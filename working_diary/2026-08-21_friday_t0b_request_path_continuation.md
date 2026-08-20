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
3. **Bound the real-FCU track for the day.** The hardware allowance is the
   Herelink read, at most one separately approved T1 change, read-back and
   rollback cycle, and, only after T1 closes cleanly, at most one separately
   approved T0b probe. If that probe does not close T0b, stop the hardware
   track and propose a separately approved motor-twin and dashboard block; this
   paragraph does not authorize starting it. Do not invent a further diagnostic
   variant to keep the track alive.

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
`95a42c61afa69d7f0fac80fe5ef12cf7d67077f2` before relying on it, and confirm
that no non-Markdown tracked file changed after
`f8e440a81d8f08318b089814c05329b21ddafd1c`. If one did, the deployed bytes and
the `24`-case suite evidence must both be re-established before continuing.

Then re-verify the governed artifacts on the workstation:

```bash
sha256sum -c config/real_fcu_digital_twin_bundle.sha256
sha256sum config/real_fcu_digital_twin_bundle.sha256
bash tools/test_real_fcu_digital_twin_helpers.sh
```

Require four member lines reporting `OK`, a manifest digest of
`2f595b63fe2248c5dada5f5f9fc8f5f69c973df0bfaa434f1fd99c0b60613642` and a final
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

Stop after the read. A T1 candidate change from `2` to `0` requires a separate
same-day approval, prior-value capture, an explicit rollback, any required
reboot and a retained read-back. A fresh T0b probe requires another approval
after T1 closes cleanly.

## Boundaries

- Start with the FCU disarmed, hardware safety ON, propulsion power isolated,
  propellers removed, hull restrained, and Herelink sticks and trims neutral.
- No approval or physical attestation crosses the date boundary.
- Arming is not part of this continuation. An armed start would bypass the open
  parameter, mapping and rail gates.
- No simulator and real-FCU supervisor overlap.
- Preserve every 20/08/2026 deployment, lock, transcript and evidence path.
- Stop at the first failed certification, safety, serial-owner, evidence or
  cleanup gate. Do not retry with the same method.
