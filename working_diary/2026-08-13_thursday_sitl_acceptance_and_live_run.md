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

## Block B second execution and MAVProxy readiness correction (13/08/2026)

**Outcome: FAIL, NOT RERUN.** The second execution used pre-edit baseline
`ad8461ac4629b5e36beba45b2f5a19c83ef9d60b` and created:

```text
/home/ghostzero/Desktop/sitl_digital_twin_20260813_151522
```

The runner passed the corrected two-listener gate and printed the required
runtime repair signal:

```text
SITL_PROCESS=READY frame=motorboat-skid instance=0 ports=5760,5762
```

This proves the `tcp:0:wait` deadlock from the first execution is removed. The
runner then started workstation-local MAVProxy, but its readiness gate timed
out after `45 s`:

```text
SITL_PHASE_FAIL phase=mavproxy rc=1 reason=timeout
SITL_SUPERVISOR_EXIT status=1 trigger=exit signal=none stop_phase=mavproxy-start failed_phase=none cleanup_rc=0 finalize_rc=1
```

No operator gate opened. MAVROS, the command bridge, evidence recorder,
rosbridge, dashboard, browser and arm phase were not reached. The Pi and
physical FCU were not involved. `logs/mavproxy.log` nevertheless proves that
the relay connected to `tcp:127.0.0.1:5760`, received the vehicle heartbeat and
continued receiving live autopilot output:

```text
Detected vehicle 1:1 on link 0
MANUAL> AP: ArduPilot Ready
```

The control runtime recorded `cleanup_rc=0`, `children_stopped=true`,
`ports_free=true` and stop order `mavproxy, sitl`. This partial teardown is the
first runtime proof of the explicit success return added after the first
execution. It is not proof of the complete seven-child stop order.

### Unsatisfiable MAVProxy marker

The connection was healthy; the readiness text contract was impossible. The
runner launched MAVProxy with `--target-system=1` but waited only for:

```text
online system 1
```

Installed MAVProxy `1.8.74` guards that message in
`MAVProxy/modules/mavproxy_link.py` with
`self.settings.target_system == 0`. The runner fixes the target to `1`, so the
branch at line `743` cannot execute. The same module emits the observed
`Detected vehicle {system}:{component} on link {link}` message independently at
line `990`.

The readiness predicate still requires exactly one established connection
whose local port is `5760`, then now requires the exact fixed identity string:

```text
Detected vehicle 1:1 on link 0
```

The complete literal rejects the wrong system, component and link. In
particular, the fixed `Detected vehicle` prefix prevents system `11` from
matching system `1` as a substring.

### Child-log producer contract

The runner has three unique fixed-string consumers for child logs, not two:

- `mavproxy.log`: `Detected vehicle 1:1 on link 0`;
- `bridge.log`: `live guard resolved:`;
- `evidence.log`: `SITL_CAPTURE=READY subscriptions=5`.

The focused suite now enumerates that exact consumer set and checks each
producer source. The MAVProxy source is resolved from the interpreter beside
the configured `mavproxy.py`; the bridge and evidence producers are checked in
their tracked source files. A consumer addition or wording drift therefore
requires an explicit producer contract update.

The exact identity case failed first against the previous predicate:

```text
FAIL: MAVProxy readiness identity contract failed: exact vehicle identity was rejected
```

After the one-line predicate correction, the host-context focused suite passed
`cases=40`. The passing identity is tested alongside wrong system `2`, boundary
system `11`, wrong component `2` and wrong link `1`. Both shell files pass
`bash -n`. No simulator, MAVProxy, middleware or other Block B child was
started by these checks.

The adjudication helper and the thirteen Pi/supervisor operational pin surfaces
are unchanged. Block B is closed while these edits are uncommitted. A third
execution requires commit, push, clean/synced certification and fresh
port/process checks. Do not reuse either failed run directory. Block C remains
closed.

## Block B third execution and Block C scope supersession

### Block B third execution - functional path complete, teardown failed

The third user-run attempt used
`/home/ghostzero/Desktop/sitl_digital_twin_20260813_153821`. It reached every
functional acceptance phase:

- `SITL_PROCESS=READY` with listeners `5760,5762`;
- `SITL_MAVPROXY=READY`, `SITL_MAVROS=READY`, the bridge guard and evidence
  capture ready;
- safety-off, browser publisher/disabled-frame readiness and
  `SITL_SESSION=READY`;
- normal arm, positive `+0.10/0.08`, release, negative `-0.04/0.09`, the FCU
  bench E-Stop and normal disarm;
- `SITL_ACCEPTANCE=COMPLETE teardown=pending`.

The E-Stop produced the expected `FCU bench emergency stop latched` feedback;
this is a status toast, not a confirmation dialog. Disarm is retained in both
`operator/disarm.json` and `evidence/disarm.json`, and
`control/disarm_release_frames.json` contains the three release frames.

Automatic teardown then terminated at
`tools/sitl_digital_twin_runner.sh:676` with `sitl: unbound variable`. The
successful return path had sourced the runner inside
`run_sitl_digital_twin_entry`; its plain `declare -A` and `declare -a` arrays
were therefore function-local. They disappeared before the script-level EXIT
trap used them. Earlier failure paths exited while that function scope was
still active, which is why they did not expose the lifecycle defect.

The run produced neither `evidence/teardown.json` nor
`evidence/verdict.json`, so Block B remains **FAIL at teardown** and the
independent adjudicator was not run. A run-specific, checksum-verified manual
cleanup stopped the six remaining child groups with `SIGINT`; SITL was already
absent. It ended with:

```text
SITL_MANUAL_CLEANUP=PASS run_dir=/home/ghostzero/Desktop/sitl_digital_twin_20260813_153821 ports=free
```

Fresh host inspection then found TCP `5760`, `5762`, `8002`, `9090` and UDP
`14600` free and all twelve Block B conflict patterns absent. The browser was
closed. This measured state replaces the missing teardown artifact only as the
clean-host prerequisite for today's Block C; it does not turn Block B into a
pass. The narrow future runner repair remains global array declarations plus a
regression for function-scope source, successful return and EXIT teardown.

### Block C now includes the real-FCU live arm observation

The maintainer explicitly expanded today's Block C. Its passing contract now
contains two sequential phases:

1. **C1 - view-only telemetry:** transfer and verify the stale Pi helper, run
   the established workstation/Pi supervisors, require seven-topic arrival and
   six fresh browser badges, then stop Pi first, workstation second and browser
   last.
2. **C2 - real-FCU arm/disarm:** only after C1 records Pi `TEARDOWN=PASS`,
   `PI_SUPERVISOR_EXIT status=0`, workstation `WORKSTATION_TEARDOWN=PASS`, and
   a fresh absence check. With propellers removed, propulsion power isolated,
   hull restrained and controls neutral, release the FCU-box hardware safety
   state, arm from QGroundControl on the Herelink, observe the armed state
   without non-neutral input, then disarm from QGroundControl and observe the
   disarmed state.

C2 is part of Block C for 13/08/2026 and is not assigned a separate block name.
It cannot overlap C1: `tools/pi_live_hailo_mavlink_dashboard.sh` requires
`armed:false`, rechecks it during the run and aborts on `armed:true`. No helper
is weakened or changed, and no repository process runs during C2.

Source review also invalidated both planned click discriminators. View-only
initialisation makes the Mission Control buttons, including E-Stop and joystick
enable, inert and disabled before a click can dispatch. The named `hold`
mission command has no dashboard caller; the only HOLD control is the separate
FCU-bench control. Therefore neither blocked-write string is an observable
browser criterion in C1. The view-only evidence is the static final-send guard,
disabled/inert control state and the runtime command sentinel reporting zero
messages. The runbook now states this instead of asking the operator to click an
unreachable path.

This scope revision and runbook preparation are documentation only. Block C has
not started at the time of this entry. The pre-edit repository baseline is
`fe69c089e093f2fa46e09926342a9a879dfdcdbc`; the two operational helper pins
remain `73,862` bytes / `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97`
and `29,058` bytes / `d101ec5840c1358e0475fff33989af9b3f3431231859c0e0e1c2ffa0fafab82a`.

### C1 operator result recorded before artifact review

C1 subsequently ran with workstation directory
`/home/ghostzero/Desktop/live_dashboard_workstation_20260813_165355` and Pi
directory
`/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260813_165410`.
Before launch, the stale Pi helper was replaced with the tracked `73,862`-byte
copy and verified at
`a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97`
on `imtaquadrone-desktop` (`10.120.2.249`).

The pasted workstation rate output reports seven passing `10`-second probes:

| Topic | Samples | Mean rate |
| --- | ---: | ---: |
| `/hailo/overlay/image_raw` | `73` | `7.34 Hz` |
| `/mavros/state` | `10` | `1.00 Hz` |
| `/mavros/global_position/raw/fix` | `10` | `1.00 Hz` |
| `/mavros/imu/data` | `10` | `1.00 Hz` |
| `/mavros/battery` | `10` | `1.00 Hz` |
| `/mavros/rc/in` | `10` | `1.00 Hz` |
| `/mavros/rc/out` | `10` | `1.00 Hz` |

The Pi transcript reached `COMMAND_SENTINEL=PASS messages=0`,
`PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=100s
elapsed=220s peak=66C` and `PI_SOURCE_HOLD=ACTIVE`. Its final raw output sample
was left `SERVO3 800`, right `SERVO1 800`, delta `0`. The operator reported
the Hailo overlay streaming correctly in both required views, one continuing
browser stream, working viewer controls, `Connected`, all six freshness badges
`Live` at `0.4 s`, `Disarmed`, mode `HOLD`, system state `Critical (5)`, and
neutral raw output `800/800`. GPS `No fix (-1)` with `100.00 m` horizontal
accuracy was retained as telemetry state rather than treated as transport loss.

Shutdown followed the required order. Pi P1 first recorded
`PI_SOURCE_HOLD=STOP operator-requested`, `TEARDOWN=PASS` and
`PI_SUPERVISOR_EXIT status=0 ... cleanup_rc=0`; workstation W1 then recorded
`WORKSTATION_TEARDOWN=PASS` and `SUPERVISOR_EXIT status=0 ... cleanup_rc=0`.
The Pi directory was copied to
`/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260813_165410`;
the operator's copy command reported `P1_LOG_COPY=PASS`, `20` files and `912K`.

These are operator-pasted results pending the local W1/Pi artifact review
below. They establish the C1 handoff state but do not close all of Block C:
the separately sequenced C2 live arm/disarm observation has not yet run.

### C1 local artifact audit - PASS

The retained workstation directory contains `12` files and the copied Pi tree
contains `20` files. The copied Pi tree has `848,384` apparent bytes; the
operator's filesystem-allocation report was `912K`. No source-side checksum
manifest was created on the Pi, so this review establishes the contents of the
received copy but does not claim cryptographic identity for the complete remote
and local trees.

The principal local evidence pins are:

| Artifact | SHA-256 |
| --- | --- |
| W1 `supervisor.log` | `35c99b8ae9668f43631a8befed4a42b61bfabdf14c98627c3dcdd9181d16860b` |
| W1 `w5_live_rates.log` | `fc6e00a414003a3f2c0ff7e892d1b5c02acdda7b5b18923e1a8a9723164c45b2` |
| copied P1 `supervisor.log` | `c22b8b2bdbde2892ed03e75368591a5a4857ee564e04d8fd6851bf1e7dfe2655` |
| copied P1 `thermal_peak_mc.txt` | `26980c4904f0d71f11c56b7a41fa57ceb17f47863aa71d98b06c5b267961ce09` |
| copied P1 `safety_monitor.log` | `410f916d69cf8f31a68be6813af54319f0bf55902d95afde13869c9cb19a563f` |

W1 independently records `WORKSTATION_RUNTIME_PREFLIGHT=PASS`,
`PI_DATA_ARRIVED=PASS topics=7`, `W5_RATE_PROBES=PASS topics=7`, supervision,
and an orderly `SIGINT` teardown ending in `WORKSTATION_TEARDOWN=PASS` and
`SUPERVISOR_EXIT status=0 ... failed_phase=none cleanup_rc=0`. The arrival logs
contain one bounded sample run for every required topic: overlay `7.49 Hz`, RC
input `0.99 Hz`, and the other five telemetry topics `1.00 Hz`. The later W5
probe matches the operator-pasted rates. Rosbridge had one concurrent browser
client: the first client disconnected before its replacement connected after
the hard refresh. Its `rosapi` exit code `-2` and the web-video-server signal
handler occur only after the supervisor initiated the intended `SIGINT`
teardown.

The copied P1 supervisor records the command sentinel ready with zero
publishers, `COMMAND_SENTINEL=PASS messages=0`, the complete `220`-second source
window, the live hold, and exit status `0`. The retained state sample is
`connected:true`, `armed:false`, mode `HOLD`, system status `5`; battery is
present at `16.061 V`; RC input has zero channels with raw RSSI `255`; and raw
output is the real-boat neutral pair `SERVO3 800` / `SERVO1 800`. The safety
monitor log contains only its readiness line and the thermal-watchdog log is
empty. There is no `FCU_ARMED`, command violation, terminal source failure or
thermal stop marker.

Several daemonless graph queries transiently reported publisher count `0` for
state, IMU or RC output. Each recovered inside the helper's three-attempt
source check: no topic reached the terminal third-attempt failure, all six
source samples had already passed, the helper continued, and W1 later received
and rate-probed all six telemetry topics. The final
`PI_SOURCE_STACK_READY=PASS mavros_topics=2` value is only the count from that
single final graph snapshot; it is not the six-topic acceptance count.

The exact thermal-watchdog maximum is `68,300 mC` (`68.3 °C`). It supersedes
the coarser supervisor samples whose displayed maximum was `66C`; no thermal
abort occurred. The repeated MAVROS no-fix warning agrees with the retained GPS
sample and does not indicate transport loss. MAVROS also exhausted the optional
`AUTOPILOT_VERSION` query and used its default capabilities, while telemetry
continued. MAVProxy's terrain file-list decode warning did not interrupt the
link. Hailo published at least `5,000` frames before its final
`KeyboardInterrupt`, whose stack occurs after the operator's `SIGINT` and is
therefore teardown output rather than a live-window crash.

Timestamp comparison proves the required shutdown order. P1 recorded
`TEARDOWN=PASS` at `1786633663.993761` and exit status `0` at
`1786633663.994201`. W1 did not begin its stop until `1786633673.481508`,
`9.487307 s` after the Pi exit, and then completed its own teardown. A fresh
host-context check after both exits found TCP `8002`, `8080`, `9090` free and
all six checked C1 process patterns absent.

C1 is therefore **PASS** for bounded simultaneous view-only image and six-topic
telemetry delivery, zero dashboard command messages, observed disarmed state,
neutral raw output and Pi-first teardown. This does not establish a GPS fix,
servo proportionality, dashboard/Pi command transmission, autonomous control
or thrust. C2 remains **NOT RUN**, so the expanded Block C is not yet closed.

### C2 pre-execution handover correction - NOT RUN

Review before the live arm found that the initial C2 handover omitted
`serve_dashboard.py` from the workstation process pattern even though
`tools/live_dashboard_preflight.sh` both lists it as a conflict and starts it
as the port-`8002` dashboard child. The revised W2 absence check names that
process explicitly, retains the `8002`, `8080`, `9090` listener check and uses
bracketed patterns to avoid self-match. A separate P2 one-shot check covers the
Pi helper, MAVProxy, MAVROS, Hailo wrapper, command safety monitor and thermal
watchdog. Both checks run in subshells, source no ROS environment and start no
service.

The bounded observation now has an additional pre-arm gate. Before releasing
the FCU-box hardware safety state, the operator must verify that the installed
Herelink QGroundControl build exposes MAVLink Inspector, select the current
vehicle's `SERVO_OUTPUT_RAW`, record its source system, source component and
`port`, and observe `time_usec` advancing. A visible but frozen row is not live
evidence. The actual `servo3_raw` and `servo1_raw` values are recorded rather
than pre-filled; both must be `800` while disarmed or the arm does not proceed.

Only one QGroundControl arm request is permitted. A rejection is recorded as
`C2_ARM=REJECTED retry=NO` and ends the attempt. If accepted, the operator
records the arm time, `Armed` indication and live raw pair without moving a
control or requesting non-neutral output. A persistent departure from the
observed `800` baseline, unexpected actuator movement or QGroundControl link
loss requires immediate disarm. After normal disarm, the final live pair and
time are recorded, both outputs must be `800`, and the physical FCU-box safety
state is re-engaged and confirmed before anything else is touched.

This observation cannot close the tier prerequisites. `SERVO_OUTPUT_RAW`
contains current output values but no `SERVO*_FUNCTION` assignment and no
configured `MIN/TRIM/MAX`; it therefore proves neither left/right function
mapping nor the complete rail. After its full parameter pull, the current T0b
implementation retains and validates only the three `BRD_SAFETY_*` values; its
standalone evidence remains absent, and Block B remains failed at teardown. C2
can add the first armed raw-output observation for this hull under today's
explicit scope exception, but it is not T0b or T2a closure and must not be
reported as such.

The corrected paste-back contract is:

```text
C2_PI_ABSENCE=PASS
C2_WORKSTATION_ABSENCE=PASS ports=8002,8080,9090
C2_BROWSER=CLOSED
C2_QGC_INSPECTOR=PASS message=SERVO_OUTPUT_RAW source_system=N source_component=N port=N time_usec=ADVANCING
C2_OBSERVATION before=DISARMED servo3_before=N servo1_before=N arm_time=HH:MM:SS armed=ARMED servo3_armed=N servo1_armed=N actuator_movement=NO disarm_time=HH:MM:SS final=DISARMED servo3_after=N servo1_after=N hardware_safety=ON qgc_link=STABLE
```

No C2 process, Inspector check, hardware-safety release or arm request was run
while making this documentation correction. Production code, both physical
helpers and the two operational pin surfaces remain unchanged.

### C2 rejected-arm restoration clarification - NOT RUN

Final handover review found one incomplete exit path. The one permitted arm
request occurs after the physical safety state is released, but the rejection
branch previously said only to avoid a retry and stop for diagnosis. It now
requires the operator to confirm that the FCU remains `Disarmed`, re-engage and
confirm the physical safety state, then report:

```text
C2_ARM=REJECTED retry=NO final=DISARMED hardware_safety=ON
```

The general stop condition now states that every exit after physical-safety
release, whether the arm is rejected, accepted normally or aborted on an
unexpected observation, must end with confirmed `Disarmed` state and the
physical safety state re-engaged. This clarification is documentation only;
C2 remains **NOT RUN**.

### C2 stick, safety-release and Inspector-failure gates - NOT RUN

Final pre-run review added three discriminating observations. First, the
Herelink sticks must remain untouched throughout C2. ArduPilot source defines
`ARMING_RUDDER=2` as rudder arm-or-disarm, so a full-yaw RC input can be a
separate state-transition request and must not be confused with the one
permitted QGroundControl button press. The cited 10/08/2026 repository record
at lines `912`-`915` is explicitly from the connected SITL instance, not a
current real-FCU parameter readback; this entry therefore does not claim that
the physical FCU's live `ARMING_RUDDER` value was revalidated today. RC input
PWM and `SERVO_OUTPUT_RAW` PWM are different layers and are not compared.

Second, release of the FCU-box hardware safety state now has its own
observation before the QGroundControl arm request:

```text
C2_SAFETY_RELEASED servo3=N servo1=N time_usec=ADVANCING
```

Both outputs must remain `800` while `time_usec` advances. A change at this
point ends the attempt without an arm request: hardware safety is re-engaged
and the observed values are retained. An armed-state transition before the
intended QGroundControl button press likewise requires immediate disarm,
hardware-safety restoration and stop.

Third, an unavailable or stale Inspector path now has an explicit pre-arm
result:

```text
C2_QGC_INSPECTOR=FAIL reason=<not-present|no-servo-output-raw|time_usec-static> armed=NO hardware_safety=ON
```

A static `time_usec` cannot support a neutral-output claim. This failure path
stops before the physical safety state is released. The successful paste-back
contract now includes the intermediate `C2_SAFETY_RELEASED` line. These are
documentation-only corrections; no P2 or W2 command, Inspector interaction,
hardware-safety release or arm request was run.

### Real-FCU rudder-arming status clarification - NOT RUN

A wider repository search sharpened the preceding note. No current or historical
real-FCU readback of `ARMING_RUDDER` is recorded. The numeric values in the
10/08/2026 diary and `wiki/Roadmap.md` belong to SITL. The 24/07/2026 real-FCU
analysis records `ARMING_REQUIRE=1` and `ARMING_CHECK=0`, but not
`ARMING_RUDDER`. Its real-vehicle status is therefore **unknown**, not confirmed
as `2` or confirmed disabled.

ArduPilot source documents `2` as `ArmOrDisarm`: right rudder arms, left rudder
disarms, and rudder arming is available only while throttle is within its zero
deadzone. C2 intentionally keeps throttle neutral for its entire observation,
so that condition would be present if the unknown real-FCU value enables the
feature. The runbook therefore treats rudder arming as potentially enabled,
requires both Herelink sticks to remain untouched, and stops on any armed-state
transition that did not follow the intended QGroundControl button press. This
clarification changes no parameter and performs no C2 action.

### C2 pre-arm gates - PASS; safety engaged, no arm request

C2 has now begun only through its non-actuating pre-arm gates. Pi P2 found the
C1 helper and all five Pi children absent:

```text
C2_PI_ABSENCE=PASS
```

Workstation W2 had already found ports `8002`, `8080` and `9090` free with the
named C1 processes absent, and the dashboard browser was confirmed closed:

```text
C2_WORKSTATION_ABSENCE=PASS ports=8002,8080,9090
C2_BROWSER=CLOSED
```

With the real FCU still `Disarmed` and its hardware safety state still engaged,
Herelink QGroundControl's MAVLink Inspector displayed one active vehicle and no
separate source-system selector. It reported `SERVO_OUTPUT_RAW (36)` at
`2.0 Hz`, component `1`, port `0`, an advancing message `Count`, and a single
`time_usec` field whose displayed value advanced continuously. The operator
observed `servo1_raw=800` and `servo3_raw=800`. The Inspector showed
`time_usec` as `uint32_t`, `port` as `uint8_t`, and both raw servo fields as
`uint16_t`; the installed `pymavlink` common-v2.0 dialect independently matches
those message and field definitions.

The retained pre-arm evidence is:

```text
C2_QGC_INSPECTOR=PASS message=SERVO_OUTPUT_RAW id=36 rate=2.0Hz source_system=SINGLE_ACTIVE_NOT_DISPLAYED source_component=1 port=0 count=ADVANCING time_usec=ADVANCING
C2_PREARM_OUTPUT=PASS servo3=800 servo1=800 armed=NO hardware_safety=ON
```

This is an independent QGroundControl observation of the same real-hull
`800/800` neutral pair that C1 observed through MAVROS. It proves the sampled
values and a continuing message stream; at `2.0 Hz`, approximately one frame
per `500 ms`, it cannot exclude a shorter transient between frames. No stream
rate, message interval or FCU parameter was changed.

The next gate remains unexecuted. CubePilot documentation says to press and
hold the safety button until its LED is solid; ArduPilot documents intermittent
blinking as the safety-engaged indication and solid as output-enabled once the
vehicle is armed. The exact press mechanics have not yet been observed on this
boat, so the LED transition rather than a fixed duration governs the step. The
external LED will be recorded as an independent indicator, then the Inspector
must hold `servo3_raw=800` and `servo1_raw=800` for `10` seconds, approximately
`20` samples, while `Count` and `time_usec` advance and QGroundControl remains
`Disarmed`:

```text
C2_SAFETY_RELEASED servo3=800 servo1=800 count=ADVANCING time_usec=ADVANCING armed=NO safety_led=SOLID
```

Real-FCU `BRD_SAFETY_MASK` and `BRD_SAFETYOPTION` have never been read, so this
record does not claim which channels the safety switch gates. If the outputs
remain `800/800`, `SERVO_OUTPUT_RAW` alone cannot distinguish a registered
safety release from a button press that did nothing, nor decide whether these
channels were always live through the safety state. The blinking-to-solid LED
transition is therefore the sole witness to the state change; an ambiguous LED
has no fallback and ends the attempt before arm. Real-FCU `ARMING_RUDDER` also
remains unknown, both Herelink sticks remain untouched, hardware safety has not
yet been released, and no arm request has been made. C2 and Block C remain
open.
