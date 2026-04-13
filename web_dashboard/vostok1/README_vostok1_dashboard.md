# Vostok1 Web Dashboard

Real-time web-based monitoring and control dashboard for the Vostok1 autonomous boat system.

## Features

- **Real-time GPS tracking** with trajectory visualization on interactive Leaflet map
- **Mission control**: Generate, Confirm, Start, Stop, Resume, Emergency Stop, Go Home, Reset
- **Three config panels**: Main Config (PID/speed/nav), OKO Perception, BURAN Controller
- **Dirty-params filtering**: Only user-modified parameters are sent on Apply
- **Apply buttons disabled** until first ROS config sync (prevents stale defaults)
- **Reset Defaults** buttons for OKO and BURAN (restores launch file values)
- **OKO presets**: Universal, Buoy Field, Pier Detect, Open Water
- **Health check panel** with live streaming output, elapsed time, and [DONE] completion
- **JSON export** on Health Check, System Logs, ROS2 Terminal, and Mission Control panels
- **Emergency stop** with red pulsing badge and thrust cut
- **Obstacle detection** with Front/Left/Right clearance, urgency scores, clusters, gaps
- **LiDAR smoke detection** display with H/V spread metrics
- **Anti-stuck status** with Kalman drift uncertainty indicator
- **Embedded camera feed** via web_video_server (MJPEG)
- **State badges** for: INIT, IDLE, WAITING_CONFIRM, WAYPOINTS_PREVIEW, READY, DRIVING, PAUSED, FINISHED, EMERGENCY_STOP, JOYSTICK

## Prerequisites

1. **ROS 2 Jazzy** installed and configured
2. **rosbridge-suite**:

   ```bash
   sudo apt install ros-jazzy-rosbridge-suite
   ```

3. **web_video_server** (camera panel):

   ```bash
   sudo apt install ros-jazzy-web-video-server
   ```

4. **Internet access** — the dashboard loads `roslib.js` and `leaflet.js` from CDNs
5. **Vostok1 nodes** running via `vostok1.launch.yaml`

## Quick Start

### Option A: One-Click Launch

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_vostok1_complete.sh
```

Then open **<http://localhost:8002>**.

### Option B: Manual Launch (5 Terminals)

| Terminal | Command                                                                                        | Purpose                       |
| -------- | ---------------------------------------------------------------------------------------------- | ----------------------------- |
| T1       | `ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT`                       | Gazebo simulation             |
| T2       | `ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0`      | WebSocket bridge (port 9090)  |
| T3       | `ros2 run web_video_server web_video_server`                                                   | Camera stream (port 8080)     |
| T4       | `ros2 launch ~/seal_ws/src/uvautoboat/launch/vostok1.launch.yaml`                             | Navigation system             |
| T5       | `cd ~/seal_ws/src/uvautoboat/web_dashboard/vostok1 && python3 -m http.server 8002`            | Dashboard (port 8002)         |

> **Important:** The `delay_between_messages:=0.0` parameter is required for ROS 2 Jazzy.
> Do NOT open `index.html` directly as a file (`file://`). Serve it via HTTP for WebSocket to work.

## Dashboard Panels

| Panel                      | Description                                                                      |
| -------------------------- | -------------------------------------------------------------------------------- |
| **Connection Status**      | WebSocket connection indicator (green/red)                                       |
| **GPS Position**           | Latitude, longitude, local X/Y coordinates                                      |
| **Mission Status**         | State badge, waypoint progress, distance, speed, time remaining                 |
| **Mission Control**        | Generate, Confirm, Start, Stop, Resume, Emergency Stop, Go Home, Reset          |
| **Obstacle Detection**     | Front/Left/Right clearance with urgency scores and status badge                 |
| **LiDAR Smoke Detection**  | Smoke status, distance, point count, H/V spread metrics                         |
| **Thruster Output**        | Left/Right thrust with visual bars                                              |
| **Anti-Stuck Status**      | Escape mode, direction (LEFT), front clearance, drift vector, Kalman sigma      |
| **Trajectory Map**         | Interactive Leaflet map with boat position, waypoints, trajectory               |
| **Main Configuration**     | PID gains, speed, safe distance, waypoint tolerance, A* settings                |
| **OKO Configuration**      | 17 perception params with 4 presets (Universal, Buoy Field, Pier, Open Water)   |
| **BURAN Configuration**    | 14 control params (safety distances, avoidance, anti-stuck, slew rate)          |
| **Health Check**           | Live streaming 45-check system diagnostic with elapsed time                     |
| **System Logs**            | Timestamped, color-coded log entries                                            |
| **ROS2 Terminal**          | Direct ROS2 command output                                                      |
| **Camera Feed**            | MJPEG stream with configurable topic                                            |

## Configuration System

### Three Separate Apply Buttons

Each section sends only its own parameters. With dirty-params filtering, only fields the user actually changed are sent:

| Button           | Parameters                                          | Target Nodes    |
| ---------------- | --------------------------------------------------- | --------------- |
| **Apply Config** | PID, speed, lanes, waypoint tolerance, A* settings  | SPUTNIK + BURAN |
| **Apply OKO**    | Height/range filters, clustering, temporal, smoke    | OKO             |
| **Apply BURAN**  | Safety distances, avoidance gains, anti-stuck, slew  | BURAN           |

All three publish to `/sputnik/set_config`. Each node picks out only the keys it recognizes.

### Safety Features

- **Apply buttons start disabled** — enabled only after first ROS config sync arrives
- **Dirty-params filtering** — only changed fields are sent (prevents overwriting unchanged params)
- **Reset Defaults** — restores launch file values and marks fields dirty (prevents ROS sync race)

### Parameter Sync (3 places)

Any parameter change must be mirrored in:

1. `vostok1.launch.yaml` — the authoritative operational values
2. `index.html` — input field default values
3. `app.js` — readInput fallbacks, currentState.config, OKO_DEFAULTS, BURAN_DEFAULTS

### Known Parameter Collisions (Resolved)

OKO and BURAN share the `/sputnik/set_config` topic. Parameters with the same name would collide:

| Parameter           | Resolution                               |
| ------------------- | ---------------------------------------- |
| `min_safe_distance` | OKO renamed to `oko_min_safe_distance`   |
| `critical_distance` | OKO renamed to `oko_critical_distance`   |

## Mission Workflow

1. Open dashboard, wait for **Connected** (green) and GPS coordinates
2. Set lanes/length/width in Route Configuration
3. Click **Generate Waypoints** — waypoints appear on map, state -> WAITING_CONFIRM
4. Click **Confirm Waypoints** — state -> READY
5. Click **Start Mission** — state -> DRIVING, boat navigates
6. Monitor: waypoint progress, obstacle clearance, trajectory on map

### Controls During Mission

| Button             | Action                                                          |
| ------------------ | --------------------------------------------------------------- |
| **Stop**           | Pause mission, zero thrust                                      |
| **Resume**         | Continue from current waypoint                                  |
| **Emergency Stop** | Cut thrust, latch stop (red pulsing badge). Resume to recover.  |
| **Go Home**        | Navigate back to spawn point                                    |
| **Reset**          | Clear waypoints, return to INIT                                 |

## ROS Topics

### Subscribed (Read)

| Topic                          | Data                                 |
| ------------------------------ | ------------------------------------ |
| `/wamv/sensors/gps/gps/fix`    | GPS position                         |
| `/planning/mission_status`     | State, waypoint, progress            |
| `/planning/waypoints`          | Waypoint list for map                |
| `/planning/current_target`     | Current navigation target            |
| `/perception/obstacle_info`    | OKO obstacle detection (JSON)        |
| `/perception/smoke_detected`   | LiDAR smoke detection (JSON)         |
| `/control/status`              | BURAN controller status              |
| `/control/anti_stuck_status`   | Anti-stuck escape status             |
| `/sputnik/config`              | Current config values (syncs fields) |
| `/wamv/thrusters/left/thrust`  | Left thruster command                |
| `/wamv/thrusters/right/thrust` | Right thruster command               |

### Published (Write)

| Topic                      | Data                                           |
| -------------------------- | ---------------------------------------------- |
| `/sputnik/set_config`      | Parameter updates (JSON)                       |
| `/sputnik/mission_command` | Mission commands (start, stop, generate, etc.) |

## Files

| File                          | Description                                |
| ----------------------------- | ------------------------------------------ |
| `index.html`                  | Dashboard structure, input fields, panels  |
| `app.js`                      | ROS connection, data handling, config logic |
| `style_merged.css`            | Unified stylesheet                         |
| `README_vostok1_dashboard.md` | This file                                  |

## Troubleshooting

| Problem                           | Solution                                                              |
| --------------------------------- | --------------------------------------------------------------------- |
| Dashboard shows "Disconnected"    | See diagnostic steps below                                            |
| Port 9090 in use                  | Kill old instance: `pkill -9 -f rosbridge`                            |
| Apply buttons stay grey           | Nodes not publishing `/sputnik/config` — check navigation is launched |
| Reset then Apply sends old values | Fixed — Reset now marks inputs dirty to prevent ROS sync race         |
| Camera feed not showing           | Check web_video_server: `ros2 run web_video_server web_video_server`  |
| Map tiles not loading             | Requires internet for OpenStreetMap CDN                               |
| ROSLIB not defined (console)      | Requires internet for CDN (roslibjs, Leaflet)                         |
| Half the page missing             | CDN failed — check internet; see browser console (F12)                |
| Parameter collision               | OKO params prefixed with `oko_` (e.g. `oko_critical_distance`)       |

### Dashboard "Disconnected" Diagnostics

Run these checks in order:

```bash
# 1. Is rosbridge listening?
ss -tuln | grep 9090
# Should show LISTEN. If empty → rosbridge not running.

# 2. Is ROS_DOMAIN_ID the same in every terminal?
echo $ROS_DOMAIN_ID
# Must match in ALL terminals. Mismatch = rosbridge can't see ROS topics.

# 3. Can rosbridge see the ROS topics?
ros2 topic list | grep planning
# Should show /planning/mission_status. If empty → domain mismatch or nodes crashed.

# 4. Is the dashboard HTTP server running?
ss -tuln | grep 8002
# Should show LISTEN.

# 5. Check browser console (F12 → Console) for:
#    - "Failed to load resource: roslib.min.js" → no internet
#    - "WebSocket connection failed" → rosbridge not running or port blocked

# 6. Firewall?
sudo ufw status
# If active: sudo ufw allow 9090/tcp && sudo ufw allow 8002/tcp && sudo ufw allow 8080/tcp
```

## License

Part of the uvautoboat project — Apache License 2.0.

Built with [roslibjs](http://robotwebtools.org/), [Leaflet.js](https://leafletjs.com/), [OpenStreetMap](https://www.openstreetmap.org/).

Last updated: 13-04-2026
