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
