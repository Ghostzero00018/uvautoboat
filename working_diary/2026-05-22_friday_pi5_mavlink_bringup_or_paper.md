# 2026-05-22 — Friday: Pi 5 Block A (live) or Slab 3 / 4 (paper)

## Day overview

Pi-availability-conditional day continuing from Thu 21/05/2026 ([`2026-05-21`](2026-05-21_thursday_pi5_mavlink_bridge_deploy.md)):

- **If Pi 5 back + reflashed and reachable** (prof finished setup, control box returned): live Block A pre-flight using yesterday's `## Afternoon prep — Fast Block A pre-flight checklist` (4-step gate: OS identification → baseline access + Pi-side state → Route 1 viability → route decision + go / no-go for Block B). Promote to Block B install (Route 1 = apt `ros-jazzy-mavros` default per Thu §D.1) if Block A green.
- **If Pi 5 still at prof's office**: paper-day. Pick up slab 3 (Pi-side `systemd` autostart strategy for the bridge) or slab 4 (hardware-design pass layout sketch — regulated ≥5A 5V supply, bulk caps, USB hub for RealSense decoupling) — both deferred from Thu.

Final commitment is a Block A decision based on actual Pi availability when the day starts.

## Boundaries

- **In scope:** live Block A pre-flight + Block B install (if Pi back) OR slab 3 / 4 paper deliverable (if Pi missing), plus debrief + action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, premature `Board.md` / `wiki/Roadmap.md` edits (defer to Block D).
- **Pi 5 OS posture:** full desktop GUI image (per 21/05/2026 supervisor reversal of the 13/05/2026 "headless permanently" directive). DE / GUI / VNC-server proposals on the Pi are unblocked. Exact OS the prof flashed (Ubuntu Desktop / RPi OS Bookworm / Server-plus-DE) unknown until Block A — drives the §D.1 decision tree from Thu (RPi OS Bookworm forces Route 2 source build; Ubuntu variants keep Route 1 viable).
- **13/05 Pi-side state is gone post re-flash** — ROS 2 Jazzy install, SSH keys, dialout config, `/boot/firmware/config.txt` + `logind.conf` edits. Bring-up effectively restarts. Yesterday's prep checklist Step 2 already accounts for this.
- **Validation methodology** Three Ask: still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight (≈ 30 min if live; ≈ 5 min "Pi unavailable" call if not)

Live branch — drive Thu's `## Afternoon prep — Fast Block A pre-flight checklist` 4-step gate:

- [ ] **Step 1** — Identify OS / image the prof flashed (`cat /etc/os-release`, `lsb_release -a`, `dpkg --print-architecture`, `uname -a`). Match against the 4-row branch table.
- [ ] **Step 2** — Baseline access + Pi-side state (SSH from workstation; on Pi: hostname / dialout / UART / device nodes for autopilot link; ROS 2 Jazzy install present?).
- [ ] **Step 3** — Route 1 viability gate (`packages.ros.org` reachable? `apt-cache policy ros-jazzy-mavros` shows candidate? — closes the live-confirmation gap left open at end of Thu).
- [ ] **Step 4** — Route decision per Thu §D.1 decision tree + go / no-go for Block B.

Paper branch (Pi unavailable): record blocked state; pivot to slab 3 or slab 4. Capture the slab choice rationale in Block A Outcome.

**Outcome:** [To fill — live (route decision + endpoint + go / no-go for Block B) OR paper (slab choice + planned deliverable shape).]

## Block B — Install + configure (live, ≈ 60-90 min) OR Slab 3 / 4 paper (≈ 60-90 min)

Live branch — for Route 1 default (apt path):

- [ ] Install packages: `sudo apt update && sudo apt install ros-jazzy-mavros ros-jazzy-mavros-extras ros-jazzy-mavros-msgs` (record exact versions captured by apt).
- [ ] GeographicLib datasets (skip if not using altitude plugins; ~700 MB): `sudo /opt/ros/jazzy/share/mavros/install_geographiclib_datasets.sh`.
- [ ] Configure FCU connection string (`serial:///dev/ttyACM0:115200` if USB-tethered autopilot per Step 2; `serial:///dev/serial0:115200` if GPIO UART; `udp://:14550@` if SITL).
- [ ] First launch attempt — capture stdout / stderr verbatim; flag missing deps or plugin-load errors.
- [ ] Iterate on config until the bridge node starts cleanly (no immediate exits, no flood of plugin-load failures).

Paper branch (slab 3): `systemd` unit shape for the bridge — `[Unit]` deps (`network-online.target`, ROS daemon?), `[Service]` Restart policy (`Restart=on-failure`, `RestartSec=5s`?), ExecStart sourcing `/opt/ros/jazzy/setup.bash` then `ros2 launch ...`, log routing via journalctl, log rotation. Draft the unit file paper-side; no Pi-side install today.

Paper branch (slab 4): hardware-design layout sketch — regulated ≥5A 5V supply options (LM2596 buck vs dedicated 5V module), bulk capacitance near Pi power input (electrolytic + ceramic placement), thick-short GPIO leads vs proper USB-C input, powered USB hub between Pi and RealSense for current-spike decoupling (Anker / Sabrent options). Sketch only — no buy decisions.

**Outcome:** [To fill — live (launch yes / no, dominant error class if no, working config string captured) OR paper (slab deliverable summary).]

## Block C — Smoke-test (live, ≈ 30 min) OR Paper continuation (≈ 20-30 min)

Live branch:

- [ ] `ros2 topic list` — confirm `/mavros/*` topics appear (or `/mavros/state` at minimum if a sub-set is enabled by plugin config).
- [ ] `ros2 topic echo /mavros/state` — confirm heartbeat flows (`mavros_msgs/State`, `connected: true`).
- [ ] Capture one full sample message dump for at least one topic as evidence (paste into Block C Outcome).
- [ ] Optional second-pass: `/mavros/global_position/raw/fix` or `/mavros/imu/data` for telemetry path beyond heartbeat.

Paper branch: cross-reference slab 3 / 4 deliverable against the §D.2 topic-name scheme alignment from Thu 21/05 — does the autostart unit launch the bridge with the right `fcu_url` + launch-time remaps onto `/sensors/*`? Does the hardware layout decouple RealSense current spikes from Pi power as expected?

**Outcome:** [To fill — live (topics-visible yes / no, heartbeat-flowing yes / no, sample dump captured yes / no) OR paper (cross-ref outcome).]

## Block D — Debrief + action-item extraction (≈ 20 min)

- [ ] Capture lessons learned — route choice rationale, install gotchas, working config strings (live); or slab insights / open design questions (paper).
- [ ] List follow-ups — missing hardware (USB hub, regulated supply, etc.), missing software (specific `mavros` plugins, dependencies), missing config (UART permissions, baud rates).
- [ ] Doc-edit decision — by default DO NOT touch `Board.md` / `wiki/Roadmap.md` today; flag for a targeted edit only if a sharp directional outcome lands (live route confirmed end-to-end, or slab deliverable that updates Phase 5 planning state).

**Outcome:** [To fill — action item bullet list + doc-edit decision (touch / defer).]

## Block E — Day wrap (≈ 10 min)

- [ ] Final checks: `git status`, `git diff --check`, `rg -n '\[To fill'` over this diary.
- [ ] Fill Block E Outcome BEFORE the wrap commit (19/05/2026 lesson learned: a placeholder slipped into `faa9ba1` and needed a follow-up `3cd8861` correction).
- [ ] Run the standard pre-commit sweep before the wrap commit.
- [ ] Set Sat 23/05 + Tue 26/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (commit subject in the wrap; run from repo root after Block E Outcome is filled).

**Outcome:** [To fill at end of day — diary closed; commit subject + landed-state note.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Sat 23/05 + Tue 26/05/2026 startup hint: TBD — depends on today's outcome.

- If Block A live + Block B install green + Block C smoke-test green → Phase 5 next sub-block (telemetry-topic shape audit live on Pi; or controller-side integration scoping).
- If Block A live + Block B blocked → root-cause writeup + alternate route plan (Route 2 source build, or Route 3 MAVProxy fallback as smoke-test evidence only).
- If Block A paper (Pi still unavailable) → continue paper deliverable on Sat / Tue 26/05 (slab 3 if today's was slab 4; slab 4 if today's was slab 3; or new paper task).
- Either way: revisit the hardware-design pass scope (D2 from 20/05/2026) at week's end; under a full-DE Pi image, D2 becomes more load-relevant than under the prior headless-Server posture.
- VRX §8.2 weekly cadence next check **Tue 26/05/2026** (Monday intentionally skipped; no action Fri).
