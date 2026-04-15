# Node Naming Refactor Plan

Rename OKO / SPUTNIK / BURAN module code-names to functional `lowercase_snake_case` names that follow ROS community conventions.

**Status:** Planned (not yet started)
**Priority:** Medium — quality improvement, not a blocker
**Estimated effort:** 13–20 hours across 5 PRs

---

## Why This Change

The current node names (`oko_perception_node`, `sputnik_planner_node`, `buran_controller_node`) use Russian space-program code-names. While memorable within the original team, they hurt:

1. **Discoverability.** A new contributor searching the repo or the community for "perception node" or "path planner" finds nothing; they must first learn the project's internal naming scheme.
2. **Onboarding.** `ros2 node list` output requires a mental translation layer before the system makes sense to outsiders.
3. **Community conventions.** Widely-used ROS 2 projects (nav2, moveit2, slam_toolbox) all use functional names that describe what the node does: `controller_server`, `planner_server`, `perception_node`.

---

## Naming Table

| Layer | Current | New | Notes |
|:------|:--------|:----|:------|
| **Python file** | `oko_perception.py` | `lidar_perception.py` | `git mv` to preserve history |
| **Python class** | `OkoPerception` | `LidarPerception` | Add `OkoPerception = LidarPerception` alias in v3.0 |
| **ROS node name** | `oko_perception_node` | `lidar_perception_node` | Change in v3.1 (after alias period) |
| **Entry point** | `oko_perception` | `lidar_perception` | Add both in setup.py during v3.0 |
| **Python file** | `sputnik_planner.py` | `waypoint_planner.py` | `git mv` |
| **Python class** | `SputnikPlanner` | `WaypointPlanner` | Add alias |
| **ROS node name** | `sputnik_planner_node` | `waypoint_planner_node` | Change in v3.1 |
| **Entry point** | `sputnik_planner` | `waypoint_planner` | Add both |
| **Python file** | `buran_controller.py` | `heading_controller.py` | `git mv` |
| **Python class** | `BuranController` | `HeadingController` | Add alias |
| **ROS node name** | `buran_controller_node` | `heading_controller_node` | Change in v3.1 |
| **Entry point** | `buran_controller` | `heading_controller` | Add both |
| **ROS topic** | `/sputnik/config` | `/planning/config` | Dual-publish during v3.0 |
| **ROS topic** | `/sputnik/set_config` | `/planning/set_config` | Dual-subscribe during v3.0 |
| **ROS topic** | `/sputnik/mission_command` | `/planning/mission_command` | Dual-subscribe during v3.0 |
| **Parameter** | `oko_min_safe_distance` | `perception_min_safe_distance` | Accept both during v3.0 |
| **Parameter** | `oko_critical_distance` | `perception_critical_distance` | Accept both during v3.0 |
| **CLI tool** | `vostok1_cli` | *keep as-is* | Tool name, not a ROS node — low renaming pressure |
| **System name** | `Vostok1` | *keep as project codename* | Used in `vostok1.launch.yaml` and docs as a system brand — acceptable |

### Collision check (verified)

All proposed new names have been verified against the entire active codebase:

- `lidar_perception` — zero matches (safe)
- `waypoint_planner` — zero matches (safe)
- `heading_controller` — zero matches (safe)
- `perception_min_safe_distance` — zero matches (safe)
- `/planning/config` — does not currently exist as a topic (safe; 5 existing `/planning/*` topics, no conflict)

---

## Impact Surface — Full Inventory

### Python source (3 files, ~175 references total)

| File | OKO refs | SPUTNIK refs | BURAN refs |
|:-----|:---------|:-------------|:-----------|
| `plan/plan/oko_perception.py` | ~90 | ~5 | ~5 |
| `plan/plan/sputnik_planner.py` | ~5 | ~40 | ~5 |
| `control/control/buran_controller.py` | ~5 | ~5 | ~45 |
| `plan/plan/vostok1_cli.py` | 0 | ~10 | 0 |

No cross-package Python imports exist between `plan/` and `control/` — they communicate exclusively via ROS topics. This means file renames within a package will not break the other package.

### ROS interface (topics, parameters, nodes)

- **3 branded topics** (`/sputnik/*`) used by 5 endpoints (3 nodes + dashboard + CLI) — total 9 topic references
- **2 branded parameters** (`oko_min_safe_distance`, `oko_critical_distance`) — declared in Python + set in YAML
- **4 node registrations** in `Node.__init__()`

### Entry points (setup.py)

- `plan/setup.py`: 3 branded entries (`oko_perception`, `sputnik_planner`, `vostok1_cli`)
- `control/setup.py`: 1 branded entry (`buran_controller`)

### Launch & shell scripts (~80 references)

- `launch/vostok1.launch.yaml` — node configs, exec names, parameter sections (~50 refs)
- `one_click_launch_all/launch_vostok1_complete.sh` — `pkill` process names, comments, labels (~40 refs)
- `one_click_launch_all/health_check_vostok1.sh` — node name checks, parameter checks (~30 refs)

### Web dashboard (~200+ references)

| File | OKO refs | BURAN refs | SPUTNIK refs |
|:-----|:---------|:-----------|:-------------|
| `web_dashboard/vostok1/index.html` | ~20 HTML IDs | ~17 HTML IDs | 0 |
| `web_dashboard/vostok1/app.js` | ~60 | ~40 | ~20 |
| `web_dashboard/vostok1/README_vostok1_dashboard.md` | ~7 | ~7 | ~4 |

Key items in app.js:

- Functions: `applyOkoParameters()`, `applyBuranParameters()`, `updateOkoInputs()`, `updateBuranInputs()`, `resetOkoDefaults()`, `resetBuranDefaults()`
- Constants: `OKO_DEFAULTS`, `BURAN_DEFAULTS`
- 4 preset objects (Universal / Buoy Field / Pier / Open Water) with `oko:` and `buran:` keys
- Topic strings: `/sputnik/config`, `/sputnik/set_config`, `/sputnik/mission_command`
- rosout filter: `message.name.includes('oko')`, `.includes('buran')`, `.includes('sputnik')`

### Active documentation (15 files, ~200+ references)

| File | Total branded lines |
|:-----|:--------------------|
| `README.md` | ~42 |
| `USER_MANUAL.md` | ~75 |
| `Board.md` | ~20 |
| `wiki/System_Overview.md` | ~34 |
| `wiki/Design_Rationale.md` | ~36 |
| `wiki/Glossary.md` | ~19 |
| `wiki/3D_LIDAR_Processing.md` | ~15 |
| `wiki/SASS.md` | ~7 |
| `wiki/Common_Issues.md` | ~11 |
| `wiki/Quick_Start.md` | ~5 |
| `wiki/Home.md` | ~2 |
| `wiki/README_WIKI.md` | ~4 |
| `wiki/UPLOAD_INSTRUCTIONS.md` | ~3 |
| `web_dashboard/vostok1/README_vostok1_dashboard.md` | ~22 |

All active markdown files MUST be updated as part of this refactor. The `wiki/Glossary.md` "Project Names" section will be retained as a historical note with a header like "Legacy Module Code-Names (pre-v3.0)".

---

## Approach: Two-Release Deprecation Cycle

### v3.0 — "New names alongside old" (backward compatible)

Old names continue to work. New names are the primary. Deprecation warnings emitted.

### v3.1 — "Old names removed" (breaking change)

All aliases, shim files, and dual-publish removed. Only new names work.

---

## Execution: 12 Steps in 5 PRs

### PR 1 — Python internals (Phase A, ~2-3 hours)

**Step 1: File renames with shims**

```bash
cd plan/plan/
git mv oko_perception.py lidar_perception.py
git mv ../plan/sputnik_planner.py ../plan/waypoint_planner.py
cd ../../control/control/
git mv buran_controller.py heading_controller.py
```

Create shim files at old paths (e.g., `plan/plan/oko_perception.py`):

```python
"""DEPRECATED: renamed to lidar_perception.py in v3.0."""
import warnings
warnings.warn(
    "Module 'plan.oko_perception' has been renamed to 'plan.lidar_perception'. "
    "Update your imports. This shim will be removed in v3.1.",
    DeprecationWarning, stacklevel=2
)
from plan.lidar_perception import *  # noqa: F401,F403
```

**Step 2: Class renames with aliases**

In `lidar_perception.py`:

```python
class LidarPerception(Node):
    ...

# DEPRECATED alias — remove in v3.1
OkoPerception = LidarPerception
```

Same pattern for `WaypointPlanner` / `SputnikPlanner` and `HeadingController` / `BuranController`.

**Step 3: Internal variable/comment cleanup**

Use IDE rename-symbol to update all internal references (docstrings, comments, variable names) within each file. No functional interface changes.

**Verification gate:** `colcon build` passes. `ros2 run plan oko_perception` and `ros2 run plan lidar_perception` both start (tested via dual entry points in Step 4).

### PR 2 — ROS interface aliases (Phase B, ~4-6 hours)

**Step 4: Dual entry points in setup.py**

```python
# plan/setup.py
'lidar_perception = plan.lidar_perception:main',
'oko_perception = plan.lidar_perception:main',  # DEPRECATED v3.0
'waypoint_planner = plan.waypoint_planner:main',
'sputnik_planner = plan.waypoint_planner:main',  # DEPRECATED v3.0

# control/setup.py
'heading_controller = control.heading_controller:main',
'buran_controller = control.heading_controller:main',  # DEPRECATED v3.0
```

**Step 5: Parameter aliases**

In `lidar_perception.py` (formerly `oko_perception.py`), add:

```python
# New name (primary)
self.declare_parameter('perception_min_safe_distance', 10.0)
# Old name (deprecated, accept if set)
self.declare_parameter('oko_min_safe_distance', 10.0)

# Read with fallback
new_val = self.get_parameter('perception_min_safe_distance').value
old_val = self.get_parameter('oko_min_safe_distance').value
if old_val != 10.0 and new_val == 10.0:
    self.get_logger().warn(
        "'oko_min_safe_distance' is deprecated; use 'perception_min_safe_distance'"
    )
    new_val = old_val
self.min_safe_distance = float(new_val)
```

Same for `oko_critical_distance` → `perception_critical_distance`.

**Step 6: Topic dual-publish/subscribe**

In `waypoint_planner.py` (formerly `sputnik_planner.py`):

```python
# New topics (primary)
self.config_pub = self.create_publisher(String, '/planning/config', 10)
self.set_config_sub = self.create_subscription(String, '/planning/set_config', self.config_callback, 10)
self.mission_cmd_sub = self.create_subscription(String, '/planning/mission_command', self.mission_command_callback, 10)

# Deprecated topics (keep for v3.0 backward compat)
self.config_pub_old = self.create_publisher(String, '/sputnik/config', 10)
self.set_config_sub_old = self.create_subscription(String, '/sputnik/set_config', self._deprecated_config_callback, 10)
self.mission_cmd_sub_old = self.create_subscription(String, '/sputnik/mission_command', self._deprecated_mission_callback, 10)
```

Where `_deprecated_*_callback` wraps the real callback with a one-time deprecation warning.

Update subscribers in `lidar_perception.py`, `heading_controller.py`, and `vostok1_cli.py` to use new topic names.

**Step 7: Deprecation log on node startup**

Each renamed node logs a warning on startup:

```
[WARN] Node 'oko_perception_node' will be renamed to 'lidar_perception_node' in v3.1.
       Update any scripts using this node name.
```

The actual `Node.__init__('oko_perception_node')` name stays unchanged in v3.0 — changing it would break `ros2 param set /oko_perception_node/...` commands.

**Verification gate:** `colcon build` passes. Health check 46/46. Dashboard still connects (it still uses `/sputnik/*` topics, which still work). `ros2 topic list` shows both `/sputnik/config` and `/planning/config`.

### PR 3 — Launch & shell scripts (Phase C, ~1-2 hours)

**Step 8: YAML launch file**

Update `launch/vostok1.launch.yaml`:

- Change `exec:` from `oko_perception` → `lidar_perception`, etc.
- Change parameter names from `oko_min_safe_distance` → `perception_min_safe_distance`
- Update all comments replacing OKO/SPUTNIK/BURAN with new names
- Keep `name: oko_perception_node` unchanged (node name changes in v3.1)

**Step 9: Shell scripts**

Update `launch_vostok1_complete.sh` and `health_check_vostok1.sh`:

- `pkill` targets: `"oko_perception"` → `"lidar_perception"`, etc.
- Health check node names: `"/oko_perception_node"` stays until v3.1
- Comments and labels: OKO → Perception, SPUTNIK → Planner, BURAN → Controller

**Verification gate:** `launch_vostok1_complete.sh` one-click launch still works. Health check still 46/46.

### PR 4 — Dashboard (Phase D, ~4-6 hours, highest risk)

**Step 10: HTML IDs**

In `web_dashboard/vostok1/index.html`, rename all branded IDs:

```
oko-min-height       → perception-min-height
oko-max-height       → perception-max-height
oko-safe-dist        → perception-safe-dist
oko-critical-dist    → perception-critical-dist
...
buran-critical-dist  → controller-critical-dist
buran-safe-dist      → controller-safe-dist
...
btn-apply-oko        → btn-apply-perception
btn-apply-buran      → btn-apply-controller
btn-reset-oko        → btn-reset-perception
btn-reset-buran      → btn-reset-controller
```

**Step 11: JavaScript**

In `web_dashboard/vostok1/app.js`:

- Function renames: `applyOkoParameters()` → `applyPerceptionParameters()`, etc.
- Constant renames: `OKO_DEFAULTS` → `PERCEPTION_DEFAULTS`, `BURAN_DEFAULTS` → `CONTROLLER_DEFAULTS`
- Topic strings: `/sputnik/config` → `/planning/config`, `/sputnik/set_config` → `/planning/set_config`, `/sputnik/mission_command` → `/planning/mission_command`
- Preset object keys: `oko:` → `perception:`, `buran:` → `controller:`
- rosout filter: `'oko'` → `'lidar_perception'` (or `'perception'`), `'buran'` → `'heading_controller'` (or `'controller'`)
- All `getElementById()` calls must match new HTML IDs

**Add localStorage migration** at app startup:

```javascript
// Migrate saved presets from old key names (one-time)
if (localStorage.getItem('oko_config')) {
    localStorage.setItem('perception_config', localStorage.getItem('oko_config'));
    localStorage.removeItem('oko_config');
}
```

**Verification gate:** Open dashboard. Verify: map loads, GPS displays, all 4 Monitoring/Control/Tuning/Visualization modules work. Click Apply on both OKO and BURAN panels — parameters reach nodes. Click each preset button. Click Reset Defaults. Run a full Generate → Confirm → Start → Stop cycle.

### PR 5 — Documentation (Phase E, ~2-3 hours)

**Step 12: All active markdown files**

Update ALL 15 active markdown files listed in the Impact Surface table above. For each:

- Replace `OKO` → `Perception (OKO)` or just the new functional name depending on context
- Replace `SPUTNIK` → `Planner (SPUTNIK)` or just the new name
- Replace `BURAN` → `Controller (BURAN)` or just the new name
- Replace `oko_perception_node` → `lidar_perception_node`
- Replace `sputnik_planner_node` → `waypoint_planner_node`
- Replace `buran_controller_node` → `heading_controller_node`
- Replace `/sputnik/config` → `/planning/config`, `/sputnik/set_config` → `/planning/set_config`, `/sputnik/mission_command` → `/planning/mission_command`
- Replace `oko_min_safe_distance` → `perception_min_safe_distance`, `oko_critical_distance` → `perception_critical_distance`

**Special handling for `wiki/Glossary.md` "Project Names" section:**

Rename from "Project Names" to "Legacy Module Code-Names (pre-v3.0)" and add a note:

> As of v3.0, the modules use functional names: `lidar_perception` (formerly OKO), `waypoint_planner` (formerly SPUTNIK), `heading_controller` (formerly BURAN). The Russian space-program names below are retained as historical context.

**Verification gate:** `grep -rn "oko_perception_node\|sputnik_planner_node\|buran_controller_node" wiki/ README.md USER_MANUAL.md Board.md` returns zero matches (except the Glossary historical note).

---

## v3.1 Release — Cleanup (1-2 hours, separate PR)

After v3.0 has been in use for at least one release cycle:

1. **Remove shim files** (`plan/plan/oko_perception.py`, etc.)
2. **Remove class aliases** (`OkoPerception = LidarPerception`)
3. **Remove deprecated entry points** from setup.py
4. **Remove deprecated topic dual-publish** — only publish to `/planning/*`
5. **Remove deprecated parameter aliases** — only accept `perception_*`
6. **Change node names** in `Node.__init__()` — `oko_perception_node` → `lidar_perception_node`
7. **Update health check** node name checks
8. **Update shell script** `pkill` targets if they reference old process names

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|:-----|:-------|:-----------|:-----------|
| Dashboard breaks after HTML ID rename | High | Medium | Dedicated PR 4; manual test every panel before merge |
| External scripts use old node names | Medium | Low | v3.0 keeps old names; startup warning gives users time to migrate |
| `/sputnik/set_config` atomic rename breaks 5 endpoints | High | Low | Dual-subscribe in v3.0; all 5 endpoints switch in same PR |
| `git blame` history lost on file rename | Low | Certain | Use `git mv` (Git tracks renames); add commit message noting the rename |
| Team muscle memory (`ros2 run plan sputnik_planner`) | Low | High | Dual entry points in v3.0; old command still works with deprecation warning |
| Preset localStorage migration fails | Low | Low | One-time migration function at app startup; fallback to defaults |

---

## Files NOT Affected (excluded from rename)

- `legacy/` — historical code, already deprecated. No changes.
- `working_diary/` — historical logs. References are time-stamped records. No changes.
- `PPT/assets/presentation_script.md` — presentation material. Keep as-is with historical context.
- `images/` — binary files. No text references.
- Test files (`plan/test/`, `control/test/`) — currently contain zero branded references.

---

## Decision Log

| Decision | Rationale |
|:---------|:----------|
| Keep `vostok1_cli` name | CLI tool name, not a ROS node. Low community-convention pressure. Users already have muscle memory. |
| Keep `Vostok1` as system brand | Used in `vostok1.launch.yaml` and as a recognizable project identity. Acceptable as a product name. |
| Use `perception_*` for renamed OKO parameters (not `lidar_*`) | Avoids coupling the parameter name to the specific sensor type. If we later add camera perception, `perception_min_safe_distance` still makes sense; `lidar_min_safe_distance` would not. |
| Rename documentation fully (not just "mention new names primarily") | Half-renamed docs are worse than fully old or fully new. Grep for "oko_perception_node" should return zero outside of the Glossary historical note. |
| Two-release deprecation cycle | Atomic rename of 500+ references risks broken intermediate states. The alias period lets external users migrate gracefully. |

---

## See Also

- **[Glossary](Glossary)** — Current term definitions (will be updated when rename lands)
- **[Design_Rationale](Design_Rationale)** — Why the modular architecture exists
- **[System_Overview](System_Overview)** — High-level architecture
