# Thursday 16/07/2026 - Live Dashboard Full-Stack Optimization

## Starting Point

On 15/07, the user observed the live stock-COCO Hailo overlay and actual
control-box telemetry together in the dashboard. The image path and the five
direct MAVROS subscriptions work as a bounded view-only diagnostic. A complete
120-second acceptance and dashboard-to-control-box write path are not proven.

The pre-EOD baseline was `d77a8f14ca565e3b822ab958cb00a24036fac076`.
Start tomorrow from clean, synchronized `main` containing the 15/07 EOD
integration commit. The temporary dashboard implementation is tracked in:

- `web_dashboard/autoboat/app.js`
- `web_dashboard/autoboat/index.html`
- `web_dashboard/autoboat/style_merged.css`
- `web_dashboard/autoboat/test/mavlink_telemetry.test.js`

Stop on a dirty worktree, failed fetch, or ahead/diverged branch. Read the 15/07
EOD section before changing the integration.

Start from `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`. Its current external
helper snapshot is `45,676` bytes with SHA-256
`3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce`.
Re-run that exact revision and capture its final completion and teardown markers
before treating the helper itself as runtime-validated.

## Goal and Order

Overall goal: improve the reliability and robustness of the existing Pi helper
and launch, validation, logging, and teardown procedures before adding more
integration behaviour.

1. **Review and promote deliberately.** Re-run the dashboard tests and decide
   whether the hard-coded view-only MAVROS mode remains a diagnostic or becomes
   a selectable real-boat mode. Before promotion, address telemetry freshness,
   clearing stale values on disconnect, and false-success control feedback.
   Update permanent panel tables and security guidance only if that mode is
   retained.
2. **Repeat and measure the view-only stack.** Capture the full live-window and
   teardown markers, image/topic rates, temperatures, and browser behaviour.
   Choose resolution, frame rate, and transport only from that evidence.
3. **Design dashboard-to-control-box information flow.** Inventory the existing
   dashboard write surfaces and the FCU-facing MAVROS interfaces, then select
   one narrowly scoped, reversible, non-actuating information path with an
   acknowledgement, timeout, and explicit failure state.
4. **Transmit only after a separate gate.** Validate the selected path in
   simulation first. A hardware write test needs explicit approval, a disarmed
   vehicle, isolated propulsion, an abort monitor, and a confirmed non-actuating
   message. If no safe information-only interface is verified, remain
   design-only.

## Boundaries

- Do not run Gazebo or navigation/controller nodes during live hardware work.
- Hailo exclusively owns the D435I; keep `realsense2_camera` stopped.
- MAVProxy exclusively owns the UART; MAVROS consumes its loopback fanout.
- Keep the dashboard fail-closed and view-only until the write-path gate opens.
- Stock-COCO integration optimization does not reopen custom detector accuracy.

## Block 1A Review And Block 1B Diagnostic Hardening - 16/07/2026

Block 1A kept the hard-coded MAVROS mode diagnostic-only. The existing suite
reported `15/15` with `node --test test/*.test.js`; the repository has no
`package.json`, and `node --test test/` does not resolve the test directory.
The review found that the green suite did not cover topic expiry, complete
disconnect clearing, keyboard activation, or caller feedback after a blocked
write.

The bounded hardening change preserves `LIVE_MAVLINK_VIEW_ONLY = true` and adds:

- independent browser-receipt timestamps for state, GPS, IMU, battery, and RC;
- a `3.0 s` freshness threshold that marks only the silent topic `Stale` and
  clears its owned fields;
- complete clearing of the five badges, fourteen values, and age summary when
  rosbridge disconnects;
- unavailable arming, mode, status, and manual-input values whenever a fresh
  MAVROS state sample reports the FCU disconnected;
- inert mission, configuration, tuning, and health-check panels, including
  keyboard activation, plus disabled header and footer E-stop shortcuts;
- caller-side rejection handling so blocked presets, mission actions, and the
  health check cannot display success or remain stuck in a running state;
- fail-closed GPS readiness until explicit planner evidence arrives.

Focused regression coverage now exercises independent and watchdog-driven topic
expiry, full disconnect clearing, disconnected-FCU rendering, the four inert
write panels, all nine blocked mission handlers, blocked preset feedback,
health-check rejection, and GPS-readiness fallback. The direct publish/service
source-count check remains only a syntax canary.

No browser or live-hardware validation has run against this change. A camera
frame-stall watchdog and invalidation of the separate primary GPS panel remain
outside this bounded change because their browser/source-ownership behaviour
needs live evidence. The mode has no positive write acknowledgement or timeout
contract and is not a promotion candidate. Block 2 remains separately gated;
its live commands must not be wrapped in an external `timeout` process killer.

Final static verification passes the three test files with
`node --test test/*.test.js` and all `24/24` individual tests with
`node --test --test-isolation=none test/*.test.js`. JavaScript syntax and diff
whitespace checks also pass. This does not replace the pending browser and live
hardware validation.

## Block 1B Demo-Readiness Correction - 16/07/2026

Post-verification review found that panel-root `inert` also disabled local
diagnostic controls needed for the next live window. The lockout is now scoped
to vehicle-writing controls. Mission History toggle, clear, and JSON export;
the two tuning-section expanders; health output clear and auto-scroll; and the
injected snapshot, export, and copy buttons remain interactive. The final
publish and service guards remain unchanged. This supersedes the earlier
panel-root lockout description; the four panel containers are no longer inert.

The disabled-control styling now follows the actual inert controls, so the
usable health auto-scroll checkbox no longer appears locked or ignores input.
The unused stop-service dispatch branch was removed. Regression coverage checks
the static controls, injected export/copy controls, panel containers, write
controls, and stop handler.

The freshness timer remains coupled to the hard-coded view-only initializer,
and freshness still uses wall-clock time. Those items do not block the current
diagnostic and remain outside this demo-readiness correction. The mode is still
not a promotion candidate.

Final static verification passes the three test files with
`node --test test/*.test.js` and all `26/26` individual tests with
`node --test --test-isolation=none test/*.test.js`. JavaScript syntax and diff
whitespace checks pass. No browser or live hardware run has been performed
against the corrected lockout. The prepared user-run helper command has no
external GNU `timeout`; the helper's internal 120-second source window must
finish naturally to produce the final completion and teardown markers.

## Block 2 Visual-Only Run Note - 16/07/2026

A later user-run session displayed the stock-COCO Hailo overlay and live
control-box telemetry together in the browser after the FCU link recovered
following a battery replug. The workstation services were reported running
through W4, whose documented launch serves the dashboard working directory
directly, but no W4 request record or browser-loaded asset checksum was
captured. This supersedes the earlier statements that no browser or
live-hardware run had occurred, but it remains a visual full-stack observation,
not runtime validation of the Block 1B freshness, stale-clearing, or
control-lockout behaviour.

The run did not include the separate workstation rate and temperature
measurements, and its final Pi console markers were not preserved. Therefore
the `45,676`-byte helper snapshot with SHA-256
`3c5be701f6399f207449662e2337a0c12d0814d975106e2f8f5bf194c4baf9ce`
remains not runtime-validated; `PI_SOURCE_WINDOW=COMPLETE`, `TEARDOWN=PASS`,
same-run helper provenance, and the full endurance and teardown acceptance
remain open. No dashboard-to-FCU write path was exercised.

The earlier failed invocation safely reported `TEARDOWN=PASS` after stopping
on a pre-heartbeat MAVProxy link-down message. The user attributed that
occurrence to incomplete FCU startup after a battery replug restored the link.
The helper's immediate link-down abort still bypasses its finite heartbeat
deadline and remains an external-helper defect to correct under a new checksum.
