# 2026-05-28 — Thursday: Pi 5 endpoint gate or Slab 3 autostart paper

## Day overview

Continuing from Wed 27/05/2026 ([`2026-05-27`](2026-05-27_wednesday_pi5_heartbeat_or_slab3.md)).

Repo state coming in should be clean and synced after the 27/05 wrap. Latest relevant commits before this scaffold:

- `f2bfc6c docs(diary): wrap 27/05 Pi 5 endpoint + RealSense retest`
- `134edeb docs: record Pi 5 endpoint and RealSense retest`
- `c151bcd docs(launch): refresh dashboard server command`

Pi 5 install side remains green: Ubuntu Desktop 24.04.4 LTS on `imtaquadrone-desktop`, ROS 2 Jazzy, MAVROS 2.14.0 installed via Route 1 apt path, GeographicLib defaults present, `dialout` active, GNOME Remote Desktop / Remmina at `10.120.2.162:3389`. Physical MAVLink endpoint remains the live-path gate as of 27/05: no CubePilot / Pixhawk USB serial, no TELEM UART / USB-UART, no `/dev/serial/by-id/*`, no `/dev/ttyACM*`, no `/dev/ttyUSB*`, and no UDP MAVLink listener on `14550`, `14551`, `14540`, or `5760`. `/dev/ttyAMA10` alone is not evidence of TELEM wiring.

RealSense side status from 27/05: D435i color/depth works through `realsense2_camera_node`; IMU-only works and publishes `/camera/camera/imu`; combined color/depth/IMU remains power / USB-stability-sensitive after a low-voltage warning and motion-module failure. This is separate from boat telemetry and does not prove `/mavros/imu/data`.

- **If a MAVLink endpoint is now physically connected to the Pi 5:** live heartbeat path. Rerun the expanded endpoint audit first, identify endpoint + firmware family, launch MAVROS only against the confirmed path, and capture `/mavros/state connected: true` plus first telemetry samples.
- **If no endpoint is visible:** paper continuation. Draft Slab 3 — Pi-side `systemd` autostart strategy for MAVROS — leaving `fcu_url` as a placeholder and recording device-ordering caveats.

Final commitment is a Block A decision based on actual endpoint availability when the day starts.

## Boundaries

- **In scope:** physical endpoint audit; live MAVROS heartbeat + first boat telemetry if endpoint exists; otherwise Slab 3 `systemd` autostart paper deliverable; debrief and action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, creating or enabling a real Pi-side `systemd` unit, and broad docs beyond targeted evidence updates.
- **Access preference:** use Remmina / Pi terminal first. Avoid SSH unless Remmina is unavailable or a shell-only check is explicitly needed.
- **MAVROS gate:** do not launch MAVROS just to make `/mavros/*` topics appear. Pass condition is `/mavros/state connected: true`; advertised plugin topics with `connected: false` are not telemetry.
- **Slab 3 constraint:** paper draft only until a real endpoint is known. The unit can show `fcu_url:=<placeholder>`, but no production unit can be enabled without the real serial / UART / UDP path.
- **RealSense constraint:** IMU-only success belongs to the camera stack, not low-level-controller telemetry. Combined color/depth/IMU should be retested only after the Pi 5 power path is improved or confirmed.
- **Validation methodology Three Ask:** still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Repo pre-flight + endpoint audit (≈ 15 min; ≈ 5 min if no change)

- [x] **Step 0** — Confirm repo state before live work:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree and `HEAD == origin/main`; recent log includes the 27/05 wrap commit `f2bfc6c` and evidence-refresh commit `134edeb`.

- [x] **Step 1** — Reach Pi via Remmina / Pi terminal. Confirm clock + ROS env:

  ```bash
  timedatectl status --no-pager
  source /opt/ros/jazzy/setup.bash
  printf "ROS_DISTRO=%s\n" "$ROS_DISTRO"
  which ros2
  ```

  Expected: synchronized clock, NTP active, `ROS_DISTRO=jazzy`, and `/opt/ros/jazzy/bin/ros2`.

- [x] **Step 2** — Confirm no stale MAVROS process:

  ```bash
  pgrep -af 'mavros|ros2 launch mavros' || true
  ```

  Expected: empty before any new launch.

- [x] **Step 3** — Expanded endpoint audit:

  ```bash
  lsusb
  lsusb -t
  ls -l /dev/serial/by-id/* /dev/serial/by-path/* /dev/ttyACM* /dev/ttyUSB* /dev/ttyAMA* /dev/ttyS* /dev/serial0 /dev/serial1 2>/dev/null || true
  ls /dev/ | grep -E 'serial|ttyAMA|ttyS' || true
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial|cubepilot|pixhawk|px4|ardupilot|mavlink|cdc' || true
  ss -ulnp | grep -E '14550|14551|14540|5760' || true
  ```

  A usable MAVLink endpoint is one of: `/dev/serial/by-id/...`, `/dev/ttyACM*`, `/dev/ttyUSB*`, a TELEM-wired UART node with wiring confirmation, or a confirmed UDP MAVLink sender / listener. `/dev/ttyAMA10` alone is not sufficient.

- [x] **Step 4** — Firmware / launch-profile decision (N/A; no endpoint found): identify PX4 / ArduPilot / generic from autopilot label, supervisor confirmation, QGC / MP evidence, or a heartbeat dump.
- [x] **Step 5** — Decision: live Block B+C if endpoint confirmed; paper Slab 3 if still absent.

**Outcome:** Paper branch selected on 28/05/2026. Repo pre-flight was green after `git fetch --prune`: recent log began with `ca17c49`, `f2bfc6c`, and `134edeb`; `git status --short --branch` showed `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `ca17c499a3a7fdba89b5ce8632e2d6314a9a25e5` for both refs.

Remmina-side Pi checks were also green: `timedatectl` showed `Thu 2026-05-28 13:35:22 CEST`, `System clock synchronized: yes`, and `NTP service: active`; ROS env showed `ROS_DISTRO=jazzy` and `ros2` at `/opt/ros/jazzy/bin/ros2`; `pgrep -af 'mavros|ros2 launch mavros'` returned empty.

Expanded endpoint audit still found no usable MAVLink endpoint. USB showed only root hubs, SiGma keyboard `1c4f:0027`, Intel RealSense D435i `8086:0b3a`, and Logitech mouse `046d:c08b`; `lsusb -t` showed the RealSense on USB 3 at `5000M` and HID devices only. Serial sweep found only `/dev/ttyAMA10`; there was no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial0`, or `/dev/serial1`. `/dev` name grep also returned only `ttyAMA10`. `sudo dmesg -T | tail -80 | grep ...` returned only `Bluetooth: RFCOMM TTY layer initialized`; there were no CubePilot / Pixhawk / PX4 / ArduPilot / MAVLink / CDC ACM lines. `ss -ulnp | grep -E '14550|14551|14540|5760'` returned empty. `/dev/ttyAMA10` remains insufficient without confirmed TELEM wiring, so MAVROS was not launched.

## Block B — Heartbeat smoke-test (live, ≈ 30-45 min) OR Slab 3 paper (≈ 60-90 min)

Live branch:

- [ ] Launch MAVROS with the confirmed endpoint and firmware profile:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros <px4|apm|node>.launch fcu_url:=serial:///dev/serial/by-id/<device>:115200
  # or: serial:///dev/ttyACM0:115200, serial:///dev/ttyUSB0:115200
  # if UDP confirmed: udp://:14550@
  ```

- [ ] If no heartbeat on first try: attempt only evidence-based variants — alternate baud (`57600` vs `115200`), alternate endpoint, or alternate profile if firmware was uncertain. Do not iterate blindly.
- [ ] Capture launch stdout / stderr; flag serial open errors, plugin-load errors, missing deps, or connection failures.
- [ ] Heartbeat verification:

  ```bash
  ros2 topic echo --once /mavros/state
  ```

  Expected pass: `connected: true`. Capture one full `/mavros/state` message as evidence.

Paper branch (Slab 3): draft the Pi-side `systemd` unit structure for MAVROS autostart:

- `[Unit]` section: `Description=MAVROS bridge`, `After=network-online.target`, `Wants=network-online.target`.
- `[Service]` section: `User=imt-aqua-drone`, `WorkingDirectory=/home/imt-aqua-drone`, `SupplementaryGroups=dialout`, `Type=simple`, `Restart=on-failure`, `RestartSec=5s`, `ExecStart=/bin/bash -lc 'source /opt/ros/jazzy/setup.bash && exec ros2 launch mavros <profile>.launch fcu_url:=<placeholder>'`, `StandardOutput=journal`, `StandardError=journal`.
- `[Install]` section: `WantedBy=multi-user.target`.
- Operator commands: `sudo systemctl enable <unit>`, `sudo systemctl start <unit>`, `systemctl status <unit>`, `journalctl -u <unit> -f`.
- Leave `fcu_url` as `<placeholder>` until a real endpoint is confirmed.
- Capture ordering caveats: `network-online.target` alone does not wait for slow USB enumeration; future endpoint-specific dependencies may need a `udev` rule or `After=dev-ttyACM0.device` / by-path equivalent.
- Capture failure semantics: `Restart=on-failure` handles process exits but not a permanently wrong `fcu_url`; journal logs must make repeated serial-open failures obvious.

**Outcome:** Paper Slab 3 draft captured only; no Pi-side unit file was created or enabled.

Candidate unit shape:

```ini
[Unit]
Description=MAVROS bridge
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=imt-aqua-drone
WorkingDirectory=/home/imt-aqua-drone
SupplementaryGroups=dialout
Restart=on-failure
RestartSec=5s
ExecStart=/bin/bash -lc 'source /opt/ros/jazzy/setup.bash && exec ros2 launch mavros <profile>.launch fcu_url:=<placeholder>'
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Operator command set, once the endpoint and launch profile are real:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mavros-bridge.service
sudo systemctl start mavros-bridge.service
systemctl status mavros-bridge.service --no-pager
journalctl -u mavros-bridge.service -f
```

Design constraints:

- Keep `fcu_url:=<placeholder>` until a real serial / UART / UDP endpoint is confirmed by Block A evidence.
- Keep `<profile>` unset until the firmware family is known. Use the PX4 / ArduPilot / generic profile only after endpoint + firmware evidence exists.
- Use `/bin/bash -lc 'source ... && exec ros2 launch ...'` because `source` is shell-specific and `exec` lets `systemd` track the ROS launch process directly.
- `Restart=on-failure` covers process exits, not a permanently wrong `fcu_url`; journal output must make repeated serial-open or heartbeat failures obvious.
- `network-online.target` is useful for UDP links, but it does not wait for a slow USB serial endpoint. A future serial-specific deployment may need a concrete device dependency, for example a by-id / by-path `.device` unit or a `udev` rule keyed to the confirmed adapter.
- Do not include RealSense in this unit. Camera startup belongs to a separate camera unit or a higher launch layer, so camera power / USB faults cannot restart the MAVROS bridge unnecessarily.

## Block C — Telemetry beyond heartbeat (live, ≈ 30 min) OR Slab 3 cross-check (≈ 20-30 min)

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

Paper branch:

- [x] Cross-reference Slab 3 against Thu 21/05 §D.2 topic-name scheme: MAVROS sensor topics should remap toward neutral `/sensors/*`; thrust translation remains a Layer B bridge-node concern, not a `systemd` unit concern.
- [x] Check that the unit design remains valid under a cold boot where network comes up before the autopilot endpoint enumerates.
- [x] Check whether Slab 3 should explicitly defer RealSense startup, or simply document that camera service ordering belongs to a separate unit / launch layer.

**Outcome:** Paper cross-check complete. The Slab 3 autostart unit is only the process supervisor for MAVROS; it should not own topic translation logic. Thu 21/05 §D.2 remains the alignment baseline: MAVROS sensor outputs should be exposed toward neutral `/sensors/*` names by launch-time remaps in the future MAVROS launch wrapper, while LiDAR / camera remain separate driver concerns and thrust translation remains a Layer B bridge-node concern because `Float64` thrust commands cannot be remapped directly into MAVROS `Twist` or manual-control messages.

Cold-boot caveat: the unit can start after `network-online.target`, but a USB autopilot / USB-UART endpoint may enumerate later. Production deployment should prefer a stable `/dev/serial/by-id/*` or `/dev/serial/by-path/*` endpoint when available, and add device-ordering only after the real adapter path is known. Until then, the unit draft is suitable as a paper strategy, not as an enable-now service.

## Side Progress - Pi-side RealSense viewers

After the MAVLink endpoint gate stayed closed, a camera-side Pi-local viewer check was run through Remmina. This was deliberately separate from MAVROS: it proves RealSense video visibility on the Pi 5 desktop, not boat telemetry or `/mavros/imu/data`.

Color-only RealSense launch:

```bash
source /opt/ros/jazzy/setup.bash
ros2 launch realsense2_camera rs_launch.py enable_depth:=false enable_gyro:=false enable_accel:=false
```

Evidence from the launch:

- RealSense ROS v4.57.7 with LibRealSense v2.57.7.
- D435i serial `213622070342`, USB type `3.2`, firmware `5.14.0`, product ID `0x0B3A`.
- Color profile opened as `RGB8`, `1280x720`, `30 FPS`.
- `RealSense Node Is Up!` reported.
- The missing `/home/imt-aqua-drone/.realsense-config.json` message only loaded defaults.

Viewer checks:

- `ros2 run rqt_image_view rqt_image_view /camera/camera/color/image_raw` initially failed because `rqt_image_view` was not installed.
- `sudo apt update` showed all package indexes current.
- `sudo apt install ros-jazzy-rqt-image-view` installed `ros-jazzy-rqt-image-view` 1.3.0 plus Qt / rqt dependencies; `/camera/camera/color/image_raw` then displayed in `rqt_image_view`. The `QSocketNotifier: Can only be used with threads started with QThread` message appeared but did not block viewing.
- `sudo apt install ros-jazzy-rviz2` installed RViz2 14.1.20 plus RViz dependencies.
- `rviz2` launched successfully, reported OpenGL `3.1 (GLSL 1.4)`, and displayed the RealSense color image topic. `Stereo is NOT SUPPORTED` appeared as a non-blocking RViz message.

Outcome: Pi-side color-only RealSense viewing is now verified through both `rqt_image_view` and RViz2 on the Ubuntu Desktop image. Keep this as camera-path evidence only. Combined color/depth/IMU remains a separate power / USB-stability retest, and MAVROS remains blocked until a real serial / UART / UDP MAVLink endpoint appears.

## Block D — Debrief + action-item extraction (≈ 20 min)

- [x] Capture lessons learned — endpoint, firmware/profile, plugin-load gotchas, working config strings (live); or Slab 3 design open questions / deferred decisions (paper).
- [x] List follow-ups — missing hardware, missing cable / endpoint, baud / firmware uncertainty, `mavros` plugin config, power-design tasks, autostart tasks.
- [x] Doc-edit decision — default defer. A confirmed `connected: true` heartbeat warrants targeted `Board.md` / `wiki/Roadmap.md` updates; Slab 3 paper may warrant targeted docs only if it changes durable Phase 5 deployment planning.

**Outcome:** Debrief complete. Lessons learned: the Pi 5 software side is still healthy (`timedatectl`, ROS 2 Jazzy env, no stale MAVROS), but the live MAVROS path remains physically blocked because the Pi still sees no CubePilot / Pixhawk / USB-UART / UDP MAVLink endpoint. `/dev/ttyAMA10` alone is still only a bare Pi UART node until TELEM wiring and baud/profile are confirmed. The Slab 3 `systemd` strategy should stay paper-only with `fcu_url:=<placeholder>` until a real endpoint appears; `network-online.target` is not enough to guarantee USB serial enumeration. Camera startup should stay outside the MAVROS service.

RealSense side progress is useful but separate: color-only D435i streaming is now verified locally on the Pi 5 desktop through both `rqt_image_view` and RViz2. The viewers are ROS subscribers; the RealSense USB handle belongs to `realsense2_camera_node`, so future "device busy" checks should look for leftover camera-node / container processes, not only viewer processes. Combined color/depth/IMU remains a power / USB-stability retest, not a green acceptance item.

Follow-ups:

- Connect a real MAVLink endpoint: data-capable CubePilot / Pixhawk USB, TELEM UART / USB-UART, or confirmed UDP MAVLink sender.
- Rerun the expanded endpoint audit before any new MAVROS launch.
- Select PX4 / ArduPilot / generic MAVROS profile only after endpoint + firmware evidence exists.
- Convert Slab 3 from paper to a real unit only after `fcu_url` and device-ordering are known.
- Retest combined RealSense color/depth/IMU only after improving or confirming the Pi 5 power path; keep this separate from boat telemetry.
- Before relaunching the camera after viewer tests, check `pgrep -af 'realsense2_camera_node|component_container|rs_launch'` and `lsusb -d 8086:0b3a`.

Doc-edit decision: touched durable status docs because 28/05 added two durable facts beyond the already-pushed diary draft: the endpoint absence was reconfirmed on a new day, and Pi-local color-only RealSense viewing through `rqt_image_view` + RViz2 is now proven. Updates landed in `Board.md`, `wiki/Roadmap.md`, and this diary. No `README.md`, `USER_MANUAL.md`, code, YAML, shell, or Pi-side service files were changed.

## Block E — Day wrap (≈ 10 min)

- [x] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [x] Fill Block E Outcome BEFORE the wrap commit.
- [x] Set next startup hint based on today's outcome.
- [ ] Commit + push (pending user-run commit).

**Outcome:** Day wrap ready. Final state captured: Block A endpoint gate still selects the paper branch; Slab 3 MAVROS autostart remains a placeholder design until `fcu_url` and device ordering are known; Pi-local color-only RealSense viewing is verified through both `rqt_image_view` and RViz2; combined color/depth/IMU remains a separate power / USB-stability retest. Durable docs touched: `Board.md`, `wiki/Roadmap.md`, and this diary only.

Verification before commit: `git status --short --branch` shows three modified Markdown files; `git diff --check` is clean; placeholder / conflict-marker scan is clean after this outcome fill. Commit subject:

`docs: wrap 28/05 Pi endpoint gate + RealSense viewers`

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Next active startup hint: resume from the physical MAVLink endpoint gate unless the session is explicitly camera-focused.

- If a real MAVLink endpoint appears: rerun the expanded endpoint audit first, launch MAVROS only against the confirmed path, verify `/mavros/state connected: true`, then capture first `/mavros/imu/data` and GPS / battery / RC samples where available.
- If no endpoint appears: do not launch MAVROS just to create `/mavros/*` topics. Keep Slab 3 as paper-only until `fcu_url` and device-ordering are known.
- If camera work resumes: color-only Pi-local viewing is already verified through `rqt_image_view` and RViz2; next useful camera test is combined color/depth/IMU only after improving or confirming the Pi 5 power path.
- Next supervisor meeting: Wed 03/06/2026 10h-12h.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
