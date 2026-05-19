# 2026-05-20 — Wednesday: 10h-10h30 joint supervisor presentation + post-talk debrief

## Context

Day after Tue 19/05 PPT polish + rehearsal-under-budget close (`faa9ba1`
wrap + `3cd8861` Block E follow-up). Final HEAD state on `origin/main`
end-of-Tue: `3cd8861 docs: 19/05 Block E outcome + close verification`,
working tree clean. **Single PPT file, two presentation modes** — live
deck (~8-10 slides, ≤15 words visible/slide where possible) +
async-reference mode (speaker-notes-embedded `.pptx`) — both shipped Tue
Windows-side per Block C/D, with the rehearsal-under-20-min acceptance
gate considered met.

**Today is the immutable presentation slot.** IMT Mines Alès supervisor
available **10h-10h30 only** (30-min hard cap on the joint slot); IMT
Nord Europe supervisor's window allows extended discussion past 10h30.
Live-talk budget locked Tue: **15-20 min summary + 10-15 min discussion**.

**Three lead items today:**

1. **Pre-presentation final check** (~30-45 min, 9h-9h45ish,
   Windows-side): laptop charge / Windows env + `.pptx` accessible /
   live-talk backup (slides-only PDF alongside `.pptx`, optional
   notes-pages PDF for print handout) / room + presentation mode
   confirmed / any last fact-check from Tue's pre-deck-shipping notes.
2. **Joint supervisor presentation 10h-10h30** — primary output of the
   day; 8-10 slide live talk + Q&A within the 30-min IMT Mines Alès cap;
   capture supervisor reactions / Three Asks status / scope signals for
   Block D debrief.
3. **Extended discussion + post-talk debrief** (post-10h30, variable +
   afternoon): IMT Nord Europe one-supervisor continuation if scheduling
   permits; consolidate notes; extract action items; queue Thu 21/05+
   priorities.

**Week shape:**

- **Wed 20/05 (today)** — presentation + extended discussion + debrief.
- **Thu 21/05 / Fri 22/05** — post-presentation; likely Phase 5 driver
  bring-up planning skeleton + hardware-design pass kickoff if the talk
  lands cleanly; reactive scope if supervisor input redirects.

**Pre-presentation carry-forwards (from Tue EOD, still pending — most
post-talk):**

- Phase 5 driver bring-up planning (Roadmap §3 — driver candidates,
  `mavros2` install path, autostart strategy on Pi, topic-name scheme
  aligned with `launch/remap.launch.yaml`). Post-presentation Thu+.
- Phase 5 hardware power-design pass (Roadmap §3 — regulated ≥5A 5V
  supply, bulk capacitance near Pi power input, thick-short GPIO leads
  or proper USB-C input, possibly powered USB hub between Pi and
  RealSense). Pre-bring-up prerequisite.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  Option A single canonical camera node + RTP republish for Herelink,
  or Option B multi-mux camera-fork daemon at v4l2 layer).
- **Three Asks to teammate maintainer** (Phase A parameter subset / CA
  placement confirmation / validation methodology) — slide 10 surfaces
  these as open items; supervisor input today may resolve some / all.
- Mock water quality sensor implementation (Phase A) — likely unblocked
  by Wed Q&A if the parameter subset gets confirmed.
- Second-site (lake) Herelink video A/B retest — next field session.
- VRX §8.2 weekly cadence next check **Mon 25/05** (no action Wed).
- Three new-data-points from Mon 18/05 audit, all queued post-talk:
  Pi thermals 43-63 °C baseline, 49 Pi apt updates pending, RealSense
  xioctl-then-auto-recover steady-state pattern.

Active blocks:

1. **Block A — Pre-presentation final check**
   (~30-45 min, 9h-9h45ish, Windows-side): laptop charge + charger in
   bag; `.pptx` opens cleanly in PowerPoint (live mode + speaker-notes
   mode); slides-only PDF export ready as font-rendering insurance;
   optional notes-pages PDF if print handout wanted; room / location
   confirmed; presentation mode (in-person + projector / hybrid /
   remote) confirmed and screen-share / projector cable plan in place;
   any last fact-check item flagged in Tue's deck-shipping notes that
   needs a Linux-side `git log` / `git grep` check (do it now, not 5
   min before 10h).
2. **Block B — Joint supervisor presentation**
   (10h-10h30, 30-min IMT Mines Alès hard cap): live talk 15-20 min
   across the 8-10 slides (Title/agenda → Status snapshot → Phase 5
   architecture → First wet test 07/05 → Network architecture findings
   → Pi 5 bring-up findings → Camera-consumer-exclusivity → VRX fork +
   sim stability → Obj 1/2/3 scope refinements → Open questions);
   discussion 10-15 min covering supervisor questions + Three Asks
   surface + Phase 5 timeline reactions + scope signals. Capture
   per-slide supervisor reactions briefly; flag any slide-claim
   pushback for Block D doc-correction queue.
3. **Block C — Extended IMT Nord Europe discussion**
   (post-10h30, variable, on-site): if scheduling permits, continue
   with IMT Nord Europe supervisor alone. Likely topics: Phase 5 driver
   bring-up planning prep, mock water sensor parameter set detail,
   deeper-dive on slides 5-7 (network / Pi 5 / camera), Three Asks
   resolutions if Mines Alès didn't get to them, Obj 3 ML scope detail.
   Capture decisions per topic.
4. **Block D — Post-presentation debrief + action-item extraction**
   (~30-60 min, early-afternoon, Linux-side): consolidate Block B + C
   notes; extract action items (Thu+ scope, owner, target); update
   `Board.md` Wed 20/05 Timeline row if substantive supervisor-confirmed
   scope changes / Three Asks resolutions / Phase 5 timeline pins;
   update `wiki/Roadmap.md` §1.1 / §1.2 / §3 / §9 if scope-signal
   warrants; queue any deck slide-claim correction items if surfaced.
5. **Block E — Day wrap** (~30 min, evening): diary outcomes,
   `Board.md` row likely already handled in Block D (or here if late);
   commit + push diary; sketch Thu 21/05+ startup priorities; final
   commit subject template depends on dominant outcome.

**Hard boundary today:**

- **10h-10h30 IMT Mines Alès joint slot is the immutable hard cap.** If
  pre-check at 9h-9h45 surfaces a fixable issue, time-box the fix to
  ≤15 min; if not fixable, present with caveat and note the gap during
  the open-questions slide.
- **No deck edits Wed AM** — deck shipped Tue per Block D acceptance
  gate. Last-minute slide changes risk introducing typos under time
  pressure; trust Tue's rehearsal.
- **No Phase 5 driver bring-up code Wed** — even if Q&A surfaces
  unblock signal, planning starts Thu earliest (need hardware-design
  pass first per Roadmap §3 prereq).
- **No live sim runs Wed** unless supervisor explicitly requests one
  during the talk window.
- Pi 5 stays Ubuntu Server headless permanently (13/05 supervisor
  directive).
- **Don't lock Thu+ scope mid-presentation** — capture supervisor
  signals during Block B/C and defer scope decisions to Block D
  debrief; in-the-moment commitments tend to over-promise.

**Fallback if Block A surfaces a `.pptx` open failure** (Windows env not
reachable / file corrupt / font missing): time-box repair to ≤15 min; if
not fixable, fall back to slides-only PDF export (created EOD Tue per
Tue's Block E checklist) for live mode and lose speaker-notes for async
reference — present the live slot via PDF, re-export `.pptx` post-talk.
Reference-mode users get the `.pptx` later in the day.

**Fallback if Block B presentation runs over** (live talk exceeds 20 min
into the 30-min window): IMT Mines Alès supervisor leaves at 10h30
regardless. Compress remaining live points into discussion-mode Q&A;
continue with IMT Nord Europe supervisor past 10h30 to cover any cut
content. The 15-20 min live budget is a soft preference; the 30-min IMT
Mines Alès cap is hard.

---

## Block A — Pre-presentation final check (~30-45 min, 9h-9h45ish, Windows-side)

**Goal.** Walk into the 10h slot with zero surprise risk. Every check
that can be done EOD-Tue should already be done; Block A confirms.

**Pre-flight checklist:**

- [ ] Laptop charged ≥80 % or charger physically in bag
- [ ] Windows session can reach the `.pptx` file path
- [ ] `.pptx` opens cleanly in PowerPoint — both live mode (presentation
      view) and reference mode (speaker notes panel visible)
- [ ] Slides-only PDF export ready alongside `.pptx` (font-rendering
      insurance; created at EOD Tue if Tue's Block E checklist ran)
- [ ] Optional notes-pages PDF export — only if a print handout is
      wanted for the supervisors
- [ ] Room / location confirmed for the 10h slot (in-person vs remote)
- [ ] Presentation mode confirmed: in-person with projector (HDMI /
      DisplayPort cable; adapter for USB-C if needed), hybrid (one
      supervisor on video call — laptop screen-share capable +
      microphone tested), or full remote (video-call link shared +
      screen-share setup tested)
- [ ] Any last fact-check item from Tue's pre-deck-shipping notes that
      needed a Linux-side `git log` / `git grep` cross-check — done now,
      not 5 min before 10h
- [ ] Phone / laptop notifications muted for the 10h-10h30 window
- [ ] Pen + paper or note-taking app open for capturing supervisor
      reactions during Block B

**Git state confirm** (Linux laptop, quick check before AM if convenient):

```bash
cd ~/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -5
git status --short --branch
```

Expect HEAD = `3cd8861 docs: 19/05 Block E outcome + close verification`,
`main` in sync with `origin/main`, working tree clean. Any drift = flag
and decide whether to address (likely defer past 10h30).

**Outcome.** [To fill — pre-flight check verdict (all green / blockers
flagged); any 9h-9h45 surprises and how they were handled; final go /
no-go signal for the 10h slot.]

---

## Block B — Joint supervisor presentation (10h-10h30, 30-min IMT Mines Alès hard cap)

**Live talk shape** (15-20 min target):

| # | Slide | Target time |
|:--|:------|:------------|
| 1 | Title + agenda | 30-60 s |
| 2 | Status snapshot (Phase 1 done / 2 done / 4 90 % / 5 starting / 3 paused) | ~60 s |
| 3 | Phase 5 architecture | ~90 s |
| 4 | First wet test 07/05 outcomes | ~90 s |
| 5 | Network architecture findings | ~90-120 s |
| 6 | Pi 5 bring-up findings | ~90-120 s |
| 7 | Camera-consumer-exclusivity constraint | ~90 s |
| 8 | VRX fork + sim stability | ~60-90 s |
| 9 | Obj 1/2/3 scope refinements | ~90-120 s |
| 10 | Open questions + next steps | ~60-90 s |

**Discussion shape** (10-15 min):

- Supervisor questions on any slide content.
- **Three Asks surface** (during slide 10 or in discussion): Phase A
  parameter subset / CA placement confirmation / validation methodology
  — explicitly request supervisor input.
- Phase 5 timeline reactions — does the Thu+ driver-bring-up scope pass
  muster? Hardware-design-pass prerequisite acknowledged?
- Mock water sensor parameter set — supervisor confirmation possible
  today?
- Scope signals — any Obj 1/2/3 re-direction implied?

**Note-capture during the talk** (paper or note-taking app — not laptop
unless screen-share allows discreet typing):

- Per-slide supervisor reactions (1-line each: nod / question /
  pushback / neutral).
- Any slide-claim pushback flagged for Block D doc-correction queue
  (e.g., supervisor disagrees with a number / framing — capture exact
  wording to verify later).
- Three Asks: which got resolved (with supervisor input wording) vs
  which stay pending.
- New scope signals or supervisor-flagged questions.

**Outcome.** [To fill — talk timing (overall + any slide that overran);
per-slide supervisor reaction summary; Three Asks status (N resolved /
N pending); Phase 5 timeline supervisor reaction; any scope signals or
doc-correction queue items; Mines Alès supervisor satisfied / partial /
needs-follow-up verdict.]

---

## Block C — Extended IMT Nord Europe discussion (post-10h30, variable, on-site)

**If scheduling permits**, continue with IMT Nord Europe supervisor
only. The 30-min cap was Mines Alès-specific; Nord Europe's window is
open per Tue scaffold context.

**Likely topics** (any combination):

- **Phase 5 driver bring-up planning prep** — which drivers go first
  (LiDAR / GPS / IMU candidates), `mavros2` install path, autostart
  strategy on Pi, topic-name scheme aligned with
  `launch/remap.launch.yaml`. Likely a Thu+ scope decision; Block C is
  fact-finding, not plan-locking.
- **Mock water sensor parameter set detail** — if not resolved in
  Block B, dig deeper one-on-one.
- **Deeper-dive on slides 5-7** — network architecture / Pi 5
  bring-up / camera-consumer exclusivity. The v4l2 sharing-mechanism
  options (Option A: single canonical camera node + RTP republish for
  Herelink, or Option B: multi-mux camera-fork daemon at v4l2 layer)
  may be the most actionable architecture question.
- **Three Asks resolutions** if Mines Alès didn't cover them.
- **Obj 3 ML scope detail** — residual-based / time-series /
  physics-informed (stretch) framing was confirmed 30/04; any further
  refinements?
- **Hardware-design pass detail** — regulated ≥5A 5V supply / bulk
  capacitance / USB hub option for RealSense decoupling.

**Note-capture priority during Block C:**

- Decisions reached (vs ideas floated).
- Action items for Thu 21/05+ (owner / target / blocker / depends-on).
- Any architecture-level commitments (e.g., "let's go with Option B for
  camera sharing") — these inform Roadmap §3 updates in Block D.

**Outcome.** [To fill — Block C ran (or N/A if no extension); topics
covered; decisions reached per topic; Thu+ action items with owner /
target; any architecture-level commitments to capture in Roadmap.md.]

---

## Block D — Post-presentation debrief + action-item extraction (~30-60 min, early-afternoon, Linux-side)

**Consolidation step.** Merge Block B + Block C notes into a single
clean action-item list. Each item: what / why / who / when / blocker.

**Action-item extraction targets:**

- Phase 5 driver bring-up Thu+ plan — does today's input change the
  scope from Tue's queued state? If yes, sketch the revision.
- Phase 5 hardware-design pass — any supervisor-provided constraints to
  layer in?
- Phase 5 camera-consumer sharing — supervisor-preferred option
  (A / B / no-preference)?
- Three Asks — final state: which resolved (with supervisor wording
  captured), which pending (with next-resolution-path noted).
- Mock water sensor (Phase A) — go / no-go signal, parameter set if
  given.
- Obj 1 / Obj 2 / Obj 3 — any further scope refinements?
- New questions / supervisor-flagged items to queue (in `Board.md`
  Risks section or `wiki/Roadmap.md` if needed).
- Deck-claim correction queue — any slide claim the supervisor pushed
  back on; need to verify and update `Board.md` / `wiki/Roadmap.md` if
  the claim was wrong.

**Doc updates** (apply Block D if substantive; defer to Thu+ if
significant rewrites):

- `Board.md` — Timeline row for 20/05/2026 capturing the talk outcome
  - scope shifts; bump `Last Updated` (currently 18/05/2026) and
  `Document Version` (currently 9.13 → 9.14+); update Risks if Three
  Asks resolution removed any.
- `wiki/Roadmap.md` §3 Phase 5 rows if supervisor input pins driver
  candidates / hardware-design constraints / camera-sharing option.
- `wiki/Roadmap.md` §9 revision-log entry for 20/05/2026 capturing the
  change provenance.
- `wiki/Roadmap.md` §1.1 / §1.2 / §1.3 if Obj 1/2/3 scope shifts.

**Hard scope cap on Block D.** Don't expand into "rewrite half the
Roadmap" — capture today's signals as Timeline rows + targeted §3 / §9
updates; bigger rewrites are Thu+ scope. The acceptance criterion for
Block D is *action items extracted + minimal doc updates landed*, not
*full Roadmap refactor*.

**Outcome.** [To fill — action-item list summary (N items: Thu+ /
defer / done-in-Block-D-itself); Board.md Timeline row added (or why
not); Roadmap.md edits landed (or queued); deck-claim correction queue
items resolved or queued; Thu 21/05+ scope decision recorded.]

---

## Block E — Day wrap (~30 min, evening)

Same shape as Tue 19/05 Block E + Mon 18/05 Block E:

1. `git log --oneline -10` — sanity check today's commits (likely 1-2:
   Block D edits + this Block E wrap; multi-commit pattern fine if
   Block D landed Board.md / Roadmap.md edits in a separate intra-day
   commit, mirroring Mon 18/05's `de6e0af` / `c9cec9c` / `9452a37`
   sequence).
2. `git diff --check` — whitespace / conflict-marker sweep.
3. Pre-commit invisibility sweep — expect 0 matches. Run from main-repo
   root before the wrap commit.
4. `Board.md` Wed 20/05 Timeline row likely already added in Block D;
   if not, decide now (probably yes — supervisor outcomes are
   repo-relevant). Bump header `Last Updated` + footer `Document
   Version` (9.13 → next) if any tracked content updated. **Use search
   rather than line numbers** (rows drift).
5. Fill all `[To fill]` placeholders in this file — **including Block E
   itself before the wrap commit**, per Tue 19/05 lesson learned (Tue
   needed a follow-up commit to close Block E because the placeholder
   was forgotten in the wrap).
6. Working diary commit; subject template depends on dominant outcome:
   - Smooth talk + Three Asks resolved + Phase 5 unblock signals:
     `docs(diary): wrap 20/05 supervisor talk + Phase 5 unblock`
   - Three Asks resolved (clean win, narrower scope shift):
     `docs(diary): wrap 20/05 supervisor talk + Three Asks resolved`
   - Scope refinement signals from talk:
     `docs(diary): wrap 20/05 supervisor talk + scope refinement`
   - Partial / follow-up presentation needed:
     `docs(diary): wrap 20/05 supervisor talk + follow-up scheduled`
   - Generic / mixed:
     `docs(diary): wrap 20/05 supervisor presentation + debrief`
7. Push.
8. **Thu 21/05 morning startup hint** — what's the next-day starting
   point? Likely Phase 5 driver bring-up planning skeleton (paper plan
   only — no Pi work; hardware-design pass prereq covered first).
   Capture in this file's Next Steps Active branch.
9. **Optional: External Week 11 diary update** — Windows-side task; if
   Tue didn't get to it, Wed evening might. Defer to next Windows
   session if Linux-only today.

**Outcome.** [To fill at end of day — diary closed; Board.md row
landed; Wed commits summary; Thu 21/05 startup hint queued.]

---

## Verification summary — 20/05 (check at end of day)

- [ ] Block A: pre-presentation final check done; no 9h-9h45 blockers;
  go / no-go signal recorded
- [ ] Block B: joint slot completed within the 30-min Mines Alès cap;
  per-slide supervisor reactions captured; Three Asks status known;
  scope signals noted
- [ ] Block C: extended IMT Nord Europe discussion either completed
  with topic coverage notes, or marked N/A (no extension)
- [ ] Block D: action items extracted; Board.md / Roadmap.md edits
  applied if scoped; deck-claim correction queue resolved or queued;
  Thu+ scope decision recorded
- [ ] Block E: diary filled (including Block E itself before commit);
  pre-commit sweep clean; commit + push handled; Thu 21/05 startup
  hint queued

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Pre-check done; no deck blocker | None — talk goes ahead |
| Block B | Joint slot completed | **High** if scope-shifting outcomes (Block D scope expands); **Medium** if smooth talk + clear unblock signals; **Low** if neutral talk |
| Block C | Extended discussion outcomes captured (or N/A) | Low — Block C is bonus, not load-bearing |
| Block D | Action items + doc updates landed | **Medium-High** if Roadmap rewrites triggered (defer rewrites to Thu+); **Low** if Timeline-row + targeted §9 update only |
| Block E | Day closed; Thu+ queued | Standard |

---

## Known unknowns to record during the day

- Will IMT Nord Europe supervisor join in-person / on video call?
  (Affects Block C continuation feasibility.)
- Will all Three Asks get supervisor input today, or stay partial?
- Will Phase 5 timeline get pinned to a specific date during the talk?
- Mock water sensor parameter set — supervisor-confirmed today or
  deferred?
- Any new directions / scope redirects the supervisors flag (e.g.,
  Obj 3 ML methodology shift, additional CA placement guidance)?
- Camera-consumer sharing — does the supervisor prefer Option A
  (single canonical node + RTP republish) or Option B (multi-mux at
  v4l2)?
- Any slide claim the supervisor pushed back on (deck-claim correction
  queue input)?

---

## Next steps — Wed 20/05 → Thu 21/05+

### Active branch: Wed 20/05 supervisor talk + post-talk debrief → Thu+ scope

Today's outcomes drive Thu+ scope:

- **If talk smooth + Three Asks resolved + Phase 5 unblock signals**:
  Thu 21/05 starts Phase 5 driver bring-up planning skeleton (paper
  plan only — driver candidates, `mavros2` install path, autostart
  strategy on Pi, topic-name scheme); Fri 22/05 hardware-design pass
  layout sketch.
- **If scope-shifting outcomes** (Obj 1/2/3 re-direction, new
  experiment scope, etc.): Thu 21/05 prioritises Board.md /
  Roadmap.md edits + sketch revised plan; Phase 5 work deferred until
  scope stable.
- **If follow-up presentation needed**: Thu 21/05 prepares follow-up
  deck (light polish of today's deck or addendum slide pack); Phase 5
  work delayed.

### Pending (carries past Wed; mostly post-talk)

- Phase 5 driver bring-up planning — newly unblocked post-Tue 12/05
  B.1 DDS WORKS + Wed 13/05 C.7 RealSense bridge State B validation +
  Mon 18/05 sim-stack regression PASS; first focused session can plan
  driver candidates, `mavros2` install path, autostart, topic-name
  scheme. **Post-presentation slot (Thu 21/05+).**
- Phase 5 hardware power-design pass (Roadmap §3 — regulated ≥5A 5V
  supply, bulk capacitance near Pi power input, thick-short GPIO leads
  or proper USB-C input, possibly powered USB hub between Pi and
  RealSense). Pre-bring-up prerequisite.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  Option A single canonical node + RTP republish for Herelink, or
  Option B multi-mux camera-fork daemon at v4l2 layer). Today's Q&A
  may guide.
- Three Asks status post-talk — whichever stay pending need a next
  resolution path noted in Block D.
- Mock water sensor (Phase A) — supervisor confirmation today may
  unblock implementation Thu+.
- Second-site (lake) Herelink video A/B retest — deferred to next
  field session under known-good QGC `Source = Herelink Hotspot`
  preset.
- VRX §8.2 weekly cadence next check **Mon 25/05** (no action Wed).
- Three new-data-points from Mon 18/05 audit, all queued post-talk:
  Pi thermals 43-63 °C baseline, 49 Pi apt updates pending, RealSense
  xioctl-then-auto-recover documentation candidate for
  `wiki/Common_Issues.md` or `wiki/Pi5_Bringup_Smoke_Test.md`.

### Possible time-permitting tasks (pick up only if Wed afternoon runs short)

- **External Week 11 diary skeleton** (Windows-side) — if Block D/E
  finishes early with afternoon time to spare, scaffold the Week 11
  external diary file. Otherwise defer to next Windows session.
- **Phase 5 driver bring-up plan skeleton** (paper plan only, no Pi
  work today) — captures which drivers go first, install ordering,
  topic-name scheme. Skeleton only; real planning is Thu+.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — see Pending
  list).
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
  pauseable. Not Wed scope.
