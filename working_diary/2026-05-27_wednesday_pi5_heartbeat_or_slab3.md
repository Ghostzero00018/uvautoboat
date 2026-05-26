# 2026-05-27 — Wednesday: Pi 5 MAVLink heartbeat or Slab 3 paper

## Day overview

Continuing from Tue 26/05/2026 ([`2026-05-26`](2026-05-26_tuesday_pi5_block_c_heartbeat_or_paper.md)).

Pi 5 install side remains green: Ubuntu Desktop 24.04.4 LTS on `imtaquadrone-desktop`, ROS 2 Jazzy base, `ros-jazzy-mavros` 2.14.0 + extras, GeographicLib datasets, `dialout` group, GNOME Remote Desktop / Remmina at `10.120.2.162:3389`. Physical MAVLink endpoint (CubePilot / Pixhawk USB serial, TELEM UART / USB-UART, or confirmed UDP sender) remains the live-path gate — no such endpoint was visible on 26/05. Slab 4 (hardware power/layout sketch) was completed on 26/05; slab 3 (Pi-side `systemd` autostart strategy) is the next paper deliverable.

- **If a MAVLink endpoint is now physically connected to the Pi 5:** live heartbeat path. Rerun the expanded endpoint audit, identify the device and firmware family, launch MAVROS with the correct profile, and capture `/mavros/state connected: true` plus a first telemetry sample.
- **If no endpoint is visible:** paper continuation. Draft slab 3 — Pi-side `systemd` unit structure for MAVROS autostart — leaving `fcu_url` as a placeholder pending a real endpoint.

Final commitment is a Block A decision based on actual endpoint availability when the day starts.

## Boundaries

- **In scope:** live heartbeat + first telemetry sample if endpoint exists; otherwise slab 3 paper deliverable, plus debrief and action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, premature `Board.md` / `wiki/Roadmap.md` edits (defer to Block D unless `connected: true` lands).
- **Pi 5 baseline:** `imt-aqua-drone@imtaquadrone-desktop`, `10.120.2.162/23` on `wlan0`, Ubuntu Desktop 24.04 full-DE, ROS 2 Jazzy + MAVROS Route 1 stack installed, `dialout` membership active.
- **Workstation → Pi access:** SSH `imt-aqua-drone@10.120.2.162` and/or GNOME Remote Desktop via Remmina to `10.120.2.162:3389` using the Pi Settings–generated credentials. Do not write the generated password into the repo.
- **Slab 3 context:** Pi-side `systemd` unit for MAVROS autostart — deferred from Thu 21/05 and Tue 26/05. Draft the unit structure now; leave `fcu_url` as a placeholder because no endpoint has been confirmed yet.
- **Slab 4 status:** current-status hardware power/layout sketch completed 26/05. Combined-load acceptance checklist (RealSense + Remmina + HDMI + MAVLink endpoint together) is a deferred follow-up, not today's scope unless slab 3 is very short.
- **Validation methodology Three Ask:** still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight + endpoint audit (≈ 15 min; ≈ 5 min if no change)

- [ ] **Step 1** — Reach Pi via SSH or RDP. Confirm clock + ROS env: `timedatectl status` synchronized, `source /opt/ros/jazzy/setup.bash`, `echo $ROS_DISTRO` is `jazzy` or `which ros2` points to `/opt/ros/jazzy/bin/ros2`.
- [ ] **Step 2** — Confirm no stale MAVROS process: `pgrep -af 'mavros|ros2 launch mavros'` should return empty.
- [ ] **Step 3** — Expanded endpoint audit (established gate from 26/05):

  ```bash
  lsusb && lsusb -t
  ls -l /dev/serial/by-id/* /dev/serial/by-path/* /dev/ttyACM* /dev/ttyUSB* /dev/ttyAMA* /dev/ttyS* /dev/serial0 /dev/serial1 2>/dev/null || true
  ls /dev/ | grep -E 'serial|ttyAMA|ttyS' || true
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial|cubepilot|pixhawk|px4|ardupilot|mavlink|cdc' || true
  ss -ulnp | grep -E '14550|14551|14540|5760' || true
  ```

  A usable MAVLink endpoint is one of: `/dev/serial/by-id/...`, `/dev/ttyACM*`, `/dev/ttyUSB*`, a TELEM-wired UART node, or a confirmed UDP listener. `/dev/ttyAMA10` alone is not sufficient without wiring confirmation.

- [ ] **Step 4** — Firmware / launch-profile decision (only if endpoint found): identify PX4 / ArduPilot / generic from autopilot label, supervisor confirmation, or `mavproxy.py` heartbeat dump if installed.
- [ ] **Step 5** — Decision: live Block B+C if endpoint confirmed; paper pivot (slab 3) if still absent.

Paper branch (no endpoint): record outcome; proceed to slab 3. Capture the choice rationale in Block A Outcome.

**Outcome:** [To fill — live (endpoint path, firmware/profile, go/no-go for Block B+C) OR paper (slab 3 selected).]

## Block B — Heartbeat smoke-test (live, ≈ 30-45 min) OR Slab 3 paper (≈ 60-90 min)

Live branch:

- [ ] Launch MAVROS with the confirmed endpoint and firmware profile:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros <px4|apm|node>.launch fcu_url:=serial:///dev/serial/by-id/<device>:115200
  # or: serial:///dev/ttyACM0:115200, serial:///dev/ttyUSB0:115200
  # if UDP confirmed: udp://:14550@
  ```

- [ ] If no heartbeat on first try: attempt only evidence-based variants — alternate baud (`57600` vs `115200`), alternate endpoint or profile if firmware was uncertain. Do not iterate blindly.
- [ ] Capture launch stdout / stderr verbatim; flag missing deps, plugin-load errors, serial open errors, or connection failures.
- [ ] Heartbeat verification:

  ```bash
  ros2 topic echo --once /mavros/state
  ```

  Expected pass: `connected: true`. Capture one full `/mavros/state` message as evidence.

Paper branch (slab 3): draft the Pi-side `systemd` unit structure for MAVROS autostart:

- `[Unit]` section: `Description=MAVROS bridge`, `After=network-online.target`, `Wants=network-online.target`.
- `[Service]` section: `User=imt-aqua-drone`, `WorkingDirectory=/home/imt-aqua-drone`, `SupplementaryGroups=dialout`, `Type=simple`, `Restart=on-failure`, `RestartSec=5s`, `ExecStart=/bin/bash -c 'source /opt/ros/jazzy/setup.bash && ros2 launch mavros <profile>.launch fcu_url:=<placeholder>'` (note: `source` is shell-specific — use the `/bin/bash -c '...'` wrapper rather than a bare `EnvironmentFile`), `StandardOutput=journal`, `StandardError=journal`.
- `[Install]` section: `WantedBy=multi-user.target`.
- Enable / status / log commands: `sudo systemctl enable <unit>`, `sudo systemctl start <unit>`, `systemctl status <unit>`, `journalctl -u <unit> -f`.
- Leave `fcu_url` as `<placeholder>` — cannot be set until a real endpoint is confirmed in a future Block A.
- Flag any ordering gap: if the autopilot USB device is slow to enumerate, `network-online.target` alone may not be sufficient; note whether a `udev` rule or `After=dev-ttyACM0.device` dependency would be needed.

**Outcome:** [To fill — live (`connected: true` y/n, working FCU URL captured, dominant error class if no) OR paper (slab 3 unit draft summary + open ordering questions).]

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

Paper branch: cross-reference slab 3 unit draft against Thu 21/05 §D.2 topic-name scheme. Does the `ExecStart` command launch the bridge with the right launch-time remaps onto `/sensors/*`? Does the unit ordering hold under a cold boot where the network comes up before the autopilot endpoint is enumerated? Does the slab 3 unit design account for the full-DE Pi 5 load (GNOME desktop + Remmina + RealSense) identified in the slab 4 sketch?

**Outcome:** [To fill — live (IMU + GPS sample captured y/n, cross-machine discovery y/n) OR paper (cross-ref outcome).]

## Block D — Debrief + action-item extraction (≈ 20 min)

- [ ] Capture lessons learned — endpoint, firmware/profile, plugin-load gotchas, working config strings (live); or slab 3 design open questions / deferred decisions (paper).
- [ ] List follow-ups — missing hardware, missing cable / endpoint, baud / firmware uncertainty, specific `mavros` plugins, power-design tasks, autostart tasks.
- [ ] Doc-edit decision — default defer. A confirmed `connected: true` heartbeat warrants targeted `Board.md` / `wiki/Roadmap.md` updates; a continued no-endpoint result should only update docs if new evidence is added beyond 26/05.

**Outcome:** [To fill — action item bullet list + doc-edit decision (touch / defer).]

## Block E — Day wrap (≈ 10 min)

- [ ] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [ ] Fill Block E Outcome BEFORE the wrap commit.
- [ ] Run the standard pre-commit sweep before the wrap commit.
- [ ] Set Thu 28/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (user-run).

**Outcome:** [To fill at end of day — diary closed; commit subject + landed-state note.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Thu 28/05/2026 startup hint: depends on Wed outcome.

- If live green (`connected: true` + IMU/GPS samples captured): Phase 5 next sub-block — telemetry-topic shape audit live on Pi against Thu 21/05 §D.2 mapping; `launch/remap.launch.yaml` Layer A/B integration scoping; autoboat-stack rewiring plan to consume `/mavros/*` through launch-time remaps onto `/sensors/*`.
- If live partial (heartbeat OK, selected telemetry topics not flowing): root-cause write-up; plugin-list trim or `<apm|px4>_pluginlists.yaml` investigation; iterate.
- If still blocked at endpoint: enable slab 3 unit draft once endpoint appears; refine slab 4 into a combined-load acceptance checklist.
- Next supervisor meeting: Wed 03/06/2026 10h-12h.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
