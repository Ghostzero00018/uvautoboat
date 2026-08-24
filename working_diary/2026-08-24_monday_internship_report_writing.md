# Monday 24/08/2026 - internship report writing and documentation-only closeout

## Status

The day went to the internship report. No code, configuration, test, simulator
run, Pi session, control box, Herelink, live run or hardware contact of any kind
occurred on this repository.

The only repository work is this end-of-day documentation closeout itself: this
record, the deferral of the day's plan, and the commit that carries both.

The report is tracked in a separate private repository and is out of scope for
this diary. Nothing about its content is recorded here.

## Repository state

`a284cae` is the technical baseline as it stood **before** this documentation
closeout. At close-out, `HEAD == main == origin/main` at that revision with
divergence `0/0`; the certification proves the close-out state, not that it held
continuously all day. It is a documentation commit, subject
`docs(diary): scaffold 24/08 FCU-to-VRX twin proposal`, and it closed
21/08/2026. No commit of any kind was authored on 24/08/2026 before this
closeout. The closeout commit that carries this file advances `HEAD` beyond
`a284cae`; that commit's own revision is not recorded here, and the next working
day's startup certifies against whatever `origin/main` then holds.

Production pins are untouched by today:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `73,862` bytes | `a72cd04d37984d692cdfecb73456d55bc7bb6f0b4fd69d69ba79447fc3594a97` |
| `tools/live_dashboard_preflight.sh` | `29,058` bytes | `d101ec5840c1358e0475fff33989af9b3f3431231859c0e0e1c2ffa0fafab82a` |

The four-file bundle is likewise untouched. It holds revision `2600ea4` with
manifest digest
`8c4f04a69fef395ec70735f6ac5485d315da7955ba6aeb3b76473aa155de2eec`, deployed and
verified on 21/08/2026 at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260821_2600ea4`. Every earlier
dated root is preserved and none is reused.

## Planned work deferred

This date was scaffolded for the FCU-to-VRX digital twin proposal. That plan was
**not started**: no stage was approved, no simulator, bridge or autopilot process
was launched, and no certification was performed. It has been moved to
`working_diary/2026-08-25_tuesday_fcu_to_vrx_digital_twin_plan.md`.

The unstarted plan file was renamed for 25/08, and this new canonical 24/08
record was added to match what the day actually was. The plan had never been
started, so no record was overwritten.

The move preserves the plan's substantive scope. All three stages, their
separate approvals, the transport reasoning, the read-live requirements and
every boundary are carried across. Two adjustments were made, neither of which
alters scope:

- The heading and the sole-continuation sentence were redated to 25/08/2026.
- That sentence now records that the file was scaffolded for 24/08, moved after
  the report day, and carries no approval from **either** 21/08 or 24/08. No
  physical approval crosses either date boundary.

## Carried forward, unchanged

The query tier remains open. The link-configuration experiment is closed as a
completed negative: the candidate was applied, reproduced the same failure, and
was rolled back and verified. The remaining direct-link transmit, receive and
endpoint hypotheses are unresolved, and no untried bounded diagnostic is
currently proposed.

**Stages 1 and 2 of the moved plan remain unblocked by that**, because they
consume autopilot output over a network transport and never use the failing
request direction. **Stage 3 remains fully gated** behind the query tier and
both bench tiers, each with its own approval; arming the vehicle and moving the
sticks is bench-input work in substance regardless of where the resulting
numbers are displayed.

The dashboard rail-relative reading stays **implemented and unit-verified but
not runtime-accepted**: the full supervisor rerun on the published revision is
still **NOT RUN**. The 21/08 workstation capture remains `PARTIAL_UNFINALIZED`,
preserved and not credited.

**Next step:** Tuesday 25/08/2026, the deferred FCU-to-VRX digital twin
proposal, beginning with live certification and stopping before Stage 1.
