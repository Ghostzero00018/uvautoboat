# 2026-05-13 — Wednesday: deeper doc sweep + audit-real-test escalation

## Context

Day after Tue 12/05 — yesterday's stack on `main` ended with:

- `77462f7` `docs(diary): wrap 12/05 Pi 5 DDS and doc sweep` — Tue Block F
  wrap landing Board.md L171 + L182 fixes, Board.md Tue 12/05 Timeline row,
  `Last Updated` 11/05 → 12/05, `Document Version` 9.10 → 9.11, Roadmap §3
  GDAL update + new DDS row, Roadmap §9 two 12/05 entries (DDS verification
  - GDAL PE-DLL diagnosis), Common_Issues MP-Linux Residual item 1 rewrite,
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
- **Thu 14/05 + Fri 15/05** — Thu 14/05 is a public holiday in France
  (Ascension Day); Fri 15/05 is a site bridge day off ("pont"). **No
  on-site work either day.** Anything left unfinished after Wed rolls to
  Mon 18/05 or later.
- **Pending (carrying past Wed; rolls to Mon 18/05+ given Thu/Fri
  off-site)** — formal joint supervisor presentation reschedule; three
  Asks to teammate maintainer (Phase A parameter subset, CA placement,
  validation methodology); second-site (lake) Herelink video A/B retest;
  Phase 5 driver bring-up planning (newly unblocked post Tue B.1 WORKS).

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
   Pi-specific. **Two time-permitting Pi-side candidates added
   Tue-evening prep:** C.6 — Pi 5 internet pre-flight + HDMI/USB
   direct-attach (Branch A TTY-only if no internet; Branch B install
   minimal DE if internet route verifies, per user authorisation that
   explicitly overrides the bare-ROS-2 boundary below); C.7 — camera-ON
   ROS 2 graph experiment via QGC-triggers-camera on Herelink Hotspot,
   then Pi-local-console capture while QGC attached (leveraging C.6's
   HDMI/USB-keyboard attachment), then IoT/DDS cross-check after
   workstation network switch; feeds B.4 forward-update scan.
4. **Block D — Day wrap** (~30 min, evening): commit + push.

**Hard boundary.** Stay within docs + audit + real-test pass. No new
features, no refactors, no Phase 5 driver bring-up code work today —
those are separate scoped sessions. **No Python / YAML edits today
without explicit user permission**, even if Block B.3 surfaces docstring
drift; flag and defer. **Pi 5 stays bare ROS 2** for the autonomy /
driver stack — *explicit user-authorised exception*: C.6 Branch B
(minimal-DE install) is in scope today **if and only if** the C.6
pre-flight verifies Pi has internet access. DE install changes Pi from
bare/headless to graphical-login; no autonomy / driver / MAVLink-bridge
software is added in the same session even under Branch B.

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

**Outcome.** Both repos clean and synced at session start: main HEAD `3486461`,
Gist HEAD `a632ad2`, both pulled with `Already up-to-date.`. Tue 12/05 Block B
(DDS WORKS), Block C (GDAL PE-DLL), and Block E (doc sweep + 5 inline fixes +
Block F propagation) re-read to anchor today's broader scope. **Overnight
inputs:** nothing new from supervisor or teammate maintainer; weather
indoors-only so not a blocker; **formal joint supervisor presentation is now
scheduled Wed 20/05/2026 10h-12h** — supersedes the 30/04 "pending IMT Mines
Alès availability + power restoration" hedge. **Pi-side test decision:**
initially deferred per scaffold (Block B was fully workstation-side); Pi-side
tests became likely once C.6 + C.7 + a user-authorised mid-day C.8 RealVNC
install thread came into scope, all going live on `IoT IMT Nord Europe`. VRX
§8.2 weekly cadence not due (next Mon 18/05).

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

**Outcome.** 24 files swept across the 5 sub-blocks plus repo-wide grep for the
B.4 propagation scan. **B.1**: 12 wiki files; 10 clean, 2 stale forward-update
opportunities — `wiki/Pi5_Bringup_Smoke_Test.md` L139 + L300 (DDS multicast
verification phrasing now superseded by Tue B.1 WORKS). **B.2**: 5 shell + SDF +
xacro files; 4 clean (3 intentional `osrf/vrx` attribution links per Roadmap
§8.6, 1 operational `stale` lifecycle wording), 1 stale forward-update —
`one_click_launch_all/patch_vrx.sh` L2-4 (self-description still said "Patches
upstream VRX" despite the 06/05 fork migration). **B.3**: 7 ROS 2 node Python
files plus launch YAMLs plus 2 `package.xml`; clean docstring↔code
sub/pub/service counts on all 7 nodes; 0 launch-YAML TODO/FIXME; 4 stale
`perception v2.0` references in docstrings (2 in `lidar_perception.py` module
docstring, 2 in `heading_controller.py` method docstrings) plus 1 borderline
missing module docstring on `plan/plan/health_check_service.py`. All 5
node-name keys match Python `Node('...')` per §5 pitfall. **B.4**: Tue-outcome
propagation grep across non-diary tracked surface — 15 hits, 14
accurate/historical, 1 new stale — `wiki/Roadmap.md` §1.1 L28 (same DDS
multicast verification phrasing as B.1, parallel finding). Two conditional
findings (`Pi5_Bringup_Smoke_Test.md` L34 + `Roadmap.md` L23 "headless" claims)
remain ACCURATE today since Branch B DE install is deferred to Mon 18/05+.
**B.5**: `legacy/` boundary clean — 1 append-only commit (`f89a1bc` 07/05 added
`legacy/README.md`, allowed under §1.3); 18 `legacy/` references in tracked
non-legacy non-diary files all intentional documentation pointers. **Fix
decisions:** all 7 stale forward-update findings plus the 1 borderline
(docstring add) applied early in-session under user authorisation — plus 4
additional user-visible v2.0 → v2.1 sites surfaced during pre-edit verification
(Option B) across `wiki/3D_LIDAR_Processing.md` L1 + L33, `wiki/System_Overview.md`
L83, `web_dashboard/autoboat/index.html` L103. Single commit `b535d6d` `docs:
refresh DDS verification + perception v2.1 + patch_vrx wording` — 9 files /
44+/14-. **Needs-real-test escalations: 0** — clean audit-only pass; C.1-C.5
no-op per scaffold gating.

---

## Block C — Audit-real-test escalations (~30-90 min, mid-PM, list-driven)

For each "needs-real-test" item from Block B, run the smallest test that
resolves it. Order by cost: workstation-side first (no offline-window),
Pi-side only when the question is Pi-specific.

**Block C sub-blocks split into two classes (gating is different):**

- **C.1–C.5: B-derived escalations** — gated by Block B producing needs-real-test items. If Block B's needs-real-test list is empty, C.1–C.5 are a no-op.
- **C.6 / C.7: Tue-evening added time-permitting Pi-side candidates** — NOT gated by Block B findings. They run iff (a) time remains after B + C.1–C.5, (b) each sub-block's own pre-condition holds (C.6: hardware brought + Pi reachable; C.7: control box powered up + QGC works). Do NOT skip C.6 / C.7 just because Block B was clean.

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

**Outcome.** **C.1-C.5: no-op** — Block B's needs-real-test list was empty, so
no B-derived escalations triggered (per scaffold gating). The C.1-C.5
pre-staged recipes remain in the scaffold for future audits that surface
needs-real-test items. **C.6, C.7, and a user-authorised C.8 RealVNC install
thread** ran as time-permitting blocks gated by their own pre-conditions, not
Block B's null list — see individual block outcomes below. C.8 was a Wed-only
scope expansion authorised mid-day for parallel workstation-side work; its
Pi-side audit was folded into C.6's SSH pre-flight session to avoid a second
offline-window switch.

---

### C.6 — Pi 5 internet verify + HDMI / USB direct-attach (time-permitting)

User physically brought a Pi-specific HDMI cable (micro-HDMI side) + USB
mouse Tue evening for Wed; supervisor mentioned Pi 5 *may* have internet
(state unverified until on-site). Goal: turn Pi from "remote SSH only"
into a fully operable workstation (graphical desktop + mouse + display)
**if** internet route exists today. User has explicitly authorised the
DE-install boundary override (per Hard boundary clause above).

**Pre-flight: verify Pi 5 internet state (cheap, ~2 min — runs regardless of branch):**

```bash
ssh aqpi-01@10.120.2.50 '
  echo "== default route =="
  ip route get 8.8.8.8 2>&1 | head -3
  echo "== outbound TCP+TLS sanity =="
  curl -sI --max-time 5 https://archive.ubuntu.com 2>&1 | head -3
  echo "== DNS resolvers =="
  cat /etc/resolv.conf | head -5
  echo "== network interfaces =="
  nmcli device status 2>/dev/null || ip -br addr
'
```

**Branch decision based on pre-flight:**

| Pi internet state | Branch | What to do today |
|---|---|---|
| No internet (any route) | **A: TTY-only sanity** | HDMI + USB keyboard validation only; mouse plugged in for `lsusb` detection but cursor not expected (TTY mode, no `gpm`). Pi stays bare. |
| Internet works (IoT-with-internet / separate WiFi / Ethernet / etc.) | **B: install minimal DE** | Per user authorisation; proceed to Branch B steps. |

**Branch A — TTY direct-attach sanity (~10 min):**

1. Connect Pi-specific HDMI cable to display (Pi 5 uses micro-HDMI).
2. Plug USB keyboard + USB mouse into Pi 5 USB-A ports.
3. Expected: HDMI shows kernel boot tail + TTY `login:` prompt; USB keyboard works for login + shell; USB mouse cursor **not** present (TTY mode, expected).
4. SSH-side checks in parallel: `lsusb` to confirm USB devices detected by kernel; `cat /proc/bus/input/devices | grep -A 4 -i mouse` to confirm input subsystem sees the mouse.
5. Outcome: TTY physical-console path validated as fallback for SSH-broken / networking-broken Phase 5 scenarios. No state change.

**Branch B — minimal DE install (~20-40 min including reboot):**

1. Pre-flight already confirmed internet (`curl` got `200`-ish from `archive.ubuntu.com`).

2. **Pre-install sanity (~1 min — abort condition gate):**

   ```bash
   ssh aqpi-01@10.120.2.50 '
     echo "== disk free (/ should have ≥ 2 GB headroom for DE install) =="
     df -h /
     echo "== memory baseline (compare against post-install) =="
     free -h
     echo "== current systemd default target =="
     systemctl get-default
     echo "== apt lock state (should be empty / no PID holding the lock) =="
     sudo lsof /var/lib/dpkg/lock-frontend 2>&1 | head -3
     echo "== apt sources sanity =="
     ls -la /etc/apt/sources.list.d/ 2>&1 | head -10
   '
   ```

   **Abort condition (any one trips → fall back to Branch A, record blocker in Outcome):**

   - `df -h /` shows < 2 GB free
   - `apt` lock held by another process
   - apt sources empty / sources list directory missing
   - `systemctl get-default` returns something unexpected (not `multi-user.target` or `graphical.target`)

3. Update apt index: `sudo apt update`.
4. Install lightweight DE — **LXQt-via-Lubuntu preferred for Pi 5 resource budget**:

   ```bash
   sudo apt install --no-install-recommends lubuntu-desktop
   ```

   Alternative if `lubuntu-desktop` is unavailable:

   ```bash
   sudo apt install --no-install-recommends lxqt-core lxqt-session sddm
   ```

5. Set default boot target to graphical: `sudo systemctl set-default graphical.target`.
6. Reboot Pi: `sudo systemctl reboot`. Workstation SSH session ends; wait ~30 s.
7. Connect HDMI to display; expected: graphical login screen (SDDM if LXQt direct, LightDM if Lubuntu route).
8. Login with `aqpi-01` user via the HDMI + USB keyboard / mouse; verify desktop renders, mouse cursor responsive.
9. Quick smoke: launch terminal app from DE → `source /opt/ros/jazzy/setup.bash` → `ros2 daemon status` → confirm ROS 2 graph still functional with DE running.
10. SSH back from workstation: verify SSH session works alongside local graphical session (no conflict). Capture `free -h` / `df -h /` / `uptime` to baseline resource footprint with DE installed.

**Branch B boundary clarification:**

- DE install is the **only** scope-boundary override authorised today; no autonomy stack / driver service / MAVLink-bridge install in the same session.
- **Rollback precision (DO NOT trust a template purge command):** the actual package set installed depends on which install path took (Lubuntu vs LXQt-core direct), display-manager resolution (sddm / lightdm / etc.), and Recommends pulled by `apt`. **Capture immediately after step 4 the exact `apt install` stdout** (and/or `apt list --installed | grep -E '<keywords>' | sort` filtered post-install) — derive the rollback purge command from THAT, not from this scaffold's template. Record the captured install set + the derived purge command in Outcome so future rollback uses real data.
- If post-install resource budget looks tight (free memory < 1 GB at idle, or CPU steal noticeable), note as "Phase 5 risk: DE retention may need re-evaluation before LiDAR / GPS / IMU drivers load" — Phase 5 bring-up may demand purging DE again.

**Outcome.** **Pre-flight pass — Branch B-conditional decision.** Workstation
reached `IoT IMT Nord Europe` cleanly via `nmcli connection up "IoT IMT Nord
Europe"` from `IMT Nord Europe 5G`. An earlier session-mid WiFi hard-block on
`wlp147s0` (`phy0 Hard blocked: yes` + Dell-firmware `dell-wifi Soft blocked:
yes` per `rfkill list` diagnostic) was recovered by the user off-line before
the pre-flight pipeline started, so the recovery itself isn't in this
session's transcript — the recovery pipeline (Fn+WiFi key for hard block,
`sudo rfkill unblock wifi` + `nmcli radio wifi on` for soft block) is drafted
in the v5-final pipeline Steps 0+1 as a pitfall worth recording for future
on-site sessions where WiFi state can't be assumed-on. Pi 5 SSH
pre-flight via the v5-final layered-IPv4 probe pipeline: default route
`1.1.1.1 via 10.120.2.1 dev wlan0` from `10.120.2.50` ✓; outbound ICMP
**blocked** (`ping -c 1 -W 3 1.1.1.1` → 0/1 received) — common on managed IoT
networks, irrelevant to apt; IPv4 DNS via `getent ahostsv4
archive.ubuntu.com` resolves to Cloudflare CDN `104.20.28.246` ✓; L7 HTTP
egress `curl -4 -sI http://archive.ubuntu.com/ubuntu/` returns `HTTP/1.1 200
OK` ✓; `resolv.conf` shows systemd-resolved stub; `wlan0` up at
`10.120.2.50/23`. ICMP-fails-only pattern with DNS + HTTP working = apt egress
healthy = Branch B DE install technically possible. **Folded-in C.8 Pi VNC
audit:** zero VNC server packages installed (`dpkg -l` matched nothing), zero
VNC systemd units, zero VNC binaries on PATH — confirms Ubuntu Server (24.04.4
aarch64) doesn't bundle RealVNC like Raspberry Pi OS does. **Branch action this session — Branch A succeeded.** Per the box-aware v5
pipeline: SSH `sudo poweroff` → ping-loss + activity-LED settle → cut whole
control-box power → physically attach **micro-HDMI to HDMI1** (HDMI0 is
occupied) + USB keyboard inside de-energised box → re-power whole control box
→ Pi auto-boots with the rest of the system → monitor shows TTY1 boot tail
followed by `imtaqua-pi-01 login:` prompt → USB keyboard input works for
login → shell access at TTY1 confirmed. The "primitive UI/UX" observed is the
expected text-mode console for a headless Ubuntu Server install — no GUI
desktop, no mouse cursor, just kernel framebuffer + getty + login + bash.
Physical-console fallback path validated for SSH-broken / networking-broken
Phase 5 scenarios. No Pi state change from Branch A itself.

**Branch B DE install permanently shelved per professor's directive.** Mid-day
clarification: Pi 5 stays **Ubuntu Server headless permanently** — no GUI /
desktop layer will be added in any future session either. This supersedes the
earlier "deferred to Mon 18/05+" framing. The earlier user-authorised Branch B
scope override is therefore moot and removed from the active plan. C.6's only
remaining purpose was Branch A physical-fallback validation, which succeeded
above.

**Late-day addendum — Pi 5 session-hardening config edits (state-changing,
intentional, distinct from any DE install).** Three Pi-side config tweaks
applied to address recurring "Pi 5 went to sleep" symptoms during longer
testing sessions:

1. `/boot/firmware/config.txt` += `dtparam=power_ctrl_button=off` — disables
   the Pi 5 hardware power button as a shutdown trigger; protects against
   accidental presses inside the cramped control box (the button is small
   and easy to bump while routing cables).
2. `/etc/systemd/logind.conf` `HandlePowerKey=ignore` — logind no longer
   treats a power-button event as a poweroff trigger; redundant with #1 at
   the firmware layer but defends against any software-side handler path.
3. `/etc/systemd/logind.conf` `IdleAction=ignore` + `IdleActionSec=3000mins`
   — logind no longer takes any action (poweroff, suspend, etc.) on
   prolonged user inactivity. The 3000-minute window is essentially "never
   within a normal session."

These are session-hardening edits — **not** scope-creep into Branch B's DE
install territory. They preserve the headless-Ubuntu-Server state while
removing software triggers that could halt the Pi unexpectedly.

**Late-day addendum — brownout root-cause for prior "sleep" symptoms.** Working
theory now well-supported: previously the Pi 5 was powered via 5V on the GPIO
pin (pin 2/4) shared off the main 14.8V LiPo battery rail (10000mAh, 30C ≈
148Wh) with the rest of the control box (autopilot, Herelink, RealSense
camera). 5V-pin power bypasses the Pi 5 USB-C PD negotiation, so the Pi has
no way to advertise its true current need; under RealSense streaming load +
co-loads from other peripherals, the 5V rail sags below the Pi 5 PMIC's
under-voltage trip threshold (~4.63 V), triggering an emergency PMIC shutdown
(LED solid red — looks like "sleep" but is actually a halted SoC). The ~3-4 s
rviz2 streaming window before "sleep" matches the typical RealSense
startup-spike duration. **Temporary fix (verified):** Pi 5 now powered via
its own USB-C charger from a separate supply, decoupled from the main 14.8V
battery rail; other box components stay on the main battery. With the
separate supply, Pi 5 does not enter the brownout-shutdown state during long
rviz2 + camera streaming sessions. This is **operational, not architectural**
— the permanent Phase 5 fix needs hardware-side work: regulated ≥5A 5V
supply dedicated to Pi 5, thick-short GPIO leads (or proper USB-C input),
bulk capacitance near the Pi 5 power input, possibly a powered USB hub
between Pi and RealSense to fully decouple the RealSense's current spikes.
Flagged for Phase 5 hardware-design pass.

---

### C.7 — Camera-ON ROS 2 graph experiment (time-permitting)

Tue B.1 captured the Pi-side topic list with the **camera OFF** (control box not fully booted; topics = `/parameter_events` + `/rosout` daemon defaults + `/pi5_dds_probe` test publisher only). Wed runs the **experiment**: with the control-box camera ON (QGC-triggered via Herelink Hotspot — note the user's setup has camera hardwired to Pi 5, so QGC trigger *may* route through Pi as a ROS publisher node, but this is not yet proven), does the Pi's ROS 2 graph show camera-related topics?

**Two equally valid outcomes** — the experiment is informative either way:

- **(i) Pi ROS graph gains camera topics** → the QGC trigger path goes through a Pi-side ROS node; sim `/wamv/sensors/cameras/*` vs real-hardware naming is exposed; direct input to Block B.4 forward-update scan.
- **(ii) Pi ROS graph unchanged** (still `/parameter_events` + `/rosout` only) **despite QGC video working** → the Herelink video pipeline is **decoupled** from the Pi ROS graph (the verified RTSP route `192.168.43.1:8554/fpv_stream` is workstation-direct-from-Herelink, not via a Pi ROS publisher). This is itself a valuable architectural finding for Phase 5: any future autonomy-stack consumption of camera frames will need a dedicated Pi-side ROS bridge — it's NOT implicit from "Herelink video works".

**Do not treat outcome (ii) as a failure.** Both are valid evidence.

**Pre-req:**

- Control box fully powered up (Pi 5 + autopilot + camera + Herelink).
- QGC (or MP) installed on workstation; Mon 11/05 `Source = Herelink Hotspot` preset preserved.
- Pi 5 reachable via SSH on `IoT IMT Nord Europe` (Tue B.1 verified workflow).
- Single-WiFi-adapter workstation constraint: Herelink Hotspot network (for QGC) and IoT IMT Nord Europe (for ROS 2 topic discovery + Pi SSH on `10.120.2.50`) are different networks — switching required between steps 4 and 8.

**Steps:**

1. Power on control box; wait for Herelink + Pi 5 + autopilot up.
2. Workstation: switch to Herelink Hotspot WiFi (`nmcli connection up "<herelink-ssid>"`).
3. Launch QGC; verify it connects (MAVLink heartbeat visible).
4. Trigger camera ON via QGC video panel (`Source = Herelink Hotspot` preset from Mon 11/05). Verify video stream renders in QGC.
5. **Critical insurance step — while QGC still connected, use Pi 5 local console** (C.6 already attached HDMI + USB keyboard to Pi). Log in directly on Pi's TTY (Branch A) or DE terminal (Branch B), then on Pi run:

   ```bash
   source /opt/ros/jazzy/setup.bash
   ros2 daemon stop && ros2 daemon start
   ros2 topic list > /tmp/pi5_topics_camera_on_qgc_attached.txt   # file lives on Pi
   wc -l /tmp/pi5_topics_camera_on_qgc_attached.txt
   ```

   This captures camera-ON state via Pi local console — no workstation-network-switch coordination needed, no dependency on Pi being reachable from the Herelink network. **The file path `/tmp/pi5_topics_camera_on_qgc_attached.txt` is on the Pi**, not the workstation; later steps need to know this for diff.

6. **(Optional bonus) SSH-snapshot from Herelink network** — cheap check: from the Herelink-connected workstation, `ping -c 2 10.120.2.50`. If reachable (unlikely — Pi at `10.120.2.50` is on IoT network, different L3 from Herelink Hotspot `192.168.43.x`; only works if Pi 5 has a second active interface on Herelink), additionally run a workstation-side SSH snapshot:

   ```bash
   ssh aqpi-01@10.120.2.50 '
     source /opt/ros/jazzy/setup.bash
     ros2 topic list
   ' > /tmp/pi5_topics_via_herelink_ssh.txt   # file lives on workstation
   ```

   If `ping` fails (expected path), skip this step silently. Step 5's Pi-local capture is the authoritative data either way; this step is just bonus cross-validation when network topology happens to allow it.
7. Stop QGC (optional — may leave open).
8. Workstation: switch to IoT IMT Nord Europe (`nmcli connection up "IoT IMT Nord Europe"`).
9. SSH to Pi 5 from IoT-side; re-run topic list capture (file lives on **workstation**):

   ```bash
   ssh aqpi-01@10.120.2.50 '
     source /opt/ros/jazzy/setup.bash
     ros2 topic list
   ' > /tmp/pi5_topics_camera_on_iot_ssh.txt   # file lives on workstation
   ```

   **This tests: did camera state persist across QGC disconnect + workstation network switch?** Compare against Step 5's Pi-local snapshot to detect any disappearance.

10. Workstation cross-machine view via DDS (Tue B.1 verified path) — file also lives on **workstation**:

    ```bash
    export ROS_DOMAIN_ID=56
    export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
    unset RMW_IMPLEMENTATION
    ros2 daemon stop && ros2 daemon start
    timeout 20 ros2 topic list > /tmp/pi5_topics_camera_on_workstation_dds.txt   # file lives on workstation
    wc -l /tmp/pi5_topics_camera_on_workstation_dds.txt
    ```

11. Diff vs Tue B.1 snapshot. Tue's Pi-side bare = `/parameter_events`, `/rosout`, `/pi5_dds_probe` only. Wed-new (camera ON) = the delta. Camera topic naming pattern is the data; common candidates: `/camera/image_raw`, `/camera/compressed`, `/camera_info`, `/<namespace>/camera/...`, vendor-specific like `/herelink/...` or `/usb_cam/...`, or autopilot-bridged names via `mavros2`.
12. Note any sim `/wamv/sensors/cameras/*` inheritance vs real-hardware naming. This feeds Block B.4 directly — if `/wamv/sensors/cameras/*` shows up on Pi, sim-name reuse is happening; if a completely different naming is in play, B.4's forward-update scan has a concrete real-name-vs-sim-name diff to flag in non-diary docs.

**Step-by-step fallback rules (Pi-local console is Step 5's primary; the Herelink-side bonus is Step 6 only):**

- **Step 6 ping fails** (Pi unreachable from Herelink network — expected on standard IoT-vs-Herelink topology): silently skip Step 6 only. Step 5's Pi-local console capture still happened, so the QGC-attached snapshot is preserved. No data gap.
- **Step 5 Pi-local console unusable** (e.g., HDMI not detected, USB keyboard not responding, Pi DE/TTY login broken): this is the only path that loses the QGC-attached snapshot. Fall back to "power on → trigger via QGC (step 4) → switch to IoT (step 8) → SSH+capture from IoT side (step 9-10)" and note in Outcome: "QGC-attached snapshot not captured due to Pi-local console failure; reported topic set may reflect either persistent camera state or already-stopped camera state; state persistence cannot be detected from this run alone".
- **Both Step 5 AND Step 6 unavailable + only Step 9/10 work**: same as above — degraded run, document limitation.

**Two gotchas to predict:**

- (a) Camera-ON state may not persist after QGC disconnect — MAVLink camera commands are typically stateful but if the Pi-side camera node is QGC-session-triggered (per-connection video pipeline), it might shut down on QGC close. **The Step 5 (Pi-local console while QGC attached) vs Step 9 (workstation SSH after QGC disconnect + network switch) comparison detects this directly**; Step 6 is just bonus cross-validation if Pi happens to be reachable on Herelink network, not the persistence detector.
- (b) Topic naming may not match sim `/wamv/sensors/cameras/*` at all — real hardware may use vendor-specific names or autopilot-bridged names. This is expected; the point of C.7 is to find out.

**Outcome.** **Outcome (ii) confirmed — Herelink video pipeline decoupled
from the Pi 5 ROS 2 graph.** Capture topology differed from scaffold: instead
of QGC on workstation switching to Herelink Hotspot, QGC was running on the
**Herelink console itself** (the hand-controller tablet) with active video
render on SSID `IMT-Aquatic-drone`; control box camera ON via the Herelink RF
link. Workstation stayed on `IoT IMT Nord Europe` (no Herelink-network switch
needed since QGC wasn't on workstation). Dual-domain sweep run on the Pi via
SSH (`ROS_DOMAIN_ID=0` AND `=56`) with env hygiene exactly matching Tue B.1's
verified-working setup (`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, `unset
ROS_LOCALHOST_ONLY`, `unset RMW_IMPLEMENTATION`, daemon stop/start between
domains, env-state echo before each topic-list query to defend against silent
env-drop). **Both domains, both runs: identical result — exactly 2 topics, 0
nodes.** Topic set is `/parameter_events [rcl_interfaces/msg/ParameterEvent]`
and `/rosout [rcl_interfaces/msg/Log]` only (standard daemon-bookkeeping).
Captured twice for reproducibility — identical. No `/wamv/sensors/cameras/*`,
no `/camera/*`, no `/herelink/*`, no `/mavros/camera/*`, nothing camera-related.
**Architectural read.** The camera-on-control-box → Herelink air unit →
Herelink ground unit (console) → QGC video panel path is fully decoupled from
any Pi-side ROS 2 publisher. The Mon 11/05 verified RTSP route
`rtsp://192.168.43.1:8554/fpv_stream` works because QGC consumes RTSP directly
on the Herelink Hotspot network (`IMT-Aquatic-drone`), never touching the Pi.
**Phase 5 implication for autonomy stack:** future camera consumption (CA model
input, vision-based obstacle detection, sim/real comparison) needs a
**dedicated Pi-side ROS bridge** consuming Herelink's RTSP and republishing to
a ROS topic (`gscam` / `usb_cam` / custom `rtsp→ROS` bridge) — **not implicit
from "Herelink video works"**. Sim `/wamv/sensors/cameras/*` has no
real-hardware counterpart in the current state. **File-location caveat.** The
per-domain Pi-side capture files
`/tmp/pi5_topics_camera_on_domain{0,56}_<timestamp>.txt` have malformed
filenames from a line-wrap inside `$(date +\n%H%M%S)` in the pasted recipe
(visible `bash: line 25: fg: no job control` warning) — `tee`'s stdout path
captured the data correctly into the SSH session log, which is authoritative
here; no rerun needed.

**Late-day addendum — outcome (i) ALSO confirmed under different conditions
(later in the session, after the QGC-only sweep).** The dual-domain sweep
above tested with QGC providing video via the Herelink RF link and **no
explicit camera node running on the Pi**. Later, a different test path was
explored: with `ROS_DOMAIN_ID=56` UNSET in the workstation `~/.bashrc` (so
default domain 0 applies) and `ros2 run realsense2_camera realsense2_camera_node`
manually started on the Pi via SSH (after `source /opt/ros/jazzy/setup.bash`),
workstation `ros2 topic list` enumerates the **full RealSense camera topic
surface**:

```text
/camera/camera/accel/imu_info
/camera/camera/accel/metadata
/camera/camera/accel/sample
/camera/camera/color/camera_info
/camera/camera/color/image_raw
/camera/camera/color/metadata
/camera/camera/depth/camera_info
/camera/camera/depth/image_rect_raw
/camera/camera/depth/metadata
/camera/camera/extrinsics/depth_to_{accel,color,depth,gyro,infra1,infra2}
/camera/camera/gyro/imu_info
/camera/camera/gyro/metadata
/camera/camera/gyro/sample
/camera/camera/infra1/camera_info
/camera/camera/infra1/image_rect_raw
/camera/camera/infra1/metadata
/camera/camera/infra2/camera_info
/camera/camera/infra2/image_rect_raw
/camera/camera/infra2/metadata
/parameter_events
/rosout
/tf_static
```

This validates **outcome (i) under "explicit Pi-side ROS camera bridge"
conditions** alongside the earlier **outcome (ii) under "no Pi-side ROS
camera bridge"** conditions. The two outcomes are not contradictory — they
correspond to two distinct architectural states:

- **State A (no Pi-side ROS publisher):** Herelink video pipeline runs in
  parallel to the Pi ROS graph; camera frames reach QGC via the Herelink
  RTSP path; nothing camera-related appears on Pi ROS. Outcome (ii) applies.
- **State B (explicit `realsense2_camera_node` running):** Pi ROS graph
  enumerates the full RealSense topic surface (color + depth + IR1+2 +
  accel + gyro + extrinsics + `tf_static`); workstation discovers all
  topics cross-machine via DDS (here `ROS_DOMAIN_ID=0` default; works
  because Pi's default is also 0). Outcome (i) applies. **This is the
  architectural path for Phase 5 autonomy-stack camera consumption** — the
  "dedicated Pi-side ROS bridge" predicted earlier is now directly
  validated, and `realsense2_camera_node` IS that bridge.

**Device + driver context.** RealSense identifies as Intel RealSense D435I
(serial `213622070342`, FW v5.14.0, Product ID `0x0B3A`) on USB 2.1 port
`2-1` (the `[WARN] Device ... connected using a 2.1 port. Reduced
performance is expected.` librealsense informational message is not an
error). Default streaming profiles negotiated by `realsense2_camera_node`
v4.57.7 / librealsense v2.57.7: depth Z16 640×480 @ 15 fps, color RGB8
640×480 @ 15 fps, IR1+IR2 Y8 640×480 @ 15 fps, accel MOTION_XYZ32F @
100 Hz, gyro MOTION_XYZ32F @ 200 Hz.

**Sub-finding — camera consumer exclusivity (Phase 5 architectural
constraint).** With `realsense2_camera_node` running on Pi and workstation
rviz2 actively rendering camera images, the Herelink console's video
stream is **lost**. When rviz2 stops (or the camera node is killed),
Herelink video returns. The two consumers cannot operate simultaneously.
Root cause is most likely v4l2 device exclusivity: `realsense2_camera_node`
opens `/dev/video0` with `VIDIOC_S_FMT` for exclusive format-setting (the
default librealsense behaviour), and the Pi-side **`v4l2loopback` fork
mechanism** (responsible for duplicating the RealSense USB stream for
multiple downstream consumers including Herelink's video pipeline) can't
replicate the format-locked stream. Matches the `xioctl(VIDIOC_S_FMT)
failed, errno=16 Last Error: Device or resource busy` errors observed in
the camera-node bring-up log during repeated `ros2 run` attempts (the
camera node saw its own previous instance still holding the device — race
condition that auto-recovered after the "Checking new devices..."
detect-disconnect-redetect cycle). **Phase 5 implication:** autonomy-stack
camera consumption (via `realsense2_camera_node` → ROS topics) and
Herelink operator video (via the existing RTSP path) are **mutually
exclusive consumers under the current Pi v4l2loopback setup** unless a
different sharing mechanism is engineered (e.g., a single canonical
camera node that republishes to RTP for Herelink, or a multi-mux camera
fork daemon at the v4l2 layer).

**RealVNC scope decision (final this session).** Workstation Viewer
install (`realvnc-vnc-viewer 7.15.1.18`) retained — no harm. Pi-side VNC
server install **parked indefinitely** per the professor's
Pi-stays-headless directive: with no GUI/desktop on Pi, there is nothing
for a VNC server to expose. C.8 thread closed.

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

**Outcome.** Day wrapped in **two commits** due to the two-phase doc-update
shape user requested (pre-test capture, then late-day-findings capture):

1. `b535d6d docs: refresh DDS verification + perception v2.1 + patch_vrx wording`
   — Block B early-application (9 files / 44+/14-) covering 7 stale
   forward-update findings + 1 borderline (docstring add) + 4 Option B
   user-visible v2.0 → v2.1 sites. Landed mid-session under user
   authorisation before the C.6/C.7 physical work.
2. `4a0b277 docs(diary): capture 13/05 Pi preflight + Herelink ROS findings`
   — Pre-Branch-A doc capture (6 files / 118+/23-) covering Block A overnight
   inputs (presentation date Wed 20/05 10h-12h), Block B audit findings list,
   Block C no-op note, Block C.6 pre-flight Branch B-conditional outcome,
   Block C.7 outcome (ii) Herelink/Pi-ROS decoupling, C.8 RealVNC scope
   expansion, Board.md 13/05 Timeline row, Roadmap.md §9 2 new entries,
   3 stamp bumps (`wiki/Home.md`, `wiki/README_WIKI.md`,
   `working_diary/README.md`). Pushed.
3. **This wrap commit** — late-day findings (4 files / ~158+/18-): Branch A
   physical-attach validated (HDMI1 + USB keyboard → Pi TTY1 login confirmed,
   no Pi state change); **Branch B DE install permanently shelved per
   professor's directive** (Pi 5 stays Ubuntu Server headless permanently —
   supersedes the "deferred to Mon 18/05+" framing); 3 Pi-side
   session-hardening config edits applied (`dtparam=power_ctrl_button=off` in
   `/boot/firmware/config.txt`, `HandlePowerKey=ignore` +
   `IdleAction=ignore` + `IdleActionSec=3000mins` in
   `/etc/systemd/logind.conf`); brownout root-cause for prior Pi 5 "sleep"
   symptoms identified (5V GPIO rail sag under RealSense load → PMIC
   under-voltage shutdown ~4.63 V) and temporary fix via separate USB-C
   charger; **C.7 outcome (i) ALSO confirmed under different conditions**
   (`ROS_DOMAIN_ID=0` default + explicit `realsense2_camera_node` running on
   Pi → workstation `ros2 topic list` enumerates full RealSense topic
   surface, validating the predicted dedicated Pi-side ROS bridge);
   camera-consumer-exclusivity Phase 5 constraint identified (rviz2/ROS
   bridge and Herelink RTSP can't stream simultaneously, likely v4l2
   device-exclusivity breaking the existing `v4l2loopback` fork);
   Roadmap §3 status table gains 3 new rows (Pi 5 power budget, RealSense →
   ROS bridge validated, camera consumer exclusivity); `wiki/Pi5_Bringup_Smoke_Test.md`
   + `wiki/Roadmap.md` §1.1 "headless" claims revised from conditional to
   permanent per supervisor directive.

**Pre-commit verification (this wrap commit, run before commit message):**
`git diff --check` clean; invisibility sweep clean on all 4 modified files;
syntax sanity not applicable (no shell/Python edits in this wrap commit);
[To fill] residue at L911 = scaffold instruction text + L922 = this outcome
itself (about to be filled). Working tree will be clean after the wrap
commit lands.

**Final HEAD after wrap commit + push:** to be confirmed in the post-commit
sweep; current pre-wrap HEAD = `4a0b277` matching `origin/main`.

**Carry-forwards to Mon 18/05+** (none reshape today; all are existing items):

- Phase 5 hardware power-design pass (Roadmap §3 new row): regulated ≥5A
  dedicated 5V supply for Pi 5, bulk capacitance near Pi power input, thick
  short GPIO leads or proper USB-C input, possibly powered USB hub between
  Pi and RealSense. Temporary USB-C-charger fix is operational, not
  architectural.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 new row):
  single canonical camera node + RTP republish for Herelink, or multi-mux
  camera-fork daemon at the v4l2 layer — to allow autonomy stack and
  Herelink operator video to consume RealSense simultaneously.
- VRX §8.2 weekly cadence — next check Mon 18/05.
- Three Asks to teammate maintainer (Phase A parameter subset, CA placement,
  validation methodology) — still pending.
- Second-site (lake) Herelink video A/B retest — deferred to next field
  session.
- External Week 10 diary Wed Outcome bullet — Windows-side, deferred to
  next Windows session.

**Thu 14/05 + Fri 15/05** — no on-site work (Ascension Day + pont). Wed
20/05 10h-12h presentation is the next hard deadline; Mon 18/05 + Tue
19/05 are the prep window.

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
| Block B | Findings list collected and classified | **Medium** — drives Block C scope; could rollover to Mon 18/05 if list is large |
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

## Next steps — Wed 13/05 → Mon 18/05+

### Active branch: today's broader doc sweep + audit-real-test escalation

**Thu 14/05 is a public holiday in France (Ascension Day); Fri 15/05 is a
site bridge day off ("pont"). No on-site work either day.** Wed's outcomes
drive the **Mon 18/05 + Tue 19/05** plan, not Thu/Fri:

- **If Wed sweep is clean** (no stale claims, no escalations needed):
  Mon 18/05 can pivot to active work — Phase 5 driver bring-up planning,
  or one of the deferred items below.
- **If Wed finds substantial stale claims**: Mon 18/05 becomes
  continuation / fix-application day, Tue 19/05 left for active work.
- **If Wed escalations surface unexpected runtime issues** (e.g., a
  docstring claim disproved by `ros2 node info`, a stale param-sync
  invariant broken): each becomes a scoped follow-up session, not folded
  into Wed's wrap.

### Pending (carrying past Wed; rolls to Mon 18/05+ given Thu/Fri off-site)

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
  scheme aligned with `launch/remap.launch.yaml`. Slot into Mon 18/05+
  if Wed's sweep is clean.

### Possible time-permitting tasks (pick up only if Wed runs short; otherwise rolls to Mon 18/05+)

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
