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
EXPECTED_VIEW_ONLY_SHA256='a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97'
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

[ -r "$WORKSTATION_HELPER" ] \
  || fail_test "workstation helper missing: $WORKSTATION_HELPER"
[ -r "$PI_HELPER" ] || fail_test "Pi helper missing: $PI_HELPER"
[ -r "$PLUGIN_YAML" ] || fail_test "plugin YAML missing: $PLUGIN_YAML"
[ -r "$PROBE_PLUGIN_YAML" ] \
  || fail_test "T0b plugin YAML missing: $PROBE_PLUGIN_YAML"
[ -r "$BUNDLE_MANIFEST" ] \
  || fail_test "Pi bundle manifest missing: $BUNDLE_MANIFEST"
bash -n "$WORKSTATION_HELPER"
bash -n "$PI_HELPER"
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
grep -Fq 'check|probe|run' <<<"$PI_USAGE" \
  || fail_test 'Pi usage does not expose check, probe and run'
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
  rfcu_pi_build_commands
  printf "WS_ROSBRIDGE=%s\n" "${RFCU_WS_ROSBRIDGE_COMMAND[*]}"
  printf "WS_DASHBOARD=%s\n" "${RFCU_WS_DASHBOARD_COMMAND[*]}"
  printf "PI_MAVROS=%s\n" "${RFCU_PI_MAVROS_COMMAND[*]}"
  printf "PI_PROBE_MAVROS=%s\n" "${RFCU_PI_PROBE_MAVROS_COMMAND[*]}"
  printf "PI_BRIDGE=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
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
pass_case

T0B_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_capture_t0b)"
[ -n "$T0B_FUNCTION" ] || fail_test 'T0b capture function is missing'
for literal in \
  '/mavros/state' \
  '/mavros/sys_status' \
  '/mavros/param/pull' \
  'mavros_msgs/srv/ParamPull' \
  'force_pull: true' \
  'BRD_SAFETY_DEFLT' \
  'BRD_SAFETY_MASK' \
  'BRD_SAFETYOPTION' \
  '32768'; do
  grep -Fq "$literal" <<<"$T0B_FUNCTION" \
    || fail_test "T0b capture is missing: $literal"
done
! grep -Eiq 'param(eter)?[_ -]?set|set_mode|arming|motor.test|rc.override|create_publisher|publish\(' \
  <<<"$T0B_FUNCTION" || fail_test 'T0b capture contains a forbidden write path'

RUN_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_run)"
PROBE_START_LINE="$(grep -n 'rfcu_pi_start_child mavros-probe' <<<"$RUN_FUNCTION" | cut -d: -f1)"
T0B_LINE="$(grep -n 'rfcu_pi_capture_t0b' <<<"$RUN_FUNCTION" | cut -d: -f1)"
PROBE_STOP_LINE="$(grep -n 'rfcu_pi_stop_child mavros-probe' <<<"$RUN_FUNCTION" | cut -d: -f1)"
MAVROS_LINE="$(grep -n 'rfcu_pi_start_child mavros ' <<<"$RUN_FUNCTION" | cut -d: -f1)"
BRIDGE_LINE="$(grep -n 'rfcu_pi_start_child bridge' <<<"$RUN_FUNCTION" | cut -d: -f1)"
[ -n "$PROBE_START_LINE" ] && [ -n "$T0B_LINE" ] && [ -n "$PROBE_STOP_LINE" ] \
  && [ -n "$MAVROS_LINE" ] && [ -n "$BRIDGE_LINE" ] \
  && [ "$PROBE_START_LINE" -lt "$T0B_LINE" ] \
  && [ "$T0B_LINE" -lt "$PROBE_STOP_LINE" ] \
  && [ "$PROBE_STOP_LINE" -lt "$MAVROS_LINE" ] \
  && [ "$MAVROS_LINE" -lt "$BRIDGE_LINE" ] \
  || fail_test 'run does not separate T0b from the full MAVROS/bridge session'
pass_case

READY_STATUS='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}'
BENCH_URL="$(bash -c 'source "$1"; rfcu_ws_bench_url_from_status "$2"' \
  _ "$WORKSTATION_HELPER" "$READY_STATUS")"
[ "$BENCH_URL" = 'http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=3&thrust_right_servo=1' ] \
  || fail_test "workstation helper emitted an unexpected bench URL: $BENCH_URL"
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
PI_BRIDGE_STOP="$(grep -n 'rfcu_pi_stop_child bridge' <<<"$PI_CLEANUP" | cut -d: -f1)"
PI_MAVROS_STOP="$(grep -n 'rfcu_pi_stop_child mavros ||' <<<"$PI_CLEANUP" | cut -d: -f1)"
[ -n "$PI_BRIDGE_STOP" ] && [ -n "$PI_MAVROS_STOP" ] \
  && [ "$PI_BRIDGE_STOP" -lt "$PI_MAVROS_STOP" ] \
  || fail_test 'Pi cleanup does not stop the bridge before MAVROS'
WS_CLEANUP="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_cleanup)"
WS_DASHBOARD_STOP="$(grep -n 'rfcu_ws_stop_child dashboard' <<<"$WS_CLEANUP" | cut -d: -f1)"
WS_ROSBRIDGE_STOP="$(grep -n 'rfcu_ws_stop_child rosbridge' <<<"$WS_CLEANUP" | cut -d: -f1)"
[ -n "$WS_DASHBOARD_STOP" ] && [ -n "$WS_ROSBRIDGE_STOP" ] \
  && [ "$WS_DASHBOARD_STOP" -lt "$WS_ROSBRIDGE_STOP" ] \
  || fail_test 'workstation cleanup does not stop dashboard before rosbridge'
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
