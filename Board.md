# 📋 AutoBoat Development Board

[![Status](https://img.shields.io/badge/Status-Active-green)](https://github.com/Ghostzero00018/uvautoboat)
[![Progress](https://img.shields.io/badge/Progress-90%25-blue)](https://github.com/Ghostzero00018/uvautoboat)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

| | |
|---|---|
| **Project** | AutoBoat Navigation System |
| **Repository** | [Ghostzero00018/uvautoboat](https://github.com/Ghostzero00018/uvautoboat) |
| **Last Updated** | 22/04/2026 |
| **Status** | 🟢 Simulation ready (A* path planning + one-click launcher + wiki docs + dashboard config system). Real-hardware deployment begins next week. |

---

## 📊 Progress Overview

| Phase | Description | Status | Progress |
|:-----:|-------------|:------:|:--------:|
| 1 | Architecture & MVP | ✅ | 100% |
| 2 | Autonomous Navigation | ✅ | 100% |
| 3 | Coverage Planning | ⏸️ | 0% |
| 4 | Integration & Testing | 🔄 | 90% |
| 5 | Real-Hardware Deployment | 🔜 | 0% |

### Active System

| System | Architecture | Sensors | Features |
|--------|--------------|---------|----------|
| **AutoBoat Modular** | Modular (Perception + Planner + Controller) | 3D PointCloud | A* path planning, simple anti-stuck, runtime config, web dashboard + camera, waypoint persistence |

> **Note:** The integrated AutoBoat monolith has been deprecated and moved to `legacy/`. Use the modular system.

---

## Phase 1: Architecture & MVP ✅

**Completed**: 27/11/2025

| Task | Status |
|------|:------:|
| ROS 2 topic conventions (\`/planning/path\`) | ✅ |
| Message types (Path, PoseStamped) | ✅ |
| Workspace structure (\`seal_ws\`) | ✅ |
| Straight-line planner v1.0 | ✅ |
| Path following controller v1.1 | ✅ |
| TF tree configuration | ✅ |

---

## Phase 2: Autonomous Navigation ✅

**Completed**: 28/11/2025

### AutoBoat Navigation System

- Integrated perception + planning + control
- Modular variant: Perception + Planner + Controller three-node pipeline
- 3D PointCloud processing (height/distance filtering)
- Simple Anti-Stuck System
  - Turn toward clearer side (bidirectional) until path clear
  - Kalman-filtered drift compensation
  - Skip detection during obstacle avoidance
- **Waypoint Skip Strategy** (NEW)
  - Stuck-based skip after 4 attempts
  - Obstacle blocking skip after 45s timeout
- Runtime PID/speed configuration
- Real-time web dashboard
- Terminal Mission CLI (`autoboat_cli`)

---

## Phase 3: Coverage Planning ⏸️

**Status**: Not Started | **Priority**: Low

| Task | Status |
|------|:------:|
| Region definition (polygon boundaries) | ⬜ |
| Boustrophedon coverage planner | ⬜ |
| Coverage validation (>95% target) | ⬜ |

---

## Phase 4: Integration & Testing 🔄

**Progress**: 90%

### Completed ✅

| Test | Status |
|------|:------:|
| GPS waypoint following | ✅ |
| Obstacle detection (3D) | ✅ |
| Multi-waypoint missions | ✅ |
| Stuck detection/recovery | ✅ |
| Waypoint skip strategy | ✅ |
| Runtime config updates | ✅ |
| Web dashboard (map, mission, camera) | ✅ |
| Terminal CLI | ✅ |
| Min-range spawn fix (5m) | ✅ |
| A* path planning (hybrid + runtime) | ✅ |
| One-click launcher script | ✅ |
| Emergency stop (dashboard + CLI + nodes) | ✅ |
| Latched E-Stop channel (`/planning/emergency_stop` Bool, RELIABLE QoS) | ✅ |
| ACK-based stop / generate as `std_srvs/Trigger` services | ✅ |
| JSON log export (4 panels) | ✅ |
| JSON schema guards at publishers + visible dashboard errors | ✅ |
| Health check service (ROS 2 node + dashboard streaming) | ✅ |
| Health check 4-state parameter validation (PASS/TUNED/WARN/FAIL) | ✅ |
| Dashboard config system (dirty-params, sync, reset defaults) | ✅ |
| Parameter collision resolution (`perception_` prefix) | ✅ |
| VRX LiDAR patch script | ✅ |
| `max_speed` cap wired as forward-thrust ceiling | ✅ |
| Kalman drift compensation activated (gated update + feed-forward) | ✅ |
| Launcher readiness polls (replace fixed sleeps) + `WS_ROOT` guard | ✅ |

### Pending ⬜

| Task | Priority |
|------|:--------:|
| Performance benchmarking (RMS error) | Medium |
| Obstacle stress testing | Medium |
| Long-duration test (15+ min) | Low |
| Complex waypoint circuit (8-point) | Low |

### Documentation ✅

| Document | Status |
|----------|:------:|
| README.md | ✅ |
| Board.md | ✅ |
| Code comments | ✅ |
| Troubleshooting guide | ✅ |

---

## Phase 5: Real-Hardware Deployment 🔜

**Status**: Planned | **Expected kickoff**: Week of 20/04/2026 | **Priority**: High

Supervisor has signalled imminent access to the real AutoBoat central control unit (CCU). Expected two-tier control architecture:

- **High-level (confirmed)**: Raspberry Pi 5 running ROS 2 Jazzy + this repo's nodes, LiDAR driver, GPS/IMU drivers, dashboard, shore comms.
- **Low-level (TBD — not confirmed)**: Supervisor mentioned something like an STM32 microcontroller, but the exact chip / whether a dedicated low-level board exists at all has not been confirmed. Could be STM32, ESP32, a commercial motor controller, or even omitted (Pi handles everything). Clarify with supervisor before hardware arrives.

The whole repo is expected to run on the Pi 5.

### Risks ranked (mitigation prep can start on Linux workstation without hardware)

| # | Risk | Why it matters | Mitigation |
|:-:|------|----------------|------------|
| 1 | LiDAR performance on Pi 5 | 30k points × 10 Hz in `rclpy` may saturate 1-2 cores | Profile callback in VRX; have `sample_rate: 2` + raised `min_cluster_size` as fallback; last resort = rewrite hot loop in `rclcpp` |
| 2 | `/wamv/*` topic hardcoding | 3 months of work tied to simulated topic names | Launch-file remapping (cleanest); inventory every `/wamv/*` reference to make next-week swap mechanical |
| 3 | Low-level bridge (new node, only needed *if* a separate low-level controller exists) | Translate thrust commands + ingest telemetry; protocol (UART/CAN/micro-ROS/GPIO PWM) depends on whatever the low-level controller runs — or is a non-issue if the Pi drives thrusters directly | **Ask supervisor: is there a low-level controller at all, and if yes what runs on it?** — this answer determines whether a bridge node is needed |
| 4 | Headless comms to shore | Dashboard range ≈ Pi's WiFi (30-50 m typical) | Walk-test WiFi range; 4G modem or directional antenna if > 50 m mission box; static IP or mDNS |
| 5 | Power-loss robustness | SD cards corrupt on sudden power-off — default boat failure mode | USB 3 SSD boot or read-only root FS with tmpfs overlay for logs |
| 6 | Safety integration | Real boat can damage property | Hardware watchdog (location depends on CCU architecture) + physical E-stop + a geofence mechanism TBD (cheapest option: a new dedicated check in the planner; re-introducing hazard polygons is also on the table); end-to-end verify dashboard E-stop cuts thrusters |

### Prep tasks (no hardware required)

| Task | Status |
|------|:------:|
| Write `remap.launch.yaml` aliasing `/wamv/*` → neutral topics; verify stack still runs | 🟡 file deployed 22/04/2026 (`816be9d`); 6 relays up + GPS matches source 1:1, but no-regression mission test deferred to Phase 5.1 bench (laptop RTF too low to hold a clean baseline) |
| Profile `/perception/obstacle_info` Hz in VRX; document baseline | ✅ 20.00 Hz at RTF ≈ 1.0, 4 ms stdev, 120 s under Buoy Field mission (22/04/2026 Linux workstation). Rate tracks Gazebo RTF — this host drops to 30-40% under heavier load; Pi 5 on-water is the real Phase 5 baseline to compare against. |
| Stub bridge node (inputs `/control/thrust_cmd`, outputs thrusters) with pass-through behaviour | 🟡 pseudocode drafted |
| Inventory of every `/wamv/*` reference across Python, YAML, JS, HTML | ✅ done |
| Supervisor conversation: confirm CCU architecture (is there a low-level controller? what chip? what firmware? any interface-control document?) | 🟡 checklist drafted |
| Spec shore-comms plan (WiFi range test, fallback to 4G) | ⬜ |

### Hardware-arrival tasks (requires CCU on-bench)

| Task | Status |
|------|:------:|
| Install Ubuntu 24.04 + ROS 2 Jazzy on Pi 5 | ⬜ |
| Build workspace on Pi 5 (native ARM64 build) | ⬜ |
| Wire bridge node to real low-level protocol (only if supervisor confirms a separate low-level controller) | ⬜ |
| Swap `/wamv/*` remaps to real driver topic names | ⬜ |
| Bench test: dashboard → Pi 5 → (low-level if present) → thruster signal (dry bench, motors disconnected) | ⬜ |
| Static analysis of thermals + current draw under full-stack load | ⬜ |

### On-water tasks (requires full CCU in boat, test-lake access)

| Task | Status |
|------|:------:|
| Manual-joystick test (no autonomy) — verify thruster mapping + E-stop | ⬜ |
| Single-waypoint autonomous run in fenced test area | ⬜ |
| Multi-waypoint mission with obstacle avoidance | ⬜ |
| Long-duration robustness (15+ min) on-water | ⬜ |
| Failure-mode drills: manual override, E-stop, low-battery return-to-home | ⬜ |

---

## 📝 Issue Tracking

### Resolved ✅

| Issue | Resolution |
|-------|------------|
| Invalid Windows file paths | Renamed to \`FREE.py\`, \`OUT.py\` |
| Sparse checkout blocking | \`git sparse-checkout disable\` |
| Markdown lint errors | Added \`.markdownlint.json\` |
| Spawn dock obstacle detection | Increased min_range from 0.5m → 5.0m |
| Runtime config not updating | Added config_callback to heading_controller |
| Boat circling around buoys | Added waypoint skip strategy (45s timeout) |
| Missing numpy dependency | Added python3-numpy to package.xml |
| Invalid setup.py entries | Removed non-existent apollo11, atlantis |
| Perception/Controller param collision (min_safe_distance) | Renamed Perception's to `perception_min_safe_distance` |
| Perception/Controller param collision (critical_distance) | Renamed Perception's to `perception_critical_distance` |
| Dashboard sending all params on Apply | Added dirty-params filtering (only changed fields sent) |
| Dashboard stale HTML defaults | Synced 17 HTML defaults to match launch YAML |
| VRX LiDAR at world origin | `patch_vrx.sh` fixes `publish_model_pose` (issue #876) |
| Dead code in setup.py / nodes | Removed `_fixed` variants, unused utilities, dead states |
| Missing `std_srvs` dependency | Added to plan/package.xml |
| Dead `restart_mission` / `panic_stop` code | Removed from Controller, dashboard, CLI |

### Active 🔄

| Issue | Priority | Description |
|-------|:--------:|-------------|
| #4 | Medium | Advanced planner debugging |
| #5 | Medium | PID tuning refinement |
| #6 | Low | Gazebo SDF customization |

---

## 📅 Timeline

| Date | Milestone | Status |
|------|-----------|:------:|
| 25/11/2025 | Project Kickoff | ✅ |
| 26/11/2025 | Basic Navigation | ✅ |
| 27/11/2025 | End-to-End Pipeline | ✅ |
| 28/11/2025 | AutoBoat Navigation Complete | ✅ |
| 01/12/2025 | Simple Anti-Stuck + Mission CLI | ✅ |
| 03/12/2025 | Waypoint Skip + Runtime Config | ✅ |
| 03/12/2025 | Go Home Optimization (detour insertion) | ✅ |
| 03/12/2025 | README Consolidation + Cleanup | ✅ |
| 08/12/2025 | A* Path Planning (Hybrid + Runtime modes) | ✅ |
| 09/12/2025 | One-Click Launcher Script | ✅ |
| 11/12/2025 | Wiki Documentation + README Update | ✅ |
| 14/12/2025 | LiDAR Smoke Detection (Spatial Density Filtering) | ✅ |
| 03/04/2026 | Code review + repo cleanup rounds | ✅ |
| 08/04/2026 | Obstacle avoidance partial fixes + dashboard cleanup | ✅ |
| 12/04/2026 | Pre-meeting sprint: VRX patch, repo audit, README rewrite, dashboard polish | ✅ |
| 13/04/2026 | Dashboard config system: dirty-params, param sync, reset defaults, collision fixes | ✅ |
| 13/04/2026 | USER_MANUAL + dashboard README rewrite | ✅ |
| 15/04/2026 | PPT fact-check (16 items), bilingual presentation script, logo SVG | ✅ |
| 15/04/2026 | Supervisor meeting delivered; wiki backfill (Glossary + Design_Rationale); Node Naming Refactor Plan | ✅ |
| 13/04/2026 | Teammate onboarding fix: bashrc guide, dashboard diagnostics, dynamic WebSocket URL, COLCON_IGNORE tracked, health check audit (46/46) | ✅ |
| 15/04/2026 | Pre-meeting dry-run after ROS 2 Jazzy apt upgrade — no regression, 46/46 PASS | ✅ |
| 16/04/2026 | One-shot node rename: OKO/SPUTNIK/BURAN/Vostok1 → functional names (26 files, ~1100+ refs) | ✅ |
| 16/04/2026 | Dashboard security: XSS fix, SRI hashes, server-side param validation, security wiki page | ✅ |
| 16/04/2026 | Dashboard UX: reject-not-clamp validation, orange/red toasts, range tooltips, copy buttons, A* panel fixes | ✅ |
| 17/04/2026 | Param-range single source of truth: Python nodes publish `PARAM_RANGES`, dashboard auto-syncs HTML min/max | ✅ |
| 17/04/2026 | Dashboard `JSON.parse` hardening: 8 subscribers wrapped in try/catch to tolerate malformed messages | ✅ |
| 17/04/2026 | Dashboard UX polish: 31 hover tooltips, nav-mode restyle, preset confirm dialog, map grid performance | ✅ |
| 17/04/2026 | LiDAR smoke detection fully removed (-624 LOC across 10 files); FINISHED counter clamp; split-screen CSS hardening | ✅ |
| 18/04/2026 | Hardware-deployment phase logged; docs audit (`distributed` → modular) across README + USER_MANUAL + Board | ✅ |
| 19/04/2026 | Target-aware VFH via `/control/heading_error` + 4 `vfh_*` tunable params; preset cleanup (Python default sync, dead-weight key trim, CLI `--mode` legacy removal); Vostok1-era breadcrumb cleanup | ✅ |
| 19/04/2026 | Dashboard Go Home distance-based progress + `distance_to_target` wiring fix; latent `distance.toFixed` DOM-node crash fix | ✅ |
| 19/04/2026 | Docs fact-check sweep (Kalman params, health-check count, Python version, VFH, escape direction, preset names); `ros2 daemon` staleness documented in Common_Issues | ✅ |
| 19/04/2026 | Tier A/B/C dashboard UX sprint: E-Stop header badge, Reset guard, toast tuning, panel reorder, Map+Camera group, collapsible info panels, preset expand/flash/scroll, step hints, first-run onboarding tour | ✅ |
| 20/04/2026 | Dead-code & bandage audit (50-item plan); Tier 1 safe deletes (`SENSOR_TIMEOUT`, `escape_start_time`, `in_hazard_zone`, unused imports); voyage-completion off-by-one fix; `Common_Issues` colcon-cwd entry | ✅ |
| 20/04/2026 | `max_speed` cap wired + Kalman drift feed-forward activated (gated update, thrust compensation); `Design_Rationale` PID/speed-shaping + drift-compensation + hand-tuned-constants tables | ✅ |
| 20/04/2026 | Launcher readiness polls (`wait_for_topic`/`wait_for_port`/`wait_for_node`) + `WS_ROOT` sibling-`src/` guard against nested workspaces | ✅ |
| 20/04/2026 | Perception `moving_obstacles` velocity pipeline removed (-124 LOC, zero consumers) | ✅ |
| 20/04/2026 | Tier 2 close-out: latched `/planning/emergency_stop` Bool channel; `std_srvs/Trigger` services for stop + generate (drops CLI/dashboard retry loops); `position_history` reset on stop resume (prevent Kalman spike); JSON schema guards at publishers + visible dashboard errors; drop redundant Waiting-for-sync label | ✅ |
| 21/04/2026 | Health check 4-state parameter validation (PASS/TUNED/WARN/FAIL) via `config_tuned` flag on 3 nodes; dashboard `[TUNED]` magenta styling | ✅ |
| 21/04/2026 | Markdown refresh post-Tier-2: Glossary health-check entry, USER_MANUAL topology + services table, dashboard README service-client section | ✅ |
| 22/04/2026 | C1/C2/C3 bug fixes (`3389554`): `_log_bad_json` helper propagated from CLI to perception + planner callbacks (drops `except Exception: pass` silent fallbacks); `force_turn_after_reverse` latch now persists across control ticks — removed the unconditional same-tick reset that made the flag dead | ✅ |
| 22/04/2026 | I6 docstring refresh on 3 nodes (`cd009c0`): pub/sub surfaces match code; 8-state planner machine documented; Trigger services section added; `/control/heading_error`, `/planning/emergency_stop`, `/planning/set_config`, `/perception/param_ranges`, `/control/param_ranges` now in docstrings | ✅ |
| 22/04/2026 | Perception publish-rate baseline recorded (`65709a0`, RTF caveat `816be9d`): 20.00 Hz mean, 4 ms stdev, 120 s Buoy Field mission at RTF ≈ 1.0; rate tracks Gazebo RTF, Pi 5 on-water remains the real Phase 5 comparison target | ✅ |
| 22/04/2026 | `launch/remap.launch.yaml` deployed (`816be9d`): 6 `topic_tools/relay` nodes (GPS / IMU / LiDAR / camera / thrust L+R) gated on `use_real_hardware:=false`, plus conditional bridge-node stub for Phase 5.1; YAML `if:`/`unless:` syntax used (draft's nested `condition:` rejected by Jazzy launch schema) | ✅ |
| TBD | Real-hardware deployment (Pi 5 as confirmed target; low-level CCU architecture TBD) | 🔜 |
| TBD | Coverage Planning | ⏸️ |

---

## 🎯 Next Priorities

1. **Phase 5 prep tasks** (see above): supervisor conversation on CCU architecture, topic-remap dry run, LiDAR profiling, bridge-node stub, `/wamv/*` inventory
2. Long-duration stress testing (15+ min missions) — may be superseded by on-water runs once hardware lands
3. Complex waypoint circuits with obstacles
4. Performance benchmarking (RMS error analysis)
5. Coverage planning algorithms (boustrophedon)

---

## 🚀 Future Ideas

| Feature | Priority | Description |
|---------|:--------:|-------------|
| **Dynamic Replanning** | High | Replan when new obstacles detected mid-route |
| **Go-To-Point** | Medium | Navigate to arbitrary GPS coordinate with obstacle avoidance |
| **Multi-Goal Navigation** | Medium | Sequence of random points (patrol mode) |
| **Coverage Planning** | Low | Boustrophedon pattern for area scanning |

### Recently Completed ✅

| Feature | Status | Description |
|---------|:------:|-------------|
| **A* Path Planning** | ✅ Done | Hybrid mode (pre-plan) + Runtime mode (detours) in Waypoint Planner |
| **One-Click Launcher** | ✅ Done | `launch_autoboat_complete.sh` for full system startup |
| **Wiki Documentation** | ✅ Done | Comprehensive wiki pages in `wiki/` folder |
| **Emergency Stop** | ✅ Done | Latching stop from dashboard/CLI, EMERGENCY_STOP state |
| **Dashboard Config System** | ✅ Done | 3 Apply panels, dirty-params, reset defaults, disabled until sync |
| **Param Collision Fix** | ✅ Done | Perception params prefixed `perception_` to avoid Controller collision |
| **VRX LiDAR Patch** | ✅ Done | `patch_vrx.sh` auto-fixes `publish_model_pose` |
| **Repo Cleanup** | ✅ Done | Dead code, legacy moves, package.xml audit, setup.py cleanup |

### A* Path Planning (Implemented)

```text
/perception/obstacles ────>┌─────────────────────┐
                    │  AStarSolver        │────> Detour waypoints inserted into /planning/waypoints
Current position ──>│  (in Planner)       │
                    └─────────────────────┘
```

- Occupancy grid (3m cells) with 8-connected A*
- **Hybrid Mode**: Pre-plan routes between lawnmower waypoints
- **Runtime Mode**: Plan detours when stuck or blocked

---

## 📚 Lessons Learned

| # | Lesson |
|---|--------|
| 1 | Cross-platform naming conventions are critical |
| 2 | TF tree configuration requires careful attention |
| 3 | Start simple, add complexity incrementally |
| 4 | Document early to reduce technical debt |

### Technical Debt

| Issue | Status | Description |
|:------|:------:|:------------|
| **ROS 2 Parameter Migration** | ✅ Done | Parameters now configurable via `autoboat.launch.yaml` |
| **Multi-Terminal Launch** | ✅ Done | `one_click_launch_all/launch_autoboat_complete.sh` available |
| **Debugging Required** | 🔄 In Progress | Complex planning and obstacle detection still need debugging |
| **Node Naming Refactor** | ✅ Done | One-shot atomic rename completed 16/04/2026 (OKO → `lidar_perception`, SPUTNIK → `waypoint_planner`, BURAN → `heading_controller`, Vostok1 → `AutoBoat`, vostok1_cli → `autoboat_cli`). See [wiki/Node_Naming_Refactor_Plan](wiki/Node_Naming_Refactor_Plan.md) for the full record. |

---

## 📜 Acknowledgments

**Document Version**: 9.7 | **Last Updated**: 22/04/2026

**Maintained By**: AutoBoat Development Team

**Institution**: [IMT Nord Europe](https://imt-nord-europe.fr/) — Industry 4.0 Students & Faculty
