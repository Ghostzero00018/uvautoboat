# 2026-05-21 — Thursday: Pi 5 MAVLink Bridge Deploy + Smoke-Test

## Day overview

Phase 5 driver bring-up day. Possible main work: deploy a MAVLink-to-ROS 2 bridge on the Pi 5 and verify the deployment can expose autopilot / boat telemetry as ROS 2 topics. This is a revision from the 20/05/2026 wrap hint ("paper-only") — promoting to a live install + smoke-test attempt on the Pi 5.

Route options:

- **Preferred:** `ros-jazzy-mavros` via apt — the ROS 2 build of `mavros` (sometimes referred to as `mavros2`); project-reinforced bridge route per the 20/05/2026 supervisor session.
- **Fallback:** `mavros` built from source against Jazzy — if the apt path is missing or stale.
- **Last resort:** `MAVProxy` + a thin custom / `pymavlink` ROS 2 publisher — `MAVProxy` alone is a router / multiplexer, NOT a bridge; it only enters the ROS ingestion path if paired with a publisher. Today this route is limited to proof-of-life only, not repo integration.

Final route lock-in is a Block A decision based on what is actually available on the Pi 5 / in the Jazzy apt repos.

Naming reminder for the diary: legacy `mavros` was ROS 1 only; the ROS 2 port is the same project (`mavros` repo, ROS 2 branch / release), sometimes called `mavros2` colloquially. The expected apt package name for ROS 2 Jazzy is `ros-jazzy-mavros`; Block A verifies whether it is actually available on the Pi 5.

## Boundaries

- **In scope:** Pi 5 install + configure + smoke-test of a single bridge instance, plus debrief + action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, premature `Board.md` / `wiki/Roadmap.md` edits (defer to Block D). If the `MAVProxy` + `pymavlink` route is selected, any custom publisher stays scratch / throwaway for smoke-test evidence only.
- **Hardware-design pass** (regulated 5A 5V supply, bulk capacitance, USB hub for RealSense) — separate Phase 5 sub-task (D2 from 20/05/2026). Today does NOT depend on it as long as a MAVLink source is reachable (autopilot via UART/USB, or SITL via UDP from another host).
- **Pi 5 stays headless** (Ubuntu Server, per 13/05/2026 supervisor directive). All work over SSH; no GUI install.
- **Validation methodology** Three Ask: still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight + route lock-in (≈ 30 min)

Pre-flight checks:

- [ ] Pi 5 reachable over SSH — record IP / hostname used.
- [ ] ROS 2 Jazzy install on the Pi 5 sourceable; `ros2 doctor` reasonably clean.
- [ ] MAVLink source identified — (a) autopilot connected via UART / USB on the Pi 5, or (b) SITL on another host reachable over the network. Capture endpoint string.
- [ ] If serial route: user in `dialout` group (`groups` includes it); device node visible (`ls /dev/serial/by-id/`, or `ls /dev/ttyUSB*` / `ls /dev/ttyACM*`).
- [ ] Internet on the Pi 5 for apt / pip.

Route lock-in (pick ONE before Block B):

1. `ros-jazzy-mavros` via apt — first preference if the package is available in the Ubuntu 24.04 Jazzy repos.
2. `mavros` built from source against Jazzy — fallback.
3. `MAVProxy` + custom publisher — last resort.

**Outcome:** [To fill — chosen route + endpoint + go / no-go for Block B.]

## Block B — Install + configure (≈ 60-90 min)

For the chosen route:

- [ ] Install packages (apt / source / pip) — record exact commands and versions.
- [ ] Configure FCU connection string (`serial:///dev/...:baud`, `udp://:14550@`, etc.) — record exact URL.
- [ ] First launch attempt — capture stdout / stderr verbatim; flag missing deps or plugin-load errors.
- [ ] Iterate on config until the bridge node starts cleanly (no immediate exits, no flood of plugin-load failures).

**Outcome:** [To fill — launch succeeded yes / no; dominant error class if no.]

## Block C — Smoke-test (≈ 30 min)

Once a bridge instance is running:

- [ ] `ros2 topic list` — confirm `/mavros/*` (or equivalent) topics appear.
- [ ] `ros2 topic echo /mavros/state` (or the closest equivalent on the chosen route) — confirm heartbeat data flows.
- [ ] Capture one full sample message dump for at least one topic as evidence (paste into Block C Outcome).
- [ ] Optional second-pass: passive read of `/mavros/global_position/raw/fix` or `/mavros/imu/data` (or analogues) to confirm a real telemetry path, not just heartbeat.

**Outcome:** [To fill — topics-visible yes / no, heartbeat-flowing yes / no, sample dump captured yes / no.]

## Block D — Debrief + action-item extraction (≈ 20 min)

- [ ] Capture lessons learned — route choice rationale, install gotchas, working config strings.
- [ ] List follow-ups — missing hardware (USB hub, regulated supply, etc.), missing software (specific `mavros` plugins, dependencies), missing config (UART permissions, baud rates).
- [ ] Doc-edit decision — by default DO NOT touch `Board.md` / `wiki/Roadmap.md` today; flag for a targeted edit only if a sharp directional outcome lands (route locked + smoke-test green, or route categorically blocked).

**Outcome:** [To fill — action item bullet list + doc-edit decision (touch / defer).]

## Block E — Day wrap (≈ 10 min)

- [ ] Final checks: `git status`, `git diff --check`, `rg -n '\[To fill'` over this diary.
- [ ] Fill Block E Outcome BEFORE the wrap commit (19/05/2026 lesson learned: a placeholder slipped into `faa9ba1` and needed a follow-up `3cd8861` correction).
- [ ] Run the standard pre-commit sweep before the wrap commit.
- [ ] Set Fri 22/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (commit subject provided in the wrap; run from repo root after Block E Outcome is filled).

**Outcome:** [To fill at end of day — diary closed; commit subject + landed-state note.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Fri 22/05/2026 startup hint: TBD — depends on today's outcome.

- If bridge deployed + smoke-test green → Phase 5 next sub-block (telemetry-topic shape audit, or controller-side integration scoping).
- If bridge blocked → root-cause writeup + alternate route plan (Phase 5 paper-only fallback day).
- Either way: revisit the hardware-design pass scope (D2 from 20/05/2026) at week's end.
