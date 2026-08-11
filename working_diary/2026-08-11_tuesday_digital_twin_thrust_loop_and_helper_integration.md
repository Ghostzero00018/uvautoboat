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

## Block B design - helper seam and red test (11/08/2026)

Block B was explicitly approved after the read-only certification. This block
defines the workstation-SITL seam and adds one failing contract assertion only.
No runner, operator helper or evidence recorder is implemented; the existing
supervisor, Pi helper, bridge, dashboard and configuration are unchanged, and no
process or service was started.

The operator re-measured `20G` free at `90%` used. This supersedes the earlier
same-day `23G` observation and remains above the `10 GB` floor. The ambient shell
inherits `ROS_DOMAIN_ID=12` and `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`; those
values are inputs to reject, not defaults for this path.

### Selected entry and files

The public entry will be:

```text
tools/live_dashboard_preflight.sh sitl
```

The exact new names are:

| Purpose | Name |
| --- | --- |
| Existing-helper entry | `run_sitl_digital_twin_entry` |
| Workstation-SITL supervisor | `tools/sitl_digital_twin_runner.sh` |
| Phase-gated operator action | `tools/sitl_operator_once.py` |
| Read-only evidence recorder | `tools/sitl_digital_twin_evidence.py` |
| Runner focused test | `tools/test_sitl_digital_twin_runner.sh` |
| Operator focused test | `tools/test_sitl_operator_once.py` |
| Evidence focused test | `tools/test_sitl_digital_twin_evidence.py` |

`live_dashboard_preflight.sh` will source the companion only inside
`run_sitl_digital_twin_entry`. Its existing `workstation`, `run` and `pi`
branches will neither source the companion nor change their domain-12 setup.
There is no entry in `tools/pi_live_hailo_mavlink_dashboard.sh` and no Pi copy of
any new file.

The selected seam reuses the existing process-group primitives without moving
them into a new library or refactoring the live supervisor. The SITL companion
defines only SITL-prefixed initialization, readiness, monitoring, evidence and
teardown functions, then calls the existing `start_child`, `stop_group` and
child-liveness functions.

### Environment and provenance boundary

Before creating a child, the SITL runner must set and immediately validate all
three values itself:

```text
ROS_DOMAIN_ID=42
ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
ROS_LOCALHOST_ONLY=1
```

It must not accept a caller's inherited domain. It also unsets static peers,
discovery servers and inherited RMW profile selectors before sourcing
`/opt/ros/jazzy/setup.bash`. Every ROS child receives the resulting explicit
environment. This runner-side guard is mandatory because
`tools/real_fcu_rc_command_bridge.py` returns early when `allow_real_fcu` is
false and therefore does not always perform its own domain check.

The SITL child is the opposite environment boundary: its wrapper unsets every
ROS and DDS variable, changes to `/home/ghostzero/ardupilot`, activates only
`/home/ghostzero/venv-ardupilot`, and never sources ROS. Before launch, the
runner rechecks the exact checkout revision, Rover executable size, digest and
embedded identity recorded above. It rejects serial devices, non-loopback FCU
URLs, domain `12`, an existing relevant process, occupied TCP ports `5760`,
`5762`, `8002` or `9090`, or occupied UDP port `14600`.

The unique run directory is created without overwriting an existing path:

```text
${WORKSTATION_LOG_ROOT}/sitl_digital_twin_YYYYMMDD_HHMMSS
```

It contains `manifest/repository.txt`, `manifest/environment.txt`,
`manifest/commands.tsv`, artifact digests and `manifest/sitl.params`. The
parameter file has exactly these three entries and no defaults beyond them:

```text
RC_OVERRIDE_TIME 0.5
ARMING_RUDDER 0
BRD_SAFETY_DEFLT 1
```

### Owned process tree

The companion is the sole long-lived supervisor. Every process below is started
with `start_child`, has a separate session and process group, receives
`/dev/null` as standard input, and has exactly one named log under `logs/`.

| Start order | Child | Required contract | Log |
| ---: | --- | --- | --- |
| 1 | SITL | Instance `0`, pinned Rover, `motorboat-skid`, no rebuild/configure/MAVProxy, exact temporary parameter file | `logs/sitl.log` |
| 2 | MAVProxy | TCP `127.0.0.1:5760` to UDP `127.0.0.1:14600`, source `254.190`, target `1.1`, non-interactive | `logs/mavproxy.log` |
| 3 | MAVROS | Source `255.191`, target `1.1`, no GCS URL, exact `sys_status`/`param`/`rc_io` allowlist | `logs/mavros.log` |
| 4 | Command bridge | `allow_real_fcu:=true`, `max_steering:=0.20`, `max_throttle:=0.12`, live parameters only | `logs/bridge.log` |
| 5 | Evidence recorder | Read-only subscriptions to request, status, E-Stop, override and MAVROS state topics | `logs/evidence.log` |
| 6 | Rosbridge | Loopback `127.0.0.1:9090` only | `logs/rosbridge.log` |
| 7 | Dashboard | Loopback `127.0.0.1:8002` only | `logs/dashboard.log` |

MAVProxy uses its installed non-interactive mode; it is not a console. This
makes the existing `/dev/null` child-input rule safe for the route and removes
the unresolved terminal-attachment problem.

### Bounded operator actions

`tools/sitl_operator_once.py` is not a supervised child and is not a console.
The runner prints its complete separate-terminal command only after creating an
action-specific gate under `operator/`. The helper connects once to instance-0
`SERIAL1` at `tcp:127.0.0.1:5762` as source `254.190`, locks target `1.1`, uses a
finite deadline, writes one result under the same run directory and exits. An
action cannot be reused or retried inside the same run.

Its exact allowlist is:

| Action | Sole permitted operation | Required result |
| --- | --- | --- |
| `safety-off` | One `SET_MODE` safety-state request with `MAV_MODE_FLAG_DECODE_POSITION_SAFETY` and custom mode `0` | Fresh `SYS_STATUS` reports motor outputs enabled |
| `arm` | One `MAV_CMD_COMPONENT_ARM_DISARM`, `param1=1`, `param2=0`, all other parameters zero | Accepted ACK followed by a fresh armed heartbeat |
| `disarm` | One `MAV_CMD_COMPONENT_ARM_DISARM`, `param1=0`, `param2=0`, all other parameters zero | Accepted ACK followed by a fresh disarmed heartbeat |

The `safety-off` action is required by the 10/08 runtime evidence: with
`BRD_SAFETY_DEFLT=1`, the bridge resolved its guard but `/mavros/rc/out` stayed
zero and feedback remained invalid until the simulated safety state was turned
off. An arm/disarm-only helper cannot reach `READY_DISARMED` under the required
three-line overlay. This is a simulator-only safety-state action, not permission
to add a general mode command.

The helper has no force arm/disarm, navigation-mode, parameter, RC override,
`MANUAL_CONTROL`, raw-servo, motor-test, mission or reconnect operation. A
non-zero helper exit latches the full run as failed. The supervisor also requires
the SERIAL1 pair to close after the result and rejects an operator peer outside
the open action gate.

### Readiness order and markers

Readiness is strictly ordered; a later child never starts after an earlier gate
fails.

| Order | Required evidence | Success marker |
| ---: | --- | --- |
| 1 | Repository, disk, binary, environment, process and socket checks pass | `SITL_PREFLIGHT=PASS` |
| 2 | SITL PID/provenance and instance-0 TCP listeners `5760`/`5762` match | `SITL_PROCESS=READY` |
| 3 | MAVProxy owns the one TCP master and loopback UDP route | `SITL_MAVPROXY=READY` |
| 4 | MAVROS is `255.191`, connected to disarmed `1.1`, in `MANUAL`, with the full parameter set | `SITL_MAVROS=READY` |
| 5 | Bridge prints one live-resolution line with distinct RC and SERVO channels | `SITL_BRIDGE_GUARD=PASS` |
| 6 | Evidence recorder confirms all five subscriptions before operator action | `SITL_CAPTURE=READY` |
| 7 | One-shot safety-off succeeds; bridge reports fresh `READY_DISARMED` and live-trim feedback | `SITL_DISARMED_READY=PASS` |
| 8 | Rosbridge and dashboard are loopback-only and healthy | `SITL_WEB=READY` |
| 9 | Browser creates exactly one command publisher and emits a disabled frame | `SITL_BROWSER=READY` |
| 10 | Runner prints the complete URL and opens the one-shot arm gate | `SITL_SESSION=READY` |

The bridge marker is parsed for the live left/right SERVO numbers. The complete
URL is then built from those values rather than from the known SITL mapping:

```text
http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=N&thrust_right_servo=N
```

Any missing, duplicate, out-of-range or changed mapping aborts. Each phase
failure records `SITL_PHASE_FAIL phase=<name> rc=<status>` once and prevents a
PASS verdict.

### Machine-readable evidence contract

The recorder is subscriber-only. It writes complete timestamped JSON Lines
streams before browser interaction begins:

```text
captures/rc_axes.jsonl
captures/status.jsonl
captures/emergency_stop.jsonl
captures/override.jsonl
captures/mavros_state.jsonl
```

It retains ROS receive metadata and the full message payload. It uses the live
RC and servo rails/reversal flags saved in `evidence/startup.json`; raw PWM from
different rails is never compared directly. The following files are written
atomically only after their complete condition is present in the ordered raw
streams:

| File | Minimum content |
| --- | --- |
| `evidence/startup.json` | Revision/artifact identity, exact environment, child commands, three received parameters and live mapping/rails |
| `evidence/ready_disarmed.json` | Fresh `READY_DISARMED`, disarmed `MANUAL`, live-trim RC input and measured output |
| `evidence/arm.json` | One-shot non-force accepted ACK, fresh armed state and `ARMED_NEUTRAL` |
| `evidence/positive.json` | `ACTIVE`, request `+0.10`/`0.08`, fresh feedback and decoded left demand greater than right |
| `evidence/release.json` | Later `ARMED_NEUTRAL`, zero request and both measured outputs at their live trims |
| `evidence/negative.json` | Later `ACTIVE`, request `-0.04`/`0.09`, fresh feedback and decoded left demand less than right |
| `evidence/estop.json` | Browser `Bool(true)`, latched `EMERGENCY_STOP`, zero accepted request and measured neutral output |
| `evidence/disarm.json` | One-shot non-force accepted ACK, fresh disarmed MAVROS state and first channel-aware release frame |
| `evidence/teardown.json` | Three channel-aware bridge shutdown frames, stopped child groups, free required ports and teardown status |
| `evidence/verdict.json` | Paths and hashes of every required evidence file plus the single final verdict |

The override capture remains alive until the bridge exits, so the three shutdown
frames are observed without adding instrumentation to the bridge. This proves
ROS frame publication only; it is not a per-frame FCU ACK or physical-output
claim.

### Failure ownership, teardown and exit status

Every unexpected exit of SITL, MAVProxy, MAVROS, the bridge, recorder,
rosbridge or dashboard terminates acceptance and latches `SITL_VERDICT=FAIL`.
No child is optional. A health failure, rejected operator action, stale feedback,
unexpected arm/mode/mapping, non-loopback peer, missing evidence or occupied
post-teardown port has the same effect.

If an interrupt or child failure occurs while armed, the supervisor first stops
new browser demand, keeps the still-valid bridge and MAVLink path alive for
neutral hold, opens only the one-shot disarm gate and waits for fresh disarmed
state. It never treats release as neutral while armed. A failed bridge cannot
provide that hold, so the separately connected one-shot disarm becomes the only
permitted command before teardown; the verdict remains FAIL.

After fresh disarm, teardown is explicit rather than simple reverse-start order:

1. dashboard;
2. rosbridge;
3. bridge, while the evidence recorder remains alive;
4. evidence recorder after it captures the shutdown frames;
5. MAVROS;
6. MAVProxy;
7. SITL.

The final checks require every process group gone and TCP `5760`, `5762`,
`8002`, `9090` plus UDP `14600` free. Exit status is `0` only when every phase
file exists, normal disarm occurred, teardown passed and
`SITL_VERDICT=PASS` was written. Usage is `2`; an interrupt before any child is
ready is `130`; termination preserves `143`; every readiness, child, operator,
evidence or teardown failure exits `1`. An early operator stop may tear down
safely but cannot produce status `0` before the full evidence contract passes.

### Change surface and non-goals

Block C, if separately approved, may change only the preflight dispatcher and
pin, the three named SITL helpers, their focused tests, the current runbook
supervisor size/digest rows, the dashboard component README and this diary. The
preflight test's expected supervisor digest and the runbook's exact digest line
must change with the supervisor; the adjacent size row must also be measured and
updated even though no test currently enforces it. Historical diary pins remain
untouched.

The Pi helper and its focused suite are not implementation surfaces. There is
no shared supervisor-library refactor, general GCS, terminal attachment,
automatic arm/disarm, new ROS message, physical endpoint, real-FCU transport,
Pi integration, VRX bridge, detector or external weekly-diary work.

### Red test result

The smallest contract is the new dispatch literal in
`tools/test_live_dashboard_preflight.sh`:

```text
1:sitl) run_sitl_digital_twin_entry ;;
```

It is added before any supervisor byte changes. The measured supervisor digest
remains `c1490db8f7198a774fc21b3892415d654725e33d83b3680edb820bc9d2f259bf`.
The focused suite reached the new assertion, exited `1` and reported exactly
`FAIL: missing contract: 1:sitl) run_sitl_digital_twin_entry ;;`. No process or
service was started, and no expected digest or runbook pin is changed in Block
B.

Block B stops with that intentional red result. Block C implementation and all
runtime work remain **NOT STARTED** and require separate explicit approval.

## Block C implementation - static closeout (11/08/2026)

Block C was explicitly approved. The approved workstation-only seam is now
implemented and covered by focused static tests. The Pi helper remains unchanged,
and no SITL, MAVProxy, MAVROS, bridge runtime, rosbridge, dashboard server,
browser or hardware link was started.

### Implemented change surface

The public entry is now:

```text
tools/live_dashboard_preflight.sh sitl
```

The dispatcher sources `tools/sitl_digital_twin_runner.sh` only inside the new
`run_sitl_digital_twin_entry` function. The existing `workstation`, `run` and
`pi` dispatch lines remain present unchanged. Direct execution of the companion
returns usage status `2` and points back to the public entry.

The six new executable files are:

| Purpose | File |
| --- | --- |
| SITL lifecycle owner | `tools/sitl_digital_twin_runner.sh` |
| Finite operator action | `tools/sitl_operator_once.py` |
| Subscriber-only evidence and verdict | `tools/sitl_digital_twin_evidence.py` |
| Runner contracts | `tools/test_sitl_digital_twin_runner.sh` |
| Operator contracts | `tools/test_sitl_operator_once.py` |
| Evidence contracts | `tools/test_sitl_digital_twin_evidence.py` |

The runner owns its process-group state, traps, dependency-ordered teardown and
`sitl_digital_twin_YYYYMMDD_HHMMSS` directory. It resets inherited supervisor
state instead of calling the workstation initializer. Its preflight rejects a
dirty worktree or a `HEAD` that differs from `origin/main`, an unexpected
ArduPilot or Rover artifact, less
than `10 GB` free, conflicting processes, occupied required ports and inherited
ROS/DDS selectors. It then explicitly validates domain `42`, `LOCALHOST`
discovery and `ROS_LOCALHOST_ONLY=1`. The SITL child receives a separate ROS-free
ArduPilot environment.

The generated parameter overlay is exactly:

```text
RC_OVERRIDE_TIME 0.5
ARMING_RUDDER 0
BRD_SAFETY_DEFLT 1
```

The owned child order is SITL, MAVProxy, MAVROS, command bridge, evidence
recorder, rosbridge and dashboard. Each child has one process group and one log.
MAVROS uses source `255.191`, target `1.1`, the installed APM parameters and the
repository's three-plugin allowlist. The bridge retains explicit steering and
throttle bounds of `0.20` and `0.12` and must expose one valid live-resolution
line before any operator gate opens.

`tools/sitl_operator_once.py` accepts only `safety-off`, `arm` or `disarm` behind
an unexpired, action-specific, non-reusable gate. It opens one non-reconnecting
loopback connection to `tcp:127.0.0.1:5762`, uses source `254.190` and target
`1.1`, and closes before writing the result. Safety-off uses only the dedicated
safety-state `SET_MODE` form. Arm and disarm use normal
`MAV_CMD_COMPONENT_ARM_DISARM` requests with no force value and require both an
accepted acknowledgement and a fresh matching heartbeat.

`tools/sitl_digital_twin_evidence.py` has no publisher. It records the five raw
request, status, E-Stop, override and MAVROS-state streams, validates the pinned
parameter count and live mapping, and emits ordered atomic phase files. Positive
and negative comparisons decode each servo through its own live rail and
reversal. Fresh feedback is required for every measured phase. A disconnected
or non-`MANUAL` state cannot satisfy arm/disarm evidence, and any capture fault
forces the final verdict to fail.

Normal post-disarm release evidence and bridge-shutdown evidence are separate:
three release frames must be captured before the run can be marked complete,
then three later frames must follow the atomic teardown request while the
evidence recorder remains alive. Teardown stops dashboard, rosbridge, bridge,
evidence, MAVROS, MAVProxy and SITL in that exact order and requires every child
group gone and every required port free.

The dashboard component README now names the new entry while retaining
**NOT RUN** for helper-driven acceptance. The living Board and Roadmap remain
unchanged because their open runtime-capture and lifecycle claims are still
current.

### Current pins

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/live_dashboard_preflight.sh` | `29,058` bytes | `d101ec5840c1358e0475fff33989af9b3f3431231859c0e0e1c2ffa0fafab82a` |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `73,862` bytes | `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97` |

The supervisor size and digest are updated together in the current runbook and
the focused checksum gate. The Pi helper bytes and all of its current pin
surfaces remain unchanged.

### Static verification

| Check | Result |
| --- | --- |
| Bash syntax for both existing helpers, the runner and three shell suites | PASS |
| Existing preflight contracts | PASS, `13` cases |
| Existing Pi lifecycle suite | PASS |
| New runner contracts | PASS, `9` cases |
| One-shot operator suite | PASS, `5` tests |
| Evidence state/verdict suite | PASS, `9` tests |
| Existing command-bridge suite | PASS, `21` tests |
| Dashboard suite | PASS, `39`; fail `0` |
| Python compilation, `node --check`, plugin YAML parse | PASS |
| Whitespace/error check | PASS |

The new tests use temporary directories, synthetic state and fake transports;
their PASS and deliberately generated FAIL verdicts are test evidence only.
After all suites, the relevant process patterns were absent and TCP `5760`,
`5762`, `8002`, `9090` plus UDP `14600` were unbound.

### Gate and next action

Block C is complete as a static implementation. The worktree intentionally
contains the five modified files and six new files above; no commit or push was
performed. The runner itself requires a clean worktree with `HEAD` equal to
`origin/main`, so the user must review, commit and push this complete change set
before runtime.

Block D remains **NOT STARTED**. It is a separately approved, user-run
workstation SITL acceptance block. Do not launch the new entry, a browser or any
ROS/MAVLink service until that approval and the complete host/terminal handover
are provided.

**Next steps:** review and publish Block C, then request explicit approval before
preparing the Block D user-run handover.

## Block C correction - ROS argument parsing and evidence traffic (11/08/2026)

The post-implementation review found that the explicit empty MAVROS GCS URL was
assembled as `gcs_url:=`. A context-only `rclpy` parser check rejected that exact
argument before creating a node:

```text
Couldn't parse parameter override rule: '-p gcs_url:='
```

A focused parser case was added before the runner change and reproduced that
failure. The runner now passes the explicit empty string as the literal argument
`gcs_url:=""`. The same assembled ROS argument vector is accepted by the parser,
and the runner suite now passes `10` cases. The workstation supervisor was not
changed, so its size and checksum pins remain unchanged.

The earlier subscriber-only wording applies specifically to the long-running
`record` mode and its `CaptureNode`. Its implementation creates exactly five
acceptance-topic subscriptions and does not create an application publisher,
service client or `AsyncParameterClient`. The preceding `snapshot` mode is
non-mutating but not traffic-free: it calls
`/mavros/param/pull` with `force_pull=True` before reading the MAVROS ROS
parameter cache, which causes a MAVLink parameter transfer without changing a
parameter value.

The two force-pull owners cannot overlap in the implemented sequence. The runner
executes `snapshot` synchronously and waits for its process to destroy its node
and ROS context. Only then does it start the command bridge, whose own complete
force-pull rounds must finish before the live-guard marker. Subscriber-only
`record` mode starts after that marker. A focused ordering assertion now retains
`snapshot -> bridge -> record`.

Only parser contexts, fake transports and focused tests were used for this
correction. No SITL, MAVROS node, bridge runtime, rosbridge, dashboard, browser
or hardware link was started. Block D remains **NOT STARTED**.

**Next steps:** review and publish the corrected Block C change set, then request
explicit approval before preparing the Block D user-run handover.

## Block D first attempt and supervised-launch correction (11/08/2026)

The first user-run helper attempt created
`/home/ghostzero/Desktop/sitl_digital_twin_20260811_150958` and stopped at the
first Rover listener gate:

```text
SITL_PHASE_FAIL phase=sitl-listener rc=1 reason=timeout
SITL_VERDICT=FAIL
```

The retained `sitl.log` contains the `sim_vehicle.py` hand-off to
`run_in_terminal_window.sh`, followed by `Waiting for SITL to exit`, but no Rover
banner or error. `/tmp/Rover.log` was absent, the inherited session had a display,
and `xterm` was installed, so the display-terminal branch had taken ownership of
Rover output. More importantly, that branch cannot satisfy the runner's process
provenance contract: the terminal's child must enter its own session to own the
pseudo-terminal and therefore cannot remain in the supervisor child's process
group. The empty `sitl_state/` directory also shows that Rover did not reach its
state-file write in this attempt.

The runner now launches the pinned Rover ELF directly under `start_child`, with
its working directory set to the run-owned `sitl_state/` directory. The three
ArduPilot defaults use absolute paths and the run-specific overlay remains the
fourth `--defaults` input. This removes `sim_vehicle.py`, the terminal wrapper and
the ArduPilot virtual-environment shell from the SITL child while preserving the
same frame, speed, instance and loopback simulation address.

The failed attempt also reported `SITL_SHUTDOWN_FRAMES=FAIL expected=3` although
the bridge had never started. Cleanup now waits for the three bridge shutdown
frames only when a bridge child was registered. Early failures therefore retain
their primary cause without a false neutralisation error.

Red-first focused cases reproduced both defects before their implementation
changes. The runner suite passes `10` cases afterwards. The corrected SITL
runner has **NOT BEEN RERUN**; the failed run remains the only 11/08 runtime
evidence.

## Guarded physical-FCU workstation/Pi helper pair (11/08/2026)

The user's integration order adds one helper per machine while preserving the
existing safety tiers. It supersedes only the earlier same-day statement that Pi
command integration was outside today's implementation scope. It does not waive
T0a, T0b, T2a or T2b conditions and does not convert static implementation into
physical acceptance.

### Workstation ownership

`tools/real_fcu_digital_twin_workstation.sh` exposes `check|run`. It forces
`ROS_DOMAIN_ID=42`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` and
`ROS_LOCALHOST_ONLY=0`, clearing inherited DDS selectors before sourcing Jazzy.
It requires a clean repository whose `HEAD` matches `origin/main`, validates the
four-file Pi bundle pin, rejects conflicting processes and bound ports, and owns
only loopback rosbridge `127.0.0.1:9090` plus dashboard
`127.0.0.1:8002`.

The workstation does not guess the real boat's servo ordering. It waits for a
fresh bridge status with `state=READY_DISARMED`, `ready=true`, connected,
disarmed, `MANUAL` and fresh feedback. Only then does it emit the bench URL with
the live resolved left/right servo numbers. Shutdown stops the dashboard before
rosbridge and checks that both loopback ports were released.

### Pi ownership and tier separation

`tools/real_fcu_digital_twin_pi.sh` exposes `check|probe|run` and owns the fixed
direct endpoint `/dev/ttyAMA0:57600`. It contains no MAVProxy or UDP fan-out.
Every live mode requires an explicit disarmed start, hardware safety ON,
propellers removed, hull restrained and propulsion isolated.

`probe` is T0b only. It also requires recorded T0a completion and separate T0b
approval, starts MAVROS with only `sys_status` and `param`, requires connected
and disarmed state, confirms that the motor-output safety bit is not enabled,
force-pulls the parameter cache, and reads `BRD_SAFETY_DEFLT`,
`BRD_SAFETY_MASK` and `BRD_SAFETYOPTION`. It requires
`BRD_SAFETY_DEFLT=1`. It contains no parameter write, mode change, arm/disarm,
motor test, safety-state change or RC override, and it never starts the bridge.

`run` additionally requires separate T2a and T2b approval. It completes and
stops the isolated T0b MAVROS process first, proves the serial endpoint is free,
then starts a fresh full MAVROS process with `sys_status`, `param`,
`global_position`, `imu` and `rc_io`. It captures state, GPS, IMU, battery, RC
input and RC output samples before starting the existing command bridge with
`allow_real_fcu=true`, maximum steering `0.20` and maximum throttle `0.12`.
Hardware safety release and arming remain external operator actions; the helper
issues neither. It requires a fresh `READY_DISARMED` bridge state and workstation
node visibility. Planned shutdown requires external disarm before Pi `Ctrl+C`,
then stops the bridge before MAVROS and checks that the serial endpoint is free.

The Pi deployment unit is pinned by
`config/real_fcu_digital_twin_bundle.sha256` and preserves these relative paths:

```text
tools/real_fcu_digital_twin_pi.sh
tools/real_fcu_rc_command_bridge.py
config/mavros_real_fcu_closed_loop_plugins.yaml
config/mavros_real_fcu_t0b_plugins.yaml
```

The established `tools/pi_live_hailo_mavlink_dashboard.sh` remains byte-identical
at `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97`
and remains view-only. The new pair closes only the FCU telemetry and guarded
command/feedback helper structure; it does not absorb the Hailo/camera runtime.
The dashboard's six live FCU statistics and opt-in thrust-control panels already
existed and retain their `39`-test coverage, so no dashboard source change was
needed.

### Static verification

| Check | Result |
| --- | --- |
| Existing workstation preflight suite | PASS, `13` cases |
| Existing Pi lifecycle suite | PASS |
| Corrected SITL runner suite | PASS, `10` cases |
| New physical-helper contract suite | PASS, `13` cases |
| One-shot operator suite | PASS, `5` tests |
| Evidence state/verdict suite | PASS, `9` tests |
| Command-bridge suite | PASS, `21` tests |
| Dashboard suite | PASS, `39`; fail `0` |
| Bash syntax, Python compilation, `node --check` and YAML parsing | PASS |

The helper contract suite uses parser-only ROS contexts, temporary directories
and synthetic status payloads. It checks direct serial ownership, the T0b/full
MAVROS separation, every explicit live gate, safe URL generation, plugin
allowlists, cleanup order, the unchanged view-only helper pin and deployment
bundle integrity.

No corrected SITL run, Pi run, FCU contact, browser session, hardware safety
change, arm/disarm, physical RC override or real thrust occurred during this
implementation. T0a physical inspection remains unscheduled and is still the
first hardware step. A corrected SITL acceptance run and every physical tier
each require a fresh user-run approval and complete host/terminal handover.

## Physical graph-isolation correction (11/08/2026)

The earlier same-day physical-helper section records domain `42` for both
machines. This entry supersedes that value: the physical workstation and Pi
helpers now force `ROS_DOMAIN_ID=43`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` and
`ROS_LOCALHOST_ONLY=0`. The SITL runner remains on domain `42` with localhost-only
discovery.

The correction closes a graph-mixing path rather than a proven direct
SITL-to-FCU override path. A localhost-only SITL publisher does not directly
reach MAVROS on the remote Pi. However, a workstation rosbridge participant on
domain `42` with subnet discovery can match both an orphaned local SITL bridge
and the remote physical bridge. One browser `/command_ingress/rc_axes` publisher
could therefore feed both subscribers, while `/command_ingress/status` from both
bridges could enter the operator display. Publisher-count checking in the bridge
does not discriminate that subscriber-side duplication. A complete SITL stack
was already rejected through occupied workstation ports; orphaned or partial
stack ownership was the remaining process-check gap.

The shared command bridge no longer embeds a domain value. It declares
`expected_domain_id` with an empty, unusable default. When
`allow_real_fcu:=true`, the declared value must be non-empty and exactly match
the process `ROS_DOMAIN_ID` before live parameter resolution or override
publisher creation. The SITL runner passes string value `42`; the physical Pi
runner passes string value `43`. The inhibited branch remains inert without
requiring either domain.

Conflict checking is now symmetric for local ownership. The SITL runner rejects
the physical workstation and Pi helper names. The physical workstation helper
rejects the complete local SITL child set: Rover, both MAVProxy spellings,
legacy `sim_vehicle.py`, MAVROS, the command bridge, evidence recorder, one-shot
operator, rosbridge and dashboard server. Domain separation is the primary
boundary; process checks remain defence in depth for partial or stale stacks.

The four-file Pi deployment manifest was regenerated only after the Pi helper
and shared bridge reached their final bytes:

```text
9c6a7f5d255da4e3faae30503df7a4ddfa859c8a5440b751da206fcc4b21af60  tools/real_fcu_digital_twin_pi.sh
3edd7edbcc12e7ac37a7069b833ad8ee5e6ae7f527b6b550e3eacddf463dcf67  tools/real_fcu_rc_command_bridge.py
215293eab9d97e8da5a941d6cb8130351dfbafc07cca7656a766798a2a32b5fc  config/mavros_real_fcu_closed_loop_plugins.yaml
5e6008314216785f2de53a617ffec72913e52acbef00645a417f19d7279e7a94  config/mavros_real_fcu_t0b_plugins.yaml
```

The focused tests first failed on the missing explicit bridge parameter, both
missing physical-helper conflicts in the SITL runner and the inherited physical
domain `42`. After implementation, verification produced:

| Check | Result |
| --- | --- |
| Existing workstation preflight suite | PASS, `13` cases |
| Corrected SITL runner suite | PASS, `11` cases |
| Physical-helper contract suite | PASS, `14` cases |
| One-shot operator suite | PASS, `5` tests |
| Evidence state/verdict suite | PASS, `9` tests |
| Command-bridge suite | PASS, `22` tests in host context |
| Dashboard suite | PASS, `39`; fail `0` |
| Existing Pi lifecycle suite | PASS |
| Bash syntax, Python compilation, JavaScript syntax and YAML parsing | PASS |
| Four-file Pi deployment checksum | PASS |

The separate simulator-to-VRX bridge remains in place. Its module summary now
describes simulated-thruster integration without naming the deleted, unbuilt C++
reference file; its existing live-rail warning and provisional defaults are
unchanged.

No SITL, MAVProxy, MAVROS, rosbridge, dashboard, Pi helper, FCU link, browser or
hardware runtime was started for this correction. The corrected SITL acceptance
and every physical tier remain **NOT RUN**. T0a remains the first physical gate.
