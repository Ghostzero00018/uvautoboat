# Common Issues & Solutions

Troubleshooting guide for frequent problems with AutoBoat.

---

## Navigation Issues

### Boat Not Moving

**Symptoms**: Boat sits idle despite mission started

**Diagnosis**:

```bash
# Check GPS signal
ros2 topic echo /wamv/sensors/gps/gps/fix --once
```

**Solutions**:

1. **Sim readiness still in progress**: the launcher runs bounded-retry readiness polls for each stage (Gazebo topics, rosbridge port, nav-node discovery). Typical cold-start is ~20-40 s on a warm machine, but absolute numbers are hardware-dependent (CPU, GPU, disk I/O, asset-cache state, concurrent load) — your machine's baseline may differ. Let the 6 launcher terminals finish their spinner output before issuing commands. The launcher prints a `Total launch time: N s (Mm Ss)` line right under the success banner — use it for cold-vs-warm comparisons on your own machine, not as an absolute benchmark.
2. **Mission not started**: Run `ros2 run plan autoboat_cli start` (or use the dashboard Start button — interactive mode preferred over one-shot CLI commands, which can race DDS late-joiner discovery)
3. **Waypoints not generated**: Run `ros2 run plan autoboat_cli generate`
4. **Node not running**: Check `ros2 node list | grep -E 'heading_controller|lidar_perception|waypoint_planner'`

---

### Boat Spinning in Circles

**Symptoms**: Boat rotates continuously without making progress

**Cause**: PID gains too high (over-responsive)

**Solution**: Reduce PID proportional gain

```bash
ros2 param set /heading_controller_node kp 300.0
```

**Alternative**: Increase derivative gain for damping

```bash
ros2 param set /heading_controller_node kd 150.0
```

---

### Boat Oscillates Around Heading

**Symptoms**: Boat zigzags toward target instead of straight line

**Cause**: Insufficient damping (Kd too low)

**Solution**: Increase derivative gain

```bash
ros2 param set /heading_controller_node kd 150.0
```

---

### Boat Drifts Off Course

**Symptoms**: Boat consistently misses waypoints to one side

**Causes**:

1. **Simulated current/wind**: Normal behavior, simple anti-stuck will compensate
2. **Integral windup**: Ki too high

**Solutions**:

1. Enable simple anti-stuck (should be active by default)
2. Reduce integral gain if overshooting:

   ```bash
   ros2 param set /heading_controller_node ki 10.0
   ```

---

### "CRITICAL" Warning at Spawn

**Symptoms**: Boat immediately detects critical obstacle at start

**Cause**: Dock/harbor structure within minimum LIDAR range

**Solution**: Increase minimum detection range

```yaml
# In autoboat.launch.yaml
- name: min_range
  value: 4.0  # Increase from default 2.2 (gives more slack around dock / spawn structures)
```

**Alternative**: Teleport boat away from dock

```bash
gz service -s /world/sydney_regatta/set_pose \
  --reqtype gz.msgs.Pose --reptype gz.msgs.Boolean --timeout 1000 \
  --req 'name: "wamv", position: {x: 10, y: 10, z: 0.5}'
```

---

### Simple Anti-Stuck Activates Too Frequently

**Symptoms**: Simple anti-stuck system triggers during normal navigation

**Cause**: Stuck detection too sensitive

**Solutions**:

1. Increase timeout (less sensitive — boat must stay still longer before triggering; default 12.0 s):

   ```bash
   ros2 param set /heading_controller_node stuck_timeout 20.0
   ```

2. Increase movement threshold (larger unblocked-motion required to count as "moving"; default 1.0 m):

   ```bash
   ros2 param set /heading_controller_node stuck_threshold 2.0
   ```

---

### Waypoints Skip Too Often

**Symptoms**: Mission skips waypoints that appear reachable

**Cause**: Waypoint skip timeout too short for obstacle avoidance

**Solution**: Increase timeout

```yaml
# In autoboat.launch.yaml
- name: waypoint_skip_timeout
  value: 60.0  # Increase from default 45.0
```

---

## Obstacle Detection Issues

### No Obstacles Detected

**Symptoms**: Boat shows "CLEAR" even near obstacles

**Diagnosis**:

```bash
# Check obstacle detection rate — perception publishes once per LiDAR scan.
# Steady-state ~20 Hz at Gazebo RTF ≈ 1.0; scales down proportionally when the
# sim is running slower than real time.
ros2 topic hz /perception/obstacle_info

# Raw LiDAR rate + liveness. In the current ros_gz_bridge config this topic is
# published RELIABLE (verify via `ros2 topic info --verbose`), so the default
# hz probe works. If a future bridge change switches the publisher to
# BEST_EFFORT, see "QoS-aware rate probing" below — Jazzy's `ros2 topic hz`
# has no --qos-* flag and mismatches against BEST_EFFORT publishers silently.
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points
ros2 topic info /wamv/sensors/lidars/lidar_wamv_sensor/points   # expect Publisher count: 1

# Sample current obstacle-info JSON once
ros2 topic echo /perception/obstacle_info --once
```

**Solutions**:

1. **LIDAR not publishing**: Restart Gazebo
2. **Height filter too restrictive**: Widen slightly around YAML defaults (`min_height: -1.2`, `max_height: 1.5`). Going far outside this range picks up sky / water reflections and makes detections *worse*, not better.

   ```yaml
   min_height: -2.0
   max_height: 3.0
   ```

3. **Range filter too restrictive**: Increase max_range

   ```yaml
   max_range: 100.0
   ```

---

### False Obstacle Detections

**Symptoms**: Boat detects obstacles in empty water

**Cause**: Water reflections or noise

**Solutions**:

1. **Enable water plane removal** (should be default)
2. **Increase temporal filtering**:

   ```yaml
   temporal_history_size: 7
   temporal_threshold: 5
   ```

3. **Adjust water plane threshold**:

   ```yaml
   water_plane_threshold: 0.8
   ```

---

### Boat Collides with Obstacles

**Symptoms**: Boat hits obstacles despite LIDAR detection

**Causes**:

1. **Safe distance too small**
2. **Control loop too slow**
3. **Speed too high near obstacles**

**Solutions**:

1. Increase safe distance:

   ```yaml
   min_safe_distance: 15.0  # Controller avoidance trigger (increase from 12.0)
   ```

2. Reduce obstacle slow factor:

   ```yaml
   obstacle_slow_factor: 0.2  # More aggressive slowdown
   ```

3. Reduce max speed:

   ```yaml
   max_speed: 600.0  # Reduce from 800.0
   ```

---

## Dashboard Issues

### Dashboard Not Connecting

**Symptoms**: "Disconnected" status in dashboard, or page only half renders

**Run through these checks in order:**

**1. Is rosbridge listening?**

```bash
ss -tuln | grep 9090
# Should show LISTEN on port 9090. If empty → rosbridge not running.
```

**2. Is ROS_DOMAIN_ID the same in every terminal?**

```bash
echo $ROS_DOMAIN_ID
# Run in EVERY terminal tab. All must match (or all be empty/unset).
# Mismatch = rosbridge can't see ROS topics → dashboard stays disconnected.
```

**3. Can rosbridge see ROS topics?**

```bash
ros2 topic list | grep planning
# Should show /planning/mission_status. If empty → domain mismatch or nodes crashed.
```

**4. Start rosbridge** (if not running):

```bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0
```

**5. Check browser console** (F12 → Console tab):

| Error | Meaning |
|:------|:--------|
| `Failed to load resource: roslib.min.js` | Vendored roslib asset missing or path wrong — check `web_dashboard/autoboat/vendor/roslib/roslib.min.js` |
| `Failed to load resource: leaflet.js` | Vendored Leaflet asset missing or path wrong — check `web_dashboard/autoboat/vendor/leaflet/leaflet.js` |
| `WebSocket connection to 'ws://localhost:9090' failed` | rosbridge not running or port blocked |

> **Offline status:** `roslib.js`, Leaflet, and dashboard fonts are vendored under
> `web_dashboard/autoboat/vendor/` as of 05/05/2026, so internet access is no
> longer required for those libraries. OpenStreetMap tiles still require internet
> until [Roadmap §1.3](Roadmap#13-iot-imt-nord-europe--local-only-network-constraint-analysed-30042026)
> Path B (offline tile server) lands.

**6. Firewall blocking?**

```bash
sudo ufw status
# If active:
sudo ufw allow 9090/tcp
sudo ufw allow 8002/tcp
sudo ufw allow 8080/tcp
```

---

### Camera Panel Shows "No Image"

**Symptoms**: Dashboard camera panel blank

**Solutions**:

1. **Start web_video_server**:

   ```bash
   ros2 run web_video_server web_video_server
   ```

2. **Check camera topic**: Default is `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`
3. **Verify topic exists** (matches both the VRX `/wamv/sensors/cameras/*` name and the neutral `/sensors/camera/*` relay from `remap.launch.yaml` if it's running):

   ```bash
   ros2 topic list | grep -E 'camera|image'
   ```

4. **Refresh stream**: Click "Refresh Stream" button in dashboard

---

### QGC / Mission Planner Can Arm via Herelink, but Video Is Missing

**Symptoms**:

- Herelink controller shows manual control / onboard video.
- QGroundControl and Mission Planner on a laptop can connect well enough to
  arm/disarm the vehicle.
- Laptop-side QGC / MP video panel stays blank.
- QGC logs may show VA-API errors, offline map-tile errors, and
  `PhotoVideoControl.qml` camera-binding errors, but no
  `qgc.videomanager.videoreceiver.gstreamer.*` pipeline-construction lines.

**Interpretation**: MAVLink and video are separate paths. Arm/disarm proving
MAVLink reachability does **not** prove that Herelink is re-streaming camera
video to the laptop. Treat this as a video forwarding / RTSP URL problem until
direct stream tests prove otherwise. If the same Herelink video stream worked at
another site before, preserve that as a location / link-condition variable and
repeat a controlled campus-vs-field comparison before changing many settings.

**Campus working-room verification (11/05/2026)**: Linux QGC video is working
on the Herelink hotspot link (SSID `IMT-Aquatic-drone`, hotspot gateway
`192.168.43.1`) from the intern's working room. **QGC config is a single
non-default knob**: `Application Settings → General → Video → Source` =
**`Herelink Hotspot`** (a built-in named preset; no manual URL field
involved). Other Video panel settings (Aspect Ratio `1.777777` = 16:9, Low
Latency Mode OFF, Default decode priority, mp4 record format) are at QGC
defaults. The underlying RTSP stream behind that preset was verified
independently with `ffplay rtsp://192.168.43.1:8554/fpv_stream` — LIVE555
server, H.264 High @ 1920×1080 30 fps; both UDP-default and TCP-interleaved
transports work. QGC's "Herelink Hotspot" preset is consistent with this
independently verified Herelink RTSP endpoint. The alternate path `/live`
does **not** exist on this firmware (`404 Stream Not Found`). The 07/05 lake
video failure for QGC remains untested under the now-known-good preset —
open cause class is still "QGC video Source setting / network topology /
site link condition". Linux Mission Planner on the same link fails with a
separate runtime issue (see "Mission Planner on Linux: libSkiaSharp
DllNotFoundException" below).

**Log triage**:

| Log signal | Likely meaning |
|:-----------|:---------------|
| `libva error ... iHD_drv_video.so ... __vaDriverInit_1_0` | Usually noise. Intel hardware decode is unavailable; software decode fallback should still work. |
| `QGeoTileRequestManager: Network Not Available` | Usually noise. Map tiles are offline on the local Herelink network; unrelated to camera video. |
| `PhotoVideoControl.qml ... 'cameras' of null` | Symptom. QGC has no active video stream object to bind to. |
| No `qgc.videomanager.videoreceiver.gstreamer.*` lines with video debug enabled | Important. QGC likely did not start a video pipeline at all. |

**Diagnosis**:

1. **Find the Herelink IP that the working control link uses.**

   In QGC, check the Comm Link used for MAVLink and note the host address. From
   a terminal, also capture the local routing state:

   ```bash
   ip route
   arp -a
   ```

2. **Test the video stream outside QGC first.** Use `ffplay` (from
   `ffmpeg`) — it has independent RTSP support and works on standard
   IP-camera streams:

   ```bash
   sudo apt install ffmpeg
   ffplay rtsp://<herelink-ip>:8554/fpv_stream
   # If the default UDP transport hangs in a restrictive network, force TCP:
   ffplay -rtsp_transport tcp rtsp://<herelink-ip>:8554/fpv_stream
   ```

   CubePilot's USB-tether default is `rtsp://192.168.42.129:8554/fpv_stream`;
   in Wi-Fi / hotspot mode (verified 11/05/2026), the Herelink IP is the
   default gateway after joining its hotspot (e.g. `192.168.43.1` on
   `IMT-Aquatic-drone`).

   **Caveat on `vlc`**: Ubuntu Noble's apt-installed VLC on this workstation
   lacks the Live555 RTSP access module (the package is built with
   `--disable-live555`) and fails on this Herelink stream with
   `satip stream error: Failed to play RTSP session`. Snap-installed VLC
   (`sudo snap install vlc`) or Flatpak (`flatpak install flathub
   org.videolan.VLC`) ship with Live555 enabled if you specifically want
   VLC; otherwise `ffplay` is the simplest tool-independent RTSP test.

3. **Branch on the generic-tool result.**

   - If `ffplay` shows video: the Herelink RTSP stream is reachable; QGC's
     side is the variable. Open Linux QGC →
     **Application Settings → General → Video** → set Source to **Herelink
     Hotspot** (the built-in preset QGC ships for CubePilot Herelink
     hotspot mode, verified-good 11/05/2026); restart QGC if needed.
   - If `ffplay` also fails: the stream is not being advertised to the
     laptop. On the Herelink controller, open Herelink Settings / Solex /
     Herelink Hub depending on firmware and enable **Video Sharing**,
     **RTSP Server**, **Forward video to GCS**, or the closest equivalent
     wording. Keep at least one GCS app running on the Herelink and make
     sure the correct HDMI/video stream is selected, then repeat the
     `ffplay` test.

4. **If video worked at campus before, run a controlled A/B retest.**

   Keep these fixed between locations:

   - Same Herelink air/ground units and camera input.
   - Same laptop, or test both laptops in the same order.
   - Same connection mode: USB tethering, Herelink hotspot, Wi-Fi, or Ethernet.
   - Same QGC/MP version and QGC video-source setting.
   - Same RTSP URL attempts.

   Capture this in both locations:

   ```bash
   ip route
   arp -a
   ffplay rtsp://<herelink-ip>:8554/fpv_stream
   ```

   If campus works but the lake fails with identical settings, the issue is
   likely link quality, RF environment, local network topology, or site-specific
   interference / range rather than QGC's general configuration. If both fail,
   focus on Herelink video-sharing state or the RTSP URL. If `ffplay` works in
   both but QGC fails in one, focus on QGC video-source settings and logs.

5. **When QGC video works, preserve the known-good config and capture the
   underlying URL** — both have to happen while still on the Herelink
   hotspot, because once the laptop switches to any other network the link
   to the camera / control box is gone (single-WiFi-adapter constraint):

   - Note the QGC video Source dropdown value (e.g. `Herelink Hotspot`).
     QGC stores it as `[Video] videoSource=...` in
     `~/.config/QGroundControl/QGroundControl.ini`.
   - Back up the config directory:

     ```bash
     cp -r ~/.config/QGroundControl/ ~/qgc_config_<YYYY-MM-DD>_<site>.bak/
     ```

   - Confirm the underlying RTSP URL independently with `ffplay` (recipe in
     step 2) — that's the value to record for tool-independent setup and for
     use in any non-QGC client (Linux MP, browser MJPEG wrappers, ROS 2
     bridges, etc.).

**Known Herelink detail**:
[CubePilot's Herelink video-sharing guide](https://docs.cubepilot.org/user-guides/herelink/herelink-user-guides/share-video-stream)
documents RTSP stream sharing on port `8554`, including
`rtsp://192.168.42.129:8554/fpv_stream` for USB tethering and
`rtsp://<Herelink Wi-Fi IP>:8554/fpv_stream` for Wi-Fi / hotspot sharing.
QGC's video source and URL/port fields are documented in
[Application Settings -> General -> Video](https://docs.qgroundcontrol.com/master/en/qgc-user-guide/settings_view/general.html#video).

**Do not chase first**:

- VA-API / `libva` decode warnings, unless the stream works in `ffplay` but
  QGC decode still fails.
- Offline map tiles, unless map background is the problem being debugged.
- `PhotoVideoControl.qml` null-camera errors before proving an RTSP stream
  exists.

---

### Mission Planner on Linux: libSkiaSharp DllNotFoundException

**Symptoms**:

- Mission Planner running under Mono on Linux connects fine via MAVLink
  (arm/disarm works) but pops a `Send Error` dialog with a stack trace
  ending in:

  ```text
  System.TypeInitializationException: The type initializer for 'SkiaSharp.SKObject' threw an exception.
  ---> System.DllNotFoundException: Unable to load library 'libSkiaSharp'.
      at SkiaSharp.SkiaApi.GetSymbol[T] (...)
      at SkiaSharp.SKObject..cctor ()
  ```

- Has been observed around the time video panel UI is exercised, but the
  stack trace alone only proves SkiaSharp's native init failed; the
  specific caller path isn't pinned by the trace.
- Linux QGC running on the same laptop against the same Herelink link
  displays the video stream when its video Source is set to "Herelink
  Hotspot" — the failure is GCS-runtime-side, not a Herelink / RTSP / video
  config issue.

**Interpretation**: SkiaSharp is a cross-platform 2D graphics library that
Mission Planner uses for several panel rendering paths. The native shared
library `libSkiaSharp.so` is not loadable in this Mono environment —
typically missing, ABI-incompatible with Mono, or unable to resolve its own
native dependencies. Same failure class as the 24/04/2026
`GDAL / OGR / OSR` gap already documented for MP-under-Mono on this
workstation.

**Status (11/05/2026)**: not chased. MP-Linux is treated as arm/disarm-only;
QGC on Linux handles video; Mission Planner on Windows (`.msi` install) is
the serious-MP fallback if the full feature surface is needed. Same posture
as the 24/04 GDAL decision.

**If a fix is needed later**:

1. Confirm the missing library — search narrow paths first before going
   wide:

   ```bash
   find ~/MissionPlanner /usr/lib /usr/local/lib ~/.nuget -name 'libSkiaSharp*' -print 2>/dev/null | head -20
   ldconfig -p | grep -i skiasharp
   ```

2. Inspect Mission Planner's install directory for a bundled SkiaSharp;
   check whether one exists, and whether it matches the Mono / .NET
   runtime / glibc ABI on this system.
3. Ubuntu does not currently package `libskiasharp` in the main
   repositories. Community fix paths include dropping a known-good
   `libSkiaSharp.so` in MP's install directory or a system library path —
   after verifying the binary source. Risk: similar Mono native-library
   gaps may surface next (same diagnosis as the 24/04 GDAL decision);
   chasing them individually has diminishing returns.

**Cross-references**: see "QGC / Mission Planner Can Arm via Herelink, but
Video Is Missing" above for the Herelink-side diagnostic recipe — that
diagnostic does **not** apply to this failure mode (this is
GCS-runtime-side, not link-side).

---

### Camera Stuck on "Connecting…" after Full Tab Close + Hard Refresh

**Symptoms**: Camera panel shows black + `Connecting to …` even after closing the dashboard tab entirely and reopening; other panels (Gazebo, RViz, nav stack) work normally.

**Root cause**: `web_video_server` (upstream) can deadlock under rapid MJPEG connection churn. CPU pegs near 100 %, port 8080 accepts TCP but returns no HTTP bytes. Most easily triggered by clicking "Refresh Stream" many times in quick succession.

**Diagnose**:

```bash
# Expect one row, <20 % CPU when healthy
ps aux | grep web_video_server | grep -v grep

# Expect HTTP 200 within 3 s
curl -I --max-time 3 http://localhost:8080/
```

If CPU is pegged or `curl` times out, the server is deadlocked.

**Fix**:

1. Kill the hung `web_video_server` process (it runs in one of the launcher's 6 terminal tabs — titled "camera"):

   ```bash
   # In the camera tab:
   Ctrl+C
   # If unresponsive:
   kill -9 <PID>   # from the ps aux output above
   ```

2. Restart it in the same tab:

   ```bash
   ros2 run web_video_server web_video_server
   ```

3. Hard-refresh the dashboard (`Ctrl+Shift+R`). Camera should flip from "Connecting…" to "Streaming | Flux en cours" within ~1 s.

Full sim restart via the launcher also works, but is overkill — only the camera server is affected.

**Prevention**: The dashboard has several layered defences (`web_dashboard/autoboat/app.js`):

- Same-topic Refresh is a no-op — clicking Refresh while already streaming the selected topic returns early with an `"Already streaming this topic"` toast instead of tearing down. Any click frequency is safe in this common case.
- Cross-topic Refresh (switching between e.g. `front_left` and `front_right`) is rate-limited by the unified `debounceGroup` at 2 s, plus a 500 ms browser TCP-close gap before the new connection opens.
- The camera-topic combobox auto-populates from `/rosapi/topics_for_type` for `sensor_msgs/Image`, so the typical switch-camera flow picks a valid image topic instead of causing a churn cycle against a misnamed one.

In practice the deadlock window has narrowed significantly since 23/04/2026 — still possible with sustained cross-topic hammering, not from repeated same-topic clicks.

---

### Dashboard Shows Old Data or Old Names After Pulling Updates

**Symptoms**: Dashboard not updating, stale information, old node names still showing, parameter changes not taking effect

**Solutions**:

1. **Hard-refresh the browser** (`Ctrl+Shift+R`) — Python's `http.server` doesn't set cache-control headers, so the browser may serve stale HTML/JS from cache
2. **Restart rosbridge** — rosbridge does not pick up topic/node changes without a restart
3. **After pulling code updates**, do a clean rebuild and relaunch:

   ```bash
   cd ~/seal_ws
   rm -rf build/ install/ log/
   colcon build --merge-install
   source install/setup.bash
   # Relaunch the full system (kills old nodes and starts fresh).
   # Append --use-nvidia on hybrid-graphics laptops — see "Gazebo Running Slow" below.
   bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_autoboat_complete.sh
   ```

   Then hard-refresh the dashboard (`Ctrl+Shift+R`). Running nodes keep old code in memory until restarted — `colcon build` alone does not update them.

4. **Check ROS topics publishing**:

   ```bash
   ros2 topic hz /planning/mission_status
   ```

---

### Map Not Showing Boat Position

**Symptoms**: Trajectory map empty or boat icon missing

**Causes**:

1. GPS not publishing
2. WebSocket not connected
3. Browser blocking Leaflet.js

**Solutions**:

1. Check GPS:

   ```bash
   ros2 topic echo /wamv/sensors/gps/gps/fix --once
   ```

2. Check browser console for JavaScript errors
3. Ensure internet connection (Leaflet loads tiles from online)

---

## Build & Compilation Issues

### Build Failures

**Symptoms**: `colcon build` fails with errors

**Solutions**:

1. **Clean build**:

   ```bash
   cd ~/seal_ws
   rm -rf build install log
   colcon build --merge-install
   ```

2. **Update dependencies**:

   ```bash
   rosdep update
   rosdep install --from-paths src --ignore-src -r -y
   ```

3. **Check Python version**:

   ```bash
   python3 --version  # Should be 3.10+
   ```

---

### `colcon build` Run From Wrong Directory (`src/src/` Path Errors)

**Symptoms**:

- Launcher prints paths like `/home/<user>/seal_ws/src/src/uvautoboat/...`
- `bash: cd: .../src/src/uvautoboat/web_dashboard/autoboat: No such file or directory`
- ROS 2 nodes abort at startup because `ros2 launch` can't find the launch YAML
- Dashboard HTTP server starts but `GET /` returns 404 (wrong docroot)
- **Early warning sign during `colcon build` itself**: the wrong-cwd build takes noticeably longer than a normal incremental build — colcon is doing a fresh cold compilation into an empty `install/` tree instead of reusing the cached artefacts from your usual `~/seal_ws/install/`. If your day-to-day incremental builds finish in seconds and this one is grinding on for minutes, interrupt it and check your cwd before it finishes laying down the spurious nested workspace.

**Cause**: `colcon build` was run from **inside `~/seal_ws/src/`** instead of from the workspace root `~/seal_ws/`. This creates a *nested, spurious* workspace at `~/seal_ws/src/build/`, `~/seal_ws/src/install/`, and `~/seal_ws/src/log/`. The one-click launcher's `WS_ROOT` auto-detection walks upward from the script location looking for `install/setup.bash` and finds the spurious `src/install/` first (it's one directory closer). Every subsequent `$WS_ROOT/src/uvautoboat/...` path then resolves to `src/src/uvautoboat/...` which does not exist.

**Diagnosis**:

```bash
# The legit workspace has install/build/log ONLY at the root.
ls -la ~/seal_ws/install/setup.bash    # Should exist (this is correct)
ls -la ~/seal_ws/src/install/setup.bash  # Should NOT exist
```

If `~/seal_ws/src/install/` exists, that is the smoking gun.

**Solution**:

1. **Delete the spurious nested workspace**:

   ```bash
   rm -rf ~/seal_ws/src/build ~/seal_ws/src/install ~/seal_ws/src/log
   ```

2. **Rebuild from the correct cwd** (the workspace root, the one containing `src/`):

   ```bash
   cd ~/seal_ws
   colcon build --merge-install
   ```

3. **Relaunch** the one-click launcher. Paths should now resolve cleanly.

**Prevention**: Always `cd ~/seal_ws` before running `colcon build`. Never run it from inside `src/` or from a package subdirectory — colcon will happily create a fresh workspace wherever you invoke it.

---

### Missing Package Errors

**Symptoms**: `ModuleNotFoundError` or `No module named 'X'`

**Solutions**:

1. **Install Python packages** (skip if your workspace Python is managed via conda — `pip3` into the system Python can shadow conda packages and create hard-to-debug import races):

   ```bash
   pip3 install numpy matplotlib
   ```

2. **Source ROS 2 environment**:

   ```bash
   source /opt/ros/jazzy/setup.bash
   source ~/seal_ws/install/setup.bash
   ```

---

### Gazebo Plugin Errors

**Symptoms**: Gazebo fails to load plugins or world

**Solutions**:

1. **Source ROS 2 environment** (Gazebo Harmonic ships its env variables through `ros_gz` and the ROS 2 workspace overlay — no separate gazebo setup script):

   ```bash
   source /opt/ros/jazzy/setup.bash
   source ~/seal_ws/install/setup.bash
   ```

2. **Check plugin paths**:

   ```bash
   echo $GZ_SIM_RESOURCE_PATH
   ```

3. **Rebuild workspace**:

   ```bash
   colcon build --packages-select vrx_gz --merge-install
   ```

---

## Performance Issues

### Gazebo Running Slow

**Symptoms**: low FPS, simulation stuttering, `/clock` running well under 250 Hz, sensor topics throttled (e.g. LiDAR `/wamv/sensors/lidars/lidar_wamv_sensor/points` ≈ 2 Hz instead of 10 Hz nominal).

**Diagnose first** — measure the rates and decide which throttle to chase:

```bash
ros2 topic hz /clock                                          # divide by 250 → RTF (1.0 = real time)
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points   # nominal 10 Hz
```

If LiDAR rate is throttled *more* than overall RTF, the GPU-bound `gpu_ray` raycasting is the dominant factor — continue with the GL-provider check below. If RTF is healthy but only LiDAR is slow, jump to "Other fallbacks" (sensor resolution).

#### 1. Hybrid-graphics laptop: discrete GPU not active

Common on Optimus / PRIME-managed dev laptops with both Intel iGPU and NVIDIA dGPU. With `prime-select on-demand` (Ubuntu's default), apps run on the iGPU unless they explicitly request offload. Gazebo's `gpu_ray` LiDAR plugin is GPU-bound — iGPU dramatically throttles it. Pi 5 deployments are unaffected (no discrete GPU; the section below is laptop-only).

Confirm the active GL provider:

```bash
glxinfo | grep -E '^OpenGL (vendor|renderer|version)'
prime-select query
```

If `OpenGL vendor string: Intel` (or any Mesa renderer) appears while `nvidia-smi` shows the discrete card with a loaded driver, Gazebo is on the iGPU.

**Fix — launcher prime-offload flag (recommended; no sudo, reversible):**

```bash
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
```

The flag exports the required prime-offload variables before spawning the launcher tabs, so the environment propagates through the launcher's `gnome-terminal --tab -- bash -i -c "..."` chain.

Manual equivalent for older checkouts or one-off `ros2 launch` tests:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia \
    bash one_click_launch_all/launch_autoboat_complete.sh
```

Verify after the success header with `nvidia-smi pmon -c 1` — `gz sim server` and `gz sim gui` should both appear on GPU 0.

Observed on the campus workstation (RTX A3000 Laptop GPU, driver 580.142, Sydney Regatta default world, 04/05/2026):

| Configuration | `/points` Hz | `/clock` Hz | RTF |
|:--|:-:|:-:|:-:|
| Mesa Intel UHD (default) | 2.48 | 80.9 | 0.32 |
| NVIDIA RTX A3000 (prime-offload) | 6.8 | 219.7 | 0.88 |

System-wide alternative: `sudo prime-select nvidia` then logout / login (always-on dGPU; trades battery life for consistent RTF).

#### 2. CPU frequency governor

If the GL provider is already NVIDIA but RTF is still below ~0.95, check the CPU governor:

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

If `powersave`, switch all cores to `performance`:

```bash
sudo cpupower frequency-set -g performance
```

Reverts on reboot unless persisted (`/etc/default/cpufrequtils` or a systemd unit). Worth ~10–15 % RTF on the campus workstation when stacked on top of the GL fix.

#### 3. Other fallbacks

1. Close other GPU/CPU-heavy apps (browsers with hardware acceleration, IDEs with code-intel)
2. Reduce sensor resolution (advanced): edit LiDAR parameters in URDF/XACRO, lower point-cloud density
3. Run headless:

   ```bash
   ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT gui:=false
   ```

4. Accept the degraded baseline and multiply timing budgets by `1 / RTF` for reasoning

---

### High CPU Usage

**Symptoms**: 100% CPU utilization

**Causes**: Normal for Gazebo + navigation nodes

**Solutions**:

1. **Monitor specific nodes**:

   ```bash
   top -p $(pgrep -d, gz)
   ```

2. **Reduce LIDAR processing**:
   - Increase `min_range` (process fewer points)
   - Reduce temporal history size

---

## A\* Path Planning Issues

### A\* Not Finding Paths

**Symptoms**: "No path found" errors, waypoint skip

**Causes**:

1. Safety margin too large
2. Grid resolution too coarse
3. Max expansions too low

**Solutions**:

1. Reduce safety margin:

   ```bash
   ros2 topic pub /planning/set_config std_msgs/String \
     "data: '{\"astar_safety_margin\": 8.0}'" --once
   ```

2. Decrease grid resolution (more precise):

   ```bash
   ros2 topic pub /planning/set_config std_msgs/String \
     "data: '{\"astar_resolution\": 2.0}'" --once
   ```

3. Increase max expansions:

   ```bash
   ros2 topic pub /planning/set_config std_msgs/String \
     "data: '{\"astar_max_expansions\": 50000}'" --once
   ```

---

### A\* Planning Too Slow

**Symptoms**: Long delays before boat moves

**Cause**: Grid too fine or search space too large

**Solutions**:

1. Increase grid resolution (coarser, faster):

   ```yaml
   astar_resolution: 5.0  # Increase from 3.0
   ```

2. Reduce max expansions:

   ```yaml
   astar_max_expansions: 10000  # Reduce from 20000
   ```

3. Disable hybrid mode (only use runtime A\*):

   ```bash
   ros2 topic pub /planning/set_config std_msgs/String \
     "data: '{\"astar_hybrid_mode\": false}'" --once
   ```

---

## System-Level Issues

### "use_sim_time" Warnings

**Symptoms**: Time-synchronization warnings at startup

**Cause**: One node is on simulation time while another is on wall clock, so the time-source heuristic flags a mismatch. `launch/autoboat.launch.yaml` does NOT currently set `use_sim_time`; all three pipeline nodes default to wall time, and the one-click launcher inherits that default. If you need simulation-clock synchronization (typically when comparing logs against Gazebo's `/clock`), pass the override consistently to every node — e.g.:

```bash
ros2 run plan waypoint_planner_node --ros-args -p use_sim_time:=true
```

---

### Nodes Crashing on Start

**Symptoms**: Node starts then immediately exits

**Diagnosis**:

```bash
# Check the specific node that crashed — pick whichever matches your symptom
ros2 run plan waypoint_planner_node --ros-args --log-level debug
ros2 run plan lidar_perception_node --ros-args --log-level debug
ros2 run control heading_controller --ros-args --log-level debug
```

**Solutions**:

1. **Check dependencies installed**
2. **Source workspace**:

   ```bash
   source ~/seal_ws/install/setup.bash
   ```

3. **Verify Gazebo running** before starting navigation

---

### `ros2 node list` Empty / Health Check "Cannot Reach ROS 2 Graph"

**Symptoms**:

- `ros2 node list` in a side terminal returns empty.
- The dashboard's Health Check panel aborts with `[FAIL] Cannot reach ROS 2 graph — is the simulation running?`.
- **But** the boat actively responds to commands from the dashboard, so the ROS 2 graph is genuinely alive — only the CLI view is blind.

**Root cause**: the local per-user `ros2 daemon` cache has gone stale. Any CLI call that queries the daemon (including the Health Check subprocess) returns an empty graph until the daemon is restarted.

**Diagnosis** (rule out env-var mismatch first):

```bash
# Env of a running launcher-spawned node:
cat /proc/$(pgrep -f lidar_perception_node | head -1)/environ 2>/dev/null | tr '\0' '\n' | grep -E '^(ROS|RMW|FASTRTPS)' | sort

# Env of your current shell:
env | grep -E '^(ROS|RMW|FASTRTPS)' | sort
```

If the two outputs match (`ROS_DOMAIN_ID`, `ROS_AUTOMATIC_DISCOVERY_RANGE`, etc.), the shell is correctly configured and the daemon is the culprit.

**Solution**:

```bash
ros2 daemon stop
ros2 daemon start
ros2 node list
```

After the restart, both the side CLI and the dashboard Health Check panel see the full graph again.

**Alternative one-shot check** (bypasses the daemon entirely):

```bash
ros2 node list --no-daemon
```

Returns a direct-discovery snapshot without the daemon cache. Typically a smaller set than the daemon's accumulated view, but useful to confirm nodes are actually alive when you suspect the daemon is the problem.

---

### Cannot Kill Processes

**Symptoms**: `Ctrl+C` doesn't stop nodes

**Nuclear Option**:

```bash
# Kill all Gazebo
pkill -9 -f "gz sim" && pkill -9 -f "gzserver" && pkill -9 -f "gzclient"

# Kill the three pipeline nodes + CLI + rosbridge
pkill -9 -f "heading_controller|lidar_perception|waypoint_planner|autoboat_cli|rosbridge"

# Kill everything (last resort)
pkill -9 -f ros && pkill -9 -f gz && pkill -9 -f gazebo
```

---

## Debug Commands

Useful commands for diagnosing issues:

### Check Node Status

```bash
ros2 node list
ros2 node info /heading_controller_node
```

### Check Topics

```bash
ros2 topic list
ros2 topic hz /wamv/sensors/gps/gps/fix
ros2 topic echo /perception/obstacle_info
```

### QoS-Aware Rate Probing (BEST_EFFORT publishers)

`ros2 topic hz` in Jazzy has no `--qos-*` flag — its subscription is always RELIABLE. Against a BEST_EFFORT publisher the QoS is incompatible and the probe silently returns 0 Hz / misleadingly low rates with no obvious error. (`ros2 topic echo` *does* accept `--qos-reliability`, but that only helps for content inspection, not rate.)

The current stack publishes all commonly-inspected topics RELIABLE — confirm via `ros2 topic info --verbose <topic>` (look for `Reliability: RELIABLE`). If a future change introduces a BEST_EFFORT publisher (e.g. a `ros_gz_bridge` config using `sensor_data` QoS, or a MAVLink bridge on the Pi 5), use the bundled probe:

```bash
python3 tools/rate_probe.py --topic /some/best_effort_topic \
    --reliability best_effort --duration 20
```

`tools/rate_probe.py` is a standalone rclpy script — no colcon build needed. Also accepts `--reliability reliable`, configurable `--depth` and `--duration`. Discovers the message type via rclpy introspection unless `--type pkg/msg/Name` is supplied.

### Check Parameters

```bash
ros2 param list /heading_controller_node
ros2 param get /heading_controller_node kp
```

### Check Pose (TF tree is not used)

This project does **not** use `/tf` — each of the three pipeline nodes does its own GPS → local conversion in Python. `ros2 run tf2_tools view_frames` returns an empty tree. To inspect pose, subscribe directly to the raw sensors:

```bash
ros2 topic echo /wamv/sensors/gps/gps/fix --once
ros2 topic echo /wamv/sensors/imu/imu/data --once
```

### Monitor System Resources

```bash
htop
nvidia-smi  # If using GPU
```

### Per-tab Launcher Logs (Post-Mortem)

Each tab spawned by `launch_autoboat_complete.sh` tees its combined stdout/stderr to `/tmp/autoboat_tab_<name>.log` — one file per tab (`gazebo`, `rosbridge`, `navigation`, `camera`, `rviz`, `dashboard`). Use these when a warning or error scrolled off-screen, or fired in a tab you weren't watching live:

```bash
# Fish for warnings across all tabs at once:
grep -iE 'warn|error|fail|deprecat' /tmp/autoboat_tab_*.log

# View one tab with ANSI colors preserved:
less -R /tmp/autoboat_tab_navigation.log
```

`tee` truncates each log on launch, and the launcher wipes `/tmp/autoboat_tab_*.log` at startup, so each session begins with a fresh log set. Files live in `/tmp` (tmpfs / RAM on most systems) and clear on reboot — no manual cleanup needed for the normal launch → stop → relaunch cycle.

---

### Known Startup Warnings (Cosmetic)

A handful of `WARN` / `Warning` / `(deprecated)` lines surface in `/tmp/autoboat_tab_gazebo.log` on every cold launch. They originate from upstream components (Gazebo Harmonic, NVIDIA/Mesa EGL, ROS 2 `kdl_parser`, VRX SDF), not from `uvautoboat` code, and do not affect simulation behaviour.

| Warning fragment | Origin | Why cosmetic |
|:-----------------|:-------|:-------------|
| `kdl_parser ... root link wamv/base_link has an inertia` | ROS 2 `kdl_parser` against VRX's WAM-V URDF | KDL silently ignores the inertia (the message itself says so); URDF is upstream |
| `libEGL ... driver (null)` / `failed to create dri2 screen` | NVIDIA/Mesa EGL probing during Gazebo GUI startup | Gazebo tries the legacy DRI2 path and falls back to a working backend; rendering proceeds normally |
| `[GUI] [Msg] Follow service on [/gui/follow] (deprecated)` (×2) | Gazebo Harmonic announcing deprecated GUI service paths | New service paths run in parallel; follow-camera works |
| `Utils.cc:132 ... vrx::WaveVisual ... XML Element[plugin] ... Copying[plugin]` | SDF parser strictness vs. VRX's wave-visual plugin nesting | Parser repositions the element under `<sdf>` and proceeds; wave visual renders |

**Cleaner grep going forward**:

```bash
grep -iE 'warn|error|fail|deprecat' /tmp/autoboat_tab_*.log | \
  grep -vE 'kdl_parser|libEGL|gui/follow.*deprecated|vrx::WaveVisual'
```

Empty output = clean run. Anything that survives the filter is from project code or a new upstream warning worth investigating.

---

### Pre-`62636e9` cold-launch Apport popup (resolved 29/04/2026)

If you see an Ubuntu Apport "internal error" dialog on a fresh boot — naming `/opt/ros/jazzy/bin/ros2` and showing a `BrokenPipeError` traceback in `ros2topic/verb/info.py` — your launcher script is from before commit `62636e9`. Pull `main` and the popup stops on the next cold launch.

The launcher itself was always unaffected. `set -e` without `pipefail` masked the pipeline's exit status, so `wait_for_topic` returned 0 and the launch sequence proceeded as expected; the popup was a cosmetic side effect of `ros2 topic info` being SIGPIPEd by the original `| grep -q` pipeline. See `wiki/Design_Rationale.md` § "Why `wait_for_topic` captures `ros2 topic info` output before grepping" for the full mechanism + design rationale.

---

## Still Having Issues?

If your problem isn't listed here:

1. **Check logs**: Look for ERROR or WARN messages
2. **Enable debug logging** — run the specific node manually rather than via the launcher:

   ```bash
   ros2 run plan waypoint_planner_node --ros-args --log-level debug
   ros2 run plan lidar_perception_node --ros-args --log-level debug
   ros2 run control heading_controller --ros-args --log-level debug
   ```

3. **Report issue**: [GitHub Issues](https://github.com/Ghostzero00018/uvautoboat/issues)
   - Include system info (Ubuntu version, ROS 2 version)
   - Paste relevant logs
   - Describe steps to reproduce

---

## Related Pages

- **[Installation Guide](Installation_Guide)** — Setup troubleshooting
- **[System Overview](System_Overview)** — Architecture, topic flow, node responsibilities
- **[Glossary](Glossary)** — Terminology (TUNED state, SASS, VFH, etc.)
