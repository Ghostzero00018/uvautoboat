# Wednesday 19/08/2026 - T0b evidence repair, probe retry and thrust-twin continuation

**PRE-DIARY - NOT STARTED.** This is the sole 19/08/2026 working diary. It
continues the 18/08 sequence after the failed T0b probe. It does not reopen
Block A, Block C, D0 or D1 Gate 1 from earlier dates.

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
