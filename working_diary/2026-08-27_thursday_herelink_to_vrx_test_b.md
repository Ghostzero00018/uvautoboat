# Thursday 27/08/2026 - Herelink-to-VRX Test B

**PRE-DIARY - NOT STARTED. TEST B IS NOT RUN. NO APPROVAL OR PHYSICAL STATE
CARRIES FROM 26/08/2026.**

This is the sole 27/08/2026 working diary. It was prepared at the 26/08/2026
close. It records inherited evidence and tomorrow's gates; it does not schedule,
authorise or start a powered run.

## Carry-over blockers - read before any Test B work

- `RC_OVERRIDE_TIME=0.5` remains live for Test B; rollback to `3.0` remains
  mandatory after Test B or before any different operation.
- Test B is **NOT RUN** and remains blocked by `/wamv/pose` versus
  `/model/wamv/pose`. Repair and prove that contract offline before any live
  Test B start.

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
assumption. Current source defaults W1 publisher arrival to `360 s` and W2
readiness to `120 s`. The Pi helper defaults its armed-observation maximum,
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

The Test A approval is expired. Test B requires a separate explicit approval
after all gates above pass.

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
