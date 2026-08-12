# Thursday 13/08/2026 - corrected SITL acceptance and view-only live run

> **PRE-DIARY - NOT STARTED.** Moved unchanged in substance from the 12/08/2026
> plan, which was deferred because that day went to the internship report. This
> file does not authorize work. Every block below needs explicit approval before
> it starts.

## Purpose

Convert the 11/08 static work into runtime evidence. Two runs are in scope and
they run in sequence, never together: the corrected workstation SITL closed loop,
then the workstation/Pi view-only telemetry stack. The guarded physical-FCU
helper pair stays unrun; its first hardware gate is a `T0a` inspection that has
not been scheduled.

## Read first

1. This file.
2. The complete 11/08 diary, especially the last three appended sections:
   `Block D first attempt and supervised-launch correction`,
   `Guarded physical-FCU workstation/Pi helper pair` and
   `Physical graph-isolation correction`:
   `working_diary/2026-08-11_tuesday_digital_twin_thrust_loop_and_helper_integration.md`.
3. `working_diary/2026-08-12_wednesday_internship_report_writing.md` - short. It
   records why this plan moved and the three inaccuracies corrected while moving
   it, including the incomplete commit chain that this file's certification
   section now states in full.
4. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` for the view-only runbook.
5. `tools/live_dashboard_preflight.sh`, `tools/sitl_digital_twin_runner.sh`,
   `tools/real_fcu_rc_command_bridge.py` and their focused suites.

Do not create a second 13/08 diary. Append the day's results to this file only.
Do not rewrite any earlier diary, dated Timeline row or historical hash.

## Repository certification

The 11/08 work landed in five commits, not three. The earlier statement in the
12/08 plan named only the middle three and omitted both the day's core
implementation and the commit that carried the plan itself:

```text
a0f516d  feat(sitl): add guarded digital-twin runner
3097061  feat(fcu): add guarded closed-loop helper pair
fcb346a  chore: remove unbuilt servo command reference
c72e8e5  docs(diary): prepare SITL acceptance and live run
89b5fc1  docs(diary): record landed baseline in the 12/08 plan
```

The pre-deferral baseline was `89b5fc1`. Startup must certify the current
`origin/main` and inspect the documentation commit carrying this deferral, which
landed after that baseline and touches only working-diary files.

Re-certify the current repository state before any run, because
`sitl_verify_repository_state` refuses to start unless the worktree is clean,
`HEAD` equals `origin/main`, and `HEAD` descends from
`d911f8a7cbe52b6c08cdd71391fcac823d9d79c4`. A committed but unpushed state fails
the same check.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git status --short --branch
git rev-parse HEAD origin/main
git rev-list --left-right --count main...origin/main
```

| Result | Action |
| --- | --- |
| Dirty, ahead or diverged | Stop. Finish the commit and push first. |
| `HEAD` differs from `origin/main` | Push, then repeat certification. |
| Behind only | `git pull --ff-only`, then repeat certification. |

Re-measure free disk and require at least `10 GB`. The 11/08 figures of `23G`
and `20G` are stale snapshots, now two days old; re-measure rather than reusing
either.

The operational pin surface count is `13`: nine helper-hash occurrences, one
helper size, two supervisor-hash occurrences and one supervisor size. Earlier
diaries record `12`, which was correct when written and stays untouched.

The deployed Pi helper copy is still stale, carried over from the 10/08 change,
because no transfer has been recorded since. It must be transferred and verified
before the view-only block.

## Carried evidence and exact non-claims

The 11/08 work established, statically only:

- the SITL runner starts the pinned Rover binary directly instead of through
  `sim_vehicle.py`, in the supervisor-owned process group, with output in
  `logs/sitl.log`;
- an explicit `expected_domain_id` bridge parameter, empty by default and
  validated only in the enabled branch, with SITL passing `42` and the physical
  Pi passing `43`;
- graph isolation: SITL on domain `42` with `LOCALHOST` discovery, both physical
  helpers on domain `43` with `SUBNET` discovery;
- focused suites green - preflight `13`, SITL `11`, physical helpers `14`,
  bridge `22`, operator `5`, evidence `9`, dashboard `39`, Pi lifecycle pass.

Nothing above is runtime evidence. The corrected SITL launch has never executed.
The physical helper pair has never contacted an FCU. No arming, no physical
thrust, no Pi command path and no real-boat mapping is claimed.

Three corrections from 11/08 that must not be rediscovered:

1. `sim_vehicle.py` delegates Rover to `run_in_terminal_window.sh`, which selects
   an `xterm` when `DISPLAY` is set. The terminal's child takes a new session, so
   its process group can never match the supervisor's and its output never
   reaches the run log. Launch the binary directly.
2. A ROS 2 parameter override with an empty value is rejected by the parser.
   `-p name:=` fails at `rcl` init; an explicit empty string must be the literal
   token `name:=""`.
3. `LOCALHOST` and `SUBNET` participants on the same host and domain do reach
   each other, so a workstation rosbridge on the physical domain could otherwise
   have spanned an orphaned SITL bridge and the remote physical bridge. Domain
   separation is the primary protection; process guards are secondary.

## Fixed architecture

1. Run the SITL acceptance to completion and tear it down before starting the
   view-only stack. They contend for ports `8002` and `9090` and each supervisor
   rejects the other's process ownership.
2. `tools/pi_live_hailo_mavlink_dashboard.sh` remains view-only and byte-identical
   at `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97`.
3. `tools/real_fcu_digital_twin_workstation.sh` and
   `tools/real_fcu_digital_twin_pi.sh` are the only two operator-facing helpers
   for the physical system. Neither runs today.
4. Operator arm and disarm stay separate one-shot actions. No helper arms,
   disarms or releases a hardware safety state.

## Block A - certify and inspect

Read-only, starts nothing. After repository certification, confirm no SITL,
MAVProxy, MAVROS, rosbridge, dashboard, bridge, evidence-recorder or helper
process is running, and that TCP `5760`, `5762`, `8002`, `9090` and UDP `14600`
are free. Re-run the focused suites and record the counts. Stop and request
approval for Block B.

## Block B - corrected SITL acceptance, user-run

Workstation only, three terminals plus one browser tab. No Pi, no FCU.

Terminal 1 launches the supervisor. Do not source ROS and do not activate the
ArduPilot virtual environment; the runner establishes and validates domain `42`,
`LOCALHOST` discovery and localhost-only mode itself.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
export LIVE_DASHBOARD_LOG_ROOT=/home/ghostzero/Desktop
tools/live_dashboard_preflight.sh sitl
```

The three `SITL_*` timeout variables equal their built-in defaults and may be
exported for explicitness only. Leave Terminal 1 in the foreground.

Expect these markers in order. The first two are what failed on 11/08, so treat
`SITL_PROCESS=READY` as the real repair signal:

```text
SITL_PREFLIGHT=PASS
SITL_PROCESS=READY
SITL_MAVPROXY=READY
SITL_MAVROS=READY
SITL_BRIDGE_GUARD=PASS
SITL_CAPTURE=READY
SITL_DISARMED_READY=PASS
SITL_WEB=READY
SITL_BROWSER=READY
SITL_SESSION=READY
```

Operator sequence, with each one-shot command copied verbatim from Terminal 1
into Terminal 2. Those commands invoke
`/home/ghostzero/venv-ardupilot/bin/python` directly and must be run once each:

1. run the printed `safety-off` command;
2. open the exact bench URL printed by Terminal 1, in one tab;
3. wait for Connected, then click Neutral Now once;
4. run the printed `arm` command; never force-arm;
5. tick the bench-condition box and hold Apply at steering `+0.10`,
   throttle `0.08`;
6. release Apply and return both axes to zero;
7. hold Apply at steering `-0.04`, throttle `0.09`;
8. release Apply, then press the bench E-Stop once;
9. run the printed `disarm` command;
10. wait for automatic teardown. Do not press Ctrl+C on the successful path.

The bench URL carries the live servo mapping parsed from the bridge guard line,
so use the printed URL rather than a remembered one:

```text
http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=N&thrust_right_servo=N
```

Acceptance requires all of:

```text
SITL_ACCEPTANCE=COMPLETE teardown=pending
SITL_VERDICT=PASS
SITL_LOGS=/home/ghostzero/Desktop/sitl_digital_twin_YYYYMMDD_HHMMSS
SITL_SUPERVISOR_EXIT status=0 ... cleanup_rc=0 finalize_rc=0
```

Stop immediately on a non-loopback endpoint, surviving domain `12`, an
already-armed startup, non-`MANUAL` mode, incomplete parameters, stale feedback,
mapping drift, failure to neutralise or an unowned conflicting process. On an
unexpected state release Apply, press Ctrl+C once in Terminal 1, use only the
printed cleanup-disarm command if armed, and do not retry the run.

Extract evidence in Terminal 3 after Terminal 1 exits, replacing `RUN` with the
exact `SITL_LOGS=` path. The subshell keeps an aborted check from closing the
terminal:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat

RUN='/home/ghostzero/Desktop/sitl_digital_twin_YYYYMMDD_HHMMSS'

(
    test -d "$RUN" || { echo "ABORT: invalid run directory: $RUN"; exit 1; }

    for file in \
        evidence/startup.json evidence/ready_disarmed.json \
        evidence/browser_ready.json evidence/arm.json \
        evidence/positive.json evidence/release.json \
        evidence/negative.json evidence/estop.json \
        evidence/disarm.json evidence/teardown.json evidence/verdict.json \
        control/disarm_release_frames.json control/shutdown_frames.json \
        control/teardown_runtime.json
    do
        echo "===== $file ====="
        /usr/bin/python3 -m json.tool "$RUN/$file" || exit 1
    done

    echo "===== capture line counts ====="
    wc -l "$RUN"/captures/*.jsonl

    echo "===== retained hashes ====="
    sha256sum "$RUN"/captures/*.jsonl "$RUN"/evidence/*.json "$RUN"/control/*.json
)
```

`evidence/teardown.json` must report `"pass": true`, and its `runtime.stop_order`
must read `dashboard`, `rosbridge`, `bridge`, `evidence`, `mavros`, `mavproxy`,
`sitl`. Do not start Block C until that file passes and the ports are free.

## Block C - view-only live run, user-run

Workstation, Pi and the physical FCU, observing only. Follow
`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` and the 11/08 handover. Summary of
what differs from the SITL block:

- prerequisites: both machines on `IoT IMT Nord Europe`, control box powered,
  FCU disarmed, propulsion physically isolated, D435I and Hailo attached, Pi
  terminal opened from the physical desktop or a Remmina session with a
  non-empty `DISPLAY`;
- the workstation supervisor is `tools/live_dashboard_preflight.sh run`, which
  prints one compound Pi command to paste unedited into the Pi terminal;
- `WORKSTATION_NODE_SNAPSHOT_RETRY attempt=N/3 missing=...` is benign; only
  `STOP: workstation nodes not visible from the Pi after 3 attempts: ...`
  is terminal;
- arrival requires `topics=7`, being one Hailo overlay topic and six MAVROS
  telemetry topics, and the browser shows six freshness badges;
- the view-only discriminators are a blocked
  `LIVE MAVLINK VIEW-ONLY: blocked mission command joystick_enable` with **no**
  confirmation dialog, and
  `LIVE MAVLINK VIEW-ONLY: blocked dashboard emergency-stop publish`. A dialog
  appearing means the write was not blocked; treat it as a breach and stop
  Pi-first;
- shutdown is Pi first, then the workstation, then the browser.

## Block D - physical helper pair, not run today

The pair is prepared and statically certified only. `T0a` is an inspection gate
and has not been scheduled, so `tools/real_fcu_digital_twin_workstation.sh` and
`tools/real_fcu_digital_twin_pi.sh` are not invoked today in any mode, including
`check`. Any future invocation requires approval for its actual tier. `T0a` and
`T0b` retain their own non-actuating conditions; propeller removal, hull
restraint and isolated propulsion power apply before `T2a` or any actuating
tier, not before the inspection and query tiers.

## Block E - document and wrap

Append the run directories, marker transcripts, measured transitions, evidence
hashes and bounded non-claims to this file. Update living Board, Roadmap and
dashboard text only where runtime behaviour actually changed. Leave dated rows
and earlier diaries untouched.

## Verification by changed surface

| Changed | Required checks |
| --- | --- |
| `tools/live_dashboard_preflight.sh` | `bash -n` on both helpers, both focused shell suites, and re-pin the supervisor size and digest in the test constant and the runbook rows. |
| `tools/sitl_digital_twin_runner.sh` | `bash -n` and the SITL focused suite. |
| `tools/real_fcu_rc_command_bridge.py` | `python3 -m py_compile`, its focused suite, and regenerate `config/real_fcu_digital_twin_bundle.sha256` last. |
| Either physical helper | `bash -n`, the physical focused suite, and regenerate the bundle last. |
| Dashboard JavaScript | `node --check` and the complete dashboard suite. |
| Any tracked change | `git diff --check`. |

## Out of scope

- physical-FCU commands, arming or thrust of any kind;
- running either physical helper, including its `check` subcommand;
- Pi-side command integration or weakening the view-only helper;
- detector, dataset, graph-query or external weekly-diary work;
- rewriting any earlier diary, dated Timeline row or historical hash.

## Wrap

One conventional commit subject per logical change, one line, at most 72
characters. Stage by explicit path. Before committing:

```bash
git status --short --branch
git diff --check
git diff --cached --name-status
git diff --cached --check
```

Inspect the staged content and confirm no intended implementation, test or
documentation file is missing.

Never predict or record the SHA of the commit that contains the day-close text.
Record the pre-edit baseline while drafting. If a landed implementation revision
must be recorded, append it in a later documentation commit; do not attempt to
record that documentation commit's own SHA. This series has produced three
self-referential revision claims that were stale the moment they landed.
