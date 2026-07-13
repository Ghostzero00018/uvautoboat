# Wednesday 15/07/2026 - Web Dashboard Optimization, Live MAVLink Prep, and Hailo-COCO Streaming

## Day Overview

A web-dashboard day, three independently gated tracks, all design / plan-first with
any code edit or live run separately gated. The focus is overall interaction-logic
and user-experience optimization of the dashboard, plus the up-front preparation for
wiring real live sources into it. The maritime dataset-collection design is
intentionally out of scope this week.

- **Track A - web dashboard bug-fix** audits the dashboard for real, reproducible
  interaction / robustness bugs and fixes the confirmed ones - the interaction-logic
  and UX hardening pass.
- **Track B - Hailo-COCO streaming** designs and prototypes streaming the Pi
  Hailo-COCO annotated overlay into the dashboard video panel - the preparation for a
  live camera-detection view.
- **Track C - real MAVLink telemetry prep** maps the dashboard's simulation-first
  topic subscriptions to the real MAVROS topic surface and plans the read-only path
  to show real vehicle state, without a command / write path.

Tracks B and C are the up-front preparation for the same near-term goal: getting the
dashboard ready to consume real live sources - the live MAVLink telemetry topics and
the Hailo-COCO camera-detection overlay - so the integration work that follows lands
on a clean, robust dashboard. No dashboard code edit, live run, or source
integration starts from this diary without a separate gate.

## Track A - Web Dashboard Bug-Fix

### Overview

Audit the web dashboard for real, reproducible bugs and fix the confirmed ones.
The dashboard is a first-class rosbridge publisher / subscriber
(`web_dashboard/autoboat/app.js`, ~4370 lines) plus its DOM (`index.html`), not a
display layer, so trace both the subscribe / callback and the publish directions.
Reading `app.js` and `index.html` surfaced the concrete candidates below; the block
work confirms each against the real message shapes before any edit.

### Starting Context

- Files: `web_dashboard/autoboat/app.js` (all logic), `index.html` (DOM, element
  ids, default input values), `style_merged.css`, and `serve_dashboard.py` (Python
  CSP / HTTP wrapper - do not edit without permission). Dashboard-tunable params are
  mirrored `launch/autoboat.launch.yaml` <-> HTML input <-> `app.js` maps; only
  `PARAM_RANGES` / `PARAM_TO_INPUT_IDS` keys are tunable.
- Reference: `wiki/Common_Issues.md` (MJPEG / `web_video_server` deadlock, stale
  cache) and `wiki/Dashboard_Security.md` (no-auth posture).
- All dashboard-tunable keys already match the launch YAML, so param-name drift is
  not the target - the crash / robustness class is.

### Candidate Bugs To Confirm And Fix

Confirm each against the actual publisher message shape (read the perception /
planning / control node in `plan/*` and `control/*`) before editing; fix only the
confirmed ones with the smallest guard.

1. Unguarded `toFixed` in `updateObstacleStatus` (`app.js:1251-1255`): `minDist`
   (`data.min_distance`) and `data.front_distance` / `left_distance` /
   `right_distance` are dereferenced with `.toFixed(1)` with no guard, and the
   subscriber maps `front_distance := data.front_clear` (`app.js:969`). If
   `/perception/obstacle_info` omits a key or sends `null`, the handler throws
   `Cannot read properties of undefined (reading 'toFixed')` and aborts. Prime
   target - verify the publisher's guaranteed fields, then guard.
2. `best_gap` deref (`app.js:1300`): `data.best_gap.direction.toFixed(0)` is
   guarded only by `if (gapEl && data.best_gap)` (`app.js:1299`); a
   present-but-malformed `best_gap` (missing `direction` / `width`) still throws.
3. Anti-stuck falsy-zero (`app.js:1413`): `data.front_clear ? ...toFixed(1) :
   'N/A'` prints `N/A` when clearance is exactly `0` (obstacle at the hull) instead
   of `0.0m` - `0` is falsy.
4. Bare-id / window-DOM trap: `index.html` has hyphen-free ids (`distance`,
   `latitude`, `longitude`, `logs`, `map`, `state`, `urgency`, `waypoint`) that
   auto-create `window` globals; a future bare reference silently binds to the DOM
   node (the classic `<var>.toFixed is not a function`). No active collision today -
   decide whether to rename to hyphenated ids or just document the trap.
5. Dead code (`app.js:3545`): `const originalInit = window.onload;` is assigned and
   never used - safe removal.
6. Likely not code bugs, confirm before touching: the MJPEG stale-socket after a
   `web_video_server` restart (`app.js:615-662`) is a browser-socket artifact -
   check a fresh tab first; the one-way perception / controller config sync
   (`app.js:1787`) and the dual-mapped `min_safe_distance` (`app.js:3448`) are
   likely intentional.

### Track A Blocks (gated - start only on explicit approval)

- Block A: repo guard; read `app.js`, `index.html`, the perception / planning /
  control publishers, and the two wiki references; record the guaranteed message
  fields per subscribed topic.
- Block B: for each candidate, reproduce or prove the failure path against the real
  message shape; drop the ones that cannot actually fire.
- Block C: fix the confirmed bugs with the smallest guard (red-green where a JS test
  harness is practical); no init rewrite, no param promotion.
- Block D: live re-check on the workstation stack (Gazebo + ROS 2 + rosbridge +
  `web_video_server` + `serve_dashboard.py`, user-run) with a browser hard-refresh;
  confirm the fixed handlers no longer abort and untouched panels are unchanged.

### Track A - Boundaries And Non-Claims

- JS / HTML edits require confirming the real defect first; no speculative
  refactors, no init rewrite, no param promotion without operational evidence.
- No `serve_dashboard.py` (Python) or launch YAML edits without explicit
  permission; the security posture (0.0.0.0 bind, no auth, direct thrust publish) is
  flagged, not in scope for this bug-fix pass.
- Live dashboard verification is user-run on the Linux workstation.

**Track A next steps:** On approval, start Block A - read the dashboard plus the
publishers and record the guaranteed fields, then confirm each candidate before any
fix.

## Track B - Hailo-COCO Dashboard Streaming

### Overview

Design and prototype streaming the Pi Hailo-8L stock-COCO annotated overlay (the
10/07 Track 2 work) into the dashboard's existing video panel. That panel is a plain
MJPEG `<img id="camera-image">` (`index.html:890`) fed by `web_video_server`
(`http://<host>:8080/stream?topic=...&type=mjpeg`, built in `buildCameraUrl`,
`app.js:664`), and its camera-topic dropdown auto-discovers any `sensor_msgs/Image`
topic matching `/image_(raw|rect|color|compressed)` over rosbridge. The Hailo runner
is external / non-ROS, owns `/dev/video4` directly, and only writes annotated frames
plus an AVI - no ROS topic, no network output. The gap is a bridge from the runner's
annotated frames to a ROS image topic the existing `web_video_server` path already
consumes.

### Starting Context

- Proven camera -> dashboard path (`wiki/RealSense_Dashboard_Testing.md`): a Pi ROS
  image topic -> cross-machine DDS (`ROS_DOMAIN_ID=12`, discovery range `SUBNET`,
  workstation `ros2 daemon` restart) -> workstation `web_video_server` (bind
  `127.0.0.1:8080`) -> dashboard `<img>`. Reuse this exactly.
- Runner contract: `wiki/Hailo_COCO_Overlay_Demo.md` (non-ROS, env-stripped,
  single-owner `/dev/video4`, `--save-output` to `output/live/<RUN_ID>/`).
- The D435I is single-owner, so `realsense2_camera` and the Hailo runner cannot
  co-run; the annotated frames must originate from the runner.
- Raw `Image` at `640x480@15` over WiFi is heavy (the RealSense feed had to drop to
  `424x240x15`) - prefer compressed `image_transport` and / or a lower runner
  `OUTRES`.

### Approach (chosen path plus fallbacks)

- **Option 1 (chosen):** a thin Pi-side `rclpy` node taps the runner's annotated BGR
  frame and publishes `sensor_msgs/Image` (plus a `compressed` variant) on
  `/hailo/overlay/image_raw`. It auto-appears in the dashboard camera dropdown
  (matches the discovery filter) and reuses the unchanged `web_video_server` and
  dashboard, so no `app.js` / `index.html` edit is needed to test, and the
  loopback-only, no-new-exposed-port posture is preserved. Keep the bridge node
  external (like the runner) unless it is deliberately promoted into an in-repo ROS
  package (which triggers the `package.xml` dependency discipline).
- Fallbacks, each worse: Option 2 (`web_video_server` Pi-side) and Option 3 (a small
  Pi MJPEG / HTTP server) both need editing the hardcoded MJPEG host in
  `buildCameraUrl` and expose a Pi port with no auth; Option 4 (RTSP) needs a
  transcode hop the `<img>` panel cannot render; Option 5 (tail the saved AVI) is a
  lag-tolerant stopgap only.

### Track B Blocks (gated - start only on explicit approval)

- Block A: repo guard; on the Pi, read the pinned runner source
  (`~/hailo_coco_overlay_2026-07-10/hailo-apps/.../object_detection.py`) to find the
  annotated-frame handoff (OpenCV `cv2` loop vs GStreamer pipeline) and whether its
  CLI already exposes any network output. This is the load-bearing unknown.
- Block B (transport half, no runner change): on the Pi publish a dummy
  `sensor_msgs/Image` on `/hailo/overlay/image_raw`; confirm the workstation
  discovers it (`ROS_DOMAIN_ID=12` + daemon restart), `web_video_server` serves it,
  and it auto-appears and streams in the dashboard camera dropdown - validating the
  whole "new Image topic -> dashboard panel" chain with zero code change.
- Block C: build the Option-1 frame tap (or wrapper) that publishes the runner's
  real annotated frames at a WiFi-friendly resolution / compressed transport,
  without disturbing the runner's env, camera ownership, or thermal budget.
- Block D: bounded, temperature-guarded live run; confirm the annotated overlay
  renders live in the dashboard panel; copy an evidence frame back.

### Track B - Boundaries And Non-Claims

- Reuse the proven ROS / `web_video_server` path; keep the bridge node and all Hailo
  artifacts outside the public repo (established boundary).
- Option 1 needs no repo code change to test; any `app.js` / `serve_dashboard.py`
  change (Options 2-4) is separately gated on explicit permission.
- Preserve the loopback-only, unauthenticated posture - the chosen path exposes no
  new Pi port on the WiFi.
- Never run `realsense2_camera` and the Hailo runner against the D435I at the same
  time; live runs are user-run from a Pi desktop session with the thermal watchdog.
- Stock-COCO overlay only; not maritime / custom-detector recovery, and not a
  `vision_msgs/Detection2DArray` structured-detection track.

**Track B next steps:** On approval, start Block A - read the runner source for the
frame handoff, then prove the transport half (Block B) before building the tap.

## Track C - Real MAVLink Telemetry Prep

### Overview

Prepare the dashboard to consume real vehicle telemetry from live MAVLink. This
inherits the 05/06 Block H decision
(`working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md`): the real
adapter is an external read-only relay that republishes MAVROS telemetry onto the
dashboard's **existing `/wamv/*` consumer topics** under a real-adapter-on /
simulation-source-off flag - not a dashboard resubscribe to `/mavros/*`, and not a new
neutral `/sensors/*` layer (that stays later preparatory plumbing). Design /
plan-first and strictly read-only: no `app.js` edit, no command / write path.

### Starting Context

- The dashboard subscribes to simulation `/wamv/*` topics over rosbridge and does
  **not** subscribe to `/mavros/*`; the 05/06 Option B path therefore relays real
  MAVROS -> existing `/wamv/*` topics rather than changing dashboard subscriptions.
- Same-family mappings already worked out on 05/06 (re-confirm the live message shapes
  before implementing):
  - GPS: `/mavros/global_position/raw/fix` -> `/wamv/sensors/gps/gps/fix`
    (`sensor_msgs/NavSatFix`), keeping the **no-fix guard** - `raw/fix` publishes the
    `status: -1` no-fix state; `/global` stays out until a real fix publishes.
  - IMU: `/mavros/imu/data` -> `/wamv/sensors/imu/imu/data` (`sensor_msgs/Imu`),
    same message family, relay only.
  - Thruster / command: **not mapped** - the low-level command path is unvalidated
    (04/06 request/response timeouts); no thrust bridge.
- Transport / domain (proven bench topology): on the Pi, MAVProxy owns
  `/dev/ttyAMA0:57600` and fans out to `udpout:127.0.0.1:14550`; Pi-local MAVROS
  consumes `udp://127.0.0.1:14550@`. An optional `14551` leg remains passive
  inspection only. QGC / Herelink are not part of this dashboard track and stay
  stopped. On the ROS side, Pi MAVROS, workstation rosbridge, `web_video_server`,
  the external adapter, and the dashboard checks must **all share
  `ROS_DOMAIN_ID=12`** so the MAVROS topics cross DDS to the workstation graph.

### Track C Blocks (gated - start only on explicit approval)

- Block A - review the existing mapping: re-read the 05/06 Option B mapping table and
  confirm the current live message shapes for `/mavros/global_position/raw/fix`,
  `/mavros/imu/data`, and `/mavros/state` (guaranteed fields, no-fix behavior) against
  a live MAVROS graph; record any drift from the 05/06 mapping.
- Block B - transport / domain: with QGC / Herelink stopped, bring up the proven
  Pi-local path `/dev/ttyAMA0:57600 -> MAVProxy -> udpout:127.0.0.1:14550 ->
  MAVROS`; keep Pi MAVROS, workstation rosbridge, and the dashboard on
  `ROS_DOMAIN_ID=12`, then confirm the workstation sees the real MAVROS topics in
  the same graph as the dashboard. No adapter yet.
- Block C - implementation gate (explicit): with simulation `/wamv/*` publishers
  **off**, start the external read-only adapter that relays MAVROS -> the existing
  `/wamv/*` consumer topics (GPS with the no-fix guard, IMU relay). For this
  dashboard-only validation, keep the simulation publishers and all non-dashboard
  `/wamv/*` consumers (`heading_controller`, `waypoint_planner`, and
  `waypoint_visualizer`) stopped, and verify that no FCU command / write bridge is
  running - so only MAVROS, the external adapter, rosbridge, and the dashboard remain.
  Publishing real telemetry onto `/wamv/*` would otherwise wake those planner /
  controller / visualizer consumers and could emit ROS-side thrust output even with no
  real FCU bridge. External and gated; neutral `/sensors/*` stays later plumbing.
- Block D - dashboard display validation: user-run; **view only the telemetry panels**
  (no-fix GPS state and IMU) with the adapter on and the sim source off. Do **not**
  operate Start / Resume / Stop / E-stop / manual-thrust / mission controls - the
  dashboard is itself a first-class ROS publisher (mission-command `app.js:1062`,
  direct-thrust `app.js:2517`), so its controls can still publish command / thrust
  messages even with no real FCU bridge to receive them. Watch
  `/planning/mission_command`, `/wamv/thrusters/left/thrust`,
  `/wamv/thrusters/right/thrust`, and `/planning/emergency_stop`; stop immediately if
  any new message appears. Then restore the sim default. Record the
  bounded claim as: telemetry rendered, no real actuator / FCU effect, and no
  command-topic publish observed this session.

### Track C - Boundaries And Non-Claims

- Read-only telemetry only: no command / write / setpoint / arm / mode / parameter /
  thruster / actuator path from this track (the command path stays unvalidated).
- The adapter is external and gated; no `app.js` / dashboard code change - it feeds
  the existing `/wamv/*` consumer topics, so the dashboard needs no edit to test.
- Real-adapter-on and simulation-source-off are mutually exclusive: do not run both
  publishers onto `/wamv/*` at once, and restore the simulation default after the test
  (no-regression).
- Dashboard-only isolation during the validation: no planner / controller / visualizer
  (`heading_controller`, `waypoint_planner`, `waypoint_visualizer`) and no FCU command
  / write bridge runs while the adapter publishes to `/wamv/*`. The dashboard itself
  remains a ROS command / thrust publisher (mission-command / direct-thrust, per
  `wiki/Dashboard_Security.md`), so there is no *real* actuator / FCU effect (no bridge
  receives commands), but the operator must not touch the command controls - see
  Block D.
- QGC, Herelink, mission sync, and upload remain out of scope and stopped; this is
  dashboard read-only telemetry prep only.

**Track C next steps:** On approval, start Block A - re-confirm the 05/06 Option B
mapping and the live message shapes before the transport bring-up.

**Next steps:** Pick a track and get explicit approval to start its Block A -
Track A (dashboard bug-fix), Track B (Hailo -> dashboard streaming), or Track C
(real MAVLink telemetry prep). All three are design / plan-first and separately
gated.

## Early-Preparation Addendum - 13/07/2026

A 13/07/2026 source-only preflight (no live run, no hardware access to the
control-unit box) reviewed the dashboard and the active publishers. It supersedes
the stale executable steps in the blocks above where noted; the original plan text
is retained unchanged. Full evidence:
`working_diary/2026-07-13_to_2026-07-14_vacation_sidework_dashboard_preflight.md`.

- Track A: of the listed candidates, only the dead assignment `const originalInit
  = window.onload;` (`app.js:3545`) is a real - and inert - defect; its removal and
  any defensive `!= null` guards are deferred, with no current runtime benefit
  under the active publisher contract. The `toFixed` crash candidates cannot fire:
  the perception distance fields are explicitly finite by construction
  (`lidar_perception.py:892-907`), `best_gap` is null-or-complete (`:868-878`), and
  the anti-stuck `front_clear` is bounded away from zero by the range and hull
  self-filter (`lidar_perception.py:461-482`) plus the clearance computation
  (`:796-804`), independent of the runtime-tunable `min_range`. Item 6 stays open
  as UX limitations, not crashes: MJPEG recovery is conditional on the `<img>`
  error event, so a silent stream freeze needs a manual refresh; and the one-way
  config sync (`app.js:1787`) shows no live controller values/controls because
  `/planning/config` carries planner state only (`waypoint_planner.py:864-887`).

- Track B: the dashboard is source-compatible with a new `/hailo/overlay/image_raw`
  (and `/compressed`) topic with no dashboard edit - discovery filter (`app.js:766`),
  `buildCameraUrl` (`:664-670`), and the manual-entry fallback (`:645-650`). Block
  B's dummy-topic transport test and Block C's bridge are unrun; the dummy publisher
  and the frame-tap bridge are drafted only, not persisted or proven. The
  load-bearing unknown remains the runner's annotated-frame handoff, which needs Pi
  access. This supersedes the "publish a dummy `sensor_msgs/Image`" executable step
  in Block B as drafted-not-run.

- Track C: Block D's criterion "view only the telemetry panels (no-fix GPS state
  and IMU)" is not achievable as written - the dashboard has no IMU subscription or
  panel, and `updateGPS` (`app.js:1098-1146`) reads lat/lon only and never
  `NavSatFix.status`, so a no-fix `0, 0` sample would render as a valid position. It
  is replaced by:
  1. Relay-plumbing validation (CLI `ros2 topic echo`): confirm
     `/mavros/global_position/raw/fix` -> `/wamv/sensors/gps/gps/fix` (valid fix
     forwarded, `status < 0` suppressed) and `/mavros/imu/data` ->
     `/wamv/sensors/imu/imu/data`, with the simulation `/wamv/*` publishers off and
     no command / write bridge running.
  2. Valid-fix GPS display: with a valid `NavSatFix` on
     `/wamv/sensors/gps/gps/fix`, the existing lat/lon panel and marker render
     correctly - already supported today.
  3. Separately gated dashboard UI additions (explicit approval, not this pass): an
     IMU subscription plus panel, and a `NavSatFix.status` guard / render in
     `updateGPS` that catches the `0, 0` no-fix case. Resolve the adapter's no-fix
     policy (drop versus hold-last) together with this render.

The external MAVROS adapter and the Hailo bridge remain gated; only a Track B dummy
publisher may be materialized first, and only once an exact external path is
approved.

## Implementation Status - 13/07/2026

Track C item G1 (the dashboard `NavSatFix.status` guard) is implemented and
unit-tested locally in `web_dashboard/autoboat/app.js` (with
`web_dashboard/autoboat/test/gps_fix.test.js`, 10/10 `node:test`): `updateGPS`
rejects a sample unless `status.status >= 0` with finite coordinates, so a no-fix
`0, 0` no longer renders as a valid position while a real `0, 0` fix is still
accepted. Not live-run. The matching planner-side guard is still open -
`waypoint_planner.py` `gps_callback` (:419) treats the first no-fix sample as
GPS-ready and anchors the origin at `0, 0` - and is the recommended next block.
Full record:
`working_diary/2026-07-13_to_2026-07-14_vacation_sidework_dashboard_preflight.md`.

## Implementation Status - 13/07/2026 (Planner Guard Landed)

The planner-side guard is now implemented and unit-tested locally too:
`waypoint_planner.py` `gps_callback` (:419) returns early unless
`msg.status.status >= 0` with finite coordinates, so a no-fix first sample no
longer anchors the mission origin at `0, 0` or reports GPS-ready (7 focused tests;
full `plan/test` 9 passed + 1 skip; not live-run). This closes the
dashboard/planner GPS-readiness contradiction. One bounded residual stays open: the
30 s force-ready fallback in `publish_mission_status` (:1466) can still publish a
misleading `gps_ready` after a timeout without initializing the origin.

## Validation Status - 13/07/2026 (Dashboard DOM Smoke)

Clarifying "Not live-run" above for the dashboard side: the GPS no-fix guard was
browser-executed on 13/07/2026 as a direct-call DOM smoke (console `updateGPS`
calls), but NOT ROS/topic-replayed - rosbridge was absent, so this is not
end-to-end. The log confirms the wrapper loaded (`typeof updateGPS` is
`"function"`), the return sequence `false -> true -> true -> false` (valid `0, 0`
accepted, no-fix rejected), and a final `hasFix: false` / `baseline: null`. The
rendered panel text and expanded `stored` / `marker` coordinates were not captured
and remain unit-test evidence. Planner side unchanged: source-tested only,
Pipeline 3 deferred. Baseline clean at HEAD `7fd0357`.

## Validation Status - 13/07/2026 (Planner Live-Node Replay)

Superseding "Pipeline 3 deferred" above: the planner GPS no-fix guard is now
live-node validated (Pipeline 3, workstation-only, isolated `ROS_DOMAIN_ID=112`).
All four phases passed against the installed 7fd0357 source - initial no-fix
rejected (`gps_ready: false`, null origin), valid `0, 0` accepted (`start 0.0/0.0`,
one acquisition), position updated without moving the origin, and a later no-fix
held the last valid position `[22.24, 11.12]` with no re-acquisition. Endpoint QoS
was RELIABLE / VOLATILE with History depth UNKNOWN on the subscription side, so
depth 10 is not live-proven. The 30 s force-ready fallback was not triggered and
remains separately open. A low-severity post-test shutdown defect
(`waypoint_planner.py:1544` catches only `KeyboardInterrupt`, then `finally` calls
`rclpy.shutdown()` after an external shutdown already ran) is recorded and deferred.
Full record:
`working_diary/2026-07-13_to_2026-07-14_vacation_sidework_dashboard_preflight.md`.

## Fix Status - 14/07/2026 (Planner Residuals Resolved)

Both residuals above are now fixed and verified (unit + domain-112 live),
superseding their open/deferred status. `publish_mission_status` derives readiness
from `start_gps` and no longer force-sets `gps_ready` on timeout (the forced value
had no navigation consumer; backend, CLI, QGC bridge, and dashboard all use
`start_gps`/`/planning/config`), and `main()` catches `ExternalShutdownException`
and uses the idempotent `rclpy.try_shutdown()`. Red-green unit tests + full
`plan/test` 13 passed / 1 skip + rebuild + an isolated domain-112 live replay
(readiness stays false past 30 s, true on a real fix; clean SIGINT shutdown, no
traceback, no orphan) all pass. Full record:
`working_diary/2026-07-13_to_2026-07-14_vacation_sidework_dashboard_preflight.md`.
