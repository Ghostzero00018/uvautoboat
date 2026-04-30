# 2026-04-30 — Thursday: 30/04 delivery + post-delivery wrap

## Context

Pre-scaffold written 30/04 morning. Today is delivery day for the supervisor presentation; per yesterday's `working_diary/2026-04-29_*.md` "Spillover to Thursday morning" line, the morning absorbs all PPT-side work that didn't land Wednesday (visual placement / speaker-note timing pass / rehearsal pass 3 / Wed-evening 10-item review). Afternoon delivers. Evening picks up small repo follow-ons that don't compete for Thursday-morning's buffer.

**Week shape recap (closing edge):**

- **Mon 27/04** — Linux content + evidence; unplanned Windows evening sprint absorbed Tuesday's Block A
- **Tue 28/04** — PPT paste + assets + cold-boot launcher fix (`2c0194a`) + conventions-doc trim (Gist `80a910f`)
- **Wed 29/04** — Linux dev day: cold-boot validation + SIGPIPE fix (`62636e9`) + dashboard reset polish (`7565242`) + launch timer (`3822e54` + `37e197c`) + health-check disclaimer (`a6792db`) + Mission Progress 7-fix bundle (`181ddd7`) + doc-audit thread (`80a910f` + `42f1c30` + README/Home freshness). PPT-side shifted to Thu morning.
- **Thu 30/04 (today)** — finish PPT spillover, final dry run, deliver, post-delivery wrap with three follow-on tasks.
- **Fri 01/05** — Labour Day, no work expected.
- **Mon 04/05** — RTF investigation kickoff (deferred from 29/04 cold-boot validation).

**Why today matters:**

Delivery is the gate. Everything Wednesday produced was in service of today's 1.5-hour window. The morning carries real time pressure (Wed spillover + last-mile + dry run all compressed into the half-day before delivery); the evening blocks are post-delivery slack used to close small repo loops that have been sitting open.

Active blocks for the day:

1. **Block A — Wed spillover finish** (~2-3 h, AM): PPT visual placement, speaker-note timing pass, rehearsal pass 3, Wed-evening 10-item review — everything Wednesday's day pivot bumped to Thursday.
2. **Block B — Final dry run + last-mile fixes** (~1-1.5 h, late AM): one full timed end-to-end pass; only typo / mis-speaking / transition fixes.
3. **Block C — DELIVER + capture** (~1.5-2 h, PM): presentation + group meeting + capture supervisor asks (CCU low-level architecture / Phase A water-quality parameter set / Phase 5 hardware-arrival window).
4. **Block D — Repo markdown + code-comment cleanup pass** (~1-2 h, evening, follow-on): widens the scope from yesterday's tightly-targeted `42f1c30` (param_ranges 3-tuple comment refresh) to a broader sweep across the repo.
5. **Block E — Cold-start re-test** (~15 min, evening): first cold boot since `62636e9` landed. Verifies the SIGPIPE fix holds and Apport doesn't fire on a fresh boot — yesterday's diary L196-199 explicitly deferred this.
6. **Block F — VRX fork scheme entry** (~30 min, evening): scoping note in `Board.md` + `wiki/Roadmap.md` for a future option to fork upstream `osrf/vrx` and maintain a customized version. Not actual fork work; just reserving the option with explicit trigger conditions.
7. **Block G — Week 8 wrap + Week 9 scaffold** (~30 min, evening): `git log --oneline -10` sanity, pre-commit grep, 30/04 Board.md milestone row(s), commit diary, create `Week9_04_05-08_05.md` scaffold in the external diary folder.

---

## Block A — Wed spillover finish (~2-3 h, AM)

Per yesterday's diary "Spillover to Thursday morning:" line. Three sub-tasks:

### A1 — PPT visual placement (~1 h)

Yesterday's Block B from `working_diary/2026-04-29_*.md` L41-65. Open the deck + the `2026-04-30/` assets folder side-by-side; drop each captured PNG / MP4 into its placeholder; resize to fill. PPT-drawn diagrams (Slides 3, 5, 6 topology) use in-app shapes — do NOT spend Thursday morning on Inkscape.

After each slide, eyeball at presentation zoom (View → Reading View / F5) — assets must read at projection size, not just laptop-zoom legible.

**Outcome.** [To fill]

### A2 — Speaker-note timing pass (~30 min)

Yesterday's Block C step 1 (L67-77). Open Notes view; read each slide's EN block aloud, timed; total target 22-26 min EN-primary spoken. Mark overruns in the slide margin.

**Outcome.** [To fill]

### A3 — Rehearsal pass 3 (~1 h)

Yesterday's Block C step 2 (L78-83). Full end-to-end with deck open in front; English-primary delivery, bilingual at transitions where natural. Time the WHOLE pass (intro + outro + slide transitions + Q&A buffer); target ~30 min wall-clock for a 22-26 min spoken.

Mark any slide that breaks the rhythm — asset not loading, note too dense, transition feels forced.

**Outcome.** [To fill]

### A4 — Wed-evening 10-item review (~30 min)

The 28/04 "Next steps" line called out four items by name; the remaining six live in `2026-04-30_slide_outline.md` (Windows-side). Pull them up at review time.

Known items from 28/04:

1. **No-ellipsis check** — every "..." in slide bodies is either explicit content or removed.
2. **Visual motif consistency** — colour palette, font sizing, badge styling uniform across slides.
3. **Asks-box highlighting** — Slide 7 "Asks" section visually distinct from "Demo" and "Future Work".
4. **QR scan test** — phone-test every QR code in the deck (repo URL, dashboard URL, presentation slides URL if any).

Items 5-10: pull from the outline file at review time.

**Outcome.** [To fill]

---

## Block B — Final dry run + last-mile fixes (~1-1.5 h, late AM)

One final timed end-to-end pass against the visually-complete deck. Fix only last-mile issues (typos, mis-speaking patterns, final transitions). **Do NOT make new slides; do NOT defer last-mile findings to "after delivery"** — by then they'll have shipped.

Pre-flight Linux check (only if Block C ends up calling for a live demo):

```bash
cd ~/seal_ws/src/uvautoboat
git status --short                 # tree should be clean
git log --oneline -5               # HEAD should reflect Wed's pushed commits
bash one_click_launch_all/launch_autoboat_complete.sh
# Wait ~30-60 s for success banner + "Total launch time: N s" line.
ros2 node list | grep -E 'heading_controller|lidar_perception|waypoint_planner|waypoint_visualizer|health_check_service'
# Expect 5 hits.
```

**Outcome.** [To fill]

---

## Block C — DELIVER + capture supervisor asks (~1.5-2 h, PM)

Presentation + group meeting per the rehearsed flow.

### Three explicit Asks to bring into the room (Slide 7)

1. **CCU low-level architecture** — confirm whether a separate low-level controller exists between Pi 5 and thrusters; if yes, what chip + firmware (MAVLink autopilot is the working hypothesis from 23/04 walk-through).
2. **Phase A mock water-quality sensor parameter set** — supervisor sign-off on subset (pH / turbidity / DO / temperature / conductivity) + sampling cadence.
3. **Phase 5 hardware-arrival window** — when the CCU lands at the bench.

### Capture targets

- Delivery notes (timing vs target, audience reactions, smooth-vs-stilted transitions)
- Feedback points (technical + scope + presentation style)
- Phase A parameter-set decision (or confirmation of further defer)
- Commitments made (theirs to us; ours to them)
- Follow-up TODOs surfaced during meeting

**Outcome.** ✅ Smaller-scale than originally planned. **Campus power outage + IMT Mines Alès supervisor unavailable** the morning of 30/04, so the formal joint presentation was scratched. The on-site team (maintainer + teammates) held its own scoping session in the afternoon instead — closer to a working scope-lock than a delivery, but it answered the questions we needed before next week.

**Scope locked across the three formal objectives** (see `wiki/Roadmap.md` §1.1 for the durable scoping reference):

- **Obj 1 — telemetry only.** "Real sensor data from the drone" = boat telemetry (GPS, IMU, velocity, …) flowing low-level controller → Pi 5 (Ubuntu 24.04 + ROS 2 Jazzy, headless, on the IoT IMT Nord Europe network) → VRX simulator on the Linux workstation. Water-quality data is *not* part of Obj 1; it lives under Obj 2. Both streams ultimately reach the simulator, but Obj 1 owns only the telemetry plumbing. Simulator mirrors the real boat's pose — that is the digital-twin baseline.
- **Obj 1 architecture clarifications.** `mavros2` (the ROS 2 port of MAVROS) is the MAVLink ↔ ROS bridge on the Pi 5. **MAVProxy is *not* the bridge** — it is a MAVLink router/multiplexer; the two are easy to confuse and were initially conflated in the meeting notes. Pi 5 ↔ Linux workstation talk via ROS 2 / DDS over the shared IoT WiFi; **multicast support on that network must be verified early** (corporate IoT WiFi often blocks multicast or isolates clients) — basic `talker` / `listener` round-trip before any serious pipeline work.
- **Obj 2 — CA placement.** Most likely Linux-side, not Pi 5: more compute, easier dashboard integration, less contention with boat-side control loop. Pending explicit confirmation in the next supervisor exchange.
- **Obj 3 — regional datasets REMOVED.** Accessible historical data for the project's region is insufficient (CESER / CPER ECRIN / VERD-Eau / CASTREau / CAP'Eau access not viable). The formal Obj 3 wording is preserved in `wiki/Roadmap.md` §1 for traceability; the implementation interpretation is now same-day cross-validation.
- **Obj 3 — validation refined.** Same-day cross-validation: collect along R₁ + R₂ in one outing; hold out R₂; train CA on R₁; predict R₂; compare to held-out R₂. No temporal-change confound. Few-days' return is acceptable for slow-changing parameters only (conductivity in stable closed lake) — not for dynamic ones (DO post-rain, turbidity post-disturbance). The original meeting interpretation ("navigate route on day 1, return day 2-3 with different route, compare to day-1 prediction") was sharpened to surface the temporal-confound issue.
- **Obj 3 — ML scope refined.** "Train an ML model deriving from the CA function" (initial framing) was rejected — training on a model's outputs just relearns the model. Refined approach: residual-based anomaly detection + time-series forecasting (ARIMA / Prophet / LSTM) + physics-informed ML (CA as prior, ML on residual) as a stretch goal.

**Open questions surfaced during the meeting** (sent to teammate maintainer in writing for confirmation, see §1.2 of Roadmap):

1. Phase A water-quality parameter subset — full set or smaller subset?
2. CA model compute placement — Linux workstation (recommended) or Pi 5?
3. Validation methodology — same-day cross-validation (recommended) or day-gap return?

**Doc landing.** Scope-lock written into `wiki/Roadmap.md`: §1.1 (scope clarifications), §1.2 (the three open questions), §6 Phase E (validation approach refresh, regional-datasets removal note), §7 top-of-section update note + Phase E sub-list refresh, §9 revision log entry. This diary's Block C captures the meeting context and outcome; Roadmap is the durable reference.

**Carryover from delivery.** The formal joint presentation is rescheduled — date pending IMT Mines Alès supervisor availability + power restoration. Rehearsal pass + dry-run work from Block A/B/E is **not wasted**: same deck and asks carry forward. The 30/04 deck stays in `Research_intern_IMT_NE/PPT/PPT_files/30_04_2026_presentation/` as the canonical pre-rescheduled-meeting version.

---

## Block D — Repo markdown + code-comment cleanup pass (~1-2 h, evening)

Follow-on to yesterday's `42f1c30` (param_ranges 3-tuple comment refresh) which was tightly scoped to one stale class. Today's pass widens the lens.

### Sweep targets

- **Stale-class siblings.** Yesterday's class was "header docstrings overlooked when their function-level siblings were updated". Other classes that might mirror it:
  - Comments referencing removed functions / renamed identifiers (post-rename residue from 16/04)
  - Wiki cross-references with broken anchors (post-section-rename / post-cleanup-of-target-doc)
  - HTML comments in `index.html` referencing removed JS constants (`*_DEFAULTS`)
  - Python docstring `Subscribes:` / `Publishes:` lists out of sync with current code
- **Long-lived TODO / FIXME / XXX markers.** Anything older than ~2 weeks worth either resolving inline or escalating to a Board.md row + diary mention.
- **Dead links.** Any `[text](path)` in active markdown pointing at a file that's been moved / removed / renamed. Wiki Home cross-links → repo files (since `scripts/sync_wiki.sh` flattens) get particular attention.
- **Stale dates / counts.** "49 checks" still 49? "20-40 s warm cold-start" still in the ballpark with `Total launch time` data points? "Last Updated" stamps in heavily-edited files?

### Method

```bash
cd ~/seal_ws/src/uvautoboat

# 1. TODO / FIXME / XXX inventory (exclude legacy + working_diary)
grep -rnIE '\b(TODO|FIXME|XXX|HACK)\b' \
  --include='*.md' --include='*.py' --include='*.js' --include='*.html' --include='*.sh' --include='*.yaml' --include='*.yml' \
  --exclude-dir=legacy --exclude-dir=working_diary --exclude-dir=.git

# 2. Dead-link candidates (markdown links pointing at non-existent paths)
# Eyeball-pass on README.md + USER_MANUAL.md + wiki/*.md + per-package READMEs.

# 3. Stale identifier search — rename residue from 16/04
grep -rnIE '\b(OKO|SPUTNIK|BURAN|Vostok1|vostok1)\b' \
  --include='*.md' --include='*.py' --include='*.js' --include='*.html' \
  --exclude-dir=legacy --exclude-dir=working_diary --exclude-dir=.git
# Hits in legacy/ / working_diary/ are intentional; hits elsewhere are stale.

# 4. *_DEFAULTS / data-default residue (post-19969c3 cleanup; should be 0 hits)
grep -rnIE '(PERCEPTION_DEFAULTS|CONTROLLER_DEFAULTS|data-default)' \
  --include='*.md' --include='*.py' --include='*.js' --include='*.html' \
  --exclude-dir=legacy --exclude-dir=working_diary --exclude-dir=.git

# 5. Subscribes/Publishes docstring drift — read each Python module's docstring
# against current `create_subscription` / `create_publisher` calls.
```

Bundle findings; one commit per coherent class. Don't bundle unrelated fixes into one mega-commit.

**Outcome.** Three classes addressed, bundled into one commit (`2dfa650 docs: sync node docstrings, refresh stamps, drop dead wiki links`) rather than the originally-planned three per-class commits:

- **A — docstring `Subscribes:` / `Publishes:` drift.** `plan/plan/waypoint_planner.py` +2 subs (`/planning/detour_request`, `/planning/skip_waypoint`); `control/control/heading_controller.py` +1 sub (`/planning/mission_command`) + 2 pubs (`/control/replan_request`, `/planning/skip_waypoint`). `lidar_perception.py` clean (4 subs / 2 pubs all already in docstring).
- **B — stale `Last Updated` stamps.** `USER_MANUAL.md` 24/04 → 27/04 (last touched by `81cc4d6`); `web_dashboard/autoboat/README_autoboat_dashboard.md` 24/04 → 28/04 (last touched by `19969c3 refactor(dashboard): drop legacy default fallbacks`). Bumped to last-edit dates rather than today's date — accurate to evidence.
- **C — broken wiki cross-references.** `wiki/Quick_Start.md` Next-Steps section (4 broken pointers to non-existent `First-Mission-Tutorial` / `Terminal-Mission-Control` / `Web-Dashboard-Guide` / `Configuration-and-Tuning` pages) removed entirely; `wiki/Installation_Guide.md` kept the working `[Quick Start](Quick_Start)` pointer, dropped 2 broken siblings. `scripts/sync_wiki.sh` confirmed not to rewrite anchors — these were genuinely broken on the published GitHub Wiki too, not just locally.

Verified clean (no fix needed): TODO inventory (1 well-formed forward-looking note in `autoboat_cli.py:155` about a possible Tier-2 Trigger-service migration, conditional on a multi-operator coordination requirement); 16/04 rename residue (21 hits, all in intentional historical/explanatory docs — Glossary, Refactor Plan, Board milestone rows, README pointer, Home wiki note); `*_DEFAULTS` / `data-default` residue post-`19969c3` (3 hits, all in historical docs narrating the past 4-place sync model and its 28/04 collapse); cold-start time mention in `wiki/Common_Issues.md:22` (properly disclaimed in same sentence as hardware-dependent); health-check counts (5 mentions all consistent at 49 across `README.md` + `USER_MANUAL.md`).

Diff summary: 6 files / +8 / -14. Pushed.

---

## Block E — Cold-start re-test (post-62636e9 verification, ~15 min, evening)

Yesterday's diary L196-199 deferred this:

> Post-fix validation (deferred — current session is mid-run):
>
> 1. After next cold boot, run the launcher.
> 2. `cat /tmp/autoboat_launcher_probe.log` — expect zero `BrokenPipeError` lines.
> 3. `ls /var/crash/` — no new ros2 crash file dated today.

Today is the first cold boot since `62636e9` landed. Run the validation now.

### Test conditions

Fresh laptop reboot, no other apps opened first. ROS 2 daemon not running, no leftover Gazebo / rosbridge processes, `/tmp/autoboat_*.log` and `/tmp/autoboat_launcher_probe.log` empty.

### Steps

```bash
# 1. After fresh reboot, before opening anything else:
cd ~/seal_ws/src/uvautoboat
bash one_click_launch_all/launch_autoboat_complete.sh

# 2. Watch for the success banner and "Total launch time: N s" line.
#    No Apport popup should appear.

# 3. After success banner — pass criteria:
grep -c 'BrokenPipeError' /tmp/autoboat_launcher_probe.log
# Expect: 0

ls /var/crash/_opt_ros_jazzy*.crash 2>/dev/null
# Expect: no file (or files all dated before today)

ros2 node list | grep -E 'heading_controller|lidar_perception|waypoint_planner|waypoint_visualizer|health_check_service' | wc -l
# Expect: 5
```

### Pass / fail handling

- **All three checks pass:** log a 30/04 Board.md milestone row alongside the delivery row.
- **BrokenPipeError still appears OR Apport popup fires:** capture `/tmp/autoboat_launcher_probe.log` + relevant tab logs + any new `/var/crash/_opt_ros_jazzy*.crash` file; defer fix to Mon 04/05 (post-Labour-Day).
- **Other failure mode** (timeout warnings / missing nodes / new tab fatal exits): same — capture, defer.

**Outcome.** PASS. All three pass criteria green on the first cold boot since `62636e9` landed:

- `BrokenPipeError` in `/tmp/autoboat_launcher_probe.log`: **0** (probe log 99 B, only benign noise).
- `/var/crash/_opt_ros_jazzy*.crash`: only the pre-existing `1002.crash` from 29/04 10:23 (untouched); no new today-dated crash.
- 5 expected nodes alive (`heading_controller_node`, `health_check_service`, `lidar_perception_node`, `waypoint_planner_node`, `waypoint_visualizer_node`).

`62636e9` capture-then-grep refactor in `wait_for_topic` holds. Launch time **43 s** (vs 29/04's 52 s — 9 s faster, normal hardware variance per the `37e197c` disclaimer on launch-timer baseline). No Apport popup observed during launch. Stack left running through the morning since the demo path was already settled (recorded clips, no live demo gate).

---

## Block F — VRX fork scheme entry (~30 min, evening)

**Scheme-only entry; not actual fork work.** Goal: reserve the option to fork `osrf/vrx` and maintain a customized version, with explicit trigger conditions captured so the future-decision can be made on evidence rather than vibes.

### Trigger conditions (when to fork)

- `patch_vrx.sh`-style workarounds growing in number against upstream changes — one patch is fine, three becomes a pattern, five-plus is "just fork it".
- Custom worlds, sensors, or WAM-V modifications that wouldn't merge upstream (project-specific scope, not generally useful).
- Phase 5+ hardware integration that requires sim-side changes incompatible with upstream API surface.
- Long-term maintenance burden of repeated patches outweighing fork-maintenance burden (cherry-pick / rebase cost vs upstream pull cost).

### What forking would NOT solve

- Upstream's slow merge cadence — even on a fork, contributing back to upstream still takes the same time.
- Real-hardware bringup work — that's separate (Pi 5 / MAVLink integration) and lives outside VRX.
- Test-environment custom worlds — those already live in `test_environment/` independent of VRX.

### Cost estimate

- One-time: fork + setup CI + decide rebase vs merge strategy + write contributor docs (~1-2 days).
- Ongoing: rebase or cherry-pick from upstream (~1-2 hours per upstream sync, every few weeks).
- Alternative path: continue patches + occasional upstream PRs (current state; ~zero ongoing cost while patches stay <3).

### Where the entry lives

- **`Board.md`** — new row under "Future / TBD" with status 🔜 + scope "scheme only".
- **`wiki/Roadmap.md`** — short scoping subsection. Could go under "Sim infrastructure" (new section) or appended to research extensions.

### What to capture in the entries

- The decision criteria above (when to fork).
- Cost estimate (one-time + ongoing).
- Alternatives (continue patches; contribute upstream).
- Explicit "not now" framing — this is a scheme, not a plan.

**Outcome.** Two surfaces landed in commit `626ce96 docs(roadmap): add §8 VRX upstream-fork scheme + Board entry`:

- **`Board.md` Timeline:** new TBD row (🔜) `VRX upstream fork (scheme only — triggers / cost / explicit "not now" framing captured in wiki/Roadmap.md §8)`, slotted between Real-hardware deployment and Coverage Planning (both 🔜 deferred items).
- **`wiki/Roadmap.md`:** new §8 "Sim infrastructure — VRX upstream fork (scheme only, not active)" with 5 subsections — 8.1 Today's baseline (1 patch — `patch_vrx.sh` for upstream issue #876, well under threshold), 8.2 Trigger conditions (4: patch growth past ~3, project-specific changes upstream wouldn't accept, Phase 5+ sim-side dependencies, long-term maintenance balance flips), 8.3 What forking would NOT solve (3: upstream merge cadence, real-hardware bring-up, test-environment custom worlds), 8.4 Cost estimate + alternatives (3-row table: continue patches / fork / contribute upstream), 8.5 Explicit "not now". Existing §8 Revision log renumbered to §9 with a 30/04 entry.

Diff: `Board.md` +1 line; `wiki/Roadmap.md` +44 / -1. Pushed.

---

## Block G — Week 8 wrap + Week 9 scaffold (~30 min, evening)

Shifted from Friday per Labour Day.

1. `git log --oneline -10` — sanity check the day's commits.
2. Pre-commit grep — sweep for blocklist matches (zero expected).
3. `Board.md` updates — milestone rows for: 30/04 delivery (Block C), Block E pass (if Block E passed), Block D cleanup (if non-trivial), Block F scheme-entry land (if Block F landed).
4. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
5. On the Windows laptop, append today's section to `Research_intern_IMT_NE/working_diary/Week8_27_04-01_05.md` (Thu Block A through G summary; cross-link to this internal diary for detail).
6. Commit:

   ```bash
   git add working_diary/2026-04-30_thursday_delivery_and_post_wrap.md Board.md
   # Plus any wiki/ or other files touched during Block D / F.
   git commit -m "docs: fill 30/04 working diary with day's outcomes"
   git push
   ```

7. **Create Week 9 scaffold** in the external diary folder:

   ```bash
   # On Windows side:
   # touch E:\IMT_dossier\DMI_Semester_3\Research_intern_IMT_NE\working_diary\Week9_04_05-08_05.md
   ```

   Skeleton: Mon-Thu (no Fri, no public holiday this week). Mon 04/05 picks up the deferred RTF investigation as the lead item.

**Outcome.** Linux-side wrap complete. This commit fills the `[To fill]` placeholders for Blocks D / E / F / G; adds 30/04 milestone rows to `Board.md` Timeline for Blocks E / D / F; bumps `Board.md` `Last Updated` stamps (header L11 + Acknowledgments L365) from 29/04 → 30/04.

Block A (Wed PPT-spillover finish: A1 visual placement / A2 timing pass / A3 rehearsal pass 3 / A4 10-item review), Block B (final dry-run rehearsal — Linux pre-flight N/A per recorded-clips choice), and Block C (delivery + supervisor asks capture: CCU low-level architecture / Phase A parameter set / hardware-arrival window) outcomes remain Windows-side / post-delivery — to be filled in a follow-on commit once the supervisor meeting has happened and asks are captured.

Week 9 scaffold creation (`Research_intern_IMT_NE/working_diary/Week9_04_05-08_05.md` Mon-Thu skeleton with Mon 04/05 picking up the RTF investigation kickoff as lead item) flagged as Windows-side action — not landable from Linux.

---

## Verification summary — 30/04 (check at end of day)

- [ ] Wed spillover finished (Block A: A1-A4 all landed) — Windows-side
- [ ] Final dry-run passed; readiness verdict recorded (Block B) — Windows-side; Linux pre-flight N/A (recorded clips)
- [ ] Presentation delivered; supervisor asks captured; Phase A parameter-set decision recorded (Block C) — Windows-side / post-delivery
- [x] Repo markdown + code-comment cleanup pass complete (Block D) — bundled into single commit `2dfa650`, 3 classes covered
- [x] Cold-start re-test passed; no Apport, zero `BrokenPipeError` in probe log (Block E) — 43 s launch, 5 nodes up
- [x] VRX fork scheme recorded in `Board.md` + `wiki/Roadmap.md` (Block F) — `626ce96`, §8 in Roadmap, Timeline TBD row in Board
- [ ] Week 8 wrapped; 30/04 Board milestone row added; Week 9 scaffold created (Block G) — partial: wrap + Board rows ✅; Week 9 scaffold pending Windows-side
- [ ] This diary section filled — partial: D / E / F / G filled; A / B / C pending Windows-side
- [x] Pre-commit grep clean

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Wed spillover absorbed; deck visually + content complete | None — Block B can't proceed without it |
| Block B | Final dry-run done; readiness verdict locked | Last-mile fixes after this point are risky — call them off |
| Block C | Delivered + asks captured | Delivery is the one-shot; no rollover |
| Block D | Cleanup pass landed (or partially landed) | Carries to Mon 04/05 — append to Week 9 day-1 plan |
| Block E | Cold-start re-test verdict recorded | If failing, deferred to Mon 04/05 with full evidence captured |
| Block F | Scheme entries landed in Board + Roadmap | Carries to Mon 04/05 if not done — cheap, low priority |
| Block G | Week 8 closed + Week 9 scaffold created | Hard requirement before Mon — Week 9 needs the scaffold to start |

---

## Known unknowns surfaced during the day

Use this section to capture anything surprising — file state drift, unexpected behaviour, asset issues, supervisor-meeting findings that don't fit Block C's capture targets cleanly. Each entry: `file:line` or command + observation + fix or follow-up.

---

## Next steps — Mon 04/05 (Monday)

### Lead item

**RTF investigation kickoff** — deferred from 29/04 cold-boot validation per yesterday's diary L382. LiDAR `/points` ~2 Hz vs 10 Hz nominal; `libEGL DRI2` fallback on NVIDIA RTX A2000 as working hypothesis. First diagnostic per yesterday's diary:

```bash
glxinfo | grep "OpenGL renderer"
# Distinguishes Mesa-software / Mesa-llvmpipe / NVIDIA active provider in one line.
# sudo apt install mesa-utils  # if glxinfo not present.

ros2 topic hz /clock
# 250 Hz nominal at 0.004 s timestep → sampled / 250 = RTF.
```

Branches from there:

- Mesa-active despite NVIDIA driver loaded → `__GLX_VENDOR_LIBRARY_NAME=nvidia` env var or `prime-select nvidia`.
- llvmpipe (software) → driver issue; install matching `nvidia-driver-XXX`.
- NVIDIA active and fast but `/points` still 2 Hz → physics-bottleneck branch (CPU governor, `<physics><real_time_update_rate>`).

### Carryovers from today

- Block D cleanup if not finished
- Block F scheme entries if not landed
- Any supervisor-meeting commitments captured in Block C that have a Linux-side action

### Other deferred

- **P1 pier/bank stuck investigation** — diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A.
- **Mock water quality sensor implementation** — unblocked once supervisor confirms the parameter set (today's Asks item 2).
- **Real no-regression test for `launch/remap.launch.yaml`** — needs first real-hardware bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** — Phase 5.2+ scope (post-real-hardware-bringup).
- **24/04 housekeeping carry-overs** — `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Rainy-day.
- **`update-pip-graph` GitHub Actions Node 20 deprecation** — server-side; auto-resolves June 2026.
- **Dashboard scaffold-without-write audit** — surfaced as a 29/04 Mission Progress architectural lesson (`gps.x/y`, `progressState.distanceTraveled`, `obstacles.clusters`/`obstacle_count`, `mission.detour_active` were declared but never populated). Worth a focused audit pass to catch any remaining instances.
