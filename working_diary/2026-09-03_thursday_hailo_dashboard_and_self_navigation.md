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
