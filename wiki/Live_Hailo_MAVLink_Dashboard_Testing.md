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

The repository copies are canonical. Only the helper is copied to the Pi for this
procedure.

| Item | Value |
| --- | --- |
| Helper source | `tools/pi_live_hailo_mavlink_dashboard.sh` |
| Helper Pi destination | `~/hailo_coco_overlay_2026-07-10/pi_live_hailo_mavlink_dashboard.sh` |
| Helper size | `52,426` bytes |
| Helper SHA-256 | `89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a` |
| Workstation supervisor | `tools/live_dashboard_preflight.sh` |
| Supervisor size | `27,621` bytes |
| Supervisor SHA-256 | `442fb65de288c3a0d1813b771f6e212feb9c2a0a2f112e5450db524b6af5a8a5` |

The helper retains its finite `120`-second evidence window and uses
`LIVE_HOLD_AFTER_WINDOW=1` for the monitored demonstration hold. A transient MAVProxy
link-down line does not bypass the finite heartbeat deadline. HEFs, calibration data,
the Hailo runtime tree, and generated logs remain outside this repository.

Direct helper calls default to `HAILO_LOCAL_DISPLAY=0` and retain `--no-display`.
When local display is enabled, `HAILO_LOCAL_WINDOW_MODE` defaults to `resizable`.
The tracked supervisor explicitly selects `HAILO_LOCAL_DISPLAY=1` and
`HAILO_LOCAL_WINDOW_MODE=fullscreen`, enabling the Pi desktop Hailo window while
retaining the same annotated ROS publisher for the workstation dashboard. Static tests
cover resizable, fullscreen, headless, and both defensive fallback paths. The new
window modes still require live acceptance.

On 17/07/2026, two runs from the clean, pushed workstation checkout on
`IoT IMT Nord Europe` proved six-topic arrival and automatic rate measurement. Both
runs also had operator-confirmed simultaneous browser delivery. Each printed Pi command
verified the deployed helper checksum before launch. The Hailo image measured `7.40 Hz`
and `7.50 Hz`; each MAVROS topic measured approximately `1.00 Hz`. Both runs completed
their Pi source windows, but the workstation dashboard stack became unavailable
unexpectedly before the intended Pi-first stop in each run, without deliberate operator
intervention. Fail-closed cleanup passed; the cause and clean Pi-first normal shutdown
remain open.

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

## Deployment preparation - helper only

This preparation is not one of the two live commands. On the Pi, verify the installed
helper before starting:

```bash
cd ~/hailo_coco_overlay_2026-07-10
printf '%s  %s\n' \
  '89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a' \
  'pi_live_hailo_mavlink_dashboard.sh' | sha256sum -c -
```

Continue when it prints `pi_live_hailo_mavlink_dashboard.sh: OK`. If it fails, transfer
only the helper from a workstation terminal:

```bash
cd ~/seal_ws/src/uvautoboat
echo '89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a  tools/pi_live_hailo_mavlink_dashboard.sh' \
  | sha256sum -c -

read -r -p 'Current Pi SSH endpoint (user@host): ' PI_SSH
: "${PI_SSH:?Pi SSH endpoint is required}"
ssh "$PI_SSH" 'mkdir -p ~/hailo_coco_overlay_2026-07-10'
scp tools/pi_live_hailo_mavlink_dashboard.sh \
  "${PI_SSH}:hailo_coco_overlay_2026-07-10/"
```

Repeat the Pi checksum check after any transfer. Do not copy
`live_dashboard_preflight.sh` to the Pi.

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
`HAILO_LOCAL_DISPLAY=1 HAILO_LOCAL_WINDOW_MODE=fullscreen`.

## Live command 2 - Pi source stack

Host: Pi. Terminal P1: new, foreground. Paste the complete compound command printed by
W1, from the opening `(` through the closing `)`. Paste it as one block without editing
or rewrapping individual lines.

Before pasting, confirm the desktop display inherited by this terminal:

```bash
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
```

Stop if the value is empty. The helper must print
`HAILO_LOCAL_DISPLAY=ENABLED display=... window_mode=fullscreen`; it fails closed instead
of silently accepting a missing desktop session. The Hailo child must then print:

```text
HAILO_LOCAL_WINDOW=READY mode=fullscreen name=Output
```

`HAILO_LOCAL_WINDOW=FALLBACK_RESIZABLE ...` means fullscreen setup failed but the
resizable window remains available. `HAILO_LOCAL_WINDOW=FALLBACK_HEADLESS ...` means
window creation failed and the visualizer continued headless. Either fallback fails the
new Pi-window acceptance; preserve the logs and do not describe the run as fullscreen.

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
PI_SOURCE_WINDOW=COMPLETE target=120s ...
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
