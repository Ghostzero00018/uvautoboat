# AutoBoat — Autonomous Navigation for Unmanned Surface Vehicles

![AutoBoat Banner](images/logo_autoboat_v2.svg)
[![ROS 2](https://img.shields.io/badge/ROS_2-Jazzy-blue)](https://docs.ros.org/en/jazzy/)
[![Gazebo](https://img.shields.io/badge/Gazebo-Harmonic-orange)](https://gazebosim.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

> Autonomous navigation research using the Virtual RobotX (VRX) simulation platform.
> GPS waypoint navigation with 3D LiDAR obstacle avoidance on the WAM-V platform.

---

## 🏗️ Architecture

The system is a modular 3-node ROS 2 pipeline:

| Node | Role | Description |
| ------ | ------ | ------------- |
| **Perception** | Perception | 3D LiDAR obstacle detection, temporal filtering, clustering |
| **Planner** | Planning | Lawnmower waypoint generation, A* detour planning, mission state machine |
| **Controller** | Control | PID heading control, reactive obstacle avoidance, anti-stuck recovery (needs testing) |

> **Note:** Earlier development used U.S.S.R space-program code-names (OKO, SPUTNIK, BURAN). See [Glossary — Legacy Code-Names](wiki/Glossary.md#legacy-module-code-names-pre-v30) for the mapping.

Supporting components:

| Component | Description |
| ------ | ------------- |
| **AutoBoat Dashboard** | Real-time web dashboard with map, config tuning, health check, and JSON export |
| **Waypoint Visualizer** | RViz marker publisher for waypoint and trajectory visualization |
| **Health Check Service** | ROS 2 node wrapping the system health check script with live streaming |
| **AutoBoat CLI** | Terminal-based mission control (fallback when dashboard is unavailable) |

```text
GPS/IMU ──> Planner ──> waypoints/targets ──> Controller ──> thrusters
                 ^                                            ^
                 |                                            |
            Perception (LiDAR) ───────────────────────────────┘
                                                              |
                                        AutoBoat Dashboard <──┘ (via rosbridge)
```

---

## 📋 Requirements

| Component | Version |
| ----------- | --------- |
| Ubuntu | 24.04 LTS |
| ROS 2 | Jazzy |
| Gazebo | Harmonic |
| Python | 3.10+ |

---

## 🔧 Installation

```bash
# 1. Create workspace and clone
mkdir -p ~/seal_ws/src && cd ~/seal_ws/src
git clone https://github.com/Ghostzero00018/uvautoboat.git
git clone https://github.com/osrf/vrx.git

# 2. Install dependencies
cd ~/seal_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
sudo apt install ros-jazzy-rosbridge-suite ros-jazzy-web-video-server

# 3. Build
colcon build --merge-install
source ~/seal_ws/install/setup.bash

# 4. Set up ~/.bashrc (add these lines to the end)
#    See USER_MANUAL.md > "Environment Setup" for full details
cat >> ~/.bashrc << 'EOF'
source /opt/ros/jazzy/setup.bash
source ~/seal_ws/install/setup.bash
export GZ_SIM_RESOURCE_PATH="$HOME/seal_ws/src/uvautoboat/test_environment:${GZ_SIM_RESOURCE_PATH}"
# export ROS_DOMAIN_ID=56  # Uncomment — all teammates must use the same value
EOF
source ~/.bashrc
```

---

## 🚀 Quick Start

### Option A: One-Click Launch (recommended)

Launches everything (Gazebo + navigation + dashboard) in one command:

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_autoboat_complete.sh
```

Then open **<http://localhost:8002>** for the web dashboard.

### Option B: Manual Launch (5 terminals)

| Terminal | Command | Purpose |
| ---------- | --------- | --------- |
| T1 | `ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT` | Gazebo simulation |
| T2 | `ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0` | WebSocket bridge |
| T3 | `ros2 run web_video_server web_video_server` | Camera stream (port 8080) |
| T4 | `ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml` | Navigation system |
| T5 | `cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat && python3 -m http.server 8002` | Dashboard |

### 🗺️ Running a Mission

1. Open **<http://localhost:8002>**
2. Wait for GPS Ready indicator
3. Set lanes/length/width in Route Configuration
4. Click **Generate Waypoints**
5. Click **Confirm Waypoints**
6. Click **Start Mission**

Other controls: **Stop**, **Resume**, **Emergency Stop**, **Go Home** (return to spawn), **Reset** (clear and start over).

---

## 🩺 Health Check

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/health_check_autoboat.sh
```

Runs 46 checks (nodes, topics, parameters, connectivity). Parameter values are reported as `PASS` (matches YAML baseline) or `TUNED` (user-applied via preset/dashboard — counted as healthy); `WARN` means unexpected drift, `FAIL` means unreadable. Auto-detects IDLE/ACTIVE state. Also available from the dashboard Health Check panel with live-streaming output.

---

## 💻 CLI Mission Control

```bash
ros2 run plan autoboat_cli generate --lanes 10 --length 50 --width 20
ros2 run plan autoboat_cli confirm
ros2 run plan autoboat_cli start
ros2 run plan autoboat_cli status
ros2 run plan autoboat_cli emergency   # Emergency stop
ros2 run plan autoboat_cli home        # Return to spawn
ros2 run plan autoboat_cli reset       # Clear and reset
```

Interactive mode: `ros2 run plan autoboat_cli interactive`

---

## 🎮 Keyboard Teleop

Manual control for testing:

```bash
ros2 run control keyboard_teleop
```

`W`/`S` = throttle up/down, `A`/`D` = steer, `Space` = all stop, `X` = emergency reverse, `H` = help.

---

## ⚙️ Key Parameters

Configured in `launch/autoboat.launch.yaml` or via the web dashboard:

| Parameter | Default | Description |
| ----------- | --------- | ------------- |
| `base_speed` | 400 | Cruising thrust (N) |
| `kp` / `ki` / `kd` | 500 / 20 / 150 | PID heading gains |
| `scan_length` / `scan_width` | 15m / 30m | Lawnmower pattern size |
| `lanes` | 10 | Number of coverage lanes |
| `waypoint_tolerance` | 3.5m | Arrival radius |
| `max_avoidance_turn_deg` | 45.0 | Max obstacle avoidance turn angle |
| `critical_distance` | 6.0m | Emergency stop distance (Controller) |
| `perception_critical_distance` | 5.5m | Emergency stop distance (Perception) |
| `min_safe_distance` | 12.0m | Start avoidance distance (Controller) |
| `perception_min_safe_distance` | 10.0m | Obstacle detection threshold (Perception) |

---

## 📂 Project Structure

```text
uvautoboat/
├── control/                    # Heading controller + keyboard teleop
├── plan/                       # LiDAR perception + waypoint planner + CLI + health check service
├── launch/                     # autoboat.launch.yaml
├── web_dashboard/autoboat/      # Web dashboard (HTML/JS/CSS)
├── one_click_launch_all/       # Launch script + health check + VRX patch
├── test_environment/           # Gazebo worlds and models
├── wiki/                       # Wiki documentation
├── working_diary/              # Daily development logs
├── legacy/                     # Deprecated code (see legacy/DEPRECATED.md)
└── USER_MANUAL.md              # Detailed technical manual
```

---

## 📚 Documentation

| Document | Description |
| ---------- | ------------- |
| [USER_MANUAL.md](USER_MANUAL.md) | Full technical manual (architecture, algorithms, troubleshooting) |
| [Dashboard Guide](web_dashboard/autoboat/README_autoboat_dashboard.md) | Dashboard setup and camera panel |
| [Board.md](Board.md) | Development milestones |
| [Wiki](wiki/Home.md) | Installation, system overview, common issues |
| [Glossary](wiki/Glossary.md) | Plain-language definitions of every technical term |
| [Design Rationale](wiki/Design_Rationale.md) | Why these architecture, algorithm, and parameter choices were made |
| [DEPRECATED.md](legacy/DEPRECATED.md) | Legacy code inventory |

---

## 🔍 Troubleshooting

| Problem | Solution |
| --------- | ---------- |
| Boat not moving | Check GPS: `ros2 topic echo /wamv/sensors/gps/gps/fix --once` |
| Spinning in circles | Reduce Kp: `ros2 param set /heading_controller_node kp 300` |
| Dashboard disconnected | Restart rosbridge, check port 9090 |
| No obstacles detected | Check LiDAR: `ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points` |
| LiDAR at world origin | Run `bash one_click_launch_all/patch_vrx.sh` (VRX issue #876) |
| Build failures | Clean: `rm -rf build install log && colcon build --merge-install` |
| Dashboard stale after update | Clean build + relaunch + hard-refresh browser (`Ctrl+Shift+R`) |
| Health check false FAILs | DDS discovery lag — wait 5s and re-run |

---

## 📊 What Works / What's In Progress

| Feature | Status |
| --------- | ---------- |
| GPS waypoint navigation (lawnmower pattern) | ✅ Working |
| 3D LiDAR obstacle detection (Perception) | ✅ Working |
| PID heading control (Controller) | ✅ Working |
| Anti-stuck recovery (SASS) | ✅ Working |
| A* detour planning | ✅ Working |
| Web dashboard with live map | ✅ Working |
| Health check (46 checks) | ✅ Working |
| CLI mission control | 🧪 Needs testing |
| Emergency stop (dashboard + CLI) | ✅ Working |
| JSON log export | ✅ Working |
| VRX LiDAR patch (issue #876) | ✅ Workaround |
| Obstacle avoidance (detour explosion fix) | 🔧 Planned |
| VFH steering bias | 🔧 Planned |
| Pier/low-obstacle avoidance tuning | 🔧 Planned |

---

## 👥 Contributors

**Current maintainers:**

- [Ghostzero00018](https://github.com/Ghostzero00018)
- [atshehu1776](https://github.com/atshehu1776)
- [Umaralfa-coder](https://github.com/Umaralfa-coder)

**Previous contributors:**

- [Erk732](https://github.com/Erk732)
- [Ghostzero00018](https://github.com/Ghostzero00018)
- [atshehu1776](https://github.com/atshehu1776)
- [ITSHT](https://github.com/ITSHT)
- [YinLi-Y2Y2](https://github.com/YinLi-Y2Y2)
- [zhiyanPiao-Y2Y2](https://github.com/zhiyanPiao-Y2Y2)
- [guillaumeLozenguez](https://github.com/guillaumeLozenguez)

---

## 📜 License

Apache License 2.0 — see [LICENSE](LICENSE).

**AutoBoat** — IMT Nord Europe research project

[Report Bug](https://github.com/Ghostzero00018/uvautoboat/issues) · [Full Manual](USER_MANUAL.md)
