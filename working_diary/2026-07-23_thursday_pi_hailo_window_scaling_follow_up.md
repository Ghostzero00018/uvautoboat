# Thursday 23/07/2026 - Pi Hailo Window Scaling Follow-up

## Status

Prepared on 22/07/2026. Block A, measurement enablement, static verification, and the
user-run P0 environment gate completed on 23/07/2026. One resizable Phase R run was
partial and did not reach acceptance. The operator visually reproduced the image-scaling
symptom, and the copied inner-rectangle series records a persistent `640x480` plateau.
Every sample remained unlabelled and no outer-window `xwininfo` matrix was collected, so
there is no quantitative `KEEPRATIO`-versus-real-cap verdict. The workstation and Pi
failed separate lifecycle gates, and both teardowns passed. The operator ended this
feature's experiments; Phase FS and Blocks B/C will not proceed. The diagnostic-only
revision awaits 24/07/2026 trim.

## Goal

Diagnose why the annotated image inside the independent Pi-local HighGUI `"Output"`
window launched by the Pi helper stops enlarging while its outer Pi-local window continues
to grow. This is not a workstation browser-dashboard window defect.
Preserve simultaneous workstation streaming and the existing safety boundary.

## Evidence carried forward

- Starting code baseline: pushed `b771223`, or a later synchronized documentation commit.
- Saved evidence paths:
  - Pi copy: `/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260722_192205`;
  - workstation: `/home/ghostzero/Desktop/live_dashboard_workstation_20260722_191845`.
- The final 22/07 attempt visually showed the annotated output on the Pi and dashboard at
  the same time. The workstation log records an early client connection; the operator
  identified it as a tab left open and reported restarting the Pi helper. The workstation
  arrival window expired during recovery.
- The copied Pi directory contains only the later helper lifecycle on deployed helper
  `10bb75e453dd86cc68bd217a078f40e2b4318e324d89de35f274563955435e50`. It reached
  command-sentinel, connected/disarmed, telemetry, and source-readiness gates, then was
  interrupted during `live-window` before
  `PI_SOURCE_WINDOW=COMPLETE` (`status=130`). Cleanup passed, and its recorded overall
  thermal peak was `67.75 C`. The attempt is not a clean timing or normal
  completed-window/live-hold lifecycle acceptance.
- The image inside the Pi-local `"Output"` window shrinks with a smaller Pi window and
  initially grows with a larger one, then reaches a ceiling while that Pi window continues
  growing.
- The one early post-request `getWindowImageRect` sample was `0,0,400,300`. It proves the
  request returned and the rectangle was read, not that fullscreen fill succeeded. The
  wrapper then stopped sampling, so the later manual-resize ceiling dimensions remain
  unmeasured.
- The dashboard's `320x240` ROS copy is a separate path and is not the confirmed cause of
  the Pi display ceiling.
- The camera-viewer zoom defect remains parked and is not part of this workstream.

## Plan

1. **Block A - diagnose only, no edits.** Inspect the saved Pi and workstation logs, the
   generated wrapper, the upstream visualizer's `--output-resolution sd` path, HighGUI
   window/image rectangles, aspect-ratio handling, and the Qt/XWayland backend. End with a
   confirmed cause or a precise evidence gap.
2. **Block B - separately approved fix.** Add the smallest failing test for the confirmed
   cause, then change only the display path. GUI failure must not interrupt the annotated
   ROS publisher.
3. **Block C - separately approved, user-run acceptance.** Close every dashboard tab,
   start one workstation supervisor and one Pi helper, then use one dashboard tab. Record
   small, large, and fullscreen image rectangles; require continued dual output, normal
   arrival/rates, and Pi-first teardown.

## Boundaries

- No second stream, second camera owner, second inference pipeline, or dashboard stream
  resolution change as a Pi-window workaround.
- Do not treat workstation browser sizing, the dashboard camera viewer, or MJPEG layout as
  the affected Pi-local HighGUI surface.
- No media-player or Pi package installation without a confirmed dependency gap and
  separate approval.
- No camera-viewer work, mission/thrust/E-Stop change, or FCU-write path.
- No Pi command, live service, hardware run, or code/config edit without its separate
  approval.

## Preparation closeout

The scope, evidence, gates, stop conditions, and acceptance target are recorded. No
23/07 command or edit has been run from this pre-diary.

**Next step:** The Block A read-only diagnosis follows.

## Block A - read-only diagnosis (23/07/2026)

Inspected read-only: the preserved Pi logs (`live_dashboard_20260722_192205`) and
workstation logs (`live_dashboard_workstation_20260722_191845`), the generated ROS
wrapper and its launch arguments, the upstream visualizer seam, and OpenCV's Qt HighGUI
window-scaling behaviour. No code or configuration edit, Pi command, live service, or
window reproduction was run. The saved wrapper is byte-identical to the tracked generator
heredoc.

### Confirmed findings

- The live `"Output"` window is created as `cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO`,
  which is numerically `0` because both flags are `0x0`. The wrapper's `namedWindow` runs
  before the upstream visualizer. The upstream later opens the same `"Output"` with
  `cv2.WINDOW_AUTOSIZE`, but `namedWindow` on an existing window is a no-op on the Qt
  backend (`GuiReceiver::createWindow` returns early through `icvFindWindowByName`), so the
  window keeps the wrapper's resizable, ratio-preserving flags. This matches the observed
  "now resizes" behaviour.
- OpenCV's Qt viewport has no native-size ceiling. `DefaultViewPort::draw2D` draws the
  frame into a destination rectangle the full size of the viewport, and under `KEEPRATIO`
  `DefaultViewPort::resizeEvent` grows the viewport with `QSize::scale(KeepAspectRatio)`,
  while `scaleView` floors the interactive zoom at the fit-to-viewport baseline. The image
  therefore scales above its native size as the window grows; a ceiling at roughly the
  `640x480` frame size is not expected Qt behaviour.
- `getWindowImageRect` on the Qt backend returns the rendered image-widget geometry, not
  the outer window's client rectangle: it dispatches to `cvGetWindowRect_QT` and
  `CvWindow::getWindowRect`, which return the view-widget geometry mapped to screen
  coordinates. Under `KEEPRATIO` this rectangle is the aspect-corrected image box, smaller
  than the window when the window is off-ratio.
- The Hailo bridge runs OpenCV's Qt HighGUI through the xcb (X11) plugin on XWayland under
  a GNOME/Mutter session (`DISPLAY=:0`); the `Ignoring XDG_SESSION_TYPE=wayland on Gnome`
  line is the Qt xcb plugin's own message. X11/EWMH fullscreen therefore applies:
  `setWindowProperty(WND_PROP_FULLSCREEN, WINDOW_FULLSCREEN)` calls Qt `showFullScreen()`,
  which only posts `_NET_WM_STATE_FULLSCREEN`; the compositor realises the geometry
  asynchronously through a later `ConfigureNotify`.
- The `320x240` copy is a separate path: the wrapper downscales the annotated frame to
  height `240` and publishes it to `/hailo/overlay/image_raw` for the workstation MJPEG
  stream. It is confirmed not the Pi display ceiling.

### Verdict - benign letterboxing is the leading explanation; measurement still required

The Pi display ceiling is not the `320x240` ROS copy, and it is not a native-pixel cap in
OpenCV's Qt scaling: the Qt viewport upscales past native (confirmed from source), so a
ceiling at roughly the `640x480` frame size is not a Qt limitation. The most likely
explanation for the resizable-mode ceiling is correct `KEEPRATIO` aspect-fit behaviour,
not a defect. The 4:3 SD frame fills the window until the constraining dimension is
reached, after which enlarging the window along the other axis only adds letterbox margin
while the image holds; on a proportional 4:3 drag the image would keep growing with no
ceiling.

An upstream per-frame cap is ruled out, not merely unread. The helper pins the Hailo
checkout to commit `891ce701` and verifies it at launch with `git rev-parse HEAD`, a
clean-tree check, and a `sha256` of `toolbox.py`, so the public source at that commit is
authoritative for what runs. There, `visualize()` calls
`cv2.namedWindow("Output", cv2.WINDOW_AUTOSIZE)` once and then only `cv2.imshow` and
`cv2.waitKey(1)` per frame, with no `resizeWindow`, `moveWindow`, or `setWindowProperty`.
Because the wrapper's `namedWindow` runs first and `namedWindow` on an existing window is a
no-op, the live window keeps `WINDOW_NORMAL | WINDOW_KEEPRATIO` and nothing upstream
re-pins its size.

The single fullscreen sample `rect=0,0,400,300` is OpenCV's default window size
(`resize(400, 300)` in the `CvWindow` constructor), not the `640x480` SD frame. Because
`getWindowImageRect` reports only the inner image widget, and the sample was taken about
one `imshow`/`waitKey` cycle after the asynchronous fullscreen request (requested on the
second callback, read on the third), it shows the inner widget had not yet grown. It is
uninformative about whether the outer window reached fullscreen and about whether the
content ultimately filled the screen, and it cannot separate "fullscreen ignored" from
"not yet applied".

### Source anchors

- OpenCV Qt behaviour: `modules/highgui/src/window_QT.cpp` and
  `include/opencv2/highgui.hpp` at release `4.10.0` (`CvWindow` default `resize(400, 300)`;
  `DefaultViewPort::draw2D` / `resizeEvent` / `scaleView`; `GuiReceiver::createWindow`
  early-return; `cvGetWindowRect_QT`). These facts are verified against `4.10.0` source
  only; the Pi's installed `cv2` version was not checked this session, and cross-version
  equivalence is not assumed.
- Upstream visualizer: Hailo `hailo-apps` commit `891ce701`, `core/common/toolbox.py`
  `visualize()` and `core/common/parser.py` (`sd` = `640x480`), matching the launch-time
  checkout and checksum pins in the helper.

### Open gaps

- The resizable ceiling dimensions were never measured; the resizable path does not sample
  `getWindowImageRect`, so `KEEPRATIO` letterboxing cannot be separated from any other
  constraint by the saved evidence alone.
- The drag geometry used to reach the ceiling (proportional 4:3 versus single-axis) was not
  recorded, and it decides the letterbox question.
- Whether fullscreen ever completed is unknown: the one sample was taken about one
  `imshow`/`waitKey` cycle after the async request, too early to assume the compositor
  transition had finished.
- The Pi's installed OpenCV `cv2` version and build flags were not captured.

### Next gates (nothing started)

Measurement is its own gate and precedes any code decision. A separately approved,
user-run measurement pass should sample `getWindowImageRect("Output")` and the outer window
rectangle at small, medium, and large sizes under both a proportional 4:3 drag and a
single-axis drag, re-sample the fullscreen rectangle several `waitKey` cycles after the
request, and read `getWindowProperty` for `WND_PROP_AUTOSIZE` and `WND_PROP_FULLSCREEN` at
steady state. If measurement confirms `KEEPRATIO` letterboxing, there is no defect, no
failing test, and no code change to make. A display-path change (Block B) is justified and
separately approved only if measurement shows a real cap rather than aspect-fit margin.

**Next step:** Hold at the measurement gate. No measurement pass, Block B change, or Block C
acceptance is authorised yet.

## Measurement enablement - approved and implemented (23/07/2026)

Measurement enablement was separately approved with graceful `xwininfo`, two clean
diagnostic phases, and live execution kept user-operated. This revision changes no normal
display behaviour:

- `HAILO_WINDOW_DIAG` defaults to `0` and accepts only `0|1`;
- diagnostics-off preserves the prior OpenCV calls and emitted window/frame lines exactly;
- diagnostics-on creates one per-run `window_diag_label.txt` beside `hailo.log`, samples
  the rendered image rectangle and `WND_PROP_AUTOSIZE`, `WND_PROP_FULLSCREEN`, and
  `WND_PROP_ASPECT_RATIO` every `30` callbacks in resizable mode, and labels each sample
  from that checkpoint file;
- fullscreen diagnostics reuse the existing early rectangle and add `fs+30` and `fs+90`
  read-only samples only after the fullscreen request succeeds;
- rectangle, property, label-file, invalid-label, and invalid-encoding errors report
  unavailable evidence but do not interrupt frame publication;
- the helper still owns one annotated ROS publisher and does not change `namedWindow`,
  `setWindowProperty`, `imshow`, `waitKey`, or the fullscreen request;
- the workstation supervisor now has tested `LIVE_PI_WINDOW_MODE` and
  `LIVE_PI_WINDOW_DIAG` selectors. Their defaults remain `fullscreen` and `0`;
- the printed Pi command resolves, checksums, and executes the helper from the resolved Pi
  Desktop while retaining `~/hailo_coco_overlay_2026-07-10` as the runtime/log root.

Red-green verification covered exact flag-off calls and logs, invalid flag rejection,
labelled samples at callbacks `30/60/90`, independent rectangle/property failures,
invalid UTF-8 label content, fullscreen `fs-early/fs+30/fs+90` scheduling, and suppression
after a failed fullscreen request. The focused helper and workstation-preflight suites
both pass.

Active revision:

| Item | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `66,481` bytes | `82e15bede13888fa33829ad5c16ddbcc23a3351a82996679fcc79ffb6fa9af07` |
| `tools/live_dashboard_preflight.sh` | `28,849` bytes | `86b37225ad7beeab7f29777f1d67c8287692c59ba5eaf542a9da7720d65cfd28` |

Session handover artifacts remain outside the repository and are transferred only to the
resolved Pi Desktop:

| Item | Size | SHA-256 |
| --- | ---: | --- |
| `p0_pi_window_probe.sh` | `8,089` bytes | `9bfb2da6ea8ee851942534bc0acf9b38736022625ad29312a3a953601d8183a4` |
| `run_p0_pi_window_probe.sh` | `4,093` bytes | `c80e3745f5efa4a9d404792772a7c44bd7da51a283b85cc836e3f13b1be48ce3` |
| `run_pi_live_window_phase.sh` | `4,862` bytes | `00de43ca98738f538d6ba52c92a94d207a590ec0429691c0aa4be4ad2ea76abc` |
| `p2_xwininfo_checkpoint.sh` | `10,542` bytes | `292e21dd705ae47355531e403f2bd01aa3792e5c2dbf30241696305c0e9f337e` |

Their no-live failure-injection matrices pass `23`, `18`, and `23` cases for P0, phase
launch, and P2 checkpointing respectively.

### P0 runtime result - GO for Phase R

The user ran `run_p0_pi_window_probe.sh` from the active Pi desktop/Remmina session. It
reported `P0_PROBE=OK` and `P0_RUNNER=OK`; all runner statuses were `0`. The off-Desktop
log is
`/home/imt-aqua-drone/p0_probe_20260723_183240.hh1PD7.log`.

Reviewed readings:

- active local GNOME/Wayland session with `DISPLAY=:0`, XWayland authorization, and no SSH
  context;
- `xwininfo` root access at logical `1920x1080`, depth `24`;
- HDMI-1 and HDMI-2 both mapped to `1920x1080+0+0`, so the current logical desktop is a
  mirrored `1920x1080` root rather than a side-by-side `3840x1080` space;
- GNOME text scaling `1.0`, integer scaling `0`, and no experimental Mutter scaling
  feature;
- venv OpenCV `4.10.0`, runtime `currentUIFramework(): QT`, compiled Qt `5.15.13`, and all
  required HighGUI window/rectangle/property APIs present;
- `xwininfo` is usable; absent `wmctrl` is non-blocking because it is not a permitted
  geometry provider;
- the RealSense inventory includes `/dev/video4`.

P0 started no live services, camera capture, Hailo inference, MAVROS, or FCU link. These
readings close the environment/version gate only; they do not prove window scaling.
Phase R is authorised as the next user-run live phase.

The deployed 22/07 helper checksum
`10bb75e453dd86cc68bd217a078f40e2b4318e324d89de35f274563955435e50`
remains historical evidence above and is not rewritten as the active revision.

The Pi Desktop inventory completed before enablement: it reported only the transferred
inventory helper and runner, with no old live-test log directories on that Desktop.
Generated P0, Hailo, and `xwininfo` evidence remains off-Desktop; only transferred
operator helpers use the Desktop.

**Next step at the P0 close (superseded by the EOD decision below):** Run Phase R with the
resizable/diagnostics-on selectors, the short Pi phase runner, and nine labelled
`xwininfo` checkpoints. Complete Pi-first teardown before the separate Phase FS run. Do
not start Block B without a measured real cap.

## EOD closeout - partial Phase R (23/07/2026)

Phase R was partial, not an acceptance pass.

### Workstation result

- W1-R evidence is under
  `/home/ghostzero/live_dashboard_logs/live_dashboard_workstation_20260723_183748`.
- Runtime preflight passed, rosbridge, `web_video_server`, and the dashboard reached
  service readiness, and the arrival phase began at `18:37:54`.
- At `18:43:54`, all six expected publishers were discoverable, but less than the
  required `60` seconds remained for six sequential `10`-second samples. The supervisor
  therefore reported
  `FAIL: insufficient arrival window before sampling /hailo/overlay/image_raw`.
- The Pi supervisor started about `197` seconds after workstation arrival began and
  reached `PI_SOURCE_STACK_READY=PASS` at `18:44:52`, about `58` seconds after W1-R had
  already failed. The late start and Pi startup time consumed the available arrival
  budget.
- No `arrival_*.log`, automatic rate log, or `PI_DATA_ARRIVED=PASS` marker was produced.
  Later MJPEG request lines prove only browser requests and streamer creation, not
  delivered frames.
- The operator stopped W1-R from failure hold with Ctrl+C. Workstation teardown passed;
  the supervisor exited `status=1`, `failed_phase=arrival`, and `cleanup_rc=0`.

### Pi result

- The Pi run directory was
  `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260723_184112`.
  It was later copied to
  `/home/ghostzero/live_dashboard_logs/pi_copies/live_dashboard_20260723_184112`
  (`19` files, `912K` allocated). No remote-versus-local SHA-256 manifest comparison was
  run, so this is a copied evidence directory, not a cryptographically verified mirror.
- The checksum-pinned Desktop helper started with local display, resizable mode, and
  diagnostics enabled. MAVROS reached `connected=true`, `armed=false`, all five telemetry
  samples passed, and `PI_SOURCE_STACK_READY=PASS` was emitted.
- Supervisor snapshots reported a peak of `66 C`; the one-second thermal watchdog's final
  `thermal_peak_mc.txt` records the more precise run peak `67750` mC (`67.75 C`), below
  the `80 C` abort.
- The operator visually reproduced the original symptom: the rendered image stopped
  enlarging while the outer `"Output"` window continued to grow.
- `hailo.log` contains `151` successful resizable diagnostic samples from callback `30`
  through `4530`. The first `24` samples were `321x241`; the inner rectangle reached
  `640x480` at callback `750` and remained `640x480` for the final `127` samples. All
  samples reported `autosize=0.0`, `fullscreen=0.0`, `aspect_ratio=0.0`, and
  `label=awaiting-checkpoint`; the label file retained that default value.
- No labelled P2 checkpoint or outer-window `xwininfo` capture exists. The inner series
  quantitatively confirms the `640x480` plateau, but without drag-direction labels or
  outer geometry it still cannot distinguish expected `KEEPRATIO` letterboxing from a
  real display cap.
- Hailo logged `320x240` ROS-frame markers through count `2200`; the saved
  `hailo_image.yaml` sample was still fresh about `10` seconds before the stop. The final
  Hailo `KeyboardInterrupt` occurred during supervisor teardown, not as an independent
  bridge failure.
- Final verification exceeded `90` seconds during the battery sample. The helper did not
  emit `PI_SOURCE_WINDOW=COMPLETE` or enter the normal live hold.
  `mavros_battery.yaml` contains the killed bounded topic-echo command, while the final
  image, GPS, and IMU samples completed immediately before the stop. Pi teardown passed;
  the helper exited `status=1`, `failed_phase=live-window`, and `cleanup_rc=0`.
- `COMMAND_SENTINEL=PASS` and the publisher-free safety monitor both passed. The saved
  MAVROS state is `connected=true`, `armed=false`, `mode=HOLD`. Later untimestamped
  MAVProxy lines record `Radio Failsafe Cleared` and a `Mode MANUAL` prompt; there is no
  command-abort evidence and no basis to attribute that transition to the dashboard.

The workstation arrival failure and the Pi final-verification timeout are separate
failures. Neither one establishes the cause of the Pi-local scaling symptom.

### Feature decision and handoff

The operator ended Pi-window experiments at EOD. Phase R will not be repeated, Phase FS
will not run, and no Block B display change or Block C acceptance will follow. The
scaling cause remains quantitatively unconfirmed and parked; no display fix is accepted.

The measurement-only instrumentation and selectors remain in the current uncommitted
tree and in the helper copied to the Pi Desktop. They are not approved for another
window experiment. On 24/07/2026, trim that experimental surface while preserving the
normal Pi-local display path, one annotated ROS publisher, the Pi Desktop deployment
location, and this historical record.

At closeout, `HEAD == origin/main ==
29a1bc5f9355e8df30eb933e98c9e9034c2845fb`. The seven previously modified tracked files
remain uncommitted; the 24/07/2026 pre-diary is added separately. Nothing is committed or
pushed.

**Next step:** Follow
`working_diary/2026-07-24_friday_dashboard_outbound_information_and_window_diag_trim.md`.
Start with its read-only state/source audit; do not resume Pi-window measurement.

**Rename note (added 24/07/2026):** the 24/07 file above was renamed to
`working_diary/2026-07-24_friday_window_trim_and_dashboard_motor_command_prep.md` after a
24/07 rescope (window research plus the first dashboard-to-motor command prep). Follow
that file.
