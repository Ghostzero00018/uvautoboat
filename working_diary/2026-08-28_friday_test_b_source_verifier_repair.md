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

## Direct operator retry

Start the same live pipeline directly:

1. W1: `tools/live_dashboard_preflight.sh run` with paired-zero armed mode,
   fanout, the retained mapping/rails and resizable Pi window.
2. W2: `tools/fcu_to_vrx_workstation.sh run` with correlated observation.
3. P1: paste only the exact compound command emitted by W1.

There is no separate SITL run, T0b probe, disarmed-measurement run or standalone
Pi preflight before this retry. Do not bypass the checks already embedded in
W1, W2 or P1. Before any arm, require the fresh physical declaration, explicit
Test B approval, `ARMED_OBSERVATION_BASELINE=PASS`, W1
`FCU_TO_VRX_PI_OBSERVER=READY`, W1 `W5_RATE_PROBES=PASS` and W2
`FCU_TO_VRX_WORKSTATION_READY=PASS`.

After motion capture, return sticks to neutral, disarm and restore hardware
safety ON. Wait for `ARMED_OBSERVATION=PASS`, `PI_SOURCE_HOLD=ACTIVE` and
`PI_SOURCE_HOLD_MODE=completed-armed` before stopping W2, then W1, then P1.
