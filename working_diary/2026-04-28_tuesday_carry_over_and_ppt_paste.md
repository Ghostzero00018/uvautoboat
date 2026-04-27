# 2026-04-28 — Tuesday: bug-fix carry-over + PPT slide paste + demo rehearsal

## Context

Pre-scaffold written 27/04 evening. Today consumes the carry-over verified at the end of 27/04's bug-finding day plus the first PPT-update-on-Windows session (per 27/04 diary's "Next steps for 28/04" section).

**Week shape recap (28/04 Tue → 30/04 Thu):**

- **Tuesday (today)** — Linux: clear today's not-fixed-yet list; demo rehearsal carry-over from Monday. Windows: paste new bucket-content into PPT; first speaker-note dry-run.
- **Wednesday (29/04)** — Final PPT polish; rehearsal pass 3 timed end-to-end; visual-asset placement; dry-run.
- **Thursday morning (30/04)** — Last-mile fixes; final dry run.
- **Thursday afternoon (30/04)** — Deliver.

**Why this isn't a free-for-all today:**

Monday (27/04) shifted from rehearsal-to-bug-finding because launching the dashboard surfaced a series of UX defects. 8 commits Monday landed those (`b3b8596` health-check service install, `5c388a6` hover unification, `81cc4d6` per-tab logs, `49b09ce` ppt_assets cleanup, `8f55fea` diary number correction, `f1f067e` Reset/dirty-marker, `bca4b0b` `(default: X)` extension, `8f7759b` diary fill). End-of-day verification surfaced 3 more confirmed-real bugs + 1 architectural-debt class (param_ranges 4-place sync). **Sunday-evening update:** rather than queue them for Tuesday, all 4 items were pre-applied Windows-side in 3 commits (`ffb7f8f` cli relative path / `74eb2b2` dashboard span refresh on programmatic mutations / `888fadd` option-1 param_ranges 3-tuple — Python publishers + JS consumer combined). Tuesday's Block A becomes pure verification — needs `colcon build` + relaunch, then exercise each path. None block Thursday — all are polish — but green Tuesday verification pushes Wednesday into pure PPT-on-Windows mode.

Active blocks for the day:

1. **Block A — Verification of pre-applied fixes** (~75 min, all changes already on `origin/main` as of Sunday evening): A1 cosmetic CLI + A3 four `updateValueDisplay()` patches + A2 verify-and-clean + A4 option-1 param_ranges 3-tuple consumer.
2. **Block B — PPT slide content paste on Windows** (~1.5 h): consume yesterday's bucket-restructured `paste_ready.md` into slides 2-6.
3. **Block C — Demo rehearsal (deferred from 27/04)** (~1 h): canonical happy-path; confirm clean.
4. **Block D — Quick verifications** (~30 min): C3 enumeration check; first-cold-launch warning capture (opportunistic).
5. **Block E — Wrap + diary fill-in**.

## Block A — Verification of pre-applied fixes

Recheck on 27/04 evening sharpened the original scope; all fixes were then **pre-applied Windows-side Sunday evening** rather than queued for Tuesday. Tuesday's Block A is verification only — exercise each path against the post-pull tree.

> **Pre-application status (Sunday evening, all on `origin/main`):**
>
> - `ffb7f8f` — A1 cli relative path (drops install-broken `parents[2]` `_REPO_ROOT`)
> - `74eb2b2` — A3 four `updateValueDisplay()` patches in `resetGroupToDefaults` / A*Reset / `updatePerceptionInputs` / `updateControllerInputs` / `updateConfigFromROS` cfg-* loop
> - `888fadd` — Option 1 param_ranges 3-tuple — Python publishers (3 nodes) extend payload to `[min, max, default]`; dashboard consumer adds `liveDefaults` map + extends `getCanonicalDefault` to consult it first; legacy fallbacks (HTML `data-default`, JS `*_DEFAULTS` constants) intact for safety
>
> All 3 commits are additive and forward-compatible: legacy 2-tuple `param_ranges` still works on the JS side, and Python's pre-3-tuple publish would still work on the original JS side. Risk on revert is bounded — a single commit revert per fault.
>
> **Recheck note (27/04):** original A2 ("3 missing wirings") was based on reading `initConfigValueTracking()` only. Recheck found the 3 inputs ARE wired via `allConfigInputs` at `app.js:1432-1459` — wiring is universal across all 43 parameter inputs. The actual bug is in 4 PROGRAMMATIC-MUTATION paths that each set `el.value` without firing `updateValueDisplay()`. A2 becomes a quick verify-and-cleanup; A3 becomes 4 one-line patches.

### A1 — `autoboat_cli.py:83` cosmetic install-path defect (5 min)

Same `parents[2]` defect that `b3b8596` fixed in `health_check_service.py`. Confirmed: `plan/plan/autoboat_cli.py:83` has `_REPO_ROOT = Path(__file__).resolve().parents[2]`; affects print statements at L277 and L541 (both use `_LAUNCH_FILE`). Cosmetic only — the path is wrong only in *visible help text*, not in actual behaviour.

```bash
cd ~/seal_ws/src/uvautoboat
grep -n "_LAUNCH_FILE\|_REPO_ROOT" plan/plan/autoboat_cli.py
```

Two fix options:

1. **Mirror `b3b8596`'s pattern** — use `ament_index_python.packages.get_package_share_directory('plan')` to locate the launch file.
2. **Drop `_LAUNCH_FILE` entirely** — replace with a literal launch-command string in the print statements (`"ros2 launch autoboat_bringup autoboat.launch.yaml"` or whatever the canonical form is). The user just needs to know WHAT to type, not WHERE the file is.

Option 2 is simpler. Pick option 2 unless the variable is referenced elsewhere.

Commit suggestion: `fix(cli): drop install-layout-broken _LAUNCH_FILE; use literal launch command in help text`

**Outcome.** [To fill]

### A2 — Verify A2 obsolescence + decide on `initConfigValueTracking` cleanup (5-10 min)

Per recheck, the originally-claimed "3 missing wirings" turn out to already be wired via `allConfigInputs` (`app.js:1432-1459`). Quick read-and-decide:

```bash
cd ~/seal_ws/src/uvautoboat
# Confirm allConfigInputs covers the 3 inputs
grep -nA12 "const allConfigInputs" web_dashboard/autoboat/app.js | head -20
# Confirm the 3 IDs (cfg-waypoint-tolerance, cfg-approach-slow-distance, cfg-approach-slow-factor) are in the array
```

Two outcomes:

1. **Confirmed wired** (expected) — `initConfigValueTracking()` at `app.js:1629-1656` is now redundant with `allConfigInputs`. Either:
   - **(a) leave as-is** — duplicate listener attachment is harmless (idempotent calls); land A3 instead.
   - **(b) delete** — drop `initConfigValueTracking()` + its single caller. Cleaner code; ~10 lines removed.
2. **Not actually wired** — resurrect the original A2 task: extend `configInputs` array in `initConfigValueTracking()` to include the 3 missing inputs.

**Default route:** option 1(a) — verify and skip. Option 1(b) lands later in the post-30/04 cleanup pass. Option 2 only if recheck was wrong.

Commit suggestion (only if 1(b) chosen): `refactor(dashboard): drop redundant initConfigValueTracking — allConfigInputs covers all 43 inputs`

**Outcome.** [To fill]

### A3 — Four `updateValueDisplay()` calls in programmatic-mutation paths (30-45 min)

Recheck revealed the user-reported bug isn't in dirty-tracker semantics — it's that 4 code paths mutate input values programmatically (`el.value = X`) without calling `updateValueDisplay(el)`. Programmatic value sets don't fire the `input` event, so the existing listener at `app.js:1453-1459` never runs. Result: orange `(default: X)` span persists indefinitely.

**The four broken paths:**

| # | Function | Location | What it skips |
|:---:|:---|:---|:---|
| 1 | `resetGroupToDefaults` | `app.js:1608-1615` | `updateValueDisplay(el)` + `classList.remove('modified')` inside loop |
| 2 | A* Reset block | `app.js:1521-1542` | `updateValueDisplay(el)` for each of 3 inputs after `.value =` |
| 3 | `updatePerceptionInputs` / `updateControllerInputs` | `app.js:3075-3088, 3094-3115` | `updateValueDisplay(el)` per input after `el.value = preset[id]` |
| 4 | `updateConfigFromROS` perception/controller branch | `app.js:1692-1796` | `updateValueDisplay(el)` after `el.value = data[…]` for tuning IDs |

`resetConfigToDefaults` at `app.js:1566-1585` is the ONE path that does it right (calls `updateValueDisplay(input)` at L1580). The 4 broken paths just need to mirror its pattern.

**Two fix options:**

1. **Inline (4 spot patches)** — add `updateValueDisplay(el)` (and `el.classList.remove('modified')` for path 1) at each site. ~15 lines of diff, very targeted.
2. **Helper-based** — introduce module-level `setInputValueAndNotify(el, value)`:

   ```js
   function setInputValueAndNotify(el, value) {
       if (!el) return;
       el.value = value;
       updateValueDisplay(el);
   }
   ```

   Then replace `el.value = X` in all 4 paths with `setInputValueAndNotify(el, X)`. DRY, but more touch surface.

**Recommendation:** option 1 (inline) for the Tuesday slot — tighter diff, less risk of subtle regression. Option 2 is post-30/04 polish.

**Bug investigation FIRST:** before patching, reproduce the bug on a `cfg-*` input (kp / ki / kd / base-speed / max-speed / safe-dist). `resetConfigToDefaults` already calls `updateValueDisplay`, so if cfg-*Reset ALSO leaves the span persistent, there's a deeper bug we haven't found. If cfg-* Reset clears correctly, the user was testing a perception-*/ controller-* input and the 4-path fix is sufficient.

**Test sequence (after each path is patched):**

- **Path 1 (resetGroupToDefaults):** edit `perception-water-threshold` off-default → orange span appears → click *Reset Perception* → confirm value AND span both clear.
- **Path 2 (A* Reset):** edit `cfg-astar-resolution` off-default → click *Reset A\** → confirm.
- **Path 3 (preset apply):** apply Pier preset → confirm tuning inputs that match preset values show no orange span; ones that differ from launch defaults DO show it.
- **Path 4 (updateConfigFromROS):** harder to test cleanly; trust symmetry with cfg-* path.

If implementation overruns 45 min, **stop and roll to Wednesday** — A3 is polish, not blocking. Don't sacrifice Block B time for it.

Commit suggestion: `fix(dashboard): call updateValueDisplay() in 4 programmatic-mutation paths`

**Outcome.** [To fill]

### A4 — Option 1 param_ranges 3-tuple verification (15-20 min)

Pre-applied via `888fadd`. Eliminates the 4-place sync drift class for default values: Python now publishes `[min, max, default]` per param; dashboard consumes via a `liveDefaults` map; `getCanonicalDefault` consults `liveDefaults` first, falls back to legacy HTML `data-default` + `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` constants.

**Prereq:** `colcon build --packages-select plan control` + relaunch (the new Python publisher is what populates `liveDefaults` on the dashboard side).

**Verification sequence:**

1. **DevTools console after dashboard connects (~5s after page load):**

   ```js
   liveDefaults
   // Expect: object with ~30+ entries — cfg-kp, cfg-ki, cfg-kd, cfg-base-speed, ...,
   // perception-min-height, ..., controller-critical-dist, ...
   // If empty {} → Python publish didn't deploy; legacy fallbacks kicking in (still functional)
   ```

2. **Live-default flow sanity test:**

   - In the dashboard, edit `cfg-kp` from 500 → 600
   - Orange `(default: 500)` hint should appear under the input
   - Verify in DevTools: `getCanonicalDefault(document.getElementById('cfg-kp'))` returns `500`

3. **End-to-end YAML-as-truth test (transient, optional but conclusive):**

   - Edit `launch/autoboat.launch.yaml` → change `kp` default from 500 to 555 (transient)
   - Ctrl+C launcher, relaunch
   - In dashboard, edit `cfg-kp` from 555 to 600
   - Orange hint should now read `(default: 555)` — proving the chain `YAML → Python._launch_defaults → /control/param_ranges → liveDefaults['cfg-kp'] → getCanonicalDefault` works
   - **Revert YAML to 500**, relaunch, confirm hint returns to `(default: 500)`

**Pass criteria:** step 1 shows a populated `liveDefaults` AND step 2 shows the `(default: 500)` hint matching the YAML default. Step 3 is the strong end-to-end proof — run it if you have the time, skip if Block C is calling.

**Fail handling:** if step 1 shows empty `liveDefaults`, the dashboard auto-falls-back to legacy paths — no user-visible breakage. Bug is in Python publish (most likely the 3-tuple JSON serialization or lazy-capture timing). Investigate: `ros2 topic echo /control/param_ranges --once` to see what's actually being published. If the topic shows 2-tuples, the build didn't pick up the Python edit (re-run `colcon build`). If it shows 3-tuples but `liveDefaults` stays empty, JS-side bug — `console.log` inside `applyRangesToDashboard` to trace.

Commit suggestion (only if a fix is needed): `fix(nodes): <specific issue>` or `revert 888fadd` if the fault is irrecoverable on the day.

**Outcome.** [To fill]

## Block B — PPT slide content paste on Windows

Open `E:\IMT_dossier\DMI_Semester_3\Research_intern_IMT_NE\PPT\PPT_files\30_04_2026_presentatioin\AutoBoat_PPT_Intern_30_04_2026.pptx` and consume the bucket-restructured content from `assets/2026-04-30_slide_paste_ready.md`.

Order:

1. **Slide 1** — overwrite existing minimal title with the dual-school + French subtitle + 6-month duration block (paste-ready file has 8 separate code blocks; paste each into its placeholder).
2. **Slide 2** — replace existing 5-bullet OUTLINE with new bucket labels (`Naming & architecture cleanup` / `Dashboard maturity` / `Reliability tier` / `Diagnostics & Hardware-Deployment Prep` / `Mission Demo + Asks + Future Work`).
3. **Slide 3** — wipe existing OKO-SPUTNIK-BURAN Project Overview content (legacy names!). Paste new "Naming & architecture cleanup" body.
4. **Slide 4** — currently title-only. Paste "Dashboard maturity" body bullets.
5. **Slide 5** — currently title-only. Paste "Reliability tier" body bullets.
6. **Slide 6** — currently title-only. Paste "Diagnostics & Hardware-Deployment Prep" body bullets.
7. **Slide 7** — currently title-only with `+`. Update title to `Mission Demo + Asks + Future Work`. Paste 3-section body (Demo / Asks / Future Work).
8. **Slide 8** — already done; QR code addition is optional polish.

**Speaker notes** (View → Notes pane): paste bilingual EN + 中文 blocks for each of slides 2-7. 12 notes total (6 slides × 2 languages).

**Visual placeholders** — leave empty today; Wednesday handles asset placement:

- Slide 3: `git_diff_stat_rename_commit.png` + small three-layer thumbnail (drawn in PPT)
- Slide 4: dashboard screenshot grid (camera combobox / Tier A/B/C / toasts / hover)
- Slide 5: PID + Kalman block diagram + E-Stop before/after (drawn in PPT)
- Slide 6: health-check + rate_probe terminal + topology diagram + (optional) MP main UI
- Slide 7: demo video / live placeholder

**Speaker-note dry-run** (after paste): read each slide's note aloud, time roughly. Aim ~3 min per content slide → 15 min for slides 3-7. Title + outline + thanks ~1 min each → 18-20 min total spoken time before transitions. If overrunning, mark which bullets to cut on Wednesday.

**Outcome.** [To fill]

## Block C — Demo rehearsal (deferred from 27/04)

Carried over from yesterday's deferred Block B. Run the canonical happy-path from boot to mission completion.

Verify on `sydney_regatta_DEFAULT`:

- Launcher cold start completes cleanly (~20-40 s on this host).
- Dashboard connects, state updates flow, log panel populates.
- Generate Waypoints → Confirm → Start cycle works; boat navigates without regression.
- Emergency Stop latches correctly; Resume recovers; Reset clears cleanly when not in `WAITING_CONFIRM`.
- Spot-check the new-since-15/04 features for demo-worthiness:
  - Camera combobox (auto-discovery dropdown)
  - Unified debounce cooldown visual on mission-control buttons
  - Reset-blocked toast during Confirm window
  - Go-Home-at-home toast at spawn
  - `TUNED` state chip in health check after a preset-apply
  - `rate_probe.py` side-by-side with `ros2 topic hz` (terminal screenshot — better for slide than live)
  - **NEW post-A3:** orange `(default: X)` span clears immediately after *Reset Perception* / *Reset Controller* (was the user-reported bug)
  - **NEW post-A3:** orange `(default: X)` span clears immediately after preset apply (Pier / Buoy Field / etc.)
  - **NEW post-A3:** orange `(default: X)` span clears after ROS-side config update (e.g., reload or external `set_parameters`)
  - **NEW post-A4:** orange `(default: X)` hint VALUES come from YAML via `/<ns>/param_ranges` topic (verify `liveDefaults` is populated in DevTools); editing a YAML default + relaunching changes the hint accordingly

Live-demo shortlist: pick 1-3 features for Thursday. Estimate live-demo minutes (target: 3-5 min if live; ≤2 min if pre-recorded).

**Outcome.** [To fill — list of demo-worthy features picked, any regressions surfaced, estimated live-demo minutes]

## Block D — Quick verifications

### D1 — C3 enumeration check (1 min)

Yesterday's verification couldn't decide whether commit `3389554` is "two C-class fixes" (by mechanism: bad-JSON helper + reverse-to-turn latch) or "three" (by call site: bad-JSON in `heading_controller`, bad-JSON in `lidar_perception`, latch in `waypoint_planner`). Slide 5 currently says "C-class bug fixes" without a count.

```bash
cd ~/seal_ws/src/uvautoboat
git show 3389554
```

If the diff shows 3 distinct logical changes (e.g. each subscriber's `_log_bad_json` is structurally different, plus the latch is a separate concept), update Slide 5 paste-ready to "three C-class bug fixes" and list them. If it's really one helper applied to two sites + the latch fix (= 2 mechanisms), leave the slide as-is — "C-class bug fixes" without enumeration is honest.

**Outcome.** [To fill — count decision + Slide 5 update if needed]

### D2 — First-cold-launch warning capture (opportunistic)

Per `81cc4d6` deployed yesterday, per-tab logs go to `/tmp/autoboat_tab_<name>.log`. The first-of-day yellow warning needs a genuine cold boot to reproduce — `drop_caches + ros2 daemon stop` didn't trigger it on 27/04 (SSD page cache likely refilled too fast).

If the first launch of the day surfaces the warning, capture:

```bash
cat /tmp/autoboat_tab_perception.log | head -30
# Or whichever tab showed the warning
```

Save as `launcher_per_tab_log.png` in `Research_intern_IMT_NE\PPT\PPT_files\30_04_2026_presentatioin\assets\`.

If the warning doesn't surface today either: drop the planned Slide 6 secondary-visual mention; the per-tab logs are still a real win regardless of whether the screenshot lands.

**Outcome.** [To fill — captured / not captured]

## Block E — Wrap + diary fill-in

1. `git log --oneline -5` — sanity check the day's commits landed cleanly.
2. Pre-commit scan: zero matches expected.
3. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
4. Add 28/04 milestone row to `Board.md` only if A1+A2+A3 lands cleanly (one row noting "carry-over fixes + PPT slide-content paste").
5. On the Windows laptop, append today's section to `Research_intern_IMT_NE/working_diary/Week8_27_04-01_05.md`.
6. Commit:

   ```bash
   git add working_diary/2026-04-28_tuesday_carry_over_and_ppt_paste.md Board.md
   git commit -m "docs: fill 28/04 working diary with day's outcomes"
   git push
   ```

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | A1 + A3 + A4 verified clean (all pre-applied Sunday); A2 confirmed obsolete | Wed picks up demo rehearsal + PPT |
| Block B | Slides 2-6 content + speaker notes pasted | Wed = visual placement + dry-run timing |
| Block C | Demo rehearsed clean | Wed = visual placement only |
| Block D | C3 verified, optional cold-launch capture | (no rollover — both are one-shots) |
| Block E | Day closed | Wed opens fresh on PPT visual placement |

## Known unknowns surfaced during the day

Use this section to capture anything surprising during the day — file state drift, unexpected behaviour, migration caveats. Each entry: `file:line` or command + observation + fix or follow-up.

- [To fill]

## Next steps — concrete plan for 29/04

[To fill at end of day with actual carry-overs and shortlist refinements.]

### Actionable on 29/04 (Wednesday)

- **PPT visual placement** — drop screenshots / PPT-drawn diagrams into placeholders on each slide. Use Block C visual-asset checklist (in `2026-04-30_slide_outline.md`).
- **Speaker-note timing pass** — read each slide note aloud, time end-to-end, adjust pacing; aim 22-26 min total.
- **Rehearsal pass 3** — full end-to-end with Windows-side deck open in front of you. Bilingual where natural; English-primary for the formal delivery.
- **Carry-over from 28/04:** whichever of Blocks A / B / C didn't land or needs follow-up.
- **Wednesday-evening dry-run** — final review checklist from `2026-04-30_slide_outline.md` (10 items including no-ellipsis check, visual motif consistency, asks-box highlighting, QR scan test).

### Blocked / deferred (not this week)

- **P1 pier/bank stuck investigation** — deferred until after Thursday meeting; diagnostic plan preserved in 24/04 diary's Block A section.
- **Mock water quality sensor implementation** — blocked on supervisor conversation; addressed via Slide 7 ask.
- **Real no-regression test for `launch/remap.launch.yaml`** — needs first real-hardware bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** — later integration milestone (post-real-hardware-bringup).
- **Option-1 cleanup sweep** — once option-1 is verified working (A4), the legacy fallbacks in `getCanonicalDefault` (HTML `data-default` attrs + `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` JS maps) become redundant code. Cleanup is non-blocking (current code is correct, just has belt-and-braces); queue for post-Thursday.
- **Housekeeping carry-overs from 24/04** — `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Both bumped post-Thursday; rainy-day.
- **`update-pip-graph` GitHub Actions Node 20 deprecation** — server-side, auto-resolves June 2026; no action needed.
