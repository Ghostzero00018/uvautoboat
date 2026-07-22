# Wednesday 22/07/2026 - Camera Viewer Defect Follow-up

## Goal

Diagnose and fix the live camera-viewer controls without changing the single MJPEG
stream or the view-only dashboard boundary.

## Evidence carried forward

- Code baseline: `98227cf`; the initial viewer-defect scaffold landed at `68d37b4`.
- The second 21/07/2026 live run passed six-topic arrival, automatic rates,
  connected/disarmed monitoring, the bounded Pi window, and local workstation teardown.
  The copied Pi run recorded a `67750` mC peak.
- Neither ordering gate was proven by the preserved sequence. The successful Pi runtime
  exceeded the workstation supervisor's lifetime, so both a fresh workstation-first
  startup and a strict Pi-first shutdown remain open. The Pi console reported loss of
  remote rosbridge visibility instead of `PI_SOURCE_HOLD=STOP operator-requested`; exact
  cross-host order remains unproven.
- Operator-reported viewer defect: one Zoom-in click jumped from `1.0×` to `4.0×`;
  Zoom in, Zoom out, and Reset then appeared unusable, while Close still worked.
- The normal source path initializes the viewer once. Repeated initialization is not
  guarded and could explain the jump, but the live cause is not proven. An image error
  is the current path that disables all three zoom controls.

## Tomorrow

1. **Block A - diagnose, no edits.** Check listener counts, one-click breakpoint hits,
   zoom and disabled states, image errors, and loaded script count.
2. **Block B - fix, separately approved.** Add a failing test for the confirmed cause,
   make the smallest fix, and retain one image with zero stream-URL mutation.
3. **Block C - browser acceptance, separately approved and user-run.** Verify `0.5×`
   steps, working Zoom in/out/Reset/Close, and one continuing `/stream?...` request.

If time remains, label the workstation post-run result as local-only and align the live
runbook with the bounded 21/07/2026 outcome. Leave Pi lifecycle logging and another
full-stack run for a later approved block.

## Boundaries

- No dashboard-to-FCU write path, write-enabled viewer clearance, E-Stop redesign,
  image-profile optimization, or transport change.
- No Pi command, live service, hardware run, or browser acceptance without its separate
  approval.

**Next step:** Start Block A only after explicit approval.

## Midday Scope Change - Professor Request

The camera-viewer diagnosis is paused after source inspection and the existing focused
test passed `5/5`. No browser probe or viewer change was made.

The professor's new priority is:

1. Prefer the stock-COCO Hailo overlay on both the Pi desktop and the workstation
   dashboard.
2. If that combined presentation is not viable, keep the annotated Hailo view on the
   Pi and show the unannotated D435I RGB view in the workstation dashboard.

The first option is source-feasible with one D435I capture and one Hailo inference
pipeline. The current wrapper already publishes a downscaled annotated frame on
`/hailo/overlay/image_raw` before returning the annotated frame to the upstream
visualizer. The current helper suppresses only the Pi window with `--no-display`.
Enabling the window requires a Pi desktop or Remmina terminal with a usable display
session. The combined Pi-window and workstation-dashboard result is not yet
runtime-proven.

The fallback must not start `realsense2_camera` beside the direct Hailo runner because
both would attempt to own the same D435I. If the preferred path fails, the bounded
fallback is one Hailo-owned capture: display the annotated frame on the Pi and publish
the unannotated pre-overlay RGB frame for the workstation dashboard. This fallback is
also source-feasible but is not implemented or runtime-proven.

Revised gates:

1. **Dual-output implementation - separately approved.** Add the smallest explicit
   local-display mode and focused regression coverage. Keep one camera owner, one
   inference pipeline, one ROS overlay publisher, one dashboard MJPEG request, and the
   view-only boundary.
2. **Dual-output acceptance - separately approved and user-run.** Start the Pi helper
   from the active desktop or Remmina session and verify the annotated Pi window plus
   the annotated workstation dashboard, rates, temperature, single ownership, and clean
   teardown.
3. **Raw-dashboard fallback - only if the preferred acceptance fails.** Diagnose the
   failure first, then separately approve any pre-overlay raw-frame publisher change and
   its acceptance.

**Next step:** Request approval for the dual-output implementation only. Do not start a
Pi service, live dashboard, browser acceptance, or hardware run from this note.

## Combined Scope Implementation - Static Result

The camera-viewer repair remains in the 22/07/2026 scope alongside the professor's
dual-output request. Its implementation remains evidence-gated: source inspection found
no confirmed live cause, so no viewer JavaScript, HTML, CSS, or test contract was changed.

The Pi helper now has an explicit `HAILO_LOCAL_DISPLAY` mode. Direct helper use defaults
to `0` and retains `--no-display`; mode `1` requires a nonempty `DISPLAY` and removes only
that display-suppression argument. The workstation supervisor's printed Pi command opts
into mode `1`. The existing D435I owner, Hailo inference callback, annotated ROS
publisher, dashboard image element, MJPEG URL, and view-only boundary are unchanged.

Static verification passed:

- Pi helper display, heartbeat, hold, and marker contracts;
- workstation preflight contracts, `13/13` cases;
- dashboard tests, `31/31`, including the existing camera-viewer `5/5` contract;
- shell and JavaScript syntax checks.

No Pi command, live service, hardware run, browser reload, or browser acceptance was run.
The combined Pi-window and dashboard result therefore remains runtime-pending. The
camera-viewer symptom also remains at the Block A evidence gap: its live listener count,
one-click breakpoint count, disabled state, image-error state, and loaded-script count
still need the user-run browser probe.

**Next step:** Under separate live approval, use one user-run stack session for the
dual-output acceptance and the camera-viewer Block A browser probe. If the probe confirms
a cause, stop again before the separately approved viewer test and smallest fix.

## Block A browser probe - ready sequence

Run against the live dashboard once the Hailo overlay feed is streaming, the camera viewer
is open at `1.0×`, and before any acceptance Zoom-in click. A live feed keeps
`cameraViewerImageAvailable` `true` and the zoom controls active, so the one-click breakpoint
fires. Use Chromium, Chrome, or Edge DevTools; the console utilities below are
Chromium-family only. Console only; read-only; no reload and no Camera Refresh. `app.js` is a
classic script, so `cameraViewerZoom`, `cameraViewerImageAvailable`, and
`adjustCameraViewerZoom` resolve from the console. Keep each pause brief and let the
telemetry badges recover before judging acceptance, since a held breakpoint stalls the
rosbridge and stream callbacks.

Step 1 - listener and script counts:

```js
(() => {
  const ids = ['btn-camera-zoom-out', 'btn-camera-zoom-in', 'btn-camera-zoom-reset', 'btn-camera-viewer-close'];
  const img = document.getElementById('camera-image');
  const isApp = v => /\/app\.js(?:\?|$)/.test(v);
  return {
    clicks: Object.fromEntries(ids.map(id => {
      const el = document.getElementById(id);
      return [id, el ? (getEventListeners(el).click || []).length : 'missing'];
    })),
    imageError: (getEventListeners(img).error || []).length,
    appTagCount: [...document.scripts].filter(s => isApp(s.src)).length,
    appLoadCount: performance.getEntriesByType('resource').filter(e => isApp(e.name)).length
  };
})()
```

Step 2 - state (run once before and once after the click):

```js
(() => {
  const img = document.getElementById('camera-image');
  const status = document.getElementById('camera-status');
  const ids = ['btn-camera-zoom-out', 'btn-camera-zoom-in', 'btn-camera-zoom-reset', 'btn-camera-viewer-close'];
  return {
    readout: document.getElementById('camera-zoom-level').textContent,
    runtimeZoom: cameraViewerZoom,
    imageAvailable: cameraViewerImageAvailable,
    inlineScale: img.style.getPropertyValue('--camera-viewer-scale'),
    controls: Object.fromEntries(ids.map(id => {
      const el = document.getElementById(id);
      return [id, { disabled: el.disabled, ariaDisabled: el.getAttribute('aria-disabled') }];
    })),
    image: { complete: img.complete, naturalWidth: img.naturalWidth, currentSrc: img.currentSrc },
    status: { text: status.textContent.trim(), errorClass: status.classList.contains('error') }
  };
})()
```

Step 3 - one-click breakpoint:

```text
monitorEvents(document.getElementById('camera-image'), 'error')
debug(adjustCameraViewerZoom)
// Click Zoom in exactly once. At each pause run:
//   ({ delta, cameraViewerZoom, cameraViewerImageAvailable })
// then press F8. Count the pauses.
undebug(adjustCameraViewerZoom)
unmonitorEvents(document.getElementById('camera-image'), 'error')
```

Healthy first-click readings: exactly one breakpoint pause with `delta` `0.5` and
`cameraViewerImageAvailable` `true`, one click listener per button, `appTagCount` `1`, the
readout advancing one `0.5×` step within `1.0×`-`4.0×`, and no second `/stream?...` network
row across open, zoom, reset, and close.

Evidence hierarchy for repeated invocation:

- Multiple pauses on a single Zoom-in click are decisive: `adjustCameraViewerZoom` ran more
  than once, so a handler is bound more than once.
- Listener counts above one are supporting evidence for the same conclusion.
- `appTagCount` `>= 2` proves only a second `app.js` injection attempt, not accumulated
  handlers. `app.js` declares its state with top-level `let`/`const`, so a second whole-file
  execution throws an already-declared `SyntaxError` and its body, including init, never
  re-runs. Accumulation therefore requires init to run twice within one successful
  execution, not re-injection.
- `imageError` is the count of registered `error` listeners on the image, not a count of
  image-error events.
- Disabled zoom controls with `cameraViewerImageAvailable` `false` are the image-error
  suppression path, not accumulation.

## Live-session procedural corrections

1. Verify the Pi-installed helper before W1; the workstation checksum does not prove the Pi
   copy. Run the `sha256sum -c` step in the runbook's deployment-preparation section
   against `89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a`.
2. Close every dashboard tab before W1. An open tab reconnects and recreates ROS and MJPEG
   endpoints, which correctly trips the Pi isolation gate. Reopen one tab only after
   `PI_SOURCE_STACK_READY=PASS` and `PI_DATA_ARRIVED=PASS topics=6`.
3. Run Block A before any acceptance Zoom-in click, following the ready sequence above.
4. Retain the runbook's Pi-first teardown order: wait for the W5 rate-probe and
   source-window markers, stop P1, require the Pi teardown markers, then stop W1 and copy
   the logs.

## Live-session SSH endpoint - 22/07/2026

For this session only, both machines remain on `IoT IMT Nord Europe` and the Pi SSH/SCP
endpoint is `imt-aqua-drone@10.120.2.249`. This value replaces only the interactive
`PI_SSH` prompts in the helper-transfer and log-copy phases. W1 must still derive the
workstation address dynamically and print the complete P1 launch command.

If the Pi helper checksum is not already current, run from workstation W0:

```bash
cd ~/seal_ws/src/uvautoboat
PI_SSH='imt-aqua-drone@10.120.2.249'

printf '%s  %s\n' \
  '89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a' \
  'tools/pi_live_hailo_mavlink_dashboard.sh' | sha256sum -c -

ssh "$PI_SSH" 'mkdir -p ~/hailo_coco_overlay_2026-07-10'
scp tools/pi_live_hailo_mavlink_dashboard.sh \
  "${PI_SSH}:hailo_coco_overlay_2026-07-10/"
```

Repeat the Pi-local checksum check and continue only after it prints
`pi_live_hailo_mavlink_dashboard.sh: OK`.

After Pi-first teardown, copy the exact Pi run directory from workstation W2:

```bash
PI_SSH='imt-aqua-drone@10.120.2.249'
read -r -p 'Run name from the Pi logs= path: ' RUN_NAME
: "${RUN_NAME:?Pi run name is required}"

mkdir -p ~/Desktop/test_logs_folder
scp -r "${PI_SSH}:hailo_coco_overlay_2026-07-10/logs/${RUN_NAME}" \
  ~/Desktop/test_logs_folder/

ls -la "$HOME/Desktop/test_logs_folder/$RUN_NAME"
```

Do not substitute the Pi address for `WORKSTATION_IP`; the supervisor supplies the
current workstation address to P1.

## Live-run evidence and revised priority - 22/07/2026

The dashboard camera-viewer zoom investigation is parked without a JavaScript, HTML,
CSS, or viewer-test change. The active presentation priority is now the Pi-local Hailo
window: keep the existing annotated workstation stream, make the existing Pi window
drag-resizable, and provide a fullscreen presentation mode without adding another
camera owner, inference process, ROS image publisher, MJPEG request, or media player.

The combined run used these copied evidence directories:

- workstation:
  `/home/ghostzero/Desktop/live_dashboard_workstation_20260722_144223`;
- Pi:
  `/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260722_144239`, copied
  from
  `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260722_144239`.

### Combined Hailo-window and dashboard result

The Pi GUI software path worked. `hailo.log` selected the existing Qt/XWayland path,
entered the upstream OpenCV display event loop, and continued annotated ROS publication
through `HAILO_ROS_FRAME count=18100`. The captured image sample is `bgr8`, `320x240`,
with frame ID `hailo_overlay`. No missing HighGUI, Qt, xcb, GTK, display-authentication,
codec, or media-player error appears. The final `KeyboardInterrupt` occurred inside
`cv2.waitKey(1)` during child teardown after the sustained frame sequence; it is not an
earlier display or inference failure.

This run therefore removes the remembered missing-viewer-package concern for the Hailo
window. The earlier missing `rqt_image_view` package and the older headless Pi image were
different, superseded conditions. Do not install VLC, FFmpeg, GStreamer, another ROS
viewer, or a replacement OpenCV package for the requested window improvement.

The software evidence proves that the display branch and GUI event loop operated. It
does not replace the operator's visual confirmation of the physical Pi window, nor does
it prove a future fullscreen property until that mode receives a separate live check.

### Safety, telemetry, and thermal evidence

- The final refreshed MAVROS state sample at `15:25:11` reports `connected: true`,
  `armed: false`, `guided: false`, and mode `MANUAL`.
- The safety monitor reached its ready marker and recorded no command-topic, FCU-armed,
  or FCU-disconnect abort. Neither `command_abort.txt` nor `thermal_abort.txt` exists.
- Peak Pi temperature was `70500 mC` (`70.5 C`), below the `80000 mC` abort threshold.
- The repeated GPS no-fix messages, the startup `AUTOPILOT_VERSION` fallback, and the
  MAVProxy SRTM cache decode warning were non-blocking and did not terminate the run.

### Cross-host termination chronology

Pi child cleanup received `SIGINT` at `15:25:25.331 CEST`. The workstation supervisor
remained in its normal supervision phase until it received a separate `SIGINT` at
`15:29:46.971 CEST`, about `4 min 21.6 s` later. It then stopped the dashboard,
`web_video_server`, and rosbridge in order, reported `WORKSTATION_TEARDOWN=PASS`, and
exited with status `0`, `failed_phase=none`, and `cleanup_rc=0`.

The workstation stack did not choose to abort because of a child failure, Pi publisher
loss, arrival timeout, rate failure, or dashboard application error. The signal sender
is not recorded, so the exact source of the workstation `SIGINT` remains an evidence
gap.

The copied Pi directory contains child logs but not the foreground helper transcript.
Consequently, the child `SIGINT` lines alone cannot distinguish an operator request from
a helper fail-closed exit. The missing decisive Pi markers are
`PI_SOURCE_HOLD=STOP operator-requested`, any `STOP:` or `ERROR line=` marker, and the
final `TEARDOWN=PASS` or `TEARDOWN=FAIL` line.

### Camera-viewer probe validity

The workstation browser reloaded at `15:26:18`, about `54 s` after Pi child cleanup had
already stopped the Hailo publisher. Any viewer reading collected after that reload was
not a live-feed Block A observation and cannot confirm or reject the original live-feed
zoom symptom. Leave the dashboard zoom controls unchanged and do not advance the viewer
repair gates from this run.

### Pi-window implementation boundary

The pinned upstream `toolbox.py` explicitly creates `"Output"` with
`cv2.WINDOW_AUTOSIZE`, then calls `cv2.imshow()` and `cv2.waitKey(1)`. This explains the
current fixed-size window. The narrow implementation seam is the generated ROS wrapper,
not the checksum-enforced upstream checkout: when local display is enabled, pre-create
the same `"Output"` window with `cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO` before the
upstream visualizer runs. An explicit local-window mode can then select resizable or
fullscreen startup via `cv2.WND_PROP_FULLSCREEN` without changing capture, inference,
overlay publication, or dashboard transport. Keep the proven Qt/XWayland path; do not
force native Wayland for this change.

No Pi-window code change or new live acceptance was made from this evidence review.

**Next step:** Inspect the tracked Pi and workstation shell helpers against the verified
run evidence. If a shell or generated-wrapper change is needed, stop for separate code
approval before editing it.

## Shell-helper audit - read-only result

Current focused checks remain green:

- `bash tools/test_pi_live_hailo_mavlink_dashboard.sh` - PASS;
- `bash tools/test_live_dashboard_preflight.sh` - PASS, `13/13` cases;
- Bash syntax - PASS for both helpers and both focused test scripts.

### Workstation supervisor verdict

No shutdown fix is justified in `tools/live_dashboard_preflight.sh`. Its `SIGINT` trap,
stop-request state, isolated child process groups, reverse teardown, durable
`supervisor.log`, and final status behave exactly as the real-`SIGINT` test requires.
Ignoring `SIGINT`, requiring a repeated interrupt, or treating it as a failure would
weaken the documented safe-stop path. Bash does not expose the signal sender PID to the
trap, so the existing log cannot attribute a keyboard interrupt versus another
`kill -INT` source.

The workstation helper will still need a coherence-only update after the Pi helper
changes: refresh its pinned Pi-helper checksum and make the printed Pi launch command
select the approved local-window mode. Those edits do not fix the 22/07 workstation
shutdown and must not be described as its cause.

### Pi helper verdict

Two bounded changes are justified in `tools/pi_live_hailo_mavlink_dashboard.sh`:

1. **Presentation contract.** Add a validated local-window mode and configure the
   generated wrapper to pre-create the existing `"Output"` window as resizable, with an
   optional fullscreen startup property. Preserve headless direct use, the existing
   `HAILO_LOCAL_DISPLAY` gate, one D435I owner, one Hailo process, one annotated ROS
   publisher, and the unchanged dashboard stream.
2. **Durable lifecycle evidence.** Persist the Pi helper's own timestamped lifecycle,
   stop-trigger, failure, hold-stop, teardown, and final-status markers inside each
   `RUN_DIR`. The copied child logs were healthy but could not distinguish an operator
   stop from a parent fail-closed exit because the foreground transcript was not stored.
   Do not wrap the helper externally with `tee`, which would change pipeline and signal
   semantics.

The final Hailo `KeyboardInterrupt` traceback is expected child-teardown noise after a
healthy run. Suppressing it is optional presentation cleanup, not a runtime-cause fix.

Focused regression coverage must be added first for valid, default, headless, invalid,
resizable, and fullscreen window modes; exact window-name and property ordering; and a
durable Pi lifecycle log for normal interrupt and fail-closed paths. The existing Pi
tests cover only `DISPLAY`, `--no-display`, console marker ordering, and cleanup; the
workstation durable-log test cannot cover a Pi artifact.

An approved Pi-helper edit will also require checksum and command-propagation updates in
the workstation helper and its test, plus the helper size/checksum and acceptance wording
in `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`. Keep the standalone demo's fixed-size
statement unchanged because that launcher does not use the live-dashboard wrapper.

No shell, Python, test, or configuration file was changed during this audit.

**Next step:** Request separate code approval for the Pi resizable/fullscreen mode,
durable Pi lifecycle log, focused regression tests, and required checksum/documentation
propagation. Fullscreen remains user-run and separately acceptance-gated.

## Approved helper implementation - static result

The approved work landed in two risk-ordered slices. Durable lifecycle evidence was
implemented first. Every live Pi run now creates `RUN_DIR/supervisor.log` before local
display configuration and the ROS/Hailo preflight, then persists timestamped phase,
stop-trigger, failure, hold-stop, teardown, log-path, and final-status markers. The exit
trap is armed immediately after successful log creation. Functional tests cover a real
hold-phase `SIGINT`, a fail-closed error, successful teardown, failed cleanup, exact final
status, and a single recorded stop trigger.

The generated ROS wrapper now accepts a validated `HAILO_LOCAL_WINDOW_MODE` of
`resizable` or `fullscreen`. Local-display use defaults to `resizable`; the workstation
supervisor's printed Pi command explicitly selects `fullscreen`. The wrapper pre-creates
the existing `"Output"` window with `cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO` before
the pinned upstream visualizer runs. A failed window creation switches the upstream
visualizer to headless mode. A failed fullscreen property keeps the valid resizable
window. In both injected failure tests, the original visualization callback still runs
and publishes one annotated ROS image.

The implementation preserves one D435I owner, one Hailo inference process, one annotated
ROS publisher, the existing MJPEG connection, and the view-only FCU boundary. No
dashboard JavaScript, HTML, CSS, or camera-viewer test was changed. The original zoom
defect remains parked until Block A is repeated against a live feed before teardown.

Static verification passed:

- `bash tools/test_pi_live_hailo_mavlink_dashboard.sh`;
- `bash tools/test_live_dashboard_preflight.sh` - `13/13` cases;
- Bash syntax for both helpers and both focused test scripts;
- Python compilation for the generated Hailo wrapper extracted from the helper.

Current operational pins:

- Pi helper: `52,426` bytes,
  `89ae95442989bf1e93a0efe22774a6ea17a33b0a38288ad85b141e467501e01a`;
- workstation supervisor: `27,621` bytes,
  `442fb65de288c3a0d1813b771f6e212feb9c2a0a2f112e5450db524b6af5a8a5`.

No Pi command, live service, hardware run, browser reload, fullscreen check, or resizable
window check was run after these changes. The next gate is a separate user-run live
acceptance: require the fullscreen-ready marker, visually verify the annotated Pi window
and continuing workstation stream, preserve `supervisor.log`, and use Pi-first teardown.

## Dual-output field result and third-run fixes - 22/07/2026

The second 22/07/2026 combined run used these evidence directories:

- workstation:
  `/home/ghostzero/Desktop/live_dashboard_workstation_20260722_170248`;
- Pi:
  `/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260722_170417`, copied
  from
  `/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260722_170417`.

### Runtime result

The professor's dual-output requirement is runtime-proven for the stock-COCO diagnostic:
the annotated Hailo view ran simultaneously in the Pi desktop window and the workstation
dashboard. The Pi log recorded the fullscreen selection and at least `2,800` annotated
ROS publications. The workstation passed six-topic arrival and all automatic rate
probes; the Hailo image averaged about `7.41 Hz`. The FCU remained connected and
disarmed, the five protected command topics carried zero messages, and the thermal peak
was `67.2 C`, below the `80 C` abort threshold.

The Pi supervisor later stopped automatically in `live-hold` because one successful
remote service-list snapshot omitted `/rosapi/topics_for_type`. The workstation rosapi
process was still running and its supervisor remained in normal supervision until the
operator stopped it about `37` seconds later. Pi teardown passed with `cleanup_rc=0`;
the Hailo `KeyboardInterrupt` was produced by that controlled child teardown, not by an
inference or display failure.

The Pi window itself reached fullscreen, but the operator reported that the rendered
image remained at its smaller size. The logged `320x240` dimensions belong only to the
downscaled ROS copy used by the workstation dashboard. The Pi display continues to use
the separate upstream SD annotated frame. The Qt warning shows that native Wayland was
not selected, but the exact XWayland image-rectangle behavior was not measured in this
run.

### Confirmed causes and correction

`reject_command_services()` previously failed on the first successful but incomplete
service snapshot. Its lower-level retry covered command errors only, so the live
semantic miss bypassed retry and caused the spurious hold abort.

The `target=120s elapsed=200s` marker did not prove that the timed monitor ran for
`200` seconds. After the finite monitor returned, the helper deliberately performed
fresh image, telemetry, endpoint, and disarmed-state verification before calculating
and emitting the completion marker. The extra duration therefore needs separate
accounting rather than a generic timeout around the live command.

The remaining Pi-image scaling cause is still a live-verified hypothesis. The previous
wrapper requested fullscreen before the upstream visualizer's first `imshow`; the next
run must determine whether delaying the request until the HighGUI window has completed
one `imshow` and `waitKey` cycle allows the rendered image rectangle to expand.

### Approved static fixes

The Pi helper now retries up to three semantic service snapshots. Every snapshot still
rejects a dashboard command service immediately, persistent rosapi absence remains
fail-closed, and a finite monitor deadline hands the check to the final-verification
phase instead of starting another observation after the evidence window closes. The
initial graph gate retains its longer discovery spin.

The generated wrapper still pre-creates the existing `"Output"` window as resizable.
Fullscreen mode now emits a pending marker, waits through the first upstream GUI cycle,
requests fullscreen on callback two, and reads `cv2.getWindowImageRect()` on callback
three after another GUI cycle. Only a successful rectangle read emits the new
evidence-backed fullscreen-ready marker. Window creation failure remains headless;
fullscreen-property failure remains resizable; rectangle-read failure is recorded as
unavailable. All paths continue annotated ROS publication.

The source-window marker now separates `monitored`, `final_verification`, and total
`elapsed` seconds. The dashboard JavaScript, HTML, CSS, camera-viewer tests, original
MJPEG image, ROS image resolution, Hailo capture and inference settings, and view-only
FCU boundary are unchanged.

Static verification passed:

- Pi helper lifecycle, window ordering, fallback, publication, semantic-retry, deadline,
  heartbeat, and hold contracts;
- workstation preflight contracts, `13/13` cases;
- dashboard tests, `31/31`, including the unchanged camera-viewer `5/5` contract;
- Bash syntax for both helpers and both focused test scripts;
- generated Hailo wrapper compilation and dashboard JavaScript syntax.

Current operational pins:

This snapshot is superseded for the third run; use the latest deployment-pin section
below.

- Pi helper: `54,789` bytes,
  `1d5b81e5d26a1645621a5841e65bd4035a30dd57ec5d3ffd19a9d0df56231931`;
- workstation supervisor: `27,621` bytes,
  `30aa99b9017ec5d29e0fe24e1d152084628df9df2a20e2165757715b9968adf4`.

No third Pi command, live service, hardware run, or browser reload was performed after
these fixes.

**Next step:** Under separate user-run approval, deploy the new Pi-helper checksum and
repeat the two-command session. Require semantic-retry survival or a persistent-miss
failure, the fullscreen pending and rectangle-ready markers, a visibly enlarged Pi image,
the unchanged workstation stream and rates, the new source-window timing breakdown, and
a normal Pi-first operator stop.

## Third-run deadline correction - 22/07/2026

The saved second-run evidence does not attribute the `120s` to `200s` gap to a ROS
service-list query. The deployed helper's deterministic phase order shows that the last
service phase, logged at `remaining=17s`, completed before `remaining=3s`. The last
monitor phase was command-subscriber inspection, followed by final verification. The
fresh final Hailo sample timestamp precedes the completion marker by about `46.56`
seconds, proving that final verification consumed a substantial part of the gap. The old
helper did not record its monitor-end timestamp, so the exact split is unrecoverable.

The finite live-window path now gives every ROS graph-list/info query one shared absolute
deadline. The raw three-attempt retry loop uses only the remaining budget and terminates
the entire query process group at expiry; a late successful response is discarded.
Deadline status propagates through node, service, command-subscriber, image-publisher,
and MAVROS-source checks and hands the interrupted phase to final verification. Initial
discovery and the operator-controlled hold continue with deadline `0` and retain their
previous behavior.

Final verification now has a separate `90`-second absolute deadline and repeats the
complete four-phase graph contract before accepting fresh image, GPS, IMU, battery, RC,
connected/disarmed-state, temperature, and power evidence. Deadline exhaustion is
fail-closed and cannot emit `PI_SOURCE_WINDOW=COMPLETE`. Tests cover timeout output,
slow successful responses, shared retry budget, unchanged deadline-zero behavior,
phase-one handoff, complete final graph ordering, and final exhaustion.

The fullscreen callback and exception handling, generated image resolution, dashboard
viewer, single MJPEG connection, and view-only FCU boundary are unchanged by this
correction.

Current third-run deployment pins supersede the earlier operational snapshot without
rewriting its historical checksums:

- Pi helper: `61,228` bytes,
  `1f043fcb67474f22130886cd415e338efccdf84de306f77961ff85e3b79c00a9`;
- workstation supervisor: `27,621` bytes,
  `d072f9436655e9e2737b709e6259701be50f5c8509bf8351916629cc657af085`.

Static verification passed for the Pi helper, workstation preflight `13/13`, dashboard
`31/31`, Bash syntax, and the generated wrapper's Python compilation. No third Pi
command, live service, hardware run, browser reload, or external diary change was made.

**Next step:** Under separate user-run approval, deploy the current Pi-helper checksum
and repeat the two-command session. Require fullscreen rectangle evidence and a visibly
enlarged Pi image, simultaneous workstation streaming, a source-window timing breakdown
without a deadline failure, and a normal Pi-first operator stop.

## Topic-echo hard-deadline parity - 22/07/2026

The pre-commit review found one remaining finite-window liveness gap. ROS graph commands
already had an external process-tree deadline, but the state and telemetry samples relied
only on `ros2 topic echo --timeout`. That cooperative option bounds the message wait but
cannot terminate a CLI process stuck during middleware discovery, initialization, or
shutdown.

Finite-window and final-verification topic samples now run under an external hard timeout
using the full remaining absolute budget. The inner ROS message timeout remains the lower
of its normal maximum and that remaining budget. This separation preserves an ordinary
no-message result when more phase time remains while still terminating a hung CLI process
at the absolute deadline. Startup checks and the operator-controlled hold keep deadline
`0` and do not use the external wrapper.

Focused tests now cover the exact outer and inner timeout values both above and below the
normal message-wait maximum, a real parent-and-child timeout, hard-timeout status mapping,
raw status `75` normalization with and without a deadline, unchanged deadline-zero
behavior, and direct MAVROS-source deadline propagation without a retry after exhaustion.

Current third-run deployment pins supersede the previous third-run snapshot:

- Pi helper: `61,404` bytes,
  `10bb75e453dd86cc68bd217a078f40e2b4318e324d89de35f274563955435e50`;
- workstation supervisor: `27,621` bytes,
  `39175bd46021605d9b0cca2578b347b5dcc00e3c8fd05be6fc409bb177c7065f`.

Static verification passed for the Pi helper, workstation preflight `13/13`, dashboard
`31/31`, Bash syntax, generated-wrapper compilation, and dashboard JavaScript syntax. No
third Pi command, live service, hardware run, browser reload, commit, push, or external
diary change was made.

**Next step:** Under separate user-run approval, deploy the latest Pi-helper checksum and
repeat the two-command session. Require fullscreen rectangle evidence and a visibly
enlarged Pi image, simultaneous workstation streaming, bounded source-window timing, and
a normal Pi-first operator stop.
