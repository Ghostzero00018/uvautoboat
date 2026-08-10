# Tuesday 11/08/2026 - digital-twin thrust loop and helper integration

## Purpose

Finish the workstation-only thrust digital-twin loop with machine-readable
request/feedback evidence and integrate its lifecycle with the existing shell
helper family. The result must start, observe and stop as one bounded workflow
without weakening `tools/pi_live_hailo_mavlink_dashboard.sh` or presenting SITL
evidence as physical acceptance.

## Read first

1. This file.
2. The complete 10/08 diary, especially `SITL digital-twin runtime acceptance
   and EOD closeout`:
   `working_diary/2026-08-10_monday_command_ingress_contract_and_helper_thrust_telemetry.md`.
3. `Board.md` Next Priorities item 2.
4. `wiki/Roadmap.md` section 3 command-ingress status.
5. `tools/live_dashboard_preflight.sh`,
   `tools/pi_live_hailo_mavlink_dashboard.sh`,
   `tools/real_fcu_rc_command_bridge.py` and their focused tests.

Do not create another 11/08 diary. Append the day's results to this file only.
Do not touch the external weekly diary or rewrite earlier diary evidence.

## Repository certification

The last known code baseline before the 10/08 documentation closeout is
`2e16b0de7068b57c36a83f5881c2a2bd85a9ff04` with subject
`fix(bridge): use the MAVROS ROS 2 parameter API`. The documentation closeout
commit that contains this file will be later, so do not guess its SHA.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -8
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git merge-base --is-ancestor 2e16b0de7068b57c36a83f5881c2a2bd85a9ff04 HEAD
```

| Result | Action |
| --- | --- |
| Fetch fails | Stop and report. |
| Behind only | Run `git pull --ff-only`, then repeat certification. |
| Dirty, ahead or diverged | Stop and report. |
| HEAD contains commits after the baseline | Inspect every intervening commit before continuing. |

Re-measure free disk and require at least `10 GB`; do not reuse the 10/08
`24 GB` observation after a restart or new build.

## Carried evidence and exact non-claims

The 10/08 workstation run established:

- `motorboat-skid`, ArduRover `4.6.3` at `3fc7011a`;
- live mapping `RC1` steering, `RC3` throttle, `SERVO1` function `73` left and
  `SERVO3` function `74` right;
- fresh `READY_DISARMED`, normal arm to `ARMED_NEUTRAL`, positive and negative
  browser-held `ACTIVE` intervals, neutral return and accepted normal disarm;
- visible positive demand `+0.10`/`0.08` with measured servo `1585`/`1485`;
- visible negative demand `-0.04`/`0.09` with measured servo `1520`/`1559`;
- two untouched recordings with SHA-256
  `b94f836ba24dfda7d6e6bda75eb185322c8aa6c06cbe47a1c3b776c0356bb26a`
  and `2d2d882cf05d7418a55a9396d8ebf5cc894516e965093ce28a14147ad26ac42d`.

The terminal status capture missed both holds. Complete machine-readable active
evidence and one supervised teardown remain open. Nothing above proves physical
thrust, real-FCU actuation, Pi integration or real-boat mapping/rails.

## Fixed architecture

1. `tools/pi_live_hailo_mavlink_dashboard.sh` remains view-only. It does not
   gain a command publisher, command subscriber or physical-FCU write mode.
2. The digital-twin runner is workstation-only, uses `ROS_DOMAIN_ID=42` and
   `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`, and must abort if either value is
   absent or different.
3. Integration belongs in an explicit SITL path in the helper family. The
   preferred seam is a dedicated companion runner invoked by a clearly named
   `tools/live_dashboard_preflight.sh` subcommand. The existing `workstation`,
   `run` and `pi` paths must retain their current live domain `12` behaviour.
4. The helper owns process provenance, log paths, readiness gates and teardown.
   Operator arm/disarm remains a separate, explicitly bounded interaction; the
   bridge itself still cannot arm or disarm.
5. All channels and rails continue to come from the connected SITL's live
   parameters. No helper may supply channel or PWM defaults to the bridge.

## Block A - certify and inspect

Read-only and starts nothing. After repository certification:

- verify there is no conflicting SITL, MAVProxy, MAVROS, rosbridge, dashboard or
  bridge process;
- verify ports `5760`, `8002`, `9090` and UDP `14600` are free;
- verify `/home/ghostzero/ardupilot/build/sitl/bin/ardurover` still matches the
  pinned Rover build and the ArduPilot virtual environment exists;
- verify ROS 2 Jazzy, MAVROS, rosbridge and the Python imports used by the bridge;
- inspect the current helper usage, pin surfaces and focused tests;
- identify every documentation or test surface invalidated by the selected
  helper seam.

Stop after Block A and request explicit approval for Block B.

## Block B - helper seam and red test

Design and focused test only. Choose the smallest implementation that gives the
existing helper family an explicit workstation-SITL entry without placing a
write path in the Pi helper. Define before implementation:

- exact new subcommand and companion-helper names;
- process tree and ownership for SITL, MAVProxy, MAVROS, the command bridge,
  rosbridge and dashboard server;
- how the operator console remains interactive without escaping supervisor
  teardown;
- unique run directory and one log per child;
- readiness order and abort markers;
- positive, negative, release, E-Stop, disarm and teardown evidence files;
- which process failure terminates the full run and the resulting exit code.

Add the smallest failing test for the chosen helper contract. Stop and request
explicit approval for Block C.

## Block C - implement helper integration

Implement only the approved workstation-SITL seam. Do not change the Pi helper
unless a verified source constraint makes the separate path impossible and the
user separately approves that scope change.

The integrated workflow must:

1. create one run directory and record revision, environment and child commands;
2. launch SITL with a temporary parameter file containing exactly
   `RC_OVERRIDE_TIME 0.5`, `ARMING_RUDDER 0` and `BRD_SAFETY_DEFLT 1`;
3. keep the ArduPilot virtual environment isolated from ROS shells;
4. route MAVProxy TCP `5760` to loopback UDP `14600`;
5. start minimal MAVROS with source `255.191`, target `1.1` and the repository's
   digital-twin plugin YAML;
6. start the bridge with explicit bounds, then require the live-resolution log;
7. start rosbridge and dashboard on loopback and print the complete bench URL;
8. start machine-readable captures of `/command_ingress/rc_axes` and
   `/command_ingress/status` before enabling browser interaction;
9. preserve normal operator arm/disarm and keep force values unavailable;
10. on any child failure or operator stop, neutralise/release as appropriate,
    stop children in dependency order and print one final verdict.

## Block D - one clean helper-driven SITL run

User-run, workstation only. Every handover must state all seven fields: host and
terminal; absolute working directory; exact source/activate lines; environment
variables; prerequisites; stop condition; exact output to paste back.

Acceptance requires one uninterrupted run directory containing all of the
following:

| Phase | Required evidence |
| --- | --- |
| Startup | Pinned SITL identity, complete parameter receipt and live guard mapping. |
| Disarmed | `READY_DISARMED`, fresh feedback and measured `1500`/`1500`. |
| Arm | Normal acknowledgement and `ARMED_NEUTRAL`; no force arm. |
| Positive | Machine-readable `ACTIVE`, requested `+0.10`/`0.08`, and decoded left demand greater than right. |
| Release | `ARMED_NEUTRAL`, command zero and measured `1500`/`1500`. |
| Negative | Machine-readable `ACTIVE`, requested `-0.04`/`0.09`, and decoded left demand less than right. |
| E-Stop | Browser E-Stop latches and returns the bridge to neutral output. |
| Disarm | Normal acknowledgement and disarmed status. |
| Teardown | Bridge shutdown frames, all children stopped, ports free and one passing supervisor verdict. |

Raw PWM comparison is valid here only after the live SITL rails and reversal
flags are recorded. If those differ from the known run, decode each output
through its own live rail/reversal before evaluating the mapping.

Stop immediately on unexpected physical endpoints, domain `12`, non-loopback
discovery, an already-armed startup, missing/incomplete parameters, stale or
invalid feedback, non-`MANUAL` mode, mapping drift, failure to neutralise, or an
unowned conflicting process. No Pi or physical FCU is part of this block.

## Block E - document and wrap

Append the exact run directory, verdict markers, measured transitions and
bounded non-claims to this diary. Update living Board/Roadmap/dashboard text only
if runtime behaviour changed; do not rewrite dated rows or the 10/08 diary.

## Verification by changed surface

| Changed | Required checks |
| --- | --- |
| `tools/live_dashboard_preflight.sh` | `bash -n` on both existing helpers, then both focused shell suites. |
| New shell companion | `bash -n`, a dedicated focused suite, and the existing preflight suite. |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | Both `bash -n` checks, both focused suites, all operational pin surfaces and deployed-copy invalidation rules. |
| `tools/real_fcu_rc_command_bridge.py` | `python3 -m py_compile` and its focused Python suite. |
| Dashboard JavaScript | `node --check` and the complete dashboard suite. |
| Any tracked change | `git diff --check`. |

Do not assume the dashboard suites cover shell orchestration. If an existing
pin changes, update every current operational pin surface but never rewrite a
historical diary hash.

## Out of scope

- physical-FCU writes, real arming or physical thrust;
- Pi-side command integration or weakening the live helper's view-only posture;
- detector, dataset, graph-query or external weekly-diary work;
- rewriting any earlier diary or dated Timeline row.

## Wrap

Use one conventional commit subject, one line and at most 72 characters. Stage
the complete intended set by explicit path only. Before the user commits:

```bash
git status --short --branch
git diff --check
git diff --cached --name-status
git diff --cached --check
```

Inspect the staged content itself and confirm that no implementation, test or
documentation file intended by the subject is missing.
