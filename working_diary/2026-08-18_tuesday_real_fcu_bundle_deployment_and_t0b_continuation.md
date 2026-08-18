# Tuesday 18/08/2026 - Real-FCU bundle deployment and T0b continuation

**PRE-DIARY - NOT STARTED.** This is the sole 18/08/2026 working diary. It
continues the unfinished 17/08 sequence at D1; it does not reopen completed
source blocks, Block C or D0.

The pre-edit repository baseline while drafting this scaffold is
`50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4`. This file does not predict the
commit that contains the 17/08 close-out or this scaffold. At day start,
certify the actual pushed revision and require this baseline to remain its
ancestor.

## Established state

- Blocks B1, B2, B3a and B3b plus the capture-helper change are landed and
  focused-test green. The last commit touching a non-Markdown tracked file is
  `ea8429daab7b7e7c1ba1234589b9899a7135c83c`.
- Block C passed on 17/08/2026 at
  `/home/ghostzero/Desktop/sitl_digital_twin_20260817_162407`: full functional
  path, automatic teardown, final verdict and independent adjudication.
- D0 passed by operator attestation with the controller and Pi off. Connector
  seating and continuity passed for
  `Pi TXD (GPIO14) -> Cube SERIAL1 RX`; T0a is closed.
- D1 was approved on 17/08/2026 but ended before execution. No bundle transfer,
  deployed hash check, Pi `check`, probe, T0b artifact or D1 run directory is
  certified.
- T0b, T2a and T2b remain open. Block E has not started. No real-FCU parameter
  write or real-FCU helper command was issued.

## Read first

1. This file in full. Do not create another 18/08 diary.
2. The `Block C`, `Block D0` and end-of-day sections of
   `working_diary/2026-08-17_monday_real_fcu_dashboard_command_feedback_acceptance.md`.
3. `Board.md` from the T0a-T3b tier table through the 12/08 T0b mismatch and
   13/08 C2 result.
4. `tools/real_fcu_digital_twin_pi.sh`,
   `tools/real_fcu_rc_command_bridge.py`, both physical MAVROS allowlists,
   `config/real_fcu_digital_twin_bundle.sha256` and their focused suites.
5. Before any Block E proposal, also reread
   `tools/real_fcu_digital_twin_workstation.sh`,
   `tools/real_fcu_command_feedback_capture.py` and the dashboard FCU-bench
   README path.

## Block A - certify and prepare only

Only this read-only block is authorized at day start. It starts no simulator,
MAVROS, helper, browser or hardware session.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -14
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git merge-base --is-ancestor \
  50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4 HEAD
```

Apply this branch-state guard as one decision:

- fetch failure: stop and report;
- behind only: `git pull --ff-only`, then reread both dated diaries and restart
  certification;
- dirty, ahead or diverged: stop;
- baseline not an ancestor: stop;
- later clean synchronized `HEAD`: inspect every intervening commit before
  continuing.

If `HEAD` still equals the pre-edit baseline, the EOD documentation did not
land; stop before D1 rather than running from an unpublished handoff.

Re-verify the four bundle members and their manifest:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/real_fcu_digital_twin_pi.sh` | `30,852` bytes | `38e41d7dc8181e0f289d3b89c6e374e37cf020cf34e7b03f3cf955981a8efafd` |
| `tools/real_fcu_rc_command_bridge.py` | `40,144` bytes | `cf6668139999308b65a2f8af7ef70f74e226c9bd6c1ac82545bc6c1d0bbb59d7` |
| `config/mavros_real_fcu_closed_loop_plugins.yaml` | `129` bytes | `215293eab9d97e8da5a941d6cb8130351dfbafc07cca7656a766798a2a32b5fc` |
| `config/mavros_real_fcu_t0b_plugins.yaml` | `79` bytes | `5e6008314216785f2de53a617ffec72913e52acbef00645a417f19d7279e7a94` |

Also recheck the three operational artifact pins from the 17/08 diary, the
`13` operational pin surfaces, free disk, the six reserved ports and the scoped
process list. Reuse the landed suite results only if no covered source or
dependency changed: SITL helper `41` cases, physical helper `22` cases,
command bridge `26` tests and capture helper `13` tests.

Confirm the physical start state with the control box and Pi off: propellers
removed, propulsion isolated, hull restrained, hardware safety understood,
Herelink sticks and trims neutral, and QGroundControl plus the Herelink
available. Then stop and request explicit approval for Block D1 user-run.

## Block D1 - deploy once and run the non-actuating T0b probe

D1 requires fresh user-run approval after Block A. Every Pi command is run by
the operator in a real Pi terminal opened through Remmina; there is no
interactive SSH terminal. A workstation `scp` transfer is acceptable only as
the byte-preserving transport. Do not substitute reflowed terminal text.

Keep the propellers removed, propulsion isolated and the hull restrained. After
powering only the control electronics needed for the approved session, confirm
that the controller is disarmed and the hardware safety state is ON (safe);
leave that state unchanged. Do not release safety, arm, change mode or write a
parameter.

The deployment root is
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818`. It must not already
exist. Create its `tools/` and `config/` directories, transfer the four manifest
members plus `config/real_fcu_digital_twin_bundle.sha256`, and verify all four
hashes from that root before invoking the helper. Any existing destination,
transfer failure or hash mismatch stops D1 without overwrite or retry.

Run `check` first with no T0/T2 approval flags. It must end with:

```text
REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
```

Stop and paste the complete deployment and `check` output before the probe.
The handover must state host and terminal, absolute working directory, exact
source or activate lines, environment variables, prerequisites, stop
condition and exact output to return.

Only after the deployed bytes and `check` are accepted may the operator run
the foreground `probe` with one-shot values for
`REAL_FCU_T0A_COMPLETE=1`, `REAL_FCU_T0B_APPROVED=1`,
`REAL_FCU_START_DISARMED=1`, `REAL_FCU_SAFETY_ON=1`,
`REAL_FCU_PROPELLERS_REMOVED=1`, `REAL_FCU_HULL_RESTRAINED=1` and
`REAL_FCU_PROPULSION_ISOLATED=1`. Do not set either T2 approval flag. The
helper sources `/opt/ros/jazzy/setup.bash`, forces ROS domain `43`, starts only
the two-plugin MAVROS probe and never starts the bridge.

Required success markers are:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

Retain and copy back the exact printed run directory, including
`evidence/t0b.json`, `evidence/t0b_parameters.txt`, the state and safety
evidence, manifest and logs. Bind copy-back to that exact directory; do not use
a broad wildcard. The live artifact must resolve this controller's
`RCMAP_*`, `SERVO*_FUNCTION`, RC rails and servo rails. Simulator values and
the historical real-boat values are not substitutes.

A timeout, refused parameter response, missing mapping or rail, non-disarmed
state, safety failure, helper failure or cleanup failure ends D1 for the day.
Do not retry and do not write `BRD_SER1_RTSCTS` or any other parameter. Confirm
disarmed state and safety, power the controller and Pi down, preserve the logs
and document the blocker.

## Block E - only after D1 passes

Block E remains separately gated. T2a is a fresh neutral-only session using
`run-t2a`. It creates no browser-command subscription and accepts no
non-neutral demand; it still creates the guarded RC-override publisher and
publishes the controller's live trim values while armed. T2a must separately
verify that the observed outputs remain at those trims. It ends in a recorded
powered-down state. T2b is a second complete session only after
T2a is closed and recorded and separate T2b approval is granted. Never set
both T2 flags to bypass T2a. Do not start a physical session late in the
available window.

## Boundaries and fallback

- T1 is not authorized: no real-controller parameter write.
- No simulator and real-FCU supervisor overlap.
- No propeller-fitted, powered-thrust, static-propeller or on-water test.
- No manual unrecorded command path and no gate relaxation.
- If equipment, network, deployment, T0b evidence or time fails, retain the
  evidence, power down and use the remainder for documentation only.

## Wrap

Append results only to this file. Preserve the 17/08 diary and dated Board rows
as history. Record the pre-edit baseline while drafting; never predict the SHA
of a commit containing its own close-out text. Stage by explicit path, inspect
the staged content, run the repository checks and leave a clean synchronized
`HEAD == main == origin/main` before the day ends.

## 18/08/2026 execution record

The `PRE-DIARY - NOT STARTED` banner above records the imported scaffold state.
Execution began on 18/08/2026 under the block approvals recorded outside this
file. The pre-edit baseline for this appended record is
`003c778eefc9075d2d37806ed099312f27db8de8`; no commit containing this text is
predicted here.

### Block A result - PASS

Remote certification established a clean
`HEAD == main == origin/main == 003c778eefc9075d2d37806ed099312f27db8de8`
with divergence `0/0` and a clean worktree and index. The drafting baseline
`50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4` remained an ancestor, and `HEAD` was
later than that baseline, so all three intervening commits were inspected.
They are documentation-only: `25b76e1` adds the 17/08 close-out and this
scaffold, `0016f70` aligns pin-surface wording and adds a superseded banner,
and `003c778` corrects the T2a publisher description and the D1 safety-state
sequence. The last commit touching a non-Markdown tracked file remains
`ea8429daab7b7e7c1ba1234589b9899a7135c83c`, so the landed suite results stayed
reusable for unchanged covered surfaces.

The three operational artifact pins matched their recorded sizes and SHA-256
values, all four physical bundle members matched the Block A table, and the
manifest verified `4/4`. The `13` operational pin surfaces remained exactly `9`
helper-hash, `1` helper-size, `2` supervisor-hash and `1` supervisor-size.

Host inspection found TCP `5760`, `5762`, `8002`, `8080`, `9090` and UDP
`14600` free, and free disk above the `10 GB` floor. The canonical
conflict-pattern union across the five tracked arrays is `20` distinct
literals, and all `20` were absent. `tools/real_fcu_command_feedback_capture.py`
is covered by no conflict array, so it was checked separately and was also
absent. All pattern literals are ASCII, so no homoglyph can silently prevent a
match. Focused suites were re-run in the current environment at `41`, `22`,
`26` and `13` cases, and the shell, Python, JavaScript and both MAVROS
allowlist checks passed.

### Block D1 Gate 1 result - PASS

Deployment and `check` only; the probe was separately gated. The deployment
root `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818` did not exist
and was created once. Host identity, log root, serial presence, serial
read/write access, serial freedom and the three Pi conflict patterns were
confirmed before any transfer.

Block 2 emitted no `D1_STOP` and completed: both transfers ran and all five
members landed. The written stop condition was nevertheless met, because `scp`
requested password authentication, so progression to the deployed-hash and
`check` phase was held rather than the transfer being halted. Review
established that the Pi host key was already present in `known_hosts` from
13/08/2026, that it matched, that no unknown-host or changed-host-key prompt
occurred, and that authentication succeeded and all five members transferred.
The stop condition as written did not distinguish a routine password prompt
from an authentication failure or a changed host key. That is a handover
wording defect, not a security or transfer failure, and Gate 1 continued after
the wording was corrected. Key-based authentication is not configured between
the workstation and the Pi.

The deployed inventory was exactly five files. All five sizes matched
`30,852`, `40,144`, `129`, `79` and `422` bytes, the manifest file itself
matched `1d7ca17b84b986da813b4a842095b18801530574cba8e952a4a073608e29ed4b`, and
all four members verified against it. The helper's own bundle verification also
passed. `check` exited `0` with empty stderr and the exact final line
`[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`.

`check` validates the Pi environment but never opens the serial link; it tests
only existence, permissions and freedom. Gate 1 therefore certified the
deployed bytes and the Pi environment, and established nothing about the
Pi-to-controller link.

### Block D1 probe result - FAIL, operator-stopped, T0b not closed

The probe ran in the foreground on the Pi with the seven one-shot approval
flags and both T2 flags unset. Run directory:
`/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260818_155351`,
copied back to
`/home/ghostzero/Desktop/test_logs_folder/real_fcu_digital_twin_pi_20260818_155351`.

| Time | Offset | Event |
| --- | ---: | --- |
| 15:53:51 | `t+0.25 s` | `mavros-probe` started |
| 15:53:53 | `t+1.9 s` | `link[1000] opened successfully` |
| 15:53:54 | `t+2.9 s` | remote address `1.1`; `CON: Got HEARTBEAT, connected. FCU: ArduPilot` |
| 15:53:56 | `t+4.94 s` | first `VER: autopilot version service timeout` |
| 15:54:02 | `t+11.01 s` | version retries exhausted |
| 15:54:05 | `t+13.92 s` | first `mavros.param: PR: request list timeout` |
| 15:54:07 | `t+15.93 s` | parameter-list retries exhausted |
| 15:55:41 | `t+109.81 s` | operator stop requested |
| 15:55:41 | `t+110.30 s` | `REAL_FCU_PI_EXIT status=130 cleanup_rc=0` |

The serial endpoint opened and an ArduPilot heartbeat was received, which
establishes controller-to-Pi traffic at `57600` with correct framing. Two
distinct request-timeout classes then occurred. The `VER` errors include
`command plugin service call failed!`, and the T0b allowlist loads only
`sys_status` and `param`, so the command plugin was never present; those errors
therefore do not evidence a wire-level outbound failure. The three
`PR: request list timeout` messages come from the loaded `param` plugin and are
the direct evidence that parameter request and response was unavailable.

MAVROS emitted no further output for `93.9 s` between the exhausted parameter
retries and the operator stop. The probe was stopped roughly `70 s` before its
own ready deadline, so it did not time out, and whether the state gate would
have been satisfied within the remaining budget is not established.

`rfcu_pi_capture_t0b` was never reached, so no `evidence/t0b.json` and no
`evidence/t0b_parameters.txt` were created. T0b remains open. No parameter was
written, the bridge was never started, and Block E stayed closed. Cleanup
completed with `cleanup_rc=0`.

### Two source defects in the probe evidence path

Both were found while interpreting the retained artifact, and neither is
repaired here; no tracked source was changed on 18/08/2026.

1. `rfcu_pi_capture_topic` redirects `2>&1` into the evidence file, so any
   child diagnostic lands inside the YAML that
   `rfcu_pi_state_file_is_connected_disarmed` must parse. The retained
   `evidence/probe_connected_disarmed.yaml` holds a Python traceback ending in
   `KeyboardInterrupt`, raised while `ros2 topic echo` was still importing
   `numpy`. That traceback is the operator stop reaching the in-flight child,
   not a fault that preceded it.
2. `rfcu_pi_capture_topic` writes every attempt to the same path, so each
   iteration overwrites the previous one. Only the final interrupted attempt
   survived. The observed `connected` and `armed` values, and the contents of
   every earlier attempt, are therefore unrecoverable from this run.

The focused suite replaces `rfcu_pi_capture_topic` with a stub in two places,
so neither behaviour is covered by an existing test.

### Documentation follow-up

`Board.md` carries no 17/08/2026 or 18/08/2026 row and still frames the
bidirectional-link question as having two uneliminated candidates with T0a as
the first hardware step. D0 closed T0a on 17/08/2026 with connector seating and
end-to-end `Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity both passing, so a
physically unconnected conductor is no longer an open candidate. Runtime
outbound signalling, serial flow control and the controller's serial
configuration remain unresolved. That row is stale and is left unedited here.

### End-of-day state

The repository was clean and synchronized at
`003c778eefc9075d2d37806ed099312f27db8de8` when this record was opened; that is
the historical baseline, not the state while this entry is being written, which
carries this file as an uncommitted modification. The
deployment root exists on the Pi, is certified, and must be preserved; it was
not overwritten, deleted or retried. D1 is closed for 18/08/2026 with T0b open.
The physical power-down state at this close-out still requires the operator's
explicit confirmation before the day is fully closed.

### End-of-day continuation handoff

No second probe was attempted. The automatic MAVROS parameter-list exchange
exhausted its retries, so D1 remained closed under the no-retry rule and the
certified 18/08/2026 deployment root remained preserved. No source,
configuration or manifest repair was applied, no real-controller parameter was
written, and no simulator or higher-tier physical block was started.

The sole continuation scaffold is
`working_diary/2026-08-19_wednesday_t0b_evidence_repair_and_thrust_twin_continuation.md`.
It places the evidence-path repair, regenerated manifest, new deployment root
and T0b retry behind separate gates; T1 remains a decision point only, and the
simulator thrust track remains proposal-only. `Board.md` is unchanged pending
the documentation-staleness review.

At this handoff, the documentation worktree contains this modified record and
the untracked 19/08/2026 scaffold, with no other repository path changed. The
operator's physical power-down attestation remains outstanding and must be
appended before the day is recorded as fully closed.

### Documentation-staleness close-out

The current status surfaces were reconciled after the execution record was
written. `Board.md` now carries dated 17/08/2026 and 18/08/2026 rows plus an
explicit supersession of the former T0a-first position. `wiki/Roadmap.md` now
records the same simulator, D0, deployment and failed-probe boundaries in its
living status, narrative and dated history. The dashboard bench README now
records T0a as closed, D1 Gate 1 as passed and T0b as open.

The README's former `run-t2a` wording was also stale. The implementation creates
the guarded RC-override publisher and publishes live RC trims while armed; it
creates no bridge subscription to browser demand and accepts no non-neutral
demand. T2a acceptance must separately compare the observed output values with
the controller's live servo trims. No source, configuration or manifest file was
changed during this documentation close-out, and older dated diaries and dated
status rows remain unchanged as history.

The documentation working set now consists of this active diary, the sole
19/08/2026 scaffold, `Board.md`, `wiki/Roadmap.md` and the dashboard bench
README. The operator's physical power-down attestation remains the only missing
close-out input; until it is appended, 18/08/2026 is documented but not fully
closed.

### Operator physical shutdown confirmation

After the machine-side and documentation close-out, the operator explicitly
confirmed the final physical state: the controller/control box is off; the Pi is
off; propulsion is isolated; propellers are removed; the hull is restrained;
hardware safety is restored; and the Herelink sticks and trims are neutral.

This confirmation closes the 18/08/2026 physical shutdown. D1 remains closed
without retry, T0b remains open, the certified 18/08/2026 Pi deployment root
remains preserved, and no T1 or T2 authority carries into 19/08/2026. The sole
continuation remains the dated 19/08/2026 scaffold under fresh certification and
fresh block approvals.
