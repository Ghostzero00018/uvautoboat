# Friday 19/06/2026 - Web dashboard hygiene and RealSense camera follow-up

## Purpose

Continue the web dashboard hygiene and camera-feed work from 18/06/2026.

Default focus: dashboard / docs hygiene first, camera observation second only if explicitly approved. Keep the work camera-display-side and dashboard-hygiene-side; do not expand into mission/control/write-path validation.

## Starting context

- Current repo state after 18/06 closeout: `main` clean/synced at `f10d059`.
- Recent landed commits:
  - `bed76fe` - dashboard camera-topic warning fix.
  - `a84f65d` - RealSense dashboard testing procedure.
  - `5f8b4f0` - Pipeline C RealSense diary result.
  - `f10d059` - 18/06 diary closeout.
- The dashboard remains simulation-first: it still reads/writes the existing `/wamv/*` topic contract and has no real-topic adapter.
- RealSense camera display path proven 18/06: `Pi RealSense -> workstation DDS -> web_video_server -> dashboard`.
- Proven practical camera profile from 18/06: `enable_depth:=false rgb_camera.color_profile:=424x240x15`.
- Workstation discovery on the IoT network required `ROS_DOMAIN_ID=12`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, `ROS_LOCALHOST_ONLY` unset, and a workstation ROS daemon restart.
- Clean camera-only workstation receive sample stayed near `14.8-15.0 Hz`; the later `10.35 Hz` value during full-stack observation was a gap-skewed cumulative average after one `27.821 s` gap.
- Full simulation-stack coexistence looked okay with only the dashboard Camera panel switched to `/camera/camera/color/image_raw`, but this proves simulation UI coexistence only.
- QGC Block C attribution remains parked for next week as observation-only work.

## Boundaries

- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, Pi upload, real-FCU command, or real-vehicle command path.
- Do not use dashboard mission or thruster controls against the real FCU.
- Live stack / Pi / RealSense / rosbridge / `web_video_server` / browser checks are user-run unless explicitly delegated.
- Keep browser-facing services loopback-only for workstation tests unless there is a deliberate reason to expose them.
- Code/config edits need explicit approval. Markdown/docs edits are allowed if they stay within the dashboard/camera scope.
- `web_video_server --help` is not a safe flag probe; it starts a real server.
- Network sequencing: commit and push any diary/docs edits while still on normal internet WiFi. Switch to `IoT IMT Nord Europe` only for camera observation, and treat restricted egress / blank map tiles as expected unless proven otherwise.

## Block A - Repo guard

- [ ] Run:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If fetch fails while still on normal internet WiFi, stop and report.
- [ ] If behind origin/main, run `git pull --ff-only`, then re-check status.
- [ ] If ahead, diverged, or dirty, stop and report before continuing.
- [ ] Re-read:
  - `working_diary/2026-06-18_thursday_block_c_attribution_followup.md`
  - `wiki/RealSense_Dashboard_Testing.md`
  - `web_dashboard/autoboat/README_autoboat_dashboard.md`
  - `wiki/Dashboard_Security.md`
  - `Board.md` RealSense row
  - `wiki/Roadmap.md` RealSense row

## Block B - Scope / go-no-go

- [ ] Confirm today's goal:
  - docs / hygiene audit only
  - one more camera display observation
  - small approved dashboard UI/code fix
- [ ] Confirm network sequencing:
  - internet WiFi for fetch / commit / push
  - `IoT IMT Nord Europe` only when a live camera observation starts
- [ ] Confirm equipment/network availability if live camera work is planned:
  - Pi 5 on `IoT IMT Nord Europe`
  - workstation on `IoT IMT Nord Europe`
  - RealSense connected to Pi 5
  - browser opened on workstation
- [ ] Ask for explicit approval before any live Pi / RealSense / dashboard stack observation.

## Block C - Dashboard hygiene audit

Main work for the day. Inspect first; edit only after the stale claim or defect is clear.

- [ ] `wiki/RealSense_Dashboard_Testing.md` polish audit:
  - first-run onboarding popup / `localhost` vs `127.0.0.1` origin-storage note
  - whether `ros2 daemon stop/start` should be mandatory or troubleshooting-only
  - AP client-isolation / DDS multicast note for discovery failures
  - optional compressed-image / bandwidth note, only if grounded in current support
  - whether direct MJPEG fallback and blank-panel triage are clear enough
- [ ] `web_dashboard/autoboat/README_autoboat_dashboard.md` audit:
  - simulation-first status
  - manual RealSense topic entry
  - warning for non-discovered topics
  - no real-topic adapter / no real-FCU command path
- [ ] `wiki/Dashboard_Security.md` audit:
  - camera-topic syntax validation vs warning behavior
  - unauthenticated `:8080`, `:9090`, `:8002`
  - loopback-only testing recommendation
  - no overclaim that client-side warning protects direct `web_video_server` requests
- [ ] Dashboard source spot-check if needed:
  - `web_dashboard/autoboat/app.js` camera topic validation / warning path
  - no mission/thruster behavior changes
  - no auth/TLS/WSS changes in this block
- [ ] Record findings as:
  - apply now
  - defer
  - no change needed

## 19/06 Block C dashboard hygiene audit result

Scope today: docs-only dashboard / camera hygiene. No live Pi, RealSense, rosbridge, `web_video_server`, browser, simulation-stack, QGC, MAVROS, or real-FCU check was run. `web_dashboard/autoboat/app.js` was spot-checked only to confirm the existing camera topic validation / warning path.

Apply now:

- `wiki/RealSense_Dashboard_Testing.md` now explains why the workstation ROS daemon restart remains part of W1 for this field check: on 18/06/2026, the workstation only discovered the Pi camera topic after the environment was set and the daemon was restarted.
- `wiki/RealSense_Dashboard_Testing.md` now makes AP client isolation / DDS multicast filtering an explicit troubleshooting branch if the Pi sees `/camera/camera/color/image_raw` but the workstation still does not.
- `wiki/RealSense_Dashboard_Testing.md` now records the `localhost` vs `127.0.0.1` browser-storage split for the first-time guide popup, so it is not mistaken for a dashboard connection fault.
- `web_dashboard/autoboat/README_autoboat_dashboard.md` now points RealSense camera-display checks to `wiki/RealSense_Dashboard_Testing.md` and keeps the simulation-first `/wamv/*` contract / no-real-topic-adapter wording intact.
- `wiki/Dashboard_Security.md` now states loopback-only guidance for all three unauthenticated browser-facing services: dashboard `:8002`, rosbridge `:9090`, and `web_video_server` `:8080`.

Defer:

- No compressed-image / bandwidth recommendation was promoted beyond the current discovered-topic support. The dashboard can list `sensor_msgs/msg/CompressedImage`, but the proven 18/06 RealSense dashboard path used `/camera/camera/color/image_raw` through the MJPEG stream, so a compressed-topic recommendation still needs separate evidence.
- Optional live camera observation, simulation-stack coexistence, and camera-OFF Pi 5 MAVProxy / MAVROS read-only health re-check were not run.

No change needed:

- The dashboard remains simulation-first and still uses the `/wamv/*` topic contract.
- No real-topic adapter is implemented.
- Mission / thruster controls remain out of scope for real-FCU use.
- QGC Block C attribution remains parked for next week as observation-only work.

## 19/06 package-update impact check

Workstation checks:

- `apt list --upgradable` reported no pending packages after the local updates.
- The 18/06/2026 ROS 2 Jazzy update was a large package sync / binary rebuild set, not a distro or repo migration. It included packages directly relevant to this project surface, including `ros-jazzy-rosbridge-server` `2.6.0 -> 2.7.0`, `ros-jazzy-rosbridge-suite` `2.6.0 -> 2.7.0`, `ros-jazzy-web-video-server` rebuilt as `3.1.0-1noble.20260615.150732`, `ros-jazzy-mavros` rebuilt as `2.14.0-1noble.20260615.151804`, `ros-jazzy-mavros-msgs` rebuilt as `2.14.0-1noble.20260615.130828`, `ros-jazzy-ros-gz` rebuilt as `1.0.22-1noble.20260616.074726`, and `ros-jazzy-rviz2` `14.1.20 -> 14.1.22`.
- Installed changelogs show `rosbridge_server` 2.7.0 adds separate publish / subscribe topic glob arguments and an optional EventsExecutor path; the current dashboard docs still use the same `rosbridge_websocket_launch.xml address:=127.0.0.1` shape, so no repo edit is required from this audit.
- Installed changelogs show `web_video_server` remained upstream 3.1.0, with only a timestamped binary rebuild in the installed package; the existing MJPEG URL and loopback bind docs still match the current use.
- Installed changelogs show the current `ros-jazzy-mavros` package is still upstream 2.14.0; the installed binary is a timestamped rebuild. This does not change the documented camera-OFF MAVProxy fanout -> MAVROS `apm.launch fcu_url:=udp://127.0.0.1:14550@` check.
- The 19/06/2026 Gazebo update installed Gazebo Sim 8 packages `8.13.0 -> 8.14.0` (`python3-gz-sim8`, `libgz-sim8`, `libgz-sim8-dev`, `libgz-sim8-plugins`, `gz-sim8-cli`). The local Debian changelog only records `gz-sim8 8.14.0-1 release`.
- Active `gz sim --version` still reports `Gazebo Sim, version 8.11.0` through `/opt/ros/jazzy/opt/gz_tools_vendor/bin/gz`; `/usr/bin/gz` also reports 8.11.0. Treat this as an installed-package update, not proof that the active VRX runtime is using 8.14.0, until a normal simulation smoke test is run.

Project impact:

- No source, launch, dashboard, wiki, or Board change is required solely because of the 18/06 ROS sync or 19/06 Gazebo package update.
- Because rosbridge and Gazebo packages are in the runtime path, the next approved simulation/dashboard run should include a normal launcher smoke test before relying on previous runtime behaviour.
- No camera, MAVROS, or simulation live acceptance was run as part of this update check.

Pi 5 side:

- Pi-side packages were not live-checked in this block. The workstation stayed on `IMT Nord Europe 5G`; the Pi is normally checked on `IoT IMT Nord Europe`, and no WiFi switch / SSH package audit was run.
- Do not infer Pi 5 MAVROS, MAVProxy, or ROS 2 Jazzy update status from the workstation package state. A future Pi-side read-only package check should be run on the Pi itself, separate from camera evidence and before any camera-OFF MAVProxy / MAVROS health re-check.

## 19/06 Pi 5 update-impact live check (camera OFF)

Closes the Pi-side open item above. The read-only MAVProxy / MAVROS / ROS 2 Jazzy update-impact check was run on the Pi 5 itself over `IoT IMT Nord Europe`, with RealSense OFF. Result: PASS, no regression.

- Pi inventory clean: ROS 2 Jazzy, `ROS_DOMAIN_ID=12`, `dpkg --audit` clean, and `apt` reports all packages up to date after `apt update`. No local `~/seal_ws/install` on the Pi, so no colcon rebuild is implied.
- The Pi received the same 18/06/2026 ROS sync as the workstation (one bulk `ros-jazzy` transaction). For the packages checked here, MAVROS stayed upstream `2.14.0` (`ros-jazzy-mavros` / `-extras` / `-msgs`) and `ros-jazzy-ros-base` `0.11.0` / `ros-jazzy-web-video-server` `3.1.0` were same-upstream-version rebuilds (timestamp suffix only); `ros-jazzy-realsense2-camera` bumped `4.57.7 -> 4.58.1` (camera-side / out of scope here). Other ROS dependency packages did move in the sync — patch-level, e.g. `rclcpp` `28.1.18 -> 28.1.21`, `rcl` `9.2.9 -> 9.2.11`, `rmw-fastrtps-cpp` `8.4.3 -> 8.4.4`, `tf2` `0.36.20 -> 0.36.21` — so it is the live MAVROS re-check below, not a rebuild-only assumption, that clears regression risk. `ros-jazzy-rosbridge-server` is not installed on the Pi.
- MAVProxy runs from `pip --user` at `/home/imt-aqua-drone/.local/bin/mavproxy.py`, outside apt, so the ROS sync did not touch it. Its exact version was not captured because the `pipx` probes returned empty; "MAVProxy works" is proven by heartbeat only.
- Serial path clear: `/dev/ttyAMA0` present, `serial-getty@ttyAMA0.service` disabled / inactive, no UDP port contention. MAVProxy reached the FCU at baud `57600`: `Detected vehicle 1:1`, `online system 1`, Mode HOLD.
- MAVROS read-side green: 136 `/mavros/*` topics, `/mavros/state` `connected: true`, live `/mavros/imu/data` (linear acceleration near gravity), and `/mavros/battery` `16.322 V`, `present: true`.
- Cross-machine DDS over `IoT IMT Nord Europe` green: the workstation received the Pi `/dds_check` publisher, then saw 136 `/mavros/*` topics, `/mavros/state` `connected: true`, and live IMU. No AP client isolation observed on this network.
- Expected-open (not regressions): EKF GPS-config waiting, no GPS fix, wrong FCU time, empty RC channels, `system_status: 5` — consistent with the known bench state.

**Next steps:** record the exact MAVProxy / `pymavlink` version on the Pi (`mavproxy.py --version`, `pip show MAVProxy pymavlink`) at the next Pi session; `ros-jazzy-realsense2-camera` `4.58.1` vs latest `4.58.2` is a camera-side patch to revisit when the camera path is in scope.

## 19/06 Cross-machine discovery range pinned in bashrc

Follow-up to the live check: `export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` was added to `~/.bashrc` on both the Pi 5 (host `imtaquadrone-desktop`, confirmed by `tail -3 ~/.bashrc` showing the appended line plus a live `echo`; this post-dates the saved test-log capture, whose bashrc paste ends at `ROS_DOMAIN_ID=12`) and the workstation, so new interactive terminals inherit the cross-machine discovery range and no longer need the per-terminal export the DDS leg used. Both `~/.bashrc` ROS blocks now match: source ROS 2 Jazzy, `ROS_DOMAIN_ID=12`, `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`. The lines sit below the interactive guard, so the values apply to interactive terminals only; non-interactive SSH one-liners and systemd units do not inherit them. `wiki/RealSense_Dashboard_Testing.md` updated to note the pinned default.

## 19/06 EOD closeout

Actual work today was docs-only plus a read-only Pi-side live check: the Block C dashboard / camera hygiene audit, the workstation and Pi 5 package-update impact check, the camera-OFF Pi 5 MAVProxy / MAVROS / ROS 2 Jazzy update-impact live check (PASS, no regression), the cross-machine discovery-range bashrc pinning above, and the durable-doc notes added to `Board.md` and `wiki/Roadmap.md`. Optional Blocks D and E (live camera observation, simulation-stack coexistence) were not run. The Block C note that the camera-OFF MAVROS health re-check was not run is block-scoped wording for that earlier block; the 19/06 Pi 5 update-impact live check above supersedes it for the day.

## Block D - Optional camera observation

Run only if explicitly approved. **Not run today (docs-only session).**

Use `wiki/RealSense_Dashboard_Testing.md` as the canonical recipe. Do not duplicate the command sequence here.

Capture only:

- [ ] Pi launch profile used.
- [ ] Whether `/camera/camera/color/image_raw` appears on the workstation before opening the dashboard.
- [ ] `ros2 topic info --verbose /camera/camera/color/image_raw` reliability line.
- [ ] `timeout 20 ros2 topic hz /camera/camera/color/image_raw` result.
- [ ] Whether the dashboard dropdown lists the topic or manual entry is needed.
- [ ] Warning/no-warning behavior after Refresh.
- [ ] Direct MJPEG URL result.
- [ ] `web_video_server` request log.
- [ ] `ss -tlnp | grep -E ':(8002|8080|9090)\b'` bind result.
- [ ] Any long gaps, panel stalls, deadlock signs, or browser hard-refresh needed.

Do not use dashboard mission or thruster controls during this block.

## Block E - Optional simulation-stack coexistence check

Run only if explicitly approved after Block D or instead of Block D. **Not run today.**

- [ ] Start normal simulation/dashboard stack.
- [ ] Change only the dashboard Camera panel topic to `/camera/camera/color/image_raw`.
- [ ] Keep all mission/thruster controls within the simulation context only.
- [ ] If a simulated mission is run, record it as simulation UI coexistence only.
- [ ] Do not claim real-boat mission, QGC upload, Herelink acceptance, MAVROS telemetry, or real-FCU command/write validation.

## Wrap

Day wrapped: repo documentation plus a read-only Pi-side live check (camera OFF). No repo code/config changed; the only config touched was `~/.bashrc` on the Pi and the workstation. The edited-docs checks and the public-repo visibility sweep ran clean, and the two-commit split (durable docs + diary) is prepared. Only commit + push remain; do them after switching back to normal internet WiFi.

- [x] Record whether today was docs-only, camera observation, or small approved fix. — repo docs + a read-only Pi-side live check (camera OFF).
- [x] Record exact commands / snippets used for any live claim. — captured in the sections above and the saved Pi test log.
- [x] If docs were edited, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" <edited-files>
  ```

- [x] Run the public-repo visibility sweep before any commit. — clean.
- [x] Keep commit scope split:
  - dashboard/docs changes separate from diary changes
  - diary-only commit uses `docs(diary): ...`
- [ ] Commit and push while still on internet WiFi. — pending, final step.
- [x] End with bounded next steps and no stale completed action.
