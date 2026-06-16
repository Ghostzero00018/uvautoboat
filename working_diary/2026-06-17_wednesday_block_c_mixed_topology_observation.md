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

- [ ] Run repo guard:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If the tree is dirty or refs diverge, stop and report before practical work.
- [ ] Re-read the latest two diaries:
  - `working_diary/2026-06-15_to_2026-06-16_ppt_prep_and_seminar_reintroduction.md`
  - `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md`
- [ ] Re-read the current QGC / bridge status rows in `Board.md` and `wiki/Roadmap.md` before making status claims.

## Block B - Block C go / no-go decision

- [ ] Confirm equipment availability:
  - Linux workstation ready
  - QGC available
  - dashboard / rosbridge stack available if needed
  - Herelink / real control-box topology available, if this observation is meant to reproduce the 11/06 mixed setup
- [ ] Confirm the observation goal: one count-only loop and one triplet / clear-burst pattern, if reproducible.
- [ ] Ask for explicit approval before starting Block C.

Decision:

- [ ] Approved - proceed to Block C.
- [ ] Not approved / equipment unavailable - stop here and record deferral.

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

Observation:

- [ ] Capture bridge terminal and QGC console side by side.
- [ ] Attempt to reproduce one count-only loop.
- [ ] Attempt to reproduce one triplet / clear-burst pattern.
- [ ] Avoid upload, arming, mode, parameter, thruster, actuator, or real-FCU command paths.

Result table:

| Anomaly | Observed? | Evidence | Interpretation |
| --- | --- | --- | --- |
| Count-only serve loop | | | |
| Triplicated counts / clear bursts | | | |
| QGC retry warning | | | |
| Visible plan mismatch | | | |

## Block D - Interpretation

- [ ] Use the H1-H4 definitions from `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md` Block B.
- [ ] Compare observed mixed-topology behaviour against the 12/06 clean local-only A/B result.
- [ ] Classify H1 / H2 / H3 / H4 as confirmed, weakened, or still unproven.
- [ ] Keep same-session refresh separate from mixed-topology contention.
- [ ] Do not claim Herelink or real-FCU acceptance from visual-bridge evidence.

## Block E - Optional follow-ups

- [ ] Optional docs cleanup only if explicitly approved.
- [ ] Block E implementation only if explicitly approved, with upload transaction tests before any live QGC upload test.

## Wrap

- [ ] Record whether Block C ran, stayed deferred, or was blocked by equipment.
- [ ] Record exact evidence paths / terminal snippets used for any claim.
- [ ] Run wrap checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-17_wednesday_block_c_mixed_topology_observation.md
  ```

- [ ] Run the public-repo visibility sweep before any commit.
- [ ] Next steps are bounded to the actual outcome above.
