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

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [ ] Re-read current anchors:

  ```bash
  sed -n '1,130p' working_diary/2026-06-03_wednesday_meeting_morning_only.md
  sed -n '176,186p' Board.md
  sed -n '167,200p' wiki/Roadmap.md
  sed -n '206,228p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  ```

- [ ] Confirm whether the test is on the Linux workstation, Pi 5 desktop via Remmina, Herelink console, or a physical projected display.

**Outcome:** [To fill - repo state, source path available, measurement setup.]

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

**Outcome:** [To fill - Herelink source path and FPS / metadata evidence.]

## Block C - Pi-local ROS camera viewer FPS evidence

Run this in a fresh Pi terminal, not inside a terminal already occupied by a foreground process.

- [ ] Start the color-only RealSense ROS path on the Pi 5:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch realsense2_camera rs_launch.py enable_depth:=false enable_gyro:=false enable_accel:=false
  ```

- [ ] In a second Pi terminal, identify image topics and measure ROS publish rate:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic list | grep -E 'image|camera' || true
  timeout 20 ros2 topic hz /camera/camera/color/image_raw
  ```

- [ ] In a third Pi terminal or through the Pi desktop, run one viewer at a time:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 run rqt_image_view rqt_image_view /camera/camera/color/image_raw
  ```

  Then close it before testing RViz2:

  ```bash
  source /opt/ros/jazzy/setup.bash
  rviz2
  ```

- [ ] Record whether the viewer itself exposes frame-rate information. If it does not, use `ros2 topic hz` as the Pi-local ROS publish-rate measurement and label viewer rendering as visual-only.
- [ ] Record load / stability notes:

  ```bash
  uptime
  free -h
  dmesg -T | tail -40 | grep -Ei 'voltage|usb|realsense|hid|uvc|error|fail' || true
  ```

**Outcome:** [To fill - Pi ROS publish rate, rqt/RViz status, stability notes.]

## Block D - Comparison table and first conclusion

Fill this table before moving to integration work.

| Path | Source / topic | Resolution | Measured rate | Measurement method | Notes |
|------|----------------|------------|---------------|--------------------|-------|
| Herelink console | [To fill] | [To fill] | [To fill] | [To fill] | [To fill] |
| Pi ROS topic | `/camera/camera/color/image_raw` | [To fill] | [To fill] | `ros2 topic hz` | [To fill] |
| Pi `rqt_image_view` | `/camera/camera/color/image_raw` | [To fill] | [To fill] | [To fill] | [To fill] |
| Pi RViz2 | `/camera/camera/color/image_raw` | [To fill] | [To fill] | [To fill] | [To fill] |

Interpretation rules:

- If only ROS publish rate is numeric, do not call it viewer FPS.
- If Herelink has only visual evidence, do not force a numeric comparison.
- If simultaneous consumers break one path, record it as a consumer-exclusivity result, not a framerate result.
- If voltage / USB warnings appear, treat the measurement as load-sensitive and rerun after power stabilization.

**Outcome:** [To fill - comparison result and confidence level.]

## Block E - Real-topic inventory for Friday integration work

Only start this after the video comparison has a usable first result.

- [ ] Confirm whether MAVROS can use the evidenced endpoint:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros apm.launch fcu_url:=serial:///dev/ttyAMA0:57600
  ```

- [ ] In another terminal, check the pass condition:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic echo --once /mavros/state
  ```

- [ ] If `connected: true`, capture first real topics:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic list -t | sort
  ros2 topic echo --once /mavros/imu/data
  ros2 topic echo --once /mavros/global_position/global
  ros2 topic echo --once /mavros/battery
  ros2 topic echo --once /mavros/rc/in
  ```

- [ ] If `connected: false`, stop and record the exact endpoint / config result. Do not start dashboard integration from unproven telemetry.

**Outcome:** [To fill - MAVROS state and real-topic inventory status.]

## Block F - Day wrap

- [ ] Fill all outcomes above.
- [ ] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if a durable runtime state changed;
  - otherwise keep today as diary-only planning / measurement work.
- [ ] Set Friday startup hint.
- [ ] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-04_thursday_video_framerate_and_real_topic_inventory.md
  ```

**Outcome:** [To fill - wrap state, doc update decision, Friday handoff.]

## Next steps

Friday 05/06/2026 startup: use Thursday's comparison result to decide whether the camera path needs a sharing / mux solution, then start the dashboard + full simulation stack integration inventory. Do not edit Python / YAML / JavaScript until the user explicitly approves code/config changes.
