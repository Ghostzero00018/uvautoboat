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

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree and branch synced; recent log includes `7516666` and this scaffold commit if it has already been committed.

- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [x] Re-read current anchors:

  ```bash
  sed -n '1,220p' working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  sed -n '170,205p' Board.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  sed -n '1,280p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  ```

- [x] Confirm Monday work branch:
  - professor / hardware present and endpoint work possible;
  - or no hardware path yet, so PPT refresh / meeting prep only.
- [x] Confirm whether the Windows `.pptx` is available today. If not, keep working in repo-side Markdown only.
- [x] Do not advance to live MAVROS work until a real endpoint path is visible or explicitly provided.

**Outcome:** Block A complete on 01/06/2026. Repo pre-flight was green after `git fetch --prune`: `git log --oneline -5` began with `4278335`, `eb60028`, `7516666`, `ff161ee`, and `a037ebb`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `4278335cfe509ab83b22eeef662754978d29980d` for both refs. No push or pull was needed.

Current anchors were re-read from the 01/06 and 29/05 diary entries, `Board.md`, `wiki/Roadmap.md`, and the 28/05 endpoint-gate diary. They still show the same live gate: install and camera evidence are separate from boat telemetry, and no confirmed CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink endpoint is visible in the repo evidence. No concrete endpoint path was provided in today's startup context, so the selected branch is PPT refresh / meeting prep only. MAVROS remains gated until a real endpoint path is visible or explicitly provided.

The actual Windows `.pptx` path was not provided in this Linux repo session, so work stays in repo-side Markdown outline / notes. Carry forward: validation methodology is still pending external confirmation, and VRX §8.2 weekly cadence next check remains Tue 02/06/2026 unless completed today.

### Side check - Pi 5 routine health and endpoint gate evidence

This was a routine Pi 5 check under the Block A / PPT branch, not a Block B endpoint-proof start. No real CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink path was provided, so MAVROS was not launched.

Pi 5 baseline from `imt-aqua-drone@imtaquadrone-desktop`:

- Host / OS: `imtaquadrone-desktop`, Ubuntu `24.04.4 LTS`, kernel `6.8.0-1057-raspi`, `arm64`.
- Clock / network: `timedatectl` showed `System clock synchronized: yes`, `NTP service: active`; `wlan0` was up at `10.120.2.162/23`; `eth0` was down.
- Resources: uptime was about 4 min at first check; memory headroom was good (`15Gi` total, about `14Gi` available); root filesystem was `58G` total, `22%` used.
- ROS 2: `ROS_DISTRO=jazzy`, `ros2` resolved to `/opt/ros/jazzy/bin/ros2`; idle graph showed only `/parameter_events` and `/rosout`.
- Stale process check: no `mavros`, `ros2 launch mavros`, `realsense2_camera_node`, `component_container`, or `rs_launch` process was reported.

Endpoint gate:

- USB tree showed root hubs, SiGma keyboard `1c4f:0027`, Intel RealSense D435i `8086:0b3a`, and Logitech mouse `046d:c08b`.
- RealSense D435i was on USB 3 SuperSpeed (`5000M`) in `lsusb -t`. This is USB-layer evidence only; it does not prove combined color/depth/IMU stability.
- Serial sweep found only `/dev/ttyAMA10`; no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial0`, or `/dev/serial1`.
- `/dev` serial-name grep returned only `ttyAMA10`.
- Filtered `sudo dmesg -T` showed no CubePilot / Pixhawk / PX4 / ArduPilot / MAVLink / CDC ACM / CP210x / FTDI evidence.
- UDP check showed no listener on `14550`, `14551`, `14540`, or `5760`.

Verdict: endpoint gate remains unchanged from the 22/05 `connected: false` launch test, 27/05 audit, and 28/05 Block A audit. USB remains the unambiguous path if a data cable / adapter appears. A TELEM-to-GPIO-UART path will not create a new device node; it needs physical wiring confirmation plus byte-flow evidence on the identified UART. `/dev/ttyAMA10` alone is still insufficient.

Thermal / power diagnostics:

- Idle temperature settled in the high 60s: `68.85 C`, `68.3 C`, then `67.2 C`. This is acceptable for idle, but leaves limited headroom for the future combined RealSense + MAVLink load test.
- `vcgencmd` was present on `PATH`, but both `get_throttled` and `measure_temp` failed because `/dev/vcio` was unavailable. Do not create `/dev/vcio` manually for today's endpoint / PPT path.
- Non-root `dmesg` was blocked by the Ubuntu kernel log restriction; `sudo dmesg` is the right form.
- Filtered `sudo dmesg -T` showed only normal thermal-governor boot registration and `mmc0/mmc1: cannot verify signal voltage switch`. The MMC lines are an SD / eMMC I/O signalling-speed footnote, not Pi supply under-voltage evidence.
- No under-voltage, throttling, thermal-trip, `vcio`, or `vchi` fault lines appeared in this boot's logs.
- CPU frequency readout was `scaling_cur_freq=2000000`, `scaling_max_freq=2400000`, `scaling_min_freq=1500000`; this indicates the governor is responding under the light desktop / Remmina session, but it is not a definitive load-time throttle test.

Conclusion: firmware / power diagnostics are closed for today's critical path. The 27/05 low-voltage event is not forensically recoverable from this fresh boot; the remaining power question is forward-looking and should be tested later under controlled combined RealSense + MAVLink load. No Board / Roadmap update is needed unless a real endpoint, heartbeat, or durable telemetry status changes.

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

**Outcome:** Block B not started on 01/06/2026. The Block A side check re-confirmed no real CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink endpoint, and the professor did not provide a concrete endpoint route in this repo session. Exact endpoint path remains unresolved. Firmware / launch profile remains unresolved. Do not proceed to heartbeat or launch MAVROS until a real endpoint path is visible or explicitly provided.

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

**Outcome:** Block C not done this session. The live-heartbeat branch stayed gated because Block B did not prove an endpoint. The PPT-refresh branch was not started; no Windows `.pptx` path was provided in this Linux session, no repo-side slide outline was revised today, and no deck export was produced. The 29/05 four-page working draft remains the current repo-side deck basis.

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

**Outcome:** Block D not done this session. Windows `.pptx` update status is unconfirmed from this Linux repo session. No backup PDF was exported here. Tuesday follow-up remains final deck polish / rehearsal if the Windows deck still needs it, plus endpoint re-check only if the professor provides a real connection path.

## Block E - Day wrap (approx 20-30 min)

- [x] Fill Block outcomes.
- [x] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if live endpoint status, heartbeat, or telemetry truly changes durable project state;
  - otherwise keep Monday as diary-only presentation / endpoint-prep work.
- [x] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='(\[[T]o fill|<{7}|={7}|>{7})'
  rg -n "$pattern" working_diary/2026-06-01_monday_professor_endpoint_or_ppt_refresh.md
  ```

- [x] Set next startup hint for Tue 02/06/2026 or Wed 03/06/2026.
- [ ] Commit + push if the diary is closed.

**Outcome:** Day wrap ready on 01/06/2026. Today's work closed as diary-only endpoint / health evidence plus branch decision: no real MAVLink endpoint appeared, MAVROS was not launched, PPT refresh was deferred while the day focused on the endpoint re-check and health evidence, and no durable project state changed. No `Board.md` / `wiki/Roadmap.md` update is needed because there is still no endpoint path, no `/mavros/state connected: true`, and no first boat telemetry.

Final checks passed: `git status --short --branch` showed only this diary modified before the wrap commit handoff; `git diff --check` was clean; placeholder / conflict-marker scan found no remaining placeholders after this outcome fill. Commit and push remain pending user action.

Suggested commit subject:

`docs(diary): wrap 01/06 endpoint gate day`

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Next active startup hint: Tue 02/06/2026 final pre-meeting check, or Wed 03/06/2026 meeting-day check if Tuesday is skipped.

- Start with repo pre-flight and current anchors.
- If a real endpoint path appears, run the expanded endpoint audit before any MAVROS launch.
- If `/mavros/state connected: true` is achieved, capture minimal first telemetry and refresh the deck.
- If no endpoint is available, keep the deck focused on work completed since 20/05/2026 and decisions needed.
- Keep exact endpoint evidence in speaker notes only; keep visible slides non-technical.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- Validation methodology remains pending external confirmation.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026 unless completed during the meeting-prep pass.
