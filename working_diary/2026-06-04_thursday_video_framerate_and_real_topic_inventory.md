# 2026-06-04 - Thursday: video frame-rate comparison + real-topic inventory

## Day overview

Continuing from Wed 03/06/2026 ([`2026-06-03`](2026-06-03_wednesday_meeting_morning_only.md)).

Primary work for Thu 04/06/2026 is the first professor follow-up from the 03/06 meeting: compare the video frame rate on the Herelink console path with direct Pi 5 ROS viewing through `rqt_image_view` / RViz2. If there is time after the camera comparison, start the inventory for real low-level-controller ROS 2 topics that will later feed the existing dashboard and simulation stack.

Carry the current facts carefully:

- MAVProxy heartbeat / ArduPilot status is externally evidenced on `/dev/ttyAMA0` at `57600` from the professor photo captured Tue 02/06/2026 at 22:09 and shown 03/06.
- MAVROS / ROS telemetry is still pending until `/mavros/state connected: true` is captured against the same endpoint.
- RealSense camera evidence is separate from MAVROS boat telemetry.
- Earlier evidence showed the Herelink video path can be decoupled from the Pi ROS graph. Today's first task must confirm the exact current source path before comparing frame rates.
- The dashboard currently talks to ROS through `rosbridge` on port `9090`, camera MJPEG through `web_video_server` on port `8080`, and the HTTP dashboard on port `8002`.

## Boundaries

- **In scope:** video source-path confirmation, Herelink console FPS evidence, Pi-local ROS viewer FPS evidence, system-load notes, first real-topic inventory.
- **Out of scope:** Python / YAML / JavaScript edits, dashboard feature implementation, Pi-side `systemd`, and changing the production video pipeline.
- **Camera boundary:** do not run Herelink video and Pi-side RealSense ROS viewers simultaneously unless the test explicitly studies consumer exclusivity. Prior evidence suggests these consumers may conflict.
- **MAVROS boundary:** do not count advertised `/mavros/*` topics as success. Only `/mavros/state connected: true` proves the ROS-side low-level-controller link.

## Block A - Repo and evidence pre-flight

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [x] Re-read current anchors:

  ```bash
  sed -n '1,130p' working_diary/2026-06-03_wednesday_meeting_morning_only.md
  sed -n '176,186p' Board.md
  sed -n '167,200p' wiki/Roadmap.md
  sed -n '206,228p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  sed -n '1,23p' working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  ```

- [x] Confirm whether the test is on the Linux workstation, Pi 5 desktop via Remmina, Herelink console, or a physical projected display.

**Outcome:** Block A started on the Linux workstation `vrx-Precision-7560` on 04/06/2026 at 10:05 CEST. `git fetch --prune` completed, `git log --oneline -5` began with `91cea9e`, `e94fcd8`, `1724c84`, `91d8a0b`, and `de2e25b`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `91cea9eaa94497e2611b249b224fafd806295e6d` for both refs. No pull, merge, or push was needed.

Current anchors were re-read from the 03/06 diary, `Board.md`, `wiki/Roadmap.md`, the 28/05 Pi-side RealSense viewer evidence, and the 05/06 integration scaffold. The state remains: MAVProxy heartbeat / ArduPilot status is evidenced on `/dev/ttyAMA0` at `57600`; MAVROS / ROS telemetry still needs `/mavros/state connected: true`; RealSense camera evidence is separate from boat telemetry.

Measurement setup verdict: Remmina is installed at `/usr/bin/remmina`, but no active Pi 5 desktop, Herelink console, or physical projected display was available from this terminal session. The exact current Herelink video source path could not be confirmed live, so Blocks B-D cannot produce a fresh frame-rate comparison today. Follow the fallback path: paper inventory for dashboard + simulation-stack integration only, with no Python / YAML / JavaScript edits.

## Block B - Herelink console video path and FPS evidence

- [ ] Confirm exact Herelink video source path before measurement:
  - source device / camera;
  - whether the stream is actually projected from the Pi 5 or directly from the Herelink / QGC video path;
  - whether the Pi ROS graph has any camera publisher while the console video is active.
- [ ] If the Herelink / QGC UI exposes numeric FPS or stream metadata, record it directly.
- [ ] If no numeric FPS is visible, record the strongest available evidence without inventing a number:
  - resolution;
  - any bitrate / radio-rate panel values;
  - visible smoothness notes;
  - whether a screen-recording / external measurement is needed.
- [ ] Optional independent stream metadata check from the workstation only if the Herelink RTSP endpoint is reachable and the workstation is on the Herelink network:

  ```bash
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height,r_frame_rate,avg_frame_rate \
    -of default=nw=1 \
    rtsp://<herelink-ip>:8554/fpv_stream
  ```

  Label this as RTSP stream metadata, not necessarily Herelink console render FPS.

**Outcome:** Not run on 04/06/2026. The Herelink console / QGC video UI was not available from this terminal session, and no RTSP endpoint reachability was confirmed. No numeric Herelink console FPS, bitrate, resolution, or stream-metadata evidence was collected. Do not infer a frame rate from older evidence.

## Block C - Pi-local ROS camera viewer FPS evidence

Run this in a fresh Pi terminal, not inside a terminal already occupied by a foreground process.

- [x] Start the color-only RealSense ROS path on the Pi 5:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch realsense2_camera rs_launch.py enable_depth:=false enable_gyro:=false enable_accel:=false
  ```

- [x] In a second Pi terminal, identify image topics and measure ROS publish rate:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic list | grep -E 'image|camera' || true
  timeout 20 ros2 topic hz /camera/camera/color/image_raw
  ```

- [x] In a third Pi terminal or through the Pi desktop, run one viewer at a time:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 run rqt_image_view rqt_image_view /camera/camera/color/image_raw
  ```

  Then close it before testing RViz2:

  ```bash
  source /opt/ros/jazzy/setup.bash
  rviz2
  ```

- [x] Record whether the viewer itself exposes frame-rate information. If it does not, use `ros2 topic hz` as the Pi-local ROS publish-rate measurement and label viewer rendering as visual-only.
- [x] Record load / stability notes:

  ```bash
  uptime
  free -h
  dmesg -T | tail -40 | grep -Ei 'voltage|usb|realsense|hid|uvc|error|fail' || true
  ```

**Outcome:** Not run on 04/06/2026. No Pi 5 desktop / Remmina session was available for a one-viewer-at-a-time RealSense ROS check. The prior 28/05 evidence still stands as historical context only: color-only RealSense viewing was verified in both `rqt_image_view` and RViz2, with the color profile opened as `RGB8 1280x720x30`; that is not a fresh 04/06 measurement.

**Live addendum, 04/06/2026 11:05-11:06:** Pi-side color-only RealSense check completed on `imtaquadrone-desktop`. `lsusb -t` showed the D435i on Bus 003 / Port 001 at `5000M`; the RealSense launch reported D435I serial `213622070342`, physical port `3-1`, USB type `3.2`, firmware `5.14.0`, product ID `0x0B3A`, and opened the color stream as `RGB8 1280x720x30`. `RealSense Node Is Up!` appeared, and the node later exited cleanly after capture.

`ros2 topic list` showed `/camera/camera/color/image_raw` plus related camera-info / metadata topics, and also showed an `/oakd/rgb/preview/image_raw` topic that was not part of this RealSense measurement. `ros2 topic info --verbose /camera/camera/color/image_raw` showed one publisher from node `/camera/camera`, type `sensor_msgs/msg/Image`, QoS `RELIABLE` and `TRANSIENT_LOCAL`. `timeout 20 ros2 topic hz /camera/camera/color/image_raw` ramped from about `17.659` Hz to a final reported average of `20.811` Hz over a 344-message window. Record this as ROS publish rate, not viewer render FPS.

Stability notes: `uptime` showed 7 min uptime with load average `2.42, 1.88, 0.98`; `free -h` showed 15 GiB total RAM, 1.6 GiB used, 12 GiB free, 13 GiB available, and no swap used. The filtered `sudo dmesg -T` tail matched only `hid-sensor-hub 0003:8086:0B3A.0005: No report with id 0xffffffff found`; no filtered under-voltage / throttling / RealSense failure line was captured in that tail.

Viewer notes: `rqt_image_view` opened `/camera/camera/color/image_raw` and displayed the video stream. The `QSocketNotifier: Can only be used with threads started with QThread` line and the class-loader unload warning on shutdown were non-blocking. RViz2 also displayed the video stream, reported OpenGL `3.1 (GLSL 1.4)`, printed the usual `Stereo is NOT SUPPORTED` line, and later showed queue-full message-filter drops for frame `camera_color_optical_frame`; those drops did not prevent visual confirmation.

**Live addendum, 04/06/2026 14:41-14:44:** Afternoon simultaneous Herelink-console / Pi RealSense check completed with no `rqt_image_view` or RViz2 viewer active on the Pi side. The Herelink console acted as a portable display for the Pi desktop / video stream; no FPS overlay or stream-stat readout was available on the console. Visual-only observation: lag was acceptable and no significant lag was observed, including with the Herelink operator outside the building while the Pi 5 remained inside. Do not treat this as a measured Herelink FPS result, and do not use it to close the older Herelink RTSP / QGC consumer-exclusivity finding because this was a Pi-desktop display condition, not a numeric retest of that stream path.

The Pi RealSense node was relaunched with default launch arguments via `ros2 launch realsense2_camera rs_launch.py`. The launch again found D435I serial `213622070342`, physical port `3-1`, USB type `3.2`, firmware `5.14.0`, product ID `0x0B3A`, then opened depth as `Z16 848x480x30` and color as `RGB8 1280x720x30`. The log set default `gyro_fps` and `accel_fps` parameters, but the pasted topic list showed only color/depth topics and did not show IMU / gyro / accel topics publishing in this run.

Afternoon ROS publish-rate samples: `/camera/camera/color/image_raw` ramped from `8.894` Hz to a final reported average of `16.393` Hz over a 279-message window; `/camera/camera/depth/image_rect_raw` ramped from `23.374` Hz to a final reported average of `24.540` Hz over a 429-message window. The depth-rate command ended with `failed to shutdown: rcl_shutdown already called on the given context`, after the rate samples were printed.

Afternoon stability notes: `uptime` showed 3 min uptime with load average `2.48, 1.22, 0.49`; `free -h` showed 15 GiB total RAM, 1.5 GiB used, 13 GiB free, 14 GiB available, and no swap used. The filtered `sudo dmesg -T` tail showed repeated `hwmon hwmon2: Undervoltage detected!` / `Voltage normalised` pairs from 14:41 through 14:44, plus the same `hid-sensor-hub 0003:8086:0B3A.0005: No report with id 0xffffffff found` line. Treat the afternoon rates as power/load-sensitive; they are not a clean replacement for the morning color-only Pi rate captured without filtered under-voltage warnings.

## Block D - Comparison table and first conclusion

Fill this table before moving to integration work.

| Path | Source / topic | Resolution | Measured rate | Measurement method | Notes |
|------|----------------|------------|---------------|--------------------|-------|
| Herelink console | Pi desktop / video stream on portable console | Not measured | Visual-only; no numeric FPS | Operator observation | No FPS overlay/stat readout available; acceptable lag, no significant lag observed |
| Pi ROS topic, morning color-only | `/camera/camera/color/image_raw` | `RGB8 1280x720` | Final `ros2 topic hz` average `20.811` Hz | `timeout 20 ros2 topic hz` | D435i USB `5000M` / type `3.2`; ROS publish rate, not viewer FPS |
| Pi ROS topic, afternoon default color | `/camera/camera/color/image_raw` | `RGB8 1280x720` | Final `ros2 topic hz` average `16.393` Hz | `timeout 20 ros2 topic hz` | Simultaneous Herelink visual-only check; repeated under-voltage warnings captured |
| Pi ROS topic, afternoon default depth | `/camera/camera/depth/image_rect_raw` | `Z16 848x480` | Final `ros2 topic hz` average `24.540` Hz | `timeout 20 ros2 topic hz` | Depth stream opened by default launch; shutdown warning after samples printed |
| Pi `rqt_image_view` | `/camera/camera/color/image_raw` | `RGB8 1280x720` | Not numerically measured | Visual viewer check | Video stream displayed; Qt / class-loader shutdown warnings non-blocking |
| Pi RViz2 | `/camera/camera/color/image_raw` | `RGB8 1280x720` | Not numerically measured | Visual viewer check | Video stream displayed; OpenGL `3.1`; queue-full drops later appeared |

Interpretation rules:

- If only ROS publish rate is numeric, do not call it viewer FPS.
- If Herelink has only visual evidence, do not force a numeric comparison.
- If simultaneous consumers break one path, record it as a consumer-exclusivity result, not a framerate result.
- If voltage / USB warnings appear, treat the measurement as load-sensitive and rerun after power stabilization.

**Outcome:** Partial camera comparison result captured after the original morning fallback. The strongest numeric Pi-side measurement remains the morning color-only run at `20.811` Hz with no filtered under-voltage warning. The afternoon default-launch run captured color at `16.393` Hz and depth at `24.540` Hz while Herelink was visually acceptable, but it also captured repeated under-voltage warnings, so treat those afternoon rates as load/power-sensitive. Herelink remains visual-only because no FPS overlay or stream metadata was available. Continue to keep Herelink / RealSense camera evidence separate from MAVROS boat telemetry.

## Block E - Real-topic inventory for Friday integration work

Only start this after the video comparison has a usable first result.

- [x] Confirm whether MAVROS can use the evidenced endpoint:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros apm.launch fcu_url:=serial:///dev/ttyAMA0:57600
  ```

- [x] In another terminal, check the pass condition:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic echo --once /mavros/state
  ```

- [x] If `connected: true`, capture first real topics:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic list -t | sort
  ros2 topic echo --once /mavros/imu/data
  ros2 topic echo --once /mavros/global_position/global
  ros2 topic echo --once /mavros/battery
  ros2 topic echo --once /mavros/rc/in
  ```

- [ ] If `connected: false`, stop and record the exact endpoint / config result. Do not start dashboard integration from unproven telemetry.

**Outcome:** Not started on 04/06/2026 because Block D did not produce a usable video result and no Pi 5 / MAVROS terminal was available. Do not treat MAVProxy heartbeat as a ROS telemetry pass; the MAVROS gate remains `/mavros/state connected: true` on `serial:///dev/ttyAMA0:57600`.

**Live addendum, 04/06/2026 11:39:** MAVROS pass condition reached through the evidenced `/dev/ttyAMA0:57600` path via MAVProxy UDP fanout. `apm.launch` and `px4.launch` both existed under `/opt/ros/jazzy/share/mavros/launch/`; `/dev/ttyAMA0` existed as `root:dialout`; no MAVProxy process was running before the test.

Actual path used: start MAVProxy on the serial endpoint with `mavproxy.py --master=/dev/ttyAMA0 --baudrate 57600 --out=udpout:127.0.0.1:14550`, then launch MAVROS with `ros2 launch mavros apm.launch fcu_url:=udp://127.0.0.1:14550@`. MAVProxy detected vehicle `1:1`, reported `online system 1`, mode `HOLD`, `fence present`, and repeated `AP: EKF3 waiting for GPS config data`. A duplicate `output add udpout:127.0.0.1:14550` command was also accepted. MAVProxy later ended with a Python `log_writer` shutdown / core-dump message; this is a MAVProxy cleanup issue after the heartbeat/fanout evidence, not the MAVROS pass criterion.

MAVROS opened the UDP endpoint, detected remote address `1.1`, started UAS `MY ID 1.191, TARGET ID 1.1`, then reported `CON: Got HEARTBEAT, connected. FCU: ArduPilot`. The pass-condition sample was:

```yaml
connected: true
armed: false
guided: false
manual_input: false
mode: HOLD
system_status: 5
```

First ROS telemetry / topic evidence was captured after `connected: true`:

- `ros2 topic list -t | sort` showed the `/mavros/*` topic surface including `/mavros/state`, `/mavros/imu/data`, `/mavros/global_position/raw/fix`, `/mavros/battery`, `/mavros/rc/in`, setpoint topics, mission / geofence / rallypoint topics, and `/uas1/mavlink_source` / `/uas1/mavlink_sink`.
- `/mavros/imu/data` published an IMU sample with frame `base_link`, orientation, angular velocity, and linear acceleration (`z` about `9.767`).
- `/mavros/global_position/raw/fix` published a `sensor_msgs/NavSatFix` sample with `status: -1`, `service: 1`, `latitude: 0.0`, `longitude: 0.0`, `altitude: 17.163`, and covariance first entry `-1.0`; interpret this with the MAVROS launch warning `GP: No GPS fix` and FCU status `EKF3 waiting for GPS config data`.
- `/mavros/battery` published a present battery sample at `15.984001159667969` V, `percentage: 1.0`, and `power_supply_status: 2`.
- `/mavros/rc/in` published with `rssi: 255` and an empty `channels` list; record this as setup state, not a MAVROS connection failure.

Request/response caveat from the same run: streaming telemetry succeeded, but targeted requests did not complete during the capture window. MAVROS logged autopilot-version service timeouts before switching to default capabilities, parameter request-list retries exhausted, mission / rallypoint / geofence pulls timed out, and command `520` / `410` ACK timeouts. Treat this as evidence that broadcast telemetry is available through the `57600` fanout, while command-path and write-path mapping still need a separate validation pass before dashboard integration.

Interpretation: MAVROS ROS-side low-level-controller link is now proven on 04/06/2026 because `/mavros/state connected: true` was captured and first ROS telemetry topics published. GPS fix / EKF GPS configuration, RC channel population, targeted request/response behaviour, command-path mapping, and dashboard / simulation integration remain open.

Fallback paper inventory completed instead:

- Dashboard connection path: browser -> `rosbridge` on `9090`; camera MJPEG -> `web_video_server` on `8080`; HTTP dashboard -> `serve_dashboard.py` on `8002`.
- Current dashboard read topics are simulation-first: `/wamv/sensors/gps/gps/fix`, `/wamv/thrusters/left/thrust`, `/wamv/thrusters/right/thrust`, `/planning/mission_status`, `/planning/waypoints`, `/planning/current_target`, `/perception/obstacle_info`, `/control/status`, `/control/anti_stuck_status`, and `/planning/config`.
- Current dashboard write / service paths are `/planning/set_config`, `/planning/mission_command`, `/planning/emergency_stop`, `/planning/stop_mission`, and `/planning/generate_waypoints`.
- Camera panel default remains `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`, but `app.js` also supports manual topic entry plus `/rosapi/topics_for_type` discovery for `sensor_msgs/msg/Image` and `sensor_msgs/msg/CompressedImage`. This is the lowest-risk Friday camera quick win if `/camera/camera/color/image_raw` is visible to `web_video_server`.
- `launch/remap.launch.yaml` still matches the two-layer transition model: VRX `/wamv/*` relays to neutral `/sensors/*` / `/actuators/*` when `use_real_hardware:=false`; `use_real_hardware:=true` still points at a not-yet-existing `bridge` package and must not be flipped during normal simulation.
- Planned mapping for Friday: GPS `/mavros/global_position/global` or `/mavros/global_position/raw/fix` -> dashboard GPS; IMU `/mavros/imu/data` -> diagnostics / sim adapter; camera `/camera/camera/color/image_raw` -> dashboard camera topic; battery `/mavros/battery` and RC `/mavros/rc/in` -> diagnostics first; real thruster command path remains TBD and must not be guessed from the VRX `0-800` Float64 scale.
- VRX §8.2 local check: sibling `vrx` checkout is clean on `autoboat/main` at `e384cd65`; `autoboat/main --not jazzy` has 0 local project-specific commits; `jazzy --not upstream/jazzy` has the single LiDAR bake-in `e384cd65`; latest local tags are `v3.1.2`, `v3.1.0`, and `v3.0.4`. This supports "no local trigger fired", but the weekly item is deferred rather than fully closed because no fresh upstream fetch was run for the `vrx` checkout today.

## Block F - Day wrap

- [x] Fill all outcomes above.
- [x] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if a durable runtime state changed;
  - otherwise keep today as diary-only planning / measurement work.
- [x] Set Friday startup hint.
- [x] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-04_thursday_video_framerate_and_real_topic_inventory.md
  ```

**Outcome:** Wrap reopened for live Pi-side camera and MAVROS addendums after the original diary-only fallback. Durable runtime state did change today: MAVROS passed the ROS-side telemetry gate with `/mavros/state connected: true` and first ROS samples from IMU, raw GPS (no fix), battery, and RC topics. `Board.md` and `wiki/Roadmap.md` were updated for that state change. A later afternoon camera addendum captured Herelink visual-only evidence, default RealSense color/depth rates, and repeated under-voltage warnings; no numeric Herelink FPS / metadata was available.

Final checks after the afternoon addendum: `git status --short --branch` showed clean sync with one modified diary file; `git diff --check` passed; the changed-file visibility sweep over this diary returned no matches; the placeholder / conflict-marker scan matched only the check command embedded in this Block F checklist, not an unresolved outcome or conflict marker.

## Next steps

Friday 05/06/2026 startup: start from the proven MAVROS endpoint and the paper inventory above. If Pi 5 / Herelink access is available, capture numeric Herelink video stats only if the console exposes them; otherwise keep Herelink as visual-only evidence. Stabilize Pi power before relying on default RealSense color+depth rates, then start the dashboard + full simulation stack integration inventory from `/mavros/state connected: true`, the first MAVROS ROS samples, the current simulation dashboard contract, and the planned mapping candidates. Do not edit Python / YAML / JavaScript until the user explicitly approves code/config changes.
