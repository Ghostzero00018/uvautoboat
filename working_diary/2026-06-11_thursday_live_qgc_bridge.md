# 2026-06-11 - Thursday: live QGC waypoint bridge planning

## Day overview

Continuing from Wed 10/06/2026 ([`2026-06-10`](2026-06-10_wednesday_yolo_professor_check.md)).

Primary work for Thu 11/06/2026:

- **Main task:** move the offline QGC Plan-view import into a live simulation-side bridge.
- **Professor request:** the conversion should be done by Python, and the final usage should be: simulation + dashboard + QGC running; user clicks Generate, then Confirm; QGC receives the waypoint mission live without writing a `.plan` file into the mission folder.
- **Reference file:** inspect the professor-provided `/home/ghostzero/Downloads/qgc_sender.py` before implementation claims.

Current state to preserve:

- 10/06 proved the offline dashboard cache -> QGC `.plan` path: `tools/qgc_plan_from_dashboard.py` converted 5 cached dashboard waypoints into 5 QGC mission items, home at `-33.722768660802124`, `150.67399109012482`, and geometry matching the dashboard route.
- That result is visual import only. It is not a MAVLink mission upload, not a vehicle command path, and not real FCU validation.
- The professor's reference script uses `pymavlink`, but it pushes mission messages in the wrong role for QGC-as-ground-station. Tomorrow's target is a simulator-side MAVLink visual bridge that behaves like a surface-boat vehicle for QGC.
- Existing dashboard / planner data flow already provides the needed data:
  - `/planning/waypoints` publishes local waypoints.
  - `/planning/config` publishes `gps_ready`, `start_lat`, and `start_lon`.
  - `/planning/mission_command` receives `confirm_waypoints`.
  - `/planning/mission_status` reports planner state.
- Final v1 should avoid dashboard JavaScript changes if the existing ROS topics are sufficient.

## Boundaries

- **Code/config edits require explicit approval:** Python, JavaScript, launch, YAML, package, service, and dependency changes are not started until the user explicitly approves implementation.
- **Simulator/QGC visual-only first:** no FCU upload, no real autopilot mission transfer, no arming, no thruster, and no actuator path.
- **No mission-folder storage in final path:** `.plan` export remains useful as a fallback / debug artifact, but the professor-requested flow should update QGC live.
- **No dashboard POST for v1 unless needed:** prefer a Python ROS-subscribing bridge over adding a new dashboard HTTP endpoint.
- **Keep command/write path separate:** the later Pi 5 / MAVProxy `14551` FCU-upload variant remains a future bench-safety task.
- **GCS noise boundary:** QGC startup `libva` and `speechd` messages were already classified as cosmetic on 10/06; do not re-diagnose them unless QGC fails to show the bridge vehicle or mission.

## Block A - Repo pre-flight and source refresh

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If `git fetch --prune` fails, stop and report the network / auth error. Do not continue from stale remote state.
- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report both SHAs.

- [ ] If the tree is dirty before work starts, identify changed files and do not overwrite user changes.
- [ ] Re-read the current anchors:

  ```bash
  sed -n '180,190p' Board.md
  sed -n '316,323p' Board.md
  sed -n '184,200p' wiki/Roadmap.md
  sed -n '606,611p' wiki/Roadmap.md
  sed -n '1,260p' tools/qgc_plan_from_dashboard.py
  sed -n '893,923p' web_dashboard/autoboat/app.js
  sed -n '2207,2217p' web_dashboard/autoboat/app.js
  sed -n '2806,2868p' web_dashboard/autoboat/app.js
  sed -n '447,505p' plan/plan/waypoint_planner.py
  sed -n '864,887p' plan/plan/waypoint_planner.py
  sed -n '1428,1434p' plan/plan/waypoint_planner.py
  sed -n '1,140p' /home/ghostzero/Downloads/qgc_sender.py
  ```

- [ ] Confirm whether implementation is approved for today. If not approved, stay at design / test-plan only.

**Outcome:** [To fill during 11/06 session.]

## Block B - Requirements and role check

- [ ] Record the professor request exactly as provided by the user.
- [ ] Classify the request:
  - live QGC visual bridge;
  - vehicle mission upload;
  - dashboard UI change;
  - ROS-only bridge;
  - package / dependency install;
  - bench-safety / real-hardware request.
- [ ] Reconfirm the MAVLink role:
  - QGC is the ground station and normally requests missions from a vehicle.
  - The bridge should send a vehicle heartbeat, then answer QGC mission requests.
  - The professor reference script is protocol-relevant but not directionally correct as a direct push to QGC.
- [ ] Record any fixes needed from the reference script before reuse:
  - dashboard payload shape differs from `points` / `path`;
  - local waypoints need Python conversion to GPS;
  - home-location command parameters need verification before any real upload use;
  - `MISSION_REQUEST_INT` must be handled in addition to `MISSION_REQUEST`.

**Outcome:** [To fill during 11/06 session.]

## Block C - Proposed v1 design before code

Target shape: a Python bridge that subscribes to existing ROS topics, converts local waypoints to GPS, and exposes a MAVLink vehicle-like mission surface for QGC.

Candidate inputs:

- `/planning/waypoints` (`std_msgs/String`) for the latest local waypoints.
- `/planning/config` (`std_msgs/String`) for `gps_ready`, `start_lat`, and `start_lon`.
- `/planning/mission_command` (`std_msgs/String`) or `/planning/mission_status` (`std_msgs/String`) to gate the live QGC update after Confirm / `READY`.

Candidate MAVLink side:

- Send 1 Hz heartbeat to QGC on UDP `127.0.0.1:14550` as a surface boat / ArduPilot-style vehicle.
- Keep latest converted mission in memory.
- Answer QGC `MISSION_REQUEST_LIST`, `MISSION_REQUEST`, and `MISSION_REQUEST_INT`.
- Serve `MISSION_COUNT`, `MISSION_ITEM_INT`, and mission ACK responses as needed for QGC Plan view.
- Do not send anything to the real FCU.

Acceptance criteria for v1:

- With simulation, rosbridge/dashboard, and QGC running, QGC auto-detects the bridge vehicle.
- Generate waypoints in the dashboard.
- Confirm waypoints in the dashboard.
- QGC shows the confirmed route live without importing a `.plan` file and without writing to the mission folder.
- The mission item count matches `/planning/waypoints`.
- QGC home / route origin matches `/planning/config` `start_lat` / `start_lon`.
- Route geometry matches the dashboard lane spacing.
- Stopping the bridge removes only the simulated bridge vehicle / mission surface, not the simulation stack.

Open design questions to answer before code:

- Should the bridge update QGC immediately on `/planning/waypoints`, or only after `confirm_waypoints` / `READY`?
- Should it live under `tools/` first, or become a ROS package node immediately?
- Should dependency setup use a local venv for `pymavlink`, or the existing ROS Python environment if available?
- How should the bridge make failures visible: terminal logs only, or a ROS status topic for the dashboard later?

**Outcome:** [To fill during 11/06 session.]

## Block D - Implementation gate

Start only after the user explicitly approves code/config edits.

- [ ] Add the smallest testable unit first:
  - conversion reuse from `tools/qgc_plan_from_dashboard.py`;
  - mission item construction from local waypoint payload;
  - confirm/READY gating logic if implemented outside ROS callbacks.
- [ ] Implement the bridge with the smallest surface that satisfies v1.
- [ ] Keep the professor reference file external unless the user explicitly asks to import or copy it into the repo.
- [ ] Avoid dashboard JavaScript edits unless the ROS-subscribing bridge cannot meet the professor's workflow.
- [ ] Avoid launch/package integration until the standalone bridge works.

**Outcome:** [To fill during 11/06 session.]

## Block E - Live acceptance test plan

Run only after implementation exists and the user approves the live test.

Preconditions to state before commands:

- Linux workstation, repo at `/home/ghostzero/seal_ws/src/uvautoboat`.
- Simulation stack running and publishing `/planning/config`, `/planning/waypoints`, and `/planning/mission_status`.
- Dashboard open from the same stack and connected through rosbridge.
- QGC running on the workstation.
- `pymavlink` availability verified in the environment chosen for the bridge.
- No real FCU / Pi 5 upload path connected to this test.

Expected live sequence:

1. Start QGC and the bridge in separate idle terminals.
2. Start or confirm the simulation/dashboard whole stack.
3. In the dashboard, click Generate and wait for waypoint preview.
4. Click Confirm.
5. In QGC, verify live vehicle / mission display:
   - route appears without `.plan` import;
   - waypoint count matches `/planning/waypoints`;
   - home/origin matches `/planning/config`;
   - geometry matches dashboard route.

**Outcome:** [To fill during 11/06 session.]

## Block F - Wrap and docs

- [ ] Record whether the day stayed design-only or implemented the bridge.
- [ ] If implemented, record exact files changed and test results.
- [ ] If live QGC acceptance passes, update `Board.md` and `wiki/Roadmap.md` narrowly:
  - live QGC visual bridge accepted;
  - still no real FCU upload;
  - command/write path remains unvalidated.
- [ ] If it does not pass, record the failing protocol step and the next hypothesis.
- [ ] Run checks after any edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To[ ]fill|<{7}|={7}|>{7}" working_diary/2026-06-11_thursday_live_qgc_bridge.md
  ```

  Also run the standard public-repo visibility sweep from the terminal before commit.

**Outcome:** [To fill during 11/06 session.]

## Next steps

Start 11/06 by confirming whether code/config implementation is approved. If approved, build the ROS-subscribing MAVLink visual bridge first and keep the real FCU upload path out of scope. If not approved, use the day for design review, protocol trace, and a paste-ready test plan only.
