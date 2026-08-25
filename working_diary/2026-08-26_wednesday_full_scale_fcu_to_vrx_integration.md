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
