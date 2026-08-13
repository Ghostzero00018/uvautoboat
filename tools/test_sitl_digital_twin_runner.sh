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

SITL_CONFLICT_OUTPUT="$(bash -c '
  source "$1"
  source "$2"
  printf "%s\n" "${SITL_CONFLICT_PATTERNS[@]}"
' _ "$PREFLIGHT" "$RUNNER")"
for physical_helper in \
  real_fcu_digital_twin_workstation.sh \
  real_fcu_digital_twin_pi.sh; do
  grep -Fxq "$physical_helper" <<<"$SITL_CONFLICT_OUTPUT" \
    || fail_test "SITL conflict guard omits physical helper: $physical_helper"
done
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
SITL_COMMAND_LINE="$(grep '^SITL_COMMAND=' <<<"$STATE_OUTPUT")"
grep -Fq -- '/home/ghostzero/ardupilot/build/sitl/bin/ardurover -S --model motorboat-skid' \
  <<<"$SITL_COMMAND_LINE" || fail_test 'SITL command does not directly launch the pinned Rover'
grep -Fq -- "--chdir=$TEST_TMP/sitl_digital_twin_" <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command does not own the run-specific state directory'
grep -Fq -- '/sitl_state' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command cwd is not the run-specific state directory'
grep -Fq -- '--defaults /home/ghostzero/ardupilot/Tools/autotest/default_params/rover.parm,/home/ghostzero/ardupilot/Tools/autotest/default_params/motorboat.parm,/home/ghostzero/ardupilot/Tools/autotest/default_params/rover-skid.parm,' \
  <<<"$SITL_COMMAND_LINE" || fail_test 'SITL command does not use absolute pinned default files'
grep -Fq -- '/manifest/sitl.params' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command does not include the run-specific parameter overlay'
grep -Fq -- '--speedup 1 --slave 0' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command changed speed or slave isolation'
grep -Fq -- '--sim-address=127.0.0.1 -I0' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command changed loopback simulation identity'
! grep -Fq -- 'sim_vehicle.py' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command still delegates Rover ownership to sim_vehicle.py'
! grep -Fq -- 'venv-ardupilot/bin/activate' <<<"$SITL_COMMAND_LINE" \
  || fail_test 'SITL command still sources the ArduPilot virtual environment'
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
grep -Fq -- 'expected_domain_id:="42"' <<<"$STATE_OUTPUT" \
  || fail_test 'SITL bridge does not explicitly require domain 42'
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
  for command_name in SITL_MAVROS_COMMAND SITL_BRIDGE_COMMAND; do
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
# The claim file outlives Ctrl+C, so an interrupted command can never be
# re-run and the phase can only time out. The warning is load-bearing safety
# text printed beside a command the operator runs against an armed vehicle.
grep -Fq 'Do NOT interrupt that command' <<<"$GATE_OUTPUT" \
  || fail_test 'operator gate dropped the do-not-interrupt warning'
grep -Fq 'claims the gate before it opens the' <<<"$GATE_OUTPUT" \
  || fail_test 'operator gate no longer explains why interrupting is fatal'
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

# The FCU Bench panel has no E-Stop; the control lives in Mission Control. An
# operator hunting for a button that does not exist is doing so mid-run with an
# armed vehicle, so the prompt must name the real one.
grep -Fq 'btn-emergency-stop' "$RUNNER" \
  || fail_test 'E-Stop prompt no longer names the Mission Control control'
grep -Fq 'Mission Control panel' "$RUNNER" \
  || fail_test 'E-Stop prompt no longer names the panel that holds it'
grep -Fq 'FCU Bench panel has no E-Stop' "$RUNNER" \
  || fail_test 'E-Stop prompt no longer rules out the bench panel'
! grep -Fq 'bench E-Stop once' "$RUNNER" \
  || fail_test 'E-Stop prompt reverted to the non-existent bench control'
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
BRIDGE_FRAME_GUARD_LINE="$(grep -n 'if \[ -n "${SITL_CHILD_INDEX\[bridge\]+present}" \]; then' \
  <<<"$CLEANUP_FUNCTION" | cut -d: -f1 || true)"
SHUTDOWN_WAIT_LINE="$(grep -n 'if ! sitl_wait_shutdown_frames; then' \
  <<<"$CLEANUP_FUNCTION" | cut -d: -f1 || true)"
[ -n "$BRIDGE_FRAME_GUARD_LINE" ] && [ -n "$SHUTDOWN_WAIT_LINE" ] \
  && [ "$BRIDGE_FRAME_GUARD_LINE" -lt "$SHUTDOWN_WAIT_LINE" ] \
  || fail_test 'early teardown still reports shutdown-frame failure before bridge startup'
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


# =============================================================================
# Post-run adjudication helper
# =============================================================================

ADJUDICATE="${ADJUDICATE:-$SCRIPT_DIR/sitl_digital_twin_adjudicate.sh}"
[ -r "$ADJUDICATE" ] || fail_test "adjudication helper missing: $ADJUDICATE"
bash -n "$ADJUDICATE" || fail_test 'adjudication helper failed bash -n'
pass_case

# A Cyrillic homoglyph in a process pattern never matches, so the conflict check
# would pass while the simulator was still running. Guard the whole file.
if LC_ALL=C grep -qP '[^\x09\x0A\x20-\x7E]' "$ADJUDICATE"; then
  LC_ALL=C grep -nP '[^\x09\x0A\x20-\x7E]' "$ADJUDICATE" >&2
  fail_test 'adjudication helper contains non-ASCII bytes'
fi
grep -Fqx '  ardurover' "$ADJUDICATE" \
  || fail_test 'adjudication helper lost the literal ASCII ardurover pattern'
pass_case

adj_stop_order='["dashboard","rosbridge","bridge","evidence","mavros","mavproxy","sitl"]'

# Build a run directory that a passing acceptance would leave behind.
adj_make_fixture() {
  local run="$1"
  rm -rf "$run"
  mkdir -p "$run"/{captures,control,evidence,logs,manifest,operator,sitl_state}

  local phase
  for phase in startup ready_disarmed browser_ready arm positive release \
    negative estop disarm; do
    printf '{"schema":"uvautoboat.sitl.evidence.v1","phase":"%s"}\n' "$phase" \
      >"$run/evidence/$phase.json"
  done
  # Faithful to finalize_run: teardown embeds the runtime and shutdown frames
  # verbatim, so the embedded copies and the control files must agree.
  adj_runtime='{"cleanup_rc":0,"children_stopped":true,"ports_free":true,"stop_order":'"$adj_stop_order"'}'
  adj_frames='{"frames":[1,2,3]}'
  printf '%s\n' "$adj_runtime" >"$run/control/teardown_runtime.json"
  printf '%s\n' "$adj_frames" >"$run/control/shutdown_frames.json"
  printf '%s\n' "$adj_frames" >"$run/control/disarm_release_frames.json"
  printf '{"schema":"uvautoboat.sitl.evidence.v1","phase":"teardown","pass":true,"cleanup_rc":0,"capture_fault":null,"runtime":%s,"shutdown_frames":%s}\n' \
    "$adj_runtime" "$adj_frames" >"$run/evidence/teardown.json"

  printf 'SITL_PREFLIGHT=PASS\nSITL_SESSION=READY\n' >"$run/supervisor.log"
  printf 'child\tcommand\nsitl\tardupilot\n' >"$run/manifest/commands.tsv"
  printf 'revision=test\n' >"$run/manifest/repository.txt"
  printf 'sitl log line\n' >"$run/logs/sitl.log"
  printf 'bridge log line\n' >"$run/logs/bridge.log"
  printf '{"topic":"/mavros/state"}\n' >"$run/captures/mavros_state.jsonl"

  # verdict.json carries the hashes the helper re-verifies, so it is written
  # last, from the files as they now stand.
  /usr/bin/python3 - "$run" <<'ADJPY'
import hashlib
import json
import sys
from pathlib import Path

run = Path(sys.argv[1])
names = [
    "startup.json", "ready_disarmed.json", "browser_ready.json", "arm.json",
    "positive.json", "release.json", "negative.json", "estop.json",
    "disarm.json", "teardown.json",
]
hashes = {
    f"evidence/{name}": hashlib.sha256(
        (run / "evidence" / name).read_bytes()
    ).hexdigest()
    for name in names
}
(run / "evidence" / "verdict.json").write_text(
    json.dumps({
        "schema": "uvautoboat.sitl.evidence.v1",
        "verdict": "PASS",
        "session_complete": True,
        "cleanup_rc": 0,
        "capture_fault": None,
        "missing": [],
        "evidence_sha256": hashes,
    }, indent=2) + "\n",
    encoding="utf-8",
)
ADJPY
}

adj_tree_digest() {
  find "$1" -type f -print0 |
    LC_ALL=C sort -z |
    xargs -0 sha256sum |
    sha256sum |
    cut -d' ' -f1
}

ADJ_RUN="$TEST_TMP/sitl_digital_twin_20260813_120000"

# --- passing fixture, and the helper must not disturb it ---------------------
adj_make_fixture "$ADJ_RUN"
ADJ_BEFORE="$(adj_tree_digest "$ADJ_RUN")"
set +e
ADJ_OUTPUT="$(bash "$ADJUDICATE" "$ADJ_RUN" 2>&1)"
ADJ_RC=$?
set -e
ADJ_AFTER="$(adj_tree_digest "$ADJ_RUN")"
# The passing fixture asserts real host state on purpose: the port and process
# checks are the half of the contract that cannot be faked. If this case fails
# with an OCCUPIED or SURVIVING line, the host is dirty, not the helper.
[ "$ADJ_RC" -eq 0 ] \
  || fail_test "adjudication rejected a passing fixture (check host state for OCCUPIED/SURVIVING lines): $ADJ_OUTPUT"
[ "$(grep -c '^SITL_ADJUDICATION=' <<<"$ADJ_OUTPUT")" -eq 1 ] \
  || fail_test 'adjudication printed more than one final verdict line'
[ "$(tail -1 <<<"$ADJ_OUTPUT")" = 'SITL_ADJUDICATION=PASS' ] \
  || fail_test 'passing fixture did not end with SITL_ADJUDICATION=PASS'
for expected in VERDICT_CHECK=PASS TEARDOWN_CHECK=PASS CONTROL_CROSSCHECK=PASS \
  'STOP_ORDER_CHECK=PASS order=dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl' \
  SITL_POSTRUN_PORTS=FREE SITL_POSTRUN_PROCESSES=FREE EVIDENCE_HASHES_CHECKED=10; do
  grep -Fq -- "$expected" <<<"$ADJ_OUTPUT" \
    || fail_test "adjudication output lost: $expected"
done
grep -Fq 'commands.tsv' <<<"$ADJ_OUTPUT" \
  || fail_test 'adjudication did not print manifest/commands.tsv'
grep -Fq 'supervisor.log' <<<"$ADJ_OUTPUT" \
  || fail_test 'adjudication did not print supervisor.log'
[ "$ADJ_BEFORE" = "$ADJ_AFTER" ] \
  || fail_test 'adjudication modified the run directory'
pass_case

# --- argument contract -------------------------------------------------------
for adj_args in '' 'relative/path' '/nonexistent/adjudication/run' '/tmp /tmp'; do
  set +e
  # shellcheck disable=SC2086
  ADJ_OUTPUT="$(bash "$ADJUDICATE" $adj_args 2>&1)"
  ADJ_RC=$?
  set -e
  [ "$ADJ_RC" -ne 0 ] \
    || fail_test "adjudication accepted bad arguments: [$adj_args]"
  [ "$(tail -1 <<<"$ADJ_OUTPUT")" = 'SITL_ADJUDICATION=FAIL' ] \
    || fail_test "bad arguments did not end with SITL_ADJUDICATION=FAIL: [$adj_args]"
done
pass_case

# --- each fault must be rejected, and diagnostics must keep gathering --------
adj_expect_fail() {
  local label="$1"
  set +e
  ADJ_OUTPUT="$(bash "$ADJUDICATE" "$ADJ_RUN" 2>&1)"
  ADJ_RC=$?
  set -e
  [ "$ADJ_RC" -ne 0 ] || fail_test "adjudication passed despite: $label"
  [ "$(tail -1 <<<"$ADJ_OUTPUT")" = 'SITL_ADJUDICATION=FAIL' ] \
    || fail_test "no FAIL verdict for: $label"
  [ "$(grep -c '^SITL_ADJUDICATION=' <<<"$ADJ_OUTPUT")" -eq 1 ] \
    || fail_test "more than one verdict line for: $label"
  grep -Fq 'retained hashes' <<<"$ADJ_OUTPUT" \
    || fail_test "diagnostics stopped early for: $label"
}

adj_make_fixture "$ADJ_RUN"
rm "$ADJ_RUN/evidence/positive.json"
adj_expect_fail 'missing positive.json'
grep -Fq 'MISSING: evidence/positive.json' <<<"$ADJ_OUTPUT" \
  || fail_test 'missing artifact was not named'
pass_case

adj_make_fixture "$ADJ_RUN"
printf '{"verdict": "PASS"\n' >"$ADJ_RUN/evidence/verdict.json"
adj_expect_fail 'malformed verdict.json'
pass_case

adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["pass"] = False
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/teardown.json"
adj_expect_fail 'teardown pass false'
grep -Fq 'teardown pass is not true' <<<"$ADJ_OUTPUT" \
  || fail_test 'false teardown was not named'
pass_case

adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["runtime"]["stop_order"] = [
    "sitl", "mavproxy", "mavros", "evidence", "bridge", "rosbridge", "dashboard",
]
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/teardown.json"
adj_expect_fail 'reversed stop order'
grep -Fq 'stop_order mismatch' <<<"$ADJ_OUTPUT" \
  || fail_test 'wrong stop order was not named'
pass_case

adj_make_fixture "$ADJ_RUN"
printf '{"schema":"uvautoboat.sitl.evidence.v1","phase":"arm","tampered":true}\n' \
  >"$ADJ_RUN/evidence/arm.json"
adj_expect_fail 'evidence hash mismatch'
grep -Fq 'hash mismatch for evidence/arm.json' <<<"$ADJ_OUTPUT" \
  || fail_test 'tampered evidence was not detected by hash'
pass_case

adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["runtime"]["cleanup_rc"] = 1
d["runtime"]["children_stopped"] = False
d["runtime"]["ports_free"] = False
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/teardown.json"
adj_expect_fail 'unclean teardown runtime'
for expected in 'cleanup_rc is 1' 'children_stopped is not true' \
  'ports_free is not true'; do
  grep -Fq "$expected" <<<"$ADJ_OUTPUT" \
    || fail_test "unclean runtime not named: $expected"
done
pass_case

# --- an uninspectable socket table is not a clean host -----------------------
adj_make_fixture "$ADJ_RUN"
ADJ_STUB_BIN="$TEST_TMP/adj_stub_bin"
mkdir -p "$ADJ_STUB_BIN"
printf '#!/bin/sh\necho "ss: simulated failure" >&2\nexit 2\n' >"$ADJ_STUB_BIN/ss"
chmod +x "$ADJ_STUB_BIN/ss"
set +e
ADJ_OUTPUT="$(PATH="$ADJ_STUB_BIN:$PATH" bash "$ADJUDICATE" "$ADJ_RUN" 2>&1)"
ADJ_RC=$?
set -e
[ "$ADJ_RC" -ne 0 ] || fail_test 'adjudication passed while socket inspection failed'
grep -Fq 'socket inspection failed' <<<"$ADJ_OUTPUT" \
  || fail_test 'socket inspection failure was not named'
[ "$(tail -1 <<<"$ADJ_OUTPUT")" = 'SITL_ADJUDICATION=FAIL' ] \
  || fail_test 'socket inspection failure did not end with FAIL'
pass_case

# --- the hash map must be the exact ten phase artifacts ----------------------
adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
only = "evidence/startup.json"
d["evidence_sha256"] = {only: d["evidence_sha256"][only]}
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/verdict.json"
adj_expect_fail 'hash map reduced to one artifact'
grep -Fq 'evidence_sha256 omits evidence/arm.json' <<<"$ADJ_OUTPUT" \
  || fail_test 'a partial hash map was accepted'
pass_case

adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["evidence_sha256"]["/etc/hostname"] = "0" * 64
d["evidence_sha256"]["../../../etc/passwd"] = "0" * 64
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/verdict.json"
adj_expect_fail 'hash map keys escaping the run directory'
grep -Fq 'escapes the run' <<<"$ADJ_OUTPUT" \
  || fail_test 'absolute or traversal hash keys were not rejected'
pass_case

# --- the control artifacts must actually decide ------------------------------
adj_make_fixture "$ADJ_RUN"
printf '{"cleanup_rc":9,"children_stopped":false,"ports_free":false,"stop_order":%s}\n' \
  "$adj_stop_order" >"$ADJ_RUN/control/teardown_runtime.json"
adj_expect_fail 'control runtime contradicting the embedded copy'
grep -Fq 'control/teardown_runtime.json disagrees' <<<"$ADJ_OUTPUT" \
  || fail_test 'a contradicting control runtime was ignored'
pass_case

adj_make_fixture "$ADJ_RUN"
printf '{"frames":[]}\n' >"$ADJ_RUN/control/shutdown_frames.json"
printf '{"frames":[]}\n' >"$ADJ_RUN/control/disarm_release_frames.json"
adj_expect_fail 'empty frame lists'
grep -Fq 'control/shutdown_frames.json holds 0 frames' <<<"$ADJ_OUTPUT" \
  || fail_test 'an empty shutdown frame list was accepted'
grep -Fq 'control/disarm_release_frames.json holds 0 frames' <<<"$ADJ_OUTPUT" \
  || fail_test 'an empty disarm release frame list was accepted'
pass_case

adj_make_fixture "$ADJ_RUN"
/usr/bin/python3 -c '
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["cleanup_rc"] = 9
d["capture_fault"] = {"error": "capture died"}
json.dump(d, open(p, "w"))
' "$ADJ_RUN/evidence/verdict.json"
adj_expect_fail 'verdict cleanup_rc and capture fault'
grep -Fq 'verdict cleanup_rc is 9' <<<"$ADJ_OUTPUT" \
  || fail_test 'a non-zero verdict cleanup_rc was accepted'
grep -Fq 'verdict capture_fault is' <<<"$ADJ_OUTPUT" \
  || fail_test 'a recorded capture fault was accepted'
grep -Fq 'disagree on cleanup_rc' <<<"$ADJ_OUTPUT" \
  || fail_test 'verdict and teardown were not cross-checked'
pass_case

adj_make_fixture "$ADJ_RUN"
printf '{"error":"capture faulted"}\n' >"$ADJ_RUN/control/capture_fault.json"
adj_expect_fail 'capture fault artifact present'
grep -Fq 'control/capture_fault.json exists' <<<"$ADJ_OUTPUT" \
  || fail_test 'a capture fault artifact was ignored'
pass_case

# --- a cleanup status must be integer zero, not merely equal to it -----------
# Python treats False == 0 and 0.0 == 0 as true, so equality alone accepts both
# where the supervisor writes an int (sitl_digital_twin_runner.sh writes %d).
for adj_bad_rc in 'false' '0.0'; do
  adj_make_fixture "$ADJ_RUN"
  /usr/bin/python3 -c '
import json, sys
path, raw = sys.argv[1], sys.argv[2]
value = False if raw == "false" else 0.0
for name in ("evidence/verdict.json", "evidence/teardown.json"):
    p = path + "/" + name
    d = json.load(open(p))
    d["cleanup_rc"] = value
    if "runtime" in d:
        d["runtime"]["cleanup_rc"] = value
    json.dump(d, open(p, "w"))
p = path + "/control/teardown_runtime.json"
d = json.load(open(p))
d["cleanup_rc"] = value
json.dump(d, open(p, "w"))
' "$ADJ_RUN" "$adj_bad_rc"
  # The hash map must stay consistent, or this would fail for the wrong reason.
  /usr/bin/python3 -c '
import hashlib, json, sys
run = sys.argv[1]
p = run + "/evidence/verdict.json"
d = json.load(open(p))
key = "evidence/teardown.json"
d["evidence_sha256"][key] = hashlib.sha256(
    open(run + "/evidence/teardown.json", "rb").read()
).hexdigest()
json.dump(d, open(p, "w"))
' "$ADJ_RUN"
  adj_expect_fail "cleanup_rc written as $adj_bad_rc"
  grep -Fq 'not integer 0' <<<"$ADJ_OUTPUT" \
    || fail_test "a non-integer cleanup_rc was accepted: $adj_bad_rc"
  for surface in 'verdict cleanup_rc' 'teardown cleanup_rc' \
    'runtime cleanup_rc' 'control runtime cleanup_rc'; do
    grep -Fq "$surface" <<<"$ADJ_OUTPUT" \
      || fail_test "surface not type-checked for $adj_bad_rc: $surface"
  done
  pass_case
done

# --- a parent whose argv mentions a pattern is not a survivor ----------------
# Without ancestor exclusion the helper matches the shell that launched it and
# reports a conflict on every clean run. The wrapper stays alive as the parent
# while the helper runs, with the pattern in its own command line.
adj_make_fixture "$ADJ_RUN"
ADJ_PARENT="$TEST_TMP/adj_parent_wrapper.sh"
cat >"$ADJ_PARENT" <<'WRAPPER'
#!/bin/bash
# $1 is a marker consumed only to place a pattern in this process's argv.
shift
"$@"
WRAPPER
chmod +x "$ADJ_PARENT"
set +e
ADJ_OUTPUT="$(bash "$ADJ_PARENT" ardurover "$ADJUDICATE" "$ADJ_RUN" 2>&1)"
ADJ_RC=$?
set -e
[ "$ADJ_RC" -eq 0 ] \
  || fail_test "a parent mentioning ardurover was treated as a survivor: $ADJ_OUTPUT"
[ "$(tail -1 <<<"$ADJ_OUTPUT")" = 'SITL_ADJUDICATION=PASS' ] \
  || fail_test 'ancestor exclusion did not yield a passing adjudication'
grep -Fq 'matched only this adjudication process tree' <<<"$ADJ_OUTPUT" \
  || fail_test 'ancestor exclusion did not report why the match was discounted'
pass_case

# --- every required artifact must decode as a JSON object -------------------
# JSON null decodes to Python None, which read as "nothing to validate" and let
# a null artifact bypass every check that followed it.
adj_required_json=(
  evidence/startup.json
  evidence/ready_disarmed.json
  evidence/browser_ready.json
  evidence/arm.json
  evidence/positive.json
  evidence/release.json
  evidence/negative.json
  evidence/estop.json
  evidence/disarm.json
  evidence/teardown.json
  evidence/verdict.json
  control/disarm_release_frames.json
  control/shutdown_frames.json
  control/teardown_runtime.json
)

# The helper takes its required set from its own array; the two must agree or
# this coverage silently stops matching what is checked.
adj_helper_required="$(
  bash -c '
    set -uo pipefail
    eval "$(sed -n "/^ADJ_REQUIRED_JSON=(/,/^)/p" "$1")"
    printf "%s\n" "${ADJ_REQUIRED_JSON[@]}"
  ' _ "$ADJUDICATE"
)"
[ "$adj_helper_required" = "$(printf '%s\n' "${adj_required_json[@]}")" ] \
  || fail_test 'helper required-artifact list diverged from its coverage'
pass_case

# Hashed phase artifacts need the map refreshed, or the case would pass on a
# hash mismatch instead of on the shape it is meant to pin.
adj_refresh_hashes() {
  /usr/bin/python3 -c '
import hashlib, json, sys
from pathlib import Path
run = Path(sys.argv[1])
p = run / "evidence" / "verdict.json"
try:
    d = json.loads(p.read_text(encoding="utf-8"))
except ValueError:
    sys.exit(0)
if not isinstance(d, dict) or not isinstance(d.get("evidence_sha256"), dict):
    sys.exit(0)
for key in list(d["evidence_sha256"]):
    target = run / key
    if target.is_file():
        d["evidence_sha256"][key] = hashlib.sha256(target.read_bytes()).hexdigest()
p.write_text(json.dumps(d), encoding="utf-8")
' "$1"
}

for adj_target in "${adj_required_json[@]}"; do
  adj_make_fixture "$ADJ_RUN"
  printf 'null\n' >"$ADJ_RUN/$adj_target"
  adj_refresh_hashes "$ADJ_RUN"
  adj_expect_fail "null $adj_target"
  # Two independent layers, asserted separately. The printing loop emits
  # NOT A JSON OBJECT; only the verdict checks emit an ADJUDICATION_FAIL line,
  # so matching the bare text would let either layer alone satisfy both.
  grep -Fq "NOT A JSON OBJECT: $adj_target decoded as NoneType" <<<"$ADJ_OUTPUT" \
    || fail_test "a null artifact was printed as valid: $adj_target"
  grep -Fq "ADJUDICATION_FAIL: $adj_target decoded as NoneType" <<<"$ADJ_OUTPUT" \
    || fail_test "a null artifact was not rejected by the verdict checks: $adj_target"
done
pass_case

# One array and one scalar, to pin that the rejection is shape-based rather
# than a special case for null.
adj_make_fixture "$ADJ_RUN"
printf '[1,2,3]\n' >"$ADJ_RUN/evidence/arm.json"
adj_refresh_hashes "$ADJ_RUN"
adj_expect_fail 'array where an object belongs'
grep -Fq 'NOT A JSON OBJECT: evidence/arm.json decoded as list' <<<"$ADJ_OUTPUT" \
  || fail_test 'a JSON array was printed as valid'
grep -Fq 'ADJUDICATION_FAIL: evidence/arm.json decoded as list' <<<"$ADJ_OUTPUT" \
  || fail_test 'a JSON array was accepted by the verdict checks'
pass_case

adj_make_fixture "$ADJ_RUN"
printf '42\n' >"$ADJ_RUN/control/shutdown_frames.json"
adj_expect_fail 'scalar where an object belongs'
grep -Fq 'NOT A JSON OBJECT: control/shutdown_frames.json decoded as int' \
  <<<"$ADJ_OUTPUT" || fail_test 'a JSON scalar was printed as valid'
grep -Fq 'ADJUDICATION_FAIL: control/shutdown_frames.json decoded as int' \
  <<<"$ADJ_OUTPUT" || fail_test 'a JSON scalar was accepted by the verdict checks'
pass_case

# --- a real surviving ardurover process must be caught -----------------------
# Proves the pattern matches a live process, which a homoglyph never would.
adj_make_fixture "$ADJ_RUN"
# Short-lived on purpose. The helper is invoked immediately, and a longer
# sleep would leave an ardurover-matching orphan behind an interrupted suite
# run, failing the NEXT run's passing-fixture case for no real reason.
ADJ_FAKE="$TEST_TMP/ardurover"
printf '#!/bin/sh\nsleep 5\n' >"$ADJ_FAKE"
chmod +x "$ADJ_FAKE"
# Output discarded: the fake's own shell announces its killed sleep child.
"$ADJ_FAKE" >/dev/null 2>&1 &
ADJ_FAKE_PID=$!
# Dropped from the job table: bash announces a signalled job on its own stderr
# when it reaps one, which no redirection around the kill can capture.
disown "$ADJ_FAKE_PID" 2>/dev/null || true
adj_kill_fake() {
  if [ -n "${ADJ_FAKE_PID:-}" ] && kill -0 "$ADJ_FAKE_PID" 2>/dev/null; then
    pkill -P "$ADJ_FAKE_PID" 2>/dev/null || true
    kill "$ADJ_FAKE_PID" 2>/dev/null || true
    local waited=0
    while kill -0 "$ADJ_FAKE_PID" 2>/dev/null && [ "$waited" -lt 50 ]; do
      sleep 0.1
      waited=$((waited + 1))
    done
  fi
}
trap 'adj_kill_fake; rm -rf "$TEST_TMP"' EXIT
sleep 0.2
set +e
ADJ_OUTPUT="$(bash "$ADJUDICATE" "$ADJ_RUN" 2>&1)"
ADJ_RC=$?
set -e
adj_kill_fake
trap 'rm -rf "$TEST_TMP"' EXIT
[ "$ADJ_RC" -ne 0 ] \
  || fail_test 'adjudication passed with a live ardurover process'
grep -Fq 'SURVIVING ardurover' <<<"$ADJ_OUTPUT" \
  || fail_test 'live ardurover process was not reported'
grep -Fq 'a conflicting process survived' <<<"$ADJ_OUTPUT" \
  || fail_test 'surviving process did not fail the adjudication'
pass_case


printf 'PASS cases=%d\n' "$CASE_COUNT"
