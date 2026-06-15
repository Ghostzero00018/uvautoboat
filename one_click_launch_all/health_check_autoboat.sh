#!/bin/bash
# ============================================================================
# AutoBoat System Health Check
# ============================================================================
# Run this from another terminal while the simulation is running.
# It checks nodes, topics, publisher counts, parameter values, and port connectivity.
# The script auto-detects the boat's mission state and adjusts expectations:
#   IDLE    — nodes should be up, but mission topics may not exist yet
#   ACTIVE  — all topics and publishers should be present
#
# Module naming convention (functional names):
#   Perception  — LiDAR obstacle detection
#   Planner     — waypoint generation & mission management
#   Controller  — PID steering & obstacle avoidance
#
# Usage:
#   cd <workspace>/src/uvautoboat/one_click_launch_all
#   bash health_check_autoboat.sh          # Full check (~30-60s, hardware-dependent)
#   bash health_check_autoboat.sh --quick  # Nodes + topics only (~5s)
#
# Full-check duration varies with hardware (CPU, ROS 2 daemon state) and
# concurrent host load — observed up to 70-80 s on a workstation under heavy
# multi-app use. --quick is much less affected (skips param + publisher probes).
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0
TUNED=0

# Per-ROS-CLI-call cap. The dashboard service has a 90 s whole-script watchdog;
# individual probes must degrade to WARN before that watchdog kills the run.
ROS_PROBE_TIMEOUT=${ROS_PROBE_TIMEOUT:-8}

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }
tuned() { echo -e "  ${MAGENTA}[TUNED]${NC} $1"; ((TUNED++)); }
info() { echo -e "  ${CYAN}[INFO]${NC} $1"; }

section() { echo -e "\n${BLUE}========== $1 ==========${NC}"; }

# Prime DDS discovery — the first ros2 node/topic list call after process
# startup often returns incomplete results due to discovery lag. Poll with
# `--no-daemon` to sidestep any stale `ros2 daemon` cache (see Common_Issues
# "ros2 node list empty"), exiting as soon as at least one node is visible.
# Caps at 10 s; if the graph is still empty, downstream checks will report
# the real state rather than a false pass.
elapsed=0
while [ "$elapsed" -lt 10 ]; do
    if [ "$(ros2 node list --no-daemon 2>/dev/null | wc -l)" -gt 0 ]; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

# ============================================================================
# 1. NODE CHECK
# ============================================================================
section "Node Check"

EXPECTED_NODES=(
    "/lidar_perception_node"
    "/waypoint_planner_node"
    "/heading_controller_node"
    "/rosbridge_websocket"
    "/web_video_server"
)

RUNNING_NODES=$(ros2 node list 2>/dev/null)

if [ -z "$RUNNING_NODES" ]; then
    fail "Cannot reach ROS 2 graph — is the simulation running?"
    echo -e "\n${RED}Aborting: no ROS 2 nodes found.${NC}"
    exit 1
fi

for node in "${EXPECTED_NODES[@]}"; do
    if echo "$RUNNING_NODES" | grep -q "^${node}$"; then
        pass "$node"
    else
        fail "$node — not running"
    fi
done

# Health check service node (needed for dashboard health check panel)
if echo "$RUNNING_NODES" | grep -q "^/health_check_service$"; then
    pass "/health_check_service"
else
    warn "/health_check_service — not running (dashboard health check panel won't work)"
fi

# Optional nodes (informational only — not counted as WARN)
OPTIONAL_NODES=("/rviz2" "/waypoint_visualizer_node")
for node in "${OPTIONAL_NODES[@]}"; do
    if echo "$RUNNING_NODES" | grep -q "^${node}$"; then
        pass "$node (optional)"
    else
        info "$node — not running (optional)"
    fi
done

# ============================================================================
# 2. STATE DETECTION
# ============================================================================
section "Boat State Detection"

RUNNING_TOPICS=$(ros2 topic list 2>/dev/null)

# Detect mission state by reading actual planner state from topic content
# Topics persist after first publish, so topic existence alone is not reliable
BOAT_STATE="IDLE"
if echo "$RUNNING_TOPICS" | grep -q "^/planning/mission_status$"; then
    # Read one message (8s timeout), strip ANSI codes, extract state from JSON.
    # The planner may publish infrequently when idle, so 8s avoids false timeouts.
    MISSION_MSG=$(timeout 8 ros2 topic echo /planning/mission_status --once 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    PLANNER_STATE=$(echo "$MISSION_MSG" | grep -oP '"state":\s*"\K[^"]+')
    if [ -n "$PLANNER_STATE" ]; then
        # INIT/IDLE/FINISHED/JOYSTICK = not actively navigating
        ACTIVE_STATES="DRIVING PAUSED READY WAITING_CONFIRM EMERGENCY_STOP"
        if echo "$ACTIVE_STATES" | grep -qw "$PLANNER_STATE"; then
            BOAT_STATE="ACTIVE"
        fi
        info "Detected state: ${BOAT_STATE} (planner: ${PLANNER_STATE})"
    else
        # Topic exists but couldn't read state — default to IDLE (conservative).
        # Mission-only checks will show as INFO instead of false FAIL.
        info "Detected state: ${BOAT_STATE} (topic exists, could not read state — defaulting to IDLE)"
    fi
else
    info "Detected state: ${BOAT_STATE} (mission_status topic not found)"
fi
if [ "$BOAT_STATE" == "IDLE" ]; then
    info "No active mission — topics that require a running mission will show as INFO instead of FAIL"
fi

# ============================================================================
# 3. TOPIC CHECK
# ============================================================================
section "Topic Check"

# Topics that always exist when nodes are running
ALWAYS_TOPICS=(
    "/wamv/sensors/gps/gps/fix"
    "/wamv/sensors/imu/imu/data"
    "/wamv/sensors/lidars/lidar_wamv_sensor/points"
    "/wamv/thrusters/left/thrust"
    "/wamv/thrusters/right/thrust"
)

# Topics that only appear after a mission starts or when nodes are actively publishing
MISSION_TOPICS=(
    "/perception/obstacle_info"
    "/planning/mission_status"
    "/planning/waypoints"
    "/control/status"
    "/planning/config"
)

for topic in "${ALWAYS_TOPICS[@]}"; do
    if echo "$RUNNING_TOPICS" | grep -q "^${topic}$"; then
        pass "$topic"
    else
        fail "$topic — not found"
    fi
done

for topic in "${MISSION_TOPICS[@]}"; do
    if echo "$RUNNING_TOPICS" | grep -q "^${topic}$"; then
        pass "$topic"
    elif [ "$BOAT_STATE" == "IDLE" ]; then
        info "$topic — not yet active (normal in IDLE state)"
    else
        fail "$topic — not found"
    fi
done

# Check orphan topic is gone
if echo "$RUNNING_TOPICS" | grep -q "^/perception/obstacle_detected$"; then
    warn "/perception/obstacle_detected still exists (should have been removed)"
else
    pass "/perception/obstacle_detected removed (as expected)"
fi

# Quick mode stops here
if [ "$1" == "--quick" ]; then
    section "Summary (Quick Mode)"
    echo -e "  ${GREEN}PASS: $PASS${NC}  ${MAGENTA}TUNED: $TUNED${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}WARN: $WARN${NC}"
    [ $FAIL -eq 0 ] && echo -e "\n${GREEN}System looks healthy.${NC}" || echo -e "\n${RED}Issues detected — check FAIL items above.${NC}"
    exit $FAIL
fi

# ============================================================================
# 4. TOPIC PUBLISHER CHECK (lightweight — no subscribing to large messages)
# ============================================================================
section "Topic Publisher Check"

check_publisher() {
    local topic=$1
    local label=$2
    local mission_only=${3:-false}  # "true" = only expected during active mission
    local tinfo pub_count sub_count probe_status timed_out=false

    # Try up to 2 times (retry once after 2s if first attempt fails — covers DDS lag)
    for attempt in 1 2; do
        tinfo=$(timeout "$ROS_PROBE_TIMEOUT" ros2 topic info "$topic" 2>/dev/null)
        probe_status=$?
        if [ "$probe_status" -eq 124 ]; then
            timed_out=true
            break
        fi
        pub_count=$(echo "$tinfo" | grep -oP 'Publisher count: \K\d+')
        sub_count=$(echo "$tinfo" | grep -oP 'Subscription count: \K\d+')
        if [ -n "$pub_count" ] && [ "$pub_count" -ge 1 ]; then
            break
        fi
        [ "$attempt" -eq 1 ] && sleep 2
    done

    if [ "$timed_out" == "true" ]; then
        warn "$label — topic info timed out after ${ROS_PROBE_TIMEOUT}s"
    elif [ -z "$pub_count" ]; then
        if [ "$mission_only" == "true" ] && [ "$BOAT_STATE" == "IDLE" ]; then
            info "$label — not yet active (normal in IDLE state)"
        else
            fail "$label — cannot get topic info"
        fi
    elif [ "$pub_count" -ge 1 ]; then
        pass "$label — ${pub_count} publisher(s), ${sub_count} subscriber(s)"
    else
        fail "$label — no publishers (0 pub, ${sub_count} sub)"
    fi
}

check_publisher "/wamv/sensors/gps/gps/fix" "GPS"
check_publisher "/wamv/sensors/imu/imu/data" "IMU"
check_publisher "/wamv/sensors/lidars/lidar_wamv_sensor/points" "LiDAR"
check_publisher "/perception/obstacle_info" "Perception obstacle info" "true"
check_publisher "/planning/mission_status" "Planner mission status" "true"
check_publisher "/control/status" "Controller control status" "true"

# ============================================================================
# 5. PARAMETER CHECK
# ============================================================================
section "Parameter Check (Controller)"

is_node_tuned() {
    # Returns "true" if the node has processed at least one /planning/set_config
    # message since launch (config_tuned flag flipped), "false" otherwise.
    local node=$1
    local output status raw
    output=$(timeout "$ROS_PROBE_TIMEOUT" ros2 param get "$node" "config_tuned" 2>/dev/null)
    status=$?
    if [ "$status" -eq 124 ]; then
        echo "timeout"
        return
    fi
    raw=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oP 'value is: \K\w+' | tail -1)
    [ "$raw" == "True" ] && echo "true" || echo "false"
}

check_param() {
    local node=$1
    local param=$2
    local expected=$3
    local node_tuned=${4:-false}  # Result of is_node_tuned, passed in by caller
    local output status raw
    # Strip ANSI color codes and RTPS error noise, then extract the value from "X value is: Y"
    output=$(timeout "$ROS_PROBE_TIMEOUT" ros2 param get "$node" "$param" 2>/dev/null)
    status=$?
    if [ "$status" -eq 124 ]; then
        warn "$param — param read timed out after ${ROS_PROBE_TIMEOUT}s"
        return
    fi
    raw=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oP 'value is: \K[-\d.]+')
    local actual
    actual=$(echo "$raw" | tail -1)
    if [ -z "$actual" ]; then
        fail "$param — cannot read (node down?)"
    elif [ "$actual" == "$expected" ]; then
        pass "$param = $actual"
    elif [ "$node_tuned" == "true" ]; then
        tuned "$param = $actual (baseline $expected — user-applied)"
    else
        warn "$param = $actual (expected $expected — unexpected drift)"
    fi
}

controller_tuned=$(is_node_tuned "/heading_controller_node")
if [ "$controller_tuned" == "timeout" ]; then
    warn "/heading_controller_node config_tuned — param read timed out after ${ROS_PROBE_TIMEOUT}s"
    controller_tuned="unknown"
fi
check_param "/heading_controller_node" "kp" "500.0" "$controller_tuned"
check_param "/heading_controller_node" "kd" "150.0" "$controller_tuned"
check_param "/heading_controller_node" "base_speed" "400.0" "$controller_tuned"
check_param "/heading_controller_node" "obstacle_slow_factor" "0.5" "$controller_tuned"
check_param "/heading_controller_node" "turn_deadband_deg" "0.5" "$controller_tuned"
check_param "/heading_controller_node" "critical_distance" "6.0" "$controller_tuned"
check_param "/heading_controller_node" "min_safe_distance" "12.0" "$controller_tuned"
check_param "/heading_controller_node" "max_avoidance_turn_deg" "45.0" "$controller_tuned"

section "Parameter Check (Planner)"

planner_tuned=$(is_node_tuned "/waypoint_planner_node")
if [ "$planner_tuned" == "timeout" ]; then
    warn "/waypoint_planner_node config_tuned — param read timed out after ${ROS_PROBE_TIMEOUT}s"
    planner_tuned="unknown"
fi
check_param "/waypoint_planner_node" "scan_length" "15.0" "$planner_tuned"
check_param "/waypoint_planner_node" "scan_width" "30.0" "$planner_tuned"
check_param "/waypoint_planner_node" "lanes" "10" "$planner_tuned"
check_param "/waypoint_planner_node" "waypoint_tolerance" "3.5" "$planner_tuned"
check_param "/waypoint_planner_node" "max_block_time" "30.0" "$planner_tuned"
check_param "/waypoint_planner_node" "astar_resolution" "3.0" "$planner_tuned"
check_param "/waypoint_planner_node" "astar_safety_margin" "12.0" "$planner_tuned"
check_param "/waypoint_planner_node" "astar_max_expansions" "20000" "$planner_tuned"

section "Parameter Check (Perception)"

perception_tuned=$(is_node_tuned "/lidar_perception_node")
if [ "$perception_tuned" == "timeout" ]; then
    warn "/lidar_perception_node config_tuned — param read timed out after ${ROS_PROBE_TIMEOUT}s"
    perception_tuned="unknown"
fi
check_param "/lidar_perception_node" "perception_min_safe_distance" "10.0" "$perception_tuned"
check_param "/lidar_perception_node" "perception_critical_distance" "5.5" "$perception_tuned"
check_param "/lidar_perception_node" "min_height" "-1.2" "$perception_tuned"
check_param "/lidar_perception_node" "max_range" "100.0" "$perception_tuned"

# ============================================================================
# 6. SERVICE / CONNECTIVITY CHECK
# ============================================================================
section "Connectivity Check"

# Rosbridge WebSocket
if ss -tlnp 2>/dev/null | grep -q ":9090"; then
    pass "Rosbridge WebSocket on port 9090"
else
    fail "Rosbridge WebSocket not listening on port 9090"
fi

# Web Dashboard HTTP
if ss -tlnp 2>/dev/null | grep -q ":8002"; then
    pass "Web Dashboard on port 8002"
else
    fail "Web Dashboard not listening on port 8002"
fi

# Web Video Server
if ss -tlnp 2>/dev/null | grep -q ":8080"; then
    pass "Web Video Server on port 8080"
else
    warn "Web Video Server not listening on port 8080 (camera may not work)"
fi

# Dashboard HTTP response
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/ 2>/dev/null)
if [ "$HTTP_STATUS" == "200" ]; then
    pass "Dashboard HTTP responds 200 OK"
else
    fail "Dashboard HTTP returned $HTTP_STATUS (expected 200)"
fi

# ============================================================================
# 7. SUMMARY
# ============================================================================
section "Summary"
echo -e "  State: ${CYAN}${BOAT_STATE}${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${MAGENTA}TUNED: $TUNED${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}WARN: $WARN${NC}"
echo ""
if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All checks passed. System is healthy.${NC}"
    if [ "$BOAT_STATE" == "IDLE" ]; then
        echo -e "${CYAN}Note: Some checks were skipped (IDLE state). Start a mission for full validation.${NC}"
    fi
else
    echo -e "${RED}$FAIL issue(s) detected — check FAIL items above.${NC}"
fi
exit $FAIL
