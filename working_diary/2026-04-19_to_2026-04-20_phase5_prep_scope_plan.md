# 2026-04-19 to 2026-04-20 — Phase 5 Hardware-Deployment Prep (Scope Plan)

**Author:** paper-only pre-hardware planning, produced on the Windows laptop. Zero Python / YAML / shell changes in this document — all the deliverables are markdown. Any actual code scaffolding (stub bridge node, real `remap.launch.yaml`) happens on the Linux workstation next week and is explicitly out of scope for this file.

**Target execution window:** 20/04/2026 onward (Week 7), beginning with the supervisor CCU conversation.

**Rationale for doing this now:** Phase 5 (real-hardware deployment) was logged in Board.md on 18/04. The 18-19 dashboard work closed out the VRX-side polish. Between now and when hardware physically arrives, the bottleneck is two unknowns: (1) CCU low-level architecture (pending supervisor conversation) and (2) the inventory of sim-tied topic bindings that will need to be remapped. This scope plan attacks (2) directly so that when (1) resolves, the topic-swap work is mechanical rather than exploratory.

---

## Part 1 — `/wamv/*` Topic Reference Audit

### Method

`grep -rn "/wamv/" --include="*.py" --include="*.yaml" --include="*.yml" --include="*.js" --include="*.html" --include="*.sh" --exclude-dir=legacy --exclude-dir=working_diary --exclude-dir=.git` over the active code tree. Counted matches, dedup'd per topic, cross-referenced with the ROS message types from the docstrings.

### Topic inventory (6 unique topics, 34 references, 9 files)

| Topic | ROS message type | Direction (from boat code) | Consumers / producers |
|:------|:-----------------|:---------------------------|:---------------------|
| `/wamv/sensors/gps/gps/fix` | `sensor_msgs/NavSatFix` | Input (subscribe) | `heading_controller`, `waypoint_planner`, `waypoint_visualizer`, dashboard, health check |
| `/wamv/sensors/imu/imu/data` | `sensor_msgs/Imu` | Input (subscribe) | `heading_controller`, health check |
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | `sensor_msgs/PointCloud2` | Input (subscribe) | `lidar_perception`, health check |
| `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | `sensor_msgs/Image` | Input (subscribe) | Dashboard camera panel via `web_video_server` |
| `/wamv/thrusters/left/thrust` | `std_msgs/Float64` | Output (publish) | `heading_controller`, `keyboard_teleop`, dashboard joystick, health check |
| `/wamv/thrusters/right/thrust` | `std_msgs/Float64` | Output (publish) | `heading_controller`, `keyboard_teleop`, dashboard joystick, health check |

### File-level inventory (active code only)

| File | `/wamv/*` touch-points | Nature |
|:-----|:----------------------:|:-------|
| `control/control/heading_controller.py` | 6 lines (L20-21, L26-27 docstring; L314, L320 subscribe; L361-362 publish) | Core: 2 in / 2 out |
| `control/control/keyboard_teleop.py` | 2 lines (L41-42 publish) | Manual-override thruster publishes |
| `plan/plan/lidar_perception.py` | 2 lines (L28 docstring; L154 subscribe) | LiDAR subscribe |
| `plan/plan/waypoint_planner.py` | 3 lines (L20 docstring; L280 subscribe; L1298 error-message hint) | GPS subscribe + user-visible error text |
| `plan/plan/waypoint_visualizer.py` | 1 line (L60 subscribe) | GPS subscribe |
| `web_dashboard/autoboat/app.js` | 6 lines (L569 camera default; L603 GPS subscribe; L615, L627, L2085, L2091 thruster pub/sub) | Dashboard bus |
| `web_dashboard/autoboat/index.html` | 1 line (L905 camera topic default `value=` + `title=`) | Dashboard UI default |
| `launch/autoboat.launch.yaml` | 1 line (L43 comment in troubleshooting note) | Documentation only |
| `one_click_launch_all/health_check_autoboat.sh` | 8 lines (L136-140 topic-list array; L220-222 `check_publisher` calls) | Health check |
| `one_click_launch_all/launch_autoboat_complete.sh` | 2 lines (L390-391 echoed help text) | Documentation only |

### Grouping by semantic role

**Sensors (inputs to the boat's perception/control stack, 3 topics):**

- `/wamv/sensors/gps/gps/fix` — GPS NavSatFix
- `/wamv/sensors/imu/imu/data` — IMU (orientation + angular velocity + linear acceleration)
- `/wamv/sensors/lidars/lidar_wamv_sensor/points` — 3D LiDAR PointCloud2 (~30,000 points/scan, 1875 × 16)

**Actuators (outputs from the boat's control stack, 2 topics):**

- `/wamv/thrusters/left/thrust` — Float64 thrust command to left thruster
- `/wamv/thrusters/right/thrust` — Float64 thrust command to right thruster

**Auxiliary (1 topic, dashboard-only):**

- `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` — Image, consumed by `web_video_server` to serve MJPEG to the dashboard camera panel

### Observations

1. **No frame-ID dependency beyond the topic names.** A separate `grep -v "/wamv/" | grep "wamv"` turned up only the VRX package names in `patch_vrx.sh` (`wamv_gazebo`, `wamv_3d_lidar`) — nothing in the project code relies on a `wamv`-named TF frame or parameter.
2. **No bidirectional topics.** Every `/wamv/*` topic is either pure-input (sensor) or pure-output (thruster). No request/response services, no actions. Remapping is a straight rename.
3. **Documentation / help-text references (6 lines across launch YAML, launcher script, error message) will NOT break at runtime** if the topic is remapped — they just become stale. Schedule for cleanup after the remap YAML lands.
4. **Dashboard joystick (lines 2085, 2091) is a second thruster publisher path** alongside `heading_controller`. Confirmed during earlier UX work. For real hardware, both paths must go through the same remap / bridge layer.
5. **`keyboard_teleop.py` is the third thruster publisher.** Not in normal launch but exists in the active tree; include in any thruster-side remap to avoid it sending raw `/wamv/*` messages during manual debugging on real hardware.

---

## Part 2 — `remap.launch.yaml` Paper Design

### Design goals

1. **One switch to flip simulation ↔ real hardware.** A boolean launch argument (`use_real_hardware` default `false`) toggles the whole topic namespace. Today's `autoboat.launch.yaml` continues to work unchanged when the flag is false.
2. **Neutral topic names** that do not embed vendor names (`wamv`, `autoboat`, etc.) on the boat-facing side, so the stack is reusable if the WAM-V is ever replaced with a different USV body.
3. **Bridge node is optional.** If the real hardware's low-level controller already speaks ROS 2 with native topic names, the bridge is empty and the remap YAML alone does the job. If the low-level side needs translation (different message types, serial/CAN encoding), the bridge node fills the gap without any node above it knowing.
4. **No changes to `lidar_perception.py` / `waypoint_planner.py` / `heading_controller.py` / `keyboard_teleop.py`.** These continue subscribing to the *original* `/wamv/*` names (to avoid churning 3 months of tested code); the remap layer translates at launch time.

### Proposed neutral topic namespace

| Current VRX topic | Neutral name | Rationale |
|:------------------|:-------------|:----------|
| `/wamv/sensors/gps/gps/fix` | `/sensors/gps/fix` | Drop `/wamv/` prefix + the double-`gps` redundancy |
| `/wamv/sensors/imu/imu/data` | `/sensors/imu/data` | Same pattern |
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | `/sensors/lidar/points` | Drop `wamv_sensor` suffix, use singular `lidar` |
| `/wamv/sensors/cameras/front_left_camera_sensor/image_raw` | `/sensors/camera/image_raw` | Drop `front_left` prefix (our code only uses one camera); drop `_sensor` suffix |
| `/wamv/thrusters/left/thrust` | `/actuators/thrusters/left/cmd` | `actuators` parallel to `sensors`; `cmd` parallel to `fix`/`data` |
| `/wamv/thrusters/right/thrust` | `/actuators/thrusters/right/cmd` | Same |

### YAML skeleton (paper only — do not commit as a runnable file)

```yaml
# launch/remap.launch.yaml (PAPER DRAFT — to be implemented next week on Linux)
#
# Two-layer topic translation:
#   layer A — re-publish from VRX /wamv/* names onto neutral /sensors /actuators names,
#             so the rest of the stack can subscribe / publish in neutral terms.
#   layer B — when on real hardware, bridge neutral names to whatever the physical
#             CCU speaks (details TBD after supervisor conversation).
#
# Today (18-19 April): all three pipeline nodes still use /wamv/* names directly.
# This file becomes the default once the transition is done; today it is opt-in.

launch:
  - arg:
      name: use_real_hardware
      default: "false"
      description: "false = VRX simulation (default), true = real boat"

  - arg:
      name: camera_topic
      default: "/sensors/camera/image_raw"
      description: "Neutral camera topic, served by web_video_server"

  # LAYER A — sensor remaps (input side)
  #
  # Simulation: VRX publishes /wamv/sensors/... → we republish onto /sensors/...
  # Real: the CCU publishes onto /sensors/... directly; this block is a no-op.
  #
  # Implementation: topic_tools/relay per topic, OR a small Python node that
  # subscribes and republishes. topic_tools is simpler if message types match.

  - node:
      pkg: topic_tools
      exec: relay
      name: gps_relay
      args: "/wamv/sensors/gps/gps/fix /sensors/gps/fix"
      condition: "unless $(var use_real_hardware)"
  - node:
      pkg: topic_tools
      exec: relay
      name: imu_relay
      args: "/wamv/sensors/imu/imu/data /sensors/imu/data"
      condition: "unless $(var use_real_hardware)"
  - node:
      pkg: topic_tools
      exec: relay
      name: lidar_relay
      args: "/wamv/sensors/lidars/lidar_wamv_sensor/points /sensors/lidar/points"
      condition: "unless $(var use_real_hardware)"
  - node:
      pkg: topic_tools
      exec: relay
      name: camera_relay
      args: "/wamv/sensors/cameras/front_left_camera_sensor/image_raw /sensors/camera/image_raw"
      condition: "unless $(var use_real_hardware)"

  # LAYER A — actuator remaps (output side)
  #
  # We publish onto /actuators/thrusters/*/cmd; relay mirrors into /wamv/...
  # so Gazebo still sees the commands.

  - node:
      pkg: topic_tools
      exec: relay
      name: thrust_left_relay
      args: "/actuators/thrusters/left/cmd /wamv/thrusters/left/thrust"
      condition: "unless $(var use_real_hardware)"
  - node:
      pkg: topic_tools
      exec: relay
      name: thrust_right_relay
      args: "/actuators/thrusters/right/cmd /wamv/thrusters/right/thrust"
      condition: "unless $(var use_real_hardware)"

  # LAYER B — bridge node (real-hardware only, scaffolding)
  #
  # When use_real_hardware==true, start the bridge. Details TBD after the
  # supervisor CCU conversation. Sketched here as a pass-through.

  - node:
      pkg: bridge
      exec: low_level_bridge_node
      name: low_level_bridge
      condition: "if $(var use_real_hardware)"
```

### Phased rollout (transition plan)

1. **Phase 5.0 (this week): zero code change, stack unchanged.** `autoboat.launch.yaml` keeps `/wamv/*` names directly. Ship this file as `launch/remap.launch.yaml` — unused, documentation-only.
2. **Phase 5.1 (once hardware is on bench):** Flip `use_real_hardware=true`, start the bridge in pass-through mode. Three pipeline nodes are unaware; they still see `/wamv/*` names from the real CCU via the relay layer.
3. **Phase 5.2 (after first mission on water):** Update three pipeline nodes to subscribe to neutral names natively. Delete Layer A relays. Bridge (Layer B) stays.
4. **Phase 5.3 (cleanup):** Update documentation strings, health-check script, launcher echo text to reference neutral topic names. Remove stale `/wamv/*` mentions.

### Rollback path

- **Phase 5.0 broken:** Impossible; no runtime touch.
- **Phase 5.1 broken (hardware refuses commands, sensor values garbage):** `use_real_hardware=false`; back to VRX. The relay-based Phase 5.1 never changes the three pipeline nodes, so the rollback is a single argument flip.
- **Phase 5.2 broken (after pipeline-node native rename):** `git revert` the node-rename commit; bring back the Layer A relays. 3 nodes × ~4 line changes each + the relays are still in the remap YAML.
- **Phase 5.3:** Pure documentation rollback, no rush.

### Risks specific to this design

1. **`topic_tools/relay` adds a small latency (<2 ms in tests elsewhere).** For LiDAR at ~10 Hz and IMU at ~50 Hz this is inconsequential. For a tight heading-controller loop (20 Hz, 50 ms), a 2 ms relay overhead is 4 % of the control period — still acceptable but worth measuring on Pi 5.
2. **`topic_tools/relay` does not preserve QoS profile perfectly.** Sensor data typically uses `SensorDataQoS()` (best-effort, depth 5); the relay default is reliable/depth-10. Monitor `/sensors/lidar/points` drop rate after Layer A lands; if drops > 1 %, switch to a small custom Python relay with explicit QoS, or use `ros2 param set` on the relay.
3. **Camera topic via `web_video_server`** is HTTP-level, not ROS-level, so the relay still needs to exist (the server subscribes to the neutral name).

---

## Part 3 — Phase 5 ICD Placeholder + Bridge-Node Design

### Part 3A — Interface Control Document (placeholder)

This section is intentionally sparse — most rows are TBD pending the supervisor CCU conversation. The structure is in place so filling it in is mechanical.

#### Hardware summary

| Component | Model / type | Confirmed? | Notes |
|:----------|:-------------|:----------:|:------|
| High-level CCU | Raspberry Pi 5 (presumed 8 GB variant) | ✅ | Runs ROS 2 Jazzy + whole stack from this repo |
| Low-level CCU | TBD (STM32? ESP32? direct GPIO PWM? commercial motor controller?) | ❌ | Single largest schedule risk. Drives CCU ICD choices. |
| GPS module | TBD — confirm model and output protocol | ❌ | Need NMEA? Native NavSatFix via driver? |
| IMU module | TBD — 9-DOF? 6-DOF? built into low-level board? | ❌ | Orientation quality impacts heading controller tuning |
| LiDAR | TBD — rotary? solid-state? point count per scan? Hz? | ❌ | VFH parameters (`vfh_block_distance`, bin width, etc.) will need re-tuning |
| Camera | TBD — USB? CSI? IP stream? Ethernet? | ❌ | Feeds web_video_server only |
| Thrusters | TBD — brushless? specific thrust range in Newtons? | ❌ | Affects thrust-scale mapping |
| Power | TBD — battery chemistry, voltage, capacity | ❌ | Drives runtime budgets, thermal envelope |
| Radio / shore-comms | TBD | ❌ | See shore-comms spec task |

#### Topic-level contract (post-Phase-5.2)

| Direction | Topic | Msg type | Publisher | Subscriber | Rate |
|:----------|:------|:---------|:----------|:-----------|:----:|
| Sensor in | `/sensors/gps/fix` | `sensor_msgs/NavSatFix` | CCU | `heading_controller`, `waypoint_planner`, `waypoint_visualizer` | ~5 Hz |
| Sensor in | `/sensors/imu/data` | `sensor_msgs/Imu` | CCU | `heading_controller` | ~50 Hz |
| Sensor in | `/sensors/lidar/points` | `sensor_msgs/PointCloud2` | CCU | `lidar_perception` | ~10 Hz |
| Sensor in | `/sensors/camera/image_raw` | `sensor_msgs/Image` | CCU | `web_video_server` → dashboard | ~5-15 Hz |
| Actuator out | `/actuators/thrusters/left/cmd` | `std_msgs/Float64` | `heading_controller`, `keyboard_teleop`, dashboard joystick | CCU | 20 Hz |
| Actuator out | `/actuators/thrusters/right/cmd` | `std_msgs/Float64` | `heading_controller`, `keyboard_teleop`, dashboard joystick | CCU | 20 Hz |

#### Physical and electrical (TBD — fill during bench work)

| Item | Value | Notes |
|:-----|:------|:------|
| Nominal thruster range (Float64) | TBD — currently 0-800 in software | VRX scale; real hardware likely Newtons or PWM duty |
| Thruster command rate | 20 Hz | Matches the heading-controller tick |
| Max power draw | TBD | Affects battery sizing + runtime |
| Continuous operating temperature | TBD | Passive heatsink sufficient, or active cooling? |
| Ingress protection | TBD | IP67 for the CCU enclosure? |
| Power-cycle recovery time | TBD | SSD boot vs SD boot affects this |

#### Safety

| Mechanism | Implementation | Notes |
|:----------|:---------------|:------|
| Dashboard Emergency Stop | `/planning/mission_command` with `EMERGENCY_STOP` payload | Already wired; proven in VRX |
| Hardware E-Stop | TBD | Physical button on the boat? Radio kill? Both? |
| Watchdog | TBD | Hardware watchdog on the low-level board? Software watchdog on Pi? |
| Geofence | `hazard_enabled: true` in `autoboat.launch.yaml` with test-lake polygon | Existing, needs polygon data for the test site |
| Return-to-home on comms loss | TBD — out-of-scope for first water tests | Future iteration |

### Part 3B — Bridge Node Design (pass-through stub)

The bridge is a small ROS 2 Python node that sits between the neutral `/sensors` / `/actuators` namespace and whatever the physical CCU speaks. In the simplest realistic case it is a pure pass-through; the interesting work is in the not-yet-known low-level protocol.

#### Responsibilities

1. **Actuator translation (out)**: subscribe to `/actuators/thrusters/{left,right}/cmd` (`Float64`), translate to whatever the low-level controller accepts (PWM duty, serial frame, CAN message, etc.), publish / write.
2. **Sensor translation (in)**: if the low-level board publishes sensor data in a non-standard format, translate to `sensor_msgs/*` and publish on the neutral `/sensors/*` namespace. If the low-level board speaks ROS 2 natively with standard message types, this layer is trivially empty.
3. **Health / heartbeat**: emit a `/bridge/status` (`std_msgs/String` JSON) at ~1 Hz with low-level-board reachability, last-command-ack latency, error counters.
4. **Safety propagation**: when the upstream `mission_state` is `EMERGENCY_STOP`, actively command zero-thrust to the low-level board, regardless of what `/actuators/thrusters/*/cmd` says. (Defence in depth — the planner already stops publishing commands on E-Stop, but the bridge should not trust upstream alone.)

#### Pass-through stub structure (Python pseudocode)

```python
# bridge/bridge/low_level_bridge.py  (PAPER DRAFT)
#
# Phase 5.1 form: pure pass-through from neutral names to /wamv/* (so the bridge
# can be developed and tested on the bench without touching the rest of the stack).
#
# Phase 5.2+ form: replaces the right-hand side with serial / CAN / whatever
# the physical CCU actually speaks.

class LowLevelBridge(Node):
    def __init__(self):
        super().__init__('low_level_bridge')

        # INPUT side (from the rest of the stack)
        self.sub_left  = self.create_subscription(Float64, '/actuators/thrusters/left/cmd',  self._on_left,  10)
        self.sub_right = self.create_subscription(Float64, '/actuators/thrusters/right/cmd', self._on_right, 10)

        # OUTPUT side
        #   Phase 5.1: republish onto /wamv/* so the existing Gazebo side works.
        #   Phase 5.2+: replace these publishers with the real serial/CAN writer.
        self.pub_left_raw  = self.create_publisher(Float64, '/wamv/thrusters/left/thrust',  10)
        self.pub_right_raw = self.create_publisher(Float64, '/wamv/thrusters/right/thrust', 10)

        # HEALTH
        self.pub_status = self.create_publisher(String, '/bridge/status', 10)
        self.create_timer(1.0, self._publish_status)

        self._last_left_ts  = None
        self._last_right_ts = None
        self._estop_active  = False

        # Listen for E-Stop from the planner
        self.sub_mstat = self.create_subscription(
            String, '/planning/mission_status', self._on_mission_status, 10)

    def _on_left(self, msg: Float64):
        if self._estop_active:
            msg.data = 0.0
        self.pub_left_raw.publish(msg)
        self._last_left_ts = self.get_clock().now()

    def _on_right(self, msg: Float64):
        if self._estop_active:
            msg.data = 0.0
        self.pub_right_raw.publish(msg)
        self._last_right_ts = self.get_clock().now()

    def _on_mission_status(self, msg: String):
        try:
            state = json.loads(msg.data).get('state', '')
        except json.JSONDecodeError:
            return
        self._estop_active = (state == 'EMERGENCY_STOP')

    def _publish_status(self):
        now = self.get_clock().now()
        payload = {
            'left_cmd_age_s':  (now - self._last_left_ts).nanoseconds / 1e9 if self._last_left_ts else None,
            'right_cmd_age_s': (now - self._last_right_ts).nanoseconds / 1e9 if self._last_right_ts else None,
            'estop_active':    self._estop_active,
            'mode':            'passthrough',
        }
        self.pub_status.publish(String(data=json.dumps(payload)))
```

#### Bench-test plan for the pass-through bridge

1. Launch Gazebo + the existing `autoboat.launch.yaml` — confirm baseline VRX mission works (10/10 waypoints).
2. Launch `remap.launch.yaml` with `use_real_hardware=false` — should behave identically to step 1 (relays are transparent).
3. Launch `remap.launch.yaml` with `use_real_hardware=true` pointing the bridge's output to `/wamv/*` (the pass-through form) — should still behave identically; the bridge is inserted but transparent.
4. Manually publish `/planning/mission_status` with `{"state": "EMERGENCY_STOP"}` during a run — confirm thrusters go to zero within one control tick (<100 ms).
5. Introduce artificial delay to simulate low-level board latency — measure mission-level impact.

Transition from this stub to the real bridge happens only after step 3 is green and the supervisor confirms the low-level protocol.

---

## Part 4 — Supervisor CCU Conversation Checklist

Organised by priority. Take notes directly into the ICD table in Part 3A; each answer unblocks a phase-5 task.

### A. CCU architecture (blocking everything)

1. **Is there a separate low-level controller between the Pi 5 and the thrusters, or does the Pi drive them directly via GPIO PWM?**
   - If direct GPIO: we skip the bridge entirely; the Pi-side thruster driver owns `/actuators/thrusters/*/cmd` directly. The bridge node in Part 3B becomes a no-op we can drop.
   - If separate: see questions 2-5.
2. **If separate: what chip or board?** (STM32 family / ESP32 / Arduino / commercial motor controller / something else.) Need this to pick the right serial / protocol libraries.
3. **What is the physical link?** UART over USB? Native UART? CAN bus? I²C? Something else?
4. **What protocol does it speak?** Custom binary framing / NMEA-like ASCII / micro-ROS / MAVLink / vendor SDK?
5. **Is there an interface control document (ICD), datasheet, or existing firmware source we can read?** Or is reverse engineering from firmware sources needed?

### B. Sensors (drives perception re-tuning)

1. **GPS module** — model, output protocol (NMEA at serial port? Native NavSatFix from a driver node?), expected fix rate (~5 Hz?).
2. **IMU module** — 9-DOF or 6-DOF? Embedded in the low-level board or separate? Magnetometer calibrated? What orientation frame (ENU? NED?) and does it match ROS 2 REP-103 conventions?
3. **LiDAR** — make / model, mechanism (rotary / solid-state), scan rate, point count per scan, angular resolution, range. These directly drive VFH parameter tuning (`vfh_block_distance`, `vfh_bin_width_deg`, etc.).
4. **Camera** — USB / CSI / IP stream? Resolution? Frame rate? Latency budget for the MJPEG path (current VRX ~3 Hz is low because Gazebo is CPU-bound; real camera should be faster).

### C. Actuators (drives thrust-scale mapping)

1. **Thruster type** — brushless motor with ESC? Hobby-grade? Industrial? What input does each thruster expect (PWM duty cycle? PPM? CAN message? DAC voltage?).
2. **Thrust range** — minimum, maximum, reverse-capable? Software currently produces Float64 values 0-800 (VRX scale); what is the mapping to real thrust in Newtons or PWM duty?
3. **Differential-thrust kinematics** — distance between left and right thrusters? Boat mass? These feed into whether the existing PID tuning (`Kp=500, Ki=20, Kd=150`) still holds on real hardware.

### D. Power and thermal (drives runtime planning)

1. **Battery chemistry, voltage, capacity** — drives mission duration budget and whether brown-out protection is needed.
2. **Expected thermal envelope for the Pi 5** — will it need active cooling, or is the ambient at the test site mild enough for passive?
3. **Power-loss behaviour** — is the Pi boot off SD card (corrupts under sudden power-off) or USB 3 SSD (survives)? Is there a shutdown interlock on the physical E-stop?

### E. Safety and shore comms

1. **Physical E-stop** — button location? Radio kill switch? Both? How do they propagate to the thruster-off state (hardware-level interrupt, or software listener?).
2. **Communication range** — expected effective range for WiFi / 2.4 GHz / 5 GHz? Is there a 4G / LTE fallback? What happens to the mission if the dashboard goes offline mid-run — does the boat return to home on its own?
3. **Test lake / field location** — coordinates for the geofence polygon. Depth profile (are there obstacles below waterline?).

### F. Process / timeline

1. **When does the CCU physically arrive?** Drives the timing of the bench-work phase.
2. **Who is doing the bench integration?** — just me, or shared with a teammate / technical support?
3. **Any prior AutoBoat instances** that have gone through this integration? Lessons-learned documents? Photos of the wiring?
4. **Access to the test site** — scheduling, any safety briefing required, weather-dependent constraints?

### G. Deliverables

1. **Demo format** — live water run? Pre-recorded video? Dashboard demo with logs? Supervisor preference shapes what we need to prepare.
2. **Report expectations** — written deliverable at Phase 5 milestone? Format (mid-term-style report, thesis chapter, conference-paper draft)?

---

## Summary and sequencing

| Task | Output | Status | Blocks |
|:-----|:-------|:------:|:-------|
| 1. `/wamv/*` audit | Inventory table (Part 1) | ✅ Done (in this file) | — |
| 2. `remap.launch.yaml` paper design | YAML skeleton + rollout plan (Part 2) | ✅ Done (in this file) | — |
| 3A. Phase 5 ICD placeholder | Structured TBD tables (Part 3A) | ✅ Scaffolding done | Supervisor conversation (§F) |
| 3B. Bridge-node stub design | Python pseudocode + test plan (Part 3B) | ✅ Done | Supervisor conversation for non-trivial bridge |
| 4. Supervisor checklist | 24 questions (Part 4) | ✅ Done | — |

### Ready-to-use artefacts

- **For the Linux workstation next week**: Part 1 gives an exact file/line list to drive the `remap.launch.yaml` implementation; Part 2 gives the YAML structure; Part 3B gives the bridge-node scaffolding.
- **For the supervisor meeting**: Part 4 is a printable checklist. Part 3A is the table to fill during the conversation.

### Next steps after the supervisor conversation

1. Fill Part 3A ICD tables from the conversation notes. Push updates to this same file (append-only; the original prep plan stays unchanged above).
2. Move the `remap.launch.yaml` content from Part 2 into an actual `launch/remap.launch.yaml` file, run it with `use_real_hardware=false`, confirm no regression vs `autoboat.launch.yaml`.
3. Stub the bridge node from Part 3B into `bridge/bridge/low_level_bridge.py` (new package). Launch with `use_real_hardware=true` but bridge still in pass-through mode — should be transparent.
4. Clean up stale `/wamv/*` references in documentation (launch YAML comments, launcher echo lines, error messages in `waypoint_planner.py` line 1298 and similar). Safe to do before hardware arrives because the actual topic names haven't changed yet.

### What this plan explicitly does NOT do

- No commitment on the real-hardware low-level protocol (that waits for the supervisor answer).
- No change to the three pipeline node topic subscriptions (Phase 5.2 work).
- No changes to VFH tuning — that waits for the real LiDAR model.
- No shore-comms protocol choice — that is a separate paper exercise.
- No concrete geofence polygon — needs the test-lake GPS survey.
