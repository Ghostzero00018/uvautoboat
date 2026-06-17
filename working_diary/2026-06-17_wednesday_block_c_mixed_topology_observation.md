# Wednesday 17/06/2026 - Block C mixed-topology observation

## Purpose

Restart practical work after the 15/06-16/06 PPT / seminar window.

Default focus: decide whether to run the deferred Block C mixed-topology QGC observation from the 12/06 closeout.

## Starting context

- 16/06 seminar is closed with no new project requirement or direction change recorded.
- Resume-hover anomaly is closed unless it recurs: no hover command path was found, `PAUSED` is sticky, and Start / Resume now have confirmation guards.
- 12/06 clean local-only QGC evidence confirmed the v1 visual bridge initial-pull path and the same-session refresh limitation.
- The mixed real+fake topology explanation for 11/06 count-only loops / triplets remains the open observation target.

## Boundaries

- Block C starts only if equipment is available and the user explicitly approves it.
- Mixed-topology work is observation-only: no mission upload, arming, mode change, parameter write, thruster, actuator, or real-FCU command path.
- QGC / dashboard / bridge / Herelink / real-vehicle GUI or live-stack steps are user-run by default; capture output and interpret it here.
- Code, launch, YAML, package, or bridge debug edits need separate explicit approval.
- If equipment is unavailable or approval is not given, record that Block C remains deferred and do not improvise another live test.

## Block A - Repo and source refresh

- [x] Run repo guard:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If the tree is dirty or refs diverge, stop and report before practical work.
- [x] Re-read the latest two diaries:
  - `working_diary/2026-06-15_to_2026-06-16_ppt_prep_and_seminar_reintroduction.md`
  - `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md`
- [x] Re-read the current QGC / bridge status rows in `Board.md` and `wiki/Roadmap.md` before making status claims.

**Outcome:** repo guard passed on 17/06/2026. `git fetch --prune` completed, latest commit was `d0eeacb` (`docs(diary): scaffold 17/06 Block C observation restart`), `git status --short --branch` showed clean `## main...origin/main`, and `git rev-parse HEAD origin/main` returned the same SHA `d0eeacb41c41531bc44e7a725cf5f831e2d95c3a` for both refs. The 15-16/06 diary, 12/06 QGC diary, `Board.md`, and `wiki/Roadmap.md` QGC status rows were re-read before interpreting the run.

## Block B - Block C go / no-go decision

- [x] Confirm equipment availability:
  - Linux workstation ready
  - QGC available
  - dashboard / rosbridge stack available if needed
  - Herelink / real control-box topology available, if this observation is meant to reproduce the 11/06 mixed setup
- [x] Confirm the observation goal: one count-only loop and one triplet / clear-burst pattern, if reproducible.
- [x] Ask for explicit approval before starting Block C.

Decision:

- [x] Approved - proceed to Block C.
- [ ] Not approved / equipment unavailable - stop here and record deferral.

**Outcome:** user confirmed no new concrete seminar feedback after the 16/06 diary. The user also confirmed mixed-topology equipment availability and explicitly approved Block C as a user-run, observation-only run. The safety boundary stayed unchanged: no upload, arming, mode change, parameter write, thruster, actuator, Pi upload, real-FCU command, or real-vehicle command path.

## Block C - Mixed-topology observation, if approved

Pre-test inventory, recorded before interaction:

- [ ] QGC vehicle list and system ids: real vehicle vs bridge `42`
- [ ] QGC comm-link list: local UDP `14550` vs Herelink / real-vehicle link
- [ ] QGC MAVLink forwarding state
- [ ] Whether Herelink console QGC is running
- [ ] Selected vehicle in QGC Plan View
- [ ] Capture method for incoming `target_system` values:
  - bridge debug logging: code edit, approval-gated
  - packet capture: user terminal, interactive sudo if needed

**Inventory note:** the structured pre-test inventory above was not fully captured before interaction, so those boxes stay unticked. The pasted preset only established that Herelink console QGC was not brought up and that Linux QGC could not see the real vehicle id.

Observation:

- [x] Capture bridge terminal and QGC console side by side.
- [x] Attempt to reproduce one count-only loop.
- [x] Attempt to reproduce one triplet / clear-burst pattern.
- [x] Avoid upload, arming, mode, parameter, thruster, actuator, or real-FCU command paths.

**Run evidence:** Linux-side log saved at `/home/ghostzero/Desktop/test_logs_folder/test_logs_17_06_2026_Linux_side.txt`.

Pre-run preset recorded in the pasted log: no Herelink console QGC was brought up, and Linux QGC could not see the real vehicle id. Therefore this run was observation-safe, but it did not establish the mixed real+fake topology needed to discriminate the 11/06 H1 / H2 / H3 branches.

Stack launch succeeded in 44 s with `--use-nvidia`, rosbridge `9090`, camera stream `8080`, dashboard `8002`, navigation stack, RViz, and Gazebo running. QGC launched from `qgc` with GUI/environment warnings only: VA-API driver errors, `speechd` text-to-speech load failure, and APM QML warnings consistent with the bridge's minimal parameter surface. No mission retry, transfer failure, or upload/control warning was present in the captured QGC console excerpt.

Bridge dependency check used the runtime-relevant import form and passed: `import rclpy; from pymavlink import mavutil`. The bridge correctly waited for confirmed `READY`, then activated one 11-item visual mission and served one clean mission download: 3 minimal params, one `MISSION_COUNT=11`, and mission items `seq=0` through `seq=10`, each once and in order. No count-only loop, triplicated count, clear-rejection burst, retry warning, or mid-transaction replacement appeared.

Result table:

| Anomaly | Observed? | Evidence | Interpretation |
| --- | --- | --- | --- |
| Count-only serve loop | No | One `MISSION_COUNT=11`, followed by mission items `seq=0` through `seq=10` | Clean single-GCS download transaction |
| Triplicated counts / clear bursts | No | No repeated `MISSION_COUNT` lines and no `rejected QGC clear request` lines in the captured log | H2/H3 symptom not reproduced |
| QGC retry warning | No | QGC console showed VA-API, `speechd`, and APM QML warnings only | No mission retry / transfer failure evidence |
| Visible plan mismatch | Not tested | Real vehicle id was not visible in Linux QGC | H1 selected-vehicle mismatch remains untested |

## Block D - Interpretation

- [x] Use the H1-H4 definitions from `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md` Block B.
- [x] Compare observed mixed-topology behaviour against the 12/06 clean local-only A/B result.
- [x] Classify H1 / H2 / H3 / H4 as confirmed, weakened, or still unproven.
- [x] Keep same-session refresh separate from mixed-topology contention.
- [x] Do not claim Herelink or real-FCU acceptance from visual-bridge evidence.

**Interpretation:** this was a clean single-GCS local visual pull, not a true mixed-topology reproduction. It supports the known clean-local side of the 12/06 A/B result: when only local QGC pulls from the bridge, the bridge can serve a coherent mission count and item sequence. H1 remains untested because there was no real-vs-bridge vehicle selection state in Linux QGC. H2/H3 were not reproduced and not fully exercised because Herelink console QGC was not running and no real vehicle appeared in Linux QGC. H4 has no evidence because there was one mission activation and one coherent download, with no mid-transaction replacement.

The discriminating Block C target therefore remains open: rerun only after the real vehicle is visible in Linux QGC and/or the Herelink console QGC is running, with vehicle ids, selected vehicle, comm links, MAVLink forwarding state, and capture method recorded before dashboard Generate / Confirm.

## Block E - Optional follow-ups

- [ ] Optional docs cleanup only if explicitly approved.
- [ ] Block E implementation only if explicitly approved, with upload transaction tests before any live QGC upload test.

## Wrap

- [x] Record whether Block C ran, stayed deferred, or was blocked by equipment.
- [x] Record exact evidence paths / terminal snippets used for any claim.
- [x] Run wrap checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-17_wednesday_block_c_mixed_topology_observation.md
  ```

- [x] Confirm public-repo visibility after commit.
- [x] Next steps are bounded to the actual outcome above.

**Current status:** Block C was approved and attempted, but the first run did not establish mixed topology. It is recorded as an observation-safe clean local visual pull with the discriminating mixed-topology observation still open.

**Visibility note:** commit `90fceba` had already landed before this wrap checkbox was closed. A repo-wide visibility sweep was run afterward and returned zero matches; no tracked content leak was found.

**Next steps:** repeat Block C only after confirming the real vehicle is visible in Linux QGC and/or Herelink console QGC is running. Before Generate / Confirm, record real vehicle id, bridge id `42`, selected vehicle, local UDP `14550`, Herelink / real link state, MAVLink forwarding state, Herelink console QGC state, and the chosen capture method. Keep the same no-upload / no-control boundary.
