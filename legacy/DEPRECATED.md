# Legacy Code

This folder contains deprecated code that is no longer actively maintained.
The current system uses the **modular AutoBoat architecture** — three nodes: `lidar_perception` (Perception), `waypoint_planner` (Planner), `heading_controller` (Controller). The earlier code-names `OKO` / `SPUTNIK` / `BURAN` / `Vostok1` were renamed on 16/04/2026 to functional names; see `wiki/Node_Naming_Refactor_Plan.md` for the mapping.

## Directory Structure

| Folder | Description | Deprecated |
|:-------|:------------|:-----------|
| `all_in_one/` | Monolithic all-in-one navigation stack (formerly `vostok1_integrated.py`) | 2025-12-12 |
| `atlantis/` | Atlantis planner, controller, launch files, and dashboard | 2025-12-12 |
| `robust_avoidance/` | Robust avoidance controller, launch, dashboard, and docs | 2025-12-12 |
| `misc/` | Standalone planners, old scripts, and port allocation docs | Various |
| `fixed_variants/` | Earlier snapshots of the perception and controller nodes under their pre-rename names (`oko_perception_fixed.py`, `buran_controller_fixed.py`) | 2026-04-12 |
| `utilities/` | Standalone helper nodes not used by the active modular system: `mission_trigger`, `tf_broadcaster` (3 variants), `simple_perception`, `gps_imu_pose`, `pose_filter` | 2026-04-12 |

## Why Deprecated?

The **integrated / Atlantis / robust-avoidance** systems were replaced by the **modular AutoBoat architecture** which offers:

- Better maintainability (separated concerns: Perception via `lidar_perception`, Planning via `waypoint_planner`, Control via `heading_controller`)
- Runtime parameter configuration via launch YAML
- A* path planning (hybrid + runtime modes)
- Hazard zone avoidance
- Web dashboard with tuning presets
- Health check monitoring script
- Easier debugging (test each node independently)

## Should I Use This?

**No.** Use the modular system instead:

```bash
cd <workspace>/src/uvautoboat/one_click_launch_all
bash launch_autoboat_complete.sh
```

This code is kept for historical reference only.
