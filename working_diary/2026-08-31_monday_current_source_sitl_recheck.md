# Monday 31/08/2026 - Current-source SITL recheck

**PRE-DIARY - PREPARED / NOT RUN. MONDAY STARTS DIRECTLY WITH THE FULL
SUPERVISED SITL ACCEPTANCE. NO LIVE-FCU OR HARDWARE APPROVAL CARRIES FORWARD.**

## Read first

1. this diary;
2. `working_diary/2026-08-28_friday_test_b_source_verifier_repair.md`;
3. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`;
4. `tools/live_dashboard_preflight.sh`;
5. `tools/sitl_digital_twin_runner.sh`;
6. `tools/sitl_operator_once.py`; and
7. `tools/sitl_digital_twin_adjudicate.sh`.

## Friday handoff

At preparation time, `main`, `origin/main` and the live remote main ref all
resolved to `da60c7dc421bdad4ec06a8e0950866e89bab4e4d`, with divergence `0/0`
and a clean worktree. Monday must certify the then-current state again; this
preparation-time value is not a substitute for that check.

The workstation already retains the complete decision-changing Pi evidence:

```text
/home/ghostzero/Desktop/pi_run_evidence/test_a_props_fitted_observation_20260828_175321
/home/ghostzero/Desktop/pi_run_evidence/test_b_functional_interrupted_20260828_155345
/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828
```

The Enhanced Test A copy includes the supervisor, manifests, six governed
logs, guard snapshot and JSON, telemetry, ready/final states and workstation
stop evidence. Its embedded `986`-parameter snapshot matches
`61406eee10c253daabfef4462ce0b3661be30b599bd7736909c5bff4e4b4943d`.
The rollback copy includes the MAVProxy transcript, `986`-parameter snapshot
and checksum; the snapshot matches
`a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`
and records `RC_OVERRIDE_TIME=3.000000`. No further Pi copy-back is required,
and the powered-off Pi must not be restarted solely to collect redundant
files. No retained Pi log can reconstruct the missing active Test A
slider-to-PWM correlation.

## Monday objective and boundary

The first work item is the complete current-source SITL acceptance and its
independent adjudication. Do not insert a standalone hardware, Pi, Test A or
Test B preflight before it. The SITL supervisor's own static preflight remains
mandatory and must not be bypassed.

This block is workstation-only. Keep the FCU, Pi, Herelink, propulsion battery
and ESCs off. It opens no serial device and grants no real-hardware authority.
The run remains **NOT RUN** until the operator gives fresh approval on Monday.

Do not edit runtime source before this acceptance. The open float32 steering
endpoint repair touches `tools/real_fcu_rc_command_bridge.py`, which this SITL
pipeline launches. If that repair or another change to the runner, dashboard
command path, bridge or shared supervisor lands after the pass, the acceptance
is stale for the changed path and must be rerun before it is relied on.

The prior complete acceptance took several minutes. Reserve one uninterrupted
work block and keep the built-in timeouts: readiness `45 s`, each operator gate
`300 s`, and shutdown-frame capture `10 s`. Do not shorten them.

## Pipeline S0 - repository guard

**Host + terminal:** Linux workstation, new one-shot terminal. Network access
is required only for the fetch and possible fast-forward.

**cwd + env:** repository root; no ROS setup or Python environment is needed.

**Prerequisites:** use branch `main`. A dirty, ahead or diverged repository is
a stop condition. A behind-only repository may fast-forward.

```bash
(
  set -euo pipefail
  cd /home/ghostzero/seal_ws/src/uvautoboat

  git fetch --prune origin || {
    echo 'SITL_ABORT=fetch-failed'
    exit 1
  }

  [ "$(git branch --show-current)" = main ] || {
    echo "SITL_ABORT=wrong-branch branch=$(git branch --show-current)"
    exit 1
  }

  [ -z "$(git status --porcelain)" ] || {
    echo 'SITL_ABORT=dirty-worktree'
    git status --short
    exit 1
  }

  read -r AHEAD BEHIND < <(
    git rev-list --left-right --count HEAD...origin/main
  )
  case "$AHEAD:$BEHIND" in
    0:0) ;;
    0:*)
      git pull --ff-only origin main
      echo 'SITL_RESTART=upstream-fast-forwarded reread-diary-and-sources'
      exit 3
      ;;
    *)
      echo "SITL_ABORT=branch-not-contiguous ahead=$AHEAD behind=$BEHIND"
      exit 1
      ;;
  esac

  read -r AHEAD BEHIND < <(
    git rev-list --left-right --count HEAD...origin/main
  )
  if [ "$AHEAD" -ne 0 ] || [ "$BEHIND" -ne 0 ]; then
    echo "SITL_ABORT=branch-moved-during-guard ahead=$AHEAD behind=$BEHIND"
    exit 1
  fi
  [ -z "$(git status --porcelain)" ]

  printf 'SITL_REPOSITORY=PASS revision=%s origin_main=%s worktree=clean\n' \
    "$(git rev-parse HEAD)" \
    "$(git rev-parse origin/main)"
)
```

**After:** paste the single `SITL_REPOSITORY=PASS` line. Stop if any
`SITL_ABORT` line appears. If `SITL_RESTART` appears, reread this diary and the
read-first sources from the updated worktree, then rerun S0; do not continue on
instructions read before the fast-forward. Passing S0 does not itself authorize
S1.

## Pipeline S1 - supervised SITL acceptance

**Host + terminal:** Linux workstation, new terminal `SITL-SUPERVISOR`.
This is a foreground, long-running command; leave it visible.

**cwd + env:** repository root. Do not manually source ROS or activate the
ArduPilot virtual environment; the supervisor establishes and checks ROS domain
`42`, `LOCALHOST` discovery and localhost-only mode.

**Prerequisites:** S0 passed on the same unchanged revision. The operator must
confirm that the FCU, Pi and Herelink remain off and that no unrelated Gazebo
session is running; the supervisor cannot establish those facts. Its static
preflight separately enforces its configured SITL/Rover, MAVProxy, MAVROS,
rosbridge, dashboard, command-bridge, evidence-recorder and physical-helper
process exclusions; TCP `5760`, `5762`, `8002`, `9090` and UDP `14600` being
free; at least `10 GiB` being free below `/home/ghostzero/Desktop`; and the
pinned ArduPilot checkout/binary, ROS Jazzy, MAVROS, rosbridge and required
Python dependencies remaining available. It must abort rather than displace a
governed owner. Keep one browser tab available for the exact loopback URL it
prints. Do not reuse remembered mapping or rail values; use the fresh bridge
marker and URL.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
export LIVE_DASHBOARD_LOG_ROOT=/home/ghostzero/Desktop
tools/live_dashboard_preflight.sh sitl
```

Expected early markers are:

```text
SITL_PREFLIGHT=PASS
SITL_PROCESS=READY
SITL_MAVPROXY=READY
SITL_MAVROS=READY
SITL_BRIDGE_GUARD=PASS
SITL_CAPTURE=READY
```

**Run + phase gates:** when the supervisor prints an operator command, use a
second new workstation terminal named `SITL-OPERATOR`. Copy the printed command
verbatim. It invokes
`/home/ghostzero/venv-ardupilot/bin/python` with the exact run directory.
Do not interrupt a one-shot command; reuse that terminal only after the command
returns its result.

1. Run the printed `safety-off` command.
2. Require `SITL_DISARMED_READY=PASS` and `SITL_WEB=READY`.
3. Open the exact printed loopback URL in one browser tab. After `Connected`,
   click `Neutral Now` once to emit the disabled frame.
4. Require `SITL_BROWSER=READY` and `SITL_SESSION=READY`.
5. Run the printed `arm` command. Never force-arm.
6. Tick the bench-condition box and hold `Apply` at steering `+0.10`, throttle
   `0.08` until the supervisor advances.
7. Release `Apply` and leave both requested axes at zero.
8. Hold `Apply` at steering `-0.04`, throttle `0.09` until it advances.
9. Release `Apply`, then press `EMERGENCY STOP` once in Mission Control or via
   the header/footer E-STOP badge. The FCU Bench panel has no E-Stop button.
10. Run the printed `disarm` command.
11. Wait for automatic teardown; do not press Ctrl+C on the successful path.

**Stop conditions:** any failed phase, unexpected child exit, missing evidence,
or timeout ends the attempt. Preserve the printed run directory and do not
start an improvised same-day retry. If manual interruption is unavoidable,
press Ctrl+C once in `SITL-SUPERVISOR` and wait for its governed teardown.

A successful supervisor path ends with all of:

```text
SITL_ACCEPTANCE=COMPLETE teardown=pending
SITL_VERDICT=PASS
SITL_LOGS=/home/ghostzero/Desktop/sitl_digital_twin_<stamp>
SITL_SUPERVISOR_EXIT status=0 trigger=exit signal=none stop_phase=acceptance-complete failed_phase=none cleanup_rc=0 finalize_rc=0
```

**After:** copy the exact `SITL_LOGS=` path. Do not select a run by newest-file
discovery and do not continue to S2 until the supervisor has exited.

## Pipeline S2 - independent adjudication

**Host + terminal:** Linux workstation, new one-shot terminal after S1 exits.

**cwd + env:** repository root; set `RUN` to the exact absolute `SITL_LOGS=`
path from S1. The adjudicator is read-only and does not start, stop or signal
any process.

```bash
(
  set -euo pipefail
  cd /home/ghostzero/seal_ws/src/uvautoboat

  RUN='/home/ghostzero/Desktop/sitl_digital_twin_YYYYMMDD_HHMMSS'
  ADJ_LOG="/home/ghostzero/Desktop/$(basename "$RUN")_adjudication.log"

  [ -d "$RUN" ] || {
    echo "SITL_ADJUDICATION_ABORT=run-missing path=$RUN"
    exit 1
  }
  [ ! -e "$ADJ_LOG" ] || {
    echo "SITL_ADJUDICATION_ABORT=log-exists path=$ADJ_LOG"
    exit 1
  }

  set +e
  tools/sitl_digital_twin_adjudicate.sh "$RUN" | tee "$ADJ_LOG"
  PIPELINE_STATUS=("${PIPESTATUS[@]}")
  set -e
  ADJ_RC="${PIPELINE_STATUS[0]}"
  TEE_RC="${PIPELINE_STATUS[1]}"
  [ "$TEE_RC" -eq 0 ] || {
    echo "SITL_ADJUDICATION_ABORT=log-write-failed rc=$TEE_RC path=$ADJ_LOG"
    exit "$TEE_RC"
  }
  [ "$ADJ_RC" -eq 0 ] || exit "$ADJ_RC"
  test -s "$ADJ_LOG" || {
    echo "SITL_ADJUDICATION_ABORT=log-empty path=$ADJ_LOG"
    exit 1
  }

  echo "SITL_ADJUDICATION_LOG=$ADJ_LOG"
)
```

Replace `YYYYMMDD_HHMMSS` with the exact stamp from S1 before running.
Acceptance requires these lines and a final status of zero:

```text
STOP_ORDER_CHECK=PASS order=dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl
EVIDENCE_HASHES_CHECKED=10
CONTROL_CROSSCHECK=PASS
VERDICT_CHECK=PASS
TEARDOWN_CHECK=PASS
SITL_POSTRUN_PORTS=FREE
SITL_POSTRUN_PROCESSES=FREE
SITL_ADJUDICATION=PASS
```

**After:** paste the S0 repository marker, the S1 final markers and run path,
and the S2 lines above. Keep both the run directory and external adjudication
log. Only that complete set can close Monday's current-source SITL gate.

## Acceptance rule

`SITL_VERDICT=PASS` without `SITL_ADJUDICATION=PASS` is incomplete. A failed or
interrupted run remains failed or interrupted; do not promote operator
impressions into acceptance. This proves only the simulator/dashboard command
loop and teardown on the recorded revision. It does not prove a Pi, real FCU,
Herelink, propulsion or props-fitted path.

### Next steps

1. On Monday, read this diary and run only S0 after giving fresh approval.
2. If S0 passes, approve S1 separately; complete S1 and S2 before other work.
3. Record the exact revision, run directory, verdict, adjudication and teardown
   result in this same diary.
4. Freeze the tested runtime path after a pass, or explicitly reopen and rerun
   SITL if the float32 endpoint repair or another relevant source change lands.
5. Keep Test B formal acceptance and all real-hardware activity outside this
   SITL-only block and subject to fresh declarations and approvals.

## Live result - 31/08/2026

The supervised acceptance ran on clean `main` revision
`3ca4c9bd16414d37506b62ce9fa5b8dad55a3719`, with `origin/main` at the
same commit. Its retained run is:

```text
run=/home/ghostzero/Desktop/sitl_digital_twin_20260831_150946
adjudication=/home/ghostzero/Desktop/sitl_digital_twin_20260831_150946_adjudication.log
```

The operator completed the safety-off, disabled-frame, arm, positive demand,
neutral release, negative demand, E-Stop and disarm sequence. The supervisor
then emitted `SITL_ACCEPTANCE=COMPLETE`, `SITL_VERDICT=PASS` and
`SITL_SUPERVISOR_EXIT status=0` with `cleanup_rc=0` and `finalize_rc=0`.
`verdict.json` records `session_complete=true`, `verdict=PASS`, `missing=[]`
and `capture_fault=null`.

Independent adjudication checked all ten evidence hashes, the control
cross-check and the exact stop order
`dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl`. It also confirmed
the teardown, all governed host ports free, all governed processes absent and
ended `SITL_ADJUDICATION=PASS`. This closes the acceptance gate for the exact
recorded revision `3ca4c9b`.

## Post-acceptance endpoint repair

After that pass, the separately authorised float32 endpoint repair changed
`tools/real_fcu_rc_command_bridge.py`. A red test first reproduced that the
browser's exact steering endpoints arrive through `sensor_msgs/msg/Joy` as
approximately `+/-0.20000000298` and are rejected by the bridge's exact
`+/-0.20` comparison. A second red regression then reproduced the same defect
when legal tunable throttle maxima such as `0.10` round upward in float32. The
narrow repair normalizes only the exact float32 encoding of each configured
command endpoint. It does not raise `max_steering=0.20` or
`max_throttle=0.12`; the next adjacent float32, a materially larger request and
a tiny negative throttle remain rejected without replacing the last accepted
command.
The focused bridge suite passes `36` tests after the change, and the bundle
manifest is repinned to the repaired bridge bytes.

The complete offline verification on the repaired working tree passed:

```text
Pi lifecycle:             PASS
live-dashboard preflight: PASS cases=25
real-FCU helper suite:    PASS cases=34
SITL runner suite:        PASS cases=41
FCU-to-VRX shell suite:   PASS cases=23 runtime=not-started
Python tools:             125 passed
Node dashboard:           tests=80 pass=80 fail=0
bundle manifest:          4/4 OK
git diff --check:         clean
```

This post-pass source edit reopens the revision-specific SITL gate for the
working tree. The `3ca4c9b` result remains valid evidence for that recorded
revision, but it must not be represented as acceptance of the repaired bytes.
After the repair is committed and pushed, run S0, S1 and S2 again before a
real-FCU pipeline relies on current-source SITL acceptance.

## One-sided propulsion finding and remaining gate

Source tracing found no one-sided publication defect. The dashboard publishes
one paired steering/throttle `Joy` command, and the bridge writes the resolved
steering and throttle RC channels together in one `OverrideRCIn` message.
ArduRover's skid mixer then forms left output from throttle plus steering and
right output from throttle minus steering. A steering-heavy request can
therefore drive one side to the bottom-neutral rail while the other side rises.
The earlier measured `0.05/0.04` request produced `911/800 us`, which is
consistent with that mixer behavior rather than proof of a missing second
command.

The reported lack of rotation at straight throttle `0.12` remains
unexplained by retained active feedback. Straight throttle introduces no
mixer differential, but the evidence does not establish either ESC's physical
start threshold. Do not raise the dashboard throttle authority or change
`MOT_THR_MIN` from this observation. A future threshold measurement is a
separate, freshly approved, propellers-removed hardware calibration. It must
retain the requested pair, measured RC input, both servo-output PWM values and
the operator-observed start point for each side. The existing feedback capture
helper can retain the machine correlation, but it is not automatically added
to the established Test A lifecycle by this repair.

`RC_OVERRIDE_TIME` remains at its restored live value `3.0`. Any later
demand-enabled real-FCU run requires its own approval, live `0.5` readback and
fresh pinned snapshot. No hardware approval or physical-state declaration was
used or carried forward during this workstation-only work.

## Post-repair current-source acceptance

After the endpoint repair landed on `main`, the complete supervised SITL
acceptance was rerun on clean revision
`bba195b19a0f06a874bfbcbcbbd1621524cbce60`. The run manifest records
`origin_main` at the same commit and `worktree=clean`. The retained paths are:

```text
run=/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839
adjudication=/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log
```

The operator completed safety-off, the disabled browser frame, arm, positive
demand, neutral release, negative demand, E-Stop and disarm. The supervisor
then emitted `SITL_ACCEPTANCE=COMPLETE`, `SITL_VERDICT=PASS` and
`SITL_SUPERVISOR_EXIT status=0` with `cleanup_rc=0` and `finalize_rc=0`.
`verdict.json` records `session_complete=true`, `verdict=PASS`, `missing=[]`
and `capture_fault=null`.

Independent adjudication checked all ten evidence hashes, the control
cross-check and the exact stop order
`dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl`. It also confirmed
the teardown, all governed ports free, all governed process patterns absent and
ended `SITL_ADJUDICATION=PASS`. This closes the current-source SITL/dashboard
command-ingress acceptance gate for exact revision `bba195b`.

This is simulator-only evidence. No Pi, real FCU, propulsion hardware or
on-water path participated, and no physical approval carries forward. The
regenerated real-FCU bundle still requires a separately verified transfer and
checksum before any later Pi use. A later relevant source, pinned runtime
artifact or acceptance-environment change reopens this exact-run gate.
