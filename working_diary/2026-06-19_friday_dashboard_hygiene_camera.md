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

## Block D - Optional camera observation

Run only if explicitly approved.

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

Run only if explicitly approved after Block D or instead of Block D.

- [ ] Start normal simulation/dashboard stack.
- [ ] Change only the dashboard Camera panel topic to `/camera/camera/color/image_raw`.
- [ ] Keep all mission/thruster controls within the simulation context only.
- [ ] If a simulated mission is run, record it as simulation UI coexistence only.
- [ ] Do not claim real-boat mission, QGC upload, Herelink acceptance, MAVROS telemetry, or real-FCU command/write validation.

## Wrap

- [ ] Record whether today was docs-only, camera observation, or small approved fix.
- [ ] Record exact commands / snippets used for any live claim.
- [ ] If docs were edited, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" <edited-files>
  ```

- [ ] Run the public-repo visibility sweep before any commit.
- [ ] Keep commit scope split:
  - dashboard/docs changes separate from diary changes
  - diary-only commit uses `docs(diary): ...`
- [ ] Commit and push while still on internet WiFi.
- [ ] End with bounded next steps and no stale completed action.
