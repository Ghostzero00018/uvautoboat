# 2026-04-17 — Parameter Range Sync, JSON Parse Hardening, and Dashboard UX Polish

## Summary

Three dashboard-related commits today:

1. **Single source of truth for parameter validation ranges** — Python nodes now publish their `PARAM_RANGES` dicts on dedicated topics, and the dashboard subscribes to auto-sync HTML `min`/`max` attributes at runtime. Eliminates the manual 4-place sync burden (launch YAML, HTML, app.js, Python) that had already caused real bugs like the `avoid_diff_gain` range mismatch.
2. **Wrap `JSON.parse(message.data)` in try/catch** across 8 dashboard subscribers to tolerate malformed messages (mostly caused by Python's `json.dumps` emitting non-spec `NaN`/`Infinity` for uninitialized Kalman filter values before the first GPS fix).
3. **Dashboard UX polish pass** — 31 new hover tooltips on Perception + Controller inputs, restyled Navigation Mode radios, clearer Apply A* toast, `confirm()` dialog for preset buttons, and adaptive-spacing + debounced map grid with a toggle button to fix lag when zooming out on weak GPUs.

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

## 3. Dashboard UX Polish Pass

Several small UX issues surfaced during end-of-day testing. Bundled into one UX-focused commit.

### Hover tooltips on Perception + Controller inputs

Before: only Main Config and A* Advanced panels had `ℹ️` hover tooltips. Perception Tuning and Heading Controller Parameters panels had inline `.param-hint` labels but no detailed on-hover explanation. Added 31 new `info-tooltip` spans (17 Perception + 14 Controller), bilingual EN | FR, matching the existing pattern. Auto-appended `[Range: X–Y]` suffix is handled by the existing `enrichTooltipsWithRanges()` at page load.

### Navigation Mode radio restyle

Before: 3 nav-mode radios (Simple Lawnmower / Runtime A* / Hybrid Mode) used raw `<input type="radio">` with inline styles — visually inconsistent with the rest of the dashboard. Rewrote as `.nav-mode-option` cards with `var(--accent)` bordered highlight on selection, hover effect, and 6 new CSS rules in `style_merged.css`.

### Apply A* toast message clarity

Before: clicking Apply A* showed `"✅ A* parameters applied"` — the user couldn't tell the 3 radio modes (`astar_enabled`, `astar_hybrid_mode`, `hazard_enabled`) were included alongside the 3 numeric params. Updated to spell out both: `✅ A* applied: mode="Runtime A*" + 3 params (resolution, safety_margin, max_expansions)`. Same text goes to System Logs panel too.

### Preset buttons now ask before applying

Before: clicking any of the 4 preset buttons (Universal / Buoy Field / Pier / Open Water) immediately overwrote Perception + Controller params with no confirmation. Added a `confirm()` dialog showing how many params will be overwritten (e.g. "Apply 'Buoy Field' preset? This will overwrite: 17 Perception + 14 Controller parameters."). Cancel → `Preset X cancelled by user` in System Logs, nothing sent to ROS.

### Map grid performance on weak GPUs

User reported the trajectory map froze when zooming out, especially on the Linux laptop's integrated graphics. Root cause: grid used fixed 50 m spacing regardless of zoom, so line count grew quadratically with viewport area (400 lines at 10 km view, 4000 at 100 km view). Redraw also fired on every `moveend`/`zoomend` event without debouncing.

Four fixes combined:

1. **Adaptive spacing** — picks grid size from `[10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000]` m based on meters-per-pixel. Target ~60 px per cell. Grid now always shows ~20–40 lines regardless of zoom level.
2. **Safety cap** — skips drawing and logs a warning if somehow the line count would exceed 200.
3. **Debounce** — new `scheduleGridRedraw()` waits 150 ms of idle before redrawing, so rapid zoom gestures don't cascade redraws.
4. **Toggle button** — Leaflet `L.Control` `⊞` button top-right of the map. Click to disable the grid entirely; click again to re-enable. Useful for max framerate during intensive testing.

Verified: zooming from default view to ~100 km whole-region view is now smooth; grid stays visually dense but performant. Toggle button dims when off.

Commit: single commit covering all 5 UX fixes (tooltips + nav-mode restyle + A* toast + preset confirmation + grid performance).

---

## Files modified today

### Python (3 files)

- `plan/plan/lidar_perception.py`
- `plan/plan/waypoint_planner.py`
- `control/control/heading_controller.py`

### Dashboard (3 files)

- `web_dashboard/autoboat/app.js` — all three commits (param_ranges, JSON.parse hardening, UX polish)
- `web_dashboard/autoboat/index.html` — UX polish only (tooltips + nav-mode restyle)
- `web_dashboard/autoboat/style_merged.css` — UX polish only (6 new rules for `.nav-mode-*` classes)

No changes to: launch YAML, setup.py, package.xml, wiki docs.
