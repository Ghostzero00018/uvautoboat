# 2026-04-08 — Obstacle Avoidance Fixes

## Summary

Fixed the detour waypoint explosion (300+ waypoints generated during obstacle encounters) and strengthened BURAN's reactive avoidance. Also fixed a critical missing method bug and removed dead code. All changes validated via simulation — mission completed 18 waypoints in 4.9 minutes with no waypoint explosion.

## Problem

During simulation, the boat generated 300+ detour waypoints when encountering obstacles but still failed to bypass them. Root cause: a feedback loop in SPUTNIK's detour insertion logic combined with too-conservative avoidance in BURAN.

## Root Cause Analysis

### Detour Explosion (SPUTNIK)
- `obstacle_callback` (line 540) reset `detour_waypoint_inserted = False` whenever obstacles momentarily cleared between LiDAR scans, allowing immediate re-insertion
- No cumulative cap on detour insertions per waypoint
- No cooldown between detour insertions
- `insert_detour_waypoint()` always went LEFT without checking clearance
- Neither insertion function validated that the detour point was actually clear of obstacles

### Weak BURAN Avoidance
- `max_avoidance_turn_deg = 20` — too conservative, boat couldn't turn sharply enough
- Escape mode always turned LEFT regardless of which side had more clearance
- `request_replan()` called at line 662 but method never defined — caused silent `AttributeError` during high-urgency encounters
- Code defaults for `reverse_timeout` (3.0) and `avoid_diff_gain` (25.0) didn't match YAML (4.0 and 18.0)

## Changes Made

### Fix 1: Remove premature detour flag reset (CRITICAL)

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `obstacle_callback` reset `detour_waypoint_inserted = False` on every momentary obstacle clear, enabling rapid re-insertion loop.

**Fix:** Removed the reset from `obstacle_callback`. Flag now only resets on: waypoint reached, waypoint advance, or detour timeout (15s).

**Effect:** Stops the core feedback loop that caused 300+ waypoint insertions.

---

### Fix 2: Add detour counter, cap, and cooldown

**File:** `plan/plan/sputnik_planner.py`

**Problem:** No limit on how many detours could be inserted for a single original waypoint.

**Fix:** Added:
- `detour_count` — tracks insertions per waypoint
- `max_detours_per_waypoint = 3` — after 3 failed detours, skip the waypoint
- `detour_cooldown = 5.0s` — minimum time between detour insertions
- `last_detour_time` — timestamp tracking

Guards added to both `insert_detour_waypoint()` and `insert_side_detour()`. Counter resets in `advance_to_next_waypoint()` and all state transition resets (start, resume, go_home).

**Effect:** Bounds worst-case waypoint growth to 3 per original waypoint.

---

### Fix 3: Validate detour points against obstacle clusters

**File:** `plan/plan/sputnik_planner.py`

**Problem:** Detour waypoints were inserted without checking if the destination was obstructed.

**Fix:** Added `_is_detour_clear(detour_x, detour_y, min_clearance=8.0)` helper that checks against known OKO obstacle clusters. Both insertion functions now:
1. Validate the chosen side
2. If blocked, try the opposite side
3. If both blocked, skip the waypoint

**Effect:** Prevents inserting detour waypoints into obstacles.

---

### Fix 4: Choose clearer side for detours

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `insert_detour_waypoint()` always went LEFT (heading + pi/2) regardless of obstacle position.

**Fix:** Now uses `left_clear` vs `right_clear` from OKO data to choose the clearer side.

**Effect:** Detour waypoints are placed on the side with more room.

---

### Fix 5: Fix missing request_replan() method (CRITICAL BUG)

**File:** `control/control/buran_controller.py`

**Problem:** `self.request_replan(reason="path_blocked")` called at line 662 but method never defined. Publisher `pub_replan_request` existed at line 335 but had no method to use it. Caused `AttributeError` during high-urgency obstacle encounters.

**Fix:** Added `request_replan()` method that publishes JSON with type, position, and reason to `/control/replan_request`.

**Effect:** Eliminates silent crash during high-urgency encounters. Enables BURAN to request A* replanning from SPUTNIK.

---

### Fix 6: Increase max avoidance turn angle

**Files:** `control/control/buran_controller.py`, `launch/vostok1.launch.yaml`

**Problem:** `max_avoidance_turn_deg = 20.0` was too conservative. Turn angle formula yielded 10-20 degrees — insufficient for tight obstacles.

**Fix:** Changed to `45.0` in both code default and YAML. Turn range is now 22.5-45 degrees based on urgency.

**Effect:** Boat can turn more aggressively when urgency is high.

---

### Fix 7: Smart escape uses clearance data

**File:** `control/control/buran_controller.py`

**Problem:** `execute_smart_escape()` always turned LEFT at fixed 450N, ignoring which side had more clearance.

**Fix:** Now turns toward the side with more room (`left_clear` vs `right_clear`). Logs direction and all clearance values.

**Effect:** Escape maneuvers are more effective — turns toward open space instead of potentially into obstacles.

---

### Fix 8: Sync code defaults to YAML

**File:** `control/control/buran_controller.py`

**Problem:** Two code defaults didn't match YAML (YAML wins at runtime, but inconsistency is confusing):
| Parameter | Old Code Default | YAML |
|-----------|-----------------|------|
| reverse_timeout | 3.0 | 4.0 |
| avoid_diff_gain | 25.0 | 18.0 |

**Fix:** Updated code defaults to match YAML values.

**Effect:** Code and YAML are consistent. No runtime behavior change (YAML already overrode).

---

### Fix 9: Remove dead code

**File:** `control/control/buran_controller.py`

**Removed:**
- `pub_detour_request` publisher (line 332) — declared but never used to publish
- `calculate_drift_compensation()` method — defined but never called in the control loop

**Effect:** Cleaner codebase. No functional change.

---

### Fix 10: Remove stray import

**File:** `plan/plan/sputnik_planner.py`

**Problem:** `import math` inside `insert_side_detour()` was redundant (top-level import at line 30).

**Fix:** Removed during function rewrite (Fix 2/3).

**Effect:** No functional change.

---

### Fix 11: Update health check

**File:** `one_click_launch_all/health_check_vostok1.sh`

**Fix:** Added `max_avoidance_turn_deg = 45.0` parameter check for BURAN.

**Effect:** Health check now validates the new avoidance turn angle. Total checks: 45 (was 44).

---

### Other changes today (before obstacle avoidance work)

- Added module naming legend (OKO/SPUTNIK/BURAN) to 6 key files for readability
- Added file/command reference section to `launch_vostok1_complete.sh` header
- Unified usage syntax to `bash` style in both shell scripts
- Fixed inaccurate description in `health_check_vostok1.sh` header

## Testing

Ran full simulation via `bash launch_vostok1_complete.sh` after `colcon build --packages-select plan control`.

**Health check:** 45/45 PASS, 0 FAIL, 0 WARN

**Simulation results:**
- Mission completed: 18 waypoints in 4.9 minutes
- Obstacle encountered at ~5.6m distance (urgency peaked at 97%)
- Detour timeout fired once (15.1s) — working as expected
- A* detour inserted twice (1 segment each) — bounded, not explosive
- Boat navigated through obstacle using GAP navigation and resumed cleanly
- No `AttributeError` from replan fix
- No "Detour cap reached" — didn't need to hit cap (good)
- **Total waypoints stayed at 18 — no explosion**

## Deferred

- **VFH steering** (`use_vfh_bias`): remains disabled by default. Test separately after core fixes are validated.
- **Obstacle avoidance tuning**: further parameter tuning (detour distance, cooldown, cap value) based on more simulation runs with different obstacle configurations.
