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

---

## 4. LiDAR Smoke Detection — Full Removal

### Context

Smoke detection was originally shipped on 14/12/2025 for VRX worlds with active smoke sources (`sydney_regatta_smoke.sdf`, `sydney_regatta_smoke_wildlife.sdf`, `sydney_regatta_randomsmoke.sdf`). During the 16/04/2026 node rename those worlds were moved to `legacy/test_worlds/`, leaving the feature alive in active code but no longer exercised by the default demo (`sydney_regatta_DEFAULT` has no smoke sources). CLAUDE.md §5 already flagged it as *"still in code but irrelevant to current demo"*. Today: remove it entirely.

### Scope

Two distinct but related features were removed together:

- **LiDAR smoke detection** in `plan/plan/lidar_perception.py` — active publisher on `/perception/smoke_detected`, 8 parameters, three-layer spatial classification (height band → point-count threshold → H/V spread ratio), plus horizontal/vertical spread analysis that published JSON per scan.
- **SDF pollutant scanning** in `plan/plan/waypoint_planner.py` — parsed SDF world files for smoke-generator model positions, published on `/perception/pollutant_sources`, included hazard-proximity checks in the planning loop. Disabled by default (`pollutant_scan_enabled: false`) and only ever relevant to the smoke worlds.

### Subtle behaviour change to expect

Previously in `lidar_callback()` with `smoke_filter_enabled=True`, the gate order was:

1. smoke gate (reject points in smoke band)
2. solid gate (keep only points in solid band)
3. generic height filter (keep points in `min_height`–`max_height`)

After removal, only step 3 runs. With the YAML defaults `min_height=-1.2, max_height=1.5`, points with `z ∈ (0.5, 1.5] m` — previously rejected as *"neither smoke nor solid"* — now pass through as obstacles. Expected effect: taller navigation-relevant features (buoy top markers, signal masts, standing wildlife) are **more** likely to be detected, not fewer. Verified in a full mission run: 10/10 waypoints completed cleanly in `sydney_regatta_DEFAULT`, no regression.

### Files changed

| File | Delta |
|:--|:--|
| `plan/plan/lidar_perception.py` | 8 params, `PARAM_RANGES` entries, classification + analysis blocks, smoke publisher (~138 LOC removed) |
| `plan/plan/waypoint_planner.py` | 2 pollutant params, state attrs, publisher, SDF-scanning methods, status-JSON field (~120 LOC removed) |
| `launch/autoboat.launch.yaml` | 6 smoke param declarations removed |
| `web_dashboard/autoboat/index.html` | Smoke status panel (32 lines) + *Smoke & Object Classification* subsection (~43 lines); one tooltip reworded |
| `web_dashboard/autoboat/app.js` | `smokeDetectionTopic` subscription + `updateSmokeDetection()` function; smoke entries in `PARAM_TO_INPUT_IDS`, `PERCEPTION_DEFAULTS`, `allConfigInputs`, `updatePerceptionParamsFromROS()`, `applyPerceptionParameters()`; 4 TUNING_PRESETS trimmed; `updateWorldBanner(hasSmoke)` simplified |
| `README.md`, `USER_MANUAL.md`, `Board.md`, `wiki/System_Overview.md`, `web_dashboard/autoboat/README_autoboat_dashboard.md` | Dedicated section (82 lines in USER_MANUAL) + inline mentions removed |
| `.ai-context/CLAUDE.md` | §5 *"smoke filter code exists but is irrelevant"* bullet replaced with §10 pitfall note documenting the 17/04/2026 removal; topic table example updated |

Legacy assets untouched per CLAUDE.md §1.3: `legacy/test_worlds/sydney_regatta_smoke*.sdf`, `legacy/environment_plugins/dead_zone_plugin.cc`, and every `legacy/` reference describing smoke-world SDFs. The 14/12/2025 Board.md milestone row was also preserved as historical fact.

### Verification

- `colcon build --packages-select plan control --merge-install` → 2/2 packages, 0 errors.
- AST parse check on all three node files → clean.
- `node --check web_dashboard/autoboat/app.js` → clean.
- Grep sweep `--exclude-dir=legacy --exclude-dir=working_diary` → only intentional residual mentions remain (launch YAML comment noting `sydney_regatta_DEFAULT` has no smoke sources, launcher-script breadcrumb pointing to legacy, CLAUDE.md removal note, and the "smoke test" software-testing idiom in §19).
- Full mission run in `sydney_regatta_DEFAULT` with Buoy Field preset applied: 10/10 waypoints, no regressions.

---

## 5. FINISHED-state Waypoint Counter Clamp

### Bug

After a successful mission the dashboard status panel showed:

```text
State: FINISHED
Waypoint: 14/13
Distance: 0.0m
```

Root cause in `plan/plan/waypoint_planner.py` (mission-status publisher): `self.current_wp_index` is incremented one past the last valid index when the final waypoint is reached, then the state transitions to `FINISHED`. The published field was `self.current_wp_index + 1`, so for a 13-waypoint mission with valid indices `0..12`, the post-transition value becomes `13 + 1 = 14` against `total=13`. The `progress_percent` calculation (`100 * current_wp_index / total`) had the same off-by-one and could report `107.7 %`.

### Fix

One-line clamp on both fields at the publish site:

```python
'current_waypoint': min(self.current_wp_index + 1, len(self.waypoints)),
'total_waypoints': len(self.waypoints),
'progress_percent': round(100 * min(self.current_wp_index, len(self.waypoints)) / max(1, len(self.waypoints)), 1),
```

Display-only fix in `app.js` was considered but rejected — clamping at the source also covers the CLI (`autoboat_cli`) and any other downstream consumer of `/planning/mission_status`.

### Verification

Re-ran a mission to completion. After FINISHED the panel now reads `Waypoint: 10/10` (for the 10-WP test run) with progress bar exactly at 100 %. Mid-mission counter still increments normally (`7/10` on WP index 6 — no off-by-one regression).

---

## 6. Dashboard Split-Screen Layout Hardening

### Trigger

During end-of-day validation the user ran Gazebo and the dashboard side-by-side on a single monitor. At that ~900-1000 px dashboard width, the Health Check panel header clipped the **Copy** button (added at runtime after Run/Clear/Auto-scroll/Export) outside the right edge of the panel — the user could see the Export button but had to resize the window to get to Copy.

### Audit findings

An Explore-agent sweep of `style_merged.css` + `index.html` surfaced 7 flex rows with no `flex-wrap` directive plus a responsive-breakpoint gap (only `@media (max-width: 1200px)` and `(max-width: 768px)` existed, leaving 769-1199 px uncovered — exactly the split-screen range):

| Severity | Rule | Issue |
|:--|:--|:--|
| Critical | `.terminal-controls` | 6 children in a non-wrapping flex row → Copy/Export clipped on 3 panels (Health Check, Logs, Terminal) |
| Critical | `.terminal-header` | Bilingual title + controls with `justify-content: space-between`, no wrap |
| Critical | `.mission-status-bar` | State + GPS badges in non-wrapping row |
| Moderate | `.config-buttons` | Column-stack only at ≤768 px; squeezes at 900 px |
| Moderate | `.header-left` / `.header-right` | World banner (520 px max) ate >50 % of a 900 px viewport |
| Moderate | Breakpoint gap | No rule between 768 px and 1200 px |
| Low | `.world-banner` | `overflow:hidden; white-space:nowrap` without `text-overflow: ellipsis` (silent clipping) |

### Fix (single CSS file, +24/-2 lines)

- Added `flex-wrap: wrap` to `.terminal-controls`, `.terminal-header`, `.mission-status-bar`, `.config-buttons`, `.header-left`, `.header-right`.
- Reduced `.world-banner` `max-width` from `520px` → `360px`; added `text-overflow: ellipsis` so long world names truncate visibly instead of invisibly clipping.
- New `@media (max-width: 1024px)` block covering the split-screen gap: drops `.tuning-panel` from `grid-column: span 2` to `span 1`, shrinks `.world-banner` further to `280px`, scales `.terminal-header h2` to 16 px.

### Verification

Hard-refreshed the dashboard at full width (≥1200 px) — no visual regression, Copy/Export still right-aligned in headers. Dragged window edge to ~900 px — Copy button now wraps to a second row instead of clipping; world banner shows "…" for long names; tuning panel reflows to a single column cleanly at 1024 px; below 768 px the original column-stack behaviour still engages. No console warnings.

---

## Afternoon commit — single cohesive bundle

Reasoning for a single commit rather than splitting into three:

- The smoke removal is the large change (−624 net LOC across 10 files) and is self-contained.
- The waypoint counter clamp is a one-liner in a file that smoke removal already touches (`waypoint_planner.py`), so splitting would create an artificial second commit on the same file.
- The CSS hardening is UI-only and independent, but thematically aligned with the "polish and prep for hardware" phase (CLAUDE.md §15) and was surfaced by a user observation during the same validation run.

All three were produced, reviewed, and tested in one continuous session. `git revert <commit>` cleanly restores all three together if needed.

Commit message subject: `refactor: Remove LiDAR smoke detection; fix FINISHED counter and split-screen layout`

### Files modified (afternoon additions)

| Category | File | Change |
|:--|:--|:--|
| Python | `plan/plan/lidar_perception.py` | Smoke removal (~138 LOC) |
| Python | `plan/plan/waypoint_planner.py` | Pollutant scanning removal (~120 LOC) + FINISHED counter clamp |
| Launch | `launch/autoboat.launch.yaml` | 6 smoke param declarations removed |
| Dashboard | `web_dashboard/autoboat/index.html` | Smoke status panel + tuning subsection removed |
| Dashboard | `web_dashboard/autoboat/app.js` | Smoke subscription, function, presets, mappings removed |
| Dashboard | `web_dashboard/autoboat/style_merged.css` | 7 `flex-wrap` additions + new 1024 px media block |
| Docs | `README.md`, `USER_MANUAL.md`, `Board.md`, `wiki/System_Overview.md`, `web_dashboard/autoboat/README_autoboat_dashboard.md` | Smoke section + inline refs removed |
| Meta | `.ai-context/CLAUDE.md` (Gist) | §5 stale bullet removed; §10 removal note added; §9 proactive-test-pipeline rule, §10 machine-specific work patterns, §12 revert-test-changes rule added earlier in the day |

---

## Side-topics (no repo impact)

- **SSH-over-443 fallback on blocked networks.** While attempting to push the morning's work from a hotspot ("DESKTOP-MNLKGA2 9662", a laptop tether), `git push` timed out while `git pull` appeared to work from cache. Root cause: port 22 blocked by the hotspot upstream. Fix: added `ssh.github.com:443` alias to `~/.ssh/config` for both `github.com` and `gist.github.com`. Verified with `ssh -T git@github.com`. Saved as auto-memory (`reference_ssh_over_443.md`) so future sessions on either machine can diagnose the same symptom without re-deriving the fix.
- **Stale auto-memory cleanup.** Removed `project_param_ranges_single_source.md` — the entry described a "planned" feature that was already shipped in commit `911a8f8` this morning.
