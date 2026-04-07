# 2026-04-07 — Continued Cleanup and Consistency Fixes

## Summary

Continued from the 2026-04-03 code review session. Fixed all 7 remaining LOW issues and discovered 3 additional parameter default mismatches during a consistency audit. Also added documentation comments to previously dismissed issues.

## Changes Made

### Fix 1: Add pkill -9 caution comments (Dismissed issue — documented)

**Files:** `launch_vostok1_complete.sh`, `launch_robust_avoidance_complete.sh`

**Problem:** `pkill -9 -f` matches processes system-wide. On a shared machine this could kill other users' processes.

**Fix:** Added caution comment above `cleanup()` in both launch scripts warning about system-wide process matching.

**Effect:** Future developers are warned before modifying cleanup behavior.

---

### Fix 2: Add vrx_gazebo vs vrx_gz comment (Dismissed issue — documented)

**Files:** `launch_vostok1_complete.sh`, `launch_robust_avoidance_complete.sh`

**Problem:** RViz is launched via `vrx_gazebo` (legacy package) while simulation uses `vrx_gz` (Gazebo Harmonic). This could confuse developers.

**Fix:** Added comment above `ros2 launch vrx_gazebo rviz.launch.py` explaining that `rviz.launch.py` only exists in `vrx_gazebo`, not `vrx_gz`.

**Effect:** Explains the dual-package dependency for future reference.

---

### Fix 3: Remove orphan /perception/obstacle_detected topic (#15)

**File:** `plan/plan/oko_perception.py`

**Problem:** OKO published `/perception/obstacle_detected` (Bool) but no node subscribed to it. Wasted resources publishing to nobody.

**Fix:** Removed the publisher, the publish call, the `Bool` import, and the docstring reference.

**Effect:** One fewer unused topic on the ROS graph. Obstacle info is still available via `/perception/obstacle_info` (JSON), which BURAN and SPUTNIK subscribe to.

---

### Fix 4: Remove initializeCamera() dead code (#17)

**File:** `web_dashboard/vostok1/app.js`

**Problem:** `initializeCamera()`, `subscribeToCamera()`, and 3 associated variables (`cameraTopic`, `cameraImage`, `cameraStatus`) were defined but never called. The dashboard uses `web_video_server` for camera streaming instead.

**Fix:** Removed the entire dead camera block (~70 lines).

**Effect:** Cleaner codebase. Active camera streaming via `web_video_server` is untouched.

---

### Fix 5: Remove no-op assignment in buran_controller (#18)

**File:** `control/control/buran_controller.py`

**Problem:** Lines 643-644 checked `if self.reverse_start_time is None` (always true, since line 639 just set it to None) and then assigned `self.reverse_start_time = None` again. Copy-paste artifact.

**Fix:** Removed the redundant 2-line block.

**Effect:** No functional change. Cleaner reverse logic flow.

---

### Fix 6: Replace hardcoded path in vostok1_cli.py (#19)

**File:** `plan/plan/vostok1_cli.py`

**Problem:** Help text hardcoded `~/seal_ws/src/uvautoboat/launch/vostok1.launch.yaml`. Would show wrong path if repo is cloned elsewhere.

**Fix:** Added `Path(__file__).resolve().parents[2]` to dynamically resolve the repo root. Both occurrences (lines 257 and 499) now use `_LAUNCH_FILE`.

**Effect:** Help text shows correct path regardless of where the workspace is located.

---

### Fix 7: Store hazard origin as self attributes (#20)

**File:** `plan/plan/sputnik_planner.py`

**Problem:** Hazard origin was stored as local variables `origin_wx`, `origin_wy` at init, lost after `__init__` completed. Runtime config callback used `getattr(self, ..., 0.0)` fallback.

**Fix:** Changed to `self.hazard_origin_world_x` and `self.hazard_origin_world_y`. Removed `getattr` fallback since attributes are now guaranteed to exist.

**Effect:** Hazard origin persists correctly between init and runtime config updates.

---

### Fix 8: Add dashboard config input validation (#21)

**File:** `web_dashboard/vostok1/app.js`

**Problem:** `sendConfig()` and `generateWaypoints()` read input values with `parseFloat()`/`parseInt()` without validation. NaN or out-of-range values could be sent to ROS nodes.

**Fix:** Added `readInput()` helper that:
- Falls back to a safe default if value is NaN
- Clamps to the HTML element's `min`/`max` range
Applied to all config inputs in `sendConfig()` and `generateWaypoints()`.

**Effect:** Invalid input values are caught before being sent to ROS.

---

### Fix 9: Fix waypoint generation HTML/hidden field defaults

**Files:** `web_dashboard/vostok1/index.html`

**Problem:** Waypoint generation inputs and hidden config fields had wrong defaults:
| Input | Old | New (YAML) |
|-------|-----|------------|
| wp-lanes / cfg-lanes | 8 | 10 |
| wp-length / cfg-scan-length | 150 | 15 |
| wp-width / cfg-scan-width | 50 | 30 |

**Fix:** Updated all 6 HTML input values to match YAML.

**Effect:** Dashboard shows correct defaults before ROS connection for waypoint generation panel.

---

### Fix 10: Sync remaining Python/HTML defaults to YAML

**Files:** `buran_controller.py`, `sputnik_planner.py`, `index.html`, `app.js`

**Problem:** Several Python `declare_parameter()` defaults and HTML input defaults diverged from YAML:
| Parameter | Old Python/HTML | New (YAML) |
|-----------|----------------|------------|
| kp | 400.0 | 500.0 |
| kd | 100.0 | 150.0 |
| base_speed | 500.0 | 400.0 |
| approach_slow_distance | 5.0 | 10.0 |
| waypoint_tolerance | 2.0 | 3.5 |

**Fix:** Updated all `declare_parameter()` defaults, HTML `value` and `data-default` attributes, and `readInput()` fallbacks.

**Effect:** All Vostok1 config defaults are consistent across YAML, Python, HTML, and JS.

---

### Fix 11: Remove repeated import json in sputnik (#22)

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `import json` appeared at the top of the file (line 27) AND inside 7 individual methods. The local imports were redundant.

**Fix:** Removed all 7 in-method `import json` statements.

**Effect:** Cleaner code. No functional change — top-level import handles everything.

---

## Issues Discovered (Not Yet Fixed)

| # | Severity | Issue |
|---|----------|-------|
| 1 | CRITICAL | Detour waypoints inserted as dicts but accessed as tuples — crash bug in sputnik_planner.py:550-551 vs 822 |
| 2 | HIGH | BURAN defaults still mismatched: obstacle_slow_factor (0.3→0.5), turn_deadband_deg (2.0→0.5), critical_distance (5.0→6.0) |
| 3 | HIGH | Missing `max_block_time` parameter in vostok1.launch.yaml (declared in sputnik with default 30.0) |
| 4 | MEDIUM | Shell single-quote in launch_vostok1_complete.sh:262 prevents $WORLD variable expansion |
| 5 | MEDIUM | innerHTML with unsanitized world name in app.js:113 |

## Original Problem List Final Status

All 22 issues from the 2026-04-03 review are now resolved:
- 16 fixed on 2026-04-03
- 7 fixed on 2026-04-07 (issues #15, #17, #18, #19, #20, #21, #22)
- 2 dismissed with documentation comments added on 2026-04-07

5 new issues discovered during today's deeper review — to be addressed next.
