# 2026-04-21 to 2026-04-22 — `launch/remap.launch.yaml` Implementation Draft

**Author:** drafted evening of 21/04/2026 as Windows-side pre-work for 22/04/2026 Linux execution. The paper design (goals, rollout phases, rollback paths, risks) lives in the prior scope plan `working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md` Part 2. This draft translates that paper design into an actual file body that can be copy-pasted into `launch/remap.launch.yaml` on the Linux workstation.

**Execution target:** tomorrow's Block 3a on Linux. Estimated ~1 h: ~15 min to create the file, ~15 min to install `topic_tools` if missing, ~30 min VRX smoke test to verify no regression against the current launcher.

**Why this is Windows-safe pre-work:** the draft lives as a markdown code block in `working_diary/`, not as a `.yaml` file. No ROS launch invocation, no build, no YAML-file creation happens tonight. Tomorrow's Linux step is a copy-paste from the code block below into the target path.

---

## Prerequisites (verify on Linux before deploying)

1. **`topic_tools` package** — should already be on the campus workstation (part of standard ROS 2 Jazzy install). Quick check:

   ```bash
   ros2 pkg prefix topic_tools
   # Expected: /opt/ros/jazzy (or similar path). Non-empty output = installed.
   ```

   If missing: `sudo apt install ros-jazzy-topic-tools`.

2. **Clean tree + main repo pulled** (to get any commits from Windows side tonight):

   ```bash
   cd ~/seal_ws/src/uvautoboat
   git status --short   # expect clean
   git pull             # pull tonight's commits (spot-read verdict, this draft)
   ```

3. **VRX functional baseline** — before introducing the remap file, verify the current `autoboat.launch.yaml` still runs a clean mission end-to-end (Buoy Field preset, 10 waypoints, 0 regressions). This is your baseline to compare against.

---

## File Content (copy-paste to `launch/remap.launch.yaml`)

The file below is deployable **as-is** for Phase 5.0 (VRX-only). Bridge-node stanza is conditional and harmless when `use_real_hardware:=false` — the `bridge` package doesn't exist yet, but the `condition: if` guard prevents ROS from trying to start it in simulation mode.

```yaml
# ============================================================================
# AutoBoat — Topic Remap Layer (Phase 5 preparation)
# ============================================================================
#
# Purpose: decouple the active navigation stack from VRX's /wamv/* topic
# names, so the same Python nodes can run against real hardware later
# without code changes. Two-layer translation:
#
#   Layer A — relay nodes translate between /wamv/* (VRX / simulation) and
#             neutral /sensors /actuators namespaces.
#   Layer B — optional bridge node for real-hardware deployment; handles
#             translation between neutral names and whatever the physical
#             control unit speaks (details TBD after hardware arrives).
#
# Rollout phases (see working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md):
#
#   Phase 5.0 (this week):
#     Deploy this file with use_real_hardware:=false.
#     Relays publish neutral names alongside /wamv/* — no behaviour change
#     for the existing stack (three pipeline nodes still subscribe /wamv/*).
#     This is a dry-run: ship the relay layer so it's exercised under VRX
#     before real hardware is on the bench.
#
#   Phase 5.1 (once hardware is on bench):
#     Flip use_real_hardware:=true. Relays off; bridge stub publishes /wamv/*
#     on behalf of the real control unit so the three pipeline nodes still see
#     their expected topic names.
#
#   Phase 5.2 (after first on-water mission):
#     Rename subscriptions in the three Python nodes from /wamv/* to the
#     neutral names. Delete Layer A relays. Bridge (Layer B) stays.
#
#   Phase 5.3 (cleanup):
#     Update documentation strings, health-check script, launcher echo text.
#
# Usage (from workspace root):
#
#   ros2 launch ~/seal_ws/src/uvautoboat/launch/remap.launch.yaml
#   ros2 launch ~/seal_ws/src/uvautoboat/launch/remap.launch.yaml use_real_hardware:=true
#
# This file complements (does not replace) autoboat.launch.yaml. Launch both:
#
#   T3a: ros2 launch autoboat.launch.yaml
#   T3b: ros2 launch remap.launch.yaml
#
# ============================================================================

launch:

  # --- Arguments ----------------------------------------------------------

  - arg:
      name: use_real_hardware
      default: "false"
      description: "false = VRX simulation (default). true = real boat hardware."

  - arg:
      name: log_level
      default: "info"
      description: "Relay logging verbosity (debug | info | warn | error)."

  # --- LAYER A — Sensor remaps (VRX → neutral) ---------------------------
  #
  # When use_real_hardware:=false, Gazebo publishes /wamv/* and these relays
  # mirror the data onto the neutral /sensors/* namespace. Downstream code
  # that subscribes either namespace sees identical data (with sub-ms relay
  # latency; see Known Unknowns below for QoS caveats).

  - node:
      pkg: topic_tools
      exec: relay
      name: gps_relay
      args: "/wamv/sensors/gps/gps/fix /sensors/gps/fix"
      output: screen
      condition: "unless $(var use_real_hardware)"

  - node:
      pkg: topic_tools
      exec: relay
      name: imu_relay
      args: "/wamv/sensors/imu/imu/data /sensors/imu/data"
      output: screen
      condition: "unless $(var use_real_hardware)"

  - node:
      pkg: topic_tools
      exec: relay
      name: lidar_relay
      args: "/wamv/sensors/lidars/lidar_wamv_sensor/points /sensors/lidar/points"
      output: screen
      condition: "unless $(var use_real_hardware)"

  - node:
      pkg: topic_tools
      exec: relay
      name: camera_relay
      args: "/wamv/sensors/cameras/front_left_camera_sensor/image_raw /sensors/camera/image_raw"
      output: screen
      condition: "unless $(var use_real_hardware)"

  # --- LAYER A — Actuator remaps (neutral → VRX) -------------------------
  #
  # Symmetrically, relay neutral /actuators/* thrust commands into the /wamv/*
  # names Gazebo expects. The three-node stack still publishes to /wamv/*
  # directly today, so these relays are effectively idle in the normal path;
  # they become relevant in Phase 5.2 when the stack is renamed to publish
  # neutral names natively.

  - node:
      pkg: topic_tools
      exec: relay
      name: thrust_left_relay
      args: "/actuators/thrusters/left/cmd /wamv/thrusters/left/thrust"
      output: screen
      condition: "unless $(var use_real_hardware)"

  - node:
      pkg: topic_tools
      exec: relay
      name: thrust_right_relay
      args: "/actuators/thrusters/right/cmd /wamv/thrusters/right/thrust"
      output: screen
      condition: "unless $(var use_real_hardware)"

  # --- LAYER B — Real-hardware bridge (stub) -----------------------------
  #
  # This stanza only activates when use_real_hardware:=true. The `bridge`
  # package does not exist yet — it will be scaffolded once the supervisor
  # CCU conversation resolves the low-level protocol. Shape sketched in
  # working_diary/2026-04-19_to_2026-04-20_phase5_prep_scope_plan.md Part 3B.
  #
  # Do NOT flip use_real_hardware:=true in simulation — ros2 launch will
  # fail to find the package and abort the whole launch.

  - node:
      pkg: bridge
      exec: low_level_bridge_node
      name: low_level_bridge
      output: screen
      condition: "if $(var use_real_hardware)"
```

---

## Deploy Workflow (tomorrow, Linux)

### 1. Create the file

```bash
cd ~/seal_ws/src/uvautoboat
# copy the code block above into launch/remap.launch.yaml
ls -la launch/
# expect: autoboat.launch.yaml + remap.launch.yaml
```

### 2. Syntax sanity check

```bash
# No colcon build needed — YAML launch files are interpreted at runtime.
# Quick parse check via Python:
python3 -c "import yaml; yaml.safe_load(open('launch/remap.launch.yaml'))"
# expect: silent exit (0). Any output = YAML syntax error.
```

### 3. Smoke test with `use_real_hardware:=false` (Phase 5.0)

Open a standalone terminal (not one of the launcher's 6) and:

```bash
source ~/seal_ws/install/setup.bash
ros2 launch ~/seal_ws/src/uvautoboat/launch/remap.launch.yaml
# expect: 6 relay nodes start; bridge node stanza skipped (condition false).
# leave this terminal running during the test.
```

In another terminal, launch the full VRX stack normally (`bash launch_autoboat_complete.sh`) alongside the remap layer.

### 4. Verify neutral topics appear

```bash
source ~/seal_ws/install/setup.bash
ros2 topic list | grep -E '^/sensors/|^/actuators/'
# expect 6 lines:
#   /sensors/gps/fix
#   /sensors/imu/data
#   /sensors/lidar/points
#   /sensors/camera/image_raw
#   /actuators/thrusters/left/cmd   (will be idle — nobody publishes here yet)
#   /actuators/thrusters/right/cmd  (same)
```

### 5. Verify relay data flow

```bash
# Pick any sensor with active VRX traffic:
ros2 topic hz /sensors/gps/fix   # expect ~5 Hz (matches /wamv/sensors/gps/gps/fix rate)
ros2 topic hz /sensors/lidar/points  # expect ~10 Hz (matches VRX LiDAR publish rate)
```

If the neutral topics show 0 Hz while the `/wamv/*` counterparts show their normal rate, the relay isn't routing. Check:

```bash
ros2 topic info /sensors/gps/fix  # expect Publisher count: 1
ros2 node info /gps_relay         # expect subscription to /wamv/sensors/gps/gps/fix, publisher on /sensors/gps/fix
```

### 6. Regression test — mission completes end-to-end

Run a normal Buoy Field mission through the dashboard. The navigation stack still subscribes `/wamv/*` directly (Phase 5.0), so the relay layer being present should not change anything downstream.

- Start mission → boat drives normally.
- Complete 10 waypoints → FINISHED state reached.
- Health check in dashboard → no new FAIL / WARN introduced by the relay layer.

If any regression shows up, it's almost certainly one of the Known Unknowns below (most likely QoS on LiDAR).

### 7. Commit

```bash
git status --short   # expect: new launch/remap.launch.yaml
git add launch/remap.launch.yaml
git commit -m "feat: add remap.launch.yaml for Phase 5 topic namespace translation"
git push
```

Commit subject: 66 chars, one-line conventional commit.

---

## Known Unknowns (monitor post-deployment)

These are the 3 specific risks flagged in the original scope plan. Re-check on the Linux workstation during step 5 above:

### A. Relay latency

`topic_tools/relay` adds <2 ms per hop. For LiDAR at 10 Hz and IMU at 50 Hz, inconsequential. For the controller's 20 Hz control loop (50 ms period), 2 ms is 4 % of period — still acceptable but worth measuring. Record via:

```bash
# Compare publish → receive latency:
# Publisher side (VRX-originated):
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points
# Relayed side:
ros2 topic hz /sensors/lidar/points
# Expect both ≈ same Hz. A drop (e.g. 10 Hz → 7 Hz on /sensors/...) = relay is choking.
```

### B. QoS profile mismatch

Sensor data from VRX uses `SensorDataQoS()` (best-effort, depth 5). Default `topic_tools/relay` is reliable / depth 10. For LiDAR this can cause:

- Drops if the subscriber expected best-effort (LiDAR often uses best-effort for high-rate data)
- Latency spikes if the reliable queue backs up

If `/sensors/lidar/points` shows > 1 % drop vs `/wamv/sensors/lidars/...`, switch that one relay to a small custom Python relay with explicit QoS, OR use `ros2 param set /lidar_relay qos_reliability best_effort` (if supported in this topic_tools version).

### C. Camera relay needed for dashboard

`web_video_server` is HTTP-level, not ROS-level. It subscribes a ROS topic and serves MJPEG. If we ever want the dashboard to talk to `/sensors/camera/image_raw` (neutral) instead of the full `/wamv/...` path, the relay must exist and `web_video_server` needs to be pointed at the neutral name. For Phase 5.0 this is cosmetic — dashboard still uses the VRX topic. Update in Phase 5.3.

---

## Rollback

**Phase 5.0 deployment broken** (e.g. YAML syntax error prevents launch):

```bash
rm launch/remap.launch.yaml
git checkout launch/    # only if already committed
```

The existing `autoboat.launch.yaml` is unchanged by this addition, so removing `remap.launch.yaml` returns the workstation to its pre-22/04 state instantly.

**VRX mission regressed after deploying the relay**:

```bash
# Stop the relay launch (Ctrl+C in its terminal). VRX mission continues
# with /wamv/* names as before — no code path in the stack cares about
# /sensors/* or /actuators/* yet.
```

The relay layer is strictly additive for Phase 5.0. Any regression means either a QoS issue (see Known Unknowns B) or an unforeseen side effect — in either case, stopping the relay launch is a zero-risk rollback.

---

## What's NOT in this draft

1. **`bridge` package scaffolding** — the `low_level_bridge_node` executable doesn't exist yet. The stanza is present so `use_real_hardware:=true` is a single flag flip after the package lands; but flipping it today will fail. Package creation waits on the supervisor CCU conversation (low-level protocol determines the bridge's actual behaviour).

2. **Python node subscription renames** (Phase 5.2 work) — no code change to `lidar_perception.py` / `waypoint_planner.py` / `heading_controller.py` subscriber declarations. They keep using `/wamv/*` topic names for now. The renaming is a Phase 5.2 task after Phase 5.1 bench-testing validates the bridge.

3. **QoS overrides on relay nodes** — deferred until measurement (step 5 / Known Unknown B). If LiDAR drops are seen, a follow-up commit introduces either per-relay QoS args or a small Python relay with explicit `SensorDataQoS()`.

4. **Documentation / launcher / health-check updates** (Phase 5.3 work) — the launcher script `one_click_launch_all/launch_autoboat_complete.sh` echoes `/wamv/*` topic names in its help text; the health check script checks publisher counts on `/wamv/*` topics. Updating those to neutral names is Phase 5.3 cleanup and depends on Phase 5.2 landing first.

---

## Verification checklist (for the 22/04 diary entry)

- [ ] File created at `launch/remap.launch.yaml` with the content block above
- [ ] `topic_tools` package confirmed installed
- [ ] YAML parses via `python3 -c "import yaml; yaml.safe_load(...)"`
- [ ] `ros2 launch remap.launch.yaml` starts 6 relay nodes in <3 s
- [ ] `ros2 topic list | grep /sensors/` shows 4 neutral sensor topics
- [ ] `ros2 topic hz /sensors/lidar/points` matches `/wamv/sensors/lidars/...` rate
- [ ] Full VRX mission (Buoy Field, 10 waypoints) completes with no regression
- [ ] Health check reports no new FAIL / WARN
- [ ] Commit + push landed; `git log --oneline -1` shows the `feat:` subject

Checkbox format makes this easy to paste into the 22/04 diary Block 3a section as live-progress evidence.
