# AutoBoat — Autonomous Navigation for Unmanned Surface Vehicles

![AutoBoat Banner](images/logo_autoboat_v2.svg)
[![ROS 2](https://img.shields.io/badge/ROS_2-Jazzy-blue)](https://docs.ros.org/en/jazzy/)
[![Gazebo](https://img.shields.io/badge/Gazebo-Harmonic-orange)](https://gazebosim.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Status](https://img.shields.io/badge/Status-Active-green)

> **PROJET-17 — Autonomous Navigation System built on the Virtual RobotX (VRX) simulation platform**  
> A comprehensive ROS 2 framework for GPS-based waypoint navigation with 3D LIDAR obstacle avoidance

---

## 📋 Table of Contents

1. [Abstract](#abstract)
2. [Project Overview](#project-overview)
   - [Project Status](#project-status)
   - [Project Structure](#project-structure)
   - [Additional Documentation](#additional-documentation)
   - [System Requirements](#system-requirements)
   - [Key Features](#key-features)
3. [Background Concepts](#background-concepts-for-new-users)
4. [Installation](#installation)
5. [Quick Start](#quick-start)
6. [Coordinate System](#coordinate-system)
7. [System Architecture](#system-architecture)
8. [Usage Guide](#usage-guide)
9. [Web Dashboard](#web-dashboard)
10. [Simple Anti-Stuck System](#simple-anti-stuck-system)
11. [Waypoint Skip Strategy](#waypoint-skip-strategy)
12. [Terminal Mission Control (CLI)](#terminal-mission-control)
13. [Technical Documentation](#technical-documentation)
    - [Performance Specifications](#performance-specifications)
    - [Waypoint Planner](#waypoint-planner)
    - [A* Path Planning](#a-path-planning)
14. [Troubleshooting](#troubleshooting)
15. [Utility Scripts](#utility-scripts)
16. [Command Cheatsheet](#command-cheatsheet)
17. [Future Roadmap](#future-roadmap)
18. [Contributing](#contributing)
    - [Legacy Directory](#legacy-directory)
19. [References](#references)
20. [Acknowledgments](#acknowledgments)
21. [License](#license)

---

## Abstract

AutoBoat is an autonomous navigation system for unmanned surface vehicles (USVs) developed as a research project using the Virtual RobotX ([VRX](https://github.com/osrf/vrx)) simulation platform. The system integrates advanced path planning, real-time obstacle avoidance, and precise trajectory tracking algorithms optimized for the WAM-V maritime platform. Built on **[ROS 2 Jazzy](https://docs.ros.org/en/jazzy/)** and **[Gazebo Harmonic](https://gazebosim.org/docs/harmonic/)**, the framework provides a robust foundation for autonomous maritime navigation in simulated environments.

The project implements a hierarchical autonomous navigation framework combining perception, planning, and control subsystems to enable intelligent waypoint navigation while dynamically responding to environmental constraints. By processing sensor data streams and mission objectives in real-time, the architecture generates collision-free trajectories that account for static obstacles, operational boundaries, and vehicle dynamics, ensuring safe and efficient autonomous operation.

**Key Contributions:**

- **AutoBoat Navigation System**: Integrated autonomous navigation with 3D LIDAR perception
- **Modular Architecture**: Three-node pipeline (Perception-Planner-Controller) for flexible deployment
- **Simple Anti-Stuck System**: Turn toward clearer side until path clear, with Kalman-filtered drift compensation
- **Web Dashboard**: Real-time monitoring with better visualization
- **Waypoint Skip Strategy**: Automatic skip for blocked waypoints ensuring mission completion
- **A-star Planner Algorithm**: Whenever path is blocked by an obstacle thanks to this algorithm it will avoid it

---

## Project Overview

### Project Status

| Phase | Description | Status |
| :------ | :------------ | :------: |
| Phase 1 | Architecture & MVP | ✅ DONE |
| Phase 2 | Autonomous Navigation | ✅ DONE |
| Phase 3 | Coverage Planning | ⏸️ Planned |
| Phase 4 | Integration & Testing | 🔄 90% |
| Phase 5 | Real-Hardware Deployment | 🔜 Planned |

See [Board.md](Board.md) for detailed milestones and progress tracking.

### Project Structure

> **Note:** Only the AutoBoat modular system (Perception-Planner-Controller) is actively developed. All Atlantis and robust_avoidance code has been moved to `legacy/`.

```text
uvautoboat/
├── control/                    # ROS 2 Control Package
│   └── control/
│       ├── heading_controller.py      # Modular controller — active
│       ├── keyboard_teleop.py       # Manual control interface
│       └── lidar_obstacle_avoidance.py  # Shared obstacle detection library
├── plan/                       # ROS 2 Planning Package
│   └── plan/
│       ├── lidar_perception.py        # 3D LIDAR perception — active
│       ├── waypoint_planner.py       # Waypoint planner + A* — active
│       ├── autoboat_cli.py           # Terminal mission control
│       ├── health_check_service.py  # ROS 2 health check node (dashboard streaming)
│       ├── lidar_obstacle_avoidance.py  # LIDAR processing module
│       ├── grid_map.py              # Grid mapping for A* planning
│       └── waypoint_visualizer.py   # RViz visualization
├── launch/                     # Top-level launch files
│   └── autoboat.launch.yaml         # Modular system configuration
├── web_dashboard/              # Real-time monitoring interfaces
│   └── autoboat/                    # AutoBoat dashboard (active)
│       ├── index.html               # Dashboard HTML
│       ├── app.js                   # Dashboard logic
│       ├── style_merged.css         # Dashboard styles
│       └── README_autoboat_dashboard.md
├── test_environment/           # Gazebo worlds and LiDAR reference
│   ├── sydney_regatta_DEFAULT.sdf  # Default VRX world (clean environment)
│   └── wamv_3d_lidar.xacro         # Default 3D LIDAR config (backup)
├── wiki/                       # GitHub Wiki documentation
│   ├── Home.md                      # Wiki landing page
│   ├── Installation_Guide.md        # Setup instructions
│   ├── Quick_Start.md               # 5-minute quick start
│   ├── System_Overview.md           # Architecture deep-dive
│   ├── Design_Rationale.md          # Why these design/parameter choices
│   ├── Glossary.md                  # Plain-language term definitions
│   ├── Roadmap.md                   # Phase 5 + research extensions scope
│   ├── SASS.md                      # Simple Anti-Stuck System
│   ├── 3D_LIDAR_Processing.md       # LiDAR perception details
│   ├── Dashboard_Security.md        # Security posture and mitigations
│   ├── Node_Naming_Refactor_Plan.md # Record of the functional-naming rename
│   └── Common_Issues.md             # Troubleshooting guide
├── one_click_launch_all/       # Automated launcher scripts
│   ├── launch_autoboat_complete.sh   # One-click full system launch
│   ├── health_check_autoboat.sh      # System health check (46 checks)
│   └── patch_vrx.sh                 # VRX xacro fix (publish_model_pose)
├── working_diary/              # Daily development logs
├── legacy/                     # Deprecated code (for reference only)
│   ├── atlantis/                    # Old Atlantis planner, controller, launch, dashboard
│   ├── robust_avoidance/            # Old robust avoidance controller and docs
│   ├── all_in_one/                  # Old monolithic all-in-one stack
│   ├── misc/                        # Old scripts, pollutant planner, demo launcher
│   ├── fixed_variants/              # Old _fixed variants of perception and controller
│   ├── utilities/                   # Standalone utilities (TF, pose, perception)
│   ├── test_worlds/                 # Custom SDF worlds (smoke, wildlife, custom)
│   ├── environment_plugins/         # Gazebo dead-zone plugin (C++)
│   └── DEPRECATED.md                # Full deprecation inventory
├── images/                     # Documentation images
├── Board.md                    # Development progress tracking
├── README.md                   # Quick start guide
└── USER_MANUAL.md              # This file (detailed technical manual)
```

> **Note:** The `test_environment/` folder contains reference copies of VRX default files:
>
> 1. **Quick reference** - No need to navigate through VRX package folders
> 2. **Template base** - Starting point for creating custom worlds with obstacles, buoys, etc.
> 3. **Parameter backup** - The `wamv_3d_lidar.xacro` contains default LIDAR parameters. If you modify your LIDAR config and need to reset, refer to this file. For the sake of the lidar sensor we are reccomending these changes on the xacro file:

  <xacro:macro name="wamv_3d_lidar" params="name
                                            x:=0.7 y:=0 z:=1.8
                                            R:=0 P:=0 Y:=0
                                            post_Y:=0 post_z_from:=1.2965
                                            update_rate:=10 vertical_lasers:=16 samples:=1875 resolution:=1
                                            min_angle:=-2.617 max_angle:=2.617
                                            min_vertical_angle:=${-pi/12} max_vertical_angle:=${pi/12}
                                            max_range:=130 noise_stddev:=0.01">

### Additional Documentation

| Document | Description |
| :--------- | :------------ |
| [Board.md](Board.md) | Development progress tracking and milestones |
| [AutoBoat Dashboard Guide](web_dashboard/autoboat/README_autoboat_dashboard.md) | Web dashboard setup (rosbridge + web_video_server) and camera panel |
| [Avoidance Code Explanation](legacy/robust_avoidance/docs/AVOIDANCE_CODE_EXPLANATION.md) | Technical obstacle avoidance documentation (legacy, Chinese) |
| [DEPRECATED.md](legacy/DEPRECATED.md) | Full inventory of deprecated/legacy code |

**Wiki Documentation** (see [wiki/](wiki/) folder):

| Wiki Page | Description |
| :---------- | :------------ |
| [Home](wiki/Home.md) | Wiki landing page with navigation |
| [Installation Guide](wiki/Installation_Guide.md) | Step-by-step setup instructions |
| [Quick Start](wiki/Quick_Start.md) | 5-minute quick start guide |
| [System Overview](wiki/System_Overview.md) | Architecture and design philosophy |
| [Design Rationale](wiki/Design_Rationale.md) | Why these architecture, algorithm, and parameter choices were made |
| [Glossary](wiki/Glossary.md) | Plain-language definitions of every technical term |
| [Roadmap](wiki/Roadmap.md) | Phase 5 hardware deployment + research-extensions scope |
| [Simple Anti-Stuck](wiki/SASS.md) | Simple anti-stuck recovery system |
| [3D LIDAR Processing](wiki/3D_LIDAR_Processing.md) | LiDAR perception system details |
| [Dashboard Security](wiki/Dashboard_Security.md) | Security posture, known vulnerabilities, mitigations |
| [Node Naming Refactor Plan](wiki/Node_Naming_Refactor_Plan.md) | Record of the functional-naming rename |
| [Common Issues](wiki/Common_Issues.md) | Comprehensive troubleshooting guide |

### System Requirements

| Component | Minimum | Recommended |
| :---------- | :-------- | :------------ |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| RAM | 8 GB | 16 GB |
| Storage | 40 GB | 60 GB |
| Python | 3.10+ | 3.10+ |
| GPU | Integrated | Dedicated (for Gazebo) |

### Key Features

| Feature | Description |
| :-------- | :------------ |
| **Autonomous Navigation** | GPS-based waypoint following with lawnmower pattern generation |
| **3D Obstacle Avoidance** | Real-time LIDAR point cloud processing with sector analysis |
| **Differential Thrust** | Independent left/right thruster control with PID heading |
| **Simple Anti-Stuck** | Turn toward clearer side until path clear, with Kalman drift compensation |
| **Waypoint Skip** | Automatic skip for blocked waypoints after timeout |
| **Go Home** | One-click return to spawn point |
| **Web Dashboard** | Real-time monitoring with interactive map |
| **Bilingual Interface** | French/English terminal output |
| **Path Priority Logic** | Feature that prioritizes GPS trajectory over obstacle panic when the direct path is clear |
| **Z-Node Interpolation** | Feature that prioritizes GPS trajectory over obstacle panic when the direct path is clear |
| **A\* Path Planning** | Grid-based pathfinding algorithm with obstacle inflation and pre-defined hazard zones |
| **Emergency Stop** | Latching emergency stop from dashboard or CLI — cuts thrust immediately |
| **JSON Log Export** | Export panel contents (health check, logs, terminal, mission) as JSON files |
| **Health Check Service** | ROS 2 node streaming 46 system checks to the dashboard with live output |

---

## Background Concepts for New Users

If you're new to ROS 2 or autonomous navigation, this section provides essential background knowledge.

### What is ROS 2?

**ROS 2 (Robot Operating System 2)** is a framework for building robot software. Think of it as a communication system that allows different parts of a robot (sensors, planning algorithms, controllers) to talk to each other.

**Key ROS 2 Concepts:**

| Concept | Description | Example |
| :-------- | :------------ | :-------- |
| **Node** | Independent program for a specific task | `waypoint_planner_node` (navigation) |
| **Topic** | Named channel for messages | `/wamv/sensors/gps/gps/fix` |
| **Message** | Data structure sent over topics | GPS coordinates, thrust commands |
| **Package** | Collection of related nodes | `plan`, `control` |
| **Parameter** | Runtime-configurable values | PID gains, speed limits |

### GPS Navigation

The WAM-V uses GPS for absolute position tracking. The system converts GPS coordinates to local meters using **equirectangular projection**:

```text
Local X = (latitude - start_lat) × Earth_radius
Local Y = (longitude - start_lon) × Earth_radius × cos(start_lat)
```

**How it works:**

1. First GPS fix becomes local origin (0, 0)
2. Waypoints defined in local meters from origin
3. Earth radius: 6,371,000 meters

### 3D LIDAR Point Cloud Processing

**LIDAR** (Light Detection and Ranging) uses laser pulses to create a 3D map of the environment. The WAM-V's 3D LIDAR returns thousands of points per scan.

**Processing Pipeline (LiDAR Perception):**

| Step | Filter | Purpose |
| :----- | :------- | :-------- |
| 1 | Height: -1.2m to +1.5m | Exclude water/sky, keep navigation-level hazards |
| 2 | Range: 2.2m to 100m | Ignore boat hull, cap detection range |
| 3 | Water Plane Removal | Filter water surface reflections (5th percentile Z, 0.32 m tolerance) |
| 4 | Sector Analysis | Front/Left/Right clearance (adaptive width) |
| 5 | Temporal Filtering | Require 2/3 scans to confirm detection |
| 6 | Obstacle Clustering | Group points into distinct obstacles |
| 7 | Gap Detection | Find passable gaps between obstacles |

**Enhanced Features:**

| Feature | Description |
| :-------- | :------------ |
| **Temporal Filtering** | 3-scan history, requires 2/3 detections to confirm (reduces flickering) |
| **Distance-Weighted Urgency** | Score 0.0 (safe) to 1.0 (critical) for smoother control |
| **Obstacle Clustering** | Groups nearby points (3 m max distance, min 8 points) into individual obstacles |
| **Gap Detection** | Finds passable gaps (>3m width) between obstacles |
| **Adaptive Sectors** | Front sector width adjusts based on target heading |
| **Water Plane Removal** | Estimates water surface Z, filters reflections |

**Enhanced `/perception/obstacle_info` JSON:**

```json
{
  "obstacle_detected": true,
  "min_distance": 8.5,
  "front_clear": 10.2,
  "left_clear": 45.0,
  "right_clear": 12.3,
  "is_critical": false,
  "front_urgency": 0.45,
  "left_urgency": 0.0,
  "right_urgency": 0.35,
  "overall_urgency": 0.45,
  "clusters": [{"x": 8.2, "y": 1.5, "size": 25, "distance": 8.5, "angle_deg": 10.3}],
  "gaps": [{"angle_deg": -25.0, "width": 5.2, "distance": 15.0}],
  "water_plane_z": -2.8,
  "temporal_confidence": 1.0
}
```

### IMU Heading

The **IMU** (Inertial Measurement Unit) provides orientation via quaternion. Yaw (heading) is extracted:

```text
siny_cosp = 2 × (w × z + x × y)
cosy_cosp = 1 - 2 × (y² + z²)
yaw = atan2(siny_cosp, cosy_cosp)
```

### Differential Thrust Control

The WAM-V uses two independent thrusters:

| Maneuver | Left | Right | Result |
| :--------- | :----- | :------ | :------- |
| Forward | +500 | +500 | Straight ahead |
| Reverse | -500 | -500 | Straight back |
| Turn Left | +200 | +500 | Gradual left |
| Spin Left | -500 | +500 | Rotate in place |

**Thrust Range:** -1000 to +1000 Newtons

### PID Control

The **PID controller** provides smooth heading adjustments:

```text
error = target_heading - current_heading
correction = Kp × error + Ki × ∫error + Kd × d(error)/dt
```

| Parameter | Default | Effect |
| :---------- | :-------- | :------- |
| Kp | 500.0 | Proportional response (fast correction) |
| Ki | 20.0 | Integral accumulation (eliminate steady-state error) |
| Kd | 150.0 | Derivative damping (prevent overshoot) |

### Simulation Time (use_sim_time)

When running in Gazebo, time moves differently than real-world time. The `use_sim_time` parameter synchronizes ROS nodes with simulation time.

 Current launch files run on wall time by default. Set `use_sim_time: true` in your launch configuration if simulation clock synchronization is needed.

---

## Installation

### Prerequisites

- **ROS 2 Jazzy**: [Installation Guide](https://docs.ros.org/en/jazzy/Installation.html)
- **Gazebo Harmonic**: [Installation Guide](https://gazebosim.org/docs/harmonic/install_ubuntu/)
- **VRX Simulation**: [GitHub Repository](https://github.com/osrf/vrx)
- **rosbridge-suite**: Required for web dashboard

### Step-by-Step Installation

```bash
# 1. Create workspace
mkdir -p ~/seal_ws/src && cd ~/seal_ws/src

# 2. Clone repositories
git clone https://github.com/Ghostzero00018/uvautoboat.git
git clone https://github.com/osrf/vrx.git

# 3. Install dependencies
cd ~/seal_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y

# 4. Install rosbridge (dashboard WebSocket bridge)
sudo apt install ros-jazzy-rosbridge-suite

# 5. Install web_video_server (dashboard camera panel)
sudo apt install ros-jazzy-web-video-server

# 6. Build workspace
colcon build --merge-install

# 7. Source environment
source ~/seal_ws/install/setup.bash

# 8. (Recommended) Set up ~/.bashrc — see next section
```

### Environment Setup (~/.bashrc)

After building the workspace, add the following lines to `~/.bashrc` so every new
terminal is ready to use. Copy-paste the block below — adjust only the workspace
path if yours differs from `~/seal_ws`:

```bash
# --- ROS 2 / AutoBoat environment (add to the END of ~/.bashrc) ---

# 1. Source ROS 2 Jazzy base
source /opt/ros/jazzy/setup.bash

# 2. Source workspace overlay (must come AFTER the base)
source ~/seal_ws/install/setup.bash

# 3. Custom Gazebo worlds — allows "world:=sydney_regatta_DEFAULT" etc.
export GZ_SIM_RESOURCE_PATH="$HOME/seal_ws/src/uvautoboat/test_environment:${GZ_SIM_RESOURCE_PATH}"

# 4. (Optional) ROS Domain ID — isolates your ROS traffic from others on
#    the same network. All teammates must use the SAME value, or omit this
#    line entirely (defaults to 0). Pick any number between 0 and 232.
# export ROS_DOMAIN_ID=56
```

After editing, apply the changes:

```bash
source ~/.bashrc
# Or simply open a new terminal — new shells load ~/.bashrc automatically.
```

**Verify your environment:**

```bash
# All four should print a non-empty path or value:
echo $ROS_DISTRO              # → jazzy
echo $AMENT_PREFIX_PATH       # → .../seal_ws/install/...
echo $GZ_SIM_RESOURCE_PATH    # → .../test_environment:...
echo $ROS_DOMAIN_ID           # → (your chosen ID, or empty if not set)
```

> **Do NOT add** the following lines — they are unnecessary for this project and
> can cause Gazebo model/plugin resolution failures:
>
> ```bash
> # These are NOT needed — do not add them:
> export GZ_VERSION=harmonic          # VRX Jazzy already knows the Gazebo version
> export GZ_SIM_SYSTEM_PLUGIN_PATH=…  # Only needed for custom C++ plugins
> export SDF_PATH=…                   # Can redirect Gazebo away from correct models
> export GAZEBO_MODEL_PATH=…          # Gazebo Garden/Classic variable, not Harmonic
> ```
>
> **Team note on ROS_DOMAIN_ID:** If multiple teammates run simulations on the
> same local network (e.g. same Wi-Fi), all ROS 2 DDS traffic is visible to
> everyone on domain 0 by default. Set the same `ROS_DOMAIN_ID` across all
> terminals on **one** machine, and use a **different** value from other
> teammates to avoid cross-talk. The launch script inherits whatever value is in
> your bashrc — it does not set its own.

---

## Quick Start

### Two-Terminal Quick Start

**Terminal 1** — Launch Simulation:

```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT
```

**Terminal 2** — Run Navigation:

```bash
ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml
```

### Five-Terminal Full Setup (Web Dashboard + Camera)

| Terminal | Command | Purpose |
| :--------- | :-------- | :-------- |
| **T1** | `ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT` | Gazebo simulation |
| **T2** | `ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0` | WebSocket bridge |
| **T3** | `ros2 run web_video_server web_video_server` | MJPEG camera stream for dashboard (http://<host>:8080) |
| **T4** | `ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml` | Navigation (modular) |
| **T5** | `cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat && python3 -m http.server 8002` | Dashboard web server |

> **Important:** The `delay_between_messages:=0.0` parameter is required for ROS 2 Jazzy due to a parameter type bug.
> This starts a WebSocket server on `ws://localhost:9090`.
> **Camera panel:** Default topic `/wamv/sensors/cameras/front_left_camera_sensor/image_raw`; change it in the dashboard input and click “Refresh” if needed.
> **Note:** T5 must run in a separate terminal — it's a simple HTTP server, not a ROS node.

Then open: **<http://localhost:8002>**

### Expected Output

[![VRX Simulation](images/sydney_regatta_gzsim.png)](https://vimeo.com/851696025)

*Sydney Regatta simulation environment in Gazebo. Credit: [VRX Project](https://github.com/osrf/vrx/wiki/running_vrx_tutorial)*

---

## Coordinate System

Understanding the coordinate system is essential for working with VRX simulation.

![3D Cartesian Coordinate System](images/3d_coordinate_system.jpg)

*3D Cartesian coordinate system. [Primalshell](https://commons.wikimedia.org/wiki/File:3D_Cartesian_Coodinate_Handedness.jpg), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)*

### Position (x, y, z)

| Axis | Direction | Maritime Term |
| :----- | :---------- | :-------------- |
| **X** | Forward / Backward | Ahead / Astern |
| **Y** | Left / Right | Port / Starboard |
| **Z** | Up / Down | Above / Below waterline |

### Orientation (Roll, Pitch, Yaw)

| Rotation | Axis | Description | Maritime Term |
| :--------- | :----- | :------------ | :-------------- |
| **Roll** | X-axis | Side-to-side tilt | Heel to port/starboard |
| **Pitch** | Y-axis | Front-to-back tilt | Bow up / Bow down |
| **Yaw** | Z-axis | Horizontal rotation | Turn to port/starboard |

**Common Values:**

| Pose | Roll | Pitch | Yaw | Result |
| :----- | :----: | :-----: | :---: | :------- |
| Default | 0 | 0 | 0 | Upright, facing +X |
| 90° right turn | 0 | 0 | -1.57 | Facing +Y |
| 90° left turn | 0 | 0 | 1.57 | Facing -Y |
| 180° turn | 0 | 0 | 3.14 | Facing -X |

---

## System Architecture

### Modular Architecture (Perception-Planner-Controller)

The active navigation system is a modular 3-node ROS 2 pipeline:

| Node | Name | Function |
| :----- | :----- | :--------- |
| **Perception** | `lidar_perception` | 3D LIDAR obstacle detection, obstacle clustering |
| **Planner** | `waypoint_planner` | GPS waypoint planning, A* detour, mission management |
| **Controller** | `heading_controller` | PID heading control, obstacle avoidance, anti-stuck recovery |

> **Note:** Earlier Atlantis and robust_avoidance systems have been deprecated. Their useful features (LiDAR processing, path validation) were integrated into the Perception/Planner/Controller modules. Legacy code is preserved in `legacy/` for reference.

### Modular Topic Flow Diagram

Detailed ROS 2 topic connections between the modular nodes:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          AUTOBOAT MODULAR SYSTEM                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────┐                                                                   │
│  │Perception│ /perception/obstacle_info ────────► Controller (obstacle_callback) │
│  │ (LiDAR)  │                           ────────► Planner (obstacle_callback)    │
│  └──────────┘                                                                   │
│       ▲                                                                         │
│       │ /wamv/sensors/lidars/lidar_wamv_sensor/points                           │
│                                                                                 │
│  ┌──────────┐  /planning/current_target ──────► Controller (target_callback)     │
│  │ Planner  │  /planning/mission_status ──────► Controller (mission_status_cb)   │
│  │          │  /planning/config          ──────► Controller (planner_config_cb)   │
│  └──────────┘                                                                   │
│       ▲  ▲                                                                      │
│       │  │ /planning/detour_request ◄──────────── Controller (pub_detour)        │
│       │  │                                                                      │
│       │  └─ /wamv/sensors/gps/gps/fix                                           │
│       ├──── /planning/emergency_stop      ◄── CLI / Dashboard (latched Bool)    │
│       ├──── /planning/stop_mission        ◄── CLI / Dashboard (Trigger service) │
│       ├──── /planning/generate_waypoints  ◄── CLI / Dashboard (Trigger service) │
│       └──── /planning/mission_command     ◄── CLI / Dashboard (other commands)  │
│                                                                                 │
│  ┌──────────┐  /wamv/thrusters/left/thrust  ────────► Gazebo Simulator          │
│  │Controller│  /wamv/thrusters/right/thrust ────────► Gazebo Simulator          │
│  │          │  /control/status              ────────► Web Dashboard             │
│  └──────────┘                                                                   │
│       ▲  ▲                                                                      │
│       │  └─ /wamv/sensors/imu/imu/data                                          │
│       └──── /planning/set_config ◄────────────────────── Dashboard (runtime PID) │
│                                                                                 │
│  External Control:                                                              │
│  ├─ /planning/set_config          ◄─────────── Dashboard (waypoint radius, etc.)│
│  ├─ /planning/emergency_stop      ◄─────────── Safety-critical E-Stop (latched) │
│  ├─ /planning/stop_mission        ◄─────────── Stop service (ACK)               │
│  ├─ /planning/generate_waypoints  ◄─────────── Generate service (ACK)           │
│  └─ /planning/mission_command     ◄─────────── Other commands (start/resume/…)  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**JSON Message Formats:**

| Topic | Format |
| :------ | :------- |
| `/perception/obstacle_info` | `{obstacle_detected, min_distance, front_clear, left_clear, right_clear, is_critical}` |
| `/planning/current_target` | `{current_position, target_waypoint, distance_to_target, waypoint_index, target_heading}` |
| `/planning/mission_status` | `{state, current_waypoint, total_waypoints, progress_percent, elapsed_time, position, mission_armed, gps_ready, detour_active, go_home_mode, joystick_override, blocked_reason}` |
| `/control/anti_stuck_status` | `{is_stuck, escape_mode, escape_direction, consecutive_attempts, front_clear, drift_vector, drift_uncertainty, drift_kalman_gain}` |
| `/control/heading_error` | `Float64` — body-frame heading error (radians) used by perception for target-aware VFH |
| `/planning/detour_request` | `{type, x, y}` |

### Data Flow Diagram

```text
┌─────────────────────────────────────────────────────────────┐
│                    SENSORS (Gazebo)                         │
├─────────────────┬─────────────────┬─────────────────────────┤
│   GPS           │      IMU        │        3D LIDAR         │
│ (NavSatFix)     │    (Imu)        │    (PointCloud2)        │
└────────┬────────┴────────┬────────┴────────────┬────────────┘
         │                 │                     │
         └─────────────────┼─────────────────────┘
                           ▼
              ┌────────────────────────┐
              │   Navigation System    │
              │   ──────────────────   │
              │   • Position tracking  │
              │   • Heading control    │
              │   • Obstacle avoidance │
              │   • Waypoint planning  │
              │   • Anti-stuck recovery│
              └───────────┬────────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
    Left Thruster              Right Thruster
    (-1000 to +1000)           (-1000 to +1000)
```

### Continuous Obstacle Avoidance Loop

The obstacle avoidance runs **continuously** - not as a one-time decision. The boat constantly scans, evaluates, and adjusts:

```text
┌─────────────────────────────────────────────────────────────────┐
│                      PERCEPTION                                 │
│           LiDAR scans 360° continuously (~10-20 Hz)             │
│                            ↓                                    │
│      ┌─────────────────────────────────────────────┐            │
│      │  For each scan:                             │            │
│      │  1. Filter points (height, range)           │            │
│      │  2. Check FRONT sector → min distance       │            │
│      │  3. Check LEFT sector  → min distance       │            │
│      │  4. Check RIGHT sector → min distance       │            │
│      │  5. Publish obstacle_info                   │            │
│      └─────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                      CONTROL                                    │
│           Receives obstacle_info every ~100ms                   │
│                            ↓                                    │
│      ┌─────────────────────────────────────────────┐            │
│      │  Decision Logic (runs every control loop):  │            │
│      │                                             │            │
│      │  IF front_clear AND distance > safe:        │            │
│      │     → Continue toward waypoint              │            │
│      │                                             │            │
│      │  IF obstacle detected:                      │            │
│      │     → Slow down (obstacle_slow_factor)      │            │
│      │     → Check which side is clearer           │            │
│      │     → Turn toward clearer side              │            │
│      │                                             │            │
│      │  IF critical distance:                      │            │
│      │     → STOP immediately                      │            │
│      │     → Initiate anti-stuck if truly stuck      │            │
│      └─────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

**Real-Time Decision Example:**

| Time | Front | Left | Right | Action |
| :----- | :------ | :----- | :------ | :------- |
| 0.0s | 15m | 50m | 8m | ⚠️ Obstacle ahead → Turn LEFT (clearer) |
| 0.1s | 20m | 45m | 10m | 🔄 Continue LEFT turn |
| 0.2s | 35m | 40m | 15m | 📐 Front clearing, reduce turn |
| 0.3s | 50m | 50m | 25m | ✅ CLEAR! Resume to waypoint |

> **Key Point:** The boat is **always** scanning, calculating distances, and adjusting - even while dodging an obstacle. This enables navigation through complex obstacle fields.

### ROS 2 Topics

#### Sensor Inputs

| Topic | Type | Description |
| :------ | :----- | :------------ |
| `/wamv/sensors/gps/gps/fix` | `NavSatFix` | GPS coordinates |
| `/wamv/sensors/imu/imu/data` | `Imu` | Orientation quaternion |
| `/wamv/sensors/lidars/.../points` | `PointCloud2` | 3D LIDAR data |

#### Control Outputs

| Topic | Type | Description |
| :------ | :----- | :------------ |
| `/wamv/thrusters/left/thrust` | `Float64` | Left thruster (-1000 to +1000 N) |
| `/wamv/thrusters/right/thrust` | `Float64` | Right thruster (-1000 to +1000 N) |

#### Dashboard Topics

| Topic | Description |
| :------ | :------------ |
| `/planning/mission_status` | Mission state and progress (JSON) |
| `/planning/waypoints` | Waypoint list (JSON) |
| `/planning/current_target` | Current navigation target (JSON) |
| `/planning/config` | Current planner configuration (JSON) |
| `/control/status` | Heading controller status (JSON) |
| `/control/anti_stuck_status` | Anti-stuck recovery status (JSON) |
| `/control/heading_error` | Body-frame heading error (Float64, rad) — consumed by Perception for target-aware VFH |
| `/perception/obstacle_info` | Obstacle detection from Perception (JSON) |

---

## Usage Guide

### Modular Navigation (YAML Launch) — Recommended

The primary navigation system uses the modular Perception-Planner-Controller architecture:

```bash
ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml
```

> **Note:** The YAML launch file contains all default parameters. Edit the file directly to customize, or use the Python launch file for command-line arguments.

**Available Parameters (in `autoboat.launch.yaml`):**

| Node | Parameter | Default | Description |
| :----- | :---------- | :-------- | :------------ |
| **Perception** | `perception_min_safe_distance` | 10.0 | Obstacle safe distance (m) |
| | `perception_critical_distance` | 5.5 | Critical obstacle distance (m) |
| | `min_height` | -1.2 | Min Z to detect (low piers) |
| | `max_height` | 1.5 | Max Z to detect (navigation hazards) |
| | `min_range` | 2.2 | Ignore obstacles closer (boat hull) |
| | `max_range` | 100.0 | Max detection range (m) |
| | `temporal_history_size` | 3 | Scans to keep in history (faster response) |
| | `temporal_threshold` | 2 | Min detections to confirm obstacle (2/3) |
| | `cluster_distance` | 3.0 | Max distance between cluster points (m) |
| | `min_cluster_size` | 8 | Min points per cluster (detect obstacles) |
| | `water_plane_threshold` | 0.32 | Tolerance for water plane removal (m) |
| **Planner** | `scan_length` | 15.0 | Lawnmower lane length (m) |
| | `scan_width` | 30.0 | Lane spacing (m) |
| | `lanes` | 10 | Number of lawnmower lanes |
| | `waypoint_tolerance` | 3.5 | Arrival radius (m) |
| | `waypoint_skip_timeout` | 45.0 | Skip blocked waypoint after (s) |
| **Controller** | `kp` | 500.0 | PID Proportional gain |
| | `ki` | 20.0 | PID Integral gain |
| | `kd` | 150.0 | PID Derivative gain |
| | `base_speed` | 400.0 | Base thrust speed (N) |
| | `max_speed` | 800.0 | Maximum thrust (N) |
| | `obstacle_slow_factor` | 0.5 | Speed reduction near obstacles |
| | `critical_distance` | 6.0 | Stop distance (m) |
| | `stuck_timeout` | 12.0 | Simple anti-stuck: stuck detection time (s) |
| | `stuck_threshold` | 1.0 | Simple anti-stuck: min movement to not be stuck (m) |
| | `drift_compensation_gain` | 0.3 | Feed-forward gain: Kalman drift → thrust compensation |

### Keyboard Teleop

Manual control for testing — **War Thunder / GTA5 naval style** with persistent throttle and auto-centering rudder.

```bash
ros2 run control keyboard_teleop
```

**Throttle (persists like a lever):**

| Key | Action |
| :---: | :------- |
| `W` / `↑` | Increase throttle (speed up) |
| `S` / `↓` | Decrease throttle (slow down / reverse) |
| `Space` | All stop (zero throttle + center rudder) |
| `X` | Emergency full reverse |

**Rudder (auto-returns to center):**

| Key | Action |
| :---: | :------- |
| `A` / `←` | Steer left |
| `D` / `→` | Steer right |
| `Q` | Hard left turn |
| `E` | Hard right turn |
| `R` | Center rudder |

**Power:**

| Key | Action |
| :---: | :------- |
| `+` / `=` | Increase max thrust |
| `-` | Decrease max thrust |
| `H` | Show help |
| `Ctrl+C` | Quit |

**Behavior:**

- Throttle persists between keypresses (like a real throttle lever)
- Rudder automatically returns to center when released
- Rudder effect scales with speed (more responsive at higher speeds)
- Visual HUD shows throttle %, rudder position, and thrust values

---

## Web Dashboard

Real-time monitoring interface with TNO Cold War aesthetic.

### Prerequisites

The dashboard communicates with ROS 2 through **rosbridge_suite** (WebSocket bridge, port 9090) and displays camera feeds via **web_video_server** (MJPEG streaming, port 8080). The browser-side client is **roslibjs v1**, loaded from CDN.

```bash
sudo apt install ros-jazzy-rosbridge-suite ros-jazzy-web-video-server
```

> **Note:** `rosbridge_suite` is the actively maintained official ROS package. A separate project called [ros2-web-bridge](https://github.com/RobotWebTools/ros2-web-bridge) (Node.js-based) was archived in November 2025 and is **not** used by this project.

### Dashboard Panels

| Panel | Description |
| :------ | :------------ |
| **Connection Status** | WebSocket connection indicator |
| **GPS Position** | Latitude, longitude, local coordinates |
| **Mission Status** | State, waypoint progress, distance (with state badge) |
| **Obstacle Detection** | Front/Left/Right clearance with status badge |
| **Thruster Output** | Left/Right thrust with visual bars |
| **Anti-Stuck** | Escape status, drift vector |
| **Trajectory Map** | Interactive Leaflet map with boat position |
| **Configuration** | Path, PID, Speed parameter controls (with Apply) |
| **Perception Configuration** | Perception parameters (height, range, clustering) |
| **Controller Configuration** | Control parameters (safety distances, avoidance, anti-stuck) |
| **Health Check** | Live-streaming system health check (46 checks) with elapsed time |
| **System Logs** | Live ROS log feed |
| **ROS2 Terminal** | Direct ROS2 command output |
| **Mission Control** | Generate, confirm, start, stop, resume, emergency stop, go home, reset |

### Configuration Panels

Three independent configuration sections, each with its own Apply button:

| Section | Parameters | Target Node |
| :-------- | :----------- | :------------ |
| **Main Config** | Lanes, Length, Width, PID (Kp/Ki/Kd), Speed (Base/Max) | Planner + Controller |
| **Perception Config** | Height range, detection range, clustering, temporal filtering | Perception |
| **Controller Config** | Safety distances, avoidance gains, anti-stuck, VFH bias, slew rate | Controller |

**Mission Control Buttons:**

| Button | Action |
| :------- | :------- |
| **Generate Waypoints** | Create lawnmower pattern from route config |
| **Confirm Waypoints** | Confirm generated waypoints |
| **Start Mission** | Begin autonomous navigation |
| **Stop** | Pause mission |
| **Resume** | Resume paused mission |
| **Emergency Stop** | Cut thrust and latch stop (red pulsing badge) |
| **Go Home** | Return to spawn point |
| **Reset** | Clear waypoints and reset mission |

**JSON Export:** Four panels (Health Check, System Logs, ROS2 Terminal, Mission Control) include export buttons to download panel contents as JSON files.

**Copy to Clipboard:** Health Check, System Logs, and ROS2 Terminal panels include a "Copy" button for quick clipboard copy of panel contents.

**Parameter Validation:** All numeric inputs are range-validated. Out-of-range values are rejected with an orange warning toast showing the valid range — nothing is sent to ROS until the value is corrected.

**Presets:** The Tuning panel includes four presets (`Universal`, `Buoy Field`, `Pier Detect`, `Open Water`) for quick parameter tuning. Each preset rewrites ~12 perception + ~10 controller params in one click. VFH bias is enabled in three of the four presets; `Open Water` leaves it off.

---

## Simple Anti-Stuck System

Simple recovery system when the boat becomes trapped or immobilized.
The AutoBoat heading controller implements a straightforward anti-stuck strategy: **turn toward the clearer side (left or right, based on sector clearance) until the path is clear, then resume navigation**.

### Features

| Feature | Description |
| :-------- | :------------ |
| **Simple Escape** | Turn toward clearer side (left or right) until front clearance > safe distance |
| **Stuck Detection** | Monitors position movement over configurable timeout (default 12s) |
| **Skip During Avoidance** | Won't trigger stuck detection while actively avoiding obstacles |
| **Kalman Drift Compensation** | Estimates current/wind with uncertainty to improve navigation |
| **Mission-Aware** | Automatically resets when mission stops |

### How It Works

```text
1. Stuck Detection:
   - Track boat position every second
   - If movement < stuck_threshold (1.0m) for stuck_timeout (12s)
   - AND path is clear (not during obstacle avoidance)
   - Trigger escape mode

2. Simple Escape:
   - Compare left_clear vs right_clear from LiDAR
   - Apply differential thrust toward the clearer side
     - right_clear > left_clear → Left=+450, Right=-450 (turn right)
     - else                    → Left=-450, Right=+450 (turn left)
   - Check front_clear distance every iteration
   - Exit when front_clear > min_safe_distance

3. Resume Navigation:
   - Reset PID integral error
   - Clear stuck state
   - Continue to current waypoint
```

### Parameters

| Parameter | Default | Description |
| :---------- | :-------- | :------------ |
| `stuck_timeout` | 12.0s | Time before declaring stuck |
| `stuck_threshold` | 1.0m | Minimum movement to avoid stuck detection |
| `drift_compensation_gain` | 0.3 | Feed-forward gain: Kalman drift → thrust compensation |
| `kalman_process_noise` | 0.01 | Drift estimation process noise |
| `kalman_measurement_noise` | 0.5 | Drift estimation measurement noise |

### Kalman Filter for Drift

The system uses a 2D Kalman filter to estimate environmental drift (current/wind):

```python
x = [drift_x, drift_y]    # State estimate
P = uncertainty           # Covariance (lower = more confident)
Q = 0.01                  # Process noise (drift changes slowly)
R = 0.5                   # Measurement noise (GPS/IMU)
```

The estimated drift is applied during navigation to compensate for environmental forces.

**Dashboard Uncertainty Colors:** 🟢 < 0.05 (confident) | 🟡 0.05-0.15 | 🔴 > 0.15

---

## Waypoint Skip Strategy

The waypoint planner includes a Waypoint Timeout feature (default: 45 seconds) that automatically skips a target if the vessel cannot reach it due to currents or persistent obstacles.

When obstacles block waypoints, the system uses two strategies to continue the mission:

### 1. Stuck-Based Skip

When the boat is physically stuck and cannot move, the controller's anti-stuck system activates:

| Attempt | Action |
| :-------- | :------- |
| 1st | Turn toward clearer side until clear |
| 2nd+ | Continue turning and retry approach |
| Timeout (45s) | **Skip waypoint** and continue to next |

### 2. Obstacle Blocking Skip

When the boat keeps circling near a waypoint but can't reach it:

| Condition | Action |
| :---------- | :------- |
| Distance < 20m | Start tracking obstacle blocking time |
| Obstacle detected | Accumulate blocking time |
| Blocking time ≥ 45s | **Skip waypoint** automatically |

### 3. Go Home Mode

When returning home encounters obstacles, the system uses **detour insertion** instead of skipping:

| Condition | Action |
| :---------- | :------- |
| Distance < 20m | Start tracking obstacle blocking time |
| Blocking time ≥ 15s | **Insert detour waypoint** perpendicular to obstacle |
| Detour reached | Continue toward home |

This ensures the boat always reaches home, even through buoy fields.

**Log Output:**

```text
🏠 HOME MODE: Obstacle blocking for 15s - Inserting detour
DÉTOUR! Inserting detour waypoint LEFT at (45.2, -12.8)
```

**Configuration:**

```yaml
# In autoboat.launch.yaml
- name: waypoint_skip_timeout
  value: 45.0  # Seconds of obstacle blocking before skip (normal mode)
```

**Normal Mode Log Output:**

```text
⏭️ SAUT PT 3/10 | SKIP WP - Obstacle blocking for 45s (target was 8.2m away)
```

> **Note:** Skipping ensures mission completion even when waypoints are placed among obstacles like buoy lines.

---

## Terminal Mission Control

The **autoboat_cli** provides terminal-based mission control when the web dashboard is unavailable or for scripted automation. It supports both navigation architectures and includes automatic readiness checking.

### Features

| Feature | Description |
| :-------- | :------------ |
| **Auto-Ready Check** | Waits for navigation system before sending commands |
| **All-in-One Generate** | Waypoints + PID + Speed in a single command |
| **Interactive Shell** | Rapid command entry without retyping prefixes |

### Waypoint Generation

```bash
# Default: 10 lanes, 15m length, 30m width
ros2 run plan autoboat_cli generate

# Custom parameters
ros2 run plan autoboat_cli generate --lanes 10 --length 50 --width 20

# All-in-one: waypoints + PID + speed in one command
ros2 run plan autoboat_cli generate --lanes 10 --length 60 --width 25 --kp 400 --ki 20 --kd 100 --base 500 --max 800

# With safety distances
ros2 run plan autoboat_cli generate --safe-dist 12.0 --approach-dist 20.0 --approach-factor 0.5 --perception-safe-dist 10.0
```

**Output:**

```text
⏳ Waiting for navigation system...
✅ Navigation system ready!
✅ Waypoints generated: 10 lanes × 60m length × 25m width
   Estimated waypoints: 19
   Estimated distance: 825m
   PID: Kp=400, Ki=20, Kd=100
   Speed: base=500, max=800
```

> **Note:** use `ros2 run plan autoboat_cli confirm` to confirm waypoints before starting the mission.
>
| Parameter | Default | Description |
| :---------- | :-------- | :------------ |
| `--lanes`, `-n` | 10 | Number of lawnmower lanes |
| `--length`, `-L` | 50.0 | Length of each lane (meters) |
| `--width`, `-w` | 20.0 | Spacing between lanes (meters) |
| `--kp` | - | PID Proportional gain (optional) |
| `--ki` | - | PID Integral gain (optional) |
| `--kd` | - | PID Derivative gain (optional) |
| `--base` | - | Base speed in N (optional) |
| `--max` | - | Max speed in N (optional) |
| `--safe-dist` | - | Controller min_safe_distance (m) |
| `--approach-dist` | - | Controller approach_slow_distance (m) |
| `--approach-factor` | - | Controller approach_slow_factor (0-1) |
| `--perception-safe-dist` | - | Perception perception_min_safe_distance (m) |

### Mission Control

```bash
ros2 run plan autoboat_cli start      # 🚀 Start mission
ros2 run plan autoboat_cli stop       # 🛑 Pause mission
ros2 run plan autoboat_cli resume     # ▶️ Resume mission
ros2 run plan autoboat_cli emergency  # 🚨 Emergency stop (cuts thrust, latches)
ros2 run plan autoboat_cli home       # 🏠 Return to spawn
ros2 run plan autoboat_cli reset      # 🔄 Clear waypoints and reset
ros2 run plan autoboat_cli confirm    # ✅ Confirm waypoints
ros2 run plan autoboat_cli status     # 📊 Show current status
```

### Parameter Tuning

```bash
# PID gains
ros2 run plan autoboat_cli pid --kp 400 --ki 20 --kd 100

# Speed limits
ros2 run plan autoboat_cli speed --base 500 --max 800
```

### Interactive Mode

Launch an interactive shell for rapid command entry:

```bash
ros2 run plan autoboat_cli interactive
```

| Command | Action |
| :-------- | :------- |
| `g [lanes] [length] [width]` | Generate waypoints |
| `c` | Confirm waypoints |
| `s` | Start mission |
| `x` | Stop/pause |
| `r` | Resume |
| `e` / `emergency` | 🚨 Emergency stop |
| `home` | 🏠 Go to spawn |
| `reset` | Reset mission |
| `status` | Show status |
| `pid <kp> <ki> <kd>` | Set PID parameters |
| `speed <base> <max>` | Set speed limits |
| `q` | Quit interactive mode |

### Typical Workflow

> **Prerequisites:** Make sure Gazebo and the navigation system are running first!
>
> ```bash
> # Terminal 1: Start Gazebo simulation
> ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT
>
> # Terminal 2: Start modular navigation system
> ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml
> ```
>
```bash
# 1. Generate waypoints with PID and speed (all-in-one)

# CLI will wait for navigation system to be ready

ros2 run plan autoboat_cli generate --lanes 10 --length 60 --width 25 --kp 400 --ki 20 --kd 100 --base 500 --max 800

# 2. Confirm waypoints

ros2 run plan autoboat_cli confirm

# 3. Start mission

ros2 run plan autoboat_cli start

# 4. Monitor (optional)

ros2 run plan autoboat_cli status

# 5. Pause if needed

ros2 run plan autoboat_cli stop

# 6. Resume

ros2 run plan autoboat_cli resume

# 7. Return home when done

ros2 run plan autoboat_cli home
```

> **Auto-Ready Check:** The `generate` command waits for the `/planning/generate_waypoints` service to become available before sending the request. If the navigation system isn't running, it will show which command to launch.

### Modular Mission Flow (Dashboard + Planner/Controller)

```bash
[Dashboard open & connected]
     |
     v
[Generate Waypoints] --(GPS missing)--> [Wait for GPS]
     |
     v                 state=WAITING_CONFIRM
[Confirm Waypoints] -----------------------> state=READY
     |
     v
[Start Mission]
     |
     v
[Planner: DRIVING + mission_armed=true]
  publishes mission_status + current_target
     |
     v
[Controller: follows target + obstacle avoidance/anti-stuck]
     |
     v
[FINISHED] --> dashboard shows finished (can Start again)

Interrupts:
- STOP: dashboard/CLI burst -> state=PAUSED, mission_armed=false, thrust zero; Resume enabled.
- EMERGENCY STOP: state=EMERGENCY_STOP, mission_armed=false, thrust zero; Resume re-enables.
- RESUME: from PAUSED/JOYSTICK/EMERGENCY_STOP/WAITING_CONFIRM/READY with waypoints -> state=DRIVING, mission_armed=true.
- RESET: clears waypoints, state->INIT, thrust zero; must Generate/Confirm again.
- JOYSTICK ON: state->JOYSTICK, mission_armed=false; Controller stops, manual teleop.
- JOYSTICK OFF: if waypoints exist -> state=PAUSED (Resume works); else INIT.
- GO HOME: replace waypoints with spawn, state=DRIVING, mission_armed=true, go_home_mode=true.
```

---

## Technical Documentation

### Performance Specifications

| Metric | Value | Notes |
| :------- | :------ | :------ |
| **Control Loop Frequency** | 20 Hz | Heading controller update rate (50 ms period) |
| **LIDAR Processing Rate** | 10-20 Hz | Depends on Gazebo simulation speed |
| **GPS Update Rate** | 10 Hz | VRX default sensor rate |
| **IMU Update Rate** | 100 Hz | VRX default sensor rate |
| **WebSocket Latency** | < 50 ms | rosbridge to dashboard |
| **Obstacle Detection Range** | 2.2–100 m | Configurable via `min_range`/`max_range` |
| **Waypoint Arrival Tolerance** | 3.5 m | Default `waypoint_tolerance` |
| **Thrust Range** | -1000 to +1000 N | Per thruster |

### GPS Navigation

**Equirectangular Projection:**

```text
Local X = (lat - start_lat) × 6,371,000m
Local Y = (lon - start_lon) × 6,371,000m × cos(start_lat)
```

### 3D LIDAR Processing

**Height Reference (LiDAR at `z=1.8` on the WAM-V base_link, ~2–3 m above water surface; Z values are expressed relative to the LiDAR sensor frame):**

| Surface | Z Value |
| :-------- | :-------- |
| Water surface | ≈ -3m |
| Lake bank/terrain | ≈ -2.5m |
| Concrete harbour | ≈ -1 to -0.5m |
| Obstacles on dock | ≈ 0 to +2m |

**Sector Analysis:**

| Sector | Angle Range | Purpose |
| :------- | :------------ | :-------- |
| Front | -45° to +45° | Forward detection |
| Left | +45° to +135° | Left clearance |
| Right | -135° to -45° | Right clearance |

### Bayesian Fundamentals

The navigation system uses Bayesian inference for state estimation:

**Bayes' Theorem:**

```text
P(State | Data) = P(Data | State) × P(State) / P(Data)
     ↓                  ↓              ↓
  Posterior         Likelihood       Prior
```

| Term | Meaning | Example |
| :----- | :-------- | :-------- |
| **Prior** | Belief before measurement | "Drift was ~0.1 m/s" |
| **Likelihood** | Probability of data | "GPS shows velocity mismatch" |
| **Posterior** | Updated belief | "Drift is now ~0.15 m/s" |

### Kalman Filter

The Kalman filter is Bayes' theorem for continuous states with Gaussian distributions:

**Predict:** `P = P + Q` (uncertainty grows)  
**Update:** `K = P/(P+R)`, `x = x + K(z-x)`, `P = (1-K)P` (uncertainty shrinks)

---

---

## Waypoint Planner

The **Waypoint Planner** is the trajectory planning system in the modular AutoBoat architecture.

### Overview

The planner generates systematic coverage patterns and manages mission execution. It works with the Perception and Controller nodes in the modular architecture:

```text
GPS Input → Waypoint Planner → Waypoints/Targets → Heading Controller
                 ↑
          Obstacle Info from Perception
```

### Planner States

| State | Description |
| :------ | :------------ |
| **INIT** | Waiting for GPS fix |
| **WAITING_CONFIRM** | Waypoints generated, awaiting user confirmation |
| **READY** | Confirmed, ready to start mission |
| **DRIVING** | Actively navigating waypoints |
| **PAUSED** | Mission paused by user |
| **FINISHED** | All waypoints reached |
| **EMERGENCY_STOP** | Emergency stop activated — thrust cut, mission latched |
| **JOYSTICK** | Manual override mode |

### Lawnmower Pattern Generation

The planner creates systematic zigzag coverage patterns:

```text
Lane 0: Start ────────────────> End
                                 │
Lane 1: End <────────────────────┘
        │
Lane 2: └────────────────────> End
                                 │
Lane 3: End <────────────────────┘
```

### Configuration Parameters

| Parameter | Default | Description |
| :---------- | :-------- | :------------ |
| `scan_length` | 15.0m | Length of each lane |
| `scan_width` | 30.0m | Spacing between lanes |
| `lanes` | 10 | Number of parallel lanes |
| `waypoint_tolerance` | 3.5m | Arrival radius for waypoint |
| `waypoint_skip_timeout` | 45.0s | Skip blocked waypoint after this time |

### ROS 2 Topics

**Subscriptions:**

| Topic | Description |
| :------ | :------------ |
| `/wamv/sensors/gps/gps/fix` | GPS position |
| `/perception/obstacle_info` | Obstacle detection from Perception |
| `/planning/mission_command` | CLI/dashboard commands (start/resume/go_home/etc.) |
| `/planning/emergency_stop` | Safety-critical E-Stop (latched Bool, RELIABLE QoS) |
| `/planning/detour_request` | Detour requests from Controller |

**Services:**

| Service | Type | Purpose |
| :------ | :--- | :------ |
| `/planning/stop_mission` | `std_srvs/Trigger` | ACK-based stop (replaces retry bandages) |
| `/planning/generate_waypoints` | `std_srvs/Trigger` | ACK-based waypoint generation |

**Publications:**

| Topic | Description |
| :------ | :------------ |
| `/planning/waypoints` | Full waypoint list (JSON) |
| `/planning/current_target` | Current navigation target (JSON) |
| `/planning/mission_status` | Mission state and progress (JSON) |
| `/planning/config` | Current configuration (JSON) |
| `/control/heading_error` | Body-frame heading error (Float64, rad) — emitted by Controller for target-aware VFH |

### Key Features

| Feature | Description |
| :-------- | :------------ |
| **Autonomous Navigation** | GPS-based waypoint following with lawnmower pattern generation |
| **3D Obstacle Avoidance** | Real-time LIDAR point cloud processing with sector analysis |
| **A\* Path Planning** | Integrated A* algorithm dynamically plans detours around obstacle clusters and hazard zones |
| **Hybrid Route Generation** | Pre-calculates A* paths between waypoints to avoid known static hazards |
| **Simple Anti-Stuck** | Turn toward clearer side (bidirectional) recovery maneuver (Heading Controller) |
| **XTE Path Correction** | "Lookahead" steering logic that actively pulls the boat back to the ideal path line |
| **Waypoint Skip** | Automatic skip for blocked waypoints after timeout |
| **Go Home** | One-click return to spawn point |
| **Web Dashboard** | Real-time monitoring with interactive map |
| **Bilingual Interface** | French/English terminal output |

## Troubleshooting

### Expected Log Messages

| Stage | Expected Output |
| :------ | :---------------- |
| Startup | "MISSION DÉMARRÉE / MISSION STARTED" |
| Navigation | "PT X/19 \| Pos: (x, y) \| Cible: (tx, ty)" |
| Obstacle | "🚨 OBSTACLE DETECTED!" |
| Clear | "✅ DÉGAGÉ \| CLEAR" |
| Stuck | "🚨 BLOQUÉ! \| STUCK!" |
| Skip | "⏭️ SAUT PT \| SKIP WP" |
| Complete | "MISSION TERMINÉE!" |

### Common Issues

| Problem | Solution |
| :-------- | :--------- |
| **Boat not moving** | Check GPS: `ros2 topic echo /wamv/sensors/gps/gps/fix --once` |
| **Spinning in circles** | Reduce PID: `ros2 param set /heading_controller_node kp 300` |
| **Dashboard disconnected** | See "Dashboard Connection Diagnostics" below |
| **No obstacles detected** | Check LIDAR: `ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points` |
| **Critical at spawn** | Increase `min_range` to 5.0 in launch file |
| **Build failures** | Clean: `rm -rf build install log && colcon build` |
| **A* not finding paths** | Reduce `astar_safety_margin` or increase `astar_resolution` |
| **A* too slow** | Reduce `astar_max_expansions` or increase `astar_resolution` |
| **Waypoints not generating** | Check GPS: ensure `/wamv/sensors/gps/gps/fix` is publishing |
| **Mission stuck in INIT** | Run `ros2 run plan autoboat_cli generate` to create waypoints |
| **LiDAR at world origin** | Run `bash one_click_launch_all/patch_vrx.sh` — fixes VRX `publish_model_pose` (issue #876) |
| **Health check false FAILs** | Usually a `ros2 daemon` stale cache — run `ros2 daemon stop && ros2 daemon start` and re-run. The health check itself polls DDS discovery on startup so transient lag should self-heal. |

### Dashboard Connection Diagnostics

If the dashboard shows "Disconnected" or only renders half the page, run through
these checks in order:

**Step 1 — Is rosbridge actually listening?**

```bash
ss -tuln | grep 9090
# Expected: a line showing LISTEN on port 9090
# If empty → rosbridge is not running. Check the rosbridge terminal tab for errors.
```

**Step 2 — Is ROS_DOMAIN_ID consistent?**

```bash
echo $ROS_DOMAIN_ID
# Run this in EVERY terminal tab (Gazebo, rosbridge, navigation, dashboard).
# All must show the same value (or all be empty).
# Mismatch = rosbridge cannot see the ROS topics → dashboard stays disconnected.
```

**Step 3 — Can rosbridge see the ROS topics?**

```bash
ros2 topic list | grep planning
# Expected: /planning/mission_status (among others)
# If empty → ROS nodes and rosbridge are on different domains, or nodes crashed.
```

**Step 4 — Is the dashboard HTTP server running?**

```bash
ss -tuln | grep 8002
# Expected: a line showing LISTEN on port 8002
# If empty → the Python HTTP server is not running.
```

### Step 5 — Check browser console (F12 → Console tab)

| Error | Meaning |
| :---- | :------ |
| `Failed to load resource: roslib.min.js` | No internet — CDN dependency cannot load |
| `Failed to load resource: leaflet.js` | No internet — map library cannot load |
| `WebSocket connection to 'ws://localhost:9090' failed` | rosbridge not running or port blocked |
| `ReferenceError: ROSLIB is not defined` | roslib.js failed to load (internet required) |

> **Internet required:** The dashboard loads `roslib.js` and `leaflet.js` from
> CDNs (cdn.jsdelivr.net, unpkg.com). Without internet access, the page will
> partially render and the ROS connection will never initialize.

### Step 6 — Check firewall (if all above pass but still disconnected)

```bash
# Check if ufw is active and blocking ports
sudo ufw status
# If active, allow the required ports:
sudo ufw allow 9090/tcp   # rosbridge WebSocket
sudo ufw allow 8002/tcp   # dashboard HTTP server
sudo ufw allow 8080/tcp   # web_video_server (camera)
```

### Debug Commands

```bash
# Check GPS
ros2 topic echo /wamv/sensors/gps/gps/fix --once

# Check LIDAR rate
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points

# Check node running
ros2 node list | grep -E "perception|planner|controller"

# List parameters
ros2 param list /heading_controller_node

# Check anti-stuck status
ros2 topic echo /control/anti_stuck_status
```

---

## Utility Scripts

### Health Check

```bash
# Run system health check (46 checks: nodes, topics, params, connectivity)
bash one_click_launch_all/health_check_autoboat.sh

# Quick mode (nodes + topics only)
bash one_click_launch_all/health_check_autoboat.sh --quick
```

The health check auto-detects the boat's mission state (IDLE/ACTIVE) and adjusts expectations — mission-dependent topics show as INFO instead of FAIL when no mission is running.

### One-Click Launch

The `one_click_launch_all/` directory contains automated launcher scripts that start the complete system with a single command:

```bash
# Make executable (first time only)
chmod +x one_click_launch_all/launch_autoboat_complete.sh

# Launch complete system (Gazebo + rosbridge + navigation + camera + dashboard)
./one_click_launch_all/launch_autoboat_complete.sh

# Launch with custom world
./one_click_launch_all/launch_autoboat_complete.sh --world sydney_regatta_DEFAULT

# Launch without dashboard (headless)
./one_click_launch_all/launch_autoboat_complete.sh --skip-dashboard

# Combine options
./one_click_launch_all/launch_autoboat_complete.sh --world sydney_regatta_DEFAULT --skip-dashboard
```

**What it launches:**

| Component | Description |
| :---------- | :------------ |
| VRX Patch | Applies `patch_vrx.sh` to fix LiDAR model pose |
| Gazebo Simulation | VRX simulation world |
| rosbridge WebSocket | Dashboard communication (port 9090) |
| web_video_server | Camera MJPEG stream (port 8080) |
| Navigation System | AutoBoat modular navigation |
| Web Dashboard | HTTP server (port 8002) |

> **Note:** The script opens multiple terminal windows. Use `Ctrl+C` in the main terminal to stop all processes.

---

## Command Cheatsheet

### Kill Processes

```bash
# Kill all Gazebo
pkill -9 -f "gz sim" && pkill -9 -f "gzserver" && pkill -9 -f "gzclient"

# Kill ROS nodes
pkill -9 -f autoboat && pkill -9 -f rosbridge

# Nuclear option
pkill -9 -f ros && pkill -9 -f gz && pkill -9 -f gazebo
```

### Build

```bash
# Full build
cd ~/seal_ws && colcon build --merge-install

# Specific packages
colcon build --packages-select plan control --merge-install

# Clean build
rm -rf build install log && colcon build --merge-install

# Run unit tests
colcon test --packages-select plan control
colcon test-result --verbose
```

### Launch

```bash
# Simulation
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT

# Navigation
ros2 launch ~/seal_ws/src/uvautoboat/launch/autoboat.launch.yaml

# Dashboard
ros2 launch rosbridge_server rosbridge_websocket_launch.xml delay_between_messages:=0.0
cd ~/seal_ws/src/uvautoboat/web_dashboard/autoboat && python3 -m http.server 8002
```

### A* Path Planning

```bash
# Enable A* runtime detours
ros2 topic pub /planning/set_config std_msgs/String "data: '{\"astar_enabled\": true}'" --once

# Enable A* hybrid mode (pre-planning between waypoints)
ros2 topic pub /planning/set_config std_msgs/String "data: '{\"astar_hybrid_mode\": true}'" --once

# Adjust grid resolution (smaller grid allows more precise and slower response)
ros2 topic pub /planning/set_config std_msgs/String "data: '{\"astar_resolution\": 2.0}'" --once

# Adjust safe distance around obstacles
ros2 topic pub /planning/set_config std_msgs/String "data: '{\"astar_safety_margin\": 10.0}'" --once

# Check current A* configuration
ros2 topic echo /planning/config --once | grep astar
```

### Teleport Boat

```bash
gz service -s /world/sydney_regatta/set_pose \
  --reqtype gz.msgs.Pose --reptype gz.msgs.Boolean --timeout 1000 \
  --req 'name: "wamv", position: {x: 0, y: 0, z: 0.5}'
```

---

## Future Roadmap

### Planned Features

| Feature | Priority | Description |
| :-------- | :--------- | :------------ |
| **A-Star Path Planning** | Implemented | Grid-based pathfinding in Waypoint Planner |
| **Hybrid Mode** | Implemented | Pre-compute routes between waypoints with lawnmower algorithm |
| **Hazard Zone Avoidance** | Implemented | Pre determined rectangular no-go zones |
| **Dynamic Replanning** | High | Replan path when new obstacles detected |
| **Coverage Planning** | Medium | Boustrophedon pattern for area coverage |
| **Multi-Goal Navigation** | Medium | Navigate through sequence of random points |

### A* Path Planning

The Waypoint Planner now has A* path planning algorithm for navigating to points that are blocked by obstacle fields:

**How it works?**

```text
1. Create occupancy grid (3m cells by default) from LIDAR/obstacle data
2. Inflate obstacles by safety margin + hull radius for clearance
3. Block rectangular hazard zones (no-go areas)
4. A* algorithm use 8-connected A*(8 directions to go) to find optimal path
5. Insert detour waypoints or pre-plan routes between lawnmower points
```

**Proposed Architecture:**

```text

/perception/obstacles ────>┌─────────────────────┐                                   
                    │  AStarSolver        │ 
Hazard boxes ──────>│  (in Planner)       │────> Detour waypoints inserted into /planning/waypoints
                    │                     │
Current position ──>└─────────────────────┘

```

**Two Operating Modes for Better User Experience:**

| Mode | Parameter | Description |
| :----- | :---------- | :------------ |
| **Hybrid** | `astar_hybrid_mode: true` | Pre-plans A* routes between lawnmower waypoints at generation time |
| **Runtime** | `astar_enabled: true` | Plans detours on-the-voyage when WAMV-boat gets stuck |

**Configuration:**

| Parameter | Default | Description |
| :---------- | :-------- | :------------ |
| `astar_resolution` | 3.0m | Grid cell size |
| `astar_safety_margin` | 12.0m | Buffer around obstacles |
| `astar_max_expansions` | 20000 | Max search iterations |

**Benefits:**

- Works for any destination point
- Avoids obstacles from the start
- No circling behavior
- Efficient paths through complex environments
- Integrated directly in the Waypoint Planner (no separate node needed)
- Handles both circular obstacles (buoys) and rectangular hazard zones
- 8-direction movement for smoother paths
- Automatic obstacle inflation for safe clearance
- Fails gracefully if no path found (falls back to waypoint skip)

**Example:**

```text
Without A*:              With A*:

S ──────X──────> G       S ─────┐
        ↑                       ↓
    blocked!              ┌─────┘
                          └────> G

S = Start, G = Goal, X = Obstacle
```

### Technical Debt

| Issue | Status | Description |
| :------ | :------: | :------------ |
| **ROS 2 Parameter Migration** | ✅ Done | Parameters now configurable via `autoboat.launch.yaml` |
| **Multi-Terminal Launch** | ✅ Done | `one_click_launch_all/launch_autoboat_complete.sh` now available |
| **Debugging Required** | 🔄 In Progress | Complex planning and obstacle detection still need debugging |

---

## Contributing

### Development Guidelines

1. **Code Style**: Follow PEP 8 for Python
2. **Documentation**: Update README for significant changes
3. **Testing**: Include unit tests for new features
4. **Commits**: Use clear, descriptive messages

### Legacy Directory

All deprecated code has been organized into `legacy/` with subdirectories:

| Directory | Contents |
| :---------- | :--------- |
| `legacy/atlantis/` | Atlantis planner, controller, launch config, and dashboard |
| `legacy/robust_avoidance/` | Robust avoidance controller, launch config, and documentation |
| `legacy/all_in_one/` | Old monolithic all-in-one navigation stack |
| `legacy/misc/` | Old root scripts, pollutant planner, demo launcher |
| `legacy/fixed_variants/` | Old `_fixed` variants of perception and controller |
| `legacy/utilities/` | Standalone utilities (TF broadcasters, pose filter, simple perception, etc.) |

See `legacy/DEPRECATED.md` for a full inventory. Legacy code is preserved for reference but is not maintained.

### Reporting Issues

Open an issue on [GitHub](https://github.com/Ghostzero00018/uvautoboat/issues) with:

- Problem description
- Steps to reproduce
- Expected vs actual behavior
- System information

---

## References

### Documentation

- [ROS 2 Jazzy Documentation](https://docs.ros.org/en/jazzy/)
- [Gazebo Harmonic Documentation](https://gazebosim.org/docs/harmonic)
- [VRX Wiki](https://github.com/osrf/vrx/wiki)
- [Kalman Filter Illustrated](https://www.bzarg.com/p/how-a-kalman-filter-works-in-pictures/)

### Message Types

- [sensor_msgs/NavSatFix](http://docs.ros.org/en/api/sensor_msgs/html/msg/NavSatFix.html)
- [sensor_msgs/PointCloud2](http://docs.ros.org/en/api/sensor_msgs/html/msg/PointCloud2.html)
- [sensor_msgs/Imu](http://docs.ros.org/en/api/sensor_msgs/html/msg/Imu.html)

### Related Projects

- [Virtual RobotX (VRX)](https://github.com/osrf/vrx)
- [ros2_control](https://github.com/ros-controls/ros2_control)

---

## Acknowledgments

**Maintained By**: AutoBoat Development Team

**Institution**: [IMT Nord Europe](https://imt-nord-europe.fr/) — Industry 4.0 Students & Faculty

**Special Thanks**:

- [Open Source Robotics Foundation (OSRF)](https://www.openrobotics.org/) for VRX and Gazebo
- [ROS 2 Community](https://www.ros.org/) for the robotics middleware
- Contributors and testers who helped improve this project

**Development Teams**:

- Perception & Planning Team: LiDAR Perception (3D LiDAR Processing), Waypoint Planner (GPS Waypoint Navigation & A* Path Planning)
- Control Team: Heading Controller (PID Control & Obstacle Avoidance)

Project finished by IMT NORD EUROPE DNM DMI-2026

Last updated at 21-04-2026

---

## License

This project is licensed under the **Apache License 2.0**.

See [LICENSE](LICENSE) for details.

---

**AutoBoat** — Autonomous USV Navigation on the VRX Simulation Platform

Built with [ROS 2 Jazzy](https://docs.ros.org/en/jazzy/) + [Gazebo Harmonic](https://gazebosim.org/docs/harmonic)

[Report Bug](https://github.com/Ghostzero00018/uvautoboat/issues) · [Request Feature](https://github.com/Ghostzero00018/uvautoboat/issues)
