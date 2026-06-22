# Monday 22/06/2026 - Console hotspot video and MAVLink dashboard path

## Purpose

Experiment with the console / Herelink hotspot path as the preferred real-video and MAVLink source for the workstation dashboard.

Primary goal: investigate whether the practical workflow can become:

```text
Pi 5 / onboard camera source -> console / Herelink video path -> workstation dashboard
console / Herelink MAVLink path -> workstation ROS 2 topics -> dashboard / later remap work
```

This should be treated as observation and prerequisite mapping first. The current dashboard is still simulation-first, still reads/writes the `/wamv/*` topic contract, and still has no real-topic adapter.

## Starting context

- Repo cold-start target after 19/06 closeout: `main` clean/synced at `438b51f`.
- 19/06 camera-OFF Pi 5 MAVProxy / MAVROS update-impact check passed: `/dev/ttyAMA0:57600`, MAVProxy heartbeat, `/mavros/state connected: true`, live IMU / battery, and workstation DDS visibility of 136 `/mavros/*` topics over `IoT IMT Nord Europe`.
- 18/06 proved only the direct RealSense display path: `Pi RealSense -> workstation DDS -> web_video_server -> dashboard`, using `/camera/camera/color/image_raw` and the practical `424x240x15` color-only profile.
- Direct Pi RealSense over WiFi is workable but bandwidth/load-sensitive. The console / Herelink video path may be better for operator video if it can be exposed cleanly to the workstation dashboard.
- 11/05 campus-side Herelink evidence: Linux QGC video worked on `IMT-Aquatic-drone` with QGC `Source = Herelink Hotspot`; the underlying RTSP stream was independently verified as `rtsp://192.168.43.1:8554/fpv_stream`.
- MAVLink and video are separate paths. QGC / MP arm-disarm or MAVLink telemetry reachability does not prove video forwarding, and video reachability does not prove MAVLink telemetry.
- 13/05 evidence warned about camera consumer exclusivity: running `realsense2_camera_node` and workstation RViz streaming could break the Herelink video stream until RViz stopped. Do not assume Pi RealSense and console video can both consume the same camera at the same time.
- 17/06 mixed-topology QGC observation stayed visual-only and safety-clean. It did not validate real-FCU upload, command/write paths, or dashboard topic adaptation.

## Boundaries

- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, Pi upload, real-FCU command, or real-vehicle command path.
- Do not use dashboard mission or thruster controls against the real FCU.
- Console / Herelink / QGC / browser / live network checks are user-run by default unless explicitly delegated.
- Code, launch, YAML, package, dependency, systemd, dashboard, or bridge edits require explicit approval.
- Markdown/docs edits are allowed if they only record the scaffold or observed evidence.
- Do not claim the dashboard "gets MAVLink topics" directly: MAVLink frames must first be translated into ROS 2 topics, for example via MAVROS or another approved bridge, before rosbridge/dashboard can consume them.
- Keep video evidence, MAVLink telemetry evidence, and `/wamv/*` replacement readiness as separate results.
- Keep browser-facing services loopback-only on the workstation unless deliberately exposing them for a documented reason.
- Commit/push any diary/docs work on normal internet WiFi. Switch to `IMT-Aquatic-drone` or `IoT IMT Nord Europe` only for approved live observations.

## Block A - Repo guard and source refresh

- [x] Run:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If fetch fails while still on normal internet WiFi, stop and report.
- [x] If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- [x] If ahead, diverged, or dirty, stop and report before continuing.
- [x] Re-read:
  - `working_diary/2026-06-19_friday_dashboard_hygiene_camera.md`
  - `working_diary/2026-06-18_thursday_block_c_attribution_followup.md`
  - `working_diary/2026-06-17_wednesday_block_c_mixed_topology_observation.md`
  - `wiki/Common_Issues.md` Herelink / QGC video section
  - `wiki/Pi5_Bringup_Smoke_Test.md`
  - `wiki/RealSense_Dashboard_Testing.md`
  - `web_dashboard/autoboat/README_autoboat_dashboard.md`
  - `Board.md` MAVROS, RealSense, QGC / Herelink rows
  - `wiki/Roadmap.md` Phase 5 rows for MAVROS, RealSense, QGC / Herelink, and `/wamv/*` topic adaptation

**Outcome:** repo guard passed on 22/06/2026. `git fetch --prune`
completed, latest commit was `54ebbbd` (`docs(diary): scaffold 22/06
console hotspot dashboard path`), `git status --short --branch` showed clean
`## main...origin/main`, and `git rev-parse HEAD origin/main` returned the
same SHA `54ebbbde803f192e9db926167bcdd8bb7451da97` for both refs. The active
22/06 scaffold, the 19/06, 18/06, and 17/06 diaries, and the requested
Board/wiki/dashboard source anchors were re-read before static interpretation.

At this Block A checkpoint, no live console, Herelink, QGC, Pi, browser,
rosbridge, `web_video_server`, or network observation had run yet.

## Block B - Scope and go/no-go

- [ ] Confirm today's main goal:
  - console / Herelink hotspot video route to workstation dashboard;
  - console / Herelink MAVLink telemetry route to ROS 2 topics;
  - prerequisite check for replacing simulation `/wamv/*` topics with real ROS 2 topics later.
- [ ] Confirm equipment availability:
  - Pi 5 / control box powered as needed;
  - console / Herelink controller available;
  - workstation can switch to `IMT-Aquatic-drone`;
  - QGC available on workstation;
  - browser available on workstation;
  - no requirement to run Pi RealSense and MAVROS together under co-load unless the dedicated >=5A Pi supply is confirmed.
- [ ] Confirm whether any live check is approved today.
- [ ] If live checks are approved, decide which block starts first:
  - Block C network / console inventory;
  - Block D video route observation;
  - Block E MAVLink telemetry observation;
  - Block F topic-replacement prerequisite check.

Closure note: live Blocks C-D-E were later user-run and are recorded in
`22/06 Blocks C-D-E live observation result`. The scaffold boxes above remain
unchecked because not every gate item was captured in its original checklist
form.

## Block C - Console hotspot network inventory

Run only if approved.

Record before changing application settings:

- [ ] Workstation SSID and IP on `IMT-Aquatic-drone`.
- [ ] Default route and gateway; expected hotspot gateway from prior evidence is `192.168.43.1`.
- [ ] QGC comm-link list and whether a real vehicle appears.
- [ ] QGC selected vehicle before any Plan View or video interaction.
- [ ] Whether Herelink console QGC / Solex / Herelink video app is running.
- [ ] Whether MAVLink forwarding / video sharing / RTSP server is enabled on the console, using the exact UI wording shown.
- [ ] Whether workstation can still reach the repo / internet. Treat missing internet and blank map tiles as expected on this local link.

No Generate / Confirm, Upload, arm/disarm, mode, param, or control action in this block.

Closure note: partial Block C evidence was captured in
`block_c_network_inventory.txt` and summarized below; exact QGC / console UI
wording was not fully captured, so the scaffold boxes remain unchecked.

## Block D - Console video path observation

Run only if approved after Block C.

Goal: prove or reject the console video path before touching the dashboard.

Evidence to capture:

- [ ] Identify the actual video source. Do not assume the stream is Pi RealSense unless the console / video settings prove that source.
- [ ] Direct RTSP result from the workstation, using the known-good style:

  ```text
  rtsp://<console-hotspot-ip>:8554/fpv_stream
  ```

- [ ] QGC video source setting and whether QGC shows video with `Source = Herelink Hotspot`.
- [ ] Whether direct RTSP and QGC video work at the same time or contend.
- [ ] Whether starting a Pi-side ROS camera publisher breaks console video, repeating the 13/05 consumer-exclusivity concern.
- [ ] Latency / stability notes: visible delay, freezes, reconnects, or decode warnings.

Interpretation rules:

- Direct RTSP working proves the workstation can receive console video. It does not prove dashboard integration.
- QGC video working proves QGC's video receiver path. It does not prove dashboard integration.
- The current dashboard camera panel consumes MJPEG from `web_video_server` for ROS image topics. It cannot display arbitrary RTSP directly without an approved adapter or dashboard change.

Candidate next designs, only after evidence:

- Decode console RTSP on the workstation into a ROS image topic, then let `web_video_server` serve that topic to the existing dashboard panel.
- Add a separate MJPEG proxy for the RTSP stream and update dashboard camera handling only if explicitly approved.
- Leave QGC as the operator video viewer and keep the dashboard for telemetry/map until a safe adapter is designed.

Closure note: Block D evidence was captured in `block_d_ffplay_tcp.txt` plus
the earlier UDP terminal paste and summarized below. The checklist remains
unchecked because QGC simultaneous/contended-viewer details were not fully
captured.

## Block E - Console MAVLink to ROS 2 telemetry observation

Run only if approved after Block C. Keep this separate from Block D.

Goal: determine whether the workstation can receive real MAVLink telemetry from the console hotspot and translate it into ROS 2 topics for future dashboard/remap work.

Evidence to capture:

- [ ] QGC proves MAVLink telemetry over the console link without upload/control actions.
- [ ] Identify the MAVLink endpoint shape visible from the workstation:
  - UDP port(s), usually around `14550` / dynamic QGC ports;
  - real vehicle system id;
  - whether the link is QGC-only, forwarded, or available to a separate MAVLink consumer.
- [ ] Decide whether a separate read-only consumer can connect without disturbing QGC:
  - MAVProxy router;
  - MAVROS on workstation;
  - MAVROS on Pi 5 with DDS to workstation;
  - no parallel consumer possible without changing console forwarding.
- [ ] If MAVROS is launched, pass criteria are read-only:
  - `/mavros/state connected: true`;
  - live `/mavros/imu/data`;
  - live GPS topic, even if no fix;
  - battery / status topic if available.
- [ ] Record QoS for live topics before using dashboard or rosbridge:
  - `ros2 topic info --verbose /mavros/imu/data`;
  - `ros2 topic info --verbose /mavros/global_position/raw/fix`;
  - any camera-decoded ROS topic if Block D creates one later.

Expected-open, not regressions:

- GPS no-fix.
- EKF GPS-config warning.
- `system_status: 5`.
- empty `/mavros/rc/in` channels.
- FCU request/response timeouts.

Flag only new failures:

- no heartbeat / no QGC telemetry;
- `/mavros/state connected: false` after a known-good endpoint is selected;
- console video works but MAVLink path is invisible to all workstation tools;
- parallel MAVLink consumer disrupts QGC or the real vehicle link.

Closure note: Block E evidence was captured in `block_e_udp_inventory.txt` and
the later `block_e_mavlink_udp_packets.txt` addendum. MAVLink transport and
sender shape were proven, but MAVROS was not launched and live ROS 2 topic QoS /
rate was not captured, so the scaffold boxes remain unchecked.

## Block F - Other ROS 2 topic replacement prerequisite check

Run as inspect-only first. Code/config edits require explicit approval.

Goal: list exactly what must exist before replacing simulation `/wamv/*` topics in the dashboard and navigation stack.

Current sim-facing contract to preserve unless an adapter is approved:

| Sim topic / surface | Real candidate | Monday check |
| --- | --- | --- |
| `/wamv/sensors/gps/gps/fix` | `/mavros/global_position/raw/fix` or `/mavros/global_position/global` | message type, QoS, rate, fix status, frame/coordinate interpretation |
| `/wamv/sensors/imu/imu/data` | `/mavros/imu/data` | message type, QoS, rate, orientation validity, frame id |
| `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | console-decoded ROS image topic, if created later | source identity, frame rate, latency, web_video_server compatibility |
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | no proven real LiDAR topic yet | keep as open prerequisite |
| `/wamv/thrusters/left/thrust`, `/wamv/thrusters/right/thrust` | no approved real write path | leave out of scope; do not map or publish |
| dashboard mission / config / command topics | existing `/planning/*` sim/planner topics | no real-FCU use; no command/write validation |

Checklist:

- [x] Inventory current dashboard subscriptions / publishers in `web_dashboard/autoboat/app.js`.
- [x] Inventory navigation-node `/wamv/*` dependencies in `plan/` and `control/`.
- [x] Compare against `launch/remap.launch.yaml` Layer A / Layer B notes.
- [ ] Confirm which real topics exist from MAVROS or a video adapter.
- [ ] Record runtime topic compatibility: live QoS, nominal rate, and missing fields.
- [x] Classify each replacement as:
  - ready for read-only adapter design;
  - blocked by missing topic;
  - blocked by semantic mismatch;
  - unsafe because it is a command/write path.

Do not implement the adapter in this block.

## 22/06 Block F static source inventory

Inspect-only source pass; no code/config/launch edits and no live ROS graph.

Current consumers / publishers:

- Dashboard camera panel defaults to
  `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`, builds
  `web_video_server` MJPEG URLs as `:8080/stream?topic=<topic>&type=mjpeg`,
  and discovers ROS image topics through rosbridge. It does not consume RTSP
  directly.
- Dashboard read side uses `/wamv/sensors/gps/gps/fix` as
  `sensor_msgs/NavSatFix` plus `/wamv/thrusters/left/thrust` and
  `/wamv/thrusters/right/thrust` as `std_msgs/Float64` feedback.
- Dashboard write side can publish manual zero-thrust / E-stop thrust messages
  to `/wamv/thrusters/*`; do not connect that surface to a real FCU.
- `waypoint_planner` and `waypoint_visualizer` subscribe to
  `/wamv/sensors/gps/gps/fix` with default queue depth `10`.
- `heading_controller` subscribes to `/wamv/sensors/gps/gps/fix` and
  `/wamv/sensors/imu/imu/data` with default queue depth `10`, then publishes
  `/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust`.
- `lidar_perception` subscribes to
  `/wamv/sensors/lidars/lidar_wamv_sensor/points` with
  `qos_profile_sensor_data`.
- `launch/remap.launch.yaml` still describes additive Layer A relays: sensor
  relays run `/wamv/*` to `/sensors/*`, while actuator relays run
  `/actuators/*` to `/wamv/*`. The active stack still consumes `/wamv/*`.

Replacement prerequisites:

| Surface | Real candidate | Must exist before replacement | Static classification |
| --- | --- | --- | --- |
| GPS | `/mavros/global_position/raw/fix` or `/mavros/global_position/global` | `sensor_msgs/NavSatFix`, live QoS, rate, `status.status`, nonzero/fix semantics, frame/coordinate interpretation, and a no-fix guard before feeding navigation consumers | Ready for read-only adapter design on the known Pi MAVROS path; console path still needs Block E proof |
| IMU | `/mavros/imu/data` | `sensor_msgs/Imu`, live QoS, rate, `frame_id`, orientation validity, yaw frame convention, and mounting/ENU interpretation before closed-loop use | Ready for read-only adapter design after live QoS/rate/frame capture |
| Camera | console-decoded ROS image topic, if created later | A ROS `sensor_msgs/Image` or compatible image topic on the workstation, known source identity, rate, latency, and `web_video_server` MJPEG compatibility | Blocked by missing topic for the console path |
| LiDAR | no proven real topic | Real `sensor_msgs/PointCloud2` topic, frame, QoS, rate, range/height semantics compatible with `lidar_perception` | Blocked by missing topic |
| Thrusters | no approved real write path | Proven low-level command contract, safety interlock, bench validation, and explicit write-path approval | Unsafe command/write path; out of scope today |
| Dashboard mission / config commands | existing `/planning/*` sim/planner topics | A deliberate real-FCU command architecture and upload/control validation | Unsafe command/write path for real FCU; out of scope today |

Block F conclusion before live evidence: `/wamv/*` replacement is not a single
switch. GPS and IMU are plausible read-only adapter surfaces once the live
MAVLink-to-ROS source is selected and measured. Console video first needs an
RTSP-to-ROS-image or RTSP-to-MJPEG adapter decision. LiDAR and all command/write
surfaces remain blocked.

## 22/06 Blocks C-D-E live observation result

Run folder:
`/home/ghostzero/Desktop/test_logs_folder/console_hotspot_20260622_1441/`.

Scope stayed observation-only. No QGC Upload, mission upload, arming, mode
change, parameter write, thruster, actuator, real-FCU command path, MAVROS
launch, MAVProxy router, or dashboard mission/thruster use was run. The Pi
RealSense camera node and `rqt_image_view` were started only because the current
Herelink image-transmission setup now forwards the Pi desktop rather than a
direct camera feed.

### Block C - hotspot/network inventory

Evidence: `block_c_network_inventory.txt`.

- Workstation was on `IMT-Aquatic-drone`.
- Workstation interface `wlp147s0` had `192.168.43.160/24`.
- Default route was `192.168.43.1` via `wlp147s0`; neighbor entry for
  `192.168.43.1` was reachable.
- QGroundControl later bound UDP `0.0.0.0:14550` during Block E.
- First paste attempts lost `RUN_DIR`, so `tee` tried to write under `/` and
  failed with permission errors. The run directory was restored and the useful
  artifacts were saved afterward.

### Block D - video path

Evidence: `block_d_ffplay_tcp.txt` plus the earlier terminal paste for the UDP
attempt.

- Direct RTSP from the workstation to
  `rtsp://192.168.43.1:8554/fpv_stream` worked.
- The stream is LIVE555 H.264 High, `1920x1080`, `30 fps`.
- UDP RTSP connected but showed repeated packet-loss / decode-error lines.
- TCP RTSP connected cleanly and is the transport to prefer for this current
  stream.
- The actual video content was the Pi 5 desktop showing `rqt_image_view` /
  ROS camera viewing, not a direct Herelink camera feed.

Interpretation: Herelink RTSP transport to the workstation is proven, but the
current image-transmission setup has regressed for the dashboard goal. It now
requires a Pi-side camera node plus a GUI viewer, then forwards a desktop
screen capture through Herelink RTSP. That adds camera -> ROS -> GUI render ->
desktop capture -> H.264 -> RTSP latency, fixes the stream to the desktop output
shape, and re-enters the 13/05 camera-consumer-exclusivity risk. Do not design a
dashboard adapter around this desktop-capture path. The setup should be raised
with the professor and, if possible, restored to a direct camera-to-Herelink
video path before dashboard integration work.

### Block E - MAVLink observation

Initial evidence: `block_e_udp_inventory.txt`.
Later addendum evidence: `block_e_mavlink_udp_packets.txt`.

- QGroundControl was running and bound UDP `0.0.0.0:14550`.
- QGC telemetry was visible without control actions.
- Repeated `EKF3 waiting for GPS config data` messages appeared; this matches
  the known expected-open GPS/config state.
- Battery/status was visible in QGC, but only a percent-style observation was
  captured. A displayed `100%` battery percentage is not itself a fault because
  prior ArduPilot/MAVROS captures also reported `percentage: 1.0`; the useful
  next datum is battery voltage.
- Selected vehicle sysid, mode, QGC comm-link list, MAVLink forwarding state,
  and separate output/forwarding availability were not captured.
- At the initial Block E snapshot, the optional `tcpdump` had not yet been run.
- MAVROS was not launched, and no ROS 2 `/mavros/*` source was created from the
  console link.

16:07 addendum: packet capture completed while workstation QGC telemetry was
live. The saved file contains 100 packet lines: 90 inbound packets from
`192.168.43.1:52600` to workstation `192.168.43.160:14550`, 5 QGC replies from
`192.168.43.160:14550` to `192.168.43.1:52600`, and 5 QGC replies from
`192.168.43.160:14550` to `192.168.43.1:54804`. The terminal summary reported
100 packets captured and 0 packets dropped by the kernel.

Interpretation: MAVLink transport from the Herelink/console path to workstation
QGC is proven as unicast UDP into QGC's `14550` socket. The remaining MAVLink
problem is forking that stream to a read-only ROS 2 consumer without disturbing
QGC. Because the Herelink gateway is sending unicast to QGC, a second passive
MAVROS bind on `14550` is not a valid duplication strategy. QGC MAVLink
forwarding to a separate local UDP port is the first-choice next test; a
workstation MAVProxy/router stays reserved for cases where QGC forwarding is
insufficient or a later command-capable route is explicitly approved.

### `/wamv/*` replacement readiness after live evidence

- Video: blocked for adapter design until the source is corrected. RTSP
  reachability is good, but the current source is a Pi desktop/rqt screen
  capture, not a clean camera stream.
- GPS/IMU telemetry: still a read-only adapter candidate only after a confirmed
  ROS 2 source exists. Today's evidence proves QGC MAVLink transport but not
  MAVLink -> ROS 2 translation, QoS, rate, frame, or fix status.
- Battery/status: QGC telemetry exists, but voltage was not captured; battery
  percentage alone is not adapter-quality evidence.
- LiDAR: no real topic proven.
- Thrusters / mission / config commands: still unsafe command/write paths and
  out of scope.

## Block G - Optional adapter design, no code unless approved

Start only if Blocks D-F produce enough evidence and the user explicitly asks for design work.

Design questions:

- Should the workstation dashboard receive console video by:
  - RTSP -> ROS image topic -> `web_video_server` -> existing Camera panel;
  - RTSP -> MJPEG proxy -> dashboard camera URL support;
  - QGC-only video viewer for now?
- Should real telemetry reach the dashboard by:
  - MAVROS on Pi 5 -> DDS -> workstation -> adapter;
  - QGC MAVLink forwarding -> workstation MAVROS on a separate local UDP port;
  - MAVROS on workstation consuming a forwarded/router MAVLink port, not QGC's
    occupied `14550` socket directly;
  - MAVProxy router on workstation feeding MAVROS and QGC separately, reserved
    for later if QGC forwarding is insufficient;
  - no dashboard telemetry until a safe topic adapter is written?
- Should the adapter publish `/wamv/*` compatibility topics, or should dashboard/navigation code learn a real-topic mode?
- How will read-only telemetry be separated from any real-FCU write path?

Non-goals:

- No QGC Upload.
- No mission upload.
- No arming / mode / param / actuator writes.
- No dashboard mission or thruster control against the real FCU.
- No combined RealSense + MAVROS co-load on Pi 5 without confirmed dedicated >=5A supply.

## Wrap

- [x] Record which live blocks ran and which stayed deferred.
- [x] Record exact network, console, QGC, and ROS evidence paths.
- [x] Keep video, MAVLink telemetry, and topic-replacement readiness as separate result sections.
- [x] If docs were edited, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-22_monday_console_hotspot_mavlink_video_dashboard.md
  ```

- [x] Run the public-repo visibility sweep before any commit.
- [x] Commit and push diary/docs work on normal internet WiFi.
- [x] End with bounded next steps and no stale completed action.

**Next steps:**

- Raise the current Herelink video-source regression with the professor: restore or identify a direct camera-to-Herelink feed before any dashboard adapter design.
- Test QGC MAVLink forwarding first: keep QGC on `14550`, forward telemetry one-way to a separate local UDP port, then attach workstation MAVROS to that forwarded port.
- Reserve a workstation MAVProxy/router for later only if QGC forwarding is lossy / unavailable or if a command-capable route is explicitly approved.
- Keep the dashboard simulation-first on `/wamv/*`; do not implement a real-topic adapter or map command/write topics until read-only ROS 2 topics are proven.
