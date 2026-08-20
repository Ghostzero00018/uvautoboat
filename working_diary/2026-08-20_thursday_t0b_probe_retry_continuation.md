# Thursday 20/08/2026 - T0b probe retry continuation

This is the sole 20/08/2026 continuation for the guarded real-FCU track. It
starts with certification and contains no inherited approval. Read the complete
19/08/2026 execution record and close-out before using this scaffold.

## Starting boundary

The source repair is landed at
`dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`: every state capture attempt has an
isolated YAML copy and sibling diagnostic log, including diagnostics from the
process writing both retained copies. The complete physical-helper suite passed
`24` cases after the bundle manifest was regenerated.

Block D Gate 1 passed on 19/08/2026 for the five-file deployment at
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260819`: exact inventory,
pinned manifest digest, `4/4` member verification and the helper's
non-actuating `check` all passed. The preserved 18/08 deployment root remains
historical and must not be reused, overwritten or deleted.

Block E did not run on 19/08/2026. No Block E serial session, controller or
Herelink power-up, parameter write, bridge start or real thrust occurred. Its
approval expired unused at the date boundary. The probe-safety audit was still
pending at close-out, and the final 19/08 physical shutdown confirmation was
still required.

## 20/08/2026 repository close-out - documentation only

The first task on 20/08/2026 is to publish the 19/08/2026 close-out and this
continuation file, which remained local after the campus Wi-Fi interruption.
This is repository-only work. It does not complete the fresh-day physical
certification below, provide the missing 19/08/2026 powered-off attestation or
authorize Block E.

A fresh fetch established the pre-publication baseline
`HEAD == main == origin/main == dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`
with divergence `0/0`. The pending scope contains only five Markdown files:
the appended 19/08/2026 diary, this sole 20/08/2026 continuation, `Board.md`,
`wiki/Roadmap.md` and
`web_dashboard/autoboat/README_autoboat_dashboard.md`. The four manifest
members verified `4/4`, the helper and manifest retained the recorded sizes and
digests, and the complete physical-helper suite passed `24` cases again. No Pi,
controller, Herelink, serial, simulator or browser action was run for this
repository close-out.

The publication revision is intentionally not predicted here. After the push,
verify the live commit subject, divergence `0/0` and
`HEAD == main == origin/main` before treating this close-out as published.

## Read first

1. Read the 19/08 diary from `## 19/08/2026 execution record` through its EOD
   close-out, including the corrected seven-field Block E handover.
2. Read the current 19/08 supersessions in `Board.md`, `wiki/Roadmap.md` and
   `web_dashboard/autoboat/README_autoboat_dashboard.md`.
3. Read `rfcu_pi_require_probe_gates`, `rfcu_pi_static_preflight`,
   `rfcu_pi_capture_topic`, `rfcu_pi_wait_connected_disarmed`,
   `rfcu_pi_capture_t0b`, `rfcu_pi_cleanup` and `rfcu_pi_probe` in
   `tools/real_fcu_digital_twin_pi.sh`.
4. Read `config/real_fcu_digital_twin_bundle.sha256` and re-establish the current
   helper and manifest bytes before reusing the `24`-case result.
5. Read and accept the completed probe-safety audit. If it has not completed or
   raises an unresolved finding, Block E stays closed.

## Block A - fresh-day certification only

First fetch and certify the live revision. Do not predict the documentation
commit that contains the 19/08 close-out:

```bash
git fetch --prune
git status --short --branch
git log --oneline -14
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
git log -1 --format='%H%n%s'
```

Require a clean worktree and index, `HEAD == main == origin/main` and divergence
`0/0`. Compare the live log with the 19/08 baseline and inspect every later
commit before relying on it. Confirm no non-Markdown tracked file changed after
`dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa`; otherwise the source and suite
evidence must be re-evaluated.

Reverify the four manifest members, the manifest's own digest, the two
production artifacts and their `13` operational pin surfaces, and the separate
adjudicator digest. Recheck free disk, the six reserved endpoints and the scoped
process list. Re-establish the current physical state directly; no prior-day
power or safety attestation carries forward.

The Pi deployment and environment must also be re-certified after the day
boundary and any Pi power cycle. Every Pi command remains operator-run in a
real terminal opened through Remmina. Do not energise the controller or
Herelink merely to run the non-actuating deployment `check`.

After Block A reports, stop. Block E requires a new explicit approval even if
all certification passes.

## Block E - one T0b probe, separately approved

Only a fresh Block E approval can activate the corrected handover in the 19/08
diary. Before launch, require the accepted safety audit, separate `sudo -v`
success, blank privileged `fuser` output with return code `1`, clean environment
prefixes and a fresh physical confirmation. Keep Herelink off unless it is the
only established read-only way to confirm the controller is disarmed.

If approved, run the helper once in the foreground and let its own deadline
resolve. A healthy but slow path can remain silent for about `544 s` plus small
overhead. Read every retained state attempt and diagnostic before concluding,
state explicitly whether `connected: true` and `armed: false` ever occurred,
and do not retry after any failure.

Success still requires all of these markers and a matching process return code:

```text
REAL_FCU_T0B=PASS serial=/dev/ttyAMA0 parameter_reads=41 safety=ON mapping=retained rails=retained
REAL_FCU_PROBE_VERDICT=PASS writes=none bridge=not-started
REAL_FCU_PI_EXIT status=0 cleanup_rc=0
```

## Boundaries

- T1, T2a, T2b, arming, mode changes, parameter writes, RC override, motor tests
  and real thrust are not authorized by this scaffold.
- No simulator and real-FCU supervisor overlap.
- Propulsion remains isolated, propellers removed and the hull restrained.
- The 18/08 deployment root remains untouched. Do not create a third deployment
  root without a separately approved reason.
- Any audit, certification, physical-state, serial-owner, evidence or cleanup
  failure ends the probe plan for the day without retry.
- Append results only to this file. Preserve all earlier dated records as
  history.

## Block A result - stopped at the probe-safety audit

Block A started on 20/08/2026 and stopped before any Pi or physical action.
The repository and workstation portions passed their bounded checks:

- A fresh fetch established
  `HEAD == main == origin/main == f7b2d9c4c053823190768a0dc75884b95d3d7062`,
  divergence `0/0` and a clean worktree and index before this result was
  appended. Every tracked change after
  `dc90a8ffa9d114f4af5ea716b7ffb2526a7944aa` is Markdown-only.
- The four bundle members verified `4/4`. The helper, manifest, supervisor,
  preflight and adjudicator retained their recorded sizes and digests, and all
  `13` operational pin surfaces matched. The existing `24`-case helper result
  remains applicable because no executable byte changed after the tested
  revision.
- The workstation had `21055528 KiB` available, above the `10485760 KiB`
  floor. TCP ports `5760`, `5762`, `8002`, `8080` and `9090`, UDP port `14600`
  and the `20` scoped process patterns had no conflict.

The probe-safety audit did not pass. The helper's `probe` path contains no
direct arming, mode-change, parameter-write, RC-override or motor command, and
its T0b plugin list is limited to `sys_status` and `param`. However, the last
verified Pi MAVROS release is `2.14.0`, whose `param` plugin creates the
write-capable `~/set` service and whose `sys_status` plugin creates the
write-capable `~/set_mode` service. The helper also forces
`ROS_DOMAIN_ID=43` with `ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` and removes
static-peer restrictions. The current deployment therefore does not prevent a
different ROS participant on the reachable subnet from discovering and calling
those endpoints. A local process check cannot establish the required
network-wide no-write and no-mode-change boundary.

The Pi deployment and environment were not re-certified because any accepted
correction to this finding would change the helper, manifest and deployed
bytes. The fresh physical state was not requested or inferred. No Remmina, Pi,
controller, Herelink, serial, simulator, browser, parameter, bridge, arming,
mode, RC override, motor or thrust action occurred.

Block A is incomplete and Block E remains closed. Continuing requires a
separately approved code and configuration repair that isolates the probe ROS
graph or otherwise enforces the no-write boundary, followed by focused tests,
manifest regeneration and an explicitly approved deployment disposition. The
18/08 and 19/08 deployment roots remain untouched.

## Block A safety repair - local verification passed

A separate code and configuration repair was approved on 20/08/2026. This
approval covered local source, test and manifest work only. It did not approve
Pi deployment, physical certification or Block E.

### Audit correction

The two write-capable services named in the preceding audit result were
examples, not an exhaustive inventory. The locally installed
`ros-jazzy-mavros` package is
`2.14.0-1noble.20260615.151804`. Its installed plugin library and the matching
MAVROS source establish at least these five state-changing endpoints in the two
T0b-allowlisted plugins:

| Plugin | Service | State-changing effect |
| --- | --- | --- |
| `param` | `~/set` | Write one FCU parameter |
| `param` | `~/push` | Push ROS-side parameter values to the FCU |
| `sys_status` | `~/set_mode` | Change flight mode |
| `sys_status` | `~/set_stream_rate` | Change telemetry stream rate |
| `sys_status` | `~/set_message_interval` | Change message intervals |

`~/pull` is the required FCU-to-ROS read path and is not included in that
table. The `cmd` plugin is absent from the T0b allowlist, so this surface does
not expose its arming services. The exposure is parameter, mode and telemetry
configuration state, not arming. The inventory is stated as a minimum because
the `param` plugin also has standard ROS parameter mutation callbacks.

### Repair boundary

The top-level `probe` call path is Pi-local: it selects `probe` mode before
static preflight, starts only `mavros-probe`, performs the local state and
parameter captures, and never waits for workstation nodes or starts the command
bridge. The helper now selects
`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST` only for that top-level mode. `check`,
`run-t2a` and `run` retain `ROS_DOMAIN_ID=43` with
`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, preserving their existing workstation
contract. The start marker and retained environment manifest report the
effective discovery range instead of assuming `SUBNET`.

A different fixed domain was not added: a domain number partitions discovery
but is not an access-control boundary. `LOCALHOST` directly removes the
identified off-host campus-subnet discovery path without changing the
workstation-connected run modes. It does not remove the MAVROS services or
authenticate an arbitrary same-Pi caller. Any later Block E preflight must
therefore retain exclusive Pi process ownership and stop on an unexpected
local participant.

### Verification

The new regression first failed against the old helper with:

```text
FAIL: Pi probe ROS boundary is not localhost-only: 43|SUBNET|0|unset|unset|unset|unset|unset|unset
```

After the source change, the suite advanced to the expected stale-manifest
boundary and failed only because the helper digest no longer matched. The
bundle manifest was then regenerated and all four members verified. Final
local results were:

```text
PASS cases=24
tools/real_fcu_digital_twin_pi.sh: OK
tools/real_fcu_rc_command_bridge.py: OK
config/mavros_real_fcu_closed_loop_plugins.yaml: OK
config/mavros_real_fcu_t0b_plugins.yaml: OK
```

`bash -n` passed for the helper and complete shell test. `shellcheck` was not
installed, so no ShellCheck result is claimed. The changed local artifacts are:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `tools/real_fcu_digital_twin_pi.sh` | `31692` | `badb26721d7358a46b0183096008ea18f2ea08e0bc55c072ddf1012a59cbbd77` |
| `tools/test_real_fcu_digital_twin_helpers.sh` | `45755` | `91a7c7cb261876cfd5b5ea1f5904853a762d3922fdbcea46b00b4f41c6cfb885` |
| `config/real_fcu_digital_twin_bundle.sha256` | `422` | `2f595b63fe2248c5dada5f5f9fc8f5f69c973df0bfaa434f1fd99c0b60613642` |

The identified off-host probe exposure is corrected and locally tested, but
the corrected bytes have not been deployed to the Pi. Both existing dated
deployment roots retain their historical bytes. No Remmina, Pi, controller,
Herelink, serial, simulator, browser, parameter, bridge, arming, mode, RC
override, motor or thrust action occurred during this repair. Block A remains
incomplete until a separately approved new deployment disposition, Pi
certification and fresh physical attestation pass. Block E remains closed and
requires its own later approval.

## Block A deployment and non-actuating check - passed

The separately approved Block A deployment disposition ran on 20/08/2026.
The preceding incomplete status is superseded by this appended result.

The workstation transfer completed at
`f8e440a81d8f08318b089814c05329b21ddafd1c`. Before payload transfer, the Pi
preflight passed on `imtaquadrone-desktop` as `imt-aqua-drone` at
`10.120.2.249`; both historical deployment roots were present and the new
root, payload and check-log paths were absent. The transferred archive and
deployment guard were then verified on the Pi with these SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| Five-member transport archive | `26a5898bc89c9b5446cd1b3b25b0db40bdb2328c60299d4a2cf5877403ee7733` |
| Deployment guard | `9660408336e19f0bf7d34a7959e04b7343c600765fb4e96352267b432acc48f0` |

Before deployment, the operator freshly attested that the Pi was on, the
controller and Herelink were off, propulsion was isolated, propellers were
removed and the hull was restrained. `sudo -v` passed. Privileged
`fuser -v /dev/ttyAMA0` returned blank output with return code `1`, and the Pi
reported `35814760 KiB` available.

The archive inventory passed with five members: the manifest plus its four
bundle members. The corrected bytes were installed once in the new root
`/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820`. The manifest digest
was `2f595b63fe2248c5dada5f5f9fc8f5f69c973df0bfaa434f1fd99c0b60613642`,
and all four governed members verified `4/4` with the expected inventory and
sizes. The 18/08 and 19/08 roots were not deployment targets.

The deployed helper's `check` command returned `0`, produced an empty stderr
log and ended with:

```text
[real-fcu-pi] REAL_FCU_PI_CHECK=PASS serial=/dev/ttyAMA0 runtime=not-started
```

Its retained outputs are:

- `/home/imt-aqua-drone/block_a_check_20260820_f8e440a.stdout.log`
- `/home/imt-aqua-drone/block_a_check_20260820_f8e440a.stderr.log`

The final process and privileged serial-owner checks also passed. The accepted
terminal marker was:

```text
BLOCK_A_DEPLOYMENT_CHECK=PASS revision=f8e440a81d8f08318b089814c05329b21ddafd1c root=/home/imt-aqua-drone/uvautoboat_real_fcu_bundle_20260820 archive_sha256=26a5898bc89c9b5446cd1b3b25b0db40bdb2328c60299d4a2cf5877403ee7733 manifest_sha256=2f595b63fe2248c5dada5f5f9fc8f5f69c973df0bfaa434f1fd99c0b60613642 members=4/4 check_rc=0 check_stderr=empty runtime=not-started
```

Block A is complete. No serial probe, MAVROS runtime or command bridge started,
and no parameter write, arming, mode, RC, motor or thrust action was authorized
or run by this workflow. Block E remains closed and requires a separate explicit
approval.

## Block E execution and end-of-day result

Block E was subsequently approved and executed against the certified
`f8e440a81d8f08318b089814c05329b21ddafd1c` deployment. The preceding
Block-E-closed status is superseded by the results below; it remains the correct
boundary for all work before the separate approval.

Two early probe sessions did not reach the connected/disarmed gate. The first
run directory was
`/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260820_164430`; all
`58` retained attempts reported `connected: false` and `armed: false`, and the
helper exited `status=1 cleanup_rc=0`. Its copied archive verified at SHA-256
`5970beb498278999db781151d9b081b32dc6382645ae06cbe7e9ec14bbe0bca0`.
The later run at
`/home/imt-aqua-drone/Desktop/real_fcu_digital_twin_pi_20260820_171457`
retained `45` attempts with the same disconnected/disarmed state and also
exited `status=1 cleanup_rc=0`. Neither session reached parameter capture,
started the bridge or changed controller state.

### Powered UART isolation - passed

A separately approved receive-only diagnostic then read `/dev/ttyAMA0` at
`57600` for `30.001 s` while sending no serial bytes. It captured `23868` bytes
and decoded `30` valid heartbeats from system/component `1.1`; every decoded
heartbeat reported `armed: false` and system status `4`. The diagnostic ended:

```text
UART_DIAG_WRAPPER=PASS serial=/dev/ttyAMA0 baud=57600 bytes=23868 heartbeats=30 armed=false serial_bytes_written=0 hardware_state=powered-safe
```

The complete three-file evidence copy is retained on the workstation at
`/home/ghostzero/Desktop/pi_run_evidence/powered_uart_diag_20260820_f8e440a`.
Its raw capture, summary and console SHA-256 values are respectively
`7fe93e2f150c43062097212148cc70a207804d232ce52b17604f7b2d2def330a`,
`ca0932e7a6e3e700ae09ca9d7281379cd4c53de57aa7c2fc8a2e6d53aa2b825f`
and `a982f782c41659df9ad958b8d9523e94bcbdcec5e718305249f43c36dd4b1f1c`.
This proves powered FCU-to-Pi heartbeat delivery and disarmed state only; it is
not parameter-exchange evidence.

### Full T0b execution - parameter exchange failed

The final one-shot run started at `18:07` with the FCU/control electronics and
Herelink powered, propulsion power isolated, propellers removed, the hull
restrained, hardware safety ON, the FCU disarmed, and Herelink controls neutral.
The standalone probe retained `ROS_DOMAIN_ID=43` with
`ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`; the bridge remained not started.

MAVROS opened `/dev/ttyAMA0:57600`, detected remote address `1.1` and logged
`CON: Got HEARTBEAT, connected. FCU: ArduPilot`. The state gate passed with
`connected: true`, `armed: false`, `mode: MANUAL` and `system_status: 4`.
`/mavros/sys_status` was also captured, and the helper's `32768` hardware-safety
bit check passed with `sensors_enabled: 52494383`.

The required parameter stage did not pass. MAVROS exhausted all three automatic
parameter-list attempts, logging retries `2`, `1` and `0`. The explicit forced
pull then started but returned no service response before its bounded timeout.
The helper stopped at `T0b MAVROS parameter pull failed` and exited
`status=1 cleanup_rc=0`. It did not create `t0b_parameters.txt` or `t0b.json`,
so none of the required `41` parameter reads, live mapping or live rail evidence
was earned. No parameter write, mode change, arming, RC override, motor action,
thrust action or command-bridge start occurred.

The copied E4 evidence is retained at
`/home/ghostzero/Desktop/pi_run_evidence/block_e4_full_retry_20260820_f8e440a`.
The archive and wrapper-transcript SHA-256 values are respectively
`f0c04727f175ffb2f3e95f6f0f7925be10b1b09bbc0283b633fa5b377ab08fd1`
and `be9830dbca8ce03a8f532f97d0937e3a66e3466a5a22a43b85fe6c5dc7070767`.
The wrapper's final physical confirmation retained the same powered-safe state,
and the final serial-owner and process-conflict checks passed.

### Accepted boundary and continuation

The full repository T0b path did run on real hardware, but its acceptance
contract did not pass. Today established a connected, disarmed, hardware-safe
MAVROS session and reproducible inbound FCU telemetry; it also confirmed that
both the automatic and explicit MAVROS parameter pulls receive no parameter
response. T0b remains open. T1, T2a, T2b and every higher physical tier remain
closed.

Repeating the same full pull is not the next step. The established T1 decision
point is now the direct continuation: in a separately approved session, read
and retain the live `BRD_SER1_RTSCTS` value through the working Herelink ground
station, allow only the previously scoped candidate change from `2` to `0`,
reboot if required, read the value back, and retain an explicit rollback. A
fresh T0b execution may follow only after that session closes cleanly and gains
its own approval. No T1 write was performed or authorized on 20/08/2026.

The operator's final powered-off physical confirmation is still required before
the 20/08/2026 hardware day is fully closed.

### Powered duplex isolation - completed without a request response

The first duplex helper stopped in its offline pseudoterminal self-test before
physical attestation, one-shot lock creation or serial access. Repeated local
execution isolated a scheduler-sensitive integration assertion. Its replacement
retained the live diagnostic scope but used deterministic packet checks; those
checks passed `100` consecutive local executions. A first invocation of the
replacement then stopped on a literal attestation mismatch, again before lock
creation or serial access. Neither stopped invocation contacted the FCU.

The accepted E5R invocation started from a freshly attested powered-safe state:
the FCU and control electronics were on, the FCU was disarmed, hardware safety
was ON, Herelink was on in read-only use with neutral sticks and trims,
propulsion power was isolated, propellers were removed and the hull was
restrained. No conflicting process or serial owner was present.

During its bounded `18.020 s` capture, E5R read `14326` bytes and decoded `18`
valid heartbeats from target `1.1`. Every heartbeat was disarmed, and no known
frame CRC error occurred. The helper then transmitted exactly two audited
MAVLink frames from `255.191` to the live serial endpoint:

- one broadcast PING, message ID `4`, `24` bytes;
- one `PARAM_REQUEST_READ` for `SYSID_THISMAV`, message ID `20`, `29` bytes,
  targeted to `1.1`.

The outbound capture therefore contains exactly `53` bytes. It contains no
parameter write, command, mode, arming, RC, motor or thrust message. No PING
response and no matching `PARAM_VALUE` response arrived. The diagnostic
completed without a serial error and ended with:

```text
E5R_RESULT=FAIL_NO_REQUEST_RESPONSE writes=2 bytes_written=53 ping_responses=0 parameter_responses=0 state_changes=0
E5R_WRAPPER=PASS verdict=FAIL_NO_REQUEST_RESPONSE ping_responses=0 parameter_responses=0 writes=2 bytes_written=53 state_changes=0 hardware_state=powered-safe summary_sha256=f59de78b649d66e559ed9925bd404c78499fb291e552a1b52c68adfaaad2b6f1 no_retry=1
```

The complete copied evidence is retained at
`/home/ghostzero/Desktop/pi_run_evidence/powered_duplex_e5r_20260820_f8e440a`.
The archive, wrapper transcript, inbound capture and outbound capture SHA-256
values are respectively:

- `c1c73f8df65e5f109adc051d3f04990ce646830a4741ec628cd100090d993802`;
- `225c5e5ce11ca1a56210186058d29fffcb0000c725fbbbbe370a37420ee19c4e`;
- `fdc7340b2e33e96af365da78924c429e343b3ff693ebed205ca51053108d9419`;
- `36e670ee4b4b91e901811e2e3a8ee23ff3ffc9768a2d5ba2e02e0313e52e6f5c`.

The archive sidecar, all five governed artifacts and the independent outbound
frame audit passed after copy-back. This proves live FCU-to-Pi heartbeat ingress
and proves the exact two Pi-side serial writes. It does not prove that either
request reached the FCU parser, and it does not distinguish a Pi-to-FCU
electrical path fault from FCU-side request handling. T0b therefore remains
open. The next bounded decision remains T1's separately approved
`BRD_SER1_RTSCTS` read, prior-value capture, candidate change, read-back and
rollback. T2a, T2b, arming and every higher physical tier remain closed.

The operator re-attested the powered-safe state after E5R. A current powered-off
confirmation is still required before the physical day can be closed.

## End-of-day close-out - complete

The preceding powered-off-pending statement is superseded. After evidence
copy-back and verification, the operator freshly confirmed this current state:

```text
FCU_AUTOPILOT_OFF_CONTROL_ELECTRONICS_OFF_HERELINK_OFF_PROPULSION_POWER_ISOLATED_PROPELLERS_REMOVED_HULL_RESTRAINED
```

The FCU/autopilot, control electronics and Herelink are off. Propulsion power is
isolated, propellers are removed and the hull is restrained. This closes the
20/08/2026 physical hardware day. T0b remains open, T1 and both T2 tiers remain
closed, and no approval or physical attestation carries into 21/08/2026.
