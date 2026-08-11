#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${1:-$SCRIPT_DIR/live_dashboard_preflight.sh}"
RUNNER="${2:-$SCRIPT_DIR/sitl_digital_twin_runner.sh}"
CASE_COUNT=0

fail_test() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass_case() {
  CASE_COUNT=$((CASE_COUNT + 1))
}

extract_function() {
  local file="$1" name="$2"
  awk -v start="${name}() {" '
    $0 == start { capture = 1 }
    capture { print }
    capture && $0 == "}" { exit }
  ' "$file"
}

[ -r "$PREFLIGHT" ] || fail_test "preflight missing: $PREFLIGHT"
[ -r "$RUNNER" ] || fail_test "runner missing: $RUNNER"
bash -n "$PREFLIGHT"
bash -n "$RUNNER"

ENTRY="$(extract_function "$PREFLIGHT" run_sitl_digital_twin_entry)"
[ -n "$ENTRY" ] || fail_test 'SITL entry function is not extractable'
grep -Fq 'source "$runner"' <<<"$ENTRY" \
  || fail_test 'SITL entry does not source the companion'
grep -Fq 'run_sitl_digital_twin' <<<"$ENTRY" \
  || fail_test 'SITL entry does not invoke the companion'
[ "$(grep -Fc 'source "$runner"' "$PREFLIGHT")" -eq 1 ] \
  || fail_test 'SITL companion is sourced outside its sole entry'
grep -Fq '1:workstation) run_workstation_preflight ;;' "$PREFLIGHT" \
  || fail_test 'workstation dispatch changed'
grep -Fq '1:run) run_workstation_supervisor ;;' "$PREFLIGHT" \
  || fail_test 'run dispatch changed'
grep -Fq '2:pi) run_pi_preflight "$2" ;;' "$PREFLIGHT" \
  || fail_test 'Pi dispatch changed'
grep -Fq '1:sitl) run_sitl_digital_twin_entry ;;' "$PREFLIGHT" \
  || fail_test 'SITL dispatch is missing'
pass_case

set +e
DIRECT_OUTPUT="$(bash "$RUNNER" 2>&1)"
DIRECT_RC=$?
set -e
[ "$DIRECT_RC" -eq 2 ] || fail_test "direct runner returned $DIRECT_RC instead of 2"
grep -Fxq 'usage: tools/live_dashboard_preflight.sh sitl' <<<"$DIRECT_OUTPUT" \
  || fail_test 'direct runner did not point to the public entry'
pass_case

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
ROS_FIXTURE="$TEST_TMP/ros_setup.bash"
: >"$ROS_FIXTURE"

ENV_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  ROS_SETUP="$3"
  ROS_DOMAIN_ID=12
  ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
  ROS_LOCALHOST_ONLY=0
  ROS_STATIC_PEERS=192.0.2.1
  ROS_DISCOVERY_SERVER=192.0.2.2:11811
  RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
  CYCLONEDDS_URI=/tmp/cyclonedds.xml
  sitl_configure_ros_environment
  printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
    "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY" \
    "${ROS_STATIC_PEERS-unset}" "${ROS_DISCOVERY_SERVER-unset}" \
    "${RMW_IMPLEMENTATION-unset}" "${FASTDDS_DEFAULT_PROFILES_FILE-unset}" \
    "${FASTRTPS_DEFAULT_PROFILES_FILE-unset}" "${CYCLONEDDS_URI-unset}"
' _ "$PREFLIGHT" "$RUNNER" "$ROS_FIXTURE")"
[ "$ENV_OUTPUT" = '42|LOCALHOST|1|unset|unset|unset|unset|unset|unset' ] \
  || fail_test "SITL environment did not fail closed: $ENV_OUTPUT"
pass_case

set +e
UDP_LOCAL_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  ss() { printf "%s\n" "UNCONN 0 0 127.0.0.1:14600 0.0.0.0:*"; }
  sitl_reject_listening_udp_ports 14600
' _ "$PREFLIGHT" "$RUNNER" 2>&1)"
UDP_LOCAL_RC=$?
set -e
[ "$UDP_LOCAL_RC" -eq 1 ] \
  || fail_test "occupied local UDP port returned $UDP_LOCAL_RC instead of 1"
grep -Fq 'SITL UDP port already in use' <<<"$UDP_LOCAL_OUTPUT" \
  || fail_test 'occupied local UDP port was not reported'
bash -c '
  source "$1"
  source "$2"
  ss() { printf "%s\n" "UNCONN 0 0 127.0.0.1:9999 127.0.0.1:14600"; }
  sitl_reject_listening_udp_ports 14600
' _ "$PREFLIGHT" "$RUNNER" \
  || fail_test 'peer UDP port was mistaken for an occupied local port'
pass_case

STATE_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  WORKSTATION_LOG_ROOT="$3"
  CHILD_NAMES=(stale)
  CHILD_PIDS=(999)
  CHILD_PGIDS=(999)
  EMITTED_MARKERS=([stale]=1)
  CLEANING=1
  STOP_REQUESTED=1
  FINAL_RC=99
  RATE_LOG=stale
  sitl_init_supervisor_state
  sitl_write_parameter_file
  sitl_build_commands
  printf "RUN_DIR=%s\n" "$RUN_DIR"
  printf "STATE=%s,%s,%s,%s,%s,%s\n" \
    "${#CHILD_NAMES[@]}" "${#CHILD_PIDS[@]}" "${#CHILD_PGIDS[@]}" \
    "$CLEANING" "$STOP_REQUESTED" "$FINAL_RC"
  printf "RATE_LOG=%s\n" "${RATE_LOG:-empty}"
  printf "PARAMS_BEGIN\n"
  sed -n "1,3p" "$RUN_DIR/manifest/sitl.params"
  printf "PARAMS_END\n"
  printf "SITL_COMMAND=%s\n" "${SITL_SITL_COMMAND[*]}"
  printf "MAVPROXY_COMMAND=%s\n" "${SITL_MAVPROXY_COMMAND[*]}"
  printf "MAVROS_COMMAND=%s\n" "${SITL_MAVROS_COMMAND[*]}"
  printf "BRIDGE_COMMAND=%s\n" "${SITL_BRIDGE_COMMAND[*]}"
  printf "EVIDENCE_COMMAND=%s\n" "${SITL_EVIDENCE_COMMAND[*]}"
  printf "ROSBRIDGE_COMMAND=%s\n" "${SITL_ROSBRIDGE_COMMAND[*]}"
  printf "DASHBOARD_COMMAND=%s\n" "${SITL_DASHBOARD_COMMAND[*]}"
' _ "$PREFLIGHT" "$RUNNER" "$TEST_TMP")"
grep -Eq "^RUN_DIR=$TEST_TMP/sitl_digital_twin_[0-9]{8}_[0-9]{6}$" \
  <<<"$STATE_OUTPUT" || fail_test 'SITL run directory name is not isolated'
grep -Fxq 'STATE=0,0,0,0,0,0' <<<"$STATE_OUTPUT" \
  || fail_test 'SITL state initialization retained workstation state'
grep -Fxq 'RATE_LOG=empty' <<<"$STATE_OUTPUT" \
  || fail_test 'SITL state initialization retained the workstation rate log'
PARAM_BLOCK="$(sed -n '/^PARAMS_BEGIN$/,/^PARAMS_END$/{/^PARAMS_/d;p}' <<<"$STATE_OUTPUT")"
[ "$PARAM_BLOCK" = $'RC_OVERRIDE_TIME 0.5\nARMING_RUDDER 0\nBRD_SAFETY_DEFLT 1' ] \
  || fail_test 'SITL parameter file does not contain exactly the approved overlay'
grep -Fq -- '--vehicle-binary "$4"' <<<"$STATE_OUTPUT" \
  || fail_test 'SITL command does not pass an explicit vehicle binary'
grep -Fq -- '/home/ghostzero/ardupilot/build/sitl/bin/ardurover' \
  <<<"$STATE_OUTPUT" || fail_test 'SITL command does not select the pinned binary'
grep -Fq -- '-f motorboat-skid -I 0 --no-rebuild --no-configure --no-mavproxy' \
  <<<"$STATE_OUTPUT" || fail_test 'SITL command changed frame or build isolation'
grep -Fq -- '--master=tcp:127.0.0.1:5760:{"autoreconnect":false}' \
  <<<"$STATE_OUTPUT" || fail_test 'MAVProxy master can reconnect or changed endpoint'
grep -Fq -- '--out=udp:127.0.0.1:14600' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVProxy loopback route changed'
grep -Fq -- '--non-interactive' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVProxy is not explicitly non-interactive'
! grep -Eq -- '--console|--map|--cmd' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVProxy command enables an operator interface'
grep -Fq -- 'fcu_url:=udp://127.0.0.1:14600@' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVROS loopback endpoint changed'
grep -Fq -- 'gcs_url:=""' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVROS GCS URL is not explicitly empty'
grep -Fq -- 'system_id:=255' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVROS source system changed'
grep -Fq -- 'component_id:=191' <<<"$STATE_OUTPUT" \
  || fail_test 'MAVROS source component changed'
grep -Fq -- 'allow_real_fcu:=true' <<<"$STATE_OUTPUT" \
  || fail_test 'bridge is not explicitly enabled inside the isolated runner'
grep -Fq -- 'max_steering:=0.20' <<<"$STATE_OUTPUT" \
  || fail_test 'bridge steering bound changed'
grep -Fq -- 'max_throttle:=0.12' <<<"$STATE_OUTPUT" \
  || fail_test 'bridge throttle bound changed'
grep -Fq -- 'record --run-dir' <<<"$STATE_OUTPUT" \
  || fail_test 'evidence recorder command is missing'
grep -Fq -- 'address:=127.0.0.1' <<<"$STATE_OUTPUT" \
  || fail_test 'rosbridge is not loopback-only'
grep -Fq -- 'serve_dashboard.py 8002 127.0.0.1' <<<"$STATE_OUTPUT" \
  || fail_test 'dashboard is not loopback-only'
! grep -Eq '/dev/(tty|serial|cu\.)' <<<"$STATE_OUTPUT" \
  || fail_test 'SITL commands contain a physical serial endpoint'
RUN_FUNCTION="$(sed -n \
  '/^run_sitl_digital_twin() {/,/^if \[\[ "${BASH_SOURCE\[0\]}"/p' "$RUNNER")"
SNAPSHOT_LINE="$(grep -n '"$SITL_EVIDENCE" snapshot' <<<"$RUN_FUNCTION" | cut -d: -f1)"
BRIDGE_START_LINE="$(grep -n 'sitl_start_child bridge' <<<"$RUN_FUNCTION" | cut -d: -f1)"
RECORD_START_LINE="$(grep -n 'sitl_start_child evidence' <<<"$RUN_FUNCTION" | cut -d: -f1)"
[ -n "$SNAPSHOT_LINE" ] && [ -n "$BRIDGE_START_LINE" ] \
  && [ -n "$RECORD_START_LINE" ] \
  && [ "$SNAPSHOT_LINE" -lt "$BRIDGE_START_LINE" ] \
  && [ "$BRIDGE_START_LINE" -lt "$RECORD_START_LINE" ] \
  || fail_test 'snapshot, bridge and subscriber-only recorder order changed'
pass_case

set +e
MAVROS_PARSE_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  RUN_DIR="$3"
  ROS_LOG_DIR="$RUN_DIR/ros-parser-log"
  export ROS_LOG_DIR
  mkdir -p "$ROS_LOG_DIR"
  sitl_build_commands
  parsing=0
  ros_args=()
  for argument in "${SITL_MAVROS_COMMAND[@]}"; do
    if [ "$parsing" -eq 1 ]; then
      ros_args+=("$argument")
    elif [ "$argument" = --ros-args ]; then
      parsing=1
      ros_args+=("$argument")
    fi
  done
  [ "${#ros_args[@]}" -gt 0 ]
  /usr/bin/python3 -c "import rclpy, sys; rclpy.init(args=sys.argv[1:]); rclpy.shutdown()" \
    "${ros_args[@]}"
' _ "$PREFLIGHT" "$RUNNER" "$TEST_TMP" 2>&1)"
MAVROS_PARSE_RC=$?
set -e
[ "$MAVROS_PARSE_RC" -eq 0 ] \
  || fail_test "MAVROS ROS argument vector was rejected: $MAVROS_PARSE_OUTPUT"
pass_case

RUN_DIR_PATH="$(sed -n 's/^RUN_DIR=//p' <<<"$STATE_OUTPUT")"
GATE_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  RUN_DIR="$3"
  SUPERVISOR_LOG="$RUN_DIR/supervisor.log"
  SITL_OPERATOR_TIMEOUT_SECONDS=60
  sitl_create_operator_gate arm
' _ "$PREFLIGHT" "$RUNNER" "$RUN_DIR_PATH")"
grep -Fq -- '--action arm' <<<"$GATE_OUTPUT" \
  || fail_test 'operator gate did not print the exact one-shot action'
/usr/bin/python3 -c '
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
gate = json.loads(path.read_text(encoding="utf-8"))
assert gate["schema"] == "uvautoboat.sitl.operator.v1"
assert gate["action"] == "arm"
assert gate["run_dir"] == sys.argv[2]
assert gate["endpoint"] == "tcp:127.0.0.1:5762"
assert (gate["source_system"], gate["source_component"]) == (254, 190)
assert (gate["target_system"], gate["target_component"]) == (1, 1)
assert len(gate["nonce"]) == 32
' "$RUN_DIR_PATH/operator/arm.gate.json" "$RUN_DIR_PATH" \
  || fail_test 'operator gate content changed'
pass_case

CLEANUP_FUNCTION="$(extract_function "$RUNNER" sitl_cleanup)"
for ordered_pair in \
  'dashboard:rosbridge' \
  'rosbridge:bridge' \
  'bridge:evidence' \
  'evidence:mavros' \
  'mavros:mavproxy' \
  'mavproxy:sitl'; do
  before="${ordered_pair%%:*}"
  after="${ordered_pair##*:}"
  before_line="$(grep -n "sitl_stop_named_child $before" <<<"$CLEANUP_FUNCTION" | tail -1 | cut -d: -f1)"
  after_line="$(grep -n "sitl_stop_named_child $after" <<<"$CLEANUP_FUNCTION" | tail -1 | cut -d: -f1)"
  [ -n "$before_line" ] && [ -n "$after_line" ] && [ "$before_line" -lt "$after_line" ] \
    || fail_test "teardown order changed: $before must precede $after"
done
grep -Fq 'sitl_wait_shutdown_frames' <<<"$CLEANUP_FUNCTION" \
  || fail_test 'bridge shutdown frames are not awaited while evidence is alive'
TEARDOWN_REQUEST_FUNCTION="$(sed -n \
  '/^sitl_write_teardown_request() {/,/^sitl_wait_shutdown_frames() {/p' "$RUNNER")"
grep -Fq 'os.replace(temporary, path)' <<<"$TEARDOWN_REQUEST_FUNCTION" \
  || fail_test 'teardown request is exposed before its JSON is complete'
grep -Fq 'click Neutral Now once' "$RUNNER" \
  || fail_test 'browser prompt does not name the exact neutral control'
pass_case

printf '%s\n' '{"action":"arm","success":true}' >"$RUN_DIR_PATH/operator/arm.json"
set +e
CLEANUP_SS_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  RUN_DIR="$3"
  SUPERVISOR_LOG=/dev/null
  ss() { return 42; }
  sitl_wait_operator_action arm cleanup
' _ "$PREFLIGHT" "$RUNNER" "$RUN_DIR_PATH" 2>&1)"
CLEANUP_SS_RC=$?
set -e
[ "$CLEANUP_SS_RC" -ne 0 ] \
  || fail_test 'cleanup operator gate accepted a failed socket inspection'
! grep -Fq 'unbound variable' <<<"$CLEANUP_SS_OUTPUT" \
  || fail_test 'cleanup operator gate referenced state before initialization'
pass_case

set +e
INT_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  SUPERVISOR_LOG=/dev/null
  SUPERVISOR_PHASE=initialization
  SITL_CHILDREN_STARTED=0
  sitl_on_interrupt
' _ "$PREFLIGHT" "$RUNNER" 2>&1)"
INT_RC=$?
TERM_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  SUPERVISOR_LOG=/dev/null
  SUPERVISOR_PHASE=initialization
  SITL_CHILDREN_STARTED=0
  sitl_on_term
' _ "$PREFLIGHT" "$RUNNER" 2>&1)"
TERM_RC=$?
set -e
[ "$INT_RC" -eq 130 ] || fail_test "pre-child interrupt returned $INT_RC"
[ "$TERM_RC" -eq 143 ] || fail_test "pre-child termination returned $TERM_RC"
pass_case

printf 'PASS cases=%d\n' "$CASE_COUNT"
