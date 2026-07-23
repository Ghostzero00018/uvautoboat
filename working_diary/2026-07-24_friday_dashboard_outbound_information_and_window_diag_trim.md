# Friday 24/07/2026 - Dashboard Outbound Information and Window Diagnostic Trim

## Status

Prepared at EOD 23/07/2026. Not started. The Pi-window experiment is retired. Tomorrow
first removes its measurement-only instrumentation, then defines a narrowly bounded live
information path from the dashboard to a Pi-side receiver. A direct low-level
controller/FCU path remains held until its protocol and ownership are confirmed.

## Goals

1. Trim the 23/07/2026 Pi-window diagnostic additions without changing normal local
   display, camera/inference ownership, annotated ROS publication, or the Pi Desktop
   deployment location.
2. Define and, only after separate approval, implement a bounded dashboard-originated
   information message that a Pi-side ROS receiver can validate, record, and acknowledge.
3. Preserve the existing real-boat view-only safety boundary. This task does not authorize
   vehicle commands or low-level-controller writes.

## Evidence carried forward

- Repository baseline:
  `HEAD == origin/main == 29a1bc5f9355e8df30eb933e98c9e9034c2845fb`.
- EOD tree: seven modified tracked files plus this new diary; nothing is committed or
  pushed.
- Pre-trim revisions used for the partial Phase R run:

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
  `80 C` abort. Phase FS and further Pi-window experiments will not run.
- The saved MAVROS state is connected, disarmed, and `HOLD`. Later untimestamped MAVProxy
  lines record `Radio Failsafe Cleared` and a `Mode MANUAL` prompt. No command-abort
  evidence attributes that transition to the dashboard; retain it as a safety audit point
  before any outbound-path decision.

## Current architecture and safety boundary

- `web_dashboard/autoboat/app.js` connects the browser to workstation rosbridge on
  `ws://<dashboard-host>:9090`.
- The live supervisor binds rosbridge, dashboard HTTP, and `web_video_server` to
  workstation loopback while ROS domain `12` carries DDS discovery between workstation
  and Pi.
- `LIVE_MAVLINK_VIEW_ONLY=true` blocks existing dashboard topic and service writes at
  their final send boundary.
- The Pi helper watches five protected command topics, rejects dashboard command-service
  servers, keeps MAVProxy as the exclusive UART owner, and runs MAVROS with the bounded
  telemetry profile.
- The low-level architecture is still a working hypothesis. `launch/remap.launch.yaml`
  retains only a non-existent real-hardware bridge stub pending confirmation of the actual
  controller and protocol.

The narrow first target is therefore a dedicated Pi-side ROS receiver, not the FCU. The
candidate path is:

```text
dashboard browser
  -> workstation rosbridge
  -> ROS domain 12 over DDS
  -> dedicated Pi information receiver
  -> validated log/display and optional acknowledgement
```

## Plan and approval gates

### Block A - read-only state and requirements audit

1. Reconfirm repository state, the 23/07/2026 EOD evidence, and the exact pre-trim diff.
2. Identify every measurement-only addition and every normal display/Desktop-path
   behaviour that must remain.
3. Confirm the first information payload, receiver, rate, size, lifetime, acknowledgement,
   and failure semantics.
4. Reconcile the saved `HOLD` state and later untimestamped `Mode MANUAL` observation
   without assuming a dashboard cause.
5. End with an exact edit/test plan. Do not edit code in this block.

### Block B - trim window instrumentation

Requires separate code-edit approval.

Remove only the measurement experiment:

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
and update current documentation. This block has no live execution.

### Block C - freeze the outbound information contract

Requires an explicit payload decision before implementation.

Recommended first contract:

- one fixed topic, provisionally `/dashboard/operator_info`;
- `std_msgs/String` containing a versioned, bounded JSON object;
- allowlisted fields such as `version`, `message_id`, `sent_at`, `kind`, and `text`;
- hard payload-length and rate limits, with no user-selected topic or message type;
- a separate Pi receiver using the system ROS 2 Python environment, not the Hailo venv;
- validation and log/display only, with an optional fixed acknowledgement topic;
- no dependency on the Hailo helper and no new server or network port.

Keep `LIVE_MAVLINK_VIEW_ONLY=true`. The information sender must be an exact-topic,
allowlisted function; it must not disable or bypass the generic dashboard write guard.

The direct low-level-controller/FCU branch remains held. It requires confirmed hardware
ownership, protocol, interface, message mapping, acknowledgements, timeout behaviour, and
a separate safety review.

### Block D - minimal implementation and static acceptance

Requires separate code-edit approval after Block C.

1. Add the smallest failing dashboard and receiver tests.
2. Implement only the fixed information publisher, bounded receiver, and approved
   acknowledgement.
3. Prove valid input, malformed input, unknown fields/kinds, oversize input, rate limiting,
   replay/duplicate handling, timeout/staleness, and fail-closed receiver behaviour.
4. Extend the dashboard direct-publish canary so only the existing guarded vehicle
   dispatcher and the exact information publisher can call `.publish()`.
5. Run the existing dashboard test suite and the retained helper/preflight suites.

### Block E - separately approved user-run acceptance

Not authorized by this pre-diary.

The first live proof should isolate the information channel: propulsion isolated, one
workstation rosbridge/dashboard, and one Pi information receiver. MAVProxy, MAVROS, Hailo,
camera capture, and the FCU are not required for that proof. Require exact receipt and
optional acknowledgement, bounded rate/size, clean teardown, and zero traffic on the five
protected command topics. Any FCU delivery is a different future block.

## Non-goals

- No further Pi-window measurement, Phase FS, display fix, or scaling acceptance.
- No arming, disarming, mode, mission, parameter, thrust, actuator, or E-Stop-release
  message.
- No direct UART/MAVProxy injection, MAVROS write plugin, arbitrary-topic sender, or
  low-level protocol guess.
- No second camera, stream, inference pipeline, or publisher.
- No broad dashboard/Hailo refactor, package installation, live hardware run, commit, or
  push without separate approval.

## Next step

Start Block A only: read the current diff and canonical dashboard/helper contracts, then
return the exact trim list and proposed fixed information schema. Do not edit code or run
live hardware until the next gate is approved.
