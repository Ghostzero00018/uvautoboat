# Friday 04/09/2026 - verify the stop-path fixes, then the stale-docs update

**PRE-DIARY. Written 03/09/2026 at end of day. Nothing below has been run or
implemented. Read the 03/09/2026 diary first, in particular "Day close" and
"Correction to the stop".**

## Where the day starts

Bundle `a8bed50` is deployed and certified on the Pi at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260903_a8bed50`. It carries
the `0.20` ceiling, advisory mode, the snapshot-guard retry and the resizable
Hailo window. The full showcase held on 03/09/2026 for a `42`-minute armed run
from one command per machine: Hailo images on the dashboard and on the Pi
desktop, demand reaching the propellers with the simulator following, `96`
detections against `0` latches, Herelink arm and disarm live on the dashboard.

Two defects from that run's **stop** are open, both workstation-side, neither
touching the bundle:

1. W1's stop marker can be lost. `rfcu_ws_publish_stop_marker` uses
   `ros2 topic pub --once --wait-matching-subscriptions 1`, which sends the
   instant the publisher counts a match; the `VOLATILE` reader on the Pi may
   not have completed its side, and W1 exits at once. On 03/09 the Pi sat at
   its marker wait until the marker was republished by hand.
2. The entry point's stop order puts Ctrl+C before the E-stop press, so the
   capture ends before it can record the terminal `EMERGENCY_STOP` the `t3a`
   verdict expects, adding two spurious reasons to every verdict.

The ESC start threshold is recorded as an operator reference figure and the
typed calibration is not its source. Its `calibration` field staying `null` is
expected.

## Task 1 - morning: fix the stop path and run the stack once to verify

### Fix A - W1 marker publish, `tools/real_fcu_digital_twin_workstation.sh`

`rfcu_ws_publish_stop_marker`, around line `666`. Replace `--once` with a
short burst so a reader that completes its match late still receives one:
`--times 5 --rate 2` with `--wait-matching-subscriptions 1` kept. Both flags
exist in Jazzy's `ros2 topic pub`. The Pi's reader is `--once` and its validity
check requires exactly one document in the capture, which a burst still gives
it since the reader exits on the first message. Add a helper-suite case that
extracts the function and asserts `--times` is present and `--once` is not,
and prove it against a mutant. W1 is not a bundle member; no transfer.

### Fix B - the entry point's stop wording, `tools/real_fcu_full_stack_workstation.sh`

Two strings. The closeout prompt should name the Pi line to wait for:
`waiting for workstation operator stop before bridge shutdown`. The operator
block and the run-sheet should put the dashboard E-stop press **before** the
workstation Ctrl+C, so the capture records `ACTIVE -> EMERGENCY_STOP`. Wrapper
suite case: the prompt text contains the Pi line. No bundle change.

### Fix C - only if time: decouple calibration from `pass`, `tools/real_fcu_command_feedback_capture.py`

`t3a` currently requires `--esc-threshold-calibration` and fails `pass` on the
two calibration reasons. Either make the flag optional for `t3a` or keep the
reasons informational. This is a verdict-semantics change with its own tests;
decide with the operator before touching it. Not needed for the verification
run.

### The verification run

Same as 03/09 with the two fixes committed. Workstation preflight first; it
refuses a dirty worktree, so commit before `check`.

```bash
cd ~/seal_ws/src/uvautoboat && bash tools/real_fcu_full_stack_workstation.sh check
```

Pi pins unchanged: `git -C ~/hailo_coco_overlay_2026-07-10/hailo-apps rev-parse HEAD`
must print `891ce701c2ebe239a5d277759eb75a30f76678a9` and the status must be
empty. FCU powered and steady before the Pi helper starts.

```bash
cd ~/seal_ws/src/uvautoboat && REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1 bash tools/real_fcu_full_stack_workstation.sh run-t3a
```

Start the Pi as soon as the `HAILO MODE: start the Pi helper NOW` line prints.
The Pi command is the 03/09 one, unchanged, from a Remmina terminal, in the
`a8bed50` bundle directory, with `REAL_FCU_HAILO_LOCAL_DISPLAY=1` and the
thirteen declarations as the operator's own.

**Stop, in the corrected order:** dashboard E-stop, then external disarm and
safe state, then Ctrl+C on the workstation terminal, then Pi Ctrl+C and the
closeout token, then wait for the Pi to print
`waiting for workstation operator stop before bridge shutdown`, then Enter at
the workstation prompt.

What proves the fixes:

- The Pi prints `REAL_FCU_WORKSTATION_STOP=PASS marker=received` **without** a
  manual republish, and `REAL_FCU_PI_EXIT status=0 cleanup_rc=0`.
- The workstation prints `FULL_STACK_EXIT status=0 stop=clean`.
- The capture verdict's reasons are only the two calibration ones, or none if
  Fix C landed. `final_status_not_disarmed` and `tier_status_sequence_incomplete`
  must be gone.

A short armed window is enough; the advisory proof is already recorded. Copy
the Pi run directory back afterwards as on 03/09.

## Task 2 - the rest of the day: the stale-docs update

Forty tracked pages outside the diaries, about `17,000` lines. The audit on
03/09 found these specific stale claims; treat the list as the starting point,
not the boundary, and grep each claim against source before changing it.

### Decision to make first

`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` is `2,000` lines and mixes two
procedures: the older `tools/live_dashboard_preflight.sh` plus
`tools/pi_live_hailo_mavlink_dashboard.sh` flow, and the real-FCU T3a stack
that now runs from `tools/real_fcu_full_stack_workstation.sh`. The T3a
procedure exists on that page only as two forward notes added 03/09. Its "Start
and stop order" at line `1111` describes the older tool's order, which is not
this stack's order. Choose one:

- split: leave the page as the older tool's runbook and write a new
  `Real_FCU_Digital_Twin_Runbook.md` for the entry point, the Pi command, the
  declarations, the stop order, the evidence layout, how to read the verdict,
  the ESC reference, advisory mode and the window; or
- restructure in place, with the T3a stack first and the older flow moved to a
  clearly dated section.

The split is the smaller edit and the clearer read. Either way the run-sheet
stops living in diaries.

### Stale claims with anchors

| Surface | Line | Claim | Correction |
| --- | --- | --- | --- |
| `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` | `429` | `max_throttle=0.12` unchanged | ceiling is `0.20` since 02/09 |
| same | `1111` | start W1 then W2, W1 rejects `gz sim` | that is `live_dashboard_preflight.sh`; the T3a stack starts W2 first from the entry point |
| same | `77` | display defaults, `HAILO_LOCAL_DISPLAY` | that is the older tool; T3a uses `REAL_FCU_HAILO_LOCAL_DISPLAY` |
| `web_dashboard/autoboat/README_autoboat_dashboard.md` | `277` | run `live_dashboard_preflight.sh run`, fullscreen window | the T3a path and its entry point are absent from this README |
| same | `386` | `max_throttle=0.12` in the calibration verdict text | `0.20`; calibration is not the threshold's source |
| `README.md` | `88` onward | Quick Start is simulation only | correct as far as it goes; add a real-hardware pointer to the runbook |
| `wiki/Home.md`, `wiki/Quick_Start.md`, `wiki/System_Overview.md` | whole | no mention of the real-FCU stack | link the runbook; state the current hardware stack |
| `Board.md` | `511` | Active System lists only the LiDAR modular system | add the real-FCU digital twin as an active system |
| `Board.md` | `885` to `1193` | Next Priorities leads with the 05/08 graph-query item, `300` lines | rewrite to today's priorities; move history down |
| `Board.md` | `1119` | "propellers-removed calibration" | threshold measured props fitted; reference values recorded |
| `Board.md` | `623` to `693` | Phase 5 task lists predate the hardware runs | mark what the 02/09 and 03/09 runs completed |
| `wiki/Roadmap.md` | `570` | "propellers-removed calibration" | as above; check whether the row is history or status first |
| `wiki/Roadmap.md` | §3 table | many 02/09 and 03/09 rows | consider one summary row per day above the detail |
| `wiki/Pi5_Bringup_Smoke_Test.md`, `Hailo_HAT_Workstream.md`, `Hailo_COCO_Overlay_Demo.md` | dated 04/08 and 25/08 | Hailo status predates the T3a integration | add a status pointer to the 03/09 result |
| `legacy/misc/PORT_ALLOCATION.md` | `54` | untagged code fence, MD040 | tag it, or leave as frozen and say so |

Undated pages to sweep for stale terms: `Glossary`, `System_Overview`, `SASS`,
`3D_LIDAR_Processing`, `Quick_Start`, `UPLOAD_INSTRUCTIONS`. Oldest dated:
`Node_Naming_Refactor_Plan` (28/04), `Design_Rationale` (29/04),
`Installation_Guide` and `VRX_Fork_Migration` (06/05).

### Method for the day

- Audit before edit: every claim changed is checked against the source in the
  same turn. Runtime configuration outranks implementation defaults, which
  outrank design notes, which outrank status records.
- Dated history rows stay as written; corrections are new rows or forward
  notes. Living sections are rewritten.
- One docs commit per surface or per coherent group, message text only.
- Dates `DD/MM/YYYY` in prose, tagged fences, single `#` per file, one-line
  pipe cells.
- Include the dashboard README in every audit pass, not just the wiki.

## Carried open items

- Fresh-boot UART probe: `stty -F /dev/ttyAMA0 57600 raw` before `cat`, or a
  counter pair while a process holds the port. Untested; the 02/09 run-sheet
  step zero gives a false dead-link reading without it.
- Pi clock read `Aug 27` at boot; verify NTP corrects it.
- GPS has no fix indoors; the self-navigation task from the 03/09 pre-diary
  needs sky and is otherwise unchanged.
- Workspace layout after 03/09: `~/seal_ws/{src,build,install,log}`, built with
  `colcon build --merge-install` from `~/seal_ws`, never from `src/`. The
  misplaced trees were removed.
- `legacy/misc/PORT_ALLOCATION.md:54` MD040, flagged 02/09.
