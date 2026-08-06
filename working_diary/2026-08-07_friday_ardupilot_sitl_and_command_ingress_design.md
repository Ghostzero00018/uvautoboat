# Friday 07/08/2026 - ArduPilot SITL and command-ingress design

> **PRE-DIARY - NOT STARTED.** Moved unchanged in substance from the 06/08/2026
> pre-diary, which was deferred because that day went to the internship report.
> This file does not authorize work. Every block below needs explicit approval
> before it starts. The day is workstation-only. No Pi, no control box, no FCU
> write, no arming, no motor or thrust command to real hardware, no edit to
> `tools/pi_live_hailo_mavlink_dashboard.sh`.

## Starting state

- Expected clean `main` with `HEAD == main == origin/main` and divergence
  `0/0`. **Certify before starting.** The expected parent is the commit that
  closed 06/08/2026; no hash is pinned here because this file was written
  before that commit existed. If `HEAD` is later than the 06/08 day-close
  revision, inspect every intervening commit first.
- Production pins unchanged since 04/08/2026:
  `tools/pi_live_hailo_mavlink_dashboard.sh` at `71,501` bytes /
  `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`, and
  `tools/live_dashboard_preflight.sh` at `28,647` bytes /
  `958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877`.
  Re-verify rather than assume.
- The batched MAVROS source view was exercised live on 05/08/2026 and is
  feasible at shipped defaults. The graph race recurred under it, so no fix is
  demonstrated. That workstream is parked; today does not touch it.
- ArduPilot SITL, `sim_vehicle.py` and workstation MAVProxy were **absent** as
  of 05/08/2026, and `~/ardupilot` did not exist. Nothing since then was
  expected to change that, but Block A re-checks it rather than assuming.
- **Host figures below are two days old and must be re-measured in Block A.**
  On 05/08/2026 the workstation `/` was at `94%` with `13 GB` free, and the
  machine was on `IoT IMT Nord Europe`, which carries the Pi ROS/SSH link and
  is not the campus internet path.

## Objective and non-goals

Open a **workstation-to-FCU thrust command path** in the only order that is
safe to open it: simulator first, real autopilot never today.

The agreed sequence is ArduPilot SITL on the workstation, then verification of
the simulator MAVLink graph, then the design of a small isolated command-ingress
bridge with explicit dead-man and safety checks. Helper integration is revisited
only after all three.

### Structural decision, binding

An outbound command path lives in a **separate bridge service or tool**, never as
an edit to `tools/pi_live_hailo_mavlink_dashboard.sh`. That helper is
deliberately view-only: `reject_command_services` (`:535`),
`reject_unexpected_command_subscribers` (`:902`) and `check_command_sentinel`
(defined at `:965`, referenced at `31` call sites) abort a live run when a
command service, unexpected command subscriber, or monitored command message
appears. Weakening a proven safety boundary to add a write path is not an
acceptable route.

The browser dashboard likewise stays view-only. Note the mechanism precisely:
`LIVE_MAVLINK_VIEW_ONLY` is **not an environment variable**. It is a source
constant, `const LIVE_MAVLINK_VIEW_ONLY = true;` at
`web_dashboard/autoboat/app.js:263`, guarded by a test that asserts that exact
source line (`web_dashboard/autoboat/test/mavlink_telemetry.test.js:234`). It
cannot be flipped at runtime, and changing it fails the suite. Do not describe
it as a toggle.

### Not in scope today

Real-FCU thrust, arming, mode change, parameter write, mission upload, any
serial or MAVLink write toward the control box, Pi-side work of any kind,
helper or supervisor edits, VRX or Gazebo runs, detector or dataset work, and
the parked graph-query workstream.

Real-boat thrust remains behind the standing powered-off, propellers-removed
wiring gate, plus `ARMING_REQUIRE=1` and the safety switch.

## Direction check before anything else

`tools/servo_command_bridge.py` runs the **opposite** direction: it reads
MAVLink `SERVO_OUTPUT_RAW` from an autopilot and publishes
`/wamv/thrusters/{left,right}/thrust` into the simulator. Today's path is
workstation into the autopilot. It is a different data flow, so treat that file
as reference and prior art, not as the thing being extended. It has never been
run against any autopilot, and its PWM defaults are stock-SITL `1100/1500/1900`
while the real boat's rail is `800/800/2200` - two opposite and silent hazards.

`tools/servo_command.cpp` remains an intentionally unbuilt, non-authoritative
reference.

## Scheduling note

This is the last working day of the week and the four blocks are not equally
sized. Block B is the long pole: a submodule clone plus a SITL build is the only
step whose duration is not under our control, and it sits behind a disk verdict
that may itself require a separate cleanup gate. Treat A and B as the day's
realistic target. C and D proceed only if B finishes with margin; carrying D
into next week is the expected outcome, not a failure, and is preferable to a
rushed contract.

## Block A - prerequisites, read-only

Certify the revision, then confirm the three things that decide whether the rest
of the day is possible at all:

1. **Disk.** Re-measure; do not reuse the 05/08 figure. An ArduPilot clone with
   submodules plus SITL build artifacts is multi-GB against a partition that was
   at `94%` two days ago. Measure the requirement before committing to it.
   Regenerable-data cleanup is a **separate user-run gate**, not part of this
   block, and historical run evidence is retained.
2. **Network.** The clone needs real internet. Confirm the current SSID rather
   than assuming; on 05/08 the workstation was on `IoT IMT Nord Europe`, which
   is the Pi link. Campus internet is `IMT Nord Europe 5G`. Decide and record
   which SSID the install runs on, and note that switching drops the Pi link for
   the duration - acceptable today because no Pi work is planned.
3. **Existing surfaces.** Read `tools/servo_command_bridge.py` and
   `tools/servo_command.cpp` before proposing anything new.

Block A starts no service, installs nothing, and changes no file.

## Block B - ArduPilot SITL install, workstation only

Explicit approval required, and only after Block A shows disk and network are
adequate.

Install and build ArduPilot SITL on the **workstation**. Not on the Pi. The real
FCU already runs ArduRover `4.6.3`, so no firmware work is implied or permitted
today.

Vehicle target is Rover, matching the real boat's skid-steer configuration.

Record the exact clone source, revision, submodule state, build command, disk
consumed before and after, and any package the build pulled in. A package
installation is a user-run step; provide the command list and interpret the
output rather than running it.

Stop condition: `sim_vehicle.py` starts a Rover SITL instance and reaches a
steady state. Nothing beyond that in this block.

## Block C - simulator MAVLink graph verification

Explicit approval required, and only after a clean Block B.

Verify what the simulator actually exposes before designing against it:
the MAVLink endpoint and port, the heartbeat, the vehicle type and autopilot
identifiers, the servo output rail, and which messages the boat's skid-steer
configuration produces. Compare the observed PWM rail against both the stock
SITL `1100/1500/1900` and the real boat's `800/800/2200`, and record which one
this instance uses.

Any ROS-side work in this block must not use the Pi's live domain. That domain
is whatever the helper resolves at `:16`, `DOMAIN="${LIVE_ROS_DOMAIN_ID:-12}"`,
exported as `ROS_DOMAIN_ID` at `:1343` - so it is `12` unless
`LIVE_ROS_DOMAIN_ID` was overridden for the session. Check which value the last
live run actually used rather than assuming the default, then pick a different
domain explicitly and record it.

Read-only observation. No command is sent to the simulator in this block.

## Block D - command-ingress bridge, design only

Explicit approval required. **Design only - no implementation today.**

Define, before any code exists:

- exact payload, units and rail, and the mapping to servo or thrust output;
- recipient, transport, port, and rate/QoS;
- acknowledgement and timeout semantics;
- **dead-man behaviour**: what happens on loss of the command stream, and the
  neutral value it falls back to;
- arming interaction, and why the bridge cannot arm;
- failure semantics, and the fail-closed default;
- the explicit boundary that prevents this path from ever addressing the real
  FCU without a separate approved gate.

State the non-goals and the over-design traps avoided. Prefer the existing
contracts and a narrow interface over a new abstraction.

## Acceptance

- Block A produces a disk and network verdict and a read of both existing
  command-path surfaces.
- Block B either has SITL running on the workstation or records exactly why not.
- Block C records the simulator's real MAVLink surface and its PWM rail.
- Block D produces a written contract, not code.

A day that closes after A and B with C and D carried forward meets the week's
objective. A day that reaches D by rushing B does not.

## Non-claims to retain

- A working SITL says nothing about the real boat. The autopilot, the rail, the
  wiring and the safety interlocks all differ.
- No command has been sent to any autopilot, simulated or real.
- The Pi helper's view-only posture is unchanged, and its pins are unchanged.
- The graph-race workstream is parked, not closed: its lower DDS/RMW/network
  trigger is unidentified, browser-last ordering is unobtained, the
  `live_dashboard_20260724_175832` cumulative timing cause is open, and the
  terminal data-plane probe has never fired.
- Task 2 remains retired.

**Next steps:** after approval, certify, run Block A, and gate Block B on its
disk and network verdict.
