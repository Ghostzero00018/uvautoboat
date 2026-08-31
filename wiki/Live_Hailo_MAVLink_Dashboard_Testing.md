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

The repository artifacts below identify the current revisions, refreshed on
27/08/2026 after the unbounded armed-observation mode and batched source-view
default were added.
The tracked Pi helper
is the copy that must be transferred to the Pi Desktop before a run; a
previously transferred copy is stale until its hash is checked against the
value below. The workstation supervisors and evidence recorder remain
workstation-only. Separately pinned historical session artifacts are retained
below only for traceability.

| Item | Value |
| --- | --- |
| Helper source | `tools/pi_live_hailo_mavlink_dashboard.sh` |
| Helper Pi destination | resolved Pi Desktop: `$(xdg-user-dir DESKTOP)/pi_live_hailo_mavlink_dashboard.sh` |
| Helper size | `95,720` bytes |
| Helper SHA-256 | `0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9` |
| Workstation supervisor | `tools/live_dashboard_preflight.sh` |
| Supervisor size | `41,001` bytes |
| Supervisor SHA-256 | `a14da50ba6a2c582ac6ac0de019f31375ff880f1a6f1467212b7630d794fd601` |
| VRX supervisor | `tools/fcu_to_vrx_workstation.sh` |
| VRX supervisor size | `26,906` bytes |
| VRX supervisor SHA-256 | `a5afddc81d59a39d63e7cca77a7b3852e30b5a555f1be2e04f3746f5540bdd5f` |
| Correlation recorder | `tools/fcu_to_vrx_evidence.py` |
| Correlation recorder size | `43,839` bytes |
| Correlation recorder SHA-256 | `19df4dae7015cfe3af44512c7a0bf854e1e448df8a3fc0b1f37075e6d62d0126` |

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
`HAILO_LOCAL_WINDOW_MODE=resizable`, and keeps the normal display path.
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
enabled, an explicit positive final-restoration limit, a positive staleness
limit, and both live-read channel and complete min/trim/max rails. A finite run
uses positive `LIVE_RUN_SECONDS` and `LIVE_ARMED_OBSERVATION_MAX_SECONDS` and
sets `LIVE_HOLD_AFTER_WINDOW=0`. The explicit operator-controlled mode requires
both values to be exactly `0`; a mixed zero/positive pair is rejected, and the
emitter sets `LIVE_HOLD_AFTER_WINDOW=1`. The emitter passes the helper's
channel/trim values and starts the domain-12 subscriber-only recorder for `/mavros/state`,
`/mavros/sys_status`, `/mavros/rc/out` and `/hailo/overlay/image_raw`.

The helper's subscriber-only safety monitor permits one armed session
only after the supervisor has proved fresh connected/disarmed telemetry,
neutral output, hardware safety ON, an empty command sentinel and the complete
pre-ready graph. It fails closed on an armed startup, a second arm, disconnect,
stale required telemetry, command publication, a finite armed deadline, or
failure to return to connected/disarmed neutral output with hardware safety
restored within the final-restoration limit. In the paired zero mode only the
armed and outer runtime deadlines are disabled; staleness, disconnect, second
arm, command-sentinel, rail, thermal and final-restoration checks remain
fail-closed. The separate dashboard-to-real-FCU Test A passed on 26/08/2026.
The first enabled Herelink-to-VRX Test B attempt on 27/08/2026 observed motion
but failed before final-safe-state capture and is **NOT ACCEPTED**.
The paired-zero retry reached its safe disarmed baseline and never armed; it
failed instead on a contradictory GPS source graph check described below.

Before enabling the selector, use the retained T0b artifact for
`BRD_SAFETY_DEFLT`, mapping and rails, then observe the live hardware-safety
state. Stop if hardware safety is
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

**Closure 27/08/2026:** the workstation-only VRX frame proof captured eight
transforms from `/wamv/pose`. The only transform parented by the configured
world was `sydney_regatta -> wamv`; no `child_frame_id` ended in `base_link`.
This directly confirms the ROS topic and the world-parent selector used by the
observer. The full supervised SITL acceptance was then rerun on clean revision
`147efe0270b3357a17ca6489c96d1722cd55c6f8` in
`/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`. It completed the
safety-off, disabled-frame, arm, positive, release, negative, E-Stop and disarm
phases, produced `SITL_VERDICT=PASS`, and independently passed all ten evidence
hashes, control cross-check, teardown, stop order, port/process cleanup and
`SITL_ADJUDICATION=PASS`. The current-source SITL evidence gate is therefore
closed on `147efe0`. This remains simulator evidence only; T0b is the remaining
open evidence gate and Test B remains **NOT RUN**.

**Later closure 27/08/2026:** the snapshot-backed T0b probe passed `41`
selected reads from the pinned `986`-parameter MAVFTP snapshot while retaining
live connected/disarmed and hardware-safety checks. It exited with
`writes=none bridge=not-started`, and its copied evidence is
`/home/ghostzero/Desktop/pi_run_evidence/t0b_probe_20260827_174820`. T0b is
closed. Revisions `aa4a07a` and `1c1dff5` then changed the W1 measurement and
subscriber-ordering paths after the `147efe0` simulator run, so the
exact-revision SITL gate is reopened unless the operator explicitly supersedes
that rerun. The live disarmed measurement and limits are closed in the section
below; Test B itself remains **NOT RUN**.

**Armed-attempt update 27/08/2026:** the operator explicitly superseded the
SITL rerun for revision `eb9a337` and started Test B. The motion chain was
observed, but the run failed at its armed deadline before final-safe-state
capture and is not accepted. The unbounded retry repair changes source after
`eb9a337`; that earlier supersession does not cover the repaired revision.

**Paired-zero retry update 27/08/2026:** the published repair was run from
clean revision `550b992`. P1 reached its connected/disarmed neutral
hardware-safe baseline, never armed, and failed on its GPS source verifier.
Test B remains not formally accepted.

**Current-source update 31/08/2026:** the full supervised SITL acceptance and
independent adjudication passed on clean revision
`3ca4c9bd16414d37506b62ce9fa5b8dad55a3719`. The retained run is
`/home/ghostzero/Desktop/sitl_digital_twin_20260831_150946`; adjudication
checked ten evidence hashes, the control cross-check, the exact governed stop
order, teardown and free host ports/processes before ending
`SITL_ADJUDICATION=PASS`. This closes the gate for exact revision `3ca4c9b`.
The float32 endpoint repair described below changed the bridge afterward, so
the current-source gate is reopened for the repaired path until that revision
passes the same supervised run and adjudication.

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

### Enhanced Test A props-fitted observation - 28/08/2026

A later one-off run used a fresh `986`-parameter snapshot with SHA-256
`61406eee10c253daabfef4462ce0b3661be30b599bd7736909c5bff4e4b4943d`.
It resolved steering/throttle as `RC1`/`RC3`, left/right output as
`SERVO3`/`SERVO1`, both servo rails as `800/800/2200`, and retained
`ARMING_CHECK=0`. The last value is safety context, not an explanation for the
observed motor behavior. The Pi and workstation reached their READY markers,
ended connected/disarmed, exchanged the stop marker and exited
`status=0 cleanup_rc=0`.

```text
revision=70c4d8bfc4827bcf89af41b711700be713139f5d
workstation=/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260828_175310
pi-copy=/home/ghostzero/Desktop/pi_run_evidence/test_a_props_fitted_observation_20260828_175321
```

The operator corrected the active-interval declaration after the run: the
propellers were fitted and propulsion was available. The operator reported no
rotation at steering/throttle `0.00/0.12`, at exact steering `+0.20` or
`-0.20`, or at `0.05/0.04`, and one-sided rotation during other
steering-heavy requests. The retained evidence contains only neutral demand,
RC `1515/1515` and output `800/800`; it does not correlate the active slider
requests with output PWM. Do not infer an ESC threshold or a motor-mixing
fault from these observations.

The correction also means `REAL_FCU_PROPELLERS_REMOVED=1` was inaccurate for
the active interval. The helpers reported the nominal
`tier=T2b authority=demand-enabled` software markers and clean teardown, but
the run did not satisfy T2b's propellers-removed physical gate. No separate
T3a approval, dedicated mechanical guarding or exclusion-zone evidence was
retained.

Exact steering `+0.20` and `-0.20` are a known input-contract defect. The
browser exposes those endpoints, but `sensor_msgs/msg/Joy.axes` transports
them as `float32`, producing approximately `+/-0.20000000298`. The bridge's
exact `[-0.20, +0.20]` comparison rejects them as
`COMMAND_OUT_OF_BOUNDS`. The endpoint contract must be repaired and covered by
a red/green test before those slider endpoints are used again.

**Forward repair 31/08/2026:** a failing regression reproduced both float32
steering endpoints and the same defect at legal tunable throttle maxima that
round upward in float32. The bridge now normalizes only the exact float32
encoding of each configured command endpoint. The next adjacent float32,
materially over-limit steering or throttle, and a tiny negative throttle remain
rejected without replacing the last accepted command. An enabled endpoint also
reaches the paired RC override.
`max_steering=0.20` and `max_throttle=0.12` are unchanged. The focused bridge
suite passes `36` tests, but the repair is offline-only until the repaired
revision passes SITL and is deployed with its regenerated bundle manifest.

Source tracing found no one-sided publication defect. The browser emits one
paired steering/throttle `Joy` frame, and the bridge writes both resolved RC
channels in one `OverrideRCIn` message. ArduRover's skid mixer calculates left
demand as throttle plus steering and right demand as throttle minus steering.
A steering-heavy request can therefore leave one side at bottom-neutral while
the other rises; the retained `0.05/0.04` request producing `911/800 us` is
consistent with this behavior. Straight throttle introduces no mixer
differential, but the 28/08 props-fitted run retained no active PWM sample and
establishes no ESC start threshold. Do not raise dashboard throttle authority
or change `MOT_THR_MIN` from that observation. Any threshold measurement is a
separate, freshly approved, propellers-removed calibration with correlated
requested demand, RC input, both servo outputs and operator-observed start
points.

Classification: **ENHANCED TEST A - PROPS-FITTED FUNCTIONAL OBSERVATION; NOT
T2B ACCEPTANCE, T3A ACCEPTANCE OR APPROVAL FOR ROUTINE OR REPEATED
PROPS-FITTED OPERATION.** This does not carry forward as approval for another
run.

Afterward, the separately approved rollback captured live
`RC_OVERRIDE_TIME=0.5`, set it to `3.0`, fetched all `986` parameters,
confirmed the live `3.0` readback and retained:

```text
directory=/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828
snapshot=real_fcu_params_20260828_rc_override_rollback_3p0.parm
sha256=a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b
```

The serial endpoint was free afterward. The temporary `0.5` value is no longer
live. Any later demand-enabled Test A requires a separate approval to set
`0.5`, confirm its readback and pin a fresh snapshot before either helper
starts.

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
decoded neutral real-FCU output at `800/800 us`. One armed correlated attempt
decoded asymmetric output, mapped thrust and VRX motion, but ended in recorder
aborts before the final safe state and is not accepted. Every run requires a clean
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

#### Disarmed limit measurement

W1 has a default-off `LIVE_FCU_TO_VRX_MEASUREMENT` selector for the required
pre-Test-B measurement. It is mutually exclusive with
`LIVE_ARMED_OBSERVATION`. When set to `1`, it requires outbound fanout plus the
same live-read channel and PWM-rail values as the armed observer, starts W1's
subscriber-only Pi evidence recorder with `stale_seconds=0`, and waits for its
four-stream READY state. The Pi command remains disarmed-only:
`LIVE_ARMED_OBSERVATION=0`, `LIVE_HOLD_AFTER_WINDOW=1` and
`LIVE_FCU_TO_VRX_FANOUT=1`. W2 stays in record-only mode with
`FCU_VRX_CORRELATED_OBSERVATION=0`.

W1 does not create that subscriber during workstation service startup. The Pi
helper first completes its zero-existing-endpoint sentinel and brings up all
seven publishers. Only after W1 observes those publishers does its arrival
phase start the evidence recorder and wait for recorder READY. Starting the
recorder earlier makes the intended `/hailo/overlay/image_raw` subscription
indistinguishable from a stale browser or simulation endpoint and correctly
causes the Pi helper to fail closed.

After a deliberately timed disarmed interval and the required Pi, W2, W1 stop
order, calculate the observed limits from the two retained JSONL files:

```bash
python3 tools/fcu_to_vrx_evidence.py summarize-disarmed \
  --pi-events "$W1_RUN/fcu_to_vrx_pi_events.jsonl" \
  --vrx-events "$W2_RUN/evidence/vrx_events.jsonl" \
  --window-seconds "$MEASUREMENT_WINDOW_SECONDS"
```

The summarizer does not select acceptance thresholds. It requires exactly one
READY event on each side, a complete common window, connected and disarmed FCU
state, hardware safety ON, neutral Pi and UDP PWM, zero VRX thrust, finite pose
data and valid JSONL on every retained line. It then reports per-stream maximum
gaps, maximum absolute Pi-PWM to UDP-PWM skew, maximum UDP-receive to thrust
delay and stationary pose drift. Armed, unsafe, non-neutral, short, empty,
malformed or ROS-contaminated evidence fails instead of producing limits.

**Live closure 27/08/2026:** the current-source disarmed measurement passed on
W1 run `live_dashboard_workstation_20260827_185101` and W2 run
`fcu_to_vrx_workstation_20260827_185133`. The 60-second common window measured
maximum Pi/VRX stream gaps of `1.039521457 s` / `0.291961215 s`, maximum
Pi-PWM to UDP-PWM skew of `223.019194 ms`, maximum UDP-PWM to thrust delay of
`9.633272 ms`, and stationary pose drift of `0.081450536 m`. The selected
armed-run limits are `5 s` staleness on both observers, `750 ms` PWM skew,
`100 ms` thrust delay, `10 s` motion delay and `0.25 m` minimum motion, with
`60 s` armed and final-restoration bounds. W1 required `403 s` to declare
seven-topic arrival, so the Pi source window remains `600 s` rather than using
a shorter limit.

The copied Pi evidence is
`/home/ghostzero/Desktop/pi_run_evidence/test_b_measurement_20260827_185227`.
It records connected/disarmed state, neutral `SERVO1/SERVO3=800/800`,
outbound-only fanout readiness, at least `3600` Hailo frames, a `67.75 C`
thermal peak and `TEARDOWN=PASS`. This closes only disarmed measurement and
limit selection; no arm, Herelink excursion or VRX motion occurred. The Pi
reported `POWER_TELEMETRY=UNAVAILABLE`, so this run does not prove the absence
of undervoltage or throttling flags; the independent thermal guard remained
active and did not trip.

#### First armed attempt and explicit unbounded retry

The first armed Test B attempt on 27/08/2026 used W1 run
`live_dashboard_workstation_20260827_191952`, W2 run
`fcu_to_vrx_workstation_20260827_192020`, and Pi run
`live_dashboard_20260827_192234`. The complete Pi copy is retained at
`/home/ghostzero/Desktop/pi_run_evidence/test_b_armed_failed_20260827_192234`.

The recorders captured the first asymmetric output as left `SERVO3=2200` and
right `SERVO1=800` approximately `49.99 s` after arming. The matching UDP frame
arrived with `0.0856 ms` left/right skew; W2 mapped it to `800.0/0.0 N` within
`0.87 ms`, and the model moved `2.47946 m` within `9.979 s`. Neutral output
`800/800` returned `0.749 s` after the excursion. This proves that Herelink
input reached the real FCU output, outbound fanout, the W2 bridge and VRX
motion for that observed interval.

The attempt is not accepted. The Pi monitor recorded
`reason=ARMED_WINDOW_DEADLINE topic=/mavros/state`, then entered `ABORT` while
the last captured FCU sample remained connected and armed in `MANUAL`. W1
recorded `stale_camera`; W2 recorded `stale_left_thrust`; canonical
adjudication therefore fails. No retained recorder captured the required final
connected/disarmed, neutral and hardware-safe state. The later operator report
of disarm, safety ON and neutral sticks occurred outside the retained evidence
window and is not substituted for that missing evidence.

The Pi message `STOP: dashboard command publication detected` was a false
classification of the shared abort file. The retained file identifies the
actual cause as `ARMED_WINDOW_DEADLINE`; there is no evidence that dashboard
command publication caused this stop. The Pi stopped every named child and
reported no `CLEANUP_ERROR`. Its `cleanup_rc=1` was forced by the non-empty
abort record, so it does not establish that a child survived teardown.

The retry mode is explicit and paired:

```text
LIVE_RUN_SECONDS=0
LIVE_ARMED_OBSERVATION_MAX_SECONDS=0
LIVE_ARMED_OBSERVATION_FINAL_SECONDS=60
LIVE_ARMED_OBSERVATION_STALE_SECONDS=5
```

Both zero values must be supplied together. This disables only the outer
runtime and armed-session deadlines. The final-restoration bound, topic
freshness, disconnect, second-arm, command-sentinel, rail and thermal guards
remain active. After the operator disarms, restores hardware safety and leaves
neutral output, the monitor must record `ARMED_OBSERVATION=PASS` and complete
final verification. P1 then enters `PI_SOURCE_HOLD=ACTIVE` with
`PI_SOURCE_HOLD_MODE=completed-armed`; it retains Pi-local safety checks without
depending on W1 nodes. In that hold, stop W2 first, then W1, and stop P1 last.
Before execution, no retry result existed.

#### Paired-zero retry result

The published paired-zero mode was run from clean revision `550b992` with W1
`live_dashboard_workstation_20260827_200652`, W2
`fcu_to_vrx_workstation_20260827_200727` and copied Pi evidence at
`/home/ghostzero/Desktop/pi_run_evidence/test_b_unbounded_failed_20260827_200821`.
P1 recorded `duration=unbounded`, `armed_deadline=disabled` and
`ARMED_OBSERVATION_BASELINE=PASS`. The safety monitor stayed in `READY`; no
armed transition, deadline abort, command abort, asymmetric output or new
motion occurred.

Approximately `234 s` after the live window began, three graph queries for
`/mavros/global_position/raw/fix` returned `query_rc=0` with
`publisher count 0`. The data-plane fallback was then skipped as
`no-declared-type`. That result conflicts with the retained NavSatFix sample
and W1's immediately preceding `40` messages in `10.02 s` at `4.00 Hz`.
MAVROS remained alive and continued logging no-fix GPS warnings. This is a
source-verification false negative, not an armed/runtime deadline or FCU
disconnect.

P1 stopped all named children with `TEARDOWN=PASS cleanup_rc=0`. Its stream
loss then caused W1 `stale_camera`, W2 `stale_left_thrust` and a zero-message
W1 RC-input rate probe. W2 and W1 stopped their governed children with
`cleanup_rc=0`; W1 also reported `WORKSTATION_TEARDOWN=PASS`. The retry never
reached the armed action and adds no motion evidence.

The earlier armed attempt remains functional evidence for its captured
interval: machine records prove the output, thrust and `2.47946 m` motion chain,
and the operator observed Herelink-driven VRX movement. No video was retained
before the armed deadline stopped that source window. The missing accepted
final-safe-state capture still means Test B is **ATTEMPTED - FAILED / NOT
FORMALLY ACCEPTED**.

The operator reported heavy rain and hail during the paired-zero retry. Severe
weather can degrade GNSS fix quality, but it does not explain a ROS graph
publisher-count result: retained NavSatFix messages and the W1 rate measurement
show that the source was still delivering data.

#### Source-verifier repair after the paired-zero retry

The helper now defaults `LIVE_MAVROS_SOURCE_BATCH` to `1`, promoting the
existing bounded six-topic `rclpy` view that accumulates discovery before the
unchanged publisher-count and `/mavros` publisher-identity verdict. Explicit
`LIVE_MAVROS_SOURCE_BATCH=0` retains the legacy daemonless CLI path for
diagnosis. No data-plane-only acceptance path was added. W1 also records a
given governed child PID/PGID exit once while continuing to fail every
subsequent supervision poll. Focused Pi and W1 suites pass; this is an offline
repair pending the direct live retry, not proof that DDS discovery can never be
transient.

The 28/08/2026 morning audit closed a phase-freshness edge in that view. If a
later topic forces a fresh six-topic generation, the consumer now discards the
already-checked earlier-topic entries through the requested topic. Those
entries can no longer survive into the next verification phase. A focused
recovery case requires two phase-one generations, an empty pending view at the
phase boundary and a third generation for the next phase's state check.

W1 also writes `LIVE_MAVROS_SOURCE_BATCH=1` and
`LIVE_FINAL_VERIFY_SECONDS=180` explicitly into its emitted P1 command. A stale
export in the Pi terminal therefore cannot reactivate the legacy source path or
silently change the final-verification budget. Explicit W1 overrides remain
validated before the command is printed.

The W1 certification suite clears inherited live selectors before constructing
its default fixtures. Configured production selectors are exercised only by
the suite's explicit cases, so certifying an armed command can no longer turn
the default hold/fanout check into a false failure.

#### W1 arrival repair after the 28/08 pre-arm attempt

The clean `a23fc6d` attempt reached P1
`PI_SOURCE_STACK_READY=PASS` and `ARMED_OBSERVATION_BASELINE=PASS`, while W2
reached four-stream READY. W1 nevertheless stayed in publisher arrival, created
no arrival sample or Pi-observer evidence, and emitted no
`PI_DATA_ARRIVED=PASS`. Its log reported the configured `600 s` failure after
`244.968` epoch seconds between phase entry and failure. The source of that
timing discrepancy is unproven. Nothing was armed, all three stacks cleaned up
with `cleanup_rc=0`, and Test B remains not accepted.

W1 now latches each expected publisher independently across polling passes and
re-queries only unresolved topics. The phase deadline, sample budget and elapsed
result use `/proc/uptime` monotonic time. A timeout reports the configured
timeout, monotonic elapsed time and exact unresolved topic names. This is still
a pre-subscription graph gate: after all seven names are retained, the selected
Pi-observer READY gate and all seven compatible-QoS message samples remain
mandatory. The repair therefore removes the all-seven-single-scan dependency
without turning an earlier publisher sighting into acceptance. Focused offline
coverage passes `25` cases; a new live result is still required.

#### Repaired W1 live result and interrupted Test B interval

The separately approved clean-`6beb603` retry used these retained directories:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260828_155040
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260828_155105
P1=/home/ghostzero/Desktop/pi_run_evidence/test_b_functional_interrupted_20260828_155345
```

P1 passed `PI_SOURCE_STACK_READY=PASS` and the connected/disarmed, neutral,
hardware-safe `ARMED_OBSERVATION_BASELINE=PASS`. W1 then passed the repaired
cumulative publisher-arrival gate, its armed Pi-observer READY gate and all
seven rate probes. W2 reached four-stream READY with mapping `SERVO3/SERVO1`
and rails `800/800/2200`.

The retained record proves the functional chain before interruption. The first
asymmetric Pi output was `800/1033`; the matching UDP frame arrived in
`4.124019 ms`, mapped to `0.0/133.142857 N`, and reached the left/right thrust
topics in `1.038506/1.126658 ms`. WAM-V moved `3.480079 m` inside the configured
`10 s` motion window, above the `0.25 m` threshold. Both full asymmetric pairs,
active-side `800.0 N` thrust, return to `800/800`, correlated zero thrust and
camera frames during the armed interval were retained. The operator separately
observed the Herelink sticks moving the boat in VRX while W1, W2 and P1 were
healthy.

The operator reports that the professor later cut FCU power. This is retained
as external-interruption context, not as a machine-established cause. The Pi
Hailo log records `/dev/video4` disappearing with `errno=19`, after which the
Hailo process completed and the thermal watchdog exited when its watched Hailo
process group disappeared. The supervisor therefore reported
`thermal-watchdog leader exited`. The exact run-wide thermal peak was
`70500 mC` (`70.5 C`), below the `80000 mC` abort threshold;
`thermal_watchdog.log` is empty and no thermal-abort record exists.

The independent P1 safety monitor moved `READY -> ARMED -> ABORT` and wrote
`reason=REQUIRED_TOPIC_STALE topic=/mavros/state`. W1 recorded `stale_state`;
W2 recorded `stale_left_thrust` `0.275 s` later. P1 stopped MAVROS, MAVProxy and
telemetry fanout, then reported `TEARDOWN=FAIL cleanup_rc=1`. The non-empty
stale-state abort record is itself sufficient to force `cleanup_rc=1`, so that
marker does not independently prove a surviving process or occupied device.

The final retained FCU state remained connected and armed, while mapped output
had returned to `800/800` and the latest system-status evidence still reported
hardware safety ON. No connected/disarmed final-state transition,
`ARMED_OBSERVATION=PASS`, `PI_SOURCE_WINDOW=COMPLETE` or
`PI_SOURCE_HOLD=ACTIVE` was retained. Canonical explicit-threshold adjudication
therefore returns `FCU_TO_VRX_EVIDENCE=FAIL reason=pi observer recorded an
abort`.

Classification: **FUNCTIONAL MOTION DEMONSTRATED; RUN EXTERNALLY INTERRUPTED /
NOT FORMALLY ACCEPTED.** The W1 arrival repair and the functional
Herelink-to-real-FCU-to-VRX motion interval are live-proven. Final-safe
lifecycle completion and formal Test B acceptance are not. No post-run
`RC_OVERRIDE_TIME` readback or rollback snapshot accompanies this evidence;
the documented restoration from `0.5` to `3.0` remains open before a different
operation.

**Forward correction 28/08/2026:** a later separately approved rollback
captured live `RC_OVERRIDE_TIME` readbacks `0.5 -> 3.0`, saved a `986`-parameter
snapshot, copied it to
`/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828`, and
verified SHA-256
`a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`.
The serial endpoint was free afterward. This supersedes the rollback-open
sentence only; Test B remains not formally accepted.

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

For the default and finite paths, stop in reverse: Pi first, then `W2` (bridge,
recorder, VRX, then UDP `14555` confirmed free), then `W1`. For the explicit
paired-zero armed retry, first disarm and restore safety, then wait for
`ARMED_OBSERVATION=PASS`, `PI_SOURCE_WINDOW=COMPLETE`, and
`PI_SOURCE_HOLD_MODE=completed-armed`. Only from that hold, stop W2, then W1,
then P1. This preserves both recorders through final-safe-state capture while
allowing the Pi to keep its local source and safety stack alive during
workstation teardown.

### Batched MAVROS source view

`LIVE_MAVROS_SOURCE_BATCH` defaults to `1`. The six MAVROS source checks are
served from one bounded `rclpy` participant that spins to accumulate discovery
and answers all six topics from a single generation. The strict publisher-count,
publisher-identity, retry and deadline verdicts are unchanged. Set it explicitly
to `0` only to reproduce the legacy per-query `ros2 topic info --verbose
--no-daemon --spin-time 2` diagnostic path.

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
  '0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9' \
  "$D/pi_live_hailo_mavlink_dashboard.sh" | sha256sum -c -
```

Continue when it prints `pi_live_hailo_mavlink_dashboard.sh: OK`. If it fails, transfer
only the helper from a workstation terminal:

```bash
cd ~/seal_ws/src/uvautoboat
printf '%s  %s\n' \
  '0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9' \
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
    '0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9' \
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
instead carries fanout and selector `1`, every supplied runtime, staleness,
channel and trim value, and either finite hold `0` or paired-zero hold `1`.
It also carries the selected `LIVE_MAVROS_SOURCE_BATCH` and
`LIVE_FINAL_VERIFY_SECONDS` values explicitly. With no display selector
override, the command carries
`HAILO_LOCAL_WINDOW_MODE=resizable`. The printed command
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
`HAILO_LOCAL_DISPLAY=ENABLED display=... window_mode=resizable`; it fails closed instead
of silently accepting a missing desktop session. The Hailo child first prints the
frame gate and then the request-and-measurement marker:

```text
HAILO_LOCAL_WINDOW=PENDING mode=resizable name=Output gate=first-imshow
HAILO_LOCAL_WINDOW=READY mode=resizable name=Output rect=x,y,width,height source=getWindowImageRect
```

`HAILO_LOCAL_WINDOW=READY ...` confirms that the resizable window opened and an
image rectangle was read. Window size remains an operator display choice and is
not Test B motion evidence.

`HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS ...` means window creation failed and the
visualizer continued headless. Preserve that result; it does not satisfy the
Pi-local visible-window check.

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
disconnect, stale required telemetry, a finite armed deadline, or the
final-restoration deadline.
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

The default arrival deadline is `360` seconds from arrival-phase entry, measured
with the supervisor's monotonic clock. Publisher discovery is cumulative across
polling passes: W1 retains each observed expected topic and re-queries only
unresolved topics. A timeout reports the configured timeout, monotonic elapsed
time and the exact unresolved names. This publisher gate is not acceptance:
after all seven names are retained, the selected Pi-observer READY gate and all
seven compatible-QoS samples remain mandatory. Each arrival sample is `10`
seconds. Continue only after:

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
- the Pi desktop window starts resizable and remains open with the same live Hailo boxes
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
