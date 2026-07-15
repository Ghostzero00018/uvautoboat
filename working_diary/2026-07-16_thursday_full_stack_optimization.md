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
