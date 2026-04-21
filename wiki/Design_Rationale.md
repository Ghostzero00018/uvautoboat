# Design Rationale

Why the AutoBoat system is designed the way it is — the "WHY" behind architecture choices, algorithm selections, and parameter values.

For **what each term means**, see **[Glossary](Glossary)**.
For **how to use the system**, see **[Quick_Start](Quick_Start)** and **[System_Overview](System_Overview)**.

---

## Architecture Decisions

### Why modular Perception–Planner–Controller pipeline instead of monolithic?

The AutoBoat navigation system is built as a **pipeline of three modules** — `Perception → Planning → Control` — each running as an **independent ROS 2 node**:

| Module | Role | Question it answers |
|:-------|:-----|:--------------------|
| **Perception** | Perception | "What do I see?" |
| **Planner** | Planning | "Where do I go?" |
| **Controller** | Control | "How do I get there?" |

#### Why separate processes, not one integrated program?

1. **Failure isolation.** If the perception node crashes (e.g., LiDAR driver segfault), the planner and controller keep running on their last-known obstacle data. A monolithic program would take down everything together.
2. **Debuggability.** ROS topic messages between modules are plain-text JSON that can be inspected live with `ros2 topic echo`. When something goes wrong, we can pinpoint which stage of the pipeline has bad data rather than stepping through a massive single program.
3. **Upgrade independence.** Swapping out the perception algorithm (e.g., replacing cluster-based detection with a neural network) does not require touching the controller. Interfaces between modules are defined by ROS message types.
4. **Parallel development.** Different contributors can work on Perception, Planner, or Controller simultaneously without merge conflicts.

**The cost** is latency — each inter-process message adds ~1–2 ms of overhead compared to a direct function call. For a 20 Hz (50 ms) control loop this cost is negligible.

### Why no dedicated pose-estimation node in the current architecture?

The legacy codebase had a `gps_imu_pose` node that fused GPS + IMU at 10 Hz into a unified `PoseStamped` message, which every other node subscribed to. When the system was modularized into AutoBoat, this node was **intentionally removed** — each planner and controller now does its own GPS-to-local conversion inline:

- The Planner does its own `latlon_to_meters` inside the planner (for waypoint generation)
- The Controller does its own quaternion → yaw extraction inside the controller (for heading control)

**Why?** Reducing inter-node dependencies. A shared "pose" node becomes a single point of failure — if it lags or crashes, every downstream node stalls. Doing the simple arithmetic inline in each consumer is more robust for the current scope.

**Future work** will reintroduce a proper pose-estimation node, but this time using an Extended Kalman Filter (EKF) for principled sensor fusion with uncertainty propagation — worth the complexity when adding more sensors (e.g., compass, dead-reckoning wheel encoders on a hardware boat) in the hardware-integration phase.

### Why ROSBridge + web dashboard instead of native ROS GUI?

The dashboard is browser-based, connecting to ROS 2 via ROSBridge (WebSocket + JSON). Alternatives would be native ROS GUIs (RViz, rqt) or a custom Qt/Gtk application.

#### Reasons for the web approach

1. **Zero-install for operators.** Anyone with a browser can connect — no ROS installation required. Useful during field trials where an observer on a laptop needs live telemetry without the full ROS stack.
2. **Remote access.** The WebSocket URL uses `window.location.hostname` dynamically, so the dashboard works over LAN (e.g., a tablet near the shoreline viewing a boat's telemetry).
3. **Familiar tooling.** HTML/CSS/JS has far more libraries for interactive maps (Leaflet), charts, and form controls than the ROS GUI ecosystem.

**Cost:** ROSBridge adds one translation layer and a ~5 s timeout for synchronous services — the dashboard uses async pub/sub for anything that could exceed that limit (e.g., health check).

> **Note on ros2-web-bridge:** A separate project ([ros2-web-bridge](https://github.com/RobotWebTools/ros2-web-bridge)) once offered a Node.js-based alternative to rosbridge_suite. It was **archived in November 2025**, last targeted ROS 2 Dashing (2019), and its own README now redirects users to `rosbridge_suite`. AutoBoat uses `rosbridge_suite` — the actively maintained official ROS package — and requires no migration.

---

## Algorithm Choices

### Why a 2D linear Kalman filter, not an EKF?

The Controller runs a 2D linear Kalman filter (state = `[drift_x, drift_y]`) to compensate for water-current and wind drift. A natural question: would an Extended Kalman Filter (EKF) do a better job?

**The answer is no** — EKF would be over-engineering for this specific task:

| Property | Linear KF | EKF |
|:---------|:----------|:----|
| State-transition model | `F = I` (random walk) | Non-linear `f(x)` |
| Measurement model | `H = I` (direct observation) | Non-linear `h(x)` |
| Linearization | Not needed | Jacobians at every step |
| Compute cost | Very low | Higher (matrix derivatives) |
| Code complexity | Minimal | Substantial |

The drift state `[drift_x, drift_y]` evolves slowly and linearly — current and wind change over seconds, not milliseconds, so a random-walk model (`x_new = x_old + noise`) is adequate. The measurement is also linear: we compare expected position (from commanded thrust/heading) against actual GPS position, and the residual divided by time gives a direct noisy observation of drift velocity.

When these two conditions hold (linear dynamics + linear measurement), the linear KF is **provably optimal** (minimum mean-squared error for Gaussian noise) and much cheaper than EKF. An EKF would give the same answer at a higher compute cost.

See **[Glossary: 2D linear Kalman filter](Glossary#2d-linear-kalman-filter-as-used-in-this-project)** for the full math.

### Why is VFH (Vector Field Histogram) disabled by default?

The Perception node implements a VFH-style polar histogram and publishes a `best_gap` direction. The Controller has a toggle `use_vfh_bias` that, when enabled, biases steering toward the best gap. In the production YAML the toggle is **`false`**.

**Why off by default?** Two reasons:

1. **The default demo world is clean.** `sydney_regatta_DEFAULT` has just a few obstacles — the simpler 3-sector avoidance (Front/Left/Right clearance checks) is sufficient. VFH is designed for dense clutter (buoy fields, pier pylons, anchored boat fleets) where the structure of the *whole* obstacle field matters.
2. **VFH can oscillate in sparse environments.** When two gaps have nearly equal width, VFH's "pick the best gap" step can jump between them frame-to-frame, causing the boat to zig-zag. The 3-sector method is monotonic: it just picks whichever side has more room, with less frame-to-frame variability.

**When to enable it:** the dashboard's 4 tuning presets are named for scenarios where VFH shines — `Buoy Field`, `Pier Detect`, `Open Water`, and `Universal`. Three of these four turn VFH on (`Open Water` leaves it off). Clicking a preset (as the operator) flips the toggle; otherwise it stays off.

**Limitations of VFH in any case:** it is a purely local, reactive method with no memory and no global planning. It can get trapped in local minima (dead-end corridors). That is why VFH is paired with the Planner's global lawnmower + A\* rerouting — VFH handles "how to squeeze through obstacles locally", the Planner handles "where to go overall".

**Runtime tuning knobs** (exposed as ROS parameters on `lidar_perception_node`, with defaults in `launch/autoboat.launch.yaml`):

| Parameter | Default | Purpose |
|:---|:---|:---|
| `vfh_block_distance` | 15.0 m | Distance at which a bin is marked blocked. Lowering narrows VFH's attention window to closer obstacles. |
| `vfh_bin_width_deg` | 5.0 ° | Angular bin width. Smaller = finer histogram, more compute. Larger = coarser, faster, less sensitive to small gaps. |
| `vfh_clearance_deg` | 10.0 ° | Inflation around blocked bins (safety margin). Increase in cluttered environments to avoid grazing obstacles. |
| `vfh_polar_power` | 1.0 | Exponent for distance weighting in the polar histogram. `1.0` = linear; higher values prefer far-away free space more strongly. |

**Target-aware VFH.** VFH's "best gap" is selected as the free bin closest to the controller's current waypoint-relative heading error (published on `/control/heading_error`, body frame), not blindly forward. This means VFH steers through clutter *toward* the waypoint rather than just picking the forwardmost clear gap.

See **[Glossary: VFH](Glossary#vfh-vector-field-histogram)** for the 3-step algorithm breakdown.

### Why 3 sectors (Front / Left / Right) and not finer-grained?

The Perception node aggregates LiDAR returns into just three directional sectors. An obvious alternative would be 8 sectors, 16 sectors, or even per-bin VFH output.

#### The three-sector design wins for the current mission profile because

1. **The controller only chooses `left` or `right`.** The Controller's avoidance logic is ultimately a binary decision — "which side has more room?" A 3-sector representation (Front for threat detection + Left/Right for avoidance direction) maps cleanly onto that decision.
2. **Fewer parameters to tune.** Each sector has distance thresholds and urgency mappings. More sectors multiply the tuning surface.
3. **More stable output.** Obstacle positions vary frame-to-frame due to LiDAR noise; aggregating into wide sectors averages out this noise. Fine-grained bins would flicker.
4. **Human-legible on the dashboard.** Three progress bars (Front/Left/Right clearance, with urgency colouring) fit naturally on screen; 16 bars would be overwhelming.

VFH **also** runs internally (producing a finer-grained polar histogram) — its `best_gap` direction is available for operators who want it. The three-sector summary is simply the default interface to the controller.

### Why 3-level obstacle fallback (reactive → detour → A\* reroute/skip)?

When a waypoint is blocked, the system escalates through three levels rather than jumping straight to full path planning:

| Level | Trigger | Action | Time cost |
|:------|:--------|:-------|:----------|
| **Reactive avoidance** | Front clearance < 12 m | The Controller steers toward clearer side; the Planner may insert an opportunistic side-detour waypoint when < 8 m | 0 (immediate) |
| **Auto detour** | Blocked for > 30 s | The Planner inserts a lateral detour waypoint (14 m offset from the blocked path) | ~30 s wait |
| **A\* reroute or skip** | Blocked for > 45 s | The Planner tries A\* grid planning; if no path is found, skips the waypoint entirely | ~45 s wait + A\* compute (capped at 20,000 node expansions) |

**Why escalation instead of always using A\*?**

1. **A\* is expensive.** Each A\* call searches up to 20,000 grid cells. Running it 10 times per second would saturate the planner.
2. **Most obstacles clear themselves.** A passing boat, floating debris, or a transient LiDAR noise cluster often disappears within a few seconds. Waiting 30 s before committing to a detour saves unnecessary replanning.
3. **Skip-if-unreachable is a safety valve.** Some waypoints may be genuinely unreachable (on land, behind impassable obstacles). Skipping after 45 s lets the mission continue rather than hanging forever.

The numbers 12 m / 8 m / 30 s / 45 s were found empirically by running the boat against VRX obstacle configurations and adjusting until behaviour was neither too aggressive (constant avoidance triggers) nor too slow (letting the boat crash before reacting).

---

## Parameter Thresholds Explained

This section explains **why each key parameter has the value it does**. All values are the YAML defaults (from `launch/autoboat.launch.yaml`).

### Obstacle detection & avoidance

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `perception_min_safe_distance` | 10 m | The Perception node considers obstacles beyond this distance "safe" (urgency = 0). 10 m is ~4× boat length — enough to plan around at typical cruise speed. |
| `perception_critical_distance` | 5.5 m | Below this, urgency saturates at 1.0. ~2× boat length — point at which reactive avoidance must override any planning. |
| `min_safe_distance` (Controller) | 12 m | The Controller triggers reactive steering below this. Chosen slightly larger than Perception's 10 m to add a safety buffer — if Perception says "urgency 0.2", the Controller is already steering. |
| `critical_distance` (Controller) | 6 m | The Controller triggers micro-reverse below this. Slightly larger than Perception's 5.5 m critical for the same buffer reason. |

### PID & speed shaping

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `kp` | 500 | Proportional gain on heading error. Tuned empirically on `sydney_regatta_DEFAULT` for prompt response without overshoot. Reduce if the boat hunts side-to-side; increase if it feels sluggish. |
| `ki` | 20 | Integral gain — compensates for sustained heading bias (weak side-current, thruster asymmetry). Kept small by design: `INTEGRAL_LIMIT = 0.5 rad` is the windup cap. |
| `kd` | 150 | Derivative gain — damps oscillation. Ratio `Kd/Kp = 0.3` gives a moderately-damped response. Larger looks over-damped; smaller causes zigzag. |
| `base_speed` | 400 N | Cruise thrust at ≤20° heading error. |
| `max_speed` | 800 N | Operator-tunable soft cap on forward thrust, applied in the control loop before the `SAFE_THRUST` hardware ceiling. Reduce to slow the boat in tight environments; raise up to `MAX_THRUST = 2000 N` for hardware with larger motors. |
| `obstacle_slow_factor` | 0.5 | Speed multiplier when an obstacle is detected. 0.5 halves speed for smoother avoidance; tuning presets may override (e.g. `Universal` uses 0.3 for tighter environments). |
| `approach_slow_distance` | 10 m | Distance from the target waypoint below which speed ramps down linearly. |
| `approach_slow_factor` | 0.7 | Terminal speed fraction at distance 0 (70% of pre-approach speed). A 250 N minimum is clamped downstream to preserve steering authority through the approach. |
| `bank_slow_distance` | 6 m | Obstacle distance below which shoreline/structure slowdown activates. |
| `bank_slow_factor` | 0.25 | Speed multiplier at the closest end of the bank-slow ramp. Aggressive by design — hitting a pier damages the boat. |
| `turn_deadband_deg` | 0.5° | Below this heading error, turn power is zeroed. Prevents chatter from GPS/IMU noise near the setpoint. |
| `slew_rate_limit` | 80 N/cycle | Maximum thrust change per 50 ms control cycle (1600 N/s). Prevents sudden reversals that could damage thrusters. |

### Timing thresholds

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `max_block_time` | 30 s | Auto-detour trigger. 30 s is long enough for a passing boat or transient LiDAR noise to clear, but short enough that the mission does not stall. |
| `waypoint_skip_timeout` | 45 s | Skip-or-reroute trigger. 15 s longer than the detour trigger so detour has a chance to work first. |
| `reverse_timeout` | 4 s | Maximum duration of a single reverse maneuver. Prevents runaway backward motion. |
| `stuck_timeout` | 12 s | Anti-stuck detection. Long enough that brief stalling during avoidance does not trigger recovery; short enough that actual stuck states are caught. |

### Control loop timing

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| Control loop period | 50 ms (20 Hz) | Faster than the LiDAR rate (10 Hz) so control can respond to fresh obstacle data within one cycle. 20 Hz is a common soft-real-time target for boat control — slow enough not to saturate the CPU, fast enough for smooth steering. |
| Micro-reverse cycle | 0.6 s total | 0.2 s reverse burst + 0.4 s pause. Short burst prevents runaway; pause lets the GPS observe whether the maneuver worked. |

### A\* planner

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `astar_resolution` | 3 m | Grid cell size. 3 m is ~1× boat length — fine enough to find paths through gaps the boat can actually fit through, coarse enough to keep the search tractable. |
| `astar_safety_margin` | 12 m | Obstacle inflation radius. Roughly `min_safe_distance` — so A\* never produces a path that the Controller would then react against. |
| `astar_max_expansions` | 20,000 | Node expansion cap. At 3 m resolution this covers ~180,000 m² of search space before timing out — more than enough for any realistic detour. |

### Drift compensation

The Controller runs a 2D linear Kalman filter to estimate water-current and wind drift, then applies the estimate as feed-forward thrust compensation.

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `kalman_process_noise` (Q) | 0.01 | Small Q → smooth drift estimates. Appropriate for environmental drift that evolves over seconds, not milliseconds. |
| `kalman_measurement_noise` (R) | 0.5 | Moderate R → partial trust in displacement-based measurement. Ratio `R/Q ≈ 50` means the filter leans on its prediction and smooths GPS jitter. |
| `drift_compensation_gain` | 0.3 | Feed-forward gain scaling estimated drift velocity (m/s) to thrust (N), multiplied by 100 and capped at ±150 N. 0.3 gives ~30 N correction per m/s of along-track drift — enough to partially counter a moderate current without destabilising the PID. |

**Filter-update gating.** The Kalman `update()` step fires only when the last commanded thrust sum is below 50 N — i.e., the boat is commanded-stationary (idle, stopped, or between escape pulses). This prevents the displacement measurement being dominated by commanded motion rather than environmental drift. During active navigation only `predict()` runs, so uncertainty grows until the next commanded-stationary window produces a fresh measurement.

**Feed-forward application.** Each control cycle the estimated drift is projected onto the boat's current heading; the along-track component is subtracted from the forward `speed` command before thrust is split into left/right. A headwind or backward-current therefore adds forward thrust; a following current reduces it. The ±150 N cap ensures a bad filter tick cannot cause runaway.

### Temporal confirmation

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `temporal_history_size` | 3 | Number of recent LiDAR scans kept in a rolling buffer. |
| `temporal_threshold` | 2 | Obstacle must appear in 2 of the last 3 scans to be confirmed. Rejects single-frame ghosts while confirming real obstacles within ~200 ms at 10 Hz LiDAR rate. |

### Path generation

| Parameter | Value | Rationale |
|:----------|:------|:----------|
| `scan_length` | 15 m | Length of each lawnmower lane. Small enough for quick demo missions, large enough to cover meaningful area. |
| `scan_width` | 30 m | Spacing between lanes. Half the typical LiDAR range (~50 m max effective) so adjacent lanes' perception zones overlap. |
| `lanes` | 10 | Number of lanes. Produces ~15 m × 300 m coverage area — sized for the default demo. |
| `waypoint_tolerance` | 3.5 m | Arrival radius. Balance between precision (small = accurate) and robustness to overshoot (large = forgiving). 3.5 m is ~1× boat length. |
| `detour_distance` | 14 m | Lateral offset for inserted detour waypoints. Wide enough to clear the obstacle being detoured around; small enough to rejoin the mission path quickly. |

### Hand-tuned constants (heading controller)

These are Python constants in `control/control/heading_controller.py`, not YAML parameters. Documented here so the values can be understood without reading source.

| Where | Value | Rationale |
|:------|:------|:----------|
| Speed multiplier at ≥45° heading error | 0.5× | Halve cruise speed when turning hard — reduces lateral skid on a boat without a keel. |
| Speed multiplier at ≥20° heading error | 0.75× | Softer slowdown in the 20–45° band — avoids the jarring on/off of a single-threshold rule. |
| Approach-phase minimum speed clamp | 250 N | Below this, differential thrust can't overcome the boat's turning inertia and heading commands stop taking effect. 250 N preserves steering authority through the final approach. |
| Escape-mode turn power | 450 N | Fixed turn-power used while anti-stuck escape is active. Higher than normal differential because the boat is already near-stationary and we want a crisp pivot. |
| `SAFE_THRUST` | 800 N | Operational per-thruster ceiling — matches VRX WAM-V default. Hardware ceiling `MAX_THRUST` lifts to 2000 N but is not the default. |
| `TURN_POWER_LIMIT` | 1600 N | Maximum turn-power magnitude before per-side clamping to `SAFE_THRUST`. |
| `INTEGRAL_LIMIT` | 0.5 rad | Hard anti-windup cap on the PID integral accumulator. |

---

## Navigation Modes — Trade-offs

The dashboard exposes three planning strategies via radio buttons:

| Mode | `astar_enabled` | `astar_hybrid_mode` | Use when |
|:-----|:----------------|:--------------------|:---------|
| **Simple Lawnmower** | `false` | `false` | Debugging the lawnmower pattern itself, or running in a completely obstacle-free world. |
| **Runtime A\*** (YAML default) | `true` | `false` | Standard demos. Lawnmower path by default; A\* kicks in only when a waypoint is blocked for 45+ s. **Cheapest mode that still handles unexpected obstacles.** |
| **Hybrid Mode** | `true` | `true` | When the obstacle field is known in advance. A\* pre-plans routes between lawnmower waypoints before the mission starts. |

**Why "Runtime A\*" is the default:** Hybrid mode's pre-planning is expensive and only beneficial when the obstacle field is accurate upfront — which requires either human labelling or a prior mapping pass. For the typical demo where we just want the boat to cover an area and react to obstacles it encounters, Runtime A\* strikes the best balance: zero pre-compute, and A\* only runs when actually needed.

The HTML shows "Simple Lawnmower" as checked on page load (a cosmetic default), but the dashboard syncs from ROS config within ~1 second and updates to "Runtime A\*" to match the YAML truth.

---

## Academic References

The algorithms in this project are built on well-established prior work:

- **Kalman Filter** — Kalman, R.E. (1960). "A New Approach to Linear Filtering and Prediction Problems." Originally developed for the Apollo guidance computer; now ubiquitous in GPS, radar, and autonomous vehicle localization.
- **A\* Search** — Hart, Nilsson, and Raphael (1968). "A Formal Basis for the Heuristic Determination of Minimum Cost Paths." Still the foundational algorithm for grid-based pathfinding.
- **VFH (Vector Field Histogram)** — Borenstein, J., and Koren, Y. (1991). "The Vector Field Histogram — Fast Obstacle Avoidance for Mobile Robots." IEEE Transactions on Robotics and Automation.
- **VFH+ variant** — Ulrich, I., and Borenstein, J. (1998). "VFH+: Reliable Obstacle Avoidance for Fast Mobile Robots." ICRA.
- **VFH\* variant** — Ulrich, I., and Borenstein, J. (2000). "VFH\*: Local Obstacle Avoidance with Look-Ahead Verification." ICRA.

### Standards referenced

- **ROS REP-103** — standard coordinate conventions for ROS (right-handed ENU: X forward, Y left, Z up).
- **Open Database License (ODbL)** — attribution requirement for OpenStreetMap map tiles used in the dashboard.
- **BSD-2-Clause** — license for the Leaflet JavaScript library.

---

## See Also

- **[Glossary](Glossary)** — Definitions of every technical term
- **[System_Overview](System_Overview)** — High-level architecture
- **[3D_LIDAR_Processing](3D_LIDAR_Processing)** — LiDAR Perception pipeline deep-dive
- **[SASS](SASS)** — Anti-stuck recovery system
