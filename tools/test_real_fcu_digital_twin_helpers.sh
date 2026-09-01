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
EXPECTED_VIEW_ONLY_SHA256='0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9'
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
grep -Fq 'check|probe|probe-snapshot SNAPSHOT SHA256|run-t2a|run|run-t3a' \
  <<<"$PI_USAGE" \
  || fail_test 'Pi usage does not expose the distinct T2a and T3a runs'
grep -Fq '1:run-t2a) rfcu_pi_run run-t2a' "$PI_HELPER" \
  || fail_test 'Pi main does not dispatch the T2a-only run'
grep -Fq '1:run) rfcu_pi_run run' "$PI_HELPER" \
  || fail_test 'Pi main does not dispatch the T2b run'
grep -Fq '1:run-t3a) rfcu_pi_run run-t3a' "$PI_HELPER" \
  || fail_test 'Pi main does not dispatch the props-fitted T3a run'
grep -Fq '3:probe-snapshot) rfcu_pi_probe_snapshot "$2" "$3"' "$PI_HELPER" \
  || fail_test 'Pi main does not dispatch the snapshot-backed T0b probe'
pass_case

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT
ROS_FIXTURE="$TEST_TMP/ros_setup.bash"
: >"$ROS_FIXTURE"

PI_HAILO_WRAPPER="$TEST_TMP/hailo_person_stop_bridge.py"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_HAILO_WRAPPER="$2"
  rfcu_pi_write_hailo_wrapper
' _ "$PI_HELPER" "$PI_HAILO_WRAPPER" \
  || fail_test 'Pi helper cannot generate the Hailo person-stop bridge'
/usr/bin/python3 -m py_compile "$PI_HAILO_WRAPPER" \
  || fail_test 'generated Hailo person-stop bridge is not valid Python'
grep -Fq 'postprocess.extract_detections' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo bridge does not use the pinned detector post-process API'
grep -Fq '"/perception/detections"' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo bridge does not publish structured detections'
grep -Fq '"/hailo/overlay/image_raw"' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo bridge does not publish its annotated image'
grep -Fq 'name="hailo-thermal-supervisor"' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo bridge has no frame-independent thermal supervisor'
grep -Fq 'HAILO_PERSON_STOP_THERMAL_ABORT' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo thermal supervisor has no explicit abort marker'
! grep -Eiq 'ttyAMA0|mavproxy|serial://|udp(out)?://' "$PI_HAILO_WRAPPER" \
  || fail_test 'Hailo bridge tries to own or relay the FCU serial path'
pass_case

PI_HAILO_COMMANDS="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_RUN_DIR="$2/pi-hailo-command"
  RFCU_PI_HAILO_WRAPPER="$RFCU_PI_RUN_DIR/hailo_person_stop_bridge.py"
  RFCU_PI_HAILO_PERSON_STOP=1
  rfcu_pi_build_commands
  printf "bridge\n"
  printf "%s\n" "${RFCU_PI_BRIDGE_COMMAND[@]}"
  printf "hailo\n"
  printf "%s\n" "${RFCU_PI_HAILO_COMMAND[@]}"
' _ "$PI_HELPER" "$TEST_TMP")" \
  || fail_test 'Pi helper cannot build the opt-in Hailo command'
grep -Fxq 'PYTHONUNBUFFERED=1' <<<"$PI_HAILO_COMMANDS" \
  || fail_test 'Pi Hailo command does not force unbuffered evidence output'
grep -Fxq 'require_person_alert:=true' <<<"$PI_HAILO_COMMANDS" \
  || fail_test 'opt-in Pi bridge does not require a fresh person-alert feed'
grep -Fq 'hailo_person_stop_bridge.py' <<<"$PI_HAILO_COMMANDS" \
  || fail_test 'Pi Hailo command does not launch its generated wrapper'
grep -Fxq -- '--no-display' <<<"$PI_HAILO_COMMANDS" \
  || fail_test 'Pi Hailo command unexpectedly requires a local display'
! grep -Eiq 'ttyAMA0|mavproxy|serial://|udp(out)?://' <<<"$PI_HAILO_COMMANDS" \
  || fail_test 'Pi Hailo command duplicates FCU serial or relay ownership'
pass_case

DEFAULT_PI_HAILO_COMMANDS="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_HAILO_PERSON_STOP=0
  rfcu_pi_build_commands
  printf "%s\n" "${#RFCU_PI_HAILO_COMMAND[@]}"
' _ "$PI_HELPER")" \
  || fail_test 'Pi helper cannot build its default command set'
[ "$DEFAULT_PI_HAILO_COMMANDS" = 0 ] \
  || fail_test "default Pi path started Hailo: $DEFAULT_PI_HAILO_COMMANDS"
DEFAULT_PI_BRIDGE_COMMAND="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_HAILO_PERSON_STOP=0
  rfcu_pi_build_commands
  printf "%s\n" "${RFCU_PI_BRIDGE_COMMAND[@]}"
' _ "$PI_HELPER")" \
  || fail_test 'Pi helper cannot build its default bridge command'
! grep -Fq 'require_person_alert' <<<"$DEFAULT_PI_BRIDGE_COMMAND" \
  || fail_test 'default Pi bridge started requiring an unavailable camera feed'
pass_case

PI_DEFAULT_CONFLICT_TRACE="$TEST_TMP/pi_default_conflicts.txt"
PI_HAILO_CONFLICT_TRACE="$TEST_TMP/pi_hailo_conflicts.txt"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_HAILO_PERSON_STOP="$2"
  TRACE="$3"
  pgrep() { printf "%s\n" "$3" >>"$TRACE"; return 1; }
  rfcu_pi_reject_conflicts
' _ "$PI_HELPER" 0 "$PI_DEFAULT_CONFLICT_TRACE" \
  || fail_test 'default Pi conflict guard failed under its focused fixture'
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_HAILO_PERSON_STOP="$2"
  TRACE="$3"
  pgrep() { printf "%s\n" "$3" >>"$TRACE"; return 1; }
  rfcu_pi_reject_conflicts
' _ "$PI_HELPER" 1 "$PI_HAILO_CONFLICT_TRACE" \
  || fail_test 'opt-in Pi conflict guard failed under its focused fixture'
[ "$(cat "$PI_DEFAULT_CONFLICT_TRACE")" = \
    $'mavros_node\nreal_fcu_rc_command_bridge.py\npi_live_hailo_mavlink_dashboard.sh' ] \
  || fail_test 'default Pi conflict guard changed when Hailo is disabled'
[ "$(cat "$PI_HAILO_CONFLICT_TRACE")" = \
    $'mavros_node\nreal_fcu_rc_command_bridge.py\npi_live_hailo_mavlink_dashboard.sh\nhailo_person_stop_bridge.py' ] \
  || fail_test 'opt-in Pi conflict guard omitted its Hailo owner'
pass_case

PI_STATIC_PREFLIGHT="$(extract_function "$PI_HELPER" rfcu_pi_static_preflight)"
PI_ROS_SETUP_LINE="$(line_number_once "$PI_STATIC_PREFLIGHT" \
  'rfcu_pi_configure_ros_environment' 'Pi ROS environment setup')"
PI_HAILO_PREFLIGHT_LINE="$(line_number_once "$PI_STATIC_PREFLIGHT" \
  'rfcu_pi_validate_hailo_preflight' 'Pi Hailo preflight')"
[ "$PI_ROS_SETUP_LINE" -lt "$PI_HAILO_PREFLIGHT_LINE" ] \
  || fail_test 'Pi validates Hailo ROS imports before sourcing the ROS environment'
PI_HAILO_PREFLIGHT="$(extract_function "$PI_HELPER" \
  rfcu_pi_validate_hailo_preflight)"
grep -Fq 'HAILO_APPS_REPO="$RFCU_PI_HAILO_REPO"' \
  <<<"$PI_HAILO_PREFLIGHT" \
  || fail_test 'Pi Hailo provenance check does not export its canonical repo root'
grep -Fq -- '--ignore-submodules=none' <<<"$PI_HAILO_PREFLIGHT" \
  || fail_test 'Pi Hailo clean-tree check ignores submodule drift'
grep -Fq 'run_inference_pipeline.__globals__["visualize"]' \
  <<<"$PI_HAILO_PREFLIGHT" \
  || fail_test 'Pi Hailo preflight does not prove the visualization hook is reachable'
pass_case

HAILO_COMMANDS="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_WS_HAILO_PERSON_STOP=1
  rfcu_ws_build_commands
  printf "person-monitor"
  printf "\t%q" "${RFCU_WS_PERSON_MONITOR_COMMAND[@]}"
  printf "\nweb-video"
  printf "\t%q" "${RFCU_WS_WEB_VIDEO_COMMAND[@]}"
' _ "$WORKSTATION_HELPER")" \
  || fail_test 'workstation cannot build the opt-in Hailo commands'
grep -Fq 'person_class:=person' <<<"$HAILO_COMMANDS" \
  || fail_test 'person-stop monitor does not select only the person class'
grep -Fq 'require_detection_feed:=true' <<<"$HAILO_COMMANDS" \
  || fail_test 'physical person-stop monitor is not fail-closed on feed loss'
grep -Fq 'latch_emergency_stop:=true' <<<"$HAILO_COMMANDS" \
  || fail_test 'person-stop monitor does not raise the authoritative E-stop'
grep -Fq 'web_video_server' <<<"$HAILO_COMMANDS" \
  || fail_test 'workstation does not expose the annotated Hailo image'
grep -Fq 'address:=127.0.0.1' <<<"$HAILO_COMMANDS" \
  || fail_test 'Hailo video service is not loopback-only'
pass_case

DEFAULT_HAILO_COMMANDS="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_WS_HAILO_PERSON_STOP=0
  rfcu_ws_build_commands
  printf "%s|%s\n" "${#RFCU_WS_PERSON_MONITOR_COMMAND[@]}" \
    "${#RFCU_WS_WEB_VIDEO_COMMAND[@]}"
' _ "$WORKSTATION_HELPER")" \
  || fail_test 'workstation cannot build its default commands'
[ "$DEFAULT_HAILO_COMMANDS" = '0|0' ] \
  || fail_test "default workstation path started Hailo services: $DEFAULT_HAILO_COMMANDS"
pass_case

WS_HAILO_SERVICE_TRACE="$TEST_TMP/ws_hailo_service_trace.txt"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_WS_HAILO_PERSON_STOP=1
  RFCU_WS_POLL_SECONDS=1
  TRACE="$2"
  rfcu_ws_children_alive() { return 0; }
  rfcu_ws_loopback_listener_ready() { printf "%s\n" "$1" >>"$TRACE"; }
  curl() { return 0; }
  rfcu_ws_wait_local_services
  printf "%s\n" video >>"$TRACE"
  rfcu_ws_wait_video_service
' _ "$WORKSTATION_HELPER" "$WS_HAILO_SERVICE_TRACE" \
  || fail_test 'workstation Hailo service gates failed under their focused fixture'
[ "$(cat "$WS_HAILO_SERVICE_TRACE")" = $'9090\n8002\nvideo\n8080' ] \
  || fail_test 'workstation tried to bind video before the detection gate'
pass_case

HAILO_VALID_DETECTIONS="$TEST_TMP/hailo_valid_detections.json"
HAILO_NON_PERSON_DETECTIONS="$TEST_TMP/hailo_non_person_detections.json"
HAILO_INVALID_SCORE="$TEST_TMP/hailo_invalid_score.json"
HAILO_CLEAR_ALERT="$TEST_TMP/hailo_clear_alert.json"
HAILO_PERSON_ALERT="$TEST_TMP/hailo_person_alert.json"
HAILO_FEED_LOST_ALERT="$TEST_TMP/hailo_feed_lost_alert.json"
printf '%s\n' '{"stamp":1.0,"detections":[{"label":"person","score":0.75}]}' \
  >"$HAILO_VALID_DETECTIONS"
printf '%s\n' '{"stamp":1.0,"detections":[{"label":"boat","score":0.75}]}' \
  >"$HAILO_NON_PERSON_DETECTIONS"
printf '%s\n' '{"stamp":1.0,"detections":[{"label":"person","score":true}]}' \
  >"$HAILO_INVALID_SCORE"
printf '%s\n' \
  '{"person_detected":false,"feed_fresh":true,"reason":""}' \
  >"$HAILO_CLEAR_ALERT"
printf '%s\n' \
  '{"person_detected":true,"feed_fresh":true,"reason":"person_detected"}' \
  >"$HAILO_PERSON_ALERT"
printf '%s\n' \
  '{"person_detected":true,"feed_fresh":false,"reason":"detector_feed_lost"}' \
  >"$HAILO_FEED_LOST_ALERT"
for helper in "$WORKSTATION_HELPER" "$PI_HELPER"; do
  case "$helper" in
    "$WORKSTATION_HELPER") prefix=rfcu_ws ;;
    "$PI_HELPER") prefix=rfcu_pi ;;
  esac
  bash -c 'source "$1"; "$2_hailo_detection_file_is_valid" "$3"' \
    _ "$helper" "$prefix" "$HAILO_VALID_DETECTIONS" \
    || fail_test "$prefix rejected a valid person-only detection frame"
  if bash -c 'source "$1"; "$2_hailo_detection_file_is_valid" "$3"' \
      _ "$helper" "$prefix" "$HAILO_NON_PERSON_DETECTIONS"; then
    fail_test "$prefix accepted a non-person detection from the Pi wrapper"
  fi
  if bash -c 'source "$1"; "$2_hailo_detection_file_is_valid" "$3"' \
      _ "$helper" "$prefix" "$HAILO_INVALID_SCORE"; then
    fail_test "$prefix accepted a boolean detection score"
  fi
  bash -c 'source "$1"; "$2_person_alert_file_is_initial_clear" "$3"' \
    _ "$helper" "$prefix" "$HAILO_CLEAR_ALERT" \
    || fail_test "$prefix rejected a fresh-clear person alert"
  if bash -c 'source "$1"; "$2_person_alert_file_is_initial_clear" "$3"' \
      _ "$helper" "$prefix" "$HAILO_PERSON_ALERT"; then
    fail_test "$prefix accepted a person obstacle as initial clear"
  fi
  if bash -c 'source "$1"; "$2_person_alert_file_is_initial_clear" "$3"' \
      _ "$helper" "$prefix" "$HAILO_FEED_LOST_ALERT"; then
    fail_test "$prefix accepted detector feed loss as initial clear"
  fi
done
pass_case

HAILO_SOURCE_EXPECTED="$TEST_TMP/hailo_source_expected.txt"
HAILO_SOURCE_WRONG="$TEST_TMP/hailo_source_wrong.txt"
HAILO_SOURCE_DUPLICATE="$TEST_TMP/hailo_source_duplicate.txt"
HAILO_SOURCE_UNKNOWN="$TEST_TMP/hailo_source_unknown.txt"
HAILO_SOURCE_ZERO="$TEST_TMP/hailo_source_zero.txt"
printf '%s\n' \
  'Type: std_msgs/msg/String' \
  'Publisher count: 1' \
  'Node name: hailo_person_stop_bridge' \
  'Node namespace: /' \
  'Endpoint type: PUBLISHER' >"$HAILO_SOURCE_EXPECTED"
printf '%s\n' \
  'Type: std_msgs/msg/String' \
  'Publisher count: 1' \
  'Node name: impostor' \
  'Node namespace: /' \
  'Endpoint type: PUBLISHER' >"$HAILO_SOURCE_WRONG"
printf '%s\n' \
  'Type: std_msgs/msg/String' \
  'Publisher count: 2' \
  'Node name: hailo_person_stop_bridge' \
  'Node namespace: /' \
  'Endpoint type: PUBLISHER' \
  'Node name: hailo_person_stop_bridge' \
  'Node namespace: /' \
  'Endpoint type: PUBLISHER' >"$HAILO_SOURCE_DUPLICATE"
printf '%s\n' \
  'Type: std_msgs/msg/String' \
  'Publisher count: 1' \
  'Node name: _NODE_NAME_UNKNOWN_' \
  'Node namespace: _NODE_NAMESPACE_UNKNOWN_' \
  'Endpoint type: PUBLISHER' >"$HAILO_SOURCE_UNKNOWN"
printf '%s\n' \
  'Type: std_msgs/msg/String' \
  'Publisher count: 0' >"$HAILO_SOURCE_ZERO"

bash -c '
  set -euo pipefail
  source "$1"
  fixture="$2"
  ros2() { cat "$fixture"; }
  rfcu_ws_hailo_detection_source_is_bound
' _ "$WORKSTATION_HELPER" "$HAILO_SOURCE_EXPECTED" \
  || fail_test 'workstation rejected the exact Hailo detection publisher'
for bad_source in "$HAILO_SOURCE_WRONG" "$HAILO_SOURCE_DUPLICATE" \
    "$HAILO_SOURCE_UNKNOWN" "$HAILO_SOURCE_ZERO"; do
  if bash -c '
      set -euo pipefail
      source "$1"
      fixture="$2"
      ros2() { cat "$fixture"; }
      rfcu_ws_hailo_detection_source_is_bound
    ' _ "$WORKSTATION_HELPER" "$bad_source" >/dev/null 2>&1; then
    fail_test "workstation accepted invalid Hailo source evidence: $bad_source"
  fi
done
if bash -c '
    set -euo pipefail
    source "$1"
    ros2() { return 1; }
    rfcu_ws_hailo_detection_source_is_bound
  ' _ "$WORKSTATION_HELPER" >/dev/null 2>&1; then
  fail_test 'workstation accepted a failed Hailo source query'
fi
pass_case

WS_HAILO_WAIT_FUNCTION="$(extract_function "$WORKSTATION_HELPER" \
  rfcu_ws_wait_hailo_detection)"
WS_HAILO_SOURCE_LINE="$(line_number_once "$WS_HAILO_WAIT_FUNCTION" \
  'rfcu_ws_hailo_detection_source_is_bound \' \
  'workstation Hailo detection source gate')"
WS_HAILO_PAYLOAD_LINE="$(line_number_once "$WS_HAILO_WAIT_FUNCTION" \
  'rfcu_ws_json_field_once /perception/detections "$output" \' \
  'workstation Hailo detection payload gate')"
[ "$WS_HAILO_SOURCE_LINE" -lt "$WS_HAILO_PAYLOAD_LINE" ] \
  || fail_test 'workstation validates Hailo payload before publisher identity'
pass_case

WORKSTATION_RUN_FUNCTION="$(extract_function "$WORKSTATION_HELPER" rfcu_ws_run)"
WS_WAIT_DETECTION_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_wait_hailo_detection \' 'workstation Hailo detection gate')"
WS_START_VIDEO_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_start_child web-video-server \' 'workstation Hailo video start')"
WS_WAIT_VIDEO_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_wait_video_service \' 'workstation Hailo video gate')"
WS_START_MONITOR_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_start_child person-stop-monitor \' 'workstation person-stop start')"
WS_WAIT_CLEAR_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_wait_person_alert_clear \' 'workstation fresh-clear gate')"
WS_WAIT_BRIDGE_LINE="$(line_number_once "$WORKSTATION_RUN_FUNCTION" \
  'rfcu_ws_wait_bridge_ready \' 'workstation bridge gate')"
[ "$WS_WAIT_DETECTION_LINE" -lt "$WS_START_MONITOR_LINE" ] \
  && [ "$WS_WAIT_DETECTION_LINE" -lt "$WS_START_VIDEO_LINE" ] \
  && [ "$WS_START_VIDEO_LINE" -lt "$WS_WAIT_VIDEO_LINE" ] \
  && [ "$WS_WAIT_VIDEO_LINE" -lt "$WS_START_MONITOR_LINE" ] \
  && [ "$WS_START_MONITOR_LINE" -lt "$WS_WAIT_CLEAR_LINE" ] \
  && [ "$WS_WAIT_CLEAR_LINE" -lt "$WS_WAIT_BRIDGE_LINE" ] \
  || fail_test 'workstation Hailo detection/monitor/clear/bridge ordering changed'
pass_case

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
  for RFCU_PI_RUN_MODE in run-t2a run run-t3a; do
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
[ "$PI_RUN_ENV" = \
    $'run-t2a=43|SUBNET|0\nrun=43|SUBNET|0\nrun-t3a=43|SUBNET|0' ] \
  || fail_test "Pi run ROS boundary lost subnet discovery: $PI_RUN_ENV"

for t2_mode in run-t2a run; do
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_MODE="$2"
    RFCU_PI_READY_TIMEOUT_SECONDS=1
    RFCU_PI_POLL_SECONDS=1
    rfcu_pi_active_children_alive() { return 0; }
    ros2() { printf "/rosbridge_websocket\n/rosapi\n"; }
    rfcu_pi_wait_workstation_nodes
  ' _ "$PI_HELPER" "$t2_mode" \
    || fail_test "$t2_mode readiness started requiring the T3a capture node"
done
if bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_MODE=run-t3a
    RFCU_PI_READY_TIMEOUT_SECONDS=1
    RFCU_PI_POLL_SECONDS=1
    rfcu_pi_active_children_alive() { return 0; }
    ros2() { printf "/rosbridge_websocket\n/rosapi\n"; }
    sleep() { SECONDS=$((SECONDS + 2)); }
    rfcu_pi_wait_workstation_nodes
  ' _ "$PI_HELPER"; then
  fail_test 'T3a readiness passed without its correlated capture node'
fi
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_READY_TIMEOUT_SECONDS=1
  RFCU_PI_POLL_SECONDS=1
  rfcu_pi_active_children_alive() { return 0; }
  ros2() {
    printf "/rosbridge_websocket\n/rosapi\n/real_fcu_command_feedback_capture\n"
  }
  rfcu_pi_wait_workstation_nodes
' _ "$PI_HELPER" \
  || fail_test 'T3a readiness rejected rosbridge, rosapi and capture together'
if bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_MODE=run-t3a
    RFCU_PI_HAILO_PERSON_STOP=1
    RFCU_PI_READY_TIMEOUT_SECONDS=1
    RFCU_PI_POLL_SECONDS=1
    rfcu_pi_active_children_alive() { return 0; }
    ros2() { printf "/rosbridge_websocket\n/rosapi\n/real_fcu_command_feedback_capture\n"; }
    sleep() { SECONDS=$((SECONDS + 2)); }
    rfcu_pi_wait_workstation_nodes
  ' _ "$PI_HELPER"; then
  fail_test 'Hailo showcase readiness accepted the formal capture in place of person-stop/video nodes'
fi
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_HAILO_PERSON_STOP=1
  RFCU_PI_READY_TIMEOUT_SECONDS=1
  RFCU_PI_POLL_SECONDS=1
  rfcu_pi_active_children_alive() { return 0; }
  ros2() {
    printf "/rosbridge_websocket\n/rosapi\n/person_stop_monitor_node\n/web_video_server\n"
  }
  rfcu_pi_wait_workstation_nodes
' _ "$PI_HELPER" \
  || fail_test 'Hailo showcase readiness rejected person-stop/video nodes'
if bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_MODE=run-t2a
    RFCU_PI_HAILO_PERSON_STOP=1
    RFCU_PI_READY_TIMEOUT_SECONDS=1
    RFCU_PI_POLL_SECONDS=1
    rfcu_pi_active_children_alive() { return 0; }
    ros2() { printf "/rosbridge_websocket\n/rosapi\n"; }
    sleep() { SECONDS=$((SECONDS + 2)); }
    rfcu_pi_wait_workstation_nodes
  ' _ "$PI_HELPER"; then
  fail_test 'non-T3a Hailo readiness ignored person-stop/video nodes'
fi
PI_RUN_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_run)"
PI_START_HAILO_LINE="$(line_number_once "$PI_RUN_FUNCTION" \
  'rfcu_pi_start_child hailo-person-stop \' 'Pi Hailo child start')"
PI_WAIT_HAILO_LINE="$(line_number_once "$PI_RUN_FUNCTION" \
  'rfcu_pi_wait_hailo_ready \' 'Pi Hailo readiness gate')"
PI_START_PROBE_LINE="$(line_number_once "$PI_RUN_FUNCTION" \
  'rfcu_pi_start_child mavros-probe' 'Pi MAVROS probe start')"
[ "$PI_START_HAILO_LINE" -lt "$PI_WAIT_HAILO_LINE" ] \
  && [ "$PI_WAIT_HAILO_LINE" -lt "$PI_START_PROBE_LINE" ] \
  || fail_test 'Pi does not prove the Hailo feed before opening the FCU serial path'
grep -Fq 'workstation rosbridge/rosapi/capture nodes were not discovered' \
  <<<"$PI_RUN_FUNCTION" \
  || fail_test 'T3a readiness failure does not identify the required capture node'
grep -Fq \
  'REAL_FCU_T3A_READY=PASS authority=demand-enabled propellers=fitted guarding=installed exclusion_zone=clear propulsion=enabled bridge=READY_DISARMED workstation=visible capture=visible' \
  <<<"$PI_RUN_FUNCTION" \
  || fail_test 'T3a readiness marker does not retain capture visibility'
pass_case

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

T3A_GUARD_SNAPSHOT_OUTPUT="$(bash -c '
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_GUARD_SNAPSHOT_FILE="$2"
  RFCU_PI_GUARD_SNAPSHOT_SHA256="$3"
  RFCU_PI_GUARD_SNAPSHOT_APPROVED=1
  rfcu_pi_validate_guard_snapshot_selector
  printf "source=%s\n" "$RFCU_PI_GUARD_SOURCE"
' _ "$PI_HELPER" "$GUARD_SNAPSHOT_FILE" "$GUARD_SNAPSHOT_SHA256")"
[ "$T3A_GUARD_SNAPSHOT_OUTPUT" = 'source=snapshot' ] \
  || fail_test 'T3a rejected an approved hash-pinned guard snapshot'
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
WORKSTATION_HAILO_CONFLICT_OUTPUT="$(bash -c '
  source "$1"
  printf "%s\n" "${RFCU_WS_CONFLICT_PATTERNS[@]}" \
    "${RFCU_WS_HAILO_CONFLICT_PATTERNS[@]}"
' _ "$WORKSTATION_HELPER")"
[ "$WORKSTATION_HAILO_CONFLICT_OUTPUT" = \
    "$EXPECTED_WORKSTATION_CONFLICTS"$'\nperson_stop_monitor.py\nweb_video_server' ] \
  || fail_test 'opt-in workstation conflict guard omitted Hailo service owners'
WS_DEFAULT_CONFLICT_TRACE="$TEST_TMP/ws_default_conflicts.txt"
WS_HAILO_CONFLICT_TRACE="$TEST_TMP/ws_hailo_conflicts.txt"
for flag_and_trace in \
    "0:$WS_DEFAULT_CONFLICT_TRACE" "1:$WS_HAILO_CONFLICT_TRACE"; do
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_WS_HAILO_PERSON_STOP="$2"
    TRACE="$3"
    pgrep() { printf "%s\n" "$3" >>"$TRACE"; return 1; }
    rfcu_ws_reject_conflicts
  ' _ "$WORKSTATION_HELPER" "${flag_and_trace%%:*}" \
    "${flag_and_trace#*:}" \
    || fail_test 'workstation conflict guard failed under its focused fixture'
done
[ "$(cat "$WS_DEFAULT_CONFLICT_TRACE")" = "$EXPECTED_WORKSTATION_CONFLICTS" ] \
  || fail_test 'default workstation conflict checks changed while Hailo is disabled'
[ "$(cat "$WS_HAILO_CONFLICT_TRACE")" = "$WORKSTATION_HAILO_CONFLICT_OUTPUT" ] \
  || fail_test 'opt-in workstation conflict checks omitted a Hailo service owner'
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
  printf "PI_T2B_BRIDGE=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
  RFCU_PI_RUN_MODE=run-t3a
  rfcu_pi_build_commands
  printf "WS_ROSBRIDGE=%s\n" "${RFCU_WS_ROSBRIDGE_COMMAND[*]}"
  printf "WS_DASHBOARD=%s\n" "${RFCU_WS_DASHBOARD_COMMAND[*]}"
  printf "PI_MAVROS=%s\n" "${RFCU_PI_MAVROS_COMMAND[*]}"
  printf "PI_PROBE_MAVROS=%s\n" "${RFCU_PI_PROBE_MAVROS_COMMAND[*]}"
  printf "PI_T3A_BRIDGE=%s\n" "${RFCU_PI_BRIDGE_COMMAND[*]}"
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
grep -Fq 'PI_T3A_BRIDGE=' <<<"$COMMAND_OUTPUT" \
  && grep -Fq 'neutral_only:=false' \
    <<<"$(grep -F 'PI_T3A_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T3a bridge command lost the unchanged demand-enabled authority'
grep -Fq '__node:=real_fcu_rc_command_bridge_t3a' \
  <<<"$(grep -F 'PI_T3A_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T3a bridge command lacks its distinct node-name remap'
! grep -Fq '__node:=real_fcu_rc_command_bridge_t3a' \
  <<<"$(grep -F 'PI_T2A_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T3a node-name remap leaked into the T2a bridge command'
! grep -Fq '__node:=real_fcu_rc_command_bridge_t3a' \
  <<<"$(grep -F 'PI_T2B_BRIDGE=' <<<"$COMMAND_OUTPUT")" \
  || fail_test 'T3a node-name remap leaked into the T2b bridge command'
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
    bash -c '
      source "$1"
      caller() { rfcu_pi_require_t2a_run_gates || return 1; }
      caller
    ' _ "$PI_HELPER" 2>&1)"
  T2A_GATE_RC=$?
  set -e
  [ "$T2A_GATE_RC" -ne 0 ] \
    || fail_test "T2a gate accepted approvals $t2a_approved/$t2b_approved"
done
pass_case

T3A_BASE_ENV=(
  REAL_FCU_T0A_COMPLETE=1
  REAL_FCU_T0B_APPROVED=1
  REAL_FCU_T2A_APPROVED=0
  REAL_FCU_T2B_APPROVED=0
  REAL_FCU_T3A_APPROVED=1
  REAL_FCU_START_DISARMED=1
  REAL_FCU_SAFETY_ON=1
  REAL_FCU_PROPELLERS_REMOVED=0
  REAL_FCU_PROPELLERS_FITTED=1
  REAL_FCU_HULL_RESTRAINED=1
  REAL_FCU_MECHANICAL_GUARDING_INSTALLED=1
  REAL_FCU_EXCLUSION_ZONE_CLEAR=1
  REAL_FCU_PROPULSION_ISOLATED=1
)
env "${T3A_BASE_ENV[@]}" \
  bash -c 'source "$1"; rfcu_pi_require_t3a_run_gates' _ "$PI_HELPER" \
  || fail_test 'complete T3a gate was rejected'
for variable in \
  REAL_FCU_T0A_COMPLETE \
  REAL_FCU_T0B_APPROVED \
  REAL_FCU_T3A_APPROVED \
  REAL_FCU_START_DISARMED \
  REAL_FCU_SAFETY_ON \
  REAL_FCU_PROPELLERS_FITTED \
  REAL_FCU_HULL_RESTRAINED \
  REAL_FCU_MECHANICAL_GUARDING_INSTALLED \
  REAL_FCU_EXCLUSION_ZONE_CLEAR \
  REAL_FCU_PROPULSION_ISOLATED; do
  set +e
  T3A_GATE_OUTPUT="$(env "${T3A_BASE_ENV[@]}" "$variable"=0 \
    bash -c 'source "$1"; rfcu_pi_require_t3a_run_gates' _ \
      "$PI_HELPER" 2>&1)"
  T3A_GATE_RC=$?
  set -e
  [ "$T3A_GATE_RC" -ne 0 ] || fail_test "T3a gate accepted $variable=0"
  grep -Fq "$variable must be 1" <<<"$T3A_GATE_OUTPUT" \
    || fail_test "T3a gate did not name $variable"
done
for contradiction in t2a-approved t2b-approved propellers-removed; do
  contradiction_env=()
  case "$contradiction" in
    t2a-approved) contradiction_env=(REAL_FCU_T2A_APPROVED=1) ;;
    t2b-approved) contradiction_env=(REAL_FCU_T2B_APPROVED=1) ;;
    propellers-removed) contradiction_env=(REAL_FCU_PROPELLERS_REMOVED=1) ;;
  esac
  if env "${T3A_BASE_ENV[@]}" "${contradiction_env[@]}" \
      bash -c 'source "$1"; rfcu_pi_require_t3a_run_gates' _ \
        "$PI_HELPER" >/dev/null 2>&1; then
    fail_test "T3a gate accepted contradictory declaration: $contradiction"
  fi
done
for t2_gate in rfcu_pi_require_t2a_run_gates rfcu_pi_require_run_gates; do
  if env \
      REAL_FCU_T0A_COMPLETE=1 \
      REAL_FCU_T0B_APPROVED=1 \
      REAL_FCU_T2A_APPROVED=1 \
      REAL_FCU_T2B_APPROVED="$([ "$t2_gate" = rfcu_pi_require_run_gates ] && printf 1 || printf 0)" \
      REAL_FCU_T3A_APPROVED=1 \
      REAL_FCU_START_DISARMED=1 \
      REAL_FCU_SAFETY_ON=1 \
      REAL_FCU_PROPELLERS_REMOVED=1 \
      REAL_FCU_PROPELLERS_FITTED=0 \
      REAL_FCU_HULL_RESTRAINED=1 \
      REAL_FCU_PROPULSION_ISOLATED=1 \
      bash -c 'source "$1"; "$2"' _ "$PI_HELPER" "$t2_gate" \
        >/dev/null 2>&1; then
    fail_test "$t2_gate accepted simultaneous T3a approval"
  fi
done
pass_case

T0B_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_capture_t0b)"
[ -n "$T0B_FUNCTION" ] || fail_test 'T0b capture function is missing'
T0B_READ_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_read_t0b_parameter)"
[ -n "$T0B_READ_FUNCTION" ] || fail_test 'T0b parameter-read function is missing'
T0B_SNAPSHOT_SELECTOR_FUNCTION="$(extract_function "$PI_HELPER" \
  rfcu_pi_validate_t0b_snapshot_selector)"
[ -n "$T0B_SNAPSHOT_SELECTOR_FUNCTION" ] \
  || fail_test 'T0b snapshot selector function is missing'
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
  't0b-snapshot-write-evidence' \
  'mavproxy-ftp-snapshot' \
  '32768'; do
  grep -Fq "$literal" <<<"$T0B_FUNCTION" \
    || fail_test "T0b capture is missing: $literal"
done
! grep -Eiq 'param(eter)?[_ -]?set|set_mode|arming|motor.test|rc.override|create_publisher|publish\(' \
  <<<"$T0B_FUNCTION$T0B_READ_FUNCTION$T0B_SNAPSHOT_SELECTOR_FUNCTION" \
  || fail_test 'T0b capture contains a forbidden write path'

T0B_SNAPSHOT_FILE="$TEST_TMP/t0b_snapshot.parm"
printf 'BRD_SAFETY_DEFLT 1\n' >"$T0B_SNAPSHOT_FILE"
T0B_SNAPSHOT_SHA256="$(sha256sum "$T0B_SNAPSHOT_FILE" | awk '{print $1}')"
T0B_SNAPSHOT_SELECTION="$(bash -c '
  source "$1"
  RFCU_PI_RUN_MODE=probe
  RFCU_PI_T0B_SNAPSHOT_FILE="$2"
  RFCU_PI_T0B_SNAPSHOT_SHA256="$3"
  RFCU_PI_T0B_SNAPSHOT_APPROVED=1
  rfcu_pi_validate_t0b_snapshot_selector
  printf "%s\n" "$RFCU_PI_T0B_SOURCE"
' _ "$PI_HELPER" "$T0B_SNAPSHOT_FILE" "$T0B_SNAPSHOT_SHA256")"
[ "$T0B_SNAPSHOT_SELECTION" = 'mavproxy-ftp-snapshot' ] \
  || fail_test 'approved hash-pinned T0b snapshot was not selected'
T0B_SNAPSHOT_PROMPT_FUNCTION="$(extract_function "$PI_HELPER" \
  rfcu_pi_probe_snapshot)"
grep -Fq 'read -r -p' <<<"$T0B_SNAPSHOT_PROMPT_FUNCTION" \
  || fail_test 'snapshot-backed T0b probe does not wait for fresh terminal approval'
T0B_SNAPSHOT_PROMPT_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  rfcu_pi_probe() {
    printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
      "$RFCU_PI_T0B_SNAPSHOT_FILE" "$RFCU_PI_T0B_SNAPSHOT_SHA256" \
      "$RFCU_PI_T0B_SNAPSHOT_APPROVED" "$REAL_FCU_T0A_COMPLETE" \
      "$REAL_FCU_T0B_APPROVED" "$REAL_FCU_START_DISARMED" \
      "$REAL_FCU_SAFETY_ON" "$REAL_FCU_PROPELLERS_REMOVED" \
      "$REAL_FCU_PROPULSION_ISOLATED:$REAL_FCU_HULL_RESTRAINED"
  }
  rfcu_pi_probe_snapshot "$2" "$3"
' _ "$PI_HELPER" "$T0B_SNAPSHOT_FILE" "$T0B_SNAPSHOT_SHA256" \
  <<< 'T0A_COMPLETE T0B_APPROVED FCU_DISARMED SAFETY_ON HERELINK_READ_ONLY STICKS_NEUTRAL PROPULSION_ISOLATED PROPELLERS_REMOVED HULL_RESTRAINED')"
[ "$T0B_SNAPSHOT_PROMPT_OUTPUT" = \
    "$T0B_SNAPSHOT_FILE|$T0B_SNAPSHOT_SHA256|1|1|1|1|1|1|1:1" ] \
  || fail_test 'snapshot-backed T0b prompt did not set the exact fresh gates'
if bash -c '
    source "$1"
    rfcu_pi_probe() { return 0; }
    rfcu_pi_probe_snapshot "$2" "$3"
  ' _ "$PI_HELPER" "$T0B_SNAPSHOT_FILE" "$T0B_SNAPSHOT_SHA256" \
    <<< 'NOT_APPROVED' >/dev/null 2>&1; then
  fail_test 'snapshot-backed T0b probe accepted an incorrect approval phrase'
fi
for failure_case in partial unauthorized run hash-drift; do
  set +e
  bash -c '
    source "$1"
    RFCU_PI_RUN_MODE=probe
    RFCU_PI_T0B_SNAPSHOT_FILE="$2"
    RFCU_PI_T0B_SNAPSHOT_SHA256="$3"
    RFCU_PI_T0B_SNAPSHOT_APPROVED=1
    case "$4" in
      partial) RFCU_PI_T0B_SNAPSHOT_SHA256= ;;
      unauthorized) RFCU_PI_T0B_SNAPSHOT_APPROVED=0 ;;
      run) RFCU_PI_RUN_MODE=run ;;
      hash-drift) RFCU_PI_T0B_SNAPSHOT_SHA256="$(printf "0%.0s" {1..64})" ;;
    esac
    rfcu_pi_validate_t0b_snapshot_selector
  ' _ "$PI_HELPER" "$T0B_SNAPSHOT_FILE" "$T0B_SNAPSHOT_SHA256" \
    "$failure_case" >/dev/null 2>&1
  T0B_SNAPSHOT_FAILURE_RC=$?
  set -e
  [ "$T0B_SNAPSHOT_FAILURE_RC" -ne 0 ] \
    || fail_test "T0b snapshot selector accepted $failure_case"
done
pass_case

T0B_MANIFEST_DIR="$TEST_TMP/t0b-manifest"
mkdir -p "$T0B_MANIFEST_DIR/manifest"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=probe
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_T0B_SNAPSHOT_FILE="$3"
  RFCU_PI_T0B_SNAPSHOT_SHA256="$4"
  RFCU_PI_T0B_SNAPSHOT_APPROVED=1
  RFCU_PI_T0B_OPERATOR_DECLARATION=FRESH_T0B_DECLARATION
  ROS_DOMAIN_ID=43
  ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
  ROS_LOCALHOST_ONLY=0
  rfcu_pi_validate_t0b_snapshot_selector
  rfcu_pi_build_commands
  rfcu_pi_write_manifest
' _ "$PI_HELPER" "$T0B_MANIFEST_DIR" "$T0B_SNAPSHOT_FILE" \
  "$T0B_SNAPSHOT_SHA256"
grep -Fxq 't0b_source=mavproxy-ftp-snapshot' \
  "$T0B_MANIFEST_DIR/manifest/environment.txt" \
  || fail_test 'Pi manifest omitted the T0b snapshot source'
grep -Fxq "t0b_snapshot_file=$T0B_SNAPSHOT_FILE" \
  "$T0B_MANIFEST_DIR/manifest/environment.txt" \
  || fail_test 'Pi manifest omitted the T0b snapshot path'
grep -Fxq "t0b_snapshot_sha256=$T0B_SNAPSHOT_SHA256" \
  "$T0B_MANIFEST_DIR/manifest/environment.txt" \
  || fail_test 'Pi manifest omitted the T0b snapshot hash'
grep -Fxq 't0b_operator_declaration=FRESH_T0B_DECLARATION' \
  "$T0B_MANIFEST_DIR/manifest/environment.txt" \
  || fail_test 'Pi manifest omitted the fresh T0b operator declaration'
grep -Fq "$T0B_SNAPSHOT_SHA256  $T0B_SNAPSHOT_FILE" \
  "$T0B_MANIFEST_DIR/manifest/artifacts.sha256" \
  || fail_test 'Pi artifact manifest omitted the T0b snapshot bytes'
pass_case

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

CAPTURE_TOPIC_LOST_DIR="$TEST_TMP/capture-topic-lost-message"
mkdir -p "$CAPTURE_TOPIC_LOST_DIR/evidence"
set +e
CAPTURE_TOPIC_LOST_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  ros2() {
    case " $* " in
      *" --no-lost-messages "*) ;;
      *)
        printf "A message was lost!!!\n\ttotal count change:1\n\ttotal count: 1---\n"
        ;;
    esac
    printf "sensors_enabled: 0\n---\n"
  }
  rfcu_pi_capture_topic /mavros/sys_status mavros_msgs/msg/SysStatus \
    "$2/evidence/sys_status.yaml" 3
' _ "$PI_HELPER" "$CAPTURE_TOPIC_LOST_DIR" 2>&1)"
CAPTURE_TOPIC_LOST_RC=$?
set -e
[ "$CAPTURE_TOPIC_LOST_RC" -eq 0 ] \
  && [ -z "$CAPTURE_TOPIC_LOST_OUTPUT" ] \
  && [ "$(cat "$CAPTURE_TOPIC_LOST_DIR/evidence/sys_status.yaml")" = \
    $'sensors_enabled: 0\n---' ] \
  && [ "$(cat "$CAPTURE_TOPIC_LOST_DIR/evidence/sys_status.attempt-001.yaml")" = \
    $'sensors_enabled: 0\n---' ] \
  || fail_test "capture-topic lost-message callback contaminated YAML: rc=$CAPTURE_TOPIC_LOST_RC output=[$CAPTURE_TOPIC_LOST_OUTPUT]"
pass_case

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
for mode_and_gate in \
  'run-t2a t2a' \
  'run t2b' \
  'run-t3a t3a'; do
  read -r run_mode expected_gate <<<"$mode_and_gate"
  set +e
  RUN_GATE_OUTPUT="$(bash -c '
    source "$1"
    rfcu_pi_require_t2a_run_gates() { echo gate=t2a; return 1; }
    rfcu_pi_require_run_gates() { echo gate=t2b; return 1; }
    rfcu_pi_require_t3a_run_gates() { echo gate=t3a; return 1; }
    rfcu_pi_static_preflight() { echo preflight-reached; return 0; }
    rfcu_pi_run "$2"
  ' _ "$PI_HELPER" "$run_mode" 2>&1)"
  RUN_GATE_RC=$?
  set -e
  [ "$RUN_GATE_RC" -eq 1 ] \
    || fail_test "$run_mode gate failure returned $RUN_GATE_RC"
  [ "$(grep -Ec '^gate=' <<<"$RUN_GATE_OUTPUT")" -eq 1 ] \
    && grep -Fxq "gate=$expected_gate" <<<"$RUN_GATE_OUTPUT" \
    || fail_test "$run_mode did not invoke only its $expected_gate gate: $RUN_GATE_OUTPUT"
  ! grep -Fq 'preflight-reached' <<<"$RUN_GATE_OUTPUT" \
    || fail_test "$run_mode continued after its gate failed"
done
pass_case

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
HAILO_READY_STATUS='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":false,"person_alert_required":true,"person_alert_fresh":true,"person_hold_clear":true,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}'
HAILO_BENCH_URL="$(bash -c '
  source "$1"
  RFCU_WS_HAILO_PERSON_STOP=1
  rfcu_ws_bench_url_from_status "$2"
' _ "$WORKSTATION_HELPER" "$HAILO_READY_STATUS")" \
  || fail_test 'workstation rejected bridge-enforced Hailo readiness'
[ "$HAILO_BENCH_URL" = "$BENCH_URL" ] \
  || fail_test "Hailo readiness changed the guarded bench URL: $HAILO_BENCH_URL"
bash -c '
  source "$1"
  RFCU_PI_HAILO_PERSON_STOP=1
  rfcu_pi_status_is_ready "$2" false
' _ "$PI_HELPER" "$HAILO_READY_STATUS" \
  || fail_test 'Pi rejected bridge-enforced Hailo readiness'
for unsafe_hailo_status in \
  '{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":false,"person_alert_required":false,"person_alert_fresh":true,"person_hold_clear":true,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}' \
  '{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":false,"person_alert_required":true,"person_alert_fresh":false,"person_hold_clear":true,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}' \
  '{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false,"mode":"MANUAL","feedback_fresh":true,"neutral_only":false,"person_alert_required":true,"person_alert_fresh":true,"person_hold_clear":false,"resolved":{"steering_rc":1,"throttle_rc":3,"left_servo":3,"right_servo":1}}'; do
  if bash -c '
      source "$1"
      RFCU_WS_HAILO_PERSON_STOP=1
      rfcu_ws_bench_url_from_status "$2"
    ' _ "$WORKSTATION_HELPER" "$unsafe_hailo_status" >/dev/null 2>&1; then
    fail_test 'workstation accepted a bridge without enforced fresh-clear camera policy'
  fi
  if bash -c '
      source "$1"
      RFCU_PI_HAILO_PERSON_STOP=1
      rfcu_pi_status_is_ready "$2" false
    ' _ "$PI_HELPER" "$unsafe_hailo_status" >/dev/null 2>&1; then
    fail_test 'Pi accepted a bridge without enforced fresh-clear camera policy'
  fi
done
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

TIMEOUT_DEFAULTS="$(bash -c '
  source "$1"
  printf "%s %s\n" "$RFCU_WS_READY_TIMEOUT_SECONDS" "$RFCU_WS_STATUS_TIMEOUT_SECONDS"
' _ "$WORKSTATION_HELPER")"
[ "$TIMEOUT_DEFAULTS" = '600 15' ] \
  || fail_test "workstation timeout defaults are not readiness=600 status=15: $TIMEOUT_DEFAULTS"
PI_TIMEOUT_DEFAULTS="$(bash -c '
  source "$1"
  printf "%s %s %s\n" "$RFCU_PI_READY_TIMEOUT_SECONDS" \
    "$RFCU_PI_STATUS_TIMEOUT_SECONDS" \
    "$RFCU_PI_T3A_CLOSEOUT_TIMEOUT_SECONDS"
' _ "$PI_HELPER")"
[ "$PI_TIMEOUT_DEFAULTS" = '600 15 300' ] \
  || fail_test "Pi timeout defaults are not readiness=600 status=15 T3a-closeout=300: $PI_TIMEOUT_DEFAULTS"
pass_case

STATUS_JSON='{"state":"READY_DISARMED","ready":true,"connected":true,"armed":false}'
STATUS_ECHO="${STATUS_JSON}"$'\n---'
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
    expected_output="$5"
    status_function="$6"
    ros2() { printf "%s\n" "$status_output"; }
    result="$("$status_function")"
    [ "$result" = "$expected_output" ]
  ' _ "$status_helper" "$STATUS_TEST_DIR" "$status_run_dir" \
    "$STATUS_ECHO" "$STATUS_JSON" "$status_function" \
    || fail_test "$status_function rejected the ROS JSON document and terminator"
done
pass_case

for status_case in \
  "$WORKSTATION_HELPER|rfcu_ws_status_json_once|RFCU_WS_RUN_DIR" \
  "$PI_HELPER|rfcu_pi_status_json_once|RFCU_PI_RUN_DIR"; do
  IFS='|' read -r status_helper status_function status_run_dir <<<"$status_case"
  STATUS_TEST_DIR="$TEST_TMP/empty-${status_function}"
  mkdir -p "$STATUS_TEST_DIR/logs"
  EMPTY_STDERR="$STATUS_TEST_DIR/stderr.log"
  if bash -c '
    source "$1"
    printf -v "$3" "%s" "$2"
    ros2() { return 0; }
    "$4"
  ' _ "$status_helper" "$STATUS_TEST_DIR" "$status_run_dir" \
      "$status_function" 2>"$EMPTY_STDERR"; then
    fail_test "$status_function accepted an empty ROS subscription result"
  fi
  [ ! -s "$EMPTY_STDERR" ] \
    || fail_test "$status_function prints a traceback for an empty ROS subscription result"
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

T3A_PROPULSION_CONFIRM_FUNCTION="$(extract_function "$PI_HELPER" \
  rfcu_pi_confirm_t3a_propulsion_enable)"
T3A_CLOSEOUT_CONFIRM_FUNCTION="$(extract_function "$PI_HELPER" \
  rfcu_pi_confirm_t3a_safe_closeout)"
T3A_INTERRUPT_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_on_interrupt)"
T3A_TERM_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_on_term)"
T3A_CLEANUP_FUNCTION="$(extract_function "$PI_HELPER" rfcu_pi_cleanup)"
grep -Fq 'read -r -t "$RFCU_PI_T3A_CLOSEOUT_TIMEOUT_SECONDS"' \
  <<<"$T3A_CLOSEOUT_CONFIRM_FUNCTION" \
  || fail_test 'T3a safe-closeout input is not time-bounded'
! grep -Fq 'trap - EXIT INT TERM' <<<"$T3A_CLEANUP_FUNCTION" \
  || fail_test 'T3a cleanup clears its signal traps before safe closeout'
grep -Fq 'trap - EXIT' <<<"$T3A_CLEANUP_FUNCTION" \
  || fail_test 'T3a cleanup does not clear only its recursive EXIT trap'
! grep -Fq "trap 'rfcu_pi_on_cleanup_signal" <<<"$T3A_CLEANUP_FUNCTION" \
  || fail_test 'T3a cleanup replaces its installed signal handlers'
for handler_and_signal in interrupt:INT term:TERM; do
  handler_name="${handler_and_signal%%:*}"
  expected_signal="${handler_and_signal##*:}"
  handler_variable="T3A_${handler_name^^}_FUNCTION"
  handler_function="${!handler_variable}"
  grep -Fq 'RFCU_PI_CLEANING' <<<"$handler_function" \
    && grep -Fq "rfcu_pi_on_cleanup_signal $expected_signal" \
      <<<"$handler_function" \
    || fail_test "Pi $handler_name handler is not cleanup-aware"
done
for literal in \
  'PROPULSION_ENABLED_FCU_DISARMED_SAFETY_ON_GUARDING_INSTALLED_EXCLUSION_CLEAR' \
  'evidence/t3a_propulsion_enable.txt'; do
  grep -Fq "$literal" <<<"$T3A_PROPULSION_CONFIRM_FUNCTION" \
    || fail_test "T3a propulsion-enable confirmation is missing: $literal"
done
for literal in \
  'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED' \
  'evidence/t3a_safe_closeout.txt'; do
  grep -Fq "$literal" <<<"$T3A_CLOSEOUT_CONFIRM_FUNCTION" \
    || fail_test "T3a safe-closeout confirmation is missing: $literal"
done
! grep -Fq 'rfcu_pi_confirm_t3a_safe_closeout' <<<"$T3A_INTERRUPT_FUNCTION" \
  || fail_test 'T3a interrupt handler still duplicates the centralized closeout prompt'
grep -Fq 'rfcu_pi_confirm_t3a_safe_closeout' <<<"$T3A_CLEANUP_FUNCTION" \
  || fail_test 'T3a cleanup does not centralize the explicit safe closeout'
T3A_CLEANUP_CONFIRM_LINE="$(line_number_once "$T3A_CLEANUP_FUNCTION" \
  'rfcu_pi_confirm_t3a_safe_closeout' 'Pi T3a cleanup confirmation')"
T3A_CLEANUP_FINAL_STATE_LINE="$(line_number_once "$T3A_CLEANUP_FUNCTION" \
  'final_state="$RFCU_PI_RUN_DIR/evidence/final_state.yaml"' \
  'Pi T3a machine final-state capture')"
[ "$T3A_CLEANUP_CONFIRM_LINE" -lt "$T3A_CLEANUP_FINAL_STATE_LINE" ] \
  || fail_test 'T3a safe-closeout phrase is not required before final-state/teardown work'
T3A_PROPULSION_CONFIRM_LINE="$(line_number_once "$RUN_FUNCTION" \
  'rfcu_pi_confirm_t3a_propulsion_enable' \
  'Pi T3a propulsion-enable confirmation')"
[ "$T3A_PROPULSION_CONFIRM_LINE" -lt "$PI_CONFIRM_LINE" ] \
  || fail_test 'T3a propulsion is not enabled while safety remains ON'
pass_case

T3A_CONFIRM_DIR="$TEST_TMP/t3a-confirmations"
mkdir -p "$T3A_CONFIRM_DIR/evidence"
T3A_PROPULSION_CONFIRM_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=0
  RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=0
  rfcu_pi_confirm_t3a_propulsion_enable
  printf "prompted=%s\n" "$RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED"
  printf "confirmed=%s\n" "$RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED"
  cat "$RFCU_PI_RUN_DIR/evidence/t3a_propulsion_enable.txt"
' _ "$PI_HELPER" "$T3A_CONFIRM_DIR" \
  <<< 'PROPULSION_ENABLED_FCU_DISARMED_SAFETY_ON_GUARDING_INSTALLED_EXCLUSION_CLEAR')"
grep -Fxq 'prompted=1' <<<"$T3A_PROPULSION_CONFIRM_OUTPUT" \
  || fail_test 'T3a propulsion-enable prompt did not create a closeout obligation'
grep -Fxq 'confirmed=1' <<<"$T3A_PROPULSION_CONFIRM_OUTPUT" \
  || fail_test 'T3a propulsion-enable confirmation did not set its state'
grep -Fxq \
  'PROPULSION_ENABLED_FCU_DISARMED_SAFETY_ON_GUARDING_INSTALLED_EXCLUSION_CLEAR' \
  "$T3A_CONFIRM_DIR/evidence/t3a_propulsion_enable.txt" \
  || fail_test 'T3a propulsion-enable evidence did not retain the exact phrase'
T3A_PROPULSION_MISMATCH_OUTPUT="$(bash -c '
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=0
  RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=0
  set +e
  rfcu_pi_confirm_t3a_propulsion_enable
  rc=$?
  set -e
  printf "rc=%s prompted=%s confirmed=%s\n" "$rc" \
    "$RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED" \
    "$RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED"
' _ "$PI_HELPER" "$T3A_CONFIRM_DIR" <<< 'WRONG' 2>/dev/null)"
[ "$T3A_PROPULSION_MISMATCH_OUTPUT" = 'rc=1 prompted=1 confirmed=0' ] \
  || fail_test "T3a propulsion-enable mismatch did not preserve its closeout obligation: $T3A_PROPULSION_MISMATCH_OUTPUT"
T3A_PROMPTLESS_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=0
  RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=0
  rfcu_pi_confirm_t3a_propulsion_enable </dev/null
  rfcu_pi_confirm_manual_safety_release </dev/null
  printf "prompted=%s confirmed=%s\n" \
    "$RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED" \
    "$RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED"
' _ "$PI_HELPER" "$T3A_CONFIRM_DIR")"
[ "$T3A_PROMPTLESS_OUTPUT" = 'prompted=1 confirmed=1' ] \
  || fail_test "T3a approved runtime still required terminal confirmation: $T3A_PROMPTLESS_OUTPUT"
grep -Fxq 'source=approved-run-t3a-runtime-flags' \
  "$T3A_CONFIRM_DIR/evidence/t3a_propulsion_enable.txt" \
  || fail_test 'T3a promptless runtime evidence did not record its approval source'
T3A_CLOSEOUT_CONFIRM_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_DIR="$2"
  RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=0
  rfcu_pi_confirm_t3a_safe_closeout
  printf "confirmed=%s\n" "$RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED"
  cat "$RFCU_PI_RUN_DIR/evidence/t3a_safe_closeout.txt"
' _ "$PI_HELPER" "$T3A_CONFIRM_DIR" \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
grep -Fxq 'confirmed=1' <<<"$T3A_CLOSEOUT_CONFIRM_OUTPUT" \
  || fail_test 'T3a safe-closeout confirmation did not set its state'
grep -Fxq 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED' \
  "$T3A_CONFIRM_DIR/evidence/t3a_safe_closeout.txt" \
  || fail_test 'T3a closeout evidence did not retain the exact phrase'
T3A_CLOSEOUT_TIMEOUT_FIFO="$TEST_TMP/t3a-closeout-timeout.fifo"
mkfifo "$T3A_CLOSEOUT_TIMEOUT_FIFO"
( exec 9>"$T3A_CLOSEOUT_TIMEOUT_FIFO"; sleep 5 ) &
T3A_CLOSEOUT_HOLDER_PID=$!
set +e
timeout 3 bash -c '
  source "$1"
  RFCU_PI_T3A_CLOSEOUT_TIMEOUT_SECONDS=1
  RFCU_PI_RUN_DIR="$2"
  rfcu_pi_confirm_t3a_safe_closeout
' _ "$PI_HELPER" "$T3A_CONFIRM_DIR" \
  <"$T3A_CLOSEOUT_TIMEOUT_FIFO" >/dev/null 2>&1
T3A_CLOSEOUT_TIMEOUT_RC=$?
kill "$T3A_CLOSEOUT_HOLDER_PID" 2>/dev/null || true
wait "$T3A_CLOSEOUT_HOLDER_PID" 2>/dev/null || true
set -e
[ "$T3A_CLOSEOUT_TIMEOUT_RC" -eq 1 ] \
  || fail_test "T3a closeout input was not bounded by its timeout: rc=$T3A_CLOSEOUT_TIMEOUT_RC"
pass_case

T3A_INIT_ROOT="$TEST_TMP/t3a-init"
mkdir -p "$T3A_INIT_ROOT"
T3A_INIT_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_LOG_ROOT="$2"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=1
  RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=1
  RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=1
  RFCU_PI_CLEANUP_SIGNAL=TERM
  date() { printf "20260901_123456\n"; }
  rfcu_pi_init_state
  printf "%s\n" "$RFCU_PI_RUN_DIR"
  printf "states=%s/%s/%s/%s\n" \
    "$RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED" \
    "$RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED" \
    "$RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED" \
    "$RFCU_PI_CLEANUP_SIGNAL"
' _ "$PI_HELPER" "$T3A_INIT_ROOT")"
T3A_RUN_DIR="$(sed -n '1p' <<<"$T3A_INIT_OUTPUT")"
[ "$T3A_RUN_DIR" = "$T3A_INIT_ROOT/real_fcu_t3a_pi_20260901_123456" ] \
  || fail_test "T3a run directory is not distinct: $T3A_RUN_DIR"
grep -Fxq 'states=0/0/0/none' <<<"$T3A_INIT_OUTPUT" \
  || fail_test "T3a init did not reset safety state: $T3A_INIT_OUTPUT"
pass_case

T3A_MANIFEST_DIR="$TEST_TMP/t3a-manifest"
mkdir -p "$T3A_MANIFEST_DIR/manifest"
bash -c '
  set -euo pipefail
  source "$1"
  RFCU_PI_RUN_MODE=run-t3a
  RFCU_PI_RUN_DIR="$2"
  ROS_DOMAIN_ID=43
  ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
  ROS_LOCALHOST_ONLY=0
  REAL_FCU_T3A_APPROVED=1
  REAL_FCU_PROPELLERS_REMOVED=0
  REAL_FCU_PROPELLERS_FITTED=1
  REAL_FCU_MECHANICAL_GUARDING_INSTALLED=1
  REAL_FCU_EXCLUSION_ZONE_CLEAR=1
  REAL_FCU_PROPULSION_ISOLATED=1
  rfcu_pi_build_commands
  rfcu_pi_write_manifest
' _ "$PI_HELPER" "$T3A_MANIFEST_DIR"
for manifest_fact in \
  'mode=run-t3a' \
  'tier=T3a' \
  'authority=demand-enabled' \
  'propellers_removed=0' \
  'propellers_fitted=1' \
  't3a_closeout_timeout_seconds=300' \
  'mechanical_guarding_installed=1' \
  'exclusion_zone_clear=1' \
  'propulsion_isolated_at_launch=1'; do
  grep -Fxq "$manifest_fact" "$T3A_MANIFEST_DIR/manifest/environment.txt" \
    || fail_test "T3a manifest omitted: $manifest_fact"
done
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
    RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=0
    RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=0
    RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=0
    if [ "$RFCU_PI_RUN_MODE" = run-t3a ]; then
      RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=1
      RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=1
    fi
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

run_pi_t3a_abnormal_exit_case() {
  local case_dir="$1" trigger="$2" propulsion_enabled="${3:-1}"
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_DIR="$2"
    mkdir -p "$RFCU_PI_RUN_DIR/evidence"
    RFCU_PI_SUPERVISOR_LOG="$RFCU_PI_RUN_DIR/supervisor.log"
    : >"$RFCU_PI_SUPERVISOR_LOG"
    RFCU_PI_RUN_MODE=run-t3a
    RFCU_PI_CLEANING=0
    RFCU_PI_READY_REACHED=0
    RFCU_PI_BRIDGE_STARTED=1
    RFCU_PI_OPERATOR_STOP_REQUESTED=0
    RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED="$4"
    RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED="$4"
    RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=0
    rfcu_pi_capture_topic() {
      printf "final-state-capture\n" >>"$RFCU_PI_RUN_DIR/closeout.trace"
      : >"$3"
      return 0
    }
    rfcu_pi_state_file_is_connected_disarmed() { return 0; }
    rfcu_pi_stop_child() {
      printf "stop-%s\n" "$1" >>"$RFCU_PI_RUN_DIR/closeout.trace"
      return 0
    }
    rfcu_pi_serial_is_free() { return 0; }
    rfcu_pi_capture_workstation_stop_marker() { return 1; }
    trap rfcu_pi_cleanup EXIT
    trap rfcu_pi_on_term TERM
    case "$3" in
      term) kill -TERM "$$" ;;
      readiness) rfcu_pi_fail "post-enable readiness failure" ;;
      child) exit 70 ;;
      *) exit 71 ;;
    esac
  ' _ "$PI_HELPER" "$case_dir" "$trigger" "$propulsion_enabled"
}

run_pi_t3a_propulsion_evidence_failure_case() {
  local case_dir="$1"
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_DIR="$2"
    mkdir -p "$RFCU_PI_RUN_DIR"
    : >"$RFCU_PI_RUN_DIR/evidence"
    RFCU_PI_SUPERVISOR_LOG="$RFCU_PI_RUN_DIR/supervisor.log"
    : >"$RFCU_PI_SUPERVISOR_LOG"
    RFCU_PI_RUN_MODE=run-t3a
    RFCU_PI_CLEANING=0
    RFCU_PI_READY_REACHED=0
    RFCU_PI_BRIDGE_STARTED=1
    RFCU_PI_OPERATOR_STOP_REQUESTED=0
    RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=0
    RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=0
    RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=0
    rfcu_pi_capture_topic() {
      : >"$3"
      return 0
    }
    rfcu_pi_state_file_is_connected_disarmed() { return 0; }
    rfcu_pi_stop_child() { return 0; }
    rfcu_pi_serial_is_free() { return 0; }
    trap rfcu_pi_cleanup EXIT
    set +e
    rfcu_pi_confirm_t3a_propulsion_enable
    confirm_rc=$?
    set -e
    [ "$confirm_rc" -ne 0 ] || exit 99
    rm -f "$RFCU_PI_RUN_DIR/evidence"
    mkdir -p "$RFCU_PI_RUN_DIR/evidence"
    exit 72
  ' _ "$PI_HELPER" "$case_dir"
}

run_pi_t3a_cleanup_signal_case() {
  local case_dir="$1" signal="$2" stage="${3:-closeout}"
  bash -c '
    set -euo pipefail
    source "$1"
    RFCU_PI_RUN_DIR="$2"
    mkdir -p "$RFCU_PI_RUN_DIR/evidence"
    RFCU_PI_SUPERVISOR_LOG="$RFCU_PI_RUN_DIR/supervisor.log"
    : >"$RFCU_PI_SUPERVISOR_LOG"
    RFCU_PI_RUN_MODE=run-t3a
    RFCU_PI_CLEANING=0
    RFCU_PI_READY_REACHED=0
    RFCU_PI_BRIDGE_STARTED=1
    RFCU_PI_OPERATOR_STOP_REQUESTED=0
    RFCU_PI_T3A_PROPULSION_ENABLE_PROMPTED=1
    RFCU_PI_T3A_PROPULSION_ENABLED_CONFIRMED=1
    RFCU_PI_T3A_SAFE_CLOSEOUT_CONFIRMED=0
    RFCU_PI_CLEANUP_SIGNAL=none
    RFCU_PI_TEST_CLEANUP_SIGNAL="$3"
    RFCU_PI_TEST_CLEANUP_STAGE="$4"
    rfcu_pi_confirm_t3a_safe_closeout() {
      if [ "$RFCU_PI_TEST_CLEANUP_STAGE" = closeout ]; then
        kill -"$RFCU_PI_TEST_CLEANUP_SIGNAL" "$BASHPID"
      fi
      return 1
    }
    rfcu_pi_capture_topic() {
      printf "final-state-capture\n" >>"$RFCU_PI_RUN_DIR/closeout.trace"
      : >"$3"
      return 0
    }
    rfcu_pi_state_file_is_connected_disarmed() { return 0; }
    rfcu_pi_stop_child() {
      printf "stop-%s\n" "$1" >>"$RFCU_PI_RUN_DIR/closeout.trace"
      return 0
    }
    rfcu_pi_serial_is_free() { return 0; }
    builtin trap rfcu_pi_cleanup EXIT
    builtin trap rfcu_pi_on_interrupt INT
    builtin trap rfcu_pi_on_term TERM
    if [ "$RFCU_PI_TEST_CLEANUP_STAGE" = transition ]; then
      trap() {
        if [ "${1:-}" = - ] && [ "${2:-}" = EXIT ]; then
          builtin trap - EXIT
          kill -"$RFCU_PI_TEST_CLEANUP_SIGNAL" "$BASHPID"
          return 0
        fi
        builtin trap "$@"
      }
    fi
    exit 0
  ' _ "$PI_HELPER" "$case_dir" "$signal" "$stage"
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
PI_T3A_TERM_OUTPUT="$(run_pi_t3a_abnormal_exit_case \
  "$TEST_TMP/pi-t3a-term" term 1 2>&1 \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
PI_T3A_TERM_RC=$?
PI_T3A_READINESS_OUTPUT="$(run_pi_t3a_abnormal_exit_case \
  "$TEST_TMP/pi-t3a-readiness" readiness 1 2>&1 \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
PI_T3A_READINESS_RC=$?
PI_T3A_CHILD_OUTPUT="$(run_pi_t3a_abnormal_exit_case \
  "$TEST_TMP/pi-t3a-child" child 1 2>&1 \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
PI_T3A_CHILD_RC=$?
PI_T3A_PRE_ENABLE_OUTPUT="$(run_pi_t3a_abnormal_exit_case \
  "$TEST_TMP/pi-t3a-pre-enable" readiness 0 </dev/null 2>&1)"
PI_T3A_PRE_ENABLE_RC=$?
PI_T3A_EVIDENCE_FAILURE_OUTPUT="$(run_pi_t3a_propulsion_evidence_failure_case \
  "$TEST_TMP/pi-t3a-evidence-failure" 2>&1 \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
PI_T3A_EVIDENCE_FAILURE_RC=$?
PI_T3A_CLEANUP_INT_OUTPUT="$(run_pi_t3a_cleanup_signal_case \
  "$TEST_TMP/pi-t3a-cleanup-int" INT 2>&1)"
PI_T3A_CLEANUP_INT_RC=$?
PI_T3A_CLEANUP_TERM_OUTPUT="$(run_pi_t3a_cleanup_signal_case \
  "$TEST_TMP/pi-t3a-cleanup-term" TERM 2>&1)"
PI_T3A_CLEANUP_TERM_RC=$?
PI_T3A_TRANSITION_INT_OUTPUT="$(run_pi_t3a_cleanup_signal_case \
  "$TEST_TMP/pi-t3a-transition-int" INT transition 2>&1)"
PI_T3A_TRANSITION_INT_RC=$?
PI_T3A_TRANSITION_TERM_OUTPUT="$(run_pi_t3a_cleanup_signal_case \
  "$TEST_TMP/pi-t3a-transition-term" TERM transition 2>&1)"
PI_T3A_TRANSITION_TERM_RC=$?
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
[ "$PI_T3A_TERM_RC" -eq 143 ] \
  || fail_test "T3a TERM changed status $PI_T3A_TERM_RC: $PI_T3A_TERM_OUTPUT"
[ "$PI_T3A_READINESS_RC" -eq 1 ] \
  || fail_test "T3a readiness failure changed status $PI_T3A_READINESS_RC: $PI_T3A_READINESS_OUTPUT"
[ "$PI_T3A_CHILD_RC" -eq 70 ] \
  || fail_test "T3a child exit changed status $PI_T3A_CHILD_RC: $PI_T3A_CHILD_OUTPUT"
[ "$PI_T3A_PRE_ENABLE_RC" -eq 1 ] \
  || fail_test "pre-enable T3a failure changed status $PI_T3A_PRE_ENABLE_RC: $PI_T3A_PRE_ENABLE_OUTPUT"
[ "$PI_T3A_EVIDENCE_FAILURE_RC" -eq 72 ] \
  || fail_test "T3a propulsion-evidence failure changed status $PI_T3A_EVIDENCE_FAILURE_RC: $PI_T3A_EVIDENCE_FAILURE_OUTPUT"
[ "$PI_T3A_CLEANUP_INT_RC" -eq 130 ] \
  || fail_test "T3a cleanup INT changed status $PI_T3A_CLEANUP_INT_RC: $PI_T3A_CLEANUP_INT_OUTPUT"
[ "$PI_T3A_CLEANUP_TERM_RC" -eq 143 ] \
  || fail_test "T3a cleanup TERM changed status $PI_T3A_CLEANUP_TERM_RC: $PI_T3A_CLEANUP_TERM_OUTPUT"
[ "$PI_T3A_TRANSITION_INT_RC" -eq 130 ] \
  || fail_test "T3a cleanup-transition INT changed status $PI_T3A_TRANSITION_INT_RC: $PI_T3A_TRANSITION_INT_OUTPUT"
[ "$PI_T3A_TRANSITION_TERM_RC" -eq 143 ] \
  || fail_test "T3a cleanup-transition TERM changed status $PI_T3A_TRANSITION_TERM_RC: $PI_T3A_TRANSITION_TERM_OUTPUT"
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
for abnormal_case in term readiness child; do
  case_dir="$TEST_TMP/pi-t3a-$abnormal_case"
  output_variable="PI_T3A_${abnormal_case^^}_OUTPUT"
  abnormal_output="${!output_variable}"
  [ "$(grep -Fc 'REAL_FCU_T3A_MANUAL_GATE=safe-closeout' \
      <<<"$abnormal_output")" -eq 1 ] \
    || fail_test "T3a $abnormal_case did not prompt for safe closeout exactly once"
  [ "$(grep -Fc 'REAL_FCU_T3A_SAFE_CLOSEOUT=PASS' \
      <<<"$abnormal_output")" -eq 1 ] \
    || fail_test "T3a $abnormal_case did not retain exactly one closeout pass"
  grep -Fq 'REAL_FCU_FINAL_STATE=PASS connected=true armed=false' \
    <<<"$abnormal_output" \
    || fail_test "T3a $abnormal_case lost machine final-disarm evidence"
  grep -Fxq 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED' \
    "$case_dir/evidence/t3a_safe_closeout.txt" \
    || fail_test "T3a $abnormal_case lost its exact closeout phrase"
  [ "$(cat "$case_dir/closeout.trace")" = \
      $'final-state-capture\nstop-bridge\nstop-mavros\nstop-mavros-probe' ] \
    || fail_test "T3a $abnormal_case changed closeout order"
done
! grep -Fq 'REAL_FCU_T3A_MANUAL_GATE=safe-closeout' \
  <<<"$PI_T3A_PRE_ENABLE_OUTPUT" \
  || fail_test 'T3a prompted for safe closeout before propulsion was enabled'
[ ! -e "$TEST_TMP/pi-t3a-pre-enable/evidence/t3a_safe_closeout.txt" ] \
  || fail_test 'pre-enable T3a failure created false closeout evidence'
[ "$(grep -Fc 'REAL_FCU_T3A_MANUAL_GATE=safe-closeout' \
    <<<"$PI_T3A_EVIDENCE_FAILURE_OUTPUT")" -eq 1 ] \
  || fail_test 'T3a propulsion-evidence failure did not prompt for safe closeout exactly once'
grep -Fxq 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED' \
  "$TEST_TMP/pi-t3a-evidence-failure/evidence/t3a_safe_closeout.txt" \
  || fail_test 'T3a propulsion-evidence failure lost its exact closeout phrase'
for cleanup_signal in int term; do
  signal_output_variable="PI_T3A_CLEANUP_${cleanup_signal^^}_OUTPUT"
  cleanup_signal_output="${!signal_output_variable}"
  grep -Fq \
    "cleanup signal=${cleanup_signal^^} received; continuing fail-closed teardown" \
    <<<"$cleanup_signal_output" \
    || fail_test "T3a cleanup ${cleanup_signal^^} was not retained"
  grep -Fq 'REAL_FCU_T3A_SAFE_CLOSEOUT=FAIL confirmation=missing-or-invalid' \
    <<<"$cleanup_signal_output" \
    || fail_test "T3a cleanup ${cleanup_signal^^} did not fail closeout"
  [ "$(cat "$TEST_TMP/pi-t3a-cleanup-$cleanup_signal/closeout.trace")" = \
      $'final-state-capture\nstop-bridge\nstop-mavros\nstop-mavros-probe' ] \
    || fail_test "T3a cleanup ${cleanup_signal^^} did not reach every child stop"
done
for cleanup_signal in int term; do
  signal_output_variable="PI_T3A_TRANSITION_${cleanup_signal^^}_OUTPUT"
  cleanup_signal_output="${!signal_output_variable}"
  grep -Fq \
    "cleanup signal=${cleanup_signal^^} received; continuing fail-closed teardown" \
    <<<"$cleanup_signal_output" \
    || fail_test "T3a cleanup-transition ${cleanup_signal^^} was not retained"
  grep -Fq 'REAL_FCU_T3A_SAFE_CLOSEOUT=FAIL confirmation=missing-or-invalid' \
    <<<"$cleanup_signal_output" \
    || fail_test "T3a cleanup-transition ${cleanup_signal^^} did not fail closeout"
  [ "$(cat "$TEST_TMP/pi-t3a-transition-$cleanup_signal/closeout.trace")" = \
      $'final-state-capture\nstop-bridge\nstop-mavros\nstop-mavros-probe' ] \
    || fail_test "T3a cleanup-transition ${cleanup_signal^^} did not reach every child stop"
done
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
PI_T3A_OPERATOR_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-t3a-operator-success" 1 1 1 1 1 run-t3a 2>&1 \
  <<< 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED')"
PI_T3A_OPERATOR_RC=$?
PI_T3A_UNCONFIRMED_OUTPUT="$(run_pi_operator_stop_case \
  "$TEST_TMP/pi-t3a-operator-unconfirmed" 1 1 1 1 1 run-t3a \
  </dev/null 2>&1)"
PI_T3A_UNCONFIRMED_RC=$?
set -e
[ "$WS_OPERATOR_RC" -eq 0 ] && [ "$PI_OPERATOR_RC" -eq 0 ] \
  || fail_test "normal operator stop remained non-zero: workstation=$WS_OPERATOR_RC Pi=$PI_OPERATOR_RC workstation_output=[$WS_OPERATOR_OUTPUT] Pi_output=[$PI_OPERATOR_OUTPUT]"
[ "$PI_T2A_OPERATOR_RC" -eq 0 ] \
  || fail_test "T2a operator stop remained non-zero: $PI_T2A_OPERATOR_OUTPUT"
[ "$PI_T3A_OPERATOR_RC" -eq 0 ] \
  || fail_test "T3a safe operator stop remained non-zero: $PI_T3A_OPERATOR_OUTPUT"
[ "$PI_T3A_UNCONFIRMED_RC" -ne 0 ] \
  || fail_test 'T3a operator stop passed without the safe-closeout phrase'
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
grep -Fq 'REAL_FCU_T3A_SAFE_CLOSEOUT=PASS neutral=true estop=true disarmed=true safety=ON propulsion=isolated' \
  <<<"$PI_T3A_OPERATOR_OUTPUT" \
  || fail_test 'T3a operator stop omitted the safe-closeout marker'
[ "$(grep -Fc 'REAL_FCU_T3A_MANUAL_GATE=safe-closeout' \
    <<<"$PI_T3A_OPERATOR_OUTPUT")" -eq 1 ] \
  || fail_test 'T3a normal operator stop prompted for safe closeout more than once'
T3A_OPERATOR_CLOSEOUT_LINE="$(line_number_once "$PI_T3A_OPERATOR_OUTPUT" \
  'REAL_FCU_T3A_SAFE_CLOSEOUT=PASS' 'T3a operator closeout pass')"
T3A_OPERATOR_FINAL_STATE_LINE="$(line_number_once "$PI_T3A_OPERATOR_OUTPUT" \
  'REAL_FCU_FINAL_STATE=PASS' 'T3a operator final-state pass')"
[ "$T3A_OPERATOR_CLOSEOUT_LINE" -lt "$T3A_OPERATOR_FINAL_STATE_LINE" ] \
  || fail_test 'T3a operator closeout phrase was not retained before final-state capture'
grep -Fq 'REAL_FCU_PI_EXIT status=0 cleanup_rc=0' \
  <<<"$PI_T3A_OPERATOR_OUTPUT" || fail_test 'T3a operator stop did not pass'
[ "$(grep -Fc 'REAL_FCU_T3A_SAFE_CLOSEOUT=FAIL confirmation=missing-or-invalid' \
    <<<"$PI_T3A_UNCONFIRMED_OUTPUT")" -eq 1 ] \
  || fail_test 'T3a missing safe-closeout phrase was not reported'
[ "$(grep -Fc 'REAL_FCU_T3A_MANUAL_GATE=safe-closeout' \
    <<<"$PI_T3A_UNCONFIRMED_OUTPUT")" -eq 1 ] \
  || fail_test 'T3a missing safe-closeout phrase was prompted more than once'
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
grep -Fxq 'NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED' \
  "$TEST_TMP/pi-t3a-operator-success/evidence/t3a_safe_closeout.txt" \
  || fail_test 'T3a safe-closeout evidence is missing'
[ "$(cat "$TEST_TMP/pi-t3a-operator-success/stop.trace")" = \
    $'bridge\nmavros\nmavros-probe' ] \
  || fail_test 'T3a changed the established Pi child stop order'
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
