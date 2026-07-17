# Friday 17/07/2026 - Live Dashboard Two-Command Demo

## Goal

Reach **two operational commands** for the live dashboard - one workstation command,
one Pi command - and use them to run the basic demo: the Pi sends the Hailo overlay and
control-box telemetry, and the workstation browser displays both. Nothing else is
launched by hand.

This is deliberately **not** the full "only two files" consolidation, and it writes no
new supervisor from scratch. The workstation side is reached by extending the existing
`tools/live_dashboard_preflight.sh` with a `run` mode - reusing its checks and adapting
the lifecycle patterns already proven in the Pi helper. Renaming, deduplication, and
file deletion are mechanical steps that come **after** the two-command flow has actually
run. The scope is sized for a short day, and the live demo is the priority outcome, not
the consolidation.

The rate probe is automated inside the supervisor rather than gated on operator
attestation. The reason is coordination, not evidence rescue: the runbook already
permits a probe to extend into `PI_SOURCE_HOLD=ACTIVE`, so a human-gated probe would not
lose the evidence outright. Automating it removes the manual hand-off delay and
guarantees the probe belongs to the same invocation.

Browser visual acceptance stays a required human observation, recorded as independent
evidence rather than as a precondition for the probe. A run may produce valid rate
evidence while its visual acceptance fails; report the two separately and never let one
imply the other.

## Starting Context

- Certify the live repository and read the 16/07 diary plus
  `wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` before editing.
- Both hosts use `IMT Nord Europe 5G`. Recheck the current addresses; the 16/07
  values were Pi `10.100.249.131` and workstation `10.100.253.235`.
- The 5G link has not proved cross-host DDS. Same SSID and same address range are
  insufficient; keep the direct-route and ROS graph gates.
- The current helper and interim preflight are offline-verified but not
  runtime-validated. Regenerate and record every checksum after any change.
- Keep `images/LogoBase.png`.

### Division Of Proof - Do Not Duplicate

Each host proves only what it can actually observe. The Pi helper already owns its side
and needs **no change for the demo**:

| Check | Owner | Where |
| --- | --- | --- |
| Pi -> workstation route, gateway-crossing rejection | Pi helper | `pi_live_hailo_mavlink_dashboard.sh:854-856` |
| Pi SSID and interface | Pi helper | `:858-860` |
| Device owners (`fuser` on UART, camera, `/dev/hailo0`) | Pi helper | `:848-850` |
| UDP `14550` availability | Pi helper | `:851-852` |
| HEF checksum | Pi helper | `:846` |
| Pi-side visibility of `/rosbridge_websocket`, `/web_video_server`, `/rosapi` | Pi helper | `:372-380` |
| `/rosapi/topics_for_type` service | Pi helper | `:382` |

The workstation supervisor must **not** re-prove any of the above - it has neither the
Pi's address nor the Pi's viewpoint. It proves only local facts: its own SSID and IPv4,
its three services, their ports and nodes, HTTP reachability, the shared ROS graph as
seen from the workstation, and arrival of the six expected topics.

## Block A - Extend The Workstation Preflight Into A Supervisor

Block A **extends the existing workstation preflight into a foreground supervisor,
reusing its runtime checks and adapting the proven lifecycle patterns from the Pi
helper. It is not a greenfield supervisor implementation.**

Add a `run` mode to `tools/live_dashboard_preflight.sh`. Do not create a new empty file:
the two ingredients already exist and are proven.

- **Reuse in place** - `run_workstation_preflight()` (`live_dashboard_preflight.sh:121`)
  plus its port (`:87`), process-conflict (`:62`), helper-pin (`:57`), and SSID checks.
- **Adapt from the Pi helper** - the lifecycle patterns already working on the Pi side:
  `start_child` (`pi_live_hailo_mavlink_dashboard.sh:238`), `group_alive` (`:84`),
  `stop_group` (`:89`), `cleanup` (`:113`), the `CHILD_PGIDS` array (`:55`), the
  `SUPERVISOR_PGID` self-exclusion guard (`:92`), and the trap hand-off (`:118-119`).
  The self-exclusion guard prevents the supervisor from signalling its own process
  group - already solved once, so do not re-derive it.

The Pi helper stays a Pi-side supervisor and is not touched. It owns UART, MAVProxy,
MAVROS, Hailo, and the camera; the workstation's rosbridge, `web_video_server`, and HTTP
server must be managed by a local workstation process. Absent SSH remote control, the Pi
helper cannot own that half - which is exactly why the workstation needs its own
foreground supervisor.

Phases, in order:

1. **Runtime preflight** - `run` must **not** execute development-time tests, so it
   cannot call today's `run_workstation_preflight()` as-is: that function currently runs
   both shell harnesses, the full Node suite, and `node --check`
   (`live_dashboard_preflight.sh:128-132`). Split the existing function rather than
   rewriting it:
   - **static gate** - the two shell harnesses plus `node --test` / `node --check`;
   - **runtime preflight** - required commands, helper pin, SSID and IPv4, ports, and
     process conflicts;
   - the existing `workstation` mode calls both, preserving today's behaviour;
   - the new `run` calls **only** the runtime preflight, then enters the supervisor.

   The live marker must also stop claiming test execution: today's
   `W1_PREFLIGHT=PASS tests=dashboard,helper,preflight ports=...`
   (`live_dashboard_preflight.sh:145`) would be dishonest from `run`, which runs no
   tests. Emit a marker that states only what `run` actually did.
2. **Services** - start rosbridge, `web_video_server`, and the dashboard, each in its
   own process group with an external log. Verify ports, ROS nodes, and HTTP. Emit
   `WORKSTATION_SERVICES=UP`, then supervise every child for the rest of the run.
3. **Print the Pi command** - emit one copy-paste block that carries the workstation
   IPv4, the tracked helper checksum verification, `LIVE_HOLD_AFTER_WINDOW=1`, and the
   helper launch as a single operation. The hold flag is mandatory in the printed
   command: the helper defaults to `0` (`pi_live_hailo_mavlink_dashboard.sh:18`) and
   would otherwise exit at `120` s, which contradicts browser observation followed by a
   Pi-first `Ctrl+C`.
4. **Arrival gate** - block until the six expected topics are present in the graph
   **and** actually carrying messages: the Hailo overlay image topic plus the five
   MAVROS telemetry topics. Bound the wait with an explicit timeout. Emit
   `PI_DATA_ARRIVED=PASS` with elapsed time. This is a workstation-observable fact only;
   Pi-side route and node visibility stay with the helper.
5. **Automatic rate probe** - on arrival, run the six sequential QoS-compatible probes
   against the live offered QoS with a durable log. Emit
   `W5_RATE_PROBES=PASS topics=6 duration_each=10s`.
6. **Supervise** - keep watching children, ports, and nodes so the operator can open the
   browser and judge the combined view while the stack stays up.
7. **Teardown** - on `Ctrl+C`, stop dashboard, then video server, then rosbridge, and
   emit `WORKSTATION_TEARDOWN=PASS` only after groups, ports, and ROS nodes are gone.

### Failure model - hold, never abandon

A supervisor that exits while its three children keep running has abandoned lifecycle
ownership: nothing supervises them, and no honest `WORKSTATION_TEARDOWN=PASS` can be
produced afterwards. So on any phase failure after services are up:

- record the failure and the final nonzero status, but **stay running and keep
  supervising**;
- do not probe, do not retry, do not tear services down automatically;
- wait for the Pi to stop and for the operator's `Ctrl+C`, then perform the same reverse
  teardown and emit `WORKSTATION_TEARDOWN=PASS` if it genuinely succeeded;
- exit with the preserved nonzero status.

A failure before services are up exits nonzero immediately - there is nothing to own.

Never wrap the run in an external GNU `timeout`. Emit each marker exactly once, and
never print a marker for a phase that did not pass.

### Required offline tests (not deferrable)

Add these four scenarios to the **existing** `tools/test_live_dashboard_preflight.sh`.
Do not create four new test files.

That harness is a literal-contract checker plus single-function stub execution
(`test_live_dashboard_preflight.sh:20`, `extract_function` at `:23`) - it is **not** a
supervisor integration environment. So the four lifecycle cases need an explicit test
seam, or `failure-hold` will either hang the harness or start real services:

- use short-lived fake child processes and injectable commands - never ROS, network, or
  hardware;
- give every case an internal deadline so a held supervisor cannot stall the suite;
- clean up every spawned child even when an assertion fails;
- update the case count from `8` to `12` (`test_live_dashboard_preflight.sh:164`).

These are the minimum for an unattended supervisor and must land with Block A:

- marker honesty - no marker prints for a phase that did not pass; each prints once;
- child monitoring - a premature child exit is detected and reported;
- failure-hold - a failed phase holds and keeps supervising instead of exiting;
- reverse teardown - dashboard, then video server, then rosbridge; `PASS` only after
  groups, ports, and nodes are gone.

Do not use `pkill -f`.

## Block B - The Live Demo (separately approved)

The demo, run by the user, with the FCU disarmed, propulsion isolated, Hailo exclusively
owning the D435I, MAVProxy exclusively owning the UART, and MAVROS consuming loopback
only. Exactly two commands, each foreground in its own terminal:

1. **Workstation:** `tools/live_dashboard_preflight.sh run` - preflights, starts the
   services, prints the Pi command, waits for arrival, probes automatically, supervises.
   The name still says "preflight" today; it is renamed only after the demo has run.
2. **Pi:** paste the command the workstation printed - it verifies the checksum, sets
   `WORKSTATION_IP` and `LIVE_HOLD_AFTER_WINDOW=1`, and launches the helper in one
   operation.

The Pi helper is used **as-is**; no Pi-side change is in tomorrow's scope.

Open the browser only after both commands report their readiness markers, then judge the
combined overlay-plus-telemetry view - this is the demo's actual acceptance. Capture,
from the same invocation: browser behaviour, the automatic probe output and log,
`PI_TEMP_START_MC` / `PI_TEMP_PEAK_MC` and the post-teardown temperature, and both log
directories - copy the Pi log directory back even on a pass.

Stop Pi P1 first and require `PI_SOURCE_WINDOW=COMPLETE` and `TEARDOWN=PASS`; then stop
the workstation supervisor and require `WORKSTATION_TEARDOWN=PASS`.

Acceptance closes only when the Pi-side checksum match, the complete window, the
automatic rate evidence, and both teardown markers come from that same run. Report the
browser visual result separately from the rate result; neither implies the other.

No browser automation, SSH-controlled Pi launch, probe retry, automatic stream profile
choice, external GNU `timeout` wrapper, Gazebo, navigation/controller nodes, or
dashboard-to-FCU write path. Do not start a later block without explicit approval.

## Deferred - after the two-command flow has run

Not tomorrow. These are the consolidation and hardening items, all of which need the
demo to have run first:

- **Mechanical rename** - once the demo has run, rename so the filenames state what the
  files became. Run from the repository root:

  ```bash
  git mv tools/live_dashboard_preflight.sh tools/live_dashboard_workstation.sh
  git mv tools/test_live_dashboard_preflight.sh tools/test_live_dashboard_workstation.sh
  ```

  Keep the rename as its own commit so rename history survives.
- **Retire the Pi wrapper mode** - the preflight's `pi` mode is already a thin wrapper
  around `"$HELPER" --preflight-only`; drop it once the supervisor prints the Pi command
  directly.
- **Harness continuity** - keep `tools/test_pi_live_hailo_mavlink_dashboard.sh`. The
  workstation harness follows its file through the rename; never delete regression
  coverage without moving it.
- **Pi helper hardening** - only the genuinely missing items: generalized process-conflict
  rejection and a single-instance `flock`. The route, SSID, device-owner, UDP, checksum,
  and node/service gates already exist and must not be reimplemented.
- **Documentation closeout** - rewrite the runbook around the two-command flow, collapse
  the former W1-W5 sections, and regenerate every checksum and byte size.

**Next steps:** Implement Block A with its four required tests, run the offline gate,
then request approval for the Block B demo.

## Block A outcome - offline implementation complete

Block A was implemented on 17/07/2026. Block B was not started, and no live services or
hardware paths were run.

- `tools/live_dashboard_preflight.sh run` now owns the ROS Jazzy environment, performs
  only the runtime preflight, starts the three workstation services in separate process
  groups, verifies their local ports, nodes, service, and HTTP endpoints, and prints the
  single checksum-pinned Pi command with `LIVE_HOLD_AFTER_WINDOW=1`.
- Arrival first uses publisher-only graph queries, then bounded message samples for all
  six topics. The full six-topic rate probe starts only after arrival passes.
- Any post-service phase failure is preserved and enters the monitored hold without a
  retry or automatic teardown. `Ctrl+C` suppresses unfinished phase markers and hands
  off to dashboard, video-server, then rosbridge teardown.
- The existing `workstation` mode still runs the two shell harnesses, the Node suite,
  `node --check`, and the runtime preflight. Its behaviour and marker remain separate
  from the new runtime-only `run` mode.
- The four required lifecycle scenarios now run through the source-safe supervisor seam
  with short-lived fake process groups and internal deadlines. The preflight harness
  passes `12/12`; the Pi helper harness passes; the dashboard suite passes `26/26`; shell
  syntax checks and `node --check` pass.

The Pi helper was not modified and remains pinned at
`b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12`.
The workstation preflight is now `25,570` bytes with SHA-256
`f5da03ebea643f534f52ddc117c318ef76b6cb75fb4627c5cf2977bafb65852a`.
The matching runbook checksum fields were refreshed without changing its superseded
Pi-side preflight procedure.

The current supervisor and helper revisions remain offline-verified only. Before Block B,
the separately user-run preparation gate must confirm that the Pi helper at
`~/hailo_coco_overlay_2026-07-10/pi_live_hailo_mavlink_dashboard.sh` matches the pinned
helper checksum; transfer only that helper if it does not.

## Block A supervision interrupt correction

A deterministic supervisor seam reproduced a benign but evidence-breaking race: when
`Ctrl+C` interrupted a foreground local-health query, its nonzero status was recorded as
a supervision failure even though the stop request was valid. The supervision failure
branch now checks the stop request before recording a phase failure or entering the
failure hold.

The existing `12/12` harness now also requires:

- an interrupted supervision query to return the preserved status without a false phase
  failure or hold;
- the arrival failure branch to enter its bounded monitored hold exactly once;
- the production teardown verifier to reject an occupied workstation port or a remaining
  workstation ROS node before allowing `WORKSTATION_TEARDOWN=PASS`.

The full offline gate remains green: both shell harnesses pass, the dashboard suite passes
`26/26`, and shell syntax plus `node --check` pass. The corrected workstation preflight
is `25,607` bytes with SHA-256
`51e9a00a391b7c20f07f04709ffe8566c14bcd404d37f989ce31d6721e62a8a1`; this supersedes
the earlier Block A checksum above. The matching runbook fields were refreshed. The Pi
helper remains unchanged at its existing pin.

Arrival defaults remain unchanged at `120` seconds overall and `3` seconds per topic.
For the first demo, a conservative proposal is `360` seconds overall and `10` seconds per
topic: the overall window includes operator paste and Pi startup, while the longer sample
allows a nominal `1 Hz` topic to satisfy the current two-message rate-probe contract. This
proposal is not applied and is not runtime-proven. It reduces timing risk but cannot
eliminate the Hailo publisher-advertised-before-data race under the no-retry rule.

## Arrival defaults applied

The first-demo arrival proposal was approved and applied after the supervision interrupt
correction. The env-overridable workstation defaults are now:

- `LIVE_ARRIVAL_TIMEOUT_SECONDS=360` for the overall arrival deadline;
- `LIVE_ARRIVAL_SAMPLE_SECONDS=10` for each of the six sequential message samples.

The longer overall window includes operator paste and Pi startup time. The longer sample
gives a nominal `1 Hz` topic adequate margin to meet the current two-message rate-probe
contract. These defaults reduce timing risk but remain offline-verified only; they do not
remove the Hailo publisher-advertised-before-data race or change the no-retry failure
model.

The full offline gate passes with the new defaults: both shell harnesses pass, the
preflight harness remains `12/12`, the dashboard suite passes `26/26`, and shell syntax
plus `node --check` pass. The workstation preflight is now `25,608` bytes with SHA-256
`27942aa0ab10dc9bc5fb949868e3956eae8d1987c07dd0c73acf4d6fb8d5b8de`; this supersedes
the earlier checksum entries above. The matching runbook fields were refreshed. The Pi
helper remains unchanged, and neither the Pi preparation gate nor Block B was run.

## Block B first attempt and network correction

The Pi preparation gate was completed on 17/07/2026. Its installed helper initially
failed the checksum check, so only the tracked helper was transferred. The landed copy
then matched
`b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12`.

The first Block B attempt used `IMT Nord Europe 5G`. The workstation supervisor reached
`WORKSTATION_SERVICES=UP` with logs under
`/home/ghostzero/Desktop/live_dashboard_workstation_20260717_143007`. The Pi passed its
local import, provenance, HEF, and MAVProxy import gates, but stopped because the
workstation rosbridge node was not visible from the Pi. It did not reach
`PI_SOURCE_STACK_READY=PASS`. The Pi reported `TEARDOWN=PASS` with logs under
`/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260717_143102`;
that directory was copied back to
`/home/ghostzero/Desktop/test_logs_folder/live_dashboard_20260717_143102`. The
workstation was then stopped with `Ctrl+C` and reported
`WORKSTATION_TEARDOWN=PASS` after dashboard, video-server, then rosbridge teardown.

A separate cross-host ROS 2 exchange check reproduced the network distinction: DDS
traffic did not cross between the two hosts on `IMT Nord Europe 5G`, while it did cross
after both hosts joined `IoT IMT Nord Europe`. The IoT network therefore replaces the
5G network for this live demo even though it currently has no Internet access. This
closes only the network-selection diagnosis; it is not a successful live Hailo/MAVROS
dashboard run.

The workstation supervisor now defaults to the env-overridable
`LIVE_SSID=IoT IMT Nord Europe` selection and carries the selected SSID into its printed
Pi command with shell-safe quoting. The retained `pi` wrapper also passes the same value
to the helper. The Pi helper itself remains byte-identical at its existing checksum, so
no new Pi transfer is required for this correction.

The existing offline gate passes after the correction: the workstation harness remains
`12/12`, the Pi helper harness passes, the dashboard suite remains `26/26`, and shell
syntax plus `node --check` pass. The workstation preflight is now `25,678` bytes with
SHA-256
`de08299cdf1a201f23619c0d434604cadaedcef29dc5926a84d04f33560c55fc`;
the current runbook checksum fields and IoT prerequisite were refreshed. Block B remains
open until both hosts switch to `IoT IMT Nord Europe` and complete a new same-run live
attempt. Recheck both IPv4 addresses after that switch rather than reusing the 5G
addresses.
