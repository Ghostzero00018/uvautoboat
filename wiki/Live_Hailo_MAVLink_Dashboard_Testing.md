# Live Hailo and MAVROS Dashboard Testing

This runbook uses two foreground commands for the live, view-only dashboard demo. The
workstation supervisor starts rosbridge, `web_video_server`, and the dashboard, then
prints the complete Pi command. The Pi helper owns MAVProxy, MAVROS, Hailo, and the
D435I.

The image and telemetry paths are separate:

- `web_video_server` subscribes to `/hailo/overlay/image_raw` and serves MJPEG to the
  browser;
- rosbridge carries the five direct MAVROS subscriptions used by the temporary state,
  GPS, IMU, battery, and RC panel.

The expanded camera viewer is accepted only while `LIVE_MAVLINK_VIEW_ONLY=true`. Its
full-screen overlay and focus trap cover the current E-Stop button and shortcuts. Do not
reuse it in a write-enabled build until an operational E-Stop remains reachable by
pointer or keyboard without closing the viewer.

Do not use `one_click_launch_all/launch_autoboat_complete.sh` for this test. It starts
Gazebo and navigation nodes. Do not deploy or run the workstation preflight on the Pi;
the retained `pi` wrapper mode is not part of this procedure.

## Current tracked revisions

The repository copies below identify the uncommitted pre-trim revision used on
23/07/2026. Only the tracked Pi helper was copied from the repository; the partial
measurement also used separately checksum-pinned, untracked P0, phase-runner, and
`xwininfo` checkpoint helpers on the Pi Desktop. This revision is retained for
traceability, is not approved for another Pi-window experiment, and is scheduled for
trim before the next live-dashboard work.

| Item | Value |
| --- | --- |
| Helper source | `tools/pi_live_hailo_mavlink_dashboard.sh` |
| Helper Pi destination | resolved Pi Desktop: `$(xdg-user-dir DESKTOP)/pi_live_hailo_mavlink_dashboard.sh` |
| Helper size | `61,427` bytes |
| Helper SHA-256 | `3c1c9c274ed18c955669d32cd9e7d0f90a2999ec927be79bd06dfefebca53072` |
| Workstation supervisor | `tools/live_dashboard_preflight.sh` |
| Supervisor size | `28,647` bytes |
| Supervisor SHA-256 | `39406e88e182125d9c088be4f4fdece239529938009b82f3c85cb268f322a4c0` |

Historical 23/07/2026 session artifacts:

| Item | Size | SHA-256 |
| --- | ---: | --- |
| `p0_pi_window_probe.sh` | `8,089` bytes | `9bfb2da6ea8ee851942534bc0acf9b38736022625ad29312a3a953601d8183a4` |
| `run_p0_pi_window_probe.sh` | `4,093` bytes | `c80e3745f5efa4a9d404792772a7c44bd7da51a283b85cc836e3f13b1be48ce3` |
| `run_pi_live_window_phase.sh` | `4,862` bytes | `00de43ca98738f538d6ba52c92a94d207a590ec0429691c0aa4be4ad2ea76abc` |
| `p2_xwininfo_checkpoint.sh` | `10,542` bytes | `292e21dd705ae47355531e403f2bd01aa3792e5c2dbf30241696305c0e9f337e` |

These four files are not repository revisions. Their hashes are retained only to identify
the prepared and executed evidence chain. Do not transfer or execute them for another
Pi-window run.

The helper retains its finite `120`-second evidence window and uses
`LIVE_HOLD_AFTER_WINDOW=1` for the monitored demonstration hold. A transient MAVProxy
link-down line does not bypass the finite heartbeat deadline. HEFs, calibration data,
the Hailo runtime tree, and generated logs remain outside this repository.

Direct helper calls default to `HAILO_LOCAL_DISPLAY=0` and retain `--no-display`.
When local display is enabled, `HAILO_LOCAL_WINDOW_MODE` defaults to `resizable`.
The tracked supervisor defaults to `HAILO_LOCAL_DISPLAY=1` and
`HAILO_LOCAL_WINDOW_MODE=fullscreen`, and keeps the normal display path.
Window outcome tracking remains through `HAILO_LOCAL_WINDOW` markers:
`READY`, `FALLBACK_HEADLESS`, `FALLBACK_RESIZABLE`, and `EVIDENCE_UNAVAILABLE`.
The removed measurement-only selectors are not part of current runtime commands.

In fullscreen mode, the wrapper waits for the first upstream `imshow` and `waitKey` 
cycle before requesting fullscreen, then reads the image rectangle after the next GUI
cycle. Static tests cover this ordering, resizable/headless modes, marker transitions,
callback-rate behavior, request-failure suppression, and defensive read failures. An
operator-run
22/07/2026 attempt observed the frame-gated Pi-local HighGUI `"Output"` window live, but
its rendered image stopped enlarging beyond a ceiling while that Pi window continued to
grow. This is independent of the workstation browser dashboard and its camera viewer.
The only recorded post-request image rectangle was `0,0,400,300`; the wrapper sampled it
once, so the later manual-resize ceiling dimensions remain unmeasured. Pi-local image
scaling remains unmeasured and is parked by the 23/07/2026 closeout.

On 17/07/2026, two runs from the clean, pushed workstation checkout on
`IoT IMT Nord Europe` proved six-topic arrival and automatic rate measurement. Both
runs also had operator-confirmed simultaneous browser delivery. Each printed Pi command
verified the deployed helper checksum before launch. The Hailo image measured `7.40 Hz`
and `7.50 Hz`; each MAVROS topic measured approximately `1.00 Hz`. Both runs completed
their Pi source windows, but the workstation dashboard stack became unavailable
unexpectedly before the intended Pi-first stop in each run, without deliberate operator
intervention. Fail-closed cleanup passed; the cause and clean Pi-first normal shutdown
remain open.

On 22/07/2026, the Pi desktop Hailo window and workstation dashboard displayed the same
annotated stream simultaneously. The helper published at least `2,800` frames, all six
workstation topics arrived, automatic rates passed, the FCU remained connected and
disarmed, no monitored command message appeared, and the Pi thermal peak was `67.2 C`.
The Pi then stopped during the monitored hold after one successful but incomplete remote
ROS service snapshot omitted `/rosapi/topics_for_type`; the workstation rosapi process
was still running, and both cleanups passed. The helper now accepts a recovered service
within three semantic observations while still rejecting any command service immediately
and failing closed after persistent misses.

A later 22/07/2026 attempt visually reproduced simultaneous Pi and dashboard output. The
workstation log recorded an early dashboard client connection; the operator identified it
as a tab left open and reported restarting the Pi helper during recovery. The workstation
then exhausted its arrival window before sampling, and Pi source readiness followed that
failure by about `36.9 s`. The copied Pi log holds only the later helper lifecycle: it
reached readiness, then was operator-interrupted during `live-window` before
`PI_SOURCE_WINDOW=COMPLETE` with status `130`. Pi and workstation cleanup passed, but this
attempt does not accept retry/deadline timing or the normal completed-window/live-hold
Pi-first lifecycle. The image inside the independent Pi-local HighGUI `"Output"` window
scaled down and initially scaled up with that window, then stopped enlarging while the Pi
window continued to grow. The workstation browser window is not the affected surface. At
that close, a clean repeat was still required; the 23/07/2026 operator decision below
supersedes it, and no further Pi-window repeat is planned.

## 23/07/2026 Pi-window experiment closeout

The environment probe passed, but the user-run resizable Phase R was partial and did not
reach acceptance:

- Workstation evidence:
  `/home/ghostzero/live_dashboard_logs/live_dashboard_workstation_20260723_183748`.
  Runtime preflight and service readiness passed. All six expected publishers became
  discoverable at the end of the `360`-second arrival window, but less than the required
  `60` seconds remained for six sequential samples. No arrival samples, automatic rates,
  or `PI_DATA_ARRIVED=PASS` marker were produced. Workstation teardown passed after
  operator Ctrl+C; the supervisor exited `status=1`, `failed_phase=arrival`, and
  `cleanup_rc=0`.
- Pi evidence directory:
  `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260723_184112`;
  copied workstation path:
  `/home/ghostzero/live_dashboard_logs/pi_copies/live_dashboard_20260723_184112`.
  The copy contains `19` files and occupies `912K`; no remote-versus-local SHA-256
  manifest comparison was run. MAVROS reached connected/disarmed state, telemetry passed,
  and `PI_SOURCE_STACK_READY=PASS` was emitted. Supervisor snapshots reported `66 C`,
  while `thermal_peak_mc.txt` records the more precise peak `67750` mC (`67.75 C`), below
  the `80 C` abort.
- The operator visually reproduced the symptom: the rendered image stopped enlarging
  while the outer `"Output"` window continued to grow. The copied `hailo.log` contains
  `151` successful inner-rectangle samples from callback `30` through `4530`: `24`
  samples at `321x241`, then `127` samples at `640x480`. Every sample retained
  `label=awaiting-checkpoint`, and no outer-window `xwininfo` capture exists. The inner
  plateau is therefore measured, but the missing drag labels and outer geometry still
  prevent a quantitative `KEEPRATIO`-versus-real-cap verdict.
- Pi final verification exceeded `90` seconds during the battery sample. It did not emit
  `PI_SOURCE_WINDOW=COMPLETE` or enter the normal live hold. The bounded battery echo was
  killed at its deadline; the saved Hailo image, GPS, and IMU samples completed
  immediately before the stop. Pi teardown passed; the helper exited `status=1`,
  `failed_phase=live-window`, and `cleanup_rc=0`.

The workstation arrival failure and Pi final-verification timeout are separate failures.
The operator ended this feature's experiments: Phase R will not be repeated, Phase FS
will not run, and Blocks B/C will not proceed. The measurement procedure below is
historical only. The diagnostic-only code and matching runbook surface are scheduled for
trim before the next live-dashboard work.

The next live-dashboard run is held until that trim produces new tracked hashes. Do not
deploy or execute the pre-trim hashes recorded above.

## Before starting

- Workstation and Pi are on the same `IoT IMT Nord Europe` link. Internet access is not
  required; OpenStreetMap background tiles may be absent.
- Control box is powered, the FCU is disarmed, and propulsion is isolated.
- D435I and Hailo hardware are connected to the Pi.
- Pi Terminal P1 is opened from the active Pi desktop or Remmina session, has a
  nonempty `DISPLAY`, and can create an OpenCV window. Do not use an SSH-only terminal
  for this dual-output run.
- Hailo exclusively owns the D435I, MAVProxy exclusively owns the UART, and MAVROS uses
  loopback only.
- Gazebo, navigation/controller nodes, `realsense2_camera`, old MAVProxy, MAVROS, and
  earlier helper runs are stopped.
- Ports `8002`, `8080`, and `9090` are free on the workstation.
- The tracked helper is installed at its Pi destination and matches its checksum.
- Keep the dashboard browser closed until the Pi source stack and workstation arrival
  gate both pass.

Use new foreground terminals. Do not reuse a terminal already running a service. Never
wrap either live command in an external GNU `timeout`.

The finite Pi source window internally gives every ROS graph-list/info query and finite
topic sample the same absolute deadline. Graph commands and topic-echo process trees are
hard-stopped at the remaining budget; topic echoes also retain their cooperative message
wait, capped by that budget. Deadline exhaustion hands the interrupted phase to a separate
`90`-second final verification, which repeats required workstation nodes, forbidden
services and subscribers, the single Hailo publisher, all five MAVROS source identities,
fresh image and telemetry samples, connected/disarmed state, temperature, and power.
Final-verification exhaustion is fail-closed and cannot emit the source-window completion
marker. Startup discovery and the operator-controlled post-window hold retain their
existing behavior.

## Deployment preparation - helper only

This preparation is not one of the two live commands. On the Pi, verify the installed
helper before starting:

```bash
H="$(readlink -f -- "$HOME")" || exit 1
D="$(xdg-user-dir DESKTOP)" || exit 1
D="$(readlink -f -- "$D")" || exit 1
[ -n "$D" ] && [ -d "$D" ] && [ "$D" != "$H" ] || exit 1
printf '%s  %s\n' \
  '3c1c9c274ed18c955669d32cd9e7d0f90a2999ec927be79bd06dfefebca53072' \
  "$D/pi_live_hailo_mavlink_dashboard.sh" | sha256sum -c -
```

Continue when it prints `pi_live_hailo_mavlink_dashboard.sh: OK`. If it fails, transfer
only the helper from a workstation terminal:

```bash
cd ~/seal_ws/src/uvautoboat
printf '%s  %s\n' \
  '3c1c9c274ed18c955669d32cd9e7d0f90a2999ec927be79bd06dfefebca53072' \
  tools/pi_live_hailo_mavlink_dashboard.sh | sha256sum -c -

read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
: "${PI_SSH:?Pi SSH endpoint is required}"
PI_DESKTOP="$(ssh "$PI_SSH" '
  d="$(xdg-user-dir DESKTOP)" || exit 2
  d="$(readlink -f -- "$d")" || exit 2
  h="$(readlink -f -- "$HOME")" || exit 2
  [ -n "$d" ] && [ -d "$d" ] && [ "$d" != "$h" ] || exit 2
  printf "%s" "$d"
')" || exit 1
scp tools/pi_live_hailo_mavlink_dashboard.sh \
  "${PI_SSH}:${PI_DESKTOP}/"
ssh "$PI_SSH" "
  cd '$PI_DESKTOP' &&
  printf '%s  %s\n' \
    '3c1c9c274ed18c955669d32cd9e7d0f90a2999ec927be79bd06dfefebca53072' \
    pi_live_hailo_mavlink_dashboard.sh |
  sha256sum -c -
"
```

Do not copy `live_dashboard_preflight.sh` to the Pi. The Hailo runtime, generated wrapper,
and timestamped logs remain under `~/hailo_coco_overlay_2026-07-10`; only transferred
operator helpers live on the Pi Desktop.

## Live command 1 - workstation supervisor

Host: workstation. Terminal W1: new, foreground. Working directory: repository root.

```bash
cd ~/seal_ws/src/uvautoboat
tools/live_dashboard_preflight.sh run
```

The supervisor sources ROS Jazzy, sets `ROS_DOMAIN_ID=12` and
`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, rejects local conflicts, verifies the helper pin
and exact SSID, derives one Wi-Fi IPv4 address, and starts each workstation service in
its own process group with external logs. This live mode runs the runtime checks only;
it does not claim to run the development test suites.

Continue only after both markers:

```text
WORKSTATION_RUNTIME_PREFLIGHT=PASS ...
WORKSTATION_SERVICES=UP ... logs=/home/.../live_dashboard_workstation_...
```

Leave W1 running. It prints one compound Pi command carrying the current workstation
IPv4 address, selected SSID, helper checksum, `LIVE_HOLD_AFTER_WINDOW=1`, and
`HAILO_LOCAL_DISPLAY=1`. With no selector override, it carries
`HAILO_LOCAL_WINDOW_MODE=fullscreen`. The printed command resolves,
checksums, and executes the helper from the Pi Desktop while retaining
`~/hailo_coco_overlay_2026-07-10` as the runtime root.

## Live command 2 - Pi source stack

Host: Pi. Terminal P1: new, foreground. Paste the complete compound command printed by
W1, from the opening `(` through the closing `)`. Paste it as one block without editing
or rewrapping individual lines. If the Remmina clipboard cannot paste a multiline block,
transfer a separately checksum-pinned phase runner to the Pi Desktop and type its short
single-line invocation in P1; do not start the command through SSH because it must inherit
the active desktop display.

Before pasting, confirm the desktop display inherited by this terminal:

```bash
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
```

Stop if the value is empty. The helper must print
`HAILO_LOCAL_DISPLAY=ENABLED display=... window_mode=fullscreen`; it fails closed instead
of silently accepting a missing desktop session. The Hailo child first prints the
frame gate and then the request-and-measurement marker:

```text
HAILO_LOCAL_WINDOW=PENDING mode=fullscreen name=Output gate=first-imshow
HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output rect=x,y,width,height source=getWindowImageRect
```

`HAILO_LOCAL_WINDOW=READY ...` confirms that the fullscreen request returned and an image
rectangle was read. It does not by itself prove that the outer Pi window filled the display
or that the rendered image filled that window. Fullscreen acceptance also requires the
visible Pi-local result and recorded rectangle observations to show the expected scaling.

`HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE ...` means fullscreen setup failed but the
resizable window remains available. `HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS ...` means
window creation failed and the visualizer continued headless.
`HAILO_LOCAL_WINDOW=EVIDENCE_UNAVAILABLE ...` means fullscreen was requested but its
rendered image rectangle could not be measured. Any of these three markers fails the new
Pi-window acceptance; preserve the logs and do not describe the run as verified
fullscreen.

The expected negative import probe prints
`CANONICAL_STRIPPED_RCLPY=UNAVAILABLE informational rc=1` and a
`ModuleNotFoundError` traceback. It is informational only when subsequently followed,
after the provenance lines, by `HAILO_ROS_PREFLIGHT=PASS`.

Continue only after the helper reaches:

```text
MAVROS_STATE=PASS connected=true armed=false
MAVROS_TELEMETRY=PASS ...
PI_SOURCE_STACK_READY=PASS ...
```

Stop immediately on a checksum failure, missing readiness marker, `STOP:`,
`ERROR line=`, thermal abort, command-sentinel abort, or loss of connected and disarmed
MAVROS state. `CLEANUP_ERROR` or `TEARDOWN=FAIL` also makes the run a failure. GPS no-fix
is valid telemetry and is not transport loss.

A single successful but incomplete remote service-list snapshot is retried. The helper
still stops after three observations omit `/rosapi/topics_for_type`, and it rejects a
dashboard command service on the first snapshot where one appears. If the finite evidence
window closes between observations, the service check moves to the final-verification
phase instead of reporting an unobserved service loss.

## Retired Pi-window measurement procedure - historical record

Do not run Phase R or Phase FS. The commands below preserve the procedure prepared for the
partial 23/07/2026 run; they are not an active test pipeline.

This diagnostic mode was prepared to measure the Pi-local scaling question without
changing the display path. It was gated on a read-only Pi environment probe reporting
`P0_PROBE=OK` and review of its OpenCV version, GUI backend, API, display, and `xwininfo`
readings. `P0_PROBE=HOLD`, `P0_PROBE=DEGRADED`, missing `xwininfo`, zero or multiple exact
`"Output"` matches, or ambiguous geometry kept the measurement gate closed.

Host: Pi. Terminal P0: active-desktop/Remmina, one-shot. After transferring and verifying
the two P0 files above, run:

```bash
bash ~/Desktop/run_p0_pi_window_probe.sh
```

Require exactly one `P0_PROBE=OK` and `P0_RUNNER=OK`, then review the reported values.
Do not run P0 over SSH.

Use one fresh workstation/Pi lifecycle for each phase. Stop the Pi first and wait for
`TEARDOWN=PASS` before stopping W1 or starting the next phase. The commands below put new
workstation run directories under `~/live_dashboard_logs`, not on the Desktop; Pi runtime
logs remain under the Hailo demo root.

### Historical measurement phases (retired)

23/07 diagnostic matrix helpers were used for Pi-local scaling research only and are no longer
part of active daily or acceptance runbooks.

Do not run `LIVE_PI_WINDOW_DIAG` in the live workflow.
Do not run the `run_pi_live_window_phase.sh` phase helpers in active testing.
The following is kept only for traceability of the completed measurement path.

## Workstation arrival and automatic rate evidence

W1 waits for these six publishers and then samples each topic with its compatible QoS:

| Topic | Probe reliability | Depth |
| --- | --- | --- |
| `/hailo/overlay/image_raw` | reliable | `1` |
| `/mavros/state` | best effort | `10` |
| `/mavros/global_position/raw/fix` | best effort | `10` |
| `/mavros/imu/data` | best effort | `10` |
| `/mavros/battery` | best effort | `10` |
| `/mavros/rc/in` | best effort | `10` |

The default arrival deadline is `360` seconds from the printed Pi command. Each arrival
sample is `10` seconds. Continue only after:

```text
PI_DATA_ARRIVED=PASS topics=6 ...
W5_RATE_PROBES=PASS topics=6 duration_each=10s log=/home/...
```

The supervisor records offered QoS plus all six `10`-second rate probes in
`w5_live_rates.log` inside its run directory. Each probe must print `N=...` and
`mean=... Hz`. These measurements describe the current `240p@10fps` diagnostic profile;
they do not select an optimized resolution, frame rate, or transport.

The Pi may enter `PI_SOURCE_HOLD=ACTIVE` before the automatic probes finish. This is
expected. Do not stop P1 until W1 has emitted `W5_RATE_PROBES=PASS`.

## Browser acceptance

Open or hard-refresh <http://127.0.0.1:8002/> only after both:

```text
PI_SOURCE_STACK_READY=PASS
PI_DATA_ARRIVED=PASS topics=6 ...
```

Open the browser developer tools Network panel, clear its log, filter for `/stream?`,
then hard-refresh the dashboard. Select `/hailo/overlay/image_raw` in the Camera panel
and verify:

- live Hailo boxes and class labels;
- the Pi desktop window starts fullscreen and remains open with the same live Hailo boxes
  and class labels;
- all five MAVROS badges remain `Live` with independent ages below `3.0 s`;
- MAVROS state remains freshly connected and disarmed;
- GPS, IMU, battery, and RC activity reaches the view-only panel without a `Stale`
  badge or cleared values;
- GPS no-fix is displayed as telemetry state, not transport loss;
- vehicle-writing controls in the mission, configuration, tuning, and health-check
  panels are inert, while Mission History, tuning expanders, health clear/auto-scroll,
  export, and copy controls remain usable;
- dashboard command and configuration writes remain blocked;
- **Expected blocked string for mission commands**: clicking a mission action such as `HOLD` should emit
  exactly one toast/console line:
  `LIVE MAVLINK VIEW-ONLY: blocked mission command hold`
- **Expected blocked string for emergency stop**: clicking emergency stop should emit only
  `LIVE MAVLINK VIEW-ONLY: blocked dashboard emergency-stop publish` and return `false`
  immediately; the zero-thrust and latch publish strings are not reachable while view-only is true.
- exactly one Hailo `/stream?...` request is present and remains continuously active;
- image click, Enter/Space on the image, and the Enlarge button open the same viewer;
- Close receives focus, Tab stays inside the viewer, and Escape closes it and restores
  focus to the opening image or button;
- each Zoom out or Zoom in click changes the scale by exactly `0.5×` within
  `1.0×`–`4.0×`, and Reset returns to `1.0×` and the top-left scroll position;
- opening, zooming, resetting, and closing add no second `/stream?...` request. The same
  original Network row must remain active throughout the sequence.

Any `Stale` badge fails the browser check for that topic. A surviving IMU topic must not
make state, GPS, battery, or RC appear current. Do not use mission, thruster, arming,
mode, RC override, parameter, or setpoint controls during this diagnostic.

Record the browser visual result separately from the automatic rate result. Neither
implies the other.

This view-only check does not clear the viewer for a write-enabled release. Before
changing that boundary, add a separate acceptance smoke test with the viewer open: an
operational E-Stop must be reachable by pointer or keyboard without closing the viewer.

## Failure hold

A phase failure after workstation services are up records `PHASE_FAIL`, preserves the
nonzero status, and enters `FAILURE_HOLD=ACTIVE`. The supervisor keeps its children
running and does not retry, probe, or tear down automatically. Preserve both consoles,
stop the Pi first, then press `Ctrl+C` in W1 for reverse workstation teardown.

A failure before workstation services are up exits immediately. Do not restart either
stack until the current Pi and workstation cleanups have finished and their logs are
preserved.

## Normal shutdown - Pi first

Before stopping anything, require W1 to have emitted `W5_RATE_PROBES=PASS` and P1 to
have emitted:

```text
COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed
PI_SOURCE_WINDOW=COMPLETE target=120s monitored=... final_verification=... elapsed=... ...
PI_SOURCE_HOLD=ACTIVE monitored=true stop=Ctrl+C
```

Then stop in this exact order:

1. Press `Ctrl+C` once in Pi P1.
2. Wait for the Pi lifecycle markers:

   ```text
   PI_SOURCE_HOLD=STOP operator-requested
   TEARDOWN=PASS
   logs=/home/.../live_dashboard_...
   PI_SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=live-hold failed_phase=none cleanup_rc=0
   ```

3. Only after Pi `TEARDOWN=PASS`, press `Ctrl+C` once in workstation W1.
4. Wait for `WORKSTATION_TEARDOWN=PASS` and the workstation `logs=` line.
5. Close the browser.

Do not stop the workstation while the Pi remains in its monitored hold. If the Pi stops
because rosbridge, rosapi, or `web_video_server` disappeared, the shutdown order was not
a clean Pi-first operator stop even when both cleanup markers pass.

The `monitored` field covers the finite evidence window and its shared absolute query
deadline. `final_verification` covers the complete fail-closed graph, fresh image,
telemetry, connected/disarmed-state, temperature, and power checks performed before
completion, with a separate `90`-second absolute deadline. `elapsed` is their combined
wall time. Any `STOP: final verification exceeded 90s during ...` marker fails the run;
`PI_SOURCE_WINDOW=COMPLETE` must not follow it.

## Temperatures and log copy-back

Pi logs are written under
`~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_YYYYMMDD_HHMMSS`. In the returned Pi
terminal, use the exact path from the helper's `logs=` line. Each run directory now
contains `supervisor.log`, which persists the helper's display selection, phases, stop
trigger, failure reason if any, teardown verdict, and final status:

```bash
read -r -p 'Exact Pi run directory from logs=: ' RUN_DIR
: "${RUN_DIR:?Pi run directory is required}"
printf 'PI_TEMP_PEAK_MC='
cat "$RUN_DIR/thermal_peak_mc.txt"
printf 'PI_TEMP_POST_MC='
cat /sys/class/thermal/thermal_zone0/temp
test -r "$RUN_DIR/supervisor.log"
tail -n 12 "$RUN_DIR/supervisor.log"
```

`PI_TEMP_START_MC` is printed by the compound launch command. Copy every Pi run directory
back, including passes, from a new workstation terminal:

```bash
read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
read -r -p 'Run name, for example live_dashboard_YYYYMMDD_HHMMSS: ' RUN_NAME
: "${PI_SSH:?Pi SSH endpoint is required}"
: "${RUN_NAME:?Pi run name is required}"
mkdir -p ~/Desktop/test_logs_folder
scp -r "${PI_SSH}:hailo_coco_overlay_2026-07-10/logs/${RUN_NAME}" \
  ~/Desktop/test_logs_folder/
ls -la "$HOME/Desktop/test_logs_folder/$RUN_NAME"
```

The workstation run directory is already under `~/Desktop`. Retain its service logs,
arrival samples, and `w5_live_rates.log` with the matching Pi run directory and Pi
`supervisor.log`.

Report:

- simultaneous annotated Pi-window and workstation-dashboard result;
- browser visual result, camera-viewer controls, and the one-continuing-stream result;
- automatic rate result and rate-log path;
- helper checksum `OK`, connected/disarmed state, command sentinel, and source-window
  markers;
- `PI_TEMP_START_MC`, `PI_TEMP_PEAK_MC`, and `PI_TEMP_POST_MC`;
- `PI_SOURCE_HOLD=STOP operator-requested`, Pi `TEARDOWN=PASS`, and
  `PI_SUPERVISOR_EXIT status=0 ...` plus `WORKSTATION_TEARDOWN=PASS`;
- both exact run directories and the copy-back result.

This procedure proves bounded simultaneous view-only delivery only. It does not prove
full endurance, an optimized image profile, a GPS fix, custom maritime detector
accuracy, or any dashboard-to-FCU write path.

## Related pages

- [Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo)
- [RealSense Dashboard Testing](RealSense_Dashboard_Testing)
- [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test)
- [Dashboard Security](Dashboard_Security)
