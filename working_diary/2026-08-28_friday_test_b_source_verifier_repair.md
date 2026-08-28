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

## Friday pre-arm arrival failure and focused repair

The separately approved attempt started from clean revision `a23fc6d`. The Pi
helper checksum
`0d3f6d1b72c473eeac8a169eaa045f24930ba7ed31fe4f7485d47616704f6ad9`
verified on both hosts. Retained evidence is:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260828_151158
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260828_151242
P1=/home/ghostzero/Desktop/pi_run_evidence/test_b_friday_failed_20260828_151345
```

P1 reached `PI_SOURCE_STACK_READY=PASS` and the connected/disarmed, neutral,
hardware-safe `ARMED_OBSERVATION_BASELINE=PASS`. W2 independently reached
`FCU_TO_VRX_WORKSTATION_READY=PASS ... streams=4`. W1 remained in its
publisher-arrival phase, created neither `arrival_*.log` nor its Pi evidence
observer, emitted no `PI_DATA_ARRIVED=PASS`, and reported its configured
`600 s` timeout after `244.968` epoch seconds between its own phase-entry and
failure records. The cause of that timing discrepancy is not established.
There was no arm, stick movement, correlation adjudication or new Test B
acceptance. The Pi safety monitor remained at `ARMED_OBSERVATION_PHASE=READY`.
P1 and W1 reported passing teardown with `cleanup_rc=0`; W2 stopped its bridge,
observer and VRX children with `cleanup_rc=0`.

The old W1 precheck required seven separate daemonless graph queries to all
succeed in one scan and discarded earlier topic sightings whenever a later
query was incomplete. The focused repair now retains each expected topic once
observed and re-queries only unresolved topics. Its deadline, remaining budget
and elapsed result use `/proc/uptime` monotonic time. A timeout records the
configured budget, monotonic elapsed time and exact unresolved topic names.
The existing Pi-observer READY gate and all seven compatible-QoS message probes
remain mandatory after discovery, so a disappeared source still fails closed.

Red/green coverage reproduces staggered publisher visibility, a raw `SECONDS`
discontinuity and exact missing-topic diagnostics. The focused W1 suite passes
`cases=25`. This workstation-only repair does not change the Pi helper or its
transfer checksum, has not been exercised live, and does not accept Test B. A
new live attempt still requires its own physical declaration and approval.

## Live retry on the repaired W1 arrival gate

The separately approved retry started from clean, pushed revision `6beb603`.
The operator confirmed the fresh physical state and authorised P1 and Test B
for this attempt. The active run directories are:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260828_155040
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260828_155105
P1=/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260828_155345
```

P1 reached `PI_SOURCE_STACK_READY=PASS` and the connected/disarmed, neutral,
hardware-safe `ARMED_OBSERVATION_BASELINE=PASS`. W2 reached
`FCU_TO_VRX_WORKSTATION_READY=PASS` with mapping `3/1`, rails
`800/800/2200`, `observer=ready` and all four streams. W1 started its armed
Pi evidence observer, reached `FCU_TO_VRX_PI_OBSERVER=READY`, completed its
repaired arrival path and emitted `W5_RATE_PROBES=PASS topics=7`. Its retained
rates were Hailo image `7.48 Hz`, MAVROS state `1.00 Hz`, GPS `4.02 Hz`, IMU
`4.01 Hz`, battery `4.01 Hz`, RC input `3.99 Hz` and RC output `4.01 Hz`.

The operator then reported that moving the Herelink sticks caused the boat to
move in VRX. At the time of that report P1, W2 and W1 were all still running;
no terminal or governed child had exited and no fail-closed marker had been
reported. This is the first live success of the repaired cumulative W1 arrival
gate and a direct operator observation of Herelink-to-VRX motion on `6beb603`.

This entry is an in-progress observation, not Test B acceptance. Sticks must
still return to neutral, the FCU must be disarmed, hardware safety must be
restored ON, and P1 must emit `ARMED_OBSERVATION=PASS`,
`PI_SOURCE_WINDOW=COMPLETE`, `PI_SOURCE_HOLD=ACTIVE` and
`PI_SOURCE_HOLD_MODE=completed-armed`. W2, W1 and P1 must then stop in that
order with passing teardown, the Pi directory must be copied back, and the two
recorder streams must pass explicit-threshold adjudication.

### Completion status and external interruption

The retained workstation evidence confirms the functional interval. W1
recorded the FCU transition from disarmed to armed, both full asymmetric output
pairs (`SERVO3/SERVO1=2200/800` and `800/2200`), and a later return to neutral
`800/800`. W2 recorded the same asymmetric pairs at the bridge, both mapped
thrust streams reached `800.0 N`, and the VRX pose moved `116.751869 m` between
the first and last retained samples. This supports the operator's direct report
that Herelink stick input moved the boat in VRX while all three stacks were
healthy.

The operator reports that the professor subsequently cut FCU power after the
functional motion observation. This is retained as external-interruption
context, not as a machine-established root cause. P1's literal failure was
`STOP: thermal-watchdog leader exited`; its last reported peak was `69 C`, so
the available terminal output does not establish an overtemperature abort or
why that watchdog process exited. P1 ended `status=1 cleanup_rc=1` without
`ARMED_OBSERVATION=PASS`, `PI_SOURCE_WINDOW=COMPLETE` or
`PI_SOURCE_HOLD=ACTIVE`.

Loss of the Pi streams was followed by the expected fail-closed cascade. W1's
Pi observer recorded `stale_state`, W2's VRX observer recorded
`stale_left_thrust`, and both supervisors exited `status=1`. W1 nevertheless
reported `WORKSTATION_TEARDOWN=PASS cleanup_rc=0`; W2 stopped its bridge,
observer and VRX children with `cleanup_rc=0`. The final retained Pi state was
still armed, although output had returned to `800/800` and hardware safety was
reported ON; no connected/disarmed final-state transition was captured.

Explicit-threshold adjudication of the two workstation recorder files returns
`FCU_TO_VRX_EVIDENCE=FAIL reason=pi observer recorded an abort`. Classification:
**FUNCTIONAL MOTION DEMONSTRATED; RUN EXTERNALLY INTERRUPTED / NOT FORMALLY
ACCEPTED.** The repaired W1 arrival gate is live-proven. Formal Test B
acceptance is not claimed because final connected/disarmed, neutral and
hardware-safe evidence, completed armed-window markers, normal W2-W1-P1
shutdown and a passing lifecycle status were not obtained. The Pi directory
still requires copy-back before the watchdog and cleanup failures can be
examined fully.

### Pi copy-back correction and evidence-qualified result

The preceding copy-back statement is superseded. The P1 directory was copied
to and inspected at:

```text
/home/ghostzero/Desktop/pi_run_evidence/test_b_functional_interrupted_20260828_155345
```

The copied P1 evidence refines the terminal-only account. Its exact run-wide
thermal peak is `70500 mC` (`70.5 C`), below the `80000 mC` abort threshold.
`thermal_watchdog.log` is empty and no thermal-abort record exists, so this was
not an overtemperature abort. The Hailo log instead records `/dev/video4`
disappearing with `errno=19 (No such device)`, followed by successful Hailo
process completion after `43211` frames. The retained watchdog exits normally
when its watched Hailo process group disappears; the supervisor then recorded
`STOP: thermal-watchdog leader exited`.

The independent safety monitor recorded
`ARMED_OBSERVATION_PHASE=READY -> ARMED -> ABORT` and
`REQUIRED_TOPIC_STALE_ABORT topic=/mavros/state`. Its abort file contains
`reason=REQUIRED_TOPIC_STALE topic=/mavros/state`; this is a stale-state safety
fault, not dashboard command publication. The operator-reported FCU power cut
is consistent with the subsequent device and stream losses, but the retained
artifacts do not establish which physical action caused either loss.

P1 stopped MAVROS, MAVProxy and telemetry fanout, then reported
`TEARDOWN=FAIL cleanup_rc=1`. The helper unconditionally sets that result when
the abort file is non-empty. The stale-state record is therefore sufficient to
explain the nonzero cleanup result, although the aggregate marker cannot prove
that it was the only contributor; it is not independent evidence that a child,
port or device owner survived.

The functional interval passes each pre-final-state correlation threshold. The
first asymmetric Pi output `800/1033` matched the bridge in `4.124019 ms`,
mapped to `0.0/133.142857 N`, reached the two thrust topics in
`1.038506/1.126658 ms`, and produced `3.480079 m` of motion inside `10 s`.
Neutral return and zero thrust were retained. The longer
`116.751869 m` value above is first-to-last retained XY displacement, not a
controlled-path-distance claim.

The final retained FCU state remained `connected=true`, `armed=true` and
`mode=MANUAL`, while mapped output had returned to `800/800` and the latest
system-status evidence still reported hardware safety ON. No connected/disarmed
final transition or completed P1 window/hold marker was retained. Canonical
adjudication fails on the Pi observer abort before it can issue an acceptance
verdict. Final classification remains: **FUNCTIONAL MOTION DEMONSTRATED; RUN
EXTERNALLY INTERRUPTED / NOT FORMALLY ACCEPTED.** No post-run
`RC_OVERRIDE_TIME` readback or rollback snapshot was retained with these runs;
the documented restoration from `0.5` to `3.0` remains open before a different
operation.

## Enhanced Test A props-fitted observation and parameter restoration

### Evidence classification

Later on 28/08/2026, the operator ran the real-FCU dashboard path again with a
fresh `986`-parameter snapshot:

```text
snapshot=/home/imt-aqua-drone/Desktop/real_fcu_params_20260828_test_a_live.parm
sha256=61406eee10c253daabfef4462ce0b3661be30b599bd7736909c5bff4e4b4943d
revision=70c4d8bfc4827bcf89af41b711700be713139f5d
workstation=/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260828_175310
pi-copy=/home/ghostzero/Desktop/pi_run_evidence/test_a_props_fitted_observation_20260828_175321
```

The snapshot retained `RC_OVERRIDE_TIME=0.5`, resolved steering/throttle as
`RC1`/`RC3`, left output as `SERVO3` function `73`, right output as `SERVO1`
function `74`, both servo rails as `800/800/2200`, and `ARMING_CHECK=0`. The
last value is retained safety context, not an explanation for the observed
motor behavior. Both helpers reached their READY markers. Their retained final
states were connected and disarmed; the stop marker was exchanged, all
supervised children stopped, and both helpers exited `status=0 cleanup_rc=0`.

The operator subsequently corrected the earlier physical declaration: the
propellers were fitted and propulsion was available during the active interval.
That later report supersedes the propellers-removed and propulsion-isolated
parts of the earlier declaration for this interval. It also means the launch
assertion `REAL_FCU_PROPELLERS_REMOVED=1` was factually inaccurate during the
active interval. The helpers reported the nominal
`tier=T2b authority=demand-enabled` software markers and clean teardown, but
the run did not satisfy T2b's propellers-removed physical gate. No separate
T3a approval, dedicated mechanical guarding or exclusion-zone evidence was
established. Classification: **ENHANCED TEST A - PROPS-FITTED FUNCTIONAL
OBSERVATION; NOT T2B ACCEPTANCE, T3A ACCEPTANCE OR APPROVAL FOR ROUTINE OR
REPEATED PROPS-FITTED OPERATION.**

`REAL_FCU_PROPELLERS_REMOVED`, `REAL_FCU_HULL_RESTRAINED` and
`REAL_FCU_PROPULSION_ISOLATED` are operator attestations; the helper cannot
observe those physical conditions. Their acceptance by the software is not
physical proof and cannot replace the separate T3a approval, guarding and
exclusion-zone requirements for props-fitted work.

### Command observations and retained limits

The operator reports these dashboard observations:

- steering `0.00`, throttle `0.12`: neither propeller moved;
- steering `+0.20` or `-0.20`: neither propeller moved;
- steering `0.05`, throttle `0.04`: neither propeller moved; and
- other steering-heavy requests produced one-sided propeller rotation.

The retained artifacts contain only neutral snapshots: requested demand
`0.00/0.00`, RC input `1515/1515` and mapped output `800/800`, followed by the
final connected/disarmed state. They do not retain the active slider values or
the corresponding live RC/output PWM. The observations above are therefore
operator evidence, not a machine-correlated demand-to-output record, and they
do not establish an ESC start threshold or explain the one-sided rotation.

One source defect does explain the exact steering endpoints. The dashboard
exposes `-0.20` and `+0.20`, but transports them through `Joy.axes` as
`float32`. Those endpoints arrive as approximately `-0.20000000298` and
`+0.20000000298`, outside the bridge's exact inclusive `[-0.20, +0.20]`
comparison, and are rejected as `COMMAND_OUT_OF_BOUNDS`. The `0.12`, `0.05`
and `0.04` values remain inside their limits after float32 conversion. No code
change was made; the endpoint contract needs a focused red/green repair before
either endpoint is relied on again.

### Rollback and safe closeout

After the run, the separately approved MAVProxy rollback captured a live
readback of `RC_OVERRIDE_TIME=0.5`, set it to `3.0`, fetched all `986`
parameters again, confirmed the live `3.0` readback and saved a new snapshot.
The copied evidence is:

```text
directory=/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828
snapshot=real_fcu_params_20260828_rc_override_rollback_3p0.parm
sha256=a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b
transcript=real_fcu_rc_override_rollback_20260828.log
```

The copied snapshot has `986` parameters, exactly one
`RC_OVERRIDE_TIME=3.000000`, and matches its retained SHA-256. The serial owner
check then returned free. This supersedes the earlier same-day rollback-open
statements: the temporary `0.5` setting is no longer live. Any later
demand-enabled Test A requires a separately approved change back to `0.5`, a
fresh readback and a newly pinned snapshot.

The final operator declaration was: FCU disarmed; hardware safety ON;
propulsion battery disconnected; ESCs unpowered; propellers fully stopped;
Herelink sticks neutral; Pi runtime stack down; workstation Test-A stack down.
It does not state that the FCU, Pi or Herelink is powered off.

### Next steps

1. Before another demand-enabled run, repair and red/green test the float32
   steering endpoint contract; do not infer an ESC threshold from this run.
2. Keep formal Test B acceptance open; the functional VRX motion record remains
   interrupted and lacks its required passing final lifecycle/adjudication.
3. If a future Test A is approved, change `RC_OVERRIDE_TIME` from `3.0` to
   `0.5` only inside that new approval, then capture and pin a fresh snapshot.
4. For full physical EOD, power off the FCU, Pi and Herelink and record that
   declaration; their powered-off state is not established by the current
   closeout statement.

### Final power-off confirmation

The operator subsequently confirmed that the FCU, Pi and Herelink were powered
off. This closes item 4 and the physical EOD layer. No physical declaration or
live-test approval carries forward to a later session.
