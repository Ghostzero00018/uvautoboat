# Monday 03/08/2026 - ros2 --no-daemon graph-query hardening (+ window size and Pi-FCU if time)

> **START HERE - carried-forward known issue.** The live-dashboard supervisor
> (`tools/pi_live_hailo_mavlink_dashboard.sh`) drives its graph and source checks with
> `ros2 ... --no-daemon --spin-time 2` queries. These are slow and can intermittently misreport.
> On 24/07/2026, the live-hold `require_mavros_source` check read a FALSE `publisher count 0` on
> `/mavros/imu/data` while MAVROS/IMU were provably healthy, self-stopping the hold with
> `status=1`. A separate final-verification run cumulatively overran its budget; that sequence
> includes `bounded_topic_echo`, which invokes `ros2 topic echo` directly rather than the graph
> wrapper. Its root cause remains open and must not be conflated with the false graph result.
> Hardening the graph/source queries is the main task for this day, with final-verification timing
> retained as separate evidence.
>
> **Forward correction, 03/08/2026.** The separation above is confirmed. The final-verification
> overrun is consistent with the cumulative cost of the serialized daemonless queries; no fault was
> identified, but the logs carry no per-query timing, so a contributing fault cannot be excluded.
> The wording "a FALSE `publisher count 0`" overstates what the logs support: the reading is
> established, its falsity is not. See the Block A and Block B1 sections below, which supersede this
> note where they differ.

## Status

Prepared initially at EOD 24/07/2026 for the planned vacation interval 25/07 - 02/08/2026 and
resumption on Monday 03/08/2026. At that preparation point, the window/telemetry stack was trimmed
and verified across three full-stack runs on 24/07, all committed and pushed to `origin/main`. The
dashboard-to-real-motor track remains parked on a hardware blocker (receive-only Pi-to-FCU serial
link). Side-work recorded on 27/07 added a C++ bridge reference (`ab16f15`) plus a runnable Python
equivalent (`tools/servo_command_bridge.py`); see
`working_diary/2026-07-27_monday_fcu_vrx_bridge_reference.md`.

Forward update on 01/08/2026: the Python bridge defaults, validation, logging, teardown lifecycle,
and this runbook were revised for the workstation-only SITL path. A local harness with synthetic
MAVLink input verified the bounded process-level safety evidence recorded below. The integrated
ArduRover SITL + VRX run remains **NOT RUN**, and no real FCU, motor, dashboard helper, write guard,
or safety-monitor behaviour was exercised or changed by that preparation.

## Goals

1. **Main - harden the `ros2 --no-daemon --spin-time 2` graph/source checks.** Make the
   supervisor robust so healthy telemetry is never intermittently misread. This is a
   correctness/robustness fix, not another timeout widen.
2. **Secondary (if time) - Hailo window image size.** The Pi-local HighGUI `"Output"` window
   letterboxes / grows and does not hold the native frame size. Leaving it as-is is acceptable;
   attempt a clean fix only if research (or the supervisor's reply) points to one. An email was
   sent to the supervisor 24/07 for help or a contact.
3. **Secondary (if time) - Pi-to-FCU command sending.** The Pi reads FCU telemetry but cannot
   send to it over `/dev/ttyAMA0` (receive-only). Progress needs a wiring / serial fix at the
   boat, or the supervisor's servo-activation file (requested 24/07). Do not arm a real vehicle
   outside the propellers-removed bench gate.

## Evidence carried forward

- **Two distinct 24/07 failures.** `require_mavros_source` and the graph/source portions of
  `final_graph_verification` use `ros2_graph_query` / `ros2_graph_query_before`, i.e.
  `ros2 ... --no-daemon --spin-time 2`. `bounded_topic_echo` instead invokes `ros2 topic echo`
  directly. Run `live_dashboard_20260724_175832` failed final verification at ~90 s during the IMU
  sample; its cumulative timing root cause remains open. Run `live_dashboard_20260724_184228`
  recorded `final_verification=116s` (passed under the new 180 s budget), then the hold monitor read
  a false `publisher count 0` on `/mavros/imu/data` while `mavros.log` showed IMU healthy. The latter
  is direct graph-query evidence; do not assign the earlier overrun the same root without further
  log evidence. Logs are copied under `~/Desktop/test_logs_folder/`.
- **FCU hardware (from QGC tlogs, no Pi contact).** `Cube Orange+` running `ArduRover 4.6.3`,
  `FRAME_CLASS=2` boat/skid-steer. Thrusters on the FCU servo rail: LEFT = `SERVO3`
  (`SERVO3_FUNCTION=73`), RIGHT = `SERVO1` (`SERVO1_FUNCTION=74`), PWM 800-2200 neutral 800.
  `ARMING_REQUIRE=1`; Cube hardware safety switch (`BRD_SAFETY_DEFLT=1`). RC3 (throttle)
  min/trim/max 1102/1515/1927.
- **Pi-to-FCU link.** Pi `/dev/ttyAMA0` @57600 = FCU `SERIAL1` (`PROTOCOL=2` MAVLink2,
  `OPTIONS=0`, `BRD_SER1_RTSCTS=2`). Pi receives telemetry but the FCU answers nothing the Pi
  sends (param read + `MAV_CMD_DO_MOTOR_TEST` returned no `PARAM_VALUE` / `COMMAND_ACK`; both
  servos stayed at neutral 800); Herelink commands work. Pi UART is correctly enabled (Pi 5,
  `enable_uart=1`, `disable-bt`, `uart0`, TX DMA allocated). Suspects: the Pi TXD (GPIO14) ->
  Cube SERIAL1 RX wire not connected, or `BRD_SER1_RTSCTS=2` on a 3-wire link. Read-only probes
  on the workstation: `~/tx_probe.py`, `~/motor_test.py`, `~/motor_test2.py`, `~/uart_check.sh`;
  launcher `~/pi_cmd.sh`.
- **Window.** 23/07 verdict: benign `KEEPRATIO` letterbox / Qt upscale. The operator launcher now
  uses `HAILO_LOCAL_WINDOW_MODE=resizable`.

## Plan and gates

### Task 1 - graph-query hardening (main)

Read-only first: confirm from the 24/07 logs whether the misreads track DDS/discovery transients.
Then take the smallest robust change - options to weigh: (a) use the ros2 daemon for these
queries instead of `--no-daemon`; (b) verify source presence via a short real `rclpy`
subscription instead of `ros2 topic info`; (c) add tolerance / more retries. Any helper edit
or supervisor edit requires recomputing the changed artifact's SHA-256 and byte size after the
edit, then propagating every current helper/supervisor hash and size pin across the preflight
constant, focused regression assertions, and wiki manifest. Enumerate all tracked occurrences;
do not assume a fixed count. Keep the supervisor-hash assertion and both focused suites green
(`bash tools/test_pi_live_hailo_mavlink_dashboard.sh`,
`bash tools/test_live_dashboard_preflight.sh`). Verify with a fresh full-stack run that reaches a
clean `PI_SUPERVISOR_EXIT status=0` after an operator Ctrl+C.

### Task 2 - window size (if time, only with a clean fix)

Research-led only; add no instrumentation. Fold in any supervisor reply.

### Task 3 - Pi-to-FCU (if time)

Default scope at the boat is inspect-only. Power the boat fully off before inspecting the Pi TXD ->
Cube SERIAL1 RX wiring, and do not alter it during this block. For a powered parameter inspection,
read back and retain the current `BRD_SER1_RTSCTS` value before proposing any change. The missing
TXD connection and an incompatible flow-control setting remain suspects, not established causes.

Any wiring change, `BRD_SER1_RTSCTS` change, or `tx_probe.py` run requires a separate explicit
approval for a propellers-removed, restrained bench block. In that approved block, power off before
touching wiring, preserve the original wiring and parameter value for rollback, change only one
suspect at a time, and read the parameter back after a write. `tx_probe.py` remains a
workstation-side probe run from `cd ~`. Restore the recorded original parameter and wiring after a
failed test or before closing the block unless the user explicitly accepts the new state. Success
is a `FRAME_CLASS` value read back from the FCU. Only after the link is bidirectional does the motor
track resume, still behind its own propellers-removed bench gate.

**Alternative that does not need the boat - SITL.** The 27/07 bridge reference and its Python
equivalent are UDP-based, so against a simulated autopilot (SITL on localhost) nothing crosses
the blocked serial link. Running `tools/servo_command_bridge.py` against SITL proves the
autopilot-to-simulator command path (`SERVO_OUTPUT_RAW` -> `/wamv/thrusters/{left,right}/thrust`)
while the wiring fix is pending. The local process-level safety checks below do not prove the
integrated ArduRover SITL + VRX path or real motor output. For this run, `publish_sensors` must
remain `false`; outbound sensor injection is not validated and remains outside scope. Because the
bridge publishes on protected command topics, run it in simulation on its own `ROS_DOMAIN_ID`,
never alongside the live Pi stack. Full analysis in
`working_diary/2026-07-27_monday_fcu_vrx_bridge_reference.md`.

#### SITL bridge safety gate (required before the first run)

The bridge safety lifecycle has been exercised locally against the actual Python file with
synthetic MAVLink input. SIGINT, SIGTERM, and repeated-signal teardown each exited `0` and
published a new trailing `0.0` after held non-zero samples on both thrust topics. Parameter
validation rejected non-finite or non-positive thrust, duplicate servo channels, and a neutral
value outside the PWM range. Python syntax passed; the two existing import-order lint findings
are unchanged and deferred.

The integrated ArduRover SITL + VRX sequence below remains prepared but **NOT RUN**. It is a
user-run workstation test, and every existing inspection and live gate below still applies.
ArduPilot SITL is a prerequisite; treat it as missing until the executable and MAVProxy checks
below pass.

Forward correction for 03/08/2026: the bridge defaults now use a provisional SITL starting profile
of `1100/1500/1900`, pending the parameter inspection below. The real-boat `800/800/2200` profile
must be supplied as explicit runtime configuration, and left/right servo output channels remain
inspection-gated in both environments.

The official installation commands below are **UNTESTED on this workstation** and require network
access plus package installation. Run them only if `~/ardupilot` is still absent:

```bash
cd ~
git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git
cd ~/ardupilot
Tools/environment_install/install-prereqs-ubuntu.sh -y
source ~/.profile
test -x "$HOME/ardupilot/Tools/autotest/sim_vehicle.py"
command -v mavproxy.py
```

Whether ArduPilot was already present or newly installed, retain its exact revision and MAVProxy
version before starting T1:

```bash
git -C "$HOME/ardupilot" rev-parse HEAD
mavproxy.py --version
```

**Host + terminals:** workstation only. Use one new or idle one-shot setup terminal S0, then five
new or idle foreground terminals: T1 for VRX, T2 for SITL/MAVProxy, T3 for the bridge, and
T4-L/T4-R for continuous left/right thrust observation. T1, T2, T3, T4-L, and T4-R remain
foreground until the ordered stop phase. Do not start the live Pi stack or
`launch_autoboat_complete.sh`; `tools/pi_live_hailo_mavlink_dashboard.sh` deliberately aborts when
either VRX thrust topic appears in its ROS domain.

**cwd + env:** run this exact setup first in S0 and then in every foreground terminal before its
terminal-specific command. Domain `42` is the proposed isolated test domain; if its bounded
occupancy gate below is not clean, choose another domain and replace `42` consistently in S0 and
all five foreground terminals.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
source /opt/ros/jazzy/setup.bash
source /home/ghostzero/seal_ws/install/setup.bash
export ROS_DOMAIN_ID=42
printf 'ROS_DOMAIN_ID=%s\n' "$ROS_DOMAIN_ID"
```

In S0, before launching any foreground process, create one unique evidence directory. Plain
`mkdir` is intentional: a timestamp collision aborts instead of reusing an existing directory.

```bash
SITL_RUN_DIR="/tmp/uvautoboat_sitl_d${ROS_DOMAIN_ID}_$(date +%Y%m%d_%H%M%S)"
if ! mkdir -- "$SITL_RUN_DIR"; then
  printf 'ABORT: SITL_RUN_DIR already exists: %s\n' "$SITL_RUN_DIR" >&2
  exit 1
fi
printf 'export SITL_RUN_DIR=%q\n' "$SITL_RUN_DIR"
```

Copy the exact printed `export SITL_RUN_DIR=...` line into T1, T2, T3, T4-L, and T4-R after each
terminal's cwd/environment setup. Do not reconstruct the value and do not run `mkdir` again. In
each foreground terminal, `test -d "$SITL_RUN_DIR"` must pass before its terminal-specific command.

Still in S0, take two bounded daemonless graph snapshots, separated by a short discovery wait:

```bash
DOMAIN_GATE_STATUS="${SITL_RUN_DIR}/domain_preflight_status.log"
for snapshot in 1 2; do
  for entity in node topic; do
    evidence="${SITL_RUN_DIR}/domain_${ROS_DOMAIN_ID}_${snapshot}_${entity}.log"
    timeout 8s ros2 "$entity" list --no-daemon --spin-time 2 >"$evidence" 2>&1
    status=$?
    if [ "$status" -ne 0 ]; then
      printf 'DOMAIN_PREFLIGHT=ABORT snapshot=%s entity=%s status=%s evidence=%s\n' \
        "$snapshot" "$entity" "$status" "$evidence" | tee -a "$DOMAIN_GATE_STATUS"
      cat "$evidence"
      exit 1
    fi
    if [ -s "$evidence" ]; then
      printf 'DOMAIN_PREFLIGHT=ABORT snapshot=%s entity=%s reason=output evidence=%s\n' \
        "$snapshot" "$entity" "$evidence" | tee -a "$DOMAIN_GATE_STATUS"
      cat "$evidence"
      exit 1
    fi
  done
  if [ "$snapshot" -eq 1 ]; then
    sleep 3
  fi
done
printf 'DOMAIN_PREFLIGHT=BOUNDED_EMPTY domain=%s\n' "$ROS_DOMAIN_ID" | \
  tee -a "$DOMAIN_GATE_STATUS"
```

Any node/topic output, timeout, or command error aborts before T1. Paste back the status line and
named evidence file, choose another domain, create a new timestamped `SITL_RUN_DIR`, and rerun the
entire gate. Two empty snapshots are only a bounded preflight observation; they cannot prove that a
late participant will not join the domain.

Every retry is a new run. Complete the prior ordered or FAIL process cleanup and the stale
process/listener checks below, then create a new directory in S0. Never reuse, truncate, or
overwrite a previous run directory or its logs.

**Prereqs + stop conditions:** confirm VRX is the only ROS simulation stack, no live Pi/dashboard
session is running, the Cube and real motors are not involved, and the ArduPilot checks above pass.
The first/reset SITL run uses `-w`; omit `-w` on later runs so parameters are not silently reset.

Before T3 launch, run both checks in T3. Both must print no matches:

```bash
pgrep -af servo_command_bridge
ss -lunp | grep 14555
```

If either command prints a process or listener, abort the launch and paste back that output for a
cleanup handoff. Do not start another bridge or bind another UDP listener until the leftover owner
has been identified and stopped deliberately.

T1, start VRX alone. This command is also **UNTESTED on this workstation**:

```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
```

T2, start Rover SITL and explicitly route MAVLink to the bridge's UDP listener:

```bash
cd /home/ghostzero/ardupilot
./Tools/autotest/sim_vehicle.py -v Rover -f rover -w --out=udp:127.0.0.1:14555
```

Before starting T3, enter these commands at the T2 MAVProxy prompt and retain their complete
output:

```text
param show SERVO*_FUNCTION
param show SERVO*_MIN
param show SERVO*_TRIM
param show SERVO*_MAX
```

Do not require a reset `-f rover -w` instance to arrive with functions `73/74` on channels `3/1`.
Inspect the complete listing, then explicitly set or confirm one unique SITL output with
`FUNCTION=73` for left and one unique output with `FUNCTION=74` for right. Re-run the listing after
any `param set` and record the actual output channel numbers. If either function is absent,
duplicated, assigned ambiguously, or associated with a disabled/inert output, stop instead of
guessing. The selected left/right outputs must have identical MIN/TRIM/MAX triplets. If their
triplets differ, stop: the bridge exposes one shared PWM profile and cannot represent asymmetric
rails. If their shared triplet differs from the provisional `1100/1500/1900` starting profile,
replace `pwm_min`, `pwm_neutral`, and `pwm_max` in the T3 bridge command with that shared observed
triplet, then recheck the mapping math before proceeding. The `rc 3` and `rc 1` commands below are
RC inputs and do not prove that servo output channels `3/1` are correct.

T4-L and T4-R, start the observers before T3 and leave them running through bridge Ctrl+C:

```bash
# T4-L
ros2 topic echo /wamv/thrusters/left/thrust | \
  tee "${SITL_RUN_DIR}/sitl_bridge_left_thrust.log"
```

```bash
# T4-R
ros2 topic echo /wamv/thrusters/right/thrust | \
  tee "${SITL_RUN_DIR}/sitl_bridge_right_thrust.log"
```

T3, start the bridge with the inspected channel/PWM values explicit; `max_thrust` intentionally
uses the source-verified `800.0` default:

```bash
set -o pipefail
python3 tools/servo_command_bridge.py --ros-args \
  -p udp_recv_port:=14555 \
  -p left_servo_channel:=3 \
  -p right_servo_channel:=1 \
  -p pwm_min:=1100 \
  -p pwm_neutral:=1500 \
  -p pwm_max:=1900 \
  -p publish_sensors:=false \
  2>&1 | tee "${SITL_RUN_DIR}/sitl_servo_command_bridge.log"
BRIDGE_EXIT=${PIPESTATUS[0]}
printf 'BRIDGE_EXIT=%s\n' "$BRIDGE_EXIT" | \
  tee -a "${SITL_RUN_DIR}/sitl_servo_command_bridge.log"
```

The channel values `3/1` in this command are allowed only if the parameter evidence confirms that
exact left/right mapping. Otherwise replace them with the two uniquely confirmed SITL servo output
channels before running T3.

The source-verified bridge default `max_thrust=800.0` matches `SAFE_THRUST`. With the confirmed
`1100/1500/1900` profile, PWM `1700` and `1300` should therefore publish `+400.0 N` and `-400.0 N`
respectively. Keep `publish_sensors=false`: sensor publication is outside this test.

The first decoded-frame log must show raw left/right PWM, normalised values, and published newtons.
If no decoded frame appears, stop and diagnose the T2 `--out=udp:127.0.0.1:14555` route rather than
treating it as a VRX failure. Record the actual `SERVO_OUTPUT_RAW` arrival rate before proposing any
watchdog. At the T2 MAVProxy prompt, the following rate commands are **UNTESTED on this
workstation**; use `help messagerate` first and retain the raw status output:

```text
module load messagerate
help messagerate
messagerate status
```

After the mapping proof and before Ctrl+C, exercise the simulated command path deliberately. Enter
one command at a time at the T2 MAVProxy prompt, wait for the corresponding T4-L and T4-R samples,
then continue. Those topic samples are the per-step command evidence; the bridge's 5 s throttled log
cannot acknowledge a short phase reliably.

```text
mode MANUAL
arm throttle
rc 3 1700
rc 1 1700
rc 3 1300
rc 3 1700
```

The last command restores channel 3 to `1700` while channel 1 remains at `1700`. Hold both
non-neutral inputs, and confirm both T4 observers retain non-zero samples, through bridge Ctrl+C.
If either T4 observer reads `0.0`, reduce the steering offset, for example with `rc 1 1600`, until
both observers show non-zero thrust; only then issue Ctrl+C. This is a skid-mixer saturation
contingency, not a proven current output.

Before `arm throttle`, confirm this is the isolated SITL process and both observed thrust values are
zero. Abort immediately if arming affects anything outside SITL, a command changes the wrong
thruster, left/right are swapped, a sign is unexpected, conversion exceeds the configured limit,
or either observer stops updating. The abort sequence at the MAVProxy prompt is `rc 3 1500`, then
`rc 1 1500`, then `disarm`; allow at most 5 s for both observed thrust values to return to zero. If
either observer has stopped or both zeros are not visible within that bound, record a FAIL and use
the bounded failure cleanup below. Do not wait indefinitely or continue to the next exercise
command after an abort condition.

**Run + stop:** with the final confirmed non-neutral RC values that produced non-zero samples on
both T4 observers still held, press Ctrl+C in T3 first while both observers remain active. Teardown
starts a bounded observation window: allow at most 5 s for each thrust-topic record to show its held
non-zero sample followed immediately by a new `0.0` sample associated with bridge Ctrl+C. The topic
records decide teardown PASS. A merely final, startup, or pre-existing zero is not evidence of safe
teardown. A missing shutdown zero, no held non-zero sample on either topic, a stopped observer, or a
bridge exception fails the gate. A gap in the bridge's throttled decoded-frame logs is a fault only
when the T4 topic samples also stop during the exercise.

Record separately whether the WAM-V visibly stops or coasts after both topic zeros. Continued motion
after confirmed zero commands does not fail bridge teardown; it is VRX dynamics evidence for later
review, not proof that thrust remained commanded.

If an observer stops or either new zero is missing after 5 s, declare FAIL and perform bounded
cleanup instead of waiting for an unreachable PASS condition. At the T2 MAVProxy prompt, immediately
enter `rc 3 1500`, `rc 1 1500`, and `disarm`. If either topic may still hold non-zero thrust or its
state is unknown, press Ctrl+C in T1 next to stop VRX. Preserve the existing
`${SITL_RUN_DIR}/sitl_bridge_left_thrust.log` and
`${SITL_RUN_DIR}/sitl_bridge_right_thrust.log` files without truncating or overwriting them. Then
stop T3 if it is still running, followed by T4-L, T4-R, T2, and any remaining T1 process. This
cleanup limits the failed state; it does not convert the result to PASS.

After both Ctrl+C-associated zero samples are captured, enter the cleanup commands at the T2
MAVProxy prompt:

```text
rc 3 1500
rc 1 1500
disarm
```

Then press Ctrl+C in T4-L, T4-R, T2, and finally T1.

**After:** paste back the ArduPilot HEAD SHA, MAVProxy version, complete servo function/range
listings, confirmed left/right output mapping, bridge startup plus first/throttled conversion logs,
raw message-rate output, left/right topic samples covering the deliberate non-zero exercise and
bridge Ctrl+C zero, bridge exit status, and the operator observation of whether VRX stopped or
coasted. Include the exact absolute `${SITL_RUN_DIR}` value and preserve that complete directory as
the evidence bundle. Do not choose a watchdog interval or advance this track until that evidence is
reviewed.

## Block A - read-only incident separation (03/08/2026)

The two 24/07 failures are confirmed distinct, on structural grounds rather than message text.
Every helper line number in this section refers to the revisions the runs actually executed -
`3890564` for `175832` and `0306310` for `184228`, which share identical line numbering - and not to
the current file, whose numbering shifted when the Block B1 diagnostics were added.
Different die sites (`tools/pi_live_hailo_mavlink_dashboard.sh:443-444` rc-75 sentinel versus
`:613` content verdict), different phases (`stop_phase=live-window` versus `stop_phase=live-hold`),
and mutually exclusive branches: in live-hold the deadline is literally `0`, so `:607` cannot fire
and `:388-389` has no `return 75` - the path that ended `175832` is unreachable in `184228`.
Helper provenance confirms the split: `175832` logged `helper_sha256=3c1c9c27...` (commit `3890564`)
and `184228` logged `04ea4fe9...` (commit `0306310`). The only difference between those revisions is
the `FINAL_VERIFY_SECONDS` default.

**Run `live_dashboard_20260724_175832` - budget exhaustion.** The 78.9539 s figure is a bracket
between two echo sample stamps (`mavros_state.yaml` 1784909046.853379190 to `hailo_image.yaml`
1784909125.807284586); it bounds the enclosed work as a whole, not graph-query time alone. Fourteen
is the minimum *logical* query count - `ros2_graph_query_before` retries on non-zero rc, and
`require_publisher_count` and `reject_command_services` add their own attempt loops, so the real
process count may be higher. The derived 5.64 s is therefore an average, not a per-query ceiling.
`mavros_imu.yaml` holds no message, only the shell banner recording that the IMU echo was launched
and SIGKILLed, so that checkpoint names where the clock expired rather than a failing IMU.
`mavros_battery.yaml` and `mavros_rc.yaml` are pre-window stale, confirming the battery, RC and
final-verdict steps never ran. The 90 to 180 s change at `0306310` is a mitigation, not a
correctness fix; nothing about the query mechanism changed.
`tools/test_pi_live_hailo_mavlink_dashboard.sh:50` is a literal contract assertion on the constant's
spelling, not a behavioural regression test.

**Run `live_dashboard_20260724_184228` - unresolved.** At least one successful (rc 0) query reported
zero publishers on `/mavros/imu/data`. Because `last` is initialised once at `:569` and the
surrounding guard only updates it when the query succeeded, the preserved text pins the most recent
*successful* observation, not necessarily the final attempt. Whether an IMU writer actually existed
at that moment remains unknown: the hold never echoes that topic, and `mavros.log` carries no
periodic IMU record, so it can show neither publication nor loss. The earlier note that `mavros.log`
showed IMU healthy is withdrawn - the nearest line at 1784912120.953798782 proves only that the
process and its `global_position` callback were alive.

## Block B1 - diagnostic hardening (03/08/2026)

Scope was deliberately narrowed to observability. **No correctness claim is made, and no root cause
for `184228` is asserted.** The change is intended to capture evidence that would narrow the next
occurrence; it does not guarantee the next occurrence will be decidable.

Written test-first: a red observability case in
`tools/test_pi_live_hailo_mavlink_dashboard.sh` drives `require_mavros_source` with a stubbed query
that returns success while reporting `Publisher count: 0`. Against the previous helper its first
failure was the attempt-1 evidence assertion; the assertions ordered before it - terminal return
code, byte-exact verdict text, and the 3/3/2 query, sentinel and back-off counts - all held. Because
the suite stops at the first failure, the later raw-output and probe assertions were not reached on
that run, so the red result establishes those earlier contracts and the missing attempt-1 evidence
only. A companion case pins recovery after a transient zero reading so the retry path cannot regress
silently.

Helper changes, both confined to the failure path:

- `require_mavros_source` now emits attempt-indexed evidence for every attempt that did not verify,
  one prefixed record per line of raw query output, so a line-oriented log stays parseable.
- A dedicated `probe_mavros_source_dataplane` runs once immediately before the terminal verdict,
  with its own external `timeout --signal=KILL` bound, an explicit message type and an explicit QoS
  profile. It always returns 0 and its result is recorded but never consulted.

The terminal verdict text, at `:613` in the pre-Block-B1 helper, is byte-identical to before and is
asserted as such by the suite rather than by line number. Acceptance, exit status and the
foreign-publisher rejection are unchanged; that rejection exits earlier and never reaches either
addition. Both focused suites pass
(`bash tools/test_pi_live_hailo_mavlink_dashboard.sh`, `bash tools/test_live_dashboard_preflight.sh`).

Note for future edits: pin enforcement is uneven. `tools/test_live_dashboard_preflight.sh:38-43`
computes the real digest of `tools/live_dashboard_preflight.sh` and cross-checks the runbook
supervisor row, so supervisor drift does fail the suite. The helper pin has no such check: `:45`,
`:95` and `:119` only assert that the expected text appears, and the comparison against the real
helper happens during a live preflight. Helper pins must therefore be recomputed by hand after any
edit, and a green suite is not evidence that they are current.

Current pins after this change:

| File | Size | SHA-256 |
| --- | --- | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `63,625` bytes | `124d674f89efcee46a24d9bfa11b227324aa0dae292c666993df2a0a687fae98` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `72adfb125533e6b456583c563e5a47716b5514bbd649fa465a06ec5f142dbe2d` |

Twelve occurrences were updated: eight helper-hash, two cascading supervisor-hash, and the two wiki
size fields. The supervisor byte size is unchanged because the replacement digest is the same length.
The 24/07 pin rows remain as recorded on that date.

Not done in this block: no query-collapse refactor, no Pi command, no hardware contact, and no live
run. The choice between using the ROS 2 daemon and probing with a short subscription is still open
and is deliberately left until the new evidence exists.

## Block B1 correction (03/08/2026)

Review of the first B1 attempt found a deadline regression, corrected before acceptance.

The probe took a fixed five-second bound and ignored the caller's deadline. Because
`require_mavros_source` is also called with a finite deadline from `final_graph_verification`, the
probe could run past that deadline and let the terminal content verdict fire where deadline
exhaustion should have been reported instead, and it could extend the final-verification budget. A
no-ROS reproduction with a one-second remaining budget crossed the deadline.

The earlier statement that the probe "runs only on the terminal-failure path, so it cannot inflate
the final-verification budget" was wrong: that path is reachable from inside final verification.

`probe_mavros_source_dataplane` now takes the deadline, skips with a recorded reason when the budget
is already exhausted, and otherwise clamps its own hard bound to the remaining budget, matching the
clamp already used by `bounded_topic_echo`. With no deadline, as in live-hold, it keeps its own
five-second bound.

The first attempt also stubbed the probe in every test, so its real arguments were unverified. The
probe is now exercised directly with `timeout` stubbed instead, covering the clamped bound, the
explicit message type and QoS flags, one prefixed record per output line, neutrality after a SIGKILL
result, and the skip when the deadline is exhausted. A further case asserts that
`require_mavros_source` hands its deadline to the probe.

A second review round found two fail-closed seams, both reproduced before being fixed.

The first was attribution. Even with the clamp, the terminal verdict fired without rechecking the
deadline, so a probe that finished exactly at the deadline reported a content failure where deadline
exhaustion should have been reported. `require_mavros_source` now rechecks after the probe and
returns the deadline code instead, leaving the content verdict for the case where budget remains.

The second was interrupt handling. During the monitored hold, an operator Ctrl+C arriving while the
failure probe was running reached the hold-stop branch of the interrupt handler, which exits `0`.
A known source failure could therefore have been published as `PI_SUPERVISOR_EXIT status=0`. A
pending-failure flag is now raised for the window between the third failed attempt and the verdict,
and the handler defers on it exactly as it already defers during lifecycle transitions, so the
verdict is still recorded and the run exits non-zero. An operator stop with no failure pending keeps
its previous behaviour, which is asserted separately so the deferral cannot silently swallow a real
stop request.

A third review round found that the pending-failure latch was raised too late. It was set only after
the third attempt's evidence records and command-sentinel check had already run, leaving that
interval unprotected: an interrupt arriving there still saw no pending failure and exited the hold
cleanly, publishing a known failure as a clean stop. The latch is now raised as soon as the third
attempt is known not to have verified, ahead of any evidence or sentinel work, and it is cleared on
every deadline return so an expired budget is still reported as exhaustion.

The handler tests from the previous round set the flag by hand, so they asserted the handler's
contract but could not detect this ordering. Two integrated cases now drive the real interrupt
handler from inside the third attempt, once from its first evidence record and once from its
sentinel check, and require the non-zero content verdict in both. A third case pins the ordering
directly by observing the flag at each sentinel call and requiring it raised on the third attempt
only. That case detects a latch that is missing or raised too late; it would not detect one moved
earlier within the third attempt, ahead of the query itself. The source placement is correct, so
this is a coverage limitation rather than an open defect.

Known limitation, not expanded in this block: when a graph query fails outright rather than
returning a zero count, the durable record shows `<no query output>`. The query wrapper writes the
underlying error to standard error while the caller captures standard output only, so that text does
not reach `supervisor.log`. This does not affect capture of the successful-query, zero-count case
that motivated the block, but it means a hard query failure is recorded by its return code alone.

## Non-goals

- No arming a real vehicle, no real motor command, no dashboard write path, and no bypass of
  `LIVE_MAVLINK_VIEW_ONLY` or the Pi safety monitor without the separate bench-safe gate.
- No low-level protocol guessing; the FCU command path must be confirmed, not assumed.
- No new window measurement instrumentation.

## Next step

Start Task 1 (graph-query hardening): read the 24/07 logs, pick the smallest robust change,
re-pin and keep both test suites green, and verify with a full-stack run reaching a clean
`status=0`. Tasks 2 and 3 only if time allows and only under their gates.

## Next step update (03/08/2026)

Superseding the entry above, which was written before the day started. Blocks A and B1 are
complete. The helper records attempt-indexed evidence and one bounded data-plane probe on the
`require_mavros_source` failure path, both suites pass, and all twelve pin occurrences are current.

Next is a full-stack run reaching a clean `PI_SUPERVISOR_EXIT status=0` after an operator Ctrl+C,
which also deploys the re-pinned helper to the Pi. That run deploys the build but does not by itself
answer the still-open question in `184228`. The discriminator only becomes available if the
zero-publisher condition recurs: a clean run proves the diagnostics do not disturb a healthy stack,
and nothing more. On a recurrence the records carry the raw query body per attempt and whether a
bounded post-query probe captured a message on `/mavros/imu/data`. Whether that settles the question
still depends on what the probe returns, so the daemon-versus-subscription-probe choice stays open
until such a recurrence has been captured. Tasks 2 and 3 remain gated as written above.

## Block C - user-run live recurrence and acceptance (03/08/2026)

Block C ran against landed commit `bfaf969`. The Pi's initial helper copy failed the expected
checksum, so the workstation copy was rechecked and transferred once. The Pi then verified the
current helper SHA-256
`124d674f89efcee46a24d9bfa11b227324aa0dae292c666993df2a0a687fae98` before launch.
The preserved evidence is:

- Pi copy: `/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260803_114802`
- workstation source: `/home/ghostzero/Desktop/live_dashboard_workstation_20260803_114713`

The copied Pi files are present and readable. No source-versus-copy checksum comparison was
captured, so the copy is not claimed as independently checksum-matched.

The automated lifecycle passed. The Pi reached `MAVROS_STATE=PASS connected=true armed=false`,
`MAVROS_TELEMETRY=PASS`, and `PI_SOURCE_STACK_READY=PASS`. The workstation reached
`PI_DATA_ARRIVED=PASS topics=6 elapsed=285s` and `W5_RATE_PROBES=PASS`. Its six ten-second samples
were:

| Topic | Messages | Mean rate |
| --- | ---: | ---: |
| `/hailo/overlay/image_raw` | `73` | `7.40 Hz` |
| `/mavros/state` | `10` | `1.00 Hz` |
| `/mavros/global_position/raw/fix` | `10` | `1.00 Hz` |
| `/mavros/imu/data` | `10` | `1.00 Hz` |
| `/mavros/battery` | `10` | `1.01 Hz` |
| `/mavros/rc/in` | `10` | `0.96 Hz` |

The Pi reported:

```text
PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=125s elapsed=245s peak=67C
```

It then entered the monitored hold. The operator observed a good live annotated camera and five
good MAVROS badges; write controls were neither visible nor tested. After the 12:00:53 browser
reload, `web_video_server.log` records one stream request at
`1785751253.754448` and its removal at `1785751969.655791`, with no intervening second request.
The ROS bridge likewise held one client subscribed to all five MAVROS topics until
`1785751968.844735`.

The independent watchdog peak was `69400` mC; the operator console recorded `58950` mC before
launch and `57850` mC after teardown. No thermal abort occurred. The command sentinel remained
quiet and the FCU remained observed-disarmed.

Supervisor shutdown ordering passed: the operator signalled P1 first at `1785751970.855767`, and
the Pi produced:

```text
TEARDOWN=PASS
PI_SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=live-hold failed_phase=none cleanup_rc=0
```

W1 was signalled later at `1785752042.275249` and produced:

```text
WORKSTATION_TEARDOWN=PASS
SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=supervision failed_phase=none cleanup_rc=0
```

The browser stream ended about 1.2 s before the P1 signal, so the requested browser-last close
order was not preserved. This bounded ordering deviation does not change the captured query
evidence or either supervisor's status, but strict browser-last acceptance is not claimed.

### Captured graph-query recurrence

Eleven non-verifying evidence headers occurred across eight source-check episodes. Every query had
`query_rc=0`: these were successful commands returning incomplete content, not command failures or
timeouts. Successful source checks are intentionally silent in the helper.

| Phase and time | Topic | Non-verifying observations | Bounded outcome |
| --- | --- | --- | --- |
| live-window `11:53:47.093` | `/mavros/state` | attempt 1: count `0` | The finite window may have recovered or returned its deadline code; final verification later accepted the source. |
| live-hold `12:00:00.287` | `/mavros/imu/data` | attempt 1: count `0` | Silent attempt 2 accepted before the next phase record. |
| live-hold `12:03:44.464` | `/mavros/state` | attempt 1: count `0`; attempt 2: count `1`, identity unknown | Silent attempt 3 accepted. |
| live-hold `12:04:08.610` | `/mavros/imu/data` | attempts 1 and 2: count `0` | Silent attempt 3 accepted. |
| live-hold `12:04:27.045` | `/mavros/battery` | attempt 1: count `0` | Silent attempt 2 accepted. |
| live-hold `12:08:17.749` | `/mavros/battery` | attempt 1: count `0`; attempt 2: count `1`, identity unknown | Silent attempt 3 accepted. |
| live-hold `12:10:02.828` | `/mavros/global_position/raw/fix` | attempt 1: count `0` | Silent attempt 2 accepted. |
| live-hold `12:11:44.555` | `/mavros/global_position/raw/fix` | attempt 1: count `0` | Silent attempt 2 accepted. |

The zero-count bodies still contained the topic type and one or more subscriptions. The state and
battery sequences then exposed a publisher endpoint with `_NODE_NAME_UNKNOWN_` and
`_NODE_NAMESPACE_UNKNOWN_` before the following attempt accepted its MAVROS identity. Those
partially identified endpoints carried the same publisher GIDs that W5 had recorded for the fully
identified `/mavros/sys` publishers. The helper launches a fresh
`ros2 topic info --verbose --no-daemon --spin-time 2` process for every attempt, so this run
confirms transiently incomplete per-process graph snapshots as the proximate query defect.

The evidence disfavors a persistent or MAVROS-wide source loss in this run: all seven live-hold
episodes recovered within the existing three attempts, the MAVROS process group stayed alive, the
ROS bridge subscriptions remained active, and the operator observed live badges. It does not prove
publisher continuity at each exact zero-count instant. W5's direct IMU rate ended before the two
hold-time IMU readings, the preserved direct IMU sample is from `11:55:58`, and no hold-time direct
IMU sample was taken.

No `MAVROS_SOURCE_PROBE` record exists because no live-hold call exhausted all three attempts.
Therefore the terminal probe remains tested but not live-exercised. The evidence does not isolate
the lower DDS, RMW, Wi-Fi, or interface-level trigger. The historical `184228` failure is now
strongly consistent with this confirmed mechanism, but the run cannot retroactively establish that
its writer existed at the exact failure instant.

The separate `175832` timing issue also remains bounded. This run's final verification took
`125 s`, which passed the current `180 s` limit but would exceed the former `90 s` budget. That
corroborates the budget insufficiency without isolating any per-query duration or lower timing
fault; timeout widening remains mitigation, not a correctness fix.

No arming, motor command, dashboard write path, safety bypass, Task 2 window-sizing change, or
Task 3 Pi-to-FCU work occurred.

**Next step:** Task 1 remains active under a separate code-edit gate. Use the captured
count-zero to identity-unknown to accepted sequence to choose and test the smallest bounded query
mechanism that preserves MAVROS publisher identity and fail-closed behaviour. More retries or a
wider timeout alone are not a correctness fix. Tasks 2 and 3 remain parked, and no second live run
is justified before that decision and its focused regression test.
