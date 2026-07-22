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
require_literal 'LOCAL_DISPLAY="${HAILO_LOCAL_DISPLAY:-0}"'
require_literal '[[ "$LOCAL_DISPLAY" =~ ^[01]$ ]]'
require_literal "die 'HAILO_LOCAL_DISPLAY must be 0 or 1'"
require_literal 'LOCAL_WINDOW_MODE="${HAILO_LOCAL_WINDOW_MODE:-resizable}"'
require_literal '[[ "$LOCAL_WINDOW_MODE" =~ ^(resizable|fullscreen)$ ]]'
require_literal "die 'HAILO_LOCAL_WINDOW_MODE must be resizable or fullscreen'"
require_literal 'configure_hailo_display() {'
require_literal 'WS_IP="${WORKSTATION_IP:-}"'
require_literal "die 'WORKSTATION_IP is required for a live run'"
require_literal 'EXPECTED_SSID="${LIVE_SSID:-IMT Nord Europe 5G}"'
! grep -Eq 'WORKSTATION_IP:-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$HELPER" \
  || fail 'helper publishes a workstation IPv4 default'

require_literal "SUPERVISOR_LOG=''"
require_literal "SUPERVISOR_PHASE='initialization'"
require_literal "SUPERVISOR_STOP_TRIGGER='none'"
require_literal 'append_supervisor_log() {'
require_literal 'record_stop_trigger() {'
require_literal 'finalize_supervisor() {'
require_literal 'PI_SUPERVISOR_START pid='
require_literal 'PI_SUPERVISOR_STOP trigger='
require_literal 'PI_SUPERVISOR_EXIT status='
require_literal 'SUPERVISOR_LOG="$RUN_DIR/supervisor.log"'
require_literal 'helper_sha256='

require_literal 'wait_for_mavproxy_heartbeat() {'
require_literal 'MAVPROXY_LINK_DOWN=OBSERVED'
require_literal 'MAVPROXY_LINK_RECOVERY=PASS'
reject_literal 'MAVProxy reported link down before heartbeat'

APPEND_LOG_FUNCTION="$(extract_function append_supervisor_log)"
LOG_FUNCTION="$(extract_function log)"
LOG_ERROR_FUNCTION="$(extract_function log_error)"
STOP_TRIGGER_FUNCTION="$(extract_function record_stop_trigger)"
FINALIZE_FUNCTION="$(extract_function finalize_supervisor)"
DIE_FUNCTION="$(extract_function die)"
INTERRUPT_FUNCTION="$(extract_function on_interrupt)"

LIFECYCLE_LOG="$(mktemp)"
FAIL_CLOSED_LOG="$(mktemp)"
trap 'rm -f "$LIFECYCLE_LOG" "$FAIL_CLOSED_LOG"' EXIT

set +e
LIFECYCLE_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  eval "$3"
  eval "$4"
  eval "$5"
  eval "$6"
  SUPERVISOR_LOG="$7"
  RUN_DIR=/test/pi-run
  SUPERVISOR_PHASE=live-hold
  SUPERVISOR_STOP_TRIGGER=none
  SUPERVISOR_STOP_SIGNAL=none
  SUPERVISOR_STOP_PHASE=none
  SUPERVISOR_FAILED_PHASE=none
  HOLD_ACTIVE=1
  WINDOW_COMPLETE=1
  LIFECYCLE_TRANSITION_ACTIVE=0
  STOP_REQUESTED=0
  finish() {
    local rc=$?
    trap - EXIT
    finalize_supervisor "$rc" 0
    exit $?
  }
  trap finish EXIT
  trap on_interrupt INT
  kill -INT $$
  printf "UNREACHABLE\n"
' _ "$APPEND_LOG_FUNCTION" "$LOG_FUNCTION" "$LOG_ERROR_FUNCTION" \
  "$STOP_TRIGGER_FUNCTION" "$INTERRUPT_FUNCTION" "$FINALIZE_FUNCTION" \
  "$LIFECYCLE_LOG" 2>&1)"
LIFECYCLE_RC=$?
set -e
[ "$LIFECYCLE_RC" -eq 0 ] || fail 'hold-phase lifecycle signal did not exit cleanly'
grep -Fq 'PI_SUPERVISOR_STOP trigger=signal signal=INT phase=live-hold' \
  "$LIFECYCLE_LOG" \
  || fail 'durable lifecycle log missed the hold-phase SIGINT trigger'
grep -Fq 'PI_SOURCE_HOLD=STOP operator-requested' "$LIFECYCLE_LOG" \
  || fail 'durable lifecycle log missed the operator hold-stop marker'
[ "$(grep -Fc 'PI_SUPERVISOR_STOP trigger=' "$LIFECYCLE_LOG")" -eq 1 ] \
  || fail 'durable lifecycle log recorded multiple stop triggers'
grep -Fq 'TEARDOWN=PASS' "$LIFECYCLE_LOG" \
  || fail 'durable lifecycle log missed successful interrupt teardown'
grep -Fq \
  'PI_SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=live-hold failed_phase=none cleanup_rc=0' \
  "$LIFECYCLE_LOG" \
  || fail 'durable lifecycle log missed successful interrupt final status'
tail -n 1 "$LIFECYCLE_LOG" | grep -Fq 'PI_SUPERVISOR_EXIT status=0' \
  || fail 'interrupt final-status marker was not the terminal lifecycle record'
! grep -Fq 'UNREACHABLE' <<<"$LIFECYCLE_OUTPUT" \
  || fail 'hold-phase lifecycle signal continued after the interrupt'

set +e
FAIL_CLOSED_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  eval "$3"
  eval "$4"
  eval "$5"
  eval "$6"
  SUPERVISOR_LOG="$7"
  RUN_DIR=/test/pi-run
  SUPERVISOR_PHASE=live-window
  SUPERVISOR_STOP_TRIGGER=none
  SUPERVISOR_STOP_SIGNAL=none
  SUPERVISOR_STOP_PHASE=none
  SUPERVISOR_FAILED_PHASE=none
  finish() {
    local rc=$?
    trap - EXIT
    finalize_supervisor "$rc" 0
    exit $?
  }
  trap finish EXIT
  die "graph check failed"
' _ "$APPEND_LOG_FUNCTION" "$LOG_FUNCTION" "$LOG_ERROR_FUNCTION" \
  "$STOP_TRIGGER_FUNCTION" "$DIE_FUNCTION" "$FINALIZE_FUNCTION" \
  "$FAIL_CLOSED_LOG" 2>&1)"
FAIL_CLOSED_RC=$?
set -e
[ "$FAIL_CLOSED_RC" -eq 1 ] || fail 'fail-closed lifecycle case did not exit 1'
grep -Fq 'PI_SUPERVISOR_STOP trigger=failure signal=none phase=live-window' \
  "$FAIL_CLOSED_LOG" \
  || fail 'durable lifecycle log missed the fail-closed trigger'
grep -Fq 'STOP: graph check failed' "$FAIL_CLOSED_LOG" \
  || fail 'durable lifecycle log missed the fail-closed reason'
grep -Fq 'STOP: graph check failed' <<<"$FAIL_CLOSED_OUTPUT" \
  || fail 'fail-closed reason was not emitted to the console'
grep -Fq 'TEARDOWN=PASS' "$FAIL_CLOSED_LOG" \
  || fail 'durable lifecycle log missed fail-closed teardown'
grep -Fq \
  'PI_SUPERVISOR_EXIT status=1 trigger=failure signal=none stop_phase=live-window failed_phase=live-window cleanup_rc=0' \
  "$FAIL_CLOSED_LOG" \
  || fail 'durable lifecycle log missed fail-closed final status'
tail -n 1 "$FAIL_CLOSED_LOG" | grep -Fq 'PI_SUPERVISOR_EXIT status=1' \
  || fail 'fail-closed final-status marker was not the terminal lifecycle record'

set +e
NEGATIVE_CLEANUP_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  eval "$3"
  eval "$4"
  SUPERVISOR_LOG=""
  RUN_DIR=/test/pi-run
  SUPERVISOR_STOP_TRIGGER=exit
  SUPERVISOR_STOP_SIGNAL=none
  SUPERVISOR_STOP_PHASE=post-window
  SUPERVISOR_FAILED_PHASE=none
  finalize_supervisor 0 1
' _ "$APPEND_LOG_FUNCTION" "$LOG_FUNCTION" "$LOG_ERROR_FUNCTION" \
  "$FINALIZE_FUNCTION" 2>&1)"
NEGATIVE_CLEANUP_RC=$?
set -e
[ "$NEGATIVE_CLEANUP_RC" -eq 1 ] \
  || fail 'negative cleanup finalizer did not return 1'
grep -Fq 'TEARDOWN=FAIL' <<<"$NEGATIVE_CLEANUP_OUTPUT" \
  || fail 'negative cleanup omitted its failure verdict'
! grep -Fq 'TEARDOWN=PASS' <<<"$NEGATIVE_CLEANUP_OUTPUT" \
  || fail 'negative cleanup emitted a pass verdict'
rm -f "$LIFECYCLE_LOG" "$FAIL_CLOSED_LOG"
trap - EXIT

DISPLAY_FUNCTION="$(extract_function configure_hailo_display)"
[ -n "$DISPLAY_FUNCTION" ] || fail 'display-mode function was not extractable'

HEADLESS_DISPLAY_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  LOCAL_DISPLAY=0
  LOCAL_WINDOW_MODE=fullscreen
  unset DISPLAY
  configure_hailo_display
  printf "DISPLAY_ARGS=%s\n" "${HAILO_DISPLAY_ARGS[*]}"
' _ "$DISPLAY_FUNCTION")"
grep -Fxq 'HAILO_LOCAL_DISPLAY=DISABLED' <<<"$HEADLESS_DISPLAY_OUTPUT" \
  || fail 'headless display mode did not emit its marker'
grep -Fxq 'DISPLAY_ARGS=--no-display' <<<"$HEADLESS_DISPLAY_OUTPUT" \
  || fail 'headless display mode omitted --no-display'

LOCAL_DISPLAY_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  LOCAL_DISPLAY=1
  LOCAL_WINDOW_MODE=fullscreen
  DISPLAY=:77
  configure_hailo_display
  printf "DISPLAY_ARGS=%s\n" "${HAILO_DISPLAY_ARGS[*]}"
' _ "$DISPLAY_FUNCTION")"
grep -Fxq 'HAILO_LOCAL_DISPLAY=ENABLED display=:77 window_mode=fullscreen' \
  <<<"$LOCAL_DISPLAY_OUTPUT" \
  || fail 'local display mode did not emit its marker'
grep -Fxq 'DISPLAY_ARGS=' <<<"$LOCAL_DISPLAY_OUTPUT" \
  || fail 'local display mode retained --no-display'

set +e
MISSING_DISPLAY_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  LOCAL_DISPLAY=1
  LOCAL_WINDOW_MODE=resizable
  unset DISPLAY
  configure_hailo_display
' _ "$DISPLAY_FUNCTION" 2>&1)"
MISSING_DISPLAY_RC=$?
set -e
[ "$MISSING_DISPLAY_RC" -eq 17 ] \
  || fail "missing-display case exited $MISSING_DISPLAY_RC instead of 17"
grep -Fq 'requires a Pi desktop or Remmina terminal with DISPLAY set' \
  <<<"$MISSING_DISPLAY_OUTPUT" \
  || fail 'missing-display case did not explain the desktop-session requirement'

HAILO_LAUNCH_BLOCK="$(sed -n '/^start_child hailo-bridge /,/^HAILO_PID=/p' "$HELPER")"
[ -n "$HAILO_LAUNCH_BLOCK" ] || fail 'Hailo launch block was not extractable'
grep -Fq '"${HAILO_DISPLAY_ARGS[@]}"' <<<"$HAILO_LAUNCH_BLOCK" \
  || fail 'Hailo launch does not use the configured display arguments'
! grep -Fq -- '--no-display' <<<"$HAILO_LAUNCH_BLOCK" \
  || fail 'Hailo launch still forces headless mode'

require_literal '"HAILO_LOCAL_WINDOW_MODE=$LOCAL_WINDOW_MODE"'
WINDOW_WRAPPER_SOURCE="$(awk '
  $0 == "window_name = \"Output\"" { capture = 1 }
  capture && $0 == "detector.visualize = publishing_visualize" { exit }
  capture { print }
' "$HELPER")"
[ -n "$WINDOW_WRAPPER_SOURCE" ] \
  || fail 'local-window wrapper source was not extractable'

WINDOW_BEHAVIOR_OUTPUT="$(python3 - "$WINDOW_WRAPPER_SOURCE" <<'PYTHON_WINDOW_TEST'
import os
import sys
from types import SimpleNamespace

source = sys.argv[1]


class FakeCv2:
    error = RuntimeError
    WINDOW_NORMAL = 1
    WINDOW_KEEPRATIO = 2
    WND_PROP_FULLSCREEN = 3
    WINDOW_FULLSCREEN = 4
    COLOR_RGB2BGR = 5
    INTER_AREA = 6

    def __init__(self, fail_at=None):
        self.calls = []
        self.fail_at = fail_at

    def namedWindow(self, name, flags):
        self.calls.append(("namedWindow", name, flags))
        if self.fail_at == "namedWindow":
            raise RuntimeError("named-window-failed")

    def setWindowProperty(self, name, prop, value):
        self.calls.append(("setWindowProperty", name, prop, value))
        if self.fail_at == "setWindowProperty":
            raise RuntimeError("fullscreen-failed")

    def destroyWindow(self, name):
        self.calls.append(("destroyWindow", name))

    def cvtColor(self, frame, _conversion):
        return frame

    def resize(self, frame, _size, interpolation=None):
        return frame


class FakeFrame:
    shape = (240, 320, 3)

    def tobytes(self):
        return b"frame"


class FakeImage:
    def __init__(self):
        self.header = SimpleNamespace(stamp=None, frame_id=None)


class FakePublisher:
    def __init__(self):
        self.messages = []

    def publish(self, message):
        self.messages.append(message)


class FakeNode:
    def get_clock(self):
        return self

    def now(self):
        return self

    def to_msg(self):
        return "stamp"


class FakeTime:
    @staticmethod
    def monotonic_ns():
        return 1_000_000_000


class FakeNp:
    @staticmethod
    def ascontiguousarray(frame):
        return frame


class Settings:
    def __init__(self, no_display=False):
        self.no_display = no_display


def exercise(mode, fail_at=None, no_display=False):
    fake_cv2 = FakeCv2(fail_at)
    calls = fake_cv2.calls
    publisher = FakePublisher()
    frame = FakeFrame()

    def fake_original(*args):
        calls.append(("original_visualize", args[1].no_display))
        args[3]()
        return "ORIGINAL_RESULT"

    namespace = {
        "cv2": fake_cv2,
        "Image": FakeImage,
        "node": FakeNode(),
        "np": FakeNp(),
        "os": os,
        "original_visualize": fake_original,
        "publisher": publisher,
        "state": {"last_publish_ns": 0, "count": 0},
        "stream_height": 240,
        "period_ns": 100_000_000,
        "time": FakeTime(),
    }
    os.environ["HAILO_LOCAL_WINDOW_MODE"] = mode
    exec(source, namespace)
    settings = Settings(no_display)
    result = namespace["publishing_visualize"](
        None, settings, None, lambda: frame
    )
    assert result == "ORIGINAL_RESULT"
    assert sum(call[0] == "original_visualize" for call in calls) == 1
    assert len(publisher.messages) == 1
    assert publisher.messages[0].header.frame_id == "hailo_overlay"
    return settings, calls


settings, calls = exercise("resizable")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("original_visualize", False),
]

settings, calls = exercise("fullscreen")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("setWindowProperty", "Output", 3, 4),
    ("original_visualize", False),
]

settings, calls = exercise("fullscreen", no_display=True)
assert settings.no_display is True
assert calls == [("original_visualize", True)]

settings, calls = exercise("fullscreen", "namedWindow")
assert settings.no_display is True
assert calls == [
    ("namedWindow", "Output", 3),
    ("destroyWindow", "Output"),
    ("original_visualize", True),
]

settings, calls = exercise("fullscreen", "setWindowProperty")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("setWindowProperty", "Output", 3, 4),
    ("original_visualize", False),
]

print("WINDOW_BEHAVIOR=PASS modes=3 fallback=headless+resizable published=5")
PYTHON_WINDOW_TEST
)"
grep -Fxq \
  'WINDOW_BEHAVIOR=PASS modes=3 fallback=headless+resizable published=5' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'local-window behavior contract did not pass'
grep -Fxq 'HAILO_LOCAL_WINDOW=READY mode=resizable name=Output' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'resizable window did not emit its ready marker'
grep -Fxq 'HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen window did not emit its ready marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS mode=fullscreen stage=namedWindow error=RuntimeError' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'window-creation failure did not emit the headless fallback marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE requested=fullscreen error=RuntimeError' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen-property failure did not emit the resizable fallback marker'

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
require_literal 'on_termination() {'
require_literal 'trap on_termination TERM'

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
  record_stop_trigger() { :; }
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
  record_stop_trigger() { :; }
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
  record_stop_trigger() { :; }
  set_supervisor_phase() { :; }
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
  record_stop_trigger() { :; }
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
FINALIZE_FUNCTION="$(extract_function finalize_supervisor)"
LOG_INIT_LINE="$(grep -n '^[[:space:]]*SUPERVISOR_LOG="$RUN_DIR/supervisor.log"$' "$HELPER" | cut -d: -f1)"
CLEANUP_TRAP_LINE="$(grep -n '^[[:space:]]*trap cleanup EXIT$' "$HELPER" | cut -d: -f1)"
DISPLAY_CALL_LINE="$(grep -n '^configure_hailo_display$' "$HELPER" | cut -d: -f1)"
PREFLIGHT_CALL_LINE="$(grep -n '^run_hailo_ros_preflight$' "$HELPER" | cut -d: -f1)"

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
grep -Fq 'finalize_supervisor "$rc" "$cleanup_rc"' <<<"$CLEANUP_FUNCTION" \
  || fail 'cleanup must delegate its final lifecycle verdict'
grep -Fq "log 'TEARDOWN=PASS'" <<<"$FINALIZE_FUNCTION" \
  || fail 'TEARDOWN=PASS must remain finalizer-owned'
! grep -Fq 'PI_SOURCE_WINDOW=COMPLETE' <<<"$CLEANUP_FUNCTION" \
  || fail 'cleanup must not defer or duplicate the source-window marker'
[ "$LOG_INIT_LINE" -lt "$CLEANUP_TRAP_LINE" ] \
  || fail 'cleanup trap must follow successful supervisor-log initialization'
[ "$CLEANUP_TRAP_LINE" -lt "$DISPLAY_CALL_LINE" ] \
  || fail 'cleanup trap must cover live display configuration'
[ "$CLEANUP_TRAP_LINE" -lt "$PREFLIGHT_CALL_LINE" ] \
  || fail 'cleanup trap must cover the ROS/Hailo preflight'

set +e
INVALID_MODE_OUTPUT="$(LIVE_HOLD_AFTER_WINDOW=2 "$HELPER" --preflight-only 2>&1)"
INVALID_MODE_RC=$?
set -e
[ "$INVALID_MODE_RC" -ne 0 ] || fail 'invalid hold mode was accepted'
grep -Fq 'LIVE_HOLD_AFTER_WINDOW must be 0 or 1' <<<"$INVALID_MODE_OUTPUT" \
  || fail 'invalid hold mode did not fail at validation'

set +e
INVALID_DISPLAY_OUTPUT="$(HAILO_LOCAL_DISPLAY=2 "$HELPER" --preflight-only 2>&1)"
INVALID_DISPLAY_RC=$?
set -e
[ "$INVALID_DISPLAY_RC" -ne 0 ] || fail 'invalid local-display mode was accepted'
grep -Fq 'HAILO_LOCAL_DISPLAY must be 0 or 1' <<<"$INVALID_DISPLAY_OUTPUT" \
  || fail 'invalid local-display mode did not fail at validation'

set +e
INVALID_WINDOW_OUTPUT="$(HAILO_LOCAL_WINDOW_MODE=stretch "$HELPER" --preflight-only 2>&1)"
INVALID_WINDOW_RC=$?
set -e
[ "$INVALID_WINDOW_RC" -ne 0 ] || fail 'invalid local-window mode was accepted'
grep -Fq 'HAILO_LOCAL_WINDOW_MODE must be resizable or fullscreen' \
  <<<"$INVALID_WINDOW_OUTPUT" \
  || fail 'invalid local-window mode did not fail at validation'

printf 'PASS: Pi lifecycle, local-window, heartbeat, and monitored-hold contracts\n'
