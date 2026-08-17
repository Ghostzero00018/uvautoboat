# Monday 17/08/2026 - real-FCU dashboard command/feedback acceptance

> **PRE-DIARY - NOT STARTED.** Moved unchanged in substance from the 14/08/2026
> scaffold, which was never started, and re-scoped from a morning-only window to
> a full working day. This file authorises nothing by itself. Every code change,
> simulator run, powered inspection, T0b probe, arm and non-neutral demand needs
> the separate approval named below.

## Objective

Obtain an honest, machine-readable real-FCU dashboard command/feedback result
with the FCU externally armed from QGroundControl on the Herelink. The
propellers remain removed, propulsion power remains isolated, the hull remains
restrained and the Herelink sticks remain untouched. The bounded browser demand
uses forward throttle only; negative throttle or a reverse test is not in
scope.

For this plan, **fully armed** means both of these observed conditions:

1. the FCU-box hardware safety state has been physically released; and
2. QGroundControl has produced an observed `armed:true` transition.

Neither repository helper nor the dashboard arms, disarms, changes mode,
releases hardware safety or force-arms the FCU. Those transitions remain
external operator actions. Because propulsion power stays isolated, this can
prove the real command and measured-feedback path while armed, but it cannot
prove powered motor movement or thrust.

## Starting state

The last technical work is still 13/08/2026. Friday 14/08/2026 went to the
internship report and produced no code, configuration, test, simulator run, Pi
session, control-box contact or hardware evidence; see
`working_diary/2026-08-14_friday_internship_report_writing.md`. Nothing below
was invalidated over the weekend, but every host-state figure in it is now
several days old and must be re-measured rather than reasoned from.

- Minimum known-good ancestor while drafting this file:
  `7df816715f81c457fc97231633d66e3341e52788`, subject
  `docs: add staged T2 gate and close-out order to Friday plan`, timestamped
  `2026-08-13 21:33:05 +0200`. The commit carrying this pre-diary will be later
  and is deliberately not predicted. On Monday certify the pushed `main` and
  inspect every intervening commit.
- C1 and C2 pass the expanded Block C. C1 has copied Pi logs and retained W1
  logs; C2 is operator-observed at `2.0 Hz` with no separately saved telemetry
  artifact.
- Block B remains **FAIL at teardown**. Its functional path reached arm,
  positive and negative differential phases, E-Stop and disarm, but the runner
  lost function-local arrays before its EXIT trap and produced no teardown or
  verdict artifact.
- T0a, T0b, T2a and T2b remain open. The real-FCU Pi link still has proven
  telemetry reception but no accepted request/response evidence. C1's optional
  `AUTOPILOT_VERSION` requests timed out.
- C2 measured `SERVO3 800` / `SERVO1 800` before safety release, after safety
  release, while armed and after disarm. `SERVO_OUTPUT_RAW` does not contain
  function assignments or configured rails, so this did not close T0b or T2a.
- The physical helper bundle verifies locally, but no deployed Pi copy of that
  four-file bundle is certified. Only the separate view-only helper was
  transferred on 13/08/2026, and no source change since then has invalidated
  it.
- The physical helpers have no normal-success operator-stop result. Their
  current `Ctrl+C` handlers exit `130`, and cleanup preserves that status even
  when `cleanup_rc=0`; the `14`-case suite checks stop order but not a clean
  planned completion.
- Host state was last observed at the close of 13/08/2026: relevant ports free,
  matching processes absent, `22 GB` free on the workstation. That snapshot is
  now stale. Re-measure all three before any block starts.

### Current pins

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `73,862` bytes | `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97` |
| `tools/live_dashboard_preflight.sh` | `29,058` bytes | `d101ec5840c1358e0475fff33989af9b3f3431231859c0e0e1c2ffa0fafab82a` |
| `tools/sitl_digital_twin_adjudicate.sh` | `19,656` bytes | `790fd46202726d53198fc9444913de421144562cbe1416497a6f3d84333687f3` |

The physical bundle manifest currently pins:

```text
9c6a7f5d255da4e3faae30503df7a4ddfa859c8a5440b751da206fcc4b21af60  tools/real_fcu_digital_twin_pi.sh
3edd7edbcc12e7ac37a7069b833ad8ee5e6ae7f527b6b550e3eacddf463dcf67  tools/real_fcu_rc_command_bridge.py
215293eab9d97e8da5a941d6cb8130351dfbafc07cca7656a766798a2a32b5fc  config/mavros_real_fcu_closed_loop_plugins.yaml
5e6008314216785f2de53a617ffec72913e52acbef00645a417f19d7279e7a94  config/mavros_real_fcu_t0b_plugins.yaml
```

Any change to a physical bundle member invalidates these values. Regenerate
`config/real_fcu_digital_twin_bundle.sha256` last, then transfer and verify the
complete relative-path bundle before any Pi invocation.

## Read first

1. This file in full. Do not create another 17/08 diary.
2. The final four sections of
   `working_diary/2026-08-13_thursday_sitl_acceptance_and_live_run.md`,
   including the Block B third execution, C1 artifact review, C2 result and
   end-of-day closeout.
3. `working_diary/2026-08-14_friday_internship_report_writing.md`, which records
   why this plan moved and confirms that nothing technical changed on 14/08.
4. `Board.md` from the T0a-T3b tier table through the 12/08 T0b mismatch and
   13/08 C2 result.
5. `working_diary/2026-08-11_tuesday_digital_twin_thrust_loop_and_helper_integration.md`
   from `Guarded physical-FCU workstation/Pi helper pair` through
   `Physical graph-isolation correction`.
6. `tools/live_dashboard_preflight.sh`,
   `tools/sitl_digital_twin_runner.sh`,
   `tools/sitl_digital_twin_adjudicate.sh` and the SITL focused suites.
7. `tools/real_fcu_digital_twin_workstation.sh`,
   `tools/real_fcu_digital_twin_pi.sh`,
   `tools/real_fcu_rc_command_bridge.py`, both MAVROS plugin allowlists, the
   bundle manifest and their focused suites.
8. `web_dashboard/autoboat/app.js` FCU-bench path and
   `web_dashboard/autoboat/README_autoboat_dashboard.md` before browser use.

## Repository certification

Start on internet-capable Wi-Fi so any required commit and push completes
before switching to `IoT IMT Nord Europe` for the two-machine run.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -12
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git merge-base --is-ancestor 7df816715f81c457fc97231633d66e3341e52788 HEAD
```

| Result | Action |
| --- | --- |
| Fetch fails | Stop and report. Remote parity is uncertified. |
| Behind only | `git pull --ff-only`, then restart the read-first and certification steps. |
| Dirty, ahead or diverged | Stop. No live helper starts. |
| `HEAD` is later than the drafting baseline | Inspect every intervening commit before continuing. |
| Baseline is not an ancestor | Stop and report. |

Recheck the three pins, all four physical bundle hashes, the `13` operational
pin surfaces, at least `10 GB` free disk, and these unused endpoints: TCP
`5760`, `5762`, `8002`, `8080`, `9090`; UDP `14600`; Pi serial `/dev/ttyAMA0` before
the physical helper owns it. Confirm no simulator, MAVProxy, MAVROS,
rosbridge, dashboard, command bridge, evidence recorder or live helper process
survives. Do not reuse a 13/08 run directory; 14/08 produced none.

## Day sequence and approvals

The order is binding. Blocks never overlap.

Unlike the 14/08 scaffold, this is a full working day rather than a single
morning, so there is enough time to attempt the complete gated chain below
without deliberately compressing close-out. Any of B1 to D1 can still fail its
gate and end the chain there. That is extra room, not
permission to relax a gate. Two rules
still bind the clock: reserve enough of the day for normal disarm, both helper
teardowns, control-box power-down, log copy-back and documentation, and do not
start a physical session late in the available window. Block E may need **two**
complete sessions, and the second one only begins if the first has been closed
out and recorded.

Every advance from B1 through E requires the gate shown in its row. F is the
exception: it is a mandatory close-out rather than a gated advance, and it runs
whether the chain completed or a blocker ended it early.

| Block | Scope | Approval and pass gate |
| --- | --- | --- |
| **A** | Certification, source review, pins, static checks and equipment inventory | Explicit start approval; read-only, starts no service |
| **B1** | Repair the Block B array-lifetime teardown defect | Separate code-change approval; red-green coverage, commit and push |
| **B2** | Give the physical helpers a normal-success operator-stop contract | Separate code-change approval; red-green coverage, bundle regeneration and push |
| **B3a** | Make a T2a-only session reachable | Separate code-change approval; red-green coverage, manifest regenerated in the same commit, push |
| **B3b** | Make T0b retain the live `RCMAP_*`, `SERVO*_FUNCTION` and rail values | Separate code-change approval; red-green coverage, manifest regenerated in the same commit, push |
| **C** | Re-run the full workstation SITL acceptance | Separate user-run approval; teardown and independent adjudication must both pass |
| **D0** | Powered-down T0a TX-path inspection | Separate physical approval; controller and propulsion remain powered down |
| **D1** | Deploy the pinned physical bundle and run T0b only | Separate user-run approval; request/response and retained parameter evidence must pass |
| **E** | Real-FCU dashboard command/feedback run, T2a then T2b as two sessions | Separate approval for T2a and another for T2b; requires B3a and B3b landed and deployed, and all prior gates green |
| **F** | Copy evidence, document bounded claims and close | Mandatory close-out, not a gated advance; runs after the live state settles or after a blocker ends the chain |

### Block A - certify and prepare only

Re-run only checks invalidated by a source or environment change. The 13/08
package and helper suites may be reused while their covered source and
dependencies remain unchanged; `HEAD` itself is not the criterion, since it has
already advanced through documentation commits. No source file changed after
`fe69c089e093f2fa46e09926342a9a879dfdcdbc` on 13/08, and the later commits
through `d11589a` are documentation-only, which is what makes the reuse
legitimate. Confirm that from git in the same turn rather than assuming it. Any
code edit reopens the checks for its changed surface.

**Block A keeps the control box powered off.** Confirm that it starts powered
off, that the propellers are removed, propulsion power is isolated, the hull
restraint is fitted, and the Herelink sticks and trims are neutral. Confirm that
QGroundControl and the Herelink are available and that the external safety
indication is understood, and rely on the retained 13/08 evidence for what live
FCU state looks like. **Any fresh live-state check requires the controller to be
powered, so it belongs to D1 or E under their own approvals, never to Block A.**
Equipment absence moves the day to the documentation fallback; it does not relax
a gate.

### Block B1 - fix the already-diagnosed SITL teardown defect

Add a focused failing case that sources the runner inside a function, returns
successfully and then exercises the script-level EXIT cleanup with registered
children. It must reproduce the 13/08 `sitl: unbound variable` failure before
the fix. Make the runner's array declarations global with the narrow
`declare -gA` / `declare -ga` correction, retain the complete seven-child stop
order and require teardown plus verdict creation.

Required verification: `bash -n` on the supervisor and runner, the complete
SITL focused suite, `git diff --check`, explicit staging, one conventional
commit and push. No simulator starts while the tree is dirty.

### Block B2 - make physical-helper completion decidable

Add red coverage for the documented sequence: externally disarmed final state,
operator-requested stop, bridge before MAVROS, dashboard before rosbridge,
serial and ports free, and both supervisors reporting a normal successful
completion. The current handlers unconditionally enter with status `130`, so
`cleanup_rc=0` alone cannot make the run pass. Define one explicit
operator-requested success path after the final disarmed gate and keep early or
armed interrupts non-zero.
The red case must exercise the actual operator-stop handler and fail while it
still exits `130`; calling cleanup directly with a synthetic status `0` is not
coverage of this defect.

Required verification: `bash -n` on both physical helpers, the complete
physical-helper suite, bridge compilation and focused suite if its surface
changes, `git diff --check`, and regeneration of
`config/real_fcu_digital_twin_bundle.sha256` within this same commit, before
the suite is run green. Commit and push. Deployment does not happen here; D1
deploys once, after the last B3 commit has landed.

### Block B3 - make the staged T2 approval and the T2a evidence actually reachable

Two independent defects block Block E as planned. Each needs its own
code-change approval; neither is authorized by approving the other, and
declining either one closes Block E rather than downgrading it.

**B3a - staged T2 approval.** `rfcu_pi_require_run_gates` demands
`REAL_FCU_T2A_APPROVED` and `REAL_FCU_T2B_APPROVED` together before `run`
starts, and the helper offers only `check|probe|run`. A T2a-only session is
therefore unreachable: the day could either approve T2b before T2a has been
observed, which contradicts the tier policy, or fail closed. T2a needs an
executable state that reaches externally-commanded arm/disarm and measured
neutral output with no command path capable of a non-neutral demand, while T2b
continues to require both flags. The red case must prove that the T2a-only
invocation is rejected today and that, after the change, it neither starts a
non-neutral command path nor lets a T2b-only or flagless invocation through.
The design is part of this block, not assumed here.

**The transition from T2a to T2b is two full sessions.** A running process
cannot be promoted by editing the environment it was started with, and the
T2a close-out deliberately ends in a powered-down bench, so no live session
survives for an in-session promotion to act on. The T2a-only session is closed
out in full, including control-box power-down, and its result recorded. Only
then is T2b proposed for its own approval; if it is granted, the bench is
powered back up and a second complete session starts with both flags set.

In-session promotion is explicitly not implemented. It would add a runtime
command path that raises a live armed vehicle's authority level, which is a
larger and less auditable surface than a second start-up is worth for one
bench measurement. B3a therefore adds no promotion mechanism, and the helper
keeps a single approval decision taken before start-up.

**B3b - T0b live mapping evidence.** The T0b artifact does not retain the live
`RCMAP_*`, `SERVO*_FUNCTION` and resolved RC/servo rail values that the tier
policy requires before T2a. The probe already force-pulls the full parameter
set; this change reads additional names out of that existing MAVROS parameter
cache and retains them in the artifact. It introduces no write to the flight
controller and no new write mechanism. It does request more parameter names
than the current artifact records, which is within T0b's read-only scope. The
red case must fail against an artifact missing those values.

Each commit that touches a bundle member regenerates
`config/real_fcu_digital_twin_bundle.sha256` **within that same commit**: the
physical-helper suite verifies the manifest against current repository bytes,
so a commit that changes a member without regenerating leaves the suite red and
the commit not self-consistent. That applies to B2, B3a and B3b alike.
**Deployment is the separate thing that happens once**, in D1, from whichever
manifest the last landed B3 commit produced.

If either change is declined or does not reach green, stop before Block E and
record the blocker. Do not reinterpret C2's `SERVO_OUTPUT_RAW 800/800` or the
bridge's channel-only log as the missing mapping proof. Never set both T2 flags
merely to bypass B3a, before T2a has been closed out, or before separate T2b
approval; after those gates pass, the fresh T2b session is the only permitted
both-flags case.

### Block C - make Block B actually pass

The user runs the existing supervisor, all one-shot operator commands and the
browser. A pass requires the full functional sequence, automatic teardown,
`evidence/teardown.json` with `"pass": true`, exact stop order
`dashboard, rosbridge, bridge, evidence, mavros, mavproxy, sitl`,
`SITL_VERDICT=PASS`, free ports and
`tools/sitl_digital_twin_adjudicate.sh "$RUN"` ending
`SITL_ADJUDICATION=PASS`.

Any failure ends Block C without a same-day retry. Preserve the run and use the
remaining time for diagnosis. Block E stays closed on a failed Block C.

### Block D0 - T0a powered-down inspection

With the controller and propulsion powered down, inspect the
`Pi TXD (GPIO14) -> Cube SERIAL1 RX` path, connector seating and continuity.
Record what was physically inspected and the result. Do not write parameters.
Only a positive T0a result permits `REAL_FCU_T0A_COMPLETE=1` later; never set
that flag from historical assumption.

### Block D1 - T0b and the live guard evidence

Transfer the complete four-file bundle with its relative paths and verify the
manifest on the Pi. The current `probe` demands the T2 mechanical-condition
flags even though T0b policy does not. Monday's bench is expected to satisfy
those conditions, so the probe can run without weakening that implementation.

T0b must start disarmed with hardware safety engaged. It may receive heartbeat,
force-pull the MAVROS parameter cache and read parameters only. It must not
start the bridge or publish a command. Required terminal results are:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=3 safety=ON
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
```

The evidence must retain actual values for `BRD_SAFETY_DEFLT`,
`BRD_SAFETY_MASK` and `BRD_SAFETYOPTION`. A timeout is evidence that the
Pi-to-FCU request path is still unavailable; stop without arming or retrying.

Because B3 lands before this block, the bundle transferred here is the final
one and this probe run is the one that must produce the live `RCMAP_*`,
`SERVO*_FUNCTION` and resolved RC/servo rail values that the tier policy
requires before T2a. If those values are absent from the artifact, T2a's
precondition is unmet: stop before Block E and record it. Do not reinterpret
C2's `SERVO_OUTPUT_RAW 800/800` or the bridge's channel-only log as that proof.

A timed-out or refused parameter path is a T0b result, not a reason to advance.
T1, the `BRD_SER1_RTSCTS` link-configuration write, is not authorized today: if
D1 fails on flow control, stop and record it rather than issuing a `PARAM_SET`.

### Block E - fully armed real-FCU dashboard loop

This block uses the guarded physical pair on ROS domain `43`: direct-serial
MAVROS and the bridge on the Pi, loopback rosbridge/dashboard on the
workstation. The camera/Hailo stack on domain `12` and SITL on domain `42` are
absent. The helpers reject overlap.

Block E is limited to the propellers-removed T2a/T2b bench tiers. Before step
1, confirm that the propellers remain removed, propulsion power remains
isolated, the hull restraint is fitted, and Herelink sticks and trims are
neutral and untouched. The dashboard bench-condition checkbox records the
operator's attestation; it is not a physical interlock. Any propeller-fitted
state is T3a, is out of scope and stops Block E.

The two tiers are two separate sessions, not one run with a mid-course change.
T2a is steps 1 to 4 followed by 7a, running under the B3a T2a-only path, which
cannot carry a non-neutral demand. Step 7a powers the bench down, so nothing of
that session survives into T2b.

T2b is proposed for its own approval only after T2a has been observed, closed
out and recorded. If it is granted, the bench is powered back up and T2b runs
**steps 1 to 6 followed by 7b** - the full sequence again, with both flags set,
a fresh `READY_DISARMED`, a fresh browser tab and a fresh capture. Steps 5 and
6 are what distinguishes T2b, but they are not the whole of it, and they are
never reached without repeating steps 1 to 4 in the new session. A running
process is never promoted by editing the environment it was started with.

The handover must provide all seven operational fields for every terminal. Use
a separate workstation capture terminal before arm and retain
`/command_ingress/rc_axes`, `/command_ingress/status` and FCU state through
every phase the approved tier actually reaches - for T2a that is neutral, arm,
disarm and teardown, and for T2b it additionally covers each active demand,
release and E-Stop. A browser observation without this capture is not a closed
evidence loop.
Long or quoting-sensitive capture logic must be a tested repository helper,
not an improvised terminal block. Preparing that helper is a separately
approved code change before Block E; its focused test must prove ordered
capture, retained timestamps and a clean final disarmed record.

Required order:

1. Pi and workstation helpers reach fresh `READY_DISARMED`; the workstation
   prints the servo-mapped bench URL.
2. Open exactly that URL in one browser tab and emit the required disabled
   frame. Use the mapping and rails read from this FCU, never SITL values.
3. Physically release hardware safety while disarmed; re-establish
   `READY_DISARMED` and neutral measured output.
4. Arm once from QGroundControl on the Herelink. No force arm and no retry on a
   rejection. Require fresh `ARMED_NEUTRAL` before any demand.
5. With the bench-condition box held true, apply only the approved bounded
   forward-throttle/differential-steering values. Require `ACTIVE`, fresh RC
   input/output and measured differential in the intended direction. Release
   returns to measured neutral before the next demand.
6. End the command sequence with the FCU-bench E-Stop. It latches; do not try
   to resume after it.
7. Close out using the matching sequence below. The T2a session runs steps 1 to
   4 and then 7a. The T2b session, if approved, runs steps 1 to 6 and then 7b;
   steps 5 and 6 are what distinguishes it, not the whole of it.

Close-out is ordered and recorded, not a wind-down. Record the time of each
step. Use exactly one of these two sequences:

**7a - T2a close-out.** Used whenever the run ends after step 4, whether or not
T2b is approved afterwards. Confirm measured output is still at neutral and
that no demand was ever issued, disarm normally in QGroundControl, observe
`armed:false`, restore hardware safety, stop Pi first, workstation second and
browser last, then power down the control box and confirm propulsion power is
still isolated. There is no E-Stop latch to confirm here, because step 6 did
not run. T2a is not complete until that powered-down state is observed and
recorded.

**7b - T2b close-out.** Used only when steps 5 and 6 ran. Release the browser
demand and confirm measured neutral, confirm the step 6 E-Stop latch is
holding, disarm normally in QGroundControl, observe `armed:false`, restore
hardware safety, stop Pi first, workstation second and browser last, then power
down the control box and confirm propulsion power is still isolated. T2b is not
complete until that powered-down state is observed and recorded.

Stop immediately on mapping or rail drift, non-`MANUAL` mode, stale state or
feedback, more or fewer than one command publisher, output above neutral before
an approved demand, an unexpected armed transition, a rejected arm, a command
phase that does not reach measured feedback, QGroundControl link loss, helper
child exit or any requirement to guess. Release the browser demand first, use
QGroundControl to disarm, restore hardware safety and preserve logs. Do not
rerun the live block that day.

A passing result must include, at minimum:

```text
REAL_FCU_PI_READY=PASS bridge=READY_DISARMED workstation=visible
REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output
REAL_FCU_FINAL_STATE=PASS connected=true armed=false
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
REAL_FCU_WORKSTATION_EXIT status=0 cleanup_rc=0
```

The two `status=0` lines are target acceptance markers for the Block B2 change;
the 13/08 source cannot emit them on its documented `Ctrl+C` path. Re-read the
landed source after the fix and use its exact wording. The retained status
capture, rather than an invented marker, must contain
`READY_DISARMED`, `ARMED_NEUTRAL`, `ACTIVE`, `EMERGENCY_STOP` and final
disarmed evidence. Paste back both supervisors, the capture path,
QGroundControl arm/disarm observations, browser demand/measured values and both
cleanup results.

## Explicit non-goals and fallback

This test does not run a virtual SITL boat concurrently with the real FCU.
Those supervisors cannot overlap and Block C must be fully down first. It also
does not test the person hold: no process publishes `/perception/detections`,
the Hailo overlay carries pixels rather than class events, and the camera and
physical command paths use different ROS domains. Adding that bridge is a
separate implementation task, not a checkbox in this run.

T1 is not authorized. No parameter is written on the real controller at any
point today, `BRD_SER1_RTSCTS` included, even if D0 shows the wiring intact and
D1 then fails on flow control. That combination ends the physical work at D1;
it does not license a link-configuration write.

No propeller-on, powered-thrust, static-propeller or on-water tier is included.
If Block B, B3, T0a, T0b, live map/rail evidence, equipment or time fails its
gate, use the remainder of the day to retain logs and document the blocker. Do
not substitute a manual unrecorded command path.

## Wrap

Append results only to this file. Preserve the 13/08 and 14/08 diaries and
dated Board rows as history. Record pre-edit baselines, never predict the
commit that contains its own closeout. Stage explicit paths, run
`git diff --check` and the checks required by every changed surface, inspect
staged content, use one-line conventional subjects no longer than 72
characters, then push and certify a clean `HEAD == main == origin/main` before
the day ends.

## Execution record - Blocks A and B1

The `PRE-DIARY - NOT STARTED` banner above records the imported scaffold state.
Execution began on 17/08/2026 under the block approvals recorded outside this
file. The pre-edit baseline for this appended record is
`8a8b75be7a897df12f53e269a5a8cf7937b8e0d3`; no commit containing this text is
predicted here.

### Block A result - PASS

Remote certification established a clean
`HEAD == main == origin/main == ef638c17fa84716de838b8bad4a94e1da1d2a326`
with divergence `0/0` before B1. The three pinned artifacts matched their
recorded sizes and SHA-256 values, the physical bundle manifest verified all
four repository files, and the `13` operational pin surfaces remained exactly
`9` helper-hash, `1` helper-size, `2` supervisor-hash and `1`
supervisor-size surfaces. Static shell, Python, JavaScript and MAVROS allowlist
checks passed without starting a service.

Fresh host inspection found TCP `5760`, `5762`, `8002`, `8080`, `9090` and UDP
`14600` free, with all named simulator, MAVProxy, MAVROS, rosbridge, dashboard,
bridge, evidence-recorder and live-helper process patterns absent. Free disk was
`23,031,112 KiB`, above the `10 GB` floor. The operator confirmed the complete
powered-down inventory: control box off, propellers removed, propulsion power
isolated, hull restrained, Herelink sticks and trims neutral, QGroundControl and
the Herelink available, and the external safety indication understood. No fresh
live-FCU state check was attempted in Block A.

The source-reuse statement in the Block A scaffold was valid at its
pre-B1 baseline but is superseded after the approved B1 change. The most recent
commit touching a non-Markdown tracked file is now
`8a8b75be7a897df12f53e269a5a8cf7937b8e0d3`. That commit changes only the SITL
runner and its focused test. Reuse remains bounded to unchanged covered
surfaces; the changed SITL surface was re-run in B1.

### Block B1 result - PASS for the landed source change

The new regression sourced the runner inside a function, returned before the
script-level EXIT trap and reproduced the retained failure as
`sitl_digital_twin_runner.sh: line 676: sitl: unbound variable`. Changing all
ten runner array declarations to `declare -gA` or `declare -ga` retained their
state for EXIT cleanup. The complete focused suite then passed at `41` cases,
including the seven-child stop order, passing teardown, empty verdict missing
set and final status `0`; the required shell syntax and diff checks also passed.

The change landed and was pushed as
`8a8b75be7a897df12f53e269a5a8cf7937b8e0d3`, subject
`fix(sitl): preserve runner arrays through EXIT cleanup`. Post-push
certification established clean local and remote parity at that revision with
divergence `0/0`. This closes the diagnosed runner source defect and its focused
regression. It does not claim that a separately approved full simulator run has
yet produced passing automatic teardown and final verdict; that remains the
Block C acceptance gate.

### Block B2 source and focused-test result - PASS

The pre-edit baseline for this appended B2 record is
`f2704c9b0fd051580b33d5d1fc3bb1be7ba681b7`; no commit containing this text is
predicted here. The first actual-signal regression sent `SIGINT` through each
helper's installed operator-stop handler. Before the fix, the workstation and
Pi each completed cleanup with `cleanup_rc=0` but retained status `130`, exactly
reproducing the missing normal-success path.

Review of the first green implementation found and reproduced a workstation
false pass: a cached disarmed value survived a failed fresh-status query and
allowed `status=0` while the injected current vehicle state was armed. That
implementation did not land. The corrected regression sets the obsolete cached
value to disarmed, makes the cleanup query fail, invokes the actual `SIGINT`
handler and requires status `130` with `cleanup_rc=1`.

The corrected contract uses no periodic workstation status polling. On an
operator stop after readiness, the Pi captures fresh connected-and-disarmed FCU
state and keeps the bridge and MAVROS alive while it waits for the workstation
rosbridge nodes to disappear. The workstation requires its children still
alive, obtains one fresh command-ingress status, accepts only connected,
disarmed, `MANUAL`, feedback-fresh `READY_DISARMED` or `EMERGENCY_STOP`, retains
that status, then stops dashboard before rosbridge. The Pi then stops bridge
before MAVROS and requires the serial endpoint free. Missing, stale, armed,
early, child-failed, port-occupied, serial-occupied or cross-supervisor timeout
paths remain non-zero.

The complete physical-helper suite passes at `17` cases. The actual success
markers in this source state are:

```text
REAL_FCU_FINAL_STATE=PASS connected=true armed=false
REAL_FCU_WORKSTATION_FINAL_STATE=PASS connected=true armed=false
REAL_FCU_WORKSTATION_EXIT status=0 cleanup_rc=0
REAL_FCU_WORKSTATION_STOP=PASS nodes=absent
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

The regenerated four-file manifest now records
`6b2cc9a1bdf60883dc03837e8cf85767d05e2dbfa16be16909f60580c95814d6`
for `tools/real_fcu_digital_twin_pi.sh`; the other three bundle hashes are
unchanged and all four verify against repository bytes. Neither deployed
view-only artifact changed, so the `13` operational pin surfaces remain
unchanged. No supervisor, simulator, browser, Pi, control box or other live
hardware path ran during B2. A physical normal-success result remains unproven
until its separately gated session is executed and retained.

### Block B2 coordination correction before landing

The first staged B2 result above is superseded before landing. Its Pi-side
shutdown decision accepted one ROS graph snapshot that omitted the workstation
nodes. The actual Pi `SIGINT` handler was exercised with the workstation still
represented as running but one incomplete snapshot injected. Before the
correction it falsely emitted:

```text
REAL_FCU_WORKSTATION_STOP=PASS nodes=absent
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

The corrected source no longer uses graph absence as shutdown proof. After a
fresh connected-and-disarmed Pi capture, the Pi keeps the bridge and MAVROS
alive and opens a bounded reliable, volatile subscription on
`/real_fcu/workstation_stop`. The workstation obtains and retains its fresh
final disarmed status, confirms its children alive, stops dashboard before
rosbridge, confirms both loopback ports free, and only then publishes the exact
one-shot marker to the waiting Pi subscription. The Pi validates the exact
payload, retains it as `evidence/workstation_stop.yaml`, then stops bridge
before MAVROS and confirms the serial endpoint free. Missing or altered marker
data, a failed publication, dead children, occupied ports or an occupied serial
endpoint all preserve status `130` with `cleanup_rc=1`.

The final staged source success markers are:

```text
REAL_FCU_FINAL_STATE=PASS connected=true armed=false
REAL_FCU_WORKSTATION_FINAL_STATE=PASS connected=true armed=false
REAL_FCU_WORKSTATION_STOP_MARKER=PASS topic=/real_fcu/workstation_stop
REAL_FCU_WORKSTATION_EXIT status=0 cleanup_rc=0
REAL_FCU_WORKSTATION_STOP=PASS marker=received topic=/real_fcu/workstation_stop
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

The regression still invokes the actual operator-stop handlers. It now injects
both the incomplete graph snapshot and invalid marker data and requires the Pi
path to fail closed. Separate checks cover the bounded QoS command arguments,
exact payload validation, publication failure, fresh disarmed evidence, child
and endpoint failures, teardown order and both normal-success paths. The
complete physical-helper suite passes at `19` cases, and the required shell
syntax and diff checks pass.

The regenerated four-file manifest now records
`501caf6c79a991977dbc056afba6d3a88ac32a72194da9aad3d1e067e36deafe`
for `tools/real_fcu_digital_twin_pi.sh`; the other three bundle hashes remain
unchanged and all four verify against repository bytes. The two deployed
view-only artifacts and their `13` operational pin surfaces remain untouched.
No live supervisor, simulator, browser, Pi or control-box path ran for this
correction. The physical normal-success result remains unproven.

### Block B2 marker-format correction after `7e97a0a`

The pre-edit baseline for this appended correction is
`7e97a0af3ea54482b18f77ba61599d5b0600da3b`; no commit containing this text is
predicted here. After that revision landed, an operator-run isolated ROS Jazzy
format probe established that the exact `ros2 topic echo --once` invocation
retains a trailing YAML document separator:

```text
data: REAL_FCU_WORKSTATION_STOPPED final=disarmed children=stopped ports=free
---
```

The landed validator parsed those bytes as one mapping followed by one empty
document and rejected them because it counted both documents. Its focused stub
had omitted the separator, so the `19`-case green result did not establish that
a live Jazzy marker could pass. The same capture also merged stderr into the
evidence file, allowing unrelated middleware diagnostics to corrupt otherwise
valid marker YAML. Therefore the physical normal-success path remained
unreachable in `7e97a0a`; the earlier success-marker list described intended
source behaviour, not a live-capable result.

The corrected fixture emits the byte-faithful trailing separator and a separate
stderr warning. It first reproduced merged-stream evidence corruption. After
stderr was routed to `logs/workstation_stop_capture.log`, the fixture separately
reproduced rejection of the valid trailing empty document. The validator now
drops only empty YAML documents before requiring exactly one mapping with only
the exact expected `data` value. Altered data and duplicate non-empty documents
remain rejected, and the actual operator-stop regression now uses the real
separator format.

The complete physical-helper suite passes at `19` cases, shell syntax and diff
checks pass, and the regenerated bundle manifest records
`e20961a7643025fe005122e927c93de9ebbc3db3dac63a174e0fc62cd85197f1`
for `tools/real_fcu_digital_twin_pi.sh`. The other three bundle hashes remain
unchanged and all four verify against repository bytes. The two deployed
view-only artifacts and their `13` operational pin surfaces remain untouched.
The isolated format probe contacted no helper, FCU or Pi and does not close the
still-unproven physical normal-success result. Block B3a remains closed.

### Block B3a source and focused-test result - PASS

The pre-edit baseline for this appended B3a record is
`9270d9e752a1c04d03525f00f474af8db7f24cd9`; no commit containing this text is
predicted here. Before the approved edit began on 17/08/2026, the operator
confirmed that the FCU and control box were powered down, propulsion was
isolated, propellers were removed, hardware safety was restored and the Pi
helper had not been started.

The focused red helper check failed because the Pi usage and dispatcher exposed
no distinct T2a-only run. The bridge suite ran `24` tests with the two intended
failures: the bridge declared no neutral-only authority parameter, and its
command callback handled an injected message instead of rejecting that path as
neutral-only. These failures established the two B3a reachability and authority
defects against the landed baseline.

The Pi helper now exposes `run-t2a` as a separate start-up mode. It requires the
common physical and probe gates plus `REAL_FCU_T2A_APPROVED=1`, and accepts only
`REAL_FCU_T2B_APPROVED=0` or an unset T2b flag. Flagless, T2b-only and
both-flags T2a invocations fail closed. The existing `run` mode still requires
both T2 approval flags. There is no runtime promotion mechanism; moving from
T2a to T2b still requires a fully closed and powered-down T2a session followed
by a separately approved fresh start.

For `run-t2a`, the Pi starts the bridge with `neutral_only:=true`. The bridge
creates no `/command_ingress/rc_axes` subscription, defensively rejects any
direct callback invocation, reports `neutral_only:true` in its retained status
and keeps the resolved steering and throttle RC rails at trim while the vehicle
is validly armed. The workstation derives its browser URL from that status and
omits `enable_fcu_bench_control=1`, so the dashboard creates no command
publisher. The Pi readiness gate requires the status authority to match the
selected run mode. Full `run` passes `neutral_only:=false` and retains the
separately gated demand-enabled path.

The actual operator-stop regression now also covers `run-t2a` and requires the
B2 final-disarmed evidence, workstation stop marker and status `0` cleanup path.
The complete physical-helper suite passes at `19` cases. The bridge suite passes
all `24` tests, Python compilation and shell syntax checks pass, and the current
dashboard README records the four Pi entry points and their distinct authority.

The regenerated physical bundle manifest records
`fa4b4bad47b24f6bbf9b001e048ec9444fa9c08b4b3cdc6ca20805e73610a277`
for `tools/real_fcu_digital_twin_pi.sh` and
`bcfdb4fa105b7d59539355cea459220ca27f9b87095d323fe4df181dedeb10f3`
for `tools/real_fcu_rc_command_bridge.py`. Both MAVROS allowlist hashes remain
unchanged and all four manifest entries verify against repository bytes. The
two deployed view-only artifacts and their `13` operational pin surfaces remain
untouched.

No supervisor, simulator, browser, Pi, FCU or control-box path ran during B3a.
This is a source and focused-test result only: no T2a physical result is claimed,
B3b remains closed, and Blocks C, D0, D1 and E have not advanced.

### Block B3b source and focused-test result - PASS

The pre-edit baseline for this appended B3b record is
`780f615150c057a9c7a6c2269fbab953c1d0bee8`; no commit containing this text is
predicted here. The focused physical-helper red failed with `T0b capture is
missing: t0b-discovery-parameters` against that source. The bridge suite then
ran `26` tests with the two intended errors because the shared T0b parameter
plan and evidence builder did not exist. These failures established that the
probe retained neither the mapping nor the configured rails.

The T0b probe still performs one forced MAVROS parameter-cache pull and uses
only read-only `ros2 param get /mavros/param` requests afterwards. It now asks
the command bridge's offline resolver for the `18` discovery names: both
`RCMAP_*` parameters and all `SERVO1..16_FUNCTION` parameters. The existing
`discover_channels` implementation resolves the steering and throttle RC
channels plus the unique servo functions `73` and `74`, after which the same
bridge implementation requests `20` channel-specific rail names. Those are
the six RC values `MIN`, `TRIM`, `MAX`, `DZ`, `REVERSED` and `OPTION` for each
resolved RC channel, and the four servo values `MIN`, `TRIM`, `MAX` and
`REVERSED` for each resolved output channel.

Together with the three safety parameters, the validated
`uvautoboat.real_fcu.t0b.v2` artifact retains exactly `41` named values, the
complete function table, the resolved channel mapping and both RC-input and
servo-output rails. The evidence builder reuses `discover_channels`,
`_rc_rail` and `_servo_rail`; the live bridge guard now obtains its discovery
and dynamic rail name plans from the same functions. Missing, duplicate,
unexpected, non-finite, ambiguous or invalid mapping and rail values fail
closed. The source marker that supersedes the earlier three-read plan is:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
```

The final review added a red case that forced a cache-read failure while calling
the new parameter helper from a shell conditional. Before correction, the
helper relied on `errexit`, returned success and appended an empty value in that
context. It now returns explicitly after every name, duplicate, read, parse and
record failure. The regression requires a non-zero result and an unchanged
parameter record.

The complete physical-helper suite passes at `21` cases and the bridge suite
passes all `26` tests. Shell syntax checks pass for both physical helpers and
the physical-helper suite; Python compilation passes for the bridge and its
focused suite. The four-file manifest verifies all entries against the current
repository bytes and now records
`38e41d7dc8181e0f289d3b89c6e374e37cf020cf34e7b03f3cf955981a8efafd`
for `tools/real_fcu_digital_twin_pi.sh` and
`cf6668139999308b65a2f8af7ef70f74e226c9bd6c1ac82545bc6c1d0bbb59d7`
for `tools/real_fcu_rc_command_bridge.py`. Both allowlist hashes remain
unchanged. The dashboard README now describes the retained `41`-parameter T0b
artifact.

No supervisor, simulator, browser, Pi, FCU or control-box path ran during B3b.
No controller parameter write or new write mechanism was introduced. The three
pinned artifacts and the `13` operational pin surfaces remain untouched. This
is a source and focused-test result only: T0b remains open until a separately
approved D1 probe retains this controller's live artifact. The separate
capture-helper change and Blocks C, D0, D1 and E have not advanced.

### Command/feedback capture-helper source and focused-test result - PASS

The pre-edit baseline for this appended capture-helper record is
`b4b9f14055c2b8cf67b92d34f9f54aab2954c9df`; no commit containing this text is
predicted here. The first focused red failed because
`tools/real_fcu_command_feedback_capture.py` did not exist. A separate
physical-helper red then failed because the workstation `check` path did not
run the new focused suite.

The new workstation-only helper uses native `rclpy` subscriptions for
`/command_ingress/rc_axes`, `/command_ingress/status` and `/mavros/state`. Its
application surface has no publisher or service client; ROS logging and
parameter services are disabled. It does not invoke `ros2 topic echo`, so YAML
document separators and partial YAML documents are not part of its evidence
format, and it has no controller-write path. The helper requires domain `43`,
subnet discovery and non-localhost transport, plus a clean
`HEAD == main == origin/main`, before creating a timestamped run directory
outside the repository.

All three topics share one JSONL stream containing only completely committed
records. Every record has one global sequence number plus Unix and monotonic
receipt times taken in the same callback. Joy and MAVROS State records also
retain their source-header timestamp; the headerless bridge status records a
null source timestamp rather than inferring one. Status JSON is retained both
as the original String payload and as a decoded object. Helper diagnostics use
`logs/capture.log` and are never merged into `evidence/events.jsonl`.

The initial implementation exposed seven further red cases during review. An
injected interrupt could leave an unverified partial final record, a merely
received invalid status could trigger the streams-ready marker, and an
immediate stop at initial disarmed readiness could produce a clean-endpoint
pass without covering arm and disarm. The default reliable Joy subscription
could also miss a best-effort publisher. Finally, incomplete decoded status
objects carrying only phase names could satisfy the ordered-state list, and a
ROS node-destruction exception could bypass later cleanup and verdict writing.
The MAVROS State subscription also inherited reliable shorthand, which could
receive no state samples if that publisher offered best-effort reliability.
The corrected writer blocks termination signals while committing one binary
JSONL record, rolls a failed write back to the last complete byte boundary,
then restores signal delivery. The Joy subscription now matches the bridge's
best-effort, depth-one contract. MAVROS State requests best-effort at depth ten,
which accepts either offered reliability, while bridge status retains its
matching reliable default. Structural and phase-semantic validation keeps
incomplete status objects out of the ordered sequence. Cleanup attempts both
node destruction and context shutdown and folds either error into the retained
fail-closed verdict. The readiness marker requires valid, connected, disarmed
`MANUAL` status and FCU state with tier-matched authority.

On operator stop, the atomic verdict requires an armed FCU sample and the
ordered bridge-state subsequence for the selected tier. T2a requires
`READY_DISARMED`, `ARMED_NEUTRAL`, final `READY_DISARMED`, and zero command
frames. T2b requires `READY_DISARMED`, `ARMED_NEUTRAL`, `ACTIVE`, final
`EMERGENCY_STOP`, and at least one retained command frame. Both tiers require
the final bridge status and final MAVROS State to be connected, disarmed and
`MANUAL`; invalid status evidence or a runtime failure keeps the verdict false.
The manifest retains the exact helper hash, repository refs, ROS environment,
tier and topic list. A passing foreground stop emits:

```text
REAL_FCU_CAPTURE_FINAL=PASS tier=T2A|T2B final=disarmed events=<count> run_dir=<path>
```

The focused capture suite passes all `13` tests. It covers exact ROS
environment rejection, application-subscription topology, global ordering,
uniform receipt timestamps, command-topic and state-topic QoS, real ROS
message-header conversion, partial-write rollback, cleanup-error retention,
valid readiness, T2a and T2b success, armed/invalid-status failure, incomplete
phase objects, missing tier sequence and the tier command-frame rules. The
complete physical-helper suite passes at `22` cases after adding the capture
suite to the workstation `check` path. Python compilation, shell syntax for
both physical helpers and the physical-helper suite, the unchanged four-file
bundle's `4/4` hash check and the repository diff check all pass. The dashboard
README documents the helper and its evidence contract.

The capture helper and workstation helper are not Pi bundle members, so the
four-file manifest was not regenerated. The three pinned artifacts and `13`
operational pin surfaces remain untouched. No supervisor, simulator, browser,
Pi, FCU or control-box path ran for this change; no physical capture result is
claimed. Block C, D0, D1 and E remain closed.

### Block C workstation simulator acceptance - PASS

The pre-edit baseline for this appended Block C record is
`ea8429daab7b7e7c1ba1234589b9899a7135c83c`; no commit containing this text is
predicted here. On 17/08/2026, the user ran the full workstation supervisor at
`/home/ghostzero/Desktop/sitl_digital_twin_20260817_162407` on isolated ROS
domain `42`. No Pi, real FCU or control-box process participated.

The first safety-off command was split before `--action` and failed during
argument parsing, before `load_gate()` or `claim_gate()` could run. It therefore
claimed no gate and performed no vehicle action. The corrected one-line command
used the still-open gate and succeeded. The retained operator artifacts record
`success:true` for safety-off, arm and disarm, each against its unique gate.

The machine-readable browser phases cover the full requested path. The run
reached disarmed `READY_DISARMED`, armed `ARMED_NEUTRAL`, positive `ACTIVE` at
steering `+0.10` and throttle `0.08`, neutral release, negative `ACTIVE` at
steering `-0.04` and throttle `0.09`, latched `EMERGENCY_STOP`, then accepted
normal disarm. Measured `SERVO1`/`SERVO3` output was `1585`/`1485` in the
positive phase, returned to `1500`/`1500`, became `1520`/`1559` in the negative
phase and returned to `1500`/`1500` for E-Stop. The differential changed sign
between the two active phases, and there was no third active demand.

Automatic teardown stopped `dashboard`, `rosbridge`, `bridge`, `evidence`,
`mavros`, `mavproxy` and `sitl` in that exact order. The retained teardown has
`"pass":true`, `cleanup_rc:0`, `children_stopped:true` and `ports_free:true`.
The final verdict has `verdict:"PASS"`, `missing:[]` and
`session_complete:true`; all ten recorded evidence digests match their files.
The supervisor exited with status `0`, `cleanup_rc=0` and `finalize_rc=0`.
Independent adjudication ended with `SITL_ADJUDICATION=PASS` and status `0`;
a second read-only adjudication produced the same result without changing the
run-directory tree digest. This is the end-to-end Block B1 confirmation that
the automatic EXIT path now retains its runner state and produces teardown and
verdict artifacts.

The run also makes the platform boundary concrete. Its captured parameter
snapshot resolves steering `RC1`, throttle `RC3`, left `SERVO1_FUNCTION=73`
and right `SERVO3_FUNCTION=74`, with both RC and servo rails at
`1000`/`1500`/`2000`. The tracked historical real-boat record instead assigns
left function `73` to `SERVO3` and right function `74` to `SERVO1`, with
`800`/`800`/`2200` output rails. Those historical real-boat values are not a
current T0b result: D1 must still read this controller's live `RCMAP_*`,
`SERVO*_FUNCTION`, RC rails and servo rails. No simulator channel assignment,
trim or PWM value may be carried into T2a or T2b.

Block C is closed as PASS. D0 has now received separate approval, but its
powered-down inspection has not yet been performed. D1 and E remain closed.

### Block D0 powered-down T0a inspection - PASS

On 17/08/2026, the operator reported the controller and Pi powered off,
propulsion isolated, propellers removed and no physical changes made. With the
path de-energised, the operator inspected `Pi TXD (GPIO14) -> Cube SERIAL1 RX`
and reported both connector seating and end-to-end continuity as PASS.

This operator-attested physical result closes T0a. It permits
`REAL_FCU_T0A_COMPLETE=1` to be supplied later only within an approved D1
session; the flag was not set during D0. No bundle transfer, helper start,
controller power-up, parameter write or wiring change occurred. D1 and E remain
closed pending their separate approvals.

### End-of-day close-out - D1 deferred before execution

The pre-edit baseline for this appended close-out is
`50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4`; no commit containing this text is
predicted here. At 17:09 on 17/08/2026, the operator ended the live work and
moved the unfinished physical sequence to 18/08/2026.

D1 received user-run approval, but no transfer, deployed-bundle verification,
Pi `check`, controller probe or T0b artifact was reported. The handover stopped
while replacing the proposed interactive SSH terminal with the operator's
existing Remmina Pi terminal. There is therefore no certified deployed copy of
the four-file physical bundle, and D1 remains **NOT RUN**. No D1 retry or
substitute command path occurred. T0b, T2a and T2b remain open; Block E did not
start.

The workstation close-out found no matching simulator, MAVProxy, MAVROS,
rosbridge, dashboard, physical-helper, bridge or capture process. TCP ports
`5760`, `5762`, `8002`, `8080` and `9090` plus UDP port `14600` were free. Free
space at 17:14 was `23,011,820 KiB`. The repository was clean and synchronized
at the pre-edit baseline; the current four-file manifest verified `4/4`. The
only 17/08 supervisor directory was the passing Block C run at
`/home/ghostzero/Desktop/sitl_digital_twin_20260817_162407`; no workstation
real-FCU run directory was created.

The durable day result is bounded: the code and focused-test blocks landed;
Block C passed its complete simulator path, automatic teardown and independent
adjudication; and the operator-attested powered-down D0 inspection closed T0a.
No real-controller parameter response, dashboard command/feedback result or
real-FCU command was obtained. The physical power-down state at this close-out
still requires the operator's explicit confirmation before the day is fully
closed.

The sole 18/08 continuation diary resumes at certification and D1. It must not
repeat Blocks B, C or D0, and it must not carry the 17/08 D1 approval across the
day boundary without a fresh user-run confirmation after certification.

After the machine-side close-out, the operator explicitly confirmed the
end-of-day physical state: controller and Pi off, propulsion isolated, hardware
safety restored, propellers removed, hull restrained, and controls neutral.
This confirmation closes the 17/08 physical shutdown. D1 remains **NOT RUN**;
its deployment, `check`, probe and T0b evidence move to 18/08.
