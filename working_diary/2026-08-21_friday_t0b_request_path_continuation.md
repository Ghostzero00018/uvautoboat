# Friday 21/08/2026 - T0b request-path continuation

**PRE-DIARY - NOT STARTED.**

This is the sole 21/08/2026 continuation for the guarded real-FCU track. It
carries no approval from 20/08/2026.

## Objective and scope discipline - read before proposing any command

The immediate objective of this command-path workstream is a **digital twin of
the boat's motors, integrated with the web dashboard**. It sits inside the
broader formal objective recorded in `wiki/Roadmap.md`, and every block below is
a means to it rather than an end in itself.

**That objective does not depend on T0b or T1.** The simulator path passed its
full functional run, automatic teardown, final verdict and independent
adjudication on 17/08/2026. The separately scoped thrust-twin continuation
recorded on 19/08/2026 has not been started, while two full working days, 19/08
and 20/08, went entirely into the real-FCU request path, which remains open.

Three rules bind this day:

1. **Every command must be tied to a decision.** Before proposing a command
   block, state which decision its output changes. If the honest answer is
   "it would be interesting to know", do not run it. A diagnostic that cannot
   change the next action is not evidence-gathering; it is delay.
2. **Prefer a tested repository helper to an improvised one-off.** Long or
   quoting-sensitive terminal blocks have repeatedly needed their own
   corrections before they could run at all. Repeatable, non-actuating
   diagnostic command logic should live in a tested helper; manual
   attestations, power changes and physical actions remain operator-run and
   separately approved.
3. **Bound the real-FCU track for the day.** The hardware allowance is four
   execution phases and no more: the Herelink read; at most one T1 candidate
   write with any required reboot and a retained read-back; at most one T0b
   probe run **while the candidate value is still in effect**; then the
   rollback. Three approvals cover them - one for the read, one for the write
   that also approves the rollback command and its trigger, and one for the
   probe. Because the rollback is pre-approved, no fresh approval is needed to
   attempt and verify restoration. Rolling back before the probe would leave
   nothing to test. **Once a retained read-back confirms `0` is in effect**, if
   probe approval is not granted or the probe cannot start or complete, attempt
   and verify that same pre-approved rollback immediately, before any further
   action or close-out. That rule applies only to the in-effect case: a
   read-back that still shows the prior value needs no rollback write, and an
   unknown read-back is handled by its own branch below. **Normal
   close-out is forbidden until a retained read-back verifies restoration of
   the prior value.** A failed or unverified rollback blocks all further
   work: preserve the evidence, report
   the controller configuration as unresolved, and perform only the
   already-approved safe power-down. A passing probe earns T0b evidence **only
   for the candidate setting**. After rollback, record the prior value as
   restored and do not describe T0b as currently available or open T2a on it;
   reapplying the candidate requires a later T1 approval of its own. If the
   probe runs and does not close T0b, stop the hardware track and propose a
   separately approved motor-twin and dashboard block; this paragraph does not
   authorize starting it. Do not invent a further diagnostic variant to keep the
   track alive.

When a proposed step does not move the motor twin and its dashboard integration
closer, and no bounded gate requires it first, the correct answer is to switch
tracks rather than to deepen the current one.

## Starting boundary

Revision `f8e440a81d8f08318b089814c05329b21ddafd1c` remains the deployed source at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820`. On 20/08/2026, the
full probe reached a connected, disarmed and hardware-safe FCU but received no
automatic or forced parameter response. A later duplex isolation received `18`
valid disarmed heartbeats and transmitted exactly one PING plus one
`SYSID_THISMAV` read request, audited as `53` bytes with no state-changing
message. Neither request received a response.

The 20/08/2026 physical day then closed with the FCU/autopilot, control
electronics and Herelink off, propulsion power isolated, propellers removed and
the hull restrained.

T0b remains open. No `41`-parameter mapping/rail artifact exists. T1, T2a, T2b,
arming, RC override, motor action, thrust action and every higher physical tier
remain closed.

## Read first

1. Read the 20/08/2026 diary from `## Block A safety repair - local
   verification passed` through `## End-of-day close-out - complete`, including
   the audit correction, the repair boundary and every superseded status note.
2. Read the current 20/08 supersessions in `Board.md`, `wiki/Roadmap.md` and
   `web_dashboard/autoboat/README_autoboat_dashboard.md`.
3. Read `rfcu_pi_configure_ros_environment` in
   `tools/real_fcu_digital_twin_pi.sh` and confirm `RFCU_PI_DISCOVERY_RANGE`
   stays `SUBNET` while `RFCU_PI_PROBE_DISCOVERY_RANGE` selects `LOCALHOST` for
   the `probe` mode only.
4. Read `config/real_fcu_digital_twin_bundle.sha256` and re-establish the
   current helper and manifest bytes before reusing the `24`-case result.
5. Read the `T1` row of the tier table in `Board.md` together with the recorded
   wiring `Pi TXD (GPIO14) -> Cube SERIAL1 RX`. Confirm that wiring before
   accepting `BRD_SER1_RTSCTS` as the correct parameter name for this boat.

## Block A - fresh-day certification only

Certify the live revision before any Pi or physical step:

```bash
git fetch --prune
git status --short --branch
git log --oneline -8
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git log -1 --format='%H%n%s'
```

Require a clean worktree and index, `HEAD == main == origin/main` and
divergence `0/0`. Inspect every commit later than
`95a42c61afa69d7f0fac80fe5ef12cf7d67077f2` before relying on it. Today's
simulator motor-twin block intentionally changes non-Markdown tracked files
after `f8e440a81d8f08318b089814c05329b21ddafd1c`, including the governed bridge.
That expected divergence invalidates the 20/08/2026 Pi root as a current copy;
it does not block the workstation simulator acceptance. It remains a blocker
for any Pi or controller continuation until a newly approved deployment root
re-establishes the deployed bytes and the `24`-case suite evidence.

Then re-verify the governed artifacts on the workstation:

```bash
sha256sum -c config/real_fcu_digital_twin_bundle.sha256
sha256sum config/real_fcu_digital_twin_bundle.sha256
bash tools/test_real_fcu_digital_twin_helpers.sh
```

Require four member lines reporting `OK`, a manifest digest of
`8c4f04a69fef395ec70735f6ac5485d315da7955ba6aeb3b76473aa155de2eec` and a final
`PASS cases=24`.

Re-measure the free-disk figure, the reserved TCP and UDP endpoints and the
scoped process list directly, and record the observed values here. The
20/08/2026 run reported a free-disk floor and a process-pattern count that no
tracked file pins, so treat both as observations to re-measure rather than as
contract values to assume.

Re-certify the Pi deployment and environment after the date boundary and after
any Pi power cycle. The 20/08/2026 close-out marker records the FCU/autopilot,
control electronics and Herelink off with propulsion isolated, propellers
removed and the hull restrained, but it does not state the Pi's own power
state. Establish that state directly and record whether the Pi was power-cycled
before reusing any deployed-byte evidence. Confirm that
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820` still holds revision
`f8e440a81d8f08318b089814c05329b21ddafd1c` with its four governed members
verified `4/4`.

Every Pi command remains operator-run in a real terminal opened through
Remmina. Do not energise the controller or Herelink merely to run the
non-actuating deployment `check`.

After Block A reports, stop. The Herelink read below and any T1 change each
require a new explicit approval even if all certification passes.

## First objective

Do not repeat the same full pull. First certify the live repository, deployed
bytes, Pi environment, serial ownership and current physical state. Then use the
working Herelink ground-station path to read and retain the current
`BRD_SER1_RTSCTS` value without changing it.

Stop after the read. The recorded `2` is prior evidence and does not stand in
for today's live reading; branch on what is actually read:

- **the initial read is not exactly `2`** - stop. Do not request the
  pre-scoped `2` to `0` change, because its premise no longer holds. Record the
  observed value and report the discrepancy.
- **the initial read is exactly `2`** - the change may be proposed.

A T1 candidate change from `2` to `0` requires a separate same-day approval,
which must cover the prior-value capture, the write itself, any required reboot,
the retained read-back **and** the rollback command with its trigger. The
rollback is not executed at this point: it is recorded as an approved, ready
action.

Branch again on the retained read-back:

- **it reads `0`** - the candidate is in effect; a probe may now be requested.
- **it still reads `2`** - the candidate is not in effect at the retained
  read-back. Preserve the evidence and stop. No rollback write is needed or
  permitted, because the controller already holds the prior value.
- **it is missing, unreadable or any other value** - the configuration state is
  unknown. Attempt and verify the pre-approved rollback, and treat close-out as
  blocked until a retained read-back confirms the prior value. Then stop: no
  reapplication and no probe under the current approvals.

**Only the read-back `0` branch continues here.** A fresh T0b probe then
requires another approval, and it runs **while the candidate value is still in
effect** - that is the only state in which it tests anything. Attempt and verify
the rollback after the probe, under the approval already granted with the write,
whatever the probe's outcome; because it is pre-approved, no fresh approval is
needed to attempt and verify restoration. If probe approval is not granted, or
the probe cannot start or complete, attempt and verify that same rollback
immediately, before any further action or close-out.

**Normal close-out is forbidden until a retained read-back verifies restoration
of the prior value.** A failed or unverified rollback blocks all further work:
preserve the evidence, report the controller configuration as unresolved, and
perform only the already-approved safe power-down.

## Boundaries

- Start with the FCU disarmed, hardware safety ON, propulsion power isolated,
  propellers removed, hull restrained, and Herelink sticks and trims neutral.
- No approval or physical attestation crosses the date boundary.
- Arming is not part of this continuation. An armed start would bypass the open
  parameter, mapping and rail gates.
- No simulator and real-FCU supervisor overlap.
- Preserve every 20/08/2026 deployment, lock, transcript and evidence path.
- Stop at the first failed certification, safety, serial-owner, evidence or
  cleanup gate, **except for the pre-approved rollback and safe power-down
  required above**. Do not retry the failed method.

## Simulator motor-twin rail block - local verification passed, live rerun pending

The user redirected the day to the motor digital twin and dashboard rather than
continuing the controller request path. The pre-edit baseline for this appended
record is `7e080f4577460a37a3693a6d2a895a0f3d4345a1`; no commit containing this
text is predicted here.

The bridge already resolved the live RC and servo rails but omitted them from
`/command_ingress/status`. The dashboard could therefore show only raw PWM and
could not describe where a measured motor output sat within its actual rail.
The status payload now carries both resolved RC rails and both function-resolved
servo rails. The dashboard keeps the raw PWM and adds a signed percentage of
the configured PWM rail. This is the literal position of the measured output;
it does not apply `SERVOx_REVERSED` again after ArduPilot has produced
`SERVO_OUTPUT_RAW`. It explicitly reports `Rails not received` before that data
exists, marks missing or invalid rail data critical, supports both a mid-scale
trim such as simulator `1000`/`1500`/`2000` and an endpoint trim such as the
recorded boat `800`/`800`/`2200`, and does not claim physical force.

The bridge regression first failed with a missing `rc_rails` status key. The
dashboard regressions first failed because the measured-output row remained raw
only and had no missing-rail state. After the implementation:

- the bridge suite passed `27` tests;
- the combined bridge, simulator-evidence and operator suite passed `44` tests;
- the complete dashboard suite passed `80` tests, including reversed mid-scale
  and endpoint-trim output rails plus direct simulator evidence `SERVO1=1585`
  and `SERVO3=1485` rendered as `+17.0% PWM rail` and `-3.0% PWM rail` against
  the live `1000`/`1500`/`2000` rails;
- the synthetic simulator-runner suite passed `41` cases with host socket
  visibility;
- the complete physical-helper suite passed `24` cases after the changed bridge
  digest was regenerated in `config/real_fcu_digital_twin_bundle.sha256`;
- all four governed members verified, the new manifest digest is
  `8c4f04a69fef395ec70735f6ac5485d315da7955ba6aeb3b76473aa155de2eec`,
  and Python and JavaScript syntax checks passed.

The production workstation `check` path is not credited: its preflight stopped
at the default log-root write check before starting its test list. The same
component suites were executed directly as recorded above. The full
`motorboat-skid` supervisor rerun is also **NOT RUN** in this uncommitted
worktree. Its clean `HEAD == origin/main` requirement remains binding and must
not be bypassed. After the user commits and publishes this logical change, run
the simulator supervisor once and retain its verdict, teardown and independent
adjudication before calling the new dashboard path runtime-accepted.

Changing the bridge invalidates the 20/08/2026 Pi deployment as a copy of the
current repository. That preserved root remains historical and was not updated,
reused or deleted. No Pi, real controller, control box, Herelink, physical
arming, motor or thrust action occurred in this block.

## Real-controller execution record - evidence copy-back and physical close pending

The later real-controller work used the clean and published revision
`2600ea414e92099178964b3e53a95f4ccef8e20d`. The workstation created
`/tmp/uvautoboat_real_fcu_bundle_20260821_2600ea4.tar.gz`, reported archive
SHA-256
`fbc9e0967289a7e0c03e14573b75c1b6c51001474f8727aff79b506c8980ef64`, and
copied it to the Pi at `10.120.2.249`. The Pi extracted it at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260821_2600ea4`. All four
governed members verified `OK`, the manifest file retained SHA-256
`8c4f04a69fef395ec70735f6ac5485d315da7955ba6aeb3b76473aa155de2eec`, and
the deployed helper reported:

```text
[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
```

The operator reported the live `BRD_SER1_RTSCTS` value as `Auto` (`2`), changed
it to `0` and rebooted the FCU. A workstation T2b evidence capture then started
and retained its local directory at
`/home/ghostzero/Desktop/real_fcu_capture_t2b_20260821_173347`.

The Pi `run` entry started at 17:35:49 with its initial MAVROS probe. The
retained terminal output ended before the command bridge or any command demand
started:

```text
[real-fcu-pi] REAL_FCU_PI_START mode=run tier=T2b authority=demand-enabled domain=43 discovery=SUBNET run_dir=/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260821_173549
[real-fcu-pi] started mavros-probe pid=7300 pgid=7300 log=/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260821_173549/logs/mavros_probe.log
[real-fcu-pi] STOP: T0b MAVROS parameter pull failed
[real-fcu-pi] stopped mavros-probe
[real-fcu-pi] REAL_FCU_PI_LOGS=/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260821_173549
[real-fcu-pi] REAL_FCU_PI_EXIT status=1 cleanup_rc=0
```

This shows that `BRD_SER1_RTSCTS=0` did not make the existing Pi serial
request/response path pass. The pasted second invocation contains the four
bundle-verification lines but no second `REAL_FCU_PI_START`, `REAL_FCU_PI_LOGS`
or `REAL_FCU_PI_EXIT` marker, so it is not credited as a second retained run.
Changing the ROS domain cannot repair this MAVLink transport failure.

The supervisor-provided `servo_command.cpp` was inspected from the external
download only. It implements FCU/SITL servo-output to VRX command conversion
over UDP, not dashboard/Pi commands to the FCU. Its potentially useful design
clue is an alternative MAVLink UDP transport. QGroundControl forwarding is
one-way, so a command-capable alternative would need direct bidirectional
access to the Herelink endpoint rather than QGroundControl forwarding. No
Herelink-to-Pi network connection was available or configured, and that route
was not run.

End-of-day evidence copy-back and physical closure remain pending. Before a
normal close can be recorded, retain the Pi run directory, stop and finalize
the workstation capture, restore `BRD_SER1_RTSCTS` to `Auto` (`2`), reboot and
read it back, then power down. If restoration cannot be verified, preserve the
controller as configuration-unresolved and perform only the safe power-down.
No serial or UDP retry is scheduled for the remainder of 21/08/2026.

The workstation capture did not finalize after repeated terminal interrupts.
The process was no longer present when inspected, but no
`evidence/verdict.json` existed. Its retained `events.jsonl` parsed completely:
`222` events, `84508` bytes and final sequence `222`, all on `/mavros/state`.
There was no retained command, command-status or output-feedback sequence.
Classify this capture as `PARTIAL_UNFINALIZED`; preserve it, but do not credit
it as T2b evidence and do not restart it today.

The Pi end-of-day inventory found two retained run directories:
`real_fcu_digital_twin_pi_20260821_173549` and
`real_fcu_digital_twin_pi_20260821_173718`. No `mavros_node` process remained,
`sudo -v` returned `0`, and privileged `fuser -v /dev/ttyAMA0` produced no
owner output and returned `1`. The serial endpoint was therefore free before
copy-back. Both exact run directories must be included in the evidence archive;
the second directory remains uninterpreted until its retained files are copied
and inspected.

After the FCU reboot, the operator confirmed the retained rollback value as
`BRD_SER1_RTSCTS=Auto (2)`. This closes the controller-configuration rollback;
the failed run did not leave the candidate `0` in effect. The Pi then created
`/home/imt-aqua-drone/real_fcu_evidence_20260821_2600ea4.tar.gz` with SHA-256
`d913d296c4aecd34ca305339ed1a9591215a75c061dec7552567f647df3643a7`.
Its listing contains both exact run roots, the five-file deployment root and
the transferred deployment archive. Workstation copy-back, checksum
verification and inspection of the second run remain pending.

The workstation copy-back then verified the archive sidecar as `OK`. All four
governed files inside the copied deployment root verified `OK`, and the
preserved transferred bundle rehashed to
`fbc9e0967289a7e0c03e14573b75c1b6c51001474f8727aff79b506c8980ef64`,
matching the workstation's original bundle hash.

Independent inspection resolves both Pi runs. Run `173549` retained four state
attempts: three disconnected samples followed by `connected: true`,
`armed: false`, `mode: MANUAL`. MAVROS detected FCU `1.1`, but every
`AUTOPILOT_VERSION` request and the automatic parameter-list request timed out.
The forced parameter pull started and produced no response before the helper
stopped with `T0b MAVROS parameter pull failed`. Thus the candidate
`BRD_SER1_RTSCTS=0` did not repair the Pi-to-FCU request/response path.

Run `173718` retained `50` state attempts: two disconnected, one connected and
armed in `CMODE(0)`, and `47` connected and armed in `MANUAL`. It created no
`t0b_param_pull.txt`; the helper stopped at its connected-and-disarmed gate
with `T0b MAVROS did not reach connected:true and armed:false`. The bridge and
command publisher never started. This run proves the armed-start guard stopped
the pipeline; it is not a digital-twin or command-path test. Both Pi runs ended
with `status=1 cleanup_rc=0`.

## End-of-day close-out — complete

After the evidence archive was copied back and verified on the workstation,
the operator supplied the final physical-state marker:

```text
PI_OFF_FCU_AUTOPILOT_OFF_CONTROL_ELECTRONICS_OFF_HERELINK_OFF_PROPULSION_POWER_ISOLATED_PROPELLERS_REMOVED_HULL_RESTRAINED_BRD_SER1_RTSCTS_RESTORED_AUTO_2
```

This confirms that the Pi, FCU/autopilot, control electronics and Herelink are
off; propulsion power is isolated; propellers are removed; the hull is
restrained; and `BRD_SER1_RTSCTS` has been restored to `Auto (2)`.

The `BRD_SER1_RTSCTS=0` experiment did not restore parameter request/response
traffic on the direct Pi serial path and was rolled back. The first guarded run
reproduced the timeout while connected and disarmed. The second run started
with the FCU armed and was stopped by the connected-and-disarmed guard before
the parameter pull, bridge or command publisher could run. No RC override,
motor command or thrust command was issued by the repository pipeline.

The workstation capture remains `PARTIAL_UNFINALIZED`: its event file contains
state samples, but no verdict was written. T0b remains open, and neither T2a nor
T2b acceptance was earned. No physical approval carries forward beyond this
close-out. This final section supersedes every earlier interim `pending`
statement in this execution record. Any later powered continuation requires a
new operator instruction and should choose a diagnostic that can distinguish
the remaining direct-link transmit, receive and endpoint hypotheses rather
than repeat either failed run.
