# Thursday 03/09/2026 - Hailo camera in the dashboard, and a self-navigation mode

**PRE-DIARY. Written 02/09/2026 at end of day. Nothing below has been run or
implemented. Read the 02/09/2026 diary first, in particular the open items and
the Hailo/FCU interaction, because one of them gates the first task.**

## Where the day starts

Bundle `929831e` is deployed and certified on the Pi. It carries the `0.20`
throttle ceiling and person-alert advisory mode. The full T3a stack ran to
readiness, closed the bidirectional twin loop against the real flight
controller, and closed out cleanly.

The measured ESC start threshold is `0.15` demand, `996 us`, `+14.0%` of the
`800/800/2200` rail, from rest with steering at `0`.

## Task 1 - Hailo camera in the dashboard

### Most of this already exists

Before building anything, note what is already in place, because the task is
smaller than it sounds and the real obstacle is elsewhere.

- `/hailo/overlay/image_raw` is already in the dashboard's camera topic
  whitelist at `web_dashboard/autoboat/index.html:1082`.
- The camera panel already exists, with enlarge, zoom and an emergency-stop
  control inside the expanded view.
- `web_video_server` on port `8080` is already started by W1 whenever
  `REAL_FCU_HAILO_PERSON_STOP=1`.
- The dashboard already subscribes directly to `/perception/person_alert` and
  renders a person badge from it.
- Advisory mode was built on 02/09/2026, so a detection can already warn without
  stopping.

So the plumbing is present. What has never happened is running it end to end,
because of the item below.

### The actual blocker

**The Hailo and flight-controller interaction is unexplained and prevents any
Hailo-enabled run.** With `REAL_FCU_HAILO_PERSON_STOP=1` the MAVROS probe never
sees the vehicle: `78` router address events, all implausible, and `1.1` never
among them. With Hailo disabled the same hardware connects in under a second,
confirmed four times.

Serial contention is ruled out from the Hailo bridge's own source: it is `cv2`,
`numpy` and `rclpy` publishing `Image`, and never opens a device. Scheduling
starvation and electrical interference both remain possible and have not been
separated.

**The measurement that separates them is prepared and unfinished.** The UART
driver exposes per-port error counters:

```bash
sudo cat /proc/tty/driver/ttyAMA | sed -n 2p
```

A control run on 02/09/2026 with MAVROS alone moved `rx` by `229,984` bytes and
`fe`, `brk` and `oe` by **zero**. That is a clean baseline, so any counter that
moves during a Hailo-enabled run is attributable.

- `oe` climbing means the reader is starved and the FIFO overran. The fix is
  scheduling, and it is small: the Hailo command vector in
  `rfcu_pi_build_commands` already begins with `env`, so a `nice` prefix is one
  line, with `chrt` on MAVROS as a stronger option.
- `fe` or `brk` climbing means the signal itself is being corrupted. That is
  hardware - power draw or interference - and no priority tuning will help.

The earlier attempt at this measurement failed before reaching `mavros-probe`
because the Hailo readiness gate correctly refused to declare the water clear
with `2` to `3` people in the camera view across `9,200` frames. **The camera
needs an empty field of view at startup**, which is also an operational
constraint for any demonstration.

### The detection principle to implement

Detection must warn, not stop. That is what advisory mode does, and it is
already built and deployed:

```bash
REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1
```

The dashboard renders `PERSON OBSTACLE - ADVISORY, NOT STOPPED` in critical
styling, and the T3a READY marker records `person_alert=advisory-no-stop`. The
freshness requirement is deliberately retained, so a dead detector feed still
stops in either mode.

Nothing further needs writing for the principle itself. What is missing is a run
in which it can be demonstrated.

### Suggested order

1. Take the UART counter measurement and name the mechanism.
2. If it is `oe`, apply the scheduling fix, regenerate the manifest, transfer and
   certify, then run with both Hailo flags.
3. Confirm the camera panel renders `/hailo/overlay/image_raw` through
   `web_video_server` on `8080`, and that a detection produces the advisory
   badge without stopping.

Step 1 is the whole of it. Steps 2 and 3 are short if step 1 answers cleanly.

## Task 2 - a simple self-navigation mode on the real boat

The operator observation that motivates this: the real GPS is working, and the
dashboard minimap shows the boat's true position on the university site.

### What exists

The VRX navigation stack is real and complete for the simulator:

- `plan/plan/waypoint_planner.py` subscribes to `/wamv/sensors/gps/gps/fix`
  and publishes `/planning/waypoints`, `/planning/current_target` and
  `/planning/mission_status`.
- `control/control/heading_controller.py` publishes
  `/wamv/thrusters/left/thrust` and the matching right topic as `Float64`.
- `plan/plan/lidar_perception.py` and `waypoint_visualizer.py` support them.
- The dashboard already has waypoint entry, mission control and the minimap.

### The two questions that decide the design

**Where does steering output go?** This is the substantive one. The heading
controller publishes simulator thrust topics. The real boat's only actuator path
is `/command_ingress/rc_axes` as `sensor_msgs/Joy` into
`tools/real_fcu_rc_command_bridge.py`, which holds the RC override, the rails,
the guard and every safety interlock. The tracked record carries a standing
constraint of one actuator path and explicitly avoids adding a second actuator
route.

So self-navigation on the real boat means the planner's output must reach the
existing bridge rather than a parallel one. That raises real questions worth
settling before code: what owns `control_owner` when the planner is driving,
how the existing E-Stop and person-alert interlocks apply to a non-browser
source, whether the bridge's exact-publisher binding for
`/command_ingress/rc_axes` admits a planner node, and how the operator takes
control back.

**Which GPS?** The planner reads `/wamv/sensors/gps/gps/fix`. The real boat
publishes `/mavros/global_position/raw/fix`. Either the planner takes a
configurable topic, or a remap covers it. The dashboard already consumes the
real one, which is why the minimap is correct.

### The VRX world

The operator's requirement is explicit and narrow: **the VRX world stays as it
is, and only needs to hold the boat model. It does not need to resemble the real
site.** That keeps this scoped as a visualisation of the real boat's motion
rather than a terrain-matching exercise, and it fits the twin that already
works: measured FCU output already drives VRX thrust, and VRX pose already
returns to the dashboard.

### What not to assume

This is a new actuator source on a hull with propellers fitted, at a `0.20`
ceiling whose measured start threshold is `0.15`. The usable band above
break-away is roughly `0.05` in demand units. Autonomous steering inside a band
that narrow deserves its own thinking, and nothing here authorises a run.

## Check the Hailo checkout before starting anything

The Hailo branch has a second gate, separate from the bundle, and it is much
stricter. `rfcu_pi_validate_hailo_preflight` runs only when
`REAL_FCU_HAILO_PERSON_STOP=1`, and it checks a **different repository**: the
`hailo-apps` checkout on the Pi. It requires that checkout to sit on a pinned
revision and to be completely clean including untracked files, then verifies
three pinned file checksums, the HEF checksum, the camera device and the
virtualenv.

The Pi helper's own `check` mode cannot pre-validate this. It leaves the run
mode at `none`, and the gate rejects any mode that is not a run mode, so
`REAL_FCU_HAILO_PERSON_STOP=1 ... check` fails with
`allowed only for a run mode` rather than validating anything.

The two pins that actually drift are the revision and the cleanliness, because
both change the moment anyone opens that checkout. On the Pi:

```bash
git -C ~/hailo_coco_overlay_2026-07-10/hailo-apps rev-parse HEAD
```

```bash
git -C ~/hailo_coco_overlay_2026-07-10/hailo-apps status --porcelain=v1 --untracked-files=all
```

The first must print `891ce701c2ebe239a5d277759eb75a30f76678a9`. The second
must print nothing at all; a single stray untracked file is enough to stop the
run at the gate. If the checkout root was moved, `REAL_FCU_HAILO_ROOT`
overrides it and the paths above shift with it.

The remaining pins - the three file checksums, the HEF, the camera and the
virtualenv - are left to the gate itself, which names precisely which one
failed. They do not drift on their own the way a working checkout does.

## How the stack starts now

The three workstation terminals were replaced on the evening of 02/09/2026 by
a single entry point, `tools/real_fcu_full_stack_workstation.sh`. It starts
the VRX supervisor, then the real-FCU supervisor, then the capture node in the
foreground of the same terminal, and it stops them in the documented order:
the VRX supervisor first, the real-FCU supervisor last so its stop marker
releases the Pi.

    bash tools/real_fcu_full_stack_workstation.sh check
    bash tools/real_fcu_full_stack_workstation.sh run-t3a

Run `check` first. The real-FCU supervisor requires a clean worktree checked
with `--untracked-files=all`, so the two new files must be committed before
either mode passes, and the combined `check` had not yet been run at the time
this was written.

Then one command on the Pi, then the dashboard. The base URL is
`http://127.0.0.1:8002/`; the exact bench-control URL, carrying the mapping
resolved from the flight controller, is printed by the real-FCU supervisor
into its log only once the Pi has connected, and the entry point says where to
read it.

Two things worth carrying into the first use. The capture node must stay
running because the Pi's discovery guard requires it. And the entry point has
never met a Pi or a flight controller; the three terminals it replaces still
work exactly as they did on 02/09/2026, so falling back costs only the paste.

## Carried open items

- The deployed bundle matches the repository at `929831e`; keep it that way or
  redeploy, since two governed members changed twice on 02/09/2026.
- The ESC calibration interface records the plateau held at release rather than
  the transition, and its terminal observation is one-shot per side. Fine for
  confirming a known value, poor for discovering one. Recorded, not repaired.
- `RC_OVERRIDE_TIME` remains `0.5` and the bridge requires `(0, 0.5]`.
- The FCU-to-VRX supervisor's own test suite is non-hermetic: exported
  `FCU_VRX_*` values make it fail with `missing live-read configuration was
  accepted`. Recorded 02/09/2026, not repaired. The new entry point scrubs
  them before delegating, so it is not in the way of a run.

## Session record - 03/09/2026, at the bench

Pi and flight controller present. Committed before the session started:
`60804e3` corrected the entry point's bare `run` to capture tier `t2b`, the
Pi's authority for that mode, and `37da8ac` added the Hailo checkout pins to
this file. Workstation preflight `FULL_STACK_CHECK=PASS` on `37da8ac`.

### A wrong UART diagnosis, and the corrected instrument

With the Pi up and then with the flight controller powered, the receive
counter read `tx:740 rx:436 fe:284 brk:15 oe:12` and did not move across four
3-second windows, and `timeout 3 cat /dev/ttyAMA0 | xxd` printed nothing. A
later pair read `tx:1120 rx:825 fe:541 brk:30 oe:23`. I called that "zero
signal edges at the pin" and named the cable. Then the stack was started
anyway and MAVROS connected at once: `REAL_FCU_TELEMETRY=PASS` on all six
topics. The link had been fine throughout.

Two facts I stated were false:

- The PL011 receiver is disabled when no process holds the port, so
  `/proc/tty/driver/ttyAMA` counts nothing while the port is closed. Every
  static reading was a reading of a disabled receiver.
- `cat` opens the port at the tty's boot-default line settings, not `57600`.
  Yesterday's `cat` showed clean frames only because MAVROS had already set
  `57600` earlier in that boot and termios persists across open and close
  until reboot. Today, on a fresh boot, `cat` received the `57600` stream at
  the wrong rate, the tty layer discarded it as framing errors, and nothing
  reached `xxd`. The `+389 rx / +257 fe` burst between readings was that
  `cat` run itself, not a connector moving.

Corrected instrument for a fresh boot, untested here: set the line first with
`stty -F /dev/ttyAMA0 57600 raw` and then read, or take the counter pair while
a process that has set the rate holds the port. The unexplained `tx` bursts
were also this: a wrong-rate reader still acknowledges nothing, but a serial
console was ruled out (`console=tty1` only, both gettys inactive, ModemManager
inactive). This is the fourth wrong UART call across two days, and it cost a
run delay and a false cable suspicion. The lesson is the same each time: name
what the instrument can and cannot see before reading it.

### First Hailo-enabled READY, ever

Bundle `929831e`, Pi run `real_fcu_t3a_pi_20260903_163003`, workstation
`real_fcu_full_stack_20260903_162620`, W1 `..._162638`, capture `..._163015`.
The Hailo checkout pins passed (`HEAD 891ce701`, clean). Both machines came up
from one command each. The Pi reached
`REAL_FCU_T3A_READY=PASS ... hailo=ready person_alert=advisory-no-stop`; W2
reported relay, twin telemetry and the four-stream observer all `READY`; W1
reported all six telemetry topics plus `hailo=image,person-detections`. The
dashboard showed Hardware Safety `ENGAGED`, a live camera panel, and the
operator armed.

### Defect - advisory mode latched the stop anyway

A person in frame gave the red badge, and every control greyed. Live bridge
status: `state EMERGENCY_STOP`, `emergency_stop_latched true`,
`person_alert_advisory true`, `person_hold_clear false`, `ready false`,
reset blocked by `COMMAND_NEUTRAL_DISABLED_REQUIRED`. Advisory was on in the
bridge and the stop latched regardless.

The bridge got advisory mode yesterday; the detector monitor did not.
`tools/real_fcu_digital_twin_workstation.sh` launched
`plan/plan/person_stop_monitor.py` with `latch_emergency_stop:=true`, and the
monitor publishes `Bool(True)` on `/planning/emergency_stop` on every tick a
person is visible. The bridge subscribes to that topic and latches on it
unconditionally, and it must: the dashboard's own E-stop button publishes to
the same topic (`FCU_BENCH_EMERGENCY_TOPIC`), so the bridge cannot tell a
monitor stop from an operator stop. The fix therefore has to be at the
monitor, and W1 never read `REAL_FCU_PERSON_ALERT_ADVISORY` at all. My miss:
one publisher on a shared topic was made advisory-aware and the second was
never traced.

W1 now reads the flag, launches the monitor with `latch_emergency_stop:=false`
under advisory and `:=true` otherwise, requires the detector to be on when
advisory is set, records the setting in its manifest, and its READY marker
says `person_alert=advisory-no-stop` or `stop-enabled` instead of the
unconditional `person_stop=armed`. Four cases added; a mutant forcing the
latch back on fails with `advisory mode still lets the monitor raise the
authoritative E-stop`. W1 is not a bundle member.

### GPS: no fix indoors, not a software fault

`/mavros/global_position/raw/fix` read `status -1`, latitude and longitude
`0.0`, `raw/satellites` `0`. The dashboard's "Waiting" and its refusal to move
the map are what its own tests require of an invalid fix. Yesterday's correct
position had sky; today did not.

### Stop of the first run - the Pi clean, my wrapper wrong

Pi: `REAL_FCU_T3A_SAFE_CLOSEOUT=PASS`, `REAL_FCU_FINAL_STATE=PASS`,
`REAL_FCU_WORKSTATION_STOP=PASS marker=received`, all children stopped,
`REAL_FCU_PI_EXIT status=0 cleanup_rc=0`. W1: `operator stop requested` at
`t=1788447988`, marker published, `REAL_FCU_WORKSTATION_EXIT status=0
cleanup_rc=0` at `t=1788447991`, three seconds later. The wrapper meanwhile
printed `W1 did not stop within 180s, sending TERM` and then
`FULL_STACK_EXIT status=0`.

W1 was innocent. The wrapper judged liveness by process group, and the ROS 2
CLI daemon that `ros2 topic echo` starts had landed in W1's group: proven on
this workstation with a throwaway domain, where the daemon spawned by a job
under `set -m` carried that job's pgid `62058` after the job had exited, and
`ros2cli/daemon/daemonize.py` sets `DETACHED_PROCESS` only on Windows. So after
W1 exited cleanly in three seconds, `kill -0` on its group kept answering, the
wrapper waited its whole grace and TERMed a bystander, and then reported a
clean exit it had not earned.

Fixed: liveness is the supervisor's pid; stragglers in the group are listed
with `pgrep -g` and terminated, never counted against the supervisor; W1's
grace is its readiness timeout plus sixty seconds, because its stop marker
legitimately blocks until the Pi reaches its closeout wait; a forced stop exits
non-zero with `stop=escalated`; every wrapper line carries a timestamp and no
`kill` result is swallowed. Two cases added, `12` to `14`: a supervisor that
leaves an in-group straggler must be seen to stop cleanly and the straggler
swept, and a supervisor that ignores the interrupt must be escalated and
reported. A mutant restoring group liveness fails the first with `a straggler
made the stop non-clean`. Two suite defects surfaced on the way and were
fixed: a `pkill -f` on a literal that matched the harness's own shell, and a
`pipefail` assignment that ended the suite silently; both are now selection by
pgid with guarded assignments.

### Feature - the Hailo window on the Pi desktop

Requested by the professor. `REAL_FCU_HAILO_LOCAL_DISPLAY=1` drops
`--no-display` from the Pi's Hailo command. Nothing else changes: the
generated wrapper hands every frame back to hailo-apps' own `visualize`, which
draws its native resizable window when the flag is absent. A display is
required at preflight, because a detector that dies for want of one mid-run
reads as a lost feed and stops the boat; the check mirrors the older
`HAILO_LOCAL_DISPLAY` tool. The T3a READY marker gains `display=local-window`
or `headless`, and the Pi manifest gains `person_alert_advisory=` and
`hailo_local_display=`, which it had lacked. Three cases added; a mutant
forcing `--no-display` back fails with `local-display mode still passes
--no-display`.

### Deployment

Helper suite `73` to `79`, wrapper suite `12` to `14`, bundle manifest
regenerated with the Pi helper at `1dcc84d9`, `sha256sum -c` clean. Committed
as `7cf684b` and transferred by `scp` into
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260903_7cf684b`, a copy of
the `929831e` directory with the two changed files replaced. Certification on
the Pi and the restart were pending when this was written.
