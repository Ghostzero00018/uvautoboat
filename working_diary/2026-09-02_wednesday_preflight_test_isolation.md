# Wednesday 02/09/2026 - Workstation preflight test isolation

Workstation-only. No Pi or FCU access, no ROS services, no VRX, no browser and
no hardware runtime were started.

## Defect

Running the showcase-mode preflight

```bash
REAL_FCU_HAILO_PERSON_STOP=1 bash tools/real_fcu_digital_twin_workstation.sh check
```

failed at revision `12236b5` with

```text
FAIL: run-t2a readiness started requiring the T3a capture node
```

The cause is a non-hermetic test suite, not a production-control fault.
`rfcu_ws_check` runs `tools/test_real_fcu_digital_twin_helpers.sh` with the
operator's own environment. `tools/real_fcu_digital_twin_pi.sh:22` resolves
`RFCU_PI_HAILO_PERSON_STOP="${REAL_FCU_HAILO_PERSON_STOP:-0}"` when it is
sourced, so the ambient showcase flag reached the ordinary T2a fixture at
`tools/test_real_fcu_digital_twin_helpers.sh:528-540`. That fixture stubs
`ros2` to return only `/rosbridge_websocket` and `/rosapi`. With the flag
inherited, `rfcu_pi_wait_workstation_nodes` took the
`RFCU_PI_HAILO_PERSON_STOP -eq 1` branch, required
`/person_stop_monitor_node` and `/web_video_server`, matched no branch and
timed out. The failure message names the T3a capture node because it describes
the regression that assertion was originally written to guard, not this cause.

The reported flag is one member of a family, but the family is not read at one
moment. The selectors resolve at source time, as
`RFCU_PI_HAILO_PERSON_STOP="${REAL_FCU_HAILO_PERSON_STOP:-0}"` does. The
physical declarations `REAL_FCU_PROPELLERS_FITTED`,
`REAL_FCU_PROPELLERS_REMOVED`, `REAL_FCU_SAFETY_ON`,
`REAL_FCU_HULL_RESTRAINED`, `REAL_FCU_PROPULSION_ISOLATED` and
`REAL_FCU_T3A_APPROVED` are read later, when a gate function executes:
`tools/real_fcu_digital_twin_pi.sh:140-177` passes their names to the
flag-requirement helpers, and `tools/real_fcu_digital_twin_pi.sh:811-816`
expands them directly. So the ambient value is read at source time or at gate
execution depending on the variable, and both are reachable from an ambient
shell. A leaked declaration flag could have produced a false green rather than
a visible failure, so the fix covers the whole family rather than the one
variable that surfaced.

## Fix

`tools/test_real_fcu_digital_twin_helpers.sh` gained
`rfcu_test_scrub_ambient_operator_env`, which unsets every `REAL_FCU_*` name
via `${!REAL_FCU_@}` prefix expansion, and one call to it before any case runs.
Prefix expansion is used instead of a fixed list so a newly added operator flag
is isolated without editing the suite. Cases that exercise a flag continue to
set it explicitly; the Hailo readiness cases already set
`RFCU_PI_HAILO_PERSON_STOP=1` in their own subshells and are unchanged.

The production helpers are untouched. `rfcu_ws_static_preflight` still
validates the ambient `REAL_FCU_HAILO_PERSON_STOP` as a binary flag and still
performs its Hailo-specific checks, because only the test suite is scrubbed.

Five cases were added, taking the suite from `55` to `60`:

1. the suite-entry scrub call itself ran;
2. the scrub clears a deliberately polluted `REAL_FCU_*` environment, leaving
   no residue;
3. the ordinary T2a readiness fixture reaches readiness when the caller
   exported `REAL_FCU_HAILO_PERSON_STOP=1`;
4. a control asserting that the same fixture without the scrub still fails; and
5. no ambient name can suppress the suite's final `PASS cases=` marker.

Case 1 exists because cases 2 and 3 call the scrub function themselves, so
deleting the real suite-entry call would leave them green in a clean
environment. It re-executes this file with a polluted environment and the
reserved argument `--rfcu-internal-entry-scrub-probe`. That mode sits
immediately after the entry call, prints any surviving `REAL_FCU_*` names and
exits before any fixture runs, so the assertion is bound to the entry call
rather than to a separate invocation of the function.

Case 4 exists so case 3 cannot rot into a vacuous pass. If a future change
stops the ambient value from reaching a sourced helper, the control fails and
says the isolation cases no longer prove anything.

Case 5 exists because `rfcu_ws_check` trusts this file's exit code alone. Any
environment name able to end the run early would report success while skipping
every case, which is a worse failure than the one this day started with. The
case re-executes the suite with the historical probe names and a showcase flag
exported and requires the final marker to appear. The reserved argument
`--rfcu-internal-nested-run` suppresses only case 5 inside the nested run, so
it cannot recurse; the nested marker reports one case fewer than the outer run.

### Correction during review - the first implementation was itself a bypass

The re-entry probe was first triggered by an environment variable,
`RFCU_TEST_ENTRY_SCRUB_PROBE`. That was wrong in exactly the way this day's
work is about. Because the variable is ambient,
`RFCU_TEST_ENTRY_SCRUB_PROBE=1 bash tools/test_real_fcu_digital_twin_helpers.sh`
returned `rc=0` with empty output: the suite exited before any case ran, and
`rfcu_ws_check`, which reads only the exit code, would have reported a passing
preflight having executed nothing.

Both internal modes are now reserved arguments. Arguments cannot leak in from
the operator's shell, and preflight invokes this file with none. The
`RFCU_TEST_NESTED_RUN` guard is a plain assignment before the argument switch,
so an ambient value of that name cannot enable nested mode either; setting it
still gives `PASS cases=60`. Case 5 above is the standing regression for this
whole class.

## Verification

Red was the reported failure at `12236b5`. Green is the same command's test
content passing with the flag set. Each new case was also exercised
individually: the scrub left no residue, the polluted T2a fixture reached
readiness, and the unscrubbed control failed as required.

Cases 1 and 5 were each proved against a mutant, both built and run outside the
repository so no untracked file was left behind.

Mutant A removed only the suite-entry scrub call. Under `env -i` it exited `1`
with `FAIL: the suite-entry scrub call did not run:` followed by the polluted
names, while the unmutated suite gave `PASS cases=60` from the same location.

Mutant B reintroduced an environment-triggered early exit, the defect described
above. It exited `1` with `FAIL: an ambient name suppressed the suite marker:`
and an empty marker, and the bypass it restores reproduces as `rc=0` with empty
output. Case 5 therefore catches this class rather than only the one variable
name that was used.

Case 5 runs the suite a second time, so the helper suite now takes about `11`
seconds instead of about `5`. That is the cost of proving the exit code cannot
be a lie, and it is paid once per preflight.

The closed bypass was retested directly:
`RFCU_TEST_ENTRY_SCRUB_PROBE=1 bash tools/test_real_fcu_digital_twin_helpers.sh`
now gives `rc=0` with `PASS cases=60`. `RFCU_TEST_ENTRY_PROBE=1`,
`RFCU_TEST_PROBE=1` and `RFCU_TEST_NESTED_RUN=1` each give the same.

| Suite | Clean shell | Polluted shell |
| --- | --- | --- |
| real-FCU helper | `PASS cases=60` | `PASS cases=60` |
| FCU-to-VRX shell | `PASS cases=30` | `PASS cases=30` |
| RC command bridge | `62` | `62` |
| command/feedback capture | `37` | `37` |
| dashboard Node | `96/96` | `96/96` |
| person-stop monitor | `37` | `37` |

These counts are the state of the first change, committed as `3c57fa0`. The
second change below takes the helper suite to `66`; the other suites are
unaffected by it.

The polluted shell exported `REAL_FCU_HAILO_PERSON_STOP=1`,
`REAL_FCU_PROPELLERS_FITTED=true`, `REAL_FCU_T3A_APPROVED=yes`,
`REAL_FCU_SAFETY_ON=true`, `REAL_FCU_PROPELLERS_REMOVED=true` and
`REAL_FCU_HULL_RESTRAINED=true`. The bundle manifest verified `4/4` and
`git diff --check` is clean.

The internal `RFCU_PI_*` and `RFCU_WS_*` names were probed as a second possible
ingress and are not one: sourcing a helper assigns them unconditionally, and
the suite sets them per case. `RFCU_PI_HAILO_PERSON_STOP=1`,
`RFCU_PI_RUN_MODE=run-t3a` and `RFCU_PI_ROS_SETUP=/nonexistent` each left
`PASS cases=58` before case 1 was added.

`REAL_FCU_HAILO_PERSON_STOP=1 bash tools/real_fcu_digital_twin_workstation.sh
check` could not be run end to end from the worktree, because
`rfcu_ws_verify_repository` requires a clean tree and the fix was uncommitted.
Everything downstream of that gate was exercised with the gate stubbed and
passed in showcase mode, including the Hailo-specific `web_video_server` and
person-stop monitor checks. The full command is expected to pass once the fix
lands; that is not yet observed.

## Workstation-only preflight pipelines

All of the following are workstation-only. None starts a service, a browser, a
simulator or any hardware link, and each ends `runtime=not-started`. Run them
from one terminal at the repository root with the ROS environment sourced:

```bash
cd ~/seal_ws/src/uvautoboat && source /opt/ros/jazzy/setup.bash
```

`rfcu_ws_check` requires a clean worktree, so pipeline 1 only runs once the
day's changes are committed. The other pipelines run from a dirty worktree.

### Pipeline 1 - real-FCU workstation preflight

```bash
bash tools/real_fcu_digital_twin_workstation.sh check
```

```bash
REAL_FCU_HAILO_PERSON_STOP=1 bash tools/real_fcu_digital_twin_workstation.sh check
```

Runs the helper suite, the RC bridge and capture suites, `node --check` on the
dashboard and the full dashboard Node suite. Both commands end with
`REAL_FCU_WORKSTATION_CHECK=PASS tests=helper,bridge,capture,dashboard
runtime=not-started ports=8002,9090`, and the showcase command ends
`ports=8002,8080,9090`. The marker lists exactly the ports inspected, so those
are the ports that must be free for each command.

### Pipeline 2 - FCU-to-VRX workstation preflight

```bash
bash tools/fcu_to_vrx_workstation.sh check
```

Expect `FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=32 python_tests=48
runtime=not-started`.

### Pipeline 3 - focused suites, for a dirty worktree

```bash
bash tools/test_real_fcu_digital_twin_helpers.sh
bash tools/test_fcu_to_vrx_workstation.sh
python3 tools/test_real_fcu_rc_command_bridge.py
python3 tools/test_real_fcu_command_feedback_capture.py
( cd web_dashboard/autoboat && node --check app.js \
  && node --test --test-isolation=none test/*.test.js )
( cd plan && python3 -m pytest -q test/test_person_stop_monitor.py )
```

Expect `PASS cases=69`, `PASS cases=32`, `Ran 62 tests ... OK`,
`Ran 37 tests ... OK`, `pass 96` with `fail 0`, and `37 passed`. The
`plan` suite must be run from `plan/`; from the repository root its import
fails. A whole-repository `pytest` run cannot collect at all, because
`control/test/test_copyright.py` and `plan/test/test_copyright.py` collide -
pre-existing and unrelated to this change.

### Pipeline 4 - environment isolation

```bash
REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PROPELLERS_FITTED=true \
  REAL_FCU_T3A_APPROVED=yes REAL_FCU_SAFETY_ON=true \
  bash tools/test_real_fcu_digital_twin_helpers.sh
```

Expect `PASS cases=69`, identical to the clean-shell run. A different count, or
any output that is not the marker, means the isolation regressed.

### Pipeline 5 - integrity

```bash
sha256sum -c config/real_fcu_digital_twin_bundle.sha256
bash -n tools/test_real_fcu_digital_twin_helpers.sh
git diff --check
git status --short
```

Expect four `OK` lines, no syntax output, no whitespace output, and only the
intended files listed. `git diff --check` skips untracked files; check a new
file with `git diff --no-index --check /dev/null <path>`, where exit `1` means
the files differ and exit `2` means a real whitespace error.

## Second change - the two workstation-helper defects, now repaired

`tools/real_fcu_digital_twin_workstation.sh:155` reads

```bash
state="$(ss -H -ltn)" || rfcu_ws_fail 'cannot inspect workstation TCP ports'
```

and `rfcu_ws_fail` returns `1` rather than exiting. The guard is therefore
fail-closed only while `set -e` is in force. Stubbing `ss` to fail and calling
`rfcu_ws_reject_listening_ports` from an `if` reproduces
`PORT_CHECK_FAIL_OPEN=YES`: the function continues past the failed inspection
and returns success. Called plainly, as `rfcu_ws_static_preflight` does today,
it aborts, so the fault is latent on the current path rather than active. It
remains a real defect because the guard's correctness rests on the caller's
shell options instead of its own structure, and any future `if`, `&&` or `||`
around it turns the port check into a silent pass.

The `REAL_FCU_WORKSTATION_CHECK=PASS` marker also hardcodes
`ports=8002,9090`. Port `8080` is added to the checked list when Hailo mode is
enabled, so in showcase mode the marker under-reports what it covered.

Both were separately authorised after the isolation fix landed at `3c57fa0`,
and both are repaired here.

### Guards no longer depend on `set -e`

The fix is at the definition, not the one call site. `rfcu_ws_fail` now exits
instead of returning, so all `48` guards of the form
`... || rfcu_ws_fail '...'` are fail-closed regardless of how their enclosing
function is called. Patching only line `155` would have left the other `47`
carrying the same latent fault.

The definition-level change was checked for blast radius first. Eleven
functions call `rfcu_ws_fail`; none of them is consumed conditionally anywhere
in the helper, the EXIT trap `rfcu_ws_cleanup` never calls it, and the three
other files that mention `real_fcu_digital_twin_workstation.sh` name it only in
conflict patterns and manifest lists - none sources it or calls an `rfcu_ws_`
function. Every call site of the eleven is a plain statement.

Stubbing `ss` to fail and calling `rfcu_ws_reject_listening_ports` from an `if`
now prints only `STOP: cannot inspect workstation TCP ports`. Neither
`PORT_CHECK_FAIL_OPEN` nor `CONTINUED_PAST_GUARD` appears.

### The marker reports the ports it checked

`rfcu_ws_checked_ports` is now the single source of truth, emitting `8002`,
then `8080` when Hailo mode is enabled, then `9090`. The rejection loop reads
it through `mapfile`, and the PASS marker reads it through
`rfcu_ws_checked_ports_csv`, so the two cannot drift apart again. The order
matches the existing `REAL_FCU_WORKSTATION_SERVICES=PASS` markers, which were
already mode-correct and are unchanged.

Verified with the worktree gate stubbed:

```text
REAL_FCU_WORKSTATION_CHECK=PASS ... ports=8002,9090
REAL_FCU_WORKSTATION_CHECK=PASS ... ports=8002,8080,9090
```

### Coverage

Six cases were added, `60` to `66`: a failed `ss` cannot be continued past from
a suppressing context; `rfcu_ws_fail` does not return to its caller; the checked
list is `8002,9090` and `8002,8080,9090` by mode; the check marker derives its
list and hardcodes no port; an empty checked-port list is rejected rather than
inspected as clean; and a listener on `8080` blocks showcase mode while being
ignored otherwise. The last of those is what makes the extra marker entry
meaningful rather than decorative.

The empty-list case covers a hole introduced by the fix itself. `mapfile -t
ports < <(rfcu_ws_checked_ports)` reads through a process substitution, whose
exit status is invisible to the caller, so a failing producer would have left
the loop inspecting nothing and reporting a clean port check - a new instance of
the very class being repaired. The list is now required to hold at least the two
ports that are always checked.

Four mutants of the workstation helper were each caught:

| Mutant | Reported |
| --- | --- |
| `rfcu_ws_fail` returns instead of exiting | `a failed ss inspection did not stop the preflight: PORT_CHECK_FAIL_OPEN` |
| marker port list hardcoded again | `the check marker no longer derives its port list` |
| `8080` dropped from the checked list | `checked ports for Hailo=1 were 8002,9090, expected 8002,8080,9090` |
| empty-list guard removed | `an empty checked-port list was accepted as a clean port check` |

### Two harness faults found while writing this

Making `rfcu_ws_fail` exit turned three command substitutions in the test suite
into silent aborts: `X="$(bash -c '...')"` where the inner shell now exits `1`
fails the assignment, and `set -e` ends the suite with no output at all. One
new assertion was also written as `grep -q ... && fail_test`, which aborts when
the grep correctly finds nothing - the same `set -e` and-or shape this day is
about, written into the fix for it. All four are corrected: the capture sites
end in `|| true` so the assertion runs and reports, and the assertion is an
`if`.

The nested-marker case also mislabelled every one of these as an ambient
suppression, because it ran early and reported the nested run's last line as
its own cause. It now runs last, so a real defect is reported by the outer
run's own case first, and it distinguishes an empty nested run - the genuine
suppression signature - from a nested run that failed for some other reason.

## Third change - the same class swept across the remaining helpers

With the workstation helper repaired at `2a769d7`, every abort helper in the
repository was checked rather than assumed. Five exist:

| Helper | Verdict |
| --- | --- |
| `rfcu_ws_fail` | fixed at `2a769d7` |
| `fcuvrx_fail` | same fault, fixed here |
| `rfcu_pi_fail` | same fault, fixed on approval - see the fourth change |
| `adj_fail` in the SITL adjudicator | accumulator, sets `ADJ_RESULT=1` by design |
| `fail` in the health check | reporter, increments a counter; zero or-branch call sites |

`tools/sitl_digital_twin_runner.sh` has no abort helper and uses `exit 1`
directly in `25` places, so it was already fail-closed.

### FCU-to-VRX supervisor

`fcuvrx_fail` returned, and `55` of its guards have code after them inside their
own function, so a failed PWM-rail or ROS-environment check fell through to the
later checks in the same function. One site already carried a hand-applied
`|| return 1` after the failure call - the fault was known and patched at one
place out of `60`. `fcuvrx_fail` now exits, and that lone workaround was removed
as redundant.

Blast radius was checked the same way as before: `16` functions call it, none is
consumed conditionally, `fcuvrx_cleanup` never calls it, and the EXIT, INT and
TERM traps are unchanged, so cleanup still runs.

Editing the supervisor made its checksum pin stale, which the suite caught
immediately. The pin in `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` was
updated to the new digest, and no other surface pins that file.

Two cases were added, `30` to `32`: a failed guard cannot be continued past, and
`fcuvrx_fail` does not return to its caller.

### The check marker stated its own suite sizes as literals

`FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=30 python_tests=48` was accurate
but unverified, so it would have drifted silently the moment a suite grew - the
same class as the port marker, one step earlier. A final assertion now compares
both numbers against what the suites actually report. It caught the drift its
own change created on the first run, and the marker now reads `shell_cases=32`.

That assertion deliberately is not counted as a case and runs after every
`pass_case`, so `CASE_COUNT` is final when compared; counting it would have
measured the marker against a total excluding the comparison itself.

Both changes were proved load-bearing against mutants. A whole-suite mutant run
is masked by the checksum pin, which fires first on any edited supervisor, so
each assertion was exercised directly: the returning mutant yields
`CONTINUED_PAST_GUARD` where the real file yields nothing, and a marker reading
`shell_cases=30` fails against a suite of `32`.

### Repository lint

`plan/test/test_person_stop_monitor.py:17` imported `PersonStopMonitor` before
`detection_publisher_binding`, failing `flake8` with `I101`. The names are now
in order. `plan` reports `67 passed, 1 skipped` with no failures; it was
`1 failed, 66 passed` at `3c57fa0` and predates every change made today.

### Not fixed, and why

A whole-repository `pytest` run still cannot collect, because
`control/test/test_copyright.py` and `plan/test/test_copyright.py` resolve to
the same module name. `--import-mode=importlib` does not help: the failure comes
from `launch_testing/pytest/hooks.py`, which calls `import_path` itself and
bypasses the setting. The supported path is per-package testing, which works, so
this is left alone and documented in the pipelines above rather than worked
around by adding `__init__.py` files that would change ament test discovery.

## Fourth change - the Pi runtime, on explicit approval

`rfcu_pi_fail` carried the same fault and the largest instance of it: `123`
guards had code after them inside their own function, `13` of those in
`rfcu_pi_run` itself, so a failed readiness or safety gate could fall through to
the next run step rather than stopping the run. It now exits.

This file is the Pi-side runtime that drives the thrusters, so the change was
cleared before being made rather than after:

- `23` functions call `rfcu_pi_fail`; none is consumed conditionally anywhere in
  the helper.
- No call site sits inside a subshell or command substitution, where `exit`
  would only leave the subshell and the guard would still be continued past.
- The EXIT trap is installed in `rfcu_pi_run` before any child is started, so
  every failure after that point still runs `rfcu_pi_cleanup`, which performs
  the T3a safe-closeout gate and the final connected/disarmed capture.
- `rfcu_pi_cleanup` is re-entry guarded by `RFCU_PI_CLEANING`, clears its own
  EXIT trap and runs under `set +e`. That last point made the reachability check
  necessary rather than nice to have: with `set -e` off inside the closeout, a
  guard failing there would have been fail-open in the safety path itself.
  Transitively, `rfcu_pi_cleanup` reaches `15` functions, `rfcu_pi_on_interrupt`
  `4` and `rfcu_pi_on_term` `3`, and none of the `22` calls `rfcu_pi_fail`.

Because the helper is a bundle member, `config/real_fcu_digital_twin_bundle.sha256`
was regenerated. Its `tools/real_fcu_digital_twin_pi.sh` entry moved from
`5c6fca19` to `43a4775f`; the other three entries are unchanged. The manifest
gate caught the stale digest before the regeneration, which is the gate working.

Three cases were added, `66` to `69`: a failed Pi guard cannot be continued past
from a suppressing context; `rfcu_pi_fail` does not return to its caller; and
none of the three closeout handlers reaches `rfcu_pi_fail`. The third is a
standing guard on the clearance above, so a later edit that routes a guard into
the closeout fails the suite instead of silently making the closeout abortable.

Sourcing the helper turns on `set -e`, which masks this fault in a plain call
path, so the guard probe reads through an `if` deliberately.

### A vacuous assertion in all three suites

The `does not return` probes were written as `source; <fail> probe; printf
RETURNED`. Sourcing any of the three helpers enables `set -e`, under which a
*returning* failure aborts the probe before the marker prints - so the assertion
passed against a returning implementation and proved nothing. Confirmed against
the mutants: all three reported PASSES where they should have failed.

All three now run `set +e` after sourcing. Re-checked against the same mutants,
each correctly reports RETURNED and fails, while the real helpers terminate and
pass. The equivalent workstation and VRX assertions, written earlier today, had
the same flaw and are fixed with them.

### Verification

Cases A and C were proved load-bearing against mutants of the Pi helper. A
whole-suite mutant run is masked, as with the VRX checksum pin, because a
scratchpad path trips a path-dependent assertion first, so each assertion was
exercised directly. The returning mutant yields `CONTINUED_PAST_GUARD` where the
real helper yields nothing, and a mutant whose `rfcu_pi_cleanup` calls
`rfcu_pi_fail` is reported as reaching it.

## Browser verification of the hardware-safety badge

Run at 03:43-03:44 on 02/09/2026 against `0f2f5ca`, workstation only: rosbridge
on `9090`, `serve_dashboard.py` on `8002`, both bound to `127.0.0.1`, all three
terminals on `ROS_DOMAIN_ID=43`. No Pi, no FCU, no MAVROS, no simulator.

The bridge status was driven synthetically with `ros2 topic pub -r 5` on
`/command_ingress/status` as `std_msgs/String` carrying JSON. The `5` Hz rate
matters: `FCU_BENCH_STATUS_MAX_AGE_MS` is `500`, so a one-shot publish would
show for half a second and then correctly age out, which reads as a fault.

The rosbridge log records `Subscribed to /command_ingress/status` for both page
loads, confirming the badge subscription is unconditional. No URL parameter was
used; `enable_fcu_bench_control=1` gates command publication, not this
read-only reading.

| Stimulus | Published | Badge |
| --- | --- | --- |
| `hardware_safety: ENGAGED` | 73 messages | `ENGAGED (motor output suppressed)`, clear |
| `hardware_safety: RELEASED` | 93 messages | `RELEASED (suppression off)`, critical |
| publisher stopped | - | falls back to `Unknown (stale)` within the `500` ms window |
| `{not json` | 46 messages | `Unknown (stale)`, with Loop State reading `Invalid bridge status` |
| rosbridge stopped | - | returns to `Unknown (stale)` rather than holding the last reading |

All five matched. The three staleness paths are the ones added on 01/09/2026;
before that change the last value stayed on screen indefinitely.

Teardown was clean: all three services stopped, ports `8002`, `8080` and `9090`
released, no stray `serve_dashboard.py`, `rosbridge_websocket` or `topic pub`
process, and the worktree unchanged. Nothing was written.

### What this establishes, and what it does not

It establishes the browser rendering and staleness behaviour end to end, through
a real rosbridge and a real DOM, matching what the five Node cases assert
headlessly.

It does not exercise `hardware_safety_state()` against a real switch. The
classifier reads `MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS` from a real
`/mavros/sys_status`, and every reading in this run was a string chosen by the
publisher. A `RELEASED` badge here is not a statement about any hardware. That
half remains covered only by the Python suite until the FCU is in the loop.

## Documentation audit

Every tracked markdown file outside `working_diary/` was checked against the
current bytes. Dated entries in `Board.md` and `wiki/Roadmap.md` were read as
append-only records, accurate for their own revision, and were not touched.
Three claims were genuinely stale.

`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` pinned the VRX supervisor at
`35,497` bytes when the file was `35,799`. The suite checks only the SHA-256
rows of that table, so the size beside them had drifted silently while the
digest was kept current. The pin test now checks both sizes as well as both
digests, and it reproduced the stale figure before the fix. Extending it grew
the suite from `32` to `33`, which the marker-consistency assertion added
earlier today caught immediately - the same guard working on its own author.

`web_dashboard/autoboat/README_autoboat_dashboard.md` stated that the FCU bench
component has "two dashboard rows ... with deliberately different provenance"
and tabled Requested RC Demand and Measured Motor Output. The hardware-safety
badge is a third reading in that component, and its provenance is exactly what
the table exists to separate: the flight controller's own report of the switch,
neither a browser request nor a measured PWM. The table now carries all three,
with the read-only contract, the three rendered strings and both staleness
windows spelled out, and the explicit statement that a released switch does not
mean propulsion is powered.

The same file described `/command_ingress/status` without the `hardware_safety`
and `sys_status_age_ms` fields added on 01/09/2026. The topic row now names
them.

Two stamps were bumped to 02/09/2026: the `Board.md` header, which still read
01/09/2026 while the file carried 02/09/2026 rows, and the dashboard README
footer.

Checked and deliberately left alone: the dated `Board.md` and `wiki/Roadmap.md`
rows quoting `55`, `60` and `66`; the runbook's `55` and `91/91` figures, which
sit inside a superseded `NOT COMMITTED` entry; the four 23/07/2026 digests the
runbook labels as not being repository revisions; and the `legacy/` tree. No
document described any helper as returning rather than exiting on failure, and
none quoted a `CHECK=PASS` marker as an operator expectation, so today's
fail-closed and port-marker changes invalidated no prose.

One gap is recorded rather than filled: no operator-facing document tells a
reader that the badge exists. The runbook asks the operator to confirm hardware
safety by eye at ten points, and the dashboard now shows the flight
controller's own reading of it. Adding that cross-check is an enhancement, not
a correction, so it is left for an explicit decision.

## Current-revision SITL acceptance - 02/09/2026

Run on clean published revision `0ed5525`, with `HEAD` equal to `origin/main`,
divergence `0/0` and an unchanged worktree before and after. Workstation only:
no Pi, no FCU, no physical hardware. Evidence root
`/home/ghostzero/Desktop/sitl_digital_twin_20260902_041033`.

This closes the gap recorded below. The last accepted SITL revision predated
`da6627e`, `12236b5`, `3c57fa0`, `2a769d7`, `0f2f5ca` and `0ed5525`, so no
accepted simulator result covered the current bytes.

### Pinned environment

The runner's own guards passed before it started anything: ArduPilot at
`3fc7011a`, Rover binary `4939888` bytes, and `HEAD` descending from the
approved baseline `d911f8a7`. MAVProxy, the digital-twin plugin YAML, the
operator and evidence helpers and the MAVROS `apm_config.yaml` were all
confirmed present beforehand, so the run reached its first phase rather than
aborting on a stale pin.

### Sequence

`SITL_PREFLIGHT=PASS domain=42 discovery=LOCALHOST localhost_only=1`, SITL
`motorboat-skid` instance `0` on ports `5760,5762`, MAVProxy `master=tcp:
127.0.0.1:5760 out=udp:127.0.0.1:14600 source=254.190 target=1.1
reconnect=false`, MAVROS `parameters=1283 state=disarmed mode=MANUAL`.

Three operator gates were claimed and released one-shot -- `safety-off`, `arm`,
`disarm` -- each leaving a claim, gate and result file. The browser drove the
demand phases from
`http://127.0.0.1:8002/?enable_fcu_bench_control=1&thrust_left_servo=1&thrust_right_servo=3`:
one disabled frame to clear the browser gate, a positive hold at steering
`+0.10` and throttle `0.08`, a release to zero, a negative hold at steering
`-0.04` and throttle `0.09`, then a single latched E-Stop.

`SITL_ACCEPTANCE=COMPLETE`, then teardown of all seven children and
`SITL_SUPERVISOR_EXIT status=0 trigger=exit signal=none
stop_phase=acceptance-complete failed_phase=none cleanup_rc=0 finalize_rc=0`.

### Independent adjudication

The runner's own `SITL_VERDICT=PASS` was not taken as the result.
`tools/sitl_digital_twin_adjudicate.sh` was run separately against the evidence
root and returned `SITL_ADJUDICATION=PASS` with no `FAIL` line anywhere:

| Check | Result |
| --- | --- |
| Nine evidence phases, `startup` through `disarm` | each `SITL_EVIDENCE=PASS` |
| `verdict.json` | `PASS`, `session_complete: true`, `missing: []`, ten digests |
| Disarm release frames | `PASS count=3` |
| Shutdown frames | `PASS count=3` |
| Stop order | `PASS order=dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl` |
| Control cross-check, verdict, teardown | `PASS` |
| Ports `5760`, `5762`, `8002`, `9090`, `14600` | `SITL_POSTRUN_PORTS=FREE` |
| Twelve process names | `SITL_POSTRUN_PROCESSES=FREE` |

Teardown was also checked directly before adjudicating, so the clean result is
not the adjudicator grading its own run: no surviving `ardurover`, `mavproxy`,
`mavros_node`, bridge, evidence, rosbridge or dashboard process, every port
released, and the worktree unchanged.

### What this does not cover

The bridge guard resolved `steering=RC1 throttle=RC3 left=SERVO1 right=SERVO3`.
That is the reverse of the boat, which resolves `left=SERVO3 right=SERVO1`, and
it is correct behaviour rather than a defect:
`tools/real_fcu_rc_command_bridge.py:245-250` scans `SERVO1..16_FUNCTION` for
functions `73` and `74` and requires exactly one assignment each, so it reads
whichever vehicle it is attached to. What passed is that the guard resolves a
mapping and refuses ambiguity. **This run is not evidence that the boat's
left/right channel assignment is correct.**

It also does not exercise `tools/real_fcu_digital_twin_pi.sh`. SITL runs the
command bridge, not the Pi runtime, so the `123` guards made fail-closed
earlier today remain verified offline only.

## Pi bundle deployment and certification - 02/09/2026

Published revision `778e069` was transferred to the Pi and certified
non-actuating. Pi powered; no flight controller, propulsion or other hardware
powered. Nothing actuated and no runtime started.

Endpoint `imt-aqua-drone@10.120.2.249`, host `imtaquadrone-desktop`. Key
authentication is not configured from the workstation, so every remote step
prompted for the account password and was run by the operator; the four
checksum-pinned one-shot helpers used on 01/09/2026 no longer exist in the
tree, so the transfer was direct `ssh` and `scp` from the workstation.

Deployment root
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069`.

### Source parity before transfer

`git status --short` was silent and `HEAD` and `origin/main` were both
`778e069263044de67f625bdc8de73ac54271d3a0`. The four governed members verified
`OK` on the workstation first. They are byte-identical between `0ed5525` and
`778e069`, since the intervening commit was documentation only, so the bundle is
named for the published head without any change to what it governs.

### Pi preconditions

Checked before spending a transfer: all seventeen required commands present, a
writable `~/Desktop` log root, `/dev/ttyAMA0` present, readable, writable and
free, `apm_config.yaml` readable, the `mavros` package resolvable and the
`json, mavros_msgs, rclpy, sensor_msgs, std_msgs, yaml` imports available. No
`MISSING` line and no `SERIAL BUSY`.

The unpowered flight controller does not block this. `rfcu_pi_check` runs
`rfcu_pi_static_preflight` and then logs; the serial endpoint is required to
exist, be read-write and be free, but no link is ever opened, so certification
is possible with the Pi alone.

### Certification

The five-file inventory transferred, the helper was made executable and
`sha256sum -c` passed on the Pi. The manifest digest read
`fedda913bb31698b150f29a96fd82735637e04d5a6ea2b8a573e39724310db58`, matching
the workstation exactly. The four governed hashes were then verified a second
time by `rfcu_pi_verify_bundle` inside `static_preflight`, and the helper
emitted:

```text
[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
```

A second pass retained the evidence at
`/home/ghostzero/Desktop/pi_bundle_certification_20260902_778e069.log` and
reproduced the same marker, so the result is not a single observation.

Every digest the Pi reported was then compared on the workstation against both
the worktree and `HEAD`, rather than read by eye. All five matched both, and the
four governed lines are identical to the manifest line for line. The
`tools/real_fcu_digital_twin_pi.sh` entry reads `43a4775f`, which is the value
the manifest moved to when it was regenerated after the guard change, so the
fail-closed runtime is what is deployed.

Classification: **DEPLOYED / CERTIFIED / NOT RUN**. No probe, MAVROS, command
bridge or run mode was started; no parameter write, arm or propulsion action
occurred, and this grants no run authority.

### First hardware execution of the fail-closed guards

`static_preflight` contains twelve of the `123` guards that could previously be
continued past. All twelve executed on the Pi, twice, and none fired
spuriously. That is real hardware evidence for the guard change, and it is
bounded: the remaining `111`, including the thirteen inside `rfcu_pi_run` and
those in `rfcu_pi_capture_t0b`, `rfcu_pi_probe_snapshot` and the Hailo
preflight, require a run mode and hardware that was not powered.

## Operator documentation for the hardware-safety reading

The gap recorded earlier is filled. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`
gained "Hardware-safety reading on the dashboard": the three rendered strings
and their styles, the read-only contract, and three properties that matter
during a run - `Unknown (stale)` is not `ENGAGED` and proves nothing in either
direction; `RELEASED (suppression off)` reports only that suppression is off and
never that propulsion is powered or that the vehicle is armed; and the reading
appears without `enable_fcu_bench_control=1`, because the page always subscribes
to bridge status even when it creates no command publisher.

Two cross-references were added where the document already directs the operator
at the switch: before enabling the selector, where it asks for the live
hardware-safety state, and at the release-then-arm stop condition. Both frame
the reading as a cross-check on the physical switch, never authority to proceed,
and both say that a contradiction, or a reading stuck at `Unknown (stale)`, is
no observation at all.

### A claim that had to be narrowed before it shipped

The section first stated that no gate in any helper consults the safety state.
That is false. `tools/pi_live_hailo_mavlink_dashboard.sh:2274` defines its own
`hardware_safety_is_on()` and `restored_safe_state()` requires it. The wording
now scopes the guarantee to what is actually proven - the badge is read-only and
only four surfaces in `tools/real_fcu_rc_command_bridge.py` may read the safety
state, enforced by a whitelist test - and names the independent reader so the
two are not confused for each other.

## Correction - the Pi monitor staleness finding was wrong

The finding recorded in the Open section at `2ba2183`, that
`tools/pi_live_hailo_mavlink_dashboard.sh` can act on a stale safety sample, is
withdrawn. It does not hold. No change was made to that file, and none is
needed.

The claim was that `hardware_safety_is_on()` reads `latest_sys_status` with no
staleness check, so a stopped `/mavros/sys_status` stream would let the last
sample answer indefinitely and reach `restored_safe_state()`. The first half is
true: that method applies no bound of its own. The conclusion does not follow,
because every call site is already guarded one level up.

`/mavros/sys_status` is a required subscription at line `2216`, so it is part of
`self.required_topics`, `record_required` timestamps it in `last_seen` on every
message, and `stale_topic` reports any required topic older than
`self.stale_seconds`.

`restored_safe_state()` has exactly three call sites, and all three sit behind
that check:

- line `2297`, `WAIT_BASELINE`: the transition to `READY` is a short-circuit
  `and` whose second term is `self.stale_topic(now) is None`, evaluated before
  `restored_safe_state()`;
- line `2313`, `FINALIZING`, and line `2317`, `COMPLETE`: both are reachable
  only past `stale = self.stale_topic(now)` at line `2302`, which calls
  `abort_seen("REQUIRED_TOPIC_STALE", stale)` and returns when anything is
  stale.

So a stalled `/mavros/sys_status` aborts the observation before the safety
reading is consulted at all. The monitor is fail-closed on this path; the guard
simply lives in the caller rather than in the reader.

The boolean case is also not reachable. `sensors_enabled` arrives as a `uint32`
field on a MAVROS `SysStatus` message and is an `int` in `rclpy`, never a
`bool`.

What went wrong in the review: the reader was inspected and its missing guard
generalised into a system property without tracing its callers. The bridge
needed its own staleness rejection because it publishes a display value on
every status message with no equivalent caller-side abort; this monitor does not
share that shape, and the comparison between them was assumed rather than
checked. A finding about a safety helper should not have been recorded before
its call sites were traced.

No repair, no re-pin: `tools/pi_live_hailo_mavlink_dashboard.sh` is unchanged
and still matches its runbook pin at `0d3f6d1b` and `95,720` bytes.

## Run-path guard map and pre-run contract

Prepared for a single full-stack run before the demo, so a `STOP:` line is
diagnosable on sight rather than read cold.

### Correction - the new bundle is not stricter in the normal path

Recorded earlier, and wrong: that a run which previously proceeded may now stop
at a gate. In the normal invocation path it will not. `rfcu_pi_main` dispatches
`rfcu_pi_run` as a plain statement inside a `case` branch, `set -euo pipefail`
is in force from line `5`, and each `rfcu_pi_fail` is the last command of its
`||` list, so `set -e` already aborted on every one of these guards before the
change. Verified against the same shape - a `case` branch calling a function
whose guard is `false || myfail` - which exits `1` and prints neither
continuation marker.

The fail-closed change is a robustness improvement: the guards no longer depend
on `set -e` being in force or on no caller suppressing it. It is not a
behaviour change for `bash tools/real_fcu_digital_twin_pi.sh run-t3a`. The only
`set +e` in the file is line `1481` inside `rfcu_pi_cleanup`, which reaches no
function that calls `rfcu_pi_fail`.

### The thirteen stop points in `rfcu_pi_run`, lines 1635-1759

| Line | `STOP:` message | Trips when |
| --- | --- | --- |
| 1655 | `unsupported run mode` | the mode argument is not `run-t2a`, `run` or `run-t3a` |
| 1680 | Hailo readiness failure | showcase mode only; the person-stop and video path did not come up |
| 1688 | `T0b MAVROS did not reach connected:true and armed:false` | no FCU link, or the FCU reports armed at start |
| 1691 | `guard-probe MAVROS did not stop cleanly` | the probe process would not stop |
| 1692 | `serial remained owned after guard probe` | `/dev/ttyAMA0` still held after teardown |
| 1698 | `full MAVROS did not reach connected:true and armed:false` | as 1688, for the full runtime |
| 1704 | `bridge did not resolve the complete parameter guard` | the parameter contract below is not satisfied |
| 1711 | T3a propulsion-enable not confirmed | `run-t3a` only; operator confirmation missing or invalid |
| 1723 | `manual hardware-safety release was not confirmed while disarmed` | release not confirmed |
| 1731 | `bridge did not reach fresh READY_DISARMED after the manual safety gate` | bridge did not re-establish readiness after the release |
| 1734 | `...person-stop/video nodes were not discovered` | workstation discovery failed, Hailo enabled |
| 1738 | `...capture nodes were not discovered` | workstation discovery failed, `run-t3a` |
| 1740 | `...rosbridge/rosapi nodes were not discovered` | workstation discovery failed, otherwise |

Lines 1734, 1738 and 1740 are three messages for one failure, selected by mode.
The discovery guards depend on the workstation side already being up.

### Pre-run parameter contract

Line 1704 is the guard most likely to end a first run, and it is checkable in
advance. `tools/real_fcu_rc_command_bridge.py` enforces these bounds on the
resolved parameters:

| Requirement | Source line |
| --- | --- |
| `RCMAP_ROLL` and `RCMAP_THROTTLE` distinct, each in `1..16` | 241 |
| functions `73` and `74` each with exactly one `SERVO1..16` assignment | 250 |
| `<prefix>DZ` in `1..200` | 267 |
| `<prefix>REVERSED` is `0` or `1` | 269, 292 |
| `<prefix>OPTION` is `0` | 275 |
| `BRD_SAFETY_DEFLT` is `1` | 404 |
| `SYSID_THISMAV` and `SYSID_MYGCS` differ | 474 |
| **`RC_OVERRIDE_TIME` in `(0, 0.5]`** | 492 |
| `DDS_ENABLE` absent or `0` | 503 |

The guard also records `ARMING_CHECK`, `BRD_SAFETY_MASK`, `BRD_SAFETYOPTION`
and `RC_OPTIONS` as critical evidence.

### The single largest risk to a one-shot run

`RC_OVERRIDE_TIME` must be in `(0, 0.5]`. The value has moved: `3.0` was the
restored live value on 31/08/2026, and the 01/09/2026 entry records `0.5` set
for the bounded test and left temporary, with **no rollback-to-`3.0` artifact**
and rollback explicitly open. If the parameter is currently `3.0`, the guard at
line 1704 rejects it and the run ends there.

The last record therefore says the value is compatible, but that is a claim from
01/09/2026 and it has not been read since. It can only be confirmed from the
flight controller. Reading it before starting the supervisors costs nothing and
removes the most likely single cause of a wasted run.

Two related notes from the runbook, not restated in the guard: snapshot mode is
opt-in and requires a MAVProxy `param save` artifact, its exact lowercase
SHA-256 and `REAL_FCU_GUARD_SNAPSHOT_APPROVED=1` together, and the retained
`986`-parameter artifact carrying `RC_OVERRIDE_TIME=3.0` is rejected and must
not be reused. Without those three, the bridge takes the live pull path.

### The other historical run-burner

The 21/08/2026 run ended at the equivalent of line 1688 with `47` of `50` state
samples reading connected and **armed** in `MANUAL`. The gate requires connected
and disarmed, so an FCU already armed when the supervisor starts ends the run
before the bridge or command publisher exist. Starting disarmed is a contract,
not a preference.

## Full-stack run-sheet

Derived from what each supervisor waits on, not from a previous run. **This
order has never been executed end to end in this configuration**, so a first
attempt also tests the order itself. The tier, the timing and the go/no-go are
the operator's; nothing here supplies a physical declaration.

### Binding constraint

Both workstation supervisors must be up and in their waiting state before the
Pi starts, because the Pi's discovery guards at lines `1734`, `1738` and `1740`
look for nodes the workstation side owns. Each supervisor states this itself:
W2 logs `start the approved real-FCU Pi helper now; this terminal waits for
relayed RCOut, outbound twin telemetry and four-stream observer READY`, and W1
logs `waiting for the separately approved Pi helper and READY_DISARMED status`.

W2's message appears before W1 is necessarily running, so it is not the trigger
to start the Pi. Nothing in the source forces W1 before W2 or the reverse; what
is forced is both before the Pi.

Domains: W1 and the Pi on `43` with `SUBNET` discovery, W2 on `77` with
`LOCALHOST` plus a relay onto `43`/`SUBNET`. Each helper exports its own domain,
so it must not be set by hand for W1, W2 or the Pi.

### Before starting anything

- Ports `8002` and `9090` free, and `8080` as well in Hailo mode.
- The flight controller **disarmed**. The 21/08/2026 run ended at the line
  `1688` gate with `47` of `50` state samples connected and armed; the gate
  requires connected and disarmed.
- `RC_OVERRIDE_TIME` read from the flight controller and inside `(0, 0.5]`. It
  was `3.0` on 31/08/2026 and `0.5` on 01/09/2026 left temporary with rollback
  open, and has not been read since. A value of `3.0` ends the run at line
  `1704`.
- The rest of the parameter contract in the section above.

### Step zero, on the Pi - prove the FCU link before spending the stack

Added after the 02/09/2026 attempt stopped at gate `1688` five minutes in. An
isolated MAVROS run answers in about `1.5` seconds what that gate takes up to
`600` to report, and it uses the same allowlist and arguments the helper builds:

```bash
source /opt/ros/jazzy/setup.bash && export ROS_DOMAIN_ID=43 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET ROS_LOCALHOST_ONLY=0 && ros2 run mavros mavros_node --ros-args --params-file /opt/ros/jazzy/share/mavros/launch/apm_config.yaml --params-file /home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069/config/mavros_real_fcu_t0b_plugins.yaml -p fcu_url:=serial:///dev/ttyAMA0:57600 -p 'gcs_url:=""' -p system_id:=255 -p component_id:=191 -p target_system_id:=1 -p target_component_id:=1
```

`CON: Got HEARTBEAT, connected` with `link[1000] detected remote address 1.1`
within a few seconds means the link is good: Ctrl+C and continue to terminal 1.
Nothing within about ten seconds means do not start the stack.

Two details that cost time when missed. The `'gcs_url:=""'` must be
single-quoted, because an unquoted `""` collapses to a bare `gcs_url:=` that the
rcl parser rejects. And this check holds `/dev/ttyAMA0`, so it must be stopped
before the run or the Pi preflight fails on `already in use`.

Reading the raw bytes is the other cheap instrument, when the port is free:

```bash
timeout 3 cat /dev/ttyAMA0 | xxd | head -8
```

A healthy stream shows MAVLink2 magic `fd` at frame starts with a constant
`sysid=1 compid=1` two bytes after the sequence, for example
`fd 1c 00 00 fb 01 01`. Occasional implausible addresses in the MAVROS router
log are **not** a fault signature; they appear on a healthy link too. The
failure signature is the absence of `1.1`, not the presence of others.

### Terminal 1, workstation - W2, the VRX supervisor

Slowest to come up, so it goes first.

`run-real-fcu` requires **ten** environment variables that have no defaults,
plus `FCU_VRX_CORRELATED_OBSERVATION=1`, whose default of `0` it rejects. The
rehearsal below hit them one restart at a time; the whole set is:

```bash
cd ~/seal_ws/src/uvautoboat && source /opt/ros/jazzy/setup.bash && FCU_TO_VRX_READY_TIMEOUT_SECONDS=600 FCU_VRX_LEFT_SERVO_CHANNEL=3 FCU_VRX_RIGHT_SERVO_CHANNEL=1 FCU_VRX_LEFT_PWM_MIN=800 FCU_VRX_LEFT_PWM_NEUTRAL=800 FCU_VRX_LEFT_PWM_MAX=2200 FCU_VRX_RIGHT_PWM_MIN=800 FCU_VRX_RIGHT_PWM_NEUTRAL=800 FCU_VRX_RIGHT_PWM_MAX=2200 FCU_VRX_MAX_THRUST=800.0 FCU_VRX_OBSERVER_STALE_SECONDS=5 FCU_VRX_CORRELATED_OBSERVATION=1 bash tools/fcu_to_vrx_workstation.sh run-real-fcu
```

The channel and rail values must match what the bridge resolves from the flight
controller. `3/1` and `800/800/2200` are what a previous run's own
`PRESTART=PASS` marker recorded and what the rehearsal reproduced; confirm them
against the current vehicle rather than assuming. Both rails must be equal, the
two channels must differ and be in `1..16`, and `MAX_THRUST` must be a finite
decimal above zero.

Wait for `FCU_TO_VRX_WORKSTATION_PRESTART=PASS mode=run-real-fcu domain=77 ...
relay=started relay_domain=43`. Do not start the Pi on this message alone.

The command above sets `FCU_TO_VRX_READY_TIMEOUT_SECONDS=600` deliberately.
The default is `120`, and it bounds six waits including `fcuvrx_wait_relay_ready`
and `fcuvrx_wait_twin_telemetry_ready`. That window opens at `PRESTART=PASS`,
before W1, the capture terminal, the browser and the Pi have even been started,
and the Pi only publishes RCOut after its own probe cycle and full MAVROS reach
connected and disarmed. `120` seconds is not achievable by hand; on expiry W2
exits `status=1` with `STOP: real-FCU RCOut relay did not become ready before
the deadline` and tears VRX down with it. `600` matches the Pi's own
`RFCU_PI_READY_TIMEOUT_SECONDS` default. Raising it only ever permits more time.

### The loop is bidirectional - both directions gate readiness

The twin is a closed loop, and W2 gates on **both** legs plus a four-stream
check after the Pi appears. Watching only the outbound leg proves half a demo.

**Outbound, real FCU drives the simulator.** Dashboard demand goes through the
Pi bridge to the flight controller; the **measured** `/mavros/rc/out` on domain
`43` is read by W2's relay, forwarded over `127.0.0.1:14555`, and converted from
PWM to thrust by the domain `77` bridge onto
`/wamv/thrusters/left|right/thrust` using the configured mapping and rails.

**Return, the simulator reports back to the dashboard.** VRX pose and thrust are
emitted as twin telemetry over `127.0.0.1:14556` onto
`/fcu_to_vrx/twin_telemetry` on domain `43`, schema
`uvautoboat.fcu_to_vrx.twin_telemetry.v1`, source
`fcu_to_vrx_domain77_bridge`. The dashboard subscribes to it and renders actual
VRX pose and left/right thrust, expiring the reading after `2000` ms.

Three markers appear in terminal 1 after the Pi starts, in this order:

| Order | Marker | Proves |
| --- | --- | --- |
| 1 | `FCU_TO_VRX_RC_OUT_RELAY_READY=PASS topic=/mavros/rc/out udp=127.0.0.1:14555 left=SERVO3 right=SERVO1 pwm=800/800/2200` | the outbound leg: real measured RCOut is reaching the relay |
| 2 | `FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS topic=/fcu_to_vrx/twin_telemetry udp=127.0.0.1:14556 schema=uvautoboat.fcu_to_vrx.twin_telemetry.v1 source=fcu_to_vrx_domain77_bridge stale_seconds=5` | the return leg: telemetry is flowing back toward the dashboard |
| 3 | `FCU_TO_VRX_WORKSTATION_READY=PASS ... observer=ready streams=4 relay=ready twin_telemetry=ready` | the four-stream observer gate, `servo_output_raw` plus both thrust streams |

Marker 3 is bounded separately by `FCUVRX_OBSERVER_READY_TIMEOUT_SECONDS`,
default `900`, not by the `600` above.

The end-to-end proof is not a marker at all: it is the dashboard's twin
telemetry panel showing live VRX pose and left/right thrust, which only exists
once the whole loop has closed. Note that `rails=800/800/2200` puts neutral at
minimum, so neutral demand should read zero VRX thrust rather than an idle
value.

### Terminal 2, workstation - W1, the real-FCU supervisor

```bash
cd ~/seal_ws/src/uvautoboat && source /opt/ros/jazzy/setup.bash && bash tools/real_fcu_digital_twin_workstation.sh run
```

Prefix `REAL_FCU_HAILO_PERSON_STOP=1` for the showcase path. Wait for
`waiting for the separately approved Pi helper and READY_DISARMED status`.

### Terminal 3, workstation - the command/feedback capture node, `run-t3a` only

No supervisor starts this node, and the `run-t3a` discovery guard requires
`/real_fcu_command_feedback_capture`. Omitting it stops the Pi at line `1738`
with `workstation rosbridge/rosapi/capture nodes were not discovered`.

The `t3a` tier is **rejected without `--esc-threshold-calibration`**:
`validate_capture_mode` raises `t3a capture tier requires ESC-threshold
calibration`. The flag is accepted only for `t2b` and `t3a`.

```bash
cd ~/seal_ws/src/uvautoboat && source /opt/ros/jazzy/setup.bash && ROS_DOMAIN_ID=43 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET ROS_LOCALHOST_ONLY=0 python3 tools/real_fcu_command_feedback_capture.py t3a --esc-threshold-calibration
```

It validates all three variables exactly against `EXPECTED_ENVIRONMENT` and
refuses otherwise. The tier positional must match the Pi's run mode.

**This terminal is interactive, not fire-and-forget.** On readiness it prints
`REAL_FCU_ESC_THRESHOLD_INPUT=READY commands='<left|right> <stopped|started|not-observed>'
steering=-0.20..0.20 bracket=per-side-pwm release-Apply-before-input=true
recent-active-grace=10s` and expects the operator to type those observations
during the run. It needs a real interactive terminal; started without one it
reaches `REAL_FCU_CAPTURE_READY=PASS` and then ends
`REAL_FCU_CAPTURE_FINAL=FAIL`.

### Terminal 4, workstation - browser

Open the `REAL_FCU_BENCH_URL=` that W1 prints. Confirm the Hardware Safety
reading agrees with the physical switch; a contradiction, or a reading stuck at
`Unknown (stale)`, is no observation.

### Terminal 5, the Pi - last

Only once terminals 1 to 3 are all waiting. From the workstation:

```bash
ssh imt-aqua-drone@10.120.2.249
```

then in `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069`,
with the physical-declaration flags the chosen tier requires, run
`bash tools/real_fcu_digital_twin_pi.sh run-t3a`, or `run-t2a` or `run`. The
flag values are the operator's observation of physical state and are not
recorded here.

### Conflict guards and stray terminals

`rfcu_ws_reject_conflicts` and `fcuvrx_reject_conflicts` both scan with
`pgrep -af -- "$pattern"`. Any process whose argv merely mentions a pattern
counts as a match, including a shell running a compound command that names one.
The rehearsal reproduced this: a sweep command mentioning `rosbridge`, `gz sim`
and similar made the very next preflight report
`STOP: conflicting workstation process found` with no such process running, and
the same preflight passed immediately when run on its own command line. Clear
stray diagnostic terminals before the run, and if a conflict stop looks wrong,
re-run the check by itself before believing it.

### Stop order - reverse, and it matters

Externally disarm first, stop W2, initiate the Pi stop and closeout, then stop
W1 last. W1's stop marker is what lets the Pi finish its closeout, so stopping
W1 early strands the Pi mid-closeout.

## T3a armed-run sheet

Traced from `rfcu_pi_run` and the confirmation functions. Extends the
start-order sheet above with where arming sits. The tier, the timing, the flag
values and the go/no-go are the operator's; none is supplied here.

### Where arming sits

The helper cannot arm. The MAVROS plugin allowlist is `sys_status`, `param`,
`global_position`, `imu`, `rc_io`, with no arming plugin, and line `1753` states
`arming remains external; planned stop requires external disarm before Ctrl+C`.
Arming is external at every point, after `REAL_FCU_T3A_READY=PASS`, and never a
starting condition.

### Starting state the gates require

`rfcu_pi_wait_connected_disarmed` gates both the T0b probe at line `1688` and
the full runtime at line `1698`, and its predicate is exact: `connected` must be
`True` and `armed` must be `False`. A flight controller already armed when the
supervisor starts fails there, before the bridge or command publisher exist.
That is how the 21/08/2026 run ended, with `47` of `50` state samples connected
and armed in `MANUAL`.

So the run begins connected, **disarmed**, hardware safety ON and propulsion
isolated, with propellers fitted, guarding installed and the exclusion zone
clear. `RC_OVERRIDE_TIME` must already be inside `(0, 0.5]`.

### The T3a flags replace the interactive prompts

This differs from `run` and `run-t2a` and is easy to be caught by.
`rfcu_pi_confirm_t3a_propulsion_enable` and
`rfcu_pi_confirm_manual_safety_release` both short-circuit and return success
immediately when the mode is `run-t3a`. In T2 they prompt for the exact tokens
`PROPULSION_ENABLED_FCU_DISARMED_SAFETY_ON_GUARDING_INSTALLED_EXCLUSION_CLEAR`
and `RELEASED_DISARMED`; in T3a the declaration was made up front by the ten
approved flags and **the run does not stop to ask again**.

A flag set to `1` for a condition that is not physically true therefore removes
a gate that would otherwise have stopped the run.

The gate requires ten names at `1` - `REAL_FCU_T0A_COMPLETE`,
`REAL_FCU_T0B_APPROVED`, `REAL_FCU_T3A_APPROVED`, `REAL_FCU_START_DISARMED`,
`REAL_FCU_SAFETY_ON`, `REAL_FCU_PROPELLERS_FITTED`,
`REAL_FCU_HULL_RESTRAINED`, `REAL_FCU_MECHANICAL_GUARDING_INSTALLED`,
`REAL_FCU_EXCLUSION_ZONE_CLEAR`, `REAL_FCU_PROPULSION_ISOLATED` - and three at
`0`: `REAL_FCU_T2A_APPROVED`, `REAL_FCU_T2B_APPROVED`,
`REAL_FCU_PROPELLERS_REMOVED`.

`REAL_FCU_PROPULSION_ISOLATED=1` describes the **starting** state. Propulsion is
enabled later, at the gate below, during the run.

### The two external cues during the run

Both are logged with `operator_action=external`, and in T3a they pass without
prompting, so the log line is the cue:

1. `REAL_FCU_T3A_PROPULSION_ENABLE=AUTHORIZED state=disarmed safety=ON
   guarding=installed exclusion_zone=clear` - propulsion power goes on here,
   while disarmed and with safety ON.
2. `REAL_FCU_T3A_SAFETY_RELEASE=AUTHORIZED state=disarmed`, then `=WAITING
   readiness=bridge-READY_DISARMED` - hardware safety is released here, while
   still disarmed.

The helper then requires a fresh `READY_DISARMED` after that release, at line
`1731`, and workstation discovery, before it prints `REAL_FCU_PI_READY=PASS` and
`REAL_FCU_T3A_READY=PASS ... propellers=fitted propulsion=enabled`.

### Arm point

After `REAL_FCU_T3A_READY=PASS` on the Pi and `REAL_FCU_WORKSTATION_READY=PASS`
on W1. Arming is external, by QGroundControl or Herelink. The dashboard
Hardware Safety reading should already read `RELEASED (suppression off)` and
agree with the physical switch; a contradiction or a stuck `Unknown (stale)` is
no observation.

Demand then comes from the browser: tick the confirmation, hold
`Hold to Apply RC Demand`, which publishes only while held.

### Pi terminal - session persistence

The Pi terminal can be an `ssh` session from the workstation or a terminal on
the Pi's own desktop over Remmina. They are not equivalent for a run that ends
in an interactive closeout.

`rfcu_pi_start_child` launches every child as
`( trap - INT QUIT; exec setsid "$@" ) >"$logfile" 2>&1 < /dev/null &`, so the
children hold their own sessions with detached stdin and survive the loss of
the parent terminal. The **supervisor** does not: it runs in that terminal. Over
`ssh`, a dropped link `SIGHUP`s it mid-run, the closeout prompt at line `1433`
never gets answered, and `rfcu_pi_cleanup` records
`REAL_FCU_T3A_SAFE_CLOSEOUT=FAIL confirmation=missing-or-invalid` with
`cleanup_rc=1`.

An RDP desktop session keeps running on the Pi when the client disconnects, so
Remmina removes that failure mode. Nothing in the helper reads `DISPLAY`,
`WAYLAND_DISPLAY` or `xdg-user-dir`, so the desktop costs nothing.

Three consequences for a Remmina run:

- Paste the flag line rather than retyping it. Thirteen flags is a realistic
  typo surface. It fails safe - a mistyped **name** leaves the intended variable
  unset, it defaults to `0`, and `rfcu_pi_require_flag` stops the run - so the
  cost is time rather than safety, which on a single-attempt run is still the
  scarce thing. If the clipboard does not reach the Pi, Remmina `1.4.43` needs
  `deny_screenshot_clipboard=false`, and the Pi's GNOME RDP needs NLA with
  Automatic negotiation plus its own `grdctl` credentials rather than the system
  password.
- Do not close the Remmina window between arming and closeout. The closeout is
  `read -r -t "$RFCU_PI_T3A_CLOSEOUT_TIMEOUT_SECONDS" -p` on the supervisor's
  own terminal; if that window is gone the prompt cannot be answered and the
  cleanup failure above is recorded.
- Confirm `Ctrl+C` reaches the Pi terminal through the Remmina keyboard
  settings before the run rather than during it, since the stop order depends
  on it.

### Closeout - this one does prompt

`rfcu_pi_confirm_t3a_safe_closeout` reads with a timeout of
`RFCU_PI_T3A_CLOSEOUT_TIMEOUT_SECONDS`, default `300`, and requires exactly:

```text
NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED
```

Its prompt states the required order: release Apply to neutral, press E-Stop,
externally disarm the flight controller, restore hardware safety ON, physically
re-isolate propulsion, then type the token.

Stack teardown follows the start-order sheet in reverse: externally disarm
first, stop W2, run the Pi closeout and Ctrl+C the Pi, then stop W1 last,
because W1's stop marker is what lets the Pi finish.

## Workstation dress rehearsal - 02/09/2026

Terminals 1 to 3 of the run-sheet executed on the workstation at revision
`90a9cdd` with no Pi and no flight controller, to prove the workstation half
and the start order before the single full-stack attempt. Both supervisors do
all of their own startup before they need the Pi, so the rehearsal reaches
their waiting states.

It found **five defects in the run-sheet as written**, every one of which would
have cost time during the one attempt. All five are corrected above.

| # | Defect | How it surfaced |
| --- | --- | --- |
| 1 | W2 needs ten environment variables; the sheet listed none | `STOP: FCU_VRX_LEFT_SERVO_CHANNEL is required`, then `STOP: FCU_VRX_OBSERVER_STALE_SECONDS is required` on the next attempt |
| 2 | `run-real-fcu` needs `FCU_VRX_CORRELATED_OBSERVATION=1`, default `0` | `fcuvrx_validate_configuration` rejects the default |
| 3 | The capture command was invalid | `t3a capture tier requires ESC-threshold calibration` |
| 4 | The capture terminal is interactive, not fire-and-forget | it printed `REAL_FCU_ESC_THRESHOLD_INPUT=READY` expecting typed observations |
| 5 | W2 carries a `120`-second fuse after `PRESTART=PASS` | it exited `status=1` with `STOP: real-FCU RCOut relay did not become ready before the deadline` |

Defects 1 and 2 were found serially, one restart each, which is exactly the
failure mode the rehearsal existed to move off the run day.

### What passed

With the correct environment, W2 reached
`FCU_TO_VRX_WORKSTATION_PRESTART=PASS mode=run-real-fcu domain=77 ...
mapping=3/1 rails=800/800/2200 ... relay=started relay_domain=43`, matching a
previous run's own marker. VRX reported ready on `/clock`, `/wamv/pose` and both
thruster topics, the observer started fail-closed, the pose baseline resolved on
`sydney_regatta`, and the bridge and relay started.

W1 reached `REAL_FCU_WORKSTATION_SERVICES=PASS ports=8002,9090
address=127.0.0.1` and then its waiting state. The domain `43` graph showed
exactly `/rosapi` and `/rosbridge_websocket`. The capture node reached
`REAL_FCU_CAPTURE_READY=PASS tier=T3A subscriptions=5
esc_threshold_calibration=true` before ending `FAIL` on absent flight-controller
data, which is the correct outcome without a Pi.

### Teardown

W2 timed out on its own and stopped `relay`, `bridge`, `observer` and `vrx` with
`FCU_TO_VRX_WORKSTATION_EXIT status=1 cleanup_rc=0`. W1 took `SIGINT` and
exited `REAL_FCU_WORKSTATION_EXIT status=130 cleanup_rc=0` after stopping the
dashboard and rosbridge. Afterwards: zero surviving simulator, MAVROS,
rosbridge, dashboard or capture processes, ports `8002`, `9090` and `8080`
released, worktree unchanged, and the workstation preflight passing again.

### The conflict-guard false positive, demonstrated

Immediately after teardown the preflight reported
`STOP: conflicting workstation process found` while a process sweep showed none
and the ports were free. The cause was `pgrep -af` matching the sweep command's
own argv, which mentioned `rosbridge`, `gz sim` and similar. Re-running the same
preflight on a clean command line passed. This had been raised earlier as a
theoretical risk; it is now reproduced, and the caution is recorded in the
run-sheet.

### What the rehearsal does not cover

The Hailo branch of W1 was not exercised: with `REAL_FCU_HAILO_PERSON_STOP=1`
the supervisor blocks in `rfcu_ws_wait_hailo_detection` on
`/perception/detections`, which is Pi-sourced. Nothing on the Pi side, and
nothing requiring the flight controller, was exercised.

## First full-stack T3a attempt - 02/09/2026, stopped at gate 1688

The full stack was started at revision `600303e` with the Pi bundle
`778e069` and propellers fitted. It reached the T0b probe and stopped there.
No arm, no propulsion command, no actuation. Two workstation supervisors and
the capture terminal timed out and cleaned themselves up.

### What passed, and it is the larger part

- **The Hailo preflight executed on hardware for the first time.** Four
  additional `OK` lines - `object_detection.py`,
  `object_detection_post_process.py`, `toolbox.py` and the
  `yolov11n-v2.19.0-hailo8l.hef` - are `rfcu_pi_validate_hailo_preflight`, `17`
  of the guards that had only ever been verified offline. Hardware-verified
  guards go from `12` to about `29`.
- **All thirteen T3a flag gates passed**, giving
  `REAL_FCU_T3A_START=PASS propellers=fitted hull=restrained
  mechanical_guarding=installed exclusion_zone=clear propulsion=isolated
  safety=ON state=disarmed`.
- **The entire unrehearsed Hailo handshake worked end to end.** The Pi's Hailo
  child reached `REAL_FCU_HAILO_PERSON_STOP=PASS detections=structured
  class=person image=ready person_alert=fresh-clear serial_owner=none
  thermal=supervised`; W1 consumed those detections, started
  `web-video-server` and `person-stop-monitor`, and reached
  `REAL_FCU_WORKSTATION_SERVICES=PASS ports=8002,8080,9090 ...
  hailo=structured-person-detections person_stop=fresh-clear` before waiting for
  the Pi. That was the largest remaining software unknown and it is now
  verified.
- W2 reached `PRESTART=PASS` with `mapping=3/1 rails=800/800/2200` and
  `ready_timeout_seconds=600`, confirming the timeout override takes effect.

### Where it stopped

`rfcu_pi_wait_connected_disarmed mavros-probe`, gate line `1688`. `/mavros/state`
carried `connected: false` with a stamp roughly `280` seconds stale, and the
router logged a churn of implausible remote addresses rather than the vehicle's
`1.1`.

### The link is not at fault - three wrong diagnoses, corrected

The address churn was read as floating-line noise and an electrical or wiring
fault was proposed. That was wrong, as were two follow-ups. Correcting them in
order, because each was disproved by a cheaper test that should have come
first:

1. **"Floating or unwired UART, or a baud mismatch."** Disproved by reading the
   bytes. `timeout 3 cat /dev/ttyAMA0 | xxd` showed `fd 0e 00 00 f2 01 01`,
   `fd 1c 00 00 fb 01 01`, `fd 0c 00 00 fc 01 01`, `fd 1c 00 00 fd 01 01` -
   MAVLink2 magic `0xFD`, incrementing sequence `f2, fb, fc, fd`, and a constant
   `sysid=1 compid=1`. A clean stream at the configured baud. **The hex dump
   should have been the first test, not the fourth.**
2. **"FCU serial parameters drifted."** Disproved by operator readback in
   QGroundControl: `SERIAL1_BAUD=57600`, `SERIAL1_PROTOCOL=MAVLink2`,
   `SERIAL1_OPTIONS=0`, `BRD_SER1_RTSCTS=Auto (2)` - all matching the
   03/08/2026 recorded baseline exactly.
3. **"The T0b allowlist cannot publish `/mavros/state`."** Disproved by reading
   `config/mavros_real_fcu_t0b_plugins.yaml`: `sys_status` is present.

An isolated MAVROS run against the same device, with the same T0b allowlist and
arguments the helper builds, then connected in about `1.5` seconds:

```text
link[1000] detected remote address 1.1
CON: Got HEARTBEAT, connected. FCU: ArduPilot
FCU: ArduRover V4.6.3 (3fc7011a)
FCU: CubeOrangePlus 0037004F 31335106 34343730
PR: parameters list received
```

### Two corrections to the retained record

**The Pi-to-FCU request/response defect is not present.** `PR: parameters list
received` is a complete `986`-parameter pull, so the Pi both sends and is
answered. The defect recorded open on 03/08/2026 and still described as open on
25/08/2026 does not reproduce today. Earlier entries stay as written; this is
the forward correction.

**Spurious router addresses are not a fault signature.** The successful isolated
run logged `42.100`, `255.190`, `42.236`, `42.250` and `10.250` alongside the
correct `1.1`. Occasional framing hiccups are normal on this link. The
distinguishing feature of the failure was not that garbage appeared, but that
`1.1` never did.

The `VER: autopilot version service timeout` errors are also benign: the T0b
allowlist has no `command` plugin, so MAVROS cannot issue that request, falls
back to default capabilities and reads the version from the heartbeat stream
regardless.

### Most likely cause, and the cheap guard against it

The link is healthy now and was not healthy when the probe opened the port. The
flight controller's transmitting state at probe-start is the remaining
difference; it was confirmed powered several minutes into the failure rather
than before the stack was started.

That is worth a pre-flight check rather than a theory. An isolated MAVROS run
answers in about `1.5` seconds what gate `1688` takes up to `600` to report,
and it costs nothing:

```bash
source /opt/ros/jazzy/setup.bash && export ROS_DOMAIN_ID=43 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET ROS_LOCALHOST_ONLY=0 && ros2 run mavros mavros_node --ros-args --params-file /opt/ros/jazzy/share/mavros/launch/apm_config.yaml --params-file /home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069/config/mavros_real_fcu_t0b_plugins.yaml -p fcu_url:=serial:///dev/ttyAMA0:57600 -p 'gcs_url:=""' -p system_id:=255 -p component_id:=191 -p target_system_id:=1 -p target_component_id:=1
```

`CON: Got HEARTBEAT, connected` plus `detected remote address 1.1` within a few
seconds means the link is good; Ctrl+C and start the stack. Nothing within about
ten seconds means do not start it. Note the single-quoted `'gcs_url:=""'`: the
rcl parser rejects the bare `gcs_url:=` that an unquoted `""` collapses to.

This check must release `/dev/ttyAMA0` before the run, or the Pi preflight stops
on `already in use`.

### Gate 1688 behaved correctly

It refused to advance a props-fitted run whose telemetry link was not
established. No propulsion was enabled, no safety released, nothing armed. The
run cost time, not safety.

## Full-stack T3a digital-twin run - 02/09/2026, complete

The second attempt reached readiness on both sides, closed the bidirectional
twin loop against the real flight controller, and ended on a confirmed safe
closeout. This is the first time the full path has run at any revision.

### What unblocked it

Two changes from the failed attempt, both diagnosed from its evidence.

**The Hailo child was removed from the run.** With `REAL_FCU_HAILO_PERSON_STOP=1`
the probe never saw the vehicle: `78` router address events, all implausible, and
`1.1` never among them. Without it the probe cleared immediately. The Hailo
bridge does not open the serial port - it is `cv2`, `numpy` and `rclpy`
publishing `Image`, and its only match for "serial" is the literal string
`serial_owner=none` in a log line - so contention is ruled out and the mechanism
is still unknown. Scheduling starvation and electrical interference both fit the
evidence and were not separated.

**Guard-snapshot mode replaced the live parameter pull.** The second failure was
`T0b MAVROS parameter pull failed`, from
`timeout 20 ros2 service call /mavros/param/pull` at
`tools/real_fcu_digital_twin_pi.sh:1198`. Three isolated MAVROS runs each
measured `36` seconds to `PR: parameters list received`, so a `20`-second budget
cannot fit this vehicle's `986` parameters and no number of retries would help.

`rfcu_pi_capture_runtime_guard` routes to `rfcu_pi_capture_snapshot_guard`
instead of `rfcu_pi_capture_t0b` when `RFCU_PI_GUARD_SOURCE=snapshot`, which
skips the pull entirely. That is how the 01/09/2026 run succeeded, and its
artifact `real_fcu_params_20260901_t3a_live_0p5.parm` was still present and
still valid. Note the two snapshot mechanisms differ: the T0b snapshot is
`probe`-only, while the **guard** snapshot is explicitly allowed for `run-t2a`,
`run` and `run-t3a`.

Its contents were checked against every bound the bridge enforces before use:
`986` parameters, `RC_OVERRIDE_TIME 0.500000`, `BRD_SAFETY_DEFLT 1`,
`RCMAP_ROLL 1` and `RCMAP_THROTTLE 3` distinct, `SERVO3_FUNCTION 73` and
`SERVO1_FUNCTION 74`, `SYSID_THISMAV 1` against `SYSID_MYGCS 255`, and
`DDS_ENABLE` absent.

### The run

```text
REAL_FCU_GUARD_SNAPSHOT=PASS sha256=5ea352bc... safety=ON source=mavproxy parameter_write=none
REAL_FCU_TELEMETRY=PASS topics=state,GPS,IMU,battery,RC-input,thrust-output
snapshot guard resolved: parameters=986 steering=RC1 throttle=RC3 left=SERVO3 right=SERVO1
REAL_FCU_T3A_READY=PASS authority=demand-enabled propellers=fitted propulsion=enabled bridge=READY_DISARMED workstation=visible capture=visible
```

The guard resolved `left=SERVO3 right=SERVO1` from the vehicle's own parameters,
the reverse of the simulator's mapping, which is exactly the behaviour the
02/09/2026 SITL entry above warned must not be read as covering the boat.

Both workstation supervisors reached readiness, and the loop closed in both
directions:

```text
FCU_TO_VRX_RC_OUT_RELAY_READY=PASS topic=/mavros/rc/out udp=127.0.0.1:14555 left=SERVO3 right=SERVO1 pwm=800/800/2200
FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS topic=/fcu_to_vrx/twin_telemetry udp=127.0.0.1:14556 schema=uvautoboat.fcu_to_vrx.twin_telemetry.v1
FCU_TO_VRX_WORKSTATION_READY=PASS ... observer=ready streams=4 relay=ready twin_telemetry=ready
REAL_FCU_WORKSTATION_READY=PASS telemetry=state,GPS,IMU,battery,RC-input,thrust-output
```

`streams=4` is the four-stream observer gate - `servo_output_raw` plus both
thrust topics - all originating from the real flight controller's measured
output. The capture terminal recorded
`REAL_FCU_CAPTURE_STREAMS=PASS status=received state=received rc_in=received
rc_out=received`.

### Closeout

`REAL_FCU_T3A_SAFE_CLOSEOUT=PASS neutral=true estop=true disarmed=true
safety=ON propulsion=isolated source=operator-confirmation`, then
`REAL_FCU_FINAL_STATE=PASS connected=true armed=false`. W1 ended
`REAL_FCU_WORKSTATION_STOP_MARKER=PASS` and `EXIT status=0 cleanup_rc=0`.

Two non-faults in the tail. W2 ended `STOP: a VRX/bridge child exited
unexpectedly` because the Pi stopped before it, taking the relay's source away;
the documented order stops W2 first and avoids this. The capture terminal ended
`FAIL` with only `calibration_left_observation_incomplete` and
`calibration_right_observation_incomplete`, meaning every stream arrived and only
the operator's typed ESC observations were absent.

## Throttle ceiling raised to 0.20

Requested after the run. The ceiling was enforced in five places, two of them
bundle members, and asserted by three test suites:

| Surface | Note |
| --- | --- |
| `tools/real_fcu_rc_command_bridge.py:802,805` | parameter default and the hard `GuardError` ceiling; bundle member |
| `tools/real_fcu_digital_twin_pi.sh:759` | the `-p max_throttle:=` the helper passes; bundle member |
| `tools/real_fcu_command_feedback_capture.py:56` | `CALIBRATION_MAX_THROTTLE` |
| `web_dashboard/autoboat/app.js:379` | `FCU_BENCH_MAX_THROTTLE` |
| `web_dashboard/autoboat/index.html:240-241` | slider `max` and its label |

Three independent guards caught the change rather than letting it pass: the
dashboard clamp test, the bundle manifest, and a deliberate tripwire in the
helper suite reading `FAIL: Pi bridge throttle bound changed`. That tripwire
exists so this bound cannot move silently, and it did its job.

Five test assertions were updated to exercise the **new** endpoint rather than
merely expect a different number. The float32 endpoint-normalisation tests in
the bridge and capture suites now clamp at `0.20`, which is the behaviour that
matters at a ceiling.

Steering and throttle now share a ceiling of `0.20`; throttle was previously
capped at `60%` of steering's range. On a props-fitted hull this is a `67%`
increase in maximum commanded throttle. The number was specified by the
operator.

The bundle manifest was regenerated. `tools/real_fcu_digital_twin_pi.sh` moved to
`0e7395f5` and `tools/real_fcu_rc_command_bridge.py` to `14944a50`; the two YAML
members are unchanged.

## Person-alert advisory mode

Requested so a detection warns on the dashboard instead of stopping the run.
Built as an explicit opt-in rather than a change of default: with it on, a
detected person no longer stops the propellers. The operator specified this
after the consequence was stated.

### Contract

`REAL_FCU_PERSON_ALERT_ADVISORY=1` on the Pi, defaulting to `0`, and refused
unless `REAL_FCU_HAILO_PERSON_STOP=1` since it is meaningless without the
detector. It reaches the bridge as `-p person_alert_advisory:=true`.

What it removes is the **hold**: no emergency stop is latched on a detection and
readiness is not withheld. What it deliberately keeps is the **freshness
requirement**: a stale or dead detector feed still latches a stop in either
mode. Advisory means "a person is present and we are continuing", not "the
detector is optional".

### The second stop path

The first implementation only changed `_person_alert_cb`, which handles the
message as it arrives. That was incomplete and would have failed in the field
while passing its own tests.

The primary stop mechanism is in `_tick`, which runs every cycle and latches
whenever the alert is not "ready" while the vehicle is armed:

```python
person_alert_ready = bool(
    self.person_alert_valid
    and self.person_alert_at > 0.0
    and now - self.person_alert_at < PERSON_ALERT_TIMEOUT_SECONDS
    and self.person_hold_clear
)
if self.require_person_alert and not person_alert_ready \
        and vehicle is not None and vehicle.armed:
    self._latch_emergency_stop()
```

That is now split so freshness and the hold are separate terms, and only the
hold is bypassed under advisory. A dedicated test covers it, and reverting only
that gate fails only that test.

The same pass found a duplicate `person_hold_clear` key introduced into the
status payload, which Python resolves silently by keeping the last one. The
duplicate is removed and a test now asserts each of the two person fields
appears exactly once.

### The dashboard would otherwise have lied

The badge read `PERSON OBSTACLE — STOPPED`. Under advisory nothing stops, so
that claim would be false in the most dangerous direction: an operator reading
"stopped" while the propellers still turn.

It now reads `PERSON OBSTACLE — ADVISORY, NOT STOPPED`, still styled critical,
because a person near live propellers is critical whether or not the boat
stopped. The advisory wording is used only on an **affirmative and fresh**
`person_alert_advisory` from the bridge. No bridge at all, as in simulation, a
stale status, or a missing field all keep the original stop wording, so the
simulation path is untouched. A first attempt dropped the stop claim whenever
bench status was absent and broke ten existing tests; that was the wrong
default and was corrected.

`personAlertIsAdvisory` guards its bench-scope reads with `typeof`, because the
badge renderer is also evaluated by a harness that does not load that scope.

### Evidence

The T3a READY marker now ends `person_alert=advisory-no-stop` or
`person_alert=stop-enabled`, so any run record states which behaviour was
active.

### Coverage

Bridge `63` to `67`: a detection under advisory latches nothing, the control
that default mode still stops, the tick path while armed, a stale feed still
stopping under advisory, and the payload field assertions. Helper `69` to `73`:
defaults off, refused without the detector, passed through only when asked, and
recorded in the marker. Dashboard `96` to `101`: advisory wording, the
non-advisory control, a stale advisory report, a missing field, and detector
feed loss.

One test defect was found and fixed while writing them: the envelope harness
mocks `Date` to its own clock, so a timestamp taken from the real `Date.now()`
was incomparable and made a stale sample look fresh.

### Deployment

Both bundle members changed again. `tools/real_fcu_digital_twin_pi.sh` is now
`fd9d0250` and `tools/real_fcu_rc_command_bridge.py` is `50e2eac3`, with the
manifest at `f0a91bb4`. The bundle certified earlier today as `65e1fb8` no
longer matches and needs a fresh transfer before advisory mode can be used.

## ESC start threshold measured - 02/09/2026

First measurement of where the propellers actually begin to turn, taken during
the armed T3a run on bundle `929831e` with the `0.20` ceiling. Steering at `0`
throughout, so both sides carry the same demand.

| Condition | Demand | Measured PWM | Rail position |
| --- | ---: | ---: | ---: |
| **From-rest start, both sides** | `0.15` | `996 us` | `+14.0%` |
| Observed turning at the ceiling | `0.20` | `1066 us` | `+19.0%` |
| Former ceiling, for comparison | `0.12` | `968 us` | `+12.0%` |

The servo rail is `800/800/2200`, so neutral sits at minimum and the span is
`1400 us`. `996 - 800 = 196`, and `196 / 1400` is `14.0%`; `1066 - 800 = 266`,
and `266 / 1400` is `19.0%`. Both figures reconcile with the reported
rail-relative percentages.

### Why the old ceiling could never turn them

`0.12` capped the output at `968 us`, which is `28 us` below the measured
`996 us` start. No amount of throttle under the previous limit could start the
motors. The request to raise the ceiling was correct, and the margin was
narrow rather than large.

### The usable band is real but small

From-rest start at `0.15` against a ceiling of `0.20` leaves roughly `70 us`,
or `0.05` in demand units, of controllable range above break-away. That is not
zero, but it is narrow. Whether it is enough for a visible demonstration rather
than a twitch into life is an operational judgement, and raising the ceiling
further would be a further increase in actuation authority on a props-fitted
hull.

An earlier reading of this session claimed the threshold sat **at** the ceiling
with no usable band. That was based on the coarser `0.20` observation and is
withdrawn; the `0.15` from-rest figure supersedes it.

### The calibration interface makes this hard to capture, and is one-shot

Recorded as a finding, not repaired. `real_fcu_command_feedback_capture.py`
correlates an operator observation to the **last ACTIVE plateau**, requires a
disabled neutral release frame first, and accepts the input within a `10`-second
grace. That much works: the held PWM is what is recorded, not the released
neutral.

The difficulty is that it records the plateau held at the moment of release
rather than the transition itself. Capturing `996 us` therefore requires holding
at exactly `0.15`, observing break-away, releasing without moving the control,
and typing inside the grace window. Locating a threshold becomes a bisection in
which every candidate costs a full hold, release and type cycle.

Worse, the terminal observation is one-shot per side:

```python
raise CaptureError(f"terminal {side} observation was already recorded")
```

Once `started` or `not-observed` is recorded for a side, that session cannot
revise it. An observation entered while holding `0.20` pins the artifact at
`1066 us`, and recording the true `996 us` requires a fresh capture session.

The operator's assessment of the interface is that it does not fit how a
threshold is actually found. That is a fair criticism of the design rather than
of its implementation: the mechanism is sound for confirming a value already
known, and poor for discovering one.

## Open

### The deployed Pi bundle is stale

The `65e1fb8` bundle was transferred and certified this afternoon, then advisory
mode changed both governed members again. `tools/real_fcu_digital_twin_pi.sh` is
now `fd9d0250` and `tools/real_fcu_rc_command_bridge.py` is `50e2eac3`, with the
manifest at `f0a91bb4`. A fresh transfer and non-actuating certification are
required before any further run. That run is also the first at a `0.20` throttle
ceiling and the first able to use advisory mode.

### The Hailo and flight-controller interaction is unexplained

It blocks the person-stop showcase the run is meant to demonstrate. With
`REAL_FCU_HAILO_PERSON_STOP=1` the probe never sees the vehicle; with it
disabled the full stack runs to READY. Serial contention is ruled out from the
Hailo bridge's own source. Scheduling starvation and electrical interference
both fit the evidence and have not been separated. Investigation is not started.

### Finding - the view-only Pi monitor trusts a stale safety sample

**WITHDRAWN 02/09/2026 - see "Correction - the Pi monitor staleness finding was
wrong" above. Every call site is guarded by `stale_topic`, which aborts on a
stale `/mavros/sys_status` before the safety reading is consulted. The entry
below is retained as written; do not act on it.**

Found while writing the documentation above, not repaired.
`tools/pi_live_hailo_mavlink_dashboard.sh` reads the same
`MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS` bit as the dashboard badge, but without
either guard the bridge applies:

```python
def hardware_safety_is_on(self):
    sensors_enabled = getattr(self.latest_sys_status, "sensors_enabled", None)
    return isinstance(sensors_enabled, int) and not (
        sensors_enabled & motor_outputs_bit
    )
```

`self.latest_sys_status` is assigned at line `2256` with no timestamp, so there
is no staleness check: if `/mavros/sys_status` stops arriving, the last sample
answers indefinitely. `isinstance(True, int)` is also true, and `True &
32768` is `0`, so a boolean would report safety on. The bridge's
`hardware_safety_state` rejects both cases and returns `UNKNOWN-STALE`.

Both failure modes push the answer toward "safety is on", and
`restored_safe_state()` requires that, so both push toward declaring the safe
state restored. That is the fail-open direction for a safety monitor, and it is
load-bearing: `restored_safe_state()` drives the transition to `COMPLETE` at
line `2313` and the `FINAL_STATE_LOST` abort at line `2317`. A stale sample can
let the monitor call an armed observation complete, and can suppress an abort
that should have fired.

Severity is bounded by the source: `sensors_enabled` arrives as a `uint32` field
on a MAVROS `SysStatus` message, so the boolean path is theoretical. The
staleness path is not - it needs only the `/mavros/sys_status` stream to stop
while the monitor keeps running.

This is the same defect class as the badge staleness fixed on 01/09/2026, in a
helper that was not swept at the time. It is not repaired here: the file is
checksum-pinned in the runbook at `0d3f6d1b` and `95,720` bytes, it is a
Pi-side safety monitor, and changing it needs an explicit decision and a
re-pin. It is relevant to any armed run, so it is recorded before one.

The deployment is current: `778e069` is **DEPLOYED / CERTIFIED / NOT RUN** at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260902_778e069`. What remains
is a run, which needs hardware beyond the Pi.

`111` of the `123` fail-closed guards in the Pi runtime are still verified
offline only, including the thirteen in `rfcu_pi_run`. The first run of this
bundle exercises them on hardware for the first time. It will not be stricter
than the bundle it replaces in the normal path - see the correction and guard
map above - so a `STOP:` line names a precondition that would have ended the
run before this change too. Read it rather than working around it.

## Run closeout and capture verdict - 02/09/2026

This section closes the run recorded above and supersedes the last line of
`Open`, which was written before the run and still said a run was what
remained. The run happened. Both supervisors were stopped in the planned
order and both exited cleanly.

### Teardown

W2 stopped first, then the Pi closeout, then W1 last so its stop marker
could release the Pi:

| Supervisor | Closing markers |
| --- | --- |
| W2 | `TEARDOWN=PASS order=relay,bridge,observer,vrx udp=14555-free twin_telemetry_udp=14556-free`, `EXIT status=0 cleanup_rc=0` |
| W1 | `FINAL_STATE=PASS connected=true armed=false`, `STOP_MARKER=PASS topic=/real_fcu/workstation_stop`, `EXIT status=0 cleanup_rc=0` |

Both `cleanup_rc=0`. A survivor sweep for `gz sim`, `gazebo`, `mavros_node`,
`serve_dashboard`, `rosbridge` and the capture process returned nothing, and
ports `8002`, `8080` and `9090` were all unbound afterwards. This is the first
teardown of the day where both supervisors reached `status=0` with no manual
cleanup.

The Pi recorded `NEUTRAL_ESTOP_FCU_DISARMED_SAFETY_ON_PROPULSION_ISOLATED` in
`evidence/t3a_safe_closeout.txt`. The Pi run directory
`real_fcu_t3a_pi_20260902_180626` was copied to the workstation at
`~/Desktop/pi_run_evidence/`, `59` files including `artifacts.sha256`.

### What the capture recorded

`real_fcu_capture_t3a_esc_threshold_20260902_180557`, `evidence/verdict.json`:

| Field | Value |
| --- | --- |
| Span | `3558.7` s, `59m18s` armed |
| Events | `106,339` total |
| Per topic | `/command_ingress/status` `70,041`, `/mavros/rc/in` `14,020`, `/mavros/rc/out` `14,010`, `/command_ingress/rc_axes` `4,714`, `/mavros/state` `3,554` |
| Invalid status | `0` |
| Publisher binding | `pass=true`, observed `/real_fcu_rc_command_bridge_t3a` |
| Guard source | `snapshot`, sha `5ea352bc3922` |
| Final state | `EMERGENCY_STOP` latched, `hardware_safety=ENGAGED`, armed `false`, connected `true` |
| Final measured | both servos `800`, both RC `1515` |

`236` state entries with `115` `ACTIVE` and `116` `ARMED_NEUTRAL` alternations,
opening `STATE_STALE` to `WAITING_DISARMED_NEUTRAL_RC` to `ARMED_BEFORE_READY`
to `READY_DISARMED` and ending `EMERGENCY_STOP`. The alternation count is the
throttle being driven up and returned to neutral, over and over, for an hour.
Not one invalid status in `70,041` samples, and the publisher lock held for
the whole run.

### The threshold is not in the artifact

`"calibration": {"left": null, "right": null}` and
`"operator/esc_threshold": 0`. Zero observations were entered, so the run
finalised `pass=false` with `calibration_left_observation_incomplete` and
`calibration_right_observation_incomplete`.

The `996` us / `0.15` measurement therefore exists only as prose in the
section above. Nothing in the capture artifact carries it. Anyone reading
`verdict.json` tomorrow will find nulls, and should not read that as the
measurement having failed - the boat did start, it was observed, and the
number was simply never typed into the calibration prompt during the run.

This is the interface problem already recorded above, now with a concrete
cost: an hour of armed running produced a `FAIL` verdict for a measurement
that succeeded physically. The interface wants the observation entered live,
mid-run, while the operator is watching propellers.

### Advisory mode was not exercised

`person_alert_advisory=false` and `person_alert_required=false` in the final
status. The Hailo branch was not part of this run, so the advisory path built
today is still deployed and unrun on hardware.

## Single workstation entry point - 02/09/2026, evening

Today's run needed three workstation terminals plus a browser plus the Pi, and
the three terminals each carried environment the operator had to paste
correctly. Two of the day's failures came out of that surface rather than out
of the vehicle: a W2 readiness window that expired because the default is not
reachable by hand, and a first attempt that ended with W1 timing out by under
a minute. The goal here is one command on the workstation, one on the Pi, then
the dashboard.

Two new files, `tools/real_fcu_full_stack_workstation.sh` and its test suite
`tools/test_real_fcu_full_stack_workstation.sh`. Neither has been run against
a Pi or a flight controller.

### What it does, and what it deliberately does not

It sequences and supervises. It does not re-implement one guard, threshold or
readiness check; each stays in the helper that owns it, and a stop still
prints that helper's own reason. The order is W2, then W1, then the capture
node in the foreground of the same terminal.

The capture node is in the foreground on purpose. It is interactive, and the
run above finalised `pass=false` purely because nobody typed the ESC
observations into it. Putting it where the operator already is removes the
separate terminal that made that easy to forget.

Defaults now carry the eleven values W2 has no defaults for, plus both
readiness timeouts at `1200`. The mapping and rails are printed back before
anything starts, with the instruction to confirm them against the vehicle
rather than against the file.

### The start order was checked, not assumed

W2 before W1 is safe here for two reasons that had to be read out of the
sources rather than taken from the run-sheet:

- `real_fcu_digital_twin_workstation.sh` has no domain-emptiness check, so
  W2's relay already publishing on domain `43` does not block it.
- None of W2's children matches any of W1's ten conflict patterns. The five
  pattern strings that do appear in the W2 script are entries in W2's own
  conflict list, not commands it launches.

Worth separating from a similar-looking rule elsewhere in the documentation:
the start order that is **not** interchangeable, where W1 rejects a running
`gz sim`, belongs to `tools/live_dashboard_preflight.sh`. That is a different
helper with a different pattern list, and it is not the one in this path.

### A supervisor started with plain background never runs its stop handler

The first version signalled each supervisor with `SIGINT` after starting it
with `setsid ... &`. The stop handler never ran. Measured on this workstation
by reading `/proc/<pid>/status`:

| How the child was started | `SigIgn` | `SIGINT` ignored | `SIGINT` caught | Result of `kill -INT` |
| --- | --- | --- | --- | --- |
| plain background | `...0006` | yes | no | still running |
| under `set -m` | `...0004` | no | yes | handler ran, exited |

A non-interactive shell sets `SIGINT` to ignore for every asynchronous child,
and a shell cannot trap a signal that was already ignored when it started, so
the supervisor's own `trap ... INT` is silently inert. The stop would have
fallen through to the `TERM` escalation, and both supervisors record a `TERM`
stop as a failed one: on a real run that means no ordered teardown, no stop
marker, and a Pi left waiting at its closeout.

The fix is job control rather than `setsid`. Under `set -m` each background
job still gets its own process group, which is what keeps a Ctrl+C in this
terminal off the supervisors, and `SIGINT` stays trappable. `setsid` is not
used at all now: under job control the process is already a group leader, so
it forks and the recorded pid stops referring to the supervisor.

The suite covers this as a regression. Reintroducing `setsid` was checked to
fail it, with `neither supervisor recorded a stop`, and removing it again to
pass.

### A second non-hermetic test suite

`bash tools/fcu_to_vrx_workstation.sh check` fails when the eleven `FCU_VRX_*`
values are exported, with `missing live-read configuration was accepted`. Its
suite spawns a subshell that inherits the ambient environment and asserts that
a missing configuration is rejected; an exported value reaches the assertion
and the case wrongly passes validation. Measured both ways in the same shell:
`PASS cases=33` with the values scrubbed, and the failure above with them set.

This is the same class as the leak repaired in the Pi helper suite this
morning, in a suite that was not swept then. It is **not** repaired here: it
is outside what was authorised tonight. The new entry point works around it by
scrubbing the whole operator-facing set before delegating to either check
mode, which is correct regardless, since a check is meant to validate the
helper rather than the operator's shell.

### Preflight results

Both supervisor preflights pass on this workstation tonight:

| Preflight | Result |
| --- | --- |
| `fcu_to_vrx_workstation.sh check` | `PASS shell_cases=33 python_tests=48 runtime=not-started` |
| `real_fcu_digital_twin_workstation.sh check` | `PASS tests=helper,bridge,capture,dashboard runtime=not-started ports=8002,9090`, `101` dashboard tests |
| `test_real_fcu_full_stack_workstation.sh` | `PASS cases=9 runtime=not-started` |

The nine cases cover argument rejection, a missing child helper, delegation
and failure attribution for both check modes, a supervisor that never starts,
one that dies during the marker wait, the full sequence with the stop order
asserted as W2 first and W1 last, the tier reaching the capture node with and
without ESC calibration, and the advisory description. No simulator,
supervisor, flight controller or hardware runtime was started by any of them.

### One thing to know before tomorrow

`real_fcu_digital_twin_workstation.sh` requires a clean worktree, checked with
`--untracked-files=all`. The two new files make the worktree dirty, so the
combined check reports `workstation helper requires a clean worktree` until
they are committed. Each half was verified separately tonight; the combined
`check` is the first thing to run tomorrow, after the commit, and it takes
about a minute.

The residual risk is stated plainly: this is a new sequencer, and tomorrow
would be its first contact with a Pi and a flight controller. The three
terminals it replaces still work exactly as they did today, and nothing about
the run depends on the new file, so falling back costs only the paste.
