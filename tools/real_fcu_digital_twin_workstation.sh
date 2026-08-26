#!/usr/bin/env bash

# Workstation half of the guarded physical-FCU dashboard loop.

set -euo pipefail

RFCU_WS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RFCU_WS_REPO_ROOT="$(cd -- "$RFCU_WS_SCRIPT_DIR/.." && pwd)"
RFCU_WS_DASHBOARD_DIR="$RFCU_WS_REPO_ROOT/web_dashboard/autoboat"
RFCU_WS_BUNDLE_MANIFEST="$RFCU_WS_REPO_ROOT/config/real_fcu_digital_twin_bundle.sha256"
RFCU_WS_ROS_SETUP="${RFCU_WS_ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
RFCU_WS_LOG_ROOT="${REAL_FCU_WORKSTATION_LOG_ROOT:-$HOME/Desktop}"
RFCU_WS_READY_TIMEOUT_SECONDS="${REAL_FCU_READY_TIMEOUT_SECONDS:-180}"
RFCU_WS_POLL_SECONDS="${REAL_FCU_POLL_SECONDS:-1}"
RFCU_WS_DOMAIN_ID='43'
RFCU_WS_DISCOVERY_RANGE='SUBNET'
RFCU_WS_LOCALHOST_ONLY='0'
RFCU_WS_STOP_TOPIC='/real_fcu/workstation_stop'
RFCU_WS_STOP_MESSAGE='REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free'
RFCU_WS_RUN_DIR=''
RFCU_WS_SUPERVISOR_LOG=''
RFCU_WS_SUPERVISOR_PGID=''
RFCU_WS_CLEANING=0
RFCU_WS_STARTED=0
RFCU_WS_READY_REACHED=0
RFCU_WS_OPERATOR_STOP_REQUESTED=0

declare -a RFCU_WS_CHILD_NAMES=()
declare -a RFCU_WS_CHILD_PIDS=()
declare -a RFCU_WS_CHILD_PGIDS=()
declare -A RFCU_WS_CHILD_INDEX=()
declare -a RFCU_WS_ROSBRIDGE_COMMAND=()
declare -a RFCU_WS_DASHBOARD_COMMAND=()
RFCU_WS_CONFLICT_PATTERNS=(
  'ardurover'
  'sim_vehicle.py'
  'mavproxy.py'
  'MAVProxy'
  'mavros_node'
  'real_fcu_rc_command_bridge.py'
  'sitl_digital_twin_evidence.py'
  'sitl_operator_once.py'
  'rosbridge'
  'serve_dashboard.py'
)

rfcu_ws_append_log() {
  local line="$1"
  [ -n "$RFCU_WS_SUPERVISOR_LOG" ] || return 0
  printf 'timestamp=%s %s\n' "${EPOCHREALTIME:-unknown}" "$line" \
    >>"$RFCU_WS_SUPERVISOR_LOG" 2>/dev/null || true
}

rfcu_ws_log() {
  local line="[real-fcu-workstation] $*"
  rfcu_ws_append_log "$line"
  printf '%s\n' "$line"
}

rfcu_ws_log_error() {
  local line="[real-fcu-workstation] $*"
  rfcu_ws_append_log "$line"
  printf '%s\n' "$line" >&2
}

rfcu_ws_fail() {
  rfcu_ws_log_error "STOP: $*"
  return 1
}

rfcu_ws_usage() {
  printf 'usage: %s check|run\n' "${0##*/}" >&2
  return 2
}

rfcu_ws_require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || rfcu_ws_fail "required command missing: $1"
}

rfcu_ws_validate_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_ws_fail "$name must be a positive integer"
}

rfcu_ws_configure_ros_environment() {
  local source_rc=0
  [ -r "$RFCU_WS_ROS_SETUP" ] \
    || rfcu_ws_fail "ROS Jazzy setup missing: $RFCU_WS_ROS_SETUP"

  export ROS_DOMAIN_ID="$RFCU_WS_DOMAIN_ID"
  export ROS_AUTOMATIC_DISCOVERY_RANGE="$RFCU_WS_DISCOVERY_RANGE"
  export ROS_LOCALHOST_ONLY="$RFCU_WS_LOCALHOST_ONLY"
  unset ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
  unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
  unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI

  set +u
  # shellcheck disable=SC1090
  source "$RFCU_WS_ROS_SETUP" || source_rc=$?
  set -u
  [ "$source_rc" -eq 0 ] \
    || rfcu_ws_fail "cannot source ROS Jazzy setup: $RFCU_WS_ROS_SETUP"

  [ "$ROS_DOMAIN_ID" = "$RFCU_WS_DOMAIN_ID" ] \
    || rfcu_ws_fail "ROS_DOMAIN_ID did not remain $RFCU_WS_DOMAIN_ID"
  [ "$ROS_AUTOMATIC_DISCOVERY_RANGE" = SUBNET ] \
    || rfcu_ws_fail 'ROS_AUTOMATIC_DISCOVERY_RANGE did not remain SUBNET'
  [ "$ROS_LOCALHOST_ONLY" = 0 ] \
    || rfcu_ws_fail 'ROS_LOCALHOST_ONLY did not remain 0'
  [ -z "${ROS_STATIC_PEERS:-}" ] || rfcu_ws_fail 'ROS_STATIC_PEERS must be unset'
  [ -z "${ROS_DISCOVERY_SERVER:-}" ] \
    || rfcu_ws_fail 'ROS_DISCOVERY_SERVER must be unset'
  [ -z "${RMW_IMPLEMENTATION:-}" ] \
    || rfcu_ws_fail 'RMW_IMPLEMENTATION must be unset'
  [ -z "${FASTDDS_DEFAULT_PROFILES_FILE:-}" ] \
    || rfcu_ws_fail 'FASTDDS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${FASTRTPS_DEFAULT_PROFILES_FILE:-}" ] \
    || rfcu_ws_fail 'FASTRTPS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${CYCLONEDDS_URI:-}" ] || rfcu_ws_fail 'CYCLONEDDS_URI must be unset'
}

rfcu_ws_verify_repository() {
  local status head upstream
  [ -d "$RFCU_WS_REPO_ROOT/.git" ] \
    || rfcu_ws_fail "repository missing: $RFCU_WS_REPO_ROOT"
  status="$(git -C "$RFCU_WS_REPO_ROOT" status --porcelain=v1 --untracked-files=all)" \
    || rfcu_ws_fail 'cannot inspect repository state'
  [ -z "$status" ] || rfcu_ws_fail 'workstation helper requires a clean worktree'
  head="$(git -C "$RFCU_WS_REPO_ROOT" rev-parse HEAD)" \
    || rfcu_ws_fail 'cannot read repository HEAD'
  upstream="$(git -C "$RFCU_WS_REPO_ROOT" rev-parse refs/remotes/origin/main)" \
    || rfcu_ws_fail 'cannot read origin/main'
  [ "$head" = "$upstream" ] \
    || rfcu_ws_fail 'repository HEAD does not match origin/main'
}

rfcu_ws_reject_listening_ports() {
  local state port matches found=0
  state="$(ss -H -ltn)" || rfcu_ws_fail 'cannot inspect workstation TCP ports'
  for port in 8002 9090; do
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
  [ "$found" -eq 0 ] || rfcu_ws_fail 'workstation dashboard port already in use'
}

rfcu_ws_reject_conflicts() {
  local pattern output rc found=0
  for pattern in "${RFCU_WS_CONFLICT_PATTERNS[@]}"; do
    if output="$(pgrep -af -- "$pattern")"; then
      printf '%s\n' "$output" >&2
      found=1
    else
      rc=$?
      [ "$rc" -eq 1 ] \
        || rfcu_ws_fail "cannot inspect process pattern: $pattern"
    fi
  done
  [ "$found" -eq 0 ] || rfcu_ws_fail 'conflicting workstation process found'
}

rfcu_ws_static_preflight() {
  local command
  rfcu_ws_validate_positive_integer REAL_FCU_READY_TIMEOUT_SECONDS \
    "$RFCU_WS_READY_TIMEOUT_SECONDS"
  rfcu_ws_validate_positive_integer REAL_FCU_POLL_SECONDS "$RFCU_WS_POLL_SECONDS"
  for command in awk bash curl date git grep mkdir pgrep ps python3 sed setsid \
    sha256sum sleep ss timeout tr; do
    rfcu_ws_require_command "$command"
  done
  [ -d "$RFCU_WS_LOG_ROOT" ] \
    || rfcu_ws_fail "log root missing: $RFCU_WS_LOG_ROOT"
  [ -w "$RFCU_WS_LOG_ROOT" ] \
    || rfcu_ws_fail "log root is not writable: $RFCU_WS_LOG_ROOT"
  [ -r "$RFCU_WS_DASHBOARD_DIR/serve_dashboard.py" ] \
    || rfcu_ws_fail 'dashboard server is missing'
  rfcu_ws_verify_repository
  [ -r "$RFCU_WS_BUNDLE_MANIFEST" ] \
    || rfcu_ws_fail "Pi bundle manifest missing: $RFCU_WS_BUNDLE_MANIFEST"
  ( cd "$RFCU_WS_REPO_ROOT" && sha256sum -c "$RFCU_WS_BUNDLE_MANIFEST" ) \
    >/dev/null || rfcu_ws_fail 'Pi bundle checksum failed'
  rfcu_ws_reject_listening_ports
  rfcu_ws_reject_conflicts
  rfcu_ws_configure_ros_environment
  rfcu_ws_require_command ros2
  ros2 pkg prefix rosbridge_server >/dev/null \
    || rfcu_ws_fail 'rosbridge_server package missing'
  /usr/bin/python3 -c 'import json, rclpy, std_msgs, yaml' \
    || rfcu_ws_fail 'workstation ROS/Python imports are unavailable'
}

rfcu_ws_init_state() {
  local timestamp
  RFCU_WS_CHILD_NAMES=()
  RFCU_WS_CHILD_PIDS=()
  RFCU_WS_CHILD_PGIDS=()
  RFCU_WS_CHILD_INDEX=()
  RFCU_WS_CLEANING=0
  RFCU_WS_STARTED=0
  RFCU_WS_READY_REACHED=0
  RFCU_WS_OPERATOR_STOP_REQUESTED=0
  RFCU_WS_SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')" \
    || rfcu_ws_fail 'cannot determine workstation supervisor process group'
  [[ "$RFCU_WS_SUPERVISOR_PGID" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_ws_fail 'invalid workstation supervisor process group'
  timestamp="$(date +%Y%m%d_%H%M%S)" \
    || rfcu_ws_fail 'cannot create workstation run timestamp'
  RFCU_WS_RUN_DIR="$RFCU_WS_LOG_ROOT/real_fcu_digital_twin_workstation_$timestamp"
  [ ! -e "$RFCU_WS_RUN_DIR" ] \
    || rfcu_ws_fail "run directory already exists: $RFCU_WS_RUN_DIR"
  mkdir -m 700 "$RFCU_WS_RUN_DIR"
  mkdir -m 700 "$RFCU_WS_RUN_DIR/logs" "$RFCU_WS_RUN_DIR/manifest" \
    "$RFCU_WS_RUN_DIR/evidence"
  RFCU_WS_SUPERVISOR_LOG="$RFCU_WS_RUN_DIR/supervisor.log"
  : >"$RFCU_WS_SUPERVISOR_LOG" \
    || rfcu_ws_fail 'cannot create workstation supervisor log'
}

rfcu_ws_build_commands() {
  RFCU_WS_ROSBRIDGE_COMMAND=(
    ros2 launch rosbridge_server rosbridge_websocket_launch.xml
    'address:=127.0.0.1' 'port:=9090'
  )
  RFCU_WS_DASHBOARD_COMMAND=(
    bash -c 'cd -- "$1" && shift && exec "$@"' _ "$RFCU_WS_DASHBOARD_DIR"
    python3 serve_dashboard.py 8002 127.0.0.1
  )
}

rfcu_ws_write_manifest() {
  {
    printf 'revision=%s\n' "$(git -C "$RFCU_WS_REPO_ROOT" rev-parse HEAD)"
    printf 'origin_main=%s\n' \
      "$(git -C "$RFCU_WS_REPO_ROOT" rev-parse refs/remotes/origin/main)"
    printf 'ROS_DOMAIN_ID=%s\n' "$ROS_DOMAIN_ID"
    printf 'ROS_AUTOMATIC_DISCOVERY_RANGE=%s\n' \
      "$ROS_AUTOMATIC_DISCOVERY_RANGE"
    printf 'ROS_LOCALHOST_ONLY=%s\n' "$ROS_LOCALHOST_ONLY"
  } >"$RFCU_WS_RUN_DIR/manifest/environment.txt"
  sha256sum "$RFCU_WS_SCRIPT_DIR/real_fcu_digital_twin_workstation.sh" \
    "$RFCU_WS_DASHBOARD_DIR/app.js" \
    "$RFCU_WS_DASHBOARD_DIR/index.html" \
    >"$RFCU_WS_RUN_DIR/manifest/artifacts.sha256"
  {
    printf 'rosbridge'
    printf '\t%q' "${RFCU_WS_ROSBRIDGE_COMMAND[@]}"
    printf '\n'
    printf 'dashboard'
    printf '\t%q' "${RFCU_WS_DASHBOARD_COMMAND[@]}"
    printf '\n'
  } >"$RFCU_WS_RUN_DIR/manifest/commands.tsv"
}

rfcu_ws_group_alive() {
  kill -0 -- "-$1" 2>/dev/null
}

rfcu_ws_start_child() {
  local name="$1" logfile="$2" pid pgid index
  shift 2
  ( trap - INT QUIT; exec setsid "$@" ) >"$logfile" 2>&1 < /dev/null &
  pid=$!
  sleep 0.2 || true
  kill -0 "$pid" 2>/dev/null \
    || rfcu_ws_fail "$name exited during startup; see $logfile"
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')" \
    || rfcu_ws_fail "cannot determine $name process group"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_ws_fail "invalid $name process group"
  [ "$pgid" = "$pid" ] \
    || rfcu_ws_fail "$name process group is not led by its registered PID"
  [ "$pgid" != "$RFCU_WS_SUPERVISOR_PGID" ] \
    || rfcu_ws_fail "$name did not enter a separate process group"
  RFCU_WS_CHILD_NAMES+=("$name")
  RFCU_WS_CHILD_PIDS+=("$pid")
  RFCU_WS_CHILD_PGIDS+=("$pgid")
  index=$((${#RFCU_WS_CHILD_NAMES[@]} - 1))
  RFCU_WS_CHILD_INDEX[$name]="$index"
  RFCU_WS_STARTED=1
  rfcu_ws_log "started $name pid=$pid pgid=$pgid log=$logfile"
}

rfcu_ws_stop_child() {
  local name="$1" index pid pgid signal attempt
  [ -n "${RFCU_WS_CHILD_INDEX[$name]+present}" ] || return 0
  index="${RFCU_WS_CHILD_INDEX[$name]}"
  pid="${RFCU_WS_CHILD_PIDS[$index]}"
  pgid="${RFCU_WS_CHILD_PGIDS[$index]}"
  [ "$pgid" != "$RFCU_WS_SUPERVISOR_PGID" ] \
    || { rfcu_ws_log_error "refusing supervisor process group for $name"; return 1; }
  if rfcu_ws_group_alive "$pgid"; then
    for signal in INT TERM KILL; do
      kill -"$signal" -- "-$pgid" 2>/dev/null || true
      for attempt in 1 2 3 4 5; do
        rfcu_ws_group_alive "$pgid" || break 2
        sleep 0.2 || true
      done
    done
  fi
  wait "$pid" 2>/dev/null || true
  rfcu_ws_group_alive "$pgid" && return 1
  rfcu_ws_log "stopped $name"
}

rfcu_ws_children_alive() {
  local index
  for index in "${!RFCU_WS_CHILD_NAMES[@]}"; do
    kill -0 "${RFCU_WS_CHILD_PIDS[$index]}" 2>/dev/null || return 1
    rfcu_ws_group_alive "${RFCU_WS_CHILD_PGIDS[$index]}" || return 1
  done
}

rfcu_ws_loopback_listener_ready() {
  local port="$1" state
  state="$(ss -H -ltn "sport = :$port")" || return 1
  awk -v expected="127.0.0.1:$port" \
    '$4 == expected { found = 1 } END { exit found ? 0 : 1 }' <<<"$state"
}

rfcu_ws_wait_local_services() {
  local deadline=$((SECONDS + 30))
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_ws_children_alive || return 1
    if rfcu_ws_loopback_listener_ready 9090 \
        && rfcu_ws_loopback_listener_ready 8002 \
        && curl --fail --silent --show-error --max-time 2 --output /dev/null \
          http://127.0.0.1:8002/; then
      return 0
    fi
    sleep "$RFCU_WS_POLL_SECONDS" || true
  done
  return 1
}

rfcu_ws_status_json_once() {
  local raw
  raw="$(ros2 topic echo --once --timeout 5 --full-length --field data --no-lost-messages \
    --qos-profile best_available /command_ingress/status std_msgs/msg/String \
    2>>"$RFCU_WS_RUN_DIR/logs/status_probe.log")" || return 1
  printf '%s\n' "$raw" | /usr/bin/python3 -c '
import sys
import yaml
values = [value for value in yaml.safe_load_all(sys.stdin.read()) if isinstance(value, str)]
if len(values) != 1:
    raise SystemExit(1)
print(values[0])
'
}

rfcu_ws_bench_url_from_status() {
  local status_json="$1"
  /usr/bin/python3 -c '
import json
import sys

status = json.loads(sys.argv[1])
required = (
    status.get("state") == "READY_DISARMED",
    status.get("ready") is True,
    status.get("connected") is True,
    status.get("armed") is False,
    status.get("mode") == "MANUAL",
    status.get("feedback_fresh") is True,
)
if not all(required):
    raise SystemExit(1)
resolved = status.get("resolved") or {}
neutral_only = status.get("neutral_only")
left = resolved.get("left_servo")
right = resolved.get("right_servo")
if not (
    isinstance(neutral_only, bool)
    and isinstance(left, int) and isinstance(right, int)
    and 1 <= left <= 16 and 1 <= right <= 16 and left != right
):
    raise SystemExit(1)
query = f"thrust_left_servo={left}&thrust_right_servo={right}"
if not neutral_only:
    query = "enable_fcu_bench_control=1&" + query
print("http://127.0.0.1:8002/?" + query)
' "$status_json"
}

rfcu_ws_status_is_final_disarmed() {
  /usr/bin/python3 -c '
import json
import sys

status = json.loads(sys.argv[1])
if not (
    status.get("state") in ("READY_DISARMED", "EMERGENCY_STOP")
    and status.get("connected") is True
    and status.get("armed") is False
    and status.get("mode") == "MANUAL"
    and status.get("feedback_fresh") is True
):
    raise SystemExit(1)
' "$1"
}

rfcu_ws_publish_stop_marker() {
  local command_timeout=$((RFCU_WS_READY_TIMEOUT_SECONDS + 5))
  timeout "$command_timeout" \
    ros2 topic pub --once --wait-matching-subscriptions 1 \
      --max-wait-time-secs "$RFCU_WS_READY_TIMEOUT_SECONDS" \
      --qos-history keep_last --qos-depth 1 \
      --qos-reliability reliable --qos-durability volatile \
      "$RFCU_WS_STOP_TOPIC" std_msgs/msg/String \
      "{data: \"$RFCU_WS_STOP_MESSAGE\"}" \
      >"$RFCU_WS_RUN_DIR/logs/workstation_stop_marker.log" 2>&1
}

rfcu_ws_wait_bridge_ready() {
  local deadline=$((SECONDS + RFCU_WS_READY_TIMEOUT_SECONDS)) status_json bench_url
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_ws_children_alive || return 1
    if status_json="$(rfcu_ws_status_json_once)" \
        && bench_url="$(rfcu_ws_bench_url_from_status "$status_json")"; then
      printf '%s\n' "$status_json" >"$RFCU_WS_RUN_DIR/evidence/ready_status.json"
      printf '%s\n' "$bench_url" >"$RFCU_WS_RUN_DIR/evidence/bench_url.txt"
      RFCU_WS_BENCH_URL="$bench_url"
      return 0
    fi
    sleep "$RFCU_WS_POLL_SECONDS" || true
  done
  return 1
}

rfcu_ws_cleanup() {
  local incoming_rc=$? cleanup_rc=0 final_rc operator_candidate=0
  local operator_success=0 status_json
  [ "$RFCU_WS_CLEANING" -eq 0 ] || return "$incoming_rc"
  RFCU_WS_CLEANING=1
  trap - EXIT INT TERM
  set +e
  if [ "$RFCU_WS_OPERATOR_STOP_REQUESTED" -eq 1 ] \
      && [ "$RFCU_WS_READY_REACHED" -eq 1 ]; then
    if ! rfcu_ws_children_alive; then
      rfcu_ws_log_error 'REAL_FCU_WORKSTATION_CHILDREN=FAIL expected=alive-before-stop'
      cleanup_rc=1
    elif status_json="$(rfcu_ws_status_json_once)" \
        && rfcu_ws_status_is_final_disarmed "$status_json"; then
      printf '%s\n' "$status_json" \
        >"$RFCU_WS_RUN_DIR/evidence/final_status.json"
      rfcu_ws_log 'REAL_FCU_WORKSTATION_FINAL_STATE=PASS connected=true armed=false'
      operator_candidate=1
    else
      rfcu_ws_log_error 'REAL_FCU_WORKSTATION_FINAL_STATE=FAIL expected=connected,disarmed'
      cleanup_rc=1
    fi
  fi
  rfcu_ws_stop_child dashboard || cleanup_rc=1
  rfcu_ws_stop_child rosbridge || cleanup_rc=1
  if [ "$RFCU_WS_STARTED" -eq 1 ]; then
    rfcu_ws_loopback_listener_ready 8002 && cleanup_rc=1
    rfcu_ws_loopback_listener_ready 9090 && cleanup_rc=1
  fi
  if [ "$incoming_rc" -eq 130 ] && [ "$operator_candidate" -eq 1 ] \
      && [ "$cleanup_rc" -eq 0 ]; then
    if rfcu_ws_publish_stop_marker; then
      rfcu_ws_log "REAL_FCU_WORKSTATION_STOP_MARKER=PASS topic=$RFCU_WS_STOP_TOPIC"
      operator_success=1
    else
      rfcu_ws_log_error "REAL_FCU_WORKSTATION_STOP_MARKER=FAIL topic=$RFCU_WS_STOP_TOPIC"
      cleanup_rc=1
    fi
  fi
  final_rc="$incoming_rc"
  if [ "$incoming_rc" -eq 130 ] && [ "$operator_success" -eq 1 ] \
      && [ "$cleanup_rc" -eq 0 ]; then
    final_rc=0
  elif [ "$final_rc" -eq 0 ]; then
    final_rc="$cleanup_rc"
  fi
  [ -z "$RFCU_WS_RUN_DIR" ] \
    || rfcu_ws_log "REAL_FCU_WORKSTATION_LOGS=$RFCU_WS_RUN_DIR"
  rfcu_ws_log "REAL_FCU_WORKSTATION_EXIT status=$final_rc cleanup_rc=$cleanup_rc"
  exit "$final_rc"
}

rfcu_ws_on_interrupt() {
  RFCU_WS_OPERATOR_STOP_REQUESTED=1
  rfcu_ws_log 'operator stop requested'
  exit 130
}

rfcu_ws_on_term() {
  rfcu_ws_log_error 'termination requested'
  exit 143
}

rfcu_ws_check() {
  rfcu_ws_static_preflight
  rfcu_ws_require_command node
  bash "$RFCU_WS_SCRIPT_DIR/test_real_fcu_digital_twin_helpers.sh"
  python3 -m unittest "$RFCU_WS_SCRIPT_DIR/test_real_fcu_rc_command_bridge.py"
  python3 -m unittest \
    "$RFCU_WS_SCRIPT_DIR/test_real_fcu_command_feedback_capture.py"
  node --check "$RFCU_WS_DASHBOARD_DIR/app.js"
  node --test --test-isolation=none "$RFCU_WS_DASHBOARD_DIR"/test/*.test.js
  rfcu_ws_log 'REAL_FCU_WORKSTATION_CHECK=PASS tests=helper,bridge,capture,dashboard runtime=not-started ports=8002,9090'
}

rfcu_ws_run() {
  rfcu_ws_static_preflight
  rfcu_ws_init_state
  rfcu_ws_build_commands
  rfcu_ws_write_manifest
  trap rfcu_ws_cleanup EXIT
  trap rfcu_ws_on_interrupt INT
  trap rfcu_ws_on_term TERM
  rfcu_ws_log "REAL_FCU_WORKSTATION_START domain=$RFCU_WS_DOMAIN_ID discovery=SUBNET run_dir=$RFCU_WS_RUN_DIR"

  rfcu_ws_start_child rosbridge "$RFCU_WS_RUN_DIR/logs/rosbridge.log" \
    "${RFCU_WS_ROSBRIDGE_COMMAND[@]}"
  rfcu_ws_start_child dashboard "$RFCU_WS_RUN_DIR/logs/dashboard.log" \
    "${RFCU_WS_DASHBOARD_COMMAND[@]}"
  rfcu_ws_wait_local_services \
    || rfcu_ws_fail 'loopback rosbridge/dashboard readiness failed'
  rfcu_ws_log 'REAL_FCU_WORKSTATION_SERVICES=PASS ports=8002,9090 address=127.0.0.1'
  rfcu_ws_log 'waiting for the separately approved Pi helper and READY_DISARMED status'
  rfcu_ws_wait_bridge_ready \
    || rfcu_ws_fail 'safe Pi bridge status did not arrive before the deadline'
  rfcu_ws_log "REAL_FCU_BENCH_URL=$RFCU_WS_BENCH_URL"
  rfcu_ws_log 'REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output'
  rfcu_ws_log 'planned stop: externally disarm first, then press Ctrl+C in the Pi terminal, then here'
  RFCU_WS_READY_REACHED=1

  while rfcu_ws_children_alive; do
    sleep "$RFCU_WS_POLL_SECONDS" || true
  done
  rfcu_ws_fail 'a workstation child exited unexpectedly'
}

rfcu_ws_main() {
  case "$#:${1:-}" in
    1:check) rfcu_ws_check ;;
    1:run) rfcu_ws_run ;;
    *) rfcu_ws_usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  rfcu_ws_main "$@"
fi
