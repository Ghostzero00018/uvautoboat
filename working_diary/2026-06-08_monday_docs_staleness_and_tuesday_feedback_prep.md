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

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report both SHAs.

- [ ] Re-read the current anchors:

  ```bash
  sed -n '1,460p' working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  sed -n '170,190p' Board.md
  sed -n '310,320p' Board.md
  sed -n '188,200p' wiki/Roadmap.md
  sed -n '604,607p' wiki/Roadmap.md
  sed -n '16,46p' wiki/Pi5_Bringup_Smoke_Test.md
  ```

- [ ] Confirm Monday stays docs / staleness / meeting-prep only.
- [ ] Confirm whether Tue 09/06 meeting needs a repo-side note only, a short spoken update, or a separate slide / `.pptx` refresh. Do not guess external Windows paths.

**Outcome:** Pending Monday execution.

## Block B - Active-doc staleness sweep

Start with the documents most likely to drift after 03/06 through 05/06:

- [ ] Check durable status docs:

  ```bash
  rg -n "05/06|04/06|03/06|MAVROS|MAVProxy|RealSense|ROS_DOMAIN_ID|ttyAMA0|14550|14551|Option B|under-voltage|undervoltage|no-fix|rc/in|remap|use_real_hardware" Board.md wiki/Roadmap.md wiki/Pi5_Bringup_Smoke_Test.md
  ```

- [ ] Check user-facing docs for stale dashboard / domain / camera wording:

  ```bash
  rg -n "dashboard|rosbridge|web_video_server|camera|ROS_DOMAIN_ID|/wamv|/mavros|/camera/camera|remap|RealSense" README.md USER_MANUAL.md web_dashboard/autoboat/README_autoboat_dashboard.md wiki/Common_Issues.md wiki/Quick_Start.md
  ```

- [ ] Check current diary consistency:

  ```bash
  rg -n "Next steps|End-of-day|Option B|power-fix|RealSense|YOLO|MAVROS|/sensors|/wamv" working_diary/2026-06-05_friday_dashboard_sim_real_integration_plan.md
  ```

- [ ] Classify findings:
  - true stale claim that should be fixed now;
  - historical row that should stay unchanged;
  - generic guide wording that needs a current-boat callout;
  - optional status refresh that can wait.
- [ ] Apply only Markdown documentation edits. Leave code/config untouched.

**Outcome:** Pending Monday execution.

## Block C - Tuesday feedback / progress meeting prep

Prepare a concise update for Tue 09/06/2026:

- [ ] Write a short progress summary:
  - MAVROS camera-off telemetry path is proven on `/dev/ttyAMA0:57600` through MAVProxy fanout and MAVROS `apm.launch`;
  - domain `12` camera-off graph is clean;
  - GPS remains no-fix / EKF GPS configuration pending;
  - command / write path remains unvalidated;
  - RealSense / combined camera + MAVROS is blocked by Pi 5 power stability;
  - Option B read-only adapter plan is documented but not implemented.
- [ ] Write the practical blockers:
  - stable Pi 5 power rail for RealSense / combined load;
  - GPS fix / EKF GPS configuration;
  - command-path validation before any thruster mapping;
  - explicit approval before code/config edits.
- [ ] Write the next proposed sequence:
  1. power fix / verification;
  2. RealSense camera-only capture;
  3. MAVROS quick gate on `ROS_DOMAIN_ID=12`;
  4. combined camera + MAVROS capture;
  5. read-only Option B adapter only after code/config approval;
  6. YOLO feasibility only after camera / MAVROS stability.
- [ ] Keep the visible story non-technical:
  - "telemetry path now proven";
  - "camera path exists but power-limited under combined load";
  - "dashboard integration has a safe read-only plan";
  - "write/control path is deliberately not mapped yet."

**Outcome:** Pending Monday execution.

## Block D - Optional doc edits and verification

- [ ] If Block B finds stale Markdown, patch only the relevant docs.
- [ ] If no stale docs are found, record the negative result and keep the day diary-only.
- [ ] Do not update `Board.md` / `wiki/Roadmap.md` unless durable status wording changes.
- [ ] Run checks after any Markdown edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-08_monday_docs_staleness_and_tuesday_feedback_prep.md
  ```

  Also run the standard public-repo visibility sweep from the terminal, then eyeball the commit subject manually before commit.

**Outcome:** Pending Monday execution.

## Next steps

Monday 08/06/2026 starts with the repo pre-flight, then a docs / staleness sweep, then Tuesday feedback prep. Hardware work, RealSense retest, combined MAVROS + camera, YOLO, and the read-only Option B adapter all remain parked unless explicitly reopened.
