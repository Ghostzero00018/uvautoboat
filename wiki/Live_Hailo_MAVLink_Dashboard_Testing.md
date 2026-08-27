# Live Hailo and MAVROS Dashboard Testing

Block C has two sequential phases. C1 uses two foreground commands for the live,
view-only dashboard demo. The workstation supervisor starts rosbridge,
`web_video_server`, and the dashboard, then prints the complete Pi command. The Pi
helper owns MAVProxy, MAVROS, Hailo, and the D435I. C2 is a real-FCU arm/disarm
observation performed only after the complete C1 Pi-first teardown; it runs no
repository helper.

The image and telemetry paths are separate:

- `web_video_server` subscribes to `/hailo/overlay/image_raw` and serves MJPEG to the
  browser;
- rosbridge carries the six direct MAVROS subscriptions used by the temporary state,
  GPS, IMU, battery, RC-input and thrust-output panel.

The expanded camera viewer is accepted only while `LIVE_MAVLINK_VIEW_ONLY=true`. Its
full-screen overlay and focus trap cover the current E-Stop button and shortcuts. Do not
reuse it in a write-enabled build until an operational E-Stop remains reachable by
pointer or keyboard without closing the viewer.

Do not use `one_click_launch_all/launch_autoboat_complete.sh` for this test. It starts
Gazebo and navigation nodes. Do not deploy or run the workstation preflight on the Pi;
the retained `pi` wrapper mode is not part of this procedure.

## Current tracked revisions

The repository artifacts below identify the current revisions, pinned on
26/08/2026 after the default-off armed-observation selector, parameterized
emitter and read-only correlation recorders were added. The tracked Pi helper
is the copy that must be transferred to the Pi Desktop before a run; a
previously transferred copy is stale until its hash is checked against the
value below. The workstation supervisors and evidence recorder remain
workstation-only. Separately pinned historical session artifacts are retained
below only for traceability.

| Item | Value |
| --- | --- |
| Helper source | `tools/pi_live_hailo_mavlink_dashboard.sh` |
| Helper Pi destination | resolved Pi Desktop: `$(xdg-user-dir DESKTOP)/pi_live_hailo_mavlink_dashboard.sh` |
| Helper size | `92,101` bytes |
| Helper SHA-256 | `8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c` |
| Workstation supervisor | `tools/live_dashboard_preflight.sh` |
| Supervisor size | `36,413` bytes |
| Supervisor SHA-256 | `2a272106b47f1b6988a01fe5f7fcc536e66aad3889b86c538b699a77e58cd90b` |
| VRX supervisor | `tools/fcu_to_vrx_workstation.sh` |
| VRX supervisor size | `26,694` bytes |
| VRX supervisor SHA-256 | `333ea19f78c640b0b04e9767fc4bcea340a48a5d8e6343571c4d0214bfd76535` |
| Correlation recorder | `tools/fcu_to_vrx_evidence.py` |
| Correlation recorder size | `35,542` bytes |
| Correlation recorder SHA-256 | `464d8f91684d83bf00162afe598d1175976f1a29e1ef9dfb8ec5a640a84cd4b6` |

Historical 23/07/2026 session artifacts:

| Item | Size | SHA-256 |
| --- | ---: | --- |
| `p0_pi_window_probe.sh` | `8,089` bytes | `9bfb2da6ea8ee851942534bc0acf9b38736022625ad29312a3a953601d8183a4` |
| `run_p0_pi_window_probe.sh` | `4,093` bytes | `c80e3745f5efa4a9d404792772a7c44bd7da51a283b85cc836e3f13b1be48ce3` |
| `run_pi_live_window_phase.sh` | `4,862` bytes | `00de43ca98738f538d6ba52c92a94d207a590ec0429691c0aa4be4ad2ea76abc` |
| `p2_xwininfo_checkpoint.sh` | `10,542` bytes | `292e21dd705ae47355531e403f2bd01aa3792e5c2dbf30241696305c0e9f337e` |

These four files are not repository revisions. Their hashes are retained only to identify
the prepared and executed evidence chain. Do not transfer or execute them for another
Pi-window run.

The helper retains its finite `120`-second evidence window and uses
`LIVE_HOLD_AFTER_WINDOW=1` for the monitored demonstration hold. A transient MAVProxy
link-down line does not bypass the finite heartbeat deadline. HEFs, calibration data,
the Hailo runtime tree, and generated logs remain outside this repository.

Direct helper calls default to `HAILO_LOCAL_DISPLAY=0` and retain `--no-display`.
When local display is enabled, `HAILO_LOCAL_WINDOW_MODE` defaults to `resizable`.
The tracked supervisor defaults to `HAILO_LOCAL_DISPLAY=1` and
`HAILO_LOCAL_WINDOW_MODE=fullscreen`, and keeps the normal display path.
Window outcome tracking remains through `HAILO_LOCAL_WINDOW` markers:
`READY`, `FALLBACK_HEADLESS`, `FALLBACK_RESIZABLE`, and `EVIDENCE_UNAVAILABLE`.

`LIVE_FCU_TO_VRX_FANOUT` defaults to `0`. Setting it to `1` adds a separately
gated, outbound-only raw MAVLink copy for the current `WORKSTATION_IP` on UDP
`14555`. MAVProxy still sends only to loopback:
`14550` for MAVROS and `14556` for a run-owned forwarder. That forwarder reads
only the loopback ingress and sends each datagram through a separate socket; it
never reads workstation return traffic and therefore creates no return route to
MAVProxy or the FCU. It does not filter MAVLink message classes: the enforced
properties are outbound-only direction and local-only ingress.

`LIVE_ARMED_OBSERVATION` defaults to `0`; at that default, the existing
`FCU_ARMED` abort remains unconditional and the emitted Pi command retains
`LIVE_HOLD_AFTER_WINDOW=1`. Setting it to `1` is accepted only with fanout
enabled and explicit positive max-window, final-verification and staleness
limits plus both live-read channel and complete min/trim/max rails. The emitter
then sets `LIVE_HOLD_AFTER_WINDOW=0`, passes the helper's channel/trim values,
and starts the domain-12 subscriber-only recorder for `/mavros/state`,
`/mavros/sys_status`, `/mavros/rc/out` and `/hailo/overlay/image_raw`.

The helper's subscriber-only safety monitor permits one bounded armed window
only after the supervisor has proved fresh connected/disarmed telemetry,
neutral output, hardware safety ON, an empty command sentinel and the complete
pre-ready graph. It fails closed on an armed startup, a second arm, disconnect,
stale required telemetry, deadline, command publication, or failure to return
to connected/disarmed neutral output with hardware safety restored. The
selector, emitter and recorder implementation has passed the offline suite.
The separate dashboard-to-real-FCU Test A passed on 26/08/2026; the enabled
Herelink-to-VRX Test B remains **NOT RUN**.

Before enabling the selector, read `BRD_SAFETY_DEFLT` in the open T0b parameter
check and observe the live hardware-safety state. Stop if hardware safety is
disabled, absent, or never reaches the required safe state. Observe a stable
disarmed `/mavros/rc/out` pair before supplying the exact live-read trims; a
reported `0` is not an accepted substitute for a PWM trim in `800..2200`.
Measure the update cadence of every required monitor topic over the real serial
link, then supply an explicit `LIVE_ARMED_OBSERVATION_STALE_SECONDS` value to
the emitter. The emitter deliberately does not inherit the helper's direct-call
default. A baseline that does not become ready is a stop condition, not
authority to weaken these gates.

### Current-source dashboard and SITL acceptance - 26/08/2026

Commit `3ca6b0b` passed the complete supervised simulator/dashboard path in
`/home/ghostzero/Desktop/sitl_digital_twin_20260826_174115`. The run resolved
steering/throttle as `RC1`/`RC3` and left/right output as `SERVO1`/`SERVO3`,
captured the disarmed baseline, browser disabled frame, arm, positive demand,
neutral release, negative demand, E-Stop and disarm, then reported
`SITL_VERDICT=PASS` with `cleanup_rc=0` and `finalize_rc=0`.

Independent adjudication checked ten evidence hashes and the stop order
`dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl`. It reported
`CONTROL_CROSSCHECK=PASS`, `VERDICT_CHECK=PASS`, `TEARDOWN_CHECK=PASS`, all
governed ports free, no surviving governed process and
`SITL_ADJUDICATION=PASS`. At the time it was recorded this closed the
current-source simulator acceptance precondition only; it was never real-FCU
forwarding, parameter, thrust or motion evidence.

**Forward correction 27/08/2026:** that acceptance is no longer current-source.
It was earned on `3ca6b0b`; `81efb73` later changed
`tools/real_fcu_rc_command_bridge.py`, the bridge `tools/sitl_digital_twin_runner.sh`
launches under test, and no `SITL_VERDICT` or `SITL_ADJUDICATION` has been
recorded against a revision containing that change. The query tier (T0b) also
remains open. Both must close on current source, or receive an explicit operator
supersession, before Test B.

The Pi helper copied to `/home/imt-aqua-drone/Desktop` also passed its
checksum and `--preflight-only` path. The retained output included
`HAILO_ROS_PREFLIGHT=PASS imports=5 monkeypatch=PASS publisher=RELIABLE` and
`PREFLIGHT_ONLY=PASS hardware=camera,hailo,serial,fcu untouched`. A separately
authenticated `fuser` check returned `1` with no owner for `/dev/ttyAMA0`.
The stripped-environment `rclpy` failure is informational in this test; the
subsequent provenance check resolved `rclpy` from ROS Jazzy and passed.

### Disarmed live fanout attempt and runtime corrections - 26/08/2026

The first real-FCU outbound fanout attempt retained three matching run
directories:

- W1: `/home/ghostzero/Desktop/live_dashboard_workstation_20260826_183120`;
- W2: `/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260826_183138`;
- copied Pi evidence:
  `/home/ghostzero/Desktop/pi_run_evidence/live_dashboard_20260826_183200`.

The Pi forwarder reported outbound-only readiness for workstation UDP `14555`.
W2 reached VRX, recorder and bridge readiness, retained `3,585` JSONL events,
and decoded repeated real `SERVO_OUTPUT_RAW` frames as left `SERVO3=800` and
right `SERVO1=800`. Both mapped thrust values remained `0.0 N`. W2 then stopped
in the required bridge, recorder, VRX order and confirmed UDP `14555` free.
This is live disarmed evidence for UART-to-fanout-to-UDP-to-bridge delivery at
neutral; it is not motion, armed-window or asymmetric-command evidence.

W1 entered its failure hold after one daemonless node snapshot missed the
required workstation graph even though its supervised children and ports
remained up. The workstation check now retries up to three complete snapshots.
It records `WORKSTATION_NODE_SNAPSHOT_RETRY` for a miss and
`WORKSTATION_NODE_RECOVERY=PASS` only when one later snapshot contains all
three required nodes; three misses still fail closed.

The Pi later reached `PI_SOURCE_STACK_READY=PASS`, and its Hailo log recorded
frames `1`, `100`, ... `1900` while the run-owned process remained alive. Final
verification nevertheless obtained three publisher-count-zero graph views and
stopped the helper automatically. The helper now recovers only from that exact
all-zero condition: the run-owned Hailo process group must still be alive and a
fresh reliable `sensor_msgs/Image` with the expected `bgr8` encoding and
`240`-pixel height must be received. Query errors and any nonzero count other
than exactly one remain fatal. A successful recovery records
`HAILO_GRAPH_ZERO_RECOVERY=PASS`; duplicate publishers are never accepted.

Before this run, the current Pi kernel `6.8.0-1062-raspi` detected the Hailo
PCIe device but had no built `hailo_pci` module and therefore no `/dev/hailo0`.
Installing the matching kernel headers triggered the DKMS build for
`hailo_pci/4.24.0`; after loading the module, `/dev/hailo0` existed and
`hailortcli fw-control identify` reported firmware `4.24.0` on `HAILO8L`.

### Hash-pinned parameter snapshot guard

The real-FCU dashboard bridge still defaults to live MAVROS parameter pulls.
An explicit snapshot mode is available only for `run-t2a` or `run` when a
MAVProxy `param save` artifact, its exact lowercase SHA-256 and
`REAL_FCU_GUARD_SNAPSHOT_APPROVED=1` are supplied together. The parser rejects
malformed lines, duplicate names, non-finite values, an incomplete guard and
any unsafe guard value. The previously retained `986`-parameter artifact with
`RC_OVERRIDE_TIME=3.0` is therefore rejected and must not be reused.

For the separately approved bounded test, set `RC_OVERRIDE_TIME=0.5`, confirm
the readback, fetch the complete list, save a new artifact and pin the exact
bytes before starting either supervisor. No parameter may change after the
save. Snapshot mode does not bypass live state: the Pi still starts its
read-only MAVROS probe and requires fresh connected/disarmed state plus the
hardware-safety bit ON before preserving and resolving the artifact. The
snapshot path writes no parameter. After both live tests, restore
`RC_OVERRIDE_TIME=3.0`, confirm the readback and retain a separate rollback
snapshot before the session is accepted.

### Real-FCU dashboard command Test A - 26/08/2026

Test A passed against the real FCU with propulsion isolated, propellers
removed and the hull restrained. The two supervised halves reached:

```text
REAL_FCU_PI_READY=PASS tier=T2b authority=demand-enabled bridge=READY_DISARMED workstation=visible
REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output
```

The run used a `986`-parameter MAVProxy snapshot with
`RC_OVERRIDE_TIME=0.5`, SHA-256
`3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`.
It resolved steering/throttle as `RC1`/`RC3`, left output as `SERVO3`
function `73`, right output as `SERVO1` function `74`, and both servo rails as
`800/800/2200`.

The retained dashboard recording shows neutral requested demand `0.00/0.00`,
RC input `1515/1515 us` and outputs `800/800 us`; an applied steering `0.05`
and throttle `0.04` request; measured RC input `1564/1470 us`; left/right
output `911/800 us`; and a complete return to requested zero and output
`800/800 us` after release. This closes the bounded dashboard demand to
RC-layer command to real-FCU output-feedback path. It does not claim physical
thrust or Herelink-to-VRX delivery.

The Pi and workstation both finished connected and disarmed, exchanged the
ordered stop marker, stopped their supervised children and exited with
`status=0 cleanup_rc=0`. Retained evidence is:

```text
workstation=/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260826_200922
pi-copy=/home/ghostzero/Desktop/pi_run_evidence/test_a_20260826/real_fcu_digital_twin_pi_20260826_201051
video=/home/ghostzero/Videos/Screencasts/Screencast from 2026-08-26 20-15-16.mp4
video-sha256=e4ce7e9ba3f832769cb0cd151f8af28ae90e612db96afaec364dd55a321dc846
```

The copied Pi `guard_snapshot.parm` independently matches the approved
snapshot SHA-256. The run's aggregate manifest retains absolute Pi paths and is
not represented as directly reverified from the workstation copy.

Test B remains **NOT RUN**. The temporary `RC_OVERRIDE_TIME=0.5` value is
retained only for that deferred test. Restore it to `3.0`, confirm the live
readback and retain a rollback snapshot after Test B or before any different
operation. No Test A approval or physical declaration carries into a later
date.

### Isolated FCU-to-VRX workstation half

`tools/fcu_to_vrx_workstation.sh` is the workstation-only owner for the VRX
half of the outbound fanout topology. Its `check` mode runs the focused
configuration, command-construction, process-group lifecycle, production bridge
imports and PWM-mapping tests without starting ROS, VRX, Gazebo, MAVROS or a
hardware link:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
bash tools/fcu_to_vrx_workstation.sh check
```

The production `run` mode has been exercised in disarmed record-only mode and
decoded neutral real-FCU output at `800/800 us`; the armed correlated motion
mode required for Test B remains **NOT RUN**. Every run requires a clean
checkout at `origin/main`, an empty ROS domain `77`, free UDP `14555`, no
simulator/bridge/MAVROS conflict, and all left/right channel and PWM values from
the same live FCU parameter read. It rejects missing values,
duplicate channels, invalid rails, unequal left/right rails that the current
bridge cannot represent, and a non-decimal thrust limit. It then fixes
`ROS_DOMAIN_ID=77`, `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` and
`ROS_LOCALHOST_ONLY=1`, starts `vrx_gz` world `sydney_regatta`, the read-only
VRX recorder and `tools/servo_command_bridge.py`, and keeps
`publish_sensors:=false` and `publish_cmd_vel:=false`. The bridge publishes one
structured `/fcu_to_vrx/servo_output_raw` evidence message for each decoded
UDP `14555` `SERVO_OUTPUT_RAW` frame before publishing the corresponding left
and right thrust values.

The required run variables are
`FCU_VRX_LEFT_SERVO_CHANNEL`, `FCU_VRX_RIGHT_SERVO_CHANNEL`, each side's
`FCU_VRX_*_PWM_MIN`, `FCU_VRX_*_PWM_NEUTRAL`, `FCU_VRX_*_PWM_MAX`, and the
simulator scaling value `FCU_VRX_MAX_THRUST`. Do not populate them from the
historical `3`/`1`, `800`/`800`/`2200` record. The live Block D parameter
artifact is the authority for that run. `FCU_VRX_CORRELATED_OBSERVATION`
defaults to `0`, which leaves the VRX recorder in record-only mode for the
disarmed measurement. Block E requires it to be `1` together with a positive
`FCU_VRX_OBSERVER_STALE_SECONDS` measured during Block D.

Each child receives a separate process group and log. Planned teardown stops
the bridge first so its existing shutdown path publishes zero thrust, then the
recorder, then VRX, and requires UDP `14555` to be free before reporting
`FCU_TO_VRX_WORKSTATION_TEARDOWN=PASS`. The recorder subscribes to the bridge
evidence topic, both thrust topics and a WAM-V pose stream; it creates no ROS
publisher or client. Event capture does not force a disk sync for every topic
callback; the retained stream is explicitly synced when the observer exits.

The 26/08/2026 record-only run left the observer at `WAIT_DATA` with no pose
event among its `3,585` records. The first diagnosis attributed that to a
pose-topic mismatch; a source review on 27/08/2026 established that the topic
was never wrong.

`/model/wamv/pose` is the Gazebo transport name. `vrx_gz` bridges it to the
relative ROS topic `pose` and launches the `ros_gz_bridge` node inside
`PushRosNamespace('wamv')`, so the ROS topic is `/wamv/pose` — the name the
supervisor already passed. The bridge start-up log prints configured
Gazebo-side names on both sides of its arrow and does not report resolved ROS
names: the same log renders the thrust bridge identically, and those topics
carried `1,195` events each in that run. VRX's own `pose_tf_broadcaster`
subscribes to the relative `pose` inside the same namespace, so a bridge
publishing `/model/wamv/pose` would break VRX's own transform tree.

The real defect was the transform selected from that stream. The recorder chose
the first transform whose `child_frame_id` ended in `base_link`, but the WAM-V
`PosePublisher` runs with `publish_link_pose=false` and `publish_model_pose=true`,
so `base_link` appears only as the parent of static sensor transforms and never
as the child of a moving one. The filter matched nothing, the pose stream never
counted as seen, and the observer could not leave `WAIT_DATA`. The recorder now
selects the transform whose parent is the launched world frame, supplied by the
supervisor as `--world-frame`, and records a `pose_frame_mismatch` event naming
the observed parents when no transform matches.

#### Correlation evidence

The two recorders stay in their required domains: the Pi/dashboard recorder in
domain `12` and the bridge/VRX recorder in isolated domain `77`. Both timestamp
events with the workstation realtime clock, so correlation does not require
cross-domain DDS discovery. W1 retains
`fcu_to_vrx_pi_events.jsonl`; W2 retains
`evidence/vrx_events.jsonl`.

After the complete Pi, W2 and W1 teardown, adjudicate the retained files with
explicit limits measured during Block D:

```bash
python3 tools/fcu_to_vrx_evidence.py adjudicate \
  --pi-events "$W1_RUN/fcu_to_vrx_pi_events.jsonl" \
  --vrx-events "$W2_RUN/evidence/vrx_events.jsonl" \
  --max-pwm-skew-ms "$MAX_PWM_SKEW_MS" \
  --max-thrust-delay-ms "$MAX_THRUST_DELAY_MS" \
  --max-motion-delay-seconds "$MAX_MOTION_DELAY_SECONDS" \
  --min-motion-metres "$MIN_MOTION_METRES"
```

The adjudicator has no default acceptance thresholds. It anchors downstream
timing to the bridge's UDP receive timestamp so cross-topic subscriber callback
ordering cannot create a false failure. It requires matching asymmetric PWM
values at dashboard `/mavros/rc/out` and the UDP-decoded bridge frame, mapped
thrust values on both VRX topics, motion above the supplied Block-D drift
threshold, a Hailo frame during the armed window, neutral return, connected
disarm and restored hardware safety. Any recorder abort, missing READY event,
mismatched value or late/missing stage fails adjudication.

#### Start and stop order

Start `W1` (`tools/live_dashboard_preflight.sh run`), then `W2`
(`tools/fcu_to_vrx_workstation.sh run`), then the Pi. The order is not
interchangeable: `W1` rejects any already-running `gazebo` or `gz sim` process,
so starting `W2` first makes `W1` abort with `workstation conflicting process
found`. `W2` permits `W1`'s rosbridge, web-video-server and dashboard
processes, so this direction is the only one that starts cleanly.

`W2` gates in two stages, because three of its four recorder streams originate
from the Pi fanout and cannot exist before the Pi runs.

Start the Pi when `W2` prints its **pre-Pi** marker:

```text
FCU_TO_VRX_WORKSTATION_PRESTART=PASS ... udp=14555-listening observer=started pose=baseline
```

That marker proves the VRX topics including `/wamv/pose`, the recorder's
subscriptions, one recorded pose baseline against the launched world frame, and
a listening UDP `14555`. It is what the rule below is about: `W1`'s
`PI_DATA_ARRIVED` phase samples ROS topics only and does not prove UDP `14555`
arrival, so a Pi started before `PRESTART` can report a passing dashboard phase
while the fanout has no listener.

`W2` then blocks, printing `start the Pi helper now`, until the recorder reports
all four streams:

```text
FCU_TO_VRX_WORKSTATION_READY=PASS ... observer=ready streams=4
```

That **post-Pi** line is the workstation readiness gate, and nothing may be
armed before it. Waiting for it before starting the Pi would deadlock. Its own
budget is `FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS`, default `900` seconds,
because it spans the operator's Pi start.

Stop in reverse: Pi first, then `W2` (bridge, recorder, VRX, then UDP `14555`
confirmed free), then `W1`.

### Batched MAVROS source view

`LIVE_MAVROS_SOURCE_BATCH` defaults to `0`. At the default the six MAVROS source
checks run exactly as before, one `ros2 topic info --verbose --no-daemon --spin-time 2`
process per topic per attempt. Set it to `1` in the Pi terminal before pasting the
compound command to serve those checks instead from one run-owned `rclpy` participant
that spins to accumulate discovery and answers all six topics from a single generation.

The probe budget is split by `LIVE_PROBE_MAX_SECONDS` (default `6`, the outer hard
bound) and `LIVE_PROBE_STARTUP_RESERVE` (default `3`, withheld for interpreter start,
`import rclpy`, participant creation and teardown). The remainder is the spin budget;
the bound must exceed the reserve. Raise both together on a slow host, keeping the bound
larger.

Each probe run records one `MAVROS_SOURCE_PROBE_RUN result=` line, and the helper can emit
five values:

| Value | Meaning | Response |
| --- | --- | --- |
| `OK` | Generation published; carries the `bound`, `settle` and `reserve` actually used | None |
| `TIMEOUT` | The probe hit its own bound. A host startup-margin result, not a deadline result; fails closed and retries | Raise `LIVE_PROBE_MAX_SECONDS` and `LIVE_PROBE_STARTUP_RESERVE` together, keeping the bound larger |
| `INCOMPLETE` | The generation was partial or malformed; the offending topic is named | Keep the raw diagnostics. A defect - do not raise the budgets |
| `FAILED` | The probe ran and produced nothing usable: `reason=cache-unavailable`, a bare `probe_rc=<n>`, `reason=staging`, or `reason=publication` | Keep the raw diagnostics. A defect - do not raise the budgets |
| `SKIPPED` | `reason=deadline-exhausted`: the parent deadline had one second or less left, so the probe was not started. Only reachable while the batched path is active | None; the ordinary retry and verdict path applies |

A view returning `75` is genuine parent-deadline exhaustion, which is a different condition.
A run with the flag off emits **no** `MAVROS_SOURCE_PROBE_RUN` line at all and leaves no
`source_view` cache directory; those two absences together are what identify a flag-off run.
The pre-window self-test is called with a zero deadline, so it can return only success or a
fail-closed error - never `75`.
The removed measurement-only selectors are not part of current runtime commands.

In fullscreen mode, the wrapper waits for the first upstream `imshow` and `waitKey`
cycle before requesting fullscreen, then reads the image rectangle after the next GUI
cycle. Static tests cover this ordering, resizable/headless modes, marker transitions,
callback-rate behavior, request-failure suppression, and defensive read failures. An
operator-run
22/07/2026 attempt observed the frame-gated Pi-local HighGUI `"Output"` window live, but
its rendered image stopped enlarging beyond a ceiling while that Pi window continued to
grow. This is independent of the workstation browser dashboard and its camera viewer.
The only recorded post-request image rectangle was `0,0,400,300`; the wrapper sampled it
once, so the later manual-resize ceiling dimensions remain unmeasured. Pi-local image
scaling remains unmeasured and is parked by the 23/07/2026 closeout.

On 17/07/2026, two runs from the clean, pushed workstation checkout on
`IoT IMT Nord Europe` proved six-topic arrival and automatic rate measurement. Both
runs also had operator-confirmed simultaneous browser delivery. Each printed Pi command
verified the deployed helper checksum before launch. The Hailo image measured `7.40 Hz`
and `7.50 Hz`; each MAVROS topic measured approximately `1.00 Hz`. Both runs completed
their Pi source windows, but the workstation dashboard stack became unavailable
unexpectedly before the intended Pi-first stop in each run, without deliberate operator
intervention. Fail-closed cleanup passed; the cause remains open. A clean Pi-first normal
shutdown was obtained on 03/08/2026 and repeated on 04/08/2026.

On 22/07/2026, the Pi desktop Hailo window and workstation dashboard displayed the same
annotated stream simultaneously. The helper published at least `2,800` frames, all six
workstation topics arrived, automatic rates passed, the FCU remained connected and
disarmed, no monitored command message appeared, and the Pi thermal peak was `67.2 C`.
The Pi then stopped during the monitored hold after one successful but incomplete remote
ROS service snapshot omitted `/rosapi/topics_for_type`; the workstation rosapi process
was still running, and both cleanups passed. The helper now accepts a recovered service
within three semantic observations while still rejecting any command service immediately
and failing closed after persistent misses.

A later 22/07/2026 attempt visually reproduced simultaneous Pi and dashboard output. The
workstation log recorded an early dashboard client connection; the operator identified it
as a tab left open and reported restarting the Pi helper during recovery. The workstation
then exhausted its arrival window before sampling, and Pi source readiness followed that
failure by about `36.9 s`. The copied Pi log holds only the later helper lifecycle: it
reached readiness, then was operator-interrupted during `live-window` before
`PI_SOURCE_WINDOW=COMPLETE` with status `130`. Pi and workstation cleanup passed, but this
attempt does not accept retry/deadline timing or the normal completed-window/live-hold
Pi-first lifecycle. The image inside the independent Pi-local HighGUI `"Output"` window
scaled down and initially scaled up with that window, then stopped enlarging while the Pi
window continued to grow. The workstation browser window is not the affected surface. At
that close, a clean repeat was still required; the 23/07/2026 operator decision below
supersedes it, and no further Pi-window repeat is planned.

## 23/07/2026 Pi-window experiment closeout

The environment probe passed, but the user-run resizable Phase R was partial and did not
reach acceptance:

- Workstation evidence:
  `/home/ghostzero/live_dashboard_logs/live_dashboard_workstation_20260723_183748`.
  Runtime preflight and service readiness passed. All six expected publishers became
  discoverable at the end of the `360`-second arrival window, but less than the required
  `60` seconds remained for six sequential samples. No arrival samples, automatic rates,
  or `PI_DATA_ARRIVED=PASS` marker were produced. Workstation teardown passed after
  operator Ctrl+C; the supervisor exited `status=1`, `failed_phase=arrival`, and
  `cleanup_rc=0`.
- Pi evidence directory:
  `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260723_184112`;
  copied workstation path:
  `/home/ghostzero/live_dashboard_logs/pi_copies/live_dashboard_20260723_184112`.
  The copy contains `19` files and occupies `912K`; no remote-versus-local SHA-256
  manifest comparison was run. MAVROS reached connected/disarmed state, telemetry passed,
  and `PI_SOURCE_STACK_READY=PASS` was emitted. Supervisor snapshots reported `66 C`,
  while `thermal_peak_mc.txt` records the more precise peak `67750` mC (`67.75 C`), below
  the `80 C` abort.
- The operator visually reproduced the symptom: the rendered image stopped enlarging
  while the outer `"Output"` window continued to grow. The copied `hailo.log` contains
  `151` successful inner-rectangle samples from callback `30` through `4530`: `24`
  samples at `321x241`, then `127` samples at `640x480`. Every sample retained
  `label=awaiting-checkpoint`, and no outer-window `xwininfo` capture exists. The inner
  plateau is therefore measured, but the missing drag labels and outer geometry still
  prevent a quantitative `KEEPRATIO`-versus-real-cap verdict.
- Pi final verification exceeded `90` seconds during the battery sample. It did not emit
  `PI_SOURCE_WINDOW=COMPLETE` or enter the normal live hold. The bounded battery echo was
  killed at its deadline; the saved Hailo image, GPS, and IMU samples completed
  immediately before the stop. Pi teardown passed; the helper exited `status=1`,
  `failed_phase=live-window`, and `cleanup_rc=0`.

The workstation arrival failure and Pi final-verification timeout are separate failures.
The operator ended this feature's experiments: Phase R will not be repeated, Phase FS
will not run, and Blocks B/C will not proceed. The measurement procedure below is
historical only. The diagnostic-only code and matching runbook surface are scheduled for
trim before the next live-dashboard work.

The trim is complete; use only the current tracked revisions in the active manifest above.
Do not deploy or execute any hash from the separate historical 23/07/2026 session-artifact
table.

## Before starting

- Workstation and Pi are on the same `IoT IMT Nord Europe` link. Internet access is not
  required; OpenStreetMap background tiles may be absent.
- Control box is powered, the FCU is disarmed, and propulsion is isolated for C1.
- For C2, the propellers are removed, propulsion power is isolated, the hull is
  restrained and every operator control is neutral before any hardware safety release
  or QGroundControl arm action.
- D435I and Hailo hardware are connected to the Pi.
- Pi Terminal P1 is opened from the active Pi desktop or Remmina session, has a
  nonempty `DISPLAY`, and can create an OpenCV window. Do not use an SSH-only terminal
  for this dual-output run.
- Hailo exclusively owns the D435I, MAVProxy exclusively owns the UART, and MAVROS uses
  loopback only.
- Gazebo, navigation/controller nodes, `realsense2_camera`, old MAVProxy, MAVROS, and
  earlier helper runs are stopped.
- Ports `8002`, `8080`, and `9090` are free on the workstation.
- The tracked helper is installed at its Pi destination and matches its checksum.
- Keep the dashboard browser closed until the Pi source stack and workstation arrival
  gate both pass.

Use new foreground terminals. Do not reuse a terminal already running a service. Never
wrap either live command in an external GNU `timeout`.

The finite Pi source window internally gives every ROS graph-list/info query and finite
topic sample the same absolute deadline. Graph commands and topic-echo process trees are
hard-stopped at the remaining budget; topic echoes also retain their cooperative message
wait, capped by that budget. Deadline exhaustion hands the interrupted phase to a separate
`180`-second final verification, which repeats required workstation nodes, forbidden
services and subscribers, the single Hailo publisher, all six MAVROS source identities,
fresh image and telemetry samples, connected/disarmed state, temperature, and power.
Final-verification exhaustion is fail-closed and cannot emit the source-window completion
marker. Startup discovery and the operator-controlled post-window hold retain their
existing behavior.

## Deployment preparation - helper only

This preparation is not one of the two live commands. On the Pi, verify the installed
helper before starting:

```bash
H="$(readlink -f -- "$HOME")" || exit 1
D="$(xdg-user-dir DESKTOP)" || exit 1
D="$(readlink -f -- "$D")" || exit 1
[ -n "$D" ] && [ -d "$D" ] && [ "$D" != "$H" ] || exit 1
printf '%s  %s\n' \
  '8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c' \
  "$D/pi_live_hailo_mavlink_dashboard.sh" | sha256sum -c -
```

Continue when it prints `pi_live_hailo_mavlink_dashboard.sh: OK`. If it fails, transfer
only the helper from a workstation terminal:

```bash
cd ~/seal_ws/src/uvautoboat
printf '%s  %s\n' \
  '8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c' \
  tools/pi_live_hailo_mavlink_dashboard.sh | sha256sum -c -

read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
: "${PI_SSH:?Pi SSH endpoint is required}"
PI_DESKTOP="$(ssh "$PI_SSH" '
  d="$(xdg-user-dir DESKTOP)" || exit 2
  d="$(readlink -f -- "$d")" || exit 2
  h="$(readlink -f -- "$HOME")" || exit 2
  [ -n "$d" ] && [ -d "$d" ] && [ "$d" != "$h" ] || exit 2
  printf "%s" "$d"
')" || exit 1
scp tools/pi_live_hailo_mavlink_dashboard.sh \
  "${PI_SSH}:${PI_DESKTOP}/"
ssh "$PI_SSH" "
  cd '$PI_DESKTOP' &&
  printf '%s  %s\n' \
    '8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c' \
    pi_live_hailo_mavlink_dashboard.sh |
  sha256sum -c -
"
```

Do not copy `live_dashboard_preflight.sh` to the Pi. The Hailo runtime, generated wrapper,
and timestamped logs remain under `~/hailo_coco_overlay_2026-07-10`; only transferred
operator helpers live on the Pi Desktop.

## Live command 1 - workstation supervisor

Host: workstation. Terminal W1: new, foreground. Working directory: repository root.

```bash
cd ~/seal_ws/src/uvautoboat
tools/live_dashboard_preflight.sh run
```

The supervisor sources ROS Jazzy, sets `ROS_DOMAIN_ID=12` and
`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, rejects local conflicts, verifies the helper pin
and exact SSID, derives one Wi-Fi IPv4 address, and starts each workstation service in
its own process group with external logs. This live mode runs the runtime checks only;
it does not claim to run the development test suites.

Continue only after both markers:

```text
WORKSTATION_RUNTIME_PREFLIGHT=PASS ...
WORKSTATION_SERVICES=UP ... logs=/home/.../live_dashboard_workstation_...
```

Leave W1 running. It prints one compound Pi command carrying the current
workstation IPv4 address, selected SSID, helper checksum and
`HAILO_LOCAL_DISPLAY=1`. The default carries
`LIVE_HOLD_AFTER_WINDOW=1`, `LIVE_FCU_TO_VRX_FANOUT=0` and
`LIVE_ARMED_OBSERVATION=0`. An explicitly configured armed-observation run
instead carries fanout and selector `1`, hold `0`, and every supplied bounded
window, staleness, channel and trim value. With no display selector override,
the command carries `HAILO_LOCAL_WINDOW_MODE=fullscreen`. The printed command
resolves, checksums, and executes the helper from the Pi Desktop while
retaining `~/hailo_coco_overlay_2026-07-10` as the runtime root.

## Live command 2 - Pi source stack

Host: Pi. Terminal P1: new, foreground. Paste the complete compound command printed by
W1, from the opening `(` through the closing `)`. Paste it as one block without editing
or rewrapping individual lines. If the Remmina clipboard cannot paste a multiline block,
transfer a separately checksum-pinned phase runner to the Pi Desktop and type its short
single-line invocation in P1; do not start the command through SSH because it must inherit
the active desktop display.

Copy the block from the terminal that printed it. Routing it through any intermediate
surface that re-wraps text can corrupt it, and the corruption is quiet. Observed
07/08/2026: the closing `)` landed on top of the `H` of `HAILO_LOCAL_WINDOW_MODE`, leaving
`exec env VAR=... VAR=...` with no command argument. `env` with no command prints its own
environment and exits `0`, so the terminal fills with an environment dump, the helper never
starts, and no error is raised. If P1 prints an environment listing instead of
`HAILO_LOCAL_DISPLAY=ENABLED`, that is this failure: the arrival deadline is still running,
so relaunch immediately using the short-line fallback rather than re-pasting the block.

Before pasting, confirm the desktop display inherited by this terminal:

```bash
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
```

Stop if the value is empty. The helper must print
`HAILO_LOCAL_DISPLAY=ENABLED display=... window_mode=fullscreen`; it fails closed instead
of silently accepting a missing desktop session. The Hailo child first prints the
frame gate and then the request-and-measurement marker:

```text
HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow
HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output rect=x,y,width,height source=getWindowImageRect
```

`HAILO_LOCAL_WINDOW=READY ...` confirms that the fullscreen request returned and an image
rectangle was read. It does not by itself prove that the outer Pi window filled the display
or that the rendered image filled that window. Fullscreen acceptance also requires the
visible Pi-local result and recorded rectangle observations to show the expected scaling.

`HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE ...` means fullscreen setup failed but the
resizable window remains available. `HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS ...` means
window creation failed and the visualizer continued headless.
`HAILO_LOCAL_WINDOW=EVIDENCE_UNAVAILABLE ...` means fullscreen was requested but its
rendered image rectangle could not be measured. Any of these three markers fails the new
Pi-window acceptance; preserve the logs and do not describe the run as verified
fullscreen.

The expected negative import probe prints
`CANONICAL_STRIPPED_RCLPY=UNAVAILABLE informational rc=1` and a
`ModuleNotFoundError` traceback. It is informational only when subsequently followed,
after the provenance lines, by `HAILO_ROS_PREFLIGHT=PASS`.

Continue only after the helper reaches:

```text
MAVROS_STATE=PASS connected=true armed=false
MAVROS_TELEMETRY=PASS ...
PI_SOURCE_STACK_READY=PASS ...
```

An enabled armed-observation run must additionally reach
`ARMED_OBSERVATION_BASELINE=PASS` before the operator arms. Its accepted final
state includes `ARMED_OBSERVATION=PASS`, connected/disarmed MAVROS state, neutral
live-read servo outputs and hardware safety restored.

Stop immediately on a checksum failure, missing readiness marker, `STOP:`,
`ERROR line=`, thermal abort, command-sentinel abort, unexpected armed state,
disconnect, stale required telemetry, or an armed/restoration deadline.
`CLEANUP_ERROR` or `TEARDOWN=FAIL` also makes the run a failure. GPS no-fix is
valid telemetry and is not transport loss.

A single successful but incomplete remote service-list snapshot is retried. The helper
still stops after three observations omit `/rosapi/topics_for_type`, and it rejects a
dashboard command service on the first snapshot where one appears. If the finite evidence
window closes between observations, the service check moves to the final-verification
phase instead of reporting an unobserved service loss.

## Retired Pi-window measurement procedure - historical record

Do not run Phase R or Phase FS. The commands below preserve the procedure prepared for the
partial 23/07/2026 run; they are not an active test pipeline.

This diagnostic mode was prepared to measure the Pi-local scaling question without
changing the display path. It was gated on a read-only Pi environment probe reporting
`P0_PROBE=OK` and review of its OpenCV version, GUI backend, API, display, and `xwininfo`
readings. `P0_PROBE=HOLD`, `P0_PROBE=DEGRADED`, missing `xwininfo`, zero or multiple exact
`"Output"` matches, or ambiguous geometry kept the measurement gate closed.

Host: Pi. Terminal P0: active-desktop/Remmina, one-shot. After transferring and verifying
the two P0 files above, run:

```bash
bash ~/Desktop/run_p0_pi_window_probe.sh
```

Require exactly one `P0_PROBE=OK` and `P0_RUNNER=OK`, then review the reported values.
Do not run P0 over SSH.

Use one fresh workstation/Pi lifecycle for each phase. Stop the Pi first and wait for
`TEARDOWN=PASS` before stopping W1 or starting the next phase. The commands below put new
workstation run directories under `~/live_dashboard_logs`, not on the Desktop; Pi runtime
logs remain under the Hailo demo root.

### Historical measurement phases (retired)

23/07 diagnostic matrix helpers were used for Pi-local scaling research only and are no longer
part of active daily or acceptance runbooks.

Do not run `LIVE_PI_WINDOW_DIAG` in the live workflow.
Do not run the `run_pi_live_window_phase.sh` phase helpers in active testing.
The following is kept only for traceability of the completed measurement path.

## Workstation arrival and automatic rate evidence

W1 waits for these seven publishers and then samples each topic with its compatible QoS:

| Topic | Probe reliability | Depth |
| --- | --- | --- |
| `/hailo/overlay/image_raw` | reliable | `1` |
| `/mavros/state` | best effort | `10` |
| `/mavros/global_position/raw/fix` | best effort | `10` |
| `/mavros/imu/data` | best effort | `10` |
| `/mavros/battery` | best effort | `10` |
| `/mavros/rc/in` | best effort | `10` |
| `/mavros/rc/out` | best effort | `10` |

The default arrival deadline is `360` seconds from the printed Pi command. Each arrival
sample is `10` seconds. Continue only after:

```text
PI_DATA_ARRIVED=PASS topics=7 ...
W5_RATE_PROBES=PASS topics=7 duration_each=10s log=/home/...
```

The supervisor records offered QoS plus all seven `10`-second rate probes in
`w5_live_rates.log` inside its run directory. Each probe must print `N=...` and
`mean=... Hz`. These measurements describe the current `240p@10fps` diagnostic profile;
they do not select an optimized resolution, frame rate, or transport.

The Pi may enter `PI_SOURCE_HOLD=ACTIVE` before the automatic probes finish. This is
expected. Do not stop P1 until W1 has emitted `W5_RATE_PROBES=PASS`.

## Browser acceptance

Open or hard-refresh <http://127.0.0.1:8002/> only after both:

```text
PI_SOURCE_STACK_READY=PASS
PI_DATA_ARRIVED=PASS topics=7 ...
```

Open the browser developer tools Network panel, clear its log, filter for `/stream?`,
then hard-refresh the dashboard. Select `/hailo/overlay/image_raw` in the Camera panel
and verify:

- live Hailo boxes and class labels;
- the Pi desktop window starts fullscreen and remains open with the same live Hailo boxes
  and class labels;
- all six MAVROS badges remain `Live` with independent ages below `3.0 s` - the
  sixth is `Thrust`, added 07/08/2026, carrying `/mavros/rc/out` servo output;
- MAVROS state remains freshly connected and disarmed;
- GPS, IMU, battery, and RC activity reaches the view-only panel without a `Stale`
  badge or cleared values;
- GPS no-fix is displayed as telemetry state, not transport loss;
- vehicle-writing controls in the mission, configuration, tuning, and health-check
  panels are inert, while Mission History, tuning expanders, health clear/auto-scroll,
  export, and copy controls remain usable;
- dashboard command and configuration writes remain blocked;
- do not click mission, joystick or E-Stop controls to seek a blocked-write message.
  The shipped view-only initialisation makes these controls both inert and disabled, so
  their click handlers do not run. The blocked mission-command and dashboard E-Stop
  strings are source-level guards, not observable click criteria in this build;
- exactly one Hailo `/stream?...` request is present and remains continuously active;
- image click, Enter/Space on the image, and the Enlarge button open the same viewer;
- Close receives focus, Tab stays inside the viewer, and Escape closes it and restores
  focus to the opening image or button;
- each Zoom out or Zoom in click changes the scale by exactly `0.5×` within
  `1.0×`–`4.0×`, and Reset returns to `1.0×` and the top-left scroll position;
- opening, zooming, resetting, and closing add no second `/stream?...` request. The same
  original Network row must remain active throughout the sequence.

Any `Stale` badge fails the browser check for that topic. A surviving IMU topic must not
make state, GPS, battery, or RC appear current. Do not use mission, thruster, arming,
mode, RC override, parameter, or setpoint controls during this diagnostic.

Record the browser visual result separately from the automatic rate result. Neither
implies the other.

This view-only check does not clear the viewer for a write-enabled release. Before
changing that boundary, add a separate acceptance smoke test with the viewer open: an
operational E-Stop must be reachable by pointer or keyboard without closing the viewer.

## Failure hold

A phase failure after workstation services are up records `PHASE_FAIL`, preserves the
nonzero status, and enters `FAILURE_HOLD=ACTIVE`. The supervisor keeps its children
running and does not retry, probe, or tear down automatically. Preserve both consoles,
stop the Pi first, then press `Ctrl+C` in W1 for reverse workstation teardown.

A failure before workstation services are up exits immediately. Do not restart either
stack until the current Pi and workstation cleanups have finished and their logs are
preserved.

## Normal shutdown - Pi first

Before stopping anything, require W1 to have emitted `W5_RATE_PROBES=PASS` and P1 to
have emitted:

```text
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s monitored=... final_verification=... elapsed=... ...
PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C
```

Then stop in this exact order:

1. Press `Ctrl+C` once in Pi P1.
2. Wait for the Pi lifecycle markers:

   ```text
   PI_SOURCE_HOLD=STOP operator-requested
   TEARDOWN=PASS
   logs=/home/.../live_dashboard_...
   PI_SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=live-hold failed_phase=none cleanup_rc=0
   ```

3. Only after Pi `TEARDOWN=PASS`, press `Ctrl+C` once in workstation W1.
4. Wait for `WORKSTATION_TEARDOWN=PASS` and the workstation `logs=` line.
5. Close the browser.

Do not stop the workstation while the Pi remains in its monitored hold. If the Pi stops
because rosbridge, rosapi, or `web_video_server` disappeared, the shutdown order was not
a clean Pi-first operator stop even when both cleanup markers pass.

The 07/08/2026 failure was initially attributed to a reversed stop order. Later comparison
of the copied lifecycle logs corrected that conclusion: the Pi reported its missing-node
failure at `16:11:44.708`, rosbridge accepted a new client at `16:11:58.752`, and the
workstation supervisor did not record its operator `SIGINT` until `16:12:22.288`. The
workstation services were therefore still running when one daemonless node-list snapshot
missed rosbridge. A publisher-count-zero reading for Pi-local `/mavros/rc/in` 19 seconds
earlier independently places the event in the already observed incomplete-snapshot class.

The helper now requires the complete rosbridge, rosapi and `web_video_server` set in one
snapshot, but retries up to three snapshots before failing closed. A recovered miss records
`WORKSTATION_NODE_SNAPSHOT_RETRY` followed by `WORKSTATION_NODE_RECOVERY=PASS`; exhaustion
still fails the run. Prove Pi-first order from the lifecycle records instead: the Pi must
record `PI_SOURCE_HOLD=STOP operator-requested`, `TEARDOWN=PASS` and
`PI_SUPERVISOR_EXIT status=0` before the workstation records `SUPERVISOR_STOP`. Do not use
the rosbridge `user interrupted with ctrl-c (SIGINT)` line as a discriminator: the
workstation supervisor sends `SIGINT` to its child process groups during every orderly
teardown. Cleanup markers alone also remain insufficient.

The `monitored` field covers the finite evidence window and its shared absolute query
deadline. `final_verification` covers the complete fail-closed graph, fresh image,
telemetry, connected/disarmed-state, temperature, and power checks performed before
completion, with a separate `180`-second absolute deadline. `elapsed` is their combined
wall time. Any `STOP: final verification exceeded 180s during ...` marker fails the run;
`PI_SOURCE_WINDOW=COMPLETE` must not follow it.

## Block C2 - post-teardown real-FCU arm/disarm observation

This is part of Block C, not a concurrent extension of the view-only graph. It starts
only after C1 has passed and fully stopped.

- **Host and terminal:** Pi P2 is a new one-shot absence-check terminal; workstation W2
  is a new one-shot absence-check terminal; the control box and Herelink console perform
  the observation. No C1 foreground terminal is reused and C2 starts no repository
  process.
- **Working directory and environment:** P2 uses `/home/imt-aqua-drone`; W2 uses
  `/home/ghostzero/seal_ws/src/uvautoboat`. Neither terminal sources ROS, activates a
  Python environment or sets a Block C environment variable. The controller-local C2
  actions have no shell working directory or environment.
- **Prerequisites:** C1 has emitted Pi `TEARDOWN=PASS`,
  `PI_SUPERVISOR_EXIT status=0` and `WORKSTATION_TEARDOWN=PASS`; the browser is closed;
  the propellers are physically removed; propulsion power is isolated; the hull is
  restrained; controls are neutral and the Herelink sticks will remain untouched;
  QGroundControl on the Herelink is connected to the real FCU; and the external safety
  LED is visible throughout the transition.
- **Stop condition:** stop without arming if any C1 process or port remains, the Herelink
  build has no live MAVLink Inspector, `SERVO_OUTPUT_RAW.time_usec` does not advance, or
  the disarmed `servo1_raw` / `servo3_raw` pair is not `800` / `800`. After hardware
  safety is released but before the QGroundControl arm request, both outputs must still
  read `800`; otherwise re-engage hardware safety and stop without arming. Do not retry a
  rejected arm. After an accepted arm, disarm immediately on a persistent departure from
  the observed neutral pair, unexpected actuator movement, a non-neutral control, loss
  of the QGroundControl link, an armed-state transition without the intended QGroundControl
  button press, or any state other than the requested bounded arm. Once the physical
  safety state has been released, every exit path must end with the FCU confirmed
  `Disarmed` and the physical safety state re-engaged.
- **Paste-back:** paste both absence verdicts, browser-closed confirmation, the Inspector
  source identity, port and advancing-time verdict, the post-safety-release output pair,
  safety LED state, and the actual state/PWM observations before arm, while armed and
  after disarm. If the Inspector gate fails, paste its explicit pre-arm failure result
  instead.

From Pi P2, confirm the Pi side of C1 is absent:

```bash
(
  set -euo pipefail
  cd /home/imt-aqua-drone

  processes="$(pgrep -af -- \
    '[p]i_live_hailo_mavlink_dashboard|[m]avproxy|[m]avros|[h]ailo_ros_wrapper|[d]ashboard_safety_monitor|[t]hermal_watchdog' \
    || true)"
  if [ -n "$processes" ]; then
    printf '%s\n' "$processes"
    printf 'C2_PI_ABSENCE=FAIL\n'
    exit 1
  fi

  printf 'C2_PI_ABSENCE=PASS\n'
)
```

From workstation W2, confirm the workstation side and all three C1 ports are absent. The
bracketed patterns prevent the inspection command from matching itself:

```bash
(
  set -euo pipefail
  cd /home/ghostzero/seal_ws/src/uvautoboat

  ports="$(ss -H -ltn '( sport = :8002 or sport = :8080 or sport = :9090 )')"
  processes="$(pgrep -af -- \
    '[p]i_live_hailo_mavlink_dashboard|[l]ive_dashboard_preflight|[r]osbridge|[w]eb_video_server|[s]erve_dashboard[.]py|[m]avproxy|[m]avros' \
    || true)"
  if [ -n "$ports" ] || [ -n "$processes" ]; then
    printf '%s\n' "$ports" "$processes"
    printf 'C2_WORKSTATION_ABSENCE=FAIL\n'
    exit 1
  fi

  printf 'C2_WORKSTATION_ABSENCE=PASS ports=8002,8080,9090\n'
)
```

After both verdicts pass and the browser is closed, perform the bounded controller-local
sequence:

1. Confirm QGroundControl reports the real FCU disarmed and all controls are neutral. Put
   the Herelink controls in a stable neutral state and do not touch either stick at any
   point in C2. A stick is an RC input; its position or input PWM is not numerically
   comparable to the raw servo-output values observed below.
2. Before releasing hardware safety, open the QGroundControl application menu, select
   Analyze Tools and then MAVLink Inspector. Herelink builds may omit this desktop-oriented
   view; if it is absent, stop without arming rather than improvising another telemetry
   path.
3. Select the current vehicle's `SERVO_OUTPUT_RAW`. Record its source system, source
   component and `port`. Confirm both `Count` and `time_usec` advance over successive
   updates, then record the actual `servo3_raw` and `servo1_raw` values. Both must be `800`
   while disarmed. Do not change the message rate: the observed `2.0 Hz` stream samples
   every approximately `500 ms` and cannot exclude a shorter transient.
4. Press and hold the physical arm/safety button on the FCU box until the external safety
   LED changes from its intermittent safety-state blink to solid. The LED transition, not
   a fixed press duration, is the gate. The
   [CubePilot user manual](https://docs.cubepilot.org/user-guides/autopilot/the-cube-user-manual)
   documents this press-and-hold/solid-LED behaviour, but it had not previously been
   observed on this boat; if the transition is not unambiguous, release the button, do
   not arm and stop. Because real-FCU `BRD_SAFETY_MASK` is unknown, unchanged `800/800`
   cannot distinguish a registered safety release from a button press that did nothing,
   nor show whether these two channels were safety-gated. The blinking-to-solid LED
   transition is therefore the sole discriminator for this state change; there is no
   fallback if it is ambiguous.
5. Before requesting arm, re-read the advancing `SERVO_OUTPUT_RAW` stream continuously for
   `10` seconds, approximately `20` samples at the observed rate. Record
   `C2_SAFETY_RELEASED servo3=N servo1=N count=ADVANCING time_usec=ADVANCING armed=NO safety_led=SOLID`.
   Both outputs must remain `800` and QGroundControl must remain `Disarmed`. If either
   output changes persistently or the armed state changes, restore `Disarmed`, re-engage
   hardware safety and stop without requesting arm.
6. Use QGroundControl on the Herelink console to arm once. If the armed state changes
   before that button press, disarm, re-engage hardware safety and stop. If the requested
   arm is rejected, do not retry. Confirm the FCU remains `Disarmed`, re-engage and confirm
   the physical safety state, record the rejection and stop for diagnosis.
7. On an accepted arm, record the arm time, QGroundControl `Armed` indication and the
   actual `servo3_raw` / `servo1_raw` pair while `time_usec` continues advancing. Do not
   move a stick, publish a command or request non-neutral output. Disarm immediately if
   either output persistently departs from the `800` baseline.
8. Use QGroundControl on the Herelink console to disarm. Record the disarm time, final
   `Disarmed` indication and final live output pair; both outputs must return to `800`.
9. Re-engage the FCU-box physical safety state with a sustained button press and confirm
   that the LED returns to its intermittent safety-state blink before touching anything
   else, then return the control box to its normal powered-down state. The
   [ArduPilot safety-switch documentation](https://ardupilot.org/sub/docs/common-safety-switch-pixhawk.html)
   defines intermittent blinking as the safety state and solid as outputs enabled once
   armed.

ArduPilot defines `ARMING_RUDDER=2` as rudder arm-or-disarm and permits that path when
throttle is within its zero deadzone. The repository's numeric `ARMING_RUDDER` records are
from SITL; the real FCU value is **unknown**. Because C2 deliberately holds neutral
throttle throughout, it treats rudder arming as potentially enabled: both Herelink sticks
remain untouched, and an armed-state transition without the intended QGroundControl
button press is an immediate stop rather than part of the accepted observation.

Paste back exactly, replacing every `N` with the observed value:

```text
C2_PI_ABSENCE=PASS
C2_WORKSTATION_ABSENCE=PASS ports=8002,8080,9090
C2_BROWSER=CLOSED
C2_QGC_INSPECTOR=PASS message=SERVO_OUTPUT_RAW id=N rate=NHz source_system=N source_component=N port=N count=ADVANCING time_usec=ADVANCING
C2_PREARM_OUTPUT=PASS servo3=N servo1=N armed=NO hardware_safety=ON
C2_SAFETY_RELEASED servo3=N servo1=N count=ADVANCING time_usec=ADVANCING armed=NO safety_led=SOLID duration=10s actuator_movement=NO_PROPULSION_POWER_ISOLATED
C2_OBSERVATION before=DISARMED servo3_before=N servo1_before=N arm_time=HH:MM:SS armed=ARMED servo3_armed=N servo1_armed=N armed_duration=10s actuator_movement=NO_PROPULSION_POWER_ISOLATED disarm_time=HH:MM:SS final=DISARMED servo3_after=N servo1_after=N count=ADVANCING time_usec=ADVANCING hardware_safety=ON safety_led=BLINKING qgc_link=STABLE
```

`NO_PROPULSION_POWER_ISOLATED` records why powered actuator movement was impossible; it
is not evidence that the command path behaved correctly. If the operator misses either
wall-clock time, record `NOT_RECORDED` rather than retaining the template or repeating an
arm solely to obtain a timestamp.

If the Inspector is absent, has no `SERVO_OUTPUT_RAW`, or shows a static `time_usec`, stop
before releasing hardware safety and retain the two absence verdicts plus browser result:

```text
C2_QGC_INSPECTOR=FAIL reason=<not-present|no-servo-output-raw|time_usec-static> armed=NO hardware_safety=ON
```

If QGroundControl refuses the one arm request, retain the five gate lines above and paste
this terminal result after restoring the physical safety state:

```text
C2_ARM=REJECTED retry=NO final=DISARMED hardware_safety=ON
```

If the Inspector stops updating after safety release, restore `Disarmed` and the blinking
safety state, then paste:

```text
C2_SAFETY_RELEASE=FAIL reason=inspector-frozen count=STATIC time_usec=STATIC arm_request=NOT_SENT final=DISARMED hardware_safety=ON safety_led=BLINKING
```

If review cannot be immediate or the operator must leave the bench after a successful
safety-release observation, restore the blinking safety state before pausing:

```text
C2_REVIEW_HOLD final=DISARMED hardware_safety=ON safety_led=BLINKING
```

C2 proves only the observed Herelink/QGroundControl-to-FCU arm/disarm transition with
the propulsion path physically disconnected, plus the current raw output values on the
two named message fields. `SERVO_OUTPUT_RAW` does not carry output-function assignments
or configured `MIN/TRIM/MAX`, so C2 does not prove which physical output is left/right,
the configured rail, PWM proportionality, dashboard/Pi command transmission, autonomous
control or thrust. It does not close T0b or T2a: the standalone T0b parameter evidence is
still absent and Block B remains failed at teardown.

### 13/08/2026 C2 pre-arm checkpoint

The first C2 gates have executed. Pi P2 reported `C2_PI_ABSENCE=PASS`; workstation W2
reported `C2_WORKSTATION_ABSENCE=PASS ports=8002,8080,9090`; and the dashboard browser was
closed. Herelink QGroundControl displayed one active vehicle and did not expose a separate
source-system number. Its Inspector reported message `SERVO_OUTPUT_RAW (36)` at `2.0 Hz`,
component `1`, port `0`, advancing `Count` and advancing `time_usec`. The field display and
installed MAVLink dialect agree on `time_usec`=`uint32_t`, `port`=`uint8_t`, and
`servo1_raw` / `servo3_raw`=`uint16_t`. With the real FCU `Disarmed` and hardware safety
still engaged, both named raw outputs were `800`:

```text
C2_QGC_INSPECTOR=PASS message=SERVO_OUTPUT_RAW id=36 rate=2.0Hz source_system=SINGLE_ACTIVE_NOT_DISPLAYED source_component=1 port=0 count=ADVANCING time_usec=ADVANCING
C2_PREARM_OUTPUT=PASS servo3=800 servo1=800 armed=NO hardware_safety=ON
```

This is a second live observation path agreeing with C1's MAVROS `800/800` result. It
confirms the sampled neutral values but cannot exclude a transient between `2.0 Hz`
frames. No stream-rate parameter or message-interval write was made. Hardware safety has
not been released and no arm request has been sent. Real-FCU `ARMING_RUDDER`,
`BRD_SAFETY_MASK` and `BRD_SAFETYOPTION` remain unknown. Consequently, the next
blinking-to-solid LED transition is the only evidence that can distinguish a registered
safety release when the sampled output pair remains `800/800`; neither T0b nor T2a
closes.

### 13/08/2026 C2 final result

The operator then completed the bounded observation. Hardware-safety release was
discriminated by the external LED changing from blinking to solid. While QGroundControl
still reported `Disarmed`, the Inspector held `800/800` for `10` seconds with advancing
`Count` and `time_usec`:

```text
C2_SAFETY_RELEASED servo3=800 servo1=800 count=ADVANCING time_usec=ADVANCING armed=NO safety_led=SOLID duration=10s actuator_movement=NO_PROPULSION_POWER_ISOLATED
```

One QGroundControl arm request produced an observed `Armed` state. Both raw output fields
remained `800` for the bounded `10`-second armed window while `Count` and `time_usec`
advanced and the link remained stable. QGroundControl disarm restored an observed
`Disarmed` state, the output pair remained `800/800`, and the physical safety button was
held until the LED returned to blinking:

```text
C2_OBSERVATION before=DISARMED servo3_before=800 servo1_before=800 arm_time=NOT_RECORDED armed=ARMED servo3_armed=800 servo1_armed=800 armed_duration=10s actuator_movement=NO_PROPULSION_POWER_ISOLATED disarm_time=NOT_RECORDED final=DISARMED servo3_after=800 servo1_after=800 count=ADVANCING time_usec=ADVANCING hardware_safety=ON safety_led=BLINKING qgc_link=STABLE
```

The submitted line retained the `HH:MM:SS` placeholders, so the two wall-clock times are
honestly recorded as `NOT_RECORDED`; the arm is not repeated for missing timestamps. The
no-movement field is a statement of physical power isolation, not output-path evidence.
C2 is operator-observed rather than artifact-backed, and `2.0 Hz` sampling cannot exclude
a transient between frames. C1 and C2 together pass the expanded Block C. Block B remains
failed at teardown, and the missing parameter/function evidence means neither T0b nor T2a
closes.

## Temperatures and log copy-back

Pi logs are written under
`~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_YYYYMMDD_HHMMSS`. In the returned Pi
terminal, use the exact path from the helper's `logs=` line. Each run directory now
contains `supervisor.log`, which persists the helper's display selection, phases, stop
trigger, failure reason if any, teardown verdict, and final status:

```bash
read -r -p 'Exact Pi run directory from logs=: ' RUN_DIR
: "${RUN_DIR:?Pi run directory is required}"
printf 'PI_TEMP_PEAK_MC='
cat "$RUN_DIR/thermal_peak_mc.txt"
printf 'PI_TEMP_POST_MC='
cat /sys/class/thermal/thermal_zone0/temp
test -r "$RUN_DIR/supervisor.log"
tail -n 12 "$RUN_DIR/supervisor.log"
```

`PI_TEMP_START_MC` is printed by the compound launch command. Copy every Pi run directory
back, including passes, from a new workstation terminal:

```bash
read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
read -r -p 'Run name, for example live_dashboard_YYYYMMDD_HHMMSS: ' RUN_NAME
: "${PI_SSH:?Pi SSH endpoint is required}"
: "${RUN_NAME:?Pi run name is required}"
mkdir -p ~/Desktop/test_logs_folder
scp -r "${PI_SSH}:hailo_coco_overlay_2026-07-10/logs/${RUN_NAME}" \
  ~/Desktop/test_logs_folder/
ls -la "$HOME/Desktop/test_logs_folder/$RUN_NAME"
```

`thermal_peak_mc.txt` is the precise run-wide thermal-watchdog maximum and governs when
it differs from the rounded `temp=... peak=...` supervisor samples. A copied directory
without a source-side checksum manifest can be inspected as received, but the copy alone
does not establish byte-for-byte identity with the remote directory.

The workstation run directory is already under `~/Desktop`. Retain its service logs,
arrival samples, and `w5_live_rates.log` with the matching Pi run directory and Pi
`supervisor.log`.

Report:

- simultaneous annotated Pi-window and workstation-dashboard result;
- browser visual result, camera-viewer controls, and the one-continuing-stream result;
- automatic rate result and rate-log path;
- helper checksum `OK`, connected/disarmed state, command sentinel, and source-window
  markers;
- `PI_TEMP_START_MC`, `PI_TEMP_PEAK_MC`, and `PI_TEMP_POST_MC`;
- `PI_SOURCE_HOLD=STOP operator-requested`, Pi `TEARDOWN=PASS`, and
  `PI_SUPERVISOR_EXIT status=0 ...` plus `WORKSTATION_TEARDOWN=PASS`;
- both exact run directories and the copy-back result;
- C2 Inspector source, component and port, advancing `time_usec`, actual `servo3_raw` /
  `servo1_raw` values before arm, while armed and after disarm, arm/disarm times, actuator
  movement result, final hardware-safety state and whether the single arm request was
  accepted or rejected.

C1 proves bounded simultaneous view-only delivery. C2 separately proves an observed
controller-local real-FCU arm/disarm transition after C1 teardown. Neither proves full
endurance, an optimized image profile, a GPS fix, custom maritime detector accuracy,
dashboard/Pi command transmission, servo mapping, PWM magnitude or thrust.

### Recorded C1 result on 13/08/2026

Workstation run `live_dashboard_workstation_20260813_165355` and Pi run
`live_dashboard_20260813_165410` passed C1. Seven topics arrived and passed the bounded
rate probes; all six browser freshness badges were live; the Hailo stream was visible;
the command sentinel recorded zero messages; the FCU remained disarmed; and the final
real-boat output sample was `SERVO3 800` / `SERVO1 800`. The precise Pi thermal maximum
was `68.3 °C`. Pi teardown and exit completed before the workstation stop began, and
both supervisors exited with status `0`. C2 remained **NOT RUN** at this checkpoint.

## Related pages

- [Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo)
- [RealSense Dashboard Testing](RealSense_Dashboard_Testing)
- [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test)
- [Dashboard Security](Dashboard_Security)
