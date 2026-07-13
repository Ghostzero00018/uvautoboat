# Vacation Side-Work Diary 13-14/07/2026 - Dashboard and Live-Source Preflight

## Overview

This is the vacation side-work diary for 13-14/07/2026 - preparation carried out
off the main schedule, ahead of the 15/07/2026 web-dashboard day. No live run and
no hardware: the control-unit box (Pi 5, camera, Hailo-8L, low-level controller)
is not reachable on these days, so every claim below rests on reading
`web_dashboard/autoboat/app.js`, `index.html`, and the active ROS 2 publishers in
`plan/` and `control/`. No code, configuration, or runtime files were edited;
documentation only. The dashboard security posture (bind address, no-auth) is
flagged, not in scope for this pass. Maritime dataset collection stays out of
scope this week.

The 13/07/2026 goal was two-fold: confirm or reject each Track A bug candidate
against the real message shapes, and establish how much Track B (Hailo streaming)
and Track C (MAVLink telemetry) preparation is possible with no hardware. The
record below is the 13/07 source-only preflight; 14/07 continues the same
documentation-and-design side-work and is appended here rather than in a new file.

## Track A - Dashboard Bug Candidates (Source Verdicts)

The dashboard is a first-class rosbridge subscriber, so every candidate was
checked against the guaranteed fields of its actual publisher, not the JS alone.

| # | Candidate | Location | Verdict | Basis |
| --- | --- | --- | --- | --- |
| C1 | Unguarded `toFixed` on obstacle distances | `app.js:1252-1255` | Cannot fire | Distance fields are explicitly finite by construction |
| C2 | `best_gap.direction/.width` sub-deref | `app.js:1300` | Cannot fire | `best_gap` is null-or-complete; null guarded |
| C3 | Anti-stuck falsy-zero (`0` renders `N/A`) | `app.js:1413` | Unreachable | Clearance bounded away from zero by the hull self-filter, not by `min_range` |
| C4 | Bare-id auto-global / DOM trap | `index.html` ids | No active source collision | Every reference is a declared local/param/property |
| C5 | Dead `const originalInit = window.onload` | `app.js:3545` | Confirmed (inert) | Assigned once, read nowhere |
| C6 | MJPEG recovery, one-way config sync | `app.js:615-662`, `:1787` | Open (UX) | Conditional recovery; stale duplicated controls |

### C1 - unguarded obstacle `toFixed`

Cannot fire. The four distance fields `min_distance`, `front_clear`,
`left_clear`, `right_clear` are built as `float(round(x, 2)) if math.isfinite(x)
else 999.9` (`lidar_perception.py:892-907`), so each is always present and always
a finite float. `_publish_json` (`lidar_perception.py:334`) refuses NaN/Inf only
(`json.dumps(..., allow_nan=False)`); a Python `None` would still serialize to
JSON `null`, so the safety here is the explicit finite field construction, not
message rejection. Under the active publisher no null or missing key reaches the
`.toFixed` calls.

### C2 - `best_gap` sub-field deref

Cannot fire. `best_gap` is either `None` or a fully-formed
`{direction, width, distance}` dict of finite floats (`lidar_perception.py:868-878`);
the `None` case is skipped by the truthiness guard at `app.js:1299`. There is no
path that emits a non-null `best_gap` missing `direction` or `width`.

### C3 - anti-stuck falsy-zero

Unreachable under the active publisher. `front_clear` on
`/control/anti_stuck_status` is a sector-clearance distance, not a boolean
(`heading_controller.py:470`, published via `_safe` at `:1335`). It is bounded
away from zero by the perception pipeline: range and hull self-filter remove
near-boat returns (`lidar_perception.py:461-482`), the sector clearance is
computed from those filtered points (`:796-804`), and an empty sector reads as
`max_range` (`:562-564`). `min_range` is runtime-tunable down to 0, so the
guarantee rests on the hull filter and the clearance computation, not a fixed
2.2 m floor. The only falsy value the publisher emits is the cold-start
`inf` -> `null`, which the ternary maps to `N/A` correctly.

### C4 - bare-id auto-global trap

No active source collision. The hyphen-free `index.html` ids (`distance`,
`latitude`, `longitude`, `logs`, `map`, `state`, `urgency`, `waypoint`) do
auto-create same-named `window` globals, but every `app.js` reference to those
names is a declared local, a function parameter, or a property access - none is a
bare read of the global. This is a latent trap and a documentation item, not an
active bug.

### C5 - dead assignment

Confirmed but inert. `const originalInit = window.onload;` (`app.js:3545`) is
assigned once and read nowhere; the load path uses
`window.addEventListener('load', ...)`. Removal has zero runtime effect and is
deferred - no current benefit.

### C6 - open UX limitations (no crash)

Two items stay open as user-experience limitations rather than defects:

- MJPEG recovery is conditional. After a `web_video_server` restart that fires
  the `<img>` error event, same-topic Refresh reconnects with a fresh
  cache-buster (`app.js:615-662`). A silent half-open stream freeze that never
  fires `error` still needs a manual tab or hard-refresh; a frame-arrival
  watchdog would close that gap (deferred).
- One-way config sync. `updateConfigFromROS` (`app.js:1787`) maps controller
  values (`kp`, `ki`, `kd`, `base_speed`, `max_speed`, `min_safe_distance`,
  `:1804-1809`), but `/planning/config` (`waypoint_planner.py:864-887`) carries
  planner state only. Those keys arrive `undefined` and are skipped, so the
  duplicated controller values/controls never receive a live-value echo and can
  show stale values after a reconnect.

C5 removal and any defensive `!= null` guards on the C1/C2/C3 derefs are deferred:
they add no runtime benefit under the active publisher contract.

## Track B - Hailo-COCO Streaming (Source-Compatible, Unrun)

The dashboard is source-compatible with a new `/hailo/overlay/image_raw` (and a
`/compressed` companion) topic with no dashboard edit:

- The camera-topic discovery filter `/\/image_(raw|rect|color|compressed)(\/|$)/`
  (`app.js:766`) matches both topic names (the match is unanchored, so the
  `/hailo/overlay` prefix is irrelevant).
- `buildCameraUrl` (`app.js:664-670`) targets
  `<host>:8080/stream?topic=...&type=mjpeg`; the `web_video_server` host and port
  are the only fixed assumptions (workstation, `8080`).
- A manual-entry fallback (`app.js:645-650`) streams even if the publisher starts
  after page load.

Not run. No transport test was performed on these days (no Pi or workstation live
run). A synthetic-frame dummy `sensor_msgs/Image` publisher and a thin external
frame-tap bridge node are drafted only - not persisted to disk and not proven.
The load-bearing unknown, which needs Pi access, is how the runner
(`object_detection.py`) hands off each annotated frame (an in-process OpenCV
`ndarray` hook versus a GStreamer `appsink` / `v4l2loopback` tap); that decides
the bridge integration mode. When run, reuse the proven Pi ->
DDS (`ROS_DOMAIN_ID=12`) -> workstation `web_video_server` -> dashboard path.

## Track C - Real MAVLink Telemetry (Dashboard Reality-Check)

The dashboard today cannot display IMU or a no-fix GPS state:

- `updateGPS` (`app.js:1098-1146`) reads only `message.latitude` and
  `message.longitude`; it never reads `NavSatFix.status`. A real no-fix sample
  (`status: -1`, `0.0 / 0.0`) would render as a valid `0, 0` position and move
  the boat marker there.
- There is no IMU subscription and no IMU panel; the only `/wamv/sensors/*`
  subscription is GPS (`app.js:805`).

So the 15/07 Block D criterion ("view the no-fix GPS state and IMU") is not
achievable as written. It is replaced (see the 15/07 addendum) by relay-plumbing
validation, valid-fix GPS display, and separately gated dashboard UI additions.

The external read-only MAVROS -> `/wamv/*` adapter (GPS with a no-fix drop or
hold guard, IMU passthrough, sim-source-off mutual exclusion, no command path) is
drafted only and gated. It must be re-confirmed against a live MAVROS graph:
exact topic names, QoS profiles, message shapes, and `/mavros/state` connected.

## Scope and Non-Claims

- Source-only. No live run, no hardware; no code, configuration, or runtime files
  were edited (documentation only) this session.
- Track B and Track C scaffolds are drafted, not persisted or proven.
- C5 removal and defensive guards are deferred; no runtime benefit now.
- The dashboard security posture is flagged, not in scope for this pass.

## Next Steps

14/07/2026 (vacation side-work) continues on documentation and design only - no
hardware and no code edits. Threads to carry forward: the Track B external
scaffolds stay deferred until an exact external path is approved (a synthetic-frame
dummy publisher would be materialized first; the Hailo frame-tap bridge and the
MAVROS adapter remain gated), and the Track C dashboard UI additions (an IMU panel
plus subscription, and a `NavSatFix.status` guard in `updateGPS`) stay gated on
explicit approval. The 15/07/2026 formal dashboard day and every code / runtime
edit remain separately gated; the superseding steps are in the 15/07 early-
preparation addendum. C5 removal and the defensive C1/C2/C3 guards stay deferred -
no runtime benefit now.
