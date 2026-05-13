# 2026-05-18 — Monday: post-break sim regression + 13/05 log audit + doc sweep

## Context

Day after Thu 14/05 + Fri 15/05 off-site (Ascension Day + pont — no on-site
work). Last working day was Wed 13/05; final state on `origin/main` is
`336b006 docs: post-wrap audit — IoT managed-egress + RealSense tooling`,
working tree clean.

**Three lead items today (user-directed):**

1. **Sim stack regression test under default `ROS_DOMAIN_ID`.** During
   Wed 13/05 C.7 RealSense bridge validation, `export ROS_DOMAIN_ID=56`
   was unset from the workstation's `~/.bashrc` (so the default
   domain 0 now applies — this was needed for the Pi 5 to be discovered
   under its default-domain `realsense2_camera_node`). Before the rest
   of the week's work, verify the full AutoBoat sim stack still runs
   cleanly under default domain 0 — Gazebo + Rviz + web dashboard
   end-to-end smoke test.
2. **13/05 terminal-log audit.** A plain-text TXT file on the Linux
   workstation captures all 13/05 terminal sessions verbatim (first-hand
   log of the C.6 / C.7 work). Cross-check this against the current
   diary write-up + `wiki/Common_Issues.md` MP-Linux & RealSense entries
   - `wiki/Pi5_Bringup_Smoke_Test.md` + `Board.md` / `Roadmap.md` 13/05
   timeline rows. Flag any stale or incorrect doc claims; harvest
   experiment-idea backlog from log details the diary may have
   compressed out.
3. **General stale-doc / incorrect-claim sweep.** Broader-than-13/05
   pass: anything the audit surfaces that doesn't fit the 13/05 scope.

**Wed 20/05/2026 10h-12h formal joint supervisor presentation is the
hard deadline this week.** Mon 18/05 + Tue 19/05 are the prep window.
**Experiment scope is explicitly capped today** — limit new sim / Pi
runs to what the regression test and log audit need. The bigger Phase 5
backlog items (driver bring-up planning, hardware power-design pass,
camera-consumer sharing) wait until after the presentation.

**Week shape:**

- **Mon 18/05 (today)** — sim regression + log audit + doc sweep; PPT
  prep starts in earnest mid-week.
- **Tue 19/05** — PPT drafting / rehearsal; address any blockers
  surfaced Mon.
- **Wed 20/05** — 10h-12h supervisor presentation (joint work meeting);
  afternoon decompression / day wrap.
- **Thu 21/05 / Fri 22/05** — TBD, post-presentation; potential pivot
  to Phase 5 driver bring-up planning if presentation lands cleanly.

**Pre-break carry-forwards (still pending — no on-site activity Thu/Fri):**

- Phase 5 hardware power-design pass (Roadmap §3 — regulated ≥5A 5V
  supply for Pi 5, bulk capacitance near Pi power input, thick-short
  GPIO leads or proper USB-C input, possibly powered USB hub between
  Pi and RealSense to fully decouple RealSense current spikes).
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  single canonical camera node + RTP republish for Herelink, or
  multi-mux camera-fork daemon at v4l2 layer).
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology).
- Second-site (lake) Herelink video A/B retest — next field session.
- VRX §8.2 weekly cadence — **DUE today** per the Mon 11/05 schedule.

Active blocks:

1. **Block A — Morning re-orientation** (~10 min, opening): verify
   `15c62ac` HEAD on disk + remote sync; re-anchor on Wed 13/05's
   Pi-stays-headless directive + brownout root-cause + C.7 RealSense
   bridge validation; VRX §8.2 cadence check (DUE today); break inputs.
2. **Block B — Sim stack regression under default `ROS_DOMAIN_ID`**
   (~45-60 min, AM): bashrc verification + repo-wide `ROS_DOMAIN_ID`
   grep + `--use-nvidia` launcher run + `ros2 node list` / `topic list`
   - dashboard browser tab smoke + health check + short mission cycle.
   Pass criteria mirror 04/05 + 30/04 cold-boot baselines.
3. **Block C — 13/05 terminal-log audit** (~60-90 min, mid-AM/PM):
   user identifies the TXT log path; cross-reference against 13/05
   diary + Common_Issues + Pi5_Bringup_Smoke_Test + Board / Roadmap
   13/05 rows; classify findings (stale / accurate / borderline /
   new-experiment-idea); inline-fix the obvious stale items; queue
   the bigger ones for post-presentation.
4. **Block D — Stale-doc sweep & fix application** (~30-45 min, PM):
   broader-than-13/05 pass; apply low-risk inline fixes; queue
   bigger items for post-presentation; stamp bumps if substantive.
5. **Block E — Day wrap** (~30 min, evening): diary outcomes, Board.md
   Mon 18/05 Timeline row if substantive, commit + push, sketch Tue
   19/05 PPT priorities.

**Hard boundary today:**

- **PPT prep priority is the back half of the week.** Today's three
  lead items must leave headroom for Tue 19/05 slide work. Wed 20/05
  presentation is the actual deliverable.
- No Python / YAML edits without explicit user permission.
- No Phase 5 driver bring-up code; no big-scope new features.
- Pi 5 stays Ubuntu Server headless permanently (Wed 13/05 supervisor
  directive — superseded the earlier Branch B DE-install authorisation).
- Block B regression test is workstation-side only; no offline-window
  switch needed unless Block C surfaces a Pi-specific question.

**Fallback if sim stack regresses under default `ROS_DOMAIN_ID`** (Block B
catches an actual failure): triage in-session; if root cause needs more
than ~30 min, file as a focused follow-up session for Tue 19/05 and
proceed to Block C with a default-domain caveat noted. Don't burn the
whole day on it — presentation prep is the higher-priority output.

---

## Block A — Morning re-orientation (~10 min, opening)

After Thu/Fri off-site break:

- `git log --oneline -10` + `git status` — verify `15c62ac` HEAD on disk
  - branch synced with `origin/main`.
- Re-read Wed 13/05 diary Block C.6 (brownout root-cause + Pi
  session-hardening config edits + Branch B permanently shelved per
  supervisor directive) and Block C.7 (outcome (i) RealSense bridge
  validation under default `ROS_DOMAIN_ID` + camera-consumer-exclusivity
  finding) — the anchors for today's regression test.
- **VRX §8.2 weekly cadence — DUE today** per the Mon 11/05 schedule:

  ```bash
  cd ~/seal_ws/src/vrx
  git status --short
  git pull --ff-only
  git branch --show-current                                      # expect autoboat/main
  git log autoboat/main --not upstream/jazzy --oneline | wc -l   # expect 1 (bake-in e384cd65)
  git tag --sort=-creatordate -l 'v*' | head -3                  # expect v3.1.2 still top
  ```

  4 triggers (patch count, custom mods, Phase 5 sim coupling, upstream
  major release) — HOLD stands unless one fires.

- Break inputs — check supervisor / teammate replies, weather, any
  presentation-related comms (deck request, scope confirmation). If
  email / Slack not reachable from this Agent context, ask the user.
- Pi 5 reachability check — defer unless Block C surfaces a Pi-specific
  question. Block B is fully workstation-side.

**Outcome.** [To fill — git state, VRX cadence verdict, break inputs,
Pi-side test decision.]

---

## Block B — Sim stack regression under default `ROS_DOMAIN_ID` (~45-60 min, AM)

**Why this matters.** Wed 13/05 C.7 unset `export ROS_DOMAIN_ID=56` from
the workstation's `~/.bashrc` so that the Pi 5 (running its own
`realsense2_camera_node` under default domain 0) could be discovered
cross-machine without a per-session export. The AutoBoat sim stack —
Gazebo + all ROS 2 nodes + rosbridge + web dashboard + Rviz — was
previously running under `ROS_DOMAIN_ID=56`. **Question: does any piece
of the sim stack hardcode-depend on domain 56**, or is the launcher /
nodes / dashboard / health check fully env-neutral?

**Pre-check (no launch yet):**

```bash
# Verify the change actually persists in bashrc
grep -n 'ROS_DOMAIN_ID' ~/.bashrc           # expect: no matches (or commented out)
echo "Active domain: ${ROS_DOMAIN_ID:-default(0)}"

# Sweep the repo for any hardcoded ROS_DOMAIN_ID references
git grep -nIE 'ROS_DOMAIN_ID' -- ':(exclude)working_diary/*' ':(exclude)legacy/*'
```

If the repo grep surfaces any `ROS_DOMAIN_ID=56` in launcher / health-check
script / dashboard JS / launch YAML / shell — those would explain a
regression before launching anything. Flag and decide whether to inline-fix
(likely trivial: drop the export or make it `${ROS_DOMAIN_ID:-0}`) or
surface for user decision.

**Launch + smoke (~30 min):**

```bash
# Fresh terminal — confirm domain is default (0) before sourcing anything
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-default(0)}"
source ~/seal_ws/install/setup.bash
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
# Wait for the "Total launch time: N s" footer — should land ~43-52 s
# based on prior cold-boot baselines (04/05 = 52 s, 30/04 = 43 s,
# 05/05 warm = 44 s).
```

**Capture runtime graph + diff against last-known-good (05/05) state:**

```bash
ros2 node list > /tmp/mon_node_list.txt
ros2 topic list > /tmp/mon_topic_list.txt
ros2 service list > /tmp/mon_service_list.txt

echo "=== node count ==="; wc -l /tmp/mon_node_list.txt
echo "=== nodes ==="; cat /tmp/mon_node_list.txt
echo "=== topic count ==="; wc -l /tmp/mon_topic_list.txt
```

Pass criteria (matches 04/05 + 05/05 + 30/04 cold-boot baselines):

- 5 expected named nodes up — `/lidar_perception`, `/waypoint_planner`,
  `/heading_controller`, `/AutoBoat`, `/waypoint_visualizer`
  (post-16/04 refactor names).
- 0 `BrokenPipeError` in `/tmp/autoboat_launcher_probe.log` — 29/04
  `62636e9` SIGPIPE capture-then-grep refactor should hold.
- No new today-dated `/var/crash/_opt_ros_jazzy*.crash` files.
- Dashboard browser tab at `http://localhost:8002` loads; map renders
  (Path A vendored libs from 05/05 mean no jsdelivr / unpkg / OSM tile
  internet dependency for first-load); camera panel renders; JSON
  panels populate with live data (mission_status, anti_stuck, etc.).
- Health check service: 49 PASS in IDLE state (per 28/04 + 04/05
  baselines).
- Short mission cycle: `autoboat_cli generate/confirm/start` → reach
  at least 1 waypoint → `autoboat_cli stop`. (Skip the full 16-waypoint
  cycle — not needed for regression evidence.)

**If regression observed**: capture exact symptom (which node is missing /
which topic is missing / which dashboard panel is blank) before debugging.
Compare against 13/05 final state to isolate the bashrc-change effect.
Most likely class if it does regress: the launcher or one of its sourced
scripts re-exports `ROS_DOMAIN_ID=56` (which would explain why Pi 5 work
in C.7 needed the bashrc unset — it can't survive that re-export inside
the launcher's shell anyway, so this scenario is structurally unlikely
but worth ruling out by grep).

**Clean shutdown:**

```bash
# Per Mon 13/05 Block C.6 pitfall + §5 pkill self-kill: avoid pkill -f
# patterns whose argv contains the pattern. Use ps + awk + xargs kill
# alternation pattern.
ps -eo pid,cmd | awk '/(launch_autoboat_complete|gz sim|rosbridge|rviz2)/ && !/awk/' \
  | awk '{print $1}' | xargs -r kill 2>/dev/null
sleep 5
ros2 daemon stop
```

**Outcome.** [To fill — bashrc grep result, repo-side `ROS_DOMAIN_ID`
grep result, launcher result (5/5 nodes? launch time? BrokenPipeError
count? new crashes?), dashboard panel state, health check count, short
mission result. Regression-found-or-not verdict + root cause if regressed.]

---

## Block C — 13/05 terminal-log audit (~60-90 min, mid-AM/PM)

**Setup:** user identifies the path to the 13/05 terminal-log TXT file
(saved on the Linux workstation; not in the repo). Read in full, then
cross-reference against the 13/05 diary write-up and adjacent docs.

**Targets for cross-reference:**

```text
working_diary/2026-05-13_wednesday_doc_sweep_deeper_pass.md   ← Wed diary
Board.md                                                       ← 13/05 Timeline row
wiki/Roadmap.md §1.3 (managed-egress correction) + §3 + §9     ← 13/05 entries
wiki/Common_Issues.md (RealSense / camera-consumer-exclusivity / IoT egress)
wiki/Pi5_Bringup_Smoke_Test.md (headless-permanent revision)
```

**Audit framework (mirrors Wed 13/05 Block B classification):**

- **stale** — diary or wiki claim contradicts the terminal log
- **accurate** — diary / wiki matches log evidence cleanly
- **borderline** — wording soft, ambiguous, or compressed but not
  strictly wrong
- **new-experiment-idea** — log surfaces a follow-up worth queuing
  (post-presentation)

**Read pattern:**

1. Skim the TXT log start-to-end to understand session shape.
2. For each substantive log block (each terminal session / each Pi
   SSH sequence / each launcher run / each RealSense bring-up attempt),
   identify what doc claim it supports or contradicts.
3. Build a findings table: `file:line` → claim → log evidence → verdict.
4. Inline-fix the **stale** items with high confidence + low ambiguity;
   queue everything else.

**Specific claims worth verifying against the log** (drawn from the
13/05 diary write-up — easy to spot-check):

- C.6 pre-flight: `getent ahostsv4 archive.ubuntu.com` → `104.20.28.246`;
  `curl -4 -sI http://archive.ubuntu.com/ubuntu/` → `HTTP/1.1 200 OK`;
  `ping -c 1 -W 3 1.1.1.1` → 0/1 received.
- C.6 brownout: PMIC under-voltage threshold ~4.63 V; the ~3-4 s rviz2
  streaming window before "sleep".
- C.7 RealSense device: D435I serial `213622070342` FW v5.14.0
  Product ID `0x0B3A` USB 2.1 port `2-1`; profiles depth Z16
  640×480 @ 15 fps, color RGB8 640×480 @ 15 fps, IR1+IR2 Y8
  640×480 @ 15 fps, accel 100 Hz, gyro 200 Hz; driver v4.57.7 /
  librealsense v2.57.7.
- C.7 camera-consumer-exclusivity: `xioctl(VIDIOC_S_FMT) failed,
  errno=16 Last Error: Device or resource busy`.
- Block A presentation: Wed 20/05/2026 10h-12h scheduled.

If the log says something different on any of these, it's a stale
claim — fix inline.

**Hard scope cap.** Don't escalate the audit into a full Wed 13/05
re-do — the goal is doc-quality polish + experiment-idea harvest, not
new real-world testing today. Wed 20/05 presentation is the actual
output.

**Outcome.** [To fill — log path used, findings count by class, inline
fixes applied (file:line list), experiment ideas queued (with rough
priority), any items deferred to post-presentation.]

---

## Block D — Stale-doc sweep & fix application (~30-45 min, PM)

Block C may surface findings that fit into Block D's broader sweep; pull
through here. **Inspect-only by default** for anything beyond the obvious
inline fixes from Block C.

**Targets** (broader than Block C's 13/05-anchored scan):

- `README.md` — any drift since Mon 11/05 last touch?
- `USER_MANUAL.md` — last substantive edit 06/05 per Tue 12/05 E.6;
  re-verify the stamp + content alignment.
- `wiki/Home.md` / `wiki/README_WIKI.md` / `working_diary/README.md` —
  stamp bumps if today lands substantive content (currently at the
  post-Wed-`4a0b277` re-bump state, likely `13/05/2026`).
- `web_dashboard/autoboat/README_autoboat_dashboard.md` — last
  substantive edit 07/05 per Tue 12/05 E.6 verification.
- Roadmap §3 status table rows added 13/05 (Pi 5 power budget,
  RealSense bridge validated, camera consumer exclusivity) — verify
  they read cleanly post-break.

**Risky-term grep pattern** (same shape as Tue 12/05 Block E + Wed 13/05
Block B):

```bash
for f in README.md USER_MANUAL.md Board.md \
         wiki/Home.md wiki/README_WIKI.md wiki/Roadmap.md \
         working_diary/README.md \
         web_dashboard/autoboat/README_autoboat_dashboard.md; do
  echo "=== $f ==="
  grep -nIE 'fail|degrad|unresolved|open|TBD|deferred|pending|broken|missing|todo' "$f" | head -10
done
```

Then read each hit in context. Cross-check against today's known state
(Block B regression verdict + Block C audit findings + Wed 13/05 final
state on `origin/main`).

**Outcome.** [To fill — files swept, findings classified, fixes
applied vs queued, stamp bumps landed.]

---

## Block E — Day wrap (~30 min, evening)

Same shape as Wed 13/05 Block D:

1. `git log --oneline -10` — sanity check today's commits.
2. `git diff --check` — whitespace / conflict-marker sweep.
3. Pre-commit invisibility sweep — expect 0 matches.
4. Add 18/05/2026 `Board.md` Timeline row **if substantive findings
   landed**; bump header `Last Updated` + footer `Document Version`
   (9.11+ → next) if any tracked content updated. **Use search rather
   than line numbers** (both rows drift as Board.md grows).
5. Fill all `[To fill]` placeholders in this file.
6. Working diary commit; subject template depends on dominant outcome:
   - Clean regression + clean audit:
     `docs(diary): wrap 18/05 sim regression OK + 13/05 audit clean`
   - Regression caught + audit findings:
     `docs(diary): wrap 18/05 sim regression fix + 13/05 audit findings`
   - Audit-only (regression skipped):
     `docs(diary): wrap 18/05 13/05 log audit + doc sweep`
   - Mixed:
     `docs(diary): wrap 18/05 post-break sim check + log audit`
7. Push.
8. **Queue Tue 19/05 PPT prep priorities** — which slides need new
   content from 13/05 work? Power-budget finding? RealSense bridge
   validation? Pi-stays-headless directive? Camera-consumer-exclusivity?
   Sketch a slide outline at session end if time permits.
9. **Update Week 10 / Week 11 external diary if applicable** — Week 10
   wrap was Wed 13/05; if Mon's work fits Week 11 scope, draft Week 11
   external diary skeleton. Windows-side; defer to next Windows session
   if Linux-only today.

**Outcome.** [To fill at end of day.]

---

## Verification summary — 18/05 (check at end of day)

- [ ] Block A: re-orientation done; `15c62ac` HEAD confirmed; VRX §8.2
  cadence check run (HOLD or trigger noted); break inputs noted;
  Pi-side test decision recorded
- [ ] Block B: sim stack regression test run; pass-criteria verdict
  recorded; any regression debugged or filed as Tue 19/05 follow-up
- [ ] Block C: 13/05 log audit complete; findings classified (stale /
  accurate / borderline / new-experiment-idea); inline fixes applied;
  experiment backlog queued for post-presentation
- [ ] Block D: stale-doc sweep across the 8 target files; fixes applied
  vs queued; stamp bumps landed if substantive
- [ ] Block E: diary filled; pre-commit sweep clean; Board.md updated
  if substantive; commit + push handled; Tue 19/05 PPT priorities
  sketched

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation done | None |
| Block B | Sim regression result known | **High** if regressed (debugging may rollover to Tue 19/05); **None** if clean |
| Block C | 13/05 audit findings classified | Medium — drives Block D fix scope |
| Block D | Doc sweep done | Low — fixes independent |
| Block E | Day closed; Tue priorities queued | Standard |

---

## Known unknowns to record during the day

- Does any part of the sim stack hardcode-depend on `ROS_DOMAIN_ID=56`?
  (Block B repo-side grep + actual launch test answer this.)
- Did the diary's compressed 13/05 write-up miss any log details worth
  preserving for the presentation deck? (Block C audit.)
- Are there post-13/05 stale doc claims beyond the 13/05 scope?
  (Block D sweep.)
- Tue 19/05 PPT scope — which slides need updates from 13/05 work?
  (End-of-day sketch.)
- Break inputs (supervisor / teammate replies, weather, presentation
  scope confirmation).

---

## Next steps — Mon 18/05 → Wed 20/05 presentation

### Active branch: post-break sim check + log audit + doc sweep + PPT prep kickoff

Today's outcomes drive Tue 19/05's PPT-prep block:

- **If sim stack is clean under default domain**: Tue 19/05 is full PPT
  prep — slides, rehearsal, last-minute fact-check sweep against the
  current `origin/main` state.
- **If sim stack regressed**: Tue 19/05 splits between regression fix
  (morning) and PPT prep (afternoon). Wed 20/05 morning slot is
  immutable — presentation goes ahead either way.
- **If 13/05 audit surfaces architecturally important findings**:
  decide on a case-by-case basis whether to fold into the presentation
  deck (only if directly relevant to the supervisor-facing scope) or
  queue for post-presentation Thu 21/05+.

### Pending (carries past Mon; mostly post-presentation)

- Phase 5 driver bring-up planning — newly unblocked post-Tue 12/05
  B.1 DDS WORKS + Wed 13/05 C.7 RealSense bridge validation; first
  focused session can plan: LiDAR / GPS / IMU driver candidates,
  `mavros2` install path, autostart strategy on Pi, topic-name scheme
  aligned with `launch/remap.launch.yaml`. **Post-presentation slot
  (Thu 21/05+).**
- Phase 5 hardware power-design pass (Roadmap §3 new row) — regulated
  ≥5A 5V supply, bulk capacitance near Pi power input, thick-short
  GPIO leads or proper USB-C input, possibly powered USB hub between
  Pi and RealSense.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 new
  row) — single canonical camera node + RTP republish for Herelink,
  or multi-mux camera-fork daemon at v4l2 layer.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology) — still pending.
- Second-site (lake) Herelink video A/B retest — deferred to next
  field session under known-good QGC `Source = Herelink Hotspot`
  preset.
- VRX §8.2 weekly cadence next check — Mon 25/05 (if today's check
  passes HOLD).

### Possible time-permitting tasks (pick up only if Mon runs short)

- **P1 pier/bank stuck investigation** — diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md`
  Block A. Substantial sim work; naturally pauseable. Requires
  `--use-nvidia` to hold acceptable RTF (~0.32 → ~0.88).
- **Phase 5 driver bring-up planning skeleton** — paper plan only,
  no Pi work today. Captures which drivers go first, install ordering,
  topic-name scheme.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — unblocked once
  supervisor confirms parameter set).
- Roadmap §1.3 Path B (offline tile server with pre-generated MBTiles
  for the test-site area) — required before first IoT-network field
  deployment.
- Dashboard CSP Option B (reverse-proxy header injection) and Option C
  (Caddy / external static webserver).
- 24/04 housekeeping carry-overs (`mono-xsp4` port-8084 disable;
  `tools/qos_scan.py` single-pass QoS inventory companion to
  `rate_probe.py`).
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware
  double-reverse symptom.
- Sim-to-real comparison — N/A until a future field test records
  autonomy bag data.
- External Week 11 diary scaffold creation — Mon evening Windows-side
  task; defer to next Windows session if Linux-only today.
