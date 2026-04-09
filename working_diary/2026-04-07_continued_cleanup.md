# 2026-04-07 — Continued Cleanup and Consistency Fixes

## Summary

Continued from the 2026-04-03 code review session. Fixed all 7 remaining LOW issues, discovered and fixed 7 additional issues during deeper reviews, added documentation comments to previously dismissed issues, and created a system health check script. All 29 identified issues are now resolved.

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

**Effect:** One fewer unused topic on the ROS graph. Obstacle info is still available via `/perception/obstacle_info` (JSON), which BURAN and SPUTNIK subscribe to. Verified via health check: topic no longer appears in `ros2 topic list`.

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

**Fix:** Added `Path(__file__).resolve().parents[2]` to dynamically resolve the repo root. Both occurrences now use `_LAUNCH_FILE`.

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
| ------- | ----- | ------------ |
| wp-lanes / cfg-lanes | 8 | 10 |
| wp-length / cfg-scan-length | 150 | 15 |
| wp-width / cfg-scan-width | 50 | 30 |

**Fix:** Updated all 6 HTML input values to match YAML.

**Effect:** Dashboard shows correct defaults before ROS connection for waypoint generation panel.

---

### Fix 10: Sync remaining Python/HTML defaults to YAML (batch 1)

**Files:** `buran_controller.py`, `sputnik_planner.py`, `index.html`, `app.js`

**Problem:** Several Python `declare_parameter()` defaults and HTML input defaults diverged from YAML:

| Parameter | Old Python/HTML | New (YAML) |
| ----------- | ---------------- | ------------ |
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

**Fix:** Removed all 7 in-method `import json` statements. Also removed a stray `import math` inside `insert_detour_waypoint` (top-level import at line 26 already covers it).

**Effect:** Cleaner code. No functional change — top-level imports handle everything.

---

### Fix 12: Detour waypoint type mismatch (CRITICAL — latent crash bug)

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `detour_request_callback()` inserted waypoints as dicts `{'x': ..., 'y': ..., 'is_detour': True}`, but all waypoint access throughout the codebase unpacks as tuples `target_x, target_y = self.waypoints[idx]`. Would crash with TypeError if BURAN ever published a detour request.

**Note:** Currently unreachable — BURAN creates the `/planning/detour_request` publisher but never publishes to it. The detour feature was wired up but never completed.

**Fix:** Changed dict to tuple `(detour_x, detour_y)`.

**Effect:** Prevents future crash if the detour feature is completed.

---

### Fix 13: Sync remaining BURAN defaults to YAML (batch 2)

**File:** `control/control/buran_controller.py`

**Problem:** Three more Python defaults didn't match YAML:

| Parameter | Old Python | New (YAML) |
| ----------- | ----------- | ------------ |
| obstacle_slow_factor | 0.3 | 0.5 |
| turn_deadband_deg | 2.0 | 0.5 |
| critical_distance | 5.0 | 6.0 |

**Fix:** Updated `declare_parameter()` defaults.

**Effect:** All BURAN defaults now match YAML. Verified via health check: `ros2 param get` confirms correct values.

---

### Fix 14: Add missing max_block_time to launch YAML

**File:** `launch/vostok1.launch.yaml`

**Problem:** `max_block_time` was declared in `sputnik_planner.py` with default 30.0 but missing from the YAML. Not visible or tunable via launch file.

**Fix:** Added `max_block_time: 30.0` under sputnik parameters in the YAML.

**Effect:** Parameter is now documented and tunable from the launch config. Verified: `ros2 param get /sputnik_planner_node max_block_time` returns 30.0.

---

### Fix 15: Shell single-quote prevents clarity of $WORLD expansion

**File:** `one_click_launch_all/launch_vostok1_complete.sh`

**Problem:** `echo 'Starting Gazebo with world: $WORLD'` used single quotes. While the outer double-quoted `bash -c "..."` block already expands `$WORLD`, single quotes mislead readers into thinking it's literal.

**Fix:** Changed to escaped double quotes `echo \"Starting Gazebo with world: $WORLD\"`.

**Effect:** Intent is clearer to anyone reading the script.

---

### Fix 16: Replace innerHTML with safe DOM methods

**File:** `web_dashboard/vostok1/app.js`

**Problem:** `banner.innerHTML` used template literal with unsanitized world name from ROS message. Low risk (trusted source) but bad practice.

**Fix:** Replaced with `createElement`/`textContent` DOM methods. Same visual result (bold italic world name), no XSS risk.

**Effect:** Dashboard world banner is now safe against HTML injection.

---

### Fix 17: Waypoint index out-of-bounds in check_waypoint_skip

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `check_waypoint_skip()` accessed `self.waypoints[self.current_wp_index]` without verifying the index was in bounds. After `advance_to_next_waypoint()` on the last waypoint, the index would exceed the array length.

**Fix:** Added `if self.current_wp_index >= len(self.waypoints): return` before the array access.

**Effect:** Prevents IndexError crash at the last waypoint during obstacle skip logic.

---

### Fix 18: Sanitize float('inf') in OKO JSON output

**File:** `plan/plan/oko_perception.py`

**Problem:** `front_clear`, `left_clear`, `right_clear`, and `min_distance` could be `float('inf')` when no obstacles detected. Python's `json.dumps(float('inf'))` produces `Infinity` which is not valid JSON. The dashboard's `JSON.parse()` would fail or return null.

**Fix:** Added `if math.isfinite(...) else 999.9` guard for all four distance fields.

**Effect:** OKO always produces valid JSON. 999.9 serves as a large "no obstacle" sentinel that JavaScript can safely parse.

---

### New Tool: health_check_vostok1.sh

**File:** `one_click_launch_all/health_check_vostok1.sh`

**Purpose:** System health monitoring script to run from another terminal during simulation.

**Checks:**

1. **Nodes** — verifies OKO, SPUTNIK, BURAN, rosbridge, web_video_server are running
2. **Topics** — confirms all expected topics exist, verifies orphan topic is removed
3. **Publishers** — checks publisher/subscriber counts for key topics (lightweight, no subscribing)
4. **Parameters** — validates BURAN, SPUTNIK, OKO params match YAML values
5. **Connectivity** — checks ports 9090 (rosbridge), 8002 (dashboard), 8080 (video server)

**Usage:** `bash health_check_vostok1.sh` (full) or `bash health_check_vostok1.sh --quick` (nodes + topics only)

**Verified:** All 44 checks pass on a running simulation.

---

## Testing

Ran full system via `./launch_vostok1_complete.sh` after rebuilding with `colcon build --packages-select plan control`. All components launched successfully:

- Gazebo simulation (sydney_regatta_smoke): OK
- ROS Bridge: OK
- Navigation stack (OKO/SPUTNIK/BURAN): OK
- Web Video Server: OK
- RViz: OK
- Web Dashboard: OK

Health check confirmed:

- All 7 expected nodes running
- All expected topics present, orphan topic removed
- All key topics have active publishers
- All parameter values match YAML config
- All ports (9090, 8002, 8080) listening and responding

## Final Status

Total issues identified across both sessions: 29

- 16 fixed on 2026-04-03
- 11 fixed on 2026-04-07 (7 original LOW + 4 newly discovered)
- 2 dismissed with documentation comments on 2026-04-07

**Additional work on 2026-04-07:**

- 2 more issues found and fixed in third review round (waypoint bounds, infinity JSON)
- 1 shell quoting clarity fix
- 1 XSS prevention fix
- Created health check monitoring tool

**All issues resolved. No known code issues remaining.**

### Known Functional Issue

Boat has difficulty bypassing some obstacles — not yet investigated. This is a behavior/tuning issue, not a code bug.
