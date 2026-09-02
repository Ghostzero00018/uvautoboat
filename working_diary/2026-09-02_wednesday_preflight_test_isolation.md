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

## Open

A current-revision SITL acceptance remains meaningful. The last accepted SITL
revision predates `da6627e`, the hardware-safety badge commit `12236b5`, the
isolation fix `3c57fa0` and this change, so no accepted SITL result covers the
current bytes. Not started, and not authorised by this entry.

The deployed Pi bundle is still named for `da6627e` and predates the badge, the
isolation fix and this change. A new bundle transfer and non-actuating
certification remain required before any run.
