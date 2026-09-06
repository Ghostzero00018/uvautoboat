# Monday 07/09/2026 - bounded T3a demonstration video, parameter closure, handover week

**PRE-DIARY. Written on the morning of 07/09/2026 before any hardware was
powered. Nothing below has been run. Read the 04/09/2026 diary first, in
particular "Night close" and "Open after the session".**

## Where the day starts

Repository `2a16a1c` is HEAD, clean and pushed. The last code change is the
dashboard hold fix `8fda5a2` (pointer capture on both hold buttons, reserved
status height), confirmed on hardware on 04/09/2026 with the unchanged Pi
bundle `a8bed50`. No bundle member has changed since that bundle was certified,
so no Pi transfer is needed. The workstation preflight
(`tools/real_fcu_full_stack_workstation.sh check`) last passed on the evening
of 03/09/2026; the dashboard suite passed at `113` after the hold fix, but the
full check has not been rerun on the current tree.

The flight controller carries the temporary `RC_OVERRIDE_TIME=0.5`, an
operator-confirmed carry from 04/09/2026, not a readback. The Pi's Hailo driver
was rebuilt for `6.8.0-1064-raspi` on 04/09/2026; the kernel-headers
meta-package is still not installed, so a further kernel update would remove
the driver again until the runbook's section 2 repair is repeated.

The internship ends on 10/09/2026, three working days after today. The
internship report covers the record through 04/09/2026 at its revision
`c99dddd`; its 07/09 Overleaf build measured `41` arabic body pages and
chapters 1 and 3 at `4` pages each.

## Task 1 - the demonstration video, same scope as 04/09

Hardware authority is the operator's: fresh physical declarations and a fresh
T3a approval at the Pi prompt, the fourteen flag values typed by the operator.
Nothing from 04/09 carries forward.

What the video is meant to show, all of it proven on 03/09 or 04/09/2026:

- Hailo live detection on the Pi window and on the workstation dashboard;
- dashboard demand reaching the fitted propellers with the VRX twin following
  and reporting back (`streams=4`);
- auto-move by mouse hold, the path repaired on 04/09, and by keyboard hold;
- the advisory person alert warning without stopping;
- Herelink arm and disarm reflected live on the dashboard;
- the ordered stop ending with the Pi receiving the workstation marker unaided.

Not in scope: a person-triggered stop (advisory mode was the operator's
choice), on-water work, autonomous navigation, ESC threshold calibration.

Order of the day:

1. Workstation preflight on the committed tree, since code changed after the
   last full check:

   ```bash
   cd ~/seal_ws/src/uvautoboat && bash tools/real_fcu_full_stack_workstation.sh check
   ```

   Expect `FULL_STACK_CHECK=PASS`.
2. Pi pins as in the runbook section 2: the Hailo checkout on
   `891ce701c2ebe239a5d277759eb75a30f76678a9` and clean, then the driver check
   (`/dev/hailo0` present, `dkms status` naming the running kernel). If the
   node is missing, the section 2 repair applies before anything else.
3. Live readback of `RC_OVERRIDE_TIME` before the stack starts, while the
   serial port is free. This is the operator's MAVProxy step, as on 28/08/2026
   ("Rollback and safe closeout" in that diary): read the value, retain the
   transcript. Expected `0.5`. The T3a guard snapshot is the hash-pinned
   01/09 read and does not prove the live value.
4. The run itself from the runbook sections 3 to 5: workstation `run-t3a`
   with `REAL_FCU_HAILO_PERSON_STOP=1 REAL_FCU_PERSON_ALERT_ADVISORY=1`, the
   Pi command in `~/uvautoboat_real_fcu_bundle_20260903_a8bed50` with
   `REAL_FCU_HAILO_LOCAL_DISPLAY=1` started at the `HAILO MODE` hint, the bench
   URL from `w1.log`, camera view clear until `REAL_FCU_T3A_READY=PASS`.
   Auto-move inside the armed window; stop order E-stop first, disarm, safe
   state, workstation Ctrl+C, Pi Ctrl+C and closeout token, Enter only after
   the Pi prints `waiting for workstation operator stop before bridge shutdown`.
5. Recording: a screen recording of the dashboard on the workstation and a
   camera on the boat and the Pi window, retained under
   `~/Desktop/test_logs_folder/` next to the run stamps, with the Pi run
   directory copied back as on 04/09.
6. After the session completes or is abandoned: restore `RC_OVERRIDE_TIME` to
   `3.0`, read it back, fetch the full parameter set and retain the hashed
   snapshot, exactly the 28/08/2026 procedure, unless the operator records a
   new explicit decision. Until that entry exists, `0.5` remains live.

Proof to record: the READY markers, the capture verdict line (the two
calibration reasons are expected), `REAL_FCU_WORKSTATION_STOP=PASS
marker=received`, `REAL_FCU_PI_EXIT status=0 cleanup_rc=0`,
`FULL_STACK_EXIT status=0 stop=clean`, the readback values before and after,
and the recording paths.

## Task 2 - decisions still open, operator's call

- **Fix C**: the `t3a` capture requires `--esc-threshold-calibration` and fails
  its verdict on the two calibration reasons. Decoupling is a verdict-semantics
  change in `tools/real_fcu_command_feedback_capture.py` with its own tests; a
  day's work if wanted before the end.
- **Pi kernel-headers meta-package**: the lifecycle guide section 4 has the
  simulate-then-install steps, `NOT RUN` on the project Pi. Installing it is a
  Pi system change and the operator's decision.
- **Kill recipes** in `USER_MANUAL.md` and the one-click launcher still use
  broad `pkill -9 -f` patterns that the wiki now advises against; the launcher
  part is a code change.

## Task 3 - handover, 08/09 to 10/09/2026

- Report: set `\ReportDate` to the submission date in place of `\today`,
  settle the page-count reading with the supervisor, final build.
- Repository: `Board.md` Next Priorities and the runbook are current; the
  lifecycle guide is indexed; this diary closes the record when the day is
  written up. Open items stay listed, not resolved by wording.

## Carried open items

- Fresh-boot UART probe: `stty -F /dev/ttyAMA0 57600 raw` before `cat`, or a
  counter pair while a process holds the port. Untested.
- Pi clock read `Aug 27` at boot on 03/09; NTP correction not verified.
- GPS has no fix indoors; self-navigation needs sky.
- `legacy/misc/PORT_ALLOCATION.md:54` MD040, flagged 02/09.
