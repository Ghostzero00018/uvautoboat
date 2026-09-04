# Digital Twin Architecture — Standards Positioning

> Reference doc. Captures the standards-context and architectural-positioning rationale for this project's digital-twin framing. Cross-referenced from [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026), [Roadmap §4](Roadmap#4-research-extensions--architecture), and [System Overview](System_Overview).

---

## 1. Purpose

Several places in the repo describe this project's water-quality monitoring USV as a "digital-twin baseline" (see [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026) and the §4 research-extensions architecture diagram). Since 02/09/2026, that baseline also has a bounded real-FCU implementation: measured flight-controller output drives VRX, and VRX pose/thrust telemetry returns to the same dashboard. This page makes the positioning explicit so that downstream artifacts (formal documents, conference paper drafts, future operator-facing material) reference it consistently.

This page is **internal positioning notes**, not a normative architecture spec — the canonical runtime architecture lives in [System Overview](System_Overview) and the launch / source code.

---

## 2. Standards context

Two ISO documents are relevant.

### 2.1 ISO/IEC 30141:2024 — IoT reference architecture

ISO/IEC 30141:2024 (Internet of Things (IoT) — Reference architecture) is the **domain-neutral** parent reference architecture for IoT systems. It defines a layered IoT system structure that applies across manufacturing, agriculture, environmental monitoring, smart cities, healthcare, and other IoT domains. The 2024 edition supersedes the 2018 edition.

For an aquatic environmental-monitoring USV — distributed sensors, network communication, edge / host compute, application layer — this is the closest direct-fit reference among published ISO standards.

### 2.2 ISO 23247 — Digital twin framework for manufacturing

ISO 23247 specializes the ISO/IEC 30141 layered pattern for **manufacturing** (machines, robots, machining cells, fastener assembly, factory floors). Published by ISO/TC 184/SC 4. Current parts:

| Part | Title | Status |
|:-----|:------|:-------|
| Part 1 | Overview and general principles | Published 2021 |
| Part 2 | Reference architecture | Published 2021 |
| Part 3 | Digital representation of manufacturing elements | Published 2021 |
| Part 4 | Information exchange | Published 2021 |
| Part 5 | Digital thread for digital twin | Under publication |
| Part 6 | Digital twin composition | FDIS / under development |

ISO 23247 inherits its layered structure from ISO/IEC 30141 and instantiates it with manufacturing-specific protocols (MTConnect, OPC/UA, QIF, AP242) and manufacturing-specific use cases (robot drill-and-fill for airframes, aircraft skin weight reduction, gear-box machining monitoring — surveyed in the third-party explainer at <https://www.ap238.org/iso23247/>). The four layers, in ISO 23247 vocabulary, are:

1. **Observable Manufacturing Elements** — physical objects (machines, robots, workpieces). Not officially part of the framework; pre-existing physical reality.
2. **Device Communication Entity** — collates state changes; sends control programs.
3. **Digital Twin Entity** — reads collated data; updates twin models.
4. **User Entity** — applications layer (ERP, PLM, plus new analytical apps).

### 2.3 Positioning of this project

This project is an **aquatic environmental-monitoring USV**, not a manufacturing system. The positioning is therefore:

- **ISO/IEC 30141:2024** is the primary domain-neutral reference for the layered structure.
- **ISO 23247:2021 (Parts 1-4)** is a **worked manufacturing instantiation** that demonstrates how a 30141-style pattern is concretely realized end-to-end. The structural pattern is informative; the protocol choices (MTConnect, OPC/UA, QIF, AP242) are manufacturing-specific and **do not transfer** to this project.
- This project should not be described as "implementing ISO 23247." The standard's scope is explicitly manufacturing. The honest description is "adapting the layered DT pattern for environmental monitoring."

---

## 3. Layer mapping for this project

| Layer (per 30141 / 23247 vocabulary) | This project's realization |
|:-------------------------------------|:----------------------------|
| **L1 — Physical / Observable entities** | USV hull + thrusters; the real boat's Cube Orange+ running ArduRover 4.6.3; the water body itself. Multi-parameter water sensors (pH, dissolved oxygen, turbidity, temperature and conductivity) remain a planned physical-layer extension; see [Roadmap §3](Roadmap#3-phase-5--real-hardware-deployment). |
| **L2 — Device communication** | ROS 2 Jazzy nodes and topics over the `IoT IMT Nord Europe` Wi-Fi (DDS cross-machine discovery verified 12/05/2026); MAVROS as the MAVLink-to-ROS bridge on the Pi; guarded RC demand and measured `/mavros/rc/out`; relays between the real-FCU domain and the local VRX domain. |
| **L3 — Digital twin entity** | **Implemented:** VRX / Gazebo receives thrust derived from measured flight-controller output and returns pose and thrust telemetry. **Planned research extension:** cellular-automata propagation and sim-side water-quality field reconstruction ([Roadmap §6](Roadmap#6-phases-b--e-sketches-not-yet-scoped) Phase B), followed by predict-ahead and what-if functions. |
| **L4 — User / Application** | Web dashboard for map, telemetry, guarded command ownership, Hailo alerts, health state and twin feedback; eventual water-quality heatmap ([Roadmap §6](Roadmap#6-phases-b--e-sketches-not-yet-scoped) Phase C); residual-based anomaly detection / time-series forecasting / physics-informed ML ([Roadmap §6](Roadmap#6-phases-b--e-sketches-not-yet-scoped) Phase E, time-permitting). |

This mapping is **structural inspiration**, not standards compliance. None of the manufacturing-specific protocols listed in ISO 23247 (MTConnect, OPC/UA, QIF, AP242) appear in this project; ROS 2 + DDS + MAVLink replace them at the equivalent layers.

### 3.1 Implemented feedback loop and evidence boundary

```text
Dashboard -> Pi command bridge -> guarded RC override --+
                                                        |
Herelink ---------------------> direct FCU RC input -----+-> real FCU
                                                             |
                                                             v
                                                   measured /mavros/rc/out
                                                             |
                                                             v
                                                       VRX thrust/pose
                                                             |
                                                             v
                                                    dashboard twin telemetry
```

In Herelink ownership the bridge releases its MAVROS RC overrides rather than
forwarding the pilot input. It continues to supervise measured output and can
reassert the neutral E-stop override.

The 03/09/2026 T3a showcase closed this loop while also carrying live Hailo
images and an advisory person alert. The 04/09/2026 focused run correlated a
held dashboard mouse command with real FCU output, VRX response and neutral
return; Hailo was deliberately disabled in that later run. These results prove
the bounded command/feedback implementation, not ISO conformance, autonomous
water-quality prediction or complete routine deployment acceptance.

---

## 4. Caveats and non-claims

To avoid overclaiming in downstream artifacts:

- **Domain gap.** ISO 23247's scope is explicitly manufacturing. Mapping it to environmental monitoring is an analogy; it is not "ISO 23247 compliance" or "ISO 23247 implementation."
- **Figure reuse.** The third-party AP238 / STEP Tools explainer at <https://www.ap238.org/iso23247/> asserts its architecture figures are "taken from an early version before it was copyrighted." That is the page maintainer's assertion, not a copyright license. Any architecture diagram in formal artifacts (thesis, conference papers, posters) should be **redrawn** by us, with the ISO standard cited in the caption — do not copy the AP238 / STEP Tools images.
- **Single-standard citation is fragile.** For an environmental DT, citing only ISO 23247 invites the reviewer question "why not ISO/IEC 30141?" The stronger citation pair is **30141:2024 + 23247:2021** — 30141 for the domain-neutral architecture, 23247 as a worked instantiation in a different domain to demonstrate the pattern's concrete realization.
- **Reference architectures are not requirements.** Citing 30141 / 23247 does not impose conformance obligations on this project. The standards are referenced as architectural inspiration; the project does not claim to satisfy any normative clauses of either standard.

---

## 5. What to cite where

- **Repo internal docs** (this page, Roadmap, System Overview): cite by ISO number + edition + title.
- **Formal external artifacts** (thesis literature review, IEEE conference / journal submissions): cite the **official ISO catalogue entries** for the exact versions (`ISO/IEC 30141:2024`, `ISO 23247-1:2021` through `ISO 23247-4:2021`), not third-party explainer pages. The AP238 / STEP Tools page is **not** an authoritative citation; it is useful only as a free informal explainer for readers without ISO catalogue access.
- **Architectural diagrams in formal artifacts**: redraw based on the layered structure; do not reproduce ISO or AP238 figures.

---

## 6. Sources

Authoritative:

- ISO/IEC 30141:2024 — Internet of Things (IoT) — Reference architecture: <https://www.iso.org/standard/88800.html>
- ISO 23247 series catalogue (ISO/TC 184/SC 4): <https://www.iso.org/committee/54158/x/catalogue/p.1>
- ISO 23247-1:2021 — Overview and general principles: <https://www.iso.org/standard/75066.html>
- ISO 23247-2:2021 — Reference architecture: <https://www.iso.org/standard/78743.html>
- ISO 23247-3:2021 — Digital representation of manufacturing elements: <https://www.iso.org/standard/78744.html>
- ISO 23247-4:2021 — Information exchange: <https://www.iso.org/standard/78745.html>
- ISO 23247-5 (under publication): <https://www.iso.org/standard/87425.html>
- ISO/FDIS 23247-6 — Digital twin composition: <https://www.iso.org/standard/87426.html>

Background / explanatory (third-party, informal):

- AP238 / STEP Tools informal explainer of ISO 23247: <https://www.ap238.org/iso23247/>
- NIST — An Analysis of the New ISO 23247 Series of Standards on Digital Twin Framework for Manufacturing: <https://www.nist.gov/publications/analysis-new-iso-23247-series-standards-digital-twin-framework-manufacturing>
