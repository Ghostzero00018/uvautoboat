#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WORKSTATION_HELPER="${1:-$SCRIPT_DIR/real_fcu_digital_twin_workstation.sh}"
PI_HELPER="${2:-$SCRIPT_DIR/real_fcu_digital_twin_pi.sh}"
PLUGIN_YAML="${3:-$REPO_ROOT/config/mavros_real_fcu_closed_loop_plugins.yaml}"
PROBE_PLUGIN_YAML="${4:-$REPO_ROOT/config/mavros_real_fcu_t0b_plugins.yaml}"
BUNDLE_MANIFEST="$REPO_ROOT/config/real_fcu_digital_twin_bundle.sha256"
VIEW_ONLY_HELPER="$SCRIPT_DIR/pi_live_hailo_mavlink_dashboard.sh"
CAPTURE_HELPER="$SCRIPT_DIR/real_fcu_command_feedback_capture.py"
CAPTURE_TEST="$SCRIPT_DIR/test_real_fcu_command_feedback_capture.py"
EXPECTED_VIEW_ONLY_SHA256='8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c'
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

line_number_once() {
  local text="$1" literal="$2" label="$3"
  local -a matches=()
  mapfile -t matches < <(grep -nF -- "$literal" <<<"$text")
  [ "${#matches[@]}" -eq 1 ] \
    || fail_test "$label expected one match, found ${#matches[@]}"
  printf '%s\n' "${matches[0]%%:*}"
}

[ -r "$WORKSTATION_HELPER" ] \
  || fail_test "workstation helper missing: $WORKSTATION_HELPER"
[ -r "$PI_HELPER" ] || fail_test "Pi helper missing: $PI_HELPER"
[ -r "$PLUGIN_YAML" ] || fail_test "plugin YAML missing: $PLUGIN_YAML"
[ -r "$PROBE_PLUGIN_YAML" ] \
  || fail_test "T0b plugin YAML missing: $PROBE_PLUGIN_YAML"
[ -r "$BUNDLE_MANIFEST" ] \
  || fail_test "Pi bundle manifest missing: $BUNDLE_MANIFEST"
[ -r "$CAPTURE_HELPER" ] \
  || fail_test "command/feedback capture helper missing: $CAPTURE_HELPER"
[ -r "$CAPTURE_TEST" ] \
  || fail_test "command/feedback capture test missing: $CAPTURE_TEST"
bash -n "$WORKSTATION_HELPER"
bash -n "$PI_HELPER"
pass_case

WORKSTATION_CHECK_FUNCTION="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_check)"
grep -Fq 'test_real_fcu_command_feedback_capture.py' \
  <<<"$WORKSTATION_CHECK_FUNCTION" \
  || fail_test 'workstation check does not run the capture-helper suite'
pass_case

set +e
WORKSTATION_USAGE="$(bash "$WORKSTATION_HELPER" 2>&1)"
WORKSTATION_USAGE_RC=$?
PI_USAGE="$(bash "$PI_HELPER" 2>&1)"
PI_USAGE_RC=$?
set -e
[ "$WORKSTATION_USAGE_RC" -eq 2 ] \
  || fail_test "workstation helper returned $WORKSTATION_USAGE_RC instead of 2"
grep -Fq 'check|run' <<<"$WORKSTATION_USAGE" \
  || fail_test 'workstation usage does not expose check and run'
[ "$PI_USAGE_RC" -eq 2 ] \
  || fail_test "Pi helper returned $PI_USAGE_RC instead of 2"
grep -Fq 'check|probe|run-t2a|run' <<<"$PI_USAGE" \
  || fail_test 'Pi usage does not expose the distinct T2a-only run'
grep -Fq '1:run-t2a) rfcu_pi_run run-t2a' "$PI_HELPER" \
  || fail_test 'Pi main does not dispatch the T2a-only run'
pass_case

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
ROS_FIXTURE="$TEST_TMP/ros_setup.bash"
: >"$ROS_FIXTURE"

WORKSTATION_ENV="$(bash -c '
  source "$1"
  RFCU_WS_ROS_SETUP="$2"
  ROS_DOMAIN_ID=12
  ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
  ROS_LOCALHOST_ONLY=1
  ROS_STATIC_PEERS=192.0.2.1
  ROS_DISCOVERY_SERVER=192.0.2.2:11811
  RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
  CYCLONEDDS_URI=/tmp/cyclonedds.xml
  rfcu_ws_configure_ros_environment
  printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
    "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY" \
    "${ROS_STATIC_PEERS-unset}" "${ROS_DISCOVERY_SERVER-unset}" \
    "${RMW_IMPLEMENTATION-unset}" "${FASTDDS_DEFAULT_PROFILES_FILE-unset}" \
    "${FASTRTPS_DEFAULT_PROFILES_FILE-unset}" "${CYCLONEDDS_URI-unset}"
' _ "$WORKSTATION_HELPER" "$ROS_FIXTURE")"
[ "$WORKSTATION_ENV" = '43|SUBNET|0|unset|unset|unset|unset|unset|unset' ] \
  || fail_test "workstation ROS boundary changed: $WORKSTATION_ENV"

PI_ENV="$(bash -c '
  source "$1"
  RFCU_PI_ROS_SETUP="$2"
  ROS_DOMAIN_ID=12
  ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
  ROS_LOCALHOST_ONLY=1
  ROS_STATIC_PEERS=192.0.2.1
  ROS_DISCOVERY_SERVER=192.0.2.2:11811
  RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
  CYCLONEDDS_URI=/tmp/cyclonedds.xml
  rfcu_pi_configure_ros_environment
  printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
    "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY" \
    "${ROS_STATIC_PEERS-unset}" "${ROS_DISCOVERY_SERVER-unset}" \
    "${RMW_IMPLEMENTATION-unset}" "${FASTDDS_DEFAULT_PROFILES_FILE-unset}" \
    "${FASTRTPS_DEFAULT_PROFILES_FILE-unset}" "${CYCLONEDDS_URI-unset}"
' _ "$PI_HELPER" "$ROS_FIXTURE")"
[ "$PI_ENV" = '43|SUBNET|0|unset|unset|unset|unset|unset|unset' ] \
  || fail_test "Pi ROS boundary changed: $PI_ENV"

PI_PROBE_ENV="$(bash -c '
  source "$1"
  RFCU_PI_ROS_SETUP="$2"
  RFCU_PI_RUN_MODE=probe
  ROS_DOMAIN_ID=12
  ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
  ROS_LOCALHOST_ONLY=1
  ROS_STATIC_PEERS=192.0.2.1
  ROS_DISCOVERY_SERVER=192.0.2.2:11811
  RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
  FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
  FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
  CYCLONEDDS_URI=/tmp/cyclonedds.xml
  rfcu_pi_configure_ros_environment
  printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
    "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY" \
    "${ROS_STATIC_PEERS-unset}" "${ROS_DISCOVERY_SERVER-unset}" \
    "${RMW_IMPLEMENTATION-unset}" "${FASTDDS_DEFAULT_PROFILES_FILE-unset}" \
    "${FASTRTPS_DEFAULT_PROFILES_FILE-unset}" "${CYCLONEDDS_URI-unset}"
' _ "$PI_HELPER" "$ROS_FIXTURE")"
[ "$PI_PROBE_ENV" = '43|LOCALHOST|0|unset|unset|unset|unset|unset|unset' ] \
  || fail_test "Pi probe ROS boundary is not localhost-only: $PI_PROBE_ENV"

PI_RUN_ENV="$(bash -c '
  source "$1"
  RFCU_PI_ROS_SETUP="$2"
  for RFCU_PI_RUN_MODE in run-t2a run; do
    ROS_DOMAIN_ID=12
    ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
    ROS_LOCALHOST_ONLY=1
    ROS_STATIC_PEERS=192.0.2.1
    ROS_DISCOVERY_SERVER=192.0.2.2:11811
    RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    FASTDDS_DEFAULT_PROFILES_FILE=/tmp/fastdds.xml
    FASTRTPS_DEFAULT_PROFILES_FILE=/tmp/fastrtps.xml
    CYCLONEDDS_URI=/tmp/cyclonedds.xml
    rfcu_pi_configure_ros_environment
    printf "%s=%s|%s|%s\n" "$RFCU_PI_RUN_MODE" \
      "$ROS_DOMAIN_ID" "$ROS_AUTOMATIC_DISCOVERY_RANGE" "$ROS_LOCALHOST_ONLY"
  done
' _ "$PI_HELPER" "$ROS_FIXTURE")"
[ "$PI_RUN_ENV" = $'run-t2a=43|SUBNET|0\nrun=43|SUBNET|0' ] \
  || fail_test "Pi run ROS boundary lost subnet discovery: $PI_RUN_ENV"

PI_PROBE_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_probe)"
PI_PROBE_MODE_LINE="$(line_number_once "$PI_PROBE_FUNCTION" \
  'RFCU_PI_RUN_MODE=probe' 'Pi probe run mode')"
PI_PROBE_PREFLIGHT_LINE="$(line_number_once "$PI_PROBE_FUNCTION" \
  'rfcu_pi_static_preflight' 'Pi probe static preflight')"
[ "$PI_PROBE_MODE_LINE" -lt "$PI_PROBE_PREFLIGHT_LINE" ] \
  || fail_test 'Pi probe does not select its mode before ROS preflight'
grep -Fq 'rfcu_pi_start_child mavros-probe' <<<"$PI_PROBE_FUNCTION" \
  || fail_test 'Pi probe does not start its local MAVROS child'
! grep -Fq 'rfcu_pi_wait_workstation_nodes' <<<"$PI_PROBE_FUNCTION" \
  || fail_test 'Pi probe unexpectedly depends on workstation ROS nodes'
! grep -Fq 'RFCU_PI_BRIDGE_COMMAND' <<<"$PI_PROBE_FUNCTION" \
  || fail_test 'Pi probe unexpectedly starts the command bridge'
grep -Fq 'discovery=$ROS_AUTOMATIC_DISCOVERY_RANGE' <<<"$PI_PROBE_FUNCTION" \
  || fail_test 'Pi probe start marker does not report its effective discovery range'
pass_case

GUARD_SNAPSHOT_FILE="$TEST_TMP/guard_snapshot.parm"
printf 'RC_OVERRIDE_TIME 0.5\n' >"$GUARD_SNAPSHOT_FILE"
GUARD_SNAPSHOT_SHA256="$(sha256sum "$GUARD_SNAPSHOT_FILE" | awk '{print $1}')"
GUARD_SNAPSHOT_OUTPUT="$(bash -c '
  source "$1"
  RFCU_PI_RUN_MODE=run
  RFCU_PI_GUARD_SNAPSHOT_FILE="$2"
  RFCU_PI_GUARD_SNAPSHOT_SHA256="$3"
  RFCU_PI_GUARD_SNAPSHOT_APPROVED=1
  rfcu_pi_validate_guard_snapshot_selector
  rfcu_pi_build_commands
  printf "source=%s\n" "$RFCU_PI_GUARD_SOURCE"
  printf "command=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
' _ "$PI_HELPER" "$GUARD_SNAPSHOT_FILE" "$GUARD_SNAPSHOT_SHA256")"
grep -Fq 'source=snapshot' <<<"$GUARD_SNAPSHOT_OUTPUT" \
  || fail_test 'approved hash-pinned guard snapshot was not selected'
grep -Fq "guard_snapshot_file:=\"$GUARD_SNAPSHOT_FILE\"" \
  <<<"$GUARD_SNAPSHOT_OUTPUT" \
  || fail_test 'bridge command omitted the approved guard snapshot path'
grep -Fq "guard_snapshot_sha256:=\"$GUARD_SNAPSHOT_SHA256\"" \
  <<<"$GUARD_SNAPSHOT_OUTPUT" \
  || fail_test 'bridge command omitted the approved guard snapshot hash'
pass_case

for failure_case in partial unauthorized probe hash-drift; do
  set +e
  GUARD_SNAPSHOT_FAILURE_OUTPUT="$(bash -c '
    source "$1"
    RFCU_PI_RUN_MODE=run
    RFCU_PI_GUARD_SNAPSHOT_FILE="$2"
    RFCU_PI_GUARD_SNAPSHOT_SHA256="$3"
    RFCU_PI_GUARD_SNAPSHOT_APPROVED=1
    case "$4" in
      partial) RFCU_PI_GUARD_SNAPSHOT_SHA256= ;;
      unauthorized) RFCU_PI_GUARD_SNAPSHOT_APPROVED=0 ;;
      probe) RFCU_PI_RUN_MODE=probe ;;
      hash-drift) RFCU_PI_GUARD_SNAPSHOT_SHA256="$(printf "0%.0s" {1..64})" ;;
    esac
    rfcu_pi_validate_guard_snapshot_selector
  ' _ "$PI_HELPER" "$GUARD_SNAPSHOT_FILE" "$GUARD_SNAPSHOT_SHA256" \
    "$failure_case" 2>&1)"
  GUARD_SNAPSHOT_FAILURE_RC=$?
  set -e
  [ "$GUARD_SNAPSHOT_FAILURE_RC" -ne 0 ] \
    || fail_test "guard snapshot selector accepted $failure_case"
  grep -Fq 'STOP:' <<<"$GUARD_SNAPSHOT_FAILURE_OUTPUT" \
    || fail_test "guard snapshot rejection lacked a stop marker: $failure_case"
done
pass_case

PI_RUNTIME_GUARD_FUNCTION="$(extract_function "$PI_HELPER" \
  rfcu_pi_capture_runtime_guard)"
PI_RUN_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_run)"
grep -Fq 'rfcu_pi_capture_snapshot_guard' <<<"$PI_RUNTIME_GUARD_FUNCTION" \
  && grep -Fq 'rfcu_pi_capture_t0b' <<<"$PI_RUNTIME_GUARD_FUNCTION" \
  || fail_test 'runtime guard dispatcher does not retain both guard sources'
grep -Fq 'rfcu_pi_capture_runtime_guard' <<<"$PI_RUN_FUNCTION" \
  || fail_test 'Pi run path does not use the runtime guard dispatcher'
! grep -Fq 'rfcu_pi_capture_runtime_guard' <<<"$PI_PROBE_FUNCTION" \
  && grep -Fq 'rfcu_pi_capture_t0b' <<<"$PI_PROBE_FUNCTION" \
  || fail_test 'Pi probe no longer requires the live T0b path'
pass_case

WORKSTATION_CONFLICT_OUTPUT="$(bash -c '
  source "$1"
  printf "%s\n" "${RFCU_WS_CONFLICT_PATTERNS[@]}"
' _ "$WORKSTATION_HELPER")"
EXPECTED_WORKSTATION_CONFLICTS=$'ardurover\nsim_vehicle.py\nmavproxy.py\nMAVProxy\nmavros_node\nreal_fcu_rc_command_bridge.py\nsitl_digital_twin_evidence.py\nsitl_operator_once.py\nrosbridge\nserve_dashboard.py'
[ "$WORKSTATION_CONFLICT_OUTPUT" = "$EXPECTED_WORKSTATION_CONFLICTS" ] \
  || fail_test "workstation conflict guard does not mirror SITL ownership: $WORKSTATION_CONFLICT_OUTPUT"
pass_case

COMMAND_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  RFCU_WS_RUN_DIR="$3/workstation"
  RFCU_PI_RUN_DIR="$3/pi"
  mkdir -p "$RFCU_WS_RUN_DIR" "$RFCU_PI_RUN_DIR"
  rfcu_ws_build_commands
  RFCU_PI_RUN_MODE=run-t2a
  rfcu_pi_build_commands
  printf "PI_T2A_BRIDGE=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
  RFCU_PI_RUN_MODE=run
  rfcu_pi_build_commands
  printf "WS_ROSBRIDGE=%s\n" "${RFCU_WS_ROSBRIDGE_COMMAND[*]}"
  printf "WS_DASHBOARD=%s\n" "${RFCU_WS_DASHBOARD_COMMAND[*]}"
  printf "PI_MAVROS=%s\n" "${RFCU_PI_MAVROS_COMMAND[*]}"
  printf "PI_PROBE_MAVROS=%s\n" "${RFCU_PI_PROBE_MAVROS_COMMAND[*]}"
  printf "PI_T2B_BRIDGE=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
' _ "$WORKSTATION_HELPER" "$PI_HELPER" "$TEST_TMP")"
grep -Fq 'address:=127.0.0.1' <<<"$COMMAND_OUTPUT" \
  || fail_test 'rosbridge is not loopback-only'
grep -Fq 'serve_dashboard.py 8002 127.0.0.1' <<<"$COMMAND_OUTPUT" \
  || fail_test 'dashboard is not loopback-only'
grep -Fq 'fcu_url:=serial:///dev/ttyAMA0:57600' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS does not own the direct serial link'
grep -Fq 'gcs_url:=""' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS GCS URL is not explicitly empty'
grep -Fq 'system_id:=255' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS source system changed'
grep -Fq 'component_id:=191' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS source component changed'
grep -Fq 'target_system_id:=1' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS target system changed'
grep -Fq 'target_component_id:=1' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS target component changed'
grep -Fq "$PLUGIN_YAML" <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi MAVROS does not use the closed-loop plugin allowlist'
grep -Fq "$PROBE_PLUGIN_YAML" <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi T0b MAVROS does not use the read-only plugin allowlist'
grep -Fq 'allow_real_fcu:=true' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi bridge is not explicitly enabled'
grep -Fq 'expected_domain_id:="43"' <<<"$COMMAND_OUTPUT" \
  || fail_test 'physical bridge does not explicitly require domain 43'
grep -Fq 'max_steering:=0.20' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi bridge steering bound changed'
grep -Fq 'max_throttle:=0.12' <<<"$COMMAND_OUTPUT" \
  || fail_test 'Pi bridge throttle bound changed'
grep -Fq 'PI_T2A_BRIDGE=' <<<"$COMMAND_OUTPUT" \
  && grep -Fq 'neutral_only:=true' \
    <<<"$(grep -F 'PI_T2A_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T2a bridge command is not explicitly neutral-only'
grep -Fq 'PI_T2B_BRIDGE=' <<<"$COMMAND_OUTPUT" \
  && grep -Fq 'neutral_only:=false' \
    <<<"$(grep -F 'PI_T2B_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T2b bridge command lost demand-enabled authority'
! grep -Eiq 'mavproxy|udp(out)?://|--out=' <<<"$COMMAND_OUTPUT" \
  || fail_test 'physical command path still contains a relay or UDP fanout'
pass_case

ROS_PARSE_OUTPUT="$(bash -c '
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  ROS_LOG_DIR="$2/ros-parser-log"
  export ROS_LOG_DIR
  mkdir -p "$ROS_LOG_DIR"
  rfcu_pi_build_commands
  for command_name in RFCU_PI_PROBE_MAVROS_COMMAND RFCU_PI_MAVROS_COMMAND RFCU_PI_BRIDGE_COMMAND; do
    declare -n command_ref="$command_name"
    parsing=0
    ros_args=()
    for argument in "${command_ref[@]}"; do
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
  done
' _ "$PI_HELPER" "$TEST_TMP" 2>&1)" \
  || fail_test "Pi ROS argument vector was rejected: $ROS_PARSE_OUTPUT"
pass_case

for variable in \
  REAL_FCU_T0A_COMPLETE \
  REAL_FCU_T0B_APPROVED \
  REAL_FCU_T2A_APPROVED \
  REAL_FCU_T2B_APPROVED \
  REAL_FCU_START_DISARMED \
  REAL_FCU_SAFETY_ON \
  REAL_FCU_PROPELLERS_REMOVED \
  REAL_FCU_HULL_RESTRAINED \
  REAL_FCU_PROPULSION_ISOLATED; do
  set +e
  GATE_OUTPUT="$(env \
    REAL_FCU_T0A_COMPLETE=1 \
    REAL_FCU_T0B_APPROVED=1 \
    REAL_FCU_T2A_APPROVED=1 \
    REAL_FCU_T2B_APPROVED=1 \
    REAL_FCU_START_DISARMED=1 \
    REAL_FCU_SAFETY_ON=1 \
    REAL_FCU_PROPELLERS_REMOVED=1 \
    REAL_FCU_HULL_RESTRAINED=1 \
    REAL_FCU_PROPULSION_ISOLATED=1 \
    "$variable"=0 \
    bash -c 'source "$1"; rfcu_pi_require_run_gates' _ "$PI_HELPER" 2>&1)"
  GATE_RC=$?
  set -e
  [ "$GATE_RC" -ne 0 ] || fail_test "run gate accepted $variable=0"
  grep -Fq "$variable must be 1" <<<"$GATE_OUTPUT" \
    || fail_test "run gate did not name $variable"
done
env \
  REAL_FCU_T0A_COMPLETE=1 \
  REAL_FCU_T0B_APPROVED=1 \
  REAL_FCU_T2A_APPROVED=1 \
  REAL_FCU_T2B_APPROVED=1 \
  REAL_FCU_START_DISARMED=1 \
  REAL_FCU_SAFETY_ON=1 \
  REAL_FCU_PROPELLERS_REMOVED=1 \
  REAL_FCU_HULL_RESTRAINED=1 \
  REAL_FCU_PROPULSION_ISOLATED=1 \
  bash -c 'source "$1"; rfcu_pi_require_run_gates' _ "$PI_HELPER" \
  || fail_test 'complete run gate was rejected'

env \
  REAL_FCU_T0A_COMPLETE=1 \
  REAL_FCU_T0B_APPROVED=1 \
  REAL_FCU_T2A_APPROVED=1 \
  REAL_FCU_T2B_APPROVED=0 \
  REAL_FCU_START_DISARMED=1 \
  REAL_FCU_SAFETY_ON=1 \
  REAL_FCU_PROPELLERS_REMOVED=1 \
  REAL_FCU_HULL_RESTRAINED=1 \
  REAL_FCU_PROPULSION_ISOLATED=1 \
  bash -c 'source "$1"; rfcu_pi_require_t2a_run_gates' _ "$PI_HELPER" \
  || fail_test 'T2a-only gate was rejected'
for approval_pair in '0 0' '0 1' '1 1'; do
  read -r t2a_approved t2b_approved <<<"$approval_pair"
  set +e
  T2A_GATE_OUTPUT="$(env \
    REAL_FCU_T0A_COMPLETE=1 \
    REAL_FCU_T0B_APPROVED=1 \
    REAL_FCU_T2A_APPROVED="$t2a_approved" \
    REAL_FCU_T2B_APPROVED="$t2b_approved" \
    REAL_FCU_START_DISARMED=1 \
    REAL_FCU_SAFETY_ON=1 \
    REAL_FCU_PROPELLERS_REMOVED=1 \
    REAL_FCU_HULL_RESTRAINED=1 \
    REAL_FCU_PROPULSION_ISOLATED=1 \
    bash -c 'source "$1"; rfcu_pi_require_t2a_run_gates' _ "$PI_HELPER" 2>&1)"
  T2A_GATE_RC=$?
  set -e
  [ "$T2A_GATE_RC" -ne 0 ] \
    || fail_test "T2a gate accepted approvals $t2a_approved/$t2b_approved"
done
pass_case

T0B_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_capture_t0b)"
[ -n "$T0B_FUNCTION" ] || fail_test 'T0b capture function is missing'
T0B_READ_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_read_t0b_parameter)"
[ -n "$T0B_READ_FUNCTION" ] || fail_test 'T0b parameter-read function is missing'
grep -Fq 'ros2 param get /mavros/param' <<<"$T0B_READ_FUNCTION" \
  || fail_test 'T0b parameter helper is not read-only MAVROS cache access'
for literal in \
  '/mavros/state' \
  '/mavros/sys_status' \
  '/mavros/param/pull' \
  'mavros_msgs/srv/ParamPull' \
  'force_pull: true' \
  'BRD_SAFETY_DEFLT' \
  'BRD_SAFETY_MASK' \
  'BRD_SAFETYOPTION' \
  't0b-discovery-parameters' \
  't0b-rail-parameters' \
  't0b-write-evidence' \
  '32768'; do
  grep -Fq "$literal" <<<"$T0B_FUNCTION" \
    || fail_test "T0b capture is missing: $literal"
done
! grep -Eiq 'param(eter)?[_ -]?set|set_mode|arming|motor.test|rc.override|create_publisher|publish\(' \
  <<<"$T0B_FUNCTION$T0B_READ_FUNCTION" \
  || fail_test 'T0b capture contains a forbidden write path'

CAPTURE_TOPIC_REGRESSION_FAILURES=0

CAPTURE_TOPIC_DIAGNOSTIC_DIR="$TEST_TMP/capture-topic-diagnostic"
mkdir -p "$CAPTURE_TOPIC_DIAGNOSTIC_DIR/evidence"
set +e
CAPTURE_TOPIC_DIAGNOSTIC_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  ros2() {
    printf "connected: true\narmed: false\n---\n"
    printf "controlled diagnostic\n" >&2
  }
  tee() {
    command tee "$@"
    printf "controlled tee diagnostic\n" >&2
  }
  rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State \
    "$2/evidence/state.yaml" 3
' _ "$PI_HELPER" "$CAPTURE_TOPIC_DIAGNOSTIC_DIR" 2>&1)"
CAPTURE_TOPIC_DIAGNOSTIC_RC=$?
set -e
if [ "$CAPTURE_TOPIC_DIAGNOSTIC_RC" -eq 0 ] \
    && [ -f "$CAPTURE_TOPIC_DIAGNOSTIC_DIR/evidence/state.yaml" ] \
    && [ "$(cat "$CAPTURE_TOPIC_DIAGNOSTIC_DIR/evidence/state.yaml")" = \
      $'connected: true\narmed: false\n---' ] \
    && [ -z "$CAPTURE_TOPIC_DIAGNOSTIC_OUTPUT" ] \
    && [ -f "$CAPTURE_TOPIC_DIAGNOSTIC_DIR/evidence/state.attempt-001.stderr.log" ] \
    && [ "$(cat "$CAPTURE_TOPIC_DIAGNOSTIC_DIR/evidence/state.attempt-001.stderr.log")" = \
      $'controlled diagnostic\ncontrolled tee diagnostic' ]; then
  pass_case
else
  printf 'FAIL: capture-topic diagnostic contaminated evidence or was not retained separately: rc=%s output=[%s]\n' \
    "$CAPTURE_TOPIC_DIAGNOSTIC_RC" "$CAPTURE_TOPIC_DIAGNOSTIC_OUTPUT" >&2
  CAPTURE_TOPIC_REGRESSION_FAILURES=$((CAPTURE_TOPIC_REGRESSION_FAILURES + 1))
fi

CAPTURE_TOPIC_RETENTION_DIR="$TEST_TMP/capture-topic-retention"
mkdir -p "$CAPTURE_TOPIC_RETENTION_DIR/evidence"
set +e
CAPTURE_TOPIC_RETENTION_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  capture_value=first
  ros2() {
    printf "sequence: %s\n---\n" "$capture_value"
  }
  rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State \
    "$2/evidence/state.yaml" 3
  capture_value=second
  rfcu_pi_capture_topic /mavros/state mavros_msgs/msg/State \
    "$2/evidence/state.yaml" 3
' _ "$PI_HELPER" "$CAPTURE_TOPIC_RETENTION_DIR" 2>&1)"
CAPTURE_TOPIC_RETENTION_RC=$?
set -e
if [ "$CAPTURE_TOPIC_RETENTION_RC" -eq 0 ] \
    && [ -f "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.yaml" ] \
    && [ "$(cat "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.yaml")" = \
      $'sequence: second\n---' ] \
    && [ -f "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.attempt-001.yaml" ] \
    && [ "$(cat "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.attempt-001.yaml")" = \
      $'sequence: first\n---' ] \
    && [ -f "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.attempt-002.yaml" ] \
    && [ "$(cat "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.attempt-002.yaml")" = \
      $'sequence: second\n---' ] \
    && [ ! -e "$CAPTURE_TOPIC_RETENTION_DIR/evidence/state.attempt-003.yaml" ]; then
  pass_case
else
  printf 'FAIL: capture-topic attempts were not retained at distinct paths: rc=%s output=[%s]\n' \
    "$CAPTURE_TOPIC_RETENTION_RC" "$CAPTURE_TOPIC_RETENTION_OUTPUT" >&2
  CAPTURE_TOPIC_REGRESSION_FAILURES=$((CAPTURE_TOPIC_REGRESSION_FAILURES + 1))
fi

[ "$CAPTURE_TOPIC_REGRESSION_FAILURES" -eq 0 ] \
  || fail_test "$CAPTURE_TOPIC_REGRESSION_FAILURES capture-topic behavioural regressions failed"

T0B_READ_FAIL_DIR="$TEST_TMP/t0b-read-failure"
mkdir -p "$T0B_READ_FAIL_DIR/evidence"
: >"$T0B_READ_FAIL_DIR/evidence/t0b_parameters.txt"
set +e
bash -c '
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_SUPERVISOR_LOG="$2/supervisor.log"
  : >"$RFCU_PI_SUPERVISOR_LOG"
  timeout() { return 1; }
  if rfcu_pi_read_t0b_parameter RCMAP_ROLL \
      "$2/evidence/t0b_parameters.txt"; then
    exit 0
  else
    exit $?
  fi
' _ "$PI_HELPER" "$T0B_READ_FAIL_DIR" >/dev/null 2>&1
T0B_READ_FAIL_RC=$?
set -e
[ "$T0B_READ_FAIL_RC" -ne 0 ] \
  || fail_test 'T0b cache-read failure returned success from a conditional caller'
[ ! -s "$T0B_READ_FAIL_DIR/evidence/t0b_parameters.txt" ] \
  || fail_test 'T0b cache-read failure appended an invalid parameter value'
pass_case

T0B_CASE_DIR="$TEST_TMP/t0b-artifact"
mkdir -p "$T0B_CASE_DIR/evidence" "$T0B_CASE_DIR/logs"
T0B_CAPTURE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_SUPERVISOR_LOG="$2/supervisor.log"
  ROS_DOMAIN_ID=43
  : >"$RFCU_PI_SUPERVISOR_LOG"

  rfcu_pi_capture_topic() {
    case "$1" in
      /mavros/state) printf "connected: true\narmed: false\n---\n" >"$3" ;;
      /mavros/sys_status) printf "sensors_enabled: 0\n---\n" >"$3" ;;
      *) return 1 ;;
    esac
  }
  rfcu_pi_state_file_is_connected_disarmed() { return 0; }
  timeout() {
    shift
    if [ "$1" = ros2 ] && [ "$2" = service ] && [ "$3" = call ]; then
      printf "success=True\n"
      return 0
    fi
    [ "$1" = ros2 ] && [ "$2" = param ] && [ "$3" = get ] || return 1
    case "$5" in
      BRD_SAFETY_DEFLT) value=1 ;;
      BRD_SAFETY_MASK|BRD_SAFETYOPTION) value=0 ;;
      RCMAP_ROLL) value=1 ;;
      RCMAP_THROTTLE) value=3 ;;
      SERVO1_FUNCTION) value=74 ;;
      SERVO3_FUNCTION) value=73 ;;
      SERVO*_FUNCTION) value=0 ;;
      RC1_MIN|RC3_MIN) value=1000 ;;
      RC1_TRIM|RC3_TRIM) value=1500 ;;
      RC1_MAX|RC3_MAX) value=2000 ;;
      RC1_DZ|RC3_DZ) value=30 ;;
      RC1_REVERSED|RC3_REVERSED|RC1_OPTION|RC3_OPTION) value=0 ;;
      SERVO1_MIN|SERVO3_MIN|SERVO1_TRIM|SERVO3_TRIM) value=800 ;;
      SERVO1_MAX|SERVO3_MAX) value=2200 ;;
      SERVO1_REVERSED|SERVO3_REVERSED) value=0 ;;
      *) printf "unexpected parameter: %s\n" "$5" >&2; return 1 ;;
    esac
    printf "Integer value is: %s\n" "$value"
  }

  rfcu_pi_capture_t0b
' _ "$PI_HELPER" "$T0B_CASE_DIR" 2>&1)" \
  || fail_test "T0b artifact capture failed: $T0B_CAPTURE_OUTPUT"
grep -Fq 'REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained' \
  <<<"$T0B_CAPTURE_OUTPUT" || fail_test 'T0b pass marker does not retain the expanded read count'
/usr/bin/python3 -c '
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["schema"] == "uvautoboat.real_fcu.t0b.v2"
assert payload["parameter_reads"] == 41
assert len(payload["recorded_parameters"]) == 41
assert payload["rcmap"] == {"RCMAP_ROLL": 1, "RCMAP_THROTTLE": 3}
assert len(payload["servo_functions"]) == 16
assert payload["resolved"] == {
    "steering_rc": 1,
    "throttle_rc": 3,
    "left_servo": 3,
    "right_servo": 1,
}
assert payload["rc_rails"]["steering"]["trim"] == 1500
assert payload["rc_rails"]["throttle"]["trim"] == 1500
assert payload["servo_rails"]["left"]["trim"] == 800
assert payload["servo_rails"]["right"]["trim"] == 800
' "$T0B_CASE_DIR/evidence/t0b.json" \
  || fail_test 'T0b artifact is missing mapping or rail evidence'
[ "$(grep -cE '^[A-Z][A-Z0-9_]*=' \
  "$T0B_CASE_DIR/evidence/t0b_parameters.txt")" -eq 41 ] \
  || fail_test 'T0b parameter record does not contain exactly 41 values'
pass_case

RUN_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_run)"
PROBE_START_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_start_child mavros-probe' 'Pi probe start')"
RUNTIME_GUARD_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_capture_runtime_guard' 'Pi runtime guard capture')"
PROBE_STOP_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_stop_child mavros-probe' 'Pi probe stop')"
MAVROS_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_start_child mavros ' 'Pi MAVROS start')"
BRIDGE_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_start_child bridge' 'Pi bridge start')"
[ -n "$PROBE_START_LINE" ] && [ -n "$RUNTIME_GUARD_LINE" ] \
  && [ -n "$PROBE_STOP_LINE" ] \
  && [ -n "$MAVROS_LINE" ] && [ -n "$BRIDGE_LINE" ] \
  && [ "$PROBE_START_LINE" -lt "$RUNTIME_GUARD_LINE" ] \
  && [ "$RUNTIME_GUARD_LINE" -lt "$PROBE_STOP_LINE" ] \
  && [ "$PROBE_STOP_LINE" -lt "$MAVROS_LINE" ] \
  && [ "$MAVROS_LINE" -lt "$BRIDGE_LINE" ] \
  || fail_test 'run does not separate the guard probe from full MAVROS/bridge'
pass_case

READY_STATUS='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":false,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}'
BENCH_URL="$(bash -c 'source "$1"; rfcu_ws_bench_url_from_status "$2"' \
  _ "$WORKSTATION_HELPER" "$READY_STATUS")"
[ "$BENCH_URL" = 'http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=3&thrust_right_servo=1' ] \
  || fail_test "workstation helper emitted an unexpected bench URL: $BENCH_URL"
T2A_READY_STATUS='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":true,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}'
T2A_BENCH_URL="$(bash -c 'source "$1"; rfcu_ws_bench_url_from_status "$2"' \
  _ "$WORKSTATION_HELPER" "$T2A_READY_STATUS")"
[ "$T2A_BENCH_URL" = 'http://127.0.0.1:8002/?thrust_left_servo=3&thrust_right_servo=1' ] \
  || fail_test "T2a workstation URL exposed bench commands: $T2A_BENCH_URL"
bash -c 'source "$1"; rfcu_pi_status_is_ready "$2" false' \
  _ "$PI_HELPER" "$READY_STATUS" \
  || fail_test 'Pi rejected demand-enabled readiness for full run'
bash -c 'source "$1"; rfcu_pi_status_is_ready "$2" true' \
  _ "$PI_HELPER" "$T2A_READY_STATUS" \
  || fail_test 'Pi rejected neutral-only readiness for T2a'
if bash -c 'source "$1"; rfcu_pi_status_is_ready "$2" false' \
    _ "$PI_HELPER" "$T2A_READY_STATUS"; then
  fail_test 'full run accepted neutral-only bridge readiness'
fi
if bash -c 'source "$1"; rfcu_pi_status_is_ready "$2" true' \
    _ "$PI_HELPER" "$READY_STATUS"; then
  fail_test 'T2a accepted demand-enabled bridge readiness'
fi
for invalid_status in \
  '{"state":"STARTUP_ARMED","ready":false,"connected":true,"armed":true,"mode":"MANUAL","feedback_fresh":true,"resolved":{"left_servo":3,"right_servo":1}}' \
  '{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"resolved":{"left_servo":3,"right_servo":3}}' \
  '{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":false,"resolved":{"left_servo":3,"right_servo":1}}'; do
  set +e
  bash -c 'source "$1"; rfcu_ws_bench_url_from_status "$2"' \
    _ "$WORKSTATION_HELPER" "$invalid_status" >/dev/null 2>&1
  INVALID_RC=$?
  set -e
  [ "$INVALID_RC" -ne 0 ] || fail_test 'unsafe bridge status produced a bench URL'
done
pass_case

for valid_final_status in \
  '{"state":"READY_DISARMED","connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true}' \
  '{"state":"EMERGENCY_STOP","connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true}'; do
  bash -c 'source "$1"; rfcu_ws_status_is_final_disarmed "$2"' \
    _ "$WORKSTATION_HELPER" "$valid_final_status" \
    || fail_test "valid final-disarmed status was rejected: $valid_final_status"
done
for invalid_final_status in \
  '{"state":"ACTIVE","connected":true,"armed":true,"mode":"MANUAL","feedback_fresh":true}' \
  '{"state":"READY_DISARMED","connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":false}'; do
  set +e
  bash -c 'source "$1"; rfcu_ws_status_is_final_disarmed "$2"' \
    _ "$WORKSTATION_HELPER" "$invalid_final_status" >/dev/null 2>&1
  INVALID_FINAL_RC=$?
  set -e
  [ "$INVALID_FINAL_RC" -ne 0 ] \
    || fail_test "unsafe final status was accepted: $invalid_final_status"
done
WS_RUN_FUNCTION="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_run)"
WS_STATUS_FUNCTION="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_status_json_once)"
PI_STATUS_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_status_json_once)"
grep -Fq -- '--no-lost-messages' <<<"$WS_STATUS_FUNCTION" \
  || fail_test 'workstation status probe permits ROS echo loss diagnostics on stdout'
grep -Fq -- '--no-lost-messages' <<<"$PI_STATUS_FUNCTION" \
  || fail_test 'Pi status probe permits ROS echo loss diagnostics on stdout'
pass_case

STATUS_JSON='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false}'
for status_case in \
  "$WORKSTATION_HELPER|rfcu_ws_status_json_once|RFCU_WS_RUN_DIR" \
  "$PI_HELPER|rfcu_pi_status_json_once|RFCU_PI_RUN_DIR"; do
  IFS='|' read -r status_helper status_function status_run_dir <<<"$status_case"
  STATUS_TEST_DIR="$TEST_TMP/status-${status_function}"
  mkdir -p "$STATUS_TEST_DIR/logs"
  bash -c '
    source "$1"
    printf -v "$3" "%s" "$2"
    status_output="$4"
    status_function="$5"
    ros2() { printf "%s\n" "$status_output"; }
    result="$("$status_function")"
    [ "$result" = "$status_output" ]
  ' _ "$status_helper" "$STATUS_TEST_DIR" "$status_run_dir" \
    "$STATUS_JSON" "$status_function" \
    || fail_test "$status_function rejected raw JSON from ros2 topic echo --field data"
done
pass_case

PI_CONFIRM_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_confirm_manual_safety_release)"
grep -Fq 'read -r -p' <<<"$PI_CONFIRM_FUNCTION" \
  || fail_test 'Pi manual safety gate does not wait for terminal input'
grep -Fq 'RELEASED_DISARMED' <<<"$PI_CONFIRM_FUNCTION" \
  || fail_test 'Pi manual safety gate lacks an exact confirmation phrase'
PI_CONFIRM_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_confirm_manual_safety_release' 'Pi manual safety confirmation')"
PI_READY_WAIT_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_wait_bridge_ready' 'Pi bridge ready wait')"
[ "$PI_CONFIRM_LINE" -lt "$PI_READY_WAIT_LINE" ] \
  || fail_test 'Pi readiness timer starts before manual safety confirmation'
pass_case

WS_READY_WAIT_LINE="$(line_number_once "$WS_RUN_FUNCTION" \
  'rfcu_ws_wait_bridge_ready' 'workstation ready wait')"
WS_READY_FLAG_LINE="$(line_number_once "$WS_RUN_FUNCTION" \
  'RFCU_WS_READY_REACHED=1' 'workstation ready flag')"
PI_READY_FLAG_LINE="$(line_number_once "$RUN_FUNCTION" \
  'RFCU_PI_READY_REACHED=1' 'Pi ready flag')"
[ -n "$WS_READY_WAIT_LINE" ] && [ -n "$WS_READY_FLAG_LINE" ] \
  && [ -n "$PI_READY_FLAG_LINE" ] \
  && [ "$WS_READY_WAIT_LINE" -lt "$WS_READY_FLAG_LINE" ] \
  || fail_test 'normal-success gates are not wired into both run paths'
pass_case

EXPECTED_PLUGINS=$'sys_status\nparam\nglobal_position\nimu\nrc_io'
ACTUAL_PLUGINS="$(sed -n 's/^      - //p' "$PLUGIN_YAML")"
[ "$ACTUAL_PLUGINS" = "$EXPECTED_PLUGINS" ] \
  || fail_test "closed-loop plugin allowlist changed: $ACTUAL_PLUGINS"
EXPECTED_PROBE_PLUGINS=$'sys_status\nparam'
ACTUAL_PROBE_PLUGINS="$(sed -n 's/^      - //p' "$PROBE_PLUGIN_YAML")"
[ "$ACTUAL_PROBE_PLUGINS" = "$EXPECTED_PROBE_PLUGINS" ] \
  || fail_test "T0b plugin allowlist changed: $ACTUAL_PROBE_PLUGINS"
pass_case

PI_CLEANUP="$(extract_function "$PI_HELPER" rfcu_pi_cleanup)"
PI_BRIDGE_STOP="$(line_number_once "$PI_CLEANUP" \
  'rfcu_pi_stop_child bridge' 'Pi bridge stop')"
PI_MAVROS_STOP="$(line_number_once "$PI_CLEANUP" \
  'rfcu_pi_stop_child mavros ||' 'Pi MAVROS stop')"
PI_WORKSTATION_MARKER="$(line_number_once "$PI_CLEANUP" \
  'rfcu_pi_wait_workstation_stop_marker' 'Pi workstation-stop marker wait')"
[ -n "$PI_BRIDGE_STOP" ] && [ -n "$PI_MAVROS_STOP" ] \
  && [ -n "$PI_WORKSTATION_MARKER" ] \
  && [ "$PI_WORKSTATION_MARKER" -lt "$PI_BRIDGE_STOP" ] \
  && [ "$PI_BRIDGE_STOP" -lt "$PI_MAVROS_STOP" ] \
  || fail_test 'Pi cleanup does not wait for workstation then stop bridge before MAVROS'
! grep -Fq 'rfcu_pi_wait_workstation_nodes_gone' "$PI_HELPER" \
  || fail_test 'Pi cleanup still accepts a negative graph snapshot as shutdown proof'
WS_CLEANUP="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_cleanup)"
WS_FINAL_PROBE="$(line_number_once "$WS_CLEANUP" \
  'rfcu_ws_status_json_once' 'workstation final-state probe')"
WS_DASHBOARD_STOP="$(line_number_once "$WS_CLEANUP" \
  'rfcu_ws_stop_child dashboard' 'workstation dashboard stop')"
WS_ROSBRIDGE_STOP="$(line_number_once "$WS_CLEANUP" \
  'rfcu_ws_stop_child rosbridge' 'workstation rosbridge stop')"
WS_MARKER_PUBLISH="$(line_number_once "$WS_CLEANUP" \
  'rfcu_ws_publish_stop_marker' 'workstation stop-marker publish')"
[ -n "$WS_FINAL_PROBE" ] && [ -n "$WS_DASHBOARD_STOP" ] \
  && [ -n "$WS_ROSBRIDGE_STOP" ] && [ -n "$WS_MARKER_PUBLISH" ] \
  && [ "$WS_FINAL_PROBE" -lt "$WS_DASHBOARD_STOP" ] \
  && [ "$WS_DASHBOARD_STOP" -lt "$WS_ROSBRIDGE_STOP" ] \
  && [ "$WS_ROSBRIDGE_STOP" -lt "$WS_MARKER_PUBLISH" ] \
  || fail_test 'workstation cleanup does not probe, stop children, then publish its marker'
pass_case

WS_PUBLISH_DIR="$TEST_TMP/ws-publish-marker"
WS_PUBLISH_ARGS="$WS_PUBLISH_DIR/timeout.args"
mkdir -p "$WS_PUBLISH_DIR/logs"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_WS_RUN_DIR="$2"
  RFCU_WS_READY_TIMEOUT_SECONDS=7
  RFCU_WS_TEST_TIMEOUT_ARGS="$3"
  timeout() {
    printf "%s\n" "$@" >"$RFCU_WS_TEST_TIMEOUT_ARGS"
  }
  rfcu_ws_publish_stop_marker
' _ "$WORKSTATION_HELPER" "$WS_PUBLISH_DIR" "$WS_PUBLISH_ARGS"
EXPECTED_WS_PUBLISH_ARGS=$'12\nros2\ntopic\npub\n--once\n--wait-matching-subscriptions\n1\n--max-wait-time-secs\n7\n--qos-history\nkeep_last\n--qos-depth\n1\n--qos-reliability\nreliable\n--qos-durability\nvolatile\n/real_fcu/workstation_stop\nstd_msgs/msg/String\n{data: "REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free"}'
[ "$(cat "$WS_PUBLISH_ARGS")" = "$EXPECTED_WS_PUBLISH_ARGS" ] \
  || fail_test 'workstation stop marker is not a bounded reliable volatile publication'
pass_case

PI_CAPTURE_DIR="$TEST_TMP/pi-capture-marker"
PI_CAPTURE_OUTPUT="$PI_CAPTURE_DIR/workstation_stop.yaml"
PI_CAPTURE_ARGS="$PI_CAPTURE_DIR/ros2.args"
PI_CAPTURE_WARNING='test rmw warning'
mkdir -p "$PI_CAPTURE_DIR/logs"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_READY_TIMEOUT_SECONDS=7
  RFCU_PI_TEST_ROS2_ARGS="$4"
  RFCU_PI_TEST_WARNING="$5"
  ros2() {
    printf "%s\n" "$@" >"$RFCU_PI_TEST_ROS2_ARGS"
    printf "data: %s\n---\n" "$RFCU_PI_WORKSTATION_STOP_MESSAGE"
    printf "%s\n" "$RFCU_PI_TEST_WARNING" >&2
  }
  rfcu_pi_capture_workstation_stop_marker "$3"
' _ "$PI_HELPER" "$PI_CAPTURE_DIR" "$PI_CAPTURE_OUTPUT" \
  "$PI_CAPTURE_ARGS" "$PI_CAPTURE_WARNING"
EXPECTED_PI_CAPTURE_ARGS=$'topic\necho\n--once\n--timeout\n7\n--full-length\n--qos-history\nkeep_last\n--qos-depth\n1\n--qos-reliability\nreliable\n--qos-durability\nvolatile\n/real_fcu/workstation_stop\nstd_msgs/msg/String'
[ "$(cat "$PI_CAPTURE_ARGS")" = "$EXPECTED_PI_CAPTURE_ARGS" ] \
  || fail_test 'Pi stop marker is not a bounded reliable volatile subscription'
EXPECTED_PI_CAPTURE_OUTPUT=$'data: REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free\n---'
[ "$(cat "$PI_CAPTURE_OUTPUT")" = "$EXPECTED_PI_CAPTURE_OUTPUT" ] \
  || fail_test 'Pi stop-marker evidence merged stderr into the ROS payload'
grep -Fxq "$PI_CAPTURE_WARNING" \
  "$PI_CAPTURE_DIR/logs/workstation_stop_capture.log" \
  || fail_test 'Pi stop-marker stderr was not retained separately'
bash -c 'source "$1"; rfcu_pi_workstation_stop_marker_file_is_valid "$2"' \
  _ "$PI_HELPER" "$PI_CAPTURE_OUTPUT" \
  || fail_test 'Pi rejected the byte-faithful ROS stop marker'
printf 'data: unexpected\n' >"$PI_CAPTURE_OUTPUT"
set +e
bash -c 'source "$1"; rfcu_pi_workstation_stop_marker_file_is_valid "$2"' \
  _ "$PI_HELPER" "$PI_CAPTURE_OUTPUT" >/dev/null 2>&1
INVALID_MARKER_RC=$?
set -e
[ "$INVALID_MARKER_RC" -ne 0 ] || fail_test 'Pi accepted an unexpected stop marker'
printf 'data: %s\n---\ndata: duplicate\n' \
  'REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free' \
  >"$PI_CAPTURE_OUTPUT"
set +e
bash -c 'source "$1"; rfcu_pi_workstation_stop_marker_file_is_valid "$2"' \
  _ "$PI_HELPER" "$PI_CAPTURE_OUTPUT" >/dev/null 2>&1
DUPLICATE_MARKER_RC=$?
set -e
[ "$DUPLICATE_MARKER_RC" -ne 0 ] || fail_test 'Pi accepted duplicate stop markers'
pass_case

run_ws_operator_stop_case() {
  local case_dir="$1" ready_reached="$2" cached_disarmed="$3"
  local final_state="$4" cleanup_ok="${5:-1}" children_alive="${6:-1}"
  local marker_ok="${7:-1}"
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_WS_RUN_DIR="$2"
    mkdir -p "$RFCU_WS_RUN_DIR/evidence"
    RFCU_WS_SUPERVISOR_LOG="$RFCU_WS_RUN_DIR/supervisor.log"
    : >"$RFCU_WS_SUPERVISOR_LOG"
    RFCU_WS_CLEANING=0
    RFCU_WS_STARTED=1
    RFCU_WS_READY_REACHED="$3"
    RFCU_WS_FINAL_DISARMED="$4"
    RFCU_WS_OPERATOR_STOP_REQUESTED=0
    RFCU_WS_TEST_FINAL_STATE="$5"
    RFCU_WS_TEST_CLEANUP_OK="$6"
    RFCU_WS_TEST_CHILDREN_ALIVE="$7"
    RFCU_WS_TEST_MARKER_OK="$8"
    rfcu_ws_status_json_once() {
      case "$RFCU_WS_TEST_FINAL_STATE" in
        disarmed)
          printf "%s\n" "{\"state\":\"READY_DISARMED\",\"connected\":true,\"armed\":false,\"mode\":\"MANUAL\",\"feedback_fresh\":true}"
          ;;
        emergency-stop)
          printf "%s\n" "{\"state\":\"EMERGENCY_STOP\",\"connected\":true,\"armed\":false,\"mode\":\"MANUAL\",\"feedback_fresh\":true}"
          ;;
        armed)
          printf "%s\n" "{\"state\":\"ACTIVE\",\"connected\":true,\"armed\":true,\"mode\":\"MANUAL\",\"feedback_fresh\":true}"
          ;;
        missing) return 1 ;;
        *) return 2 ;;
      esac
    }
    rfcu_ws_stop_child() {
      printf "%s\n" "$1" >>"$RFCU_WS_RUN_DIR/stop.trace"
      return 0
    }
    rfcu_ws_children_alive() {
      [ "$RFCU_WS_TEST_CHILDREN_ALIVE" -eq 1 ]
    }
    rfcu_ws_loopback_listener_ready() {
      [ "$RFCU_WS_TEST_CLEANUP_OK" -eq 0 ] && return 0
      return 1
    }
    rfcu_ws_publish_stop_marker() {
      [ "$RFCU_WS_TEST_MARKER_OK" -eq 1 ]
    }
    trap rfcu_ws_cleanup EXIT
    trap rfcu_ws_on_interrupt INT
    kill -INT "$$"
  ' _ "$WORKSTATION_HELPER" "$case_dir" "$ready_reached" "$cached_disarmed" \
    "$final_state" "$cleanup_ok" "$children_alive" "$marker_ok"
}

run_pi_operator_stop_case() {
  local case_dir="$1" ready_reached="$2" bridge_started="$3"
  local final_disarmed="$4" cleanup_ok="${5:-1}"
  local workstation_marker="${6:-1}"
  local run_mode="${7:-run}"
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_DIR="$2"
    mkdir -p "$RFCU_PI_RUN_DIR/evidence"
    RFCU_PI_SUPERVISOR_LOG="$RFCU_PI_RUN_DIR/supervisor.log"
    : >"$RFCU_PI_SUPERVISOR_LOG"
    RFCU_PI_RUN_MODE="$8"
    RFCU_PI_CLEANING=0
    RFCU_PI_READY_REACHED="$3"
    RFCU_PI_BRIDGE_STARTED="$4"
    RFCU_PI_OPERATOR_STOP_REQUESTED=0
    RFCU_PI_TEST_FINAL_DISARMED="$5"
    RFCU_PI_TEST_CLEANUP_OK="$6"
    RFCU_PI_TEST_WORKSTATION_MARKER="$7"
    rfcu_pi_capture_topic() {
      : >"$3"
      return 0
    }
    rfcu_pi_state_file_is_connected_disarmed() {
      [ "$RFCU_PI_TEST_FINAL_DISARMED" -eq 1 ]
    }
    rfcu_pi_stop_child() {
      printf "%s\n" "$1" >>"$RFCU_PI_RUN_DIR/stop.trace"
      return 0
    }
    rfcu_pi_serial_is_free() {
      [ "$RFCU_PI_TEST_CLEANUP_OK" -eq 1 ]
    }
    rfcu_pi_capture_workstation_stop_marker() {
      if [ "$RFCU_PI_TEST_WORKSTATION_MARKER" -eq 1 ]; then
        printf "data: %s\n---\n" "$RFCU_PI_WORKSTATION_STOP_MESSAGE" >"$1"
      else
        printf "data: unexpected\n---\n" >"$1"
      fi
    }
    ros2() {
      if [ "${1:-}:${2:-}" = node:list ]; then
        printf 'node-list\n' >>"$RFCU_PI_RUN_DIR/graph.trace"
        printf "%s\n" /mavros
        return 0
      fi
      return 1
    }
    trap rfcu_pi_cleanup EXIT
    trap rfcu_pi_on_interrupt INT
    kill -INT "$$"
  ' _ "$PI_HELPER" "$case_dir" "$ready_reached" "$bridge_started" \
    "$final_disarmed" "$cleanup_ok" "$workstation_marker" "$run_mode"
}

set +e
WS_EARLY_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-early" 0 1 disarmed 2>&1)"
WS_EARLY_RC=$?
WS_ARMED_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-armed" 1 0 armed 2>&1)"
WS_ARMED_RC=$?
WS_STALE_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-stale" 1 1 missing 2>&1)"
WS_STALE_RC=$?
PI_EARLY_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-operator-early" 0 0 1 2>&1)"
PI_EARLY_RC=$?
PI_ARMED_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-operator-armed" 1 1 0 2>&1)"
PI_ARMED_RC=$?
WS_CLEANUP_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-cleanup-fail" 1 1 disarmed 0 2>&1)"
WS_CLEANUP_RC=$?
WS_CHILD_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-child-fail" 1 1 disarmed 1 0 2>&1)"
WS_CHILD_RC=$?
WS_MARKER_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-marker-fail" 1 1 disarmed 1 1 0 2>&1)"
WS_MARKER_RC=$?
PI_CLEANUP_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-operator-cleanup-fail" 1 1 1 0 2>&1)"
PI_CLEANUP_RC=$?
PI_COORDINATION_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-operator-coordination-fail" 1 1 1 1 0 2>&1)"
PI_COORDINATION_RC=$?
set -e
[ "$WS_EARLY_RC" -eq 130 ] \
  || fail_test "early workstation operator stop returned $WS_EARLY_RC: $WS_EARLY_OUTPUT"
[ "$WS_ARMED_RC" -eq 130 ] \
  || fail_test "armed workstation operator stop returned $WS_ARMED_RC: $WS_ARMED_OUTPUT"
[ "$WS_STALE_RC" -eq 130 ] \
  || fail_test "stale workstation operator stop returned $WS_STALE_RC: $WS_STALE_OUTPUT"
[ "$PI_EARLY_RC" -eq 130 ] \
  || fail_test "early Pi operator stop returned $PI_EARLY_RC: $PI_EARLY_OUTPUT"
[ "$PI_ARMED_RC" -eq 130 ] \
  || fail_test "armed Pi operator stop returned $PI_ARMED_RC: $PI_ARMED_OUTPUT"
[ "$WS_CLEANUP_RC" -eq 130 ] \
  || fail_test "workstation cleanup failure returned $WS_CLEANUP_RC: $WS_CLEANUP_OUTPUT"
[ "$WS_CHILD_RC" -eq 130 ] \
  || fail_test "workstation child failure returned $WS_CHILD_RC: $WS_CHILD_OUTPUT"
[ "$WS_MARKER_RC" -eq 130 ] \
  || fail_test "workstation marker failure returned $WS_MARKER_RC: $WS_MARKER_OUTPUT"
[ "$PI_CLEANUP_RC" -eq 130 ] \
  || fail_test "Pi cleanup failure returned $PI_CLEANUP_RC: $PI_CLEANUP_OUTPUT"
[ "$PI_COORDINATION_RC" -eq 130 ] \
  || fail_test "Pi coordination failure returned $PI_COORDINATION_RC: $PI_COORDINATION_OUTPUT"
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=0' \
  <<<"$WS_EARLY_OUTPUT" || fail_test 'early workstation stop lost status 130'
grep -Fq 'REAL_FCU_WORKSTATION_FINAL_STATE=FAIL expected=connected,disarmed' \
  <<<"$WS_ARMED_OUTPUT" || fail_test 'armed workstation state was not rejected'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=1' \
  <<<"$WS_ARMED_OUTPUT" || fail_test 'armed workstation stop lost status 130'
grep -Fq 'REAL_FCU_WORKSTATION_FINAL_STATE=FAIL expected=connected,disarmed' \
  <<<"$WS_STALE_OUTPUT" || fail_test 'missing workstation state was not rejected'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=1' \
  <<<"$WS_STALE_OUTPUT" || fail_test 'stale workstation state passed cleanup'
grep -Fq 'REAL_FCU_PI_EXIT status=130 cleanup_rc=0' \
  <<<"$PI_EARLY_OUTPUT" || fail_test 'early Pi stop lost status 130'
grep -Fq 'REAL_FCU_FINAL_STATE=FAIL expected=connected,disarmed' \
  <<<"$PI_ARMED_OUTPUT" || fail_test 'armed Pi stop did not reject final state'
grep -Fq 'REAL_FCU_PI_EXIT status=130 cleanup_rc=1' \
  <<<"$PI_ARMED_OUTPUT" || fail_test 'armed Pi stop did not retain failure status'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=1' \
  <<<"$WS_CLEANUP_OUTPUT" || fail_test 'occupied workstation port passed cleanup'
grep -Fq 'REAL_FCU_WORKSTATION_CHILDREN=FAIL expected=alive-before-stop' \
  <<<"$WS_CHILD_OUTPUT" || fail_test 'workstation child failure was not reported'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=1' \
  <<<"$WS_CHILD_OUTPUT" || fail_test 'workstation child failure passed cleanup'
grep -Fq 'REAL_FCU_WORKSTATION_STOP_MARKER=FAIL topic=/real_fcu/workstation_stop' \
  <<<"$WS_MARKER_OUTPUT" || fail_test 'workstation marker failure was not reported'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=1' \
  <<<"$WS_MARKER_OUTPUT" || fail_test 'workstation marker failure passed cleanup'
grep -Fq 'REAL_FCU_PI_EXIT status=130 cleanup_rc=1' \
  <<<"$PI_CLEANUP_OUTPUT" || fail_test 'occupied Pi serial endpoint passed cleanup'
grep -Fq 'REAL_FCU_PI_EXIT status=130 cleanup_rc=1' \
  <<<"$PI_COORDINATION_OUTPUT" || fail_test 'Pi passed before workstation shutdown'
grep -Fq 'REAL_FCU_WORKSTATION_STOP=FAIL marker=missing-or-invalid' \
  <<<"$PI_COORDINATION_OUTPUT" || fail_test 'Pi coordination failure was not reported'
[ ! -e "$TEST_TMP/pi-operator-coordination-fail/graph.trace" ] \
  || fail_test 'Pi coordination still queried graph absence during cleanup'
pass_case

set +e
WS_OPERATOR_OUTPUT="$(run_ws_operator_stop_case \
  "$TEST_TMP/ws-operator-success" 1 1 disarmed 2>&1)"
WS_OPERATOR_RC=$?
PI_OPERATOR_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-operator-success" 1 1 1 2>&1)"
PI_OPERATOR_RC=$?
PI_T2A_OPERATOR_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-t2a-operator-success" 1 1 1 1 1 run-t2a 2>&1)"
PI_T2A_OPERATOR_RC=$?
set -e
[ "$WS_OPERATOR_RC" -eq 0 ] && [ "$PI_OPERATOR_RC" -eq 0 ] \
  || fail_test "normal operator stop remained non-zero: workstation=$WS_OPERATOR_RC Pi=$PI_OPERATOR_RC workstation_output=[$WS_OPERATOR_OUTPUT] Pi_output=[$PI_OPERATOR_OUTPUT]"
[ "$PI_T2A_OPERATOR_RC" -eq 0 ] \
  || fail_test "T2a operator stop remained non-zero: $PI_T2A_OPERATOR_OUTPUT"
grep -Fq 'operator stop requested' <<<"$WS_OPERATOR_OUTPUT" \
  || fail_test 'workstation operator-stop handler did not run'
grep -Fq 'operator stop requested' <<<"$PI_OPERATOR_OUTPUT" \
  || fail_test 'Pi operator-stop handler did not run'
grep -Fq 'REAL_FCU_WORKSTATION_FINAL_STATE=PASS connected=true armed=false' \
  <<<"$WS_OPERATOR_OUTPUT" || fail_test 'workstation lost fresh final disarmed state'
grep -Fq 'REAL_FCU_WORKSTATION_EXIT status=0 cleanup_rc=0' \
  <<<"$WS_OPERATOR_OUTPUT" || fail_test 'workstation operator stop did not pass'
grep -Fq 'REAL_FCU_WORKSTATION_STOP_MARKER=PASS topic=/real_fcu/workstation_stop' \
  <<<"$WS_OPERATOR_OUTPUT" || fail_test 'workstation did not publish its stop marker'
grep -Fq 'REAL_FCU_FINAL_STATE=PASS connected=true armed=false' \
  <<<"$PI_OPERATOR_OUTPUT" || fail_test 'Pi operator stop lost final disarmed state'
grep -Fq 'REAL_FCU_PI_EXIT status=0 cleanup_rc=0' \
  <<<"$PI_OPERATOR_OUTPUT" || fail_test 'Pi operator stop did not pass'
grep -Fq 'REAL_FCU_PI_EXIT status=0 cleanup_rc=0' \
  <<<"$PI_T2A_OPERATOR_OUTPUT" || fail_test 'T2a operator stop did not pass'
grep -Fq 'REAL_FCU_WORKSTATION_STOP=PASS marker=received topic=/real_fcu/workstation_stop' \
  <<<"$PI_OPERATOR_OUTPUT" || fail_test 'Pi did not retain workstation shutdown'
grep -Fq 'REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free' \
  "$TEST_TMP/pi-operator-success/evidence/workstation_stop.yaml" \
  || fail_test 'Pi workstation-stop artifact is missing the exact marker'
grep -Fq '"armed":false' \
  "$TEST_TMP/ws-operator-success/evidence/final_status.json" \
  || fail_test 'workstation final status artifact is missing disarmed state'
[ "$(cat "$TEST_TMP/ws-operator-success/stop.trace")" = $'dashboard\nrosbridge' ] \
  || fail_test 'workstation operator-stop order changed'
[ "$(cat "$TEST_TMP/pi-operator-success/stop.trace")" = \
    $'bridge\nmavros\nmavros-probe' ] \
  || fail_test 'Pi operator-stop order changed'
pass_case

printf '%s  %s\n' "$EXPECTED_VIEW_ONLY_SHA256" "$VIEW_ONLY_HELPER" | sha256sum -c - \
  >/dev/null || fail_test 'existing Pi view-only helper changed'
! grep -Fq 'real_fcu_digital_twin_pi.sh' "$VIEW_ONLY_HELPER" \
  || fail_test 'existing Pi view-only helper imports the command helper'
pass_case

EXPECTED_BUNDLE_PATHS=$'tools/real_fcu_digital_twin_pi.sh\ntools/real_fcu_rc_command_bridge.py\nconfig/mavros_real_fcu_closed_loop_plugins.yaml\nconfig/mavros_real_fcu_t0b_plugins.yaml'
ACTUAL_BUNDLE_PATHS="$(awk '{print $2}' "$BUNDLE_MANIFEST")"
[ "$ACTUAL_BUNDLE_PATHS" = "$EXPECTED_BUNDLE_PATHS" ] \
  || fail_test "Pi bundle manifest paths changed: $ACTUAL_BUNDLE_PATHS"
( cd "$REPO_ROOT" && sha256sum -c "$BUNDLE_MANIFEST" ) >/dev/null \
  || fail_test 'Pi bundle manifest does not match repository bytes'
grep -Fq 'rfcu_pi_verify_bundle' "$PI_HELPER" \
  || fail_test 'Pi preflight does not verify the deployed bundle'
pass_case

DEPLOYED_BUNDLE="$TEST_TMP/deployed_bundle"
mkdir -p "$DEPLOYED_BUNDLE/tools" "$DEPLOYED_BUNDLE/config"
cp "$PI_HELPER" "$DEPLOYED_BUNDLE/tools/real_fcu_digital_twin_pi.sh"
cp "$SCRIPT_DIR/real_fcu_rc_command_bridge.py" \
  "$DEPLOYED_BUNDLE/tools/real_fcu_rc_command_bridge.py"
cp "$PLUGIN_YAML" "$DEPLOYED_BUNDLE/config/mavros_real_fcu_closed_loop_plugins.yaml"
cp "$PROBE_PLUGIN_YAML" "$DEPLOYED_BUNDLE/config/mavros_real_fcu_t0b_plugins.yaml"
cp "$BUNDLE_MANIFEST" "$DEPLOYED_BUNDLE/config/real_fcu_digital_twin_bundle.sha256"
bash -c 'source "$1"; rfcu_pi_verify_bundle' \
  _ "$DEPLOYED_BUNDLE/tools/real_fcu_digital_twin_pi.sh" >/dev/null \
  || fail_test 'copied Pi bundle did not validate from its deployed layout'
pass_case

printf 'PASS cases=%d\n' "$CASE_COUNT"
