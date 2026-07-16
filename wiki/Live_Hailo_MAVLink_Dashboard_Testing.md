# Live Hailo and MAVROS Dashboard Testing

This runbook starts the workstation dashboard services first, then runs the
external Pi source-stack helper for a bounded, view-only hardware diagnostic.
The image and telemetry paths are separate:

- `web_video_server` subscribes to `/hailo/overlay/image_raw` and serves MJPEG
  to the browser.
- rosbridge carries the five direct MAVROS subscriptions used by the temporary
  state, GPS, IMU, battery, and RC panel.

Do not use `one_click_launch_all/launch_autoboat_complete.sh` for this test. It
is the simulation launcher and starts Gazebo and navigation nodes. The Pi file
used here is `pi_live_hailo_mavlink_dashboard.sh`.

## Current Helper Revision

The helper is external to this repository.

| Item | Value |
| --- | --- |
| Workstation archive | `~/Desktop/pi_helpers/pi_live_hailo_mavlink_dashboard.sh` |
| Pi destination | `~/hailo_coco_overlay_2026-07-10/pi_live_hailo_mavlink_dashboard.sh` |
| Size | `45,676` bytes |
| SHA-256 | `3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce` |

The service order and browser path were observed working on 15/07/2026. This
archive is a later corrected helper revision: its syntax and checksum are
verified, but it needs one checksum-matched run with the final success markers
before it is treated as runtime-validated.

## Before Starting

- Workstation and Pi are on the same `IoT IMT Nord Europe` link with
  `ROS_DOMAIN_ID=12` and `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`.
- Control box is powered, the FCU is disarmed, and propulsion is isolated.
- D435I and Hailo hardware are connected to the Pi.
- Gazebo, navigation/controller nodes, `realsense2_camera`, old MAVProxy,
  MAVROS, and earlier helper runs are stopped.
- Ports `8002`, `8080`, and `9090` are free on the workstation.
- Keep the dashboard browser closed until the Pi prints
  `PI_SOURCE_STACK_READY=PASS`.
- The temporary direct-MAVROS dashboard changes are present in the workstation
  worktree. This is a diagnostic, not the default simulation dashboard mode.

Use new foreground terminals. Do not reuse a terminal that is already running
a service.

## 1. Workstation W2 - rosbridge

Host: workstation. Terminal: new W2, foreground. Working directory: home.

```bash
cd ~
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER RMW_IMPLEMENTATION \
  FASTDDS_DEFAULT_PROFILES_FILE FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI
ros2 launch rosbridge_server rosbridge_websocket_launch.xml address:=127.0.0.1
```

Continue only after rosbridge reports that the WebSocket server is listening on
port `9090`. Leave W2 running.

## 2. Workstation W3 - web_video_server

Host: workstation. Terminal: new W3, foreground. Working directory: home.

```bash
cd ~
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER RMW_IMPLEMENTATION \
  FASTDDS_DEFAULT_PROFILES_FILE FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI
ros2 run web_video_server web_video_server --ros-args -p address:=127.0.0.1
```

Continue only after it reports `Waiting For connections on 127.0.0.1:8080`.
Leave W3 running.

## 3. Workstation W4 - Dashboard HTTP Server

Host: workstation. Terminal: new W4, foreground. Working directory: dashboard
root.

```bash
cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat
python3 serve_dashboard.py 8002 127.0.0.1
```

Continue only after it reports `Serving HTTP on 127.0.0.1 port 8002`. Leave W4
running, but do not open the browser yet.

## 4. Refresh The Pi Helper When Needed

Host: workstation. Terminal: one-shot. Replace `user@pi-host` with the current
Pi SSH endpoint.

```bash
cd ~
PI_SSH='user@pi-host'
scp ~/Desktop/pi_helpers/pi_live_hailo_mavlink_dashboard.sh \
  "${PI_SSH}:~/hailo_coco_overlay_2026-07-10/"
```

Skip this transfer when the Pi already has the checksum below.

## 5. Pi P1 - Verify And Run The Live Stack

Host: Pi. Terminal: new P1, foreground. The helper sources ROS Jazzy, sets
domain `12` with `SUBNET` discovery, owns the UART through MAVProxy, starts a
minimal telemetry MAVROS profile, and starts the Hailo image publisher. The
view-only boundary is enforced by the temporary dashboard mode and operator
procedure; MAVROS itself is not a structurally read-only graph.

```bash
cd ~/hailo_coco_overlay_2026-07-10
echo '3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce  pi_live_hailo_mavlink_dashboard.sh' | sha256sum -c -
chmod +x pi_live_hailo_mavlink_dashboard.sh
./pi_live_hailo_mavlink_dashboard.sh
```

Run the helper directly. Do not wrap it in an external GNU `timeout`; its own
default 120-second window must finish naturally so it can emit the completion
and teardown markers.

The expected negative probe prints
`CANONICAL_STRIPPED_RCLPY=UNAVAILABLE informational rc=1` and a
`ModuleNotFoundError` traceback. It is informational only when immediately
followed by `HAILO_ROS_PREFLIGHT=PASS`.

Stop immediately on any checksum failure, `STOP:`, `ERROR line=`, thermal
abort, command-sentinel abort, or loss of the connected and disarmed MAVROS
state. `CLEANUP_ERROR` or `TEARDOWN=FAIL` also makes the run a failure. If the
workstation address changed, set `WORKSTATION_IP` to its current address when
invoking the helper.

For a changed address, replace the example value before running:

```bash
WORKSTATION_IP='10.120.2.x' ./pi_live_hailo_mavlink_dashboard.sh
```

## 6. Browser Acceptance

Wait for this Pi marker:

```text
PI_SOURCE_STACK_READY=PASS
```

Then open or hard-refresh <http://127.0.0.1:8002/>. Select
`/hailo/overlay/image_raw` in the Camera panel and verify:

- live Hailo boxes and class labels;
- all five MAVROS badges remain `Live` with independent ages below `3.0 s`;
- MAVROS state remains freshly connected and disarmed;
- GPS, IMU, battery, and RC activity reaches the view-only panel without a
  `Stale` badge or cleared values;
- GPS no-fix is displayed as telemetry state, not transport loss;
- vehicle-writing mission, configuration, tuning, and health-check controls are
  inert while local history, export, copy, and auto-scroll controls remain
  usable;
- dashboard command and configuration writes remain blocked.

Any `Stale` badge fails the browser check for that topic. A surviving IMU topic
must not make state, GPS, battery, or RC appear current.

Do not use mission, thruster, arming, mode, RC override, parameter, or setpoint
controls during this diagnostic.

## 7. Pass, Logs, And Shutdown

A complete run needs all three final Pi markers:

```text
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s ...
TEARDOWN=PASS
```

Pi logs are written under
`~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_YYYYMMDD_HHMMSS`.
For review, paste the Pi console from the checksum `OK` line through the final
`logs=` line. This ties the helper bytes, source window, and teardown result to
the same invocation. Copy back the matching directory from a new workstation
terminal when a failure needs analysis:

```bash
cd ~
PI_SSH='user@pi-host'
RUN_NAME='live_dashboard_YYYYMMDD_HHMMSS'
mkdir -p ~/Desktop/test_logs_folder
scp -r "${PI_SSH}:hailo_coco_overlay_2026-07-10/logs/${RUN_NAME}" \
  ~/Desktop/test_logs_folder/
```

After the Pi helper completes and reports `TEARDOWN=PASS`:

1. Close the browser tab.
2. Press `Ctrl+C` in workstation W4, then W3, then W2.
3. Confirm no old helper, MAVProxy, MAVROS, Hailo image publisher, or camera
   owner remains before another run.

If cleanup reports `CLEANUP_ERROR` or `TEARDOWN=FAIL`, do not rerun. Close the
browser, stop W4, W3, and W2, preserve the final Pi console and matching log
directory, and inspect the remaining camera, Hailo, UART, UDP, and ROS owners
before deciding on cleanup.

This procedure proves bounded simultaneous view-only delivery only. It does not
prove full endurance, an optimized image profile, a GPS fix, custom maritime
detector accuracy, or any dashboard-to-FCU write path.

## Related Pages

- [Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo)
- [RealSense Dashboard Testing](RealSense_Dashboard_Testing)
- [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test)
- [Dashboard Security](Dashboard_Security)
