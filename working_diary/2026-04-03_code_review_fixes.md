# 2026-04-03 — Code Review and Bug Fixes

## Summary

Performed a full code review of the uvautoboat repository. Identified 22 issues across
CRITICAL / HIGH / MEDIUM / LOW severity. Fixed 16 of them in this session, dismissed 2, leaving 7 LOW issues remaining.

## Changes Made

### Fix 1: Hardcoded path in vostok1.launch.yaml (CRITICAL)

**File:** `launch/vostok1.launch.yaml` line 158

**Problem:** `pollutant_sdf_glob` was hardcoded to `/home/ghostzero/seal_ws/src/uvautoboat/test_environment/*smoke*.sdf`. Would break on any other machine when launching the YAML directly.

**Fix:** Replaced with empty string `""`. The feature is deprecated (`pollutant_scan_enabled: false`) and the one-click launch script already overrides this value dynamically.

**Effect:** YAML is now portable. No runtime impact since the feature is disabled.

---

### Fix 2: Parameter name mismatch — dead_zone_threshold (CRITICAL)

**File:** `launch/vostok1.launch.yaml` line 206

**Problem:** YAML defined `dead_zone_threshold: 0.5` but BURAN controller declares `turn_deadband_deg` (default 2.0). ROS 2 silently ignores undeclared parameters, so the value was never applied.

**Fix:** Renamed `dead_zone_threshold` to `turn_deadband_deg` in the YAML.

**Effect:** BURAN now receives the intended 0.5-degree deadband instead of defaulting to 2.0 degrees. This means finer heading corrections during navigation.

---

### Fix 3: Dashboard scan_length default 150 vs actual 15 (HIGH)

**File:** `web_dashboard/vostok1/app.js` line 63

**Problem:** JS default `scan_length: 150.0` was 10x larger than the YAML/sputnik value of `15.0`. If a user generated waypoints from the dashboard before ROS synced config, sputnik would receive a 150m scan length.

**Fix:** Changed to `15.0`.

**Effect:** Dashboard shows correct default before ROS connection. Eliminates the 10x waypoint generation error on early clicks.

---

### Fix 4: All other JS config defaults mismatched with YAML (HIGH)

**File:** `web_dashboard/vostok1/app.js` lines 64-71

**Problem:** Multiple defaults diverged from YAML values.

**Changes:**
| Parameter         | Old (JS) | New (JS) | YAML   |
|-------------------|----------|----------|--------|
| scan_width        | 50.0     | 30.0     | 30.0   |
| lanes             | 8        | 10       | 10     |
| kp                | 400.0    | 500.0    | 500.0  |
| kd                | 100.0    | 150.0    | 150.0  |
| base_speed        | 500.0    | 400.0    | 400.0  |
| min_safe_distance | 15.0     | 10.0     | 10.0   |

**Effect:** Dashboard displays correct values before first ROS message arrives.

---

### Fix 5: Remove legacy dead topic subscriptions (LOW)

**File:** `web_dashboard/vostok1/app.js` lines 402-426

**Problem:** Dashboard subscribed to `/vostok1/obstacle_status` and `/vostok1/anti_stuck_status`. These topics are only published by the legacy `vostok1_integrated.py`, not the modular OKO/SPUTNIK/BURAN architecture. Dead subscribers wasting rosbridge resources.

**Fix:** Removed both legacy subscriptions. The modular equivalents (`/perception/obstacle_info` and `/control/anti_stuck_status`) were already subscribed.

**Effect:** Two fewer dead subscriptions in rosbridge. No functional change since no node was publishing to those topics.

---

### Fix 6: Duplicate /planning/mission_status subscription (LOW)

**File:** `web_dashboard/vostok1/app.js` lines 389-400 and 444-465

**Problem:** Two separate subscriptions to the same topic. Every message from sputnik triggered `updateMissionStatus()` twice. The second subscription also did field remapping (e.g. `current_waypoint` -> `waypoint`).

**Fix:** Merged into a single subscription that includes both the field remapping and `updateDetourBadge()` call.

**Effect:** Mission status updates fire once per message instead of twice.

---

### Fix 7: Dashboard cache-busting for app.js

**File:** `web_dashboard/vostok1/index.html` line 931

**Problem:** `app.js` was loaded with a static version query (`?v=14`). Firefox cached the file aggressively, so code changes weren't picked up without a manual hard refresh (Ctrl+Shift+R). This caused confusion during testing — fixes appeared in the source files but the dashboard kept running old code.

**Fix:** Replaced the static `<script src="app.js?v=14">` tag with a dynamic loader that appends `Date.now()` as the version (e.g. `app.js?v=1775207602310`), forcing a fresh fetch every page load.

**Effect:** Verified working — dashboard server logs show `GET /app.js?v=1775207602310 HTTP/1.1 200` (fresh load) instead of `GET /app.js?v=14 HTTP/1.1 304` (cached). Note: the `index.html` itself may still be cached by the browser; one initial hard refresh is needed after this change to pick up the new HTML, after which all future `app.js` updates load automatically.

---

### Fix 8: LiDAR topic name in help text (HIGH)

**File:** `one_click_launch_all/launch_vostok1_complete.sh` line 380

**Problem:** Help text showed `/wamv/sensors/lidars/lidar_wamv/points` but OKO subscribes to `/wamv/sensors/lidars/lidar_wamv_sensor/points` (missing `_sensor`). Users copy-pasting the debug command would get no output.

**Fix:** Changed to `lidar_wamv_sensor/points`.

**Effect:** Debug command now matches the actual topic.

---

### Fix 9: Dashboard GPS origin hardcoded (HIGH)

**File:** `web_dashboard/vostok1/app.js` `gpsToLocal()` function

**Problem:** Hardcoded `originLat = -33.8361`, `originLon = 151.0697` (Sydney Regatta). The ROS nodes use the first GPS fix as origin. This caused a constant offset in dashboard "Local X/Y" display.

**Fix:** Replaced with dynamic origin that stores the first non-zero GPS fix, matching how `sputnik_planner` stores `start_gps`.

**Effect:** Dashboard local coordinates now match the navigation stack's local frame.

---

### Fix 10: Config + generate_waypoints race condition (HIGH)

**File:** `web_dashboard/vostok1/app.js` `generateWaypoints()` function

**Problem:** Config was published then `generate_waypoints` sent immediately on the next line. Sputnik could generate waypoints with old parameters if it hadn't processed the config message yet.

**Fix:** Added 200ms `setTimeout` between config publish and generate command.

**Effect:** Sputnik reliably uses the new config when generating waypoints.

---

### Fix 11: YAML comment port mismatch (HIGH)

**File:** `launch/vostok1.launch.yaml` line 34

**Problem:** Comment said `python3 -m http.server 8000` but the one-click script uses port 8002.

**Fix:** Updated comment to `8002`.

**Effect:** Documentation now matches reality.

---

### Fix 12: CSS cache-busting and cache-control headers

**File:** `web_dashboard/vostok1/index.html`

**Problem:** `style_merged.css?v=2` used a static version tag (same issue as app.js). Also, `index.html` itself was cached by Firefox (`304`), and `favicon.ico` returned `404` on every load.

**Fix:**
- Dynamic `Date.now()` loader for CSS
- `Cache-Control: no-cache, no-store, must-revalidate` meta headers for `index.html`
- `<link rel="icon" href="data:,">` to suppress favicon request

**Effect:** All assets load fresh. No more `favicon.ico 404`. Browser always validates `index.html`.

---

### Fix 13: Remove blocking `time.sleep(0.1)` in sputnik callback (MEDIUM)

**File:** `plan/plan/sputnik_planner.py` line 500

**Problem:** `time.sleep(0.1)` inside a ROS callback blocked the single-threaded executor for 100ms. All other callbacks (GPS, obstacle, IMU) were delayed.

**Fix:** Removed the sleep. The preceding `publish_mission_status_timer()` already queues the message asynchronously.

**Effect:** No more 100ms callback blockage during "Go Home" state transition.

---

### Fix 14: OKO and BURAN config_callback bypass ROS parameter server (MEDIUM)

**Files:** `plan/plan/oko_perception.py`, `control/control/buran_controller.py`

**Problem:** Dashboard config updates used `setattr()` directly, never calling `set_parameters()`. `ros2 param get` returned stale launch-time values.

**Fix:**
- OKO: Added `self.set_parameters([rclpy.parameter.Parameter(...)])` in the config loop
- BURAN: Added bulk `set_parameters()` sync at the end of `config_callback`

**Effect:** `ros2 param get` and `ros2 param dump` now return live values after dashboard config changes.

---

### Fix 15: BURAN undocumented params added to YAML (MEDIUM)

**File:** `launch/vostok1.launch.yaml` BURAN section

**Problem:** 5 parameters were declared in Python with defaults but never appeared in the YAML. The YAML wasn't a complete config reference.

**Added:**
| Parameter | Value | Purpose |
|-----------|-------|---------|
| `slew_rate_limit` | 80.0 | Max thrust change per cycle (N) |
| `min_safe_distance` | 12.0 | Obstacle avoidance trigger distance (m) |
| `max_reverse_distance` | 25.0 | Max meters to reverse during escape |
| `bank_slow_distance` | 6.0 | Start slowing near obstacles (m) |
| `bank_slow_factor` | 0.25 | Speed multiplier when near banks |

**Effect:** YAML is now the complete config reference for BURAN. All tunable parameters are visible and documented.

---

### Fix 16: Bare `except:` replaced across codebase (MEDIUM)

**Files:** 7 files, 10 locations

**Problem:** Bare `except:` catches `KeyboardInterrupt` and `SystemExit`, making Ctrl+C unreliable and silently swallowing errors.

**Fix:** Replaced all `except:` with `except Exception:` in:
- `oko_perception.py` (1)
- `sputnik_planner.py` (1)
- `vostok1_cli.py` (3)
- `atlantis_planner.py` (2)
- `simple_perception.py` (1)
- `oko_perception_fixed.py` (1)
- `atlantis_planner_fixed.py` (1)

**Effect:** Ctrl+C now cleanly shuts down nodes. `KeyboardInterrupt` and `SystemExit` are no longer swallowed.

---

## Issues Identified but NOT Fixed

### Dismissed (2)
- **vrx_gazebo package name**: Both `vrx_gazebo` and `vrx_gz` exist in the workspace. RViz launched successfully. Not an issue on this machine.
- **`pkill -9` system-wide**: Single user, single session — non-issue in practice.

### Remaining (7)
| # | Severity | Issue |
|---|----------|-------|
| 15 | LOW | Orphan topic `/perception/obstacle_detected` |
| 17 | LOW | `initializeCamera()` dead code in app.js |
| 18 | LOW | No-op assignment in buran_controller line 633-634 |
| 19 | LOW | `vostok1_cli.py` hardcodes `~/seal_ws/` in help text |
| 20 | LOW | Hazard origin stored as local var, not `self` |
| 21 | LOW | Dashboard config inputs no validation |
| 22 | LOW | Repeated `import json` inside sputnik methods |

## Testing

Ran full system via `./launch_vostok1_complete.sh` three times during the session. All components launched successfully each time:
- Gazebo simulation: OK
- ROS Bridge: OK (single `/planning/mission_status`, no legacy topics)
- Navigation stack (OKO/SPUTNIK/BURAN): OK
- Web Video Server: OK
- RViz: OK
- Web Dashboard: OK (cache-busting confirmed: `app.js` and `style_merged.css` served fresh on every load)

Boat navigates but has difficulty bypassing some obstacles — to be investigated separately.

Boat navigates but has difficulty bypassing some obstacles — to be investigated separately.
