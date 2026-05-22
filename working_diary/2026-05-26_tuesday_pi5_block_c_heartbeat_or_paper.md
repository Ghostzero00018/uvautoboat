# 2026-05-26 — Tuesday: Pi 5 Block C heartbeat single-shot or paper fallback

## Day overview

Autopilot-availability-conditional day continuing from Fri 22/05/2026 ([`2026-05-22`](2026-05-22_friday_pi5_mavlink_bringup_or_paper.md)).

Pi 5 install side is green: Ubuntu Desktop 24.04.4 LTS Noble on `linux-raspi` 6.8.0-1056 aarch64, ROS 2 Jazzy base, `ros-jazzy-mavros` 2.14.0 + extras + msgs, GeographicLib default datasets, `dialout`, `openssh-server`, and GNOME Remote Desktop over RDP / Remmina. Friday's late MAVROS launch check proved the `/mavros/*` plugin topic surface appears, but `/mavros/state` stayed `connected: false` because no autopilot serial endpoint was visible (`/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial/by-id/*` absent; `lsusb` showed keyboard, mouse, RealSense only).

- **If autopilot / boat is physically connected to the Pi 5:** live heartbeat path. Identify the real endpoint and firmware family, launch MAVROS with the correct profile, and capture `/mavros/state connected: true` plus at least one telemetry sample.
- **If autopilot is still unavailable:** paper continuation. Pick slab 3 (Pi-side `systemd` autostart strategy for the bridge, deferred from Thu 21/05) or slab 4 (hardware-design pass layout sketch, deferred from 20/05 + Thu 21/05; more load-relevant under the full-DE image).

Final commitment is a Block A decision based on actual autopilot availability when the day starts.

## Boundaries

- **In scope:** live Block C heartbeat + telemetry verification if autopilot is present; otherwise slab 3 / 4 paper deliverable, plus debrief and action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, and premature `Board.md` / `wiki/Roadmap.md` edits. Block D decides whether evidence is strong enough for targeted doc updates.
- **Pi 5 baseline:** `imt-aqua-drone@imtaquadrone-desktop`, `10.120.2.162/23` on `wlan0`, ROS 2 Jazzy + MAVROS Route 1 stack installed.
- **Workstation -> Pi access:** SSH `imt-aqua-drone@10.120.2.162` and/or GNOME Remote Desktop via Remmina to `10.120.2.162:3389` using the GNOME Remote Desktop generated credentials from the Pi Settings pane. Do not write the generated password into the repo.
- **Validation methodology Three Ask:** still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight + autopilot check (≈ 15 min live; ≈ 5 min if unavailable)

- [ ] **Step 1** — Reach Pi via SSH or RDP. Confirm clock + ROS env: `timedatectl status` synchronized, `source /opt/ros/jazzy/setup.bash`, `echo $ROS_DISTRO` is `jazzy` or `which ros2` points to `/opt/ros/jazzy/bin/ros2`.
- [ ] **Step 2** — Clear any leftover MAVROS process from Friday's no-endpoint test: prefer Ctrl+C in the launch terminal if still open; otherwise `pkill -f 'ros2 launch mavros|mavros_node|mavros_router'` and confirm `ps -ef | grep mavros | grep -v grep` is empty.
- [ ] **Step 3** — Autopilot physical endpoint check:

  ```bash
  lsusb
  ls -l /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB* /dev/serial0 2>/dev/null
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial'
  ```

  Prefer `/dev/serial/by-id/...` over `/dev/ttyACM0` / `/dev/ttyUSB0` if available. HDMI cabling does not count as a MAVLink endpoint.
- [ ] **Step 4** — Firmware / launch-profile decision. Use autopilot label, supervisor confirmation, or a heartbeat dump if `mavproxy.py` is installed. PX4 -> `px4.launch`; ArduPilot -> `apm.launch`; unknown / generic -> `node.launch` until identified. Friday's `px4.launch` was only a guess.
- [ ] **Step 5** — Decision: live Block B+C if endpoint exists; paper pivot if no serial / UDP MAVLink endpoint is available.

Paper branch (autopilot unavailable): record blocked state; pivot to slab 3 or slab 4. Capture slab choice rationale in Block A Outcome.

**Outcome:** [To fill — live (endpoint + firmware/profile + go/no-go for Block B+C) OR paper (slab choice + planned deliverable shape).]

## Block B — Heartbeat smoke-test (live, ≈ 30-45 min) OR Slab 3 / 4 paper (≈ 60-90 min)

Live branch:

- [ ] Launch MAVROS with the correct launch file and real endpoint, e.g.:

  ```bash
  ros2 launch mavros <px4|apm|node>.launch fcu_url:=serial:///dev/serial/by-id/<device>:115200
  # or serial:///dev/ttyACM0:115200, serial:///dev/ttyUSB0:115200, serial:///dev/serial0:115200
  # if UDP MAVLink is confirmed: udp://:14550@
  ```

- [ ] If no heartbeat, try only evidence-based variants: alternate baud (`57600` vs `115200`), alternate endpoint found in Block A, or alternate launch profile if firmware ID was uncertain.
- [ ] Capture launch stdout / stderr verbatim; flag missing deps, plugin-load errors, serial open errors, or connection failures.
- [ ] Heartbeat verification:

  ```bash
  ros2 topic echo --once /mavros/state
  ```

  Expected pass: `connected: true`. Capture one full `/mavros/state` message as evidence.

Paper branch (slab 3): draft the Pi-side `systemd` unit shape for the bridge: `[Unit]` deps (`network-online.target`), `[Service]` restart policy (`Restart=on-failure`, `RestartSec=5s`), `ExecStart` sourcing `/opt/ros/jazzy/setup.bash` then `ros2 launch ...`, journal logging, and log review commands.

Paper branch (slab 4): hardware-design layout sketch: regulated >=5A 5V supply, bulk capacitance near Pi power input, thick-short GPIO leads or proper USB-C input, powered USB hub between Pi and RealSense for current-spike decoupling. Sketch only — no buy decisions.

**Outcome:** [To fill — live (`connected: true` y/n, working FCU URL captured, dominant error class if no) OR paper (slab deliverable summary).]

## Block C — Telemetry beyond heartbeat (live, ≈ 30 min) OR Paper continuation (≈ 20-30 min)

Live branch:

- [ ] IMU sample:

  ```bash
  ros2 topic echo --once /mavros/imu/data
  ```

- [ ] GPS sample if available:

  ```bash
  ros2 topic echo --once /mavros/global_position/global
  ros2 topic echo --once /mavros/global_position/raw/fix
  ```

  If no GPS lock, record status / zeroed fields honestly rather than treating it as a MAVROS failure.
- [ ] Optional battery and RC:

  ```bash
  ros2 topic echo --once /mavros/battery
  ros2 topic echo --once /mavros/rc/in
  ```

- [ ] Optional cross-machine DDS sanity from workstation on `IoT IMT Nord Europe`: `ros2 topic list | grep mavros` should enumerate Pi-side `/mavros/*` topics. Baseline DDS discovery worked 12/05/2026.

Paper branch: cross-reference slab 3 / 4 deliverable against Thu 21/05 §D.2 topic-name scheme alignment. Does the autostart unit launch the bridge with the right `fcu_url` and launch-time remaps onto `/sensors/*`? Does the hardware layout address RealSense + GUI + remote-viewer load on the Pi 5 power rail?

**Outcome:** [To fill — live (IMU + GPS sample captured y/n, cross-machine discovery y/n) OR paper (cross-ref outcome).]

## Block D — Debrief + action-item extraction (≈ 20 min)

- [ ] Capture lessons learned — endpoint, firmware/profile, plugin-load gotchas, working config strings (live); or slab insights / open design questions (paper).
- [ ] List follow-ups — missing hardware, missing cable / endpoint, baud / firmware uncertainty, specific `mavros` plugins, power-design tasks, or autostart tasks.
- [ ] Doc-edit decision — default defer. A confirmed `connected: true` heartbeat is a sharp enough outcome to update `Board.md` / `wiki/Roadmap.md`; a no-endpoint result should only update docs if it adds genuinely new evidence beyond Fri 22/05.

**Outcome:** [To fill — action item bullet list + doc-edit decision (touch / defer).]

## Block E — Day wrap (≈ 10 min)

- [ ] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [ ] Fill Block E Outcome BEFORE the wrap commit.
- [ ] Run the standard pre-commit sweep before the wrap commit.
- [ ] Set Wed 27/05/2026 startup hint based on today's outcome.
- [ ] Commit + push.

**Outcome:** [To fill at end of day — diary closed; commit subject + landed-state note.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Wed 27/05/2026 startup hint: depends on Tue outcome.

- If live green (`connected: true` + IMU/GPS samples captured): Phase 5 next sub-block — telemetry-topic shape audit live on Pi against Thu 21/05 §D.2 mapping; `launch/remap.launch.yaml` Layer A/B integration scoping; autoboat-stack rewiring plan to consume `/mavros/*` through launch-time remaps onto `/sensors/*`.
- If live partial (heartbeat OK, selected telemetry topics not flowing): root-cause write-up; plugin-list trim or `<apm|px4>_pluginlists.yaml` investigation; iterate.
- If live blocked at heartbeat: capture serial / launch logs and decide the next physical-layer test (data cable, USB-UART, TELEM wiring, baud, firmware profile, or UDP MAVLink).
- If autopilot still unavailable: continue paper work on slab 3 / slab 4, or pivot to the D2 hardware-design pass shopping-list draft.
- D2 hardware-design pass revisit scheduled week's end — full-DE Pi image makes power margins more load-relevant than the old headless-server posture.
- Next supervisor meeting: Wed 03/06/2026 10h-12h.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
