# 📋 AutoBoat Development Board

[![Status](https://img.shields.io/badge/Status-Active-green)](https://github.com/Ghostzero00018/uvautoboat)
[![Progress](https://img.shields.io/badge/Progress-90%25-blue)](https://github.com/Ghostzero00018/uvautoboat)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

| | |
|---|---|
| **Project** | AutoBoat Navigation System |
| **Repository** | [Ghostzero00018/uvautoboat](https://github.com/Ghostzero00018/uvautoboat) |
| **Last Updated** | 05/05/2026 |
| **Status** | 🟢 Simulation ready (A* path planning + one-click launcher + wiki docs + dashboard config system + MP/QGC install). Real-hardware deployment prep ongoing — Pi 5 walked through 23/04/2026, bench delivery pending. |

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

Supervisor walked through the real AutoBoat central control unit (CCU) in person on 23/04/2026 — boat frame, control unit enclosure, battery, and a Raspberry Pi 5 inside the enclosure as the companion computer. Hardware not yet delivered to the intern's bench, but the target platform is now physically verified rather than specified-on-paper.

Expected two-tier control architecture:

- **High-level (confirmed, 23/04/2026 visual)**: Raspberry Pi 5 running ROS 2 Jazzy + this repo's nodes, LiDAR driver, GPS/IMU drivers, dashboard, shore comms.
- **Low-level (TBD — likely autopilot)**: Supervisor's 23/04 request to install **Mission Planner + QGroundControl** as the intended flight-control toolchain strongly suggests a MAVLink-speaking autopilot (ArduPilot or PX4) sits between the Pi 5 and the thrusters — MP and QGC both assume a MAVLink-compatible flight controller. The specific chip / firmware has not been confirmed; earlier STM32 mention remains speculative. Treat the autopilot-in-loop architecture as the **working hypothesis** pending supervisor confirmation; the alternative (Pi drives thrusters directly, MP/QGC installed only for future research work) stays on the table.

The whole repo is expected to run on the Pi 5. Long-term (Phase 5.2+): dashboard should issue waypoints and read telemetry **through MP/QGC as the autopilot front-end** rather than directly against ROS 2 nodes — requires a MAVLink bridge on the Pi 5 (`mavros` / `mavsdk` / similar) plus dashboard-side MAVLink emit/subscribe. Not scoped for Phase 5.0 bring-up.

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
| Supervisor conversation: confirm CCU architecture (is there a low-level controller? what chip? what firmware? any interface-control document?) | 🟡 checklist drafted; partial signal 23/04/2026 — MP/QGC request implies MAVLink autopilot in loop, specific chip / firmware still open |
| Install Mission Planner + QGroundControl on Linux workstation (prof-requested 23/04 toolchain) | ✅ 24/04/2026 — MP 1.3.9384.38258 + QGC stable-daily 09/10/2025; MP-under-Mono reaches main UI but GDAL / OGR / OSR fail (terrain + advanced geo-ref degraded — Windows `.msi` fallback held if prof needs GIS demos) |
| Spec shore-comms plan (WiFi range test, fallback to 4G) | ⬜ |

### Hardware-arrival tasks (requires CCU on-bench)

| Task | Status |
|------|:------:|
| Install Ubuntu 24.04 + ROS 2 Jazzy on Pi 5 | ⬜ |
| Build workspace on Pi 5 (native ARM64 build) | ⬜ |
| Wire bridge node to real low-level protocol (only if supervisor confirms a separate low-level controller) | ⬜ |
| Swap `/wamv/*` remaps to real driver topic names | ⬜ |
| Connect MP / QGC to the autopilot (MAVLink default `14550/udp`, or serial if USB-tethered); verify telemetry + waypoint upload before attempting dashboard integration | ⬜ |
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
| 23/04/2026 | Health-check count verify: runtime total **= 49 in both IDLE and ACTIVE** (IDLE: 49 PASS; ACTIVE: 41 PASS + 8 TUNED from applied presets). Matches `README.md:128` and `:236` claim exactly; no docs change needed | ✅ |
| 23/04/2026 | Dashboard shared-helpers consolidation: `scrollToEmergencyStop` 300 ms debounce (`03e5c2d`); `resetGroupToDefaults` helper extraction with thin wrappers (`11c5f95`); unified `debounceGroup(name, ms, fn, options)` helper absorbs `debounceCommand`/`debounceApply`/`debouncePreset` + camera refresh + E-Stop shortcut into single mechanism (`336fb28`, net –26 LOC) | ✅ |
| 23/04/2026 | Camera panel hardening (unplanned F+G blocks): same-topic Refresh no-op eliminates Mode B `web_video_server` deadlock vector (`560f9fe`, tear-down gap 200→500 ms); custom combobox with ▼ toggle + rosbridge `/rosapi/topics_for_type` auto-discovery replaces free-text topic input (`8c215e5`, hardcoded 3-camera fallback preserved; name-pattern filter drops zombie Image-typed LiDAR subscriptions) | ✅ |
| 23/04/2026 | Supervisor hardware walk-through: prof showed the real CCU in person — Pi 5 inside the control-unit enclosure (physically verified as companion computer). Prof-preferred toolchain **Mission Planner** (+ QGroundControl as cross-platform alt); signals a MAVLink autopilot in loop though specific chip / firmware not confirmed. Long-term ask: dashboard → MP/QGC as autopilot front-end (Phase 5.2+, post-bringup) | ✅ |
| 24/04/2026 | MP + QGC installed on Linux workstation per 23/04 ask (`qgc` + `missionplanner` in `~/.local/bin`; QGC AppImage in `~/Applications/`; Mono 6.8.0.105). MP 1.3.9384.38258 reaches main UI but GDAL / OGR / OSR DLLs fail under Mono (terrain / geo-ref degraded); QGC stable-daily 09/10/2025 clean. Windows `.msi` fallback held for GIS-heavy demos | ✅ |
| 24/04/2026 | `tools/rate_probe.py` — QoS-aware publisher-rate probe working around Jazzy's `ros2 topic hz` lacking `--qos-*` flag. Correctness validated against `/perception/obstacle_info` (both RELIABLE, rate_probe agrees with `topic hz` within noise at idle RTF). Jazzy-bug live demo deferred — no BEST_EFFORT publisher in the current stack (ros_gz_bridge publishes LiDAR points RELIABLE, contrary to the sensor_data-QoS assumption). `wiki/Common_Issues.md` gets a new QoS-aware rate-probing subsection + corrected Obstacle-Detection diagnostic block | ✅ |
| 24/04/2026 | Dashboard UX pass 2 (`9832793`): S1 Reset during Confirm (was silently disabled) now greyed via `.mission-btn-blocked` class and pops `🛑 Reset blocked — click Confirm or Cancel first` on click; S2 Go Home while at home now defended twice over (planner-side `go_home` at-home guard via `waypoint_tolerance` + dashboard client-side check before `sendMissionCommand`, both surface `🏠 Already at home (X.X m from spawn)`); S3 multi-click Joystick toggle already defended (state-gated button + 800 ms `debounceCommand`), no fix needed | ✅ |
| 28/04/2026 | Sunday pre-applied dashboard polish verified clean (`ffb7f8f` cli relative path, `74eb2b2` four `updateValueDisplay()` calls in programmatic-mutation paths, `888fadd` option-1 `param_ranges` 3-tuple chain — 43 `liveDefaults` entries arrive from all 3 nodes, `getCanonicalDefault` returns YAML-published defaults). Part 2 option-1 cleanup sweep landed (3 dashboard files, +85/-84): 15 HTML `data-default` attrs deleted, JS `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` constants removed, `resetGroupToDefaults` signature flipped to prefix-based, Reset buttons gated on per-namespace `liveDefaults` arrival. 4-place sync drift class for default values collapsed to 1-place — `autoboat.launch.yaml` is now sole source of truth | ✅ |
| 28/04/2026 | Cold-start JSON-serialization race fixed in `/control/anti_stuck_status` (`6ec20af`): inline `_safe()` maps `inf` / NaN → `None` in `publish_anti_stuck_status` and the dormant mirror at `publish_status` `obstacle_distance` (caught by class-instance sweep on `_publish_json` callers); init sentinels at L286-289 and the L968 gate left untouched. `wiki/Common_Issues.md` gains a `### Known Startup Warnings (Cosmetic)` subsection cataloguing 4 upstream categories (`kdl_parser` / `libEGL` / Gazebo Follow `(deprecated)` / VRX `WaveVisual` SDF) with origin + why-cosmetic + a `grep -vE` filter recipe (`134e52c`) | ✅ |
| 29/04/2026 | Cold-boot launcher validation: 28/04 readiness-poll patch (`2c0194a`) holds — fresh-reboot run shows all 5 expected nodes up, no `wait_for_*` timeout warnings, no fatal nav-stack tab exits. Side finding `wait_for_topic` SIGPIPE-trapped `ros2 topic info` (`grep -q` exits early on `Publisher count:` match, closing the pipe; `ros2cli` raises unhandled `BrokenPipeError` on the trailing `Subscription count:` print → Apport `_opt_ros_jazzy_bin_ros2.crash` popup; `set -e` without `pipefail` masked the failure so launcher proceeded). Fixed by capture-then-grep refactor in `wait_for_topic` (`62636e9`). Gazebo RTF throttle flagged out-of-scope (LiDAR `/points` ~2 Hz vs 10 Hz nominal; libEGL DRI2 fallback on NVIDIA RTX A2000 as working hypothesis), deferred to week of 04/05 | ✅ |
| 29/04/2026 | Launcher prints `Total launch time: N s (Mm Ss)` after success header (`3822e54`): `$SECONDS`-based bash arithmetic, total only (no per-stage breakdown). First observation post-feature-deploy: 52 s on the Linux workstation. Baseline data point for next week's RTF investigation cold-vs-warm comparisons | ✅ |
| 30/04/2026 | Block E cold-start re-test PASS (first fresh boot since `62636e9` capture-then-grep refactor in `wait_for_topic`): zero `BrokenPipeError` in `/tmp/autoboat_launcher_probe.log`, no new today-dated `/var/crash/_opt_ros_jazzy*.crash` (only pre-fix 29/04 crash file untouched), all 5 expected nodes up, no Apport popup. Launch time 43 s. SIGPIPE fix holds | ✅ |
| 30/04/2026 | Block D markdown + docstring cleanup pass (`2dfa650`): 3 classes bundled into one commit (+8 / -14 across 6 files). (a) docstring Subscribes/Publishes drift in `waypoint_planner.py` (+2 subs) and `heading_controller.py` (+1 sub / +2 pubs); (b) stale `Last Updated` stamps in `USER_MANUAL.md` (24/04→27/04) and `web_dashboard/autoboat/README_autoboat_dashboard.md` (24/04→28/04) bumped to last-edit dates; (c) 6 broken Next-Steps wiki cross-references in `Quick_Start.md` and `Installation_Guide.md` removed (`scripts/sync_wiki.sh` confirmed not to rewrite anchors — they were genuinely broken on the published wiki too). Verified clean: TODO inventory (1 well-formed forward-looking note), 16/04 rename residue (intentional historical), `*_DEFAULTS` residue (intentional historical), cold-start time + health-check count claims | ✅ |
| 30/04/2026 | Block F VRX upstream-fork scheme captured (`626ce96`): scheme-only entries in `Board.md` Timeline (new TBD row 🔜) and `wiki/Roadmap.md` §8 "Sim infrastructure — VRX upstream fork" with 5 subsections (today's baseline, trigger conditions, what forking won't solve, cost+alternatives, explicit "not now"). Revision log renumbered §8 → §9. Reserves the future fork-or-don't decision behind explicit triggers (patch count >3, custom mods upstream wouldn't accept, Phase 5+ sim-side dependencies, maintenance balance flip) so the call gets made on evidence | ✅ |
| 30/04/2026 | Internship scope locked at the on-site scoping meeting (smaller-scale than originally planned — campus power outage + IMT Mines Alès supervisor unavailable forced the on-site team to run its own session in place of the formal joint delivery): **Obj 1 = telemetry only** (boat → `mavros2` on Pi 5 → ROS 2 over IoT WiFi → VRX sim on Linux; water-sensor data belongs to Obj 2; MAVROS is the bridge, MAVProxy is a router not the bridge; DDS-multicast verification on IoT WiFi flagged as early-priority); **Obj 2 CA placement** most likely Linux-side; **Obj 3 regional-datasets portion REMOVED** (insufficient accessible regional data); **Obj 3 validation** refined to same-day cross-validation (R₁ train + R₂ holdout in one outing; no temporal confound) with day-gap return acceptable for slow-changing parameters only; **Obj 3 ML scope** refined (residual-based anomaly detection + time-series forecasting + physics-informed ML as stretch — "ML trained on CA outputs" framing rejected). Documented in `wiki/Roadmap.md` §1.1 + §1.2 + §6 Phase E refresh + §7 update note + §9 revision log; in `working_diary/2026-04-30_*.md` Block C outcome. Three open questions sent to teammate maintainer for confirmation: Phase A parameter subset, CA placement, validation methodology. Formal joint presentation rescheduled — date pending IMT Mines Alès availability + power restoration | ✅ |
| 30/04/2026 | Block H1 Pi 5 ↔ flight-controller bring-up smoke-test procedure documented (`wiki/Pi5_Bringup_Smoke_Test.md`, +new "🔌 Hardware Bring-up" section in `wiki/Home.md`, +row in Roadmap §3 status table): SSH + UART/dialout setup, MAVProxy install with PEP 668 caveat for Ubuntu 24.04, heartbeat verify, IMU smoke test via `stream_data.py` from team. 8 known issues catalogued (legacy `MAV_DATA_STREAM_*` API + 1 Hz IMU rate too slow + EXTRA1-vs-RAW_IMU mismatch on ArduPilot + missing heartbeat timeout + 4 others). Modern `MAV_CMD_SET_MESSAGE_INTERVAL` replacement provided in §7 + 4 other suggested fixes (drop redundant sleep, heartbeat timeout, argparse, explicit close). 5-step bring-up order (heartbeat → direct script → UDP fanout → mavros2 → simulator integration) captured to enforce one-layer-at-a-time debugging | ✅ |
| 30/04/2026 | Block H2 IoT IMT Nord Europe local-only network impact analysed (Roadmap §1.3, +Phase 5 status row "Dashboard offline-capable for IoT-local network deployment ❌", §9 revision log entry): the IoT network is institutional/IoT-only with no internet, but the dashboard currently loads 4 internet-runtime deps — `roslib` from jsdelivr (`index.html:18`), Leaflet JS+CSS from unpkg (`index.html:21, 24`), OSM tiles (`app.js:342`), Google Fonts in `style_merged.css:4`. Without internet, (1) and (2) are **critical** (kill core dashboard + map respectively), (3) is critical for map background, (4) is cosmetic. Three mitigation paths captured (A: vendor libs locally — removes 3/4 deps; B: offline tile server with pre-generated MBTiles; C: map-less fallback mode as third-tier backup). Recommended order: A immediately (network-independent hardening, ~2 MB vendored), B before first on-water deployment, C optional. Dashboard README troubleshooting + `wiki/Common_Issues.md` + `USER_MANUAL.md` cross-linked to §1.3 for the durable analysis | ✅ |
| 04/05/2026 | Post-Labour-Day cold-boot sanity (Blocks A/B/C): launcher 43 s, 0 `BrokenPipeError`, all 5 nodes up — `62636e9` SIGPIPE fix + `2c0194a` readiness gates hold across the weekend; 30/04 visualizer JSON-warn verified silent under normal mission + fires on malformed publishes (with `--rate 2 --times 5` workaround for the `--once` BEST_EFFORT-vs-RELIABLE discovery race); GitHub Action propagated the 30/04 wiki commits over the weekend, local-side spot-check on Dashboard_Security / README_WIKI / Roadmap §1.3 markers all clean | ✅ |
| 04/05/2026 | Gazebo RTF throttle root cause + fix (Block D, deferred from 29/04): hardware drift catch first — `nvidia-smi` reports **RTX A3000 Laptop GPU** not A2000 (same Ampere driver line so hypothesis structure unchanged). Real cause was `prime-select on-demand` routing Gazebo to Mesa Intel UHD (TGL GT1) iGPU despite the discrete NVIDIA driver loading cleanly — `gpu_ray` LiDAR raycasting was iGPU-bound. Fix: `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` env-prefix on `bash one_click_launch_all/launch_autoboat_complete.sh` (env vars propagate cleanly through `gnome-terminal --tab -- bash -i -c "..."` chain). A/B numbers: `/points` 2.48 → 6.8 Hz on the full launcher (2.7×; 8.95 Hz / 3.6× standalone), `/clock` 80.9 → 219.7 Hz, RTF **0.32 → 0.88** (2.7×). `nvidia-smi pmon` confirms `gz sim server` + `gz sim gui` + `rviz2` all on GPU 0. CPU governor `powersave` flagged as remaining ~10–15 % RTF gap (D3, needs sudo, deferred). `wiki/Common_Issues.md` "Gazebo Running Slow" section rewritten with diagnostic flow + measured table + Pi 5-unaffected caveat. Open question for the maintainer: bake env vars into the launcher (auto / `--use-nvidia` flag / leave manual) — flagged in diary, code change deferred | ✅ |
| 05/05/2026 | Pre-field-test Block B sim verification (A=pending weather): warm `--use-nvidia` launch (44 s) → 5/5 nodes, 0 `BrokenPipeError`, 0 fresh `/var/crash/_opt_ros_jazzy*`. Mission cycle FINISHED 16/16 waypoints (100 %, 405 s sim @ RTF 0.88) via `autoboat_cli generate/confirm/start`. Rosbag dry-run: 14 topics requested, all subscribed at start; 79 080 messages / 21.5 MiB / 351.7 s; 12 non-empty (IMU ~89 Hz, thrusters ~21 Hz each, GPS ~18 Hz, mission_status 5 152, obstacle_info 4 320, current_target 3 391, anti-stuck 702, waypoints 3); `/planning/emergency_stop` 4 of 5 fan-published captured (recordability proven); `/health_check/*` advertised-only, 0 captured (scaffold L108 alternative criterion). `metadata.yaml` not flushed on backgrounded SIGINT — recovered via `ros2 bag reindex`. Pre / post health_check 49 / 46 PASS + 3 TUNED + 0 FAIL. B3 TBD list replaced with concrete fill-in form across 7 categories. B4 VRX §8.2 triggers re-checked: 0/4 still hold, HOLD stands. AM scope refinement recorded: even if A=GO, today's wet test is first-bring-up only (D1 + D2; D3-D5 + autonomy `/planning/emergency_stop` latching + full autonomy-stack network validation deferred — teleop stop/cutoff and a network smoke check stay mandatory) | ✅ |
| 05/05/2026 | `--use-nvidia` discoverability follow-up landed (deferred from 04/05 Block D open question): 5 user-facing docs annotated for hybrid-graphics laptop users (Optimus / PRIME) — `README.md` Quick Start callout, `wiki/Quick_Start.md` parallel callout, `USER_MANUAL.md` flag example added to one-click-launch code block + combine line includes `--use-nvidia`, `web_dashboard/autoboat/README_autoboat_dashboard.md` callout, `wiki/Common_Issues.md` inline annotation in the rebuild-recipe at L396 forward-pointing to "Gazebo Running Slow". +83 / -11 across 5 files. Manual env-prefix fallback at `wiki/Common_Issues.md:594-595` left untouched by design (older-checkout / one-off `ros2 launch` equivalent). Pre-commit invisibility sweep clean | ✅ |
| TBD | Real-hardware deployment (Pi 5 as confirmed target, visual-verified 23/04/2026; MAVLink autopilot as working hypothesis; low-level CCU architecture TBD) | 🔜 |
| 06/05/2026 | VRX upstream fork landed: `Ghostzero00018/vrx` with LiDAR `publish_model_pose` bake-in (issue #876) committed to the fork's `jazzy` branch (commit `e384cd65`); `patch_vrx.sh` retained as idempotent no-op safety net for ≥2 release cycles. Reference-surface migration: 5 install/clone URLs swapped (`README.md:62`, `USER_MANUAL.md:357`, `wiki/Installation_Guide.md:51 + 55 + 94`) + 1 dual-link entry (`USER_MANUAL.md:346`) rewritten with both arrows; 9 attribution / canonical-project links to `osrf/vrx` preserved. Two remotes set up locally — `origin` = fork, `upstream` = `osrf/vrx`. Two-branch model on the fork: `jazzy` (upstream-tracking + bake-ins) and `autoboat/main` (workspace-consumed branch where future inside-VRX mods land — mesh adds/removes, sensor-config tweaks, etc.). Scope-expansion override of `wiki/Roadmap.md` §8.5 "explicit not now" — at fork time, 0/4 §8.2 triggers had fired; original framework preserved as audit trail; new §8.6 Migration log + §8.7 Upstream sync workflow added | ✅ |
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
/perception/obstacle_info ────>┌─────────────────────┐
                        │  AStarSolver        │────> Detour waypoints inserted into /planning/waypoints
Current position ──────>│  (in Planner)       │
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

**Document Version**: 9.9 | **Last Updated**: 05/05/2026

**Maintained By**: AutoBoat Development Team

**Institution**: [IMT Nord Europe](https://imt-nord-europe.fr/) — Industry 4.0 Students & Faculty
