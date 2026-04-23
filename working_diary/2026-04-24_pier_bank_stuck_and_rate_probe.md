# 2026-04-24 — P1 pier/bank investigation + MP/QGC install + rate-probe

## Context

Scaffold written evening of 23/04 as tomorrow's work template — fill in each section as the day progresses.

**Hardware context from 23/04 afternoon supervisor meeting.** Prof walked through the real hardware in person — boat frame, control unit box, battery, and inside the control unit a **Raspberry Pi 5** as the companion computer (confirms the Pi 5 target that was tentative in Board.md). Prof introduced two mission-planner GUIs: **QGroundControl** (cross-platform, MAVLink, PX4/ArduPilot compatible) and **Mission Planner** (ArduPilot ecosystem, Windows-native / Linux-via-Mono), with **Mission Planner preferred**. Prof also raised a longer-term goal: the webdashboard should eventually mirror its current waypoint-issue + live-telemetry flow against MP/QGC as the autopilot front-end, not directly against ROS 2 nodes. Full integration is Phase 5.2+ scope (post-bringup); tomorrow just seeds the install side.

**Mixed-scope day for 24/04.** P1 pier/bank (carried since 20/04 pressure test) leads the morning — 2-3 h, needs live sim. Mid-day block installs MP + QGC on the Linux workstation. Then P3 rate-probe tool (~45 min, Linux-local). UX pass 2 as filler if capacity remains. No supervisor meeting tomorrow; Phase A implementation remains blocked on further conversation.

Four planned blocks, each independently commit-able and stoppable:

1. **P1 pier/bank stuck investigation** — reproduce in sim, trace where SASS / controller state misbehaves against a static obstacle with vertical extent, propose fix scope (don't necessarily implement today).
2. **Install Mission Planner + QGroundControl** — prof-requested mission-planner GUIs on the Linux workstation (QGC native AppImage, MP via Mono). Smoke-launch only — no vehicle to connect to yet.
3. **P3 `tools/rate_probe.py`** — standalone publisher-rate probe with configurable QoS, works around `ros2 topic hz`'s Jazzy limitation (no `--qos-*` flags) that misreports rate on BEST_EFFORT publishers.
4. **Dashboard UX pass 2** — mission-control edge cases: Reset during Confirm window, Go Home while already at home, multi-click Joystick toggle mid-mission.

Plus wrap-up diary fill-in at end of day.

## Block A — P1 pier/bank stuck investigation

Long-running open item from 20/04 pressure test. Boat appears to enter a stuck state when navigating close to a pier or bank (shallow-slope vertical obstacle). Current SASS (`wiki/SASS.md`: "turn toward clearer side") was designed around floating buoy-like obstacles; it's unclear how well the same logic handles an obstacle with near-vertical extent and large lateral footprint.

### Diagnostic steps (inspect-only first)

Pull + launch:

```bash
cd ~/seal_ws/src/uvautoboat
git pull
cd one_click_launch_all
bash launch_autoboat_complete.sh sydney_regatta_DEFAULT
# Wait for readiness polls to finish (~20-40 s)
```

In an idle terminal:

```bash
source ~/seal_ws/install/setup.bash
# Watch SASS + anti-stuck status live
ros2 topic echo /control/anti_stuck_status &
ros2 topic echo /control/status &
```

Trigger a mission that routes the boat close to a pier/bank:

1. Use dashboard to Generate Waypoints with a short lawnmower pattern placed near a static scenery feature (or set `start_position` manually via waypoint override).
2. Confirm + Start.
3. Watch for the moment the boat stops making progress. Note: (a) distance to nearest obstacle per `/perception/obstacle_info`, (b) whether SASS fires (anti_stuck_status transitions), (c) whether reverse trigger engages (≤6 m critical distance), (d) whether reactive-steer engages (≤12 m `min_safe_distance`).

### What to look for

- **SASS-fires-but-doesn't-help:** boat turns toward clearer side, re-approaches, gets stuck again — classic pier/bank loop. Root cause likely: the "clearer side" computation treats the pier edge as a single obstacle rather than a continuous wall, so every retreat-and-turn brings it back perpendicular to the same obstacle.
- **SASS-never-fires:** anti-stuck timeout (12 s) not tripping because the boat IS making some forward progress against the bank (micro-creep) but below the 1 m movement threshold. Would surface as no `anti_stuck_status` transitions.
- **Perception under-reports distance:** vertical extent + close range pushes points outside the `-1.2 to 1.5` m height filter band, leaving the planner thinking the path is clear. Sanity-check by comparing `/perception/obstacle_info` front-sector distance vs. eyeballing the sim.

### Outcome — fix scope proposal (not implementation)

Write 2-3 paragraphs in this block at end of investigation:

- What exact mechanism fails (which of the three above, or something else).
- What fix direction looks plausible (e.g., "expand height filter upper bound to 3 m for near-range clustering", or "SASS needs a wall-detection heuristic distinct from the buoy-like case").
- Estimated effort and risk for the fix.

Implementation is deferred to a later block (24/04 afternoon if investigation concludes fast, or 25/04 otherwise).

**Outcome.** [To fill — mechanism identified, fix direction, effort estimate, commit hash if a diagnostic patch landed.]

## Block B — Install Mission Planner + QGroundControl (prof request)

Per 23/04 afternoon meeting. Both GUIs are MAVLink-based and assume a compatible flight controller / autopilot — the Pi 5 companion + TBD autopilot firmware will eventually provide that. Goal today is install + smoke-launch (each GUI opens cleanly with no vehicle connected). Connection to real hardware is Phase 5.1+.

### QGroundControl — Linux AppImage

Primary reference: <https://docs.qgroundcontrol.com/master/en/qgc-user-guide/getting_started/download_and_install.html>

```bash
# Prerequisites
sudo usermod -a -G dialout $USER              # serial-port access; log out/in to take effect
sudo apt update
sudo apt install libfuse2 libqt5gui5 \
    gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl -y
# Optional — only if no cellular modem in use (ModemManager hijacks USB-serial devices):
sudo apt remove modemmanager -y

# Download stable AppImage + launch
cd ~/Downloads
wget https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl.AppImage
chmod +x QGroundControl.AppImage
./QGroundControl.AppImage
```

Verify: GUI launches; without a vehicle connected it sits at a "Waiting for Vehicle Connection" banner. Record version from Help → About.

### Mission Planner — via Mono on Linux (prof's preferred tool)

Primary reference: <https://ardupilot.org/planner/docs/mission-planner-installation.html>

Mission Planner is .NET-native on Windows; Linux support is via the Mono runtime. Functional for mission planning + basic telemetry but historically has occasional UI glitches vs. the Windows version.

```bash
# Prerequisites: Mono .NET runtime
sudo apt update
sudo apt install mono-complete -y
mono --version     # expect Mono JIT compiler 6.x or newer

# Fetch + unpack the latest Mission Planner Linux zip
cd ~/Downloads
wget https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.zip
mkdir -p ~/MissionPlanner
unzip -o MissionPlanner-latest.zip -d ~/MissionPlanner

# Run
cd ~/MissionPlanner
mono MissionPlanner.exe
```

Verify: GUI launches; equivalent "Waiting for Vehicle Connection" state. Record version from Help → About.

### Fallback — Windows-native install on the laptop

If MP under Mono turns out too flaky for prof's planned demos (known issues include slow rendering, occasional crashes, some plugins non-functional), install the Windows-native `.msi` from the same `firmware.ardupilot.org/Tools/MissionPlanner/` path onto the Windows laptop. Workflow then: Linux workstation stays primary for sim + ROS; Windows laptop hosts prof-facing MP with MAVLink-over-network once the Pi 5 is online (default port `14550/udp`, standard MAVLink convention).

### Outcome — record install results

- Which machine each tool landed on (workstation / laptop / both).
- Whether each GUI launched cleanly; note any Mono warnings or missing-library errors.
- Version strings captured.
- No repo code changes expected; Board.md milestone row optional (this is setup state, not a code milestone).

If the only repo artifact is a Board.md update:

```bash
git add Board.md
git commit -m "docs: record MP + QGC install on Linux workstation per 23/04 meeting"
git push
```

**Outcome.** [To fill — target machines, version strings, launch-clean?, Board.md commit hash if one landed, any Mono-specific issues with MP.]

## Block C — P3 `tools/rate_probe.py`

Known-unknown from 22/04 perception-rate baseline work: `ros2 topic hz` in Jazzy has no `--qos-*` flag (only `ros2 topic echo` does). Probing a BEST_EFFORT publisher with the default RELIABLE subscription drops messages silently and reports a misleadingly low rate. Standalone Python script works around this.

### Design sketch

File: `tools/rate_probe.py` (new; create `tools/` if absent).

CLI:

```text
usage: rate_probe.py [-h] --topic TOPIC [--type MSG_TYPE]
                     [--reliability {reliable,best_effort}]
                     [--depth N] [--duration SECONDS]
```

Defaults: `--reliability best_effort`, `--depth 10`, `--duration 10`.

Behaviour:

- Start an rclpy node, subscribe to `--topic` with a `QoSProfile` matching the args.
- If `--type` is omitted, query the topic type via `ros2 topic type` (or use `rclpy`'s type introspection).
- Count received messages over `--duration` wall-clock seconds; print mean Hz + stdev + N.
- Exit cleanly on Ctrl-C, printing the partial stats.

### Package placement

- `tools/` at repo root, not under a colcon package (these are ad-hoc ops scripts, not ROS 2 entry points).
- No `package.xml` changes needed; direct `python3 tools/rate_probe.py ...` invocation.
- Document usage in `wiki/Common_Issues.md` or a new `wiki/Tools.md` if we expect more scripts.

### Test plan

Run against a known-rate topic to validate:

```bash
source ~/seal_ws/install/setup.bash
# Reference: 20 Hz BEST_EFFORT from lidar_perception
python3 tools/rate_probe.py --topic /perception/obstacle_info --reliability best_effort --duration 30
# Expected: ~20.0 Hz ± few ms stdev — matches 22/04 baseline
```

Cross-check against `ros2 topic hz` default (RELIABLE) on the same topic to confirm the fix:

```bash
ros2 topic hz /perception/obstacle_info
# Expected: much lower than 20 Hz, or hangs — demonstrates the bug
```

Commit (if landing):

```bash
git add tools/rate_probe.py wiki/...
git commit -m "tools: add rate_probe.py for QoS-aware publisher rate probing"
git push
```

**Outcome.** [To fill — rate measured on /perception/obstacle_info, match/mismatch with 22/04 baseline, any surprise during impl, commit hash.]

## Block D — Dashboard UX pass 2 (filler)

Planned-filler block; skip or truncate if Block A runs long. Three mission-control edge cases identified during 22/04 review but not addressed:

### Scenario 1 — Reset during Confirm window

Reproduce: Generate Waypoints → wait at Confirm dialog → click Reset instead of Confirm/Cancel.

Current behaviour: [check in sim]. Suspected issue: Reset may not clear the pending-waypoint state cleanly; next Generate attempt might see stale state.

Fix direction (if needed): ensure Reset cancels the pending Confirm and returns to INIT cleanly. May require a planner-side `confirm_pending` flag.

### Scenario 2 — Go Home while already home

Reproduce: start boat at home GPS → dashboard → Go Home.

Current behaviour: [check]. Expected: no-op or "already at home" toast, not a new mission attempt.

Fix direction: in `waypoint_planner` / CLI, compare current GPS to `home_position` within a tolerance (e.g., 3 m); if within, reject the Go Home command with a visible reason.

### Scenario 3 — Multi-click Joystick toggle mid-mission

Reproduce: start mission → rapidly toggle joystick override on/off/on during DRIVING state.

Current behaviour: [check]. Suspected issue: rapid state flip may confuse the controller or leave thrusters in an inconsistent command state.

Fix direction: debounce the joystick-toggle handler under the unified `debounceGroup` (800 ms, matches command debounce), OR gate the toggle on a minimum-interval guard inside the controller.

Commit message template per scenario:

```text
fix(dashboard): <scenario-specific fix>
```

**Outcome.** [To fill — which scenarios needed fixes, commits, any unexpected findings.]

## Block E — Wrap + diary fill-in

1. `git log --oneline -5` — sanity check the day's commits landed cleanly.
2. Pre-commit scan one more time — run the standing repo-wide sweep (expected: zero matches).
3. **Post-change doc audit** — scan `wiki/*`, `README.md`, `USER_MANUAL.md`, dashboard README, `Common_Issues.md`, `Design_Rationale.md`, `SASS.md` for stale claims touching today's changes (especially if P1 SASS behaviour is altered or rate_probe lands a new tool).
4. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
5. Add 24/04 milestone rows to Board.md's Timeline table.
6. Fill the Friday block's `[fill]` / `[待填]` Outcome placeholders in the external `Research_intern_IMT_NE/working_diary/Week7_20_04-24_04.md` (scaffold already in place from 22/04 evening restructure; today's work just replaces placeholders with real outcomes).
7. Commit the diary / Board updates:

   ```bash
   git add working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md Board.md
   git commit -m "docs: fill 24/04 working diary with day's outcomes"
   git push
   ```

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A diagnosis only | Pier/bank mechanism identified, fix deferred | 25/04 starts on the fix implementation |
| Block A diagnosis + patch | Fix landed | 25/04 moves to Block B or next priority |
| Block B | MP + QGC installed + smoke-launched | 25/04 picks up C or next priority |
| Block C | `rate_probe.py` in `tools/` | 25/04 starts on Block D or new priority |
| Block D | UX pass 2 scenarios addressed | 25/04 on supervisor-related work if available |
| Block E | Full day closed | 24/04 wrapped |

## Known unknowns surfaced during the day

Use this section to capture anything surprising during the day — file state drift, unexpected behaviour, migration caveats. Each entry: file:line or command + observation + fix or follow-up.

- [To fill]

## Next steps — concrete plan for 25/04

[To fill at end of day.]

### Actionable on 25/04

- **Carry-over from today:** whichever of Blocks A / B / C didn't land or needs follow-up.
- **If supervisor meeting scheduled:** Phase A parameter-set conversation → unblocks water-quality sensor scaffolding.

### Blocked / deferred (not on 25/04)

- **Phase A implementation** — blocked on supervisor.
- **Real no-regression test for `launch/remap.launch.yaml`** — migrates to Phase 5.1 bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware symptom.
- **Dashboard ↔ MP/QGC integration** (prof's long-term request from 23/04 meeting). Goal: dashboard issues waypoints + monitors live telemetry *through* MP/QGC as the autopilot front-end, not directly against ROS 2 nodes. Requires a MAVLink bridge on the Pi 5 (`mavros`, `mavsdk`, or similar) plus dashboard-side MAVLink emit/subscribe. Significant architecture work — fits the Phase 5.2+ window once basic bringup via MP/QGC against the Pi 5 is proven. Preserve today's dashboard UX (combobox, debounced controls, live map) as the prototype the MAVLink-bridged version has to match.
