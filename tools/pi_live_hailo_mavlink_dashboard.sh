#!/usr/bin/env bash
# Operator-bounded Pi source stack for Hailo overlay and MAVROS telemetry.

set -Eeo pipefail

ROOT="${HAILO_DEMO_ROOT:-$HOME/hailo_coco_overlay_2026-07-10}"
REPO="$ROOT/hailo-apps"
VENV="$ROOT/venv"
HEF="${HAILO_DEMO_HEF:-$ROOT/models/yolov11n-v2.19.0-hailo8l.hef}"
CAM="${HAILO_DEMO_CAM:-/dev/video4}"
SERIAL="${MAVLINK_SERIAL:-/dev/ttyAMA0}"
BAUD="${MAVLINK_BAUD:-57600}"
HEARTBEAT_TIMEOUT="${MAVLINK_HEARTBEAT_TIMEOUT:-30}"
WS_IP="${WORKSTATION_IP:-}"
EXPECTED_SSID="${LIVE_SSID:-IMT Nord Europe 5G}"
DOMAIN="${LIVE_ROS_DOMAIN_ID:-12}"
RUN_SECONDS="${LIVE_RUN_SECONDS:-120}"
HOLD_AFTER_WINDOW="${LIVE_HOLD_AFTER_WINDOW:-0}"
FINAL_VERIFY_SECONDS="${LIVE_FINAL_VERIFY_SECONDS:-180}"
LOCAL_DISPLAY="${HAILO_LOCAL_DISPLAY:-0}"
LOCAL_WINDOW_MODE="${HAILO_LOCAL_WINDOW_MODE:-resizable}"
ABORT_MC="${HAILO_DEMO_ABORT_MC:-80000}"
POLL_S="${LIVE_POLL_SECONDS:-2}"
STREAM_HEIGHT="${HAILO_STREAM_HEIGHT:-240}"
STREAM_FPS="${HAILO_STREAM_FPS:-10}"
THERMAL='/sys/class/thermal/thermal_zone0/temp'
EXPECTED_REPO_SHA='891ce701c2ebe239a5d277759eb75a30f76678a9'
EXPECTED_HEF_SHA='d08e140e61befc4fe3c8e5c2d10969fec258bc411363de6813e8b1778dc7cb8e'
EXPECTED_OBJ_SHA='9f8eca7efc139a423459e87e1715bdf7bc42e1e0a1ecd84b628f62e195e22046'
EXPECTED_TOOL_SHA='c796def8fb99c8337b1ecee64011a2ea4fe099dbe5ea40dff2cd45a2ab848e9d'
OBJ_REL='hailo_apps/python/standalone_apps/object_detection/object_detection.py'
TOOL_REL='hailo_apps/python/core/common/toolbox.py'
IMAGE_TOPIC='/hailo/overlay/image_raw'

RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$ROOT/logs/live_dashboard_$RUN_ID"
HAILO_WRAPPER="$RUN_DIR/hailo_ros_wrapper.py"
SAFETY_MONITOR="$RUN_DIR/dashboard_safety_monitor.py"
THERMAL_WATCHDOG="$RUN_DIR/thermal_watchdog.sh"
MAVPROXY_LOG="$RUN_DIR/mavproxy.log"
MAVROS_LOG="$RUN_DIR/mavros.log"
MAVROS_PLUGINLISTS="$RUN_DIR/mavros_dashboard_plugins.yaml"
SAFETY_LOG="$RUN_DIR/safety_monitor.log"
HAILO_LOG="$RUN_DIR/hailo.log"
THERMAL_LOG="$RUN_DIR/thermal_watchdog.log"
STATE_SAMPLE="$RUN_DIR/mavros_state.yaml"
GPS_SAMPLE="$RUN_DIR/mavros_gps.yaml"
IMU_SAMPLE="$RUN_DIR/mavros_imu.yaml"
BATTERY_SAMPLE="$RUN_DIR/mavros_battery.yaml"
RC_SAMPLE="$RUN_DIR/mavros_rc.yaml"
IMAGE_SAMPLE="$RUN_DIR/hailo_image.yaml"
COMMAND_ABORT_FILE="$RUN_DIR/command_abort.txt"
THERMAL_ABORT_FILE="$RUN_DIR/thermal_abort.txt"
THERMAL_PEAK_FILE="$RUN_DIR/thermal_peak_mc.txt"

declare -a CHILD_NAMES=()
declare -a CHILD_PIDS=()
declare -a CHILD_PGIDS=()
declare -a HAILO_DISPLAY_ARGS=()
declare -a COMMAND_TOPICS=(
  '/planning/mission_command'
  '/planning/set_config'
  '/planning/emergency_stop'
  '/wamv/thrusters/left/thrust'
  '/wamv/thrusters/right/thrust'
)
CLEANING=0
WINDOW_COMPLETE=0
WINDOW_START_SECONDS=0
WINDOW_MONITOR_END_SECONDS=0
HOLD_ACTIVE=0
LIFECYCLE_TRANSITION_ACTIVE=0
STOP_REQUESTED=0
SUPERVISOR_LOG=''
SUPERVISOR_PHASE='initialization'
SUPERVISOR_STOP_TRIGGER='none'
SUPERVISOR_STOP_SIGNAL='none'
SUPERVISOR_STOP_PHASE='none'
SUPERVISOR_FAILED_PHASE='none'
SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')"

append_supervisor_log() {
  local line="$1"
  [ -n "$SUPERVISOR_LOG" ] || return 0
  if ! printf 'timestamp=%s %s\n' "${EPOCHREALTIME:-unknown}" "$line" \
      >>"$SUPERVISOR_LOG"; then
    printf '[live-dashboard] LOG_WRITE_ERROR: path=%s\n' "$SUPERVISOR_LOG" >&2
  fi
  return 0
}

log() {
  local line="[live-dashboard] $*"
  append_supervisor_log "$line"
  printf '%s\n' "$line"
}

log_error() {
  local line="[live-dashboard] $*"
  append_supervisor_log "$line"
  printf '%s\n' "$line" >&2
}

set_supervisor_phase() {
  SUPERVISOR_PHASE="$1"
  log "PI_SUPERVISOR_PHASE=$SUPERVISOR_PHASE"
}

record_stop_trigger() {
  local trigger="$1" signal="$2"
  [ "$SUPERVISOR_STOP_TRIGGER" = none ] || return 0
  SUPERVISOR_STOP_TRIGGER="$trigger"
  SUPERVISOR_STOP_SIGNAL="$signal"
  SUPERVISOR_STOP_PHASE="$SUPERVISOR_PHASE"
  log "PI_SUPERVISOR_STOP trigger=$trigger signal=$signal phase=$SUPERVISOR_STOP_PHASE"
}

finalize_supervisor() {
  local rc="$1" cleanup_rc="$2" final_rc
  if [ "$cleanup_rc" -eq 0 ]; then
    log 'TEARDOWN=PASS'
  else
    log_error 'TEARDOWN=FAIL; inspect remaining processes and topics'
  fi
  final_rc="$rc"
  [ "$final_rc" -ne 0 ] || final_rc="$cleanup_rc"
  log "logs=$RUN_DIR"
  log "PI_SUPERVISOR_EXIT status=$final_rc trigger=$SUPERVISOR_STOP_TRIGGER signal=$SUPERVISOR_STOP_SIGNAL stop_phase=$SUPERVISOR_STOP_PHASE failed_phase=$SUPERVISOR_FAILED_PHASE cleanup_rc=$cleanup_rc"
  return "$final_rc"
}

die() {
  SUPERVISOR_FAILED_PHASE="$SUPERVISOR_PHASE"
  record_stop_trigger failure none
  log_error "STOP: $*"
  exit 1
}

configure_hailo_display() {
  HAILO_DISPLAY_ARGS=(--no-display)
  if [ "$LOCAL_DISPLAY" -eq 0 ]; then
    log 'HAILO_LOCAL_DISPLAY=DISABLED'
    return 0
  fi

  [ -n "${DISPLAY:-}" ] \
    || die 'HAILO_LOCAL_DISPLAY=1 requires a Pi desktop or Remmina terminal with DISPLAY set'
  HAILO_DISPLAY_ARGS=()
  log "HAILO_LOCAL_DISPLAY=ENABLED display=$DISPLAY window_mode=$LOCAL_WINDOW_MODE"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"
}

group_alive() {
  local pgid="$1"
  kill -0 -- "-$pgid" 2>/dev/null
}

stop_group() {
  local name="$1" pgid="$2" pid="$3" signal i
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || return 0
  [ "$pgid" != "$SUPERVISOR_PGID" ] || return 0
  group_alive "$pgid" || { wait "$pid" 2>/dev/null || true; return 0; }

  for signal in INT TERM KILL; do
    kill -"$signal" -- "-$pgid" 2>/dev/null || true
    case "$signal" in
      INT)  for i in 1 2 3 4 5; do group_alive "$pgid" || break; sleep 1; done ;;
      TERM) for i in 1 2 3; do group_alive "$pgid" || break; sleep 1; done ;;
      KILL) sleep 1 ;;
    esac
    group_alive "$pgid" || break
  done
  wait "$pid" 2>/dev/null || true
  if group_alive "$pgid"; then
    log_error "CLEANUP_ERROR: process group still alive name=$name pgid=$pgid"
    return 1
  fi
  log "stopped $name"
}

cleanup() {
  local rc=$? i monitor_index=-1 hailo_index=-1 thermal_index=-1
  local cleanup_rc=0 final_rc hailo_stopped=0
  [ "$CLEANING" -eq 0 ] || exit "$rc"
  CLEANING=1
  trap - EXIT ERR
  trap ':' INT TERM
  set +e

  if [ "$SUPERVISOR_STOP_TRIGGER" = none ]; then
    record_stop_trigger exit none
  fi
  set_supervisor_phase teardown

  if [ "$WINDOW_COMPLETE" -eq 1 ]; then
    for ((i=0; i<${#CHILD_PGIDS[@]}; i++)); do
      kill -0 "${CHILD_PIDS[$i]}" 2>/dev/null \
        && group_alive "${CHILD_PGIDS[$i]}" \
        || cleanup_rc=1
    done
  fi

  for ((i=0; i<${#CHILD_NAMES[@]}; i++)); do
    case "${CHILD_NAMES[$i]}" in
      safety-monitor) monitor_index="$i" ;;
      hailo-bridge) hailo_index="$i" ;;
      thermal-watchdog) thermal_index="$i" ;;
    esac
  done

  # A thermal abort takes priority over normal sentinel-first teardown.
  if [ -s "$THERMAL_ABORT_FILE" ] && [ "$hailo_index" -ge 0 ]; then
    stop_group "${CHILD_NAMES[$hailo_index]}" \
      "${CHILD_PGIDS[$hailo_index]}" "${CHILD_PIDS[$hailo_index]}" \
      || cleanup_rc=1
    hailo_stopped=1
  fi

  if [ "$monitor_index" -ge 0 ]; then
    stop_group "${CHILD_NAMES[$monitor_index]}" \
      "${CHILD_PGIDS[$monitor_index]}" "${CHILD_PIDS[$monitor_index]}" \
      || cleanup_rc=1
  fi
  [ ! -s "$COMMAND_ABORT_FILE" ] || cleanup_rc=1
  [ ! -s "$THERMAL_ABORT_FILE" ] || cleanup_rc=1

  # Keep the independent thermal guard alive until the Hailo workload is gone.
  if [ "$hailo_index" -ge 0 ] && [ "$hailo_stopped" -eq 0 ]; then
    stop_group "${CHILD_NAMES[$hailo_index]}" \
      "${CHILD_PGIDS[$hailo_index]}" "${CHILD_PIDS[$hailo_index]}" \
      || cleanup_rc=1
  fi
  if [ "$thermal_index" -ge 0 ]; then
    stop_group "${CHILD_NAMES[$thermal_index]}" \
      "${CHILD_PGIDS[$thermal_index]}" "${CHILD_PIDS[$thermal_index]}" \
      || cleanup_rc=1
  fi

  for ((i=${#CHILD_PGIDS[@]}-1; i>=0; i--)); do
    [ "$i" -eq "$monitor_index" ] && continue
    [ "$i" -eq "$hailo_index" ] && continue
    [ "$i" -eq "$thermal_index" ] && continue
    stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
      || cleanup_rc=1
  done
  [ ! -s "$COMMAND_ABORT_FILE" ] || cleanup_rc=1
  [ ! -s "$THERMAL_ABORT_FILE" ] || cleanup_rc=1
  if [ -s "$THERMAL_PEAK_FILE" ]; then
    WATCHDOG_PEAK="$(<"$THERMAL_PEAK_FILE")"
    if [[ "$WATCHDOG_PEAK" =~ ^[0-9]+$ ]] && [ "$WATCHDOG_PEAK" -gt "$PEAK_TEMP" ]; then
      PEAK_TEMP="$WATCHDOG_PEAK"
    fi
  fi

  if [ "${ROS_READY:-0}" -eq 1 ]; then
    for i in 1 2 3 4 5; do
      IMAGE_PUBS="$(topic_publishers "$IMAGE_TOPIC" 2>/dev/null)" || IMAGE_PUBS=UNKNOWN
      if [ "$IMAGE_PUBS" = '0' ]; then
        break
      fi
      sleep 1
    done
    [ "$IMAGE_PUBS" = '0' ] || cleanup_rc=1
  fi
  [ -z "$(fuser "$SERIAL" 2>/dev/null || true)" ] || cleanup_rc=1
  [ -z "$(fuser "$CAM" 2>/dev/null || true)" ] || cleanup_rc=1
  [ -z "$(fuser /dev/hailo0 2>/dev/null || true)" ] || cleanup_rc=1
  PORT_STATE="$(ss -H -ulnp 'sport = :14550' 2>/dev/null)"
  [ -z "$PORT_STATE" ] || cleanup_rc=1

  finalize_supervisor "$rc" "$cleanup_rc"
  final_rc=$?
  exit "$final_rc"
}

on_error() {
  local rc=$? line="$1" command="$2"
  SUPERVISOR_FAILED_PHASE="$SUPERVISOR_PHASE"
  record_stop_trigger error none
  log_error "ERROR line=$line rc=$rc command=$command"
  exit "$rc"
}

on_interrupt() {
  record_stop_trigger signal INT
  log 'interrupt received'
  if [ "$LIFECYCLE_TRANSITION_ACTIVE" -eq 1 ]; then
    STOP_REQUESTED=1
    log 'interrupt deferred until lifecycle markers complete'
    return 0
  fi
  if [ "$HOLD_ACTIVE" -eq 1 ]; then
    log 'PI_SOURCE_HOLD=STOP operator-requested'
    exit 0
  fi
  if [ "$WINDOW_COMPLETE" -eq 1 ]; then
    log 'source-window teardown requested after completion'
    exit 0
  fi
  exit 130
}

on_termination() {
  record_stop_trigger signal TERM
  log 'termination received'
  exit 143
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR
trap on_interrupt INT
trap on_termination TERM

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
  LAST_CHILD_PID="$pid"
  LAST_CHILD_PGID="$pgid"
  sleep 0.2
  kill -0 "$pid" 2>/dev/null || die "$name exited during startup; see $logfile"
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || die "cannot determine $name process group"
  [ "$pgid" != "$SUPERVISOR_PGID" ] || die "$name did not enter a separate process group"
  CHILD_PGIDS[$index]="$pgid"
  LAST_CHILD_PGID="$pgid"
  [ "$pgid" = "$pid" ] || die "$name process group is not led by its registered PID"
  log "started $name pid=$pid pgid=$pgid log=$logfile"
}

require_group_alive() {
  local name="$1" pid="$2" pgid="$3" logfile="$4"
  kill -0 "$pid" 2>/dev/null || die "$name leader exited; see $logfile"
  group_alive "$pgid" || die "$name exited; see $logfile"
}

wait_for_mavproxy_heartbeat() {
  local heartbeat_seen=0 heartbeat_deadline link_down_reported=0 first_event
  heartbeat_deadline=$((SECONDS + HEARTBEAT_TIMEOUT))

  while [ "$SECONDS" -lt "$heartbeat_deadline" ]; do
    check_command_sentinel
    require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
    first_event="$(awk '
      /link [0-9]+ down/ { print "link-down"; exit }
      /Detected vehicle [0-9]+:[0-9]+|online system [0-9]+/ {
        print "heartbeat"
        exit
      }
    ' "$MAVPROXY_LOG")"
    if [ "$link_down_reported" -eq 0 ] && [ "$first_event" = 'link-down' ]; then
      link_down_reported=1
      log "MAVPROXY_LINK_DOWN=OBSERVED; waiting for heartbeat deadline=${HEARTBEAT_TIMEOUT}s"
    fi
    if grep -Eq 'Detected vehicle [0-9]+:[0-9]+|online system [0-9]+' "$MAVPROXY_LOG" \
        && [ "$SECONDS" -lt "$heartbeat_deadline" ]; then
      heartbeat_seen=1
      break
    fi
    sleep 1
  done

  if [ "$heartbeat_seen" -eq 0 ]; then
    check_command_sentinel
    require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
    die "MAVProxy heartbeat not seen within ${HEARTBEAT_TIMEOUT}s; see $MAVPROXY_LOG"
  fi

  if [ "$link_down_reported" -eq 1 ]; then
    log 'MAVPROXY_LINK_RECOVERY=PASS; heartbeat arrived before deadline'
  fi
}

ros2_graph_query_before() {
  local deadline="$1"
  shift
  local attempt output='' query_rc remaining
  for attempt in 1 2 3; do
    query_rc=0
    if [ "$deadline" -eq 0 ]; then
      output="$(ros2 "$@" 2>&1)" || query_rc=$?
    else
      remaining=$((deadline - SECONDS))
      [ "$remaining" -gt 0 ] || return 75
      output="$(timeout --signal=KILL "${remaining}s" ros2 "$@" 2>&1)" \
        || query_rc=$?
      if [ "$query_rc" -eq 124 ] || [ "$query_rc" -eq 137 ] \
          || [ "$SECONDS" -ge "$deadline" ]; then
        return 75
      fi
    fi
    if [ "$query_rc" -eq 0 ]; then
      printf '%s\n' "$output"
      return 0
    fi
    if [ "$attempt" -ne 3 ]; then
      if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
        return 75
      fi
      sleep 1
    fi
  done
  printf '%s\n' "$output" >&2
  return 1
}

ros2_graph_query() {
  ros2_graph_query_before 0 "$@"
}

bounded_topic_echo() {
  local deadline="$1" max_timeout="$2"
  shift 2
  local remaining timeout_seconds query_rc=0
  timeout_seconds="$max_timeout"
  if [ "$deadline" -ne 0 ]; then
    remaining=$((deadline - SECONDS))
    [ "$remaining" -gt 0 ] || return 75
    [ "$remaining" -ge "$timeout_seconds" ] || timeout_seconds="$remaining"
    timeout --signal=KILL "${remaining}s" \
      ros2 topic echo --once --timeout "$timeout_seconds" "$@" || query_rc=$?
    if [ "$query_rc" -eq 124 ] || [ "$query_rc" -eq 137 ] \
        || [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
  else
    ros2 topic echo --once --timeout "$timeout_seconds" "$@" || query_rc=$?
  fi
  [ "$query_rc" -ne 75 ] || query_rc=1
  return "$query_rc"
}

require_final_check_result() {
  local result="$1" context="$2" failure="$3"
  [ "$result" -ne 75 ] \
    || die "final verification exceeded ${FINAL_VERIFY_SECONDS}s during $context"
  [ "$result" -eq 0 ] || die "$failure"
}

topic_publishers() {
  local topic="$1" deadline="${2:-0}" topics info count query_rc=0
  topics="$(ros2_graph_query_before "$deadline" topic list --no-daemon --spin-time 2)" \
    || query_rc=$?
  [ "$query_rc" -eq 0 ] || return "$query_rc"
  if ! grep -Fxq "$topic" <<<"$topics"; then
    printf '0\n'
    return 0
  fi
  info="$(ros2_graph_query_before "$deadline" topic info --no-daemon --spin-time 2 "$topic")" \
    || query_rc=$?
  [ "$query_rc" -eq 0 ] || return "$query_rc"
  count="$(awk -F': ' '/^Publisher count:/{print $2}' <<<"$info")"
  [ -n "$count" ] || return 2
  printf '%s\n' "$count"
}

topic_subscriptions() {
  local topic="$1" topics info count
  topics="$(ros2_graph_query topic list --no-daemon --spin-time 2)" || return 2
  if ! grep -Fxq "$topic" <<<"$topics"; then
    printf '0\n'
    return 0
  fi
  info="$(ros2_graph_query topic info --no-daemon --spin-time 2 "$topic")" || return 2
  count="$(awk -F': ' '/^Subscription count:/{print $2}' <<<"$info")"
  [ -n "$count" ] || return 2
  printf '%s\n' "$count"
}

require_publisher_count() {
  local topic="$1" expected="$2" context="$3" deadline="${4:-0}"
  local attempt count='UNKNOWN' query_rc
  for attempt in 1 2 3; do
    query_rc=0
    count="$(topic_publishers "$topic" "$deadline")" || query_rc=$?
    [ "$query_rc" -ne 75 ] || return 75
    if [ "$query_rc" -eq 0 ] && [ "$count" = "$expected" ]; then
      return 0
    fi
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    check_command_sentinel
    check_thermal_watchdog
    [ "$attempt" -eq 3 ] || sleep 1
  done
  die "publisher count failed after 3 attempts during $context: $topic expected=$expected found=$count"
}

graph_nodes() {
  local deadline="${1:-0}"
  ros2_graph_query_before "$deadline" node list --no-daemon --spin-time 2
}

reject_forbidden_nodes() {
  local nodes="$1"
  if grep -Fxq '/camera/camera' <<<"$nodes"; then
    printf '%s\n' "$nodes" >&2
    die 'realsense2_camera detected; stop /camera/camera so Hailo can own the D435I'
  fi
  if grep -Eq '/(heading_controller|waypoint_planner|waypoint_visualizer)(_node)?(/|$)' <<<"$nodes"; then
    printf '%s\n' "$nodes" >&2
    die 'navigation consumer detected; dashboard-only isolation required'
  fi
}

require_workstation_nodes() {
  local nodes="$1"
  grep -Fxq '/rosbridge_websocket' <<<"$nodes" \
    || die 'workstation rosbridge node is not visible from the Pi'
  grep -Fxq '/web_video_server' <<<"$nodes" \
    || die 'workstation web_video_server node is not visible from the Pi'
  grep -Fxq '/rosapi' <<<"$nodes" \
    || die 'workstation rosapi node is not visible from the Pi'
}

reject_command_services() {
  local deadline="${1:-0}" spin_time="${2:-2}"
  local query_error="${3:-cannot inspect ROS services}" attempt services query_rc
  for attempt in 1 2 3; do
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    query_rc=0
    services="$(ros2_graph_query_before "$deadline" service list --no-daemon --spin-time "$spin_time")" \
      || query_rc=$?
    [ "$query_rc" -ne 75 ] || return 75
    [ "$query_rc" -eq 0 ] || die "$query_error"
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    if grep -Eq '^/planning/(stop_mission|generate_waypoints|emergency_stop)$' \
        <<<"$services"; then
      printf '%s\n' "$services" >&2
      die 'dashboard command service server detected; dashboard-only isolation required'
    fi
    if grep -Fxq '/rosapi/topics_for_type' <<<"$services"; then
      return 0
    fi
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    if [ -n "${SAFETY_MONITOR_PID:-}" ]; then
      check_command_sentinel
    fi
    if [ -n "${THERMAL_WATCHDOG_PID:-}" ]; then
      check_thermal_watchdog
    fi
    if [ "$attempt" -ne 3 ]; then
      if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
        return 75
      fi
      sleep 1
    fi
  done
  die 'workstation rosapi topics_for_type service is not visible from the Pi'
}

require_mavros_source() {
  local topic="$1" deadline="${2:-0}"
  local attempt info count nodes node identity_unknown last='query failed' query_rc
  for attempt in 1 2 3; do
    info=''
    nodes=''
    identity_unknown=0
    query_rc=0
    info="$(ros2_graph_query_before "$deadline" topic info --verbose --no-daemon --spin-time 2 "$topic")" \
      || query_rc=$?
    [ "$query_rc" -ne 75 ] || return 75
    if [ "$query_rc" -eq 0 ]; then
      count="$(awk -F': ' '/^Publisher count:/{print $2}' <<<"$info")"
      last="publisher count ${count:-UNKNOWN}"
      if [ "$count" = '1' ]; then
        nodes="$(awk -F': ' '
          /^Node name:/ {name=$2}
          /^Node namespace:/ {namespace=$2}
          /^Endpoint type: PUBLISHER/ {
            if (namespace == "/") print "/" name
            else print namespace "/" name
          }
        ' <<<"$info")"
        if [ -n "$nodes" ]; then
          while IFS= read -r node; do
            case "$node" in
              /mavros|/mavros/*) ;;
              *_NODE_NAMESPACE_UNKNOWN_*|*_NODE_NAME_UNKNOWN_*) identity_unknown=1 ;;
              *) die "unexpected publisher on $topic: $node" ;;
            esac
          done <<<"$nodes"
          if [ "$identity_unknown" -eq 0 ]; then
            return 0
          fi
          last='publisher identity temporarily unknown'
        else
          last='publisher identity unavailable'
        fi
      fi
    fi
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    check_command_sentinel
    [ "$attempt" -eq 3 ] || sleep 1
  done
  die "MAVROS source endpoint failed after 3 attempts: $topic ($last)"
}

sample_connected_disarmed_state() {
  local deadline="${1:-0}"
  bounded_topic_echo "$deadline" 5 /mavros/state mavros_msgs/msg/State \
    >"$STATE_SAMPLE" 2>&1 \
    && grep -q '^connected: true' "$STATE_SAMPLE" \
    && grep -q '^armed: false' "$STATE_SAMPLE"
}

require_connected_disarmed_state() {
  local context="$1" deadline="${2:-0}" attempt sample_rc
  for attempt in 1 2 3; do
    sample_rc=0
    sample_connected_disarmed_state "$deadline" || sample_rc=$?
    [ "$sample_rc" -ne 75 ] || return 75
    if [ "$sample_rc" -eq 0 ]; then
      return 0
    fi
    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      return 75
    fi
    check_command_sentinel
    [ "$attempt" -eq 3 ] || sleep 1
  done
  die "MAVROS connection/disarmed state failed after 3 attempts during $context"
}

initial_graph_gate() {
  local nodes topics topic info pubs subs
  nodes="$(ros2_graph_query node list --no-daemon --spin-time 3)" \
    || die 'cannot inspect the initial ROS node graph'
  reject_forbidden_nodes "$nodes"
  require_workstation_nodes "$nodes"
  if grep -Eq '/(mavros|live_dashboard_safety_monitor|hailo_overlay_bridge)(/|$)' <<<"$nodes"; then
    printf '%s\n' "$nodes" >&2
    die 'existing live-integration node detected'
  fi

  reject_command_services 0 3 'cannot inspect the initial ROS service graph'

  topics="$(ros2_graph_query topic list --no-daemon --spin-time 3)" \
    || die 'cannot inspect the initial ROS topic graph'
  for topic in "$IMAGE_TOPIC" "${COMMAND_TOPICS[@]}"; do
    grep -Fxq "$topic" <<<"$topics" || continue
    info="$(ros2_graph_query topic info --no-daemon --spin-time 3 "$topic")" \
      || die "cannot inspect initial endpoints on $topic"
    pubs="$(awk -F': ' '/^Publisher count:/{print $2}' <<<"$info")"
    subs="$(awk -F': ' '/^Subscription count:/{print $2}' <<<"$info")"
    [ "$pubs" = '0' ] && [ "$subs" = '0' ] \
      || die "existing endpoint on $topic (publishers=${pubs:-UNKNOWN}, subscribers=${subs:-UNKNOWN}); stop dummy/simulation/control/browser clients"
  done
}

reject_unexpected_command_subscribers() {
  local deadline="${1:-0}" topic attempt info nodes node identity_unknown verified query_rc
  for topic in "${COMMAND_TOPICS[@]}"; do
    verified=0
    for attempt in 1 2 3; do
      info=''
      nodes=''
      identity_unknown=0
      query_rc=0
      info="$(ros2_graph_query_before "$deadline" topic info --verbose --no-daemon --spin-time 2 "$topic")" \
        || query_rc=$?
      [ "$query_rc" -ne 75 ] || return 75
      if [ "$query_rc" -eq 0 ]; then
        nodes="$(awk -F': ' '
          /^Node name:/ {name=$2}
          /^Node namespace:/ {namespace=$2}
          /^Endpoint type: SUBSCRIPTION/ {
            if (namespace == "/") print "/" name
            else print namespace "/" name
          }
        ' <<<"$info")"
        if [ -n "$nodes" ]; then
          while IFS= read -r node; do
            case "$node" in
              /live_dashboard_safety_monitor|/rosbridge_websocket) ;;
              *_NODE_NAMESPACE_UNKNOWN_*|*_NODE_NAME_UNKNOWN_*) identity_unknown=1 ;;
              *) die "unexpected command-topic subscriber on $topic: $node" ;;
            esac
          done <<<"$nodes"
          if [ "$identity_unknown" -eq 0 ]; then
            verified=1
            break
          fi
        fi
      fi
      if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
        return 75
      fi
      check_command_sentinel
      [ "$attempt" -eq 3 ] || sleep 1
    done
    [ "$verified" -eq 1 ] \
      || die "command sentinel identity unavailable after 3 attempts: $topic"
  done
}

check_power() {
  local context="$1" output
  if command -v vcgencmd >/dev/null 2>&1 \
      && output="$(vcgencmd get_throttled 2>/dev/null)" \
      && [[ "$output" =~ ^throttled=0x[0-9A-Fa-f]+$ ]]; then
    POWER_TELEMETRY_AVAILABLE=1
    [ "$output" = 'throttled=0x0' ] \
      || die "power/undervoltage flags present during $context: $output"
    log "power=$output phase=$context"
  elif [ "$POWER_TELEMETRY_AVAILABLE" -eq 1 ]; then
    die "power telemetry became unavailable during $context"
  elif [ "$POWER_UNAVAILABLE_REPORTED" -eq 0 ]; then
    POWER_UNAVAILABLE_REPORTED=1
    log 'POWER_TELEMETRY=UNAVAILABLE; thermal guard remains active'
  fi
}

check_command_sentinel() {
  [ ! -s "$COMMAND_ABORT_FILE" ] || {
    sed -n '1,5p' "$COMMAND_ABORT_FILE" >&2
    die 'dashboard command publication detected'
  }
  require_group_alive safety-monitor \
    "$SAFETY_MONITOR_PID" "$SAFETY_MONITOR_PGID" "$SAFETY_LOG"
}

check_thermal_watchdog() {
  [ ! -s "$THERMAL_ABORT_FILE" ] || {
    sed -n '1,5p' "$THERMAL_ABORT_FILE" >&2
    die 'independent thermal watchdog aborted the Hailo workload'
  }
  require_group_alive thermal-watchdog \
    "$THERMAL_WATCHDOG_PID" "$THERMAL_WATCHDOG_PGID" "$THERMAL_LOG"
}

read_temp() {
  local value
  value="$(<"$THERMAL")" || return 1
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$value"
}

check_temperature() {
  local context="$1" temp
  if temp="$(read_temp)"; then
    BAD_TEMP_READS=0
    [ "$temp" -le "$PEAK_TEMP" ] || PEAK_TEMP="$temp"
    [ "$temp" -lt "$ABORT_MC" ] \
      || die "temperature $((temp / 1000))C reached abort threshold during $context"
    log "temp=$((temp / 1000))C peak=$((PEAK_TEMP / 1000))C phase=$context"
  else
    BAD_TEMP_READS=$((BAD_TEMP_READS + 1))
    [ "$BAD_TEMP_READS" -lt 3 ] \
      || die "thermal sensor failed three consecutive reads during $context"
  fi
}

final_graph_verification() {
  local deadline="$1" nodes result=0 source_topic

  nodes="$(graph_nodes "$deadline")" || result=$?
  [ "$result" -eq 0 ] || return "$result"
  reject_forbidden_nodes "$nodes"
  require_workstation_nodes "$nodes"
  check_command_sentinel
  check_thermal_watchdog

  reject_command_services "$deadline" || result=$?
  [ "$result" -eq 0 ] || return "$result"
  check_command_sentinel
  check_thermal_watchdog
  reject_unexpected_command_subscribers "$deadline" || result=$?
  [ "$result" -eq 0 ] || return "$result"
  check_command_sentinel
  check_thermal_watchdog
  require_publisher_count "$IMAGE_TOPIC" 1 final-verification "$deadline" || result=$?
  [ "$result" -eq 0 ] || return "$result"
  check_command_sentinel
  check_thermal_watchdog

  for source_topic in \
    /mavros/state \
    /mavros/global_position/raw/fix \
    /mavros/imu/data \
    /mavros/battery \
    /mavros/rc/in; do
    require_mavros_source "$source_topic" "$deadline" || result=$?
    [ "$result" -eq 0 ] || return "$result"
    check_command_sentinel
    check_thermal_watchdog
  done
}

monitor_live_stack() {
  local context="$1" deadline="$2"
  local next_graph_check=$SECONDS next_state_check=$SECONDS
  local next_power_check=$SECONDS graph_phase=0 nodes phase_rc source_topic remaining

  while [ "$deadline" -eq 0 ] || [ "$SECONDS" -lt "$deadline" ]; do
    check_command_sentinel
    check_thermal_watchdog
    require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
    require_group_alive mavros "$MAVROS_PID" "$MAVROS_PGID" "$MAVROS_LOG"
    require_group_alive hailo-bridge "$HAILO_PID" "$HAILO_PGID" "$HAILO_LOG"

    check_temperature "$context"
    if [ "$deadline" -eq 0 ]; then
      log "hold_elapsed=$((SECONDS - HOLD_START_SECONDS))s"
    else
      log "remaining=$((deadline - SECONDS))s"
    fi

    if [ "$SECONDS" -ge "$next_graph_check" ]; then
      case "$graph_phase" in
        0)
          phase_rc=0
          nodes="$(graph_nodes "$deadline")" || phase_rc=$?
          [ "$phase_rc" -ne 75 ] || break
          [ "$phase_rc" -eq 0 ] || die 'cannot inspect the ROS node graph'
          reject_forbidden_nodes "$nodes"
          require_workstation_nodes "$nodes"
          phase_rc=0
          if reject_command_services "$deadline"; then
            :
          else
            phase_rc=$?
            [ "$phase_rc" -eq 75 ] && break
            return "$phase_rc"
          fi
          ;;
        1)
          phase_rc=0
          reject_unexpected_command_subscribers "$deadline" || phase_rc=$?
          [ "$phase_rc" -ne 75 ] || break
          [ "$phase_rc" -eq 0 ] || return "$phase_rc"
          ;;
        2)
          phase_rc=0
          require_publisher_count "$IMAGE_TOPIC" 1 "$context" "$deadline" || phase_rc=$?
          [ "$phase_rc" -ne 75 ] || break
          [ "$phase_rc" -eq 0 ] || return "$phase_rc"
          ;;
        3)
          for source_topic in \
            /mavros/state \
            /mavros/global_position/raw/fix \
            /mavros/imu/data \
            /mavros/battery \
            /mavros/rc/in; do
            phase_rc=0
            require_mavros_source "$source_topic" "$deadline" || phase_rc=$?
            if [ "$phase_rc" -eq 75 ]; then
              break 2
            fi
            [ "$phase_rc" -eq 0 ] || return "$phase_rc"
          done
          ;;
      esac
      check_thermal_watchdog
      graph_phase=$(((graph_phase + 1) % 4))
      next_graph_check=$((SECONDS + 1))
    fi

    if [ "$deadline" -ne 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
      break
    fi

    if [ "$SECONDS" -ge "$next_state_check" ]; then
      phase_rc=0
      require_connected_disarmed_state "$context" "$deadline" || phase_rc=$?
      [ "$phase_rc" -ne 75 ] || break
      [ "$phase_rc" -eq 0 ] || return "$phase_rc"
      next_state_check=$((SECONDS + 4))
    fi

    if [ "$SECONDS" -ge "$next_power_check" ]; then
      check_power "$context"
      next_power_check=$((SECONDS + 10))
    fi

    if [ "$deadline" -ne 0 ]; then
      remaining=$((deadline - SECONDS))
      [ "$remaining" -gt 0 ] || break
      if [ "$remaining" -lt "$POLL_S" ]; then
        sleep "$remaining"
        break
      fi
    fi
    sleep "$POLL_S"
  done
}

complete_source_window() {
  local monitored_seconds final_verification_seconds
  monitored_seconds=$((WINDOW_MONITOR_END_SECONDS - WINDOW_START_SECONDS))
  final_verification_seconds=$((SECONDS - WINDOW_MONITOR_END_SECONDS))
  WINDOW_ELAPSED_SECONDS=$((SECONDS - WINDOW_START_SECONDS))
  LIFECYCLE_TRANSITION_ACTIVE=1
  set_supervisor_phase source-window-complete
  log 'COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed'
  log "PI_SOURCE_WINDOW=COMPLETE target=${RUN_SECONDS}s monitored=${monitored_seconds}s final_verification=${final_verification_seconds}s elapsed=${WINDOW_ELAPSED_SECONDS}s peak=$((PEAK_TEMP / 1000))C"
  WINDOW_COMPLETE=1

  if [ "$HOLD_AFTER_WINDOW" -eq 1 ]; then
    HOLD_START_SECONDS=$SECONDS
    set_supervisor_phase live-hold
    log 'PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C'
    HOLD_ACTIVE=1
  else
    set_supervisor_phase post-window
  fi
  LIFECYCLE_TRANSITION_ACTIVE=0

  if [ "$STOP_REQUESTED" -eq 1 ]; then
    if [ "$HOLD_ACTIVE" -eq 1 ]; then
      log 'PI_SOURCE_HOLD=STOP operator-requested'
    else
      log 'source-window teardown requested after completion'
    fi
    exit 0
  fi

  if [ "$HOLD_ACTIVE" -eq 1 ]; then
    monitor_live_stack live-hold 0
  fi
}

run_hailo_ros_preflight() {
  local stripped_output stripped_rc

  stripped_rc=0
  if stripped_output="$(env \
      -u ROS_DISTRO -u ROS_VERSION -u PYTHONPATH -u AMENT_PREFIX_PATH \
      -u COLCON_PREFIX_PATH -u CMAKE_PREFIX_PATH \
      "$VENV/bin/python" -c \
      'import rclpy; print(rclpy.__file__)' 2>&1)"; then
    log "CANONICAL_STRIPPED_RCLPY=AVAILABLE informational path=$stripped_output"
  else
    stripped_rc=$?
    log "CANONICAL_STRIPPED_RCLPY=UNAVAILABLE informational rc=$stripped_rc"
    printf '%s\n' "$stripped_output"
  fi

  HAILO_APPS_REPO="$REPO" \
  PYTHONPATH="$REPO${PYTHONPATH:+:$PYTHONPATH}" \
  "$VENV/bin/python" - <<'PYTHON_PREFLIGHT'
import os

import cv2
import numpy
import rclpy
import sensor_msgs.msg
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from rclpy.signals import SignalHandlerOptions
from sensor_msgs.msg import Image

from hailo_apps.python.standalone_apps.object_detection import object_detection as detector


for name, module in (
    ("cv2", cv2),
    ("numpy", numpy),
    ("rclpy", rclpy),
    ("sensor_msgs", sensor_msgs.msg),
    ("detector", detector),
):
    print(f"PREFLIGHT_PROVENANCE {name}={getattr(module, '__file__', 'BUILTIN')}")

assert os.path.realpath(detector.__file__).startswith(
    os.path.realpath(os.environ["HAILO_APPS_REPO"]) + os.sep
)
assert callable(detector.visualize)
assert "visualize" in detector.run_inference_pipeline.__globals__

original_visualize = detector.visualize


def preflight_marker(*args, **kwargs):
    return None


try:
    detector.visualize = preflight_marker
    assert detector.run_inference_pipeline.__globals__["visualize"] is preflight_marker
finally:
    detector.visualize = original_visualize

rclpy.init(signal_handler_options=SignalHandlerOptions.NO)
node = rclpy.create_node("hailo_ros_preflight")
publisher = None
try:
    publisher = node.create_publisher(
        Image,
        "/hailo/preflight/image_raw",
        QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
        ),
    )
    message = Image()
    message.height = 1
    message.width = 1
    message.encoding = "bgr8"
    message.step = 3
    message.data = b"\x00\x00\x00"
    assert publisher is not None
finally:
    if publisher is not None:
        node.destroy_publisher(publisher)
    node.destroy_node()
    rclpy.try_shutdown()

print("HAILO_ROS_PREFLIGHT=PASS imports=5 monkeypatch=PASS publisher=RELIABLE")
PYTHON_PREFLIGHT
}

PREFLIGHT_ONLY=0
case "$#:${1:-}" in
  0:) ;;
  1:--preflight-only) PREFLIGHT_ONLY=1 ;;
  *) die 'usage: pi_live_hailo_mavlink_dashboard.sh [--preflight-only]' ;;
esac

[[ "$RUN_SECONDS" =~ ^[1-9][0-9]*$ ]] || die 'LIVE_RUN_SECONDS must be a positive integer'
[[ "$HOLD_AFTER_WINDOW" =~ ^[01]$ ]] \
  || die 'LIVE_HOLD_AFTER_WINDOW must be 0 or 1'
[[ "$FINAL_VERIFY_SECONDS" =~ ^[1-9][0-9]*$ ]] \
  || die 'LIVE_FINAL_VERIFY_SECONDS must be a positive integer'
[[ "$LOCAL_DISPLAY" =~ ^[01]$ ]] \
  || die 'HAILO_LOCAL_DISPLAY must be 0 or 1'
[[ "$LOCAL_WINDOW_MODE" =~ ^(resizable|fullscreen)$ ]] \
  || die 'HAILO_LOCAL_WINDOW_MODE must be resizable or fullscreen'
[[ "$ABORT_MC" =~ ^[1-9][0-9]*$ ]] || die 'HAILO_DEMO_ABORT_MC must be a positive integer'
[[ "$POLL_S" =~ ^[1-9][0-9]*$ ]] || die 'LIVE_POLL_SECONDS must be a positive integer'
[[ "$STREAM_HEIGHT" =~ ^[1-9][0-9]*$ ]] || die 'HAILO_STREAM_HEIGHT must be a positive integer'
[[ "$STREAM_FPS" =~ ^[1-9][0-9]*$ ]] || die 'HAILO_STREAM_FPS must be a positive integer'
[[ "$BAUD" =~ ^[1-9][0-9]*$ ]] || die 'MAVLINK_BAUD must be a positive integer'
[[ "$HEARTBEAT_TIMEOUT" =~ ^[1-9][0-9]*$ ]] \
  || die 'MAVLINK_HEARTBEAT_TIMEOUT must be a positive integer'
[[ "$DOMAIN" =~ ^[0-9]+$ ]] || die 'LIVE_ROS_DOMAIN_ID must be a non-negative integer'

if [ "$PREFLIGHT_ONLY" -eq 0 ]; then
  mkdir -p "$RUN_DIR"
  SUPERVISOR_LOG="$RUN_DIR/supervisor.log"
  if ! : >"$SUPERVISOR_LOG"; then
    SUPERVISOR_LOG=''
    die "cannot create Pi supervisor lifecycle log: $RUN_DIR/supervisor.log"
  fi
  PEAK_TEMP=0
  trap cleanup EXIT
  HELPER_SHA256="$(sha256sum "$0" | awk '{print $1}')" \
    || die 'cannot calculate Pi helper checksum'
  log "PI_SUPERVISOR_START pid=$BASHPID pgid=$SUPERVISOR_PGID helper_sha256=$HELPER_SHA256 phase=$SUPERVISOR_PHASE"
  set_supervisor_phase runtime-preflight
fi
configure_hailo_display

for command in git sha256sum ps awk grep python3 env; do
  require_command "$command"
done

MODEL="$(tr -d '\0' 2>/dev/null </proc/device-tree/model || true)"
case "$MODEL" in
  *Raspberry\ Pi\ 5*) ;;
  *) die "unexpected host model: ${MODEL:-UNKNOWN}" ;;
esac

[ -d "$REPO/.git" ] || die "Hailo checkout missing: $REPO"
[ -x "$VENV/bin/python" ] || die "Hailo venv missing: $VENV"
[ -r "$REPO/$OBJ_REL" ] || die "runner missing: $REPO/$OBJ_REL"
[ -r "$REPO/$TOOL_REL" ] || die "toolbox missing: $REPO/$TOOL_REL"

ACTUAL_SHA="$(git -C "$REPO" rev-parse HEAD)" || die 'cannot read Hailo checkout SHA'
[ "$ACTUAL_SHA" = "$EXPECTED_REPO_SHA" ] || die "Hailo checkout SHA mismatch: $ACTUAL_SHA"
[ -z "$(git -C "$REPO" status --porcelain=v1 --untracked-files=all --ignore-submodules=none)" ] \
  || die 'Hailo checkout is dirty'
printf '%s  %s\n' "$EXPECTED_OBJ_SHA" "$REPO/$OBJ_REL" | sha256sum -c -
printf '%s  %s\n' "$EXPECTED_TOOL_SHA" "$REPO/$TOOL_REL" | sha256sum -c -

[ -r /opt/ros/jazzy/setup.bash ] || die 'ROS Jazzy setup missing'
set +u
# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
set -u
ROS_READY=1
export ROS_DOMAIN_ID="$DOMAIN"
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI

run_hailo_ros_preflight
if [ "$PREFLIGHT_ONLY" -eq 1 ]; then
  log 'PREFLIGHT_ONLY=PASS hardware=camera,hailo,serial,fcu untouched'
  exit 0
fi

[ -n "$WS_IP" ] || die 'WORKSTATION_IP is required for a live run'

cat >"$MAVROS_PLUGINLISTS" <<'YAML'
/**:
  ros__parameters:
    plugin_allowlist:
      - sys_status
      - global_position
      - imu
      - rc_io
YAML

for command in fuser ss setsid iwgetid ip install ros2 timeout; do
  require_command "$command"
done

[ -r "$HEF" ] || die "HEF missing: $HEF"
[ -c /dev/hailo0 ] || die '/dev/hailo0 missing'
[ -e "$CAM" ] || die "camera missing: $CAM"
[ -e "$SERIAL" ] || die "MAVLink serial endpoint missing: $SERIAL"
[ -r "$SERIAL" ] && [ -w "$SERIAL" ] || die "MAVLink serial endpoint is not readable/writable: $SERIAL"
[ -r "$THERMAL" ] || die "thermal sensor unreadable: $THERMAL"
printf '%s  %s\n' "$EXPECTED_HEF_SHA" "$HEF" | sha256sum -c -

[ -z "$(fuser "$SERIAL" 2>/dev/null || true)" ] || die "$SERIAL already in use"
[ -z "$(fuser "$CAM" 2>/dev/null || true)" ] || die "$CAM already in use"
[ -z "$(fuser /dev/hailo0 2>/dev/null || true)" ] || die '/dev/hailo0 already in use'
PORT_STATE="$(ss -H -ulnp 'sport = :14550' 2>&1)" || die 'cannot inspect UDP port 14550'
[ -z "$PORT_STATE" ] || die "UDP port 14550 unavailable: $PORT_STATE"

ROUTE="$(ip -4 route get "$WS_IP")" || die "no route to workstation $WS_IP"
[ -n "$ROUTE" ] || die "empty route to workstation $WS_IP"
case " $ROUTE " in *' via '*) die "workstation route crosses gateway: $ROUTE" ;; esac
PI_IF="$(awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}' <<<"$ROUTE")"
[ -n "$PI_IF" ] || die 'cannot derive Pi network interface'
SSID="$(iwgetid "$PI_IF" --raw)" || die "cannot read SSID on $PI_IF"
[ "$SSID" = "$EXPECTED_SSID" ] || die "unexpected SSID: ${SSID:-NONE}"

ros2 pkg prefix mavros >/dev/null || die 'mavros package missing'
ros2 pkg prefix mavros_msgs >/dev/null || die 'mavros_msgs package missing'
MAVPROXY="${MAVPROXY_BIN:-$(command -v mavproxy.py || true)}"
[ -x "$MAVPROXY" ] || die 'mavproxy.py missing or not executable'
MAVPROXY_USER_BASE="$(python3 -m site --user-base)" \
  || die 'cannot resolve the MAVProxy Python user base'
MAVPROXY_HOME="$RUN_DIR/mavproxy_home"
install -d -m 0700 "$MAVPROXY_HOME"
MAVPROXY_VERSION="$(env HOME="$MAVPROXY_HOME" PYTHONUSERBASE="$MAVPROXY_USER_BASE" \
  "$MAVPROXY" --version 2>&1)" \
  || die 'MAVProxy cannot start with isolated HOME; check its user-site install'
log "MAVPROXY_IMPORT_GATE=PASS version=$MAVPROXY_VERSION"

initial_graph_gate
sleep 2
initial_graph_gate
log 'INITIAL_ROS_GRAPH=PASS stable_snapshots=2'

START_TEMP="$(read_temp)" || die 'initial thermal read failed'
[ "$START_TEMP" -lt "$ABORT_MC" ] \
  || die "initial temperature $((START_TEMP / 1000))C is at/above abort threshold"
PEAK_TEMP="$START_TEMP"
BAD_TEMP_READS=0
POWER_TELEMETRY_AVAILABLE=0
POWER_UNAVAILABLE_REPORTED=0
check_power initial

cat >"$HAILO_WRAPPER" <<'PYTHON_HAILO'
#!/usr/bin/env python3
import os
import sys
import time

import cv2
import numpy as np
import rclpy
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from rclpy.signals import SignalHandlerOptions
from sensor_msgs.msg import Image

repo = os.environ["HAILO_APPS_REPO"]
sys.path.insert(0, repo)

from hailo_apps.python.standalone_apps.object_detection import object_detection as detector

stream_height = int(os.environ["HAILO_STREAM_HEIGHT"])
stream_fps = int(os.environ["HAILO_STREAM_FPS"])
period_ns = int(1_000_000_000 / stream_fps)

rclpy.init(signal_handler_options=SignalHandlerOptions.NO)
node = rclpy.create_node("hailo_overlay_bridge")
publisher = node.create_publisher(
    Image,
    "/hailo/overlay/image_raw",
    QoSProfile(
        history=HistoryPolicy.KEEP_LAST,
        depth=1,
        reliability=ReliabilityPolicy.RELIABLE,
        durability=DurabilityPolicy.VOLATILE,
    ),
)

original_visualize = detector.visualize
state = {"last_publish_ns": 0, "count": 0}
window_name = "Output"
window_state = {
    "callback_count": 0,
    "fullscreen_pending": False,
    "rect_pending": False,
}


def configure_local_window(visualization_settings):
    if visualization_settings.no_display:
        return

    window_mode = os.environ["HAILO_LOCAL_WINDOW_MODE"]
    try:
        cv2.namedWindow(
            window_name,
            cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO,
        )
    except cv2.error as exc:
        visualization_settings.no_display = True
        try:
            cv2.destroyWindow(window_name)
        except cv2.error:
            pass
        print(
            f"HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS mode={window_mode} "
            f"stage=namedWindow error={type(exc).__name__}",
            flush=True,
        )
        return

    if window_mode == "fullscreen":
        window_state["fullscreen_pending"] = True
        print(
            f"HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name={window_name} "
            "gate=first-imshow",
            flush=True,
        )
        return

    print(
        f"HAILO_LOCAL_WINDOW=READY mode={window_mode} name={window_name}",
        flush=True,
    )
def advance_fullscreen_gate(visualization_settings):
    if visualization_settings.no_display:
        return
    if not (
        window_state["fullscreen_pending"] or window_state["rect_pending"]
    ):
        return

    window_state["callback_count"] += 1
    if window_state["fullscreen_pending"]:
        if window_state["callback_count"] < 2:
            return
        try:
            cv2.setWindowProperty(
                window_name,
                cv2.WND_PROP_FULLSCREEN,
                cv2.WINDOW_FULLSCREEN,
            )
        except cv2.error as exc:
            print(
                "HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE requested=fullscreen "
                f"error={type(exc).__name__}",
                flush=True,
            )
            window_state["fullscreen_pending"] = False
            return
        window_state["fullscreen_pending"] = False
        window_state["rect_pending"] = True
        return

    if window_state["callback_count"] < 3:
        return
    try:
        x, y, width, height = cv2.getWindowImageRect(window_name)
    except cv2.error as exc:
        print(
            "HAILO_LOCAL_WINDOW=EVIDENCE_UNAVAILABLE mode=fullscreen "
            f"name={window_name} stage=getWindowImageRect "
            f"error={type(exc).__name__}",
            flush=True,
        )
    else:
        rect = f"{x},{y},{width},{height}"
        print(
            f"HAILO_LOCAL_WINDOW=READY mode=fullscreen name={window_name} "
            f"rect={rect} source=getWindowImageRect",
            flush=True,
        )
    window_state["rect_pending"] = False


def publishing_visualize(
    input_context,
    visualization_settings,
    output_queue,
    callback,
    fps_tracker=None,
    stop_event=None,
):
    configure_local_window(visualization_settings)

    def callback_and_publish(*args, **kwargs):
        advance_fullscreen_gate(visualization_settings)
        annotated_rgb = callback(*args, **kwargs)
        now_ns = time.monotonic_ns()
        if now_ns - state["last_publish_ns"] < period_ns:
            return annotated_rgb

        height, width = annotated_rgb.shape[:2]
        scale = min(1.0, stream_height / float(height))
        if scale < 1.0:
            stream_rgb = cv2.resize(
                annotated_rgb,
                (int(round(width * scale)), stream_height),
                interpolation=cv2.INTER_AREA,
            )
        else:
            stream_rgb = annotated_rgb
        stream_bgr = np.ascontiguousarray(
            cv2.cvtColor(stream_rgb, cv2.COLOR_RGB2BGR)
        )

        message = Image()
        message.header.stamp = node.get_clock().now().to_msg()
        message.header.frame_id = "hailo_overlay"
        message.height, message.width = stream_bgr.shape[:2]
        message.encoding = "bgr8"
        message.is_bigendian = 0
        message.step = message.width * 3
        message.data = stream_bgr.tobytes()
        publisher.publish(message)

        state["last_publish_ns"] = now_ns
        state["count"] += 1
        if state["count"] == 1 or state["count"] % 100 == 0:
            print(
                f'HAILO_ROS_FRAME count={state["count"]} '
                f'size={message.width}x{message.height}',
                flush=True,
            )
        return annotated_rgb

    return original_visualize(
        input_context,
        visualization_settings,
        output_queue,
        callback_and_publish,
        fps_tracker,
        stop_event,
    )


detector.visualize = publishing_visualize
print(
    f"HAILO_BRIDGE_READY topic=/hailo/overlay/image_raw "
    f"height={stream_height} max_fps={stream_fps}",
    flush=True,
)
try:
    detector.main()
finally:
    node.destroy_node()
    rclpy.try_shutdown()
PYTHON_HAILO

cat >"$SAFETY_MONITOR" <<'PYTHON_SAFETY'
#!/usr/bin/env python3
import os

import rclpy
from mavros_msgs.msg import State
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from rclpy.signals import SignalHandlerOptions
from std_msgs.msg import Bool, Float64, String

abort_file = os.environ["COMMAND_ABORT_FILE"]


class DashboardSafetyMonitor(Node):
    def __init__(self):
        super().__init__("live_dashboard_safety_monitor")
        state_qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
        command_qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )

        self.abort_violation = False
        self.fcu_connected_once = False

        self.create_subscription(
            String,
            "/planning/mission_command",
            lambda message: self.abort_seen("COMMAND", "/planning/mission_command"),
            command_qos,
        )
        self.create_subscription(
            String,
            "/planning/set_config",
            lambda message: self.abort_seen("COMMAND", "/planning/set_config"),
            command_qos,
        )
        self.create_subscription(
            Bool,
            "/planning/emergency_stop",
            lambda message: self.abort_seen("COMMAND", "/planning/emergency_stop"),
            command_qos,
        )
        self.create_subscription(
            Float64,
            "/wamv/thrusters/left/thrust",
            lambda message: self.abort_seen("COMMAND", "/wamv/thrusters/left/thrust"),
            command_qos,
        )
        self.create_subscription(
            Float64,
            "/wamv/thrusters/right/thrust",
            lambda message: self.abort_seen("COMMAND", "/wamv/thrusters/right/thrust"),
            command_qos,
        )
        self.create_subscription(State, "/mavros/state", self.check_state, state_qos)
        print(
            "DASHBOARD_SAFETY_MONITOR_READY topics=5 state=/mavros/state "
            "publishers=0",
            flush=True,
        )

    def check_state(self, message):
        if message.armed:
            self.abort_seen("FCU_ARMED", "/mavros/state")
        elif message.connected:
            self.fcu_connected_once = True
        elif self.fcu_connected_once:
            self.abort_seen("FCU_DISCONNECTED", "/mavros/state")

    def abort_seen(self, reason, topic):
        if self.abort_violation:
            return
        self.abort_violation = True
        with open(abort_file, "w", encoding="utf-8") as stream:
            stream.write(f"reason={reason} topic={topic}\n")
        print(f"{reason}_ABORT topic={topic}", flush=True)
        rclpy.try_shutdown()


rclpy.init(signal_handler_options=SignalHandlerOptions.NO)
node = DashboardSafetyMonitor()
exit_code = 0
try:
    rclpy.spin(node)
except (KeyboardInterrupt, ExternalShutdownException):
    pass
finally:
    if node.abort_violation:
        exit_code = 70
    node.destroy_node()
    rclpy.try_shutdown()
raise SystemExit(exit_code)
PYTHON_SAFETY

cat >"$THERMAL_WATCHDOG" <<'SHELL_THERMAL'
#!/usr/bin/env bash
set -uo pipefail

: "${THERMAL_PATH:?}"
: "${ABORT_MC:?}"
: "${HAILO_PGID:?}"
: "${SUPERVISOR_PID:?}"
: "${THERMAL_ABORT_FILE:?}"
: "${THERMAL_PEAK_FILE:?}"

failures=0
peak=0

stop_hot_workload() {
  local reason="$1" unused
  printf 'reason=%s timestamp=%s\n' "$reason" "$(date --iso-8601=seconds)" \
    >"$THERMAL_ABORT_FILE"
  kill -TERM -- "-$HAILO_PGID" 2>/dev/null || true
  kill -TERM "$SUPERVISOR_PID" 2>/dev/null || true
  for unused in 1 2 3; do
    kill -0 -- "-$HAILO_PGID" 2>/dev/null || break
    sleep 1
  done
  if kill -0 -- "-$HAILO_PGID" 2>/dev/null; then
    kill -KILL -- "-$HAILO_PGID" 2>/dev/null || true
  fi
  # Stay alive until the supervisor has reaped/stopped the Hailo group.
  while kill -0 -- "-$HAILO_PGID" 2>/dev/null; do
    sleep 1
  done
  exit 70
}

trap 'exit 0' INT TERM

while kill -0 -- "-$HAILO_PGID" 2>/dev/null; do
  if value="$(<"$THERMAL_PATH")" && [[ "$value" =~ ^[0-9]+$ ]]; then
    failures=0
    if [ "$value" -gt "$peak" ]; then
      peak="$value"
      printf '%s\n' "$peak" >"$THERMAL_PEAK_FILE"
    fi
    if [ "$value" -ge "$ABORT_MC" ]; then
      stop_hot_workload "temperature_${value}_at_or_above_${ABORT_MC}"
    fi
  else
    failures=$((failures + 1))
    if [ "$failures" -ge 3 ]; then
      stop_hot_workload 'thermal_sensor_failed_three_consecutive_reads'
    fi
  fi
  sleep 1
done

exit 0
SHELL_THERMAL

chmod 0700 "$HAILO_WRAPPER" "$SAFETY_MONITOR" "$THERMAL_WATCHDOG"

log "PRECHECK=PASS model=$MODEL domain=$DOMAIN route=$ROUTE"
log "stream=${STREAM_HEIGHT}p@${STREAM_FPS}fps safety-biased-temporary-diagnostic duration=${RUN_SECONDS}s hold_after_window=${HOLD_AFTER_WINDOW} abort=$((ABORT_MC / 1000))C"
log 'boundary: Pi owns serial/MAVROS/Hailo DDS sources; workstation owns ports 8002/8080/9090 and browser'

OLDPWD="$PWD"
set_supervisor_phase service-start
start_child safety-monitor "$SAFETY_LOG" \
  env "COMMAND_ABORT_FILE=$COMMAND_ABORT_FILE" python3 "$SAFETY_MONITOR"
SAFETY_MONITOR_PID="$LAST_CHILD_PID"
SAFETY_MONITOR_PGID="$LAST_CHILD_PGID"

SENTINEL_READY=0
for attempt in $(seq 1 10); do
  check_command_sentinel
  SENTINEL_OK=1
  for topic in "${COMMAND_TOPICS[@]}"; do
    COUNT="$(topic_subscriptions "$topic")" || die "cannot inspect $topic subscribers"
    [ "$COUNT" = '1' ] || SENTINEL_OK=0
  done
  if [ "$SENTINEL_OK" -eq 1 ] \
      && grep -q '^DASHBOARD_SAFETY_MONITOR_READY topics=5 state=/mavros/state publishers=0$' \
        "$SAFETY_LOG"; then
    SENTINEL_READY=1
    break
  fi
done
[ "$SENTINEL_READY" -eq 1 ] || die 'publisher-free dashboard safety monitor did not become ready'
reject_unexpected_command_subscribers
log 'COMMAND_SENTINEL=PASS topics=5; safety monitor publishers=0'

cd "$RUN_DIR"
start_child mavproxy "$MAVPROXY_LOG" \
  env HOME="$MAVPROXY_HOME" PYTHONUSERBASE="$MAVPROXY_USER_BASE" PYTHONUNBUFFERED=1 \
  "$MAVPROXY" --non-interactive --no-state \
  --master="$SERIAL" --baudrate "$BAUD" \
  --out=udpout:127.0.0.1:14550
MAVPROXY_PID="$LAST_CHILD_PID"
MAVPROXY_PGID="$LAST_CHILD_PGID"
cd "$OLDPWD"

wait_for_mavproxy_heartbeat
log 'MAVPROXY_HEARTBEAT=PASS; UART owner and loopback fanout active'

MAVROS_SHARE="$(ros2 pkg prefix --share mavros)" \
  || die 'cannot resolve the MAVROS share directory'
MAVROS_CONFIG="$MAVROS_SHARE/launch/apm_config.yaml"
[ -r "$MAVROS_CONFIG" ] || die "MAVROS APM config is unreadable: $MAVROS_CONFIG"
start_child mavros "$MAVROS_LOG" \
  ros2 launch mavros node.launch \
  pluginlists_yaml:="$MAVROS_PLUGINLISTS" \
  config_yaml:="$MAVROS_CONFIG" \
  fcu_url:=udp://127.0.0.1:14550@ 'gcs_url:=""' \
  tgt_system:=1 tgt_component:=1 fcu_protocol:=v2.0 \
  respawn_mavros:=false namespace:=mavros
MAVROS_PID="$LAST_CHILD_PID"
MAVROS_PGID="$LAST_CHILD_PGID"

CONNECTED_DISARMED=0
for attempt in $(seq 1 20); do
  check_command_sentinel
  require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
  require_group_alive mavros "$MAVROS_PID" "$MAVROS_PGID" "$MAVROS_LOG"
  if sample_connected_disarmed_state; then
    CONNECTED_DISARMED=1
    break
  fi
done
[ "$CONNECTED_DISARMED" -eq 1 ] \
  || die "MAVROS did not reach connected:true and armed:false; see $STATE_SAMPLE"
check_command_sentinel
log 'MAVROS_STATE=PASS connected=true armed=false'

ros2 topic echo --once --timeout 10 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/global_position/raw/fix sensor_msgs/msg/NavSatFix >"$GPS_SAMPLE" 2>&1 \
  || die "no MAVROS raw GPS sample; see $GPS_SAMPLE"
check_command_sentinel
ros2 topic echo --once --timeout 10 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/imu/data sensor_msgs/msg/Imu >"$IMU_SAMPLE" 2>&1 \
  || die "no MAVROS IMU sample; see $IMU_SAMPLE"
check_command_sentinel
ros2 topic echo --once --timeout 10 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/battery sensor_msgs/msg/BatteryState >"$BATTERY_SAMPLE" 2>&1 \
  || die "no MAVROS battery sample; see $BATTERY_SAMPLE"
check_command_sentinel
ros2 topic echo --once --timeout 10 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/rc/in mavros_msgs/msg/RCIn >"$RC_SAMPLE" 2>&1 \
  || die "no MAVROS RC input sample; see $RC_SAMPLE"
check_command_sentinel
require_mavros_source /mavros/state
require_mavros_source /mavros/global_position/raw/fix
require_mavros_source /mavros/imu/data
require_mavros_source /mavros/battery
require_mavros_source /mavros/rc/in
log 'MAVROS_TELEMETRY=PASS state,GPS,IMU,battery,RC sampled from one MAVROS publisher each'

HAILO_ENV=(
  "PYTHONUNBUFFERED=1"
  "PYTHONPATH=$REPO${PYTHONPATH:+:$PYTHONPATH}"
  "HAILO_APPS_REPO=$REPO"
  "HAILO_STREAM_HEIGHT=$STREAM_HEIGHT"
  "HAILO_STREAM_FPS=$STREAM_FPS"
  "HAILO_LOCAL_WINDOW_MODE=$LOCAL_WINDOW_MODE"
)
check_temperature pre-hailo
check_power pre-hailo
check_command_sentinel
start_child hailo-bridge "$HAILO_LOG" env "${HAILO_ENV[@]}" \
  "$VENV/bin/python" "$HAILO_WRAPPER" \
  --hef-path "$HEF" --input "$CAM" --camera-resolution sd \
  --output-resolution sd --frame-rate 15 --show-fps \
  "${HAILO_DISPLAY_ARGS[@]}"
HAILO_PID="$LAST_CHILD_PID"
HAILO_PGID="$LAST_CHILD_PGID"
start_child thermal-watchdog "$THERMAL_LOG" \
  env "THERMAL_PATH=$THERMAL" "ABORT_MC=$ABORT_MC" \
  "HAILO_PGID=$HAILO_PGID" "SUPERVISOR_PID=$$" \
  "THERMAL_ABORT_FILE=$THERMAL_ABORT_FILE" \
  "THERMAL_PEAK_FILE=$THERMAL_PEAK_FILE" \
  bash "$THERMAL_WATCHDOG"
THERMAL_WATCHDOG_PID="$LAST_CHILD_PID"
THERMAL_WATCHDOG_PGID="$LAST_CHILD_PGID"
check_thermal_watchdog

IMAGE_READY=0
for attempt in $(seq 1 30); do
  check_command_sentinel
  check_thermal_watchdog
  require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
  require_group_alive mavros "$MAVROS_PID" "$MAVROS_PGID" "$MAVROS_LOG"
  require_group_alive hailo-bridge "$HAILO_PID" "$HAILO_PGID" "$HAILO_LOG"
  check_temperature hailo-readiness
  if ros2 topic echo --once --timeout 3 --no-arr \
      --qos-reliability reliable --qos-history keep_last --qos-depth 1 \
      "$IMAGE_TOPIC" sensor_msgs/msg/Image >"$IMAGE_SAMPLE" 2>&1 \
      && grep -q '^encoding: bgr8' "$IMAGE_SAMPLE" \
      && grep -q "^height: $STREAM_HEIGHT" "$IMAGE_SAMPLE"; then
    IMAGE_READY=1
    check_thermal_watchdog
    check_temperature hailo-readiness
    break
  fi
  check_temperature hailo-readiness
  check_thermal_watchdog
done
[ "$IMAGE_READY" -eq 1 ] || die "Hailo image topic did not deliver; see $IMAGE_SAMPLE and $HAILO_LOG"
check_command_sentinel
check_thermal_watchdog
require_connected_disarmed_state pre-ready
require_mavros_source /mavros/state
require_mavros_source /mavros/global_position/raw/fix
require_mavros_source /mavros/imu/data
require_mavros_source /mavros/battery
require_mavros_source /mavros/rc/in

NODES="$(graph_nodes)" || die 'cannot inspect the ROS node graph'
reject_forbidden_nodes "$NODES"
require_workstation_nodes "$NODES"
reject_command_services
reject_unexpected_command_subscribers
require_publisher_count "$IMAGE_TOPIC" 1 pre-ready
TOPICS="$(ros2_graph_query topic list --no-daemon --spin-time 2)" \
  || die 'cannot enumerate final ROS topics'
MAVROS_TOPIC_COUNT="$(grep -c '^/mavros/' <<<"$TOPICS" || true)"
[ "$MAVROS_TOPIC_COUNT" -gt 0 ] || die 'no MAVROS topics discovered'
set_supervisor_phase live-window
log "PI_SOURCE_STACK_READY=PASS mavros_topics=$MAVROS_TOPIC_COUNT image_topic=$IMAGE_TOPIC"
log "dashboard: hard-refresh; camera=$IMAGE_TOPIC; native MAVROS panel reads five topics directly"
log 'scope: Pi source readiness only; GPS no-fix is valid telemetry and must not be misread as transport loss'

WINDOW_START_SECONDS=$SECONDS
DEADLINE=$((WINDOW_START_SECONDS + RUN_SECONDS))
monitor_live_stack live-window "$DEADLINE"
WINDOW_MONITOR_END_SECONDS=$SECONDS
FINAL_VERIFY_DEADLINE=$((WINDOW_MONITOR_END_SECONDS + FINAL_VERIFY_SECONDS))

check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
require_connected_disarmed_state final "$FINAL_VERIFY_DEADLINE" || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" disarmed-state \
  'MAVROS connection/disarmed state failed during final verification'
check_command_sentinel
check_thermal_watchdog
require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
require_group_alive mavros "$MAVROS_PID" "$MAVROS_PGID" "$MAVROS_LOG"
require_group_alive hailo-bridge "$HAILO_PID" "$HAILO_PGID" "$HAILO_LOG"
FINAL_CHECK_RC=0
final_graph_verification "$FINAL_VERIFY_DEADLINE" || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" graph-contract \
  'final ROS graph verification failed'

FINAL_CHECK_RC=0
bounded_topic_echo "$FINAL_VERIFY_DEADLINE" 5 --no-arr \
  --qos-reliability reliable --qos-history keep_last --qos-depth 1 \
  "$IMAGE_TOPIC" sensor_msgs/msg/Image >"$IMAGE_SAMPLE" 2>&1 || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" Hailo-image \
  "no fresh final Hailo image; see $IMAGE_SAMPLE"
grep -q '^encoding: bgr8' "$IMAGE_SAMPLE" \
  && grep -q "^height: $STREAM_HEIGHT" "$IMAGE_SAMPLE" \
  || die "invalid final Hailo image; see $IMAGE_SAMPLE"
check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
bounded_topic_echo "$FINAL_VERIFY_DEADLINE" 5 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/global_position/raw/fix sensor_msgs/msg/NavSatFix >"$GPS_SAMPLE" 2>&1 \
  || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" GPS-sample \
  "no fresh final MAVROS raw GPS sample; see $GPS_SAMPLE"
check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
bounded_topic_echo "$FINAL_VERIFY_DEADLINE" 5 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/imu/data sensor_msgs/msg/Imu >"$IMU_SAMPLE" 2>&1 \
  || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" IMU-sample \
  "no fresh final MAVROS IMU sample; see $IMU_SAMPLE"
check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
bounded_topic_echo "$FINAL_VERIFY_DEADLINE" 5 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/battery sensor_msgs/msg/BatteryState >"$BATTERY_SAMPLE" 2>&1 \
  || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" battery-sample \
  "no fresh final MAVROS battery sample; see $BATTERY_SAMPLE"
check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
bounded_topic_echo "$FINAL_VERIFY_DEADLINE" 5 --no-arr \
  --qos-reliability best_effort --qos-history keep_last --qos-depth 10 \
  /mavros/rc/in mavros_msgs/msg/RCIn >"$RC_SAMPLE" 2>&1 \
  || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" RC-sample \
  "no fresh final MAVROS RC input sample; see $RC_SAMPLE"
check_command_sentinel
check_thermal_watchdog
FINAL_CHECK_RC=0
require_connected_disarmed_state final-verdict "$FINAL_VERIFY_DEADLINE" \
  || FINAL_CHECK_RC=$?
require_final_check_result "$FINAL_CHECK_RC" final-disarmed-verdict \
  'MAVROS connection/disarmed state failed during final verdict'
require_group_alive mavproxy "$MAVPROXY_PID" "$MAVPROXY_PGID" "$MAVPROXY_LOG"
require_group_alive mavros "$MAVROS_PID" "$MAVROS_PGID" "$MAVROS_LOG"
require_group_alive hailo-bridge "$HAILO_PID" "$HAILO_PGID" "$HAILO_LOG"
check_command_sentinel
check_thermal_watchdog
check_temperature final-verification
check_power final-verification
[ "$SECONDS" -lt "$FINAL_VERIFY_DEADLINE" ] \
  || die "final verification exceeded ${FINAL_VERIFY_SECONDS}s during completion"
complete_source_window
