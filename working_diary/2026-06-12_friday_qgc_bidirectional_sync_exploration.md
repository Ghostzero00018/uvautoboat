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

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If the tree is dirty or refs diverge, stop and report before continuing.
- [x] Re-read anchors before any claim: the 11/06 diary (including both addenda context), `tools/qgc_live_mission_bridge.py` message handling and gate logic, the planner command surface in `plan/plan/waypoint_planner.py` (what `/planning/mission_command` accepts today), and the QGC / bridge rows in `Board.md` and `wiki/Roadmap.md`.

**Outcome:** Block A completed on 12/06/2026. `git fetch --prune` completed, `git log --oneline -5` began with `dadad6b`, `3bdbc81`, `817d41d`, `8f83b16`, and `05ab402`; `git status --short --branch` showed clean `## main...origin/main`; and `git rev-parse HEAD origin/main` returned the same SHA `dadad6bf18f2246ee33e25afaaa52f22d14d6843` for both refs. No pull was needed, and no divergence or dirty worktree was present.

Anchors re-read before Block B/D claims: this 12/06 diary, the 11/06 diary Block E and system-Python addendum, `tools/qgc_live_mission_bridge.py` `MissionGate` and `handle_message` / send paths, `plan/plan/waypoint_planner.py` generate + `/planning/mission_command` callback, `Board.md` Phase 5 + 11/06 QGC row, and `wiki/Roadmap.md` Phase 5.2+ + MP/QGC rows.

## Block B - Anomaly diagnosis from the 11/06 evidence

- [x] Classify each anomaly and assign hypotheses:

  | Anomaly | Candidate explanation |
  | --- | --- |
  | `Flight plan received` but visible plan unchanged | H1: Plan view follows the selected vehicle; bridge downloads complete in the background while the real vehicle is selected |
  | Count-only serve loops, no item requests | H2 / H3 / H4 below; identify which |
  | Triplicated counts and clear rejections within ~100 ms | H2 / H3: duplicated requests from forwarding or a second GCS |
  | Maximum-retry warning in QGC | Downstream symptom of the failing download transaction |
  | No new logs on identical resend | Already explained: signature dedup; confirm wording for docs only |

- [x] Hypotheses evaluated:
  - **H1 - vehicle selection:** with two vehicles (real + bridge id 42), QGC shows the selected vehicle's plan; a completed background download from the unselected bridge does not change the visible plan.
  - **H2 - missing target filtering:** mission requests addressed to the real vehicle but visible on the 14550 link are answered by the bridge, corrupting transaction state on both sides.
  - **H3 - multiple GCS:** local QGC and the Herelink console QGC (likely both GCS system id 255) both issue requests; replies go to whichever asked last.
  - **H4 - mid-transaction replacement:** the active mission was swapped while a download transaction was in flight, desynchronising count and item sequences.
- [x] Design the discriminating A/B retest: repeat the same Generate / Confirm sequence in the clean local-only topology (no Herelink link, no control box). If count-only loops and triplets disappear locally, the anomalies are topology-coupled rather than bridge-internal logic faults. Record expected observations for both branches before running anything.

**Outcome:** Block B completed as diagnosis/design only. No live QGC, Herelink, real vehicle, or FCU path was touched.

| Anomaly | Classification | Current explanation | Retest discriminator |
| --- | --- | --- | --- |
| `Flight plan received` but visible plan unchanged | H1 likely, not yet proven | The 11/06 evening run had at least two vehicles visible to local QGC. A complete background download from bridge system `42` can coexist with Plan View still showing the selected real vehicle's plan. This is a UI/selection hypothesis, not a bridge-source proof yet. | In clean local-only QGC, there should be only the fake bridge vehicle. If QGC downloads a changed bridge mission and Plan View still stays stale, H1 is weakened and the refresh mechanism becomes the primary cause. |
| Count-only serve loops, no item requests | H2/H3 primary; H4 secondary | The bridge answers every `MISSION_REQUEST_LIST` it sees and does not inspect incoming `target_system`. It records only the requesting source and replies to that source. In a mixed real+fake link, requests meant for the real vehicle or from a second GCS can trigger bridge counts without a clean item-request sequence. H4 can explain isolated count/item mismatch around an active-mission replacement, but it does not explain repeated count-only loops as well as H2/H3. | If the loops disappear in clean local-only topology, treat them as topology-coupled. If they persist locally, inspect QGC's download state and add `target_system`/transaction logging under the implementation gate. |
| Triplicated counts and clear rejections within ~100 ms | H2/H3 strong | The current code logs one count or clear rejection per incoming request; it has no internal timer that should emit three identical responses in ~100 ms. Triplets therefore point to duplicate incoming MAVLink messages, likely forwarding/noise from the mixed topology or a second QGC. | Clean local-only should not produce triplets. If triplets still appear with only one QGC and one bridge vehicle, the next suspect is QGC retry state or duplicated local UDP links. |
| Maximum-retry warning in QGC | Downstream symptom | MAVLink mission operations retry when the expected next message does not arrive. A contended transaction, wrong selected vehicle, wrong target, or mid-transaction replacement can leave QGC waiting for an item or ACK that never matches its active transaction. | Pair QGC console timestamps with bridge logs. If warnings align with count-only loops or triplets, H2/H3 are strengthened; if they align exactly with mission replacement, H4 strengthens. |
| No new logs on identical resend | Confirmed v1 behaviour | `MissionGate._maybe_activate()` computes a stable signature from origin, altitude, and waypoint x/y tuples. If the signature is unchanged, it returns without replacing `active` or logging a new active mission. | No live retest required; use a changed waypoint set when testing refresh. |
| QGC-side mission upload does nothing | Confirmed missing capability | `handle_message()` handles download-side requests, parameter requests, clear rejection, and unsupported command ACKs. It has no upload transaction path for incoming `MISSION_COUNT` followed by `MISSION_ITEM_INT`. This is outside v1 scope, not a v1 regression. | Implementation gate only: add upload transaction tests before any live QGC upload test. |
| New active mission with no later serve | Confirmed v1 refresh limitation | Mission activation updates the bridge's in-memory snapshot, but the bridge has no mechanism that tells an already-connected QGC to redownload. The 11/06 addendum proved QGC got new routes after relaunch/initial-connect pulls, not through same-session refresh. | Local-only same-session replacement should still remain stale unless QGC is relaunched, manually redownloads, or a new refresh mechanism is implemented. |

Discriminating A/B retest design:

- **A: clean local-only repeat.** Preconditions: no Herelink link in local QGC, no powered real control box visible to local QGC, one local UDP link on `127.0.0.1:14550`, bridge system id `42`, and QGC Plan View empty/clean before the first pull. Expected v1 success branch: initial-connect or manual download yields one coherent `MISSION_COUNT=N` followed by item requests `seq=0..N-1`, no triplets, no repeated count-only loop, and QGC displays the downloaded bridge route. Expected v1 limitation branch: a later dashboard Generate -> Confirm in the same QGC session activates a new bridge mission but does not update QGC until relaunch/manual redownload.
- **B: mixed topology observation.** Preconditions: record selected vehicle, vehicle system ids, QGC comm links, MAVLink forwarding state, and whether Herelink console QGC is running before interaction. Expected topology-coupled branch: triplets/count-only loops reappear only with the real vehicle / second GCS topology. This branch needs either code-gated debug logging or user-run packet capture to prove incoming `target_system` values.

## Block C - Mixed-topology observation plan (only if equipment is available and the user approves)

- [ ] Pre-test inventory, recorded before any interaction: QGC vehicle list with system ids (real vehicle vs bridge `42`), QGC comm-link list (local UDP 14550 vs Herelink link), the QGC MAVLink-forwarding setting, and whether the Herelink console QGC is running.
- [ ] Observation-only repro of one count-only loop and one triplet burst, with QGC console log and bridge terminal captured side by side.
- [ ] Decide the capture method for incoming `target_system` values on the local link: bridge debug logging is a code edit (gated); a packet capture in the user's own terminal needs interactive sudo. Choose and record before running.
- [ ] Per-anomaly outcome table: confirmed / refuted / needs local-only A/B comparison.

**Status:** not started on 12/06/2026. This block requires equipment availability and explicit approval. It stays user-run by default because it involves QGC GUI, Herelink / real-vehicle topology, and possible packet capture.

## Block D - v2 bidirectional design review (no code)

- [x] Verify the current planner command surface first; do not design the injection path from memory.
- [x] Design questions to answer in writing:
  - **Mission authority:** a single source of truth for the active mission, with the dashboard and QGC as two editors of the same state — not a dashboard-owned mission that QGC merely views.
  - **QGC upload reception:** accept the incoming upload transaction (`MISSION_COUNT`, `MISSION_ITEM_INT` sequence, final ACK), validate it, convert GPS back to the local frame (inverse of `local_to_gps()`), and inject it into the planner.
  - **Planner entry point:** a dedicated external-waypoint command or service vs reuse of the existing generate / confirm flow, and what confirm means for a QGC-authored mission (is the QGC upload itself the approval, or does the dashboard still confirm?).
  - **Conflict rules:** QGC edit arriving while the dashboard holds unconfirmed waypoints — last-writer-wins, explicit lock, or operator prompt.
  - **Same-session refresh:** deliberate mechanism options for pushing a changed mission to a connected QGC, with trade-offs, instead of relying on relaunch.
  - **Protocol hygiene:** filter by `target_system`, address replies to the requesting GCS, and replace stateless replies with a per-transaction state machine; required regardless of which refresh mechanism is chosen.
  - **Scope split:** mission data is bidirectional; water-quality and similar telemetry stays dashboard-only.
  - **Safety split:** the visual bridge and any future real-FCU command path stay architecturally separated; bidirectional mission sync must not silently become a real-vehicle upload path.
- [x] Output: a written v2 proposal with explicit non-goals and over-design traps avoided. Implementation remains gated behind explicit approval.

**Current planner command surface:** `/planning/generate_waypoints` is a `Trigger` service that generates the lawnmower path, sets `WAITING_CONFIRM`, publishes `/planning/waypoints`, and republishes mission status. `/planning/mission_command` is a JSON-over-String command channel. The callback currently recognises `confirm_waypoints`, `start_mission`, `resume_mission`, `cancel_waypoints`, `reset_mission`, `joystick_enable`, `joystick_disable`, and `go_home`. None of those commands accepts an arbitrary external waypoint list; `go_home` is a special one-point overwrite, not a general mission import surface. Therefore QGC-authored waypoint injection needs a new planner entry point or an explicit extension of the command schema; it should not be described as already supported.

**Recommended v2 shape: peer mission editor model.** Treat the planner-side mission authority as the single source of truth, with QGC and the web dashboard as two editors of that state. The bridge should stop being "dashboard mission viewer for QGC" and become a protocol adapter between MAVLink mission transactions and the mission authority. The active mission record should carry at least a version / opaque id, source editor, waypoint list in local x/y, GPS origin, state (`DRAFT`, `WAITING_CONFIRM`, `READY`, `DRIVING`, etc.), and timestamp.

**QGC upload reception.** Add an upload transaction state machine before any live upload test. Per the MAVLink Mission Protocol checked on 12/06/2026 (<https://mavlink.io/en/services/mission.html>), QGC upload starts with `MISSION_COUNT`; the vehicle side requests each item with `MISSION_REQUEST_INT`; QGC replies with `MISSION_ITEM_INT`; and the vehicle sends final `MISSION_ACK` after the last valid item. The v2 bridge should:

- accept only mission type `MAV_MISSION_TYPE_MISSION` for the visual bridge;
- reject or ignore fence/rally until explicitly scoped;
- filter incoming upload/download messages by `target_system == 42` and the bridge component where applicable;
- keep a per-GCS transaction keyed by requester system/component, not a single global `_target_system`;
- request items in sequence and reject/cancel out-of-window or unsupported commands;
- validate finite lat/lon/alt, `MAV_CMD_NAV_WAYPOINT`, supported global `_INT` frame, count limits, and duplicate/out-of-sequence behaviour;
- convert GPS waypoints back to local x/y using the inverse of `local_to_gps()` against the current `/planning/config` origin;
- publish to the planner only after the complete upload validates, so a partial upload never replaces the current mission.

**Planner entry point.** Preferred later implementation: a dedicated planner import surface with ACK/error semantics, e.g. `load_external_waypoints` carrying source, version, origin, and local waypoints. If custom ROS interfaces are deferred, a narrow JSON command extension on `/planning/mission_command` can work for a prototype, but it must publish a clear status/error event so the MAVLink side can send the correct final `MISSION_ACK`. Reusing `generate_waypoints` is wrong because QGC-authored geometry is already defined; it should not trigger lawnmower generation.

**Confirm semantics.** For peer editing, a successful QGC upload should mean "mission approved by QGC editor" and should land as `READY`, not as a dashboard preview waiting for a second dashboard Confirm. It still must not start motion; `start_mission` / driving remains a separate operator action. Dashboard-generated waypoints keep the existing Generate -> Confirm flow. The dashboard should display QGC-authored missions as current/ready and expose Reset/Start/Cancel consistently.

**Conflict rules.** Do not silently overwrite an unconfirmed dashboard draft. Initial v2 rule: if the dashboard is in `WAITING_CONFIRM`, reject a QGC upload with a busy/error result and keep the existing draft. If no unconfirmed draft exists, accept the QGC upload as the new `READY` mission and increment the mission version. Later UI work can add an operator prompt or explicit lock, but last-writer-wins is too easy to misread during mixed QGC/dashboard operation.

**Same-session refresh.** Use a deliberate refresh mechanism instead of relying on relaunch. Recommended protocol-aligned path: maintain a mission version / opaque id, expose it through `MISSION_CURRENT` and `MISSION_COUNT` where supported, and make QGC redownload when it detects the id changed or when the operator triggers Plan View download. Because QGC behaviour still needs live confirmation, keep a fallback for v2 acceptance: a documented manual Plan View redownload or clean reconnect proves the transaction path while a later enhancement tests automatic same-session refresh. Avoid fake "new vehicle id per edit" as the main design; it hides state-management bugs and creates vehicle clutter.

**Protocol hygiene required for both directions.** Add target filtering, per-requester transactions, idle/upload/download states, timeout/cancel handling, and explicit unsupported ACKs. The current stateless "reply to latest source" model is enough for local visual v1 but unsafe in any mixed topology.

**Safety and scope split.** Bidirectional mission sync remains a visual/planner-data path until separately validated. It must not upload to the real FCU, arm, change mode, write parameters, or drive actuators. Water-quality and similar telemetry remain dashboard-only display unless a separate design changes that. Real-FCU mission upload should be a different path with its own bench-safety gate.

**Non-goals for v2 design.**

- No real vehicle mission upload or command/write path.
- No Herelink acceptance claim from local-only evidence.
- No water-quality editing in QGC.
- No generic MAVLink command bridge for arbitrary commands.
- No replacement of the dashboard UX; QGC and dashboard become peer editors of mission data only.

**Over-design traps avoided.**

- Do not build a general MAVLink router inside the bridge; use narrow mission-protocol handling.
- Do not store `.plan` files as the source of truth; keep them as debug/export artifacts only.
- Do not add dashboard prompts before the minimal conflict rule is needed.
- Do not combine visual bridge and real-FCU upload in one class or launch path.

## Block E - Implementation gate

Start only after the user explicitly approves code/config edits. Not expected on 12/06/2026.

## Block F - Wrap and docs

- [x] Record which hypotheses were confirmed / refuted and whether the day stayed design-only.
- [x] Keep durable docs frozen pending explicit approval; no `Board.md` / `wiki/Roadmap.md` edits made.
- [x] Run checks after any edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-12_friday_qgc_bidirectional_sync_exploration.md
  ```

  Also run the standard public-repo visibility sweep from the terminal before commit.

**Outcome:** Day stayed diagnosis/design-only through Block D. No Python, JavaScript, launch, YAML, package, durable-doc, real-FCU, control-box, arming, mode-change, parameter-write, actuator, thruster, Pi-upload, or real vehicle command path was touched.

Hypothesis status from source review:

- **Confirmed:** missing QGC-upload capability is a v1 scope gap; identical resend silence is expected signature dedup; same-session refresh is a known v1 limitation; current planner has no generic external-waypoint injection surface.
- **Likely but not proven:** H1 selected-vehicle mismatch for "Flight plan received" with unchanged visible plan; H2/H3 mixed-topology duplicate / wrong-target mission transactions for count-only loops, triplets, and clear bursts.
- **Secondary / needs retest:** H4 mid-transaction replacement can contribute to count/item mismatch but is not the primary explanation for repeated count-only loops.

Durable docs remain frozen on 12/06/2026 because no explicit durable-doc retouch approval has been given. If approved later, retouch only the forward-looking Phase 5.2+ paragraphs in `Board.md` and `wiki/Roadmap.md`; do not edit the dated 23/04/2026 history rows.

## Next steps

Next options, all still gated:

1. Clean local-only A/B retest, user-run by default, to separate v1 refresh limitation from mixed-topology effects.
2. Block C mixed-topology observation only if equipment is available and explicitly approved.
3. Durable-doc retouch of only the forward-looking Phase 5.2+ paragraphs if explicitly approved.
4. Block E implementation only after explicit code/config approval, with upload transaction tests before live QGC upload.
