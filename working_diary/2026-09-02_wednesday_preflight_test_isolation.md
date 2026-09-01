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
runtime=not-started ports=8002,9090`. That marker is a fixed string: showcase
mode also requires port `8080` to be free but does not say so, which is the
second open defect below. So ports `8002` and `9090` must be free for the first
command, and `8080` as well for the second.

### Pipeline 2 - FCU-to-VRX workstation preflight

```bash
bash tools/fcu_to_vrx_workstation.sh check
```

Expect `FCU_TO_VRX_WORKSTATION_CHECK=PASS shell_cases=30 python_tests=48
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

Expect `PASS cases=60`, `PASS cases=30`, `Ran 62 tests ... OK`,
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

Expect `PASS cases=60`, identical to the clean-shell run. A different count, or
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

## Open - separate pre-existing defect, not repaired here

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

Both are pre-existing faults in the production helper, outside the
environment-isolation scope authorised for today, and neither is repaired by
this change. The workstation preflight should not be described as structurally
fail-closed until the first is fixed.

## Open

A current-revision SITL acceptance remains meaningful. The last accepted SITL
revision predates both `da6627e` and the hardware-safety badge commit
`12236b5`, so no accepted SITL result covers the current bytes. Not started,
and not authorised by this entry.
