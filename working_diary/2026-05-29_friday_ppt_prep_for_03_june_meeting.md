# 2026-05-29 — Friday: PPT prep for 03/06/2026 group meeting

## Day overview

Continuing from Thu 28/05/2026 ([`2026-05-28`](2026-05-28_thursday_pi5_endpoint_or_slab3.md)).

Repo state coming in should be clean and synced after the 28/05 wrap. Latest relevant commits before this scaffold:

- `a037ebb docs: wrap 28/05 Pi endpoint gate + RealSense viewers`
- `3571648 docs(diary): record 28/05 endpoint gate + Slab 3 draft`
- `ca17c49 docs(diary): scaffold 28/05 Pi 5 endpoint or Slab 3`

Primary work for tomorrow is presentation preparation for the next group / supervisor meeting on Wed 03/06/2026, 10h-12h. Treat this as a PPT-prep day, not a Pi bring-up day. Expected Pi 5 hardware state: the Pi still does not read the CubePilot / Pixhawk as a real MAVLink endpoint. As of the 28/05 Remmina-side audit, USB showed keyboard + RealSense D435i + mouse only; serial sweep showed only `/dev/ttyAMA10`; there was no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, or MAVLink UDP listener on `14550`, `14551`, `14540`, or `5760`. `/dev/ttyAMA10` alone remains insufficient without confirmed TELEM wiring.

Current message to prepare for the 03/06 meeting:

- Software install side is green: Ubuntu Desktop 24.04.4, ROS 2 Jazzy, MAVROS 2.14.0, GeographicLib datasets, `dialout`, Remmina access.
- Live MAVROS telemetry is blocked by physical endpoint absence, not by the ROS / MAVROS install.
- Slab 3 autostart is a placeholder `systemd` strategy only; `fcu_url` and device-ordering must wait for a real endpoint.
- RealSense D435i camera path is improving: color/depth and IMU-only were verified on 27/05; Pi-local color-only viewing through `rqt_image_view` and RViz2 was verified on 28/05. Combined color/depth/IMU remains a power / USB-stability retest.
- The 03/06 meeting should use these facts to ask for the missing hardware / firmware decisions: real MAVLink endpoint path, firmware family / launch profile, power path for combined RealSense load, and validation-methodology confirmation.

## Boundaries

- **In scope:** PPT outline / slide story; fact table from current repo docs; meeting question list; rehearsal checklist; optional minimal Pi endpoint status wording for slides.
- **Out of scope:** Python / YAML edits, launching MAVROS without a confirmed endpoint, enabling a Pi-side service, broad doc rewrites, and external weekly diary updates unless explicitly requested.
- **PPT file boundary:** external PPT paths vary by machine. Confirm the actual `.pptx` path before editing or giving file-specific instructions. The repo diary can draft the story and evidence table without touching the external deck.
- **Pi endpoint assumption:** expect no CubePilot / Pixhawk endpoint. If hardware unexpectedly appears, run the expanded endpoint audit before any MAVROS launch; do not launch MAVROS just to make `/mavros/*` topics appear.
- **RealSense boundary:** RealSense camera evidence is not boat telemetry. `/camera/camera/color/image_raw` and `/camera/camera/imu` do not prove `/mavros/imu/data`.

## Block A — Repo pre-flight + meeting scope lock (≈ 15-20 min)

- [x] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected at 29/05 Block A start: clean tree and branch synced; recent log begins with `ff161ee`.

- [x] Re-read the current status anchors:

  ```bash
  sed -n '170,205p' Board.md
  sed -n '309,315p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  sed -n '1,280p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  ```

- [x] Confirm meeting frame: Wed 03/06/2026, 10h-12h, group / supervisor meeting.
- [x] Confirm the PPT path and editing machine. If the path is external to the repo, do not guess it; ask or record it as TBD.
- [x] Lock the day priority: PPT evidence pack and slide story first; Pi checks only if they support the meeting narrative or new hardware appears.

**Outcome:** Block A complete on 29/05/2026. Repo pre-flight was green after `git fetch --prune`: `git log --oneline -5` began with `ff161ee`, `a037ebb`, and `3571648`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `ff161eea78b29226c8aa7b0fa599eca5f9106581` for both refs. No pull was needed.

The 03/06/2026 10h-12h group / supervisor meeting frame is confirmed. The actual `.pptx` file will be on another Windows machine, so this Linux repo session will prepare copy-pasteable Markdown evidence, slide structure, and speaker-note material only; no external deck path is assumed or touched here. Day priority is locked to PPT evidence pack and slide story. No Pi checks or MAVROS launches are planned unless new endpoint hardware appears and the expanded endpoint audit proves a real serial / UART / UDP MAVLink path first.

## Block B — Fact table for the PPT (≈ 45-60 min)

Create a concise evidence table that can be copied into slides or speaker notes. Keep each row tied to a repo source, so claims are easy to defend in the 03/06 meeting.

Final fact rows:

| Slide theme | Slide-level claim | Speaker-note evidence | Repo source |
|:------------|:------------------|:----------------------|:------------|
| Meeting frame | 03/06/2026 is a 10h-12h group / supervisor meeting focused on progress and decisions. | Use this as a longer discussion slot than the 20/05 10h-10h30 cap: concise live update, deeper backup notes. | `Board.md:309`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:278` |
| Pi baseline | Pi 5 software baseline is green after the reflash. | Ubuntu Desktop 24.04.4 LTS Noble, `linux-raspi` 6.8.0-1056, aarch64, ROS 2 Jazzy base, GNOME Remote Desktop / Remmina path. | `Board.md:178`; `Board.md:311`; `wiki/Roadmap.md:193`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:80-82` |
| MAVROS install | MAVROS Route 1 apt install is green; telemetry is not blocked by package installation. | `ros-jazzy-mavros` 2.14.0 plus extras and msgs installed from apt; GeographicLib defaults installed; `dialout` active after reboot. | `Board.md:179`; `Board.md:311`; `wiki/Roadmap.md:192` |
| MAVROS gate | `/mavros/*` topic presence alone is not success. | Earlier quick launch exposed plugin topics while `/mavros/state` stayed `connected: false`; the pass condition is `/mavros/state connected: true`. | `Board.md:311`; `wiki/Roadmap.md:192`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:27`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:101-107` |
| Endpoint blocker | As of 28/05/2026, the Pi still has no usable CubePilot / Pixhawk / USB-UART / UDP MAVLink endpoint. | USB showed keyboard, RealSense D435i, and mouse only; serial sweep found only `/dev/ttyAMA10`; no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial0`, `/dev/serial1`, or UDP listener on `14550`, `14551`, `14540`, `5760`. `/dev/ttyAMA10` alone is not sufficient without TELEM wiring confirmation. | `Board.md:313`; `wiki/Roadmap.md:192`; `wiki/Roadmap.md:198`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:84` |
| Slab 3 autostart | Slab 3 is a placeholder deployment strategy, not an enabled Pi service. | Candidate `systemd` unit exists in notes only; no Pi-side unit file was created or enabled. `fcu_url` and launch profile stay placeholders until endpoint and firmware evidence exist. `network-online.target` does not guarantee slow USB serial enumeration. | `Board.md:313`; `wiki/Roadmap.md:192`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:119-161`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:197-199` |
| RealSense progress | RealSense D435i camera path is improving and is useful camera evidence. | D435i serial `213622070342`, FW `5.14.0`, USB type `3.2`; color/depth ROS topics verified; IMU-only launch publishes `/camera/camera/imu`; 28/05 color-only local viewer worked in `rqt_image_view` and RViz2 with `/camera/camera/color/image_raw`. | `Board.md:180`; `Board.md:313`; `wiki/Roadmap.md:190`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:212-228` |
| RealSense caveat | Combined color/depth/IMU is not green yet and should not be sold as boat telemetry. | Combined accel/gyro attempt hit `HID set_power 1 failed` / `Motion Module failure` during a Pi low-voltage warning; `/camera/camera/imu` does not prove `/mavros/imu/data`. | `Board.md:180`; `wiki/Roadmap.md:189-190`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:15`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:203`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:228` |
| Camera backup risk | RealSense ROS use and Herelink RTSP video may still conflict under the current camera setup. | Prior observation: Pi-side `realsense2_camera_node` plus workstation RViz streaming caused Herelink video loss; likely v4l2 device-exclusivity. Keep this as backup risk, not a main-line claim unless the meeting turns to camera architecture. | `wiki/Roadmap.md:191` |
| Decision asks | The 03/06 meeting should unlock endpoint, firmware/profile, power, and validation decisions. | Ask for the real Pi 5 MAVLink connection path, firmware family / MAVROS launch profile, TELEM UART / USB-UART cable availability, power path for combined RealSense + desktop + MAVLink load, and validation-methodology confirmation. | `Board.md:170`; `Board.md:309`; `wiki/Roadmap.md:189`; `wiki/Roadmap.md:197-198`; `working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md:240-246` |

Acceptance criterion: each slide-level claim has one current repo citation and no memory-only facts.

**Outcome:** Block B fact table ready for transfer into the Windows-hosted `.pptx`. The deck should use short visible claims and keep exact dates, device paths, topic names, version strings, and source pointers in speaker notes. No external PPT file was edited from this Linux repo session.

## Block C — Slide story for 03/06 (≈ 60-90 min)

Draft or revise the PPT story around the 03/06 10h-12h meeting. Because this is a longer meeting than the 20/05 10h-10h30 slot, prepare a concise live update plus deeper backup notes rather than overloading visible slides.

Audience adjustment: keep the visible deck to about 4 main-content pages and avoid ROS-heavy wording because at least one professor may not know ROS 2. Use plain phrases on slides; keep exact topic names, device paths, package names, and citations in speaker notes.

Revised 4-page visible slide sequence:

1. **Progress since last meeting**
   - 20/05 meeting clarified the next direction: bring real boat telemetry into the onboard software stack.
   - Since then, the onboard computer environment was restored and made accessible again.
   - The communication bridge software was installed and documented.
   - The camera path was retested with desktop viewers.
   - A future autostart strategy was drafted for deployment.

   Speaker notes: keep this as the main "work done since 20/05" slide. Cite Block B rows for meeting frame, Pi baseline, MAVROS install, RealSense progress, and Slab 3 autostart. Use plain wording: "the software environment and preparation work moved forward; the physical telemetry path is the part to re-check before the final deck."

2. **Current dependency to confirm**
   - The onboard computer is ready for a real boat-data connection.
   - The exact physical connection path still needs confirmation.
   - This is a connection / hardware decision, not a software installation issue.
   - Do not count camera data as boat telemetry.

   Speaker notes: avoid overloading the slide with the 28/05 endpoint audit because the professor visit on Mon 01/06/2026 or Tue 02/06/2026 may change the status. Keep the exact audit evidence only as backup: 28/05 USB showed keyboard + RealSense + mouse only; serial sweep found only `/dev/ttyAMA10`; no USB serial, by-id/by-path serial, or UDP telemetry listener. `/dev/ttyAMA10` alone is not enough without TELEM wiring confirmation.

3. **What is ready vs what still needs a decision**
   - Ready: Pi 5 baseline, remote desktop access, MAVROS installation, camera viewer check, draft autostart strategy.
   - Pending before the final deck: real telemetry connection path, firmware / launch profile, power margin under combined load, validation methodology.

   Speaker notes: explain MAVROS as "the bridge that converts autopilot data into the boat computer's software environment." Avoid visible package names except MAVROS if useful. Mention Slab 3 only as "future autostart strategy, waiting for the real connection path." If next week resolves the connection, revise the pending line before the meeting.

4. **Decisions requested on 03/06**
   - Which physical path should connect the autopilot to the Pi 5?
   - Which firmware family / software profile should be used?
   - Is a TELEM UART / USB-UART cable available?
   - What power path should support Pi + camera + telemetry together?
   - Is the validation methodology confirmed?

   Speaker notes: use this as the close. The next work plan is endpoint-first: confirm the real connection, verify live telemetry, then harden autostart and collect samples.

Design constraints for the actual Windows deck:

- Use 4 visible content pages plus title only if the existing deck format requires it.
- Keep visible bullets short; no command blocks on slides.
- Prefer a simple "Ready / Blocked / Decisions needed" structure over a ROS architecture diagram.
- Put exact evidence in speaker notes, not in the main slide body.
- If space is tight, drop the camera backup-risk row from visible slides and keep it as backup discussion only.
- Treat today's 29/05/2026 deck material as a working draft, not the final meeting version. If the professor visit on Mon 01/06/2026 or Tue 02/06/2026 resolves the CubePilot / MAVROS endpoint, refresh the relevant blocker and next-step slides before the Wed 03/06/2026 meeting.

**Outcome:** Block C slide story locked as a 4-page, non-technical main-content outline for the current 29/05/2026 evidence snapshot. Slide 1 now summarizes work completed since the 20/05/2026 meeting without dwelling on Pi 5 endpoint details. Missing asset: actual Windows-hosted `.pptx` remains external to this repo session. Final deck revision should wait until after the Mon 01/06/2026 / Tue 02/06/2026 professor window if CubePilot / MAVROS status changes.

## Block D — PPT edit / rehearsal pass (skipped)

- [x] Skip the local PPT edit / rehearsal pass in this Linux repo session.
- [x] Keep the actual `.pptx` edit for the Windows machine.
- [x] Carry forward the revision rule: if the professor visit on Mon 01/06/2026 or Tue 02/06/2026 produces a real CubePilot / MAVROS endpoint, revise the current-dependency slide and decision asks before the Wed 03/06/2026 meeting.

**Outcome:** Block D skipped by user direction on 29/05/2026. No external deck was opened, edited, exported, or rehearsed from this repo session. Proceed directly to Block E.

## Block E — Day wrap (≈ 20-30 min)

- [x] Fill Block outcomes.
- [x] Decide whether durable docs need updates. Default: no, unless the PPT prep changes project status or adds new confirmed decisions.
- [x] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='(\[[T]o fill|<{7}|={7}|>{7})'
  rg -n "$pattern" working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  ```

- [x] Set next startup hint for the next active day.
- [x] Commit + push if the diary is closed.

**Outcome:** Block E opened after user direction to skip Block D. No durable status docs need updates from today's PPT planning because no project state changed; this is a presentation-prep snapshot only. Final checks passed after correcting the placeholder-scan regex to avoid self-matching the command block: `git diff --check` is clean, and the conflict-marker / placeholder scan is clean after this outcome fill. The close commit later landed and synced as `7516666 docs(diary): record 29/05 PPT prep story`.

Commit subject used for the close commit:

`docs(diary): record 29/05 PPT prep story`

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Next active startup hint: use the 29/05 PPT prep as a working draft for the Wed 03/06/2026 10h-12h meeting.

- If working on the Windows deck: transfer the 4-page non-technical outline first, using the Block B fact table for speaker notes.
- If the professor visit on Mon 01/06/2026 or Tue 02/06/2026 resolves the CubePilot / MAVROS endpoint, refresh the current-dependency slide before final rehearsal.
- If the endpoint is still unresolved, keep the deck focused on work completed since 20/05/2026 and decisions needed, without overloading visible slides with endpoint audit details.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
- VRX §8.2 weekly cadence next check: Tue 02/06/2026.
