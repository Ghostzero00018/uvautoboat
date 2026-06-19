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

- [ ] Run:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If fetch fails while still on normal internet WiFi, stop and report.
- [ ] If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- [ ] If ahead, diverged, or dirty, stop and report before continuing.
- [ ] Re-read:
  - `working_diary/2026-06-19_friday_dashboard_hygiene_camera.md`
  - `working_diary/2026-06-18_thursday_block_c_attribution_followup.md`
  - `working_diary/2026-06-17_wednesday_block_c_mixed_topology_observation.md`
  - `wiki/Common_Issues.md` Herelink / QGC video section
  - `wiki/Pi5_Bringup_Smoke_Test.md`
  - `wiki/RealSense_Dashboard_Testing.md`
  - `web_dashboard/autoboat/README_autoboat_dashboard.md`
  - `Board.md` MAVROS, RealSense, QGC / Herelink rows
  - `wiki/Roadmap.md` Phase 5 rows for MAVROS, RealSense, QGC / Herelink, and `/wamv/*` topic adaptation

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

- [ ] Inventory current dashboard subscriptions / publishers in `web_dashboard/autoboat/app.js`.
- [ ] Inventory navigation-node `/wamv/*` dependencies in `plan/` and `control/`.
- [ ] Compare against `launch/remap.launch.yaml` Layer A / Layer B notes.
- [ ] Confirm which real topics exist from MAVROS or a video adapter.
- [ ] Record message type compatibility, QoS compatibility, nominal rate, and missing fields.
- [ ] Classify each replacement as:
  - ready for read-only adapter design;
  - blocked by missing topic;
  - blocked by semantic mismatch;
  - unsafe because it is a command/write path.

Do not implement the adapter in this block.

## Block G - Optional adapter design, no code unless approved

Start only if Blocks D-F produce enough evidence and the user explicitly asks for design work.

Design questions:

- Should the workstation dashboard receive console video by:
  - RTSP -> ROS image topic -> `web_video_server` -> existing Camera panel;
  - RTSP -> MJPEG proxy -> dashboard camera URL support;
  - QGC-only video viewer for now?
- Should real telemetry reach the dashboard by:
  - MAVROS on Pi 5 -> DDS -> workstation -> adapter;
  - MAVROS on workstation consuming console MAVLink directly;
  - MAVProxy router on workstation feeding MAVROS and QGC separately;
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

- [ ] Record which live blocks ran and which stayed deferred.
- [ ] Record exact network, console, QGC, and ROS evidence paths.
- [ ] Keep video, MAVLink telemetry, and topic-replacement readiness as separate result sections.
- [ ] If docs were edited, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-22_monday_console_hotspot_mavlink_video_dashboard.md
  ```

- [ ] Run the public-repo visibility sweep before any commit.
- [ ] Commit and push diary/docs work on normal internet WiFi.
- [ ] End with bounded next steps and no stale completed action.
