# Tuesday 21/07/2026 - Live Dashboard Helper Reliability And Video Zoom

## Goal

Improve the existing shell helpers around the unexpected workstation-side dashboard
termination seen on 17/07/2026, then assess a safe click-to-enlarge and zoom view for
the live Hailo detection stream. Keep the dashboard view-only and the FCU disarmed.

## Starting point

- Both 17/07 IoT runs passed six-topic arrival, rate probes, and human visual acceptance.
- The workstation dashboard stack ended before the intended Pi-first stop without
  deliberate operator intervention. The Pi failed closed, but the cause and normal
  lifecycle acceptance remain open.
- The current camera panel uses one MJPEG image and has no enlarge or zoom behaviour.

## Plan

1. Diagnose the workstation-side termination from the supervisor paths and preserved
   logs; reproduce it with short fake children before changing live behaviour.
2. Add the smallest regression test and improve the existing helper lifecycle without
   adding a new launcher, external timeout, or broad process killing.
3. Design a click-to-enlarge viewer with zoom in, zoom out, reset, and Escape close,
   reusing the same MJPEG image so it does not open a second video connection.
4. Run the existing focused static tests. Gate any live hardware or browser acceptance
   separately.

**Next step:** Start helper diagnosis after explicit approval. This scaffold does not
pre-authorize shell or dashboard code changes.
