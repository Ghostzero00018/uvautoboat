#!/usr/bin/env bash
# Tests for the single-entry-point workstation helper.
#
# The helper resolves its three children from its own directory, so each case
# runs a copy of it in a temporary directory beside stand-in children of the
# same names. Nothing here starts a simulator, a supervisor or a flight
# controller, and HOME is redirected so no run directory reaches the desktop.

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUPERVISOR="$TEST_DIR/real_fcu_full_stack_workstation.sh"
CASES=0

# Stand-in supervisors outlive a case whenever the helper could not stop them,
# which is exactly what a case asserting a broken stop is arranged to produce.
# Left alone they accumulate and would later trip a real supervisor's conflict
# guard, so every sandbox is swept before it is removed. The match is anchored
# on the sandbox path and cannot reach a supervisor in the repository.
sweep_sandbox() {
  local root="$1" pid sig
  for sig in TERM KILL; do
    local pids=''
    # pgrep exits non-zero when nothing matches, which under pipefail would
    # abort the whole suite through this assignment. Nothing to sweep is the
    # normal case, not an error.
    pids="$(pgrep -af -- 'workstation.sh' 2>/dev/null \
      | grep -F -- "$root" | awk '{print $1}')" || pids=''
    [ -n "$pids" ] || return 0
    for pid in $pids; do
      kill -"$sig" "$pid" 2>/dev/null || true
    done
    sleep 1
  done
}

discard_sandbox() {
  local root="$1"
  [ -n "$root" ] || return 0
  sweep_sandbox "$root"
  rm -rf "$root"
}

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  [ -n "${SANDBOX:-}" ] && discard_sandbox "$SANDBOX"
  exit 1
}

pass_case() {
  CASES=$((CASES + 1))
}

require_text() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*) return 0 ;;
  esac
  printf -- '--- output ---\n%s\n--- end ---\n' "$haystack" >&2
  fail_test "$message"
}

refute_text() {
  local haystack="$1" needle="$2" message="$3"
  case "$haystack" in
    *"$needle"*)
      printf -- '--- output ---\n%s\n--- end ---\n' "$haystack" >&2
      fail_test "$message"
      ;;
  esac
  return 0
}

# A sandbox holding a copy of the helper and stand-in children.
make_sandbox() {
  local root
  root="$(mktemp -d)"
  cp "$SUPERVISOR" "$root/real_fcu_full_stack_workstation.sh"
  chmod +x "$root/real_fcu_full_stack_workstation.sh"
  mkdir -p "$root/home"
  printf '%s' "$root"
}

# A stand-in supervisor: prints its marker after a delay, then waits. On
# SIGINT it appends its name to the shared order file, so a case can assert
# which supervisor was stopped first.
write_supervisor_stub() {
  local path="$1" marker="$2" name="$3" order_file="$4" delay="${5:-0}"
  cat >"$path" <<STUB
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "%s\n" "$name" >>"$order_file"; exit 0' INT TERM
sleep $delay
printf '%s\n' "$marker"
while true; do sleep 0.2; done
STUB
  chmod +x "$path"
}

write_dying_stub() {
  local path="$1"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
printf 'STOP: stand-in supervisor refused to start\n' >&2
exit 1
STUB
  chmod +x "$path"
}

# Dies only after its process group is readable, so the death is detected by
# the marker wait rather than by the start-up probe.
write_late_dying_stub() {
  local path="$1"
  cat >"$path" <<'STUB'
#!/usr/bin/env bash
sleep 3
printf 'STOP: stand-in supervisor lost its device mid-start\n' >&2
exit 1
STUB
  chmod +x "$path"
}

# A capture stand-in that keeps running, so a case can deliver an operator
# interrupt while it is still in the foreground.
write_long_capture_stub() {
  local path="$1" order_file="$2"
  cat >"$path" <<STUB
#!/usr/bin/env python3
import sys, time, pathlib
with open("$order_file", "a") as handle:
    handle.write("capture:" + " ".join(sys.argv[1:]) + "\n")
print("CAPTURE_STUB_RUNNING", flush=True)
time.sleep(600)
STUB
  chmod +x "$path"
}

write_capture_stub() {
  local path="$1" order_file="$2"
  cat >"$path" <<STUB
#!/usr/bin/env python3
import sys, pathlib
pathlib.Path("$order_file").write_text(
    pathlib.Path("$order_file").read_text() + "capture:" + " ".join(sys.argv[1:]) + "\n"
    if pathlib.Path("$order_file").exists() else "capture:" + " ".join(sys.argv[1:]) + "\n"
)
print("CAPTURE_STUB_STARTED", " ".join(sys.argv[1:]))
STUB
  chmod +x "$path"
}

# stdin comes from /dev/null so the closeout prompt in the helper's cleanup
# returns immediately instead of holding the case open. A real run has a
# terminal there and the prompt is the point.
run_helper() {
  local root="$1"
  shift
  ( cd "$root" && HOME="$root/home" timeout 120 bash \
      "$root/real_fcu_full_stack_workstation.sh" "$@" </dev/null 2>&1 )
}

# --- a bad argument is rejected -------------------------------------------
SANDBOX="$(make_sandbox)"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t9z)"
RC=$?
set -e
[ "$RC" -eq 2 ] || fail_test "an unknown mode should exit 2, got $RC"
require_text "$OUTPUT" 'usage:' 'an unknown mode does not print usage'
discard_sandbox "$SANDBOX"
pass_case

# --- no argument is rejected ----------------------------------------------
SANDBOX="$(make_sandbox)"
set +e
OUTPUT="$(run_helper "$SANDBOX")"
RC=$?
set -e
[ "$RC" -eq 2 ] || fail_test "a missing mode should exit 2, got $RC"
discard_sandbox "$SANDBOX"
pass_case

# --- a missing child helper stops the run before anything starts ----------
SANDBOX="$(make_sandbox)"
set +e
OUTPUT="$(run_helper "$SANDBOX" check)"
RC=$?
set -e
[ "$RC" -ne 0 ] || fail_test 'a missing child helper was accepted'
require_text "$OUTPUT" 'required helper missing' \
  'a missing child helper does not name itself'
discard_sandbox "$SANDBOX"
pass_case

# --- check delegates, and a failing child fails the check -----------------
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_dying_stub "$SANDBOX/fcu_to_vrx_workstation.sh"
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" 'x' 'w1' "$ORDER"
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
set +e
OUTPUT="$(run_helper "$SANDBOX" check)"
RC=$?
set -e
[ "$RC" -ne 0 ] || fail_test 'a failing VRX preflight was accepted'
require_text "$OUTPUT" 'VRX supervisor preflight failed' \
  'a failing VRX preflight is not attributed to the VRX supervisor'
refute_text "$OUTPUT" 'FULL_STACK_CHECK=PASS' \
  'a failing preflight still reported an overall pass'
discard_sandbox "$SANDBOX"
pass_case

# --- a supervisor that never starts is reported as such --------------------
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_dying_stub "$SANDBOX/fcu_to_vrx_workstation.sh"
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS' 'w1' "$ORDER"
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
STARTED="$SECONDS"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t3a)"
RC=$?
set -e
ELAPSED=$((SECONDS - STARTED))
[ "$RC" -ne 0 ] || fail_test 'a VRX supervisor that never started was accepted'
require_text "$OUTPUT" 'did not start' \
  'a supervisor that never started is not reported as such'
require_text "$OUTPUT" 'stand-in supervisor refused to start' \
  'the failed supervisor own output was not surfaced'
[ "$ELAPSED" -lt 60 ] \
  || fail_test "a failed start was not detected promptly (${ELAPSED}s)"
discard_sandbox "$SANDBOX"
pass_case

# --- a supervisor that dies during the marker wait is detected promptly ----
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_late_dying_stub "$SANDBOX/fcu_to_vrx_workstation.sh"
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS' 'w1' "$ORDER"
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
STARTED="$SECONDS"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t3a)"
RC=$?
set -e
ELAPSED=$((SECONDS - STARTED))
[ "$RC" -ne 0 ] || fail_test 'a VRX supervisor that died mid-start was accepted'
require_text "$OUTPUT" 'exited before reaching' \
  'a supervisor dying during the marker wait is not reported as exiting early'
require_text "$OUTPUT" 'lost its device mid-start' \
  'the dying supervisor own output was not surfaced'
[ "$ELAPSED" -lt 60 ] \
  || fail_test "a mid-start death was not detected promptly (${ELAPSED}s)"
discard_sandbox "$SANDBOX"
pass_case

# --- the full sequence, and the stop order ---------------------------------
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_supervisor_stub "$SANDBOX/fcu_to_vrx_workstation.sh" \
  'FCU_TO_VRX_WORKSTATION_PRESTART=PASS mode=run-real-fcu' 'w2' "$ORDER" 1
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS ports=8002,9090' 'w1' "$ORDER" 1
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t3a)"
RC=$?
set -e
require_text "$OUTPUT" 'started W2' 'the VRX supervisor was not started'
require_text "$OUTPUT" 'started W1' 'the real-FCU supervisor was not started'
require_text "$OUTPUT" 'W2 reached FCU_TO_VRX_WORKSTATION_PRESTART=PASS' \
  'the VRX prestart marker was not awaited'
require_text "$OUTPUT" 'W1 reached REAL_FCU_WORKSTATION_SERVICES=PASS' \
  'the real-FCU services marker was not awaited'
ORDER_TEXT="$(cat "$ORDER")"
require_text "$ORDER_TEXT" 'capture:t3a --esc-threshold-calibration' \
  't3a did not reach the capture node with ESC-threshold calibration'
if ! grep -qE '^w[12]$' "$ORDER"; then
  printf -- '--- order file ---\n%s\n--- end ---\n' "$(cat "$ORDER")" >&2
  fail_test 'neither supervisor recorded a stop'
fi
FIRST_STOPPED="$(grep -E '^w[12]$' "$ORDER" | head -1)"
[ "$FIRST_STOPPED" = 'w2' ] \
  || fail_test "the VRX supervisor must stop first, got '$FIRST_STOPPED'"
LAST_STOPPED="$(grep -E '^w[12]$' "$ORDER" | tail -1)"
[ "$LAST_STOPPED" = 'w1' ] \
  || fail_test "the real-FCU supervisor must stop last, got '$LAST_STOPPED'"
discard_sandbox "$SANDBOX"
pass_case

# --- the t2a tier does not request ESC-threshold calibration ---------------
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_supervisor_stub "$SANDBOX/fcu_to_vrx_workstation.sh" \
  'FCU_TO_VRX_WORKSTATION_PRESTART=PASS' 'w2' "$ORDER" 1
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS' 'w1' "$ORDER" 1
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t2a)"
set -e
require_text "$(cat "$ORDER")" 'capture:t2a' 't2a did not reach the capture node'
refute_text "$(cat "$ORDER")" 'capture:t2a --esc-threshold-calibration' \
  't2a wrongly requested ESC-threshold calibration'
discard_sandbox "$SANDBOX"
pass_case

# --- the advisory description is only shown when the detector is on --------
SANDBOX="$(make_sandbox)"
write_dying_stub "$SANDBOX/fcu_to_vrx_workstation.sh"
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" 'x' 'w1' "$SANDBOX/o"
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$SANDBOX/o"
set +e
OUTPUT="$(run_helper "$SANDBOX" check)"
set -e
require_text "$OUTPUT" 'detector not started' \
  'the default contract does not say the detector is off'
set +e
OUTPUT="$( cd "$SANDBOX" && HOME="$SANDBOX/home" \
  REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1 \
  timeout 60 bash "$SANDBOX/real_fcu_full_stack_workstation.sh" check </dev/null 2>&1 )"
set -e
require_text "$OUTPUT" 'advisory, warns on the dashboard without stopping' \
  'advisory mode is not described in the contract'
refute_text "$OUTPUT" 'a detection stops the stack' \
  'advisory mode was described as stopping the stack'
discard_sandbox "$SANDBOX"
pass_case

# --- an operator interrupt stops the stack in the documented order ---------
# Started under job control so the helper keeps a trappable SIGINT, which is
# what an operator's Ctrl+C delivers. A plain background job would inherit
# SIGINT ignored and this case would prove nothing.
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_supervisor_stub "$SANDBOX/fcu_to_vrx_workstation.sh" \
  'FCU_TO_VRX_WORKSTATION_PRESTART=PASS' 'w2' "$ORDER" 1
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS' 'w1' "$ORDER" 1
write_long_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
RUNLOG="$SANDBOX/run.log"
set -m
( cd "$SANDBOX" && HOME="$SANDBOX/home" exec bash \
    "$SANDBOX/real_fcu_full_stack_workstation.sh" run-t3a ) \
  >"$RUNLOG" 2>&1 </dev/null &
HELPER_PID=$!
set +m
WAITED=0
while [ "$WAITED" -lt 60 ]; do
  if grep -q 'CAPTURE_STUB_RUNNING' "$RUNLOG" 2>/dev/null; then break; fi
  WAITED=$((WAITED + 1))
  sleep 1
done
grep -q 'CAPTURE_STUB_RUNNING' "$RUNLOG" \
  || fail_test 'the capture stand-in never reached the foreground'
HELPER_PGID="$(ps -o pgid= -p "$HELPER_PID" 2>/dev/null | tr -d ' ')"
[ -n "$HELPER_PGID" ] || fail_test 'the helper has no process group'
kill -INT -- "-$HELPER_PGID" 2>/dev/null || true
WAITED=0
while [ "$WAITED" -lt 90 ]; do
  if ! kill -0 "$HELPER_PID" 2>/dev/null; then break; fi
  WAITED=$((WAITED + 1))
  sleep 1
done
if kill -0 "$HELPER_PID" 2>/dev/null; then
  kill -KILL -- "-$HELPER_PGID" 2>/dev/null || true
  fail_test 'an operator interrupt did not stop the helper'
fi
OUTPUT="$(cat "$RUNLOG")"
require_text "$OUTPUT" 'operator stop requested' \
  'an operator interrupt was not recognised as one'
refute_text "$OUTPUT" 'exited on its own' \
  'an operator interrupt was mistaken for the capture node failing'
FIRST_STOPPED="$(grep -E '^w[12]$' "$ORDER" | head -1)"
LAST_STOPPED="$(grep -E '^w[12]$' "$ORDER" | tail -1)"
[ "$FIRST_STOPPED" = 'w2' ] \
  || fail_test "on an interrupt the VRX supervisor must stop first, got '$FIRST_STOPPED'"
[ "$LAST_STOPPED" = 'w1' ] \
  || fail_test "on an interrupt the real-FCU supervisor must stop last, got '$LAST_STOPPED'"
discard_sandbox "$SANDBOX"
pass_case

# --- the capture node failing by itself does not tear the stack down -------
SANDBOX="$(make_sandbox)"
ORDER="$SANDBOX/order.txt"
: >"$ORDER"
write_supervisor_stub "$SANDBOX/fcu_to_vrx_workstation.sh" \
  'FCU_TO_VRX_WORKSTATION_PRESTART=PASS' 'w2' "$ORDER" 1
write_supervisor_stub "$SANDBOX/real_fcu_digital_twin_workstation.sh" \
  'REAL_FCU_WORKSTATION_SERVICES=PASS' 'w1' "$ORDER" 1
write_capture_stub "$SANDBOX/real_fcu_command_feedback_capture.py" "$ORDER"
set +e
OUTPUT="$(run_helper "$SANDBOX" run-t3a)"
set -e
require_text "$OUTPUT" 'exited on its own' \
  'the capture node ending by itself was not reported as such'
require_text "$OUTPUT" 'Nothing else has been stopped' \
  'the hold does not say the stack is still up'
refute_text "$OUTPUT" 'operator stop requested' \
  'a capture failure was mistaken for an operator stop'
discard_sandbox "$SANDBOX"
pass_case

printf 'full-stack workstation helper tests: PASS cases=%d runtime=not-started\n' "$CASES"
