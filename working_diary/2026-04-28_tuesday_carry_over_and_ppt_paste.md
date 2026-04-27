# 2026-04-28 — Tuesday: bug-fix carry-over + PPT slide paste + demo rehearsal

## Context

Pre-scaffold written 27/04 evening. Today consumes the carry-over verified at the end of 27/04's bug-finding day plus the first PPT-update-on-Windows session (per 27/04 diary's "Next steps for 28/04" section).

**Week shape recap (28/04 Tue → 30/04 Thu):**

- **Tuesday (today)** — Linux: clear today's not-fixed-yet list; demo rehearsal carry-over from Monday. Windows: paste new bucket-content into PPT; first speaker-note dry-run.
- **Wednesday (29/04)** — Final PPT polish; rehearsal pass 3 timed end-to-end; visual-asset placement; dry-run.
- **Thursday morning (30/04)** — Last-mile fixes; final dry run.
- **Thursday afternoon (30/04)** — Deliver.

**Why this isn't a free-for-all today:**

Yesterday (27/04) shifted from rehearsal-to-bug-finding because launching the dashboard surfaced a series of UX defects. 8 commits today landed those (`b3b8596` health-check service install, `5c388a6` hover unification, `81cc4d6` per-tab logs, `49b09ce` ppt_assets cleanup, `8f55fea` diary number correction, `f1f067e` Reset/dirty-marker, `bca4b0b` `(default: X)` extension, `8f7759b` diary fill). End-of-day verification surfaced 3 more confirmed-real bugs that are small enough to clear before tomorrow's demo rehearsal stays clean. None block Thursday's slot — they're polish — but a clean rehearsal Tuesday pushes Wednesday into pure PPT-on-Windows mode.

Active blocks for the day:

1. **Block A — Dashboard / code carry-over fixes** (~1.5 h): three confirmed bugs from 27/04 verification.
2. **Block B — PPT slide content paste on Windows** (~1.5 h): consume yesterday's bucket-restructured `paste_ready.md` into slides 2-6.
3. **Block C — Demo rehearsal (deferred from 27/04)** (~1 h): canonical happy-path; confirm clean.
4. **Block D — Quick verifications** (~30 min): C3 enumeration check; first-cold-launch warning capture (opportunistic).
5. **Block E — Wrap + diary fill-in**.

## Block A — Dashboard / code carry-over fixes

Three real bugs verified at end of 27/04 against the post-`bca4b0b` baseline. Each is small. Time-box A1+A2+A3 to 1.5 h total — overruns mean A3 (the bigger one) stays for Wednesday.

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

### A2 — 3 missing `.modified` class wirings in `initConfigValueTracking()` (15 min)

`web_dashboard/autoboat/app.js:1629` `initConfigValueTracking()` only wires 6 inputs. Three missing: `cfg-waypoint-tolerance` / `cfg-approach-slow-distance` / `cfg-approach-slow-factor`. Without the wiring, those inputs don't get the orange `.modified` border on user modification.

```bash
# Open app.js at L1629-1656; extend the configInputs array from 6 entries to 9:
#     'cfg-kp', 'cfg-ki', 'cfg-kd',
#     'cfg-base-speed', 'cfg-max-speed', 'cfg-safe-dist',
#     'cfg-waypoint-tolerance', 'cfg-approach-slow-distance', 'cfg-approach-slow-factor',
```

Verification: open dashboard; nudge `cfg-waypoint-tolerance` off-default; confirm orange `.modified` border appears. Repeat for the other two.

Commit suggestion: `fix(dashboard): wire .modified class for 3 missing tuning-panel inputs`

**Outcome.** [To fill]

### A3 — `lastApplied` per-input dirty-tracker refactor (45-60 min)

The bigger one. Current dirty-marker compares input value to `data-default` (launch-time HTML attribute). Real semantics: dirty if input differs from **last value successfully applied to ROS**, not from launch default.

Failure mode confirmed yesterday: user applies non-default → ROS holds non-default; user reverts input to launch default → marker clears (incorrect — ROS still has old value, input/ROS state mismatch is silent). Or: user lands at default first time, marker clears, but ROS has different prior value if config sync hasn't happened.

Reading scope:

- `app.js:1629-1656` — current `initConfigValueTracking()` dirty tracker
- Apply button click handler (grep `Apply` or `sendConfig` for the publish path)
- `updateConfigFromROS` — first ROS config sync hook

Approach:

1. Add module-level `const lastAppliedValues = new Map();` keyed by input id.
2. On successful Apply (after the ROS publish), iterate config inputs and write `lastAppliedValues.set(id, currentValue)`.
3. In the dirty-tracker `input` event listener, compare `currentValue` against `lastAppliedValues.get(id) ?? input.dataset.default` (fallback to launch-default for inputs that haven't been Applied yet).
4. Initialize `lastAppliedValues` on first ROS config sync (around `updateConfigFromROS`).

Time-box: 45 min for implementation + 15 min for manual test. Test sequence:

- Apply a non-default value → confirm `.modified` clears (matches lastApplied).
- Revert input to launch default → confirm `.modified` STAYS ON (input now differs from lastApplied).
- Re-Apply (now default) → confirm `.modified` clears (lastApplied = default = current).

If implementation overruns 60 min, **stop and roll to Wednesday** — A3 is polish, not blocking. Don't sacrifice Block B time for it.

Commit suggestion: `fix(dashboard): track lastApplied per-input for accurate dirty-marker semantics`

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
  - **NEW post-A2:** `.modified` border on 3 newly-wired tuning inputs
  - **NEW post-A3:** dirty-marker correctly clears on Apply, persists on revert-to-default

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
| Block A | 3 dashboard / CLI fixes shipped | Wed picks up demo rehearsal + PPT |
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
- **`param_ranges` topic doesn't publish defaults** — 4-place sync (YAML + `index.html` + `app.js` + Python) is real architectural debt; post-30/04 work item.
- **Housekeeping carry-overs from 24/04** — `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Both bumped post-Thursday; rainy-day.
- **`update-pip-graph` GitHub Actions Node 20 deprecation** — server-side, auto-resolves June 2026; no action needed.
