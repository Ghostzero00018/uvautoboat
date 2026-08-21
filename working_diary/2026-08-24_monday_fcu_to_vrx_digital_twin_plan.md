# Monday 24/08/2026 - FCU-to-VRX digital twin proposal

**PRE-DIARY - NOT STARTED.**

This is the sole 24/08/2026 continuation. It carries no approval from
21/08/2026, and no physical approval crosses the date boundary.

## Why this file exists

On 21/08/2026 the `BRD_SER1_RTSCTS` `Auto (2)` to `0` experiment was executed
and rolled back. It did not restore parameter request/response traffic on the
direct Pi serial path. The flow-control hypothesis is therefore closed as a fix
for that failure, and the remaining direct-link transmit, receive and endpoint
hypotheses are unresolved. T0b remains open; T2a and T2b remain closed.

Every repository path to a commanded thruster runs through T0b. `probe`, `run`
and `run-t2a` all execute the same T0b capture before anything else, so no
amount of approval reaches a bridge while the Pi cannot read parameters.

**Stages 1 and 2 below do not have to wait for that.** They never write to the
flight controller and never use the Pi serial link in the failing direction.
**Stage 3 is different and inherits none of that reasoning** - see its own
paragraph.

## The proposal - drive the simulated boat from autopilot servo output

The supported direction is **FCU to VRX**: the autopilot computes its own servo
outputs, and those outputs drive the simulated thrusters. Nothing is sent to the
flight controller.

`tools/servo_command_bridge.py` already implements this. It consumes
`SERVO_OUTPUT_RAW` over **UDP** and publishes
`/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust`. Because the
transport is UDP rather than the Pi's serial port, the receive-only serial
defect does not sit on this path. The node is prepared and **NOT RUN**.

Three stages, each separately approved, each a decision point.

### Stage 1 - simulator only, no hardware

ArduPilot SITL with an explicit `--out=udp:127.0.0.1:14555` output, the bridge on
an isolated domain, and VRX started alone. This proves decode, mapping, rail
handling and thrust publication end to end with **no controller present**; the
mixer exercised here is the ArduPilot SITL mixer, not the boat's. Rover SITL
values measured 07/08/2026 are `left_servo_channel:=1`, `right_servo_channel:=3`
and rails `1000`/`1500`/`2000`.

### Stage 2 - real autopilot, disarmed

Two transport facts, kept apart because only one of them is proven.

*Proven:* the Herelink hotspot path to workstation QGroundControl on UDP `14550`.
The 22/06/2026 capture recorded unicast MAVLink from `192.168.43.1:52600` to
`192.168.43.160:14550`. Separately, on 13/08/2026 Herelink QGroundControl
displayed live `SERVO_OUTPUT_RAW (36)` at `2.0 Hz`, with `servo1_raw` and
`servo3_raw` both holding `800` while the FCU was disarmed with hardware safety
engaged. So the message this bridge needs is known to reach QGroundControl, and
the boat's disarmed value on both channels is known to be `800`.

*Not proven:* that a QGroundControl **forwarded** copy reaches the bridge. The
22/06/2026 record names this as the untried next step - keep QGroundControl on
`14550` and forward to a separate local port. Published QGroundControl
documentation describes forwarding as one-way from QGroundControl to a UDP
endpoint, which suits a read-only consumer, but nothing here has yet shown a
forwarded `SERVO_OUTPUT_RAW` arriving on port `14555`. **Stage 2's first
acceptance criterion is exactly that arrival**, before any decode claim.

Disarmed, the outputs hold `800`/`800`. This stage proves transport, decode and
mapping against the real vehicle without arming it, and a correct decode should
reproduce zero thrust at the bottom-of-rail neutral.

### Stage 3 - observed armed output; still physical T2b work

Servo outputs only leave their disarmed value once the vehicle is armed and the
pilot moves the Herelink sticks. That is a **non-neutral real-FCU output
produced by a deliberate physical input**, which is T2b in substance regardless
of where the resulting numbers are displayed. Isolating propulsion power and
removing the propellers limits the consequence; it does not change the tier.

**Stage 3 therefore does not inherit the "does not have to wait for T0b"
reasoning above.** It stays behind the existing physical gates - T0b, then T2a,
then T2b, each with its own approval - unless the operator explicitly supersedes
those gates in a later instruction. This file schedules nothing and proposes no
supersession.

## What must be read live, never assumed

The real boat records `SERVO3` as function `73` (ThrottleLeft) and `SERVO1` as
function `74` (ThrottleRight), with rails `800`/`800`/`2200` - neutral at the
**bottom**, so there is no reverse. Rover SITL is the mirror image on both
counts. The bridge's own defaults, `1100`/`1500`/`1900`, match neither platform
and exist as a documented trap rather than a profile to reuse.

Emitting a mid-scale neutral at the real vehicle's rail would represent roughly
half thrust while the caller believed it commanded zero. On this path that error
would only mis-scale the simulated thrust, but the same numbers must never be
carried into a commanding path.

### QGroundControl parameter reads do not earn T0b

The `41`-parameter T0b artifact does not exist, and a QGroundControl parameter
listing **cannot** substitute for it. T0b is defined as non-actuating
request/response evidence **over the direct link** - the `Pi TXD (GPIO14) ->
Cube SERIAL1 RX` path whose failure is the open defect. A reading taken over the
Herelink telemetry link exercises a different transport and proves nothing about
the failing one. That is a definitional consequence, not a policy preference.

What such a reading may legitimately do is supply **path-local mapping and rail
inputs for this read-only FCU-to-VRX experiment only**: `SERVO*_FUNCTION`,
`SERVO*_MIN`, `SERVO*_TRIM`, `SERVO*_MAX`, `SERVO*_REVERSED` and `RCMAP_*`,
recorded as a working input for Stage 2 decode. It is not T0b evidence, does not
close T0b, and does not unlock T2a or T2b.

## Read first

1. This file in full.
2. The `End-of-day close-out` section of
   `working_diary/2026-08-21_friday_t0b_request_path_continuation.md`.
3. The 21/08/2026 supersessions in `Board.md`, `wiki/Roadmap.md` and
   `web_dashboard/autoboat/README_autoboat_dashboard.md`.
4. The module docstring of `tools/servo_command_bridge.py` in full, including
   the deliberate differences and the safety section.
5. The 22/06/2026 Herelink MAVLink capture rows and the 13/08/2026 C2 pre-arm
   checkpoint in `Board.md`.
6. `working_diary/2026-07-27_monday_fcu_vrx_bridge_reference.md` for the C++
   reference review.

## Block A - certification only

Certify the live revision before any simulator or hardware step, and stop after
it reports. Stage 1 requires its own approval even if every check passes.

```bash
git fetch --prune
git status --short --branch
git rev-parse HEAD origin/main
git rev-list --left-right --count main...origin/main
```

Require a clean worktree, `HEAD == origin/main` and divergence `0/0`. That is
sufficient for Stage 1: `tools/servo_command_bridge.py` is tracked, so clean
pushed parity certifies its bytes directly.

`config/real_fcu_digital_twin_bundle.sha256` is **not** checked here. Its four
members are `tools/real_fcu_digital_twin_pi.sh`,
`tools/real_fcu_rc_command_bridge.py` and the two real-FCU MAVROS plugin
configurations; none of them is the component Stage 1 exercises, and requiring
it would couple simulator acceptance to an unrelated real-FCU bundle.
Re-introduce that manifest check, with its recorded digest and four `OK` member
lines, only for a stage that deploys or runs the real-FCU bundle.

One limit to carry into Stage 1 acceptance: `tools/servo_command_bridge.py` has
no focused test suite under `tools/`. Nothing certifies its behaviour ahead of a
run, so the Stage 1 verdict rests entirely on its own observed decode and
published thrust rather than on prior coverage.

## Boundaries

- No write of any kind reaches the flight controller on this path. No parameter
  write, mode change, arming command, RC override or motor command is issued by
  the repository.
- Arming, when it happens at all, is an external operator action through the
  Herelink or QGroundControl, is T2b-gated per Stage 3, and is not scheduled by
  this file.
- Propulsion power stays isolated, propellers stay removed and the hull stays
  restrained for any stage involving the real vehicle.
- The bridge publishes on `/wamv/thrusters/*`, which the Pi safety monitor
  treats as protected command topics. Any run keeps the Pi stack down and uses a
  separate, explicitly isolated `ROS_DOMAIN_ID`.
- Keep `publish_sensors:=false`. The outbound sensor-injection path is
  unsupported and unvalidated.
- No simulator and real-FCU supervisor overlap.
- Channel numbers and rails come from an observed reading in the same session,
  never from a remembered profile or from the other platform.

## Open questions for the operator

1. Does the direct Pi serial link stay on the schedule as its own diagnostic, or
   is it parked while the twin advances on the UDP path?
2. Is Stage 2 worth running on its own evidence value - a real-vehicle decode at
   the `800`/`800` disarmed rail - or only as preparation for a later stage?

## The C++ reference - already held and already reviewed

The supervisor confirmed on 21/08/2026 that the control box uses `SERVO1` and
`SERVO3`, which matches the recorded mapping, and stated that the reference C++
implementation sends commands in the **FCU to VRX** direction, with the other
direction still to be examined.

That reference is already in hand. `ab16f15` added `tools/servo_command.cpp`
(`180` lines) as an autopilot-to-simulator reference; `fcb346a` later removed it
from the tree as an unbuilt artifact, so it lives in repository history rather
than at `HEAD`. An untracked copy sits at `~/Downloads/servo_command.cpp` and
hashes to
`f10e548d6320c361908126a0c73833b1adba09592ec30048ec8db622b4f3fae4`, identical to
the `ab16f15` blob, so the supervisor's copy and the recorded revision are the
same bytes.

It was reviewed on 27/07/2026 and again on 07/08/2026. The recorded findings
still stand: it is a reference only, with no `main()`, no `rclcpp::init` or
`spin`, and no build files, so it does not produce an executable; and it
announces itself as an armed `MAV_TYPE_SURFACE_BOAT`, an impersonation
`tools/servo_command_bridge.py` deliberately rejects in favour of an
onboard-controller identity with `base_mode 0`. **No fresh review is needed
before Stage 1**; re-read the 27/07/2026 record instead.

The separate display-window sizing item concerns the Pi overlay window. Those
experiments were retired on 23/07/2026 and nothing in this file reopens them.
