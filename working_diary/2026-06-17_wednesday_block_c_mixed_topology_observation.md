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

**Inventory note:** the structured pre-test inventory above is scoped to values captured before interaction, and the artifacts do not prove that checklist was completed before Generate / Confirm. The boxes therefore stay unticked. The first pasted preset only established that Herelink console QGC was not brought up and that Linux QGC could not see the real vehicle id. The later Herelink-hotspot run still provides interpretation evidence: real vehicle sysid `1`, selected vehicle `1`, Herelink console QGC running, and Linux QGC on `IMT-Aquatic-drone`; bridge sysid attribution, QGC comm-link list, MAVLink forwarding state, and incoming `target_system` evidence remained unknown.

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

**Second run evidence:** Herelink-hotspot attempt saved under `/home/ghostzero/Desktop/test_logs_folder/block_c_20260617_1447/`.

Pre-test inventory improved but stayed partial. Linux was connected to `IMT-Aquatic-drone` with `wlp147s0` at `192.168.43.160/24` and default route `192.168.43.1`. QGC had UDP `14550` open plus two additional UDP sockets (`42504`, `42505`). The manual inventory recorded that the real vehicle was visible in Linux QGC as sysid `1`, selected vehicle in Plan View was `1`, and Herelink console QGC was running. Bridge sysid, QGC link list, and MAVLink forwarding state were not captured.

Planner evidence stayed safety-clean. The navigation log recorded 9 generated waypoints, then `MISSION COMMAND: confirm_waypoints`, then `Waypoints confirmed - ready to start`. No `start_mission`, `resume_mission`, `go_home`, `DRIVING`, or thrust-command transition appeared in the searched navigation excerpt.

Bridge evidence also stayed clean. The bridge waited for confirmed `READY`, activated one 9-item visual mission about 1 ms after planner confirm, served 3 minimal params, then served one `MISSION_COUNT=9` and mission items `seq=0` through `seq=8` once each. It then served empty fence and rally counts (`MISSION_COUNT=0` for mission types `1` and `2`). No count-only loop, triplicated mission count, clear-rejection burst, QGC retry warning, or mid-transaction replacement appeared.

Herelink console QGC did not show the waypoint route and did not auto-center to Sydney Regatta. This is consistent with the bridge's loopback MAVLink URL (`udpout:127.0.0.1:14550`): the fake visual mission is isolated to the Linux workstation QGC and is not broadcast to the Herelink console. That isolation is safety-positive. The main operational hazard remains QGC-side operator error: Linux QGC had real vehicle sysid `1` selected while a simulated mission was visible, so an accidental QGC Upload action could target the selected real vehicle. The no-upload rule remains mandatory.

Updated result table:

| Anomaly | Observed? | Evidence | Interpretation |
| --- | --- | --- | --- |
| Count-only serve loop | No | First run: one `MISSION_COUNT=11`, `seq=0` through `seq=10`; second run: one `MISSION_COUNT=9`, `seq=0` through `seq=8` | Symptom not reproduced |
| Triplicated counts / clear bursts | No | No repeated mission counts for mission type `0`; no `rejected QGC clear request` lines | H2/H3 symptom not reproduced |
| QGC retry warning | No | QGC logs showed GUI/environment noise only; no mission retry / transfer failure lines | No failed mission transaction evidence |
| Visible plan mismatch | Partially observed, not resolved | Linux QGC had real sysid `1` selected and showed the waypoint route; Herelink console QGC showed no route | H1 weakened but not closed; vehicle attribution in Linux QGC was not captured |

## Block D - Interpretation

- [x] Use the H1-H4 definitions from `working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md` Block B.
- [x] Compare observed mixed-topology behaviour against the 12/06 clean local-only A/B result.
- [x] Classify H1 / H2 / H3 / H4 as confirmed, weakened, or still unproven.
- [x] Keep same-session refresh separate from mixed-topology contention.
- [x] Do not claim Herelink or real-FCU acceptance from visual-bridge evidence.

**Interpretation:** Block C now has one clean local visual pull and one valid Herelink-hotspot mixed-topology attempt. In the second run, the real vehicle was visible in Linux QGC as sysid `1`, selected vehicle was recorded as `1`, Herelink console QGC was running, and Linux QGC was on the Herelink hotspot. Despite that contention setup, the 11/06 count-only loops, triplicated counts, clear bursts, and QGC retry warnings did not reproduce. This weakens H2/H3 for the observed setup, but does not refute them because bridge sysid attribution, QGC link list, MAVLink forwarding state, and incoming `target_system` values were not captured.

Compared with the 12/06 clean local-only A/B result, the second run added real-vehicle visibility and Herelink-hotspot networking, but the bridge transaction still looked clean: one activation, one mission count, ordered mission items, no retry loop, and no triplet burst.

H1 is weakened but still not closed: Linux QGC showed the route while selected vehicle was recorded as sysid `1`, which is not a simple "unselected bridge route stayed hidden" outcome. However, the diary still lacks proof of which vehicle QGC attributed the displayed mission to. H4 has no evidence: both runs had one mission activation and one coherent download, with no mid-transaction replacement.

Same-session refresh remains separate from mixed-topology contention. The Herelink console not showing the route is expected for the current local loopback bridge and is not Herelink acceptance or real-FCU upload evidence. No upload/control path was used.

## Block E - Optional follow-ups

- [x] Optional docs cleanup: approved and landed in `a491b48` (docs-only sync).
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

**Current status:** Block C was approved and attempted twice. The first run was an observation-safe clean local visual pull. The second run established a real Herelink-hotspot mixed-topology attempt and stayed safety-clean, but the 11/06 count-only / triplet symptoms did not reproduce. H1-H3 are weakened but not closed because vehicle attribution, QGC link list, MAVLink forwarding state, and incoming `target_system` evidence remain missing.

**Visibility note:** commit `90fceba` had already landed before this wrap checkbox was closed. A repo-wide visibility sweep was run afterward and returned zero matches; no tracked content leak was found.

**Next steps:** if Block C is repeated, capture the remaining attribution gaps before Generate / Confirm: QGC vehicle list including bridge id `42`, which vehicle QGC attributes the displayed mission to, full comm-link list, MAVLink forwarding state, and incoming `target_system` evidence if approved. Keep the same no-upload / no-control boundary; in mixed topology, QGC Upload is specifically unsafe while the real vehicle is selected.

**Post-wrap note:** the approved docs-sync cleanup landed in `a491b48` — refreshed stale metadata dates and replaced drift-prone code-reference anchors across `Board.md`, `wiki/Roadmap.md`, `wiki/Design_Rationale.md`, `wiki/Dashboard_Security.md`, `web_dashboard/autoboat/README_autoboat_dashboard.md`, and `working_diary/README.md`. Docs only; no code, config, or live-path change.
