# 2026-06-05 - Friday: dashboard and simulation-stack real-topic integration plan

## Day overview

Continuing from Thu 04/06/2026 ([`2026-06-04`](2026-06-04_thursday_video_framerate_and_real_topic_inventory.md)).

Primary work for Fri 05/06/2026 is the second professor follow-up from the 03/06 meeting: start integrating real low-level-controller ROS 2 topics into the existing web dashboard and the previously used full simulation stack. The first safe step is inventory and mapping, then a narrow implementation proposal. Python, YAML, and JavaScript edits need explicit approval before they happen.

Current architecture anchors:

- Existing dashboard data path: browser -> `rosbridge` (`9090`) -> ROS 2 topics; camera panel -> `web_video_server` (`8080`); HTTP dashboard -> `serve_dashboard.py` (`8002`).
- Existing dashboard subscriptions include `/wamv/sensors/gps/gps/fix`, `/wamv/thrusters/left/thrust`, and `/wamv/thrusters/right/thrust`.
- Existing simulation stack is launched by `one_click_launch_all/launch_autoboat_complete.sh` and must keep working.
- `launch/remap.launch.yaml` already documents a two-layer Phase 5 transition: VRX `/wamv/*` <-> neutral `/sensors` / `/actuators`, then a future real-hardware bridge.
- MAVROS / ROS telemetry on `/dev/ttyAMA0:57600` is proven through MAVProxy UDP fanout with `/mavros/state connected: true`; Friday still needs a fresh combined-load re-capture while the camera node is running before dashboard integration treats the combined path as validated.
- Prof reports the Pi 5 ROS domain is now `ROS_DOMAIN_ID=12`; confirm the value in every Pi / workstation terminal before interpreting graph discovery. Any host running `rosbridge`, `web_video_server`, or dashboard-side ROS checks must use the same domain as the Pi, or it will see an empty graph with no explicit error.

## Boundaries

- **In scope:** topic inventory, topic mapping, dashboard subscription audit, simulation-stack preservation plan, implementation proposal, verification recipe.
- **Out of scope without explicit approval:** editing `web_dashboard/autoboat/app.js`, `index.html`, Python nodes, launch YAML, or Pi-side services.
- **Simulation boundary:** preserve the default VRX / dashboard path. Real-topic support must be flag-gated or mapped so the old full simulation stack still works.
- **Telemetry boundary:** do not build dashboard claims on MAVProxy alone. Dashboard telemetry needs ROS 2 topics, preferably from MAVROS with `/mavros/state connected: true`.

## Block A - Repo and Thursday handoff pre-flight

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [ ] Re-read Thursday outcome and current integration anchors:

  ```bash
  sed -n '1,283p' working_diary/2026-06-04_thursday_video_framerate_and_real_topic_inventory.md
  sed -n '170,200p' web_dashboard/autoboat/README_autoboat_dashboard.md
  sed -n '517,840p' web_dashboard/autoboat/app.js
  sed -n '1,140p' launch/remap.launch.yaml
  sed -n '193,205p' wiki/Pi5_Bringup_Smoke_Test.md
  ```

**Outcome:** [To fill - repo state, Thursday result, integration starting point.]

## Block B - Real ROS 2 topic inventory

Run these from a fresh Pi terminal using the known-good topology first: MAVProxy is the sole serial owner on `/dev/ttyAMA0:57600`, MAVROS consumes `udp://127.0.0.1:14550@`, and optional direct-MAVLink scripts use `14551` only. Confirm `ROS_DOMAIN_ID=12` before interpreting the graph. Capture the MAVROS inventory with the camera node off first, then attempt the combined camera + MAVROS inventory; the 04/06 combined run was power-limited and did not produce a fresh `/mavros/state` echo pass.

- [ ] Confirm MAVROS state:

  ```bash
  source /opt/ros/jazzy/setup.bash
  echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}"
  timeout 10 ros2 topic echo --once /mavros/state
  ```

- [ ] Capture the real topic list with types:

  ```bash
  source /opt/ros/jazzy/setup.bash
  echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}"
  ros2 topic list -t | sort
  ```

  The 04/06 combined capture did not record `ROS_DOMAIN_ID`, so whether domain `12` isolates the earlier TurtleBot4 / Create3 / Gazebo / OAK-D graph noise is unverified. Confirm with the echo above and a fresh topic list, then still filter the inventory by source before mapping.

- [ ] Capture minimal telemetry samples if connected:

  ```bash
  source /opt/ros/jazzy/setup.bash
  timeout 10 ros2 topic echo --once /mavros/global_position/raw/fix --qos-profile sensor_data
  timeout 10 ros2 topic echo --once /mavros/global_position/global --qos-profile sensor_data
  timeout 10 ros2 topic echo --once /mavros/imu/data --qos-profile sensor_data
  timeout 10 ros2 topic echo --once /mavros/battery --qos-profile sensor_data
  timeout 10 ros2 topic echo --once /mavros/rc/in --qos-profile sensor_data
  ```

  Use `/mavros/global_position/raw/fix` as the GPS sample that can publish the no-fix state (`status: -1`). `/mavros/global_position/global` may remain empty until a valid GPS fix is available. A few "message was lost" notices before a final sample do not fail the run; an empty timeout should be recorded as topic/config state.

- [ ] Capture image topics if camera integration is in scope today:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 topic list -t | grep -E 'Image|CompressedImage|camera|image' || true
  ```

**Outcome:** [To fill - real topic list and connected/not-connected verdict.]

## Block C - Existing dashboard and simulation-stack inventory

- [ ] Confirm current dashboard subscriptions / publishers in `app.js`:
  - GPS: `/wamv/sensors/gps/gps/fix`;
  - thrusters: `/wamv/thrusters/left/thrust`, `/wamv/thrusters/right/thrust`;
  - mission state: `/planning/*`;
  - config: `/planning/config`, `/planning/set_config`;
  - camera default: `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`, with auto-discovery through `/rosapi/topics_for_type`.
- [ ] Confirm current full simulation stack still starts from the documented launcher:

  ```bash
  bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
  ```

  If this command is only planned and not run today, label it as untested in the outcome.

- [ ] Confirm `launch/remap.launch.yaml` still matches the intended transition model:
  - Layer A: sim `/wamv/*` to neutral `/sensors/*`;
  - Layer B: future real-hardware bridge;
  - `use_real_hardware:=true` currently points to a non-existing `bridge` package, so do not flip it during normal simulation.

**Outcome:** [To fill - current dashboard/sim topic contract.]

## Block D - Mapping table

Fill this table before proposing edits.

| Function | Existing sim/dashboard topic | Candidate real topic | Type | Integration direction | Status |
|----------|------------------------------|----------------------|------|-----------------------|--------|
| GPS position | `/wamv/sensors/gps/gps/fix` | `/mavros/global_position/global` or `/mavros/global_position/raw/fix` | `sensor_msgs/NavSatFix` | Real -> dashboard / sim pose | [To fill] |
| IMU | `/wamv/sensors/imu/imu/data` | `/mavros/imu/data` | `sensor_msgs/Imu` | Real -> sim / diagnostics | [To fill] |
| Camera image | `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | `/camera/camera/color/image_raw` or confirmed Herelink-derived ROS topic | `sensor_msgs/Image` | Real -> dashboard camera | [To fill] |
| Battery | none in current dashboard | `/mavros/battery` | `sensor_msgs/BatteryState` | Real -> future dashboard panel | [To fill] |
| RC / manual state | none in current dashboard | `/mavros/rc/in` | `mavros_msgs/msg/RCIn` | Real -> diagnostics | [To fill] |
| Thruster command | `/wamv/thrusters/*/thrust` | MAVROS setpoint / actuator path TBD | TBD | dashboard / planner -> low-level | [To fill] |

Interpretation rules:

- If a real topic is not publishing, keep it as a candidate only.
- If types differ, record the adapter needed; do not pretend a relay is enough.
- If command direction is uncertain, keep it diagnostics-only until the low-level command path is confirmed.

**Outcome:** [To fill - topic mapping and open adapters.]

## Block E - Implementation proposal, no edits yet

Draft the smallest safe implementation path. Do not edit code/config until explicit approval lands.

Candidate shape:

1. **No-regression baseline:** keep the one-click simulation launcher and existing `/wamv/*` dashboard path unchanged.
2. **Camera quick win:** use dashboard camera topic auto-discovery / manual topic entry to point the camera panel at `/camera/camera/color/image_raw` if `web_video_server` can see it. This may need no code change. On 04/06 the RealSense color topic published as `RELIABLE` / `TRANSIENT_LOCAL`; confirm the actual QoS again before blaming an empty viewer.
3. **Telemetry bridge path:** prefer a launch-level topic adapter from real MAVROS topics to the dashboard's existing expected topics first, if message types match. If the adapter becomes non-trivial, then add a narrow bridge node only after approval.
4. **Dashboard topic configurability:** if launch-level mapping is insufficient, propose a dashboard-side topic profile selector (`simulation` vs `real`) in `app.js` / `index.html`; this is JavaScript/HTML work and needs approval.
5. **Simulation stack preservation:** run the full simulation launcher after every integration change to prove `/wamv/*` still works.

**Outcome:** [To fill - recommended option and approval needed.]

## Block F - Verification recipe for any approved implementation

Keep this as the test plan if code/config edits are approved later.

1. Simulation baseline from a new Linux workstation terminal:

   ```bash
   cd /home/ghostzero/seal_ws/src/uvautoboat
   bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
   ```

   Browser check: open `http://localhost:8002`, confirm dashboard connection, GPS, mission status, camera default, and no regression in the previously used full simulation stack.

2. Real-topic read-only check from a Pi or workstation terminal with matching ROS environment:

   ```bash
   source /opt/ros/jazzy/setup.bash
   echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}"
   ros2 topic list -t | grep -E 'mavros|camera|sensors|wamv|planning|control' || true
   timeout 10 ros2 topic echo --once /mavros/state
   ```

   Use the Block B timeout + `--qos-profile sensor_data` form for best-effort telemetry topics. Do not interpret a bare empty `echo --once` as a telemetry failure before checking QoS and timeout behaviour.

3. Dashboard real-topic check:

   ```bash
   ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0
   ros2 run web_video_server web_video_server
   cd /home/ghostzero/seal_ws/src/uvautoboat/web_dashboard/autoboat
   python3 serve_dashboard.py 8002
   ```

   Browser check: open `http://localhost:8002`, confirm camera topic selection and any real telemetry fields explicitly implemented.

4. Post-change doc audit if implementation changes user-visible behavior:

   ```bash
   rg -n "wamv|mavros|camera|dashboard|web_video_server|rosbridge|remap" README.md USER_MANUAL.md wiki web_dashboard/autoboat/README_autoboat_dashboard.md
   ```

**Outcome:** [To fill - verification status if implementation starts.]

## Block G - Day wrap

- [ ] Fill all outcomes above.
- [ ] If no code/config edits occurred, close as diary-only planning.
- [ ] If code/config edits occurred after explicit approval, run the verification recipe above and the standard pre-commit visibility sweep.
- [ ] Set next startup hint.
- [ ] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  ```

**Outcome:** [To fill - wrap state, implementation status, next startup hint.]

## Next steps

Next startup: continue from the mapping table. If the user approves code/config edits, implement the smallest flag-gated path that preserves the existing full simulation stack first, then add real-topic support.
