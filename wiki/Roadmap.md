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

---

## 2. Current state (as of 21/04/2026)

### Navigation foundation — ready for hardware

| Layer | Status |
|:------|:------:|
| Perception (3D LiDAR → obstacle info, temporal filtering, VFH) | ✅ |
| Planning (lawnmower + A\* detour) | ✅ |
| Control (PID + Kalman drift compensation + micro-reverse escape) | ✅ |
| Dashboard (Leaflet map + telemetry + 3-panel config + health check) | ✅ |
| Simulation (VRX, `sydney_regatta_DEFAULT` world) | ✅ |
| Safety (latched E-Stop, `std_srvs/Trigger` ACK services, geofence via hazard polygons) | ✅ |

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

> **Canonical detailed reference:** `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` — /wamv/\* topic inventory, `remap.launch.yaml` paper design, bridge-node pseudocode, 24-item supervisor CCU checklist. That document was written as a pre-execution scope plan; all of its contents remain in effect as of 21/04/2026.

### Summary

- **High-level CCU (confirmed):** Raspberry Pi 5, Ubuntu Noble (24.04), ROS 2 Jazzy — all Tier 1 per REP-2000. Dependency versions: Python 3.12.3, NumPy 1.26.4, PCL 1.14.0, OpenCV 4.6.0, Fast-DDS 2.14.0.
- **Low-level CCU (TBD):** Either the Pi drives thrusters directly via GPIO PWM, or a separate microcontroller (STM32 / ESP32 / commercial motor controller) is present. This is the single largest schedule risk — the supervisor conversation decides whether a bridge node is needed at all.
- **Transition path:** paper design is a two-layer remap — `topic_tools/relay` from VRX `/wamv/*` names to neutral `/sensors` / `/actuators` names (layer A), plus an optional bridge node for real-hardware protocol translation (layer B). The three pipeline nodes continue to subscribe to VRX names during Phase 5.0; no code churn required until layer A is proven.

### Status of prep tasks (as of 21/04/2026)

| Task | Status |
|:-----|:------:|
| `/wamv/*` reference inventory across Python / YAML / JS / HTML | ✅ done (in scope plan) |
| `remap.launch.yaml` paper design | ✅ done; runnable file not yet written |
| Bridge-node pseudocode with pass-through behaviour | ✅ drafted |
| Supervisor CCU checklist (24 questions) | ✅ drafted |
| Launcher readiness polls (pre-requisite for Pi 5 slower-CPU timing) | ✅ landed 20/04/2026 |
| Profile `/perception/obstacle_info` Hz in VRX; baseline for Pi 5 comparison | ❌ |
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
- Maintains a 2D spatial grid over the survey area (extent TBD — likely from the hazard polygon, or a dedicated survey-area polygon parameter).
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

- Blocked on regional dataset access (CESER / ECRIN / VERD-Eau / CASTREau / CAP'Eau).
- Ingest regional dataset; align spatially / temporally with the CA-generated field.
- Define validation metric (RMSE per parameter? Spatial correlation? Anomaly-detection precision / recall?).
- ML component (time-permitting): could target anomaly detection on streaming readings (unsupervised or one-class), or trend prediction on the historical field.

---

## 7. Open questions — supervisor conversation

Questions that unblock specific next steps. Organised by phase.

### Pre-Phase-A (parameter set)

1. Which water quality parameters are in scope for this internship? Confirm vs. the recommended default set (pH, turbidity, DO, temperature).
2. Are any parameters *required* to appear in the research deliverable (e.g., for regional-dataset alignment)?

### Phase 5 (Pi 5 bring-up — see also the scope plan in `working_diary/`)

1. Is there a separate low-level CCU between the Pi 5 and the thrusters, or does the Pi drive them directly?
2. If separate: what chip, physical link, protocol? Any existing ICD / firmware?
3. Thruster type and thrust range (for mapping the current 0–800 VRX scale to real Newtons / PWM duty)?
4. Test-lake or test-site GPS coordinates for the geofence polygon?

### Phase D (real probe)

1. Probe make / model, protocol (serial? I²C? CAN?), output rate, power requirements?
2. Probe mounting plan on the boat?

### Phase E (validation & ML)

1. Which regional dataset can we obtain access to, and in what format?
2. Is ML a required deliverable or a stretch goal? Specific technique the supervisors expect (e.g., supervised regression, anomaly detection, LSTM)?

### Process

1. Expected delivery format — live demo? Written report? Conference-paper draft?
2. Timeline checkpoints between now and end-of-internship?

---

## 8. Revision log

| Date | Change |
|:-----|:-------|
| 21/04/2026 | Initial version. Consolidates Phase 5 scope summary (detail in `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`), adds research-extension architecture and Phase A consulting scope. |
