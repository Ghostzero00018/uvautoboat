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
