# 2026-06-12 - Friday: QGC bidirectional mission sync exploration

## Day overview

Continuing from Thu 11/06/2026 ([`2026-06-11`](2026-06-11_thursday_live_qgc_bridge.md)).

Trigger: professor and colleague feedback after the 11/06/2026 live tests. Two issues were raised:

1. **One-way sync.** Waypoints currently flow only dashboard -> QGC. The final-stage requirement is that waypoints — and other possible commands — can be designed and approved from either place, QGC or the web dashboard, with bidirectional information exchange. Exception: display-only data such as water-quality parameters stays on the web dashboard only.
2. **Same-session update failures.** After changing waypoints on the dashboard, QGC only shows the latest route after a full QGC relaunch. In the 11/06 evening test (local QGC additionally linked to the Herelink console via the console hotspot, real control box powered, real vehicle visible in QGC), QGC logged `Flight plan received` yet the visible waypoints did not update, and sometimes warned that the maximum retry count for waypoint update was exceeded. Resending the same route after re-initialising the boat status produced no new `served ...` lines in the bridge terminal.

Primary work for Fri 12/06/2026: **diagnosis and design exploration only.** Map each observed anomaly to a code-level or topology-level explanation, then review a v2 bidirectional design. No code edits unless explicitly approved.

## Inputs - 11/06 evening evidence

Topology: this run was **not** the local-only Block E setup. Local QGC was simultaneously connected to the bridge (`udpout:127.0.0.1:14550`) and, via the Herelink console hotspot, to a real vehicle on a powered control box. The Herelink console runs its own QGC as well.

Bridge log pattern (times local):

- 16:31 bridge start; 16:32 active mission 5 items; 16:32 one full initial-connect serve (params, `MISSION_COUNT=5`, items `seq=0` to `seq=4`).
- 16:35 active 11 items; 16:42 a lone `served MISSION_COUNT=11` with no item requests following.
- 16:44 active 13 items; 16:46 three `MISSION_COUNT=13` serves within ~100 ms, then params plus a full 13-item download, then count-only serves every ~1.5 s until 16:47 with no item requests in between.
- 16:54 active 7 items; 16:58 three `rejected QGC clear request` lines within ~1 ms; `MISSION_COUNT=7` serves arriving in triplets.
- 16:59 active 9 items; 17:03 params plus a full 9-item download, followed by another count-only loop.
- 17:04 active 19 items; no serve afterwards in the captured log.

Code-level facts verified on 11/06 against `tools/qgc_live_mission_bridge.py`:

- **No upload path.** `handle_message` (lines 322-347) handles `MISSION_REQUEST_LIST`, `MISSION_REQUEST` / `MISSION_REQUEST_INT`, `PARAM_REQUEST_LIST`, `PARAM_REQUEST_READ`, `MISSION_CLEAR_ALL` (rejected as unsupported), and `COMMAND_LONG` (unsupported ACK). There is no handler for an incoming `MISSION_COUNT` followed by `MISSION_ITEM_INT` from QGC, so a QGC-side mission upload is silently ignored. Issue 1 is a missing capability, not a defect in the v1 scope.
- **Signature dedup explains the silent resend.** `MissionGate._maybe_activate` (lines 242-243) returns early when the new mission signature (origin, altitude, waypoint x/y tuple) equals the active one, so re-confirming identical waypoints neither re-activates nor re-logs. Expected v1 behaviour, not a fault.
- **No target filtering.** Incoming requests are answered regardless of the message `target_system`; the bridge records only the requester source (line 324) and replies to the most recent one. In a multi-vehicle / multi-GCS topology the bridge can answer mission requests that were not addressed to it.
- **v1 acceptance was local-visual-only**, and the missing same-session refresh was recorded as a known limitation in the 11/06 design review before the live test.

## Boundaries

- **Diagnosis and design only.** Python / JavaScript / launch / YAML / package edits need explicit approval; none is granted by this scaffold.
- **Nothing is sent to the real FCU / control box.** No mission upload, arming, mode change, parameter write, thruster, or actuator path toward the real vehicle. The bridge stays visual-only.
- **Mixed real+fake topology runs are observation-only**, and only with the real-vehicle link explicitly identified and left untouched.
- **Herelink network acceptance stays a separate variant** with its own system-id, routing / firewall, and FCU-isolation checks.
- **Water-quality parameters remain dashboard-only display** per the stated requirement.

## Block A - Repo pre-flight and source refresh

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If the tree is dirty or refs diverge, stop and report before continuing.
- [ ] Re-read anchors before any claim: the 11/06 diary (including both addenda context), `tools/qgc_live_mission_bridge.py` message handling and gate logic, the planner command surface in `plan/plan/waypoint_planner.py` (what `/planning/mission_command` accepts today), and the QGC / bridge rows in `Board.md` and `wiki/Roadmap.md`.

## Block B - Anomaly diagnosis from the 11/06 evidence

- [ ] Classify each anomaly and assign hypotheses:

  | Anomaly | Candidate explanation |
  | --- | --- |
  | `Flight plan received` but visible plan unchanged | H1: Plan view follows the selected vehicle; bridge downloads complete in the background while the real vehicle is selected |
  | Count-only serve loops, no item requests | H2 / H3 / H4 below; identify which |
  | Triplicated counts and clear rejections within ~100 ms | H2 / H3: duplicated requests from forwarding or a second GCS |
  | Maximum-retry warning in QGC | Downstream symptom of the failing download transaction |
  | No new logs on identical resend | Already explained: signature dedup; confirm wording for docs only |

- [ ] Hypotheses to evaluate:
  - **H1 - vehicle selection:** with two vehicles (real + bridge id 42), QGC shows the selected vehicle's plan; a completed background download from the unselected bridge does not change the visible plan.
  - **H2 - missing target filtering:** mission requests addressed to the real vehicle but visible on the 14550 link are answered by the bridge, corrupting transaction state on both sides.
  - **H3 - multiple GCS:** local QGC and the Herelink console QGC (likely both GCS system id 255) both issue requests; replies go to whichever asked last.
  - **H4 - mid-transaction replacement:** the active mission was swapped while a download transaction was in flight, desynchronising count and item sequences.
- [ ] Design the discriminating A/B retest: repeat the same Generate / Confirm sequence in the clean local-only topology (no Herelink link, no control box). If count-only loops and triplets disappear locally, the anomalies are topology-coupled rather than bridge-internal logic faults. Record expected observations for both branches before running anything.

## Block C - Mixed-topology observation plan (only if equipment is available and the user approves)

- [ ] Pre-test inventory, recorded before any interaction: QGC vehicle list with system ids (real vehicle vs bridge `42`), QGC comm-link list (local UDP 14550 vs Herelink link), the QGC MAVLink-forwarding setting, and whether the Herelink console QGC is running.
- [ ] Observation-only repro of one count-only loop and one triplet burst, with QGC console log and bridge terminal captured side by side.
- [ ] Decide the capture method for incoming `target_system` values on the local link: bridge debug logging is a code edit (gated); a packet capture in the user's own terminal needs interactive sudo. Choose and record before running.
- [ ] Per-anomaly outcome table: confirmed / refuted / needs local-only A/B comparison.

## Block D - v2 bidirectional design review (no code)

- [ ] Verify the current planner command surface first; do not design the injection path from memory.
- [ ] Design questions to answer in writing:
  - **Mission authority:** a single source of truth for the active mission, with the dashboard and QGC as two editors of the same state — not a dashboard-owned mission that QGC merely views.
  - **QGC upload reception:** accept the incoming upload transaction (`MISSION_COUNT`, `MISSION_ITEM_INT` sequence, final ACK), validate it, convert GPS back to the local frame (inverse of `local_to_gps()`), and inject it into the planner.
  - **Planner entry point:** a dedicated external-waypoint command or service vs reuse of the existing generate / confirm flow, and what confirm means for a QGC-authored mission (is the QGC upload itself the approval, or does the dashboard still confirm?).
  - **Conflict rules:** QGC edit arriving while the dashboard holds unconfirmed waypoints — last-writer-wins, explicit lock, or operator prompt.
  - **Same-session refresh:** deliberate mechanism options for pushing a changed mission to a connected QGC, with trade-offs, instead of relying on relaunch.
  - **Protocol hygiene:** filter by `target_system`, address replies to the requesting GCS, and replace stateless replies with a per-transaction state machine; required regardless of which refresh mechanism is chosen.
  - **Scope split:** mission data is bidirectional; water-quality and similar telemetry stays dashboard-only.
  - **Safety split:** the visual bridge and any future real-FCU command path stay architecturally separated; bidirectional mission sync must not silently become a real-vehicle upload path.
- [ ] Output: a written v2 proposal with explicit non-goals and over-design traps avoided. Implementation remains gated behind explicit approval.

## Block E - Implementation gate

Start only after the user explicitly approves code/config edits. Not expected on 12/06/2026.

## Block F - Wrap and docs

- [ ] Record which hypotheses were confirmed / refuted and whether the day stayed design-only.
- [ ] Narrow updates to `Board.md` / `wiki/Roadmap.md` only if a diagnosis or design decision lands.
- [ ] Run checks after any edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md
  ```

  Also run the standard public-repo visibility sweep from the terminal before commit.

## Next steps

To fill at wrap on 12/06/2026.
