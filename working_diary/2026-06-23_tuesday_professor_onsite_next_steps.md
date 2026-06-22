# Tuesday 23/06/2026 - Professor onsite next-step check

## Purpose

Use the professor onsite window to decide the next practical direction after the 22/06 console / Herelink hotspot observation. Keep this as a decision and clarification day unless the professor explicitly approves a specific live test.

## Starting Context

- Repo should start clean/synced at `ffb212a` or later.
- 22/06 video result: Herelink RTSP transport works at `rtsp://192.168.43.1:8554/fpv_stream` and TCP was clean, but the current stream content is Pi desktop / `rqt_image_view` after starting the Pi camera node, not a direct camera feed. Treat this as a source regression to raise with the professor.
- 22/06 MAVLink result: QGC receives unicast MAVLink from `192.168.43.1:52600` to workstation `192.168.43.160:14550`. QGC owns `14550`; the next read-only telemetry test is QGC MAVLink forwarding to a separate local UDP port and workstation MAVROS on that forwarded port.
- The dashboard remains simulation-first on `/wamv/*`; no real-topic adapter is implemented.
- The Pi RealSense direct dashboard path was already proven on 18/06 via `/camera/camera/color/image_raw`; do not repeat it unless the professor specifically asks.

## Boundaries

- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, real-FCU command path, or dashboard mission/thruster use.
- No code/config/launch/YAML changes unless explicitly approved.
- No combined RealSense + MAVROS co-load on the Pi 5 unless the dedicated `>=5A` supply is confirmed.
- Keep video, MAVLink telemetry, and `/wamv/*` readiness as separate decisions.

## Block A - Repo Guard

- [ ] Run:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If behind, run `git pull --ff-only`, then re-check.
- [ ] If ahead, diverged, or dirty, stop and report.

## Block B - Professor Decision Check

Ask and record:

- [ ] Should Herelink video be restored to direct camera feed, or is Pi desktop / `rqt_image_view` screen capture intentional?
- [ ] If direct camera feed is desired, who changes the Herelink / Pi image-transmission setup?
- [ ] Is the next telemetry test allowed to use QGC MAVLink forwarding to a local UDP port for workstation MAVROS?
- [ ] Which local port should be reserved for the forwarded MAVROS leg? Avoid QGC's `14550`.
- [ ] Should the next work prioritize video-source repair, read-only MAVROS via QGC forwarding, post-update simulation smoke test, or documentation/planning only?
- [ ] Confirm whether any live test is approved today and who runs it.

## Block C - Optional Live Test Only If Approved

Candidate test, read-only only:

```text
QGC receives on 14550 -> QGC MAVLink forwarding to separate local UDP port -> workstation MAVROS -> ROS 2 topics
```

Do not run until the professor and user explicitly approve the live test.

Pass criteria if run:

- [ ] QGC remains connected and telemetry visible.
- [ ] MAVROS connects on the forwarded port without binding QGC's `14550`.
- [ ] `/mavros/state connected: true`.
- [ ] Live `/mavros/imu/data`.
- [ ] Live GPS topic, even if no fix.
- [ ] Battery/status topic if available.
- [ ] Record `ros2 topic info --verbose` QoS for any topic that might feed dashboard/adapter work later.

## Wrap

- [ ] Record professor decisions and exact wording.
- [ ] Keep video-source decision separate from MAVLink-forwarding decision.
- [ ] Keep `/wamv/*` replacement as design-only unless explicitly approved.
- [ ] If docs/diary changed, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-23_tuesday_professor_onsite_next_steps.md
  ```

- [ ] Run the public-repo visibility sweep before any commit.
- [ ] End with bounded next steps.
