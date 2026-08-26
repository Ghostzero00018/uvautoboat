#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DASHBOARD_DIR="$REPO_ROOT/web_dashboard/autoboat"
HELPER="$SCRIPT_DIR/pi_live_hailo_mavlink_dashboard.sh"
FCU_TO_VRX_EVIDENCE="$SCRIPT_DIR/fcu_to_vrx_evidence.py"
EXPECTED_HELPER_SHA256='b0793bdac61595a2c5e85dafbc18806bde8146cecece4ae232846b51ae4b8cb0'
EXPECTED_SSID="${LIVE_SSID:-IoT IMT Nord Europe}"
PI_WINDOW_MODE="${LIVE_PI_WINDOW_MODE:-fullscreen}"
FCU_TO_VRX_FANOUT="${LIVE_FCU_TO_VRX_FANOUT:-0}"
ARMED_OBSERVATION="${LIVE_ARMED_OBSERVATION:-0}"
ARMED_OBSERVATION_MAX_SECONDS="${LIVE_ARMED_OBSERVATION_MAX_SECONDS:-}"
ARMED_OBSERVATION_FINAL_SECONDS="${LIVE_ARMED_OBSERVATION_FINAL_SECONDS:-}"
ARMED_OBSERVATION_STALE_SECONDS="${LIVE_ARMED_OBSERVATION_STALE_SECONDS:-}"
ARMED_OBSERVATION_LEFT_CHANNEL="${LIVE_ARMED_OBSERVATION_LEFT_CHANNEL:-}"
ARMED_OBSERVATION_LEFT_PWM_MIN="${LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN:-}"
ARMED_OBSERVATION_LEFT_TRIM="${LIVE_ARMED_OBSERVATION_LEFT_TRIM:-}"
ARMED_OBSERVATION_LEFT_PWM_MAX="${LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX:-}"
ARMED_OBSERVATION_RIGHT_CHANNEL="${LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL:-}"
ARMED_OBSERVATION_RIGHT_PWM_MIN="${LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN:-}"
ARMED_OBSERVATION_RIGHT_TRIM="${LIVE_ARMED_OBSERVATION_RIGHT_TRIM:-}"
ARMED_OBSERVATION_RIGHT_PWM_MAX="${LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX:-}"
FCU_TO_VRX_INGRESS_PORT=14556
PI_HOLD_AFTER_WINDOW=1
ROS_SETUP='/opt/ros/jazzy/setup.bash'
LIVE_DOMAIN_ID='12'
WORKSTATION_LOG_ROOT="${LIVE_DASHBOARD_LOG_ROOT:-$HOME/Desktop}"
SERVICE_READY_TIMEOUT_SECONDS="${LIVE_SERVICE_READY_TIMEOUT_SECONDS:-30}"
ARRIVAL_TIMEOUT_SECONDS="${LIVE_ARRIVAL_TIMEOUT_SECONDS:-360}"
ARRIVAL_SAMPLE_SECONDS="${LIVE_ARRIVAL_SAMPLE_SECONDS:-10}"
TEARDOWN_TIMEOUT_SECONDS="${LIVE_TEARDOWN_TIMEOUT_SECONDS:-15}"
SUPERVISOR_POLL_SECONDS="${LIVE_SUPERVISOR_POLL_SECONDS:-1}"
CHILD_STARTUP_SETTLE_SECONDS="${LIVE_CHILD_STARTUP_SETTLE_SECONDS:-0.2}"
STOP_POLL_SECONDS="${LIVE_STOP_POLL_SECONDS:-1}"
STOP_INT_ATTEMPTS="${LIVE_STOP_INT_ATTEMPTS:-5}"
STOP_TERM_ATTEMPTS="${LIVE_STOP_TERM_ATTEMPTS:-3}"

WORKSTATION_CONFLICT_PATTERNS=(
  'rosbridge'
  'web_video_server'
  'serve_dashboard.py'
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'gazebo'
  'gz sim'
  'waypoint_planner'
  'pi_live_hailo_mavlink_dashboard.sh'
  'fcu_to_vrx_evidence.py observe-pi'
)

PI_CONFLICT_PATTERNS=(
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'pi_live_hailo_mavlink_dashboard.sh'
)

WORKSTATION_PORTS=(8002 8080 9090)
PI_DEVICES=(/dev/ttyAMA0 /dev/video4 /dev/hailo0)
THERMAL_PATH='/sys/class/thermal/thermal_zone0/temp'

EXPECTED_TOPICS=(
  '/hailo/overlay/image_raw'
  '/mavros/state'
  '/mavros/global_position/raw/fix'
  '/mavros/imu/data'
  '/mavros/battery'
  '/mavros/rc/in'
  '/mavros/rc/out'
)
EXPECTED_TOPIC_TYPES=(
  'sensor_msgs/msg/Image'
  'mavros_msgs/msg/State'
  'sensor_msgs/msg/NavSatFix'
  'sensor_msgs/msg/Imu'
  'sensor_msgs/msg/BatteryState'
  'mavros_msgs/msg/RCIn'
  'mavros_msgs/msg/RCOut'
)
EXPECTED_TOPIC_RELIABILITY=(reliable best_effort best_effort best_effort best_effort best_effort best_effort)
EXPECTED_TOPIC_DEPTH=(1 10 10 10 10 10 10)

ROSBRIDGE_COMMAND=(
  ros2 launch rosbridge_server rosbridge_websocket_launch.xml address:=127.0.0.1
)
VIDEO_COMMAND=(
  ros2 run web_video_server web_video_server --ros-args -p address:=127.0.0.1
)
DASHBOARD_COMMAND=(
  bash -c 'cd -- "$1" && shift && exec "$@"' _ "$DASHBOARD_DIR"
  python3 serve_dashboard.py 8002 127.0.0.1
)

declare -a CHILD_NAMES=()
declare -a CHILD_PIDS=()
declare -a CHILD_PGIDS=()
declare -A EMITTED_MARKERS=()
SUPERVISOR_PGID=''
SUPERVISOR_LOG=''
SUPERVISOR_PHASE='not-started'
SUPERVISOR_STOP_TRIGGER='none'
SUPERVISOR_STOP_SIGNAL='none'
SUPERVISOR_STOP_PHASE='none'
SUPERVISOR_FAILED_PHASE='none'
WORKSTATION_INTERFACE=''
WORKSTATION_IP=''
RUN_DIR=''
RATE_LOG=''
SERVICES_UP=0
CLEANING=0
STOP_REQUESTED=0
FINAL_RC=0
ARRIVAL_ELAPSED_SECONDS=0

append_supervisor_log() {
  local line="$1"
  [ -n "$SUPERVISOR_LOG" ] || return 0
  if ! printf 'timestamp=%s %s\n' "${EPOCHREALTIME:-unknown}" "$line" \
    >>"$SUPERVISOR_LOG"; then
    printf '[live-dashboard-preflight] LOG_WRITE_ERROR: path=%s\n' \
      "$SUPERVISOR_LOG" >&2
  fi
  return 0
}

log() {
  local line="[live-dashboard-preflight] $*"
  append_supervisor_log "$line"
  printf '%s\n' "$line"
}

log_error() {
  local line="[live-dashboard-preflight] $*"
  append_supervisor_log "$line"
  printf '%s\n' "$line" >&2
}

set_supervisor_phase() {
  SUPERVISOR_PHASE="$1"
  log "SUPERVISOR_PHASE=$SUPERVISOR_PHASE"
}

record_stop_trigger() {
  local signal="$1"
  [ "$SUPERVISOR_STOP_TRIGGER" = none ] || return 0
  SUPERVISOR_STOP_TRIGGER=signal
  SUPERVISOR_STOP_SIGNAL="$signal"
  SUPERVISOR_STOP_PHASE="$SUPERVISOR_PHASE"
  log "SUPERVISOR_STOP trigger=signal signal=$signal phase=$SUPERVISOR_STOP_PHASE"
}

fail() {
  log_error "FAIL: $*"
  exit 1
}

validate_pi_window_selectors() {
  local name value side minimum trim maximum
  [[ "$PI_WINDOW_MODE" =~ ^(resizable|fullscreen)$ ]] \
    || fail 'LIVE_PI_WINDOW_MODE must be resizable or fullscreen'
  [[ "$FCU_TO_VRX_FANOUT" =~ ^[01]$ ]] \
    || fail 'LIVE_FCU_TO_VRX_FANOUT must be 0 or 1'
  [[ "$ARMED_OBSERVATION" =~ ^[01]$ ]] \
    || fail 'LIVE_ARMED_OBSERVATION must be 0 or 1'
  PI_HOLD_AFTER_WINDOW=1
  [ "$ARMED_OBSERVATION" -eq 0 ] && return 0
  [ "$FCU_TO_VRX_FANOUT" -eq 1 ] \
    || fail 'LIVE_ARMED_OBSERVATION=1 requires LIVE_FCU_TO_VRX_FANOUT=1'

  for name in \
    ARMED_OBSERVATION_MAX_SECONDS ARMED_OBSERVATION_FINAL_SECONDS \
    ARMED_OBSERVATION_STALE_SECONDS ARMED_OBSERVATION_LEFT_CHANNEL \
    ARMED_OBSERVATION_LEFT_PWM_MIN ARMED_OBSERVATION_LEFT_TRIM \
    ARMED_OBSERVATION_LEFT_PWM_MAX ARMED_OBSERVATION_RIGHT_CHANNEL \
    ARMED_OBSERVATION_RIGHT_PWM_MIN ARMED_OBSERVATION_RIGHT_TRIM \
    ARMED_OBSERVATION_RIGHT_PWM_MAX; do
    [ -n "${!name:-}" ] \
      || fail "LIVE_${name} is required when LIVE_ARMED_OBSERVATION=1"
  done
  for value in "$ARMED_OBSERVATION_MAX_SECONDS" \
    "$ARMED_OBSERVATION_FINAL_SECONDS" "$ARMED_OBSERVATION_STALE_SECONDS"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] \
      || fail 'armed-observation time limits must be positive integers'
  done
  for value in "$ARMED_OBSERVATION_LEFT_CHANNEL" \
    "$ARMED_OBSERVATION_RIGHT_CHANNEL"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] && [ "$value" -le 16 ] \
      || fail 'armed-observation servo channels must be live-read values in 1..16'
  done
  [ "$ARMED_OBSERVATION_LEFT_CHANNEL" -ne "$ARMED_OBSERVATION_RIGHT_CHANNEL" ] \
    || fail 'armed-observation left and right servo channels must differ'
  for side in LEFT RIGHT; do
    minimum="ARMED_OBSERVATION_${side}_PWM_MIN"
    trim="ARMED_OBSERVATION_${side}_TRIM"
    maximum="ARMED_OBSERVATION_${side}_PWM_MAX"
    for name in "$minimum" "$trim" "$maximum"; do
      value="${!name}"
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] \
        && [ "$value" -le 65535 ] \
        || fail "LIVE_${name} must be a live-read PWM integer in 1..65535"
    done
    [ "${!minimum}" -le "${!trim}" ] && [ "${!trim}" -lt "${!maximum}" ] \
      || fail "$side armed-observation rail must satisfy min <= trim < max"
    [ "${!trim}" -ge 800 ] && [ "${!trim}" -le 2200 ] \
      || fail "$side armed-observation trim must be in the helper range 800..2200"
  done
  PI_HOLD_AFTER_WINDOW=0
}

usage() {
  printf 'usage: %s workstation\n' "${0##*/}" >&2
  printf '       %s run\n' "${0##*/}" >&2
  printf '       %s pi WORKSTATION_IP\n' "${0##*/}" >&2
  printf '       %s sitl\n' "${0##*/}" >&2
  exit 2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command missing: $1"
}

check_helper_pin() {
  [ -r "$HELPER" ] || fail "helper missing: $HELPER"
  printf '%s  %s\n' "$EXPECTED_HELPER_SHA256" "$HELPER" | sha256sum -c -
}

reject_conflicting_processes() {
  local context="$1" pattern output rc
  local found=0
  shift

  for pattern in "$@"; do
    [ -n "$pattern" ] || fail "$context process pattern is empty"
    case "$pattern" in
      *'|'*) fail "$context process pattern contains alternation: $pattern" ;;
      *$'\n'*|*$'\r'*) fail "$context process pattern contains a line break" ;;
    esac

    if output="$(pgrep -af -- "$pattern")"; then
      printf '%s\n' "$output" >&2
      found=1
    else
      rc=$?
      [ "$rc" -eq 1 ] \
        || fail "cannot inspect $context processes for pattern: $pattern"
    fi
  done

  [ "$found" -eq 0 ] || fail "$context conflicting process found"
}

reject_listening_tcp_ports() {
  local state port matches
  local found=0
  state="$(ss -H -ltn)" || fail 'cannot inspect workstation TCP listeners'

  for port in "$@"; do
    matches="$(awk -v target="$port" '
      {
        local_address = $4
        sub(/^.*:/, "", local_address)
        if (local_address == target) print
      }
    ' <<<"$state")"
    if [ -n "$matches" ]; then
      printf '%s\n' "$matches" >&2
      found=1
    fi
  done

  [ "$found" -eq 0 ] || fail 'workstation dashboard port already in use'
}

reject_device_owners() {
  local device owners rc
  for device in "$@"; do
    if owners="$(fuser "$device" 2>/dev/null)"; then
      [ -z "$owners" ] || fail "$device already in use by:$owners"
    else
      rc=$?
      [ "$rc" -eq 1 ] || fail "cannot inspect device owner: $device"
    fi
  done
}

setup_ros_environment() {
  local source_rc=0

  [ -r "$ROS_SETUP" ] || fail "ROS Jazzy setup missing: $ROS_SETUP"
  set +u
  # shellcheck disable=SC1091
  source "$ROS_SETUP" || source_rc=$?
  set -u
  [ "$source_rc" -eq 0 ] || fail "cannot source ROS Jazzy setup: $ROS_SETUP"

  export ROS_DOMAIN_ID="$LIVE_DOMAIN_ID"
  export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
  unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
  unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
  unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI
}

resolve_workstation_network() {
  local wifi_state matched_devices ip_state cidr address
  local -a devices=() addresses=()

  wifi_state="$(nmcli -t -f DEVICE,ACTIVE,SSID dev wifi)" \
    || fail 'cannot inspect workstation Wi-Fi state'
  matched_devices="$(awk -F: -v expected="$EXPECTED_SSID" \
    '$2 == "yes" && $3 == expected { print $1 }' <<<"$wifi_state")"
  while IFS= read -r address; do
    [ -n "$address" ] && devices+=("$address")
  done <<<"$matched_devices"
  [ "${#devices[@]}" -eq 1 ] \
    || fail "expected one active interface on SSID '$EXPECTED_SSID', found ${#devices[@]}"
  WORKSTATION_INTERFACE="${devices[0]}"

  ip_state="$(ip -4 -o address show dev "$WORKSTATION_INTERFACE" scope global)" \
    || fail "cannot inspect IPv4 on interface: $WORKSTATION_INTERFACE"
  while IFS= read -r cidr; do
    [ -n "$cidr" ] || continue
    address="${cidr%%/*}"
    addresses+=("$address")
  done < <(awk '{print $4}' <<<"$ip_state")
  [ "${#addresses[@]}" -eq 1 ] \
    || fail "expected one global IPv4 on $WORKSTATION_INTERFACE, found ${#addresses[@]}"
  WORKSTATION_IP="${addresses[0]}"
  [[ "$WORKSTATION_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] \
    || fail "invalid workstation IPv4: $WORKSTATION_IP"
  printf 'workstation_ipv4=%s dev=%s ssid=%s\n' \
    "$WORKSTATION_IP" "$WORKSTATION_INTERFACE" "$EXPECTED_SSID"
}

run_workstation_static_gate() {
  require_command node
  "$SCRIPT_DIR/test_pi_live_hailo_mavlink_dashboard.sh" "$HELPER"
  "$SCRIPT_DIR/test_live_dashboard_preflight.sh" "$SCRIPT_DIR/live_dashboard_preflight.sh"
  node --test --test-isolation=none "$DASHBOARD_DIR"/test/*.test.js
  node --check "$DASHBOARD_DIR/app.js"
}

run_workstation_runtime_preflight() {
  local command

  validate_pi_window_selectors
  for command in awk bash curl date grep ip mkdir nmcli pgrep ps python3 \
    setsid sha256sum ss tee tr; do
    require_command "$command"
  done
  setup_ros_environment
  require_command ros2
  ros2 pkg prefix rosbridge_server >/dev/null \
    || fail 'rosbridge_server package missing'
  ros2 pkg prefix web_video_server >/dev/null \
    || fail 'web_video_server package missing'
  [ -r "$DASHBOARD_DIR/serve_dashboard.py" ] \
    || fail "dashboard server missing: $DASHBOARD_DIR/serve_dashboard.py"
  [ -x "$SCRIPT_DIR/rate_probe.py" ] \
    || fail "rate probe missing or not executable: $SCRIPT_DIR/rate_probe.py"
  [ -r "$FCU_TO_VRX_EVIDENCE" ] \
    || fail "FCU-to-VRX evidence observer missing: $FCU_TO_VRX_EVIDENCE"
  if [ "$ARMED_OBSERVATION" -eq 1 ]; then
    python3 -c 'import mavros_msgs, rclpy, sensor_msgs' \
      || fail 'Pi-side evidence observer Python dependencies are unavailable'
  fi

  check_helper_pin
  resolve_workstation_network
  reject_listening_tcp_ports "${WORKSTATION_PORTS[@]}"
  reject_conflicting_processes workstation "${WORKSTATION_CONFLICT_PATTERNS[@]}"
}

run_workstation_preflight() {
  run_workstation_static_gate
  run_workstation_runtime_preflight
  log 'W1_PREFLIGHT=PASS tests=dashboard,helper,preflight ports=8002,8080,9090'
}

emit_marker_once() {
  local key="$1"
  shift
  [ "${EMITTED_MARKERS[$key]:-0}" -eq 0 ] || return 0
  EMITTED_MARKERS[$key]=1
  log "$*"
}

init_supervisor_state() {
  CHILD_NAMES=()
  CHILD_PIDS=()
  CHILD_PGIDS=()
  EMITTED_MARKERS=()
  SERVICES_UP=0
  CLEANING=0
  STOP_REQUESTED=0
  FINAL_RC=0
  ARRIVAL_ELAPSED_SECONDS=0
  SUPERVISOR_LOG=''
  SUPERVISOR_PHASE=initialization
  SUPERVISOR_STOP_TRIGGER=none
  SUPERVISOR_STOP_SIGNAL=none
  SUPERVISOR_STOP_PHASE=none
  SUPERVISOR_FAILED_PHASE=none
  SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')" \
    || fail 'cannot determine workstation supervisor process group'
  [[ "$SUPERVISOR_PGID" =~ ^[1-9][0-9]*$ ]] \
    || fail 'invalid workstation supervisor process group'
  RUN_DIR="$WORKSTATION_LOG_ROOT/live_dashboard_workstation_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$RUN_DIR"
  RATE_LOG="$RUN_DIR/w5_live_rates.log"
  SUPERVISOR_LOG="$RUN_DIR/supervisor.log"
  if ! : >>"$SUPERVISOR_LOG"; then
    SUPERVISOR_LOG=''
    fail "cannot create supervisor lifecycle log: $RUN_DIR/supervisor.log"
  fi
  log "SUPERVISOR_START pid=$BASHPID pgid=$SUPERVISOR_PGID phase=$SUPERVISOR_PHASE"
}

group_alive() {
  local pgid="$1"
  kill -0 -- "-$pgid" 2>/dev/null
}

stop_group() {
  local name="$1" pgid="$2" pid="$3" signal attempts i
  if ! [[ "$pgid" =~ ^[1-9][0-9]*$ ]]; then
    log_error "CLEANUP_ERROR: invalid process group name=$name pgid=$pgid"
    return 1
  fi
  if [ "$pgid" = "$SUPERVISOR_PGID" ]; then
    log_error "CLEANUP_ERROR: refusing supervisor process group name=$name pgid=$pgid"
    return 1
  fi
  group_alive "$pgid" || { wait "$pid" 2>/dev/null || true; return 0; }

  for signal in INT TERM KILL; do
    kill -"$signal" -- "-$pgid" 2>/dev/null || true
    case "$signal" in
      INT) attempts="$STOP_INT_ATTEMPTS" ;;
      TERM) attempts="$STOP_TERM_ATTEMPTS" ;;
      KILL) attempts=1 ;;
    esac
    for ((i=0; i<attempts; i++)); do
      group_alive "$pgid" || break
      sleep "$STOP_POLL_SECONDS" || true
    done
    group_alive "$pgid" || break
  done
  wait "$pid" 2>/dev/null || true
  if group_alive "$pgid"; then
    log_error "CLEANUP_ERROR: process group still alive name=$name pgid=$pgid"
    return 1
  fi
  log "stopped $name"
}

start_child() {
  local name="$1" logfile="$2" pid pgid index
  shift 2
  ( trap - INT QUIT; exec setsid "$@" ) >"$logfile" 2>&1 < /dev/null &
  pid=$!
  pgid="$pid"
  CHILD_NAMES+=("$name")
  CHILD_PIDS+=("$pid")
  CHILD_PGIDS+=("$pgid")
  index=$((${#CHILD_PGIDS[@]} - 1))
  sleep "$CHILD_STARTUP_SETTLE_SECONDS" || true
  kill -0 "$pid" 2>/dev/null \
    || fail "$name exited during startup; see $logfile"
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] \
    || fail "cannot determine $name process group"
  [ "$pgid" != "$SUPERVISOR_PGID" ] \
    || fail "$name did not enter a separate process group"
  CHILD_PGIDS[$index]="$pgid"
  [ "$pgid" = "$pid" ] \
    || fail "$name process group is not led by its registered PID"
  log "started $name pid=$pid pgid=$pgid log=$logfile"
}

monitor_children_once() {
  local verifier_fn="${1:-:}" i
  for ((i=0; i<${#CHILD_NAMES[@]}; i++)); do
    if ! kill -0 "${CHILD_PIDS[$i]}" 2>/dev/null; then
      log_error "CHILD_EXITED: name=${CHILD_NAMES[$i]} pid=${CHILD_PIDS[$i]}"
      return 1
    fi
    if ! group_alive "${CHILD_PGIDS[$i]}"; then
      log_error \
        "CHILD_GROUP_EXITED: name=${CHILD_NAMES[$i]} pgid=${CHILD_PGIDS[$i]}"
      return 1
    fi
  done
  "$verifier_fn"
}

loopback_listener_ready() {
  local port="$1" state
  state="$(ss -H -ltn "sport = :$port")" || return 1
  awk -v expected="127.0.0.1:$port" \
    '$4 == expected { found = 1 } END { exit found ? 0 : 1 }' <<<"$state"
}

workstation_nodes_present() {
  local nodes
  nodes="$(ros2 node list --no-daemon --spin-time 2)" || return 1
  grep -Fxq '/rosbridge_websocket' <<<"$nodes" || return 1
  grep -Fxq '/rosapi' <<<"$nodes" || return 1
  grep -Fxq '/web_video_server' <<<"$nodes"
}

workstation_rosapi_service_present() {
  local services
  services="$(ros2 service list --no-daemon --spin-time 2)" || return 1
  grep -Fxq '/rosapi/topics_for_type' <<<"$services"
}

verify_workstation_services_ready_once() {
  local port
  for port in "${WORKSTATION_PORTS[@]}"; do
    loopback_listener_ready "$port" || return 1
  done
  workstation_nodes_present || return 1
  workstation_rosapi_service_present || return 1
  curl --fail --silent --show-error --max-time 3 --output /dev/null \
    http://127.0.0.1:8002/ || return 1
  curl --fail --silent --show-error --max-time 3 --output /dev/null \
    http://127.0.0.1:8080/ || return 1
}

verify_workstation_local_health_once() {
  local port
  for port in "${WORKSTATION_PORTS[@]}"; do
    loopback_listener_ready "$port" || return 1
  done
  workstation_nodes_present
}

monitor_workstation_once() {
  monitor_children_once verify_workstation_local_health_once
}

wait_for_workstation_services() {
  local deadline=$((SECONDS + SERVICE_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    monitor_children_once || return 1
    if verify_workstation_services_ready_once; then
      return 0
    fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  log_error \
    "FAIL: workstation services did not become ready within ${SERVICE_READY_TIMEOUT_SECONDS}s"
  return 1
}

start_workstation_services() {
  start_child rosbridge "$RUN_DIR/rosbridge.log" "${ROSBRIDGE_COMMAND[@]}"
  start_child web-video-server "$RUN_DIR/web_video_server.log" "${VIDEO_COMMAND[@]}"
  start_child dashboard "$RUN_DIR/dashboard.log" "${DASHBOARD_COMMAND[@]}"
  if [ "$ARMED_OBSERVATION" -eq 1 ]; then
    start_child pi-evidence-observer "$RUN_DIR/fcu_to_vrx_pi_observer.log" \
      python3 "$FCU_TO_VRX_EVIDENCE" observe-pi \
      --output "$RUN_DIR/fcu_to_vrx_pi_events.jsonl" \
      --status "$RUN_DIR/fcu_to_vrx_pi_status.json" \
      --stale-seconds "$ARMED_OBSERVATION_STALE_SECONDS" \
      --left-channel "$ARMED_OBSERVATION_LEFT_CHANNEL" \
      --right-channel "$ARMED_OBSERVATION_RIGHT_CHANNEL" \
      --left-min "$ARMED_OBSERVATION_LEFT_PWM_MIN" \
      --left-trim "$ARMED_OBSERVATION_LEFT_TRIM" \
      --left-max "$ARMED_OBSERVATION_LEFT_PWM_MAX" \
      --right-min "$ARMED_OBSERVATION_RIGHT_PWM_MIN" \
      --right-trim "$ARMED_OBSERVATION_RIGHT_TRIM" \
      --right-max "$ARMED_OBSERVATION_RIGHT_PWM_MAX"
  fi
}

print_pi_command() {
  validate_pi_window_selectors
  printf '\nPi P1: paste this single compound command'
  printf ' (window_mode=%s)\n' "$PI_WINDOW_MODE"
  printf '(\n'
  printf '  set -euo pipefail\n'
  printf '  PI_HOME="$(readlink -f -- "$HOME")" || { echo "home-resolve-failed"; exit 2; }\n'
  printf '  { [ -n "$PI_HOME" ] && [ -d "$PI_HOME" ]; } || { echo "home-invalid"; exit 2; }\n'
  printf '  PI_DESKTOP="$(xdg-user-dir DESKTOP)" || { echo "desktop-resolve-failed"; exit 2; }\n'
  printf '  PI_DESKTOP="$(readlink -f -- "$PI_DESKTOP")" || { echo "desktop-canonicalize-failed"; exit 2; }\n'
  printf '  { [ -n "$PI_DESKTOP" ] && [ -d "$PI_DESKTOP" ]; } || { echo "desktop-invalid"; exit 2; }\n'
  printf '  [ "$PI_DESKTOP" != "$PI_HOME" ] || { echo "desktop-not-dedicated"; exit 2; }\n'
  printf '  PI_RUNTIME_ROOT="$PI_HOME/hailo_coco_overlay_2026-07-10"\n'
  printf '  PI_HELPER="$PI_DESKTOP/pi_live_hailo_mavlink_dashboard.sh"\n'
  printf '  cd "$PI_RUNTIME_ROOT"\n'
  printf "  printf '%%s  %%s\\\\n' '%s' \"\$PI_HELPER\" | sha256sum -c -\n" \
    "$EXPECTED_HELPER_SHA256"
  printf '  chmod +x "$PI_HELPER"\n'
  printf "  printf 'PI_TEMP_START_MC='\n"
  printf '  cat /sys/class/thermal/thermal_zone0/temp\n'
  printf '  exec env WORKSTATION_IP=%q LIVE_SSID=%q LIVE_HOLD_AFTER_WINDOW=%q LIVE_FCU_TO_VRX_FANOUT=%q LIVE_ARMED_OBSERVATION=%q LIVE_ARMED_OBSERVATION_MAX_SECONDS=%q LIVE_ARMED_OBSERVATION_FINAL_SECONDS=%q LIVE_ARMED_OBSERVATION_STALE_SECONDS=%q LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=%q LIVE_ARMED_OBSERVATION_LEFT_TRIM=%q LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=%q LIVE_ARMED_OBSERVATION_RIGHT_TRIM=%q HAILO_DEMO_ROOT="$PI_RUNTIME_ROOT" HAILO_LOCAL_DISPLAY=1 HAILO_LOCAL_WINDOW_MODE=%q "$PI_HELPER"\n' \
    "$WORKSTATION_IP" "$EXPECTED_SSID" "$PI_HOLD_AFTER_WINDOW" \
    "$FCU_TO_VRX_FANOUT" "$ARMED_OBSERVATION" \
    "$ARMED_OBSERVATION_MAX_SECONDS" "$ARMED_OBSERVATION_FINAL_SECONDS" \
    "$ARMED_OBSERVATION_STALE_SECONDS" "$ARMED_OBSERVATION_LEFT_CHANNEL" \
    "$ARMED_OBSERVATION_LEFT_TRIM" "$ARMED_OBSERVATION_RIGHT_CHANNEL" \
    "$ARMED_OBSERVATION_RIGHT_TRIM" "$PI_WINDOW_MODE"
  printf ')\n\n'
}

topic_has_publisher() {
  local topic="$1" info count
  info="$(ros2 topic info --no-daemon --spin-time 2 "$topic" 2>/dev/null)" \
    || return 1
  count="$(awk -F': ' '/^Publisher count:/{print $2}' <<<"$info")"
  [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -gt 0 ]
}

all_expected_publishers_present() {
  local topic
  for topic in "${EXPECTED_TOPICS[@]}"; do
    topic_has_publisher "$topic" || return 1
  done
}

wait_for_pi_observer_ready() {
  local deadline="$1"
  [ "$ARMED_OBSERVATION" -eq 1 ] || return 0
  while [ "$SECONDS" -lt "$deadline" ]; do
    monitor_workstation_once || return 1
    if grep -Fq '"phase":"READY"' \
        "$RUN_DIR/fcu_to_vrx_pi_status.json" 2>/dev/null; then
      emit_marker_once FCU_TO_VRX_PI_OBSERVER \
        "FCU_TO_VRX_PI_OBSERVER=READY events=$RUN_DIR/fcu_to_vrx_pi_events.jsonl"
      return 0
    fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  log_error 'FAIL: Pi-side FCU-to-VRX evidence observer did not reach READY'
  return 1
}

wait_for_pi_data_arrival() {
  local start_seconds="$SECONDS" deadline index remaining required rc
  local topic type reliability depth sample
  deadline=$((SECONDS + ARRIVAL_TIMEOUT_SECONDS))

  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  while [ "$SECONDS" -lt "$deadline" ]; do
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return 1
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    if all_expected_publishers_present; then
      [ "$STOP_REQUESTED" -eq 0 ] || return 130
      break
    fi
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  all_expected_publishers_present || {
    log_error \
      "FAIL: seven expected publishers did not arrive within ${ARRIVAL_TIMEOUT_SECONDS}s"
    return 1
  }
  wait_for_pi_observer_ready "$deadline" || return 1
  [ "$STOP_REQUESTED" -eq 0 ] || return 130

  for index in "${!EXPECTED_TOPICS[@]}"; do
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return 1
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    remaining=$((deadline - SECONDS))
    required=$(((${#EXPECTED_TOPICS[@]} - index) * ARRIVAL_SAMPLE_SECONDS))
    [ "$remaining" -ge "$required" ] || {
      log_error \
        "FAIL: insufficient arrival window before sampling ${EXPECTED_TOPICS[$index]}"
      return 1
    }
    topic="${EXPECTED_TOPICS[$index]}"
    type="${EXPECTED_TOPIC_TYPES[$index]}"
    reliability="${EXPECTED_TOPIC_RELIABILITY[$index]}"
    depth="${EXPECTED_TOPIC_DEPTH[$index]}"
    sample="$RUN_DIR/arrival_$((index + 1)).log"
    if python3 "$SCRIPT_DIR/rate_probe.py" --topic "$topic" --type "$type" \
      --reliability "$reliability" --depth "$depth" \
      --duration "$ARRIVAL_SAMPLE_SECONDS" >"$sample" 2>&1; then
      :
    else
      rc=$?
      [ "$STOP_REQUESTED" -eq 0 ] || return 130
      log_error "FAIL: no message from $topic rc=$rc; see $sample"
      return "$rc"
    fi
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
  done
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  monitor_workstation_once || return 1
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  ARRIVAL_ELAPSED_SECONDS=$((SECONDS - start_seconds))
}

run_rate_probe_body() {
  local index topic
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  date -Is || return $?
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  for topic in "${EXPECTED_TOPICS[@]}"; do
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return $?
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    printf '=== %s ===\n' "$topic"
    ros2 topic info --no-daemon --spin-time 3 --verbose "$topic" || return $?
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return $?
  done
  for index in "${!EXPECTED_TOPICS[@]}"; do
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return $?
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    python3 "$SCRIPT_DIR/rate_probe.py" \
      --topic "${EXPECTED_TOPICS[$index]}" \
      --type "${EXPECTED_TOPIC_TYPES[$index]}" \
      --reliability "${EXPECTED_TOPIC_RELIABILITY[$index]}" \
      --depth "${EXPECTED_TOPIC_DEPTH[$index]}" --duration 10 || return $?
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    monitor_workstation_once || return $?
  done
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  monitor_workstation_once
}

run_rate_probes() {
  local body_rc=0 tee_pid tee_rc=0
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  if run_rate_probe_body > >(tee "$RATE_LOG") 2>&1; then
    :
  else
    body_rc=$?
  fi
  tee_pid=$!
  if wait "$tee_pid"; then
    :
  else
    tee_rc=$?
  fi
  [ "$STOP_REQUESTED" -eq 0 ] || return 130
  [ "$body_rc" -eq 0 ] || return "$body_rc"
  [ "$tee_rc" -eq 0 ] || return "$tee_rc"
}

stop_requested() {
  [ "$STOP_REQUESTED" -eq 1 ]
}

record_phase_failure() {
  local phase="$1" rc="$2"
  [ "$rc" -ne 0 ] || rc=1
  [ "$FINAL_RC" -ne 0 ] || FINAL_RC="$rc"
  [ "$SUPERVISOR_FAILED_PHASE" != none ] || SUPERVISOR_FAILED_PHASE="$phase"
  log_error "PHASE_FAIL: phase=$phase rc=$rc preserved_rc=$FINAL_RC"
}

supervise_children() {
  local monitor_fn="${1:-monitor_workstation_once}"
  local stop_fn="${2:-stop_requested}" rc
  while ! "$stop_fn"; do
    if "$monitor_fn"; then
      :
    else
      rc=$?
      return "$rc"
    fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
}

hold_after_failure() {
  local monitor_fn="${1:-monitor_workstation_once}"
  local stop_fn="${2:-stop_requested}"
  set_supervisor_phase failure-hold
  log "FAILURE_HOLD=ACTIVE preserved_rc=$FINAL_RC stop=Ctrl+C"
  while ! "$stop_fn"; do
    if "$monitor_fn"; then :; else :; fi
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
}

run_post_service_phases() {
  local arrival_fn="${1:-wait_for_pi_data_arrival}"
  local probe_fn="${2:-run_rate_probes}"
  local monitor_fn="${3:-monitor_workstation_once}"
  local stop_fn="${4:-stop_requested}" rc

  set_supervisor_phase arrival
  "$stop_fn" && return "$FINAL_RC"
  if "$arrival_fn"; then
    "$stop_fn" && return "$FINAL_RC"
    emit_marker_once PI_DATA_ARRIVED \
      "PI_DATA_ARRIVED=PASS topics=${#EXPECTED_TOPICS[@]} elapsed=${ARRIVAL_ELAPSED_SECONDS}s"
  else
    rc=$?
    "$stop_fn" && return "$FINAL_RC"
    record_phase_failure arrival "$rc"
    hold_after_failure "$monitor_fn" "$stop_fn"
    return "$FINAL_RC"
  fi

  set_supervisor_phase rate-probes
  "$stop_fn" && return "$FINAL_RC"
  if "$probe_fn"; then
    "$stop_fn" && return "$FINAL_RC"
    emit_marker_once W5_RATE_PROBES \
      "W5_RATE_PROBES=PASS topics=${#EXPECTED_TOPICS[@]} duration_each=10s log=$RATE_LOG"
  else
    rc=$?
    "$stop_fn" && return "$FINAL_RC"
    record_phase_failure rate-probes "$rc"
    hold_after_failure "$monitor_fn" "$stop_fn"
    return "$FINAL_RC"
  fi

  set_supervisor_phase supervision
  "$stop_fn" && return "$FINAL_RC"
  if supervise_children "$monitor_fn" "$stop_fn"; then
    return "$FINAL_RC"
  else
    rc=$?
    "$stop_fn" && return "$FINAL_RC"
    record_phase_failure supervision "$rc"
    hold_after_failure "$monitor_fn" "$stop_fn"
    return "$FINAL_RC"
  fi
}

verify_workstation_gone_once() {
  local i port state nodes
  for ((i=0; i<${#CHILD_PGIDS[@]}; i++)); do
    group_alive "${CHILD_PGIDS[$i]}" && return 1
  done
  for port in "${WORKSTATION_PORTS[@]}"; do
    state="$(ss -H -ltn "sport = :$port")" || return 1
    [ -z "$state" ] || return 1
  done
  nodes="$(ros2 node list --no-daemon --spin-time 2)" || return 1
  ! grep -Fxq '/rosbridge_websocket' <<<"$nodes" || return 1
  ! grep -Fxq '/rosapi' <<<"$nodes" || return 1
  ! grep -Fxq '/web_video_server' <<<"$nodes"
}

wait_for_workstation_teardown() {
  local deadline=$((SECONDS + TEARDOWN_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    verify_workstation_gone_once && return 0
    sleep "$SUPERVISOR_POLL_SECONDS" || true
  done
  return 1
}

teardown_workstation_services() {
  local verifier_fn="${1:-wait_for_workstation_teardown}" i
  local teardown_rc=0
  for ((i=${#CHILD_NAMES[@]}-1; i>=0; i--)); do
    stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
      || teardown_rc=1
  done
  if ! "$verifier_fn"; then
    log_error 'WORKSTATION_TEARDOWN=FAIL; inspect logs and local owners'
    teardown_rc=1
  fi
  if [ "$teardown_rc" -eq 0 ] && [ "$SERVICES_UP" -eq 1 ]; then
    emit_marker_once WORKSTATION_TEARDOWN 'WORKSTATION_TEARDOWN=PASS'
  fi
  return "$teardown_rc"
}

cleanup() {
  local incoming_rc=$?
  local cleanup_rc=0 final_rc exit_phase="$SUPERVISOR_PHASE"
  [ "$CLEANING" -eq 0 ] || exit "$incoming_rc"
  CLEANING=1
  trap - EXIT ERR
  trap ':' INT TERM
  set +e
  if [ "$SUPERVISOR_STOP_TRIGGER" = none ]; then
    SUPERVISOR_STOP_TRIGGER=exit
    SUPERVISOR_STOP_SIGNAL=none
    SUPERVISOR_STOP_PHASE="$exit_phase"
    log "SUPERVISOR_STOP trigger=exit signal=none phase=$SUPERVISOR_STOP_PHASE incoming_status=$incoming_rc"
  fi
  set_supervisor_phase teardown
  if [ "${#CHILD_NAMES[@]}" -gt 0 ]; then
    teardown_workstation_services || cleanup_rc=$?
  fi
  [ -z "$RUN_DIR" ] || log "logs=$RUN_DIR"
  final_rc="$incoming_rc"
  [ "$final_rc" -ne 0 ] || final_rc="$FINAL_RC"
  [ "$final_rc" -ne 0 ] || final_rc="$cleanup_rc"
  log "SUPERVISOR_EXIT status=$final_rc trigger=$SUPERVISOR_STOP_TRIGGER signal=$SUPERVISOR_STOP_SIGNAL stop_phase=$SUPERVISOR_STOP_PHASE failed_phase=$SUPERVISOR_FAILED_PHASE cleanup_rc=$cleanup_rc"
  exit "$final_rc"
}

on_supervisor_interrupt() {
  record_stop_trigger INT
  STOP_REQUESTED=1
  if [ "$SERVICES_UP" -eq 0 ]; then
    log 'stop requested before workstation services were ready'
    exit 130
  fi
  log 'stop requested; waiting for orderly workstation teardown'
}

on_supervisor_term() {
  record_stop_trigger TERM
  [ "$FINAL_RC" -ne 0 ] || FINAL_RC=143
  STOP_REQUESTED=1
  if [ "$SERVICES_UP" -eq 0 ]; then
    log 'termination requested before workstation services were ready'
    exit 143
  fi
  log 'termination requested; waiting for orderly workstation teardown'
}

run_workstation_supervisor() {
  local rc
  run_workstation_runtime_preflight

  init_supervisor_state
  trap cleanup EXIT
  trap on_supervisor_interrupt INT
  trap on_supervisor_term TERM
  log "WORKSTATION_RUNTIME_PREFLIGHT=PASS helper=verified ssid=$EXPECTED_SSID dev=$WORKSTATION_INTERFACE ipv4=$WORKSTATION_IP ports=8002,8080,9090"

  set_supervisor_phase service-start
  start_workstation_services
  set_supervisor_phase service-readiness
  if wait_for_workstation_services; then
    SERVICES_UP=1
    emit_marker_once WORKSTATION_SERVICES \
      "WORKSTATION_SERVICES=UP ports=8002,8080,9090 nodes=rosbridge,rosapi,web_video_server logs=$RUN_DIR"
  else
    rc=$?
    exit "$rc"
  fi

  [ "$STOP_REQUESTED" -eq 0 ] || exit "$FINAL_RC"
  set_supervisor_phase pi-command
  if print_pi_command; then
    :
  else
    rc=$?
    record_phase_failure pi-command "$rc"
    hold_after_failure monitor_workstation_once stop_requested
    exit "$FINAL_RC"
  fi

  if run_post_service_phases; then
    rc=0
  else
    rc=$?
  fi
  exit "$rc"
}

run_pi_preflight() {
  local workstation_ip="$1" device port_state route pi_interface ssid

  validate_pi_window_selectors
  [[ "$workstation_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] \
    || fail "invalid workstation IPv4 address: $workstation_ip"

  for command in sha256sum pgrep fuser ss ip iwgetid awk; do
    require_command "$command"
  done

  check_helper_pin
  reject_conflicting_processes Pi "${PI_CONFLICT_PATTERNS[@]}"

  for device in "${PI_DEVICES[@]}"; do
    [ -e "$device" ] || fail "required Pi device missing: $device"
  done
  [ -c /dev/hailo0 ] || fail '/dev/hailo0 is not a character device'
  [ -r /dev/ttyAMA0 ] && [ -w /dev/ttyAMA0 ] \
    || fail '/dev/ttyAMA0 is not readable and writable'
  [ -r "$THERMAL_PATH" ] || fail "thermal sensor unreadable: $THERMAL_PATH"

  reject_device_owners "${PI_DEVICES[@]}"
  port_state="$(ss -H -ulnp 'sport = :14550' 2>&1)" \
    || fail 'cannot inspect Pi UDP port 14550'
  [ -z "$port_state" ] || fail "Pi UDP port 14550 already in use: $port_state"
  if [ "$FCU_TO_VRX_FANOUT" -eq 1 ]; then
    port_state="$(ss -H -ulnp "sport = :$FCU_TO_VRX_INGRESS_PORT" 2>&1)" \
      || fail "cannot inspect Pi UDP port $FCU_TO_VRX_INGRESS_PORT"
    [ -z "$port_state" ] \
      || fail "Pi UDP port $FCU_TO_VRX_INGRESS_PORT already in use: $port_state"
  fi

  route="$(ip -4 route get "$workstation_ip")" \
    || fail "no route to workstation: $workstation_ip"
  [ -n "$route" ] || fail "empty route to workstation: $workstation_ip"
  case " $route " in
    *' via '*) fail "workstation route crosses a gateway: $route" ;;
  esac
  pi_interface="$(awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}' \
    <<<"$route")"
  [ -n "$pi_interface" ] || fail 'cannot derive Pi network interface'
  ssid="$(iwgetid "$pi_interface" --raw)" \
    || fail "cannot read SSID on Pi interface: $pi_interface"
  [ "$ssid" = "$EXPECTED_SSID" ] || fail "unexpected Pi SSID: ${ssid:-NONE}"

  WORKSTATION_IP="$workstation_ip" \
    LIVE_SSID="$EXPECTED_SSID" \
    LIVE_HOLD_AFTER_WINDOW="$PI_HOLD_AFTER_WINDOW" \
    LIVE_FCU_TO_VRX_FANOUT="$FCU_TO_VRX_FANOUT" \
    LIVE_ARMED_OBSERVATION="$ARMED_OBSERVATION" \
    LIVE_ARMED_OBSERVATION_MAX_SECONDS="$ARMED_OBSERVATION_MAX_SECONDS" \
    LIVE_ARMED_OBSERVATION_FINAL_SECONDS="$ARMED_OBSERVATION_FINAL_SECONDS" \
    LIVE_ARMED_OBSERVATION_STALE_SECONDS="$ARMED_OBSERVATION_STALE_SECONDS" \
    LIVE_ARMED_OBSERVATION_LEFT_CHANNEL="$ARMED_OBSERVATION_LEFT_CHANNEL" \
    LIVE_ARMED_OBSERVATION_LEFT_TRIM="$ARMED_OBSERVATION_LEFT_TRIM" \
    LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL="$ARMED_OBSERVATION_RIGHT_CHANNEL" \
    LIVE_ARMED_OBSERVATION_RIGHT_TRIM="$ARMED_OBSERVATION_RIGHT_TRIM" \
    "$HELPER" --preflight-only
  log "P1_PREFLIGHT=PASS workstation=$workstation_ip dev=$pi_interface ssid=$ssid"
}

run_sitl_digital_twin_entry() {
  local runner="$SCRIPT_DIR/sitl_digital_twin_runner.sh"
  [ -r "$runner" ] || fail "SITL runner missing: $runner"
  # shellcheck disable=SC1090
  source "$runner"
  run_sitl_digital_twin
}

main() {
  case "$#:${1:-}" in
    1:workstation) run_workstation_preflight ;;
    1:run) run_workstation_supervisor ;;
    2:pi) run_pi_preflight "$2" ;;
    1:sitl) run_sitl_digital_twin_entry ;;
    *) usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
