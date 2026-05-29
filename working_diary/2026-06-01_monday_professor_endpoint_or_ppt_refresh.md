# 2026-06-01 - Monday: professor endpoint window or PPT refresh

## Day overview

Continuing from Fri 29/05/2026 ([`2026-05-29`](2026-05-29_friday_ppt_prep_for_03_june_meeting.md)).

Repo state coming in should be clean and synced after the 29/05 PPT-prep diary close. Latest relevant commits before this scaffold:

- `7516666 docs(diary): record 29/05 PPT prep story`
- `ff161ee docs(diary): scaffold 29/05 PPT prep for 03/06 meeting`
- `a037ebb docs: wrap 28/05 Pi endpoint gate + RealSense viewers`

Primary work for Mon 01/06/2026 is the professor window before the Wed 03/06/2026 10h-12h group / supervisor meeting. Treat the 29/05 PPT material as a working draft. If the professor visit provides a real CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink path, use the day to prove the endpoint first and then refresh the deck's current-dependency slide. If no endpoint path appears, do not force a MAVROS launch; keep the deck focused on work completed since 20/05/2026 and decisions needed.

Current message to carry into Monday:

- Since the 20/05/2026 meeting, the onboard computer environment was restored, remote desktop access works, MAVROS Route 1 installation is green, the camera path was retested, and a paper autostart strategy exists.
- The 03/06/2026 deck should stay about 4 non-technical content pages, with exact ROS / device evidence in speaker notes.
- The deck is not final until after the Mon 01/06/2026 / Tue 02/06/2026 professor window, because CubePilot / MAVROS endpoint status may change.
- RealSense camera evidence remains separate from boat telemetry. `/camera/camera/color/image_raw` and `/camera/camera/imu` do not prove `/mavros/imu/data`.

## Boundaries

- **In scope:** repo pre-flight; professor-side endpoint confirmation; expanded endpoint audit if hardware appears; first MAVROS heartbeat only against a proven endpoint; PPT slide refresh if endpoint status changes; concise meeting decision asks.
- **Out of scope:** Python / YAML edits, broad docs, enabling a real Pi-side `systemd` unit, controller integration, and external weekly diary updates unless explicitly requested.
- **Access preference:** Remmina / Pi terminal first. Avoid SSH unless Remmina is unavailable or a shell-only check is explicitly needed.
- **MAVROS gate:** do not launch MAVROS just to create `/mavros/*` topics. Pass condition is `/mavros/state connected: true`.
- **PPT boundary:** actual `.pptx` lives on the Windows machine. This repo can carry outline / notes; do not guess external deck paths.
- **Deck posture:** today's draft should stay easy to update. If endpoint status changes on 01/06 or 02/06, revise the deck before the 03/06 meeting.

## Block A - Repo pre-flight + Monday scope decision (approx 15-20 min)

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree and branch synced; recent log includes `7516666` and this scaffold commit if it has already been committed.

- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [ ] Re-read current anchors:

  ```bash
  sed -n '1,220p' working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  sed -n '170,205p' Board.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  sed -n '1,280p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  ```

- [ ] Confirm Monday work branch:
  - professor / hardware present and endpoint work possible;
  - or no hardware path yet, so PPT refresh / meeting prep only.
- [ ] Confirm whether the Windows `.pptx` is available today. If not, keep working in repo-side Markdown only.
- [ ] Do not advance to live MAVROS work until a real endpoint path is visible or explicitly provided.

**Outcome:** [To fill - repo state, professor/window status, selected branch.]

## Block B - Endpoint proof if professor hardware path appears (approx 30-45 min)

Run this block only if a real physical or network MAVLink path is present or the professor provides a concrete connection route. Otherwise skip to Block C.

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

  Note: run interactive `sudo` in the user's real Pi terminal if needed.

- [ ] Classify the endpoint:
  - usable: `/dev/serial/by-id/...`, `/dev/serial/by-path/...`, `/dev/ttyACM*`, `/dev/ttyUSB*`, TELEM-wired UART with wiring confirmation, or confirmed UDP MAVLink sender / listener;
  - not enough: bare `/dev/ttyAMA10` without TELEM wiring confirmation.
- [ ] Identify firmware / launch profile from label, professor confirmation, Mission Planner / QGroundControl evidence, or heartbeat dump: PX4, ArduPilot, or generic.

**Outcome:** [To fill - endpoint found y/n, exact path, firmware/profile evidence, proceed to heartbeat y/n.]

## Block C - Live heartbeat or PPT refresh (approx 45-90 min)

Live branch, only after Block B proves a real endpoint:

- [ ] Launch MAVROS with the confirmed endpoint and profile:

  ```bash
  source /opt/ros/jazzy/setup.bash
  ros2 launch mavros <px4|apm|node>.launch fcu_url:=serial:///dev/serial/by-id/<device>:115200
  # or: serial:///dev/ttyACM0:115200, serial:///dev/ttyUSB0:115200
  # if UDP confirmed: udp://:14550@
  ```

- [ ] If no heartbeat on first try, attempt only evidence-based variants: alternate baud, alternate confirmed endpoint, or alternate profile if firmware evidence is uncertain.
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

  If GPS / battery data is absent or zeroed, record it honestly.

PPT branch, if endpoint remains unresolved or after live result is known:

- [ ] Update the 4-page deck story from the 29/05 diary:
  1. Progress since 20/05.
  2. Current dependency to confirm, or first telemetry result if resolved.
  3. Ready vs pending.
  4. Decisions requested on 03/06.
- [ ] Keep visible slides non-technical. Put exact topic names, device paths, package versions, and audit results in speaker notes.
- [ ] If endpoint is resolved, revise slide 2 from "current dependency" to "telemetry link established" and update slide 4 decision asks.
- [ ] If endpoint is still unresolved, keep the deck focused on completed work and decisions needed without overloading visible slides with endpoint audit detail.

**Outcome:** [To fill - live heartbeat result or PPT refresh result.]

## Block D - Meeting readiness check (approx 20-30 min)

- [ ] Confirm whether the Windows `.pptx` has been updated.
- [ ] If the deck was touched, export / keep a backup PDF on the Windows machine.
- [ ] Prepare the short verbal version for a professor unfamiliar with ROS 2:
  - since 20/05, the onboard computer and software bridge are ready;
  - the next dependency is the real boat-data connection path;
  - camera progress is useful but separate from boat telemetry;
  - the 03/06 meeting should confirm connection, firmware/profile, power path, and validation methodology.
- [ ] Decide whether Tue 02/06/2026 needs a final deck polish / rehearsal pass.
- [ ] Carry VRX §8.2 weekly cadence check to Tue 02/06/2026 unless it is completed today.

**Outcome:** [To fill - deck status, rehearsal/polish need, Tuesday follow-up.]

## Block E - Day wrap (approx 20-30 min)

- [ ] Fill Block outcomes.
- [ ] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if live endpoint status, heartbeat, or telemetry truly changes durable project state;
  - otherwise keep Monday as diary-only presentation / endpoint-prep work.
- [ ] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='(\[[T]o fill|<{7}|={7}|>{7})'
  rg -n "$pattern" working_diary/2026-06-01_monday_professor_endpoint_or_ppt_refresh.md
  ```

- [ ] Run the standard pre-commit sweep if committing.
- [ ] Set next startup hint for Tue 02/06/2026 or Wed 03/06/2026.
- [ ] Commit + push if the diary is closed.

**Outcome:** [To fill - diary closed state, commit subject, next startup hint.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Mon 01/06/2026 startup hint: use the professor window to resolve or re-confirm the CubePilot / MAVROS endpoint before finalizing the Wed 03/06/2026 deck.

- Start with repo pre-flight and current anchors.
- If a real endpoint path appears, run the expanded endpoint audit before any MAVROS launch.
- If `/mavros/state connected: true` is achieved, capture minimal first telemetry and refresh the deck.
- If no endpoint is available, keep the deck as a working draft focused on work completed since 20/05/2026 and decisions needed.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
