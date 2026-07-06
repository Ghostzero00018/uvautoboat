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

- [x] **Step 1** — Reach Pi via SSH or RDP. Confirm clock + ROS env: `timedatectl status` synchronized, `source /opt/ros/jazzy/setup.bash`, `echo $ROS_DISTRO` is `jazzy` or `which ros2` points to `/opt/ros/jazzy/bin/ros2`.
- [x] **Step 2** — Confirm no stale MAVROS process: `pgrep -af 'mavros|ros2 launch mavros'` should return empty.
- [x] **Step 3** — Expanded endpoint audit (established gate from 26/05):

  ```bash
  lsusb && lsusb -t
  ls -l /dev/serial/by-id/* /dev/serial/by-path/* /dev/ttyACM* /dev/ttyUSB* /dev/ttyAMA* /dev/ttyS* /dev/serial0 /dev/serial1 2>/dev/null || true
  ls /dev/ | grep -E 'serial|ttyAMA|ttyS' || true
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial|cubepilot|pixhawk|px4|ardupilot|mavlink|cdc' || true
  ss -ulnp | grep -E '14550|14551|14540|5760' || true
  ```

  A usable MAVLink endpoint is one of: `/dev/serial/by-id/...`, `/dev/ttyACM*`, `/dev/ttyUSB*`, a TELEM-wired UART node, or a confirmed UDP listener. `/dev/ttyAMA10` alone is not sufficient without wiring confirmation.

- [ ] **Step 4** — Firmware / launch-profile decision (only if endpoint found): identify PX4 / ArduPilot / generic from autopilot label, supervisor confirmation, or `mavproxy.py` heartbeat dump if installed.
- [x] **Step 5** — Decision: live Block B+C if endpoint confirmed; paper pivot (slab 3) if still absent.

Paper branch (no endpoint): record outcome; proceed to slab 3. Capture the choice rationale in Block A Outcome.

**Outcome:** Paper branch selected from Remmina-side evidence on 27/05/2026. Pi host was reachable as `imtaquadrone-desktop`; `timedatectl` showed synchronized clock / active NTP at 11:00 CEST; ROS env was valid with `ROS_DISTRO=jazzy` and `ros2` at `/opt/ros/jazzy/bin/ros2`; `pgrep -af 'mavros|ros2 launch mavros'` returned empty. Expanded endpoint audit still found no usable MAVLink endpoint: USB tree showed only root hubs, keyboard, Intel RealSense D435i (`8086:0b3a`), and Logitech mouse; serial sweep found only `/dev/ttyAMA10` and no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, or `/dev/ttyUSB*`; `dmesg` showed RealSense / WiFi / Bluetooth-related lines only; `ss -ulnp` showed no listener on `14550`, `14551`, `14540`, or `5760`. `/dev/ttyAMA10` remains insufficient without TELEM wiring confirmation. Do not launch MAVROS for heartbeat until a real serial / UART / UDP endpoint is visible.

Additional Pi sensor-side check before Block B: current ROS graph initially showed only `/parameter_events` and `/rosout`, plus `/parasit_marvin`; `ros2 node info /parasit_marvin`, `ros2 param list`, and `ps -ef` identified it as the `ros2cli` daemon rather than a sensor, MAVROS, PX4, ArduPilot, or CubePilot data source. Installed packages included `mavros`, `mavros_extras`, `mavros_msgs`, `realsense2_camera`, `realsense2_camera_msgs`, and `realsense2_description`.

RealSense D435i color/depth path was then verified separately. `ros2 launch realsense2_camera rs_launch.py` started RealSense ROS v4.57.7 / LibRealSense v2.57.7, detected D435i serial `213622070342`, USB type `3.2`, firmware `5.14.0`, and reported `RealSense Node Is Up!`. Published topics included color and depth camera info, raw color image, rectified depth image, metadata, and depth-to-color extrinsics. Evidence samples showed color camera info at `1280x720`, depth camera info at `848x480`, color image rate around 15-18 Hz, and depth image rate around 26-27 Hz. The missing `.realsense-config.json` message only loaded defaults.

RealSense D435i motion/IMU path was split by load. With color/depth still enabled plus `enable_gyro:=true enable_accel:=true unite_imu_method:=2`, the node opened accel at 100 FPS and gyro at 200 FPS, but then reported `HID set_power 1 failed` and `Motion Module failure`; a Pi 5 low-voltage warning appeared during the same test. An IMU-only relaunch with color/depth disabled then succeeded: `/camera/camera/accel/sample`, `/camera/camera/gyro/sample`, and `/camera/camera/imu` appeared, and `ros2 topic echo --once /camera/camera/imu` returned angular velocity plus linear acceleration. Treat color/depth as working, IMU-only as working, and combined color/depth/IMU as still power / USB-stability-sensitive. This does not change the MAVLink decision above.

### Raw Evidence Highlights

- Pi baseline:
  - Host: `imtaquadrone-desktop`.
  - Clock: `Wed 2026-05-27 11:00:05 CEST`, `System clock synchronized: yes`, `NTP service: active`.
  - ROS: `ROS_DISTRO=jazzy`, `which ros2` -> `/opt/ros/jazzy/bin/ros2`.
  - Stale MAVROS check: `pgrep -af 'mavros|ros2 launch mavros'` returned empty.
- Endpoint audit:
  - `lsusb` devices: Linux root hubs, `1c4f:0027 SiGma Micro USB Keyboard`, `8086:0b3a Intel Corp. Intel(R) RealSense(TM) Depth Camera 435i`, `046d:c08b Logitech, Inc. G502 SE HERO Gaming Mouse`.
  - `lsusb -t`: RealSense on USB 3 bus `3-1` at `5000M`; keyboard and mouse only on HID paths.
  - Serial nodes: only `crw-rw---- 1 root dialout 204, 74 ... /dev/ttyAMA10`; no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial0`, or `/dev/serial1`.
  - `/dev` serial-name grep: `ttyAMA10` only.
  - `dmesg` filter: `serial0-0` regulator note, RealSense UVC detection, `uvcvideo`, `brcmfmac`, and Bluetooth RFCOMM TTY initialisation only; no CubePilot / Pixhawk / PX4 / ArduPilot / MAVLink / CDC ACM line.
  - UDP listener check: no `14550`, `14551`, `14540`, or `5760` listener.
- ROS graph / package check:
  - Before launching camera: `ros2 node list` showed `/parasit_marvin`; `ros2 topic list -t` showed only `/parameter_events` and `/rosout`.
  - `/parasit_marvin` details: no data subscribers, only `/parameter_events` publisher, standard parameter service servers, parameters `start_type_description_service` and `use_sim_time`.
  - Owning process: `/usr/bin/python3 -c from ros2cli.daemon.daemonize import main; main() --name ros2-daemon --ros-domain-id 0 --rmw-implementation rmw_fastrtps_cpp`.
  - Relevant installed packages: `mavros`, `mavros_extras`, `mavros_msgs`, `realsense2_camera`, `realsense2_camera_msgs`, `realsense2_description`.
  - Relevant executables: `mavros_node`, `mav`, `install_geographiclib_datasets.sh`, and `realsense2_camera_node`.
- RealSense color/depth:
  - Launch command: `ros2 launch realsense2_camera rs_launch.py`.
  - Driver stack: RealSense ROS v4.57.7, LibRealSense v2.57.7.
  - Device: Intel RealSense D435I, serial `213622070342`, physical port ending in `usb3/3-1/3-1:1.0/video4linux/video0`, USB type `3.2`, firmware `5.14.0`, product ID `0x0B3A`.
  - Default profiles: depth `848x480x30`, color `1280x720x30`, gyro default `200`, accel default `100`.
  - Key success line: `RealSense Node Is Up!`.
  - Topic check: `/camera/camera/color/camera_info`, `/camera/camera/color/image_raw`, `/camera/camera/color/metadata`, `/camera/camera/depth/camera_info`, `/camera/camera/depth/image_rect_raw`, `/camera/camera/depth/metadata`, `/camera/camera/extrinsics/depth_to_color`.
  - Sample camera-info frames: `camera_color_optical_frame` at `1280x720`; `camera_depth_optical_frame` at `848x480`.
  - Rate samples: color image approximately `15-18 Hz`; depth image approximately `26-27 Hz`.
- RealSense motion / IMU:
  - Combined launch command: `ros2 launch realsense2_camera rs_launch.py enable_gyro:=true enable_accel:=true unite_imu_method:=2`.
  - Combined run opened accel `MOTION_XYZ32F` at 100 FPS and gyro `MOTION_XYZ32F` at 200 FPS, then reported `HID set_power 1 failed` and `Motion Module failure`.
  - Pi UI also showed a low-voltage warning during the combined color/depth/IMU attempt.
  - Combined-run shutdown after `Ctrl+C` was clean; node stopped depth, RGB, and motion modules before exit.
  - Power/throttle probes after the warning were inconclusive without privilege: `vcgencmd get_throttled` found `/usr/bin/vcgencmd` but failed with `Can't open device file: /dev/vcio`; unprivileged `dmesg -T ...` failed with `read kernel buffer failed: Operation not permitted`.
  - IMU-only launch command: `ros2 launch realsense2_camera rs_launch.py enable_color:=false enable_depth:=false enable_gyro:=true enable_accel:=true unite_imu_method:=2`.
  - IMU-only run detected the same D435I serial `213622070342`, USB type `3.2`, firmware `5.14.0`, opened accel at 100 FPS and gyro at 200 FPS, and reported `RealSense Node Is Up!` without the earlier motion-module failure in the provided log.
  - IMU-only topics: `/camera/camera/accel/imu_info`, `/camera/camera/accel/metadata`, `/camera/camera/accel/sample`, `/camera/camera/gyro/imu_info`, `/camera/camera/gyro/metadata`, `/camera/camera/gyro/sample`, `/camera/camera/imu`, plus depth-to-accel / depth-to-gyro extrinsics.
  - `/camera/camera/imu` sample: `frame_id: camera_imu_optical_frame`, angular velocity around `(-0.0052, 0.0052, 0.0017)`, linear acceleration around `(0.255, -9.826, -0.186)`, and covariance values present.

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

**Outcome:** Not executed after the Block A paper decision. The live MAVROS heartbeat branch was blocked by the missing physical MAVLink endpoint, and the paper slab 3 autostart draft was deliberately left for the next session after today's extra RealSense evidence capture and doc refresh. Slab 3 still needs a real `fcu_url` placeholder strategy plus service-ordering notes for USB/UART enumeration, but no unit file should be enabled until a serial / UART / UDP endpoint is visible.

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

**Outcome:** Not executed as a MAVROS telemetry block because no `/mavros/state connected: true` heartbeat exists. Sensor-side evidence captured outside MAVROS: RealSense D435i color/depth publishes ROS topics; IMU-only publishes `/camera/camera/imu`, `/camera/camera/accel/sample`, and `/camera/camera/gyro/sample`; combined color/depth/IMU remains power / USB-stability-sensitive after the low-voltage warning and motion-module failure. This does not provide boat GPS / IMU / battery / RC telemetry from the low-level controller.

## Block D — Debrief + action-item extraction (≈ 20 min)

- [x] Capture lessons learned — endpoint, firmware/profile, plugin-load gotchas, working config strings (live); or slab 3 design open questions / deferred decisions (paper).
- [x] List follow-ups — missing hardware, missing cable / endpoint, baud / firmware uncertainty, specific `mavros` plugins, power-design tasks, autostart tasks.
- [x] Doc-edit decision — default defer. A confirmed `connected: true` heartbeat warrants targeted `Board.md` / `wiki/Roadmap.md` updates; a continued no-endpoint result should only update docs if new evidence is added beyond 26/05.

**Outcome:** Debrief complete. Lessons learned: Remmina-first Pi access worked; ROS 2 Jazzy environment and clock are healthy; no stale MAVROS process was running; the expanded endpoint audit is still the correct gate before any MAVROS launch. No CubePilot / Pixhawk / USB-UART / UDP MAVLink endpoint is visible; `/dev/ttyAMA10` remains only a bare Pi UART node unless TELEM wiring is confirmed. `/parasit_marvin` is the `ros2cli` daemon, not a hidden data source. RealSense D435i is present and usable as a ROS camera source for color/depth, and IMU-only works; the combined color/depth/IMU load exposed a low-voltage / motion-module stability issue that should be retested with the final power topology.

Follow-ups:

- Physical endpoint: connect a known data-capable CubePilot / Pixhawk USB cable, TELEM UART / USB-UART path, or confirmed UDP MAVLink sender, then rerun the expanded endpoint audit before any MAVROS launch.
- MAVROS profile: select PX4 / ArduPilot / generic only after the endpoint and firmware family are known; do not infer from installed packages or advertised `/mavros/*` topics.
- RealSense power: retest combined color/depth/IMU with a stronger / final Pi 5 power path and, if available, privileged throttle and kernel-log checks.
- Slab 3: draft the Pi-side `systemd` unit next, keeping `fcu_url` as a placeholder and noting USB/UART device-ordering constraints.
- Slab 4 follow-up: convert the power/layout sketch into a combined-load acceptance checklist once the MAVLink endpoint can be attached.

Doc-edit decision: targeted docs were touched because today's evidence added new durable facts beyond 26/05: the endpoint sweep widened again; `/dev/ttyAMA10` was explicitly de-promoted; RealSense color/depth and IMU-only status were verified on the post-reflash Ubuntu Desktop image; combined RealSense load exposed a power / USB-stability risk. Updates landed in `Board.md`, `wiki/Roadmap.md`, `wiki/Pi5_Bringup_Smoke_Test.md`, and this diary in commit `134edeb docs: record Pi 5 endpoint and RealSense retest`.

## Block E — Day wrap (≈ 10 min)

- [x] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [x] Fill Block E Outcome BEFORE the wrap commit.
- [x] Set Thu 28/05/2026 startup hint based on today's outcome.
- [x] Commit; push pending.

**Outcome:** Day wrap ready. Wed outcome: live MAVLink heartbeat remains blocked by the missing physical endpoint; no MAVROS launch should be attempted until the Pi sees a real serial / UART / UDP MAVLink path. RealSense side-checks are useful but separate: color/depth works, IMU-only works, and combined color/depth/IMU needs a power / USB-stability retest. Slab 3 was not drafted today and remains the next paper branch if no endpoint appears on Thu 28/05/2026. Evidence-refresh commit is local as `134edeb docs: record Pi 5 endpoint and RealSense retest`. Wrap commit subject: `docs(diary): wrap 27/05 Pi 5 endpoint + RealSense retest`. Push remains pending.

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Thu 28/05/2026 startup hint: resume from the physical-link gate.

- If a CubePilot / Pixhawk data cable, TELEM UART / USB-UART path, or UDP MAVLink endpoint becomes available: rerun the expanded endpoint audit first, then launch MAVROS only against the confirmed path and verify `/mavros/state connected: true`.
- If no endpoint is available: draft slab 3 — Pi-side `systemd` autostart strategy for MAVROS with `fcu_url` left as a placeholder and device-ordering caveats captured.
- Retest RealSense combined color/depth/IMU only after improving or confirming the Pi 5 power path; IMU-only already works and should not be confused with boat IMU telemetry.
- Convert the Slab 4 power/layout sketch into a combined-load acceptance checklist once the MAVLink endpoint is present.
- Next supervisor meeting: Wed 03/06/2026 10h-12h.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
