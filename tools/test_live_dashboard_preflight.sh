#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${1:-$SCRIPT_DIR/live_dashboard_preflight.sh}"
HELPER="$SCRIPT_DIR/pi_live_hailo_mavlink_dashboard.sh"
WIKI="$SCRIPT_DIR/../wiki/Live_Hailo_MAVLink_Dashboard_Testing.md"
EXPECTED_PREFLIGHT_SHA256='d4fc4a72457d8d0d73ef3804023028239036abaaf18a3e4962cb8bd7f2afdbd6'
CASE_COUNT=0

# Production selectors are exercised explicitly below. Keep the default
# fixtures deterministic even when the caller certifies a configured live run.
unset LIVE_SSID LIVE_PI_WINDOW_MODE LIVE_RUN_SECONDS
unset LIVE_FCU_TO_VRX_FANOUT LIVE_FCU_TO_VRX_MEASUREMENT
unset LIVE_ARMED_OBSERVATION LIVE_ARMED_OBSERVATION_MAX_SECONDS
unset LIVE_ARMED_OBSERVATION_FINAL_SECONDS LIVE_ARMED_OBSERVATION_STALE_SECONDS
unset LIVE_ARMED_OBSERVATION_LEFT_CHANNEL LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN
unset LIVE_ARMED_OBSERVATION_LEFT_TRIM LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX
unset LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN
unset LIVE_ARMED_OBSERVATION_RIGHT_TRIM LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass_case() {
  CASE_COUNT=$((CASE_COUNT + 1))
}

require_literal() {
  local literal="$1"
  grep -Fq -- "$literal" "$PREFLIGHT" || fail "missing contract: $literal"
}

extract_function() {
  local name="$1"
  awk -v start="${name}() {" '
    $0 == start { capture = 1 }
    capture { print }
    capture && $0 == "}" { exit }
  ' "$PREFLIGHT"
}

[ -r "$PREFLIGHT" ] || fail "preflight script missing: $PREFLIGHT"
[ -r "$WIKI" ] || fail "live-dashboard runbook missing: $WIKI"
bash -n "$PREFLIGHT"

ACTUAL_PREFLIGHT_SHA256="$(sha256sum "$PREFLIGHT" | awk '{print $1}')"
[ "$ACTUAL_PREFLIGHT_SHA256" = "$EXPECTED_PREFLIGHT_SHA256" ] \
  || fail "preflight checksum changed: $ACTUAL_PREFLIGHT_SHA256"
PINNED_HELPER_SHA256="$(awk -F"'" '
  /^EXPECTED_HELPER_SHA256=/ { print $2; exit }
' "$PREFLIGHT")"
ACTUAL_HELPER_SHA256="$(sha256sum "$HELPER" | awk '{print $1}')"
[ -n "$PINNED_HELPER_SHA256" ] \
  || fail 'preflight helper checksum pin is missing'
[ "$PINNED_HELPER_SHA256" = "$ACTUAL_HELPER_SHA256" ] \
  || fail "preflight helper checksum is stale: pinned=$PINNED_HELPER_SHA256 actual=$ACTUAL_HELPER_SHA256"
pass_case
grep -Fqx -- \
  "| Supervisor SHA-256 | \`$EXPECTED_PREFLIGHT_SHA256\` |" "$WIKI" \
  || fail 'live-dashboard runbook supervisor checksum is stale'
grep -Fq '`WORKSTATION_NODE_SNAPSHOT_RETRY` followed by `WORKSTATION_NODE_RECOVERY=PASS`' \
  "$WIKI" \
  || fail 'live-dashboard runbook omits transient workstation-node recovery evidence'
grep -Fq 'the rosbridge `user interrupted with ctrl-c (SIGINT)` line as a discriminator' \
  "$WIKI" \
  || fail 'live-dashboard runbook omits the invalid SIGINT discriminator warning'
! grep -Fq 'The signature of a reversed order, observed 07/08/2026' "$WIKI" \
  || fail 'live-dashboard runbook retains the falsified 07/08 stop-order claim'

require_literal "EXPECTED_HELPER_SHA256='ca0c1ff834ac347a04e8a59a01a85c05abe78d939e2083397c2f121a9b24314e'"
require_literal 'EXPECTED_SSID="${LIVE_SSID:-IoT IMT Nord Europe}"'
require_literal 'PI_WINDOW_MODE="${LIVE_PI_WINDOW_MODE:-resizable}"'
require_literal 'FCU_TO_VRX_FANOUT="${LIVE_FCU_TO_VRX_FANOUT:-0}"'
require_literal 'DISARMED_MEASUREMENT="${LIVE_FCU_TO_VRX_MEASUREMENT:-0}"'
require_literal 'ARMED_OBSERVATION="${LIVE_ARMED_OBSERVATION:-0}"'
require_literal 'ARMED_OBSERVATION_MAX_SECONDS="${LIVE_ARMED_OBSERVATION_MAX_SECONDS:-}"'
require_literal 'ARMED_OBSERVATION_STALE_SECONDS="${LIVE_ARMED_OBSERVATION_STALE_SECONDS:-}"'
require_literal 'RUN_SECONDS="${LIVE_RUN_SECONDS:-}"'
require_literal 'python3 "$FCU_TO_VRX_EVIDENCE" observe-pi \'
require_literal '--output "$RUN_DIR/fcu_to_vrx_pi_events.jsonl" \'
require_literal '--left-min "$ARMED_OBSERVATION_LEFT_PWM_MIN" \'
require_literal 'FCU_TO_VRX_INGRESS_PORT=14556'
require_literal 'validate_pi_window_selectors() {'
require_literal 'LIVE_PI_WINDOW_MODE must be resizable or fullscreen'
require_literal 'LIVE_FCU_TO_VRX_FANOUT must be 0 or 1'
require_literal 'reject_conflicting_processes workstation "${WORKSTATION_CONFLICT_PATTERNS[@]}"'
require_literal 'reject_conflicting_processes Pi "${PI_CONFLICT_PATTERNS[@]}"'
require_literal 'pgrep -af -- "$pattern"'
require_literal 'case "$pattern" in'
require_literal 'process pattern contains alternation'
require_literal 'LIVE_FCU_TO_VRX_FANOUT="$FCU_TO_VRX_FANOUT" \'
require_literal '"$HELPER" --preflight-only'
require_literal 'W1_PREFLIGHT=PASS'
require_literal 'python3 -m unittest "$SCRIPT_DIR/test_pi_live_armed_observation_monitor.py"'
require_literal 'tests=dashboard,helper,armed-monitor,preflight'
require_literal 'P1_PREFLIGHT=PASS'
require_literal 'set +u'
require_literal 'source "$ROS_SETUP" || source_rc=$?'
require_literal 'set -u'
require_literal 'export ROS_DOMAIN_ID="$LIVE_DOMAIN_ID"'
require_literal 'export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET'
require_literal 'unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER'
require_literal 'unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE'
require_literal 'unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI'
require_literal 'for command in awk bash curl date grep ip mkdir nmcli pgrep ps python3 \'
require_literal 'setsid sha256sum ss tee tr; do'
require_literal 'require_command ros2'
require_literal "grep -Fxq '/rosapi/topics_for_type'"
require_literal 'all_expected_publishers_present'
require_literal 'ARRIVAL_TIMEOUT_SECONDS="${LIVE_ARRIVAL_TIMEOUT_SECONDS:-360}"'
require_literal 'ARRIVAL_SAMPLE_SECONDS="${LIVE_ARRIVAL_SAMPLE_SECONDS:-10}"'
require_literal 'PI_HOLD_AFTER_WINDOW=1'
require_literal 'run_post_service_phases'
require_literal 'WORKSTATION_RUNTIME_PREFLIGHT=PASS'
require_literal 'if [ "$pgid" = "$SUPERVISOR_PGID" ]; then'
require_literal 'refusing supervisor process group'
require_literal 'trap cleanup EXIT'
require_literal 'teardown_workstation_services || cleanup_rc=$?'
require_literal 'trap - EXIT ERR'
require_literal "trap ':' INT TERM"
require_literal '1:workstation) run_workstation_preflight ;;'
require_literal '1:run) run_workstation_supervisor ;;'
require_literal '2:pi) run_pi_preflight "$2" ;;'
require_literal '1:sitl) run_sitl_digital_twin_entry ;;'
require_literal 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then'

PREFLIGHT_FANOUT_PORT="$(awk -F= '$1 == "FCU_TO_VRX_INGRESS_PORT" { print $2 }' "$PREFLIGHT")"
HELPER_FANOUT_PORT="$(awk -F= '$1 == "FCU_TO_VRX_INGRESS_PORT" { print $2 }' "$HELPER")"
[[ "$PREFLIGHT_FANOUT_PORT" =~ ^[1-9][0-9]*$ ]] \
  || fail 'preflight fanout ingress port is invalid'
[ "$PREFLIGHT_FANOUT_PORT" = "$HELPER_FANOUT_PORT" ] \
  || fail "fanout ingress port drift: preflight=$PREFLIGHT_FANOUT_PORT helper=$HELPER_FANOUT_PORT"

PI_COMMAND_OUTPUT="$(bash -c '
  source "$1"
  WORKSTATION_IP=10.100.253.235
  print_pi_command
' _ "$PREFLIGHT")"
PI_COMMAND_BLOCK="$(sed -n '/^($/,/^)$/{p}' <<<"$PI_COMMAND_OUTPUT")"
[ -n "$PI_COMMAND_BLOCK" ] || fail 'printed Pi command block missing'
bash -n <<<"$PI_COMMAND_BLOCK"
grep -Fq 'ca0c1ff834ac347a04e8a59a01a85c05abe78d939e2083397c2f121a9b24314e' \
  <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not verify the helper pin'
grep -Fq 'LIVE_HOLD_AFTER_WINDOW=1' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not enable the monitored hold'
grep -Fq 'LIVE_FCU_TO_VRX_FANOUT=0' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not keep FCU-to-VRX fanout disabled by default'
grep -Fq 'HAILO_LOCAL_DISPLAY=1' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not enable the Pi desktop Hailo window'
grep -Fq 'HAILO_LOCAL_WINDOW_MODE=resizable' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not select resizable Hailo presentation'
grep -Fq 'xdg-user-dir DESKTOP' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not resolve the Pi Desktop'
grep -Fq '[ -n "$PI_HOME" ] && [ -d "$PI_HOME" ]' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not validate the canonical Pi home'
grep -Fq 'readlink -f -- "$PI_DESKTOP"' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not canonicalize the Pi Desktop'
grep -Fq '[ "$PI_DESKTOP" != "$PI_HOME" ]' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not require a dedicated Pi Desktop'
grep -Fq 'PI_HELPER="$PI_DESKTOP/pi_live_hailo_mavlink_dashboard.sh"' \
  <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not select the Desktop helper'
grep -Fq 'HAILO_DEMO_ROOT="$PI_RUNTIME_ROOT"' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not preserve the Hailo runtime root'
grep -Fq '"$PI_HELPER"' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not execute the absolute Desktop helper'
grep -Fq "\\n' 'ca0c1ff834ac347a04e8a59a01a85c05abe78d939e2083397c2f121a9b24314e' \"\$PI_HELPER\" | sha256sum -c -" \
  <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi checksum format contains a literal line break'
! grep -Fq './pi_live_hailo_mavlink_dashboard.sh' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command still executes a runtime-root helper copy'
grep -Fq 'LIVE_SSID=IoT\ IMT\ Nord\ Europe' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command does not carry the default IoT SSID'
! grep -Fq 'live_dashboard_preflight.sh' <<<"$PI_COMMAND_BLOCK" \
  || fail 'printed Pi command reintroduced the Pi-side preflight'

PI_COMMAND_OVERRIDE_OUTPUT="$(
  LIVE_SSID="Test Lab's IoT" \
  LIVE_PI_WINDOW_MODE=fullscreen \
  LIVE_FCU_TO_VRX_FANOUT=1 \
  bash -c '
  source "$1"
  WORKSTATION_IP=192.0.2.10
  print_pi_command
' _ "$PREFLIGHT")"
PI_COMMAND_OVERRIDE_BLOCK="$(sed -n '/^($/,/^)$/{p}' <<<"$PI_COMMAND_OVERRIDE_OUTPUT")"
EXPECTED_OVERRIDE_QUOTED="$(printf '%q' "Test Lab's IoT")"
bash -n <<<"$PI_COMMAND_OVERRIDE_BLOCK"
grep -Fq "LIVE_SSID=$EXPECTED_OVERRIDE_QUOTED" <<<"$PI_COMMAND_OVERRIDE_BLOCK" \
  || fail 'printed Pi command did not shell-quote the SSID override'
grep -Fq 'HAILO_LOCAL_WINDOW_MODE=fullscreen' <<<"$PI_COMMAND_OVERRIDE_BLOCK" \
  || fail 'printed Pi command did not carry the fullscreen selector'
grep -Fq 'LIVE_FCU_TO_VRX_FANOUT=1' <<<"$PI_COMMAND_OVERRIDE_BLOCK" \
  || fail 'printed Pi command did not carry the enabled fanout selector'

PI_COMMAND_ARMED_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_ARMED_OBSERVATION=1 \
  LIVE_ARMED_OBSERVATION_MAX_SECONDS=20 \
  LIVE_ARMED_OBSERVATION_FINAL_SECONDS=25 \
  LIVE_ARMED_OBSERVATION_STALE_SECONDS=7 \
  LIVE_RUN_SECONDS=300 \
  LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
  LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.20
    print_pi_command
  ' _ "$PREFLIGHT")"
PI_COMMAND_ARMED_BLOCK="$(sed -n '/^($/,/^)$/{p}' <<<"$PI_COMMAND_ARMED_OUTPUT")"
bash -n <<<"$PI_COMMAND_ARMED_BLOCK"
for literal in \
  'LIVE_HOLD_AFTER_WINDOW=0' \
  'LIVE_FCU_TO_VRX_FANOUT=1' \
  'LIVE_ARMED_OBSERVATION=1' \
  'LIVE_ARMED_OBSERVATION_MAX_SECONDS=20' \
  'LIVE_ARMED_OBSERVATION_FINAL_SECONDS=25' \
  'LIVE_ARMED_OBSERVATION_STALE_SECONDS=7' \
  'LIVE_RUN_SECONDS=300' \
  'LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3' \
  'LIVE_ARMED_OBSERVATION_LEFT_TRIM=800' \
  'LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1' \
  'LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800'; do
  grep -Fq "$literal" <<<"$PI_COMMAND_ARMED_BLOCK" \
    || fail "armed-observation Pi command is missing: $literal"
done

PI_COMMAND_UNBOUNDED_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_ARMED_OBSERVATION=1 \
  LIVE_ARMED_OBSERVATION_MAX_SECONDS=0 \
  LIVE_ARMED_OBSERVATION_FINAL_SECONDS=25 \
  LIVE_ARMED_OBSERVATION_STALE_SECONDS=7 \
  LIVE_RUN_SECONDS=0 \
  LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
  LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.20
    print_pi_command
  ' _ "$PREFLIGHT")"
PI_COMMAND_UNBOUNDED_BLOCK="$(
  sed -n '/^($/,/^)$/{p}' <<<"$PI_COMMAND_UNBOUNDED_OUTPUT"
)"
bash -n <<<"$PI_COMMAND_UNBOUNDED_BLOCK"
for literal in \
  'LIVE_RUN_SECONDS=0' \
  'LIVE_ARMED_OBSERVATION_MAX_SECONDS=0' \
  'LIVE_HOLD_AFTER_WINDOW=1' \
  'HAILO_LOCAL_WINDOW_MODE=resizable'; do
  grep -Fq "$literal" <<<"$PI_COMMAND_UNBOUNDED_BLOCK" \
    || fail "unbounded armed-observation Pi command is missing: $literal"
done
pass_case

for mismatched_pair in '0:20' '300:0'; do
  IFS=: read -r bad_run bad_max <<<"$mismatched_pair"
  set +e
  MISMATCHED_UNBOUNDED_OUTPUT="$(
    LIVE_FCU_TO_VRX_FANOUT=1 \
    LIVE_ARMED_OBSERVATION=1 \
    LIVE_ARMED_OBSERVATION_MAX_SECONDS="$bad_max" \
    LIVE_ARMED_OBSERVATION_FINAL_SECONDS=25 \
    LIVE_ARMED_OBSERVATION_STALE_SECONDS=7 \
    LIVE_RUN_SECONDS="$bad_run" \
    LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
    LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
    LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
    LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
    LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
    LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
    LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
    LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
    bash -c '
      source "$1"
      WORKSTATION_IP=192.0.2.20
      print_pi_command
    ' _ "$PREFLIGHT" 2>&1
  )"
  MISMATCHED_UNBOUNDED_RC=$?
  set -e
  [ "$MISMATCHED_UNBOUNDED_RC" -ne 0 ] \
    || fail "mismatched unbounded selectors were accepted: $mismatched_pair"
  grep -Fq 'LIVE_RUN_SECONDS and LIVE_ARMED_OBSERVATION_MAX_SECONDS must both be 0 or both be positive' \
    <<<"$MISMATCHED_UNBOUNDED_OUTPUT" \
    || fail "mismatched unbounded selectors were not identified: $mismatched_pair"
done
pass_case

PI_COMMAND_MEASUREMENT_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_FCU_TO_VRX_MEASUREMENT=1 \
  LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
  LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.21
    print_pi_command
  ' _ "$PREFLIGHT")"
PI_COMMAND_MEASUREMENT_BLOCK="$(
  sed -n '/^($/,/^)$/{p}' <<<"$PI_COMMAND_MEASUREMENT_OUTPUT"
)"
bash -n <<<"$PI_COMMAND_MEASUREMENT_BLOCK"
for literal in \
  'LIVE_HOLD_AFTER_WINDOW=1' \
  'LIVE_FCU_TO_VRX_FANOUT=1' \
  'LIVE_ARMED_OBSERVATION=0'; do
  grep -Fq "$literal" <<<"$PI_COMMAND_MEASUREMENT_BLOCK" \
    || fail "disarmed-measurement Pi command is missing: $literal"
done
pass_case

MEASUREMENT_SERVICE_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_FCU_TO_VRX_MEASUREMENT=1 \
  LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
  LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
  bash -c '
    source "$1"
    RUN_DIR=/tmp/fcu-to-vrx-measurement-test
    start_child() { printf "child=%s %s\n" "$1" "${*:3}"; }
    log() { printf "%s\n" "$*"; }
    start_workstation_services
  ' _ "$PREFLIGHT"
)"
if grep -Fq 'child=pi-evidence-observer' <<<"$MEASUREMENT_SERVICE_OUTPUT"; then
  fail 'disarmed measurement started its subscriber before Pi publishers existed'
fi

MEASUREMENT_OBSERVER_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_FCU_TO_VRX_MEASUREMENT=1 \
  LIVE_ARMED_OBSERVATION_LEFT_CHANNEL=3 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_LEFT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_LEFT_PWM_MAX=2200 \
  LIVE_ARMED_OBSERVATION_RIGHT_CHANNEL=1 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MIN=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_TRIM=800 \
  LIVE_ARMED_OBSERVATION_RIGHT_PWM_MAX=2200 \
  bash -c '
    source "$1"
    RUN_DIR=/tmp/fcu-to-vrx-measurement-test
    start_child() { printf "child=%s %s\n" "$1" "${*:3}"; }
    log() { printf "%s\n" "$*"; }
    start_pi_evidence_observer
  ' _ "$PREFLIGHT"
)"
grep -Fq 'child=pi-evidence-observer' <<<"$MEASUREMENT_OBSERVER_OUTPUT" \
  || fail 'disarmed measurement did not start its observer after Pi publishers'
grep -Fq -- '--stale-seconds 0' <<<"$MEASUREMENT_OBSERVER_OUTPUT" \
  || fail 'disarmed measurement observer was not record-only'
grep -Fq 'FCU_TO_VRX_PI_OBSERVER_STARTED mode=disarmed-measurement stale_seconds=0' \
  <<<"$MEASUREMENT_OBSERVER_OUTPUT" \
  || fail 'disarmed measurement observer marker is missing'

MEASUREMENT_ARRIVAL_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_FCU_TO_VRX_MEASUREMENT=1 \
  bash -c '
    source "$1"
    STOP_REQUESTED=0
    ARRIVAL_TIMEOUT_SECONDS=2
    EXPECTED_TOPICS=()
    EXPECTED_TOPIC_TYPES=()
    EXPECTED_TOPIC_RELIABILITY=()
    EXPECTED_TOPIC_DEPTH=()
    monitor_workstation_once() { return 0; }
    all_expected_publishers_present() { return 0; }
    start_pi_evidence_observer() { printf "observer-started\n"; }
    wait_for_pi_observer_ready() { printf "observer-ready\n"; }
    wait_for_pi_data_arrival
  ' _ "$PREFLIGHT"
)"
[ "$MEASUREMENT_ARRIVAL_OUTPUT" = $'observer-started\nobserver-ready' ] \
  || fail 'Pi evidence observer was not started after publisher arrival and before its READY wait'
pass_case

set +e
INVALID_MEASUREMENT_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_FCU_TO_VRX_MEASUREMENT=1 \
  LIVE_ARMED_OBSERVATION=1 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.21
    print_pi_command
  ' _ "$PREFLIGHT" 2>&1
)"
INVALID_MEASUREMENT_RC=$?
set -e
[ "$INVALID_MEASUREMENT_RC" -ne 0 ] \
  || fail 'disarmed measurement and armed observation were accepted together'
grep -Fq 'cannot both be enabled' <<<"$INVALID_MEASUREMENT_OUTPUT" \
  || fail 'incompatible observer modes were not identified'
pass_case

WORKSTATION_NODES_FUNCTION="$(extract_function workstation_nodes_present)"
[ -n "$WORKSTATION_NODES_FUNCTION" ] \
  || fail 'workstation node snapshot verifier is missing'
WORKSTATION_NODE_COUNTER="$(mktemp)"
printf '0\n' >"$WORKSTATION_NODE_COUNTER"
set +e
WORKSTATION_NODE_RECOVERY_OUTPUT="$(bash -c '
  eval "$1"
  counter_file="$2"
  ros2() {
    observed="$(cat "$counter_file")"
    observed=$((observed + 1))
    printf "%s\n" "$observed" >"$counter_file"
    if [ "$observed" -eq 1 ]; then
      printf "/rosbridge_websocket\n"
    else
      printf "/rosbridge_websocket\n/rosapi\n/web_video_server\n"
    fi
  }
  sleep() { :; }
  log() { printf "%s\n" "$*"; }
  workstation_nodes_present
' _ "$WORKSTATION_NODES_FUNCTION" "$WORKSTATION_NODE_COUNTER" 2>&1)"
WORKSTATION_NODE_RECOVERY_RC=$?
set -e
[ "$WORKSTATION_NODE_RECOVERY_RC" -eq 0 ] \
  || fail "transient workstation graph zero was not recovered: $WORKSTATION_NODE_RECOVERY_OUTPUT"
grep -Fq 'WORKSTATION_NODE_SNAPSHOT_RETRY' <<<"$WORKSTATION_NODE_RECOVERY_OUTPUT" \
  || fail 'workstation node retry did not emit its retry marker'
grep -Fq 'WORKSTATION_NODE_RECOVERY=PASS' <<<"$WORKSTATION_NODE_RECOVERY_OUTPUT" \
  || fail 'workstation node retry did not emit its recovery marker'
rm -f "$WORKSTATION_NODE_COUNTER"
pass_case
pass_case

set +e
MISSING_ARMED_VALUE_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=1 \
  LIVE_ARMED_OBSERVATION=1 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.20
    print_pi_command
  ' _ "$PREFLIGHT" 2>&1)"
MISSING_ARMED_VALUE_RC=$?
set -e
[ "$MISSING_ARMED_VALUE_RC" -ne 0 ] \
  || fail 'armed-observation emitter accepted missing live-read values'
grep -Fq 'LIVE_ARMED_OBSERVATION_MAX_SECONDS is required' \
  <<<"$MISSING_ARMED_VALUE_OUTPUT" \
  || fail 'missing armed-observation value was not identified'
pass_case
for invalid_case in 'stretch:LIVE_PI_WINDOW_MODE'; do
  IFS=: read -r bad_mode expected_error <<<"$invalid_case"
  set +e
  INVALID_SELECTOR_OUTPUT="$(
    LIVE_PI_WINDOW_MODE="$bad_mode" \
    bash -c '
      source "$1"
      WORKSTATION_IP=192.0.2.12
      print_pi_command
    ' _ "$PREFLIGHT" 2>&1
  )"
  INVALID_SELECTOR_RC=$?
  set -e
  [ "$INVALID_SELECTOR_RC" -ne 0 ] \
    || fail "invalid selector was accepted: $invalid_case"
  grep -Fq "$expected_error" <<<"$INVALID_SELECTOR_OUTPUT" \
    || fail "invalid selector did not identify $expected_error"

  set +e
  INVALID_RUNTIME_SELECTOR_OUTPUT="$(
    LIVE_PI_WINDOW_MODE="$bad_mode" \
    bash -c '
      source "$1"
      run_workstation_runtime_preflight
    ' _ "$PREFLIGHT" 2>&1
  )"
  INVALID_RUNTIME_SELECTOR_RC=$?
  set -e
  [ "$INVALID_RUNTIME_SELECTOR_RC" -ne 0 ] \
    || fail "runtime preflight accepted invalid selector: $invalid_case"
  grep -Fq "$expected_error" <<<"$INVALID_RUNTIME_SELECTOR_OUTPUT" \
    || fail "runtime preflight did not identify $expected_error"
  ! grep -Fq 'required command missing' <<<"$INVALID_RUNTIME_SELECTOR_OUTPUT" \
    || fail "runtime preflight used dependencies before selector validation"
done

set +e
INVALID_FANOUT_OUTPUT="$(
  LIVE_FCU_TO_VRX_FANOUT=2 \
  bash -c '
    source "$1"
    WORKSTATION_IP=192.0.2.12
    print_pi_command
  ' _ "$PREFLIGHT" 2>&1
)"
INVALID_FANOUT_RC=$?
set -e
[ "$INVALID_FANOUT_RC" -ne 0 ] \
  || fail 'printed Pi command accepted invalid FCU-to-VRX fanout selector'
grep -Fq 'LIVE_FCU_TO_VRX_FANOUT must be 0 or 1' <<<"$INVALID_FANOUT_OUTPUT" \
  || fail 'invalid fanout selector did not identify its variable'

set +e
PRE_READY_INTERRUPT_OUTPUT="$(bash -c '
  source "$1"
  SERVICES_UP=0
  on_supervisor_interrupt
' _ "$PREFLIGHT" 2>&1)"
PRE_READY_INTERRUPT_RC=$?
set -e
[ "$PRE_READY_INTERRUPT_RC" -eq 130 ] \
  || fail "pre-ready interrupt returned $PRE_READY_INTERRUPT_RC instead of 130"
POST_READY_INTERRUPT_OUTPUT="$(bash -c '
  source "$1"
  SERVICES_UP=1
  on_supervisor_interrupt
  [ "$STOP_REQUESTED" -eq 1 ]
' _ "$PREFLIGHT" 2>&1)"
grep -Fq 'stop requested; waiting for orderly workstation teardown' \
  <<<"$POST_READY_INTERRUPT_OUTPUT" \
  || fail 'post-ready interrupt did not request orderly teardown'

NETWORK_OUTPUT="$(bash -c '
  source "$1"
  nmcli() { printf "wlp7s0:yes:IoT IMT Nord Europe\n"; }
  ip() { printf "7: wlp7s0    inet 10.100.253.235/24 brd 10.100.253.255 scope global dynamic wlp7s0\n"; }
  resolve_workstation_network
  [ "$WORKSTATION_INTERFACE" = wlp7s0 ]
  [ "$WORKSTATION_IP" = 10.100.253.235 ]
' _ "$PREFLIGHT")"
grep -Fq 'workstation_ipv4=10.100.253.235 dev=wlp7s0' <<<"$NETWORK_OUTPUT" \
  || fail 'active Wi-Fi IPv4 was not selected deterministically'
set +e
MULTI_NETWORK_OUTPUT="$(bash -c '
  source "$1"
  nmcli() {
    printf "wlp7s0:yes:IoT IMT Nord Europe\n"
    printf "wlan1:yes:IoT IMT Nord Europe\n"
  }
  ip() { return 0; }
  resolve_workstation_network
' _ "$PREFLIGHT" 2>&1)"
MULTI_NETWORK_RC=$?
set -e
[ "$MULTI_NETWORK_RC" -eq 1 ] \
  || fail "multiple active Wi-Fi interfaces returned $MULTI_NETWORK_RC instead of 1"
grep -Fq 'expected one active interface' <<<"$MULTI_NETWORK_OUTPUT" \
  || fail 'multiple active Wi-Fi interfaces were not reported'

PUBLISHER_QUERY_CODE="$(extract_function topic_has_publisher)
$(extract_function all_expected_publishers_present)"
! grep -Fq 'topic echo' <<<"$PUBLISHER_QUERY_CODE" \
  || fail 'publisher-presence gate creates a subscription'
! grep -Fq 'ros2 topic echo' "$PREFLIGHT" \
  || fail 'arrival gate relies on an unbounded ros2 topic echo'

RATE_MONITOR_OUTPUT="$(bash -c '
  source "$1"
  MONITOR_CALLS=0
  PROBE_CALLS=0
  date() { return 0; }
  ros2() { return 0; }
  python3() { PROBE_CALLS=$((PROBE_CALLS + 1)); }
  monitor_workstation_once() {
    MONITOR_CALLS=$((MONITOR_CALLS + 1))
    [ "$MONITOR_CALLS" -lt 16 ]
  }
  if run_rate_probe_body; then
    fail "rate body ignored a local-service failure"
  else
    rc=$?
  fi
  [ "$rc" -eq 1 ] || fail "rate monitor returned $rc instead of 1"
  [ "$PROBE_CALLS" -eq 1 ] \
    || fail "rate body did not stop after the monitored failure"
' _ "$PREFLIGHT" 2>&1)"
RATE_PIPELINE_OUTPUT="$(bash -c '
  source "$1"
  RATE_LOG=/dev/null
  run_rate_probe_body() { return 41; }
  if run_rate_probes; then
    fail "rate pipeline discarded a nonzero probe status"
  else
    rc=$?
  fi
  [ "$rc" -eq 41 ] || fail "rate pipeline returned $rc instead of 41"

  SERVICES_UP=1
  STOP_REQUESTED=0
  trap on_supervisor_interrupt INT
  run_rate_probe_body() {
    kill -INT "$$"
    [ "$STOP_REQUESTED" -eq 0 ] || return 130
    fail "rate body continued after interrupt"
  }
  if run_rate_probes >/dev/null 2>&1; then
    fail "rate pipeline ignored an interrupt"
  else
    rc=$?
  fi
  [ "$rc" -eq 130 ] || fail "interrupted rate pipeline returned $rc instead of 130"
  [ "$STOP_REQUESTED" -eq 1 ] || fail "rate interrupt did not reach supervisor state"
' _ "$PREFLIGHT" 2>&1)"
[ -z "$RATE_PIPELINE_OUTPUT" ] \
  || fail "rate-pipeline status case produced unexpected output: $RATE_PIPELINE_OUTPUT"
pass_case

WORKSTATION_ARRAY="$(sed -n '/^WORKSTATION_CONFLICT_PATTERNS=(/,/^)/p' "$PREFLIGHT")"
PI_ARRAY="$(sed -n '/^PI_CONFLICT_PATTERNS=(/,/^)/p' "$PREFLIGHT")"
[ -n "$WORKSTATION_ARRAY" ] || fail 'workstation conflict array missing'
[ -n "$PI_ARRAY" ] || fail 'Pi conflict array missing'
! grep -Fq '|' <<<"$WORKSTATION_ARRAY" \
  || fail 'workstation conflict array uses a combined alternation'
! grep -Fq '|' <<<"$PI_ARRAY" \
  || fail 'Pi conflict array uses a combined alternation'
eval "$WORKSTATION_ARRAY"
eval "$PI_ARRAY"
EXPECTED_WORKSTATION_PATTERNS=(
  'rosbridge'
  'web_video_server'
  'serve_dashboard.py'
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'gazebo'
  'gz sim'
  'waypoint_planner'
  'pi_live_hailo_mavlink_dashboard.sh'
  'fcu_to_vrx_evidence.py observe-pi'
)
EXPECTED_PI_PATTERNS=(
  'realsense2_camera'
  'mavproxy'
  'MAVProxy'
  'mavros'
  'pi_live_hailo_mavlink_dashboard.sh'
)
[ "${#WORKSTATION_CONFLICT_PATTERNS[@]}" -eq "${#EXPECTED_WORKSTATION_PATTERNS[@]}" ] \
  || fail 'workstation conflict-pattern count changed'
[ "${#PI_CONFLICT_PATTERNS[@]}" -eq "${#EXPECTED_PI_PATTERNS[@]}" ] \
  || fail 'Pi conflict-pattern count changed'
for index in "${!EXPECTED_WORKSTATION_PATTERNS[@]}"; do
  [ "${WORKSTATION_CONFLICT_PATTERNS[$index]}" = "${EXPECTED_WORKSTATION_PATTERNS[$index]}" ] \
    || fail "workstation conflict pattern changed at index $index"
done
for index in "${!EXPECTED_PI_PATTERNS[@]}"; do
  [ "${PI_CONFLICT_PATTERNS[$index]}" = "${EXPECTED_PI_PATTERNS[$index]}" ] \
    || fail "Pi conflict pattern changed at index $index"
done
pass_case

CONFLICT_FUNCTION="$(extract_function reject_conflicting_processes)"
[ -n "$CONFLICT_FUNCTION" ] || fail 'conflict function was not extractable'

NO_MATCH_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  pgrep() { return 1; }
  reject_conflicting_processes workstation rosbridge mavros pi_live_hailo_mavlink_dashboard.sh
  printf "NO_MATCH=PASS\n"
' _ "$CONFLICT_FUNCTION")"
grep -Fxq 'NO_MATCH=PASS' <<<"$NO_MATCH_OUTPUT" \
  || fail 'no-match process scan did not pass'
pass_case

TRACE="$(mktemp)"
TEST_TMP="$(mktemp -d)"
trap 'rm -f "$TRACE"; rm -rf "$TEST_TMP"' EXIT
set +e
MATCH_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  TRACE_PATH="$2"
  pgrep() {
    local pattern="${*: -1}"
    printf "%s\n" "$pattern" >>"$TRACE_PATH"
    if [ "$pattern" = mavproxy ]; then
      printf "4242 mavproxy.py --master=/dev/ttyAMA0\n"
      return 0
    fi
    return 1
  }
  reject_conflicting_processes workstation rosbridge mavproxy pi_live_hailo_mavlink_dashboard.sh
' _ "$CONFLICT_FUNCTION" "$TRACE" 2>&1)"
MATCH_RC=$?
set -e
[ "$MATCH_RC" -eq 17 ] || fail "matching process scan exited $MATCH_RC instead of 17"
grep -Fq '4242 mavproxy.py --master=/dev/ttyAMA0' <<<"$MATCH_OUTPUT" \
  || fail 'matching process was not reported'
[ "$(wc -l <"$TRACE")" -eq 3 ] \
  || fail 'matching scan did not inspect each separate pattern'
pass_case

set +e
ERROR_OUTPUT="$(bash -c '
  eval "$1"
  fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
  pgrep() { return 2; }
  reject_conflicting_processes Pi mavros
' _ "$CONFLICT_FUNCTION" 2>&1)"
ERROR_RC=$?
set -e
[ "$ERROR_RC" -eq 17 ] || fail "pgrep-error case exited $ERROR_RC instead of 17"
grep -Fq 'cannot inspect Pi processes for pattern: mavros' <<<"$ERROR_OUTPUT" \
  || fail 'pgrep inspection error was treated as no match'
pass_case

for bad_pattern in '' 'rosbridge|mavros' $'rosbridge\nmavros'; do
  set +e
  BAD_OUTPUT="$(bash -c '
    eval "$1"
    fail() { printf "FAIL_STUB: %s\n" "$*" >&2; exit 17; }
    pgrep() { printf "PGREP_MUST_NOT_RUN\n"; return 0; }
    reject_conflicting_processes workstation "$2"
  ' _ "$CONFLICT_FUNCTION" "$bad_pattern" 2>&1)"
  BAD_RC=$?
  set -e
  [ "$BAD_RC" -eq 17 ] || fail "invalid-pattern case exited $BAD_RC instead of 17"
  ! grep -Fq 'PGREP_MUST_NOT_RUN' <<<"$BAD_OUTPUT" \
    || fail 'invalid process pattern reached pgrep'
  pass_case
done

MARKER_CASE_DIR="$TEST_TMP/marker"
mkdir -p "$MARKER_CASE_DIR"
set +e
MARKER_CASE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  CASE_DIR="$2"
  SUPERVISOR_POLL_SECONDS=0.02
  RATE_LOG="$CASE_DIR/rates.log"
  WATCHDOG_PID=""
  case_cleanup() {
    local rc=$? i
    trap - EXIT INT TERM
    set +e
    [ -z "$WATCHDOG_PID" ] || kill -TERM -- "-$WATCHDOG_PID" 2>/dev/null
    [ -z "$WATCHDOG_PID" ] || wait "$WATCHDOG_PID" 2>/dev/null
    for ((i=${#CHILD_NAMES[@]}-1; i>=0; i--)); do
      stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
        >/dev/null 2>&1
    done
    exit "$rc"
  }
  trap case_cleanup EXIT
  trap "exit 124" TERM
  setsid bash -c "sleep 5; kill -TERM \"\$1\" 2>/dev/null" _ "$$" &
  WATCHDOG_PID=$!

  RUN_MODE_OUTPUT="$(
    run_workstation_static_gate() { fail "run mode called static gate"; }
    run_workstation_runtime_preflight() {
      WORKSTATION_INTERFACE=wlp7s0
      WORKSTATION_IP=10.100.253.235
    }
    init_supervisor_state() {
      EMITTED_MARKERS=()
      SERVICES_UP=0
      STOP_REQUESTED=0
      FINAL_RC=0
      RUN_DIR="$CASE_DIR"
      RATE_LOG="$CASE_DIR/rates.log"
    }
    start_workstation_services() { return 0; }
    wait_for_workstation_services() { return 0; }
    print_pi_command() { return 0; }
    run_post_service_phases() { return 0; }
    cleanup() { printf "cleanup-called\n"; }
    run_workstation_supervisor
  )"
  [ "$(grep -Fc "WORKSTATION_RUNTIME_PREFLIGHT=PASS" <<<"$RUN_MODE_OUTPUT")" -eq 1 ] \
    || fail "run runtime-preflight marker was not emitted exactly once"
  ! grep -Fq "tests=" <<<"$RUN_MODE_OUTPUT" \
    || fail "run runtime-preflight marker claimed test execution"
  grep -Fxq "cleanup-called" <<<"$RUN_MODE_OUTPUT" \
    || fail "run supervisor did not hand off to its EXIT cleanup"

  RUN_DIR="$CASE_DIR"
  ARRIVAL_TIMEOUT_SECONDS=120
  PUBLISHER_CHECKS=0
  SAMPLE_COUNT=0
  SAMPLE_FAIL_AT=0
  SAMPLE_INTERRUPT_AT=0
  monitor_workstation_once() { return 0; }
  all_expected_publishers_present() {
    PUBLISHER_CHECKS=$((PUBLISHER_CHECKS + 1))
    [ "$PUBLISHER_CHECKS" -ge 3 ]
  }
  python3() {
    local duration="" argument
    [ "$PUBLISHER_CHECKS" -ge 3 ] \
      || fail "subscription started before publisher-only gate passed"
    [ "$1" = "$SCRIPT_DIR/rate_probe.py" ] \
      || fail "arrival gate did not call rate_probe.py"
    shift
    while [ "$#" -gt 0 ]; do
      argument="$1"
      shift
      if [ "$argument" = --duration ]; then
        [ "$#" -gt 0 ] || fail "arrival probe duration value missing"
        duration="$1"
        shift
      fi
    done
    [ "$duration" = "$ARRIVAL_SAMPLE_SECONDS" ] \
      || fail "arrival probe duration was $duration"
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
    if [ "$SAMPLE_INTERRUPT_AT" -eq "$SAMPLE_COUNT" ]; then
      on_supervisor_interrupt
      return 0
    fi
    [ "$SAMPLE_FAIL_AT" -ne "$SAMPLE_COUNT" ] || return 23
  }
  wait_for_pi_data_arrival
  [ "$SAMPLE_COUNT" -eq 7 ] || fail "arrival gate did not sample all seven topics"

  PUBLISHER_CHECKS=3
  SAMPLE_COUNT=0
  SAMPLE_FAIL_AT=3
  if wait_for_pi_data_arrival; then
    fail "failed arrival sample returned success"
  else
    rc=$?
  fi
  [ "$rc" -eq 23 ] || fail "failed arrival sample returned $rc instead of 23"
  [ "$SAMPLE_COUNT" -eq 3 ] || fail "arrival sampling continued after failure"

  FINAL_RC=0
  STOP_REQUESTED=0
  SERVICES_UP=1
  EMITTED_MARKERS=()
  PUBLISHER_CHECKS=3
  SAMPLE_COUNT=0
  SAMPLE_FAIL_AT=0
  SAMPLE_INTERRUPT_AT=1
  rm -f "$CASE_DIR/probe_forbidden"
  probe_must_not_run() { printf "called\n" >"$CASE_DIR/probe_forbidden"; }
  run_post_service_phases wait_for_pi_data_arrival probe_must_not_run \
    monitor_workstation_once stop_requested >"$CASE_DIR/interrupt.out" 2>&1
  [ "$SAMPLE_COUNT" -eq 1 ] || fail "arrival sampling continued after interrupt"
  [ "$STOP_REQUESTED" -eq 1 ] || fail "arrival interrupt did not request stop"
  [ ! -e "$CASE_DIR/probe_forbidden" ] || fail "probe ran after arrival interrupt"
  ! grep -Fq "PI_DATA_ARRIVED=PASS" "$CASE_DIR/interrupt.out" \
    || fail "arrival PASS printed after interrupt"
  ! grep -Fq "W5_RATE_PROBES=PASS" "$CASE_DIR/interrupt.out" \
    || fail "rate PASS printed after arrival interrupt"

  STOP_REQUESTED=0
  SAMPLE_INTERRUPT_AT=0
  POLL_COUNT=0
  ARRIVAL_CALLS=0
  arrival_fail() {
    ARRIVAL_CALLS=$((ARRIVAL_CALLS + 1))
    return 31
  }
  monitor_tick() { POLL_COUNT=$((POLL_COUNT + 1)); }
  stop_after_two() { [ "$POLL_COUNT" -ge 2 ]; }
  if run_post_service_phases arrival_fail probe_must_not_run monitor_tick stop_after_two \
    >"$CASE_DIR/failure.out" 2>&1; then
    fail "failed arrival returned success"
  else
    rc=$?
  fi
  [ "$rc" -eq 31 ] || fail "failed arrival returned $rc instead of 31"
  [ "$ARRIVAL_CALLS" -eq 1 ] || fail "failed arrival phase was retried"
  [ "$POLL_COUNT" -eq 2 ] || fail "arrival failure did not enter bounded hold"
  [ "$(grep -Fc "FAILURE_HOLD=ACTIVE" "$CASE_DIR/failure.out")" -eq 1 ] \
    || fail "arrival failure did not enter exactly one monitored hold"
  [ ! -e "$CASE_DIR/probe_forbidden" ] || fail "probe ran after arrival failure"
  ! grep -Fq "PI_DATA_ARRIVED=PASS" "$CASE_DIR/failure.out" \
    || fail "arrival PASS printed after failure"
  ! grep -Fq "W5_RATE_PROBES=PASS" "$CASE_DIR/failure.out" \
    || fail "rate PASS printed after arrival failure"

  FINAL_RC=0
  EMITTED_MARKERS=()
  ARRIVAL_ELAPSED_SECONDS=4
  arrival_ok() { return 0; }
  PROBE_CALLS=0
  probe_fail() {
    PROBE_CALLS=$((PROBE_CALLS + 1))
    return 41
  }
  POLL_COUNT=0
  if run_post_service_phases arrival_ok probe_fail monitor_tick stop_after_two \
    >"$CASE_DIR/probe_failure.out" 2>&1; then
    fail "failed rate probe returned success"
  else
    rc=$?
  fi
  [ "$rc" -eq 41 ] || fail "failed rate probe returned $rc instead of 41"
  [ "$PROBE_CALLS" -eq 1 ] || fail "failed rate phase was retried"
  [ "$(grep -Fc "PI_DATA_ARRIVED=PASS" "$CASE_DIR/probe_failure.out")" -eq 1 ] \
    || fail "arrival PASS missing before rate failure"
  ! grep -Fq "W5_RATE_PROBES=PASS" "$CASE_DIR/probe_failure.out" \
    || fail "rate PASS printed after rate failure"
  [ "$POLL_COUNT" -eq 2 ] || fail "rate failure did not enter bounded hold"

  FINAL_RC=0
  STOP_REQUESTED=0
  EMITTED_MARKERS=()
  probe_interrupt() {
    on_supervisor_interrupt
    return 0
  }
  run_post_service_phases arrival_ok probe_interrupt monitor_workstation_once \
    stop_requested >"$CASE_DIR/probe_interrupt.out" 2>&1
  grep -Fq "PI_DATA_ARRIVED=PASS" "$CASE_DIR/probe_interrupt.out" \
    || fail "arrival PASS missing before rate interrupt"
  ! grep -Fq "W5_RATE_PROBES=PASS" "$CASE_DIR/probe_interrupt.out" \
    || fail "rate PASS printed after rate interrupt"

  FINAL_RC=0
  STOP_REQUESTED=0
  SERVICES_UP=1
  EMITTED_MARKERS=()
  SUPERVISION_MONITOR_CALLS=0
  probe_ok() { return 0; }
  monitor_interrupted() {
    SUPERVISION_MONITOR_CALLS=$((SUPERVISION_MONITOR_CALLS + 1))
    on_supervisor_interrupt
    return 1
  }
  if run_post_service_phases arrival_ok probe_ok monitor_interrupted stop_requested \
    >"$CASE_DIR/supervision_interrupt.out" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  [ "$rc" -eq 0 ] || fail "interrupted supervision returned $rc instead of 0"
  [ "$FINAL_RC" -eq 0 ] || fail "interrupted supervision recorded a false failure"
  [ "$SUPERVISION_MONITOR_CALLS" -eq 1 ] \
    || fail "interrupted supervision monitor call count changed"
  ! grep -Fq "PHASE_FAIL: phase=supervision" "$CASE_DIR/supervision_interrupt.out" \
    || fail "interrupted supervision emitted a false phase failure"
  ! grep -Fq "FAILURE_HOLD=ACTIVE" "$CASE_DIR/supervision_interrupt.out" \
    || fail "interrupted supervision entered failure hold"

  FINAL_RC=0
  STOP_REQUESTED=0
  EMITTED_MARKERS=()
  : >"$CASE_DIR/success.out"
  for invocation in 1 2; do
    POLL_COUNT=0
    run_post_service_phases arrival_ok probe_ok monitor_tick stop_after_two \
      >>"$CASE_DIR/success.out" 2>&1
  done
  [ "$(grep -Fc "PI_DATA_ARRIVED=PASS" "$CASE_DIR/success.out")" -eq 1 ] \
    || fail "arrival PASS was not emitted exactly once"
  [ "$(grep -Fc "W5_RATE_PROBES=PASS" "$CASE_DIR/success.out")" -eq 1 ] \
    || fail "rate PASS was not emitted exactly once"
' _ "$PREFLIGHT" "$MARKER_CASE_DIR" 2>&1)"
MARKER_CASE_RC=$?
set -e
[ "$MARKER_CASE_RC" -eq 0 ] \
  || fail "marker-honesty case failed rc=$MARKER_CASE_RC: $MARKER_CASE_OUTPUT"
pass_case

CHILD_CASE_DIR="$TEST_TMP/child"
mkdir -p "$CHILD_CASE_DIR"
set +e
CHILD_CASE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  CASE_DIR="$2"
  WORKSTATION_LOG_ROOT="$CASE_DIR"
  CHILD_STARTUP_SETTLE_SECONDS=0.02
  SUPERVISOR_POLL_SECONDS=0.02
  STOP_POLL_SECONDS=0.02
  STOP_INT_ATTEMPTS=2
  STOP_TERM_ATTEMPTS=2
  WATCHDOG_PID=""
  case_cleanup() {
    local rc=$? i
    trap - EXIT INT TERM
    set +e
    [ -z "$WATCHDOG_PID" ] || kill -TERM -- "-$WATCHDOG_PID" 2>/dev/null
    [ -z "$WATCHDOG_PID" ] || wait "$WATCHDOG_PID" 2>/dev/null
    for ((i=${#CHILD_NAMES[@]}-1; i>=0; i--)); do
      stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
        >/dev/null 2>&1
    done
    exit "$rc"
  }
  trap case_cleanup EXIT
  trap "exit 124" TERM
  setsid bash -c "sleep 5; kill -TERM \"\$1\" 2>/dev/null" _ "$$" &
  WATCHDOG_PID=$!
  init_supervisor_state
  long_child=(bash -c "trap \"exit 0\" INT TERM; while :; do sleep 0.05; done")
  start_child rosbridge "$CASE_DIR/rosbridge.log" "${long_child[@]}"
  start_child web-video-server "$CASE_DIR/video.log" "${long_child[@]}"
  start_child dashboard "$CASE_DIR/dashboard.log" bash -c "sleep 0.15"
  test_local_ok() { return 0; }
  MONITOR_CALLS=0
  arrival_ok() { return 0; }
  probe_ok() { return 0; }
  monitor_supervisor() {
    MONITOR_CALLS=$((MONITOR_CALLS + 1))
    monitor_children_once test_local_ok
  }
  stop_after_twelve() { [ "$MONITOR_CALLS" -ge 12 ]; }
  if run_post_service_phases arrival_ok probe_ok monitor_supervisor stop_after_twelve \
    >"$CASE_DIR/monitor.out" 2>&1; then
    fail "premature child exit returned success"
  else
    rc=$?
  fi
  [ "$rc" -eq 1 ] || fail "premature child exit returned $rc instead of 1"
  grep -Fq "CHILD_EXITED: name=dashboard" "$CASE_DIR/monitor.out" \
    || fail "exited child name was not reported"
  grep -Fq "PHASE_FAIL: phase=supervision" "$CASE_DIR/monitor.out" \
    || fail "supervision failure was not preserved"
  grep -Fq "FAILURE_HOLD=ACTIVE" "$CASE_DIR/monitor.out" \
    || fail "child failure did not enter hold"
  group_alive "${CHILD_PGIDS[0]}" || fail "rosbridge fake child was not retained"
  group_alive "${CHILD_PGIDS[1]}" || fail "video fake child was not retained"
' _ "$PREFLIGHT" "$CHILD_CASE_DIR" 2>&1)"
CHILD_CASE_RC=$?
set -e
[ "$CHILD_CASE_RC" -eq 0 ] \
  || fail "child-monitoring case failed rc=$CHILD_CASE_RC: $CHILD_CASE_OUTPUT"
pass_case

HOLD_CASE_DIR="$TEST_TMP/hold"
mkdir -p "$HOLD_CASE_DIR"
set +e
HOLD_CASE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  CASE_DIR="$2"
  WORKSTATION_LOG_ROOT="$CASE_DIR"
  CHILD_STARTUP_SETTLE_SECONDS=0.02
  SUPERVISOR_POLL_SECONDS=0.02
  STOP_POLL_SECONDS=0.02
  STOP_INT_ATTEMPTS=2
  STOP_TERM_ATTEMPTS=2
  WATCHDOG_PID=""
  case_cleanup() {
    local rc=$? i
    trap - EXIT INT TERM
    set +e
    [ -z "$WATCHDOG_PID" ] || kill -TERM -- "-$WATCHDOG_PID" 2>/dev/null
    [ -z "$WATCHDOG_PID" ] || wait "$WATCHDOG_PID" 2>/dev/null
    for ((i=${#CHILD_NAMES[@]}-1; i>=0; i--)); do
      stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
        >/dev/null 2>&1
    done
    exit "$rc"
  }
  trap case_cleanup EXIT
  trap "exit 124" TERM
  setsid bash -c "sleep 5; kill -TERM \"\$1\" 2>/dev/null" _ "$$" &
  WATCHDOG_PID=$!
  init_supervisor_state
  long_child=(bash -c "trap \"exit 0\" INT TERM; while :; do sleep 0.05; done")
  start_child rosbridge "$CASE_DIR/rosbridge.log" "${long_child[@]}"
  start_child web-video-server "$CASE_DIR/video.log" "${long_child[@]}"
  start_child dashboard "$CASE_DIR/dashboard.log" "${long_child[@]}"
  POLL_COUNT=0
  arrival_ok() { return 0; }
  PROBE_CALLS=0
  probe_fail() {
    PROBE_CALLS=$((PROBE_CALLS + 1))
    return 37
  }
  monitor_hold() {
    monitor_children_once
    POLL_COUNT=$((POLL_COUNT + 1))
    printf "hold-poll\n" >>"$CASE_DIR/hold.trace"
  }
  stop_after_three() { [ "$POLL_COUNT" -ge 3 ]; }
  if run_post_service_phases arrival_ok probe_fail monitor_hold stop_after_three \
    >"$CASE_DIR/hold.out" 2>&1; then
    fail "failure hold returned success"
  else
    rc=$?
  fi
  [ "$rc" -eq 37 ] || fail "failure hold returned $rc instead of 37"
  [ "$PROBE_CALLS" -eq 1 ] || fail "held rate failure was retried"
  grep -Fq "PI_DATA_ARRIVED=PASS" "$CASE_DIR/hold.out" \
    || fail "arrival PASS missing before held rate failure"
  ! grep -Fq "W5_RATE_PROBES=PASS" "$CASE_DIR/hold.out" \
    || fail "rate PASS printed during held rate failure"
  [ "$(grep -Fc "hold-poll" "$CASE_DIR/hold.trace")" -eq 3 ] \
    || fail "failure hold did not monitor exactly three times"
  for pgid in "${CHILD_PGIDS[@]}"; do
    group_alive "$pgid" || fail "failure hold tore down a child"
  done
' _ "$PREFLIGHT" "$HOLD_CASE_DIR" 2>&1)"
HOLD_CASE_RC=$?
set -e
[ "$HOLD_CASE_RC" -eq 0 ] \
  || fail "failure-hold case failed rc=$HOLD_CASE_RC: $HOLD_CASE_OUTPUT"
pass_case

TEARDOWN_CASE_DIR="$TEST_TMP/teardown"
mkdir -p "$TEARDOWN_CASE_DIR"
set +e
TEARDOWN_CASE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  CASE_DIR="$2"
  WORKSTATION_LOG_ROOT="$CASE_DIR"
  CHILD_STARTUP_SETTLE_SECONDS=0.02
  STOP_POLL_SECONDS=0.02
  STOP_INT_ATTEMPTS=2
  STOP_TERM_ATTEMPTS=2
  WATCHDOG_PID=""
  case_cleanup() {
    local rc=$? i
    trap - EXIT INT TERM
    set +e
    [ -z "$WATCHDOG_PID" ] || kill -TERM -- "-$WATCHDOG_PID" 2>/dev/null
    [ -z "$WATCHDOG_PID" ] || wait "$WATCHDOG_PID" 2>/dev/null
    for ((i=${#CHILD_NAMES[@]}-1; i>=0; i--)); do
      stop_group "${CHILD_NAMES[$i]}" "${CHILD_PGIDS[$i]}" "${CHILD_PIDS[$i]}" \
        >/dev/null 2>&1
    done
    exit "$rc"
  }
  trap case_cleanup EXIT
  trap "exit 124" TERM
  setsid bash -c "sleep 5; kill -TERM \"\$1\" 2>/dev/null" _ "$$" &
  WATCHDOG_PID=$!
  init_supervisor_state
  long_child=(bash -c "trap \"exit 0\" INT TERM; while :; do sleep 0.05; done")
  start_child rosbridge "$CASE_DIR/rosbridge.log" "${long_child[@]}"
  start_child web-video-server "$CASE_DIR/video.log" "${long_child[@]}"
  start_child dashboard "$CASE_DIR/dashboard.log" "${long_child[@]}"
  SERVICES_UP=1
  gone_verifier() {
    local pgid
    for pgid in "${CHILD_PGIDS[@]}"; do
      ! group_alive "$pgid" || return 1
    done
    printf "verified-gone\n"
  }
  teardown_workstation_services gone_verifier >"$CASE_DIR/teardown.out" 2>&1
  dashboard_line="$(awk "/stopped dashboard/{print NR; exit}" "$CASE_DIR/teardown.out")"
  video_line="$(awk "/stopped web-video-server/{print NR; exit}" "$CASE_DIR/teardown.out")"
  rosbridge_line="$(awk "/stopped rosbridge/{print NR; exit}" "$CASE_DIR/teardown.out")"
  verify_line="$(awk "/verified-gone/{print NR; exit}" "$CASE_DIR/teardown.out")"
  pass_line="$(awk "/WORKSTATION_TEARDOWN=PASS/{print NR; exit}" "$CASE_DIR/teardown.out")"
  [ -n "$dashboard_line" ] && [ "$dashboard_line" -lt "$video_line" ] \
    && [ "$video_line" -lt "$rosbridge_line" ] \
    && [ "$rosbridge_line" -lt "$verify_line" ] \
    && [ "$verify_line" -lt "$pass_line" ] \
    || fail "reverse teardown order or PASS placement is wrong"

  init_supervisor_state
  start_child rosbridge "$CASE_DIR/rosbridge_2.log" "${long_child[@]}"
  start_child web-video-server "$CASE_DIR/video_2.log" "${long_child[@]}"
  start_child dashboard "$CASE_DIR/dashboard_2.log" "${long_child[@]}"
  SERVICES_UP=1
  negative_verifier() { return 1; }
  if teardown_workstation_services negative_verifier \
    >"$CASE_DIR/teardown_negative.out" 2>&1; then
    fail "negative teardown verifier returned success"
  fi
  ! grep -Fq "WORKSTATION_TEARDOWN=PASS" "$CASE_DIR/teardown_negative.out" \
    || fail "teardown PASS printed after failed verification"

  PORT_MODE=occupied
  NODE_MODE=clear
  ss() {
    if [ "$PORT_MODE" = occupied ] && [[ "$*" == *"sport = :8080"* ]]; then
      printf "LISTEN 0 128 127.0.0.1:8080 0.0.0.0:*\n"
    fi
    return 0
  }
  ros2() {
    if [ "$NODE_MODE" = present ]; then
      printf "/rosbridge_websocket\n"
    fi
    return 0
  }
  if verify_workstation_gone_once; then
    fail "teardown verifier accepted an occupied workstation port"
  fi
  PORT_MODE=clear
  NODE_MODE=present
  if verify_workstation_gone_once; then
    fail "teardown verifier accepted a remaining workstation node"
  fi
  NODE_MODE=clear
  verify_workstation_gone_once \
    || fail "teardown verifier rejected clear ports and nodes"
' _ "$PREFLIGHT" "$TEARDOWN_CASE_DIR" 2>&1)"
TEARDOWN_CASE_RC=$?
set -e
[ "$TEARDOWN_CASE_RC" -eq 0 ] \
  || fail "reverse-teardown case failed rc=$TEARDOWN_CASE_RC: $TEARDOWN_CASE_OUTPUT"
pass_case

REAL_SIGINT_CASE_DIR="$TEST_TMP/real-sigint"
mkdir -p "$REAL_SIGINT_CASE_DIR"
set +e
REAL_SIGINT_CASE_OUTPUT="$(bash -c '
  set -euo pipefail
  source "$1"
  CASE_DIR="$2"
  WORKSTATION_LOG_ROOT="$CASE_DIR"
  CHILD_STARTUP_SETTLE_SECONDS=0.02
  SUPERVISOR_POLL_SECONDS=0.02
  STOP_POLL_SECONDS=0.02
  STOP_INT_ATTEMPTS=2
  STOP_TERM_ATTEMPTS=2
  WATCHDOG_PID=""
  case_cleanup() {
    local rc=$? pgid signaler_pid
    trap - EXIT INT TERM
    set +e
    [ -z "$WATCHDOG_PID" ] || kill -TERM -- "-$WATCHDOG_PID" 2>/dev/null
    [ -z "$WATCHDOG_PID" ] || wait "$WATCHDOG_PID" 2>/dev/null
    if [ -r "$CASE_DIR/signaler.pid" ]; then
      read -r signaler_pid <"$CASE_DIR/signaler.pid"
      if [[ "$signaler_pid" =~ ^[1-9][0-9]*$ ]]; then
        kill -TERM -- "-$signaler_pid" 2>/dev/null
      fi
    fi
    if [ -r "$CASE_DIR/child.pgids" ]; then
      while read -r pgid; do
        [[ "$pgid" =~ ^[1-9][0-9]*$ ]] || continue
        kill -INT -- "-$pgid" 2>/dev/null
        kill -TERM -- "-$pgid" 2>/dev/null
        kill -KILL -- "-$pgid" 2>/dev/null
      done <"$CASE_DIR/child.pgids"
    fi
    exit "$rc"
  }
  trap case_cleanup EXIT
  trap "exit 124" TERM
  setsid bash -c "sleep 8; kill -TERM \"\$1\" 2>/dev/null" _ "$BASHPID" \
    >"$CASE_DIR/watchdog.log" 2>&1 < /dev/null &
  WATCHDOG_PID=$!

  run_workstation_runtime_preflight() {
    WORKSTATION_INTERFACE=wlp7s0
    WORKSTATION_IP=192.0.2.10
  }
  start_workstation_services() {
    local child_code
    child_code="name=\"\$1\"; trace=\"\$2\"; deadline=\$((SECONDS + 5)); trap \"printf \\\"%s\\\\n\\\" \\\"\$name\\\" >>\\\"\$trace\\\"; exit 0\" INT; trap \"exit 0\" TERM; while [ \"\$SECONDS\" -lt \"\$deadline\" ]; do sleep 0.02; done; exit 125"
    start_child rosbridge "$RUN_DIR/rosbridge.log" \
      bash -c "$child_code" _ rosbridge "$CASE_DIR/child-int.trace"
    start_child web-video-server "$RUN_DIR/web_video_server.log" \
      bash -c "$child_code" _ web-video-server "$CASE_DIR/child-int.trace"
    start_child dashboard "$RUN_DIR/dashboard.log" \
      bash -c "$child_code" _ dashboard "$CASE_DIR/child-int.trace"
    printf "%s\n" "${CHILD_PGIDS[@]}" >"$CASE_DIR/child.pgids"
  }
  wait_for_workstation_services() { return 0; }
  print_pi_command() { return 0; }
  wait_for_pi_data_arrival() {
    ARRIVAL_ELAPSED_SECONDS=0
    return 0
  }
  run_rate_probes() { return 0; }
  monitor_workstation_once() {
    monitor_children_once
    : >"$CASE_DIR/supervision.ready"
  }
  wait_for_workstation_teardown() {
    local pgid
    for pgid in "${CHILD_PGIDS[@]}"; do
      group_alive "$pgid" && return 1
    done
    return 0
  }

  SUPERVISOR_OUTPUT="$({
    set -e
    signal_target="$BASHPID"
    setsid bash -c "
      target=\"\$1\"
      marker=\"\$2\"
      sent=\"\$3\"
      for ((i=0; i<500; i++)); do
        if [ -e \"\$marker\" ]; then
          kill -INT \"\$target\"
          : >\"\$sent\"
          exit 0
        fi
        sleep 0.01
      done
      kill -TERM \"\$target\" 2>/dev/null
      exit 124
    " _ "$signal_target" "$CASE_DIR/supervision.ready" "$CASE_DIR/signaler.sent" \
      >"$CASE_DIR/signaler.log" 2>&1 < /dev/null &
    printf "%s\n" "$!" >"$CASE_DIR/signaler.pid"
    run_workstation_supervisor
  } 2>&1)"
  SUPERVISOR_RC=$?

  printf "%s\n" "$SUPERVISOR_OUTPUT" >"$CASE_DIR/supervisor.out"
  [ "$SUPERVISOR_RC" -eq 0 ] \
    || fail "real SIGINT supervisor returned $SUPERVISOR_RC instead of 0"
  [ -e "$CASE_DIR/signaler.sent" ] || fail "real SIGINT signaler did not run"
  [ "$(grep -Fc "stop requested; waiting for orderly workstation teardown" "$CASE_DIR/supervisor.out")" -eq 1 ] \
    || fail "real SIGINT stop request was not emitted exactly once"
  ! grep -Fq "PHASE_FAIL:" "$CASE_DIR/supervisor.out" \
    || fail "real SIGINT recorded a false phase failure"
  ! grep -Fq "FAILURE_HOLD=ACTIVE" "$CASE_DIR/supervisor.out" \
    || fail "real SIGINT entered failure hold"

  shopt -s nullglob
  run_dirs=("$CASE_DIR"/live_dashboard_workstation_*)
  [ "${#run_dirs[@]}" -eq 1 ] \
    || fail "real SIGINT created ${#run_dirs[@]} run directories instead of 1"
  supervisor_log="${run_dirs[0]}/supervisor.log"
  [ -r "$supervisor_log" ] || fail "durable supervisor log missing"
  [ "$(grep -Fc "SUPERVISOR_STOP trigger=signal signal=INT phase=supervision" "$supervisor_log")" -eq 1 ] \
    || fail "durable supervisor log did not record one supervision-phase SIGINT"
  [ "$(grep -Fc "SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=supervision failed_phase=none cleanup_rc=0" "$supervisor_log")" -eq 1 ] \
    || fail "durable supervisor log did not record the successful final status"
  [ "$(grep -Fc "WORKSTATION_TEARDOWN=PASS" "$supervisor_log")" -eq 1 ] \
    || fail "durable supervisor log did not record successful teardown"
  [ "$(grep -Fc "SUPERVISOR_STOP trigger=" "$supervisor_log")" -eq 1 ] \
    || fail "durable supervisor log recorded more than one stop trigger"

  for child in dashboard web-video-server rosbridge; do
    [ "$(grep -Fc "stopped $child" "$CASE_DIR/supervisor.out")" -eq 1 ] \
      || fail "real SIGINT did not stop $child exactly once"
  done
  dashboard_line="$(awk "/stopped dashboard/{print NR; exit}" "$CASE_DIR/supervisor.out")"
  video_line="$(awk "/stopped web-video-server/{print NR; exit}" "$CASE_DIR/supervisor.out")"
  rosbridge_line="$(awk "/stopped rosbridge/{print NR; exit}" "$CASE_DIR/supervisor.out")"
  [ -n "$dashboard_line" ] && [ "$dashboard_line" -lt "$video_line" ] \
    && [ "$video_line" -lt "$rosbridge_line" ] \
    || fail "real SIGINT did not preserve reverse teardown order"

  [ -r "$CASE_DIR/child-int.trace" ] || fail "fake-child INT trace missing"
  mapfile -t child_order <"$CASE_DIR/child-int.trace"
  [ "${#child_order[@]}" -eq 3 ] \
    && [ "${child_order[0]}" = dashboard ] \
    && [ "${child_order[1]}" = web-video-server ] \
    && [ "${child_order[2]}" = rosbridge ] \
    || fail "fake children did not receive INT once in reverse order"
  while read -r pgid; do
    ! kill -0 -- "-$pgid" 2>/dev/null \
      || fail "fake child process group remains alive: $pgid"
  done <"$CASE_DIR/child.pgids"
' _ "$PREFLIGHT" "$REAL_SIGINT_CASE_DIR" 2>&1)"
REAL_SIGINT_CASE_RC=$?
set -e
[ "$REAL_SIGINT_CASE_RC" -eq 0 ] \
  || fail "real-SIGINT lifecycle case failed rc=$REAL_SIGINT_CASE_RC: $REAL_SIGINT_CASE_OUTPUT"
pass_case

[ "$CASE_COUNT" -eq 22 ] || fail "executed $CASE_COUNT cases instead of 22"
printf 'PASS: live-dashboard preflight contracts cases=%s\n' "$CASE_COUNT"
