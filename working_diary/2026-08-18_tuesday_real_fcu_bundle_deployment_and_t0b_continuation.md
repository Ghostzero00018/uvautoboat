# Tuesday 18/08/2026 - Real-FCU bundle deployment and T0b continuation

**PRE-DIARY - NOT STARTED.** This is the sole 18/08/2026 working diary. It
continues the unfinished 17/08 sequence at D1; it does not reopen completed
source blocks, Block C or D0.

The pre-edit repository baseline while drafting this scaffold is
`50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4`. This file does not predict the
commit that contains the 17/08 close-out or this scaffold. At day start,
certify the actual pushed revision and require this baseline to remain its
ancestor.

## Established state

- Blocks B1, B2, B3a and B3b plus the capture-helper change are landed and
  focused-test green. The last commit touching a non-Markdown tracked file is
  `ea8429daab7b7e7c1ba1234589b9899a7135c83c`.
- Block C passed on 17/08/2026 at
  `/home/ghostzero/Desktop/sitl_digital_twin_20260817_162407`: full functional
  path, automatic teardown, final verdict and independent adjudication.
- D0 passed by operator attestation with the controller and Pi off. Connector
  seating and continuity passed for
  `Pi TXD (GPIO14) -> Cube SERIAL1 RX`; T0a is closed.
- D1 was approved on 17/08/2026 but ended before execution. No bundle transfer,
  deployed hash check, Pi `check`, probe, T0b artifact or D1 run directory is
  certified.
- T0b, T2a and T2b remain open. Block E has not started. No real-FCU parameter
  write or real-FCU helper command was issued.

## Read first

1. This file in full. Do not create another 18/08 diary.
2. The `Block C`, `Block D0` and end-of-day sections of
   `working_diary/2026-08-17_monday_real_fcu_dashboard_command_feedback_acceptance.md`.
3. `Board.md` from the T0a-T3b tier table through the 12/08 T0b mismatch and
   13/08 C2 result.
4. `tools/real_fcu_digital_twin_pi.sh`,
   `tools/real_fcu_rc_command_bridge.py`, both physical MAVROS allowlists,
   `config/real_fcu_digital_twin_bundle.sha256` and their focused suites.
5. Before any Block E proposal, also reread
   `tools/real_fcu_digital_twin_workstation.sh`,
   `tools/real_fcu_command_feedback_capture.py` and the dashboard FCU-bench
   README path.

## Block A - certify and prepare only

Only this read-only block is authorized at day start. It starts no simulator,
MAVROS, helper, browser or hardware session.

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -14
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git merge-base --is-ancestor \
  50ae386437f1a8bf5b7c2c4fa07e9f55c3f50de4 HEAD
```

Apply this branch-state guard as one decision:

- fetch failure: stop and report;
- behind only: `git pull --ff-only`, then reread both dated diaries and restart
  certification;
- dirty, ahead or diverged: stop;
- baseline not an ancestor: stop;
- later clean synchronized `HEAD`: inspect every intervening commit before
  continuing.

If `HEAD` still equals the pre-edit baseline, the EOD documentation did not
land; stop before D1 rather than running from an unpublished handoff.

Re-verify the four bundle members and their manifest:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/real_fcu_digital_twin_pi.sh` | `30,852` bytes | `38e41d7dc8181e0f289d3b89c6e374e37cf020cf34e7b03f3cf955981a8efafd` |
| `tools/real_fcu_rc_command_bridge.py` | `40,144` bytes | `cf6668139999308b65a2f8af7ef70f74e226c9bd6c1ac82545bc6c1d0bbb59d7` |
| `config/mavros_real_fcu_closed_loop_plugins.yaml` | `129` bytes | `215293eab9d97e8da5a941d6cb8130351dfbafc07cca7656a766798a2a32b5fc` |
| `config/mavros_real_fcu_t0b_plugins.yaml` | `79` bytes | `5e6008314216785f2de53a617ffec72913e52acbef00645a417f19d7279e7a94` |

Also recheck the three operational artifact pins from the 17/08 diary, the
`13` production pin surfaces, free disk, the six reserved ports and the scoped
process list. Reuse the landed suite results only if no covered source or
dependency changed: SITL helper `41` cases, physical helper `22` cases,
command bridge `26` tests and capture helper `13` tests.

Confirm the physical start state with the control box and Pi off: propellers
removed, propulsion isolated, hull restrained, hardware safety understood,
Herelink sticks and trims neutral, and QGroundControl plus the Herelink
available. Then stop and request explicit approval for Block D1 user-run.

## Block D1 - deploy once and run the non-actuating T0b probe

D1 requires fresh user-run approval after Block A. Every Pi command is run by
the operator in a real Pi terminal opened through Remmina; there is no
interactive SSH terminal. A workstation `scp` transfer is acceptable only as
the byte-preserving transport. Do not substitute reflowed terminal text.

Keep propellers removed, propulsion isolated, the hull restrained, hardware
safety engaged and the controller disarmed. Power only the control electronics
needed for the approved session. Do not release safety, arm, change mode or
write a parameter.

The deployment root is
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818`. It must not already
exist. Create its `tools/` and `config/` directories, transfer the four manifest
members plus `config/real_fcu_digital_twin_bundle.sha256`, and verify all four
hashes from that root before invoking the helper. Any existing destination,
transfer failure or hash mismatch stops D1 without overwrite or retry.

Run `check` first with no T0/T2 approval flags. It must end with:

```text
REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
```

Stop and paste the complete deployment and `check` output before the probe.
The handover must state host and terminal, absolute working directory, exact
source or activate lines, environment variables, prerequisites, stop
condition and exact output to return.

Only after the deployed bytes and `check` are accepted may the operator run
the foreground `probe` with one-shot values for
`REAL_FCU_T0A_COMPLETE=1`, `REAL_FCU_T0B_APPROVED=1`,
`REAL_FCU_START_DISARMED=1`, `REAL_FCU_SAFETY_ON=1`,
`REAL_FCU_PROPELLERS_REMOVED=1`, `REAL_FCU_HULL_RESTRAINED=1` and
`REAL_FCU_PROPULSION_ISOLATED=1`. Do not set either T2 approval flag. The
helper sources `/opt/ros/jazzy/setup.bash`, forces ROS domain `43`, starts only
the two-plugin MAVROS probe and never starts the bridge.

Required success markers are:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

Retain and copy back the exact printed run directory, including
`evidence/t0b.json`, `evidence/t0b_parameters.txt`, the state and safety
evidence, manifest and logs. Bind copy-back to that exact directory; do not use
a broad wildcard. The live artifact must resolve this controller's
`RCMAP_*`, `SERVO*_FUNCTION`, RC rails and servo rails. Simulator values and
the historical real-boat values are not substitutes.

A timeout, refused parameter response, missing mapping or rail, non-disarmed
state, safety failure, helper failure or cleanup failure ends D1 for the day.
Do not retry and do not write `BRD_SER1_RTSCTS` or any other parameter. Confirm
disarmed state and safety, power the controller and Pi down, preserve the logs
and document the blocker.

## Block E - only after D1 passes

Block E remains separately gated. T2a is a fresh neutral-only session using
`run-t2a`; it contains no command publisher or non-neutral demand and ends in
a recorded powered-down state. T2b is a second complete session only after
T2a is closed and recorded and separate T2b approval is granted. Never set
both T2 flags to bypass T2a. Do not start a physical session late in the
available window.

## Boundaries and fallback

- T1 is not authorized: no real-controller parameter write.
- No simulator and real-FCU supervisor overlap.
- No propeller-fitted, powered-thrust, static-propeller or on-water test.
- No manual unrecorded command path and no gate relaxation.
- If equipment, network, deployment, T0b evidence or time fails, retain the
  evidence, power down and use the remainder for documentation only.

## Wrap

Append results only to this file. Preserve the 17/08 diary and dated Board rows
as history. Record the pre-edit baseline while drafting; never predict the SHA
of a commit containing its own close-out text. Stage by explicit path, inspect
the staged content, run the repository checks and leave a clean synchronized
`HEAD == main == origin/main` before the day ends.
