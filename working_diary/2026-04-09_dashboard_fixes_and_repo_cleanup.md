# 2026-04-09 — Dashboard Fixes, Performance Optimization, and Repo Cleanup

## Summary

Major dashboard overhaul: fixed race conditions, improved performance, reorganized repo, updated documentation.

---

## Problems Detected and Solved

### Dashboard — Race Conditions & Logic Bugs

#### Fix 1: GO HOME disabled after RESET

**File:** `web_dashboard/vostok1/app.js`
**Problem:** GO HOME button was gated by `hasWaypoints`, but `go_home` in SPUTNIK creates its own waypoint to spawn — doesn't need pre-existing waypoints.
**Fix:** Separated `canGoHome` logic from `canStart`. GO HOME now requires only `connected + gpsReady`, works from DRIVING state too.

#### Fix 2: Route config inputs flickering after RESET

**File:** `web_dashboard/vostok1/app.js`
**Problem:** `/sputnik/config` publishes at 1Hz and overwrites `wp-lanes`, `wp-length`, `wp-width` inputs. After RESET, user edits get overwritten by ROS within 1 second. The dirty-clear logic could prematurely clear the dirty flag.
**Fix:** Skip ROS config overwrites for route params (`cfg-lanes`, `cfg-scan-length`, `cfg-scan-width`, `wp-*`) when boat is in INIT/IDLE state.

#### Fix 3: Waypoint map jitter

**File:** `web_dashboard/vostok1/app.js`
**Problem:** Two causes: (1) When `missionState.startLat/Lon` was null, used live GPS as reference — waypoints shifted as boat moved. (2) `displayWaypointsOnMap()` did clear+redraw on every call even when nothing changed.
**Fix:** Lock in fallback GPS reference on first use. Added cache key check to skip redundant redraws.

#### Fix 4: No button debounce

**File:** `web_dashboard/vostok1/app.js`
**Problem:** Rapid clicks on Generate/Start/Stop sent duplicate commands to ROS.
**Fix:** Added 800ms `debounceCommand()` wrapper on all mission buttons. Emergency Stop excluded (safety critical).

#### Fix 5: Reset doesn't clear startLat/Lon

**File:** `web_dashboard/vostok1/app.js`
**Problem:** After RESET, old GPS reference point persisted, causing waypoints to display at wrong positions.
**Fix:** Added `missionState.startLat = null; missionState.startLon = null` to reset handler.

#### Fix 6: Stale publishers after WebSocket reconnect

**File:** `web_dashboard/vostok1/app.js`
**Problem:** On reconnect, `ros` object is recreated but old publishers still reference the dead connection.
**Fix:** Null all publishers (`missionCommandPublisher`, `configPublisher`, etc.) in `ros.on('close')`.

#### Fix 7: Missing dirty tracking for approach params

**File:** `web_dashboard/vostok1/app.js`
**Problem:** `cfg-waypoint-tolerance`, `cfg-approach-slow-distance`, `cfg-approach-slow-factor` not in `allConfigInputs` — user edits silently overwritten by ROS.
**Fix:** Added 3 missing inputs to the `allConfigInputs` array.

#### Fix 8: Config→Generate timing

**File:** `web_dashboard/vostok1/app.js`
**Problem:** 200ms timeout between config publish and generate_waypoints command could race.
**Fix:** Increased to 500ms (conservative for local rosbridge).

---

### Dashboard — Performance Optimization

#### Fix 9: Double updateDetourBadge call

**Problem:** Called at line 409 (subscriber) and line 674 (`updateMissionStatus`) — 2x per message at 5Hz.
**Fix:** Removed duplicate call from subscriber, pass `detour_active` through data object.

#### Fix 10: Duplicate distance DOM writes

**Problem:** `#distance` element updated from both `/planning/current_target` and `updateMissionStatus()`.
**Fix:** Removed distance update from current_target subscriber (mission_status is authoritative).

#### Fix 11: Unconditional DOM updates in updateObstacleStatus (~10Hz)

**Problem:** className, textContent rewritten every callback even when values unchanged.
**Fix:** Added `_prevObstacle` cache, only writes when values differ.

#### Fix 12: Unconditional style updates in updateAntiStuckStatus

**Problem:** style.color and textContent set on every callback.
**Fix:** Added `_prevAntiStuck` cache.

#### Fix 13: Heavy updateMissionProgress at 5Hz

**Problem:** 8+ DOM operations per callback with no change detection.
**Fix:** Added `_prevProgress` cache for all DOM elements.

#### Fix 14: updateWorldBanner recreating DOM elements

**Problem:** Cleared and rebuilt child elements on every call.
**Fix:** Added cache check + single `innerHTML` update.

#### Fix 15: Misplaced code in addTerminalLine

**Problem:** Lines referencing `data.world_name` inside `addTerminalLine()` where `data` was undefined — copy-paste error duplicating `updateWorldFromConfig()` logic.
**Fix:** Removed the misplaced block.

---

### Dashboard — Visual Fixes

#### Fix 16: Config panel overflow (CSS)

**File:** `web_dashboard/vostok1/style_merged.css`
**Problem:** Advanced Configuration labels + tooltips overflowed on horizontal layout.
**Fix:** Switched `.config-item` from horizontal flex to vertical stack (label above input). Updated input to full-width, section headers truncate with ellipsis.

#### Fix 17: White-on-white text in mission control

**File:** `web_dashboard/vostok1/index.html`
**Problem:** "Navigation Mode" h4, planning strategy labels, and "A* Advanced Parameters" inherited `color: white` from dark mission control panel but sat on light `.config-section` background.
**Fix:** Added explicit dark colors to h4 (`var(--accent)`), labels (`#495057`, `#333`), and border (`#dee2e6`).

#### Fix 18: Map colors too similar

**Files:** `app.js`, `style_merged.css`
**Problem:** Waypoint, Path, and Trajectory were all blue variants — hard to distinguish.
**Fix:** Path → purple (`#aa44ff`), Trajectory → green (`#00cc66`). Extended trajectory trail from 300 to 1000 points.

---

### Health Check Improvements

#### Fix 19: State detection using topic existence

**File:** `one_click_launch_all/health_check_vostok1.sh`
**Problem:** Checked if `/planning/mission_status` topic exists — but topics persist after first publish, so always showed ACTIVE after first mission.
**Fix:** Read actual planner state from topic content. INIT/IDLE/FINISHED/JOYSTICK → IDLE; DRIVING/RUNNING/PAUSED/READY → ACTIVE.

#### Fix 20: ANSI color codes breaking parameter parsing

**File:** `one_click_launch_all/health_check_vostok1.sh`
**Problem:** `ros2 param get` output included ANSI codes and RTPS errors. `grep -oP '[-\d.]+'` matched numbers from error messages.
**Fix:** Strip ANSI codes with `sed`, match only `value is: <number>` pattern.

#### Fix 21: Mission-dependent topics as hard FAILs in IDLE

**File:** `one_click_launch_all/health_check_vostok1.sh`
**Problem:** Topics like `/perception/obstacle_info` showed FAIL before mission start.
**Fix:** Split topics into ALWAYS (sensor topics) and MISSION (planning/control topics). MISSION topics show INFO in IDLE state.

---

### Documentation & Repo Cleanup

#### Fix 22: README too long

**Fix:** Split into `README.md` (quick start, ~200 lines) and `USER_MANUAL.md` (full manual, ~1700 lines).

#### Fix 23: README misaligned with repo (18 issues)

**Fix:** Updated project structure tree, removed Atlantis from active listings, fixed broken doc links, removed nonexistent root scripts, updated dashboard topics, fixed waypoint_tolerance (2.0→3.5m).

#### Fix 24: Erk732 → Ghostzero00018

**Fix:** Replaced all 22 occurrences across 10 files (USER_MANUAL, Board.md, 3 package.xml, 5 wiki pages).

#### Fix 25: Contributors section

**Fix:** Added to README — current maintainers (Ghostzero00018, atshehu1776) and previous contributors.

#### Fix 26: LICENSE copyright year

**Fix:** Updated from `2025` to `2025-2026`.

#### Fix 27: Dead code cleanup

- **OKO:** Removed redundant `import json`, 2 commented-out filter blocks, unused `smoke_detected` variable

- **SPUTNIK:** Removed unused `curr_x`/`curr_y` params from `skip_blocked_waypoints()` + 5 call sites
- **Waypoint Visualizer:** Removed unused `self.total_waypoints` assignment

#### Fix 28: Unused files moved to legacy

- `grid_map.py`, `lidar_obstacle_avoidance.py` (both copies), `mission.yaml`, `obstacle_avoidance_config.yaml`, `map_coordinates.csv`, `map_extent.txt` → `legacy/misc/`

- Removed `lidar_obstacle_avoidance` entry points from both setup.py files

#### Fix 29: Custom worlds and plugins moved to legacy

- 5 custom SDF worlds → `legacy/test_worlds/`

- `cardboardbox/` model → `legacy/misc/`
- `environment_plugins/` → `legacy/`

- Default world changed from `sydney_regatta_smoke` to `sydney_regatta_DEFAULT`

---

## Still Pending

### From Today

- **Dashboard visual polish** — config panel layout works but could be more polished (deferred)

### From Previous Days

- **LiDAR tuning** — OKO perception parameters for pier/low-obstacle detection

- **Test map check** — verify alignment between web dashboard minimap and Gazebo world coordinates
- **Control part check** — BURAN review, VFH steering integration test

- **VFH steering** (`use_vfh_bias`) — remains disabled by default, needs separate testing
- **Pier avoidance** — boat detects pier but struggles to route around its end, needs deeper A* tuning

- **`max_speed` in BURAN** — parameter fetched but never constrains speed in control loop (intentional or incomplete?)
- **`drift_compensation_gain` in BURAN** — parameter fetched but never used (intentional or incomplete?)

- **`in_hazard_zone()` in SPUTNIK** — method defined but never called (kept as potential utility)
- **`self.start_gps` in waypoint_visualizer** — attribute set but never used (kept as potential feature)

- **`self.path_pub` in waypoint_visualizer** — publisher created but never published to (kept as potential feature)

---

## Testing

- Health check: 45/45 PASS in both IDLE and ACTIVE states

- Dashboard: config panel no longer overflows, map colors distinct, buttons debounced
- State detection: correctly shows IDLE (planner: INIT) after RESET

---

## Files Modified Today

### Dashboard

- `web_dashboard/vostok1/app.js` — race conditions, debounce, performance caches, map colors

- `web_dashboard/vostok1/index.html` — white-on-white text fix
- `web_dashboard/vostok1/style_merged.css` — config panel CSS, map legend colors

### Health Check

- `one_click_launch_all/health_check_vostok1.sh` — state detection, ANSI parsing, IDLE/ACTIVE logic

### Documentation

- `README.md` — new quick start guide

- `USER_MANUAL.md` — renamed from old README, updated structure and references

### Code Cleanup

- `plan/plan/oko_perception.py` — dead code removal

- `plan/plan/sputnik_planner.py` — dead code removal
- `plan/plan/waypoint_visualizer.py` — dead code removal

- `plan/setup.py` — removed stale entry point
- `control/setup.py` — removed stale entry point

### Repo Organization

- `one_click_launch_all/launch_vostok1_complete.sh` — default world, header cleanup

- `Board.md`, `LICENSE`, 3× `package.xml`, 5× wiki pages — Erk732→Ghostzero00018, copyright year
- Moved 7 unused files to `legacy/misc/`

- Moved 5 SDF worlds to `legacy/test_worlds/`
- Moved `cardboardbox/` to `legacy/misc/`

- Moved `environment_plugins/` to `legacy/`
