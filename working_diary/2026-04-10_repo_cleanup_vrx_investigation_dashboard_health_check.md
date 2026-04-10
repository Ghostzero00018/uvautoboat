# 2026-04-10 — Repo Cleanup Round 2, VRX Upstream Investigation, Dashboard Health Check Integration

## Summary

Three major threads today: another pass of repo cleanup (orphans + stale setup.py refs + colcon exclusions), deep investigation of VRX upstream LiDAR/TF bug (issue #876) with a verified partial fix, and a full live-streaming health check panel integrated into the web dashboard.

---

## Problems Detected and Solved

### Repo Cleanup — Round 2

#### Fix 1: Orphan files at repo root

**Files:** `sydney_regatta_map.png`, `test_environment_coordinates.csv`
**Problem:** Both files tracked by git but referenced nowhere in the codebase (no grep hits in any `.py`, `.md`, `.sh`, launch file, or config).
**Fix:** `git mv` both to `legacy/misc/`.

#### Fix 2: Stale `plan/brain/` directory with bytecode only

**Problem:** `plan/brain/` contained only `__pycache__/` with stale `.pyc` files (`oko_perception`, `sputnik_planner`, `vostok1_cli`, etc.) from a removed module. Not tracked by git, no imports anywhere.
**Fix:** `rm -rf plan/brain/` — untracked, no git action needed.

#### Fix 3: Stale setup.py glob references pointing at removed directories

**Files:** `control/setup.py`, `plan/setup.py`
**Problem:** Both packages had `data_files` entries with `glob('launch/*.launch.py')` and `glob('config/*.yaml')` pointing at directories that had been moved to `legacy/` in earlier sessions. The globs returned empty silently but the lines were stale.
**Fix:** Removed the dead glob entries. Also removed now-unused `import os` and `from glob import glob` from `control/setup.py` (still needed in `plan/setup.py` for rviz config glob). Deleted the empty `plan/launch/` directory.

#### Fix 4: Stale `launch/__pycache__/atlantis.launch.cpython-312.pyc`

**Problem:** Bytecode cache from a launch file that had been moved to `legacy/atlantis/` in an earlier session. Untracked (gitignored) but clutter.
**Fix:** `rm -rf launch/__pycache__/`.

#### Fix 5: `environment_plugins` still being built from legacy/

**File:** new `legacy/COLCON_IGNORE`
**Problem:** After earlier sessions moved `environment_plugins/` from `src/uvautoboat/` to `src/uvautoboat/legacy/environment_plugins/`, colcon still discovered it because it scans recursively for `package.xml` and there was no exclusion marker. Every `colcon build` kept rebuilding the retired package, and a stale `build/environment_plugins/CMakeCache.txt` pointed at the old source path causing build failures after the move.
**Symptom:** `CMake Error: The source directory "/home/ghostzero/seal_ws/src/uvautoboat/environment_plugins" does not exist.`
**Fix:** Created empty `legacy/COLCON_IGNORE` marker file; colcon's package discovery now skips the entire `legacy/` tree. Deleted stale `build/environment_plugins/`. Build went from 8 packages to 7, clean.

#### Fix 6: VS Code C/C++ IntelliSense cache bloat (1.1 GB)

**File:** `.vscode/settings.json`
**Problem:** `browse.vc.db` had grown to 1.1 GB because the C/C++ extension was indexing `build/`, `install/`, `log/`, and ROS system headers under `/opt/ros/`. File is `.gitignore`d (`.vscode/` is already ignored) so not a commit concern, but disk bloat + slow IntelliSense startup.
**Fix:** Added `C_Cpp.files.exclude` map to `.vscode/settings.json` excluding `build/`, `install/`, `log/`, `.git/`, `__pycache__/`, `legacy/`, and `/opt/ros/**`. Also capped `C_Cpp.intelliSenseCacheSize` at 1024 MB (default was 5120). Deleted the existing `browse.vc.db` to reclaim space; `.vscode/` is now 16 KB. The cache will regrow on next VS Code session but only with in-workspace sources, not system headers.

---

### Health Check Script — DDS Discovery Lag

#### Fix 7: Node Check and Topic Check falsely reporting FAIL

**File:** `one_click_launch_all/health_check_vostok1.sh`
**Problem:** After running the sim and starting the health check, Node Check reported all 5 core nodes as "not running" and IMU/LiDAR topics as "not found" — while Parameter Check and Topic Publisher Check on the SAME node/topic names reported PASS. Contradiction. Manual `ros2 node list` showed all nodes present with exact expected names.
**Root cause:** DDS discovery lag. The first `ros2 node list` / `ros2 topic list` call after the script starts returns an incomplete snapshot because DDS hasn't finished discovering the graph yet. By the time later checks ran, discovery had converged — which is why the same names worked for `ros2 param get`.
**Fix:** Added a discovery prime at the top of the script — one throwaway `ros2 node list` and `ros2 topic list` call, followed by `sleep 1.5`, before capturing the snapshot. After the fix: 45/45 PASS, 0 FAIL, 0 WARN.

---

### VRX Upstream Investigation — Issue #876 (LiDAR detached from USV)

#### Fix 8: Root cause of ROS TF tree disconnection — `publish_model_pose=false`

**File:** `src/vrx/vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro:94` (upstream)
**Problem:** When running clean upstream VRX (`ros2 launch vrx_gz competition.launch.py world:=sydney_regatta`), LiDAR rays render at world origin `(0,0,0)` instead of following the boat. Existing open issue #876 reports the same symptom.

**Investigation chain:**

1. Confirmed via `ros2 topic echo /wamv/sensors/lidars/lidar_wamv_sensor/points --once` that sensor data is correct — `frame_id: wamv/wamv/base_link/lidar_wamv_sensor`, real point cloud payload.
2. `ros2 run tf2_ros tf2_echo world wamv/wamv/base_link` → fails with `frame does not exist`. `world` is not in the TF tree at all.
3. `ros2 run tf2_tools view_frames` → shows `wamv/wamv/base_link` as a parent of sensors but a child of nothing. Entire WAM-V subtree is dangling.
4. `/wamv/pose` stream (bridged from Gazebo) contains only 7 static sensor-to-link mounting offsets — no world anchor transform.
5. Traced bridge chain: `vrx_gz/src/vrx_gz/bridges.py:40-54` defines `pose()` and `pose_static()` bridge conversions; `vrx_gz/src/vrx_gz/launch.py:366-370` spawns `pose_tf_broadcaster` (C++ class `FramePublisher` in `vrx_ros/src/pose_tf_broadcaster.cc`) to republish ROS pose topic → `/tf`. Pipeline code path is correct.
6. Found the real cause: `wamv_gazebo.urdf.xacro:89-98` configures the `gz::sim::systems::PosePublisher` plugin with `<publish_model_pose>false</publish_model_pose>` — so Gazebo is explicitly told NOT to emit the model root pose. Only `publish_sensor_pose=true` is set, which explains why only sensor mount offsets appear in `/wamv/pose`.

**Fix applied locally:** Changed `publish_model_pose` to `true`, rebuilt `wamv_gazebo` package, relaunched. Result: `/wamv/pose` now gains a new transform each tick with parent `sydney_regatta`, child `wamv`, and live translation values matching the boat's world position. `tf2_echo sydney_regatta wamv` succeeds with real dynamic values.

#### Fix 9: Second VRX bug discovered — naming mismatch `wamv` vs `wamv/wamv/*`

**Problem:** After flipping `publish_model_pose` to `true`, the TF database ends up with **two disconnected subtrees**:

- Tree A: `sydney_regatta → wamv` (from the new model pose flow)
- Tree B: `wamv/wamv/base_link → {all sensor frames}` (from existing sensor pose flow)

`tf2_echo wamv wamv/wamv/base_link` → `Could not find a connection... they are not part of the same tree.`

The PosePublisher emits the model root using the literal model name `wamv`, but sensor frames in `/wamv/pose` use a **double-prefixed** `wamv/wamv/base_link`. A `wamv/` prefix is being prepended somewhere in the bridge chain (not in `pose_tf_broadcaster.cc` itself — confirmed by reading the code; likely in `ros_gz_bridge` namespace handling or gz-sim Pose_V field formatting).

**Workaround verified:** Adding a static identity transform bridges the gap:

```bash
ros2 run tf2_ros static_transform_publisher \
  --x 0 --y 0 --z 0 --roll 0 --pitch 0 --yaw 0 \
  --frame-id wamv --child-frame-id wamv/wamv/base_link
```

After which `tf2_echo sydney_regatta wamv/wamv/base_link/lidar_wamv_sensor` returns live translations matching the boat position + the 1.8 m LiDAR mount height. **The ROS TF chain is complete end-to-end.**

#### Fix 10: Recognized ROS TF bug is SEPARATE from Gazebo GUI rendering bug

**Key realization:** Even after fixing both TF bugs above, the Gazebo GUI window still draws LiDAR rays at world origin. Gazebo's 3D viewport renders sensors from its own internal scene graph, not from ROS TF. So the original issue #876 symptom is actually **two layered bugs**:

- **Bug A (ROS TF disconnection):** Fixed by the two changes above. Affects RViz and any ROS-side consumer.
- **Bug B (Gazebo GUI rendering):** Upstream `gz-sim8` / Harmonic rendering issue, cannot be fixed from VRX side. Belongs in the `gz-sim` tracker.

**Outcome:** Drafted comprehensive comment for issue #876 documenting the two-bug distinction, exact file/line references, concrete command outputs as evidence, and the verified partial fix. Ready to post.

#### Fix 11: Discovered duplicate `optical_frame_publisher` node warning

**File:** `src/vrx/vrx_gz/src/vrx_gz/model.py:119-144` (upstream)
**Problem:** `ros2 node list` emits "nodes in the graph that share an exact name" warning with three identical `/wamv/optical_frame_publisher` entries. Root cause: `model.py` spawns one `optical_frame_publisher` `Node(...)` per `CAMERA` sensor (and two per `RGBD_CAMERA`) but none pass a `name=` argument, so they all register under the default executable name.
**Severity:** Cosmetic — each instance has correct topic remappings, image pipeline works. The warning just makes `ros2 node list` ambiguous.
**Status:** Drafted separate issue for osrf/vrx proposing `name=f'optical_frame_publisher_{sensor_name}'` fix. Not yet posted (prioritizing issue #876 comment first).

---

### Dashboard — Health Check Integration

#### Fix 12: New `health_check_service` ROS node

**File:** new `plan/plan/health_check_service.py`
**Problem:** Running `bash health_check_vostok1.sh` requires a terminal; no way to check system state from the web dashboard.
**Fix:** New ROS 2 node that wraps the shell script:

- Exposes `/health_check/run` (`std_srvs/Trigger`) service
- Runs the script in a background thread (so service returns immediately — rosbridge's default ~5 s service timeout would otherwise fail on the ~10 s script runtime)
- Streams script output line-by-line via `subprocess.Popen` (line-buffered, `stderr` merged to `stdout`)
- Publishes each line to `/health_check/line` (`std_msgs/String`) as it arrives
- Publishes `running` / `ok` / `error` state transitions to `/health_check/status` (`std_msgs/String`)
- Lock prevents concurrent runs; rejects service calls while a check is in progress
- 90-second hard timeout with clean subprocess kill

Registered entry point in `plan/setup.py`. Added to `launch/vostok1.launch.yaml` so the node auto-spawns alongside OKO/SPUTNIK/BURAN.

#### Fix 13: Dashboard Health Check panel

**Files:** `web_dashboard/vostok1/index.html`, `app.js`, `style_merged.css`
**Fix:** New panel between ROS2 Terminal and System Logs with:

- **Run | Lancer** button — calls `/health_check/run` service via `ROSLIB.Service`
- **Clear | Effacer** button — wipes the output
- **Auto-scroll checkbox** — matches the existing ROS2 Terminal / System Logs pattern
- **Status badge** — "Idle" / "Running..." (pulsing blue) / "All OK" (green) / "Issues found" (red) / "Rejected" / "Service failed"
- **Scrollable output container** with live line-by-line streaming

JavaScript architecture:

- `classifyHealthLine(line)` — regex-classifies lines as `pass`/`fail`/`warn-line`/`info`/`section`/`summary`
- `clearHealthOutput()` and `appendHealthLine(raw)` — append-only rendering for live streaming
- `/health_check/line` subscription calls `appendHealthLine` on each incoming message
- `/health_check/status` subscription drives button enable/disable and badge state
- Auto-scroll respects the checkbox state — uncheck mid-run to freeze scroll position while new lines keep arriving at the bottom

CSS:

- `.health-check-container` — explicit `background: #1a1a2e` and `color: #e0e0e0` as defaults (the existing `.terminal-container` rule only set background; text was inheriting dark gray from body, making uncategorized lines invisible)
- High-contrast colors for each category: `#66bb6a` green PASS, `#ef5350` red FAIL (bold), `#ffa726` orange WARN, `#64b5f6` blue INFO, `#81d4fa` light blue section headers, `#ce93d8` purple summary
- `.health-status-badge` with `.running` (pulsing via `@keyframes pulse`), `.ok` (green), `.error` (red) states

**Architecture note:** Started with `subprocess.run` + bulk result publish on a single `/health_check/result` topic. First test hit the rosbridge timeout (~5 s < 10 s script runtime). Switched to pub/sub async pattern with `subprocess.Popen` streaming, which both solved the timeout and naturally enabled live per-line updates.

---

## Still Pending

### From Today

- **Post VRX issue #876 comment** with the Bug A / Bug B distinction and the `publish_model_pose` fix (drafted, not yet posted)
- **Open separate VRX issue for `optical_frame_publisher` duplicate name warning** (drafted, not yet posted)
- **Consider upstream PR to osrf/vrx** flipping `publish_model_pose` to `true` in `wamv_gazebo.urdf.xacro:94` (one-line change, verified locally; depends on maintainer feedback on the issue comment first)
- **Investigate the extra `wamv/` prefix origin** — currently worked around with a static_transform_publisher, but the proper fix is to find where in the bridge chain the double prefix is being introduced (not in `pose_tf_broadcaster.cc`, likely in `ros_gz_bridge` under `PushRosNamespace` or in `gz-sim8` Pose_V frame_id formatting)
- **File separate upstream `gz-sim8` / `gz-rendering` issue** for the Gazebo GUI LiDAR ray rendering bug (Bug B) — not fixable from VRX side
- **Local VRX xacro edit is not committed** — the `publish_model_pose=true` change sits uncommitted in `src/vrx/`; it will be overwritten on the next `git pull` / VRX update. Keep the static_transform_publisher workaround handy until the upstream fix lands

### From Previous Days

- **Obstacle avoidance detour explosion plan** (`~/.claude/plans/bright-cooking-shamir.md`):
  - SPUTNIK: remove premature `detour_waypoint_inserted = False` reset, add detour cap + cooldown, validate detour clearance, choose clearer side, reset counter on advance
  - BURAN: add missing `request_replan()` method (silent AttributeError crasher at line 662), raise `max_avoidance_turn_deg` 20° → 45°, clearance-aware escape side, sync defaults to YAML
  - Dead code: remove unused `pub_detour_request`, `calculate_drift_compensation()`
  - Config sync: YAML + health check
- **LiDAR tuning** — OKO perception parameters for pier/low-obstacle detection
- **Test map check** — verify alignment between dashboard minimap and Gazebo world coordinates
- **Control part check** — BURAN review, VFH steering integration test
- **VFH steering** (`use_vfh_bias`) — remains disabled by default, needs separate testing
- **Pier avoidance** — boat detects pier but struggles to route around its end, deeper A* tuning
- **`max_speed` in BURAN** — parameter fetched but never constrains speed in control loop (intentional or incomplete?)
- **`drift_compensation_gain` in BURAN** — parameter fetched but never used (intentional or incomplete?)
- **`in_hazard_zone()` in SPUTNIK** — method defined but never called (kept as potential utility)
- **`self.start_gps` in `waypoint_visualizer`** — attribute set but never used (kept as potential feature)
- **`self.path_pub` in `waypoint_visualizer`** — publisher created but never published to (kept as potential feature)
- **Dashboard visual polish** — config panel layout (deferred)

---

## Testing

- Build: `colcon build --merge-install` → 7 packages clean after `COLCON_IGNORE`, down from 8
- Health check script: 45/45 PASS, 0 FAIL, 0 WARN after DDS prime fix
- Health check dashboard panel: verified live streaming with colorized output, auto-scroll toggle working
- VRX fix verification: `tf2_echo sydney_regatta wamv/wamv/base_link/lidar_wamv_sensor` returns live dynamic translations tracking boat motion after both `publish_model_pose=true` and the static identity transform are applied
- Gazebo GUI still shows LiDAR rays detached after the ROS TF fix (expected — confirms bug B is separate upstream rendering issue)

---

## Files Modified Today

### Code cleanup

- `control/setup.py` — removed stale `launch/`/`config/` glob entries + unused `os`/`glob` imports
- `plan/setup.py` — removed stale `launch/` glob entries; added `health_check_service` entry point
- `legacy/COLCON_IGNORE` (new) — excludes retired packages from colcon discovery
- Deleted empty `plan/launch/` directory
- Deleted untracked `plan/brain/__pycache__/` and `launch/__pycache__/`

### Orphans moved to legacy

- `sydney_regatta_map.png` → `legacy/misc/`
- `test_environment_coordinates.csv` → `legacy/misc/`

### Health check

- `one_click_launch_all/health_check_vostok1.sh` — added DDS discovery prime at top
- `plan/plan/health_check_service.py` (new) — ROS 2 node wrapping the script with pub/sub streaming
- `launch/vostok1.launch.yaml` — added health_check_service node block

### Dashboard

- `web_dashboard/vostok1/index.html` — new Health Check panel with Run/Clear/auto-scroll controls
- `web_dashboard/vostok1/app.js` — service client, line/status topic subscriptions, classification, append-only rendering
- `web_dashboard/vostok1/style_merged.css` — `.health-check-panel` grid entry + container/line/badge styles with explicit colors

### IDE

- `.vscode/settings.json` — C/C++ IntelliSense exclusions + cache size cap (local only, gitignored)
- Deleted `.vscode/browse.vc.db` (1.1 GB cache, gitignored, will regrow smaller)
