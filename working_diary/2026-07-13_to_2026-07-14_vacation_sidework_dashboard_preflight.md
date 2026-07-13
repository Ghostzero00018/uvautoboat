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

## Implementation Note - 13/07/2026 - Dashboard GPS No-Fix Guard

Following the source-only preflight above, the first Track C reality-check item
(the dashboard `NavSatFix.status` guard) was implemented and unit-tested locally
later on 13/07/2026. This moves that one item from design to implementation; the
preflight sections and their documentation-only scope stand as written.

- `web_dashboard/autoboat/app.js`: `updateGPS` accepts a sample only when
  `status.status >= 0` with finite latitude/longitude (`isUsableGpsFix`);
  coordinates are not a validity signal, so a real `0, 0` fix is still accepted.
  Invalid samples show `No fix | Pas de position`, hold the last map position, and
  reset the speed/distance baseline (`progressState.lastPosition = null`). The
  obsolete `lat !== 0 && lon !== 0` origin guard in `gpsToLocal` was removed.
- `web_dashboard/autoboat/test/gps_fix.test.js`: focused `node:test` coverage over
  invalid/missing status, non-finite coordinates, valid `0, 0`, and outage
  reacquisition.
- Verified locally: 10/10 tests, `node --check` clean, `git diff --check` clean;
  the GPS subscription (`app.js:809`) calls `updateGPS` by name, so the reassigned
  guard wrapper runs at runtime. No ROS / browser live test was run.

Open follow-on: the planner side of the same contract - `waypoint_planner.py`
`gps_callback` (:419) stores `start_gps` from the first sample with no status
check, anchoring the mission origin at `0, 0` on a no-fix first sample and
reporting `gps_ready` - is the recommended next block.

## Implementation Note - 13/07/2026 - Planner GPS No-Fix Guard

The planner-side follow-on flagged above is now implemented and unit-tested
locally, closing the dashboard/planner GPS-readiness contradiction.

- `plan/plan/waypoint_planner.py`: `gps_callback` (:419) now returns early unless
  `msg.status.status >= 0` with finite latitude/longitude, before touching planner
  state - mirroring the dashboard `isUsableGpsFix` semantics. `current_gps` and
  `start_gps` initialize only from the first usable fix; a real `0, 0` fix is
  accepted; later no-fix samples retain the last valid `current_gps` and never
  re-anchor `start_gps`.
- `plan/test/test_waypoint_planner_gps.py`: focused coverage (unbound
  `gps_callback` against a duck-typed state with real `NavSatFix` messages) -
  unusable first fix rejected, valid `0, 0` after a no-fix accepted, current fix
  updates without moving the origin, last valid position held during a no-fix.
- Verified locally: focused 7 passed; full `plan/test` 9 passed + 1 existing skip;
  `py_compile` and `git diff --check` clean. No colcon rebuild, node restart, DDS
  graph, or live replay was run.

Bounded residual (not fixed): `publish_mission_status` (:1466) keeps an independent
30 s force-ready fallback that sets `/planning/mission_status.gps_ready` true after
a GPS timeout even with no usable fix. It does not initialize the origin
(`start_gps` stays `None`), so it cannot corrupt the local frame, but it can
publish a misleading readiness value. Left as a separate, bounded follow-up.

## Validation Note - 13/07/2026 - Dashboard DOM Smoke

The dashboard GPS no-fix guard was exercised in the browser later on 13/07/2026.
This supersedes only the browser half of "No ROS / browser live test was run"
above; no ROS / rosbridge / topic replay was run, so that half stays accurate.

- Scope: a browser-level direct-call smoke, NOT end-to-end - rosbridge was absent
  and `updateGPS` was called straight from the DevTools console, bypassing ROS.
- Confirmed by the log: `typeof updateGPS` is `"function"` (the wrapper loaded
  without rosbridge); the four calls returned `false -> true -> true -> false`
  (no-fix rejected, valid `0, 0` accepted, valid fix accepted, later no-fix
  rejected); the final state read `hasFix: false` with `baseline: null`.
- Not captured (remains unit-test evidence): the rendered GPS panel text and the
  expanded `stored` / `marker` coordinates - Firefox printed them collapsed and
  they were deliberately not re-run to expand. The "hold last valid position"
  values stay covered by `test/gps_fix.test.js`.
- Expected noise only: `ws://127.0.0.1:9090` connection refusals (no rosbridge) and
  Leaflet legacy-CSS parse warnings.
- Source regression (Pipeline 1) re-confirmed green at HEAD `7fd0357`.

Planner guard unchanged: source-tested only; live-node replay (Pipeline 3)
deferred.

## Validation Note - 13/07/2026 - Planner Live-Node Replay (Pipeline 3)

This supersedes the "source-tested only; live-node replay (Pipeline 3) deferred"
statement above: Pipeline 3 was run on 13/07/2026 (workstation only, isolated
`ROS_DOMAIN_ID=112`, no Pi / Gazebo / MAVROS / FCU / browser / external network), and the
planner GPS no-fix guard is now live-node validated against the installed 7fd0357
source.

- Endpoint: publisher 0, subscription 1, `waypoint_planner_node`, RELIABLE /
  VOLATILE. History depth introspected as UNKNOWN on the subscription side, so
  depth 10 was NOT live-proven - it is only declared in source.
- Phase 1 - initial no-fix (`status -1`, `0, 0`): `/planning/config` stayed
  `gps_ready: false`, `start_lat/lon: null` before and after; no acquisition logged.
- Phase 2 - valid `0, 0` (`status 0`): `gps_ready: true`, `start 0.0 / 0.0`; exactly
  one `Base Point` and one `GPS acquired`.
- Phase 3 - move (`status 1`, `0.0001, 0.0002`): origin held `0.0 / 0.0`,
  `/planning/mission_status` position `[22.24, 11.12]`.
- Phase 4 - later no-fix (`status -1`, `51, 3`): position held at `[22.24, 11.12]`,
  origin held `0.0 / 0.0`, acquisition counts stayed `1 / 1` - the decisive live
  proof that a no-fix cannot move the origin or the last valid position.
- The 30 s force-ready fallback was NOT triggered (the valid fix set `start_gps`
  before the timeout; no warning logged) and remains a separate, open bounded
  residual; `/planning/config.gps_ready`, used as the oracle, is independent of it.
- Evidence: `testlogs_13_07_2026.txt` (combined) and
  `planner_pipeline3_node_13_07_2026.txt` (node stdout).

Deferred follow-up (post-test, does not affect the GPS verdict): the planner's
`main()` (`waypoint_planner.py:1544`) catches only `KeyboardInterrupt`, and its
`finally` calls `rclpy.shutdown()` unconditionally, so an external shutdown
(`ExternalShutdownException`) double-shuts the context and raises
`RCLError: rcl_shutdown already called`. Low-severity shutdown-path defect,
recorded and deferred.

## Fix Note - 14/07/2026 - Planner Residuals Resolved

Both bounded residuals recorded above are now fixed and verified (unit + isolated
domain-112 live), superseding their "deferred" / "separately open" status.

- Force-ready fallback: `publish_mission_status` now derives readiness from
  `start_gps` (the same oracle as `/planning/config`) and never forces
  `gps_ready = true` on timeout. The one-time late-GPS warning is kept but reworded
  truthfully ("readiness stays disabled until a real fix"). This was safe because
  the forced value had no navigation consumer - the backend gates every GPS
  operation on `start_gps` / `current_gps` directly (`waypoint_planner.py:456,586`),
  and the dashboard, CLI (`autoboat_cli.py:492`), and QGC bridge
  (`qgc_live_mission_bridge.py:110`) all read the truthful `/planning/config`.
- Double shutdown: `main()` now catches `(KeyboardInterrupt,
  ExternalShutdownException)` and calls the idempotent `rclpy.try_shutdown()`, so an
  external shutdown no longer double-shuts the context.
- Verification: red-green unit tests
  (`plan/test/test_waypoint_planner_mission_readiness.py`,
  `plan/test/test_waypoint_planner_shutdown.py` - two discriminator tests fail on the
  old code, all pass after the fixes); full `plan/test` 13 passed + 1 skip;
  `py_compile` clean; `plan` rebuilt. Isolated domain-112 live replay: past the 30 s
  timeout with no GPS, `mission_status.gps_ready` stayed `false` and the truthful
  one-time warning fired; a valid fix flipped both `/planning/config` and
  `/planning/mission_status` to `true`; SIGINT to the node shut down cleanly with no
  traceback and no orphan (child-aware teardown). Evidence:
  `testlogs_14_07_2026.txt`, `planner_residuals_node_14_07_2026.txt`.

No dependency or configuration change; scope limited to `waypoint_planner.py` and
focused planner tests. Kept as two code commits plus this diary update.
