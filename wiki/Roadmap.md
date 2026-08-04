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
| Tracked two-command live supervisor | 🟡 17/07/2026 + 03/08/2026 + 04/08/2026 — two IoT runs reached six-topic arrival and automatic rate acceptance (Hailo `7.40/7.50 Hz`; five MAVROS feeds near `1 Hz`). Both combined stock-COCO/MAVLink browser views were operator-confirmed, MAVROS stayed connected/disarmed, and zero messages were observed on the five monitored command topics. Pi peaks were `68.3/67.2 C`; both Pi log directories were copied back. Pi fail-closed and workstation teardown markers passed after the workstation dashboard stack became unavailable unexpectedly before the intended Pi-first stop in both runs; that cause remains open. **03/08/2026:** two view-only runs completed the source window, entered the monitored hold and exited `status=0` on a normal Pi-first operator stop, with post-teardown temperature recorded, so both of the lifecycle items outstanding at 17/07 are now obtained. Both runs also reproduced a daemonless graph-query defect: a fresh `ros2 topic info --verbose` process can return a successful but transiently incomplete snapshot. **04/08/2026:** a batched MAVROS source view landed behind `LIVE_MAVROS_SOURCE_BATCH`, off by default, and a flag-off canary passed end to end (`PI_DATA_ARRIVED=PASS topics=6 elapsed=272s`, rate probes PASS, `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=115s`, both exits `status=0`). The defect recurred in that control run at `2` non-verifying readings, and per-run control counts are now `11`, `3` and `2`, so the variance exceeds any effect three runs could resolve. The batched path is **unexercised live**. Browser-last ordering, full endurance, optimized transport, GPS fix, custom-detector accuracy/calibration/live integration, and all FCU writes remain open. |
| Workstation → Pi 5 desktop access | ✅ 22/05/2026 — GNOME Remote Desktop over RDP verified from workstation Remmina to `10.120.2.162:3389` after compositor check returned `wayland ubuntu:GNOME ubuntu`. `wayvnc` ruled out because this Pi image is GNOME / Mutter, not wlroots; RealVNC Server remains Xorg-only fallback. Desktop Sharing + Remote Control mirror the physical Pi desktop session; Remote Login intentionally left off because it creates a separate session. |
| Pi 5 YOLO CPU feasibility and workstation training path | ✅ 09/06/2026 + 10/06/2026 + 23/06/2026 + 24/06/2026 + 25/06/2026 + 26/06/2026 — Pi-local environment `~/venvs/yolo-pi5` installed and loaded `yolo26n.pt` on aarch64 with `torch-2.12.0+cpu`; NCNN export produced `yolo26n_ncnn_model` (`model.ncnn.bin` 9.3M, `model.ncnn.param` 26K). Static-image NCNN inference used the `bus.jpg` fallback, returned `detections: 5`, and measured preprocess 17.24 ms / inference 244.42 ms / postprocess 15.05 ms at `imgsz=320` on CPU. The 10/06 demo repeated static-image inference for 5 runs, with 5 detections each run, mean inference `84.09` ms, and temp 68.8 C -> 72.2 C. On 23/06, the workstation path passed a CUDA train -> NCNN export smoke test with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, `yolo26n.pt`, and `NVIDIA RTX A3000 Laptop GPU`: one-epoch `coco8.yaml` training wrote `runs/smoke/weights/best.pt`, then NCNN export wrote `runs/smoke/weights/best_ncnn_model`. That workstation-exported NCNN model was copied to Pi `imt-aqua-drone@10.120.2.249` and ran 3 static CPU inferences at `imgsz=640` on `000000000042.jpg`, with `boxes=2`, steady-state inference `226.0-281.1` ms, and temp `68.85 C -> 68.30 C` with no undervoltage / throttle evidence. On 24/06, the first RealSense RGB pipeline-validation pilot was captured, reviewed, labeled, and split outside the repo: 7 `person` images plus 4 clean negatives became a tiny 9/2 train/val split, all active label rows used class `4`, all coordinates were normalized, and rejected frames/labels were excluded from train/val. On 25/06, workstation-only training used that tiny split with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, and CUDA on `NVIDIA RTX A3000 Laptop GPU`: `yolo26n.pt` trained for 50 epochs into `runs/baseline_yolo26n/weights/best.pt`, validation was rerun to `runs/val_baseline_yolo26n`, and NCNN export wrote `runs/baseline_yolo26n/weights/best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Later 25/06, that custom NCNN export loaded and ran on the Pi as a static-image CPU check in `~/venvs/yolo-pi5` with Ultralytics `8.4.62` / `ncnn 1.0.20260526`; both saved validation images returned `0` boxes at the default confidence threshold, so detections remain informational only. A later bounded ROS-camera-node procedure fed RealSense RGB frames into the custom NCNN model: F1 saved 5 frames and ran inference, then F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` and `mean_inf_ms=340.9` before the intended `80.0 C` abort fired at `80.95 C`; the Pi had little thermal headroom from a roughly `72.7-73.8 C` baseline, so this points to cooling rather than a proven model infeasibility. On 26/06, `pyrealsense2 2.58.2` was installed only in the separate `~/venvs/yolo-pi5-rs`; direct camera-only capture proved `900` frames in `60.0 s` at `14.99 fps`, and a direct-SDK -> custom NCNN short run at `imgsz=640` completed `150` frames in `23.1 s` at `mean_fps=6.51` / `mean_inf_ms=151.9` with temp `57.3 C -> 68.85 C` and `0` boxes. Compared with ROS runs (`6.16-7.98 fps`, `123.8-160.6 ms`), direct SDK showed no meaningful capture-overhead advantage; the workload is inference-bound. The optional `imgsz=320` run segfaulted after model load, likely because the NCNN export was fixed for the `640` input profile; a real `320` test needs a separate workstation NCNN export at `imgsz=320`. The reusable dataset and capture plan now lives in [YOLO_Dataset_Plan](YOLO_Dataset_Plan). This proves dataset/toolchain preparation, tiny custom pilot training/export, static COCO Pi handoff, custom Pi static load/run mechanics, bounded ROS camera-topic -> custom NCNN procedure/safety-abort, direct camera-only SDK capture, and short direct-SDK -> custom NCNN mechanics only: not detector-quality evidence or sustained thermally clean live inference. Dashboard integration, MAVROS/QGC/Herelink, and command/write path remain unrun. |
| Hailo AI HAT+ 13 TOPS acceleration branch | 🟡 01/07/2026 + 02/07/2026 + 03/07/2026 + 07/07/2026 — Pi-side probe confirmed the mounted Hailo-8L board is PCIe-healthy (`1e60:2864`, gen-3 x1), the official pinned row is HailoRT / driver / pyHailoRT `4.24.0`, DFC `3.34.0`, and Model Zoo `2.19.0`, and the workstation Docker suite compiled the custom `yolo26n` checkpoint to `yolo26n_route_a_six_heads.hef` for `HAILO8L` with six raw outputs and no embedded NMS. On 03/07, the Pi installed the pinned `4.24.0` runtime stack on Ubuntu 24.04.4 / kernel `6.8.0-1060-raspi`; matching headers and DKMS passed, `/dev/hailo0` appeared, `fw-control identify` reported architecture `HAILO8L`, Python `HEF` import passed, `parse-hef` confirmed the six-output contract, and `hailortcli run yolo26n_route_a_six_heads.hef` completed `293` frames at `58.22 FPS`. On 07/07, the six-output host-side decode contract was proven on saved frames (`fb308f9`): a same-engine raw-head ONNX isolation decoded the six final head convs back to the graph `output0` to float precision (box max abs `0.0 px`, class max abs `1.178e-7`), so six-output layout handling, direct 4-channel box decode, class sigmoid, and the `data.yaml` class map are settled, and the earlier full-precision box residual is now diagnosed as a Hailo DFC emulation vs ONNX Runtime cross-engine numeric difference amplified by stride, not a decode error. The next Hailo gate — a positive-bearing saved-frame Tier 3 (quantized path -> host decode + NMS + un-letterbox versus Ultralytics) — is blocked upstream on a functional detector: the current tiny `best.pt` fires on none of the available saved frames at `conf=0.25`, including its own training images, so a larger labeled dataset and retrain are the precondition (see [YOLO_Dataset_Plan](YOLO_Dataset_Plan)). Accuracy-grade live RealSense detector input, live ROS image integration, dashboard integration, MAVROS/QGC/Herelink co-loads, and accuracy-grade calibration remain open. |
| Stock-COCO Hailo live dashboard diagnostic | 🟡 15/07/2026 — the D435I/Hailo path published annotated frames on `/hailo/overlay/image_raw`, and the workstation browser displayed live boxes and class labels while minimal MAVROS telemetry was visible. This closes the stock-model image/dashboard mechanics question only; custom detector quality, optimized transport, and full endurance remain open. |
| Detector recovery and proxy training path | 🟡 08/07/2026 + 09/07/2026 — 08/07 Blocks A-C produced the detector baseline inventory, source decision, and external acquisition manifest only. The manifest scopes VRX to `buoy` / `dock` bootstrap rows, marks `vessel` as spawn-required, and leaves `obstacle` / `person` to RealSense, public data admitted through checks, or explicit world authoring. A bounded Pi smoke also proved single-process RealSense -> Hailo -> decode-summary mechanics with the current HEF (`30` frames, `8.61 FPS`, float32 six-output tensors), but the model stayed at the expected zero-detection / `~0.003` confidence floor. The visual target is YOLO-style colored boxes with class / confidence labels, not masks or polygons. The 09/07 scaffold sets up an isolated unicolor-object real-image training smoke to validate capture -> box labeling -> workstation retrain -> held-out firing before maritime data collection. This remains process evidence only, not maritime detector quality, Hailo accuracy, Pi deployment, ROS/dashboard integration, MAVROS/QGC/Herelink, or command/write validation. |

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
   behind a default-off flag but unexercised live. No command/write or
   mission-sync path was opened.

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
