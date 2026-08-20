# Friday 21/08/2026 - T0b request-path continuation

**PRE-DIARY - NOT STARTED.**

This is the sole 21/08/2026 continuation for the guarded real-FCU track. It
carries no approval from 20/08/2026.

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
