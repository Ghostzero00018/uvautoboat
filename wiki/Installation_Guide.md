# Installation Guide

Complete guide to installing AutoBoat and its dependencies.

---

## System Requirements

| Component | Minimum | Recommended |
|:----------|:--------|:------------|
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| RAM | 8 GB | 16 GB |
| Storage | 40 GB | 60 GB |
| Python | 3.10+ | 3.10+ |
| GPU | Integrated | Dedicated (for Gazebo) |

---

## Prerequisites

Before installing AutoBoat, you need to install the following dependencies:

### 1. ROS 2 Jazzy

Follow the official installation guide:

- **[ROS 2 Jazzy Installation](https://docs.ros.org/en/jazzy/Installation.html)**

```bash
# Quick install (Ubuntu 24.04)
sudo apt update
sudo apt install ros-jazzy-desktop-full
```

### 2. Gazebo Harmonic

Follow the official installation guide:

- **[Gazebo Harmonic Installation](https://gazebosim.org/docs/harmonic/install_ubuntu/)**

```bash
# Quick install
sudo apt-get update
sudo apt-get install gz-harmonic
```

### 3. VRX Simulation

Clone the VRX repository:

- **[VRX GitHub Repository](https://github.com/osrf/vrx)**

```bash
cd ~/seal_ws/src
git clone https://github.com/osrf/vrx.git
```

### 4. rosbridge-suite

Required for web dashboard WebSocket communication (port 9090). This is the actively maintained official ROS package — **not** [ros2-web-bridge](https://github.com/RobotWebTools/ros2-web-bridge), which was archived in 2025.

```bash
sudo apt install ros-jazzy-rosbridge-suite
```

### 5. web_video_server

Required for dashboard camera panel (MJPEG streaming on port 8080):

```bash
sudo apt install ros-jazzy-web-video-server
```

---

## Installation Steps

### Step 1: Create Workspace

```bash
mkdir -p ~/seal_ws/src
cd ~/seal_ws/src
```

### Step 2: Clone AutoBoat Repository

```bash
git clone https://github.com/Ghostzero00018/uvautoboat.git
```

### Step 3: Clone VRX (if not already done)

```bash
git clone https://github.com/osrf/vrx.git
```

### Step 4: Install Dependencies

```bash
cd ~/seal_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -r -y
```

### Step 5: Build Workspace

```bash
colcon build --merge-install
```

**Note**: This may take 5-10 minutes on first build.

### Step 6: Source Environment

```bash
source ~/seal_ws/install/setup.bash
```

### Step 7: Set Up ~/.bashrc

Add the following block to the **end** of `~/.bashrc` so every new terminal is
ready. Adjust the workspace path if yours differs from `~/seal_ws`:

```bash
# --- ROS 2 / AutoBoat environment ---
source /opt/ros/jazzy/setup.bash
source ~/seal_ws/install/setup.bash
export GZ_SIM_RESOURCE_PATH="$HOME/seal_ws/src/uvautoboat/test_environment:${GZ_SIM_RESOURCE_PATH}"
# export ROS_DOMAIN_ID=56   # Uncomment and pick a team-wide value (0-232)
```

Then apply it:

```bash
source ~/.bashrc
```

> **Do NOT add** `export GZ_VERSION=harmonic`, `export SDF_PATH=...`,
> `export GZ_SIM_SYSTEM_PLUGIN_PATH=...`, or `export GAZEBO_MODEL_PATH=...`.
> These are unnecessary for this project and can cause Gazebo model/plugin
> resolution failures.

**Verify:**

```bash
echo $ROS_DISTRO              # → jazzy
echo $AMENT_PREFIX_PATH       # → .../seal_ws/install/...
echo $GZ_SIM_RESOURCE_PATH    # → .../test_environment:...
```

---

## Verification

### Verify ROS 2 Installation

```bash
ros2 --version
# Expected: ros2 cli version: 0.32.x
```

### Verify Gazebo Installation

```bash
gz sim --version
# Expected: Gazebo Sim, version 8.x.x
```

### Verify AutoBoat Installation

```bash
ros2 pkg list | grep plan
ros2 pkg list | grep control
```

You should see `plan` and `control` packages listed.

### Test Launch VRX

```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
```

You should see the Gazebo simulator open with the Sydney Regatta world and WAM-V boat.

---

## Troubleshooting

### Build Failures

If you encounter build errors, try a clean build:

```bash
cd ~/seal_ws
rm -rf build install log
colcon build --merge-install
```

### Missing Dependencies

```bash
rosdep update
rosdep install --from-paths src --ignore-src -r -y
```

### Gazebo Plugin Errors

Verify your Gazebo resource path includes the project's test_environment:

```bash
echo $GZ_SIM_RESOURCE_PATH
# Should contain: .../uvautoboat/test_environment
# If not, check your ~/.bashrc (see Step 7 above)
```

### Python Package Issues

Install additional Python packages if needed:

```bash
pip3 install numpy matplotlib
```

---

## Next Steps

Once installation is complete:

- **[Quick Start](Quick_Start)** — Launch your first mission

---

## Additional Resources

- **[ROS 2 Jazzy Tutorials](https://docs.ros.org/en/jazzy/Tutorials.html)**
- **[Gazebo Harmonic Tutorials](https://gazebosim.org/docs/harmonic/tutorials)**
- **[VRX Installation Guide](https://github.com/osrf/vrx/wiki/installation)**
