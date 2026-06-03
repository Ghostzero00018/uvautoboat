# 2026-06-03 - Wednesday: morning meeting only

## Day overview

Continuing from Tue 02/06/2026 ([`2026-06-02`](2026-06-02_tuesday_pre_meeting_final_check.md)).

Today is a short day: attend the Wed 03/06/2026 10h-12h group / supervisor meeting in the morning only. No planned afternoon work.

Carry the Tuesday endpoint-proof result carefully:

- Software preparation is ready to report: Pi 5 baseline, remote desktop access, MAVROS Route 1 installation, MAVProxy / `pymavlink` available, camera-path checks, and repo-side meeting notes.
- No live MAVROS telemetry was achieved on 02/06/2026. `/mavros/state connected: true` remains the ROS-side pass condition.
- `/dev/ttyAMA10` opened but stayed silent: no heartbeat in MAVROS, MAVProxy, or direct `pymavlink`; raw byte checks showed no visible bytes.
- USB was not exercised because no `/dev/ttyACM0` appeared. UDP listeners had no confirmed MAVLink source.
- Pi 5 UART mapping is the leading technical lead: GPIO header pins 8/10 need the Pi 5 `uart0-pi5` path, likely producing `/dev/ttyAMA0` if enabled correctly. Capture exact post-config evidence before claiming the overlay succeeded or failed.
- Professor photo sent on the morning of 03/06/2026 changes the endpoint evidence. The photo clock shows the MAVProxy run was captured on Tue 02/06/2026 at 22:09: after Pi 5 reconfiguration, MAVProxy on `/dev/ttyAMA0` at `57600` detected vehicle `1:1` and received ArduPilot status text. Treat this as a MAVProxy heartbeat / ArduPilot status proof, not yet as MAVROS / ROS telemetry proof.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- Validation methodology remains pending external confirmation.
- VRX Section 8.2 weekly cadence check remains to resolve or carry.

## Boundaries

- **In scope:** morning meeting attendance; concise visible story; bounded endpoint evidence in speaker notes; decisions requested; exact meeting outcomes.
- **Out of scope:** afternoon work, broad docs, Python / YAML edits, Pi-side `systemd`, and launching MAVROS without a proven endpoint.
- **PPT boundary:** actual `.pptx` remains Windows-side unless a concrete Windows path is provided.
- **Endpoint boundary:** do not count advertised `/mavros/*` topics as success. Only `/mavros/state connected: true` proves heartbeat.

## Block A - Morning repo and meeting pre-flight

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report the state.

- [x] Re-read current anchors:

  ```bash
  sed -n '1,320p' working_diary/2026-06-02_tuesday_pre_meeting_final_check.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  ```

- [x] Inspect the professor photo sent on 03/06 morning, captured by the Pi desktop clock on 02/06 at 22:09.
- [x] Confirm the morning-only scope and no planned afternoon work.

**Outcome:** Block A started and pre-flight completed on 03/06/2026. `git fetch --prune` completed, `git log --oneline -5` began with `1724c84`, `91d8a0b`, `de2e25b`, `374f8a9`, and `444df00`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `1724c849a7fafa03da53976900f1193898b1d237` for both refs. No pull, merge, or push was needed.

Current anchors were re-read from the 02/06 diary, `Board.md`, and `wiki/Roadmap.md`. They still correctly preserve the 02/06 result as the pre-reconfiguration baseline: `/dev/ttyAMA10` opened but stayed silent, no `/dev/ttyACM0` appeared, UDP had no confirmed source, and `/mavros/state connected: true` was not reached.

New evidence from the professor photo, sent on the morning of 03/06/2026 and captured by the Pi desktop clock on Tue 02/06/2026 at 22:09: after Pi 5 reconfiguration, the terminal ran `mavproxy.py --master=/dev/ttyAMA0 --baudrate 57600`. MAVProxy connected to `/dev/ttyAMA0`, waited for heartbeat, then printed `Detected vehicle 1:1 on link 0`, `online system 1`, mode `HOLD`, `fence present`, and repeated `AP: EKF3 waiting for GPS config data` status text.

Interpretation: `/dev/ttyAMA0` at `57600` is now the first evidenced MAVProxy heartbeat path and matches the suspected Pi 5 GPIO UART mapping lead from 02/06. This supersedes the 02/06 `/dev/ttyAMA10` silent-line result for the reconfigured setup. It does not yet prove MAVROS / ROS telemetry; the next technical gate is a MAVROS launch against `serial:///dev/ttyAMA0:57600` and `/mavros/state connected: true`, followed by minimal telemetry topics if connected.

Morning-only scope remains confirmed: attend the 10h-12h meeting, record exact decisions, update durable docs only where this new endpoint evidence changes current status, then stop unless afternoon work is explicitly reopened.

## Block B - 10h-12h meeting notes

- [ ] Keep visible story short:
  1. Progress since 20/05.
  2. Current dependency: MAVROS / ROS telemetry link still not proven.
  3. Ready vs pending.
  4. Decisions requested.
- [ ] Use speaker notes for exact endpoint evidence:
  - `/dev/ttyAMA10` opened but stayed silent;
  - professor photo sent on 03/06 morning, captured on 02/06 at 22:09, shows MAVProxy on `/dev/ttyAMA0` at `57600` detecting vehicle `1:1`, mode `HOLD`, and ArduPilot EKF3 GPS status text;
  - no `/dev/ttyACM0` USB device was present;
  - UDP tests had no confirmed source;
  - `ModemManager` was removed and rebooted, but that did not produce heartbeat;
  - Pi 5 GPIO UART mapping / `uart0-pi5` now has photo evidence through `/dev/ttyAMA0`, but the exact config change and MAVROS pass still need verification.
- [ ] Capture decisions:
  - exact flight-controller board / firmware;
  - exact physical path: USB, GPIO UART, TELEM UART, or UDP router;
  - required ArduPilot `SERIALx_PROTOCOL` / `SERIALx_BAUD` values;
  - whether RTS/CTS is enabled or wired;
  - exact Pi boot config / overlay change that made `/dev/ttyAMA0` work;
  - whether MAVROS should now use `serial:///dev/ttyAMA0:57600`;
  - validation methodology confirmation;
  - VRX Section 8.2 weekly cadence status.

**Outcome:** [To fill - meeting decisions and unresolved items.]

## Block C - Noon handoff only

- [ ] Record meeting outcome while still fresh.
- [ ] Decide whether durable docs need updates:
  - update `Board.md` / `wiki/Roadmap.md` only if the meeting changes durable project state;
  - otherwise keep this as diary-only.
- [ ] Set the next startup hint.
- [ ] Stop after the noon handoff unless the user explicitly reopens afternoon work.

**Outcome:** [To fill - handoff state, doc update decision, next startup hint.]

## Next steps

Morning startup: repo pre-flight and the professor's post-reconfiguration MAVProxy photo evidence are documented. Attend the 10h-12h meeting, confirm the exact `/dev/ttyAMA0` / `57600` configuration path, decide whether to run MAVROS against that endpoint, and capture decisions. Afternoon is intentionally off-work unless explicitly reopened.
