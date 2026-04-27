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

**Outcome.** 5 themed slide groups landed (Naming/architecture cleanup; Dashboard maturity; Reliability tier; Diagnostics & Hardware-Deployment Prep; Mission Demo + Asks + Future Work), fed into the Windows-side PPT draft this afternoon. ~5 new content slides since the 15/04 deck (collapses to 3 if "Diagnostics" + "Reliability" merge). Three themes emerged: (1) **Observability first** — TUNED state, JSON schema guards, per-tab logs, rate probing, 4-state health check, dashboard validation rejection; (2) **Dashboard as a first-class subsystem** — helpers consolidation, security hardening, defensive toasts, hover unification; (3) **Phase 5 framing** — `remap.launch.yaml`, MP/QGC tooling, perception publish-rate baseline. Parked: detail-level commits (individual tooltips, JSON-parse hardening), diary scaffolding, Vostok1 breadcrumb cleanup. Number-correction round-trip via `8f55fea`: "26 files / ~1,100 refs" → "30 files, +1,099 / −1,398 lines" after `git diff --stat 39b5a6e` verification.

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

**Outcome.** Demo rehearsal deferred to Tuesday morning — day shifted to **bug-finding during simulation testing**. Five emergent fixes shipped today:

| Commit | Surface | Summary |
|:-------|:--------|:--------|
| `b3b8596` | Health Check service install path | `Path(__file__).resolve().parents[2]` worked from source but resolved 3 levels too short under colcon install layout, producing the dashboard error `Health check script not found at /home/ghostzero/seal_ws/install/lib/python3.12/...`. Fix: `ament_index_python.get_package_share_directory('plan')` + script installed as package data via `setup.py` `data_files`. |
| `5c388a6` | Dashboard main-panel hover style | 5 mission buttons had no `:hover` rule at all (Joystick on/off, Confirm, Cancel, Resume); 5 large CTAs used `scale()` zoom, tuning Reset used bg-only — visually mismatched with paired Apply. Universal Pattern A (`translateY(-2px)` + colored shadow) applied across all main-panel buttons. |
| `81cc4d6` | Per-tab launcher logs | Each `gnome-terminal` tab tees stdout/stderr to `/tmp/autoboat_tab_<name>.log`; `rm -f` at launcher start handles skip-flag stale-log edge case. Cold-simulate (`drop_caches` + `ros2 daemon stop`) didn't reproduce the first-of-day yellow warning — likely SSD page cache refilled too fast. Capture pending next genuine cold boot. |
| `f1f067e` | Reset → Apply UX + dirty marker | Reset is now confirm + reset + apply in one step (Option B); A* Reset gained the missing confirm dialog. Dirty marker: drop focus-only trigger (was firing on click without edit); revert-to-default now clears the orange marker; 6 missing `data-default` attrs added (`wp-*` + `cfg-astar-*`). |
| `bca4b0b` | `(default: X)` hint extended | Indicator was scoped to 6 `cfg-*` inputs only; now all parameter inputs (perception, controller, A*, waypoint, VFH select) show the orange hint when modified. Refactored `updateValueDisplay` via `getCanonicalDefault` + new `ensureValueDisplay` helper that creates the value-display sibling on the fly. |

No live-demo shortlist drafted yet — that work moves to Tuesday's actual rehearsal.

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

**Outcome.** Capture work deferred. Synthetic artefacts (`changelog_since_15-04.md` + `CHECKLIST.md`) were created mid-day under `ppt_assets/2026-04-30/`, then removed (commit `49b09ce`) once the maintainer decided PPT artefacts stay Windows-side; the diary itself updated in the same commit to drop the `mkdir -p ppt_assets/2026-04-30` line and point at the Windows-side flow. No PNG / terminal / MP4 captures today — Block B's deferral pulled Block C with it. Block A's bullet content fed the Windows-side slide draft directly instead.

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

- **First-cold-launch warning still uncaptured** — user reports a yellow `print_warning` text on first-of-day launches that quiets on subsequent runs; phrased as "ros2 has error" by the user. Cold-simulate (`sync && echo 3 | sudo tee /proc/sys/vm/drop_caches` + `ros2 daemon stop`) didn't reproduce on this Linux workstation; SSD page cache likely refilled too fast. Per-tab logs (`81cc4d6`) now in place at `/tmp/autoboat_tab_<name>.log`; capture pending next genuine first-of-day launch.
- **`update-pip-graph` GitHub Actions deprecation warning** — Node 20 deprecation on GitHub-managed `github/dependabot-action@main`, fires only on Dependabot-attributed events. Server-side workflow, not in our repo (only `sync-wiki.yml` is ours, uses `actions/checkout@v6`). Auto-resolves by 2 June 2026 per GitHub's cutover. No action needed.
- **C3 specifics in commit `3389554`** — diary's themed grouping says "C1/C2/C3 bug fixes" but the slide draft (Windows-side) describes only two specifics (`_log_bad_json` propagation + `force_turn_after_reverse` persistence). Run `git show 3389554` Tuesday before finalizing the slide bullet.
- **Revert-to-applied-non-default edge case** in dirty tracker — `getCanonicalDefault()` compares to launch default, not last-value-sent-to-ROS. After applying a non-default value, manually reverting to default clears the orange marker but ROS state is unchanged → silent mismatch in this narrow scenario. Proper fix: per-input `lastApplied` tracker (~30 LOC). Deferred.
- **`autoboat_cli.py:83` cosmetic install-path bug** — same `parents[2]` defect as the health-check fix, affects only user-facing print messages at lines 277 and 541. Class-instance pair; deferred.
- **3 `.modified`-class wirings missing** in `initConfigValueTracking()` — `cfg-waypoint-tolerance`, `cfg-approach-slow-distance`, `cfg-approach-slow-factor` have value-display spans in HTML but aren't in the init loop's `configInputs` array. Pre-existing bug. Deferred.

## Next steps — concrete plan for 28/04

Today wrapped: 7 commits shipped on `main`, all simulation-tested. Block A done and fed the Windows-side PPT draft; Blocks B + C carry to Tuesday morning. Emergent bug-fix work consumed the afternoon (5 dashboard / launcher fixes — see Block B outcome table). See the actionable list below for Tuesday's order of operations.

### Actionable on 28/04 (Tuesday)

**Morning — Linux side:**

- **Block B — Demo rehearsal** (~1.5 h): canonical happy-path on `sydney_regatta_DEFAULT`. Verify no regressions since the 15/04 demo. Spot-check the new-since-then features (camera combobox, unified debounce visual, Reset-blocked toast, Go-Home-at-home toast, `[TUNED]` chip after a preset-apply, `rate_probe.py`). Draft live-demo shortlist (1-3 features) + estimated live-demo minutes for Thursday timing.
- **Block C — Visual capture during/after the demo** (~45 min): 6 GUI PNGs (dashboard main view post-23/04, health-check IDLE + ACTIVE-with-preset, Reset-blocked toast, Go-Home-at-home toast, `Board.md` timeline rendered in the GitHub web view) + 2 terminal captures (`rate_probe.py --reliability reliable --duration 20 --topic /perception/obstacle_info` next to `ros2 topic hz /perception/obstacle_info`). Land directly in the Windows-side PPT assets folder.
- **First-cold-launch warning capture**: if Tuesday's launch is the first since reboot, run `grep -iE 'warn|error|fail|deprecat' /tmp/autoboat_tab_*.log` immediately after the launch banner. The per-tab logs deployed in `81cc4d6` should now contain whatever yellow text was previously eluding capture.
- **C3 spot-check**: `git show 3389554` to identify the third bug fix in the C-class commit. The slide draft (Windows-side) currently describes only two specifics (`_log_bad_json` + `force_turn_after_reverse`) — confirm the third or soften the slide bullet to "two C-class bugs" before finalizing.

**Afternoon / evening — Windows side:**

- **PPT updates**: consume today's changelog bullets + Block C captures into slides 2-6. Speaker-script additions mirror slide content (bilingual EN + 中文 per convention).
- **Rehearsal pass 2**: timed run with the updated deck, Tuesday evening.

**Optional follow-ups (post-deck or rainy-day):**

- **`lastApplied` per-input dirty-tracker refactor** (~30 LOC, `web_dashboard/autoboat/app.js`). Today's `getCanonicalDefault(el)` compares an input's value to its **launch default**; the architecturally-correct semantic is "differs from what's **currently on ROS**". After applying a non-default value, manually reverting the field to launch default clears the orange marker but ROS state is unchanged → silent dashboard ↔ ROS mismatch in this narrow scenario.
  - **Implementation sketch:** add `const lastApplied = new Map()` keyed by input ID. Initialize each entry from `getCanonicalDefault(el)` on page load (in the `allConfigInputs.forEach` loop). Update from inside `markClean(ids)` after a successful Apply (read each input's current value, store as `lastApplied.get(id)`); also update from the config-from-ROS sync path around `app.js:1722` whenever `el.value` is overwritten by an incoming config message.
  - **Rename / rewire:** `isAtCanonicalDefault()` → `isAtAppliedValue()`, compares against `lastApplied.get(el.id)` instead of `getCanonicalDefault(el)`. `updateValueDisplay()` keeps using `getCanonicalDefault()` (the `(default: X)` hint is intentionally about launch default, not last-applied).
  - **Test:** apply a non-default value via Apply; manually revert the field to its launch default; orange marker should now stay (was incorrectly clearing today).

- **`autoboat_cli.py:83` cosmetic install-path fix** — same `parents[2]` defect as today's health-check fix (`b3b8596`). Affects only user-facing print sites at `autoboat_cli.py:277` (`"Start with: ros2 launch {_LAUNCH_FILE}"`) and `:541` (`"ros2 launch {_LAUNCH_FILE}"`). When run via `ros2 run plan autoboat_cli`, `_LAUNCH_FILE` resolves to a non-existent path under `install/lib/python3.12/launch/...` and the printed launch instruction is wrong (cosmetic — nothing breaks, but copy-pasting the printed path fails).
  - **Cleanest fix:** mirror today's pattern (`b3b8596`). Edit `plan/setup.py` `data_files` to install `launch/*.yaml` as plan package data (e.g. `(os.path.join('share', package_name, 'launch'), glob('../launch/*.yaml'))`). Update `autoboat_cli.py` to look up via `Path(get_package_share_directory('plan')) / 'launch' / 'autoboat.launch.yaml'`. Then print as the pkg-relative form `ros2 launch plan autoboat.launch.yaml` instead of an absolute path. ~10 LOC across 2 files; rebuild required.
  - **Alternative (smaller):** keep the absolute-path style but use the same `get_package_share_directory` lookup, adjusting the printed string accordingly. Saves the data_files entry but leaves the user with a longer absolute path to copy-paste.

- **3 `.modified`-class wirings missing in `initConfigValueTracking()`** (`web_dashboard/autoboat/app.js:~1614`). Three inputs in the Advanced Configuration panel — `cfg-waypoint-tolerance`, `cfg-approach-slow-distance`, `cfg-approach-slow-factor` — already have `<span class="value-display"></span>` siblings in HTML (`index.html:552, 560, 568`) but aren't in the function's `configInputs` array (which only lists the 6 PID + speed + safe-dist inputs).
  - **Effect today:** since `bca4b0b`, the `(default: X)` text DOES appear for them (via the broader `updateInputDirtyState` path that I wired tonight). But the `.modified` class — which adds the orange border + light-orange background via `.config-item input.modified` at `style_merged.css:~1335` — stays absent. So the visual is asymmetric: the 3 missing inputs show only `.input-dirty`'s thin orange contour + the `(default: X)` hint, while the 6 wired inputs show all three layers (`.input-dirty` + `.modified` + `(default: X)`).
  - **Fix:** 3-line addition — append `'cfg-waypoint-tolerance', 'cfg-approach-slow-distance', 'cfg-approach-slow-factor'` to the array at `app.js:~1616`. Or better: drop the `.modified`-class duplication entirely and merge the orange-border styling into a single CSS rule keyed on `.input-dirty`, which already covers all parameter inputs uniformly. The duplication is pre-existing (predates today's work) and low-impact, but the CSS unification is the cleaner long-term fix.

### Blocked / deferred (not this week)

- **P1 pier/bank stuck investigation** — deferred until after Thursday meeting; diagnostic plan preserved in 24/04 diary's Block A section.
- **Phase A implementation (mock water quality sensor)** — blocked on supervisor conversation.
- **Real no-regression test for `launch/remap.launch.yaml`** — Phase 5.1 bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** — Phase 5.2+ scope.
- **Housekeeping follow-ups from 24/04 Known-unknowns** — mono-xsp4 port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`. Both bumped out of this week; rainy-day items for post-Thursday.
