# 2026-06-15 to 2026-06-16 - PPT prep and seminar re-introduction

## Purpose

Monday 15/06/2026 and Tuesday 16/06/2026 are reserved for PPT preparation and seminar presentation work, not repo or practical execution.

The Tuesday 16/06/2026 seminar at IMT Mines Alès needs a simple re-introduction of the whole AutoBoat project: what the project is, what has been built, current real-hardware status, and what practical work resumes afterward.

## Boundaries

- No repo implementation work on 15/06/2026 or 16/06/2026.
- No practical Gazebo, QGC, Herelink, Pi, real-FCU, control-box, arming, upload, parameter-write, thruster, actuator, or live vehicle work.
- No durable-doc cleanup unless explicitly approved after the seminar.
- Practical work resumes from Wednesday 17/06/2026.

## Monday 15/06/2026 - PPT preparation

- [ ] Prepare a simple whole-project re-introduction for the seminar.
- [ ] Keep the story high-level: project goal, simulation stack, web dashboard, planner, controller, perception, real-hardware bring-up, QGC / MP status, and remaining blockers.
- [ ] Reuse existing project evidence and screenshots only; do not start new live tests for slide material.
- [ ] Keep technical claims bounded to what is already recorded in `Board.md`, `wiki/Roadmap.md`, and recent working diaries.
- [ ] Prepare a short ending slide: practical work resumes Wednesday 17/06/2026.

**EOD 15/06/2026:** Monday closed. The PPT-only day was instead spent on two narrow, now-landed code exceptions (documented below); the seminar re-introduction draft was not started, so the five preparation tasks above carry forward into the 16/06 prep window.

**Next steps:** complete the carried-forward PPT re-introduction draft in the 16/06 window. The 16/06 seminar and 17/06 restart plans recorded below are unchanged.

## Dashboard reset exception - 15/06/2026

A small dashboard-only fix landed during the PPT-prep window after a live Advanced Configuration issue was noticed: `ee9c366` (`fix(dashboard): reset waypoint approach fields, gate on all defaults`) updates `web_dashboard/autoboat/app.js` so Advanced Configuration Reset Defaults restores the Waypoint Approach fields as well as the PID / speed / safe-distance fields.

Scope stayed narrow: no Gazebo, QGC, Herelink, Pi, real-FCU, arming, upload, parameter-write, thruster, actuator, or live vehicle work was run. Static checks passed before commit: `git diff --check` and `node --check web_dashboard/autoboat/app.js`. Dashboard hard-refresh / live UI retest remains operator-side if needed.

No Board / Roadmap update is needed for this narrow dashboard bug fix; it is not a durable project-status change.

## Health-check hardening exception - 15/06/2026

A second narrow exception during the PPT-prep window: the dashboard Health Diagnosis was timing out at its 90s watchdog when run during return-home. The cause was unbounded `ros2` CLI probes in `one_click_launch_all/health_check_autoboat.sh` blocking against a CPU-saturated single-threaded perception node — a wedged probe held the command-substitution pipe open (surfacing as a `ros2 param get max_range` `BrokenPipeError`) until the watchdog killed the whole run. Hardened across `3423085` (per-probe timeout), `f09a5b0` (temp-file output isolation, `timeout -k` force-kill, and a shared probe helper), and `fd6e18f` (skip a node's remaining parameter probes once its tuned-flag probe times out).

Live-validated during return-home: no watchdog kill, `FAIL: 0`, slow perception probes degrade to `WARN`, and the run finished in ~88s. Scope stayed narrow: the only practical run was the dashboard Health Diagnosis during an already-running return-home simulation; no QGC, Herelink, Pi, real-FCU, arming, upload, parameter-write, thruster, actuator, or live vehicle work was run. Static checks (`bash -n`, `git diff --check`) passed before each commit.

The deeper root cause — the perception node's parameter service being unresponsive under load (single-threaded executor) — is left as a separate, approval-gated task. No Board / Roadmap update is needed for this narrow diagnosis-tool robustness fix.

## Tuesday 16/06/2026 - IMT Mines Alès seminar

- [x] Present the project re-introduction at the seminar.
- [x] Record only concrete feedback, questions, or action items that are actually said during or after the seminar.
- [x] Do not infer extra requirements from vague discussion; keep follow-up notes factual.
- [x] If feedback changes the project direction, record it before restarting practical work.

**EOD 16/06/2026:** Tuesday seminar closed. No concrete new seminar requirement or direction change was recorded here. The only follow-up captured today is a separate dashboard-control anomaly noticed during testing: after Stop paused an active mission, hovering over the Resume button appeared to restart motion before an actual click.

Source inspection found no mission-control hover handler in `web_dashboard/autoboat/app.js` or `web_dashboard/autoboat/index.html`: Start, Stop, Resume, Reset, Return Home, E-Stop, and joystick controls are all `click`-wired, and `resume_mission` is published only inside the Resume click callback (the single publish site). CSS hover rules for mission buttons only change visual styling. Planner/controller inspection confirmed `PAUSED` is sticky: the planning loop returns while not `DRIVING`, the only writes back to `DRIVING` come from `start_mission` / `resume_mission` / `go_home`, and the controller mirrors planner state with no independent re-enable. So the boat cannot resume without one of those commands.

Live repro (16/06/2026, full stack, single browser tab) did not reproduce the anomaly: hovering Resume published nothing on `/planning/mission_command`, and the boat did not move. Stop reached a sticky `PAUSED` (held at waypoint 15/20 across every status tick), and only the three deliberate commands appeared on the echo (`confirm_waypoints`, `start_mission`, `resume_mission`). One method note: `ros2 topic info /planning/mission_command -v` reported `Publisher count: 0` because rosbridge advertises a publisher only transiently per publish, so `ros2 topic echo` is the reliable signal and `ss -tnp | grep ':9090'` is the right check for the number of open dashboard tabs.

Most likely cause of the original observation: residual momentum/drift in the moments after Stop, or a one-off accidental real click (touchpad tap-to-click) — neither a code defect. As a low-cost safeguard, the dashboard Start and Resume buttons now carry the same `confirm()` accidental-click guard that Reset, Go Home, and Emergency Stop already use; Stop stays immediate. If the behaviour ever recurs, capture `/planning/mission_command` (echo) plus the rosbridge socket count to confirm whether a real command was sent.

## Wednesday 17/06/2026 restart note

Practical repo / hardware work starts again on Wednesday 17/06/2026.

First planned practical option from the 12/06 closeout: Block C mixed-topology QGC observation, only if equipment is available and explicitly approved. Keep it user-run by default and preserve the boundary: no upload or control path.

## Next steps after seminar

- Wednesday 17/06/2026: decide whether to start Block C mixed-topology observation.
- Dashboard Resume-hover anomaly: live repro found no hover command path and the boat did not move; Start/Resume confirm guard added. Closed unless it recurs.
- Optional docs cleanup remains separate and approval-gated.
- Block E implementation remains separate and approval-gated.
