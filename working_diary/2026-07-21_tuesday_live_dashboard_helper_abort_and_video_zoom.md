# Tuesday 21/07/2026 - Live Dashboard Helper Reliability And Video Zoom

## Goal

Improve the existing shell helpers around the unexpected workstation-side dashboard
termination seen on 17/07/2026, then assess a safe click-to-enlarge and zoom view for
the live Hailo detection stream. Keep the dashboard view-only and the FCU disarmed.

## Starting point

- Both 17/07 IoT runs passed six-topic arrival, rate probes, and human visual acceptance.
- The workstation dashboard stack ended before the intended Pi-first stop. The
  initiating event, cross-host causal order, and normal lifecycle acceptance remain
  open.
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

## Block A outcome - diagnosis and design assessment

Block A completed on 21/07/2026. Only repository inspection, preserved-log analysis,
existing static checks, and this diary update were performed. No shell or dashboard
source changed, and no Pi command, live service, hardware test, or browser acceptance
was run.

### Repository baseline

- `git fetch --prune` completed before the investigation.
- `main` started clean at `bab92e0`; `HEAD` and `origin/main` both resolved to
  `bab92e0f19984e1e1cb78b64599a12114cca2091`.
- The supervisor and Pi helper still match their 17/07 pins:
  `de08299cdf1a201f23619c0d434604cadaedcef29dc5926a84d04f33560c55fc` and
  `b778f69e3c692ae6e221d8a341962baf879d6aa2336df8f21912a3f1fbb81c12`.

### Workstation termination diagnosis

The child-stop signal and teardown sequence are identified; the supervisor's initiating
event is not.

- The preserved child logs show the same coordinated reverse stop order in both runs:

  | Workstation run | Dashboard | `web_video_server` | rosbridge |
  | --- | --- | --- | --- |
  | `live_dashboard_workstation_20260717_145833` | interrupt exit around `15:09:17` | signal handler at `15:09:18.143` | SIGINT and clean websocket exit by `15:09:19` |
  | `live_dashboard_workstation_20260717_151713` | interrupt exit around `15:25:57` | signal handler at `15:25:58.466` | SIGINT and clean websocket exit by `15:25:59` |

- This sequence matches `teardown_workstation_services()`: dashboard, video server,
  then rosbridge, with `stop_group()` trying `INT` first. The `rosapi_node` exit code
  `-2` appears only after rosbridge launch sends it `SIGINT`; it is teardown fallout,
  not the trigger.
- After the rate probes pass, the success path enters unbounded `supervise_children()`.
  A monitored child or local-health failure is recorded and then enters
  `FAILURE_HOLD=ACTIVE` until a stop request. The supervisor has no successful-completion
  timeout and does not read stdin; browser closure, stdin EOF, and the earlier
  readiness/arrival deadlines do not normally end that path.
- The paired Pi copies contain no command-safety or thermal abort: each safety log has
  only its ready marker, each thermal-watchdog log is empty, and the recorded peaks are
  `68300` mC and `67200` mC.
- The only preserved cross-host process timestamps place Pi MAVROS `SIGINT` before the
  workstation video-server signal by about `66` seconds and `13` seconds. Host-clock
  alignment is not proven, and the rosbridge/rosapi reachability loss has no durable
  timestamp, so process order and causation between the two hosts are not determinable
  from these logs.

**Diagnosis:** both workstation stacks underwent coordinated INT-first child teardown
that matches the supervisor's cleanup routine. No preserved child log shows an
independent dashboard, video-server, or rosbridge crash before that sequence, and the
source has no internal successful-completion timeout. However, `cleanup()` sends `INT`
to the children regardless of why the supervisor exits. The child logs therefore do not
prove a terminal-generated interrupt or identify the supervisor's initiating event.

No change to the fail-closed teardown behaviour is justified from this evidence. The
remaining helper gap is forensic: child, arrival, and rate logs are durable, but the
supervisor's own stop cause, phase, stdout/stderr, and exit status are not stored in the
run directory.

### Safe single-stream viewer assessment

The current camera path has exactly one `<img id="camera-image">`. Only
`updateCameraStream()` removes or assigns its `src`, with a deliberate disconnect delay
to protect `web_video_server` from connection churn. The enlarge/zoom path must therefore
remain presentation-only.

Recommended design:

- Apply a fixed CSS modal state to the existing camera container. Keep
  `#camera-image` in the same DOM location; do not clone, replace, reparent, or recreate
  it.
- Provide image-click and explicit Enlarge-button entry to the same idempotent open
  function. Add Zoom out, a scale readout, Zoom in, Reset, and Close controls.
- Keep bounded local state only: closed/open plus `1.0x` to `4.0x` in `0.5x` steps.
  A scrollable viewport exposes enlarged edges without a custom drag or gesture engine.
- Opening, zooming, resetting, and closing may change only classes, accessibility
  attributes, control visibility, scroll position, and the zoom CSS property. They must
  make zero `src` assignments, zero `removeAttribute('src')` calls, and zero calls to
  `updateCameraStream()`.
- On open, save the triggering control, reset to `1.0x`, expose the dialog semantics,
  and focus Close. Trap focus within the viewer. Escape closes only the expanded viewer,
  resets zoom/scroll, and restores focus without consuming unrelated Escape events.
- A camera `error` keeps the viewer closable and disables zoom; a later `load` restores
  zoom controls. Rosbridge disconnect must not close or relabel the independent HTTP
  MJPEG stream.

The resource-ownership boundary is:

```text
updateCameraStream() owns the MJPEG connection lifecycle
camera viewer functions own presentation state only
```

Later automated coverage must prove one `#camera-image`, idempotent open/close, bounded
zoom, Reset and Escape/focus behaviour, error recovery, rosbridge/MJPEG separation, and
zero stream-URL mutation across every viewer action. A later browser gate must confirm
one continuing `/stream?...` request through open, zoom, reset, and close.

Non-goals for the first implementation are a second image, CSS background stream,
canvas copy, snapshot, recording, Picture-in-Picture, browser Fullscreen API, custom
drag/pinch/wheel capture, persisted zoom, a general modal framework, or any MJPEG topic,
quality, reconnect, Pi, helper, or ROS change. Camera-frame freshness monitoring is also
separate work; the current `load`/`error` contract does not detect a frozen last frame.

### Existing static verification

- Shell syntax checks passed for both helpers and both shell harnesses.
- `tools/test_live_dashboard_preflight.sh tools/live_dashboard_preflight.sh` passed
  `12/12` cases.
- `tools/test_pi_live_hailo_mavlink_dashboard.sh` against
  `tools/pi_live_hailo_mavlink_dashboard.sh` passed.
- `node --test --test-isolation=none web_dashboard/autoboat/test/*.test.js` passed
  `26/26` tests.
- `node --check web_dashboard/autoboat/app.js` passed.

The existing workstation harness covers direct interrupt-handler calls, premature fake
child exit, failure hold, and reverse teardown. It does not deliver a real operating
system signal to a fake supervisor or persist the initiating signal and phase.

**Next step:** Request explicit approval for Block B: add a durable supervisor stop-cause
record and one real-`SIGINT` fake-child regression only. Preserve the current stop
semantics; do not start services or touch the camera implementation in that block.

## Block B outcome - durable supervisor lifecycle evidence

Block B completed on 21/07/2026. The workstation supervisor, its existing shell harness,
and this diary are the only modified files. No Pi command or connection, live ROS or
dashboard service, hardware test, browser acceptance, or camera change was performed.

### Supervisor record

Each future workstation run now creates `supervisor.log` in its existing run directory
before any child is started. The supervisor writes timestamped lifecycle messages to that
file before emitting the same normal or error message to the terminal. The record includes:

- startup and the current phase: `service-start`, `service-readiness`, `pi-command`,
  `arrival`, `rate-probes`, `supervision`, `failure-hold`, and `teardown`;
- the first handled stop trigger, for example
  `SUPERVISOR_STOP trigger=signal signal=INT phase=supervision`;
- ordinary EXIT-triggered cleanup when no `INT` or `TERM` handler recorded the cause;
- the first failed phase, reverse child-stop messages, teardown result, and the selected
  final status, for example
  `SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=supervision failed_phase=none cleanup_rc=0`.

Signal and status remain separate facts. A healthy post-readiness `INT` still requests an
orderly stop and returns `0`; a pre-readiness `INT` still returns `130`; `TERM` and prior
phase failures retain their existing non-zero status. Cleanup still stops dashboard,
`web_video_server`, and rosbridge in reverse order and still tries `INT`, `TERM`, then
`KILL`. The final status precedence remains incoming status, preserved phase status, then
cleanup status.

This is a lifecycle/provenance record, not an unrestricted terminal transcript. Capture
starts only after the runtime preflight succeeds and the run directory is initialized.
The printed Pi command is not duplicated, and rate-probe payload remains in
`w5_live_rates.log`; child output remains in each child log. A later append failure warns
without interrupting cleanup, while an unwritable initial log prevents child startup.
`SIGKILL` and power loss cannot run a shell trap, so a missing final record remains a
bounded indication rather than an identified cause.

The change does not identify the initiating event in either preserved 17/07 run. It gives
future runs the evidence needed to distinguish a handled `INT` or `TERM` from a generic
EXIT path and to retain the phase and final status.

### Regression and focused verification

The existing workstation harness now has one additional case. It first failed because no
durable supervisor record existed, then passed after the lifecycle change. The case keeps
the fake supervisor in the foreground with `errexit` enabled, waits until its monitor has
entered `supervision`, and sends a real programmatic operating-system `SIGINT` to that PID
only. Three fake children run in separate process groups through the production
`start_child()` path.

The case proves:

- supervisor status `0`, one durable `INT` trigger at `supervision`, final status `0`,
  and successful teardown;
- no false `PHASE_FAIL` or `FAILURE_HOLD=ACTIVE`;
- exactly one stop per child in dashboard, video-server, rosbridge order, with each fake
  child receiving `INT` and all three process groups gone;
- a bounded watchdog and local fallback cleanup; the case does not call `ss`, `ros2`, a
  network endpoint, or any Pi command.

Focused results:

- `bash -n` passed for `tools/live_dashboard_preflight.sh` and
  `tools/test_live_dashboard_preflight.sh`;
- `tools/test_live_dashboard_preflight.sh tools/live_dashboard_preflight.sh` passed
  `13/13` cases;
- `git diff --check` passed;
- the new supervisor pin is
  `b7fd414b23c6c3b5e7d2dabde3828b8b3e98e24a28fa9bc243314baaef781ead`
  at `27,564` bytes; the harness pin is
  `a8012bcca0ff395328312baecf659bf63e1ba3fc1e38257372055817babb17c3`
  at `35,000` bytes.

### Deferred runbook update

`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` still contains the previous supervisor
size and checksum. Its 17/07 cause wording and the corresponding summary in `Board.md`
also predate the evidence ceiling established in Block A. Neither file was edited in this
block.

**Next step:** Request explicit approval for a narrow documentation-only block to update
those two surfaces. Pi work, live acceptance, and camera implementation remain separately
gated.

## Block C outcome - bounded live validation

Block C completed on 21/07/2026 as a user-run working-tree validation of the
uncommitted Block B supervisor against the live Pi source stack. The run changed no
shell or dashboard source. Both workstation and Pi run directories were preserved;
browser acceptance is recorded as operator-reported.

### First attempt - fail-closed heartbeat and arrival failure

Pi run `live_dashboard_20260721_142441` opened `/dev/ttyAMA0`, but MAVProxy received
no FCU heartbeat and reported `link 1 down`. The helper stopped at its 30-second
heartbeat gate and reached `TEARDOWN=PASS`. The paired workstation run
`live_dashboard_workstation_20260721_142426` then reached its 360-second six-topic
arrival timeout, recorded `PHASE_FAIL: phase=arrival`, and entered
`FAILURE_HOLD=ACTIVE`. Its later operator `INT` produced orderly reverse teardown and:

```text
SUPERVISOR_EXIT status=1 trigger=signal signal=INT stop_phase=failure-hold failed_phase=arrival cleanup_rc=0
```

These are two views of the failed attempt: no serial heartbeat on the Pi and no
six-topic arrival on the workstation. The initiating cause remains unknown. The Pi
symptom matches the `/dev/ttyAMA0` `link 1 down` observation recorded for 26/06/2026
in `Board.md`, but the evidence does not establish a common cause.

### Retry - functional stack and durable lifecycle evidence

Pi run `live_dashboard_20260721_144945` detected vehicle `1:1`; MAVROS reported
`connected: true`, `armed: false`, and mode `HOLD`. State, raw GPS, IMU, battery, and
RC samples were present. GPS remained no-fix and the RC sample contained no channels,
while transport remained live. Hailo published `320x240` frames through frame `5100`.
The recorded peak was `67750` mC; `thermal_watchdog.log` was empty, the safety log
contained only its ready marker, and no command or thermal abort artifact was produced.
The target 120-second window completed in `181` seconds, followed by the monitored hold
and orderly operator-requested teardown.

The second workstation run `live_dashboard_workstation_20260721_145447` observed all
six topics after `111` seconds. Its rate probes measured Hailo at `7.52 Hz` and each of
the five MAVROS topics at `1.00 Hz`. An operator `INT` during `supervision` stopped
dashboard, `web_video_server`, and rosbridge in reverse order, reached
`WORKSTATION_TEARDOWN=PASS`, and recorded:

```text
SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=supervision failed_phase=none cleanup_rc=0
```

The browser dashboard passed operator acceptance. These two preserved `supervisor.log`
files are the first live-run evidence that the Block B record distinguishes a clean
supervision stop from an arrival-phase failure.

This validation does not prove a fresh workstation-first then Pi startup or Pi-first
shutdown. The successful Pi runtime exceeded the second workstation supervisor's total
lifetime, so the preserved sequence cannot satisfy both ordering gates. Both remain
open for a fresh full-stack run.

**Next step:** Complete the separately gated presentation-only camera viewer
implementation and its automated coverage, then run one fresh ordered full-stack
acceptance with workstation-first startup and Pi-first shutdown.

## Block D outcome - single-stream camera viewer

Block D completed on 21/07/2026. It changed only the dashboard HTML, JavaScript,
stylesheet, one new focused Node test, and this diary. No shell helper, Pi connection,
live service, hardware run, or browser acceptance was performed. The browser PASS in
Block C predates this implementation and does not validate the viewer.

### Presentation-only implementation

The existing camera container now becomes a fixed dialog only while expanded. The sole
`#camera-image` stays under the same `#camera-feed` parent for its entire lifetime. The
viewer functions change classes, dialog and trigger attributes, toolbar visibility,
scroll position, and the `--camera-viewer-scale` CSS value only. They do not assign or
remove `src`, build a stream URL, call `updateCameraStream()`, or create or move an image.

The viewer provides:

- image-click, Enter/Space, and an explicit Enlarge button as idempotent entry paths;
- Zoom out, a live scale readout, Zoom in, Reset, and Close controls;
- `1.0x` to `4.0x` bounds in `0.5x` steps, with a native scroll viewport and Reset
  available at `1.0x` to clear scroll position;
- open-time dialog semantics, Close focus, trapped Tab navigation, Escape close only
  while expanded, and focus restoration to the original trigger;
- zoom-control disablement on camera error and restoration on a later image load,
  without coupling viewer state to rosbridge reconnects.

The modal sits below the onboarding layer but above the current header and footer
E-Stop shortcuts. That is acceptable only in this temporary view-only build, where the
write controls are disabled. Reuse in a future write-enabled dashboard requires a
separate safety decision rather than silently hiding an active E-Stop surface.

### Red-green and focused verification

The new `web_dashboard/autoboat/test/camera_viewer.test.js` first failed all five cases
against the pre-feature dashboard because the viewer DOM and presentation source block
did not exist. After the implementation and review corrections, it proves:

- exactly one camera image and unchanged stream ownership;
- idempotent open and close without image-parent or URL mutation;
- bounded half-step zoom and Reset scroll clearing, including at `1.0x`;
- closed-versus-open Escape behaviour, focus wrapping, and trigger restoration;
- camera error/load recovery and rosbridge independence.

Focused and full results:

- the camera-viewer suite passed `5/5` tests;
- `node --test --test-isolation=none web_dashboard/autoboat/test/*.test.js` passed
  `31/31` tests;
- `node --check web_dashboard/autoboat/app.js` passed;
- `git diff --check` passed.

These static tests prove the source-level single-stream boundary. They do not replace the
browser gate: a later live run must confirm one continuing MJPEG request while opening,
zooming, resetting, and closing the viewer.

### Deferred documentation

The dashboard README feature table and the live runbook browser checklist do not yet
describe the new viewer controls or their single-request acceptance gate. Updating those
two surfaces remains a separate documentation-only decision.

**Next step:** Update the two user-facing instructions if approved, then run one fresh
ordered full-stack acceptance with workstation-first startup, Pi-first shutdown, and the
camera viewer exercised against one continuing Hailo MJPEG stream.

## Block E outcome - viewer guidance and safety guardrail

Block E completed on 21/07/2026 as a documentation and comment-only follow-up before
publication. It changed no viewer behaviour, shell helper, Pi path, ROS topic, or live
test result.

The dashboard README now describes the single-stream viewer entry paths, bounded zoom,
Reset, Close, Escape, focus handling, and camera-error recovery. The live runbook browser
gate now requires the Network panel to retain one original `/stream?...` request while
the operator opens, zooms, resets, and closes the viewer. It also checks keyboard entry,
Close focus, trapped Tab navigation, Escape close, focus restoration, and the scale and
scroll reset.

The view-only boundary is explicit in the code-adjacent comment, README, and runbook. The
current full-screen viewer covers and focus-fences all three E-Stop surfaces, which are
inert in this temporary build. Any future write-enabled reuse must first make an
operational E-Stop reachable by pointer or keyboard without closing the viewer, then
pass that condition as a separate acceptance smoke test.

**Next step:** Commit and push the complete Tuesday working tree on `main`, then prepare
the separately gated fresh full-stack pipeline. Do not start the live run from this
documentation block.
