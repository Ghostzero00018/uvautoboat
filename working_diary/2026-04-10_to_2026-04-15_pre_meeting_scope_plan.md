# 2026-04-10 to 2026-04-15 — Pre-Meeting Scope Plan (Special Work)

## Context

Supervisor meeting scheduled for **2026-04-15** (3 days away). The meeting is a
project introduction — the audience is the supervisor, not a code review.

**Time budget is tight.** These 3 days are also split with:

- Teammate meetings
- Preparing the introduction PPT (primary deliverable for the meeting)
- Repo work (this plan — secondary)

So the scope below is **aggressively trimmed**. Anything that isn't directly
visible to the supervisor on Apr 15 is cut.

## Repo Status Snapshot (2026-04-12)

- **uvautoboat (main):** Clean, up-to-date with origin. Last commit `6c2780e test`.
- **vrx (jazzy):** Clean, up-to-date. Upstream at v3.1.0.
- ⚠️ **Regression since 2026-04-10:** `publish_model_pose` in
  `src/vrx/vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro:94` is back to
  `false`. The local edit from the VRX investigation session is gone. VRX LiDAR
  will visualize at world origin again until re-applied.

## Trimmed Scope — 7 Items

### 1. Pre-demo safety (~1h) — do first, non-negotiable ✅ DONE

- [x] Re-apply `publish_model_pose=true` at `wamv_gazebo.urdf.xacro:94`.
- [x] Stash the fix in `one_click_launch_all/patch_vrx.sh` called by the
  launcher so it survives a future `git pull` of VRX.
- [x] Run `health_check_vostok1.sh` — 45/45 PASS confirmed.

**Why kept:** if forgotten, LiDAR renders at origin during demo and undermines
the whole perception story. Cheapest + highest-impact item.

### 2. Repo cleanup (~2h, tightly scoped) ✅ DONE

- [x] Scanned for orphan files — no new orphans found
- [x] Deleted `__pycache__/` in plan + control (stale bytecode)
- [x] Deleted empty `web_dashboard/vostok1/test/`
- [x] Consolidated duplicate pkill block in launcher → single `cleanup` call
- [x] Moved `oko_perception_fixed.py` + `buran_controller_fixed.py` →
  `legacy/fixed_variants/`; removed entry points from setup.py; updated
  USER_MANUAL.md tree and legacy/DEPRECATED.md
- [x] Build verified: 7 packages clean, health check 45/45 PASS
- [x] Audited vostok1_cli.py — marked `--mode vostok1` deprecated, added
  runtime warning
- [x] Added emergency_stop handling to SPUTNIK (distinct `EMERGENCY_STOP`
  state) + BURAN (resets escape state) + dashboard (red pulsing badge) + CLI
- [x] Added CLI args: `--safe-dist`, `--approach-dist`, `--approach-factor`
- [x] Removed dead code: `panic_stop`, `force_resume`, `clear_stop_override`
  in BURAN; `STOP`/`STOPPED`/`PANIC` states; `restart_mission` in dashboard
- [x] Moved 7 unused standalone utilities to `legacy/utilities/`
- [x] Fixed package.xml: added missing `std_srvs`, removed 17 unused deps

**Why kept:** first impression when the supervisor browses the repo tree. A
tidy tree signals a maintained project.

### 3. README rewrite (~½ day) ★ highest demo value ✅ DONE

- [x] Added emojis to all section headers
- [x] Added Umaralfa-coder to current maintainers
- [x] Expanded architecture with supporting components table + dashboard in diagram
- [x] Added "What Works / What's In Progress" status table
- [x] Added `oko_min_safe_distance` to key parameters, `emergency` to CLI section
- [x] Added troubleshooting entries (LiDAR origin fix, DDS lag)
- [x] Added link to `legacy/DEPRECATED.md` in documentation section
- [x] Marked SASS anti-stuck and CLI as needs-testing

**Why kept:** doubles as source material for the PPT — writing this feeds the
slides directly, so the time isn't duplicated.

### 4. Dashboard polish (~2–3h, visible wins only) ✅ DONE (folded into item 2)

Done ahead of schedule during the audit/cleanup pass:

- [x] Added missing CSS badge styles for `init`, `waiting_confirm`, `driving`
- [x] Health check UX: removed double-clear flicker, added `[DONE]` completion
  line with elapsed time, `[SYSTEM]` lines styled blue
- [x] Added JSON export buttons to 4 panels (Health Check, System Logs,
  ROS2 Terminal, Mission Control)
- [x] Renamed `oko_min_safe_distance` to prevent dashboard config collision
- [x] Removed dead `restart_mission` flag, dead state strings from UI arrays
- [x] Added `EMERGENCY_STOP` state badge (red pulsing)

### 5. Dashboard config system + full audit (Apr 13) ✅ DONE (unplanned)

Emerged from testing — discovered param broadcast issues and stale defaults:

- [x] **Dirty-params fix**: Apply buttons now send only changed fields, not all
- [x] **17 HTML default mismatches** synced to match `vostok1.launch.yaml`
- [x] **Apply buttons disabled** until first ROS config sync (prevents stale overwrites)
- [x] **Reset Defaults** buttons added to OKO and BURAN panels (with hint notes)
- [x] **Reset race condition** fixed: Reset marks inputs dirty so ROS sync can't overwrite
- [x] **`oko_critical_distance` rename**: OKO's `critical_distance` → `oko_critical_distance`
  to fix collision with BURAN (same pattern as `oko_min_safe_distance`)
- [x] **Full param collision audit**: confirmed 0 remaining collisions across
  OKO (17 keys), BURAN (21 keys), SPUTNIK (14 keys)
- [x] **app.js audit**: removed dead `setROS2Parameter()`, `no-go-zones`,
  `escape-history` refs, fixed `escapeHistory` ReferenceError
- [x] **CSS fixes**: `stat-label` mismatch, duplicate keyframes, emergency-pulse conflict
- [x] **HTML fixes**: camera panel nesting, unescaped entity, `step="any"` for typing,
  `DEBUG_MODE` const→let
- [x] **Dashboard README** rewritten from scratch (was 4 months outdated)
- [x] **USER_MANUAL** updated: 14 edits (structure, states, panels, CLI, troubleshooting)
- [x] **Board.md** updated: dates DD-MM-YYYY, v9.0, 5 milestones, 9 resolved issues
- [x] **Wiki deep scan**: 8 files fixed (ports, deprecated systems, param names, SASS rewrite)
- [x] **`WIKI_SUMMARY.md`** moved to `legacy/misc/` (historical Dec 2025 doc)
- [x] Health check verified: **45/45 PASS, 0 WARN** after all changes

### 6. Teammate onboarding fix + health check audit (Apr 13 evening) ✅ DONE (unplanned)

Triggered by teammate's dashboard issues on his own laptop:

- [x] **USER_MANUAL**: Full "Environment Setup (~/.bashrc)" section — copy-paste
  bashrc block, verify commands, "Do NOT add" warnings for unnecessary GZ exports,
  ROS_DOMAIN_ID team guidance
- [x] **USER_MANUAL**: 6-step "Dashboard Connection Diagnostics" troubleshooting
  (ss, ROS_DOMAIN_ID, topic list, browser console, firewall)
- [x] **README**: Installation step updated with complete bashrc block
- [x] **wiki/Installation_Guide**: Rewrote Step 7 (bashrc setup), removed stale
  Gazebo Classic advice
- [x] **wiki/Common_Issues**: Rewrote "Dashboard Not Connecting" with diagnostic flow
- [x] **Dashboard README**: Added internet prerequisite, expanded troubleshooting
- [x] **app.js**: `ws://localhost:9090` → dynamic `window.location.hostname`
  (matches camera stream pattern, enables remote access)
- [x] **.gitignore**: Removed `COLCON_IGNORE` entry so `legacy/COLCON_IGNORE` is
  tracked by git (teammate was building legacy environment_plugins as 8th package)
- [x] **Health check audit**: DDS priming 1.5s→3s, state detection timeout 3s→8s,
  fallback ACTIVE→IDLE, publisher retry on fail, EMERGENCY_STOP in active states,
  optional nodes WARN→INFO, added health_check_service node check, runtime estimate
  updated
- [x] Health check verified: **46/46 PASS, 0 WARN** after all changes

### 7. Dry-run + any showstopper fixes (Apr 14) ✅ DONE

Happened alongside the ROS 2 Jazzy `apt update` + rebuild on Apr 14:

- [x] Full launch (Gazebo + dashboard + rosbridge + web video + RViz) — clean
- [x] Mission start → boat drove normally, no regression post-upgrade
- [x] Health check: **46/46 PASS, 0 WARN** in ACTIVE state (DRIVING)
- [x] Gazebo/rosbridge/web-video/RViz startup logs reviewed — only known-benign
  warnings (QT QML binding loops, libEGL NVIDIA hybrid-GPU noise, Ogre2
  visibility mask, KDL root-link inertia, dartsim mesh limitation)
- No showstoppers found, no fixes needed

**Why kept:** catches the worst surprises before the live demo.

> **Note:** Item numbering shifted — dry-run was originally item 6, now item 7
> after teammate onboarding fix was inserted.

## Still Cut

- Core-node + launch comment pass — invisible to supervisor, high chance of
  introducing typos or regressions under time pressure
- Deep repo reorganization — any move bigger than a dead-file delete

## Explicitly OUT of Scope

- Obstacle-avoidance plan (`obstacle-avoidance-fix.md`)
- VRX upstream PR / issue #876 comment posts
- VFH steering, OKO LiDAR tuning, pier A\* routing
- `request_replan()` AttributeError fix in BURAN:662
- Any logic changes in core nodes

Mention these verbally in the meeting as known next steps.

## Completed Beyond Original Scope (Apr 13)

The following were not in the original plan but emerged from testing and auditing:

- **Dashboard config system** — dirty-params filtering, Apply-disabled-until-sync,
  Reset Defaults buttons with race condition fix
- **Parameter collision resolution** — `oko_min_safe_distance` (Apr 12) and
  `oko_critical_distance` (Apr 13) renames across all files
- **Full dashboard audit** — HTML/CSS/JS stale code removal, default sync, input fixes
- **Wiki deep scan** — 8 files updated (ports, deprecated systems, param names, SASS)
- **Board.md, USER_MANUAL, dashboard README** — all brought up to date
- **Teammate onboarding fix** — bashrc guide, dashboard diagnostics, dynamic WebSocket
  URL, COLCON_IGNORE tracked by git, health check audit (46/46 PASS)

### Parameter sync rule (for future reference)

Any parameter change must be mirrored in three places:
(1) `vostok1.launch.yaml`, (2) `index.html` input defaults,
(3) `app.js` readInput fallbacks / currentState.config / OKO_DEFAULTS / BURAN_DEFAULTS.

Apply buttons are disabled until first ROS config sync, and dirty-params filtering
prevents unchanged fields from being sent. Reset Defaults marks inputs dirty to
prevent the 1-second ROS sync from overwriting before Apply is clicked.

## Daily Split (Revised)

| Day | Repo work | Other |
| ----- | --------- | ------- |
| Apr 12 (Sun) | ✅ Items 1–4 all completed (pre-demo safety, repo cleanup, audit, dashboard polish, README rewrite) | PPT outline, teammate sync |
| Apr 13 (Mon) | ✅ Items 5–6: dashboard config system, full audit, param collision fixes, wiki deep scan, docs update, teammate onboarding fix, health check audit | PPT slides draft |
| Apr 14 (Tue) | ✅ Item 7: dry-run after ROS 2 Jazzy apt upgrade + rebuild — 46/46 PASS, no regression | PPT polish, rehearsal |
| Apr 15 (Wed) | — | Meeting |

## Risk Notes

- ~~VRX xacro regression~~ — ✅ Fixed (Item 1, `patch_vrx.sh` persists it).
- The README and PPT overlap — reuse README structure and screenshots in the slides.
- ✅ All 7 items complete. Repo work done ahead of the Apr 15 meeting.
- Jazzy apt upgrade on Apr 14 was absorbed cleanly — no code changes needed,
  health check still 46/46 PASS.
