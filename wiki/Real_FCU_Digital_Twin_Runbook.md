# Real-FCU Digital Twin Runbook

Operator runbook for the real-flight-controller digital twin: the Raspberry Pi 5
driving a Cube Orange+ running ArduRover 4.6.3, the Hailo-8L person detector,
the workstation dashboard, and the VRX simulator following the real outputs.
One command per machine. Everything here has been run on hardware; the dated
records are the 02/09/2026 and 03/09/2026 working diaries.

> Status 03/09/2026: bundle `a8bed50` deployed and certified on the Pi. A
> `42`-minute armed run from these commands held the full showcase: Hailo
> images on the dashboard and on the Pi desktop, dashboard demand reaching the
> propellers with the simulator following, advisory person detection with `96`
> detections against `0` stops, Herelink arm and disarm live on the dashboard.

The older two-command view-only procedure with
`tools/live_dashboard_preflight.sh` and `tools/pi_live_hailo_mavlink_dashboard.sh`
is a different stack with a different start order; it is documented in
[Live Hailo and MAVROS Dashboard Testing](Live_Hailo_MAVLink_Dashboard_Testing)
and is not what this page describes.

## 1. What runs where

| Machine | Process | Owner |
| --- | --- | --- |
| Pi 5 | MAVROS on `/dev/ttyAMA0` at `57600`, the RC command bridge, the Hailo detector | `tools/real_fcu_digital_twin_pi.sh` |
| Workstation | rosbridge on `9090`, dashboard on `8002`, `web_video_server` on `8080`, the person-stop monitor | W1, `tools/real_fcu_digital_twin_workstation.sh` |
| Workstation | VRX simulator, RCOut relay, twin telemetry, four-stream observer | W2, `tools/fcu_to_vrx_workstation.sh` |
| Workstation | command and feedback capture, interactive, in the foreground | `tools/real_fcu_command_feedback_capture.py` |
| Workstation | starts and stops the three above in order | `tools/real_fcu_full_stack_workstation.sh` |

Domains: the Pi and W1 on `43` with subnet discovery; W2 on `77` local-only
with a relay onto `43`. Each helper exports its own domain; do not set one by
hand for any of them.

The only actuator path is dashboard demand on `/command_ingress/rc_axes` into
the Pi bridge, which holds the RC override, the rails, the parameter guard and
every interlock. The dashboard E-stop and the person-stop monitor share
`/planning/emergency_stop`; the bridge latches on it unconditionally.

## 2. Before starting

Workstation preflight, which refuses a dirty worktree:

```bash
cd ~/seal_ws/src/uvautoboat && bash tools/real_fcu_full_stack_workstation.sh check
```

Expect `FULL_STACK_CHECK=PASS`. It runs both supervisors' own check modes,
which run every suite; on 03/09/2026 that was helper `83`, VRX `36` shell plus
`48` Python, bridge `67`, capture `37`, dashboard `101`.

Pi, if the Hailo branch is used. The gate requires the `hailo-apps` checkout to
be on its pin and completely clean, including untracked files:

```bash
git -C ~/hailo_coco_overlay_2026-07-10/hailo-apps rev-parse HEAD
```

```bash
git -C ~/hailo_coco_overlay_2026-07-10/hailo-apps status --porcelain=v1 --untracked-files=all
```

The first prints `891ce701c2ebe239a5d277759eb75a30f76678a9`; the second prints
nothing. `REAL_FCU_HAILO_ROOT` moves the checkout root if it was relocated.

Flight controller powered and steady before the Pi helper starts. Do not judge
the link with `cat /dev/ttyAMA0` on a fresh boot: the port opens at its default
rate, the `57600` stream arrives as framing errors and prints nothing, and the
receive counters in `/proc/tty/driver/ttyAMA` do not move while no process
holds the port. Both gave a false dead-link reading on 03/09/2026 while the
link was fine. Set the rate first, `stty -F /dev/ttyAMA0 57600 raw`, untested
as of 03/09, or let the Pi helper's own probe be the judge.

## 3. Start

Workstation, one terminal, stays in the foreground for the whole run:

```bash
cd ~/seal_ws/src/uvautoboat && REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1 bash tools/real_fcu_full_stack_workstation.sh run-t3a
```

Drop the two flags for a run without the detector. Modes mirror the Pi's:
`run-t3a` is tier `T3a`, bare `run` or `run-t2b` is `T2b`, `run-t2a` is `T2a`.

It starts W2, waits for `FCU_TO_VRX_WORKSTATION_PRESTART=PASS`, starts W1, and
in Hailo mode prints `HAILO MODE: start the Pi helper NOW`. **Start the Pi at
that line.** W1 cannot report its services until it has seen one detection
frame from the Pi, so the operator block below does not appear before the Pi
is running.

Pi, from a Remmina desktop terminal when the local window is wanted, in the
deployed bundle directory:

```bash
cd ~/uvautoboat_real_fcu_bundle_20260903_a8bed50 && source /opt/ros/jazzy/setup.bash && REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1 REAL_FCU_HAILO_LOCAL_DISPLAY=1 REAL_FCU_READY_TIMEOUT_SECONDS=1200 REAL_FCU_GUARD_SNAPSHOT_FILE=/home/imt-aqua-drone/Desktop/real_fcu_params_20260901_t3a_live_0p5.parm REAL_FCU_GUARD_SNAPSHOT_SHA256=5ea352bc3922216470cfa9ad1e1358ce8f51fc05608163b729096ba4a588767d REAL_FCU_GUARD_SNAPSHOT_APPROVED=1 REAL_FCU_T0A_COMPLETE=1 REAL_FCU_T0B_APPROVED=1 REAL_FCU_T3A_APPROVED=1 REAL_FCU_START_DISARMED=1 REAL_FCU_SAFETY_ON=1 REAL_FCU_PROPELLERS_FITTED=1 REAL_FCU_HULL_RESTRAINED=1 REAL_FCU_MECHANICAL_GUARDING_INSTALLED=1 REAL_FCU_EXCLUSION_ZONE_CLEAR=1 REAL_FCU_PROPULSION_ISOLATED=1 REAL_FCU_T2A_APPROVED=0 REAL_FCU_T2B_APPROVED=0 REAL_FCU_PROPELLERS_REMOVED=0 bash tools/real_fcu_digital_twin_pi.sh run-t3a
```

The thirteen `REAL_FCU_*` declarations at the end are the operator's statement
of physical state; pressing Enter asserts they hold. The `T3a` gate accepts
exactly this pattern and names any flag that does not match. The guard snapshot
is the hash-pinned `986`-parameter read taken with `RC_OVERRIDE_TIME=0.5`;
it resolves `steering=RC1 throttle=RC3 left=SERVO3 right=SERVO1`. The camera
needs an empty field of view at startup.

Then the workstation prints its operator block and runs the capture node,
`REAL_FCU_CAPTURE_READY=PASS tier=T3A subscriptions=5`. Leave that terminal
alone; the Pi's discovery guard requires the capture node.

Markers that mean READY:

| Where | Line |
| --- | --- |
| Pi | `REAL_FCU_T3A_READY=PASS ... bridge=READY_DISARMED workstation=visible ... person_alert=advisory-no-stop display=local-window` |
| W1 | `REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output hailo=image,person-detections person_alert=advisory-no-stop` |
| W2 | `FCU_TO_VRX_RC_OUT_RELAY_READY=PASS`, `FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS`, `FCU_TO_VRX_WORKSTATION_READY=PASS ... streams=4` |

W1 and W2 write to `logs/w1.log` and `logs/w2.log` under the entry point's run
directory, `~/Desktop/real_fcu_full_stack_<date>_<time>`.

## 4. Dashboard

Base URL `http://127.0.0.1:8002/`. The bench-control URL, carrying the mapping
resolved from the flight controller, appears in `logs/w1.log` once the Pi has
connected:

```bash
grep REAL_FCU_BENCH_URL ~/Desktop/real_fcu_full_stack_*/logs/w1.log | tail -1
```

Confirm Hardware Safety agrees with the physical switch; `Unknown (stale)` is
not a reading. Arming is external and the operator's. HOLD applies demand only
while held; release is neutral within a frame.

## 5. Stop, in this order

1. Press E-stop on the dashboard. The capture node ends at the next step, and
   the `t3a` verdict requires it to have recorded the latched `EMERGENCY_STOP`.
2. Disarm externally and bring the boat to safe state.
3. Workstation terminal: Ctrl+C. W2 stops, then the terminal pauses with the
   dashboard still up.
4. Pi terminal: Ctrl+C, do the physical steps it lists, type the closeout token
   it asks for. It then prints `waiting for workstation operator stop before
   bridge shutdown`.
5. Only after that line: press Enter at the workstation prompt. W1 stops last
   and publishes the marker that releases the Pi.

Expected ends: Pi `REAL_FCU_WORKSTATION_STOP=PASS marker=received` and
`REAL_FCU_PI_EXIT status=0 cleanup_rc=0`; workstation `FULL_STACK_EXIT status=0
stop=clean`. `stop=escalated` means a supervisor had to be forced and is worth
reading the logs for.

## 6. Evidence

| Artifact | Where |
| --- | --- |
| Entry point run, W1 and W2 logs | `~/Desktop/real_fcu_full_stack_<stamp>/logs/` |
| W1 own run directory | `~/Desktop/real_fcu_digital_twin_workstation_<stamp>/` |
| W2 own run directory | `~/Desktop/fcu_to_vrx_workstation_<stamp>/` |
| Capture verdict and events | `~/Desktop/real_fcu_capture_t3a_esc_threshold_<stamp>/evidence/verdict.json` |
| Pi run directory, to copy back | `/home/imt-aqua-drone/Desktop/real_fcu_t3a_pi_<stamp>/` |

Copy back from the workstation:

```bash
mkdir -p ~/Desktop/pi_run_evidence && scp -r imt-aqua-drone@10.120.2.249:/home/imt-aqua-drone/Desktop/real_fcu_t3a_pi_<stamp> ~/Desktop/pi_run_evidence/
```

The Pi address was `10.120.2.249` on both 02/09 and 03/09/2026; `hostname -I`
on the Pi confirms it.

### Reading the verdict

A `t3a` verdict reads `pass:false` whenever the operator does not type ESC
observations into the capture terminal, on
`calibration_left_observation_incomplete` and
`calibration_right_observation_incomplete`. That is the expected outcome and
not a failed run: the ESC start threshold is an operator-recorded reference,
section 7, and the typed calibration is not its source.

`final_status_not_disarmed` and `tier_status_sequence_incomplete` mean the
capture did not see the run end in `EMERGENCY_STOP`. On 03/09/2026 that came
from pressing E-stop after the capture had been stopped; the stop order above
prevents it. Any other reason is worth reading.

Publisher binding `pass` with `/real_fcu_rc_command_bridge_t3a`,
`invalid_status_count 0`, and states alternating `ARMED_NEUTRAL` and `ACTIVE`
are what a healthy run looks like.

## 7. Reference figures

Rails `800 / 800 / 2200` on both servos, neutral at minimum, so a rail
percentage is `(pwm - 800) / 1400`. Ceilings `max_steering 0.20`,
`max_throttle 0.20`. Mixer: left is throttle plus steering, right is throttle
minus steering.

ESC start threshold, operator-recorded on the armed `a8bed50` run, propellers
fitted, from rest:

| Demand held | Side that starts | Output at onset | Rail |
| --- | --- | --- | --- |
| throttle `0`, steering `-0.14` | one side | `994` us | `13.9 %` |
| throttle `0`, steering `+0.14` | the other side | `994` us | `13.9 %` |
| steering `0`, throttle `0.15` | both | `996` us | `14.0 %` |

Break-away is about `14 %` of the rail whichever axis drives it; the usable
band above it at the `0.20` ceiling is about `0.05` of demand.

## 8. Advisory person detection

`REAL_FCU_HAILO_PERSON_STOP=1` starts the detector and the person-stop monitor.
Without `REAL_FCU_PERSON_ALERT_ADVISORY=1` a detection latches the bridge
E-stop. With it, the monitor is launched with `latch_emergency_stop:=false`
and the bridge runs with `person_alert_advisory:=true`: a detection raises the
dashboard badge `PERSON OBSTACLE - ADVISORY, NOT STOPPED` and stops nothing.
A lost detector feed still stops in either mode. Both flags must be set on
both machines. Recorded proof 03/09/2026: `96` detections, `0` latches, `0`
E-stop publications over a `30` s joint capture, and `0` `EMERGENCY_STOP`
states in the `42`-minute run.

## 9. Local Hailo window on the Pi

`REAL_FCU_HAILO_LOCAL_DISPLAY=1` on the Pi drops `--no-display`; hailo-apps
draws its `Output` window, pre-created resizable. It requires `DISPLAY` and is
refused at preflight without it, because a detector dying for want of a
window mid-run reads as a lost feed and stops the boat. Run the Pi helper from
a Remmina desktop terminal, not SSH. Measured 03/09/2026: about `7` MB through
the UART with the window open added `36` framing errors and `1` overrun; the
window does not touch the link.

## 10. The Pi bundle

Four governed files and a manifest, `config/real_fcu_digital_twin_bundle.sha256`:
`tools/real_fcu_digital_twin_pi.sh`, `tools/real_fcu_rc_command_bridge.py`,
`config/mavros_real_fcu_closed_loop_plugins.yaml`,
`config/mavros_real_fcu_t0b_plugins.yaml`. The Pi verifies the manifest's path
list and `sha256sum -c`; nothing else. Workstation-side files never need a
transfer.

After changing a member, from the repository root:

```bash
sha256sum tools/real_fcu_digital_twin_pi.sh tools/real_fcu_rc_command_bridge.py config/mavros_real_fcu_closed_loop_plugins.yaml config/mavros_real_fcu_t0b_plugins.yaml > config/real_fcu_digital_twin_bundle.sha256
```

Commit, then transfer into a new directory named for the revision:

```bash
REV=$(git rev-parse --short=7 HEAD) && ssh imt-aqua-drone@10.120.2.249 "cp -r ~/uvautoboat_real_fcu_bundle_20260903_a8bed50 ~/uvautoboat_real_fcu_bundle_$(date +%Y%m%d)_$REV" && scp tools/real_fcu_digital_twin_pi.sh imt-aqua-drone@10.120.2.249:~/uvautoboat_real_fcu_bundle_$(date +%Y%m%d)_$REV/tools/ && scp config/real_fcu_digital_twin_bundle.sha256 imt-aqua-drone@10.120.2.249:~/uvautoboat_real_fcu_bundle_$(date +%Y%m%d)_$REV/config/
```

Add the other members to the `scp` if they changed. Certify on the Pi in the
new directory:

```bash
sha256sum -c config/real_fcu_digital_twin_bundle.sha256 && bash tools/real_fcu_digital_twin_pi.sh check
```

Four `OK` lines and `REAL_FCU_PI_CHECK=PASS`. `check` cannot pre-validate the
Hailo gate, which accepts only run modes; section 2 covers that by hand.

## 11. Known limits, 03/09/2026

- GPS has no fix indoors; the dashboard shows `Waiting` and holds the map on
  its default, which is correct behaviour.
- `t3a` capture requires `--esc-threshold-calibration` and fails `pass` on it;
  decoupling is an open item.
- The Pi's system clock read `Aug 27` at boot on 03/09; NTP correction not
  verified.
- Workspace layout is `~/seal_ws/{src,build,install,log}`, built with
  `colcon build --merge-install` from `~/seal_ws`. W2 requires
  `~/seal_ws/install/setup.bash`.
