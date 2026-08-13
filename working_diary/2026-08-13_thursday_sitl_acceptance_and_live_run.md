# Thursday 13/08/2026 - corrected SITL acceptance and view-only live run

> **PRE-DIARY - NOT STARTED.** Moved unchanged in substance from the 12/08/2026
> plan, which was deferred because that day went to the internship report. This
> file does not authorize work. Every block below needs explicit approval before
> it starts.

## Purpose

Convert the 11/08 static work into runtime evidence. Two runs are in scope and
they run in sequence, never together: the corrected workstation SITL closed loop,
then the workstation/Pi view-only telemetry stack. The guarded physical-FCU
helper pair stays unrun; its first hardware gate is a `T0a` inspection that has
not been scheduled.

## Read first

1. This file.
2. The complete 11/08 diary, especially the last three appended sections:
   `Block D first attempt and supervised-launch correction`,
   `Guarded physical-FCU workstation/Pi helper pair` and
   `Physical graph-isolation correction`:
   `working_diary/2026-08-11_tuesday_digital_twin_thrust_loop_and_helper_integration.md`.
3. `working_diary/2026-08-12_wednesday_internship_report_writing.md` - short. It
   records why this plan moved and the three inaccuracies corrected while moving
   it, including the incomplete commit chain that this file's certification
   section now states in full.
4. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` for the view-only runbook.
5. `tools/live_dashboard_preflight.sh`, `tools/sitl_digital_twin_runner.sh`,
   `tools/real_fcu_rc_command_bridge.py` and their focused suites.

Do not create a second 13/08 diary. Append the day's results to this file only.
Do not rewrite any earlier diary, dated Timeline row or historical hash.

## Repository certification

The 11/08 work landed in five commits, not three. The earlier statement in the
12/08 plan named only the middle three and omitted both the day's core
implementation and the commit that carried the plan itself:

```text
a0f516d  feat(sitl): add guarded digital-twin runner
3097061  feat(fcu): add guarded closed-loop helper pair
fcb346a  chore: remove unbuilt servo command reference
c72e8e5  docs(diary): prepare SITL acceptance and live run
89b5fc1  docs(diary): record landed baseline in the 12/08 plan
```

The pre-deferral baseline was `89b5fc1`. Startup must certify the current
`origin/main` and inspect the documentation commit carrying this deferral, which
landed after that baseline and touches only working-diary files.

Re-certify the current repository state before any run, because
`sitl_verify_repository_state` refuses to start unless the worktree is clean,
`HEAD` equals `origin/main`, and `HEAD` descends from
`d911f8a7cbe52b6c08cdd71391fcac823d9d79c4`. A committed but unpushed state fails
the same check.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git status --short --branch
git rev-parse HEAD origin/main
git rev-list --left-right --count main...origin/main
```

| Result | Action |
| --- | --- |
| Dirty, ahead or diverged | Stop. Finish the commit and push first. |
| `HEAD` differs from `origin/main` | Push, then repeat certification. |
| Behind only | `git pull --ff-only`, then repeat certification. |

Re-measure free disk and require at least `10 GB`. The 11/08 figures of `23G`
and `20G` are stale snapshots, now two days old; re-measure rather than reusing
either.

The operational pin surface count is `13`: nine helper-hash occurrences, one
helper size, two supervisor-hash occurrences and one supervisor size. Earlier
diaries record `12`, which was correct when written and stays untouched.

The deployed Pi helper copy is still stale, carried over from the 10/08 change,
because no transfer has been recorded since. It must be transferred and verified
before the view-only block.

## Carried evidence and exact non-claims

The 11/08 work established, statically only:

- the SITL runner starts the pinned Rover binary directly instead of through
  `sim_vehicle.py`, in the supervisor-owned process group, with output in
  `logs/sitl.log`;
- an explicit `expected_domain_id` bridge parameter, empty by default and
  validated only in the enabled branch, with SITL passing `42` and the physical
  Pi passing `43`;
- graph isolation: SITL on domain `42` with `LOCALHOST` discovery, both physical
  helpers on domain `43` with `SUBNET` discovery;
- focused suites green - preflight `13`, SITL `11`, physical helpers `14`,
  bridge `22`, operator `5`, evidence `9`, dashboard `39`, Pi lifecycle pass.

Nothing above is runtime evidence. The corrected SITL launch has never executed.
The physical helper pair has never contacted an FCU. No arming, no physical
thrust, no Pi command path and no real-boat mapping is claimed.

Three corrections from 11/08 that must not be rediscovered:

1. `sim_vehicle.py` delegates Rover to `run_in_terminal_window.sh`, which selects
   an `xterm` when `DISPLAY` is set. The terminal's child takes a new session, so
   its process group can never match the supervisor's and its output never
   reaches the run log. Launch the binary directly.
2. A ROS 2 parameter override with an empty value is rejected by the parser.
   `-p name:=` fails at `rcl` init; an explicit empty string must be the literal
   token `name:=""`.
3. `LOCALHOST` and `SUBNET` participants on the same host and domain do reach
   each other, so a workstation rosbridge on the physical domain could otherwise
   have spanned an orphaned SITL bridge and the remote physical bridge. Domain
   separation is the primary protection; process guards are secondary.

## Fixed architecture

1. Run the SITL acceptance to completion and tear it down before starting the
   view-only stack. They contend for ports `8002` and `9090` and each supervisor
   rejects the other's process ownership.
2. `tools/pi_live_hailo_mavlink_dashboard.sh` remains view-only and byte-identical
   at `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97`.
3. `tools/real_fcu_digital_twin_workstation.sh` and
   `tools/real_fcu_digital_twin_pi.sh` are the only two operator-facing helpers
   for the physical system. Neither runs today.
4. Operator arm and disarm stay separate one-shot actions. No helper arms,
   disarms or releases a hardware safety state.

## Block A - certify and inspect

Read-only, starts nothing. After repository certification, confirm no SITL,
MAVProxy, MAVROS, rosbridge, dashboard, bridge, evidence-recorder or helper
process is running, and that TCP `5760`, `5762`, `8002`, `9090` and UDP `14600`
are free. Re-run the focused suites and record the counts. Stop and request
approval for Block B.

## Block B - corrected SITL acceptance, user-run

Workstation only, three terminals plus one browser tab. No Pi, no FCU.

Terminal 1 launches the supervisor. Do not source ROS and do not activate the
ArduPilot virtual environment; the runner establishes and validates domain `42`,
`LOCALHOST` discovery and localhost-only mode itself.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
export LIVE_DASHBOARD_LOG_ROOT=/home/ghostzero/Desktop
tools/live_dashboard_preflight.sh sitl
```

The three `SITL_*` timeout variables equal their built-in defaults and may be
exported for explicitness only. Leave Terminal 1 in the foreground.

Expect these markers in order. The first two are what failed on 11/08, so treat
`SITL_PROCESS=READY` as the real repair signal:

```text
SITL_PREFLIGHT=PASS
SITL_PROCESS=READY
SITL_MAVPROXY=READY
SITL_MAVROS=READY
SITL_BRIDGE_GUARD=PASS
SITL_CAPTURE=READY
SITL_DISARMED_READY=PASS
SITL_WEB=READY
SITL_BROWSER=READY
SITL_SESSION=READY
```

Operator sequence, with each one-shot command copied verbatim from Terminal 1
into Terminal 2. Those commands invoke
`/home/ghostzero/venv-ardupilot/bin/python` directly and must be run once each:

1. run the printed `safety-off` command;
2. open the exact bench URL printed by Terminal 1, in one tab;
3. wait for Connected, then click Neutral Now once;
4. run the printed `arm` command; never force-arm;
5. tick the bench-condition box and hold Apply at steering `+0.10`,
   throttle `0.08`;
6. release Apply and return both axes to zero;
7. hold Apply at steering `-0.04`, throttle `0.09`;
8. release Apply, then press the bench E-Stop once;
9. run the printed `disarm` command;
10. wait for automatic teardown. Do not press Ctrl+C on the successful path.

The bench URL carries the live servo mapping parsed from the bridge guard line,
so use the printed URL rather than a remembered one:

```text
http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=N&thrust_right_servo=N
```

Acceptance requires all of:

```text
SITL_ACCEPTANCE=COMPLETE teardown=pending
SITL_VERDICT=PASS
SITL_LOGS=/home/ghostzero/Desktop/sitl_digital_twin_YYYYMMDD_HHMMSS
SITL_SUPERVISOR_EXIT status=0 ... cleanup_rc=0 finalize_rc=0
```

Stop immediately on a non-loopback endpoint, surviving domain `12`, an
already-armed startup, non-`MANUAL` mode, incomplete parameters, stale feedback,
mapping drift, failure to neutralise or an unowned conflicting process. On an
unexpected state release Apply, press Ctrl+C once in Terminal 1, use only the
printed cleanup-disarm command if armed, and do not retry the run.

Extract evidence in Terminal 3 after Terminal 1 exits, replacing `RUN` with the
exact `SITL_LOGS=` path. The subshell keeps an aborted check from closing the
terminal:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat

RUN='/home/ghostzero/Desktop/sitl_digital_twin_YYYYMMDD_HHMMSS'

(
    test -d "$RUN" || { echo "ABORT: invalid run directory: $RUN"; exit 1; }

    for file in \
        evidence/startup.json evidence/ready_disarmed.json \
        evidence/browser_ready.json evidence/arm.json \
        evidence/positive.json evidence/release.json \
        evidence/negative.json evidence/estop.json \
        evidence/disarm.json evidence/teardown.json evidence/verdict.json \
        control/disarm_release_frames.json control/shutdown_frames.json \
        control/teardown_runtime.json
    do
        echo "===== $file ====="
        /usr/bin/python3 -m json.tool "$RUN/$file" || exit 1
    done

    echo "===== capture line counts ====="
    wc -l "$RUN"/captures/*.jsonl

    echo "===== retained hashes ====="
    sha256sum "$RUN"/captures/*.jsonl "$RUN"/evidence/*.json "$RUN"/control/*.json
)
```

`evidence/teardown.json` must report `"pass": true`, and its `runtime.stop_order`
must read `dashboard`, `rosbridge`, `bridge`, `evidence`, `mavros`, `mavproxy`,
`sitl`. Do not start Block C until that file passes and the ports are free.

## Block C - view-only live run, user-run

Workstation, Pi and the physical FCU, observing only. Follow
`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` and the 11/08 handover. Summary of
what differs from the SITL block:

- prerequisites: both machines on `IoT IMT Nord Europe`, control box powered,
  FCU disarmed, propulsion physically isolated, D435I and Hailo attached, Pi
  terminal opened from the physical desktop or a Remmina session with a
  non-empty `DISPLAY`;
- the workstation supervisor is `tools/live_dashboard_preflight.sh run`, which
  prints one compound Pi command to paste unedited into the Pi terminal;
- `WORKSTATION_NODE_SNAPSHOT_RETRY attempt=N/3 missing=...` is benign; only
  `STOP: workstation nodes not visible from the Pi after 3 attempts: ...`
  is terminal;
- arrival requires `topics=7`, being one Hailo overlay topic and six MAVROS
  telemetry topics, and the browser shows six freshness badges;
- the view-only discriminators are a blocked
  `LIVE MAVLINK VIEW-ONLY: blocked mission command joystick_enable` with **no**
  confirmation dialog, and
  `LIVE MAVLINK VIEW-ONLY: blocked dashboard emergency-stop publish`. A dialog
  appearing means the write was not blocked; treat it as a breach and stop
  Pi-first;
- shutdown is Pi first, then the workstation, then the browser.

## Block D - physical helper pair, not run today

The pair is prepared and statically certified only. `T0a` is an inspection gate
and has not been scheduled, so `tools/real_fcu_digital_twin_workstation.sh` and
`tools/real_fcu_digital_twin_pi.sh` are not invoked today in any mode, including
`check`. Any future invocation requires approval for its actual tier. `T0a` and
`T0b` retain their own non-actuating conditions; propeller removal, hull
restraint and isolated propulsion power apply before `T2a` or any actuating
tier, not before the inspection and query tiers.

## Block E - document and wrap

Append the run directories, marker transcripts, measured transitions, evidence
hashes and bounded non-claims to this file. Update living Board, Roadmap and
dashboard text only where runtime behaviour actually changed. Leave dated rows
and earlier diaries untouched.

## Verification by changed surface

| Changed | Required checks |
| --- | --- |
| `tools/live_dashboard_preflight.sh` | `bash -n` on both helpers, both focused shell suites, and re-pin the supervisor size and digest in the test constant and the runbook rows. |
| `tools/sitl_digital_twin_runner.sh` | `bash -n` and the SITL focused suite. |
| `tools/real_fcu_rc_command_bridge.py` | `python3 -m py_compile`, its focused suite, and regenerate `config/real_fcu_digital_twin_bundle.sha256` last. |
| Either physical helper | `bash -n`, the physical focused suite, and regenerate the bundle last. |
| Dashboard JavaScript | `node --check` and the complete dashboard suite. |
| Any tracked change | `git diff --check`. |

## Out of scope

- physical-FCU commands, arming or thrust of any kind;
- running either physical helper, including its `check` subcommand;
- Pi-side command integration or weakening the view-only helper;
- detector, dataset, graph-query or external weekly-diary work;
- rewriting any earlier diary, dated Timeline row or historical hash.

## Forward-only hull envelope and camera person hold (13/08/2026)

Requested after Block A closed and before Block B was opened, so this sits
outside the A-E block sequence. Simulation and dashboard surfaces only. No
physical helper, Pi file, bundle checksum, MAVROS plugin list or view-only
gate was touched, and nothing here was executed against a vehicle.

### What landed

| Surface | Change |
| --- | --- |
| `control/control/heading_controller.py` | `forward_only` parameter, default `true`; non-negative clamp before the slew limiter and again in `send_thrust`; the critical-obstacle branch skips the reverse burst and falls through to the forward differential avoidance turn; escape spin drives one side only; `/perception/person_alert` subscription and a person gate above the E-Stop latch; `person_stop` and `forward_only` added to `/control/status`. |
| `plan/plan/person_stop_monitor.py` | New node. Reads `/perception/detections`, applies the person-class policy, publishes `/perception/person_alert`, and holds `/planning/emergency_stop` while stopped. |
| `plan/plan/waypoint_planner.py` | `/perception/person_alert` ingest; `blocked_reason` reports `person_detected`; `start_mission`, `resume_mission` and `go_home` refused while the hold is active. |
| Both E-Stop latch callbacks | Made idempotent, so a re-asserted latch no longer re-enters the state or re-logs on every message. |
| `launch/autoboat.launch.yaml` | `forward_only: true` on the controller; the monitor launched with its six parameters. |
| `web_dashboard/autoboat/` | `person-stop-status` badge; negative thrust drawn as an envelope breach rather than as reverse; thruster and obstacle tooltips reworded. |

### Why the clamp sits in `send_thrust`

Four controller paths can command negative thrust, and two of them — the
`-1200.0` reverse burst and the `-450.0` escape spin — return before the
`±SAFE_THRUST` clamp and before the slew limiter. `send_thrust` is the only
point all of its call sites pass through, so the clamp is applied there,
below the existing `mission_active` gate rather than above it.

### Why the person hold is a separate flag

`mission_command_callback` drops `stop_override` for any resume-family
command. A person hold sharing that latch could be cleared by pressing Start
Mission with someone still in frame. `person_stop_active` is independent and
is released only by the alert reporting the frame clear.

### The recovery contract

Two mechanisms, deliberately split, because one doing both jobs deadlocks.

The **hold** tracks what the camera can see, with `clear_hold_s` of hysteresis
against flicker. It rises when a person is in frame and falls when the frame
has been clear for that long. It never latches.

The **`/planning/emergency_stop` latch**, raised by the monitor on every tick
while the hold is up, is what stops the boat and what requires an operator to
act. Releasing the hold does not restart anything; it only restores the
operator's ability to issue a resume command, which the planner refuses while
a person is in frame.

So the sequence is: person appears, hold rises, latch stops the boat; person
leaves, hold falls after the clear window, boat stays stopped; operator
presses Resume, and only then does it move. Making the hold itself latch would
break this, because the resume command that clears the latch is exactly the
command the planner refuses while the hold is up.

This contract is proven for the simulated heading controller and planner only.
`tools/real_fcu_rc_command_bridge.py` subscribes to the same latch topic, but
its flag is set once and never cleared, and it does not subscribe to mission
commands at all — on the physical path a hold would end only by restarting
that process. The physical helper was not touched and is not wired to this
node; giving the real path a recovery route is an unanswered design question,
not something this change delivers.

### Not wired yet

Nothing publishes `/perception/detections`. The camera host publishes an
annotated image on `/hailo/overlay/image_raw` and no class labels, so the
monitor is inert until a detections publisher exists. The camera stack runs on
`ROS_DOMAIN_ID` 12 and the physical command path on 43; covering both in one
run needs a topology decision that has not been taken. Real-thrust stopping
therefore remains unproven, and no claim is made about it.

### Corrections made during review

The first draft of this work carried five defects, all found and fixed before
the change was recorded as complete.

| Defect | Correction |
| --- | --- |
| Under `forward_only` the critical-obstacle branch held station and returned, so the boat could never change the geometry keeping `is_critical` true — neither the avoidance turn, the replan request nor the anti-stuck escape could fire. A permanent zero-thrust deadlock. | The branch now skips the reverse bookkeeping and falls through to the avoidance turn, which steers away on forward differential alone. |
| The hull clamp lived only in `send_thrust`, while `prev_left_thrust` / `prev_right_thrust` stored the pre-clamp value, desynchronising the slew limiter and the drift estimator's commanded-stationary gate. | The clamp is applied before the slew store as well; `send_thrust` remains the final choke point for the paths that bypass that block. |
| A non-object JSON payload on `/perception/person_alert` parses cleanly but has no `.get`, raising `AttributeError` out of the callback and taking the node down mid-mission. | Both alert callbacks reject non-object payloads and catch the wider exception set. |
| A detection carrying a null or non-numeric score crashed the monitor, ending every future alert — a silent fail-open on the one node implementing the stopping policy. | Every entry is validated before the frame is accepted, and anything unreadable rejects the whole frame without advancing the feed clock. |
| The person badge shipped as a solid green `Clear` with no verdict behind it, and a dropped link left the last reading frozen on screen. | The badge ships `Waiting`, and the rosbridge close path resets the verdict to unknown. |
| An empty JSON object released the hold in all three consumers, and counted as a live frame in the monitor — so `{}` both cleared a safety hold and made a dead detector satisfy the feed watchdog. | The `detections` and `person_detected` fields must now be present, and the verdict must be a real boolean. Absent or non-boolean input is rejected and leaves the hold untouched. |
| The hold latched by default while the planner refused the resume command that would clear it, so a person walking away left the boat unrecoverable: `person_detected` true forever, planner `EMERGENCY_STOP`, `armed` false. | The hold no longer latches. It tracks what the camera can see with `clear_hold_s` of hysteresis, and `auto_clear` is gone. The operator-must-act property comes from the `/planning/emergency_stop` latch instead, which the monitor raises while held and which a resume command clears in the simulated stack. |
| A `NaN` score raised no exception and compared false against every threshold, so a person box carrying one read as "no person" while still advancing the freshness clock — a broken detector presenting as a clear waterway. | Every entry, whatever its class, must carry a non-empty string label and a finite score inside `[0, 1]`, booleans excluded. Anything else rejects the whole frame, so the freshness clock does not advance and `require_detection_feed` sees the detector as lost rather than clear. |
| Neither the `stop_override` nor the idle branch published `/control/status`, so once the loop dropped into them the dashboard's last word stood. After a frame cleared, the person badge stayed red until the operator resumed. | Both branches now publish, as `STOP_OVERRIDE` and `IDLE`. |
| Structurally malformed detection entries — a null, `{}`, a missing label or score, a boolean score — were skipped rather than rejected, so an unreadable frame advanced the freshness clock and read as clear water. A boolean score also became a full-confidence sighting via `float(True)`. | Every entry must carry a string label and a finite numeric score, booleans excluded. Anything else rejects the frame and leaves the clock untouched. |
| The badge went green before any camera had looked: the controller starts at `person_stop` false and the idle loop publishes immediately, and in simulation no detector runs at all. A false verdict was being rendered as a checked-and-clear one. | The monitor reports `feed_fresh`, the controller carries it and `person_verdict_known` into `/control/status`, and the dashboard shows `Clear` only for a known verdict backed by a live feed. A hold is still shown unconditionally — the safe direction never waits for corroboration. |
| `feed_fresh` was read through `bool(...)` on both sides, so the string `"false"` became true; the same message could also release an existing hold. | `person_detected` and `feed_fresh` must both be present and real booleans. Either one malformed rejects the alert outright: an active hold is kept, and a controller or planner without one gains nothing from the message. |
| The dashboard coerced the three status fields with `!!` and refreshed its staleness clock on every message, so `"false"` rendered green and a stream of field-less `{mode}` messages kept an old all-clear alive past its timeout. | `/control/status` is validated as a unit: a missing field or a non-boolean field yields no verdict at all, and such a message never restarts the staleness clock. An existing `PERSON — HOLD` stays `PERSON — HOLD`; anything else falls back, or times out, to `Waiting`. |
| The subscription callback still dereferenced the parsed payload after the verdict reader had safely rejected it, so `"null"`, `"42"` or `"[]"` — all well-formed JSON — raised `TypeError` out of the handler. `stop_override` was also still coerced. The helper-level tests could not see any of it, because they called the helper with an already-shaped object. | The handler is now one function, `applyControlStatus`, which rejects non-objects before any property is read and treats `stop_override` as a strict boolean like the rest. Tests drive it through `JSON.parse`, the way the subscription does. |
| Only an upstream-declared stale feed was handled; upstream going silent was not. After one valid all-clear a dead monitor left `person_feed_fresh` true for ever, republished at 20 Hz, and the dashboard had no age check of its own. | Two independent timeouts, each against a locally stamped receipt time: the controller ages out a silent monitor after `person_alert_timeout_s`, and the dashboard ages out a silent controller after five seconds. Neither can downgrade an active hold. |

Removing `auto_clear` also left a startup log line referring to it, which
would have raised `AttributeError` the first time the node was launched. Every
stub test still passed, because they drive unbound methods and never build the
node. `plan/test/test_person_stop_monitor_construction.py` now constructs the
real node, parses `launch/autoboat.launch.yaml`, and drives the node's real
publishers. Its parameter check is bounded: it asserts that every parameter the
launch file sets is declared by the node and carries the node's default value.
Parameters the launch file does not set — `publish_rate_hz` today — have no
drift protection from it.

Three of the new tests were also passing vacuously: the `go_home` refusal was
being satisfied by a swallowed stub `AttributeError` rather than by the guard,
the `blocked_reason` release assertion never reached the branch it named, and
nothing exercised `publish_alert` — the only place this node publishes the
shared safety latch. All three were rebuilt and confirmed by mutation: deleting
the guard, or restoring the deadlock, now fails the suite. What that latch does
downstream on the physical path remains unwired and unproven; see the recovery
contract above.

### Verification

| Check | Result |
| --- | --- |
| `plan` focused suite | 63 passed, 1 skipped |
| `control` focused suite | 29 passed, 1 skipped |
| Dashboard suite | 76 passed |
| Real node construction and launch-file parameter agreement | pass |
| `node --check app.js` | pass |
| Launch file parse | 6 nodes |
| `git diff --check` (tracked changes) | no whitespace errors |
| `git diff --no-index --check` per new file | no whitespace errors |

### Recorded: how the real thrust is actually unlocked

Stated by the maintainer on 13/08/2026. Recorded here because it was not
written down anywhere and does not follow from the code. Nothing below was
executed, and it authorizes nothing.

Two separate human actions gate the physical thrust, in this order:

1. The FCU boots disarmed with the hardware safety engaged.
2. Press the physical arm/safety button on the FCU box. This is the hardware
   safety release; `BRD_SAFETY_DEFLT=1` means outputs stay dead until it is
   done, and no software path can substitute for it.
3. Wait for the bridge to report `READY_DISARMED`.
4. Arm from QGroundControl on the Herelink console.
5. Only then can the servo rail follow a command.

This matches the existing state machine rather than changing it. The bridge
requires an observed `armed:false → true` transition before it will enter its
authorized arm epoch, and still passes through disabled and dead-man priming
before `ACTIVE`.

Two limits worth stating plainly. The bridge observes `/mavros/state.armed`,
so it can prove a transition happened but not that the arm command came from
the Herelink console; if that provenance ever becomes an acceptance condition
it needs separate operator evidence. And the Pi's transmit direction to the
FCU has never worked, so Herelink remains the only proven command path — a
dashboard-initiated arm is not on the table today.

Shutdown reverses it: release the command first, disarm from QGroundControl,
then tear the helper down.

### Effect on Block B

The worktree is no longer clean, and `tools/sitl_digital_twin_runner.sh`
requires a clean worktree with `HEAD == origin/main`. The corrected SITL
acceptance stays available once this work is committed and pushed, or stashed.

## Block B correction - float32 command evidence (13/08/2026)

**Block B was NOT RUN.** A handover was prepared, reviewed against source, and
withdrawn before anything started. No simulator, MAVProxy, MAVROS, bridge,
rosbridge, dashboard, browser or operator command was executed, and the vehicle
was never armed. What follows is a static defect found during that review.

### The defect

`/command_ingress/rc_axes` is a `sensor_msgs/Joy`, whose `axes` field is
`float32[]`. A dashboard demand of `0.10` is therefore quantised in transit and
read back widened, and the bridge copies the same quantised value into its
status JSON. The evidence comparator compared those values with
`rel_tol=0.0, abs_tol=1e-9` - a bound tighter than float32 rounding itself, so
three of the four demanded axis values could never match:

| Demand | After float32 | Absolute error | Within `1e-9` |
| --- | --- | --- | --- |
| `+0.10` | `0.10000000149011612` | `1.49e-09` | no |
| `0.08` | `0.07999999821186066` | `1.79e-09` | no |
| `0.09` | `0.09000000357627869` | `3.58e-09` | no |
| `-0.04` | `-0.03999999910593033` | `8.94e-10` | yes |

Both halves of each gate failed: the Joy axes and the bridge's echoed status
carry the same rounding. The run would have reached `SITL_SESSION=READY`,
completed safety-off and a live arm, then blocked in `sitl_wait_for_file
positive` for the full `SITL_OPERATOR_TIMEOUT_SECONDS`, emitted
`SITL_PHASE_FAIL phase=positive rc=1 reason=timeout`, exited `1`, and finalised
a `FAIL` verdict - after the vehicle had been armed.

The focused suite could not see it. Its `joy()` and `status_payload()` fixtures
built plain Python dicts holding float64, so no assertion ever crossed the
float32 boundary that a real message forces.

### The fix

A named `FLOAT32_COMMAND_TOLERANCE = 1e-6`, with `rel_tol=0.0` retained. That is
above float32 noise and still four orders of magnitude below the `0.01` slider
step, so an adjacent slider position stays distinguishable. The demanded axis
values are unchanged.

The fixtures now quantise through `struct.pack('f')`, so the ordered-capture
assertions fail against the old bound and pass against the new one. Three cases
were added: float32 rounding alone opens the positive gate, an adjacent `0.01`
step on either axis does not, and the tolerance sits between the two scales.
Both directions were confirmed by mutation - `1e-9` fails three tests, `0.02`
fails five. The tolerance is also pinned outright at `1e-6`, because the two
bounds admit a range and the value inside it is a choice; the upper bound is
asserted against `0.01 / 10_000`, since a `* 100` bound would prove only two
orders of magnitude and still admit `5e-5`.

The two operator-facing safety prompts are asserted by the runner's focused
suite rather than left as prose: deleting the do-not-interrupt warning, or
reverting the E-Stop prompt to the non-existent bench control, each fails a
named case.

### Corrected E-Stop location

The runner previously said "press the FCU bench E-Stop once". The FCU Bench
panel contains only `btn-fcu-loop-neutral` and `btn-fcu-loop-hold`; there is no
E-Stop in it. The control is `btn-emergency-stop` in the Mission Control panel,
or the header and footer E-STOP badges. The prompt now names it.

### Never interrupt a printed operator command

`sitl_operator_once.py` claims its gate with `O_EXCL` before opening the MAVLink
link, and `KeyboardInterrupt` is not caught by its `except Exception`. Ctrl+C
therefore leaves a claim file with no result, every re-run is refused as already
claimed, and the phase can only time out. The runner now prints this warning
beside each operator command. The recovery logic itself is untouched and remains
separate hardening.

### Expanded adjudication capture

The prepared Terminal 3 extraction covered `evidence/`, `control/` and
`captures/` only. A contested or failed run also needs:

- `supervisor.log` - the durable record of supervisor phase transitions,
  `SITL_PHASE_FAIL` lines, the stop sequence, `SITL_LOGS` and
  `SITL_SUPERVISOR_EXIT`;
- `logs/` - per-child output, `bridge.log` and `sitl.log` above all;
- `manifest/commands.tsv` - the exact child command vectors, whose hash appears
  in `startup.json` but whose content does not.

Two markers never reach `supervisor.log` and must be read from the terminal:
`SITL_MAVROS=READY`, which the snapshot subprocess writes to
`logs/mavros_snapshot.log`, and `SITL_VERDICT`, which finalize prints on its own
stdout. A post-run grep of `supervisor.log` finds eight of the ten.

### Confirmed unaffected

`296f1794` does not touch this run. The SITL supervisor starts exactly seven
children - `sitl`, `mavproxy`, `mavros`, `bridge`, `evidence`, `rosbridge`,
`dashboard` - and never launches `launch/autoboat.launch.yaml`, so the person
monitor, planner and controller are absent from the graph. `waypoint_planner`
appears only in the conflict-detection list. `tools/sitl_digital_twin_evidence.py`
is in no pinned bundle, so no checksum is regenerated.

One limit worth recording: the one-browser-tab rule is operator-enforced only.
rosbridge shares a single publisher per topic across websocket clients, so the
`publisher=1` gate reads `1` with two tabs open and cannot detect the second.

## Post-run adjudication helper (13/08/2026)

**Block B remains NOT RUN.** This adds the adjudication step as a tested file
and changes nothing about how a run is performed.

### Why a file rather than a pasted block

The prepared Terminal 3 extraction was about 120 lines of quoting-sensitive
shell, executed once, at the least recoverable moment of an unrepeatable run.
Reviewing it as text found three faults that a file would have made impossible:

| Fault | Effect if it had been run |
| --- | --- |
| `ardurover` written with Cyrillic `U+0443` and `U+0440` | `pgrep` can never match, so a surviving simulator reports the host clean - fail-open on the one check that proves teardown finished |
| Heredoc terminator indented under `<<'PY'` | `here-document delimited by end-of-file`; the whole extraction fails to parse, after the run is over |
| Conflict patterns interpolated into a wrapper command line | the check matches its own argv and reports a conflict on every clean run |

### The helper

`tools/sitl_digital_twin_adjudicate.sh` takes exactly one absolute run
directory and never discovers a run on its own, because adjudicating the wrong
directory is worse than adjudicating none. It is read-only: it does not write
inside the run directory and does not start, stop or signal any process. The
focused suite asserts the run directory is byte-identical afterwards.

Every one of the fourteen required artifacts must decode as a JSON object. A
JSON `null` decodes to Python `None`, which read as "nothing to validate" and
let a null artifact bypass every check behind it; `None` is now only ever a
failure sentinel, never a decoded value. The shape is enforced twice
independently, once where the artifact is printed and once in the verdict
checks, and the required set is taken from the helper's own array so the printed
and validated sets cannot drift apart.

It prints the required evidence and control JSON, `supervisor.log`,
`manifest/commands.tsv`, the manifest and log inventories with log content,
capture line counts and retained hashes. It then decides independently rather
than trusting the run's own summary, requiring: verdict `PASS` with
`session_complete` true and `missing` empty; teardown `pass` true; `cleanup_rc`
zero with `children_stopped` and `ports_free` true; the seven-item stop order
written out in full; `evidence_sha256` holding exactly the ten phase artifacts,
each key resolving inside the run directory and still matching the file on disk;
`control/teardown_runtime.json` and `control/shutdown_frames.json` agreeing with
the copies teardown embeds, and `control/disarm_release_frames.json`, which
teardown does not embed, checked independently - both frame lists holding
exactly three frames; `cleanup_rc` being integer zero rather than merely equal
to zero, in verdict, teardown, the embedded runtime and the control runtime,
since `False == 0` and `0.0 == 0` in Python while the supervisor writes an int;
`capture_fault` null in both verdict and teardown and equal to each other, with
no `control/capture_fault.json` present at all; the five ports free on the host
now; and no conflicting process alive.

The process check excludes this script and its ancestors. A shell that merely
mentions a pattern on its command line is not a surviving simulator, and
counting one would report a conflict on every clean run - the same self-match
hazard that made the pasted block unusable.

Diagnostics keep gathering past the first fault, so a failed run is adjudicated
in one pass. The final line is always exactly one of `SITL_ADJUDICATION=PASS` or
`SITL_ADJUDICATION=FAIL`, and the exit status matches it.

An uninspectable host is not a clean host: if `ss` or `pgrep` fails, the
adjudication fails rather than reporting free.

### Coverage

Twenty-five cases were added to `tools/test_sitl_digital_twin_runner.sh`,
taking it from the committed baseline of `12` to `37`. Beyond the passing fixture and the argument
contract they cover a missing artifact, malformed JSON, `pass` false, a reversed
stop order, tampered evidence caught by hash, an unclean runtime block, a hash
map reduced to a single artifact, hash keys that escape the run by absolute or
traversal path, a control runtime contradicting the embedded copy, empty frame
lists, a non-zero verdict `cleanup_rc` with a recorded capture fault, a
`control/capture_fault.json` artifact, a `cleanup_rc` written as `false` and as
`0.0`, every one of the fourteen required artifacts written as `null` in turn,
an array and a scalar where an object belongs, a simulated `ss` failure, a
parent process whose argv mentions
`ardurover` - which must not count as a survivor - and a real temporary process
named `ardurover`, which proves the pattern matches a live process as a
homoglyph never would. A whole-file ASCII guard fails on any
non-ASCII byte.

The passing-fixture case asserts real host state deliberately, since the port
and process checks cannot be faked. A failure there showing `OCCUPIED` or
`SURVIVING` means the host is dirty, not the helper.

### Supersedes the Block B instructions above

Append-only correction. Where this section and the Block B instructions earlier
in this file disagree, this section governs. Two steps are superseded:

| Superseded | Replaced by |
| --- | --- |
| Step 8, "release Apply, then press the bench E-Stop once" | Release Apply, then press EMERGENCY STOP once: `btn-emergency-stop` in the Mission Control panel, or the header or footer E-STOP badge. The FCU Bench panel has no E-Stop button. The runner now prints this. |
| The Terminal 3 inline extraction block | `tools/sitl_digital_twin_adjudicate.sh "$RUN"`, run after Terminal 1 exits, with `RUN` set to the exact `SITL_LOGS=` path. |

There is one execution path. The earlier inline block is incomplete rather than
wrong: it has no process check at all, so it can neither detect nor misreport a
surviving simulator. The Cyrillic homoglyph belonged to the expanded handover
that was withdrawn before it ran, and is recorded above only as the reason this
step became a tested file.

### Adjudication pin

Separate from the operational pin surfaces. The nine Pi-helper hash
occurrences, one helper size, two supervisor-hash occurrences and one supervisor
size - thirteen surfaces in total - are unchanged by this work.

| Field | Value |
| --- | --- |
| Path | `tools/sitl_digital_twin_adjudicate.sh` |
| Size | `19656` bytes |
| SHA-256 | `790fd46202726d53198fc9444913de421144562cbe1416497a6f3d84333687f3` |
| Mode | `100755` |

Invocation, the only supported form:

```bash
tools/sitl_digital_twin_adjudicate.sh "$RUN"
```

## Wrap

One conventional commit subject per logical change, one line, at most 72
characters. Stage by explicit path. Before committing:

```bash
git status --short --branch
git diff --check
git diff --cached --name-status
git diff --cached --check
```

Inspect the staged content and confirm no intended implementation, test or
documentation file is missing.

Never predict or record the SHA of the commit that contains the day-close text.
Record the pre-edit baseline while drafting. If a landed implementation revision
must be recorded, append it in a later documentation commit; do not attempt to
record that documentation commit's own SHA. This series has produced three
self-referential revision claims that were stale the moment they landed.

## Block B first execution and runner corrections (13/08/2026)

**Outcome: FAIL, NOT RERUN.** The first execution used pre-edit baseline
`cb6524c6f05134c5fb973fe9a215652ed6176d5c` and created:

```text
/home/ghostzero/Desktop/sitl_digital_twin_20260813_145244
```

The preflight passed, the direct Rover child started under the supervisor and
its output reached `logs/sitl.log`. The run then failed at the first listener
gate after `45 s`:

```text
SITL_PHASE_FAIL phase=sitl-listener rc=1 reason=timeout
SITL_VERDICT=FAIL
SITL_SUPERVISOR_EXIT status=1 trigger=exit signal=none stop_phase=sitl-start failed_phase=none cleanup_rc=1 finalize_rc=1
```

No operator gate opened. Safety-off, browser startup, arm, command demand,
E-Stop and disarm were not reached; MAVProxy, MAVROS, the command bridge,
evidence recorder, rosbridge and dashboard never started. The only child was
Rover, and the supervisor stopped it. A later host check found all five Block B
ports free and no conflicting process. The user-run adjudicator exited `1` with
`SITL_ADJUDICATION=FAIL` and independently reported the same clean host state.

### Listener-order deadlock

The earlier 11/08 failure never launched Rover directly, so it could not expose
this ordering defect. This run did. `logs/sitl.log` ends with:

```text
bind port 5760 for SERIAL0
SERIAL0 on TCP port 5760
Waiting for connection ....
```

The pinned ArduPilot source defaults SERIAL0 to `tcp:0:wait` and SERIAL1 to
`tcp:2`. The `wait` flag blocks in `accept()` after opening `5760`, before Rover
finishes initialisation and opens `5762`. The runner simultaneously required
both listeners before it started the MAVProxy client for `5760`. Neither side
could advance.

Accepting only `5760` is not a repair: the one-shot operator helper requires
`tcp:127.0.0.1:5762`. The direct Rover command now makes both endpoints
explicit as `--serial0 tcp:0 --serial1 tcp:2`. Removing `wait` from SERIAL0
allows initialisation to continue while retaining the strict requirement that
the same pinned Rover PID owns both listeners before MAVProxy starts. This is a
source-level correction only until the user-run acceptance reaches
`SITL_PROCESS=READY`.

### Teardown-accounting defect

The run also exposed a separate defect that would fail a fully successful
acceptance. `sitl_children_stopped_once()` returned the status of its final
false `group_alive` check because it had no explicit success return. A clean
set of stopped process groups therefore produced `children_stopped=false` and
forced `cleanup_rc=1` even though the host was clean. The function now returns
`0` after checking every registered group.

The focused teardown case drives `sitl_write_teardown_runtime 0` with two
registered but absent groups and free sockets, then requires exact JSON:
`cleanup_rc=0`, `children_stopped=true`, `ports_free=true` and the complete
seven-item stop order.

### Red-green evidence and retry gate

The command case failed first against the prior runner with:

```text
FAIL: SITL command does not open both MAVLink listeners without blocking on SERIAL0
```

After only the serial arguments changed, the independent teardown case still
failed with:

```text
FAIL: clean child groups were reported as alive
```

After the explicit success return, the focused host-context suite passed
`cases=38`. No simulator or downstream child was started by these checks. The
adjudication helper remains byte-identical at its `19656`-byte, `100755`,
SHA-256 `790fd46202726d53198fc9444913de421144562cbe1416497a6f3d84333687f3`
pin; the thirteen Pi/supervisor operational pin surfaces are unchanged.

Block B is closed while these edits are uncommitted. A retry requires the
changes to land and push, followed by a fresh clean/synced certification and
free-port/process check. Do not reuse the failed run directory and do not start
Block C.
