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

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree and branch synced; recent log includes `444df00` (01/06 wrap) and this 02/06 scaffold commit once it lands.

- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [x] Re-read current anchors:

  ```bash
  sed -n '1,260p' working_diary/2026-06-01_monday_professor_endpoint_or_ppt_refresh.md
  sed -n '1,260p' working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  sed -n '170,185p' Board.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  ```

- [x] Confirm Tuesday work branch:
  - if a real endpoint path appears, run Block B endpoint proof first;
  - if no endpoint path appears, skip live work and proceed to Block C final meeting prep.
- [x] Confirm whether the Windows `.pptx` is available. If not, keep work in repo-side Markdown notes only.
- [x] Do not advance to live MAVROS work until a real endpoint path is visible or explicitly provided.

**Outcome:** Block A complete on 02/06/2026. Repo pre-flight was green after `git fetch --prune`: `git log --oneline -5` began with `374f8a9`, `444df00`, `612d1c8`, `4278335`, and `eb60028`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `374f8a93cb83149d8686da432dd806881ee4e56a` for both refs. No local push, pull, or merge was needed.

The current anchors were re-read from this 02/06 diary, the 01/06 endpoint-gate diary, the 29/05 PPT-prep diary, `Board.md`, and `wiki/Roadmap.md`. They still show the same live gate: Pi 5 software preparation, MAVROS Route 1 installation, remote access, and camera-path evidence are ready to report, but no confirmed CubePilot / Pixhawk / TELEM / USB-UART / UDP MAVLink endpoint is available in the repo-side evidence. No concrete endpoint path was provided in today's startup context.

Selected branch: Block C final deck / meeting-prep notes. Block B stays skipped until a real endpoint path is visible or explicitly provided. MAVROS must not be launched just to create `/mavros/*` topics; the pass condition remains `/mavros/state connected: true`. The Windows `.pptx` path was not provided in this Linux repo session, so work stays in repo-side Markdown notes only.

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

**Outcome:** Block B attempted on 02/06/2026 during the professor window. The professor confirmed the hardware should use the ArduPilot / CubePilot path, so `apm.launch` was the selected MAVROS profile.

Endpoint audit before launch:

- Serial sweep showed only `/dev/ttyAMA10`; no `/dev/ttyACM0` or `/dev/ttyUSB0` was present.
- UDP check showed no listener on `14550`, `14551`, `14540`, or `5760`.
- The MAVROS package contained `apm.launch`, `px4.launch`, and related config files.

MAVROS attempts:

- `serial:///dev/ttyACM0:115200` failed because `/dev/ttyACM0` did not exist.
- `serial:///dev/ttyAMA10:57600` opened the port, but `/mavros/state` stayed `connected: false`.
- `serial:///dev/ttyAMA10:115200` opened the port, but `/mavros/state` stayed `connected: false`.
- `udp://:14855@` opened the UDP socket, but `/mavros/state` stayed `connected: false`.

Raw byte-flow check:

- `stty` + `cat /dev/ttyAMA10 | hexdump -C` at `57600` and `115200` produced no visible bytes during the test window.

MAVProxy cross-check:

- MAVProxy was installed on the Pi with `mavproxy-1.8.74`, `pymavlink-2.4.49`, and the missing `future` dependency added afterward; `mavproxy.py --version` reported `MAVProxy Version: 1.8.74`, and `python3 -c "from pymavlink import mavutil"` succeeded.
- USB serial sweep still returned no `/dev/ttyACM*` or `/dev/ttyUSB*`; `mavproxy.py --master=/dev/ttyACM0 --show-errors` failed to open `/dev/ttyACM0` because the device did not exist.
- `mavproxy.py --master=/dev/ttyAMA10,57600 --show-errors` opened the port, waited for heartbeat, then reported `link 1 down`.
- `mavproxy.py --master=/dev/ttyAMA10,115200 --show-errors` opened the port, waited for heartbeat, then reported `link 1 down`.
- `mavproxy.py --master=/dev/ttyAMA10,921600 --show-errors` opened the port, waited for heartbeat, then reported `link 1 down`.
- `mavproxy.py --master=udpin:0.0.0.0:14855 --show-errors` opened the UDP listener, waited for heartbeat, then reported `link 1 down`.
- `mavproxy.py --master=udpin:0.0.0.0:14550 --show-errors` also opened the UDP listener, waited for heartbeat, then reported `link 1 down`.
- Later retest after `ModemManager` had already been uninstalled and the Pi rebooted still showed no `/dev/ttyACM*`, no `/dev/serial*`, and only `/dev/ttyAMA10`; `mavproxy.py --master=/dev/ttyAMA10 --baudrate 115200` and `mavproxy.py --master=/dev/ttyAMA10 --show-errors` both opened the port and waited for heartbeat before `link 1 down`.
- MAVProxy still allowed local prompt commands such as `status` while the link was down; reported outbound master counters do not prove a vehicle link when inbound / heartbeat-related counters remain zero.
- `cat mav.tlog`, `cat /dev/ttyAMA10`, and `sudo hexdump -C /dev/ttyAMA10` produced no visible MAVLink bytes in the terminal during the retest.
- Pi boot config check showed `/boot/firmware/config.txt` exists with `enable_uart=1` and `dtoverlay=disable-bt`; `/boot/firmware/cmdline.txt` contains only `console=tty1`, so no serial console is visible in the kernel command line. Device check still showed no `/dev/serial*`; only `/dev/ttyAMA10` and `/dev/ttyS0` appeared. No `/dev/ttyAMA0` was present.
- Late note after the wrap: user reported that after modifying `config.txt`, rebooting, and retesting the MAVProxy commands, the result still reported `link 1 down`. Exact post-reboot device enumeration and target port used after the config change should be captured next before treating this as a completed post-overlay proof.

Python / `pymavlink` cross-check:

- A heartbeat-only script at `~/mavlink_heartbeat_test.py` tested `/dev/ttyAMA10` at `57600`, `115200`, and `921600`.
- Result for all three baud rates: `NO HEARTBEAT`.

Verdict: MAVROS, MAVProxy, and direct `pymavlink` all start and can open `/dev/ttyAMA10`, but no heartbeat arrives on that UART at `57600`, `115200`, or `921600`. The raw hexdump showed zero bytes, so the tools agree because the line is silent; this rules out a MAVROS-specific software fault, not a wiring fault. USB was not exercised because no `/dev/ttyACM0` ever appeared, and the UDP listener had no confirmed source, so neither path is evidence either way. Since a baud mismatch usually yields garbled bytes rather than silence, the blocker is likely physical or configuration-side: TELEM TX-to-Pi RX wiring, common ground, Pi UART mapping, or whether the flight controller emits MAVLink on that port through its `SERIALx_PROTOCOL` / `SERIALx_BAUD` settings. `ModemManager` is no longer the current explanation after uninstall and reboot. The Pi 5 UART mapping is now suspect because no `/dev/serial*` or `/dev/ttyAMA0` exists, while `/dev/ttyAMA10` is the Pi 5 debug UART class device. Next checks are confirming which Linux device maps to GPIO header pins 8/10, enabling the correct Pi 5 UART overlay if needed, and running a real flight-controller USB enumeration test on `/dev/ttyACM0` if the board can be connected by USB. No `/mavros/state connected: true` result was achieved, so no `/mavros/imu/data`, `/mavros/global_position/global`, or `/mavros/battery` telemetry capture was attempted.

## Block C - Final deck notes / meeting story (approx 45-75 min)

Run this block if no live endpoint proof changes the status, or after any live result is known.

- [x] Confirm whether the Windows `.pptx` is available:
  - if available, transfer / update the visible 4-page story and speaker notes on the Windows machine;
  - if unavailable, keep final copy in this diary as repo-side speaker-note text.
- [x] Keep visible slides non-technical:
  1. Progress since 20/05.
  2. Current dependency: real boat-data connection path, or telemetry link established if Block B passes.
  3. Ready vs pending.
  4. Decisions requested on 03/06.
- [x] Keep exact evidence in speaker notes only:
  - Pi 5 baseline and MAVROS install green;
  - endpoint gate: no usable endpoint as of 01/06 unless Block B changes it;
  - `/dev/ttyAMA10` alone is not enough without TELEM wiring confirmation;
  - RealSense camera evidence is separate from boat telemetry;
  - combined RealSense color/depth/IMU remains a future power / USB-stability retest.
- [x] Keep the decision asks explicit:
  - real autopilot-to-Pi physical path;
  - firmware family / MAVROS launch profile;
  - TELEM UART / USB-UART cable availability;
  - power path for Pi + camera + telemetry load;
  - validation methodology confirmation.

### Repo-side final copy

Use this as the Markdown source for the Windows deck if the `.pptx` becomes available. Keep visible slide text short; keep exact paths, ROS topics, version strings, and audit evidence in speaker notes.

1. **Progress since 20/05**
   - Onboard computer environment restored and reachable.
   - Communication bridge software installed and ready for a real data link.
   - Camera path retested with desktop viewers.
   - Future autostart strategy drafted for deployment.

   Speaker notes: describe this as preparation completed since the 20/05 meeting. Use the repo evidence for Pi 5 baseline, Remmina access, MAVROS Route 1 install, RealSense viewer checks, and paper autostart strategy. Keep package names and device details in notes, not on the visible slide.

2. **Current dependency**
   - The onboard computer is ready for a real boat-data connection.
   - The exact autopilot-to-Pi data path still needs confirmation.
   - This is a connection / hardware decision, not a software installation issue.
   - Camera data is useful but separate from boat telemetry.

   Speaker notes: the latest endpoint gate remains unchanged from 01/06. No `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, or UDP MAVLink listener has been proven. `/dev/ttyAMA10` alone is not enough without TELEM wiring confirmation plus byte-flow evidence on the identified UART.

3. **Ready vs pending**
   - Ready: Pi 5 baseline, remote desktop access, MAVROS installation, camera viewer check, draft autostart strategy.
   - Pending: real telemetry connection path, firmware / launch profile, power margin under combined Pi + camera + telemetry load, validation methodology.

   Speaker notes: explain MAVROS as the bridge that converts autopilot data into the boat computer's software environment. If Block B later reaches `/mavros/state connected: true`, revise this slide from "pending telemetry path" to "telemetry link established" and add the first telemetry status honestly.

4. **Decisions requested on 03/06**
   - Which physical path should connect the autopilot to the Pi 5?
   - Which firmware family / software profile should be used?
   - Is a TELEM UART / USB-UART cable available?
   - What power path should support Pi + camera + telemetry together?
   - Is the validation methodology confirmed?

   Speaker notes: close with an endpoint-first next step: confirm the real connection, prove heartbeat, capture minimal telemetry, then harden autostart and collect repeatable samples. Keep exact endpoint audit evidence available for questions, not as main slide content.

Carry-forward note: validation methodology remains pending external confirmation. VRX Section 8.2 weekly cadence check remains due on 02/06/2026 unless completed later in the meeting-prep pass.

**Outcome:** Block C updated on 02/06/2026. Repo-side deck notes are now ready in this diary. The Windows `.pptx` was not touched because no Windows path was provided. Final story status: software preparation is ready to report, live boat telemetry remains gated on a real endpoint, RealSense stays separate from MAVROS telemetry, and the 03/06 decision asks are explicit.

## Block D - Meeting readiness / rehearsal check (approx 20-30 min)

- [x] Skip the short verbal rehearsal in this repo session:
  - since 20/05, the onboard computer environment and software bridge are ready;
  - the remaining dependency is the real boat-data connection path;
  - camera progress is useful but separate from boat telemetry;
  - the 03/06 meeting should confirm connection, firmware/profile, power path, and validation methodology.
- [x] Skip Windows deck export from this Linux repo session; the Windows deck was not touched here.
- [x] Defer the Wed 03/06 morning edit decision to the next meeting-day check.
- [x] Carry the VRX §8.2 weekly cadence check forward; it was not completed during this repo session.

**Outcome:** Block D skipped by user direction on 02/06/2026. No rehearsal pass, Windows `.pptx` export, or VRX §8.2 cadence check was completed in this repo session. Carry the meeting-day polish decision and VRX cadence check into the next startup.

## Block E - Day wrap (approx 20-30 min)

- [x] Fill Block outcomes.
- [x] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if live endpoint status, heartbeat, telemetry, or meeting decision state truly changes durable project state;
  - otherwise keep Tuesday as diary-only pre-meeting work.
- [x] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='(\[[T]o fill|<{7}|={7}|>{7})'
  rg -n "$pattern" working_diary/2026-06-02_tuesday_pre_meeting_final_check.md
  ```

- [x] Run the standard pre-commit sweep if committing.
- [x] Set next startup hint for Wed 03/06/2026 meeting day.
- [ ] Commit + push if the diary is closed.

**Outcome:** Day wrap ready on 02/06/2026. Tuesday closed as diary-only pre-meeting / endpoint-proof work. The professor-window tests did not produce `/mavros/state connected: true`, first boat telemetry, or a durable endpoint path, so no `Board.md` / `wiki/Roadmap.md` update is needed from this wrap. Current evidence is sharper than the morning state: MAVROS, MAVProxy, and direct `pymavlink` all open `/dev/ttyAMA10` but receive no heartbeat; raw byte checks show the line is silent; `ModemManager` is no longer the current explanation after uninstall and reboot; Pi 5 UART mapping is now suspect because `uart0-pi5` is required for GPIOs 14-15 and no `/dev/ttyAMA0` / `/dev/serial*` appeared. A late user report says MAVProxy still returned `link 1 down` after a `config.txt` edit and reboot, but the exact post-reboot device list and tested target port still need to be captured.

Final checks passed before commit handoff: `git diff --check` was clean; placeholder / conflict-marker scan found no remaining placeholders after this outcome fill; the standard visibility sweep was clean. Commit and push remain pending user action.

Suggested commit subject:

`docs(diary): close 02/06 endpoint proof day`

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Wed 03/06/2026 meeting-day startup hint: prepare for the 10h-12h group / supervisor meeting with the endpoint-proof evidence bounded tightly.

- Start with repo pre-flight and current anchors.
- Keep the visible deck non-technical: software preparation ready, live boat telemetry still gated, decisions needed.
- In speaker notes, state the exact endpoint result: no `/mavros/state connected: true`; `/dev/ttyAMA10` opens but is silent; USB was not exercised because no `/dev/ttyACM0` appeared; UDP listeners had no confirmed source; a late post-config/reboot MAVProxy retest was reported as still `link 1 down`, with exact post-reboot device enumeration still to capture.
- If the professor wants one more live check before / during the meeting, first confirm the physical path:
  - if TELEM is on Pi GPIO header pins 8/10, enable the correct Pi 5 GPIO UART path (`uart0-pi5`) and test the resulting device, likely `/dev/ttyAMA0`;
  - if USB is possible, connect the flight controller by USB and confirm `/dev/ttyACM0` enumeration before MAVProxy / MAVROS heartbeat checks.
- Do not launch MAVROS just to create topics; pass condition remains `/mavros/state connected: true`.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- Carry validation methodology and VRX Section 8.2 weekly cadence as meeting-day follow-ups unless resolved in the meeting.
