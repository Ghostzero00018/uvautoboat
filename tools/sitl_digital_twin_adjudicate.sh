#!/usr/bin/env bash
#
# Post-run adjudication for a SITL digital-twin acceptance run.
#
# Reads one completed run directory, prints the evidence a reviewer needs, and
# decides independently whether the run passed. It exists as a file rather than
# as a block of text to paste: this is the last step of an unrepeatable run, and
# a quoting slip, an indented heredoc terminator or a homoglyph in a process
# pattern would only be discovered once the run is already over.
#
# Usage:
#   tools/sitl_digital_twin_adjudicate.sh /absolute/path/to/sitl_digital_twin_<stamp>
#
# The run directory is an argument on purpose. There is no "most recent run"
# discovery, because adjudicating the wrong directory is worse than adjudicating
# none, and a stale run that happens to be complete would read as a pass.
#
# Read-only by contract: this script never writes inside the run directory and
# never starts, stops or signals a process. It only observes.
#
# Exit status is 0 when it prints SITL_ADJUDICATION=PASS and 1 otherwise. It
# always prints exactly one of those two lines, as its final line, even when an
# artifact is missing - diagnostics keep gathering past the first fault so a
# failed run is adjudicated in one pass rather than one fault at a time.

set -uo pipefail

# --- contract constants ------------------------------------------------------
#
# ASCII only, and pinned by the focused suite. A Cyrillic homoglyph in a process
# pattern never matches, so the conflict check would report a clean host while
# the simulator was still running - the exact failure this check exists to catch.

ADJ_TCP_PORTS=(5760 5762 8002 9090)
ADJ_UDP_PORTS=(14600)

ADJ_CONFLICT_PATTERNS=(
  ardurover
  sim_vehicle.py
  mavproxy.py
  MAVProxy
  mavros_node
  real_fcu_rc_command_bridge.py
  sitl_digital_twin_evidence.py
  sitl_operator_once.py
  rosbridge
  serve_dashboard.py
  real_fcu_digital_twin_workstation.sh
  real_fcu_digital_twin_pi.sh
)

ADJ_REQUIRED_JSON=(
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

ADJ_LOG_HEAD_LINES=120
ADJ_LOG_TAIL_LINES=120
ADJ_LOG_FULL_LIMIT=240

ADJ_RESULT=0

adj_fail() {
  printf 'ADJUDICATION_FAIL: %s\n' "$*"
  ADJ_RESULT=1
}

adj_section() {
  printf '===== %s =====\n' "$*"
}

# --- argument handling -------------------------------------------------------

adj_usage() {
  printf 'usage: %s /absolute/path/to/sitl_digital_twin_<stamp>\n' "${0##*/}" >&2
}

if [ "$#" -ne 1 ]; then
  adj_usage
  printf 'SITL_ADJUDICATION=FAIL\n'
  exit 1
fi

RUN="$1"

case "$RUN" in
  /*) ;;
  *)
    printf 'ABORT: run directory must be an absolute path: %s\n' "$RUN" >&2
    adj_usage
    printf 'SITL_ADJUDICATION=FAIL\n'
    exit 1
    ;;
esac

if [ ! -d "$RUN" ]; then
  printf 'ABORT: not a directory: %s\n' "$RUN" >&2
  printf 'SITL_ADJUDICATION=FAIL\n'
  exit 1
fi

printf 'SITL_ADJUDICATION_RUN=%s\n' "$RUN"

# --- required JSON artifacts -------------------------------------------------

for relative in "${ADJ_REQUIRED_JSON[@]}"; do
  adj_section "$relative"
  if [ ! -f "$RUN/$relative" ]; then
    printf 'MISSING: %s\n' "$relative"
    adj_fail "missing artifact: $relative"
    continue
  fi
  if ! /usr/bin/python3 - "$RUN/$relative" "$relative" <<'PYJSON'
import json
import sys

path, label = sys.argv[1], sys.argv[2]
try:
    value = json.loads(open(path, encoding="utf-8").read())
except ValueError as exc:
    print("INVALID JSON: " + label + ": " + str(exc))
    sys.exit(1)
# json.tool would happily print null, a bare array or a number. Every required
# artifact is an object, and anything else must fail here rather than reach a
# check that reads it as "nothing to validate".
if not isinstance(value, dict):
    print("NOT A JSON OBJECT: " + label + " decoded as " + type(value).__name__)
    sys.exit(1)
print(json.dumps(value, indent=4))
PYJSON
  then
    adj_fail "not a readable JSON object: $relative"
  fi
done

# --- supervisor log ----------------------------------------------------------

adj_section 'supervisor.log'
if [ -f "$RUN/supervisor.log" ]; then
  cat "$RUN/supervisor.log" || adj_fail 'supervisor.log unreadable'
else
  printf 'MISSING: supervisor.log\n'
  adj_fail 'missing supervisor.log'
fi

# --- manifest ----------------------------------------------------------------

adj_section 'manifest/commands.tsv'
if [ -f "$RUN/manifest/commands.tsv" ]; then
  cat "$RUN/manifest/commands.tsv" || adj_fail 'manifest/commands.tsv unreadable'
else
  printf 'MISSING: manifest/commands.tsv\n'
  adj_fail 'missing manifest/commands.tsv'
fi

adj_section 'manifest inventory'
if [ -d "$RUN/manifest" ]; then
  while IFS= read -r -d '' file; do
    printf '%s\n' "${file#"$RUN"/}"
  done < <(find "$RUN/manifest" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)
else
  printf 'MISSING: manifest/\n'
  adj_fail 'missing manifest directory'
fi

# --- logs --------------------------------------------------------------------

adj_section 'log inventory'
if [ -d "$RUN/logs" ]; then
  while IFS= read -r -d '' file; do
    printf '%s %s\n' "$(wc -l <"$file")" "${file#"$RUN"/}"
  done < <(find "$RUN/logs" -type f -print0 | LC_ALL=C sort -z)

  while IFS= read -r -d '' file; do
    lines="$(wc -l <"$file")"
    adj_section "${file#"$RUN"/} ($lines lines)"
    if [ "$lines" -le "$ADJ_LOG_FULL_LIMIT" ]; then
      cat "$file" || adj_fail "log unreadable: ${file#"$RUN"/}"
    else
      sed -n "1,${ADJ_LOG_HEAD_LINES}p" "$file"
      printf '===== middle omitted; final %s lines follow =====\n' "$ADJ_LOG_TAIL_LINES"
      tail -n "$ADJ_LOG_TAIL_LINES" "$file"
    fi
  done < <(find "$RUN/logs" -type f -print0 | LC_ALL=C sort -z)
else
  printf 'MISSING: logs/\n'
  adj_fail 'missing logs directory'
fi

# --- captures ----------------------------------------------------------------

adj_section 'capture line counts'
adj_capture_count=0
while IFS= read -r -d '' file; do
  printf '%s %s\n' "$(wc -l <"$file")" "${file#"$RUN"/}"
  adj_capture_count=$((adj_capture_count + 1))
done < <(find "$RUN/captures" -type f -name '*.jsonl' -print0 2>/dev/null | LC_ALL=C sort -z)
if [ "$adj_capture_count" -eq 0 ]; then
  printf 'MISSING: captures/*.jsonl\n'
  adj_fail 'no capture files'
fi

# --- retained hashes ---------------------------------------------------------

adj_section 'retained hashes'
adj_hashed=0
while IFS= read -r -d '' file; do
  sha256sum "$file" || adj_fail "cannot hash: ${file#"$RUN"/}"
  adj_hashed=$((adj_hashed + 1))
done < <(
  find "$RUN/captures" "$RUN/evidence" "$RUN/control" "$RUN/logs" "$RUN/manifest" \
    -type f -print0 2>/dev/null | LC_ALL=C sort -z
)
if [ -f "$RUN/supervisor.log" ]; then
  sha256sum "$RUN/supervisor.log" || adj_fail 'cannot hash supervisor.log'
fi
if [ "$adj_hashed" -eq 0 ]; then
  adj_fail 'no retained artifacts to hash'
fi

# --- independent verdict checks ----------------------------------------------
#
# Deliberately recomputed here rather than trusting the run's own summary: a run
# that mis-adjudicates itself is precisely what this step is meant to catch. The
# expected stop order is written out in full for the same reason.

adj_section 'verdict checks'
if /usr/bin/python3 - "$RUN" "${ADJ_REQUIRED_JSON[@]}" <<'PYTHON'
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1]).resolve()
# Taken from the shell array rather than restated, so the printed set and the
# validated set cannot drift apart.
REQUIRED_JSON = tuple(sys.argv[2:])

failures = []

# Mirrors PHASE_FILES in tools/sitl_digital_twin_evidence.py. Written out rather
# than imported so a change to the recorder cannot silently relax the check the
# recorder is being audited by.
PHASE_FILES = (
    "startup.json",
    "ready_disarmed.json",
    "browser_ready.json",
    "arm.json",
    "positive.json",
    "release.json",
    "negative.json",
    "estop.json",
    "disarm.json",
    "teardown.json",
)
EXPECTED_HASH_KEYS = {"evidence/" + name for name in PHASE_FILES}

EXPECTED_STOP_ORDER = [
    "dashboard",
    "rosbridge",
    "bridge",
    "evidence",
    "mavros",
    "mavproxy",
    "sitl",
]

EXPECTED_FRAME_COUNT = 3


def load_object(relative):
    """
    Decode a required artifact, which must be a JSON object.

    None is returned only on failure. A decoded JSON null is rejected here
    rather than handed back, so None never doubles as "the file said null" -
    that ambiguity let a null artifact skip every check that came after it.
    """
    path = run_dir / relative
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        failures.append("missing " + relative)
        return None
    except OSError as exc:
        failures.append("unreadable " + relative + ": " + str(exc))
        return None
    try:
        value = json.loads(raw)
    except ValueError as exc:
        failures.append("invalid JSON in " + relative + ": " + str(exc))
        return None
    if not isinstance(value, dict):
        failures.append(
            relative + " decoded as " + type(value).__name__
            + ", not a JSON object"
        )
        return None
    return value


def require_zero_int(value, label):
    """
    Require integer zero, not merely something equal to it.

    Python treats False == 0 and 0.0 == 0 as true, so a plain equality test
    accepts a boolean or a float where the supervisor writes an int. isinstance
    is no good either, because bool subclasses int - the exact type is the check.
    """
    if type(value) is not int or value != 0:
        failures.append(label + " is " + repr(value) + ", not integer 0")


def resolve_inside_run(relative):
    """Return the path for a hash-map key, or None if it escapes the run."""
    if not isinstance(relative, str) or not relative:
        return None
    if relative.startswith("/") or "\\" in relative:
        return None
    parts = Path(relative).parts
    if any(part in ("..", "") for part in parts):
        return None
    candidate = (run_dir / relative).resolve()
    try:
        candidate.relative_to(run_dir)
    except ValueError:
        return None
    return candidate


def frame_count(payload, label):
    """Require exactly the contracted frame count, and report what was found."""
    frames = payload.get("frames")
    if not isinstance(frames, list):
        failures.append(label + " carries no frames list")
        return
    if len(frames) != EXPECTED_FRAME_COUNT:
        failures.append(
            label + " holds " + str(len(frames)) + " frames, not "
            + str(EXPECTED_FRAME_COUNT)
        )


# Every required artifact is decoded and shape-checked, not only the five read
# in depth below: a null phase artifact is just as fatal as a null verdict.
documents = {relative: load_object(relative) for relative in REQUIRED_JSON}

verdict = documents.get("evidence/verdict.json")
teardown = documents.get("evidence/teardown.json")
runtime_file = documents.get("control/teardown_runtime.json")
shutdown_file = documents.get("control/shutdown_frames.json")
release_file = documents.get("control/disarm_release_frames.json")

# A capture fault forces teardown_pass false in the recorder, so its mere
# presence contradicts any PASS the run claims for itself.
if (run_dir / "control" / "capture_fault.json").exists():
    failures.append("control/capture_fault.json exists; the capture faulted")

if verdict is not None:
    if verdict.get("verdict") != "PASS":
        failures.append("verdict is " + repr(verdict.get("verdict")) + ", not 'PASS'")
    if verdict.get("session_complete") is not True:
        failures.append("session_complete is not true")
    missing = verdict.get("missing")
    if missing != []:
        failures.append("verdict reports missing evidence: " + repr(missing))
    require_zero_int(verdict.get("cleanup_rc"), "verdict cleanup_rc")
    if verdict.get("capture_fault") is not None:
        failures.append(
            "verdict capture_fault is " + repr(verdict.get("capture_fault"))
        )

    stored = verdict.get("evidence_sha256")
    if not isinstance(stored, dict):
        failures.append("verdict carries no evidence_sha256 map")
    else:
        keys = set(stored)
        # An arbitrary non-empty subset would let a run drop nine of the ten
        # phase artifacts and still be hashed clean.
        for absent in sorted(EXPECTED_HASH_KEYS - keys):
            failures.append("evidence_sha256 omits " + absent)
        for extra in sorted(keys - EXPECTED_HASH_KEYS):
            failures.append("evidence_sha256 carries unexpected key " + repr(extra))
        for relative in sorted(keys):
            path = resolve_inside_run(relative)
            if path is None:
                failures.append("evidence_sha256 key escapes the run: " + repr(relative))
                continue
            if not path.is_file():
                failures.append("hashed artifact vanished: " + relative)
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest != stored[relative]:
                failures.append(
                    "hash mismatch for " + relative + ": stored "
                    + str(stored[relative]) + ", found " + digest
                )
        print("EVIDENCE_HASHES_CHECKED=" + str(len(keys)))

if teardown is not None:
    if teardown.get("pass") is not True:
        failures.append("teardown pass is not true")
    require_zero_int(teardown.get("cleanup_rc"), "teardown cleanup_rc")
    if teardown.get("capture_fault") is not None:
        failures.append(
            "teardown capture_fault is " + repr(teardown.get("capture_fault"))
        )
    if verdict is not None:
        if teardown.get("cleanup_rc") != verdict.get("cleanup_rc"):
            failures.append("verdict and teardown disagree on cleanup_rc")
        if teardown.get("capture_fault") != verdict.get("capture_fault"):
            failures.append("verdict and teardown disagree on capture_fault")

    runtime = teardown.get("runtime")
    if not isinstance(runtime, dict):
        failures.append("teardown carries no runtime object")
    else:
        require_zero_int(runtime.get("cleanup_rc"), "runtime cleanup_rc")
        if runtime.get("children_stopped") is not True:
            failures.append("children_stopped is not true")
        if runtime.get("ports_free") is not True:
            failures.append("ports_free is not true")
        order = runtime.get("stop_order")
        if order != EXPECTED_STOP_ORDER:
            failures.append("stop_order mismatch: " + repr(order))
        else:
            print("STOP_ORDER_CHECK=PASS order=" + ",".join(EXPECTED_STOP_ORDER))
        # The embedded copy is a summary; the control file is the artifact the
        # supervisor actually wrote. They must not diverge.
        if runtime_file is not None and runtime_file != runtime:
            failures.append(
                "control/teardown_runtime.json disagrees with the embedded runtime"
            )

    if shutdown_file is not None:
        if teardown.get("shutdown_frames") != shutdown_file:
            failures.append(
                "control/shutdown_frames.json disagrees with the embedded frames"
            )

if runtime_file is not None:
    # Checked in its own right: two copies that agree with each other can still
    # both carry a boolean or float where an integer status belongs.
    require_zero_int(runtime_file.get("cleanup_rc"), "control runtime cleanup_rc")

if shutdown_file is not None:
    frame_count(shutdown_file, "control/shutdown_frames.json")
if release_file is not None:
    frame_count(release_file, "control/disarm_release_frames.json")

for failure in failures:
    print("ADJUDICATION_FAIL: " + failure)

if failures:
    sys.exit(1)

print("CONTROL_CROSSCHECK=PASS")
print("VERDICT_CHECK=PASS")
print("TEARDOWN_CHECK=PASS")
sys.exit(0)
PYTHON
then
  :
else
  ADJ_RESULT=1
fi

# --- host state --------------------------------------------------------------
#
# The run claims the ports were free at teardown. This asks the host now, so a
# child that outlived the supervisor is caught rather than attested away.

adj_section 'host ports'
adj_ports_busy=0
adj_ss_ok=1
for port in "${ADJ_TCP_PORTS[@]}"; do
  if ! state="$(ss -H -ltn "sport = :$port" 2>&1)"; then
    printf 'ss failed for TCP %s: %s\n' "$port" "$state"
    adj_ss_ok=0
    continue
  fi
  if [ -n "$state" ]; then
    printf 'TCP %s OCCUPIED: %s\n' "$port" "$state"
    adj_ports_busy=1
  else
    printf 'TCP %s free\n' "$port"
  fi
done
for port in "${ADJ_UDP_PORTS[@]}"; do
  if ! state="$(ss -H -uln "sport = :$port" 2>&1)"; then
    printf 'ss failed for UDP %s: %s\n' "$port" "$state"
    adj_ss_ok=0
    continue
  fi
  if [ -n "$state" ]; then
    printf 'UDP %s OCCUPIED: %s\n' "$port" "$state"
    adj_ports_busy=1
  else
    printf 'UDP %s free\n' "$port"
  fi
done

if [ "$adj_ss_ok" -ne 1 ]; then
  # An uninspectable socket table is not evidence of a clean host.
  adj_fail 'socket inspection failed; port state unknown'
elif [ "$adj_ports_busy" -ne 0 ]; then
  adj_fail 'a Block B port remains occupied'
else
  printf 'SITL_POSTRUN_PORTS=FREE\n'
fi

# --- surviving processes -----------------------------------------------------
#
# The patterns live in this file, so this script's own argv is just its path and
# the run directory. Interpolating them into a wrapper's command line would make
# the check match itself and report a conflict on every clean run.

# This process and its ancestors are excluded. A shell that merely mentions a
# pattern on its command line - the suite that runs this helper, an editor, a
# wrapper - is not a surviving simulator, and counting it would report a
# conflict on every clean run. A genuine survivor is never our own ancestor.
adj_self_pids() {
  local pid=$$ parent
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
    printf ' %s' "$pid"
    parent="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$parent" ] || break
    [ "$parent" != "$pid" ] || break
    pid="$parent"
  done
  printf ' '
}

ADJ_SELF_PIDS="$(adj_self_pids) "

adj_section 'surviving processes'
adj_processes_found=0
adj_pgrep_ok=1
for pattern in "${ADJ_CONFLICT_PATTERNS[@]}"; do
  output="$(pgrep -af -- "$pattern")"
  status="$?"
  case "$status" in
    0)
      foreign=''
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        pid="${line%% *}"
        case "$ADJ_SELF_PIDS" in
          *" $pid "*) continue ;;
        esac
        foreign="$foreign$line
"
      done <<<"$output"
      if [ -n "$foreign" ]; then
        printf 'SURVIVING %s:\n%s' "$pattern" "$foreign"
        adj_processes_found=1
      else
        printf 'absent %s (matched only this adjudication process tree)\n' "$pattern"
      fi
      ;;
    1)
      printf 'absent %s\n' "$pattern"
      ;;
    *)
      printf 'pgrep failed for %s (status %s)\n' "$pattern" "$status"
      adj_pgrep_ok=0
      ;;
  esac
done

if [ "$adj_pgrep_ok" -ne 1 ]; then
  adj_fail 'process inspection failed; host state unknown'
elif [ "$adj_processes_found" -ne 0 ]; then
  adj_fail 'a conflicting process survived'
else
  printf 'SITL_POSTRUN_PROCESSES=FREE\n'
fi

# --- single final line -------------------------------------------------------

if [ "$ADJ_RESULT" -eq 0 ]; then
  printf 'SITL_ADJUDICATION=PASS\n'
  exit 0
fi

printf 'SITL_ADJUDICATION=FAIL\n'
exit 1
