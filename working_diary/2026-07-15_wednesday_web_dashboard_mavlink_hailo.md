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
  `424x240x15`) - prefer compressed `image_transport`. A lower runner `OUTRES` is
  not available: `sd` = `640x480` is the floor, since
  `wiki/Hailo_COCO_Overlay_Demo.md:196-197` offers only `sd|hd|fhd` and `:247`
  hard-rejects anything else. Any further reduction must therefore come from the
  bridge (downscale before publish) or from compressed transport, not from a
  runner knob.

### Approach (chosen path plus fallbacks)

- **Option 1 (chosen):** a thin Pi-side `rclpy` node taps the runner's annotated BGR
  frame and publishes `sensor_msgs/Image` (plus a `compressed` variant) on
  `/hailo/overlay/image_raw`. It matches the dashboard camera dropdown's discovery
  filter, but matching is necessary rather than sufficient: discovery is a one-shot
  query fired on the rosbridge connection event (`app.js:526-533`), and Refresh
  calls `updateCameraStream()`, not the discovery. Start the publisher first, then
  connect the browser - or hard-refresh an already-open tab so discovery reruns. It
  reuses the unchanged `web_video_server` and dashboard, so no `app.js` /
  `index.html` edit is needed to test, and the loopback-only, no-new-exposed-port
  posture is preserved. Keep the bridge node
  external (like the runner) unless it is deliberately promoted into an in-repo ROS
  package (which triggers the `package.xml` dependency discipline).
- Fallbacks, each worse: Option 2 (`web_video_server` Pi-side) and Option 3 (a small
  Pi MJPEG / HTTP server) both need editing the hardcoded MJPEG host in
  `buildCameraUrl` and expose a Pi port with no auth; Option 4 (RTSP) needs a
  transcode hop the `<img>` panel cannot render; Option 5 (tail the saved AVI) is a
  lag-tolerant stopgap only.

### Track B Preflight B0 - Workstation Loopback

- Prepared 14/07/2026; not run.
- Workstation-only; no Pi or hardware.
- Separate execution approval required.
- Zero code changes.
- Block A remains the first Pi / hardware action.

Record any run results directly beneath this section.

B0 is designed to validate three things that do not need the Pi: bgr8 ->
`web_video_server` -> dashboard render at the exact `/hailo/overlay/image_raw`
name; the four-cell QoS matrix; and the `148ba2f` dashboard GPS guard over real
rosbridge (so far unit-tested plus a DevTools direct-call smoke that bypassed
ROS, never delivered through a live graph). No dummy publisher is written: stock
`image_tools/cam2image` `0.33.11-1noble` already supplies configurable
dimensions, rate, QoS and animated synthetic frames.

#### B0 prerequisites

```bash
command -v curl || echo "MISSING: sudo apt install curl"
dpkg -l ros-jazzy-image-tools | grep '^ii'
ss -tlnp | grep -E ':(8002|8080|9090)\b' || echo "PORTS FREE - good"
pgrep -af 'rosbridge|web_video_server|serve_dashboard|cam2image|gazebo|gz sim|waypoint_planner' || echo "CLEAN - good"
ss -tlnp | grep -E ':115[0-9][0-9]' || echo "NO DAEMON - good"
```

Abort if a port is already bound or a planner / sim is live; report rather than
kill, because a running sim means the workstation is not in the assumed state.

Do not use `one_click_launch_all/launch_autoboat_complete.sh`: Gazebo is
unconditional (no `--skip-gazebo`) and its `cleanup()` (`:341`) `pkill -9`s
rosbridge, `web_video_server` and `serve_dashboard`, killing this stack. Never
run `web_video_server --help` - it starts a real server
(`wiki/RealSense_Dashboard_Testing.md:11`).

#### B0 environment preamble - every ROS terminal (T1, T2, T3, T4)

Adapted from `wiki/RealSense_Dashboard_Testing.md` W1-W3, with three deliberate
deviations. `ROS_DOMAIN_ID=42` isolates this run from the Pi's domain 12; W1
never exports a domain at all, relying on `~/.bashrc:123`, so this is an added
line rather than an edited one. `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`
replaces the recipe's `SUBNET` (a legal Jazzy value,
`rmw/discovery_options.h:36-37`). `unset ROS_LOCALHOST_ONLY` is kept from the
recipe: it is deprecated in Jazzy, but when enabled it takes precedence and
`ROS_AUTOMATIC_DISCOVERY_RANGE` is ignored outright, so the unset is what makes
LOCALHOST bind.

Ordering is load-bearing. The exports must follow `source ~/.bashrc` (which
re-sets 12 / SUBNET at `:123-124`) and precede the first `ros2` call: the daemon
is keyed by domain alone (42 -> port 11553, 12 -> 11523, never colliding) but
inherits the discovery range at spawn, so a daemon created under SUBNET is
silently reused for two hours.

```bash
source ~/.bashrc
export ROS_DOMAIN_ID=42
export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
unset ROS_LOCALHOST_ONLY

echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "ROS_AUTOMATIC_DISCOVERY_RANGE=$ROS_AUTOMATIC_DISCOVERY_RANGE"
echo "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-unset}"
```

Abort if any terminal echoes `12`, `SUBNET`, or a set `ROS_LOCALHOST_ONLY`. T2
(rosbridge) and T3 (`web_video_server`) need this preamble as much as T1: adapt
only the first terminal and they stay on domain 12, seeing nothing, while the
topic check still passes.

#### B0 T1 - cam2image publisher (new terminal, foreground, long-running)

```bash
ros2 daemon stop
ros2 daemon start

ros2 run image_tools cam2image --ros-args \
  -p burger_mode:=true \
  -p width:=640 \
  -p height:=480 \
  -p frequency:=15.0 \
  -p reliability:=reliable \
  -p history:=keep_last \
  -p depth:=10 \
  -p frame_id:=hailo_overlay \
  -r image:=/hailo/overlay/image_raw
```

Flags that are not obvious, all proven against tag `0.33.11` (the installed
version). `frequency:=15.0` must carry the decimal - the parameter is declared a
double and an int is rejected on type. `history:=keep_last` plus `depth:=10` are
mandatory: the upstream default is `map.begin()->first`, and because
`std::map` sorts keys, `"keep_all" < "keep_last"` makes the real default
KEEP_ALL despite the help text, giving RELIABLE + an unbounded queue.
`-r image:=...` is mandatory because the topic is the relative name `image`;
unremapped it publishes `/image`, which fails the dashboard discovery filter.

`640x480@15` is the stress case: it is the runner's only available floor
(`wiki/Hailo_COCO_Overlay_Demo.md:196-198`, hard-validated to `sd|hd|fhd` at
`:246-247`), and `2026-06-18:52` already records it unstable on this link
(`110.592` Mbps raw bgr8 versus `36.634` Mbps at `424x240`, a 3.02x gap). A
`424x240` dummy would pass a profile the real bridge cannot emit.

Expect `Publishing image #N` incrementing. Abort on `Target resolution must be
at least the burger size (64 x 64)`, which means width / height did not apply.

#### B0 T2 - verification, matrix, GPS (new terminal, one-shot, reused)

Never route these into a busy foreground terminal.

```bash
ros2 topic list | grep '^/hailo/overlay/image_raw$'
ros2 topic info --verbose /hailo/overlay/image_raw
```

Read the `Reliability:` line under `Publishers:` - that is the field proving
publisher QoS. Confirm `History (Depth): KEEP_LAST (10)`; `KEEP_ALL` means the
`history` param did not apply. Expect `Type: sensor_msgs/msg/Image` and
`Publisher count: 1`.

Do not use `ros2 topic hz` as evidence anywhere in B0. Installed Jazzy's
`ros2topic/verb/hz.py` passes `qos_profile_sensor_data` (BEST_EFFORT, depth 5)
and exposes no `--qos-*` flag. A BEST_EFFORT subscriber is compatible with every
publisher, so `hz` reports green in all four matrix cells and proves nothing
about what the dashboard can see.

#### B0 T3 - rosbridge (new terminal, foreground)

Environment preamble first.

```bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml address:=127.0.0.1
```

#### B0 T4 - web_video_server (new terminal, foreground)

Environment preamble first. Watch this terminal during the matrix; its log is
the only positive proof for cell 2.

```bash
ros2 run web_video_server web_video_server --ros-args -p address:=127.0.0.1
```

Expected log: `Waiting For connections on 127.0.0.1:8080`.

#### B0 T5 - dashboard HTTP (new terminal, foreground)

No ROS environment needed: `serve_dashboard.py` imports only `http.server`,
`re` and `sys`, is not a ROS node, and is unaffected by domain.

```bash
cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat
python3 serve_dashboard.py 8002 127.0.0.1
```

#### B0 QoS matrix

Start order is load-bearing: T1 must publish before the browser connects, since
`populateCameraTopicList()` fires once on the rosbridge `connection` event
(`app.js:526-533`) and Refresh calls `updateCameraStream()`, not the discovery.

All four cells return HTTP 200 with byte-identical headers and all four time out
under `--max-time`, because an MJPEG stream never ends and `MjpegStreamer`'s
constructor sends the initial header before any QoS matching occurs. curl's exit
code (28) and status line therefore discriminate nothing. The only signal is the
count of `image/jpeg` parts in the body.

```bash
probe() {  # $1 = label, $2 = extra query string
  curl -s --max-time 8 -o /tmp/mjpeg_$1.bin \
    "http://127.0.0.1:8080/stream?topic=/hailo/overlay/image_raw&type=mjpeg&quality=80$2"
  echo "$1: bytes=$(stat -c%s /tmp/mjpeg_$1.bin) frames=$(grep -ac 'image/jpeg' /tmp/mjpeg_$1.bin)"
}
```

`bytes` near 22 with `frames=0` is no stream; megabytes with dozens of frames is
streaming.

Cell 2 and a genuine failure are indistinguishable by curl - a QoS mismatch and
an absent or misspelled topic give the identical observable, because the header
is sent before the topic is resolved at all. Cell 2 must be proven positively
from T4's log:

```text
New publisher discovered on topic '/hailo/overlay/image_raw', offering
incompatible QoS. No messages will be sent to it. Last incompatible policy:
RELIABILITY_QOS_POLICY
```

T1 emits the mirror line. Absence of that warning with zero frames is a real
failure, not cell 2.

Phase A, RELIABLE publisher (T1 as launched above):

```bash
probe cell1 ""                          # expect frames > 0
probe cell4 "&qos_profile=sensor_data"  # expect frames > 0
```

Phase B: Ctrl+C T1 and relaunch it with `-p reliability:=best_effort`, all else
identical. Re-run `ros2 topic info --verbose` and confirm
`Reliability: BEST_EFFORT` before probing.

```bash
probe cell2 ""                          # expect frames = 0 + QoS warning in T4
probe cell3 "&qos_profile=sensor_data"  # expect frames > 0
```

A `qos_profile` typo does not return 4xx - it logs `Invalid QoS profile %s
specified. Using default profile.` and falls back to RELIABLE, making cell 3
present exactly like cell 2 and yielding a false "sensor_data does not work".
Only `default`, `system_default` and `sensor_data` are accepted; if cell 3 reads
zero frames, grep T4's log for `Invalid QoS profile` first. Restore T1 to
`reliability:=reliable` afterwards.

`qos_profile=sensor_data` is the conditional `app.js:669` patch if the matrix
passes - QoS-compatible with both publisher reliabilities, but it changes
delivery to BEST_EFFORT, so it is a deliberate trade rather than a free fix. It
stays gated on explicit permission.

#### B0 dashboard render check

Open `http://127.0.0.1:8002/index.html` only after T1, T3, T4 and T5 are up. The
dropdown should list `/hailo/overlay/image_raw` (the discovery filter
`app.js:766` matches `/image_raw` at end-of-string). If it is absent, the page
connected before T1 started - hard-refresh rather than debugging DDS. Manual
entry needs the topic typed and then Refresh clicked: there is no Enter handler
(`app.js:730` is a tooltip sync) and Refresh is debounced `2000` ms. Expect
visibly bouncing sprites; a frozen image is a cached frame, not a live stream.

#### B0 GPS guard over rosbridge

Confirm `Publisher count: 0` on `/wamv/sensors/gps/gps/fix` first; a live sim
would race these samples. `status` is a nested `NavSatStatus` whose own field is
also named `status`, so the YAML needs `status: {status: -1}`. An omitted status
defaults to `-2` (STATUS_UNKNOWN) and also renders No fix. Use `-t 10 -r 1`
rather than `--once`: `-w` counts any matching subscription and three repo nodes
already subscribe to this topic, so `--once` can fire before the browser is
listening.

Case (a), plausible coordinates with `status: -1` - must still read No fix:

```bash
ros2 topic pub -t 10 -r 1 /wamv/sensors/gps/gps/fix sensor_msgs/msg/NavSatFix \
  '{header: {frame_id: gps}, status: {status: -1, service: 1},
    latitude: -33.8361, longitude: 151.0697, altitude: 0.0}'
```

Coordinates are the dashboard's own Sydney Regatta datum (`app.js:351-352`), so
the marker falls inside the default viewport. Expect `latitude` and `longitude`
to render exactly `No fix | Pas de position`, with `local-x` and `local-y` at
`N/A`. This would prove the guard keys on status, not coordinates.

Case (b), `0,0` with `status: 0` - must render as a valid fix:

```bash
ros2 topic pub -t 10 -r 1 /wamv/sensors/gps/gps/fix sensor_msgs/msg/NavSatFix \
  '{header: {frame_id: gps}, status: {status: 0, service: 1},
    latitude: 0.0, longitude: 0.0, altitude: 0.0}'
```

Expect `latitude` and `longitude` to render exactly `0.000000°`. This would
promote `app.js:1098`'s "0,0 is a valid location" assertion, and its
`gps_fix.test.js` unit coverage, to end-to-end evidence over rosbridge.

#### B0 cleanup - reverse order of startup

Close the browser tab first (stopping the MJPEG pull and rosbridge socket), then
Ctrl+C T5, T4, T3, T1 in that order, then `ros2 daemon stop` in T2 (which stops
only the domain-42 daemon on `11553`, leaving domain 12 untouched).

```bash
ss -tlnp | grep -E ':(8002|8080|9090)\b' || echo "PORTS FREE - good"
ss -tlnp | grep -E ':11553' || echo "DAEMON STOPPED - good"
pgrep -af 'rosbridge|web_video_server|serve_dashboard|cam2image' || echo "ALL STOPPED - good"
ros2 topic info --verbose /hailo/overlay/image_raw 2>/dev/null | grep 'Publisher count' || echo "TOPIC GONE - good"
cd ~/seal_ws/src/uvautoboat && git status --short --branch
```

#### B0 output to record

The three environment `echo` lines from one ROS terminal; full
`ros2 topic info --verbose /hailo/overlay/image_raw` for both the RELIABLE and
BEST_EFFORT runs; the four `probe` lines; any T4 line containing
`incompatible QoS` or `Invalid QoS profile`; whether the dropdown listed the
topic and the sprites animated; the literal rendered GPS text for cases (a) and
(b); the five cleanup checks; and `git status --short --branch`.

### Track B Blocks (gated - start only on explicit approval)

- Block A: repo guard; on the Pi, read the pinned runner source in the installed
  checkout under `~/hailo_coco_overlay_2026-07-10/hailo-apps/`. Read BOTH files:
  `.../standalone_apps/object_detection/object_detection.py` holds the `visualize()`
  call site, while `.../core/common/toolbox.py` owns `visualize()` itself and the
  annotated BGR frame (local `frame_to_show`). Establish the annotated-frame handoff
  (OpenCV `cv2` loop vs GStreamer pipeline) and whether the CLI already exposes any
  network output. Confirm the checkout SHA and cleanliness first, and re-derive every
  location with `grep -n` in the installed tree: upstream line numbers are not
  authoritative for the installed checkout, which may carry local edits or a
  different SHA. This is the load-bearing unknown.
- Block B (transport half, no runner change): on the Pi publish a dummy
  `sensor_msgs/Image` on `/hailo/overlay/image_raw`; confirm the workstation
  discovers it (`ROS_DOMAIN_ID=12` + daemon restart), `web_video_server` serves it,
  and it streams in the dashboard camera dropdown - validating the whole "new Image
  topic -> dashboard panel" chain with zero code change. Start the Pi publisher
  before connecting the browser, or hard-refresh an already-open tab: discovery is a
  one-shot query on the rosbridge connection event, so a late-started publisher will
  not appear on its own and would otherwise read as a false transport failure.
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

## Block A Status - 15/07/2026 (Runner Frame Handoff Established)

Track B Block A is complete. The pinned runner checkout under the external root
`~/hailo_coco_overlay_2026-07-10/hailo-apps/` was inspected read-only on the Pi. The
checkout is clean at the pinned SHA. Both required tracked sources hash-match the
pinned commit, so those sources are byte-identical and their offsets are
authoritative for this checkout.

```text
runner checkout (hailo-apps, tag 26.03.1)
  891ce701c2ebe239a5d277759eb75a30f76678a9
hailo_apps/python/standalone_apps/object_detection/object_detection.py (313 lines)
  9f8eca7efc139a423459e87e1715bdf7bc42e1e0a1ecd84b628f62e195e22046
hailo_apps/python/core/common/toolbox.py (968 lines)
  c796def8fb99c8337b1ecee64011a2ea4fe099dbe5ea40dff2cd45a2ab848e9d
```

Locations re-derived in the installed checkout:

| Location | Content |
| --- | --- |
| `object_detection.py:177` | `visualize()` call site |
| `toolbox.py:664` | `def visualize(` - the definition |
| `toolbox.py:773` | `cv2.cvtColor(frame_with_detections, cv2.COLOR_RGB2BGR)` -> `output_bgr_frame`, the annotated BGR frame |
| `toolbox.py:775` | `frame_to_show = resize_frame_for_output(` |
| `toolbox.py:788` | `cv2.imshow("Output", frame_to_show)` |
| `toolbox.py:804` | `frame_to_show` passed to the `cv2.resize` at `:803` feeding the writer |
| `toolbox.py:822` | `cv2.imwrite(output_image_path, frame_to_show)` |

**Frame handoff.** The standalone visualization/display/save loop is OpenCV-based;
inference remains HailoRT. The annotated BGR frame exists as a local inside
`visualize()` at `toolbox.py:773`. This resolves the load-bearing unknown the block
was opened to settle.

**CLI surface.** `object_detection.py:42` imports `get_standalone_parser` from
`hailo_apps/python/core/common/parser.py`, so the base flags are declared outside both
required files. The standalone runner exposes network input (RTSP / HTTP source
handling), not network output. UDP and shared-memory sink fragments exist at
`hailo_apps/python/core/gstreamer/gstreamer_helper_pipelines.py:615` and `:629`, but
the search found only their definitions; this does not establish that the pipeline-app
family exposes an integrated streaming path, and the standalone runner does not import
them.

**Bounded claims.** Option 1 is source-feasible, not runtime-proven. The BGR local
establishes that an annotated frame is reachable in-process; it does not establish the
integration. Whether the tap is a hook, callback, or wrapper - and where it attaches -
remains a Block C design choice. `rclpy`, `cv_bridge`, QoS, compression, Wi-Fi
performance, and frame-rate cost all remain unverified.

**Evidence.** The raw A1 transcript (`block_a_a1_output.txt`) remains on the Pi under
the external root; a clean workstation copy via `scp` is pending.

**Gate state.** Block A complete. Block B is the next eligible block and awaits
explicit approval; the transport half must be proven there before the tap is built.
B0, Block C, and Block D remain closed.

## Correction - 15/07/2026 (Track B Throughput Premise)

The `110.592 Mbps`, `36.634 Mbps`, and `3.02x` values at `:262` are computed
nominal raw-pixel payload rates, not measured throughput. The cited 18/06 record
supports only the qualitative finding that `640x480x15` was unstable with long
receive gaps and `424x240x15` was smoother. It records no Mbps measurement or
`bgr8` encoding.

If Block B resumes, it establishes the first synthetic-image link baseline. It
does not reproduce the 18/06 D435I result, because the source and measurement
method differ.

## EOD Live Integration Status - 15/07/2026

The user completed a bounded live diagnostic with the Pi, D435I, Hailo AI
HAT+, and powered control box on `IoT IMT Nord Europe`. In the browser, the
user observed the live stock-COCO Hailo overlay with detection boxes and class
labels while the temporary native MAVROS panel displayed actual control-box
telemetry.

The two browser data paths remained separate:

- Hailo produced the annotated BGR frame, the temporary Pi bridge published
  `/hailo/overlay/image_raw`, and workstation `web_video_server` served the
  browser's MJPEG stream.
- MAVProxy owned `/dev/ttyAMA0:57600` and fanned MAVLink to a minimal MAVROS
  profile. ROS 2 DDS carried `/mavros/state`, raw GPS, IMU, battery, and RC to
  workstation rosbridge, and the browser subscribed to those five topics.

The observed run established simultaneous live rendering and read-only
telemetry delivery. The FCU was connected and disarmed; raw GPS no-fix remains
valid telemetry and is not a transport failure. The D435I had one owner: the
Hailo path ran with `realsense2_camera` stopped. The temporary stream profile
was `240p@10fps`, selected for this diagnostic rather than as an optimized
production setting.

The external Pi helper used for the run is not tracked in this repository. Its
verified workstation copy has SHA-256
`3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce`.
The dashboard implementation also remains an intentional, uncommitted
diagnostic across `app.js`, `index.html`, `style_merged.css`, and
`test/mavlink_telemetry.test.js`.

This result does not establish a full 120-second endurance acceptance because
the final completion and teardown markers were not returned for the record. It
also does not validate any dashboard-to-FCU command or information-write path:
no arming, mode, setpoint, RC override, mission upload, or other control action
was attempted. Block B's synthetic throughput baseline remains incomplete, and
the custom maritime detector accuracy branch remains separate from this stock
COCO integration proof.

## EOD Helper Provenance Correction - 15/07/2026

The SHA-256 at `:799` identifies the current workstation archive at
`~/Desktop/pi_helpers/pi_live_hailo_mavlink_dashboard.sh`: `45,676` bytes with
SHA-256
`3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce`.
It is a later corrected snapshot, not proof that the earlier observed run used
those exact bytes. The service order and browser result remain observed; this
helper revision needs a Pi-side checksum match plus
`PI_SOURCE_WINDOW=COMPLETE` and `TEARDOWN=PASS` from the same run before it is
recorded as runtime-validated. The durable procedure is in
`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`.
