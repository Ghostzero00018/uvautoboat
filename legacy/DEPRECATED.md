# Legacy Code

This folder contains deprecated code that is no longer actively maintained.
The current system uses the **modular Vostok1 architecture** (OKO + SPUTNIK + BURAN).

## Directory Structure

| Folder | Description | Deprecated |
|:-------|:------------|:-----------|
| `all_in_one/` | Monolithic all-in-one navigation stack | 2025-12-12 |
| `atlantis/` | Atlantis planner, controller, launch files, and dashboard | 2025-12-12 |
| `robust_avoidance/` | Robust avoidance controller, launch, dashboard, and docs | 2025-12-12 |
| `misc/` | Standalone planners, old scripts, and port allocation docs | Various |

## Why Deprecated?

The **integrated/Atlantis/robust-avoidance** systems were replaced by the **modular Vostok1 architecture** which offers:

- Better maintainability (separated concerns: OKO perception, SPUTNIK planning, BURAN control)
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
bash launch_vostok1_complete.sh
```

This code is kept for historical reference only.
