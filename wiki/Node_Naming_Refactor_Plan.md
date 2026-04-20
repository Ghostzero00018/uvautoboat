# Node Naming Refactor — Completed Record

Renamed OKO / SPUTNIK / BURAN / Vostok1 module code-names to functional `lowercase_snake_case` names that follow ROS community conventions.

**Status:** Done (2026-04-16)
**Approach:** One-shot atomic rename (no deprecation cycle)
**Actual effort:** ~1 session, all layers in one pass
**Files touched:** 26 active files (~1,100+ branded references replaced)

---

## Why This Change Was Made

The old node names (`oko_perception_node`, `sputnik_planner_node`, `buran_controller_node`) used U.S.S.R. space-program code-names. While memorable within the original team, they hurt:

1. **Discoverability.** A new contributor searching for "perception node" or "path planner" found nothing without knowing the internal naming scheme.
2. **Onboarding.** `ros2 node list` output required a mental translation layer before the system made sense to outsiders.
3. **Community conventions.** Widely-used ROS 2 projects (nav2, moveit2, slam_toolbox) all use functional names that describe what the node does.

---

## Complete Naming Table

| Layer | Old | New |
|:------|:----|:----|
| **Python file** | `oko_perception.py` | `lidar_perception.py` |
| **Python class** | `OkoPerception` | `LidarPerception` |
| **ROS node name** | `oko_perception_node` | `lidar_perception_node` |
| **Entry point** | `oko_perception` | `lidar_perception` |
| **Python file** | `sputnik_planner.py` | `waypoint_planner.py` |
| **Python class** | `SputnikPlanner` | `WaypointPlanner` |
| **ROS node name** | `sputnik_planner_node` | `waypoint_planner_node` |
| **Entry point** | `sputnik_planner` | `waypoint_planner` |
| **Python file** | `buran_controller.py` | `heading_controller.py` |
| **Python class** | `BuranController` | `HeadingController` |
| **ROS node name** | `buran_controller_node` | `heading_controller_node` |
| **Entry point** | `buran_controller` | `heading_controller` |
| **CLI file** | `vostok1_cli.py` | `autoboat_cli.py` |
| **CLI node name** | `vostok1_cli` | `autoboat_cli` |
| **CLI entry point** | `vostok1_cli` | `autoboat_cli` |
| **System name** | `Vostok1` | `AutoBoat` |
| **Launch file** | `vostok1.launch.yaml` | `autoboat.launch.yaml` |
| **Launch script** | `launch_vostok1_complete.sh` | `launch_autoboat_complete.sh` |
| **Health check** | `health_check_vostok1.sh` | `health_check_autoboat.sh` |
| **Dashboard dir** | `web_dashboard/vostok1/` | `web_dashboard/autoboat/` |
| **Dashboard README** | `README_vostok1_dashboard.md` | `README_autoboat_dashboard.md` |
| **ROS topic** | `/sputnik/config` | `/planning/config` |
| **ROS topic** | `/sputnik/set_config` | `/planning/set_config` |
| **ROS topic** | `/sputnik/mission_command` | `/planning/mission_command` |
| **Parameter** | `oko_min_safe_distance` | `perception_min_safe_distance` |
| **Parameter** | `oko_critical_distance` | `perception_critical_distance` |
| **HTML IDs** | `oko-*` | `perception-*` |
| **HTML IDs** | `buran-*` | `controller-*` |
| **JS constants** | `OKO_DEFAULTS` / `BURAN_DEFAULTS` | `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` |
| **JS functions** | `applyOkoParameters()` / `applyBuranParameters()` | `applyPerceptionParameters()` / `applyControllerParameters()` |

---

## How It Was Executed

### Approach: one-shot rename instead of two-release deprecation

The original plan proposed a v3.0/v3.1 deprecation cycle with shim files, dual-publish topics, and parameter aliases. This was replaced with a one-shot atomic rename because:

- The project has **no external consumers** (1 active maintainer + 2 occasional collaborators, no downstream packages).
- No shim files, dual-publish, or alias code was needed — eliminating ~50% of the planned effort.
- All changes were committed together, so the system was never in a partially-renamed state.

### Execution order (4 phases, inside-out)

| Phase | What | Files | Why this order |
|:------|:-----|:------|:---------------|
| **1. Python core** | `git mv` 4 files, rename classes, node names, topics, params, entry points | 4 `.py` + 2 `setup.py` + `health_check_service.py` | Everything else references these names |
| **2. Launch + scripts** | `git mv` 3 files, update exec names, pkill targets, param checks | `autoboat.launch.yaml`, 2 shell scripts | Reference entry point and node names from Phase 1 |
| **3. Dashboard** | `git mv` directory, rename 68 HTML IDs, 290 app.js references, README | `index.html`, `app.js`, dashboard README | References topics and param names from Phase 1 |
| **4. Documentation** | Find-and-replace across 15 markdown files | README, USER_MANUAL, Board, 12 wiki pages | References everything from all prior phases |

### Verification performed

- **Clean build:** `colcon build --merge-install` — 7/7 packages built with zero errors
- **getElementById cross-check:** every `getElementById()` call in app.js has a matching HTML `id=` attribute — zero orphans
- **Exhaustive grep:** zero old-name matches in active code (only `legacy/`, `working_diary/`, and this file's naming table)
- **Shell syntax:** `bash -n` passed for both renamed shell scripts
- **YAML validity:** `yaml.safe_load()` passed for `autoboat.launch.yaml`

---

## Files Not Affected

- `legacy/` — historical deprecated code, untouched by design
- `working_diary/` — historical development logs, untouched by design
- `images/` — binary files, no text references
- `plan/test/`, `control/test/` — contain zero branded references
- `style_merged.css` — zero branded selectors (confirmed pre-rename)

---

## Decision Log

| Decision | Rationale |
|:---------|:----------|
| One-shot rename (no deprecation cycle) | No external consumers exist. The deprecation machinery (shims, dual-publish, parameter aliases) would have cost ~50% of the effort for zero benefit. |
| Keep `heading_controller` (not `thrust_controller` or `motion_controller`) | Matches the node's primary responsibility: PID heading control. The anti-stuck and emergency stop are secondary behaviors. |
| Use `perception_*` for renamed parameters (not `lidar_*`) | Sensor-agnostic: if camera perception is added later, `perception_min_safe_distance` still makes sense. |
| Rename `Vostok1` → `AutoBoat` | Aligns system branding with the repository name `uvautoboat`. |
| Rename `/sputnik/*` topics → `/planning/*` | Aligns with existing `/planning/path`, `/planning/waypoints` topics already in use. |
| Rename documentation fully | Half-renamed docs are worse than fully old or fully new. `grep "oko_perception_node"` now returns zero outside this file. |
| Retain old names in `wiki/Glossary.md` | The "Legacy Module Code-Names (pre-v3.0)" section preserves historical context for anyone reading old commits or logs. |

---

## See Also

- **[Glossary](Glossary)** — Term definitions (includes legacy code-name section)
- **[Design_Rationale](Design_Rationale)** — Why the modular architecture exists
- **[System_Overview](System_Overview)** — High-level architecture with new names
