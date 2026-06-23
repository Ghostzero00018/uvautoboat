# RealSense Dashboard Testing

This page is the safe camera-only procedure for checking whether the Pi 5 RealSense image can appear in the AutoBoat web dashboard.

## Warnings

- This test is camera-only. Do not use dashboard mission controls, thruster controls, QGC Upload, arming, mode changes, parameter writes, actuator commands, Pi upload paths, or any real-FCU command path during this check.
- Keep browser-facing services loopback-only unless there is a deliberate reason to expose them. `rosbridge` on `:9090`, `web_video_server` on `:8080`, and the dashboard on `:8002` have no authentication in the current setup.
- Raw RealSense image topics over WiFi are bandwidth-heavy. The default RealSense launch can produce a visible feed, but it may be slow or unstable over the IoT network.
- Verify the ROS topic from the workstation before blaming the dashboard. If the workstation cannot see `/camera/camera/color/image_raw`, the dashboard cannot stream it.
- Do not probe `web_video_server` with `--help` on a shared network. It starts a real server process instead of only printing help.
- OpenStreetMap tiles may be blank on restricted or offline local networks. That is expected and does not affect the camera test.

## Network And Environment

Use this on the Pi and workstation:

- Both machines on `IoT IMT Nord Europe`.
- `ROS_DOMAIN_ID=12`.
- `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`.
- `ROS_LOCALHOST_ONLY` unset.

As of 19/06/2026, both the Pi 5 and the workstation `~/.bashrc` set `ROS_DOMAIN_ID=12` and `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` for new interactive shells, so a fresh terminal already carries the cross-machine discovery range; the commands below still set it explicitly as a safe redundancy and to cover non-interactive shells.

Re-exporting `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` per terminal is harmless given that bashrc default. If one terminal sees the camera and another does not, check that each terminal has the value set — inherited from `~/.bashrc` or exported — before starting its ROS process.

Keep the workstation ROS daemon restart in the W1 recipe for this field check. On 18/06/2026, the workstation only discovered the Pi camera topic after the environment was set and the daemon was restarted.

## Recommended RealSense Profile

Use this profile first for dashboard viewing:

```bash
ros2 launch realsense2_camera rs_launch.py enable_depth:=false rgb_camera.color_profile:=424x240x15
```

This was the first practical profile observed on 18/06/2026 for a smoother dashboard feed over the IoT WiFi. Higher profiles such as the default color profile or `640x480x15` can work, but they may be too slow or unstable over the network.

## Pi Terminal P1 - Start RealSense

```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "ROS_AUTOMATIC_DISCOVERY_RANGE=$ROS_AUTOMATIC_DISCOVERY_RANGE"
echo "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-unset}"

ros2 launch realsense2_camera rs_launch.py enable_depth:=false rgb_camera.color_profile:=424x240x15
```

Expected signs:

- Intel RealSense D435I detected.
- USB type `3.2`.
- `RealSense Node Is Up!`.
- A color-profile log matching the requested low-bandwidth profile, for example width `424`, height `240`, FPS `15`. If the driver snaps to a different native mode, record the actual log line and re-check W1 before proceeding.

## Workstation Terminal W1 - Verify Topic Flow

```bash
source ~/.bashrc
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "ROS_AUTOMATIC_DISCOVERY_RANGE=$ROS_AUTOMATIC_DISCOVERY_RANGE"
echo "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-unset}"

ros2 daemon stop
ros2 daemon start

ros2 topic list | grep '^/camera/camera/color/image_raw$'
ros2 topic info --verbose /camera/camera/color/image_raw
timeout 20 ros2 topic hz /camera/camera/color/image_raw
```

Pass criteria:

- `/camera/camera/color/image_raw` appears in `ros2 topic list`.
- `ros2 topic hz` reports frames on the workstation.

If the topic is unknown on the workstation but exists on the Pi, this is a DDS discovery / network issue, not a dashboard issue. Re-check `ROS_DOMAIN_ID`, `ROS_AUTOMATIC_DISCOVERY_RANGE`, `ROS_LOCALHOST_ONLY`, WiFi, and the ROS daemon. If that still fails, suspect AP client isolation or DDS multicast filtering before changing dashboard settings; verify both machines are on the same SSID/subnet and repeat a simple ROS 2 talker/listener check as described in [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026).

QoS note: `ros2 topic hz` in ROS 2 Jazzy uses a RELIABLE subscription and has no `--qos-*` flag. Check `ros2 topic info --verbose /camera/camera/color/image_raw` and read the `Reliability` line. If a future camera configuration publishes BEST_EFFORT, use the repo's QoS-aware probe instead:

```bash
cd ~/seal_ws/src/uvautoboat
python3 tools/rate_probe.py --topic /camera/camera/color/image_raw \
    --reliability best_effort --duration 20
```

See [Common Issues — QoS-Aware Rate Probing](Common_Issues#qos-aware-rate-probing-best_effort-publishers).

## Workstation Terminal W2 - Start rosbridge

```bash
source ~/.bashrc
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

ros2 launch rosbridge_server rosbridge_websocket_launch.xml address:=127.0.0.1
```

## Workstation Terminal W3 - Start web_video_server

```bash
source ~/.bashrc
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY

ros2 run web_video_server web_video_server --ros-args -p address:=127.0.0.1
```

Expected log:

```text
Waiting For connections on 127.0.0.1:8080
```

## Workstation Terminal W4 - Start Dashboard

```bash
cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat
python3 serve_dashboard.py 8002 127.0.0.1
```

Open this URL on the workstation:

```text
http://127.0.0.1:8002
```

For a pre-populated camera dropdown, open the dashboard only after W1 has already proven that `/camera/camera/color/image_raw` is visible. The dashboard asks rosbridge for image topics when the page connects; if the camera starts later, type the topic manually or hard-refresh the page after W1 passes.

Use the same browser origin during one evidence capture. `http://localhost:8002` and `http://127.0.0.1:8002` have separate browser storage, so the first-time guide may appear on one URL and not the other. That is expected and does not indicate a dashboard connection fault.

## Workstation Terminal W5 - Confirm Local-Only Exposure

```bash
ss -tlnp | grep -E ':(8002|8080|9090)\b'
```

Pass criteria: all three services are bound to `127.0.0.1`, not `0.0.0.0`.

Expected shape:

```text
127.0.0.1:9090
127.0.0.1:8080
127.0.0.1:8002
```

## Dashboard Camera Panel

Use exactly this topic:

```text
/camera/camera/color/image_raw
```

Steps:

1. Select `/camera/camera/color/image_raw` if it appears in the camera-topic dropdown.
2. If it is not listed but W1 proves it is flowing, type the topic manually.
3. Click Refresh.

Expected behavior:

- If the topic is discovered by rosbridge, the stream starts without a warning.
- If the topic is not in the discovered list, the dashboard warns but still tries the stream.
- If the typed topic has invalid syntax, the dashboard blocks it before making a `web_video_server` request.
- `web_video_server` should log a request like:

  ```text
  /stream?topic=/camera/camera/color/image_raw&type=mjpeg&quality=80
  ```

For a direct MJPEG check, open:

```text
http://127.0.0.1:8080/stream?topic=/camera/camera/color/image_raw&type=mjpeg&quality=80
```

If the direct URL works but the dashboard panel is stale, hard-refresh the dashboard page.

If W1 shows frames but both the dashboard panel and direct MJPEG URL are blank, check `web_video_server` before changing the camera launch:

```bash
ps aux | grep web_video_server | grep -v grep
curl -I --max-time 3 http://127.0.0.1:8080/
```

If CPU is pegged or `curl` times out, stop W3 with `Ctrl+C`, restart `web_video_server`, then hard-refresh the dashboard. See [Common Issues — Camera Stuck on Connecting](Common_Issues#camera-stuck-on-connecting-after-full-tab-close--hard-refresh).

If the topic appears in W1 and the direct MJPEG URL works, but the dashboard panel still does not update, hard-refresh the dashboard (`Ctrl+Shift+R`) and re-enter `/camera/camera/color/image_raw`.

## Optional Simulation-Stack Coexistence Check

The normal VRX simulation stack can run while the dashboard camera panel displays the Pi RealSense feed. In that case, change only the Camera panel topic to:

```text
/camera/camera/color/image_raw
```

On 18/06/2026, the user observed a full simulated out-and-return-home mission while the dashboard camera panel showed the Pi RealSense feed. Treat this as simulation UI coexistence evidence only. It does not prove a real-boat mission, QGC upload, MAVROS telemetry, Herelink acceptance, or any real-FCU command/write path.

## Performance Notes From 18/06/2026

- The default RealSense launch exposed the expected color topic but was too heavy for smooth remote dashboard viewing.
- `enable_depth:=false` at the default color profile still produced low / unstable workstation receive rate.
- `640x480x15` was still unstable during the observed test window.
- `424x240x15` produced a visibly smoother dashboard image. During the full dashboard stack, workstation `ros2 topic hz` initially reported near `15 Hz`; one long `27.821 s` gap made the later `10.35 Hz` value a gap-skewed cumulative average, not the clean steady rate.
- After stopping the dashboard browser tab, dashboard server, `web_video_server`, and rosbridge, a clean workstation `timeout 20 ros2 topic hz /camera/camera/color/image_raw` sample stayed near `14.8-15.0 Hz` with low jitter.

Treat these values as field evidence for this network and hardware state, not a universal camera benchmark.

## Shutdown

Stop the live processes when the check is finished:

- Pi P1 RealSense launch: `Ctrl+C`.
- Workstation W2 rosbridge: `Ctrl+C`.
- Workstation W3 `web_video_server`: `Ctrl+C`.
- Workstation W4 dashboard server: `Ctrl+C`.
- Close the dashboard browser tab.

## What This Test Does Not Prove

This test does not prove:

- QGC mission upload.
- Herelink console acceptance.
- MAVROS telemetry.
- Real-FCU command or write paths.
- Dashboard mission or thruster controls.
- Bidirectional QGC / dashboard mission sync.

It only proves the camera display path from Pi RealSense to workstation dashboard.

## Related Pages

- [Dashboard Security](Dashboard_Security)
- [Pi 5 Bringup Smoke Test](Pi5_Bringup_Smoke_Test)
- [Roadmap](Roadmap)
- [YOLO Dataset Plan](YOLO_Dataset_Plan)
