# 2026-04-12 — Pre-Meeting Scope Plan (Special Work)

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

## Trimmed Scope — 5 Items

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

### 5. Dry-run + any showstopper fixes (~2h, Apr 14 evening)

- Full launch → generate waypoints → start mission → stop → health check
- Fix **only** showstoppers (crashes, broken buttons, blank panels)
- Nothing cosmetic, nothing "while I'm in there"

**Why kept:** catches the worst surprises before the live demo.

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

- **Dashboard ↔ Launch file parameter sync** — 17 mismatched defaults were
  fixed on Apr 13 (HTML input defaults vs `vostok1.launch.yaml`). Any future
  parameter change in the launch file must be mirrored in three places:
  (1) `vostok1.launch.yaml`, (2) `index.html` input defaults,
  (3) `app.js` readInput fallbacks / currentState.config. A systematic
  cross-check should be done whenever parameters are added or tuned.

### Parameter sync safety notes (Apr 13)

Parameters live in three places: ROS2 node Python defaults, launch YAML, and
dashboard (HTML defaults + JS fallbacks). How mismatches behave:

- **Node default ≠ Launch file** — safe. Launch file always overrides at startup.
  Node default only matters if running without the launch file.
- **Launch file ≠ Dashboard HTML** — safe *now*. Apply buttons are disabled until
  first ROS config sync arrives, preventing the dashboard from overwriting correct
  launch values with stale HTML defaults. Dirty-params filtering also means only
  user-modified fields are sent (unless no field was touched, in which case all are
  sent as a fallback — hence the HTML defaults must still match).
- **Dashboard sends unknown param** — safe. Nodes only process keys they recognize
  (`if 'param' in config`).
- **Node expects param dashboard never sends** — safe. Node keeps its launch value.

Fixes applied Apr 13:
- 17 HTML default mismatches corrected to match launch YAML
- `readInput` JS fallback for `min_safe_distance` corrected (15 → 12)
- `currentState.config.min_safe_distance` corrected (10 → 12)
- Apply buttons start `disabled` in HTML, enabled by first `/sputnik/config` message
- OKO and BURAN panels now have Reset Defaults buttons (values from launch YAML)

Mention these verbally in the meeting as known next steps.

## Daily Split (Revised)

| Day | Repo work | Other |
| ----- | --------- | ------- |
| Apr 12 (Sun) | ✅ Items 1–4 all completed (pre-demo safety, repo cleanup, audit, dashboard polish, README rewrite) | PPT outline, teammate sync |
| Apr 13 (Mon) | Screenshots for README/PPT if needed | PPT slides draft |
| Apr 14 (Tue) | Item 4: dashboard polish (~2–3h) + Item 5: dry-run (~2h) | PPT polish, rehearsal |
| Apr 15 (Wed) | — | Meeting |

## Risk Notes

- VRX xacro regression is still the single highest-impact item. Do it first,
  same day as writing this plan.
- The README and PPT overlap — write the README first, reuse its structure
  and screenshots in the slides. Do not let them drift apart.
- If anything slips, cut in this order: **item 4 (polish) → item 5 (dry-run
  shrinks to a quick sanity launch) → item 2 (repo cleanup) → item 3 (README
  becomes a minimal stub)**. Item 1 is non-negotiable.
