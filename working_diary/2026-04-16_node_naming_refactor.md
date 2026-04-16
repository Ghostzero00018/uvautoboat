# 2026-04-16 — Node Naming Refactor (One-Shot Rename)

## Summary

Renamed all U.S.S.R. space-program code-names (OKO, SPUTNIK, BURAN, Vostok1) to
functional `snake_case` names following ROS 2 community conventions. One-shot
atomic rename across 26 active files (~1,100+ branded references). Also documented
the web communication stack (rosbridge_suite vs ros2-web-bridge) and fixed a
pre-existing `waypoint_visualizer` node name mismatch.

---

## Pre-Rename Work

### Web communication stack documentation

Added rosbridge_suite / web_video_server / roslibjs documentation to 5 files,
noting that ros2-web-bridge (archived Nov 2025) is NOT used by this project:

- `wiki/System_Overview.md` — new "Web Communication Stack" subsection with
  component table (package, port, role)
- `wiki/Design_Rationale.md` — blockquote note under "Why ROSBridge" section
- `wiki/Installation_Guide.md` — clarified rosbridge-suite prerequisite
- `USER_MANUAL.md` — expanded Web Dashboard Prerequisites
- `web_dashboard/vostok1/README_vostok1_dashboard.md` — expanded Prerequisites

### Pre-rename backup

Created `uvautoboat_backup_2026-04-16_pre_rename.zip` (3.8 MB, .git/ excluded).

---

## Node Naming Refactor

### Complete naming table

| Old | New |
|:----|:----|
| `oko_perception.py` / `OkoPerception` / `oko_perception_node` | `lidar_perception.py` / `LidarPerception` / `lidar_perception_node` |
| `sputnik_planner.py` / `SputnikPlanner` / `sputnik_planner_node` | `waypoint_planner.py` / `WaypointPlanner` / `waypoint_planner_node` |
| `buran_controller.py` / `BuranController` / `buran_controller_node` | `heading_controller.py` / `HeadingController` / `heading_controller_node` |
| `vostok1_cli.py` / `vostok1_cli` (node) | `autoboat_cli.py` / `autoboat_cli` |
| `Vostok1` (system name) | `AutoBoat` |
| `vostok1.launch.yaml` | `autoboat.launch.yaml` |
| `launch_vostok1_complete.sh` | `launch_autoboat_complete.sh` |
| `health_check_vostok1.sh` | `health_check_autoboat.sh` |
| `web_dashboard/vostok1/` | `web_dashboard/autoboat/` |
| `/sputnik/config`, `/sputnik/set_config`, `/sputnik/mission_command` | `/planning/config`, `/planning/set_config`, `/planning/mission_command` |
| `oko_min_safe_distance` / `oko_critical_distance` | `perception_min_safe_distance` / `perception_critical_distance` |
| HTML IDs `oko-*` / `buran-*` | `perception-*` / `controller-*` |
| JS `OKO_DEFAULTS` / `BURAN_DEFAULTS` | `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` |

### Execution (4 phases, inside-out order)

#### Phase 1 — Python core (4 file renames + 6 content edits)

- `git mv` 4 Python files: oko_perception → lidar_perception, sputnik_planner →
  waypoint_planner, buran_controller → heading_controller, vostok1_cli → autoboat_cli
- Updated class names, `Node.__init__()` strings, topic strings, param names,
  entry points in both `setup.py` files, SCRIPT_PATH in `health_check_service.py`
- Verified: zero old names remain in active Python (only in `legacy/`)

#### Phase 2 — Launch YAML + shell scripts (3 file renames + 3 content edits)

- `git mv` launch file + 2 shell scripts
- Updated exec names, node names, pkill targets, param names, comments/labels
- Verified: YAML valid, shell syntax clean (`bash -n`), zero old names

#### Phase 3 — Dashboard (1 dir rename + 1 file rename + 3 content edits)

- `git mv` `web_dashboard/vostok1/` → `web_dashboard/autoboat/`
- `index.html`: renamed 68 HTML IDs (`oko-*` → `perception-*`, `buran-*` → `controller-*`)
- `app.js`: renamed ~290 references (functions, constants, topics, getElementById
  calls, preset keys, rosout filters, export filenames, log strings)
- Cross-check: every `getElementById()` target in JS has a matching HTML `id=` —
  zero orphans (only `toast-container` and `follow-boat-toggle` are dynamically created)

#### Phase 4 — Documentation (15 markdown files)

- Global find-replace across README.md, USER_MANUAL.md, Board.md, 12 wiki pages
- `wiki/Node_Naming_Refactor_Plan.md` rewritten from future-tense plan to
  completed record
- `wiki/Glossary.md` old names retained under "Legacy Module Code-Names (pre-v3.0)"

### Additional fix: waypoint_visualizer node name mismatch

- **Pre-existing bug** (not caused by rename): `waypoint_visualizer.py` registered as
  `'waypoint_visualizer'` but launch YAML declared `name: waypoint_visualizer_node`
- **Fixed:** Python now matches YAML: `super().__init__('waypoint_visualizer_node')`
- Also updated stale "Sputnik planner" references in docstring/comments

### Approach decision: one-shot vs two-release deprecation

The wiki plan originally proposed a v3.0/v3.1 deprecation cycle with shim files,
dual-publish topics, and parameter aliases. This was replaced with a one-shot
atomic rename because:

- No external consumers (2-person team, no downstream packages)
- Deprecation machinery would have cost ~50% of the effort for zero benefit
- All changes committed together — system never in a partially-renamed state

---

## Verification

- **Clean build:** `colcon build --merge-install` — 7/7 packages, zero errors
- **Health check:** 46/46 PASS, 0 FAIL, 0 WARN (in ACTIVE/DRIVING state)
- **Exhaustive grep:** zero old names in active code (only in `legacy/`,
  `working_diary/`, and the refactor plan's naming table)
- **getElementById cross-check:** zero orphaned JS→HTML ID references
- **Dashboard:** connected, all panels functional, camera streaming
- **Gazebo/rosbridge/web_video_server/RViz:** all benign warnings only (same as pre-rename)

---

## Files Modified (26 active files)

### Python (4 renamed + 6 edited)

- `plan/plan/oko_perception.py` → `plan/plan/lidar_perception.py`
- `plan/plan/sputnik_planner.py` → `plan/plan/waypoint_planner.py`
- `plan/plan/vostok1_cli.py` → `plan/plan/autoboat_cli.py`
- `control/control/buran_controller.py` → `control/control/heading_controller.py`
- `plan/setup.py` — entry points updated
- `control/setup.py` — entry point updated
- `plan/plan/health_check_service.py` — SCRIPT_PATH updated
- `plan/plan/waypoint_visualizer.py` — node name + docstring fix

### Launch + scripts (3 renamed + 3 edited)

- `launch/vostok1.launch.yaml` → `launch/autoboat.launch.yaml`
- `one_click_launch_all/launch_vostok1_complete.sh` → `launch_autoboat_complete.sh`
- `one_click_launch_all/health_check_vostok1.sh` → `health_check_autoboat.sh`
- `one_click_launch_all/patch_vrx.sh` — comment reference updated

### Dashboard (1 dir + 1 file renamed + 3 edited)

- `web_dashboard/vostok1/` → `web_dashboard/autoboat/`
- `README_vostok1_dashboard.md` → `README_autoboat_dashboard.md`
- `web_dashboard/autoboat/index.html` — 68 HTML IDs + text content
- `web_dashboard/autoboat/app.js` — ~290 references

### Documentation (15 files)

- `README.md`, `USER_MANUAL.md`, `Board.md`
- `wiki/System_Overview.md`, `wiki/Design_Rationale.md`, `wiki/Glossary.md`,
  `wiki/3D_LIDAR_Processing.md`, `wiki/SASS.md`, `wiki/Common_Issues.md`,
  `wiki/Quick_Start.md`, `wiki/Home.md`, `wiki/README_WIKI.md`,
  `wiki/UPLOAD_INSTRUCTIONS.md`, `wiki/Installation_Guide.md`,
  `wiki/Node_Naming_Refactor_Plan.md`

---

## Dashboard Security and UX Improvements (same day)

### Security fixes

- **XSS protection:** rosout log messages now use `textContent` instead of `innerHTML`
  to prevent script injection from malformed ROS log messages (`app.js`)
- **SRI hashes:** added SHA-384 integrity + `crossorigin="anonymous"` to CDN scripts
  (roslib.js, leaflet.js, leaflet.css) in `index.html`
- **Server-side parameter range validation:** added `_validate_range()` / `param_ranges`
  to all 3 Python nodes — out-of-range values rejected with warning log
  (`lidar_perception.py`, `waypoint_planner.py`, `heading_controller.py`)
- **Quoted `$WORLD` variable** in `launch_autoboat_complete.sh` to prevent command injection
- **Dashboard_Security wiki page** created — full security posture, 11 vulnerabilities
  ranked, risk-by-environment, 3 tiers of mitigations, usage guidelines

### Dashboard parameter validation UX

- **`readInput()` reject-not-clamp:** invalid values now abort the entire Apply operation
  instead of silently clamping. Orange warning toast shows the valid range. Nothing sent to ROS.
- **Validation error counter:** `resetValidation()` / `hasValidationErrors()` pattern
  used by all 4 entry points (sendConfig, applyPerceptionParameters,
  applyControllerParameters, generateWaypoints)
- **sendConfig returns true/false:** the unconditional "Configuration Applied" alert
  was removed — green toast only shown on actual success
- **All 3 Apply functions now use `readInput()`:** Perception and Controller panels
  previously used raw `parseFloat()`/`parseInt()`, bypassing validation entirely
- **Red toast for server-side rejection:** `/rosout` messages starting with "Rejected"
  trigger a red error toast (catches direct ROS command bypasses)
- **Auto-appended `[Range: X-Y]`** to all parameter hover tooltips at page load

### HTML min/max bounds sync

Added or fixed `min`/`max` attributes on all dashboard number inputs to match
the Python server-side validation ranges:

- 16 Perception inputs — all were missing bounds
- 8 Controller inputs — were missing bounds
- 5 Controller inputs — had mismatched bounds (e.g., `avoid_diff_gain` HTML said
  10-100 but Python said 0-10; Python range was wrong, fixed to 0-100)
- 3 A* inputs — had mismatched bounds (resolution, safety margin, max expansions)

### A* panel fixes

- **Value-revert bug fixed:** `/planning/config` sync callback was unconditionally
  overwriting A* input values every 1Hz, ignoring user edits. Added `dirtyInputs`
  check (same pattern used by all other inputs)
- **`generateWaypoints()` now uses `readInput()`** for A* params instead of raw
  `parseFloat()`/`parseInt()`
- **Range mismatches fixed:** `astar_resolution` 0.5-20 (was 0.5-10),
  `astar_safety_margin` 1-50 (was 1-30), `astar_max_expansions` 100-100000 (was 1000-50000)
- **Added Apply A* and Reset buttons** with full validation, matching the style
  of Perception and Controller panels (`apply-btn` / `reset-btn` classes)
- **Added tooltips** to all 3 A* inputs with descriptions and `[Range: X-Y]`
  auto-enrichment (via `param-row` class + `info-tooltip` spans)

### Copy-to-clipboard buttons

Added "Copy" button next to "Export JSON" on Health Check, System Logs, and
ROS2 Terminal panels. One click copies panel text to clipboard with green
toast confirmation. Includes fallback for older browsers. Initial selectors
were wrong (`.terminal-output` doesn't exist) — fixed to use actual element
IDs (`#health-check-output`, `#logs`, `#terminal-output`).

### Unconditional "Configuration Applied" alert removed

The main Apply Config button had a `setTimeout(() => alert(...))` that fired
regardless of whether `sendConfig()` succeeded or was aborted by validation.
Fixed: `sendConfig()` now returns `true`/`false`, alert replaced with toast
that only shows on success.

### Other fixes

- Removed residual `(OKO)` / `(SPUTNIK)` / `(BURAN)` parenthetical references
  from README.md, USER_MANUAL.md, wiki/System_Overview.md, wiki/Design_Rationale.md,
  wiki/3D_LIDAR_Processing.md
- Added "Legacy Code-Names" note to README architecture table linking to Glossary
- Replaced "Russian" with "U.S.S.R." in space-program references (3 active files)
- Fixed `avoid_diff_gain` Python range from (0, 10) to (0, 100) — was rejecting
  the YAML default of 18.0
- Updated package.xml descriptions (stale OKO/BURAN references)
- Unified maintainer/author name to `Ghostzero00018` across both packages
- Added "Dashboard stale after update" troubleshooting tip to README + Common_Issues
- Expanded Common_Issues "Dashboard Shows Old Data" with full post-update workflow

---

## Not Modified (by design)

- `legacy/` — historical deprecated code
- `working_diary/` — historical development logs
- `style_merged.css` — zero branded selectors (confirmed pre-rename)
