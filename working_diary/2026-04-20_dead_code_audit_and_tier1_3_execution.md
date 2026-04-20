# 2026-04-20 — Dead-code & bandage audit, plus Tier-1/Tier-3 execution

## Context

The project is in the "polish and prep for hardware" phase with Phase 5
deployment next. Dead code ships to the Pi 5 as CPU and cognitive load
with no upside, and bandage patterns (silent `try/except`, retry loops,
hand-tuned sleeps) become disproportionately hard to debug once off-sim.
Today's session ran a repo-wide audit against the principle
*"avoid degradation handling, fallback, hacks, heuristics, local
stabilizations, or post-processing bandages that are not faithful general
algorithms"* — and then executed the safest two tiers of the resulting
plan end-to-end.

## Audit — findings at a glance

Three parallel exploration passes (Python nodes / dashboard /
launchers+config+wiki) produced ~50 candidate items. After direct
verification several subagent-only claims were dropped or downgraded;
the validated set grouped into four tiers:

| Tier | Shape | Count |
|:----:|:--|:-:|
| 1 | Safe delete (dead params/imports/methods/attrs) | 10 |
| 2 | Bandage surgery (replace symptom-patch with faithful algorithm) | 8 |
| 3 | Principled-ise or document (hand-tuned constants, launcher sleeps) | ~25 |
| 4 | Defensible on review — flagged but not a bandage | 6 |

Architectural themes surfaced alongside the item list:

1. **Command reliability is an unowned concern** — four separate retry
   loops (CLI stop ×3, CLI e-stop ×5, dashboard stop ×2, dashboard
   e-stop ×5) exist because no component owns "deliver this command."
2. **Typed-vs-JSON bus inconsistency** — 9 `JSON.parse try/catch`
   blocks in the dashboard are the visible cost of schema-less `String`
   status topics.
3. **Aspirational pipelines without consumers** — the
   `moving_obstacles` velocity-estimation subsystem in perception, and
   the `max_speed` / `drift_compensation_gain` parameters in the
   controller, were all "declared, computed, never used." The latter
   actively misleads the operator (dial on the dashboard that does
   nothing).
4. **Launcher imperatively sequenced with hand-tuned sleeps** that
   compensate for absent readiness signals.
5. **Dashboard's mini-FSM shadows the planner's authoritative state**,
   producing races like reset-during-confirm.
6. **Pi 5 will violate startup-timing assumptions** — fixed sleeps
   tuned on the dev box may be too short under Pi CPU load.

The Jazzy-official layer — QoS enum names
(`DurabilityPolicy.TRANSIENT_LOCAL`), the `spin_until_future_complete`
deadlock gotcha, the Raspberry Pi `noble-backports` apt-source trap,
and the `OnProcessIO` launch-event handler — was folded into the plan
so recommendations aren't generic ROS-knowledge paraphrases.

## Tier 1 executions — safe deletes

Removed in one commit (heading controller + planner + launch YAML +
user manual + wiki):

- `SENSOR_TIMEOUT` constant (declared, never referenced).
- `drift_compensation_gain` parameter (declared + fetched, no
  downstream consumer — Kalman estimate was computed and published but
  never scaled into any thrust output). *Re-added later in the day
  when the Kalman wire-in gave it real meaning.*
- `self.escape_start_time` attribute (set on escape entry, never
  read).
- `in_hazard_zone()` method in `waypoint_planner` (defined, zero
  callers).
- `import glob`, `import xml.etree.ElementTree as ET` in
  `waypoint_planner` (unused).
- Simplified `self.start_gps` tuple (never read after store) into a
  `self.first_gps_seen` bool flag — the None sentinel *was* used, the
  stored coordinates were not.

Dashboard cleanup in the same pass: removed a dead
`history-empty` CSS class reference (empty-state placeholder); then
a minimal CSS rule was added so the class actually earns its keep as
a muted italic centred placeholder.

## Bug fixes surfaced during testing

### Voyage-completion off-by-one at the final waypoint

Dashboard progress bar read 100% while the boat was still en route to
the last waypoint (observed as 14/14 display + 100% bar, boat still
moving). Root cause: `missionState.currentWaypoint` is the 1-indexed
*target*, so progress should be `(currentWaypoint - 1) / totalWaypoints`
for completed fraction. Refactored to a single
`waypointsCompletedFraction` helper reused by the progress bar,
traveled-distance, and remaining-time calcs — all three were wrong in
the same way.

### `colcon build` from inside `src/` silently ambushed the launcher

Mid-session test aborted with
`bash: cd: .../src/src/uvautoboat/web_dashboard/autoboat: No such file
or directory`. Root cause: an earlier accidental `colcon build` from
inside `~/seal_ws/src/` had created a spurious nested workspace at
`~/seal_ws/src/{build,install,log}/`. The launcher's `WS_ROOT`
auto-detect walks upward for `install/setup.bash` and captured the
spurious `src/install/` first — every downstream path then resolved
to `src/src/uvautoboat/...` which doesn't exist.

Fixed in two layers:

1. **Hardened detection** — the launcher's walk-up loop now requires
   `$WS_ROOT/src/` to exist as a sibling directory, rejecting the
   nested workspace case.
2. **Common_Issues entry** with full symptoms + cause + diagnosis
   - solution + prevention. Added an early-warning bullet: the
   accidental wrong-cwd build is noticeably *slower* than a normal
   incremental build because it's compiling cold into a fresh install
   tree — a tell the operator can catch at build time and abort before
   the spurious workspace finishes laying down.

## Tier 2 partial — `max_speed` cap + Kalman drift feed-forward

Both parameters had the same architectural smell ("declared, surfaced
in dashboard, validated on apply, but no downstream consumer"), so
tackled together as "close the declared-but-unused loops before
hardware."

### max_speed wire-in

Added a forward-speed clamp `speed = max(-self.max_speed,
min(self.max_speed, speed))` in the control loop *before* the
differential-thrust split. This caps the forward component; the
existing `SAFE_THRUST` clamp on the combined left/right thrust is
still the hardware ceiling, and `TURN_POWER_LIMIT` still bounds the
differential independently, so turning authority is preserved when
the operator dials `max_speed` down.

### Kalman drift compensation — B.1

Investigation before coding revealed that the existing Kalman filter
had a **measurement-equation problem**: `estimate_drift()` was called
every control cycle and the measurement (`total_dx/dt, total_dy/dt`)
is literally the boat's ground velocity — commanded motion PLUS any
current, never separated. Naive feed-forward wiring of this output
into thrust would produce a negative-feedback loop on the boat's own
velocity, not drift compensation.

Fix had two parts:

1. **Gated update** — the Kalman `update()` step now only fires when
   the last commanded thrust sum is below 50 N (i.e., the boat is
   commanded-stationary: idle, stopped, or between escape pulses).
   During active navigation only `predict()` runs, so the state
   uncertainty grows until the next commanded-stationary window
   yields a clean measurement. After gating, `drift_vector` actually
   reflects environmental current/wind rather than commanded motion.
2. **Feed-forward application** — the gated drift estimate is
   projected onto the boat's heading each cycle; the along-track
   component is subtracted from the forward `speed` command before
   thrust is split, capped at ±150 N so a bad filter tick cannot
   cause runaway. A headwind or backward current therefore adds
   forward thrust; a following current subtracts it.

The `drift_compensation_gain` parameter (previously dead) was
re-added with real meaning — feed-forward gain scaling drift (m/s) to
thrust (N) × 100. Default 0.3 gives ~30 N correction per m/s of
drift.

## Tier 3 — launcher readiness polls + tuning-rationale docs

### Launcher readiness migration

Replaced five fixed sleeps in `launch_autoboat_complete.sh`
(`sleep 28` Gazebo + four `sleep 8` service waits) with three small
helpers used by the specific sites that need them:

- `wait_for_topic <topic> <timeout>` — uses `ros2 topic info |
  grep 'Publisher count: [1-9]'` rather than `ros2 topic echo --once`.
  The first attempt used `echo --once` but got bitten by QoS /
  message-type resolution subtleties that made it hang past the
  timeout — `topic info` just queries DDS discovery and is immune to
  those. All three helpers return 0 unconditionally (the warning is
  the failure signal); returning non-zero trips `set -e` and aborts
  the whole launcher, defeating the "continuing anyway" intent —
  that's how the first cut of the helper wrecked a test run.
- `wait_for_port <port> <timeout>` — `ss -tln | grep`. Used for
  rosbridge `:9090`, `web_video_server` `:8080`, dashboard HTTP
  `:8002`.
- `wait_for_node <node> <timeout>` — `timeout 2 ros2 param list`.
  Used for `/heading_controller_node` as the last-up nav node.

Health check script's 3 s DDS-prime sleep replaced with a bounded
retry on `ros2 node list --no-daemon` (the `--no-daemon` flag
sidesteps the stale-daemon failure mode already documented under
System-Level Issues).

### Tuning rationale docs

Added three new tables to `wiki/Design_Rationale.md §Parameter
Thresholds Explained`:

- **PID & speed shaping** — Kp/Ki/Kd, base_speed, max_speed,
  obstacle_slow_factor, approach/bank slowdown, turn_deadband,
  slew_rate_limit with rationale and "how to re-tune" hints.
- **Drift compensation** (rewrite of the old "Kalman filter"
  section) — Q, R, drift_compensation_gain plus two short paragraphs
  explaining the new gated-update behaviour and the feed-forward
  application rule.
- **Hand-tuned constants (heading controller)** — the Python-level
  magic numbers that aren't YAML parameters (speed multipliers at
  45°/20° heading error, 250 N approach-minimum clamp for steering
  authority, 450 N escape-mode turn power, SAFE_THRUST /
  TURN_POWER_LIMIT / INTEGRAL_LIMIT ceilings).

## Perception — moving_obstacles pipeline delete

Biggest single cut of the day (~90 LOC net removed from
`lidar_perception.py`). The velocity-estimation subsystem
(`obstacle_tracks` + `obstacle_velocities` dicts, three private
methods `_update_obstacle_tracks`, `_estimate_velocity`,
`_cleanup_old_tracks`, the `moving_obstacles` JSON-field
construction, `velocity_history_size` parameter) ran every LiDAR
scan but had zero consumers — no Python node or dashboard code read
the published `moving_obstacles` array. Classic "aspirational feature
behind no feature flag."

Deleted end-to-end:

- Three methods + two state dicts in `lidar_perception.py`.
- Parameter declare + fetch + config-callback entry in the same
  file.
- `velocity_history_size` entry in `launch/autoboat.launch.yaml`.
- `moving_obstacles: data.moving_obstacles || []` pass-through in
  the dashboard's `obstacleInfoTopic` subscriber.
- Example JSON lines + parameter rows in `USER_MANUAL.md` and
  `wiki/3D_LIDAR_Processing.md` (whole "Step 9: Velocity Estimation"
  subsection gone).

Post-delete health check: 46 PASS / 0 FAIL / 0 WARN — cleanest
snapshot of the day (fresh launch, YAML defaults, no preset
artefacts), which simultaneously validated the earlier
readiness-poll migration and confirmed the perception trim didn't
break any of the three `/perception/obstacle_info` subscribers.

## Commits landed (all pushed)

```text
58b73ba refactor(perception): Drop moving_obstacles pipeline (no consumer)
697164b refactor: Launcher readiness polls + WS_ROOT guard + tuning docs
af18342 feat: max_speed cap + Kalman drift FF + docs/CSS tidy
67b864a refactor: Tier 1 cleanup + final-leg voyage% fix + colcon-cwd doc
03cf803 docs: Bump stamps to 19-04, add 19-04 milestones, align team phrasing
```

## Pressure-test outcome

After all the above: two consecutive full lawnmower missions on
`sydney_regatta_DEFAULT` behaved well in open water. The boat
consistently reaches the FINISHED state; the voyage-completion bar
now tracks completed rather than targeted waypoints.

**Residual issue** (deferred, not today): in pier-dense and
lake-bank-dense regions the boat still tends to get stuck after
several consecutive missions. None of today's work specifically
addresses structured-obstacle scenarios — the recent Kalman /
max_speed / VFH improvements target open-water control loops. Likely
future directions: wider A\* safety margin near structures, tighter
`bank_slow_distance` threshold, default-enabling the **Pier Detect**
preset for structured-environment missions, or adding a dedicated
near-structure mode. Logged for resumption.

## Evening session — Tier 2 completion + UI cleanup

The three remaining Tier 2 items were all executed end-to-end in the
evening session; the pressure-test issue from earlier remains the only
carry-over to a future day.

### #9 — Dedicated latched E-Stop channel

New `/planning/emergency_stop` (`std_msgs/Bool`) topic. Publishers:
`autoboat_cli.py` and `app.js` (dashboard). Subscribers: both
`waypoint_planner.py` and `heading_controller.py` — each node sets its
own latched state rather than routing through the planner.

Design call that split from the original audit plan: chose
`RELIABLE + KEEP_LAST(depth=1)` **without** `TRANSIENT_LOCAL`.
The audit itself flagged the cross-language QoS trap — a subscriber
requesting `TRANSIENT_LOCAL` against a `VOLATILE` publisher silently
drops messages — and roslib.js's advertise-QoS support is version-
sensitive enough that matching both sides was a risk not worth taking
for a safety path. `RELIABLE` alone is what the 5× retry loops were
actually compensating for (UDP loss, not late-joining subscribers); the
planner is always running when E-Stop fires, so
`TRANSIENT_LOCAL`'s late-joiner benefit doesn't buy anything here.

Controller-side refactor: extracted `_latch_emergency_stop(source)` so
both the existing `mission_command` path and the new latched-topic
path share the same latch-stop-cut-thrust sequence, with the logged
source string distinguishing entry points ("command" vs. "latched
topic").

Verified live: `[ERROR] 🚨 EMERGENCY STOP via latched topic
(was DRIVING → now EMERGENCY_STOP)` on the planner and
`[WARN] 🚨 EMERGENCY STOP via latched topic — override latched,
escape state reset.` on the controller. Single publish, both
subscribers fire once. No retry duplicates in the log.

### Position-history reset on resume (Kalman hazard avoidance)

Surfaced while reviewing the Phase 5 prep scope plan
(`2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`) against the
afternoon's Kalman wire-in. The scope plan asked: "does `predict()`
still run during E-Stop?" Answer after reading the code: **no** —
`estimate_drift()` is gated behind the same `stop_override` early-
return that blocks the control loop, so the filter is fully frozen
during E-Stop.

But a subtler concern surfaced from the same reading: `position_history`
(the 100-sample buffer used by the measurement step) is only appended
when the control loop runs. During E-Stop the buffer freezes; the boat
may still drift physically; on resume the first `estimate_drift()` call
sees a 20-sample window spanning pre-E-Stop and post-resume positions
and — because the first post-resume ticks are commanded-stationary
(PID ramping from zero) — the gated `update()` fires on that spurious
giant delta, temporarily inflating `drift_vector`.

Three-line fix: clear `self.position_history` on the
`resume_mission` / `go_home` / `start_mission` branch of
`mission_command_callback` when `stop_override` was active. Simple
state-reset pattern, no heuristic needed.

### #10 — `std_srvs/Trigger` ACK services

Two new services on `waypoint_planner.py`:

- `/planning/stop_mission` (`Trigger`) — replaces CLI's 3× retry loop
  and dashboard's 2× 200 ms-apart retry.
- `/planning/generate_waypoints` (`Trigger`) — replaces both CLI's
  200 ms sleep between `send_config` and `send_command('generate')`
  and dashboard's 500 ms `setTimeout` before the same.

Key observation for the generate path: the "wait for planner to
process config" sleep is redundant under rclpy's single-threaded
executor. Sending a config publish followed immediately by a service
call results in the config-subscription handler running first (ordered
dispatch from rosbridge/DDS), so by the time the service handler
executes the new config is already applied. No hand-tuned sleep.

CLI-side client uses `spin_until_future_complete` at the main-thread
top level (not inside a callback, where it deadlocks per Jazzy docs).
Dashboard-side uses `ROSLIB.Service.callService` with success + error
callbacks that feed back into `addLog` so operator sees ACK like
"Mission stopped — stopped (was DRIVING)" or
"Waypoints generated — generated 19 waypoints."

Other mission commands (`start_mission`, `confirm_waypoints`,
`resume_mission`, `reset_mission`, `go_home`, `joystick_enable`) stay
on the existing `/planning/mission_command` topic — they weren't
audit-scope bandages and the topic-based broadcast (planner +
controller both subscribe) remains a reasonable fit.

### #11 — JSON schema guards at publishers + visible dashboard errors

Python side: each of the three status-publishing nodes
(`waypoint_planner.py`, `heading_controller.py`, `lidar_perception.py`)
gained a `_publish_json(publisher, payload, label)` helper that wraps
`json.dumps(payload, allow_nan=False)` in a try and, on failure, logs
a throttled error and skips the publish cycle. Nine raw `json.dumps`
sites across the three files were refactored onto this helper. The
`allow_nan=False` flag specifically catches NaN/Inf leaking in from
a bad Kalman tick, an uninitialised float, or an empty-scan division
— the sources most likely to reach the wire after today's Kalman
wire-in.

Dashboard side: added a module-scope `logBadJson(topicName, error)`
helper with a 5-second-per-topic rate limit. It calls `addLog(..., 'error')`
so the operator sees a visible red entry in the dashboard event log
instead of the old silent `if (DEBUG_MODE) console.warn` swallow.
Eight `JSON.parse` catch blocks were migrated from the silent pattern
onto `logBadJson`.

Stress-tested the visible-error path directly via

```bash
ros2 topic pub --once /planning/mission_status std_msgs/String "data: 'corrupted{garbage'"
ros2 topic pub --once /control/status         std_msgs/String "data: 'bad'"
ros2 topic pub --once /perception/obstacle_info std_msgs/String "data: 'bad'"
```

Each injection surfaced one red event-log entry of the form
"Malformed JSON on /planning/mission_status: JSON.parse: unexpected
character at line 1 column 1 of the JSON data", then the dashboard
recovered on the next real publish from the Python node. Rate limit
behaved as designed (rapid repeat suppressed).

### Bonus: "Waiting for ROS sync" label drift cleanup

Noticed during the #11 stress test: the
`⏳ Waiting for ROS sync… | En attente de synchro` label was showing at
the bottom of the Advanced Configuration panel even though the Apply
Config button was enabled and clickable. DevTools diagnosis:

```text
button classList: config-btn apply waiting-sync
button disabled?: false
label computed display: block
```

The button's `disabled` attribute had been cleared but the
`waiting-sync` CSS class had not — the two states (meant to mirror
each other) had drifted. All code paths that clear `disabled` in
`app.js` also remove the class; the drift source couldn't be
reproduced from grep alone but the inconsistency was live.

Faithful fix applied rather than patching the drift: dropped the
redundant UI element entirely. Three existing cues already communicate
the pre-sync state — greyed-out button, `cursor: not-allowed`, and the
`title` tooltip `"Waiting for ROS config sync..."` — plus the
rosbridge connection indicator as a separate panel. The explicit text
label was a fourth, redundant signal.

Deleted: three `<span class="apply-waiting-label">` elements from
`index.html`, three `waiting-sync` class references from the Apply
buttons, three CSS rules targeting the now-dead class/label pair, and
the matching `classList.remove('waiting-sync')` line from
`updateConfigFromROS` in `app.js`. Net: two states synchronised by one
authoritative `disabled` attribute.

## Commits landed (evening)

```text
refactor: Drop redundant Waiting-for-sync label (disabled + tooltip suffice)
refactor: JSON schema guards at publishers + visible dashboard errors
refactor: Stop/generate as Trigger services, drop CLI/dashboard bandages
fix: Clear drift position buffer on stop resume (prevent Kalman spike)
refactor: Dedicated latched E-Stop channel, drop retry loops
```

## Late-evening addition — TUNED health-check state

After pushing the Tier 2 close-out commits, a post-hoc sweep of the
active tree (Explore agent, guided against today's actual deletions
and refactors) came back empty: no lingering references to deleted
symbols, no now-dead Python identifiers, no AI-tooling leaks, no
broken dashboard selectors. Two cosmetic `sleep 8` lines in
`launch_autoboat_complete.sh` (post-RViz, pre-browser-open) were
flagged then marked Tier 4 "defensible on review" — both are cushions
for human-visible UI timing, not bandages masking ROS-level races, so
left in place.

### What triggered the feature

Running the health check after a Buoy-Field dashboard preset produced
six `[WARN] param = X (expected Y)` lines — all legitimate user
tunings, none actually unhealthy. The WARN signal had drifted into
noise: it was firing every time the operator pressed a preset button,
so an operator couldn't distinguish "runtime intentionally differs
from YAML" from "something actually went wrong with the node."

### Fix — 4-state parameter check

Added a boolean ROS parameter `config_tuned` to each of the three
nodes (`waypoint_planner.py`, `heading_controller.py`,
`lidar_perception.py`), declared `False` at startup and flipped to
`True` in the node's `config_callback` after the first successful
`/planning/set_config` parse. Idempotent via `if not
self.get_parameter('config_tuned').value:` guard — one-shot flip,
subsequent config updates don't touch it.

Health check reads this flag once per node (`is_node_tuned` helper)
and passes the result into each `check_param` call:

| Runtime vs baseline | `config_tuned` | State |
|:-------------------|:--------------:|:-----:|
| equal | any | **PASS** — green, counted as healthy |
| differs | `True` | **TUNED** — magenta, counted as healthy |
| differs | `False` | **WARN** — yellow, *unexpected drift* (actionable) |
| unreadable | any | **FAIL** — red |

Summary line now reads `PASS: X  TUNED: Y  FAIL: Z  WARN: W`. WARN
regains a meaningful signal: it fires only when runtime diverges from
YAML *without* the user having applied a config — exactly the case an
operator should investigate.

Dashboard needed a small follow-up in the same commit: its
`classifyHealthLine(line)` didn't know about the `[TUNED]` tag, so
the lines rendered white (default fallthrough). Added the regex case
in `app.js` and a matching `.terminal-line.tuned { color: #ba68c8; }`
CSS rule mirroring the terminal ANSI magenta.

### Live verification

Health check after a Buoy-Field preset:
`PASS: 40  TUNED: 6  FAIL: 0  WARN: 0`. Six TUNED lines rendered
magenta in the dashboard terminal panel, e.g.:

```text
[TUNED] obstacle_slow_factor = 0.3 (baseline 0.5 — user-applied)
[TUNED] critical_distance    = 3.0 (baseline 6.0 — user-applied)
[TUNED] perception_critical_distance = 2.5 (baseline 5.5 — user-applied)
```

### Commits landed (late evening)

```text
feat: Health check distinguishes baseline vs user-tuned params (TUNED state)
```

## Status after today

All three Tier 2 items from the audit plan are now landed — the full
plan (Tiers 1, 2, 3) is executed end-to-end. The only audit item
*not* closed is Tier 4 (defensible-on-review), which by design needed
no action. One improvement added beyond the audit scope (health-check
TUNED state) to keep the WARN signal actionable once preset-based
tuning became a routine operator action.

## Next steps

1. **Pier / bank stuck behaviour** — reproduce first (the underlying
   code has shifted across several refactors), then explore the A\*
   safety-margin / bank-threshold / Pier-Detect-default options. See
   the earlier obstacle-avoidance notes for context. Carried over
   from the afternoon session, still the top open issue.
2. **Phase 5 prep scope plan review on Linux** — the
   `2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` Part 1 line
   numbers have drifted by ±1 to ±5 due to today's edits; the
   file-level inventory is still correct. Part 3B bridge-node design
   is unaffected by the Kalman wire-in. Worth a quick line-number
   refresh next time `remap.launch.yaml` implementation starts.
