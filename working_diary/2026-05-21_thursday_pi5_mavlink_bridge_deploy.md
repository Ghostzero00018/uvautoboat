# 2026-05-21 — Thursday: Pi 5 MAVLink Bridge Deploy + Smoke-Test

## Day pivot — paper-only (21/05 morning)

Live bring-up cancelled — control box (with Pi 5 inside) is at the prof's office; the prof is re-flashing the Pi 5 with a full desktop GUI image. Pi inaccessible for the day. Block A pre-flight cannot run; Blocks B and C are N/A. Day repurposed to paper-only Phase 5 planning per the scaffold's "could pivot to a planning / paper-only day if pre-flight blocks things" contingency — directly continues 20/05/2026 Block D's recorded Thu+ scope ("Phase 5 driver bring-up planning skeleton, paper-only").

**Supervisor-directive reversal noted.** The prof's GUI re-flash supersedes the 13/05/2026 "Pi 5 stays Ubuntu Server headless permanently" supervisor directive — the prof himself initiated the GUI flash, so the headless posture is no longer in force. Re-flash also wipes all 13/05 Pi-side state: ROS 2 Jazzy install, SSH keys, dialout config, `/boot/firmware/config.txt` + `logind.conf` edits. Phase 5 Pi-side bring-up effectively restarts when the box returns. Doc-sweep landed in Block D §D.3 (`wiki/Roadmap.md` §1.1 + §9 + `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites + `Board.md` Last Updated / Document Version / 21/05 Timeline row); past `working_diary/` entries (13/05 / 18/05 / 19/05 / 20/05) left frozen per the append-only rule.

## Day overview (original scaffold intent — preserved as paper reference)

Phase 5 driver bring-up day. Possible main work: deploy a MAVLink-to-ROS 2 bridge on the Pi 5 and verify the deployment can expose autopilot / boat telemetry as ROS 2 topics. This is a revision from the 20/05/2026 wrap hint ("paper-only") — promoting to a live install + smoke-test attempt on the Pi 5.

Route options:

- **Preferred:** `ros-jazzy-mavros` via apt — the ROS 2 build of `mavros` (sometimes referred to as `mavros2`); project-reinforced bridge route per the 20/05/2026 supervisor session.
- **Fallback:** `mavros` built from source against Jazzy — if the apt path is missing or stale.
- **Last resort:** `MAVProxy` + a thin custom / `pymavlink` ROS 2 publisher — `MAVProxy` alone is a router / multiplexer, NOT a bridge; it only enters the ROS ingestion path if paired with a publisher. Today this route is limited to proof-of-life only, not repo integration.

Final route lock-in is a Block A decision based on what is actually available on the Pi 5 / in the Jazzy apt repos.

Naming reminder for the diary: legacy `mavros` was ROS 1 only; the ROS 2 port is the same project (`mavros` repo, ROS 2 branch / release), sometimes called `mavros2` colloquially. The expected apt package name for ROS 2 Jazzy is `ros-jazzy-mavros`; Block A verifies whether it is actually available on the Pi 5.

## Boundaries

- **In scope:** Pi 5 install + configure + smoke-test of a single bridge instance, plus debrief + action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, premature `Board.md` / `wiki/Roadmap.md` edits (defer to Block D). If the `MAVProxy` + `pymavlink` route is selected, any custom publisher stays scratch / throwaway for smoke-test evidence only.
- **Hardware-design pass** (regulated 5A 5V supply, bulk capacitance, USB hub for RealSense) — separate Phase 5 sub-task (D2 from 20/05/2026). Today does NOT depend on it as long as a MAVLink source is reachable (autopilot via UART/USB, or SITL via UDP from another host).
- **Pi 5 OS posture in flux** — prof re-flashing the Pi 21/05/2026 with a full-DE image (supersedes the 13/05/2026 "headless permanently" directive). Today is paper-only regardless; no Pi-side work either way.
- **Validation methodology** Three Ask: still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight + route lock-in (≈ 30 min)

Pre-flight checks:

- [ ] Pi 5 reachable over SSH — record IP / hostname used.
- [ ] ROS 2 Jazzy install on the Pi 5 sourceable; `ros2 doctor` reasonably clean.
- [ ] MAVLink source identified — (a) autopilot connected via UART / USB on the Pi 5, or (b) SITL on another host reachable over the network. Capture endpoint string.
- [ ] If serial route: user in `dialout` group (`groups` includes it); device node visible (`ls /dev/serial/by-id/`, or `ls /dev/ttyUSB*` / `ls /dev/ttyACM*`).
- [ ] Internet on the Pi 5 for apt / pip.

Route lock-in (pick ONE before Block B):

1. `ros-jazzy-mavros` via apt — first preference if the package is available in the Ubuntu 24.04 Jazzy repos.
2. `mavros` built from source against Jazzy — fallback.
3. `MAVProxy` + custom publisher — last resort.

**Outcome:** Pre-flight blocked — Pi 5 inaccessible (control box at prof's office; prof re-flashing with a full desktop GUI image). No SSH, no apt-availability check, no MAVLink-source endpoint identification possible today. Paper-only pivot triggered per the Day pivot note; route lock-in deferred until the Pi returns. Day's effort redirected to Block D paper artifacts (`mavros2` install-path matrix + topic-name scheme alignment) and the directive-reversal doc sweep.

## Block B — Install + configure (≈ 60-90 min)

For the chosen route:

- [ ] Install packages (apt / source / pip) — record exact commands and versions.
- [ ] Configure FCU connection string (`serial:///dev/...:baud`, `udp://:14550@`, etc.) — record exact URL.
- [ ] First launch attempt — capture stdout / stderr verbatim; flag missing deps or plugin-load errors.
- [ ] Iterate on config until the bridge node starts cleanly (no immediate exits, no flood of plugin-load failures).

**Outcome:** N/A — Pi 5 inaccessible; install + configure not attempted. Paper analysis of the three install routes lives in Block D §D.1.

## Block C — Smoke-test (≈ 30 min)

Once a bridge instance is running:

- [ ] `ros2 topic list` — confirm `/mavros/*` (or equivalent) topics appear.
- [ ] `ros2 topic echo /mavros/state` (or the closest equivalent on the chosen route) — confirm heartbeat data flows.
- [ ] Capture one full sample message dump for at least one topic as evidence (paste into Block C Outcome).
- [ ] Optional second-pass: passive read of `/mavros/global_position/raw/fix` or `/mavros/imu/data` (or analogues) to confirm a real telemetry path, not just heartbeat.

**Outcome:** N/A — Pi 5 inaccessible; no bridge instance to smoke-test. The paper-side topic-name shape that the eventual smoke-test will validate lives in Block D §D.2.

## Block D — Paper artifacts + doc-sweep (substantive content for paper-only day)

Original bring-up-day Block D scope (lessons learned / install gotchas / doc-edit decision) does not directly apply on a paper-only day. Today's substantive output lives in §D.1 + §D.2 (paper artifacts continuing 20/05 Block D's recorded "Phase 5 driver bring-up planning skeleton, paper-only" scope) and §D.3 (the headless-directive-reversal doc sweep — the "sharp directional outcome" the original scaffold flagged as a targeted-edit trigger).

### D.1 — `mavros2` install-path matrix (paper)

Three routes ranked. Each gets pre-conditions, commands, pros, cons, when to choose it. Route 1 is the recommended primary; routes 2 and 3 are fallback / last resort.

#### Route 1 — apt `ros-jazzy-mavros` (preferred)

**Pre-conditions.** Pi runs Ubuntu 24.04 LTS (Server / Desktop, aarch64) — both are official Jazzy platforms per REP-2000. ROS 2 Jazzy apt sources registered (`/etc/apt/sources.list.d/ros2.list` pointing at `packages.ros.org/ros2/ubuntu noble main`). Internet egress for apt — Pi-side `archive.ubuntu.com` HTTP egress was OK on 13/05/2026 (`HTTP/1.1 200 OK`) under partial managed IoT egress; `packages.ros.org` still needs live confirmation on the Pi (the 13/05 test covered only the Ubuntu archive, not the ROS apt index). Block A verifies via `sudo apt update` exit code or a direct `curl -I https://packages.ros.org/ros2/ubuntu/dists/noble/Release` before committing to Route 1.

**Commands.**

```bash
sudo apt update
sudo apt install ros-jazzy-mavros ros-jazzy-mavros-extras ros-jazzy-mavros-msgs

# GeographicLib datasets (geoid models for altitude / global-position plugins).
# ~700 MB download; skip if you don't use altitude-conversion plugins,
# accept partial functionality.
sudo /opt/ros/jazzy/share/mavros/install_geographiclib_datasets.sh
```

**Verify.**

```bash
ros2 pkg list | grep mavros        # expect: mavros, mavros_extras, mavros_msgs
ros2 run mavros mavros_node --ros-args -p fcu_url:=udp://:14550@   # quick sanity
```

**Pros.** Official, dependency-managed, version-pinned to Jazzy ABI. Fastest path to a running bridge. Standard `apt upgrade` path for security / bugfix tracking.

**Cons.** Pinned version may lag upstream `mavros` master by weeks-to-months. Less convenient for patching (would need source rebuild on top).

**When.** Default if pre-conditions hold. Confirmed paper-side: `ros-jazzy-mavros` exists in Open Robotics' Jazzy apt index for Tier 1 platforms (aarch64 + amd64 binaries published under `packages.ros.org/ros2/ubuntu noble/main/binary-arm64/`). Block A live confirmation: `apt-cache policy ros-jazzy-mavros` once the Pi is back.

#### Route 2 — source build against Jazzy (fallback)

**Pre-conditions.** Same as Route 1 + colcon + `rosdep` initialized.

**Commands.**

```bash
cd ~/seal_ws/src
git clone https://github.com/mavlink/mavros.git -b ros2
rosdep update
rosdep install --from-paths . --ignore-src -r -y
cd ~/seal_ws
colcon build --packages-up-to mavros mavros_extras --merge-install
source install/setup.bash

# GeographicLib datasets — post-build path:
sudo ~/seal_ws/install/share/mavros/install_geographiclib_datasets.sh
```

**Pros.** Latest features; easy to patch source; pinnable to a specific upstream commit; version-controlled in the workspace.

**Cons.** 10-20 min build time on Pi 5 (single-board ARM, 8 GB RAM). Pulls more build-time dependencies. Ongoing maintenance on each upstream bump.

**When.** Apt route blocked (package missing / stale / patching needed) **or** the Pi runs an OS where Jazzy apt is unavailable (e.g., RPi OS Bookworm — not an officially supported Jazzy platform).

#### Route 3 — MAVProxy + custom `pymavlink` ROS publisher (last resort)

**Pre-conditions.** MAVProxy installed (`pipx install mavproxy` on 24.04 — PEP 668 caveat documented in [`wiki/Pi5_Bringup_Smoke_Test.md`](../wiki/Pi5_Bringup_Smoke_Test.md) §3.2). pymavlink available (via `pipx inject mavproxy pymavlink` or apt `python3-pymavlink`). A Python ROS 2 publisher node written for this project — does not exist today; would be scratch / throwaway for smoke-test evidence only.

**Pros.** Lighter footprint than `mavros` (no large plugin set on the Pi). MAVProxy useful as router for parallel ground-station / QGC consumers regardless of bridge choice.

**Cons.** Reinvents the well-tested `mavros2` topic surface. Custom publisher needs maintenance + test coverage. Per today's scaffold: "limited to proof-of-life only, not repo integration."

**When.** Routes 1 + 2 both fail. Smoke-test-evidence path only — not the production bridge.

#### Decision tree

1. Pi runs Ubuntu 24.04 LTS (Server / Desktop, aarch64) **and** `apt-cache policy ros-jazzy-mavros` shows a candidate version → **Route 1**.
2. Apt missing the package **or** version blocks integration → **Route 2** source build.
3. Both blocked → **Route 3** as scratch / smoke-test evidence only.

#### Pre-flight confirmation checks for live Block A (when Pi returns)

```bash
# Confirm package available
apt-cache policy ros-jazzy-mavros            # candidate version expected
apt-cache show ros-jazzy-mavros | head -40   # depends chain
sudo apt install --dry-run ros-jazzy-mavros  # what apt would actually pull

# Confirm OS + arch + Jazzy install
lsb_release -d                               # Ubuntu 24.04.x LTS expected
dpkg --print-architecture                    # arm64 expected
source /opt/ros/jazzy/setup.bash && ros2 doctor 2>&1 | tail -20
```

### D.2 — Topic-name scheme alignment (paper)

Goal: identify how `mavros2` topic outputs map onto the neutral aliases in `launch/remap.launch.yaml`, so the existing planner / controller / dashboard subscribe transparently whether VRX or real hardware drives the data.

#### Current Layer A (sim → neutral) — `launch/remap.launch.yaml`

When `use_real_hardware:=false`, six `topic_tools/relay` nodes mirror VRX topics to the neutral namespace:

| VRX side | Neutral alias |
|:---------|:--------------|
| `/wamv/sensors/gps/gps/fix` | `/sensors/gps/fix` |
| `/wamv/sensors/imu/imu/data` | `/sensors/imu/data` |
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | `/sensors/lidar/points` |
| `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | `/sensors/camera/image_raw` |
| `/actuators/thrusters/left/cmd` (neutral) | `/wamv/thrusters/left/thrust` (VRX) |
| `/actuators/thrusters/right/cmd` (neutral) | `/wamv/thrusters/right/thrust` (VRX) |

When `use_real_hardware:=true`, Layer A relays are off and the (not-yet-existent) `bridge/low_level_bridge_node` is meant to fill in.

#### `mavros2` published topic surface (typical, on ArduPilot / PX4 — exact set depends on plugin config)

| Topic | Type | Carries |
|:------|:-----|:--------|
| `/mavros/state` | `mavros_msgs/State` | connection / arming / flight mode |
| `/mavros/heartbeat` | `mavros_msgs/Mavlink` | heartbeat passthrough |
| `/mavros/global_position/global` | `sensor_msgs/NavSatFix` | GPS fix in WGS-84 |
| `/mavros/global_position/local` | `nav_msgs/Odometry` | local-frame odometry |
| `/mavros/global_position/compass_hdg` | `std_msgs/Float64` | compass heading (deg) |
| `/mavros/imu/data` | `sensor_msgs/Imu` | fused IMU (orientation + ang. vel + lin. acc.) |
| `/mavros/imu/data_raw` | `sensor_msgs/Imu` | raw IMU (no orientation) |
| `/mavros/imu/mag` | `sensor_msgs/MagneticField` | magnetometer |
| `/mavros/battery` | `sensor_msgs/BatteryState` | battery state |
| `/mavros/rc/in` | `mavros_msgs/RCIn` | RC channel inputs |
| `/mavros/local_position/pose` | `geometry_msgs/PoseStamped` | local-frame pose |

`mavros2` subscribed (input) topics — control side:

| Topic | Type | Effect |
|:------|:-----|:-------|
| `/mavros/setpoint_velocity/cmd_vel_unstamped` | `geometry_msgs/Twist` | velocity setpoint (linear + angular) |
| `/mavros/setpoint_position/local` | `geometry_msgs/PoseStamped` | local position setpoint |
| `/mavros/manual_control/control` | `mavros_msgs/ManualControl` | RC-override-like manual stick input |

Services for arming / mode change: `/mavros/cmd/arming` (`mavros_msgs/CommandBool`), `/mavros/cmd/set_mode` (`mavros_msgs/SetMode`).

#### Phase 5.1+ mapping decision

| Direction | Neutral name | Sim source (Layer A relay) | Real source (Layer B bridge / `mavros2` remap) |
|:----------|:-------------|:---------------------------|:------------------------------------------------|
| GPS | `/sensors/gps/fix` (`NavSatFix`) | `/wamv/sensors/gps/gps/fix` via relay | `/mavros/global_position/global` via launch-time remap in `mavros2` launch |
| IMU | `/sensors/imu/data` (`Imu`) | `/wamv/sensors/imu/imu/data` via relay | `/mavros/imu/data` via launch-time remap in `mavros2` launch |
| LiDAR | `/sensors/lidar/points` (`PointCloud2`) | `/wamv/sensors/lidars/.../points` via relay | dedicated LiDAR ROS driver publishes directly (not via `mavros2` — `mavros2` doesn't carry LiDAR) |
| Camera | `/sensors/camera/image_raw` (`Image`) | `/wamv/sensors/cameras/.../image_raw` via relay | `realsense2_camera_node` (validated 13/05/2026 on Pi 5 D435I) with launch-time remap |
| Thruster L cmd | `/actuators/thrusters/left/cmd` (`Float64`) | relay → `/wamv/thrusters/left/thrust` (sim) | bridge node subscribes Float64, computes + publishes to `/mavros/setpoint_velocity/cmd_vel_unstamped` (Twist) — or `/mavros/manual_control/control` depending on autopilot config |
| Thruster R cmd | `/actuators/thrusters/right/cmd` (`Float64`) | same | same — thrust translation is single-node coordinated (left + right together → one Twist or one ManualControl) |

#### Method choice — relay vs launch-time remap

Two ways to expose `mavros2`'s `/mavros/...` topics under the neutral `/sensors/...` namespace:

- **Launch-time remap** inside a custom `mavros2` launch file:

  ```yaml
  - node:
      pkg: mavros
      exec: mavros_node
      name: mavros
      remappings:
        - { from: "/mavros/global_position/global", to: "/sensors/gps/fix" }
        - { from: "/mavros/imu/data", to: "/sensors/imu/data" }
  ```

- **`topic_tools/relay`** from `/mavros/...` to `/sensors/...` — same pattern as today's Layer A.

**Recommendation: launch-time remap for sensors** (option A). Reasons: (i) no extra node per topic, (ii) latency saved (relay adds sub-ms but it's still a hop), (iii) consistent with the `realsense2_camera_node` pattern where launch-time remap is the idiom. Relay was used for sim because VRX topics are SDF-fixed and we don't control VRX's launch.

For thruster commands, neither approach works as a pure topic-name change — Float64 → Twist requires computation. The Layer B bridge node owns this translation.

#### Layer B bridge node — paper shape

```text
                 /actuators/thrusters/left/cmd  ─┐  (Float64, planner / controller)
                 /actuators/thrusters/right/cmd ─┤
                                                 ▼
                  ┌────────────────────────────────────────┐
                  │  thrust_to_setpoint_bridge_node        │
                  │  (subscribes 2 Float64, publishes 1    │
                  │   Twist to mavros2 setpoint, or 1      │
                  │   ManualControl depending on autopilot │
                  │   config)                              │
                  └────────────────────────────────────────┘
                                                 │
                                                 ▼
                  /mavros/setpoint_velocity/cmd_vel_unstamped   (mavros2 in)
```

Bridge node responsibilities:

1. Subscribe Float64 thrust commands (L + R), buffer most-recent value of each.
2. Publish a coordinated setpoint at fixed rate (e.g., 10 Hz) — the bridge does the L+R → Twist coordination.
3. Optionally accept `/mavros/state` to gate publishing on `armed && mode == AUTO`.
4. Translation function is autopilot-dependent: ArduBoat differential-drive mapping ≠ PX4 RoverPos mapping. Encode as a launch parameter / plugin choice.

Sensor remaps stay inside `mavros2`'s launch file (option A above) and not inside the bridge — keeps the bridge single-purpose.

#### Open items

- Autopilot ID (ArduPilot ArduBoat vs PX4 RoverPos) still unconfirmed — drives the thrust-translation mapping.
- `0–800` VRX thrust scale → real-Newton / PWM mapping target — see [Roadmap §3](../wiki/Roadmap.md#3-phase-5--real-hardware-deployment) Phase 5 Q4 + §8.8 propeller-placement notes (air-propeller efficiency curve differs from submerged-thruster default).
- `mavros2` plugin load list — which plugins to enable on the Pi (default plugin set is heavy; targeted plugin enablement keeps the node light).

### D.3 — Headless-directive reversal + doc-sweep (landed)

Triggering event: the prof's 21/05/2026 Pi-5 re-flash to a full-DE image supersedes the 13/05/2026 "Ubuntu Server headless permanently" supervisor directive (the prof himself initiated the GUI flash, so the headless posture is no longer in force).

Doc-sweep targets identified via `grep -rnIEi 'headless|ubuntu server'` across tracked files. Pi-OS-posture hits in non-frozen tracked prose (2 hits in 2 files): `wiki/Roadmap.md` §1.1 L23 + `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites L34. Plus `Board.md` header / footer bump and a new 21/05 Timeline row (driven by the date itself, not by a stale "headless" claim — the existing "headless" hit at `Board.md` L158 is shore-comms phrasing unrelated to Pi OS posture; Board.md 12/05 + 13/05 Timeline rows are frozen historical entries). Non-Pi-OS-posture false positives confirmed: `wiki/Common_Issues.md` L1099 (Gazebo `gui:=false`), `USER_MANUAL.md` L1478 (launcher `--skip-dashboard`), `wiki/Glossary.md` L117 (`autoboat_cli` vs dashboard distinction), `Board.md` L158 (shore-comms risks-table entry). No edit at any false-positive site.

Edits landed this commit:

- `wiki/Roadmap.md` §1.1 — Pi 5 OS-posture parenthetical revised; the 13/05 "headless permanently" line replaced with a "posture in flux + 21/05 reversal" wording.
- `wiki/Roadmap.md` §9 — new 21/05/2026 revision-log entry.
- `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites — first-line Pi-OS prerequisite rewritten to allow Ubuntu Server / Desktop (officially supported on aarch64 Jazzy) and flag RPi OS Bookworm as forcing source-build.
- `Board.md` — Last Updated 20/05 → 21/05; Document Version 9.14 → 9.15; new 21/05 Timeline row covering the Pi-unavail / paper-pivot / posture-reversal triple.

Files deliberately not touched:

- Past `working_diary/` entries (13/05 / 18/05 / 19/05 / 20/05) — frozen per the append-only rule; the reversal lives forward in 21/05's diary + Board Timeline.
- `Board.md` 12/05 / 13/05 Timeline rows — frozen as historical record; new 21/05 row carries the reversal.
- Code / YAML / shell — paper-only day; no `.py` / `.yaml` / `.sh` edits anywhere.

**Outcome:** D.1 + D.2 paper artifacts captured (`mavros2` install-path matrix with Route 1 / 2 / 3 + decision tree; topic-name scheme alignment between current Layer A relays and `mavros2` outputs, with Layer B bridge shape). D.3 doc-sweep landed: 2 Pi-OS-posture claims revised (`wiki/Roadmap.md` §1.1 L23 + `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites L34), `wiki/Roadmap.md` §9 + `Board.md` header / footer / Timeline updated, 4 non-Pi-OS-posture `headless` mentions confirmed unrelated and left alone. No code / YAML changes. Pre-commit grep sweep clean (run before the wrap commit).

## Block E — Day wrap (≈ 10 min)

- [ ] Final checks: `git status`, `git diff --check`, `rg -n '\[To fill'` over this diary.
- [ ] Fill Block E Outcome BEFORE the wrap commit (19/05/2026 lesson learned: a placeholder slipped into `faa9ba1` and needed a follow-up `3cd8861` correction).
- [ ] Run the standard pre-commit sweep before the wrap commit.
- [ ] Set Fri 22/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (commit subject provided in the wrap; run from repo root after Block E Outcome is filled).

**Outcome.** Day closed paper-only (Pi 5 unavailable at the prof's office for a full-DE re-flash). Block A pre-flight blocked → paper pivot per Day pivot note; Blocks B + C marked N/A — no live Pi. Block D landed paper artifacts (`mavros2` install-path matrix in §D.1; `mavros2` ↔ `launch/remap.launch.yaml` topic-name scheme alignment in §D.2) plus the headless-directive-reversal doc sweep (§D.3): `wiki/Roadmap.md` §1.1 + §9 + `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites + `Board.md` (Last Updated 20/05 → 21/05 + Document Version 9.14 → 9.15 + 21/05 Timeline row) all touched. Past `working_diary/` entries (13/05 / 18/05 / 19/05 / 20/05) left frozen per the append-only rule. Pre-commit grep sweep clean (0 matches across tracked files). No code / YAML / shell changes — paper-only.

Wrap commit subject (candidate, user picks final):

- `docs(diary): wrap 21/05 — Pi unavail, Phase 5 paper + posture sweep` (67 chars)
- `docs(diary): wrap 21/05 Pi unavail + Phase 5 paper + posture reversal` (69 chars)
- `docs: 21/05 Pi unavail → Phase 5 paper + headless directive reversed` (68 chars)

## Afternoon prep — Fast Block A pre-flight checklist (pending Pi return)

Prep drafted 21/05 mid-day: when the prof returns the Pi this late afternoon, run this checklist in order before deciding on Block B install. Built from §D.1 pre-conditions + the OS / setup-state uncertainty introduced by the re-flash. Each step gates the next — stop at the first hard failure and capture evidence.

If the Pi doesn't return today, Fri 22/05 startup picks this checklist up unchanged.

### Step 1 — Identify the OS / image the prof flashed

```bash
cat /etc/os-release          # NAME, VERSION_ID, ID — first source of truth
lsb_release -a 2>/dev/null   # cross-check
dpkg --print-architecture    # expect arm64
uname -a                     # kernel + arch
```

Branch table:

| `/etc/os-release` says | Image | Decision impact |
|:-----------------------|:------|:----------------|
| `ID=ubuntu`, `VERSION_ID=24.04`, no `ubuntu-desktop`/`gnome-session` pkg | Ubuntu Server 24.04 (likely + a lightweight DE if prof installed one) | Tier 1 Jazzy → Route 1 viable |
| `ID=ubuntu`, `VERSION_ID=24.04`, `ubuntu-desktop` / `gnome-session` present | Ubuntu Desktop 24.04 | Tier 1 Jazzy → Route 1 viable; D2 hardware-design pass becomes more load-relevant |
| `ID=debian`, `VERSION_CODENAME=bookworm` (or `/etc/rpi-issue` present) | RPi OS Bookworm | **Not officially supported for Jazzy** → force Route 2 source build, or evaluate snap install |
| Anything else | Unknown | Stop — capture image-ID evidence, escalate to prof |

### Step 2 — Baseline access + Pi-side state

From workstation (Pi IP was `10.120.2.50` pre-reflash on `IoT IMT Nord Europe`; may have changed):

```bash
# Try the old IP first
ssh <user>@10.120.2.50
# If unreachable, scan the subnet
nmap -sn 10.120.2.0/23 | grep -B1 -i 'raspberry\|pi'
```

On the Pi once SSH works:

```bash
hostname                                                          # imtaqua-pi-01 if prof preserved
whoami; id
groups | grep -o dialout                                          # empty = need usermod -a -G dialout
ls -l /dev/serial/by-id/ /dev/ttyUSB* /dev/ttyACM* 2>/dev/null    # autopilot device nodes
# UART enable check (Ubuntu on Pi uses /boot/firmware/config.txt, not /boot/config.txt)
ls /boot/firmware/config.txt 2>/dev/null && \
  grep -E 'enable_uart|dtparam' /boot/firmware/config.txt
# ROS 2 presence
ls /opt/ros/ 2>/dev/null
which ros2 2>/dev/null
source /opt/ros/jazzy/setup.bash 2>/dev/null && ros2 doctor 2>&1 | tail -10
```

Capture in the addendum:

- SSH reachable yes / no — record IP + auth method (key vs password).
- Hostname / user / dialout / UART state.
- ROS 2 Jazzy install present yes / no (and if no, is the apt path available for a fresh install?).
- Autopilot device node visible yes / no — drives Route 1 endpoint string (`serial:///dev/ttyXXX:115200` vs `udp://:14550@`).

### Step 3 — Route 1 viability gate

If Step 1 = Ubuntu Noble **and** Step 2 confirms ROS 2 Jazzy (or fresh-install path open):

```bash
# Live confirmation that packages.ros.org is reachable from the Pi
# (13/05 only proved archive.ubuntu.com; ROS apt index needs its own check)
curl -4 -sI https://packages.ros.org/ros2/ubuntu/dists/noble/Release | head -5
# Alternatively, sudo apt update exit code as the proxy
sudo apt update 2>&1 | tail -10
# Package availability
apt-cache policy ros-jazzy-mavros
apt-cache show ros-jazzy-mavros 2>/dev/null | head -20
sudo apt install --dry-run ros-jazzy-mavros 2>&1 | tail -20
```

Capture: candidate version, dep chain shape, dry-run "N MB will be installed" line.

### Step 4 — Route decision + go / no-go for Block B

| Pre-flight outcome | Route | Next action |
|:-------------------|:------|:------------|
| Ubuntu Noble + ROS apt reachable + `ros-jazzy-mavros` candidate visible | **Route 1** | Block B install per §D.1 — `sudo apt install ros-jazzy-mavros ros-jazzy-mavros-extras ros-jazzy-mavros-msgs` |
| Ubuntu Noble but ROS apt unreachable / package missing | **Route 2** planning | Source build prep notes only today; defer install to Friday |
| RPi OS Bookworm | **Route 2** | Source build on Bookworm; no apt path |
| No stable SSH / no device node / image unknown | **Stop** | Evidence capture only; afternoon-addendum closes with "blocked, escalate to prof" |

### Capture format for the addendum

When this runs, paste the actual command outputs (terse — first 5-10 lines each) into a new subsection under this Block, headed `### Live pre-flight outcome (HH:MM)`. Then either:

- Promote to a follow-on `### Block B — Install attempt` subsection if Route 1 green, or
- Close at evidence-capture per Step 4's table.

Wrap-commit subject for the addendum (per 21/05 mid-day plan): `docs(diary): add 21/05 Pi return pre-flight addendum`.

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Fri 22/05/2026 startup hint depends on Pi 5 availability:

- **If Pi 5 back + freshly flashed by Fri morning:** live Block A pre-flight (apt-cache check for `ros-jazzy-mavros`, ROS 2 install verify on the new OS, MAVLink-source identification, dialout / device-node state). Promote to Block B install (Route 1 by default — see today's §D.1 matrix) if Block A green. The exact Pi-side OS the prof flashed (Ubuntu Desktop / RPi OS Bookworm / Server + DE) drives the Block A install-route confirmation per today's §D.1 decision tree — RPi OS Bookworm forces Route 2 source build; Ubuntu variants keep Route 1 viable.
- **If Pi 5 still at prof's office:** another paper / planning day. Pick up slab 3 (Pi-side `systemd` autostart strategy for the bridge) or slab 4 (hardware-design pass layout sketch — regulated ≥5A 5V supply, bulk caps, USB hub for RealSense decoupling) — both deferred from today.
- **Either path:** revisit the hardware-design pass scope (D2 from 20/05/2026) at week's end; under a full-DE Pi image, D2 is **more** load-relevant than it was under the prior headless-Server posture.
