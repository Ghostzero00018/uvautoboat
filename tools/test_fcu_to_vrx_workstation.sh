#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUPERVISOR="${1:-$SCRIPT_DIR/fcu_to_vrx_workstation.sh}"
EVIDENCE="$SCRIPT_DIR/fcu_to_vrx_evidence.py"
WIKI="$SCRIPT_DIR/../wiki/Live_Hailo_MAVLink_Dashboard_Testing.md"
CASE_COUNT=0

fail_test() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass_case() {
  CASE_COUNT=$((CASE_COUNT + 1))
}

extract_function() {
  local name="$1"
  awk -v start="${name}() {" '
    $0 == start { capture = 1 }
    capture { print }
    capture && $0 == "}" { exit }
  ' "$SUPERVISOR"
}

require_text() {
  local text="$1" literal="$2" message="$3"
  grep -Fq -- "$literal" <<<"$text" || fail_test "$message"
}

[ -r "$SUPERVISOR" ] \
  || fail_test "FCU-to-VRX workstation supervisor missing: $SUPERVISOR"
[ -r "$EVIDENCE" ] || fail_test "FCU-to-VRX evidence recorder missing: $EVIDENCE"
[ -r "$WIKI" ] || fail_test "live-dashboard runbook missing: $WIKI"
bash -n "$SUPERVISOR"
pass_case

SUPERVISOR_SHA256="$(sha256sum "$SUPERVISOR" | awk '{print $1}')"
EVIDENCE_SHA256="$(sha256sum "$EVIDENCE" | awk '{print $1}')"
grep -Fqx -- "| VRX supervisor SHA-256 | \`$SUPERVISOR_SHA256\` |" "$WIKI" \
  || fail_test 'live-dashboard runbook VRX supervisor checksum is stale'
grep -Fqx -- "| Correlation recorder SHA-256 | \`$EVIDENCE_SHA256\` |" "$WIKI" \
  || fail_test 'live-dashboard runbook correlation recorder checksum is stale'
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

set +e
MISSING_OBSERVER_STALE_OUTPUT="$(env "${VALID_ENV[@]}" \
  FCU_VRX_CORRELATED_OBSERVATION=1 bash -c '
    source "$1"
    fcuvrx_validate_configuration
  ' _ "$SUPERVISOR" 2>&1)"
MISSING_OBSERVER_STALE_RC=$?
set -e
[ "$MISSING_OBSERVER_STALE_RC" -ne 0 ] \
  || fail_test 'Block E observer accepted a missing staleness limit'
require_text "$MISSING_OBSERVER_STALE_OUTPUT" \
  'FCU_VRX_OBSERVER_STALE_SECONDS is required' \
  'missing Block E observer staleness limit was not identified'
CORRELATED_OUTPUT="$(env "${VALID_ENV[@]}" \
  FCU_VRX_CORRELATED_OBSERVATION=1 FCU_VRX_OBSERVER_STALE_SECONDS=7 \
  bash -c '
    source "$1"
    fcuvrx_validate_configuration
    printf "correlated=%s stale=%s\n" \
      "$FCU_VRX_CORRELATED_OBSERVATION" "$FCU_VRX_OBSERVER_STALE_SECONDS"
  ' _ "$SUPERVISOR")"
[ "$CORRELATED_OUTPUT" = 'correlated=1 stale=7' ] \
  || fail_test "valid Block E observer configuration changed: $CORRELATED_OUTPUT"
pass_case

COMMAND_OUTPUT="$(env "${VALID_ENV[@]}" bash -c '
  source "$1"
  fcuvrx_validate_configuration
  fcuvrx_build_commands
  printf "VRX"
  printf "\t%q" "${FCUVRX_VRX_COMMAND[@]}"
  printf "\nBRIDGE"
  printf "\t%q" "${FCUVRX_BRIDGE_COMMAND[@]}"
  printf "\nOBSERVER"
  printf "\t%q" "${FCUVRX_OBSERVER_COMMAND[@]}"
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
for literal in \
  'fcu_to_vrx_evidence.py' 'observe-vrx' \
  '--servo-topic' '/fcu_to_vrx/servo_output_raw' \
  '--pose-topic' '/wamv/pose'; do
  require_text "$COMMAND_OUTPUT" "$literal" \
    "built observer command is missing: $literal"
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
  fcuvrx_start_child observer "$2/logs/observer.log" "$3" observer "$2/trace"
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
  'FCU_TO_VRX_WORKSTATION_TEARDOWN=PASS order=bridge,observer,vrx udp=14555-free' \
  'successful lifecycle did not emit the teardown proof'
[ "$(tail -n 3 "$LIFECYCLE_ROOT/trace")" = $'bridge\nobserver\nvrx' ] \
  || fail_test 'children did not stop in bridge-observer-VRX order'
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

# --- two-stage readiness and world-frame pose selection -------------------

SUPERVISOR_SOURCE="$(cat "$SUPERVISOR")"
require_text "$SUPERVISOR_SOURCE" '--world-frame "$FCUVRX_WORLD"' \
  'the observer command does not pass the launched world as the pose parent frame'
require_text "$(extract_function fcuvrx_topics_present)" '/wamv/pose' \
  'the pre-Pi VRX topic gate does not require the pose topic'
# Every wait tunable is validated before anything starts, so a bad override
# cannot kill the supervisor mid-run.
PREFLIGHT_BODY="$(extract_function fcuvrx_static_preflight)"
for timeout_name in FCU_TO_VRX_READY_TIMEOUT_SECONDS FCU_TO_VRX_POLL_SECONDS \
  FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS; do
  require_text "$PREFLIGHT_BODY" "$timeout_name" \
    "static preflight does not validate $timeout_name"
done
pass_case

set +e
BAD_TIMEOUT_OUTPUT="$(env "${VALID_ENV[@]}" \
  FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS=0 bash -c '
    source "$1"
    fcuvrx_validate_positive_integer FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS \
      "$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS"
  ' _ "$SUPERVISOR" 2>&1)"
BAD_TIMEOUT_RC=$?
set -e
[ "$BAD_TIMEOUT_RC" -ne 0 ] \
  || fail_test 'a non-positive observer-ready timeout was accepted'
require_text "$BAD_TIMEOUT_OUTPUT" \
  'FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS must be a positive integer' \
  'the rejected observer-ready timeout did not report its contract'
pass_case

# Every wait budget that governs acceptance must be recoverable from the
# retained run, so a later adjudicator can prove which value applied.
MANIFEST_BODY="$(extract_function fcuvrx_write_manifest)"
for manifest_key in 'ready_timeout_seconds=' 'observer_ready_timeout_seconds=' \
  'observer_stale_seconds=' 'correlated_observation='; do
  require_text "$MANIFEST_BODY" "$manifest_key" \
    "the run manifest does not record $manifest_key"
done
RUN_BODY_TIMEOUTS="$(extract_function fcuvrx_run)"
require_text "$RUN_BODY_TIMEOUTS" \
  'observer_ready_timeout_seconds=$FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS' \
  'the readiness markers do not record the observer-ready timeout'
require_text "$(extract_function fcuvrx_run)" \
  'observer_stale_seconds=${FCU_VRX_OBSERVER_STALE_SECONDS:-0}' \
  'the final READY marker does not record the staleness limit that governed it'
pass_case

# The pre-Pi gate must be provable without the Pi, and the post-Pi gate must
# require the observer's own four-stream READY marker, not its STARTED marker.
POSE_ROOT="$FIXTURE_ROOT/pose_gate"
mkdir -p "$POSE_ROOT/evidence" "$POSE_ROOT/logs"
: >"$POSE_ROOT/evidence/vrx_events.jsonl"

pose_gate() {
  bash -c '
    set -uo pipefail
    source "$1"
    set +e
    FCUVRX_RUN_DIR="$2"
    FCUVRX_READY_TIMEOUT_SECONDS=1
    FCUVRX_POLL_SECONDS=1
    fcuvrx_children_alive() { return 0; }
    fcuvrx_wait_pose_baseline
    printf "rc=%s\n" "$?"
  ' _ "$SUPERVISOR" "$POSE_ROOT" 2>&1
}

require_text "$(pose_gate)" 'rc=1' \
  'an empty evidence stream did not time out the pose baseline gate'
pass_case

printf '{"kind":"pose_frame_mismatch","expected_frame":"sydney_regatta"}\n' \
  >"$POSE_ROOT/evidence/vrx_events.jsonl"
require_text "$(pose_gate)" 'rc=2' \
  'a recorded world-frame mismatch was not reported distinctly'
pass_case

printf '{"kind":"pose","x":1.0}\n' >"$POSE_ROOT/evidence/vrx_events.jsonl"
require_text "$(pose_gate)" 'rc=0' \
  'a recorded pose baseline did not satisfy the pre-Pi gate'
pass_case

READY_ROOT="$FIXTURE_ROOT/observer_ready"
mkdir -p "$READY_ROOT/logs"

observer_ready_gate() {
  bash -c '
    set -uo pipefail
    source "$1"
    set +e
    FCUVRX_RUN_DIR="$2"
    FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS=1
    FCUVRX_POLL_SECONDS=1
    fcuvrx_children_alive() { return 0; }
    fcuvrx_wait_observer_ready
    printf "rc=%s\n" "$?"
  ' _ "$SUPERVISOR" "$READY_ROOT" 2>&1
}

printf 'FCU_TO_VRX_VRX_OBSERVER_STARTED=PASS topics=4 publishers=0\n' \
  >"$READY_ROOT/logs/observer.log"
require_text "$(observer_ready_gate)" 'rc=1' \
  'the STARTED marker alone incorrectly satisfied the observer READY gate'
pass_case

printf 'FCU_TO_VRX_VRX_OBSERVER_READY=PASS topics=4\n' \
  >>"$READY_ROOT/logs/observer.log"
require_text "$(observer_ready_gate)" 'rc=0' \
  'the four-stream READY marker did not satisfy the observer READY gate'
pass_case

# Ordering: the pre-Pi marker must be emitted before the observer READY wait,
# and the final workstation READY only after it.
RUN_BODY="$(extract_function fcuvrx_run)"
PRESTART_LINE="$(grep -n 'FCU_TO_VRX_WORKSTATION_PRESTART=PASS' <<<"$RUN_BODY" |
  head -1 | cut -d: -f1)"
WAIT_LINE="$(grep -n 'fcuvrx_wait_observer_ready' <<<"$RUN_BODY" |
  head -1 | cut -d: -f1)"
READY_LINE="$(grep -n 'FCU_TO_VRX_WORKSTATION_READY=PASS' <<<"$RUN_BODY" |
  head -1 | cut -d: -f1)"
[ -n "$PRESTART_LINE" ] && [ -n "$WAIT_LINE" ] && [ -n "$READY_LINE" ] \
  || fail_test 'two-stage readiness markers are missing from fcuvrx_run'
[ "$PRESTART_LINE" -lt "$WAIT_LINE" ] && [ "$WAIT_LINE" -lt "$READY_LINE" ] \
  || fail_test 'readiness ordering is not prestart -> observer-ready -> READY'
require_text "$RUN_BODY" 'observer=ready streams=4' \
  'the final READY marker does not record proven observer readiness'
! grep -Fq 'observer=started publish_sensors' <<<"$RUN_BODY" \
  || fail_test 'the final READY marker still claims only observer=started'
require_text "$RUN_BODY" \
  'after PI_SOURCE_HOLD=ACTIVE, press Ctrl+C here before stopping W1 and the Pi helper' \
  'correlated Test B teardown does not preserve Pi streams until both observers stop'
pass_case

printf 'FCU-to-VRX workstation supervisor tests: PASS cases=%d runtime=not-started\n' \
  "$CASE_COUNT"
