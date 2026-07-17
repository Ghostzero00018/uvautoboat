# Live Hailo and MAVROS Dashboard Testing

This runbook starts the workstation dashboard services first, then runs the
tracked Pi source-stack helper for a bounded, view-only evidence window with an
optional monitored demonstration hold.
The image and telemetry paths are separate:

- `web_video_server` subscribes to `/hailo/overlay/image_raw` and serves MJPEG
  to the browser.
- rosbridge carries the five direct MAVROS subscriptions used by the temporary
  state, GPS, IMU, battery, and RC panel.

Do not use `one_click_launch_all/launch_autoboat_complete.sh` for this test. It
is the simulation launcher and starts Gazebo and navigation nodes. The Pi file
used here is `pi_live_hailo_mavlink_dashboard.sh`.

## Current Tracked Revisions

The repository copies are canonical. Copy both files to the Pi before a run
whenever either checksum differs.

| Item | Value |
| --- | --- |
| Helper source | `tools/pi_live_hailo_mavlink_dashboard.sh` |
| Helper Pi destination | `~/hailo_coco_overlay_2026-07-10/pi_live_hailo_mavlink_dashboard.sh` |
| Helper size | `47,978` bytes |
| Helper SHA-256 | `b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12` |
| Preflight source | `tools/live_dashboard_preflight.sh` |
| Preflight Pi destination | `~/hailo_coco_overlay_2026-07-10/live_dashboard_preflight.sh` |
| Preflight size | `25,608` bytes |
| Preflight SHA-256 | `27942aa0ab10dc9bc5fb949868e3956eae8d1987c07dd0c73acf4d6fb8d5b8de` |

This revision retains the finite 120-second evidence window and adds an
opt-in, fully monitored post-window hold for demonstrations. A transient
MAVProxy link-down line no longer bypasses the finite heartbeat deadline.
Syntax, deterministic heartbeat recovery/timeout checks, lifecycle-marker
order, and hold safety coverage are verified offline. The revision still needs
one checksum-matched live run with the final success markers before it is
treated as runtime-validated.

The earlier `45,676`-byte snapshot with SHA-256
`3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce`
remains a historical, unvalidated deployment snapshot. HEFs, calibration data,
the Hailo runtime tree, and generated logs remain outside this repository.

## Before Starting

- Workstation and Pi are on the same `IMT Nord Europe 5G` link with
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

## 1. Workstation W1 - Static And Environment Preflight

Host: workstation. Terminal: new W1, one-shot. Working directory: repository
root. This runs the dashboard, helper, and preflight contract tests, verifies
the helper checksum, requires the exact configured 5G SSID, prints the current
IPv4 addresses, and rejects occupied dashboard ports or conflicting processes.

```bash
cd ~/seal_ws/src/uvautoboat
tools/live_dashboard_preflight.sh workstation
```

Continue only after `W1_PREFLIGHT=PASS`. Retain the Wi-Fi IPv4 address printed
by this command for Pi P1. The process checks use separate, tested patterns;
do not replace this command with a pasted combined regular expression.

## 2. Workstation W2 - rosbridge

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

## 3. Workstation W3 - web_video_server

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

## 4. Workstation W4 - Dashboard HTTP Server

Host: workstation. Terminal: new W4, foreground. Working directory: dashboard
root.

```bash
cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat
python3 serve_dashboard.py 8002 127.0.0.1
```

Continue only after it reports `Serving HTTP on 127.0.0.1 port 8002`. Leave W4
running, but do not open the browser yet.

## 5. Refresh The Pi Files When Needed

Host: workstation. Terminal: new one-shot terminal. Working directory:
repository root. Enter the current Pi SSH endpoint when prompted.

```bash
read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
(
  set -euo pipefail
  cd ~/seal_ws/src/uvautoboat
  : "${PI_SSH:?Pi SSH endpoint is required}"
  echo 'b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12  tools/pi_live_hailo_mavlink_dashboard.sh' | sha256sum -c -
  echo '27942aa0ab10dc9bc5fb949868e3956eae8d1987c07dd0c73acf4d6fb8d5b8de  tools/live_dashboard_preflight.sh' | sha256sum -c -
  scp tools/pi_live_hailo_mavlink_dashboard.sh tools/live_dashboard_preflight.sh \
    "${PI_SSH}:~/hailo_coco_overlay_2026-07-10/"
)
```

Skip this transfer only when both Pi files already have the checksums below.

## 6. Pi P1 - Verify And Run The Live Stack

Host: Pi. Terminal: new P1, foreground. The helper sources ROS Jazzy, sets
domain `12` with `SUBNET` discovery, owns the UART through MAVProxy, starts a
minimal telemetry MAVROS profile, and starts the Hailo image publisher. The
view-only boundary is enforced by the temporary dashboard mode and operator
procedure; MAVROS itself is not a structurally read-only graph.

```bash
cd ~/hailo_coco_overlay_2026-07-10
read -r -p 'Current workstation Wi-Fi IPv4 from W1: ' WORKSTATION_IP
export WORKSTATION_IP
(
  set -euo pipefail
  : "${WORKSTATION_IP:?Workstation Wi-Fi IPv4 is required}"
  echo 'b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12  pi_live_hailo_mavlink_dashboard.sh' | sha256sum -c -
  echo '27942aa0ab10dc9bc5fb949868e3956eae8d1987c07dd0c73acf4d6fb8d5b8de  live_dashboard_preflight.sh' | sha256sum -c -
  chmod +x pi_live_hailo_mavlink_dashboard.sh live_dashboard_preflight.sh
  ./live_dashboard_preflight.sh pi "$WORKSTATION_IP"
)
```

Continue only after `P1_PREFLIGHT=PASS`. Then, in the same P1 terminal, launch
the helper directly in the foreground:

```bash
(
  set -euo pipefail
  cd ~/hailo_coco_overlay_2026-07-10
  : "${WORKSTATION_IP:?Run the P1 preflight block first}"
  printf 'PI_TEMP_START_MC='
  cat /sys/class/thermal/thermal_zone0/temp
  exec env WORKSTATION_IP="$WORKSTATION_IP" LIVE_HOLD_AFTER_WINDOW=1 \
    ./pi_live_hailo_mavlink_dashboard.sh
)
```

Run the helper directly. Do not wrap it in an external GNU `timeout`; its own
default 120-second evidence window must finish naturally. With
`LIVE_HOLD_AFTER_WINDOW=1`, the full safety monitor remains active after the
window and the stack continues until `Ctrl+C`. Omitting the variable preserves
the bounded default and starts teardown immediately after the window.

The expected negative probe prints
`CANONICAL_STRIPPED_RCLPY=UNAVAILABLE informational rc=1` and a
`ModuleNotFoundError` traceback. It is informational only when immediately
followed by `HAILO_ROS_PREFLIGHT=PASS`.

`WORKSTATION_IP` is required for the Pi preflight and live run. Enter W1's
current same-link Wi-Fi IPv4 address at the prompt; the exported value is
reused by the separately gated launch block. The preflight checks the pinned
helper, default Pi devices, resource ownership, port `14550`, same-link route, SSID,
and non-hardware Hailo/ROS import path. Stop immediately on any checksum
failure, missing `P1_PREFLIGHT=PASS`, `STOP:`, `ERROR line=`, thermal
abort, command-sentinel abort, or loss of the connected and disarmed MAVROS
state. `CLEANUP_ERROR` or `TEARDOWN=FAIL` also makes the run a failure. If the
MAVProxy log first reports a link-down line, the helper records
`MAVPROXY_LINK_DOWN=OBSERVED` and continues only until the existing finite
heartbeat deadline. A later heartbeat must produce
`MAVPROXY_LINK_RECOVERY=PASS`; otherwise the run stops at the deadline.

## 7. Browser Acceptance

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

## 8. Workstation W5 - Same-Run Topic Rates

Host: workstation. Terminal: new W5, sequential one-shot probes. Working
directory: repository root. Start only after Pi P1 prints
`PI_SOURCE_STACK_READY=PASS` and the browser shows the live combined view.
Leave W2-W4 and Pi P1 running throughout.

```bash
cd ~/seal_ws/src/uvautoboat
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12 ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER RMW_IMPLEMENTATION \
  FASTDDS_DEFAULT_PROFILES_FILE FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI
test -x tools/rate_probe.py
W5_LOG="$HOME/Desktop/w5_live_rates_$(date +%Y%m%d_%H%M%S).log"
(
  set -euo pipefail
  date -Is
  for topic in \
    /hailo/overlay/image_raw \
    /mavros/state \
    /mavros/global_position/raw/fix \
    /mavros/imu/data \
    /mavros/battery \
    /mavros/rc/in
  do
    printf '=== %s ===\n' "$topic"
    ros2 topic info --no-daemon --spin-time 3 --verbose "$topic"
  done
  python3 tools/rate_probe.py --topic /hailo/overlay/image_raw --type sensor_msgs/msg/Image --reliability reliable --depth 1 --duration 10
  python3 tools/rate_probe.py --topic /mavros/state --type mavros_msgs/msg/State --reliability best_effort --depth 10 --duration 10
  python3 tools/rate_probe.py --topic /mavros/global_position/raw/fix --type sensor_msgs/msg/NavSatFix --reliability best_effort --depth 10 --duration 10
  python3 tools/rate_probe.py --topic /mavros/imu/data --type sensor_msgs/msg/Imu --reliability best_effort --depth 10 --duration 10
  python3 tools/rate_probe.py --topic /mavros/battery --type sensor_msgs/msg/BatteryState --reliability best_effort --depth 10 --duration 10
  python3 tools/rate_probe.py --topic /mavros/rc/in --type mavros_msgs/msg/RCIn --reliability best_effort --depth 10 --duration 10
  echo 'W5_RATE_PROBES=PASS topics=6 duration_each=10s'
) 2>&1 | tee "$W5_LOG"
W5_RC="${PIPESTATUS[0]}"
printf 'W5_RC=%s W5_LOG=%s\n' "$W5_RC" "$W5_LOG"
```

The topic-info records capture the live publishers' offered QoS before the
measurements. Each probe must print `N=...` and `mean=... Hz`; the complete
block must finish with `W5_RATE_PROBES=PASS` and `W5_RC=0`. Start W5 promptly so
the six 10-second samples normally finish inside the 120-second evidence
window. If a probe extends into `PI_SOURCE_HOLD=ACTIVE`, keep it running and
record that it was measured during the same invocation's monitored hold. Do
not press `Ctrl+C` in Pi P1 until W5 has returned to its shell prompt. A
nonzero `W5_RC`, zero/one message result, import failure, or topic-discovery
failure leaves the rate gate open; preserve `W5_LOG` and proceed to orderly
teardown rather than rerunning the stack immediately.

These measurements describe the current `240p@10fps` diagnostic profile; they
do not select an optimized resolution, frame rate, or transport by themselves.

## 9. Pass, Logs, And Shutdown

A complete bounded run needs the three acceptance and teardown markers:

```text
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s ...
TEARDOWN=PASS
```

In hold mode, wait for the first three lines below before continuing the demo.
When the demonstration is finished, press `Ctrl+C` once in Pi P1 and wait for
the final two lines:

```text
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s ...
PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C
PI_SOURCE_HOLD=STOP operator-requested
TEARDOWN=PASS
```

`PI_SOURCE_WINDOW=COMPLETE` proves the monitored evidence window closed;
`PI_SOURCE_HOLD=ACTIVE` proves monitoring continued for the demonstration; and
`TEARDOWN=PASS` is emitted only after the Pi resources have actually stopped.

Pi logs are written under
`~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_YYYYMMDD_HHMMSS`.
For review, paste the Pi console from the checksum `OK` line through the final
`logs=` line. This ties the helper bytes, source window, and teardown result to
the same invocation. Copy back the matching directory from a new workstation
terminal after the first checksum-matched validation run and whenever a failure
needs analysis:

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

In idle Pi P1, use the exact directory from the helper's final `logs=` line to
capture the same run's peak and post-run temperature:

```bash
RUN_DIR="$HOME/hailo_coco_overlay_2026-07-10/logs/live_dashboard_YYYYMMDD_HHMMSS"
printf 'PI_TEMP_PEAK_MC='
cat "$RUN_DIR/thermal_peak_mc.txt"
printf 'PI_TEMP_POST_MC='
cat /sys/class/thermal/thermal_zone0/temp
```

Paste back `W5_LOG`, the full W5 output, `PI_TEMP_START_MC`, `PI_TEMP_PEAK_MC`,
`PI_TEMP_POST_MC`, the browser observations, and Pi P1 from the checksum `OK`
line through the final `logs=` line.

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
