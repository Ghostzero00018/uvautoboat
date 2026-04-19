# 2026-04-18 to 2026-04-19 — Wiki Auto-Sync, Docs Hygiene, Phase 5, and Dashboard UX Fixes

## Summary

Two-day diary. Day 1 focused on wiki infrastructure and hardware-prep paperwork; Day 2 was a docs fact-check pass and a live-testing-driven dashboard UX overhaul.

**2026-04-18:**

1. Documentation audit and hygiene pass.
2. Phase 5 (Real-Hardware Deployment) logged in `Board.md`.
3. Wiki auto-sync pipeline built and verified end-to-end.

**2026-04-19:**

1. Main-repo markdown fact-check against authoritative sources (launch YAML, Python, git log); small but real corrections committed.
2. Live health-check run resolves the "45 vs 46 checks" count drift; six active-doc hits updated.
3. Dashboard UX overhaul driven by live testing: Go Home returning-home label, anti-stuck direction plumbing, status-panel tooltips with ℹ️ affordances, speed unit labels, VFH default visual state.
4. Preset system audit, target-aware VFH, Vostok1-era breadcrumb cleanup, Go Home progress overhaul, `ros2 daemon` staleness diagnosis.
5. Tier-A/B/C dashboard sprint: safety guards (E-Stop header badge, Reset guard, toast tuning, waiting labels), structural reorg (panel reorder, Map+Camera grouping, collapsible info panels, preset feedback, step hints), first-run onboarding tour with replay button.

---

## 1. Documentation Audit and Hygiene Pass (2026-04-18)

### SASS.md body rewrite (the largest single fix)

`wiki/SASS.md` had an internal contradiction: the "Design Evolution" section at the top correctly stated that the legacy multi-phase escape (PROBE → REVERSE → TURN → FORWARD) had been moved to `legacy/fixed_variants/heading_controller_fixed.py` and replaced with a single-phase "turn toward the clearer side" behaviour. But the rest of the file kept describing the legacy behaviour — "turn left until clear" phrasing, a four-phase example, and a JSON status format with `phase`/`phase_name`/`no_go_zones` fields that the active code doesn't emit.

Verified ground-truth against the active code before rewriting:

| Fact | Source of truth |
|---|---|
| 12-second stuck timeout | `launch/autoboat.launch.yaml:179-180` (`stuck_timeout: 12.0`) |
| 1-metre movement threshold | `launch/autoboat.launch.yaml:181-182` (`stuck_threshold: 1.0`) |
| Direction-selection logic | `control/control/heading_controller.py:1051-1079` — `execute_smart_escape()` docstring reads "Escape: turn toward clearer side until path is clear"; line 1071: `if self.right_clear > self.left_clear:` picks direction from sector clearances |
| Status JSON format | `publish_anti_stuck_status()` at line 1132 emits `is_stuck`, `escape_mode`, `consecutive_attempts`, `front_clear`, `drift_vector`, `drift_uncertainty`, `drift_kalman_gain` — no `phase`/`phase_name`/`no_go_zones` keys |

Rewrote the Overview, Key Features, Escape Strategy, Interaction with Waypoint Skip, SASS-vs-Skip comparison, Typical Flow, Real-World Example, Dashboard Panel, Terminal Output, JSON Format, and Troubleshooting sections. The one remaining "turn left" reference is an intentional note in the Design Evolution section explaining that old code comments still use that phrasing.

### Cross-file "distributed" → "modular/three-node pipeline"

Per-file pitfall: the three-node architecture is **modular** running on one host over DDS loopback, not a distributed system. Fixed in six places:

- `README.md:15` — "three distributed ROS 2 nodes" → "modular 3-node ROS 2 pipeline"
- `USER_MANUAL.md:58` — "Distributed nodes (Perception-Planner-Controller) for flexible deployment" → "Three-node pipeline (Perception-Planner-Controller) for flexible deployment"
- `USER_MANUAL.md:516` — "three distributed ROS 2 nodes" → "modular 3-node ROS 2 pipeline"
- `wiki/System_Overview.md:23, 33` — two instances of "distributed" → "three-node pipeline"
- `Board.md:57` (Active System table row) — "distributed architecture" → "three-node pipeline"

### UPLOAD_INSTRUCTIONS.md mislabel

Line 43 and line 144 both labelled `SASS.md` as "Simple Anti-Stuck (deprecated)". The Simple Anti-Stuck System **is** the active implementation; the multi-phase v2.x variant is what's deprecated and moved to `legacy/`. Dropped the "(deprecated)" tag in both places.

### Home.md dead-link cleanup

The wiki Home page's "Quick Navigation" section listed ~33 links, of which 23 pointed to pages that were never created (a wish-list from the wiki's initial scaffolding — `First-Mission-Tutorial`, `Terminal-Mission-Control`, `Web-Dashboard-Guide`, `GPS-Navigation`, `PID-Control`, `Astar-Path-Planning`, `Contributing`, `FAQ`, etc.). On the published GitHub Wiki, those rendered as clickable links landing on "This page doesn't exist — create it?" prompts.

Stripped all 23 dead entries. Collapsed the remaining survivors into four clean sections:

- Getting Started (2 links: Installation_Guide, Quick_Start)
- Architecture (4 links: System_Overview, Design_Rationale, Glossary, Node_Naming_Refactor_Plan)
- Module Deep Dives (2 links: 3D_LIDAR_Processing, SASS)
- Troubleshooting & Security (2 links: Common_Issues, Dashboard_Security)

Also synced the Project Status table on Home.md with `Board.md`: added the Phase 5 row and changed the Phase 2 label from "Obstacle Avoidance" to "Autonomous Navigation" to match.

### Stale "Last Updated" dates

Bumped to 18-04-2026 across:

- `wiki/Home.md` (was 15-04)
- `wiki/README_WIKI.md` (was 15-04)
- `USER_MANUAL.md` (was 13-04)
- `web_dashboard/autoboat/README_autoboat_dashboard.md` (was 13-04)
- `Board.md` (was 16-04, version bumped 9.3 → 9.4)

### Other trims

- `wiki/Common_Issues.md`: removed an out-of-place bullet from a Gazebo CPU-load troubleshooting list. The bullet had no connection to the surrounding topic.
- `working_diary/2026-04-17_*.md`: trimmed a few prose references and a stale side-topics bullet that didn't belong in the public diary.

---

## 2. Phase 5 — Real-Hardware Deployment Logged in Board.md (2026-04-18)

### Trigger

Supervisor conversation on 18-04 signalled imminent access to the real AutoBoat central control unit. Expected work will begin the week of **20-04-2026** (next week).

### Known vs TBD in the CCU architecture

- **Confirmed**: The high-level control runs on a Raspberry Pi 5. The whole ROS 2 Jazzy stack from this repo is expected to run on it.
- **Not confirmed**: Supervisor mentioned something like an STM32 for low-level control, but the exact chip — or whether a separate low-level board even exists — has not been confirmed. Options range from STM32, ESP32, a commercial motor controller, to no low-level board (Pi handles thrusters directly via GPIO PWM). This is the **single largest schedule risk** for Phase 5 and must be clarified with the supervisor before hardware arrives.

### Risk table (abbreviated — full form in Board.md)

| # | Risk | Mitigation |
|---|---|---|
| 1 | LiDAR perception performance on Pi 5 (30k points × 10 Hz through `rclpy` may saturate cores) | Profile in VRX now; keep `sample_rate: 2` + raised `min_cluster_size` as fallback; C++ rewrite only as last resort |
| 2 | `/wamv/*` topic hardcoding (3 months of work tied to simulated topic names) | Launch-file remapping; inventory every reference now to make next-week swap mechanical |
| 3 | Low-level bridge node (only needed if a separate low-level controller exists) | Depends on supervisor answer to the CCU architecture question |
| 4 | Headless comms to shore | WiFi range walk-test; plan 4G modem fallback if mission box > 50 m; static IP or mDNS |
| 5 | Power-loss robustness | USB 3 SSD boot or read-only root FS; SD cards corrupt under sudden power-off |
| 6 | Safety integration | Hardware watchdog + physical E-stop + geofence; enable `hazard_enabled: true` with test-lake polygon |

### Task buckets (each row is a checkbox in Board.md)

- **Prep tasks (zero hardware required)** — 6 items: topic-remap dry run, LiDAR Hz baseline, bridge-node stub, `/wamv/*` reference inventory, supervisor ICD conversation, shore-comms plan.
- **Hardware-arrival bench tasks (CCU on bench, motors disconnected)** — 6 items: Ubuntu 24.04 + ROS 2 Jazzy install on Pi 5, native ARM64 build, bridge-node wiring, real topic-name swap, dry bench test, thermal + current-draw analysis.
- **On-water tasks (boat + test-lake)** — 5 items: manual joystick, single-waypoint autonomous, multi-waypoint with obstacles, long-duration (15+ min), failure-mode drills (manual override, E-stop, low-battery return-to-home).

Timeline row added: `TBD | Real-hardware deployment (Pi 5 as confirmed target; low-level CCU architecture TBD) | 🔜`.

---

## 3. Wiki Auto-Sync Pipeline (2026-04-18)

### Motivation

Before 18-04, the `wiki/` folder in this repo was only browsable via the code-tree on GitHub. The actual GitHub Wiki tab contained a 2-line placeholder Home page from when the wiki was first enabled. Readers who clicked the Wiki tab got almost nothing; readers who hunted for the `wiki/` folder in the source tree could read the content but lost all inter-page navigation. Fixing this was a good excuse to automate the sync so the two never drift again.

### Part A — first manual upload

Cloned `git@github.com:Ghostzero00018/uvautoboat.wiki.git` to a temp directory, copied every `wiki/*.md` except `UPLOAD_INSTRUCTIONS.md` (meta file, stays in the main repo only), pushed to the wiki repo's `master` branch. 12 pages published in one commit (commit `b719009` on the wiki repo). Excluded UPLOAD_INSTRUCTIONS.md because readers browsing the wiki shouldn't see upload-instruction meta content.

Moved the clone from `/tmp/` to `~/seal_ws/uvautoboat.wiki/` (sibling to `src/`) so it persists across reboots and is easy to open alongside the main repo in an editor.

### Part B — automation

Three artefacts committed to the main repo:

1. **`.github/workflows/sync-wiki.yml`** — GitHub Action. Triggers on `push` to `main` when `wiki/**` changed. Clones the wiki repo using the default `GITHUB_TOKEN` (scoped with `contents: write`), clobber-copies `wiki/*.md` into the clone, strips `UPLOAD_INSTRUCTIONS.md`, commits as `github-actions[bot]`, pushes. Exits cleanly with "No wiki changes to sync." when the copy produced no diff.
2. **`scripts/sync_wiki.sh`** — manual fallback. One command: `scripts/sync_wiki.sh "commit message"`. Auto-clones the wiki repo to `../uvautoboat.wiki/` on first run if absent. Uses `git pull --rebase` before copying to avoid non-fast-forward pushes when the wiki was edited directly via the GitHub UI.
3. **`wiki/UPLOAD_INSTRUCTIONS.md`** — condensed from 378 lines to 77. The old file documented a one-time upload ceremony, three redundant upload methods, and a stale "Additional Pages to Create" wish-list that included deprecated references (Atlantis). New file is a focused ongoing-sync reference: normal path (automatic), manual fallback (script), disaster-recovery steps (raw git commands), GitHub Wiki conventions cheat sheet, troubleshooting table.

### Part C — end-to-end verification

- **Run #1** (triggered by commit `591cd93` — the workflow-introduction push itself): Action fired because `wiki/UPLOAD_INSTRUCTIONS.md` matched the `wiki/**` path filter; clobber-copied wiki sources onto the clone; `git status --porcelain` returned empty (published content already matched the main repo's `wiki/`); printed "No wiki changes to sync." and exited green. Confirmed: the Action is wired up correctly.
- **Annotation warning on Run #1**: `actions/checkout@v4` uses Node.js 20 which is deprecated (forced Node 24 default from June 2026, removal September 2026). Bumped to `actions/checkout@v6` in commit `2852e89` per GitHub's release notes confirming v6 ships with Node 24 support.
- **Run #2** (triggered by commit `2852e89` — the v6 bump plus `wiki/Home.md` dead-link cleanup): Action ran; detected real diff (Home.md changed); produced a sync commit on the wiki repo titled `Sync wiki from main repo @ 2852e89...` by `github-actions[bot]`. **Zero annotations** — Node 20 warning gone. Published wiki now reflects the trimmed Home.md.

### Verification snapshot

| Signal | Status |
|---|---|
| Action triggers on `wiki/**` changes only | Confirmed via `paths:` filter |
| Action ignores non-wiki pushes | Confirmed (no extra runs from other same-day pushes) |
| Default `GITHUB_TOKEN` can push to the wiki repo | Confirmed (Repo Settings → Actions → Workflow permissions was already "Read and write") |
| Node 24 migration | Confirmed via 0 annotations on Run #2 |
| Manual script parity | Ran `scripts/sync_wiki.sh "test"` after pulling the bot's commit — printed "No wiki changes to sync." as expected |

---

## 4. Main-Repo Markdown Fact-Check (2026-04-19)

A parallel audit pass this morning checked all active markdown in the main repo against the authoritative sources (launch YAML, Python source, git log). Findings were ranked HIGH / MED / LOW; HIGH claims were re-verified manually before applying fixes.

**HIGH-severity (confirmed):**

- `wiki/SASS.md:97-98` — Kalman tuning shown as `Q = 0.001`, `R = 0.1` — wrong by 10× and 5× against YAML (`kalman_process_noise: 0.01`, `kalman_measurement_noise: 0.5`). Stale from before the 18-04 SASS.md rewrite, which refreshed the prose but missed the Kalman code block.

**MED-severity:**

- Health-check count drift across docs: README + USER_MANUAL said "45 checks"; Glossary + Board said "46 checks". Script has 26 static `pass`/`fail`/`warn` call sites, some inside loops — needed a live run to resolve authoritatively. Resolved by the live health-check run described below (46 confirmed).

**LOW-severity:**

- `USER_MANUAL.md:182` + `wiki/Installation_Guide.md:14` over-specified "Python 3.12" in the Recommended column. Project supports `3.10+` with no upper bound. Flattened both columns to `3.10+`.

Good-hygiene negatives (searched for and NOT found):

- No stale naming leaks (OKO / SPUTNIK / BURAN / Vostok1 references confined to `legacy/` or git history).
- No "distributed ROS 2" phrasing in active docs (18-04 cleanup stuck).
- No smoke-detection resurrection.
- No four-phase SASS leaks in active docs.

Applied in one commit `ee4bbcc docs: Fix stale Kalman params, health-check count, Python version`.

---

## 5. Live Health-Check Run Resolves the 45-vs-46 Drift (2026-04-19)

Ran `health_check_autoboat.sh` against a live simulation with the **Buoy Field** preset active. Output totalled **46 checks** (40 PASS + 6 WARN). The six warns were all the expected preset-override mismatches (`critical_distance: 3.0` vs launch default `6.0`, `min_safe_distance: 10.0` vs `12.0`, `obstacle_slow_factor: 0.3` vs `0.5`, and three perception overrides), not real faults.

Authoritative count: **46**. Updated README and USER_MANUAL from "45" to "46" across six hits (folded into the fact-check commit `ee4bbcc`). Historical working-diary entries from before today were left alone per the append-only rule.

---

## 6. Dashboard UX Overhaul (2026-04-19)

Live simulation testing surfaced four user-reported issues. An Explore-agent triage + manual verification expanded them to **seven discrete bugs** across the planner, controller, and dashboard.

### 6.1 Mission completion stayed at 100% during Go Home

Root cause: the FINISHED-state counter clamp landed on 17-04 (`current_waypoint: min(current_wp_index + 1, len(waypoints))`) produces `1 / 1 = 100%` when Go Home replaces the waypoint list with a single synthetic home waypoint (length 1). The progress bar was correctly showing "100% of the home trip" — which is exactly what the user did NOT want.

Fix was two-sided:

1. **Planner** — publish a new `go_home_mode: bool` field in `/planning/mission_status` JSON, reflecting `self.go_home_mode` state.
2. **Dashboard** — branch the progress-bar render on `missionState.goHomeMode`: render "🏠 Returning Home" instead of a percentage, and "Return trip" instead of the N/M waypoint counter.

**Follow-up bug uncovered during verification.** The dashboard's `/planning/mission_status` subscriber at `app.js:446` cherry-picks specific fields from the incoming JSON and throws the rest away. The first fix wired `missionState.goHomeMode` inside `updateMissionControlUI()`, but that function is only called from the `/planning/config` subscriber — not `/planning/mission_status`. The `go_home_mode` field was therefore discarded before reaching the handler. Had to also add `go_home_mode` to the cherry-pick object and read it in `updateMissionStatus()`. Worth remembering: this dashboard has two different code paths for mission-state updates, and they do not share state-extraction logic.

Initial misdiagnosis of the symptom was a browser-cache issue; had the user try hard-refreshes. Caught by the user reporting the UI still showed 100% after a clean cache flush; then grepped the subscriber path and found the cherry-pick.

### 6.2 Simple Anti-Stuck Action / Direction fields misleading

Three layered bugs in the `/control/anti_stuck_status` wiring:

- **A (tuning, not code):** with default `stuck_timeout: 12.0 s` and `stuck_threshold: 1.0 m`, escape rarely fires during normal obstacle-avoided sailing. Panel sits on IDLE most of the time, which is correct but looks broken.
- **B (dashboard):** even when escape *did* fire, `app.js:904` hardcoded the Action text to "TURNING LEFT | Virage Gauche" regardless of actual direction. Python code at `heading_controller.py:1071-1076` turns toward whichever side is clearer (left or right).
- **C (dashboard):** the Direction field was `'← LEFT | Gauche (fixed)'` — a literal static string set unconditionally at `app.js:960`. Stale since the 18-04 single-phase rewrite.

Fix:

- **Python** — added `self.escape_direction` state (`'IDLE' | 'LEFT' | 'RIGHT'`) to `HeadingController.__init__`; set in `execute_smart_escape()` at the same point the thrusters are commanded; reset to `'IDLE'` in `_reset_all_escape_state()` and on both escape-exit paths (front clear, or three consecutive failures → waypoint skip). Published as a new `escape_direction` field in `publish_anti_stuck_status()`.
- **Dashboard** — replaced hardcoded strings with reads from `data.escape_direction`. Action now says TURNING LEFT / TURNING RIGHT / IDLE dynamically; Direction mirrors with `← LEFT | Gauche`, `RIGHT → | Droite`, or `— Idle`. Tooltip on the Direction field explains the semantic.

### 6.3 Status panels lacked tooltips and hover affordance

Two passes:

**Pass 1** — added `title="..."` attributes to the `<div class="info-item">` containers for 20 fields across Mission Status, GPS Position, Obstacle Detection, Thrusters, and Simple Anti-Stuck panels. Native browser tooltips showed on row-hover.

**Pass 2** (after user feedback) — user correctly flagged that without a visible ℹ️ icon, the status rows looked like plain read-only text and users didn't know anything was hoverable. The existing tuning panels use `<span class="info-tooltip" title="...">ℹ️</span>` for affordance; status panels should match. Moved the titles from the info-item div onto explicit icon spans, one per field. Consistent with the existing convention and gives users a visual cue.

Also explored a CK3-style persistent/pinned tooltip system (hover N seconds → pin → stays until click or hover-elsewhere). Concluded not worth implementing at this stage: native tooltips plus the new ℹ️ affordance solve the actual discoverability problem, and a custom tooltip system is ~150 LOC of JS for marginal reading-comfort gain. Shelved unless reviewers actually struggle during a demo.

### 6.4 Parameter inputs missing unit suffixes

Audit showed most tuning params already carry `(m)`, `(s)`, `(°)` suffixes. Only the two Controller Speed inputs were ambiguous:

- `Base:` → `Base (thrust, 100–2000):`
- `Max:` → `Max (thrust, 100–2000):`

Tooltip bodies also clarified these are unitless thrust commands, not Newtons or m/s, with the YAML default values called out explicitly.

### 6.5 VFH dropdown defaulted to "Enabled" despite YAML `false`

Caught during live testing after the user asked why VFH appeared enabled in the Controller tuning panel. Two independent root causes:

1. `index.html:789-790` lists `<option value="true">Enabled</option>` first, with no `selected` attribute. Browsers default to showing the first option. The YAML-side `use_vfh_bias: false` was therefore never visually reflected on page load.
2. All four tuning presets (Universal, Buoy Field, Pier Detect, **Open Water**) had `use_vfh_bias: true` in `app.js`. The intended design is "3 of 4 enable VFH, Open Water off" — Open Water should have been the escape hatch. It wasn't.

Fix: added `selected` to the Disabled option in HTML, and corrected the Open Water preset to `use_vfh_bias: false`. Dashboard now loads with VFH Disabled by default (matching YAML), and clicking Open Water flips VFH off. Clicking any of the other three presets still flips it on — consistent with the convention.

Follow-up question from the user: is VFH "banned" in the ROS node? Answer: no, it is code-present but off-by-default. `lidar_perception.py` publishes the polar histogram (`vfh_gap` in `/perception/obstacle_info`) on every scan; `heading_controller.py:864-899` has the polar-bias application gated behind `if self.use_vfh_bias and (self.obstacle_detected or self.force_avoid_active)`. With the YAML default false, that branch is cold but the code is exercised — opt-in feature, not a removed one. Confirmed no removal planned; user preference is to keep as-is.

---

## 7. Preset, VFH, and Dashboard Polish (2026-04-19, afternoon/evening)

After the dashboard UX overhaul landed, the day continued with three audits that each produced a focused cleanup commit, plus a last round of Go Home work driven by live-testing feedback.

### 7.1 Preset system audit + 3 cleanup fixes

Traced the 4-preset wiring end-to-end across `app.js` (`TUNING_PRESETS`, `applyPreset`, `updatePerceptionInputs`, `updateControllerInputs`), `index.html` (4 buttons), `style_merged.css` (4 colour variants), and the three ROS subscribers that consume the bus (`/planning/set_config`). Findings:

- All 4 presets have consistent key coverage (12 perception, 14 controller). VFH state matches the 3-on / Open-Water-off design after the morning fix.
- **10 perception and 2 controller `declare_parameter` defaults in Python had drifted** from the YAML defaults. YAML overrides at launch so no runtime drift, but reading Python alone was misleading (e.g., `min_height=-15.0` in Python vs `-1.2` in YAML).
- **4 controller keys identical across all 4 presets AND identical to YAML defaults** (`avoid_diff_gain=18.0`, `reverse_timeout=4.0`, `turn_deadband_deg=0.5`, `max_avoidance_turn_deg=45.0`). Dead weight on every preset apply.
- **`autoboat_cli.py` still had a `--mode vostok1` argparse branch** that published to `/vostok1/*` topics with only a warn message. Fully unused — the legacy integrated system's topics are long gone.

Applied in `d7dd869 refactor: Sync Python defaults, trim preset keys, drop CLI legacy mode`:

- Synced 10 perception + 2 controller `declare_parameter` defaults to match YAML.
- Trimmed 4 dead-weight keys from all 4 presets; added `!== undefined` guards in `updateControllerInputs()` so presets that omit a key no longer write `undefined` into the HTML input.
- Removed `--mode` argparse flag, `MissionCLI.__init__(mode=...)` parameter, all `self.mode == 'modular'` branches, and legacy topic fallbacks from `autoboat_cli.py`.

Verified live: `ros2 run plan autoboat_cli --help` no longer lists `--mode`; `--mode vostok1 status` rejects with "invalid choice: 'vostok1'"; `ros2 param get /lidar_perception_node min_height` returns `-1.2` (YAML, unchanged at runtime); Buoy Field preset apply shows "12 Perception + 10 Controller" (down from 12/14); `ros2 param get /heading_controller_node avoid_diff_gain` stays at `18.0` after a preset click (dead-weight key no longer pushed).

### 7.2 VFH status audit + 4 improvements

Asked whether VFH was being actively used after the morning's preset click flipped `use_vfh_bias=true`. Answer: yes. Full trace of the VFH path:

- **Perception** (`lidar_perception.py`): `_calculate_polar_histogram()` (left/right free-space bias), `_calculate_vfh_steering()` (72 bins × 5° over 360°, blocks within 15 m, 10° clearance inflation, picks free bin closest to `target_angle`). Outputs `polar_bias` and `vfh_gap` in `/perception/obstacle_info`.
- **Controller** (`heading_controller.py:864-905`): gates on `use_vfh_bias AND (obstacle_detected OR force_avoid_active)`, fuses LR-clearance + VFH-direction + polar-histogram into a differential bias, clamps to `±avoid_diff_gain`, applies as differential thrust.

Four improvement opportunities identified; user approved all four.

Applied in `62b4320 refactor: Target-aware VFH with tunable params and loosened polar gate`:

1. **Target-aware VFH.** Previously `_calculate_vfh_steering()` was called with `target_angle=0.0` (hardcoded forward). For a boat 45° off-waypoint, VFH picked the forwardmost clear gap, not the toward-waypoint clear gap. Fix: controller publishes its computed `angle_error` (body-frame radians) on a new `/control/heading_error` topic (`Float64`) once per control tick, after the PID step. Perception subscribes, stores `self.body_heading_error`, passes it as `target_angle`. VFH now aims at the actual intended direction, not blindly forward. World-frame vs body-frame was the subtle gotcha — perception's existing `self.target_angle` (from `/planning/current_target`) is world-frame compass bearing; the controller's `angle_error` is body-frame, which is what VFH needs.
2. **4 new ROS params.** Exposed `vfh_block_distance` (15.0), `vfh_bin_width_deg` (5.0), `vfh_clearance_deg` (10.0), `vfh_polar_power` (1.0) as `declare_parameter` + YAML + `_load_parameters()` + used in the VFH / polar functions. YAML defaults match the prior hardcoded values → no runtime behaviour change at launch, but the knobs are now field-tunable per scenario without a code change.
3. **Legacy comment cleanup.** Stripped `# from all_in_one_stack` and `# for BURAN compatibility` references from `lidar_perception.py` headers / status JSON comments; replaced with neutral descriptions.
4. **Polar-bias gate loosened.** Was `if self.force_avoid_active and self.urgency > 0.2:`. Outer gate already requires obstacle detection, so the extra `force_avoid_active` made the wide-field signal almost never fire. Changed to `if self.urgency > 0.2:` — polar histogram now contributes whenever urgency is meaningful during any obstacle encounter.

Verified live: `ros2 topic list` shows `/control/heading_error`; `ros2 topic echo /control/heading_error --once` returned `data: 0.054 rad` (~3° off-course) during an active mission, confirming the body-frame error is flowing through; `ros2 param list /lidar_perception_node | grep vfh` lists the 4 new params with their YAML values.

### 7.3 Vostok1-era breadcrumb cleanup

Same commit `62b4320` (chore sub-subject). Audited the active code tree (excluding the frozen `legacy/` tree and the append-only `working_diary/`) for residual OKO / SPUTNIK / BURAN / Vostok1 references. Kept the legitimate historical references — `wiki/Node_Naming_Refactor_Plan.md` (entire file IS the rename record), `wiki/Glossary.md`'s "Legacy Module Code-Names" section, Board milestone entries, README's historical pointer to Glossary. Removed 5 true-stale items:

- `web_dashboard/autoboat/style_merged.css:1` — header comment `/* Vostok1 Web Dashboard ... */` → `/* AutoBoat Web Dashboard ... */`
- `plan/plan/lidar_perception.py:5, 50` — `(formerly OKO)` and `(formerly OKO — "Œil", early-warning satellite reference)` breadcrumbs stripped
- `plan/plan/waypoint_planner.py:5` — `(formerly SPUTNIK)` stripped
- `control/control/heading_controller.py:5` — `(formerly BURAN)` stripped
- `wiki/Node_Naming_Refactor_Plan.md:107` — stale grep-claim about "outside this file and the Glossary historical note" tightened to "outside this file" (the Glossary no longer contains the literal `oko_perception_node` string, only the short-form `OKO`).

### 7.4 Go Home progress bar — from "stuck at 100%" to real fill

Live retest of the morning's Go Home label fix exposed two more bugs, both in `web_dashboard/autoboat/app.js`:

**Bug A — 1 Hz race between two subscribers.** `/planning/mission_status` (~5 Hz) and `/planning/config` (1 Hz) both wrote to `missionState.currentWaypoint` / `missionState.goHomeMode` / `missionState.totalWaypoints`. `mission_status` carries these fields; `config` does not. `updateMissionControlUI()` used `|| 0` / `|| false` defaults, so every config tick clobbered the good values set by `updateMissionStatus`. Flicker visible as the progress bar briefly dropping to 0% / mission-mode labels reverting. Fix: guard the three assignments with explicit `!== undefined` checks, matching the pattern `totalWaypoints` already used.

**Bug B — bar always full during Go Home.** Root cause: bar width was computed from `currentWaypoint / totalWaypoints = 1 / 1 = 100%` during Go Home (synthetic single home waypoint). The morning fix had only relabelled the *text*; the *fill* stayed at 100% regardless of distance. User correctly noted: "the boat can be far from spawn but the bar is full."

Rebuilt the Go Home progress as distance-based:

- New `missionState.goHomeInitialDistance` field, captured from the first `distance_to_target > 0.5 m` observed while `goHomeMode` is true. Reset when `goHomeMode` flips false.
- Render: `waypointProgress = (1 − currentDistance / initialDistance) × 100`, clamped to `[0, 100]`.
- Moved the `🏠 Returning Home` label from the bar's inner text to the waypoint-count slot, so the bar text can now show a live percentage as it fills.

**Bonus latent bug surfaced during the fix.** `currentState.mission.distance` had been stuck at `0.0 m` for the whole mission history. The mission_status subscriber cherry-picked `data.distance_to_target` (a field that doesn't exist on that topic), and the separate `/planning/current_target` subscriber — which IS the authoritative source of `distance_to_target` — was parsing the JSON and throwing it away. Fix: rewired `/planning/current_target` callback to store `currentState.mission.distance` + do the Go Home initial-distance capture there; removed the bogus cherry-pick; `updateMissionStatus()` no longer clobbers distance when the field is absent. Side effect: the Mission Status panel's "Distance:" display now works for every mission, not only Go Home.

Pending commit: `fix: Dashboard Go Home progress + mission-state race + distance wiring`.

### 7.5 Stale `ros2` daemon — diagnosis-only, worth logging

During the Go Home retest, a side terminal's `ros2 node list` returned empty while the boat was clearly responding to dashboard commands. Same symptom from the dashboard's Health Check panel (`[FAIL] Cannot reach ROS 2 graph`). Ruled out env-var mismatch — `/proc/<pid>/environ` of `lidar_perception_node` and the side shell both showed identical `ROS_DOMAIN_ID=56`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`. Root cause: stale per-user `ros2 daemon` cache. Fixed with:

```bash
ros2 daemon stop
ros2 daemon start
ros2 node list
```

No code change this round — adding to the operational knowledge base. Worth remembering for Phase 5: if the daemon is restarted or its socket gets wedged while nodes are already up, the CLI and the dashboard's health check will report an empty graph even though the nodes are fine. Longer-term fix candidate: `ros2 daemon stop` prime at the top of the health check subprocess, or an empty-state message in the dashboard panel suggesting the daemon restart recipe.

---

## 8. Dashboard Tier A / B / C UX Sprint (2026-04-19, late session)

Three-tier UX audit mapped first-impression problems and interaction-logic gaps against the live dashboard. User picked Tier A + the logic-audit guards first (safety, low risk), then the full Tier B structural reorg, then only item 4 of Tier C — the first-run onboarding tour. Items 1–3 of Tier C (jargon renames: urgency → "Obstacle Alert %", VFH → "Navigation Gap", Kalman σ → "Drift Confidence", preset renames) were intentionally deferred until after the supervisor CCU conversation so labels are not renamed twice.

### 8.1 Tier A — safety guards and Apply-button feedback

Commit `f36be82`. Five items:

- **Header E-Stop badge.** Red "🚨 E-STOP" pill in the header-right area; click scrolls to the real Emergency Stop button and flashes it with a yellow outline for ~1 s. When mission state is `EMERGENCY_STOP`, the header badge itself pulses to mirror the latched state. New CSS rules `.header-estop-badge`, `.header-estop-badge.latched`, `.mission-btn.emergency.estop-flash`.
- **Toast durations by type.** `showFeedback()` previously used a binary 5 s (error/warning) vs 3 s. Replaced with a per-type object: error 6.5 s, warning 5.5 s, success 3 s, info 3.5 s. Rationale: "Rejected: Kp out of range (0-2000)" type messages were disappearing before a slow reader could parse them.
- **Visible "Waiting for ROS sync…" label.** Three Apply buttons (Config, Perception, Controller) gained a `waiting-sync` class and a sibling `<span class="apply-waiting-label">` showing an italic "⏳ Waiting for ROS sync… | En attente de synchro". CSS adjacent-sibling selector `.waiting-sync + .apply-waiting-label` hides it once the class is removed in `updateConfigFromROS()` on first config sync. Replaces title-only tooltips that required hover to discover.
- **Reset guarded during WAITING_CONFIRM.** Previously always enabled; a Reset could fire a `clear_mission` in-flight against a pending `confirm_waypoints` and leave the planner inconsistent. Now disabled when `awaitingDecision` is true or disconnected.
- **Joystick enable/disable routed through `debounceCommand`.** The other mission buttons were already debounced (800 ms global cooldown); joystick toggle was not. Added for consistency — prevents rapid back-to-back mode flips during command latency.

### 8.2 Latent `distance.toFixed is not a function` crash

Same commit `f36be82`. User hit `TypeError: distance.toFixed is not a function` in `updateMissionStatus` at line 793 once the planner started publishing a valid distance. Root cause: the function used a bare `distance` identifier with no local declaration, so the browser resolved it to `window.distance` — which in HTML5 is automatically populated with any element whose `id` is a valid JS identifier, in this case the `<div id="distance">`. Calling `.toFixed()` on a DOM node throws.

Fixed to read `currentState.mission.distance` with a `Number.isFinite()` guard. Then swept the eight other bare-identifier-eligible IDs in the file (`latitude`, `longitude`, `logs`, `map`, `state`, `urgency`, `waypoint`) — all are either explicitly declared (`let map`, `const logs`, `const distance` in other scopes) or used only as function parameters. No other instances.

### 8.3 Tier B — structural reorg and preset feedback

Commit `9f3f8d8`. Five items:

- **Panel reorder via CSS `order`.** `.mission-control-panel { order: -3 }` pushes Mission Control to the first grid cell. New-user eye lands on actionable buttons instead of scrolling past five telemetry panels.
- **Map + Camera grouped.** Wrapped both panels in `<div class="map-camera-group">` with `display: flex; flex-direction: column` so the camera feed always sits directly under the trajectory map, regardless of how the auto-fit grid reflows. The group itself is a grid child with `order: -2`. An earlier iteration tried individual `order: -2`/`-1` on the two panels, but grid auto-placement could split them across rows at some breakpoints.
- **Collapsible info panels.** GPS / Obstacle / Thruster / Anti-Stuck panels gained a `collapsible` class. `initCollapsiblePanels()` wires a click handler on each `h2` that toggles a `.collapsed` class on the panel; CSS shows a ▾ caret that rotates to ▸ when collapsed and hides all non-h2 children. Start expanded so nothing is hidden by surprise.
- **Preset feedback.** `applyPreset()` now snapshots all 26 tuning inputs before update, diffs after, expands the affected tuning sub-section(s), outlines changed inputs in orange with a 2-pulse animation, and scrolls the first changed field into view. Status line reports `"Buoy Field preset applied — N field(s) changed"`. A later commit (§8.6) refined the expand behaviour to only open a sub-section that actually changed.
- **Step-transition hints.** Blue-left-border "➡️ Next: review waypoints and click CONFIRM" between Step 1 and Step 2; same pattern between Step 2 and Step 3. Step 3 gained a yellow help banner above the button rows describing STOP / RESUME / RESET / RETURN HOME / EMERGENCY STOP behaviour.

Incidental while in the file: stale `"turn left until clear"` wording in the Controller tuning-section tip replaced with `"turn toward clearer side until path is safe"`, matching the current bidirectional escape.

### 8.4 Camera layout polish and black-feed gotcha

Same commit `9f3f8d8` for the layout fix. After the map-camera-group wrap, the camera topic `<input>` still had an inline `width: 250px` which left the Refresh button overflowing the panel boundary, and the long topic string `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` was hard to read at 250 px. Fix:

- Removed inline `width` and `margin-left` styles.
- `.camera-controls` gained `flex-wrap: wrap`; input is `flex: 1 1 200px; min-width: 0`; button is `flex: 0 0 auto`.
- Added a `title=` on the input so hovering shows the full path as a native tooltip.

Separately during testing the user hit a black camera feed stuck on "Connecting to…". Diagnosed via a pipeline: topic publishes (confirmed with `ros2 topic hz` at ~3 Hz, low due to CPU-bound Gazebo), port 8080 already bound (Address already in use — the launcher's `web_video_server` was alive). So the dashboard was talking to an alive upstream, but the browser's MJPEG long-polling connection had gotten stuck on the previous session's socket. Full simulation restart resolved. Not a dashboard bug — operational gotcha worth remembering: Firefox in particular holds MJPEG long-polling beyond a hard refresh.

### 8.5 First-run onboarding tour (Tier C item 4 only)

Commit `bde743c`. User picked only the onboarding item from Tier C — not the jargon renames, because "this is a research project at least it needs to be a little bit scientific". Implementation:

- **5-step guided tour:** Welcome → Generate → Confirm → Start → Emergency Stop.
- Semi-transparent backdrop (`.onboarding-backdrop`, z-index 9998) plus a bilingual EN/FR callout card fixed at the bottom of the viewport. Each step (after the welcome card) highlights its target button with a green pulsing glow (`.onboarding-highlight` using `box-shadow` and an animated pulse keyframe, z-index 9999). The target is scrolled into view.
- **Controls:** Back / Skip / Next buttons plus keyboard shortcuts — `Esc` skips, `→` or `Enter` advance, `←` goes back.
- **Terminology:** the tour card copy uses the actual technical vocabulary (VFH gaps, PID gains, Kalman drift, mission state names like `WAITING_CONFIRM` / `READY`) rather than simplified labels. The per-field ℹ️ tooltips remain the authoritative explainers.
- **Persistence:** `localStorage['autoboat_tutorial_seen_v1']` records dismissed/completed state. Auto-launches ~900 ms after first load; does not appear again on subsequent loads. Bumping the `_v1` suffix in a future iteration replays for returning users.
- **Replay entry point:** a purple-gradient `?` button in the header (first attempt used `rgba(255,255,255,0.15)` on a white header background — invisible; corrected to a `#667eea → #764ba2` gradient circle with white text and a coloured box-shadow).

### 8.6 Preset sub-section expand — per-side guard

Commit `17c191c`. User observed during testing that every preset click unfolded both tuning sub-sections even when they had manually collapsed one. Refined `applyPreset()`:

```js
const changedPerception = changed.filter(id => id.startsWith('perception-'));
const changedController = changed.filter(id => id.startsWith('controller-'));
if (changedPerception.length > 0) expandTuningSection('perception-params');
if (changedController.length > 0) expandTuningSection('controller-params');
```

Audited all four current presets afterward: each carries 12 perception + 10 controller params with distinct values. So in practice both sides always change → both sub-sections always auto-expand (today's behaviour unchanged). The guard is future-proofing: if a preset is later slimmed to a minimal-diff form (e.g. Open Water dropping perception entries that already match YAML defaults), or if a user has manually matched a preset's values beforehand, the guard will respect their collapse state.

### Verification and process notes

- All six changes were dashboard-only — zero Python / YAML / launch edits. No `colcon build` needed; browser hard-refresh is sufficient.
- `node --check app.js` run after every change; syntax clean each time.
- AI-tooling grep sweep clean before every commit.
- Full mission smoke-test between Tier A and Tier B confirmed no regressions on Go Home, preset apply, or mission-state transitions.
- Tier C items 1–3 (jargon / preset / tooltip renames) intentionally deferred pending supervisor CCU feedback so labels are not renamed twice.

---

## Commit trail

2026-04-18 (all pushed to `main`):

```text
d36d0bf docs: Trim out-of-place bullet in Common_Issues; reword 2026-04-17 diary prose
20e9ab9 docs: Log Phase 5 hardware-deployment in Board; fix stale "distributed" phrasing in README/USER_MANUAL
71475d0 docs: Sync SASS.md body with current single-phase escape; fix mislabels and stale dates in wiki and dashboard README
591cd93 feat: Auto-sync wiki/ to GitHub Wiki via workflow; add manual sync script; condense UPLOAD_INSTRUCTIONS.md
2852e89 chore(wiki): Bump actions/checkout to v6; trim dead links from Home
89d39ab docs: Add 2026-04-18 working diary covering wiki auto-sync, docs hygiene, and Phase 5 logging
```

2026-04-19:

```text
ee4bbcc docs: Fix stale Kalman params, health-check count, Python version
d7f7cf5 fix: Dashboard Go Home label, escape direction, VFH default, tooltips
e58dc15 docs: Expand 18-04 diary to cover 19-04 fact-check and dashboard UX
5c04de6 docs: Correct numbering in the 2026-04-19 diary entries for clarity
fbc8f89 docs: Expand 18-04 diary to cover 19-04 fact-check and dashboard UX
d7dd869 refactor: Sync Python defaults, trim preset keys, drop CLI legacy mode
62b4320 refactor: Target-aware VFH with tunable params and loosened polar gate; chore: Strip Vostok1-era breadcrumbs from active code
4b2d132 fix: Dashboard Go Home progress + mission-state race + distance wiring
8ec76a2 docs(wiki): Document ros2 daemon staleness in Common_Issues; append 2026-04-19 afternoon work to diary
760b40a docs: Sweep docs for VFH, escape direction, preset names, LiDAR typo
f36be82 feat(dashboard): Tier A UX fixes + fix latent distance.toFixed crash
9f3f8d8 feat(dashboard): Tier B UX — reorder, collapsibles, preset feedback
bde743c feat(dashboard): Add first-run onboarding tour with replay button
17c191c refactor(dashboard): Expand only tuning sub-sections changed by preset
<pending> docs: Append 2026-04-19 late session (Tier A/B/C onboarding) to diary
```

On the wiki repo (separate `uvautoboat.wiki.git`):

```text
b719009 Upload AutoBoat wiki pages from uvautoboat/wiki/           (manual first upload, 18-04)
<auto>  Sync wiki from main repo @ 2852e89...                      (from the Action, 18-04)
<auto>  Sync wiki from main repo @ <next>                          (pending from 19-04 SASS fix)
```

---

## Next steps

Carrying over from 18-04 — still the right priorities:

1. **Supervisor CCU architecture conversation** — highest priority. Three open questions:
   - Is there a separate low-level controller in the CCU, or does the Pi drive thrusters directly?
   - If separate: what chip, what firmware, what does the Pi ↔ low-level interface look like (UART, CAN, micro-ROS, custom binary)?
   - Is there an interface-control document, or will we reverse-engineer from firmware sources?
2. **Zero-hardware Phase 5 prep on the Linux workstation**:
   - Inventory every `/wamv/*` reference across `*.py`, `*.yaml`, `*.js`, `*.html`. Produce a target topic map.
   - Profile `/perception/obstacle_info` publish rate in VRX under realistic load. Baseline for the Pi 5 measurement.
   - Draft `remap.launch.yaml` aliasing each `/wamv/*` topic to a neutral name.
   - Stub the bridge node as a pass-through: subscribe to `/control/thrust_cmd`, republish to `/wamv/thrusters/{left,right}/thrust`.
3. **Shore-comms spec** (paper exercise): measure the dashboard's max useful range; decide WiFi / directional / 4G; confirm the WAM-V's antenna setup when inspecting the CCU.

New items surfaced on 2026-04-19:

1. **Dashboard controller-param ROS-sync gap**: observed during VFH debugging that there is no sync path from the `heading_controller` node's parameter state back to the Controller Tuning panel. Users toggling a preset change the ROS state, but the dashboard's display of that state is driven only by its own input fields, never re-read from the controller. If the controller rejects a value (server-side validation), the dashboard's display will silently drift from reality. Not urgent — flag as future-iteration cleanup.
2. **Optional "VFH Live" status badge**: one-line indicator in the status column showing whether VFH is currently biasing steering (distinct from the tuning-panel toggle). Only if someone gets confused again about whether it's on. Ticket-sized, trivially skippable.
3. **`ros2 daemon` cache staleness as an ops gotcha**: the dashboard Health Check panel (and any side `ros2 node list`) will silently report an empty graph if the local per-user `ros2 daemon` goes stale, even while the nodes are healthy and the boat responds to commands. Recovery is `ros2 daemon stop && ros2 daemon start`. Worth adding either a prime at the top of the health check subprocess or an empty-state hint on the dashboard panel; likely to bite again on the Pi 5 in Phase 5. Low priority but easy to miss.
4. **VFH tuning sweep once on hardware**: the four new `vfh_*` ROS params (`vfh_block_distance`, `vfh_bin_width_deg`, `vfh_clearance_deg`, `vfh_polar_power`) are currently at values tuned for the VRX LiDAR. When the real LiDAR model is known during Phase 5, do a short scan-width and bin-count sweep to match the new sensor's angular resolution.
