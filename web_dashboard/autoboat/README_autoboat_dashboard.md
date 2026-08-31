# AutoBoat Web Dashboard

Real-time web-based monitoring and control dashboard for the AutoBoat autonomous boat system.

## Features

- **Real-time GPS tracking** with trajectory visualization on interactive Leaflet map
- **Mission control**: Generate, Confirm, Start, Stop, Resume, Emergency Stop, Go Home, Reset
- **Three config panels**: Main Config (PID/speed/nav), LiDAR Perception, Heading Controller
- **Dirty-params filtering**: Only user-modified parameters are sent on Apply
- **Apply buttons disabled** until first ROS config sync (prevents stale defaults)
- **Reset Defaults** buttons for Perception and Controller (restores launch file values)
- **Perception presets**: Universal, Buoy Field, Pier Detect, Open Water
- **Health check panel** with live streaming output, elapsed time, and [DONE] completion
- **JSON export** on Health Check, System Logs, ROS2 Terminal, and Mission Control panels
- **Copy to clipboard** on Health Check, System Logs, and ROS2 Terminal panels
- **Parameter validation** — out-of-range values rejected with orange toast, nothing sent to ROS
- **A\* Advanced Parameters** panel with Apply/Reset buttons and range-validated inputs
- **Emergency stop** with red pulsing badge and thrust cut
- **Obstacle detection** with Front/Left/Right clearance, urgency scores, clusters, gaps
- **Anti-stuck status** with Kalman drift uncertainty indicator
- **Single-stream camera viewer** via web_video_server (MJPEG), with image, keyboard,
  or button Enlarge; `1.0×`–`4.0×` zoom; Reset; Close; Escape; focus trapping; and
  camera-error recovery without opening another stream
- **State badges** for: INIT, WAITING_CONFIRM, READY, DRIVING, PAUSED, FINISHED, EMERGENCY_STOP, JOYSTICK
- **FCU bench digital twin** with a paired RC-layer request and separately measured
  MAVROS RC-output panel; disabled unless its explicit URL and bridge gates pass

## Prerequisites

1. **ROS 2 Jazzy** installed and configured
2. **rosbridge-suite** — WebSocket ↔ ROS 2 bridge (port 9090):

   ```bash
   sudo apt install ros-jazzy-rosbridge-suite
   ```

3. **web_video_server** — MJPEG camera streaming (port 8080):

   ```bash
   sudo apt install ros-jazzy-web-video-server
   ```

4. **AutoBoat nodes** running via `autoboat.launch.yaml` for simulation, or the
   isolated source stack from the live-hardware runbook for its view-only test
5. **Internet access for map tiles only** — `roslibjs`, Leaflet, and fonts are vendored locally; OpenStreetMap tiles still require internet until Roadmap §1.3 Path B lands

> **Not ros2-web-bridge.** A separate project ([ros2-web-bridge](https://github.com/RobotWebTools/ros2-web-bridge)) offered a Node.js-based alternative but was **archived in November 2025** (last targeted ROS 2 Dashing, 2019). This dashboard uses `rosbridge_suite`, the actively maintained official ROS package.

## Current Real-Boat Status

The dashboard remains simulation-first and normally reads and writes the
existing `/wamv/*` topic contract. The temporary live helper remains view-only:
it displays the stock-COCO Hailo stream and six direct MAVROS telemetry feeds
without validating any real-FCU write path. Its implementation gives each
MAVROS topic an independent three-second freshness threshold, clears the
corresponding values when a topic becomes stale, clears the whole panel when
rosbridge disconnects, and makes all write-capable controls inert while
preserving Mission History, tuning expanders, health clear/auto-scroll, export,
and copy controls.

A separate, default-inhibited bench component is now implemented for a bounded
digital-twin test. The browser publishes one atomic steering/throttle
`sensor_msgs/Joy` frame on `/command_ingress/rc_axes` only while the operator
holds its Apply button. `tools/real_fcu_rc_command_bridge.py` discovers the live
RC mapping, RC rails and function `73`/`74` output rails through MAVROS, converts
the request to `/mavros/rc/override`, and returns the separately observed
`/mavros/rc/in` and `/mavros/rc/out` values plus the resolved live rails on
`/command_ingress/status`. The dashboard retains raw PWM and also reports each
motor output as a signed percentage of its configured PWM rail. The percentage
is the literal position of the measured output between its live minimum, trim
and maximum. `SERVOx_REVERSED` remains visible in the status evidence but is not
applied again because `SERVO_OUTPUT_RAW` already reflects that output setting.
This percentage is not a force estimate. Requested values are never displayed
as measured feedback, and no rail-relative value is shown before the rails
arrive.

The component cannot arm, disarm, change mode or write parameters. It is inert
unless `allow_real_fcu:=true`, an explicitly supplied `expected_domain_id`
matches `ROS_DOMAIN_ID`, a fresh neutral RC input and the live parameter guards
all pass. The browser additionally requires
`?enable_fcu_bench_control=1`, fresh measured feedback, the physical-condition
checkbox and a continuously held button. A new armed epoch requires a disabled
frame before an enabled frame, and command loss replaces both channels with
their live trims. Empty or out-of-rail RC input/output arrays are invalid rather
than fresh. The measured one-hertz MAVROS feeds use a `1.5 s` feedback limit and
the state feed uses `2.5 s`; the browser still requires a fresh bridge status
within `500 ms` because that status is emitted by the bridge at `20 Hz`.

With the bench query enabled, the normal E-Stop button, both shortcut buttons
and the E-Stop inside the expanded camera viewer publish a latched
`/planning/emergency_stop`. The bridge immediately clears the demand and holds
both resolved RC inputs at their live trims while armed. `Ctrl+C` and `SIGTERM`
use the same neutralisation path before the ROS context closes; when already
disarmed, shutdown sends the channel-aware release values instead.

This path has static, dashboard-test and workstation-only SITL runtime coverage,
but no physical acceptance. On 10/08/2026, a clean `motorboat-skid` run resolved
steering/throttle to RC channels `1`/`3` and functions `73`/`74` to
`SERVO1`/`SERVO3`. Normal arming reached `ARMED_NEUTRAL`; browser-held positive
and negative steering demands reached `ACTIVE`, produced independently measured
asymmetric servo output in the expected directions, and returned to measured
`1500`/`1500` neutral. Normal disarm was acknowledged `ACCEPTED`. The recordings
prove the visible request/feedback loop; the simultaneous terminal capture
missed both active intervals and proves neutral stability only.

The dedicated workstation SITL entry is implemented with static and focused-test
coverage:

```bash
tools/live_dashboard_preflight.sh sitl
```

It is separate from the Pi helper, accepts no endpoint argument, forces ROS
domain `42` with localhost-only discovery, and prints each finite simulator
safety/arm/disarm action only when its one-shot gate is open. It records the raw
request, status, E-Stop, override and MAVROS-state streams under one
`sitl_digital_twin_YYYYMMDD_HHMMSS` directory.

The first helper-driven attempt on 11/08/2026 failed before the Rover listener
gate in `sitl_digital_twin_20260811_150958`. `sim_vehicle.py` delegated Rover to
a display terminal outside the supervisor-owned process group, so the runner
could neither certify Rover provenance nor retain its output. The runner now
launches the pinned `ardurover` binary directly in the run-owned state directory,
and early teardown checks shutdown frames only after the bridge has started.
Those corrections pass focused tests but have not been rerun against SITL;
complete machine-readable phase and teardown acceptance remain open.

In the operator-supplied Pi transcript on 10/08/2026, the Pi received the FCU
heartbeat, but parameter requests returned no values and the FCU was observed
already armed in `MANUAL`. That evidence keeps the physical run blocked. A
missing parameter response exits before the RC-override publisher is created.
Startup while armed keeps the publisher present but latches `STARTUP_ARMED`, and
every timer tick returns without publishing an override. The existing live
helper is not the runner for this path because its MAVROS plugin allowlist omits
`param` and its `udpout` route is the established view-only transport.

The guarded physical-FCU path is now prepared as two separate entry points:
`tools/real_fcu_digital_twin_workstation.sh` and
`tools/real_fcu_digital_twin_pi.sh`. Both use ROS domain `43`, separate from the
domain `42` localhost-only SITL graph. The workstation and Pi `check`, `run-t2a`
and `run` paths retain subnet discovery for the cross-machine contract; the
standalone Pi `probe` path selects localhost-only discovery. The Pi owns
`/dev/ttyAMA0:57600` directly, without MAVProxy or UDP fan-out. Its `probe` mode
loads only `sys_status` and `param` to verify a connected, disarmed,
hardware-safe T0b state and read the safety, mapping and rail parameters. Those
plugins advertise state-changing services, so localhost discovery is part of
the probe safety boundary. Its separately gated `run` mode restarts MAVROS with
`sys_status`, `param`,
`global_position`, `imu` and `rc_io`, verifies the six dashboard telemetry
signals, and starts the bounded bridge. The workstation owns only loopback
rosbridge and dashboard services and emits the servo-mapped bench URL only after
fresh `READY_DISARMED` feedback. Powered-down connector seating and end-to-end
`Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity passed on 17/08/2026, closing
T0a. On 18/08/2026, the bundle deployment and non-actuating Pi `check` passed.
The first T0b probe opened direct serial and received an ArduPilot heartbeat but
did not complete the MAVROS parameter-list exchange, so T0b and both T2 tiers
remain open. On 19/08/2026, the state-capture path was repaired so every attempt
has isolated YAML and diagnostic files, the bundle manifest was regenerated,
and the physical-helper suite passed `24` cases. A new five-file deployment at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` passed exact
inventory, pinned-manifest, `4/4` member verification and the non-actuating Pi
`check`. The T0b retry did not run and was deferred to a later day pending a
fresh safety review, certification and approval. No parameter was written and
the bridge did not start. On 20/08/2026, the safety review found that the two
T0b plugins expose parameter, mode and telemetry-configuration services to the
ROS graph. The local helper was repaired and its `24`-case suite passed so the
standalone probe graph is now localhost-only, while the run paths remain
subnet-visible. After separate approval, revision `f8e440a` was deployed once
to `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820`. Fresh Pi and
physical certification passed with the controller and Herelink off, the exact
five-member archive inventory and four-member manifest verified, and the
non-actuating Pi `check` returned
`REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started` with empty
stderr. Block A is complete. The serial probe did not run, so Block E remains
separately closed and T0b plus both T2 tiers remain open.

Later on 20/08/2026, Block E was separately approved and the real-FCU probe did
run. A powered receive-only UART diagnostic first captured `23868` bytes and
`30` valid disarmed heartbeats from system/component `1.1` while transmitting
zero serial bytes. The final full probe then reached `connected: true`,
`armed: false`, `mode: MANUAL` and a passing hardware-safety check. MAVROS
exhausted its automatic parameter-list attempts, and the explicit forced pull
received no response before timeout. The helper cleaned up with
`status=1 cleanup_rc=0`; no `41`-parameter mapping/rail artifact was produced,
no parameter was written and the bridge did not start. T0b and both T2 tiers
remain open. A later duplex isolation received `18` valid disarmed heartbeats
and transmitted exactly one MAVLink PING plus one `PARAM_REQUEST_READ` for
`SYSID_THISMAV`. The two outbound frames audited as `53` bytes with no
state-changing message, but neither received a response. The copied archive
verified at
`c1c73f8df65e5f109adc051d3f04990ce646830a4741ec628cd100090d993802`.
The result does not distinguish a Pi-to-FCU electrical fault from FCU-side
request handling. The next separately gated decision is the T1
`BRD_SER1_RTSCTS` link-configuration change, not another identical full-pull
retry. The operator then confirmed the FCU/control electronics and Herelink
off, with propulsion power isolated, propellers removed and the hull restrained.
This closed the 20/08/2026 physical hardware day; no approval carries forward.

On 21/08/2026, revision `2600ea4` was deployed to a new certified Pi root and
`BRD_SER1_RTSCTS` was changed from `Auto (2)` to `0` before reboot. The first
guarded run connected disarmed in `MANUAL`, but automatic and forced parameter
pulls still received no response. The second run started armed and stopped at
the connected-and-disarmed gate before the parameter pull, bridge or command
publisher started. Both runs ended `status=1 cleanup_rc=0`; the dashboard
command path did not start and no RC override, motor command or thrust command
was issued by the repository pipeline. The workstation capture retained valid
state events but no verdict and is classified `PARTIAL_UNFINALIZED`. The copied
Pi evidence archive verified at
`d913d296c4aecd34ca305339ed1a9591215a75c061dec7552567f647df3643a7`.
`BRD_SER1_RTSCTS=Auto (2)` was restored and read back, and the operator then
confirmed the Pi, FCU/autopilot, control electronics and Herelink off, with
propulsion power isolated, propellers removed and the hull restrained. T0b
remains open, neither T2 tier earned acceptance and no physical approval
carries forward.

The expanded camera viewer owns pointer and keyboard focus while open. It now
contains its own E-Stop button, so the explicit FCU bench stop path remains
reachable without closing the viewer. The button stays inert in the ordinary
live view and is enabled only by the opt-in bench URL.

Keyboard Hold to Apply stops on button blur as well as key release, window blur
and page hiding, so moving focus with Tab cannot leave its interval active. The
first-run onboarding backdrop is visual only and cannot intercept pointer
events; its card remains interactive above the page.

On 17/07/2026, two runs from the clean, pushed workstation checkout on
`IoT IMT Nord Europe` proved six-topic arrival and automatic rate measurement;
both had operator-confirmed combined Hailo and MAVLink browser output.
Each printed Pi command verified the deployed helper checksum before launch.
The Hailo image measured `7.40 Hz` and `7.50 Hz`, and each MAVROS topic measured
approximately `1.00 Hz`. The detailed stale, disconnect, and inert-control
behaviour matrix retains automated coverage but was not deliberately exercised
in full during those live runs. In both runs the workstation dashboard stack
became unavailable unexpectedly before the intended Pi-first stop, without
deliberate operator intervention. Its cause remains open; clean Pi-first normal shutdown
was obtained on 03/08/2026 and repeated on 04/08/2026. Follow
[Live Hailo and MAVROS Dashboard
Testing](../../wiki/Live_Hailo_MAVLink_Dashboard_Testing.md) for the isolated
two-command service order and safety boundary. For the separate RealSense
camera-only check, use [RealSense Dashboard
Testing](../../wiki/RealSense_Dashboard_Testing.md). Do not use dashboard
mission or thruster controls against the real FCU until the command path is
separately validated.

## Quick Start

### Option A: Simulation One-Click Launch

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_autoboat_complete.sh
```

Then open **<http://localhost:8002>**.

> **Hybrid-graphics laptops (NVIDIA Optimus / PRIME):** append `--use-nvidia` to route Gazebo through the discrete GPU. Without it the iGPU fallback can throttle Gazebo heavily — see [`wiki/Common_Issues.md`](../../wiki/Common_Issues.md) section *Gazebo Running Slow* for diagnosis + measured figures + canonical recipe.

### Option B: Manual Launch (5 Terminals)

| Terminal | Command                                                                                        | Purpose                       |
| -------- | ---------------------------------------------------------------------------------------------- | ----------------------------- |
| T1       | `ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT`                       | Gazebo simulation             |
| T2       | `ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0`      | WebSocket bridge (port 9090)  |
| T3       | `ros2 run web_video_server web_video_server`                                                   | Camera stream (port 8080)     |
| T4       | `ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml`                             | Navigation system             |
| T5       | `cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat && python3 serve_dashboard.py 8002`        | Dashboard (port 8002)         |

> **Important:** The installed Jazzy launch file currently defaults
> `delay_between_messages` to `0.0`; the simulation command keeps it explicit.
> Do NOT open `index.html` directly as a file (`file://`). Serve it via HTTP for WebSocket to work.

### Real-Hardware View-Only Diagnostic

Do not use the simulation one-click launcher for live Hailo/MAVROS testing.
Follow [Live Hailo and MAVROS Dashboard
Testing](../../wiki/Live_Hailo_MAVLink_Dashboard_Testing.md). Run
`tools/live_dashboard_preflight.sh run` on the workstation, then paste its
complete printed command in a new terminal opened from the active Pi desktop or
Remmina session; do not use an SSH-only terminal. The terminal must have a nonempty
`DISPLAY`. The printed command selects `HAILO_LOCAL_DISPLAY=1` and
`HAILO_LOCAL_WINDOW_MODE=fullscreen`, which opens the existing annotated Hailo window
fullscreen on the Pi while the same annotated topic continues to the workstation
dashboard. Direct helper use defaults to a resizable local window when display is
enabled. These new window modes still require live acceptance.
The supervisor starts rosbridge,
`web_video_server`, and the dashboard, waits for all six topics, and records the
automatic rate probes. Transfer only the tracked
[`pi_live_hailo_mavlink_dashboard.sh`](../../tools/pi_live_hailo_mavlink_dashboard.sh)
when its Pi checksum differs; never deploy the workstation preflight to the Pi.
Open the browser only after `PI_SOURCE_STACK_READY=PASS` on the Pi and
`PI_DATA_ARRIVED=PASS` on the workstation. For shutdown, follow the full
runbook: first require workstation `W5_RATE_PROBES=PASS` plus Pi
`COMMAND_SENTINEL=PASS`, `PI_SOURCE_WINDOW=COMPLETE`, and
`PI_SOURCE_HOLD=ACTIVE`; stop the Pi and require
`PI_SOURCE_HOLD=STOP operator-requested`, `TEARDOWN=PASS`, and a successful
`PI_SUPERVISOR_EXIT` in the Pi run directory's `supervisor.log`; then stop the
workstation and require `WORKSTATION_TEARDOWN=PASS`. Treat any MAVROS topic marked
`Stale` as a failed diagnostic even if another topic continues updating.

### Guarded Physical-FCU Helper Pair

The physical command/feedback loop is deliberately separate from the Hailo
view-only helper and from the domain `42` localhost-only SITL graph. Both
physical halves use domain `43`. The workstation and Pi `check`, `run-t2a` and
`run` paths use subnet discovery; only the standalone Pi `probe` path uses
localhost discovery. The two entry points are:

```text
tools/real_fcu_digital_twin_workstation.sh check|run
tools/real_fcu_digital_twin_pi.sh check|probe|run-t2a|run
```

`check` performs bounded preflight and static verification without starting the
loop. `probe` is the separately approved T0b request/response and safety-state
check: the helper issues reads only, and localhost discovery prevents off-Pi
participants from reaching the write-capable services advertised by its MAVROS
plugins. After one forced MAVROS cache pull, it retains the three safety
parameters, both `RCMAP_*` values, all `SERVO1..16_FUNCTION` values and the
resolved RC and servo rails as a validated `41`-parameter T0b artifact.
`run-t2a` requires T2a approval while rejecting T2b approval;
it creates the guarded RC-override publisher, creates no bridge subscription to
browser demand, accepts no non-neutral demand and publishes the resolved live RC
trims while armed. T2a acceptance must separately compare the observed output
values against the live servo trims retained by T0b; the capture verdict does
not perform that equality check by itself. `run` requires both T2 approvals and
enables the separately approved closed-loop demand path. Neither mode arms,
disarms, changes mode, writes parameters or issues a software safety release.
Those actions remain outside the helpers, and external disarm is required before
stopping them.

The separately started workstation capture helper is:

```text
tools/real_fcu_command_feedback_capture.py t2a|t2b [--output-root PATH]
```

Its application surface consists only of subscriptions for
`/command_ingress/rc_axes`, `/command_ingress/status` and `/mavros/state`;
ROS logging and parameter services are disabled. One global JSONL stream gives
every message a sequence number plus uniform Unix and monotonic receipt times;
the Joy and MAVROS State source-header times are also retained. Bridge status
has no source header, so its source time is recorded as null rather than
inferred. The Joy subscription matches the bridge's best-effort, depth-one QoS,
and MAVROS State uses best-effort at depth ten so it can receive either offered
reliability. Bridge status retains the reliable default that matches its
publisher. Diagnostics are written to a separate log and never merged into the
evidence stream. On operator stop, an atomic verdict requires an armed FCU
sample, structurally valid phase evidence, the tier's ordered bridge-state
sequence, tier-matched authority and a final connected, disarmed `MANUAL`
status and FCU state. T2a fails if any command frame was observed; T2b fails if
none was observed, and any ROS cleanup error fails the retained verdict. The
helper creates no application publisher, service client or controller-write
path and is not a member of the four-file Pi deployment bundle.

Deploy the Pi helper, command bridge and both physical MAVROS allowlists with
their `tools/` and `config/` layout intact. The exact four-file set is pinned by
`config/real_fcu_digital_twin_bundle.sha256`. Do not add the physical command
bridge or any FCU write path to `tools/pi_live_hailo_mavlink_dashboard.sh`; it
remains the established view-only Hailo/telemetry path. Its default-off
FCU-to-VRX option copies received raw MAVLink datagrams outward only and does
not filter message classes. Its enforced boundary is outbound-only direction
with local-only ingress; it does not change the FCU command boundary.

No physical mode is currently accepted for routine use. The guarded one-off
Test A path was operator-accepted on 26/08/2026 after a hash-pinned parameter
snapshot resolved `RC1`/`RC3`, left `SERVO3`, right `SERVO1` and both
`800/800/2200` output rails. The dashboard requested steering `0.05` and
throttle `0.04`; measured RC input changed to `1564/1470 us`, measured output
changed from `800/800 us` to `911/800 us`, and release restored `800/800 us`.
Both supervised halves ended connected and disarmed with successful ordered
teardown. This is bounded real-FCU command/output-feedback evidence with
propulsion isolated, not approval for routine use or physical thrust.
Herelink-to-VRX Test B has demonstrated functional motion, but its externally
interrupted run did not retain the required final safe lifecycle and is not
formally accepted. A later guarded dashboard run on 28/08/2026 reached both
READY markers and clean connected/disarmed teardown. The operator corrected
that active interval to propellers fitted and reported limited one-sided
rotation, but only neutral RC/output snapshots were retained. It is therefore
an Enhanced Test A props-fitted functional observation. The launch assertion
`REAL_FCU_PROPELLERS_REMOVED=1` was inaccurate for that interval; the run is
neither T2b nor T3a acceptance. Exact steering `+/-0.20` is currently rejected
after `float32` transport slightly exceeds the bridge's exact bound.

**Forward repair 31/08/2026:** the command bridge now normalizes only the exact
float32 encoding of each configured steering or throttle endpoint. The next
adjacent float32, materially larger requests and any negative throttle remain
rejected, while an enabled endpoint is covered through paired override
publication. The configured `0.20` steering and `0.12` throttle limits are
unchanged. The focused bridge suite passes `36` tests. The bridge bundle
manifest changed, so these bytes still require current-source SITL acceptance,
transfer and checksum verification before any later Pi use; this is not live
hardware evidence.

**Current-source closure later 31/08/2026:** clean revision
`bba195b19a0f06a874bfbcbcbbd1621524cbce60` passed the complete supervised
SITL acceptance in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839`
and independent adjudication retained at
`/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log`.
The SITL requirement for these repaired bytes is closed. Transfer and checksum
verification of the regenerated bundle must still be established separately
before Pi use; this is still not live hardware evidence.

**Pi deployment closure later 31/08/2026:** the regenerated manifest and four
governed members were installed at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260831_bba195b`. Exact
inventory, the manifest digest and all four governed hashes passed before the
non-actuating helper check ended
`REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The verified
workstation copy-back is
`/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260831_bba195b`.
This closes bundle transfer/checksum certification only; no probe, MAVROS or
bridge runtime, parameter write, arm or propulsion action ran.

The temporary `RC_OVERRIDE_TIME=0.5` setting was subsequently restored to
`3.0`. The live before/after readbacks and `986`-parameter rollback snapshot
are retained under
`/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828`; the
snapshot SHA-256 is
`a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`.

### FCU Bench Command/Feedback Component

This component is separate from the view-only helper and from the normal
simulation controls. Its two dashboard rows have deliberately different
provenance:

| Row | Source | Meaning |
| --- | --- | --- |
| Requested RC Demand | bridge status | The bounded steering/throttle pair accepted from the browser |
| Measured Motor Output | `/mavros/rc/out` plus bridge rail resolution | Raw PWM and signed position within each function-resolved output rail; not physical force |

The narrow browser publisher exists only when the page is opened with:

```text
http://127.0.0.1:8002/?enable_fcu_bench_control=1
```

Without the query value, the page subscribes to status but creates no command
publisher. This URL is not approval to run a physical test. A physical run also
requires a disarmed startup, a working bidirectional serial path, complete live
parameter responses, propellers removed, restrained hull, controlled propulsion
power, and the separately approved arm and input phases.

## Dashboard Panels

| Panel                      | Description                                                                      |
| -------------------------- | -------------------------------------------------------------------------------- |
| **Connection Status**      | WebSocket connection indicator (green/red)                                       |
| **GPS Position**           | Latitude, longitude, local X/Y coordinates                                      |
| **Live MAVLink Diagnostic** | Six direct MAVROS feeds with independent ages and stale-value clearing         |
| **FCU Bench Digital Twin** | Opt-in paired RC demand beside separately measured function-resolved PWM feedback |
| **Mission Status**         | State badge, waypoint progress, distance, speed, time remaining                 |
| **Mission Control**        | Generate, Confirm, Start, Stop, Resume, Emergency Stop, Go Home, Reset          |
| **Obstacle Detection**     | Front/Left/Right clearance with urgency scores and status badge                 |
| **Thruster Output**        | Left/Right thrust with visual bars                                              |
| **Anti-Stuck Status**      | Escape mode, live direction (LEFT/RIGHT/IDLE), front clearance, drift vector, Kalman sigma |
| **Trajectory Map**         | Interactive Leaflet map with boat position, waypoints, trajectory               |
| **Main Configuration**     | PID gains, speed, safe distance, waypoint tolerance, A\* settings                |
| **Perception Configuration**      | 12 perception params with 4 presets (Universal, Buoy Field, Pier Detect, Open Water) |
| **Controller Configuration**    | 14 control params (safety distances, avoidance, anti-stuck, slew rate)          |
| **Health Check**           | Live streaming 49-check system diagnostic with elapsed time                     |
| **System Logs**            | Timestamped, color-coded log entries                                            |
| **ROS2 Terminal**          | Direct ROS2 command output                                                      |
| **Camera Feed**            | One MJPEG image with topic combobox, in-place Enlarge, bounded zoom, Reset, Close, Escape, focus trapping, and error recovery |

## Configuration System

### Three Separate Apply Buttons

Each section sends only its own parameters. With dirty-params filtering, only fields the user actually changed are sent:

| Button           | Parameters                                          | Target Nodes    |
| ---------------- | --------------------------------------------------- | --------------- |
| **Apply Config** | PID, speed, lanes, waypoint tolerance, A\* settings  | Planner + Controller |
| **Apply Perception** | Height/range filters, clustering, temporal | Perception           |
| **Apply Controller** | Safety distances, avoidance gains, anti-stuck, slew | Controller         |

All three publish to `/planning/set_config`. Each node picks out only the keys it recognizes.

### Safety Features

- **Apply buttons start disabled** — enabled only after first ROS config sync arrives
- **Dirty-params filtering** — only changed fields are sent (prevents overwriting unchanged params)
- **Reset Defaults** — restores launch file values and marks fields dirty (prevents ROS sync race)

### Parameter Sync (1 place)

`autoboat.launch.yaml` is the single source of truth for runtime defaults. Each
node's `_publish_param_ranges` lazy-captures launch-time `get_parameter()` values
into a `[min, max, default]` 3-tuple per param and publishes on `/<ns>/param_ranges`.
The dashboard's `applyRangesToDashboard` writes the 3rd element into `liveDefaults`,
which `getCanonicalDefault` then reads when painting `(default: X)` hints and when
Reset buttons fire. `index.html` `value="…"` attributes are cosmetic-only (initial
paint before ROS sync) — change them only if the unconnected-page snapshot matters.

### Tunable contract (`PARAM_RANGES` vs launch-only)

Only params in a node's `PARAM_RANGES` class-level dict are dashboard-tunable.
`PARAM_RANGES` is what gets published on `/<ns>/param_ranges` and consumed by
the dashboard. Params declared via `self.declare_parameter()` but absent from
`PARAM_RANGES` (e.g., `kalman_*` in `heading_controller`, `hull_radius` /
`max_block_time` / `plan_avoid_margin` / `waypoint_skip_timeout` in
`waypoint_planner`, `sample_rate` / `vfh_*` in `lidar_perception`) are
intentionally launch-time-only — configured via `autoboat.launch.yaml`, not
exposed on the dashboard; direct `ros2 param set` behavior is node-specific
and may not affect already-cached runtime attributes. This keeps the operator
surface focused on field-tunable knobs and avoids surfacing internal /
algorithmic tuning as field footguns.

To promote a launch-only param to dashboard-tunable, wire all eight surfaces:
`PARAM_RANGES` range tuple + node `config_callback` branch + `PARAM_TO_INPUT_IDS`
in `app.js` + apply function's local `idMap` (`controllerIdMap` /
`perceptionIdMap` / `mainIdMap` in `sendConfig`) + apply function's `fullParams` +
`allConfigInputs` (dirty-state listener) + `updateXxxInputs` guarded set +
matching `<input>` in `index.html`. Add the DOM-id to `PRESET_INPUT_IDS` too if
presets should diff/flash this field.

### Known Parameter Collisions (Resolved)

Perception and Controller share the `/planning/set_config` topic. Parameters with the same name would collide:

| Parameter           | Resolution                               |
| ------------------- | ---------------------------------------- |
| `min_safe_distance` | Perception renamed to `perception_min_safe_distance`   |
| `critical_distance` | Perception renamed to `perception_critical_distance`   |

## Mission Workflow

1. Open dashboard, wait for **Connected** (green) and GPS coordinates
2. Set lanes/length/width in Route Configuration
3. Click **Generate Waypoints** — waypoints appear on map, state -> WAITING_CONFIRM
4. Click **Confirm Waypoints** — state -> READY
5. In a write-enabled simulation build, click **Start Mission** and confirm the prompt
   — state -> DRIVING, boat navigates. The shipped
   `LIVE_MAVLINK_VIEW_ONLY=true` build keeps this control inert and disabled.
6. Monitor: waypoint progress, obstacle clearance, trajectory on map

### Controls During Mission

| Button             | Action                                                          |
| ------------------ | --------------------------------------------------------------- |
| **Stop**           | Pause mission, zero thrust                                      |
| **Resume**         | Continue from current waypoint                                  |
| **Emergency Stop** | Simulation mode: cut thrust and latch stop; the two shortcut badges scroll to the main button. FCU bench mode: the main button, both shortcuts and the expanded-camera button publish the direct latched bridge E-Stop immediately. |
| **Go Home**        | Navigate back to spawn point                                    |
| **Reset**          | Clear waypoints, return to INIT                                 |

In a write-enabled simulation build, Start, Resume, Go Home, Reset, and Emergency Stop
prompt before acting, while Stop acts immediately. In the shipped
`LIVE_MAVLINK_VIEW_ONLY=true` build these Mission Control actions are inert and disabled,
so their prompts and blocked-write handlers are not reachable by clicking. The explicit
FCU bench E-Stop is the exception: it is re-enabled by the bench URL and latches without
a confirmation prompt.

## ROS Topics

### Subscribed (Read)

| Topic                          | Data                                 |
| ------------------------------ | ------------------------------------ |
| `/mavros/global_position/raw/fix` | GPS position in the temporary live MAVLink view |
| `/planning/mission_status`     | State, waypoint, progress            |
| `/planning/waypoints`          | Waypoint list for map                |
| `/planning/current_target`     | Current navigation target            |
| `/perception/obstacle_info`    | LiDAR obstacle detection (JSON)      |
| `/control/status`              | Heading controller status, including the `person_stop` hold and the `forward_only` hull flag |
| `/control/anti_stuck_status`   | Anti-stuck escape status             |
| `/planning/config`              | Current config values (syncs fields) |
| `/wamv/thrusters/left/thrust`  | Left thruster command feedback       |
| `/wamv/thrusters/right/thrust` | Right thruster command feedback      |
| `/command_ingress/status`   | Guarded bridge state, live mapping and rails, request and measured RC/servo PWM feedback |

The live MAVLink thrust row defaults to the real boat's measured output mapping
(`SERVO3` left, `SERVO1` right). For another connected vehicle, first resolve
functions `73` and `74` from its live `SERVO*_FUNCTION` values, then open the
dashboard with those resolved channels, for example:

```text
http://127.0.0.1:8002/?thrust_left_servo=1&thrust_right_servo=3
```

This temporary view-only row remains raw PWM and does not infer a percentage or
physical thrust. The separate FCU Bench component can show a configured-rail
percentage because its guarded bridge supplies the live rails with the measured
PWM; it still does not estimate physical force.

The current temporary view-only build does not subscribe to the VRX simulation GPS
topic. Simulation GPS and map updates require restoring that subscription in a
simulation build.

### Published (Write)

| Topic                      | Data                                           |
| -------------------------- | ---------------------------------------------- |
| `/planning/set_config`      | Parameter updates (JSON)                       |
| `/planning/mission_command` | Mission commands (start, resume, go_home, etc.) |
| `/planning/emergency_stop`  | Latched Bool; normal mission E-Stop, plus the opt-in direct FCU bench stop |
| `/wamv/thrusters/left/thrust`  | E-Stop zero-thrust command (`0.0` only; blocked while `LIVE_MAVLINK_VIEW_ONLY=true`) |
| `/wamv/thrusters/right/thrust` | E-Stop zero-thrust command (`0.0` only; blocked while `LIVE_MAVLINK_VIEW_ONLY=true`) |
| `/command_ingress/rc_axes` | Opt-in paired steering/throttle `sensor_msgs/Joy`; created only by the FCU bench URL |

`LIVE_MAVLINK_VIEW_ONLY` continues to block mission, configuration and generic
thrust-topic writes. The two explicit exceptions under
`?enable_fcu_bench_control=1` are the bounded paired RC-demand topic and its
direct E-Stop topic.

### Called (Service Clients)

| Service                          | Type                 | Purpose                         |
| -------------------------------- | -------------------- | ------------------------------- |
| `/planning/stop_mission`         | `std_srvs/Trigger`   | ACK-based stop                  |
| `/planning/generate_waypoints`   | `std_srvs/Trigger`   | ACK-based waypoint generation   |

## Files

| File                          | Description                                |
| ----------------------------- | ------------------------------------------ |
| `index.html`                  | Dashboard structure, input fields, panels  |
| `app.js`                      | ROS connection, data handling, config logic |
| `style_merged.css`            | Unified stylesheet                         |
| `README_autoboat_dashboard.md` | This file                                  |
| `../../tools/real_fcu_rc_command_bridge.py` | Default-inhibited MAVROS RC bridge and measured-output status |
| `../../tools/real_fcu_command_feedback_capture.py` | Subscriber-only ordered evidence capture for the physical bench tiers |
| `../../tools/real_fcu_digital_twin_workstation.sh` | Loopback rosbridge/dashboard supervisor for the guarded physical loop |
| `../../tools/real_fcu_digital_twin_pi.sh` | Direct-serial T0b probe and separately gated physical-loop supervisor |
| `../../tools/test_real_fcu_digital_twin_helpers.sh` | Focused static contract suite for both physical helpers |
| `../../config/mavros_real_fcu_digital_twin_plugins.yaml` | Minimal MAVROS plugin allowlist for the SITL runner |
| `../../config/mavros_real_fcu_t0b_plugins.yaml` | Two-plugin read-only T0b MAVROS allowlist |
| `../../config/mavros_real_fcu_closed_loop_plugins.yaml` | Five-plugin physical closed-loop MAVROS allowlist |
| `../../config/real_fcu_digital_twin_bundle.sha256` | Exact Pi deployment bundle paths and SHA-256 pins |

## Troubleshooting

> **Offline / no-internet deployment** (including the `IoT IMT Nord Europe` link used for live Hailo/MAVROS testing): `roslib`, Leaflet (JS + CSS + images), and Google Fonts are vendored under `vendor/` as of 05/05/2026, so the dashboard libraries self-load without internet. OpenStreetMap tiles still come from the public tile server; without internet the map background is missing, though boat markers / waypoints / path overlays can still draw. Roadmap §1.3 Path B tracks the required offline tile server and pre-generated MBTiles work before field deployment.

| Problem                           | Solution                                                              |
| --------------------------------- | --------------------------------------------------------------------- |
| Dashboard shows "Disconnected"    | See diagnostic steps below                                            |
| Port 9090 in use                  | Stop the owning launcher or supervisor; identify the listener with `ss -ltnp 'sport = :9090'` |
| Apply buttons stay grey           | Nodes not publishing `/planning/config` — check navigation is launched |
| Reset then Apply sends old values | Fixed — Reset now marks inputs dirty to prevent ROS sync race         |
| Camera feed not showing           | Check `web_video_server`; for Pi RealSense use the loopback-only procedure in `wiki/RealSense_Dashboard_Testing.md` and compare the direct MJPEG URL before changing the camera launch |
| Map tiles not loading             | Requires internet for OpenStreetMap tiles. For offline deployment see Roadmap §1.3 Path B (offline tile server). |
| ROSLIB not defined (console)      | Vendored roslib failed to load — check `vendor/roslib/roslib.min.js` and browser console (F12). |
| Half the page missing             | Vendored dashboard asset failed to load — check `vendor/roslib/`, `vendor/leaflet/`, and browser console (F12). |
| Parameter collision               | Perception params prefixed with `perception_` (e.g. `perception_critical_distance`) |

### Dashboard "Disconnected" Diagnostics

Run these checks in order:

```bash
# 1. Is rosbridge listening?
ss -tuln | grep 9090
# Should show LISTEN. If empty → rosbridge not running.

# 2. Is ROS_DOMAIN_ID the same in every terminal?
echo $ROS_DOMAIN_ID
# Must match in ALL terminals. Mismatch = rosbridge can't see ROS topics.

# 3. Can rosbridge see the ROS topics?
ros2 topic list | grep planning
# Should show /planning/mission_status. If empty → domain mismatch or nodes crashed.

# 4. Is the dashboard HTTP server running?
ss -tuln | grep 8002
# Should show LISTEN.

# 5. Check browser console (F12 → Console) for:
#    - "Failed to load resource: roslib.min.js" → missing vendored asset or wrong path
#    - "WebSocket connection failed" → rosbridge not running or port blocked

# 6. Firewall?
sudo ufw status
# If active: sudo ufw allow 9090/tcp && sudo ufw allow 8002/tcp && sudo ufw allow 8080/tcp
```

## Security

The dashboard currently has **no authentication, encryption, or access control**. With the default all-interface launch posture, all 3 ports (8002, 9090, 8080) are accessible to any device on the same network.

This is acceptable for local simulation but poses risks on shared networks or field deployments. See **[wiki/Dashboard_Security.md](../../wiki/Dashboard_Security.md)** for the full security assessment, known vulnerabilities, and recommended mitigations.

**Quick safety measure for shared networks:**

```bash
# Bind dashboard to localhost only (prevents remote access)
python3 serve_dashboard.py 8002 127.0.0.1
```

## License

Part of the uvautoboat project — Apache License 2.0.

Built with [roslibjs](http://robotwebtools.org/), [Leaflet.js](https://leafletjs.com/), [OpenStreetMap](https://www.openstreetmap.org/).

Last updated: 31/08/2026
