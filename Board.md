# 📋 AutoBoat Development Board

[![Status](https://img.shields.io/badge/Status-Active-green)](https://github.com/Ghostzero00018/uvautoboat)
[![Progress](https://img.shields.io/badge/Progress-90%25-blue)](https://github.com/Ghostzero00018/uvautoboat)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

| | |
|---|---|
| **Project** | AutoBoat Navigation System |
| **Repository** | [Ghostzero00018/uvautoboat](https://github.com/Ghostzero00018/uvautoboat) |
| **Last Updated** | 02/09/2026 |
| **Status** | 🟢 Simulation ready (A\* path planning + one-click launcher + wiki docs + dashboard config system + MP/QGC install). First wet test completed 07/05/2026: boat survived float/manual-control bring-up, Herelink manual control works, QGC/MP MAVLink arm/disarm works. Herelink video A/B campus side verified 11/05/2026 — Linux QGC video works via the `Source = Herelink Hotspot` preset and `ffplay rtsp://<herelink-ip>:8554/fpv_stream` independently confirms the underlying LIVE555 H.264 stream; Linux MP video + arm/disarm also working after a host-local SkiaSharp 2.88.8 NuGet swap + `~/MissionPlanner/libdl.so` → `libdl.so.2` symlink (11/05/2026 late-day fix, reversible — see `wiki/Common_Issues.md` MP-Linux entry); GDAL/OGR/OSR Mono gaps from 24/04 remain (terrain / advanced geo-ref still degraded) but no longer block the video panel. Second-site (lake) retest deferred to next field session. **22/06/2026 update:** workstation on `IMT-Aquatic-drone` again reached the Herelink RTSP endpoint (`rtsp://192.168.43.1:8554/fpv_stream`, LIVE555 H.264 1920×1080@30); TCP was clean while UDP showed packet loss, but the current video source was a Pi desktop / `rqt_image_view` screen capture after starting the Pi camera node, not a direct camera feed. Treat this as transport reachability plus a current source-regression finding, not dashboard-camera integration evidence. Pi 5 MAVLink telemetry path proven 04/06/2026 (`/mavros/state connected: true` via MAVProxy → MAVROS on the reconfigured ArduPilot endpoint; GPS fix / EKF config still open). Pi 5 RealSense camera display in the workstation dashboard was proven 18/06/2026 over `IoT IMT Nord Europe` using a camera-only `424x240x15` profile; this is camera display only, not command/write validation. Local dashboard/planner → QGC visual mission bridge accepted 10-11/06/2026 (`tools/qgc_live_mission_bridge.py` over `127.0.0.1:14550`) and observed under a Herelink-hotspot mixed-topology setup 17/06/2026; visual-only — real-FCU upload, bidirectional sync, and command/write validation remain open. |

> **15/07/2026 live update:** the workstation dashboard simultaneously displayed
> the live stock-COCO Hailo overlay and read-only control-box telemetry from five
> direct MAVROS topics. The temporary diagnostic did not exercise a
> dashboard-to-FCU write path.
>
> **17/07/2026 live update:** two bounded runs on `IoT IMT Nord Europe`
> delivered all six expected topics with messages. During both runs, the
> operator confirmed the combined stock-COCO overlay and MAVLink telemetry
> view. Automatic probes measured the overlay at `7.40 Hz` and `7.50 Hz`, with
> state, raw GPS, IMU,
> battery, and RC near `1 Hz`. MAVROS stayed connected and disarmed, and the
> command sentinel observed zero messages on its five monitored command topics.
> Pi thermal peaks were `68.3 C` and `67.2 C`, and both Pi log directories were
> copied back. In both runs the workstation dashboard stack ended before the
> intended Pi-first stop, and fail-closed Pi and workstation teardown markers
> passed. The initiating event and cross-host causal order remain open. Normal
> Pi-first lifecycle acceptance and post-teardown temperature were obtained on
> 03/08/2026 and repeated on 04/08/2026, as recorded further down this block.
> Browser-last ordering, full endurance, optimized transport, GPS fix, and any
> FCU write remain open.
>
> **22/07/2026 live update:** the stock-COCO annotated view ran simultaneously in
> the Pi desktop window and workstation dashboard. The tracked helper now provides
> frame-gated fullscreen handling, durable lifecycle evidence, semantic discovery
> retry, and absolute finite/final ROS CLI deadlines (`b771223`). A later repeat was
> procedurally confounded by an operator-reported already-open dashboard tab and Pi-helper
> restart, so clean timing and the normal completed-window/live-hold Pi-first lifecycle
> acceptance remain open.
> The image inside the Pi-local HighGUI `"Output"` window resizes only up to a
> ceiling while that Pi window continues growing. This is independent of the
> workstation browser dashboard and moves to 23/07 diagnosis.
>
> **24/07/2026 live update:** the 23/07 Pi-window measurement instrumentation was
> trimmed from the runtime and tests and committed (`3890564`); the operational display
> path is unchanged and the operator launcher now defaults to a resizable window. Two
> full-stack runs on `IoT IMT Nord Europe` reached six-topic arrival and automatic rates;
> the first also completed the source-window / live-hold with clean Pi and workstation
> teardown, while a later re-run brought the stack up but hit an intermittent end-of-window
> final-verification timeout. That overrun is consistent with cumulative `ros2` CLI cost; no fault
> was identified, and the logs carry no per-query timing that could exclude one. The budget was
> raised `90 → 180 s` (`0306310`) as mitigation, not as a correctness fix, and that cause remains
> unresolved. Read-only motor-path confirmation found no software path to a
> real motor: `/wamv/thrusters/*` is the VRX sim topic, MAVROS is telemetry-only, and the
> Layer B bridge is an unbuilt stub. The real FCU is a `Cube Orange+` running
> `ArduRover 4.6.3` with thrusters on `SERVO3` (left) / `SERVO1` (right); the Pi-to-FCU
> serial link is receive-only — the Pi reads telemetry but cannot command the FCU
> (Herelink commands work) — so the dashboard-to-motor path is blocked at the link. The
> motor / outbound-write track is parked pending that link and a separate bench-safe
> arming decision.
>
> **25/08/2026 current-state correction:** the preceding 24/07 receive-only
> description is historical. A Pi-local arm/disarm command and returned FCU ACK
> are now proven on `/dev/ttyAMA0:57600`; the parameter-specific failure and the
> unproven workstation-originated route remain separate limitations. See the
> 25/08 supersession below.
>
> **01/08/2026 simulator-bridge update:** `tools/servo_command_bridge.py` provides a
> simulator-only `SERVO_OUTPUT_RAW`-to-VRX thrust path. A local harness held non-zero thrust
> through teardown and observed a new trailing zero on both outputs for SIGINT, SIGTERM, and
> repeated signals; configuration validation and Python syntax also passed. The current
> `1100/1500/1900` PWM starting values are provisional, not confirmed SITL defaults. The
> integrated ArduRover SITL + VRX run is **NOT RUN**. Actual servo functions and symmetric
> PWM rails, `SERVO_OUTPUT_RAW` arrival rate, and WAM-V stop/coast behaviour remain Monday
> inspection/runtime gates. The parked real-FCU motor/write boundary is unchanged.
> The bridge remains standalone and must not be invoked by or embedded in the live view-only
> `tools/pi_live_hailo_mavlink_dashboard.sh`; a separate simulator-only runner may be considered
> only after Monday's evidence is reviewed.
>
> **Carried-forward known issue (top follow-up, 04/08/2026):** two distinct 24/07 failures,
> confirmed separate. Two 03/08 live runs **confirmed the proximate mechanism**: a fresh
> `ros2 topic info --verbose --no-daemon --spin-time 2` process can return a successful but
> transiently incomplete graph snapshot. Across both runs the aggregate is 14 non-verifying readings
> over 11 source-check episodes - 12 `publisher count 0` and 2 identity-temporarily-unknown - and
> **every one returned `query_rc=0`**. Two of them progressed from `publisher count 0` to a publisher
> endpoint carrying `_NODE_NAME_UNKNOWN_` to accepted MAVROS identity, with the partially identified
> endpoints holding the same publisher GIDs as the fully identified ones. Three episodes reached and
> recovered on a third attempt, but none exhausted all three with a non-verifying result, so the
> terminal data-plane probe has never been exercised live. One second-run episode
> (`/mavros/battery`) has no durable record of its recovery, because the operator interrupt followed
> too closely; a clean `status=0` cannot discriminate there. This makes the 24/07 `184228` failure **strongly
> consistent** with a confirmed mechanism, but does not retroactively prove that its writer existed
> at that exact instant. The lower DDS, RMW, Wi-Fi and interface-level trigger is still unidentified,
> and the selected correctness fix - the batched source view behind `LIVE_MAVROS_SOURCE_BATCH`, off by
> default (`63d6e9a`, `c8a0ecd`) - was exercised live for the first time on 05/08/2026 and is
> **feasible at shipped defaults**, but the race recurred under it, so it is not a demonstrated
> fix. Separately and still unresolved, the `175832` overrun is
> consistent with the cost of the serialized daemonless queries; no fault was identified, and the
> logs carry no per-query timing that could exclude one. It was mitigated with `180 s`; the 03/08 run
> took `125 s`, corroborating that the former `90 s` budget was insufficient without isolating any
> per-query duration. The source-failure path records attempt-indexed raw query evidence and runs one
> bounded data-plane probe; the path as a whole is fail-closed while the probe itself is
> verdict-neutral, its result recorded but never consulted. See
> `working_diary/2026-08-03_monday_ros2_graph_query_hardening.md` and
> `working_diary/2026-08-04_tuesday_ros2_graph_query_single_participant_implementation.md`, and
> `working_diary/2026-08-05_wednesday_graph_query_live_comparison.md`.
>
> **Forward update (27/08/2026):** the paired-zero Test B retry reproduced the
> daemonless CLI failure at attempt three for live GPS data. The existing
> bounded six-topic `rclpy` view is therefore now default `1`; explicit `0`
> retains the legacy diagnostic path. Exact `/mavros` identity checks remain,
> and this promotion is offline-tested but not yet live-validated.
>
> **Forward update (28/08/2026):** a morning phase-freshness audit found that a
> fresh generation created while retrying a later topic could leave an
> already-checked earlier-topic block for the next phase. The consumer now
> discards entries through the recovered topic, and the regression case
> requires the next phase to start a new generation. W1 also pins source batch
> `1` and the `180 s` final-verification budget in the emitted P1 command. The
> focused suites pass; no live retry has used these bytes yet.
>
> **Forward update (28/08/2026, pre-arm arrival):** the corrected Pi helper ran
> live to `PI_SOURCE_STACK_READY=PASS` and its safe disarmed baseline, while W2
> reached four-stream READY. W1's separate all-seven publisher precheck timed
> out before starting message samples or its Pi observer, so nothing was armed
> and Test B remains not accepted. W1 now retains publisher sightings across
> polling passes, re-queries only unresolved topics, uses monotonic timing and
> names unresolved topics on timeout. The focused `25`-case suite passes; this
> workstation-only repair still needs a new live attempt.
>
> **Forward update (28/08/2026, repaired live result):** clean revision
> `6beb603` passed P1's safe baseline, the repaired W1 arrival/rate gates and W2
> four-stream READY. Retained records contain both `2200/800` and `800/2200`
> output pairs, active-side `800.0 N` thrust, neutral restoration and
> `116.751869 m` of first-to-last VRX displacement; the operator also observed
> Herelink-driven VRX motion while all three stacks were healthy. A later
> operator-reported external interruption was followed by `/dev/video4` loss,
> stale `/mavros/state`, and fail-closed W1/W2 stream exits. The copied Pi peak
> was `70500 mC`, below the `80000 mC` abort threshold, with no thermal-abort
> record. No retained connected/disarmed final state or passing lifecycle and
> adjudication exists, so functional motion is demonstrated but Test B is not
> formally accepted.
>
> **10/08/2026 lifecycle correction:** copied Pi/workstation logs disprove the
> 07/08 workstation-first explanation. The Pi's missing-rosbridge failure preceded
> its exit, rosbridge then accepted a new WebSocket client, and only afterwards did
> the workstation supervisor receive operator `SIGINT`. A Pi-local publisher-count-zero
> result 19 seconds before the fatal node miss independently matches the confirmed
> incomplete-snapshot class. The helper now retries the complete workstation-node
> set for three snapshots, records recovery and still fails closed on exhaustion.
> Stop order is judged from supervisor lifecycle timestamps, not the rosbridge
> `SIGINT` line. The helper pin changed and no corrective live run has occurred yet.
>
> **09/08/2026 policy supersession - real-controller access.** The former blanket
> rule, that any write or arming on the real flight controller is prohibited outright,
> is **superseded** by a tiered gate. The blanket wording did not distinguish
> non-modifying queries from configuration writes from actuating commands, and
> the command-ingress contract's startup guard depends on reading the real
> channel assignment and PWM rail from the connected vehicle, so an undifferentiated
> rule sat on the critical path of the very defence it was meant to support.
>
> **Each tier requires its own separate approval when proposed. Nothing below is
> authorized by this entry, and no tier is in scope for 10/08/2026.**
>
> | Tier | Scope | Binding conditions |
> | --- | --- | --- |
> | **T0a** | Powered-down inspection or repair of the `Pi TXD (GPIO14) -> Cube SERIAL1 RX` link | Controller and propulsion powered down; no parameter changed |
> | **T0b** | Non-actuating request/response over the link | Disarmed; hardware safety state confirmed ON (safe) and left unchanged; heartbeat and parameter **reads** only, including `BRD_SAFETY_DEFLT`, `BRD_SAFETY_MASK` and `BRD_SAFETYOPTION`. No `PARAM_SET`, no safety-state change, no mode change, no arming, no motor test and no RC override |
> | **T1** | Link-configuration write under a strict allowlist | Initially only `BRD_SER1_RTSCTS`, currently `Auto (2)`. Candidate `0` was tested on 21/08/2026, did not restore parameter responses and was rolled back with read-back. Any further write needs new evidence and separate approval. Propulsion power isolated |
> | **T2a** | First arm/disarm on the bench, propellers removed | Function, channel and rail confirmed live in T0b; the Block B contract implemented and passing against the simulator; **no non-neutral input sent** |
> | **T2b** | Minimal bounded input on the bench, propellers removed | Separate approval again. Short, low amplitude, asymmetric so it can actually evidence the mapping; dead-man defined; explicit neutral, disarm and power-down order |
> | **T3a** | Static test with propellers fitted | Separate approval, dedicated mechanical guarding and an exclusion zone |
> | **T3b** | On-water test | Separate day, separate plan, separate approval |
>
> **01/09/2026 T3a implementation addendum.** The source now implements T3a
> as a distinct `run-t3a` mode instead of weakening either T2 bench tier. It is
> demand-enabled with the unchanged `0.20` steering and `0.12` throttle bounds,
> and fails closed unless T0a is complete, T0b is approved, and separate T3a
> approval, disarmed start, hardware safety ON, propellers fitted, hull
> restraint, installed mechanical guarding, a clear exclusion zone and
> propulsion isolation at launch are all declared. T2/T3 approvals and
> removed/fitted-propeller declarations are mutually exclusive. After guard
> resolution, the operator enables propulsion while disarmed, safe and guarded,
> then enters an exact retained confirmation. READY requires the generic capture
> node to be visible; the separately launched T3a recorder's verdict binds the
> T3a bridge identity. Safe closeout is owed from the moment that
> enable prompt appears. Its bounded prompt precedes final-state capture and
> teardown; an exact neutral, E-Stop, external-disarm, safety-ON and
> propulsion-isolated confirmation is required to pass. Missing, invalid,
> timed-out, `INT` or `TERM` input fails closed while cleanup still captures the
> final state and stops every child. The default timeout is `300 s`. The helper does not automatically
> enable power, release safety, arm, disarm, change mode or write parameters.
> This is an offline source contract, not evidence that any physical declaration
> is true and not authorization or acceptance of a hardware run.
>
> **01/09/2026 live-runtime correction.** Published revision `507bfcf` removed
> the additional typed T3a start confirmations described above. The already
> required approved runtime flags authorize only the operator's external
> propulsion-enable and hardware-safety-release actions while the FCU is
> disarmed. The exact typed safe-closeout confirmation remains mandatory before
> final-state capture and teardown can pass.
>
> **10/08/2026 later authorization addendum.** Subsequent operator instructions
> brought the default-inhibited prototype implementation and a future
> T0b/T2a/T2b physical workflow into the day's proposed scope. That later
> instruction supersedes only the earlier “no tier is in scope” sentence; it
> does not waive any tier condition. The operator-supplied Pi transcript did not
> close T0b because it returned no parameter values or current safety state and
> showed the vehicle already armed. No T2 command was emitted by the repository.
>
> **11/08/2026 implementation update.** A guarded physical-FCU helper pair is
> prepared but not run. The workstation half owns loopback rosbridge and the
> dashboard. The Pi half owns direct MAVROS serial access, first through a
> two-plugin T0b probe and then, only behind separate T2 approvals, through a
> five-plugin telemetry/command session and the bounded bridge. It contains no
> MAVProxy/UDP fan-out, parameter write, mode change, arming, disarming or
> software safety-release command. The existing Hailo/MAVROS helper remains
> byte-identical and view-only. This preparation does not close or schedule T0a,
> T0b or either T2 tier.
>
> **12/08/2026 current limitation.** The tier policy above defines T0b as a
> standalone non-actuating read-only request/response step, but the current
> `tools/real_fcu_digital_twin_pi.sh probe` path also requires the propellers-removed,
> hull-restrained and propulsion-isolated flags used by the T2 bench tiers. T0b is
> therefore defined but cannot currently be executed independently. The
> implementation is stricter than the policy; this is a policy/operability mismatch,
> not an exposed safety weakness. The helper remains unchanged, and these gates must
> not be loosened as part of documentation maintenance.
>
> The future implementation task has a narrow existing seam. The `probe` path starts
> only the two-plugin read-only MAVROS session, captures T0b evidence, does not start
> the bridge, and records `writes=none bridge=not-started`. A separately approved code
> change must first add red contract coverage proving that: (1) standalone T0b can
> enter without the T2 mechanical-condition flags; (2) `probe` creates no bridge,
> command-demand publisher or write/actuation path; (3) `run` continues to require the
> mechanical conditions and separate T2a/T2b approvals; and (4) parameter writes,
> mode changes, arming and RC override remain fail-closed in `probe`.
>
> Two facts govern why the physical conditions carry the weight rather than the
> autopilot. First, this vehicle records **`ARMING_CHECK=0`**, so pre-arm checks
> are **not** a safety layer; `ARMING_REQUIRE=1` only means output requires
> arming, it does not screen it. The layers that do carry weight are the removed
> propellers, a restrained hull and isolated propulsion power. The Cube safety
> switch is a **conditional firmware/IOMCU guard, not a physical isolation and
> not independent of software**: `BRD_SAFETY_DEFLT=1` sets the startup default to
> the safe state; it does not prove the current safety state or independently
> isolate propulsion. The current state, `BRD_SAFETY_MASK` and `BRD_SAFETYOPTION`
> must be read before the safety mechanism can count as a guard - none of the
> three is on record anywhere in this repository today. It remains subordinate to
> propeller removal, hull restraint and propulsion-power isolation. Second, this
> platform uses
> **above-water, airboat-style propulsion** (`wiki/Roadmap.md`), so a fitted
> propeller turns unshielded at working height - which is why T3a is separated
> from the bench tiers and from on-water testing rather than folded into either.
>
> **Current position: T0a remains unscheduled.** The bidirectional-link cause is
> not yet isolated; the next hardware window must inspect TX-to-RX continuity
> before deciding whether wiring repair or a separately approved T1 configuration
> change is needed. The 24/07/2026 record names two candidates - an unconnected
> `Pi TXD (GPIO14) -> Cube SERIAL1 RX` line, or `BRD_SER1_RTSCTS=2` flow control
> on a three-wire link. Neither candidate has been eliminated. T0a inspection is
> therefore the first hardware step; its result decides whether T0a includes a
> wiring repair or closes without repair before a separately approved T1
> configuration change is considered.
>
> That no tier is currently scheduled is not a gap in this framework. Its purpose
> is to state why the real-controller path is still blocked, and in what order it
> would be unlocked once a hardware window exists.
>
> **18/08/2026 supersession - T0a closed, T0b open.** The preceding current-position
> paragraph is now historical. On 17/08/2026, powered-down connector inspection and
> end-to-end continuity both passed for
> `Pi TXD (GPIO14) -> Cube SERIAL1 RX`, closing T0a without a wiring change. On
> 18/08/2026, the four-file Pi bundle was deployed once to
> `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818`, verified against its
> manifest and accepted by `check` with
> `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The separately
> approved probe opened the serial endpoint and received an ArduPilot heartbeat,
> but the MAVROS parameter-list exchange exhausted its retries. The operator stopped
> the run at `t+109.81 s`, before its `180 s` deadline; cleanup completed with
> `status=130 cleanup_rc=0`. No T0b parameter artifact was created, no parameter was
> written, and the bridge did not start. Inbound heartbeat traffic is proven, but
> the retained evidence does not isolate runtime UART behaviour, controller serial
> configuration, protocol handling or `BRD_SER1_RTSCTS`. T0b is therefore the next
> physical gate; T1 and both T2 tiers remain closed.
>
> The operator subsequently confirmed the 18/08/2026 end-of-day physical state:
> controller/control box off, Pi off, propulsion isolated, propellers removed,
> hull restrained, hardware safety restored, and Herelink sticks and trims
> neutral. This closes the day's physical shutdown; it does not close T0b or
> authorize a later tier.
>
> **19/08/2026 supersession - evidence repaired, new deployment certified, T0b
> still open.** The two capture defects were repaired so every state attempt now
> has an isolated YAML copy and sibling diagnostic log, including diagnostics
> from the process writing both retained copies. The bundle manifest was
> regenerated only after the helper was final, and the complete physical-helper
> suite passed `24` cases. The helper, regression tests and manifest landed
> together at `dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`.
>
> A new five-file deployment at
> `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` then passed exact
> inventory, pinned-manifest and `4/4` member verification. Its non-actuating
> `check` returned
> `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`, with empty
> stderr. Block E was approved but deferred without starting because its
> probe-safety review remained pending at the end of the day. No controller or
> Herelink power-up, serial open, parameter write, bridge start or real thrust
> occurred under Block E. The unused approval does not carry into 20/08/2026:
> T0b remains the first open physical gate, and T1 plus both T2 tiers remain
> closed pending fresh certification and approval.
>
> **20/08/2026 supersession - T0b probe isolated locally, deployment pending.**
> The safety audit found that the `param` and `sys_status` plugins advertise at
> least five state-changing parameter, mode and telemetry-configuration services
> even though the helper's planned probe actions are read-only. Because the
> standalone probe never waits for workstation nodes or starts the bridge, its
> ROS discovery is now forced to `LOCALHOST`; `check`, `run-t2a` and `run` retain
> the domain-`43` subnet contract. A regression first failed against the former
> subnet behaviour, the manifest was regenerated after the repair, and the
> complete suite passed `24` cases with all four bundle members verifying. The
> corrected bytes have not been deployed, so neither existing dated deployment
> root may be used for the retry. No Pi, controller, Herelink, serial or physical
> action occurred. Block A still requires a separately approved deployment
> disposition and fresh certification; Block E remains closed.
>
> **20/08/2026 deployment update - Block A complete.** The preceding same-day
> deployment-pending status is superseded. Revision
> `f8e440a81d8f08318b089814c05329b21ddafd1c` was transferred and installed once
> in the new root
> `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820`; the 18/08 and 19/08
> roots were not deployment targets. Pi host, user, address, environment, free
> disk and process checks passed. The operator freshly attested that the
> controller and Herelink were off, propulsion was isolated, propellers were
> removed and the hull was restrained. Privileged serial-owner checks returned
> blank output with return code `1` before and after deployment. The five-member
> transport archive passed exact inventory, its four governed members verified
> `4/4`, and the deployed helper's non-actuating `check` returned
> `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started` with empty
> stderr. No serial probe, MAVROS runtime, command bridge, parameter write,
> arming, mode, RC, motor or thrust action ran. Block E remains closed pending a
> separate explicit approval; T0b remains the first open physical gate.
>
> **20/08/2026 live update - T0b executed, parameter response still blocked.**
> The preceding Block-E-closed status is superseded. Two early runs retained
> clean disconnected/disarmed failure evidence. A later powered receive-only
> UART diagnostic captured `23868` bytes and `30` valid disarmed heartbeats from
> system/component `1.1` while sending zero serial bytes. The final full probe
> then opened `/dev/ttyAMA0:57600`, detected the FCU at `1.1`, and passed the
> connected/disarmed and hardware-safety gates with `mode: MANUAL` and
> `system_status: 4`. MAVROS nevertheless exhausted all automatic
> parameter-list attempts, and the explicit forced pull received no response
> before its bounded timeout. The helper exited `status=1 cleanup_rc=0` without
> `t0b_parameters.txt`, `t0b.json` or any of the required `41` parameter values.
> No parameter write, bridge start, mode change, arming, RC, motor or thrust
> action occurred. The copied E4 archive verified at
> `f0c04727f175ffb2f3e95f6f0f7925be10b1b09bbc0283b633fa5b377ab08fd1`.
> A later powered duplex isolation captured `14326` inbound bytes and `18`
> valid disarmed heartbeats without a known-frame CRC error. It transmitted
> exactly one MAVLink PING and one `PARAM_REQUEST_READ` for `SYSID_THISMAV`,
> audited as two frames and `53` bytes in total, with no state-changing message.
> Neither request received a response. Its copied archive verified at
> `c1c73f8df65e5f109adc051d3f04990ce646830a4741ec628cd100090d993802`.
> T0b remains open; the next separately gated decision is T1's single
> `BRD_SER1_RTSCTS` link-configuration change with prior-value capture,
> read-back and rollback, not another identical full-pull retry. The evidence
> does not yet distinguish a Pi-to-FCU electrical path fault from FCU-side
> request handling. T1 and both T2 tiers remain closed.
> The operator then freshly confirmed the FCU/autopilot, control electronics and
> Herelink off, with propulsion power isolated, propellers removed and the hull
> restrained. This closes the 20/08/2026 physical hardware day. No approval or
> physical attestation carries into 21/08/2026.
>
> **21/08/2026 live update - T1 tested, failed and rolled back.** Revision
> `2600ea4` was deployed to the new Pi root
> `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260821_2600ea4`; all four
> governed members verified `OK`, and the helper's non-actuating `check`
> passed. The operator changed `BRD_SER1_RTSCTS` from `Auto (2)` to `0` and
> rebooted. The first guarded run reached connected/disarmed `MANUAL`, but
> automatic and forced parameter pulls again received no response. A second
> run began armed and stopped at the connected-and-disarmed gate before the
> parameter pull, bridge or command publisher started. Both runs ended
> `status=1 cleanup_rc=0`; no RC override, motor command or thrust command was
> issued by the repository pipeline. The copied Pi evidence archive verified
> at `d913d296c4aecd34ca305339ed1a9591215a75c061dec7552567f647df3643a7`.
> The operator restored and read back `BRD_SER1_RTSCTS=Auto (2)`, then confirmed
> the Pi, FCU/autopilot, control electronics and Herelink off, with propulsion
> power isolated, propellers removed and the hull restrained. T0b remains open;
> T1 candidate `0` is closed as a fix for this failure; neither T2 tier earned
> acceptance; and no physical approval carries forward.
>
> **25/08/2026 supersession - direct arm/disarm command and ACK proven.** A
> later operator-supplied Pi capture opened `/dev/ttyAMA0:57600`, loaded
> MAVProxy's `arm` module and received
> `MAV_CMD_COMPONENT_ARM_DISARM: ACCEPTED` for `arm throttle`. The capture began
> already `ARMED`, so it does not prove a fresh arm transition. A subsequent
> disarm received an accepted acknowledgement and ended explicitly
> `DISARMED`. This supersedes the generic receive-only description for this
> direct serial endpoint: Pi-to-FCU command delivery and the returned FCU ACK
> are proven for arm/disarm. It does not close the parameter-specific T0b
> failure, because no parameter response or required mapping artifact was
> captured. No `rc` override, non-neutral `SERVO_OUTPUT_RAW`, repository bridge,
> dashboard or VRX run occurred. The operator reports that the professor fixed
> the workstation-command blocker, but the supplied capture is Pi-local; the
> full workstation-to-Pi-to-FCU route still needs one correlated trace. T2a and
> T2b remain unearned. The 26/08/2026 target is a fresh-day, full-scale
> FCU-to-VRX integration with all real electronics active and propellers
> removed; today's approval and physical state do not carry forward.
>
> Diaries for 24/07/2026 and 07/08/2026 record the former policy and are left
> unchanged as history.
>
> **13/08/2026 Block C scope supersession - sequential live arm.** The
> maintainer explicitly expanded today's Block C to include a real-FCU
> arm/disarm observation. Block C now has two non-overlapping phases. C1 is the
> established Pi/workstation view-only telemetry run and retains its
> `armed:false` runtime contract. C2 begins only after C1 has recorded Pi
> `TEARDOWN=PASS`, workstation `WORKSTATION_TEARDOWN=PASS`, and the browser is
> closed. No C1 process may remain when C2 starts because the Pi helper aborts
> on `armed:true` by design.
>
> C2 uses the maintainer-stated physical sequence: propellers removed,
> propulsion power isolated, hull restrained and controls neutral; release the
> FCU-box hardware safety state; arm from QGroundControl on the Herelink;
> observe the armed state without sending a non-neutral input; disarm from
> QGroundControl; then confirm the disarmed state. No repository helper runs or
> transmits during C2. This makes the live arm/disarm observation part of Block
> C for 13/08/2026; it does not enable a dashboard/Pi arm path, authorize thrust
> or a non-neutral command, or alter the view-only helper.
>
> **13/08/2026 C1 result - PASS; C2 NOT RUN.** The transferred Pi helper
> matched its tracked size and digest. The workstation recorded seven-topic
> arrival, seven passing `10`-second rate probes and six fresh browser telemetry
> badges; the Hailo image streamed correctly in the Pi and browser views. The Pi
> command sentinel recorded zero messages, the FCU remained disarmed and raw
> thrust output remained neutral at real-boat `SERVO3 800` / `SERVO1 800`.
> Shutdown was Pi first with `TEARDOWN=PASS` and exit status `0`, followed by
> workstation `WORKSTATION_TEARDOWN=PASS` and exit status `0`. A subsequent
> host-context check found workstation ports `8002`, `8080`, `9090` and the six
> C1 process patterns absent. This closes C1 only. The separately sequenced C2
> arm/disarm observation has not run, so Block C as expanded above remains open.
>
> **13/08/2026 C2 pre-execution evidence correction - NOT RUN.** C2 now requires
> the Herelink build to expose a live `SERVO_OUTPUT_RAW` view before hardware
> safety is released. Its `time_usec` must advance, and the actual `servo3_raw`
> / `servo1_raw` values must be recorded before arm, while armed and after
> disarm. This is current raw-output evidence only: the message carries neither
> `SERVO*_FUNCTION` nor configured `MIN/TRIM/MAX`, so it cannot establish the
> left/right assignment or rail and cannot close T0b or T2a. The standalone T0b
> evidence remains absent and Block B remains failed at teardown. The C2 absence
> check now names `serve_dashboard.py`. A rejected arm is not retried and ends
> with confirmed `Disarmed` state plus re-engagement of the FCU-box hardware
> safety state; an accepted arm has the same required final state after normal
> QGroundControl disarm. No C2 action has run at this checkpoint.
>
> **13/08/2026 C2 pre-arm checkpoint - PASS; hardware safety still engaged.**
> The Pi P2 absence check passed, the workstation W2 check found ports `8002`,
> `8080` and `9090` free with the C1 processes absent, and the dashboard browser
> was confirmed closed. Herelink QGroundControl exposed live
> `SERVO_OUTPUT_RAW (36)` at `2.0 Hz` for the single active vehicle. The view did
> not display a separate source-system number; it reported component `1`, port
> `0`, an advancing message `Count` and an advancing `time_usec`. While the FCU
> remained `Disarmed` with hardware safety engaged, `servo1_raw` and
> `servo3_raw` both held `800`. The installed MAVLink dialect confirms
> `time_usec` as `uint32_t`, `port` as `uint8_t`, and both raw output fields as
> `uint16_t`. This independently corroborates C1's MAVROS `800/800` observation,
> but the `2.0 Hz` sampling cannot exclude a transient shorter than the
> approximately `500 ms` interval. Hardware safety has not been released and no
> arm request has been made. The next gate records the independent safety LED
> and requires `800/800` to persist for `10` seconds after safety release but
> before arm. Because real-FCU `BRD_SAFETY_MASK` is unknown, unchanged
> `800/800` cannot prove that the switch press registered or identify whether
> these channels were safety-gated; the blinking-to-solid LED transition is the
> sole discriminator for the safety-state change. Real-FCU `ARMING_RUDDER`,
> `BRD_SAFETY_MASK` and
> `BRD_SAFETYOPTION` remain unknown; C2 and Block C remain open.
>
> **13/08/2026 C2 result - PASS; expanded Block C PASS.** The external safety
> LED changed from blinking to solid, independently confirming safety release.
> Before arm, the FCU remained `Disarmed` and QGroundControl held
> `SERVO3 800` / `SERVO1 800` for `10` seconds with advancing `Count` and
> `time_usec`. One QGroundControl arm request then reached an observed `Armed`
> state; the same sampled `800/800` pair held for the bounded `10`-second armed
> window with a stable link and untouched Herelink sticks. QGroundControl
> disarm returned an observed `Disarmed` state and `800/800`; a sustained safety
> button press restored the blinking hardware-safety indication. Propulsion
> power was isolated, so `NO_PROPULSION_POWER_ISOLATED` records the physical
> isolation condition rather than proving command-path behaviour. The operator
> did not record the wall-clock arm and disarm times; the durable record uses
> `NOT_RECORDED`, and no repeat arm is warranted solely to obtain timestamps.
> The evidence is operator-observed at `2.0 Hz`, so it cannot exclude a shorter
> transient and carries no saved C2 telemetry artifact. C1 and C2 together pass
> today's expanded Block C. This does not close Block B, T0b or T2a, establish
> the configured output functions or rail, prove dashboard/Pi command
> transmission, or demonstrate powered actuator movement or thrust.

---

## 📊 Progress Overview

| Phase | Description | Status | Progress |
|:-----:|-------------|:------:|:--------:|
| 1 | Architecture & MVP | ✅ | 100% |
| 2 | Autonomous Navigation | ✅ | 100% |
| 3 | Coverage Planning | ⏸️ | 0% |
| 4 | Integration & Testing | 🔄 | 90% |
| 5 | Real-Hardware Deployment | 🔄 | In progress |

### Active System

| System | Architecture | Sensors | Features |
|--------|--------------|---------|----------|
| **AutoBoat Modular** | Modular (Perception + Planner + Controller) | 3D PointCloud | A\* path planning, simple anti-stuck, runtime config, web dashboard + camera, waypoint persistence |

> **Note:** The integrated AutoBoat monolith has been deprecated and moved to `legacy/`. Use the modular system.

---

## Phase 1: Architecture & MVP ✅

**Completed**: 27/11/2025

| Task | Status |
|------|:------:|
| ROS 2 topic conventions (\`/planning/path\`) | ✅ |
| Message types (Path, PoseStamped) | ✅ |
| Workspace structure (\`seal_ws\`) | ✅ |
| Straight-line planner v1.0 | ✅ |
| Path following controller v1.1 | ✅ |
| TF tree configuration | ✅ |

---

## Phase 2: Autonomous Navigation ✅

**Completed**: 28/11/2025

### AutoBoat Navigation System

- Integrated perception + planning + control
- Modular variant: Perception + Planner + Controller three-node pipeline
- 3D PointCloud processing (height/distance filtering)
- Simple Anti-Stuck System
  - Turn toward clearer side (bidirectional) until path clear
  - Kalman-filtered drift compensation
  - Skip detection during obstacle avoidance
- **Waypoint Skip Strategy** (NEW)
  - Stuck-based skip after 4 attempts
  - Obstacle blocking skip after 45s timeout
- Runtime PID/speed configuration
- Real-time web dashboard
- Terminal Mission CLI (`autoboat_cli`)

---

## Phase 3: Coverage Planning ⏸️

**Status**: Not Started | **Priority**: Low

| Task | Status |
|------|:------:|
| Region definition (polygon boundaries) | ⬜ |
| Boustrophedon coverage planner | ⬜ |
| Coverage validation (>95% target) | ⬜ |

---

## Phase 4: Integration & Testing 🔄

**Progress**: 90%

### Completed ✅

| Test | Status |
|------|:------:|
| GPS waypoint following | ✅ |
| Obstacle detection (3D) | ✅ |
| Multi-waypoint missions | ✅ |
| Stuck detection/recovery | ✅ |
| Waypoint skip strategy | ✅ |
| Runtime config updates | ✅ |
| Web dashboard (map, mission, camera) | ✅ |
| Terminal CLI | ✅ |
| Min-range spawn fix (5m) | ✅ |
| A\* path planning (hybrid + runtime) | ✅ |
| One-click launcher script | ✅ |
| Emergency stop (dashboard + CLI + nodes) | ✅ |
| Latched E-Stop channel (`/planning/emergency_stop` Bool, RELIABLE QoS) | ✅ |
| ACK-based stop / generate as `std_srvs/Trigger` services | ✅ |
| JSON log export (4 panels) | ✅ |
| JSON schema guards at publishers + visible dashboard errors | ✅ |
| Health check service (ROS 2 node + dashboard streaming) | ✅ |
| Health check 4-state parameter validation (PASS/TUNED/WARN/FAIL) | ✅ |
| Dashboard config system (dirty-params, sync, reset defaults) | ✅ |
| Parameter collision resolution (`perception_` prefix) | ✅ |
| VRX LiDAR patch script | ✅ |
| `max_speed` cap wired as forward-thrust ceiling | ✅ |
| Kalman drift compensation activated (gated update + feed-forward) | ✅ |
| Launcher readiness polls (replace fixed sleeps) + `WS_ROOT` guard | ✅ |

### Pending ⬜

| Task | Priority |
|------|:--------:|
| Performance benchmarking (RMS error) | Medium |
| Obstacle stress testing | Medium |
| Long-duration test (15+ min) | Low |
| Complex waypoint circuit (8-point) | Low |

### Documentation ✅

| Document | Status |
|----------|:------:|
| README.md | ✅ |
| Board.md | ✅ |
| Code comments | ✅ |
| Troubleshooting guide | ✅ |

---

## Phase 5: Real-Hardware Deployment 🔄

**Status**: Bring-up started | **Expected kickoff**: Week of 20/04/2026 | **Priority**: High

Supervisor walked through the real AutoBoat central control unit (CCU) in person on 23/04/2026 — boat frame, control unit enclosure, battery, and a Raspberry Pi 5 inside the enclosure as the companion computer. Hardware not yet delivered to the intern's bench, but the target platform is now physically verified rather than specified-on-paper.

Expected two-tier control architecture:

- **High-level (confirmed, 23/04/2026 visual)**: Raspberry Pi 5 running ROS 2 Jazzy + this repo's nodes, LiDAR driver, GPS/IMU drivers, dashboard, shore comms.
- **Low-level (TBD — likely autopilot)**: Supervisor's 23/04 request to install **Mission Planner + QGroundControl** as the intended flight-control toolchain strongly suggests a MAVLink-speaking autopilot (ArduPilot or PX4) sits between the Pi 5 and the thrusters — MP and QGC both assume a MAVLink-compatible flight controller. The specific chip / firmware has not been confirmed; earlier STM32 mention remains speculative. Treat the autopilot-in-loop architecture as the **working hypothesis** pending supervisor confirmation; the alternative (Pi drives thrusters directly, MP/QGC installed only for future research work) stays on the table.

The whole repo is expected to run on the Pi 5. Long-term (Phase 5.2+): QGC and the web dashboard should act as peer mission editors for one mission authority, with mission data exchange bridged through MAVLink while water-quality data remains dashboard-only. The current 11-12/06 workstation bridge is narrower: same-machine visual QGC display from dashboard Generate -> Confirm works, but same-session auto-refresh is not supported, manual Plan View download was not proven in clean local QGC, and reconnect/relaunch is the only proven v1 refresh workaround. QGC mission upload, bidirectional sync, real FCU upload, and command/write validation remain gated future work outside Phase 5.0 bring-up.

### Risks ranked (mitigation prep can start on Linux workstation without hardware)

| # | Risk | Why it matters | Mitigation |
|:-:|------|----------------|------------|
| 1 | LiDAR performance on Pi 5 | 30k points × 10 Hz in `rclpy` may saturate 1-2 cores | Profile callback in VRX; have `sample_rate: 2` + raised `min_cluster_size` as fallback; last resort = rewrite hot loop in `rclcpp` |
| 2 | `/wamv/*` topic hardcoding | 3 months of work tied to simulated topic names | Launch-file remapping (cleanest); inventory every `/wamv/*` reference to make next-week swap mechanical |
| 3 | Low-level bridge (new node, only needed *if* a separate low-level controller exists) | Translate thrust commands + ingest telemetry; protocol (UART/CAN/micro-ROS/GPIO PWM) depends on whatever the low-level controller runs — or is a non-issue if the Pi drives thrusters directly | **Ask supervisor: is there a low-level controller at all, and if yes what runs on it?** — this answer determines whether a bridge node is needed |
| 4 | Headless comms to shore | Dashboard range ≈ Pi's WiFi (30-50 m typical) | Walk-test WiFi range; 4G modem or directional antenna if > 50 m mission box; static IP or mDNS |
| 5 | Power-loss robustness | SD cards corrupt on sudden power-off — default boat failure mode | USB 3 SSD boot or read-only root FS with tmpfs overlay for logs |
| 6 | Safety integration | Real boat can damage property | Hardware watchdog (location depends on CCU architecture) + physical E-stop + a geofence mechanism TBD (cheapest option: a new dedicated check in the planner; re-introducing hazard polygons is also on the table); end-to-end verify dashboard E-stop cuts thrusters |

### Prep tasks (no hardware required)

| Task | Status |
|------|:------:|
| Write `remap.launch.yaml` aliasing `/wamv/*` → neutral topics; verify stack still runs | 🟡 file deployed 22/04/2026 (`816be9d`); 6 relays up + GPS matches source 1:1, but no-regression mission test deferred to Phase 5.1 bench (laptop RTF too low to hold a clean baseline) |
| Profile `/perception/obstacle_info` Hz in VRX; document baseline | ✅ 20.00 Hz at RTF ≈ 1.0, 4 ms stdev, 120 s under Buoy Field mission (22/04/2026 Linux workstation). Rate tracks Gazebo RTF — this host drops to 30-40% under heavier load; Pi 5 on-water is the real Phase 5 baseline to compare against. |
| Stub bridge node (inputs `/control/thrust_cmd`, outputs thrusters) with pass-through behaviour | 🟡 pseudocode drafted |
| Inventory of every `/wamv/*` reference across Python, YAML, JS, HTML | ✅ done |
| Supervisor conversation: confirm CCU architecture (is there a low-level controller? what chip? what firmware? any interface-control document?) | 🟡 checklist drafted; partial signal 23/04/2026 — MP/QGC request implies MAVLink autopilot in loop, specific chip / firmware still open |
| Install Mission Planner + QGroundControl on Linux workstation (prof-requested 23/04 toolchain) | ✅ 24/04/2026 — MP 1.3.9384.38258 + QGC stable AppImage 09/10/2025. **11/05/2026 update**: MP-Linux video panel + arm/disarm unblocked via host-local SkiaSharp 2.88.8 + `libdl.so` symlink fix (see `wiki/Common_Issues.md` MP-Linux entry); GDAL / OGR / OSR still degraded. **12/05/2026 diagnosis**: GDAL native wrappers are Windows PE DLLs, not Linux `.so`, so the SkiaSharp-style musl→glibc swap does not apply; Windows `.msi` remains the GIS / terrain fallback. |
| Spec shore-comms plan (WiFi range test, fallback to 4G) | ⬜ |

### Hardware-arrival tasks (requires CCU on-bench)

| Task | Status |
|------|:------:|
| Verify Ubuntu 24.04 + ROS 2 Jazzy baseline on Pi 5 | ✅ 22/05/2026 — prof reflash verified as Ubuntu Desktop 24.04.4 LTS Noble, `linux-raspi` 6.8.0-1056, aarch64, ROS 2 Jazzy base pre-installed |
| Install MAVROS Route 1 stack on Pi 5 | ✅ 22/05/2026 — `ros-jazzy-mavros` 2.14.0 + `mavros-extras` + `mavros-msgs` via apt, GeographicLib defaults installed, `dialout` active |
| Verify Pi 5 MAVProxy heartbeat endpoint | 🟡 02/06/2026 (shown 03/06) + 04/06/2026 first-party repeat — professor photo sent on 03/06 morning, with the Pi desktop clock showing Tue 02/06/2026 22:09 capture time, shows MAVProxy on `/dev/ttyAMA0` at `57600` detecting vehicle `1:1` on link 0, `online system 1`, mode `HOLD`, `fence present`, and ArduPilot `EKF3 waiting for GPS config data` status text. On 04/06, MAVProxy with `--master=/dev/ttyAMA0 --baudrate 57600` repeated the same vehicle `1:1`, `online system 1`, `HOLD`, `fence present`, and EKF3 status before UDP fanout. **26/06/2026 caveat:** after the box was shut down and relaunched, the usual startup music/sound was missing; a camera-off MAVProxy check opened `/dev/ttyAMA0` at `57600`, but no heartbeat arrived and MAVProxy reported `link 1 down`. At the 26/06 close this was treated as a box power/wiring issue to inspect on Tuesday 30/06/2026 before rerunning MAVProxy/MAVROS, not as a Route 1 install regression. **30/06/2026 update:** the 26/06 symptom was reported cleared, but not with logged evidence. The user reported a very quick morning telemetry sanity check — heartbeat visible again, with other sensor feedback data also visible. That retires the strict 26/06 "no heartbeat heard" symptom as the only current observation; MAVProxy's own `link 1 down` status was not re-observed, since no MAVProxy console was reopened. No MAVProxy transcript was captured — the exact detected vehicle `1:1` / `online system 1` lines were not pasted — and no fresh `/mavros/state connected: true` was recorded on 30/06, so the ROS-side telemetry gate is likely healthy but not freshly documented. At the 30/06 close, the logged repeat remained open: the next bench window needed a bounded MAVProxy heartbeat probe followed by `/mavros/state` and a small read-only sensor-topic sample. Nothing between 01/07/2026 and 14/07/2026 revisits the link on hardware — the accelerator sessions explicitly excluded MAVProxy / MAVROS, and the 13-14/07 MAVLink telemetry review was source-only with no hardware — so at the 14/07 close the 30/06 report was the latest observation and 04/06 was the latest logged evidence. The 15/07 and 17/07 rows below supersede that boundary. |
| Current MAVProxy/MAVROS endpoint status | ✅ 15/07/2026 + 17/07/2026 — this forward status supersedes the open/current wording in the June heartbeat history above. The 15/07 logged bench run restored first-party heartbeat evidence; both 17/07 IoT runs again passed MAVProxy heartbeat, MAVROS `connected: true`, armed `false`, and all five telemetry samples. GPS fix and all command/write paths remain open. |
| Verify Pi 5 MAVROS heartbeat and first ROS telemetry | ✅ 04/06/2026 + 05/06/2026 + 19/06/2026 — MAVProxy on `/dev/ttyAMA0:57600` fanned out to `udpout:127.0.0.1:14550`; MAVROS `apm.launch` with `fcu_url:=udp://127.0.0.1:14550@` reported `CON: Got HEARTBEAT, connected. FCU: ArduPilot`; `/mavros/state` returned `connected: true`, mode `HOLD`, armed `false`; first ROS samples captured from `/mavros/imu/data`, `/mavros/global_position/raw/fix`, `/mavros/battery`, and `/mavros/rc/in`. The 05/06 camera-off rerun on `ROS_DOMAIN_ID=12` captured a clean graph with 136 `/mavros/*` typed topics and no TurtleBot4 / Create3 / Gazebo / OAK-D noise; raw GPS remained no-fix and `/mavros/rc/in` had `channels: []`. GPS remains no-fix / EKF GPS-config pending; targeted request/response paths timed out on 04/06, so command-path mapping is not validated yet. The 19/06/2026 camera-OFF post-update re-check on `IoT IMT Nord Europe` re-confirmed `connected: true`, mode `HOLD`, and live IMU / battery after the 18/06 ROS sync (MAVROS held `2.14.0`); the 136-topic `/mavros/*` graph was also visible on the workstation over DDS. |
| Reconfirm MAVProxy/MAVROS and display live control-box telemetry with Hailo co-load | 🟡 15/07/2026 — this supersedes the MAVProxy heartbeat row's 04/06 logged-evidence boundary. MAVProxy again detected vehicle `1:1` on `/dev/ttyAMA0:57600`, reported the vehicle online in `HOLD`, and provided loopback fanout to a minimal MAVROS profile. MAVROS passed `connected: true`, armed `false`, and samples from state, raw GPS, IMU, battery, and RC. The workstation dashboard displayed those feeds while the stock-COCO Hailo overlay streamed. GPS remained no-fix; full endurance and dashboard-to-FCU command/write validation remain open. |
| Verify RealSense D435i ROS bridge on Pi 5 | 🟡 27/05/2026 + 28/05/2026 + 05/06/2026 + 10/06/2026 + 18/06/2026 + 24/06/2026 + 25/06/2026 + 26/06/2026 — post-reflash Ubuntu Desktop retest through Remmina confirms color/depth via `realsense2_camera_node` v4.57.7 (D435I serial `213622070342`, FW `5.14.0`, USB type `3.2`; color `1280x720`, depth `848x480`, image topics publishing). IMU-only launch also publishes `/camera/camera/imu` plus accel/gyro samples. 28/05 Pi-local color-only viewer check verified `/camera/camera/color/image_raw` in both `rqt_image_view` and RViz2 after installing `ros-jazzy-rqt-image-view` and `ros-jazzy-rviz2`; RViz2 reported OpenGL `3.1`. On 10/06, default `rs_launch.py` opened color + depth on serial `213622070342`, `/camera/camera/color/image_raw` averaged `18.341` Hz during the camera-only proof, `rqt_image_view` displayed live video, and `web_video_server` served the same image topic over MJPEG on the Pi. On 18/06, `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 exposed `/camera/camera/color/image_raw` over `ROS_DOMAIN_ID=12`; workstation DDS discovery required `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, and the dashboard displayed the Pi RealSense feed through loopback-only rosbridge / `web_video_server` / dashboard services. The practical dashboard profile was `enable_depth:=false rgb_camera.color_profile:=424x240x15`, with a clean workstation receive sample near `14.8-15.0` Hz after other subscribers were stopped. A full simulated out-and-return-home mission also appeared to run normally while the dashboard Camera panel showed the RealSense feed. On 24/06, a camera-only YOLO dataset-readiness run used the same `424x240x15` RGB profile without dashboard, MAVROS, QGC, Herelink, or YOLO inference: workstation DDS saw publisher count `1`, QoS `Reliability: RELIABLE` / `Durability: TRANSIENT_LOCAL`, and about `15 Hz`; Pi temperature stayed around `68.85-72.7 C`, with no undervoltage or throttle evidence. On 25/06, a bounded ROS-camera-node fallback procedure used the same `RGB8 424x240x15` topic and held camera-only flow around `14.939-15.012` Hz before feeding frames to the custom NCNN model; F2 processed 30 live frames in `10.4 s` before the intended `80.0 C` thermal abort fired at `80.95 C`. On 26/06, SSH/headless retesting separated the Remmina / desktop-session confound from deployment load: no-camera floor was `51.25-54.00 C` (mean `52.19 C`), camera-on / no-NCNN floor was `50.70-52.35 C` (mean `51.03 C`), and the camera topic averaged `14.989 Hz`. A short ROS-camera -> custom NCNN live run then completed `150` frames in `18.8 s` at `mean_fps=7.98` / `mean_inf_ms=123.8` with temp `54.55 C -> 67.75 C` and no abort, but the multi-run sustained test later climbed through `80.4-82.05 C` aborts. This remains camera-display / dataset-readiness / simulation-coexistence / bounded procedure / short-run inference evidence only: sustained inference at the current NCNN profile is not viable yet, and dashboard integration, real-FCU command/write path, QGC upload, Herelink acceptance, MAVROS telemetry change, or bidirectional sync was not validated. Combined color/depth/IMU remains load-sensitive: earlier combined attempts hit `HID set_power 1 failed` / `Motion Module failure` while the Pi displayed a low-voltage warning, 05/06 showed chronic undervoltage before RealSense and a user-observed Pi shutdown, and the 10/06 combined camera + MAVROS window captured coexistence plus `/mavros/state` only, with no combined camera Hz / IMU / GPS / battery inventory; temp reached 82.6 C and the power blocker remains open. |
| Build workspace on Pi 5 (native ARM64 build) | ⬜ |
| Run isolated Pi 5 YOLO CPU feasibility spike and workstation training/export path | ✅ 09/06/2026 + 10/06/2026 + 23/06/2026 + 24/06/2026 + 25/06/2026 + 26/06/2026 — `yolo26n.pt` loaded in `~/venvs/yolo-pi5`, exported to NCNN as `yolo26n_ncnn_model`, and ran static-image CPU inference at `imgsz=320` on the `bus.jpg` fallback with `detections: 5` and speed timings preprocess 17.24 ms / inference 244.42 ms / postprocess 15.05 ms. The 10/06 demo repeated static-image NCNN inference for 5 runs on local `bus.jpg`, with 5 detections each run, mean inference `84.09` ms, and temp 68.8 C -> 72.2 C. On 23/06, the workstation path passed CUDA train -> NCNN export with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, `yolo26n.pt`, and `NVIDIA RTX A3000 Laptop GPU`; one-epoch `coco8.yaml` training wrote `runs/smoke/weights/best.pt`, then NCNN export wrote `runs/smoke/weights/best_ncnn_model` under `/home/ghostzero/datasets/uvautoboat_yolo_2026-06`. That workstation-exported NCNN model was copied to Pi `imt-aqua-drone@10.120.2.249` and ran 3 static CPU inferences at `imgsz=640` on `000000000042.jpg`, with `boxes=2`, steady-state inference `226.0-281.1` ms, and temp `68.85 C -> 68.30 C` with no undervoltage / throttle evidence. On 24/06, the first RealSense RGB pipeline-validation pilot was captured, reviewed, labeled, and split outside the repo: 7 `person` images plus 4 clean negatives became a tiny 9/2 train/val split, all label rows used class `4`, all coordinates were normalized, and no rejected frames were copied into train/val. On 25/06, workstation-only training used that tiny split with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, and CUDA on `NVIDIA RTX A3000 Laptop GPU`: `yolo26n.pt` trained for 50 epochs into `runs/baseline_yolo26n/weights/best.pt`, validation was rerun to `runs/val_baseline_yolo26n`, and NCNN export wrote `runs/baseline_yolo26n/weights/best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Later 25/06, the custom NCNN export was copied to Pi `imt-aqua-drone@10.120.2.249` and loaded in `~/venvs/yolo-pi5` with Ultralytics `8.4.62` / `ncnn 1.0.20260526`; two saved validation images ran as static CPU inference at `imgsz=640`, returning `0` boxes on both images, with Pi temp `66.65 C -> 69.95 C` and no undervoltage / throttle evidence beyond boot-time storage-bus messages. A later bounded ROS-camera-node procedure fed RealSense RGB frames into the custom NCNN model: F1 saved 5 frames and ran inference, then F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` / `mean_inf_ms=340.9` before the intended `80.0 C` abort fired at `80.95 C`; the Pi had little thermal headroom from a roughly `72.7-73.8 C` baseline, so this points to cooling rather than a proven model infeasibility. On 26/06, `pyrealsense2 2.58.2` was installed only in the separate `~/venvs/yolo-pi5-rs`; direct camera-only capture proved `900` frames in `60.0 s` at `14.99 fps`, and a direct-SDK -> custom NCNN short run at `imgsz=640` completed `150` frames in `23.1 s` at `mean_fps=6.51` / `mean_inf_ms=151.9` with temp `57.3 C -> 68.85 C` and `0` boxes. Compared with ROS runs (`6.16-7.98 fps`, `123.8-160.6 ms`), direct SDK showed no meaningful capture-overhead advantage; the workload is inference-bound. The optional `imgsz=320` run segfaulted after model load, likely because the NCNN export was fixed for the `640` input profile; a real `320` test needs a separate workstation NCNN export at `imgsz=320`. The dataset/capture plan is documented in `wiki/YOLO_Dataset_Plan.md`. This proves the workstation-to-Pi NCNN handoff and Pi CPU runtime for a COCO model, plus custom tiny-pilot capture -> label -> split -> train -> validate -> export -> Pi static load/run mechanics, bounded ROS camera-topic -> custom NCNN procedure/safety-abort, direct camera-only SDK capture, and short direct-SDK -> custom NCNN mechanics only; it is not detector-quality evidence or sustained thermally clean live inference. Dashboard integration, MAVROS/QGC/Herelink, and command-path work remain unrun. |
| Compile and smoke-test custom YOLO HEF for the Raspberry Pi AI HAT+ 13 TOPS / Hailo-8L branch | ✅ 01/07/2026 + 02/07/2026 + 03/07/2026 + 07/07/2026 — Pi-side probe confirmed the HAT is PCIe-healthy (`1e60:2864`, gen-3 x1), the official pinned row is HailoRT / driver / pyHailoRT `4.24.0`, DFC `3.34.0`, and Model Zoo `2.19.0`, and the workstation Docker suite compiled the custom `yolo26n` checkpoint to `yolo26n_route_a_six_heads.hef` for `HAILO8L` with one `UINT8` `NHWC(640x640x3)` input and six raw output vstreams. On 03/07, the Pi installed the pinned runtime stack on Ubuntu 24.04.4 / kernel `6.8.0-1060-raspi`: matching headers and DKMS passed, `/dev/hailo0` appeared, `hailortcli fw-control identify` reported `HAILO8L`, and `hailortcli run yolo26n_route_a_six_heads.hef` completed `293` frames at `58.22 FPS`. On 07/07, the six-output host-side decode contract was proven on saved frames (`fb308f9`): a same-engine raw-head ONNX isolation reproduced the graph `output0` to float precision (box max abs `0.0 px`, class max abs `1.178e-7`), so six-output layout, direct 4-channel box decode, class sigmoid, and the `data.yaml` class map are settled, and the earlier full-precision box residual is now diagnosed as a Hailo DFC emulation vs ONNX Runtime cross-engine numeric difference amplified by stride, not a decode error. The next Hailo gate — a positive-bearing saved-frame Tier 3 (quantized path → host decode + NMS + un-letterbox versus Ultralytics) — is blocked upstream on a functional detector: the current tiny `best.pt` fires on none of the available saved frames at `conf=0.25`, so a larger labeled dataset and retrain are the precondition (see `wiki/YOLO_Dataset_Plan.md`). Accuracy-grade live RealSense detector input, live ROS image integration, dashboard integration, MAVROS/QGC/Herelink co-loads, and accuracy-grade calibration remain open. |
| Stock-COCO Hailo live dashboard path | 🟡 22/07/2026 + 23/07/2026 — the annotated D435I frame appears simultaneously in the Pi-local HighGUI `"Output"` window and workstation browser dashboard while one Hailo-owned capture publishes `/hailo/overlay/image_raw`. On 23/07, the Pi environment gate passed and one partial resizable run visually reproduced the image holding at a size while the outer window continued growing. The copied log adds 151 unlabelled inner-rectangle samples: the image reached `640x480` and remained there for the final 127 samples. No labelled `xwininfo` matrix was collected, so expected `KEEPRATIO` letterboxing was not separated quantitatively from a real cap. The operator ended this feature's experiments; fullscreen measurement and display-fix blocks will not proceed, and the diagnostic-only instrumentation was trimmed from runtime and tests on 24/07/2026 (`3890564`), leaving fullscreen in place. This is stock-model integration evidence, not custom detector accuracy, optimized transport, or full endurance acceptance. |
| Validate the tracked two-command stock-COCO/MAVROS live supervisor | 🟡 22/07/2026 + 23/07/2026 — the 17/07 runs reached six-topic arrival and automatic rates; the 22/07 combined run proved simultaneous Pi/dashboard output and motivated the lifecycle, discovery, and deadline hardening pushed at `b771223`. On 23/07, all six publishers became discoverable at the workstation arrival deadline but no message/rate samples ran; independently, the Pi reached source readiness and later exceeded its final-verification deadline during the battery sample. Both teardowns passed, but that run reached no completed source-window/live-hold. Normal Pi-first lifecycle acceptance has since been obtained: two view-only full-stack runs on 03/08/2026 each completed the source window, entered the monitored hold, and exited `status=0` on operator Ctrl+C in Pi-first order, with workstation six-topic arrival and rate acceptance. Both runs reproduced the daemonless graph-query defect (see the carried-forward known issue above), and in both the browser/stream closed before the Pi signal, so **browser-last ordering is not claimed**. The Pi-window-specific repeat is retired. The graph-query correctness fix is implemented behind a flag that is off by default, with red-first coverage and both focused suites green, and was **exercised live for the first time on 05/08/2026 with a feasibility PASS at shipped defaults**; the race recurred under it, so feasibility is not a demonstrated fix. Full endurance, optimized transport, GPS fix, custom-detector accuracy/calibration/live integration, and all FCU writes remain open. |
| Wire bridge node to real low-level protocol (only if supervisor confirms a separate low-level controller) | ⬜ |
| Swap `/wamv/*` remaps to real driver topic names | ⬜ |
| Connect MP / QGC to the autopilot (MAVLink default `14550/udp`, or serial if USB-tethered); verify telemetry + waypoint upload before attempting dashboard integration | 🟡 QGC/MP arm-disarm path confirmed 07/05/2026; FPV video panel verified campus-side 11/05/2026 (see row below). On 10/06, offline dashboard-cache -> QGC `.plan` conversion landed in `tools/qgc_plan_from_dashboard.py` and QGC Plan-view import was accepted on the workstation: 5 cached waypoints -> 5 plan items, home at the exported Sydney Regatta origin, and route geometry matching the dashboard. **11/06 update:** local simulator/dashboard -> QGC visual bridge accepted on the workstation via `tools/qgc_live_mission_bridge.py`: after dashboard Generate -> Confirm, the bridge served params, `MISSION_COUNT=7`, and mission items `seq=0` through `seq=6`; QGC displayed a route matching the dashboard over `127.0.0.1:14550`, without `.plan` import or mission-folder write. **22/06 update:** workstation QGC on `IMT-Aquatic-drone` showed read-only real telemetry without control actions while bound to UDP `14550`, including the known `EKF3 waiting for GPS config data` status. A 16:07 packet capture identified the sender as unicast UDP `192.168.43.1:52600` to workstation `192.168.43.160:14550` with 90 inbound packets in the saved 100-packet sample. This proves MAVLink transport to workstation QGC over the console/hotspot path, but not a MAVROS / ROS 2 consumer path; next read-only fork test should keep QGC on `14550` and use QGC MAVLink forwarding to a separate local port for MAVROS before trying a workstation MAVProxy/router. This remains separate from real FCU waypoint upload and command/write validation. |
| Herelink laptop-side video A/B retest: campus side verified 11/05/2026 — Linux QGC works on `Source = Herelink Hotspot` preset + `ffplay rtsp://<herelink-ip>:8554/fpv_stream` independently confirms the underlying stream (LIVE555 H.264 1920×1080@30, both UDP-default and TCP-interleaved transports; hotspot gateway `192.168.43.1` on `IMT-Aquatic-drone`); Linux MP video + arm/disarm also working after host-local SkiaSharp/libdl fix landed later 11/05 (see `wiki/Common_Issues.md` MP-Linux entry — reversible workaround, may need re-apply after MP update); GDAL/OGR/OSR Mono gaps unchanged. **22/06 update:** direct RTSP still works from the workstation, and TCP is the clean transport for the current stream, but the current image source is a Pi desktop / `rqt_image_view` screen capture after starting the Pi camera node. This is a setup regression for dashboard use: clean direct camera source not proven, and the path re-enters the Pi camera-consumer risk. Second-site retest deferred to next field session | 🟡 |
| Bench test: dashboard → Pi 5 → (low-level if present) → thruster signal (dry bench, motors disconnected) | ⬜ |
| Static analysis of thermals + current draw under full-stack load | ⬜ |

### On-water tasks (requires full CCU in boat, test-lake access)

| Task | Status |
|------|:------:|
| Manual-joystick test (no autonomy) — verify thruster mapping + E-stop | 🟡 Herelink manual control worked 07/05/2026; detailed thruster mapping + E-stop evidence still TBD |
| Single-waypoint autonomous run in fenced test area | ⬜ |
| Multi-waypoint mission with obstacle avoidance | ⬜ |
| Long-duration robustness (15+ min) on-water | ⬜ |
| Failure-mode drills: manual override, E-stop, low-battery return-to-home | ⬜ |

---

## 📝 Issue Tracking

### Resolved ✅

| Issue | Resolution |
|-------|------------|
| Invalid Windows file paths | Renamed to \`FREE.py\`, \`OUT.py\` |
| Sparse checkout blocking | \`git sparse-checkout disable\` |
| Markdown lint errors | Added \`.markdownlint.json\` |
| Spawn dock obstacle detection | Increased min_range from 0.5m → 5.0m |
| Runtime config not updating | Added config_callback to heading_controller |
| Boat circling around buoys | Added waypoint skip strategy (45s timeout) |
| Missing numpy dependency | Added python3-numpy to package.xml |
| Invalid setup.py entries | Removed non-existent apollo11, atlantis |
| Perception/Controller param collision (min_safe_distance) | Renamed Perception's to `perception_min_safe_distance` |
| Perception/Controller param collision (critical_distance) | Renamed Perception's to `perception_critical_distance` |
| Dashboard sending all params on Apply | Added dirty-params filtering (only changed fields sent) |
| Dashboard stale HTML defaults | Synced 17 HTML defaults to match launch YAML |
| VRX LiDAR at world origin | Initial fix: runtime `patch_vrx.sh` (issue #876). Superseded 06/05/2026 by fork bake-in commit `e384cd65` on `autoboat/main`; script retained as idempotent no-op safety net |
| Dead code in setup.py / nodes | Removed `_fixed` variants, unused utilities, dead states |
| Missing `std_srvs` dependency | Added to plan/package.xml |
| Dead `restart_mission` / `panic_stop` code | Removed from Controller, dashboard, CLI |

### Active 🔄

| Issue | Priority | Description |
|-------|:--------:|-------------|
| #4 | Medium | Advanced planner debugging |
| #5 | Medium | PID tuning refinement |
| #6 | Low | Gazebo SDF customization |

---

## 📅 Timeline

| Date | Milestone | Status |
|------|-----------|:------:|
| 25/11/2025 | Project Kickoff | ✅ |
| 26/11/2025 | Basic Navigation | ✅ |
| 27/11/2025 | End-to-End Pipeline | ✅ |
| 28/11/2025 | AutoBoat Navigation Complete | ✅ |
| 01/12/2025 | Simple Anti-Stuck + Mission CLI | ✅ |
| 03/12/2025 | Waypoint Skip + Runtime Config | ✅ |
| 03/12/2025 | Go Home Optimization (detour insertion) | ✅ |
| 03/12/2025 | README Consolidation + Cleanup | ✅ |
| 08/12/2025 | A\* Path Planning (Hybrid + Runtime modes) | ✅ |
| 09/12/2025 | One-Click Launcher Script | ✅ |
| 11/12/2025 | Wiki Documentation + README Update | ✅ |
| 14/12/2025 | LiDAR Smoke Detection (Spatial Density Filtering) | ✅ |
| 03/04/2026 | Code review + repo cleanup rounds | ✅ |
| 08/04/2026 | Obstacle avoidance partial fixes + dashboard cleanup | ✅ |
| 12/04/2026 | Pre-meeting sprint: VRX patch, repo audit, README rewrite, dashboard polish | ✅ |
| 13/04/2026 | Dashboard config system: dirty-params, param sync, reset defaults, collision fixes | ✅ |
| 13/04/2026 | USER_MANUAL + dashboard README rewrite | ✅ |
| 15/04/2026 | PPT fact-check (16 items), bilingual presentation script, logo SVG | ✅ |
| 15/04/2026 | Supervisor meeting delivered; wiki backfill (Glossary + Design_Rationale); Node Naming Refactor Plan | ✅ |
| 13/04/2026 | Teammate onboarding fix: bashrc guide, dashboard diagnostics, dynamic WebSocket URL, COLCON_IGNORE tracked, health check audit (46/46) | ✅ |
| 15/04/2026 | Pre-meeting dry-run after ROS 2 Jazzy apt upgrade — no regression, 46/46 PASS | ✅ |
| 16/04/2026 | One-shot node rename: OKO/SPUTNIK/BURAN/Vostok1 → functional names (26 files, ~1100+ refs) | ✅ |
| 16/04/2026 | Dashboard security: XSS fix, SRI hashes, server-side param validation, security wiki page | ✅ |
| 16/04/2026 | Dashboard UX: reject-not-clamp validation, orange/red toasts, range tooltips, copy buttons, A\* panel fixes | ✅ |
| 17/04/2026 | Param-range single source of truth: Python nodes publish `PARAM_RANGES`, dashboard auto-syncs HTML min/max | ✅ |
| 17/04/2026 | Dashboard `JSON.parse` hardening: 8 subscribers wrapped in try/catch to tolerate malformed messages | ✅ |
| 17/04/2026 | Dashboard UX polish: 31 hover tooltips, nav-mode restyle, preset confirm dialog, map grid performance | ✅ |
| 17/04/2026 | LiDAR smoke detection fully removed (-624 LOC across 10 files); FINISHED counter clamp; split-screen CSS hardening | ✅ |
| 18/04/2026 | Hardware-deployment phase logged; docs audit (`distributed` → modular) across README + USER_MANUAL + Board | ✅ |
| 19/04/2026 | Target-aware VFH via `/control/heading_error` + 4 `vfh_*` tunable params; preset cleanup (Python default sync, dead-weight key trim, CLI `--mode` legacy removal); Vostok1-era breadcrumb cleanup | ✅ |
| 19/04/2026 | Dashboard Go Home distance-based progress + `distance_to_target` wiring fix; latent `distance.toFixed` DOM-node crash fix | ✅ |
| 19/04/2026 | Docs fact-check sweep (Kalman params, health-check count, Python version, VFH, escape direction, preset names); `ros2 daemon` staleness documented in Common_Issues | ✅ |
| 19/04/2026 | Tier A/B/C dashboard UX sprint: E-Stop header badge, Reset guard, toast tuning, panel reorder, Map+Camera group, collapsible info panels, preset expand/flash/scroll, step hints, first-run onboarding tour | ✅ |
| 20/04/2026 | Dead-code & bandage audit (50-item plan); Tier 1 safe deletes (`SENSOR_TIMEOUT`, `escape_start_time`, `in_hazard_zone`, unused imports); voyage-completion off-by-one fix; `Common_Issues` colcon-cwd entry | ✅ |
| 20/04/2026 | `max_speed` cap wired + Kalman drift feed-forward activated (gated update, thrust compensation); `Design_Rationale` PID/speed-shaping + drift-compensation + hand-tuned-constants tables | ✅ |
| 20/04/2026 | Launcher readiness polls (`wait_for_topic`/`wait_for_port`/`wait_for_node`) + `WS_ROOT` sibling-`src/` guard against nested workspaces | ✅ |
| 20/04/2026 | Perception `moving_obstacles` velocity pipeline removed (-124 LOC, zero consumers) | ✅ |
| 20/04/2026 | Tier 2 close-out: latched `/planning/emergency_stop` Bool channel; `std_srvs/Trigger` services for stop + generate (drops CLI/dashboard retry loops); `position_history` reset on stop resume (prevent Kalman spike); JSON schema guards at publishers + visible dashboard errors; drop redundant Waiting-for-sync label | ✅ |
| 21/04/2026 | Health check 4-state parameter validation (PASS/TUNED/WARN/FAIL) via `config_tuned` flag on 3 nodes; dashboard `[TUNED]` magenta styling | ✅ |
| 21/04/2026 | Markdown refresh post-Tier-2: Glossary health-check entry, USER_MANUAL topology + services table, dashboard README service-client section | ✅ |
| 22/04/2026 | C1/C2/C3 bug fixes (`3389554`): `_log_bad_json` helper propagated from CLI to perception + planner callbacks (drops `except Exception: pass` silent fallbacks); `force_turn_after_reverse` latch now persists across control ticks — removed the unconditional same-tick reset that made the flag dead | ✅ |
| 22/04/2026 | I6 docstring refresh on 3 nodes (`cd009c0`): pub/sub surfaces match code; 8-state planner machine documented; Trigger services section added; `/control/heading_error`, `/planning/emergency_stop`, `/planning/set_config`, `/perception/param_ranges`, `/control/param_ranges` now in docstrings | ✅ |
| 22/04/2026 | Perception publish-rate baseline recorded (`65709a0`, RTF caveat `816be9d`): 20.00 Hz mean, 4 ms stdev, 120 s Buoy Field mission at RTF ≈ 1.0; rate tracks Gazebo RTF, Pi 5 on-water remains the real Phase 5 comparison target | ✅ |
| 22/04/2026 | `launch/remap.launch.yaml` deployed (`816be9d`): 6 `topic_tools/relay` nodes (GPS / IMU / LiDAR / camera / thrust L+R) gated on `use_real_hardware:=false`, plus conditional bridge-node stub for Phase 5.1; YAML `if:`/`unless:` syntax used (draft's nested `condition:` rejected by Jazzy launch schema) | ✅ |
| 23/04/2026 | Health-check count verify: runtime total **= 49 in both IDLE and ACTIVE** (IDLE: 49 PASS; ACTIVE: 41 PASS + 8 TUNED from applied presets). Matches `README.md:128` and `:236` claim exactly; no docs change needed | ✅ |
| 23/04/2026 | Dashboard shared-helpers consolidation: `scrollToEmergencyStop` 300 ms debounce (`03e5c2d`); `resetGroupToDefaults` helper extraction with thin wrappers (`11c5f95`); unified `debounceGroup(name, ms, fn, options)` helper absorbs `debounceCommand`/`debounceApply`/`debouncePreset` + camera refresh + E-Stop shortcut into single mechanism (`336fb28`, net –26 LOC) | ✅ |
| 23/04/2026 | Camera panel hardening (unplanned F+G blocks): same-topic Refresh no-op eliminates Mode B `web_video_server` deadlock vector (`560f9fe`, tear-down gap 200→500 ms); custom combobox with ▼ toggle + rosbridge `/rosapi/topics_for_type` auto-discovery replaces free-text topic input (`8c215e5`, hardcoded 3-camera fallback preserved; name-pattern filter drops zombie Image-typed LiDAR subscriptions) | ✅ |
| 23/04/2026 | Supervisor hardware walk-through: prof showed the real CCU in person — Pi 5 inside the control-unit enclosure (physically verified as companion computer). Prof-preferred toolchain **Mission Planner** (+ QGroundControl as cross-platform alt); signals a MAVLink autopilot in loop though specific chip / firmware not confirmed. Long-term ask: dashboard → MP/QGC as autopilot front-end (Phase 5.2+, post-bringup) | ✅ |
| 24/04/2026 | MP + QGC installed on Linux workstation per 23/04 ask (`qgc` + `missionplanner` in `~/.local/bin`; QGC AppImage in `~/Applications/`; Mono 6.8.0.105). MP 1.3.9384.38258 reaches main UI but GDAL / OGR / OSR DLLs fail under Mono (terrain / geo-ref degraded); QGC stable AppImage 09/10/2025 clean. Windows `.msi` fallback held for GIS-heavy demos | ✅ |
| 24/04/2026 | `tools/rate_probe.py` — QoS-aware publisher-rate probe working around Jazzy's `ros2 topic hz` lacking `--qos-*` flag. Correctness validated against `/perception/obstacle_info` (both RELIABLE, rate_probe agrees with `topic hz` within noise at idle RTF). Jazzy-bug live demo deferred — no BEST_EFFORT publisher in the current stack (ros_gz_bridge publishes LiDAR points RELIABLE, contrary to the sensor_data-QoS assumption). `wiki/Common_Issues.md` gets a new QoS-aware rate-probing subsection + corrected Obstacle-Detection diagnostic block | ✅ |
| 24/04/2026 | Dashboard UX pass 2 (`9832793`): S1 Reset during Confirm (was silently disabled) now greyed via `.mission-btn-blocked` class and pops `🛑 Reset blocked — click Confirm or Cancel first` on click; S2 Go Home while at home now defended twice over (planner-side `go_home` at-home guard via `waypoint_tolerance` + dashboard client-side check before `sendMissionCommand`, both surface `🏠 Already at home (X.X m from spawn)`); S3 multi-click Joystick toggle already defended (state-gated button + 800 ms `debounceCommand`), no fix needed | ✅ |
| 28/04/2026 | Sunday pre-applied dashboard polish verified clean (`ffb7f8f` cli relative path, `74eb2b2` four `updateValueDisplay()` calls in programmatic-mutation paths, `888fadd` option-1 `param_ranges` 3-tuple chain — 43 `liveDefaults` entries arrive from all 3 nodes, `getCanonicalDefault` returns YAML-published defaults). Part 2 option-1 cleanup sweep landed (3 dashboard files, +85/-84): 15 HTML `data-default` attrs deleted, JS `PERCEPTION_DEFAULTS` / `CONTROLLER_DEFAULTS` constants removed, `resetGroupToDefaults` signature flipped to prefix-based, Reset buttons gated on per-namespace `liveDefaults` arrival. 4-place sync drift class for default values collapsed to 1-place — `autoboat.launch.yaml` is now sole source of truth | ✅ |
| 28/04/2026 | Cold-start JSON-serialization race fixed in `/control/anti_stuck_status` (`6ec20af`): inline `_safe()` maps `inf` / NaN → `None` in `publish_anti_stuck_status` and the dormant mirror at `publish_status` `obstacle_distance` (caught by class-instance sweep on `_publish_json` callers); init sentinels at L286-289 and the L968 gate left untouched. `wiki/Common_Issues.md` gains a `### Known Startup Warnings (Cosmetic)` subsection cataloguing 4 upstream categories (`kdl_parser` / `libEGL` / Gazebo Follow `(deprecated)` / VRX `WaveVisual` SDF) with origin + why-cosmetic + a `grep -vE` filter recipe (`134e52c`) | ✅ |
| 29/04/2026 | Cold-boot launcher validation: 28/04 readiness-poll patch (`2c0194a`) holds — fresh-reboot run shows all 5 expected nodes up, no `wait_for_*` timeout warnings, no fatal nav-stack tab exits. Side finding `wait_for_topic` SIGPIPE-trapped `ros2 topic info` (`grep -q` exits early on `Publisher count:` match, closing the pipe; `ros2cli` raises unhandled `BrokenPipeError` on the trailing `Subscription count:` print → Apport `_opt_ros_jazzy_bin_ros2.crash` popup; `set -e` without `pipefail` masked the failure so launcher proceeded). Fixed by capture-then-grep refactor in `wait_for_topic` (`62636e9`). Gazebo RTF throttle flagged out-of-scope (LiDAR `/points` ~2 Hz vs 10 Hz nominal; libEGL DRI2 fallback on NVIDIA RTX A2000 as working hypothesis), deferred to week of 04/05 | ✅ |
| 29/04/2026 | Launcher prints `Total launch time: N s (Mm Ss)` after success header (`3822e54`): `$SECONDS`-based bash arithmetic, total only (no per-stage breakdown). First observation post-feature-deploy: 52 s on the Linux workstation. Baseline data point for next week's RTF investigation cold-vs-warm comparisons | ✅ |
| 30/04/2026 | Block E cold-start re-test PASS (first fresh boot since `62636e9` capture-then-grep refactor in `wait_for_topic`): zero `BrokenPipeError` in `/tmp/autoboat_launcher_probe.log`, no new today-dated `/var/crash/_opt_ros_jazzy*.crash` (only pre-fix 29/04 crash file untouched), all 5 expected nodes up, no Apport popup. Launch time 43 s. SIGPIPE fix holds | ✅ |
| 30/04/2026 | Block D markdown + docstring cleanup pass (`2dfa650`): 3 classes bundled into one commit (+8 / -14 across 6 files). (a) docstring Subscribes/Publishes drift in `waypoint_planner.py` (+2 subs) and `heading_controller.py` (+1 sub / +2 pubs); (b) stale `Last Updated` stamps in `USER_MANUAL.md` (24/04→27/04) and `web_dashboard/autoboat/README_autoboat_dashboard.md` (24/04→28/04) bumped to last-edit dates; (c) 6 broken Next-Steps wiki cross-references in `Quick_Start.md` and `Installation_Guide.md` removed (`scripts/sync_wiki.sh` confirmed not to rewrite anchors — they were genuinely broken on the published wiki too). Verified clean: TODO inventory (1 well-formed forward-looking note), 16/04 rename residue (intentional historical), `*_DEFAULTS` residue (intentional historical), cold-start time + health-check count claims | ✅ |
| 30/04/2026 | Block F VRX upstream-fork scheme captured (`626ce96`): scheme-only entries in `Board.md` Timeline (new TBD row 🔜) and `wiki/Roadmap.md` §8 "Sim infrastructure — VRX upstream fork" with 5 subsections (today's baseline, trigger conditions, what forking won't solve, cost+alternatives, explicit "not now"). Revision log renumbered §8 → §9. Reserves the future fork-or-don't decision behind explicit triggers (patch count >3, custom mods upstream wouldn't accept, Phase 5+ sim-side dependencies, maintenance balance flip) so the call gets made on evidence | ✅ |
| 30/04/2026 | Internship scope locked at the on-site scoping meeting (smaller-scale than originally planned — campus power outage + IMT Mines Alès supervisor unavailable forced the on-site team to run its own session in place of the formal joint delivery): **Obj 1 = telemetry only** (boat → `mavros2` on Pi 5 → ROS 2 over IoT WiFi → VRX sim on Linux; water-sensor data belongs to Obj 2; MAVROS is the bridge, MAVProxy is a router not the bridge; DDS-multicast verification on IoT WiFi flagged as early-priority); **Obj 2 CA placement** most likely Linux-side; **Obj 3 regional-datasets portion REMOVED** (insufficient accessible regional data); **Obj 3 validation** refined to same-day cross-validation (R₁ train + R₂ holdout in one outing; no temporal confound) with day-gap return acceptable for slow-changing parameters only; **Obj 3 ML scope** refined (residual-based anomaly detection + time-series forecasting + physics-informed ML as stretch — "ML trained on CA outputs" framing rejected). Documented in `wiki/Roadmap.md` §1.1 + §1.2 + §6 Phase E refresh + §7 update note + §9 revision log; in `working_diary/2026-04-30_*.md` Block C outcome. Three open questions sent to teammate maintainer for confirmation: Phase A parameter subset, CA placement, validation methodology. Formal joint presentation rescheduled — date pending IMT Mines Alès availability + power restoration | ✅ |
| 30/04/2026 | Block H1 Pi 5 ↔ flight-controller bring-up smoke-test procedure documented (`wiki/Pi5_Bringup_Smoke_Test.md`, +new "🔌 Hardware Bring-up" section in `wiki/Home.md`, +row in Roadmap §3 status table): SSH + UART/dialout setup, MAVProxy install with PEP 668 caveat for Ubuntu 24.04, heartbeat verify, IMU smoke test via `stream_data.py` from team. 8 known issues catalogued (legacy `MAV_DATA_STREAM_*` API + 1 Hz IMU rate too slow + EXTRA1-vs-RAW_IMU mismatch on ArduPilot + missing heartbeat timeout + 4 others). Modern `MAV_CMD_SET_MESSAGE_INTERVAL` replacement provided in §7 + 4 other suggested fixes (drop redundant sleep, heartbeat timeout, argparse, explicit close). 5-step bring-up order (heartbeat → direct script → UDP fanout → mavros2 → simulator integration) captured to enforce one-layer-at-a-time debugging | ✅ |
| 30/04/2026 | Block H2 IoT IMT Nord Europe local-only network impact analysed (Roadmap §1.3, +Phase 5 status row "Dashboard offline-capable for IoT-local network deployment ❌", §9 revision log entry): the IoT network is institutional/IoT-only with no internet, but the dashboard currently loads 4 internet-runtime deps — `roslib` from jsdelivr (`index.html:18`), Leaflet JS+CSS from unpkg (`index.html:21, 24`), OSM tiles (`app.js:342`), Google Fonts in `style_merged.css:4`. Without internet, (1) and (2) are **critical** (kill core dashboard + map respectively), (3) is critical for map background, (4) is cosmetic. Three mitigation paths captured (A: vendor libs locally — removes 3/4 deps; B: offline tile server with pre-generated MBTiles; C: map-less fallback mode as third-tier backup). Recommended order: A immediately (network-independent hardening, ~2 MB vendored), B before first on-water deployment, C optional. Dashboard README troubleshooting + `wiki/Common_Issues.md` + `USER_MANUAL.md` cross-linked to §1.3 for the durable analysis | ✅ |
| 04/05/2026 | Post-Labour-Day cold-boot sanity (Blocks A/B/C): launcher 43 s, 0 `BrokenPipeError`, all 5 nodes up — `62636e9` SIGPIPE fix + `2c0194a` readiness gates hold across the weekend; 30/04 visualizer JSON-warn verified silent under normal mission + fires on malformed publishes (with `--rate 2 --times 5` workaround for the `--once` BEST_EFFORT-vs-RELIABLE discovery race); GitHub Action propagated the 30/04 wiki commits over the weekend, local-side spot-check on Dashboard_Security / README_WIKI / Roadmap §1.3 markers all clean | ✅ |
| 04/05/2026 | Gazebo RTF throttle root cause + fix (Block D, deferred from 29/04): hardware drift catch first — `nvidia-smi` reports **RTX A3000 Laptop GPU** not A2000 (same Ampere driver line so hypothesis structure unchanged). Real cause was `prime-select on-demand` routing Gazebo to Mesa Intel UHD (TGL GT1) iGPU despite the discrete NVIDIA driver loading cleanly — `gpu_ray` LiDAR raycasting was iGPU-bound. Fix: `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` env-prefix on `bash one_click_launch_all/launch_autoboat_complete.sh` (env vars propagate cleanly through `gnome-terminal --tab -- bash -i -c "..."` chain). A/B numbers: `/points` 2.48 → 6.8 Hz on the full launcher (2.7×; 8.95 Hz / 3.6× standalone), `/clock` 80.9 → 219.7 Hz, RTF **0.32 → 0.88** (2.7×). `nvidia-smi pmon` confirms `gz sim server` + `gz sim gui` + `rviz2` all on GPU 0. CPU governor `powersave` flagged as remaining ~10–15 % RTF gap (D3, needs sudo, deferred). `wiki/Common_Issues.md` "Gazebo Running Slow" section rewritten with diagnostic flow + measured table + Pi 5-unaffected caveat. Open question for the maintainer: bake env vars into the launcher (auto / `--use-nvidia` flag / leave manual) — flagged in diary, code change deferred | ✅ |
| 05/05/2026 | Pre-field-test Block B sim verification (A=pending weather): warm `--use-nvidia` launch (44 s) → 5/5 nodes, 0 `BrokenPipeError`, 0 fresh `/var/crash/_opt_ros_jazzy*`. Mission cycle FINISHED 16/16 waypoints (100 %, 405 s sim @ RTF 0.88) via `autoboat_cli generate/confirm/start`. Rosbag dry-run: 14 topics requested, all subscribed at start; 79 080 messages / 21.5 MiB / 351.7 s; 12 non-empty (IMU ~89 Hz, thrusters ~21 Hz each, GPS ~18 Hz, mission_status 5 152, obstacle_info 4 320, current_target 3 391, anti-stuck 702, waypoints 3); `/planning/emergency_stop` 4 of 5 fan-published captured (recordability proven); `/health_check/*` advertised-only, 0 captured (scaffold L108 alternative criterion). `metadata.yaml` not flushed on backgrounded SIGINT — recovered via `ros2 bag reindex`. Pre / post health_check 49 / 46 PASS + 3 TUNED + 0 FAIL. B3 TBD list replaced with concrete fill-in form across 7 categories. B4 VRX §8.2 triggers re-checked: 0/4 still hold, HOLD stands. AM scope refinement recorded: even if A=GO, today's wet test is first-bring-up only (D1 + D2; D3-D5 + autonomy `/planning/emergency_stop` latching + full autonomy-stack network validation deferred — teleop stop/cutoff and a network smoke check stay mandatory) | ✅ |
| 05/05/2026 | `--use-nvidia` discoverability follow-up landed (deferred from 04/05 Block D open question): 5 user-facing docs annotated for hybrid-graphics laptop users (Optimus / PRIME) — `README.md` Quick Start callout, `wiki/Quick_Start.md` parallel callout, `USER_MANUAL.md` flag example added to one-click-launch code block + combine line includes `--use-nvidia`, `web_dashboard/autoboat/README_autoboat_dashboard.md` callout, `wiki/Common_Issues.md` inline annotation in the rebuild-recipe at L396 forward-pointing to "Gazebo Running Slow". +83 / -11 across 5 files. Manual env-prefix fallback at `wiki/Common_Issues.md:594-595` left untouched by design (older-checkout / one-off `ros2 launch` equivalent). | ✅ |
| 06/05/2026 | VRX upstream fork landed: `Ghostzero00018/vrx` with LiDAR `publish_model_pose` bake-in (issue #876) committed to the fork's `jazzy` branch (commit `e384cd65`); `patch_vrx.sh` retained as idempotent no-op safety net for ≥2 release cycles. Reference-surface migration: 5 install/clone URLs swapped (`README.md:62`, `USER_MANUAL.md:357`, `wiki/Installation_Guide.md:51 + 55 + 94`) + 1 dual-link entry (`USER_MANUAL.md:346`) rewritten with both arrows; 9 attribution / canonical-project links to `osrf/vrx` preserved. Two remotes set up locally — `origin` = fork, `upstream` = `osrf/vrx`. Two-branch model on the fork: `jazzy` (upstream-tracking + bake-ins) and `autoboat/main` (workspace-consumed branch where future inside-VRX mods land — mesh adds/removes, sensor-config tweaks, etc.). Newcomer-onboarding polish (commit `427f4b4`): all 4 install clone snippets re-pinned to `git clone --branch autoboat/main ...` so doc-followed path lands on the right branch; GitHub default branch on the fork also flipped to `autoboat/main` so plain `git clone` lands there too. Scope-expansion override of `wiki/Roadmap.md` §8.5 "explicit not now" — at fork time, 0/4 §8.2 triggers had fired; original framework preserved as audit trail; new §8.6 Migration log + §8.7 Upstream sync workflow added | ✅ |
| 07/05/2026 | First wet test completed at small artificial lake (D1/D2 scope only): boat survived in-water bring-up, Herelink manual control works, QGC and Mission Planner can arm/disarm over MAVLink. Laptop-side video feed remains unresolved; QGC log triage points away from VA-API/map-tile noise and toward Herelink RTSP/video-sharing, QGC video-source configuration, or location/link-condition differences. Professor notes video reportedly worked during the earlier campus-site stream test, so a controlled campus-vs-lake A/B retest is queued. Autonomy, ROS dashboard field link, remap-layer no-regression, and obstacle/lake-edge behaviour remain untested. Diagnostic recipe captured in [`wiki/Common_Issues.md`](wiki/Common_Issues.md#qgc--mission-planner-can-arm-via-herelink-but-video-is-missing) | 🟡 |
| 11/05/2026 | Herelink video A/B campus side verified (intern working room, Herelink hotspot `IMT-Aquatic-drone` gateway `192.168.43.1`): Linux QGC video works on `Application Settings → General → Video → Source = Herelink Hotspot` preset (no manual URL field involved; QGC `.ini` shows `[Video] videoSource=Herelink Hotspot`). RTSP underlying that preset independently verified via `ffplay rtsp://192.168.43.1:8554/fpv_stream` — LIVE555 Streaming Media server, H.264 High @ 1920×1080 30 fps; both UDP-default and `-rtsp_transport tcp` transports work. Alternate path `/live` does NOT exist on this firmware (`404 Stream Not Found`). Linux Mission Planner on the same link fails with `System.DllNotFoundException: Unable to load library 'libSkiaSharp'` from `SkiaSharp.SKObject..cctor` — GCS-runtime-side runtime gap (same failure class as the 24/04 `GDAL / OGR / OSR` Mono gap), split out as a separate `wiki/Common_Issues.md` entry and treated as degraded; QGC is the Linux-side video tool of record going forward, MP-Windows (`.msi`) remains the serious-MP fallback. Side-finding documented in `Common_Issues.md`: Ubuntu Noble apt VLC on this workstation lacks the Live555 RTSP access module (package built with `--disable-live555`) and fails on this stream with `satip stream error: Failed to play RTSP session`; `ffmpeg`/`ffplay`, snap-VLC, or flatpak-VLC are working alternatives. Second-site (lake) retest deferred to next field session under the now-known-good QGC preset — A/B comparison is not yet complete. Pi 5 Side activity (long-deferred `launch/remap.launch.yaml` no-regression discovery phase) initially carried forward from the main Herelink blocks: the Pi 5 is reachable only on the `IoT IMT Nord Europe` private workstation↔Pi link, which requires a single-WiFi-adapter offline switch off campus WiFi; offline workflow drafted before the evening execution. **Late-day addendum**: MP-Linux SkiaSharp + libdl fix landed (host-local, reversible) — root cause was a musl-libc bundled `libSkiaSharp.so` (`ldd` showed `libc.musl-x86_64.so.1 => not found` on Ubuntu) plus a missing unversioned `libdl.so` symlink (Ubuntu Noble ships only `libdl.so.2`; `libc6-dev` provides `libdl.a` static lib not the runtime symlink). Fix: SkiaSharp.NativeAssets.Linux 2.88.8 NuGet glibc swap at `~/MissionPlanner/{,x64/}libSkiaSharp.so` (musl original backed up at `~/MissionPlanner/x64/libSkiaSharp.so.musl.bak`) + local `~/MissionPlanner/libdl.so` symlink to `/lib/x86_64-linux-gnu/libdl.so.2`. MP-Linux video panel + arm/disarm verified end-to-end at the campus working room; Herelink controller's Radio Status panel (`~/Pictures/Camera/herelink_settings.png`) showed Paired link, Controller signal strength M:-69 / S:-73 dBm, Air Unit signal strength M:-74 / S:-67 dBm, Uplink Rate 1395 kbps, Uplink bandwidth 16926 kbps, Fly Distance 0 m (healthy-link baseline for the campus working-room setup). First post-fix MP-Linux video + MAVLink validation sample captured at `~/.local/share/Mission Planner/logs/2026-05-11 14-56-05.{rlog,tlog}` (618 KB + 850 KB). `wiki/Common_Issues.md` MP-Linux entry's speculative "If a fix is needed later" section replaced with the working recipe + rollback + verification log details. GDAL/OGR/OSR Mono native gaps from 24/04 remain unchanged but no longer block the video panel (SkiaSharp/libdl are upstream dependencies). MP-Windows (`.msi`) remains the serious-MP fallback for the full feature surface, especially GIS / terrain / advanced geo-ref. **Evening 11/05 — Pi 5 Side activity executed**: workstation reached Pi 5 on `IoT IMT Nord Europe` (`10.120.2.190` → `10.120.2.50`), SSH key auth installed, Pi `imtaqua-pi-01` verified on Ubuntu 24.04.4 aarch64 with ROS 2 Jazzy. Pi 5 verified as **bare ROS 2 (daemon only — no auto-launched driver services)** under **both `ROS_DOMAIN_ID=0`** (Pi's default; catches anything that may have autostarted under defaults on boot) **and `ROS_DOMAIN_ID=56`** (the workstation's target value for cross-machine ROS 2 graph discovery): in both cases `ros2 node list` was empty and `ros2 topic list` returned only `/parameter_events` + `/rosout` (the two standard ROS 2 daemon-bookkeeping topics every fresh daemon advertises — not real LiDAR / GPS / IMU / MAVLink driver topics). Clean baseline for Phase 5 driver bring-up — no surprises hiding behind the domain choice. DDS cross-machine discovery remains inconclusive until a long-running publisher probe; see diary Block H | 🟡 |
| 12/05/2026 | Pi 5 DDS cross-machine probe closed the main Phase 5 networking unknown: workstation on `IoT IMT Nord Europe` (`10.120.2.190/23`) reached Pi `10.120.2.50`, Pi-side `/pi5_dds_probe` publisher ran 162 messages, workstation discovered the topic and `timeout 20 ros2 topic echo --once` returned `data: pi5_probe`; `topic info --verbose` showed `Publisher count: 1` with RELIABLE/VOLATILE/AUTOMATIC QoS. Standard ROS 2 graph discovery works on this WiFi; Fast-DDS Discovery Server unicast is not required for Phase 5 driver bring-up. B.2 confirmed the Pi remains bare/headless ROS 2 Ubuntu (no DE, no VNC/xrdp, no display manager, no X clients), so PRIMARY desktop access is skipped today and SECONDARY viz is deferred until real driver topics exist. MP-Linux GDAL/OGR/OSR local recon found Windows PE native wrappers only (`~/MissionPlanner/gdal/{x86,x64}/*_wrap.dll`), no Linux `.so`; Common_Issues rewritten to replace the earlier musl-libc speculation. QGC stable update skipped: local AppImage timestamp matches GitHub latest stable v5.0.8; CloudFront Last-Modified not confirmed. README/wiki stamp sweep bumped `wiki/Home.md`, `wiki/README_WIKI.md`, and `working_diary/README.md`. Roadmap §8.8 also added the propeller-placement sim-vs-real geometry gap tracker | ✅ |
| 13/05/2026 | Deeper doc sweep + audit-real-test escalation day (Wed before Thu/Fri off-site; Mon 18/05 next on-site). **Block B audit-only sweep across 24 files** (12 wiki, 5 shell/SDF/xacro, 7 Python + launch YAMLs + 2 package.xml, plus repo-wide grep for Tue-outcome propagation): 7 stale forward-update findings + 1 borderline applied inline mid-session under user authorisation — 3 DDS-verified parentheticals (`wiki/Pi5_Bringup_Smoke_Test.md` L139 + L300, `wiki/Roadmap.md` §1.1 L28), 1 `one_click_launch_all/patch_vrx.sh` upstream → fork wording rewrite, 4 `perception v2.0 → v2.1` docstring updates across `plan/plan/lidar_perception.py` + `control/control/heading_controller.py`, plus 1 new module docstring for `plan/plan/health_check_service.py`. Plus Option B refresh of 4 user-visible v2.0 references in `wiki/3D_LIDAR_Processing.md` L1 + L33, `wiki/System_Overview.md` L83, `web_dashboard/autoboat/index.html` L103. Total: 9 files / 44+/14-, single commit `b535d6d` `docs: refresh DDS verification + perception v2.1 + patch_vrx wording`. **Block A note**: formal joint supervisor presentation now scheduled **Wed 20/05/2026 10h-12h** — supersedes the 30/04 "pending IMT Mines Alès availability + power restoration" hedge captured earlier in this Timeline. **C.6 Pi 5 internet pre-flight: Branch B-conditional.** Workstation reached `IoT IMT Nord Europe` cleanly via `nmcli connection up` (an earlier session-mid WiFi hard-block on `wlp147s0` was recovered off-line by the user before the pre-flight pipeline run; rfkill recovery pipeline drafted as a pitfall for future on-site sessions where WiFi state can't be assumed-on). Pi 5 SSH-side layered-IPv4 probes: default route `1.1.1.1 via 10.120.2.1 dev wlan0` from `10.120.2.50`, IPv4 DNS resolves `archive.ubuntu.com` to Cloudflare `104.20.28.246`, `curl -4 -sI http://archive.ubuntu.com/ubuntu/` returns `HTTP/1.1 200 OK`; outbound ICMP blocked. This refines the 30/04 "IoT = no internet" claim to **managed partial egress**, not open internet: apt HTTP worked from the Pi, but workstation-side internet and OSM tile egress still must not be assumed. Minimal-DE install was initially considered technically possible but later same day shelved permanently as noted below. **Folded-in C.8 Pi VNC audit: zero pre-install** (no packages, no systemd units, no binaries on PATH) — confirms Ubuntu Server doesn't bundle RealVNC like Raspberry Pi OS does. **C.8 workstation install**: `realvnc-vnc-viewer 7.15.1.18` installed via standalone .deb after purging an accidentally-installed `realvnc-rvncconnect 8.4.1` (Connect installer ran to completion despite the user cancelling the Wayland-disable prompt mid-flow; cleaned via `apt purge`). EULA clause 3.4 covers Free Subscription for private non-commercial use, applicable here. **C.7 Herelink/Pi-ROS decoupling — architectural finding for Phase 5**: with camera ON via control box and QGC live on the **Herelink console itself** (SSID `IMT-Aquatic-drone`, different topology than scaffold's "QGC on workstation" assumption), dual-domain Pi ROS sweep (`ROS_DOMAIN_ID=0` AND `=56`, env hygiene matching Tue B.1's verified-working configuration `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` + `unset ROS_LOCALHOST_ONLY` + `unset RMW_IMPLEMENTATION` + daemon stop/start per domain) returned only `/parameter_events` + `/rosout` (2 topics, 0 nodes) on **both** domains in **both** of two separate runs. The camera → Herelink-RF → QGC pipeline is fully decoupled from the Pi ROS graph; future autonomy-stack camera consumption needs a dedicated Pi-side ROS bridge (`gscam` / `usb_cam` / custom `rtsp→ROS`). Sim `/wamv/sensors/cameras/*` has no real-hardware counterpart in the current state. Three deployment networks recorded by exact SSID: `IMT Nord Europe 5G` (workstation campus internet), `IoT IMT Nord Europe` (workstation ↔ Pi ROS/SSH), `IMT-Aquatic-drone` (Herelink/QGC video). **Late-day addendum**: Branch A physical-console attach (micro-HDMI to HDMI1 + USB keyboard → Pi TTY1 login) **succeeded** per the box-aware power-cycle pipeline (SSH poweroff → cut whole-box power → attach cables → repower → auto-boot). **Branch B DE install permanently shelved per professor's directive** — Pi 5 stays Ubuntu Server headless permanently, no GUI / desktop layer ever; supersedes the earlier "deferred to Mon 18/05+" framing. **C.7 outcome (i) ALSO confirmed under different conditions**: with `ROS_DOMAIN_ID=56` unset and `ros2 run realsense2_camera realsense2_camera_node` running on Pi, workstation `ros2 topic list` enumerates full RealSense topic surface (`/camera/camera/color/image_raw`, `/depth/image_rect_raw`, `/infra1+2/image_rect_raw`, `/accel/sample`, `/gyro/sample`, extrinsics, `/tf_static`); the Pi 5 hosts a Intel RealSense D435I (serial 213622070342, FW v5.14.0) on USB 2.1. Validates `realsense2_camera_node` as the dedicated ROS bridge predicted by outcome (ii); the two outcomes correspond to two architectural states (no Pi-side publisher vs explicit camera node), not contradictions. **Camera-consumer exclusivity finding**: when `realsense2_camera_node` + workstation rviz2 are streaming, Herelink console video stream is lost; when rviz2 stops, Herelink video returns. Root cause likely v4l2 device-exclusivity (camera node opens `/dev/video0` with `VIDIOC_S_FMT`, breaking the existing `v4l2loopback`-based fork that the Herelink RTSP pipeline relies on); matches the `xioctl(VIDIOC_S_FMT) failed, errno=16 Device or resource busy` errors in the node bring-up log. Phase 5 constraint: autonomy-stack camera consumption and Herelink operator video are mutually exclusive consumers under current Pi setup unless a different sharing mechanism is engineered. **Pi 5 brownout root-cause identified for prior "sleep" symptoms**: 5V-via-GPIO-pin power shared off the main 14.8V LiPo battery sags below the PMIC's ~4.63 V under-voltage trip threshold under RealSense streaming load, triggering PMIC shutdown (LED solid red — not actual sleep, halted SoC); temporary fix is separate USB-C charger for Pi 5 decoupled from the main battery (verified stable). Permanent Phase 5 fix is hardware-side (regulated ≥5A dedicated 5V supply, thick-short GPIO leads, bulk capacitance, possibly powered USB hub for RealSense). **Pi 5 session-hardening config edits applied**: `/boot/firmware/config.txt` += `dtparam=power_ctrl_button=off`; `/etc/systemd/logind.conf` `HandlePowerKey=ignore` + `IdleAction=ignore` + `IdleActionSec=3000mins`. **RealVNC parked**: workstation Viewer install retained but Pi-side server install no-go indefinitely per the prof headless directive | ✅ |
| 18/05/2026 | Post-Thu/Fri-break Mon: sim regression check + 13/05 log audit + broader doc sweep + PPT-prep kickoff. **Block B sim stack regression under default `ROS_DOMAIN_ID` PASS** (cold-boot 55 s with `--use-nvidia`; all 5 modular IDLE nodes up — `/lidar_perception_node`, `/waypoint_planner_node`, `/heading_controller_node`, `/waypoint_visualizer_node`, `/health_check_service`; 0 `BrokenPipeError`, 0 fresh `/var/crash/_opt_ros_jazzy*.crash`); no hardcoded-domain dependency in any runtime path (`git grep` showed all `ROS_DOMAIN_ID` hits were narrative/documentation, zero in launcher / launch YAML / dashboard JS / Python / health-check shell). Wed 13/05 C.7 `~/.bashrc ROS_DOMAIN_ID=56` unset is regression-free. **Block C 13/05 terminal-log audit** of `~/Desktop/13_05_2026_test_logs.txt` (1336 lines / 82 KB) vs the 13/05 diary write-up: **17 specific claims directly supported, 0 contradicted**, 1 borderline inline-fixed (RealSense USB hub port: `2-1` dominant across 16:25 / 17:33 / 17:40 / 17:41 runs, `1-1` observed once in the 17:14 pre-reboot run — `wiki/Roadmap.md` §3 row gains parenthetical via `de6e0af`, §9 revision log entry via `c9cec9c`). 3 new-data-points queued post-presentation: Pi thermals 43-63 °C under RealSense load (positive evidence for Phase 5 hardware-design pass), 49 apt updates pending on Pi (Phase 5 driver bring-up decision branch), RealSense first-invocation `xioctl errno=16` `Device or resource busy`-then-auto-recover is the steady-state pattern (5/5 invocations show it across reboots / sessions / USB ports). 13/05 `working_diary` left frozen per append-only rule. **Block D broader stale-doc sweep across 8 target files** (`README.md` + `USER_MANUAL.md` + `Board.md` + `wiki/Home.md` + `wiki/README_WIKI.md` + `wiki/Roadmap.md` + `working_diary/README.md` + `web_dashboard/autoboat/README_autoboat_dashboard.md`): 0 stale claims; ~43 risky-term hits all legitimate. Scaffold-bug carry-forward from Block C fixed in today's diary (Block B pass-criteria scaffold prose listed `/AutoBoat` as one of 5 expected nodes; replaced with the actual modular IDLE 5 — the `/AutoBoat` monolith was deprecated to `legacy/` per Board L32). PPT-prep headroom preserved for Tue 19/05; **Wed 20/05/2026 10h-12h formal joint supervisor presentation** is the hard deadline | ✅ |
| 20/05/2026 | Joint supervisor presentation completed within the 10h-10h30 IMT Mines Alès cap (`working_diary/2026-05-20`). Live talk shipped from Tue 19/05 deck-shipping state; detailed talk timing / per-slide reactions / slide-claim pushback / supervisor satisfaction verdict not captured (compressed slot). **Block C marked N/A**: no separate IMT Nord Europe-only extension notes were captured. **Three Asks status: 2/3 resolved** — Phase A parameter subset resolved as scope clarification (physical sensor interface is not part of this internship's work scope, owned by another team member; parameter-subset detail belongs to the Phase A owner); CA placement resolved Linux-side (mild hedge — "probably placed on Linux machine"; consistent with Pi 5 headless + Linux-workstation-hosts-CA-compute topology); **validation methodology stays pending external confirmation only** (same-day R₁/R₂ one-outing split remains documented principal approach, locked 30/04/2026 per `wiki/Roadmap.md` §6 Phase E; day-gap return bounded to slow-changing parameters; not addressed today, carry forward to teammate maintainer reply or 03/06/2026 meeting). **Phase 5 next-step direction confirmed**: implement Pi 5 MAVLink ingestion path so the Pi 5 receives autopilot / boat telemetry and exposes it as ROS 2 topics. `mavros2` / MAVROS remains the direct MAVLink-to-ROS bridge route. MAVProxy remains useful for heartbeat verification, routing, or fanout; if used in the ROS ingestion path, it must be paired with a custom / `pymavlink` ROS publisher (preserves `wiki/Roadmap.md` §1.1 + Board 30/04 row distinction). Supervisor left exact route open; end state is Pi 5 telemetry → ROS 2 topics. **Action items**: IMT Mines Alès prof to send paper list on digital twin (review on arrival; likely informs Obj 3 ML methodology); **next supervisor meeting 03/06/2026 10h-12h** (2-hour morning window, not 30-min cap shape). Scope signals: digital-twin direction surfaced via paper-list deliverable; Obj 3 ML implication TBD pending paper review | ✅ |
| 21/05/2026 | Pi 5 inaccessible — control box at prof's office for a full-DE re-flash by the prof (supersedes the 13/05/2026 "Ubuntu Server headless permanently" supervisor directive; the prof himself initiated the GUI flash). Today's scaffold paper-only contingency fired; no live Block A/B/C work. Block D paper artifacts captured (`working_diary/2026-05-21`): `mavros2` install-path matrix (Route 1 apt `ros-jazzy-mavros` primary; Route 2 source build fallback; Route 3 MAVProxy + custom `pymavlink` publisher last resort), plus `mavros2` topic-name scheme alignment vs `launch/remap.launch.yaml` Layer A relays (sensor remaps via launch-time remap in `mavros2`'s launch; Layer B bridge node owns the thrust Float64 → mavros2 setpoint translation). Posture-reversal doc sweep: `wiki/Roadmap.md` §1.1 + §9 + `wiki/Pi5_Bringup_Smoke_Test.md` §2 prerequisites updated; past `working_diary/` entries left frozen per the append-only rule. Phase 5 Pi-side state from 13/05 (ROS 2 Jazzy install, SSH keys, dialout config, `/boot/firmware/config.txt` + `logind.conf` edits) wiped on re-flash — fresh start when the Pi returns. Under a full-DE Pi image, the 20/05 D2 hardware-design pass (regulated ≥5A 5V supply, bulk caps, USB hub for RealSense decoupling) becomes **more** load-relevant than under the prior headless-Server posture | ✅ |
| 22/05/2026 | Pi 5 returned after prof reflash. Live Block A/B MAVLink bring-up path green on `imt-aqua-drone@imtaquadrone-desktop` (`10.120.2.162/23` on `wlan0`): Ubuntu Desktop 24.04.4 LTS Noble + `linux-raspi` 6.8.0-1056 aarch64, ROS 2 Jazzy base already present, `packages.ros.org` reachable via apt, Route 1 `ros-jazzy-mavros` candidate visible. MAVROS install landed cleanly (`ros-jazzy-mavros` 2.14.0 + extras + msgs, 21 packages, 20.3 MB fetched / 273 MB installed), GeographicLib defaults installed via corrected ROS 2 ament path `/opt/ros/jazzy/lib/mavros/install_geographiclib_datasets.sh`, `dialout` activated and persisted after reboot, `openssh-server` installed/enabled, NTP clock skew fixed. GNOME Remote Desktop over RDP verified from workstation Remmina (`10.120.2.162:3389`) after compositor check showed GNOME/Mutter Wayland; `wayvnc` ruled out for this image. Late MAVROS launch check (`px4.launch`, `/dev/ttyACM0:115200`) proved the plugin topic surface appears but `/mavros/state` remains `connected: false`; no autopilot serial endpoint is visible yet (`/dev/ttyACM*`, `/dev/ttyUSB*`, `/dev/serial/by-id/*` absent; USB shows keyboard, mouse, RealSense only). HDMI cabling is video, not MAVLink. Block C heartbeat remains deferred until a real USB / UART / UDP MAVLink endpoint is connected | ✅ |
| 27/05/2026 | Remmina-side Pi 5 startup audit on `imtaquadrone-desktop`: clock synchronized, ROS 2 Jazzy env valid, no stale MAVROS process. Expanded endpoint sweep still found no usable MAVLink path — no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, or common UDP listener (`14550`, `14551`, `14540`, `5760`); only `/dev/ttyAMA10` was present and remains insufficient without TELEM wiring confirmation. ROS graph showed only bookkeeping topics before drivers; `/parasit_marvin` was just the `ros2cli` daemon. RealSense D435i color/depth ROS path works on the post-reflash desktop image (`realsense2_camera_node` v4.57.7, D435I serial `213622070342`, FW `5.14.0`, USB type `3.2`, color/depth image topics publishing). IMU-only launch also works and publishes `/camera/camera/imu`; combined color/depth/IMU remains power / USB-stability-sensitive after `HID set_power 1 failed` / `Motion Module failure` during a Pi low-voltage warning. Slab 3 paper branch selected until a real MAVLink endpoint appears | 🟡 |
| 28/05/2026 | Block A endpoint gate repeated through Remmina: Pi clock / ROS 2 Jazzy env green and no stale MAVROS process, but expanded endpoint audit still found no usable MAVLink link (USB showed keyboard, RealSense D435i, and mouse only; serial sweep found only `/dev/ttyAMA10`; no `/dev/serial/by-id/*`, `/dev/serial/by-path/*`, `/dev/ttyACM*`, `/dev/ttyUSB*`, or UDP listener on `14550`, `14551`, `14540`, `5760`). MAVROS was not launched; Slab 3 paper draft recorded a placeholder `systemd` unit for future MAVROS autostart with `fcu_url` left unresolved until a real endpoint appears. Separate camera-side check verified Pi-local color-only RealSense viewing: `realsense2_camera_node` opened D435i color `RGB8 1280x720x30`, `rqt_image_view` displayed `/camera/camera/color/image_raw`, and RViz2 displayed the same topic after installing `ros-jazzy-rqt-image-view` and `ros-jazzy-rviz2`. This is camera-path evidence only, not boat telemetry | 🟡 |
| 03/06/2026 | Professor photo sent on 03/06 morning changes the endpoint evidence; the Pi desktop clock in the photo shows the MAVProxy run was captured on Tue 02/06/2026 at 22:09 after reconfiguration. MAVProxy using `/dev/ttyAMA0` at `57600` detected vehicle `1:1` on link 0, reported `online system 1`, entered mode `HOLD`, showed `fence present`, and received repeated ArduPilot `EKF3 waiting for GPS config data` status text. This proves a MAVProxy heartbeat / ArduPilot status path for the reconfigured setup; MAVROS / ROS telemetry is still pending until `/mavros/state connected: true` is captured against the same endpoint | 🟡 |
| 04/06/2026 | MAVROS ROS-side telemetry gate passed on the reconfigured endpoint: MAVProxy on `/dev/ttyAMA0:57600` fanned out to `udpout:127.0.0.1:14550`; MAVROS `apm.launch` with `fcu_url:=udp://127.0.0.1:14550@` reported ArduPilot heartbeat, `/mavros/state connected: true`, mode `HOLD`, and first ROS samples from IMU, raw GPS (no fix), battery, and RC topics. GPS remains no-fix / EKF GPS-config pending; targeted request/response checks timed out, so dashboard / simulation integration and command-path mapping remain future work | ✅ |
| 05/06/2026 | MAVROS camera-off rerun on the same `/dev/ttyAMA0:57600` endpoint confirmed `ROS_DOMAIN_ID=12`, `/mavros/state connected: true`, mode `HOLD`, and a clean domain-12 graph with 136 `/mavros/*` typed topics and no unrelated TurtleBot4 / Create3 / Gazebo / OAK-D noise. Samples captured raw GPS no-fix, IMU, vehicle battery, and empty RC channels. RealSense / combined capture stayed power-blocked: the log showed repeated Pi undervoltage before the camera step, the user observed shutdown when launching RealSense, and no fresh 05/06 camera / combined topics were captured. Immediate remap plan is read-only Option B: MAVROS IMU can feed the existing `/wamv/sensors/imu/imu/data` consumer topic, while GPS needs a no-fix guard before feeding `/wamv/sensors/gps/gps/fix`; command / thruster mapping remains unvalidated | ✅ |
| 09/06/2026 | Post-meeting feedback recorded: professor said to keep working and that the graph still needs updates / polish; no code/config approval or external slide path was provided. Pi-local YOLO feasibility trial then passed on Pi 5 with isolated `~/venvs/yolo-pi5`: `yolo26n.pt` loaded, NCNN export succeeded in 15.8 s / total 16.8 s, and static-image NCNN inference on the `bus.jpg` fallback returned `detections: 5` with preprocess 17.24 ms, inference 244.42 ms, postprocess 15.05 ms at `imgsz=320` on CPU. This remains feasibility-only: no ROS node, RealSense stream, dashboard integration, continuous camera workload, or command-path mapping was added. RealSense / combined-load power risk, GPS no-fix / EKF GPS config, and unvalidated command/write path remain open. | ✅ |
| 10/06/2026 | Professor feedback was positive continuation only: "good" and "keep working". Live Pi 5 demo evidence added: RealSense default launch opened color + depth on D435I serial `213622070342`, color image averaged `18.341` Hz, `rqt_image_view` and Pi-local `web_video_server` both displayed `/camera/camera/color/image_raw`; MAVProxy + MAVROS again reached `/mavros/state connected: true`, mode `HOLD`, with IMU / raw GPS no-fix / battery samples but `system_status: 5`, FCU request/response timeouts, repeated EKF GPS-config warnings, and empty RC channels. YOLO stayed static-image only with 5 runs, 5 detections each, and mean inference `84.09` ms. Combined camera + MAVROS evidence remains narrow: topic/node coexistence plus state echo and no fresh pasted under-voltage tail, but no combined Hz / IMU / GPS / battery inventory and temp 82.6 C. Offline dashboard-cache -> QGC `.plan` conversion was added and QGC Plan-view import accepted with 5 plan items matching the dashboard geometry; no vehicle upload or command/write path was attempted. | ✅ |
| 11/06/2026 | Live local QGC visual bridge accepted on the Linux workstation. `tools/qgc_live_mission_bridge.py` uses the dashboard/planner topics, waits for confirmed `READY`, then presents a simulated surface-boat MAVLink mission surface to same-machine QGC over `127.0.0.1:14550`. After dashboard Generate -> Confirm, the bridge logged 7 active mission items, served 3 params, `MISSION_COUNT=7`, and mission items `seq=0` through `seq=6`; QGC displayed the route matching the dashboard without `.plan` import or mission-folder write. Scope remains visual-only: no real FCU upload, arming, thruster, actuator, Pi upload, Herelink network variant, or command/write path was attempted. | ✅ |
| 18/06/2026 | Pi RealSense -> workstation dashboard camera path proven on `IoT IMT Nord Europe`: `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 exposed `/camera/camera/color/image_raw`; `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` plus a workstation ROS daemon restart fixed cross-machine discovery; loopback-only rosbridge `127.0.0.1:9090`, `web_video_server` `127.0.0.1:8080`, and dashboard `127.0.0.1:8002` displayed the feed. Practical profile: `enable_depth:=false rgb_camera.color_profile:=424x240x15`; clean workstation receive sample near 14.8-15.0 Hz. User also observed a full simulated out-and-return-home mission while the dashboard Camera panel showed the RealSense feed. Camera-display / sim-coexistence only; no real-FCU command/write path, QGC upload, Herelink acceptance, MAVROS telemetry change, or bidirectional sync was validated. | ✅ |
| 19/06/2026 | Camera-OFF Pi 5 post-update MAVROS re-check on `IoT IMT Nord Europe` after the 18/06 ROS sync. For the packages checked, MAVROS held `2.14.0` (`ros-jazzy-mavros` / `-extras` / `-msgs`) and `ros-base` `0.11.0` / `web-video-server` `3.1.0` were same-version rebuilds, while `realsense2-camera` bumped `4.57.7 -> 4.58.1`; other ROS dependencies (e.g. `rclcpp`, `rmw-fastrtps-cpp`, `tf2`) also moved at patch level, so it is the live re-check — not a rebuild-only assumption — that showed no regression: MAVProxy heartbeat on `/dev/ttyAMA0:57600`, `/mavros/state connected: true`, mode `HOLD`, live IMU and battery `16.322 V`, and the workstation discovering 136 `/mavros/*` topics over DDS. Expected-open GPS no-fix / EKF GPS-config / empty RC / `system_status: 5` persist. `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` was pinned in `~/.bashrc` on both machines. Read-only health check; no real-FCU command/write path. | ✅ |
| 22/06/2026 | Console / Herelink hotspot observation on `IMT-Aquatic-drone`: workstation reached `192.168.43.1`, direct RTSP `rtsp://192.168.43.1:8554/fpv_stream` worked, and TCP was clean while UDP showed packet loss / decode errors. Current video content was a Pi desktop / `rqt_image_view` screen capture after starting the Pi camera node, not a direct camera feed, so this is a setup regression for dashboard use rather than adapter-ready video evidence. QGC showed read-only real telemetry while bound to UDP `14550`; a 16:07 capture identified unicast MAVLink from `192.168.43.1:52600` to `192.168.43.160:14550` with 0 kernel drops in the terminal summary. MAVLink transport to workstation QGC is proven; MAVROS / ROS 2 telemetry from that console path should next be tested through QGC MAVLink forwarding to a separate local port. No upload/control/write path was run. | ✅ |
| 23/06/2026 | Professor was not onsite, so the 22/06 Herelink video-source and QGC-forwarded MAVROS questions remain unanswered and no live QGC / Herelink / Pi / MAVROS test was approved. Work pivoted to YOLO / RealSense dataset planning. Workstation GPU path passed a local CUDA train -> NCNN export smoke test outside the repo (`/home/ghostzero/datasets/uvautoboat_yolo_2026-06`): `torch-2.12.1+cu130` on `NVIDIA RTX A3000 Laptop GPU`, `yolo26n.pt`, one `coco8.yaml` epoch, `best.pt`, and `best_ncnn_model`. X-AnyLabeling `4.0.0-beta.10` launched separately and exported a valid YOLO-Hbb `.txt` from a disposable `coco8` image. The workstation-exported `best_ncnn_model` then ran as a static-image CPU handoff check on Pi `imt-aqua-drone@10.120.2.249` (`imgsz=640`, `boxes=2`, steady-state inference `226.0-281.1` ms, temp `68.85 C -> 68.30 C`, no undervoltage / throttle evidence). New `wiki/YOLO_Dataset_Plan.md` defines first-pass classes, labeling rules, capture protocol, storage layout, clean training shell, NCNN export caveat, and Pi validation gates. This is toolchain/dataset preparation plus static Pi handoff only; custom RealSense capture, real-data training, custom maritime-model Pi validation, live RealSense inference, ROS integration, and dashboard integration remain future work. | ✅ |
| 24/06/2026 | Pi 5 RealSense RGB camera-only YOLO dataset-readiness check passed on `IoT IMT Nord Europe` with `ROS_DOMAIN_ID=12`: `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 opened D435I serial `213622070342` at `RGB8 424x240x15`; workstation DDS saw `/camera/camera/color/image_raw`, publisher count `1`, RELIABLE / TRANSIENT_LOCAL QoS, and about `15 Hz`; Pi thermal/power checks stayed clean (`68.85-72.7 C`, no undervoltage / throttle evidence). A scratch workstation saver captured a small pilot outside the repo, then review/dedup kept 7 `person` frames plus 4 clean negatives; X-AnyLabeling YOLO-Hbb labels exported to `raw/labels/`; R3 split copied only the active stems into `images/{train,val}` and `labels/{train,val}` as a 9/2 train/val split. This is camera-readiness, capture, label, and split evidence only: no training, custom model, live inference, ROS integration, dashboard integration, MAVROS, QGC, Herelink, or real-FCU command/write path was run. | ✅ |
| 25/06/2026 | Workstation-only YOLO training gate passed from the 24/06 tiny split outside the repo. The dataset lint still showed `9` train images, `9` train labels, `2` val images, and `2` val labels, with `9` total boxes all class `4` and normalized. `~/venvs/yolo-ws` imported Ultralytics `8.4.75` and `ncnn 1.0.20260526`; CUDA was available on `NVIDIA RTX A3000 Laptop GPU`. `yolo26n.pt` trained for 50 epochs into `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt`, validation was rerun to dataset-local `runs/val_baseline_yolo26n`, and NCNN export wrote `best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Metrics are informational only because the split has `2` validation images and `2` validation boxes. No Pi custom-model load, live RealSense inference, ROS/dashboard integration, MAVROS, QGC, Herelink, or real-FCU path was run. | ✅ |
| 25/06/2026 | Pi static-image custom NCNN load/run passed after the workstation export. The exported `best_ncnn_model` and two saved validation JPGs were copied to `imtaquadrone-desktop` (`10.120.2.249`) under `~/yolo_tests/custom_20260625_static`; `~/venvs/yolo-pi5` imported Ultralytics `8.4.62` and `ncnn 1.0.20260526`. The custom NCNN model loaded and ran both static images at `imgsz=640` on CPU. Both images returned `0` boxes at the default confidence threshold, so detections remain informational only; the result proves static Pi load/run mechanics, not detector-quality validation. Pi temperature moved `66.65 C -> 69.95 C`, and the dmesg voltage/throttle filter showed only the same boot-time storage-bus voltage-switch messages before and after. No RealSense stream, live inference, ROS/dashboard integration, MAVROS, QGC, Herelink, or real-FCU path was run. | ✅ |
| 25/06/2026 | Block F ROS-camera-node procedure spike ran after the static Pi load/run check. Direct `pyrealsense2` was unavailable in both `~/venvs/yolo-pi5` and `/usr/bin/python3`, so the fallback used `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 on D435I serial `213622070342` at `RGB8 424x240x15`. Camera-only topic flow held about `14.939-15.012` Hz, F1 saved 5 ROS snapshots and ran the custom NCNN model on them, and F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` / `mean_inf_ms=340.9` before the intended `80.0 C` safety abort fired at `80.95 C`. The Pi started near a `72.7-73.8 C` baseline, so the blocker is thermal headroom / cooling, not a proven model infeasibility. dmesg voltage/throttle filters stayed clean. This is procedure and safety-abort evidence only: detections were `0`, detector quality is not proven, sustained thermally clean live inference is not proven, and dashboard, MAVROS, QGC, Herelink, and real-FCU paths were not run. | 🟡 |
| 26/06/2026 | YOLO / RealSense cooling and direct-SDK closeout: headless SSH retesting showed the Remmina / desktop session was the thermal confound (`51.03 C` mean camera-on / no-NCNN floor), short ROS-camera -> custom NCNN inference passed (`150` frames, `18.8 s`, `mean_fps=7.98`, no abort), but the sustained ROS + NCNN loop climbed through `80.4-82.05 C` aborts, so the current `imgsz=640` profile failed the sustained thermal gate. `pyrealsense2 2.58.2` was installed only in `~/venvs/yolo-pi5-rs`; direct camera-only SDK capture passed (`900` frames / `60.0 s` / `14.99 fps`), and direct-SDK -> custom NCNN short inference passed (`150` frames / `23.1 s` / `mean_fps=6.51` / `mean_inf_ms=151.9`) with no meaningful overhead advantage over ROS. The optional direct `imgsz=320` run segfaulted after model load, so the next software thermal lever is a separate workstation NCNN export at `imgsz=320`, not a helper rewrite. Late camera-off MAVProxy opened `/dev/ttyAMA0:57600` after a box relaunch with missing startup sound, but no heartbeat arrived and it reported `link 1 down`; inspect physical power/wiring on Tuesday 30/06/2026 before rerunning MAVProxy/MAVROS. | 🟡 |
| 02/07/2026 | Hailo E2 workstation gate closed: official artifacts pinned at HailoRT / driver / pyHailoRT `4.24.0`, DFC `3.34.0`, Model Zoo `2.19.0`; Docker suite loaded on the workstation; custom `yolo26n` exported through ONNX, parsed as six raw heads, optimized with a mechanics-only 28-frame calibration set, and compiled to `yolo26n_route_a_six_heads.hef` for `HAILO8L`. Pi payload staged externally with the runtime packages and HEF. At the 02/07 close, the remaining gate was Pi runtime install plus static HEF execution, not decode or live RealSense. | ✅ |
| 03/07/2026 | Hailo Pi runtime gate closed on `imtaquadrone-desktop`: payload checksums passed, stale-clock / header preflight passed, matching `linux-headers-6.8.0-1060-raspi` and DKMS installed, `hailort-pcie-driver` / `hailort` / pyHailoRT all pinned at `4.24.0`, `/dev/hailo0` appeared after reboot, `fw-control identify` reported firmware `4.24.0` and architecture `HAILO8L`, Python `HEF` import passed, `parse-hef` confirmed the six-output `HAILO8L` contract, and `hailortcli run yolo26n_route_a_six_heads.hef` completed `293` frames at `58.22 FPS`. This is runtime-smoke evidence only: decode, saved-frame input, live RealSense, ROS/dashboard integration, MAVROS/QGC/Herelink co-loads, and detector quality remain open. | ✅ |
| 07/07/2026 | Hailo six-output host-side decode contract proven on the workstation, outside the repo (`fb308f9`). An independent same-engine isolation declared the six final head convs (`/model.23/cv2.{0,1,2}` box, `/model.23/cv3.{0,1,2}` class) as extra ONNX outputs and decoded them back to the graph `output0`: box max abs `0.0 px`, class max abs `1.178e-7`, so six-output layout handling, direct 4-channel box decode, class sigmoid, and the `data.yaml` class map are settled. The earlier full-precision residual (box max relative `0.025359`, max abs `3.7708 px`, median abs `0.01257 px`) was a Hailo DFC emulation vs ONNX Runtime cross-engine numeric difference amplified by stride, not a decode error, and is now a diagnostic only. Saved-frame decode-contract evidence only: no NMS / end-to-end match, Pi run, live RealSense, ROS/dashboard, MAVROS/QGC/Herelink, or detector-quality claim. Next Hailo gate is a positive-bearing saved-frame Tier 3 (quantized path → host decode + NMS + un-letterbox vs Ultralytics), but current reconnaissance found the tiny `best.pt` fires on none of the available saved pools at `conf=0.25`, including its own train images. That makes a functional detector / larger labeled dataset the upstream precondition before Tier 3 or accuracy-grade calibration can be meaningful. | ✅ |
| 08/07/2026 | Detector-recovery Blocks A-C closed as planning evidence only. Baseline inventory confirmed the current split is `9` train / `2` val images with `9` labeled instances, all class `person`; `buoy`, `vessel`, `dock`, and `obstacle` have zero examples. The current `best.pt` remains non-functional, returning no detections at `conf=0.25` and staying near the old `~0.003` confidence ceiling. A source-specific acquisition manifest was written outside the repo with VRX `buoy` / `dock` bootstrap rows and RealSense capture rows; VRX `vessel` is spawn-required, while VRX `obstacle` and `person` are unsupported without a separate source decision. A bounded Pi runtime smoke then proved single-process RealSense -> Hailo -> decode-summary mechanics with the current HEF (`30` frames, `8.61 FPS`, float32 six-output tensors), but zero detections remain expected. The visual target was pinned as YOLO-style colored boxes with class / confidence labels, not masks or polygons. No detector recovery, retraining, Hailo compile, accuracy-grade calibration, Tier 3, ROS image integration, dashboard integration, MAVROS/QGC/Herelink, or command/write path was run. | ✅ |
| 09/07/2026 | Pre-diary scaffold added for an isolated unicolor-object real-image training smoke. The proxy route intentionally precedes the VRX `buoy` / `dock` smoke because it tests the real RealSense capture -> manual box labeling -> workstation retrain -> held-out firing loop directly with easy targets. The proxy dataset stays outside both the repo and the maritime dataset, uses temporary classes such as `red_object`, `blue_object`, and `green_object`, and keeps YOLO-Hbb box labels. Execution remains gated on explicit approval; success would prove the training process on easy real objects only, not maritime detector quality, Hailo accuracy, Pi deployment, dashboard integration, or real target detection. | ✅ |
| 15/07/2026 | Bounded live dashboard integration: the user observed the stock-COCO Hailo overlay with detection boxes and class labels while a temporary view-only panel displayed actual control-box state, raw GPS, IMU, battery, and RC through MAVProxy, minimal MAVROS, DDS, and rosbridge. This proves simultaneous browser rendering and telemetry delivery, not a full endurance acceptance or dashboard-to-FCU command/write path. | 🟡 |
| 17/07/2026 | The tracked two-command supervisor ran twice on `IoT IMT Nord Europe`. Both runs reached six-topic arrival and automatic rate acceptance (Hailo `7.40/7.50 Hz`; five MAVROS topics near `1 Hz`), with MAVROS connected/disarmed and zero messages on the five monitored command topics. During both runs, the operator confirmed the combined stock-COCO overlay and telemetry browser view. Pi peaks were `68.3/67.2 C`; Pi log directories `live_dashboard_20260717_145905` and `live_dashboard_20260717_151749` were copied to the workstation. In each run the workstation dashboard stack became unavailable unexpectedly before the intended Pi-first stop, after which fail-closed Pi and workstation teardown markers passed. The cause, normal Pi-first lifecycle acceptance, and post-teardown temperature remain open. | 🟡 |
| 23/07/2026 | Pi-window environment P0 passed on the active desktop with OpenCV `4.10.0`, Qt `5.15.13`, XWayland/`xwininfo`, and a logical `1920x1080` root. One resizable Phase R run was partial: the Pi reached MAVROS connected/disarmed, telemetry, and `PI_SOURCE_STACK_READY=PASS`, and the operator visually reproduced the rendered image holding while the outer `"Output"` window continued growing. The copied Pi log contains 151 unlabelled inner-rectangle samples and records a persistent `640x480` plateau, but no labelled P2/`xwininfo` outer geometry, so no `KEEPRATIO`-versus-real-cap verdict was reached. The workstation had all six publishers at the deadline edge but no time for message/rate samples; separately, Pi final verification exceeded `90` seconds during the battery sample. Both teardowns passed; the thermal watchdog recorded `67.75 C`, below the `80 C` abort. The operator ended Pi-window experiments, so Phase FS and display-fix/acceptance blocks are retired. The measurement-only instrumentation remains uncommitted and is scheduled for trim before the next dashboard work. | 🟡 |
| 04/08/2026 | Batched MAVROS source view implemented offline and landed (`63d6e9a`, `c8a0ecd`). One run-owned `rclpy` participant spins to accumulate discovery, then serves all five source topics from one consumed-once generation published by checked atomic rename; the flag `LIVE_MAVROS_SOURCE_BATCH` is **off by default** and the flag-off path delegates byte-for-byte to the existing CLI query. Red-first: every defect case was observed failing before the change and both focused suites are green after it. Pi runtime margin measured for the first time - a full `rclpy` init/create/destroy/shutdown cycle takes `1.701 s` idle against a `3 s` startup reserve. Flag-off canary run (`live_dashboard_workstation_20260804_172253` / `live_dashboard_20260804_172331`): workstation preflight and services PASS, `PI_DATA_ARRIVED=PASS topics=6 elapsed=272s`, `W5_RATE_PROBES=PASS topics=6` with the image topic at `7.4-7.6 Hz` and all five MAVROS topics at `1.00 Hz`, Pi reached the monitored hold and stopped operator-requested, both teardowns PASS and both exits `status=0 cleanup_rc=0`. The seam replacement therefore did not regress the flag-off lifecycle. Pi-side figures extracted from the copied run directory: `0` `MAVROS_SOURCE_PROBE_RUN` records and no `source_view` cache, so two independent witnesses confirm the batched path did not run; the generated `mavros_source_probe.py` was materialized and left unexecuted. `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=115s peak=65C` - the window was not truncated. The defect recurred as expected for a control: `2` non-verifying readings in `2` distinct episodes (`/mavros/imu/data` in-window, `/mavros/battery` in-hold), both `attempt=1`, both `query_rc=0`, both `publisher count 0`, both recovered on attempt two; `0` identity-unknown, `0` episodes reaching attempt three, terminal data-plane probe still never exercised live. **Planning consequence:** per-run control counts are now `11`, `3` and `2`, so a control varying between `2` and `11` readings per run cannot be separated from a modest improvement by three enabled runs; any reduction inside that range is not evidence of a fix. Browser-last ordering still not obtained (browser closed after the Pi but before the workstation). No enabled-flag run was performed, so the batched path remains unexercised live. | 🟡 |
| 05/08/2026 | First enabled run of the batched MAVROS source view, at shipped defaults. **Feasibility PASS.** Offline Block A first: the generated probe was run standalone on the Pi against real `rclpy`, three timed runs at `4.618`/`4.116`/`4.076 s` real against a `6 s` hard bound, so non-spin overhead is `1.08`-`1.62 s` against a `3 s` startup reserve and the defaults were kept rather than raised. Live run `live_dashboard_workstation_20260805_163802` / `live_dashboard_20260805_163818` with `LIVE_MAVROS_SOURCE_BATCH=1`: `18` `MAVROS_SOURCE_PROBE_RUN result=OK`, zero `TIMEOUT` / `INCOMPLETE` / `FAILED` / `SKIPPED`, every summary `bound=6s settle=3s reserve=3s topics=5`, so one participant served all five topics per run across all four invocation groups. `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=85s peak=66C`, both supervisors `status=0 cleanup_rc=0`, workstation rates `7.40 Hz` image and `1.00 Hz` on all five MAVROS topics. **The payload contract is now verified against real data**: the surviving `source_view/probe.out` holds five blocks, each `Publisher count: 1` with a `/mavros`-namespaced endpoint and its own GID, in the exact field order the Bash identity parser consumes - previously produced only by the focused suite's fake module. `probe.err` is `0` bytes across all `18` runs and the final `pending` is `0` bytes, so the generation was fully consumed. **The race recurred under the batched path**: `2` non-verifying readings, both `/mavros/state`, both `query_rc=0`, both identity-temporarily-unknown, both recovered on attempt two, each discarding its generation and forcing a fresh probe - the consume-and-refresh contract observed live for the first time. Note the mode shift from 04/08's `2` publisher-count-zero readings; both modes were in the 03/08 baseline. **No reduction claim**: `2` readings sits inside the `11`/`3`/`2` flag-off control range and one run cannot separate a modest improvement from ordinary variation. Final verification `85 s` against 04/08's `115 s` is two single samples and yields no timing conclusion. Evidence copied to `~/Desktop/pi_run_evidence/live_dashboard_20260805_163818` and verified `22`/`22` against a Pi-side checksum manifest. No production file, test suite, or flag default changed. Browser-last ordering and the terminal data-plane probe remain unexercised. | 🟡 |
| 07/08/2026 | Workstation-to-FCU command path opened **in simulation only**. ArduPilot SITL was stood up on the workstation and its MAVLink graph verified read-only; no command reached any autopilot, simulated or real, and no code was written. Prerequisites first: `/` re-measured at `95%` with `11G` free against the two-day-old `94%` / `13G`, then fell to `96%` / `9.4G` during the session, so a separate user-run cleanup gate reclaimed `12.6 GB` - largest items `~/.gz/sim/log` `5.6G` (`648` automatic simulator console logs), `~/.npm` `3.3G`, `~/.cache/pip` `3.0G` - reaching `22G` free at `89%` while leaving `~/hailo_artifacts`, `~/venvs`, `~/Desktop/pi_run_evidence` and the `hailo8_ai_sw_suite_2026-07` image untouched. That image was explicitly retained: it holds the Dataflow Compiler that produced `yolo26n_route_a_six_heads.hef`, the Pi holds only the runtime and the compiled HEF, and the installer archive is no longer on disk. Reachability was proven on `IoT IMT Nord Europe` (`github.com` `HTTP 200` in `0.212322s`, `13444775` B/s sustained), so the install ran there and the Pi link stayed up with no switch to `IMT Nord Europe 5G`. A shallow clone of `Rover-4.6.3` at `3fc7011a7d3dc047cbb17d8bd98ee94577d144c6` took `1m01.882s` for `1.2G`. Source review of the prerequisite installer showed `maybe_prompt_user()` returns `0` under `ASSUME_YES`, so `-y` would have installed the STM32 toolchain and appended four lines across `~/.profile` and `~/.bashrc`; it was run without `-y` with `SKIP_AP_GRAPHIC_ENV=1` and `DO_*` opt-outs, and no shell rc write, package removal or submodule re-fetch occurred. `./waf configure --board sitl` then `./waf rover -j4` finished in `2m51.885s` at `1299/1299`, producing `build/sitl/bin/ardurover` (`4939888` bytes) with `ccache` capped at `2 GB`. `sim_vehicle.py -v Rover -f motorboat-skid` reached steady state - `Detected vehicle 1:1`, `Mode MANUAL`, `ArduRover V4.6.3 (3fc7011a)`, `EKF3` active, `1283` parameters received - disarmed throughout. **The day's substantive finding:** SITL assigns `SERVO1_FUNCTION 73` (ThrottleLeft) and `SERVO3_FUNCTION 74` (ThrottleRight), while the real boat records the opposite channel order (`SERVO3`=`73`, `SERVO1`=`74`), so both platforms share the function convention on **swapped channel numbers**; and the measured SITL rail is `1000`/`1500`/`2000` with neutral at mid-scale against the real boat's `800`/`800`/`2200` with neutral at the bottom, while `tools/servo_command_bridge.py` hard-defaults to `1100`/`1500`/`1900` and so matches neither. Because stop is `1500` in simulation and `800` on the boat, a bridge emitting the simulator's neutral at the real vehicle would command substantial thrust while believing it commanded zero. Two constraints carry into Block D: address thrusters by SERVO **function**, never by channel number, and read the PWM rail from live parameters rather than hard-coding one. Block D, the command-ingress contract, was not started and stays design-only. No FCU contact, no arming, no file under `tools/` modified, and both production pins unchanged. **Later the same day, after the day-close commit `6645b29`, a view-only live run was directed with the Pi and control box** (`live_dashboard_workstation_20260807_154942` / `live_dashboard_20260807_154959`). It reached `PI_SOURCE_STACK_READY=PASS`, six-topic arrival and all six rate probes - `/hailo/overlay/image_raw` `7.32 Hz` and the five MAVROS topics at `1.00`-`1.01 Hz` - with `COMMAND_SENTINEL=PASS messages=0; FCU remained observed-disarmed`, `PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=128s elapsed=248s`, and a run-wide thermal peak of `67.2 C` against the `80 C` abort. **It did not close cleanly:** the workstation was stopped before the Pi, `rosbridge.log` records `user interrupted with ctrl-c (SIGINT)`, and the Pi failed closed on `STOP: workstation rosbridge node is not visible from the Pi` after `hold_elapsed=812s`, exiting `status=1 failed_phase=live-hold` with both teardowns `PASS` - so telemetry delivery and view-only posture are proven but **no normal-lifecycle claim** comes from it, and browser-last ordering was again not obtained. The run was flag-off (`MAVROS_SOURCE_PROBE_RUN` count `0`), giving a fourth graph-query control point of `10` non-verifying readings, all `query_rc=0` publisher-count-zero, on `/mavros/imu/data` `5`, `/mavros/rc/in` `3`, `/mavros/battery` `2`. Alongside it, four **view-only** dashboard telemetry improvements landed: new GPS position and GPS horizontal-accuracy readouts, `NavSatStatus` fix codes rendered by name, and `system_status` rendered by `MAV_STATE` name so this vehicle's long-standing `5` now reads `Critical (5)` with a badge instead of a bare integer. A fifth followed at the end of the day: a **live thrust-output readout** and a sixth freshness badge fed from `/mavros/rc/out` (`mavros_msgs/RCOut`), showing raw servo PWM for both thrusters and their difference. It is safe under the live posture because `rc_io` is already in the helper's MAVROS `plugin_allowlist`, `/mavros/rc/out` is **not** one of the helper's five `COMMAND_TOPICS`, and the entry is subscribe-only. Raw PWM is shown with **no conversion to a percentage** - the rail differs between platforms and today proved it must be read, never assumed - and the channel indices follow the real boat (`SERVO3` left, `SERVO1` right), the opposite of SITL. `LIVE_MAVLINK_VIEW_ONLY` remains `true` and no write path was added or enabled; focused suites `31`/`31`. **Finally, the first workstation-to-autopilot command path in this project was exercised - against ArduPilot SITL on the workstation only, never a real autopilot.** Workstation MAVProxy `1.8.74` on `udpin:0.0.0.0:14600` against `sim_vehicle.py` fanned out with an extra `--out=udp:127.0.0.1:14600`, plus an untracked read-only observer on SITL's spare `tcp:127.0.0.1:5762` printing only servo changes. Two mechanisms were checked from source before anything ran: `MAV_CMD_DO_SET_SERVO` **cannot** drive these thrusters, because `AP_ServoRelayEvents::do_set_servo` (`:32-57`) allowlists only `k_none`, `k_manual`, sprayer, gripper and `k_rcin*` functions and returns `false` with `Channel %d is already in use` for anything else - `k_throttleLeft` `73` and `k_throttleRight` `74` are not in that list; and `RC_CHANNELS_OVERRIDE` (`GCS_Common.cpp:3988`) is the path that works, feeding `AP_MotorsUGV`. Channels were read rather than assumed: `RCMAP_ROLL 1`, `RCMAP_PITCH 2`, `RCMAP_THROTTLE 3`, `RCMAP_YAW 4`. `mode MANUAL`, `arm throttle` and `disarm` were all `ACCEPTED`, and RC override produced measured skid-steer output - armed idle `1500`/`1500`; throttle `rc 3 1600` gave `1570`/`1570` (`delta +0`); steering `rc 1 1600` gave `1644`/`1496` (`delta +148`); `rc all 0` returned `1500`/`1500`. The steering step decomposes as mean `(1644+1496)/2 = 1570`, exactly the throttle level, with a pure differential of `±74`, so the mixer is correct and SERVO1 rising while SERVO3 falls is the right turn that `ThrottleLeft` on SERVO1 predicts. **Three consequences:** a symmetric impulse cannot detect a channel swap (`delta` stayed `+0` on the throttle step), RC input PWM is not servo output PWM (`1600` commanded produced `1570`), and - superseding much of the morning's channel-number concern - **command at the RC or higher layer, not the raw servo layer**, because the autopilot resolves SERVO function to physical channel internally, so the SITL-versus-boat swap never reaches the RC path and only affects raw-channel code such as `tools/servo_command_bridge.py`. **Non-claims:** simulator only, no command reached a real autopilot and no real thruster moved; the boat's `800/800/2200` rail with neutral at the bottom means none of these PWM figures transfer; `RCMAP_*` was confirmed for SITL only; and this is not a contract - Block D remains unwritten, the dashboard still contains no FCU command code, and the powered-off, propellers-removed gate plus `ARMING_REQUIRE=1` and the safety switch are untouched. | ✅ |
| 10/08/2026 | The command-ingress contract was closed, implemented as a default-inhibited workstation bridge and exercised end to end against `motorboat-skid` SITL on isolated domain `42`. Live parameters resolved steering/throttle to RC channels `1`/`3` and functions `73`/`74` to `SERVO1`/`SERVO3`; fresh disarmed neutral, normal arm to `ARMED_NEUTRAL`, positive and negative browser-held `ACTIVE` intervals, measured neutral return and accepted normal disarm were obtained. The two recordings show `+0.10`/`0.08` producing servo `1585`/`1485` and `-0.04`/`0.09` producing `1520`/`1559`. The terminal capture missed both active windows, so machine-readable transition capture and helper-owned teardown remain open. Simulator only: no Pi, physical controller or real thruster was involved. | 🟡 |
| 11/08/2026 | The first helper-owned SITL run failed at the Rover-listener gate because `sim_vehicle.py` launched Rover through a display terminal outside the supervisor-owned process group. The runner now starts the pinned Rover binary directly in its run-owned state directory and suppresses the shutdown-frame check when an early failure occurs before bridge startup; focused tests pass, but the corrected runtime is not rerun. A separate guarded physical-FCU pair is now prepared on domain `43` with subnet discovery, isolated from the domain `42` localhost-only SITL graph: the workstation supervises loopback rosbridge/dashboard and emits a servo-mapped bench URL only from fresh `READY_DISARMED` status, while the Pi supervises direct `/dev/ttyAMA0:57600` MAVROS, an isolated T0b read-only probe and the separately gated bounded bridge. Both launch paths pass an explicit expected domain to the shared bridge and reject conflicting helper/process ownership. The existing Pi Hailo/MAVROS helper remains byte-identical and view-only. No Pi/FCU runtime, hardware safety change, arm/disarm, physical command or real thrust occurred; T0a remains the first hardware gate. | 🟡 |
| 17/08/2026 | The guarded command-path implementation and evidence capture work closed red-green, with the landed focused suites at SITL `41`, physical helper `22`, command bridge `26` and capture helper `13`. The full helper-owned `motorboat-skid` run then passed every functional phase, contracted teardown order, final verdict, all ten evidence digests and independent read-only adjudication. A separate powered-down D0 inspection passed connector seating and end-to-end `Pi TXD (GPIO14) -> Cube SERIAL1 RX` continuity, closing T0a without a wiring change. D1 ended before execution: no transfer, deployed check, real-controller probe or T0b artifact occurred. | 🟡 |
| 18/08/2026 | D1 Gate 1 deployed and certified the four-file bundle at `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260818`; exact inventory, sizes, manifest digest, all four member hashes and the helper's `check` passed. The separately approved read-only probe opened `/dev/ttyAMA0:57600` and received an ArduPilot heartbeat, then the MAVROS parameter-list exchange exhausted its retries. The operator stopped at `t+109.81 s`, before the `180 s` deadline; cleanup was clean at `status=130 cleanup_rc=0`. The retained state capture is non-diagnostic because repeated attempts overwrote one path and stderr could enter the YAML. No T0b parameter artifact was produced, no parameter was written, the bridge never started and no real thrust occurred. D1 is closed for the day without retry; T0b, T1 and both T2 tiers remain open. | 🟡 |
| 19/08/2026 | The T0b capture path now retains every attempt as isolated YAML plus a sibling diagnostic log, including diagnostics from the copy writer; the complete physical-helper suite passed `24` cases after the manifest was regenerated, and the helper, tests and manifest landed together at `dc90a8f`. A new five-file Pi deployment at `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819` passed exact inventory, pinned-manifest, `4/4` member verification and the non-actuating helper `check`. Block E was approved but deferred without execution while its safety review remained pending. No controller or Herelink power-up, serial open, parameter write, bridge start or real thrust occurred under Block E. T0b remains open; the unused approval expires at day close, and T1 plus both T2 tiers remain closed. | 🟡 |
| 20/08/2026 | The T0b probe graph was restricted to localhost, its `24`-case suite passed, revision `f8e440a` was deployed once to the new dated root, and the non-actuating Pi `check` passed. A powered receive-only UART diagnostic then captured `23868` bytes and `30` valid disarmed heartbeats from `1.1` with zero transmitted bytes. The final full probe reached `connected: true`, `armed: false`, `mode: MANUAL` and a passing hardware-safety check, but all automatic parameter-list attempts and the explicit forced pull received no parameter response. A final duplex isolation captured `18` more valid disarmed heartbeats and transmitted exactly one PING plus one `SYSID_THISMAV` read request, audited as `53` bytes with no state-changing message; neither received a response. Cleanup and copy-back passed, no `41`-parameter or mapping/rail artifact was created, and no parameter write, bridge, mode, arm, RC, motor or thrust action occurred. T0b remains open; T1's separately approved `BRD_SER1_RTSCTS` change is the next decision point, while both T2 tiers remain closed. The operator confirmed the FCU/control electronics and Herelink off with propulsion isolated, propellers removed and the hull restrained, closing the physical day. | 🟡 |
| 21/08/2026 | Revision `2600ea4` was deployed to a new certified Pi root for the separately approved `BRD_SER1_RTSCTS` experiment and guarded run attempts. Candidate `0` did not restore parameter request/response in the connected/disarmed run. The armed-start run stopped at the disarmed-state gate before the parameter pull, bridge or command publisher started. Both helpers cleaned up with `status=1 cleanup_rc=0`; the evidence archive copied back and verified; and no RC override, motor command or thrust command was issued by the repository pipeline. `BRD_SER1_RTSCTS=Auto (2)` was restored and read back. The operator then confirmed the Pi, FCU/autopilot, control electronics and Herelink off with propulsion isolated, propellers removed and the hull restrained. T0b remains open, neither T2 tier earned acceptance and no physical approval carries forward. | 🟡 |
| 25/08/2026 | A Pi-local MAVProxy session on `/dev/ttyAMA0:57600` received accepted FCU acknowledgements for arm and disarm, ending explicitly `DISARMED`. The arm request was issued after the capture had already shown `ARMED`, so it proves command acceptance but not a fresh arm transition. This is the first direct state-changing command/ACK proof on the endpoint and supersedes the generic receive-only label. No parameter response, workstation-originated request, RC override, non-neutral servo output, repository bridge, dashboard or VRX runtime was captured. The professor's workstation-path fix is operator-reported pending a correlated trace. The next-day target is full-scale FCU-to-VRX integration with real electronics active and propellers removed, behind fresh 26/08 certification and approvals. | 🟡 |
| 26/08/2026 | Real-FCU Test A passed on the guarded dashboard command path. A hash-pinned `986`-parameter snapshot with temporary `RC_OVERRIDE_TIME=0.5` resolved `RC1` steering, `RC3` throttle, left `SERVO3`, right `SERVO1` and both rails `800/800/2200`. Both supervisors reached their READY markers. The retained dashboard recording captured `ARMED_NEUTRAL` at requested `0.00/0.00`, RC `1515/1515` and output `800/800 us`; Hold to Apply at steering `0.05` and throttle `0.04` changed measured RC to `1564/1470` and output to `911/800 us`; release restored requested zero and `800/800 us`. Propellers were removed and propulsion was isolated, so this is real-FCU command/output-feedback evidence, not physical thrust. Both helpers ended connected and disarmed, exchanged the stop marker, completed ordered teardown and exited `status=0 cleanup_rc=0`. Pi evidence was copied to `/home/ghostzero/Desktop/pi_run_evidence/test_a_20260826/real_fcu_digital_twin_pi_20260826_201051`; the matching workstation run is `/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260826_200922`. Herelink-to-VRX Test B remains **NOT RUN** and is deferred to 27/08/2026 behind fresh physical declarations and approval. Its W2 observer currently requests `/wamv/pose`, while the live VRX bridge publishes `/model/wamv/pose`; the retained observer stayed `WAIT_DATA`, so that contract must be repaired and proven offline first. The temporary parameter setting still requires verified rollback to `3.0` after Test B or before any other operation. **Forward correction 27/08/2026:** the pose-topic half of this row is withdrawn. `/model/wamv/pose` is the Gazebo transport name; `vrx_gz` bridges it to relative `pose` inside `PushRosNamespace('wamv')`, so the ROS topic is `/wamv/pose` and the supervisor was already correct. The recorder's `base_link` child-frame filter matched nothing, which is what held the observer at `WAIT_DATA`. | 🟡 |
| 27/08/2026 | The workstation-only VRX frame proof captured eight transforms from `/wamv/pose`; `sydney_regatta -> wamv` was the only world-parented transform and no child frame ended in `base_link`, directly validating the repaired world-frame selector. The exact W2 launch stopped cleanly with domain `77` empty afterward. The complete supervised SITL acceptance then passed on clean revision `147efe0270b3357a17ca6489c96d1722cd55c6f8` in `/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`, including safety-off, disabled frame, arm, positive and negative demand, neutral release, E-Stop and disarm; independent adjudication checked ten evidence hashes and ended `SITL_ADJUDICATION=PASS`. A fresh MAVFTP snapshot then retained `986` parameters with `RC_OVERRIDE_TIME=0.5`, SHA-256 `3347835b8482c9fa00c54e9d53586d2beb1db87fabd92adfe599259a9c346900`. The snapshot-backed T0b probe passed `41` selected reads, connected/disarmed state and hardware safety ON with `writes=none bridge=not-started`; its copied evidence is `/home/ghostzero/Desktop/pi_run_evidence/t0b_probe_20260827_174820`. This closes T0b. A later offline audit found that the required disarmed all-stream limit measurement had no clean W1 mode and that configured live selectors contaminated W1's default certification fixture. A default-off disarmed recorder mode, strict JSONL measurement summarizer and environment-isolated certification tests now pass offline, but these source changes are not landed and have not run live. Test B is explicitly approved but remains **NOT RUN**; W2 still requires a clean pushed revision, the disarmed measurement and limits remain outstanding, and exact-revision SITL acceptance must be rerun after the repair lands or explicitly superseded. `RC_OVERRIDE_TIME=0.5` remains temporary until Test B completes or is abandoned, then must be restored to `3.0` with retained readback and snapshot. **Forward update:** the repairs landed as `aa4a07a` and `1c1dff5`. A full live disarmed measurement then passed with all eight streams: maximum Pi/VRX gaps `1.039521457 s` / `0.291961215 s`, PWM skew `223.019194 ms`, thrust delay `9.633272 ms` and stationary drift `0.081450536 m`. Explicit armed limits are now recorded, Pi evidence is copied under `/home/ghostzero/Desktop/pi_run_evidence/test_b_measurement_20260827_185227`, and Pi, W2 and W1 teardowns passed. This closes the measurement and limit-selection items only. Test B remains **NOT RUN**; current-revision SITL acceptance or explicit supersession and a fresh physical declaration still gate the armed phase. **Armed-attempt update:** the operator superseded the SITL rerun for `eb9a337` and ran Test B. The retained record captured `SERVO3/SERVO1=2200/800`, mapped thrust `800.0/0.0 N` and `2.47946 m` of VRX motion, but the Pi then aborted on `ARMED_WINDOW_DEADLINE`; W1 and W2 recorded terminal stale-stream aborts and no recorder captured final connected/disarmed neutral hardware-safe state. Test B is therefore **ATTEMPTED - FAILED / NOT ACCEPTED**. The copied Pi evidence is `/home/ghostzero/Desktop/pi_run_evidence/test_b_armed_failed_20260827_192234`. An explicit paired-zero retry mode now disables only the armed and outer runtime deadlines, defaults the Pi window to resizable, retains all freshness, disconnect, command, rail, thermal and final-restoration gates, and changes completed-run teardown to W2, W1, Pi. This repair is offline-only and not yet published or rerun; it requires fresh exact-revision SITL acceptance or explicit supersession, a fresh declaration and separate approval. **Later paired-zero update:** the repair was published, then clean revision `550b992` reached its disarmed baseline with both duration deadlines disabled but never armed. P1 failed on three false zero-publisher graph snapshots for live `/mavros/global_position/raw/fix` data; retained NavSatFix and W1 `4.00 Hz` evidence rule out stream loss. P1, W2 and W1 cleaned up, but Test B remains **ATTEMPTED - FAILED / NOT FORMALLY ACCEPTED**. **EOD repair:** the existing bounded six-topic `rclpy` source view is now default `1`, preserving exact `/mavros` identity checks, while W1 child-exit reporting is one-shot. Focused suites pass; the same direct W1, W2, P1 retry remains for 28/08/2026. | 🟡 |
| 28/08/2026 | Test B demonstrated functional Herelink-to-VRX motion on the repaired W1/W2/P1 path but was externally interrupted and remains not formally accepted. A later real-FCU dashboard run used a fresh `986`-parameter snapshot (`61406eee10c253daabfef4462ce0b3661be30b599bd7736909c5bff4e4b4943d`), reached both READY markers and ended connected/disarmed with ordered `status=0 cleanup_rc=0` teardown. The operator corrected the active-interval state to propellers fitted and propulsion available, making the launch assertion `REAL_FCU_PROPELLERS_REMOVED=1` inaccurate for that interval. The helpers reported nominal `tier=T2b authority=demand-enabled` software markers and clean teardown, but the run did not satisfy T2b's propellers-removed gate and had no separate T3a approval, dedicated guarding or exclusion-zone evidence. The operator reported one-sided rotation for some steering-heavy requests plus no rotation at `0.00/0.12`, exact steering `+/-0.20`, or `0.05/0.04`. The retained files contain only neutral `1515/1515` RC and `800/800` output, so those active observations are not machine-correlated and establish no ESC threshold. Exact `+/-0.20` is independently invalid because `float32` transport places it just outside the bridge's exact bound; that code defect remains open. Classification: **ENHANCED TEST A - PROPS-FITTED FUNCTIONAL OBSERVATION; NOT T2B OR T3A ACCEPTANCE**. The approved rollback captured live `RC_OVERRIDE_TIME` readbacks `0.5 -> 3.0`, retained a `986`-parameter snapshot with SHA-256 `a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`, copied it to `/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828`, and left `/dev/ttyAMA0` free. | 🟡 |
| 31/08/2026 | The full supervised SITL acceptance and independent adjudication passed on clean revision `3ca4c9bd16414d37506b62ce9fa5b8dad55a3719` in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_150946`. Adjudication checked ten hashes, the control cross-check, exact stop order, teardown and free host ports/processes. Afterward, the bridge's exact `+/-0.20` float32 steering defect and the equivalent defect at legal tunable throttle maxima were reproduced red. The repair normalizes only the exact float32 encoding of each configured command endpoint without raising the configured `0.20` steering or `0.12` throttle authority; adjacent and materially over-limit values plus negative throttle remain rejected. The focused suite passes `36` tests and the bundle manifest is regenerated. Source tracing confirms one paired dashboard command and one paired RC override, while ArduRover's skid mixer uses throttle plus/minus steering. The measured `0.05/0.04 -> 911/800 us` result is consistent with a steering-heavy mixed request, not a missing second command. The straight-throttle ESC start threshold remains unmeasured, so no throttle-authority or `MOT_THR_MIN` change was made. Because the bridge changed after the pass, `3ca4c9b` remains valid exact-revision evidence but current-source SITL was reopened for the repaired bytes. **Current-source closure:** the complete supervised acceptance and independent adjudication then passed again on clean revision `bba195b19a0f06a874bfbcbcbbd1621524cbce60` in `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839`; the retained adjudication log is `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log`. It checked all ten hashes, the control cross-check, exact stop order, teardown, governed ports free and governed process patterns absent before ending `SITL_ADJUDICATION=PASS`. This closes current-source SITL for the repaired runtime path. No Pi, real FCU or propulsion hardware participated and no hardware approval carries forward; the regenerated bundle still requires a separately verified transfer and checksum before Pi use. **Pi deployment closure:** the regenerated bundle was then installed at `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260831_bba195b`. Its exact five-file inventory, manifest digest and all four governed member hashes passed, and the non-actuating helper check ended `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The verified copy-back is `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260831_bba195b`. This closes only bundle transfer/checksum certification; no probe, MAVROS or bridge runtime, parameter write, arm, propulsion action or hardware approval occurred. | 🟡 |
| 31/08/2026 | A separately approved workstation-only change prepared opt-in ESC-onset evidence capture without starting hardware. Normal T2a/T2b recording remains the original three-topic subscriber contract; `t2b --esc-threshold-calibration` adds raw `/mavros/rc/in` and `/mavros/rc/out` plus typed per-side `stopped`, `started` or terminal `not-observed` observations. Each annotation requires five correlated streams, an enabled straight positive demand, `ACTIVE` fresh bridge feedback, armed `MANUAL` FCU state, raw/status channel agreement, fast-stream age no more than `1 s` and state age no more than `2.5 s`. A passing per-side bracket requires a later higher request and strictly higher delivered servo PWM than the highest stopped-output PWM; `not-observed` is valid only at the governed `0.12` maximum. The full T2b phase sequence, E-Stop and final connected/disarmed state remain mandatory, and the helper remains subscriber-only. Focused coverage passes `21` tests and the complete offline gate passes. Classification: **OFFLINE CAPTURE PREPARATION / NOT RUN**. Current Pi modes still require propulsion isolated and no T3a props-fitted runtime, fitted-propeller gate, guarding evidence or exclusion-zone evidence exists. No threshold, parameter, FCU, ESC, motor or propeller action occurred; `RC_OVERRIDE_TIME` remains `3.0`; no Pi bundle member changed; and the certified `bba195b` deployment and exact-revision SITL evidence remain valid. | 🟡 |
| 01/09/2026 | A separately approved workstation-only change implemented a distinct props-fitted T3a contract without starting hardware. Pi mode `run-t3a` remains demand-enabled at the existing `0.20` steering and `0.12` throttle bounds and fails closed unless T0a is complete, T0b is approved, and T3a approval, propellers fitted, hull restraint, mechanical guarding, a clear exclusion zone, propulsion isolation at launch, disarmed start and hardware safety ON are declared; T2/T3 approvals and removed/fitted-propeller declarations are mutually exclusive. The operator enables propulsion under those conditions and enters an exact retained confirmation; the resulting closeout obligation survives confirmation errors and evidence-write failures. Bounded closeout handling remains fail-closed under missing, invalid, timed-out, `INT` or `TERM` input while still proceeding to final-state capture and child stops; the recorded default timeout is `300 s`. The workstation `t3a --esc-threshold-calibration` helper is a separate subscriber-only recorder with five ROS subscriptions, typed operator observations from stdin and no write path. It binds evidence to the T3a bridge identity and preserves the existing five-stream freshness, per-side PWM bracket, E-Stop and final-disarm requirements. Focused verification passes `26` recorder tests, `42` Pi-helper cases and the regenerated `4/4` bundle manifest. Classification: **OFFLINE T3A IMPLEMENTATION / NOT RUN / NOT DEPLOYED**. No serial endpoint, FCU, parameter, bridge runtime, arm, ESC, motor or propeller action occurred; declarations are operator attestations rather than machine proof of guarding; and the certified `20260831_bba195b` Pi root does not contain these bytes. | 🟡 |
| 01/09/2026 | **T3a Block D deployment closure:** clean published revision `025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba` was transferred to the new Pi root `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c`. Its exact five-file inventory, executable helpers, manifest digest `11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d` and all four governed member hashes passed. The helper then ran only its non-actuating `check` and emitted `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The copied-back bundle and log were independently reverified at `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`. Classification advances only to **DEPLOYED / CERTIFIED / NOT RUN**. No probe, MAVROS or bridge runtime, parameter write, arm, propulsion action or T3a acceptance occurred, and this grants no Block E authority. | 🟡 |
| 01/09/2026 | **T3a Block E live result:** published revision `507bfcfa9d1eed0733840188d99905d49c691430` reached Pi and W1 READY, then closed connected/disarmed with the workstation stop marker, `REAL_FCU_T3A_SAFE_CLOSEOUT=PASS` and `status=0 cleanup_rc=0` on both supervisors. Retained Pi evidence is `/home/ghostzero/Desktop/pi_run_evidence/t3a_esc_threshold_20260901_193548`; W1 is `/home/ghostzero/Desktop/real_fcu_digital_twin_workstation_20260901_193313`; capture is `/home/ghostzero/Desktop/real_fcu_capture_t3a_esc_threshold_20260901_193327`. The recorder verdict is `pass:false` over `33,598` events with invalid/binding status evidence and incomplete left/right annotations. Machine output reached `954/954 us` at straight `0.12`, `994/913 us` at `+0.03/0.12` and `913/994 us` at `-0.03/0.12`. The operator-reported onset near `990 us` is consistent with a driven-side interval `(980, 994] us`, but is not an accepted exact threshold. Classification: **FUNCTIONAL PROPS-FITTED RUN / CLEAN LIFECYCLE; CALIBRATION FAILED / NOT ACCEPTED**. `RC_OVERRIDE_TIME=0.5` remains temporary; no 01/09 rollback artifact exists. | 🟡 |
| 01/09/2026 | **Integrated Hailo/real-FCU/VRX showcase worktree:** one actuator path now routes Dashboard or Herelink ownership through the real FCU and exact measured `/mavros/rc/out` into forward-only VRX, while validated loopback telemetry returns actual VRX pose and left/right thrust to the dashboard. Stock-COCO `person` or required detector-feed loss raises E-Stop; fresh clear alone never resumes motion. Explicit neutral-gated Reset E-Stop and Dashboard/Herelink ownership handover are repeatable without restarting the stack, with E-Stop retaining priority. Detection input is bound to exactly one resolved `/hailo_person_stop_bridge`; stale bridge status disables and blocks Reset/Owner publications. Focused red/green verification passes person monitor `37`, helper `55` and the full dashboard Node suite `90/90`, with unchanged bridge/W2/capture/servo results retained. Classification: **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN**. Tomorrow requires a new landed bundle and one separately approved integrated run; no live result is claimed from these bytes. | 🟡 |
| 01/09/2026 | **Forward safety correction to the integrated worktree:** firmware source review established that ArduPilot reports an active RC override through `RC_CHANNELS`, so `/mavros/rc/in` cannot independently prove physical Herelink stick neutrality while the bridge owns the channels. The earlier neutral-RC-wait claim is superseded. The existing Dashboard ownership button now sends the one-shot `HERELINK_STICKS_NEUTRAL` operator attestation; raw `HERELINK` is rejected. Acceptance requires the single bound rosbridge publisher, the current connected/armed/authorized `MANUAL` epoch, fresh valid feedback and neutral measured `/mavros/rc/out`. Three trim frames precede three release frames; non-neutral measured output during release relatches E-Stop and reasserts trim. Disarm/disconnect revokes ownership. E-Stop reset now uses owner-matched String tokens and does not auto-prime through delayed browser neutral frames. Focused results are bridge `54`, capture `37` and dashboard `91/91`. Classification remains **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN**; no live evidence applies to these bytes. | 🟡 |
| 01/09/2026 | **Fresh-release and explicit-reprime correction:** the first handover correction could reuse one cached neutral RCOut sample across all release ticks. The bridge now advances only on callback-delivered RCOut generations: a newer neutral generation is required before the first release, between each of three release frames and after the final release; a newly observed non-neutral output latches E-Stop, while missing new evidence leaves the handover pending. Dashboard reclaim now emits no Joy prime from either the ownership action or the returned status transition, and its button explicitly requires `Neutral Now` before Dashboard demand. Bridge `54`, capture `37` and dashboard `91/91` pass. Classification remains **WORKTREE IMPLEMENTATION / NOT COMMITTED / NOT DEPLOYED / NOT RUN**; no existing bundle or live evidence contains these bytes. | 🟡 |
| 01/09/2026 | **Forward correction - publication status:** the three 01/09/2026 showcase entries above classify their bytes as **NOT COMMITTED**. Those bytes landed as `da6627e21b9019eaff95b36d407f2439da24e156` (`feat(showcase): integrate Hailo stop and FCU-VRX handover`, 22 files, `+6041/-200`) with `HEAD == origin/main`, divergence `0/0` and a clean worktree. The corrected classification for all three is **COMMITTED `da6627e` / NOT DEPLOYED / NOT RUN**. The previously certified Pi bundle does not contain these bytes, so a new `da6627e`-named bundle transfer and non-actuating certification remain required before any run. **Revision correction:** the required bundle is no longer `da6627e`-named. The hardware-safety badge changed `tools/real_fcu_rc_command_bridge.py` after that commit, so the manifest and the deployed bundle must be named for the revision that lands this change. | 🟡 |
| 02/09/2026 | **Workstation preflight test isolation:** showcase-mode `REAL_FCU_HAILO_PERSON_STOP=1 bash tools/real_fcu_digital_twin_workstation.sh check` failed at `12236b5` with `run-t2a readiness started requiring the T3a capture node`. The cause was a non-hermetic test suite, not a production-control fault: the helpers take their `REAL_FCU_*` contract from the ambient environment, read at source time for the selectors and at gate execution for the physical declarations, so the operator's ambient showcase flag reconfigured an ordinary T2a readiness fixture. `tools/test_real_fcu_digital_twin_helpers.sh` now scrubs the whole `REAL_FCU_*` family once before any case, which also closes the same leak for the declaration flags, where it could have produced a false green instead of a visible failure. Five cases were added, `55` to `60`: one bound to the suite-entry scrub call through a re-execution probe, one on the scrub function, one on the polluted T2a fixture, a control asserting the unscrubbed fixture still fails so the isolation cases cannot rot into vacuous passes, and one requiring the final `PASS cases=` marker to survive a polluted nested run. Both internal re-entry modes are reserved arguments rather than environment variables, after review found that an environment-triggered probe was itself an ambient bypass: it ended the suite before any case ran while still returning success to `rfcu_ws_check`, which reads only the exit code. Production helpers are untouched and `rfcu_ws_static_preflight` still validates the ambient flag. Clean and polluted shells both give helper `60`, W2 `30`, bridge `62`, capture `37`, dashboard `96/96`, person monitor `37`, bundle `4/4`. Workstation-only: no Pi, FCU, ROS service, VRX, browser or hardware runtime was started. Separately, `tools/real_fcu_digital_twin_workstation.sh:155` depends on `set -e` rather than being structurally fail-closed: `rfcu_ws_fail` returns instead of exiting, so under any caller that suppresses `set -e` the function continues past a failed `ss` and returns success. On today's plain call path from `rfcu_ws_static_preflight` it does abort; reached from an `if` it reproduces `PORT_CHECK_FAIL_OPEN=YES`. The PASS marker also hardcodes `ports=8002,9090` and omits port `8080`, which is checked in Hailo mode. Both are pre-existing, outside today's authorised scope and not repaired here, so the workstation preflight is not yet structurally fail-closed. | 🟡 |
| 02/09/2026 | **Workstation preflight guards made structurally fail-closed:** the two faults recorded in the isolation entry above are repaired. `rfcu_ws_fail` now exits instead of returning, so all `48` guards that end in an or-branch to it are fail-closed regardless of caller context rather than only while `set -e` is in force; patching the one reported call site would have left the other `47` carrying the same latent fault. Blast radius was checked first: eleven functions call it, none is consumed conditionally, the EXIT trap never calls it, and no other file sources the helper. `rfcu_ws_checked_ports` is now the single source of truth for the inspected ports, read by both the rejection loop and the PASS marker, so showcase mode now reports `ports=8002,8080,9090` instead of hardcoding `ports=8002,9090`. Six cases added, `60` to `66`, each proved against a mutant: a returning `rfcu_ws_fail`, a hardcoded marker list, a dropped `8080` and a removed empty-list guard are all caught. The last covers a hole the fix itself introduced, where `mapfile` reading through a process substitution hid a failing producer and would have inspected no ports at all. Making the helper exit also exposed three command substitutions in the test suite that became silent aborts, and one new assertion written as an and-branch to `fail_test` that aborted when its grep correctly found nothing - the same `set -e` and-or shape this day is about. All four were corrected, and the nested-marker case moved last so a real defect is reported by its own assertion rather than second-hand. Preflight passes both modes; helper `66`, W2 `30`, SITL runner `41`, bridge `62`, capture `37`, dashboard `96/96`, person monitor `37`, bundle `4/4`. Workstation-only: nothing started. | 🟡 |
| 02/09/2026 | **Abort-helper sweep and FCU-to-VRX guards:** with the workstation helper repaired, every abort helper in the repository was checked rather than assumed. `fcuvrx_fail` carried the same fault and is fixed: it returned while `55` of its guards have code after them inside their own function, so a failed PWM-rail or ROS-environment check fell through to the later checks; one site already carried a hand-applied `return` workaround, removed as redundant. `adj_fail` and the health-check `fail` are accumulators by design and were left alone, and the SITL runner already aborts directly. Editing the supervisor made its checksum pin stale, which the suite caught; the runbook pin was updated and no other surface pins that file. The check marker also stated its suite sizes as literals, accurate but unverified, so a final assertion now compares both against what the suites report - it caught the drift its own change created and the marker reads `shell_cases=32`. Two cases added, `30` to `32`, both proved load-bearing against mutants. Separately `plan/test/test_person_stop_monitor.py:17` had a `flake8 I101` import-order failure predating today; `plan` now reports `67 passed, 1 skipped` with no failures. `rfcu_pi_fail` carries the same fault and was deliberately not changed: it is the thruster-driving Pi runtime and a bundle member, so it needs an explicit decision. Workstation-only: nothing started. | 🟡 |
| 02/09/2026 | **Pi runtime guards made fail-closed, on explicit approval:** `rfcu_pi_fail` carried the largest instance of the day's fault - `123` guards had code after them inside their own function, `13` in `rfcu_pi_run` itself, so a failed readiness or safety gate could fall through to the next run step instead of stopping the run. It now exits. Because this is the thruster-driving runtime the change was cleared first: `23` callers, none consumed conditionally, no call site inside a subshell where `exit` would only leave the subshell, and the EXIT trap installed before any child starts so `rfcu_pi_cleanup` still runs the T3a safe-closeout gate and the final connected/disarmed capture. Cleanup runs under `set +e`, which made the reachability check essential rather than optional: transitively it reaches `15` functions, the INT and TERM handlers `4` and `3`, and none of the `22` calls `rfcu_pi_fail`, so a guard cannot abort the closeout. The bundle manifest was regenerated; the Pi entry moved from `5c6fca19` to `43a4775f` and the other three are unchanged. Three cases added, `66` to `69`, the third a standing guard on that clearance. Separately, the `does not return` probes added earlier today were vacuous in all three suites - sourcing a helper enables `set -e`, under which a returning failure aborts the probe before its marker prints, so they passed against returning implementations; all three now run `set +e` and were re-proved against mutants. Workstation-only: nothing started, and the change is not validated on the Pi. | 🟡 |
| 02/09/2026 | **Hardware-safety badge verified in the browser:** first browser-side proof of the badge added on 01/09/2026, run against `0f2f5ca` with rosbridge on `9090` and the dashboard on `8002`, both loopback, on domain `43`. Workstation only: no Pi, FCU, MAVROS or simulator. Bridge status was driven synthetically on `/command_ingress/status` at `5` Hz, a rate the `500` ms freshness window requires. All five behaviours matched: `ENGAGED (motor output suppressed)` clear, `RELEASED (suppression off)` critical, and a fall back to `Unknown (stale)` on publisher silence, on malformed JSON with Loop State reading `Invalid bridge status`, and on rosbridge disconnect. The rosbridge log records `Subscribed to /command_ingress/status` for both page loads, confirming the reading is unconditional rather than gated by `enable_fcu_bench_control=1`. Teardown clean: services stopped, ports released, no stray process, worktree unchanged. This proves the rendering and staleness paths only; `hardware_safety_state()` against a real switch stays unexercised, since every reading was a string chosen by the publisher. | 🟡 |
| 02/09/2026 | **Current-revision SITL acceptance passed:** clean published revision `0ed5525` ran the full simulator acceptance on the workstation with no Pi, FCU or physical hardware. The runner's pins passed first - ArduPilot `3fc7011a`, Rover binary `4939888` bytes, `HEAD` descending from baseline `d911f8a7` - then SITL `motorboat-skid`, MAVProxy, MAVROS at `1283` parameters `disarmed`/`MANUAL`, the command bridge and the dashboard ran the sequence through three one-shot operator gates and browser-driven positive, release, negative and latched E-Stop phases. The runner's own `SITL_VERDICT=PASS` was not taken as the result: `tools/sitl_digital_twin_adjudicate.sh` was run separately and returned `SITL_ADJUDICATION=PASS` with no `FAIL` line - nine evidence phases, `verdict.json` `session_complete` with `missing: []`, disarm-release and shutdown frames `3` each, stop order `dashboard,rosbridge,bridge,evidence,mavros,mavproxy,sitl`, five ports free and twelve process names absent. Teardown was checked directly beforehand so the clean result is not self-graded. Supervisor exited `status=0 failed_phase=none cleanup_rc=0 finalize_rc=0`. This closes the outstanding workstation-only gap; no accepted SITL result previously covered the current bytes. Two limits are explicit: the guard resolved `left=SERVO1 right=SERVO3` from the simulator's own parameters, the reverse of the boat, so this is not evidence for the boat's channel assignment; and SITL runs the command bridge rather than the Pi runtime, so the `123` fail-closed Pi guards stay verified offline only. Evidence root `/home/ghostzero/Desktop/sitl_digital_twin_20260902_041033`. | 🟡 |
| TBD | Complete real-hardware deployment acceptance (Pi 5 target; bounded read-only Hailo/MAVROS dashboard proven 17/07/2026; lifecycle, endurance, low-level CCU, and write-path gates remain open) | 🔜 |
| TBD | Coverage Planning | ⏸️ |

---

## 🎯 Next Priorities

1. **Live-dashboard graph-query hardening (05/08/2026 update)**:
   the two 24/07 failures are confirmed separate, and **two 03/08 live runs confirmed the
   recurrence** - a fresh daemonless `ros2 topic info --verbose` process can return a
   successful but transiently incomplete graph snapshot. That makes `184228` strongly
   consistent with a confirmed mechanism rather than retroactively proven, leaves the lower
   DDS/RMW/network trigger unidentified, and leaves `175832` separate and unresolved. More
   retries or a wider spin time are mitigation, not a fix, and `ros2cli/node/direct.py` always
   spins the full requested duration. The selected correctness fix is a run-owned participant
   that spins and accumulates discovery before reading endpoints, mirroring that spin behaviour
   once per phase instead of once per topic query.
   The single-participant design - one bounded, run-owned graph participant answering all five
   source topics from a single accumulated discovery view while preserving endpoint GID and
   node identity, holding no daemon state between phases, and leaving the fail-closed deadlines
   and verdict in the helper - is implemented behind a flag that is off by default and was
   **exercised live for the first time on 05/08/2026 with a feasibility PASS at shipped
   defaults**: `18` probe runs all `OK`, one participant serving five topics per run, window
   and final verification intact, both supervisors `status=0`. The race recurred in that run,
   so feasibility is not a demonstrated fix.
   One probe run serves a clean phase; because each topic entry is consumed once and each new
   generation replaces the previous one atomically, a phase in which every topic must be
   re-read repeatedly costs up to `1 + (2 * 5)` runs, so "one participant per phase" describes
   the clean path only. Red-first offline verification is complete: every defect case was
   observed failing before the change and both focused suites are green after it. A later live
   comparison cannot be settled by three runs against the 03/08 baseline: per-run flag-off control
   counts are now `11`, `3` and `2`, so any reduction inside that range is not evidence of a fix.
   **07/08/2026 control point:** a fourth flag-off run (`live_dashboard_20260807_154959`, with
   `MAVROS_SOURCE_PROBE_RUN` count `0`) produced `10` non-verifying readings - all `query_rc=0`
   with `verdict=publisher count 0`, distributed `/mavros/imu/data` `5`, `/mavros/rc/in` `3`,
   `/mavros/battery` `2`, and none reaching `attempt=3`. The control series is now `11`, `3`,
   `2`, `10`. This is 04/08's publisher-count-zero mode rather than 05/08's identity-unknown
   mode, and the widened range reinforces the conclusion above rather than weakening it.
2. **Live dashboard outbound command design path**:
   design the next safe write-protocol contract now that Pi-window diagnostics have been
   trimmed and normal Pi-local display is preserved. Define exact payload, recipient,
   transport, rate/QoS, acknowledgement, timeout, and failure semantics before any
   enabled-write implementation. A Pi-side ROS application and a low-level control
   box/FCU are different safety targets.
   Keep `LIVE_MAVLINK_VIEW_ONLY=true` until a separately approved outbound contract
   exists; no actuator, arming, mode, thrust, mission, or direct serial/MAVLink write is
   implied.
   **Structural decision taken 05/08/2026:** an outbound command path belongs in a separate
   bridge service or tool, **not** as an edit to `tools/pi_live_hailo_mavlink_dashboard.sh`.
   That helper is deliberately view-only and rejects command services, unexpected command
   subscribers, and monitored command messages as a hard safety posture; weakening a proven
   boundary to add a write path is not an acceptable route. The agreed order of work is
   simulation first - ArduPilot SITL on the **workstation**, not the Pi - then verification of
   the simulator MAVLink graph, then a small isolated command-ingress bridge with explicit
   dead-man and safety checks. Helper integration is revisited only after that.
   **07/08/2026 progress:** the first two steps of that order are done. ArduPilot SITL is built
   and running on the workstation (`Rover-4.6.3` at `3fc7011a`, `build/sitl/bin/ardurover`,
   frame `motorboat-skid`), and its MAVLink graph is verified read-only - master
   `tcp:127.0.0.1:5760`, MAVProxy rebroadcast `127.0.0.1:14550`, simulator interface
   `127.0.0.1:5501`. No command was sent, the vehicle stayed disarmed, and no code was written.
   Verification produced two binding inputs for the contract. First, SITL and the real boat
   assign the same throttle **functions** (`73` left, `74` right) to **opposite channel
   numbers**, so any design that addresses a thruster by channel number is correct on exactly
   one of the two platforms; the contract must key on function. Second, the PWM rails differ in
   kind and not only in value - SITL measured `1000`/`1500`/`2000` with neutral mid-scale, the
   real boat `800`/`800`/`2200` with neutral at the bottom, and `tools/servo_command_bridge.py`
   defaulting to `1100`/`1500`/`1900`, which matches neither. A bridge emitting the simulator's
   neutral at the real vehicle would command substantial thrust while believing it commanded
   zero, so the rail must be read from live parameters and never hard-coded. **10/08/2026:** the
   command-ingress contract is closed and a default-inhibited workstation implementation now
   connects the browser's paired `/command_ingress/rc_axes` demand to MAVROS RC override. The
   bridge resolves `RCMAP_*`, `RC<n>_*`, `SERVO*_FUNCTION` and both servo rails from live
   parameters, reports independently measured `/mavros/rc/in` and `/mavros/rc/out` feedback, and
   neutralises on command loss, E-Stop and shutdown. It cannot arm, disarm, change mode or write
   parameters.

   A clean `motorboat-skid` SITL run then exercised that implementation on isolated domain `42`.
   The guard resolved steering/throttle to RC channels `1`/`3` and functions `73`/`74` to
   `SERVO1`/`SERVO3`; safety-off produced fresh disarmed neutral feedback, normal arming reached
   `ARMED_NEUTRAL`, and two recordings show the browser reaching `ACTIVE`. A `+0.10` steering,
   `0.08` throttle demand produced measured RC `1577`/`1567` and servo `1585`/`1485`; a `-0.04`,
   `0.09` demand produced RC `1452`/`1572` and servo `1520`/`1559`. Both returned to measured
   `1500`/`1500`, and normal disarm was acknowledged `ACCEPTED`. The simultaneous terminal status
   capture missed the active intervals and therefore proves neutral stability only. Helper-owned
   lifecycle integration and a machine-readable active capture remain open. This is SITL evidence
   only: no Pi, physical controller or real thruster was involved, and physical acceptance remains
   unstarted.

   **17/08/2026 to 20/08/2026 progress:** the helper-owned simulator lifecycle and
   independent adjudication pass, powered-down continuity closed T0a, and the
   first T0b probe from the certified 18/08 Pi deployment received an FCU
   heartbeat. Its parameter-list exchange did not complete, so the two
   non-diagnostic capture behaviours were repaired and covered before a new
   dated bundle was deployed and accepted by `check` on 19/08/2026. Block E did
   not run. On 20/08/2026, the safety audit identified graph-visible state-change
   services in the two T0b plugins; the standalone probe is now localhost-only,
   its regression and regenerated manifest pass the `24`-case suite, and the
   workstation-connected run paths remain subnet-visible. The corrected bundle
   is not deployed, so live function/channel/rail evidence remains missing and
   every T2 session remains blocked. The next physical work is a separately
   approved deployment and fresh certification before any T0b retry, not T1 or
   a thrust session.

   **26/08/2026 supersession** (superseded in part; see the 27/08/2026 forward correction at the end of this entry): the current helper-owned SITL acceptance passed,
   a hash-pinned live snapshot supplied the real `RC1`/`RC3`,
   `SERVO3`/`SERVO1` and `800/800/2200` mapping, and the guarded real-FCU Test A
   passed. The dashboard's `0.05` steering and `0.04` throttle request changed
   measured RC input to `1564/1470 us` and output to `911/800 us`; release
   restored requested zero and `800/800 us`. Both supervisors finished
   connected/disarmed and exited cleanly. This closes the bounded
   dashboard-to-real-FCU command/output-feedback test only. Propulsion was
   isolated, Herelink-to-VRX Test B remains **NOT RUN**, and the temporary
   `RC_OVERRIDE_TIME=0.5` must still be restored to `3.0` after Test B or before
   any different operation.

   **27/08/2026 forward correction:** the SITL acceptance above is no longer
   current-source. `81efb73` later changed `tools/real_fcu_rc_command_bridge.py`,
   the bridge `tools/sitl_digital_twin_runner.sh` launches under test, and no
   `SITL_VERDICT` or `SITL_ADJUDICATION` has been recorded against a revision
   containing it. The query tier (T0b) was never closed either. Both gates must
   close on current source, or receive an explicit operator supersession, before
   Herelink-to-VRX Test B starts.

   **27/08/2026 closure:** the live workstation-only frame capture confirmed
   `/wamv/pose` contains `sydney_regatta -> wamv` as its sole world-parented
   transform and contains no child ending in `base_link`. The complete
   supervised SITL path was then rerun on clean revision `147efe0` in
   `/home/ghostzero/Desktop/sitl_digital_twin_20260827_164623`. It produced
   `SITL_VERDICT=PASS`; independent adjudication checked ten hashes and passed
   the control cross-check, stop order, verdict, teardown, ports, governed
   processes and final `SITL_ADJUDICATION=PASS`. The current-source SITL gate is
   closed. T0b remains open and Test B remains **NOT RUN**.

   **Later 27/08/2026 update:** the pinned snapshot-backed T0b probe passed all
   `41` selected reads while retaining live connected/disarmed and
   hardware-safety checks, so T0b is closed. Revisions `aa4a07a` and `1c1dff5`
   then landed the disarmed recorder and subscriber-ordering repair. A live
   disarmed run reached W1 seven-topic/rate acceptance and W2 four-stream
   READY, measured all stream gaps, PWM skew, thrust delay and stationary pose
   drift, and passed Pi, W2 and W1 teardown. The measurement and explicit-limit
   gates are closed. Test B remains **NOT RUN** pending current-revision SITL
   acceptance or explicit supersession, a clean published worktree and a fresh
   physical declaration.

   **Armed-attempt update:** the operator supplied those approvals for
   `eb9a337` and ran the armed path. Asymmetric real-FCU output, mapped thrust
   and `2.47946 m` of VRX motion were captured, but the fixed 60-second armed
   deadline aborted the Pi before the recorders captured final disarm and
   restored hardware safety. Test B is **ATTEMPTED - FAILED / NOT ACCEPTED**.
   The explicit retry repair uses paired zero armed/runtime selectors, retains
   all non-duration safety gates, defaults the Pi display to resizable and uses
   W2, W1, Pi teardown after recorded completion. **Publication update:** the
   repair is published as `d9dd120`; it remains unrun live and requires
   revision-specific SITL acceptance or explicit supersession, a fresh physical
   declaration and separate live approval.

   **Paired-zero retry update:** the operator ran the published mode from clean
   revision `550b992`. P1 reached its connected/disarmed neutral hardware-safe
   baseline with both armed and outer-runtime deadlines disabled, but never
   armed. It failed after three graph views reported zero publishers for
   `/mavros/global_position/raw/fix`, despite retained NavSatFix data and W1
   measuring the stream at `4.00 Hz`. P1 teardown passed; the resulting stale
   Pi streams stopped W2 and failed W1's RC-input rate probe, after which both
   workstation stacks cleaned up. The first attempt's machine evidence and the
   operator observation still prove Herelink-to-real-FCU-to-VRX motion for the
   captured interval, but no video or accepted final-safe-state record exists.
   Test B remains **ATTEMPTED - FAILED / NOT FORMALLY ACCEPTED** pending the
   minimal source-verifier repair and a direct W1, W2, P1 retry.

   **EOD source-verifier repair:** the existing bounded six-topic `rclpy`
   source view is now the default, while explicit
   `LIVE_MAVROS_SOURCE_BATCH=0` retains the legacy daemonless CLI diagnostic
   path. Exact publisher-count and `/mavros` identity verdicts remain
   fail-closed; no data-plane-only bypass was added. W1 now emits each governed
   child PID/PGID exit once in failure hold. Focused Pi and W1 suites pass. The
   repair is offline-only pending the direct W1, W2, P1 retry; formal Test B
   acceptance remains open.

   **28/08 morning correction:** a later-topic recovery could leave an
   earlier-topic block from its new six-topic generation pending across a
   verification boundary. The consumer now removes entries through the
   recovered topic, a focused phase-boundary case requires a new generation,
   and W1 explicitly carries source batch `1` plus the `180 s` final-verification
   budget into P1. The corrected helper still has no live result.

   **28/08 pre-arm arrival update:** the corrected helper subsequently reached
   source-stack and safe disarmed baseline PASS, and W2 reached four-stream
   READY. W1's independent publisher-arrival precheck timed out before any
   message sample, Pi observer or arm. Its focused repair retains per-topic
   discovery, uses monotonic timing and reports exact unresolved topics. The
   `25`-case W1 suite passes offline; formal Test B acceptance remains open.

   **28/08 repaired live result:** clean revision `6beb603` live-proved the W1
   publisher latch and seven rate probes, P1's connected/disarmed neutral
   hardware-safe baseline and W2 four-stream readiness. The first retained
   asymmetric command `800/1033` crossed UDP in `4.124019 ms`, mapped to
   `0.0/133.142857 N`, reached both thrust topics in about `1.1 ms`, and moved
   WAM-V `3.480079 m` inside the `10 s` window; neutral and zero thrust were
   subsequently retained. The operator also observed Herelink-driven VRX
   motion. A later external interruption was followed by Pi `stale_state`, W2
   `stale_left_thrust` and P1 loss of `/dev/video4`. The copied P1 evidence is
   `/home/ghostzero/Desktop/pi_run_evidence/test_b_functional_interrupted_20260828_155345`;
   its exact peak was `70500 mC`, below the `80000 mC` abort threshold. The
   last retained FCU state remained connected and armed, and canonical
   adjudication fails on the observer abort. Classification: **FUNCTIONAL
   MOTION DEMONSTRATED; RUN EXTERNALLY INTERRUPTED / NOT FORMALLY ACCEPTED**.
   No post-run rollback readback was retained, so the documented
   `RC_OVERRIDE_TIME=0.5` to `3.0` rollback remains open.

   **Later 28/08 Enhanced Test A and rollback update:** a fresh guarded
   dashboard run reached both READY markers and ended connected/disarmed with
   ordered `status=0 cleanup_rc=0` teardown. The operator corrected the active
   interval to propellers fitted and reported limited physical rotation, but
   the retained artifacts contain only neutral RC/output snapshots; this is a
   props-fitted functional observation, not T2b or T3a acceptance. The launch
   assertion `REAL_FCU_PROPELLERS_REMOVED=1` was inaccurate for that interval.
   The dashboard's exact `+/-0.20` steering endpoints are rejected
   after `float32` conversion exceeds the bridge's exact bound, and that source
   defect remains open. The separately approved rollback then confirmed live
   `RC_OVERRIDE_TIME=0.5`, set and re-read `3.0`, saved `986` parameters and
   copied the pinned artifact to
   `/home/ghostzero/Desktop/pi_run_evidence/rc_override_rollback_20260828`.
   Its SHA-256 is
   `a50fe5d313dd7ef2f2ab93f86dc2b6f7c800182eb603a1e4559580339aa1555b`;
   the serial endpoint was free afterward. This supersedes only the preceding
   rollback-open sentence. Test B remains not formally accepted.

   **31/08/2026 forward update:** clean revision `3ca4c9b` passed the complete
   supervised SITL acceptance and independent adjudication, then the bridge was
   changed to normalize only the exact float32 encoding of each configured
   steering or throttle endpoint. The unchanged authority limits remain `0.20`
   steering and `0.12` throttle; the next adjacent float32, materially
   over-limit commands and negative throttle stay rejected, and the focused
   suite passes `36` tests. The later edit reopens current-source SITL
   for the repaired bridge. Source tracing confirms paired command and override
   publication. ArduRover's throttle-plus/minus-steering mixer explains why a
   steering-heavy request can leave one side at bottom-neutral, but the
   straight-throttle ESC onset remains unmeasured. No authority or
   `MOT_THR_MIN` value was raised; any threshold measurement remains a
   separately approved, propellers-removed calibration with correlated command
   and PWM capture.

   **Later 31/08/2026 closure:** clean revision
   `bba195b19a0f06a874bfbcbcbbd1621524cbce60` passed the complete supervised
   SITL acceptance in
   `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839`. Independent
   adjudication retained at
   `/home/ghostzero/Desktop/sitl_digital_twin_20260831_161839_adjudication.log`
   checked all ten hashes, the control cross-check, exact stop order and
   teardown, with governed ports free and governed process patterns absent,
   before ending `SITL_ADJUDICATION=PASS`. This
   closes current-source SITL for the repaired bridge. It is simulator-only
   evidence; a separately verified Pi transfer and checksum of the regenerated
   bundle remain required before Pi use.

   **Later 31/08/2026 Pi deployment closure:** the regenerated bundle was
   installed at
   `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260831_bba195b` with
   exact five-file inventory, the pinned manifest digest and all four governed
   member hashes verified. The non-actuating helper check ended
   `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`, and the
   workstation copy-back is
   `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260831_bba195b`.
   This closes bundle transfer/checksum certification only. No probe, MAVROS
   or bridge runtime, parameter write, arm or propulsion action ran; complete
   real-hardware acceptance and the ESC-threshold calibration remain open.

   **01/09/2026 T3a source supersession:** the former propellers-removed
   calibration path remains available only for its T2b tier. The source now
   provides a separate `run-t3a` demand-enabled Pi mode for a freshly approved,
   guarded props-fitted window and a separate
   `t3a --esc-threshold-calibration` subscriber-only recorder with no write
   path. The existing command authority, E-Stop, neutral, disarm and teardown
   contracts remain unchanged. Focused verification passes `26` recorder tests,
   `42` helper cases and the regenerated `4/4` manifest. This is
   **OFFLINE IMPLEMENTATION / NOT RUN / NOT DEPLOYED**: the earlier
   `20260831_bba195b` Pi root remains valid for its own bytes but does not contain
   the T3a runtime. A new commit-named deployment and non-actuating
   certification are required before any live approval can be requested.

   **Later 01/09/2026 T3a deployment closure:** clean published revision
   `025f48c1fb97dd4bf939c7fd3b3fd44a064e89ba` was installed at
   `/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260901_025f48c`. Its exact
   five-file inventory, executable helpers, manifest digest
   `11a892667767ce74f162d4a5b58e88762ec66e6fceba346784dc775cfd80748d`
   and all four governed hashes passed. The helper ran only its non-actuating
   `check` and emitted
   `REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started`. The
   independently reverified workstation copy-back is
   `/home/ghostzero/Desktop/pi_run_evidence/pi_bundle_certification_20260901_025f48c`.
   This changes the classification only to **DEPLOYED / CERTIFIED / NOT RUN**.
   It is not a probe or command runtime, created no parameter, arm or propulsion
   result, and grants no Block E authority.

3. **Detector recovery before Hailo accuracy gates**: the Hailo six-output decode
   contract is proven on saved frames (07/07/2026, `fb308f9`), and the 08/07 Pi
   runtime smoke proved single-process RealSense -> Hailo -> decode-summary
   mechanics with the current non-functional HEF. The next accuracy-grade Hailo
   gate remains positive-bearing saved-frame Tier 3, but it is blocked upstream
   until a retrained detector fires on held-out positives at sane confidence.
   Immediate work: run the isolated 09/07 unicolor-object training smoke only
   after explicit approval, then execute the maritime acquisition manifest and
   retrain only after materially larger labeled data exists.
4. **Phase 5 prep tasks** (see above): supervisor conversation on CCU
   architecture, topic-remap dry run, LiDAR profiling, bridge-node stub,
   `/wamv/*` inventory.
5. Long-duration stress testing (15+ min missions) — may be superseded by
   on-water runs once hardware lands.
6. Complex waypoint circuits with obstacles.
7. Performance benchmarking (RMS error analysis).
8. Coverage planning algorithms (boustrophedon).

---

## 🚀 Future Ideas

| Feature | Priority | Description |
|---------|:--------:|-------------|
| **Dynamic Replanning** | High | Replan when new obstacles detected mid-route |
| **Go-To-Point** | Medium | Navigate to arbitrary GPS coordinate with obstacle avoidance |
| **Multi-Goal Navigation** | Medium | Sequence of random points (patrol mode) |
| **Coverage Planning** | Low | Boustrophedon pattern for area scanning |

### Recently Completed ✅

| Feature | Status | Description |
|---------|:------:|-------------|
| **A\* Path Planning** | ✅ Done | Hybrid mode (pre-plan) + Runtime mode (detours) in Waypoint Planner |
| **One-Click Launcher** | ✅ Done | `launch_autoboat_complete.sh` for full system startup |
| **Wiki Documentation** | ✅ Done | Comprehensive wiki pages in `wiki/` folder |
| **Emergency Stop** | ✅ Done | Latching stop from dashboard/CLI, EMERGENCY_STOP state |
| **Dashboard Config System** | ✅ Done | 3 Apply panels, dirty-params, reset defaults, disabled until sync |
| **Param Collision Fix** | ✅ Done | Perception params prefixed `perception_` to avoid Controller collision |
| **VRX LiDAR Patch** | ✅ Done | Fork bake-in commit `e384cd65` on `autoboat/main` (06/05/2026); `patch_vrx.sh` retained as idempotent no-op safety net for ≥2 release cycles |
| **Repo Cleanup** | ✅ Done | Dead code, legacy moves, package.xml audit, setup.py cleanup |

### A\* Path Planning (Implemented)

```text
/perception/obstacle_info ────>┌─────────────────────┐
                        │  AStarSolver        │────> Detour waypoints inserted into /planning/waypoints
Current position ──────>│  (in Planner)       │
                        └─────────────────────┘
```

- Occupancy grid (3m cells) with 8-connected A\*
- **Hybrid Mode**: Pre-plan routes between lawnmower waypoints
- **Runtime Mode**: Plan detours when stuck or blocked

---

## 📚 Lessons Learned

| # | Lesson |
|---|--------|
| 1 | Cross-platform naming conventions are critical |
| 2 | TF tree configuration requires careful attention |
| 3 | Start simple, add complexity incrementally |
| 4 | Document early to reduce technical debt |

### Technical Debt

| Issue | Status | Description |
|:------|:------:|:------------|
| **ROS 2 Parameter Migration** | ✅ Done | Parameters now configurable via `autoboat.launch.yaml` |
| **Multi-Terminal Launch** | ✅ Done | `one_click_launch_all/launch_autoboat_complete.sh` available |
| **Debugging Required** | 🔄 In Progress | Complex planning and obstacle detection still need debugging |
| **Node Naming Refactor** | ✅ Done | One-shot atomic rename completed 16/04/2026 (OKO → `lidar_perception`, SPUTNIK → `waypoint_planner`, BURAN → `heading_controller`, Vostok1 → `AutoBoat`, vostok1_cli → `autoboat_cli`). See [wiki/Node_Naming_Refactor_Plan](wiki/Node_Naming_Refactor_Plan.md) for the full record. |

---

## 📜 Acknowledgments

**Document Version**: 9.61 | **Last Updated**: 01/09/2026

**Maintained By**: AutoBoat Development Team

**Institution**: [IMT Nord Europe](https://imt-nord-europe.fr/) — Industry 4.0 Students & Faculty
