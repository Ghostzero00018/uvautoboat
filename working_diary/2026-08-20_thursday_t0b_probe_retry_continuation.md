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
