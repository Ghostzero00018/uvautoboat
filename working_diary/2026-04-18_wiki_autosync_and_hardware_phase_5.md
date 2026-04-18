# 2026-04-18 — Wiki Auto-Sync Pipeline, Docs Hygiene, and Hardware Deployment (Phase 5) Logged

## Summary

Three substantive chunks of work today, in this order:

1. **Documentation audit and hygiene pass** — finished the stale-content cleanup started yesterday. Swept README, USER_MANUAL, Board.md, wiki, and the dashboard README for stale phrasing, internal contradictions, old dates, and mislabels. The biggest single fix was a full rewrite of `wiki/SASS.md`'s body to match the current single-phase escape behaviour in `heading_controller.py`.
2. **Phase 5 (Real-Hardware Deployment) logged in `Board.md`** — the supervisor signalled imminent access to the real AutoBoat central control unit (CCU). Added a full Phase 5 section with a ranked risk table and three task buckets (no-hardware prep, hardware-arrival bench tasks, on-water tasks).
3. **Wiki auto-sync pipeline built and verified end-to-end** — the `wiki/` folder in this repo is now continuously mirrored to the published GitHub Wiki (`github.com/Ghostzero00018/uvautoboat/wiki`) via a GitHub Action on every push to `main`. Includes a one-command manual fallback script and a condensed sync reference doc. Zero warnings on the most recent Action run.

---

## 1. Documentation Audit and Hygiene Pass

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

## 2. Phase 5 — Real-Hardware Deployment Logged in Board.md

### Trigger

Supervisor conversation today signalled imminent access to the real AutoBoat central control unit. Expected work will begin the week of **20-04-2026** (next week).

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

## 3. Wiki Auto-Sync Pipeline

### Motivation

Before today, the `wiki/` folder in this repo was only browsable via the code-tree on GitHub. The actual GitHub Wiki tab contained a 2-line placeholder Home page from when the wiki was first enabled. Readers who clicked the Wiki tab got almost nothing; readers who hunted for the `wiki/` folder in the source tree could read the content but lost all inter-page navigation. Fixing this was a good excuse to automate the sync so the two never drift again.

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

## 4. Commit trail (all pushed to `main`)

```text
d36d0bf docs: Trim out-of-place bullet in Common_Issues; reword 2026-04-17 diary prose
20e9ab9 docs: Log Phase 5 hardware-deployment in Board; fix stale "distributed" phrasing in README/USER_MANUAL
71475d0 docs: Sync SASS.md body with current single-phase escape; fix mislabels and stale dates in wiki and dashboard README
591cd93 feat: Auto-sync wiki/ to GitHub Wiki via workflow; add manual sync script; condense UPLOAD_INSTRUCTIONS.md
2852e89 chore(wiki): Bump actions/checkout to v6; trim dead links from Home
```

On the wiki repo (separate `uvautoboat.wiki.git`):

```text
b719009 Upload AutoBoat wiki pages from uvautoboat/wiki/           (manual first upload)
<auto>  Sync wiki from main repo @ 2852e89...                      (from the Action)
```

---

## Next steps

1. **Supervisor conversation this week** — highest priority. Three questions that unblock the majority of Phase 5 planning:
   - Is there a separate low-level controller in the CCU, or does the Pi drive thrusters directly?
   - If separate: what chip, what firmware, what does the Pi ↔ low-level interface look like (UART, CAN, micro-ROS, custom binary)?
   - Is there an interface-control document (ICD) for it, or will we need to reverse-engineer from firmware sources?
2. **Start the zero-hardware Phase 5 prep on the Linux workstation**:
   - Inventory every `/wamv/*` reference across `*.py`, `*.yaml`, `*.js`, `*.html`. Produce a target topic map for the remap file.
   - Profile `/perception/obstacle_info` publish rate in VRX under realistic load (full mission in `sydney_regatta_DEFAULT`). Record a baseline; it's the comparison point for the Pi 5 measurement.
   - Draft `remap.launch.yaml` aliasing each `/wamv/*` topic to a neutral name (e.g., `/wamv/sensors/gps/gps/fix` → `/gps/fix`). Launch both versions; confirm nothing regresses via the aliases.
   - Stub the bridge node as a pass-through: subscribe to `/control/thrust_cmd`, republish to `/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust`. When the low-level protocol is known, swap the stub body for the real translation.
3. **Shore-comms spec** (paper exercise): measure the dashboard's max useful range from the Linux laptop in the test-lake environment. Decide between WiFi (acceptable up to ~50 m), directional antenna (up to a few hundred metres), or 4G dongle (arbitrary range but metered). Confirm the WAM-V's actual antenna setup when inspecting the CCU.
4. **Nice-to-have**: once the new convention about session-handoff is internalised, tomorrow's session should open by reading `Board.md` + the last two diary entries + `git log --oneline -30`, per the new bootstrap checklist. That's the test of whether the cold-start protocol actually works in practice.
