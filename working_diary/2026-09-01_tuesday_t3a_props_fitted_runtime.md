# Tuesday 01/09/2026 - Minimal T3a props-fitted runtime

**PRE-DIARY - START WITH THE SMALLEST HONEST T3A SOURCE CHANGE. DO NOT REPEAT
UNCHANGED TESTS FROM 31/08/2026. NO LIVE OR PHYSICAL STATE CARRIES INTO THIS
DAY.**

## Read first

1. this diary;
2. `working_diary/2026-08-31_monday_current_source_sitl_recheck.md`;
3. the T3a tier definition in `Board.md`;
4. `tools/real_fcu_digital_twin_pi.sh`;
5. `tools/real_fcu_command_feedback_capture.py` and its focused test;
6. `tools/test_real_fcu_digital_twin_helpers.sh`; and
7. `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`.

## Carried evidence - reuse it

The 31/08/2026 workstation gate passed Pi lifecycle, W1 `25`, real-FCU helper
`34`, SITL `41`, W2 `23`, Python `133`, Node `80/80`, the four-file bundle,
Python compilation and whitespace checks. The current-source supervised SITL
acceptance and independent adjudication also passed on exact revision
`bba195b` before the later subscriber-only capture change.

The capture-only change does not alter the SITL runner, dashboard, command
bridge, W1, W2 or either Pi runtime helper. Reuse those results. Do not begin
Tuesday by rerunning SITL, W1, W2, Node, the Pi dashboard lifecycle or all
`133` Python tests.

`RC_OVERRIDE_TIME=3.0` is the last retained live readback. It was not read from
the FCU on 31/08/2026 and must not be represented as a fresh Tuesday value.
Do not change it until an honest T3a runtime is implemented, tested, published
and deployed.

## Block A - repository guard

**Host + terminal:** workstation, new one-shot terminal. No ROS or hardware.

```bash
(
  set -euo pipefail
  cd /home/ghostzero/seal_ws/src/uvautoboat

  git fetch --prune origin || {
    echo 'T3A_ABORT=fetch-failed'
    exit 1
  }

  [ "$(git branch --show-current)" = main ] || {
    echo "T3A_ABORT=wrong-branch branch=$(git branch --show-current)"
    exit 1
  }

  [ -z "$(git status --porcelain)" ] || {
    echo 'T3A_ABORT=dirty-worktree'
    git status --short
    exit 1
  }

  read -r AHEAD BEHIND < <(
    git rev-list --left-right --count HEAD...origin/main
  )
  case "$AHEAD:$BEHIND" in
    0:0) ;;
    0:*)
      git pull --ff-only origin main
      echo 'T3A_RESTART=upstream-fast-forwarded reread-diary-and-sources'
      exit 3
      ;;
    *)
      echo "T3A_ABORT=branch-not-contiguous ahead=$AHEAD behind=$BEHIND"
      exit 1
      ;;
  esac

  [ -z "$(git status --porcelain)" ]
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]
  echo "T3A_REPOSITORY=PASS revision=$(git rev-parse HEAD) worktree=clean"
)
```

Stop if this fails. Do not repair, test or deploy from a dirty, ahead or
diverged tree.

## Block B - smallest offline implementation

Implement only the missing props-fitted runtime contract:

1. add a distinct Pi `run-t3a` mode rather than weakening T2b;
2. keep T2b fail-closed on propellers removed and propulsion isolated;
3. require separate T3a approval, propellers fitted, dedicated mechanical
   guarding, a clear exclusion zone, disarmed start and hardware safety ON;
4. make contradictory T2b/T3a declarations fail;
5. extend the recorder with a distinct `t3a --esc-threshold-calibration` tier
   while preserving its five-stream, per-side PWM-bracket and final-disarm
   requirements;
6. replace the dashboard's propellers-removed-only checkbox and inhibited
   policy copy with tier-neutral wording that requires the operator to satisfy
   the active approved tier; otherwise a T3a run would require a false
   declaration;
7. preserve the existing `max_throttle=0.12`, RC mapping, servo rails,
   E-Stop, neutral, disarm and teardown behaviour; and
8. create distinct T3a markers, manifests and run-directory names.

Non-goals: do not change the dashboard command logic, command bridge,
`MOT_THR_MIN`, throttle authority, W1, W2, VRX, Hailo or MAVROS topic
configuration unless a concrete red test proves one is required. The dashboard
edit is policy text only; the Pi mode remains the authority gate.

## Block C - change-driven verification only

Write the smallest red tests first, then implement. After the edit, run only:

```bash
(
  set -eo pipefail
  source /opt/ros/jazzy/setup.bash
  cd /home/ghostzero/seal_ws/src/uvautoboat

  python3 -m unittest tools/test_real_fcu_command_feedback_capture.py
  bash tools/test_real_fcu_digital_twin_helpers.sh
  python3 -m py_compile \
    tools/real_fcu_command_feedback_capture.py
  node --check web_dashboard/autoboat/app.js
  rg -n -i 'propellers removed|propellers-removed' \
    web_dashboard/autoboat/index.html \
    web_dashboard/autoboat/app.js && {
      echo 'T3A_ABORT=dashboard-still-propellers-removed-only'
      exit 1
    } || [ "$?" -eq 1 ]
  sha256sum -c config/real_fcu_digital_twin_bundle.sha256
  git diff --check
)
```

The Pi helper change invalidates its focused helper suite and bundle hash, so
those checks are required. The capture-tier change invalidates its focused
Python suite, so that suite is required. The two dashboard text edits require
only syntax plus a focused wording assertion while command logic remains
unchanged.

Do not rerun these unchanged surfaces:

- Node `80/80` when dashboard command logic is untouched and only the focused
  T3a policy wording changes;
- W1 `25` when `tools/live_dashboard_preflight.sh` is untouched;
- W2 `23` when the FCU-to-VRX files are untouched;
- Pi dashboard lifecycle when `tools/pi_live_hailo_mavlink_dashboard.sh` is
  untouched; or
- supervised SITL when its runner, shared supervisor, dashboard command path
  and command bridge are untouched.

If the command bridge or dashboard command path must change, stop and record
the exact invalidation before scheduling a new SITL acceptance. Such a rerun
would then be decision-changing, not routine repetition.

## Block D - publish and deploy before hardware

After focused green tests, update only adjacent T3a documentation, commit and
push, then prove `HEAD == main == origin/main` with a clean tree. Regenerate the
real-FCU bundle because the Pi helper changed. Deploy it to a new commit-named
Pi root, verify its exact inventory, manifest digest, member hashes and
executable bit, run the non-actuating `check`, and copy the certification back.

Do not reuse the `20260831_bba195b` deployment for T3a. Do not write a new Pi
path or SHA into a command until the new commit and manifest exist.

## Keep the live window simple

Before requesting Block E approval, prepare offline everything that does not
require live hardware: the exact commands generated from the landed bytes,
evidence paths, expected markers, and both normal and abort teardown plans.
Refresh the physical declaration at the actual pre-arm point; an offline draft
does not replace that observation.

The Block E approval must explicitly include the abnormal stop sequence,
including the relationship between supervisor teardown, E-Stop and physical
power isolation. Once the approved live window begins, run
only the prepared sequence. Do not edit source, regenerate a command, diagnose
interactively or try an unreviewed variant while the propellers are fitted and
the T3a hardware is energised.

On any unexpected result, execute only the approved abort and safe-closeout
plan, preserve the evidence and report. This paragraph authorises no retry.
Use the fewest live actions required by the success condition; any other step
stays outside this window.

## Block E - separately gated live test

Only after Blocks A-D pass, request a fresh same-day physical declaration and
live approval. It must establish the actual disarmed/safety/stick state,
propellers fitted, hull restraint, installed mechanical guarding, exclusion
zone, propulsion-power state and that Pi/workstation stacks are down. The
31/08/2026 approval records intent only; it does not attest Tuesday's physical
state.

Then generate the exact landed-source pipeline in this order:

1. Pi parameter preparation with serial free: read `RC_OVERRIDE_TIME=3.0`, set
   `0.5`, fetch and read back, save all parameters, hash the snapshot and write
   guard evidence;
2. workstation dashboard supervisor;
3. workstation T3a correlated capture;
4. Pi `run-t3a` supervisor from the newly certified bundle;
5. straight-steering bounded throttle plateaus with per-side typed
   observations, never exceeding `0.12`;
6. neutral release, E-Stop, external disarm and final safe-state capture;
7. ordered supervisor teardown and evidence copy-back; and
8. mandatory live `RC_OVERRIDE_TIME=0.5 -> 3.0` rollback, full snapshot,
   checksum, transcript, copy-back and serial-free proof.

No live command is pre-pinned here because tomorrow's commit, bundle hash and
deployment root do not exist yet. Generate them from the landed bytes; do not
reuse a stale command block.

## Tuesday success condition

The day closes only if the T3a source contract is red/green proven and
published. A live props-fitted result additionally requires a passing
subscriber verdict, final connected/disarmed evidence, clean supervisor
teardown, copied evidence and verified parameter rollback to `3.0`.

If time is insufficient after Block D, stop there. A certified but unrun T3a
bundle is a valid outcome; an improvised or falsely declared T2b props-on run
is not.
