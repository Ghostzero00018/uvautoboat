# 2026-05-18 — Monday: post-break sim regression + 13/05 log audit + doc sweep

## Context

Day after Thu 14/05 + Fri 15/05 off-site (Ascension Day + pont — no on-site
work). Last working day was Wed 13/05; final state on `origin/main` is
`336b006 docs: post-wrap audit — IoT managed-egress + RealSense tooling`,
working tree clean.

**Three lead items today (user-directed):**

1. **Sim stack regression test under default `ROS_DOMAIN_ID`.** During
   Wed 13/05 C.7 RealSense bridge validation, `export ROS_DOMAIN_ID=56`
   was unset from the workstation's `~/.bashrc` (so the default
   domain 0 now applies — this was needed for the Pi 5 to be discovered
   under its default-domain `realsense2_camera_node`). Before the rest
   of the week's work, verify the full AutoBoat sim stack still runs
   cleanly under default domain 0 — Gazebo + Rviz + web dashboard
   end-to-end smoke test.
2. **13/05 terminal-log audit.** A plain-text TXT file on the Linux
   workstation captures all 13/05 terminal sessions verbatim (first-hand
   log of the C.6 / C.7 work). Cross-check this against the current
   diary write-up + `wiki/Common_Issues.md` MP-Linux & RealSense entries
   - `wiki/Pi5_Bringup_Smoke_Test.md` + `Board.md` / `Roadmap.md` 13/05
   timeline rows. Flag any stale or incorrect doc claims; harvest
   experiment-idea backlog from log details the diary may have
   compressed out.
3. **General stale-doc / incorrect-claim sweep.** Broader-than-13/05
   pass: anything the audit surfaces that doesn't fit the 13/05 scope.

**Wed 20/05/2026 10h-12h formal joint supervisor presentation is the
hard deadline this week.** Mon 18/05 + Tue 19/05 are the prep window.
**Experiment scope is explicitly capped today** — limit new sim / Pi
runs to what the regression test and log audit need. The bigger Phase 5
backlog items (driver bring-up planning, hardware power-design pass,
camera-consumer sharing) wait until after the presentation.

**Week shape:**

- **Mon 18/05 (today)** — sim regression + log audit + doc sweep; PPT
  prep starts in earnest mid-week.
- **Tue 19/05** — PPT drafting / rehearsal; address any blockers
  surfaced Mon.
- **Wed 20/05** — 10h-12h supervisor presentation (joint work meeting);
  afternoon decompression / day wrap.
- **Thu 21/05 / Fri 22/05** — TBD, post-presentation; potential pivot
  to Phase 5 driver bring-up planning if presentation lands cleanly.

**Pre-break carry-forwards (still pending — no on-site activity Thu/Fri):**

- Phase 5 hardware power-design pass (Roadmap §3 — regulated ≥5A 5V
  supply for Pi 5, bulk capacitance near Pi power input, thick-short
  GPIO leads or proper USB-C input, possibly powered USB hub between
  Pi and RealSense to fully decouple RealSense current spikes).
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 —
  single canonical camera node + RTP republish for Herelink, or
  multi-mux camera-fork daemon at v4l2 layer).
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology).
- Second-site (lake) Herelink video A/B retest — next field session.
- VRX §8.2 weekly cadence — **DUE today** per the Mon 11/05 schedule.

Active blocks:

1. **Block A — Morning re-orientation** (~10 min, opening): verify HEAD
   is `a8d27f3` (or one tail-end doc-fix commit above) + remote sync;
   re-anchor on Wed 13/05's
   Pi-stays-headless directive + brownout root-cause + C.7 RealSense
   bridge validation; VRX §8.2 cadence check (DUE today); break inputs.
2. **Block B — Sim stack regression under default `ROS_DOMAIN_ID`**
   (~45-60 min, AM): bashrc verification + repo-wide `ROS_DOMAIN_ID`
   grep + `--use-nvidia` launcher run + `ros2 node list` / `topic list`
   - dashboard browser tab smoke + health check + short mission cycle.
   Pass criteria mirror 04/05 + 30/04 cold-boot baselines.
3. **Block C — 13/05 terminal-log audit** (~60-90 min, mid-AM/PM):
   user identifies the TXT log path; cross-reference against 13/05
   diary + Common_Issues + Pi5_Bringup_Smoke_Test + Board / Roadmap
   13/05 rows; classify findings (stale / accurate / borderline /
   new-experiment-idea); inline-fix the obvious stale items; queue
   the bigger ones for post-presentation.
4. **Block D — Stale-doc sweep & fix application** (~30-45 min, PM):
   broader-than-13/05 pass; apply low-risk inline fixes; queue
   bigger items for post-presentation; stamp bumps if substantive.
5. **Block E — Day wrap** (~30 min, evening): diary outcomes, Board.md
   Mon 18/05 Timeline row if substantive, commit + push, sketch Tue
   19/05 PPT priorities.

**Hard boundary today:**

- **PPT prep priority is the back half of the week.** Today's three
  lead items must leave headroom for Tue 19/05 slide work. Wed 20/05
  presentation is the actual deliverable.
- No Python / YAML edits without explicit user permission.
- No Phase 5 driver bring-up code; no big-scope new features.
- Pi 5 stays Ubuntu Server headless permanently (Wed 13/05 supervisor
  directive — superseded the earlier Branch B DE-install authorisation).
- Block B regression test is workstation-side only; no offline-window
  switch needed unless Block C surfaces a Pi-specific question.

**Fallback if sim stack regresses under default `ROS_DOMAIN_ID`** (Block B
catches an actual failure): triage in-session; if root cause needs more
than ~30 min, file as a focused follow-up session for Tue 19/05 and
proceed to Block C with a default-domain caveat noted. Don't burn the
whole day on it — presentation prep is the higher-priority output.

---

## Block A — Morning re-orientation (~10 min, opening)

After Thu/Fri off-site break:

- `git log --oneline -10` + `git status` — verify HEAD is `a8d27f3`
  (or one tail-end doc-fix commit above) + branch synced with `origin/main`.
- Re-read Wed 13/05 diary Block C.6 (brownout root-cause + Pi
  session-hardening config edits + Branch B permanently shelved per
  supervisor directive) and Block C.7 (outcome (i) RealSense bridge
  validation under default `ROS_DOMAIN_ID` + camera-consumer-exclusivity
  finding) — the anchors for today's regression test.
- **VRX §8.2 weekly cadence — DUE today** per the Mon 11/05 schedule:

  ```bash
  cd ~/seal_ws/src/vrx
  git status --short
  git pull --ff-only
  git branch --show-current                                      # expect autoboat/main
  git log autoboat/main --not upstream/jazzy --oneline | wc -l   # expect 1 (bake-in e384cd65)
  git tag --sort=-creatordate -l 'v*' | head -3                  # expect v3.1.2 still top
  ```

  4 triggers (patch count, custom mods, Phase 5 sim coupling, upstream
  major release) — HOLD stands unless one fires.

- Break inputs — check supervisor / teammate replies, weather, any
  presentation-related comms (deck request, scope confirmation). If
  email / Slack not reachable, note it and follow up.
- Pi 5 reachability check — defer unless Block C surfaces a Pi-specific
  question. Block B is fully workstation-side.

**Outcome.** Git state clean: HEAD = `1b03702 docs(diary): soften 18/05 Block
A expected-HEAD wording`, one tail-end doc-fix commit above the scaffold's
`a8d27f3` soft anchor; `main` in sync with `origin/main` (0/0 ahead-behind);
working tree clean. Re-anchored on Wed 13/05 C.6 (Pi 5 brownout root-cause —
GPIO-pin 5V sag below ~4.63 V PMIC under-voltage trip under RealSense
streaming load; session-hardening edits applied to `/boot/firmware/config.txt`
and `/etc/systemd/logind.conf`; Branch B DE-install **permanently shelved per
professor's directive** — Pi 5 stays Ubuntu Server headless permanently) and
C.7 (RealSense bridge State B validated: `realsense2_camera_node` on Pi under
default `ROS_DOMAIN_ID=0` enumerates full topic surface to workstation
cross-machine via DDS; camera-consumer-exclusivity finding — `v4l2loopback`
fork can't share format-locked stream, so autonomy-stack camera and Herelink
operator video are mutually exclusive consumers under current Pi v4l2 setup).
**VRX §8.2 weekly cadence (DUE today) — HOLD stands.** `~/seal_ws/src/vrx`
clean tree, on `autoboat/main`, `git pull --ff-only` already up-to-date;
`git log autoboat/main --not upstream/jazzy --oneline` returns exactly 1 commit
(`e384cd65 fix: enable publish_model_pose for LiDAR TF bridge (issue #876)`);
top tag still `v3.1.2`. All 4 triggers (patch count >3, custom mods upstream
wouldn't accept, Phase 5+ sim-side coupling, upstream major release) at 0/4 —
HOLD continues; next cadence check Mon 25/05. **Break inputs:** Wed 20/05/2026
10h-12h formal joint supervisor presentation confirmed unchanged; no other
supervisor / teammate replies, no presentation-scope changes, no machine-state
changes over Thu 14/05 + Fri 15/05 off-site break. **Pi-side test decision:**
Block B is fully workstation-side per scaffold; Pi reachability check deferred
unless Block C surfaces a Pi-specific question.

---

## Block B — Sim stack regression under default `ROS_DOMAIN_ID` (~45-60 min, AM)

**Why this matters.** Wed 13/05 C.7 unset `export ROS_DOMAIN_ID=56` from
the workstation's `~/.bashrc` so that the Pi 5 (running its own
`realsense2_camera_node` under default domain 0) could be discovered
cross-machine without a per-session export. The AutoBoat sim stack —
Gazebo + all ROS 2 nodes + rosbridge + web dashboard + Rviz — was
previously running under `ROS_DOMAIN_ID=56`. **Question: does any piece
of the sim stack hardcode-depend on domain 56**, or is the launcher /
nodes / dashboard / health check fully env-neutral?

**Pre-check (no launch yet):**

```bash
# Verify the change actually persists in bashrc
grep -n 'ROS_DOMAIN_ID' ~/.bashrc           # expect: no matches (or commented out)
echo "Active domain: ${ROS_DOMAIN_ID:-default(0)}"

# Sweep the repo for any hardcoded ROS_DOMAIN_ID references
git grep -nIE 'ROS_DOMAIN_ID' -- ':(exclude)working_diary/*' ':(exclude)legacy/*'
```

If the repo grep surfaces any `ROS_DOMAIN_ID=56` in launcher / health-check
script / dashboard JS / launch YAML / shell — those would explain a
regression before launching anything. Flag and decide whether to inline-fix
(likely trivial: drop the export or make it `${ROS_DOMAIN_ID:-0}`) or
surface for user decision.

**Launch + smoke (~30 min):**

```bash
# Fresh terminal — confirm domain is default (0) before sourcing anything
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-default(0)}"
source ~/seal_ws/install/setup.bash
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
# Wait for the "Total launch time: N s" footer — should land ~43-52 s
# based on prior cold-boot baselines (04/05 = 52 s, 30/04 = 43 s,
# 05/05 warm = 44 s).
```

**Capture runtime graph + diff against last-known-good (05/05) state:**

```bash
ros2 node list > /tmp/mon_node_list.txt
ros2 topic list > /tmp/mon_topic_list.txt
ros2 service list > /tmp/mon_service_list.txt

echo "=== node count ==="; wc -l /tmp/mon_node_list.txt
echo "=== nodes ==="; cat /tmp/mon_node_list.txt
echo "=== topic count ==="; wc -l /tmp/mon_topic_list.txt
```

Pass criteria (matches 04/05 + 05/05 + 30/04 cold-boot baselines):

- 5 expected long-running nodes up under the modular system —
  `/lidar_perception_node`, `/waypoint_planner_node`,
  `/heading_controller_node`, `/waypoint_visualizer_node`,
  `/health_check_service` (the integrated `/AutoBoat` monolith was
  deprecated and moved to `legacy/`; `autoboat_cli` only spawns its own
  node when CLI commands run).
- 0 `BrokenPipeError` in `/tmp/autoboat_launcher_probe.log` — 29/04
  `62636e9` SIGPIPE capture-then-grep refactor should hold.
- No new today-dated `/var/crash/_opt_ros_jazzy*.crash` files.
- Dashboard browser tab at `http://localhost:8002` loads; map renders
  (Path A vendored libs from 05/05 mean no jsdelivr / unpkg / OSM tile
  internet dependency for first-load); camera panel renders; JSON
  panels populate with live data (mission_status, anti_stuck, etc.).
- Health check service: 49 PASS in IDLE state (per 28/04 + 04/05
  baselines).
- Short mission cycle: `autoboat_cli generate/confirm/start` → reach
  at least 1 waypoint → `autoboat_cli stop`. (Skip the full 16-waypoint
  cycle — not needed for regression evidence.)

**If regression observed**: capture exact symptom (which node is missing /
which topic is missing / which dashboard panel is blank) before debugging.
Compare against 13/05 final state to isolate the bashrc-change effect.
Most likely class if it does regress: the launcher or one of its sourced
scripts re-exports `ROS_DOMAIN_ID=56` (which would explain why Pi 5 work
in C.7 needed the bashrc unset — it can't survive that re-export inside
the launcher's shell anyway, so this scenario is structurally unlikely
but worth ruling out by grep).

**Clean shutdown:**

```bash
# Per Mon 13/05 Block C.6 pitfall + §5 pkill self-kill: avoid pkill -f
# patterns whose argv contains the pattern. Use ps + awk + xargs kill
# alternation pattern.
ps -eo pid,cmd | awk '/(launch_autoboat_complete|gz sim|rosbridge|rviz2)/ && !/awk/' \
  | awk '{print $1}' | xargs -r kill 2>/dev/null
sleep 5
ros2 daemon stop
```

**Outcome — Regression test PASS on the core question: no hardcoded-domain
dependency in the sim stack.** Pre-check: `~/.bashrc:123` shows
`#export ROS_DOMAIN_ID=56` (commented out, confirms Wed 13/05 unset);
active session domain default (0). Repo-wide
`git grep -nIE 'ROS_DOMAIN_ID'` surfaced **zero hits in runtime
paths** — all hits were narrative/documentation (commented setup examples in
`README.md` L81, `USER_MANUAL.md` L401 + diagnostic prose, `wiki/Installation_Guide.md`
L131; troubleshooting docs in `wiki/Common_Issues.md` L260/263/1255 +
`web_dashboard/autoboat/README_autoboat_dashboard.md` L236/237; narrative in
`wiki/Dashboard_Security.md` L272 + `wiki/Roadmap.md` L28/190/587/590/591;
historical Timeline rows in `Board.md` L303/305). No launcher / launch YAML
/ dashboard JS / Python node / health-check shell hit. **Launcher run
(`--use-nvidia`)**: 55 s cold-boot (within 43-52 s baseline variance for
first-boot-after-break-of-week); all 6 stages green per launcher footer —
Gazebo (PID 32707), ROS Bridge (33160), Navigation Stack (33245), Web Video
Server (33455), RViz (33537), Web Dashboard (33629); `patch_vrx.sh`
idempotent no-op (`OK: publish_model_pose already true`) — fork bake-in
`e384cd65` in effect. **Runtime graph snapshot**: `ros2 node list` returned
18 nodes total, including all 4 modular user-AutoBoat nodes under their
post-16/04 `_node` suffix (`/lidar_perception_node`, `/waypoint_planner_node`,
`/heading_controller_node`, `/waypoint_visualizer_node`) plus
`/health_check_service` as the 5th long-running user node; full WAM-V
boat-side bridge (`/wamv/frame_publisher`, `/wamv/optical_frame_publisher` ×3,
`/wamv/robot_state_publisher`, `/wamv/ros_gz_bridge`), `/ros_gz_bridge`,
`/rosapi`, `/rosbridge_websocket`, `/rviz2`, `/web_video_server`, anonymous
TF listener. **0 `BrokenPipeError`** in `/tmp/autoboat_launcher_probe.log`

- 29/04 `62636e9` SIGPIPE capture-then-grep refactor holds across the
weekend + Thu/Fri break. **No today-dated `_opt_ros_jazzy*.crash` files** in
`/var/crash/` — only pre-existing 13/05 `_opt_ros_jazzy_bin_rqt.1002.crash`
(from C.7 RealSense introspection) untouched. Dashboard browser tab: user
visual-confirmed no issues during the launch window. **Scaffold-vs-reality
node-name finding worth flagging for Block C audit.** Scaffold's pass
criteria listed 5 expected nodes including `/AutoBoat`. Live IDLE graph
shows `/health_check_service` as the 5th long-running node, no `/AutoBoat`
present. Per `Board.md`, the integrated `/AutoBoat` monolith was deprecated
and moved to `legacy/` (`Note: The integrated AutoBoat monolith has been
deprecated and moved to legacy/.`); the modular IDLE-state 5th node is
`/health_check_service`. `/AutoBoat` may have been the 16/04 rename target
for the now-deprecated Vostok1 monolith, in which case scaffold's pass
criteria copied a stale assumption — to confirm against the 13/05 terminal
log + a fresh grep in Block C. Not a regression in any case. **Items
captured by snapshot before launcher Ctrl+C; not captured live (launcher
already down):** health check 49-PASS service call, short
`autoboat_cli generate/confirm/start` mission cycle, full dashboard panel
populate-with-live-data verification. Sufficient evidence already: the
regression question (does any piece of the sim stack hardcode-depend on
domain 56?) is unambiguously answered NO — pre-check grep + launch + 18-node
graph all align. Re-running for the trailing checks would cost ~30-40 min
and dilute Block C / Block D / PPT-prep headroom; deferred. Block B
PASS-with-trailing-items-acknowledged. **Pi-side test decision held:**
Block C may still need Pi-specific data depending on what the 13/05 log
audit surfaces, but Block B itself stayed fully workstation-side per
scaffold's hard boundary.

---

## Block C — 13/05 terminal-log audit (~60-90 min, mid-AM/PM)

**Setup:** user identifies the path to the 13/05 terminal-log TXT file
(saved on the Linux workstation; not in the repo). Read in full, then
cross-reference against the 13/05 diary write-up and adjacent docs.

**Targets for cross-reference:**

```text
working_diary/2026-05-13_wednesday_doc_sweep_deeper_pass.md   ← Wed diary
Board.md                                                       ← 13/05 Timeline row
wiki/Roadmap.md §1.3 (managed-egress correction) + §3 + §9     ← 13/05 entries
wiki/Common_Issues.md (RealSense / camera-consumer-exclusivity / IoT egress)
wiki/Pi5_Bringup_Smoke_Test.md (headless-permanent revision)
```

**Audit framework (mirrors Wed 13/05 Block B classification):**

- **stale** — diary or wiki claim contradicts the terminal log
- **accurate** — diary / wiki matches log evidence cleanly
- **borderline** — wording soft, ambiguous, or compressed but not
  strictly wrong
- **new-experiment-idea** — log surfaces a follow-up worth queuing
  (post-presentation)

**Read pattern:**

1. Skim the TXT log start-to-end to understand session shape.
2. For each substantive log block (each terminal session / each Pi
   SSH sequence / each launcher run / each RealSense bring-up attempt),
   identify what doc claim it supports or contradicts.
3. Build a findings table: `file:line` → claim → log evidence → verdict.
4. Inline-fix the **stale** items with high confidence + low ambiguity;
   queue everything else.

**Specific claims worth verifying against the log** (drawn from the
13/05 diary write-up — easy to spot-check):

- C.6 pre-flight: `getent ahostsv4 archive.ubuntu.com` → `104.20.28.246`;
  `curl -4 -sI http://archive.ubuntu.com/ubuntu/` → `HTTP/1.1 200 OK`;
  `ping -c 1 -W 3 1.1.1.1` → 0/1 received.
- C.6 brownout: PMIC under-voltage threshold ~4.63 V; the ~3-4 s rviz2
  streaming window before "sleep".
- C.7 RealSense device: D435I serial `213622070342` FW v5.14.0
  Product ID `0x0B3A` USB 2.1 port `2-1`; profiles depth Z16
  640×480 @ 15 fps, color RGB8 640×480 @ 15 fps, IR1+IR2 Y8
  640×480 @ 15 fps, accel 100 Hz, gyro 200 Hz; driver v4.57.7 /
  librealsense v2.57.7.
- C.7 camera-consumer-exclusivity: `xioctl(VIDIOC_S_FMT) failed,
  errno=16 Last Error: Device or resource busy`.
- Block A presentation: Wed 20/05/2026 10h-12h scheduled.

If the log says something different on any of these, it's a stale
claim — fix inline.

**Hard scope cap.** Don't escalate the audit into a full Wed 13/05
re-do — the goal is doc-quality polish + experiment-idea harvest, not
new real-world testing today. Wed 20/05 presentation is the actual
output.

**Outcome — 13/05 diary's C.6 / C.7 write-up holds up cleanly against the
log; 1 borderline + 3 new-data-points + 1 scaffold-bug carry-forward.** Log
path: `/home/ghostzero/Desktop/13_05_2026_test_logs.txt` (1336 lines, 82 KB,
~40 k tokens — read in 3 chunks). **Findings counts: 17 accurate / 0
contradicted / 1 borderline / 3 new-experiment-data-points / 1 scaffold-bug
carry-forward to Block D.** **Accurate (sampled — 17 cleanly supported
claims):** workstation `IMT Nord Europe 5G → IoT IMT Nord Europe` hop (log
L6-7), Pi default route `1.1.1.1 via 10.120.2.1 dev wlan0` (L35-37), ICMP
blocked 0/1 (L38-40), DNS `archive.ubuntu.com → 104.20.28.246` (L42-44), HTTP
egress `200 OK Date: Wed, 13 May 2026 12:06:34 GMT` (L46-48), Pi VNC audit
zero pre-install (L60-67), C.7 dual-domain sweep `/parameter_events +
/rosout` only on both domains across 4 separate runs (L132-413; diary's "twice"
under-counts the actual reproducibility), `bash: line 25: fg: no job
control` (L139 etc.), RealSense `xioctl(VIDIOC_S_FMT) errno=16` recurring
across 5+ invocations including post-reboot (L525, L652, L742, L1016, L1254
— validates diary's "do not attribute narrowly to the camera node's own
previous instance"), auto-recovery cycle to `RealSense Node Is Up!` (L540-577
etc.), SSH instability `Broken pipe / Connection timed out / No route to
host` around brownout (L466, L592-593, L1068-1078, L1163-1166), `apt install
rviz` not found (L919-924, L925-929 — two attempts), `ros2 run rviz2 rviz2`
and bare `rviz2` both launch (L930-942), `rqt` `realsense2_camera_msgs`
`ModuleNotFoundError` trace (L845-915), RealSense streaming profiles depth
Z16 / color RGB8 / IR Y8 all 640×480 @ 15 fps + accel 100 Hz + gyro 200 Hz
(L521-575), D435I serial / FW / Product ID / USB 2.1 protocol identity
(L498-502, L514-515), full workstation cross-machine topic surface (L809-836,
list ordering exact match). **Borderline (1, inline-fixed in
`wiki/Roadmap.md` §3 L190).** RealSense USB hub port enumeration varied
across sessions: `2-1` dominant (16:25 / 17:33 / 17:40 / 17:41 runs), `1-1`
observed once (17:14 pre-reboot run at L1233-1235 with
`usb1/1-1/1-1:1.0/video4linux/video0` + `Device with port number 1-1 was
found`). Likely a physical re-plug between sessions or USB bus
re-enumeration after the 16:48 brownout / shutdown cycle. Roadmap §3 row
amended with single parenthetical noting both ports observed. 13/05
`working_diary` entry left untouched per the append-only frozen-history rule;
`Board.md` L305 doesn't make a port-number claim (only the USB-2.1 protocol
generation, which is unambiguous), so no Board edit needed. **New
experiment-data-points (3, all queued post-presentation, low priority).** (1)
Pi 5 thermals during RealSense streaming: 43.3 → 46.2 → 51.8 → 57.2 → 59.0
→ 61.1 → 63.4 °C across the session (Ubuntu MOTD on every SSH reconnect:
L476, L603, L967, L1088, L1175, L1207, L1316). 63 °C peak is well within Pi
5's safe range (~85 °C throttle). Positive evidence for Phase 5 hardware-design
pass's "Static analysis of thermals + current draw under full-stack load"
prep task. (2) 49 apt updates pending on Pi 5 (37 security) surfaced on
every SSH MOTD — Phase 5 driver bring-up decision branch: apply updates
before driver work (risk: kernel updates may reset device-tree overlays /
cause boot regressions) or defer. Queue for Thu 21/05+ driver bring-up
planning session. (3) RealSense first-invocation xioctl-error-then-auto-recover
is the **steady-state pattern**, not a transient failure (5/5 invocations show
it across reboots, sessions, and USB ports). Worth a one-paragraph operator-facing
note in `wiki/Common_Issues.md` or `wiki/Pi5_Bringup_Smoke_Test.md` so future
bring-up operators don't panic when the first `ros2 run realsense2_camera`
shows red text then succeeds in ~2 s. Queue post-presentation. **Scaffold-bug
carry-forward to Block D (1).** Today's diary scaffold Block B L200-201
listed 5 expected nodes including `/AutoBoat`. Per `Board.md` L32, the
integrated `/AutoBoat` monolith has been deprecated and moved to `legacy/`;
the modular system's 5 long-running IDLE nodes are the 4 `_node`-suffixed
ones (`lidar_perception`, `waypoint_planner`, `heading_controller`,
`waypoint_visualizer`) plus `health_check_service`. Live Block B graph
confirmed this — `/AutoBoat` never appeared. Scaffold author copied stale
expectation. Inline-fix the scaffold prose in Block D's broader sweep.
**Pi-side test decision held**: Block C didn't surface a Pi-specific question
needing a live Pi probe; audit was log + doc cross-reference only. No Pi
SSH session today.

---

## Block D — Stale-doc sweep & fix application (~30-45 min, PM)

Block C may surface findings that fit into Block D's broader sweep; pull
through here. **Inspect-only by default** for anything beyond the obvious
inline fixes from Block C.

**Targets** (broader than Block C's 13/05-anchored scan):

- `README.md` — any drift since Mon 11/05 last touch?
- `USER_MANUAL.md` — last substantive edit 06/05 per Tue 12/05 E.6;
  re-verify the stamp + content alignment.
- `wiki/Home.md` / `wiki/README_WIKI.md` / `working_diary/README.md` —
  stamp bumps if today lands substantive content (currently at the
  post-Wed-`4a0b277` re-bump state, likely `13/05/2026`).
- `web_dashboard/autoboat/README_autoboat_dashboard.md` — last
  substantive edit 07/05 per Tue 12/05 E.6 verification.
- Roadmap §3 status table rows added 13/05 (Pi 5 power budget,
  RealSense bridge validated, camera consumer exclusivity) — verify
  they read cleanly post-break.

**Risky-term grep pattern** (same shape as Tue 12/05 Block E + Wed 13/05
Block B):

```bash
for f in README.md USER_MANUAL.md Board.md \
         wiki/Home.md wiki/README_WIKI.md wiki/Roadmap.md \
         working_diary/README.md \
         web_dashboard/autoboat/README_autoboat_dashboard.md; do
  echo "=== $f ==="
  grep -nIE 'fail|degrad|unresolved|open|TBD|deferred|pending|broken|missing|todo' "$f" | head -10
done
```

Then read each hit in context. Cross-check against today's known state
(Block B regression verdict + Block C audit findings + Wed 13/05 final
state on `origin/main`).

**Outcome — broader sweep clean; 2 carry-forward fixes from Block C
landed.** Risky-term grep across the 8 target files (`README.md` /
`USER_MANUAL.md` / `Board.md` / `wiki/Home.md` / `wiki/README_WIKI.md` /
`wiki/Roadmap.md` / `working_diary/README.md` /
`web_dashboard/autoboat/README_autoboat_dashboard.md`) returned **0 stale
claims** — all ~43 hits across the 8 files were legitimate (license badges,
instructional prose like "Then open ...", troubleshooting tables for vendored
assets / build failures / WebSocket / GPS, accurate Phase 5 status rows,
Roadmap meta-description "open questions", `working_diary/README.md`
append-only convention). No inline fixes needed from the broader sweep.
**2 carry-forward fixes from Block C applied.** (1) Scaffold-bug at today's
diary Block B pass-criteria list (was around L222-224) — the original prose
listed 5 expected nodes including `/AutoBoat` (the 16/04 rename target for
the deprecated Vostok1 monolith, which `Board.md` L32 records as moved to
`legacy/`). The live Block B `ros2 node list` snapshot showed
`/health_check_service` instead. Replaced with the correct 5 `_node`-suffixed
modular nodes (`/lidar_perception_node`, `/waypoint_planner_node`,
`/heading_controller_node`, `/waypoint_visualizer_node`) plus
`/health_check_service`, with a clarifying note that `autoboat_cli` only
spawns its own node when CLI commands run. (2) `wiki/Roadmap.md` §9 revision
log gains an 18/05/2026 entry capturing the §3 RealSense USB port-enumeration
parenthetical landed earlier today in commit `de6e0af`. Single-line entry
matching §9 convention; provides change provenance for future readers.
**No stamp bumps in Block D.** `wiki/Home.md`, `wiki/README_WIKI.md`,
`working_diary/README.md` were untouched today and stay at 13/05/2026.
`Board.md` Last-Updated also stays at 13/05/2026; any 18/05 Board.md
Timeline-row addition is a Block E decision per scaffold ("if substantive").
**Block D scope cap respected** — inspect-only by default for everything
outside the Block C carry-forwards. PPT-prep headroom preserved for
Tue 19/05.

---

## Block E — Day wrap (~30 min, evening)

Same shape as Wed 13/05 Block D:

1. `git log --oneline -10` — sanity check today's commits.
2. `git diff --check` — whitespace / conflict-marker sweep.
3. Add 18/05/2026 `Board.md` Timeline row **if substantive findings
   landed**; bump header `Last Updated` + footer `Document Version`
   (9.11+ → next) if any tracked content updated. **Use search rather
   than line numbers** (both rows drift as Board.md grows).
4. Fill all `[To fill]` placeholders in this file.
5. Working diary commit; subject template depends on dominant outcome:
   - Clean regression + clean audit:
     `docs(diary): wrap 18/05 sim regression OK + 13/05 audit clean`
   - Regression caught + audit findings:
     `docs(diary): wrap 18/05 sim regression fix + 13/05 audit findings`
   - Audit-only (regression skipped):
     `docs(diary): wrap 18/05 13/05 log audit + doc sweep`
   - Mixed:
     `docs(diary): wrap 18/05 post-break sim check + log audit`
6. Push.
7. **Queue Tue 19/05 PPT prep priorities** — which slides need new
   content from 13/05 work? Power-budget finding? RealSense bridge
   validation? Pi-stays-headless directive? Camera-consumer-exclusivity?
   Sketch a slide outline at session end if time permits.
8. **Update Week 10 / Week 11 external diary if applicable** — Week 10
   wrap was Wed 13/05; if Mon's work fits Week 11 scope, draft Week 11
   external diary skeleton. Windows-side; defer to next Windows session
   if Linux-only today.

**Outcome — day closed clean; 3 commits + Board.md row + PPT-prep on
deck for Tue 19/05.** `Board.md` Timeline gains an 18/05/2026 row
capturing the three Block-level outcomes (sim regression PASS + 13/05 log
audit clean + broader sweep clean) plus the inline fixes that landed
during the day; `Board.md` header `Last Updated` bumped 13/05/2026 →
18/05/2026, footer `Document Version` bumped 9.12 → 9.13. All 5
Verification-summary checkboxes ticked. **Total commits today: 3** —
`de6e0af docs: 18/05 Block A-C fills + Roadmap RealSense port note`,
`c9cec9c docs: 18/05 Block D outcome + scaffold node fix + Roadmap §9`,
plus this Block E wrap commit. `git diff --check` clean (no whitespace / conflict
markers). **Tue 19/05 is full PPT-prep day** — the "sim stack clean"
branch from the Next Steps conditional matrix applies; concrete 10-slide
outline now appended to the Active branch subsection below for tomorrow's
starting point. Wed 20/05/2026 10h-12h presentation slot stays immutable.
**Pi-side test decision held end-to-end**: Block C audit was log + doc
cross-reference only; no Pi SSH session today. No external Week 11 diary
scaffolded today (Linux-only session; defer to next Windows session).

---

## Verification summary — 18/05 (check at end of day)

- [x] Block A: re-orientation done; HEAD confirmed (`a8d27f3` or one tail-end doc-fix commit above); VRX §8.2
  cadence check run (HOLD or trigger noted); break inputs noted;
  Pi-side test decision recorded
- [x] Block B: sim stack regression test run; pass-criteria verdict
  recorded; any regression debugged or filed as Tue 19/05 follow-up
- [x] Block C: 13/05 log audit complete; findings classified (stale /
  accurate / borderline / new-experiment-idea); inline fixes applied;
  experiment backlog queued for post-presentation
- [x] Block D: stale-doc sweep across the 8 target files; fixes applied
  vs queued; stamp bumps landed if substantive
- [x] Block E: diary filled; `git diff --check` clean; Board.md updated
  if substantive; commit + push handled; Tue 19/05 PPT priorities
  sketched

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation done | None |
| Block B | Sim regression result known | **High** if regressed (debugging may rollover to Tue 19/05); **None** if clean |
| Block C | 13/05 audit findings classified | Medium — drives Block D fix scope |
| Block D | Doc sweep done | Low — fixes independent |
| Block E | Day closed; Tue priorities queued | Standard |

---

## Known unknowns to record during the day

- Does any part of the sim stack hardcode-depend on `ROS_DOMAIN_ID=56`?
  (Block B repo-side grep + actual launch test answer this.)
- Did the diary's compressed 13/05 write-up miss any log details worth
  preserving for the presentation deck? (Block C audit.)
- Are there post-13/05 stale doc claims beyond the 13/05 scope?
  (Block D sweep.)
- Tue 19/05 PPT scope — which slides need updates from 13/05 work?
  (End-of-day sketch.)
- Break inputs (supervisor / teammate replies, weather, presentation
  scope confirmation).

---

## Next steps — Mon 18/05 → Wed 20/05 presentation

### Active branch: post-break sim check + log audit + doc sweep + PPT prep kickoff

Today's outcomes drive Tue 19/05's PPT-prep block:

- **If sim stack is clean under default domain**: Tue 19/05 is full PPT
  prep — slides, rehearsal, last-minute fact-check sweep against the
  current `origin/main` state.
- **If sim stack regressed**: Tue 19/05 splits between regression fix
  (morning) and PPT prep (afternoon). Wed 20/05 morning slot is
  immutable — presentation goes ahead either way.
- **If 13/05 audit surfaces architecturally important findings**:
  decide on a case-by-case basis whether to fold into the presentation
  deck (only if directly relevant to the supervisor-facing scope) or
  queue for post-presentation Thu 21/05+.

**Conditional resolution (EOD 18/05).** Sim stack clean — Block B PASS, no
regressions. Block C audit confirmed 13/05 diary holds (17 accurate / 0
contradicted / 1 borderline inline-fixed). No architecturally-new findings
that would force a deck rewrite. Tue 19/05 is therefore **full PPT prep
day** — slides, rehearsal, last-minute fact-check sweep against the current
`origin/main` state.

**Concrete 10-slide outline — starting point for Tue 19/05:**

1. **Title + agenda** (~5 min)
2. **Project status snapshot** — Phase 1 done / Phase 2 done / Phase 4 90 % /
   Phase 5 starting / Phase 3 paused; `Board.md` 90 % progress badge
3. **Phase 5 architecture** — Pi 5 as companion computer (23/04/2026
   visual-verified inside CCU); MAVLink autopilot as working hypothesis
   (specific chip / firmware still open, see `Board.md` Risk #3)
4. **First wet test 07/05/2026 outcomes** — Herelink manual control + QGC/MP
   arm-disarm both work; autonomy untested; video resolved 11/05 campus side
   under known-good `Source = Herelink Hotspot` preset (post-SkiaSharp /
   libdl host-local fix for MP-Linux)
5. **Network architecture findings** — DDS WORKS on `IoT IMT Nord Europe`
   12/05/2026 (standard ROS 2 graph discovery, no Discovery Server needed);
   Herelink / Pi-ROS decoupling (13/05 C.7 — RTSP path is workstation-direct
   from Herelink, not via a Pi ROS publisher); three deployment networks by
   exact SSID (`IMT Nord Europe 5G` / `IoT IMT Nord Europe` /
   `IMT-Aquatic-drone`)
6. **Pi 5 bring-up findings** — Pi stays Ubuntu Server headless permanently
   (13/05 supervisor directive); brownout root-cause (5V GPIO sag below
   ~4.63 V PMIC under-voltage trip under RealSense streaming load — was
   misread as "sleep"); session-hardening edits to `/boot/firmware/config.txt`
   and `/etc/systemd/logind.conf`; RealSense → ROS bridge State B validated
   via `realsense2_camera_node` on Pi
7. **Camera-consumer-exclusivity constraint** — `realsense2_camera_node` on
   Pi + workstation rviz2 streaming → Herelink console video lost; likely
   `v4l2loopback` fork can't share format-locked stream; Phase 5
   sharing-mechanism design space (single canonical camera node + RTP
   republish for Herelink, or multi-mux camera-fork daemon at v4l2 layer)
8. **VRX upstream fork + sim infrastructure stability** — `e384cd65`
   `publish_model_pose` bake-in on `Ghostzero00018/vrx autoboat/main`
   (06/05); §8.2 weekly cadence still HOLD (18/05 check, 0/4 triggers
   fired); today's regression PASS demonstrates the modular sim stack runs
   cleanly under default `ROS_DOMAIN_ID` post-13/05 bashrc unset
9. **Obj 1 / Obj 2 / Obj 3 scope refinements** (post-30/04 on-site scoping
   meeting) — Obj 1 = telemetry only (water-sensor data is Obj 2); CA
   placement most likely Linux-side; Obj 3 "regional datasets" portion
   removed (insufficient accessible regional historical data); validation
   refined to same-day cross-validation; ML scope refined to
   residual-based + time-series + physics-informed (stretch); "ML trained
   on CA outputs" framing rejected
10. **Open questions for supervisors + next steps** — Phase 5 driver
    bring-up planning starts Thu 21/05+ (newly unblocked by 12/05 DDS PASS
    - 13/05 RealSense bridge State B); **Three Asks to teammate maintainer
    still pending** (Phase A parameter subset / CA placement confirmation /
    validation methodology); Phase 5 hardware-design pass (regulated ≥5A 5V
    supply, bulk capacitance, possibly powered USB hub); second-site
    Herelink video A/B retest deferred to next field session

### Pending (carries past Mon; mostly post-presentation)

- Phase 5 driver bring-up planning — newly unblocked post-Tue 12/05
  B.1 DDS WORKS + Wed 13/05 C.7 RealSense bridge validation; first
  focused session can plan: LiDAR / GPS / IMU driver candidates,
  `mavros2` install path, autostart strategy on Pi, topic-name scheme
  aligned with `launch/remap.launch.yaml`. **Post-presentation slot
  (Thu 21/05+).**
- Phase 5 hardware power-design pass (Roadmap §3 new row) — regulated
  ≥5A 5V supply, bulk capacitance near Pi power input, thick-short
  GPIO leads or proper USB-C input, possibly powered USB hub between
  Pi and RealSense.
- Phase 5 camera-consumer sharing mechanism design (Roadmap §3 new
  row) — single canonical camera node + RTP republish for Herelink,
  or multi-mux camera-fork daemon at v4l2 layer.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology) — still pending.
- Second-site (lake) Herelink video A/B retest — deferred to next
  field session under known-good QGC `Source = Herelink Hotspot`
  preset.
- VRX §8.2 weekly cadence next check — Mon 25/05 (if today's check
  passes HOLD).

### Possible time-permitting tasks (pick up only if Mon runs short)

- **P1 pier/bank stuck investigation** — diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md`
  Block A. Substantial sim work; naturally pauseable. Requires
  `--use-nvidia` to hold acceptable RTF (~0.32 → ~0.88).
- **Phase 5 driver bring-up planning skeleton** — paper plan only,
  no Pi work today. Captures which drivers go first, install ordering,
  topic-name scheme.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — unblocked once
  supervisor confirms parameter set).
- Roadmap §1.3 Path B (offline tile server with pre-generated MBTiles
  for the test-site area) — required before first IoT-network field
  deployment.
- Dashboard CSP Option B (reverse-proxy header injection) and Option C
  (Caddy / external static webserver).
- 24/04 housekeeping carry-overs (`mono-xsp4` port-8084 disable;
  `tools/qos_scan.py` single-pass QoS inventory companion to
  `rate_probe.py`).
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware
  double-reverse symptom.
- Sim-to-real comparison — N/A until a future field test records
  autonomy bag data.
- External Week 11 diary scaffold creation — Mon evening Windows-side
  task; defer to next Windows session if Linux-only today.
