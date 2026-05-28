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

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

  Expected: clean tree, `HEAD == origin/main`, latest commit `a037ebb`.

- [ ] Re-read the current status anchors:

  ```bash
  sed -n '170,205p' Board.md
  sed -n '188,205p' wiki/Roadmap.md
  sed -n '1,280p' working_diary/2026-05-28_thursday_pi5_endpoint_or_slab3.md
  ```

- [ ] Confirm meeting frame: Wed 03/06/2026, 10h-12h, group / supervisor meeting.
- [ ] Confirm the PPT path and editing machine. If the path is external to the repo, do not guess it; ask or record it as TBD.
- [ ] Lock the day priority: PPT evidence pack and slide story first; Pi checks only if they support the meeting narrative or new hardware appears.

**Outcome:** [To fill - repo state, PPT path status, meeting-scope decision.]

## Block B — Fact table for the PPT (≈ 45-60 min)

Create a concise evidence table that can be copied into slides or speaker notes. Keep each row tied to a repo source, so claims are easy to defend in the 03/06 meeting.

Suggested fact rows:

| Slide theme | Claim to support | Source to verify |
|:------------|:-----------------|:-----------------|
| Pi baseline | Ubuntu Desktop 24.04.4 + ROS 2 Jazzy + Remmina access are green | `Board.md` hardware-arrival tasks; 28/05 diary Block A |
| MAVROS install | MAVROS 2.14.0 Route 1 apt install is green | `Board.md` MAVROS task; `wiki/Roadmap.md` MAVROS Route 1 row |
| Endpoint blocker | no CubePilot / Pixhawk / USB-UART / UDP MAVLink endpoint as of 28/05 | 28/05 diary Block A; `wiki/Roadmap.md` Blockers |
| Slab 3 | autostart design exists only as placeholder with `fcu_url` unresolved | 28/05 diary Block B/C; `wiki/Roadmap.md` MAVROS row |
| RealSense camera | color/depth, IMU-only, and Pi-local color viewers verified in split status | `Board.md` RealSense row; `wiki/Roadmap.md` RealSense row |
| RealSense caveat | combined color/depth/IMU is still load-sensitive | `Board.md` RealSense row; `wiki/Roadmap.md` power row |
| Decision needs | endpoint path, firmware family, power path, validation methodology | `Board.md` blockers; 20/05 and 28/05 diary follow-ups |

Acceptance criterion: each slide-level claim has one current repo citation and no memory-only facts.

**Outcome:** [To fill - final fact table / slide claim pack.]

## Block C — Slide story for 03/06 (≈ 60-90 min)

Draft or revise the PPT story around the 03/06 10h-12h meeting. Because this is a longer meeting than the 20/05 10h-10h30 slot, prepare a concise live update plus deeper backup notes rather than overloading visible slides.

Recommended visible slide sequence:

1. **Title / meeting goal** - 03/06 progress update and decisions needed.
2. **Status since 20/05** - Pi returned, MAVROS installed, endpoint still missing, RealSense path improved.
3. **MAVROS gate** - software green; physical MAVLink endpoint absent; `/dev/ttyAMA10` is not enough.
4. **Slab 3 autostart strategy** - placeholder `systemd` unit, no enabled service, `fcu_url` pending endpoint.
5. **RealSense evidence** - color/depth, IMU-only, Pi-local viewers; combined-load caveat.
6. **Risk / blocker table** - endpoint, firmware family, power, validation methodology.
7. **Decision asks for 03/06** - what supervisors / teammate maintainer need to confirm.
8. **Next work plan** - endpoint-first MAVROS heartbeat, then telemetry samples, then autostart hardening.

Speaker notes should carry the exact evidence details: commit IDs, device IDs, topic names, and dates. Visible slides should stay short and diagram/table-heavy.

**Outcome:** [To fill - slide outline locked, sections drafted, missing assets/questions.]

## Block D — PPT edit / rehearsal pass (≈ 90-150 min)

- [ ] Open the confirmed `.pptx` and update only the necessary slides.
- [ ] Add or refresh speaker notes with source pointers to `Board.md`, `wiki/Roadmap.md`, and `working_diary/2026-05-28...`.
- [ ] Export a slides-only PDF backup if the deck is touched.
- [ ] Rehearse the live update once. Target: 10-15 min for the update, leaving most of the 10h-12h window for discussion.
- [ ] Prepare a decision-asks list for the meeting:
  - confirm real CubePilot / Pixhawk connection path to the Pi 5;
  - confirm firmware family / MAVROS profile (`px4`, `apm`, or generic);
  - confirm whether a TELEM UART / USB-UART cable will be provided;
  - confirm power path for combined RealSense + desktop + MAVLink load;
  - confirm validation methodology still pending from the Three Asks.

Fallback if PPT editing takes too long: ship the fact table + outline first, then defer visual polish. The meeting needs defensible facts more than decorative polish.

**Outcome:** [To fill - deck edited y/n, PDF backup y/n, rehearsal timing, decision asks ready y/n.]

## Block E — Day wrap (≈ 20-30 min)

- [ ] Fill Block outcomes.
- [ ] Decide whether durable docs need updates. Default: no, unless the PPT prep changes project status or adds new confirmed decisions.
- [ ] Run final checks:

  ```bash
  git status --short --branch
  git diff --check
  pattern='[[]To fill|<{7}|={7}|>{7}'
  rg -n "$pattern" working_diary/2026-05-29_friday_ppt_prep_for_03_june_meeting.md
  ```

- [ ] Run the standard pre-commit sweep if committing.
- [ ] Set next startup hint for the next active day.
- [ ] Commit + push if the diary is closed.

**Outcome:** [To fill - diary closed state, commit subject, next startup hint.]

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 - not this internship's physical-sensor-interface work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

Fri 29/05/2026 startup hint: focus on PPT prep for Wed 03/06/2026 10h-12h.

- Start with repo pre-flight and current status anchors.
- Build the slide fact table before editing the deck.
- Keep Pi 5 / CubePilot work as a blocker narrative unless a real endpoint appears.
- Do not launch MAVROS without a confirmed serial / UART / UDP MAVLink endpoint.
- Keep RealSense camera evidence separate from MAVROS boat telemetry.
