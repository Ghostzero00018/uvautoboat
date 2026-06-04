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

**Outcome:** Not run on 04/06/2026. No Pi 5 desktop / Remmina session was available for a one-viewer-at-a-time RealSense ROS check. The prior 28/05 evidence still stands as historical context only: color-only RealSense viewing was verified in both `rqt_image_view` and RViz2, with the color profile opened as `RGB8 1280x720x30`; that is not a fresh 04/06 measurement.

## Block D - Comparison table and first conclusion

Fill this table before moving to integration work.

| Path | Source / topic | Resolution | Measured rate | Measurement method | Notes |
|------|----------------|------------|---------------|--------------------|-------|
| Herelink console | Not confirmed live | Not measured | Not measured | Not run | Hardware / console unavailable |
| Pi ROS topic | `/camera/camera/color/image_raw` | Not measured live | Not measured live | `ros2 topic hz` planned, not run | Pi desktop unavailable |
| Pi `rqt_image_view` | `/camera/camera/color/image_raw` | Not measured live | Not measured live | Viewer check planned, not run | Pi desktop unavailable |
| Pi RViz2 | `/camera/camera/color/image_raw` | Not measured live | Not measured live | Viewer check planned, not run | Pi desktop unavailable |

Interpretation rules:

- If only ROS publish rate is numeric, do not call it viewer FPS.
- If Herelink has only visual evidence, do not force a numeric comparison.
- If simultaneous consumers break one path, record it as a consumer-exclusivity result, not a framerate result.
- If voltage / USB warnings appear, treat the measurement as load-sensitive and rerun after power stabilization.

**Outcome:** No usable 04/06 video comparison result. Confidence is high only on the negative scope claim: fresh Herelink-console and Pi-local viewer evidence was not available from this terminal session. Continue to keep Herelink / RealSense camera evidence separate from MAVROS boat telemetry.

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

**Outcome:** Not started on 04/06/2026 because Block D did not produce a usable video result and no Pi 5 / MAVROS terminal was available. Do not treat MAVProxy heartbeat as a ROS telemetry pass; the MAVROS gate remains `/mavros/state connected: true` on `serial:///dev/ttyAMA0:57600`.

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

**Outcome:** Wrap complete as diary-only fallback work. No durable runtime state changed today: no fresh Herelink FPS, Pi-local RealSense rate, MAVROS connection, or real-topic telemetry was captured, so `Board.md` and `wiki/Roadmap.md` do not need updates. Friday 05/06/2026 handoff is set to continue from the paper inventory and collect live video / MAVROS evidence first if hardware access is available.

Final checks: `git status --short --branch` showed clean sync with one modified diary file; `git diff --check` passed; the placeholder / conflict-marker scan matched only the check command embedded in this Block F checklist, not an unresolved outcome or conflict marker.

## Next steps

Friday 05/06/2026 startup: continue from the paper inventory above. First try to collect the missing live video result if Pi 5 / Herelink access is available; otherwise start the dashboard + full simulation stack integration inventory from the current simulation dashboard contract and the planned MAVROS topic candidates. Do not edit Python / YAML / JavaScript until the user explicitly approves code/config changes.
