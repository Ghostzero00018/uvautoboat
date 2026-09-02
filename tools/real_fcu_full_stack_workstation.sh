#!/usr/bin/env bash
# Single workstation entry point for the real-FCU digital-twin run.
#
# Sequences the three workstation processes that were previously started by
# hand in three terminals:
#
#   1. the VRX supervisor          tools/fcu_to_vrx_workstation.sh
#   2. the real-FCU supervisor     tools/real_fcu_digital_twin_workstation.sh
#   3. the command/feedback capture tools/real_fcu_command_feedback_capture.py
#
# This script sequences and supervises. It does not re-implement a single
# guard, threshold or readiness check; every one of those stays in the helper
# that owns it. If a helper stops the run, the reason it prints is the reason.
#
# The capture node runs in the foreground of this terminal on purpose: it is
# interactive and expects the ESC-threshold observations to be typed during
# the run.

set -Eeuo pipefail

RFCUFS_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RFCUFS_W2="$RFCUFS_SCRIPT_DIR/fcu_to_vrx_workstation.sh"
RFCUFS_W1="$RFCUFS_SCRIPT_DIR/real_fcu_digital_twin_workstation.sh"
RFCUFS_CAPTURE="$RFCUFS_SCRIPT_DIR/real_fcu_command_feedback_capture.py"

RFCUFS_RUN_DIR=''
RFCUFS_CLEANING=0
RFCUFS_W2_PGID=''
RFCUFS_W1_PGID=''
RFCUFS_MODE=''
RFCUFS_TIER=''
RFCUFS_OPERATOR_STOP=0

# Vehicle mapping and rails. These are the values the previous run's own
# PRESTART marker recorded for this boat: left thruster on SERVO3, right on
# SERVO1, rails 800/800/2200 with neutral at minimum. They are printed back
# for confirmation before anything starts, and every one can be overridden
# from the environment.
: "${FCU_VRX_LEFT_SERVO_CHANNEL:=3}"
: "${FCU_VRX_RIGHT_SERVO_CHANNEL:=1}"
: "${FCU_VRX_LEFT_PWM_MIN:=800}"
: "${FCU_VRX_LEFT_PWM_NEUTRAL:=800}"
: "${FCU_VRX_LEFT_PWM_MAX:=2200}"
: "${FCU_VRX_RIGHT_PWM_MIN:=800}"
: "${FCU_VRX_RIGHT_PWM_NEUTRAL:=800}"
: "${FCU_VRX_RIGHT_PWM_MAX:=2200}"
: "${FCU_VRX_MAX_THRUST:=800.0}"
: "${FCU_VRX_OBSERVER_STALE_SECONDS:=5}"
: "${FCU_VRX_CORRELATED_OBSERVATION:=1}"

# Both supervisors' readiness windows open before the Pi has been started, so
# the stock defaults of 120 and 600 are not reachable by hand. 1200 is what
# the 02/09/2026 run used after a W1 timeout ended an attempt with under a
# minute to spare.
: "${FCU_TO_VRX_READY_TIMEOUT_SECONDS:=1200}"
: "${REAL_FCU_READY_TIMEOUT_SECONDS:=1200}"

# Seconds to wait for each supervisor's own marker before giving up.
: "${RFCUFS_W2_PRESTART_TIMEOUT_SECONDS:=900}"
: "${RFCUFS_W1_WAITING_TIMEOUT_SECONDS:=600}"
# Seconds the closeout prompt waits before stopping W1 anyway.
: "${RFCUFS_CLOSEOUT_PROMPT_SECONDS:=900}"

# Optional passthrough, off unless set by the operator.
: "${REAL_FCU_HAILO_PERSON_STOP:=0}"
: "${REAL_FCU_PERSON_ALERT_ADVISORY:=0}"

rfcufs_log() {
  printf '[full-stack] %s\n' "$1"
}

rfcufs_fail() {
  printf '[full-stack] STOP: %s\n' "$1" >&2
  exit 1
}

rfcufs_usage() {
  cat >&2 <<'EOF'
usage: real_fcu_full_stack_workstation.sh check|run|run-t2a|run-t3a

  check     run both supervisors' own preflight checks and exit.
            Needs no Pi and no flight controller.
  run       full stack, capture tier t2a
  run-t2a   full stack, capture tier t2a
  run-t3a   full stack, capture tier t3a with ESC-threshold calibration

The tier must match the run mode used on the Pi.
EOF
  exit 2
}

# W1 and W2 each export their own ROS domain. A domain inherited from this
# shell would follow them into their children, so they are always started
# with those three variables removed. This is an array rather than a function
# because setsid execs a real command and cannot run a shell function.
RFCUFS_CLEAN_ENV=(env -u ROS_DOMAIN_ID -u ROS_AUTOMATIC_DISCOVERY_RANGE -u ROS_LOCALHOST_ONLY)

# Both supervisors' check modes run their own test suites, and those suites
# assert that a missing configuration is rejected. An exported value reaches
# the assertion and makes it pass validation, so check mode scrubs the whole
# operator-facing set before delegating. Verified 02/09/2026: the VRX suite
# reports PASS cases=33 scrubbed and fails its own missing-configuration case
# when the values are exported.
RFCUFS_SCRUBBED_ENV=(env
  -u ROS_DOMAIN_ID -u ROS_AUTOMATIC_DISCOVERY_RANGE -u ROS_LOCALHOST_ONLY
  -u FCU_VRX_LEFT_SERVO_CHANNEL -u FCU_VRX_RIGHT_SERVO_CHANNEL
  -u FCU_VRX_LEFT_PWM_MIN -u FCU_VRX_LEFT_PWM_NEUTRAL -u FCU_VRX_LEFT_PWM_MAX
  -u FCU_VRX_RIGHT_PWM_MIN -u FCU_VRX_RIGHT_PWM_NEUTRAL -u FCU_VRX_RIGHT_PWM_MAX
  -u FCU_VRX_MAX_THRUST -u FCU_VRX_OBSERVER_STALE_SECONDS
  -u FCU_VRX_CORRELATED_OBSERVATION
  -u FCU_TO_VRX_READY_TIMEOUT_SECONDS -u FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS
  -u REAL_FCU_READY_TIMEOUT_SECONDS -u REAL_FCU_STATUS_TIMEOUT_SECONDS
  -u REAL_FCU_POLL_SECONDS -u REAL_FCU_HAILO_PERSON_STOP
  -u REAL_FCU_PERSON_ALERT_ADVISORY)

# Each supervisor gets its own process group, so a Ctrl+C in this terminal
# reaches only this script and the foreground capture node. Without that the
# signal would hit all three at once and the documented stop order could not
# be honoured.
# Sets RFCUFS_LAST_PGID rather than echoing it: this function also logs, and a
# command substitution would capture the log line along with the value.
#
# Job control, not setsid. A non-interactive shell sets SIGINT to SIG_IGN for
# every asynchronous child, and a shell cannot trap a signal that was ignored
# when it started, so a supervisor launched with plain "&" never runs its own
# INT handler: the stop would fall through to TERM, which both supervisors
# record as a failed stop. With "set -m" each background job instead gets its
# own process group with SIGINT left trappable, which is what the ordered stop
# needs. Measured on this workstation 02/09/2026: plain background gives
# SigIgn=...6 with INT uncaught, "set -m" gives SigIgn=...4 with INT caught.
# setsid is not used because under job control it is already a process-group
# leader, so it forks and $! stops referring to the supervisor.
RFCUFS_LAST_PGID=''
rfcufs_start_supervisor() {
  local name="$1" log="$2"
  shift 2
  RFCUFS_LAST_PGID=''
  set -m
  "$@" >"$log" 2>&1 </dev/null &
  local pid=$!
  set +m
  local pgid=''
  local waited=0
  while [ "$waited" -lt 50 ]; do
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" || pgid=''
    if [ -n "$pgid" ]; then
      break
    fi
    waited=$((waited + 1))
    sleep 0.1
  done
  if [ -z "$pgid" ]; then
    printf '\n--- last 30 lines of %s ---\n' "$log" >&2
    tail -30 "$log" >&2 || true
    printf -- '--- end ---\n\n' >&2
    rfcufs_fail "$name did not start"
  fi
  if [ "$pgid" = "$$" ]; then
    rfcufs_fail "$name shares this script's process group; refusing to signal it"
  fi
  RFCUFS_LAST_PGID="$pgid"
  rfcufs_log "started $name pid=$pid pgid=$pgid log=$log"
}

rfcufs_pgid_alive() {
  local pgid="$1"
  [ -n "$pgid" ] || return 1
  kill -0 -- "-$pgid" 2>/dev/null
}

# Wait for a marker in a supervisor's log, and stop early if that supervisor
# dies. Waiting the whole timeout on a dead child wastes the operator's time
# on a run that has already ended.
rfcufs_wait_marker() {
  local name="$1" log="$2" marker="$3" timeout="$4" pgid="$5"
  local deadline=$((SECONDS + timeout))
  rfcufs_log "waiting for $name: $marker"
  while [ "$SECONDS" -lt "$deadline" ]; do
    if [ -f "$log" ] && grep -q -- "$marker" "$log"; then
      rfcufs_log "$name reached $marker"
      return 0
    fi
    if ! rfcufs_pgid_alive "$pgid"; then
      printf '\n--- last 30 lines of %s ---\n' "$log" >&2
      tail -30 "$log" >&2 || true
      printf -- '--- end ---\n\n' >&2
      rfcufs_fail "$name exited before reaching: $marker"
    fi
    sleep 2
  done
  printf '\n--- last 30 lines of %s ---\n' "$log" >&2
  tail -30 "$log" >&2 || true
  printf -- '--- end ---\n\n' >&2
  rfcufs_fail "$name did not reach $marker within ${timeout}s"
}

rfcufs_stop_supervisor() {
  local name="$1" pgid="$2" grace="${3:-120}"
  if ! rfcufs_pgid_alive "$pgid"; then
    rfcufs_log "$name already stopped"
    return 0
  fi
  rfcufs_log "stopping $name (pgid=$pgid), allowing ${grace}s for its own teardown"
  kill -INT -- "-$pgid" 2>/dev/null || true
  local waited=0
  while [ "$waited" -lt "$grace" ]; do
    if ! rfcufs_pgid_alive "$pgid"; then
      rfcufs_log "$name stopped cleanly"
      return 0
    fi
    waited=$((waited + 1))
    sleep 1
  done
  rfcufs_log "$name did not stop within ${grace}s, sending TERM"
  kill -TERM -- "-$pgid" 2>/dev/null || true
  sleep 5
  if rfcufs_pgid_alive "$pgid"; then
    rfcufs_log "$name still alive after TERM; it is left running for inspection"
    return 1
  fi
  return 0
}

# Stop order, from the run-sheet: the operator disarms externally, W2 stops,
# the Pi closeout runs, and W1 stops last. W1 is last because its stop marker
# is what releases the Pi, and because stopping it kills the dashboard the
# operator is still reading during the closeout.
# An operator Ctrl+C is a request to stop the run. The capture node ending on
# its own is not: it can die on a runtime error while the boat is still armed,
# and tearing the stack down then would take the dashboard and its emergency
# stop away from the operator at the worst possible moment. Only the first of
# those two may proceed straight to teardown.
rfcufs_on_interrupt() {
  RFCUFS_OPERATOR_STOP=1
  rfcufs_log 'operator stop requested; beginning the ordered stop'
  rfcufs_cleanup
}

rfcufs_cleanup() {
  local incoming_rc=$?
  [ "$RFCUFS_CLEANING" -eq 0 ] || return "$incoming_rc"
  RFCUFS_CLEANING=1
  trap - INT TERM HUP EXIT
  printf '\n'
  rfcufs_log 'stopping the workstation stack in the documented order'

  if [ -n "$RFCUFS_W2_PGID" ]; then
    rfcufs_stop_supervisor 'W2 (VRX supervisor)' "$RFCUFS_W2_PGID" 180 || true
  fi

  if [ -n "$RFCUFS_W1_PGID" ] && rfcufs_pgid_alive "$RFCUFS_W1_PGID"; then
    cat <<EOF

  W1 is still running, so the dashboard is still up.
  Complete the Pi closeout now, in the Pi terminal.
  W1 stops last: its stop marker is what releases the Pi.

EOF
    local reply=''
    if read -r -t "$RFCUFS_CLOSEOUT_PROMPT_SECONDS" \
        -p "  Press Enter once the Pi is at its closeout wait (or wait ${RFCUFS_CLOSEOUT_PROMPT_SECONDS}s): " reply; then
      printf '\n'
    else
      printf '\n'
      rfcufs_log 'closeout prompt timed out; stopping W1 now'
    fi
    rfcufs_stop_supervisor 'W1 (real-FCU supervisor)' "$RFCUFS_W1_PGID" 180 || true
  fi

  rfcufs_log "logs: ${RFCUFS_RUN_DIR:-<none>}"
  rfcufs_log 'each supervisor wrote its own run directory under ~/Desktop; read those for evidence'
  rfcufs_log "FULL_STACK_EXIT status=$incoming_rc"
  exit "$incoming_rc"
}

rfcufs_preflight_paths() {
  local path
  for path in "$RFCUFS_W2" "$RFCUFS_W1" "$RFCUFS_CAPTURE"; do
    [ -f "$path" ] || rfcufs_fail "required helper missing: $path"
  done
  local command
  for command in env grep ps tail python3 ros2; do
    command -v "$command" >/dev/null 2>&1 \
      || rfcufs_fail "required command missing: $command"
  done
}

rfcufs_person_alert_description() {
  if [ "$REAL_FCU_HAILO_PERSON_STOP" != '1' ]; then
    printf 'detector not started'
    return 0
  fi
  if [ "$REAL_FCU_PERSON_ALERT_ADVISORY" = '1' ]; then
    printf 'advisory, warns on the dashboard without stopping'
  else
    printf 'enabled, a detection stops the stack'
  fi
}

rfcufs_show_contract() {
  cat <<EOF

  Mapping and rails this run will use. Confirm these against the vehicle,
  not against this file:

    left thruster    SERVO$FCU_VRX_LEFT_SERVO_CHANNEL
    right thruster   SERVO$FCU_VRX_RIGHT_SERVO_CHANNEL
    left rails       $FCU_VRX_LEFT_PWM_MIN / $FCU_VRX_LEFT_PWM_NEUTRAL / $FCU_VRX_LEFT_PWM_MAX
    right rails      $FCU_VRX_RIGHT_PWM_MIN / $FCU_VRX_RIGHT_PWM_NEUTRAL / $FCU_VRX_RIGHT_PWM_MAX
    max thrust       $FCU_VRX_MAX_THRUST
    capture tier     ${RFCUFS_TIER:-<none>}
    person alert     $(rfcufs_person_alert_description)

  Neutral sits at minimum on these rails, so neutral demand reads zero
  VRX thrust rather than an idle value.

EOF
}

rfcufs_run_checks() {
  rfcufs_log 'running the VRX supervisor preflight (its own check mode, scrubbed env)'
  if ! "${RFCUFS_SCRUBBED_ENV[@]}" bash "$RFCUFS_W2" check; then
    rfcufs_fail 'VRX supervisor preflight failed; its own output above is the reason'
  fi
  rfcufs_log 'running the real-FCU supervisor preflight (its own check mode, scrubbed env)'
  if ! "${RFCUFS_SCRUBBED_ENV[@]}" bash "$RFCUFS_W1" check; then
    rfcufs_fail 'real-FCU supervisor preflight failed; its own output above is the reason'
  fi
  rfcufs_log 'running this script''s own syntax check'
  if ! bash -n "$RFCUFS_SCRIPT_DIR/real_fcu_full_stack_workstation.sh"; then
    rfcufs_fail 'this script failed its own syntax check'
  fi
  rfcufs_log 'FULL_STACK_CHECK=PASS both supervisor preflights passed, runtime=not-started'
}

rfcufs_main() {
  [ "$#" -eq 1 ] || rfcufs_usage
  case "$1" in
    check)   RFCUFS_MODE=check ;;
    run)     RFCUFS_MODE=run; RFCUFS_TIER=t2a ;;
    run-t2a) RFCUFS_MODE=run; RFCUFS_TIER=t2a ;;
    run-t3a) RFCUFS_MODE=run; RFCUFS_TIER=t3a ;;
    *)       rfcufs_usage ;;
  esac

  rfcufs_preflight_paths

  if [ "$RFCUFS_MODE" = check ]; then
    rfcufs_show_contract
    rfcufs_run_checks
    return 0
  fi

  RFCUFS_RUN_DIR="$HOME/Desktop/real_fcu_full_stack_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$RFCUFS_RUN_DIR/logs"
  rfcufs_show_contract
  rfcufs_log "FULL_STACK_START mode=$RFCUFS_MODE tier=$RFCUFS_TIER run_dir=$RFCUFS_RUN_DIR"

  # HUP is trapped alongside INT and TERM. An untrapped signal terminates the
  # shell without running the EXIT trap, so a closed terminal or a dropped
  # session would leave both supervisors running with their ports still bound
  # and nothing left to stop them. Observed on this workstation 02/09/2026.
  trap rfcufs_on_interrupt INT TERM HUP
  trap rfcufs_cleanup EXIT

  # W2 first: it is the slowest to come up, and starting the simulator before
  # the dashboard means the dashboard is not left waiting on it.
  rfcufs_start_supervisor 'W2 (VRX supervisor)' \
    "$RFCUFS_RUN_DIR/logs/w2.log" \
    "${RFCUFS_CLEAN_ENV[@]}" \
      FCU_TO_VRX_READY_TIMEOUT_SECONDS="$FCU_TO_VRX_READY_TIMEOUT_SECONDS" \
      FCU_VRX_LEFT_SERVO_CHANNEL="$FCU_VRX_LEFT_SERVO_CHANNEL" \
      FCU_VRX_RIGHT_SERVO_CHANNEL="$FCU_VRX_RIGHT_SERVO_CHANNEL" \
      FCU_VRX_LEFT_PWM_MIN="$FCU_VRX_LEFT_PWM_MIN" \
      FCU_VRX_LEFT_PWM_NEUTRAL="$FCU_VRX_LEFT_PWM_NEUTRAL" \
      FCU_VRX_LEFT_PWM_MAX="$FCU_VRX_LEFT_PWM_MAX" \
      FCU_VRX_RIGHT_PWM_MIN="$FCU_VRX_RIGHT_PWM_MIN" \
      FCU_VRX_RIGHT_PWM_NEUTRAL="$FCU_VRX_RIGHT_PWM_NEUTRAL" \
      FCU_VRX_RIGHT_PWM_MAX="$FCU_VRX_RIGHT_PWM_MAX" \
      FCU_VRX_MAX_THRUST="$FCU_VRX_MAX_THRUST" \
      FCU_VRX_OBSERVER_STALE_SECONDS="$FCU_VRX_OBSERVER_STALE_SECONDS" \
      FCU_VRX_CORRELATED_OBSERVATION="$FCU_VRX_CORRELATED_OBSERVATION" \
      bash "$RFCUFS_W2" run-real-fcu
  RFCUFS_W2_PGID="$RFCUFS_LAST_PGID"
  rfcufs_wait_marker 'W2' "$RFCUFS_RUN_DIR/logs/w2.log" \
    'FCU_TO_VRX_WORKSTATION_PRESTART=PASS' \
    "$RFCUFS_W2_PRESTART_TIMEOUT_SECONDS" "$RFCUFS_W2_PGID"

  rfcufs_start_supervisor 'W1 (real-FCU supervisor)' \
    "$RFCUFS_RUN_DIR/logs/w1.log" \
    "${RFCUFS_CLEAN_ENV[@]}" \
      REAL_FCU_READY_TIMEOUT_SECONDS="$REAL_FCU_READY_TIMEOUT_SECONDS" \
      REAL_FCU_HAILO_PERSON_STOP="$REAL_FCU_HAILO_PERSON_STOP" \
      REAL_FCU_PERSON_ALERT_ADVISORY="$REAL_FCU_PERSON_ALERT_ADVISORY" \
      bash "$RFCUFS_W1" run
  RFCUFS_W1_PGID="$RFCUFS_LAST_PGID"
  rfcufs_wait_marker 'W1' "$RFCUFS_RUN_DIR/logs/w1.log" \
    'REAL_FCU_WORKSTATION_SERVICES=PASS' \
    "$RFCUFS_W1_WAITING_TIMEOUT_SECONDS" "$RFCUFS_W1_PGID"

  # The dashboard is served as soon as W1 reports its services, but the
  # bench-control URL is not: W1 derives it from the Pi's resolved mapping and
  # only prints it once the Pi has connected. So the base URL is offered now
  # and the exact bench URL is left where W1 writes it.
  cat <<EOF

  ========================================================================
  Workstation is up. Three things left, in this order.

  1. This terminal is about to run the capture node. Leave it running: the
     Pi's discovery guard requires it, and the Pi will stop without it.

  2. Start the Pi helper, in its own terminal, with the physical-declaration
     flags the tier requires. The tier there must be $RFCUFS_TIER.

  3. Once the Pi has connected, open the dashboard. The base URL is

       http://127.0.0.1:8002/

     and W1 prints the exact bench-control URL, with the mapping it resolved
     from the flight controller, once the Pi is up. Read it with:

       grep REAL_FCU_BENCH_URL $RFCUFS_RUN_DIR/logs/w1.log

     Confirm the Hardware Safety reading agrees with the physical switch.
     A reading stuck at "Unknown (stale)" is not an observation.

  The capture node is interactive: type the ESC-threshold observations here
  during the run. Ctrl+C here begins the ordered stop.
  ========================================================================

EOF

  local -a capture_command=(python3 "$RFCUFS_CAPTURE" "$RFCUFS_TIER")
  if [ "$RFCUFS_TIER" = t3a ]; then
    capture_command+=(--esc-threshold-calibration)
  fi
  local capture_rc=0
  ROS_DOMAIN_ID=43 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET ROS_LOCALHOST_ONLY=0 \
    "${capture_command[@]}" || capture_rc=$?

  # Reached only when the capture node ended without an operator interrupt:
  # the interrupt handler tears down and exits rather than returning here.
  cat <<EOF

  ========================================================================
  WARNING: the capture node exited on its own (status $capture_rc).

  Nothing else has been stopped. The dashboard, its emergency stop and both
  supervisors are still running, and the Pi is untouched. If the boat is
  armed it is still armed.

  Recording has ended, so any observation from here on is not being captured.

  Bring the boat to a safe state first. Then press Ctrl+C here to stop the
  workstation in the documented order.
  ========================================================================

EOF
  rfcufs_log 'holding with the stack up; Ctrl+C stops it in the documented order'
  local ignored=''
  while [ "$RFCUFS_OPERATOR_STOP" -eq 0 ]; do
    if ! read -r -t 30 ignored; then
      # A terminal at end of file cannot deliver a Ctrl+C, so holding would
      # never end. Anything else means the read simply timed out; keep holding.
      if [ ! -t 0 ]; then
        rfcufs_log 'no terminal on standard input; stopping now'
        return 0
      fi
    fi
  done
  return 0
}

rfcufs_main "$@"
