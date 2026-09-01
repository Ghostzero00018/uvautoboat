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

## Blocks B-C outcome - source prepared, not run

The approved workstation-only implementation added a distinct Pi `run-t3a`
mode and a distinct `t3a --esc-threshold-calibration` capture tier. The Pi mode
is demand-enabled within the unchanged `0.20` steering and `0.12` throttle
limits; the capture helper remains subscriber-only with five ROS subscriptions,
typed stdin observations and no write path. T2/T3 approvals and
removed/fitted-propeller declarations are mutually exclusive. Propulsion enable
creates a safe-closeout obligation before the operator input is read. Bounded
closeout handling remains fail-closed under missing, invalid, timed-out, `INT`
or `TERM` input while still reaching final-state capture and child stops; the
recorded default timeout is `300 s`.

Focused red/green verification ended green:

- command-feedback capture: `26` tests;
- Pi helper: `PASS cases=42`;
- Python, Bash and dashboard JavaScript syntax: pass;
- tier-neutral dashboard safety wording: pass;
- regenerated bundle manifest: `4/4`; and
- whitespace validation: pass.

The source/test/dashboard/manifest change covers seven files. The Pi helper
SHA-256 is
`9096536b9150bb7e2a369c4eb0203701cc80af0b9eb96d3866e9aaaa626b1f89`.
No SITL acceptance was repeated because the dashboard edits changed only
tier-policy copy; command logic, topic identifiers, bounds, the command bridge,
runner, operator, evidence and adjudicator code were untouched. W1, W2 and the
Pi dashboard lifecycle were not repeated because their own source surfaces were
untouched. No broad full-suite test was repeated.

Classification at this point is **OFFLINE T3A IMPLEMENTATION / NOT RUN / NOT
DEPLOYED**. No serial endpoint, FCU, parameter, MAVROS/bridge runtime, arm, ESC,
motor or propeller action occurred. The existing
`uvautoboat_real_fcu_bundle_20260831_bba195b` deployment remains exact evidence
for its own bytes and does not contain this T3a runtime.

## Block D status - publication and certification pending

Block D is approved. Adjacent documentation is updated without rewriting the
31/08 historical rows. The next actions are the focused publication checks,
one source/documentation commit and push, then a new commit-named Pi deployment,
exact inventory and manifest verification, executable-bit check, non-actuating
`check`, and workstation copy-back. This status grants no Block E authority;
the live props-fitted window still requires a fresh physical declaration and a
separate T3a approval after certification.

## Block D outcome - published and certified, not run

Block D completed on clean published revision
`025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba`, with `HEAD`, `main` and
`origin/main` equal before transfer. Four checksum-pinned one-shot helpers
prepared the new Pi root, transferred the governed bundle, certified it on the
Pi and copied the evidence back. Their failure paths were reviewed fail-closed,
including fresh `origin` fetch before workstation parity and explicit
propagation of any copied-bundle hash failure.

The new deployment is
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c`. Its exact
five-file inventory, executable helpers, manifest digest
`11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d`
and all four governed member hashes passed. The Pi then ran only
`tools/real_fcu_digital_twin_pi.sh check`, which emitted:

```text
[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
PI_BUNDLE_CERTIFICATION=PASS path=/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c manifest_sha256=11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d log=/home/imt-aqua-drone/Desktop/real_fcu_bundle_check_20260901_025f48c.log
```

The retained copy-back is
`/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`.
It independently passed the manifest digest, all four governed hashes,
executable-bit checks and exact log-marker check before ending
`PI_BUNDLE_COPYBACK=PASS`.

Classification is now **DEPLOYED / CERTIFIED / NOT RUN**. The certification
inspected serial availability but did not run a probe, MAVROS, the command
bridge or the T3a supervisor. It performed no parameter write, safety release,
arm, propulsion action, ESC or motor operation and created no threshold or T3a
acceptance result. Block E remains closed pending a fresh physical declaration
and separate explicit live approval.

## Block E live outcome - functional run, threshold verdict failed

The final live runtime used published revision
`507bfcfa9d1eed0733840188d99905d49c691430`. The retained evidence roots are:

- Pi copy-back:
  `/home/ghostzero/Desktop/pi_run_evidence/t3a_esc_threshold_20260901_193548`;
- W1:
  `/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260901_193313`;
  and
- workstation capture:
  `/home/ghostzero/Desktop/real_fcu_capture_t3a_esc_threshold_20260901_193327`.

The Pi and W1 supervisors both reached READY. The operator then completed the
safe closeout, and the retained Pi record contains
`REAL_FCU_T3A_SAFE_CLOSEOUT=PASS`. Both supervisors captured final
connected/disarmed state, exchanged the workstation stop marker and exited
`status=0 cleanup_rc=0`.

The separate ESC-threshold capture did not pass. Its final verdict is
`pass:false` over `33,598` events, with reasons
`invalid_status_evidence`, `status_publisher_binding_mismatch`,
`calibration_left_observation_incomplete` and
`calibration_right_observation_incomplete`; zero typed annotations were
accepted. Therefore this run is not an accepted threshold calibration.

The retained machine stream still bounds the relevant output points:

- straight steering `0.00`, throttle `0.12`: left/right `954/954 us`;
- steering `+0.03`, throttle `0.12`: left/right `994/913 us`; and
- steering `-0.03`, throttle `0.12`: left/right `913/994 us`.

The operator reported physical onset near `990 us`, consistent with the
measured driven-side change from `980 us` at `0.11` throttle to `994 us` at
`0.12`. This is an operator-observed, machine-bounded interval `(980, 994] us`,
not a formally adjudicated exact ESC threshold.

Classification: **T3A FUNCTIONAL PROPS-FITTED RUN / CLEAN SUPERVISOR
LIFECYCLE; ESC-THRESHOLD CALIBRATION FAILED / NOT ACCEPTED**.
`RC_OVERRIDE_TIME=0.5` remains temporary. No 01/09/2026 rollback-to-`3.0`
artifact exists, so rollback remains open before unrelated controller use or
day close.

## After-hours integrated showcase implementation - offline only

The tracked worktree now implements the requested single-path digital-twin
showcase without adding a second actuator route:

1. dashboard or Herelink demand enters the real FCU;
2. exact measured `/mavros/rc/out` from `/mavros/rc` is the sole W2 actuator
   source;
3. W2 maps that measured output into forward-only VRX thrust; and
4. VRX pose and left/right thrust return to the dashboard through validated
   `/fcu_to_vrx/twin_telemetry` evidence.

The Hailo path uses the stock-COCO `person` label as the sole camera obstacle.
A person or a missing/stale required detection feed raises the stop path for
both the real-FCU bridge and VRX. Clearing the camera does not resume motion by
itself. The operator must request Reset E-Stop while commands and measured
outputs are neutral and the camera supplies fresh-clear evidence, then issue a
new neutral prime before another demand. This reset is reusable: repeated
E-Stop -> safe reset -> new prime -> motion cycles do not require restarting
the stack.

The dashboard ownership button switches between `DASHBOARD` and `HERELINK`.
Dashboard-to-Herelink handover first publishes neutral, waits for neutral
physical RC input, then releases MAVROS override so the Herelink directly owns
the real boat while VRX continues to mirror measured FCU output. Returning to
dashboard control neutralizes again and requires a new dashboard prime.
E-Stop has priority in either ownership state, and both transitions are
repeatable.

The physical Hailo feed is now bound fail-closed to exactly one resolved
`/hailo_person_stop_bridge` publisher at both W1 readiness and every required
detection callback. A missing, wrong, duplicate or unresolved publisher cannot
refresh the clear-water clock. Dashboard Reset and ownership controls also age
out with bridge status and repeat the freshness/eligibility checks at their
publish boundaries.

Focused red/green verification currently passes:

- person-stop monitor: `37` tests;
- real-FCU helper: `PASS cases=55`;
- dashboard Node suite: `90/90`, including MAVLink/bench control `27/27`;
- Python, Bash and dashboard JavaScript syntax; and
- whitespace validation.

The unchanged earlier focused results remain W2 shell `30`, W2 Python `48`,
command bridge `47`, capture `37` and servo mapping `16`. These are reused only
because the final source-authentication and stale-status fixes did not touch
those surfaces.

Classification: **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT
RUN**. No integrated Hailo-camera, real-FCU, Herelink, W2 or VRX execution has
used these worktree bytes. Tomorrow must first land and certify one new bundle,
then run one freshly approved integrated showcase. Unchanged SITL acceptance,
W1/W2 historical tests and unrelated full suites must not be repeated merely
for reassurance.

## Forward correction - physical-stick evidence and reusable handover

The earlier statement that the bridge waits for neutral physical RC input is
withdrawn. ArduPilot applies an active RC override to `radio_in`, and its
`RC_CHANNELS` telemetry reports that effective value. Consequently,
`/mavros/rc/in` reads back the bridge override while it is active and cannot
independently establish the Herelink stick position.

The corrected worktree keeps the existing single-button workflow but makes its
authority explicit and per-event:

- Dashboard-to-Herelink ownership requires the exact
  `HERELINK_STICKS_NEUTRAL` string, sent by the button labelled `Confirm
  Herelink Sticks Neutral & Take Control`; raw `HERELINK` is rejected;
- the token is accepted only from the bound rosbridge publisher in the current
  connected, armed, authorized `MANUAL` epoch with fresh valid feedback;
- three trim frames precede three release frames, and measured
  `/mavros/rc/out` must remain neutral before and during release or E-Stop is
  relatched and trim is reasserted;
- disarm or disconnect returns ownership to `DASHBOARD` and clears any pending
  handover, preventing reuse in a later armed epoch;
- owner-matched E-Stop reset uses `std_msgs/String`:
  `DASHBOARD_COMMAND_NEUTRAL` for Dashboard control or
  `HERELINK_STICKS_NEUTRAL` for Herelink control; and
- Reset cancels pending browser Hold-to-Apply timers without emitting delayed
  Joy frames, so the Reset click cannot silently provide the next Dashboard
  neutral prime.

`/mavros/rc/in` remains freshness/range evidence; explicit operator
confirmation plus neutral measured servo output are the two distinct handover
inputs. Focused verification now passes command bridge `54`, command capture
`37` and dashboard Node `91/91`. The legacy
`HERELINK_WAITING_NEUTRAL` status is rejected by the capture validator.

Classification remains **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT
DEPLOYED / NOT RUN**. No hardware or integrated runtime used these corrected
bytes, and the existing live evidence is not transferred to this worktree.

## Forward correction - fresh release evidence and explicit reprime

The first corrected handover still reused one cached neutral
`/mavros/rc/out` sample across the release sequence. That did not establish the
documented output-neutral condition during release. The focused tests were
changed first and reproduced the defect.

The bridge now increments a process-local generation only in the real RCOut
callback. After the immediate protective trim and three timed trim frames, it
waits for a newer neutral generation before the first release, between each of
the three release frames and after the final release before declaring
`HERELINK_CONTROL`. No new generation leaves the handover pending; a newly
observed non-neutral output latches E-Stop and reasserts trim. Disarm,
disconnect, E-Stop and Dashboard reclaim clear the pending generation gate.

Dashboard reclaim also no longer publishes a disabled-neutral Joy frame from
either the ownership action or the returned status transition. Its button now
states `Switch to Dashboard Control (Neutral Now Required)`. The returned
Dashboard session remains unprimed until the operator explicitly clicks
`Neutral Now`; E-Stop reset remains independently non-priming.

Focused verification remains command bridge `54`, command capture `37` and
dashboard Node `91/91`, with the release and reclaim cases now exercising the
correct evidence semantics. Classification remains **WORKTREE IMPLEMENTATION /
NOT COMMITTED / NOT DEPLOYED / NOT RUN**. No previous bundle or live result
contains these bytes.
