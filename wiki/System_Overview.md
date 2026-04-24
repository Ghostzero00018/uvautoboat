# System Overview

High-level architecture and design philosophy of the AutoBoat autonomous navigation system.

> 💡 **Related pages:**
>
> - For **term definitions** (USV, VRX, VFH, Kalman filter, ENU, etc.), see **[Glossary](Glossary)**.
> - For **why these choices were made** (trade-offs, parameter rationale, algorithm justifications), see **[Design_Rationale](Design_Rationale)**.

---

## Abstract

AutoBoat is an autonomous navigation system for unmanned surface vehicles (USVs) developed as a research project on the Virtual RobotX ([VRX](https://github.com/osrf/vrx)) simulation platform. The system integrates advanced path planning, real-time obstacle avoidance, and precise trajectory tracking algorithms optimized for the WAM-V maritime platform.

Built on **ROS 2 Jazzy** and **Gazebo Harmonic**, the framework provides a robust foundation for autonomous maritime navigation in simulated environments.

---

## Key Contributions

- **AutoBoat Navigation System**: Integrated autonomous navigation with 3D LIDAR perception
- **Modular Architecture**: Three-node pipeline (Perception-Planner-Controller) for flexible deployment
- **Simple Anti-Stuck System**: Turn toward clearer side until path clear, with Kalman-filtered drift compensation
- **Web Dashboard**: Real-time monitoring with visualization
- **Waypoint Skip Strategy**: Automatic skip for blocked waypoints ensuring mission completion
- **A* Path Planning**: Grid-based pathfinding for obstacle avoidance

---

## Active Navigation System

The **Modular (Perception–Planner–Controller)** three-node pipeline is the active system:

| Node | Role | Description |
|:-----|:-----|:------------|
| **Perception** | Perception | 3D LiDAR obstacle detection, temporal filtering, clustering |
| **Planner** | Planning | Lawnmower waypoint generation, A* detour planning, mission state machine |
| **Controller** | Control | PID heading control, reactive obstacle avoidance, simple anti-stuck recovery |

- Highly **configurable via YAML** (`autoboat.launch.yaml`)
- Three separate dashboard config panels (Main, Perception, Controller)
- Runtime parameter tuning with dirty-params filtering

> **Note:** The integrated AutoBoat and Atlantis systems have been deprecated and moved to `legacy/`. See `legacy/DEPRECATED.md` for details.

---

## High-Level Data Flow

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
    (-1000 to +1000N)          (-1000 to +1000N)
```

---

## Core Subsystems

### 1. Perception

- **3D LIDAR Processing** (LiDAR Perception v2.0)
- Real-time point cloud filtering
- Sector-based obstacle detection
- Temporal filtering for reliability
- Obstacle clustering and gap detection
- VFH polar histogram with target-aware gap selection

### 2. Planning

- **GPS Waypoint Navigation** (Waypoint Planner)
- Lawnmower pattern generation
- A* path planning for obstacles
- Waypoint skip logic
- Detour insertion

### 3. Control

- **PID Heading Control** (Heading Controller)
- Differential thrust control
- Obstacle reaction
- Simple Anti-Stuck System
- Drift compensation with Kalman filter
- Speed adaptation near obstacles

### 4. Monitoring

- **Web Dashboard**
- Real-time position visualization
- Mission status and progress
- Obstacle detection display
- Parameter configuration
- Camera feed integration

---

## Key Features Explained

### Autonomous Navigation

- GPS-based waypoint following
- Automatic lawnmower pattern generation
- Dynamic path adjustment for obstacles

### 3D Obstacle Avoidance

- Real-time LIDAR point cloud processing
- Front/Left/Right sector clearance analysis
- Continuous obstacle monitoring (~10 Hz)
- Distance-weighted urgency scoring

### Simple Anti-Stuck System

- Turn toward clearer side (left or right, chosen by live sector-clearance comparison) until the path is clear
- Single-phase escape — no probe/reverse/turn sub-states
- Kalman filter for drift estimation
- Adaptive duration based on severity

### Waypoint Skip Strategy

- Automatic skip after timeout (default: 45s)
- Go Home mode uses detour insertion instead
- Ensures mission completion in complex environments

### A* Path Planning

- Grid-based pathfinding (default: 3m cells)
- Obstacle inflation for safe clearance
- Hybrid mode: pre-plan routes at generation
- Runtime mode: plan detours when stuck

---

## Software Stack

```text
┌───────────────────────────────────┐
│      Application Layer            │
│  (AutoBoat Navigation Nodes)      │
├───────────────────────────────────┤
│         ROS 2 Jazzy               │
│  (Middleware & Communication)     │
├───────────────────────────────────┤
│      Gazebo Harmonic              │
│   (Physics Simulation)            │
├───────────────────────────────────┤
│       Ubuntu 24.04 LTS            │
└───────────────────────────────────┘
```

### Technologies Used

- **ROS 2 Jazzy**: Robot middleware
- **Gazebo Harmonic**: 3D simulation
- **Python 3.10+**: Implementation language
- **NumPy/SciPy**: Numerical computations
- **Leaflet.js**: Interactive map visualization

### Web Communication Stack

The dashboard connects to ROS 2 through three components:

| Component | Package | Port | Role |
|:----------|:--------|:-----|:-----|
| **rosbridge_suite** | `ros-jazzy-rosbridge-suite` | 9090 | WebSocket ↔ ROS 2 bridge (JSON protocol). Dashboard uses `ROSLIB.Ros()` to subscribe/publish topics and call services. |
| **web_video_server** | `ros-jazzy-web-video-server` | 8080 | Serves live MJPEG camera streams over HTTP from any `sensor_msgs/Image` topic. |
| **roslibjs** | `roslib@1` (CDN) | — | Browser-side JavaScript client for rosbridge. Loaded via `<script src="https://cdn.jsdelivr.net/npm/roslib@1/build/roslib.min.js">`. |

> **Not to be confused with:** [ros2-web-bridge](https://github.com/RobotWebTools/ros2-web-bridge) — a separate Node.js reimplementation of the rosbridge protocol. That project was **archived in November 2025**, last targeted ROS 2 Dashing (2019), and its README redirects users to `rosbridge_suite`. This project has always used `rosbridge_suite`, which is the actively maintained official package.

---

## Design Philosophy — Why This Architecture?

The guiding principles below shape every design choice in AutoBoat. For the full trade-off analysis behind each choice, see **[Design_Rationale](Design_Rationale)**.

### Modularity — independent nodes over a monolithic binary

- **Clear separation of perception, planning, and control** — Perception, Planner, and Controller each run as an independent ROS 2 node, communicating only through topic messages.
- **Failure isolation** — if the perception node crashes, the planner and controller keep running on their last-known obstacle data. A monolithic program would take down everything together.
- **Debuggability** — inter-module messages are plain-text JSON, inspectable live with `ros2 topic echo`, so problems can be pinpointed to the exact pipeline stage.
- **Upgrade independence** — swapping out perception (e.g., cluster-based → neural network) does not require touching the controller.
- **Parallel development** — contributors can work on Perception, Planner, or Controller simultaneously without merge conflicts.

**Cost:** ~1–2 ms inter-process messaging overhead, negligible for a 50 ms control loop.

### Robustness — graceful degradation over perfection

- **Temporal filtering** — an obstacle must appear in 2 of the last 3 LiDAR scans before it is trusted, rejecting transient noise.
- **Multi-level obstacle fallback** — reactive avoidance → auto detour → A\* reroute → skip waypoint. Each level is cheap; expensive replanning only runs when the simpler options fail.
- **Anti-stuck recovery** — if the boat makes no progress for 12 s and the path looks clear, the Controller turns toward the clearer side until it escapes; see **[SASS](SASS)** for details.
- **Kalman-filtered drift compensation** — the Controller runs a 2D linear Kalman filter to track water-current and wind drift and steer "upstream" to compensate.

### Flexibility — configuration over hardcoding

- **Runtime parameter tuning** — the dashboard's Tuning panel sends changed parameters via `/planning/set_config` without restarting nodes.
- **Multiple control interfaces** — web dashboard, terminal CLI (`autoboat_cli`), keyboard teleop, and joystick for manual override.
- **YAML-first configuration** — `autoboat.launch.yaml` is the single source of truth for active parameter values.
- **Three navigation modes** — Simple Lawnmower, Runtime A\* (default), and Hybrid Mode — chosen by radio buttons on the dashboard.

### Real-Time Performance — "fast enough" not "as fast as possible"

- **20 Hz (50 ms) control loop** — faster than the LiDAR rate (10 Hz), so control can respond to fresh obstacle data within one cycle.
- **Sector-based summarisation** — the Perception node reduces ~30,000 LiDAR points per scan to three sector summaries (Front/Left/Right distance + urgency), letting the controller make decisions in constant time regardless of raw cloud size.
- **Soft real-time** — not hard-real-time (no kernel scheduling guarantees), but empirically consistent enough for a slow-moving boat.

### Simplicity over sophistication (when adequate)

Several places in the project deliberately use simpler methods over more sophisticated alternatives:

| Where | Simple method (in use) | Sophisticated alternative (not used) | Why |
|:------|:-----------------------|:-------------------------------------|:----|
| Drift estimation | 2D linear Kalman filter | Extended Kalman Filter (EKF) | Drift is a slow, linear process — linear KF is provably optimal here, at a fraction of the compute cost |
| Obstacle direction | 3-sector summary (F/L/R) | Full polar histogram (VFH) | 3 sectors are more stable in sparse environments; VFH is enabled only for cluttered scenarios via dashboard presets |
| Pose fusion | Inline GPS→local in each node | Dedicated pose node | Removing the shared pose node eliminates a single point of failure and reduces inter-node dependencies |

These choices are documented with full rationale in **[Design_Rationale](Design_Rationale)**.

---

## Project Structure

```text
uvautoboat/
├── control/           # Control nodes (heading_controller, teleop)
├── plan/              # Planning nodes (waypoint_planner, lidar_perception)
├── launch/            # Top-level launch files
├── web_dashboard/     # Web monitoring interfaces
├── test_environment/  # Custom Gazebo worlds and models
├── scripts/           # Repo-maintenance helpers (wiki sync, …)
├── tools/             # Ad-hoc diagnostic scripts (rate_probe.py — QoS-aware topic-hz)
└── wiki/              # This documentation
```

---

## Next Steps

Learn more about specific components:

- **[Glossary](Glossary)** — Plain-language definitions of every technical term
- **[Design_Rationale](Design_Rationale)** — Full "why" behind architecture, algorithm, and parameter choices
- **[3D LIDAR Processing](3D_LIDAR_Processing)** — LiDAR Perception deep-dive
- **[SASS](SASS)** — Simple Anti-Stuck recovery system
- **[Common_Issues](Common_Issues)** — Troubleshooting guide
- **[Quick_Start](Quick_Start)** — Get your first mission running in 5 minutes
