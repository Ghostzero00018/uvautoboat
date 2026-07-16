#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${1:-$SCRIPT_DIR/pi_live_hailo_mavlink_dashboard.sh}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

require_trace_count() {
  local expected="$1" literal="$2" actual
  actual="$(grep -Fxc -- "$literal" "$MONITOR_TRACE" || true)"
  [ "$actual" -eq "$expected" ] \
    || fail "trace count for $literal was $actual, expected $expected"
}

require_literal() {
  local literal="$1"
  grep -Fq -- "$literal" "$HELPER" || fail "missing contract: $literal"
}

reject_literal() {
  local literal="$1"
  ! grep -Fq -- "$literal" "$HELPER" || fail "forbidden contract remains: $literal"
}

extract_function() {
  local name="$1"
  awk -v start="${name}() {" '
    $0 == start { capture = 1 }
    capture { print }
    capture && $0 == "}" { exit }
  ' "$HELPER"
}

bash -n "$HELPER"

require_literal 'HOLD_AFTER_WINDOW="${LIVE_HOLD_AFTER_WINDOW:-0}"'
require_literal '[[ "$HOLD_AFTER_WINDOW" =~ ^[01]$ ]]'
require_literal "die 'LIVE_HOLD_AFTER_WINDOW must be 0 or 1'"
require_literal 'WS_IP="${WORKSTATION_IP:-}"'
require_literal "die 'WORKSTATION_IP is required for a live run'"
require_literal 'EXPECTED_SSID="${LIVE_SSID:-IMT Nord Europe 5G}"'
! grep -Eq 'WORKSTATION_IP:-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$HELPER" \
  || fail 'helper publishes a workstation IPv4 default'

require_literal 'wait_for_mavproxy_heartbeat() {'
require_literal 'MAVPROXY_LINK_DOWN=OBSERVED'
require_literal 'MAVPROXY_LINK_RECOVERY=PASS'
reject_literal 'MAVProxy reported link down before heartbeat'

HEARTBEAT_FUNCTION="$(extract_function wait_for_mavproxy_heartbeat)"
[ -n "$HEARTBEAT_FUNCTION" ] || fail 'heartbeat function was not extractable'

PASS_LOG="$(mktemp)"
FAIL_LOG="$(mktemp)"
ORDER_LOG="$(mktemp)"
LATE_LOG="$(mktemp)"
trap 'rm -f "$PASS_LOG" "$FAIL_LOG" "$ORDER_LOG" "$LATE_LOG"' EXIT
printf 'link 1 down\n' >"$PASS_LOG"

PASS_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  require_group_alive() { :; }
  POLL_COUNT=0
  SECONDS=0
  sleep() {
    POLL_COUNT=$((POLL_COUNT + 1))
    SECONDS=$((SECONDS + 1))
    printf "TEST_POLL=%s\n" "$POLL_COUNT"
    if [ "$POLL_COUNT" -eq 2 ]; then
      printf "Detected vehicle 1:1\n" >>"$MAVPROXY_LOG"
    fi
  }
  HEARTBEAT_TIMEOUT=3
  MAVPROXY_LOG="$2"
  MAVPROXY_PID=11
  MAVPROXY_PGID=11
  wait_for_mavproxy_heartbeat
' _ "$HEARTBEAT_FUNCTION" "$PASS_LOG")"

grep -Fq 'MAVPROXY_LINK_DOWN=OBSERVED' <<<"$PASS_OUTPUT" \
  || fail 'transient link-down warning was not emitted'
grep -Fq 'MAVPROXY_LINK_RECOVERY=PASS' <<<"$PASS_OUTPUT" \
  || fail 'heartbeat recovery was not accepted before the deadline'
[ "$(grep -Fc 'TEST_POLL=' <<<"$PASS_OUTPUT")" -eq 2 ] \
  || fail 'transient recovery did not span two deterministic polls'

printf 'Detected vehicle 1:1\nlink 1 down\n' >"$ORDER_LOG"
ORDER_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  require_group_alive() { :; }
  HEARTBEAT_TIMEOUT=3
  SECONDS=0
  MAVPROXY_LOG="$2"
  MAVPROXY_PID=11
  MAVPROXY_PGID=11
  wait_for_mavproxy_heartbeat
' _ "$HEARTBEAT_FUNCTION" "$ORDER_LOG")"
! grep -Fq 'MAVPROXY_LINK_DOWN=OBSERVED' <<<"$ORDER_OUTPUT" \
  || fail 'a post-heartbeat link-down was mislabelled as startup recovery'
! grep -Fq 'MAVPROXY_LINK_RECOVERY=PASS' <<<"$ORDER_OUTPUT" \
  || fail 'a post-heartbeat link-down emitted a recovery marker'

printf 'Detected vehicle 1:1\n' >"$LATE_LOG"
set +e
LATE_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { SECONDS=3; }
  require_group_alive() { :; }
  sleep() { :; }
  HEARTBEAT_TIMEOUT=3
  SECONDS=0
  MAVPROXY_LOG="$2"
  MAVPROXY_PID=11
  MAVPROXY_PGID=11
  wait_for_mavproxy_heartbeat
' _ "$HEARTBEAT_FUNCTION" "$LATE_LOG" 2>&1)"
LATE_RC=$?
set -e
[ "$LATE_RC" -eq 17 ] || fail 'post-deadline heartbeat was accepted'
grep -Fq 'MAVProxy heartbeat not seen within 3s' <<<"$LATE_OUTPUT" \
  || fail 'acceptance-time deadline crossing did not fail at the deadline'

printf 'link 1 down\n' >"$FAIL_LOG"
set +e
FAIL_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  require_group_alive() { :; }
  SECONDS=0
  sleep() {
    SECONDS=$((SECONDS + 1))
    printf "TEST_POLL=%s\n" "$SECONDS"
  }
  HEARTBEAT_TIMEOUT=3
  MAVPROXY_LOG="$2"
  MAVPROXY_PID=11
  MAVPROXY_PGID=11
  wait_for_mavproxy_heartbeat
' _ "$HEARTBEAT_FUNCTION" "$FAIL_LOG" 2>&1)"
FAIL_RC=$?
set -e
[ "$FAIL_RC" -eq 17 ] || fail "deadline case exited $FAIL_RC instead of 17"
grep -Fq 'MAVProxy heartbeat not seen within 3s' <<<"$FAIL_OUTPUT" \
  || fail 'deadline case did not report the finite heartbeat timeout'
[ "$(grep -Fc 'MAVPROXY_LINK_DOWN=OBSERVED' <<<"$FAIL_OUTPUT")" -eq 1 ] \
  || fail 'link-down warning was not one-shot'
[ "$(grep -Fc 'TEST_POLL=' <<<"$FAIL_OUTPUT")" -eq 3 ] \
  || fail 'deadline case did not execute exactly three deterministic polls'

require_literal 'monitor_live_stack() {'
MONITOR_FUNCTION="$(extract_function monitor_live_stack)"
for contract in \
  'check_command_sentinel' \
  'check_thermal_watchdog' \
  'require_group_alive mavproxy' \
  'require_group_alive mavros' \
  'require_group_alive hailo-bridge' \
  'check_temperature "$context"' \
  'reject_forbidden_nodes' \
  'require_workstation_nodes' \
  'reject_command_services' \
  'reject_unexpected_command_subscribers' \
  'require_publisher_count "$IMAGE_TOPIC" 1 "$context"' \
  'require_mavros_source /mavros/state' \
  'require_mavros_source /mavros/global_position/raw/fix' \
  'require_mavros_source /mavros/imu/data' \
  'require_mavros_source /mavros/battery' \
  'require_mavros_source /mavros/rc/in' \
  'require_connected_disarmed_state "$context"' \
  'check_power "$context"'; do
  grep -Fq -- "$contract" <<<"$MONITOR_FUNCTION" \
    || fail "hold monitor omits safety contract: $contract"
done

require_literal 'monitor_live_stack live-window "$DEADLINE"'
require_literal 'monitor_live_stack live-hold 0'
require_literal 'complete_source_window() {'
[ "$(grep -Fc 'complete_source_window' "$HELPER")" -eq 2 ] \
  || fail 'completion function must have exactly one definition and one call'
require_literal 'PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C'
require_literal 'if [ "$HOLD_ACTIVE" -eq 1 ]; then'
require_literal 'PI_SOURCE_HOLD=STOP operator-requested'
require_literal "trap 'log \"termination received\"; exit 143' TERM"

MONITOR_TRACE="$(mktemp)"
trap 'rm -f "$PASS_LOG" "$FAIL_LOG" "$ORDER_LOG" "$LATE_LOG" "$MONITOR_TRACE"' EXIT
set +e
bash -c '
  eval "$1"
  set -euo pipefail
  TRACE="$2"
  trace() { printf "%s\n" "$*" >>"$TRACE"; }
  log() { :; }
  die() { trace "die:$*"; exit 17; }
  check_command_sentinel() { trace sentinel; }
  check_thermal_watchdog() { trace thermal; }
  require_group_alive() { trace "alive:$1"; }
  check_temperature() { trace "temperature:$1"; }
  graph_nodes() { trace graph-nodes; printf "nodes\n"; }
  reject_forbidden_nodes() { trace forbidden-nodes; }
  require_workstation_nodes() { trace workstation-nodes; }
  reject_command_services() { trace command-services; }
  reject_unexpected_command_subscribers() { trace command-subscribers; }
  require_publisher_count() { trace "publisher:$1:$2:$3"; }
  require_mavros_source() { trace "source:$1"; }
  require_connected_disarmed_state() { trace "state:$1"; }
  check_power() { trace "power:$1"; }
  SLEEP_COUNT=0
  SECONDS=0
  sleep() {
    SLEEP_COUNT=$((SLEEP_COUNT + 1))
    SECONDS=$((SECONDS + 1))
    [ "$SLEEP_COUNT" -lt 4 ] || exit 23
  }
  POLL_S=1
  HOLD_START_SECONDS=0
  MAVPROXY_PID=11
  MAVPROXY_PGID=11
  MAVPROXY_LOG=mavproxy.log
  MAVROS_PID=12
  MAVROS_PGID=12
  MAVROS_LOG=mavros.log
  HAILO_PID=13
  HAILO_PGID=13
  HAILO_LOG=hailo.log
  IMAGE_TOPIC=/hailo/overlay/image_raw
  monitor_live_stack live-hold 0
' _ "$MONITOR_FUNCTION" "$MONITOR_TRACE"
MONITOR_RC=$?
set -e
[ "$MONITOR_RC" -eq 23 ] || fail "hold monitor exited $MONITOR_RC instead of test stop 23"
for trace in \
  sentinel thermal \
  alive:mavproxy alive:mavros alive:hailo-bridge \
  temperature:live-hold \
  graph-nodes forbidden-nodes workstation-nodes command-services \
  command-subscribers \
  publisher:/hailo/overlay/image_raw:1:live-hold \
  source:/mavros/state \
  source:/mavros/global_position/raw/fix \
  source:/mavros/imu/data \
  source:/mavros/battery \
  source:/mavros/rc/in \
  state:live-hold power:live-hold; do
  grep -Fxq -- "$trace" "$MONITOR_TRACE" \
    || fail "executed hold monitor missed: $trace"
done
require_trace_count 4 sentinel
require_trace_count 8 thermal
require_trace_count 4 alive:mavproxy
require_trace_count 4 alive:mavros
require_trace_count 4 alive:hailo-bridge
require_trace_count 4 temperature:live-hold
require_trace_count 1 graph-nodes
require_trace_count 1 forbidden-nodes
require_trace_count 1 workstation-nodes
require_trace_count 1 command-services
require_trace_count 1 command-subscribers
require_trace_count 1 publisher:/hailo/overlay/image_raw:1:live-hold
require_trace_count 1 source:/mavros/state
require_trace_count 1 source:/mavros/global_position/raw/fix
require_trace_count 1 source:/mavros/imu/data
require_trace_count 1 source:/mavros/battery
require_trace_count 1 source:/mavros/rc/in
require_trace_count 1 state:live-hold
require_trace_count 1 power:live-hold

INTERRUPT_FUNCTION="$(extract_function on_interrupt)"
set +e
PRE_WINDOW_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  cleanup() { printf "TEST_CLEANUP\n"; }
  trap cleanup EXIT
  trap on_interrupt INT
  HOLD_ACTIVE=0
  WINDOW_COMPLETE=0
  LIFECYCLE_TRANSITION_ACTIVE=0
  STOP_REQUESTED=0
  kill -INT $$
  printf "UNREACHABLE\n"
' _ "$INTERRUPT_FUNCTION" 2>&1)"
PRE_WINDOW_RC=$?
set -e
[ "$PRE_WINDOW_RC" -eq 130 ] || fail 'pre-window interrupt must exit 130'
! grep -Fq 'PI_SOURCE_HOLD=STOP' <<<"$PRE_WINDOW_OUTPUT" \
  || fail 'pre-window interrupt claimed an active hold'
grep -Fq 'TEST_CLEANUP' <<<"$PRE_WINDOW_OUTPUT" \
  || fail 'pre-window SIGINT did not enter the EXIT cleanup trap'
! grep -Fq 'UNREACHABLE' <<<"$PRE_WINDOW_OUTPUT" \
  || fail 'pre-window SIGINT continued after the interrupt handler'

set +e
HOLD_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  cleanup() { printf "TEST_CLEANUP\n"; }
  trap cleanup EXIT
  trap on_interrupt INT
  HOLD_ACTIVE=1
  WINDOW_COMPLETE=1
  LIFECYCLE_TRANSITION_ACTIVE=0
  STOP_REQUESTED=0
  kill -INT $$
  printf "UNREACHABLE\n"
' _ "$INTERRUPT_FUNCTION" 2>&1)"
HOLD_RC=$?
set -e
[ "$HOLD_RC" -eq 0 ] || fail 'operator stop during hold must exit 0'
grep -Fq 'PI_SOURCE_HOLD=STOP operator-requested' <<<"$HOLD_OUTPUT" \
  || fail 'operator stop during hold was not labelled'
grep -Fq 'TEST_CLEANUP' <<<"$HOLD_OUTPUT" \
  || fail 'hold SIGINT did not enter the EXIT cleanup trap'
! grep -Fq 'UNREACHABLE' <<<"$HOLD_OUTPUT" \
  || fail 'hold SIGINT continued after the interrupt handler'

COMPLETE_FUNCTION="$(extract_function complete_source_window)"
set +e
TRANSITION_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  set -euo pipefail
  TRIGGERED=0
  log() {
    printf "%s\n" "$*"
    if [ "$TRIGGERED" -eq 0 ] \
        && [ "$*" = "COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed" ]; then
      TRIGGERED=1
      kill -INT $$
    fi
  }
  cleanup() { printf "TEST_CLEANUP\n"; }
  monitor_live_stack() { printf "MONITOR_UNREACHABLE\n"; exit 99; }
  trap cleanup EXIT
  trap on_interrupt INT
  RUN_SECONDS=120
  PEAK_TEMP=50000
  SECONDS=10
  WINDOW_START_SECONDS=0
  HOLD_AFTER_WINDOW=1
  HOLD_ACTIVE=0
  WINDOW_COMPLETE=0
  LIFECYCLE_TRANSITION_ACTIVE=0
  STOP_REQUESTED=0
  complete_source_window
  printf "UNREACHABLE\n"
' _ "$INTERRUPT_FUNCTION" "$COMPLETE_FUNCTION" 2>&1)"
TRANSITION_RC=$?
set -e
[ "$TRANSITION_RC" -eq 0 ] || fail 'deferred lifecycle stop must exit 0'
grep -Fq 'interrupt deferred until lifecycle markers complete' <<<"$TRANSITION_OUTPUT" \
  || fail 'lifecycle-boundary SIGINT was not deferred'
TRANSITION_MARKERS="$(grep -E \
  '^(COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed|PI_SOURCE_WINDOW=COMPLETE target=120s |PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl\+C|PI_SOURCE_HOLD=STOP operator-requested|TEST_CLEANUP)' \
  <<<"$TRANSITION_OUTPUT")"
EXPECTED_TRANSITION_MARKERS="$(printf '%s\n' \
  'COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed' \
  'PI_SOURCE_WINDOW=COMPLETE target=120s elapsed=10s peak=50C' \
  'PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C' \
  'PI_SOURCE_HOLD=STOP operator-requested' \
  'TEST_CLEANUP')"
[ "$TRANSITION_MARKERS" = "$EXPECTED_TRANSITION_MARKERS" ] \
  || fail 'deferred lifecycle stop emitted incorrect marker order'
! grep -Fq 'MONITOR_UNREACHABLE' <<<"$TRANSITION_OUTPUT" \
  || fail 'deferred lifecycle stop entered the hold monitor'
! grep -Fq 'UNREACHABLE' <<<"$TRANSITION_OUTPUT" \
  || fail 'deferred lifecycle stop continued after completion'

set +e
COMPLETE_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  cleanup() { printf "TEST_CLEANUP\n"; }
  trap cleanup EXIT
  trap on_interrupt INT
  HOLD_ACTIVE=0
  WINDOW_COMPLETE=1
  LIFECYCLE_TRANSITION_ACTIVE=0
  STOP_REQUESTED=0
  kill -INT $$
  printf "UNREACHABLE\n"
' _ "$INTERRUPT_FUNCTION" 2>&1)"
COMPLETE_RC=$?
set -e
[ "$COMPLETE_RC" -eq 0 ] || fail 'post-window interrupt must exit 0'
grep -Fq 'source-window teardown requested after completion' <<<"$COMPLETE_OUTPUT" \
  || fail 'post-window interrupt was misclassified as incomplete'
grep -Fq 'TEST_CLEANUP' <<<"$COMPLETE_OUTPUT" \
  || fail 'post-window SIGINT did not enter the EXIT cleanup trap'
! grep -Fq 'UNREACHABLE' <<<"$COMPLETE_OUTPUT" \
  || fail 'post-window SIGINT continued after the interrupt handler'

COMMAND_LINE="$(grep -nF 'COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed' "$HELPER" | cut -d: -f1)"
WINDOW_LINE="$(grep -nF 'PI_SOURCE_WINDOW=COMPLETE target=' "$HELPER" | cut -d: -f1)"
HOLD_LINE="$(grep -nF 'PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C' "$HELPER" | cut -d: -f1)"
COMPLETE_LINE="$(grep -n '^[[:space:]]*WINDOW_COMPLETE=1$' "$HELPER" | cut -d: -f1)"
TRANSITION_START_LINE="$(grep -n '^[[:space:]]*LIFECYCLE_TRANSITION_ACTIVE=1$' "$HELPER" | cut -d: -f1)"
TRANSITION_END_LINE="$(grep -n '^[[:space:]]*LIFECYCLE_TRANSITION_ACTIVE=0$' "$HELPER" | tail -n 1 | cut -d: -f1)"
HOLD_STATE_LINE="$(grep -n '^[[:space:]]*HOLD_ACTIVE=1$' "$HELPER" | cut -d: -f1)"
STOP_BLOCK_LINE="$(grep -n '^[[:space:]]*if \[ "$STOP_REQUESTED" -eq 1 \]; then$' "$HELPER" | cut -d: -f1)"
HOLD_MONITOR_LINE="$(grep -n '^[[:space:]]*monitor_live_stack live-hold 0$' "$HELPER" | cut -d: -f1)"
CLEANUP_FUNCTION="$(extract_function cleanup)"

[ "$(grep -Fc 'COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed' "$HELPER")" -eq 1 ] \
  || fail 'final command-sentinel marker must be unique'
[ "$(grep -Fc 'PI_SOURCE_WINDOW=COMPLETE target=' "$HELPER")" -eq 1 ] \
  || fail 'source-window marker must be unique'
[ "$(grep -Fc 'PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C' "$HELPER")" -eq 1 ] \
  || fail 'hold-active marker must be unique'
[ "$(grep -Fc "log 'TEARDOWN=PASS'" "$HELPER")" -eq 1 ] \
  || fail 'teardown marker must be unique'
[ "$TRANSITION_START_LINE" -lt "$COMMAND_LINE" ] \
  || fail 'lifecycle transition must start before completion markers'
[ "$COMMAND_LINE" -lt "$WINDOW_LINE" ] || fail 'command marker must precede window marker'
[ "$WINDOW_LINE" -lt "$COMPLETE_LINE" ] || fail 'window state must close only after its marker'
[ "$COMPLETE_LINE" -lt "$HOLD_LINE" ] || fail 'window state must close before the hold marker'
[ "$HOLD_LINE" -lt "$HOLD_STATE_LINE" ] || fail 'hold state must follow its active marker'
[ "$HOLD_STATE_LINE" -lt "$TRANSITION_END_LINE" ] \
  || fail 'lifecycle transition must cover hold activation'
[ "$TRANSITION_END_LINE" -lt "$STOP_BLOCK_LINE" ] \
  || fail 'deferred stop must run only after lifecycle transition'
[ "$STOP_BLOCK_LINE" -lt "$HOLD_MONITOR_LINE" ] \
  || fail 'deferred stop must run before the hold monitor'
grep -Fq "log 'TEARDOWN=PASS'" <<<"$CLEANUP_FUNCTION" \
  || fail 'TEARDOWN=PASS must remain cleanup-owned'
! grep -Fq 'PI_SOURCE_WINDOW=COMPLETE' <<<"$CLEANUP_FUNCTION" \
  || fail 'cleanup must not defer or duplicate the source-window marker'

set +e
INVALID_MODE_OUTPUT="$(LIVE_HOLD_AFTER_WINDOW=2 "$HELPER" --preflight-only 2>&1)"
INVALID_MODE_RC=$?
set -e
[ "$INVALID_MODE_RC" -ne 0 ] || fail 'invalid hold mode was accepted'
grep -Fq 'LIVE_HOLD_AFTER_WINDOW must be 0 or 1' <<<"$INVALID_MODE_OUTPUT" \
  || fail 'invalid hold mode did not fail at validation'

printf 'PASS: heartbeat behavior and monitored hold/marker contracts\n'
