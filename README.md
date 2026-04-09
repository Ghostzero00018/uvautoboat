# AutoBoat — Autonomous Navigation for Unmanned Surface Vehicles

![AutoBoat Banner](images/logo_autoboat_v2.svg)
[![ROS 2](https://img.shields.io/badge/ROS_2-Jazzy-blue)](https://docs.ros.org/en/jazzy/)
[![Gazebo](https://img.shields.io/badge/Gazebo-Harmonic-orange)](https://gazebosim.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

> **PROJET-17** — Autonomous navigation for the Virtual RobotX (VRX) course.
> GPS waypoint navigation with 3D LiDAR obstacle avoidance on the WAM-V platform.

---

## Architecture

The system uses three distributed ROS 2 nodes (Russian space program theme):

| Node | Role | Description |
| ------ | ------ | ------------- |
| **OKO** | Perception | 3D LiDAR obstacle detection, smoke filtering, clustering |
| **SPUTNIK** | Planning | Waypoint generation, A* detour planning, mission management |
| **BURAN** | Control | PID steering, obstacle avoidance, anti-stuck recovery |

```text
GPS/IMU ──> SPUTNIK (planner) ──> waypoints/targets ──> BURAN (controller) ──> thrusters
                 ^                                            ^
                 |                                            |
            OKO (LiDAR perception) ───────────────────────────┘
```

---

## Requirements

| Component | Version |
| ----------- | --------- |
| Ubuntu | 24.04 LTS |
| ROS 2 | Jazzy |
| Gazebo | Harmonic |
| Python | 3.10+ |

---

## Installation

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

# 4. (Recommended) Auto-source on new terminals
echo "source ~/seal_ws/install/setup.bash" >> ~/.bashrc
```

---

## Quick Start

### Option A: One-Click Launch (recommended)

Launches everything (Gazebo + navigation + dashboard) in one command:

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/launch_vostok1_complete.sh
```

Then open **<http://localhost:8002>** for the web dashboard.

### Option B: Manual Launch (5 terminals)

| Terminal | Command | Purpose |
| ---------- | --------- | --------- |
| T1 | `ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT` | Gazebo simulation |
| T2 | `ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0` | WebSocket bridge |
| T3 | `ros2 run web_video_server web_video_server` | Camera stream (port 8080) |
| T4 | `ros2 launch ~/seal_ws/src/uvautoboat/launch/vostok1.launch.yaml` | Navigation system |
| T5 | `cd ~/seal_ws/src/uvautoboat/web_dashboard/vostok1 && python3 -m http.server 8002` | Dashboard |

### Running a Mission

1. Open **<http://localhost:8002>**
2. Wait for GPS Ready indicator
3. Set lanes/length/width in Route Configuration
4. Click **Generate Waypoints**
5. Click **Confirm Waypoints**
6. Click **Start Mission**

Other controls: **Stop**, **Resume**, **Go Home** (return to spawn), **Reset** (clear and start over).

---

## Health Check

```bash
bash ~/seal_ws/src/uvautoboat/one_click_launch_all/health_check_vostok1.sh
```

Runs 45 checks (nodes, topics, parameters, connectivity). Auto-detects IDLE/ACTIVE state.

---

## CLI Mission Control

```bash
ros2 run plan vostok1_cli generate --lanes 10 --length 50 --width 20
ros2 run plan vostok1_cli confirm
ros2 run plan vostok1_cli start
ros2 run plan vostok1_cli status
ros2 run plan vostok1_cli home      # Return to spawn
ros2 run plan vostok1_cli reset     # Clear and reset
```

Interactive mode: `ros2 run plan vostok1_cli interactive`

---

## Keyboard Teleop

Manual control for testing:

```bash
ros2 run control keyboard_teleop
```

`W`/`S` = throttle up/down, `A`/`D` = steer, `Space` = all stop, `H` = help.

---

## Key Parameters

Configured in `launch/vostok1.launch.yaml` or via the web dashboard:

| Parameter | Default | Description |
| ----------- | --------- | ------------- |
| `base_speed` | 400 | Cruising thrust (N) |
| `kp` / `ki` / `kd` | 500 / 20 / 150 | PID heading gains |
| `scan_length` / `scan_width` | 15m / 30m | Lawnmower pattern size |
| `lanes` | 10 | Number of coverage lanes |
| `waypoint_tolerance` | 3.5m | Arrival radius |
| `max_avoidance_turn_deg` | 45.0 | Max obstacle avoidance turn angle |
| `critical_distance` | 6.0m | Emergency stop distance (BURAN) |
| `min_safe_distance` | 12.0m | Start slowing distance (BURAN) |

---

## Project Structure

```text
uvautoboat/
├── control/                    # BURAN controller + keyboard teleop
├── plan/                       # OKO perception + SPUTNIK planner + CLI
├── launch/                     # vostok1.launch.yaml
├── web_dashboard/vostok1/      # Web dashboard (HTML/JS/CSS)
├── one_click_launch_all/       # Launch script + health check
├── test_environment/           # Gazebo worlds and models
├── wiki/                       # Wiki documentation
├── working_diary/              # Daily development logs
├── legacy/                     # Deprecated code (Atlantis, robust_avoidance)
└── USER_MANUAL.md              # Detailed technical manual
```

---

## Documentation

| Document | Description |
| ---------- | ------------- |
| [USER_MANUAL.md](USER_MANUAL.md) | Full technical manual (architecture, algorithms, troubleshooting) |
| [Dashboard Guide](web_dashboard/vostok1/README_vostok1_dashboard.md) | Dashboard setup and camera panel |
| [Board.md](Board.md) | Development milestones |
| [Wiki](wiki/Home.md) | Installation, system overview, common issues |

---

## Troubleshooting

| Problem | Solution |
| --------- | ---------- |
| Boat not moving | Check GPS: `ros2 topic echo /wamv/sensors/gps/gps/fix --once` |
| Spinning in circles | Reduce Kp: `ros2 param set /buran_controller_node kp 300` |
| Dashboard disconnected | Restart rosbridge, check port 9090 |
| No obstacles detected | Check LiDAR: `ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points` |
| Build failures | Clean: `rm -rf build install log && colcon build --merge-install` |

---

## Contributors

**Current maintainers:**

- [Ghostzero00018](https://github.com/Ghostzero00018)
- [atshehu1776](https://github.com/atshehu1776)

**Previous contributors:**

- [Erk732](https://github.com/Erk732)
- [Ghostzero00018](https://github.com/Ghostzero00018)
- [ITSHT](https://github.com/ITSHT)
- [YinLi-Y2Y2](https://github.com/YinLi-Y2Y2)
- [zhiyanPiao-Y2Y2](https://github.com/zhiyanPiao-Y2Y2)
- [guillaumeLozenguez](https://github.com/guillaumeLozenguez)
- [atshehu1776](https://github.com/atshehu1776)

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).

**AutoBoat** — IMT Nord Europe, PROJET-17

[Report Bug](https://github.com/Ghostzero00018/uvautoboat/issues) · [Full Manual](USER_MANUAL.md)
