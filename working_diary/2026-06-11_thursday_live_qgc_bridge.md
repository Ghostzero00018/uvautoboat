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
- **Block E local-only:** the first live acceptance target is QGC on the same Linux workstation via `127.0.0.1:14550`. Herelink/QGC over the network is a separate acceptance variant, not part of the first local v1 test.
- **No mission-folder storage in final path:** `.plan` export remains useful as a fallback / debug artifact, but the professor-requested flow should update QGC live.
- **No dashboard POST for v1 unless needed:** prefer a Python ROS-subscribing bridge over adding a new dashboard HTTP endpoint.
- **Keep command/write path separate:** the later Pi 5 / MAVProxy `14551` FCU-upload variant remains a future bench-safety task.
- **GCS noise boundary:** QGC startup `libva` and `speechd` messages were already classified as non-fatal warnings during the 24/04/2026 QGC install smoke launch; do not re-diagnose them unless QGC fails to show the bridge vehicle or mission.

## Block A - Repo pre-flight and source refresh

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If `git fetch --prune` fails, stop and report the network / auth error. Do not continue from stale remote state.
- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report both SHAs.

- [x] If the tree is dirty before work starts, identify changed files and do not overwrite user changes.
- [x] Re-read the current anchors:

  ```bash
  sed -n '180,190p' Board.md
  sed -n '316,323p' Board.md
  sed -n '184,200p' wiki/Roadmap.md
  sed -n '606,611p' wiki/Roadmap.md
  sed -n '1,260p' tools/qgc_plan_from_dashboard.py
  sed -n '893,923p' web_dashboard/autoboat/app.js
  sed -n '2207,2217p' web_dashboard/autoboat/app.js
  sed -n '2806,2870p' web_dashboard/autoboat/app.js
  sed -n '447,505p' plan/plan/waypoint_planner.py
  sed -n '864,887p' plan/plan/waypoint_planner.py
  sed -n '1428,1434p' plan/plan/waypoint_planner.py
  sed -n '1,140p' /home/ghostzero/Downloads/qgc_sender.py
  ```

- [x] Confirm whether implementation is approved for today. If not approved, stay at design / test-plan only.

**Outcome:** Block A completed on 11/06/2026. The branch guard was refreshed live before design claims: `git fetch --prune` completed successfully, `git log --oneline -5` began with `1480684`, `cf7580e`, `5c05c6d`, `7dd7a74`, and `f8844e8`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `1480684bb1870255e0b3cd67779dba3f0e982e90` for both refs. No pull was needed, no divergence was present, and no pre-existing user changes were present.

The required anchors were re-read before recording this design review: the 11/06 active diary, the 10/06 wrap diary, `tools/qgc_plan_from_dashboard.py`, `/home/ghostzero/Downloads/qgc_sender.py`, dashboard ranges around `/planning/waypoints`, Confirm, cached waypoints, and `localToGPS`, planner ranges around generate / confirm / config / waypoint publishing, plus the current `Board.md` and `wiki/Roadmap.md` rows around QGC, RealSense, MAVROS, YOLO, and blockers. Implementation is not approved yet today, so the work stays at requirements classification and design review only.

## Block B - Requirements and role check

- [x] Record the professor request exactly as provided by the user.
- [x] Classify the request:
  - live QGC visual bridge;
  - vehicle mission upload;
  - dashboard UI change;
  - ROS-only bridge;
  - package / dependency install;
  - bench-safety / real-hardware request.
- [x] Reconfirm the MAVLink role:
  - QGC is the ground station and normally requests missions from a vehicle.
  - The bridge should send a vehicle heartbeat, then answer QGC mission requests.
  - The professor reference script is protocol-relevant but not directionally correct as a direct push to QGC.
- [x] Record any fixes needed from the reference script before reuse:
  - dashboard payload shape differs from `points` / `path`;
  - local waypoints need Python conversion to GPS;
  - home-location command parameters need verification before any real upload use;
  - `MISSION_REQUEST_INT` must be handled in addition to `MISSION_REQUEST`.

**Outcome:** Professor request recorded exactly as provided by the user: "with simulation + dashboard + QGC running, after Generate then Confirm in the dashboard, QGC should receive the waypoint mission live. Python should do the conversion. Do not rely on writing a .plan file into the QGC mission folder for the final flow."

Classification:

- **Live QGC visual bridge:** yes. This is the main requested v1.
- **Vehicle mission upload:** no for today. Real FCU upload, arming, thruster, actuator, and Pi `14551` upload paths remain out of scope.
- **Dashboard UI change:** not required for v1 if the Python bridge can subscribe to existing ROS topics.
- **ROS-only bridge:** yes for the input side. Use `/planning/waypoints`, `/planning/config`, and planner state / command topics.
- **Package / dependency install:** possible only if `pymavlink` is missing from the selected environment; no install is approved yet.
- **Bench-safety / real-hardware request:** no. Keep this visual-only on the workstation / simulation side.

MAVLink role check: QGC is the ground station. The bridge should behave like a vehicle by sending a heartbeat to QGC, keeping the confirmed mission in memory, then answering QGC mission-list / mission-item requests. The professor reference script is protocol-relevant because it shows `pymavlink` mission messages, but it is directionally mismatched for QGC-as-ground-station: it waits for a heartbeat from the other side and tries to push a mission sequence, rather than presenting a vehicle-like mission surface that QGC can discover and query.

Reference-script fixes before reuse:

- The reference has a commented helper for `points` / `path`, while the active send path consumes preconverted `lat` / `lng` dictionaries. The current dashboard / ROS payload is `waypoints` with local `x` / `y` values plus origin from `/planning/config`.
- Local waypoints need the Python `local_to_gps()` conversion already present in `tools/qgc_plan_from_dashboard.py`.
- Home-location command parameters are not needed for visual-only v1 and must be re-verified before any real upload use.
- QGC may use `MISSION_REQUEST_INT`; the bridge should handle both `MISSION_REQUEST` and `MISSION_REQUEST_INT`.
- The final path must not copy the external file into the repo unless explicitly requested.

## Block C - Proposed v1 design before code

Target shape: a Python bridge that subscribes to existing ROS topics, converts local waypoints to GPS, and exposes a MAVLink vehicle-like mission surface for QGC.

Candidate inputs:

- `/planning/waypoints` (`std_msgs/String`) for the latest local waypoints.
- `/planning/config` (`std_msgs/String`) for `gps_ready`, `start_lat`, and `start_lon`.
- `/planning/mission_command` (`std_msgs/String`) or `/planning/mission_status` (`std_msgs/String`) to gate the live QGC update after Confirm / `READY`.

Candidate MAVLink side:

- Send heartbeat to same-machine QGC on UDP `127.0.0.1:14550` as a surface boat / ArduPilot-style vehicle, with a nonzero source system id and source component `MAV_COMP_ID_AUTOPILOT1` (`1`).
- Avoid an empty first mission pull: for the first professor demo, withhold the vehicle heartbeat until a confirmed mission exists. If repeated Generate / Confirm updates must be shown in the same QGC session, add a deliberate refresh mechanism before claiming support: reconnect with a new bridge system id, force a clean QGC reconnect, or require a manual Plan-view download action.
- Do not design around a default "receive waypoints" UI prompt. QGC creates a vehicle from an autopilot-component heartbeat, then initial connect requests parameters, mission, geofence, and rally data. Plan View should load the vehicle plan automatically when the view is empty or clean; a user choice is expected mainly when Plan View already has dirty / unsaved content or a manual download would overwrite existing content.
- Keep latest converted mission in memory.
- Answer QGC `MISSION_REQUEST_LIST`, `MISSION_REQUEST`, and `MISSION_REQUEST_INT`.
- Serve `MISSION_COUNT`, `MISSION_ITEM_INT`, and mission ACK responses as needed for QGC Plan view.
- Handle QGC initial-connect side traffic: respond safely to mission, fence, and rally mission-type requests (`MISSION_COUNT=0` for unsupported empty fence / rally plans), and either serve the smallest parameter response set needed for QGC to finish initial connect or document the expected parameter-timeout banner before acceptance.
- Do not send anything to the real FCU.

Acceptance criteria for v1:

- With simulation, rosbridge/dashboard, and QGC running, QGC auto-detects the bridge vehicle after the first confirmed mission is available.
- This first acceptance run is same-machine Linux workstation only: bridge / dashboard / ROS stack on the workstation, QGC on the workstation, and MAVLink UDP directed at `127.0.0.1:14550`.
- Generate waypoints in the dashboard.
- Confirm waypoints in the dashboard.
- QGC shows the confirmed route live without importing a `.plan` file and without writing to the mission folder.
- QGC Plan View loads the vehicle plan when the view is empty or clean. If Plan View is dirty / unsaved, or if a manual download overwrite case appears, record that branch explicitly instead of treating the prompt as the default success path.
- The mission item count matches `/planning/waypoints`.
- QGC home / route origin matches `/planning/config` `start_lat` / `start_lon`.
- Route geometry matches the dashboard lane spacing.
- Stopping the bridge affects only the simulated bridge vehicle / mission surface and does not stop the simulation stack. QGC may leave the bridge vehicle visible as communication-lost until manually disconnected.

Open design questions to answer before code:

- Should the bridge update QGC immediately on `/planning/waypoints`, or only after `confirm_waypoints` / `READY`?
- Should it live under `tools/` first, or become a ROS package node immediately?
- Should dependency setup use a local venv for `pymavlink`, or the existing ROS Python environment if available?
- How should the bridge make failures visible: terminal logs only, or a ROS status topic for the dashboard later?

**Outcome:** Block C design review completed on 11/06/2026. The recommended v1 is a standalone Python ROS 2 / MAVLink bridge, kept under `tools/` first, that subscribes to the planner topics and serves a vehicle-like mission surface to QGC without dashboard JavaScript, launch, package, YAML, or real-FCU changes.

Design decisions before code:

- **QGC update gate:** update QGC only after Confirm / `READY`, not immediately on `/planning/waypoints`. The planner generate service publishes waypoints and sets `WAITING_CONFIRM`; the dashboard Confirm button sends `confirm_waypoints`; the planner then sets `READY` and republishes mission status. The bridge can cache the latest generated waypoints, but it should only expose or replace the active mission after it observes confirmed / `READY` state. This matches the professor sequence and avoids showing unconfirmed previews in QGC.
- **Location:** start as `tools/qgc_live_mission_bridge.py` or similar, not a package node. That keeps the first implementation narrow and runnable without launch integration. Package / launch integration can wait until the live visual bridge passes.
- **Inputs:** subscribe to `/planning/waypoints` for local waypoint arrays, `/planning/config` for `gps_ready`, `start_lat`, `start_lon`, `state`, and `waypoint_count`, and `/planning/mission_status` as a second state signal. Listening to `/planning/mission_command` can help observe `confirm_waypoints`, but the safer acceptance gate is the planner-published `READY` state.
- **Conversion:** reuse the same `local_to_gps()` math and payload validation shape from `tools/qgc_plan_from_dashboard.py`; do not use the dashboard cache or `.plan` writer in the final live flow.
- **MAVLink side:** default to the local QGC visual path only, e.g. vehicle heartbeat plus mission-protocol responses to same-machine QGC over `127.0.0.1:14550`. Pin bridge identity explicitly: a nonzero source system id and source component `MAV_COMP_ID_AUTOPILOT1` (`1`), because QGC creates vehicles from autopilot-component heartbeats. Do not target the real MAVProxy / FCU upload path.
- **Refresh mechanism:** do not rely on passive mission changes after QGC has already downloaded an empty mission. V1 should withhold heartbeat until the first confirmed mission is ready, so QGC's initial connect sequence downloads the non-empty route. Repeated mission replacement in one QGC session is not accepted until Block D adds and tests an explicit refresh mechanism such as a clean reconnect / new bridge system id or a documented manual Plan-view download step.
- **QGC UI expectation:** do not expect a default "receive waypoints" prompt. In QGC v4.4.3, Plan View should load from the active vehicle automatically when it is empty or clean; a prompt is mainly a dirty / unsaved Plan View or manual overwrite branch.
- **Network variant:** Herelink-hosted QGC is not the Block E target. If QGC runs on Herelink while the dashboard / ROS bridge runs on the Linux workstation, add a separate network acceptance block: send MAVLink UDP to the Herelink/QGC link rather than `127.0.0.1`, check bridge and vehicle system-id conflicts, verify firewall / routing, and isolate the visual bridge from any real FCU link.
- **Initial-connect protocol surface:** implement or deliberately account for QGC's initial parameter, mission, geofence, and rally-point requests. At minimum, mission download must return the confirmed route, unsupported empty fence / rally requests must get `MISSION_COUNT=0`, and parameter handling must either be minimally served or the timeout banner must be documented as expected before the live demo.
- **Failure visibility:** terminal logs are enough for v1. A ROS status topic for dashboard surfacing can be deferred unless live testing shows the bridge state is too opaque.
- **Dependency path:** first verify whether the ROS-sourced workstation Python can already import both `rclpy` and `pymavlink`. If not, ask before installing. Safest dependency plan is an isolated local venv with system site packages, e.g. `~/venvs/uvautoboat-qgc-bridge`, so ROS Python modules remain visible while `pymavlink` stays out of package manifests. No dependency installation is approved yet.

Test strategy if Block D is approved:

- Red-green unit coverage where practical: payload unwrap / local waypoint parsing, local-to-GPS conversion reuse, mission-item construction, and confirm / `READY` gating.
- Protocol-level tests without QGC where practical: feed fake MAVLink request messages into a small handler and verify heartbeat identity, `MISSION_COUNT` / `MISSION_ITEM_INT` sequencing, `MISSION_REQUEST_INT`, legacy `MISSION_REQUEST`, empty fence / rally counts, and the chosen first-confirm refresh behaviour.
- Live QGC verification stays Block E only after code exists and the user approves acceptance testing.

Implementation is still gated. Stop here before Block D.

## Block D - Implementation gate

Start only after the user explicitly approves code/config edits.

- [x] Add the smallest testable unit first:
  - conversion reuse from `tools/qgc_plan_from_dashboard.py`;
  - mission item construction from local waypoint payload;
  - confirm/READY gating logic if implemented outside ROS callbacks.
- [x] Implement the bridge with the smallest surface that satisfies v1.
- [x] Keep the professor reference file external unless the user explicitly asks to import or copy it into the repo.
- [x] Avoid dashboard JavaScript edits unless the ROS-subscribing bridge cannot meet the professor's workflow.
- [x] Avoid launch/package integration until the standalone bridge works.
- [x] Keep the later Block E test local to the workstation via `127.0.0.1:14550`; do not fold Herelink/QGC network behavior into the first implementation acceptance gate.

**Outcome:** Block D started after explicit approval on 11/06/2026 and stayed inside the approved v1 implementation boundary.

Files added:

- `tools/qgc_live_mission_bridge.py`
- `tools/test_qgc_live_mission_bridge.py`

Implementation summary:

- Added a standalone ROS 2 / MAVLink tool under `tools/`, with no dashboard JavaScript, launch, package, YAML, service, or dependency-manifest edits.
- Reused the same local-to-GPS conversion path from `tools/qgc_plan_from_dashboard.py`.
- Added helper coverage for waypoint payload parsing, GPS-origin validation, mission item construction, Confirm / `READY` gating, and empty fence / rally mission counts.
- The bridge subscribes to `/planning/waypoints`, `/planning/config`, and `/planning/mission_status`; it caches generated waypoints but only exposes an active QGC visual mission after planner state is `READY`.
- The MAVLink side defaults to `udpout:127.0.0.1:14550`, source system id `42`, and source component `MAV_COMP_ID_AUTOPILOT1` (`1`). It withholds heartbeat until a confirmed mission exists, answers `MISSION_REQUEST_LIST`, `MISSION_REQUEST`, and `MISSION_REQUEST_INT`, sends empty counts for unsupported fence / rally mission types, and serves a minimal parameter set for QGC initial connect.
- Pre-Block-E review hardening: repeated `READY` status updates now use a stable mission signature and return/log only when the active mission actually changes; `MISSION_CLEAR_ALL` is rejected as unsupported for v1 and leaves the dashboard-owned fake mission intact.
- The professor reference file stayed external and was not copied into the repo.
- Runtime dependency status: `rclpy` imports in the current environment, but `pymavlink` is missing. The script now exits clearly with `error: pymavlink is required for live QGC bridge runtime; install it in the selected bridge environment before Block E`. No install was attempted.

## Block E - Live acceptance test plan

Run only after implementation exists and the user approves the live test.

Preconditions to state before commands:

- Linux workstation, repo at `/home/ghostzero/seal_ws/src/uvautoboat`.
- Simulation stack running and publishing `/planning/config`, `/planning/waypoints`, and `/planning/mission_status`.
- Dashboard open from the same stack and connected through rosbridge.
- QGC running on the same Linux workstation and listening through the local UDP path `127.0.0.1:14550`.
- `pymavlink` availability verified in the environment chosen for the bridge.
- No real FCU / Pi 5 upload path connected to this test.
- Herelink/QGC network testing is not part of this block.

Expected live sequence:

1. Start QGC and the bridge in separate idle terminals; the bridge should log that it is waiting for a confirmed mission and should not present a QGC vehicle yet if using the delayed-heartbeat v1 path.
2. Start or confirm the simulation/dashboard whole stack.
3. In the dashboard, click Generate and wait for waypoint preview.
4. Click Confirm.
5. In QGC, verify live vehicle / mission display:
   - route appears without `.plan` import;
   - Plan View loads the vehicle mission automatically if the view is empty or clean;
   - any dirty / unsaved Plan View or manual download overwrite prompt is recorded as that specific branch, not as the default success path;
   - vehicle appears only after Confirm if delayed heartbeat is selected;
   - waypoint count matches `/planning/waypoints`;
   - home/origin matches `/planning/config`;
   - geometry matches dashboard route.

Separate Herelink/QGC network acceptance variant, not for the first Block E run:

- QGC on Herelink and the dashboard / ROS bridge on the Linux workstation requires MAVLink UDP over the network to the Herelink/QGC link, not `127.0.0.1`.
- Before attempting that variant, verify routing / firewall, bridge source system id versus any real vehicle id, and isolation from any real FCU link.
- Record it as a separate acceptance result so the local workstation v1 cannot be mistaken for a Herelink network pass.

**Outcome:** Not started on 11/06/2026. The bridge implementation now exists, but live QGC acceptance still requires explicit Block E approval plus `pymavlink` in the selected bridge environment. No QGC live acceptance run was attempted, no `.plan` import was used, and no real FCU / Pi 5 upload path was connected.

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

**Outcome:** Interim wrap after Block D implementation on 11/06/2026. The repo was refreshed and clean at pushed commit `35768f4`, the professor request was recorded and classified, the v1 bridge design was reviewed, and the standalone bridge implementation was added under `tools/`. Post-review corrections remain preserved around QGC's initial mission download, bridge heartbeat identity, initial-connect side requests, Plan View prompt expectations, and the boundary between same-machine local acceptance and a later Herelink/QGC network variant. No live QGC acceptance has started. `Board.md` and `wiki/Roadmap.md` were not updated because live QGC visual bridge acceptance has not passed.

Checks run after Block D code:

- `python3 tools/test_qgc_live_mission_bridge.py` -> 8 tests passed.
- `python3 tools/test_qgc_plan_from_dashboard.py` -> 5 tests passed.
- `python3 -m unittest discover tools -p 'test_qgc_*.py'` -> 13 tests passed.
- `python3 -m py_compile tools/qgc_live_mission_bridge.py tools/test_qgc_live_mission_bridge.py tools/qgc_plan_from_dashboard.py tools/test_qgc_plan_from_dashboard.py` -> passed.
- `python3 -m flake8 --config .linters/ament_flake8.ini tools/qgc_live_mission_bridge.py tools/test_qgc_live_mission_bridge.py` -> passed.
- `python3 tools/qgc_live_mission_bridge.py --help` -> help rendered.
- `python3 tools/qgc_live_mission_bridge.py` -> blocked as expected because `pymavlink` is not installed in the current environment.
- `git diff --check` -> clean.
- Line-length scan for the new bridge/test files -> no lines over 99 chars.

## Next steps

Next step is Block E only after explicit approval: install or select an environment with `pymavlink`, keep the run local to the workstation via `127.0.0.1:14550`, start QGC and the bridge in separate idle terminals, then test Generate -> Confirm -> QGC mission display. Keep the run visual-only and keep the real FCU upload path out of scope. Treat Herelink/QGC as a later network acceptance variant with separate system-id, firewall / routing, and FCU-isolation checks.
