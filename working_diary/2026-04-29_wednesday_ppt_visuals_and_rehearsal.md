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

## Cold-boot launcher validation (unplanned, AM)

Yesterday's `2c0194a` (improve logging and timeout handling in launch script) landed without a same-day cold-boot test. This morning's first slot ran a fresh-reboot validation before opening Block A.

### Test conditions

Fresh laptop reboot, no other apps opened first; ROS 2 daemon not running, no leftover Gazebo/rosbridge processes, `/tmp/autoboat_*.log` empty.

```bash
cd ~/seal_ws/src/uvautoboat
bash one_click_launch_all/launch_autoboat_complete.sh
```

### Result — pass

- Launcher reached `AutoBoat System Launched Successfully!` without any `wait_for_*` timeout warnings.
- `ros2 node list` returned all five expected nodes (`lidar_perception_node`, `waypoint_planner_node`, `heading_controller_node`, `waypoint_visualizer_node`, `health_check_service`) plus standard infra (`ros_gz_bridge`, `rosapi`, `rosbridge_websocket`, `rviz2`, frame publishers, `web_video_server`).
- No `recheck "appears to have exited"` warnings; no fatal entries in any `/tmp/autoboat_tab_*.log`.

The new `/wamv/sensors/lidars/lidar_wamv_sensor/points` gate fired and cleared. `wait_for_node /heading_controller_node 60` cleared without timeout. Patch goal — preventing first-launch-after-boot fatal ROS 2 crashes — met.

### Side finding 1 — `wait_for_topic` SIGPIPE → BrokenPipeError (fixed today)

`/var/crash/_opt_ros_jazzy_bin_ros2.1002.crash` (10:23) triggered an Apport popup on the cold launch. `/tmp/autoboat_launcher_probe.log` carries the underlying tracebacks: `BrokenPipeError` at `/opt/ros/jazzy/lib/python3.12/site-packages/ros2topic/verb/info.py:68`, twice (one per `wait_for_topic` call — GPS gate, LiDAR gate).

Mechanism. `ros2 topic info | grep -q 'Publisher count: [1-9]'` — once `grep -q` matches the second of three lines, it exits and closes its stdin; `ros2 topic info` then SIGPIPEs while writing the trailing `Subscription count: %d` line. `ros2cli` doesn't `signal(SIGPIPE, SIG_DFL)`, so Python raises an unhandled `BrokenPipeError` and Apport catches it.

Launcher effect: nil. `set -e` is on, `pipefail` isn't — pipeline status is `grep`'s 0, the `if` branch fires, `wait_for_topic` returns 0, the launcher proceeds. The Apport popup was the only visible artifact. Possible the original "first-launch-after-boot fatal crash" symptom that motivated `2c0194a` was *only* the popup all along; the launcher was reaching the success header through it.

Fix. Capture-then-grep in `wait_for_topic`: `ros2 topic info` writes all three lines into a local variable, `grep` operates on the captured string with no live pipe. `wait_for_port` uses `ss` (C program — ignores SIGPIPE silently) — unaffected. `wait_for_node` uses `timeout 2 ros2 param list >/dev/null 2>>...` with no piped consumer — unaffected.

Post-fix validation (deferred — current session is mid-run):

1. After next cold boot, run the launcher.
2. `cat /tmp/autoboat_launcher_probe.log` — expect zero `BrokenPipeError` lines. Other noise (`Unknown topic`, `failed to check service availability`, `Node not found`) is benign.
3. `ls /var/crash/` — no new ros2 crash file dated today.

### Side finding 2 — Gazebo RTF throttle (deferred)

`ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points` averaged ~2 Hz at T+0 and T+3 min. Nominal 10 Hz (`install/share/vrx_gazebo/models/wamv/tmp/model.urdf:1212` → `<update_rate>10</update_rate>`; xacro source `wamv_3d_lidar.xacro:28` → `update_rate:=10`). Ratio ≈ 0.2 → Gazebo running at ~20% RTF.

Probable cause: GPU/render fallback. Gazebo logs `libEGL warning: ... failed to create dri2 screen` on an NVIDIA RTX A2000 Laptop (PCI `10de:24b8`). Mesa probes legacy DRI2, fails, falls back; target backend (proprietary NVIDIA EGL vs llvmpipe) not confirmed today. The `gpu_ray` LiDAR sensor and shader-coupled physics step throttle when render isn't accelerated.

Pre-existing (independent of `2c0194a`); out of scope for the delivery week. Picked up under "Blocked / deferred (post-Thursday)" — week of 04/05.

### Outcome

- Cold-boot launcher patch validated.
- SIGPIPE side issue patched today (capture-then-grep in `wait_for_topic`).
- RTF throttle deferred to next week.

## Dashboard reset-path polish (unplanned, AM)

Surfaced after the cold-boot validation wrap-up — maintainer flagged a UX glitch in the Heading Controller panel: flipping `Use VFH Bias` (manual or via a quick-preset button) then clicking Reset Defaults left the orange `(default: X)` span lingering only for VFH while clearing correctly for other params. Also: that span rendered the raw HTML option value (`true` / `false`) rather than the dropdown's display label (`Enabled` / `Disabled`).

### Issue 1 — VFH dirty hint lingers after Reset Defaults

`resetGroupToDefaults` (`web_dashboard/autoboat/app.js:1594-1610`) iterates over `liveDefaults` entries. `controller-use-vfh` is intentionally outside `PARAM_RANGES` (boolean toggle, not a numeric range), so the loop skips it. The `extraReset` callback in `resetControllerToDefaults` handled VFH separately but only set `vfhEl.value = 'false'` — missing the `dirtyInputs.add` / `classList.add('input-dirty')` / `updateValueDisplay` trio that the main loop applies for every other input. The orange `(default: X)` span never re-rendered against the canonical default and lingered with whatever text it had before reset.

Fix. Extended the `extraReset` callback to mirror the loop's full reset trio.

### Issue 2 — Dirty hint shows `false` / `true` instead of `Disabled` / `Enabled`

`updateValueDisplay` (`app.js:1668-1684`) hardcoded `(default: ${canonical})` where `canonical` is the raw HTML option `value` (`'false'` for VFH default). The `<option>`'s `textContent` (`Disabled`) is what the user sees in the dropdown, so the hint disagreed with the visible label.

Fix. When `input.tagName === 'SELECT'`, look up the option whose `value === canonical` and use its `textContent` for display. Generic — any future tracked-default `<select>` benefits automatically.

### Audit for similar patterns

- **Custom-reset shortcuts that bypass the dirty trio.** Only one instance — the VFH `extraReset`, now fixed. `resetGroupToDefaults` is invoked with `extraReset` only by `resetControllerToDefaults`. `resetPerceptionToDefaults` has no `extraReset`; `resetConfigToDefaults` is a self-contained loop that already applies the trio correctly.
- **Other `<select>` elements.** `controller-use-vfh` is the only `<select>` in the entire dashboard. No `createElement('select')` / `new Option(...)` calls — no dynamic dropdowns. The `updateValueDisplay` fix covers any future `<select>` with a tracked default automatically.

Both VFH-pattern surfaces fully covered.

### Bonus finding — `btn-reset-astar` hardcoded defaults

Audit caught a related-but-different bug: the A\* Reset click handler (`app.js:1517-1548`) hardcoded `'3.0'` / `'12.0'` / `'20000'` for both the input `.value` sets *and* the ROS-published `config` object. Values matched `launch/autoboat.launch.yaml:139, 141, 143` so the button worked, but the structure was the same drift class the 28/04 option-1 cleanup was meant to eliminate — a YAML-default change would silently bypass this reset path while every other reset would track it.

Migration applied (separate from the VFH fix scope, bundled in the same commit since both are dashboard reset-path cleanup):

- HTML (`web_dashboard/autoboat/index.html:357`) — `btn-reset-astar` now starts `disabled` with "Waiting for ROS launch defaults..." tooltip, matching `btn-reset-config` / `btn-reset-perception` / `btn-reset-controller`.
- JS `gateResetButtons` — new `'btn-reset-astar': 'cfg-astar-resolution' in liveDefaults` entry. Single-key check sufficient: A\* params arrive atomically from `waypoint_planner_node`'s single `param_ranges` publish.
- JS click handler — captures liveDefaults values into a local `astarDefaults` map at click time, uses for both UI `.value` sets and the ROS-published `config`. No hardcoded literals; YAML is single source of truth as documented in `wiki/Design_Rationale.md` § "Why dashboard parameter defaults are 1-place".

### Outcome

- VFH lingering-hint bug fixed.
- VFH dropdown vs hint label mismatch fixed.
- A\* Reset migrated to liveDefaults and properly gated until `/planning/param_ranges` arrives.
- Bundled into single commit `7565242` (`fix(dashboard): tighten reset paths in Controller + A* config panels`).

## Launch-time timer + hw-dependence disclaimer (unplanned)

Maintainer asked for a small launcher addition: a wall-clock readout of total launch duration printed under the success banner, useful as an objective baseline for cold-vs-warm-boot comparisons (relevant once next week's RTF investigation begins).

### Implementation

Two-edit minimal change to `one_click_launch_all/launch_autoboat_complete.sh`:

- Right after `set -e` — capture `LAUNCH_START=$SECONDS` (bash auto-increments `$SECONDS` from script start).
- Right after `print_header "AutoBoat System Launched Successfully!"` — compute `LAUNCH_ELAPSED=$((SECONDS - LAUNCH_START))` and print `Total launch time: N s (Mm Ss) — varies with hardware/state` in green + yellow (matches the existing colour convention: green for success, yellow for caveats).

Total only, no per-stage breakdown. Format prints both seconds and `Mm Ss` so longer launches stay readable (e.g. `Total launch time: 95 s (1m 35s)`).

### First observation

`Total launch time: 52 s (0m 52s)` on a fresh launch on the Linux workstation post-feature-deploy. Single data point; ~12 s above the documented `~20-40 s` warm-machine range in `wiki/Common_Issues.md`. Possible contributors: the new `/wamv/sensors/lidars/lidar_wamv_sensor/points` gate added in `2c0194a` extends the readiness window vs pre-`2c0194a` runs, plus normal cold-vs-warm variance and asset-cache state. Not enough samples to revise the documented range yet — recorded in `Board.md` as a baseline data point.

### Disclaimer

Absolute timing varies meaningfully across hardware (CPU, GPU, disk I/O, asset-cache state, concurrent load), so both the print line and `wiki/Common_Issues.md:22` now make this explicit — the timer is for cold-vs-warm comparisons **on your own machine**, not as an absolute benchmark across machines.

### Outcome

- Launch-timer feature merged in `3822e54` (`feat(launch): print total launch time after success header`).
- Hardware-dependence disclaimer + Common_Issues prose + Board.md milestone row merged in `37e197c` (`docs+launch: disclaim hardware-dependence on launch-timer baseline`).
- New baseline data point recorded for the deferred RTF investigation (week of 04/05).

## Health-check disclaimer follow-on (unplanned)

Maintainer noted that the same hw-dependence applies to the `health_check_autoboat.sh` script — past experience shows full-check duration ~70-80 s under heavy multi-app load on the workstation, well above the documented `~30-60 s` typical range.

### Implementation

Single edit to `one_click_launch_all/health_check_autoboat.sh` (the Usage comment block). Documented typical range stays at `30-60 s` (warm-machine, light-load expectation); a 3-line variance note now follows, naming the contributors (CPU, ROS 2 daemon state, concurrent host load) and recording 70-80 s as the heavy-load upper-bound observation. `--quick` mode flagged as much less affected since it skips parameter and per-topic publisher probes.

### Audit

Cross-checked the wiki + README + USER_MANUAL + Board for other timing claims about the health-check shell script — none. The 49-checks count, the 4-state validation framework, the dashboard live-stream panel, and the `ros2 daemon` troubleshooting note all stay at a level of abstraction that doesn't commit to a duration. No other doc updates needed.

### Outcome

- Disclaimer comment merged in `a6792db` (`docs(health_check): note hardware-dependence of full-check duration`).
- Sibling-only update — no related docs needed touching.

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
- **Gazebo RTF investigation** — LiDAR `/points` throttled to ~2 Hz vs 10 Hz nominal (`install/share/vrx_gazebo/models/wamv/tmp/model.urdf:1212`); `libEGL warning: ... failed to create dri2 screen` on the NVIDIA RTX A2000 Laptop (PCI `10de:24b8`) is the working hypothesis. Pre-existing (independent of `2c0194a`); surfaced 29/04 cold-boot validation. **Pick up Mon 04/05 morning.** First diagnostic — `glxinfo | grep "OpenGL renderer"` cleanly distinguishes Mesa-software / Mesa-llvmpipe / NVIDIA active provider in one line; `sudo apt install mesa-utils` if `glxinfo` not present. Cross-check actual RTF with `ros2 topic hz /clock` (250 Hz nominal at 0.004 s timestep → sampled / 250 = RTF). From there: Mesa-active despite NVIDIA driver loaded → try `__GLX_VENDOR_LIBRARY_NAME=nvidia` or `prime-select nvidia`; llvmpipe (software) → driver issue, install matching `nvidia-driver-XXX`; NVIDIA active and fast but `/points` still 2 Hz → physics-bottleneck branch (CPU governor, `<physics><real_time_update_rate>`).
