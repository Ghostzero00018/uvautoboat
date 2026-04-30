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

**Obj 1 — "real sensor data from the drone".** Scope = boat **telemetry** (GPS, IMU, velocity, etc.) flowing from the low-level controller through the Pi 5 (Ubuntu 24.04 + ROS 2 Jazzy, headless, on the *IoT IMT Nord Europe* network) into the VRX simulator on the Linux workstation. Water-quality sensor data is **not** part of Obj 1 — it belongs under Obj 2. Both streams ultimately reach the simulator, but Obj 1 owns only the telemetry plumbing. The simulator mirrors the real boat's pose; this is the digital-twin baseline.

Architecture inside Obj 1:

- **MAVLink ↔ ROS bridge on the Pi 5.** `mavros2` (the ROS 2 port of MAVROS) translates MAVLink frames from the low-level controller into ROS topics; ROS commands flow the other way. **MAVProxy is *not* the bridge** — it is a MAVLink router/multiplexer for fanning out to additional ground-control tools (QGroundControl, Mission Planner) when needed. The two are easy to confuse and have been in the project's discussion notes.
- **Pi 5 ↔ Linux workstation via ROS 2 / DDS** over the shared IoT WiFi. Direct topic discovery once both nodes share the same `ROS_DOMAIN_ID`. **Caveat:** corporate IoT networks frequently block multicast (DDS's default discovery transport) or isolate WiFi clients. This must be verified early with a basic `talker` / `listener` round-trip before serious pipeline work. Workarounds if multicast fails: Fast-DDS Discovery Server (unicast), Cyclone DDS peer list, or direct Ethernet during testing.

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

---

## 2. Current state (as of 24/04/2026)

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
| Regional dataset validation | ❌ (blocked on dataset access) |
| ML for trend / anomaly detection | ❌ (time-permitting) |

---

## 3. Phase 5 — Real-Hardware Deployment

> **Canonical detailed reference:** `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` — /wamv/\* topic inventory, `remap.launch.yaml` paper design, bridge-node pseudocode, 24-item supervisor CCU checklist. Pre-execution scope plan; the topic inventory and remap design still stand (`remap.launch.yaml` shipped 22/04/2026). The 23/04/2026 supervisor walk-through narrowed the bridge-node target toward a MAVLink-speaking autopilot and partially answers the CCU checklist — see the Summary bullets below for the current working hypothesis.

### Summary

- **High-level CCU (confirmed):** Raspberry Pi 5, Ubuntu Noble (24.04), ROS 2 Jazzy — all Tier 1 per REP-2000. Dependency versions: Python 3.12.3, NumPy 1.26.4, PCL 1.14.0, OpenCV 4.6.0, Fast-DDS 2.14.0.
- **Low-level CCU (TBD — likely autopilot):** Supervisor's 23/04/2026 request to install Mission Planner + QGroundControl strongly suggests a MAVLink-speaking autopilot (ArduPilot or PX4) sits between the Pi 5 and the thrusters — both GUIs assume a MAVLink-compatible flight controller. The specific chip and firmware are still open. Alternative paths (Pi drives thrusters directly via GPIO PWM, or a non-MAVLink microcontroller as earlier hypothesised) remain logically possible but lower-probability given the 23/04 signal. Either way this is the single largest schedule risk — whether a bridge node is needed at all, and what protocol it speaks, hangs on the supervisor confirmation.
- **Transition path:** paper design is a two-layer remap — `topic_tools/relay` from VRX `/wamv/*` names to neutral `/sensors` / `/actuators` names (layer A), plus an optional bridge node for real-hardware protocol translation (layer B). The three pipeline nodes continue to subscribe to VRX names during Phase 5.0; no code churn required until layer A is proven.
- **Phase 5.2+ dashboard integration (longer-term, prof request 23/04):** web dashboard should eventually issue waypoints and read telemetry *through* MP/QGC as the autopilot front-end, rather than directly against ROS 2 nodes. Requires a MAVLink bridge on the Pi 5 (`mavros` / `mavsdk` / similar) plus dashboard-side MAVLink emit/subscribe. Explicitly out of Phase 5.0 bring-up scope; preserved current dashboard UX as the behavioural target the MAVLink-bridged version must match.

### Status of prep tasks (as of 24/04/2026)

| Task | Status |
|:-----|:------:|
| `/wamv/*` reference inventory across Python / YAML / JS / HTML | ✅ done (in scope plan) |
| `remap.launch.yaml` paper design + runnable file | ✅ deployed 22/04/2026; 6 relays + conditional bridge stub |
| Bridge-node pseudocode with pass-through behaviour | ✅ drafted |
| Supervisor CCU checklist (24 questions) | ✅ drafted |
| Launcher readiness polls (pre-requisite for Pi 5 slower-CPU timing) | ✅ landed 20/04/2026 |
| Profile `/perception/obstacle_info` Hz in VRX; baseline for Pi 5 comparison | ✅ 20.00 Hz at RTF ≈ 1.0 (22/04/2026); rate tracks Gazebo RTF |
| Install Mission Planner + QGroundControl on Linux workstation (prof-requested toolchain) | ✅ 24/04/2026 — MP 1.3.9384.38258 + QGC stable-daily 09/10/2025; MP-under-Mono GDAL / OGR / OSR degraded (Windows `.msi` fallback held for GIS demos) |
| Pi 5 ↔ flight-controller bring-up smoke-test procedure documented | ✅ 30/04/2026 — see [Pi5_Bringup_Smoke_Test.md](Pi5_Bringup_Smoke_Test.md): SSH + UART + dialout setup, MAVProxy install (with PEP 668 caveat for Ubuntu 24.04), heartbeat verify, `stream_data.py` IMU smoke test with 8 known issues catalogued + suggested fixes |
| Shore-comms plan (WiFi range test, 4G fallback) | ❌ |

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

## 8. Sim infrastructure — VRX upstream fork (scheme only, not active)

> **Status:** scheme only — *not* a planned task. This section captures the option to fork `osrf/vrx`, with explicit trigger conditions so the future fork-or-don't decision can be made on evidence rather than vibes.

### 8.1 Today's baseline

Project consumes upstream VRX via apt + a single workaround patch (`patch_vrx.sh` for the LiDAR-at-origin bug, upstream issue #876). One patch sits well under the threshold past which forking starts to make sense.

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
| **Continue patches** (current) | ~0 | ~zero while patch count stays <3 |
| **Fork** + CI + rebase strategy + contributor docs | ~1-2 days | ~1-2 h per upstream sync |
| **Contribute upstream** | depends on fix | none after merge — upstream owns it |

The fork path becomes cheaper than continued patches only when ongoing patch-maintenance time exceeds ongoing rebase time. Today's 1 patch is far from that crossover.

### 8.5 Explicit "not now"

This is captured for traceability, not action. Re-open this section only when one of the §8.2 triggers fires.

---

## 9. Revision log

| Date | Change |
|:-----|:-------|
| 21/04/2026 | Initial version. Consolidates Phase 5 scope summary (detail in `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`), adds research-extension architecture and Phase A consulting scope. |
| 24/04/2026 | Phase 5 summary reworded for 23/04 supervisor hardware walk-through: Pi 5 visually verified inside CCU; MP/QGC install added as prep task; low-level CCU note now flags "likely autopilot" as the working hypothesis from prof's MP/QGC ask; new bullet for Phase 5.2+ dashboard-through-MAVLink longer-term goal; Phase 5 open-questions list gains an autopilot / MAVLink-topology question. |
| 30/04/2026 | Added §8 Sim infrastructure — VRX upstream fork captured as scheme-only with triggers / what-it-won't-solve / cost / explicit "not now" framing. Revision log renumbered §8 → §9. |
| 30/04/2026 | §1.1 Scope clarifications + §1.2 Open questions added after the on-site scoping meeting (smaller scale than planned — campus power outage + IMT Mines Alès supervisor unavailable, so the on-site team ran its own session): Obj 1 = telemetry only (water-sensor data is Obj 2); MAVROS as the canonical MAVLink↔ROS bridge (MAVProxy is a router, not the bridge); DDS-over-IoT-WiFi multicast verification flagged as early-priority; CA placement most likely Linux-side; "regional datasets" portion of Obj 3 removed (insufficient accessible regional historical data); validation refined to same-day cross-validation; ML scope refined (residual-based + time-series + physics-informed; "ML trained on CA outputs" rejected). §6 Phase E rewritten to match. §7 top note + Phase E sub-list refresh. |
| 30/04/2026 | §3 Phase 5 status table gains a row for the Pi 5 ↔ flight-controller bring-up smoke-test procedure (`wiki/Pi5_Bringup_Smoke_Test.md`): SSH + UART/dialout setup, MAVProxy install with PEP 668 caveat for Ubuntu 24.04, heartbeat verify, IMU smoke test via `stream_data.py` (received from team) — 8 known issues catalogued (legacy `MAV_DATA_STREAM_*` API + 1 Hz IMU rate too slow + missing heartbeat timeout + others), modern `MAV_CMD_SET_MESSAGE_INTERVAL` replacement provided. Bring-up order documented (1. heartbeat, 2. direct script, 3. UDP fanout, 4. mavros2, 5. simulator integration). Cross-linked from `wiki/Home.md` under a new "🔌 Hardware Bring-up" section. |
