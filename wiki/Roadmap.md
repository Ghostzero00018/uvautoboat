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

**Obj 1 — "real sensor data from the drone".** Scope = boat **telemetry** (GPS, IMU, velocity, etc.) flowing from the low-level controller through the Pi 5 (Ubuntu 24.04 Server + ROS 2 Jazzy, headless permanently per supervisor directive 13/05/2026, on the *IoT IMT Nord Europe* network) into the VRX simulator on the Linux workstation. Water-quality sensor data is **not** part of Obj 1 — it belongs under Obj 2. Both streams ultimately reach the simulator, but Obj 1 owns only the telemetry plumbing. The simulator mirrors the real boat's pose; this is the digital-twin baseline.

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

**Constraint.** The IoT IMT Nord Europe network is institutional / IoT-managed, not a normal open campus internet link. The 30/04 working assumption was "local-only / no internet"; the 13/05 Pi-side pre-flight refined that: from the Pi (`10.120.2.50/23`), IPv4 DNS resolved `archive.ubuntu.com` and `curl -4 -sI http://archive.ubuntu.com/ubuntu/` returned `HTTP/1.1 200 OK`, while public ICMP to `1.1.1.1` was blocked. Treat this as **partial managed egress**: apt HTTP egress worked for that Pi-side test, but general internet, workstation-side internet while attached to the IoT SSID, and OpenStreetMap tile availability must not be assumed. Pi 5 ↔ Linux workstation traffic stays on the IoT LAN for ROS 2 / SSH. The original dashboard design implicitly assumed open internet; Path A (05/05/2026) removed the library/font dependencies, while Path B remains required for deterministic offline map tiles before IoT-network deployment.

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

### Research layers — not yet started

| Layer | Status |
|:------|:------:|
| Water-quality sensor streaming (ROS topic contract) | ❌ |
| Cellular-automata spatio-temporal model | ❌ |
| Water-quality map visualization in dashboard | ❌ |
| Real probe integration | ❌ (blocked on hardware) |
| Regional dataset validation | ❌ removed from scope 30/04/2026 — accessible regional historical data insufficient; replaced by same-day cross-validation. See §1.1 + §6 Phase E. |
| ML for trend / anomaly detection | ❌ (time-permitting) |

---

## 3. Phase 5 — Real-Hardware Deployment

> **Canonical detailed reference:** `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` — /wamv/\* topic inventory, `remap.launch.yaml` paper design, bridge-node pseudocode, 24-item supervisor CCU checklist. Pre-execution scope plan; the topic inventory and remap design still stand (`remap.launch.yaml` shipped 22/04/2026). The 23/04/2026 supervisor walk-through narrowed the bridge-node target toward a MAVLink-speaking autopilot and partially answers the CCU checklist — see the Summary bullets below for the current working hypothesis.

### Summary

- **High-level CCU (confirmed):** Raspberry Pi 5, Ubuntu Noble (24.04), ROS 2 Jazzy — all Tier 1 per REP-2000. Dependency versions: Python 3.12.3, NumPy 1.26.4, PCL 1.14.0, OpenCV 4.6.0, Fast-DDS 2.14.0.
- **Low-level CCU (TBD — likely autopilot):** Supervisor's 23/04/2026 request to install Mission Planner + QGroundControl strongly suggests a MAVLink-speaking autopilot (ArduPilot or PX4) sits between the Pi 5 and the thrusters — both GUIs assume a MAVLink-compatible flight controller. The specific chip and firmware are still open. Alternative paths (Pi drives thrusters directly via GPIO PWM, or a non-MAVLink microcontroller as earlier hypothesised) remain logically possible but lower-probability given the 23/04 signal. Either way this is the single largest schedule risk — whether a bridge node is needed at all, and what protocol it speaks, hangs on the supervisor confirmation.
- **Transition path:** paper design is a two-layer remap — `topic_tools/relay` from VRX `/wamv/*` names to neutral `/sensors` / `/actuators` names (layer A), plus an optional bridge node for real-hardware protocol translation (layer B). The three pipeline nodes continue to subscribe to VRX names during Phase 5.0; no code churn required until layer A is proven.
- **Phase 5.2+ dashboard integration (longer-term, prof request 23/04):** web dashboard should eventually issue waypoints and read telemetry *through* MP/QGC as the autopilot front-end, rather than directly against ROS 2 nodes. Requires a MAVLink bridge on the Pi 5 (`mavros` / `mavsdk` / similar) plus dashboard-side MAVLink emit/subscribe. Explicitly out of Phase 5.0 bring-up scope; preserved current dashboard UX as the behavioural target the MAVLink-bridged version must match.

### Status of prep tasks (baseline 24/04/2026; rows added 30/04/2026 for bring-up doc + IoT-local dashboard prep)

| Task | Status |
|:-----|:------:|
| `/wamv/*` reference inventory across Python / YAML / JS / HTML | ✅ done (in scope plan) |
| `remap.launch.yaml` paper design + runnable file | ✅ deployed 22/04/2026; 6 relays + conditional bridge stub |
| Bridge-node pseudocode with pass-through behaviour | ✅ drafted |
| Supervisor CCU checklist (24 questions) | ✅ drafted |
| Launcher readiness polls (pre-requisite for Pi 5 slower-CPU timing) | ✅ landed 20/04/2026 |
| Profile `/perception/obstacle_info` Hz in VRX; baseline for Pi 5 comparison | ✅ 20.00 Hz at RTF ≈ 1.0 (22/04/2026); rate tracks Gazebo RTF |
| Install Mission Planner + QGroundControl on Linux workstation (prof-requested toolchain) | ✅ 24/04/2026 — MP 1.3.9384.38258 + QGC stable AppImage 09/10/2025; MP-under-Mono GDAL / OGR / OSR degraded (Windows `.msi` fallback held for GIS demos). **11/05/2026 update**: MP-Linux video panel + arm/disarm path unblocked via host-local SkiaSharp 2.88.8 + `libdl.so` symlink fix (see `wiki/Common_Issues.md` MP-Linux entry). **12/05/2026 diagnosis**: GDAL/OGR/OSR still degraded because MP bundles Windows PE native wrappers, not Linux `.so`; not the same musl→glibc class as SkiaSharp |
| Pi 5 ↔ flight-controller bring-up smoke-test procedure documented | ✅ 30/04/2026 — see [Pi5_Bringup_Smoke_Test](Pi5_Bringup_Smoke_Test): SSH + UART + dialout setup, MAVProxy install (with PEP 668 caveat for Ubuntu 24.04), heartbeat verify, `stream_data.py` IMU smoke test with 8 known issues catalogued + suggested fixes |
| Pi 5 ↔ workstation DDS cross-machine discovery on `IoT IMT Nord Europe` | ✅ 12/05/2026 — verified with Pi-side `/pi5_dds_probe` publisher and workstation-side `ros2 topic echo --once`; discovery + transport both work. Standard ROS 2 graph discovery is sufficient for Phase 5 driver bring-up; Fast-DDS Discovery Server unicast config not required for this WiFi |
| Dashboard offline-capable for IoT / restricted-egress deployment | 🔄 path A landed 05/05/2026 (vendored `roslibjs` + Leaflet + Google Fonts under `web_dashboard/autoboat/vendor/`, ~516 KB; dashboard now CDN-free for the 3 main lib deps); path B (offline tile server, pre-generated MBTiles for test area) still future and required before relying on the map panel during IoT-network deployment. |
| Shore-comms plan (WiFi range test, 4G fallback) | ❌ |
| Pi 5 power budget for RealSense + co-loads | 🔄 13/05/2026 — temporary fix in place (Pi 5 on its own USB-C charger separate from the main 14.8V LiPo battery rail; brownout root-cause identified for prior "sleep" symptoms, was PMIC under-voltage shutdown at ~4.63 V under RealSense streaming load via 5V-GPIO-pin power). Permanent Phase 5 fix is hardware-side: regulated ≥5A dedicated 5V supply, thick-short GPIO leads (or proper USB-C input), bulk capacitance near Pi power input, possibly a powered USB hub between Pi and RealSense to fully decouple current spikes. |
| RealSense → ROS bridge via `realsense2_camera_node` | ✅ 13/05/2026 — `realsense2_camera_node` v4.57.7 on Pi (Intel RealSense D435I serial 213622070342, FW v5.14.0, USB 2.1; Pi hub port enumeration varied across sessions — `2-1` dominant, `1-1` observed once in the 17:14 pre-reboot run, see 18/05 log audit) publishes full topic surface (`/camera/camera/{color,depth,infra1,infra2}/{image_*,camera_info,metadata}`, `/accel/sample`, `/gyro/sample`, `/extrinsics/*`, `/tf_static`) discoverable cross-machine from workstation with `ROS_DOMAIN_ID=0` (workstation `~/.bashrc` `ROS_DOMAIN_ID=56` unset for the test). `rviz2` is the correct workstation viewer command (`rviz` package name / command is absent on Jazzy); `rqt` can list standard image topics but needs the `realsense2_camera_msgs` interfaces installed locally before it can introspect the RealSense custom metadata / extrinsics messages. Validates the "dedicated Pi-side ROS bridge" architectural prediction from `working_diary/2026-05-13` C.7 outcome (ii). |
| Camera consumer exclusivity — Pi ROS bridge vs Herelink RTSP video | ⚠ 13/05/2026 — observed constraint: when `realsense2_camera_node` runs on Pi and workstation rviz2 streams from it, Herelink console video stream is lost; rviz2 stop → Herelink video returns. Likely v4l2 device-exclusivity (`VIDIOC_S_FMT` `errno=16 Device or resource busy` matches the symptom), breaking the existing `v4l2loopback`-based fork that the Herelink RTSP path relies on. Phase 5 implication: autonomy-stack camera consumption and Herelink operator video are mutually exclusive under current Pi setup unless a different sharing mechanism is engineered (single canonical camera node + RTP republish for Herelink, or multi-mux camera-fork daemon). |

### Blockers

1. **Supervisor CCU conversation** — unblocks the decision to build a bridge node or not.
2. **Hardware arrival** — unblocks Pi 5 bring-up, build, bench test.

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
