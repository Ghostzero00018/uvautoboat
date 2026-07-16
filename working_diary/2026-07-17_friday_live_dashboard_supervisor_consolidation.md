# Friday 17/07/2026 - Live Dashboard Supervisor Consolidation

## Goal

Reduce the live-dashboard handoff to two operational files: one workstation
supervisor and one Pi helper. Preserve every existing fail-closed, view-only,
thermal, disarmed-state, marker, and teardown contract. W5 remains an explicit
operator-gated measurement after browser acceptance.

## Starting Context

- Certify the live repository and read the 16/07 diary plus
  `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` before editing.
- Both hosts use `IMT Nord Europe 5G`. Recheck the current addresses; the 16/07
  values were Pi `10.100.249.131` and workstation `10.100.253.235`.
- The 5G link has not proved cross-host DDS. Same SSID and same address range are
  insufficient; keep the direct-route and ROS graph gates.
- The current helper and interim preflight are offline-verified but not
  runtime-validated. Regenerate and record every checksum after consolidation.
- Keep `images/LogoBase.png`.

## Block A - Workstation Supervisor

Replace the interim cross-host preflight with
`tools/live_dashboard_workstation.sh`:

- `run` performs W1, starts rosbridge, `web_video_server`, and the dashboard in
  separate process groups, records external logs, verifies ports/nodes/HTTP,
  and continuously monitors them;
- `rates --browser-accepted` treats the flag as explicit operator attestation
  after the Pi readiness marker and manual combined-view acceptance; without
  it, W5 fails closed;
- workstation teardown stops dashboard, video server, then rosbridge and emits
  `WORKSTATION_TEARDOWN=PASS` only after groups, ports, and ROS nodes are gone.

W5 failure preserves its log, exits nonzero, and leaves W2-W4 running for
orderly Pi-first teardown. It never retries or tears down services
automatically.

Add offline tests for real process-group cleanup, readiness denial, premature
child exit, reverse teardown order, W5 failure, and marker honesty. Do not use
`pkill -f`.

## Block B - Single Pi Helper

Make `tools/pi_live_hailo_mavlink_dashboard.sh` the only Pi operational file:

- retain external checksum verification and direct foreground execution;
- add robust device-owner error handling, explicit RealSense/MAVProxy/MAVROS
  conflict checks, and a single-instance `flock`;
- make `--preflight-only` require `WORKSTATION_IP`, run every applicable
  pre-start non-actuating gate, emit `P1_PREFLIGHT=PASS`, and exit before any
  child starts; retain heartbeat, source, image, and connected-disarmed gates
  in the normal live path;
- leave lifecycle markers, monitored hold, thermal abort, disarmed-state gate,
  and teardown ownership unchanged.

## Block C - Documentation And Offline Gate

Update the runbook, dashboard README, Friday diary, checksums, sizes, and tests.
Remove the superseded Pi copy of the workstation preflight. Run the full shell,
dashboard, syntax, and documentation checks before proposing live execution.

## Block D - Separately Approved 5G Live Gate

The user runs the hardware test with the FCU disarmed, propulsion isolated,
Hailo exclusively owning the D435I, MAVProxy exclusively owning the UART, and
MAVROS consuming loopback only. First re-prove direct routing and Pi visibility
of `/rosbridge_websocket`, `/web_video_server`, `/rosapi`, and
`/rosapi/topics_for_type`. Then capture browser behaviour, W5 output,
temperatures, and both log directories from the same live-test run. Stop Pi P1
first and require Pi `TEARDOWN=PASS`; then stop the workstation supervisor and
require `WORKSTATION_TEARDOWN=PASS`.

No browser automation, SSH-controlled Pi launch, W5 retry, automatic stream
profile choice, Gazebo, navigation/controller nodes, or dashboard-to-FCU write
path. Do not start a later block without explicit approval.
