# Wednesday 22/07/2026 - Camera Viewer Defect Follow-up

## Goal

Diagnose and fix the live camera-viewer controls without changing the single MJPEG
stream or the view-only dashboard boundary.

## Evidence carried forward

- Pushed code baseline: `98227cf`; this pre-diary is the only workspace change.
- The second 21/07/2026 live run passed fresh workstation-first startup, six-topic
  arrival, automatic rates, connected/disarmed monitoring, the bounded Pi window, and
  local workstation teardown. The copied Pi run contained 16 files, passed the bounded
  artifact check, and recorded a `67200` mC peak.
- Strict Pi-first shutdown did not pass. The Pi console reported loss of remote
  rosbridge visibility instead of `PI_SOURCE_HOLD=STOP operator-requested`; exact
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
