# 2026-06-02 - Tuesday: pre-meeting final check

## Day overview

Continuing from Mon 01/06/2026 ([`2026-06-01`](2026-06-01_monday_professor_endpoint_or_ppt_refresh.md)).

Repo state coming in should be clean and synced after the 01/06 endpoint-gate wrap. Latest relevant commits before this scaffold:

- `444df00 docs(diary): wrap 01/06 endpoint gate day`
- `612d1c8 docs(diary): record 01/06 Block A and Pi endpoint side check`
- `4278335 docs(diary): scaffold 01/06 professor endpoint window`

Primary work for Tue 02/06/2026 is the final pre-meeting check before the Wed 03/06/2026 10h-12h group / supervisor meeting. The 29/05 repo-side deck story remains the working draft, and the 01/06 side check re-confirmed that no real CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink endpoint was visible from the Pi 5.

Current message to carry into Tuesday:

- Software / onboard-computer preparation is ready to report: Pi 5 baseline, remote desktop access, MAVROS Route 1 installation, camera-path checks, and paper autostart strategy.
- Live MAVROS telemetry remains gated on the real boat-data endpoint. `/mavros/state connected: true` is still the pass condition.
- RealSense evidence remains camera evidence only. `/camera/camera/color/image_raw` and `/camera/camera/imu` do not prove `/mavros/imu/data`.
- The visible deck should stay non-technical and about 4 content pages. Exact device paths, ROS topics, package versions, and endpoint audit details belong in speaker notes.
- Validation methodology is still pending external confirmation and should remain one of the 03/06 decision asks.

## Boundaries

- **In scope:** repo pre-flight; last endpoint availability check if new hardware / professor input appears; final repo-side deck notes; meeting decision asks; short verbal version; Tue / Wed handoff.
- **Out of scope:** Python / YAML edits, broad docs, enabling a Pi-side `systemd` unit, launching MAVROS without a proven endpoint, external weekly diary updates unless explicitly requested, and guessing the Windows `.pptx` path.
- **Endpoint gate:** do not launch MAVROS just to create `/mavros/*` topics. Pass condition is `/mavros/state connected: true`.
- **PPT boundary:** actual `.pptx` lives on the Windows machine. This repo can carry outline / speaker-note text only unless the Windows path is explicitly provided.
- **Thermal / power boundary:** 01/06 idle diagnostics are enough for today unless a new symptom appears. Combined RealSense + MAVLink load testing stays deferred until a real MAVLink endpoint exists.

## Block A - Repo pre-flight + Tuesday branch decision (approx 15-20 min)

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree and branch synced; recent log includes `444df00` (01/06 wrap) and this 02/06 scaffold commit once it lands.

- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [ ] Re-read current anchors:

  ```bash
  sed -n '1,260p' working_diary/2026-06-01_monday_professor_endpoint_or_ppt_refresh.md
  sed -n '1,260p' working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  sed -n '170,185p' Board.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  ```

- [ ] Confirm Tuesday work branch:
  - if a real endpoint path appears, run Block B endpoint proof first;
  - if no endpoint path appears, skip live work and proceed to Block C final meeting prep.
- [ ] Confirm whether the Windows `.pptx` is available. If not, keep work in repo-side Markdown notes only.
- [ ] Do not advance to live MAVROS work until a real endpoint path is visible or explicitly provided.

**Outcome:** [To fill - repo state, endpoint availability, selected branch.]

## Block B - Endpoint proof only if new hardware path appears (approx 30-45 min)

Run this block only if a real physical or network MAVLink path appears or the professor provides a concrete route. Otherwise skip to Block C.

- [ ] Reach the Pi via Remmina / Pi terminal. Confirm clock + ROS env:

  ```bash
  timedatectl status --no-pager
  source /opt/ros/jazzy/setup.bash
  printf "ROS_DISTRO=%s\n" "$ROS_DISTRO"
  which ros2
  ```

- [ ] Confirm no stale MAVROS process:

  ```bash
  pgrep -af 'mavros|ros2 launch mavros' || true
  ```

- [ ] Run the expanded endpoint audit:

  ```bash
  lsusb
  lsusb -t
  ls -l /dev/serial/by-id/* /dev/serial/by-path/* /dev/ttyACM* /dev/ttyUSB* /dev/ttyAMA* /dev/ttyS* /dev/serial0 /dev/serial1 2>/dev/null || true
  ls /dev/ | grep -E 'serial|ttyAMA|ttyS' || true
  sudo dmesg -T | tail -80 | grep -Ei 'usb|tty|acm|cp210|ch34|ftdi|serial|cubepilot|pixhawk|px4|ardupilot|mavlink|cdc' || true
  ss -ulnp | grep -E '14550|14551|14540|5760' || true
  ```

  Note: run interactive `sudo` in the Pi terminal if needed.

- [ ] Classify the endpoint:
  - usable: `/dev/serial/by-id/...`, `/dev/serial/by-path/...`, `/dev/ttyACM*`, `/dev/ttyUSB*`, TELEM-wired UART with wiring confirmation plus byte-flow evidence, or confirmed UDP MAVLink sender / listener;
  - not enough: bare `/dev/ttyAMA10` without TELEM wiring confirmation.
- [ ] Identify firmware / launch profile from label, professor confirmation, Mission Planner / QGroundControl evidence, or heartbeat dump: PX4, ArduPilot, or generic.
- [ ] If and only if endpoint + profile evidence exist, launch MAVROS against that endpoint:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros <px4|apm|node>.launch fcu_url:=serial:///dev/serial/by-id/<device>:115200
  # or: serial:///dev/ttyACM0:115200, serial:///dev/ttyUSB0:115200
  # if UDP confirmed: udp://:14550@
  ```

- [ ] Verify heartbeat:

  ```bash
  ros2 topic echo --once /mavros/state
  ```

  Pass condition: `connected: true`.

- [ ] If heartbeat passes, capture minimal first telemetry where available:

  ```bash
  ros2 topic echo --once /mavros/imu/data
  ros2 topic echo --once /mavros/global_position/global
  ros2 topic echo --once /mavros/battery
  ```

**Outcome:** [To fill - endpoint found y/n, exact path, firmware/profile evidence, heartbeat result.]

## Block C - Final deck notes / meeting story (approx 45-75 min)

Run this block if no live endpoint proof changes the status, or after any live result is known.

- [ ] Confirm whether the Windows `.pptx` is available:
  - if available, transfer / update the visible 4-page story and speaker notes on the Windows machine;
  - if unavailable, keep final copy in this diary as repo-side speaker-note text.
- [ ] Keep visible slides non-technical:
  1. Progress since 20/05.
  2. Current dependency: real boat-data connection path, or telemetry link established if Block B passes.
  3. Ready vs pending.
  4. Decisions requested on 03/06.
- [ ] Keep exact evidence in speaker notes only:
  - Pi 5 baseline and MAVROS install green;
  - endpoint gate: no usable endpoint as of 01/06 unless Block B changes it;
  - `/dev/ttyAMA10` alone is not enough without TELEM wiring confirmation;
  - RealSense camera evidence is separate from boat telemetry;
  - combined RealSense color/depth/IMU remains a future power / USB-stability retest.
- [ ] Keep the decision asks explicit:
  - real autopilot-to-Pi physical path;
  - firmware family / MAVROS launch profile;
  - TELEM UART / USB-UART cable availability;
  - power path for Pi + camera + telemetry load;
  - validation methodology confirmation.

**Outcome:** [To fill - deck notes updated y/n, Windows PPT touched y/n, final story status.]

## Block D - Meeting readiness / rehearsal check (approx 20-30 min)

- [ ] Prepare the short verbal version for a professor unfamiliar with ROS 2:
  - since 20/05, the onboard computer environment and software bridge are ready;
  - the remaining dependency is the real boat-data connection path;
  - camera progress is useful but separate from boat telemetry;
  - the 03/06 meeting should confirm connection, firmware/profile, power path, and validation methodology.
- [ ] If the Windows deck was touched, export / keep a backup PDF on the Windows machine.
- [ ] Decide whether any Wed 03/06 morning edits are needed before the 10h-12h meeting.
- [ ] Complete or explicitly carry the VRX §8.2 weekly cadence check.

**Outcome:** [To fill - readiness status, rehearsal/polish need, VRX cadence status.]

## Block E - Day wrap (approx 20-30 min)

- [ ] Fill Block outcomes.
- [ ] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if live endpoint status, heartbeat, telemetry, or meeting decision state truly changes durable project state;
  - otherwise keep Tuesday as diary-only pre-meeting work.
- [ ] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='(\[[T]o fill|<{7}|={7}|>{7})'
  rg -n "$pattern" working_diary/2026-06-02_tuesday_pre_meeting_final_check.md
  ```

- [ ] Run the standard pre-commit sweep if committing.
- [ ] Set next startup hint for Wed 03/06/2026 meeting day.
- [ ] Commit + push if the diary is closed.

**Outcome:** [To fill - diary closed state, commit subject, next startup hint.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Tue 02/06/2026 startup hint: make one final endpoint / deck branch decision before the Wed 03/06/2026 10h-12h meeting.

- Start with repo pre-flight and current anchors.
- If a real endpoint path appears, run the expanded endpoint audit before any MAVROS launch.
- If `/mavros/state connected: true` is achieved, capture minimal first telemetry and refresh the deck.
- If no endpoint is available, keep the deck focused on work completed since 20/05/2026 and decisions needed.
- Keep exact endpoint evidence in speaker notes only; keep visible slides non-technical.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- Carry validation methodology as a decision ask unless confirmed before the meeting.
