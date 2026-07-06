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

- [x] **Step 1** — Reach Pi via SSH or RDP. Confirm clock + ROS env: `timedatectl status` synchronized, `source /opt/ros/jazzy/setup.bash`, `echo $ROS_DISTRO` is `jazzy` or `which ros2` points to `/opt/ros/jazzy/bin/ros2`.
- [x] **Step 2** — Clear any leftover MAVROS process from Friday's no-endpoint test: prefer Ctrl+C in the launch terminal if still open; otherwise `pkill -f 'ros2 launch mavros|mavros_node|mavros_router'` and confirm `ps -ef | grep mavros | grep -v grep` is empty.
- [x] **Step 3** — Autopilot physical endpoint check:

  ```bash
  lsusb
  ls -l /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB* /dev/serial0 2>/dev/null
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial'
  ```

  Prefer `/dev/serial/by-id/...` over `/dev/ttyACM0` / `/dev/ttyUSB0` if available. HDMI cabling does not count as a MAVLink endpoint.
- [x] **Step 4** — Firmware / launch-profile decision. N/A today: no serial / UDP MAVLink endpoint exists to classify, so no PX4 / ArduPilot / generic launch profile can be selected. Friday's `px4.launch` remains only a guess.
- [x] **Step 5** — Decision: live Block B+C if endpoint exists; paper pivot if no serial / UDP MAVLink endpoint is available.

Paper branch (autopilot unavailable): record blocked state; pivot to slab 3 or slab 4. Capture slab choice rationale in Block A Outcome.

**Outcome:** Paper pivot. Pi access and environment are green: Remmina session is active on `imtaquadrone-desktop`; local time is Tue 26/05/2026 10:30 CEST; `timedatectl` reports `System clock synchronized: yes`, NTP active, `Europe/Paris`; ROS env is `jazzy` with `ros2` at `/opt/ros/jazzy/bin/ros2`. No stale MAVROS process is running (`pgrep -af 'mavros|ros2 launch mavros'` returned no matches). Autopilot endpoint remains absent after the basic and widened checks: `lsusb` / `lsusb -t` show only Linux root hubs, SiGma keyboard, Intel RealSense D435i, and Logitech mouse; no CubePilot / Pixhawk / USB-UART device appears. `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial0`, and `/dev/serial1` produced no entries; the only listed serial node was `/dev/ttyAMA10` (`serial10` / `uart10`, PL011), with no evidence that it is wired to the autopilot. Filtered `dmesg` shows USB enumeration for keyboard / mouse / RealSense only, no CDC ACM, CP210x, CH34x, FTDI, CubePilot, Pixhawk, PX4, ArduPilot, or MAVLink-class device. Firmware config has `enable_uart=1`, but there is no usable `/dev/serial0` alias in the device-node check. UDP check also shows no listener on common MAVLink ports (`14550`, `14551`, `14540`, `5760`); `wlan0` is up at `10.120.2.162/23`, `eth0` has no carrier. HDMI cross-check: both Pi HDMI outputs are connected and enabled; `HDMI-1` identifies as `PHL 242B1` / `UHB2315038187` (Philips monitor), while `HDMI-2` identifies as `LONTIUM` (HDMI bridge / sink). This explains the visible HDMI cabling but does not provide telemetry: HDMI is display/video only and still creates no MAVLink serial / UDP endpoint for MAVROS. Decision: do not run live Block B+C today until a real MAVLink serial / UDP endpoint appears. Proceed only after choosing paper slab 3 (`systemd` autostart strategy) or slab 4 (hardware power/layout sketch).

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

**Outcome:** Paper branch selected: slab 4 hardware power/layout sketch. Scope guard: this sketch reflects the current observed Pi 5 status only — Ubuntu Desktop full-DE image, GNOME Remote Desktop / Remmina use, RealSense D435i attached over USB, both HDMI outputs active, and no visible CubePilot / Pixhawk / USB-UART / UDP MAVLink endpoint today. It is not a final electrical design, supplier choice, or buy list.

Current-status layout sketch:

- Keep the Pi 5 on a dedicated regulated 5 V rail sized at ≥5 A before any RealSense + GUI + remote-viewer load test. The 13/05/2026 brownout class was a 5 V sag under RealSense streaming load, so the sketch treats shared / weak 5 V GPIO-pin power as the risk to avoid.
- Prefer proper USB-C power into the Pi 5, or if a GPIO 5 V feed is unavoidable later, use short, thick conductors and place bulk capacitance near the Pi power input. The sketch does not choose component values today; it records placement and topology only.
- Put the RealSense behind a powered USB hub when testing camera + desktop + Remmina together, so camera current spikes do not ride on the Pi 5's own 5 V margin. This is especially relevant now that the Pi image is full desktop rather than the old headless posture.
- Keep telemetry/data cabling separate from display cabling in the physical layout notes: HDMI-1 / HDMI-2 are display sinks only; MAVLink still needs USB serial, TELEM UART / USB-UART, or UDP.
- Add acceptance checks for the eventual hardware pass: no Pi under-voltage / throttling flags during RealSense streaming and Remmina use, RealSense remains enumerated, and the future MAVLink endpoint remains visible while the camera and desktop load are active.

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

**Outcome:** Paper cross-check complete for slab 4. The hardware sketch is compatible with the Thu 21/05 §D.2 topic-name scheme because it does not change the software boundary: future MAVROS sensor topics still remap toward neutral `/sensors/*`, RealSense remains the camera source behind `/sensors/camera/image_raw`, and any future thrust translation still belongs to Layer B rather than the power/layout sketch. No `fcu_url` can be selected today because no USB serial, GPIO UART, or UDP MAVLink endpoint is visible.

Power/layout cross-reference result: the sketch addresses the current full-DE Pi 5 load case better than the old headless assumption. It explicitly includes Pi 5 power, RealSense D435i USB load, GNOME desktop, Remmina remote-control session, both HDMI sinks, and the future requirement that a MAVLink endpoint must stay visible while those loads are active. The acceptance checks should therefore be run together, not one at a time: RealSense streaming + Remmina connected + HDMI active + future MAVLink endpoint present, with no under-voltage / throttling flags and no device dropouts. No code, launch YAML, or component selection follows from this block.

## Block D — Debrief + action-item extraction (≈ 20 min)

- [x] Capture lessons learned — endpoint, firmware/profile, plugin-load gotchas, working config strings (live); or slab insights / open design questions (paper).
- [x] List follow-ups — missing hardware, missing cable / endpoint, baud / firmware uncertainty, specific `mavros` plugins, power-design tasks, or autostart tasks.
- [x] Doc-edit decision — default defer. A confirmed `connected: true` heartbeat is a sharp enough outcome to update `Board.md` / `wiki/Roadmap.md`; a no-endpoint result should only update docs if it adds genuinely new evidence beyond Fri 22/05.

**Outcome:** Debrief complete. Lessons learned: Pi access and ROS environment are healthy through Remmina; MAVROS should not be relaunched without a real endpoint; the widened audit is the right pre-launch gate because it checks USB device enumeration, serial nodes, GPIO UART aliases, kernel logs, and common UDP MAVLink ports. Today's only serial node (`/dev/ttyAMA10`) is not evidence of CubePilot wiring by itself. HDMI evidence is useful for physical-cabling interpretation only: `HDMI-1` is the Philips monitor and `HDMI-2` is a `LONTIUM` HDMI bridge / sink, but neither is telemetry.

Follow-ups:

- Physical endpoint test: connect a known data-capable CubePilot / Pixhawk USB cable or a TELEM UART / USB-UART path to the Pi, then rerun `lsusb`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial/by-id/*`, and `dmesg` before any MAVROS launch.
- UDP endpoint test: only use `udp://:14550@` or related URLs after a real sender / listener is confirmed on the Pi network.
- Firmware/profile selection remains blocked: no PX4 / ArduPilot / generic MAVROS launch profile can be selected until a real endpoint identifies the low-level controller path.
- Slab 4 follow-up: the eventual power/layout validation should combine RealSense streaming, Remmina, active HDMI sinks, and the future MAVLink endpoint in one load test; passing each piece separately is not enough.
- Slab 3 remains deferred: Pi-side `systemd` autostart becomes useful after the heartbeat path is known, because the unit needs a real `fcu_url`.

Doc-edit decision: defer broader docs for now. `Board.md`, `wiki/Roadmap.md`, and `wiki/Pi5_Bringup_Smoke_Test.md` already carry the milestone-level state: MAVROS install / launch side green, physical MAVLink endpoint missing, and HDMI not a telemetry path. Today's expanded audit and current-status hardware sketch belong in this diary unless a future test changes the integration state.

## Block E — Day wrap (≈ 10 min)

- [x] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [x] Fill Block E Outcome BEFORE the wrap commit.
- [x] Set Wed 27/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (user-run).

**Outcome:** Day wrap ready. Tue outcome: live heartbeat path blocked because no CubePilot / Pixhawk / USB-UART / GPIO UART / UDP MAVLink endpoint is visible to the Pi 5; expanded endpoint audit and HDMI sink check are captured in Block A. Paper fallback executed through slab 4: current-status-only hardware power/layout sketch plus Block C cross-check against the Layer A/B topic plan. Broader doc edits deferred because the milestone state did not change: MAVROS install side remains green, physical MAVLink endpoint remains the gate. Pre-wrap checks clean: `git diff --check` clean; placeholder / conflict-marker scan clean after this outcome fill. Proposed wrap commit subject: `docs(diary): wrap 26/05 Pi 5 no-endpoint audit + Slab 4`. Commit / push pending user-run.

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Wed 27/05/2026 startup hint: resume from the physical-link gate.

- If a CubePilot / Pixhawk data cable, TELEM UART / USB-UART, or UDP MAVLink endpoint becomes available: rerun the expanded endpoint audit first, then launch MAVROS only against the confirmed path and verify `/mavros/state connected: true`.
- If no endpoint is available: continue paper work with slab 3 (Pi-side `systemd` autostart strategy) or refine slab 4 into an evidence checklist for the eventual combined-load test.
- D2 hardware-design pass remains current-status only until real power topology and component constraints are known; no shopping-list draft without hardware constraints.
- Next supervisor meeting: Wed 03/06/2026 10h-12h.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
