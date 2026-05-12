# 2026-05-13 — Wednesday: deeper doc sweep + audit-real-test escalation

## Context

Day after Tue 12/05 — yesterday's stack on `main` ended with:

- `77462f7` `docs(diary): wrap 12/05 Pi 5 DDS and doc sweep` — Tue Block F
  wrap landing Board.md L171 + L182 fixes, Board.md Tue 12/05 Timeline row,
  `Last Updated` 11/05 → 12/05, `Document Version` 9.10 → 9.11, Roadmap §3
  GDAL update + new DDS row, Roadmap §9 two 12/05 entries (DDS verification
  + GDAL PE-DLL diagnosis), Common_Issues MP-Linux Residual item 1 rewrite,
  E.6 stamp bumps (`wiki/Home.md`, `wiki/README_WIKI.md`,
  `working_diary/README.md`), and the filled Block A-F outcomes in the
  12/05 diary itself.
- `d3449bd` `docs(roadmap): soften propeller thrust-line wording` —
  follow-up wording polish on the §8.8 entry that landed earlier in the day.
- `ee35633` `docs(roadmap): §8.8 track propeller placement sim-vs-real gap`
  — new VRX-fork candidate-modifications tracker (§8.8 of Roadmap), first
  entry covering the submerged-thruster WAM-V vs above-water hovercraft /
  airboat-style propulsion gap.

Repo synced. Working tree clean as of Tue close.

**Pi 5 baseline unchanged** (`imtaqua-pi-01`, Ubuntu 24.04.4 LTS aarch64,
ROS 2 Jazzy at `/opt/ros/jazzy/`, bare daemon under both `ROS_DOMAIN_ID=0`
and `=56`, SSH key auth `aqpi-01@10.120.2.50` durable). DDS cross-machine
discovery + transport **verified WORKS** on `IoT IMT Nord Europe` per Tue
Block B.1 — standard ROS 2 graph discovery sufficient for Phase 5 driver
bring-up, Fast-DDS Discovery Server unicast NOT required.

**Lead item today:** continuation of Tue Block E's doc-sweep spirit, broader
and deeper. Tue's E pass covered 10 target files with a risky-term grep
plus targeted reads; today expands coverage to the 12 wiki files Tue didn't
visit, the launch / xacro / SDF / shell scripts under `launch/` and
`one_click_launch_all/` and `test_environment/`, the 7 ROS 2 node Python
docstrings, and any docs that might be stale post Tue's DDS-WORKS verdict
or Block C's GDAL PE-DLL reclassification.

**Escalation policy.** For any claim that cannot be settled by audit alone
(grep / read / cross-ref), plan a focused real test:

- **Workstation-side** (preferred default; no offline-window cost): launch
  the autoboat stack via `bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia`,
  observe `ros2 node list` / `topic list` / dashboard panels; run the
  health-check script; diff actual runtime graph against doc claims.
- **Pi 5 / boat control box** (only if claim is Pi-specific): single short
  offline-window cycle on `IoT IMT Nord Europe`, scoped to the specific
  question (e.g., whether a particular apt package is installed, whether
  a configuration file reads as documented). Don't open the offline window
  unless ≥ 1 Pi-specific question has accumulated.

**Week shape recap:**

- **Mon 11/05** — Herelink video A/B campus close + MP-Linux SkiaSharp/libdl
  fix + Pi 5 SSH/ROS 2 install verified + audit cleanup. 6 commits.
- **Tue 12/05** — Pi 5 deep check (DDS WORKS, B.2 bare/headless), MP-Linux
  GDAL re-diagnosis (PE-DLL bundle, not musl), QGC stable check (skip,
  v5.0.8 current), Block E doc sweep across 10 files, Block F wrap.
  3 commits (`ee35633`, `d3449bd`, `77462f7`).
- **Wed 13/05 (today)** — deeper doc sweep with audit-real-test escalation.
  Continuation of Tue Block E, expanded scope.
- **Pending all week** — formal joint supervisor presentation reschedule;
  three Asks to teammate maintainer (Phase A parameter subset, CA
  placement, validation methodology); second-site (lake) Herelink video
  A/B retest; Phase 5 driver bring-up planning (newly unblocked post Tue
  B.1 WORKS).

**Why this matters.** Doc accuracy is the cheapest lever against future
debugging cost. Tue's E pass surfaced 2 real stale claims in `Board.md`
(L171, L182) and 1 in `wiki/Common_Issues.md` (the GDAL musl/glibc
misframing) — all inherited from speculative diagnoses that got disproven
by Mon/Tue's actual investigations. Wed's broader sweep is the natural
next pass to surface similar drift across the parts of the repo Tue's
narrower scope didn't visit.

The audit-real-test escalation captures Tue Block C's lesson: the
musl-libc speculation survived from 24/04 → 11/05 because nobody opened
the bundle to see what was actually there. When audit hits an "X probably
means Y" claim that can be settled by running a command, run the command.

Active blocks:

1. **Block A — Morning re-orientation** (~10 min, opening): catch up;
   verify Tue's commits on disk + push state; overnight inputs; Pi 5
   reachability check only if a Pi-side test seems likely.
2. **Block B — Broader doc sweep** (~60-90 min, AM): five sub-blocks
   (B.1 wiki files Tue didn't visit, B.2 shell + SDF + xacro comments,
   B.3 ROS 2 node Python docstrings + launch YAML + package.xml,
   B.4 Tue-outcome forward-update scan, B.5 legacy/ boundary check).
   Inspect-only by default — classify each finding stale / accurate /
   borderline / needs-real-test.
3. **Block C — Audit-real-test escalations** (~30-90 min, mid-PM,
   list-driven, conditional on Block B's findings): for each
   needs-real-test item, run the smallest test that resolves it.
   Workstation-side preferred; Pi-side only when the question is
   Pi-specific.
4. **Block D — Day wrap** (~30 min, evening): commit + push.

**Hard boundary.** Stay within docs + audit + real-test pass. No new
features, no refactors, no Phase 5 driver bring-up code work today —
those are separate scoped sessions. **No Python / YAML edits today
without explicit user permission**, even if Block B.3 surfaces docstring
drift; flag and defer.

**Fallback if Pi-side test becomes needed but Pi unreachable**: skip
Pi-specific real tests; document as "audit-only verdict, Pi-side real
test deferred to next Pi-reachable session". All workstation-side and
audit-only work proceeds independently.

---

## Block A — Morning re-orientation (~10 min, opening)

After Tue's 3-commit close, catch up before starting today's blocks:

- `git log --oneline -10` + `git status` — verify Tue's `77462f7` /
  `d3449bd` / `ee35633` on disk + branch synced with `origin/main`.
- Re-read Tue 12/05 diary Block B (DDS WORKS findings) + Block C (GDAL
  PE-DLL diagnosis) + Block E (doc sweep findings list + carry-forward
  notes) — these are the contextual anchors today's broader sweep builds
  on.
- Check overnight inputs (supervisor / teammate replies, weather,
  presentation reschedule). If email / Slack aren't reachable from this
  Agent context, ask the user.
- **VRX §8.2 weekly cadence** — next scheduled check is Mon 18/05 per the
  Mon 11/05 schedule, so NOT due today (5 days early). No state-check
  needed.
- Confirm Pi 5 reachability **only if** a Pi-side real test is likely in
  today's plan. Default: Block B is fully workstation-side; defer the
  reachability question until Block B's findings list surfaces a
  Pi-specific item.

**Outcome.** [To fill — git state, overnight inputs, decision on whether
Pi-side tests are likely today.]

---

## Block B — Broader doc sweep (~60-90 min, AM)

Five sub-blocks. **Inspect-only by default** — classify each finding as
one of:

- **stale** (clear correction needed; fix at Block D if low-risk, else
  queue for follow-up)
- **accurate** (claim verifies cleanly; no change)
- **borderline** (wording soft / ambiguous but not strictly wrong)
- **needs-real-test** (cannot be resolved by audit alone — escalates to
  Block C)

### B.1 — Wiki files not covered in Tue E (~25 min)

12 wiki files Tue didn't visit:

```text
wiki/3D_LIDAR_Processing.md
wiki/Dashboard_Security.md
wiki/Design_Rationale.md
wiki/Glossary.md
wiki/Installation_Guide.md
wiki/Node_Naming_Refactor_Plan.md
wiki/Pi5_Bringup_Smoke_Test.md
wiki/Quick_Start.md
wiki/SASS.md
wiki/System_Overview.md
wiki/UPLOAD_INSTRUCTIONS.md
wiki/VRX_Fork_Migration.md
```

**Known forward-update opportunity** flagged from Tue: `wiki/Pi5_Bringup_Smoke_Test.md`
L139 + L300 reference "verify multicast on the IoT WiFi" via talker /
listener round-trip — that verification is now complete (Tue B.1 WORKS).
Either add a "(verified 12/05/2026 — see `working_diary/2026-05-12` Block
B.1)" parenthetical, or leave as forward-looking guidance for future
networks; surface decision at Block D.

Risky-term grep + targeted reads as the standard pattern. Cross-check each
hit against Tue's known-good state (DDS WORKS, Pi bare/headless,
MP-Linux GDAL is PE-DLL not musl, 06/05 VRX fork in place,
05/05 dashboard vendoring in place, 16/04 node-name refactor stable).

```bash
for f in wiki/3D_LIDAR_Processing.md wiki/Dashboard_Security.md \
         wiki/Design_Rationale.md wiki/Glossary.md \
         wiki/Installation_Guide.md wiki/Node_Naming_Refactor_Plan.md \
         wiki/Pi5_Bringup_Smoke_Test.md wiki/Quick_Start.md wiki/SASS.md \
         wiki/System_Overview.md wiki/UPLOAD_INSTRUCTIONS.md \
         wiki/VRX_Fork_Migration.md; do
  echo "=== $f ==="
  grep -nIE 'fail|degrad|unresolved|open|TBD|deferred|pending|broken|missing|todo|multicast|musl|gdal_wrap\.so|inconclusive' "$f" | head -15
done
```

Stamp + version trailer also worth a glance per file (the same pattern Tue
E.6 used) — `grep -niE 'last[ _-]updated|document version'`.

### B.2 — Shell + SDF + xacro comment sweep (~10 min)

Targets (small, focused):

- `one_click_launch_all/launch_autoboat_complete.sh`
- `one_click_launch_all/health_check_autoboat.sh`
- `one_click_launch_all/patch_vrx.sh` (kept as idempotent no-op safety net
  per Roadmap §8.6 — should still describe itself accurately)
- `test_environment/sydney_regatta_DEFAULT.sdf`
- `test_environment/wamv_3d_lidar.xacro`

Look for stale TODO / FIXME / outdated comments / references to renamed
nodes (post 16/04 refactor) / references to pre-fork VRX (`osrf/vrx`
where it should now point to `Ghostzero00018/vrx`).

```bash
grep -nIE 'TODO|FIXME|XXX|DEPRECATED|stale|outdated|osrf/vrx|OKO|SPUTNIK|BURAN' \
  one_click_launch_all/*.sh test_environment/*.sdf test_environment/*.xacro 2>/dev/null
```

**Note:** `osrf/vrx` references in xacro/SDF as attribution / canonical-project
links are intentional per Roadmap §8.6 ("9 attribution / canonical-project
links to `osrf/vrx` preserved"). Don't flag those.

### B.3 — ROS 2 node Python docstrings + launch YAML + package.xml (~25 min)

7 ROS 2 node Python files:

```text
control/control/heading_controller.py
control/control/keyboard_teleop.py
plan/plan/autoboat_cli.py
plan/plan/health_check_service.py
plan/plan/lidar_perception.py
plan/plan/waypoint_planner.py
plan/plan/waypoint_visualizer.py
```

Each node's module-level + class-level docstrings typically claim a
`Subscribes / Publishes / Parameters / Services` list. The 30/04 Block D
cleanup landed a fix for this same class of drift in `waypoint_planner.py`
(+2 subs in docstring) and `heading_controller.py` (+1 sub / +2 pubs);
About two weeks later, another pass is useful. **Inspect-only — no Python
edits today without explicit user permission.** Flag drift; surface at
Block D.

```bash
for f in control/control/heading_controller.py control/control/keyboard_teleop.py \
         plan/plan/autoboat_cli.py plan/plan/health_check_service.py \
         plan/plan/lidar_perception.py plan/plan/waypoint_planner.py \
         plan/plan/waypoint_visualizer.py; do
  echo "=== $f — docstring excerpt ==="
  awk '/^"""/{c++; if (c==1) p=1; else if (c==2) {print; exit}} p' "$f" | head -60
  echo "--- actual create_*/declare calls ---"
  grep -nE 'create_(subscription|publisher|service|client|timer)|declare_parameter' "$f"
done
```

Diff each pair. Flag drift class:
- Docstring claims a sub/pub/param that the code no longer has → stale.
- Code has a sub/pub/param that the docstring doesn't list → undocumented.
- Names match → accurate.

Also sweep launch YAML + package.xml:

```bash
echo "== launch YAMLs ==" && \
  grep -nIE 'TODO|FIXME|XXX|deprecated|stale|outdated' launch/*.yaml 2>/dev/null
echo "== package.xml descriptions ==" && \
  git ls-files '*package.xml' | grep -v '^legacy/' | xargs -r grep -nE '<description>'
```

Cross-check launch YAML node-name keys: Python node `name:` must match
launch YAML `name:`, otherwise the node appears under one name via
`ros2 run` but a different name via launch (breaks downstream lookups
including the health-check script).

### B.4 — Tue-outcome forward-update scan (~10 min)

Tue's three big verdicts (DDS WORKS / Pi bare-headless / GDAL PE-DLL)
potentially affect any earlier doc that hedges on these points. Grep for
hedging phrasings:

```bash
# Tue-outcome propagation targets — search tracked files only, exclude frozen working_diary/
git grep -nIE 'DDS.*inconclusive|multicast.*unknown|Pi 5.*TBD|MP.*musl.*GDAL|gdal_wrap\.so|musl.*libc.*gdal' \
  -- '*.md' '*.py' '*.yaml' '*.yml' \
  ':(exclude)working_diary/*' ':(exclude)legacy/*'
```

The `working_diary/2026-05-12_*.md` and earlier diary entries are
**append-only records** and stay as-is (per `working_diary/README.md`
Editing convention rules — past entries frozen). Hits in `Roadmap.md`,
`README.md`, `USER_MANUAL.md`, `Board.md`, `Common_Issues.md`, `wiki/*.md`
(not the diary), etc. are candidates for forward-update.

**Judgment caveat**: dated Timeline rows in `Board.md` (e.g., the 11/05
row's `DDS … inconclusive` phrasing) are themselves append-only history
within the timeline table — forward-updates land via NEW dated rows (Tue's
12/05 row did this), not by editing the older row's text. Flag a `Board.md`
grep hit as **stale** only if it sits in a status-bearing area (header
summary, a Phase 5 prep row that's status-bearing rather than historical),
not a dated history row. Same logic for dated entries in `wiki/Roadmap.md`
§9 revision log or `wiki/Common_Issues.md` dated paragraphs — historical
text superseded by a newer dated row stays as-is.

### B.5 — `legacy/` boundary check (~5 min)

Confirm no Wed work has accidentally referenced anything inside `legacy/`,
and confirm `legacy/`-internal docs haven't been edited recently:

```bash
git log --since='2026-05-01' --oneline -- legacy/ 2>/dev/null
echo "(empty = clean — legacy/ is frozen as expected)"
git grep -nIE 'legacy/' -- '*.md' '*.py' '*.yaml' \
  ':(exclude)legacy/*' ':(exclude)working_diary/*' | head -10
```

Inadvertent references should be rare; the legacy boundary has been stable
since the original cleanup.

**Outcome.** [To fill — findings list per sub-block (B.1 / B.2 / B.3 /
B.4 / B.5), classified stale / accurate / borderline / needs-real-test;
fix-now vs queue-for-later decisions surfaced.]

---

## Block C — Audit-real-test escalations (~30-90 min, mid-PM, list-driven)

For each "needs-real-test" item from Block B, run the smallest test that
resolves it. Order by cost: workstation-side first (no offline-window),
Pi-side only when the question is Pi-specific.

If Block B's needs-real-test list is empty, Block C is a no-op — skip
straight to Block D.

**Pre-staged recipes for common need-real-test classes:**

### C.1 — Workstation autoboat-stack launch + node/topic diff

When: a doc claims a node name, topic name, service name, or
publish-rate that can be settled by checking the actual runtime graph.

```bash
# Workstation, fresh shell
source ~/seal_ws/install/setup.bash
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia &
LAUNCH_PID=$!
sleep 40   # Gazebo + nodes + dashboard need time to come up

# Capture actual runtime graph
ros2 node list > /tmp/wed_node_list.txt
ros2 topic list > /tmp/wed_topic_list.txt
ros2 service list > /tmp/wed_service_list.txt
echo "=== nodes ==="; cat /tmp/wed_node_list.txt
echo "=== topics ==="; cat /tmp/wed_topic_list.txt

# Diff against doc claim (replace <file> + <claim-pattern>)
diff <(sort /tmp/wed_node_list.txt) <(grep -oE '/[a-z][a-z_]*' <file> | sort -u)

# Shutdown cleanly — Mon Block G pitfall: pkill -f mismatches multi-arg
# python/Gazebo procs AND can self-kill when the calling shell's own argv
# contains the pattern. Use ps + awk + xargs kill with a single
# self-excluding alternation for all targets.
kill "$LAUNCH_PID" 2>/dev/null
sleep 5
ps -eo pid,cmd | awk '/(launch_autoboat_complete|gz sim|rosbridge)/ && !/awk/' | awk '{print $1}' | xargs -r kill 2>/dev/null
```

### C.2 — Health check script real run

When: any doc claim about `one_click_launch_all/health_check_autoboat.sh`
needs verification against actual output.

```bash
# Run against an already-launched stack (assumes C.1 stack is up, or user
# has the stack up in another terminal)
bash one_click_launch_all/health_check_autoboat.sh | tee /tmp/wed_health_check.log
```

Compare output structure / claimed checks against any doc references to
the script.

### C.3 — Dashboard param-flow real test

When: a doc claim about dashboard ↔ ROS param sync needs verification.
The sync invariant: a PARAM_RANGES key in `app.js` must be mirrored by
the corresponding `launch/autoboat.launch.yaml` declaration and the
`index.html` control element; all three must agree.

```bash
# Stack up (C.1), dashboard browser tab open at http://localhost:8002
# In dashboard: change a PARAM_RANGES-listed param value (e.g., planning
# spacing or perception thresholds).
# Verify ROS-side:
ros2 param get /<node-name> <param-name>

# Also confirm launch YAML lock:
grep -nE '<param-name>' launch/autoboat.launch.yaml
```

### C.4 — Python node `ros2 node info` vs docstring (Block B.3 follow-up)

When: a docstring claim about Subscribes/Publishes/Params/Services can
be verified by listing the node's actual endpoints at runtime.

```bash
# After C.1 launch:
ros2 node info /<node-name>
```

Diff the listed endpoints against the docstring's claims. **Read-only
inspection — no Python edits without explicit user permission.** Surface
drift at Block D's findings list, not as an inline fix.

### C.5 — Pi-side real test (only if escalation needs it)

When: a doc claim is Pi-specific (e.g., "Pi has package X installed",
"file at path Y exists on Pi", "service Z is enabled on Pi").

**Pre-staged Pi-side checks** (likely candidates given Tue's findings):

```bash
# Switch to IoT WiFi
nmcli connection up "IoT IMT Nord Europe"

# Common Pi-side audit queries — pick the ones that match Block B's needs-real-test items
ssh aqpi-01@10.120.2.50 '
  echo "== apt list installed (filtered) =="
  apt list --installed 2>/dev/null | grep -E "ros-jazzy-|tigervnc|xrdp|foxglove-bridge|mavros|mavlink|tmux"
  echo "== ros2 jazzy packages available =="
  apt-cache search ros-jazzy- 2>/dev/null | grep -E "mavros|mavlink|foxglove|rviz" | head -20
  echo "== ros2 daemon state =="
  source /opt/ros/jazzy/setup.bash
  ros2 daemon status 2>/dev/null
  echo "== free / df / uptime =="
  uptime; free -h; df -h /
'

# Switch back to 5G
nmcli connection up "IMT Nord Europe 5G"
```

**Decision rule for opening the offline window:** only if ≥ 1
Pi-specific question accumulated in Block B's needs-real-test list.
Don't open the window for a question that could be answered by user
recollection or by deferring.

**Outcome.** [To fill — list of escalations attempted, results, any
verdicts flipped from "needs-real-test" to "stale" / "accurate" /
"borderline", any escalations explicitly deferred.]

---

## Block D — Day wrap (~30 min, evening)

Same shape as Tue Block F:

1. `git log --oneline -10` — sanity check today's commits.
2. `git diff --check` — whitespace / conflict-marker sweep.
3. Pre-commit invisibility sweep — expect 0 matches.
4. Add 13/05/2026 `Board.md` Timeline row **if substantive findings landed**;
   bump header `Last Updated` + footer `Document Version` (9.11 → 9.12) if
   any tracked content updated. **Use search rather than line numbers**
   (both rows drift as Board.md grows).
5. Fill all `[To fill]` placeholders in this file.
6. Working diary commit; subject template depends on dominant outcome:
   - Clean sweep, no stale claims: `docs(diary): wrap 13/05 broader doc sweep — no stale claims`
   - Stale claims found + fixed inline: `docs(diary): wrap 13/05 doc sweep + N inline fixes`
   - Stale claims found + queued for follow-up: `docs(diary): wrap 13/05 doc sweep + N findings`
   - Real-test escalation landed: `docs(diary): wrap 13/05 doc sweep + audit-real-test pass`
   - Mixed: `docs(diary): wrap 13/05 deeper doc sweep`
7. Push.
8. **Update Week 10 external diary Wed Outcome bullet** — Windows-side
   weekly diary; deferred to next Windows-side session if Linux-only today.

**Outcome.** [To fill at end of day.]

---

## Verification summary — 13/05 (check at end of day)

- [ ] Block A: morning re-orientation done; Tue's `77462f7` / `d3449bd` / `ee35633` confirmed at / under HEAD; overnight inputs noted; Pi-side test decision recorded
- [ ] Block B.1: 12 wiki files swept; findings classified (stale / accurate / borderline / needs-real-test); `wiki/Pi5_Bringup_Smoke_Test.md` L139 + L300 forward-update decision surfaced
- [ ] Block B.2: shell + SDF + xacro comments swept; findings classified
- [ ] Block B.3: 7 ROS 2 node docstrings + launch YAMLs + package.xml swept (inspect-only — no Python / YAML edits today without explicit permission); findings classified
- [ ] Block B.4: Tue-outcome forward-update scan done (DDS WORKS / Pi bare-headless / GDAL PE-DLL propagation across non-diary docs)
- [ ] Block B.5: `legacy/` boundary check clean (no inadvertent references; no recent edits inside `legacy/`)
- [ ] Block C: audit-real-test escalations completed (or explicitly recorded "none needed" if Block B's needs-real-test list was empty)
- [ ] Block D: diary filled; pre-commit sweep clean; `Board.md` updated if substantive; commit + push handled

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation done | None |
| Block B | Findings list collected and classified | **Medium** — drives Block C scope; could rollover to Thu if list is large |
| Block C | Escalations run; verdicts finalised | Low — each escalation independent |
| Block D | Day closed | Standard |

---

## Known unknowns to record during the day

- Whether the 12 wiki files have any drift not already caught (Block B.1).
- Whether `wiki/Pi5_Bringup_Smoke_Test.md`'s talker/listener-verification
  references should be forward-updated with Tue's 12/05 verification
  outcome (Block B.1 decision point).
- Whether shell / SDF / xacro comments mention pre-fork `osrf/vrx` or
  pre-refactor node names (Block B.2).
- Whether the 7 ROS 2 node docstrings still match actual
  `create_subscription` / `create_publisher` / `declare_parameter` calls
  (Block B.3).
- Whether any pre-Tue hedging on DDS / Pi-state / GDAL diagnosis survived
  Tue's outcome propagation across the rest of the doc surface (Block B.4).
- Overnight inputs (supervisor / teammate replies / external events).
- Whether any Pi-specific real test is needed (only known if Block B
  finds a Pi-specific needs-real-test item).

---

## Next steps — Wed 13/05 → end of week

### Active branch: today's broader doc sweep + audit-real-test escalation

Today's outcomes drive Thu / Fri:

- **If Wed sweep is clean** (no stale claims, no escalations needed):
  Thursday can pivot to active work — Phase 5 driver bring-up planning,
  or one of the deferred items below.
- **If Wed finds substantial stale claims**: Thursday becomes
  continuation / fix-application day, Friday left for active work.
- **If Wed escalations surface unexpected runtime issues** (e.g., a
  docstring claim disproved by `ros2 node info`, a stale param-sync
  invariant broken): each becomes a scoped follow-up session, not folded
  into Wed's wrap.

### Pending all week (carried from Mon 11/05 + Tue 12/05)

- Formal joint supervisor presentation reschedule — still pending IMT
  Mines Alès availability + power restoration.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology).
- Second-site (lake) Herelink video A/B retest — deferred from Mon 11/05
  Block D; rolls into next field session under the known-good QGC
  `Source = Herelink Hotspot` preset.
- **Phase 5 driver bring-up planning** — newly unblocked post Tue B.1
  WORKS. First focused session can plan: LiDAR / GPS / IMU driver
  candidates, `mavros2` install path, autostart strategy on Pi, topic-name
  scheme aligned with `launch/remap.launch.yaml`. Slot into Thu / Fri if
  Wed's sweep is clean.

### This week's possible time-permitting tasks (deferred-for-week per user direction; pick up only if any Wed / Thu / Fri block runs short)

- **P1 pier/bank stuck investigation** — diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A.
  Substantial sim work; naturally pauseable. Requires `--use-nvidia` to
  hold acceptable RTF (~0.32 → ~0.88).
- **Real no-regression test for `launch/remap.launch.yaml`** — prereqs:
  Pi-side driver bring-up landed so there are real-hardware topics to diff
  against sim. Not actionable until Phase 5 driver bring-up happens.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — unblocked once
  supervisor confirms parameter set).
- Roadmap §1.3 Path B (offline tile server with pre-generated MBTiles for
  the test-site area).
- Dashboard CSP Option B (reverse-proxy header injection) and Option C
  (Caddy / external static webserver).
- 24/04 housekeeping carry-overs (`mono-xsp4` port-8084 disable;
  `tools/qos_scan.py` single-pass QoS inventory).
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware double-reverse
  symptom.
- Sim-to-real comparison — N/A until a future field test records autonomy
  bag data.
- External Week 9 + Week 10 diary outcomes — bilingual EN + 中文,
  Windows-side; deferred to next Windows session.
