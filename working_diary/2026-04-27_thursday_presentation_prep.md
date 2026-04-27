# 2026-04-27 — Thursday 30/04 presentation + group meeting prep (Monday)

## Context

Scaffold written evening of 24/04. Original plan (P1 pier/bank stuck investigation) is **deferred until after Thursday's meeting** — the week shifts to preparing the 30/04 presentation + group meeting. Pier/bank diagnostic plan is preserved in 24/04 diary's Block A scaffold (lines 21–70); resurrect from there when we next pick up the topic.

**Week shape (27/04 Mon → 30/04 Thu):**

- Monday (today) — compile "what's new since the last checkpoint (15/04)", start demo rehearsal, capture visuals. Linux-side content-and-evidence work.
- Tue/Wed — PPT update on the Windows laptop (slides + speaker script live in `E:\IMT_dossier\DMI_Semester_3\Research_intern_IMT_NE\PPT\`); further rehearsal cycles.
- Thu morning — final dry run; last-mile fixes.
- Thu afternoon — deliver.

Today's Linux-side focus is **content + evidence**, not slide-making. Three active blocks plus wrap:

1. **Block A — Changelog compile** (~1 h): extract since-15/04 milestones into a focused "what's new" list, structured enough to drop into PPT slides.
2. **Block B — Demo rehearsal** (~1.5 h): run the canonical happy-path mission end-to-end; confirm nothing regressed since the 15/04 demo; shortlist 1–3 new features worth showing live.
3. **Block C — Visual capture** (~45 min): screenshots + short screen recordings of demo-worthy items. Captured Linux-side and copied straight into the Windows-side PPT assets folder — no asset directory tracked in this repo (PPT artefacts stay Windows-side).

Plus Block D wrap + diary fill-in at end of day.

## Block A — Changelog compile (since 15/04)

Goal: a prose-ready "what's new since the last checkpoint" paragraph + bullet list, themed for slide consumption rather than chronological.

Raw material:

```bash
cd ~/seal_ws/src/uvautoboat
git log --oneline --since=2026-04-15 | wc -l        # sanity: expect ~40–60 commits
git log --pretty='%h %ad %s' --date=short --since=2026-04-15 > /tmp/changelog-since-apr15.txt
less /tmp/changelog-since-apr15.txt
```

Themed grouping proposal (refine as we read the log + `Board.md` timeline):

- **Module rename (16/04)** — OKO / SPUTNIK / BURAN → `lidar_perception` / `waypoint_planner` / `heading_controller`; **30 files, +1,099 / −1,398 lines** (line changes — actual identifier sites grep-counted at ~609; "1,100 refs" was an estimate, replaced after `git diff --stat` verification on 27/04). Behavioural no-op but affects every topic + dashboard reference.
- **Perception hardening (17/04)** — param-ranges sync, smoke-detection removed, JSON-parse hardening.
- **Target-aware VFH + Go Home progress (19/04)** — VFH responds to `/control/heading_error`; Go Home distance-based progress; Tier-A/B/C dashboard UX sprint.
- **Dead-code audit + drift compensation + readiness polls (20/04)** — Tier 1 safe deletes; `max_speed` cap wired; Kalman drift compensation activated (gated update + feed-forward thrust); launcher `wait_for_*` polls replacing fixed sleeps; Tier 2 close-out (latched `/planning/emergency_stop`, `std_srvs/Trigger` services).
- **4-state health check + Roadmap (21/04)** — `PASS / TUNED / WARN / FAIL`; new `wiki/Roadmap.md` consolidates Phase 5 + research extensions + Phase A consulting scope; three-layer phase mental model adopted after formal internship-objectives doc.
- **C1/C2/C3 bug fixes + I6 docstring + remap draft (22/04)** — JSON-parse helper propagated; `force_turn_after_reverse` latch now persists; 3-node docstring refresh; `launch/remap.launch.yaml` deployed with 6 `topic_tools/relay` nodes gated on `use_real_hardware:=false`.
- **Dashboard consolidation + camera hardening + supervisor walk-through (23/04)** — unified `debounceGroup` helper (–26 LOC net); camera same-topic Refresh no-op eliminates a `web_video_server` deadlock vector; topic combobox with `/rosapi/topics_for_type` auto-discovery. Prof walked through the real CCU hardware (Pi 5 physically verified; MP/QGC as prof-preferred toolchain; MAVLink-autopilot-in-loop working hypothesis).
- **MP + QGC install + rate_probe + UX pass 2 (24/04)** — prof-requested toolchain installed on Linux workstation (GDAL/OGR/OSR degraded under Mono, Windows `.msi` fallback held); `tools/rate_probe.py` with new `wiki/Common_Issues.md` QoS-aware-probing subsection; S1 Reset-during-Confirm + S2 Go-Home-at-home toasts with planner-side at-home guard.

**Outcome.** [To fill — which items made the deck, which got parked, approx slide count added since 15/04, themes that emerged while reading the raw log.]

## Block B — Demo rehearsal

Run the canonical end-to-end demo (mirror the 15/04 structure from `PPT/assets/presentation_script.md` on the Windows side; the demo script itself lives there). Verify on `sydney_regatta_DEFAULT`:

- Launcher cold start completes cleanly (~20–40 s on this host).
- Dashboard connects, state updates flow, log panel populates.
- Generate Waypoints → Confirm → Start cycle works; boat navigates without regression.
- Emergency Stop latches correctly; Resume recovers; Reset clears cleanly when not in `WAITING_CONFIRM`.
- Spot-check the new-since-last-demo features for demo-worthiness:
  - Camera combobox (auto-discovery dropdown)
  - Unified debounce cooldown visual on mission-control buttons
  - Reset-blocked toast during Confirm window
  - Go-Home-at-home toast at spawn
  - `TUNED` state chip in health check after a preset-apply
  - rate_probe.py side-by-side with `ros2 topic hz` (best for a technical-story slide, less for a live demo)

**Outcome.** [To fill — any regressions surfaced, shortlist of 1–3 demo-worthy features, estimated live-demo minutes for Thursday timing.]

## Block C — Visual capture

Lightweight. Screenshots + short MP4s for Block B's shortlist. Files land directly in the Windows-side PPT assets folder (the maintainer's existing PPT working directory) — no asset directory in this repo. Transfer mechanism (USB / cloud sync / shared folder) is the maintainer's call.

PNGs default; MP4s only where motion carries the story. Keep filenames self-descriptive (`dashboard_camera_combobox.png`, `health_check_tuned_state.png`, `go_home_at_home_toast.png`, etc.) so the Windows side doesn't have to interpret.

Candidate captures (final list depends on Block B):

- Dashboard main view post-23/04 consolidation — debounced buttons, camera combobox, live map.
- Health-check panel in both IDLE (49 PASS) and ACTIVE-with-preset (PASS + TUNED) states.
- `rate_probe.py --reliability reliable --duration 20 --topic /perception/obstacle_info` output next to `ros2 topic hz` output (terminal screenshot).
- Reset-during-Confirm toast + Go-Home-at-home toast.
- `Board.md` timeline since 15/04, rendered in the GitHub web view — useful as a "scope" slide.

Real-hardware photos (Pi 5 in the CCU enclosure, real WAM-V running the stack on water, dashboard against a remote Pi 5) are deferred until hardware testing begins — added to the asset list as Phase-5.1+ progresses, not blocking the 30/04 deck.

**Outcome.** [To fill — list of captured assets, any that turned out not useful once reviewed.]

## Block D — Wrap + diary fill-in

1. `git log --oneline -5` — sanity check the day's commits landed cleanly.
2. Pre-commit scan one more time — expected: zero matches.
3. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
4. Add 27/04 milestone row to `Board.md` only if the changelog compile + visual-capture output rises to the level of a tracked artefact (likely: one low-ceremony row noting "Thursday-meeting prep: changelog + demo rehearsal + N visual assets").
5. On the Windows laptop, create + seed `Research_intern_IMT_NE/working_diary/Week8_27_04-01_05.md` (Week 8 opens today).
6. Commit diary (and Board if updated):

   ```bash
   git add working_diary/2026-04-27_thursday_presentation_prep.md Board.md
   git commit -m "docs: fill 27/04 working diary with day's outcomes"
   git push
   ```

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Changelog compiled, themes identified | Tue picks up demo rehearsal + visual capture |
| Block B | Demo rehearsed, regressions ID'd, live-demo shortlist fixed | Tue starts visual capture |
| Block C | Visual assets captured + transferred to the Windows-side PPT folder | Tue opens directly on PPT slide updates (Windows) |
| Block D | Day closed | Tue opens fresh on PPT work |

## Known unknowns surfaced during the day

Use this section to capture anything surprising during the day — file state drift, unexpected behaviour, migration caveats. Each entry: file:line or command + observation + fix or follow-up.

- [To fill]

## Next steps — concrete plan for 28/04

[To fill at end of day.]

### Actionable on 28/04 (Tuesday)

- **PPT updates on Windows laptop** — consume today's changelog + visual assets into slides. Speaker-script additions mirror slide content (bilingual EN + 中文 per convention).
- **Carry-over from 27/04:** whichever of Blocks A / B / C didn't land or needs follow-up.
- **Rehearsal pass 2** — timed, with the updated deck, on Tuesday evening.

### Blocked / deferred (not this week)

- **P1 pier/bank stuck investigation** — deferred until after Thursday meeting; diagnostic plan preserved in 24/04 diary's Block A section.
- **Phase A implementation (mock water quality sensor)** — blocked on supervisor conversation.
- **Real no-regression test for `launch/remap.launch.yaml`** — Phase 5.1 bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** — Phase 5.2+ scope.
- **Housekeeping follow-ups from 24/04 Known-unknowns** — mono-xsp4 port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Both bumped out of this week; rainy-day items for post-Thursday.
