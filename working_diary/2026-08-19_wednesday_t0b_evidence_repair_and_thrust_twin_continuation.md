# Wednesday 19/08/2026 - T0b evidence repair, probe retry and thrust-twin continuation

**PRE-DIARY - NOT STARTED.** This is the sole 19/08/2026 working diary. It
continues the 18/08 sequence after the failed T0b probe. It does not reopen
Block A, Block C, D0 or D1 Gate 1 from earlier dates.

**Superseded by the execution record below.** This banner is retained as the
imported scaffold state; the day was executed on 19/08/2026 and its results are
appended from `19/08/2026 execution record` onward.

The pre-edit repository baseline while drafting this scaffold is
`003c778eefc9075d2d37806ed099312f27db8de8`. This file does not predict the
commit that contains the 18/08 close-out or this scaffold. At day start,
certify the actual pushed revision and require this baseline to remain its
ancestor.

## Established state

- D1 Gate 1 passed on 18/08/2026. The bundle is deployed and certified at
  `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818`. That root must be
  preserved and must not be overwritten, deleted or reused.
- The T0b probe failed on 18/08/2026 and T0b remains open. The serial link
  opened and an ArduPilot heartbeat was received, which establishes
  controller-to-Pi traffic at `57600` with correct framing. Three
  `mavros.param: PR: request list timeout` messages then exhausted their
  retries. This directly establishes that the automatic MAVROS parameter-list
  exchange did not complete during those retries. The operator stopped the run
  at `t+109.81 s`, roughly `70 s` before its deadline, so it did not time out.
- The `VER: autopilot version service timeout` sequence includes
  `command plugin service call failed!` while the T0b allowlist excludes the
  command plugin. It therefore cannot distinguish local plugin topology from a
  controller-side request or response failure and is not wire-level proof.
- Two defects in `rfcu_pi_capture_topic` are recorded and **not yet repaired**:
  it merges `stderr` into the evidence YAML via `2>&1`, and it writes every
  attempt to the same path so each iteration overwrites the previous one.
  The retained result is therefore non-diagnostic: diagnostics can contaminate
  a capture, and only the final interrupted attempt survived. The focused suite
  stubs that function in two places, so neither behaviour is covered by a test.
- T0a is closed. Connector seating and end-to-end
  `Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity both passed on 17/08/2026.
- No parameter has been written to the real controller. Block E and every tier
  above T0b remain closed.
- The operator confirmed the 18/08/2026 physical close-out: controller/control
  box and Pi off, propulsion isolated, propellers removed, hull restrained,
  hardware safety restored, and Herelink sticks and trims neutral. This is the
  prior day's historical end state; Block A must establish the current state
  again before any 19/08/2026 hardware work.

## Sequencing constraint - read before planning thrust work

`Board.md` gates **T2a** on `Function, channel and rail confirmed live in T0b`.
T0b is open, so the real-FCU arm/disarm step is blocked, and every real-FCU
thrust step above it is blocked with it. Real thrust on the physical controller
is therefore **not reachable on 19/08/2026** unless T0b closes first.

The simulator thrust twin is a separate track and is not blocked. Block C
passed its full SITL path on 17/08/2026, so digital-twin thrust work against
the simulator can proceed in parallel with, or instead of, the hardware track.
Any plan that presents real-FCU thrust as the next step without closing T0b is
wrong about the gating and must be corrected rather than followed.

T2a has a second boundary after T0b: `run-t2a` creates the guarded RC-override
publisher and publishes the resolved live RC trims while armed, although it
creates no bridge subscription to browser demand and accepts no non-neutral
demand. Acceptance must separately compare the observed left/right output values
against the live servo trims retained by T0b. The capture verdict retains those
observations but does not perform the trim-equality comparison by itself.

## Read first

1. This file in full. Do not create another 19/08 diary.
2. The `18/08/2026 execution record` section of
   `working_diary/2026-08-18_tuesday_real_fcu_bundle_deployment_and_t0b_continuation.md`,
   in full.
3. `Board.md` from the T0a-T3b tier table through the 13/08 C2 result, plus any
   rows added for 17/08 and 18/08.
4. `tools/real_fcu_digital_twin_pi.sh`, specifically `rfcu_pi_capture_topic`,
   `rfcu_pi_wait_connected_disarmed`, `rfcu_pi_state_file_is_connected_disarmed`
   and `rfcu_pi_capture_t0b`, together with
   `tools/test_real_fcu_digital_twin_helpers.sh` where capture is stubbed.
5. Before any thrust proposal, also reread
   `working_diary/2026-08-11_tuesday_digital_twin_thrust_loop_and_helper_integration.md`
   from `Fixed architecture` through `Verification by changed surface`.

## Block A - certify and prepare only

Only this read-only block is authorized at day start. It starts no simulator,
MAVROS, helper, browser or hardware session.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -16
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git merge-base --is-ancestor \
  003c778eefc9075d2d37806ed099312f27db8de8 HEAD
```

Apply the same branch-state guard as 18/08: stop on fetch failure, on dirty,
ahead or diverged, or if the baseline is not an ancestor; `git pull --ff-only`
if behind only, then restart certification; and inspect every intervening
commit if `HEAD` is a later clean synchronized revision. If `HEAD` still equals
the drafting baseline, the 18/08 close-out did not land; stop and publish it
before anything else.

Re-verify the four bundle members and their manifest. These are the values
**before** any Block B change; Block B alters the first row and Block C
regenerates the manifest, so treat this table as the pre-change baseline only.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/real_fcu_digital_twin_pi.sh` | `30,852` bytes | `38e41d7dc8181e0f289d3b89c6e374e37cf020cf34e7b03f3cf955981a8efafd` |
| `tools/real_fcu_rc_command_bridge.py` | `40,144` bytes | `cf6668139999308b65a2f8af7ef70f74e226c9bd6c1ac82545bc6c1d0bbb59d7` |
| `config/mavros_real_fcu_closed_loop_plugins.yaml` | `129` bytes | `215293eab9d97e8da5a941d6cb8130351dfbafc07cca7656a766798a2a32b5fc` |
| `config/mavros_real_fcu_t0b_plugins.yaml` | `79` bytes | `5e6008314216785f2de53a617ffec72913e52acbef00645a417f19d7279e7a94` |

Also recheck the three operational artifact pins, the `13` operational pin
surfaces, free disk against the `10 GB` floor, the six reserved ports, and the
scoped process list. The canonical conflict-pattern union across the five
tracked arrays is `20` distinct literals;
`tools/real_fcu_command_feedback_capture.py` is covered by no array and must be
checked separately. Reuse the landed suite results only if no covered source or
dependency changed.

Then stop and request approval for Block B.

## Block B - repair the T0b evidence path

Code change. It requires explicit approval and is not authorized by this file.
No hardware, no simulator, no Pi session.

Both repairs are to `rfcu_pi_capture_topic` in
`tools/real_fcu_digital_twin_pi.sh`:

1. Stop merging `stderr` into the evidence artifact. The captured YAML must
   contain only the message body. Child diagnostics belong in a sibling file or
   in the run log, retained either way.
2. Give each capture attempt its own retained path so an iteration can no
   longer destroy its predecessor. The gate may still read the newest attempt,
   but every attempt must survive for diagnosis.

Work red-green. The focused suite currently stubs `rfcu_pi_capture_topic` in
two places, so add a test that exercises the real function against a controlled
command before changing behaviour. The failing test must reproduce the observed
defect - a diagnostic on `stderr` rendering the artifact unparsable, and a
second attempt erasing the first - and must pass afterwards. Do not rewrite
unrelated tests and do not widen the suite beyond these two behaviours.

Run the full focused suites afterwards and record the case counts. Stop and
report before Block C.

The complete suite cannot be green at this point: it verifies the manifest
against repository bytes, and the helper change invalidates that until Block C
regenerates it. The suite is expected to remain red **only** at the manifest
check. Any additional failure blocks Block C and must be resolved under a
separately approved scope.

## Block C - regenerate the manifest and re-pin

Block C requires separate approval. Do not commit the Block B changes alone.
After regenerating the manifest and obtaining a green complete suite, commit the
helper, its tests and the manifest together.

Changing the Pi helper changes its digest, which invalidates
`config/real_fcu_digital_twin_bundle.sha256` and every copy verified against
the old manifest, including the certified 18/08 deployment. Regenerate the
manifest **last**, after the helper change is final, then record the new size
and SHA-256 for the changed member and the new manifest digest in this file.
The physical-helper suite verifies the manifest against current repository
bytes, so it must be rerun after regeneration.

The `13` operational pin surfaces cover the deployed view-only helper and
supervisor, which Block B does not touch. Confirm rather than assume that they
are unchanged.

## Block D - deploy once to a new root

Requires fresh user-run approval. Every Pi command is run by the operator in a
real Pi terminal opened through Remmina.

The 18/08 root is certified, preserved and **not reused**. The new deployment
root is `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819`. It must not
already exist. Retain the 18/08 root untouched; do not delete it to free the
name.

Reuse the 18/08 block structure, which is proven: a host-identity, log-root,
serial and conflict guard before any transfer; a pinned `PI_HOST`; explicit
`D1_STOP reason=` text and a distinct exit code on every guard; the exact
five-file inventory built so no line can wrap; separate `stdout` and `stderr`
capture; and a closing `D1_GATE1=PASS` marker. Correct the transfer stop
condition so a routine password prompt is not treated as an authentication
failure; an unknown or changed host key remains a stop.

Run `check` with no T0/T2 approval flags and require its exact final line
before proceeding.

## Block E - T0b probe retry

Separate approval again, after the deployed bytes and `check` are accepted.
Keep propellers removed, propulsion isolated and the hull restrained. After
powering only the control electronics needed for the session, confirm that the
controller is disarmed and the hardware safety state is ON (safe), and leave
that state unchanged.

Use the same seven one-shot approval flags as 18/08 and set neither T2 flag.
Required success markers are unchanged:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

Two changes to how the run is conducted, both learned from 18/08:

- **Let it reach its own deadline.** The 18/08 run was stopped roughly `70 s`
  early, which is why it is unknown whether the state gate would have passed.
  Unless the physical state changes, allow the full ready timeout to expire and
  record which outcome actually occurred.
- **Read the retained per-attempt captures before concluding.** With Block B in
  place, the observed `connected` and `armed` values across attempts are
  evidence rather than a single overwritten file. State explicitly whether the
  state gate was ever satisfied.

If parameter request and response fails again, record it as the confirmed
blocker with the retained per-attempt evidence, and do not retry.

## Block F - T1 decision point only, not authorized here

`Board.md` defines **T1** as a link-configuration write under a strict
allowlist, initially only `BRD_SER1_RTSCTS`, currently `2`, candidate `0`, with
the prior value recorded, one write, reboot if required, read back, and a
stated rollback. The 18/08 symptom - heartbeats received while parameter
exchange retries failed - is consistent with the unresolved flow-control
hypothesis that T1 was defined to test, but it does not isolate flow control
from runtime UART, controller configuration or protocol causes.

This scaffold does **not** authorize T1 and does not propose it as today's
work. If Block E fails the same way, the outcome of the day is a documented T1
proposal for separate approval on a later date, not a parameter write. T1 is
the first step in this sequence that changes controller state, and it must not
be reached by momentum.

## Thrust digital twin - simulator track

Available without any hardware gate and independent of T0b. Propose scope
before starting; this file authorizes no simulator run.

Candidate work, in preference order:

1. Close the outstanding thrust-loop items against the simulator using the
   Block C path that passed on 17/08/2026.
2. Strengthen the thrust contract's test coverage where the focused suites stub
   real behaviour, in the same spirit as the Block B repair.
3. Document the real-FCU thrust path as blocked behind T0b then T2a, so the
   gating is explicit in the durable record rather than only in this file.

No real-FCU parameter write, arming, motor test, propeller-fitted run or
on-water test is in scope on 19/08/2026.

## Boundaries and fallback

- T1 is not authorized; no real-controller parameter write.
- The 18/08 deployment root is preserved and never reused, overwritten or
  deleted.
- No simulator and real-FCU supervisor overlap.
- No propeller-fitted, powered-thrust, static-propeller or on-water test.
- No manual unrecorded command path and no gate relaxation. A stop condition
  that fires is investigated against the hazard it was written to catch, and
  its wording is corrected in this file rather than reinterpreted in the moment.
- If equipment, network, deployment, evidence or time fails, retain the
  evidence, power down and use the remainder for documentation only.

## Wrap

Append results only to this file. Preserve the 17/08 and 18/08 diaries and
dated Board rows as history. Record the pre-edit baseline while drafting; never
predict the SHA of a commit containing its own close-out text. Stage by
explicit path, inspect the staged content, run the repository checks and leave
a clean synchronized `HEAD == main == origin/main` before the day ends.

## 19/08/2026 execution record

Execution began on 19/08/2026 under the block approvals recorded outside this
file. The pre-edit baseline for this appended record is
`dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`; no commit containing this text is
predicted here.

### Block A result - PASS

Remote certification established a clean
`HEAD == main == origin/main == d5680d7126a2fcbabbf97f44c89c0afd96b26e63`
with divergence `0/0` and a clean worktree and index, and the expected baseline
remained an ancestor. All four bundle members matched the Block A table and the
manifest verified `4/4`. The three operational artifact pins and the `13`
operational pin surfaces were unchanged, and the adjudicator remained `19,656`
bytes at
`790fd46202726d53198fc9444913de421144562cbe1416497a6f3d84333687f3`
with no operational pin surface of its own.

The last commit touching a non-Markdown tracked file remained
`ea8429daab7b7e7c1ba1234589b9899a7135c83c`, so the landed suite results stayed
reusable at `41`, `22`, `26` and `13` cases. Free disk was `22,369,084` KiB
against the `10,485,760` KiB floor, TCP `5760`, `5762`, `8002`, `8080`, `9090`
and UDP `14600` were free, and the canonical `20` conflict patterns plus
`tools/real_fcu_command_feedback_capture.py` produced no match.

### Block B result - PASS

Both recorded defects in `rfcu_pi_capture_topic` were repaired. Child
diagnostics now go to a sibling `.attempt-NNN.stderr.log` instead of being
merged into the evidence YAML, and every capture attempt is retained at its own
`.attempt-NNN.yaml` while the stable path holds the newest capture. Two cases
were added to `tools/test_real_fcu_digital_twin_helpers.sh` that exercise the
real function against a controlled command; both fail against the original body
and pass against the repair.

Review of the first repaired body found a third diagnostic gap in the same
function. The new pipeline introduces `tee` as a second child, and a redirection
binds only to the command it follows, so `tee` became the process that writes
both retained copies while its own diagnostics went to a stream nothing keeps.
A write-side failure would therefore have been reported only to the operator
terminal. The redirection was extended to cover `tee`, and the first case was
strengthened to assert three things at once: the evidence YAML holds only the
message body, nothing reaches the terminal, and the retained log holds both
children's diagnostics in order.

The complete physical-helper suite was red only at the manifest comparison, as
expected before Block C. That check aborts the suite, so the two cases after it
and the terminal case count were not evaluated in that run; one of the two is
the same manifest comparison in a copied layout and was cleared by the same
Block C action.

### Block C result - PASS

`config/real_fcu_digital_twin_bundle.sha256` was regenerated last, after the
helper body was final. Only the Pi helper line changed; the bridge and both
plugin allowlist lines were untouched.

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/real_fcu_digital_twin_pi.sh` | `31,467` bytes | `9379aa4bf03dedec8f9c9cd9a0592d3d302841bbc1e855144bc6f12ecb922f80` |
| `config/real_fcu_digital_twin_bundle.sha256` | `422` bytes | `fd27fedffc98c3d6eb11e8bbe08cfec53498fe05692507bf491f37016d449ffc` |

The complete physical-helper suite then ran to its terminal count at `PASS
cases=24`, which is the landed `22` plus the two new cases. The helper, its
tests and the manifest were committed together as
`dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`, subject `fix(fcu): isolate and
retain each MAVROS capture attempt`, and the synchronized revision was
re-certified afterwards.

### Block D result - Gate 1 PASS after one failed transfer

The 18/08 deployment root was preserved untouched and never reused. The new
root `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` did not exist,
and was created once with its `tools/` and `config/` directories. Host identity,
log root, serial presence, serial read/write access, serial freedom and the
three Pi conflict patterns were confirmed before any transfer.

The read-only Pi guard was run from a copy at
`/home/imt-aqua-drone/d1_pi_guard.sh`, transferred to the Pi home directory
after the paste-only approach failed. That file is outside both deployment roots
and outside the evidence root, and has no effect on the deployed bytes.

The first transfer attempt failed. The destination reached `scp` with a leading
newline, which made the remote path relative rather than absolute, so its
directory creation failed before any member byte was written:

```text
scp: remote mkdir "
/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819/config/": No such file or directory
```

`config/` was therefore left empty, with no partially written file anywhere. The
same attempt also reported a tools status of `0` that did not describe `scp`,
because the status was captured after a separate redirection rather than on the
same line. The cause was the handover form, not the deployment: a long inline
command whose quoted destination was broken across lines when copied.

The corrected transfer sent all five files with both statuses `0`. Deployment
certification then established the three parts together: an inventory of exactly
two directories and five files at `129`, `79`, `422`, `31,467` and `40,144`
bytes; the manifest's own digest
`fd27fedffc98c3d6eb11e8bbe08cfec53498fe05692507bf491f37016d449ffc`; and member
verification `4/4`. The manifest digest is the part that matters most, because a
root holding a stale manifest beside its matching stale members verifies against
itself and would otherwise pass.

The deployed `check` then exited `0` with empty stderr, four bundle `OK` lines
and the exact final line
`[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`.
Gate 1 is certified. `check` validates the Pi environment and never opens the
serial link, so this establishes the deployed bytes and the Pi environment and
nothing about the Pi-to-controller link.

### Findings carried into Block E and later

Three properties were established while preparing Block D. The first two are
preconditions for any block that opens `/dev/ttyAMA0`; the third sets the
expected shape of the retained evidence.

`fuser` run without privileges cannot report a holder owned by another user;
the psmisc `23.7` manual states this under RESTRICTIONS, and a non-privileged
process cannot read another user's file-descriptor table. Both the pre-transfer
serial check and `rfcu_pi_serial_is_free` use unprivileged `fuser`, so neither
can detect a root-owned holder such as a leftover privileged serial client or a
re-enabled console service on that device; both read the resulting empty answer
as free. The `pgrep` patterns do not backstop it, and read/write bits test
permission rather than exclusivity. A privileged owner check belongs before the
probe.

The deployed Pi helper takes exactly four settings from the environment:
`RFCU_PI_ROS_SETUP`, `REAL_FCU_PI_LOG_ROOT`, `REAL_FCU_READY_TIMEOUT_SECONDS`
and `REAL_FCU_POLL_SECONDS`. Three share the `REAL_FCU_` prefix and one does
not, so a check against a single prefix is incomplete; `HOME` also determines
the default log root. Confirm both prefixes absent and `HOME` correct before a
run whose result will be recorded.

The readiness poll retains one capture pair per attempt, so a wait that runs to
its full timeout leaves roughly `90` files in the run's `evidence/` directory,
most of them small. That is the Block B repair behaving as designed, not a
fault, and the retained attempts are the evidence the 18/08 run could not
provide.

### State at the time of writing

Block E has not been started. The controller, control box and Herelink console
remained off for the whole of Blocks A to D, and `check` requires none of them.
No parameter has been written to the real controller, no bridge was started, and
no simulator session was run. The committed revision is
`dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`, synchronized `0/0`, and this record
is the only uncommitted change.

### Block E approval and execution preparation - APPROVED, NOT STARTED

The operator explicitly approved Block E on 19/08/2026 after Block D Gate 1
passed. This approval covers one non-actuating T0b probe attempt from the
certified deployment root
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819`. It does not
authorize T1, either T2 tier, a parameter write, a mode change, arming, an RC
override, a motor test or any simulator session.

Physical execution remains held while the separate probe-safety audit is
pending. Its accepted result must be recorded before the prepared launch form
becomes operative. Preparation is documentation-only: no Pi command,
serial open, controller power-up or Herelink power-up has occurred under Block
E.

#### Prepared seven-field operator handover

1. **Host and terminal.** Use Pi
   `imt-aqua-drone@10.120.2.249`, hostname `imtaquadrone-desktop`, through
   Remmina. Open a new interactive Pi terminal labelled E1. The probe is one
   foreground process; do not use an SSH command shell, a background process or
   a reused terminal carrying earlier environment values.
2. **Absolute working directory.** Use
   `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819`. Do not use or
   alter the preserved 18/08 deployment root.
3. **Source and environment.** Run no manual `source` or virtual-environment
   activation line. The deployed helper sources
   `/opt/ros/jazzy/setup.bash`, fixes ROS domain `43` and uses the `180 s`
   ready timeout. Before power-up, require
   `HOME=/home/imt-aqua-drone` and zero variables beginning with
   `REAL_FCU_` or `RFCU_PI_`. The launch receives only the seven one-shot T0b
   gate values; neither T2 approval variable may be present.
4. **Prerequisites to confirm.** The accepted probe-safety audit, Block D Gate
   1, the certified five-file deployment and its pinned manifest must still be
   valid. Confirm there is no simulator session, MAVROS node, command bridge,
   live-dashboard helper or other serial client. Validate `sudo` separately,
   then run a privileged owner check for `/dev/ttyAMA0`; only completely blank
   `fuser` output with return code `1` is the free-device result. Before
   energising control electronics, reconfirm propulsion
   isolated, propellers removed, hull restrained, and Herelink sticks and trims
   neutral. Power only the controller/control box needed for the state check and
   keep propulsion power isolated. Keep the Herelink console off if the control
   box and safety indication establish both required states. If Herelink is the
   only established way to confirm disarmed state, power it for that read-only
   observation only, state why it was needed, and do not use rudder-arm, change
   mode or apply any control input. Positively confirm the controller is
   disarmed and hardware safety is ON (safe), and leave both states unchanged.
5. **Stop condition.** Stop before launch if the audit is not accepted, an
   environment override exists, `HOME` differs, `sudo` validation fails, the
   privileged serial check
   reports an owner or error, a conflicting process or simulator exists, any
   physical prerequisite is false, or disarmed plus safety-ON cannot both be
   confirmed. During the probe, use Ctrl+C only for a physical-state change or
   emergency; otherwise let the helper reach its own deadline. Any failure ends
   Block E without a retry. Preserve the run directory and confirm cleanup and
   the final safe physical state. Power down the controller/control box and any
   powered Herelink console first, keep the Pi on only for the retained-evidence
   read and exact-directory copy-back, then power the Pi down and do
   documentation only.
6. **Run behaviour and phase guard.** The final launch is a single complete
   subshell so a partial paste cannot start the probe. It sets the seven gate
   values only inside that subshell, explicitly leaves both T2 approvals unset,
   and invokes only `probe`. The helper starts the two-plugin MAVROS probe on
   `/dev/ttyAMA0:57600`; it does not start the bridge. Whether the attempt
   passes or fails, stop after this one invocation. No later tier follows from
   the Block E approval.
7. **Exact output to return.** Paste the accepted audit result, `HOME`, the
   override count, the `sudo` validation return code, the complete privileged
   `fuser` output and return code, and the fresh physical-state confirmation.
   After the run, paste the complete
   foreground output and probe return code, including the exact
   `REAL_FCU_PI_LOGS` path and `REAL_FCU_PI_EXIT` line. Then paste the retained
   attempt inventory, every observed `connected` and `armed` value, every
   non-empty attempt diagnostic, the T0b evidence inventory and the MAVROS log
   tail. State explicitly whether the connected-and-disarmed state gate was
   ever satisfied. Do not conclude from the newest stable YAML alone.

#### Prepared pre-launch checks - do not run before audit acceptance

In E1, before any control-electronics power-up:

```bash
cd /home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819
printf 'E_HOME=%s\n' "$HOME"
E_OVERRIDE_COUNT="$(env | grep -cE '^(REAL_FCU_|RFCU_PI_)' || true)"
printf 'E_OVERRIDE_COUNT=%s\n' "$E_OVERRIDE_COUNT"
sudo -v
E_SUDO_VALIDATE_RC=$?
printf 'E_SUDO_VALIDATE_RC=%s\n' "$E_SUDO_VALIDATE_RC"
```

Require exactly `E_HOME=/home/imt-aqua-drone`, `E_OVERRIDE_COUNT=0` and
`E_SUDO_VALIDATE_RC=0`. An authentication, configuration, permission or command
failure can make `sudo` return `1`, which collides with `fuser`'s free-device
status. The owner check has no evidential value until this separate gate passes.
Stop and paste all three lines if it does not pass.

Only after `E_SUDO_VALIDATE_RC=0`, run:

```bash
sudo fuser -v /dev/ttyAMA0
E_PRIVILEGED_FUSER_RC=$?
printf 'E_PRIVILEGED_FUSER_RC=%s\n' "$E_PRIVILEGED_FUSER_RC"
```

The only pass is no output at all followed by `E_PRIVILEGED_FUSER_RC=1`.
Return code `0` means a holder was found. Any printed owner or diagnostic, or
any return code other than `1`, stops the block.

After those checks pass, the operator must paste a fresh confirmation covering
all of the following before the launch is released:

```text
propulsion isolated
propellers removed
hull restrained
Herelink sticks and trims neutral
controller/control box powered for control only
Herelink console off, or powered only for read-only disarm confirmation
controller disarmed
hardware safety ON (safe) and unchanged
```

State which Herelink condition applies and, if it is powered, why it is needed.

#### Prepared launch form - held pending audit acceptance

The launch form below records the exact intended environment and is not yet an
instruction to run it:

```bash
(
  export REAL_FCU_T0A_COMPLETE=1
  export REAL_FCU_T0B_APPROVED=1
  export REAL_FCU_START_DISARMED=1
  export REAL_FCU_SAFETY_ON=1
  export REAL_FCU_PROPELLERS_REMOVED=1
  export REAL_FCU_HULL_RESTRAINED=1
  export REAL_FCU_PROPULSION_ISOLATED=1
  unset REAL_FCU_T2A_APPROVED REAL_FCU_T2B_APPROVED
  exec bash tools/real_fcu_digital_twin_pi.sh probe
)
E_PROBE_RC=$?
printf 'E_PROBE_RC=%s\n' "$E_PROBE_RC"
```

Do not stop an otherwise stable run merely because no new terminal output
appears. The ready gate owns a full `180 s` deadline. After readiness, the
helper can spend up to `8 s` on each of two state captures, `20 s` on the
parameter pull and `8 s` on each of `41` parameter reads before it prints the
success marker. The source-defined worst-case silent envelope is therefore
about `544 s`, just over nine minutes, plus small process and parsing overhead.
The only successful end state contains all three markers below and
`E_PROBE_RC=0`:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

#### Prepared retained-evidence read - required before any verdict

Bind `E_RUN_DIR` to the exact absolute path printed by
`REAL_FCU_PI_LOGS`; never select it with a wildcard or by newest timestamp.
After confirming the value on screen, use these read-only commands in E1:

```bash
printf 'E_RUN_DIR=%s\n' "$E_RUN_DIR"
test -d "$E_RUN_DIR"; printf 'E_RUN_DIR_EXISTS_RC=%s\n' "$?"
find "$E_RUN_DIR/evidence" -maxdepth 1 -type f \
  -name 'probe_connected_disarmed.attempt-*' \
  -printf '%f|%s\n' | LC_ALL=C sort
(
  shopt -s nullglob
  set +e
  E_STATE_YAMLS=(
    "$E_RUN_DIR"/evidence/probe_connected_disarmed.attempt-*.yaml
  )
  E_STATE_LOGS=(
    "$E_RUN_DIR"/evidence/probe_connected_disarmed.attempt-*.stderr.log
  )
  printf 'E_STATE_YAML_ATTEMPTS=%s\n' "${#E_STATE_YAMLS[@]}"
  printf 'E_STATE_DIAGNOSTIC_ATTEMPTS=%s\n' "${#E_STATE_LOGS[@]}"
  if [ "${#E_STATE_YAMLS[@]}" -eq 0 ]; then
    printf 'E_STATE_VALUE_GREP_RC=NOT_RUN reason=no-attempt-yaml\n'
  else
    grep -H -E '^(connected|armed):' "${E_STATE_YAMLS[@]}"
    E_STATE_VALUE_GREP_RC=$?
    printf 'E_STATE_VALUE_GREP_RC=%s\n' "$E_STATE_VALUE_GREP_RC"
  fi
  if [ "${#E_STATE_LOGS[@]}" -eq 0 ]; then
    printf 'E_STATE_DIAGNOSTIC_GREP_RC=NOT_RUN reason=no-attempt-log\n'
  else
    grep -Hn . "${E_STATE_LOGS[@]}"
    E_STATE_DIAGNOSTIC_GREP_RC=$?
    printf 'E_STATE_DIAGNOSTIC_GREP_RC=%s\n' \
      "$E_STATE_DIAGNOSTIC_GREP_RC"
  fi
)
find "$E_RUN_DIR/evidence" -maxdepth 1 -type f \
  -name 't0b*' -printf '%f|%s\n' | LC_ALL=C sort
tail -n 120 "$E_RUN_DIR/logs/mavros_probe.log"
```

Zero YAML attempts is an explicit finding: the state-capture loop never reached
its first capture, so neither grep is run against an unmatched glob. With
attempt files present, a grep return code of `1` means the files exist but
contain no matching line; return code `2` from either grep is a read or
invocation error and must be reported. The state gate was satisfied only if a
retained attempt shows both
`connected: true` and `armed: false`. If parameter request and response fails
again, retain that evidence as the confirmed blocker and do not retry. Copy-back
will be bound to the accepted exact run directory after this read; no broad
remote wildcard is permitted.

### End-of-day close-out - Block E deferred without execution

The operator chose to leave the real-FCU execution for 20/08/2026. Block E did
not start on 19/08/2026: no Block E Pi command ran, `/dev/ttyAMA0` was not
opened under this block, the controller/control box and Herelink console were
not powered for it, no parameter was written, the bridge did not start and no
real thrust occurred. The separate probe-safety audit was still pending when
the deferral was recorded, so no audit result is predicted here.

The unused 19/08/2026 Block E approval expires at this day boundary. It does not
authorize a 20/08/2026 probe. Tomorrow must begin with live repository and
deployment certification, the completed audit result, a fresh physical-state
attestation and a new explicit Block E approval before any control electronics
are energised.

The prepared handover was corrected before deferral in four places. `sudo -v`
now has its own required `0` status before the privileged owner check, so a
`sudo` failure cannot collide with `fuser`'s free-device status. The free-device
result is explicitly blank output plus return code `1`. The retained-evidence
read now reports zero attempt files separately instead of passing an unmatched
glob to `grep`, and distinguishes an empty match result from a read error. The
silent-run guidance now includes the source-defined worst case: the `180 s`
ready wait, two captures at up to `8 s`, a `20 s` pull and `41` reads at up to
`8 s`, or about `544 s` plus small overhead. Herelink is no longer assumed
necessary; it stays off unless it is the only established read-only way to
confirm disarmed state.

The current-status audit updated `Board.md`, `wiki/Roadmap.md` and
`web_dashboard/autoboat/README_autoboat_dashboard.md`. Each now records the
19/08/2026 capture repair, `24`-case suite, new dated deployment, passing
non-actuating `check`, unrun Block E and open T0b boundary. Historical dated
rows and the 17/08 and 18/08 diaries remain unchanged. A single 20/08/2026
continuation scaffold carries the fresh-day gate; it carries no approval.

A live fetch at this close-out still showed
`HEAD == main == origin/main == dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`
with divergence `0/0`. That is the pre-documentation baseline, not a predicted
SHA for the commit containing this close-out. Only Markdown files are modified
or added. Final physical shutdown is not inferred from repository or process
state: the last direct record has the controller/control box and Herelink off
and the Pi powered for Block D. A fresh operator confirmation of the powered-off
EOD state is still required before the physical day is closed.
