# 2026-06-05 - Friday: dashboard and simulation-stack real-topic integration plan

## Day overview

Continuing from Thu 04/06/2026 ([`2026-06-04`](2026-06-04_thursday_video_framerate_and_real_topic_inventory.md)).

Primary work for Fri 05/06/2026 is the second professor follow-up from the 03/06 meeting: start integrating real low-level-controller ROS 2 topics into the existing web dashboard and the previously used full simulation stack. The first safe step is inventory and mapping, then a narrow implementation proposal. Plan-change addendum after the first diary commit: today's live priority is MAVROS + RealSense camera evidence first. If those checks are stable, use remaining time for a bounded Pi 5 light-YOLO install feasibility check only. Python, YAML, and JavaScript edits need explicit approval before they happen.

Current architecture anchors:

- Existing dashboard data path: browser -> `rosbridge` (`9090`) -> ROS 2 topics; camera panel -> `web_video_server` (`8080`); HTTP dashboard -> `serve_dashboard.py` (`8002`).
- Existing dashboard subscriptions include `/wamv/sensors/gps/gps/fix`, `/wamv/thrusters/left/thrust`, and `/wamv/thrusters/right/thrust`.
- Existing simulation stack is launched by `one_click_launch_all/launch_autoboat_complete.sh` and must keep working.
- `launch/remap.launch.yaml` already documents a two-layer Phase 5 transition: VRX `/wamv/*` <-> neutral `/sensors` / `/actuators`, then a future real-hardware bridge.
- MAVROS / ROS telemetry on `/dev/ttyAMA0:57600` is proven through MAVProxy UDP fanout with `/mavros/state connected: true`; Friday still needs a fresh combined-load re-capture while the camera node is running before dashboard integration treats the combined path as validated.
- Prof reports the Pi 5 ROS domain is now `ROS_DOMAIN_ID=12`; confirm the value in every Pi / workstation terminal before interpreting graph discovery. Any host running `rosbridge`, `web_video_server`, or dashboard-side ROS checks must use the same domain as the Pi, or it will see an empty graph with no explicit error.

## Boundaries

- **In scope:** topic inventory, topic mapping, dashboard subscription audit, simulation-stack preservation plan, implementation proposal, verification recipe, and isolated Pi 5 light-YOLO install feasibility if MAVROS / camera time allows.
- **Out of scope without explicit approval:** editing `web_dashboard/autoboat/app.js`, `index.html`, Python nodes, launch YAML, or Pi-side services.
- **Simulation boundary:** preserve the default VRX / dashboard path. Real-topic support must be flag-gated or mapped so the old full simulation stack still works.
- **Telemetry boundary:** do not build dashboard claims on MAVProxy alone. Dashboard telemetry needs ROS 2 topics, preferably from MAVROS with `/mavros/state connected: true`.
- **YOLO boundary:** install exploration is local to the Pi 5 user environment and must not change repo code, ROS launch files, Pi services, or the camera / MAVROS runtime contract today.

## Block A - Repo and Thursday handoff pre-flight

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [x] Re-read Thursday outcome and current integration anchors:

  ```bash
  sed -n '1,283p' working_diary/2026-06-04_thursday_video_framerate_and_real_topic_inventory.md
  sed -n '170,200p' web_dashboard/autoboat/README_autoboat_dashboard.md
  sed -n '517,840p' web_dashboard/autoboat/app.js
  sed -n '1,140p' launch/remap.launch.yaml
  sed -n '193,205p' wiki/Pi5_Bringup_Smoke_Test.md
  ```

**Outcome:** Block A ran on the Linux workstation on 05/06/2026. `git fetch --prune` completed. `git log --oneline -5` began with `0bf2676`, `7a54404`, `85a91d1`, `dc508fd`, and `21643ad`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `0bf26767e68c64e2d18838250c473801052db865` for both refs. No pull was needed, and no pre-existing user changes were present.

Thursday's diary and the live status rows in `Board.md` / `wiki/Roadmap.md` were re-read before mapping. Current verified state remains: MAVProxy owns `/dev/ttyAMA0:57600`; MAVROS consumes `udp://127.0.0.1:14550@`; optional direct-MAVLink inspection uses `14551`; `/mavros/state connected: true` passed on 04/06/2026 in a camera-off topology; first ROS samples were captured from IMU, raw GPS no-fix, battery, and RC; command / write paths remain unvalidated after request/response timeouts; the 04/06/2026 camera + MAVROS run was power-limited and did not produce a fresh `/mavros/state` echo pass.

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

**Outcome:** No fresh 05/06/2026 Pi runtime capture was available in this terminal session, so the clean inventory below is bounded to verified 04/06/2026 diary evidence plus today's source audit. It is suitable for dashboard / simulation planning, not for closing the combined camera + MAVROS validation gate.

Clean real-topic inventory:

| Source | Topic / endpoint | Type / role | 04/06 evidence | 05/06 mapping status |
|--------|------------------|-------------|----------------|----------------------|
| MAVProxy serial input | `/dev/ttyAMA0:57600` | MAVLink serial endpoint | Proven ArduPilot heartbeat / status source | Keep MAVProxy as sole serial owner |
| MAVProxy fanout | `udpout:127.0.0.1:14550` | MAVLink UDP leg for MAVROS | Used by MAVROS pass | Reserved for MAVROS |
| MAVProxy fanout | `udpout:127.0.0.1:14551` | MAVLink UDP leg for direct scripts | Intended optional inspection leg | Do not use for MAVROS |
| MAVROS state | `/mavros/state` | `mavros_msgs/msg/State` | `connected: true` in camera-off run | Gate topic for any real telemetry session |
| MAVROS GPS raw | `/mavros/global_position/raw/fix` | `sensor_msgs/msg/NavSatFix` | Published no-fix status (`status: -1`) | Diagnostic GPS state; not navigation fix |
| MAVROS GPS global | `/mavros/global_position/global` | `sensor_msgs/msg/NavSatFix` | May be empty until GPS fix | Candidate dashboard GPS after fix |
| MAVROS IMU | `/mavros/imu/data` | `sensor_msgs/msg/Imu` | Sample captured, frame `base_link` | Candidate IMU adapter / diagnostics |
| MAVROS battery | `/mavros/battery` | `sensor_msgs/msg/BatteryState` | Sample captured | Future dashboard diagnostics panel |
| MAVROS RC | `/mavros/rc/in` | `mavros_msgs/msg/RCIn` | Empty first, then populated in no-camera recovery | Manual-input diagnostics only |
| MAVROS raw MAVLink | `/uas1/mavlink_source`, `/uas1/mavlink_sink` | `mavros_msgs/msg/Mavlink` | Advertised in topic surface | Do not map directly to dashboard |
| RealSense color | `/camera/camera/color/image_raw` | `sensor_msgs/msg/Image` | Color-only and default camera runs published | Best dashboard camera candidate |
| RealSense depth | `/camera/camera/depth/image_rect_raw` | `sensor_msgs/msg/Image` | Default camera run published | Diagnostics / later perception candidate |
| RealSense camera info | `/camera/camera/*/camera_info` | `sensor_msgs/msg/CameraInfo` | Listed with color/depth topics | Support topic, not dashboard primary |
| RealSense IMU path | `/camera/camera/imu`, `/camera/camera/accel/sample`, `/camera/camera/gyro/sample` | IMU / sample topics | Historical IMU-only evidence; not seen in 04/06 default topic list | Candidate only; re-capture before mapping |

Noise filter for the next live graph: exclude unrelated TurtleBot4 / Create3 / Gazebo / OAK-D topics observed on 04/06/2026, including examples such as `/battery_state`, `/cmd_vel`, `/scan`, and `/oakd/rgb/preview/image_raw`, unless a fresh `ROS_DOMAIN_ID=12` run proves they still belong to the active test graph.

## Block C - Existing dashboard and simulation-stack inventory

- [x] Confirm current dashboard subscriptions / publishers in `app.js`:
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

- [x] Confirm `launch/remap.launch.yaml` still matches the intended transition model:
  - Layer A: sim `/wamv/*` to neutral `/sensors/*`;
  - Layer B: future real-hardware bridge;
  - `use_real_hardware:=true` currently points to a non-existing `bridge` package, so do not flip it during normal simulation.

**Outcome:** Source audit only; the full simulation launcher was not run today.

Current dashboard / simulation topic contract:

- Dashboard connects to `rosbridge` on `9090`; camera MJPEG comes from `web_video_server` on `8080`; HTTP serving remains `serve_dashboard.py` on `8002`.
- Dashboard read topics are simulation-first: `/wamv/sensors/gps/gps/fix`, `/wamv/thrusters/left/thrust`, `/wamv/thrusters/right/thrust`, `/planning/mission_status`, `/planning/waypoints`, `/planning/current_target`, `/perception/obstacle_info`, `/control/status`, `/control/anti_stuck_status`, `/planning/config`, param ranges, `/rosout`, and optional health-check topics.
- Dashboard write / service paths are `/planning/set_config`, `/planning/mission_command`, `/planning/emergency_stop`, `/planning/stop_mission`, `/planning/generate_waypoints`, and `/health_check/run`.
- The camera panel default is `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`, but it already supports manual topic entry and `/rosapi/topics_for_type` discovery for `sensor_msgs/msg/Image` and `sensor_msgs/msg/CompressedImage`. This makes `/camera/camera/color/image_raw` the lowest-friction real camera test if `rosbridge` and `web_video_server` share the Pi's domain.
- `launch/remap.launch.yaml` still implements only the Phase 5.0 simulation relay layer when `use_real_hardware:=false`: `/wamv/sensors/gps/gps/fix -> /sensors/gps/fix`, `/wamv/sensors/imu/imu/data -> /sensors/imu/data`, `/wamv/sensors/lidars/lidar_wamv_sensor/points -> /sensors/lidar/points`, `/wamv/sensors/cameras/front_left_camera_sensor/image_raw -> /sensors/camera/image_raw`, and neutral actuator relays back to `/wamv/thrusters/*/thrust`. The `use_real_hardware:=true` branch still points to the not-yet-existing `bridge` package, so it must stay off for the default simulation stack.

## Block D - Mapping table

Fill this table before proposing edits.

| Function | Existing sim/dashboard topic | Candidate real topic | Type | Integration direction | Status |
|----------|------------------------------|----------------------|------|-----------------------|--------|
| GPS position | `/wamv/sensors/gps/gps/fix` | `/mavros/global_position/global` or `/mavros/global_position/raw/fix` | `sensor_msgs/msg/NavSatFix` | Real -> dashboard / sim pose | Same message family. Use `raw/fix` to display no-fix state; use `global` for dashboard position only after GPS fix publishes. Fresh domain-12 recapture pending. |
| IMU | `/wamv/sensors/imu/imu/data` | `/mavros/imu/data` | `sensor_msgs/msg/Imu` | Real -> sim / diagnostics | Camera-off MAVROS sample proven. Dashboard does not currently display IMU; adapter can feed neutral `/sensors/imu/data` later if needed. |
| Camera image | `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | `/camera/camera/color/image_raw` or confirmed Herelink-derived ROS topic | `sensor_msgs/msg/Image` | Real -> dashboard camera | Best immediate path is manual topic entry / auto-discovery, not a code change. Herelink visual-only path is separate and not a ROS image topic yet. |
| Battery | none in current dashboard | `/mavros/battery` | `sensor_msgs/msg/BatteryState` | Real -> future dashboard panel | Telemetry sample proven camera-off. Requires new UI or diagnostics-only logging before dashboard display. |
| RC / manual state | none in current dashboard | `/mavros/rc/in` | `mavros_msgs/msg/RCIn` | Real -> diagnostics | Useful for manual-control state and channel sanity. Not a command path. |
| MAVROS connection | none in current dashboard | `/mavros/state` | `mavros_msgs/msg/State` | Real -> dashboard diagnostics / integration gate | Add only if a diagnostics panel is approved. Use `connected: true` as the gate before trusting MAVROS telemetry. |
| Thruster command | `/wamv/thrusters/*/thrust` | MAVROS setpoint / actuator path TBD | TBD | dashboard / planner -> low-level | Not mapped. Targeted request/response and command ACK paths timed out on 04/06/2026, so do not infer a real thrust command route from VRX `Float64` topics. |

Interpretation rules:

- If a real topic is not publishing, keep it as a candidate only.
- If types differ, record the adapter needed; do not pretend a relay is enough.
- If command direction is uncertain, keep it diagnostics-only until the low-level command path is confirmed.

**Outcome:** Mapping is clean enough for planning but not for implementation. Read-side telemetry candidates are clear: MAVROS GPS / IMU / battery / RC plus RealSense color image. Write-side control remains blocked until the low-level command path is validated. The safest adapter direction is real telemetry into existing dashboard / neutral read topics first; do not bridge dashboard thruster commands to MAVROS until the command semantics, units, arming state, and ACK behavior are proven.

## Block E - Implementation proposal, no edits yet

Draft the smallest safe implementation path. Do not edit code/config until explicit approval lands.

Candidate shape:

1. **No-regression baseline:** keep the one-click simulation launcher and existing `/wamv/*` dashboard path unchanged.
2. **Camera quick win:** use dashboard camera topic auto-discovery / manual topic entry to point the camera panel at `/camera/camera/color/image_raw` if `web_video_server` can see it. This may need no code change. On 04/06 the RealSense color topic published as `RELIABLE` / `TRANSIENT_LOCAL`; confirm the actual QoS again before blaming an empty viewer.
3. **Telemetry bridge path:** prefer a launch-level topic adapter from real MAVROS topics to the dashboard's existing expected topics first, if message types match. If the adapter becomes non-trivial, then add a narrow bridge node only after approval.
4. **Dashboard topic configurability:** if launch-level mapping is insufficient, propose a dashboard-side topic profile selector (`simulation` vs `real`) in `app.js` / `index.html`; this is JavaScript/HTML work and needs approval.
5. **Simulation stack preservation:** run the full simulation launcher after every integration change to prove `/wamv/*` still works.

**Outcome:** Recommended no-edit path:

1. Re-run the live Pi capture with `ROS_DOMAIN_ID=12` confirmed in every Pi and workstation terminal.
2. Start camera-off MAVProxy + MAVROS first and require `/mavros/state connected: true`.
3. If stable, start RealSense and re-capture `/mavros/state`, MAVROS telemetry samples, and camera topic rates in the same run.
4. For dashboard camera, first use the existing camera topic input with `/camera/camera/color/image_raw` and `web_video_server`; this should need no JavaScript / HTML edit if discovery sees the topic.
5. For telemetry, prefer a small launch-level or bridge-node adapter only after approval, and keep the default `/wamv/*` simulation path unchanged.
6. Do not implement real thruster / actuator mapping until command-path validation passes separately.

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

**Outcome:** No implementation started on 05/06/2026, so the recipe remains a planned verification path only. If code or launch edits are approved later, run the simulation baseline first, then the real-topic read-only check, then the dashboard real-topic check with matching `ROS_DOMAIN_ID`.

## Block G - Day wrap

- [x] Fill all outcomes above.
- [x] If no code/config edits occurred, close as diary-only planning.
- [ ] If code/config edits occurred after explicit approval, run the verification recipe above and the standard pre-commit visibility sweep.
- [x] Set next startup hint.
- [x] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  ```

**Outcome:** 05/06/2026 work stayed diary-only and source-audit only. No Python, YAML, JavaScript, launch, dashboard, or runtime config files were edited. The clean topic inventory and mapping above are bounded to verified 04/06/2026 evidence plus today's source reads. Final checks: `git status --short --branch` showed only this diary modified; `git diff --check` passed; the placeholder / conflict-marker scan matched only the check command embedded in this Block G checklist; the visibility sweep returned zero matches. Next live pass should confirm `ROS_DOMAIN_ID=12` on the Pi and workstation, run camera-off MAVProxy + MAVROS first, then attempt the combined RealSense + MAVROS inventory only if power is stable.

## Plan-change addendum - MAVROS/camera first, YOLO feasibility stretch

User update after the first 05/06 diary commit: focus mainly on MAVROS and the camera today; if time and power stability allow, explore how to install a light YOLO model on the Pi 5.

Revised live order:

1. Confirm `ROS_DOMAIN_ID=12` and run camera-off MAVProxy + MAVROS first. `/mavros/state connected: true` remains the MAVROS gate.
2. Start the RealSense node and capture color/depth topics and rates.
3. Attempt combined MAVROS + camera only after power looks stable. Repeated under-voltage keeps the result power-limited.
4. Only after the MAVROS / camera capture, explore light-YOLO install feasibility with the camera and MAVROS workload stopped.
5. If YOLO install succeeds, first test on a static image or saved frame. Continuous camera-stream inference is optional and should be low-rate (`imgsz=320`, `vid_stride` set) to avoid hiding MAVROS / camera stability issues behind CPU load.
6. Prepare the Python environment, model weights, and exported runtime online at the bench before any field test. During boat deployment, the Pi 5 should run YOLO offline from local files because WiFi / internet access is not reliable in the field condition.

External references checked 05/06/2026:

- Ultralytics Raspberry Pi guide: Pi 5-focused guide recommends nano-class YOLO on Raspberry Pi and says NCNN is the preferred deployment format for ARM / embedded inference. It currently lists `YOLO26n` and `YOLO26s` as the Pi-sized models, with larger variants too slow for Raspberry Pi-class hardware.
- Ultralytics quickstart: standard install is `pip install -U ultralytics`; headless environments can use the headless package variant, but the Raspberry Pi export path uses `ultralytics[export]`.
- Arm / PyTorch install guide: on Arm Linux, verify `aarch64`, use a virtual environment, and install CPU PyTorch with `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu`.

Pi-side YOLO feasibility commands, to run only after the MAVROS / camera checks or during a hardware fallback window:

```bash
# Precheck, Pi terminal
source /opt/ros/jazzy/setup.bash
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}"
hostname
uname -m
python3 --version
free -h
df -h ~
sudo dmesg -T | tail -80 | grep -Ei 'voltage|thrott|under-voltage|usb|error|fail' || true
```

```bash
# Online bench prep: isolated install, Pi terminal, with MAVROS / camera stopped
sudo apt update
sudo apt install -y python-is-python3 python3-pip python3-venv
python -m venv ~/venvs/yolo-pi5
source ~/venvs/yolo-pi5/bin/activate
python -m pip install -U pip wheel
python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
python -m pip install "ultralytics[export]"
yolo settings sync=False
```

```bash
# Online bench prep: import and model-load check
source ~/venvs/yolo-pi5/bin/activate
export MODEL_WEIGHTS=yolo26n.pt
export MODEL_EXPORT="${MODEL_WEIGHTS%.pt}_ncnn_model"
python - <<'PY'
import os
import platform
import torch
from ultralytics import YOLO

print("arch:", platform.machine())
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
model = YOLO(os.environ["MODEL_WEIGHTS"])
print("model_loaded:", os.environ["MODEL_WEIGHTS"])
PY
```

If `yolo26n.pt` is not available from the installed package / model hub, set `MODEL_WEIGHTS=yolo11n.pt`, recompute `MODEL_EXPORT="${MODEL_WEIGHTS%.pt}_ncnn_model"`, and use that same pair for export and smoke tests.

```bash
# Online bench prep: NCNN export
source ~/venvs/yolo-pi5/bin/activate
export MODEL_WEIGHTS=yolo26n.pt
export MODEL_EXPORT="${MODEL_WEIGHTS%.pt}_ncnn_model"
python - <<'PY'
import os
from ultralytics import YOLO

model = YOLO(os.environ["MODEL_WEIGHTS"])
model.export(format="ncnn", imgsz=320)
print("model_export:", os.environ["MODEL_EXPORT"])
PY
```

Before leaving the bench, save at least one local test image on the Pi, for example a RealSense frame at `/home/imt-aqua-drone/yolo_test.jpg`. The field smoke test below must not depend on internet.

```bash
# Offline-capable static-image smoke test
source ~/venvs/yolo-pi5/bin/activate
export ULTRALYTICS_SKIP_REQUIREMENTS_CHECKS=1
export MODEL_WEIGHTS=yolo26n.pt
export MODEL_EXPORT="${MODEL_WEIGHTS%.pt}_ncnn_model"
python - <<'PY'
import os
from ultralytics import YOLO

ncnn_model = YOLO(os.environ["MODEL_EXPORT"])
results = ncnn_model.predict(
    source="/home/imt-aqua-drone/yolo_test.jpg",
    imgsz=320,
    device="cpu",
    verbose=False,
)
print(results[0].speed)
PY
```

Optional camera-stream smoke test only after `web_video_server` sees `/camera/camera/color/image_raw` and the Pi is not under-voltage-limited:

```bash
# Offline-capable camera-stream smoke test
source ~/venvs/yolo-pi5/bin/activate
export ULTRALYTICS_SKIP_REQUIREMENTS_CHECKS=1
export MODEL_WEIGHTS=yolo26n.pt
export MODEL_EXPORT="${MODEL_WEIGHTS%.pt}_ncnn_model"
timeout 30 yolo predict \
  model="${MODEL_EXPORT}" \
  source='http://127.0.0.1:8080/stream?topic=/camera/camera/color/image_raw&type=mjpeg' \
  imgsz=320 \
  device=cpu \
  vid_stride=5
sudo dmesg -T | tail -80 | grep -Ei 'voltage|thrott|under-voltage|usb|error|fail' || true
```

Record YOLO as a feasibility result only: installed / failed, model loaded / failed, NCNN export succeeded / failed, static-image inference speed, and any power or thermal warnings. Do not treat YOLO as integrated with the ROS camera pipeline unless a separate adapter / node is later approved.

## Next steps

Next startup: run the live topic capture. First confirm `ROS_DOMAIN_ID=12` in every Pi / workstation shell, then prove camera-off `/mavros/state connected: true` through the `/dev/ttyAMA0:57600` MAVProxy fanout, then add the RealSense node only if power is stable. If time remains after MAVROS / camera capture, try the isolated Pi 5 light-YOLO feasibility path above. If code/config edits are approved after that, implement the smallest flag-gated path that preserves the existing full simulation stack first, then add real-topic support.
