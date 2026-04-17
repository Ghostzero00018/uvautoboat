# 2026-04-17 — Parameter Range Sync + Dashboard JSON Parse Hardening

## Summary

Two dashboard-related commits today:

1. **Single source of truth for parameter validation ranges** — Python nodes now publish their `PARAM_RANGES` dicts on dedicated topics, and the dashboard subscribes to auto-sync HTML `min`/`max` attributes at runtime. Eliminates the manual 4-place sync burden (launch YAML, HTML, app.js, Python) that had already caused real bugs like the `avoid_diff_gain` range mismatch.
2. **Wrap `JSON.parse(message.data)` in try/catch** across 8 dashboard subscribers to tolerate malformed messages (mostly caused by Python's `json.dumps` emitting non-spec `NaN`/`Infinity` for uninitialized Kalman filter values before the first GPS fix).

---

## 1. Parameter Range Single Source of Truth

### Problem

Parameter validation ranges were duplicated in 4 places that had to be kept in sync manually:

1. `launch/autoboat.launch.yaml` (runtime source of truth for values)
2. `web_dashboard/autoboat/index.html` (HTML `min`/`max` attributes)
3. `web_dashboard/autoboat/app.js` (readInput fallbacks, defaults dicts)
4. Python node (`_validate_range()` calls / `param_ranges` dict)

Mismatches had caused real bugs:

- `avoid_diff_gain`: HTML said 10–100, Python said 0–10, YAML default was 18.0 → neither side accepted the default.
- `cfg-ki`: HTML 0–200 vs Python 0–500 drift (discovered during the audit).
- `cfg-astar-max`: HTML 1000–50000 vs Python 100–100000 drift.

### Solution — publish-and-apply pattern

- **Each Python node owns a class-level `PARAM_RANGES` dict** (single source of truth).
- **New topics**: `/perception/param_ranges`, `/planning/param_ranges`, `/control/param_ranges` (`std_msgs/String` JSON, 5-second republish timer + initial publish on startup).
- **Dashboard subscribes** and dynamically sets `input.min` / `input.max` at runtime via a new `applyRangesToDashboard()` function + a module-scope `PARAM_TO_INPUT_IDS` lookup table.
- **HTML values kept as graceful fallback** — when a node is offline the dashboard still uses the hardcoded values; no error, no crash.

### Python changes

| File | Change |
|---|---|
| `plan/plan/lidar_perception.py` | Promoted the existing inline `param_ranges` dict (16 params) to class-level `PARAM_RANGES` constant. Added publisher + 5 s timer + `_publish_param_ranges()` method. |
| `plan/plan/waypoint_planner.py` | Added new class-level `PARAM_RANGES` dict (7 params). Added `_validate(name, value)` helper that looks up bounds from the dict. **Refactored 7 inline `_validate_range(name, v, lo, hi)` calls to `_validate(name, v)`** — bounds now live only in `PARAM_RANGES`. |
| `control/control/heading_controller.py` | Same refactor pattern as waypoint_planner but larger: `PARAM_RANGES` has 20 params, ~20 inline `_validate_range` calls refactored. Old `_validate_range` method removed; `PARAM_RANGES` references module constant `MAX_THRUST` for speed bounds. |

### Dashboard (app.js) changes

- **New `PARAM_TO_INPUT_IDS` module-scope lookup table** — maps each param name to the HTML input ID(s) it controls. Some params appear in multiple inputs (e.g. `lanes` is in both `cfg-lanes` and `wp-lanes`), so values are lists.
- **New `applyRangesToDashboard(rangesJson)`** — iterates received ranges, finds matching inputs, sets `input.min` / `input.max`, calls `enrichTooltipsWithRanges()` to refresh `[Range: X–Y]` hover text.
- **Three new subscribers** for the new `param_ranges` topics (wrapped in try/catch).
- **Fixed `enrichTooltipsWithRanges()`** — it now strips and re-appends the `[Range: ...]` suffix so tooltips reflect the latest bounds from the node (previously it only appended if no `[Range:]` was present, so subsequent updates were ignored).

### End-to-end verification

- `colcon build --merge-install` → 7/7 packages, 0 errors.
- `ros2 topic list | grep param_ranges` → all 3 topics appear.
- `ros2 topic echo /perception/param_ranges --once` → valid JSON with all perception params.
- DevTools inspection of 6 sample inputs (`cfg-ki`, `cfg-kp`, `cfg-kd`, `controller-avoid-gain`, `perception-min-range`, `cfg-astar-max`) all returned the **Python** values, not the old HTML defaults.
- **Offline fallback verified**: temporarily set `controller-avoid-gain` HTML to `min="999" max="9999"` (obviously wrong). With `heading_controller` running, DevTools showed `min=0 max=100` (Python wins). After `pkill -f heading_controller` and a hard-refresh, it reverted to `min=999 max=9999` (HTML fallback kicked in, no errors). Reverted the test change back to `min=0 max=100` before commit.

Commit: `911a8f8`

---

## 2. Dashboard JSON.parse Hardening

### Problem

While running the `heading_controller` standalone (via `ros2 run control heading_controller` for testing, instead of the full launcher), the browser console showed:

```text
Uncaught SyntaxError: JSON.parse: unexpected character at line 1 column 85
    subscribeToTopics ... app.js:421
```

Root cause: Python's `json.dumps()` emits `NaN` and `Infinity` by default for invalid float values — these tokens are **not valid JSON** per spec, so browsers' `JSON.parse` rejects them. The transient trigger was `self.drift_kalman.last_kalman_gain` being NaN right after node startup, before the first GPS fix had arrived to seed the Kalman filter.

8 dashboard subscribers called `JSON.parse(message.data)` directly without any exception handling. A single malformed message caused the exception to bubble up through the ROSLIB event loop and flood the console.

### Fix

Wrapped all 8 raw `JSON.parse(message.data)` calls in try/catch, using the same pattern as the existing `/rosout` subscriber and the newly added `/param_ranges` subscribers. On a bad message, the subscriber logs a `console.warn` only when `DEBUG_MODE` is on and silently returns; no exception escapes into the event loop.

### Affected topics

| Subscribed topic | Purpose |
|---|---|
| `/planning/mission_status` | Mission state + waypoint progress |
| `/control/anti_stuck_status` | Anti-stuck + Kalman drift status |
| `/planning/current_target` | Target waypoint for display |
| `/planning/waypoints` | Full waypoint list for map |
| `/perception/obstacle_info` | Front/Left/Right clearance, clusters |
| `/control/status` | Controller state (stop_override etc.) |
| `/perception/smoke_detected` | LiDAR smoke detection |
| `/planning/config` | Runtime config sync |

### Verification

- Hard-refreshed dashboard, forced a bad message via DevTools:

  ```js
  const testPub = new ROSLIB.Topic({ros, name: '/control/anti_stuck_status', messageType: 'std_msgs/String'});
  testPub.publish(new ROSLIB.Message({data: '{"front_clear": NaN}'}));
  ```

  Before the fix: red `SyntaxError` in console. After the fix: publish returned `undefined`, no error visible. Valid messages still flow normally (verified by checking `document.getElementById('controller-avoid-gain').min` still returns `0` — param_ranges subscription still working).

- No behavioural change when messages are valid. This is purely defensive.

Commit: `01b1424`

---

## Outstanding follow-ups (not in today's commits)

- **Python sanitisation of NaN/Infinity in `json.dumps` output** — the dashboard is now tolerant, but the ideal fix is at the source: each Python publisher should convert NaN/Infinity to `null` or a sentinel before `json.dumps()`. Deferred as a separate hygiene pass across all 3 nodes.
- **Anti-stuck default mismatch when running `ros2 run control heading_controller` standalone** — Python defaults are `stuck_timeout=3.0, stuck_threshold=0.5`, YAML overrides to `12.0 / 1.0`. Running without the launcher bypasses the YAML. Workaround: always use `launch_autoboat_complete.sh` or `ros2 launch autoboat.launch.yaml`. Python defaults could be tightened to match YAML so standalone runs behave the same as launched ones.

---

## Files modified today

### Python (3 files)

- `plan/plan/lidar_perception.py`
- `plan/plan/waypoint_planner.py`
- `control/control/heading_controller.py`

### Dashboard (1 file)

- `web_dashboard/autoboat/app.js` (both commits)

No changes to: launch YAML, `index.html` (fallbacks preserved), setup.py, package.xml, wiki docs.
