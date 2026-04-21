#!/bin/bash

# ============================================================================
# AutoBoat — Complete One-Click Launch Script
# ============================================================================
#
# ℹ️  DASHBOARD PORT: This dashboard runs on PORT 8002
#     AutoBoat dashboard: http://localhost:8002
#
# Module naming convention (functional names):
#   Perception  — LiDAR obstacle detection
#   Planner     — waypoint generation & mission management
#   Controller  — PID steering & obstacle avoidance
#
# This script launches the complete AutoBoat autonomous navigation system:
#   - VRX Gazebo Simulation (Sydney Regatta World)
#   - ROS Bridge (WebSocket bridge for web dashboard)
#   - LiDAR Perception (3D LIDAR obstacle detection)
#   - Waypoint Planner (GPS waypoint planning)
#   - Heading Controller (PID control with obstacle avoidance)
#   - Web Video Server (camera stream for dashboard)
#   - Web Dashboard (real-time monitoring interface)
#
# Launch sequence and files called:
#   T1  Gazebo         ros2 launch vrx_gz competition.launch.py world:="$WORLD"
#   T2  ROS Bridge     ros2 launch rosbridge_server rosbridge_websocket_launch.xml  :9090
#   T3  Nav Stack      ros2 launch launch/autoboat.launch.yaml                      (Perception+Planner+Controller)
#                        → plan/plan/lidar_perception.py
#                        → plan/plan/waypoint_planner.py
#                        → control/control/heading_controller.py
#                        → launches waypoint_visualizer + health_check_service
#   T4  Video Server   ros2 run web_video_server web_video_server                   :8080
#   T5  RViz           ros2 launch vrx_gazebo rviz.launch.py                        (optional)
#   T6  Dashboard      python3 -m http.server 8002                                  :8002
#                        → serves web_dashboard/autoboat/ (index.html, app.js, style_merged.css)
#
# ----------------------------------------------------------------------------
# Author: IMT Nord Europe UVAutoBoat Team
#
# Usage:
#   cd <workspace>/src/uvautoboat/one_click_launch_all
#   bash launch_autoboat_complete.sh [OPTIONS]
#
# Options:
#   --world <world_name>       Gazebo world (default: sydney_regatta_DEFAULT)
#   For example: bash launch_autoboat_complete.sh --world sydney_regatta_DEFAULT
#
#   --skip-rviz                Skip RViz launch (default: launch RViz)
#   --skip-dashboard           Skip web dashboard (default: launch dashboard)
#   --skip-camera              Skip web video server (default: launch camera)
#   --no-browser               Do not open browser (default: open browser)
#   --help                     Show this help message
#
# Prerequisites:
#   - ROS 2 Jazzy installed and sourced
#   - VRX package installed
#   - AutoBoat workspace built: cd ~/seal_ws && colcon build --merge-install # (seal_ws is example workspace)
#   - rosbridge-suite: sudo apt install ros-jazzy-rosbridge-suite (Install if not already)
#   - web_video_server: sudo apt install ros-jazzy-web-video-server (Install if not already)
#   - GNOME Terminal installed (required for multi-tab launch)
#
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Graceful exit helper
die() { echo -e "${RED}$*${NC}"; exit 1; }

# Cleanup on exit (kills all spawned components)
# CAUTION: pkill -9 -f matches processes system-wide by name pattern.
# On a shared machine or multi-session setup, this may kill processes belonging
# to other users or unrelated workflows. Safe for single-user dev environments.
cleanup() {
    echo -e "${YELLOW}Stopping all AutoBoat components...${NC}"
    pkill -9 -f "gz sim" || true
    pkill -9 -f "gzserver" || true
    pkill -9 -f "gzclient" || true
    pkill -9 -f "rosbridge_websocket" || true
    pkill -9 -f "web_video_server" || true
    pkill -9 -f "autoboat.launch.yaml" || true
    pkill -9 -f "plan/autoboat" || true
    pkill -9 -f "waypoint_planner" || true
    pkill -9 -f "heading_controller" || true
    pkill -9 -f "lidar_perception" || true
    pkill -9 -f "http.server 8002" || true
    pkill -9 -f "rviz" || true
    pkill -9 -f "web_dashboard/autoboat" || true
    # Close gnome-terminal tabs we opened (if still running)
    for pid in $GAZEBO_PID $ROSBRIDGE_PID $NAV_PID $CAMERA_PID $RVIZ_PID $DASHBOARD_PID; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}

# Only clean up on user/system signals, not on normal exit.
trap cleanup INT TERM

# Default options
WORLD="sydney_regatta_DEFAULT"
LAUNCH_RVIZ=true
LAUNCH_DASHBOARD=true
LAUNCH_CAMERA=true
OPEN_BROWSER=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --world)
            WORLD="$2"
            shift 2
            ;;
        --skip-rviz)
            LAUNCH_RVIZ=false
            shift
            ;;
        --skip-dashboard)
            LAUNCH_DASHBOARD=false
            shift
            ;;
        --skip-camera)
            LAUNCH_CAMERA=false
            shift
            ;;
        --no-browser)
            OPEN_BROWSER=false
            shift
            ;;
        --help)
            cat << 'EOF'
AutoBoat — Complete Launch Script

Usage: ./launch_autoboat_complete.sh [OPTIONS]

Options:
  --world <world_name>       Gazebo world (default: sydney_regatta_DEFAULT)
  --skip-rviz                Skip RViz launch
  --skip-dashboard           Skip web dashboard launch
  --skip-camera              Skip web video server launch
  --no-browser               Do not open browser
  --help                     Show this help message

Example:
  ./launch_autoboat_complete.sh --world sydney_regatta_DEFAULT --skip-rviz

Worlds available:
  - sydney_regatta_DEFAULT (default, clean environment)
  - (smoke worlds moved to legacy/ — use --world with any VRX world name)
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Helper function to print messages
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Recheck if a launched tab/process is still alive and report status
recheck() {
    local pid="$1"
    local label="$2"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        print_status "$label is running (PID: $pid)"
    else
        print_warning "$label appears to have exited. Check the tab for errors; consider stopping this script."
    fi
}

# Wait until a ROS 2 topic has at least one publisher. Uses `ros2 topic info`
# rather than `ros2 topic echo --once` because the latter is sensitive to QoS
# mismatches and message-type-resolution delays on sensor topics — info just
# queries DDS discovery, which is enough to confirm "the publishing node is
# alive and has advertised this topic".
#
# All three wait_for_* helpers always return 0. The warning is the failure
# signal; returning non-zero would trip `set -e` and abort the whole launcher,
# defeating the "continuing anyway" intent.
wait_for_topic() {
    local topic="$1"
    local timeout="${2:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if ros2 topic info "$topic" 2>/dev/null | grep -q 'Publisher count: [1-9]'; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    print_warning "Timed out waiting for $topic after ${timeout}s — continuing anyway"
    return 0
}

# Wait until a local TCP port is listening. Used for rosbridge (:9090),
# web_video_server (:8080), and the dashboard HTTP server (:8002).
wait_for_port() {
    local port="$1"
    local timeout="${2:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if ss -tln 2>/dev/null | grep -q ":$port "; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    print_warning "Timed out waiting for port $port after ${timeout}s — continuing anyway"
    return 0
}

# Wait until a ROS 2 node is reachable via its parameter server. Any response
# from `ros2 param list <node>` confirms the node is both alive and discoverable.
wait_for_node() {
    local node="$1"
    local timeout="${2:-30}"
    local elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if timeout 2 ros2 param list "$node" >/dev/null 2>&1; then
            return 0
        fi
        elapsed=$((elapsed + 2))
    done
    print_warning "Timed out waiting for node $node after ${timeout}s — continuing anyway"
    return 0
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v ros2 &> /dev/null; then
    die "ROS 2 not found. Please install and source ROS 2 Jazzy."
fi
print_status "ROS 2 found"

if ! command -v gnome-terminal &> /dev/null; then
    print_warning "GNOME Terminal not found. Some features may not work as expected."
fi

if ! command -v gz &> /dev/null; then
    die "Gazebo not found. Please install Gazebo Harmonic."
fi
print_status "Gazebo found"

# Detect workspace root dynamically.
# Require install/setup.bash AND a src/ sibling directory — the latter rejects
# a spurious nested colcon workspace (e.g. ~/seal_ws/src/install/ created by
# running `colcon build` from inside src/) which would otherwise capture this
# walk-upward and produce src/src/... path errors downstream.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WS_ROOT="$SCRIPT_DIR"
while [ "$WS_ROOT" != "/" ]; do
    if [ -f "$WS_ROOT/install/setup.bash" ] && [ -d "$WS_ROOT/src" ]; then break; fi
    WS_ROOT="$(dirname "$WS_ROOT")"
done
INSTALL_DIR="$WS_ROOT/install"
if [ ! -f "$INSTALL_DIR/setup.bash" ]; then
    die "AutoBoat workspace not built or install/setup.bash not found. Run: colcon build --merge-install"
fi
print_status "AutoBoat workspace found at $WS_ROOT"

# Source environment
source "$INSTALL_DIR/setup.bash"
print_status "Sourced AutoBoat environment"

# Check if VRX is available
if ! ros2 pkg prefix vrx_gz &> /dev/null 2>&1; then
    print_warning "VRX package not found in ROS 2 path. Gazebo launch may fail."
fi

print_header "Launching AutoBoat Complete System"
echo "World: $WORLD"
echo "RViz: $([ "$LAUNCH_RVIZ" = true ] && echo 'Yes' || echo 'No')"
echo "Dashboard: $([ "$LAUNCH_DASHBOARD" = true ] && echo 'Yes' || echo 'No')"
echo "Camera Stream: $([ "$LAUNCH_CAMERA" = true ] && echo 'Yes' || echo 'No')"
echo "Auto-open Browser: $([ "$OPEN_BROWSER" = true ] && echo 'Yes' || echo 'No')"
echo ""
echo "Tip: If tabs close immediately, check their terminal output for missing packages or model downloads."
echo "Shortcuts: skip RViz with --skip-rviz, skip dashboard with --skip-dashboard, skip camera with --skip-camera, change world with --world <name>."
echo ""

# Kill any old processes (reuse the cleanup function defined above)
print_status "Cleaning up old processes..."
cleanup
sleep 4

# T1: Launch Gazebo (VRX Simulation)
# Apply upstream VRX patches (issue #876 workaround — LiDAR at origin fix)
bash "$(dirname "$0")/patch_vrx.sh"

print_status "Launching Gazebo (Sydney Regatta - $WORLD)..."
gnome-terminal --wait --tab --title="gazebo" -- bash -i -c "
source \"$INSTALL_DIR/setup.bash\"
echo \"Starting Gazebo with world: $WORLD\"
echo 'Note: GPS may take 10-30 seconds to initialize'
ros2 launch vrx_gz competition.launch.py world:="$WORLD"
" &
GAZEBO_PID=$!
# Wait for Gazebo to load the world and for WAM-V sensors to start publishing.
# First GPS fix is the earliest reliable "world + boat are up" signal.
wait_for_topic /wamv/sensors/gps/gps/fix 60
print_status "Gazebo launched (PID: $GAZEBO_PID)"
recheck "$GAZEBO_PID" "Gazebo"

# T2: Launch ROS Bridge (WebSocket for dashboard)
print_status "Launching ROS Bridge (WebSocket on ws://localhost:9090)..."
gnome-terminal --wait --tab --title="rosbridge" -- bash -i -c "
source \"$INSTALL_DIR/setup.bash\"
echo 'Starting ROS Bridge WebSocket server...'
ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0
" &
ROSBRIDGE_PID=$!
wait_for_port 9090 30  # Rosbridge WebSocket
print_status "ROS Bridge launched (PID: $ROSBRIDGE_PID)"
recheck "$ROSBRIDGE_PID" "ROS Bridge"

# T3: Launch Navigation Stack (Perception-Planner-Controller)
print_status "Launching Navigation Stack (Perception-Planner-Controller)..."
gnome-terminal --wait --tab --title="navigation" -- bash -i -c "
source \"$INSTALL_DIR/setup.bash\"
echo 'Starting AutoBoat Modular Navigation System...'
echo 'Components: Perception | Planner | Controller'
ros2 launch \"$WS_ROOT/src/uvautoboat/launch/autoboat.launch.yaml\"
" &
NAV_PID=$!
# heading_controller_node is the last node to come up in the nav launch —
# if it responds to a param list the whole pipeline is discoverable.
wait_for_node /heading_controller_node 30
print_status "Navigation stack launched (PID: $NAV_PID)"
recheck "$NAV_PID" "Navigation stack"

# T4: Launch Web Video Server (camera stream)
if [ "$LAUNCH_CAMERA" = true ]; then
    print_status "Launching Web Video Server (http://localhost:8080)..."
gnome-terminal --wait --tab --title="camera" -- bash -i -c "
source \"$INSTALL_DIR/setup.bash\"
echo 'Starting Web Video Server for camera feed...'
echo 'Stream available at: http://localhost:8080'
ros2 run web_video_server web_video_server
" &
    CAMERA_PID=$!
    wait_for_port 8080 30  # web_video_server MJPEG stream
    print_status "Web Video Server launched (PID: $CAMERA_PID)"
    recheck "$CAMERA_PID" "Web Video Server"
fi

# T5: Launch RViz (optional visualization)
if [ "$LAUNCH_RVIZ" = true ]; then
    print_status "Launching RViz visualization..."
gnome-terminal --wait --tab --title="rviz" -- bash -i -c "
source \"$INSTALL_DIR/setup.bash\"
echo 'Starting RViz...'
sleep 3
cd \"$WS_ROOT\"
# NOTE: rviz.launch.py only exists in vrx_gazebo (legacy package), not in vrx_gz.
# vrx_gz is used for Gazebo Harmonic simulation; vrx_gazebo provides the RViz config.
ros2 launch vrx_gazebo rviz.launch.py
" &
    RVIZ_PID=$!
    sleep 8
    print_status "RViz launched (PID: $RVIZ_PID)"
    recheck "$RVIZ_PID" "RViz"
fi

# T6: Launch Web Dashboard
if [ "$LAUNCH_DASHBOARD" = true ]; then
    print_status "Launching Web Dashboard (http://localhost:8002)..."
gnome-terminal --wait --tab --title="dashboard" -- bash -i -c "
cd \"$WS_ROOT/src/uvautoboat/web_dashboard/autoboat\"
echo 'Starting Web Dashboard HTTP server...'
echo 'Dashboard available at: http://localhost:8002'
echo 'Note: Wait for GPS to initialize (~10-30s) before opening dashboard'
python3 -m http.server 8002
" &
    DASHBOARD_PID=$!
    wait_for_port 8002 15  # Dashboard HTTP server
    print_status "Web Dashboard launched (PID: $DASHBOARD_PID)"
fi

# Open browser if requested
if [ "$OPEN_BROWSER" = true ] && [ "$LAUNCH_DASHBOARD" = true ]; then
    print_status "Waiting for systems to stabilize before opening browser..."
    sleep 8
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8002 >/dev/null 2>&1 &
    elif command -v open &> /dev/null; then
        open http://localhost:8002 >/dev/null 2>&1 &
    elif command -v google-chrome &> /dev/null; then
        google-chrome http://localhost:8002 >/dev/null 2>&1 &
    elif command -v firefox &> /dev/null; then
        firefox http://localhost:8002 >/dev/null 2>&1 &
    else
        print_warning "Could not auto-open browser. Manually visit http://localhost:8002"
    fi
fi

print_header "AutoBoat System Launched Successfully!"
echo ""
echo -e "${GREEN}System Status:${NC}"
echo "  ROS Bridge:      ws://localhost:9090"
if [ "$LAUNCH_CAMERA" = true ]; then
    echo "  Camera Stream:   http://localhost:8080"
fi
if [ "$LAUNCH_DASHBOARD" = true ]; then
    echo "  Web Dashboard:   http://localhost:8002"
fi
echo ""
echo -e "${YELLOW}Quick Tips:${NC}"
echo "  - GPS takes 10-30s to initialize (be patient!)"
echo "  - Check terminal tabs for error messages"
echo "  - Use web dashboard to control and monitor the boat"
echo "  - Run 'ros2 run plan autoboat_cli generate' to create waypoints (if the web dashboard is not used)"
echo "  - Run 'ros2 run plan autoboat_cli start' to begin mission (if the web dashboard is not used)"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  Monitor GPS:        ros2 topic echo /wamv/sensors/gps/gps/fix"
echo "  Check LIDAR:        ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points"
echo "  View obstacles:     ros2 topic echo /perception/obstacle_info"
echo "  List all nodes:     ros2 node list"
echo "  Kill everything:    pkill -9 gz && pkill -9 ros2 && pkill -9 rosbridge"
echo ""
echo -e "${BLUE}Press Ctrl+C in any terminal tab to stop that component${NC}"
echo -e "${BLUE}Press Ctrl+C here in this terminal to stop EVERYTHING (cleanup will kill all components)${NC}"
echo ""

# Keep script running until user interrupts (Ctrl+C triggers cleanup trap)
while true; do
    sleep 6
done
