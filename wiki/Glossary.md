# Glossary

Plain-language definitions of every technical term used across the AutoBoat codebase and documentation. Organized by category.

For **design rationale** (why these choices were made), see **[Design_Rationale](Design_Rationale)**.

---

## Robotics & Vehicles

### USV (Unmanned Surface Vehicle)

A boat that operates on the water surface without a human pilot. Think of it as a self-driving car, but for water. Used for tasks like oceanographic research, port security, and environmental monitoring.

### WAM-V (Wave Adaptive Modular Vessel)

A specific type of USV originally designed by Marine Advanced Research. It has a unique twin-hull catamaran design (two pontoons connected by a suspension system) that lets it adapt to wave motion. It is the standard platform used in the VRX competition.

### USV Thrusters

The propellers that push the boat forward. The WAM-V has two — one on each pontoon. By varying the power of each independently (see **differential thrust** below), the boat can go forward, backward, and turn.

---

## Simulation

### VRX (Virtual RobotX)

An open-source simulation environment maintained by the Open Source Robotics Foundation (OSRF). Specifically designed for testing USV algorithms — think of it as a flight simulator, but for autonomous boats. VRX provides realistic WAM-V models, water physics, and competition-style scenarios.

### Gazebo Harmonic

A 3D physics simulator commonly used in robotics research. It simulates physics (gravity, water, collisions), sensors (GPS, IMU, cameras, LiDAR), and visualization. "Harmonic" is a specific version released in 2024.

### Sydney Regatta Scenario

A simulated map of Sydney Harbour in Gazebo, modelled after the real competition venue at the Sydney International Regatta Centre. Includes docks, buoys, and realistic water physics. The active world file in this project is `sydney_regatta_DEFAULT.sdf`.

---

## Robotics Software

### ROS 2 (Robot Operating System 2)

Despite the name, ROS is NOT an operating system like Windows or Linux. It is a **framework** (a set of tools and libraries) for writing robotics software. It helps different parts of a robot communicate. Version 2 is the modern version; "Jazzy" is the 2024 stable release codename.

### ROS Node

An independent program that does one specific job in a robotic system. Example: one node reads GPS data, another processes LiDAR data, another controls the thrusters. Nodes communicate by publishing and subscribing to **topics** (named message channels).

### ROS Topic

A named communication channel where messages are sent. One or more nodes publish messages to a topic, and other nodes subscribe to receive them. Example: the `/wamv/sensors/gps/gps/fix` topic carries GPS location messages in this project.

### Modular Architecture

A design where a system is split into small, independent pieces (modules) that communicate through well-defined interfaces. Benefits: easier to debug, easier to replace or upgrade, easier for teams to work in parallel.

### ROSBridge

A bridge program that translates between ROS 2 messages (internal format) and WebSocket + JSON (web format). This lets a web browser communicate with a ROS system. Without ROSBridge, the web dashboard could not talk to the ROS nodes. Runs on `ws://localhost:9090`.

### DDS (Data Distribution Service)

The underlying network protocol ROS 2 uses internally. Think of it as the "native language" of ROS 2. Browsers do not speak DDS, which is why ROSBridge is needed.

### WebSocket

A web technology that allows real-time two-way communication between a browser and a server. Normal web pages use HTTP (one-shot request/response). WebSocket keeps the connection open for continuous data flow — perfect for live dashboards.

### RViz

A 3D visualization tool that comes with ROS. Lets you see what the robot "sees" — sensor data, planned paths, coordinate frames, etc. Used for debugging.

### TF (Transform Tree)

In ROS, a "transform" describes how one coordinate frame relates to another (e.g., how the LiDAR frame is positioned relative to the boat's base). TF is the system that maintains a tree of such transforms. **This project does not use TF in the current architecture** — each node does its own GPS→local conversion. TF broadcasters exist only in legacy code.

### URDF / Xacro

**URDF** (Unified Robot Description Format) is an XML file describing a robot's physical structure: links, joints, sensors. **Xacro** is a macro extension of URDF that allows reusable components and variables. This project's LiDAR configuration (`wamv_3d_lidar.xacro`) uses xacro.

### colcon

The standard build tool for ROS 2 packages (replacement for the older `catkin_make`). Commands used in this project: `colcon build`, `colcon test`. Each ROS 2 package has a `package.xml` declaring dependencies and a `setup.py` (Python) or `CMakeLists.txt` (C++) describing how to build it.

### ament_python

The Python build system used by this project's packages (declared in `package.xml` as `<build_type>ament_python</build_type>`). It is the ROS 2 equivalent of a Python `setup.py` with ROS-specific install hooks (e.g., installing launch files, resources).

### Launch File (YAML vs Python)

A file that describes how to start a set of ROS nodes together with their parameters. ROS 2 supports two formats: `.launch.yaml` (declarative, easier to read) and `.launch.py` (programmatic, more flexible). This project uses `autoboat.launch.yaml` as the main launch configuration.

### Health Check Service

A background ROS node (`health_check_service`) that runs 49 automated checks to verify system integrity: node presence, topic publish/subscribe counts, runtime parameter values, port connectivity (9090/8002/8080). Parameter values are reported in one of four states — `PASS` (matches YAML baseline), `TUNED` (differs because the user applied a preset or dashboard config, counted as healthy), `WARN` (differs without any user config having been applied — genuine drift worth investigating), `FAIL` (unreadable / node down). The dashboard has a "Health Check" panel that streams results live. `PASS + TUNED` with zero `FAIL` / `WARN` means the system is correctly wired and the runtime state is as intended.

### OSRF (Open Source Robotics Foundation)

A non-profit organization that maintains ROS, Gazebo, and VRX. They provide the underlying infrastructure this project is built on.

### Leaflet

An open-source JavaScript library for interactive maps (BSD-2-Clause license). Lightweight (~42 KB), mobile-friendly, and widely used. In the dashboard, Leaflet renders the boat's live position, trajectory, and waypoints. It automatically displays attribution at the bottom-right of the map.

### OpenStreetMap (OSM)

A free, collaborative world map, similar in spirit to Wikipedia — edited by volunteers worldwide. Its map tiles are free to use under the **Open Database License (ODbL)**, which **requires attribution** (`© OpenStreetMap contributors`). The dashboard uses OSM tiles as the base layer below the boat's trajectory.

### Real-Time

In robotics, "real-time" usually means "responds fast enough to control actions in a given time window." This project's 20 Hz (50 ms) control loop is "soft real-time" — the OS does not guarantee the timing, but in practice it is consistent enough for a slow-moving boat.

### CLI (Command Line Interface)

The project includes a `autoboat_cli` tool for controlling the mission from a terminal instead of the web dashboard — useful for testing, scripting, or headless operation.

---

## Sensors

### GPS (Global Positioning System)

A satellite-based system that gives you your location on Earth. Provides latitude and longitude. In this project, the simulated GPS publishes to the topic `/wamv/sensors/gps/gps/fix`.

### GNSS (Global Navigation Satellite System)

The general term for satellite positioning systems. GPS (American) is one type of GNSS; others include GLONASS (Russian), Galileo (European), BeiDou (Chinese).

### IMU (Inertial Measurement Unit)

A sensor that measures motion: acceleration, angular velocity, and sometimes magnetic field (like a compass). In this project, the IMU is used mainly for heading — which way the boat is pointing. Publishes to `/wamv/sensors/imu/imu/data`.

### Quaternion

A mathematical way to represent 3D rotations using **4 numbers**: `(x, y, z, w)` in ROS convention — where `(x, y, z)` forms the rotation axis (scaled by sin(θ/2)) and `w` is the scalar part (cos(θ/2)). A unit quaternion satisfies `x² + y² + z² + w² = 1`.

Why 4 numbers for 3D rotation? Because unit quaternions avoid a problem called **"gimbal lock"** that simpler 3-angle representations (like Euler angles) suffer from — at certain orientations, Euler angles lose one degree of freedom.

ROS uses a **right-handed coordinate system** (REP-103): X = forward, Y = left, Z = up. Rotations follow the right-hand rule: point the thumb along the axis, fingers curl in the positive rotation direction.

The IMU publishes orientation as a quaternion on topic `/wamv/sensors/imu/imu/data`. In this project, only the **yaw** angle is extracted using:

```text
yaw = atan2( 2·(w·z + x·y), 1 − 2·(y² + z²) )
```

This gives yaw in radians, where 0 means facing the `+X` direction in the ENU frame.

### Yaw

The rotation around the vertical axis (Z in the right-handed ENU frame). For a boat: **which compass direction its bow is pointing**.

- **Unit:** radians in code, range `−π` to `+π` (ROS convention)
- **Sign:** positive = counterclockwise when viewed from above (right-hand rule around `+Z`)
- **Relation to compass bearing:** compass uses 0° = North, clockwise; ROS yaw uses 0 = `+X` (East in geographic ENU, but can be aligned with North depending on the frame definition)

The three body-frame rotations together are called **Tait-Bryan angles** when using yaw-pitch-roll:

- **Yaw (ψ)** — around Z (up) — "which way is the boat pointing"
- **Pitch (θ)** — around Y (left) — "is the bow tilting up or down"
- **Roll (φ)** — around X (forward) — "is the boat leaning left or right"

In this project, only yaw matters for navigation — the boat is assumed to stay roughly flat on the water surface.

### 3D LiDAR (Light Detection and Ranging)

A sensor that uses laser beams to measure distances to objects around it. A 3D LiDAR sends out laser pulses in many directions and measures how long each takes to bounce back. The result is a 3D "point cloud" — thousands of points representing the shape of the environment. This project's LiDAR produces approximately 30,000 points per scan (1875 horizontal × 16 vertical).

### Point Cloud

A collection of 3D points, each with X, Y, Z coordinates, representing the surface shapes of objects detected by a LiDAR.

---

## Algorithms & Math

### ENU (East-North-Up)

A local coordinate system centred at a reference point, with X pointing East, Y pointing North, and Z pointing Up. Used to convert GPS latitude/longitude into metres — because "5.2 metres east" is easier to work with than "lat 33.83601, lon 151.06972".

In this project there is no dedicated "ENU node" — the conversion is done inline inside the Planner and Controller using the formula:

```text
Δx_East  = delta_lon × R × cos(lat0)
Δy_North = delta_lat × R
```

where `R` = Earth's radius (~6,371,000 m). The first GPS fix received becomes the local origin `(0, 0)`.

### PID Controller (Proportional-Integral-Derivative)

A classic control algorithm. Given the current error (e.g., "the boat is pointing 10° off course"), PID computes a correction based on three things:

- **P** (Proportional): how big the current error is
- **I** (Integral): how much error has accumulated over time
- **D** (Derivative): how fast the error is changing

Used everywhere in engineering, from thermostats to rockets. In this project, PID adjusts thruster power to keep the boat on course. Default gains: `Kp=500`, `Ki=20`, `Kd=150`.

### Kalman Filter

A recursive mathematical algorithm (Rudolf Kalman, 1960) for estimating the true state of a dynamic system when you only have noisy, incomplete measurements. The idea: at every time step you have two sources of information about where the boat *really* is, and you optimally blend them:

1. **Prediction** from a motion model — "if the boat was here last time and was moving in X direction, it should be *about* here now"
2. **Measurement** from a sensor (GPS/IMU/etc.) — "the sensor *says* the boat is *roughly* over there"

Neither source is perfect. The Kalman filter tracks *how uncertain* each one is and combines them with weights proportional to their confidence — the result is provably optimal (minimum mean-squared error) when the noise is Gaussian.

#### Two alternating steps

- **Predict:**

  ```text
  x_new = F · x_old               (project state forward using model F)
  P_new = F · P_old · Fᵀ + Q      (uncertainty grows by process noise Q)
  ```

- **Update (when a measurement z arrives):**

  ```text
  y = z − H · x                   (innovation: how wrong the prediction was)
  S = H · P · Hᵀ + R              (innovation uncertainty = prediction + measurement noise)
  K = P · Hᵀ · S⁻¹                (Kalman gain: optimal blending weight)
  x = x + K · y                   (corrected state)
  P = (I − K · H) · P             (uncertainty shrinks after incorporating measurement)
  ```

#### Key matrices

- `x` — state vector (what we want to estimate)
- `F` — state-transition matrix (how state evolves without measurements)
- `H` — measurement matrix (how state maps to measurements)
- `Q` — process noise covariance (how much we trust our model)
- `R` — measurement noise covariance (how much we trust our sensors)
- `P` — state-covariance matrix (our current uncertainty)
- `K` — Kalman gain (automatically computed blending weight)

**Famous applications:** Apollo 11 guidance computer (original flight use), GPS receivers, radar tracking, autonomous vehicle localization, quantitative finance.

### 2D Linear Kalman Filter (as used in this project)

The specific Kalman filter variant implemented in the Heading Controller to compensate for water-current and wind drift. Unpacking every word:

**"2D"** — The state has **2 dimensions**:

```text
x = [drift_x]      ← eastward drift velocity (m/s)
    [drift_y]      ← northward drift velocity (m/s)
```

Only horizontal drift matters because the boat stays flat on the water — vertical and rotational drift are not estimated.

**"Linear"** — Both the state-evolution function and the measurement function are **linear** (can be expressed as matrix multiplication):

- **F = I** (the 2×2 identity matrix) — this is a **random-walk model**: we assume the drift velocity stays approximately constant from one time step to the next, plus small random perturbations from Q.
- **H = I** (also 2×2 identity) — drift is measured directly (by comparing expected position vs. actual GPS position over time), so the measurement is just the state itself plus noise.

Because both F and H are linear (and actually identity), this project does **NOT need the more complex Extended Kalman Filter (EKF)** which handles non-linear models via Taylor-series linearization at each step.

#### Noise parameters (tunable in YAML)

- `kalman_process_noise: 0.01` — how fast drift is allowed to change between steps (small = smooth, large = responsive)
- `kalman_measurement_noise: 0.5` — how much we distrust the displacement-based drift measurement

**How drift is measured:** at each time step, the Controller computes the positional displacement vector `(Δx, Δy)` over the last interval, subtracts the displacement expected from the commanded thrust and heading, and treats the residual `(dx, dy) / dt` as a noisy measurement of the current drift velocity. This is fed into the Kalman update.

**How drift is used:** the filtered drift vector is subtracted from the target heading calculation, so the boat aims slightly "upstream" to compensate for being pushed sideways.

See **[Design_Rationale](Design_Rationale)** for why linear KF was chosen over EKF.

### A-star (A\*) Path Planning

An algorithm for finding the shortest path from a start point to a goal, avoiding obstacles. It searches a grid of cells, picking the most promising one at each step based on "distance so far + estimated distance to goal". Invented in 1968, still widely used today.

In this project: 8-connected grid, Euclidean heuristic. Default parameters: `astar_resolution: 3.0` m, `astar_safety_margin: 12.0` m, `astar_max_expansions: 20000`.

### Clustering

Grouping similar data points together. In LiDAR processing, nearby points are grouped into "obstacle clusters" — a cluster of many points close together likely represents a single physical object. Default parameters: `cluster_distance: 3.0` m, `min_cluster_size: 8` points.

### Temporal Filtering

A filter that uses the time dimension: only trust an observation if it appears consistently over multiple time steps. This project requires an obstacle to be detected in **2 out of 3** consecutive LiDAR scans before treating it as real — this filters out random noise. Parameters: `temporal_history_size: 3`, `temporal_threshold: 2`.

### Differential Thrust

Steering a two-propeller boat by varying the power of each propeller independently:

```text
left_thrust  = speed − turn_power
right_thrust = speed + turn_power
```

- `left == right` → straight
- `left > right` → turn right
- `left < right` → turn left

---

## Planning Terms

### Waypoint

A specific target location the boat should visit. A mission is usually a sequence of waypoints.

### Lawnmower Pattern (a.k.a. Boustrophedon Coverage)

A back-and-forth path for covering an area — like how a lawn mower moves over grass. Used when you want to systematically cover all of a water surface (e.g., searching or scanning for pollution). Default parameters: 10 lanes × 15 m length × 30 m width.

### Boustrophedon

A Greek word meaning "as the ox turns" (ox ploughing a field). The boustrophedon path is a more optimized version of a lawnmower pattern — it accounts for obstacles by decomposing the area into simpler sub-regions. Boustrophedon coverage planning is listed as future work.

### Detour

An alternative route around an obstacle. In this system, if the boat cannot reach a waypoint directly, it tries a detour before giving up. Default lateral offset: 14 m.

---

## Perception Details

### Water Plane Removal

Removes LiDAR returns from the water surface itself. The Perception node estimates the dynamic water-plane Z using the 5th percentile of all Z values, then drops any point within a tolerance (default `water_plane_threshold: 0.32` m) of that plane. This prevents treating waves/ripples as obstacles.

### Boat Self-Filter

A bounding-box filter that removes LiDAR points that fall inside (or very close to) the boat's own hull. Since the LiDAR is mounted on the boat itself, the twin pontoons and deck would otherwise appear as permanent "obstacles" right in front of the boat, causing the avoidance system to think it is always blocked. This filter is essential for any sensor-equipped boat.

### Hysteresis

A "sticky" detection threshold: once an obstacle is confirmed, the exit threshold is larger than the entry threshold to prevent rapid on/off flickering. Example: detect obstacle at 10 m, release only when clear for > 12 m.

### Sector Analysis (Front / Left / Right)

The Perception node divides the 360° scan into three directional sectors around the boat. For each sector it computes:

- (a) the minimum obstacle distance
- (b) the clearance distance (10th percentile of returns)
- (c) an urgency score (0-1)

The controller uses these three sector summaries instead of processing thousands of raw points.

### Urgency Score

A number 0–1 reflecting how dangerous an obstacle is:

- **0** = safe distance (≥ `perception_min_safe_distance`, default 10 m)
- **1** = critical distance (≤ `perception_critical_distance`, default 5.5 m)
- Linear interpolation in between

The dashboard visualizes this as a progress-bar-style urgency meter.

### Best Gap (VFH Output)

The Perception node scans for the widest clear "gap" between obstacle clusters and reports its centre angle and width. This is the **output** of the VFH algorithm — the direction the boat *could* steer toward if gap-following is active. In the standard demo VFH is kept off; the best-gap data is still published (for visualization/debugging) but the Controller ignores it and uses simpler sector-based avoidance instead.

### VFH (Vector Field Histogram)

An **obstacle-avoidance algorithm** invented by Johann Borenstein and Yoram Koren at the University of Michigan (1991), originally for ground robots but widely adopted for boats, drones, and any vehicle navigating cluttered spaces. The name "vector field histogram" captures two ideas: (1) obstacles are treated as a repulsive "vector field" pushing the robot away, (2) this field is summarized as a **polar histogram** — a 1D graph indexed by heading angle.

#### The core idea in three steps

1. **Build a polar histogram around the robot.** Divide the 360° space around the boat into angular bins (e.g., 5° each = 72 bins). For each bin, sum up the "obstacle density" — points that fall in that direction, weighted by how close they are (closer obstacles contribute more). The result is a histogram: X-axis is heading angle, Y-axis is obstacle density.

2. **Threshold to find openings.** Compare each bin to a threshold. Bins below the threshold are "traversable" — the boat can go that way. Contiguous traversable bins form a **candidate gap** (opening). Each gap has a centre angle and an angular width.

3. **Pick the best gap.** From all candidate gaps, choose the one that balances two criteria: (a) wide enough to fit the boat safely, (b) closest to the current target direction so the boat does not veer off course. The centre of that gap becomes the new steering heading.

**Why it is useful for boats:** traditional "obstacle detected → turn away" reactive methods treat obstacles as point threats. VFH looks at the *structure* of the whole obstacle field, so it handles dense clutter (buoy fields, pier pylons, anchored boats) more gracefully — it can find a *path through* rather than always bouncing away.

#### Variants in literature

- **VFH (1991)** — the original algorithm described above
- **VFH+ (1998)** — adds kinematic constraints (respects vehicle turning radius)
- **VFH\* (2000)** — combines VFH with A\*-style lookahead for more global planning

**In this project:** The Perception node implements a basic VFH-style polar histogram over the LiDAR returns and publishes the best-gap direction in `/perception/obstacle_info`. The Controller has a toggle `use_vfh_bias` that, when enabled, biases the steering command toward that best-gap direction instead of relying purely on the Front/Left/Right sector summary.

**Why it is disabled by default:** in clean worlds like `sydney_regatta_DEFAULT` there are few obstacles, so the simpler 3-sector avoidance is not only sufficient but actually more stable — it has fewer parameters to tune and does not oscillate when the best-gap jumps between two similar openings. VFH shines in cluttered worlds (buoy fields, piers); that is why 3 out of 4 dashboard presets that enable VFH are named for cluttered scenarios.

**Limitations:** VFH is a **local, reactive** method — it reacts to what it sees *now*, with no memory and no global planning. It can get stuck in local minima (dead-end corridors where the widest gap leads the robot back the way it came). That is why VFH is paired with the Planner's global lawnmower path and A\* rerouting — VFH handles "how to squeeze through obstacles locally", the Planner handles "where to go overall".

See **[Design_Rationale](Design_Rationale)** for more on the VFH vs. sector-based trade-off.

---

## Dashboard Concepts

### Mission States

The phases a mission goes through (from `waypoint_planner.py`):

| State | Meaning |
|:------|:--------|
| **INIT** | System starting, waiting for first GPS fix |
| **WAITING_CONFIRM** | Waypoints generated, waiting for user to confirm the plan |
| **READY** | Waypoints confirmed, waiting for Start |
| **DRIVING** | Mission in progress, boat following waypoints |
| **PAUSED** | Mission temporarily stopped by Stop button |
| **JOYSTICK** | Manual control mode, autonomy disabled |
| **EMERGENCY_STOP** | All motion halted by emergency stop |
| **FINISHED** | All waypoints reached |

### HTTP Server (port 8002)

A simple web server that serves the dashboard's HTML/CSS/JavaScript files to the browser. Port 8002 is just a number identifying this particular server (similar to how a phone extension works).

### Navigation Modes (dashboard radio options)

The dashboard lets the operator choose between 3 planning strategies, controlled by two Planner parameters (`astar_enabled` and `astar_hybrid_mode`):

- **Simple Lawnmower** — `astar_enabled: false`, `astar_hybrid_mode: false`. Pure zigzag coverage, no A\* involvement. If blocked, the mission falls back to skipping waypoints only.
- **Runtime A\*** — `astar_enabled: true`, `astar_hybrid_mode: false`. Lawnmower path by default; A\* is called **reactively** only when a waypoint stays blocked for 45+ seconds. **This is the YAML default and the mode used in demos.**
- **Hybrid Mode** — `astar_enabled: true`, `astar_hybrid_mode: true`. A\* **pre-plans** routes between lawnmower waypoints before the mission starts. More expensive than Runtime A\*, and only beneficial when the obstacle field is known up front; otherwise the runtime detour path reacts to whatever the LiDAR actually sees.

The HTML initially shows "Simple Lawnmower" as checked on page load, but the dashboard syncs from ROS config within ~1 second and updates the radio to match the actual runtime value (Runtime A\* by default).

---

## Legacy Module Code-Names (pre-v3.0)

> As of v3.0, modules use functional names: `lidar_perception` (formerly OKO), `waypoint_planner` (formerly SPUTNIK), `heading_controller` (formerly BURAN). The U.S.S.R. space-program names below are retained as historical context.

The original modular navigation system and its modules used U.S.S.R. space-program names as a team naming convention — there is no deep meaning beyond making the modules memorable.

- **Vostok1** (now **AutoBoat**) — the modular navigation system (Vostok = "East" in Russian, also the name of the first human spaceflight).
- **OKO** (now **lidar_perception**) — the perception module (OKO = "eye" in Russian).
- **SPUTNIK** (now **waypoint_planner**) — the planning module (Sputnik = "satellite" or "companion" in Russian, name of the first artificial satellite).
- **BURAN** (now **heading_controller**) — the control module (Buran = "blizzard" in Russian, also the Soviet space shuttle).

---

## See Also

- **[Design_Rationale](Design_Rationale)** — Why design choices were made (trade-offs and justifications)
- **[System_Overview](System_Overview)** — High-level architecture
- **[3D_LIDAR_Processing](3D_LIDAR_Processing)** — LiDAR Perception pipeline in depth
- **[SASS](SASS)** — Anti-stuck recovery system
- **[Common_Issues](Common_Issues)** — Troubleshooting guide
