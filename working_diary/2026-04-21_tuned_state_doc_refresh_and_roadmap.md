# 2026-04-21 — Health-check TUNED state, doc refresh, and research roadmap

## Context

Tuesday after a large Tier 2 close-out the previous evening. Today's
session had three threads: (1) a small but useful polish to the health
check based on a real-usage annoyance, (2) a sweep through the wiki
and Board to synchronise documentation with the reality the 20/04
commits left behind, and (3) re-opening the strategic scope
conversation now that the formal internship objectives document is in
hand. No navigation-code changes today beyond the TUNED-state
parameter additions; the bulk of the day was documentation.

## Health check — 4-state parameter validation (TUNED)

Triggered by a concrete irritation: running the health check after a
dashboard preset press (Buoy Field in particular) printed six
`[WARN] param = X (expected Y)` lines, one for each preset-modified
parameter. Every one of those warnings was a legitimate user tuning,
not a failure. The WARN signal had quietly drifted into noise — it
fired every time the operator touched a preset button, and an
operator couldn't distinguish "runtime intentionally differs from
YAML" from "something actually went wrong inside the node."

### Design

Added a `config_tuned` boolean parameter to each of the three nodes
(`waypoint_planner.py`, `heading_controller.py`,
`lidar_perception.py`), declared `False` at launch and flipped to
`True` in each node's `config_callback` after the first successful
`/planning/set_config` parse. The flip is idempotent via an
`if not self.get_parameter('config_tuned').value:` guard — subsequent
set_config updates don't re-set it. Health check reads this flag once
per node via a new `is_node_tuned` helper and threads the result into
each `check_param` call as a fourth argument.

Result: four outcomes per parameter rather than three.

| Runtime vs baseline | `config_tuned` | State |
|:-------------------|:--------------:|:-----:|
| equal | any | `PASS` (green, counted as healthy) |
| differs | `True` | `TUNED` (magenta, counted as healthy) |
| differs | `False` | `WARN` (yellow, **unexpected drift** — actionable) |
| unreadable | any | `FAIL` (red) |

Summary line now reads `PASS: X  TUNED: Y  FAIL: Z  WARN: W`. WARN
regains a meaningful signal: it fires only when runtime diverges from
YAML *without* the user having applied a config — exactly the case an
operator should investigate rather than shrug off.

### Dashboard follow-up

Initial test came back with `[TUNED]` lines rendering in white in the
dashboard's health check panel. Traced to `classifyHealthLine()` in
`app.js` — its regex list didn't cover `[TUNED]`, so those lines fell
through to the default styling. One-line regex addition plus a
matching `.terminal-line.tuned { color: #ba68c8; }` rule in
`style_merged.css` (mirrors the terminal ANSI magenta). Fix went in
the same commit.

### Live verification

Buoy-Field preset applied, then health check run. Final tally:

```text
PASS: 40  TUNED: 6  FAIL: 0  WARN: 0
```

Six TUNED lines rendered correctly in magenta in the dashboard
terminal panel; the six parameters they called out are exactly the
ones Buoy Field changes (`obstacle_slow_factor`, `critical_distance`,
`min_safe_distance` on the controller;
`perception_critical_distance`, `min_height`, `max_range` on
perception). WARN was zero — no accidental drift.

## Post-Tier-2 audit — confirmation pass

After the previous evening's Tier 2 commits went in, ran a repo-wide
sweep to catch any newly-stale references. Delegated to an Explore
agent guided against today's actual deletions and refactors; verified
the agent's specific findings against the live files before trusting
them.

Result: **clean tree.** Three findings the agent surfaced turned out
to be false positives on closer reading (comments I had intentionally
written to document the *new* design, not stale references to deleted
code). No lingering mentions of `moving_obstacles`, `SENSOR_TIMEOUT`,
`escape_start_time`, `in_hazard_zone`, `waiting-sync`, or the
`apply-waiting-label` span. No AI-tooling leaks (pre-commit grep
returned zero). No now-dead Python identifiers in the active tree.

Two `sleep 8` survivors in `launch_autoboat_complete.sh` (post-RViz
PID status spacing, pre-browser-open padding) were flagged then
marked Tier 4 "defensible on review" — both are cushions for
human-visible UI timing rather than bandages masking ROS-level race
conditions. Left in place.

The health check's own per-topic retry loop (2-attempt × 2 s fixed
sleep in `check_publisher`) was also reviewed. Arguably not a true
bandage — the retry runs once per topic and only when the first probe
returns empty; fails fast in the common case and gives DDS discovery
a brief grace window when it doesn't. Also promoted to Tier 4. On
Pi 5 under CPU load the cushion may even earn its keep.

## Markdown and Board refresh

Second half of the day was synchronising prose-level documentation
with the reality the 20/04 commits left behind.

### Audit

Scanned `.md` files across the active tree. Three tiers surfaced:

- **Tier A (factually wrong):** `wiki/Glossary.md` Health Check entry
  still claimed "parameter values matching YAML" and "46/46 PASS
  means the system is correctly wired." Both statements had been
  accurate before the 4-state upgrade; neither is now.
- **Tier B (incomplete but not wrong):** `USER_MANUAL.md` ASCII
  topology diagram listed `/planning/mission_command` as the sole
  dashboard-to-planner channel; after the Tier 2 work there are now
  three channels (mission_command topic for most commands, two
  Trigger services for stop/generate, a latched Bool topic for
  e-stop). Same gap in `web_dashboard/autoboat/README_autoboat_dashboard.md`.
- **Tier C (optional polish):** `README.md` health check blurb could
  mention 4-state semantics; `USER_MANUAL.md` troubleshooting row for
  "health check false FAILs" still recommended a 5-second wait
  (obsolete now that the health check has a built-in DDS-prime loop).

Applied all three tiers. Added a Services sub-table in USER_MANUAL
under the existing ROS 2 Topics section, documenting `Trigger` types
for stop/generate.

### Board.md

Stale in three places. Bumped Last-Updated stamps (twice),
incremented Document Version (9.5 → 9.6), appended today's and
yesterday's milestones to the Timeline table (seven new rows covering
the Tier 2 close-out, the Kalman wire-in, launcher readiness polls,
`moving_obstacles` delete, TUNED state, and the doc refresh itself).
Added seven rows to the Phase 4 Completed table and moved three rows
in the Phase 5 Prep Tasks table from `⬜` to `🟡` or `✅` based on
what the scope plan already delivers.

Didn't touch the Phase 5 progress percentage (still shown as 0%) —
defensible either way, and "actual hardware not yet arrived" argues
for keeping it at 0% until the Pi 5 is physically on the bench.

### Other stale stamps

Grep across the tree for `Last [Uu]pdated` surfaced two more: the
wiki's `README_WIKI.md` and `Home.md` still carried 19-04-2026.
Bumped both to 21-04-2026. Legacy tree and `working_diary/` historical
entries left untouched by design.

## Research scope — internship objectives clarified

Mid-day the formal objectives document arrived: *"Aquatic Drone–Based
Digital Twin for Spatio-Temporal Water Quality Monitoring"* (IMT Nord
Europe × IMT Mines Alès, supervised by A. Shehu and G. Zacharewicz).
Three deliverables:

1. Integration of real drone sensor data into the simulator via ROS.
2. Implement computational models (cellular automata explicitly
   named) to simulate the spatio-temporal evolution of water quality
   parameters, displayed as a map in the existing dashboard.
3. Validate generated maps against regional datasets
   (CESER / ECRIN / VERD-Eau / CASTREau / CAP'Eau); ML for trend
   prediction and anomaly detection, time-permitting.

This re-frames what the current repo represents. The navigation
stack (perception, planning, control, dashboard, VRX integration,
Phase 5 hardware prep) is the **foundation layer** that supports the
research deliverables — it is *not* the research deliverables
themselves. Nothing wasted — without reliable navigation + sensor
streaming + mission management, the whole water-quality-monitoring
mission can't function — but the gap between "current state" and
"internship complete" is larger than the Board's narrative had
implied.

### Gap analysis

| Deliverable | Current repo | Gap |
|:------------|:------------:|:----|
| ROS-based real data integration | ⚠ foundation only | Water quality sensor pipeline absent; same architectural pattern as existing sensors though |
| CA spatio-temporal water quality modeling | ❌ | No CA node; no spatial grid; no propagation rule |
| Water quality map in existing dashboard | ⚠ Leaflet map exists for position/waypoints | Heatmap / contour overlay layer absent |
| Regional dataset validation | ❌ | No ingestion, no metric |
| ML for trend / anomaly (time-permitting) | ❌ | — |

### Phased path forward (sketch)

| Phase | Deliverable | Blocking dependency |
|:-----:|:------------|:--------------------|
| A | Mock water quality sensor node publishing synthetic readings tied to GPS position | None — unblocks B and C without probe hardware |
| B | CA-based propagation node (2D grid over survey area) | Phase A |
| C | Dashboard heatmap overlay on existing Leaflet map | Phase B |
| D | Real probe integration, replacing the mock | Probe hardware availability |
| E | Regional dataset validation + ML anomaly / trend detection | Phase C + dataset access |

Phase A is the natural next piece of technical work. Supervisor
confirmation on the specific parameter set (pH? turbidity? DO?
temperature? conductivity?) is expected later this week and is the
only strict blocker on Phase A detailed design; everything else can
be scoped now.

## Wiki Roadmap page

Consolidated the Phase 5 scope summary (pointing at the detailed
`working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`
for the full /wamv/* inventory, `remap.launch.yaml` paper design,
bridge-node pseudocode, and 24-item supervisor checklist) with the
new research-extensions architecture diagram and a consulting-style
Phase A scope. Landed as a new wiki page, `wiki/Roadmap.md`, linked
from `wiki/Home.md` under a new "Roadmap" section.

Phase A section is deliberately consultative rather than
prescriptive: it surfaces seven open design questions (parameter set,
message type, publish rate, spatial synthesis model, topic name,
package location, payload schema) each with options, trade-offs, and
a recommendation — to be confirmed with the supervisor before code
lands. Recorded the message schema as a generic parameter dict
(`{"params": {"pH": ..., "turbidity_ntu": ..., ...}}`) so the
supervisor's answer about which parameters to include becomes a 3-line
change rather than a protocol rewrite.

The scope plan in `working_diary/` is explicitly preserved as the
detailed Phase 5 reference. The new wiki page summarises and links
rather than duplicates — diary entries stay append-only historical by
design.

## Afternoon — doc polish wave

The morning closed with the Roadmap + Board refresh. The afternoon was a
batch of small, independently scoped doc-polish items done back-to-back:

- **Absolute URL for the USER_MANUAL link on the wiki's Home page**
  (9107b66). Home.md pointed at `../USER_MANUAL.md` — fine when rendered
  inside the repo tree on GitHub, but the GitHub Wiki is a separate repo,
  so the relative target 404s on the wiki side.
- **USER_MANUAL stale-fact sweep + VRX framing reword** (7fe98f5). Phase
  Status table realigned to the Board (Phase 4 = 90%, Phase 5 row added).
  Perception pipeline table corrected — the earlier prose claimed range
  5–50 m, height −15 to +10 m, temporal 3/5, clustering 2 m eps — actual
  runtime is 2.2–100 m / −1.2 to 1.5 m / 2/3 / 3 m. The phantom "velocity
  estimation" step was dropped (pipeline was removed 20/04). Wiki doc
  table missing Design_Rationale, Glossary, Roadmap, Dashboard_Security,
  Node_Naming_Refactor_Plan — added. `Perception v2.0` version label
  stripped. Performance specs row "Control Loop Frequency 30 Hz" → 20 Hz
  (actual). Also project-framing reword: USER_MANUAL, README, Home.md,
  System_Overview, dashboard README and two USER_MANUAL lines all moved
  from "for the Virtual RobotX (VRX) competition" to "research project
  using the VRX simulation platform" — the internship is not a competition
  entry and the old framing implied otherwise.
- **PROJET-17 course tag dropped from headers and banners** (f5a60e7).
  Seven sites across README, USER_MANUAL, launcher script, launch YAML,
  and wiki Quick Start. The course assignment ID had outlived its
  relevance (the project is now a research internship).
- **Xacro realigned to VRX upstream** (89d048e). Found that
  `test_environment/wamv_3d_lidar.xacro` — the file whose own header claims
  to be "VRX Official Default Configuration, do NOT modify" — had an edited
  horizontal scan range (`-pi/6` to `7*pi/6`, i.e. 240°) while the VRX
  upstream is `-pi` to `pi` (full 360°). Three other files had inconsistent
  pasted xacro blocks with yet more values. Patched the main copy to
  byte-match upstream, removed the pasted blocks in USER_MANUAL and the
  launcher's leading comment. Also: the launcher's patch script only
  touches `wamv_gazebo.urdf.xacro` for `publish_model_pose`, not the LiDAR
  xacro, so the simulation was running upstream defaults regardless — the
  edited local copy was inert.

## Launcher + health-check cleanup pass

(ca8253c) Two small fixes after a local audit of the two shell scripts:

- `launch_autoboat_complete.sh` printed `Gazebo: http://localhost:11345`
  in the "System Status" block at startup. That port was Gazebo Classic's
  gzserver/gzclient TCP protocol (not HTTP); Harmonic doesn't use it at
  all. Removed.
- `health_check_autoboat.sh` had phantom planner states (`RUNNING`,
  `WAYPOINTS_PREVIEW`) in its `ACTIVE_STATES` list. Planner never emits
  either, so the check was carrying dead literals. Dropped.

## Hazard-zone feature fully deprecated

Mid-afternoon scope decision. The hazard-zone boxes feature (operator-declared
no-go rectangles from the legacy AllInOneStack monolith) had been dormant for
months — `hazard_enabled: False` by default in YAML, nothing in the active
tree flipping it true, no dashboard control exposing it, no runtime path
exercising it. The only place actual box values lived was
`legacy/all_in_one/hazard_world_boxes.yaml`. Discussed partial vs full
removal; landed on full.

Scope ended up being ~230 net LOC deleted across 11 files (32c409d):

- Planner: 5 hazard_*parameter declares + 4 methods (`_parse_hazard_boxes`,
  `_world_boxes_to_local`, `_segment_intersects_hazard`,
  `plan_detour_around_hazard`); `AStarSolver.plan` no longer takes a
  `hazard_boxes` param; the go_home "hazard-aware planning" branch removed;
  hybrid and runtime A* detour sites no longer construct `hazard_blocks`;
  publish_config no longer emits `hazard_enabled` / `hazard_boxes_count`.
- CLI: four `--hazard-*` args removed.
- Launch YAML: three `hazard_*` entries removed; `plan_avoid_margin` comment
  reworded to reference "A*safety margin" since A* still uses it.
- Dashboard `app.js`: four `hazard_enabled` config-dict entries removed.
- Prose: six wiki/USER_MANUAL files updated to drop hazard-zone from
  feature lists and ASCII diagrams. Board.md safety-plan row reworded
  from "enable `hazard_enabled: true` with test-lake polygon" to
  "geofence mechanism TBD — re-introducing hazard polygons is on the
  table" (honest about its future-work status).

Bundled into the same commit: **planner config-callback sync fix**. The
planner's `config_callback` updated `self.lanes` / `self.scan_length` /
`self.scan_width` on receipt of a `/planning/set_config` but never called
`set_parameters` to reflect those values in the ROS param server, so the
health check always showed baseline YAML values regardless of user tuning.
Added the same sync loop the controller already had (generic
`hasattr(self, key)` pattern) plus explicit `set_parameters` calls for the
three A*params (`astar_resolution` / `astar_safety_margin` /
`astar_max_expansions`) that live on `self.astar.*` and bypass the generic
loop. Same commit also added those three A* params to the health check's
planner section, bumping total from 46 → 49 checks.

## Audit round 2 — fire-and-hope tail + orphan handlers

Spawned Ultraplan for a follow-up sweep: fire-and-hope patterns remaining
after 20/04, CLI drift, teleop audit. Findings fell into five classes and
landed as 9155cdf:

- **Dead state literals**: `RUNNING` and `WAYPOINTS_PREVIEW` appeared in
  the CLI and dashboard but the planner never emits either. Five sites in
  `app.js`, two in `autoboat_cli.py` — all dropped.
- **Orphan `mission_command` handlers**: the planner and controller both
  still had topic-based branches for `generate_waypoints`, `emergency_stop`,
  and `stop_mission` — paths that no caller exercises post-20/04 (those use
  `std_srvs/Trigger` services and the latched Bool channel). Removed.
- **Silent `except Exception: pass`** on the CLI's three JSON callbacks
  (`mission_status_callback`, `config_callback`, `controller_status_callback`).
  The dashboard's JS side was upgraded to visible `logBadJson` in the 20/04
  Tier 2 pass; the CLI was missed. Added a small `_log_bad_json(topic, exc)`
  helper with a 5-second per-topic throttle.
- **Hand-tuned `time.sleep` + `spin_once` after publish** in four CLI
  command methods (start / resume / go_home / emergency). Same class of
  fire-and-hope the 20/04 Tier 2 work removed for stop/generate/e-stop.
  Added `_wait_for_state(expected, timeout=2.0) -> (reached, observed)` and
  replaced the sleep+spin pattern. Decision: stayed with subscribe-and-
  observe (Option B) rather than the full Trigger-service migration
  (Option A) — Option A would touch planner, CLI, and dashboard and is
  overkill for what turns out to be purely a CLI ergonomic concern.
- **Dead attribute**: `keyboard_teleop.py` had `self.last_throttle_key_time`
  assigned but never read. Dropped.

Also: one-shot CLI commands (`autoboat_cli start` etc.) sometimes race the
DDS late-joiner — the node lives briefly and the `_wait_for_state` window
can close before the planner's next `mission_status` publish lands. Not a
bug; the observer is honest about what it saw. Documented in the CLI module
docstring and recommended interactive mode for command sequences.

## Round 3 — doc/comment sync + named escape constants

Closing polish pass on the day (a57b176). Two categories:

- **Comment/doc drift** caused by 9155cdf: a controller docstring still
  claimed "highest priority STOP latch" (the latch moved to
  `emergency_stop_latched_callback`); the CLI's `status` command had two
  inline `RUNNING` references; the dashboard README's state-badge list and
  `index.html`'s state-chip tooltip had the now-dead `IDLE` /
  `WAYPOINTS_PREVIEW` but were missing `INIT` / `WAITING_CONFIRM`; three
  broken intra-wiki links in `Common_Issues.md` pointed at pages that have
  never existed.
- **Named constants in heading_controller.py**: two magic numbers had been
  flagged in prior audits but never extracted — `-1200.0` for the CQB
  micro-reverse pulse and `450.0` for the stuck-escape spin-in-place.
  Added `REVERSE_BURST_THRUST` and `ESCAPE_TURN_POWER` to the
  `CONTROL CONSTANTS` block; call sites reference them. Pure rename, values
  unchanged. Also collapsed a duplicate "Heading Controller - ..." line in
  the startup log banner.

Residual `IDLE` references in the dashboard JS and CLI code were noted but
deliberately deferred — the dashboard uses `IDLE` as a self-consistent
client-side default label (meaning "no mission_status received yet"), and
the UI button-enable guards check for it. The planner doesn't emit `IDLE`
and doesn't need to; the semantics are correct as-is. Aligning it to
`INIT` is a coordinated rename across ~12 sites with no behaviour benefit.

## Stale CLI status tip reworded

Last item of the day (87b3034). The CLI `status` command printed a tip
reading "PID/Speed are set via CLI but not broadcast by controller" and
pointed at `ros2 param get /heading_controller kp`. Both halves were stale
after today's sync-loop fix (PID/Speed *are* now reflected in the param
server on every `/planning/set_config`) and the node name is actually
`heading_controller_node`. Reworded to `"Verify runtime param values with
e.g.: ros2 param get /heading_controller_node kp"`.

## Commits landed

```text
87b3034 docs: Correct CLI status tip — PID/Speed synced to ROS params, fix node name
a57b176 refactor: Post-9155cdf docs/comment sync + escape thrust constants
9155cdf refactor: Drop dead state literals and orphan mission_command handlers
32c409d refactor: Deprecate hazards; fix planner config sync; +A* health checks
ca8253c fix: Drop bogus Gazebo:11345 URL and phantom planner states
89d048e fix: Align test_environment LiDAR xacro to VRX upstream; drop stale pastes
f5a60e7 docs: Drop obsolete PROJET-17 course tag from headers and banners
7fe98f5 docs: USER_MANUAL fact sweep and VRX framing fix
9107b66 docs: Use absolute URL for USER_MANUAL link on wiki Home
7beee22 docs: Add wiki Roadmap (Phase 5 summary + research extensions + Phase A scope)
bb20c38 docs: Refresh Board timeline + post-Tier-2 doc sync to 21-04-2026
13012cb docs: Append TUNED health-check state section to 2026-04-20 diary
4606b2d feat: Health check distinguishes baseline vs user-tuned params (TUNED state)
```

## Next steps

1. **Supervisor conversation (this week)** — confirm the water quality
   parameter set for Phase A; confirm CCU low-level architecture for
   Phase 5. Both are single-conversation blockers on otherwise-scoped
   work. Unchanged from this morning.
2. **Phase A implementation** (after supervisor answer) — new
   `water_quality/` package, mock sensor node publishing
   `/water_quality/readings` at 1 Hz with a linear-gradient synthesis
   model and small Gaussian noise. Estimated one focused session of
   2–3 hours.
3. **Residual `IDLE` alignment** — deferred from round 3. Semantic
   polish across ~12 dashboard JS sites + two CLI sites; no bug, just
   terminology unification if we want it later.
4. **Pier / bank stuck behaviour** — still the open navigation issue
   from the 20/04 pressure test. Unrelated to the research roadmap and
   could be tackled in parallel.
5. **Phase 5 prep residuals** — `remap.launch.yaml` as a runnable file
   (paper design already in the scope plan), and the perception-rate
   profiling that still shows `⬜` on the Board.

## Supplementary audit (late evening, post-doc-polish round)

Following the closing-polish commits above, ran a broader read-only
inspection across the active code tree to surface issues not yet on
any backlog. Two-part sweep: concrete investigation of the two
deferred Next-steps items (residual `IDLE` alignment + Phase 5 prep
residuals), plus a wider code-level + cross-file consistency audit.

No code edits made in this round — all findings documented here for
triage on 22/04.

### Residual `IDLE` alignment — complete site inventory

Actual count: **16 dashboard sites + 2 CLI sites = 18 total** (this
morning's diary estimate of "~12 + 2" was rounded; real total is
slightly higher).

**Dashboard sites (16):**

- `README_autoboat_dashboard.md:78` — Anti-Stuck panel direction docs
  (LEFT/RIGHT/**IDLE**)
- `index.html:203` — Escape-direction tooltip text
- `app.js:43, 66` — initial `missionState.state` default on two
  parallel objects (pre-first-message)
- `app.js:802` — reset path via
  `updateMissionControlUI({state: 'IDLE', ...})`
- `app.js:1126, 1185` — `data.escape_direction || 'IDLE'` fallback
- `app.js:1129` — `'IDLE | Attente'` display text for IDLE direction
- `app.js:1522, 2251` — inline comments mentioning `INIT/IDLE`
- `app.js:1531, 2253` — `['INIT', 'IDLE'].includes(state)` guards
- `app.js:2162` — `(state.state || 'IDLE').toString()...` fallback
- `app.js:2201` — `'IDLE': 'Idle | En attente'` in `stateLabels` map
- `app.js:2262, 2267` — state lists for Start / Go-Home button enables

**CLI sites (2):**

- `autoboat_cli.py:241` — `needs_confirm` check includes `IDLE`
  alongside WAITING_CONFIRM / INIT / None / UNKNOWN
- `autoboat_cli.py:528` — `self.config_status.get('state', 'IDLE')`
  fallback

**Semantic interpretation:** `waypoint_planner.py` state transitions
emit 8 real states — `INIT`, `WAITING_CONFIRM`, `READY`, `DRIVING`,
`PAUSED`, `JOYSTICK`, `EMERGENCY_STOP`, `FINISHED`. Never emits
`IDLE`. The dashboard and CLI use `IDLE` as a "no data yet" client-
side sentinel before the first `/planning/mission_status` lands. This
is distinct from `INIT` ("planner is up but mission not yet
configured"). Coherent as-is.

**Decision options** (none required):

1. Keep as-is (current approach). Cost: reader must know IDLE is
   dashboard-side only.
2. Rename all 18 sites → `INIT`. Cost: coordinated cross-file edit,
   no behaviour gain, still need a pre-data sentinel concept.
3. Introduce `UNKNOWN` as the pre-data sentinel (semantically
   cleanest — the CLI's fallback list already treats `UNKNOWN`
   equivalently). Cost: same 18 edits + threading `UNKNOWN` display
   label.

Option 1 remains the morning recommendation. Nothing to change.

### Phase 5 prep residuals — concrete status

**A. `remap.launch.yaml` as a runnable file.**

- Paper design exists in
  `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md`
  Part 2 (~100 lines: skeleton, neutral namespace, 4-phase rollout,
  rollback path, 3 QoS risks).
- Actual runnable file does NOT exist. `launch/` contains only
  `autoboat.launch.yaml`.
- 6 files reference `remap.launch` by name — all are design /
  roadmap docs (Roadmap, Board, 3 diary entries, scope plan itself).
  Zero implementations.
- **To land:** create `launch/remap.launch.yaml` from the scope
  plan's skeleton — 6 `topic_tools/relay` nodes + 1 conditional
  bridge stub. Verify `ros-jazzy-topic-tools` is installed. Dry-run
  with `use_real_hardware:=false` should produce identical behaviour
  to the current launcher. Estimated 1 focused session (~1 h).
- **Blocked on:** nothing. Bridge-node layer depends on supervisor
  CCU confirmation, but Layer A relays do not.

**B. Perception-rate profiling.**

- Board.md Prep Tasks table line 165: `Profile /perception/obstacle
  _info Hz in VRX; document baseline` — still `⬜`.
- **To land:** full launch → Buoy Field preset → `ros2 topic hz
  /perception/obstacle_info` for 2 min under mission load → record
  mean / std / dropouts → write baseline row into Board.md for
  future Pi-5 comparison.
- Estimated 30 min on Linux.
- **Blocked on:** nothing.

### Broader code audit — prioritised findings

Two parallel read-only inspection passes covered: dead code, silent
error handling, stale legacy refs, TODO/FIXME markers, magic
numbers, fire-and-hope patterns, state-name consistency, orphan
params, Python↔YAML default drift, dashboard four-place sync,
docstring↔implementation drift, topic / message type consistency.

#### Critical (possible real bugs — verify before acting)

| # | File:line | Finding |
|:--|:----------|:--------|
| C1 | `plan/plan/lidar_perception.py:278` | Bare `except Exception: pass` in the target-subscriber callback; parse failures silently fall back to static ±45° sectors without log |
| C2 | `plan/plan/waypoint_planner.py:552` | Bare `except: pass` in obstacle callback; cluster-parse failures may feed stale data into A\* detour planning |
| C3 | `control/control/heading_controller.py:753-791` | Critical-obstacle reverse sequence — `reverse_start_time` can be `None` from another reset path; `elapsed > reverse_timeout` comparison may misfire |
| C4 | `one_click_launch_all/health_check_autoboat.sh` vs docs | One inspection pass counted ~34 emission sites in the script; docs + Board claim 49. Likely the difference is loop-expansion (`check_param` inside a loop emits N runtime checks from 1 static site), but a sanity count is warranted |

#### Important (tech debt, not unsafe)

| # | File:line | Finding |
|:--|:----------|:--------|
| I1 | `plan/plan/autoboat_cli.py:153` | `# TODO(tier2-option-a)` for start/resume/go_home — still topic-based; could migrate to `std_srvs/Trigger` like stop/generate did 20/04 |
| I2 | `control/control/heading_controller.py:45-50` | `MAX_THRUST=2000`, `SAFE_THRUST=800`, `TURN_POWER_LIMIT=1600`, `REVERSE_BURST_THRUST=-1200`, `ESCAPE_TURN_POWER=450` — module-level constants not exposed as ROS parameters; no runtime or dashboard tuning |
| I3 | `plan/plan/lidar_perception.py:563` | `math.radians(15)` hardcoded for minimum gap width in VFH — candidate for a 5th `vfh_*` parameter |
| I4 | `plan/plan/lidar_perception.py:401, 406` | Boat-hull self-filter hardcoded to WAM-V (`abs(y) < 1.3` + `x ∈ (-4.5, 1.0)`) — would need adjustment for a different USV body |
| I5 | `control/control/heading_controller.py:876-888` | Angle-dependent speed-reduction thresholds (45°, 20°) hardcoded — no angle-axis mirror of the existing `approach_slow_distance` |
| I6 | All 3 node module-level docstrings | Missing newer pub/sub lines. `lidar_perception.py` missing `/planning/set_config` sub + `/control/heading_error` sub + `/perception/param_ranges` pub; `heading_controller.py` missing `/planning/mission_status` sub + `/control/heading_error` pub; `waypoint_planner.py` state-machine docstring omits PAUSED / JOYSTICK / EMERGENCY_STOP |
| I7 | `plan/plan/waypoint_planner.py:245, 899` | `self.detour_start_time` cleared only in `advance_to_next_waypoint`; paths that skip that method may leave `None` and silently break the detour-timeout check around line 899 |

#### Cosmetic (low priority)

| # | File:line | Finding |
|:--|:----------|:--------|
| K1 | `waypoint_planner.py:1079, 1133, 1177` | Local `import time` inside three methods — inconsistent with the module-level import at line 32; Python caches so no perf impact, pure style drift |
| K2 | `waypoint_planner.py:804` | `hasattr(self, 'obstacle_clusters')` guard where the attribute is always initialised in `__init__` line 224 — defensive dead branch |
| K3 | `lidar_perception.py:100-102` | Some `vfh_*` params read via `get_parameter()` at every tick rather than cached to `self.<attr>` at init — micro-overhead at 10 Hz |
| K4 | `heading_controller.py:857` | `/control/heading_error` published at 20 Hz unconditionally, even when `use_vfh_bias: false` and perception not subscribing — a few bytes per tick, harmless |

#### False alarms (flagged but verified correct)

| # | Where | Why correct |
|:--|:------|:-----------|
| F1 | `waypoint_planner.py` cooldown uses `time.time()` | Cooldown timer, not a fire-and-hope. Backward-jumping system clock is not a realistic concern in this deployment |
| F2 | `heading_controller.py` Kalman update gate (`commanded_thrust < 50.0`) | Sound design — documented in 20/04 diary; prevents drift estimator absorbing commanded motion |
| F3 | Dashboard `IDLE` label | Intentional "no data yet" sentinel — see inventory above |
| F4 | Python ↔ YAML default drift | Cross-audit pass found zero drift across all 3 nodes; the 19/04 sync work has held |
| F5 | Dashboard four-place sync | Verified params all sync across YAML / HTML / JS / Python; the 17/04 `avoid_diff_gain` regression does not recur |
| F6 | Topic message-type consistency | Publishers and subscribers agree on types across `/perception/*`, `/planning/*`, `/control/*` |

**Totals:** 4 Critical (pending spot-read verification), 7 Important,
4 Cosmetic, 6 False alarms. 21 items surfaced, filtered down from
~40 raw findings across the two inspection passes.

#### C1-C4 spot-read verdict (21/04 late evening revision)

Completed a Read-only spot-check of the four Critical items. Results
supersede the "pending spot-read verification" qualifier on the totals
line above.

| # | Original concern | Verdict | Detail |
|:--|:-----------------|:--------|:-------|
| **C1** | `lidar_perception.py:278` target-subscriber bare except | **Real bug (mild)** | Lines 267-279: `try/except Exception: pass` around `json.loads` + field access. Silent fallback — `self.target_angle` and `self.front_half_width` keep their previous values, no logger call. Fix is the `_log_bad_json` helper pattern the CLI JSON callbacks got 21/04. |
| **C2** | `waypoint_planner.py:552` obstacle-subscriber bare except | **Real bug (medium)** | Lines 537-553: same pattern as C1 but more consequential — `self.obstacle_clusters` is consumed by A*detour planning. On parse failure, A* operates on stale cluster data. Same `_log_bad_json` fix applies. |
| **C3** | `heading_controller.py:753-797` reverse state machine | **Real bug (medium)** | Line 782 sets `force_turn_after_reverse = True` when reverse-timeout or reverse-distance is hit (intent: latch into "turn instead of reverse again" for the next tick). But the fall-through block at lines 793-797 unconditionally resets the flag to `False` in the same tick. Net effect: the latch never persists across control ticks. On the next tick with `is_critical == True`, the flow re-enters the reverse branch, re-initialises `reverse_start_time`, and starts another reverse cycle. Not an infinite loop (each reverse cycle does move the boat ~0.8 m further from the obstacle, eventually clearing `is_critical`), but the boat performs ~2 reverse cycles (~8 s total) where 1 reverse + turn-to-avoid was intended. Fix: move the `force_turn_after_reverse = False` reset out of the unconditional fall-through; reset it only when exiting `is_critical` (the `else` branch at line 798-801 already does this correctly). |
| **C4** | Health check `49` vs one pass's "~34 emission sites" | **False alarm / verified correct** | Manually enumerated runtime emissions under the "full launch, active mission" assumption: 5 main-node passes + 1 `health_check_service` + 2 optional nodes (when both running) + 5 always topics + 5 mission topics + 1 orphan check + 6 `check_publisher` calls + 8+8+4 `check_param` calls + 4 connectivity = **49 exactly**. Matches what the README, USER_MANUAL, and Board all claim. The "~34" count was static call sites (loops counted as 1 instead of N), not a runtime-emission count; no error in the script or docs. No fix needed. |

**Updated category totals** (rebalancing after spot-read):

| Category | Before | After |
|:---------|:------:|:-----:|
| Critical — real bug confirmed | 4 pending | **3** (C1, C2, C3) |
| Important | 7 | 7 (unchanged) |
| Cosmetic | 4 | 4 (unchanged) |
| False alarms verified | 6 | **7** (C4 moved here) |
| **Grand total** | **21** | **21** (unchanged) |

**Implication for 22/04 Block 2:** C1, C2, C3 are real and cluster into
two fix patterns:

1. **`_log_bad_json` helper** for C1 + C2 — the same treatment the CLI's
   three JSON callbacks got on 21/04. Add a module-level helper to each
   of the two perception/planner files (or a shared one), replace the
   `except Exception: pass` bodies with a throttled warn log, keep the
   fall-back-to-previous-value behaviour.
2. **`force_turn_after_reverse` latch fix** for C3 — single-file edit in
   `heading_controller.py`. Remove or gate the unconditional reset at
   line 796 so the flag persists until `is_critical == False` resets it
   via the `else` branch.

All three fixes fit in one Python-edit commit cycle with `py_compile`

- `colcon build --packages-select plan control` as the verification
loop. Estimated 45-60 min on Linux.

## Guide for 22/04/2026

Priority-ordered triage derived from the supplementary audit above.
High-yield / low-risk first; blocked-on-external items last.

1. **Spot-read C1 / C2 / C3 / C4** (~30 min, either machine, Read-
   only). Decide whether each is a real bug before committing to a
   fix cycle.
   - `lidar_perception.py:278` — is the bare-except truly silent, or
     does the fall-back log somewhere?
   - `waypoint_planner.py:552` — same question.
   - `heading_controller.py:753-791` — read the reverse state
     machine as a connected block; check all `reverse_start_time`
     reset points.
   - `health_check_autoboat.sh` — count actual `pass`/`fail`/`warn`
     emission sites to resolve the 49 vs ~34 discrepancy.

2. **Phase 5 residuals land today** (~1.5 h total on Linux):
   - Create `launch/remap.launch.yaml` from the scope plan's Part 2
     skeleton. Commit as `feat:` with a `use_real_hardware:=false`
     smoke-test showing identical mission behaviour.
   - `ros2 topic hz /perception/obstacle_info` 2-minute sample under
     Buoy Field preset. Record baseline in Board.md Prep Tasks row
     165 (flip `⬜` → `✅` with the measured value).

3. **I6 docstring refresh** (~15 min, either machine, pure markdown-
   in-Python). Update the three module-level docstrings to list all
   current pub/sub + the full state machine. Zero behaviour change.
   One `docs:` commit.

4. **If C1 / C2 / C3 confirmed real** — apply the same pattern the
   CLI got on 21/04: replace bare-except with a
   `_log_bad_json(topic, exc)` helper that throttle-logs visibly. A
   single fix-and-commit cycle closes all three. Linux-only (Python
   edits).

5. **C4 resolution:**
   - If 49 is wrong, fix the number in README + USER_MANUAL + Board
     - dashboard README + wiki Glossary in one `docs:` commit.
   - If 49 is correct but emission-site count is ~34, add a short
     comment near the health-check summary block explaining the
     loop-expansion so future readers don't re-open this question.

6. **Deferred / blocked:**
   - IDLE alignment — no behavioural benefit; bundle only if doing a
     broader dashboard-JS cleanup pass for another reason.
   - I1, I2, I3, I4, I5, I7, K1-K4 — backlog; land opportunistically
     when touching the same file for another purpose.
   - Phase A mock water quality sensor — still blocked on supervisor
     parameter-set confirmation (pH / turbidity / DO / temperature /
     conductivity — which subset?).
   - Phase 5 bridge node beyond the pass-through stub — still
     blocked on supervisor CCU architecture (separate low-level
     controller or direct Pi GPIO?).
   - Pier / bank stuck behaviour from 20/04 pressure test — open
     navigation issue; can be tackled in parallel but not scoped
     here.

**Machine assignments:**

| Item | Machine | Why |
|:-----|:--------|:----|
| 1. C1-C4 spot-read | Either | Pure Read / Grep |
| 2. Phase 5 residuals | Linux | Needs full VRX launch |
| 3. I6 docstrings | Either | Pure markdown |
| 4. Bare-except fixes | Linux | Python edits (launch tests after) |
| 5. C4 docs fix | Either | Pure markdown |
