# Monday 10/08/2026 - command-ingress contract and helper thrust telemetry

> **PRE-DIARY - NOT STARTED.** Written at the close of 07/08/2026. This file does
> not authorize work. Every block below needs explicit approval before it starts.
> No arming, no thrust command to real hardware, and no weakening of the Pi
> helper's view-only posture.
>
> **Real-controller access policy, revised 09/08/2026.** The former blanket
> prohibition on any real-FCU write is replaced by a tiered gate, recorded in
> `Board.md`. The revision does **not** authorize anything in this file: no tier
> is in scope for 10/08/2026, and each tier still requires its own separate
> approval when it is proposed. The change is recorded here only so that a
> reader does not treat the blanket wording as current.

## Starting state

- Expected clean `main` with `HEAD == main == origin/main` and divergence `0/0`.
  **Certify before starting.** No hash is pinned here: this file is written
  before the commit that carries it exists, and a self-describing hash is stale
  the moment it lands. The expected parent is the last commit of 07/08/2026,
  whose subject concerns the 07/08 documentation close. If `HEAD` is later,
  inspect every intervening commit first.
- Production pins unchanged and to be re-verified rather than assumed:
  `tools/pi_live_hailo_mavlink_dashboard.sh` at `71,501` bytes /
  `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`, and
  `tools/live_dashboard_preflight.sh` at `28,647` bytes /
  `958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877`.
- ArduPilot SITL exists on the workstation as of 07/08/2026: `~/ardupilot`,
  shallow `Rover-4.6.3` at `3fc7011a`, built to `build/sitl/bin/ardurover`, with
  a virtual environment at `~/venv-ardupilot`. Activate it explicitly and
  **never source ROS in the same shell** - its NumPy `2.5.1` shadows the system
  `1.26.4` that `scipy 1.11.4` pins.
- `~/servo_watch.py` exists outside the repository: a read-only observer that
  prints `servo1_raw`, `servo3_raw` and their difference only when a value
  changes. It sends nothing.
- Disk was `~21 GB` free at `90%` after the 07/08 cleanup. Re-measure rather
  than assume.

## What 07/08/2026 established, and what it did not

Established, all from measurement or source rather than assumption:

- `MAV_CMD_DO_SET_SERVO` cannot drive these thrusters.
  `AP_ServoRelayEvents::do_set_servo` allowlists only `k_none`, `k_manual`,
  sprayer, gripper and `k_rcin*`, returning `false` for anything else, and
  `k_throttleLeft` (`73`) / `k_throttleRight` (`74`) are not in that list.
- `RC_CHANNELS_OVERRIDE` is the working ingress, validated end to end against
  SITL: `mode MANUAL`, `arm throttle` and `disarm` all `ACCEPTED`, with measured
  skid-steer output - throttle symmetric, steering differential, mean equal to
  the throttle level.
- SITL and the real boat carry the same throttle **functions** on **opposite
  channel numbers**, and their PWM rails differ in kind, not only in value.

Not established: nothing has commanded a real autopilot, no contract exists, and
the dashboard still contains no FCU command code.

## Block A - certify and read

Certify the revision and both pins, then read, in this order:

1. `working_diary/2026-08-07_friday_ardupilot_sitl_and_command_ingress_design.md`
   - the whole file, including its three forward corrections.
2. `Board.md` Next Priorities item 2 and the 07/08/2026 Timeline row.
3. `tools/servo_command_bridge.py` - its docstring was corrected on 07/08 and
   now states both platforms' mappings and rails explicitly.

Read-only. Starts nothing.

## Block B - the command-ingress contract, design only

Explicit approval required. **Design only. No implementation.**

This is the carried Block D from 07/08/2026 and the day's primary objective.
Define, before any code exists:

- exact payload, units and rail, and the mapping to servo or thrust output;
- recipient, transport, port, and rate/QoS;
- acknowledgement and timeout semantics;
- **dead-man behaviour**: what happens on loss of the command stream, and the
  neutral value it falls back to;
- arming interaction, and why the bridge cannot arm;
- failure semantics and the fail-closed default;
- the explicit boundary preventing this path from ever addressing the real FCU
  without a separate approved gate.

Three constraints are already fixed by 07/08 measurement and are not open for
rediscussion:

1. **Address thrusters by SERVO function** (`73` left, `74` right), never by
   channel number.
2. **Read the PWM rail from live parameters.** Never hard-code one.
3. **Command at the RC or higher layer, not the raw servo layer.** The autopilot
   resolves function to channel internally, which removes the entire inversion
   class rather than documenting around it.

The contract must specify a **startup resolution guard** that makes the 07/08
mismatch structurally impossible to reintroduce. Before the bridge publishes
anything, it must:

1. read `SERVO*_FUNCTION` from the connected vehicle and resolve which channel
   carries `73` and which carries `74`, aborting if either function is
   unassigned;
2. read `SERVO<n>_MIN`, `SERVO<n>_TRIM` and `SERVO<n>_MAX` for exactly those two
   resolved channels, aborting if the rail is incomplete.

Neither value may come from a default, a constant, a configuration file, or an
observation of a different platform. If the vehicle cannot answer, the bridge
does not start. That is the whole defence: the channel numbers and the rail stop
being assumptions and become preconditions.

State the non-goals and the over-design traps avoided. Prefer existing contracts
and a narrow interface over a new abstraction.

## Block C - thrust telemetry on the Pi helper

Explicit approval required, and **read the cost before deciding**.

The browser dashboard gained a live thrust readout on 07/08/2026 from
`/mavros/rc/out`. The Pi helper's own terminal output has no equivalent. Bringing
the two to parity is the request that motivates this block.

**This is a pin-invalidating change**, and that is the decision, not the code.
Editing `tools/pi_live_hailo_mavlink_dashboard.sh` requires, measured on
07/08/2026:

| Surface | Occurrences | Action |
| --- | ---: | --- |
| `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` | `4` | update |
| `tools/test_live_dashboard_preflight.sh` | `3` | update |
| `tools/live_dashboard_preflight.sh` | `1` | update |
| four frozen working diaries | `9` | **leave untouched** |

Plus: re-transfer and re-verify the deployed Pi Desktop copy, and re-run
`tools/test_pi_live_hailo_mavlink_dashboard.sh` and
`tools/test_live_dashboard_preflight.sh`.

Constraints if it proceeds:

- Display only. The helper's view-only posture, `reject_command_services`,
  `reject_unexpected_command_subscribers` and `check_command_sentinel` are not
  touched, weakened, or bypassed.
- `/mavros/rc/out` is **not** one of the helper's five `COMMAND_TOPICS`, and
  `rc_io` is already in its MAVROS `plugin_allowlist`, so a read of that topic
  does not alter the safety surface.
- Raw PWM only. No conversion to a percentage, for the same reason the dashboard
  shows raw values: the rail differs between platforms.

A defensible outcome for this block is deciding **not** to change the helper and
recording why.

## Block D - the clean Pi-first lifecycle run, still owed

Explicit approval required. Needs the Pi, control box and browser.

The 07/08 run reached six-topic arrival, all six rate probes,
`COMMAND_SENTINEL=PASS messages=0` and `PI_SOURCE_WINDOW=COMPLETE`, but ended on
a **reversed shutdown order** - the workstation was stopped first, so the Pi
failed closed on a missing rosbridge and exited `status=1`. No normal-lifecycle
claim came out of it.

This block repeats it correctly. The only change is the stop sequence: `Ctrl+C`
in the Pi terminal, wait for `TEARDOWN=PASS` and `PI_SUPERVISOR_EXIT status=0`,
then the workstation, then close the browser.

Two method rules apply, both learned the expensive way on 07/08:

- The operator starts the workstation supervisor, so the compound Pi command
  appears on their own screen and is copied from that terminal. It is never
  relayed through an intermediate surface, which corrupts it silently.
- Confirm the new `Thrust` badge and the thrust readout show live values, which
  is the first opportunity to see the 07/08 dashboard work against real
  telemetry.

## Block E - optional, SITL to VRX bridge first run

Explicit approval required. Workstation-only, no boat, no Pi.

`tools/servo_command_bridge.py` has never run against any autopilot. SITL now
exists, and the docstring carries corrected values. Guards: Pi stack down, and
an isolated `ROS_DOMAIN_ID` - the workstation default is the Pi's live domain
and must not be used.

Echo **both** thrust topics together. Disarmed, both must read `0.0` N; that
phase tests the rail and **cannot** detect a channel swap. Then apply an
**asymmetric** input: a symmetric impulse drives both sides identically and looks
the same whether or not the channels are inverted.

## Open items carried in

- `tools/servo_command_bridge.py` parameter defaults remain internally
  inconsistent - the real boat's channels paired with a rail belonging to
  neither platform. The docstring says so. **Decided 07/08/2026: leave them.**
  Flipping them to SITL-shaped would substitute one set of implicit assumptions
  for another and could make a wrong model look correct by accident. They stay
  as historical reference; correctness comes from the Block B contract reading
  live values, not from a better default.
- MAVProxy's NumPy import wall and `Aborted (core dumped)` exits are **fixed as
  of 07/08/2026**. Cause: `mavproxy.py:50` imports `matplotlib`, which resolved
  to the system `3.6.3` built against NumPy 1.x while the venv carries NumPy
  `2.5.1`. Note the trap - because the venv was created
  `--system-site-packages`, a plain `pip install matplotlib` reports
  "Requirement already satisfied" and does nothing. The working command was
  `~/venv-ardupilot/bin/pip install --ignore-installed matplotlib`, which put
  `matplotlib 3.11.1` inside the venv. System `matplotlib 3.6.3`, `numpy 1.26.4`
  and `scipy 1.11.4` are untouched and still mutually consistent, and
  `mavproxy.py --help` now runs clean with no traceback.
- The graph-query workstream stays parked, not closed. Flag-off control counts
  are `11`, `3`, `2`, `10`.
- Task 2 remains retired.

## Acceptance

- Block B produces a written contract, not code.
- Block C produces either a helper change with every live pin surface updated
  and both suites green, or a recorded decision not to change it.
- Block D produces a clean Pi-first lifecycle run, or records exactly why not.
- Block E, if run, records the rail and mapping observed at neutral and under an
  asymmetric input.

## Non-claims to retain

- A working SITL says nothing about the real boat. Autopilot instance, rail,
  wiring and interlocks all differ.
- No command has reached a real autopilot. Real-controller work is governed by
  the tiered gate recorded in `Board.md` as of 09/08/2026; none of its tiers is
  authorized by this file, and each requires separate approval. Real-boat thrust
  stays behind a propellers-removed bench condition, hull restraint and isolated
  propulsion power. Note that `ARMING_CHECK=0` on this vehicle, so autopilot
  pre-arm checks are **not** a safety layer; `ARMING_REQUIRE=1` only means output
  requires arming, it does not screen it. The Cube safety switch is a
  conditional firmware guard rather than physical isolation: `BRD_SAFETY_DEFLT=1`
  only sets the startup default. The repository carries no recorded reading of
  the current safety state, `BRD_SAFETY_MASK` or `BRD_SAFETYOPTION` for this
  vehicle as of 09/08/2026.
- The dashboard contains no FCU command code, and
  `LIVE_MAVLINK_VIEW_ONLY` remains `true` at `web_dashboard/autoboat/app.js:263`,
  asserted literally by
  `web_dashboard/autoboat/test/mavlink_telemetry.test.js`.

**Next steps:** certify, then Block B. The contract is the gate on everything
downstream.

## Block B executed - command-ingress contract, design only (10/08/2026)

Block B was explicitly approved after the read-only certification. This section
is a design record only. No command bridge was implemented, no parameter was
written, no simulator or service was started, and nothing contacted the Pi,
control box or real controller.

The source basis is the pinned ArduPilot `Rover-4.6.3` checkout at `3fc7011a` and
the current repository at `6d973ec`. Source-derived behaviour below is kept
separate from the 07/08/2026 SITL observation.

### Forward correction - the startup guard has two layers

The pre-diary's lines 96-109 use the output servo rail as though it were the
input rail for an RC-layer command. That is incomplete and is superseded by this
correction.

`SERVO*_FUNCTION` still answers an essential output question: which physical
outputs carry `ThrottleLeft` (`73`) and `ThrottleRight` (`74`). Their
`SERVO<n>_*` values describe output observation. They do **not** select or scale
an `RC_CHANNELS_OVERRIDE` input.

The ingress side is independent:

- live `RCMAP_ROLL` selects Rover's steering input;
- live `RCMAP_THROTTLE` selects Rover's throttle input;
- the corresponding live `RC<n>_MIN`, `_TRIM`, `_MAX`, `_DZ` and `_REVERSED`
  values define the raw input PWM that produces each normalized RC demand.

This separation is already visible in the 07/08 result: RC input `1600`
produced servo output `1570`. There is no PWM passthrough. The corrected startup
guard therefore resolves both layers and never uses one layer's rail for the
other.

### Contract status and scope

This is command-ingress contract `v1`, limited to an explicitly isolated
ArduRover SITL instance on the workstation. It is not a real-controller
contract.

The future implementation is one separate bridge process. It is not an edit to
`tools/pi_live_hailo_mavlink_dashboard.sh`, the browser dashboard, or
`tools/servo_command_bridge.py`. The existing Python bridge remains the opposite
`FCU/SITL -> VRX` direction and its executable defaults remain unchanged.

The contract owns only a normalized steering/throttle stream and exclusive use
of the two resolved RC override inputs. It does not own arming, mode selection,
parameter writes, physical thrust estimation, the RC receiver, or the output
mixer.

### Upstream payload and ROS 2 delivery

The bridge accepts one atomic `sensor_msgs/msg/Joy` frame on
`/command_ingress/rc_axes`. Reusing this standard paired-axis message avoids a
new interface package while keeping the two axes in one sample.

The payload is exact:

| Field | Contract |
| --- | --- |
| `header.frame_id` | literal `uvautoboat/rc_axes/v1` |
| `axes[0]` | steering, dimensionless, finite, `[-0.8, +0.8]` |
| `axes[1]` | throttle, dimensionless, finite, `[0.0, 1.0]` |
| `buttons[0]` | enable/dead-man, exactly `0` or `1` |
| Array lengths | exactly two axes and one button |

Positive steering means positive Rover steering input; with the required
`PILOT_STEER_TYPE=0` and non-negative throttle this is the clockwise/right
direction. Throttle `0.0` is the live RC neutral and `1.0` is the live positive
endpoint. Negative longitudinal throttle demand is deliberately absent from
`v1`; this does not promise that both mixed motor outputs stay non-negative.
Differential steering can still drive one side below neutral.

`header.stamp` must be non-zero and strictly increasing for the locked publisher,
but the safety watchdog uses the bridge's monotonic receive time rather than
assuming synchronized ROS clocks. The bridge locks the first valid publisher
GID from `MessageInfo.publisher_gid` and rejects a frame from any other publisher
until restart.

Both publisher and subscriber use `KEEP_LAST(1)`, `BEST_EFFORT`, `VOLATILE`, a
`150 ms` deadline and a `150 ms` lifespan, and the producer publishes at
`20 Hz`. Those QoS settings bound middleware retention; they do not prove that
an executor has not already taken a delayed sample. The subscription therefore
uses a dedicated non-blocking wait-set/executor with no other callbacks, and the
RMW message's received timestamp and reception sequence must be supported. The
callback only copies the newest sample and timing metadata. Immediately before
every MAVLink emission the bridge revalidates publisher GID, sequence, strictly
increasing header stamp, RMW receive age and monotonic callback age. Unsupported
timing, a clock discontinuity, a taken-but-delayed callback or a superseded
sample is rejected; only the newest sample with age strictly below `150 ms` can
influence output.

While `ACTIVE`, a gap reaching `150 ms`, a missed deadline, an invalid field
or `buttons[0]=0` enters the fault state defined below. Before `ACTIVE`, none of
those events can create demand. The sole handshake exception is that a valid
`buttons[0]=0` frame in `ARMED_NEUTRAL` primes or resets the required consent
edge; it still commands no motion. A publisher change invalidates readiness and
requires restart.

Contract `v1` fixes `ROS_DOMAIN_ID=42`. An unset, inherited or different value
aborts startup. This is operational isolation, not an anti-actuation claim: the
current repository has no path from `/wamv/thrusters/*` to an FCU command, so the
Pi helper may remain up. Domain `42` keeps bridge-side ROS traffic out of the live
domain, avoiding dashboard aborts and competing thrust publishers. The bridge
does not probe or control the Pi, and the helper does not know
`/command_ingress/rc_axes`.

The repository's current `/wamv/thrusters/left/thrust` and
`/wamv/thrusters/right/thrust` messages are **not** this payload. They are two
independent `Float64` values in newtons, with no atomic pair, timestamp, validity
period or calibrated inverse mapping to RC axes. `/cmd_vel` is also excluded: in
the current bridge it is optional output derived from servo feedback, not an
ingress. A future producer-side conversion is a separate contract and cannot be
invented inside this bridge.

No current repository node publishes this `Joy` contract and no launch file
wires it. A concrete interpreter that imports both the required ROS 2 modules
and `pymavlink` without the known NumPy/Matplotlib collision is also unproven.
Both are implementation blockers, not gaps to improvise around at runtime.

### Recipient, identity and transport

The `v1` transport is a direct MAVLink 2 TCP connection to instance `0` SITL
`SERIAL0` at `tcp:127.0.0.1:5760`. UDP `udpin` is rejected because pymavlink
keeps a set of UDP clients and writes to all of them; it is not a one-peer
session. A MAVProxy relay is also excluded. The SITL launch prerequisite uses
the pinned checkout, the `motorboat-skid` frame and `--no-mavproxy`. The same TCP
connection receives heartbeat, parameter responses, `RC_CHANNELS` and
`SERVO_OUTPUT_RAW`, sends the two permitted telemetry-rate requests, and sends
the override. Separate send and receive paths are forbidden.

One temporary operator path is the explicit exception to the single-link rule.
A separately approved, one-shot helper may connect directly to instance-0
`SERIAL1` at `tcp:127.0.0.1:5762`, with source system `254` and source component
`190`. It may send exactly one `MAV_CMD_COMPONENT_ARM_DISARM` arm or disarm
request to the locked non-broadcast target: `param1=1` for arm or `param1=0` for
disarm, `param2=0` so force-arm/force-disarm is impossible, and unused parameters
all zero. It waits for that request's `COMMAND_ACK`, reports it, and exits. It has
no mode, parameter, RC override, `MANUAL_CONTROL`, servo or motor-test operation.
No QGC, MAVProxy or general command console substitutes for this bounded helper.
Because `254` must differ from live `SYSID_MYGCS`, any RC override or
`MANUAL_CONTROL` from the operator identity is rejected by the source-system gate
even if the helper violates its own allowlist.

Loopback text alone is not the SITL boundary. Before connecting, a local
supervisor must prove all of the following from Linux process and socket state:

- the ArduPilot checkout is still exactly `3fc7011a`, and the executable at
  `/home/ghostzero/ardupilot/build/sitl/bin/ardurover` is `4,939,888` bytes with
  SHA-256 `569412d6843e6b1ecfd2cfd6106ea4f60559ff440100f3b6dca94a02bf750169`
  and contains the embedded `ArduRover V4.6.3 (3fc7011a)` identity;
- the new listener PID has that exact executable, the expected checkout working
  directory, a later recorded start time, `--model motorboat-skid`, instance
  `0`, and the instance-0 waiting `SERIAL0` listener on port `5760`;
- normally, exactly one established pair owned by the bridge reaches that PID;
  during a separately approved arm or disarm only, one additional recorded
  one-shot operator pair may reach `SERIAL1`, and it must close after its ACK.
  No other established client may reach any MAVLink listener owned by that PID.

The SITL TCP listeners bind beyond loopback and have accept backlogs, so the
socket census continues while the bridge is alive. An unapproved or queued peer,
an operator peer outside its bounded phase, listener/PID change, endpoint
reconnect, or connection from a non-loopback address is a latched fault.
Automatic reconnect is forbidden.

The bridge locks exactly one ArduPilot heartbeat source. The non-broadcast
`target_system` and `target_component` come from that source; live
`SYSID_THISMAV` must agree with the heartbeat system id. Live
`SERIAL0_PROTOCOL` and `SERIAL1_PROTOCOL` must both be `2`.

`SIM_SPEEDUP` must be exactly `1`, selecting a wall-clock-rate target;
`SIM_RATE_HZ` must be present, finite and positive. Configuration alone does not
prove the achieved simulated-time rate under host load. Before readiness, and
then continuously, the bridge compares FCU `time_boot_ms` progression with host
monotonic time over a rolling `2 s` window and requires a slope in `0.9..1.1`
with no regression. These simulation values corroborate the selected launch but
are **not** identity proof: simulation parameters can also be compiled on
hardware. Process, executable and socket provenance above form the positive SITL
boundary.

Sender discovery has one non-actuating bootstrap exception. After locking the
target heartbeat, the bridge chooses provisional source system `253`, or `252`
when the target heartbeat already uses `253`, with source component
`MAV_COMP_ID_ONBOARD_COMPUTER` (`191`). It may request only `SYSID_ENFORCE` and
`SYSID_MYGCS`. No response aborts. `SYSID_ENFORCE` must be `0`; the bridge then
changes the sender on the same TCP connection to the returned live
`SYSID_MYGCS` before any other parameter request, telemetry-rate command or
override.

From that point the MAVLink source system must equal live `SYSID_MYGCS`.
Component id is not an RC-override authorization boundary: ArduPilot checks only
the source system, and a wrong system is a silent drop. `SYSID_MYGCS` is
ownership, not authentication. Both live system identifiers must be exact
integers in `1..255`, must be distinct and must both differ from operator system
`254`; the bridge and operator source components must each differ from the target
component. Live `SYSID_ENFORCE=0` is also required so the separate operator
identity reaches its arm/disarm handler.

Every accepted override also refreshes ArduPilot's `SYSID_MYGCS` last-seen time.
The bridge can therefore mask loss of an operator GCS using the same system id;
the contract does not rely on GCS failsafe as a bridge watchdog and forbids a
co-owned GCS identity.

Exclusive ownership covers the resolved RC override state, not just the
`RC_CHANNELS_OVERRIDE` message. No other link or process may send
`RC_CHANNELS_OVERRIDE` or `MANUAL_CONTROL`, and onboard DDS and Lua override
producers must be disabled. This is an operator/process prerequisite supported
by the socket census and live guards; MAVLink cannot prove global writer
exclusivity by itself.

### Startup resolution guard

State starts at `UNRESOLVED`, with no RC override output. The bridge requests the
bounded guard set by exact name with `PARAM_REQUEST_READ`: every required live
global value named below, `RC1_OPTION` through `RC16_OPTION`, and
`SERVO1_FUNCTION` through `SERVO16_FUNCTION`. After the mappings are known, the
set expands with the two resolved RC rails and the two resolved servo rails. Two
complete rounds must return identical values from the locked target. Each round has a `30 s`
deadline; an individually missing value may be retried once after `2 s`. No
cached parameter file, launch value, default, constant or other vehicle's value
is accepted as the observed value.

All channel numbers, system identifiers, enum/function values, option masks,
reversal values and PWM/dead-zone parameters must be finite exact integers before
range checks or serialization. RC and servo `MIN`/`TRIM`/`MAX` must be within
their documented `800..2200` domain. RC dead zones have documented domain
`0..200`, but `v1` requires `1..200` so its zero-demand application probe is
distinct from trim.

Every condition below must pass together:

1. `SYSID_THISMAV`, `SYSID_MYGCS`, `SYSID_ENFORCE`, `SERIAL0_PROTOCOL`,
   `SERIAL1_PROTOCOL`, `SIM_SPEEDUP` and `SIM_RATE_HZ` pass the identity/time
   checks above.
2. `RCMAP_ROLL` and `RCMAP_THROTTLE` are present, distinct and each in `1..16`.
3. For both resolved RC channels, `RC<n>_MIN`, `_TRIM`, `_MAX`, `_DZ`,
   `_REVERSED` and `_OPTION` are present. `_OPTION` must be `0`, `_REVERSED`
   must be `0` or `1`, and the rail must satisfy
   `MIN < TRIM-DZ < TRIM+DZ < MAX`.
4. Neither resolved RC channel equals live `MODE_CH`. Across `RC1_OPTION`
   through `RC16_OPTION`, none may be `46`, because that switch can disable and
   clear every override.
5. `RC_OPTIONS` bits `0` and `1` are both clear: the receiver is not ignored and
   MAVLink overrides are not ignored. Other set bits are recorded explicitly.
6. `PILOT_STEER_TYPE` is exactly `0`, `FRAME_CLASS` is the Boat value `2`, the
   exact output functions `73`/`74` establish skid steering, and the continuously
   observed mode is `MANUAL`.
7. `ARMING_RUDDER`, `FS_THR_ENABLE`, `FS_THR_VALUE`, `FS_TIMEOUT`, `FS_ACTION`,
   `FS_OPTIONS`, `FS_GCS_ENABLE` and `FS_GCS_TIMEOUT` are present and recorded.
   When throttle failsafe is enabled, every PWM the `v1` throttle range can emit
   must stay above `FS_THR_VALUE`. The bridge does not rewrite any failsafe.
8. `RC_OVERRIDE_TIME` is live, finite, greater than `0` and no greater than
   `0.5 s`. Zero disables overrides; a negative value never expires. The bridge
   never changes this parameter and never uses a temporary zero as teardown.
9. `SCR_ENABLE` is `0`, excluding Lua override producers. The exact pinned
   binary above contains no `AP_DDS` client and exposes no `DDS_ENABLE` parameter;
   a different binary or a target that exposes DDS is outside `v1` and aborts.
10. `SERVO_32_ENABLE` is `0`, so outputs `17..32` and their second raw-output
    bank cannot hide a duplicate assignment. Across `SERVO1_FUNCTION` through
    `SERVO16_FUNCTION`, exactly one channel carries `73` and exactly one carries
    `74`. Missing or duplicate assignments abort.
11. Both resolved servo channels are in the observable `1..16` range and have
    complete live `SERVO<n>_MIN`, `_TRIM`, `_MAX` and `_REVERSED` values, with
    `MIN < MAX`, `MIN <= TRIM <= MAX` and `_REVERSED` equal to `0` or `1`.
12. The target is freshly observed disarmed; both resolved receiver inputs are
    freshly at their live trims before any override; domain `42` has exactly the
    locked command publisher; and the process/socket exclusivity prerequisites
    above pass.

The source-default `RC_OVERRIDE_TIME` for the known `motorboat-skid` instance is
`3.0 s`, so the current SITL cannot pass item 8. A separately approved launch
preconfiguration, read back live as at most `0.5 s`, is a runtime prerequisite.
It was not created or applied in this block. Even after such preconfiguration,
the live response remains the only accepted value; a launch overlay is never a
substitute for resolution.

The bridge never sends `PARAM_SET`, and the isolated run permits no other
parameter writer. While ready or active it also completes a rolling
`PARAM_REQUEST_READ` comparison of every guarded parameter at least once per
`2 s`; a missing response or difference invalidates readiness.

Any missing, duplicate, invalid, stale or target-mismatched value aborts startup.
After neutral transmission has begun, a missing, stale or changed rolling
guarded-parameter response, or vehicle-time regression/reboot, enters
`CONFIG_FAULT`; cached channels and trims are no longer described as neutral. If
the original target, link and process identity are still intact, the bridge sends
only three channel-aware clear frames for the last resolved override fields and
then stops output. If target, endpoint, heartbeat source or process/socket
provenance changed, it closes the connection without transmitting to the
unproven peer. Both paths require external disarm and restart. A ROS publisher
change latches a restart-required fault while the still-valid FCU guard permits
neutral hold. No state survives reconnect and there is no partial re-resolution.
A mode change uses the separate mode-fault path below.

### RC encoding and MAVLink emission

No inherited `SERIAL0` stream rate is trusted. Before any override, the bridge
may send exactly two non-persistent `MAV_CMD_SET_MESSAGE_INTERVAL` requests on
this link: message `65` (`RC_CHANNELS`) and message `36`
(`SERVO_OUTPUT_RAW`), each at `10 Hz`. Both require an accepted `COMMAND_ACK` and
an observed maximum inter-arrival of `250 ms` for `2 s`; failure aborts startup.
No `REQUEST_DATA_STREAM` is allowed because Rover persists that rate change.

The bridge converts each normalized axis independently using that axis's live RC
rail. Let `u` be the contracted normalized demand and let `d = -u` when
`RC<n>_REVERSED=1`, otherwise `d = u`:

```text
d == 0: pwm = TRIM
d >  0: pwm = TRIM + DZ + d * (MAX - TRIM - DZ)
d <  0: pwm = TRIM - DZ + d * (TRIM - DZ - MIN)
```

For `d > 0` the continuous result is rounded down; for `d < 0` it is rounded up.
Quantization therefore stays toward trim rather than increasing demand. Before
serialization the bridge decodes the selected integer with Rover's exact
integer arithmetic and rejects it unless the resulting steering magnitude is at
most `3600`, below the strict greater-than-`4000` rudder-arm threshold. This is
the inverse of RC input normalization, not a servo-output or thrust conversion.

Every `RC_CHANNELS_OVERRIDE` frame carries both resolved channels atomically at
`20 Hz`. All other channel fields are `65535` (`UINT16_MAX`, ignore). MAVLink 2
is mandatory because an `RCMAP_*` result may be above channel 8.

Before external arming, the bridge proves application by its configured sender
with a zero-demand transition. Starting from a fresh pre-override effective RC
echo at both trims, it sends each resolved channel at `TRIM+DZ`, observes that
exact pair in `RC_CHANNELS`, returns to both trims, and observes the return. The
dead-zone boundary decodes to zero demand, but the distinct raw pair proves that
this override was applied rather than silently dropped. It does not by itself
prove the wrong-sysid rejection branch. Failure aborts without arming. After this
probe the bridge keeps sending both trims while disarmed.

Neutral is the two live RC `TRIM` values. A field value of zero is **not**
neutral. For channels 1-8 it clears override selection; for channels 9-16 both
zero and `65535` mean ignore, and the clear value is `65534`. Receiver input is
then used only if it is available under the live RC configuration. Channel-aware
release is used only after the teardown conditions below pass, except for the
explicitly non-neutral `CONFIG_FAULT` emergency clear.

ArduPilot owns the skid-steer mixer, function-to-output mapping, saturation,
slew and motor limits. The bridge does not invert the existing left/right thrust
mix and does not claim raw RC PWM, servo PWM or physical newtons are equivalent.

### Acknowledgement and feedback

`RC_CHANNELS_OVERRIDE` is an ordinary MAVLink message with no `COMMAND_ACK`.
Transmission success is therefore not an FCU-acceptance acknowledgement. The
two telemetry-rate commands have their own startup ACKs; those ACKs say nothing
about later override frames.

The contract keeps three evidence levels separate:

1. local serialization and socket send succeeded;
2. a fresh `RC_CHANNELS` message from the locked target shows the effective
   steering and throttle PWM matching a pair in the bridge's timestamped
   `500 ms` transmit history;
3. a fresh `SERVO_OUTPUT_RAW` message with `port=0` contains both
   function-resolved channels, and both values are within their live servo rails.

Level 2 is indirect application evidence; level 3 is output observation. Neither
is a per-frame protocol ACK or proof of physical thrust. Another writer sharing
`SYSID_MYGCS` would also make ownership ambiguous, which is why exclusive
override-writer ownership is a precondition.

Mapping acceptance compares each output only after decoding it through its own
live servo rail. For `pwm > TRIM`, demand is
`(pwm-TRIM)/(MAX-TRIM)`; for `pwm < TRIM`, demand is
`(pwm-TRIM)/(TRIM-MIN)`; at trim it is zero. A zero denominator on the demanded
side is an acceptance failure. The sign is then negated when that channel's live
`SERVO<n>_REVERSED` is `1`. This direction-normalized value is used only to
compare the two function outputs; it is not displayed as thrust or claimed as a
physical percentage.

`SERVO_OUTPUT_RAW.port=1` reuses the field names for outputs `17..32` and is never
accepted as evidence for `1..16`. While active, heartbeat age must stay below
`2.5 s`, and both accepted feedback types must stay below `500 ms`. A received
RC pair that matches no pair sent during the preceding `500 ms`, heartbeat age
reaching `2.5 s`, or either feedback age reaching `500 ms` immediately latches
the applicable fault; there is no second grace period.

Before the first non-neutral command, the bridge must already be transmitting
both RC trims, observe the post-probe RC return to those trims, and, after
external arming, observe both resolved servo outputs at their live trims within
`2 s`. The distinct dead-zone probe above, not the trim echo alone, is the
application evidence for the configured sender.

### Arming and mode boundary

The bridge contains no arm, disarm or mode-change path and sends no `SET_MODE`,
parameter write, servo command or motor-test command. Its only `COMMAND_LONG`
allowlist is the two non-actuating message-interval requests above. After the
startup probe it may emit only the atomic trim pair or a channel-specific release
while disarmed; no upstream demand can affect those frames.

An external, separately authorized operator may arm SITL only after the raw
dead-zone probe has passed, the trim override is continuous, and a fresh
`RC_CHANNELS` sample reports both trims. The transition moves the bridge only to
`ARMED_NEUTRAL`. Activation then requires a valid post-arm frame with
`buttons[0]=0` followed by a fresh `0 -> 1` edge from the same publisher. A
producer holding enable high through arming cannot activate the bridge, and no
pre-arm or buffered demand survives.

The permanent decoded `|steering| <= 3600` bound prevents the bridge from holding
the greater-than-`4000` steering input that Rover's rudder-arm/disarm path
requires. Mapped `RC<n>_OPTION=0` removes the other input-channel side effect.

Unexpected disarm or an armed target at initial discovery erases demand and
latches a fault. A mode other than fresh `MANUAL`, or loss of fresh mode
observation, enters `MODE_FAULT`: the bridge erases demand and sends the RC trim
pair as a best-effort input clamp, but makes no neutral-output claim because
non-Manual modes need not use pilot RC input. `MODE_FAULT` requires external
disarm. No fault can resume while armed; restart begins from fresh disarmed
resolution.

### Dead-man, failure and teardown semantics

There are three different loss mechanisms and they must not be collapsed:

- **Command-stream loss while the bridge and MAVLink link are alive:** when the
  gap reaches `150 ms` without a valid enabled frame, the bridge immediately
  replaces both demands with their live RC trims and keeps transmitting that
  atomic neutral input pair at `20 Hz`. With fresh `MANUAL` mode this is
  `NEUTRAL_HOLD`; the fault latches and fresh commands do not resume motion.
- **Mode loss or non-Manual mode:** this is `MODE_FAULT`, not neutral hold. The
  bridge sends the same best-effort trim input clamp, but the active mode may
  continue producing motor output independently. External disarm is required.
- **Bridge crash or MAVLink-link loss:** no process remains to send neutral.
  `RC_OVERRIDE_TIME` is evaluated only when ArduPilot processes new receiver
  input or another override. Without such an event, the last decoded control can
  persist beyond the configured time. If reevaluation occurs, receiver use still
  depends on receiver availability and `RC_OPTIONS`; there is no unconditional
  authority transfer or neutral-output guarantee.

`RC_OVERRIDE_TIME` is therefore a conditional validity timeout, not the neutral
dead-man. Receiver values plus the recorded `RC_OPTIONS`, throttle-failsafe and
GCS-failsafe parameters govern later behaviour. Override traffic itself refreshes
GCS last-seen time. A true vehicle-side fail-neutral guarantee would require
additional verified receiver/failsafe behaviour or a different higher-layer
ingress; neither is established by this block. Process-loss transfer and its
timing remain a required discriminating SITL acceptance, not a source claim.

Failures in `UNRESOLVED` abort with no output. After the dead-zone probe begins,
publisher, payload, feedback or command-age faults enter `NEUTRAL_HOLD` only
while the entire FCU guard remains valid and fresh mode remains `MANUAL`;
otherwise they enter `MODE_FAULT` or `CONFIG_FAULT` as defined above. While the
link is alive, `NEUTRAL_HOLD` and `MODE_FAULT` do not release automatically.
Endpoint loss is reported without pretending that the dead bridge emitted a
fallback.

Graceful teardown is:

1. erase the last demand; in fresh `MANUAL`, enter `NEUTRAL_HOLD`, observe a
   fresh RC echo at both trims and `port=0` servo outputs at their live trims;
   in `MODE_FAULT`, send only the best-effort trim input clamp and make no output
   claim;
2. wait for an external operator to disarm and verify a fresh disarmed heartbeat;
3. send three atomic channel-specific release frames at `20 Hz` while disarmed;
4. send no further override, wait longer than the live `RC_OVERRIDE_TIME` plus
   `100 ms`, and continue observing fresh disarmed heartbeat;
5. record local release transmission and exit without claiming a release ACK or
   an observable internal released state.

If disarm never arrives, the process remains in the applicable hold/fault state
and reports the blocker. Missing feedback may force external disarm but makes
the teardown unclean. Release is never substituted for neutral while armed; the
armed clear in `CONFIG_FAULT` is an explicitly non-neutral emergency exception,
not a clean teardown.

### Explicit real-controller boundary

Contract `v1` accepts only the provenance-checked local instance-0 SITL process
and its direct `SERIAL0` bridge connection, plus the separately approved one-shot
`SERIAL1` arm/disarm helper exception. It rejects serial devices, UDP relays,
non-loopback peers, unmatched processes/binaries and targets reached through an
unproven endpoint. It has no real-controller transport profile and no runtime
option that can enable one.

The 09/08/2026 tiered gate remains unchanged. No tier was exercised or
authorized here. A future real-controller proposal requires its own approval,
live T0b reads, a separately reviewed transport profile, physical bench
conditions, and resolution of the process-loss receiver-transfer residual before
any actuating tier. A SITL result cannot satisfy those gates.

### Non-goals and avoided over-design

- No implementation, runtime, parameter change, arming or command occurred.
- No change to either pinned helper, the dashboard, or
  `tools/servo_command_bridge.py`.
- No direct raw-servo path, `MAV_CMD_DO_MOTOR_TEST`, Lua motor path, or other
  actuator mechanism is part of the contract. RC ingress is the selected design,
  not the only route firmware could expose.
- `MAV_CMD_DO_SET_SERVO` rejection for functions `73` and `74` is source-proven
  in `AP_ServoRelayEvents.cpp`; it has not been exercised in SITL.
- No inverse mixer, physical-thrust model, percentage conversion, multi-vehicle
  router, automatic parameter repair or custom ROS interface package is added.
- The Pi helper remains unchanged and view-only, but it does not know the new
  command topic. Domain `42` prevents operational graph and publisher collisions;
  helper shutdown is not a bridge prerequisite.

### Block B verdict

**Block B is closed only as a written design decision.** The pre-diary's fixed
count remains three constraints; the startup guard is a separate requirement,
now corrected into ingress and output layers.

It is not runnable in the known environment: the stock SITL timeout is `3.0 s`,
the required preconfiguration is neither approved nor present, the combined ROS
2/pymavlink interpreter is unproven, and no repository publisher implements the
new `Joy` payload. The bounded one-shot operator helper is also not implemented.
Implementation and runtime acceptance remain `NOT STARTED`.

The first later acceptance must prove every guard failure, exact RC
normalization/quantization, the dead-zone application probe, a separate
wrong-sysid no-effect test, channel-aware release, telemetry cadence and port
filtering, publisher/command-age watchdogs, the post-arm `0 -> 1` consent edge,
decoded rudder-arm bound, Manual neutral hold, Mode-fault non-claim, and actual
process-loss behaviour against SITL. Mapping
acceptance requires a positive-steering asymmetric input under positive throttle
and must observe decoded function-`73` demand exceed decoded function `74` using
each output's own live rail and reversal; raw PWM values are not compared across
unequal rails. A symmetric impulse or two neutral readings cannot establish it.
This contract is source-reviewed, not implementation-ready or runtime-proven.

Blocks C, D and E remain separately gated and have not started.

## Forward corrections - ROS publisher identity and the 07/08 lifecycle cause

### Block B publisher identity and interpreter

The installed Jazzy binding does not provide the callback identity used in the
contract above. `MessageInfo` is not importable from `rclpy.subscription`, and
the installed `_rclpy_pybind11` extension exposes source/received timestamps and
publication/reception sequence numbers but no `publisher_gid`. The per-message
publisher-GID lock at lines 316-340 is therefore not implementable as written.

Contract `v1` is corrected to a graph-level publisher invariant. Before accepting
the first sample and on a rolling check before output, the bridge must call
`Node.get_publishers_info_by_topic()` and require exactly one publisher on
`/command_ingress/rc_axes`. It locks that `TopicEndpointInfo.endpoint_gid` and
faults on a missing, additional or changed endpoint. Message acceptance still
requires increasing header stamps and supported RMW timing/sequence metadata.
This is an operational uniqueness check, not per-message attribution,
authentication or a claim that DDS graph propagation has no race. A stronger
identity guarantee would require a different payload or transport and is outside
`v1`; real-controller tiers remain excluded.

The interpreter blocker is also retired. After sourcing
`/opt/ros/jazzy/setup.bash`, the system interpreter imported `rclpy`,
`sensor_msgs.msg.Joy` and `pymavlink 2.4.49` together. The known ArduPilot-venv
NumPy conflict remains relevant, but this concrete ROS-side environment does not
reintroduce it. Block B remains **SITL-only, not implementation-ready and not
runnable in the known environment** because the timeout preconfiguration, bridge
implementation, command publisher and bounded operator helper remain absent.

### 07/08 lifecycle cause and Block D prerequisite

The 07/08 diary's claim that the workstation was stopped first is corrected
forward, without editing that frozen record. The copied logs establish this
sequence in local time:

| Time | Evidence |
| --- | --- |
| `16:11:44.708` | Pi reports the workstation rosbridge node missing |
| `16:11:57.653` | Pi exits `status=1 failed_phase=live-hold` |
| `16:11:58.752` | Workstation rosbridge accepts a new WebSocket client |
| `16:12:22.288` | Workstation supervisor records operator `SIGINT` |

Rosbridge was therefore alive after the Pi failure. Nineteen seconds before the
fatal node-list miss, the same Pi log recorded a successful daemonless query with
publisher count zero for Pi-local `/mavros/rc/in`. The evidence supports a
transient incomplete graph snapshot, not workstation-first shutdown. The
rosbridge `user interrupted with ctrl-c (SIGINT)` line is not a discriminator:
the workstation supervisor starts child process groups with `setsid` and sends
`SIGINT` to them during every orderly teardown.

The helper now retries the complete workstation-node set for three snapshots,
records retry/recovery markers and still fails closed after three incomplete
results. Finite verification keeps its shared absolute deadline. Focused coverage
proves one-miss recovery, persistent three-snapshot failure and deadline handoff.
The runbook now judges stop order from the two supervisor lifecycle records.

No live service, browser, SITL or Pi process was started for this correction. The
helper edit invalidates the deployed Pi Desktop copy; transfer and Pi-side hash
verification remain operator-run prerequisites before any live test. Block C was
not started.

### Current operational pins after the correction

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `72,514` bytes | `19eaaef1a6147235705160abe5379915ff03e83f3ea553948ebe5b27ba38cc40` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `0a37ba04c7261225eadc7889a9169efcab5bbdc2b05808714b1350d4ea8d8f2b` |

The operational cascade is twelve pin occurrences: one helper hash in the
supervisor, three in `tools/test_live_dashboard_preflight.sh`, four in the live
runbook, the supervisor hash in both that test and the runbook, and the two
runbook size rows. All twelve were checked directly; focused suites alone do not
certify the unguarded documentation occurrences. Historical hashes in the four
frozen 04/08-07/08 diaries remain untouched, as do the original Block A pins at
the start of this diary. The Pi Desktop copy remains stale until the operator
transfers and verifies the new helper.

## Block C implementation and workstation-only SITL dashboard acceptance

The operator explicitly expanded today's authority to the complete workstation-only
SITL path: implement Block C, start Rover SITL, write the required simulator
parameters, arm, apply bounded thrust inputs, and observe the result in the web
dashboard. This did not authorize the Pi, control box, physical FCU or real
propulsion system; none was contacted.

### Block C result

Block C is implemented rather than closed as a no-change decision. The Pi helper
now treats `/mavros/rc/out` as its sixth MAVROS source identity, captures a full
`mavros_msgs/msg/RCOut` sample at initial and final verification, and prints the
raw channel list between `THRUST_OUTPUT_RAW_BEGIN` and
`THRUST_OUTPUT_RAW_END`. It performs no PWM percentage or physical-thrust
conversion. `reject_command_services`, `reject_unexpected_command_subscribers`,
`check_command_sentinel` and the five protected command topics are unchanged.

The workstation supervisor now includes `/mavros/rc/out` in arrival and rate
evidence, so the active pipeline covers seven publishers: the Hailo image plus six
MAVROS topics. Marker counts are derived from the array rather than duplicated as
a literal. The browser keeps the real-boat mapping as its default, but accepts
`thrust_left_servo` and `thrust_right_servo` query values after the operator has
resolved functions `73` and `74` from the connected vehicle's live parameters.
Invalid, duplicate or out-of-range values do not replace the default. The SITL
acceptance used:

```text
http://127.0.0.1:8002/?thrust_left_servo=1&thrust_right_servo=3
```

The helper edit invalidates the deployed Pi copy. This session did not transfer
or run it on the Pi.

### Workstation and runtime preconditions

- Repository revision before edits: `11460fc088b33853f1ed8ed1089b2c60c552d945`,
  with `HEAD == main == origin/main` and no ahead/behind count.
- Root filesystem: `24G` free at `88%` used.
- Workstation network: `10.120.2.168` on `wlp147s0`, SSID
  `IoT IMT Nord Europe`; the full workstation preflight passed.
- SITL binary: `4,939,888` bytes, SHA-256
  `569412d6843e6b1ecfd2cfd6106ea4f60559ff440100f3b6dca94a02bf750169`,
  embedding `ArduRover V4.6.3 (3fc7011a)`.
- SITL/MAVProxy ran from `/home/ghostzero/ardupilot` after activating
  `/home/ghostzero/venv-ardupilot/bin/activate`; no ROS setup was sourced in that
  shell.
- MAVROS and rosbridge used `/opt/ros/jazzy/setup.bash`,
  `ROS_DOMAIN_ID=42`, `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` and
  `ROS_LOCALHOST_ONLY=1`. The system interpreter imported `rclpy`,
  `sensor_msgs.msg.Joy` and `pymavlink 2.4.49` together.

### Live resolution and simulator writes

Before arming, the connected SITL instance returned exactly one assignment for
each thrust function:

| Output layer | Left | Right |
| --- | --- | --- |
| Output function | `SERVO1_FUNCTION=73` | `SERVO3_FUNCTION=74` |
| Servo rail | `1000/1500/2000`, reversed `0` | `1000/1500/2000`, reversed `0` |

The independent RC ingress resolved steering through `RCMAP_ROLL=1` and throttle
through `RCMAP_THROTTLE=3`. Both RC rails were `1000/1500/2000`, with dead zone
`30`, reversal `0` and option `0`.

`SYSID_MYGCS` was `255`. The stock values were
`RC_OVERRIDE_TIME=3.0` and `ARMING_RUDDER=2`. While disarmed, the simulator was
temporarily written to `RC_OVERRIDE_TIME=0.5` and `ARMING_RUDDER=0`; both live
read-backs passed before arming.

### Armed acceptance and dashboard evidence

MAVProxy reported `DO_SET_MODE: ACCEPTED` for `MANUAL` and
`COMPONENT_ARM_DISARM: ACCEPTED` for both arm and disarm. The headless browser
connected through the live rosbridge endpoint, subscribed to `/mavros/rc/out`
and rendered:

| Step | Browser left | Browser right | Delta |
| --- | ---: | ---: | ---: |
| Disarmed neutral | `SERVO1 1500` | `SERVO3 1500` | `+0` |
| Armed neutral | `SERVO1 1500` | `SERVO3 1500` | `+0` |
| `rc 3 1600` | `SERVO1 1570` | `SERVO3 1570` | `+0` |
| plus `rc 1 1600` | `SERVO1 1644` | `SERVO3 1496` | `+148` |
| explicit `rc 1 1500`, `rc 3 1500` | `SERVO1 1500` | `SERVO3 1500` | `+0` |
| final disarmed state | `SERVO1 1500` | `SERVO3 1500` | `+0` |

The asymmetric step establishes the SITL mapping in the dashboard: positive
steering increased function `73` on the left and decreased function `74` on the
right. The symmetric throttle step did not discriminate the mapping.

`rc all 0` did **not** neutralise the vehicle. More than the live `0.5 s` timeout
later, the dashboard still rendered `1644/1496`. This is direct runtime evidence
for the contract's distinction: zero releases RC override selection; it is not a
neutral command, and without a new receiver/input event the last output can
persist. Both live RC trims were therefore commanded explicitly before disarm.

After disarm, `rc all 0` released the neutral overrides. The two temporary
parameters were restored and read back as `RC_OVERRIDE_TIME=3.0` and
`ARMING_RUDDER=2`. The persisted `mav.parm` contains those original values.
The browser, dashboard server, rosbridge, MAVROS, MAVProxy and SITL then stopped;
no matching process or listener remained.

This proves the bounded simulator operator path and raw-PWM web display. It does
not implement or accept the production command-ingress bridge, does not run
`tools/servo_command_bridge.py`, does not exercise VRX, and says nothing about a
physical controller or motor.

### Verification and new operational pins

- `bash -n` passed for both operational shell files and both shell test files.
- `bash tools/test_pi_live_hailo_mavlink_dashboard.sh` passed.
- `bash tools/test_live_dashboard_preflight.sh` passed, `13/13` cases.
- all dashboard tests passed, `32/32`; `node --check` passed for `app.js`.
- the host-visible workstation preflight passed on the required SSID.
- `git diff --check` passed.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `73,862` bytes | `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97` |
| `tools/live_dashboard_preflight.sh` | `28,749` bytes | `c1490db8f7198a774fc21b3892415d654725e33d83b3680edb820bc9d2f259bf` |

All twelve current operational pin surfaces were updated: ten digest occurrences
and the two size rows. The earlier pins in this diary and every frozen diary
remain unchanged. The external weekly diary was not touched.

## Physical-FCU digital-twin implementation prepared

Later on 10/08/2026 the operator explicitly requested a web control/feedback
loop for a physical-FCU bench test. The supplied Pi transcript showed three
serial sessions on `/dev/ttyAMA0:57600`. Each received the vehicle `1:1`
heartbeat, but no requested parameter value was printed. The second and third
sessions reported the vehicle already `ARMED` in `MANUAL`, with arming checks
disabled. This is evidence of heartbeat reception only. It does not close T0b,
prove bidirectional request/response, or satisfy the disarmed startup condition
for T2a/T2b.

No repository process contacted the Pi or FCU during this implementation. No
parameter, mode, arming state, RC input or physical output was changed from the
workstation. The operator was told to disarm through the existing physical
control surface and isolate propulsion before any further test.

### Implemented path

`tools/real_fcu_rc_command_bridge.py` adds a default-inhibited MAVROS bridge:

- the browser emits one paired `sensor_msgs/Joy` frame on
  `/command_ingress/rc_axes`, with steering, non-negative throttle, enable and a
  strictly increasing timestamp;
- the bridge reads the connected target's live RC mapping, RC rails and exact
  output-function `73`/`74` assignments twice before it creates an
  `/mavros/rc/override` publisher;
- channel numbers and both RC and servo rails come only from those live MAVROS
  parameter responses;
- steering and throttle are converted through their own live RC rails and sent
  in one `mavros_msgs/OverrideRCIn` frame at `20 Hz`;
- `/mavros/rc/in` and `/mavros/rc/out` are read independently and returned as
  JSON on `/command_ingress/status`; the requested pair is never reused as
  measured feedback;
- the browser renders the request and measured raw PWM in separate rows and
  marks feedback stale after `500 ms`;
- the browser publisher exists only with
  `?enable_fcu_bench_control=1`; applying demand additionally requires a fresh
  ready status, fresh input/output feedback, the physical-condition checkbox
  and a continuously held button;
- a newly armed epoch requires a disabled frame before the first enabled frame,
  and loss of the enabled stream replaces both fields with their live trims;
- startup already armed latches `STARTUP_ARMED`; a later disarm cannot recover
  that process into a command-ready state.

The bridge has no arm, disarm, mode-change, parameter-write, motor-test or raw
servo-command route. Its configured limits cannot exceed `0.20` steering or
`0.12` throttle. It requires domain `42`, one command publisher, a fresh
disarmed `MANUAL` observation, both resolved RC inputs at live trim and
`RC_OVERRIDE_TIME` in `(0, 0.5]`. Channel-aware release is sent only after an
observed armed-to-disarmed transition; zero is not treated as neutral.

`config/mavros_real_fcu_digital_twin_plugins.yaml` is the minimal separate
MAVROS allowlist for this component: `sys_status`, `param` and `rc_io`. The
existing Pi helper remains unchanged and view-only. Its allowlist omits `param`
and its MAVProxy `udpout` route is not promoted into a command transport.

### Scope and unresolved runtime gates

This is prepared code, not physical acceptance and not a claim that the full
Block B `v1` contract is implemented. The first implementation deliberately
does not yet provide the contract's process/socket provenance census, rolling
two-second guard re-read, discriminating dead-zone application probe, GID-based
publisher identity or latched production fault state. Python Jazzy does not
expose the designed `MessageInfo.publisher_gid`, so this implementation uses
the narrower observable condition of exactly one ROS publisher. Those
differences keep the production-contract verdict unchanged.

The current physical path cannot start this bridge. Its blank parameter results
would fail the first MAVROS parameter request, and the recorded armed startup
would independently latch `STARTUP_ARMED`. A future physical test needs a
direct, bidirectional MAVROS serial route using the minimal allowlist, complete
live parameter responses and a disarmed neutral start before any arming phase.
No physical runner or acceptance result is recorded here.

### Verification

- `python3 -m py_compile` passed for the bridge and its focused test.
- `python3 -m unittest tools/test_real_fcu_rc_command_bridge.py` passed all nine
  tests, including function discovery, independent rails, override-time guard,
  quantization toward trim, channel-aware release, timestamp validation,
  failsafe range and live-neutral input resolution.
- `node --check web_dashboard/autoboat/app.js` passed.
- the focused dashboard telemetry test passed with the opt-in command contract,
  strict paired timestamps, fresh-status gate and requested-versus-measured
  rendering covered.

Full dashboard, YAML and repository-diff checks remain to be run before the
change is staged.

### Verification completion

The remaining local checks then completed:

- the complete dashboard suite passed `34/34`;
- `config/mavros_real_fcu_digital_twin_plugins.yaml` parsed and its allowlist
  resolved exactly to `sys_status`, `param`, `rc_io`;
- `bash tools/test_live_dashboard_preflight.sh` passed all `13` cases;
- `git diff --check` passed.

The physical FCU and Pi were not contacted by these checks. The implementation
remains prepared and unrun against physical hardware.

## Physical prototype stop-path correction

A later adversarial read found that the prepared prototype's two operator stop
paths were incomplete. The ordinary live-build invariant still blocked the
dashboard E-Stop, and the bridge did not subscribe to the E-Stop topic. The
default `rclpy` signal handlers could also close the ROS context before the
bridge's `finally` block published its neutral or release frames. No physical
run was attempted with that version.

The following corrections are now implemented:

- the opt-in bench URL creates a dedicated
  `/planning/emergency_stop` `std_msgs/Bool` publisher while mission,
  configuration and generic thrust-topic writes remain blocked;
- the main E-Stop, both shortcut buttons and a new button inside the expanded
  camera viewer all reach that same direct stop path without a confirmation
  dialogue;
- the browser stops the hold timer, emits disabled command frames and latches
  the E-Stop locally before publishing the stop message;
- the bridge subscribes to the E-Stop, clears the active demand immediately and
  publishes both live RC trims while the vehicle is armed;
- `SIGINT` and `SIGTERM` are handled outside `rclpy`, the publish timer is
  cancelled, and three neutral or channel-aware release frames are emitted
  before the ROS context is shut down;
- disarmed readiness is recalculated for every arming epoch, including a final
  fresh neutral RC-input check on the armed transition;
- empty, incomplete or out-of-rail `/mavros/rc/in` and `/mavros/rc/out` content
  is invalid and cannot enable a non-neutral command;
- the state timeout is `2.5 s` and the RC input/output timeout is `1.5 s`, which
  permits the measured one-hertz MAVROS streams without the earlier
  deterministic false trip. The browser's bridge-status limit remains
  `500 ms` because the bridge emits status at `20 Hz`;
- if readiness disappears while Hold to Apply is down, the interval stops and
  the final browser frames have `enable=0`.

An armed E-Stop or armed runtime fault deliberately holds the live trims rather
than releasing the override. The simulator acceptance above proved that
release is not neutral. Once the bridge stops, its final neutral frames remain
the last override until the live `RC_OVERRIDE_TIME` expires; after disarm it
uses the channel-aware release encoding directly.

The earlier pure-function-only test gap is also closed. The focused Python
suite now constructs the ROS node and exercises startup-armed silence, empty
feedback, the measured-rate state threshold, stale-state neutralisation,
per-epoch readiness and the immediate E-Stop branch. It passed `17/17` with DDS
restricted to isolated localhost domain `232`. The complete dashboard suite
passed `37/37`, including a dropped-readiness hold and direct E-Stop publication;
`node --check` passed. The MAVROS plugin YAML parsed to exactly `sys_status`,
`param`, `rc_io`; the preflight suite passed `13/13`; and both staged and
unstaged diff checks passed.

The operator-supplied Pi transcript remains heartbeat-only evidence: it printed
no requested parameter values and showed an already-armed vehicle. These
changes were verified locally without opening a Pi, browser, MAVROS serial link
or physical-FCU connection. No parameter, mode, arming state, RC override or
physical output was changed.

A final node-level test directly exercised `neutralize_for_shutdown()` while
armed and confirmed three live-trim frames. The isolated Python suite therefore
finished at `18/18`; the earlier `17/17` result above remains the preceding
checkpoint.

## Browser dead-man and onboarding correction

A same-page keyboard sequence remained open after the stop-path correction:
holding Space on Hold to Apply and then pressing Tab moved focus away without
delivering `keyup` to the button. The window stayed focused and the page stayed
visible, so neither existing fallback stopped the `50 ms` interval. The Hold
button now treats its own `blur` event as a release. A focused browser test
starts the keyboard hold, dispatches the focus loss and confirms that the
interval is inactive and the final command has `enable=0`.

The first-run onboarding backdrop also sat above the E-Stop controls and
received pointer events. It is now a visual-only layer with
`pointer-events: none`; the onboarding card remains independently interactive
above it. This keeps the header, floating and main E-Stop controls reachable
during every tour step. The README was also corrected to distinguish missing
parameters, which exit before publisher creation, from startup armed, which
latches `STARTUP_ARMED` and emits no override while the publisher remains
present. No Pi, browser service or physical-FCU link was opened for these
changes.

The focused dashboard file passed `17/17`; the complete dashboard suite passed
`39/39`; `node --check` passed; the preflight suite remained `13/13`; and
`git diff --check` passed.
