# Friday 28/08/2026 - Test B direct paired-zero retry

**PRE-DIARY - SOURCE REPAIR COMPLETED OFFLINE ON 27/08/2026. TEST B IS NOT
FORMALLY ACCEPTED. NO LIVE OR HARDWARE APPROVAL CARRIES INTO THIS DAY.**

## Read first

1. `working_diary/2026-08-27_thursday_herelink_to_vrx_test_b.md`
2. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`
3. `tools/pi_live_hailo_mavlink_dashboard.sh`
4. the focused Pi lifecycle and W1 preflight tests
5. the retained second-retry evidence:

   ```text
   /home/ghostzero/Desktop/pi_run_evidence/test_b_unbounded_failed_20260827_200821
   /home/ghostzero/Desktop/live_dashboard_workstation_20260827_200652
   /home/ghostzero/Desktop/fcu_to_vrx_workstation_20260827_200727
   ```

## Carried evidence

The first armed attempt proved the functional Herelink-to-real-FCU-to-VRX
motion chain for one observed interval. Machine evidence captured
`SERVO3/SERVO1=2200/800`, mapped `800.0/0.0 N` and `2.47946 m` of VRX motion;
the operator also observed the boat move. No video was retained. Formal Test B
acceptance remains open because the armed deadline stopped the source window
before final connected/disarmed, neutral and hardware-safe evidence was
captured.

The paired-zero retry then proved that the armed and outer-runtime deadlines
were disabled, reached the safe disarmed baseline and never armed. It failed
when three graph views reported zero publishers for
`/mavros/global_position/raw/fix`, even though NavSatFix data had been retained
and W1 had just measured the topic at `4.00 Hz`. P1 teardown passed; W1 and W2
then failed on downstream stale streams and stopped their children.

`RC_OVERRIDE_TIME=0.5` remains the last verified live value. Its rollback to
`3.0` remains mandatory after this campaign is accepted or abandoned, or
before any different operation.

## Test B selector provenance

The retained T0b artifact contains two intentionally different rail families.
For Test B, take left/right channels only from `resolved.left_servo=3` and
`resolved.right_servo=1`, and take output calibration only from
`servo_rails`: left function `73`, right function `74`, with both rails
`800/800/2200`. The `rc_rails` entries are RC-input calibration
`1102/1515/1927`; they are not valid servo-output selectors or neutral values.

Use the same `SERVO3`/`SERVO1` and `800/800/2200` literals in W1 and W2, then
confirm W2 reports `mapping=3/1 rails=800/800/2200` before arming. Disarmed
servo output is already measured rather than inferred: both the retained
disarmed-measurement run and paired-zero retry captured `/mavros/rc/out` with
`SERVO1=800` and `SERVO3=800`, and the retry reached
`ARMED_OBSERVATION_BASELINE=PASS`. No extra disarmed-measurement run is
scheduled.

## Repair carried into the day

The existing bounded six-topic `rclpy` source view is now the default. It
accumulates discovery before applying the unchanged exact publisher-count and
`/mavros` identity verdict. The legacy one-process-per-query path remains only
as explicit `LIVE_MAVROS_SOURCE_BATCH=0`. W1 also reports each governed child
exit once while preserving failure hold. The complete offline EOD verification
passed: Pi lifecycle, W1 `cases=22`, real-FCU `cases=34`, SITL `cases=41`,
FCU-to-VRX `shell_cases=23 python_tests=35`, Python tools `123`, Node `80/80`,
the four-file bundle and shell syntax.

This repair has no live result yet. Transfer and verify the current Pi helper
through the exact checksum block emitted by W1; do not add a separate trial or
diagnostic run.

## Morning phase-freshness correction

The Friday audit found one cache edge before transfer. If a later source topic
needed a fresh six-topic generation, its successful retry consumed only that
topic and could leave an already-checked earlier-topic block pending for the
next verification phase. A red focused case reproduced two phase-one probe
runs followed by reuse of the second run's state block in phase two.

The consumer now discards entries through the requested topic whenever it has
created a fresh generation. The same case requires no pending entry at the
phase boundary and a third probe for the next phase's state check. W1 also
places `LIVE_MAVROS_SOURCE_BATCH=1` and
`LIVE_FINAL_VERIFY_SECONDS=180` explicitly in the emitted P1 block, preventing
stale Pi-terminal exports from selecting the old path or changing that budget.
The focused Pi and W1 suites pass. These corrected bytes remain offline-only
and require the updated transfer below before the direct retry.

The complete Friday offline verification also passes on these bytes: Pi
lifecycle and telemetry fanout, W1 `cases=22`, real-FCU `cases=34`, SITL
`cases=41`, FCU-to-VRX `shell_cases=23 python_tests=35`, Python tools `123`,
Node `80/80`, the four-file bundle, shell syntax and whitespace checks. No Pi,
FCU, Gazebo, SITL, MAVProxy, MAVROS or dashboard runtime was started by this
verification.

## Pi transfer reminder

**TRANSFER REQUIRED BEFORE P1:** the current Friday repair changes the Pi
dashboard helper. W1 and W2 remain workstation-side; the current required Pi
transfer is:

```text
tools/pi_live_hailo_mavlink_dashboard.sh
-> /home/imt-aqua-drone/Desktop/pi_live_hailo_mavlink_dashboard.sh
sha256=0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9
```

From a new workstation transfer terminal:

```bash
(
  set -euo pipefail
  cd /home/ghostzero/seal_ws/src/uvautoboat
  printf '%s  %s\n' \
    '0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9' \
    tools/pi_live_hailo_mavlink_dashboard.sh | sha256sum -c -
  scp tools/pi_live_hailo_mavlink_dashboard.sh \
    imt-aqua-drone@10.120.2.249:/home/imt-aqua-drone/Desktop/pi_live_hailo_mavlink_dashboard.sh
)
```

Then, in the existing Remmina Pi terminal, verify the transferred bytes and
make the helper executable:

```bash
(
  set -euo pipefail
  PI_HELPER=/home/imt-aqua-drone/Desktop/pi_live_hailo_mavlink_dashboard.sh
  printf '%s  %s\n' \
    '0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9' \
    "$PI_HELPER" | sha256sum -c -
  chmod +x "$PI_HELPER"
  test -x "$PI_HELPER"
  echo "PI_HELPER_TRANSFER=PASS file=$PI_HELPER"
)
```

Do not continue to P1 unless both checksum commands print `OK` and the final
marker prints. If any Pi-owned source changes before the run, update this
transfer list and its hashes first; never reuse this reminder as a stale pin.

## Direct operator retry

Start the same live pipeline directly:

1. W1: `tools/live_dashboard_preflight.sh run` with paired-zero armed mode,
   fanout, the retained mapping/rails and resizable Pi window.
2. W2: `tools/fcu_to_vrx_workstation.sh run` with correlated observation.
3. P1: paste only the exact compound command emitted by W1.

The user explicitly supersedes a new full current-revision SITL acceptance for
this 28/08/2026 Test B retry. The acceptance remains stale; this decision does
not reclassify it as current, and no separate SITL run is scheduled. The scope
is supported by the reviewed dependency boundary:

1. `tools/real_fcu_rc_command_bridge.py`, the SITL runner, its operator and
   evidence tools, and the dashboard application are unchanged since the
   passing `147efe0` run.
2. `tools/live_dashboard_preflight.sh` changed afterwards, but its SITL entry
   and shared `start_child` function did not. The SITL runner uses its own
   `sitl_monitor_children_once`; the later one-shot child-reporting change was
   made in the separate `monitor_children_once` path. The `41`-case SITL suite
   passes on the current source, but it is not represented as an integrated
   acceptance run.
3. Test B uses the outbound FCU-to-VRX path through
   `tools/fcu_to_vrx_workstation.sh` and `tools/servo_command_bridge.py`; it
   does not invoke the guarded command-ingress bridge above.

This supersession applies only to that SITL precondition for this retry. It
does not authorize Test B, carry hardware approval into 28/08/2026, waive any
W1, W2 or P1 fail-closed gate, or carry forward to a later retry or revision.
Apart from that, there is no separate T0b probe, disarmed-measurement run or
standalone Pi preflight before this retry. Do not bypass the checks embedded in
W1, W2 or P1. Before any arm, require the fresh physical declaration, explicit
Test B approval, `ARMED_OBSERVATION_BASELINE=PASS`, W1
`FCU_TO_VRX_PI_OBSERVER=READY`, W1 `W5_RATE_PROBES=PASS` and W2
`FCU_TO_VRX_WORKSTATION_READY=PASS`.

After motion capture, return sticks to neutral, disarm and restore hardware
safety ON. Wait for `ARMED_OBSERVATION=PASS`, `PI_SOURCE_HOLD=ACTIVE` and
`PI_SOURCE_HOLD_MODE=completed-armed` before stopping W2, then W1, then P1.
