# 2026-05-16 — Obj 3 methodology revision

## Why this doc exists

The 30/04/2026 on-site scoping meeting outcomes were recorded in
`working_diary/2026-04-30_thursday_delivery_and_post_wrap.md` Block C,
summarised in `Board.md` Timeline 30/04 row, and propagated to
`wiki/Roadmap.md` §1.1 + §1.2 + §6 Phase E + §7 + §9 revision log.

A re-reading of the original Internship project draft PDF + reflection
on the 30/04 conversation surfaced two methodology framings on Obj 3
that differ from what 30/04 diary recorded. This addendum captures the
divergence + open methodology questions for supervisor confirmation
before the Wed 20/05/2026 10h-12h formal joint presentation.

The 30/04 diary itself stays as-is (frozen per working_diary editing
convention); this file is the forward-update record.

## Original PDF text (Internship project draft) — verbatim

> Objectives
>
> The main objectives of this internship is to design and implement a
> digital twin using our simulator and real prototype for spatio-temporal
> water quality monitoring, as follows:
>
> 1. Integration of real data into the simulator coming from the drone
>    using the ROS ecosystem.
> 2. Implement computational models, such as cellular automata, to
>    simulate the evolution of key water quality parameters using data
>    streamed from the drone. Then, display the data as a water quality
>    map within our existing interface.
> 3. Validate the generated map using existing datasets from regional
>    projects. Leverage our existing work to propose a machine learning
>    technique to predict water quality trends and identify anomalies
>    (if time permits).

## 30/04 diary record vs Current re-articulation

| | 30/04 diary record | Current re-articulation |
|---|---|---|
| **Obj 1 "real data"** | Boat-own state (velocity / GPS / IMU); water-sensor data belongs to Obj 2 | Same — boat state, not water sensor |
| **Obj 1 bridge tool** | MAVROS is the bridge; MAVProxy is a router not the bridge | "MAVProxy or MAVROS if possible" — treated as interchangeable |
| **Obj 2 CA placement** | Most likely Linux-side | Unresolved (Pi or Linux either) |
| **Obj 3 regional datasets** | REMOVED — insufficient accessible regional data | Same — removed |
| **Obj 3 validation** | Same-day R1 train + R2 holdout in one outing; no temporal confound; day-gap return acceptable only for slow-changing parameters | Day 1 collect → CA predicts area A → Day 3 return to a different sub-area of A → compare real vs predicted |
| **Obj 3 ML** | "ML trained on CA outputs" framing rejected; replaced with residual-based anomaly detection + time-series forecasting + physics-informed ML (stretch) | Trained model deriving from the CA function → auto-identify anomalies fast |

The two readings of Obj 3 validation + ML are not "summary vs detail" —
they are substantively different methodologies. Both emerged from the
same 30/04 conversation. The 30/04 diary captured one reading; the
Current re-articulation captures another.

## Open methodology questions for supervisor confirmation

### Q1 — Validation: same-day vs day-gap

| Approach | Pro | Con |
|---|---|---|
| Same-day R1 train + R2 holdout | No temporal confound — water condition near-constant within one outing | Smaller training set per session; one out-of-distribution check |
| Day-gap (2-3 days) return to different sub-area | More data per training run; spatial cross-validation across area A | Natural temporal drift (DO, temperature, algae bloom) mixes with model error — "real Day-3 minus predicted Day-1" can't disentangle |

The slow-changing-vs-fast-changing parameter distinction matters:

- **Slow-changing within typical 2-3 day window**: pH, salinity,
  conductivity — daily natural variation typically << measurement noise
  → day-gap return acceptable.
- **Fast-changing**: dissolved oxygen (DO), temperature, chlorophyll-a —
  diurnal + weather-driven variation can be significant → same-day
  holdout preferred.

**Proposed default**: split the validation per parameter — slow
parameters use day-gap return (collect more spatial coverage), fast
parameters use same-day R1/R2 holdout (control temporal confound). Or
commit fully to one methodology and accept its limits.

### Q2 — ML: trained on what?

Three candidate framings:

#### Option A: ML trained on CA outputs (= "model deriving from CA function")

- Mechanism: feed CA prediction maps to ML → ML learns to approximate
  CA quickly
- Use case: replace slow CA inference with fast ML inference at
  deployment
- Issue: ML cannot detect anomalies the CA model itself doesn't already
  flag — it inherits CA's blind spots completely. **Circular for
  anomaly detection.**

#### Option B: ML trained on residuals (= "real measurement − CA prediction")

- Mechanism: collect (real, CA-predicted) pairs at each sampled point →
  compute residual → train ML on residual distribution
- Use case: detect points where measurements deviate significantly from
  CA prediction → those are anomaly candidates
- Why this works: CA captures bulk dynamics; ML learns where CA fails;
  failure points = anomaly candidates. **Non-circular.**
- This is what the 30/04 diary recorded as "residual-based anomaly
  detection".

#### Option C: ML on raw measurements + physics-informed constraints (stretch)

- Train ML directly on sensor measurements with physics regularisation
  (mass conservation, advection-diffusion, parameter ranges)
- More ambitious; deferred as stretch goal in the 30/04 diary record

**Proposed default**: Option B as the working framing for anomaly
detection. Option A useful only if deployment compute budget is the
bottleneck — and Option A alone does not deliver anomaly detection.
Option C as stretch.

### Q3 — Water sensor physical interface (related, but Obj 2 / Obj 1 boundary)

The 30/04 conversation did not resolve where the water quality sensor
physically connects:

- (a) **Pi 5 directly** (USB / I2C / serial) → Python ROS publisher node
  on Pi 5
- (b) **Linux workstation directly** → no network transport for sensor
  data; CA must run Linux-side
- (c) **Autopilot via custom MAVLink message** → routed through MAVROS
  alongside boat-state telemetry

The decision affects Obj 1 (data-flow architecture) AND Obj 2 (CA
placement consequence). Needs supervisor / teammate confirmation.

## Tooling note — MAVProxy vs MAVROS (Obj 1 architecture clarification)

The 30/04 diary distinguished the two; the Current re-articulation
treated them as interchangeable. For record:

| Tool | Role | In this architecture |
|---|---|---|
| **MAVProxy** | MAVLink router + CLI ground station; can fan-out one MAVLink link to multiple consumers (QGC + MP + custom Python + ...) | Useful for debug, multiplexing, alternate GCS. Does NOT speak ROS. |
| **MAVROS** | ROS package that bridges MAVLink ↔ ROS topics / services / actions | The actual MAVLink ↔ ROS translator. ROS 2 Jazzy has `ros-jazzy-mavros` — supported. |

The teammate's bring-up recipe (`mavproxy.py --master=/dev/serial0` +
`stream_data.py`) is **initial connectivity verification** (heartbeat
check + Python script using PyMAVLink to stream IMU). It is **not** the
production data flow. The production architecture for Obj 1 needs
MAVROS launched on Pi 5 (e.g.,
`ros2 launch mavros apm.launch fcu_url:=/dev/serial0:115200`) so that
IMU / GPS / heartbeat / SET_POSITION_TARGET become real ROS topics
discoverable from the Linux workstation.

PEP 668 caveat (Ubuntu 24.04 + Python 3.12): `python3 -m pip install
mavproxy --user` errors with `externally-managed-environment`. Use
`pipx install mavproxy`, or `--break-system-packages`, or a venv. The
30/04 `wiki/Pi5_Bringup_Smoke_Test.md` already documented this.

## Next steps before Wed 20/05/2026 10h-12h presentation

- Bring Q1 / Q2 / Q3 to the maintainer team Asks list. Current three
  pending Asks (Phase A parameter subset, CA placement, validation
  methodology) overlap with Q1 + Q3 — Q2 (ML framing) is a new ask.
- Mon 18/05 + Tue 19/05 are the PPT prep window; get supervisor's read
  on Q1 + Q2 **before** the deck lands so the methodology slides
  don't take live pushback.
- If Q1 / Q2 / Q3 unresolved by Wed, flag as open in the PPT under
  "open questions" rather than commit to either reading.

## Pointers

- 30/04 diary entry: `working_diary/2026-04-30_thursday_delivery_and_post_wrap.md` Block C
- Roadmap entries: `wiki/Roadmap.md` §1.1 + §1.2 + §6 Phase E + §7 + §9
- Board.md Timeline 30/04 row
- This addendum supersedes the 30/04 reading **only** on Obj 3
  validation + ML framings, pending supervisor confirmation.
