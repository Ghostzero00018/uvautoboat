# 2026-04-21 to 2026-04-22 — I6 Docstring Refresh Draft

Drafted evening of 21/04 as Windows-side pre-work for tomorrow's Block D (I6 docstring refresh). Current module-level docstrings on the three nodes drifted from reality across the past 2 weeks of topic / state additions. This draft holds the proposed new docstrings ready to paste, plus a short rationale per line.

Minimum scope matches the I6 audit finding (new pub/sub + expanded state machine). Bonus fixes for two stale "Features" bullets are flagged separately — user picks whether to bundle.

Tomorrow on Linux, the work is: for each of the 3 files, select the module docstring (the `"""..."""` block near the top), replace with the "Proposed new" version below, run `python3 -m py_compile` per file, one `docs:` commit. Zero behaviour change.

---

## 1. `plan/plan/lidar_perception.py`

### Current docstring (lines 2-33)

```python
"""
LiDAR Perception - 3D LiDAR Point Cloud Processing (Enhanced v2.0)

Module: LiDAR Perception
Role:   Processes 3D LiDAR point clouds and publishes obstacle information.
See also: Waypoint Planner (Planning) and Heading Controller (Control)

Part of the modular AutoBoat architecture.
Subscribes to 3D LiDAR data, processes point cloud, publishes obstacle information.

Features:
- Three-sector obstacle detection (front, left, right)
- 10th percentile filtering for noise rejection
- Height-based filtering to reject sky/water reflections
- Hysteresis to prevent oscillation at detection boundary

Enhanced Features (v2.0):
- Temporal filtering (multi-scan history for noise rejection)
- Distance-weighted urgency scoring
- Obstacle clustering (gap detection)
- Adaptive sector analysis (target-aware)
- Ground plane removal (water surface filtering)
- Velocity estimation (moving obstacle tracking)

Topics:
    Subscribes:
        /wamv/sensors/lidars/lidar_wamv_sensor/points (PointCloud2)
        /planning/current_target (String) - For adaptive sectors
    
    Publishes:
        /perception/obstacle_info (String) - JSON with obstacle distances per sector
"""
```

### Proposed new docstring

```python
"""
LiDAR Perception - 3D LiDAR Point Cloud Processing (Enhanced v2.0)

Module: LiDAR Perception
Role:   Processes 3D LiDAR point clouds and publishes obstacle information.
See also: Waypoint Planner (Planning) and Heading Controller (Control)

Part of the modular AutoBoat architecture.
Subscribes to 3D LiDAR data, processes point cloud, publishes obstacle information.

Features:
- Three-sector obstacle detection (front, left, right)
- 10th percentile filtering for noise rejection
- Height-based filtering to reject sky/water reflections
- Hysteresis to prevent oscillation at detection boundary

Enhanced Features (v2.0):
- Temporal filtering (multi-scan history for noise rejection)
- Distance-weighted urgency scoring
- Obstacle clustering (gap detection)
- Adaptive sector analysis (target-aware)
- Ground plane removal (water surface filtering)
- VFH polar histogram with target-aware gap selection (uses /control/heading_error)

Topics:
    Subscribes:
        /wamv/sensors/lidars/lidar_wamv_sensor/points (PointCloud2) - raw LiDAR scan
        /planning/current_target (String) - for adaptive front-sector width
        /planning/set_config (String) - runtime parameter updates from dashboard
        /control/heading_error (Float64) - body-frame angle-to-target for VFH targeting

    Publishes:
        /perception/obstacle_info (String) - JSON with obstacle distances per sector
        /perception/param_ranges (String) - JSON parameter validation ranges for dashboard HTML min/max sync
"""
```

### Changes (rationale per line)

| Kind | Line | Rationale |
|:-----|:-----|:----------|
| FIX | `Velocity estimation (moving obstacle tracking)` → `VFH polar histogram with target-aware gap selection (uses /control/heading_error)` | The `moving_obstacles` / velocity-tracking pipeline was removed 20/04 (zero consumers, −124 LOC). Replacing the stale feature line with a factual description of what the v2.0 actually provides today. |
| ADD | `/planning/set_config` sub | Config callback added for runtime parameter updates from dashboard presets (existing code, not documented). |
| ADD | `/control/heading_error` sub | Target-aware VFH added 19/04 — perception subscribes to the controller's body-frame angle error so the VFH free-gap picker aims toward the current waypoint rather than forward. |
| ADD | `/perception/param_ranges` pub | `PARAM_RANGES` class dict published as JSON once on startup + every 5 s so the dashboard can sync HTML input `min`/`max` attributes at runtime (17/04 sync pattern). |

---

## 2. `control/control/heading_controller.py`

### Current docstring (lines 2-30)

```python
"""
Heading Controller - Motion Control System

Module: Heading Controller
Role:   PID heading control, thruster output, and obstacle avoidance maneuvers.
See also: LiDAR Perception (Perception) and Waypoint Planner (Planning)

Part of the modular AutoBoat architecture.
Subscribes to planner targets and perception data, outputs thruster commands.

Features:
- PID heading control with anti-windup
- Simple anti-stuck system (turn left until clear)
- Kalman-filtered drift compensation
- LiDAR Perception v2.1 VFH/polar histogram obstacle avoidance integration

Topics:
    Subscribes:
        /wamv/sensors/gps/gps/fix (NavSatFix) - GPS position
        /wamv/sensors/imu/imu/data (Imu) - Heading orientation
        /planning/current_target (String) - Current navigation target
        /perception/obstacle_info (String) - Obstacle detection data
    
    Publishes:
        /wamv/thrusters/left/thrust (Float64) - Left thruster command
        /wamv/thrusters/right/thrust (Float64) - Right thruster command
        /control/status (String) - Controller status
        /control/anti_stuck_status (String) - Anti-stuck system status
"""
```

### Proposed new docstring

```python
"""
Heading Controller - Motion Control System

Module: Heading Controller
Role:   PID heading control, thruster output, and obstacle avoidance maneuvers.
See also: LiDAR Perception (Perception) and Waypoint Planner (Planning)

Part of the modular AutoBoat architecture.
Subscribes to planner targets and perception data, outputs thruster commands.

Features:
- PID heading control with anti-windup
- Simple Anti-Stuck: turn toward the clearer side (left/right based on sector clearance) until front is clear
- 2D linear Kalman filter for water/wind drift estimation, applied as feed-forward thrust compensation
- LiDAR Perception v2.1 VFH/polar histogram obstacle avoidance integration

Control constants (module-scope, not ROS parameters — change by code edit + rebuild):
- MAX_THRUST        = 2000 N   - hardware limit
- SAFE_THRUST       = 800 N    - operational cap on forward thrust
- TURN_POWER_LIMIT  = 1600 N   - max differential thrust during avoidance
- REVERSE_BURST_THRUST = -1200 N - CQB micro-reverse pulse magnitude
- ESCAPE_TURN_POWER = 450 N    - stuck-escape spin-in-place magnitude
- INTEGRAL_LIMIT    = 0.5 rad  - PID anti-windup bound

Topics:
    Subscribes:
        /wamv/sensors/gps/gps/fix (NavSatFix) - GPS position
        /wamv/sensors/imu/imu/data (Imu) - Heading orientation
        /planning/current_target (String) - Current navigation target
        /perception/obstacle_info (String) - Obstacle detection data
        /planning/mission_status (String) - Mission state (for E-Stop gate)
        /planning/set_config (String) - runtime parameter updates from dashboard
        /planning/emergency_stop (Bool, latched RELIABLE depth=1) - dedicated E-Stop channel

    Publishes:
        /wamv/thrusters/left/thrust (Float64) - Left thruster command
        /wamv/thrusters/right/thrust (Float64) - Right thruster command
        /control/status (String) - Controller status
        /control/anti_stuck_status (String) - Anti-stuck system status
        /control/heading_error (Float64) - body-frame angle-to-target, published per control tick for perception VFH targeting
        /control/param_ranges (String) - JSON parameter validation ranges for dashboard HTML min/max sync
"""
```

### Changes (rationale per line)

| Kind | Line | Rationale |
|:-----|:-----|:----------|
| FIX | `Simple anti-stuck system (turn left until clear)` → `turn toward the clearer side (left/right based on sector clearance) until front is clear` | The anti-stuck rewrite earlier moved from "always turn left" to "pick the clearer side". The hardcoded-left text is a leftover from the v2.x era. |
| FIX | `Kalman-filtered drift compensation` → fuller phrasing with feed-forward application | Drift compensation was actually wired on 20/04 (previously declared but unused). Mentioning the feed-forward application pins down the mechanism. |
| ADD | `/planning/mission_status` sub | Controller gates on mission state for E-Stop / paused handling; existing code, not documented. |
| ADD | `/planning/set_config` sub | Config callback added for runtime parameter updates (same pattern as perception / planner). |
| ADD | `/planning/emergency_stop` sub | Dedicated latched-Bool E-Stop channel added 20/04 (replaces the old retry-over-mission_command pattern). |
| ADD | `/control/heading_error` pub | Published per control tick since 19/04 so perception can target-aware-VFH. |
| ADD | `/control/param_ranges` pub | `PARAM_RANGES` class dict published as JSON same pattern as perception (17/04). |
| ADD | Control constants subsection | 6 module-scope constants (MAX_THRUST / SAFE_THRUST / TURN_POWER_LIMIT / REVERSE_BURST_THRUST / ESCAPE_TURN_POWER / INTEGRAL_LIMIT) listed inline so readers of the top-of-file docstring see the thrust envelope without diving into code. REVERSE_BURST_THRUST and ESCAPE_TURN_POWER were just extracted to names on 21/04 — fresh context worth surfacing. |

---

## 3. `plan/plan/waypoint_planner.py`

### Current docstring (lines 2-26)

```python
"""
Waypoint Planner - GPS Waypoint Navigation Planning

Module: Waypoint Planner
Role:   Generates waypoints, manages mission state, and publishes navigation targets.
See also: LiDAR Perception (Perception) and Heading Controller (Control)

Part of the modular AutoBoat architecture.
Generates lawnmower pattern waypoints, publishes navigation path.

Features:
- Lawnmower pattern generation for systematic coverage
- State machine: INIT -> WAITING_CONFIRM -> READY -> DRIVING -> FINISHED
- Waypoint timeout with skip-to-next fallback
- Return home mode with detour insertion

Topics:
    Subscribes:
        /wamv/sensors/gps/gps/fix (NavSatFix) - GPS position
    
    Publishes:
        /planning/waypoints (String) - JSON list of waypoints
        /planning/current_target (String) - JSON current target waypoint
        /planning/mission_status (String) - JSON mission state
"""
```

### Proposed new docstring

```python
"""
Waypoint Planner - GPS Waypoint Navigation Planning

Module: Waypoint Planner
Role:   Generates waypoints, manages mission state, and publishes navigation targets.
See also: LiDAR Perception (Perception) and Heading Controller (Control)

Part of the modular AutoBoat architecture.
Generates lawnmower pattern waypoints, publishes navigation path.

Features:
- Lawnmower pattern generation for systematic coverage
- State machine (8 states):
    INIT -> WAITING_CONFIRM -> READY -> DRIVING -> FINISHED (happy path)
    PAUSED (via stop/resume), JOYSTICK (manual override), EMERGENCY_STOP (latched)
- Multi-level obstacle handling:
    (a) opportunistic side detour if lateral gap >= 8 m (planner-side, no waypoint insertion)
    (b) auto-detour waypoint insertion after 30 s blocked (14 m lateral offset)
    (c) A* reroute or waypoint skip after 45 s blocked
- Runtime A* path planning (default on): 3 m grid, 12 m safety margin, 20k max expansions
- Optional Hybrid Mode (astar_hybrid_mode=false by default): pre-plan full path once vs tick-by-tick replan
- Return home mode with detour insertion

Topics:
    Subscribes:
        /wamv/sensors/gps/gps/fix (NavSatFix) - GPS position
        /perception/obstacle_info (String) - obstacle detection for skip / detour logic
        /planning/mission_command (String) - dashboard / CLI commands (start, resume, confirm, go_home, reset, joystick)
        /planning/set_config (String) - runtime parameter updates from dashboard
        /planning/emergency_stop (Bool, latched RELIABLE depth=1) - dedicated E-Stop channel
        /control/replan_request (String) - reroute trigger from controller when blocked

    Publishes:
        /planning/waypoints (String) - JSON list of waypoints
        /planning/current_target (String) - JSON current target waypoint
        /planning/mission_status (String) - JSON mission state
        /planning/config (String) - runtime parameter snapshot
        /planning/param_ranges (String) - JSON parameter validation ranges for dashboard HTML min/max sync

    Services:
        /planning/stop_mission (std_srvs/Trigger) - ACK-based stop (replaces retry-over-topic)
        /planning/generate_waypoints (std_srvs/Trigger) - ACK-based lawnmower generation
"""
```

### Changes (rationale per line)

| Kind | Line | Rationale |
|:-----|:-----|:----------|
| FIX | State machine line: expanded from 5 to 8 states | The original docstring showed only the happy path. Actual `self.state = "..."` assignments across the file emit 8 distinct states. Listing them in a "happy path + side-states" form preserves readability. |
| FIX | Features section: expanded from 4 to 6 items | The original Features listed only happy-path behaviours (lawnmower, state machine, timeout, return home). Now explicit: (a) 3-level obstacle handling (opportunistic side detour / auto-detour insertion / A\* reroute + skip) with thresholds spelled out; (b) Runtime A\* with its key params (3m grid, 12m safety margin, 20k expansions); (c) optional Hybrid Mode toggle. Readers of the top docstring should see the planner's decision hierarchy without diving into methods. |
| ADD | `/perception/obstacle_info` sub | `obstacle_callback` (line 537) subscribes; used for waypoint-skip logic. Existing code, not documented. |
| ADD | `/planning/mission_command` sub | Dashboard and CLI push commands here; this is the primary command channel. Exists since early versions but never in the top docstring. |
| ADD | `/planning/set_config` sub | Config callback added for runtime parameter updates (same pattern as perception / controller). |
| ADD | `/planning/emergency_stop` sub | Dedicated latched E-Stop channel added 20/04. |
| ADD | `/control/replan_request` sub | Controller requests reroute when path is blocked; existing since A\* work. |
| ADD | `/planning/config` pub | Runtime parameter snapshot published periodically; existing, not documented. |
| ADD | `/planning/param_ranges` pub | Same `PARAM_RANGES` pattern as perception / controller (17/04). |
| ADD | Services section | `/planning/stop_mission` and `/planning/generate_waypoints` are `std_srvs/Trigger` services added 20/04 (replaced the retry-over-topic anti-pattern). Services are distinct from topics and deserve their own subsection. |

---

## Additional fixes bundled (originally out-of-I6-scope, now included above)

Three follow-up items surfaced while drafting. Items 2 and 3 are now incorporated into the proposed docstrings above; item 1 turned out to be a false alarm on closer inspection.

1. **Lidar Perception `Features` list — "10th percentile filtering"** — **false alarm, no change.** Grep on `lidar_perception.py` shows "10th percentile" in the docstring refers to sector-clearance calculation (line 705 and line 740: `10th percentile for robustness`), not water-plane removal. The 5th percentile (line 424, `sorted_z[len(sorted_z) // 20]`) applies to a *different* filter (water plane removal) which is not in the docstring Features list at all. Original docstring is factually correct — leave alone.
2. **Planner "Features" mentions only v1 items** — **bundled.** Expanded to include 3-level obstacle handling (side detour / auto-detour / A\* reroute) with thresholds, Runtime A\* parameters, and the Hybrid Mode toggle. See Planner Changes table for the new FIX row.
3. **Controller `CONTROL CONSTANTS` block** — **bundled.** Six module-scope constants (MAX_THRUST, SAFE_THRUST, TURN_POWER_LIMIT, REVERSE_BURST_THRUST, ESCAPE_TURN_POWER, INTEGRAL_LIMIT) now listed inline in the Features subsection. See Controller Changes table for the ADD row.

---

## Tomorrow's Linux workflow

```bash
cd ~/seal_ws/src/uvautoboat
git pull

# For each of the 3 files: select the """..."""  block at the top,
# replace with the "Proposed new" version from above.

# Per-file syntax check after edit:
python3 -m py_compile plan/plan/lidar_perception.py
python3 -m py_compile control/control/heading_controller.py
python3 -m py_compile plan/plan/waypoint_planner.py

# All 3 clean; no build needed for docstring-only change.

git add plan/plan/lidar_perception.py control/control/heading_controller.py plan/plan/waypoint_planner.py
git commit -m "docs: refresh node docstrings to match current pub/sub + state machine"
git push
```

Expected: 3 files changed, ~15-35 line additions (planner gains more due to Features rewrite, controller gains constants subsection, perception gains sub/pub additions), ~1 line deletion in perception (stale "Velocity estimation" line). Pure documentation — zero runtime effect.
