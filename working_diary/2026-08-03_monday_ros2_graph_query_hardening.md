# Monday 03/08/2026 - ros2 --no-daemon graph-query hardening (+ window size and Pi-FCU if time)

> **START HERE - carried-forward known issue.** The live-dashboard supervisor
> (`tools/pi_live_hailo_mavlink_dashboard.sh`) drives its graph and source checks with
> `ros2 ... --no-daemon --spin-time 2` queries. These are slow and intermittently misreport,
> and they caused two separate flaky failures on 24/07/2026: (1) the end-of-window final
> verification cumulatively overran its budget (worked around by raising `FINAL_VERIFY_SECONDS`
> 90 -> 180 s in `0306310`); (2) the live-hold `require_mavros_source` publisher-count check read
> a FALSE `publisher count 0` on `/mavros/imu/data` while MAVROS/IMU were provably healthy,
> self-stopping the hold with `status=1`. Both share one root. Hardening these queries is the main
> task for this day.

## Status

Prepared at EOD 24/07/2026. Vacation 25/07 - 02/08/2026 (no work); resume Monday 03/08/2026. At
prep, the window/telemetry stack is trimmed and verified across three full-stack runs (24/07),
all committed and pushed to `origin/main`. The dashboard-to-real-motor track is parked on a
hardware blocker (receive-only Pi-to-FCU serial link). No decisions were taken during the gap.

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

- **Graph-query root cause.** `require_mavros_source`, `final_graph_verification`, and
  `bounded_topic_echo` in `tools/pi_live_hailo_mavlink_dashboard.sh` all go through
  `ros2_graph_query` / `ros2_graph_query_before`, i.e. `ros2 ... --no-daemon --spin-time 2`. 24/07
  evidence: run `live_dashboard_20260724_175832` failed final-verify at ~90 s during the IMU
  sample; run `live_dashboard_20260724_184228` recorded `final_verification=116s` (passed under
  the new 180 s budget) then hit the hold-monitor false `publisher count 0` on `/mavros/imu/data`
  while mavros.log showed IMU healthy. Logs copied under `~/Desktop/test_logs_folder/`.
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
re-pins the checksum across the preflight constant, both preflight-test literals, and the wiki
manifest, and must keep both suites green (`bash tools/test_pi_live_hailo_mavlink_dashboard.sh`,
`bash tools/test_live_dashboard_preflight.sh`). Verify with a fresh full-stack run that reaches a
clean `PI_SUPERVISOR_EXIT status=0` after an operator Ctrl+C.

### Task 2 - window size (if time, only with a clean fix)

Research-led only; add no instrumentation. Fold in any supervisor reply.

### Task 3 - Pi-to-FCU (if time)

At the boat: check the Pi TXD -> Cube SERIAL1 RX wire and/or set `BRD_SER1_RTSCTS=0`, then re-run
`tx_probe.py` - success = a `FRAME_CLASS` value read back from the FCU. Only after the link is
bidirectional does the motor track resume, still behind the propellers-removed bench gate.

## Non-goals

- No arming a real vehicle, no real motor command, no dashboard write path, and no bypass of
  `LIVE_MAVLINK_VIEW_ONLY` or the Pi safety monitor without the separate bench-safe gate.
- No low-level protocol guessing; the FCU command path must be confirmed, not assumed.
- No new window measurement instrumentation.

## Next step

Start Task 1 (graph-query hardening): read the 24/07 logs, pick the smallest robust change,
re-pin and keep both test suites green, and verify with a full-stack run reaching a clean
`status=0`. Tasks 2 and 3 only if time allows and only under their gates.
