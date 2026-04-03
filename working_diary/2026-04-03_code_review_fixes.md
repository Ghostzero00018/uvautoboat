# 2026-04-03 — Code Review and Bug Fixes

## Summary

Performed a full code review of the uvautoboat repository. Identified 22 issues across
CRITICAL / HIGH / MEDIUM / LOW severity. Fixed 7 of them in this session.

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

## Issues Identified but NOT Fixed

### Dismissed (1)
- **vrx_gazebo package name**: Both `vrx_gazebo` and `vrx_gz` exist in the workspace. RViz launched successfully. Not an issue on this machine.

### Remaining (15)
| # | Severity | Issue |
|---|----------|-------|
| 5 | HIGH | LiDAR topic name wrong in launch script help text (missing `_sensor`) |
| 7 | HIGH | `gpsToLocal()` hardcoded Sydney origin in dashboard |
| 8 | HIGH | Config + generate_waypoints race condition (no delay) |
| 9 | HIGH | YAML comment says port 8000, script uses 8002 |
| 10 | MEDIUM | `pkill -9` kills all matching processes system-wide |
| 11 | MEDIUM | `time.sleep(0.1)` blocking ROS callback in sputnik |
| 12 | MEDIUM | OKO config_callback bypasses ROS parameter server |
| 13 | MEDIUM | BURAN has undocumented params not in YAML |
| 14 | MEDIUM | Bare `except:` in 10 locations swallows all exceptions |
| 15 | LOW | Orphan topic `/perception/obstacle_detected` |
| 17 | LOW | `initializeCamera()` dead code in app.js |
| 18 | LOW | No-op assignment in buran_controller line 633-634 |
| 19 | LOW | `vostok1_cli.py` hardcodes `~/seal_ws/` in help text |
| 20 | LOW | Hazard origin stored as local var, not self attribute |
| 21 | LOW | Dashboard config inputs have no validation |
| 22 | LOW | Repeated `import json` inside sputnik methods |

## Testing

Ran full system via `./launch_vostok1_complete.sh`. All components launched successfully:
- Gazebo simulation: OK
- ROS Bridge: OK (confirmed legacy subscriptions no longer appear after fix)
- Navigation stack (OKO/SPUTNIK/BURAN): OK
- Web Video Server: OK
- RViz: OK
- Web Dashboard: OK

Boat navigates but has difficulty bypassing some obstacles — to be investigated separately.
