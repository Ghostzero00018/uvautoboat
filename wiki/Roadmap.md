# Project Roadmap

> **Status:** living document. Phases beyond the navigation foundation are research extensions tied to the internship's water-quality / digital-twin objectives. Revise as supervisor conversations, hardware timelines, and dataset access resolve open questions.
>
> **Audience:** intern, supervisors (A. Shehu, G. Zacharewicz), collaborators reviewing scope before committing resources.

---

## 1. Internship objectives (reference)

From the formal objectives document *"Aquatic Drone–Based Digital Twin for Spatio-Temporal Water Quality Monitoring"* (IMT Nord Europe × IMT Mines Alès):

1. **Data integration** — stream real sensor data from the drone into the simulator via the ROS ecosystem.
2. **Spatio-temporal modeling** — implement computational models (e.g., cellular automata) that simulate the evolution of key water quality parameters using drone-streamed data, displayed as a water quality map within the existing dashboard interface.
3. **Validation & prediction (time-permitting)** — validate generated maps against regional datasets (CESER, CPER ECRIN, VERD-Eau, CASTREau, CAP'Eau); propose ML techniques for trend prediction and anomaly detection.

Scientific community fit: RMC2 — modeling, control, and communication of complex systems.

### 1.1 Scope clarifications (locked 30/04/2026)

The 30/04 supervisor + teammates scoping meeting — held at smaller scale than originally planned, since a campus power outage and the IMT Mines Alès supervisor's unavailability forced the on-site team to run its own session — clarified each formal objective:

**Obj 1 — "real sensor data from the drone".** Scope = boat **telemetry** (GPS, IMU, velocity, etc.) flowing from the low-level controller through the Pi 5 (ROS 2 Jazzy on aarch64 Linux, on the *IoT IMT Nord Europe* network; Pi 5 OS posture verified 22/05/2026 after the prof's reflash: Ubuntu Desktop 24.04.4 LTS Noble, `linux-raspi` 6.8.0-1056, GNOME on Mutter / Wayland, hostname `imtaquadrone-desktop`) into the VRX simulator on the Linux workstation. Water-quality sensor data is **not** part of Obj 1 — it belongs under Obj 2. Both streams ultimately reach the simulator, but Obj 1 owns only the telemetry plumbing. The simulator mirrors the real boat's pose; this is the digital-twin baseline. See [Digital_Twin_Architecture](Digital_Twin_Architecture) for the standards-positioning rationale — ISO/IEC 30141:2024 as the domain-neutral IoT reference architecture, ISO 23247:2021 (Parts 1-4) as a worked manufacturing instantiation, and this project as an aquatic environmental adaptation of the layered pattern.

Architecture inside Obj 1:

- **MAVLink ↔ ROS bridge on the Pi 5.** `mavros2` (the ROS 2 port of MAVROS) translates MAVLink frames from the low-level controller into ROS topics; ROS commands flow the other way. **MAVProxy is *not* the bridge** — it is a MAVLink router/multiplexer for fanning out to additional ground-control tools (QGroundControl, Mission Planner) when needed. The two are easy to confuse and have been in the project's discussion notes.
- **Pi 5 ↔ Linux workstation via ROS 2 / DDS** over the shared IoT WiFi. Direct topic discovery once both nodes share the same `ROS_DOMAIN_ID`. **Caveat:** corporate IoT networks frequently block multicast (DDS's default discovery transport) or isolate WiFi clients. This must be verified early with a basic `talker` / `listener` round-trip before serious pipeline work — verified WORKS on `IoT IMT Nord Europe` 12/05/2026 (see `working_diary/2026-05-12` Block B.1); re-run on any future network. Workarounds if multicast fails: Fast-DDS Discovery Server (unicast), Cyclone DDS peer list, or direct Ethernet during testing.

Design implications worth tracking explicitly (so the digital-twin framing carries weight in the eventual report):

- **Sim physics state when the real boat is connected.** Decide whether the simulator's physics step still runs in parallel with the real boat (so sim-predicted vs real-observed pose can be compared, surfacing model error) or whether it freezes and merely renders the real pose. Recommendation: run both; expose a launch flag.
- **Topic remapping.** The current sim publishes `/wamv/sensors/gps/gps/fix` etc.; `mavros2` publishes `/mavros/global_position/global` etc. Downstream planner / controller / dashboard need to read from either source transparently. The existing `launch/remap.launch.yaml` is the home for this; worth a focused pass before Pi 5 hardware lands.
- **Digital-twin value beyond mirroring.** Mirroring the real boat alone adds nothing the boat cannot do. Value comes from sim-side computation the real boat cannot perform: predict-ahead (run sim faster than real-time on current commands), what-if (alternative commands from current state), the eventual water-quality CA heatmap overlay (Obj 2). Worth being explicit about which of these is claimed for the deliverable.

**Obj 2 — CA model compute placement.** Most likely **Linux-side**, not on the Pi 5: more compute headroom, easier dashboard integration, less contention with the boat-side control loop. Pending explicit confirmation in the next supervisor exchange.

**Obj 3 — "regional datasets" portion REMOVED.** Accessible historical data for the project's region (CESER / CPER ECRIN / VERD-Eau / CASTREau / CAP'Eau) is insufficient or not available. Validation is replaced by **same-day cross-validation**: collect partial-coverage data along two routes R₁ + R₂ in a single outing; hold out R₂; train the CA on R₁ only; predict R₂ from CA; compare predictions to the held-out R₂ measurements. No temporal-change confound on the model error. A few-days' return visit is acceptable for slow-changing parameters (conductivity in a stable closed lake) but not for dynamic ones (DO post-rain, turbidity post-disturbance) — the original meeting interpretation of "navigate one route on day 1, return on day 2-3 with a different route, compare to day-1 prediction" was refined to surface this temporal-confound issue.

**Obj 3 — ML scope refinement.** The meeting initially discussed "training an ML model deriving from the CA function" for anomaly detection; this was refined since training ML on CA outputs just relearns the CA and adds no information. Refined approach (still scoped as "if time permits"):

- **Residual-based anomaly detection** — flag measurements where `|real − CA-predicted|` exceeds a threshold. Statistics on top of CA; light-touch and fastest to implement.
- **Time-series forecasting** — ARIMA / Prophet / LSTM on collected measurement sequences for trend prediction.
- **Physics-informed ML (stretch)** — use CA as a physics prior; train ML to predict the residual between CA and reality. Learns the CA's systematic blind spots; most interesting research-wise.

### 1.2 Open questions surfaced 30/04 (sent for teammate input)

Three architectural questions raised in the 30/04 meeting and sent in writing to the teammate maintainer for confirmation ahead of the next supervisor exchange:

1. **Phase A water-quality parameter subset** — full set (pH, DO, turbidity, conductivity, temperature, …) or a smaller subset? See §5.3(a).
2. **CA model compute placement** — Linux workstation (recommended) or Pi 5? See §1.1 above.
3. **Validation methodology** — same-day cross-validation (recommended) or a few-days' return visit? See §1.1 above + §6 Phase E.

<a id="13-iot-imt-nord-europe--local-only-network-constraint-analysed-30042026"></a>

### 1.3 IoT IMT Nord Europe — managed-egress / offline-map constraint (analysed 30/04/2026; corrected 13/05/2026)

**Constraint.** The IoT IMT Nord Europe network is institutional / IoT-managed, not a normal open campus internet link. The 30/04 working assumption was "local-only / no internet"; the 13/05 Pi-side pre-flight refined that: from the pre-reflash Pi (`10.120.2.50/23`; post-22/05 reflash DHCP reassigned the Pi to `10.120.2.162/23`), IPv4 DNS resolved `archive.ubuntu.com` and `curl -4 -sI http://archive.ubuntu.com/ubuntu/` returned `HTTP/1.1 200 OK`, while public ICMP to `1.1.1.1` was blocked. Treat this as **partial managed egress**: apt HTTP egress worked for that Pi-side test, but general internet, workstation-side internet while attached to the IoT SSID, and OpenStreetMap tile availability must not be assumed. Pi 5 ↔ Linux workstation traffic stays on the IoT LAN for ROS 2 / SSH / RDP. The original dashboard design implicitly assumed open internet; Path A (05/05/2026) removed the library/font dependencies, while Path B remains required for deterministic offline map tiles before IoT-network deployment.

#### Runtime dependency status after Path A

Inventoried 30/04/2026 across `web_dashboard/autoboat/`; Path A landed 05/05/2026.

| # | Source before Path A | Current source | Function | Severity when external internet / tiles are unavailable |
|:-:|:---------------------|:---------------|:---------|:------------------------------|
| 1 | `cdn.jsdelivr.net/npm/roslib@1` (`index.html:18` before Path A) | `vendor/roslib/roslib.min.js` | rosbridge WebSocket JS client | **Resolved by Path A** — dashboard core connection no longer depends on internet |
| 2 | `unpkg.com/leaflet@1.9.4` JS + CSS (`index.html:21, 24` before Path A) | `vendor/leaflet/` | Map rendering library | **Resolved by Path A** — Leaflet loads locally; map overlays can render without internet |
| 3 | `tile.openstreetmap.org` (`app.js:354`) | unchanged external tile server | Map background tiles | **Still open** — map area renders empty grey without internet; boat marker / waypoints / path overlay still draw on top, but with no geographical context |
| 4 | Google Fonts — Roboto Condensed (`style_merged.css:4`) | `vendor/google-fonts/roboto-condensed.css` + local WOFF2 files | Typography | **Resolved by Path A** — fonts load locally |

**Combined impact after Path A.** If external internet or the OSM tile endpoint is unavailable, dashboard core functionality (telemetry, mission control, health check) and the Leaflet map library still load. The remaining blocker is map background context: OSM tiles are still external, so IoT / restricted-egress deployment needs Path B (offline tile server + pre-generated MBTiles for the test area) before the first field deployment that depends on the map panel.

#### Mitigation paths

Three options, ordered by recommended priority.

##### Path A — Vendor libraries locally (low effort, removes 3 of 4 deps)

Done 05/05/2026: `roslib.min.js`, `leaflet.js`, `leaflet.css`, Leaflet images, and the Roboto Condensed font files were committed under `web_dashboard/autoboat/vendor/` and referenced via relative paths.

```html
<!-- Local vendored copies -->
<script src="vendor/roslib/roslib.min.js"></script>
<script src="vendor/leaflet/leaflet.js"></script>
<link rel="stylesheet" href="vendor/leaflet/leaflet.css">
```

- **Cost:** ~516 KB of vendored assets in the repo.
- **Removes:** dependencies (1), (2), (4) — three of the four.
- **License compliance:** Leaflet (BSD-2), roslib (BSD-3), Roboto (Apache 2.0) — all compatible with the project's Apache 2.0 license. Add a `vendor/LICENSE_NOTICES` file copying the upstream license texts.
- **SRI integrity hashes:** dropped 05/05/2026 when the CDN loads were replaced with same-origin vendored files; the CDN-compromise vector is gone.
- **Not just for IoT.** This is hardening worth doing regardless — removes any runtime jsdelivr / unpkg / Google Fonts outage from blocking the dashboard.

##### Path B — Offline tile server (required for map functionality on IoT)

Run a local tile server on the Linux workstation; pre-generate tiles for the operating area before deployment. Removes dependency (3).

Options:

- **TileServer GL + MBTiles** — pre-render tiles at zoom 12-18 for the test-site bounding box; serve via a small Docker container or Node process. ~50-200 MB per area depending on zoom range and area size.
- **`tilemaker` + `martin`** — generate MBTiles from raw OSM extracts (`.osm.pbf` from Geofabrik); serve via `martin`.
- **`Leaflet.OfflineMap` plugin** — caches tiles in browser `localStorage` on first internet access; doesn't help if the workstation has never had internet on the test network.

Pre-deployment workflow:

1. Identify lake / test-site geographic bounds.
2. Download OSM extract for the region (Geofabrik regional `.osm.pbf`).
3. Generate MBTiles via `tilemaker`.
4. Copy MBTiles to the workstation.
5. Run tile server (e.g., `martin tiles.mbtiles`).
6. Update `app.js:354` `L.tileLayer(...)` URL to `http://localhost:<port>/tiles/{z}/{x}/{y}.png` (or make it a launch parameter).

For Phase 5 deployment on the IoT network, this path is **mandatory** if the map panel must work reliably without depending on external tile egress.

##### Path C — Map-less fallback mode (optional, ~200 LOC)

Add a launch flag (e.g., `--offline-map`) that:

- Skips Leaflet initialization entirely
- Replaces the map panel with a Cartesian XY plot of the boat's trajectory + waypoints in the local frame (no geographic background)
- All other panels work normally

Useful as a third-tier backup when even the local tile server is unavailable. Lowest priority — Path A + B should suffice for normal operation.

#### Recommended approach for Phase 5 deployment

1. **Path A first**, before any deployment — ✅ landed 05/05/2026; vendored (1), (2), (4). Network-independent hardening.
2. **Path B before first on-water deployment** — offline tile server + pre-generated tiles for the test-site area.
3. **Path C optional** — keep as a documented backup, do not implement until Path B has been tried and found insufficient.

#### Tracker

Status row in §3 Phase 5 status table now records Path A landed 05/05/2026 and Path B still future. `web_dashboard/autoboat/README_autoboat_dashboard.md`, `wiki/Common_Issues.md`, and `USER_MANUAL.md` now distinguish missing vendored assets from the remaining OpenStreetMap tile dependency.

---

## 2. Current state (foundation baseline 24/04/2026; later deltas appended in §3 status table + §1.1 / §1.3 30/04 entries)

### Navigation foundation — ready for hardware

| Layer | Status |
|:------|:------:|
| Perception (3D LiDAR → obstacle info, temporal filtering, VFH) | ✅ |
| Planning (lawnmower + A\* detour) | ✅ |
| Control (PID + Kalman drift compensation + micro-reverse escape) | ✅ |
| Dashboard (Leaflet map + telemetry + 3-panel config + health check) | ✅ |
| Simulation (VRX, `sydney_regatta_DEFAULT` world) | ✅ |
| Safety (latched E-Stop, `std_srvs/Trigger` ACK services) | ✅ |

### Research layers — current bounded status

| Layer | Status |
|:------|:------:|
| Water-quality sensor streaming (ROS topic contract) | ❌ |
| Cellular-automata spatio-temporal model | Synthetic CA/MCMC prototype completed and evidenced externally (final RMSE 0.0063; mean acceptance 53.3%). ROS 2, field-data, and operational digital-twin integration remain not started. |
| Water-quality map visualization in dashboard | ❌ |
| Real probe integration | ❌ (blocked on hardware) |
| Regional dataset validation | ❌ removed from scope 30/04/2026 — accessible regional historical data insufficient; replaced by same-day cross-validation. See §1.1 + §6 Phase E. |
| ML for trend / anomaly detection | ❌ (time-permitting) |

---

## 3. Phase 5 — Real-Hardware Deployment

> **Canonical detailed reference:** `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` — /wamv/\* topic inventory, `remap.launch.yaml` paper design, bridge-node pseudocode, 24-item supervisor CCU checklist. Pre-execution scope plan; the topic inventory and remap design still stand (`remap.launch.yaml` shipped 22/04/2026). The 23/04/2026 supervisor walk-through narrowed the bridge-node target toward a MAVLink-speaking autopilot and partially answers the CCU checklist — see the Summary bullets below for the current working hypothesis.

### Summary

- **High-level CCU (confirmed):** Raspberry Pi 5 on Ubuntu Desktop 24.04.4 LTS Noble, `linux-raspi` 6.8.0-1056, aarch64, ROS 2 Jazzy — Tier 1 per REP-2000. 22/05/2026 reflash verification: ROS 2 Jazzy base pre-installed by the prof, `mavros` Route 1 apt install green, GNOME on Mutter / Wayland for the full-DE image, hostname `imtaquadrone-desktop`, IoT IP `10.120.2.162/23`.
- **Low-level CCU (TBD — likely autopilot):** Supervisor's 23/04/2026 request to install Mission Planner + QGroundControl strongly suggests a MAVLink-speaking autopilot (ArduPilot or PX4) sits between the Pi 5 and the thrusters — both GUIs assume a MAVLink-compatible flight controller. The exact board and firmware version remain open, but a professor photo sent on 03/06/2026, with the Pi desktop clock showing Tue 02/06/2026 22:09 capture time, shows MAVProxy receiving ArduPilot `AP: EKF3 waiting for GPS config data` status text on `/dev/ttyAMA0`; this gives the first concrete ArduPilot-side signal. Alternative paths (Pi drives thrusters directly via GPIO PWM, or a non-MAVLink microcontroller as earlier hypothesised) remain logically possible but lower-probability given the 23/04, 20/05/2026, and 02/06/2026 late-evening signals. **20/05/2026 supervisor presentation reinforced the Pi 5 MAVLink ingestion direction**: autopilot / boat telemetry should be exposed as ROS 2 topics, with `mavros2` / MAVROS as the direct MAVLink-to-ROS bridge route; MAVProxy remains routing / fanout tooling. **04/06/2026 update:** the evidenced `/dev/ttyAMA0:57600` endpoint now also passes through MAVROS via MAVProxy UDP fanout: `/mavros/state` returned `connected: true`, MAVROS reported ArduPilot heartbeat, and first ROS samples were captured from IMU, raw GPS (no fix), battery, and RC topics. **26/06/2026 caveat:** after a box shutdown/relaunch with the usual startup music/sound missing, a camera-off MAVProxy check opened `/dev/ttyAMA0:57600` but no heartbeat arrived and MAVProxy reported `link 1 down`; at the 26/06 close this was treated as a physical power/wiring issue to inspect on Tuesday 30/06/2026 before rerunning MAVProxy/MAVROS, not as a Route 1 install regression. Remaining integration risks are GPS fix / EKF GPS configuration, targeted request/response timeouts, command-path mapping, physical wiring reliability, and dashboard / simulation topic adaptation.
- **15/07/2026 live read-only update:** a logged bench run supersedes the 26/06
  heartbeat failure as the current endpoint observation. MAVProxy detected the
  vehicle on `/dev/ttyAMA0:57600`, minimal MAVROS connected while disarmed, and
  the workstation dashboard displayed state, raw GPS, IMU, battery, and RC
  while the stock-COCO Hailo overlay streamed. GPS fix, endurance, production
  mode selection, and dashboard-to-FCU command/write validation remain open.
- **17/07/2026 tracked live-demo update:** two bounded runs on
  `IoT IMT Nord Europe` again passed MAVProxy heartbeat and MAVROS
  `connected: true`, armed `false`; the 26/06 link-down is therefore historical,
  not the current endpoint state. All six expected topics arrived with messages.
  During both runs, the operator confirmed the combined stock-COCO overlay and
  telemetry browser view, and the command sentinel observed zero messages
  on its five monitored command topics.
  Automatic probes measured Hailo at `7.40 Hz` and `7.50 Hz` and each MAVROS
  feed near `1 Hz`. Pi thermal peaks were `68.3 C` and `67.2 C`, and both Pi log
  directories were copied back. In each run the workstation dashboard stack
  became unavailable unexpectedly before the intended Pi-first stop, without
  deliberate operator intervention; fail-closed teardown passed. That cause
  remains open. Normal Pi-first shutdown and post-teardown temperature were
  subsequently obtained on 03/08/2026 and repeated on 04/08/2026; see the
  supervisor row in the status table below. Browser-last ordering, full
  endurance, optimized transport, GPS fix, and all FCU writes remain open.
- **Transition path:** paper design is a two-layer remap — `topic_tools/relay` from VRX `/wamv/*` names to neutral `/sensors` / `/actuators` names (layer A), plus an optional bridge node for real-hardware protocol translation (layer B). The three pipeline nodes continue to subscribe to VRX names during Phase 5.0; no code churn required until layer A is proven.
- **Phase 5.2+ dashboard / QGC mission integration (longer-term, prof request 23/04):** QGC and the web dashboard should act as peer mission editors for one mission authority, with mission data exchange bridged through MAVLink while water-quality data remains dashboard-only. The current 11-12/06 workstation bridge is narrower: same-machine visual QGC display from dashboard Generate -> Confirm works, but same-session auto-refresh is not supported, manual Plan View download was not proven in clean local QGC, and reconnect/relaunch is the only proven v1 refresh workaround. QGC mission upload, bidirectional sync, real FCU upload, and command/write validation remain gated future work outside Phase 5.0 bring-up.

### Status of prep tasks (baseline 24/04/2026; rows added 30/04/2026 for bring-up doc + IoT-local dashboard prep)

| Task | Status |
|:-----|:------:|
| `/wamv/*` reference inventory across Python / YAML / JS / HTML | ✅ done (in scope plan) |
| `remap.launch.yaml` paper design + runnable file | ✅ deployed 22/04/2026; 6 relays + conditional bridge stub |
| Bridge-node pseudocode with pass-through behaviour | ✅ drafted |
| Supervisor CCU checklist (24 questions) | ✅ drafted |
| Launcher readiness polls (pre-requisite for Pi 5 slower-CPU timing) | ✅ landed 20/04/2026 |
| Profile `/perception/obstacle_info` Hz in VRX; baseline for Pi 5 comparison | ✅ 20.00 Hz at RTF ≈ 1.0 (22/04/2026); rate tracks Gazebo RTF |
| Install Mission Planner + QGroundControl on Linux workstation (prof-requested toolchain) | ✅ 24/04/2026 — MP 1.3.9384.38258 + QGC stable AppImage 09/10/2025; MP-under-Mono GDAL / OGR / OSR degraded (Windows `.msi` fallback held for GIS demos). **11/05/2026 update**: MP-Linux video panel + arm/disarm path unblocked via host-local SkiaSharp 2.88.8 + `libdl.so` symlink fix (see `wiki/Common_Issues.md` MP-Linux entry). **12/05/2026 diagnosis**: GDAL/OGR/OSR still degraded because MP bundles Windows PE native wrappers, not Linux `.so`; not the same musl→glibc class as SkiaSharp. **10/06/2026 update**: offline dashboard-cache -> QGC `.plan` conversion was added in `tools/qgc_plan_from_dashboard.py` and QGC Plan-view import was accepted on the workstation (5 cached waypoints -> 5 mission items, home at the exported Sydney Regatta origin, and route geometry matching the dashboard). **11/06/2026 update**: live local dashboard/planner -> QGC visual bridge accepted via `tools/qgc_live_mission_bridge.py`; after Generate -> Confirm, QGC pulled 7 mission items from the simulated bridge vehicle over `127.0.0.1:14550` and displayed the route matching the dashboard without `.plan` import or mission-folder write. **22/06/2026 update**: workstation QGC on the Herelink hotspot showed read-only telemetry while bound to UDP `14550`, including the known `EKF3 waiting for GPS config data` state. A 16:07 packet capture identified unicast MAVLink from `192.168.43.1:52600` to workstation `192.168.43.160:14550`; the terminal summary reported 100 captured packets and 0 kernel drops. MAVLink transport to workstation QGC is proven, but the MAVROS / ROS 2 fork remains open; next read-only test should keep QGC on `14550` and use QGC MAVLink forwarding to a separate local port before trying a workstation MAVProxy/router. Vehicle waypoint upload remains separate command/write-path work. |
| Pi 5 ↔ flight-controller bring-up smoke-test procedure documented | ✅ 30/04/2026 — see [Pi5_Bringup_Smoke_Test](Pi5_Bringup_Smoke_Test): SSH + UART + dialout setup, MAVProxy install (with PEP 668 caveat for Ubuntu 24.04), heartbeat verify, `stream_data.py` IMU smoke test with 8 known issues catalogued + suggested fixes |
| Pi 5 ↔ workstation DDS cross-machine discovery on `IoT IMT Nord Europe` | ✅ 12/05/2026 — verified with Pi-side `/pi5_dds_probe` publisher and workstation-side `ros2 topic echo --once`; discovery + transport both work. Standard ROS 2 graph discovery is sufficient for Phase 5 driver bring-up; Fast-DDS Discovery Server unicast config not required for this WiFi |
| Dashboard offline-capable for IoT / restricted-egress deployment | 🔄 path A landed 05/05/2026 (vendored `roslibjs` + Leaflet + Google Fonts under `web_dashboard/autoboat/vendor/`, ~516 KB; dashboard now CDN-free for the 3 main lib deps); path B (offline tile server, pre-generated MBTiles for test area) still future and required before relying on the map panel during IoT-network deployment. |
| Shore-comms plan (WiFi range test, 4G fallback) | ❌ |
| Pi 5 power budget for RealSense + co-loads | 🔄 13/05/2026 + 27/05/2026 + 05/06/2026 + 10/06/2026 — 13/05 mitigation was Pi 5 on its own USB-C charger separate from the main 14.8V LiPo battery rail; brownout root-cause identified for prior "sleep" symptoms as PMIC under-voltage shutdown at ~4.63 V under RealSense streaming load via 5V-GPIO-pin power. On the post-reflash Ubuntu Desktop image, a Pi 5 low-voltage warning reappeared during the D435i combined color/depth/IMU attempt; IMU-only later worked, so that mitigation may not be sufficient under full combined load. On 05/06, the MAVROS-only precheck log showed repeated Pi undervoltage before the RealSense step, and the user observed Pi shutdown when launching the RealSense node. On 10/06, a narrow camera + MAVROS combined window showed topic/node coexistence plus `/mavros/state connected: true` and no fresh pasted under-voltage / throttling tail, but the run did not capture combined camera Hz or combined IMU/GPS/battery samples, temp reached 82.6 C, and the live dmesg watcher was not kept running throughout. Permanent Phase 5 fix remains hardware-side: regulated ≥5A dedicated 5V supply, thick-short GPIO leads (or proper USB-C input), bulk capacitance near Pi power input, possibly a powered USB hub between Pi and RealSense to fully decouple current spikes. |
| RealSense → ROS bridge via `realsense2_camera_node` | 🟡 13/05/2026 + 27/05/2026 + 28/05/2026 + 05/06/2026 + 10/06/2026 + 18/06/2026 + 24/06/2026 + 25/06/2026 + 26/06/2026 — 13/05 headless-image run validated the predicted dedicated Pi-side ROS bridge and full topic surface. 27/05 post-reflash Ubuntu Desktop retest from Remmina confirmed `realsense2_camera_node` v4.57.7 / LibRealSense v2.57.7 still detects Intel RealSense D435I serial `213622070342`, FW `5.14.0`, USB type `3.2`, and publishes color/depth ROS topics (`/camera/camera/color/image_raw`, `/camera/camera/depth/image_rect_raw`, camera-info, metadata, depth-to-color extrinsics). Evidence samples: color camera info `1280x720`, depth camera info `848x480`, color image about 15-18 Hz, depth image about 26-27 Hz. IMU-only launch also publishes `/camera/camera/imu`, `/camera/camera/accel/sample`, and `/camera/camera/gyro/sample`, with a valid `/camera/camera/imu` sample captured. 28/05 Pi-local viewer check installed `ros-jazzy-rqt-image-view` and `ros-jazzy-rviz2`; color-only launch opened `/camera/camera/color/image_raw` as `RGB8 1280x720x30`, displayed in both `rqt_image_view` and RViz2, and RViz2 reported OpenGL `3.1`. On 10/06, default `rs_launch.py` opened color + depth on serial `213622070342`, `/camera/camera/color/image_raw` averaged `18.341` Hz during the camera-only proof, `rqt_image_view` displayed live video, and Pi-local `web_video_server` served the same image topic over MJPEG. On 18/06, `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 exposed `/camera/camera/color/image_raw` over `ROS_DOMAIN_ID=12`; workstation DDS discovery required `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, and the workstation dashboard displayed the Pi RealSense feed through loopback-only rosbridge / `web_video_server` / dashboard services. The practical dashboard profile was `enable_depth:=false rgb_camera.color_profile:=424x240x15`, with a clean workstation receive sample near `14.8-15.0` Hz after other subscribers were stopped. A full simulated out-and-return-home mission also appeared to run normally while the dashboard Camera panel showed the RealSense feed. On 24/06, a camera-only YOLO dataset-readiness check reused the `424x240x15` RGB profile without dashboard, MAVROS, QGC, Herelink, or live inference; workstation DDS saw publisher count `1`, RELIABLE / TRANSIENT_LOCAL QoS, and about `15 Hz`, while Pi temperature and dmesg stayed clean (`68.85-72.7 C`, no undervoltage / throttle evidence). On 25/06, a bounded ROS-camera-node fallback procedure used the same `RGB8 424x240x15` topic and held camera-only flow around `14.939-15.012` Hz before feeding frames to the custom NCNN model; F2 processed 30 live frames in `10.4 s` before the intended `80.0 C` thermal abort fired at `80.95 C`. On 26/06, SSH/headless retesting separated the Remmina / desktop-session confound from deployment load: no-camera floor was `51.25-54.00 C` (mean `52.19 C`), camera-on / no-NCNN floor was `50.70-52.35 C` (mean `51.03 C`), and the camera topic averaged `14.989 Hz`. A short ROS-camera -> custom NCNN live run then completed `150` frames in `18.8 s` at `mean_fps=7.98` / `mean_inf_ms=123.8` with temp `54.55 C -> 67.75 C` and no abort, but the multi-run sustained test later climbed through `80.4-82.05 C` aborts. This remains camera-display / dataset-readiness / simulation-coexistence / bounded procedure / short-run inference evidence only: sustained inference at the current NCNN profile is not viable yet, and real-FCU command/write path, QGC upload, Herelink acceptance, MAVROS telemetry change, dashboard integration, or bidirectional sync was not validated. Combined color/depth/IMU is not green yet: the earlier combined accel/gyro attempt reported `HID set_power 1 failed` and `Motion Module failure` during a Pi low-voltage warning, 05/06 showed chronic undervoltage before the user-observed shutdown, and 10/06 did not capture a full combined topic-rate / telemetry inventory. |
| Camera consumer exclusivity — Pi ROS bridge vs Herelink RTSP video | ⚠ 13/05/2026 — observed constraint: when `realsense2_camera_node` runs on Pi and workstation rviz2 streams from it, Herelink console video stream is lost; rviz2 stop → Herelink video returns. Likely v4l2 device-exclusivity (`VIDIOC_S_FMT` `errno=16 Device or resource busy` matches the symptom), breaking the existing `v4l2loopback`-based fork that the Herelink RTSP path relies on. **22/06/2026 update:** the current Herelink RTSP feed reached the workstation cleanly over TCP, but its content was a Pi desktop / `rqt_image_view` screen capture after starting the Pi camera node, not a direct camera feed. That is a setup regression for dashboard integration, not an adapter target. Phase 5 implication: autonomy-stack camera consumption and Herelink operator video are mutually exclusive under the current Pi setup unless a different sharing mechanism is engineered (single canonical camera node + RTP republish for Herelink, or multi-mux camera-fork daemon). |
| MAVROS Route 1 install on Pi 5 | ✅ 22/05/2026 + 04/06/2026 + 05/06/2026 + 10/06/2026 + 19/06/2026 + 26/06/2026 caveat — Ubuntu Noble + ROS apt path green; `ros-jazzy-mavros` 2.14.0, `ros-jazzy-mavros-extras`, and `ros-jazzy-mavros-msgs` installed from `packages.ros.org` with the dry-run dependency chain matching the real install. GeographicLib default datasets installed (`egm96-5`, `egm96`, `emm2015`) via corrected ROS 2 ament executable path `/opt/ros/jazzy/lib/mavros/install_geographiclib_datasets.sh`; `dialout` active after reboot. Late 22/05 quick launch with `px4.launch fcu_url:=serial:///dev/ttyACM0:115200` exposed the expected `/mavros/*` plugin topic surface but `/mavros/state` stayed `connected: false`. 27/05 and 28/05 expanded Remmina-side audits found no usable endpoint, with only `/dev/ttyAMA10` visible and silent. Professor photo sent on 03/06 morning, captured by the Pi desktop clock on 02/06 at 22:09 after reconfiguration, changed endpoint status: MAVProxy on `/dev/ttyAMA0` at `57600` detected vehicle `1:1`, reported `online system 1`, entered mode `HOLD`, showed `fence present`, and received ArduPilot EKF3 GPS status text. On 04/06, MAVProxy fanned that serial endpoint to `udpout:127.0.0.1:14550`; MAVROS `apm.launch fcu_url:=udp://127.0.0.1:14550@` reported `CON: Got HEARTBEAT, connected. FCU: ArduPilot`; `/mavros/state` returned `connected: true`; first ROS samples were captured from `/mavros/imu/data`, `/mavros/global_position/raw/fix`, `/mavros/battery`, and `/mavros/rc/in`. On 05/06, the camera-off MAVROS rerun on `ROS_DOMAIN_ID=12` again passed `/mavros/state connected: true` and captured a clean 136-topic `/mavros/*` graph with raw GPS no-fix, IMU, vehicle battery, and empty RC channels. On 10/06, MAVProxy/MAVROS again passed read-side heartbeat and samples (`connected: true`, mode `HOLD`, IMU, raw GPS no-fix, battery `16.281` V), but `system_status: 5`, FCU request/response timeouts, repeated EKF GPS-config warnings, and empty RC channels kept GPS/config and command/write validation open. On 19/06/2026, a camera-OFF post-update re-check confirmed the Route 1 install held across the 18/06 ROS sync — `ros-jazzy-mavros` was rebuilt at the same `2.14.0`, `/mavros/state` again returned `connected: true` with live IMU / battery, and the workstation saw the 136-topic `/mavros/*` graph over DDS. On 26/06, after the box was shut down and relaunched with the usual startup music/sound missing, MAVProxy could open `/dev/ttyAMA0:57600` but stayed at `Waiting for heartbeat from /dev/ttyAMA0` and reported `link 1 down`; MAVROS was not launched because the heartbeat gate failed. At the 26/06 close this was a physical power/wiring follow-up, not an install regression; the 15/07 and 17/07 live runs below supersede it as the current endpoint observation. |
| MAVProxy/MAVROS live dashboard reconfirmation | 🟡 15/07/2026 — MAVProxy heartbeat and loopback fanout passed; a minimal MAVROS profile returned `connected: true`, armed `false`, and live state, raw GPS, IMU, battery, and RC samples. DDS carried the topics to workstation rosbridge, and the view-only dashboard displayed the actual control-box data alongside the Hailo stream. GPS remained no-fix, and no FCU write was attempted. |
| Tracked two-command live supervisor | 🟡 17/07/2026 + 03/08/2026 + 04/08/2026 — two IoT runs reached six-topic arrival and automatic rate acceptance (Hailo `7.40/7.50 Hz`; five MAVROS feeds near `1 Hz`). Both combined stock-COCO/MAVLink browser views were operator-confirmed, MAVROS stayed connected/disarmed, and zero messages were observed on the five monitored command topics. Pi peaks were `68.3/67.2 C`; both Pi log directories were copied back. Pi fail-closed and workstation teardown markers passed after the workstation dashboard stack became unavailable unexpectedly before the intended Pi-first stop in both runs; that cause remains open. **03/08/2026:** two view-only runs completed the source window, entered the monitored hold and exited `status=0` on a normal Pi-first operator stop, with post-teardown temperature recorded, so both of the lifecycle items outstanding at 17/07 are now obtained. Both runs also reproduced a daemonless graph-query defect: a fresh `ros2 topic info --verbose` process can return a successful but transiently incomplete snapshot. **04/08/2026:** a batched MAVROS source view landed behind `LIVE_MAVROS_SOURCE_BATCH`, off by default, and a flag-off canary passed end to end (`PI_DATA_ARRIVED=PASS topics=6 elapsed=272s`, rate probes PASS, `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=115s`, both exits `status=0`). The defect recurred in that control run at `2` non-verifying readings, and per-run control counts are now `11`, `3` and `2`, so the variance exceeds any effect three runs could resolve. **05/08/2026:** the batched path was exercised live for the first time, at shipped defaults, and is **feasible**: `18` `MAVROS_SOURCE_PROBE_RUN result=OK` with no `TIMEOUT`, `INCOMPLETE`, `FAILED` or `SKIPPED`, every summary `bound=6s settle=3s reserve=3s topics=5`, `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=85s peak=66C`, and both supervisors `status=0 cleanup_rc=0`. The payload contract is now verified against real `TopicEndpointInfo` output rather than the focused suite's fake module. The defect recurred under the batched path at `2` non-verifying readings, identity-temporarily-unknown rather than 04/08's publisher-count-zero, so feasibility is not a fix and the reading count sits inside the flag-off control range with no reduction claimed. **07/08/2026:** a further view-only run (`live_dashboard_workstation_20260807_154942` / `live_dashboard_20260807_154959`) reached `PI_SOURCE_STACK_READY=PASS`, six-topic arrival and all six rate probes (`/hailo/overlay/image_raw` `7.32 Hz`; the five MAVROS topics `1.00`-`1.01 Hz`), with `COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed`, `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=128s elapsed=248s` and a run-wide peak of `67.2 C`. It ended on a **reversed shutdown order**: the workstation was stopped first, `rosbridge.log` records `user interrupted with ctrl-c (SIGINT)`, and the Pi failed closed on `STOP: workstation rosbridge node is not visible from the Pi` after `hold_elapsed=812s`, exiting `status=1 failed_phase=live-hold` with both teardowns `PASS`. Telemetry delivery and view-only posture are therefore proven; normal Pi-first lifecycle is not claimed for this run, and browser-last ordering was again not obtained. Being flag-off, it added a fourth graph-query control point of `10` non-verifying readings (all publisher-count-zero), making the series `11`, `3`, `2`, `10`. Browser-last ordering, the terminal data-plane probe, full endurance, optimized transport, GPS fix, custom-detector accuracy/calibration/live integration, and all FCU writes remain open. |
| Tracked two-command supervisor correction | 🟡 10/08/2026 — copied Pi/workstation logs disprove the 07/08 workstation-first explanation recorded above. The Pi reported its missing-rosbridge failure at `16:11:44.708`, exited at `16:11:57.653`, rosbridge accepted a new client at `16:11:58.752`, and the workstation supervisor did not receive operator `SIGINT` until `16:12:22.288`. A Pi-local publisher-count-zero result 19 seconds before the fatal miss independently matches the confirmed incomplete-snapshot class. The helper now retries the complete workstation-node set for three snapshots, records recovery and still fails closed on exhaustion. Stop order is judged from supervisor lifecycle timestamps, not the rosbridge `SIGINT` line. The helper pin changed; no corrective live run has occurred yet. |
| Guarded real-FCU closed-loop helper pair | 🟡 11/08/2026 — prepared and statically verified, not run. Both physical halves force domain `43` with subnet discovery, isolated from the domain `42` localhost-only SITL graph; the SITL and Pi bridge commands carry explicit expected-domain parameters, and both helper families reject conflicting local ownership. The workstation helper owns loopback rosbridge/dashboard and waits for fresh `READY_DISARMED` status before emitting the live servo-mapped bench URL. The Pi helper owns direct `/dev/ttyAMA0:57600` MAVROS, separates the two-plugin read-only T0b probe from the five-plugin telemetry/command session, and starts the existing bounded bridge only behind the T0a/T0b/T2 and physical-safety gates. It contains no MAVProxy/UDP relay, parameter write, mode change, arming, disarming or software safety-release command. The established Hailo/MAVROS helper is unchanged and remains view-only. No Pi, FCU, browser or physical thrust runtime was performed; T0a remains unscheduled. |
| Guarded real-FCU deployment and T0b acceptance | 🟡 17/08/2026 + 18/08/2026 — the complete helper-owned simulator path passed on 17/08 with contracted teardown, final verdict, ten matching evidence digests and independent adjudication. Powered-down connector seating and end-to-end `Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity then passed, closing T0a. On 18/08, D1 Gate 1 deployed and certified the four-file Pi bundle and `check` returned `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The read-only probe opened `/dev/ttyAMA0:57600` and received an ArduPilot heartbeat, but the MAVROS parameter-list exchange exhausted its retries. The operator stopped before the probe deadline; cleanup passed, but no T0b parameter artifact was created. The retained state evidence cannot recover earlier attempts because one path was overwritten and stderr could contaminate the YAML. No parameter was written, the bridge did not start and no real thrust occurred. T0b remains open, so T1 and both T2 tiers remain closed. |
| T0b evidence repair and second dated deployment | 🟡 19/08/2026 — the Pi capture path now isolates child diagnostics from YAML, retains every attempt and records diagnostics from the process writing both copies. Two behavioural regressions raised the complete physical-helper suite from `22` to `24` cases. The bundle manifest was regenerated only after the helper was final, and the helper, tests and manifest landed together at `dc90a8f`. The new five-file deployment at `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` passed exact inventory, pinned-manifest, `4/4` member verification and `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. Block E was approved but deferred without execution while its safety review remained pending. No controller or Herelink power-up, serial open, parameter write, bridge start or real thrust occurred under Block E. T0b remains open; T1 and both T2 tiers remain closed. |
| Workstation → Pi 5 desktop access | ✅ 22/05/2026 — GNOME Remote Desktop over RDP verified from workstation Remmina to `10.120.2.162:3389` after compositor check returned `wayland ubuntu:GNOME ubuntu`. `wayvnc` ruled out because this Pi image is GNOME / Mutter, not wlroots; RealVNC Server remains Xorg-only fallback. Desktop Sharing + Remote Control mirror the physical Pi desktop session; Remote Login intentionally left off because it creates a separate session. |
| Pi 5 YOLO CPU feasibility and workstation training path | ✅ 09/06/2026 + 10/06/2026 + 23/06/2026 + 24/06/2026 + 25/06/2026 + 26/06/2026 — Pi-local environment `~/venvs/yolo-pi5` installed and loaded `yolo26n.pt` on aarch64 with `torch-2.12.0+cpu`; NCNN export produced `yolo26n_ncnn_model` (`model.ncnn.bin` 9.3M, `model.ncnn.param` 26K). Static-image NCNN inference used the `bus.jpg` fallback, returned `detections: 5`, and measured preprocess 17.24 ms / inference 244.42 ms / postprocess 15.05 ms at `imgsz=320` on CPU. The 10/06 demo repeated static-image inference for 5 runs, with 5 detections each run, mean inference `84.09` ms, and temp 68.8 C -> 72.2 C. On 23/06, the workstation path passed a CUDA train -> NCNN export smoke test with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, `yolo26n.pt`, and `NVIDIA RTX A3000 Laptop GPU`: one-epoch `coco8.yaml` training wrote `runs/smoke/weights/best.pt`, then NCNN export wrote `runs/smoke/weights/best_ncnn_model`. That workstation-exported NCNN model was copied to Pi `imt-aqua-drone@10.120.2.249` and ran 3 static CPU inferences at `imgsz=640` on `000000000042.jpg`, with `boxes=2`, steady-state inference `226.0-281.1` ms, and temp `68.85 C -> 68.30 C` with no undervoltage / throttle evidence. On 24/06, the first RealSense RGB pipeline-validation pilot was captured, reviewed, labeled, and split outside the repo: 7 `person` images plus 4 clean negatives became a tiny 9/2 train/val split, all active label rows used class `4`, all coordinates were normalized, and rejected frames/labels were excluded from train/val. On 25/06, workstation-only training used that tiny split with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, and CUDA on `NVIDIA RTX A3000 Laptop GPU`: `yolo26n.pt` trained for 50 epochs into `runs/baseline_yolo26n/weights/best.pt`, validation was rerun to `runs/val_baseline_yolo26n`, and NCNN export wrote `runs/baseline_yolo26n/weights/best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Later 25/06, that custom NCNN export loaded and ran on the Pi as a static-image CPU check in `~/venvs/yolo-pi5` with Ultralytics `8.4.62` / `ncnn 1.0.20260526`; both saved validation images returned `0` boxes at the default confidence threshold, so detections remain informational only. A later bounded ROS-camera-node procedure fed RealSense RGB frames into the custom NCNN model: F1 saved 5 frames and ran inference, then F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` and `mean_inf_ms=340.9` before the intended `80.0 C` abort fired at `80.95 C`; the Pi had little thermal headroom from a roughly `72.7-73.8 C` baseline, so this points to cooling rather than a proven model infeasibility. On 26/06, `pyrealsense2 2.58.2` was installed only in the separate `~/venvs/yolo-pi5-rs`; direct camera-only capture proved `900` frames in `60.0 s` at `14.99 fps`, and a direct-SDK -> custom NCNN short run at `imgsz=640` completed `150` frames in `23.1 s` at `mean_fps=6.51` / `mean_inf_ms=151.9` with temp `57.3 C -> 68.85 C` and `0` boxes. Compared with ROS runs (`6.16-7.98 fps`, `123.8-160.6 ms`), direct SDK showed no meaningful capture-overhead advantage; the workload is inference-bound. The optional `imgsz=320` run segfaulted after model load, likely because the NCNN export was fixed for the `640` input profile; a real `320` test needs a separate workstation NCNN export at `imgsz=320`. The reusable dataset and capture plan now lives in [YOLO_Dataset_Plan](YOLO_Dataset_Plan). This proves dataset/toolchain preparation, tiny custom pilot training/export, static COCO Pi handoff, custom Pi static load/run mechanics, bounded ROS camera-topic -> custom NCNN procedure/safety-abort, direct camera-only SDK capture, and short direct-SDK -> custom NCNN mechanics only: not detector-quality evidence or sustained thermally clean live inference. Dashboard integration, MAVROS/QGC/Herelink, and command/write path remain unrun. |
| Hailo AI HAT+ 13 TOPS acceleration branch | 🟡 01/07/2026 + 02/07/2026 + 03/07/2026 + 07/07/2026 — Pi-side probe confirmed the mounted Hailo-8L board is PCIe-healthy (`1e60:2864`, gen-3 x1), the official pinned row is HailoRT / driver / pyHailoRT `4.24.0`, DFC `3.34.0`, and Model Zoo `2.19.0`, and the workstation Docker suite compiled the custom `yolo26n` checkpoint to `yolo26n_route_a_six_heads.hef` for `HAILO8L` with six raw outputs and no embedded NMS. On 03/07, the Pi installed the pinned `4.24.0` runtime stack on Ubuntu 24.04.4 / kernel `6.8.0-1060-raspi`; matching headers and DKMS passed, `/dev/hailo0` appeared, `fw-control identify` reported architecture `HAILO8L`, Python `HEF` import passed, `parse-hef` confirmed the six-output contract, and `hailortcli run yolo26n_route_a_six_heads.hef` completed `293` frames at `58.22 FPS`. On 07/07, the six-output host-side decode contract was proven on saved frames (`fb308f9`): a same-engine raw-head ONNX isolation decoded the six final head convs back to the graph `output0` to float precision (box max abs `0.0 px`, class max abs `1.178e-7`), so six-output layout handling, direct 4-channel box decode, class sigmoid, and the `data.yaml` class map are settled, and the earlier full-precision box residual is now diagnosed as a Hailo DFC emulation vs ONNX Runtime cross-engine numeric difference amplified by stride, not a decode error. The next Hailo gate — a positive-bearing saved-frame Tier 3 (quantized path -> host decode + NMS + un-letterbox versus Ultralytics) — is blocked upstream on a functional detector: the current tiny `best.pt` fires on none of the available saved frames at `conf=0.25`, including its own training images, so a larger labeled dataset and retrain are the precondition (see [YOLO_Dataset_Plan](YOLO_Dataset_Plan)). Accuracy-grade live RealSense detector input, live ROS image integration, dashboard integration, MAVROS/QGC/Herelink co-loads, and accuracy-grade calibration remain open. |
| Stock-COCO Hailo live dashboard diagnostic | 🟡 15/07/2026 — the D435I/Hailo path published annotated frames on `/hailo/overlay/image_raw`, and the workstation browser displayed live boxes and class labels while minimal MAVROS telemetry was visible. This closes the stock-model image/dashboard mechanics question only; custom detector quality, optimized transport, and full endurance remain open. |
| Detector recovery and proxy training path | 🟡 08/07/2026 + 09/07/2026 — 08/07 Blocks A-C produced the detector baseline inventory, source decision, and external acquisition manifest only. The manifest scopes VRX to `buoy` / `dock` bootstrap rows, marks `vessel` as spawn-required, and leaves `obstacle` / `person` to RealSense, public data admitted through checks, or explicit world authoring. A bounded Pi smoke also proved single-process RealSense -> Hailo -> decode-summary mechanics with the current HEF (`30` frames, `8.61 FPS`, float32 six-output tensors), but the model stayed at the expected zero-detection / `~0.003` confidence floor. The visual target is YOLO-style colored boxes with class / confidence labels, not masks or polygons. The 09/07 scaffold sets up an isolated unicolor-object real-image training smoke to validate capture -> box labeling -> workstation retrain -> held-out firing before maritime data collection. This remains process evidence only, not maritime detector quality, Hailo accuracy, Pi deployment, ROS/dashboard integration, MAVROS/QGC/Herelink, or command/write validation. |
| T0b probe DDS isolation repair | 🟡 20/08/2026 — the safety audit found that the two probe-allowlisted MAVROS plugins advertise at least five state-changing parameter, mode and telemetry-configuration services despite the helper issuing read requests only. The standalone Pi `probe` path is local and does not wait for workstation nodes or start the bridge, so it now forces `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`; `check`, `run-t2a` and `run` preserve the domain-`43` subnet contract. A regression failed against the former probe boundary, then the regenerated four-member manifest and complete `24`-case suite passed. Revision `f8e440a` was subsequently deployed once in the new root `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820`. Fresh Pi and physical certification passed with the controller and Herelink off, the exact five-member archive inventory and four governed members verified `4/4`, and the deployed non-actuating `check` returned `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started` with empty stderr. Block A is complete. The serial probe did not run; Block E remains closed pending separate approval, T0b remains open, and T1 plus both T2 tiers remain closed. |
| Powered T0b execution | 🟡 20/08/2026 — after separate approval, a powered receive-only UART isolation captured `23868` bytes and `30` valid disarmed heartbeats from system/component `1.1` while sending zero serial bytes. The final full probe then opened `/dev/ttyAMA0:57600`, detected the live ArduPilot FCU, and passed `connected: true`, `armed: false` plus the hardware-safety gate. MAVROS exhausted all automatic parameter-list attempts, and the explicit forced pull received no response before its bounded timeout. A later duplex isolation captured `14326` inbound bytes and `18` valid disarmed heartbeats, then transmitted exactly one PING and one `SYSID_THISMAV` read request. The two outbound frames verified at `53` bytes with no state-changing message, but neither received a response. No required `41`-parameter mapping/rail artifact was produced. No parameter write, bridge start, mode change, arming, RC, motor or thrust action occurred. T0b remains open; the separately gated T1 `BRD_SER1_RTSCTS` change is the next decision point, and both T2 tiers remain closed. The final powered-off confirmation closed the physical hardware day. |
| T1 flow-control experiment and guarded run attempts | 🟡 21/08/2026 — revision `2600ea4` was deployed in a new certified Pi root. `BRD_SER1_RTSCTS` was changed from `Auto (2)` to `0` and the FCU rebooted. The first guarded run connected disarmed in `MANUAL`, but automatic and forced parameter pulls still received no response. The second run started armed and stopped at the connected-and-disarmed gate before the parameter pull, bridge or command publisher started. Both runs ended `status=1 cleanup_rc=0`; no RC override, motor command or thrust command was issued by the repository pipeline. The copied Pi evidence archive verified at `d913d296c4aecd34ca305339ed1a9591215a75c061dec7552567f647df3643a7`. The parameter was restored and read back as `Auto (2)`, then all control hardware was powered off with propulsion isolated, propellers removed and the hull restrained. T0b remains open, candidate `0` did not fix the direct-link request/response failure, neither T2 tier earned acceptance and no physical approval carries forward. |
| Direct command/ACK on the Pi serial endpoint | 🟡 25/08/2026 — a Pi-local MAVProxy session on `/dev/ttyAMA0:57600` received `MAV_CMD_COMPONENT_ARM_DISARM: ACCEPTED` for arm and disarm and ended explicitly `DISARMED`. Because the capture began already armed, it proves FCU command acceptance but not a fresh arm transition. No parameter response, workstation-originated command, RC override or non-neutral servo output was captured, so T0b and both T2 tiers remain open. The professor's workstation-path repair is operator-reported pending one correlated workstation-to-Pi-to-FCU trace. |
| Guarded real-FCU dashboard Test A | 🟡 26/08/2026 — the current helper-owned SITL acceptance and independent adjudication passed first. A later real-FCU run used a hash-pinned `986`-parameter snapshot with temporary `RC_OVERRIDE_TIME=0.5`, resolved steering/throttle as `RC1`/`RC3`, left/right output as `SERVO3`/`SERVO1`, and both rails as `800/800/2200`. The Pi and workstation reached their READY markers. The retained dashboard recording shows requested `0.00/0.00`, RC `1515/1515` and output `800/800 us`; applied steering `0.05` and throttle `0.04`; measured RC `1564/1470` and output `911/800 us`; then complete neutral restoration. Both supervisors ended connected/disarmed, exchanged the stop marker and exited `status=0 cleanup_rc=0`. This accepts bounded dashboard-to-real-FCU command/output feedback with propulsion isolated, not physical thrust. Herelink-to-VRX Test B remains **NOT RUN** and is deferred to 27/08/2026 behind fresh declarations and approval. Its current W2 observer requests `/wamv/pose` while VRX publishes `/model/wamv/pose`, leaving the retained observer at `WAIT_DATA`; that contract must be repaired and proven offline before Test B. Rollback to `RC_OVERRIDE_TIME=3.0` remains mandatory afterward. **Forward correction 27/08/2026:** the pose-topic half of this row is withdrawn. `/model/wamv/pose` is the Gazebo transport name; `vrx_gz` bridges it to relative `pose` inside `PushRosNamespace('wamv')`, so the ROS topic is `/wamv/pose` and the supervisor was already correct. The recorder's `base_link` child-frame filter matched nothing, which is what held the observer at `WAIT_DATA`. |
| VRX pose, SITL and T0b proof for Test B | 🟡 27/08/2026 — the exact W2 VRX launch produced eight transforms on `/wamv/pose`; `sydney_regatta -> wamv` was the sole world-parented transform and no child ended in `base_link`, directly proving the repaired selector. The full supervised SITL acceptance then passed on clean revision `147efe0` in `/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`; independent adjudication checked ten hashes and ended `SITL_ADJUDICATION=PASS`. A fresh `986`-parameter MAVFTP snapshot with `RC_OVERRIDE_TIME=0.5` was pinned at `3347835b8482c9fa00c54e9d53586d2beb1db87fabd92adfe599259a9c346900`. The snapshot-backed T0b probe passed the direct live connected/disarmed and hardware-safety checks, resolved all `41` selected parameters and exited with `writes=none bridge=not-started`; copy-back is `/home/ghostzero/Desktop/pi_run_evidence/t0b_probe_20260827_174820`. T0b is closed. A subsequent offline readiness audit added a default-off W1 disarmed recorder mode, environment-isolated certification and a strict JSONL summarizer for the still-required stream gaps, PWM skew, thrust delay and stationary pose drift. Those source changes are not landed or live-run, so W2 parity, a fresh exact-revision SITL run or explicit supersession, the disarmed measurement, explicit limits and fresh physical declaration still gate execution. Test B is approved but remains **NOT RUN**, and the temporary `0.5` value still requires rollback to `3.0` afterward. **Forward update:** revisions `aa4a07a` and `1c1dff5` landed the recorder mode and corrected publisher-before-subscriber ordering. The live disarmed run reached W1 seven-topic/rate acceptance and W2 four-stream READY, measured Pi/VRX maximum gaps `1.039521457 s` / `0.291961215 s`, `223.019194 ms` PWM skew, `9.633272 ms` thrust delay and `0.081450536 m` stationary drift, then passed ordered Pi, W2 and W1 teardown. The copied Pi evidence is `/home/ghostzero/Desktop/pi_run_evidence/test_b_measurement_20260827_185227`; explicit armed limits are recorded. Measurement and limit selection are closed, but Test B remains **NOT RUN** pending current-revision SITL acceptance or explicit supersession and a fresh physical declaration. **Armed-attempt update:** the operator superseded the SITL rerun for `eb9a337` and ran Test B. The retained record captured `SERVO3/SERVO1=2200/800`, mapped thrust `800.0/0.0 N` and `2.47946 m` of VRX motion, but the Pi then aborted on `ARMED_WINDOW_DEADLINE`; W1 and W2 recorded terminal stale-stream aborts and no recorder captured final connected/disarmed neutral hardware-safe state. Test B is **ATTEMPTED - FAILED / NOT ACCEPTED**. Pi copy-back is `/home/ghostzero/Desktop/pi_run_evidence/test_b_armed_failed_20260827_192234`. An explicit paired-zero retry mode now disables only the armed and outer runtime deadlines, defaults the Pi window to resizable, retains freshness, disconnect, command, rail, thermal and final-restoration gates, and uses completed-run teardown W2, W1, Pi. The repair is offline-only and still needs publication, fresh exact-revision SITL acceptance or explicit supersession, a fresh declaration and separate approval before retry. **Later paired-zero update:** clean revision `550b992` reached the disarmed baseline with both duration deadlines disabled but never armed. P1 then failed on three false zero-publisher graph snapshots for live `/mavros/global_position/raw/fix` data; retained NavSatFix and W1 `4.00 Hz` evidence rule out stream loss. P1, W2 and W1 cleaned up, but Test B remains **ATTEMPTED - FAILED / NOT FORMALLY ACCEPTED**. **EOD repair:** the existing bounded six-topic `rclpy` source view is now default `1` with exact `/mavros` identity checks preserved; W1 child-exit reporting is one-shot. Focused suites pass, and the same direct W1, W2, P1 retry remains for 28/08/2026. |
| W1 arrival-gate repair for Test B | 🟡 28/08/2026 — clean revision `a23fc6d` reached P1 source-stack and safe disarmed baseline PASS plus W2 four-stream READY, but W1's separate all-seven publisher precheck timed out before message sampling or Pi-observer startup. Nothing was armed and all stacks cleaned up with `cleanup_rc=0`; Test B remains not accepted. W1 now retains each observed expected publisher across polling passes, re-queries only unresolved topics, uses `/proc/uptime` monotonic timing and reports exact unresolved names. The focused `25`-case suite passes offline; the repair still needs a new live attempt. |
| Test B repaired live functional run | 🟡 28/08/2026 — clean revision `6beb603` passed P1's safe baseline, the repaired W1 publisher-arrival and seven-topic rate gates, and W2 four-stream READY. Retained evidence contains both full asymmetric `SERVO3/SERVO1` pairs, active-side `800.0 N` thrust, neutral restoration and `116.751869 m` of first-to-last VRX displacement; the operator observed Herelink stick input moving the boat while W1, W2 and P1 remained healthy. A later operator-reported external interruption was followed by `/dev/video4` disappearing, stale `/mavros/state`, P1 `status=1 cleanup_rc=1`, and fail-closed W1/W2 stale-stream exits. The copied Pi peak was `70500 mC`, below the `80000 mC` abort threshold, with no thermal-abort record. No retained connected/disarmed final state or passing lifecycle/adjudication exists. Classification: **FUNCTIONAL MOTION DEMONSTRATED; RUN EXTERNALLY INTERRUPTED / NOT FORMALLY ACCEPTED**. |
| Enhanced Test A and parameter rollback | 🟡 28/08/2026 — a fresh `986`-parameter snapshot with SHA-256 `61406eee10c253daabfef4462ce0b3661be30b599bd7736909c5bff4e4b4943d` resolved `RC1`/`RC3`, left `SERVO3`, right `SERVO1` and both rails `800/800/2200`. The real-FCU dashboard and Pi helpers reached READY and ended connected/disarmed with the ordered stop marker and `status=0 cleanup_rc=0`. The operator corrected the active-interval state to propellers fitted and propulsion available, making `REAL_FCU_PROPELLERS_REMOVED=1` inaccurate for that interval, then reported limited one-sided physical rotation. No active command/PWM interval was retained. The helpers reported nominal `tier=T2b authority=demand-enabled` software markers and clean teardown, but the run did not satisfy T2b's propellers-removed gate and had no separate T3a approval, dedicated guarding or exclusion-zone evidence. Classification: **ENHANCED TEST A - PROPS-FITTED FUNCTIONAL OBSERVATION; NOT T2B OR T3A ACCEPTANCE**. It establishes no ESC threshold. Exact steering `+/-0.20` is rejected because `float32` transport slightly exceeds the bridge's exact bounds; that code defect remains open. The approved rollback then captured live `RC_OVERRIDE_TIME` readbacks `0.5 -> 3.0`, saved and copied a `986`-parameter snapshot with SHA-256 `a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`, and left the serial endpoint free. |
| Current-source SITL and command endpoint repair | 🟡 31/08/2026 — clean revision `3ca4c9bd16414d37506b62ce9fa5b8dad55a3719` passed the full supervised SITL acceptance and independent adjudication in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_150946`, including ten hashes, control cross-check, exact stop order, teardown and free host ports/processes. After that pass, the exact `+/-0.20` float32 steering defect and the equivalent defect at legal tunable throttle maxima were reproduced. The repair normalizes only the exact float32 encoding of each configured command endpoint within the unchanged authority; adjacent and materially over-limit values plus negative throttle remain rejected. The focused suite passes `36` tests and the four-file manifest is regenerated. The later bridge edit reopened current-source SITL for the repaired bytes. Source tracing confirms paired command/override publication and ArduRover throttle-plus/minus-steering mixing; the observed `911/800 us` steering-heavy result is consistent with the mixer, while the straight-throttle ESC onset remains unmeasured. No throttle-authority or `MOT_THR_MIN` change was made, and calibration remains a separate, freshly approved, propellers-removed activity. **Current-source closure:** clean revision `bba195b19a0f06a874bfbcbcbbd1621524cbce60` then passed the complete supervised acceptance in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839` and independent adjudication in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log`. All ten hashes, the control cross-check, exact stop order and teardown passed, with governed ports free and governed process patterns absent, ending `SITL_ADJUDICATION=PASS`. This closes current-source SITL for the repaired runtime path; separately verified bundle transfer/checksum and the separate ESC-threshold calibration remain open. **Pi deployment closure:** the regenerated five-file bundle was installed at `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260831_bba195b`; its manifest digest, all four governed hashes and the non-actuating helper check passed. The verified copy-back is `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260831_bba195b`. Bundle transfer/checksum certification is closed; the ESC-threshold calibration and complete real-hardware acceptance remain open. |
| ESC-onset evidence capture | 🟡 31/08/2026 — an opt-in workstation-only `t2b --esc-threshold-calibration` recorder mode is prepared offline. It keeps ordinary T2a/T2b capture unchanged, adds raw RC input/output to the existing command/status/state evidence and correlates typed per-side observations against exact mapping and measured feedback. A per-side result requires fresh five-stream evidence, a later higher request and strictly higher delivered output PWM than the highest stopped-output observation; terminal `not-observed` is valid only at the governed `0.12` maximum. The full T2b phase sequence, E-Stop and final connected/disarmed state remain required, and the recorder has no write path. Focused coverage passes `21` tests and the full offline gate passes. **OFFLINE PREPARATION / NOT RUN:** current Pi modes require propulsion isolated, so no physical motor onset can yet be measured; no T3a props-fitted mode, guarding record or exclusion-zone evidence exists. No threshold, parameter, FCU or propulsion result was created, `RC_OVERRIDE_TIME` remains `3.0`, and no bundle member changed. |
| T3a props-fitted runtime and ESC-onset capture | 🟡 01/09/2026 — a distinct Pi `run-t3a` mode and a distinct workstation `t3a --esc-threshold-calibration` recorder are implemented offline. The Pi runtime is demand-enabled within the unchanged `0.20` steering and `0.12` throttle bounds and requires T0a complete, T0b approved, separate T3a approval, propellers fitted, hull restraint, mechanical guarding, a clear exclusion zone, propulsion isolation at launch, disarmed start and hardware safety ON; T2/T3 approvals and removed/fitted-propeller declarations fail closed when contradictory. Propulsion enable creates a closeout obligation before operator input. Bounded closeout handling remains fail-closed under missing, invalid, timed-out, `INT` or `TERM` input while still reaching final-state capture and child stops; the recorded default timeout is `300 s`. The recorder remains subscriber-only with five ROS subscriptions and stdin observations, binds to the T3a bridge identity and retains the five-stream freshness, PWM-bracket, E-Stop and final-disarm evidence contract. Focused verification passes `26` recorder tests, `42` Pi-helper cases and the regenerated `4/4` bundle manifest. **OFFLINE IMPLEMENTATION / NOT RUN / NOT DEPLOYED:** no serial, FCU, parameter, bridge runtime, arm, ESC, motor or propeller action occurred; declarations do not prove guarding exists; and the certified `20260831_bba195b` Pi root does not contain these bytes. |
| T3a bundle deployment and non-actuating certification | 🟡 01/09/2026 — clean published revision `025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba` was installed in `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c`. Exact five-file inventory, executable helpers, manifest digest `11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d` and all four governed hashes passed. The helper ran only its non-actuating `check` and emitted `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`; the verified copy-back is `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`. **DEPLOYED / CERTIFIED / NOT RUN:** no probe, MAVROS or bridge runtime, parameter write, arm, propulsion action, threshold, acceptance or Block E authority was created. |
| T3a props-fitted functional run | 🟡 01/09/2026 — published revision `507bfcfa9d1eed0733840188d99905d49c691430` reached Pi and W1 READY and completed the typed safe closeout, final connected/disarmed capture, stop-marker exchange and `status=0 cleanup_rc=0` lifecycle. Evidence is retained under `/home/ghostzero/Desktop/pi_run_evidence/t3a_esc_threshold_20260901_193548`, `/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260901_193313` and `/home/ghostzero/Desktop/real_fcu_capture_t3a_esc_threshold_20260901_193327`. The separate capture verdict failed over `33,598` events because status evidence/binding was invalid and both typed calibration sides were incomplete. Machine output points were `954/954 us` at straight `0.12`, `994/913 us` at `+0.03/0.12` and `913/994 us` at `-0.03/0.12`. The operator-reported onset near `990 us` is consistent with a driven-side `(980, 994] us` interval, not an accepted exact threshold. Classification: **FUNCTIONAL PROPS-FITTED RUN / CLEAN LIFECYCLE; CALIBRATION FAILED / NOT ACCEPTED**. `RC_OVERRIDE_TIME=0.5` still requires a retained rollback to `3.0`. |
| Integrated Hailo/real-FCU/VRX showcase | 🟡 01/09/2026 — the tracked worktree now keeps one actuator path: Dashboard or Herelink ownership -> real FCU -> exact measured `/mavros/rc/out` -> forward-only VRX, with validated VRX pose and thrust telemetry returned to the dashboard. Stock-COCO `person` and required detector-feed loss raise E-Stop. Clear camera evidence never auto-resumes; neutral-gated Reset E-Stop, new prime and Dashboard/Herelink handovers can repeat without restarting the stack, while E-Stop retains priority. The required Hailo feed is bound to exactly one resolved `/hailo_person_stop_bridge`, and stale bridge status blocks Reset/Owner UI and publication. Focused red/green results are person monitor `37`, real-FCU helper `55` and the full dashboard Node suite `90/90`; prior unchanged bridge/W2/capture/servo results remain valid for their own bytes. Classification: **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN**. A new landed/certified bundle and one separately approved integrated run remain for the showcase. |
| Integrated handover safety correction | 🟡 01/09/2026 — firmware source review invalidated the worktree's physical-RC-neutral wait: while MAVROS override is active, ArduPilot exposes the effective override through `RC_CHANNELS`, so `/mavros/rc/in` is freshness/range evidence rather than independent physical-stick proof. The existing ownership button now sends the one-shot `HERELINK_STICKS_NEUTRAL` attestation; raw `HERELINK` is rejected. The bridge requires exact rosbridge source binding, the current connected/armed/authorized `MANUAL` epoch, fresh valid feedback and neutral measured `/mavros/rc/out`, then monitors output through three trim and three release frames. A non-neutral release relatches E-Stop and reasserts trim; disarm/disconnect revokes ownership. Owner-matched String reset tokens replace the Bool reset, and Reset cannot auto-prime through delayed Joy frames. Bridge `54`, capture `37` and dashboard `91/91` pass. **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN:** the previous live run and certified bundle do not contain these bytes. |
| Integrated fresh-release and explicit-reprime correction | 🟡 01/09/2026 — callback-delivered RCOut generations now gate Herelink release: a newer neutral generation is required before the first release, between each of three release frames and after the final release. Missing new evidence leaves the handover pending; a newly observed non-neutral output relatches E-Stop. Dashboard reclaim publishes no automatic Joy prime and the UI requires an explicit `Neutral Now` action before demand. Bridge `54`, capture `37` and dashboard `91/91` pass. **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN:** no existing bundle or live evidence contains these bytes. |
| Integrated showcase publication status correction | 🟡 01/09/2026 — the three 01/09/2026 showcase entries above classify their bytes as **NOT COMMITTED**. Those bytes landed as `da6627e21b9019eaff95b36d407f2439da24e156` (`feat(showcase): integrate Hailo stop and FCU-VRX handover`, 22 files, `+6041/-200`) with `HEAD == origin/main`, divergence `0/0` and a clean worktree. The corrected classification for all three is **COMMITTED `da6627e` / NOT DEPLOYED / NOT RUN**. The previously certified Pi bundle does not contain these bytes, so a new bundle transfer and non-actuating certification remain required before any run. The bundle is no longer `da6627e`-named: the hardware-safety badge changed `tools/real_fcu_rc_command_bridge.py` after that commit, so the manifest and the deployed bundle must be named for the revision that lands that change. |
| Workstation preflight test isolation | 🟡 02/09/2026 — showcase-mode preflight failed at `12236b5` because `tools/test_real_fcu_digital_twin_helpers.sh` inherited the operator's ambient `REAL_FCU_HAILO_PERSON_STOP`, which reconfigured an ordinary T2a readiness fixture into expecting the Hailo nodes. The suite now scrubs every `REAL_FCU_*` name before any case, covering the physical declaration flags read at gate execution in the same class. Five cases added, `55` to `60`, one bound to the suite-entry call itself, one a control proving the unscrubbed fixture still fails, and one requiring the final marker to survive a polluted nested run. The two internal re-entry modes are reserved arguments, not environment variables, after review found an environment-triggered probe was itself an ambient bypass that returned success without running a case. Production helpers unchanged; the static preflight still validates the ambient flag. Workstation-only, nothing started. Two pre-existing workstation-helper faults stay open and unrepaired: the port check at line `155` is fail-closed only because `set -e` is active, since `rfcu_ws_fail` returns instead of exiting, and the PASS marker hardcodes `ports=8002,9090` and omits port `8080` checked in Hailo mode. A current-revision SITL acceptance also stays open: the last accepted SITL revision predates both `da6627e` and `12236b5`. |
| Workstation preflight guards fail-closed | 🟡 02/09/2026 — `rfcu_ws_fail` now exits rather than returning, so all `48` guards that end in an or-branch to it are fail-closed by construction instead of depending on the caller's `set -e`. The inspected-port list became a single source of truth shared by the rejection loop and the PASS marker, so showcase mode reports `ports=8002,8080,9090` rather than hardcoding `ports=8002,9090`. Six cases added, `60` to `66`, each proved against a mutant, one of them covering a process-substitution hole the fix itself introduced. The change also exposed and fixed four `set -e` and-or faults in the test harness itself. Preflight passes in both modes, workstation-only. Both faults recorded as open in the isolation entry above are now closed. |
| Abort-helper sweep and FCU-to-VRX guards | 🟡 02/09/2026 — every abort helper in the repository was checked. `fcuvrx_fail` had the same fault as the workstation one and now exits, closing `55` guards that were continued past inside their own function; a lone hand-applied workaround was removed as redundant. `adj_fail` and the health-check `fail` are accumulators by design; the SITL runner already aborts directly. The VRX check marker stated its suite sizes as literals and now has an assertion pinning them to what the suites report, which caught real drift on its first run. Two cases added, `30` to `32`; the supervisor checksum pin in the runbook was refreshed. A pre-existing `flake8 I101` failure in `plan` is also closed. `rfcu_pi_fail` carries the same fault and is left for an explicit decision: it is the thruster-driving Pi runtime and a bundle member. |
| Pi runtime guards fail-closed | 🟡 02/09/2026 — `rfcu_pi_fail` now exits, closing `123` guards that were continued past inside their own function, `13` of them in `rfcu_pi_run`. Cleared before the edit because this is the thruster-driving runtime: no conditional consumption, no subshell call sites, EXIT trap installed before any child, and none of the `22` functions reachable from the closeout and signal handlers calls it, so a guard cannot abort the T3a safe-closeout. Bundle manifest regenerated, Pi entry `5c6fca19` to `43a4775f`. Three cases added, `66` to `69`. The `does not return` probes written earlier today were vacuous in all three suites, since sourcing a helper enables `set -e`; they now use `set +e` and are proved against mutants. Not validated on the Pi: a new bundle transfer and non-actuating certification remain required before any run. |
| Current-revision SITL acceptance | 🟡 02/09/2026 — revision `0ed5525` passed the full simulator acceptance, workstation-only, closing the gap where no accepted SITL result covered the current bytes. Three one-shot operator gates plus browser-driven positive, release, negative and latched E-Stop phases; supervisor exited `status=0 failed_phase=none cleanup_rc=0 finalize_rc=0`. Adjudicated independently rather than on the runner's own verdict: `SITL_ADJUDICATION=PASS`, no `FAIL` line, nine evidence phases, `missing: []`, ports and processes free, teardown confirmed directly first. Not evidence for the boat's thruster channel assignment - the guard resolved the simulator's own reversed mapping - and it does not exercise the Pi runtime, so the `123` fail-closed Pi guards remain offline-verified. |
| Pi bundle deployed and certified | 🟡 02/09/2026 — `778e069` transferred to `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069` and certified non-actuating with the Pi alone powered; `check` needs `/dev/ttyAMA0` present, read-write and free but never opens a link, so the unpowered flight controller does not block it. Manifest digest `fedda913…` matched the workstation, the four governed hashes verified twice, and `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started` was reproduced across two passes with a retained log. Every Pi-reported digest was compared on the workstation against the worktree and `HEAD` rather than read by eye; all five matched. First hardware execution of the fail-closed guards: the twelve in `static_preflight` ran clean twice, the other `111` still need a run mode. Classification: **DEPLOYED / CERTIFIED / NOT RUN**. |
| Hardware-safety reading documented; Pi monitor finding open | 🟡 02/09/2026 — the runbook now documents the dashboard hardware-safety reading as an operator cross-check on the physical switch, with `Unknown (stale)` explicitly not `ENGAGED` and `RELEASED` explicitly not evidence of powered propulsion, plus cross-references at the two points where the document already directs the operator at the switch. Writing it surfaced an open fail-open finding, not repaired: `tools/pi_live_hailo_mavlink_dashboard.sh` derives its own `hardware_safety_is_on()` without the staleness or boolean guards the bridge applies, and `restored_safe_state()` depends on it, so a stopped `/mavros/sys_status` stream can let the monitor declare an armed observation complete and suppress a `FINAL_STATE_LOST` abort. The file is checksum-pinned and Pi-side, so a repair needs an explicit decision and a re-pin. |
| Pi monitor staleness finding withdrawn | 🟡 02/09/2026 — the fail-open finding against `tools/pi_live_hailo_mavlink_dashboard.sh` recorded in the row above does not hold and no change was made. `hardware_safety_is_on()` applies no bound of its own, but `/mavros/sys_status` is a required subscription, `record_required` timestamps it, and all three `restored_safe_state()` call sites sit behind `stale_topic`, which aborts with `REQUIRED_TOPIC_STALE` before the safety reading is consulted. The monitor is fail-closed on this path, with the guard in the caller rather than the reader; the boolean case is unreachable from a `uint32` field. The review error was generalising a missing guard into a system property without tracing call sites. File unchanged, runbook pin still valid. |
| Run-path guard map and pre-run contract | 🟡 02/09/2026 — the thirteen stop points in `rfcu_pi_run` are mapped with message and trigger, and the parameter guard's nine bounds are tabulated from the bridge source so line `1704` is checkable before a run rather than discovered during one. The earlier claim that the new bundle is stricter is withdrawn for the normal path: `set -e` already aborted on all thirteen, so the fail-closed change is robustness rather than new strictness. Largest one-shot risk: `RC_OVERRIDE_TIME` must be in `(0, 0.5]`, was `3.0` on 31/08/2026, set to `0.5` on 01/09/2026 and left temporary with rollback open, and has not been read since; `3.0` ends the run at `1704`. An FCU already armed at start ends it at `1688`, as the 21/08/2026 run did. |
| Full-stack run-sheet | 🟡 02/09/2026 — five workstation terminals plus the Pi, with domains, waiting markers and stop order in one place. Both workstation supervisors must be waiting before the Pi starts, since the Pi's discovery guards look for nodes they own; W2's `start the Pi now` message is not the trigger because W1 need not be up when it prints. Records the gap that no supervisor starts `real_fcu_command_feedback_capture` although `run-t3a` requires it, so a missing terminal stops the Pi at line `1738`. Stop order is the reverse, with W1 last because its stop marker lets the Pi finish its closeout. Derived from source, never executed end to end in this configuration, and carrying no physical declaration values. |
| T3a armed-run sheet | 🟡 02/09/2026 — where arming sits in the T3a path, traced from source. The helper cannot arm and arming is external, after `REAL_FCU_T3A_READY=PASS`, never a starting condition, since the runtime gates require `connected` true and `armed` false. Records that `run-t3a` short-circuits both manual confirmations because the ten approved flags are the declaration, unlike the T2 modes which prompt for exact tokens, so an untrue flag removes a real gate. Closeout prompts for `NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED` in a stated order with a `300`-second default timeout. Carries no flag values, tier choice or go/no-go. |
| Pi terminal session persistence | 🟡 02/09/2026 — the T3a sheet now records that an `ssh` session and a Remmina desktop terminal differ for a run ending in an interactive closeout. Children are `setsid` with detached stdin and survive the parent terminal; the supervisor does not, so a dropped `ssh` link leaves the closeout prompt unanswered and `rfcu_pi_cleanup` records a safe-closeout failure. An RDP desktop session persists across a client disconnect and the helper needs no display, so Remmina removes that failure mode. Also records pasting rather than retyping the thirteen-flag line, keeping the Remmina window open between arming and closeout, and confirming `Ctrl+C` passes through beforehand. |
| Workstation dress rehearsal | 🟡 02/09/2026 — terminals 1 to 3 of the run-sheet executed with no Pi and no flight controller, finding five defects in the sheet, all corrected: ten undocumented W2 environment variables, the rejected default `FCU_VRX_CORRELATED_OBSERVATION=0`, a capture command invalid without `--esc-threshold-calibration`, an interactive capture terminal documented as fire-and-forget, and a `120`-second W2 fuse after `PRESTART=PASS` that tears down VRX when the Pi does not deliver relayed RCOut in time. W2, W1 and the capture node all reached their ready or waiting states with the corrected environment, teardown was clean with no survivors, and the `pgrep -af` conflict-guard false positive was reproduced and recorded. The Hailo branch and everything Pi- or FCU-side remain unexercised. |
| Bidirectional twin documented; readiness timeout raised | 🟡 02/09/2026 — the run-sheet covered only the outbound leg. Both are now documented: measured `/mavros/rc/out` on domain `43` relayed to the domain `77` bridge as VRX thrust, and VRX pose and thrust returned as twin telemetry on `/fcu_to_vrx/twin_telemetry` for the dashboard. The three post-Pi markers are tabulated in order, with the dashboard twin-telemetry panel named as the only end-to-end proof. The W2 command now sets `FCU_TO_VRX_READY_TIMEOUT_SECONDS=600`, since the `120` default opens its window at `PRESTART=PASS` before the rest of the stack is started and is not achievable by hand; the four-stream observer gate stays bounded separately at `900`. `RC_OVERRIDE_TIME` operator-confirmed at `0.5`. |
| First full-stack T3a attempt; link proven, record corrected | 🟡 02/09/2026 — the stack reached the T0b probe and stopped at gate `1688` with no arm, propulsion command or actuation. The Hailo preflight ran on hardware for the first time (`17` guards, coverage `12` to about `29`), all thirteen T3a flag gates passed, and the unrehearsed Hailo handshake worked end to end. Three link diagnoses were proposed and all three disproved by cheaper tests that should have come first; an isolated MAVROS run connected in about `1.5` seconds and pulled `986` parameters. Corrections: the Pi-to-FCU request/response defect carried open since 03/08/2026 does not reproduce, and implausible router addresses appear on healthy links so they are not a fault signature. The run-sheet gained a step zero that proves the link in seconds rather than discovering it five minutes into a committed stack. |
| Full-stack T3a run complete; throttle ceiling `0.20` | 🟡 02/09/2026 — the bidirectional twin loop closed against the real flight controller and ended on a confirmed safe closeout, the first full-path run at any revision. Unblocked by removing the Hailo child, whose interaction with the serial link is still unexplained though contention is ruled out, and by guard-snapshot mode, which skips a live parameter pull whose `timeout 20` cannot fit a measured `36`-second transfer of `986` parameters. The guard resolved the boat's own `left=SERVO3 right=SERVO1`, the reverse of the simulator's. Throttle ceiling raised `0.12` to `0.20` across five enforcing surfaces, two of them bundle members, caught by three independent guards including a deliberate tripwire; steering and throttle now share `0.20`. Manifest regenerated, so the deployed bundle is stale and needs a fresh transfer and certification. |
| Person-alert advisory mode | 🟡 02/09/2026 — an explicit opt-in, default off and refused without the detector, in which a detected person warns instead of stopping. The freshness requirement is kept, so a dead detector feed still stops. Building it exposed a second stop path in `_tick` that the first implementation missed and that would have stopped the boat in the field while passing its own tests, plus a duplicate payload key. The dashboard badge no longer claims a stop it cannot verify, using advisory wording only on an affirmative fresh report so simulation is unaffected. Coverage bridge `67`, helper `73`, dashboard `101`. Both bundle members changed, so the bundle certified earlier today is stale and needs a fresh transfer before advisory mode can be used. |
| ESC start threshold measured | 🟡 02/09/2026 — both propellers start from rest at demand `0.15`, `996 us`, `+14.0%` of the `800/800/2200` rail, steering at `0`. The former `0.12` ceiling capped output `28 us` below that, so it could never have started them; the new `0.20` ceiling leaves about `70 us` of usable band above break-away. An earlier same-session claim that the threshold sat at the ceiling is withdrawn. Also records a calibration-interface finding, not repaired: observations correlate to the plateau held at release rather than the transition, and the terminal observation is one-shot per side, so a value entered at the wrong plateau cannot be corrected without a fresh session. |
| T3a run closeout and capture verdict | 🟡 02/09/2026 — both supervisors stopped in the documented order and exited `status=0 cleanup_rc=0`, ports free and no survivors. Pi evidence `real_fcu_t3a_pi_20260902_180626` copied to `/home/ghostzero/Desktop/pi_run_evidence/` with the typed safe closeout recorded. The capture artifact holds `59m18s` armed, `106,339` events, `invalid_status_count 0` and publisher binding `pass=true`, ending latched `EMERGENCY_STOP` disarmed with both servos at `800`. The verdict is `pass:false` because `calibration` is `null` on both sides and no operator observation was recorded, so the `996 us` figure is prose only. |
| Single workstation entry point | 🟡 02/09/2026 — `tools/real_fcu_full_stack_workstation.sh` and its suite reduce the workstation to one command, sequencing both supervisors and the capture node and stopping them VRX-first, real-FCU-last. It re-implements no guard. Two findings: a plain background child inherits `SIGINT` ignored so its stop handler never runs, fixed with job control and covered as a regression; and `tools/test_fcu_to_vrx_workstation.sh` is non-hermetic under exported `FCU_VRX_*`, recorded and not repaired. Both supervisor preflights pass. The entry point has met no Pi or flight controller. |
| FCU-to-VRX suite made hermetic | 🟡 02/09/2026 — the supervisor's own check now passes from a shell carrying the eleven `FCU_VRX_*` values, where it stopped at `missing live-read configuration was accepted`. The suite scrubs the `FCU_VRX_*` and `FCU_TO_VRX_*` families once before any case. Three cases added, `33` to `36`, bound to the real entry call through a reserved-argument probe, with a control against vacuous passes and a polluted nested run. Proved load-bearing: narrowing the scrub to one family is caught only by the new probe. Runbook pin refreshed to `94d1825`; marker reads `shell_cases=36 python_tests=48`. |
| First Hailo-enabled READY; advisory latch, stop liveness and Pi window | 🟡 03/09/2026 — one command per machine reached `REAL_FCU_T3A_READY=PASS ... person_alert=advisory-no-stop` on bundle `929831e`, the first Hailo-enabled READY on hardware. A person still latched the stop because the W1-launched person monitor kept `latch_emergency_stop:=true` on the shared `/planning/emergency_stop` topic; W1 now honours the advisory flag at the monitor. The entry point misjudged W1's clean stop because the ROS 2 CLI daemon inherits the spawning process group; liveness is now by pid with a pgid straggler sweep and a truthful exit status. `REAL_FCU_HAILO_LOCAL_DISPLAY=1` opens hailo-apps' native window on the Pi desktop. Suites `79` and `14`, commit `7cf684b`, transferred to `bundle_20260903_7cf684b`, certification pending. |
| Advisory mode proven on hardware | 🟢 03/09/2026 — armed with a person in frame, `96` detections against `0` latches and `0` E-stop publications over a `30` s joint capture (`advisory_proof_20260903_183827`). Enabled by fixing a single-shot read of the latched `/mavros/state` that stopped the restart with a three-second-older `connected:false`; the snapshot guard now retries as the probe gate does. UART counters show the Pi window does not touch the link (`fe +36`, `oe +1` over `6.9` MB). Window resizable; Hailo-mode start hint added. `a8bed50` deployed and certified. |
| ESC start threshold reference | 🟢 03/09/2026 — operator-recorded on the armed `a8bed50` run: steering `±0.14` at throttle `0` starts one side at `994` us (`13.9 %`), throttle `0.15` at steering `0` starts both at `996` us (`14.0 %`); break-away about `14 %` of the rail. Reference figure; the typed capture calibration is not, and the `t3a` requirement for it should be decoupled from the verdict. |
| Full showcase held on hardware | 🟢 03/09/2026 — one command per machine; Hailo images on the dashboard and in a resizable Pi window; two-way twin with demand reaching the propellers; advisory person detection with `0` latches across a `42` min armed run; Herelink arm/disarm live on the dashboard; clean ordered stop. Verdict artefacts from the new stop order (E-stop pressed after the capture ends) and the calibration requirement are open items. |
| Stop-path fixes proven on hardware | 🟢 04/09/2026 — the corrected order and the marker burst held: the Pi received the workstation stop marker unaided (`marker=received`, `PI_EXIT status=0 cleanup_rc=0`), the workstation exited `status=0 stop=clean`, and the `t3a` verdict carried only the two calibration reasons. Before the run, a Pi kernel update (`1063` to `1064`) had removed the Hailo driver; headers installed, DKMS rebuilt, node back in six minutes. |
| Auto-move first run | 🟢 04/09/2026 — by keyboard hold: straight then right at throttle `0.20`, steering `0.18`, left `1315` us and right `1066` us, hull turned right, side label matches the mixer; `8` runs of `10` s or more, both sides. Open: the mouse hold releases after one frame because the status text reflows the box and moves the button from under the pointer; fix (pointer capture, fixed-height status line) awaiting approval. |
| Hold-button pointer capture | 🟡 04/09/2026 — the mouse-hold fix landed the same evening: both hold buttons capture the pointer on press; the auto-move status line reserves the tested two-line phase height, while pointer capture remains the continuity mechanism under any other reflow. Suite `114`, four cases and three mutants, including proof that keyboard activation skips capture; browser drag test shows the release delivered after a `230` px slide off the button with no leave while pressed. Sliding off no longer releases; mouse-up anywhere does. Awaiting a hardware run. |

### Blockers

1. **Supervisor CCU conversation** — unblocks the decision to build a bridge node or not.
2. **Real-topic integration from the now-proven MAVROS endpoint** — Pi install / MAVROS launch side is green, and the `/dev/ttyAMA0:57600` path is now proven through MAVProxy fanout into MAVROS with `/mavros/state connected: true` plus first ROS telemetry samples. The 22/06 Herelink-hotspot observation proves MAVLink transport to workstation QGC, and the 16:07 packet capture identifies the sender as unicast UDP `192.168.43.1:52600` into QGC's `14550` socket. A second MAVLink consumer or ROS 2 topic source is still not proven; next read-only test should use QGC MAVLink forwarding to a separate local port for workstation MAVROS, reserving a workstation MAVProxy/router for later if forwarding is unavailable or insufficient. The 10/06 QGC `.plan` import proves an offline dashboard-cache handoff only; the 11/06 local QGC bridge proves a same-workstation visual mission surface from dashboard Generate -> Confirm to QGC, but still not real vehicle upload. Remaining blockers are GPS fix / EKF GPS configuration, targeted request/response timeout behaviour, command-path mapping, real vehicle waypoint upload, and adapting the dashboard / simulation topic contract without regressing the default VRX stack. `/dev/ttyAMA10` remains a superseded silent-line result from before the reconfiguration.

   **15/07/2026 supersession:** the workstation rosbridge/dashboard directly
   consumed the Pi MAVROS topics over DDS, so a second ROS 2 consumer and a
   view-only real-topic dashboard path are now proven. The remaining blockers
   are GPS fix, a durable selectable real-boat mode, complete endurance and
   cleanup evidence, and any dashboard-to-FCU command/write or mission-sync
   path.

   **17/07/2026 evidence boundary:** the tracked supervisor now has two bounded
   six-topic arrival/rate records, thermal peaks, copied Pi logs, and
   fail-closed cleanup evidence. The remaining lifecycle proof is specifically a
   normal Pi-first operator shutdown with post-teardown temperature, plus full
   endurance and a durable selectable mode. No command/write or mission-sync
   path was opened.

   **04/08/2026 supersession:** the normal Pi-first operator shutdown and
   post-teardown temperature named above were both obtained on 03/08/2026 and
   repeated on 04/08/2026. The remaining lifecycle items are browser-last
   ordering, full endurance, and a durable selectable mode. A separate
   daemonless graph-query defect is now tracked: its correctness fix is landed
   behind a default-off flag. No command/write or mission-sync path was opened.

   **05/08/2026 supersession:** that fix was exercised live for the first time
   and is **feasible at shipped defaults** - `18` probe runs, all `OK`, one
   run-owned participant serving all five source topics per run, a `120 s`
   window that was not truncated, final verification inside its budget, and
   `status=0` on both supervisors. Feasibility is not a fix: the defect recurred
   under the batched path in the same run, and the per-run reading count sits
   inside the flag-off control range, so no reduction is claimed. Browser-last
   ordering and the terminal data-plane probe remain unexercised. No
   command/write path was opened.

   **07/08/2026 supersession:** a command path was opened **in simulation only**.
   ArduPilot SITL is built and running on the workstation - `Rover-4.6.3` at
   `3fc7011a`, frame `motorboat-skid`, matching the boat's skid-steer
   configuration and the real controller's ArduRover `4.6.3` line - and its
   MAVLink surface is verified read-only at `tcp:127.0.0.1:5760` with a MAVProxy
   rebroadcast on `127.0.0.1:14550`. No command was sent to the simulator, the
   vehicle stayed disarmed, no code was written, and **no command/write path to
   any real autopilot was opened**. The verification produced two constraints the
   eventual bridge must satisfy. SITL and the real boat assign the same throttle
   functions (`73` left, `74` right) to **opposite channel numbers**, so a design
   keyed on channel number is correct on exactly one of the two platforms.
   And the PWM rails differ in kind, not only in value: SITL measures
   `1000`/`1500`/`2000` with neutral at mid-scale, the real boat is
   `800`/`800`/`2200` with neutral at the bottom, and `tools/servo_command_bridge.py`
   defaults to `1100`/`1500`/`1900`, matching neither - so a bridge emitting the
   simulator's neutral at the real vehicle would command substantial thrust while
   believing it commanded zero. **10/08/2026:** the command-ingress contract is
   closed and a default-inhibited workstation-only implementation now exists.
   It resolves ingress from live `RCMAP_*` and `RC<n>_*`, retains
   `SERVO*_FUNCTION` and live servo rails for output observation, and uses domain
   `42` for operational isolation rather than FCU actuation safety. Physical
   acceptance and integration with the existing shell-helper lifecycle remain
   open.

   Later the same day the **first workstation-to-autopilot command path** in this
   project was exercised, **against ArduPilot SITL on the workstation only and
   never a real autopilot**. `MAV_CMD_DO_SET_SERVO` was ruled out from source -
   `AP_ServoRelayEvents::do_set_servo` allowlists only `k_none`, `k_manual`,
   sprayer, gripper and `k_rcin*`, so it returns `false` on `k_throttleLeft` `73`
   and `k_throttleRight` `74`. `RC_CHANNELS_OVERRIDE` is the validated path, with
   `RCMAP_ROLL 1` / `RCMAP_THROTTLE 3` read rather than assumed. `mode MANUAL`,
   `arm throttle` and `disarm` were all `ACCEPTED`; RC override produced armed
   idle `1500`/`1500`, throttle `1570`/`1570` (`delta +0`), steering
   `1644`/`1496` (`delta +148`, mean `1570` with a `±74` differential), and a
   clean return to `1500`/`1500`. This adds a third constraint that partly
   supersedes the two above: **command at the RC or higher layer, not the raw
   servo layer**, because the autopilot resolves SERVO function to physical
   channel internally, so the SITL-versus-boat channel swap never reaches the RC
   path and only affects raw-channel code such as `tools/servo_command_bridge.py`.
   Simulator only: no command reached a real autopilot, no real thruster moved,
   the boat's `800/800/2200` neutral-at-bottom rail means none of these PWM
   figures transfer. The 10/08 design-only command-ingress contract is now written.

   **10/08/2026 runtime addendum:** a new bounded workstation-only acceptance reran the
   MAVProxy RC-override path while MAVROS and the browser dashboard were isolated on
   `ROS_DOMAIN_ID=42` with localhost-only discovery. Live reads again resolved
   function `73` to `SERVO1`, function `74` to `SERVO3`, both servo rails to
   `1000`/`1500`/`2000`, and steering/throttle to RC channels `1`/`3`. The browser
   rendered disarmed and armed neutral at `1500`/`1500`, symmetric throttle at
   `1570`/`1570`, and the discriminating steering step at `1644`/`1496` (`delta
   +148`). `rc all 0` left that last output present; explicit live RC trims were
   required to recover `1500`/`1500` before disarm. The two temporary SITL
   prerequisites were restored to `RC_OVERRIDE_TIME=3.0` and `ARMING_RUDDER=2`,
   and all local services stopped. This is runtime evidence for the bounded operator
   path and dashboard telemetry, not implementation or acceptance of the production
   command-ingress bridge. No Pi, physical controller or real thruster was involved.

   A later default-inhibited implementation adds a narrow browser
   `/command_ingress/rc_axes` input, MAVROS RC override conversion and a separate
   `/mavros/rc/out` measured-feedback row. Its direct dashboard E-Stop latches live
   RC trims, and its shutdown publishes neutral or release frames before the ROS
   context closes. It does not constitute physical acceptance or open a physical tier.
   The same-day operator-supplied Pi transcript received heartbeat but no parameter
   values and showed an already-armed startup; both conditions make the prototype
   abort, and no repository process sent a physical command.

   **10/08/2026 implementation acceptance:** the corrected bridge was started
   against a clean `motorboat-skid` SITL with launch-time
   `RC_OVERRIDE_TIME=0.5`, `ARMING_RUDDER=0` and `BRD_SAFETY_DEFLT=1`. The live
   guard resolved RC channels `1`/`3` and `SERVO1`/`SERVO3`; after safety-off it
   reported fresh `READY_DISARMED` feedback at `1500`/`1500`, and normal arming
   reached `ARMED_NEUTRAL`. Two screen recordings show the browser reaching
   `ACTIVE`: `+0.10` steering with `0.08` throttle measured RC `1577`/`1567` and
   servo `1585`/`1485`, while `-0.04` steering with `0.09` throttle measured RC
   `1452`/`1572` and servo `1520`/`1559`. Both returned to measured neutral, and
   normal disarm received `MAV_CMD_COMPONENT_ARM_DISARM: ACCEPTED`. The terminal
   status capture did not overlap either active interval, so it proves neutral
   stability but not the commanded transitions. Complete machine-readable
   capture and helper-owned startup/teardown are the remaining simulator work.
   This is not physical-FCU or real-thrust evidence.

   **11/08/2026 helper update:** the first helper-owned SITL attempt stopped at
   the Rover-listener gate. `sim_vehicle.py` had delegated Rover to a display
   terminal outside the supervisor-owned process group, so the runner could not
   certify ownership or retain the Rover output. The corrected runner directly
   starts the pinned binary in its run-owned state directory and no longer asks
   for bridge shutdown frames when bridge startup was never reached. Focused
   tests pass; the corrected SITL runtime remains unrun.

   A separate two-host physical-FCU helper pair is also prepared on domain `43`
   with subnet discovery, isolated from the domain `42` localhost-only SITL
   graph. The Pi owns direct serial MAVROS, first as a read-only T0b
   safety/parameter probe and then as a separately approved telemetry/command
   session; the workstation owns the loopback browser services and accepts only
   a fresh `READY_DISARMED` bridge status before showing the mapped bench URL.
   The shared bridge has no default domain authority: each runner must supply
   the expected domain explicitly, and helper conflict checks reject opposite
   stack ownership on the same host. This is implementation and static test
   evidence only. T0a is still the first hardware gate, and no physical tier or
   real-thrust result is claimed.

   **18/08/2026 supersession:** the preceding 11/08 status is historical. The
   complete simulator path passed on 17/08, powered-down continuity closed T0a,
   and the 18/08 Pi deployment plus `check` passed. The first read-only probe
   received a heartbeat but did not complete the MAVROS parameter-list exchange;
   it was operator-stopped before its deadline and produced no T0b parameter
   artifact. T0b is now the first open physical gate. No parameter write, bridge
   start, physical command or real-thrust result occurred.

   The operator then confirmed the 18/08/2026 end state: controller/control box
   and Pi off, propulsion isolated, propellers removed, hull restrained, hardware
   safety restored, and Herelink sticks and trims neutral. This closes the
   physical session without changing the open T0b boundary.

   **19/08/2026 supersession:** the capture path was repaired and covered, its
   manifest was regenerated, and a new dated five-file deployment passed exact
   inventory, pinned-manifest, `4/4` member verification and the helper's
   non-actuating `check`. The T0b probe itself did not run: Block E was deferred
   to a later day while its safety review remained pending. The unused approval
   does not cross the date boundary. T0b therefore remains the first open
   physical gate; T1, both T2 tiers and real thrust remain closed.

   **25/08/2026 supersession:** the direct `/dev/ttyAMA0:57600` endpoint is no
   longer generically receive-only. A Pi-local MAVProxy session received an
   accepted arm command acknowledgement and then an accepted disarm that ended
   explicitly `DISARMED`. This proves a state-changing command/ACK exchange but
   not a successful parameter exchange, RC override, changed servo output or
   workstation-originated command. The operator reports that the professor
   repaired the workstation command path; a correlated workstation-to-Pi-to-FCU
   trace is still required to promote that report to captured evidence. The
   full-scale FCU-to-VRX target moves to a fresh 26/08/2026 session with real
   electronics active and propellers removed. No current approval carries.

   **26/08/2026 supersession** (superseded in part; see the 27/08/2026 forward correction at the end of this entry): the full current-source SITL acceptance passed,
   then guarded real-FCU Test A passed with a pinned parameter snapshot and
   measured non-neutral output feedback. The dashboard request, measured RC
   input, real `SERVO3`/`SERVO1` output and neutral restoration were retained,
   and both supervisors closed connected/disarmed with successful ordered
   teardown. This closes Test A only. The Herelink-to-UDP-`14555`-to-VRX Test B
   remains **NOT RUN** and moves to 27/08/2026. Its physical declaration and
   approval must be fresh, and the temporary `RC_OVERRIDE_TIME=0.5` must be
   restored to `3.0` with live readback after Test B or before any different
   operation.

   **27/08/2026 forward correction:** the SITL acceptance above is no longer
   current-source. `81efb73` later changed `tools/real_fcu_rc_command_bridge.py`,
   the bridge `tools/sitl_digital_twin_runner.sh` launches under test, and no
   `SITL_VERDICT` or `SITL_ADJUDICATION` has been recorded against a revision
   containing it. The query tier (T0b) was never closed either. Both gates must
   close on current source, or receive an explicit operator supersession, before
   Herelink-to-VRX Test B starts.

   **27/08/2026 closure:** the live workstation-only frame capture confirmed
   `/wamv/pose` contains `sydney_regatta -> wamv` as its sole world-parented
   transform and contains no child ending in `base_link`. The complete
   supervised SITL path was then rerun on clean revision `147efe0` in
   `/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`. It produced
   `SITL_VERDICT=PASS`; independent adjudication checked ten hashes and passed
   the control cross-check, stop order, verdict, teardown, ports, governed
   processes and final `SITL_ADJUDICATION=PASS`. The current-source SITL gate is
   closed. T0b remains open and Test B remains **NOT RUN**.

   **Later 27/08/2026 update:** the pinned snapshot-backed T0b probe passed all
   `41` selected reads while retaining live connected/disarmed and
   hardware-safety checks, so T0b is closed. Revisions `aa4a07a` and `1c1dff5`
   then landed the disarmed recorder and subscriber-ordering repair. A live
   disarmed run reached W1 seven-topic/rate acceptance and W2 four-stream
   READY, measured all stream gaps, PWM skew, thrust delay and stationary pose
   drift, and passed Pi, W2 and W1 teardown. The measurement and explicit-limit
   gates are closed. Test B remains **NOT RUN** pending current-revision SITL
   acceptance or explicit supersession, a clean published worktree and a fresh
   physical declaration.

   **Armed-attempt update:** the approved `eb9a337` run captured asymmetric
   real-FCU output, mapped thrust and `2.47946 m` of VRX motion, but the fixed
   armed deadline aborted the Pi before final disarm and hardware-safety
   restoration were captured. Test B is **ATTEMPTED - FAILED / NOT ACCEPTED**.
   The explicit paired-zero retry repair removes the armed and outer runtime
   deadlines only, retains the remaining fail-closed gates, defaults the Pi
   display to resizable and uses W2, W1, Pi teardown after recorded completion.
   **Publication update:** the repair is published as `d9dd120`; it remains
   unrun live and requires revision-specific SITL acceptance or explicit
   supersession, a fresh physical declaration and separate live approval.

   **Paired-zero retry update:** clean revision `550b992` reached P1's
   connected/disarmed neutral hardware-safe baseline with both duration limits
   disabled, but never armed. P1 then failed after three graph views reported
   zero publishers for `/mavros/global_position/raw/fix`, despite retained
   NavSatFix data and W1 measuring `4.00 Hz`. P1 teardown passed; loss of its
   streams caused the downstream W1/W2 stale-stream failures before both
   workstation stacks cleaned up. The first attempt still proves the functional
   Herelink-to-real-FCU-to-VRX motion interval from machine evidence and operator
   observation, but no video or accepted final-safe-state record exists. Test B
   remains **ATTEMPTED - FAILED / NOT FORMALLY ACCEPTED** pending the minimal
   source-verifier repair and a direct W1, W2, P1 retry.

   **EOD source-verifier repair:** the existing bounded six-topic `rclpy`
   source view is now the default, with exact publisher-count and `/mavros`
   identity verdicts unchanged; explicit `LIVE_MAVROS_SOURCE_BATCH=0` retains
   the legacy daemonless CLI diagnostic path. W1 now reports each governed
   child PID/PGID exit once in failure hold. Focused Pi and W1 suites pass. The
   direct W1, W2, P1 live retry remains outstanding, so formal Test B
   acceptance stays open.

   **28/08 morning correction:** a fresh generation created by a later-topic
   recovery could leave an already-checked earlier-topic block pending across a
   verification boundary. The consumer now discards entries through the
   recovered topic, and a focused case requires a new generation for the next
   phase. W1 explicitly carries source batch `1` and the `180 s`
   final-verification budget into P1. These corrected bytes remain offline-only.

   **28/08 pre-arm arrival update:** the corrected Pi helper reached its safe
   disarmed baseline and W2 reached four-stream READY, but W1's separate
   publisher-arrival precheck timed out before sampling, Pi-observer startup or
   arm. W1 now retains topic sightings across polls, uses monotonic timing and
   reports exact unresolved topics. The focused `25`-case suite passes offline;
   formal Test B acceptance remains open.

   **28/08 repaired live result:** clean revision `6beb603` passed the repaired
   W1 arrival and seven-topic rate gates, P1's safe baseline and W2 four-stream
   READY. The first retained asymmetric output `800/1033` matched the bridge in
   `4.124019 ms`, mapped to `0.0/133.142857 N`, reached both thrust topics in
   about `1.1 ms`, and produced `3.480079 m` of motion inside `10 s`. Neutral
   return and zero thrust were also retained, and the operator directly
   observed Herelink-driven VRX motion. A later external interruption was
   followed by stale `/mavros/state`, stale left thrust and loss of
   `/dev/video4`. The copied Pi evidence is
   `/home/ghostzero/Desktop/pi_run_evidence/test_b_functional_interrupted_20260828_155345`;
   its peak was `70500 mC`, below the `80000 mC` limit, with no thermal-abort
   record. The last retained FCU state remained connected and armed, and the
   canonical adjudicator fails on the Pi observer abort. Functional motion is
   demonstrated, but Test B remains not formally accepted. No post-run
   rollback readback was retained, so the documented
   `RC_OVERRIDE_TIME=0.5` to `3.0` rollback remains open.

   **Later 28/08 Enhanced Test A and rollback update:** the guarded dashboard
   and Pi helpers reached READY and completed connected/disarmed ordered
   teardown. The operator corrected the active interval to propellers fitted
   and reported limited one-sided rotation, but the retained files contain only
   neutral RC/output snapshots. The launch assertion
   `REAL_FCU_PROPELLERS_REMOVED=1` was inaccurate for that interval, and the
   observation is neither T2b nor T3a acceptance. The exact `+/-0.20`
   steering endpoints remain unusable because `float32` transport exceeds the
   bridge's exact comparison. The
   separately approved rollback subsequently captured live
   `RC_OVERRIDE_TIME=0.5`, set and re-read `3.0`, retained `986` parameters at
   SHA-256
   `a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`,
   copied the artifact to
   `/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828`, and
   left the serial endpoint free. This supersedes only the preceding
   rollback-open sentence; Test B remains not formally accepted.

   **31/08/2026 forward update:** the complete SITL acceptance and independent
   adjudication passed on exact revision `3ca4c9b`. The subsequent narrow bridge
   repair normalizes only the exact float32 encoding of each configured
   steering or throttle endpoint, keeps negative throttle fail-closed and
   leaves both authority limits unchanged. The next adjacent float32 is also
   rejected. The focused suite passes `36` tests, but the source edit reopens
   current-source SITL and requires a new bundle transfer before Pi use. The
   command path is paired end to end; one-sided output is consistent with the
   skid mix when steering dominates throttle. The straight-throttle ESC start
   threshold remains unmeasured, so no authority or `MOT_THR_MIN` change is
   justified. A threshold measurement remains a separately approved,
   propellers-removed calibration with correlated demand, RC-input and
   servo-output capture.
   *Forward note 03/09/2026: measured since, propellers fitted - break-away
   about `14 %` of the rail, `996` us at throttle `0.15`; ceiling `0.20` since
   02/09/2026. See [Real-FCU Digital Twin Runbook](Real_FCU_Digital_Twin_Runbook).*

   **Later 31/08/2026 closure:** clean revision
   `bba195b19a0f06a874bfbcbcbbd1621524cbce60` passed the complete supervised
   SITL acceptance in
   `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839`. Independent
   adjudication retained at
   `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log`
   checked all ten hashes, the control cross-check, exact stop order and
   teardown, with governed ports free and governed process patterns absent,
   before ending `SITL_ADJUDICATION=PASS`. This
   closes the current-source SITL gate for the repaired runtime path. The
   regenerated bundle still requires a separately verified transfer and
   checksum before Pi use; no Pi or real-FCU hardware participated in this
   closure.

   **Later 31/08/2026 Pi deployment closure:** the regenerated bundle was
   installed at
   `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260831_bba195b` with an
   exact five-file inventory. The pinned manifest digest and all four governed
   member hashes passed, followed by
   `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The
   independently reverified workstation copy-back is
   `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260831_bba195b`.
   This closes transfer/checksum and non-actuating Pi certification only; no
   probe, MAVROS or bridge runtime, parameter write, arm or propulsion action
   ran, and no hardware approval carries forward.

   **01/09/2026 T3a source supersession:** the source now separates the
   demand-enabled props-fitted `run-t3a` Pi runtime from the subscriber-only
   `t3a --esc-threshold-calibration` recorder. T3a keeps the existing command
   limits and final-safe-state contract while adding mutually exclusive tier
   gates, explicit guarding/exclusion declarations, propulsion-enable evidence
   and bounded closeout handling that remains fail-closed under signals while
   still reaching final-state capture and child stops. Focused tests pass, but the result is
   **OFFLINE IMPLEMENTATION / NOT RUN / NOT DEPLOYED**. The certified
   `20260831_bba195b` root remains exact evidence for its own revision only; a
   new commit-named Pi deployment and non-actuating certification must close
   before a fresh live declaration or T3a approval is requested.

   **Later 01/09/2026 T3a deployment closure:** clean published revision
   `025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba` was deployed to
   `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c`. Exact
   five-file inventory, executable helpers, manifest digest
   `11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d`
   and all four governed hashes passed. The non-actuating helper check ended
   `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`; the
   independently reverified copy-back is
   `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`.
   This supersedes only the preceding deployment prerequisite: T3a remains
   **NOT RUN**, with no probe, MAVROS or bridge runtime, parameter write, arm,
   propulsion action, acceptance or Block E authority.

---

## 4. Research Extensions — Architecture

Research layers sit *on top of* the navigation foundation, not inside it. This separation keeps both independently testable and keeps today's navigation stack untouched by research code that may iterate more aggressively.

```text
┌────────────────────┐
│  Navigation stack  │  (existing — perception, planning, control, dashboard)
│   — position       │
│   — mission state  │
└─────────┬──────────┘
          │ position, timestamp
          ▼
┌─────────────────────┐         ┌─────────────────────┐
│ Water-quality mock  │  or  →  │ Water-quality driver │  (Phase D — real probe)
│ sensor (Phase A)    │         │                      │
└──────────┬──────────┘         └──────────┬──────────┘
           │  /water_quality/readings (JSON-over-String)
           ▼
┌─────────────────────┐
│ CA propagation node │  (Phase B)
│  — 2D grid          │
│  — per-param update │
└──────────┬──────────┘
           │  /water_quality/field (JSON-over-String)
           ▼
┌─────────────────────┐
│ Dashboard overlay   │  (Phase C — Leaflet heatmap)
└─────────────────────┘
```

Key property: **no bidirectional coupling.** Navigation does not depend on research topics; the research stack consumes position + sensor data and produces a map. This lets Phase 5 hardware bring-up proceed in parallel with research-stack development.

The layered pattern shown above is positioned against the ISO/IEC 30141:2024 IoT reference architecture and the ISO 23247:2021 manufacturing DT specialization in [Digital_Twin_Architecture](Digital_Twin_Architecture).

---

## 5. Phase A — Mock water quality sensor (consulting scope)

> **Intent:** this section is deliberately consultative — it surfaces options, trade-offs, and open questions rather than prescribing *the* design. Intended readers: the intern (for self-alignment), supervisors (for scope agreement), and future collaborators (for context).

### 5.1 Why this first

Phase A is the single piece of the research stack that unblocks Phases B and C **without requiring any hardware or dataset access**. Starting here lets downstream work (CA node, dashboard overlay) develop in parallel with Phase 5 hardware bring-up, and lets the whole pipeline be demonstrated end-to-end in simulation before any real probe arrives. It also produces a reference implementation that the eventual real-probe driver (Phase D) can conform to.

### 5.2 What the mock is — and what it is not

**It is** a standalone ROS 2 node that publishes synthetic water quality readings at a realistic rate, tied to the boat's current GPS position. It is designed to be the source-of-truth upstream of Phase B and Phase C during the months where no real probe is available.

**It is not** a physics-accurate hydrological model. The point is to exercise the downstream interface (CA node + dashboard overlay), not to pretend to be a real lake. A second-order property (stability of downstream consumers when readings change) matters; first-order accuracy (what the reading "would be" in a real lake) does not.

### 5.3 Open design questions

Each of the following has more than one defensible answer. Final choices should be confirmed with the supervisor and collaborators before implementation.

#### (a) Which parameters to publish?

**Known:** the objectives document does not name a fixed parameter set; it mentions "key water quality parameters" without enumerating them. Standard multi-parameter probes (e.g., Atlas Scientific, In-Situ Aqua TROLL) typically cover:

- **pH** — acidity / alkalinity, unitless
- **Turbidity** (NTU) — suspended solids / water clarity
- **Dissolved oxygen** (mg/L or % saturation) — aquatic life indicator
- **Temperature** (°C) — baseline for almost everything else
- **Conductivity** (µS/cm) — total dissolved ions
- **ORP / redox** (mV) — oxidation-reduction potential
- **Chlorophyll-a** (µg/L) — algae indicator, requires fluorometer

**Recommended default for the mock:** pH, turbidity, DO, temperature. Four parameters, all commonly prioritized in regional freshwater monitoring, all with straightforward synthesis models. **To be confirmed with supervisor.**

**Design mitigation for uncertainty:** the message schema should be a **generic parameter dictionary** (`{"params": {"pH": ..., "turbidity_ntu": ..., ...}}`) rather than fixed fields. Adding / removing a parameter later becomes a 3-line change in the mock's publish loop — not a protocol rewrite. Downstream consumers (CA node, dashboard) iterate over the dict.

#### (b) Message type: JSON-over-String vs. custom `.msg`?

**Option JSON-over-String:**

- Consistent with all existing status topics in this repo (`/planning/mission_status`, `/control/status`, `/perception/obstacle_info`).
- Zero new dependencies, no interface package, no cross-language codegen.
- Dashboard already has `logBadJson` for visible error handling of malformed frames.
- Schema documented in prose, not enforced by the type system.

**Option custom `.msg`:**

- Type-safe, auto-generated bindings for Python / C++ / JS (via rosbridge).
- Requires a new interface package, adds a build-time dependency.
- Schema changes force a recompile of every consumer.

**Recommendation:** JSON-over-String, to stay consistent with repo conventions. If the research layer later grows to the point where schema drift is a real problem, migration to `.msg` is a bounded later task.

#### (c) Publish rate

**Known:** real multi-parameter probes typically publish at 1 Hz. Regional monitoring networks often collect at much lower rates (one sample per minute to per hour) because parameters evolve slowly.

**Options:**

- **1 Hz** — matches typical real-probe output; gives CA node enough data density to show spatial variation as the boat moves.
- **0.2 Hz** (one sample per 5 s) — cheaper; still enough to paint a useful map along a typical lawnmower trajectory.

**Recommendation:** 1 Hz default, parameter-tunable via YAML. Gives headroom; downstream consumers can subsample if load becomes a concern.

#### (d) Spatial synthesis model

The mock needs a rule that takes `(lat, lon)` and returns a plausible reading. Four options, ordered by complexity:

| Option | How | Use when |
|:------:|:----|:---------|
| **1** | Constant per parameter (e.g., pH always 7.2) | Pure interface smoke test — proves downstream consumes the data. No spatial variation to show on a map. |
| **2** | Linear gradient along a principal axis (e.g., pH rises from north to south) | Minimal model to prove CA + heatmap actually render spatial variation. Easiest to reason about. |
| **3** | 2D field with Gaussian "hotspots" at configurable lat/lon centres | More interesting visually; lets you test the CA node's ability to track localized anomalies. |
| **4** | Ground-truth field loaded from a seed file (CSV of measured points, interpolated) | Closest to real data. Requires a small dataset. |

**Recommendation:** start with **option 2** (linear gradient). Migrate to **option 3** once Phase B is running and we want to stress-test hotspot detection. Option 4 is a later-phase enhancement that overlaps with Phase E (validation).

Add small Gaussian noise on top of whichever field model is chosen — real probe readings are never exact. Noise magnitude should be a YAML parameter.

#### (e) Topic name

**Recommendation:** `/water_quality/readings` — parallel to the existing `/perception/*` and `/planning/*` namespaces.

#### (f) Where the node lives

**Options:**

- `plan/plan/water_quality_mock.py` — adds it to the existing `plan` package. Minimal scaffolding; no new `package.xml`.
- New package `water_quality/` — cleaner separation if the research stack is expected to grow to several nodes (CA + mock + heatmap backend).

**Recommendation:** new package `water_quality/` (mirrors `plan/` and `control/`). Phase B's CA node and any future Phase D driver also live there — the research stack becomes self-contained and easy to reason about. One-time cost: adding a package.xml and setup.py.

#### (g) What the message payload carries

Minimum viable schema:

```json
{
  "timestamp": 1714038000.123,
  "position": {"lat": -33.72, "lon": 150.67, "x": 12.4, "y": -8.2},
  "params": {
    "pH": 7.15,
    "turbidity_ntu": 4.3,
    "dissolved_oxygen_mgL": 8.6,
    "temperature_c": 18.2
  },
  "source": "mock",
  "probe_health": "ok"
}
```

Rationale:

- `timestamp` lets the CA node time-align readings.
- `position` carries both global (lat/lon) and local (x/y, metres from GPS origin) — matches existing repo convention where both are already computed in the planner.
- `params` is the generic dictionary from §5.3(a).
- `source` lets the real-probe driver (Phase D) be dropped in without CA-node changes — downstream doesn't care whether the data is mock or real.
- `probe_health` forward-compat field so the real driver can signal calibration errors later.

### 5.4 Proposed minimal viable Phase A

**Scope for the first implementation iteration:**

1. New `water_quality/` package with a single node `water_quality_mock_node`.
2. Subscribes to `/wamv/sensors/gps/gps/fix` for position.
3. Publishes `/water_quality/readings` at 1 Hz using option 2 (linear gradient) + Gaussian noise.
4. Four parameters: pH, turbidity (NTU), DO (mg/L), temperature (°C).
5. Tunable via launch YAML: rate, noise amplitude, gradient direction, gradient magnitude per parameter.
6. Visible in `ros2 topic echo /water_quality/readings` and logged in the dashboard event log once subscribed.

**Out of scope for Phase A:**

- CA propagation (Phase B).
- Dashboard visualization (Phase C).
- Real probe driver (Phase D).
- Dataset-backed spatial field (Phase E prerequisite).
- Multi-parameter correlation (e.g., DO depending on temperature).

**Estimated effort:** one focused session of ~2-3 hours for the node + launch entry + basic test (`ros2 topic echo` + dashboard event log confirmation).

### 5.5 Risks and dependencies

| Risk | Severity | Mitigation |
|:-----|:--------:|:-----------|
| Parameter set changes after supervisor confirmation | Low | Generic param dict schema absorbs the change |
| Real probe eventually arrives with different units than the mock's defaults | Low | Units are part of the parameter key (e.g., `turbidity_ntu`, `dissolved_oxygen_mgL`) — explicit, Phase D conforms |
| Overlap with existing `/perception/obstacle_info` publish load on rosbridge | Low | 1 Hz is negligible next to LiDAR + GPS streams |
| Phase A becomes the permanent data source (real probe never arrives / never works) | Medium | Document in the node docstring that it is a stand-in; Phase D replacement is a planned task |

### 5.6 Suggested validation

Phase A is validated when:

1. `ros2 topic echo /water_quality/readings` shows well-formed JSON at 1 Hz.
2. Launching a lawnmower mission produces readings whose values drift predictably with position (proves the gradient model is wired correctly).
3. Dashboard event log shows no `Malformed JSON on /water_quality/readings` entries (proves the schema is stable under the JSON guard at the publisher).
4. Stopping / resuming the mission does not affect the readings publisher (proves independence from navigation state).

No in-simulator water is simulated. The mock does not need VRX cooperation.

---

## 6. Phases B – E (sketches, not yet scoped)

These are recorded here to pre-empt scope drift and to make dependencies visible. Each phase gets its own consulting-style scope document when it becomes the active work item.

### Phase B — Cellular-automata propagation node

- Subscribes to `/water_quality/readings` + GPS.
- Maintains a 2D spatial grid over the survey area (extent TBD — likely from a dedicated survey-area polygon parameter, or inferred from the lawnmower bounding box).
- Per-parameter update rule: assimilate the new reading at the boat's current cell; propagate outward via a simple CA update (diffusion; optionally advection from a supplied current vector field).
- Publishes the grid as `/water_quality/field` at, say, 0.5 Hz.
- Open questions: cell size (1 m? 5 m? 10 m?); update rule (pure diffusion? diffusion + decay? coupling between parameters?); handling of never-observed cells (NaN? default? interpolated?).

### Phase C — Dashboard heatmap overlay

- Subscribes to `/water_quality/field`.
- Renders as a Leaflet heatmap layer (e.g., `leaflet.heat` plugin) or a custom canvas overlay.
- UI: per-parameter layer toggle, colour-scale legend, optional "show raw readings" overlay for QC.
- Consumes the existing map panel — reuses boat-position and waypoint rendering.

### Phase D — Real probe integration

- Blocked on probe hardware identification and delivery.
- Replaces the Phase A mock with a driver node speaking the probe's protocol (typical: serial at 9600 / 38400 / 115200 baud, ASCII or binary framing).
- Same topic contract as Phase A (`/water_quality/readings`), same schema — by design.

### Phase E — Validation + ML

- **Validation approach (locked 30/04/2026):** same-day cross-validation. Collect partial-coverage data along two routes R₁ + R₂ in a single outing; hold out R₂; train the CA on R₁ only; predict R₂ from CA; compare to held-out R₂ measurements. No temporal-change confound on the model error. Day-gap return visits are acceptable for slow-changing parameters only (e.g., conductivity in a stable closed lake), not for dynamic parameters (DO, turbidity post-disturbance). See §1.1 for the meeting rationale.
- The "regional datasets" pathway (CESER / CPER ECRIN / VERD-Eau / CASTREau / CAP'Eau) is **out of scope** as of 30/04/2026 — accessible historical data for the project's region is insufficient. The Obj 3 wording in §1 is preserved for traceability against the formal document; the implementation interpretation is the cross-validation approach above.
- Validation metrics: RMSE per parameter on held-out R₂; spatial correlation between predicted-vs-observed; per-parameter coverage of the cross-validation across multiple outings.
- ML component (time-permitting), refined 30/04/2026:
  - **Residual-based anomaly detection** — flag measurements where `|real − CA-predicted|` exceeds a threshold. Statistics on top of CA; light-touch.
  - **Time-series forecasting** — ARIMA / Prophet / LSTM on the time series of measurements for trend prediction.
  - **Physics-informed ML (stretch)** — use CA as a physics prior, train ML to predict the residual between CA and reality. Learns systematic CA error.
  - The discarded framing "ML trained on CA outputs" was rejected in the 30/04 meeting — training on a model's outputs just relearns the model. See §1.1.

---

## 7. Open questions — supervisor conversation

> **Update 30/04/2026:** the smaller-scale on-site scoping meeting (§1.1) answered or refined several items. **Answered:** Phase E #1 (regional datasets — out of scope) and the ML framing (residual-based / time-series / physics-informed — see §1.1). **New questions surfaced** on CA placement and validation methodology (§1.2); folded into the relevant subsections below.

Questions that unblock specific next steps. Organised by phase.

### Pre-Phase-A (parameter set)

1. Which water quality parameters are in scope for this internship? Confirm vs. the recommended default set (pH, turbidity, DO, temperature).
2. Are any parameters *required* to appear in the research deliverable (e.g., for regional-dataset alignment)?

### Phase 5 (Pi 5 bring-up — see also the scope plan in `working_diary/`)

1. Is there a separate low-level CCU between the Pi 5 and the thrusters, or does the Pi drive them directly? (23/04/2026 MP/QGC signal leans toward separate MAVLink autopilot — needs explicit confirmation.)
2. If separate: what chip, physical link, protocol? Any existing ICD / firmware?
3. If autopilot: **ArduPilot or PX4?** What's the MAVLink connection topology between autopilot and Pi 5 — serial (USB/UART), Ethernet, onboard MAVLink-router? Default `14550/udp` or custom?
4. Thruster type and thrust range (for mapping the current 0–800 VRX scale to real Newtons / PWM duty)?
5. Test-lake or test-site GPS coordinates for the geofence polygon?

### Phase D (real probe)

1. Probe make / model, protocol (serial? I²C? CAN?), output rate, power requirements?
2. Probe mounting plan on the boat?

### Phase E (validation & ML)

1. ~~Which regional dataset can we obtain access to, and in what format?~~ — **Answered 30/04:** out of scope (insufficient accessible historical data). Validation now uses same-day cross-validation; see §1.1 + §6 Phase E.
2. ML scope refined 30/04 (see §1.1) — residual-based anomaly detection + time-series forecasting + physics-informed ML (stretch). **Open:** which subset of the three is the priority for the deliverable?
3. **(new 30/04)** Validation methodology — confirm same-day cross-validation as the primary approach; clarify which parameters are slow-changing enough to permit a few-days' return-visit fallback.
4. **(new 30/04)** CA model compute placement — Linux workstation (recommended) or Pi 5?

### Process

1. Expected delivery format — live demo? Written report? Conference-paper draft?
2. Timeline checkpoints between now and end-of-internship?

---

## 8. Sim infrastructure — VRX upstream fork (active since 06/05/2026)

> **Status:** forked 06/05/2026 to `Ghostzero00018/vrx` (basename invariant — `patch_vrx.sh:20` hardcoded local path `$WS_ROOT/src/vrx/`). The original §8.5 "explicit not now" was overridden as a deliberate scope expansion: 0/4 §8.2 triggers had fired at the time of fork, but the call was taken ahead of upstream pressure to unblock future hardening (CI on the fork, freer custom-mod surface, the eventual Phase 5+ sim-side integrations). The decision-rationale framework below (§8.1-§8.5) is preserved as the audit trail of how the call gets made when triggers DO fire in future re-evaluations. See §8.6 Migration log for the landing detail and §8.7 for the sync workflow.
>
> **Teammates with a pre-06/05/2026 VRX checkout** (i.e., `~/seal_ws/src/vrx/` still pointing at `osrf/vrx` upstream) — see [VRX_Fork_Migration](VRX_Fork_Migration) for the repoint recipe. Two paths offered (in-place vs fresh clone) plus verification + troubleshooting.

### 8.1 Original baseline (pre-fork)

Project consumed upstream VRX via source clone + colcon build + a single runtime workaround patch (`patch_vrx.sh` for the LiDAR-at-origin bug, upstream issue #876). One patch sat well under the threshold past which forking starts to make sense — the fork landed 06/05/2026 as scope expansion, not triggered re-evaluation (see §8.6 Migration log).

### 8.2 Trigger conditions — when to re-open the decision

Any one of these:

- **Patch count growth.** Local workarounds against upstream grow past ~3. One is hygiene; three is a pattern; five-plus means tracking cost has caught up with fork-maintenance cost.
- **Custom worlds / sensors / WAM-V mods that wouldn't merge upstream.** Project-specific changes (e.g., test-lake worlds for our regional dataset coverage area, water-quality sensor stubs that only matter to this internship's research stack) — upstream has no scope reason to accept them.
- **Phase 5+ hardware integration with sim-side dependencies.** Bring-up surfaces a need for sim-side changes incompatible with upstream's API surface (e.g., a custom thrust-controller plugin for our autopilot bridge, a custom LiDAR plugin matching the real probe geometry).
- **Long-term maintenance balance flips.** Re-evaluate whenever a major upstream release would otherwise force re-deriving every local patch.

### 8.3 What forking would NOT solve

Listed so future-us doesn't fork for the wrong reasons:

- **Upstream's merge cadence.** Even on a fork, contributing back goes through the same review path. Forking buys local autonomy, not faster upstream merges.
- **Real-hardware bring-up.** Pi 5 + MAVLink + thruster wiring lives entirely outside VRX.
- **Test-environment custom worlds.** Already independent of VRX repo layout (`test_environment/`).

### 8.4 Cost estimate and alternatives

| Path | One-time | Ongoing |
|:-----|:---------|:--------|
| **Continue patches** (pre-fork posture) | ~0 | ~zero while patch count stays <3 |
| **Fork** + CI + rebase strategy + contributor docs | ~1-2 days | ~1-2 h per upstream sync |
| **Contribute upstream** | depends on fix | none after merge — upstream owns it |

The fork path becomes cheaper than continued patches only when ongoing patch-maintenance time exceeds ongoing rebase time. Today's 1 patch was far from that crossover — the 06/05 fork landed for forward-leaning reasons (see §8.6), not patch-burden crossover.

### 8.5 Original "not now" (overridden 06/05/2026)

Captured originally for traceability, not action: *re-open this section only when one of the §8.2 triggers fires*. The decision was taken **without** any §8.2 trigger firing; see §8.6 for the scope-expansion rationale and §8.7 for the resulting maintenance workflow. Future re-evaluations of fork-strategy changes (e.g., merging the bake-in upstream and decommissioning the fork) should still gate on the §8.2 framework.

### 8.6 Migration log — 06/05/2026

- **Fork created:** `Ghostzero00018/vrx` (basename invariant — must stay `vrx` so `patch_vrx.sh:20` hardcoded local path `$WS_ROOT/src/vrx/` resolves correctly).
- **Branch scope (initial):** jazzy-only at fork creation (other upstream branches accessible via the `upstream` remote if ever needed).
- **Two-branch model adopted post-fork:** `jazzy` mirrors `osrf/vrx jazzy` plus upstream-bugfix bake-in commits (at fork creation: 1 — `e384cd65`); `autoboat/main` branches off `jazzy` and accumulates project-specific inside-VRX modifications — mesh adds/removes, sensor-config tweaks, hydrodynamics tuning, etc. (at fork creation: 0 commits beyond `jazzy`; created at the same HEAD as a clean starting point for the monthly-mod cadence). Workspace consumes `autoboat/main` (set via `git checkout autoboat/main` in `~/seal_ws/src/vrx/`). Rationale: separates "upstream-bugfix" history from "our project mods" history so sync conflicts can be resolved at the appropriate level.
- **Initial sync:** local `jazzy` started at upstream HEAD (commit `7609d1bd`, no divergence from `osrf/vrx`); `autoboat/main` created at the same point.
- **Bake-in commit (`e384cd65`):** the LiDAR-at-origin workaround (single sed substitution `<publish_model_pose>false → true` in `vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro:94`) landed as a real commit on the fork's `jazzy` branch. `patch_vrx.sh` becomes idempotent no-op (the `grep -q '<publish_model_pose>true</publish_model_pose>'` short-circuit at line 27-29 triggers immediately).
- **Patch script retention:** kept as no-op safety-net for ≥2 release cycles; remove only after a fork upstream-merge cycle confirms the bake-in survives without re-derivation.
- **Reference-surface migration:** 5 install/clone URLs (`README.md:62`, `USER_MANUAL.md:357`, `wiki/Installation_Guide.md:51 + 55 + 94`) → fork URL. 1 dual-link entry (`USER_MANUAL.md:346`) rewritten with both arrows: `depends on fork at <URL> (canonical project: github.com/osrf/vrx)`. 9 attribution / canonical-project / wiki-reference links to `osrf/vrx` preserved (USER_MANUAL.md:51 / 477 / 1702 / 1713; wiki/Home.md:78; wiki/Installation_Guide.md:246; wiki/System_Overview.md:14; test_environment/sydney_regatta_DEFAULT.sdf:8; test_environment/wamv_3d_lidar.xacro:8).
- **Newcomer-onboarding polish (commit `427f4b4`, late-evening):** all 4 install clone snippets re-pinned to `git clone --branch autoboat/main https://github.com/Ghostzero00018/vrx.git` so the doc-followed path lands on the workspace-consumed branch independent of the fork's GitHub default-branch state. Line numbers shifted slightly with the added comment / Note paragraph: `README.md:63`, `USER_MANUAL.md:358`, `wiki/Installation_Guide.md:55 + 96` (Step 3 also gained a `> Note:` block with a forward-pointer to this §8). GitHub default branch on the fork was also flipped from `jazzy` → `autoboat/main` (web action) so plain `git clone` (without the `--branch` flag) lands on `autoboat/main` too — belt-and-suspenders. `git remote set-head origin -a` run locally to refresh `~/seal_ws/src/vrx/`'s `origin/HEAD` to match.
- **Out of scope (deferred to follow-up):** CI on the fork (decide whether to keep upstream's GitHub Actions workflows or disable); contributor docs for the fork; sync GitHub Action for periodic upstream tracking.

### 8.7 Upstream sync workflow

Two remotes: `origin` = `Ghostzero00018/vrx` (fork), `upstream` = `osrf/vrx` (canonical). Two branches on the fork: `jazzy` (upstream-tracking + bake-ins) and `autoboat/main` (project-specific mods on top of `jazzy`). Periodic sync recipe:

```bash
cd ~/seal_ws/src/vrx

# Step 1: bring upstream changes into the tracking branch
git fetch upstream
git checkout jazzy
git merge upstream/jazzy        # bake-ins may need re-derivation if upstream rewrote relevant lines
git push origin jazzy

# Step 2: bring fresh jazzy into the downstream branch
git checkout autoboat/main
git merge jazzy                  # project-specific mods may need re-derivation
git push origin autoboat/main

# Step 3 (if any source files changed in the merge): rebuild the workspace
cd ~/seal_ws && colcon build --merge-install
```

Re-derive the bake-in commit if upstream changes the relevant section of `wamv_gazebo.urdf.xacro` near line 94 (manual review of the merge result against `patch_vrx.sh:33` sed pattern). The script's idempotency check makes accidental double-application impossible.

**Workspace branch:** `~/seal_ws/src/vrx/` should stay on `autoboat/main` for daily use. Switch to `jazzy` only for the sync operations above (then `git checkout autoboat/main` after pushing). Switching branches changes source files on disk — a `colcon build` is needed afterwards if the differences include built artifacts (typically yes for any URDF / mesh / plugin change).

**Fresh-machine onboarding:** on a new clone of `~/seal_ws/src/vrx/` from the fork, `colcon build --merge-install` from `~/seal_ws/` is **mandatory** — there's no pre-existing `install/` tree, so the bake-in commit must be compiled into `wamv_gazebo` artifacts before the launcher will see it. On an existing workstation that already had VRX built before the fork landed (today's 06/05 case), `install/` already contains the bake-in's effect because the runtime patch had already applied + built — so the rebuild is optional. After any future bake-in or upstream-sync commit on `autoboat/main`, the rebuild becomes mandatory again.

### 8.8 Candidate inside-VRX modifications (tracked)

> Items here are observations that may justify project-specific edits on `autoboat/main` per §8.6's "mesh adds/removes, sensor-config tweaks, hydrodynamics tuning" surface. Each item is **noted only** until concrete scoping decides whether to act. Verify the simulator-side baseline before starting any modification work.

#### Propeller placement — sim-vs-real geometry gap (noted 12/05/2026)

**Observation.** The default VRX WAM-V uses **submerged thrusters** (propellers in the water, conventional boat layout). Our real drone-boat uses **above-water propulsion** (propellers mounted above the hull, hovercraft / airboat-style placement — same family as a hovercraft's air-propeller layout). The simulator-side hull and propeller geometry therefore do not match the real-world platform.

**Two follow-on questions:**

1. **Mesh fidelity.** Modify the WAM-V `urdf` / mesh on `autoboat/main` so the rendered boat in VRX matches the real platform (propeller assemblies above the hull rather than below). Cosmetic in isolation, but useful for digital-twin visualisation and operator intuition during sim runs.
2. **Physics characteristics.** Moving the thrust application point from "below waterline" to "above waterline" changes more than rendering:
   - **Thrust line of action** shifts relative to the hull / waterline and measured centre of mass; differential thrust steering may couple differently into pitch / roll (lever-arm change).
   - **Underwater drag** from the propeller / shaft disappears in the real platform but remains in the unmodified VRX model.
   - **Buoyancy distribution** is unaffected by propeller placement alone, but any associated hull / superstructure changes (e.g., a different above-deck assembly carrying the air-propellers) would also shift centre of mass / centre of buoyancy.
   - **Propulsion efficiency curve** — air propellers produce far less thrust per unit power at low speed than water propellers; the existing `0–800` VRX thrust scale (already flagged in §7 Phase 5 Q4 for real-Newton / PWM mapping) would need a different calibration target.

   None of these are "must fix before Phase 5 bring-up" — Phase 5.0's transition path (`remap.launch.yaml`) abstracts topics, not physics. They become relevant when the simulator is used to *predict* real-boat behaviour (the digital-twin value claim in §1.1) rather than to *mirror* it.

**Status.** Not scoped. Becomes a §8.2 trigger 2 candidate (custom mods that wouldn't merge upstream — the real platform's geometry is project-specific) **if** any of the following becomes a need: (a) operator-facing demo sim that should visually match the real boat (drives the mesh-fidelity work); (b) digital-twin predict-ahead capability requiring sim physics close to real physics (drives the physics-characteristic work); (c) Phase E validation runs where sim-side prediction error from geometry mismatch becomes a confound (drives both).

**Pre-work to actually scope this:** confirm real platform's propulsion geometry from hardware photos / supervisor walkthrough; capture propeller mount height, diameter, and any cowl / duct configuration; identify real-platform mass distribution. Cross-ref §7 Phase 5 Q4 (thrust mapping) once those numbers exist.

---

## 9. Revision log

| Date | Change |
|:-----|:-------|
| 21/04/2026 | Initial version. Consolidates Phase 5 scope summary (detail in `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`), adds research-extension architecture and Phase A consulting scope. |
| 24/04/2026 | Phase 5 summary reworded for 23/04 supervisor hardware walk-through: Pi 5 visually verified inside CCU; MP/QGC install added as prep task; low-level CCU note now flags "likely autopilot" as the working hypothesis from prof's MP/QGC ask; new bullet for Phase 5.2+ dashboard-through-MAVLink longer-term goal; Phase 5 open-questions list gains an autopilot / MAVLink-topology question. |
| 30/04/2026 | Added §8 Sim infrastructure — VRX upstream fork captured as scheme-only with triggers / what-it-won't-solve / cost / explicit "not now" framing. Revision log renumbered §8 → §9. |
| 30/04/2026 | §1.1 Scope clarifications + §1.2 Open questions added after the on-site scoping meeting (smaller scale than planned — campus power outage + IMT Mines Alès supervisor unavailable, so the on-site team ran its own session): Obj 1 = telemetry only (water-sensor data is Obj 2); MAVROS as the canonical MAVLink↔ROS bridge (MAVProxy is a router, not the bridge); DDS-over-IoT-WiFi multicast verification flagged as early-priority; CA placement most likely Linux-side; "regional datasets" portion of Obj 3 removed (insufficient accessible regional historical data); validation refined to same-day cross-validation; ML scope refined (residual-based + time-series + physics-informed; "ML trained on CA outputs" rejected). §6 Phase E rewritten to match. §7 top note + Phase E sub-list refresh. |
| 30/04/2026 | §3 Phase 5 status table gains a row for the Pi 5 ↔ flight-controller bring-up smoke-test procedure (`wiki/Pi5_Bringup_Smoke_Test.md`): SSH + UART/dialout setup, MAVProxy install with PEP 668 caveat for Ubuntu 24.04, heartbeat verify, IMU smoke test via `stream_data.py` (received from team) — 8 known issues catalogued (legacy `MAV_DATA_STREAM_*` API + 1 Hz IMU rate too slow + missing heartbeat timeout + others), modern `MAV_CMD_SET_MESSAGE_INTERVAL` replacement provided. Bring-up order documented (1. heartbeat, 2. direct script, 3. UDP fanout, 4. mavros2, 5. simulator integration). Cross-linked from `wiki/Home.md` under a new "🔌 Hardware Bring-up" section. |
| 30/04/2026 | §1.3 IoT IMT Nord Europe local-only network constraint analysed: dashboard has 4 internet-runtime dependencies (`roslib` from jsdelivr, `leaflet` JS+CSS from unpkg, OSM tile server, Google Fonts); without internet, (1) and (2) are **critical** (kill core dashboard + map respectively), (3) is critical for map background, (4) is cosmetic. Three mitigation paths captured (A: vendor libs locally — removes 3 of 4 deps; B: offline tile server with pre-generated MBTiles for the test area — required for the map panel; C: map-less fallback mode as third-tier backup). Recommended Phase 5 prep order: A immediately, B before first on-water deployment, C optional. §3 Phase 5 status table gains a row "Dashboard offline-capable for IoT-local network deployment ❌". `web_dashboard/autoboat/README_autoboat_dashboard.md` troubleshooting table updated to flag (1) and (2) alongside the existing (3) entry. |
| 12/05/2026 | §8.8 added: candidate inside-VRX modifications tracker. Initial entry — propeller placement sim-vs-real geometry gap (VRX default submerged-thruster WAM-V vs project's above-water hovercraft / airboat-style propulsion) flagged as a future `autoboat/main` candidate, with mesh-fidelity and physics-characteristic follow-on questions captured. Not scoped — pending Phase 5 hardware geometry confirmation; cross-refs §7 Phase 5 Q4 (thrust mapping) and §1.1 digital-twin framing. |
| 12/05/2026 | §3 Phase 5 status table updated after the Pi 5 DDS cross-machine probe: workstation on `IoT IMT Nord Europe` discovered Pi-side `/pi5_dds_probe`, `ros2 topic echo --once` returned `data: pi5_probe`, and `ros2 topic info --verbose` reported `Publisher count: 1`. For this WiFi, DDS discovery + transport work with standard ROS 2 graph discovery (`ROS_DOMAIN_ID=56`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`); Fast-DDS Discovery Server unicast config is not required for Phase 5 driver bring-up. |
| 12/05/2026 | §3 MP/QGC row updated to reflect the MP-Linux GDAL/OGR/OSR diagnosis from `working_diary/2026-05-12` Block C and `wiki/Common_Issues.md`: the bundled native wrappers are Windows PE DLLs under `~/MissionPlanner/gdal/{x86,x64}/`, not Linux `.so`; the earlier SkiaSharp-style musl→glibc swap hypothesis is superseded. MP-Windows remains the GIS / terrain fallback; MP-Linux video + arm/disarm remain working after the 11/05 SkiaSharp/libdl fix. |
| 13/05/2026 | Doc-audit early-application (Block B sweep, commit `b535d6d`): §1.1 DDS multicast caveat updated with parenthetical IoT-verified anchor (`IoT IMT Nord Europe` verified 12/05/2026; re-run on future networks). Same wording landed in `wiki/Pi5_Bringup_Smoke_Test.md` L139 + L300 cross-references. Perception `v2.0 → v2.1` refreshed across user-visible doc surface (4 sites: `wiki/3D_LIDAR_Processing.md` H1 title + body prose, `wiki/System_Overview.md` §3 module bullet, `web_dashboard/autoboat/index.html` H2 UI heading) plus 4 Python docstring/module sites — 21 historical "introduced in v2.0" comment markers in body code left intentionally untouched (provenance preservation). `one_click_launch_all/patch_vrx.sh` self-description refreshed from "Patches upstream VRX" to safety-net wording for the post-fork state (`Ghostzero00018/vrx` `autoboat/main` since 06/05/2026). `plan/plan/health_check_service.py` gained a module docstring documenting its `/health_check/run` service and `/health_check/line` + `/health_check/status` pub topics. 9 files / 44+/14-. |
| 13/05/2026 | Pi 5 Phase 5 networking deep-dive (`working_diary/2026-05-13` Block C.6 + C.7 + C.8): Pi 5 internet pre-flight on `IoT IMT Nord Europe` returns Branch B-conditional — default route + IPv4 DNS + HTTP egress to `archive.ubuntu.com` all OK, only outbound ICMP blocked (irrelevant to apt). Minimal-DE install (Lubuntu/LXQt) was initially authorised/deferred as technically possible, then superseded by the next row's headless directive. C.7 Herelink/Pi-ROS decoupling finding: with camera ON via control box and QGC live on the Herelink console (SSID `IMT-Aquatic-drone`), dual-domain Pi ROS sweep (`ROS_DOMAIN_ID=0` AND `=56`, env matching Tue B.1 verified-working) returned only `/parameter_events` + `/rosout` on **both** domains in **both** runs — Herelink video pipeline is architecturally decoupled from the Pi ROS graph, future autonomy-stack camera consumption needs a dedicated Pi-side ROS bridge (`gscam` / `usb_cam` / custom `rtsp→ROS`); sim `/wamv/sensors/cameras/*` has no real-hardware counterpart in current state. C.8 (user-authorised scope expansion): zero VNC server pre-install on Pi (no packages, no systemd units, no binaries) — confirms Ubuntu Server doesn't bundle RealVNC like Raspberry Pi OS does; workstation got `realvnc-vnc-viewer 7.15.1.18` via standalone .deb after purging an accidentally-installed `realvnc-rvncconnect 8.4.1`. Three deployment networks recorded by exact SSID for operator clarity: `IMT Nord Europe 5G`, `IoT IMT Nord Europe`, `IMT-Aquatic-drone`. |
| 13/05/2026 | Late-day session findings (`working_diary/2026-05-13` C.6 + C.7 addendums): **Branch B DE install permanently shelved per professor's directive** — Pi 5 stays Ubuntu Server headless permanently, no GUI/desktop in any future session; supersedes the earlier "deferred to Mon 18/05+" framing. C.6 Branch A physical-attach validated (micro-HDMI to HDMI1 + USB keyboard → Pi TTY1 login; no Pi state change). C.7 outcome (i) ALSO confirmed under different conditions: with `ROS_DOMAIN_ID=56` unset and `ros2 run realsense2_camera realsense2_camera_node` on Pi, workstation `ros2 topic list` enumerates the full RealSense topic surface (Intel D435I, FW v5.14.0, USB 2.1) — validates `realsense2_camera_node` as the predicted dedicated ROS bridge; outcomes (i) and (ii) correspond to two architectural states (explicit camera node vs no node), not contradictions. Camera consumer exclusivity finding: rviz2/ROS bridge and Herelink RTSP cannot stream simultaneously (likely v4l2 device-exclusivity breaking the `v4l2loopback` fork); flagged for Phase 5 sharing-mechanism design. Pi 5 brownout root-cause identified for prior "sleep" symptoms (5V GPIO power sag under RealSense load → PMIC under-voltage shutdown ~4.63 V → red LED ≈ halted SoC, not actual sleep); temporary fix is Pi 5 on its own USB-C charger decoupled from main 14.8V LiPo battery. Pi 5 session-hardening config edits applied: `/boot/firmware/config.txt` += `dtparam=power_ctrl_button=off`; `/etc/systemd/logind.conf` `HandlePowerKey=ignore` + `IdleAction=ignore` + `IdleActionSec=3000mins`. Phase 5 hardware-design requirements added to §3 status table: regulated ≥5A 5V supply dedicated to Pi 5, RealSense → ROS bridge via `realsense2_camera_node` (validated), camera consumer exclusivity constraint. |
| 13/05/2026 | Post-wrap log audit correction: §1.3's 30/04 "local-only / no internet" wording was too absolute after the C.6 pre-flight. Updated to "managed / partial egress": Pi-side DNS + HTTP egress to `archive.ubuntu.com` worked on 13/05, public ICMP was blocked, and workstation-side / OSM tile availability still must not be assumed. Path B remains required for deterministic map-panel operation on restricted or offline deployments. Also added the workstation visualization caveat for RealSense topics: use `rviz2`, not `rviz`; install local `realsense2_camera_msgs` interfaces before relying on `rqt` for custom metadata / extrinsics topics. |
| 18/05/2026 | §3 RealSense → ROS bridge row gains a parenthetical on USB hub port enumeration variability (port `2-1` dominant across 13/05 RealSense sessions; port `1-1` observed once in the 17:14 pre-reboot run per the 18/05 13/05-log audit in `working_diary/2026-05-18`). Pi USB hub port may vary across physical re-plugs or bus re-enumeration after a power cycle — operator-facing note for Phase 5 hardware-design pass. |
| 20/05/2026 | Joint supervisor presentation delivered within the 10h-10h30 IMT Mines Alès cap (formal slot replacing the 30/04 reschedule hedge, `working_diary/2026-05-20`). Three Asks status update: Phase A parameter subset resolved as scope clarification (physical sensor interface owned by another team member, not in this internship's work scope); CA placement resolved Linux-side ("probably placed on Linux machine" supervisor signal); validation methodology stays pending external confirmation only (same-day R₁/R₂ split documented principal approach locked 30/04/2026 per §6 Phase E remains intact). §3 Summary "Low-level CCU" bullet gains a 20/05 reinforcement sentence — supervisor presentation reinforced the Pi 5 MAVLink ingestion direction: autopilot / boat telemetry should be exposed as ROS 2 topics, with `mavros2` / MAVROS as the direct MAVLink-to-ROS bridge route; MAVProxy remains routing / fanout tooling and only enters the ROS ingestion path if paired with a custom / `pymavlink` ROS publisher (preserves §1.1 + Board 30/04 distinction). Action items: IMT Mines Alès prof to send paper list on digital twin (Obj 3 ML methodology input); next supervisor meeting 03/06/2026 10h-12h (2-hour morning window, not 30-min cap shape). Detailed talk timing / per-slide supervisor reactions / slide-claim pushback / supervisor satisfaction verdict not captured (compressed slot); Block C marked N/A — no separate IMT Nord Europe-only extension notes were captured. |
| 21/05/2026 | §1.1 Pi 5 OS-posture parenthetical revised: the 13/05/2026 "Ubuntu Server headless permanently" supervisor directive was reversed 21/05/2026 — prof re-flashing the Pi 5 with a full desktop GUI image (control box at prof's office). Re-flash wipes 13/05 Pi-side state (ROS 2 Jazzy install, SSH keys, dialout config, `/boot/firmware/config.txt` + `logind.conf` edits); Phase 5 Pi-side bring-up effectively restarts when the box returns. Companion edits: `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisite line rewritten (Ubuntu Server / Desktop both supported on aarch64 Jazzy; RPi OS Bookworm not officially supported — would force source-build); `Board.md` Last Updated 20/05 → 21/05, Document Version 9.14 → 9.15, new 21/05 Timeline row added. Past `working_diary/` entries (13/05 / 18/05 / 19/05 / 20/05) left frozen per the append-only rule; the 21/05 reversal lives forward of them in `working_diary/2026-05-21` + Board Timeline. Phase 5 next-step direction (Pi 5 telemetry → ROS 2 topics via `mavros2`) confirmed 20/05/2026 remains intact — `mavros2` is OS-agnostic between Ubuntu Server / Desktop on aarch64 Jazzy. |
| 21/05/2026 | New `wiki/Digital_Twin_Architecture.md` page added: standards-positioning rationale for the project's digital-twin framing (ISO/IEC 30141:2024 as the domain-neutral IoT reference architecture; ISO 23247:2021 Parts 1-4 as a worked manufacturing DT instantiation of 30141; this project as an aquatic environmental adaptation of the layered pattern). §1.1 closing line + §4 closing paragraph gain cross-reference pointers to the new page; `wiki/Home.md` Architecture group adds a bullet + Last Updated bump 13/05 → 21/05; `wiki/System_Overview.md` top-of-file related-pages callout adds a line. |
| 22/05/2026 | §1.1 and §3 updated after live Pi 5 return: prof reflash verified as Ubuntu Desktop 24.04.4 LTS Noble + `linux-raspi` + GNOME/Mutter Wayland; Route 1 apt MAVROS install green (`ros-jazzy-mavros` 2.14.0 + extras + msgs, GeographicLib defaults, `dialout` active); workstation → Pi desktop access verified through GNOME Remote Desktop over RDP / Remmina. `wiki/Pi5_Bringup_Smoke_Test.md` gains post-reflash NTP and `openssh-server` prerequisites plus a MAVROS quick-check warning: `/mavros/*` topics can be advertised while `/mavros/state connected: false`; real pass condition is a visible serial / UDP MAVLink endpoint and `connected: true`. `Board.md` version bumped to 9.16 with 22/05 Timeline row and Pi hardware-arrival task status updates. Remaining gate is no longer Pi return; it is autopilot / boat physical connection for `/mavros/state` heartbeat. |
| 27/05/2026 | §3 refreshed after Remmina-side Pi 5 audit in `working_diary/2026-05-27`: expanded MAVLink endpoint sweep still found no CubePilot / Pixhawk / USB-UART / UDP endpoint, so `/mavros/state connected: true` remains blocked by physical connectivity. RealSense D435i color/depth ROS path revalidated on the post-reflash Ubuntu Desktop image (`realsense2_camera_node` v4.57.7, LibRealSense v2.57.7, serial `213622070342`, FW `5.14.0`, USB type `3.2`); IMU-only launch later validated `/camera/camera/imu`, while combined color/depth/IMU remains load-sensitive after `HID set_power 1 failed` / `Motion Module failure` during a Pi low-voltage warning. `wiki/Pi5_Bringup_Smoke_Test.md` endpoint checklist widened to include by-path, `ttyAMA*`, `ttyS*`, and common UDP MAVLink listener checks. |
| 28/05/2026 | §3 refreshed after the `working_diary/2026-05-28` endpoint gate and RealSense viewer check: expanded MAVLink endpoint audit still found no serial / UART / UDP endpoint, so MAVROS remains blocked by physical connectivity; Slab 3 records only a placeholder Pi-side `systemd` autostart strategy with `fcu_url` unresolved. Separate camera-side evidence now confirms Pi-local color-only RealSense viewing on the Ubuntu Desktop image through both `rqt_image_view` and RViz2 after installing `ros-jazzy-rqt-image-view` and `ros-jazzy-rviz2`; this proves the camera path only, not boat telemetry. |
| 03/06/2026 | §3 refreshed after the professor's morning-send photo of the post-reconfiguration Pi 5 MAVProxy result, with the Pi desktop clock showing Tue 02/06/2026 22:09 capture time: `/dev/ttyAMA0` at `57600` detects vehicle `1:1`, reports `online system 1`, enters `HOLD`, and receives ArduPilot EKF3 GPS status text. This upgrades the endpoint from missing to externally evidenced for MAVProxy, while preserving `/mavros/state connected: true` as the ROS-side pass condition. |
| 04/06/2026 | §3 refreshed after the live MAVROS pass on the reconfigured endpoint: MAVProxy on `/dev/ttyAMA0:57600` fanned out to `udpout:127.0.0.1:14550`; MAVROS `apm.launch` with `fcu_url:=udp://127.0.0.1:14550@` reported ArduPilot heartbeat, `/mavros/state connected: true`, and first ROS samples from `/mavros/imu/data`, `/mavros/global_position/raw/fix`, `/mavros/battery`, and `/mavros/rc/in`. GPS fix / EKF GPS configuration, targeted request/response timeouts, command-path mapping, and dashboard / simulation integration remain open. |
| 05/06/2026 | §3 refreshed after the 05/06 MAVROS-only log review and remap planning pass: camera-off MAVROS on `ROS_DOMAIN_ID=12` again returned `/mavros/state connected: true`, captured a clean 136-topic `/mavros/*` graph with no unrelated sim / TurtleBot / OAK-D noise, and produced raw GPS no-fix, IMU, vehicle-battery, and empty-RC-channel samples. The same log showed chronic Pi undervoltage before RealSense; the user observed shutdown when launching the RealSense node, and no fresh 05/06 camera / combined topic capture exists. Immediate dashboard / sim integration plan is read-only Option B: MAVROS IMU into existing `/wamv/sensors/imu/imu/data`, GPS into `/wamv/sensors/gps/gps/fix` only behind a no-fix guard, and no command / thruster mapping until write-path validation passes. |
| 09/06/2026 | §3 refreshed after the post-meeting feedback and Pi-local YOLO feasibility trial in `working_diary/2026-06-09`: feedback was to keep working while polishing the graph, with no code/config approval or external slide path. The isolated Pi 5 trial installed a venv, loaded `yolo26n.pt`, exported NCNN successfully, and ran static-image CPU inference on the `bus.jpg` fallback with `detections: 5` and 244.42 ms inference at `imgsz=320`. This is recorded as feasibility only, not ROS integration, camera-stream inference, dashboard integration, or command-path work; existing RealSense power, GPS/EKF, and command/write blockers remain open. |
| 10/06/2026 | §3 refreshed after the professor continuation feedback, live Pi 5 demo, and QGC Plan-view acceptance recorded in `working_diary/2026-06-10`: RealSense default launch opened color + depth on D435I serial `213622070342`, color image averaged `18.341` Hz, and Pi-local `web_video_server` served `/camera/camera/color/image_raw`; MAVProxy/MAVROS again returned `/mavros/state connected: true` with read-side telemetry but also `system_status: 5`, FCU request/response timeouts, EKF GPS-config warnings, and empty RC channels. The combined camera + MAVROS window is recorded narrowly: no fresh pasted under-voltage tail, but no combined camera Hz / IMU / GPS / battery inventory and temp 82.6 C. YOLO remains static-image only after 5 runs at mean inference `84.09` ms. The new dashboard-cache -> QGC `.plan` converter imported successfully in QGC Plan view with 5 mission items matching the dashboard geometry; no vehicle upload or command/write path was attempted. |
| 11/06/2026 | §3 refreshed after the live local QGC visual bridge acceptance recorded in `working_diary/2026-06-11`: `tools/qgc_live_mission_bridge.py` waits for dashboard/planner `READY`, then exposes a simulated surface-boat MAVLink mission surface to same-machine QGC over `127.0.0.1:14550`. After dashboard Generate -> Confirm, QGC requested params and the mission; the bridge served 3 params, `MISSION_COUNT=7`, and mission items `seq=0` through `seq=6`; QGC displayed the route matching the dashboard without `.plan` import or mission-folder write. This is visual-only local acceptance. Real FCU upload, arming, thruster, actuator, Pi upload, Herelink network variant, and command/write validation remain open. |
| 12/06/2026 | §3 / Phase 5.2+ wording refined after the clean local-only A/B retest and no-code v2 design review in `working_diary/2026-06-12`: A1 reproduced the local visual initial-pull (`MISSION_COUNT=19`, items `seq=0` through `seq=18`), A2 confirmed the same-session auto-refresh limitation (a changed route did not redownload in the same session; reconnect/relaunch remained the only proven v1 refresh workaround), and the count-only loops / triplets / clear bursts / retry warnings did not reproduce locally — strengthening the H2/H3 mixed-topology explanation for the 11/06 evening anomalies. Block D captured a no-code v2 bidirectional design direction (QGC and dashboard as peer mission editors over one mission authority, opaque-id / mission-version refresh where supported). Visual-only; real-FCU upload, bidirectional sync, and command/write validation remain open. |
| 18/06/2026 | §3 RealSense row refreshed after the Pipeline C dashboard test in `working_diary/2026-06-18`: Pi RealSense -> workstation dashboard camera display worked on `IoT IMT Nord Europe` after setting `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`; loopback-only rosbridge / `web_video_server` / dashboard served the browser side. Practical profile: `enable_depth:=false rgb_camera.color_profile:=424x240x15`; clean workstation receive sample near 14.8-15.0 Hz. New `wiki/RealSense_Dashboard_Testing.md` procedure added. User also observed a full simulated out-and-return-home mission while the dashboard Camera panel showed the Pi RealSense feed. Camera-display / sim-coexistence only; no real-FCU command/write path, QGC upload, Herelink acceptance, MAVROS telemetry change, or bidirectional sync was validated. |
| 19/06/2026 | §3 Phase 5 history appended after the camera-OFF Pi 5 post-update MAVROS re-check in `working_diary/2026-06-19`: in the 18/06 ROS sync the checked packages left MAVROS at `2.14.0` and `ros-base` `0.11.0` / `web-video-server` `3.1.0` as same-version rebuilds, with `realsense2-camera` bumped `4.57.7 -> 4.58.1`; other ROS dependencies (`rclcpp`, `rmw-fastrtps-cpp`, `tf2`, etc.) also moved at patch level, so it is the live re-check that showed no regression — MAVProxy heartbeat on `/dev/ttyAMA0:57600`, `/mavros/state connected: true`, mode `HOLD`, live IMU and battery, and the workstation discovering 136 `/mavros/*` topics over DDS. `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` is now pinned in `~/.bashrc` on both machines. Expected-open GPS no-fix / EKF GPS-config / empty RC / `system_status: 5` persist; read-only, no real-FCU command/write path. |
| 22/06/2026 | §3 refreshed after `working_diary/2026-06-22` console / Herelink hotspot observation. Workstation on `IMT-Aquatic-drone` reached the Herelink gateway `192.168.43.1`; direct RTSP to `rtsp://192.168.43.1:8554/fpv_stream` worked and TCP was clean, but the current stream content was a Pi desktop / `rqt_image_view` screen capture after starting the Pi camera node, not a direct camera feed. Treat this as Herelink RTSP transport proof plus source-regression evidence, not dashboard camera integration. QGC also showed read-only MAVLink telemetry over UDP `14550` with the known EKF GPS-config warning. A 16:07 packet capture identified unicast MAVLink from `192.168.43.1:52600` to workstation `192.168.43.160:14550`, proving the MAVLink sender shape; a MAVROS / ROS 2 fork should next be tested through QGC MAVLink forwarding to a separate local port. |
| 23/06/2026 | §3 refreshed and `wiki/YOLO_Dataset_Plan.md` added after the workstation YOLO toolchain smoke test and dataset-planning pivot in `working_diary/2026-06-23`: professor was not onsite, so QGC/Herelink/MAVROS live-test questions remain unanswered. Workstation GPU training is now the selected custom-detector path; Pi 5 stays capture + deployment-validation. The smoke test proved CUDA train -> NCNN export with `yolo26n.pt` outside the public repo, X-AnyLabeling `4.0.0-beta.10` exported a valid YOLO-Hbb label from a disposable image, and the workstation-exported NCNN model ran on Pi `imt-aqua-drone@10.120.2.249` as a static-image CPU handoff check (`imgsz=640`, `boxes=2`, steady-state inference `226.0-281.1` ms, temp `68.85 C -> 68.30 C`, no undervoltage / throttle evidence). Custom RealSense data capture, real-data training, custom maritime-model Pi validation, ROS integration, and dashboard integration remain future work. |
| 24/06/2026 | §3 refreshed after `working_diary/2026-06-24`: Pi 5 RealSense RGB camera-only publish passed at `424x240x15` over `ROS_DOMAIN_ID=12` / `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, with workstation DDS receiving `/camera/camera/color/image_raw` near `15 Hz`, RELIABLE / TRANSIENT_LOCAL QoS, and clean Pi thermal/power evidence. A scratch workstation saver captured a tiny pipeline-validation pilot outside the repo; R1 culled it to 7 `person` frames plus 4 clean negatives, R2 YOLO-Hbb labels passed structural and visual checks, and R3 copied only active stems into a 9/2 train/val split. This is camera-readiness, capture, label, and split evidence only; training, custom-model export, Pi custom-model validation, live inference, ROS/dashboard integration, MAVROS, QGC, Herelink, and command/write paths remain unrun. |
| 25/06/2026 | §3 refreshed after `working_diary/2026-06-25`: the workstation-only YOLO training gate passed from the 24/06 tiny split outside the repo. Dataset lint stayed at `9` train images, `9` train labels, `2` val images, `2` val labels, and `9` total boxes, all class `4`. `~/venvs/yolo-ws` imported Ultralytics `8.4.75` and `ncnn 1.0.20260526`; CUDA was available on `NVIDIA RTX A3000 Laptop GPU`. `yolo26n.pt` trained for 50 epochs into `runs/baseline_yolo26n/weights/best.pt`, validation was rerun to dataset-local `runs/val_baseline_yolo26n`, and NCNN export wrote `best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Metrics are informational only because the split has `2` validation images and `2` validation boxes; Pi custom-model validation, live inference, ROS/dashboard integration, MAVROS, QGC, Herelink, and command/write paths remain unrun. |
| 25/06/2026 | §3 refreshed after the Block E static Pi log in `working_diary/2026-06-25`: the custom `best_ncnn_model` and two saved validation images were copied to Pi `imtaquadrone-desktop` at `10.120.2.249` under `~/yolo_tests/custom_20260625_static`. `~/venvs/yolo-pi5` imported Ultralytics `8.4.62` and `ncnn 1.0.20260526`; the model loaded and ran both static images at `imgsz=640` on CPU. Both images returned `0` boxes at the default confidence threshold, so detections remain informational only and detector-quality validation is not proven. Pi temperature moved `66.65 C -> 69.95 C`, and the dmesg voltage/throttle filter showed only the same boot-time storage-bus voltage-switch messages before and after. No RealSense stream, live inference, ROS/dashboard integration, MAVROS, QGC, Herelink, or command/write path was run. |
| 25/06/2026 | §3 refreshed after the Block F ROS-camera-node procedure spike in `working_diary/2026-06-25`: direct `pyrealsense2` was unavailable in both `~/venvs/yolo-pi5` and `/usr/bin/python3`, so the fallback used `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 on D435I serial `213622070342` at `RGB8 424x240x15`. Camera-only topic flow held about `14.939-15.012` Hz, F1 saved 5 ROS snapshots and ran the custom NCNN model on them, and F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` and `mean_inf_ms=340.9` before the intended `80.0 C` safety abort fired at `80.95 C`. The Pi started near a `72.7-73.8 C` baseline, so the blocker is thermal headroom / cooling, not a proven model infeasibility. dmesg voltage/throttle filters stayed clean. This is procedure and safety-abort evidence only: detections were `0`, detector quality is not proven, sustained thermally clean live inference is not proven, and dashboard, MAVROS, QGC, Herelink, and command/write paths were not run. |
| 26/06/2026 | §3 refreshed after `working_diary/2026-06-26`: closing the Remmina / desktop screen session dropped the representative RealSense floor to about `51 C` camera-on / no-NCNN, and a short headless ROS-camera -> custom NCNN run passed (`150` frames in `18.8 s`, `mean_fps=7.98`, `mean_inf_ms=123.8`, no `80.0 C` abort). A sustained headless ROS + NCNN loop then failed the thermal gate, climbing through repeated `80.4-82.05 C` aborts, so sustained inference at the current `imgsz=640` NCNN profile is tested and not viable yet. `pyrealsense2 2.58.2` was installed only in `~/venvs/yolo-pi5-rs`; direct SDK camera-only capture passed (`900` frames / `60.0 s` / `14.99 fps`), and direct-SDK -> custom NCNN short inference passed (`150` frames / `23.1 s` / `mean_fps=6.51` / `mean_inf_ms=151.9`) but showed no meaningful overhead advantage over ROS. The optional direct `imgsz=320` run segfaulted after model load, so the next software thermal test needs a separate workstation NCNN export at `imgsz=320`. A late camera-off MAVProxy sanity check after missing box startup sound opened `/dev/ttyAMA0:57600` but received no heartbeat and reported `link 1 down`; inspect power/wiring on Tuesday 30/06/2026 before rerunning MAVProxy/MAVROS. |
| 02/07/2026 | §3 gains the Hailo AI HAT+ 13 TOPS acceleration row after the official E2 artifact row and workstation compile gate closed. At the 02/07 close, the Pi HAT was PCIe-healthy but the runtime was not installed yet; the workstation Docker suite had produced `yolo26n_route_a_six_heads.hef` for `HAILO8L` with six raw outputs and no embedded NMS. Remaining work at that point was Pi runtime install plus device execution, not RealSense decode or dashboard integration. |
| 03/07/2026 | §3 refreshed after `working_diary/2026-07-03`: the Pi manual Ubuntu runtime path installed the pinned `4.24.0` driver/runtime/Python row on kernel `6.8.0-1060-raspi`; matching headers and DKMS passed, `/dev/hailo0` appeared, firmware `4.24.0` loaded, `fw-control identify` reported `HAILO8L`, Python `HEF` import passed, `parse-hef` confirmed the custom six-output `HAILO8L` HEF contract, and `hailortcli run` completed `293` frames at `58.22 FPS`. Runtime mechanics are proven; decode, saved-frame RealSense input, live ROS integration, dashboard integration, co-load tests, and detector quality remain future work. |
| 07/07/2026 | §3 Hailo row refreshed after `working_diary/2026-07-07`: the six-output host-side decode contract is proven on saved frames (`fb308f9`). A same-engine raw-head ONNX isolation declared the six final head convs as extra ONNX outputs and decoded them back to the graph `output0` to float precision (box max abs `0.0 px`, class max abs `1.178e-7`), so six-output layout, direct 4-channel box decode, class sigmoid, and the `data.yaml` class map are settled; the earlier full-precision box residual is now diagnosed as a Hailo DFC emulation vs ONNX Runtime cross-engine numeric difference amplified by stride, not a decode error. The next Hailo gate — a positive-bearing saved-frame Tier 3 (quantized path -> host decode + NMS + un-letterbox versus Ultralytics) — is blocked upstream on a functional detector: the current tiny `best.pt` fires on none of the available saved frames at `conf=0.25`, including its own training images (only 9 labeled instances, all class `person`; buoy / vessel / dock / obstacle have no data). Planning landed in response: a four-way split + sizing contract in [YOLO_Dataset_Plan](YOLO_Dataset_Plan), and a detector-recovery scaffold in `working_diary/2026-07-08_wednesday_detector_recovery.md`. Saved-frame decode-contract evidence only; no NMS / end-to-end match, Pi run, live RealSense, ROS/dashboard integration, MAVROS/QGC/Herelink, or detector-quality claim. |
| 08/07/2026 | §3 detector row added after `working_diary/2026-07-08`: detector-recovery Blocks A-C closed as planning evidence only. The session recorded the 9-box `person`-only baseline, the non-firing `best.pt`, a split-aware external acquisition manifest, the VRX support limits, and the boxes-not-masks visual target. A bounded Pi runtime smoke proved RealSense -> Hailo -> decode-summary mechanics with the current HEF, but zero detections remain expected and no Hailo accuracy gate reopened. |
| 09/07/2026 | §3 detector row refreshed after `working_diary/2026-07-09`: the next scaffold is an isolated unicolor-object real-image training smoke that intentionally precedes the VRX `buoy` / `dock` route. It tests capture, YOLO-Hbb box labeling, workstation retrain, and held-out firing with easy targets while keeping all proxy data outside the maritime dataset and outside the repo. |
| 15/07/2026 | §3 refreshed after the bounded live Pi/control-box diagnostic. The user observed the stock-COCO Hailo overlay and five direct MAVROS telemetry feeds together in the workstation dashboard. This proves simultaneous view-only browser delivery; full endurance, durable integration, GPS fix, and dashboard-to-FCU information or command writes remain open. |
| 17/07/2026 | §3 refreshed after two tracked-supervisor runs on `IoT IMT Nord Europe`. Both reached six-topic arrival and rate acceptance: the stock-COCO Hailo overlay measured `7.40/7.50 Hz`, while state, raw GPS, IMU, battery, and RC were near `1 Hz`; MAVROS stayed connected and disarmed, and the command sentinel observed zero messages on its five monitored command topics. During both runs, the operator confirmed the combined browser view. Pi thermal peaks were `68.3/67.2 C`, and both Pi run directories were copied back. The workstation dashboard stack became unavailable unexpectedly before the intended Pi-first stop in each run; both sides cleaned up fail-closed. The cause, normal Pi-first shutdown, post-teardown temperature, full endurance, optimized transport, GPS fix, custom-detector accuracy/calibration/live integration, and FCU writes remain open. |
| 04/08/2026 | §3 supervisor row and §3 Blockers refreshed after `working_diary/2026-08-03` and `working_diary/2026-08-04`. The 17/07 lifecycle gap closed: normal Pi-first shutdown and post-teardown temperature were obtained 03/08/2026 and repeated 04/08/2026. Both 03/08 runs reproduced a daemonless graph-query defect where a fresh `ros2 topic info --verbose` process returns a successful but transiently incomplete snapshot. On 04/08/2026 a batched MAVROS source view landed behind `LIVE_MAVROS_SOURCE_BATCH` (off by default, `63d6e9a`): one run-owned `rclpy` participant spins to accumulate discovery and serves all five source topics from a single consume-once generation, with the flag-off path delegating byte-for-byte to the existing CLI query. A flag-off canary passed end to end and the defect recurred at `2` non-verifying readings; per-run control counts are now `11`, `3` and `2`. The batched path remains unexercised live, the lower DDS/RMW/network trigger is unidentified, and browser-last ordering, endurance, GPS fix, detector quality and all FCU write paths remain out of scope. Sessions between 22/07/2026 and 24/07/2026 are recorded in `Board.md` and the working diaries and are not restated here. |
| 05/08/2026 | §3 supervisor row and §3 Blockers refreshed after `working_diary/2026-08-05`. The batched MAVROS source view was exercised live for the first time at shipped defaults and is feasible: `18` probe runs all `OK`, one run-owned participant serving all five source topics per run, a `120 s` window that was not truncated, final verification at `85 s` inside its `180 s` budget, and `status=0` on both supervisors. Its payload contract is now verified against real endpoint output. The graph-query defect recurred under the batched path, so the earlier "unexercised live" status is replaced by feasibility rather than by a fix; the per-run reading count sits inside the flag-off control range and no reduction is claimed. Browser-last ordering and the terminal data-plane probe remain unexercised. |
| 07/08/2026 | §3 gains a 07/08/2026 supersession after `working_diary/2026-08-07`. A command path was opened in simulation only: ArduPilot SITL is built and running on the workstation (`Rover-4.6.3` at `3fc7011a`, frame `motorboat-skid`, `build/sitl/bin/ardurover`), reaching steady state with `Mode MANUAL`, `EKF3` active and `1283` parameters received while disarmed, and its MAVLink surface was verified read-only at `tcp:127.0.0.1:5760` with a MAVProxy rebroadcast on `127.0.0.1:14550`. No command was sent to the simulator, no code was written, and no command/write path to any real autopilot was opened. Two constraints for the eventual bridge were established from measured parameters rather than assumption: SITL and the real boat assign the same throttle functions (`73` left, `74` right) to opposite channel numbers, so a design keyed on channel number is correct on only one platform; and the PWM rails differ in kind, SITL measuring `1000`/`1500`/`2000` with neutral mid-scale against the real boat's `800`/`800`/`2200` with neutral at the bottom, while `tools/servo_command_bridge.py` defaults to `1100`/`1500`/`1900` and matches neither, so emitting the simulator's neutral at the real vehicle would command substantial thrust while appearing to command zero. The written command-ingress contract is unstarted and stays design-only. Later the same day a view-only live run with the Pi and control box reached six-topic rate acceptance and `COMMAND_SENTINEL=PASS messages=0` but ended on a reversed shutdown order, so telemetry delivery is proven and normal lifecycle is not; it also added a fourth flag-off graph-query control point of `10` readings, series now `11`/`3`/`2`/`10`. Five view-only dashboard telemetry improvements landed alongside it - GPS position and horizontal-accuracy readouts, `NavSatStatus` fix codes by name, `system_status` by `MAV_STATE` name so this vehicle's `5` reads `Critical (5)`, and a live thrust-output readout with a sixth freshness badge fed from `/mavros/rc/out`, showing raw servo PWM for both thrusters without converting to a percentage - with `LIVE_MAVLINK_VIEW_ONLY` still `true` and no write path added. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` gains the compound-command corruption signature and the reversed-shutdown signature. |
| 10/08/2026 | §3 refreshed after the command-ingress contract, default-inhibited bridge/dashboard implementation and clean workstation-only `motorboat-skid` SITL run. Live parameter resolution produced RC channels `1`/`3` and `SERVO1`/`SERVO3`; the run obtained fresh disarmed neutral, normal arming to `ARMED_NEUTRAL`, positive and negative browser-held `ACTIVE` intervals, measured neutral return and accepted normal disarm. Two recordings preserve the visible closed loop: `+0.10`/`0.08` produced measured servo `1585`/`1485`, and `-0.04`/`0.09` produced `1520`/`1559`. The terminal capture missed both active intervals, so machine-readable transition capture and one helper-owned lifecycle remain open. No Pi, physical controller or real thruster participated. |
| 11/08/2026 | §3 records the failed first helper-owned SITL attempt and the correction: direct pinned-Rover launch replaces `sim_vehicle.py` terminal delegation, and early cleanup no longer asks for bridge shutdown frames before bridge startup. Focused tests pass, but the corrected runtime has not been rerun. A separate guarded physical-FCU workstation/Pi helper pair is prepared with a direct-serial, read-only T0b probe before its separately gated full MAVROS/bridge session. The workstation emits the mapped bench URL only from fresh `READY_DISARMED` status. The existing Hailo/MAVROS helper remains byte-identical and view-only. No Pi/FCU runtime or physical command occurred; T0a remains unscheduled. |
| 17/08/2026 | §3 records the complete helper-owned `motorboat-skid` acceptance: all functional phases passed, teardown followed the contracted order, the final verdict had nothing missing, all ten evidence digests matched and independent read-only adjudication passed. A separate powered-down D0 inspection passed connector seating and end-to-end `Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity, closing T0a. D1 did not run and no real controller was powered or contacted. |
| 18/08/2026 | §3 records D1 Gate 1 and the failed T0b probe. The four-file bundle was deployed once to the dated Pi root, certified against its manifest and accepted by the helper's non-actuating `check`. The probe opened direct serial and received an ArduPilot heartbeat, then the MAVROS parameter-list exchange exhausted its retries. The operator stopped before the deadline; cleanup passed, but repeated same-path captures and merged stderr left the retained state evidence non-diagnostic. No T0b parameter artifact, parameter write, bridge start, physical command or real-thrust result occurred. T0b remains open. |
| 19/08/2026 | §3 records the repaired T0b capture path and second dated deployment. Every state attempt now has an isolated YAML copy and sibling diagnostic log, including diagnostics from the copy writer; the physical-helper suite passed `24` cases after the bundle manifest was regenerated. The helper, tests and manifest landed together at `dc90a8f`. The five-file `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` deployment passed exact inventory, pinned-manifest, `4/4` member verification and the helper's non-actuating `check`. Block E was approved but deferred without execution while its safety review remained pending. No controller or Herelink power-up, serial open, parameter write, bridge start, physical command or real-thrust result occurred under Block E. T0b remains open, and the unused approval does not cross the day boundary. |
| 20/08/2026 | §3 records the localhost-only probe repair, the third dated deployment, powered UART isolation, the full real-FCU T0b execution and the final duplex isolation. The live FCU reached connected/disarmed and hardware-safe state, but automatic and forced MAVROS parameter pulls received no response. The duplex run then received `18` more disarmed heartbeats while one audited PING and one audited `SYSID_THISMAV` request received no reply. Cleanup and evidence copy-back passed; no `41`-parameter mapping/rail artifact, parameter write, bridge, mode change, arming, RC, motor or thrust action occurred. T0b remains open, with T1's separately approved `BRD_SER1_RTSCTS` link-configuration change as the next decision point. The operator's powered-off confirmation closed the physical day, and no approval carries forward. |
| 21/08/2026 | §3 records the new `2600ea4` Pi deployment, the `BRD_SER1_RTSCTS` `Auto (2)` to `0` experiment, two guarded runs and final rollback. The disarmed run again received FCU state but no parameter response; the armed run was rejected by the disarmed-state gate before the parameter pull or command path. Both helpers cleaned up with `status=1 cleanup_rc=0`. The copied evidence archive verified, `BRD_SER1_RTSCTS=Auto (2)` was read back after rollback, and the operator confirmed all control hardware off with propulsion isolated, propellers removed and the hull restrained. T0b remains open; the candidate did not fix the direct-link failure; neither T2 tier earned acceptance; and no approval carries forward. |
| 25/08/2026 | §3 records the first accepted state-changing command/ACK evidence on the direct Pi endpoint. MAVProxy on `/dev/ttyAMA0:57600` received accepted arm and disarm acknowledgements and ended `DISARMED`; the arm request occurred after the capture had already shown `ARMED`, so no fresh arm transition is claimed. This supersedes the generic receive-only label but does not close the parameter-specific T0b failure or prove a workstation-issued command, RC override, changed `SERVO_OUTPUT_RAW`, dashboard/bridge integration or VRX motion. The operator reports the professor repaired the workstation command path and schedules fresh-day full-scale FCU-to-VRX integration for 26/08/2026 with the real electronics active and propellers removed. |
| 01/09/2026 | §3 records the distinct offline T3a implementation. Pi `run-t3a` is a separately gated demand-enabled props-fitted runtime at unchanged command bounds; workstation `t3a --esc-threshold-calibration` is a subscriber-only five-stream recorder with no write path. Contradictory tier approvals fail closed, propulsion enable creates an immediate cleanup obligation, and bounded closeout handling fails closed under missing, invalid, timed-out, `INT` or `TERM` input while still reaching final-state capture and child stops. The recorded default timeout is `300 s`. Focused verification passes `26` recorder tests, `42` helper cases and the regenerated `4/4` manifest. Classification remains **NOT RUN / NOT DEPLOYED**; the 31/08 bundle does not contain these bytes, no hardware result was created and a new commit-named Pi certification remains required before any live approval. |
| 01/09/2026 | §3 records the later Block D deployment closure. Clean published revision `025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba` was deployed to the new Pi root with exact inventory, executable helpers, manifest SHA-256 `11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d` and all four governed hashes verified. The non-actuating helper check ended `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`, and the copied bundle and log reverified at `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`. Classification advances only to **DEPLOYED / CERTIFIED / NOT RUN**. No live runtime, parameter action, arm, propulsion action, threshold, acceptance or Block E authority resulted. |
