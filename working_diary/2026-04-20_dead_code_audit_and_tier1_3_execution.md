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
   + solution + prevention. Added an early-warning bullet: the
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

## Next steps

Remaining Tier 2 items from the audit plan, in the order they should
be approached:

1. **Latched e-stop** via `TRANSIENT_LOCAL` QoS topic — replaces the
   5× retry e-stop in both CLI and dashboard. Phase 5 safety-critical;
   do before hardware bring-up. Scope: ~30–50 LOC across
   `heading_controller.py` + `autoboat_cli.py` + `app.js`. Must
   match QoS on both ends or the subscription silently fails.
2. **Command ACK services** via `std_srvs/Trigger` — replaces the
   stop_mission retries (3×) and the 500 ms `setTimeout` before
   `generate_waypoints`. Scope: ~80–120 LOC. Deferrable past
   hardware.
3. **Publisher-side JSON schema validation** — add
   `json.dumps(..., allow_nan=False)` guards at the three Python
   status publishers; drop 7 of 9 silent `try/catch` blocks in the
   dashboard. Scope: ~20–30 LOC. Deferrable past hardware.
4. **Pier / bank stuck behaviour** — reproduce first (the underlying
   code has shifted across several refactors), then explore the A\*
   safety-margin / bank-threshold / Pier-Detect-default options. See
   the earlier obstacle-avoidance notes for context.
