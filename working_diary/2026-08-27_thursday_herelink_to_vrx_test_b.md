# Thursday 27/08/2026 - Herelink-to-VRX Test B

**PRE-DIARY - NOT STARTED. TEST B IS NOT RUN. NO APPROVAL OR PHYSICAL STATE
CARRIES FROM 26/08/2026.**

This is the sole 27/08/2026 working diary. It was prepared at the 26/08/2026
close. It records inherited evidence and tomorrow's gates; it does not schedule,
authorise or start a powered run.

## Carry-over blockers - read before any Test B work

- `RC_OVERRIDE_TIME=0.5` remains live for Test B; rollback to `3.0` remains
  mandatory after Test B or before any different operation.
- Test B is **NOT RUN**. It was recorded here as blocked by `/wamv/pose` versus
  `/model/wamv/pose`. **Withdrawn 27/08/2026** - the topic was never wrong; see
  "Pose and readiness repair - 27/08/2026" at the end of this file. The real
  defect was the transform selected from that stream, now repaired offline.
  Test B remains blocked on the physical declaration, approval, current-source
  SITL acceptance and the query tier.

## Objective

Prove the real outbound control-to-digital-twin direction with correlated
evidence at every stage:

```text
Herelink sticks -> real FCU mixer -> SERVO_OUTPUT_RAW
                -> Pi MAVROS /mavros/rc/out
                -> outbound-only fanout -> workstation UDP 14555
                -> servo-command bridge -> VRX left/right thrust -> WAM-V motion
Pi D435I -> Hailo overlay -> dashboard and correlation recorder
```

Acceptance requires one bounded asymmetric stick input, matching left/right PWM
through both recorders, matching VRX thrust, measured WAM-V displacement, a
Hailo frame during the observation window, neutral return, external disarm,
restored hardware safety and ordered teardown. Visual motion without the
correlated values is not acceptance.

This test does not use the dashboard command publisher from Test A. Do not run
the real-FCU dashboard command supervisors, a second MAVProxy, a parallel SITL
or any direct servo-write path alongside Test B.

## Read first

1. `working_diary/2026-08-26_wednesday_full_scale_fcu_to_vrx_integration.md`
2. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`
3. `Board.md`
4. `wiki/Roadmap.md`
5. `tools/live_dashboard_preflight.sh`
6. `tools/pi_live_hailo_mavlink_dashboard.sh`
7. `tools/fcu_to_vrx_workstation.sh`
8. `tools/fcu_to_vrx_evidence.py`
9. `tools/servo_command_bridge.py`

Re-read the current source and hashes on 27/08/2026. The values below identify
the 26/08/2026 close only and become stale after any source change:

```text
Pi dashboard helper:      8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c
W1 dashboard supervisor:  2a272106b47f1b6988a01fe5f7fcc536e66aad3889b86c538b699a77e58cd90b
W2 VRX supervisor:        981fba979e86d0e7a2e50c4d9c89b30b699b62b7a24343b4d315c819fb931091
correlation recorder:     5c40d6376efc7456929ddf1e80454f3e17ff87c7530629a65f4c10ac0db361dc
```

## Evidence inherited from 26/08/2026

Evidence may carry forward; approval and physical state may not.

- SITL acceptance passed with independent adjudication and clean teardown during
  26/08/2026. **Forward correction: it is no longer current-source.** `81efb73`
  subsequently changed `tools/real_fcu_rc_command_bridge.py`, which is the
  bridge under test at `tools/sitl_digital_twin_runner.sh` line 18, and no
  `SITL_VERDICT` or `SITL_ADJUDICATION` has been recorded since. Of the three
  preconditions recorded on 26/08/2026, only the armed-observation selector
  closed; the current-source simulator acceptance reopened and the query tier
  was never closed.
- Real-FCU Test A passed the bounded dashboard command/output-feedback path.
  It is separate from Test B.
- Test A retained:
  `/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260826_200922`
  and
  `/home/ghostzero/Desktop/pi_run_evidence/test_a_20260826/real_fcu_digital_twin_pi_20260826_201051`.
- The Test A video is
  `/home/ghostzero/Videos/Screencasts/Screencast from 2026-08-26 20-15-16.mp4`,
  SHA-256
  `e4ce7e9ba3f832769cb0cd151f8af28ae90e612db96afaec364dd55a321dc846`.
- The live snapshot contains `986` parameters, has SHA-256
  `3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`
  and records temporary `RC_OVERRIDE_TIME=0.5`.
- Live resolution is steering `RC1`, throttle `RC3`, left `SERVO3` function
  `73`, right `SERVO1` function `74`, with both output rails
  `800/800/2200`.
- The disarmed W2 fanout run decoded repeated real FCU output at `800/800 us`
  and zero mapped thrust. It proves UART-to-UDP-`14555`-to-bridge delivery at
  neutral, not armed motion.
- The Hailo PCIe device was recovered on kernel `6.8.0-1062-raspi` after the
  matching headers enabled DKMS to install `hailo_pci/4.24.0`; `/dev/hailo0`
  and firmware identification then passed.

`RC_OVERRIDE_TIME=0.5` has not been rolled back. It remains authorised only for
this deferred Test B. Restore it to `3.0` after Test B or before any different
operation.

## Blocker to close before any Test B live start

**Withdrawn 27/08/2026.** The diagnosis in this section is superseded by "Pose
and readiness repair - 27/08/2026" at the end of this file. `/wamv/pose` was
correct; step 1 below must not be carried out. The section is retained as the
record of what was believed at the 26/08/2026 close.

The 26/08/2026 W2 record-only evidence exposed a pose-topic mismatch:

```text
current observer request: /wamv/pose
VRX bridge created:       /model/wamv/pose
message type:             tf2_msgs/msg/TFMessage
```

The retained W2 recorder status remained `WAIT_DATA`. Its `3,585` events
contain servo-output and left/right-thrust events but no pose event. The VRX
log explicitly records the Gazebo-to-ROS bridge for `/model/wamv/pose`.
Correlated Test B would therefore fail before it could prove motion.

Before any hardware is armed on 27/08/2026:

1. update the W2 pose-topic contract to the actual `/model/wamv/pose` source;
2. add focused coverage that rejects a future pose-topic drift;
3. run the W2 focused check and the relevant Python tests;
4. run a workstation-only VRX check that receives one matching WAM-V pose;
5. commit and push the scoped repair, then require clean
   `HEAD == origin/main` parity.

This source repair is not part of the 26/08/2026 documentation close. Until it
lands and its offline checks pass, Test B remains blocked and must not start.

## Non-regression rules from the 26/08/2026 failures

Do not repeat the short-wait, prompt-timing or data-format failures that consumed
the 26/08/2026 hardware window.

### Timeout and interactive-gate contract

- Do not wrap a live supervisor in an improvised external `timeout` command.
- Keep the real-FCU readiness budget at `600 s` and each one-shot status
  subscription at `15 s` unless a separately reviewed source change and focused
  test deliberately replace those values.
- Start a post-confirmation readiness deadline only after the operator has
  completed the physical action and entered the exact terminal confirmation.
  Time spent reading or acting on a prompt must not consume the next readiness
  window.
- Do not confuse a startup/discovery timeout with the intentionally short,
  bounded armed-observation window or a stale-data limit. Record all three
  values and their meanings before launch.
- If a readiness wait expires, preserve the complete run directory and diagnose
  that run. Do not immediately retry with another arbitrary timeout.

The current real-FCU source and focused tests already pin `600/15`, require the
Pi `RELEASED_DISARMED` prompt before the readiness wait and pass the complete
helper suite. Recheck those assertions after any helper edit.

Test B uses different supervisors and must not inherit the Test A numbers by
assumption. Current source defaults W1 publisher arrival to `360 s`, W2 pre-Pi
readiness to `120 s` and W2 post-Pi observer readiness to `900 s`
(`FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS`; it spans the operator's Pi start,
so it is deliberately longer than its pre-Pi sibling). The Pi helper defaults its armed-observation maximum,
final and stale limits to `30/30/5 s`, but W1 requires those three values to be
set explicitly when armed observation is enabled. Correlated W2 observation
also requires an explicit `FCU_VRX_OBSERVER_STALE_SECONDS` value.

Before the live Test B launch:

- run one clean disarmed W1/W2/Pi rehearsal after the pose-source repair;
- measure actual Hailo, VRX, DDS, publisher-arrival and correlation readiness;
- record the selected `LIVE_ARRIVAL_TIMEOUT_SECONDS`,
  `FCU_TO_VRX_READY_TIMEOUT_SECONDS`, all three
  `LIVE_ARMED_OBSERVATION_*_SECONDS` values and
  `FCU_VRX_OBSERVER_STALE_SECONDS` in the run evidence;
- allow measured startup margin instead of blindly relying on the `360 s` or
  `120 s` defaults;
- prove one deliberate timeout/failure case offline before relying on each
  changed wait contract in the hardware window.

### Data-format contract

- Never parse mixed human terminal output as evidence data.
- For `ros2 topic echo` status sampling, use `--field data` and
  `--no-lost-messages`; send diagnostics to a separate stderr log.
- Accept exactly one JSON/YAML mapping, with or without the normal ROS `---`
  document terminator, then normalize it to compact JSON before field checks.
- Reject empty output, a scalar/string, malformed or tab-contaminated text and
  multiple documents without printing a Python traceback into the supervisor
  stream.
- Keep W1 and W2 recorder files as JSONL only. Every non-empty line must pass
  `json.loads`, carry the expected evidence schema and contain no ROS warning or
  progress text. Diagnostics belong in the sibling log.
- Exercise the parser against the real production output shape before a live
  wait. A test that compares one helper's invented format with itself is not a
  sufficient contract.

Before Test B, retain or add focused cases for JSON alone, JSON plus `---`,
empty output, scalar/string output, malformed output, tab-contaminated output
and multiple non-empty documents. Also validate every retained disarmed W1/W2
JSONL line before selecting correlation limits. Any format failure blocks the
live run; it is not a reason to weaken the parser.

At the 26/08/2026 close, the current timeout/parser checks passed:

```text
real-FCU shell helper suite: PASS cases=32
real-FCU Python tests:       45 passed
```

## Fresh 27/08/2026 gates

The operator must state every physical item literally on 27/08/2026:

- propellers removed;
- hull restrained;
- exact propulsion battery and ESC power state;
- hardware safety initially ON;
- FCU initially disarmed;
- Herelink powered with sticks neutral;
- Pi runtime stack down;
- workstation W1/W2 stacks down.

Also require, before launch:

- a clean pushed repository with zero divergence from `origin/main`;
- current helper and supervisor checksums derived from current workstation
  bytes, followed by matching checks on the Pi copy;
- no conflicting SITL, Gazebo, MAVProxy, MAVROS, rosbridge, dashboard or bridge
  process;
- workstation TCP `8002`, `8080`, `9090` and UDP `14555` free;
- the current workstation address and SSID resolved by W1 rather than copied
  from an earlier run;
- `/dev/ttyAMA0` unowned on the Pi;
- `/dev/hailo0` present, `hailo_pci` loaded and `hailortcli fw-control identify`
  successful;
- the retained snapshot bytes still matching
  `3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`;
- live `RC_OVERRIDE_TIME=0.5` readback and confirmation that no parameter changed
  after the snapshot. If this cannot be established, fetch a fresh complete
  list and pin the new bytes before continuing.

Two evidence gates sit alongside the physical and environmental items above and
are **not** satisfied by any preflight command:

- **current-source SITL acceptance.** The recorded `SITL_VERDICT=PASS` /
  `SITL_ADJUDICATION=PASS` was earned on `3ca6b0b`; `81efb73` later changed
  `tools/real_fcu_rc_command_bridge.py`, the bridge the SITL runner launches
  under test. A fresh acceptance on current source is required, or an explicit
  operator supersession that names this gate.
- **query-tier (T0b) closure.** No tracked file records T0b closed. It requires
  a successful parameter response and the mapping/rail artifact over the direct
  link, or an explicit operator supersession that names this gate.

The Test A approval is expired. Test B requires a separate explicit approval,
and that approval may only be requested once the physical declaration, the
environmental items and **both evidence gates above** are satisfied or
explicitly superseded. Passing the preflight commands alone does not reach the
approval question.

## Observation limits to resolve before launch

Do not invent timing or motion thresholds at the armed gate. The 26/08 W2
servo stream had a maximum observed inter-frame gap of approximately
`4.086 s`, but its pose stream was absent, so it cannot certify the complete
correlated observer.

After the pose correction, obtain a disarmed all-stream measurement and record:

- maximum gap for Pi state, system-status, RC-output and Hailo events;
- maximum gap for W2 servo-output, left thrust, right thrust and pose events;
- dashboard-PWM to UDP-PWM clock skew;
- UDP-PWM to thrust publication delay;
- stationary WAM-V pose drift over the chosen motion window.

Only then set explicit values for:

```text
LIVE_ARMED_OBSERVATION_STALE_SECONDS
FCU_VRX_OBSERVER_STALE_SECONDS
MAX_PWM_SKEW_MS
MAX_THRUST_DELAY_MS
MAX_MOTION_DELAY_SECONDS
MIN_MOTION_METRES
```

The armed-observation maximum and final-verification windows must also be
explicit positive integers. Keep the total Pi run long enough to cover the
baseline, one bounded arm window, neutral return and final verification. Record
the chosen values in this diary before starting the armed phase.

## Canonical launch order

Use three foreground operator terminals and no substitutes:

1. **W1 workstation:** run `tools/live_dashboard_preflight.sh run` with fanout
   and armed observation enabled, current mapping/rails, and all explicit
   observation limits. Wait for workstation services and the emitted Pi block.
2. **W2 workstation:** run `tools/fcu_to_vrx_workstation.sh run` with live
   mapping/rails, `FCU_VRX_MAX_THRUST=800.0`, correlated observation enabled
   and the measured stale limit. Require VRX, bridge and observer readiness.
3. **Pi:** run only the exact current block emitted by W1. Do not use an older
   pasted block. Require the disarmed neutral baseline and outbound fanout
   readiness before any external arm.

W1 must start before W2 because W1 rejects an already-running Gazebo process.
W2 must be ready before the Pi because W1's ROS arrival phase does not prove a
UDP `14555` listener.

## Bounded Test B action

After all three terminals report readiness and the fresh approval is recorded:

1. keep Herelink sticks neutral and record the disarmed `800/800 us` baseline;
2. externally arm by the separately declared operator method;
3. confirm the Pi observer entered its one allowed armed window;
4. apply one small asymmetric Herelink steering/throttle input within the
   approved bound;
5. hold only long enough to capture matching PWM, thrust and pose movement;
6. return both sticks to neutral immediately;
7. require both outputs to return to `800/800 us`;
8. externally disarm;
9. restore hardware safety ON;
10. require the Pi final-verification PASS before teardown.

Abort immediately on an armed startup, non-neutral baseline, missing observer
READY, stale topic, disconnected FCU, unexpected command publication, output
outside the live rails, missing UDP delivery, a second arm, failure to return
neutral, failed disarm or failed hardware-safety restoration.

## Stop order and acceptance

Stop in reverse order only:

1. Pi first, after external disarm and hardware safety restoration;
2. W2 next, requiring bridge then observer then VRX stop and UDP `14555` free;
3. W1 last, requiring dashboard, web-video-server and rosbridge teardown.

Retain and copy back every run directory, including failures. Adjudicate the Pi
and W2 JSONL streams only after all three teardowns, using the measured limits
recorded above. Acceptance requires:

- exactly one observer READY event on each side;
- one asymmetric PWM excursion matching at Pi and UDP-decode stages;
- matching left/right VRX thrust values;
- pose displacement above the measured stationary-drift threshold within the
  approved delay;
- at least one Hailo frame during the armed window;
- neutral return, connected disarm and hardware safety restored;
- all supervisor exits and ordered teardown markers passing.

## Mandatory parameter rollback

After Test B completes or is abandoned, use a standalone MAVProxy parameter
session with every repository supervisor stopped:

1. set `RC_OVERRIDE_TIME` back to `3.0`;
2. read it back as `3.0`;
3. fetch and save a complete rollback parameter snapshot;
4. retain its SHA-256 and copy it to the workstation evidence directory;
5. confirm FCU disarmed, hardware safety ON and propulsion safe;
6. confirm the serial device, governed ports and processes are free.

The day cannot close with Test B accepted while the temporary `0.5` value is
still live.

## Approval gate

Test B remains **NOT RUN**. After the pose repair, offline checks, measured
limits, fresh physical declaration and all preflight gates pass, ask exactly:

> Do you approve starting the bounded Herelink-to-VRX Test B now?

## Pose and readiness repair - 27/08/2026 (offline only)

The pose-topic blocker recorded above is **withdrawn**. A source review of the
installed `vrx_gz` established that `/wamv/pose` was correct all along, and that
the observed `WAIT_DATA` had a different cause. Nothing in this section was run
against a simulator, Pi, FCU, Herelink or network.

### The topic was never wrong

`/model/wamv/pose` is the Gazebo transport name. `vrx_gz` bridges it to the
relative ROS topic `pose`, and launches the `ros_gz_bridge` node inside
`PushRosNamespace('wamv')`, so the resolved ROS topic is `/wamv/pose`.

The 26/08 diagnosis came from the bridge start-up log, which prints configured
Gazebo-side names on both sides of its arrow. The same log in the same retained
run renders the thrust bridge as `wamv/thrusters/left/thrust ->
wamv/thrusters/left/thrust`, yet that run captured `1,195` events on
`/wamv/thrusters/left/thrust`. The log form therefore cannot distinguish the two
names. Independently, VRX's own `pose_tf_broadcaster` subscribes to the relative
`pose` inside the same namespace, so a bridge publishing `/model/wamv/pose`
would break VRX's own transform tree.

`tools/fcu_to_vrx_workstation.sh` keeps `--pose-topic /wamv/pose`.

### The real defect

The recorder selected the first transform whose `child_frame_id` ended in
`base_link`. The WAM-V `PosePublisher` runs with `publish_link_pose=false` and
`publish_model_pose=true`, so `base_link` appears only as the *parent* of static
sensor transforms and never as the child of a moving one. The filter matched
nothing, `seen("pose")` never fired, and the observer could not leave
`WAIT_DATA`.

`tools/fcu_to_vrx_evidence.py` now selects the transform whose parent is the
launched world frame, passed by the supervisor as `--world-frame`, so the
vehicle's own model name is never assumed. When no transform matches, the
recorder appends one `pose_frame_mismatch` event naming the observed parent
frames and prints a matching marker, so a wrong world frame is named instead of
stalling silently.

### Two-stage workstation readiness

`servo_output_raw` and both thrust streams originate from the Pi fanout, so
waiting for four-stream observer readiness before the Pi starts would deadlock.
W2 therefore gates in two stages:

```text
pre-Pi   VRX topics incl. /wamv/pose -> observer subscriptions started
         -> one recorded pose baseline -> UDP 14555 listening
         -> FCU_TO_VRX_WORKSTATION_PRESTART=PASS
post-Pi  FCU_TO_VRX_VRX_OBSERVER_READY=PASS topics=4
         -> FCU_TO_VRX_WORKSTATION_READY=PASS ... observer=ready streams=4
```

No arming before the final `READY` line. The pre-Pi pose baseline is provable
without the Pi, so a world-frame mismatch now stops the run before the operator
starts the boat rather than after. The post-Pi wait uses its own timeout,
`FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS`, default `900`, because it spans the
operator's Pi start.

`FCUVRX_READY_REACHED` is still set only at the final `READY`, so a run that
never reaches four-stream readiness cannot report `TEARDOWN=PASS`.

### Coverage

Transform selection, the previous `base_link` filter matching nothing, wrong and
empty world frames, a message without the world parent, and parent-frame
reporting are covered in `tools/test_fcu_to_vrx_evidence.py`. The pre-Pi pose
gate (timeout, named mismatch, satisfied baseline), the post-Pi readiness gate
(`STARTED` alone rejected, `READY` accepted), the `--world-frame` argument, the
pose topic in the VRX gate and the prestart/ready ordering are covered in
`tools/test_fcu_to_vrx_workstation.sh`.

The selection tests were confirmed to fail against the previous implementation
before being accepted as passing: with the `base_link` filter restored,
`test_selects_the_model_root_under_the_world_frame` fails.

### Documentation

The runbook diagnosis, `Board.md` and `wiki/Roadmap.md` carried the withdrawn
topic-mismatch claim; each now carries a dated forward correction, and the dated
26/08 rows are otherwise left intact. The same two files also asserted a
current-source SITL acceptance that `81efb73` had already invalidated; both now
record that the SITL acceptance and the query tier (T0b) remain open.

### Offline gate

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=17
real-FCU helper suite: PASS cases=32
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS shell_cases=21 python_tests=21 runtime=not-started
Python: 106 passed
Node: tests=80 pass=80 fail=0
bundle manifest: 4/4 OK
GATE_RC=0
```

Whitespace checks passed. Test B remains **NOT RUN**. The physical declaration,
Block D/Test B approval, current-source SITL acceptance and the query tier are
all still open, and no workstation-only VRX run has been performed to confirm
the live frame names.

### Review follow-ups on the same repair - 27/08/2026

An adversarial review of the repair above found further defects, all closed
offline in the same change.

- **The runbook start order contradicted the new gate.** It still said `W2` must
  be ready before the Pi starts, which the two-stage gate makes unreachable. It
  now names `FCU_TO_VRX_WORKSTATION_PRESTART=PASS` as the pre-Pi gate the
  UDP-listener rule is actually about, and the four-stream
  `FCU_TO_VRX_WORKSTATION_READY=PASS` as the post-Pi arming gate.
- **`publish_model_pose=true` is not upstream VRX.** It comes from this
  workspace's vrx commit `e384cd65`, applied by
  `one_click_launch_all/patch_vrx.sh`. The recorder docstring said otherwise.
  The wording is corrected, and the pre-Pi abort now names the disabled-model-pose
  case alongside a wrong world name, because both produce the same signature.
- **Readiness was set membership, never recency.** A pose sample recorded during
  the pre-Pi hold could satisfy the four-stream marker minutes later, after the
  operator had started the Pi. When a staleness limit is set, readiness now
  additionally requires every stream to be within it, so `observer=ready
  streams=4` means four concurrently live streams. Record-only mode keeps
  membership semantics, having no acceptance role.
- **Pose was recorded at the simulator step rate.** Over a pre-Pi hold that
  lasts as long as the operator takes, that dominated the retained stream. The
  record is now thinned to `20 Hz`, far finer than the motion correlation needs.
  Readiness and staleness still observe every message.
- **`FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS` was unvalidated**, unlike the two
  tunables beside it, so a bad override would have failed the run mid-flight
  rather than in static preflight. It is validated now.
- **The pose fixture used invented frame names.** It now uses the names this
  repository recorded live on 10/04/2026: model root `sydney_regatta -> wamv`,
  and double-prefixed sensor parents `wamv/wamv/base_link`. That name does end
  in `base_link`, which is why the previous filter looked plausible - but it
  appears only as a parent, never as a `child_frame_id`.
- The withdrawn topic-mismatch claim is now marked withdrawn at the two places
  earlier in this file that still asserted it, and the runbook records a dated
  forward correction for the reopened current-source SITL acceptance.

Both new behaviours were confirmed to fail against the pre-fix implementation
before being accepted: with membership-only readiness,
`test_fail_closed_mode_rejects_a_stale_pre_pi_pose` fails; with unthrottled
recording, `test_samples_inside_the_gap_are_not_recorded` fails.

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=17
real-FCU helper suite: PASS cases=32
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS shell_cases=22 python_tests=30 runtime=not-started
Python: 115 passed
Node: tests=80 pass=80 fail=0
bundle manifest: 4/4 OK
GATE_RC=0
```

Still offline only. Test B remains **NOT RUN**, and no workstation-only VRX run
has confirmed the live frame names against a running simulator.

### Closure defects from the second review - 27/08/2026

- **The post-Pi budget was unrecoverable from a retained run.**
  `FCU_TO_VRX_OBSERVER_READY_TIMEOUT_SECONDS` governs acceptance but appeared in
  no artifact, so a later adjudicator could not prove which value applied.
  `manifest/environment.txt` now records `ready_timeout_seconds` and
  `observer_ready_timeout_seconds`; the pre-Pi marker carries both, the final
  `READY` marker carries the observer-ready timeout and the staleness limit that
  governed it, and the timeout failure message names the value it exceeded. A
  focused case requires all four keys, so the manifest cannot drift from the
  markers.
- **The approval question was reachable through preflight alone.** The
  enumerated 27/08 list held only physical and environmental items, while the
  approval sentence read "after all gates above pass". Current-source SITL
  acceptance and query-tier (T0b) closure are now enumerated beside them as
  evidence gates that no preflight command can satisfy, each with its explicit
  supersession alternative, and the approval sentence states that passing the
  preflight commands alone does not reach the approval question.
- Malformed emphasis in the `Board.md` and `wiki/Roadmap.md` forward-correction
  pointers is repaired.

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=17
real-FCU helper suite: PASS cases=32
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS shell_cases=23 python_tests=30 runtime=not-started
Python: 115 passed
Node: tests=80 pass=80 fail=0
bundle manifest: 4/4 OK
GATE_RC=0
```

### T0b query-source repair - 27/08/2026

The retained 26/08 evidence separates two failures. Run `175757` reached live
`connected: true`, `armed: false` and hardware safety ON, then the forced
MAVROS parameter pull did not return before its bounded timeout. Run `175855`
stopped earlier because the live `MOTOR_OUTPUTS` safety bit showed hardware
safety released. Repeating the same MAVROS pull would not distinguish a new
hypothesis.

The same Pi UART subsequently returned a complete `986`-parameter list through
MAVProxy's MAVFTP parameter path. The query mechanism therefore differs from
the failed MAVROS `PARAM_REQUEST_LIST` path. The 26/08 snapshot remains useful
regression input, but it does not close the fresh 27/08 query tier.

The Pi helper now has a default-off, probe-only
`probe-snapshot SNAPSHOT SHA256` path. It requires a freshly fetched complete
MAVProxy/MAVFTP snapshot, verifies its SHA-256 before any serial open, and waits
for the operator to type one exact fresh declaration and approval. The normal
probe then independently requires live connected/disarmed state and live
hardware safety ON before selecting exactly the `41` T0b safety, mapping and
rail values from the immutable snapshot.

The retained run records:

- `t0b_source=mavproxy-ftp-snapshot`, the absolute snapshot path, SHA-256 and
  exact operator declaration in `manifest/environment.txt`;
- the snapshot bytes in `manifest/artifacts.sha256` and
  `evidence/t0b_parameter_snapshot.parm`;
- the full snapshot parameter count and hash in `evidence/t0b.json`;
- exactly `41` selected values in `evidence/t0b_parameters.txt`;
- `REAL_FCU_T0B=PASS ... source=mavproxy-ftp-snapshot` and
  `REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started` only after all
  live and artifact checks pass.

The selector rejects a partial selector, absent approval, non-probe use, hash
drift, malformed snapshots, missing mapping/rail values and hardware safety
released. It starts no bridge, publishes no command, performs no parameter
write and keeps probe discovery at `LOCALHOST`. The original MAVROS parameter
path remains the default when no snapshot is explicitly selected.

Offline evidence:

```text
real-FCU helper suite: PASS cases=34
focused bridge tests:  34 passed
repository Python:     117 passed
Pi lifecycle:          PASS
live preflight:        PASS cases=17
SITL runner:           PASS cases=41
FCU-to-VRX:            shell_cases=23 python_tests=30 runtime=not-started
Node:                  tests=80 pass=80 fail=0
bundle manifest:       4/4 OK
```

The production snapshot converter was also exercised against both retained
26/08 complete snapshots. Each produced `41` selected values and the live
`RC1`/`RC3`, `SERVO3`/`SERVO1`, `800/800/2200` mapping and rails; the Test A
snapshot retained its `986`-parameter count and
`3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`
hash.

This is offline preparation only. T0b remains open until a fresh snapshot and
the live snapshot-backed probe pass on 27/08. Test B remains **NOT RUN**. The
source change also keeps current-source SITL acceptance open until its complete
supervised acceptance and independent adjudication are rerun.

### Pipeline 1 and Pipeline 2 live closure - 27/08/2026

The repository remained clean at
`147efe0270b3357a17ca6489c96d1722cd55c6f8`, with `HEAD` equal to
`origin/main` and divergence `0/0`, throughout both completed simulator-side
pipelines.

#### Pipeline 1 - workstation-only VRX frame proof

The exact W2 launch ran on ROS domain `77` with localhost-only discovery. The
capture in `/home/ghostzero/Desktop/vrx_pose_preflight_20260827/wamv_pose.yaml`
contained eight transforms on `/wamv/pose`:

```text
sydney_regatta          -> wamv
wamv/wamv/base_link     -> wamv/wamv/base_link/front_left_camera_sensor
wamv/wamv/base_link     -> wamv/wamv/base_link/front_right_camera_sensor
wamv/wamv/base_link     -> wamv/wamv/base_link/middle_right_camera_sensor
wamv/wamv/base_link     -> wamv/wamv/base_link/lidar_wamv_sensor
wamv/wamv/base_link     -> wamv/wamv/base_link/contact_sensor
wamv/wamv/imu_wamv_link -> wamv/wamv/imu_wamv_link/imu_wamv_sensor
wamv/wamv/gps_wamv_link -> wamv/wamv/gps_wamv_link/navsat
```

`sydney_regatta -> wamv` was the only world-parented transform. No
`child_frame_id` ended in `base_link`, so the former child-frame selector would
have matched nothing. The retained parser reported:

```text
VRX_FRAME_PROOF=PASS topic=/wamv/pose world_frame=sydney_regatta children=wamv
```

This directly proves that `/wamv/pose` is the correct ROS topic, the model-root
pose is present, and selecting the transform by configured world parent is the
correct live contract. Ctrl+C produced the expected SIGINT exit while all VRX
bridges and publishers stopped cleanly; the post-stop process scan found no
relevant survivor and domain `77` returned to zero nodes. The EGL/QML messages
were rendering warnings, not evidence faults.

#### Pipeline 2 - current-source SITL acceptance

The full supervised acceptance ran in
`/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`. Its repository
manifest records:

```ini
revision=147efe0270b3357a17ca6489c96d1722cd55c6f8
origin_main=147efe0270b3357a17ca6489c96d1722cd55c6f8
worktree=clean
```

The run passed safety release, the disarmed-ready baseline, the browser disabled
frame, arm, positive demand at steering `+0.10` and throttle `0.08`, neutral
release, negative demand at steering `-0.04` and throttle `0.09`, E-Stop and
normal disarm. It ended with:

```text
SITL_ACCEPTANCE=COMPLETE teardown=pending
SITL_VERDICT=PASS
SITL_SUPERVISOR_EXIT status=0 trigger=exit signal=none cleanup_rc=0 finalize_rc=0
```

Independent adjudication checked all ten retained evidence hashes and reported:

```text
STOP_ORDER_CHECK=PASS order=dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl
CONTROL_CROSSCHECK=PASS
VERDICT_CHECK=PASS
TEARDOWN_CHECK=PASS
SITL_POSTRUN_PORTS=FREE
SITL_POSTRUN_PROCESSES=FREE
SITL_ADJUDICATION=PASS
```

The retained verdict records `session_complete: true`, `verdict: PASS`, no
missing evidence and no capture fault. The teardown record reports every child
stopped, all governed ports free and `cleanup_rc: 0`. This closes the
current-source SITL evidence gate on `147efe0`; it remains simulator evidence
and does not prove real-FCU, parameter, thrust or vehicle-motion behaviour.

#### Remaining gate and Pipeline 3 authority

After the two closures above, T0b is the sole remaining evidence gate from the
original preconditions. The operator then stated:

> FCU and Pi powered; FCU disarmed; hardware safety ON; Herelink powered
> read-only with sticks neutral; propulsion battery disconnected; ESCs
> unpowered; propellers removed; hull restrained; Pi runtime stack down.

The operator separately approved Pipeline 3, the read-only MAVFTP snapshot.
That approval is recorded, but Pipeline 3 is **NOT RUN** at this point. No
serial link was opened, no fresh snapshot or T0b artifact was created, and no
parameter write, bridge start, mode change, arm, RC command, motor command or
thrust occurred under Pipeline 3. Herelink-to-VRX Test B remains **NOT RUN**.

## Pipeline 3, Pipeline 4 and pre-Test-B readiness repair - 27/08/2026

This section appends the results obtained after the Pipeline 3 authority record
above. It does not rewrite that earlier point-in-time statement.

### Pipeline 3 - fresh MAVFTP snapshot

The operator opened the direct serial link in read-only MAVProxy mode, loaded
the FTP and parameter modules, fetched `986` parameters, confirmed
`RC_OVERRIDE_TIME=0.5` and saved:

```text
pi=/home/imt-aqua-drone/Desktop/real_fcu_params_20260827_live.parm
workstation=/home/ghostzero/Desktop/pi_run_evidence/t0b_20260827/real_fcu_params_20260827_live.parm
sha256=3347835b8482c9fa00c54e9d53586d2beb1db87fabd92adfe599259a9c346900
parameters=986
selected=41
```

Offline validation also retained `ARMING_CHECK=0` and
`BRD_SAFETY_DEFLT=1.000000`. No parameter was written by Pipeline 3.

### Pipeline 4 - snapshot-backed T0b probe

The deployed `d88c712` bundle passed its four-member manifest and non-actuating
`check`. The separately approved read-only probe ran on the Pi in localhost
discovery and reported:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained source=mavproxy-ftp-snapshot snapshot_parameters=986
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started query_source=mavproxy-ftp-snapshot
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

The complete copied run is:

```text
/home/ghostzero/Desktop/pi_run_evidence/t0b_probe_20260827_174820
```

The retained live state is connected, disarmed and `MANUAL`, with hardware
safety ON. The artifact resolves steering `RC1`, throttle `RC3`, left
`SERVO3`, right `SERVO1`, RC rails `1102/1515/1927` and both output rails
`800/800/2200`. T0b is closed. This is read-only parameter, mapping, rail and
state evidence; it is not Herelink-to-VRX motion evidence.

### Test B approval and readiness audit

The operator explicitly approved running Test B. The approval is recorded, but
does not replace the remaining pre-run evidence and physical gates.

The full offline readiness audit reproduced two defects before any live Test B
launch:

1. W1 started its Pi JSONL recorder only when armed observation was enabled.
   There was no clean, supervisor-owned way to retain the required disarmed
   all-stream measurement without entering the Pi helper's arm-window contract.
2. W1's certification suite inherited the caller's `LIVE_*` selectors. An armed
   certification therefore evaluated the default command fixture as armed and
   failed its expected monitored-hold assertion even though the production
   emitter was correct.

The offline repair adds default-off `LIVE_FCU_TO_VRX_MEASUREMENT=1`. It is
mutually exclusive with armed observation, requires fanout and the live-read
mapping/rails, starts W1's subscriber-only Pi recorder with `stale_seconds=0`,
and emits a Pi command that stays disarmed-only with hold and fanout enabled.
`summarize-disarmed` validates both retained JSONL streams and reports the eight
stream gaps, PWM skew, thrust delay and stationary pose drift without choosing
acceptance thresholds. It rejects armed, unsafe, non-neutral, short, empty,
malformed and ROS-contaminated evidence. The W1 suite now clears inherited live
selectors before its default fixtures and exercises configured modes explicitly.

Offline results after the repair:

```text
Pi lifecycle:             PASS
live-dashboard preflight: PASS cases=20
real-FCU helper suite:    PASS cases=34
SITL runner suite:        PASS cases=41
FCU-to-VRX workstation:   PASS shell_cases=23 python_tests=35 runtime=not-started
Python:                   122 passed
Node:                     pass=80 fail=0
bundle manifest:          4/4 OK
git diff --check:         clean
```

### Forward blocker correction - 28/08/2026

The blocker sentence near the start of this diary records the opening state of
27/08/2026, not the close. The snapshot-backed T0b query tier passed later that
day with `41` selected reads and retained evidence. The integrated SITL
acceptance passed on revision `147efe0`; it is historical evidence rather than
current-source acceptance after later revisions, and any use in place of a
newer run remains an explicit scoped supersession. Fresh physical state and
Test B approval remain operator gates, and Test B remains not formally
accepted. Continue from the 28/08/2026 diary for the current retry.

No simulator, Pi helper, FCU bridge, Herelink command or Test B motion ran under
this repair. The worktree is modified and W2's clean pushed parity gate therefore
blocks launch until publication. Landing the repair changes the exact revision
from the successful `147efe0` SITL run; current-revision SITL acceptance must be
rerun or explicitly superseded before the armed phase. The disarmed measurement,
selection and recording of explicit limits, and a fresh physical declaration
also remain outstanding. Test B remains **NOT RUN**.

### Live disarmed-measurement preflight failure and ordering repair - 27/08/2026

After `aa4a07a` was published, the operator supplied the fresh physical
declaration and the Pi preflight passed after rebuilding HailoRT DKMS for the
new running kernel `6.8.0-1063-raspi`. W1 reached workstation service readiness
in:

```text
/home/ghostzero/Desktop/live_dashboard_workstation_20260827_184220
```

W2 reached VRX pose baseline and UDP `14555` prestart readiness in:

```text
/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260827_184300
```

The first Pi start then failed closed during runtime preflight:

```text
STOP: existing endpoint on /hailo/overlay/image_raw (publishers=0, subscribers=1)
TEARDOWN=PASS
```

The retained Pi run is
`hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260827_184424`.
The subscriber was W1's intended Pi evidence recorder. W1 had created it during
workstation service startup, before the Pi helper could complete its
zero-existing-endpoint sentinel. This made the new measurement launch order
internally contradictory; the failure was not an operator or Hailo defect.

The repair keeps W1's dashboard, rosbridge and web-video services at the initial
startup phase, but defers `pi-evidence-observer` until all seven Pi publishers
are observed in the arrival phase. W1 then starts the recorder and waits for its
READY state. The same order applies to disarmed measurement and armed
observation, while the default view-only path remains unchanged.

A focused test reproduced the original early-subscriber behavior, then passed
after the repair. It now requires both that workstation service startup creates
no Pi evidence subscriber and that publisher arrival starts the subscriber
before the observer READY wait. Offline verification after the repair:

```text
Pi lifecycle:             PASS
live-dashboard preflight: PASS cases=20
Node:                     pass=80 fail=0
git diff --check:         clean
```

No FCU arming, Herelink input, output excursion or VRX Test B motion occurred.
W1 subsequently reported `WORKSTATION_TEARDOWN=PASS` and exit status `0`. W2
stopped bridge, observer and VRX in order and left UDP `14555` free; because it
had reached PRESTART rather than final READY, its expected interrupted-run exit
status was `130` and it did not emit the post-READY teardown PASS marker. Both
failed run directories are retained. Test B remains **NOT RUN**.

### Live disarmed measurement and selected Test B limits - 27/08/2026

The ordering repair was published as `1c1dff5`. A fresh disarmed measurement
then reached full W1 and W2 readiness without arming or Herelink input. The
retained workstation runs are:

```text
/home/ghostzero/Desktop/live_dashboard_workstation_20260827_185101
/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260827_185133
```

The Pi source run is retained on the Pi at:

```text
/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260827_185227
```

W1 observed all seven live topics, started its recorder only after the Pi
publishers existed, reached recorder READY, passed the seven rate probes and
entered supervision. W2 reached the live pose baseline, decoded the real
`SERVO3`/`SERVO1` output at neutral, and reached four-stream observer READY.
The FCU remained connected, disarmed, hardware-safe and neutral throughout the
measurement.

The 60-second common-window summary passed and reported:

```text
Pi maximum gaps:
  camera=0.275542186 s
  rc_out=0.497195719 s
  state=1.039521457 s
  sys_status=0.309898691 s
VRX maximum gaps:
  left_thrust=0.291955471 s
  pose=0.129303774 s
  right_thrust=0.291961215 s
  servo_output_raw=0.291760135 s
maximum Pi-PWM to UDP-PWM skew=223.019194 ms
maximum UDP-PWM to thrust delay=9.633272 ms
stationary pose drift=0.081450536 m
FCU_TO_VRX_DISARMED_MEASUREMENT=PASS window_seconds=60 thresholds=not-selected
```

The following explicit limits are selected from those current-source
measurements for the bounded armed phase:

```text
LIVE_ARMED_OBSERVATION_STALE_SECONDS=5
FCU_VRX_OBSERVER_STALE_SECONDS=5
MAX_PWM_SKEW_MS=750
MAX_THRUST_DELAY_MS=100
MAX_MOTION_DELAY_SECONDS=10
MIN_MOTION_METRES=0.25
LIVE_ARMED_OBSERVATION_MAX_SECONDS=60
LIVE_ARMED_OBSERVATION_FINAL_SECONDS=60
LIVE_RUN_SECONDS=600
```

The stale limit is more than four times the largest measured Pi gap. The PWM
skew and thrust-delay limits retain more than three and ten times their
respective measured maxima. The motion threshold is more than three times the
measured stationary drift, with a ten-second correlation window. W1 required
`403 s` to declare seven-topic arrival in this run, so the ten-minute Pi source
window preserves time for the rate probes, one bounded 60-second armed window,
neutral return and a 60-second final safe-state window without repeating the
short-timeout failure class.

Teardown completed in the required order. The Pi stopped its safety monitor,
Hailo bridge, MAVROS, MAVProxy and telemetry fanout with `TEARDOWN=PASS`. W2
stopped bridge, observer and VRX in order, confirmed UDP `14555` free and exited
with status `0`. W1 stopped its evidence observer and three workstation services
with `WORKSTATION_TEARDOWN=PASS` and status `0`.

This closes the disarmed measurement and threshold-selection gate only. No FCU
arming, Herelink stick excursion, asymmetric motor output or VRX motion occurred,
so Test B remains **NOT RUN**. The successful SITL acceptance was earned on
`147efe0`; the current revision still requires a fresh SITL acceptance or an
explicit operator supersession naming that gate before the armed phase.

### Pi measurement copy-back and log audit - 27/08/2026

The complete Pi run was copied to the workstation at:

```text
/home/ghostzero/Desktop/pi_run_evidence/test_b_measurement_20260827_185227
```

The copied supervisor log verifies helper SHA-256
`8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c`,
an initially clean ROS graph, the outbound-only
`127.0.0.1:14556 -> 10.120.2.168:14555` fanout, zero safety-monitor
publishers, connected/disarmed MAVROS state, six-topic telemetry sampling and
neutral output `SERVO1=800`, `SERVO3=800`. The Pi reached
`PI_SOURCE_STACK_READY=PASS mavros_topics=29`, retained at least `3600` Hailo
frames and recorded a thermal peak of `67750 mC`, below the `80 C` abort limit.

The Pi was stopped deliberately during the disarmed live window. Its
`status=130 trigger=signal signal=INT` is therefore the expected operator-stop
status for this measurement, followed by ordered child shutdown and
`TEARDOWN=PASS cleanup_rc=0`. The Hailo log's final `KeyboardInterrupt` is the
matching process interruption during that teardown, not an earlier inference
failure.

Two bounded diagnostics remain in the retained logs: MAVROS version-service
requests timed out during startup, and MAVProxy could not decode its cached
terrain `filelist_python`. Neither prevented heartbeat, connected/disarmed
state, the required telemetry samples, `986` FTP parameters, fanout readiness,
Hailo publication or the passed disarmed evidence summary. They are not treated
as Test B acceptance evidence and do not replace the still-required armed
correlation and final adjudication.

The supervisor also recorded `POWER_TELEMETRY=UNAVAILABLE`. Thermal protection
remained active and did not trip, but this run is not represented as direct
evidence for Pi undervoltage or throttling flags.

### First armed Test B attempt - failed, motion observed - 27/08/2026

The operator explicitly superseded the current-revision SITL rerun for
`eb9a337`, repeated the physical declaration and authorised the armed Test B
attempt. The retained workstation runs are:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260827_191952
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260827_192020
```

The Pi run was copied to:

```text
/home/ghostzero/Desktop/pi_run_evidence/test_b_armed_failed_20260827_192234
```

The machine evidence captured a real motion chain. The first asymmetric FCU
output was left `SERVO3=2200` and right `SERVO1=800`, approximately `49.99 s`
after arming. The matching UDP frame had `0.0856 ms` left/right skew. W2 mapped
that frame to left/right thrust `800.0/0.0 N` within `0.87 ms`, and VRX pose
moved `2.47946 m` within `9.979 s`. Neutral `800/800` output returned `0.749 s`
after the excursion. The operator also observed the VRX boat move while moving
the Herelink stick.

This attempt is **FAILED / NOT ACCEPTED**. The Pi abort record contains:

```text
reason=ARMED_WINDOW_DEADLINE topic=/mavros/state
```

The safety monitor progressed `READY -> ARMED -> ABORT`. Its last retained FCU
state was connected and still armed in `MANUAL`. W1 later recorded
`stale_camera`, W2 recorded `stale_left_thrust`, and canonical adjudication
fails. Even when those terminal observer abort events are excluded for
diagnosis, the record still lacks the required connected disarm after neutral
return. No retained recorder captured final disarm, neutral restoration and
hardware safety ON together. The operator's later statement that the FCU was
disarmed, hardware safety ON and sticks neutral occurred outside the evidence
window and is not substituted for that missing acceptance evidence.

The Pi line `STOP: dashboard command publication detected` was a false
classification. The shared abort file was non-empty because the safety monitor
recorded `ARMED_WINDOW_DEADLINE`; no retained evidence attributes the stop to a
dashboard command publisher. The copied log shows every named child being
stopped and no `CLEANUP_ERROR`. The Pi's `cleanup_rc=1` was forced by the
non-empty abort record, so it does not establish a surviving child process.

The first attempt also used `HAILO_LOCAL_WINDOW_MODE=fullscreen`, which covered
the Pi desktop and could not be resized with the attempted shortcuts. Future
supervisor commands default to `resizable`.

### Explicit unbounded retry repair - offline only - 27/08/2026

The operator authorised removal of the armed-session and outer-runtime
deadlines for the retry. The selector is deliberately explicit and paired:

```text
LIVE_RUN_SECONDS=0
LIVE_ARMED_OBSERVATION_MAX_SECONDS=0
```

A zero/positive mismatch fails validation. The paired mode retains positive
`LIVE_ARMED_OBSERVATION_FINAL_SECONDS` and
`LIVE_ARMED_OBSERVATION_STALE_SECONDS`, so final safe-state restoration, topic
freshness, disconnect, second-arm, command-sentinel, rail and thermal guards
remain fail-closed. The test runs armed until the operator disarms; it does not
end merely because time elapsed.

After connected/disarmed neutral output and hardware safety ON are recorded,
the Pi monitor transitions through final verification and emits
`ARMED_OBSERVATION=PASS`, `PI_SOURCE_WINDOW=COMPLETE`,
`PI_SOURCE_HOLD=ACTIVE`, and
`PI_SOURCE_HOLD_MODE=completed-armed teardown=W2,W1,Pi`. That completed hold
keeps MAVProxy, MAVROS, Hailo, fanout and Pi-local safety checks alive without
depending on W1 nodes. The retry stop order is therefore W2, then W1, then P1,
and is permitted only after the completion markers appear.

The helper now reports the actual first abort record rather than the generic
dashboard-publication message. W1 wires the armed-monitor unit suite into its
static gate. Focused tests cover finite and zero deadline selection, mismatched
pair rejection, stale-data failure under zero armed deadline, completion
handoff, the completed hold's local-only contract, truthful abort reporting,
the revised teardown marker and the default resizable display.

Current uncommitted artifact identities after this repair are:

```text
Pi helper size=95316 sha256=ca0c1ff834ac347a04e8a59a01a85c05abe78d939e2083397c2f121a9b24314e
W1 size=38444 sha256=d4fc4a72457d8d0d73ef3804023028239036abaaf18a3e4962cb8bd7f2afdbd6
W2 size=26906 sha256=a5afddc81d59a39d63e7cca77a7b3852e30b5a555f1be2e04f3746f5540bdd5f
```

Offline verification after the repair:

```text
Pi lifecycle:             PASS
live-dashboard preflight: PASS cases=22
real-FCU helper suite:    PASS cases=34
SITL runner suite:        PASS cases=41
FCU-to-VRX workstation:   PASS shell_cases=23 python_tests=35 runtime=not-started
Python tools:             123 passed
Node:                     tests=80 pass=80 fail=0
bundle manifest:          4/4 OK
git diff --check:         clean
```

No live retry has run with this repair. Because it changes source after
`eb9a337`, the explicit SITL supersession naming `eb9a337` does not carry
forward. A published clean revision, exact-revision SITL acceptance or a new
explicit supersession, fresh physical declaration and separate live approval
are required before a retry.

`RC_OVERRIDE_TIME=0.5` remains temporary for this campaign. Restore it to
`3.0`, confirm live readback and retain a rollback snapshot after Test B is
accepted or abandoned, or before any different operation.

### Publication update - 27/08/2026

The explicit paired-zero retry repair and its offline verification were
published as `d9dd120` with subject
`fix(test-b): support operator-controlled armed runs`. The earlier
`Current uncommitted artifact identities` label records the pre-publication
state at the time those bytes were calculated. The helper, W1 and W2 byte
identities themselves are unchanged. No live retry has run on `d9dd120`.

### Paired-zero live retry and EOD handoff - 27/08/2026

The published paired-zero mode was exercised from clean revision `550b992`.
The retained run directories are:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260827_200652
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260827_200727
Pi=/home/ghostzero/Desktop/pi_run_evidence/test_b_unbounded_failed_20260827_200821
```

P1 recorded `duration=unbounded`, `armed_deadline=disabled` and
`ARMED_OBSERVATION_BASELINE=PASS`. The safety monitor remained in `READY`;
there was no `ARMED` transition, command abort, deadline abort, asymmetric
output or new motion evidence. The final retained FCU sample was connected,
disarmed and in `MANUAL`. Hardware safety ON is proven at the baseline only;
no final hardware-state declaration is inferred from these logs.

The retry failed approximately `234 s` after the live window began. Three
successful graph queries for `/mavros/global_position/raw/fix` each reported
`publisher count 0`, then the data-plane fallback was skipped with
`reason=no-declared-type`. This conflicts with the retained NavSatFix sample
and W1's immediately preceding `40` messages in `10.02 s` at `4.00 Hz`.
MAVROS remained alive and continued its no-fix GPS warnings. The evidence
therefore identifies a source-verification false negative, not an FCU
disconnect and not a failure of the paired-zero deadline mode.

P1 stopped all named children with `TEARDOWN=PASS` and `cleanup_rc=0`. Loss of
the Pi streams then caused the W1 observer to abort on `stale_camera`, the W2
observer to abort on `stale_left_thrust`, and the W1 RC-input rate probe to
receive zero messages. W2 stopped bridge, observer and VRX with `cleanup_rc=0`;
W1 stopped dashboard, web-video-server and rosbridge with
`WORKSTATION_TEARDOWN=PASS cleanup_rc=0`. A workstation post-run check found
no governed process and no listener on `8002`, `8080`, `9090` or `14555`.

The first armed attempt remains a genuine functional result for the observed
interval: retained machine evidence proves Herelink input reached real-FCU
output, mapped thrust and `2.47946 m` of VRX motion, and the operator observed
the boat move in VRX. No video was retained because the armed deadline ended
the source window before the operator could record one. This does not convert
the attempt into formal acceptance because the recorders did not capture the
required final connected/disarmed, neutral and hardware-safe state.

Test B closes 27/08/2026 as **ATTEMPTED - FAILED / NOT FORMALLY ACCEPTED**.
The minimal next-source change is to make the existing bounded, accumulated-
discovery MAVROS source view the default while retaining exact publisher
identity checks. The repeated W1
`CHILD_EXITED` marker in failure hold also needs one-shot reporting. After the
minimal repair is tested and published, the next operator flow is the direct
`W1 -> W2 -> P1` Test B pipeline. No separate SITL, T0b, disarmed-measurement
or standalone Pi preflight is scheduled; the supervisors' built-in fail-closed
checks remain mandatory.

`RC_OVERRIDE_TIME=0.5` remains the last verified live value. Rollback to
`3.0`, live readback and a retained rollback snapshot remain pending after the
campaign is accepted or abandoned, or before any different operation.

### EOD minimal verifier repair - 27/08/2026

The source failure is bounded to the default daemonless graph-query path. The
retained NavSatFix sample and the W1 `4.00 Hz` measurement prove the GPS data
stream remained live while a fresh graph participant reported zero publishers.
The operator also reported heavy rain and hail during the run. That weather can
degrade GNSS fix quality, but it cannot explain a ROS publisher-count result;
the weather is context, not the cause of the supervisor abort.

The narrow repair promotes the existing bounded six-topic `rclpy` source view
by changing `LIVE_MAVROS_SOURCE_BATCH` from default `0` to default `1`. It
retains the exact publisher-count, `/mavros` identity, retry, deadline and
command-sentinel verdicts. Explicit `LIVE_MAVROS_SOURCE_BATCH=0` remains
available only to reproduce the legacy per-query diagnostic path. No
data-plane-only bypass or publisher-identity relaxation was added.

W1 now latches each governed child PID/PGID exit message, so failure hold keeps
returning failure without printing the same `CHILD_EXITED` line every second.
Red-first focused coverage pinned the new default and one-shot marker; the Pi
lifecycle suite and W1 preflight suite then passed, with W1 reporting
`cases=22`.

Current repaired artifact identities are:

```text
Pi helper size=95316 sha256=8cfd313eb8c6a65e6ef903c8d240d91500f5dfea32a52837c2aa7e8425cdbfe5
W1 size=38763 sha256=00effd85198cf156d08a450504dc9dc4ae0b67a2cb3fa99ea064faa0ff00a3ac
```

This is an offline repair ready for live validation, not proof that discovery
can never be transient. Test B remains **ATTEMPTED - FAILED / NOT FORMALLY
ACCEPTED**. The next live action is the same direct `W1 -> W2 -> P1` paired-zero
pipeline after transferring the repaired helper. No separate SITL, T0b,
disarmed-measurement or standalone Pi preflight is scheduled; all built-in
supervisor gates and fresh physical/live approvals still apply.

The complete offline EOD verification is:

```text
Pi lifecycle:             PASS
live-dashboard preflight: PASS cases=22
real-FCU helpers:         PASS cases=34
SITL runner:              PASS cases=41
FCU-to-VRX:               PASS shell_cases=23 python_tests=35 runtime=not-started
Python tools:             123 passed
Node:                     tests=80 pass=80 fail=0
bundle manifest:          4/4 OK
shell syntax:             PASS
git diff --check:         clean
```
