# Friday 24/07/2026 - Window Trim/Research and First Dashboard-to-Motor Command Prep

## Status

Prepared at EOD 23/07/2026; rescoped 23/07/2026 EOD. Track 1 window trim landed and
validated (see Execution log); Track 2 not started. Two tracks. Track 1
trims the Pi-window measurement instrumentation, then pursues the scaling question only
through forum/documentation research plus at most one small standalone Pi helper. Track 2
prepares the first dashboard-to-real-motor command: confirm the real motor path first,
then design the smallest safe single-motor command; the live send is held for a separate
bench-safe, propellers-removed, user-run gate. Track 2 deliberately reopens a real
actuator-write path, but only behind confirmation, design, and that separate gate;
everything else stays view-only.

## Goals

1. **Window - trim, then lightweight research only.** Trim the 23/07 Pi-window measurement
   instrumentation without changing normal local display, camera/inference ownership,
   annotated ROS publication, or the Pi Desktop deployment location. Then pursue the
   scaling question ONLY through (a) online forum / OpenCV-Qt documentation research and
   (b) at most one small standalone Pi `.sh` helper as an isolated experiment. Integrate
   into the full Pi helper only if that standalone clearly works. The 23/07 diagnosis
   found the ceiling is most likely benign `KEEPRATIO` letterboxing, not a defect; the
   research confirms or refutes that first.
2. **Motor - confirm and design the first dashboard-to-real-motor command; do not send.**
   Confirm which real topic/interface actually reaches a physical motor - the
   `/wamv/thrusters/*/thrust` bridge path, a MAVROS/FCU actuator path, or neither wired
   yet - then design the smallest safe single-motor command with an explicit abort. No
   live send in this task.
3. **Safety.** Track 2 reopens a real actuator-write path only behind confirmation,
   design, and a separate bench-safe user-run gate with propellers removed. Arming, mode,
   mission, parameter, E-Stop-release, multi-motor commands, and the FCU beyond the one
   confirmed motor path stay view-only and unauthorized. Track 1 authorizes no vehicle
   write at all.

## Evidence carried forward

- Repository baseline: `HEAD == origin/main == a2f5f5cb0b913248440751e9e809d16670403549`
  (`a2f5f5c`, "feat(dashboard): resizable Pi window diagnostic + 23/07 run record"). The
  23/07 measurement work and both diaries are committed and pushed; the working tree is
  clean.
- Pre-trim revisions this task trims:

  | Item | Size | SHA-256 |
  | --- | ---: | --- |
  | `tools/pi_live_hailo_mavlink_dashboard.sh` | `66,481` bytes | `82e15bede13888fa33829ad5c16ddbcc23a3351a82996679fcc79ffb6fa9af07` |
  | `tools/live_dashboard_preflight.sh` | `28,849` bytes | `86b37225ad7beeab7f29777f1d67c8287692c59ba5eaf542a9da7720d65cfd28` |

- P0 passed on the active Pi desktop: OpenCV `4.10.0`, Qt `5.15.13`,
  `currentUIFramework(): QT`, XWayland/`xwininfo`, and logical `1920x1080`.
- Partial Phase R evidence:
  - workstation:
    `/home/ghostzero/live_dashboard_logs/live_dashboard_workstation_20260723_183748`;
  - Pi run:
    `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260723_184112`;
  - copied Pi run directory:
    `/home/ghostzero/live_dashboard_logs/pi_copies/live_dashboard_20260723_184112`
    (`19` files, `912K` allocated; no remote-versus-local SHA-256 manifest comparison).
- The Pi reached connected/disarmed MAVROS state, telemetry, and
  `PI_SOURCE_STACK_READY=PASS`; the operator visually reproduced the scaling symptom. The
  copied `hailo.log` records `151` unlabelled inner-rectangle samples: `24` at `321x241`,
  then `127` at `640x480`. No labelled P2/`xwininfo` outer geometry was captured, so the
  inner plateau is measured but no display-cause verdict exists.
- The workstation produced no arrival/rate samples, and the Pi exceeded final
  verification during the battery sample; the saved bounded battery echo was killed at
  its deadline. Both teardowns passed. The thermal watchdog peak was `67.75 C`, below its
  `80 C` abort. Phase FS and further in-place Pi-window experiments will not run.
- The saved MAVROS state is connected, disarmed, and `HOLD`. Later untimestamped MAVProxy
  lines record `Radio Failsafe Cleared` and a `Mode MANUAL` prompt. No command-abort
  evidence attributes that transition to the dashboard; retain it as a safety audit point
  before any motor-path decision.

## Current architecture and safety boundary

- `web_dashboard/autoboat/app.js` connects the browser to workstation rosbridge on
  `ws://<dashboard-host>:9090`.
- The live supervisor binds rosbridge, dashboard HTTP, and `web_video_server` to
  workstation loopback while ROS domain `12` carries DDS discovery between workstation
  and Pi.
- `LIVE_MAVLINK_VIEW_ONLY=true` blocks existing dashboard topic and service writes at
  their final send boundary. The motor track must add an exact-topic allowlisted path
  through this guard, never disable or bypass it.
- The Pi helper watches five protected command topics, rejects dashboard command-service
  servers, keeps MAVProxy as the exclusive UART owner, and runs MAVROS with the bounded
  telemetry profile.
- The low-level architecture is still a working hypothesis. `launch/remap.launch.yaml`
  retains only a non-existent real-hardware bridge stub (`use_real_hardware:=false`)
  pending confirmation of the actual controller and protocol.

The real low-level motor path is therefore the first thing to confirm, not assume. The
candidate transport is the same rosbridge -> DDS domain `12` path the dashboard already
uses, but where a `/wamv/thrusters/*/thrust` message actually goes on real hardware is
unproven: in simulation it drives the sim thrusters, and on real hardware the Layer B
bridge that would translate it to the control unit is a stub. Block C confirms whether
that bridge, a MAVROS/FCU actuator path, or neither currently reaches a physical motor,
before any command is designed against it.

## Plan and approval gates

### Block A - read-only state and requirements audit

No code edit in this block.

1. Reconfirm repository state at `a2f5f5c` and the exact 23/07 measurement diff to be
   trimmed.
2. Identify every measurement-only addition to remove and every normal display/Desktop
   behaviour that must remain.
3. List the read-only questions Block C must answer: the real controller identity, the
   candidate motor topic(s) and message type(s), whether any driver/bridge consumes them
   and drives a physical motor, and the ownership/protocol.
4. Reconcile the saved `HOLD` state and later untimestamped `Mode MANUAL` observation
   without assuming a dashboard cause.
5. End with an exact window-trim list and the motor-path confirmation checklist.

### Block B - window: trim, then research and one standalone experiment

The trim requires separate code-edit approval. Remove only the measurement experiment:

- `HAILO_WINDOW_DIAG`, its validation and environment propagation;
- checkpoint-label file creation and diagnostic state/functions;
- periodic rectangle/property reads and delayed fullscreen samples;
- `LIVE_PI_WINDOW_DIAG` and its measurement-only preflight cases;
- active P1/P2 measurement procedure and matching test cases.

Audit `LIVE_PI_WINDOW_MODE` before removal. If it exists only to select the retired
measurement phases, restore the supervisor's fixed operational fullscreen command. Retain:

- the helper's pre-existing `HAILO_LOCAL_WINDOW_MODE` contract and normal fullscreen gate;
- ordinary `HAILO_LOCAL_WINDOW` lifecycle evidence and diagnostics-off display behaviour;
- one Hailo camera owner, one inference path, and one annotated ROS publisher;
- all command sentinels and telemetry/readiness gates;
- the absolute Pi Desktop resolution, checksum, and execution path plus its tests;
- the 22/07/2026 and 23/07/2026 historical records.

Run focused helper/preflight regressions, recompute both tracked sizes and SHA-256 values,
and update documentation. The trim has no live execution.

After the trim, the only further window work is lightweight:

- online forum / OpenCV-Qt-documentation research on `WINDOW_KEEPRATIO` fit behaviour,
  `getWindowImageRect` semantics, and X11/XWayland fullscreen, to confirm or refute the
  23/07 benign-letterboxing verdict;
- at most one small standalone Pi `.sh` helper as an isolated experiment - its own file,
  off the main helper, user-run - to test a candidate improvement;
- integrate into `tools/pi_live_hailo_mavlink_dashboard.sh` only if that standalone
  clearly works, under separate approval. No new in-place measurement instrumentation.

### Block C - confirm the real motor path (read-only)

Read-only inspection; a live introspection on hardware is separately approved. Answer,
with evidence, before any command is designed:

- the real low-level controller identity and how it is driven;
- the exact candidate motor topic(s) and message type(s) - the `/wamv/thrusters/*/thrust`
  bridge path, a MAVROS/FCU actuator or RC-override path, or neither currently wired;
- whether a driver/bridge actually consumes the topic and moves a physical motor, versus
  only the simulator;
- ownership, rate, units, sign, neutral value, and failure/timeout behaviour of that
  interface.

If no path currently reaches a real motor, stop and report. Block D and Block E do not
proceed until one real path is confirmed.

### Block D - design the smallest safe single-motor command (design only)

Requires the confirmed path from Block C. No code edit, no send.

- Design one exact-topic, allowlisted dashboard publisher for the single confirmed motor
  topic. It must route through the existing `LIVE_MAVLINK_VIEW_ONLY` write guard, never
  disable or bypass it.
- Specify the smallest possible command: one motor, minimal magnitude, a brief bounded
  duration, an explicit neutral/stop on release, and a fail-closed timeout.
- Specify the abort path (operator stop plus a hardware kill), the bench-safety
  preconditions (propellers removed, so shafts free-spin with zero thrust), and the exact
  evidence to capture.
- Design the smallest failing tests for valid, malformed, oversize, and rate-limited
  input and fail-closed behaviour.
- Present the topic, message, magnitude, duration, guard interaction, tests, and
  abort/safety contract for explicit review before any implementation.

### Block E - separately approved, bench-safe, user-run first send

Not authorized by this pre-diary.

The first live motor proof is user-run with propellers removed (zero thrust): one
workstation supervisor, one dashboard tab, and the single confirmed motor path. Require
the smallest command, a visible motor response, the neutral/stop on release, a working
abort, and zero traffic on the other four protected command topics. Arming, mode,
mission, parameter, E-Stop-release, and any second motor stay out of this first proof.

## Non-goals

- No further Pi-window measurement, Phase FS, display fix, or scaling acceptance beyond
  the research plus one standalone experiment.
- No live motor send until Block C confirms a real path, Block D's design is reviewed, and
  the bench-safe propellers-removed gate is separately approved.
- No arming, disarming, mode, mission, parameter, E-Stop-release, or multi-motor command.
- No direct UART/MAVProxy injection or low-level protocol guess; the path must be
  confirmed, not assumed.
- No second camera, stream, inference pipeline, or publisher.
- No broad dashboard/Hailo refactor, package installation, live hardware run, commit, or
  push without separate approval.

## Execution log - 24/07/2026

Block A (read-only audit) and Block B (window trim) are complete and documentation is
updated. The Pi-window measurement instrumentation added on 23/07/2026 is removed while the
operational display path is unchanged.

- **Trim landed.** Removed `HAILO_WINDOW_DIAG` with its validation and environment
  propagation, the checkpoint-label file, the diagnostic state and functions
  (`read_window_diag_label`, `read_window_diag_field`, `emit_window_diag`,
  `advance_window_diagnostics`), the periodic and delayed rectangle/property sample
  emitters, and the `LIVE_PI_WINDOW_DIAG` selector with its measurement-only preflight
  cases. Retained the `HAILO_LOCAL_WINDOW_MODE` contract, the fullscreen gate and its
  `setWindowProperty` activation, and the `HAILO_LOCAL_WINDOW` lifecycle markers.
- **Post-trim revisions** (recomputed; pins aligned across the helper, the preflight
  constant, the preflight tests, and the wiki manifest):

  | Item | Size | SHA-256 |
  | --- | ---: | --- |
  | `tools/pi_live_hailo_mavlink_dashboard.sh` | `61,427` bytes | `3c1c9c274ed18c955669d32cd9e7d0f90a2999ec927be79bd06dfefebca53072` |
  | `tools/live_dashboard_preflight.sh` | `28,647` bytes | `39406e88e182125d9c088be4f4fdece239529938009b82f3c85cb268f322a4c0` |

- **Documentation.** `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` and `Board.md` updated:
  the retired selectors are removed from active commands, a retired-measurement section is
  kept for traceability, and the helper/supervisor size and SHA-256 manifest is refreshed.

### Pipeline 1 - workstation preflight: PASS

`tools/live_dashboard_preflight.sh workstation`, 24/07/2026:

- helper lifecycle/local-window contract regression: PASS;
- live-dashboard preflight contract regression: PASS (`cases=13`);
- dashboard unit tests: `31` pass, `0` fail, `0` skipped;
- helper checksum pin verified against the tracked value: `OK`;
- `W1_PREFLIGHT=PASS tests=dashboard,helper,preflight ports=8002,8080,9090`.

Workstation identity for the live run: `workstation_ipv4=10.120.2.243 dev=wlp147s0
ssid=IoT IMT Nord Europe`; the Pi endpoint is `10.120.2.249` on the same subnet and SSID.
This preflight started no live services.

## Next step

Blocks A and B are complete and the workstation preflight is green. Next is the user-run
live dashboard run across the two terminals to validate the trimmed helper end to end
under view-only, then Block C read-only motor-path confirmation. Do not send any vehicle
command until Block C confirms a real path and the bench-safe, propellers-removed gate is
separately approved.
