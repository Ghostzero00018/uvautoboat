# Tuesday 25/08/2026 - FCU-to-VRX digital twin proposal

**LIVE DIARY - PARTIAL DIRECT-LINK DIAGNOSTIC RECORDED; STAGES 1-3 NOT RUN.**

This is the sole 25/08/2026 continuation. It was scaffolded for 24/08/2026,
which went to the internship report; it was moved unchanged in substance. It
carries no approval from 21/08/2026 or 24/08/2026, and no physical approval
crosses either date boundary.

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
outputs, and those outputs drive the simulated thrusters. **The repository's
FCU-to-VRX bridge sends no command and no state-changing write to the flight
controller.** That is a property of the bridge, not of every participant: Stage 3
below involves a real arming and deliberate Herelink stick input, and stays
behind the T0b, T2a and T2b gates.

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

## Live disarmed MAVProxy relay diagnostic - partial only

This was a separately approved real-hardware diagnostic on 25/08/2026, not an
execution of any FCU-to-VRX stage. Before the link was opened, the operator
attested that the FCU was online and disarmed, hardware safety was engaged, the
Herelink was read-only, controls were neutral, propulsion was isolated,
propellers were removed, the hull was restrained and the Pi stack was down.

### Runtime topology and preflight

- Pi: `imt-aqua-drone@imtaquadrone-desktop`, address `10.120.2.249`, MAVProxy
  `1.8.74` at `/home/imt-aqua-drone/.local/bin/mavproxy.py`.
- Workstation: `vrx-Precision-7560`, address `10.120.2.243` on `wlp147s0`,
  MAVProxy `1.8.74` at
  `/home/ghostzero/venv-ardupilot/bin/mavproxy.py`.
- The Pi used `/dev/ttyAMA0` at `57600` baud and exposed
  `udpin:10.120.2.249:14555`; the workstation connected with
  `udpout:10.120.2.249:14555`.
- Both MAVProxy processes used `--streamrate=-1`, `--heartbeat-rate=0`, an empty
  `--default-modules` list, `--nowait` and `--no-state`. This kept the probe to
  the core link module, disabled automatic stream requests and heartbeat
  transmission, and retained no telemetry log.
- On the Pi, both MAVProxy startup-script locations were absent, serial read and
  write access passed, no conflicting repository/MAVProxy/MAVROS process was
  reported, `/dev/ttyAMA0` was unowned (`fuser` return code `1`) and UDP `14555`
  was free.
- On the workstation, the route resolved as
  `10.120.2.249 dev wlp147s0 src 10.120.2.243`; no MAVProxy, MAVROS, SITL,
  servo bridge or QGroundControl process was reported.

The Pi MAVProxy detected vehicle `1:1`, reported mode `MANUAL`, and confirmed
the runtime forwarding setting as `mavfwd True`. The workstation initially
reported `link 1 down`, as the Pi `udpin` endpoint had not yet learned its peer.
After a workstation `ping`, it detected vehicle `1:1`, reported `link 1 OK`,
received mode `MANUAL` and continued receiving FCU telemetry.

### Instrumented `TIMESYNC` result

With `watch TIMESYNC` enabled on the Pi, the trace included a forwarded
workstation request such as:

```text
> TIMESYNC {tc1 : 0, ts1 : 1787647252855465216}
```

It also included FCU-originated messages with unrelated, much smaller `ts1`
values, including:

```text
< TIMESYNC {tc1 : 0, ts1 : 450888869001}
< TIMESYNC {tc1 : 0, ts1 : 460909010001}
< TIMESYNC {tc1 : 0, ts1 : 470928863001}
< TIMESYNC {tc1 : 0, ts1 : 480949440001}
```

No inbound `TIMESYNC` echoed a workstation request timestamp and the
workstation printed no `ping response`. The evidence therefore proves the
workstation-to-Pi UDP path, FCU telemetry from Pi to workstation, and the Pi
MAVProxy software forwarding the request toward the serial master. It does
**not** prove that the request reached or was accepted by the FCU. The direct
Pi-to-FCU request/response defect remains open.

Two `arm throttle` lines were entered at the Pi prompt during the observation.
Both returned `Unknown command 'arm throttle'`; the deliberately empty default
module set had not loaded the `arm` command. No accepted arming action was
observed, and those rejected lines provide no arming evidence.

### Verdict and retained boundaries

- Result: **PARTIAL - NO CORRELATED FCU RESPONSE**.
- Stage 1 remains simulator-only and **NOT RUN**.
- Stage 2 remains **NOT RUN**: QGroundControl forwarding to `14555` and bridge
  arrival were not exercised.
- Stage 3 remains **NOT RUN**: VRX and the servo bridge were not started, and no
  accepted arming or deliberate stick input occurred.
- The earlier full parameter pull was not repeated. No parameter read, parameter
  write, mode change, accepted arming command, RC override or motor/servo command
  was issued by this diagnostic.
- At the last returned terminal evidence, both foreground MAVProxy processes
  were still live. Ordered shutdown and post-stop checks are **NOT YET
  CONFIRMED**; do not cite teardown as complete without later terminal output.

## Receive-only Pi fanout preparation - authorized, not run

The operator subsequently confirmed that the earlier diagnostic processes were
gone: no MAVProxy, SITL, Gazebo or servo-bridge process remained, UDP `14555`
was free and no process was addressing the Pi at `10.120.2.249`. This confirms
the post-stop machine state. It does not reconstruct an ordered shutdown trace
that was not captured during the diagnostic.

The direction then changed. The persistent workstation-to-FCU command relay was
abandoned in favour of the already established Pi Hailo/MAVROS source stack:
Herelink remains the only intended physical controller, the dashboard continues
to read camera and FCU telemetry, and a separately isolated workstation bridge
may later use a received servo-output copy to move only the VRX boat.

The simulator-only Stage 1 block is explicitly **PARKED** and remains **NOT
RUN**. The only authorized implementation in this session was the first,
disarmed preparation: a default-off, outbound-only raw MAVLink fanout with the
existing armed-state guard untouched. Armed observation remains a separate
physical T2b decision and was neither implemented nor run.

### Prepared implementation

- `LIVE_FCU_TO_VRX_FANOUT` defaults to `0`; the established Pi source path is
  unchanged when the selector is not enabled.
- When explicitly set to `1`, MAVProxy still has only loopback outputs:
  `127.0.0.1:14550` for MAVROS and `127.0.0.1:14556` for a run-owned raw MAVLink
  forwarder. MAVProxy is never given a direct workstation `--out` endpoint.
- The forwarder binds only `127.0.0.1:14556`, sends received datagrams through
  a separate socket to the current `WORKSTATION_IP` on UDP `14555`, and never
  reads from that outbound socket. Workstation return traffic therefore has no
  application path back to the loopback MAVProxy output. The forwarder does not
  filter MAVLink message classes; the enforced properties are outbound-only
  direction and local-only ingress.
- The workstation supervisor carries the selector into its printed Pi command,
  checks loopback port `14556` when enabled and keeps the default printed value
  at `0`.
- The safety monitor still unconditionally calls
  `abort_seen("FCU_ARMED", "/mavros/state")`. Connected/disarmed checks,
  command-topic sentinels and final disarmed verification were not relaxed.

Static verification passed on 25/08/2026:

- `bash -n` passed for both modified helpers and their focused shell tests;
- `tools/test_pi_live_hailo_mavlink_dashboard.sh` passed, including one
  loopback datagram forwarded and zero returned datagrams reflected;
- `tools/test_live_dashboard_preflight.sh` passed `13` cases;
- `tools/test_real_fcu_digital_twin_helpers.sh` passed `24` cases, retaining
  separation from the command-capable physical bundle;
- `git diff --check` passed.

This is source and synthetic loopback evidence only. No Pi helper, MAVProxy,
MAVROS, camera, FCU, Herelink, VRX, servo bridge or hardware path was launched
for this implementation. FCU telemetry arrival on workstation UDP `14555`,
disarmed `800`/`800` decode, dashboard/bridge correlation and VRX movement all
remain **NOT RUN**.

## Pi 5 UART endpoint identity - read-only confirmation

Earlier same-day terminal output recorded `enable_uart=1`,
`dtoverlay=disable-bt` and `dtoverlay=uart0` in
`/boot/firmware/config.txt`. A separate `cat /boot/firmware/cmdline.txt` output
contained `console=tty1` and no serial-console assignment. Later read-only
inspection distinguished the two PL011 device nodes exposed by the live Pi 5.

The first pin-controller view was the BCM2712 controller
`107d504100.pinctrl-pinctrl-bcm2712`. Its unclaimed `gpio14` and `gpio15` entries
do not describe the Pi 5 40-pin header. The header is controlled by RP1, whose
live `1f000d0000.gpio-pinctrl-rp1/pinmux-pins` entries reported:

```text
pin 14 (gpio14): 1f00030000.serial (GPIO UNCLAIMED) function uart0 group gpio14
pin 15 (gpio15): 1f00030000.serial (GPIO UNCLAIMED) function uart0 group gpio15
```

The corresponding sysfs links tied `/dev/ttyAMA0` to that same RP1 UART0
controller and `/dev/ttyAMA10` to the separate BCM2712 debug UART:

```text
/dev/ttyAMA0  -> .../1f00030000.serial/1f00030000.serial:0/1f00030000.serial:0.0
/dev/ttyAMA10 -> .../107d001000.serial/107d001000.serial:0/107d001000.serial:0.0
```

A bounded MAVProxy comparison at `57600` baud then supplied the runtime
discriminator. `/dev/ttyAMA10` detected no vehicle. `/dev/ttyAMA0` detected
vehicle `1:1`, reported it online and observed mode `HOLD`. Two subsequent
`mode manual` entries returned `Unknown command 'mode manual'` because the
diagnostic deliberately used an empty default-module set; no accepted mode
change was observed.

Verdict: the current boat's FCU endpoint is `/dev/ttyAMA0:57600` on RP1 UART0.
`/dev/ttyAMA10` is the Pi 5 debug UART and must not replace it. This confirms
endpoint identity and FCU-to-Pi heartbeat reception only. It does not prove
Pi-to-FCU request/response traffic, does not close the direct-link defect and
does not change any Stage 1, Stage 2 or Stage 3 `NOT RUN` boundary.

## Late-day direct command/ACK result and 26/08 handoff

### What the supplied capture proves

A later operator-supplied Pi terminal capture supersedes only the generic
"receive-only serial link" description above. MAVProxy `1.8.74` again opened
`/dev/ttyAMA0:57600`, detected vehicle `1:1` and received live FCU telemetry.
The session deliberately began with an empty default-module set, so its first
`arm throttle` returned `Unknown command`. After `module load arm`, a subsequent
`arm throttle` received:

```text
Got COMMAND_ACK: COMPONENT_ARM_DISARM: ACCEPTED
```

The capture began already `ARMED`, so that acknowledgement proves FCU command
acceptance but not a newly observed disarmed-to-armed transition. It also
reported `Arming checks disabled`. A later `disarm throttle` received the same
accepted command acknowledgement followed by:

```text
AP: Throttle disarmed
DISARMED
```

The accepted disarm and explicit final state prove a Pi-to-FCU state-changing
command/ACK exchange over the direct serial endpoint. The official
[MAVProxy cheatsheet](https://ardupilot.org/mavproxy/docs/getting_started/cheatsheet.html)
documents `arm throttle` for vehicle arming and plain `disarm` for disarming;
the captured `disarm throttle` spelling is retained as evidence, not promoted
as the runbook form.

The same capture contains one `status` snapshot with `RC_CHANNELS` count `16`
and `SERVO_OUTPUT_RAW` at `SERVO1 800` / `SERVO3 800`. No `rc N PWM` command was
executed, no non-neutral servo-output change was captured and no VRX, dashboard,
camera, MAVROS or repository bridge participated. The cheatsheet defines
`rc N PWM` as an RC-input override, with `PWM=0` releasing that override; it is
not a direct write to `SERVO<n>_RAW`.

The operator separately reports that the professor fixed the blocker affecting
workstation-to-FCU commands. The supplied terminal capture is from the Pi prompt,
not the workstation, so that end-to-end workstation claim remains
operator-reported. A future evidence run must correlate a workstation-issued
request with Pi forwarding and the FCU acknowledgement before calling the full
workstation-to-FCU route proven.

Consequently, the direct serial endpoint is no longer described as generically
receive-only: arm/disarm command and acknowledgement traffic is proven in both
directions. The earlier parameter-specific failure remains open because this
capture contains no successful parameter response and no required T0b mapping
artifact. T0b is therefore not closed, T2a is not earned, no RC override or
motor/servo-output test is accepted, and FCU-to-VRX Stages 1-3 remain `NOT RUN`.

### Operator direction for Wednesday 26/08/2026

The next-day target is a full-scale digital-twin integration with the real Pi,
FCU, camera and Herelink active, the dashboard live, and FCU servo output driving
the VRX boat through the outbound-only UDP fanout and isolated bridge. The
operator states that the physical propellers will be removed. This is a plan,
not advance approval: no 25/08/2026 authorization or physical attestation carries
into 26/08/2026.

The 26/08 session must begin with fresh repository certification and a fresh
literal physical-state declaration. Because the FCU reports disabled arming
checks, propeller removal, hull restraint, control neutrality, hardware-safety
state and the exact propulsion-power state must be established explicitly; none
may be inferred from today's capture. The current Hailo/MAVROS helper still
aborts unconditionally on `FCU_ARMED`, so armed observation requires a separately
reviewed lifecycle change and approval before runtime. Do not bypass that guard
with an ad-hoc MAVProxy topology.

The intended evidence chain for the full-scale run is:

```text
Herelink input -> FCU mixer -> SERVO_OUTPUT_RAW
               -> Pi MAVROS -> dashboard /mavros/rc/out
               -> outbound-only Pi fanout -> workstation UDP 14555
               -> isolated servo-command bridge -> VRX thrust and motion
```

Live `RCMAP_*`, RC rails, `SERVO*_FUNCTION` and servo rails must be read in that
session before any bounded input; no SITL or earlier real-boat profile may be
silently reused. Acceptance requires correlated timestamps and values at each
arrow, neutral return, accepted disarm, restored hardware safety and ordered
teardown. No part of this 26/08 runtime was executed on 25/08/2026.

Late operator direction fixes the 26/08 scope: pursue the complete outbound
fanout chain through the bounded armed observation rather than stopping after
the disarmed subset. The separate workstation-to-Pi-to-FCU command trace is not
on that chain and is deferred as an independent diagnostic; it must not be
folded into or used to complicate the FCU-to-VRX run.
