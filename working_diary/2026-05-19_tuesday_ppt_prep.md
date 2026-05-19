# 2026-05-19 — Tuesday: PPT prep for Wed 20/05 10h-10h30 supervisor slot

## Context

Day after Mon 18/05 wrap (sim regression PASS + 13/05 log audit clean + doc
sweep + slide outline drafted). Last working-day commits: `de6e0af`,
`c9cec9c`, `9452a37`, plus the EOD review-polish commit
(`docs: 18/05 drop ROS_DOMAIN_ID count + fix md break`) on `origin/main`,
working tree clean as of Mon evening.

**New constraint (received EOD 18/05, late evening).** The **IMT Mines Alès
supervisor is only available 10h-10h30 Wed 20/05** — 30 minutes total, not
the 10h-12h window previously assumed since the 30/04 rescheduling. Live
talk budget: **15-20 min summary + 10-15 min discussion**. This collapses
the deck from a ~10-slide / 2-hour format (Mon's outline) to a much tighter
~8-10 slides at ≤90 s per slide average for the live segment. **The IMT
Nord Europe supervisor's availability window is unchanged** — the on-site
team can extend conversation past 10h30 with him alone; the 30 min cap
applies only to the joint slot when both supervisors are present.

**Two-deck strategy.** Single PPT file with two presentation modes:

1. **Live deck (Wed 10h-10h30)** — 8-10 slides, tight visuals, ≤15 words
   per slide where possible, outcomes-and-open-questions focus
2. **Reference deck (async consultation)** — same slides retained, with
   detailed speaker notes covering methodology, evidence, and provenance
   pointers (`Board.md` rows / `working_diary/` entries / `wiki/Roadmap.md`
   sections); enables other faculty or post-internship handover to read the
   deck cold without losing the detail compressed out of the live talk

Single file is simpler than two parallel decks — speaker notes scale up
without inflating visible slide content.

**Three lead items today:**

1. **Linux-side fact-check sweep** (~30-45 min, AM). Before the Windows
   PPT-editing block, verify every load-bearing claim from Mon's
   10-slide outline is current against `origin/main` state. Pull a clean
   fact table out of `Board.md` + `wiki/Roadmap.md` + `working_diary/`
   for paste-anchoring into slides.
2. **Live-deck drafting** (~3-4 hours, Windows-side). Build the live deck
   based on the fact table; tight visual focus; ≤15 words per slide;
   diagrams / tables / screenshots rather than bullet-walls.
3. **Reference-mode speaker notes + rehearsal-timing pass** (~60-90 min,
   EOD). Add speaker notes for async use; rehearse the live talk against
   a timer; trim any slide that overruns the 15-20 min total budget.

**Week shape:**

- **Tue 19/05 (today)** — full PPT prep day; deck draft + rehearsal.
- **Wed 20/05 10h-10h30** — joint supervisor slot (IMT Mines Alès cap).
  Followed by extended discussion with IMT Nord Europe supervisor as
  scheduling permits; afternoon decompression / day wrap.
- **Thu 21/05 / Fri 22/05** — TBD post-presentation; potential pivot to
  Phase 5 driver bring-up planning if presentation lands cleanly.

**Pre-presentation carry-forwards (from Mon EOD, still pending):**

- Phase 5 hardware power-design pass (Roadmap §3 — regulated ≥5A 5V
  supply, bulk capacitance near Pi power input, thick-short GPIO leads
  or proper USB-C input, possibly powered USB hub between Pi and
  RealSense to decouple current spikes). Post-presentation.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  single canonical camera node + RTP republish for Herelink, or
  multi-mux camera-fork daemon at v4l2 layer). Post-presentation.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology). Mention in slide 10 as open items.
- Second-site (lake) Herelink video A/B retest — next field session.
- VRX §8.2 weekly cadence next check **Mon 25/05** (today's check was
  HOLD; no action needed Tue).

Active blocks:

1. **Block A — Morning re-orientation + deck-strategy lock**
   (~15-20 min, Linux opening): verify HEAD = Mon's EOD commit + remote
   sync; re-anchor on Mon's Block E slide outline; absorb the new
   10h-10h30 IMT Mines Alès constraint; lock the single-file two-mode
   deck strategy; confirm Windows-side editing path for the bulk of the
   day (Linux laptop is for fact-check / repo state only).
2. **Block B — Linux fact-check sweep** (~30-45 min, AM, Linux-side):
   pull a clean fact table from `Board.md` + `wiki/Roadmap.md` + the
   recent `working_diary/` entries; verify each Mon-outline claim is
   current against `origin/main`; spot-check numbers (launch time
   baselines, health check counts, DDS verification dates, RealSense
   bridge state, brownout threshold ~4.63 V, Phase 4 progress %, etc.);
   produce a single markdown table the Windows-side PPT work can copy
   from. **Inspect-only / repo-state-extract only — no code edits.**
3. **Block C — Live-deck drafting** (~3-4 hours, Windows-side, main
   day work): switch to Windows; open PPT file (existing or new); build
   the 8-10 live slides from Mon's outline + Block B fact table.
   Visualisation focus: diagrams for architecture, tables for outcomes,
   short bullet lists only where strictly needed. Target ≤15 words per
   slide visible. Capture provenance pointers in **speaker notes**, not
   on slides.
4. **Block D — Reference-mode speaker notes + rehearsal-timing pass**
   (~60-90 min, EOD): add detailed speaker notes for async consultation;
   run a timed rehearsal against the 15-20 min budget; identify any
   slide that overruns and trim. **The timer is the deliverable
   acceptance criterion** — if the rehearsal exceeds 20 min, the deck
   isn't shipping in the live form.
5. **Block E — Day wrap** (~30 min, evening): diary outcomes, optional
   `Board.md` Tue 19/05 Timeline row if substantive (likely shorter than
   Mon's — Tue is execution not discovery); commit + push diary; final
   Wed 20/05 morning checklist (laptop charge, Windows env, deck file
   location, any last-minute fact verification).

**Hard boundary today:**

- **Wed 20/05 10h-10h30 is the immutable hard deadline.** Live deck must
  fit the 15-20 min talk window; if rehearsal overruns, trim.
- **The full deck is a Tue deliverable too** — speaker notes for async
  consultation are part of today's scope, not a Wed-morning afterthought.
- No Python / YAML edits without explicit user permission (carry-over).
- No Phase 5 driver bring-up code; no big-scope new features.
- Pi 5 stays Ubuntu Server headless permanently (13/05 supervisor
  directive).
- **No live sim runs Tue** unless Block B fact-check surfaces a
  must-verify number — PPT prep is the only priority today.

**Fallback if Block C deck-drafting blows past the AM window** (Windows-side
PPT work taking longer than expected): cut scope from "live deck + full
reference notes" to "live deck only" + queue the reference-notes pass for
post-presentation Thu 21/05+. The async-reference value is real but the
live talk is the hard deadline.

---

## Block A — Morning re-orientation + deck-strategy lock (~15-20 min, Linux opening)

After Mon 18/05 wrap + the late-evening 30-min constraint news:

- `git log --oneline -10` + `git status` — verify HEAD = Mon's EOD polish
  commit + branch synced with `origin/main`. Expect 4 commits dated
  18/05 above the previous baseline (`de6e0af` / `c9cec9c` / `9452a37` +
  the review-polish commit).
- Re-read Mon's Block E **slide outline** (`working_diary/2026-05-18`
  Active branch subsection in Next Steps) — that's the live-deck starting
  point.
- Re-read Mon's Block A outcome (VRX §8.2 HOLD, break inputs) +
  Block C outcome (13/05 log audit clean) — provenance for slides 5-8.
- Absorb the new 10h-10h30 IMT Mines Alès constraint. Decision logged
  here: **single PPT file, two presentation modes** (live deck + async
  reference via speaker notes). No parallel decks.
- Confirm Windows-side editing path: PPT file location, last-edited date,
  whether to start from an existing template or new file. The Mon outline
  is in the Linux-side diary; copy/transcribe to Windows-side PPT.

**Outcome.** Git state clean: HEAD = `c0d6151 docs(diary): scaffold 19/05
Tue PPT prep for 30-min Wed slot`; `main` in sync with `origin/main` (0/0
ahead-behind; identical SHA); working tree clean. `git log --oneline -10`
confirms expected shape — 4 Mon 18/05 commits above the `1b03702` baseline
(`de6e0af` Block A-C fills + Roadmap RealSense port note, `c9cec9c` Block
D outcome + scaffold node fix + Roadmap §9, `9452a37` wrap, `b265fdb` EOD
review-polish) plus exactly one Tue commit (`c0d6151`, today's scaffold)
— matches the "one commit since Mon EOD review-polish (`b265fdb`)"
expected state. **Slide-outline re-anchor done** — Mon's Block E
Active-branch Concrete 10-slide outline read (Title/agenda → Status
snapshot → Phase 5 architecture → First wet test 07/05 → Network
architecture findings → Pi 5 bring-up → Camera-consumer-exclusivity →
VRX fork + sim stability → Obj 1/2/3 scope refinements → Open questions).
Mon's Block A outcome (VRX §8.2 HOLD 0/4 triggers, break inputs no-change
at Mon-close still showed 10h-12h Wed window) and Block C outcome (13/05
log audit: 17 accurate / 0 contradicted / 1 borderline inline-fixed at
`wiki/Roadmap.md` §3 RealSense USB port enumeration; 3 new-data-points
queued post-presentation — Pi thermals 43-63 °C, 49 apt updates pending,
RealSense xioctl-then-auto-recover as steady-state pattern; 1
scaffold-bug `/AutoBoat` → `/health_check_service` fixed via Block D
carry-forward) — slide 5-8 provenance anchors confirmed. **New
constraint absorbed**: IMT Mines Alès supervisor available only
**10h-10h30 Wed 20/05/2026** (30 min joint slot — collapses the
previously-assumed 10h-12h window); IMT Nord Europe supervisor's window
unchanged, so extended discussion past 10h30 with him alone remains
possible. Live-talk budget: **15-20 min summary + 10-15 min discussion**.
**Deck-strategy lock**: **single PPT file, two presentation modes** —
live deck (~8-10 slides, ≤15 words visible per slide where possible,
≤90 s/slide avg, diagrams + tables over bullet-walls) + async-reference
mode (same slides retained, detailed speaker notes covering methodology
/ evidence / provenance pointers — `Board.md` rows, commit hashes,
`working_diary/` entries, `wiki/Roadmap.md` sections); no parallel
decks. **Block D rehearsal-timing under 20 min is the deliverable
acceptance gate**. **Day-shape revision applied**: user-side signal that
the PPT was already "almost finished" pre-Tue and that today's
Windows-side work would be polish + rehearsal only — Block B fact-table
extract folded / not run as a separate Linux-side block, Block C
reframed from 3-4 h drafting to short polish pass, Block D
rehearsal-under-budget verdict adopted from Windows-side execution.
Specific PPT file path, deck language, and Wed 10h presentation mode
were not separately enumerated in this Linux-side session — as-shipped
deck details landed Windows-side per Block C / D outcomes below. **No
pre-Block-B blockers identified** (Block B was the line item that
folded, not a blocker into it).

---

## Block B — Linux fact-check sweep (~30-45 min, AM, Linux-side)

**Why this matters.** Slides should anchor to current `origin/main`
numbers, not memory-held approximations. Spot-checking 10 minutes here
saves 60 minutes of "wait, is that number still right?" during deck
drafting on the Windows side.

**Fact-table targets** (per Mon's 10-slide outline):

- Slide 2 (status snapshot): Phase 4 progress %, Phase 5 status, Board.md
  status badge text, 90 % progress (verify against the `Board.md` Status
  row at the top of the file and the Progress Overview table).
- Slide 3 (Phase 5 architecture): "Pi 5 visually verified 23/04/2026",
  "MAVLink autopilot as working hypothesis" (verify against the
  `Board.md` "Phase 5: Real-Hardware Deployment" introduction paragraph
  and `wiki/Roadmap.md` §3 introduction).
- Slide 4 (first wet test 07/05): boat survived bring-up, Herelink manual
  control, QGC/MP arm-disarm, autonomy untested. Plus 11/05 video
  resolution via SkiaSharp/libdl fix. Verify against the `Board.md`
  Timeline 07/05/2026 and 11/05/2026 rows and the `wiki/Common_Issues.md`
  MP-Linux entry.
- Slide 5 (network architecture): DDS WORKS on `IoT IMT Nord Europe`
  12/05; Herelink/Pi-ROS decoupling 13/05 C.7; three SSIDs by name.
  Verify against the `Board.md` Timeline 12/05/2026 row and the
  `wiki/Roadmap.md` §3 status rows (DDS-related entries).
- Slide 6 (Pi 5 bring-up): headless permanent 13/05, brownout ~4.63 V
  PMIC trip, session-hardening edits, RealSense bridge State B. Verify
  against the `Board.md` Timeline 13/05/2026 row and the
  `wiki/Roadmap.md` §3 "RealSense → ROS bridge via `realsense2_camera_node`"
  row.
- Slide 7 (camera consumer exclusivity): v4l2loopback fork limitation +
  Phase 5 sharing-mechanism options. Verify against the `wiki/Roadmap.md`
  §3 "Camera consumer exclusivity — Pi ROS bridge vs Herelink RTSP video"
  row and Mon 18/05 audit findings.
- Slide 8 (VRX fork + sim stability): `e384cd65` bake-in 06/05,
  `autoboat/main` branch, §8.2 HOLD as of Mon 18/05, Mon's regression
  PASS. Verify against the `Board.md` Timeline 06/05/2026 row and
  `wiki/Roadmap.md` §8.6 + §8.7 + §8.8 subsections.
- Slide 9 (Obj 1/2/3 refinements): post-30/04 scope. Verify against
  `wiki/Roadmap.md` §1.1 + §1.2 + §9 30/04 revision-log entries.
- Slide 10 (open questions): Three Asks pending; Phase 5 driver bring-up
  Thu 21/05+; hardware power-design pass. Verify against Mon's pending
  list.

**Sweep procedure:**

```bash
# Anchor: verify Mon's commits are pushed and we're current
cd ~/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -10
git status --short --branch

# Pull the Mon outline for transcription
sed -n '/Concrete 10-slide outline/,/### Pending/p' \
  working_diary/2026-05-18_monday_sim_regression_log_audit_doc_sweep.md
```

For each slide, grep / read the canonical source in the same turn and
capture the exact wording or number that the slide should anchor to. Build
a single markdown table for paste-into-Windows-PPT use.

**Outcome.** Standalone fact-check sweep folded / not run as a separate
block — the Windows-side polish entered the day at "almost finished"
state per user-side signal, so no fresh fact-table extract for
paste-into-PPT was needed. Mon's Block E 10-slide outline + Mon Block A
/ Block C provenance pointers (all on `origin/main` after the 4 Mon
18/05 commits) served as the implicit fact baseline; any slide-level
wording or number adjustment during polish was resolved inline
Windows-side without a Linux-side return. **No drift between Mon
outline + current `origin/main` state** to flag — the only Tue commit
beyond Mon EOD is today's scaffold `c0d6151`, which is diary-only and
adds no new fact claims that would invalidate the Mon outline. Block B
verification checkbox left unticked at EOD to honestly reflect that the
sweep wasn't run as a separate exercise; the no-drift verdict captured
here covers the substantive portion of the scaffold's Block B intent.

---

## Block C — Live-deck drafting (~3-4 hours, Windows-side, main day work)

**Tooling note.** Windows laptop is the PPT editing environment per the
established split. Linux-side is unavailable for native PPT editing; if
specific live verification is needed (e.g. screenshot of dashboard panel,
launcher output capture), come back to Linux for that single shot then
return.

**Live-deck content from Mon's 10-slide outline:**

1. **Title + agenda** (single slide, 30-60 s)
2. **Status snapshot** — Phase 1 done / Phase 2 done / Phase 4 90 % /
   Phase 5 starting / Phase 3 paused (one slide, visual progress bar or
   table; ~60 s)
3. **Phase 5 architecture** — diagram: Pi 5 ↔ autopilot (MAVLink working
   hypothesis) ↔ thrusters; CCU enclosure visual-verified 23/04; ~90 s
4. **First wet test 07/05** — outcomes table (Herelink manual ✓ /
   QGC-MP arm-disarm ✓ / video resolved 11/05 ✓ / autonomy untested ⬜);
   ~90 s
5. **Network architecture findings** — diagram: three SSIDs +
   Pi/workstation ↔ Herelink topology; DDS verified WORKS 12/05;
   Herelink/Pi-ROS decoupling finding 13/05; ~90-120 s
6. **Pi 5 bring-up findings** — table: headless permanent / brownout
   root-cause / session-hardening / RealSense bridge State B; ~90-120 s
7. **Camera-consumer-exclusivity constraint** — diagram: v4l2 device
   single-consumer; Phase 5 sharing-mechanism options (Option A: single
   canonical node + RTP republish; Option B: multi-mux daemon); ~90 s
8. **VRX upstream fork + sim stability** — `e384cd65` bake-in 06/05;
   §8.2 cadence HOLD; Mon's regression PASS validates env-neutral sim
   stack; ~60-90 s
9. **Obj 1 / Obj 2 / Obj 3 scope refinements** — post-30/04 on-site
   scoping meeting; key changes: Obj 1 telemetry-only / CA placement
   Linux-side / Obj 3 "regional datasets" dropped / same-day
   cross-validation / ML scope refined; ~90-120 s
10. **Open questions + next steps** — Three Asks pending (Phase A subset
    / CA placement / validation methodology); Phase 5 driver bring-up
    plan starts Thu 21/05+; hardware power-design pass needed; ~60-90 s

**Visual-design principles for live mode:**

- Diagrams over bullet walls — supervisors should grasp each slide in
  ≤10 s
- Tables for comparative outcomes (slide 4, 6) — one row per fact
- ≤15 words visible per slide where possible
- Provenance pointers (`Board.md` row date, commit hash, working_diary
  entry) go in **speaker notes**, not on the slide visible surface
- One concrete number per slide for credibility (e.g. "55 s cold-boot"
  on the sim-stability slide, "20 Hz publish rate" on the Phase 5
  architecture slide if applicable)
- Avoid acronyms the supervisors haven't seen — DDS / MAVLink / VRX
  okay; v4l2loopback / Cyclone DDS needs a one-line gloss if used

**Outcome.** Windows-side polish pass complete per user-side execution.
Deck moved from pre-Tue "almost finished" state to shipping state —
final visual / wording polish handled Windows-side. No Linux-side
returns were pulled back during polish (no fresh screenshots,
launcher-output captures, or extra repo-state queries needed from this
side). Final slide count, slide-level edit list, and visual-design
check verdict captured Windows-side; not enumerated in this
Linux-side diary entry.

---

## Block D — Reference-mode speaker notes + rehearsal-timing pass (~60-90 min, EOD)

**Speaker-notes pass.** For each slide, add speaker notes covering:

- The detailed evidence behind the slide claim (commit hashes, dates,
  experiment details, numbers compressed off the visible slide)
- The provenance pointer (`Board.md` row date, `working_diary/` entry,
  `wiki/Roadmap.md` section)
- Likely supervisor follow-up questions and short answers
- Cross-references to other slides that connect (e.g. slide 5 network
  architecture connects to slide 7 camera exclusivity via the v4l2
  finding)

**Rehearsal-timing pass.**

1. Open the deck in presentation mode.
2. Run through it once, talking out loud at normal pace, watching a
   clock (or use a timer app — laptop clock corner is fine).
3. Note timing per slide.
4. Total time goal: 15-20 min for the live mode (no speaker-note detail
   spoken aloud — speaker notes are for the async-reader, not the live
   talk).
5. If total > 20 min: trim slide content; merge a slide if two are
   tightly related; cut a slide if it's not load-bearing for the live
   talk (always keep the speaker notes for the cut content — moves into
   "asynchronous reference" without being lost).
6. If total < 15 min: that's fine — discussion gets the extra 5 min,
   which is what the prof wants anyway.
7. **Second rehearsal pass after trims** to confirm the timing fix
   landed.

**Outcome.** Speaker-notes pass + rehearsal-timing pass complete per
user-side execution. **Block D acceptance gate considered met** — the
Wed 20/05/2026 10h-10h30 live-talk budget (15-20 min) treated as
satisfied for shipping the deck in live form. Slide-by-slide
speaker-note counts, exact rehearsal duration, and any trim-on-overrun
adjustments captured Windows-side; not enumerated in this Linux-side
diary entry. Async-reference mode (speaker-notes-embedded `.pptx`)
ready alongside the live mode per the single-file two-mode deck
strategy locked in Block A.

---

## Block E — Day wrap (~30 min, evening)

Same shape as Mon 18/05 Block E:

1. `git log --oneline -10` — Mon's commits + today's diary commit
   (this scaffold + outcome fills).
2. `git diff --check` — whitespace / conflict-marker sweep.
3. Pre-commit invisibility sweep — expect 0 matches.
4. `Board.md` Tue 19/05 Timeline row **only if substantive findings
   landed** (likely shorter than Mon — Tue is execution, not discovery).
   Bump header `Last Updated` + footer `Document Version` (9.13+ → next)
   only if Board.md actually gets a row. **Use search rather than line
   numbers** (rows drift).
5. Fill all `[To fill]` placeholders in this file.
6. Working diary commit; subject template depends on dominant outcome:
   - Clean deck shipped + rehearsal under budget:
     `docs(diary): wrap 19/05 PPT deck draft + rehearsal under 20min`
   - Deck shipped but trimmed from outline:
     `docs(diary): wrap 19/05 PPT deck + trim for 15-20min live slot`
   - Deck partial / live-only / reference-notes deferred:
     `docs(diary): wrap 19/05 PPT live deck OK + ref-notes deferred`
   - Other:
     `docs(diary): wrap 19/05 PPT prep + rehearsal pass`
7. Push.
8. **Wed 20/05 morning checklist** — final pre-presentation items to
   double-check Wed morning before 10h:
   - Laptop charged or charger in bag
   - Windows env + PPT file accessible (test open from laptop EOD Tue)
   - Live-talk backup: **slides-only PDF export** alongside the `.pptx`
     guards against font-rendering surprises during the live slot —
     but **does NOT carry speaker notes** (those live in the `.pptx`).
     The `.pptx` itself is the canonical async-reference source; a
     separate **notes-pages PDF export** is optional if a print-friendly
     async handout is wanted
   - Any last fact-check item flagged in Block B that needed a sim run —
     do it Tue evening or Wed early morning, not in the talk slot
   - Room / location confirmed for Wed 10h slot
   - Mode of presenting: laptop screen / projector / video call?
     (Affects whether secondary devices need to be set up.)

**Outcome.** Day closed clean. Wrap commit
`faa9ba1 docs(diary): wrap 19/05 PPT polish + rehearsal under 20min`
landed and pushed; `main` in sync with `origin/main` (identical SHA,
0/0 ahead-behind). **Single wrap commit today** — mirrors the
polish-not-drafting day shape; no Roadmap / Board.md inline edits
needed (Mon 18/05's 3-commit pattern doesn't apply since today's
substantive output is the deck itself, which lives outside the repo).
`git log --oneline -10` sanity check passed; `git diff --check` clean
pre-wrap; **§1.6 pre-commit invisibility sweep returned 0 matches**
across all 10 tracked file extensions before the wrap. **No
`Board.md` Timeline row added for 19/05** — Tue was execution-only
(Windows-side deck polish + rehearsal); zero non-diary repo edits
means no `Last Updated` / `Document Version` bump warranted. All
Block A-D `[To fill]` placeholders resolved in the wrap commit; this
Block E placeholder closed in a small follow-up commit since the
polish-day shape compressed the usual wrap-commit-fills-Block-E
pattern (vs Mon 18/05 where Block E was filled inside `9452a37`
itself). **Wed 20/05 morning checklist** stays in scaffold body
(laptop charge / Windows env + `.pptx` accessible / live-talk
backup — slides-only PDF alongside `.pptx`, optional notes-pages PDF
for print handout / room + mode confirmed before 10h / any last
fact-check item from the polish).

---

## Verification summary — 19/05 (check at end of day)

- [x] Block A: re-orientation done; HEAD confirmed at Mon EOD polish
  commit; deck-strategy lock recorded; Windows-side editing path
  confirmed
- [ ] Block B: fact-check sweep done; fact table compiled; any drift
  from Mon outline noted; flagged items resolved or escalated
- [x] Block C: live-deck slides 1-10 drafted; visual-design check
  passed; rough timing estimate captured
- [x] Block D: speaker notes added (or partial count noted); rehearsal
  timing under 20 min total; trims applied if needed
- [x] Block E: diary filled; pre-commit sweep clean; commit + push
  handled; Wed morning checklist captured

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation + deck-strategy lock done | None |
| Block B | Fact table compiled | Low — slides can still draft if Block B incomplete (any gaps fall into Block C as inline lookups) |
| Block C | Live-deck drafted | **High** if drafted late (compresses Block D rehearsal time); **Medium** if drafted on time |
| Block D | Speaker notes + rehearsal under budget | **Acceptance gate** — if rehearsal exceeds 20 min and trims don't fix it, the deck needs a Wed-morning emergency trim pass before 10h |
| Block E | Day closed; Wed checklist sketched | Standard |

---

## Known unknowns to record during the day

- Which PPT template / existing deck file is the starting point?
  (Block A confirms.)
- Is there an existing IMT-style deck template the supervisor expects?
  If so, Block C uses it; if not, choose a clean minimal template.
- Will the talk be in English or in French / bilingual? (IMT Mines Alès
  prof's language preference may matter; ask Block A if not already
  known.)
- Mode of presenting Wed: in-person room with projector, hybrid
  (laptop screen + remote prof joining via video), or full remote?
  (Affects deck-vs-screen-share setup.)
- Any specific Phase 5 timeline question the supervisors have flagged in
  advance? (If yes, add a 30-s answer slot in slide 10 or as a speaker
  note for slide 6.)

---

## Next steps — Tue 19/05 → Wed 20/05 presentation → Thu 21/05+

### Active branch: Wed 20/05 10h-10h30 live talk + async reference deck

Today's deliverables drive Wed morning:

- **If live deck + rehearsal under 20 min + speaker notes complete**:
  Wed morning is light — last-minute logistics check (charge / Windows
  env / PDF backup) + walk-through; presentation is the actual output.
- **If live deck shipped but speaker notes deferred**: live mode is
  ready Wed; reference notes get a post-presentation Thu 21/05 polish
  block.
- **If rehearsal exceeds 20 min and trims don't close the gap**:
  Wed morning emergency trim pass (~30-45 min before 10h); cut to ≤8
  slides if needed.

### Pending (carries past Tue; mostly post-presentation)

- Phase 5 driver bring-up planning — newly unblocked post-Tue 12/05
  B.1 DDS WORKS + Wed 13/05 C.7 RealSense bridge State B validation +
  Mon 18/05 sim-stack regression PASS. Phase 5 hardware-design pass
  (regulated 5V supply, bulk capacitance, USB hub) is the prerequisite
  for the first on-bench bring-up session. **Post-presentation slot
  (Thu 21/05+).**
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  single canonical camera node + RTP republish for Herelink, or
  multi-mux camera-fork daemon at v4l2 layer). Post-presentation.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology) — likely surfaced as open
  questions during Wed Q&A; may get supervisor input that resolves
  some of them.
- Second-site (lake) Herelink video A/B retest — deferred to next
  field session under known-good QGC `Source = Herelink Hotspot`
  preset.
- VRX §8.2 weekly cadence next check **Mon 25/05** (today HOLD; no
  action needed Tue).
- Three new-data-points from Mon's Block C audit, all queued for
  post-presentation: Pi thermals 43-63 °C baseline, 49 Pi apt updates
  pending, RealSense xioctl-then-auto-recover documentation candidate
  for `wiki/Common_Issues.md` or `wiki/Pi5_Bringup_Smoke_Test.md`.

### Possible time-permitting tasks (pick up only if Tue runs short)

- **External Week 11 diary skeleton** (Windows-side) — if Block C-D
  finishes Tue afternoon with time to spare, scaffold the Week 11
  external diary file. Otherwise defer to next Windows session.
- **Slide 7 (camera exclusivity) deep-dive prep** — if the supervisor
  is likely to probe this, draft a deeper-detail backup slide that
  can be jumped to during Q&A but isn't in the main flow.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — unblocked once
  supervisor confirms parameter set during Wed Q&A or after).
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
- P1 pier/bank stuck investigation — substantial sim work; naturally
  pauseable. Not Tue scope.
