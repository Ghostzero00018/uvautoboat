# Wednesday 26/08/2026 - full-scale FCU-to-VRX digital twin integration

**PRE-DIARY - NOT STARTED. NO APPROVAL CARRIES FROM 25/08/2026.**

This is the sole 26/08/2026 continuation. It was written at the close of
25/08/2026 as a plan. It schedules nothing, authorises nothing, and no physical
attestation, arming state, power state or repository approval from 25/08/2026
crosses the date boundary.

## Target

Drive the simulated boat from the real flight controller's own servo output,
with the full physical stack live and the propellers removed:

```text
Herelink input -> FCU mixer -> SERVO_OUTPUT_RAW
               -> Pi MAVROS   -> dashboard /mavros/rc/out
               -> Pi outbound-only fanout -> workstation UDP 14555
               -> isolated servo-command bridge -> VRX thrust and motion
Pi D435I -> Hailo overlay -> dashboard /hailo/overlay/image_raw
```

Acceptance requires correlated timestamps and values at every arrow, neutral
return, a live camera overlay, accepted disarm, restored hardware safety and
ordered teardown. A plausible-looking VRX motion with no correlated PWM at each
stage is not acceptance.

This is the only runtime topology for the day. Do not add a workstation-to-FCU
command relay, a second MAVProxy, direct servo writes or a parallel SITL. The
professor-repaired workstation command route is useful separate evidence, but
it is not required for the outbound FCU-to-VRX chain and is deferred from this
run.

## What 25/08/2026 established

- At the 25/08 close, `dd87527` was the last pushed baseline before this
  close-out set. `018bba0` added the opt-in `LIVE_FCU_TO_VRX_FANOUT` path;
  `dd87527` recorded the verified UART identity.
- The boat's FCU endpoint is `/dev/ttyAMA0:57600` on RP1 UART0. `/dev/ttyAMA10`
  is the Pi 5 debug UART and is not the FCU endpoint.
- Pi-to-FCU arm/disarm command delivery and the returned FCU acknowledgement are
  proven on that endpoint. The capture began already `ARMED`, so no fresh
  disarmed-to-armed transition is proven.
- The parameter-specific failure is unchanged. No parameter response and no
  mapping/rail artifact was captured, so T0b is not closed and T2a is not
  earned.
- The workstation-to-Pi-to-FCU route is operator-reported repaired and remains
  unproven. One correlated trace is still required.
- The fanout has never been run live. `TELEMETRY_FANOUT_TEST=PASS forward=1
  return=0` is a loopback subprocess test, not a live-link result.

## Three independent preconditions, none of them closed

1. **Full simulator acceptance has not been re-run on the current source.** The
   passing functional path, teardown, verdict and independent adjudication of
   17/08/2026 were earned against an earlier revision. Commit `2600ea4` later
   changed `tools/real_fcu_rc_command_bridge.py` and the dashboard data path.
   The 21/08/2026 work produced component and synthetic suite results only and
   recorded the complete supervisor rerun as NOT RUN; no later revision has
   received that complete run.
2. **T0b is not closed.** No successful parameter response and no mapping
   artifact exist for this controller.
3. **The default-off armed-observation selector is not implemented or tested.**

`Board.md` gates T2a on the first two preconditions and on a separate T2a
approval. The selector is an additional implementation prerequisite introduced
by this plan. Combining the T0b and T2a approval envelope would not itself close
T0b or exempt either the current-source simulator acceptance or selector
evidence. Each precondition remains open until its own evidence closes it,
unless an explicit operator supersession changes that requirement.

## Required armed-observation contract before runtime

`tools/pi_live_hailo_mavlink_dashboard.sh` aborts unconditionally when
`/mavros/state` reports `armed`. The full-scale target requires observing armed
servo output, so the current helper cannot complete the target unchanged.

The 26/08 implementation target is a default-off armed-observation selector,
covered by focused tests before any hardware starts. With the selector off, the
existing unconditional `FCU_ARMED` abort remains byte-for-byte in behaviour.
With it explicitly enabled, the helper must:

- reject an already-armed startup;
- first prove connected, disarmed, neutral telemetry and an empty command
  sentinel;
- observe but never issue arming, mode, RC, servo, mission or parameter writes;
- permit one bounded armed window only after the disarmed baseline;
- fail closed on a repository command topic, disconnect, stale required topic,
  deadline or unexpected armed state outside that window;
- accept completion only after neutral output, `armed=false`, restored hardware
  safety and ordered teardown.

This is a narrow lifecycle extension, not removal of the safety monitor. Do not
bypass it with an ad-hoc MAVProxy topology, a second command path or a monitor
disabled outside the reviewed implementation.

A disabled-arming-checks state was observed on 25/08/2026. Arming-check
configuration, propeller removal, hull restraint, control neutrality,
hardware-safety state and the exact propulsion-power state must each be declared
explicitly at session start. None may be inferred from any earlier capture.

## Blocks

Each block is a separate decision point and requires explicit approval to start.
Do not pre-mark a block in progress, and do not advance on a passing result
alone.

### Block A - certification, no hardware

```bash
git fetch --prune
git status --short --branch
git rev-parse HEAD origin/main
git rev-list --left-right --count main...origin/main
```

Require a clean worktree, `HEAD == origin/main`, divergence `0/0`. Then run the
offline suite gate and require it to exit `0`:

```bash
(
  set -eo pipefail
  source /opt/ros/jazzy/setup.bash
  source /home/ghostzero/seal_ws/install/setup.bash

  for s in \
    tools/test_pi_live_hailo_mavlink_dashboard.sh \
    tools/test_live_dashboard_preflight.sh \
    tools/test_real_fcu_digital_twin_helpers.sh \
    tools/test_sitl_digital_twin_runner.sh
  do
    echo "== $s"
    bash "$s" | tail -2
  done

  pytest -q tools/test_*.py | tail -1

  node --test --test-reporter=tap \
    'web_dashboard/autoboat/test/*.test.js' |
    awk '
      /^# (tests|pass|fail) [0-9]+$/ {
        print
        value[$2] = $3
      }
      END {
        if (value["tests"] != 80 ||
            value["pass"] != 80 ||
            value["fail"] != 0) exit 1
      }
    '
)
GATE_RC=$?
printf 'GATE_RC=%s\n' "$GATE_RC"
```

Use `set -eo pipefail`, not `set -euo`; the ROS setup script reads an initially
unset variable. Continue only with `GATE_RC=0`.

### Block B - offline armed-observation implementation

Implement the default-off contract above, add focused tests for both selector
states and rerun the complete offline gate. Correct the stale receive-only
sentence in the bridge module docstring in the same reviewed change. No Pi,
FCU, Herelink, camera, VRX, MAVProxy or hardware path runs in this block.

### Block C - fresh physical declaration and preflight

The operator states, in literal terms and without inference: propellers removed;
hull restrained; exact propulsion-power state; hardware-safety state; Herelink
powered with sticks neutral; arming-check configuration; FCU initially
disarmed; and Pi stack initially down. Confirm the workstation and Pi share the
expected network, serial ownership is free, UDP `14555` is free, domain `77` is
unoccupied, and no SITL or competing helper is running. No agent may supply,
infer or carry forward any part of the physical declaration.

### Block D - disarmed fanout and neutral arm/disarm

Start the one canonical fanout topology. With the vehicle disarmed, prove every
arrow at rest and confirm workstation UDP `14555` arrival before making a decode
claim. Read the live mapping and rails. Only after the disarmed chain is green,
use the established Herelink control to perform one neutral arm/disarm window;
do not move either stick. Require the Hailo camera overlay, neutral servo output,
zero VRX thrust, accepted disarm and restored hardware safety. This is the
neutral T2a evidence block.

### Block E - bounded armed observation

Only after Block D passes and after a separate T2b approval. Re-enter the same
canonical topology from a fresh disarmed baseline. Apply one short, low-amplitude
asymmetric Herelink stick movement, then return immediately to neutral. Require
correlated `SERVO_OUTPUT_RAW`, dashboard `/mavros/rc/out`, UDP `14555`, bridge
thrust and VRX motion, followed by neutral output, accepted disarm, restored
hardware safety and ordered teardown. Stop on any stalled observer, missing
correlation or value outside the live-read rails.

## What must be read live, never assumed

Read `SERVO*_FUNCTION`, `SERVO*_MIN`, `SERVO*_TRIM`, `SERVO*_MAX`,
`SERVO*_REVERSED` and `RCMAP_*` in the same session, before any bounded input.

The real boat records `SERVO3` as function `73` (ThrottleLeft) and `SERVO1` as
function `74` (ThrottleRight), with rails `800`/`800`/`2200` - neutral at the
**bottom**, so there is no reverse. Rover SITL is the mirror image on both
counts, and `tools/servo_command_bridge.py` defaults to `1100`/`1500`/`1900`,
which match neither platform. Emitting a mid-scale neutral at the real boat's
rail would represent roughly half thrust while the caller believed it commanded
zero. Never combine a channel mapping from one platform with a rail from the
other.

## Isolation

- Pi MAVROS, dashboard and safety monitor stay on `ROS_DOMAIN_ID=12`.
- VRX and `tools/servo_command_bridge.py` stay on a separate isolated domain
  with localhost-only discovery. Domain `77` was used and verified empty on
  25/08/2026; re-verify occupancy in the new session rather than assuming it.
- The Pi fanout ingress is `127.0.0.1:14556`, loopback-bound by design. The
  workstation ingress is `14555`. MAVROS keeps `127.0.0.1:14550`.
- The fanout is outbound-only and unfiltered raw MAVLink. What is enforced is
  direction and local ingress, not message class.
- Keep `publish_sensors:=false`. Outbound sensor injection is unsupported.

## Carried-forward source wording debt

`Board.md` now places an immediate 25/08 correction beside its historical 24/07
receive-only statement. One source docstring still says the direct serial link
"is currently receive-only": `tools/servo_command_bridge.py`. Block B corrects
that wording alongside the reviewed armed-observation implementation so source
and runtime claims move together.

Dated historical rows that describe a *powered receive-only diagnostic* are a
different meaning and stay frozen.

## Operator direction fixed on 25/08/2026

- The target is the complete outbound fanout through the bounded armed
  observation in Block E, not a disarmed-only finish.
- The workstation-to-Pi-to-FCU command trace is a separate diagnostic and is
  not inserted into this chain.
- Robustness comes from one supervisor-owned topology, default-off authority,
  focused tests, live-read mapping and rails, correlated observers, neutral
  return and ordered teardown. No bypass topology is an acceptable shortcut.

## Block A/B execution note - 26/08/2026

The opening repository certification passed at
`HEAD == origin/main == e140c5a`, divergence `0/0`, with a clean worktree before
the day's edits. The original offline gate also passed. No Pi, FCU, Herelink,
camera, MAVProxy, VRX or other hardware/live path ran.

Block B is now implemented offline. `LIVE_ARMED_OBSERVATION` defaults to `0`,
so the prior unconditional `FCU_ARMED` abort remains the default behaviour. The
enabled selector is accepted only with the outbound fanout enabled, the
indefinite hold disabled, and live-read left/right servo channels and trims
supplied explicitly. Its subscriber-only monitor requires the supervisor-owned
pre-ready latch plus fresh connected/disarmed telemetry, neutral output,
hardware safety ON and an empty command sentinel before it permits one bounded
armed window. It fails closed on an armed startup, a second arm, disconnect,
stale required telemetry, armed-window deadline, command publication, or a
missed connected/disarmed neutral and hardware-safe restoration deadline.

Focused tests were written and observed failing before the implementation. The
final focused result is `8 passed`. The existing Pi lifecycle suite also passes,
including the default-off path. The helper's governed subscriber-only checksum
pin was refreshed after the intentional source change to
`b0793bdac61595a2c5e85dafbc18806bde8146cecece4ae232846b51ae4b8cb0`.
The complete final offline gate passed:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=13
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
Python: 80 passed
Node: tests=80 pass=80 fail=0
GATE_RC=0
```

The stale receive-only bridge docstring and the live-dashboard runbook wording
were corrected in the same reviewed change. The selector remains **NOT RUN** on
the Pi or against any FCU. Of the three opening preconditions, only the offline
selector implementation/test prerequisite is now closed. Current-source full
simulator acceptance and T0b remain open.

Block C has not started. It still requires a fresh literal physical declaration
and separate approval. The intended continuation remains the real FCU/Pi/Hailo
stack feeding the real workstation VRX digital twin; no disarmed-only substitute
or simulator-only shortcut replaces Blocks C, D or E.

## Block B checksum correction - 26/08/2026

A post-gate review found that the workstation preflight, its focused test and
the live-dashboard runbook still carried the previous helper checksum even
though the current helper checksum was already recorded here and in the
real-FCU helper suite. The mismatch was fail-closed, but it would have stopped
Block C at the first helper-pin check.

The focused preflight test now reads the supervisor's helper pin and compares
it with the actual helper bytes. The new check first failed with the previous
pin and then passed after the runtime pin, printed Pi command assertions,
runbook manifest and copy-paste checks were updated to
`b0793bdac61595a2c5e85dafbc18806bde8146cecece4ae232846b51ae4b8cb0`.
The runbook helper size is also corrected to `90,518` bytes. Updating the
workstation preflight changed its checksum to
`dfa41732e5fc39572e9f927bf5c202aba3250c18e2372dc238b6d72212dc9372`;
the governed test and runbook manifest now carry that value.

The review also established three pre-enable stop conditions without relaxing
the selector: read `BRD_SAFETY_DEFLT` through the open T0b parameter check and
observe live hardware-safety state; read a stable disarmed `/mavros/rc/out`
pair and stop if it does not supply valid PWM trims in `800..2200`; and measure
the real-link cadence of every required monitor topic before changing the
default `5`-second freshness limit. Failure to reach the exact baseline remains
a stop, not a reason to widen acceptance.

The complete offline gate was rerun after the repair and passed:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=14
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
Python: 80 passed
Node: tests=80 pass=80 fail=0
GATE_RC=0
```

No Pi, FCU, Herelink, camera, MAVProxy, VRX or other live path ran during this
repair. Block C approval remains outstanding. The operator has confirmed that
the propellers are removed and has described the other hardware generally as
safe to operate. That partial statement does not establish the exact
propulsion-power state, hardware-safety state, Herelink power and stick state,
arming-check configuration, FCU armed state or Pi-stack state. Block C has not
started, and no live command is authorised.

## Block C approval - 26/08/2026

The operator explicitly approved Block C in the current session. This clears
the separate approval gate only. The propellers-removed state is confirmed;
the exact hull-restraint, propulsion-power, hardware-safety, Herelink power and
stick, arming-check, FCU armed/disarmed and Pi-stack states remain unstated.
Block C has not started, and its first live command remains blocked until that
fresh literal declaration is complete.

## Piece 1 VRX/bridge supervisor - offline implementation - 26/08/2026

The workstation-only Piece 1 implementation is now present at
`tools/fcu_to_vrx_workstation.sh`. It owns exactly two runtime children: the
`vrx_gz` `sydney_regatta` world and `tools/servo_command_bridge.py`. Both are
fixed to isolated ROS domain `77` with localhost-only discovery. The bridge
receives the Pi's outbound MAVLink copy on UDP `14555`; sensor injection and
`/cmd_vel` publication are explicitly disabled. This piece does not start or
own SITL, MAVProxy, MAVROS, a serial device, the Pi helper, rosbridge or the
dashboard.

The supervisor refuses to build the bridge command until both live-read servo
channels and both sides' live-read PWM rails are supplied. It rejects missing
or duplicate channels, invalid rails, unequal left/right rails that the current
shared-rail bridge cannot represent, and an invalid simulator thrust limit.
Production preflight additionally requires a clean checkout at `origin/main`,
an empty domain `77`, free UDP `14555`, the installed VRX topic/world contract,
and no conflicting simulator, bridge, SITL, MAVProxy or MAVROS process.

Focused tests were written before the supervisor existed and first stopped on
the missing file. A later empty-domain contract test first stopped on the
missing guard. The completed focused gate now reports:

```text
FCU-to-VRX workstation supervisor tests: PASS cases=12 runtime=not-started
Servo-command bridge PWM mapping: 2 tests passed
FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=12 python_tests=2 runtime=not-started
```

The process lifecycle test uses only temporary local child processes. It proves
separate process groups, bridge-before-VRX teardown, a free-UDP teardown
requirement, the success marker and unexpected-child-exit detection. The mapping
test directly characterises both the real-FCU-style bottom-neutral rail and the
bidirectional midscale rail without importing or starting ROS.

The complete offline regression set passes with the new suites included:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=14
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
FCU-to-VRX workstation supervisor: PASS cases=12 runtime=not-started
Python: 82 passed
Node: tests=80 pass=80 fail=0
```

A daemonless localhost-only environment probe also passed against the installed
workspace: domain `77` contained zero nodes, `vrx_gz` supplied the
`sydney_regatta` world and both WAM-V thrust topics, and `/usr/bin/python3`
imported `pymavlink` and `rclpy`. It reported `runtime=not-started`.

Two deliberate production-path failures were also confirmed without launching
runtime: an empty configuration stops on the first required live value, and a
complete example configuration stops at the clean-worktree gate while the
reviewed changes are uncommitted. No Pi, FCU, Herelink, camera, MAVProxy,
MAVROS, VRX, Gazebo or live network path ran during Piece 1.

The source recheck also corrects the session discussion about
`BRD_SAFETY_DEFLT`: `tools/real_fcu_digital_twin_pi.sh` first checks the live
hardware-safety bit and later explicitly rejects `BRD_SAFETY_DEFLT` unless its
value is `1` or `1.0`. Both checks remain unchanged.

Piece 1 is prepared offline, not accepted live. Block C approval remains scoped
to Block C, and the seven exact physical states listed above remain unstated.
Block D has no approval to start. Piece 2 - the armed-observation emitter path
and correlated observers required for Block E - has not started.

## Piece 1 review follow-ups - 26/08/2026

Two gaps found in the Piece 1 review were closed offline. Neither changes the
supervisor's runtime behaviour and neither is a live result.

The bridge parameter contract was fail-open. The workstation supervisor builds
eleven `-p name:=value` overrides for `tools/servo_command_bridge.py`, but no
test compared those names with the bridge's own `declare_parameter` calls; the
existing suite checked the constructed command against expected literals only.
An override whose name no longer matches a declaration is stored without being
applied, so the bridge would keep its own default. For `pwm_neutral` that means
a mid-scale `1500` against a bottom-neutral boat whose neutral is `800`, while
the supervisor's ready line still reports the live-read rails.

`tools/test_fcu_to_vrx_parameter_contract.py` now extracts the override names
from the argument vector the supervisor actually builds, extracts the declared
names from the bridge by syntax-tree walk, and requires every override to be
declared. It also pins the expected set of eleven names so an addition or
removal has to be deliberate. A second case renames one declaration in a
temporary copy and requires the check to reject it. The guard was confirmed to
fail against a renamed bridge before it was accepted as passing: the primary
case reports `pwm_neutral` as undeclared when the declaration is renamed. All
eleven names match the current bridge.

The runbook gained a start and stop order section. `W1` rejects any running
`gazebo` or `gz sim` process, so `W1` must start before `W2`; `W2` permits
`W1`'s rosbridge, web-video-server and dashboard processes. `W2` must also be
ready before the Pi starts, because `W1`'s `PI_DATA_ARRIVED` phase samples ROS
topics and does not prove UDP `14555` arrival. Teardown runs in reverse: Pi,
then `W2` bridge before VRX with `14555` confirmed free, then `W1`.

The complete offline gate passed after both changes:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=14
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS cases=12 runtime=not-started
Python: 84 passed
Node: tests=80 pass=80 fail=0
GATE_RC=0
```

No Pi, FCU, Herelink, camera, MAVProxy, MAVROS, VRX, Gazebo or live network
path ran. Block D has no approval to start and the seven exact physical states
remain unstated. Piece 2 has not started.

## Workstation check coverage correction - 26/08/2026

The bridge parameter contract test was reachable from the repository-wide
Python collection but not from the workstation supervisor's own `check` mode.
`fcuvrx_check` ran the shell suite and the PWM mapping tests only, so
`FCU_TO_VRX_WORKSTATION_CHECK=PASS` could be printed without the fail-open
override guard ever executing. That marker is the certification used by the
no-hardware workstation preflight, which is precisely where the guard matters.

`tools/fcu_to_vrx_workstation.sh` now also runs
`tools/test_fcu_to_vrx_parameter_contract.py` in `check`, and the marker
reports `python_tests=4`. The earlier `python_tests=2` line recorded above
remains as the historical result for the previous revision. Both unit files
were confirmed to execute in one `check` invocation, two tests each.

```text
FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=12 python_tests=4 runtime=not-started
```

The complete offline gate passed after the change:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=14
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS cases=12 runtime=not-started
Python: 84 passed
Node: tests=80 pass=80 fail=0
GATE_RC=0
```

Whitespace checks passed. No Pi, FCU, Herelink, camera, MAVProxy, MAVROS, VRX,
Gazebo or live network path ran. The helper deployed to the Pi Desktop is a
separate copy: its checksum must be computed from workstation bytes at the time
of use and reverified on the Pi after any transfer, rather than carried forward
from an earlier recorded value.

## Piece 2 offline implementation - 26/08/2026

Piece 2 started after the operator's explicit instruction. Its scope remained
offline implementation and tests only. No Pi, FCU, Herelink, camera, MAVProxy,
MAVROS, VRX, Gazebo, simulator acceptance or live network path ran.

The Pi command emitter in `tools/live_dashboard_preflight.sh` now carries the
armed-observation selector. The default remains unchanged:
`LIVE_ARMED_OBSERVATION=0`, `LIVE_FCU_TO_VRX_FANOUT=0` and
`LIVE_HOLD_AFTER_WINDOW=1`, so the helper's unconditional `FCU_ARMED` abort is
still active. The enabled form requires fanout, explicit max-window,
final-verification and staleness limits, both live-read channel numbers and both
complete min/trim/max rails. It emits `LIVE_HOLD_AFTER_WINDOW=0` and passes the
validated channel/trim values to the helper. No live rail or cadence value is
baked into the emitter.

Two read-only observers preserve the existing domain boundary. W1 starts a
domain-12 recorder only for the enabled armed-observation form; it subscribes
to `/mavros/state`, `/mavros/sys_status`, `/mavros/rc/out` and
`/hailo/overlay/image_raw`. W2 always starts a domain-77 recorder before the
bridge. `tools/servo_command_bridge.py` now publishes one structured
`/fcu_to_vrx/servo_output_raw` evidence message for each decoded UDP `14555`
frame before publishing left and right thrust. The W2 recorder subscribes to
that evidence topic, both thrust topics and `/wamv/pose`. Neither recorder
creates a ROS publisher or client.

`FCU_VRX_CORRELATED_OBSERVATION=0` leaves W2 in record-only mode for the first
disarmed measurement. Block E requires the selector to be `1` and requires an
explicit positive `FCU_VRX_OBSERVER_STALE_SECONDS` measured during Block D.
Once the first UDP servo frame arrives, a missing observer input must become
READY within that limit; after READY, any stale required input aborts the
observer. Teardown is now bridge, observer, VRX, followed by the existing UDP
`14555`-free requirement.

`tools/fcu_to_vrx_evidence.py adjudicate` joins the two workstation-clock JSONL
streams after teardown. It has no default acceptance thresholds. The caller
must supply the allowed PWM timestamp skew, thrust delay, motion delay and
minimum motion measured from Block D. It requires matching asymmetric PWM at
dashboard `/mavros/rc/out` and the UDP-decoded frame, the bridge's live-rail
mapping on both thrust topics, VRX motion above the supplied drift threshold, a
Hailo frame during the armed window, neutral return, connected disarm and
restored hardware safety. An observer abort, missing READY event, value drift
or missing/late stage is a failure. Downstream timing is anchored to the
bridge's UDP receive timestamp, so a valid run is not rejected when callbacks
from separate ROS topics are processed in a different order.

The focused tests were first confirmed red for the three absent contracts:
the emitter had no armed-observation variables, W2 built no observer command,
and the evidence module did not exist. The resulting passing and deliberate
failure coverage includes missing emitter values, missing W2 staleness,
dashboard-to-UDP PWM drift, insufficient VRX motion, missing final hardware
safety, observer abort, bridge parameter drift and ordered child teardown.

Current tracked pins after the implementation are:

```text
Pi helper:             b0793bdac61595a2c5e85dafbc18806bde8146cecece4ae232846b51ae4b8cb0 (90,518 bytes)
W1 supervisor:         642fddc1f8edb20b988e610bc71205fead7c54b4c874a3b351287a027ccab1d9 (35,812 bytes)
W2 supervisor:         01e4947140eefa3338390775ef357acbee68fa40e07020082f8fad1aaf5759ee (23,530 bytes)
correlation recorder:  341f2ae9ede40a6db4c287360b76e538f04bb753ec9ee55ed77a566908c1a07b (30,962 bytes)
servo bridge:          db8bddf558ceec7baec534800122c96cfc4a31653b37cd978bbdf00dcd3db034 (19,959 bytes)
```

The complete offline gate passed:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=16
real-FCU helper suite: PASS cases=24
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS shell_cases=14 python_tests=12 runtime=not-started
Python: 92 passed
Node: tests=80 pass=80 fail=0
SHELL_GATE_RC=0
GATE_REMAINDER_RC=0
```

Piece 2 is implemented and tested offline, not accepted live. The worktree is
uncommitted, so W2's clean-repository parity gate will refuse a runtime start.
The full current-source simulator acceptance through
`tools/live_dashboard_preflight.sh sitl` remains unrun. The seven exact physical
states remain unstated, Block D has no start approval and Block E still requires
its own later T2b approval.

## Piece 2 recorder finalization - 26/08/2026

Final review found that the first recorder implementation called `fsync` for
every topic event. That could add avoidable callback latency during the live
multi-topic capture. Event appends now flush and close without a per-event disk
sync, while observer teardown explicitly syncs the retained JSONL stream. The
atomic status-file writes keep their existing `fsync` because they are
low-frequency supervisor gates.

A focused regression was first confirmed red against the per-event behavior:
the append path made one unexpected `fsync` call. It then passed after the
finalization change and requires exactly one explicit sync when capture ends.

Current affected pins are:

```text
W2 supervisor:         6ad20b28b364cabb1175211f24e70f03738687d7b8dc2551a8b9b7d07c1c5f3e (23,530 bytes)
correlation recorder:  5c40d6376efc7456929ddf1e80454f3e17ff87c7530629a65f4c10ac0db361dc (31,069 bytes)
```

Affected offline checks passed:

```text
live-dashboard preflight: PASS cases=16
FCU-to-VRX workstation: PASS shell_cases=14 python_tests=13 runtime=not-started
Focused Python: 13 passed
Repository Python: 93 passed
```

The Pi lifecycle, real-FCU helper, SITL synthetic and Node results recorded in
the preceding section were not rerun because this finalization did not change
their inputs. No live service, simulator acceptance or hardware path ran.

## Piece 2 bridge import coverage - 26/08/2026

Review confirmed that the production bridge imports correctly when launched as
`python3 <absolute-script-path>`, but the offline suite previously parsed the
bridge without importing the module. A renamed or missing
`fcu_to_vrx_evidence.py` could therefore leave the suite green and stop W2 only
at runtime.

`tools/test_servo_command_bridge_mapping.py` now loads the real bridge in a
fresh Python subprocess. The probe sets the bridge directory at `sys.path[0]`
and uses a non-`__main__` run name, matching production module resolution
without starting the ROS node. This avoids a prior test module cache masking a
missing dependency.

The affected checks passed:

```text
bridge import and mapping: PASS tests=3
FCU-to-VRX workstation: PASS shell_cases=14 python_tests=14 runtime=not-started
Repository Python: 94 passed
git diff --check: PASS
```

The current W2 supervisor pin is
`981fba979e86d0e7a2e50c4d9c89b30b699b62b7a24343b4d315c819fb931091`
(`23,530` bytes). No live service, simulator acceptance or hardware path ran.

## Dashboard, simulator and Pi preflight acceptance - 26/08/2026

The published Piece 2 revision is
`3ca6b0ba43d078c8f69621fa38f17de3c8e8e657`. Local `HEAD`, `origin/main` and
the live remote ref matched with divergence `0/0`, and the worktree was clean.

The workstation one-shot preflight reported:

```text
W1_PREFLIGHT=PASS tests=dashboard,helper,preflight ports=8002,8080,9090
workstation_ipv4=10.120.2.168 dev=wlp147s0 ssid=IoT IMT Nord Europe
FCU_VRX_ENV_PREFLIGHT=PASS domain=77 nodes=0 udp=14555,14556-free
```

The current Pi helper was transferred to
`/home/imt-aqua-drone/Desktop/pi_live_hailo_mavlink_dashboard.sh` on Pi host
`imtaquadrone-desktop` (`10.120.2.249`). Its checksum matched
`b0793bdac61595a2c5e85dafbc18806bde8146cecece4ae232846b51ae4b8cb0`.
The one-shot Pi result was:

```text
HAILO_ROS_PREFLIGHT=PASS imports=5 monkeypatch=PASS publisher=RELIABLE
PREFLIGHT_ONLY=PASS hardware=camera,hailo,serial,fcu untouched
```

`CANONICAL_STRIPPED_RCLPY=UNAVAILABLE` was informational; the governed
provenance check subsequently resolved `rclpy` from ROS Jazzy and passed. After
a separate successful `sudo -v`, `sudo fuser -v /dev/ttyAMA0` printed no owner
and returned `FUSER_RC=1`.

The operator then completed the full current-source simulator/dashboard run at
`/home/ghostzero/Desktop/sitl_digital_twin_20260826_174115`. The supervisor
resolved `RC1`/`RC3` and `SERVO1`/`SERVO3`, completed every browser and operator
phase, and reported:

```text
SITL_ACCEPTANCE=COMPLETE teardown=pending
SITL_VERDICT=PASS
SITL_SUPERVISOR_EXIT status=0 cleanup_rc=0 finalize_rc=0
```

Independent adjudication checked ten evidence hashes, confirmed stop order
`dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl`, confirmed all
governed ports and processes free, and ended with
`SITL_ADJUDICATION=PASS`. The retained verdict records
`session_complete=true`, `cleanup_rc=0`, no capture fault and no missing
evidence.

This closes the current-source simulator acceptance precondition. It does not
prove the real FCU fanout or VRX path.

## Read-only live FCU probe approval and hold - 26/08/2026

The operator approved the read-only T0b probe. The current physical declaration
records: FCU and Pi powered; Herelink powered with sticks neutral; propellers
removed; hull restrained; hardware safety ON; FCU disarmed; Pi runtime stack
down; propulsion battery connected; ESCs powered. QGroundControl displayed
`ARMING_CHECK=None`, corresponding to no selected bitmask checks (`0`); the
probe must still read and retain the live parameter value before it is treated
as parameter evidence.

The approved probe has **NOT RUN**. The governed helper requires
`REAL_FCU_PROPULSION_ISOLATED=1`, while the declared propulsion battery and ESC
state is powered. Propeller removal does not satisfy that source gate. No flag
may be invented: the operator must physically isolate propulsion power and
state that new condition before the read-only probe command is issued. No
parameter write, arm, mode change, RC command, bridge launch or thrust is
authorized.

## Read-only probe propulsion isolation - 26/08/2026

The operator subsequently confirmed that the propulsion battery is
disconnected and the ESCs are unpowered, with every other declared physical
state unchanged. This satisfies the production probe's physical propulsion
isolation gate. The existing approval remains limited to the read-only T0b
probe; the probe is still **NOT RUN** pending clean repository publication,
deployed-bundle verification and Pi `check` mode. No parameter write, arm,
mode change, RC command, bridge launch or thrust is authorized.

## T0b attempts, disarmed fanout evidence and revised authority - 26/08/2026

The deployed four-file real-FCU bundle passed its checksum manifest and Pi
`check` mode. Two read-only `probe` attempts then failed closed. Run
`real_fcu_digital_twin_pi_20260826_175757` stopped when the MAVROS parameter
pull failed. Run `real_fcu_digital_twin_pi_20260826_175855` reached live state
and SYS_STATUS sampling but stopped because the observed hardware-safety bit
was not ON. Both helpers stopped their probe MAVROS child and exited nonzero.
The two complete run directories were copied to
`/home/ghostzero/Desktop/pi_run_evidence/t0b_20260826`; neither is a passing
T0b result.

The operator then used MAVProxy directly, explicitly released hardware safety,
armed once and disarmed once. ArduPilot accepted both requests and reported
`Arming Checks Disabled`, `Throttle armed` and `Throttle disarmed`. This proves
that the manual MAVProxy command path can change armed state with the current
configuration. It does not convert either failed helper run into a passing
probe. A subsequent MAVProxy FTP fetch returned `986` parameters and the saved
artifact was copied to the workstation. Its retained
`RC_OVERRIDE_TIME=3.0` is outside the bridge guard and is not valid for a
demand-enabled run.

The first three-part disarmed fanout attempt retained:

```text
W1=/home/ghostzero/Desktop/live_dashboard_workstation_20260826_183120
W2=/home/ghostzero/Desktop/fcu_to_vrx_workstation_20260826_183138
PI=/home/ghostzero/Desktop/pi_run_evidence/live_dashboard_20260826_183200
```

The Pi forwarder reported outbound-only readiness for
`10.120.2.168:14555`. W2 reached VRX, recorder and bridge readiness. Its
`3,585` retained events include repeated real `SERVO_OUTPUT_RAW` frames with
left `SERVO3=800`, right `SERVO1=800` and both mapped thrust values `0.0 N`.
W2 later reported ordered teardown and UDP `14555` free. This closes live
disarmed UART-to-fanout-to-UDP-to-bridge delivery at neutral only. It does not
prove asymmetric output, thrust or VRX motion.

W1 entered failure hold after a single daemonless workstation node snapshot
missed the required graph while its supervised children and ports remained
up. The Pi was nevertheless started later, reached
`PI_SOURCE_STACK_READY=PASS` and recorded Hailo frames `1`, `100`, ... `1900`.
Its final verification then received three publisher-count-zero graph views
and stopped automatically; teardown passed and the helper exited status `1`.
The Hailo process traceback is the `KeyboardInterrupt` produced during that
ordered teardown, not a preceding inference crash.

The earlier `/dev/hailo0 missing` preflight stop was independently repaired.
The current kernel was `6.8.0-1062-raspi`; its matching headers were installed,
DKMS built and installed `hailo_pci/4.24.0`, the module loaded, `/dev/hailo0`
appeared and `hailortcli fw-control identify` reported firmware `4.24.0` on
`HAILO8L`.

The operator then explicitly approved the source repairs, a temporary
`RC_OVERRIDE_TIME=0.5` value, a hash-pinned post-change MAVProxy snapshot, both
live armed tests and mandatory rollback to `RC_OVERRIDE_TIME=3.0`. The latest
physical declaration at that approval was: hardware safety ON, FCU disarmed,
propulsion battery disconnected, ESCs unpowered, Herelink sticks neutral,
propellers removed and hull restrained. These states must still be checked at
each live pipeline header because a later physical change invalidates them.

## Live graph recovery and parameter-snapshot implementation - 26/08/2026

The Pi helper now treats a run-owned Hailo process plus a fresh reliable
`sensor_msgs/Image` sample with `bgr8` encoding and height `240` as recovery
evidence only after three successful publisher queries all report exactly
zero. Query errors, a duplicate publisher or any other non-one count cannot
take that recovery path. The workstation supervisor independently retries its
complete three-node graph snapshot up to three times. Both changes retain
fail-closed exhaustion and add explicit recovery markers.

`LIVE_RUN_SECONDS` can now be passed through the workstation emitter. It is
optional and defaults to the Pi helper's existing value when omitted; an armed
observation can set a bounded value explicitly without hand-editing the
printed command.

The real-FCU bridge and Pi supervisor now support a default-off snapshot guard
for `run-t2a` and `run` only. The selector requires an absolute readable
MAVProxy parameter artifact, its exact lowercase SHA-256 and explicit snapshot
approval. The same bytes are parsed once, reject malformed or duplicate
entries and pass through the complete existing parameter guard. The Pi still
uses a read-only MAVROS probe to require current connected/disarmed state and
hardware safety ON before it copies the snapshot into run evidence. No
parameter write was added. The original live-pull path remains the default,
and `probe` remains live-pull-only.

The stored `RC_OVERRIDE_TIME=3.0` artifact was exercised against the new CLI
and correctly rejected:

```text
real_fcu_rc_command_bridge: RC_OVERRIDE_TIME must be in (0, 0.5], got 3.0
```

The new positive and negative coverage includes snapshot hash drift, parser
errors, unsafe timeout rejection, mode and approval selector failures,
snapshot/live bridge ordering, Hailo zero recovery, Hailo duplicate rejection,
workstation graph retry and emitter validation. The final serialized offline
gate passed:

```text
Pi lifecycle: PASS
live-dashboard preflight: PASS cases=17
real-FCU helper suite: PASS cases=27
SITL runner suite: PASS cases=41
FCU-to-VRX workstation: PASS shell_cases=14 python_tests=14 runtime=not-started
Python: 99 passed
Node: tests=80 pass=80 fail=0
```

Current publication pins are:

```text
Pi dashboard helper:       8458526c183479b1ca004dcbdfb3e498b585e415826025b4ee71b7856ecb311c
W1 dashboard supervisor:   2a272106b47f1b6988a01fe5f7fcc536e66aad3889b86c538b699a77e58cd90b
real-FCU Pi supervisor:    a9f10a34aecd4bab1952448803c0f95dea8f1b7648048f667e2e7a8a82c4b8ef
real-FCU command bridge:   31ac64d68138eee8b8bc15e47023ea1b70ec1c6ce17a38ad9130f6d444e649e3
```

The real dashboard-to-FCU command run and the armed Herelink-to-VRX motion run
remain **NOT RUN** at this checkpoint. Their authorization is recorded, but
runtime acceptance still requires a newly saved post-`0.5` snapshot, exact
transfer checks, the live physical declaration, the supervisors' readiness
markers, external disarm before teardown and the verified `3.0` rollback.

## Real-FCU Test A acceptance - 26/08/2026

The preceding **NOT RUN** statement remains the correct record for its
checkpoint. Later on 26/08/2026, Test A ran against the real FCU and passed.
This closes the bounded dashboard-to-FCU command-and-feedback test only; it
does not close the Herelink-to-VRX Test B.

The approved run used the hash-pinned `986`-parameter MAVProxy snapshot:

```text
snapshot=/home/imt-aqua-drone/Desktop/real_fcu_params_20260826_rc_override_0p5.parm
sha256=3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9
RC_OVERRIDE_TIME=0.5
steering=RC1
throttle=RC3
left=SERVO3, function=73, rail=800/800/2200
right=SERVO1, function=74, rail=800/800/2200
```

The initial physical declaration was hardware safety ON, FCU disarmed,
propellers removed, hull restrained, propulsion battery disconnected, ESCs
unpowered and Herelink sticks neutral. The operator released hardware safety
while disarmed at the helper's interactive gate and entered the exact
`RELEASED_DISARMED` confirmation. The Pi then reported:

```text
REAL_FCU_PI_READY=PASS tier=T2b authority=demand-enabled bridge=READY_DISARMED workstation=visible
```

The workstation independently reported:

```text
REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output
```

The retained screen recording shows the complete bounded command sequence.
At `ARMED_NEUTRAL`, requested steering/throttle were `0.00/0.00`, RC input was
`1515/1515 us`, and both measured outputs were `800 us`. While Hold to Apply
was pressed, the dashboard requested steering `0.05` and throttle `0.04`; the
bridge state became `ACTIVE`, measured RC input changed to `1564/1470 us`,
left `SERVO3` changed to `911 us` and right `SERVO1` remained `800 us`. Release
returned the bridge to `ARMED_NEUTRAL`, the request to `0.00/0.00`, and both
outputs to `800 us`. This is correlated dashboard demand, RC-layer command
delivery, real-FCU mixing/output feedback and neutral restoration. Propulsion
was isolated, so it is not a physical-thrust claim.

The video retained on the workstation is:

```text
path=/home/ghostzero/Videos/Screencasts/Screencast from 2026-08-26 20-15-16.mp4
sha256=e4ce7e9ba3f832769cb0cd151f8af28ae90e612db96afaec364dd55a321dc846
duration=6.381900 s
codec=H.264
frame=922x906
size=314543 bytes
```

The final closeout was clean on both supervisors. The Pi reported
`REAL_FCU_FINAL_STATE=PASS connected=true armed=false`, received the
workstation stop marker on `/real_fcu/workstation_stop`, stopped the bridge
before MAVROS and exited with `status=0 cleanup_rc=0`. The workstation reported
`REAL_FCU_WORKSTATION_FINAL_STATE=PASS connected=true armed=false`, stopped the
dashboard and rosbridge, published the stop marker and exited with
`status=0 cleanup_rc=0`.

The retained run directories are:

```text
workstation=/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260826_200922
pi-source=/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260826_201051
pi-copy=/home/ghostzero/Desktop/pi_run_evidence/test_a_20260826/real_fcu_digital_twin_pi_20260826_201051
```

The copied Pi directory contains the supervisor log, child logs, evidence and
manifest. Its supervisor markers and resolved snapshot/mapping were re-read on
the workstation, and the copied `guard_snapshot.parm` independently hashes to
`3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`.
The source-side artifact manifest contains absolute Pi paths, so the copy alone
is not represented as a byte-for-byte remote comparison.

## End-of-day handoff - 26/08/2026

Test A is **PASS**. Test B, the armed Herelink-to-FCU-to-UDP-`14555`-to-VRX
motion and correlation test, is **NOT RUN** and is deferred to 27/08/2026.

The final live-work source revision was clean and at `a5339b2` before this
documentation closeout. The current real-FCU runtime pins are:

```text
real-FCU workstation supervisor: 164c811bd870c5976c1dc017f802f675306f5e4404624a8f8d80a1d6d38db262
real-FCU Pi supervisor:          f716635814c8ed8516b3bf8844c7145e9f11a475b1c7bfe96e4576e0c890ccec
real-FCU command bridge:         31ac64d68138eee8b8bc15e47023ea1b70ec1c6ce17a38ad9130f6d444e649e3
real-FCU bundle manifest:        7fe4e1a3020322c0339547ec90bb9d0321a7cfae350d909b7f2d931c3165187e
```

`RC_OVERRIDE_TIME=0.5` remains the live temporary value solely for the deferred
Test B. It has not yet been rolled back. Test B must either run under a fresh
27/08/2026 declaration and approval or be abandoned; after either outcome,
restore `RC_OVERRIDE_TIME=3.0`, confirm the live readback and retain a separate
rollback snapshot. The final pasted Test A state proves software disarm but
does not independently restate the final physical hardware-safety position, so
that state must be declared fresh before any 27/08/2026 live action.

## Test B pre-run blocker found at closeout - 26/08/2026

Review of the retained W2 record-only run found a source/topic mismatch that
must be repaired before the armed correlated Test B. The observer was launched
with `--pose-topic /wamv/pose`, but the same run's VRX log records the actual
Gazebo-to-ROS bridge as:

```text
/model/wamv/pose (gz.msgs.Pose_V) -> /model/wamv/pose (tf2_msgs/msg/TFMessage)
```

The retained `vrx_status.json` stayed at `WAIT_DATA`. Its `3,585` events contain
`1,194` servo-output events and `1,195` events for each thrust side, but zero
pose events. The servo-output maximum observed inter-frame gap was about
`4.086 s`; that figure cannot certify the complete observer while pose is
absent.

Test B is therefore blocked before live start on a scoped pose-topic correction,
focused drift coverage, an offline gate and a workstation-only proof that one
matching WAM-V pose arrives. This finding does not change the Test A PASS.

## Final EOD closure audit - 26/08/2026

The final audit rechecked all closeout layers rather than treating the passing
browser video as the whole result.

Test A evidence is closed:

- both copied Pi and local workstation run directories are retained;
- the copied Pi supervisor again shows `REAL_FCU_PI_READY=PASS`, final
  `connected=true armed=false`, receipt of the workstation stop marker and
  `REAL_FCU_PI_EXIT status=0 cleanup_rc=0`;
- the workstation closeout shows final connected/disarmed state, ordered child
  stop, stop-marker publication and `status=0 cleanup_rc=0`;
- the copied `guard_snapshot.parm` still hashes to
  `3854b9705bea81b4b86d6b57476671872d1a0e30a21edadf188270889fb473e9`;
- the video digest and measured `800/800 -> 911/800 -> 800/800 us` sequence are
  retained.

The workstation runtime is closed:

- no governed real-FCU, FCU-to-VRX, MAVROS, rosbridge, dashboard, Gazebo or
  servo-bridge process remained;
- TCP `8002`, `8080`, `9090` and UDP `14555` had no listener;
- fresh daemonless checks found no ROS node in domain `43` or domain `77`.

The repaired timeout and status-format contracts were rechecked directly from
current source. Both real-FCU supervisors default to a `600 s` readiness window
and a `15 s` one-shot status subscription. The Pi manual confirmation occurs
before its fresh readiness wait begins. Both status readers use
`--no-lost-messages`, keep diagnostics on stderr, require exactly one mapping,
accept the ROS document terminator and normalize the result to JSON. The focused
verification passed:

```text
real-FCU shell helper suite: PASS cases=32
real-FCU Python tests:       45 passed
```

The day's Test A work is therefore operationally closed and retained. The
overall FCU-to-VRX workstream is not represented as fully closed because four
items remain explicit:

1. Test B is **NOT RUN** and its `/wamv/pose` versus `/model/wamv/pose` defect
   must be repaired and proven offline first.
2. `RC_OVERRIDE_TIME=0.5` remains live only for Test B and still requires the
   mandatory verified rollback to `3.0` afterward or before another operation.
3. The final software evidence proves FCU disarm but does not independently
   prove the final physical hardware-safety, power, Pi or Herelink state. A
   literal operator closeout is still required for the physical layer.
4. The documentation closeout is present in the worktree but is not yet
   committed or pushed.

All four open items are carried into the 27/08/2026 diary. None is silently
promoted to PASS.

## Final physical closeout - 26/08/2026

At EOD, the operator explicitly confirmed that the FCU and Pi were powered
off. No unstated hardware condition is inferred from that confirmation. All
27/08/2026 physical declarations and approvals remain fresh-day gates.
