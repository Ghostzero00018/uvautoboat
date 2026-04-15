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

## Completed Beyond Original Scope (Apr 14)

In addition to the planned dry-run (Item 7), a comprehensive PPT polish pass was
completed on Apr 14, going well beyond the planned "PPT polish, rehearsal":

- **PPT fact-check against repo code (16 technical claims verified)** — PID values,
  50ms control loop, 30k LiDAR points/scan, obstacle thresholds (<8m / >30s / >45s),
  differential thrust formula, A* enabled by default, reverse behavior
  (0.2s burst / 0.4s pause). Corrections applied:
  - Kalman filter: verified as **2D linear KF with random walk model** (NOT EKF);
    state is `[drift_x, drift_y]` for water/wind drift compensation, not heading
  - "SASS Recovery" → "Anti-Stuck Recovery" (SASS removed from active code)
  - "Pose Estimation (GPS/IMU)" → "GPS/IMU Processing (embedded)" — no separate
    pose node in current architecture
  - "4-level obstacle handling" → "3-level" (detour → A* reroute → skip)
  - Removed stale claim about `gps_imu_pose.py` being active (it's legacy)
- **PPT structural improvements across all 14 visible slides:**
  - Slide 1: Supervisor label added; Dr. Shehu as current, Dr. Lozenguez as former
    supervisor (footnote); school names added; VRX expanded
  - Slide 3: removed VS Code from tech stack (dev tool, not runtime); expanded
    "USV" abbreviation; added "Contribution" line
  - Slide 4: simplified complex block diagram to horizontal pipeline arrow
    (Sensors → OKO → SPUTNIK → BURAN → Thrust); removed duplicate tech stack
  - Slide 5: added WAM-V sensor equipment description
  - Slide 11: fixed "Positioning" line — removed inaccurate "combined at 10 Hz"
  - Slides 13 & 15: rewrote in functional language for non-ROS audience; fixed
    "scan" terminology overload ("scanning path" → "coverage path"); unified
    Kalman filter description across slides
  - Slide 17: replaced "MJPEG" jargon with "live camera feed"; specified
    obstacle parameters; added bidirectional Data Flow arrow
  - Slide 20: added Future Work item — CA pollution simulation + Digital Twin
- **Bilingual presentation script created** (`PPT/assets/presentation_script.md`):
  - Full English + Chinese speaker notes for all 14 slides
  - Comprehensive glossary (27 terms: USV, WAM-V, VRX, ROS 2, nodes, topics,
    ROSBridge, DDS, WebSocket, GPS, IMU, quaternion, yaw, LiDAR, point cloud,
    ENU, PID, Kalman filter, A*, clustering, temporal filtering, differential
    thrust, waypoint, lawnmower, boustrophedon, MJPEG, mission states, project
    naming) with plain-language explanations
  - Delivery tips (5 recommendations)
  - Markdownlint warnings fixed (MD028 blockquote spacing, MD025 single-H1)
- **Repo maintenance (PPT-related):**
  - Fixed all MD060 markdownlint warnings in README.md (table pipe formatting)
  - Created new hybrid SVG logo (`logo_autoboat_v2.svg`) — vector outer ring +
    embedded moorhen PNG center, updated README.md and wiki/Home.md references

## Completed Beyond Original Scope (Apr 15)

The scope plan had Apr 15 as "Meeting day — no repo work". In practice,
significant final-polish work happened in the hours before the meeting,
plus a substantial reverse-backfill of repo documentation from the
presentation script:

- **PPT script expansion for likely supervisor follow-ups:**
  - Kalman filter: expanded glossary entry from 2 sentences to a full
    treatment — history (Kalman 1960), recursive predict/update equations
    with all matrices (x, F, H, Q, R, P, K), why-not-EKF rationale
  - VFH: expanded from brief mention to full 3-step algorithm
    (polar histogram → threshold → pick best gap) + VFH/VFH+/VFH\* variants
    - why-disabled-by-default design rationale
  - Quaternion: expanded with ROS convention `(x,y,z,w)`, REP-103
    right-handed frame, gimbal-lock explanation, yaw extraction formula
    `atan2(2(wz+xy), 1−2(y²+z²))`, Tait-Bryan yaw/pitch/roll breakdown
- **Additional fact-checks against code (2 items):**
  - **VFH state**: verified `use_vfh_bias: false` is the YAML default
    (BURAN ignores VFH); dashboard has a toggle + 4 tuning presets that
    enable it if the operator clicks one; clean worlds use 3-sector
    avoidance, VFH is for cluttered scenarios (buoy fields, piers)
  - **Navigation modes**: verified the YAML runtime default is
    `astar_enabled: true, astar_hybrid_mode: false` → "Runtime A\*" mode
    (reactive detours after 45 s blockage). The dashboard HTML briefly
    shows "Simple Lawnmower" checked on load but syncs to "Runtime A\*"
    within ~1 s from ROS config. "Hybrid Mode" is a separate option
    (pre-planned routes, only useful with prior hazard map).
- **PPT slide reorder:** swapped Slide 4 (System Architecture) and
  Slide 5 (Simulation Environment) per user request — new flow is
  Overview → Simulation (where it runs) → Architecture (how it's
  designed) → Decision Flow → details. Script speaker notes updated
  with new transition phrasing.
- **Smoke references removed** from PPT + script: the demo world is
  `sydney_regatta_DEFAULT` (no smoke sources), so smoke filtering is
  in code but irrelevant to the demo. Replaced with "water reflections,
  the boat itself, and noise" wording; deleted smoke-filter glossary
  entry entirely per user direction.
- **Script repetition audit (Slides 3-8):** tightened overlapping
  content — Slide 5 now focuses purely on architecture rationale
  (removed duplicated sensor-list from Slide 4), Slide 6 becomes a
  question-framing preview (defers module details to Slides 7-8),
  Slide 8 references Kalman filter from Slide 5 instead of repeating.
  Eliminates 3 instances of "said twice in 30 seconds" feedback.
- **Markdownlint cleanup in script:** fixed MD036 (emphasis-as-heading
  on 3+ lines), MD037 (spaces in emphasis around `A*`), MD040
  (unlabelled code blocks on Kalman/VFH equations — added `text`).
- **Reverse-backfill of repo documentation from script (new scope!):**
  - New `wiki/Glossary.md` (440 lines) — extracted all 30+ technical
    terms from the script as a self-contained English reference, organised
    into 9 categories (Robotics/Vehicles, Simulation, Robotics Software,
    Sensors, Algorithms/Math, Planning, Dashboard, Perception Details,
    Project Names)
  - New `wiki/Design_Rationale.md` (228 lines) — single "WHY" document
    consolidating architecture decisions (modular pipeline, no pose node,
    ROSBridge choice), algorithm choices (why linear KF not EKF, why
    VFH off by default, why 3 sectors, why 3-level obstacle fallback),
    full parameter-threshold rationale table (12m/8m/30s/45s/14m/3m/
    Q=0.01/R=0.5 etc.), navigation modes trade-offs, and academic
    references (Kalman 1960, Borenstein & Koren 1991 VFH/VFH+/VFH*,
    A\* 1968, REP-103, ODbL, BSD-2-Clause)
  - Enhanced `wiki/System_Overview.md` — rewrote "Design Philosophy"
    section with concrete rationale + new "Simplicity over sophistication"
    trade-off table; added cross-references to Glossary and Design_Rationale
  - Enhanced `wiki/3D_LIDAR_Processing.md` — added "VFH (Vector Field
    Histogram) — Optional Advanced Avoidance" section with 3-step algorithm
    - why-disabled; added "Threshold Rationale" table explaining each
    pipeline parameter value
  - Enhanced `wiki/SASS.md` — added "Design Evolution" section
    documenting legacy v2.x multi-phase escape → current simple
    "turn toward clearer side" simplification
  - Updated `wiki/Home.md` and `wiki/README_WIKI.md` — added Glossary
    and Design_Rationale to navigation + page listing
  - Zero Python/YAML changes per user constraint — all improvement
    happened in markdown

  **Value:** the presentation script had accumulated weeks of
  fact-checked rationale and terminology. Previously this lived only in
  a one-off presentation document. Now it's permanent, discoverable repo
  documentation — new contributors can find "why 2D linear KF not EKF"
  and "why VFH disabled" without digging through working diaries.

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
| Apr 14 (Tue) | ✅ Item 7: dry-run after ROS 2 Jazzy apt upgrade + rebuild — 46/46 PASS, no regression | ✅ PPT polish (expanded): 16-item fact-check vs code, 14 slides restructured, bilingual script + glossary, logo SVG, README markdownlint fixes |
| Apr 15 (Wed) | ✅ Reverse-backfill of wiki docs from script (2 new + 3 enhanced pages); script expansion (Kalman/VFH/quaternion deep dives); slide 4/5 reorder; smoke removal; repetition cleanup; 2 extra fact-checks (VFH state, nav modes) | Meeting |

## Risk Notes

- ~~VRX xacro regression~~ — ✅ Fixed (Item 1, `patch_vrx.sh` persists it).
- The README and PPT overlap — reuse README structure and screenshots in the slides.
- ✅ All 7 items complete. Repo work done ahead of the Apr 15 meeting.
- Jazzy apt upgrade on Apr 14 was absorbed cleanly — no code changes needed,
  health check still 46/46 PASS.
- ✅ Apr 15 final polish + wiki backfill went well beyond original plan.
  Net result: the work invested in the presentation script became permanent
  repo documentation, with full design-rationale coverage that was previously
  absent.

## Post-Meeting Status (Apr 15)

- ✅ **Supervisor meeting delivered.** PPT presented, demos (dashboard
  overview + full mission video) played, Q&A handled with the oral
  follow-ups prepared in `PPT/assets/presentation_script.md`.

## Open Issues Identified — Next Iteration

The following items are **not blockers** but should be addressed in the
next development cycle:

### 1. Non-standard ROS node names (OKO / SPUTNIK / BURAN)

The current navigation nodes use Russian space-program code-names
(Vostok1 = system name; OKO = perception; SPUTNIK = planning; BURAN =
control). While memorable within the team and in the PPT narrative,
these names **do not follow ROS community conventions**:

- ROS community practice is **functional lowercase_snake_case** names
  that describe what the node does, not branded/thematic names.
  Examples from widely-used ROS projects:
  `perception_node`, `obstacle_detector`, `waypoint_planner`,
  `heading_controller`, `nav2_controller`, `localization_node`.
- **Discoverability cost:** a new contributor searching the repo or the
  community for "perception node" or "path planner" finds nothing; they
  must first learn the project's internal naming scheme.
- **Onboarding cost:** `ros2 node list` output shows
  `oko_perception_node`, `sputnik_planner_node`, `buran_controller_node`
  which requires a mental translation layer before the system makes sense
  to outsiders.

**Proposed rename (decided, full plan in `wiki/Node_Naming_Refactor_Plan.md`):**

| Current | New | Scope |
|:--------|:----|:------|
| OKO / `oko_perception_node` | `lidar_perception_node` | Python file + class + node + entry point |
| SPUTNIK / `sputnik_planner_node` | `waypoint_planner_node` | Python file + class + node + entry point |
| BURAN / `buran_controller_node` | `heading_controller_node` | Python file + class + node + entry point |
| `vostok1_cli` | `autoboat_cli` | Python file + entry point + node |
| `Vostok1` (system name) | `AutoBoat` | Launch file, shell scripts, dashboard dir, docs |
| `vostok1.launch.yaml` | `autoboat.launch.yaml` | File rename |
| `launch_vostok1_complete.sh` | `launch_autoboat_complete.sh` | File rename |
| `health_check_vostok1.sh` | `health_check_autoboat.sh` | File rename |
| `web_dashboard/vostok1/` | `web_dashboard/autoboat/` | Directory rename |
| `/sputnik/*` topics | `/planning/*` | 3 topic renames |
| `oko_min_safe_distance` | `perception_min_safe_distance` | Parameter rename |

**Migration strategy:** two-release deprecation cycle (v3.0 new+old
coexist with warnings; v3.1 old removed). Full 12-step plan with 5 PRs
documented in `wiki/Node_Naming_Refactor_Plan.md`. Impact: ~550+ refs
across 15 markdown files, 3 Python files, 2 shell scripts, and 200+
dashboard refs.

**Priority:** Medium. Not a blocker; quality improvement for long-term
maintainability and community discoverability.
