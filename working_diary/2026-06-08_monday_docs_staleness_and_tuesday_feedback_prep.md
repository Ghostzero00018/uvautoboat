# 2026-06-08 - Monday: docs staleness sweep and Tuesday feedback prep

## Day overview

Continuing from Fri 05/06/2026 ([`2026-06-05`](2026-06-05_friday_dashboard_sim_real_integration_plan.md)).

Primary work for Mon 08/06/2026 is documentation update, staleness sweep, and preparation for the Tue 09/06/2026 quick feedback / progress meeting that follows the 03/06/2026 supervisor meeting. Do not start the Pi 5 power / RealSense / combined camera work today, and do not start the read-only Option B adapter implementation unless the user explicitly reopens code/config work.

Current message to carry into Monday:

- 03/06 meeting follow-up produced two work threads: video / camera evidence and real-topic integration for dashboard + simulation preservation.
- 04/06 and 05/06 proved the MAVProxy / MAVROS camera-off path on `/dev/ttyAMA0:57600` through MAVProxy UDP fanout, with `/mavros/state connected: true`.
- 05/06 captured a clean domain-12 MAVROS-only graph: 136 `/mavros/*` typed topics, raw GPS no-fix, IMU, vehicle battery, and empty RC channels.
- RealSense / combined camera + MAVROS remains power-blocked. The pasted 05/06 log did not capture a fresh camera or combined topic pass, and the user-observed RealSense-launch shutdown stays bounded as an observed event outside the pasted log.
- Immediate repo implementation direction is documented but parked: read-only Option B, feeding existing `/wamv/*` consumers under a real-adapter-on / simulation-source-off flag, with GPS no-fix filtering.
- Tuesday's meeting prep should foreground progress and clean blockers, not reopen implementation.

## Boundaries

- **In scope:** repo pre-flight, active-doc staleness sweep, current-status cleanup, Tuesday feedback / progress meeting notes, concise progress summary, and next-week decision asks.
- **Out of scope unless explicitly approved:** Python, YAML, JavaScript, launch, dashboard, Pi service, or adapter implementation edits.
- **Hardware boundary:** no RealSense retry, combined MAVROS + camera test, YOLO test, or Pi power experiment today unless the user explicitly changes the plan.
- **Evidence boundary:** keep MAVROS boat telemetry, RealSense camera evidence, Herelink visual evidence, and YOLO feasibility separate.
- **Meeting-prep boundary:** keep the Tue 09/06 visible story concise and non-technical. Put exact ROS topics, endpoint paths, and log counts in notes.

## Block A - Repo pre-flight and Monday scope lock

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

  If `HEAD` and `origin/main` diverge, stop and report both SHAs.

- [x] Re-read the current anchors:

  ```bash
  sed -n '1,460p' working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  sed -n '170,190p' Board.md
  sed -n '310,320p' Board.md
  sed -n '188,200p' wiki/Roadmap.md
  sed -n '604,607p' wiki/Roadmap.md
  sed -n '16,46p' wiki/Pi5_Bringup_Smoke_Test.md
  ```

- [x] Confirm Monday stays docs / staleness / meeting-prep only.
- [x] Confirm whether Tue 09/06 meeting needs a repo-side note only, a short spoken update, or a separate slide / `.pptx` refresh. Do not guess external Windows paths.

**Outcome:** Block A completed on 08/06/2026. `git fetch --prune` first hit the local sandbox's read-only `.git/FETCH_HEAD`, then completed after the repo pre-flight was allowed to update `.git`. `git log --oneline -5` began with `f0e6999`, `305f040`, `0e95195`, `726579c`, and `2e88149`; `git status --short --branch` showed clean `## main...origin/main`; `git rev-parse HEAD origin/main` returned the same SHA `f0e6999227e5978894bd80e0ec545d7b6efca8b6` for both refs. No pull was needed, and no pre-existing user changes were present.

The required anchors were re-read before making status claims. Monday remained documentation / staleness / meeting-prep only. No `.pptx` or external slide path was needed for the repo-side meeting notes; if a slide refresh is requested later, ask for the external path first.

## Block B - Active-doc staleness sweep

Start with the documents most likely to drift after 03/06 through 05/06:

- [x] Check durable status docs:

  ```bash
  rg -n "05/06|04/06|03/06|MAVROS|MAVProxy|RealSense|ROS_DOMAIN_ID|ttyAMA0|14550|14551|Option B|under-voltage|undervoltage|no-fix|rc/in|remap|use_real_hardware" Board.md wiki/Roadmap.md wiki/Pi5_Bringup_Smoke_Test.md
  ```

- [x] Check user-facing docs for stale dashboard / domain / camera wording:

  ```bash
  rg -n "dashboard|rosbridge|web_video_server|camera|ROS_DOMAIN_ID|/wamv|/mavros|/camera/camera|remap|RealSense" README.md USER_MANUAL.md web_dashboard/autoboat/README_autoboat_dashboard.md wiki/Common_Issues.md wiki/Quick_Start.md
  ```

- [x] Check current diary consistency:

  ```bash
  rg -n "Next steps|End-of-day|Option B|power-fix|RealSense|YOLO|MAVROS|/sensors|/wamv" working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  ```

- [x] Classify findings:
  - true stale claim that should be fixed now;
  - historical row that should stay unchanged;
  - generic guide wording that needs a current-boat callout;
  - optional status refresh that can wait.
- [x] Apply only Markdown documentation edits. Leave code/config untouched.

**Outcome:** Block B completed as a Markdown-only staleness sweep.

Classification:

- True stale claim fixed now: `Board.md` footer still said `Last Updated: 04/06/2026` while the board already contained 05/06 status rows. Updated the footer to 05/06/2026.
- Historical rows left unchanged: 03/06, 04/06, and 05/06 timeline / revision rows in `Board.md` and `wiki/Roadmap.md`; they are evidence history, not stale prose.
- Generic guide wording updated with a current-boat callout: `web_dashboard/autoboat/README_autoboat_dashboard.md` now states that the dashboard remains simulation-first, the real-topic adapter is not implemented, RealSense camera display is topic-selector / manual-entry only after `web_video_server` sees `/camera/camera/color/image_raw`, and dashboard mission / thruster controls must not be used against the real FCU until the command path is validated.
- Adjacent dashboard README drift fixed after source verification: `/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust` are now listed as both read feedback topics and manual write topics, matching the dashboard source.
- Optional status refresh that can wait: `README.md`, `USER_MANUAL.md`, `wiki/Common_Issues.md`, and `wiki/Quick_Start.md` still read as generic simulation / dashboard guides. No direct false current-state claim was found in those files during the requested sweep.

## Block C - Tuesday feedback / progress meeting prep

Prepare a concise update for Tue 09/06/2026:

- [x] Write a short progress summary:
  - MAVROS camera-off telemetry path is proven on `/dev/ttyAMA0:57600` through MAVProxy fanout and MAVROS `apm.launch`;
  - domain `12` camera-off graph is clean;
  - GPS remains no-fix / EKF GPS configuration pending;
  - command / write path remains unvalidated;
  - RealSense / combined camera + MAVROS is blocked by Pi 5 power stability;
  - Option B read-only adapter plan is documented but not implemented.
- [x] Write the practical blockers:
  - stable Pi 5 power rail for RealSense / combined load;
  - GPS fix / EKF GPS configuration;
  - command-path validation before any thruster mapping;
  - explicit approval before code/config edits.
- [x] Write the next proposed sequence:
  1. power fix / verification;
  2. RealSense camera-only capture;
  3. MAVROS quick gate on `ROS_DOMAIN_ID=12`;
  4. combined camera + MAVROS capture;
  5. read-only Option B adapter only after code/config approval;
  6. YOLO feasibility only after camera / MAVROS stability.
- [x] Keep the visible story non-technical:
  - "telemetry path now proven";
  - "camera path exists but power-limited under combined load";
  - "dashboard integration has a safe read-only plan";
  - "write/control path is deliberately not mapped yet."

**Outcome:** Tue 09/06/2026 quick feedback / progress meeting notes prepared.

Visible story:

- Telemetry path now proven: the boat telemetry can reach ROS 2 through the Pi 5 in the camera-off setup.
- The ROS 2 graph is clean in the known-good domain-12 telemetry-only run.
- Dashboard / simulation integration has a safe read-only plan that preserves the existing simulation path first.
- The remaining blockers are clear and deliberately bounded: Pi 5 power under RealSense / combined load, GPS no-fix / EKF GPS configuration, and unvalidated command path.

Technical notes to keep behind the visible story:

- Proven endpoint: MAVProxy owns `/dev/ttyAMA0:57600`; MAVROS consumes `udp://127.0.0.1:14550@`; `14551` stays reserved for optional direct-MAVLink inspection.
- 05/06 MAVROS-only evidence: `ROS_DOMAIN_ID=12`, `/mavros/state connected: true`, 136 `/mavros/*` typed topics, raw GPS no-fix, IMU, vehicle battery, and empty RC channels.
- RealSense / combined camera + MAVROS remains power-blocked. The 05/06 pasted log did not include a fresh camera or combined topic pass; the RealSense-launch shutdown is a user-observed event outside that pasted log.
- Command/write path remains unvalidated. Do not map dashboard mission commands, thrusters, actuator paths, or FCU commands to real hardware yet.

Short spoken update:

> Since the 03/06 meeting, the telemetry side moved from endpoint uncertainty to a proven ROS 2 path. MAVProxy now owns the serial link and MAVROS receives telemetry through a UDP fanout, with a clean domain-12 graph and first GPS / IMU / battery / RC samples. The camera side is still blocked by Pi 5 power stability under RealSense load, and GPS is still no-fix, so the next live work is power first, then camera-only, then combined telemetry plus camera. For dashboard integration, the safe plan is read-only: feed existing consumers only after simulation publishers are off, and keep all command / thruster paths parked until they are validated.

## Block D - Optional doc edits and verification

- [x] If Block B finds stale Markdown, patch only the relevant docs.
- [x] Negative-result path not used because stale Markdown was found; record the actual docs-sweep + meeting-prep outcome instead.
- [x] Do not update `Board.md` / `wiki/Roadmap.md` unless durable status wording changes.
- [x] Run checks after any Markdown edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-08_monday_docs_staleness_and_tuesday_feedback_prep.md
  ```

  Also run the standard public-repo visibility sweep from the terminal, then eyeball the commit subject manually before commit.

**Outcome:** Wrap verification completed after the Markdown edits. `git status --short --branch` showed only `Board.md`, `web_dashboard/autoboat/README_autoboat_dashboard.md`, and this diary modified. `git diff --check` passed. The placeholder / conflict-marker scan matched only the embedded scan command in this checklist, not an actual placeholder or merge marker. The standard public-repo visibility sweep returned zero matches. Manual commit-subject eyeball: suggested subject `docs: refresh 08/06 sweep and dashboard status` is conventional, docs-scoped, under 72 characters, and contains no public-repo visibility blocked terms.

## Next steps

Next live work remains unchanged unless explicitly reopened: fix / verify the Pi 5 power rail first, then run RealSense camera-only, a MAVROS-only quick gate on `ROS_DOMAIN_ID=12`, and combined camera + MAVROS. The read-only Option B adapter remains documented but unimplemented until code/config edits are explicitly approved. YOLO stays stretch / future only after power, camera, and MAVROS stability.
