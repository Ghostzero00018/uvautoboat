# 2026-04-29 — Wednesday: PPT visual placement + rehearsal pass 3 + Wed-evening dry run

## Context

Pre-scaffold written 28/04 evening. Today is the LAST work day before Thursday delivery (30/04 afternoon). All Linux-side debt closed by Tuesday's pushes — 28/04 Block A verification + Part 2 option-1 cleanup sweep + the cold-start `inf` JSON race fix (`6ec20af`) + cosmetic-startup-warnings catalog (`134e52c`) + diary/Board backfill. Wednesday is now PPT-finishing + rehearsal day with no Linux-side debt — visual placement, speaker-note timing, rehearsal pass 3, and the Wed-evening 10-item dry-run is the entire scope.

**Week shape recap (29/04 Wed → 30/04 Thu):**

- **Wednesday (today)** — Visual placement; speaker-note timing pass; rehearsal pass 3 timed end-to-end; Wed-evening 10-item dry-run.
- **Thursday morning (30/04)** — Last-mile fixes from Wed-evening dry-run findings; one final rehearsal pass.
- **Thursday afternoon (30/04)** — Deliver.

**Why Wednesday matters more than it looks:**

Tuesday's verification + cleanup + bonus inf-fix landed everything Linux-side cleanly; Wednesday inherits zero red-debt. But polish at the wrong end of the week IS the delivery — visual placement that doesn't land turns into Thursday-morning fire-fighting; un-rehearsed timing means delivery cadence is unpolished. The Wed-evening 10-item review is the gate before Thursday opens; if it surfaces something hard, Thursday morning has to absorb it, eating the buffer for the actual delivery.

Active blocks for the day:

1. **Block A — Slide content paste carryover check** (~5 min if Windows already absorbed; up to ~1.5 h if not): verify whether yesterday's Block B landed Windows-side; finish slides 1-8 + bilingual speaker notes for slides 2-7 if not.
2. **Block B — PPT visual placement** (~1.5 h): drop screenshots / PPT-drawn diagrams into each slide's placeholder. Maintainer reports assets already in hand; placement is the remaining work.
3. **Block C — Speaker-note timing pass + rehearsal pass 3** (~1.5 h combined): read each slide note aloud timed; full bilingual rehearsal with deck open in front; aim 22-26 min total spoken.
4. **Block D — Optional Linux-side live demo rehearsal** (~5-10 min, conditional): if Block C exposes a live-demo cue still in the deck, drive a single canonical happy-path on `sydney_regatta_DEFAULT`. Part 2 cleanup is dashboard-only and non-functional, regression risk is low — but a 5-minute confirmation pass is cheap.
5. **Block E — Wednesday-evening 10-item review + wrap + diary fill-in** (~30-45 min): final dry-run checklist from `2026-04-30_slide_outline.md`; commit + push diary + Board.

## Block A — Slide content paste carryover check

Yesterday's Block B status on the Linux side is `[To fill]` — maintainer's "PPT assets already captured" closed 28/04 Block C (demo rehearsal) but didn't clarify Block B (slide content paste).

Open `Research_intern_IMT_NE\working_diary\Week8_27_04-01_05.md` (Windows) to see whether the Tuesday entry there documents the slide paste having landed.

**If already done** (Windows-side absorbed the paste): skip the rest of Block A; jump to Block B.

**If not done:**

1. Open `E:\IMT_dossier\DMI_Semester_3\Research_intern_IMT_NE\PPT\PPT_files\30_04_2026_presentatioin\AutoBoat_PPT_Intern_30_04_2026.pptx`.
2. Consume the bucket-restructured content from `assets/2026-04-30_slide_paste_ready.md` per the original 28/04 Block B order (slides 1-8 + bilingual speaker notes for slides 2-7).
3. Allocate up to ~1.5 h. If overrunning, **stop and roll the remaining slides to Thursday morning** — Block B (visual placement) is more time-pressing.

**Outcome.** [To fill]

## Block B — PPT visual placement

Maintainer reports PPT assets already captured per yesterday's "PPT assets already captured" signal. Today is the placement work — drop each captured asset into its placeholder; resize to fill.

Per 28/04 diary L218-222, the visual placeholders by slide:

| Slide | Visual placeholders |
|:-----:|:--------------------|
| 3 | `git_diff_stat_rename_commit.png` + small three-layer thumbnail (drawn in PPT) |
| 4 | Dashboard screenshot grid (camera combobox / Tier A/B/C / toasts / hover) |
| 5 | PID + Kalman block diagram + E-Stop before/after (drawn in PPT) |
| 6 | Health-check + rate_probe terminal + topology diagram + (optional) MP main UI |
| 7 | Demo video / live placeholder |

Order:

1. Open the deck and the `2026-04-30/` assets folder side-by-side.
2. Drop each captured asset into its placeholder; resize to fill.
3. For PPT-drawn diagrams (Slides 3, 5, 6 topology), use the in-app shapes/arrows; do NOT spend Wednesday on Inkscape or external tooling.
4. After each slide, eyeball it at presentation zoom (View → Reading View or F5) — assets must be readable at projection size, not just laptop-zoom legible.
5. Slide 7 demo: if a recorded MP4 exists, embed it; otherwise, leave the placeholder slot for a "live demo" callout and decide live-vs-pre-recorded during Block C rehearsal.

**Pacing target:** ~10 min per slide × 5 slides = ~50 min raw. Buffer for the PPT-drawn diagrams (Slides 3, 5, 6 topology) brings total to ~1.5 h.

**Outcome.** [To fill]

## Block C — Speaker-note timing pass + rehearsal pass 3

Read each slide's bilingual note aloud, timed end-to-end. This is rehearsal pass 3 (passes 1-2 happened over earlier sessions; pass 3 is the timed end-to-end with the visually-complete deck).

### Step 1 — Speaker-note timing pass (~30 min)

- Open the deck in Notes view (View → Notes).
- For each slide, read the EN block aloud (timed). Note overruns in the slide margin.
- Total target: 22-26 min EN-primary spoken delivery. If under 22 min, the deck is too thin; if over 26 min, mark which bullets to cut.
- For slides where the 中文 block reads notably longer/shorter than EN, decide which side leads for the formal delivery.

### Step 2 — Rehearsal pass 3 (~1 h)

- Full end-to-end dry run with deck open in front.
- English-primary for the formal delivery (per the supervisor audience profile); bilingual where natural at transitions.
- Time the WHOLE pass (intro + outro + slide transitions + Q&A buffer). Target ~30 min wall-clock for an audience-facing 22-26 min spoken.
- Mark any slide that breaks the rhythm — asset not loading, note too dense, transition feels forced.

### Failure-mode handling

- **Timed pass runs >30 min total:** cut content from Slides 4-6 (densest); Slide 7 stays at full length.
- **Visuals don't land at projection-size eyeball check:** defer to Thursday morning unless the fix is trivial (resize, reposition).
- **Speaker note feels stilted:** rewrite in-place; do NOT defer note rewrites — the diff is small and the Wednesday-evening dry-run will exercise the rewrite.

**Outcome.** [To fill]

## Block D — Optional Linux-side live demo rehearsal

Conditional. Run this ONLY IF Block C rehearsal exposes a live-demo cue still in the deck (e.g., Slide 7 ends up calling for a live cycle rather than a recorded clip).

**Pre-flight check:**

```bash
cd ~/seal_ws/src/uvautoboat
git status --short
git log --oneline -5
# Tree should be clean; HEAD should reflect Tuesday's pushed commits.
```

**Single canonical happy-path on `sydney_regatta_DEFAULT`:**

1. Launch:

   ```bash
   bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_autoboat_complete.sh
   ```

2. Wait ~30 s for dashboard "connected" + 49 PASS in health check.
3. Generate Waypoints → Confirm → Start.
4. Watch mission run to FINISHED.
5. Sanity grep for new errors using the new filter from `Common_Issues.md` Known-Startup-Warnings section:

   ```bash
   grep -iE 'warn|error|fail|deprecat' /tmp/autoboat_tab_*.log | \
     grep -vE 'kdl_parser|libEGL|gui/follow.*deprecated|vrx::WaveVisual'
   ```

   Empty filtered output = clean run.

If the run completes cleanly and the deck doesn't ask for a live demo, refer Slide 7 to a recorded clip or remove the live slot.

If the run surfaces a regression: STOP. Roll back to the last known-good commit and defer the demo to a recorded clip. Do not try to debug Wednesday afternoon — that path eats Thursday-morning's buffer.

**Outcome.** [To fill]

## Block E — Wednesday-evening 10-item review + wrap + diary fill-in

### 10-item review checklist

The 28/04 "Next steps" line called out four of the items by name; the remaining six live in `2026-04-30_slide_outline.md` (Windows-side) — pull them up at review time.

Known items (from 28/04 diary):

1. **No-ellipsis check** — every "..." in slide bodies is either explicit content or removed.
2. **Visual motif consistency** — colour palette, font sizing, badge styling uniform across slides.
3. **Asks-box highlighting** — Slide 7 "Asks" section is visually distinct from "Demo" and "Future Work".
4. **QR scan test** — phone-test every QR code in the deck (repo URL, dashboard URL, presentation slides URL if any).

Items 5-10: pull from `2026-04-30_slide_outline.md`. If the outline file hasn't been split out yet, draft the missing six items live based on Block C's deck-pass observations and append them here for the post-fact diary fill.

### Wrap

1. `git log --oneline -5` — sanity check the day's commits landed cleanly.
2. Pre-commit scan (sweep for tracked-file blocklist matches) — zero matches expected.
3. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
4. Add 29/04 milestone row to `Board.md` only if Block A + Block B + Block C all land cleanly.
5. On the Windows laptop, append today's section to `Research_intern_IMT_NE/working_diary/Week8_27_04-01_05.md`.
6. Commit:

   ```bash
   git add working_diary/2026-04-29_wednesday_ppt_visuals_and_rehearsal.md Board.md
   git commit -m "docs: fill 29/04 working diary with day's outcomes"
   git push
   ```

**Outcome.** [To fill]

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Slide content paste carryover resolved (or confirmed done from Windows side) | Trivial — paste is the prereq for placement |
| Block B | All visual placeholders filled; deck visually complete | Thursday morning falls back to last-mile asset fixes only |
| Block C | Rehearsal pass 3 timed; speaker notes aligned to 22-26 min target | Thursday opens with one final dry-run pass |
| Block D | Live-demo cue resolved (skipped, recorded, or live-rehearsed) | (no rollover — Block D is a one-shot decision) |
| Block E | 10-item review complete + day closed | Thursday morning is fix-and-deliver only |

## Known unknowns surfaced during the day

Use this section to capture anything surprising during the day — file state drift, unexpected behaviour, asset issues. Each entry: `file:line` or command + observation + fix or follow-up.

## Next steps — concrete plan for 30/04

### Actionable on 30/04 (Thursday morning)

- **Last-mile fixes from Wed-evening review** — fold in any 10-item checklist findings that didn't land Wednesday.
- **One final rehearsal pass** — end-to-end with the projection screen if available; otherwise full-screen on the laptop.
- **Asset double-check** — every screenshot at projection-size legibility; QR codes scan-tested again; speaker notes printed as fallback.
- **Pre-flight Linux-side check** (only if a live demo is part of the delivery) — confirm `sydney_regatta_DEFAULT` boots clean; have the launcher tab ready before walking into the room.
- **Final commit + push** — wrap working diary entry for 30/04 morning; nothing else Linux-side.

### On 30/04 (Thursday afternoon — DELIVERY)

- Deliver the presentation per the rehearsed flow.
- Surface the three open Asks during Slide 7:
  1. **CCU low-level architecture** — confirm whether a separate low-level controller exists between Pi 5 and thrusters; if yes, what chip + firmware (MAVLink autopilot is the working hypothesis).
  2. **Mock water quality sensor** — supervisor sign-off on parameter set + sampling cadence.
  3. **Phase 5 hardware-arrival window** — when the CCU lands at the bench.

### Blocked / deferred (post-Thursday)

- **P1 pier/bank stuck investigation** — diagnostic plan preserved in 24/04 diary's Block A section; pick up after Thursday meeting.
- **Mock water quality sensor implementation** — unblocked once supervisor confirms the parameter set (Asks item 2 above).
- **Real no-regression test for `launch/remap.launch.yaml`** — needs first real-hardware bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** — later integration milestone (post-real-hardware-bringup; Phase 5.2+).
- **24/04 housekeeping carry-overs** — `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Bumped post-Thursday; rainy-day.
- **`update-pip-graph` GitHub Actions Node 20 deprecation** — server-side, auto-resolves June 2026; no action needed.
