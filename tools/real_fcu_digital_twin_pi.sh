#!/usr/bin/env bash

# Pi half of the guarded physical-FCU dashboard loop.

set -euo pipefail

RFCU_PI_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RFCU_PI_REPO_ROOT="$(cd -- "$RFCU_PI_SCRIPT_DIR/.." && pwd)"
RFCU_PI_ROS_SETUP="${RFCU_PI_ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
RFCU_PI_BRIDGE="$RFCU_PI_SCRIPT_DIR/real_fcu_rc_command_bridge.py"
RFCU_PI_PLUGIN_YAML="$RFCU_PI_REPO_ROOT/config/mavros_real_fcu_closed_loop_plugins.yaml"
RFCU_PI_PROBE_PLUGIN_YAML="$RFCU_PI_REPO_ROOT/config/mavros_real_fcu_t0b_plugins.yaml"
RFCU_PI_BUNDLE_MANIFEST="$RFCU_PI_REPO_ROOT/config/real_fcu_digital_twin_bundle.sha256"
RFCU_PI_APM_CONFIG='/opt/ros/jazzy/share/mavros/launch/apm_config.yaml'
RFCU_PI_SERIAL='/dev/ttyAMA0'
RFCU_PI_BAUD='57600'
RFCU_PI_LOG_ROOT="${REAL_FCU_PI_LOG_ROOT:-$HOME/Desktop}"
RFCU_PI_READY_TIMEOUT_SECONDS="${REAL_FCU_READY_TIMEOUT_SECONDS:-180}"
RFCU_PI_POLL_SECONDS="${REAL_FCU_POLL_SECONDS:-1}"
RFCU_PI_DOMAIN_ID='43'
RFCU_PI_DISCOVERY_RANGE='SUBNET'
RFCU_PI_PROBE_DISCOVERY_RANGE='LOCALHOST'
RFCU_PI_LOCALHOST_ONLY='0'
RFCU_PI_WORKSTATION_STOP_TOPIC='/real_fcu/workstation_stop'
RFCU_PI_WORKSTATION_STOP_MESSAGE='REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free'
RFCU_PI_MOTOR_OUTPUTS_BIT=32768
RFCU_PI_RUN_DIR=''
RFCU_PI_RUN_MODE='none'
RFCU_PI_SUPERVISOR_LOG=''
RFCU_PI_SUPERVISOR_PGID=''
RFCU_PI_CLEANING=0
RFCU_PI_BRIDGE_STARTED=0
RFCU_PI_READY_REACHED=0
RFCU_PI_OPERATOR_STOP_REQUESTED=0

declare -a RFCU_PI_CHILD_NAMES=()
declare -a RFCU_PI_CHILD_PIDS=()
declare -a RFCU_PI_CHILD_PGIDS=()
declare -A RFCU_PI_CHILD_INDEX=()
declare -A RFCU_PI_CHILD_ACTIVE=()
declare -a RFCU_PI_PROBE_MAVROS_COMMAND=()
declare -a RFCU_PI_MAVROS_COMMAND=()
declare -a RFCU_PI_BRIDGE_COMMAND=()

rfcu_pi_append_log() {
  local line="$1"
  [ -n "$RFCU_PI_SUPERVISOR_LOG" ] || return 0
  printf 'timestamp=%s %s\n' "${EPOCHREALTIME:-unknown}" "$line" \
    >>"$RFCU_PI_SUPERVISOR_LOG" 2>/dev/null || true
}

rfcu_pi_log() {
  local line="[real-fcu-pi] $*"
  rfcu_pi_append_log "$line"
  printf '%s\n' "$line"
}

rfcu_pi_log_error() {
  local line="[real-fcu-pi] $*"
  rfcu_pi_append_log "$line"
  printf '%s\n' "$line" >&2
}

rfcu_pi_fail() {
  rfcu_pi_log_error "STOP: $*"
  return 1
}

rfcu_pi_usage() {
  printf 'usage: %s check|probe|run-t2a|run\n' "${0##*/}" >&2
  return 2
}

rfcu_pi_require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || rfcu_pi_fail "required command missing: $1"
}

rfcu_pi_validate_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_pi_fail "$name must be a positive integer"
}

rfcu_pi_require_flag() {
  local name="$1"
  [ "${!name:-0}" = 1 ] || rfcu_pi_fail "$name must be 1"
}

rfcu_pi_require_probe_gates() {
  local name
  for name in \
    REAL_FCU_T0A_COMPLETE \
    REAL_FCU_T0B_APPROVED \
    REAL_FCU_START_DISARMED \
    REAL_FCU_SAFETY_ON \
    REAL_FCU_PROPELLERS_REMOVED \
    REAL_FCU_HULL_RESTRAINED \
    REAL_FCU_PROPULSION_ISOLATED; do
    rfcu_pi_require_flag "$name" || return 1
  done
}

rfcu_pi_require_run_gates() {
  local name
  rfcu_pi_require_probe_gates || return 1
  for name in REAL_FCU_T2A_APPROVED REAL_FCU_T2B_APPROVED; do
    rfcu_pi_require_flag "$name" || return 1
  done
}

rfcu_pi_require_t2a_run_gates() {
  rfcu_pi_require_probe_gates || return 1
  rfcu_pi_require_flag REAL_FCU_T2A_APPROVED || return 1
  [ "${REAL_FCU_T2B_APPROVED:-0}" = 0 ] \
    || rfcu_pi_fail 'REAL_FCU_T2B_APPROVED must be 0 for run-t2a'
}

rfcu_pi_configure_ros_environment() {
  local discovery_range="$RFCU_PI_DISCOVERY_RANGE" source_rc=0
  [ -r "$RFCU_PI_ROS_SETUP" ] \
    || rfcu_pi_fail "ROS Jazzy setup missing: $RFCU_PI_ROS_SETUP"

  [ "$RFCU_PI_RUN_MODE" != probe ] \
    || discovery_range="$RFCU_PI_PROBE_DISCOVERY_RANGE"

  export ROS_DOMAIN_ID="$RFCU_PI_DOMAIN_ID"
  export ROS_AUTOMATIC_DISCOVERY_RANGE="$discovery_range"
  export ROS_LOCALHOST_ONLY="$RFCU_PI_LOCALHOST_ONLY"
  unset ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
  unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
  unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI

  set +u
  # shellcheck disable=SC1090
  source "$RFCU_PI_ROS_SETUP" || source_rc=$?
  set -u
  [ "$source_rc" -eq 0 ] \
    || rfcu_pi_fail "cannot source ROS Jazzy setup: $RFCU_PI_ROS_SETUP"

  [ "$ROS_DOMAIN_ID" = "$RFCU_PI_DOMAIN_ID" ] \
    || rfcu_pi_fail "ROS_DOMAIN_ID did not remain $RFCU_PI_DOMAIN_ID"
  [ "$ROS_AUTOMATIC_DISCOVERY_RANGE" = "$discovery_range" ] \
    || rfcu_pi_fail \
      "ROS_AUTOMATIC_DISCOVERY_RANGE did not remain $discovery_range"
  [ "$ROS_LOCALHOST_ONLY" = 0 ] \
    || rfcu_pi_fail 'ROS_LOCALHOST_ONLY did not remain 0'
  [ -z "${ROS_STATIC_PEERS:-}" ] || rfcu_pi_fail 'ROS_STATIC_PEERS must be unset'
  [ -z "${ROS_DISCOVERY_SERVER:-}" ] \
    || rfcu_pi_fail 'ROS_DISCOVERY_SERVER must be unset'
  [ -z "${RMW_IMPLEMENTATION:-}" ] \
    || rfcu_pi_fail 'RMW_IMPLEMENTATION must be unset'
  [ -z "${FASTDDS_DEFAULT_PROFILES_FILE:-}" ] \
    || rfcu_pi_fail 'FASTDDS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${FASTRTPS_DEFAULT_PROFILES_FILE:-}" ] \
    || rfcu_pi_fail 'FASTRTPS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${CYCLONEDDS_URI:-}" ] || rfcu_pi_fail 'CYCLONEDDS_URI must be unset'
}

rfcu_pi_reject_conflicts() {
  local pattern output rc found=0
  for pattern in mavros_node real_fcu_rc_command_bridge.py \
    pi_live_hailo_mavlink_dashboard.sh; do
    if output="$(pgrep -af -- "$pattern")"; then
      printf '%s\n' "$output" >&2
      found=1
    else
      rc=$?
      [ "$rc" -eq 1 ] \
        || rfcu_pi_fail "cannot inspect process pattern: $pattern"
    fi
  done
  [ "$found" -eq 0 ] || rfcu_pi_fail 'conflicting Pi process found'
}

rfcu_pi_serial_is_free() {
  local owners rc
  if owners="$(fuser "$RFCU_PI_SERIAL" 2>/dev/null)"; then
    [ -z "$owners" ] || return 1
  else
    rc=$?
    [ "$rc" -eq 1 ] || return 1
  fi
}

rfcu_pi_verify_bundle() {
  local expected actual
  expected=$'tools/real_fcu_digital_twin_pi.sh\ntools/real_fcu_rc_command_bridge.py\nconfig/mavros_real_fcu_closed_loop_plugins.yaml\nconfig/mavros_real_fcu_t0b_plugins.yaml'
  [ -r "$RFCU_PI_BUNDLE_MANIFEST" ] \
    || rfcu_pi_fail "bundle manifest missing: $RFCU_PI_BUNDLE_MANIFEST"
  actual="$(awk '{print $2}' "$RFCU_PI_BUNDLE_MANIFEST")" \
    || rfcu_pi_fail 'cannot read bundle manifest paths'
  [ "$actual" = "$expected" ] \
    || rfcu_pi_fail 'bundle manifest paths changed'
  ( cd "$RFCU_PI_REPO_ROOT" && sha256sum -c "$RFCU_PI_BUNDLE_MANIFEST" ) \
    || rfcu_pi_fail 'deployed Pi bundle checksum failed'
}

rfcu_pi_static_preflight() {
  local command model
  rfcu_pi_validate_positive_integer REAL_FCU_BAUD "$RFCU_PI_BAUD"
  rfcu_pi_validate_positive_integer REAL_FCU_READY_TIMEOUT_SECONDS \
    "$RFCU_PI_READY_TIMEOUT_SECONDS"
  rfcu_pi_validate_positive_integer REAL_FCU_POLL_SECONDS "$RFCU_PI_POLL_SECONDS"
  for command in awk bash date fuser grep mkdir pgrep ps python3 sed setsid \
    sha256sum sleep tail tee timeout tr; do
    rfcu_pi_require_command "$command"
  done
  model="$(tr -d '\0' 2>/dev/null </proc/device-tree/model || true)"
  case "$model" in
    *Raspberry\ Pi\ 5*) ;;
    *) rfcu_pi_fail "unexpected host model: ${model:-UNKNOWN}" ;;
  esac
  [ -d "$RFCU_PI_LOG_ROOT" ] \
    || rfcu_pi_fail "log root missing: $RFCU_PI_LOG_ROOT"
  [ -w "$RFCU_PI_LOG_ROOT" ] \
    || rfcu_pi_fail "log root is not writable: $RFCU_PI_LOG_ROOT"
  rfcu_pi_verify_bundle
  [ -r "$RFCU_PI_BRIDGE" ] || rfcu_pi_fail "bridge missing: $RFCU_PI_BRIDGE"
  [ -r "$RFCU_PI_PLUGIN_YAML" ] \
    || rfcu_pi_fail "closed-loop plugin YAML missing: $RFCU_PI_PLUGIN_YAML"
  [ -r "$RFCU_PI_PROBE_PLUGIN_YAML" ] \
    || rfcu_pi_fail "T0b plugin YAML missing: $RFCU_PI_PROBE_PLUGIN_YAML"
  [ -r "$RFCU_PI_APM_CONFIG" ] \
    || rfcu_pi_fail "MAVROS APM config missing: $RFCU_PI_APM_CONFIG"
  [ -e "$RFCU_PI_SERIAL" ] \
    || rfcu_pi_fail "serial endpoint missing: $RFCU_PI_SERIAL"
  [ -r "$RFCU_PI_SERIAL" ] && [ -w "$RFCU_PI_SERIAL" ] \
    || rfcu_pi_fail "serial endpoint is not readable and writable: $RFCU_PI_SERIAL"
  rfcu_pi_serial_is_free || rfcu_pi_fail "$RFCU_PI_SERIAL already in use"
  rfcu_pi_reject_conflicts
  rfcu_pi_configure_ros_environment
  rfcu_pi_require_command ros2
  ros2 pkg prefix mavros >/dev/null || rfcu_pi_fail 'mavros package missing'
  /usr/bin/python3 -c 'import json, mavros_msgs, rclpy, sensor_msgs, std_msgs, yaml' \
    || rfcu_pi_fail 'Pi ROS/Python imports are unavailable'
  /usr/bin/python3 -c '
import sys
import yaml
for path in sys.argv[1:]:
    data = yaml.safe_load(open(path, encoding="utf-8"))
    assert isinstance(data, dict)
' "$RFCU_PI_PLUGIN_YAML" "$RFCU_PI_PROBE_PLUGIN_YAML" \
    || rfcu_pi_fail 'MAVROS plugin YAML is invalid'
}

rfcu_pi_init_state() {
  local timestamp
  RFCU_PI_CHILD_NAMES=()
  RFCU_PI_CHILD_PIDS=()
  RFCU_PI_CHILD_PGIDS=()
  RFCU_PI_CHILD_INDEX=()
  RFCU_PI_CHILD_ACTIVE=()
  RFCU_PI_CLEANING=0
  RFCU_PI_BRIDGE_STARTED=0
  RFCU_PI_READY_REACHED=0
  RFCU_PI_OPERATOR_STOP_REQUESTED=0
  RFCU_PI_SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')" \
    || rfcu_pi_fail 'cannot determine Pi supervisor process group'
  [[ "$RFCU_PI_SUPERVISOR_PGID" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_pi_fail 'invalid Pi supervisor process group'
  timestamp="$(date +%Y%m%d_%H%M%S)" || rfcu_pi_fail 'cannot create Pi timestamp'
  RFCU_PI_RUN_DIR="$RFCU_PI_LOG_ROOT/real_fcu_digital_twin_pi_$timestamp"
  [ ! -e "$RFCU_PI_RUN_DIR" ] \
    || rfcu_pi_fail "run directory already exists: $RFCU_PI_RUN_DIR"
  mkdir -m 700 "$RFCU_PI_RUN_DIR"
  mkdir -m 700 "$RFCU_PI_RUN_DIR/logs" "$RFCU_PI_RUN_DIR/manifest" \
    "$RFCU_PI_RUN_DIR/evidence"
  RFCU_PI_SUPERVISOR_LOG="$RFCU_PI_RUN_DIR/supervisor.log"
  : >"$RFCU_PI_SUPERVISOR_LOG" || rfcu_pi_fail 'cannot create Pi supervisor log'
}

rfcu_pi_build_commands() {
  local serial_url="serial://$RFCU_PI_SERIAL:$RFCU_PI_BAUD" neutral_only=true
  [ "$RFCU_PI_RUN_MODE" != run ] || neutral_only=false
  RFCU_PI_PROBE_MAVROS_COMMAND=(
    ros2 run mavros mavros_node --ros-args
    --params-file "$RFCU_PI_APM_CONFIG"
    --params-file "$RFCU_PI_PROBE_PLUGIN_YAML"
    -p "fcu_url:=$serial_url"
    -p 'gcs_url:=""'
    -p 'system_id:=255' -p 'component_id:=191'
    -p 'target_system_id:=1' -p 'target_component_id:=1'
  )
  RFCU_PI_MAVROS_COMMAND=(
    ros2 run mavros mavros_node --ros-args
    --params-file "$RFCU_PI_APM_CONFIG"
    --params-file "$RFCU_PI_PLUGIN_YAML"
    -p "fcu_url:=$serial_url"
    -p 'gcs_url:=""'
    -p 'system_id:=255' -p 'component_id:=191'
    -p 'target_system_id:=1' -p 'target_component_id:=1'
  )
  RFCU_PI_BRIDGE_COMMAND=(
    /usr/bin/python3 "$RFCU_PI_BRIDGE" --ros-args
    -p 'allow_real_fcu:=true'
    -p 'expected_domain_id:="43"'
    -p "neutral_only:=$neutral_only"
    -p 'max_steering:=0.20'
    -p 'max_throttle:=0.12'
  )
}

rfcu_pi_write_manifest() {
  printf 'mode=%s\nROS_DOMAIN_ID=%s\nROS_AUTOMATIC_DISCOVERY_RANGE=%s\nROS_LOCALHOST_ONLY=%s\nserial=%s\nbaud=%s\n' \
    "$RFCU_PI_RUN_MODE" "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" \
    "$ROS_LOCALHOST_ONLY" "$RFCU_PI_SERIAL" "$RFCU_PI_BAUD" \
    >"$RFCU_PI_RUN_DIR/manifest/environment.txt"
  sha256sum "$RFCU_PI_SCRIPT_DIR/real_fcu_digital_twin_pi.sh" \
    "$RFCU_PI_BRIDGE" "$RFCU_PI_PLUGIN_YAML" "$RFCU_PI_PROBE_PLUGIN_YAML" \
    "$RFCU_PI_APM_CONFIG" \
    >"$RFCU_PI_RUN_DIR/manifest/artifacts.sha256"
  printf 'probe_mavros' >"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\t%q' "${RFCU_PI_PROBE_MAVROS_COMMAND[@]}" \
    >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\nmavros' >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\t%q' "${RFCU_PI_MAVROS_COMMAND[@]}" \
    >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\nbridge' >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\t%q' "${RFCU_PI_BRIDGE_COMMAND[@]}" \
    >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  printf '\n' >>"$RFCU_PI_RUN_DIR/manifest/commands.tsv"
  ! grep -Eiq 'mavproxy|udp(out)?://|--out=' \
    "$RFCU_PI_RUN_DIR/manifest/commands.tsv" \
    || rfcu_pi_fail 'relay or UDP fanout entered the physical command manifest'
}

rfcu_pi_group_alive() {
  kill -0 -- "-$1" 2>/dev/null
}

rfcu_pi_start_child() {
  local name="$1" logfile="$2" pid pgid index
  shift 2
  [ -z "${RFCU_PI_CHILD_INDEX[$name]+present}" ] \
    || rfcu_pi_fail "child name already registered: $name"
  ( trap - INT QUIT; exec setsid "$@" ) >"$logfile" 2>&1 < /dev/null &
  pid=$!
  sleep 0.2 || true
  kill -0 "$pid" 2>/dev/null \
    || rfcu_pi_fail "$name exited during startup; see $logfile"
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')" \
    || rfcu_pi_fail "cannot determine $name process group"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] \
    || rfcu_pi_fail "invalid $name process group"
  [ "$pgid" = "$pid" ] \
    || rfcu_pi_fail "$name process group is not led by its registered PID"
  [ "$pgid" != "$RFCU_PI_SUPERVISOR_PGID" ] \
    || rfcu_pi_fail "$name did not enter a separate process group"
  RFCU_PI_CHILD_NAMES+=("$name")
  RFCU_PI_CHILD_PIDS+=("$pid")
  RFCU_PI_CHILD_PGIDS+=("$pgid")
  index=$((${#RFCU_PI_CHILD_NAMES[@]} - 1))
  RFCU_PI_CHILD_INDEX[$name]="$index"
  RFCU_PI_CHILD_ACTIVE[$name]=1
  rfcu_pi_log "started $name pid=$pid pgid=$pgid log=$logfile"
}

rfcu_pi_stop_child() {
  local name="$1" index pid pgid signal attempt
  [ -n "${RFCU_PI_CHILD_INDEX[$name]+present}" ] || return 0
  [ "${RFCU_PI_CHILD_ACTIVE[$name]:-0}" -eq 1 ] || return 0
  index="${RFCU_PI_CHILD_INDEX[$name]}"
  pid="${RFCU_PI_CHILD_PIDS[$index]}"
  pgid="${RFCU_PI_CHILD_PGIDS[$index]}"
  [ "$pgid" != "$RFCU_PI_SUPERVISOR_PGID" ] \
    || { rfcu_pi_log_error "refusing supervisor process group for $name"; return 1; }
  if rfcu_pi_group_alive "$pgid"; then
    for signal in INT TERM KILL; do
      kill -"$signal" -- "-$pgid" 2>/dev/null || true
      for attempt in 1 2 3 4 5; do
        rfcu_pi_group_alive "$pgid" || break 2
        sleep 0.2 || true
      done
    done
  fi
  wait "$pid" 2>/dev/null || true
  rfcu_pi_group_alive "$pgid" && return 1
  RFCU_PI_CHILD_ACTIVE[$name]=0
  rfcu_pi_log "stopped $name"
}

rfcu_pi_child_alive() {
  local name="$1" index
  [ "${RFCU_PI_CHILD_ACTIVE[$name]:-0}" -eq 1 ] || return 1
  index="${RFCU_PI_CHILD_INDEX[$name]}"
  kill -0 "${RFCU_PI_CHILD_PIDS[$index]}" 2>/dev/null || return 1
  rfcu_pi_group_alive "${RFCU_PI_CHILD_PGIDS[$index]}"
}

rfcu_pi_active_children_alive() {
  local name
  for name in "${RFCU_PI_CHILD_NAMES[@]}"; do
    [ "${RFCU_PI_CHILD_ACTIVE[$name]:-0}" -eq 1 ] || continue
    rfcu_pi_child_alive "$name" || return 1
  done
}

rfcu_pi_capture_topic() {
  local topic="$1" message_type="$2" output="$3" timeout_seconds="${4:-8}"
  local output_stem="$output" output_suffix=''
  local attempt=1 attempt_output diagnostic_output
  if [[ "$output" == *.yaml ]]; then
    output_stem="${output%.yaml}"
    output_suffix='.yaml'
  fi
  while :; do
    printf -v attempt_output '%s.attempt-%03d%s' \
      "$output_stem" "$attempt" "$output_suffix"
    printf -v diagnostic_output '%s.attempt-%03d.stderr.log' \
      "$output_stem" "$attempt"
    if [ ! -e "$attempt_output" ] && [ ! -e "$diagnostic_output" ]; then
      break
    fi
    attempt=$((attempt + 1))
  done
  ros2 topic echo --once --timeout "$timeout_seconds" --full-length \
    --qos-profile best_available "$topic" "$message_type" \
    2>"$diagnostic_output" | tee "$attempt_output" \
    2>>"$diagnostic_output" >"$output"
}

rfcu_pi_state_file_is_connected_disarmed() {
  /usr/bin/python3 -c '
import sys
import yaml
values = [value for value in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")) if isinstance(value, dict)]
if len(values) != 1:
    raise SystemExit(1)
state = values[0]
if state.get("connected") is not True or state.get("armed") is not False:
    raise SystemExit(1)
' "$1"
}

rfcu_pi_capture_workstation_stop_marker() {
  local output="$1"
  ros2 topic echo --once --timeout "$RFCU_PI_READY_TIMEOUT_SECONDS" \
    --full-length --qos-history keep_last --qos-depth 1 \
    --qos-reliability reliable --qos-durability volatile \
    "$RFCU_PI_WORKSTATION_STOP_TOPIC" std_msgs/msg/String >"$output" \
      2>"$RFCU_PI_RUN_DIR/logs/workstation_stop_capture.log"
}

rfcu_pi_workstation_stop_marker_file_is_valid() {
  /usr/bin/python3 -c '
import sys
import yaml
values = [
    value
    for value in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8"))
    if value is not None
]
if (
    len(values) != 1
    or not isinstance(values[0], dict)
    or set(values[0]) != {"data"}
    or values[0]["data"] != sys.argv[2]
):
    raise SystemExit(1)
' "$1" "$RFCU_PI_WORKSTATION_STOP_MESSAGE"
}

rfcu_pi_wait_workstation_stop_marker() {
  local output="$RFCU_PI_RUN_DIR/evidence/workstation_stop.yaml"
  rfcu_pi_active_children_alive || return 1
  rfcu_pi_capture_workstation_stop_marker "$output" || return 1
  rfcu_pi_active_children_alive || return 1
  rfcu_pi_workstation_stop_marker_file_is_valid "$output"
}

rfcu_pi_wait_connected_disarmed() {
  local child="$1" output="$2" deadline=$((SECONDS + RFCU_PI_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_pi_child_alive "$child" || return 1
    if rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State "$output" 3 \
        && rfcu_pi_state_file_is_connected_disarmed "$output"; then
      return 0
    fi
    sleep "$RFCU_PI_POLL_SECONDS" || true
  done
  return 1
}

rfcu_pi_parameter_value() {
  /usr/bin/python3 -c '
import re
import sys
text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"(?:Integer|Double) value is:\s*(-?[0-9]+(?:\.[0-9]+)?)", text)
if not match:
    raise SystemExit(1)
print(match.group(1))
' "$1"
}

rfcu_pi_read_t0b_parameter() {
  local parameter="$1" parameters_file="$2" parameter_file value
  if ! [[ "$parameter" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
    rfcu_pi_fail "invalid T0b parameter name: $parameter"
    return 1
  fi
  if grep -Fq "$parameter=" "$parameters_file"; then
    rfcu_pi_fail "duplicate T0b parameter request: $parameter"
    return 1
  fi
  parameter_file="$RFCU_PI_RUN_DIR/evidence/t0b_${parameter}.txt"
  if ! timeout 8 ros2 param get /mavros/param "$parameter" \
      >"$parameter_file" 2>&1; then
    rfcu_pi_fail "T0b parameter read failed: $parameter"
    return 1
  fi
  if ! value="$(rfcu_pi_parameter_value "$parameter_file")"; then
    rfcu_pi_fail "T0b parameter value is missing: $parameter"
    return 1
  fi
  if ! printf '%s=%s\n' "$parameter" "$value" >>"$parameters_file"; then
    rfcu_pi_fail "T0b parameter record failed: $parameter"
    return 1
  fi
}

rfcu_pi_capture_t0b() {
  local state_file="$RFCU_PI_RUN_DIR/evidence/t0b_state.yaml"
  local sys_status_file="$RFCU_PI_RUN_DIR/evidence/t0b_sys_status.yaml"
  local pull_file="$RFCU_PI_RUN_DIR/evidence/t0b_param_pull.txt"
  local parameters_file="$RFCU_PI_RUN_DIR/evidence/t0b_parameters.txt"
  local resolver_log="$RFCU_PI_RUN_DIR/logs/t0b_resolver.log"
  local parameter default_value discovery_output rail_output parameter_reads
  local -a discovery_parameters=() rail_parameters=()
  rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State "$state_file" 8 \
    || rfcu_pi_fail 'T0b did not receive a MAVROS state sample'
  rfcu_pi_state_file_is_connected_disarmed "$state_file" \
    || rfcu_pi_fail 'T0b requires connected:true and armed:false'
  rfcu_pi_capture_topic /mavros/sys_status mavros_msgs/msg/SysStatus \
    "$sys_status_file" 8 || rfcu_pi_fail 'T0b did not receive SYS_STATUS'
  /usr/bin/python3 -c '
import sys
import yaml
values = [value for value in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")) if isinstance(value, dict)]
if len(values) != 1:
    raise SystemExit(1)
enabled = values[0].get("sensors_enabled")
if not isinstance(enabled, int) or enabled & 32768:
    raise SystemExit(1)
' "$sys_status_file" || rfcu_pi_fail 'T0b hardware safety state is not ON (safe)'
  timeout 20 ros2 service call /mavros/param/pull mavros_msgs/srv/ParamPull \
    '{force_pull: true}' >"$pull_file" 2>&1 \
    || rfcu_pi_fail 'T0b MAVROS parameter pull failed'
  grep -Eq 'success[=:][[:space:]]*(True|true)' "$pull_file" \
    || rfcu_pi_fail 'T0b MAVROS parameter pull was not successful'
  : >"$parameters_file"
  : >"$resolver_log"
  for parameter in BRD_SAFETY_DEFLT BRD_SAFETY_MASK BRD_SAFETYOPTION; do
    rfcu_pi_read_t0b_parameter "$parameter" "$parameters_file" || return 1
  done
  if ! discovery_output="$(/usr/bin/python3 "$RFCU_PI_BRIDGE" \
      t0b-discovery-parameters 2>>"$resolver_log")"; then
    rfcu_pi_fail 'T0b discovery parameter plan failed'
    return 1
  fi
  mapfile -t discovery_parameters <<<"$discovery_output"
  if [ "${#discovery_parameters[@]}" -ne 18 ]; then
    rfcu_pi_fail 'T0b discovery parameter plan must contain 18 names'
    return 1
  fi
  for parameter in "${discovery_parameters[@]}"; do
    rfcu_pi_read_t0b_parameter "$parameter" "$parameters_file" || return 1
  done
  if ! rail_output="$(/usr/bin/python3 "$RFCU_PI_BRIDGE" \
      t0b-rail-parameters "$parameters_file" 2>>"$resolver_log")"; then
    rfcu_pi_fail 'T0b live mapping resolution failed'
    return 1
  fi
  mapfile -t rail_parameters <<<"$rail_output"
  if [ "${#rail_parameters[@]}" -ne 20 ]; then
    rfcu_pi_fail 'T0b resolved rail plan must contain 20 names'
    return 1
  fi
  for parameter in "${rail_parameters[@]}"; do
    rfcu_pi_read_t0b_parameter "$parameter" "$parameters_file" || return 1
  done
  default_value="$(sed -n 's/^BRD_SAFETY_DEFLT=//p' \
    "$parameters_file")"
  if [ "$default_value" != 1 ] && [ "$default_value" != 1.0 ]; then
    rfcu_pi_fail "BRD_SAFETY_DEFLT is not 1: $default_value"
    return 1
  fi
  if ! /usr/bin/python3 "$RFCU_PI_BRIDGE" t0b-write-evidence \
      "$parameters_file" "$RFCU_PI_RUN_DIR/evidence/t0b.json" \
      "$RFCU_PI_SERIAL" "$ROS_DOMAIN_ID" 2>>"$resolver_log"; then
    rfcu_pi_fail 'T0b mapping and rail artifact validation failed'
    return 1
  fi
  if ! parameter_reads="$(grep -cE '^[A-Z][A-Z0-9_]*=' "$parameters_file")"; then
    rfcu_pi_fail 'T0b parameter record is empty'
    return 1
  fi
  if [ "$parameter_reads" -ne 41 ]; then
    rfcu_pi_fail "T0b parameter record has $parameter_reads values instead of 41"
    return 1
  fi
  rfcu_pi_log "REAL_FCU_T0B=PASS serial=$RFCU_PI_SERIAL parameter_reads=$parameter_reads safety=ON mapping=retained rails=retained"
}

rfcu_pi_verify_telemetry() {
  local topic message_type output label
  while IFS='|' read -r topic message_type label; do
    output="$RFCU_PI_RUN_DIR/evidence/telemetry_${label}.yaml"
    rfcu_pi_capture_topic "$topic" "$message_type" "$output" 10 \
      || rfcu_pi_fail "dashboard telemetry sample missing: $topic"
  done <<'TOPICS'
/mavros/global_position/raw/fix|sensor_msgs/msg/NavSatFix|gps
/mavros/imu/data|sensor_msgs/msg/Imu|imu
/mavros/battery|sensor_msgs/msg/BatteryState|battery
/mavros/rc/in|mavros_msgs/msg/RCIn|rc_in
/mavros/rc/out|mavros_msgs/msg/RCOut|rc_out
TOPICS
  rfcu_pi_log 'REAL_FCU_TELEMETRY=PASS topics=state,GPS,IMU,battery,RC-input,thrust-output'
}

rfcu_pi_wait_bridge_guard() {
  local deadline=$((SECONDS + RFCU_PI_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_pi_child_alive bridge || return 1
    [ "$(grep -Fc 'live guard resolved:' "$RFCU_PI_RUN_DIR/logs/bridge.log")" -eq 1 ] \
      && return 0
    sleep "$RFCU_PI_POLL_SECONDS" || true
  done
  return 1
}

rfcu_pi_status_json_once() {
  local raw
  raw="$(ros2 topic echo --once --timeout 5 --full-length --field data \
    --qos-profile best_available /command_ingress/status std_msgs/msg/String \
    2>>"$RFCU_PI_RUN_DIR/logs/status_probe.log")" || return 1
  printf '%s\n' "$raw" | /usr/bin/python3 -c '
import sys
import yaml
values = [value for value in yaml.safe_load_all(sys.stdin.read()) if isinstance(value, str)]
if len(values) != 1:
    raise SystemExit(1)
print(values[0])
'
}

rfcu_pi_status_is_ready() {
  /usr/bin/python3 -c '
import json
import sys
status = json.loads(sys.argv[1])
expected_neutral_only = sys.argv[2] == "true"
if not (
    status.get("state") == "READY_DISARMED"
    and status.get("ready") is True
    and status.get("connected") is True
    and status.get("armed") is False
    and status.get("mode") == "MANUAL"
    and status.get("feedback_fresh") is True
    and status.get("neutral_only") is expected_neutral_only
):
    raise SystemExit(1)
resolved = status.get("resolved") or {}
values = [resolved.get(key) for key in ("steering_rc", "throttle_rc", "left_servo", "right_servo")]
if not all(isinstance(value, int) and 1 <= value <= 16 for value in values):
    raise SystemExit(1)
if values[0] == values[1] or values[2] == values[3]:
    raise SystemExit(1)
' "$1" "$2"
}

rfcu_pi_wait_bridge_ready() {
  local deadline=$((SECONDS + RFCU_PI_READY_TIMEOUT_SECONDS))
  local status_json expected_neutral_only=false
  [ "$RFCU_PI_RUN_MODE" != run-t2a ] || expected_neutral_only=true
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_pi_active_children_alive || return 1
    if status_json="$(rfcu_pi_status_json_once)" \
        && rfcu_pi_status_is_ready "$status_json" "$expected_neutral_only"; then
      printf '%s\n' "$status_json" \
        >"$RFCU_PI_RUN_DIR/evidence/ready_status.json"
      return 0
    fi
    sleep "$RFCU_PI_POLL_SECONDS" || true
  done
  return 1
}

rfcu_pi_wait_workstation_nodes() {
  local deadline=$((SECONDS + RFCU_PI_READY_TIMEOUT_SECONDS)) nodes
  while [ "$SECONDS" -lt "$deadline" ]; do
    rfcu_pi_active_children_alive || return 1
    nodes="$(ros2 node list --no-daemon --spin-time 2 2>/dev/null)" || nodes=''
    if grep -Fxq '/rosbridge_websocket' <<<"$nodes" \
        && grep -Fxq '/rosapi' <<<"$nodes"; then
      return 0
    fi
    sleep "$RFCU_PI_POLL_SECONDS" || true
  done
  return 1
}

rfcu_pi_cleanup() {
  local incoming_rc=$? cleanup_rc=0 final_rc final_state operator_success=0
  [ "$RFCU_PI_CLEANING" -eq 0 ] || return "$incoming_rc"
  RFCU_PI_CLEANING=1
  trap - EXIT INT TERM
  set +e
  if [[ "$RFCU_PI_RUN_MODE" == run || "$RFCU_PI_RUN_MODE" == run-t2a ]] \
      && [ "$RFCU_PI_BRIDGE_STARTED" -eq 1 ]; then
    final_state="$RFCU_PI_RUN_DIR/evidence/final_state.yaml"
    if ! rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State "$final_state" 3 \
        || ! rfcu_pi_state_file_is_connected_disarmed "$final_state"; then
      rfcu_pi_log_error 'REAL_FCU_FINAL_STATE=FAIL expected=connected,disarmed'
      cleanup_rc=1
    else
      rfcu_pi_log 'REAL_FCU_FINAL_STATE=PASS connected=true armed=false'
      if [ "$RFCU_PI_OPERATOR_STOP_REQUESTED" -eq 1 ] \
          && [ "$RFCU_PI_READY_REACHED" -eq 1 ]; then
        rfcu_pi_log 'waiting for workstation operator stop before bridge shutdown'
        if rfcu_pi_wait_workstation_stop_marker; then
          rfcu_pi_log "REAL_FCU_WORKSTATION_STOP=PASS marker=received topic=$RFCU_PI_WORKSTATION_STOP_TOPIC"
          operator_success=1
        else
          rfcu_pi_log_error 'REAL_FCU_WORKSTATION_STOP=FAIL marker=missing-or-invalid'
          cleanup_rc=1
        fi
      fi
    fi
  fi
  rfcu_pi_stop_child bridge || cleanup_rc=1
  rfcu_pi_stop_child mavros || cleanup_rc=1
  rfcu_pi_stop_child mavros-probe || cleanup_rc=1
  rfcu_pi_serial_is_free || cleanup_rc=1
  final_rc="$incoming_rc"
  if [ "$incoming_rc" -eq 130 ] && [ "$operator_success" -eq 1 ] \
      && [ "$cleanup_rc" -eq 0 ]; then
    final_rc=0
  elif [ "$final_rc" -eq 0 ]; then
    final_rc="$cleanup_rc"
  fi
  [ -z "$RFCU_PI_RUN_DIR" ] || rfcu_pi_log "REAL_FCU_PI_LOGS=$RFCU_PI_RUN_DIR"
  rfcu_pi_log "REAL_FCU_PI_EXIT status=$final_rc cleanup_rc=$cleanup_rc"
  exit "$final_rc"
}

rfcu_pi_on_interrupt() {
  RFCU_PI_OPERATOR_STOP_REQUESTED=1
  rfcu_pi_log 'operator stop requested; neutral/release precedes MAVROS shutdown'
  exit 130
}

rfcu_pi_on_term() {
  rfcu_pi_log_error 'termination requested; neutral/release precedes MAVROS shutdown'
  exit 143
}

rfcu_pi_check() {
  rfcu_pi_static_preflight
  rfcu_pi_log "REAL_FCU_PI_CHECK=PASS serial=$RFCU_PI_SERIAL runtime=not-started"
}

rfcu_pi_probe() {
  RFCU_PI_RUN_MODE=probe
  rfcu_pi_require_probe_gates
  rfcu_pi_static_preflight
  rfcu_pi_init_state
  rfcu_pi_build_commands
  rfcu_pi_write_manifest
  trap rfcu_pi_cleanup EXIT
  trap rfcu_pi_on_interrupt INT
  trap rfcu_pi_on_term TERM
  rfcu_pi_log "REAL_FCU_PI_START mode=probe domain=$RFCU_PI_DOMAIN_ID discovery=$ROS_AUTOMATIC_DISCOVERY_RANGE run_dir=$RFCU_PI_RUN_DIR"
  rfcu_pi_start_child mavros-probe "$RFCU_PI_RUN_DIR/logs/mavros_probe.log" \
    "${RFCU_PI_PROBE_MAVROS_COMMAND[@]}"
  rfcu_pi_wait_connected_disarmed mavros-probe \
    "$RFCU_PI_RUN_DIR/evidence/probe_connected_disarmed.yaml" \
    || rfcu_pi_fail 'T0b MAVROS did not reach connected:true and armed:false'
  rfcu_pi_capture_t0b
  rfcu_pi_log 'REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started'
}

rfcu_pi_run() {
  local tier authority
  RFCU_PI_RUN_MODE="$1"
  case "$RFCU_PI_RUN_MODE" in
    run-t2a)
      rfcu_pi_require_t2a_run_gates || return 1
      tier=T2a
      authority=neutral-only
      ;;
    run)
      rfcu_pi_require_run_gates || return 1
      tier=T2b
      authority=demand-enabled
      ;;
    *)
      rfcu_pi_fail "unsupported run mode: $RFCU_PI_RUN_MODE"
      return 1
      ;;
  esac
  rfcu_pi_static_preflight
  rfcu_pi_init_state
  rfcu_pi_build_commands
  rfcu_pi_write_manifest
  trap rfcu_pi_cleanup EXIT
  trap rfcu_pi_on_interrupt INT
  trap rfcu_pi_on_term TERM
  rfcu_pi_log "REAL_FCU_PI_START mode=$RFCU_PI_RUN_MODE tier=$tier authority=$authority domain=$RFCU_PI_DOMAIN_ID discovery=SUBNET run_dir=$RFCU_PI_RUN_DIR"

  rfcu_pi_start_child mavros-probe "$RFCU_PI_RUN_DIR/logs/mavros_probe.log" \
    "${RFCU_PI_PROBE_MAVROS_COMMAND[@]}"
  rfcu_pi_wait_connected_disarmed mavros-probe \
    "$RFCU_PI_RUN_DIR/evidence/probe_connected_disarmed.yaml" \
    || rfcu_pi_fail 'T0b MAVROS did not reach connected:true and armed:false'
  rfcu_pi_capture_t0b
  rfcu_pi_stop_child mavros-probe \
    || rfcu_pi_fail 'T0b MAVROS did not stop cleanly'
  rfcu_pi_serial_is_free || rfcu_pi_fail 'serial remained owned after T0b'

  rfcu_pi_start_child mavros "$RFCU_PI_RUN_DIR/logs/mavros.log" \
    "${RFCU_PI_MAVROS_COMMAND[@]}"
  rfcu_pi_wait_connected_disarmed mavros \
    "$RFCU_PI_RUN_DIR/evidence/run_connected_disarmed.yaml" \
    || rfcu_pi_fail 'full MAVROS did not reach connected:true and armed:false'
  rfcu_pi_verify_telemetry
  rfcu_pi_start_child bridge "$RFCU_PI_RUN_DIR/logs/bridge.log" \
    "${RFCU_PI_BRIDGE_COMMAND[@]}"
  RFCU_PI_BRIDGE_STARTED=1
  rfcu_pi_wait_bridge_guard \
    || rfcu_pi_fail 'bridge did not resolve the complete live guard'
  grep -F 'live guard resolved:' "$RFCU_PI_RUN_DIR/logs/bridge.log" \
    | tail -1 | tee "$RFCU_PI_RUN_DIR/evidence/resolved_mapping.txt"
  rfcu_pi_log 'REAL_FCU_MANUAL_GATE=release hardware safety physically while disarmed; no software safety command exists here'
  rfcu_pi_wait_bridge_ready \
    || rfcu_pi_fail 'bridge did not reach fresh READY_DISARMED after the manual safety gate'
  rfcu_pi_wait_workstation_nodes \
    || rfcu_pi_fail 'workstation rosbridge/rosapi nodes were not discovered'
  RFCU_PI_READY_REACHED=1
  rfcu_pi_log "REAL_FCU_PI_READY=PASS tier=$tier authority=$authority bridge=READY_DISARMED workstation=visible"
  rfcu_pi_log 'arming remains external; planned stop requires external disarm before Ctrl+C'

  while rfcu_pi_active_children_alive; do
    sleep "$RFCU_PI_POLL_SECONDS" || true
  done
  rfcu_pi_fail 'a Pi child exited unexpectedly'
}

rfcu_pi_main() {
  case "$#:${1:-}" in
    1:check) rfcu_pi_check ;;
    1:probe) rfcu_pi_probe ;;
    1:run-t2a) rfcu_pi_run run-t2a ;;
    1:run) rfcu_pi_run run ;;
    *) rfcu_pi_usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  rfcu_pi_main "$@"
fi
