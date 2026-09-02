#!/usr/bin/env bash

# Owns only the isolated workstation VRX simulator and FCU-output bridge.

set -euo pipefail

FCUVRX_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FCUVRX_REPO_ROOT="$(cd -- "$FCUVRX_SCRIPT_DIR/.." && pwd)"
FCUVRX_BRIDGE="$FCUVRX_SCRIPT_DIR/servo_command_bridge.py"
FCUVRX_EVIDENCE="$FCUVRX_SCRIPT_DIR/fcu_to_vrx_evidence.py"
FCUVRX_ROS_SETUP="${FCU_TO_VRX_ROS_SETUP:-/opt/ros/jazzy/setup.bash}"
FCUVRX_WORKSPACE_SETUP="${FCU_TO_VRX_WORKSPACE_SETUP:-$FCUVRX_REPO_ROOT/../../install/setup.bash}"
FCUVRX_LOG_ROOT="${FCU_TO_VRX_LOG_ROOT:-$HOME/Desktop}"
FCUVRX_READY_TIMEOUT_SECONDS="${FCU_TO_VRX_READY_TIMEOUT_SECONDS:-120}"
FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS="${FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS:-900}"
FCUVRX_POLL_SECONDS="${FCU_TO_VRX_POLL_SECONDS:-1}"
FCUVRX_DOMAIN_ID='77'
FCUVRX_DISCOVERY_RANGE='LOCALHOST'
FCUVRX_LOCALHOST_ONLY='1'
FCUVRX_RELAY_DOMAIN_ID='43'
FCUVRX_RELAY_DISCOVERY_RANGE='SUBNET'
FCUVRX_RELAY_LOCALHOST_ONLY='0'
FCUVRX_UDP_RECV_PORT='14555'
FCUVRX_UDP_SEND_PORT='14551'
FCUVRX_TWIN_TELEMETRY_UDP_PORT='14556'
FCUVRX_TWIN_TELEMETRY_TOPIC='/fcu_to_vrx/twin_telemetry'
FCUVRX_TWIN_TELEMETRY_SCHEMA='uvautoboat.fcu_to_vrx.twin_telemetry.v1'
FCUVRX_TWIN_TELEMETRY_SOURCE='fcu_to_vrx_domain77_bridge'
FCUVRX_WORLD='sydney_regatta'
FCUVRX_RUN_MODE='run'
FCUVRX_VRX_SHARE=''
FCUVRX_RUN_DIR=''
FCUVRX_SUPERVISOR_LOG=''
FCUVRX_SUPERVISOR_PGID=''
FCUVRX_CLEANING=0
FCUVRX_STARTED=0
FCUVRX_READY_REACHED=0
FCUVRX_OPERATOR_STOP_REQUESTED=0

FCU_VRX_LEFT_SERVO_CHANNEL="${FCU_VRX_LEFT_SERVO_CHANNEL:-}"
FCU_VRX_RIGHT_SERVO_CHANNEL="${FCU_VRX_RIGHT_SERVO_CHANNEL:-}"
FCU_VRX_LEFT_PWM_MIN="${FCU_VRX_LEFT_PWM_MIN:-}"
FCU_VRX_LEFT_PWM_NEUTRAL="${FCU_VRX_LEFT_PWM_NEUTRAL:-}"
FCU_VRX_LEFT_PWM_MAX="${FCU_VRX_LEFT_PWM_MAX:-}"
FCU_VRX_RIGHT_PWM_MIN="${FCU_VRX_RIGHT_PWM_MIN:-}"
FCU_VRX_RIGHT_PWM_NEUTRAL="${FCU_VRX_RIGHT_PWM_NEUTRAL:-}"
FCU_VRX_RIGHT_PWM_MAX="${FCU_VRX_RIGHT_PWM_MAX:-}"
FCU_VRX_MAX_THRUST="${FCU_VRX_MAX_THRUST:-}"
FCU_VRX_CORRELATED_OBSERVATION="${FCU_VRX_CORRELATED_OBSERVATION:-0}"
FCU_VRX_OBSERVER_STALE_SECONDS="${FCU_VRX_OBSERVER_STALE_SECONDS:-}"
FCU_VRX_PWM_MIN=''
FCU_VRX_PWM_NEUTRAL=''
FCU_VRX_PWM_MAX=''

declare -a FCUVRX_CHILD_NAMES=()
declare -a FCUVRX_CHILD_PIDS=()
declare -a FCUVRX_CHILD_PGIDS=()
declare -A FCUVRX_CHILD_INDEX=()
declare -a FCUVRX_VRX_COMMAND=()
declare -a FCUVRX_BRIDGE_COMMAND=()
declare -a FCUVRX_OBSERVER_COMMAND=()
declare -a FCUVRX_RELAY_COMMAND=()

FCUVRX_CONFLICT_PATTERNS=(
  'servo_command_bridge.py'
  'competition.launch.py'
  'gz sim'
  'gazebo'
  'ardurover'
  'sim_vehicle.py'
  'mavproxy.py'
  'MAVProxy'
  'mavros_node'
)

fcuvrx_append_log() {
  local line="$1"
  [ -n "$FCUVRX_SUPERVISOR_LOG" ] || return 0
  printf 'timestamp=%s %s\n' "${EPOCHREALTIME:-unknown}" "$line" \
    >>"$FCUVRX_SUPERVISOR_LOG" 2>/dev/null || true
}

fcuvrx_log() {
  local line="[fcu-to-vrx-workstation] $*"
  fcuvrx_append_log "$line"
  printf '%s\n' "$line"
}

fcuvrx_log_error() {
  local line="[fcu-to-vrx-workstation] $*"
  fcuvrx_append_log "$line"
  printf '%s\n' "$line" >&2
}

# Terminates. Returning here would leave 55 guards continued past inside their
# own function: a failed PWM-rail or ROS-environment check would fall through to
# the later checks and the function could still return success to a caller that
# suppresses set -e. Exiting keeps every guard fail-closed by construction.
fcuvrx_fail() {
  fcuvrx_log_error "STOP: $*"
  exit 1
}

fcuvrx_usage() {
  cat >&2 <<EOF
usage: ${0##*/} check|run|run-real-fcu

run and run-real-fcu require all values below from the same live FCU parameter read:
  FCU_VRX_LEFT_SERVO_CHANNEL
  FCU_VRX_RIGHT_SERVO_CHANNEL
  FCU_VRX_LEFT_PWM_MIN / FCU_VRX_LEFT_PWM_NEUTRAL / FCU_VRX_LEFT_PWM_MAX
  FCU_VRX_RIGHT_PWM_MIN / FCU_VRX_RIGHT_PWM_NEUTRAL / FCU_VRX_RIGHT_PWM_MAX
  FCU_VRX_MAX_THRUST (positive decimal, for example 800.0)

Block E additionally requires:
  FCU_VRX_CORRELATED_OBSERVATION=1
  FCU_VRX_OBSERVER_STALE_SECONDS (positive integer measured in Block D)
EOF
  return 2
}

fcuvrx_real_fcu_mode() {
  [ "$FCUVRX_RUN_MODE" = run-real-fcu ]
}

fcuvrx_require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fcuvrx_fail "required command missing: $1"
}

fcuvrx_require_value() {
  local name="$1"
  [ -n "${!name:-}" ] || fcuvrx_fail "$name is required"
}

fcuvrx_validate_channel() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 16 ] \
    || fcuvrx_fail "$name must be an integer in 1..16"
}

fcuvrx_validate_pwm_rail() {
  local side="$1" minimum="$2" neutral="$3" maximum="$4"
  local value
  for value in "$minimum" "$neutral" "$maximum"; do
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 65535 ] \
      || fcuvrx_fail "$side PWM values must be integers in 1..65535"
  done
  [ "$minimum" -le "$neutral" ] && [ "$neutral" -lt "$maximum" ] \
    || fcuvrx_fail "$side PWM rail must satisfy min <= neutral < max"
}

fcuvrx_validate_max_thrust() {
  local value="$1"
  /usr/bin/python3 - "$value" <<'PY' >/dev/null 2>&1
import math
import re
import sys

value = sys.argv[1]
if re.fullmatch(r"[0-9]+\.[0-9]+", value) is None:
    raise SystemExit(1)
number = float(value)
if not math.isfinite(number) or number <= 0.0:
    raise SystemExit(1)
PY
}

fcuvrx_validate_configuration() {
  local name
  for name in \
    FCU_VRX_LEFT_SERVO_CHANNEL FCU_VRX_RIGHT_SERVO_CHANNEL \
    FCU_VRX_LEFT_PWM_MIN FCU_VRX_LEFT_PWM_NEUTRAL FCU_VRX_LEFT_PWM_MAX \
    FCU_VRX_RIGHT_PWM_MIN FCU_VRX_RIGHT_PWM_NEUTRAL FCU_VRX_RIGHT_PWM_MAX \
    FCU_VRX_MAX_THRUST; do
    fcuvrx_require_value "$name" || return 1
  done

  fcuvrx_validate_channel FCU_VRX_LEFT_SERVO_CHANNEL \
    "$FCU_VRX_LEFT_SERVO_CHANNEL" || return 1
  fcuvrx_validate_channel FCU_VRX_RIGHT_SERVO_CHANNEL \
    "$FCU_VRX_RIGHT_SERVO_CHANNEL" || return 1
  [ "$FCU_VRX_LEFT_SERVO_CHANNEL" != "$FCU_VRX_RIGHT_SERVO_CHANNEL" ] \
    || fcuvrx_fail 'left and right servo channels must be distinct'

  fcuvrx_validate_pwm_rail left "$FCU_VRX_LEFT_PWM_MIN" \
    "$FCU_VRX_LEFT_PWM_NEUTRAL" "$FCU_VRX_LEFT_PWM_MAX" || return 1
  fcuvrx_validate_pwm_rail right "$FCU_VRX_RIGHT_PWM_MIN" \
    "$FCU_VRX_RIGHT_PWM_NEUTRAL" "$FCU_VRX_RIGHT_PWM_MAX" || return 1

  if [ "$FCU_VRX_LEFT_PWM_MIN" != "$FCU_VRX_RIGHT_PWM_MIN" ] \
      || [ "$FCU_VRX_LEFT_PWM_NEUTRAL" != "$FCU_VRX_RIGHT_PWM_NEUTRAL" ] \
      || [ "$FCU_VRX_LEFT_PWM_MAX" != "$FCU_VRX_RIGHT_PWM_MAX" ]; then
    fcuvrx_fail 'left and right PWM rails must match for the current bridge' \
      || return 1
  fi
  fcuvrx_validate_max_thrust "$FCU_VRX_MAX_THRUST" \
    || fcuvrx_fail 'FCU_VRX_MAX_THRUST must be a finite decimal greater than zero' \
    || return 1
  [[ "$FCU_VRX_CORRELATED_OBSERVATION" =~ ^[01]$ ]] \
    || fcuvrx_fail 'FCU_VRX_CORRELATED_OBSERVATION must be 0 or 1' \
    || return 1
  if fcuvrx_real_fcu_mode \
      && [ "$FCU_VRX_CORRELATED_OBSERVATION" -ne 1 ]; then
    fcuvrx_fail 'run-real-fcu requires FCU_VRX_CORRELATED_OBSERVATION=1' \
      || return 1
  fi
  if [ "$FCU_VRX_CORRELATED_OBSERVATION" -eq 1 ]; then
    fcuvrx_require_value FCU_VRX_OBSERVER_STALE_SECONDS || return 1
    fcuvrx_validate_positive_integer FCU_VRX_OBSERVER_STALE_SECONDS \
      "$FCU_VRX_OBSERVER_STALE_SECONDS" || return 1
  fi

  FCU_VRX_PWM_MIN="$FCU_VRX_LEFT_PWM_MIN"
  FCU_VRX_PWM_NEUTRAL="$FCU_VRX_LEFT_PWM_NEUTRAL"
  FCU_VRX_PWM_MAX="$FCU_VRX_LEFT_PWM_MAX"
}

fcuvrx_validate_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] \
    || fcuvrx_fail "$name must be a positive integer"
}

fcuvrx_configure_ros_environment() {
  local source_rc=0
  [ -r "$FCUVRX_ROS_SETUP" ] \
    || fcuvrx_fail "ROS setup missing: $FCUVRX_ROS_SETUP"
  [ -r "$FCUVRX_WORKSPACE_SETUP" ] \
    || fcuvrx_fail "workspace setup missing: $FCUVRX_WORKSPACE_SETUP"

  export ROS_DOMAIN_ID="$FCUVRX_DOMAIN_ID"
  export ROS_AUTOMATIC_DISCOVERY_RANGE="$FCUVRX_DISCOVERY_RANGE"
  export ROS_LOCALHOST_ONLY="$FCUVRX_LOCALHOST_ONLY"
  unset ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
  unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
  unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI

  set +u
  # shellcheck disable=SC1090
  source "$FCUVRX_ROS_SETUP" || source_rc=$?
  if [ "$source_rc" -eq 0 ]; then
    # shellcheck disable=SC1090
    source "$FCUVRX_WORKSPACE_SETUP" || source_rc=$?
  fi
  set -u
  [ "$source_rc" -eq 0 ] \
    || fcuvrx_fail 'cannot source the ROS/workspace environment'

  [ "$ROS_DOMAIN_ID" = 77 ] || fcuvrx_fail 'ROS_DOMAIN_ID did not remain 77'
  [ "$ROS_AUTOMATIC_DISCOVERY_RANGE" = LOCALHOST ] \
    || fcuvrx_fail 'ROS_AUTOMATIC_DISCOVERY_RANGE did not remain LOCALHOST'
  [ "$ROS_LOCALHOST_ONLY" = 1 ] \
    || fcuvrx_fail 'ROS_LOCALHOST_ONLY did not remain 1'
  [ -z "${ROS_STATIC_PEERS:-}" ] || fcuvrx_fail 'ROS_STATIC_PEERS must be unset'
  [ -z "${ROS_DISCOVERY_SERVER:-}" ] \
    || fcuvrx_fail 'ROS_DISCOVERY_SERVER must be unset'
  [ -z "${RMW_IMPLEMENTATION:-}" ] \
    || fcuvrx_fail 'RMW_IMPLEMENTATION must be unset'
  [ -z "${FASTDDS_DEFAULT_PROFILES_FILE:-}" ] \
    || fcuvrx_fail 'FASTDDS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${FASTRTPS_DEFAULT_PROFILES_FILE:-}" ] \
    || fcuvrx_fail 'FASTRTPS_DEFAULT_PROFILES_FILE must be unset'
  [ -z "${CYCLONEDDS_URI:-}" ] || fcuvrx_fail 'CYCLONEDDS_URI must be unset'
}

fcuvrx_verify_repository() {
  local status head upstream
  [ -d "$FCUVRX_REPO_ROOT/.git" ] \
    || fcuvrx_fail "repository missing: $FCUVRX_REPO_ROOT"
  status="$(git -C "$FCUVRX_REPO_ROOT" status --porcelain=v1 --untracked-files=all)" \
    || fcuvrx_fail 'cannot inspect repository state'
  [ -z "$status" ] \
    || fcuvrx_fail 'FCU-to-VRX run requires a clean worktree'
  head="$(git -C "$FCUVRX_REPO_ROOT" rev-parse HEAD)" \
    || fcuvrx_fail 'cannot read repository HEAD'
  upstream="$(git -C "$FCUVRX_REPO_ROOT" rev-parse refs/remotes/origin/main)" \
    || fcuvrx_fail 'cannot read origin/main'
  [ "$head" = "$upstream" ] \
    || fcuvrx_fail 'repository HEAD does not match origin/main'
}

fcuvrx_udp_port_listener_present() {
  local target="$1" state
  state="$(ss -H -lun)" || return 2
  awk -v target="$target" '
    {
      local_address = $4
      sub(/^.*:/, "", local_address)
      if (local_address == target) found = 1
    }
    END { exit found ? 0 : 1 }
  ' <<<"$state"
}

fcuvrx_udp_listener_present() {
  fcuvrx_udp_port_listener_present "$FCUVRX_UDP_RECV_PORT"
}

fcuvrx_twin_telemetry_listener_present() {
  fcuvrx_udp_port_listener_present "$FCUVRX_TWIN_TELEMETRY_UDP_PORT"
}

fcuvrx_require_udp_port_free() {
  local rc
  if fcuvrx_udp_listener_present; then
    fcuvrx_fail "UDP $FCUVRX_UDP_RECV_PORT is already in use"
    return 1
  else
    rc=$?
  fi
  [ "$rc" -eq 1 ] || fcuvrx_fail 'cannot inspect workstation UDP listeners'
}

fcuvrx_require_twin_telemetry_port_free() {
  local rc
  if fcuvrx_twin_telemetry_listener_present; then
    fcuvrx_fail \
      "UDP $FCUVRX_TWIN_TELEMETRY_UDP_PORT is already in use by twin telemetry"
    return 1
  else
    rc=$?
  fi
  [ "$rc" -eq 1 ] \
    || fcuvrx_fail 'cannot inspect twin telemetry UDP listener'
}

fcuvrx_reject_conflicts() {
  local pattern output rc found=0
  for pattern in "${FCUVRX_CONFLICT_PATTERNS[@]}"; do
    if output="$(pgrep -af -- "$pattern")"; then
      printf '%s\n' "$output" >&2
      found=1
    else
      rc=$?
      [ "$rc" -eq 1 ] \
        || fcuvrx_fail "cannot inspect process pattern: $pattern"
    fi
  done
  [ "$found" -eq 0 ] || fcuvrx_fail 'conflicting simulator or FCU process found'
}

fcuvrx_reject_domain_nodes() {
  local nodes
  nodes="$(ros2 node list --no-daemon --spin-time 2)" \
    || fcuvrx_fail 'cannot inspect ROS domain 77'
  if [ -n "$nodes" ]; then
    printf '%s\n' "$nodes" >&2
    fcuvrx_fail 'ROS domain 77 is not empty'
    return 1
  fi
}

fcuvrx_static_preflight() {
  local command
  fcuvrx_validate_configuration
  fcuvrx_validate_positive_integer FCU_TO_VRX_READY_TIMEOUT_SECONDS \
    "$FCUVRX_READY_TIMEOUT_SECONDS"
  fcuvrx_validate_positive_integer FCU_TO_VRX_POLL_SECONDS \
    "$FCUVRX_POLL_SECONDS"
  fcuvrx_validate_positive_integer FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS \
    "$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS"
  for command in awk bash date git grep mkdir pgrep ps python3 sed setsid \
    sha256sum sleep ss tail tr; do
    fcuvrx_require_command "$command"
  done
  [ -d "$FCUVRX_LOG_ROOT" ] \
    || fcuvrx_fail "log root missing: $FCUVRX_LOG_ROOT"
  [ -w "$FCUVRX_LOG_ROOT" ] \
    || fcuvrx_fail "log root is not writable: $FCUVRX_LOG_ROOT"
  [ -r "$FCUVRX_BRIDGE" ] || fcuvrx_fail "bridge missing: $FCUVRX_BRIDGE"
  [ -r "$FCUVRX_EVIDENCE" ] \
    || fcuvrx_fail "evidence observer missing: $FCUVRX_EVIDENCE"
  [ -x /usr/bin/env ] || fcuvrx_fail '/usr/bin/env is unavailable'
  [ -x /usr/bin/python3 ] || fcuvrx_fail '/usr/bin/python3 is unavailable'
  fcuvrx_verify_repository
  fcuvrx_require_udp_port_free
  if fcuvrx_real_fcu_mode; then
    fcuvrx_require_twin_telemetry_port_free
  fi
  fcuvrx_reject_conflicts
  fcuvrx_configure_ros_environment
  fcuvrx_require_command ros2
  fcuvrx_reject_domain_nodes
  FCUVRX_VRX_SHARE="$(ros2 pkg prefix --share vrx_gz)" \
    || fcuvrx_fail 'vrx_gz package is unavailable'
  [ -r "$FCUVRX_VRX_SHARE/worlds/$FCUVRX_WORLD.sdf" ] \
    || fcuvrx_fail "VRX world is missing: $FCUVRX_WORLD"
  [ -r "$FCUVRX_VRX_SHARE/config/wamv.yaml" ] \
    || fcuvrx_fail 'VRX WAM-V configuration is missing'
  grep -Fq '/wamv/thrusters/left/thrust' "$FCUVRX_VRX_SHARE/config/wamv.yaml" \
    || fcuvrx_fail 'VRX left-thrust topic contract is missing'
  grep -Fq '/wamv/thrusters/right/thrust' "$FCUVRX_VRX_SHARE/config/wamv.yaml" \
    || fcuvrx_fail 'VRX right-thrust topic contract is missing'
  /usr/bin/python3 -c 'import pymavlink, rclpy, tf2_msgs' \
    || fcuvrx_fail 'bridge Python dependencies are unavailable'
}

fcuvrx_build_commands() {
  FCUVRX_RELAY_COMMAND=()
  FCUVRX_VRX_COMMAND=(
    ros2 launch vrx_gz competition.launch.py
    "world:=$FCUVRX_WORLD" 'sim_mode:=full'
  )
  FCUVRX_BRIDGE_COMMAND=(
    /usr/bin/python3 "$FCUVRX_BRIDGE" --ros-args
    -p "udp_recv_port:=$FCUVRX_UDP_RECV_PORT"
    -p "udp_send_port:=$FCUVRX_UDP_SEND_PORT"
    -p 'target_ip:=127.0.0.1'
    -p "left_servo_channel:=$FCU_VRX_LEFT_SERVO_CHANNEL"
    -p "right_servo_channel:=$FCU_VRX_RIGHT_SERVO_CHANNEL"
    -p "pwm_min:=$FCU_VRX_PWM_MIN"
    -p "pwm_neutral:=$FCU_VRX_PWM_NEUTRAL"
    -p "pwm_max:=$FCU_VRX_PWM_MAX"
    -p "max_thrust:=$FCU_VRX_MAX_THRUST"
    -p 'publish_sensors:=false'
    -p 'publish_cmd_vel:=false'
  )
  FCUVRX_OBSERVER_COMMAND=(
    /usr/bin/python3 "$FCUVRX_EVIDENCE" observe-vrx
    --output "$FCUVRX_RUN_DIR/evidence/vrx_events.jsonl"
    --status "$FCUVRX_RUN_DIR/evidence/vrx_status.json"
    --stale-seconds "${FCU_VRX_OBSERVER_STALE_SECONDS:-0}"
    --left-channel "$FCU_VRX_LEFT_SERVO_CHANNEL"
    --right-channel "$FCU_VRX_RIGHT_SERVO_CHANNEL"
    --left-min "$FCU_VRX_LEFT_PWM_MIN"
    --left-trim "$FCU_VRX_LEFT_PWM_NEUTRAL"
    --left-max "$FCU_VRX_LEFT_PWM_MAX"
    --right-min "$FCU_VRX_RIGHT_PWM_MIN"
    --right-trim "$FCU_VRX_RIGHT_PWM_NEUTRAL"
    --right-max "$FCU_VRX_RIGHT_PWM_MAX"
    --max-thrust "$FCU_VRX_MAX_THRUST"
    --servo-topic /fcu_to_vrx/servo_output_raw
    --left-thrust-topic /wamv/thrusters/left/thrust
    --right-thrust-topic /wamv/thrusters/right/thrust
    --pose-topic /wamv/pose
    --world-frame "$FCUVRX_WORLD"
  )
  if fcuvrx_real_fcu_mode; then
    FCUVRX_BRIDGE_COMMAND+=(
      -p 'twin_telemetry_role:=sender'
      -p "twin_telemetry_udp_port:=$FCUVRX_TWIN_TELEMETRY_UDP_PORT"
      -p "twin_telemetry_topic:=$FCUVRX_TWIN_TELEMETRY_TOPIC"
      -p 'twin_telemetry_pose_topic:=/wamv/pose'
      -p "twin_telemetry_world_frame:=$FCUVRX_WORLD"
      -p "twin_telemetry_stale_seconds:=$FCU_VRX_OBSERVER_STALE_SECONDS"
    )
    FCUVRX_RELAY_COMMAND=(
      /usr/bin/env
      "ROS_DOMAIN_ID=$FCUVRX_RELAY_DOMAIN_ID"
      "ROS_AUTOMATIC_DISCOVERY_RANGE=$FCUVRX_RELAY_DISCOVERY_RANGE"
      "ROS_LOCALHOST_ONLY=$FCUVRX_RELAY_LOCALHOST_ONLY"
      /usr/bin/python3 "$FCUVRX_BRIDGE" --ros-args
      -r '__node:=fcu_to_vrx_rc_out_relay'
      -p 'input_mode:=ros_rc_out_relay'
      -p 'rc_out_topic:=/mavros/rc/out'
      -p 'rc_out_publisher:=/mavros/rc'
      -p 'target_ip:=127.0.0.1'
      -p "udp_send_port:=$FCUVRX_UDP_RECV_PORT"
      -p "left_servo_channel:=$FCU_VRX_LEFT_SERVO_CHANNEL"
      -p "right_servo_channel:=$FCU_VRX_RIGHT_SERVO_CHANNEL"
      -p "pwm_min:=$FCU_VRX_PWM_MIN"
      -p "pwm_neutral:=$FCU_VRX_PWM_NEUTRAL"
      -p "pwm_max:=$FCU_VRX_PWM_MAX"
      -p "max_thrust:=$FCU_VRX_MAX_THRUST"
      -p 'publish_sensors:=false'
      -p 'publish_cmd_vel:=false'
      -p 'twin_telemetry_role:=receiver'
      -p "twin_telemetry_udp_port:=$FCUVRX_TWIN_TELEMETRY_UDP_PORT"
      -p "twin_telemetry_topic:=$FCUVRX_TWIN_TELEMETRY_TOPIC"
      -p "twin_telemetry_world_frame:=$FCUVRX_WORLD"
      -p "twin_telemetry_stale_seconds:=$FCU_VRX_OBSERVER_STALE_SECONDS"
    )
  fi
}

fcuvrx_init_state() {
  local timestamp
  FCUVRX_CHILD_NAMES=()
  FCUVRX_CHILD_PIDS=()
  FCUVRX_CHILD_PGIDS=()
  FCUVRX_CHILD_INDEX=()
  FCUVRX_CLEANING=0
  FCUVRX_STARTED=0
  FCUVRX_READY_REACHED=0
  FCUVRX_OPERATOR_STOP_REQUESTED=0
  FCUVRX_SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d ' ')" \
    || fcuvrx_fail 'cannot determine supervisor process group'
  [[ "$FCUVRX_SUPERVISOR_PGID" =~ ^[1-9][0-9]*$ ]] \
    || fcuvrx_fail 'invalid supervisor process group'
  timestamp="$(date +%Y%m%d_%H%M%S)" \
    || fcuvrx_fail 'cannot create run timestamp'
  FCUVRX_RUN_DIR="$FCUVRX_LOG_ROOT/fcu_to_vrx_workstation_$timestamp"
  [ ! -e "$FCUVRX_RUN_DIR" ] \
    || fcuvrx_fail "run directory already exists: $FCUVRX_RUN_DIR"
  mkdir -m 700 "$FCUVRX_RUN_DIR"
  mkdir -m 700 "$FCUVRX_RUN_DIR/logs" "$FCUVRX_RUN_DIR/manifest" \
    "$FCUVRX_RUN_DIR/evidence"
  FCUVRX_SUPERVISOR_LOG="$FCUVRX_RUN_DIR/supervisor.log"
  : >"$FCUVRX_SUPERVISOR_LOG" \
    || fcuvrx_fail 'cannot create supervisor log'
}

fcuvrx_write_manifest() {
  {
    printf 'revision=%s\n' "$(git -C "$FCUVRX_REPO_ROOT" rev-parse HEAD)"
    printf 'origin_main=%s\n' \
      "$(git -C "$FCUVRX_REPO_ROOT" rev-parse refs/remotes/origin/main)"
    printf 'run_mode=%s\n' "$FCUVRX_RUN_MODE"
    printf 'ROS_DOMAIN_ID=%s\n' "$ROS_DOMAIN_ID"
    printf 'ROS_AUTOMATIC_DISCOVERY_RANGE=%s\n' \
      "$ROS_AUTOMATIC_DISCOVERY_RANGE"
    printf 'ROS_LOCALHOST_ONLY=%s\n' "$ROS_LOCALHOST_ONLY"
    printf 'udp_recv_port=%s\n' "$FCUVRX_UDP_RECV_PORT"
    printf 'world=%s\n' "$FCUVRX_WORLD"
    printf 'left_servo_channel=%s\n' "$FCU_VRX_LEFT_SERVO_CHANNEL"
    printf 'right_servo_channel=%s\n' "$FCU_VRX_RIGHT_SERVO_CHANNEL"
    printf 'left_pwm=%s/%s/%s\n' "$FCU_VRX_LEFT_PWM_MIN" \
      "$FCU_VRX_LEFT_PWM_NEUTRAL" "$FCU_VRX_LEFT_PWM_MAX"
    printf 'right_pwm=%s/%s/%s\n' "$FCU_VRX_RIGHT_PWM_MIN" \
      "$FCU_VRX_RIGHT_PWM_NEUTRAL" "$FCU_VRX_RIGHT_PWM_MAX"
    printf 'max_thrust=%s\n' "$FCU_VRX_MAX_THRUST"
    printf 'correlated_observation=%s\n' "$FCU_VRX_CORRELATED_OBSERVATION"
    printf 'observer_stale_seconds=%s\n' \
      "${FCU_VRX_OBSERVER_STALE_SECONDS:-0}"
    printf 'ready_timeout_seconds=%s\n' "$FCUVRX_READY_TIMEOUT_SECONDS"
    printf 'observer_ready_timeout_seconds=%s\n' \
      "$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS"
    printf 'publish_sensors=false\n'
    printf 'publish_cmd_vel=false\n'
    if fcuvrx_real_fcu_mode; then
      printf 'twin_telemetry_enabled=true\n'
      printf 'twin_telemetry_transport=udp-loopback-outbound-only\n'
      printf 'twin_telemetry_udp=127.0.0.1:%s\n' \
        "$FCUVRX_TWIN_TELEMETRY_UDP_PORT"
      printf 'twin_telemetry_topic=%s\n' "$FCUVRX_TWIN_TELEMETRY_TOPIC"
      printf 'twin_telemetry_schema=%s\n' "$FCUVRX_TWIN_TELEMETRY_SCHEMA"
      printf 'twin_telemetry_source=%s\n' "$FCUVRX_TWIN_TELEMETRY_SOURCE"
      printf 'twin_telemetry_stale_seconds=%s\n' \
        "$FCU_VRX_OBSERVER_STALE_SECONDS"
      printf 'relay_ROS_DOMAIN_ID=%s\n' "$FCUVRX_RELAY_DOMAIN_ID"
      printf 'relay_ROS_AUTOMATIC_DISCOVERY_RANGE=%s\n' \
        "$FCUVRX_RELAY_DISCOVERY_RANGE"
      printf 'relay_ROS_LOCALHOST_ONLY=%s\n' "$FCUVRX_RELAY_LOCALHOST_ONLY"
      printf 'relay_rc_out_topic=/mavros/rc/out\n'
      printf 'relay_udp_target=127.0.0.1:%s\n' "$FCUVRX_UDP_RECV_PORT"
    else
      printf 'twin_telemetry_enabled=false\n'
    fi
  } >"$FCUVRX_RUN_DIR/manifest/environment.txt"
  sha256sum "$FCUVRX_SCRIPT_DIR/fcu_to_vrx_workstation.sh" \
    "$FCUVRX_BRIDGE" "$FCUVRX_EVIDENCE" \
    "$FCUVRX_VRX_SHARE/config/wamv.yaml" \
    "$FCUVRX_VRX_SHARE/worlds/$FCUVRX_WORLD.sdf" \
    >"$FCUVRX_RUN_DIR/manifest/artifacts.sha256"
  {
    printf 'vrx'
    printf '\t%q' "${FCUVRX_VRX_COMMAND[@]}"
    printf '\nbridge'
    printf '\t%q' "${FCUVRX_BRIDGE_COMMAND[@]}"
    printf '\nobserver'
    printf '\t%q' "${FCUVRX_OBSERVER_COMMAND[@]}"
    if fcuvrx_real_fcu_mode; then
      printf '\nrelay'
      printf '\t%q' "${FCUVRX_RELAY_COMMAND[@]}"
    fi
    printf '\n'
  } >"$FCUVRX_RUN_DIR/manifest/commands.tsv"
}

fcuvrx_group_alive() {
  kill -0 -- "-$1" 2>/dev/null
}

fcuvrx_start_child() {
  local name="$1" logfile="$2" pid pgid index
  shift 2
  ( trap - INT QUIT; exec setsid "$@" ) >"$logfile" 2>&1 < /dev/null &
  pid=$!
  sleep 0.2 || true
  kill -0 "$pid" 2>/dev/null \
    || fcuvrx_fail "$name exited during startup; see $logfile"
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')" \
    || fcuvrx_fail "cannot determine $name process group"
  [[ "$pgid" =~ ^[1-9][0-9]*$ ]] \
    || fcuvrx_fail "invalid $name process group"
  [ "$pgid" = "$pid" ] \
    || fcuvrx_fail "$name process group is not led by its PID"
  [ "$pgid" != "$FCUVRX_SUPERVISOR_PGID" ] \
    || fcuvrx_fail "$name did not enter a separate process group"
  FCUVRX_CHILD_NAMES+=("$name")
  FCUVRX_CHILD_PIDS+=("$pid")
  FCUVRX_CHILD_PGIDS+=("$pgid")
  index=$((${#FCUVRX_CHILD_NAMES[@]} - 1))
  FCUVRX_CHILD_INDEX[$name]="$index"
  FCUVRX_STARTED=1
  fcuvrx_log "started $name pid=$pid pgid=$pgid log=$logfile"
}

fcuvrx_stop_child() {
  local name="$1" index pid pgid signal attempt
  [ -n "${FCUVRX_CHILD_INDEX[$name]+present}" ] || return 0
  index="${FCUVRX_CHILD_INDEX[$name]}"
  pid="${FCUVRX_CHILD_PIDS[$index]}"
  pgid="${FCUVRX_CHILD_PGIDS[$index]}"
  [ "$pgid" != "$FCUVRX_SUPERVISOR_PGID" ] \
    || { fcuvrx_log_error "refusing supervisor process group for $name"; return 1; }
  if fcuvrx_group_alive "$pgid"; then
    for signal in INT TERM KILL; do
      kill -"$signal" -- "-$pgid" 2>/dev/null || true
      for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        fcuvrx_group_alive "$pgid" || break 2
        sleep 0.1 || true
      done
    done
  fi
  wait "$pid" 2>/dev/null || true
  fcuvrx_group_alive "$pgid" && return 1
  fcuvrx_log "stopped $name"
}

fcuvrx_children_alive() {
  local index
  [ "${#FCUVRX_CHILD_NAMES[@]}" -gt 0 ] || return 1
  for index in "${!FCUVRX_CHILD_NAMES[@]}"; do
    kill -0 "${FCUVRX_CHILD_PIDS[$index]}" 2>/dev/null || return 1
    fcuvrx_group_alive "${FCUVRX_CHILD_PGIDS[$index]}" || return 1
  done
}

fcuvrx_topics_present() {
  local topics
  topics="$(ros2 topic list --no-daemon --spin-time 1)" || return 1
  grep -Fxq '/clock' <<<"$topics" \
    && grep -Fxq '/wamv/pose' <<<"$topics" \
    && grep -Fxq '/wamv/thrusters/left/thrust' <<<"$topics" \
    && grep -Fxq '/wamv/thrusters/right/thrust' <<<"$topics"
}

fcuvrx_wait_vrx_ready() {
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    fcuvrx_topics_present && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_bridge_ready() {
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS)) rc
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    if grep -Fq 'bridge up: recv udp:14555' \
        "$FCUVRX_RUN_DIR/logs/bridge.log"; then
      if fcuvrx_udp_listener_present; then
        return 0
      else
        rc=$?
        [ "$rc" -eq 1 ] || return 1
      fi
    fi
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_relay_ready() {
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS))
  local marker
  marker="FCU_TO_VRX_RC_OUT_RELAY_READY=PASS topic=/mavros/rc/out udp=127.0.0.1:$FCUVRX_UDP_RECV_PORT left=SERVO$FCU_VRX_LEFT_SERVO_CHANNEL right=SERVO$FCU_VRX_RIGHT_SERVO_CHANNEL pwm=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX"
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    grep -Fq "$marker" "$FCUVRX_RUN_DIR/logs/relay.log" && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_twin_telemetry_ready() {
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS))
  local marker
  marker="FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS topic=$FCUVRX_TWIN_TELEMETRY_TOPIC udp=127.0.0.1:$FCUVRX_TWIN_TELEMETRY_UDP_PORT schema=$FCUVRX_TWIN_TELEMETRY_SCHEMA source=$FCUVRX_TWIN_TELEMETRY_SOURCE stale_seconds=$FCU_VRX_OBSERVER_STALE_SECONDS"
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    grep -Fq "$marker" "$FCUVRX_RUN_DIR/logs/relay.log" && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_observer_started() {
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    grep -Fq 'FCU_TO_VRX_VRX_OBSERVER_STARTED=PASS topics=4 publishers=0' \
      "$FCUVRX_RUN_DIR/logs/observer.log" && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_pose_baseline() {
  # Pre-Pi gate. VRX publishes pose without the Pi, so a world-frame mismatch
  # is provable here rather than after the operator has started the boat.
  # Returns 2 for a named frame mismatch, 1 for a plain timeout.
  local deadline=$((SECONDS + FCUVRX_READY_TIMEOUT_SECONDS))
  local events="$FCUVRX_RUN_DIR/evidence/vrx_events.jsonl"
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    if grep -Fq '"kind":"pose_frame_mismatch"' "$events" 2>/dev/null; then
      return 2
    fi
    grep -Fq '"kind":"pose"' "$events" 2>/dev/null && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_wait_observer_ready() {
  # Post-Pi gate. servo_output_raw and both thrust streams originate from the
  # Pi fanout or the explicit real-FCU RCOut relay, so the observer itself must
  # prove that all four streams are present before workstation readiness.
  local deadline=$((SECONDS + FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    fcuvrx_children_alive || return 1
    grep -Fq 'FCU_TO_VRX_VRX_OBSERVER_READY=PASS topics=4' \
      "$FCUVRX_RUN_DIR/logs/observer.log" && return 0
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  return 1
}

fcuvrx_cleanup() {
  local incoming_rc="${1-$?}" cleanup_rc=0 final_rc operator_success=0 rc
  local teardown_order='bridge,observer,vrx'
  local teardown_ports='udp=14555-free'
  [ "$FCUVRX_CLEANING" -eq 0 ] || return "$incoming_rc"
  FCUVRX_CLEANING=1
  trap - EXIT INT TERM
  set +e
  if fcuvrx_real_fcu_mode; then
    fcuvrx_stop_child relay || cleanup_rc=1
    teardown_order='relay,bridge,observer,vrx'
    teardown_ports='udp=14555-free twin_telemetry_udp=14556-free'
  fi
  fcuvrx_stop_child bridge || cleanup_rc=1
  fcuvrx_stop_child observer || cleanup_rc=1
  fcuvrx_stop_child vrx || cleanup_rc=1
  if [ "$FCUVRX_STARTED" -eq 1 ]; then
    if fcuvrx_udp_listener_present; then
      fcuvrx_log_error "UDP $FCUVRX_UDP_RECV_PORT remains in use after teardown"
      cleanup_rc=1
    else
      rc=$?
      [ "$rc" -eq 1 ] || cleanup_rc=1
    fi
    if fcuvrx_real_fcu_mode; then
      if fcuvrx_twin_telemetry_listener_present; then
        fcuvrx_log_error \
          "UDP $FCUVRX_TWIN_TELEMETRY_UDP_PORT remains in use after teardown"
        cleanup_rc=1
      else
        rc=$?
        [ "$rc" -eq 1 ] || cleanup_rc=1
      fi
    fi
  fi
  if [ "$incoming_rc" -eq 130 ] \
      && [ "$FCUVRX_OPERATOR_STOP_REQUESTED" -eq 1 ] \
      && [ "$FCUVRX_READY_REACHED" -eq 1 ] \
      && [ "$cleanup_rc" -eq 0 ]; then
    fcuvrx_log \
      "FCU_TO_VRX_WORKSTATION_TEARDOWN=PASS order=$teardown_order $teardown_ports"
    operator_success=1
  fi
  final_rc="$incoming_rc"
  if [ "$operator_success" -eq 1 ]; then
    final_rc=0
  elif [ "$final_rc" -eq 0 ]; then
    final_rc="$cleanup_rc"
  fi
  [ -z "$FCUVRX_RUN_DIR" ] \
    || fcuvrx_log "FCU_TO_VRX_WORKSTATION_LOGS=$FCUVRX_RUN_DIR"
  fcuvrx_log "FCU_TO_VRX_WORKSTATION_EXIT status=$final_rc cleanup_rc=$cleanup_rc"
  exit "$final_rc"
}

fcuvrx_on_interrupt() {
  FCUVRX_OPERATOR_STOP_REQUESTED=1
  fcuvrx_log 'operator stop requested'
  exit 130
}

fcuvrx_on_term() {
  fcuvrx_log_error 'termination requested'
  exit 143
}

fcuvrx_check() {
  bash -n "$FCUVRX_SCRIPT_DIR/fcu_to_vrx_workstation.sh"
  bash "$FCUVRX_SCRIPT_DIR/test_fcu_to_vrx_workstation.sh"
  python3 -m unittest "$FCUVRX_SCRIPT_DIR/test_servo_command_bridge_mapping.py"
  python3 -m unittest "$FCUVRX_SCRIPT_DIR/test_fcu_to_vrx_parameter_contract.py"
  python3 -m unittest "$FCUVRX_SCRIPT_DIR/test_fcu_to_vrx_evidence.py"
  fcuvrx_log \
    'FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=32 python_tests=48 runtime=not-started'
}

fcuvrx_run() {
  local fcuvrx_pose_rc=0
  fcuvrx_static_preflight
  fcuvrx_init_state
  fcuvrx_build_commands
  fcuvrx_write_manifest
  trap fcuvrx_cleanup EXIT
  trap fcuvrx_on_interrupt INT
  trap fcuvrx_on_term TERM
  fcuvrx_log \
    "FCU_TO_VRX_WORKSTATION_START domain=77 discovery=LOCALHOST world=$FCUVRX_WORLD udp=14555 run_dir=$FCUVRX_RUN_DIR"

  fcuvrx_start_child vrx "$FCUVRX_RUN_DIR/logs/vrx.log" \
    "${FCUVRX_VRX_COMMAND[@]}"
  fcuvrx_wait_vrx_ready \
    || fcuvrx_fail 'VRX topics did not become ready before the deadline'
  fcuvrx_log \
    'FCU_TO_VRX_VRX_READY=PASS topics=/clock,/wamv/pose,/wamv/thrusters/left/thrust,/wamv/thrusters/right/thrust'

  fcuvrx_start_child observer "$FCUVRX_RUN_DIR/logs/observer.log" \
    "${FCUVRX_OBSERVER_COMMAND[@]}"
  fcuvrx_wait_observer_started \
    || fcuvrx_fail 'VRX evidence observer did not start before the deadline'
  fcuvrx_log \
    "FCU_TO_VRX_OBSERVER_STARTED=PASS mode=$([ "$FCU_VRX_CORRELATED_OBSERVATION" -eq 1 ] && printf fail-closed || printf record-only) status=$FCUVRX_RUN_DIR/evidence/vrx_status.json"

  fcuvrx_pose_rc=0
  fcuvrx_wait_pose_baseline || fcuvrx_pose_rc=$?
  case "$fcuvrx_pose_rc" in
    0) ;;
    2)
      fcuvrx_fail "no VRX pose transform has parent '$FCUVRX_WORLD'; either the world name is wrong or publish_model_pose is disabled in the WAM-V model (one_click_launch_all/patch_vrx.sh). Observed parents are listed in $FCUVRX_RUN_DIR/evidence/vrx_events.jsonl"
      ;;
    *)
      fcuvrx_fail 'no VRX pose baseline arrived before the deadline'
      ;;
  esac
  fcuvrx_log \
    "FCU_TO_VRX_POSE_BASELINE=PASS topic=/wamv/pose world_frame=$FCUVRX_WORLD"

  fcuvrx_start_child bridge "$FCUVRX_RUN_DIR/logs/bridge.log" \
    "${FCUVRX_BRIDGE_COMMAND[@]}"
  fcuvrx_wait_bridge_ready \
    || fcuvrx_fail 'bridge UDP listener did not become ready before the deadline'
  if fcuvrx_real_fcu_mode; then
    fcuvrx_start_child relay "$FCUVRX_RUN_DIR/logs/relay.log" \
      "${FCUVRX_RELAY_COMMAND[@]}"
    fcuvrx_log \
      "FCU_TO_VRX_WORKSTATION_PRESTART=PASS mode=run-real-fcu domain=77 udp=14555-listening world=$FCUVRX_WORLD mapping=$FCU_VRX_LEFT_SERVO_CHANNEL/$FCU_VRX_RIGHT_SERVO_CHANNEL rails=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX observer=started pose=baseline relay=started relay_domain=43 relay_discovery=SUBNET twin_telemetry=started twin_telemetry_udp=127.0.0.1:$FCUVRX_TWIN_TELEMETRY_UDP_PORT twin_telemetry_topic=$FCUVRX_TWIN_TELEMETRY_TOPIC ready_timeout_seconds=$FCUVRX_READY_TIMEOUT_SECONDS observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS publish_sensors=false publish_cmd_vel=false"
    fcuvrx_log 'start the approved real-FCU Pi helper now; this terminal waits for relayed RCOut, outbound twin telemetry and four-stream observer READY before declaring workstation readiness'
    fcuvrx_wait_relay_ready \
      || fcuvrx_fail 'real-FCU RCOut relay did not become ready before the deadline'
    fcuvrx_log \
      "FCU_TO_VRX_RC_OUT_RELAY_READY=PASS topic=/mavros/rc/out udp=127.0.0.1:$FCUVRX_UDP_RECV_PORT left=SERVO$FCU_VRX_LEFT_SERVO_CHANNEL right=SERVO$FCU_VRX_RIGHT_SERVO_CHANNEL pwm=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX"
    fcuvrx_wait_twin_telemetry_ready \
      || fcuvrx_fail 'outbound twin telemetry did not become ready before the deadline'
    fcuvrx_log \
      "FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS topic=$FCUVRX_TWIN_TELEMETRY_TOPIC udp=127.0.0.1:$FCUVRX_TWIN_TELEMETRY_UDP_PORT schema=$FCUVRX_TWIN_TELEMETRY_SCHEMA source=$FCUVRX_TWIN_TELEMETRY_SOURCE stale_seconds=$FCU_VRX_OBSERVER_STALE_SECONDS"
  else
    fcuvrx_log \
      "FCU_TO_VRX_WORKSTATION_PRESTART=PASS domain=77 udp=14555-listening world=$FCUVRX_WORLD mapping=$FCU_VRX_LEFT_SERVO_CHANNEL/$FCU_VRX_RIGHT_SERVO_CHANNEL rails=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX observer=started pose=baseline ready_timeout_seconds=$FCUVRX_READY_TIMEOUT_SECONDS observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS publish_sensors=false publish_cmd_vel=false"
    fcuvrx_log 'start the Pi helper now; this terminal waits for the four-stream observer READY before declaring workstation readiness'
  fi

  fcuvrx_wait_observer_ready \
    || fcuvrx_fail "VRX observer did not reach four-stream READY within observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS"
  FCUVRX_READY_REACHED=1
  if fcuvrx_real_fcu_mode; then
    fcuvrx_log \
      "FCU_TO_VRX_WORKSTATION_READY=PASS mode=run-real-fcu domain=77 udp=14555 world=$FCUVRX_WORLD mapping=$FCU_VRX_LEFT_SERVO_CHANNEL/$FCU_VRX_RIGHT_SERVO_CHANNEL rails=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX observer=ready streams=4 relay=ready relay_domain=43 relay_discovery=SUBNET twin_telemetry=ready twin_telemetry_topic=$FCUVRX_TWIN_TELEMETRY_TOPIC twin_telemetry_stale_seconds=$FCU_VRX_OBSERVER_STALE_SECONDS observer_stale_seconds=${FCU_VRX_OBSERVER_STALE_SECONDS:-0} observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS publish_sensors=false publish_cmd_vel=false"
  else
    fcuvrx_log \
      "FCU_TO_VRX_WORKSTATION_READY=PASS domain=77 udp=14555 world=$FCUVRX_WORLD mapping=$FCU_VRX_LEFT_SERVO_CHANNEL/$FCU_VRX_RIGHT_SERVO_CHANNEL rails=$FCU_VRX_PWM_MIN/$FCU_VRX_PWM_NEUTRAL/$FCU_VRX_PWM_MAX observer=ready streams=4 observer_stale_seconds=${FCU_VRX_OBSERVER_STALE_SECONDS:-0} observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS publish_sensors=false publish_cmd_vel=false"
  fi
  if fcuvrx_real_fcu_mode; then
    fcuvrx_log 'planned stop: externally disarm first; stop W2 here; initiate the real-FCU Pi stop/closeout; then stop W1 so its stop marker lets the Pi finish'
  elif [ "$FCU_VRX_CORRELATED_OBSERVATION" -eq 1 ]; then
    fcuvrx_log 'no arming before this line; planned stop: after PI_SOURCE_HOLD=ACTIVE, press Ctrl+C here before stopping W1 and the Pi helper'
  else
    fcuvrx_log 'no arming before this line; planned stop: stop the Pi helper first, then press Ctrl+C here'
  fi

  while fcuvrx_children_alive; do
    sleep "$FCUVRX_POLL_SECONDS" || true
  done
  fcuvrx_fail 'a VRX/bridge child exited unexpectedly'
}

fcuvrx_main() {
  case "$#:${1:-}" in
    1:check) fcuvrx_check ;;
    1:run)
      FCUVRX_RUN_MODE=run
      fcuvrx_run
      ;;
    1:run-real-fcu)
      FCUVRX_RUN_MODE=run-real-fcu
      fcuvrx_run
      ;;
    *) fcuvrx_usage ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  fcuvrx_main "$@"
fi
