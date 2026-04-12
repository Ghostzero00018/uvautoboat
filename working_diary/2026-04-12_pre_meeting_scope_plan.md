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

### 3. README rewrite (~½ day) ★ highest demo value

The README is what the supervisor will open first. Keep it short:

- Project one-liner + simple architecture sketch (SPUTNIK / BURAN / OKO /
  VOSTOK1 dashboard — one sentence each)
- Quickstart: one copy-pasteable launch block
- Two or three dashboard screenshots (captured while the dashboard is already
  open for testing — no separate session)
- Honest "What works / what's in progress" status table

**Why kept:** doubles as source material for the PPT — writing this feeds the
slides directly, so the time isn't duplicated.

### 4. Dashboard polish (~2–3h, visible wins only)

Constrain to visible-at-a-glance fixes:

- Config panel layout (already on pending list)
- Button/label consistency — caps, spacing, obvious typos
- Verify health check panel + live trajectory render cleanly at 1920×1080
  (projector resolution) — this is what the supervisor will actually see
- **No** new features, **no** new topics, **no** new services, **no**
  refactors. If a fix takes more than 20 minutes, defer it.

**Why kept:** the dashboard is the most visible artifact of the project. A
small polish pass goes a long way in the demo.

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

Mention these verbally in the meeting as known next steps.

## Daily Split (Revised)

| Day | Repo work | Other |
| ----- | --------- | ------- |
| Apr 12 (Sun) | Item 1: pre-demo safety (~1h) + Item 2: repo cleanup (~2h) | PPT outline, teammate sync |
| Apr 13 (Mon) | Item 3: README rewrite + screenshots (~½ day) | PPT slides draft |
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
