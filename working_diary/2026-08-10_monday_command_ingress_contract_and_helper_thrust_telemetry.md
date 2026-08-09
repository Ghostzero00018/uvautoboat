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
