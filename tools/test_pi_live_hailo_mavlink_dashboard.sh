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
require_literal 'IMAGE_RECOVERY_SAMPLE="$RUN_DIR/hailo_graph_zero_recovery.yaml"'

require_literal 'HOLD_AFTER_WINDOW="${LIVE_HOLD_AFTER_WINDOW:-0}"'
require_literal '[[ "$HOLD_AFTER_WINDOW" =~ ^[01]$ ]]'
require_literal "die 'LIVE_HOLD_AFTER_WINDOW must be 0 or 1'"
require_literal 'LOCAL_DISPLAY="${HAILO_LOCAL_DISPLAY:-0}"'
require_literal '[[ "$LOCAL_DISPLAY" =~ ^[01]$ ]]'
require_literal "die 'HAILO_LOCAL_DISPLAY must be 0 or 1'"
require_literal 'LOCAL_WINDOW_MODE="${HAILO_LOCAL_WINDOW_MODE:-resizable}"'
require_literal '[[ "$LOCAL_WINDOW_MODE" =~ ^(resizable|fullscreen)$ ]]'
require_literal "die 'HAILO_LOCAL_WINDOW_MODE must be resizable or fullscreen'"
require_literal 'FINAL_VERIFY_SECONDS="${LIVE_FINAL_VERIFY_SECONDS:-180}"'
require_literal '[[ "$FINAL_VERIFY_SECONDS" =~ ^[1-9][0-9]*$ ]]'
require_literal "die 'LIVE_FINAL_VERIFY_SECONDS must be a positive integer'"
require_literal 'for command in fuser ss setsid iwgetid ip install ros2 timeout; do'
require_literal 'timeout --signal=KILL'
reject_literal 'timeout --foreground'
require_literal 'configure_hailo_display() {'
require_literal 'WS_IP="${WORKSTATION_IP:-}"'
require_literal "die 'WORKSTATION_IP is required for a live run'"
require_literal 'EXPECTED_SSID="${LIVE_SSID:-IMT Nord Europe 5G}"'
! grep -Eq 'WORKSTATION_IP:-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$HELPER" \
  || fail 'helper publishes a workstation IPv4 default'
require_literal 'FCU_TO_VRX_FANOUT="${LIVE_FCU_TO_VRX_FANOUT:-0}"'
require_literal 'FCU_TO_VRX_INGRESS_PORT=14556'
require_literal 'FCU_TO_VRX_DESTINATION_PORT=14555'
require_literal 'validate_fcu_to_vrx_fanout() {'
require_literal 'configure_mavproxy_outputs() {'
require_literal 'FCU_TO_VRX_FANOUT=DISABLED'
require_literal 'FCU_TO_VRX_FANOUT=ENABLED direction=outbound-only'
require_literal 'class OutboundOnlyMavlinkFanout:'
require_literal 'self.ingress.bind(("127.0.0.1", self.ingress_port))'
require_literal 'self.outbound.sendto(payload, self.destination)'
require_literal 'self.abort_seen("FCU_ARMED", "/mavros/state")'
reject_literal 'class OutboundOnlyTelemetryFanout:'

MAVPROXY_OUT_LINES="$(grep -n -- '--out=' "$HELPER" || true)"
[ -n "$MAVPROXY_OUT_LINES" ] || fail 'helper has no MAVProxy output endpoint'
while IFS= read -r output_line; do
  [[ "$output_line" == *127.0.0.1* ]] \
    || fail "non-loopback MAVProxy output endpoint: $output_line"
done <<<"$MAVPROXY_OUT_LINES"

FANOUT_VALIDATION_LINE="$(grep -nFx 'validate_fcu_to_vrx_fanout' "$HELPER" | cut -d: -f1)"
SUPERVISOR_TRAP_LINE="$(grep -nF 'trap cleanup EXIT' "$HELPER" | cut -d: -f1)"
[[ "$FANOUT_VALIDATION_LINE" =~ ^[1-9][0-9]*$ ]] \
  || fail 'fanout validation call was not found exactly once'
[[ "$SUPERVISOR_TRAP_LINE" =~ ^[1-9][0-9]*$ ]] \
  || fail 'supervisor cleanup trap was not found exactly once'
[ "$FANOUT_VALIDATION_LINE" -lt "$SUPERVISOR_TRAP_LINE" ] \
  || fail 'fanout selector is not validated before cleanup is installed'

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
require_literal 'THRUST_SAMPLE="$RUN_DIR/mavros_thrust_output.yaml"'
require_literal 'log_thrust_output_sample() {'
require_literal 'THRUST_OUTPUT_RAW_BEGIN phase=$context'
require_literal 'THRUST_OUTPUT_RAW_END phase=$context'

require_literal 'wait_for_mavproxy_heartbeat() {'
require_literal 'MAVPROXY_LINK_DOWN=OBSERVED'
require_literal 'MAVPROXY_LINK_RECOVERY=PASS'
reject_literal 'MAVProxy reported link down before heartbeat'

FANOUT_VALIDATE_FUNCTION="$(extract_function validate_fcu_to_vrx_fanout)"
FANOUT_CONFIG_FUNCTION="$(extract_function configure_mavproxy_outputs)"
[ -n "$FANOUT_VALIDATE_FUNCTION" ] \
  || fail 'fanout validation function was not extractable'
[ -n "$FANOUT_CONFIG_FUNCTION" ] \
  || fail 'MAVProxy output configuration function was not extractable'

set +e
INVALID_FANOUT_OUTPUT="$(bash -c '
  eval "$1"
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  FCU_TO_VRX_FANOUT=2
  WS_IP=10.120.2.243
  validate_fcu_to_vrx_fanout
' _ "$FANOUT_VALIDATE_FUNCTION" 2>&1)"
INVALID_FANOUT_RC=$?
set -e
[ "$INVALID_FANOUT_RC" -eq 17 ] \
  || fail "invalid fanout flag exited $INVALID_FANOUT_RC instead of 17"
grep -Fq 'LIVE_FCU_TO_VRX_FANOUT must be 0 or 1' \
  <<<"$INVALID_FANOUT_OUTPUT" \
  || fail 'invalid fanout flag did not explain the accepted values'

DISABLED_FANOUT_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  FCU_TO_VRX_FANOUT=0
  FCU_TO_VRX_INGRESS_PORT=14556
  WS_IP=10.120.2.243
  configure_mavproxy_outputs
  printf "MAVPROXY_OUTPUT_ARGS=%s\n" "${MAVPROXY_OUTPUT_ARGS[*]}"
' _ "$FANOUT_CONFIG_FUNCTION")"
grep -Fxq 'FCU_TO_VRX_FANOUT=DISABLED' <<<"$DISABLED_FANOUT_OUTPUT" \
  || fail 'default-off fanout did not emit its disabled marker'
grep -Fxq 'MAVPROXY_OUTPUT_ARGS=--out=udpout:127.0.0.1:14550' \
  <<<"$DISABLED_FANOUT_OUTPUT" \
  || fail 'disabled fanout changed the established local MAVProxy output'

ENABLED_FANOUT_OUTPUT="$(bash -c '
  eval "$1"
  log() { printf "%s\n" "$*"; }
  FCU_TO_VRX_FANOUT=1
  FCU_TO_VRX_INGRESS_PORT=14556
  FCU_TO_VRX_DESTINATION_PORT=14555
  WS_IP=10.120.2.243
  configure_mavproxy_outputs
  printf "MAVPROXY_OUTPUT_ARGS=%s\n" "${MAVPROXY_OUTPUT_ARGS[*]}"
' _ "$FANOUT_CONFIG_FUNCTION")"
grep -Fxq \
  'FCU_TO_VRX_FANOUT=ENABLED direction=outbound-only destination=10.120.2.243:14555 ingress=127.0.0.1:14556' \
  <<<"$ENABLED_FANOUT_OUTPUT" \
  || fail 'enabled fanout did not emit its bounded topology marker'
grep -Fxq \
  'MAVPROXY_OUTPUT_ARGS=--out=udpout:127.0.0.1:14550 --out=udpout:127.0.0.1:14556' \
  <<<"$ENABLED_FANOUT_OUTPUT" \
  || fail 'enabled fanout did not keep both MAVProxy outputs loopback-only'
FANOUT_SOURCE="$(awk '
  /^[[:space:]]*cat >"\$TELEMETRY_FANOUT" <<'"'"'PYTHON_TELEMETRY_FANOUT'"'"'$/ {
    capture = 1
    next
  }
  capture && /^PYTHON_TELEMETRY_FANOUT$/ { exit }
  capture { print }
' "$HELPER")"
[ -n "$FANOUT_SOURCE" ] || fail 'telemetry fanout source was not extractable'
python3 - "$FANOUT_SOURCE" <<'PYTHON_FANOUT_TEST'
import os
import select
import socket
import subprocess
import sys
import tempfile

source = sys.argv[1]


def free_udp_port():
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
    probe.close()
    return port


ingress_port = free_udp_port()
destination = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
destination.bind(("127.0.0.1", 0))
destination.settimeout(2.0)
destination_port = destination.getsockname()[1]
origin = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
origin.bind(("127.0.0.1", 0))
origin.settimeout(0.3)

with tempfile.TemporaryDirectory() as directory:
    path = os.path.join(directory, "telemetry_fanout.py")
    with open(path, "w", encoding="utf-8") as stream:
        stream.write(source)
    environment = os.environ.copy()
    environment.update(
        {
            "FCU_TO_VRX_WORKSTATION_IP": "127.0.0.1",
            "FCU_TO_VRX_INGRESS_PORT": str(ingress_port),
            "FCU_TO_VRX_DESTINATION_PORT": str(destination_port),
        }
    )
    process = subprocess.Popen(
        [sys.executable, path],
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        readable, _, _ = select.select([process.stdout], [], [], 2.0)
        assert readable, "fanout did not emit its readiness marker"
        ready = process.stdout.readline().strip()
        expected_ready = (
            f"TELEMETRY_FANOUT_READY listen=127.0.0.1:{ingress_port} "
            f"destination=127.0.0.1:{destination_port} direction=outbound-only"
        )
        assert ready == expected_ready, (ready, expected_ready)

        payload = b"servo-output-raw"
        origin.sendto(payload, ("127.0.0.1", ingress_port))
        forwarded, outbound_peer = destination.recvfrom(4096)
        assert forwarded == payload

        destination.sendto(b"workstation-command", outbound_peer)
        try:
            reflected, _ = origin.recvfrom(4096)
        except socket.timeout:
            reflected = None
        assert reflected is None, reflected
        assert process.poll() is None, "fanout exited after return traffic"
    finally:
        process.terminate()
        stdout, stderr = process.communicate(timeout=2.0)
        assert process.returncode == 0, (process.returncode, stdout, stderr)

origin.close()
destination.close()
print("TELEMETRY_FANOUT_TEST=PASS forward=1 return=0")
PYTHON_FANOUT_TEST

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
import contextlib
import io
import os
import re
import sys
import tempfile
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
    WND_PROP_AUTOSIZE = 7
    WND_PROP_ASPECT_RATIO = 8

    def __init__(self, mode, fail_at=None):
        self.calls = []
        self.mode = mode
        if fail_at is None:
            self.fail_at = set()
        elif isinstance(fail_at, str):
            self.fail_at = {fail_at}
        else:
            self.fail_at = set(fail_at)

    def should_fail(self, operation):
        return operation in self.fail_at

    def namedWindow(self, name, flags):
        self.calls.append(("namedWindow", name, flags))
        if self.should_fail("namedWindow"):
            raise RuntimeError("named-window-failed")

    def setWindowProperty(self, name, prop, value):
        self.calls.append(("setWindowProperty", name, prop, value))
        if self.should_fail("setWindowProperty"):
            raise RuntimeError("fullscreen-failed")

    def getWindowImageRect(self, name):
        self.calls.append(("getWindowImageRect", name))
        if self.should_fail("getWindowImageRect"):
            raise RuntimeError("window-rect-failed")
        return (0, 0, 1920, 1080)

    def getWindowProperty(self, name, prop):
        self.calls.append(("getWindowProperty", name, prop))
        if (
            self.should_fail("getWindowProperty")
            or self.should_fail(f"getWindowProperty:{prop}")
        ):
            raise RuntimeError(f"window-property-{prop}-failed")
        if prop == self.WND_PROP_AUTOSIZE:
            return 0.0
        if prop == self.WND_PROP_FULLSCREEN:
            return 1.0 if self.mode == "fullscreen" else 0.0
        if prop == self.WND_PROP_ASPECT_RATIO:
            return 0.0
        raise AssertionError(f"unexpected window property: {prop}")

    def imshow(self, name, _frame):
        self.calls.append(("imshow", name))

    def waitKey(self, delay):
        self.calls.append(("waitKey", delay))
        return -1

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
    def __init__(self, calls):
        self.calls = calls
        self.messages = []

    def publish(self, message):
        self.messages.append(message)
        self.calls.append(("publish", len(self.messages)))


class FakeNode:
    def get_clock(self):
        return self

    def now(self):
        return self

    def to_msg(self):
        return "stamp"


class FakeTime:
    def __init__(self):
        self.value = 0

    def monotonic_ns(self):
        self.value += 1_000_000_000
        return self.value


class FakeNp:
    @staticmethod
    def ascontiguousarray(frame):
        return frame


class Settings:
    def __init__(self, no_display=False):
        self.no_display = no_display


def exercise(
    mode,
    fail_at=None,
    no_display=False,
    frame_count=3,
):
    with tempfile.TemporaryDirectory():
        fake_cv2 = FakeCv2(mode, fail_at)
        calls = fake_cv2.calls
        publisher = FakePublisher(calls)
        frame = FakeFrame()

        def fake_original(*args):
            calls.append(("original_visualize", args[1].no_display))
            for callback_index in range(1, frame_count + 1):
                shown_frame = args[3]()
                if not args[1].no_display:
                    fake_cv2.imshow("Output", shown_frame)
                    fake_cv2.waitKey(1)
            return "ORIGINAL_RESULT"

        namespace = {
            "cv2": fake_cv2,
            "Image": FakeImage,
            "node": FakeNode(),
            "np": FakeNp(),
            "os": os,
            "re": re,
            "original_visualize": fake_original,
            "publisher": publisher,
            "state": {"last_publish_ns": 0, "count": 0},
            "stream_height": 240,
            "period_ns": 100_000_000,
            "time": FakeTime(),
        }
        old_environment = {"HAILO_LOCAL_WINDOW_MODE": os.environ.get("HAILO_LOCAL_WINDOW_MODE")}
        os.environ["HAILO_LOCAL_WINDOW_MODE"] = mode
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                exec(source, namespace)
                settings = Settings(no_display)
                result = namespace["publishing_visualize"](
                    None, settings, None, lambda: frame
                )
        finally:
            for name, value in old_environment.items():
                if value is None:
                    os.environ.pop(name, None)
                else:
                    os.environ[name] = value

        assert result == "ORIGINAL_RESULT"
        assert sum(call[0] == "original_visualize" for call in calls) == 1
        assert len(publisher.messages) == frame_count
        assert publisher.messages[0].header.frame_id == "hailo_overlay"
        return settings, calls, output.getvalue().splitlines()


all_logs = []

settings, calls, logs = exercise("resizable")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("original_visualize", False),
    ("publish", 1),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("publish", 2),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("publish", 3),
    ("imshow", "Output"),
    ("waitKey", 1),
]
assert logs == [
    "HAILO_LOCAL_WINDOW=READY mode=resizable name=Output",
    "HAILO_ROS_FRAME count=1 size=320x240",
]
all_logs.extend(logs)

settings, calls, logs = exercise("fullscreen")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("original_visualize", False),
    ("publish", 1),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("setWindowProperty", "Output", 3, 4),
    ("publish", 2),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("getWindowImageRect", "Output"),
    ("publish", 3),
    ("imshow", "Output"),
    ("waitKey", 1),
]
assert logs == [
    "HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow",
    "HAILO_ROS_FRAME count=1 size=320x240",
    (
        "HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output "
        "rect=0,0,1920,1080 source=getWindowImageRect"
    ),
]
all_logs.extend(logs)

settings, calls, logs = exercise("fullscreen", no_display=True)
assert settings.no_display is True
assert calls == [
    ("original_visualize", True),
    ("publish", 1),
    ("publish", 2),
    ("publish", 3),
]
assert logs == ["HAILO_ROS_FRAME count=1 size=320x240"]
all_logs.extend(logs)

settings, calls, logs = exercise("fullscreen", "namedWindow")
assert settings.no_display is True
assert calls == [
    ("namedWindow", "Output", 3),
    ("destroyWindow", "Output"),
    ("original_visualize", True),
    ("publish", 1),
    ("publish", 2),
    ("publish", 3),
]
assert logs == [
    (
        "HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS mode=fullscreen "
        "stage=namedWindow error=RuntimeError"
    ),
    "HAILO_ROS_FRAME count=1 size=320x240",
]
all_logs.extend(logs)

settings, calls, logs = exercise("fullscreen", "setWindowProperty")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("original_visualize", False),
    ("publish", 1),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("setWindowProperty", "Output", 3, 4),
    ("publish", 2),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("publish", 3),
    ("imshow", "Output"),
    ("waitKey", 1),
]
assert logs == [
    "HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow",
    "HAILO_ROS_FRAME count=1 size=320x240",
    (
        "HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE requested=fullscreen "
        "error=RuntimeError"
    ),
]
all_logs.extend(logs)

settings, calls, logs = exercise("fullscreen", "getWindowImageRect")
assert settings.no_display is False
assert calls == [
    ("namedWindow", "Output", 3),
    ("original_visualize", False),
    ("publish", 1),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("setWindowProperty", "Output", 3, 4),
    ("publish", 2),
    ("imshow", "Output"),
    ("waitKey", 1),
    ("getWindowImageRect", "Output"),
    ("publish", 3),
    ("imshow", "Output"),
    ("waitKey", 1),
]
assert logs == [
    "HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow",
    "HAILO_ROS_FRAME count=1 size=320x240",
    (
        "HAILO_LOCAL_WINDOW=EVIDENCE_UNAVAILABLE mode=fullscreen "
        "name=Output stage=getWindowImageRect error=RuntimeError"
    ),
]
all_logs.extend(logs)


for line in all_logs:
    print(line)

print("WINDOW_BEHAVIOR=PASS modes=3 fallback=headless+resizable evidence=rect published=18")
PYTHON_WINDOW_TEST
)"
grep -Fxq \
  'WINDOW_BEHAVIOR=PASS modes=3 fallback=headless+resizable evidence=rect published=18' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'local-window behavior contract did not pass'
grep -Fxq 'HAILO_LOCAL_WINDOW=READY mode=resizable name=Output' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'resizable window did not emit its ready marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen window did not emit its first-frame gate marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output rect=0,0,1920,1080 source=getWindowImageRect' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen window did not emit its evidence-backed ready marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS mode=fullscreen stage=namedWindow error=RuntimeError' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'window-creation failure did not emit the headless fallback marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE requested=fullscreen error=RuntimeError' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen-property failure did not emit the resizable fallback marker'
grep -Fxq \
  'HAILO_LOCAL_WINDOW=EVIDENCE_UNAVAILABLE mode=fullscreen name=Output stage=getWindowImageRect error=RuntimeError' \
  <<<"$WINDOW_BEHAVIOR_OUTPUT" \
  || fail 'fullscreen rectangle failure did not emit its evidence marker'

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

SERVICE_FUNCTION="$(extract_function reject_command_services)"
[ -n "$SERVICE_FUNCTION" ] || fail 'command-service function was not extractable'
GRAPH_DEADLINE_FUNCTION="$(extract_function ros2_graph_query_before)"
[ -n "$GRAPH_DEADLINE_FUNCTION" ] \
  || fail 'deadline-aware graph-query function was not extractable'
GRAPH_WRAPPER_FUNCTION="$(extract_function ros2_graph_query)"
[ -n "$GRAPH_WRAPPER_FUNCTION" ] || fail 'unbounded graph-query wrapper was not extractable'
WORKSTATION_NODES_FUNCTION="$(extract_function require_workstation_nodes)"
[ -n "$WORKSTATION_NODES_FUNCTION" ] \
  || fail 'workstation-node function was not extractable'
BOUNDED_ECHO_FUNCTION="$(extract_function bounded_topic_echo)"
[ -n "$BOUNDED_ECHO_FUNCTION" ] || fail 'bounded topic-echo function was not extractable'
# The consumer now reads through the source view, so every sandbox that
# evaluates it must carry the view family too. With the batch flag off the view
# delegates to ros2_graph_query_before, so the existing stubs still apply.
SOURCE_VIEW_PREAMBLE="$(sed -n '/^PROBE_MAX_SECONDS=/p' "$HELPER")
$(sed -n '/^PROBE_STARTUP_RESERVE=/p' "$HELPER")
$(sed -n '/^declare -a MAVROS_SOURCE_TOPICS=(/,/^)$/p' "$HELPER")
$(extract_function mavros_source_topic_block)
$(extract_function mavros_source_valid_block)
$(extract_function mavros_source_probe_diagnostics)
$(extract_function mavros_source_probe_generation)
$(extract_function mavros_source_consume_topic)
$(extract_function mavros_source_view)"
[ -n "$(sed -n '/^PROBE_MAX_SECONDS=/p' "$HELPER")" ] \
  || fail 'the probe hard bound was not extractable'
[ -n "$(sed -n '/^PROBE_STARTUP_RESERVE=/p' "$HELPER")" ] \
  || fail 'the probe startup reserve was not extractable'
MAVROS_SOURCE_FUNCTION="$(extract_function require_mavros_source)
$SOURCE_VIEW_PREAMBLE"
[ -n "$MAVROS_SOURCE_FUNCTION" ] || fail 'MAVROS-source function was not extractable'
SOURCE_PROBE_FUNCTION="$(extract_function probe_mavros_source_dataplane)"
[ -n "$SOURCE_PROBE_FUNCTION" ] || fail 'MAVROS-source data-plane probe was not extractable'
INTERRUPT_FUNCTION="$(extract_function on_interrupt)"
[ -n "$INTERRUPT_FUNCTION" ] || fail 'interrupt handler was not extractable'
SERVICE_TRACE="$(mktemp)"
GRAPH_TRACE="$(mktemp)"
trap 'rm -f "$PASS_LOG" "$FAIL_LOG" "$ORDER_LOG" "$LATE_LOG" "$SERVICE_TRACE" "$GRAPH_TRACE"' EXIT

: >"$GRAPH_TRACE"
set +e
WORKSTATION_TRANSIENT_OUTPUT="$(bash -c '
  eval "$1"
  set -u
  TRACE="$2"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { : "$SAFETY_MONITOR_PID"; }
  check_thermal_watchdog() { : "$THERMAL_WATCHDOG_PID"; }
  sleep() { :; }
  graph_nodes() {
    printf "query\n" >>"$TRACE"
    printf "%s\n" /rosbridge_websocket /web_video_server /rosapi
  }
  initial_nodes="$(printf "%s\n" /web_video_server /rosapi)"
  require_workstation_nodes "$initial_nodes" 0
' _ "$WORKSTATION_NODES_FUNCTION" "$GRAPH_TRACE" 2>&1)"
WORKSTATION_TRANSIENT_RC=$?
set -e
[ "$WORKSTATION_TRANSIENT_RC" -eq 0 ] \
  || fail 'one incomplete workstation-node snapshot did not recover'
[ "$(grep -Fc 'query' "$GRAPH_TRACE")" -eq 1 ] \
  || fail 'transient workstation-node recovery changed its re-query count'
grep -Fq \
  'WORKSTATION_NODE_SNAPSHOT_RETRY attempt=1/3 missing=/rosbridge_websocket' \
  <<<"$WORKSTATION_TRANSIENT_OUTPUT" \
  || fail 'transient workstation-node recovery omitted its retry evidence'
grep -Fq 'WORKSTATION_NODE_RECOVERY=PASS attempts=2' \
  <<<"$WORKSTATION_TRANSIENT_OUTPUT" \
  || fail 'transient workstation-node recovery omitted its pass evidence'

: >"$GRAPH_TRACE"
set +e
WORKSTATION_PERSISTENT_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  sleep() { :; }
  graph_nodes() {
    printf "query\n" >>"$TRACE"
    printf "%s\n" /web_video_server /rosapi
  }
  initial_nodes="$(printf "%s\n" /web_video_server /rosapi)"
  require_workstation_nodes "$initial_nodes" 0
' _ "$WORKSTATION_NODES_FUNCTION" "$GRAPH_TRACE" 2>&1)"
WORKSTATION_PERSISTENT_RC=$?
set -e
[ "$WORKSTATION_PERSISTENT_RC" -eq 17 ] \
  || fail 'three incomplete workstation-node snapshots did not fail closed'
[ "$(grep -Fc 'query' "$GRAPH_TRACE")" -eq 2 ] \
  || fail 'persistent workstation-node failure changed its re-query count'
[ "$(grep -Fc 'WORKSTATION_NODE_SNAPSHOT_RETRY' \
  <<<"$WORKSTATION_PERSISTENT_OUTPUT")" -eq 2 ] \
  || fail 'persistent workstation-node failure omitted retry evidence'
grep -Fq \
  'DIE: workstation nodes not visible from the Pi after 3 attempts: /rosbridge_websocket' \
  <<<"$WORKSTATION_PERSISTENT_OUTPUT" \
  || fail 'persistent workstation-node failure changed its terminal verdict'

: >"$GRAPH_TRACE"
set +e
WORKSTATION_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  sleep() { :; }
  graph_nodes() { printf "query\n" >>"$TRACE"; return 75; }
  initial_nodes="$(printf "%s\n" /web_video_server /rosapi)"
  require_workstation_nodes "$initial_nodes" 10
' _ "$WORKSTATION_NODES_FUNCTION" "$GRAPH_TRACE" 2>&1)"
WORKSTATION_DEADLINE_RC=$?
set -e
[ "$WORKSTATION_DEADLINE_RC" -eq 75 ] \
  || fail 'workstation-node retry did not preserve the shared deadline'
[ "$(grep -Fc 'query' "$GRAPH_TRACE")" -eq 1 ] \
  || fail 'workstation-node deadline performed an extra re-query'
! grep -Fq 'DIE:' <<<"$WORKSTATION_DEADLINE_OUTPUT" \
  || fail 'workstation-node deadline was converted into a content verdict'

: >"$GRAPH_TRACE"
set +e
SLOW_PRESENT_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=10
  timeout() {
    printf "%s\n" "$*" >>"$TRACE"
    printf "/rosapi/topics_for_type\n"
    return 137
  }
  ros2_graph_query_before 20 service list --no-daemon --spin-time 2
' _ "$GRAPH_DEADLINE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
SLOW_PRESENT_RC=$?
set -e
[ "$SLOW_PRESENT_RC" -eq 75 ] \
  || fail 'slow-present graph query was accepted after its absolute deadline'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 1 ] \
  || fail 'slow-present graph query performed more than one raw attempt'
grep -Fq -- '--signal=KILL 10s ros2 service list --no-daemon --spin-time 2' \
  "$GRAPH_TRACE" \
  || fail 'graph query did not pass the remaining absolute budget to timeout'
! grep -Fq '/rosapi/topics_for_type' <<<"$SLOW_PRESENT_OUTPUT" \
  || fail 'slow-present graph output escaped after the deadline'

set +e
SLOW_SUCCESS_OUTPUT="$(bash -c '
  eval "$1"
  SECONDS=0
  timeout() {
    command sleep 1
    printf "/rosapi/topics_for_type\n"
    return 0
  }
  ros2_graph_query_before 1 service list --no-daemon --spin-time 2
' _ "$GRAPH_DEADLINE_FUNCTION" 2>&1)"
SLOW_SUCCESS_RC=$?
set -e
[ "$SLOW_SUCCESS_RC" -eq 75 ] \
  || fail 'slow successful graph response was accepted at its absolute deadline'
! grep -Fq '/rosapi/topics_for_type' <<<"$SLOW_SUCCESS_OUTPUT" \
  || fail 'slow successful graph output escaped after the deadline'

set +e
SECONDS=0
PROCESS_TREE_OUTPUT="$(timeout --signal=KILL 1s bash -c 'sleep 5 & wait' 2>&1)"
PROCESS_TREE_RC=$?
PROCESS_TREE_ELAPSED=$SECONDS
set -e
case "$PROCESS_TREE_RC" in 124|137) ;; *)
  fail "process-tree timeout returned $PROCESS_TREE_RC instead of 124/137" ;;
esac
[ "$PROCESS_TREE_ELAPSED" -le 2 ] \
  || fail "process-tree timeout took ${PROCESS_TREE_ELAPSED}s instead of about 1s"
[ -z "$PROCESS_TREE_OUTPUT" ] \
  || fail "process-tree timeout emitted unexpected output: $PROCESS_TREE_OUTPUT"

: >"$GRAPH_TRACE"
set +e
HARD_ECHO_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=10
  timeout() {
    printf "%s\n" "$*" >>"$TRACE"
    return 137
  }
  ros2() {
    printf "UNEXPECTED_DIRECT_ROS2 %s\n" "$*" >>"$TRACE"
    return 99
  }
  bounded_topic_echo 20 5 /mavros/state mavros_msgs/msg/State
' _ "$BOUNDED_ECHO_FUNCTION" "$GRAPH_TRACE" 2>&1)"
HARD_ECHO_RC=$?
set -e
[ "$HARD_ECHO_RC" -eq 75 ] \
  || fail 'hard-killed topic echo did not report absolute-deadline exhaustion'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 1 ] \
  || fail 'bounded topic echo bypassed or repeated its hard timeout wrapper'
grep -Fxq -- \
  '--signal=KILL 10s ros2 topic echo --once --timeout 5 /mavros/state mavros_msgs/msg/State' \
  "$GRAPH_TRACE" \
  || fail 'bounded topic echo did not separate the remaining hard budget from its cooperative wait'
! grep -Fq 'UNEXPECTED_DIRECT_ROS2' "$GRAPH_TRACE" \
  || fail 'finite topic echo bypassed its hard timeout wrapper'
[ -z "$HARD_ECHO_OUTPUT" ] \
  || fail "hard-killed topic echo emitted unexpected output: $HARD_ECHO_OUTPUT"

: >"$GRAPH_TRACE"
set +e
CLAMPED_ECHO_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=18
  timeout() {
    printf "%s\n" "$*" >>"$TRACE"
    return 137
  }
  ros2() { printf "UNEXPECTED_DIRECT_ROS2\n"; return 99; }
  bounded_topic_echo 20 5 /mavros/state mavros_msgs/msg/State
' _ "$BOUNDED_ECHO_FUNCTION" "$GRAPH_TRACE" 2>&1)"
CLAMPED_ECHO_RC=$?
set -e
[ "$CLAMPED_ECHO_RC" -eq 75 ] \
  || fail 'short remaining topic-echo budget did not report deadline exhaustion'
grep -Fxq -- \
  '--signal=KILL 2s ros2 topic echo --once --timeout 2 /mavros/state mavros_msgs/msg/State' \
  "$GRAPH_TRACE" \
  || fail 'topic echo did not clamp both hard and cooperative waits to the short remaining budget'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 1 ] \
  || fail 'short remaining topic-echo budget performed more than one raw attempt'
[ -z "$CLAMPED_ECHO_OUTPUT" ] \
  || fail "short remaining topic echo emitted unexpected output: $CLAMPED_ECHO_OUTPUT"

set +e
RAW_75_OUTPUT="$(bash -c '
  eval "$1"
  SECONDS=0
  timeout() {
    shift 2
    "$@"
  }
  ros2() { return 75; }
  bounded_topic_echo 10 5 /mavros/state mavros_msgs/msg/State
' _ "$BOUNDED_ECHO_FUNCTION" 2>&1)"
RAW_75_RC=$?
set -e
[ "$RAW_75_RC" -eq 1 ] \
  || fail 'bounded topic echo confused a raw command status with deadline exhaustion'
[ -z "$RAW_75_OUTPUT" ] \
  || fail "raw topic-echo failure emitted unexpected output: $RAW_75_OUTPUT"

set +e
UNBOUNDED_RAW_75_OUTPUT="$(bash -c '
  eval "$1"
  timeout() { printf "UNEXPECTED_TIMEOUT\n"; exit 99; }
  ros2() { return 75; }
  bounded_topic_echo 0 5 /mavros/state mavros_msgs/msg/State
' _ "$BOUNDED_ECHO_FUNCTION" 2>&1)"
UNBOUNDED_RAW_75_RC=$?
set -e
[ "$UNBOUNDED_RAW_75_RC" -eq 1 ] \
  || fail 'deadline-zero topic echo confused raw status 75 with deadline exhaustion'
[ -z "$UNBOUNDED_RAW_75_OUTPUT" ] \
  || fail "deadline-zero raw topic-echo failure emitted unexpected output: $UNBOUNDED_RAW_75_OUTPUT"

UNBOUNDED_ECHO_OUTPUT="$(bash -c '
  eval "$1"
  timeout() { printf "UNEXPECTED_TIMEOUT\n"; exit 99; }
  ros2() { printf "SETUP_ECHO=PASS %s\n" "$*"; }
  bounded_topic_echo 0 5 /mavros/state mavros_msgs/msg/State
' _ "$BOUNDED_ECHO_FUNCTION")"
grep -Fxq \
  'SETUP_ECHO=PASS topic echo --once --timeout 5 /mavros/state mavros_msgs/msg/State' \
  <<<"$UNBOUNDED_ECHO_OUTPUT" \
  || fail 'deadline-zero topic echo changed behavior'
! grep -Fq 'UNEXPECTED_TIMEOUT' <<<"$UNBOUNDED_ECHO_OUTPUT" \
  || fail 'deadline-zero topic echo invoked the hard timeout wrapper'

: >"$GRAPH_TRACE"
set +e
MAVROS_SOURCE_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    return 75
  }
  check_command_sentinel() { printf "UNEXPECTED_SENTINEL\n"; exit 98; }
  sleep() { printf "UNEXPECTED_SLEEP\n"; exit 97; }
  die() { printf "UNEXPECTED_DIE %s\n" "$*"; exit 96; }
  require_mavros_source /mavros/state 20
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
MAVROS_SOURCE_DEADLINE_RC=$?
set -e
[ "$MAVROS_SOURCE_DEADLINE_RC" -eq 75 ] \
  || fail 'MAVROS-source query did not propagate absolute-deadline exhaustion'
grep -Fxq \
  'query:20 topic info --verbose --no-daemon --spin-time 2 /mavros/state' \
  "$GRAPH_TRACE" \
  || fail 'MAVROS-source query did not receive the finite phase deadline'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 1 ] \
  || fail 'MAVROS-source deadline exhaustion was retried'
[ -z "$MAVROS_SOURCE_DEADLINE_OUTPUT" ] \
  || fail "MAVROS-source deadline path ran an unexpected guard: $MAVROS_SOURCE_DEADLINE_OUTPUT"

: >"$GRAPH_TRACE"
set +e
MAVROS_SOURCE_EVIDENCE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Type: sensor_msgs/msg/Imu\n"
    printf "Publisher count: 0\n"
    printf "Subscription count: 1\n"
    return 0
  }
  check_command_sentinel() { printf "sentinel\n" >>"$TRACE"; }
  sleep() { printf "sleep:%s\n" "$1" >>"$TRACE"; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { printf "PROBE %s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/imu/data 0
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
MAVROS_SOURCE_EVIDENCE_RC=$?
set -e
[ "$MAVROS_SOURCE_EVIDENCE_RC" -eq 17 ] \
  || fail 'zero-publisher MAVROS source did not reach the terminal verdict'
grep -Fxq \
  'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/imu/data (publisher count 0)' \
  <<<"$MAVROS_SOURCE_EVIDENCE_OUTPUT" \
  || fail 'terminal MAVROS-source verdict text changed'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'zero-publisher MAVROS source did not retry exactly three times'
[ "$(grep -Fc 'sentinel' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'zero-publisher MAVROS source skipped the command sentinel'
[ "$(grep -Fc 'sleep:1' "$GRAPH_TRACE")" -eq 2 ] \
  || fail 'zero-publisher MAVROS source did not back off between attempts'
for attempt_index in 1 2 3; do
  grep -Fq \
    "EVIDENCE MAVROS_SOURCE_EVIDENCE topic=/mavros/imu/data attempt=$attempt_index" \
    <<<"$MAVROS_SOURCE_EVIDENCE_OUTPUT" \
    || fail "zero-publisher MAVROS source did not record attempt $attempt_index evidence"
done
[ "$(grep -Fc 'raw: Publisher count: 0' <<<"$MAVROS_SOURCE_EVIDENCE_OUTPUT")" -eq 3 ] \
  || fail 'zero-publisher MAVROS source discarded the raw query body'
[ "$(grep -Fc 'PROBE /mavros/imu/data' <<<"$MAVROS_SOURCE_EVIDENCE_OUTPUT")" -eq 1 ] \
  || fail 'zero-publisher MAVROS source did not run exactly one bounded data-plane probe'

: >"$GRAPH_TRACE"
set +e
MAVROS_SOURCE_RECOVERY_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Type: sensor_msgs/msg/Imu\n"
    if [ "$(grep -Fc "query:" "$TRACE")" -eq 1 ]; then
      printf "Publisher count: 0\n"
      return 0
    fi
    printf "Publisher count: 1\n"
    printf "Node name: mavros\n"
    printf "Node namespace: /\n"
    printf "Endpoint type: PUBLISHER\n"
    return 0
  }
  check_command_sentinel() { printf "sentinel\n" >>"$TRACE"; }
  sleep() { printf "sleep:%s\n" "$1" >>"$TRACE"; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { printf "UNEXPECTED_PROBE\n"; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/imu/data 0
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
MAVROS_SOURCE_RECOVERY_RC=$?
set -e
[ "$MAVROS_SOURCE_RECOVERY_RC" -eq 0 ] \
  || fail 'MAVROS source did not recover after a transient zero-publisher reading'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 2 ] \
  || fail 'recovering MAVROS source did not stop querying once verified'
[ "$(grep -Fc 'sleep:1' "$GRAPH_TRACE")" -eq 1 ] \
  || fail 'recovering MAVROS source did not back off exactly once'
! grep -Fq 'UNEXPECTED_PROBE' <<<"$MAVROS_SOURCE_RECOVERY_OUTPUT" \
  || fail 'recovering MAVROS source ran the failure-path data-plane probe'

: >"$GRAPH_TRACE"
set +e
MAVROS_SOURCE_PROBE_HANDOFF="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  ros2_graph_query_before() {
    printf "query\n" >>"$TRACE"
    printf "Publisher count: 0\n"
    return 0
  }
  check_command_sentinel() { :; }
  sleep() { :; }
  log_error() { :; }
  probe_mavros_source_dataplane() { printf "PROBE_ARGS:%s\n" "$*" >>"$TRACE"; }
  die() { exit 17; }
  require_mavros_source /mavros/imu/data 20
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
MAVROS_SOURCE_PROBE_HANDOFF_RC=$?
set -e
[ "$MAVROS_SOURCE_PROBE_HANDOFF_RC" -eq 17 ] \
  || fail 'finite-deadline MAVROS source did not reach the terminal verdict'
[ "$(grep -Fxc 'query' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'the probe-handoff case did not reach its query stub, so its result is vacuous'
grep -Fxq 'PROBE_ARGS:/mavros/imu/data 20' "$GRAPH_TRACE" \
  || fail 'MAVROS source did not hand the parent deadline to the data-plane probe'

: >"$GRAPH_TRACE"
set +e
SOURCE_PROBE_BOUNDED_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=10
  log_error() { printf "PROBE %s\n" "$*"; }
  timeout() {
    printf "timeout:%s\n" "$*" >>"$TRACE"
    printf "header:\n  frame_id: base_link\n"
    return 137
  }
  probe_mavros_source_dataplane /mavros/imu/data 12
  printf "probe_returned=%s\n" "$?"
' _ "$SOURCE_PROBE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
set -e
grep -Fxq 'probe_returned=0' <<<"$SOURCE_PROBE_BOUNDED_OUTPUT" \
  || fail 'data-plane probe did not stay neutral after a SIGKILL result'
grep -Fxq \
  'timeout:--signal=KILL 2s ros2 topic echo --once --timeout 2 --no-arr --qos-reliability best_effort --qos-history keep_last --qos-depth 10 /mavros/imu/data sensor_msgs/msg/Imu' \
  "$GRAPH_TRACE" \
  || fail 'data-plane probe did not clamp its hard bound to the remaining parent budget'
grep -Fq 'PROBE MAVROS_SOURCE_PROBE topic=/mavros/imu/data type=sensor_msgs/msg/Imu bound=2s probe_rc=137' \
  <<<"$SOURCE_PROBE_BOUNDED_OUTPUT" \
  || fail 'data-plane probe did not record its bound and result'
[ "$(grep -Fc 'raw: ' <<<"$SOURCE_PROBE_BOUNDED_OUTPUT")" -eq 2 ] \
  || fail 'data-plane probe did not record one prefixed line per output line'

: >"$GRAPH_TRACE"
set +e
SOURCE_PROBE_EXHAUSTED_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=12
  log_error() { printf "PROBE %s\n" "$*"; }
  timeout() { printf "UNEXPECTED_PROBE_LAUNCH\n" >>"$TRACE"; return 0; }
  probe_mavros_source_dataplane /mavros/imu/data 12
  printf "probe_returned=%s\n" "$?"
' _ "$SOURCE_PROBE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
set -e
grep -Fxq 'probe_returned=0' <<<"$SOURCE_PROBE_EXHAUSTED_OUTPUT" \
  || fail 'exhausted-deadline data-plane probe did not stay neutral'
grep -Fq 'PROBE MAVROS_SOURCE_PROBE topic=/mavros/imu/data result=SKIPPED reason=deadline-exhausted' \
  <<<"$SOURCE_PROBE_EXHAUSTED_OUTPUT" \
  || fail 'exhausted-deadline data-plane probe did not record the skip'
[ ! -s "$GRAPH_TRACE" ] \
  || fail 'data-plane probe launched after the parent deadline was exhausted'

: >"$GRAPH_TRACE"
set +e
SOURCE_PROBE_UNBOUNDED_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=900
  log_error() { printf "PROBE %s\n" "$*"; }
  timeout() {
    printf "timeout:%s\n" "$*" >>"$TRACE"
    return 0
  }
  probe_mavros_source_dataplane /mavros/imu/data 0
  printf "probe_returned=%s\n" "$?"
' _ "$SOURCE_PROBE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
set -e
grep -Fxq 'probe_returned=0' <<<"$SOURCE_PROBE_UNBOUNDED_OUTPUT" \
  || fail 'hold-mode data-plane probe did not stay neutral'
grep -Fq -- '--signal=KILL 5s ros2 topic echo --once --timeout 5 ' "$GRAPH_TRACE" \
  || fail 'hold-mode data-plane probe did not keep its own finite hard bound'
grep -Fq 'PROBE MAVROS_SOURCE_PROBE topic=/mavros/imu/data raw: <no probe output>' \
  <<<"$SOURCE_PROBE_UNBOUNDED_OUTPUT" \
  || fail 'data-plane probe did not record an empty result explicitly'

set +e
: >"$GRAPH_TRACE"
SOURCE_DEADLINE_ATTRIBUTION_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  ros2_graph_query_before() {
    printf "query\n" >>"$TRACE"
    printf "Publisher count: 0\n"
    return 0
  }
  check_command_sentinel() { :; }
  sleep() { :; }
  log_error() { :; }
  probe_mavros_source_dataplane() { SECONDS=20; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/imu/data 20
  printf "source_returned=%s\n" "$?"
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
set -e
[ "$(grep -Fxc 'query' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'the deadline-attribution case did not reach its query stub, so its result is vacuous'
grep -Fxq 'source_returned=75' <<<"$SOURCE_DEADLINE_ATTRIBUTION_OUTPUT" \
  || fail 'a probe that consumed the parent budget was not reported as deadline exhaustion'
! grep -Fq 'DIE:' <<<"$SOURCE_DEADLINE_ATTRIBUTION_OUTPUT" \
  || fail 'deadline exhaustion after the data-plane probe was reported as a content failure'

set +e
INTERRUPT_PENDING_OUTPUT="$(bash -c '
  eval "$1"
  record_stop_trigger() { :; }
  log() { printf "LOG %s\n" "$*"; }
  LIFECYCLE_TRANSITION_ACTIVE=0
  SOURCE_FAILURE_PENDING=1
  HOLD_ACTIVE=1
  WINDOW_COMPLETE=1
  STOP_REQUESTED=0
  on_interrupt
  printf "interrupt_returned=%s\n" "$?"
' _ "$INTERRUPT_FUNCTION" 2>&1)"
set -e
grep -Fxq 'interrupt_returned=0' <<<"$INTERRUPT_PENDING_OUTPUT" \
  || fail 'interrupt during a pending source failure exited instead of deferring'
! grep -Fq 'PI_SOURCE_HOLD=STOP operator-requested' <<<"$INTERRUPT_PENDING_OUTPUT" \
  || fail 'interrupt during a pending source failure was recorded as an operator stop'

set +e
INTERRUPT_CLEAN_OUTPUT="$(bash -c '
  eval "$1"
  record_stop_trigger() { :; }
  log() { printf "LOG %s\n" "$*"; }
  LIFECYCLE_TRANSITION_ACTIVE=0
  SOURCE_FAILURE_PENDING=0
  HOLD_ACTIVE=1
  WINDOW_COMPLETE=1
  STOP_REQUESTED=0
  on_interrupt
  printf "interrupt_returned=%s\n" "$?"
' _ "$INTERRUPT_FUNCTION" 2>&1)"
INTERRUPT_CLEAN_RC=$?
set -e
[ "$INTERRUPT_CLEAN_RC" -eq 0 ] \
  || fail 'operator hold stop no longer exits cleanly'
grep -Fq 'PI_SOURCE_HOLD=STOP operator-requested' <<<"$INTERRUPT_CLEAN_OUTPUT" \
  || fail 'operator hold stop no longer records its marker'
! grep -Fq 'interrupt_returned=' <<<"$INTERRUPT_CLEAN_OUTPUT" \
  || fail 'operator hold stop returned instead of exiting'

run_third_attempt_interrupt() {
  local trigger="$1"
  bash -c '
    eval "$1"
    eval "$2"
    TRIGGER="$3"
    SECONDS=0
    LIFECYCLE_TRANSITION_ACTIVE=0
    SOURCE_FAILURE_PENDING=0
    HOLD_ACTIVE=1
    WINDOW_COMPLETE=1
    STOP_REQUESTED=0
    SENTINEL_CALLS=0
    record_stop_trigger() { :; }
    log() { printf "LOG %s\n" "$*"; }
    log_error() {
      printf "LOG %s\n" "$*"
      if [ "$TRIGGER" = evidence ]; then
        case "$*" in
          *"attempt=3 query_rc"*) on_interrupt ;;
        esac
      fi
    }
    ros2_graph_query_before() { printf "Publisher count: 0\n"; return 0; }
    sleep() { :; }
    probe_mavros_source_dataplane() { :; }
    check_command_sentinel() {
      SENTINEL_CALLS=$((SENTINEL_CALLS + 1))
      printf "SENTINEL pending=%s\n" "$SOURCE_FAILURE_PENDING"
      if [ "$TRIGGER" = sentinel ] && [ "$SENTINEL_CALLS" -eq 3 ]; then
        on_interrupt
      fi
    }
    die() { printf "DIE: %s\n" "$*"; exit 1; }
    require_mavros_source /mavros/imu/data 0
    printf "source_returned=%s\n" "$?"
  ' _ "$MAVROS_SOURCE_FUNCTION" "$INTERRUPT_FUNCTION" "$trigger" 2>&1
}

for interrupt_trigger in evidence sentinel; do
  set +e
  THIRD_ATTEMPT_OUTPUT="$(run_third_attempt_interrupt "$interrupt_trigger")"
  THIRD_ATTEMPT_RC=$?
  set -e
  [ "$THIRD_ATTEMPT_RC" -eq 1 ] \
    || fail "interrupt during $interrupt_trigger work on attempt 3 did not fail closed"
  grep -Fq \
    'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/imu/data (publisher count 0)' \
    <<<"$THIRD_ATTEMPT_OUTPUT" \
    || fail "interrupt during $interrupt_trigger work on attempt 3 suppressed the content verdict"
  grep -Fq 'interrupt deferred until the pending source failure is reported' \
    <<<"$THIRD_ATTEMPT_OUTPUT" \
    || fail "interrupt during $interrupt_trigger work on attempt 3 was not deferred"
  ! grep -Fq 'PI_SOURCE_HOLD=STOP operator-requested' <<<"$THIRD_ATTEMPT_OUTPUT" \
    || fail "interrupt during $interrupt_trigger work on attempt 3 exited as an operator stop"
done

set +e
THIRD_ATTEMPT_LATCH_ORDER="$(run_third_attempt_interrupt none)"
set -e
[ "$(grep -c '^SENTINEL pending=1$' <<<"$THIRD_ATTEMPT_LATCH_ORDER")" -eq 1 ] \
  || fail 'the pending-failure latch was not raised before the attempt-3 sentinel check'
[ "$(grep -c '^SENTINEL pending=0$' <<<"$THIRD_ATTEMPT_LATCH_ORDER")" -eq 2 ] \
  || fail 'the pending-failure latch was raised before the third attempt was known'

# The MAVROS-source consumer reads its endpoint evidence through one query call.
# The guards below pin today's argument vector, body forwarding, stream
# separation, status classes, and identity decisions so that replacing that call
# cannot silently change what the consumer sees. The argument vector is recorded
# one positional argument per line, with its count, so that argument boundaries
# are compared rather than a flattened string; every attempt's forwarded body is
# compared as ordered consumer-visible text; and the two streams are captured and
# compared separately. Command substitution and the reconstruction below strip
# trailing newlines, so these guards do not compare raw standard-output bytes.
SEAM_QUERY_BODY="$(printf '%s\n' \
  'Type: mavros_msgs/msg/State' \
  'Publisher count: 0' \
  '  Reliability: RELIABLE' \
  'Subscription count: 1')"

run_seam_cli_characterization() {
  bash -c '
    eval "$1"
    TRACE="$2"
    BODY="$3"
    ros2_graph_query_before() {
      printf "argc:%s\n" "$#" >>"$TRACE"
      printf "argv:%s\n" "$@" >>"$TRACE"
      printf "SEAM_STDERR_MARKER\n" >&2
      printf "%s\n" "$BODY"
      return 0
    }
    check_command_sentinel() { :; }
    sleep() { :; }
    log_error() { printf "EVIDENCE %s\n" "$*"; }
    probe_mavros_source_dataplane() { :; }
    die() { printf "DIE: %s\n" "$*"; exit 17; }
    require_mavros_source /mavros/state 0
  ' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" "$SEAM_QUERY_BODY"
}

: >"$GRAPH_TRACE"
set +e
SEAM_CLI_STDOUT="$(run_seam_cli_characterization 2>/dev/null)"
SEAM_CLI_CONTRACT_RC=$?
set -e
SEAM_CLI_ARGV="$(<"$GRAPH_TRACE")"
SEAM_CLI_STDERR="$(run_seam_cli_characterization 2>&1 1>/dev/null || true)"
[ "$SEAM_CLI_CONTRACT_RC" -eq 17 ] \
  || fail 'the characterized MAVROS-source seam did not reach the terminal verdict'

SEAM_ATTEMPT_ARGV="$(printf '%s\n' \
  'argc:8' \
  'argv:0' \
  'argv:topic' \
  'argv:info' \
  'argv:--verbose' \
  'argv:--no-daemon' \
  'argv:--spin-time' \
  'argv:2' \
  'argv:/mavros/state')"
[ "$SEAM_CLI_ARGV" = "$(printf '%s\n%s\n%s' \
  "$SEAM_ATTEMPT_ARGV" "$SEAM_ATTEMPT_ARGV" "$SEAM_ATTEMPT_ARGV")" ] \
  || fail 'the MAVROS-source query argument vector, argument count, or attempt count changed'

for seam_body_attempt in 1 2 3; do
  SEAM_CAPTURED_BODY="$(awk \
    -v prefix="EVIDENCE MAVROS_SOURCE_EVIDENCE topic=/mavros/state attempt=$seam_body_attempt raw: " '
    index($0, prefix) == 1 { print substr($0, length(prefix) + 1) }
  ' <<<"$SEAM_CLI_STDOUT")"
  [ "$SEAM_CAPTURED_BODY" = "$SEAM_QUERY_BODY" ] \
    || fail "the MAVROS-source seam no longer forwards the attempt $seam_body_attempt query body as ordered consumer-visible text"
done

[ "$SEAM_CLI_STDERR" = "$(printf '%s\n%s\n%s' \
  'SEAM_STDERR_MARKER' 'SEAM_STDERR_MARKER' 'SEAM_STDERR_MARKER')" ] \
  || fail 'the MAVROS-source query standard-error stream changed'
! grep -Fq 'SEAM_STDERR_MARKER' <<<"$SEAM_CLI_STDOUT" \
  || fail 'the MAVROS-source seam captured standard error into the query body'
grep -Fxq \
  'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/state (publisher count 0)' \
  <<<"$SEAM_CLI_STDOUT" \
  || fail 'the characterized MAVROS-source terminal verdict text changed'

: >"$GRAPH_TRACE"
set +e
SEAM_STATUS_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Publisher count: 1\n"
    printf "Node name: mavros\n"
    printf "Node namespace: /\n"
    printf "Endpoint type: PUBLISHER\n"
    return 42
  }
  check_command_sentinel() { :; }
  sleep() { :; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { :; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/state 0
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
SEAM_STATUS_RC=$?
set -e
[ "$SEAM_STATUS_RC" -eq 17 ] \
  || fail 'a non-zero non-75 query status no longer fails closed'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'a non-zero non-75 query status changed the retry count'
for seam_status_attempt in 1 2 3; do
  grep -Fq \
    "EVIDENCE MAVROS_SOURCE_EVIDENCE topic=/mavros/state attempt=$seam_status_attempt query_rc=42 verdict=query failed" \
    <<<"$SEAM_STATUS_OUTPUT" \
    || fail "a non-zero non-75 query status is no longer reported verbatim on attempt $seam_status_attempt"
done
[ "$(grep -Fc 'raw: Publisher count: 1' <<<"$SEAM_STATUS_OUTPUT")" -eq 3 ] \
  || fail 'a non-zero non-75 query status stopped recording the raw query body'
grep -Fxq \
  'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/state (query failed)' \
  <<<"$SEAM_STATUS_OUTPUT" \
  || fail 'a non-zero non-75 query status no longer reports a failed query'

: >"$GRAPH_TRACE"
set +e
SEAM_NAMESPACED_UNKNOWN_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Publisher count: 1\n"
    printf "Node name: _NODE_NAME_UNKNOWN_\n"
    printf "Node namespace: /mavros\n"
    printf "Endpoint type: PUBLISHER\n"
    return 0
  }
  check_command_sentinel() { :; }
  sleep() { printf "UNEXPECTED_SLEEP\n"; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { printf "UNEXPECTED_PROBE\n"; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/state 0
  printf "source_returned=%s\n" "$?"
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
set -e
grep -Fxq 'source_returned=0' <<<"$SEAM_NAMESPACED_UNKNOWN_OUTPUT" \
  || fail 'a MAVROS-namespaced unknown node name is no longer accepted on the first attempt'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 1 ] \
  || fail 'a MAVROS-namespaced unknown node name was retried'
! grep -Eq 'UNEXPECTED_SLEEP|UNEXPECTED_PROBE|^DIE:' <<<"$SEAM_NAMESPACED_UNKNOWN_OUTPUT" \
  || fail 'a MAVROS-namespaced unknown node name took a failure path'

run_unknown_identity_case() {
  local node_name="$1" node_namespace="$2"
  : >"$GRAPH_TRACE"
  bash -c '
    eval "$1"
    TRACE="$2"
    NODE_NAME="$3"
    NODE_NAMESPACE="$4"
    ros2_graph_query_before() {
      printf "query:%s\n" "$*" >>"$TRACE"
      printf "Publisher count: 1\n"
      printf "Node name: %s\n" "$NODE_NAME"
      printf "Node namespace: %s\n" "$NODE_NAMESPACE"
      printf "Endpoint type: PUBLISHER\n"
      return 0
    }
    check_command_sentinel() { :; }
    sleep() { printf "backoff\n" >>"$TRACE"; }
    log_error() { printf "EVIDENCE %s\n" "$*"; }
    probe_mavros_source_dataplane() { printf "PROBE\n"; }
    die() { printf "DIE: %s\n" "$*"; exit 17; }
    require_mavros_source /mavros/state 0
  ' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" "$node_name" "$node_namespace" 2>&1
}

while read -r unknown_node_name unknown_node_namespace; do
  set +e
  UNKNOWN_IDENTITY_OUTPUT="$(run_unknown_identity_case \
    "$unknown_node_name" "$unknown_node_namespace")"
  UNKNOWN_IDENTITY_RC=$?
  set -e
  [ "$UNKNOWN_IDENTITY_RC" -eq 17 ] \
    || fail "an unresolved publisher identity ($unknown_node_name in $unknown_node_namespace) no longer fails closed"
  [ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 3 ] \
    || fail "an unresolved publisher identity ($unknown_node_name in $unknown_node_namespace) changed its retry count"
  [ "$(grep -Fxc 'backoff' "$GRAPH_TRACE")" -eq 2 ] \
    || fail "an unresolved publisher identity ($unknown_node_name in $unknown_node_namespace) changed its back-off count"
  grep -Fxq \
    'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/state (publisher identity temporarily unknown)' \
    <<<"$UNKNOWN_IDENTITY_OUTPUT" \
    || fail "an unresolved publisher identity ($unknown_node_name in $unknown_node_namespace) changed its terminal verdict"
  [ "$(grep -Fxc 'PROBE' <<<"$UNKNOWN_IDENTITY_OUTPUT")" -eq 1 ] \
    || fail "an unresolved publisher identity ($unknown_node_name in $unknown_node_namespace) skipped the data-plane probe"
done <<'UNKNOWN_IDENTITY_CASES'
_NODE_NAME_UNKNOWN_ /
mavros _NODE_NAMESPACE_UNKNOWN_
UNKNOWN_IDENTITY_CASES

: >"$GRAPH_TRACE"
set +e
SEAM_FOREIGN_PUBLISHER_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Publisher count: 1\n"
    printf "Node name: rosbridge_websocket\n"
    printf "Node namespace: /\n"
    printf "Endpoint type: PUBLISHER\n"
    return 0
  }
  check_command_sentinel() { :; }
  sleep() { printf "UNEXPECTED_SLEEP\n"; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { printf "UNEXPECTED_PROBE\n"; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/state 0
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
SEAM_FOREIGN_PUBLISHER_RC=$?
set -e
[ "$SEAM_FOREIGN_PUBLISHER_RC" -eq 17 ] \
  || fail 'a foreign MAVROS-source publisher no longer fails closed'
grep -Fxq 'DIE: unexpected publisher on /mavros/state: /rosbridge_websocket' \
  <<<"$SEAM_FOREIGN_PUBLISHER_OUTPUT" \
  || fail 'a foreign MAVROS-source publisher changed its rejection text'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 1 ] \
  || fail 'a foreign MAVROS-source publisher was retried instead of rejected immediately'
! grep -Eq 'UNEXPECTED_SLEEP|UNEXPECTED_PROBE' <<<"$SEAM_FOREIGN_PUBLISHER_OUTPUT" \
  || fail 'a foreign MAVROS-source publisher took the retry or probe path'

: >"$GRAPH_TRACE"
set +e
SEAM_NO_PUBLISHER_BLOCK_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  ros2_graph_query_before() {
    printf "query:%s\n" "$*" >>"$TRACE"
    printf "Publisher count: 1\n"
    printf "Node name: mavros\n"
    printf "Node namespace: /\n"
    printf "Endpoint type: SUBSCRIPTION\n"
    return 0
  }
  check_command_sentinel() { :; }
  sleep() { :; }
  log_error() { printf "EVIDENCE %s\n" "$*"; }
  probe_mavros_source_dataplane() { :; }
  die() { printf "DIE: %s\n" "$*"; exit 17; }
  require_mavros_source /mavros/state 0
' _ "$MAVROS_SOURCE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
SEAM_NO_PUBLISHER_BLOCK_RC=$?
set -e
[ "$SEAM_NO_PUBLISHER_BLOCK_RC" -eq 17 ] \
  || fail 'a counted publisher without a publisher endpoint block no longer fails closed'
[ "$(grep -Fc 'query:' "$GRAPH_TRACE")" -eq 3 ] \
  || fail 'a counted publisher without a publisher endpoint block changed its retry count'
grep -Fxq \
  'DIE: MAVROS source endpoint failed after 3 attempts: /mavros/state (publisher identity unavailable)' \
  <<<"$SEAM_NO_PUBLISHER_BLOCK_OUTPUT" \
  || fail 'a counted publisher without a publisher endpoint block changed its terminal verdict'

: >"$GRAPH_TRACE"
set +e
SHARED_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=10
  timeout() {
    printf "%s\n" "$*" >>"$TRACE"
    printf "temporary graph failure\n"
    return 1
  }
  sleep() { SECONDS=$((SECONDS + $1)); }
  ros2_graph_query_before 12 topic list --no-daemon --spin-time 2
' _ "$GRAPH_DEADLINE_FUNCTION" "$GRAPH_TRACE" 2>&1)"
SHARED_DEADLINE_RC=$?
set -e
[ "$SHARED_DEADLINE_RC" -eq 75 ] \
  || fail 'graph retries did not stop at their shared absolute deadline'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 2 ] \
  || fail 'graph retries reset the absolute deadline per raw attempt'
sed -n '1p' "$GRAPH_TRACE" | grep -Fq -- '--signal=KILL 2s ros2 topic list' \
  || fail 'first graph attempt did not receive the full remaining budget'
sed -n '2p' "$GRAPH_TRACE" | grep -Fq -- '--signal=KILL 1s ros2 topic list' \
  || fail 'second graph attempt did not receive the reduced shared budget'
! grep -Fq 'temporary graph failure' <<<"$SHARED_DEADLINE_OUTPUT" \
  || fail 'deadline-exhausted graph output escaped to the caller'

UNBOUNDED_GRAPH_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  ros2() { printf "SETUP_GRAPH=PASS %s\n" "$*"; }
  timeout() { printf "UNEXPECTED_TIMEOUT\n"; exit 99; }
  ros2_graph_query node list --no-daemon --spin-time 3
' _ "$GRAPH_DEADLINE_FUNCTION" "$GRAPH_WRAPPER_FUNCTION")"
grep -Fxq 'SETUP_GRAPH=PASS node list --no-daemon --spin-time 3' \
  <<<"$UNBOUNDED_GRAPH_OUTPUT" \
  || fail 'deadline-zero setup graph query changed behavior'
! grep -Fq 'UNEXPECTED_TIMEOUT' <<<"$UNBOUNDED_GRAPH_OUTPUT" \
  || fail 'deadline-zero setup graph query invoked timeout'

: >"$SERVICE_TRACE"
SERVICE_RECOVERY_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  SAFETY_MONITOR_PID=11
  THERMAL_WATCHDOG_PID=12
  ros2_graph_query_before() {
    shift
    local query_count
    printf "query\n" >>"$TRACE"
    query_count="$(wc -l <"$TRACE")"
    if [ "$query_count" -eq 1 ]; then
      printf "/rosapi/get_time\n"
    else
      printf "/rosapi/topics_for_type\n"
    fi
  }
  sleep() {
    SECONDS=$((SECONDS + $1))
    printf "retry-sleep=%s\n" "$1"
  }
  check_command_sentinel() { printf "retry-guard=command\n"; }
  check_thermal_watchdog() { printf "retry-guard=thermal\n"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  reject_command_services 0
' _ "$SERVICE_FUNCTION" "$SERVICE_TRACE")"
[ "$(wc -l <"$SERVICE_TRACE")" -eq 2 ] \
  || fail 'transient rosapi service miss was not retried exactly once'
[ "$(grep -Fc 'retry-sleep=1' <<<"$SERVICE_RECOVERY_OUTPUT")" -eq 1 ] \
  || fail 'transient rosapi service miss did not use one bounded retry sleep'
[ "$(grep -Fc 'retry-guard=command' <<<"$SERVICE_RECOVERY_OUTPUT")" -eq 1 ] \
  || fail 'semantic rosapi retry did not check the command sentinel'
[ "$(grep -Fc 'retry-guard=thermal' <<<"$SERVICE_RECOVERY_OUTPUT")" -eq 1 ] \
  || fail 'semantic rosapi retry did not check the thermal watchdog'

: >"$SERVICE_TRACE"
set +e
SERVICE_EXHAUSTED_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  ros2_graph_query_before() {
    shift
    printf "query\n" >>"$TRACE"
    printf "/rosapi/get_time\n"
  }
  sleep() { SECONDS=$((SECONDS + $1)); }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  reject_command_services 0
' _ "$SERVICE_FUNCTION" "$SERVICE_TRACE" 2>&1)"
SERVICE_EXHAUSTED_RC=$?
set -e
[ "$SERVICE_EXHAUSTED_RC" -eq 17 ] \
  || fail 'persistent rosapi service miss did not fail closed'
[ "$(wc -l <"$SERVICE_TRACE")" -eq 3 ] \
  || fail 'persistent rosapi service miss did not stop after three observations'
grep -Fq 'workstation rosapi topics_for_type service is not visible from the Pi' \
  <<<"$SERVICE_EXHAUSTED_OUTPUT" \
  || fail 'persistent rosapi service miss changed the fail-closed reason'

: >"$SERVICE_TRACE"
set +e
SERVICE_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=1
  ros2_graph_query_before() {
    shift
    printf "query\n" >>"$TRACE"
    printf "/rosapi/topics_for_type\n"
  }
  sleep() { SECONDS=$((SECONDS + $1)); }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  reject_command_services 1
' _ "$SERVICE_FUNCTION" "$SERVICE_TRACE" 2>&1)"
SERVICE_DEADLINE_RC=$?
set -e
[ "$SERVICE_DEADLINE_RC" -eq 75 ] \
  || fail 'deadline reached before service observation did not defer to final verification'
[ "$(wc -l <"$SERVICE_TRACE")" -eq 0 ] \
  || fail 'service check began a graph query at the finite-window deadline'
! grep -Fq 'workstation rosapi topics_for_type service is not visible from the Pi' \
  <<<"$SERVICE_DEADLINE_OUTPUT" \
  || fail 'finite-window deadline was misreported as rosapi loss'

: >"$SERVICE_TRACE"
set +e
SERVICE_QUERY_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  ros2_graph_query_before() {
    shift
    printf "query\n" >>"$TRACE"
    return 75
  }
  sleep() { printf "retry-sleep=%s\n" "$1"; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  reject_command_services 1
' _ "$SERVICE_FUNCTION" "$SERVICE_TRACE" 2>&1)"
SERVICE_QUERY_DEADLINE_RC=$?
set -e
[ "$SERVICE_QUERY_DEADLINE_RC" -eq 75 ] \
  || fail 'service query reaching the deadline did not defer to final verification'
[ "$(wc -l <"$SERVICE_TRACE")" -eq 1 ] \
  || fail 'service query reaching the deadline did not stop after one observation'
! grep -Fq 'retry-sleep=' <<<"$SERVICE_QUERY_DEADLINE_OUTPUT" \
  || fail 'service query reaching the deadline performed an unnecessary retry sleep'

: >"$SERVICE_TRACE"
set +e
FORBIDDEN_SERVICE_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  SECONDS=0
  ros2_graph_query_before() {
    shift
    printf "query\n" >>"$TRACE"
    printf "/planning/emergency_stop\n"
  }
  sleep() { SECONDS=$((SECONDS + $1)); }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  reject_command_services 0
' _ "$SERVICE_FUNCTION" "$SERVICE_TRACE" 2>&1)"
FORBIDDEN_SERVICE_RC=$?
set -e
[ "$FORBIDDEN_SERVICE_RC" -eq 17 ] \
  || fail 'forbidden command service was accepted'
[ "$(wc -l <"$SERVICE_TRACE")" -eq 1 ] \
  || fail 'forbidden command service was not rejected on its first snapshot'
grep -Fq 'dashboard command service server detected' <<<"$FORBIDDEN_SERVICE_OUTPUT" \
  || fail 'forbidden service was hidden by the rosapi completeness check'

require_literal 'monitor_live_stack() {'
MONITOR_FUNCTION="$(extract_function monitor_live_stack)"
set +e
MONITOR_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  set -u
  log() { :; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  require_group_alive() { :; }
  check_temperature() { :; }
  graph_nodes() { printf "nodes\n"; }
  reject_forbidden_nodes() { :; }
  require_workstation_nodes() { :; }
  reject_command_services() { return 75; }
  reject_unexpected_command_subscribers() { :; }
  require_owned_hailo_stream() { :; }
  require_mavros_source() { :; }
  require_connected_observation_state() { :; }
  check_power() { :; }
  sleep() { printf "UNEXPECTED_SLEEP\n"; exit 99; }
  SECONDS=0
  POLL_S=1
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
  monitor_live_stack live-window 10
  printf "MONITOR_DEADLINE=HANDOFF\n"
' _ "$MONITOR_FUNCTION" 2>&1)"
MONITOR_DEADLINE_RC=$?
set -e
[ "$MONITOR_DEADLINE_RC" -eq 0 ] \
  || fail 'monitor did not hand deadline-limited service discovery to final verification'
grep -Fxq 'MONITOR_DEADLINE=HANDOFF' <<<"$MONITOR_DEADLINE_OUTPUT" \
  || fail 'monitor omitted its deadline handoff marker'
! grep -Fq 'UNEXPECTED_SLEEP' <<<"$MONITOR_DEADLINE_OUTPUT" \
  || fail 'monitor slept after the service check reached its finite deadline'

COMMAND_SUBSCRIBER_FUNCTION="$(extract_function reject_unexpected_command_subscribers)"
[ -n "$COMMAND_SUBSCRIBER_FUNCTION" ] \
  || fail 'command-subscriber function was not extractable'
: >"$GRAPH_TRACE"
set +e
PHASE_ONE_DEADLINE_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  set -u
  TRACE="$3"
  log() { :; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  require_group_alive() { :; }
  check_temperature() { :; }
  graph_nodes() { printf "nodes\n"; }
  reject_forbidden_nodes() { :; }
  require_workstation_nodes() { :; }
  reject_command_services() { return 0; }
  ros2_graph_query_before() { printf "query\n" >>"$TRACE"; return 75; }
  require_owned_hailo_stream() { printf "UNEXPECTED_PHASE_TWO\n"; exit 98; }
  require_mavros_source() { printf "UNEXPECTED_PHASE_THREE\n"; exit 97; }
  require_connected_observation_state() { :; }
  check_power() { :; }
  sleep() { SECONDS=$((SECONDS + $1)); }
  SECONDS=0
  POLL_S=1
  COMMAND_TOPICS=(/planning/mission_command)
  SAFETY_MONITOR_PID=11
  THERMAL_WATCHDOG_PID=12
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
  monitor_live_stack live-window 10
  printf "PHASE_ONE_DEADLINE=HANDOFF\n"
' _ "$COMMAND_SUBSCRIBER_FUNCTION" "$MONITOR_FUNCTION" "$GRAPH_TRACE" 2>&1)"
PHASE_ONE_DEADLINE_RC=$?
set -e
[ "$PHASE_ONE_DEADLINE_RC" -eq 0 ] \
  || fail 'phase-one graph deadline did not hand off to final verification'
grep -Fxq 'PHASE_ONE_DEADLINE=HANDOFF' <<<"$PHASE_ONE_DEADLINE_OUTPUT" \
  || fail 'phase-one deadline omitted its final-verification handoff'
! grep -Eq 'UNEXPECTED_PHASE_(TWO|THREE)' <<<"$PHASE_ONE_DEADLINE_OUTPUT" \
  || fail 'monitor advanced after the phase-one graph deadline'
[ "$(wc -l <"$GRAPH_TRACE")" -eq 1 ] \
  || fail 'phase-one deadline was retried before final-verification handoff'

FINAL_GRAPH_FUNCTION="$(extract_function final_graph_verification)"
FINAL_RESULT_FUNCTION="$(extract_function require_final_check_result)"
[ -n "$FINAL_GRAPH_FUNCTION" ] || fail 'final graph-verification function was not extractable'
[ -n "$FINAL_RESULT_FUNCTION" ] || fail 'final result function was not extractable'
set +e
FINAL_EXHAUSTED_OUTPUT="$(bash -c '
  eval "$1"
  eval "$2"
  graph_nodes() { printf "nodes\n"; }
  reject_forbidden_nodes() { :; }
  require_workstation_nodes() { :; }
  reject_command_services() { :; }
  reject_unexpected_command_subscribers() { return 75; }
  require_owned_hailo_stream() { printf "UNEXPECTED_FINAL_PUBLISHER\n"; exit 96; }
  require_mavros_source() { printf "UNEXPECTED_FINAL_SOURCE\n"; exit 95; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  die() { printf "DIE: %s\n" "$*" >&2; exit 17; }
  FINAL_VERIFY_SECONDS=90
  result=0
  final_graph_verification 100 || result=$?
  require_final_check_result "$result" graph-contract "final graph verification failed"
' _ "$FINAL_GRAPH_FUNCTION" "$FINAL_RESULT_FUNCTION" 2>&1)"
FINAL_EXHAUSTED_RC=$?
set -e
[ "$FINAL_EXHAUSTED_RC" -eq 17 ] \
  || fail 'final graph deadline exhaustion did not fail closed'
grep -Fq 'final verification exceeded 90s during graph-contract' \
  <<<"$FINAL_EXHAUSTED_OUTPUT" \
  || fail 'final graph deadline exhaustion changed its fail-closed reason'
! grep -Eq 'UNEXPECTED_FINAL_(PUBLISHER|SOURCE)' <<<"$FINAL_EXHAUSTED_OUTPUT" \
  || fail 'final graph verification continued after deadline exhaustion'

: >"$GRAPH_TRACE"
FINAL_SUCCESS_OUTPUT="$(bash -c '
  eval "$1"
  TRACE="$2"
  graph_nodes() { printf "nodes:%s\n" "$1" >>"$TRACE"; printf "nodes\n"; }
  reject_forbidden_nodes() { printf "forbidden\n" >>"$TRACE"; }
  require_workstation_nodes() { printf "workstation\n" >>"$TRACE"; }
  reject_command_services() { printf "services:%s\n" "$1" >>"$TRACE"; }
  reject_unexpected_command_subscribers() { printf "subscribers:%s\n" "$1" >>"$TRACE"; }
  require_owned_hailo_stream() { printf "publisher:%s:%s\n" "$@" >>"$TRACE"; }
  require_mavros_source() { printf "source:%s:%s\n" "$@" >>"$TRACE"; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  IMAGE_TOPIC=/hailo/overlay/image_raw
  final_graph_verification 77
' _ "$FINAL_GRAPH_FUNCTION" "$GRAPH_TRACE")"
[ -z "$FINAL_SUCCESS_OUTPUT" ] \
  || fail "successful final graph verification emitted unexpected output: $FINAL_SUCCESS_OUTPUT"
EXPECTED_FINAL_TRACE="$(printf '%s\n' \
  'nodes:77' \
  'forbidden' \
  'workstation' \
  'services:77' \
  'subscribers:77' \
  'publisher:final-verification:77' \
  'source:/mavros/state:77' \
  'source:/mavros/global_position/raw/fix:77' \
  'source:/mavros/imu/data:77' \
  'source:/mavros/battery:77' \
  'source:/mavros/rc/in:77' \
  'source:/mavros/rc/out:77')"
[ "$(<"$GRAPH_TRACE")" = "$EXPECTED_FINAL_TRACE" ] \
  || fail 'final graph verification changed phase order or absolute deadline'
for contract in \
  'graph_nodes "$deadline"' \
  'reject_forbidden_nodes "$nodes"' \
  'require_workstation_nodes "$nodes" "$deadline"' \
  'reject_command_services "$deadline"' \
  'reject_unexpected_command_subscribers "$deadline"' \
  'require_owned_hailo_stream final-verification "$deadline"' \
  'require_mavros_source "$source_topic" "$deadline"' \
  'check_command_sentinel' \
  'check_thermal_watchdog'; do
  grep -Fq -- "$contract" <<<"$FINAL_GRAPH_FUNCTION" \
    || fail "final graph verification omits contract: $contract"
done
[ "$(grep -Fc 'require_workstation_nodes "$nodes" "$deadline"' "$HELPER")" -eq 2 ] \
  || fail 'deadline-limited workstation-node checks must cover final verification and hold monitoring'
for contract in \
  'check_command_sentinel' \
  'check_thermal_watchdog' \
  'require_group_alive mavproxy' \
  'require_group_alive mavros' \
  'require_group_alive hailo-bridge' \
  'check_temperature "$context"' \
  'graph_nodes "$deadline"' \
  'reject_forbidden_nodes' \
  'require_workstation_nodes' \
  'reject_command_services "$deadline"' \
  'reject_unexpected_command_subscribers "$deadline"' \
  'require_owned_hailo_stream "$context" "$deadline"' \
  'require_mavros_source "$source_topic" "$deadline"' \
  'require_connected_observation_state "$context" "$deadline"' \
  'check_power "$context"'; do
  grep -Fq -- "$contract" <<<"$MONITOR_FUNCTION" \
    || fail "hold monitor omits safety contract: $contract"
done

require_literal 'monitor_live_stack live-window "$DEADLINE"'
require_literal 'WINDOW_MONITOR_END_SECONDS=$SECONDS'
require_literal 'FINAL_VERIFY_DEADLINE=$((WINDOW_MONITOR_END_SECONDS + FINAL_VERIFY_SECONDS))'
require_literal 'final_graph_verification "$FINAL_VERIFY_DEADLINE"'
require_literal 'check_temperature final-verification'
require_literal 'check_power final-verification'
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
trap 'rm -f "$PASS_LOG" "$FAIL_LOG" "$ORDER_LOG" "$LATE_LOG" "$SERVICE_TRACE" "$GRAPH_TRACE" "$MONITOR_TRACE"' EXIT
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
  require_owned_hailo_stream() { trace "publisher:$1:$2"; }
  require_mavros_source() { trace "source:$1"; }
  require_connected_observation_state() { trace "state:$1"; }
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
  publisher:live-hold:0 \
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
require_trace_count 1 publisher:live-hold:0
require_trace_count 1 source:/mavros/state
require_trace_count 1 source:/mavros/global_position/raw/fix
require_trace_count 1 source:/mavros/imu/data
require_trace_count 1 source:/mavros/battery
require_trace_count 1 source:/mavros/rc/in
require_trace_count 1 source:/mavros/rc/out
require_trace_count 1 state:live-hold
require_trace_count 1 power:live-hold

# Four invocation groups read the same six MAVROS source topics: the two
# top-level pre-readiness groups, final_graph_verification, and monitor phase
# three. The guards below pin one canonical order for all four, the absence of a
# deadline argument in the two top-level groups, and their surrounding anchors.
MAVROS_SOURCE_TOPIC_ORDER="$(printf '%s\n' \
  /mavros/state \
  /mavros/global_position/raw/fix \
  /mavros/imu/data \
  /mavros/battery \
  /mavros/rc/in \
  /mavros/rc/out)"

extract_source_group() {
  awk '
    /for source_topic in \\$/ { capture = 1; next }
    capture {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]*\\$/, "", line)
      if (line ~ /; do$/) {
        sub(/; do$/, "", line)
        print line
        exit
      }
      print line
    }
  ' <<<"$1"
}

# Every line mentioning the consumer is pinned in order, complete except for
# leading whitespace, so a new call site, a renamed handler, an added prefix such
# as a wrapper command, or an indirect reference that spells the name changes
# this set. A call reached through a variable that never spells the name cannot
# be detected from the source text.
[ "$(grep -c '^require_mavros_source() {$' "$HELPER")" -eq 1 ] \
  || fail 'the MAVROS-source consumer no longer has exactly one definition'
[ "$(grep -F 'require_mavros_source' "$HELPER" | sed 's/^[[:space:]]*//')" = "$(printf '%s\n' \
  'require_mavros_source() {' \
  'require_mavros_source "$source_topic" "$deadline" || result=$?' \
  'require_mavros_source "$source_topic" "$deadline" || phase_rc=$?' \
  'require_mavros_source /mavros/state' \
  'require_mavros_source /mavros/global_position/raw/fix' \
  'require_mavros_source /mavros/imu/data' \
  'require_mavros_source /mavros/battery' \
  'require_mavros_source /mavros/rc/in' \
  'require_mavros_source /mavros/rc/out' \
  'require_mavros_source /mavros/state' \
  'require_mavros_source /mavros/global_position/raw/fix' \
  'require_mavros_source /mavros/imu/data' \
  'require_mavros_source /mavros/battery' \
  'require_mavros_source /mavros/rc/in' \
  'require_mavros_source /mavros/rc/out')" ] \
  || fail 'the MAVROS-source consumer gained, lost, or reshaped a reference'

mapfile -t PRE_READINESS_SOURCE_LINES < <(grep -n '^require_mavros_source ' "$HELPER" | cut -d: -f1)
[ "${#PRE_READINESS_SOURCE_LINES[@]}" -eq 12 ] \
  || fail "expected two six-topic pre-readiness groups, found ${#PRE_READINESS_SOURCE_LINES[@]} top-level source checks"

for group_offset in 0 6; do
  GROUP_START="${PRE_READINESS_SOURCE_LINES[$group_offset]}"
  GROUP_END="${PRE_READINESS_SOURCE_LINES[$((group_offset + 5))]}"
  [ "$((GROUP_END - GROUP_START))" -eq 5 ] \
    || fail "the pre-readiness source group at line $GROUP_START is not six contiguous checks"
  GROUP_LINES="$(sed -n "${GROUP_START},${GROUP_END}p" "$HELPER")"
  [ "$(awk 'NF != 2 { unexpected++ } END { print unexpected + 0 }' <<<"$GROUP_LINES")" -eq 0 ] \
    || fail "the pre-readiness source group at line $GROUP_START no longer runs without a deadline argument"
  [ "$(awk '{ print $2 }' <<<"$GROUP_LINES")" = "$MAVROS_SOURCE_TOPIC_ORDER" ] \
    || fail "the pre-readiness source group at line $GROUP_START changed topic membership or order"
done

[ "$(sed -n "$((PRE_READINESS_SOURCE_LINES[5] + 1))p" "$HELPER")" \
  = "log 'MAVROS_TELEMETRY=PASS state,GPS,IMU,battery,RC-input,thrust-output sampled from one MAVROS publisher each'" ] \
  || fail 'the telemetry pre-readiness source group no longer precedes the telemetry pass marker'
[ "$(sed -n "$((PRE_READINESS_SOURCE_LINES[6] - 1))p" "$HELPER")" \
  = 'require_connected_disarmed_state pre-ready' ] \
  || fail 'the post-Hailo-readiness source group no longer follows the pre-ready connection check'

[ "$(extract_source_group "$FINAL_GRAPH_FUNCTION")" = "$MAVROS_SOURCE_TOPIC_ORDER" ] \
  || fail 'final graph verification changed its source topic membership or order'
[ "$(extract_source_group "$MONITOR_FUNCTION")" = "$MAVROS_SOURCE_TOPIC_ORDER" ] \
  || fail 'the hold monitor changed its source topic membership or order'

: >"$MONITOR_TRACE"
set +e
bash -c '
  eval "$1"
  set -euo pipefail
  TRACE="$2"
  log() { :; }
  die() { exit 17; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  require_group_alive() { :; }
  check_temperature() { :; }
  graph_nodes() { printf "nodes\n"; }
  reject_forbidden_nodes() { :; }
  require_workstation_nodes() { :; }
  reject_command_services() { :; }
  reject_unexpected_command_subscribers() { :; }
  require_owned_hailo_stream() { :; }
  require_mavros_source() { printf "source:%s:%s\n" "$1" "$2" >>"$TRACE"; }
  require_connected_observation_state() { :; }
  check_power() { :; }
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
  monitor_live_stack live-window 77
' _ "$MONITOR_FUNCTION" "$MONITOR_TRACE"
MONITOR_SOURCE_ORDER_RC=$?
set -e
[ "$MONITOR_SOURCE_ORDER_RC" -eq 23 ] \
  || fail "the monitor source-order harness exited $MONITOR_SOURCE_ORDER_RC instead of test stop 23"
EXPECTED_MONITOR_SOURCE_TRACE="$(printf 'source:%s:77\n' \
  /mavros/state \
  /mavros/global_position/raw/fix \
  /mavros/imu/data \
  /mavros/battery \
  /mavros/rc/in \
  /mavros/rc/out)"
[ "$(<"$MONITOR_TRACE")" = "$EXPECTED_MONITOR_SOURCE_TRACE" ] \
  || fail 'monitor phase three changed its source order or stopped forwarding the phase deadline'

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
  WINDOW_MONITOR_END_SECONDS=10
  HOLD_AFTER_WINDOW=1
  ARMED_OBSERVATION=0
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
  'PI_SOURCE_WINDOW=COMPLETE target=120s monitored=10s final_verification=0s elapsed=10s peak=50C' \
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

set +e
INVALID_FINAL_VERIFY_OUTPUT="$(LIVE_FINAL_VERIFY_SECONDS=0 "$HELPER" --preflight-only 2>&1)"
INVALID_FINAL_VERIFY_RC=$?
set -e
[ "$INVALID_FINAL_VERIFY_RC" -ne 0 ] || fail 'invalid final-verification deadline was accepted'
grep -Fq 'LIVE_FINAL_VERIFY_SECONDS must be a positive integer' \
  <<<"$INVALID_FINAL_VERIFY_OUTPUT" \
  || fail 'invalid final-verification deadline did not fail at validation'

set +e
INVALID_SOURCE_BATCH_OUTPUT="$(LIVE_MAVROS_SOURCE_BATCH=2 "$HELPER" --preflight-only 2>&1)"
INVALID_SOURCE_BATCH_RC=$?
set -e
[ "$INVALID_SOURCE_BATCH_RC" -ne 0 ] || fail 'invalid batched-source flag was accepted'
grep -Fq 'LIVE_MAVROS_SOURCE_BATCH must be 0 or 1' \
  <<<"$INVALID_SOURCE_BATCH_OUTPUT" \
  || fail 'invalid batched-source flag did not fail at validation'

set +e
INVALID_PROBE_BOUND_OUTPUT="$(LIVE_PROBE_MAX_SECONDS=0 "$HELPER" --preflight-only 2>&1)"
INVALID_PROBE_BOUND_RC=$?
set -e
[ "$INVALID_PROBE_BOUND_RC" -ne 0 ] || fail 'invalid probe hard bound was accepted'
grep -Fq 'LIVE_PROBE_MAX_SECONDS must be a positive integer' \
  <<<"$INVALID_PROBE_BOUND_OUTPUT" \
  || fail 'invalid probe hard bound did not fail at validation'

set +e
INVALID_PROBE_RESERVE_OUTPUT="$(LIVE_PROBE_STARTUP_RESERVE=x "$HELPER" --preflight-only 2>&1)"
INVALID_PROBE_RESERVE_RC=$?
set -e
[ "$INVALID_PROBE_RESERVE_RC" -ne 0 ] || fail 'invalid probe startup reserve was accepted'
grep -Fq 'LIVE_PROBE_STARTUP_RESERVE must be a positive integer' \
  <<<"$INVALID_PROBE_RESERVE_OUTPUT" \
  || fail 'invalid probe startup reserve did not fail at validation'

set +e
INVALID_PROBE_SPLIT_OUTPUT="$(LIVE_PROBE_MAX_SECONDS=3 LIVE_PROBE_STARTUP_RESERVE=3 \
  "$HELPER" --preflight-only 2>&1)"
INVALID_PROBE_SPLIT_RC=$?
set -e
[ "$INVALID_PROBE_SPLIT_RC" -ne 0 ] || fail 'a probe budget with no spin time was accepted'
grep -Fq 'LIVE_PROBE_MAX_SECONDS must exceed LIVE_PROBE_STARTUP_RESERVE' \
  <<<"$INVALID_PROBE_SPLIT_OUTPUT" \
  || fail 'a probe budget with no spin time did not fail at validation'

# ---------------------------------------------------------------------------
# Defect cases for the batched MAVROS source view.
#
# Each was written and observed failing on its own before the implementation
# existed. They now run unconditionally.
#
# Interface these cases pin:
#   mavros_source_view <deadline> <topic>
#     - with MAVROS_SOURCE_BATCH=0, delegates to ros2_graph_query_before with
#       the exact argument vector and forwards the complete raw CLI streams and
#       status unchanged
#     - with MAVROS_SOURCE_BATCH=1, prints exactly the synthesized
#       "Publisher count: <n>" line followed by the verbatim publisher endpoint
#       blocks for that topic, and nothing else; it does not reproduce the rest
#       of "ros2 topic info --verbose"
#     - returns 0 on a successful serve, 75 on parent-deadline exhaustion, and
#       1 fail closed
#   mavros_source_probe_program prints the probe program; it takes the topic
#     list as arguments and emits per-topic blocks introduced by "TOPIC: <topic>"
#   mavros_source_probe_selftest runs one bounded probe before the live window
#   the probe runs synchronously through "timeout --signal=KILL <bound>s ..."
#   PROBE_MAX_SECONDS is 6; the cache lives under $RUN_DIR
# ---------------------------------------------------------------------------
# Every source-view case below runs unconditionally. The temporary selector that
# allowed each case to be observed failing on its own has been removed; this
# wrapper only carries the case name for readability.
source_view_case() {
  return 0
}

SOURCE_VIEW_FUNCTION="$SOURCE_VIEW_PREAMBLE"
SOURCE_PROBE_PROGRAM="$(sed -n '/^cat >"\$MAVROS_SOURCE_PROBE" <<.PYTHON_SOURCE_PROBE.$/,/^PYTHON_SOURCE_PROBE$/p' "$HELPER" | sed '1d;$d')"
SOURCE_SELFTEST_FUNCTION="$SOURCE_VIEW_PREAMBLE
$(extract_function mavros_source_probe_selftest)"
SOURCE_VIEW_TEST_DIR="$(mktemp -d)"
trap 'rm -f "$PASS_LOG" "$FAIL_LOG" "$ORDER_LOG" "$LATE_LOG" "$SERVICE_TRACE" "$GRAPH_TRACE" "$MONITOR_TRACE"; rm -rf "$SOURCE_VIEW_TEST_DIR"' EXIT

# Each case and each scenario within a case gets its own run directory, so no
# cache entry can leak from one into the next once they run unconditionally.
source_run_dir() {
  local dir="$SOURCE_VIEW_TEST_DIR/$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

# One publisher endpoint block, shaped like str(TopicEndpointInfo).
source_topic_payload() {
  local count="$1" gid="$2"
  printf 'Publisher count: %s\n' "$count"
  printf 'Node name: mavros\n'
  printf 'Node namespace: /\n'
  printf 'Topic type: mavros_msgs/msg/Probe\n'
  printf 'Topic type hash: RIHS01_%s\n' "$gid"
  printf 'Endpoint type: PUBLISHER\n'
  printf 'GID: %s\n' "$gid"
  printf 'QoS profile:\n'
  printf '  Reliability: RELIABLE\n'
  printf '  History (Depth): KEEP_LAST (10)\n'
}

source_topic_block() {
  printf 'TOPIC: %s\n' "$1"
  shift
  source_topic_payload "$@"
}

SOURCE_TOPIC_GIDS='/mavros/state:01.01
/mavros/global_position/raw/fix:02.02
/mavros/imu/data:03.03
/mavros/battery:04.04
/mavros/rc/in:05.05
/mavros/rc/out:06.06'

source_gid_for() {
  awk -F: -v topic="$1" '$1 == topic { print $2 }' <<<"$SOURCE_TOPIC_GIDS"
}

# A complete generation: all six topics, each with its own identity.
source_complete_stream() {
  local override_topic="${1:-}" override_count="${2:-}" entry topic gid count
  while IFS=: read -r topic gid; do
    count=1
    [ "$topic" != "$override_topic" ] || count="$override_count"
    source_topic_block "$topic" "$count" "$gid"
  done <<<"$SOURCE_TOPIC_GIDS"
}

SOURCE_PROBE_STREAM="$(source_complete_stream)"

# Complete-looking but structurally invalid: every topic present, every block
# claiming one publisher, none carrying an endpoint record.
SOURCE_MALFORMED_STREAM="$(while IFS=: read -r malformed_topic malformed_gid; do
  printf 'TOPIC: %s\n' "$malformed_topic"
  printf 'Publisher count: 1\n'
  printf 'not an endpoint record\n'
done <<<"$SOURCE_TOPIC_GIDS")"

if source_view_case flag-off-delegation; then
  # The disabled path hands over the exact argument vector and returns the
  # query's own status, with both streams preserved as raw bytes.
  DELEGATION_DIR="$(source_run_dir flag-off-delegation)"
  printf 'Type: mavros_msgs/msg/State\nPublisher count: 0\n  Reliability: RELIABLE\n' \
    >"$DELEGATION_DIR/expected_stdout"
  printf 'DELEGATED_STDERR\n' >"$DELEGATION_DIR/expected_stderr"
  set +e
  bash -c '
    eval "$1"
    TRACE="$2"
    BODY="$3"
    ros2_graph_query_before() {
      printf "argc:%s\n" "$#" >>"$TRACE"
      printf "argv:%s\n" "$@" >>"$TRACE"
      printf "DELEGATED_STDERR\n" >&2
      cat "$BODY"
      return 42
    }
    MAVROS_SOURCE_BATCH=0
    mavros_source_view 0 /mavros/state
  ' _ "$SOURCE_VIEW_FUNCTION" "$DELEGATION_DIR/argv" "$DELEGATION_DIR/expected_stdout" \
    >"$DELEGATION_DIR/stdout" 2>"$DELEGATION_DIR/stderr"
  DELEGATION_RC=$?
  set -e
  [ "$DELEGATION_RC" -eq 42 ] \
    || fail "flag-off delegation returned $DELEGATION_RC instead of the query status 42"
  [ "$(<"$DELEGATION_DIR/argv")" = "$(printf '%s\n' \
    'argc:8' 'argv:0' 'argv:topic' 'argv:info' 'argv:--verbose' \
    'argv:--no-daemon' 'argv:--spin-time' 'argv:2' 'argv:/mavros/state')" ] \
    || fail 'flag-off delegation changed the argument vector or its boundaries'
  cmp -s "$DELEGATION_DIR/stdout" "$DELEGATION_DIR/expected_stdout" \
    || fail 'flag-off delegation did not forward standard output as raw bytes'
  cmp -s "$DELEGATION_DIR/stderr" "$DELEGATION_DIR/expected_stderr" \
    || fail 'flag-off delegation did not keep standard error separate and unmodified'
fi

if source_view_case enabled-payload-routing; then
  # Every topic is served its own block, exactly: one count line, the verbatim
  # publisher endpoint block including identity, type, hash, GID and QoS, no
  # stream header, and nothing borrowed from another topic.
  ROUTING_DIR="$(source_run_dir enabled-payload-routing)"
  while IFS=: read -r routing_topic routing_gid; do
    set +e
    ROUTING_OUTPUT="$(bash -c '
      eval "$1"
      STREAM="$2"
      RUN_DIR="$3"
      timeout() { printf "%s\n" "$STREAM"; return 0; }
      log_error() { :; }
      MAVROS_SOURCE_BATCH=1
      mavros_source_view 0 "$4"
    ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$ROUTING_DIR" "$routing_topic")"
    ROUTING_RC=$?
    set -e
    [ "$ROUTING_RC" -eq 0 ] \
      || fail "a successful serve of $routing_topic returned $ROUTING_RC instead of 0"
    [ "$ROUTING_OUTPUT" = "$(source_topic_payload 1 "$routing_gid")" ] \
      || fail "the batched view did not serve $routing_topic its own verbatim endpoint block"
    [ "$(grep -Fc 'Publisher count:' <<<"$ROUTING_OUTPUT")" -eq 1 ] \
      || fail "the batched view did not emit exactly one publisher-count line for $routing_topic"
    ! grep -Fq 'TOPIC:' <<<"$ROUTING_OUTPUT" \
      || fail "the batched view leaked a stream header into the $routing_topic payload"
  done <<<"$SOURCE_TOPIC_GIDS"
fi

if source_view_case discriminating-count-api; then
  # The count comes from count_publishers, not the endpoint-list length, so a
  # deliberate disagreement inside a complete generation must survive.
  COUNT_DIR="$(source_run_dir discriminating-count-api)"
  set +e
  COUNT_API_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    timeout() { printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state
  ' _ "$SOURCE_VIEW_FUNCTION" "$(source_complete_stream /mavros/state 3)" "$COUNT_DIR")"
  COUNT_API_RC=$?
  set -e
  [ "$COUNT_API_RC" -eq 0 ] \
    || fail "a successful serve returned $COUNT_API_RC instead of 0"
  grep -Fxq 'Publisher count: 3' <<<"$COUNT_API_OUTPUT" \
    || fail 'the batched view did not report the publisher count from count_publishers'
  [ "$(grep -Fc 'Endpoint type: PUBLISHER' <<<"$COUNT_API_OUTPUT")" -eq 1 ] \
    || fail 'the batched view did not report the endpoint list independently of the count'
fi

if source_view_case one-participant-six-topics; then
  # Six ordered topics are served from a single probe run.
  SHARED_DIR="$(source_run_dir one-participant-six-topics)"
  set +e
  SHARED_TOPIC_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    RUNS="$4"
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    for view_topic in \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out; do
      mavros_source_view 0 "$view_topic" >/dev/null
      printf "serve:%s:%s\n" "$view_topic" "$?"
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$SHARED_DIR" \
    "$SHARED_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$SHARED_DIR/runs")" -eq 1 ] \
    || fail 'six source topics did not share one probe run'
  for view_topic in \
    /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
    /mavros/battery /mavros/rc/in /mavros/rc/out; do
    grep -Fxq "serve:$view_topic:0" <<<"$SHARED_TOPIC_OUTPUT" \
      || fail "the batched view did not serve $view_topic successfully from the shared run"
  done
fi

if source_view_case consumed-entry-refresh; then
  # Each topic entry is consumed once, so a repeat read re-runs the probe and
  # still succeeds.
  REFRESH_DIR="$(source_run_dir consumed-entry-refresh)"
  set +e
  REFRESH_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    RUNS="$4"
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
    printf "first=%s\n" "$?"
    mavros_source_view 0 /mavros/state >/dev/null
    printf "second=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$REFRESH_DIR" \
    "$REFRESH_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$REFRESH_DIR/runs")" -eq 2 ] \
    || fail 'a consumed topic entry did not force a fresh probe run'
  grep -Fxq 'first=0' <<<"$REFRESH_OUTPUT" \
    || fail 'the first read of a consumed-entry case did not succeed'
  grep -Fxq 'second=0' <<<"$REFRESH_OUTPUT" \
    || fail 'the refreshed read of a consumed-entry case did not succeed'
fi

if source_view_case execution-bounds-clean-phase; then
  # One run serves a clean phase, and every serve succeeds.
  CLEAN_DIR="$(source_run_dir execution-bounds-clean-phase)"
  set +e
  CLEAN_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    RUNS="$4"
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    for view_topic in \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out; do
      mavros_source_view 0 "$view_topic" >/dev/null
      printf "serve:%s\n" "$?"
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$CLEAN_DIR" \
    "$CLEAN_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$CLEAN_DIR/runs")" -eq 1 ] \
    || fail 'a clean phase did not stay within one probe run'
  [ "$(grep -Fxc 'serve:0' <<<"$CLEAN_OUTPUT")" -eq 6 ] \
    || fail 'a clean phase did not report six successful serves'
fi

if source_view_case execution-bounds-problematic-topic; then
  # A single problematic topic costs three runs, one per consumed read.
  PROBLEM_DIR="$(source_run_dir execution-bounds-problematic-topic)"
  set +e
  PROBLEM_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    RUNS="$4"
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    for view_attempt in 1 2 3; do
      mavros_source_view 0 /mavros/imu/data >/dev/null
      printf "serve:%s\n" "$?"
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$PROBLEM_DIR" \
    "$PROBLEM_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$PROBLEM_DIR/runs")" -eq 3 ] \
    || fail 'one problematic topic did not cost exactly three probe runs'
  [ "$(grep -Fxc 'serve:0' <<<"$PROBLEM_OUTPUT")" -eq 3 ] \
    || fail 'a repeatedly read topic did not report three successful serves'
fi

if source_view_case execution-bounds-worst-case; then
  # The per-phase worst case is 1 + (2 * 6): the first read of each topic after
  # the first is served from the surviving generation, the next two re-run.
  WORST_DIR="$(source_run_dir execution-bounds-worst-case)"
  set +e
  WORST_OUTPUT="$(bash -c '
    eval "$1"
    STREAM="$2"
    RUN_DIR="$3"
    RUNS="$4"
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    for view_topic in \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out; do
      for view_attempt in 1 2 3; do
        mavros_source_view 0 "$view_topic" >/dev/null
        printf "serve:%s\n" "$?"
      done
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$SOURCE_PROBE_STREAM" "$WORST_DIR" \
    "$WORST_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$WORST_DIR/runs")" -eq 13 ] \
    || fail 'the per-phase worst case did not settle at 1 + (2 * 6) probe runs'
  [ "$(grep -Fxc 'serve:0' <<<"$WORST_OUTPUT")" -eq 18 ] \
    || fail 'the per-phase worst case did not report eighteen successful serves'
fi

if source_view_case finite-deadline-clamp; then
  # A finite parent deadline clamps the probe below the remaining budget and
  # keeps non-zero headroom for serialization and teardown.
  CLAMP_DIR="$(source_run_dir finite-deadline-clamp)"
  set +e
  CLAMP_RC_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    BOUNDS="$3"
    SECONDS=17
    timeout() { printf "bound:%s\n" "$*" >>"$BOUNDS"; return 124; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 20 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$CLAMP_DIR" "$CLAMP_DIR/bounds" 2>&1)"
  set -e
  CLAMP_BOUND="$(grep -o 'bound:--signal=KILL [0-9]\+s' "$CLAMP_DIR/bounds" \
    | head -1 | grep -o '[0-9]\+' || true)"
  [ -n "$CLAMP_BOUND" ] \
    || fail 'the batched probe did not record a clamped hard bound'
  [ "$CLAMP_BOUND" -lt 3 ] \
    || fail 'the batched probe did not clamp below the remaining parent budget'
  [ "$CLAMP_BOUND" -gt 0 ] \
    || fail 'the batched probe did not keep non-zero headroom'
  grep -Fxq 'view_returned=1' <<<"$CLAMP_RC_OUTPUT" \
    || fail 'a probe that hit its own clamped bound was not reported as a content failure'
  ! grep -Fxq 'view_returned=75' <<<"$CLAMP_RC_OUTPUT" \
    || fail 'a probe timeout inside the parent budget was misreported as deadline exhaustion'
fi

if source_view_case probe-timeout-crossing-deadline; then
  # A probe timeout that does consume the parent budget is deadline exhaustion.
  CROSS_DIR="$(source_run_dir probe-timeout-crossing-deadline)"
  set +e
  CROSS_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    SECONDS=10
    timeout() { SECONDS=40; return 124; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 30 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$CROSS_DIR" 2>&1)"
  set -e
  grep -Fxq 'view_returned=75' <<<"$CROSS_OUTPUT" \
    || fail 'a probe timeout that consumed the parent budget was not reported as 75'
fi

if source_view_case failed-view-leaves-no-cache; then
  # A view that returns non-zero must leave nothing a later phase could serve.
  RESIDUE_DIR="$(source_run_dir failed-view-leaves-no-cache)"
  set +e
  RESIDUE_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    RUNS="$4"
    SECONDS=10
    timeout() { printf "run\n" >>"$RUNS"; printf "%s\n" "$STREAM"; SECONDS=40; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 30 /mavros/state >/dev/null
    printf "first=%s\n" "$?"
    if [ -s "$RUN_DIR/source_view/pending" ]; then
      printf "residual=yes\n"
    else
      printf "residual=no\n"
    fi
    SECONDS=0
    mavros_source_view 300 /mavros/global_position/raw/fix >/dev/null
    printf "second=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$RESIDUE_DIR" "$SOURCE_PROBE_STREAM" \
    "$RESIDUE_DIR/runs" 2>&1)"
  set -e
  grep -Fxq 'first=75' <<<"$RESIDUE_OUTPUT" \
    || fail 'a generation that crossed the parent deadline was not reported as 75'
  grep -Fxq 'residual=no' <<<"$RESIDUE_OUTPUT" \
    || fail 'a deadline-exhausted view left a generation a later phase could serve'
  grep -Fxq 'second=0' <<<"$RESIDUE_OUTPUT" \
    || fail 'the next phase could not recover after the discarded generation'
  [ "$(grep -Fxc 'run' "$RESIDUE_DIR/runs")" -eq 2 ] \
    || fail 'the next phase served a discarded generation instead of probing again'
fi

if source_view_case probe-invocation-argv; then
  # The real probe argument vector: program path, settle budget, and the exact
  # six-topic list, compared as one ordered string.
  ARGV_DIR="$(source_run_dir probe-invocation-argv)"
  set +e
  bash -c '
    eval "$1"
    RUN_DIR="$2"
    ARGV="$3"
    timeout() { printf "%s\n" "$*" >>"$ARGV"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
  ' _ "$SOURCE_VIEW_FUNCTION" "$ARGV_DIR" "$ARGV_DIR/argv" >/dev/null 2>&1
  set -e
  [ "$(cat "$ARGV_DIR/argv")" = "--signal=KILL 6s python3 $ARGV_DIR/mavros_source_probe.py 3 /mavros/state /mavros/global_position/raw/fix /mavros/imu/data /mavros/battery /mavros/rc/in /mavros/rc/out" ] \
    || fail "the probe invocation changed: $(cat "$ARGV_DIR/argv")"
fi

if source_view_case probe-budget-split; then
  # The outer bound is spent as startup reserve plus spin budget, so a slow host
  # loses discovery time instead of overrunning the bound. The reserve is
  # honoured under a clamped parent deadline too, down to a one-second floor.
  BUDGET_DIR="$(source_run_dir probe-budget-split)"
  set +e
  bash -c '
    eval "$1"
    RUN_DIR="$2"
    ARGV="$3"
    timeout() { printf "%s\n" "$*" >>"$ARGV"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
  ' _ "$SOURCE_VIEW_FUNCTION" "$BUDGET_DIR" "$BUDGET_DIR/argv" >/dev/null 2>&1
  set -e
  BUDGET_BOUND="$(awk '{print $2}' "$BUDGET_DIR/argv" | head -1 | tr -d 's')"
  BUDGET_SETTLE="$(awk '{print $5}' "$BUDGET_DIR/argv" | head -1)"
  BUDGET_RESERVE="$(sed -n 's/^PROBE_STARTUP_RESERVE="${LIVE_PROBE_STARTUP_RESERVE:-\([0-9]*\)}"$/\1/p' "$HELPER")"
  [ -n "$BUDGET_RESERVE" ] || fail 'the probe startup reserve default was not readable'
  [ "$BUDGET_SETTLE" -eq "$((BUDGET_BOUND - BUDGET_RESERVE))" ] \
    || fail "the probe spin budget is not the bound minus the startup reserve: $BUDGET_SETTLE"
  [ "$BUDGET_RESERVE" -ge 2 ] \
    || fail 'the probe startup reserve leaves too little for interpreter start and import'

  : >"$BUDGET_DIR/argv"
  set +e
  bash -c '
    eval "$1"
    RUN_DIR="$2"
    ARGV="$3"
    SECONDS=17
    timeout() { printf "%s\n" "$*" >>"$ARGV"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 20 /mavros/state >/dev/null
  ' _ "$SOURCE_VIEW_FUNCTION" "$BUDGET_DIR" "$BUDGET_DIR/argv" >/dev/null 2>&1
  set -e
  [ "$(awk '{print $5}' "$BUDGET_DIR/argv" | head -1)" -eq 1 ] \
    || fail 'a clamped probe budget did not fall back to the one-second spin floor'
fi

if source_view_case deadline-zero-hard-bound; then
  # Parent deadline zero keeps the probe's own finite hard bound.
  HARD_DIR="$(source_run_dir deadline-zero-hard-bound)"
  set +e
  bash -c '
    eval "$1"
    RUN_DIR="$2"
    BOUNDS="$3"
    SECONDS=900
    timeout() { printf "bound:%s\n" "$*" >>"$BOUNDS"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
  ' _ "$SOURCE_VIEW_FUNCTION" "$HARD_DIR" "$HARD_DIR/bounds" >/dev/null 2>&1
  set -e
  grep -Fq -- '--signal=KILL 6s ' "$HARD_DIR/bounds" \
    || fail 'a deadline-zero batched probe did not keep its own six-second hard bound'
fi

if source_view_case probe-status-three-maps-to-one; then
  # A raw probe status of 3 surfaces as a fail-closed 1, never as 75, and the
  # probe must actually have been invoked.
  STATUS_DIR="$(source_run_dir probe-status-three-maps-to-one)"
  set +e
  STATUS_THREE_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    RUNS="$3"
    timeout() { printf "run\n" >>"$RUNS"; return 3; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$STATUS_DIR" "$STATUS_DIR/runs" 2>&1)"
  set -e
  [ "$(grep -Fxc 'run' "$STATUS_DIR/runs")" -eq 1 ] \
    || fail 'the status-three case did not invoke the probe, so its result is vacuous'
  grep -Fxq 'view_returned=1' <<<"$STATUS_THREE_OUTPUT" \
    || fail 'a raw probe status of 3 did not map to view status 1'
  ! grep -Fxq 'view_returned=75' <<<"$STATUS_THREE_OUTPUT" \
    || fail 'a raw probe status of 3 was misreported as deadline exhaustion'
fi

if source_view_case pre-window-probe-selftest; then
  # The status-three mapping is covered before the window by a bounded
  # self-test that fails closed and is wired ahead of the live window.
  SELFTEST_DIR="$(source_run_dir pre-window-probe-selftest)"
  set +e
  SELFTEST_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    RUNS="$3"
    timeout() { printf "run\n" >>"$RUNS"; return 3; }
    log_error() { printf "LOG %s\n" "$*"; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_probe_selftest 0
    printf "selftest_returned=%s\n" "$?"
  ' _ "$SOURCE_SELFTEST_FUNCTION" "$SELFTEST_DIR" "$SELFTEST_DIR/runs" 2>&1)"
  set -e
  [ -n "$(extract_function mavros_source_probe_selftest)" ] \
    || fail 'the pre-window probe self-test does not exist'
  [ "$(grep -Fxc 'run' "$SELFTEST_DIR/runs")" -eq 1 ] \
    || fail 'the pre-window probe self-test did not run exactly one bounded probe'
  grep -Fxq 'selftest_returned=1' <<<"$SELFTEST_OUTPUT" \
    || fail 'the pre-window probe self-test did not fail closed on a status-three probe'
  grep -q '^mavros_source_probe_selftest ' \
    <<<"$(sed -n '/^monitor_live_stack live-window/q;p' "$HELPER")" \
    || fail 'the probe self-test is not called before the live window'

  # A successful self-test must not leave a pre-window generation behind, or the
  # first in-window source check would serve a snapshot taken before the window.
  SELFTEST_CLEAN_DIR="$(source_run_dir pre-window-probe-selftest-clean)"
  set +e
  SELFTEST_CLEAN_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    timeout() { printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_probe_selftest 0
    printf "selftest_returned=%s\n" "$?"
    if [ -s "$RUN_DIR/source_view/pending" ]; then
      printf "residual=yes\n"
    else
      printf "residual=no\n"
    fi
  ' _ "$SOURCE_SELFTEST_FUNCTION" "$SELFTEST_CLEAN_DIR" "$SOURCE_PROBE_STREAM" 2>&1)"
  set -e
  grep -Fxq 'selftest_returned=0' <<<"$SELFTEST_CLEAN_OUTPUT" \
    || fail 'a successful probe self-test did not report success'
  grep -Fxq 'residual=no' <<<"$SELFTEST_CLEAN_OUTPUT" \
    || fail 'the probe self-test left a pre-window generation that a later check could serve'
fi

for probe_failure_mode in crash exception timeout malformed partial; do
  if source_view_case "atomic-publication-$probe_failure_mode"; then
    # No failure mode may publish cache state that a later read can consume.
    # "partial" is a complete-looking stream missing one topic, which is why
    # every success fixture above uses a complete six-topic generation.
    ATOMIC_DIR="$(source_run_dir "atomic-publication-$probe_failure_mode")"
    set +e
    ATOMIC_OUTPUT="$(bash -c '
      eval "$1"
      RUN_DIR="$2"
      RUNS="$3"
      MODE="$4"
      PARTIAL="$5"
      MALFORMED="$6"
      timeout() {
        printf "run\n" >>"$RUNS"
        case "$MODE" in
          crash) return 137 ;;
          exception) printf "Traceback (most recent call last):\n"; return 1 ;;
          timeout) return 124 ;;
          malformed) printf "%s\n" "$MALFORMED"; return 0 ;;
          partial) printf "%s\n" "$PARTIAL"; return 0 ;;
        esac
      }
      log_error() { :; }
      MAVROS_SOURCE_BATCH=1
      mavros_source_view 0 /mavros/state >/dev/null
      printf "first=%s\n" "$?"
      mavros_source_view 0 /mavros/state >/dev/null
      printf "second=%s\n" "$?"
    ' _ "$SOURCE_VIEW_FUNCTION" "$ATOMIC_DIR" "$ATOMIC_DIR/runs" \
      "$probe_failure_mode" \
      "$(source_topic_block /mavros/state 1 01.01
         source_topic_block /mavros/imu/data 1 03.03)" \
      "$SOURCE_MALFORMED_STREAM" 2>&1)"
    set -e
    grep -Fxq 'first=1' <<<"$ATOMIC_OUTPUT" \
      || fail "the $probe_failure_mode probe-failure mode did not fail closed"
    grep -Fxq 'second=1' <<<"$ATOMIC_OUTPUT" \
      || fail "the $probe_failure_mode probe-failure mode served a later read from failed state"
    [ "$(grep -Fxc 'run' "$ATOMIC_DIR/runs")" -eq 2 ] \
      || fail "the $probe_failure_mode probe-failure mode published consumable cache state"
  fi
done

if source_view_case publication-failure-fails-closed; then
  # A failed atomic publication is reported, never logged as a successful run.
  PUBLISH_DIR="$(source_run_dir publication-failure-fails-closed)"
  set +e
  PUBLISH_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    timeout() { printf "%s\n" "$STREAM"; return 0; }
    mv() { return 1; }
    log_error() { printf "LOG %s\n" "$*" >&2; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$PUBLISH_DIR" "$SOURCE_PROBE_STREAM" 2>&1)"
  set -e
  grep -Fxq 'view_returned=1' <<<"$PUBLISH_OUTPUT" \
    || fail 'a failed atomic publication did not fail closed'
  ! grep -Fq 'MAVROS_SOURCE_PROBE_RUN result=OK' <<<"$PUBLISH_OUTPUT" \
    || fail 'a failed atomic publication was logged as a successful run'
fi

if source_view_case probe-stderr-not-cached; then
  # Probe standard error never becomes part of a cached payload.
  STDERR_DIR="$(source_run_dir probe-stderr-not-cached)"
  set +e
  STDERR_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    timeout() {
      printf "%s\n" "$STREAM"
      printf "PROBE_STDERR_NOISE\n" >&2
      return 0
    }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    for view_topic in \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out; do
      mavros_source_view 0 "$view_topic"
      printf "serve:%s\n" "$?"
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$STDERR_DIR" "$SOURCE_PROBE_STREAM" 2>/dev/null)"
  set -e
  [ "$(grep -Fxc 'serve:0' <<<"$STDERR_OUTPUT")" -eq 6 ] \
    || fail 'the probe-stderr case did not serve all six topics, so its result is vacuous'
  ! grep -Fq 'PROBE_STDERR_NOISE' <<<"$STDERR_OUTPUT" \
    || fail 'probe standard error was mixed into a cached payload'
fi

if source_view_case synchronous-no-managed-child; then
  # The probe is synchronous and never becomes a managed child.
  OWNERSHIP_DIR="$(source_run_dir synchronous-no-managed-child)"
  set +e
  OWNERSHIP_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    declare -a CHILD_NAMES=()
    declare -a CHILD_PIDS=()
    declare -a CHILD_PGIDS=()
    start_child() { printf "UNEXPECTED_START_CHILD\n"; }
    timeout() { printf "%s\n" "$STREAM"; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
    printf "serve=%s\n" "$?"
    printf "children=%s:%s:%s\n" \
      "${#CHILD_NAMES[@]}" "${#CHILD_PIDS[@]}" "${#CHILD_PGIDS[@]}"
  ' _ "$SOURCE_VIEW_FUNCTION" "$OWNERSHIP_DIR" "$SOURCE_PROBE_STREAM" 2>&1)"
  set -e
  grep -Fxq 'serve=0' <<<"$OWNERSHIP_OUTPUT" \
    || fail 'the ownership case did not serve the topic, so its result is vacuous'
  ! grep -Fq 'UNEXPECTED_START_CHILD' <<<"$OWNERSHIP_OUTPUT" \
    || fail 'the batched probe registered a managed child'
  grep -Fxq 'children=0:0:0' <<<"$OWNERSHIP_OUTPUT" \
    || fail 'the batched probe changed the managed-child arrays'
  ! grep -Fq 'start_child' <<<"$SOURCE_VIEW_FUNCTION" \
    || fail 'the batched view references start_child'
fi

if source_view_case success-summary; then
  # A complete run records one summary and no per-topic raw noise.
  SUMMARY_DIR="$(source_run_dir success-summary)"
  set +e
  SUMMARY_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    timeout() { printf "%s\n" "$STREAM"; return 0; }
    log_error() { printf "LOG %s\n" "$*" >&2; }
    MAVROS_SOURCE_BATCH=1
    for view_topic in \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out; do
      mavros_source_view 0 "$view_topic" >/dev/null
      printf "serve:%s\n" "$?"
    done
  ' _ "$SOURCE_VIEW_FUNCTION" "$SUMMARY_DIR" "$SOURCE_PROBE_STREAM" 2>&1)"
  set -e
  [ "$(grep -Fxc 'serve:0' <<<"$SUMMARY_OUTPUT")" -eq 6 ] \
    || fail 'the success-summary case did not serve all six topics'
  [ "$(grep -Fc 'LOG MAVROS_SOURCE_PROBE_RUN' <<<"$SUMMARY_OUTPUT")" -eq 1 ] \
    || fail 'a complete probe run did not record exactly one summary'
  ! grep -Fq 'raw: ' <<<"$SUMMARY_OUTPUT" \
    || fail 'a complete probe run emitted per-topic raw diagnostics'
fi

if source_view_case failure-summary-diagnostics; then
  # An incomplete run keeps its raw diagnostics.
  FAILURE_DIR="$(source_run_dir failure-summary-diagnostics)"
  set +e
  FAILURE_SUMMARY_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    timeout() { printf "TOPIC: /mavros/state\nnot an endpoint record\n"; return 0; }
    log_error() { printf "LOG %s\n" "$*" >&2; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 0 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$FAILURE_DIR" 2>&1)"
  set -e
  grep -Fxq 'view_returned=1' <<<"$FAILURE_SUMMARY_OUTPUT" \
    || fail 'an incomplete probe run did not fail closed'
  grep -Fq 'LOG MAVROS_SOURCE_PROBE_RUN' <<<"$FAILURE_SUMMARY_OUTPUT" \
    || fail 'an incomplete probe run did not record its summary'
  grep -Fq 'raw: not an endpoint record' <<<"$FAILURE_SUMMARY_OUTPUT" \
    || fail 'an incomplete probe run discarded its raw diagnostics'
fi

source_write_fake_rclpy() {
  mkdir -p "$1/fake/rclpy"
  cat >"$1/fake/rclpy/__init__.py" <<'FAKE_RCLPY'
import os

TRACE = os.environ['PROBE_TRACE']
SETTLE_AFTER = int(os.environ.get('PROBE_SETTLE_AFTER', '0'))
_STATE = {'spins': 0}


def _record(event):
    with open(TRACE, 'a') as handle:
        handle.write(event + '\n')


class _Endpoint:
    def __init__(self, topic):
        self.topic = topic

    def __str__(self):
        return '\n'.join([
            'Node name: mavros',
            'Node namespace: /',
            'Topic type: mavros_msgs/msg/Probe',
            'Topic type hash: RIHS01_%s' % self.topic,
            'Endpoint type: PUBLISHER',
            'GID: gid%s' % self.topic,
            'QoS profile:',
            '  Reliability: RELIABLE',
        ])


class Node:
    def __init__(self, name, *args, **kwargs):
        _record('node:' + name)

    def _discovered(self):
        return _STATE['spins'] > SETTLE_AFTER

    def count_publishers(self, topic):
        _record('count_publishers:' + topic)
        return 3 if self._discovered() else 0

    def get_publishers_info_by_topic(self, topic):
        _record('get_publishers_info_by_topic:' + topic)
        return [_Endpoint(topic)] if self._discovered() else []

    def destroy_node(self):
        _record('destroy_node')


def init(*args, **kwargs):
    _record('init')


def shutdown(*args, **kwargs):
    _record('shutdown')


def create_node(name, *args, **kwargs):
    return Node(name, *args, **kwargs)


def spin_once(node, timeout_sec=None):
    _STATE['spins'] += 1
    _record('spin_once')
FAKE_RCLPY
  cat >"$1/fake/rclpy/node.py" <<'FAKE_RCLPY_NODE'
from rclpy import Node

__all__ = ['Node']
FAKE_RCLPY_NODE
}

if source_view_case producer-single-participant; then
  # Producer-level coverage: the materialized program is run against a fake
  # rclpy so the accumulated-discovery spin, the two distinct API calls, the
  # single participant, the topic order, and the endpoint serialization are all
  # observable rather than inferred from an already-synthesized stream.
  PRODUCER_DIR="$(source_run_dir producer-single-participant)"
  source_write_fake_rclpy "$PRODUCER_DIR"
  [ -n "$SOURCE_PROBE_PROGRAM" ] \
    || fail 'the materialized probe program was not extractable'
  printf '%s\n' "$SOURCE_PROBE_PROGRAM" >"$PRODUCER_DIR/probe.py"
  set +e
  PRODUCER_OUTPUT="$(PROBE_TRACE="$PRODUCER_DIR/trace" \
    PYTHONPATH="$PRODUCER_DIR/fake" \
    python3 "$PRODUCER_DIR/probe.py" 2 \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out 2>&1)"
  PRODUCER_RC=$?
  set -e
  [ "$PRODUCER_RC" -eq 0 ] \
    || fail "the materialized probe program exited $PRODUCER_RC against a fake rclpy"
  [ "$(grep -Fxc 'node:_live_dashboard_graph_probe' "$PRODUCER_DIR/trace")" -eq 1 ] \
    || fail 'the probe program did not create exactly one hidden participant'
  [ "$(grep -Fc 'node:' "$PRODUCER_DIR/trace")" -eq 1 ] \
    || fail 'the probe program created more than one participant'
  [ "$(grep -Fxc 'spin_once' "$PRODUCER_DIR/trace")" -ge 1 ] \
    || fail 'the probe program never spun its participant before reading endpoints'
  [ "$(head -1 "$PRODUCER_DIR/trace")" = 'init' ] \
    || fail 'the probe program did not initialise before creating its participant'
  [ "$(tail -1 "$PRODUCER_DIR/trace")" = 'shutdown' ] \
    || fail 'the probe program did not shut down its participant'
  [ "$(grep -Fc 'count_publishers:' "$PRODUCER_DIR/trace")" -ge 6 ] \
    || fail 'the probe program did not call count_publishers per topic'
  [ "$(grep -Fc 'get_publishers_info_by_topic:' "$PRODUCER_DIR/trace")" -ge 6 ] \
    || fail 'the probe program did not look up endpoints separately per topic'
  EXPECTED_PRODUCER_OUTPUT="$(for producer_topic in \
    /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
    /mavros/battery /mavros/rc/in /mavros/rc/out; do
    printf 'TOPIC: %s\n' "$producer_topic"
    printf 'Publisher count: 3\n'
    printf 'Node name: mavros\n'
    printf 'Node namespace: /\n'
    printf 'Topic type: mavros_msgs/msg/Probe\n'
    printf 'Topic type hash: RIHS01_%s\n' "$producer_topic"
    printf 'Endpoint type: PUBLISHER\n'
    printf 'GID: gid%s\n' "$producer_topic"
    printf 'QoS profile:\n'
    printf '  Reliability: RELIABLE\n'
  done)"
  [ "$PRODUCER_OUTPUT" = "$EXPECTED_PRODUCER_OUTPUT" ] \
    || fail 'the probe program changed its topic order or endpoint serialization'
fi

if source_view_case producer-accumulated-discovery; then
  # Discovery is accumulated: the program keeps spinning while the graph reports
  # nothing and only emits once every topic has a publisher.
  DISCOVERY_DIR="$(source_run_dir producer-accumulated-discovery)"
  source_write_fake_rclpy "$DISCOVERY_DIR"
  printf '%s\n' "$SOURCE_PROBE_PROGRAM" >"$DISCOVERY_DIR/probe.py"
  set +e
  DISCOVERY_OUTPUT="$(PROBE_TRACE="$DISCOVERY_DIR/trace" \
    PROBE_SETTLE_AFTER=3 \
    PYTHONPATH="$DISCOVERY_DIR/fake" \
    python3 "$DISCOVERY_DIR/probe.py" 5 \
      /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
      /mavros/battery /mavros/rc/in /mavros/rc/out 2>&1)"
  DISCOVERY_RC=$?
  set -e
  [ "$DISCOVERY_RC" -eq 0 ] \
    || fail "the accumulated-discovery probe exited $DISCOVERY_RC"
  [ "$(grep -Fxc 'spin_once' "$DISCOVERY_DIR/trace")" -ge 4 ] \
    || fail 'the probe program stopped spinning before the graph settled'
  [ "$(grep -Fc 'Publisher count: 3' <<<"$DISCOVERY_OUTPUT")" -eq 6 ] \
    || fail 'the probe program emitted a pre-discovery reading instead of the settled graph'
  ! grep -Fq 'Publisher count: 0' <<<"$DISCOVERY_OUTPUT" \
    || fail 'the probe program published a zero-publisher reading after settling'
fi

if source_view_case late-deadline-crossing; then
  # A fresh probe that succeeds but consumes the parent budget is reported as
  # deadline exhaustion, not as a late success.
  LATE_DIR="$(source_run_dir late-deadline-crossing)"
  set +e
  LATE_OUTPUT="$(bash -c '
    eval "$1"
    RUN_DIR="$2"
    STREAM="$3"
    SECONDS=10
    timeout() { printf "%s\n" "$STREAM"; SECONDS=40; return 0; }
    log_error() { :; }
    MAVROS_SOURCE_BATCH=1
    mavros_source_view 30 /mavros/state >/dev/null
    printf "view_returned=%s\n" "$?"
  ' _ "$SOURCE_VIEW_FUNCTION" "$LATE_DIR" "$SOURCE_PROBE_STREAM" 2>&1)"
  set -e
  grep -Fxq 'view_returned=75' <<<"$LATE_OUTPUT" \
    || fail 'a probe that consumed the parent budget was reported as a late success'
fi

OWNED_HAILO_FUNCTION="$(extract_function require_owned_hailo_stream)"
[ -n "$OWNED_HAILO_FUNCTION" ] \
  || fail 'owned Hailo stream verifier is missing'

HAILO_RECOVERY_DIR="$(mktemp -d)"
trap 'rm -rf "$HAILO_RECOVERY_DIR"' EXIT
set +e
HAILO_ZERO_OUTPUT="$(bash -c '
  eval "$1"
  IMAGE_TOPIC=/hailo/overlay/image_raw
  IMAGE_RECOVERY_SAMPLE="$2/recovery.yaml"
  STREAM_HEIGHT=240
  HAILO_PID=100
  HAILO_PGID=100
  HAILO_LOG="$2/hailo.log"
  SECONDS=10
  topic_publishers() { printf "0\n"; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  require_group_alive() { :; }
  bounded_topic_echo() {
    printf "encoding: bgr8\nheight: 240\n"
  }
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*"; exit 90; }
  require_owned_hailo_stream final-verification 100
' _ "$OWNED_HAILO_FUNCTION" "$HAILO_RECOVERY_DIR" 2>&1)"
HAILO_ZERO_RC=$?
HAILO_DUPLICATE_OUTPUT="$(bash -c '
  eval "$1"
  IMAGE_TOPIC=/hailo/overlay/image_raw
  IMAGE_RECOVERY_SAMPLE="$2/duplicate.yaml"
  STREAM_HEIGHT=240
  HAILO_PID=100
  HAILO_PGID=100
  HAILO_LOG="$2/hailo.log"
  SECONDS=10
  topic_publishers() { printf "2\n"; }
  check_command_sentinel() { :; }
  check_thermal_watchdog() { :; }
  require_group_alive() { :; }
  bounded_topic_echo() { printf "encoding: bgr8\nheight: 240\n"; }
  log() { printf "%s\n" "$*"; }
  die() { printf "DIE: %s\n" "$*"; exit 91; }
  require_owned_hailo_stream live-window 100
' _ "$OWNED_HAILO_FUNCTION" "$HAILO_RECOVERY_DIR" 2>&1)"
HAILO_DUPLICATE_RC=$?
set -e
[ "$HAILO_ZERO_RC" -eq 0 ] \
  || fail "fresh owned Hailo stream did not recover graph zero: $HAILO_ZERO_OUTPUT"
grep -Fq 'HAILO_GRAPH_ZERO_RECOVERY=PASS' <<<"$HAILO_ZERO_OUTPUT" \
  || fail 'graph-zero recovery did not emit its evidence marker'
[ "$HAILO_DUPLICATE_RC" -eq 91 ] \
  || fail "duplicate Hailo publisher count was accepted: $HAILO_DUPLICATE_OUTPUT"
grep -Fq 'expected=1 found=2' <<<"$HAILO_DUPLICATE_OUTPUT" \
  || fail 'duplicate Hailo publisher failure did not retain its observed count'

printf 'PASS: Pi lifecycle, local-window, heartbeat, deadline, and monitored-hold contracts\n'
