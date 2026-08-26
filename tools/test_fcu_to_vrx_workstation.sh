#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUPERVISOR="${1:-$SCRIPT_DIR/fcu_to_vrx_workstation.sh}"
CASE_COUNT=0

fail_test() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass_case() {
  CASE_COUNT=$((CASE_COUNT + 1))
}

require_text() {
  local text="$1" literal="$2" message="$3"
  grep -Fq -- "$literal" <<<"$text" || fail_test "$message"
}

[ -r "$SUPERVISOR" ] \
  || fail_test "FCU-to-VRX workstation supervisor missing: $SUPERVISOR"
bash -n "$SUPERVISOR"
pass_case

FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT
ROS_SETUP_FIXTURE="$FIXTURE_ROOT/ros_setup.bash"
: >"$ROS_SETUP_FIXTURE"

ROS_ENV_OUTPUT="$(bash -c '
  source "$1"
  FCUVRX_ROS_SETUP="$2"
  FCUVRX_WORKSPACE_SETUP="$2"
  ROS_DOMAIN_ID=12
  ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
  ROS_LOCALHOST_ONLY=0
  ROS_STATIC_PEERS=192.0.2.1
  ROS_DISCOVERY_SERVER=192.0.2.2:11811
  RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
  CYCLONEDDS_URI=/tmp/cyclonedds.xml
  fcuvrx_configure_ros_environment
  printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
    "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY" \
    "${ROS_STATIC_PEERS-unset}" "${ROS_DISCOVERY_SERVER-unset}" \
    "${RMW_IMPLEMENTATION-unset}" "${FASTDDS_DEFAULT_PROFILES_FILE-unset}" \
    "${FASTRTPS_DEFAULT_PROFILES_FILE-unset}" "${CYCLONEDDS_URI-unset}"
' _ "$SUPERVISOR" "$ROS_SETUP_FIXTURE")"
[ "$ROS_ENV_OUTPUT" = '77|LOCALHOST|1|unset|unset|unset|unset|unset|unset' ] \
  || fail_test "domain-77 ROS isolation changed: $ROS_ENV_OUTPUT"
pass_case

EMPTY_DOMAIN_OUTPUT="$(bash -c '
  source "$1"
  ros2() { return 0; }
  fcuvrx_reject_domain_nodes
  printf "domain-empty\n"
' _ "$SUPERVISOR")"
[ "$EMPTY_DOMAIN_OUTPUT" = 'domain-empty' ] \
  || fail_test "an empty domain 77 was rejected: $EMPTY_DOMAIN_OUTPUT"
set +e
OCCUPIED_DOMAIN_OUTPUT="$(bash -c '
  source "$1"
  ros2() { printf "/unexpected_node\n"; }
  fcuvrx_reject_domain_nodes
' _ "$SUPERVISOR" 2>&1)"
OCCUPIED_DOMAIN_RC=$?
set -e
[ "$OCCUPIED_DOMAIN_RC" -ne 0 ] \
  || fail_test 'an occupied domain 77 was accepted'
require_text "$OCCUPIED_DOMAIN_OUTPUT" 'ROS domain 77 is not empty' \
  'occupied-domain failure does not identify the isolation breach'
pass_case

set +e
MISSING_OUTPUT="$(bash -c '
  source "$1"
  fcuvrx_validate_configuration
' _ "$SUPERVISOR" 2>&1)"
MISSING_RC=$?
set -e
[ "$MISSING_RC" -ne 0 ] \
  || fail_test 'missing live-read configuration was accepted'
require_text "$MISSING_OUTPUT" 'FCU_VRX_LEFT_SERVO_CHANNEL is required' \
  'missing configuration failure does not identify the first required value'
pass_case

VALID_ENV=(
  FCU_VRX_LEFT_SERVO_CHANNEL=3
  FCU_VRX_RIGHT_SERVO_CHANNEL=1
  FCU_VRX_LEFT_PWM_MIN=800
  FCU_VRX_LEFT_PWM_NEUTRAL=800
  FCU_VRX_LEFT_PWM_MAX=2200
  FCU_VRX_RIGHT_PWM_MIN=800
  FCU_VRX_RIGHT_PWM_NEUTRAL=800
  FCU_VRX_RIGHT_PWM_MAX=2200
  FCU_VRX_MAX_THRUST=800.0
)

VALID_OUTPUT="$(env "${VALID_ENV[@]}" bash -c '
  source "$1"
  fcuvrx_validate_configuration
  printf "%s/%s %s/%s/%s %s\n" \
    "$FCU_VRX_LEFT_SERVO_CHANNEL" "$FCU_VRX_RIGHT_SERVO_CHANNEL" \
    "$FCU_VRX_PWM_MIN" "$FCU_VRX_PWM_NEUTRAL" "$FCU_VRX_PWM_MAX" \
    "$FCU_VRX_MAX_THRUST"
' _ "$SUPERVISOR")"
[ "$VALID_OUTPUT" = '3/1 800/800/2200 800.0' ] \
  || fail_test "valid bottom-neutral configuration changed: $VALID_OUTPUT"
pass_case

for invalid_case in \
  'FCU_VRX_LEFT_SERVO_CHANNEL=0:must be an integer in 1..16' \
  'FCU_VRX_RIGHT_SERVO_CHANNEL=3:must be distinct' \
  'FCU_VRX_LEFT_PWM_NEUTRAL=799:must satisfy min <= neutral < max' \
  'FCU_VRX_RIGHT_PWM_MAX=2199:left and right PWM rails must match' \
  'FCU_VRX_MAX_THRUST=zero:must be a finite decimal greater than zero'; do
  assignment="${invalid_case%%:*}"
  expected="${invalid_case#*:}"
  set +e
  INVALID_OUTPUT="$(env "${VALID_ENV[@]}" "$assignment" bash -c '
    source "$1"
    fcuvrx_validate_configuration
  ' _ "$SUPERVISOR" 2>&1)"
  INVALID_RC=$?
  set -e
  [ "$INVALID_RC" -ne 0 ] \
    || fail_test "invalid configuration was accepted: $assignment"
  require_text "$INVALID_OUTPUT" "$expected" \
    "invalid configuration did not report its contract: $assignment"
done
pass_case

COMMAND_OUTPUT="$(env "${VALID_ENV[@]}" bash -c '
  source "$1"
  fcuvrx_validate_configuration
  fcuvrx_build_commands
  printf "VRX"
  printf "\t%q" "${FCUVRX_VRX_COMMAND[@]}"
  printf "\nBRIDGE"
  printf "\t%q" "${FCUVRX_BRIDGE_COMMAND[@]}"
  printf "\n"
' _ "$SUPERVISOR")"
for literal in \
  'ros2' 'launch' 'vrx_gz' 'competition.launch.py' \
  'world:=sydney_regatta' 'sim_mode:=full' \
  'servo_command_bridge.py' 'udp_recv_port:=14555' \
  'left_servo_channel:=3' 'right_servo_channel:=1' \
  'pwm_min:=800' 'pwm_neutral:=800' 'pwm_max:=2200' \
  'max_thrust:=800.0' 'publish_sensors:=false' \
  'publish_cmd_vel:=false'; do
  require_text "$COMMAND_OUTPUT" "$literal" \
    "built command is missing: $literal"
done
for forbidden in ttyAMA0 mavros MAVProxy sim_vehicle.py ardupilot; do
  ! grep -Fq -- "$forbidden" <<<"$COMMAND_OUTPUT" \
    || fail_test "built command unexpectedly owns $forbidden"
done
pass_case

CONFLICT_OUTPUT="$(bash -c '
  source "$1"
  printf "%s\n" "${FCUVRX_CONFLICT_PATTERNS[@]}"
' _ "$SUPERVISOR")"
for required in 'servo_command_bridge.py' 'gz sim' gazebo mavros_node \
  sim_vehicle.py mavproxy.py; do
  require_text "$CONFLICT_OUTPUT" "$required" \
    "conflict guard is missing: $required"
done
for allowed in rosbridge serve_dashboard.py; do
  ! grep -Fxq -- "$allowed" <<<"$CONFLICT_OUTPUT" \
    || fail_test "Piece 1 incorrectly rejects concurrent $allowed"
done
pass_case

FAKE_CHILD="$FIXTURE_ROOT/fake_child.sh"
cat >"$FAKE_CHILD" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name="$1"
trace="$2"
trap 'printf "%s\n" "$name" >>"$trace"; exit 0' INT TERM
printf '%s-ready\n' "$name" >>"$trace"
while :; do
  sleep 0.1
done
EOF
chmod 700 "$FAKE_CHILD"

LIFECYCLE_ROOT="$FIXTURE_ROOT/lifecycle"
mkdir -p "$LIFECYCLE_ROOT/logs"
set +e
LIFECYCLE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  FCUVRX_RUN_DIR="$2"
  FCUVRX_SUPERVISOR_LOG="$2/supervisor.log"
  FCUVRX_SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d " ")"
  FCUVRX_CHILD_NAMES=()
  FCUVRX_CHILD_PIDS=()
  FCUVRX_CHILD_PGIDS=()
  FCUVRX_CHILD_INDEX=()
  fcuvrx_udp_listener_present() { return 1; }
  fcuvrx_start_child vrx "$2/logs/vrx.log" "$3" vrx "$2/trace"
  fcuvrx_start_child bridge "$2/logs/bridge.log" "$3" bridge "$2/trace"
  FCUVRX_READY_REACHED=1
  FCUVRX_OPERATOR_STOP_REQUESTED=1
  fcuvrx_cleanup 130
' _ "$SUPERVISOR" "$LIFECYCLE_ROOT" "$FAKE_CHILD" 2>&1)"
LIFECYCLE_RC=$?
set -e
[ "$LIFECYCLE_RC" -eq 0 ] \
  || fail_test "ordered lifecycle fixture failed rc=$LIFECYCLE_RC: $LIFECYCLE_OUTPUT"
require_text "$LIFECYCLE_OUTPUT" \
  'FCU_TO_VRX_WORKSTATION_TEARDOWN=PASS order=bridge,vrx udp=14555-free' \
  'successful lifecycle did not emit the teardown proof'
[ "$(tail -n 2 "$LIFECYCLE_ROOT/trace")" = $'bridge\nvrx' ] \
  || fail_test 'children did not stop in bridge-then-VRX order'
pass_case

FAILURE_ROOT="$FIXTURE_ROOT/failure"
mkdir -p "$FAILURE_ROOT/logs"
FAILURE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  FCUVRX_RUN_DIR="$2"
  FCUVRX_SUPERVISOR_LOG="$2/supervisor.log"
  FCUVRX_SUPERVISOR_PGID="$(ps -o pgid= -p $$ | tr -d " ")"
  FCUVRX_CHILD_NAMES=()
  FCUVRX_CHILD_PIDS=()
  FCUVRX_CHILD_PGIDS=()
  FCUVRX_CHILD_INDEX=()
  fcuvrx_start_child bridge "$2/logs/bridge.log" "$3" bridge "$2/trace"
  fcuvrx_stop_child bridge
  if fcuvrx_children_alive; then
    printf "unexpected-alive\n"
    exit 1
  fi
  printf "unexpected-exit-detected\n"
' _ "$SUPERVISOR" "$FAILURE_ROOT" "$FAKE_CHILD")"
require_text "$FAILURE_OUTPUT" 'unexpected-exit-detected' \
  'a stopped child was not detected as unavailable'
pass_case

STUCK_UDP_ROOT="$FIXTURE_ROOT/stuck_udp"
mkdir -p "$STUCK_UDP_ROOT"
set +e
STUCK_UDP_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  FCUVRX_RUN_DIR="$2"
  FCUVRX_SUPERVISOR_LOG="$2/supervisor.log"
  FCUVRX_STARTED=1
  FCUVRX_CHILD_NAMES=()
  FCUVRX_CHILD_PIDS=()
  FCUVRX_CHILD_PGIDS=()
  FCUVRX_CHILD_INDEX=()
  fcuvrx_udp_listener_present() { return 0; }
  fcuvrx_cleanup 0
' _ "$SUPERVISOR" "$STUCK_UDP_ROOT" 2>&1)"
STUCK_UDP_RC=$?
set -e
[ "$STUCK_UDP_RC" -eq 1 ] \
  || fail_test "occupied teardown port returned $STUCK_UDP_RC instead of 1"
require_text "$STUCK_UDP_OUTPUT" 'UDP 14555 remains in use after teardown' \
  'occupied teardown port was not reported'
! grep -Fq 'FCU_TO_VRX_WORKSTATION_TEARDOWN=PASS' <<<"$STUCK_UDP_OUTPUT" \
  || fail_test 'occupied teardown port incorrectly produced a PASS marker'
pass_case

USAGE_OUTPUT=''
set +e
USAGE_OUTPUT="$(bash "$SUPERVISOR" 2>&1)"
USAGE_RC=$?
set -e
[ "$USAGE_RC" -eq 2 ] || fail_test "usage returned $USAGE_RC instead of 2"
require_text "$USAGE_OUTPUT" 'check|run' 'usage does not expose check and run'
pass_case

printf 'FCU-to-VRX workstation supervisor tests: PASS cases=%d runtime=not-started\n' \
  "$CASE_COUNT"
