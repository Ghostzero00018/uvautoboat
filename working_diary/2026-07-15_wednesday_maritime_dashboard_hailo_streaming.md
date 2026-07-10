# Wednesday 15/07/2026 - Maritime Design, Dashboard Fixes, and Hailo Streaming

## Day Overview

Three independently gated tracks today, each design / plan-first, with any code
edit, capture, training, or live run separately gated. **Track A** is the maritime
dataset-collection design in the sections through its own Explicit Non-Claims
below. **Track B** audits the web dashboard for real bugs and fixes the confirmed
ones. **Track C** designs and prototypes streaming the Pi Hailo-COCO annotated
overlay into the dashboard video panel.

Turn the 09/07 proxy result into a concrete maritime data-collection design. The
proxy already answered the mechanical question: the real-image loop
capture -> label -> split -> train -> held-out evaluation runs end to end. Its
weak fixed-threshold result is consistent with a data-distribution problem:
about 30 near-duplicate, single-scale images produced a detector that was
confident nowhere at a usable threshold and blind to the held-out scale. This
diary designs the maritime dataset so the same, already-frozen training loop can
be tested on real held-out maritime frames.

Default mode is design only. A bounded camera-only live rehearsal may run only
after explicit approval, and only to check RealSense capture logistics and
near / mid / far framing. No labeling, training, detector execution, Hailo work,
deployment, or command-path work starts from this diary without a separate gate.
This is not another bottle-model recovery pass; the optional proxy below is a
logistics rehearsal only.

## Carry-Over From 09/07

- The loop is mechanically valid; the leading failure hypothesis is the dataset
  distribution, not a proven pipeline defect.
- Even large `val` objects fired only around `0.016`; held-out `tier3_eval`
  (tiny) sat at background level around `0.007` with mAP50 `0.0`.
- Leading hypothesis: too few distinct examples (weak confidence everywhere)
  plus a single dominant object scale (no far/small generalization).
- Fixes carried into this design:
  1. materially more genuinely distinct examples per class, not more frames of
     one static scene;
  2. train/val scale coverage that spans the held-out distance range;
  3. held-out that stays scene- and placement-disjoint;
  4. a usable-threshold firing gate, not the `~0.003` floor or the `0.01` band.
- The frozen training config (`yolo26n.pt`, `imgsz=640`) is proven. This cycle
  changes the data, not the model, with training `imgsz` kept as an explicit
  small-object knob to decide (higher `imgsz` helps far/small at a batch / VRAM
  cost on the 6 GB RTX A3000).

## Target Classes And Minimum Per-Class Counts

Class map and first-pass label / do-not-label rules stay as defined in
`wiki/YOLO_Dataset_Plan.md`. Current reality: `9` labeled instances, all
`person`; `buoy`, `vessel`, `dock`, and `obstacle` have zero examples. The
dataset plan's sizing target is hundreds of labeled instances per active class;
do not repeat the 9-box pilot.

Fill per-bucket targets at manifest time before any capture:

| ID | Class | Current | Near | Mid | Far | Per-class target | Primary source |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 0 | `buoy` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX bootstrap |
| 1 | `vessel` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX, spawn-required |
| 2 | `dock` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX bootstrap |
| 3 | `obstacle` | 0 | TBD | TBD | TBD | hundreds (see plan) | RealSense / public / world-authoring |
| 4 | `person` | 9 | TBD | TBD | TBD | hundreds (see plan) | RealSense / public |

Distribution rule: no active bucket, and especially `far`, should fall below
about one third of that class total. The `far` bucket was the 09/07 miss and is
the most data-hungry.

## Distance Buckets

Define buckets by apparent object size so collection is measurable, not by feel:

- `near` - object taller than roughly one third of the frame height;
- `mid` - roughly one tenth to one third of frame height;
- `far` - below roughly one tenth of frame height (small, previously-missed
  regime).

Every active class needs coverage in each deployment-relevant bucket. Record the
measured apparent size per scene in the manifest, not just a subjective label.

## Placement, Lighting, Occlusion, Background Variation

Follow the capture protocol in `wiki/YOLO_Dataset_Plan.md` and prioritize
diversity over frame count:

- placement: vary position in frame, spacing, and orientation across scenes;
- lighting: overcast, direct sun, glare, backlight, dusk; on-water reflections;
- occlusion: partial occlusion where the class stays identifiable; skip frames
  where a target is not labelable;
- background: open water, shoreline, dock, vegetation, vessels, clutter;
- negatives: empty / background-only frames at each distance bucket;
- sampling: sparse frames on scene / distance / lighting / orientation change;
  no dense near-duplicate bursts.

## Split Rules

Use the four-way split contract from `wiki/YOLO_Dataset_Plan.md`
(`train` / `val` / `calib_hailo` / `tier3_eval`), assigned at capture / review
time and disjoint at the scene / condition level.

09/07 correction, binding for this cycle:

- `train`, `val`, and `tier3_eval` must span the **same** distance-bucket range,
  so the held-out set is not a scale-extrapolation trap.
- They must still be **scene- and placement-disjoint**, or the held-out only
  measures memorization.
- `tier3_eval` holds at least a few clear positives per active class in each
  active bucket, plus negatives, to record a meaningful held-out confidence
  distribution.

## Source Plan Per Class

Carry the 08/07 acquisition-manifest decisions:

- VRX can bootstrap `buoy`, `vessel` (spawn-required), and `dock`, with a
  domain-gap caveat versus real RealSense input;
- `obstacle` and `person` need real RealSense capture, admitted public data
  (licence and class-map checked), or explicit world / asset authoring; VRX
  `obstacle` / `person` remain unsupported without a separate source decision.

Fill the chosen source per class per bucket in the manifest before capture. Keep
all manifests, images, labels, weights, and runs outside the public repo.

## Pass Gate

This cycle passes only when a checkpoint trained on the new data fires on **real
held-out maritime** frames at a usable threshold:

- record the per-class held-out confidence distribution;
- require firing at `conf >= 0.05`, ideally `conf >= 0.25`, on `val` and
  `tier3_eval`;
- the `~0.003` floor and the `0.01` band do not count as usable firing.

Only after that gate passes should maritime deployment, dashboard integration,
or the Hailo accuracy-grade / Tier 3 path reopen.

## Camera-Only Live Rehearsal Gate

Use this only if a useful live test is wanted on 15/07. It is a camera logistics
test, not detector recovery.

Purpose:

- verify the Pi 5 direct RealSense still-capture route is still healthy;
- check whether the fixed camera placement can produce measurable `near`, `mid`,
  and `far` apparent-size buckets at the intended collection resolution, not
  only at the quick health-check profile;
- decide whether a later real maritime collection can reuse this physical
  camera placement or needs a different mount / distance plan.

Preconditions:

- repo state is clean and synced before starting;
- D435I is the only camera owner;
- no ROS camera launch, dashboard camera panel, `rqt_image_view`, live detector,
  Hailo path, MAVROS, QGC, Herelink, mission upload, arming, mode change,
  parameter write, thruster, or actuator work;
- any stills kept from the rehearsal go outside the repo under a new root such
  as
  `/home/ghostzero/datasets/uvautoboat_maritime_live_rehearsal_20260715/`;
- choose the snapshot resolution before the rehearsal; if the far bucket is the
  question, compare `640x480` against the intended higher collection profile
  rather than judging labelability from `640x480` alone;
- place a reference target of known approximate size in frame for the apparent
  size check, such as the proxy bottle, a person, or a ruler / marked card;
- do not reuse or merge into the 09/07 unicolor smoke dataset.

Minimal live-test sequence:

Use the proven Pi helper's preflight / snapshot flow where possible. A trimmed
camera-only helper is acceptable if it removes object-identity requirements but
keeps one-camera-owner start / stop behavior.

1. Pi preflight only: date, host, IP, thermal readout, camera-owner process
   check, Python import check, D435I identity, and one `640x480@15` stream
   start / stop.
2. One headless snapshot at the intended collection resolution to verify current
   framing and exposure; if that profile cannot start, record the exact blocker.
3. Optional paired-resolution snapshot: repeat the same framing at `640x480`
   and at the intended higher profile to separate placement limits from
   resolution limits.
4. Optional three-distance rehearsal stills: `near`, `mid`, and `far`, with one
   or a few sparse stills per distance after physically changing the object
   distance / placement.
5. Copy snapshots back to the workstation for visual review.
6. Stop. Do not label, train, evaluate, export, or deploy.

What to record if run:

- Pi host, IP, uptime, temperature, and D435I serial / firmware;
- snapshot path(s), copy-back path(s), capture profile(s), and image dimensions;
- whether `near`, `mid`, and `far` were actually visible and labelable from the
  fixed camera placement at the intended collection resolution;
- whether the `far` bucket looks like a capture-resolution problem, a placement
  problem, or both; carry that into the training `imgsz` decision;
- exact blocker if the camera route, framing, thermal state, or copy-back fails;
- bounded non-claim: this proves camera logistics only.

## Optional Proxy Rehearsal

Run only after the camera-only rehearsal shows that the fixed placement and
intended resolution can produce labelable `near`, `mid`, and `far` frames. Keep
it short and explicitly not a recovery pass:

- 10-15 genuinely different scenes per distance bucket, not 12 static frames per
  scene;
- both proxy objects visible in every positive; negatives per bucket;
- purpose is to rehearse the multi-scale capture / label / split logistics, not
  to recover a model.

Skippable. The mechanical loop is already proven, so this adds logistics
practice only.

## Track A - Explicit Non-Claims

- No Hailo compile, calibration, Tier 3, or HEF work.
- No deployment, dashboard integration, MAVROS, QGC, Herelink, mission upload,
  arming, mode change, parameter write, thruster, or actuator path.
- No maritime detector-recovery claim until real held-out maritime firing works
  at a usable threshold.
- No production repo Python / YAML changes; all data and manifests stay outside
  the public repo.
- Default mode is design only; the camera-only rehearsal, any capture beyond
  snapshots, labeling, and training are gated on explicit approval.

**Track A next steps:** Confirm the per-class and per-bucket targets and the source
assignment, decide the training `imgsz` for the far bucket, then either run the
camera-only live rehearsal, run the optional proxy logistics rehearsal, or plan
the real maritime collection when water or VRX access is available.

## Track B - Web Dashboard Bug-Fix

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

### Track B Blocks (gated - start only on explicit approval)

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

### Track B - Boundaries And Non-Claims

- JS / HTML edits require confirming the real defect first; no speculative
  refactors, no init rewrite, no param promotion without operational evidence.
- No `serve_dashboard.py` (Python) or launch YAML edits without explicit
  permission; the security posture (0.0.0.0 bind, no auth, direct thrust publish) is
  flagged, not in scope for this bug-fix pass.
- Live dashboard verification is user-run on the Linux workstation.

**Track B next steps:** On approval, start Block A - read the dashboard plus the
publishers and record the guaranteed fields, then confirm each candidate before any
fix.

## Track C - Hailo-COCO Dashboard Streaming

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

### Track C Blocks (gated - start only on explicit approval)

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

### Track C - Boundaries And Non-Claims

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

**Track C next steps:** On approval, start Block A - read the runner source for the
frame handoff, then prove the transport half (Block B) before building the tap.

**Next steps:** Pick a track and get explicit approval to start its Block A -
Track A (maritime design), Track B (dashboard bug-fix), or Track C
(Hailo -> dashboard streaming). All three are design / plan-first and separately
gated.
