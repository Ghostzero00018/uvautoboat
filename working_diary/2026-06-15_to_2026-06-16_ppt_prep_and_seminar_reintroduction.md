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

## Dashboard reset exception - 15/06/2026

A small dashboard-only fix landed during the PPT-prep window after a live Advanced Configuration issue was noticed: `ee9c366` (`fix(dashboard): reset waypoint approach fields, gate on all defaults`) updates `web_dashboard/autoboat/app.js` so Advanced Configuration Reset Defaults restores the Waypoint Approach fields as well as the PID / speed / safe-distance fields.

Scope stayed narrow: no Gazebo, QGC, Herelink, Pi, real-FCU, arming, upload, parameter-write, thruster, actuator, or live vehicle work was run. Static checks passed before commit: `git diff --check` and `node --check web_dashboard/autoboat/app.js`. Dashboard hard-refresh / live UI retest remains operator-side if needed.

No Board / Roadmap update is needed for this narrow dashboard bug fix; it is not a durable project-status change.

## Tuesday 16/06/2026 - IMT Mines Alès seminar

- [ ] Present the project re-introduction at the seminar.
- [ ] Record only concrete feedback, questions, or action items that are actually said during or after the seminar.
- [ ] Do not infer extra requirements from vague discussion; keep follow-up notes factual.
- [ ] If feedback changes the project direction, record it before restarting practical work.

## Wednesday 17/06/2026 restart note

Practical repo / hardware work starts again on Wednesday 17/06/2026.

First planned practical option from the 12/06 closeout: Block C mixed-topology QGC observation, only if equipment is available and explicitly approved. Keep it user-run by default and preserve the boundary: no upload or control path.

## Next steps after seminar

- Wednesday 17/06/2026: decide whether to start Block C mixed-topology observation.
- Optional docs cleanup remains separate and approval-gated.
- Block E implementation remains separate and approval-gated.
