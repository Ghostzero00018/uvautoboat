# Friday 04/09/2026 - verify the stop-path fixes, then the stale-docs update

**PRE-DIARY. Written 03/09/2026 at end of day. Nothing below has been run or
implemented. Read the 03/09/2026 diary first, in particular "Day close" and
"Correction to the stop".**

**The session record from `16:30` on 04/09/2026 is appended at the end. The
pre-diary sections stay as written; where the record differs, the record is
what happened.**

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

Same as 03/09 with the two fixes committed. The workstation preflight already
passed on the committed tree on 03/09/2026 at `21:07` (`7d1eece`: VRX `36`
shell and `48` Python, helper `83`, dashboard `110`, `FULL_STACK_CHECK=PASS`),
so the morning starts at the Pi pins. Rerun it only if the worktree changed:

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

**Inside the armed verification window - first use of auto-move:** after all
READY markers and external arming, use the bench panel's `Hold to Run Auto
Move` before the dashboard E-stop or either supervisor is stopped. Defaults:
throttle `0.17`, straight `5` s, then right, steering `0.10`, `5` s. Hold it;
release at any instant is neutral. Watch three things: the propellers follow
the two phases, the capture records `ACTIVE` frames with the profile's values,
and the side selector's sign matches which way the hull tries to turn - if it
is reversed, the mixer convention in the label is wrong and the sign flips in
`readFcuBenchAutoMoveConfig`. Hull restrained as declared. This dashboard-only
feature was implemented on the evening of 03/09/2026 with nine tests and has
not yet run on hardware.

**Stop, in the corrected order:** dashboard E-stop, then external disarm and
safe state, then Ctrl+C on the workstation terminal, then Pi Ctrl+C and the
closeout token, then wait for the Pi to print
`waiting for workstation operator stop before bridge shutdown`, then Enter at
the workstation prompt.

Fix B was already rehearsed against the real supervisors on the evening of
03/09 (`REHEARSAL4=PASS`: wording present, prompt answered, `stop=clean`), so
the run only has to prove Fix A. What proves it:

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

## Session record - 04/09/2026, at the bench

Pi and flight controller present from `16:30`. Committed before the session:
`38fac0e` moved the auto-move paragraph inside the armed window and corrected
the runbook's copy-back path to `~/Desktop/test_logs_folder/pi_run_evidence/`,
where the 02/09 and 03/09 Pi run directories already were. The workstation
preflight was not rerun: the tree was docs-only since the `7d1eece` pass. Pi
Hailo checkout on `891ce701c2ebe239a5d277759eb75a30f76678a9` and clean.

### The Hailo driver was gone: a kernel update without headers

Workstation launcher at `16:31:00`, run directory
`real_fcu_full_stack_20260904_163100`; W2 prestart at `16:31:10`, then the
`HAILO MODE` hint. The Pi helper's first start passed the bundle and Hailo
pins and stopped at `STOP: /dev/hailo0 missing`.

Read-only look on the Pi: `uname -r` gave `6.8.0-1064-raspi`; `dkms status`
listed `hailo_pci/4.24.0` installed for `6.8.0-1063-raspi` only; `lsmod` had no
`hailo_pci`; `lspci` still listed the Hailo-8 at `0000:01:00.0`. The Pi had
taken the kernel update from `1063` to `1064` since 03/09 with no headers for
it, so DKMS could not rebuild the module and the device node was never
created. Nothing physical.

Fix at `16:36`, on the Pi:

```bash
[ -e /lib/modules/$(uname -r)/build ] || sudo apt-get install -y linux-headers-$(uname -r); sudo dkms install hailo_pci/4.24.0 -k $(uname -r) && sudo modprobe hailo_pci && ls -l /dev/hailo0 && lsmod | grep -i hailo
```

`apt` pulled `linux-headers-6.8.0-1064-raspi` and
`linux-raspi-headers-6.8.0-1064` (`16.6` MB); the headers' postinst ran the
DKMS autoinstall, which built and installed `hailo_pci.ko.zst` for `1064`, so
the explicit `dkms install` reported "already installed". `modprobe` then gave
`crw-rw-rw- 1 root root 509, 0 /dev/hailo0` and `hailo_pci 126976 0`. Six
minutes lost, inside the workstation's `1200` s wait for the Pi feed.

Root cause and the durable fix, not applied: the Pi has no
`linux-headers-raspi` meta-package, so every kernel update arrives without
headers and removes Hailo until the headers are installed by hand.
`sudo apt-get install linux-headers-raspi` on the Pi (package name untested)
would make future updates carry their headers and let DKMS rebuild on its
own. Operator's decision.

### Second start, READY on both machines

Pi helper at `16:37:24`, run directory `real_fcu_t3a_pi_20260904_163724`:
`REAL_FCU_HAILO_PERSON_STOP=PASS ... person_alert=fresh-clear`, guard snapshot
`PASS` on `5ea352bc` with `parameter_write=none`, telemetry `PASS`, bridge
resolved `986` parameters, `RC1/RC3`, `SERVO3/SERVO1`. In `run-t3a` the helper
prints its propulsion-enable and safety-release gate lines with
`source=approved-runtime-flags operator_action=external` and does not pause at
them; the physical steps and their timing are the operator's.
`REAL_FCU_PI_READY=PASS`, then `REAL_FCU_T3A_READY=PASS ... hailo=ready
person_alert=advisory-no-stop display=local-window`. Workstation: capture
`READY` at `16:37:37` (`real_fcu_capture_t3a_esc_threshold_20260904_163737`),
`REAL_FCU_WORKSTATION_READY=PASS ... hailo=image,person-detections
person_alert=advisory-no-stop`, bench URL carrying
`thrust_left_servo=3&thrust_right_servo=1`.

Bridge timeline from the capture: `READY_DISARMED` at `16:41:13`,
`ARMED_NEUTRAL` at `16:42:14` on the external arm, dashboard page loaded at
`16:42:31`, seventeen seconds after arming, and it primed the epoch on its
first armed status, as read in the code that morning. Hardware Safety read
`RELEASED`, sticks `1515/1515` us, outputs `800/800` us.

### Defect - auto-move with the mouse releases itself after one frame

From `16:44:19` to `16:46:21` the operator pressed `Hold to Run Auto Move`
with the mouse at throttle `0.17`, `0.18`, `0.15` and `0.20`. Every press
produced exactly one enabled frame: `20` single-frame bursts in the capture,
each with the bridge going `ACTIVE` for one status and back to
`ARMED_NEUTRAL`, alert fresh and feedback fresh throughout. The bridge was
never the problem; the page stopped sending.

The manual hold worked and sustained in the same minutes: `16:47:53` to
`16:48:57`, holds up to `13.7` s at steering `+0.12` throttle `0.10` (left
`1090` us, right `800` us), and at throttle `0.17` with steering `-0.03` or
`+0.03` (`983/1064` us, sides swapping with the sign).

Cause, confirmed after the run on a static copy of the page served locally at
the run's window width: the first enabled frame writes the status text
(`Straight — steering 0.00, throttle 0.20`) into the auto-move box above the
buttons; the box is `238` px wide there, the text wraps, the box grows by
`46` px and the `64` px button moves down under the stationary pointer. The
browser reports the pointer leaving the button, and pointer-leave is the
release path, exactly as for a plain hold. The manual hold never changes the
layout, so it never sees this; a keyboard hold does not involve the pointer.
The dashboard suite cannot see it either: its element stubs have no layout.

Workaround used, no code change: click `Neutral Now` (which also re-primes
after a handback), Tab twice to the auto-move button, hold Space.

### Auto-move first use, by keyboard

`16:55:34` to `16:55:44`, `10.4` s: straight at throttle `0.20`, then steering
`+0.18`: left `1315` us, right `1066` us, and the hull turned right, operator
observed, so the side label ("right: +steering, left propeller faster")
matches the mixer. Repeated at `16:56:27`. `16:57:07`: throttle `0.18`, turn
`+0.03`. A Herelink handover and handback from `16:58:23` to `16:59:04`, then
four `15` s runs from `17:00:00` to `17:05:16` at throttle `0.18`, `10` s
straight and `5` s turn at `0.03` to either side. The status line showed the
phases and returned to `Idle`; every run ended itself at the profile's end.

The operator's statement for the record: on both 03/09 and 04/09, the real
propellers and the VRX twin moved together on the same dashboard command.
That is the two-way digital twin working end to end, the project's first
success criterion.

### The stop - both fixes proven

Order actually executed: external disarm at `17:07:33` (`READY_DISARMED`),
dashboard E-stop at `17:10:53` (`EMERGENCY_STOP`), workstation Ctrl+C at
`17:11:37`. The documented order is E-stop first; the verdict's two checks
passed anyway because the E-stop was recorded before the capture ended.

Workstation: `REAL_FCU_CAPTURE_FINAL=FAIL tier=T3A
reasons=calibration_left_observation_incomplete,calibration_right_observation_incomplete`,
the two calibration reasons only; `final_status_not_disarmed` and
`tier_status_sequence_incomplete` are gone (Fix B). W2 `stopped cleanly after
7s`; the closeout prompt named the Pi line to wait for; Enter at `17:12:32`
after the Pi had printed it; W1 `stopped cleanly after 6s` with one straggler,
the `ros2` daemon, terminated by the wrapper; `FULL_STACK_EXIT status=0
stop=clean` at `17:12:40`.

Pi: `REAL_FCU_T3A_SAFE_CLOSEOUT=PASS`, `REAL_FCU_FINAL_STATE=PASS
connected=true armed=false`, `waiting for workstation operator stop before
bridge shutdown`, then `REAL_FCU_WORKSTATION_STOP=PASS marker=received` with
no manual republish: W1's marker log shows the five-publish burst (Fix A).
`REAL_FCU_PI_EXIT status=0 cleanup_rc=0`. Nothing survived on the workstation;
ports `8002`, `8080` and `9090` free.

Capture: `38,946` bridge statuses from `16:39:09` to `17:11:37`; `4,119`
demand frames, `3,111` of them enabled, in `48` bursts of which `8` lasted
`10` s or more; `7,915` RC-in and `7,913` RC-out samples; verdict
`final_status` `EMERGENCY_STOP` latched with `armed:false`.

### Open after the session

- Auto-move mouse hold: fix proposed as pointer capture on both hold buttons
  plus a fixed-height status line, a code change awaiting approval; verify on
  hardware at the next bench session.
- Pi: install the kernel-headers meta-package so kernel updates keep Hailo
  alive; operator's decision.
- Fix C unchanged.
- Copy back `real_fcu_t3a_pi_20260904_163724`.

### Evening - the mouse-hold fix, approved and landed

Approved after the copy-back. Tests first, on the untouched code: the
harness element stub gained `setPointerCapture`, which records pointer ids.
The first three cases assert that each hold button captures pointer id `7` on
`pointerdown` and still releases on `pointerup` with a disabled frame, and
that a press whose capture call throws still starts the hold. The capture
cases were red as expected (`[]` against `[7]`). Review added a fourth
characterisation case: keyboard activation of both buttons requests no
pointer capture. A first version
of the cases called `initFcuBenchLoop` after `readyBenchHarness` already had,
which registered the listeners twice and captured `[7, 7]`; the extra call
was removed.

Change, dashboard only: `captureHoldPointer(event)` in `app.js` takes the
event's `currentTarget`, returns without effect when the element has no
capture method, calls `setPointerCapture(event.pointerId)` inside a
`try/catch`, and is called by both `pointerdown` handlers before the start;
keyboard handlers do not call it. `style_merged.css` gives
`#fcu-loop-auto-status` `display: block` and `min-height: 2.6em`, reserving the
tested two-line phase height; pointer capture remains responsible for
continuity under any other reflow. Suite `114`, all passing. Mutants: removing
the auto-move call fails only its capture case; making the helper rethrow fails
only the refusal case; adding capture to a keyboard handler fails the keyboard
isolation case.

Browser, a static copy served on `8003` at `800` px wide: the three phase
texts now shift the buttons by `0` px (status height reserved at `52` px);
the "Rejected" text still shifts them by `17` px, when no hold is running.
Drag test on the fixed page: pointer down on the auto-move button, a `230` px
slide off it, release. Events on the button, in order: `pointerdown`,
`gotpointercapture`, `pointerup`, `lostpointercapture`, `pointerleave`. The
release arrived and no leave fired while pressed. Two test-rig notes: the
unconnected page keeps the bench controls `inert` and disabled, which hides
them from hit-testing until pinned off for the test, and the browser pane's
coordinates scale by about `1.08` against the emulated viewport, which cost
two missed drags.

Behaviour change to know: sliding the pressed mouse off the button no longer
releases the hold; releasing the mouse button does, anywhere, as do the other
release paths. Recorded in the runbook. Not yet run on hardware.
