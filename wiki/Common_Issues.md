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

1. **GPS not initialized**: Wait 5-10 seconds after Gazebo launches
2. **Mission not started**: Run `ros2 run plan autoboat_cli start`
3. **Waypoints not generated**: Run `ros2 run plan autoboat_cli generate`
4. **Node not running**: Check `ros2 node list | grep autoboat`

---

### Boat Spinning in Circles

**Symptoms**: Boat rotates continuously without making progress

**Cause**: PID gains too high (over-responsive)

**Solution**: Reduce PID proportional gain

```bash
# For AutoBoat
ros2 param set /heading_controller_node kp 300.0

# For Modular (Controller)
ros2 param set /heading_controller kp 300.0
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
  value: 7.0  # Increase from default 5.0
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

1. Increase timeout:

   ```bash
   ros2 param set /heading_controller stuck_timeout 5.0
   ```

2. Increase movement threshold:

   ```bash
   ros2 param set /heading_controller stuck_threshold 1.0
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
# Check LIDAR data rate
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points

# Check obstacle info
ros2 topic echo /perception/obstacle_info
```

**Solutions**:

1. **LIDAR not publishing**: Restart Gazebo
2. **Height filter too restrictive**: Adjust range

   ```yaml
   min_height: -20.0
   max_height: 15.0
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
| `Failed to load resource: roslib.min.js` | No internet — CDN dependency cannot load |
| `Failed to load resource: leaflet.js` | No internet — map library cannot load |
| `WebSocket connection to 'ws://localhost:9090' failed` | rosbridge not running or port blocked |

> **Internet required:** The dashboard loads `roslib.js` and `leaflet.js` from
> CDNs. Without internet, the page partially renders and ROS connection never initializes.

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
3. **Verify topic exists**:

   ```bash
   ros2 topic list | grep camera
   ```

4. **Refresh stream**: Click "Refresh Stream" button in dashboard

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
   # Relaunch the full system (kills old nodes and starts fresh)
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

1. **Install Python packages**:

   ```bash
   pip3 install numpy scipy matplotlib
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

1. **Source Gazebo setup**:

   ```bash
   source /usr/share/gazebo/setup.sh
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

**Symptoms**: Low FPS, stuttering simulation

**Solutions**:

1. **Reduce real-time factor**: Accept slower-than-real-time
2. **Close other applications**: Free up CPU/GPU
3. **Reduce sensor resolution** (advanced):
   - Edit LIDAR parameters in URDF/XACRO
   - Reduce point cloud density
4. **Disable GUI**:

   ```bash
   ros2 launch vrx_gz competition.launch.py world:=sydney_regatta gui:=false
   ```

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

## A* Path Planning Issues

### A* Not Finding Paths

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

### A* Planning Too Slow

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

3. Disable hybrid mode (only use runtime A*):

   ```bash
   ros2 topic pub /planning/set_config std_msgs/String \
     "data: '{\"astar_hybrid_mode\": false}'" --once
   ```

---

## System-Level Issues

### "use_sim_time" Warnings

**Symptoms**: TF warnings about time synchronization

**Solution**: Ensure all nodes use simulation time

```yaml
# In launch file
- name: use_sim_time
  value: true
```

**Note**: `launch/autoboat.launch.yaml` sets this for all active nodes in the modular pipeline.

---

### Nodes Crashing on Start

**Symptoms**: Node starts then immediately exits

**Diagnosis**:

```bash
# Check node logs
ros2 run plan autoboat --ros-args --log-level debug
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

# Kill ROS nodes
pkill -9 -f autoboat && pkill -9 -f rosbridge

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

### Check Parameters

```bash
ros2 param list /heading_controller_node
ros2 param get /heading_controller_node kp
```

### Check Transforms

```bash
ros2 run tf2_tools view_frames
evince frames.pdf
```

### Monitor System Resources

```bash
htop
nvidia-smi  # If using GPU
```

---

## Still Having Issues?

If your problem isn't listed here:

1. **Check logs**: Look for ERROR or WARN messages
2. **Enable debug logging**:

   ```bash
   ros2 run plan autoboat --ros-args --log-level debug
   ```

3. **Report issue**: [GitHub Issues](https://github.com/Ghostzero00018/uvautoboat/issues)
   - Include system info (Ubuntu version, ROS 2 version)
   - Paste relevant logs
   - Describe steps to reproduce

---

## Related Pages

- **[FAQ](FAQ)** — Frequently asked questions
- **[Debug Commands](Debug-Commands)** — Advanced diagnostic tools
- **[Configuration & Tuning](Configuration-and-Tuning)** — Parameter reference
- **[Installation Guide](Installation_Guide)** — Setup troubleshooting
