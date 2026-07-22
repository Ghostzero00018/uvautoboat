# Thursday 23/07/2026 - Pi Hailo Window Scaling Follow-up

## Status

Prepared on 22/07/2026. Not started.

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

**Next step:** Start Block A with read-only saved-log and source inspection. Stop before
any live reproduction or Block B change.
