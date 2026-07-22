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
   copy. Run the `sha256sum -c` step at `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md:81`
   against `7222f6779a81103af140ac8571df926d25a7ab818a02f0dbe4c921dab666b648`.
2. Close every dashboard tab before W1. An open tab reconnects and recreates ROS and MJPEG
   endpoints, which correctly trips the Pi isolation gate. Reopen one tab only after
   `PI_SOURCE_STACK_READY=PASS` and `PI_DATA_ARRIVED=PASS topics=6`.
3. Run Block A before any acceptance Zoom-in click, following the ready sequence above.
4. Retain the teardown order at `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md:255`: wait for
   the W5 rate-probe and source-window markers, stop P1, require the Pi teardown markers,
   then stop W1 and copy the logs.

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
  '7222f6779a81103af140ac8571df926d25a7ab818a02f0dbe4c921dab666b648' \
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
