# Wednesday 05/08/2026 - probe dry-run and first enabled run

> **Prepared as a pre-diary at EOD 04/08/2026; Gate 0 has since run and the
> corrections appended below supersede parts of it.** Blocks A and B still
> require explicit approval before they start. Block A is offline on the Pi.
> Block B is live and needs the Pi, control box, workstation supervisor and
> browser. No FCU write, no arming, no motor command, no dataset or detector
> work.

## Starting state

- Clean `main` at `0169553`, the last of five 04/08/2026 commits: `63d6e9a`
  carries the batched source view; `c8a0ecd`, `12bcc6a`, `3bfcdde` and
  `0169553` the documentation. Certify `HEAD == main == origin/main == 0169553`
  with divergence `0/0` before starting. If `HEAD` is later, inspect every
  intervening commit first.
- Operator reference for the flag and the probe budget is the "Batched MAVROS
  source view" section of
  [Live_Hailo_MAVLink_Dashboard_Testing](Live_Hailo_MAVLink_Dashboard_Testing).
- Pi helper `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`,
  `71,501` bytes, already on the Pi Desktop and verified there. No re-transfer
  unless the helper changes.
- `LIVE_MAVROS_SOURCE_BATCH` defaults to `0`. The batched path has never run.
- Flag-off canary complete: `2` non-verifying readings in `2` episodes, both
  publisher-count-zero, both recovered on attempt two, `monitored=120s` equal to
  `target=120s`, clean exit. Recorded in the 04/08/2026 diary.
- Pi `rclpy` lifecycle measured idle at `1.701 s` against a `3 s` startup
  reserve inside a `6 s` bound. Under run load it is unmeasured.

## Scope note

Per-run flag-off reading counts are `11`, `3` and `2`. A control that varies by
more than five times per run cannot be separated from a modest improvement by a
handful of enabled runs, so today is **feasibility only**: does the batched path
run on the Pi, stay inside its budget, serve all five topics, and leave the
window and final verification intact. No reduction claim comes out of today.

## Block A - probe dry-run, offline

The 04/08 run directory preserved the generated probe, so it can be executed on
its own with no stack running. This answers the startup-margin question before
any live time is spent.

Pi desktop terminal, nothing else running:

```bash
RUN=~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260804_172331
[ -f "$RUN/mavros_source_probe.py" ] \
  || RUN=~/Desktop/pi_run_evidence/live_dashboard_20260804_172331
time python3 "$RUN/mavros_source_probe.py" 3 \
  /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
  /mavros/battery /mavros/rc/in
```

The first path is the run directory the helper wrote; the second is the copy
taken at day close on 04/08. If neither exists the probe was not preserved, and
Block A is replaced by regenerating it from a fresh `--preflight-only` run
before any live time is spent.

Expected with no MAVROS running: five `TOPIC:` blocks, each with
`Publisher count: 0` and no endpoint records, exit `0`, and a real time near
`4.7 s` - about `3 s` of settle plus the measured `1.7 s` of startup and
teardown.

Read the result as:

- real time comfortably under `6 s`: the default budget holds, continue.
- real time at or above `6 s`: the bound is too tight on this host. Use
  `LIVE_PROBE_MAX_SECONDS=8` and `LIVE_PROBE_STARTUP_RESERVE=5` in Block B and
  record that the run used non-default budgets. This is a host-capacity result,
  not a defect.
- non-zero exit, an import error, or a malformed block: stop. Capture the output
  and do not start Block B; the enabled run would only fail closed repeatedly.

This block touches no hardware beyond the Pi itself and starts no service.

## Block B - one enabled run

Explicit approval required, and only if Block A is clean.

Workstation first: `tools/live_dashboard_preflight.sh run` in W1, foreground,
left running. Pi second, in the desktop terminal P1:

```bash
export LIVE_MAVROS_SOURCE_BATCH=1
```

then paste the compound command W1 printed, unedited. Stop Pi first, then the
workstation, matching the 04/08 ordering exactly.

Extract afterwards:

```bash
RUN=~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_<stamp>
grep 'MAVROS_SOURCE_PROBE_RUN result=' "$RUN/supervisor.log" \
  | sed 's/.*result=/result=/' | cut -d' ' -f1 | sort | uniq -c
grep 'PI_SOURCE_WINDOW' "$RUN/supervisor.log"
grep 'MAVROS_SOURCE_EVIDENCE' "$RUN/supervisor.log" | grep -v ' raw: '
grep -c 'PI_SUPERVISOR_EXIT status=0' "$RUN/supervisor.log"
```

Feasibility acceptance:

- at least one `result=OK` carrying `bound=` `settle=` `reserve=`;
- `monitored=` equal to `target=`;
- final verification inside its budget;
- clean teardown and `status=0`.

Failure classification. The helper emits five `result=` values; all five need a
reading, because the extraction above will surface whichever occurs:

- `result=OK` is the feasibility case above.
- `result=TIMEOUT` is a startup-margin result; raise the two budget variables,
  keeping the bound above the reserve.
- `result=INCOMPLETE` is a partial or malformed generation; keep the raw
  diagnostics.
- `result=FAILED` is the probe running and not producing a usable generation.
  This is a defect in the batched path, not a capacity result, so do not raise
  the budgets in response. Keep the raw output and stop after the run.
- `result=SKIPPED` means the batched path did not execute at all. Treat the run
  as void for feasibility: check that `LIVE_MAVROS_SOURCE_BATCH=1` was exported
  in the same shell that ran the pasted command, since the flag defaults to `0`
  and an unexported flag reproduces the 04/08 canary rather than testing
  anything new. `0` `MAVROS_SOURCE_PROBE_RUN` records and no `source_view` cache
  are the same two witnesses used on 04/08 to confirm a flag-off run.
- A view returning `75` is genuine parent-deadline exhaustion, not a probe
  timeout.
- `monitored=` shorter than `target=` is a truncated window; the run is void.

## Block C - record and decide

Record the Block A timing, the Block B probe outcomes, readings and episodes,
window and final-verification durations, and thermal peak. State the feasibility
verdict.

Then decide whether further enabled runs are worth scheduling, and say what
would make them informative given the control variance. Do not schedule a run
count today.

## Acceptance

- Block A produces a timing figure and a verdict on the default budget.
- Block B either meets feasibility acceptance or the day records exactly why not.
- No effect-size claim is made.

## Non-claims to retain

- Feasibility does not mean the graph race is fixed or explained.
- The lower DDS/RMW/network trigger stays unidentified.
- Browser-last ordering remains open.
- The `live_dashboard_20260724_175832` cumulative timing cause stays open.
- Post-teardown temperature, endurance, GPS fix, detector quality and all FCU
  write paths remain out of scope.

**Next steps:** after approval, run Block A, report the timing, and gate Block B
on it.

## Gate 0 certification and pre-Block A corrections (05/08/2026)

Gate 0 ran from the clean pushed revision
`959612d60d6b50bc37ff2865b226952ed848f997`, with `HEAD == main == origin/main`
and divergence `0/0`, a clean worktree and index, and this file as the sole
05/08/2026 diary. `959612d` is one commit past the `0169553` named in the
Starting state above and carries only the 04/08/2026 day-close revision
correction and the hardening of this runbook, so the starting pins remain
current and were re-verified against the actual files:
`tools/pi_live_hailo_mavlink_dashboard.sh` at `71,501` bytes /
`31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa`, and
`tools/live_dashboard_preflight.sh` at `28,647` bytes /
`958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877`.

Reading the helper against this runbook found four defects. Three of them are
in the Block A command block and each would have cost live time or produced a
false verdict. No production file is changed; these are documentation
corrections and they supersede the Block A and Block B sections above where
they differ.

### The `result=SKIPPED` reading was wrong

The Block B failure classification above states that `SKIPPED` means the batched
path did not execute. It does not. `result=SKIPPED reason=deadline-exhausted` is
emitted at `tools/pi_live_hailo_mavlink_dashboard.sh:659`, inside
`mavros_source_probe_generation`, which is reached only when the batched path is
active. It fires when a finite parent deadline has one second or less remaining,
so the probe is deliberately not started, and it returns `75`. Its meaning is
"the batched path was running and declined this attempt because the parent
budget was already gone" - the opposite of the earlier reading. `SKIPPED`
appearing in a run log is positive evidence that the flag was set.

The flag-off signature is different and unambiguous: no
`MAVROS_SOURCE_PROBE_RUN` line of any kind is emitted, so the extraction's
`sort | uniq -c` prints nothing at all. That, together with an absent
`$RUN_DIR/source_view` cache, is exactly the pair of witnesses recorded on
04/08/2026.

The corrected classification of the five values, read from the helper:

| Value | Site | Meaning |
| --- | --- | --- |
| `OK` | `:717` | All five blocks validated and published by rename. Carries the `bound`, `settle` and `reserve` actually used. |
| `TIMEOUT` | `:683` | `timeout --signal=KILL` fired with `rc` `124` or `137`. Host startup margin. Returns `1` and retries; returns `75` only if `SECONDS` genuinely reached the parent deadline. |
| `INCOMPLETE` | `:701` | Probe exited `0` but one topic's block failed validation. Names the offending topic. |
| `FAILED` | `:671`, `:694`, `:709`, `:714` | Four causes: `reason=cache-unavailable`, a bare `probe_rc=<n>`, `reason=staging`, `reason=publication`. A defect, not capacity; do not raise the budgets in response. |
| `SKIPPED` | `:659` | Parent deadline exhausted before the probe started, batched path active, returns `75`. |

`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md` documents `OK`, `TIMEOUT` and
`INCOMPLETE` and omits `FAILED` and `SKIPPED`. That gap is recorded here and
left for a later documentation pass.

### Block A had no ROS environment

The Block A block above calls `python3` on the probe with no
`source /opt/ros/jazzy/setup.bash`. The helper sources it at `:1340` before ever
invoking the probe. In a bare Pi desktop terminal `import rclpy` fails, the
probe exits non-zero, and that reads as the third outcome listed above - stop,
do not start Block B - from a false negative unrelated to the batched path. The
corrected block mirrors `:1340-1347` exactly, including `ROS_DOMAIN_ID=12`,
`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET` and the seven unsets, because domain and
discovery range affect participant-creation cost, which is the quantity being
measured.

### The stated Block A fallback cannot work

Regenerating the probe from a fresh `--preflight-only` run is impossible.
`--preflight-only` exits at `:1352`; the probe heredoc is written at `:1420`. A
preflight-only run never materializes the file.

### The secondary path is a workstation path

`~/Desktop/pi_run_evidence/live_dashboard_20260804_172331` is where the
04/08/2026 Pi run directory was copied on the workstation. Block A runs on the
Pi, where that path does not exist.

### Verified replacement for both fallback defects

The probe heredoc is quote-delimited, so its content is fixed and derivable from
the pinned helper with no run at all. Three independent derivations agree:

| Source | SHA-256 | Size |
| --- | --- | --- |
| Tracked helper, lines `1421-1474` | `571be8f5811488f8a47903f2857f62a82be54f126e562fea343bdb202207bff4` | `1,316` bytes |
| Tracked helper, marker-anchored extraction | same | same |
| The artifact the Pi generated on 04/08/2026 | same | same |

So the file the Pi wrote is byte-identical to what the pinned helper produces.
`571be8f5811488f8a47903f2857f62a82be54f126e562fea343bdb202207bff4` becomes an
identity check on the preserved copy, and marker-anchored extraction from the
hash-verified deployed helper becomes the fallback. The helper hash is checked
before extraction, so drift is caught before any measurement rather than after.

### Corrected Block A

This supersedes the Block A command block above. Pi desktop session, one new
terminal, all commands one-shot, nothing left running. Working directory `~`.
No filesystem write on the primary path; the fallback writes `1,316` bytes into
`~/probe_dryrun_2026-08-05/`. Each probe self-terminates at its `3 s` settle
budget; if any single run has not returned within `15 s`, interrupt it and treat
that as the reading.

Step 1, environment and preconditions:

```bash
cd ~
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY ROS_STATIC_PEERS ROS_DISCOVERY_SERVER
unset RMW_IMPLEMENTATION FASTDDS_DEFAULT_PROFILES_FILE
unset FASTRTPS_DEFAULT_PROFILES_FILE CYCLONEDDS_URI
pgrep -af 'pi_live_hailo_mavlink_dashboard|mavros_node|hailo_coco|mavproxy' \
  || echo 'NONE_RUNNING'
uptime
cat /sys/class/thermal/thermal_zone0/temp
python3 -c 'import sys, rclpy; print("python", sys.executable); print("rclpy", rclpy.__file__)'
```

Expected: `NONE_RUNNING`, a low load average, a temperature well under `80000`,
`/usr/bin/python3`, and `rclpy` resolving under
`/opt/ros/jazzy/lib/python3.12/site-packages/`.

Step 2a, primary path:

```bash
RUN=~/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260804_172331
ls -l "$RUN/mavros_source_probe.py"
printf '%s  %s\n' '571be8f5811488f8a47903f2857f62a82be54f126e562fea343bdb202207bff4' \
  "$RUN/mavros_source_probe.py" | sha256sum -c -
```

Expected `1316` bytes and a line ending `: OK`. A `FAILED` result stops the
block and also puts Block B in doubt. If the file is absent, run step 2b.

Step 2b, fallback only if the primary file is absent. The desktop-path
validation mirrors `tools/live_dashboard_preflight.sh:500-507`:

```bash
(
  PI_HOME="$(readlink -f -- "$HOME")" || { echo 'GUARD_FAIL home-resolve'; exit 2; }
  { [ -n "$PI_HOME" ] && [ -d "$PI_HOME" ]; } || { echo 'GUARD_FAIL home-invalid'; exit 2; }
  PI_DESKTOP="$(xdg-user-dir DESKTOP)" || { echo 'GUARD_FAIL desktop-resolve'; exit 2; }
  PI_DESKTOP="$(readlink -f -- "$PI_DESKTOP")" || { echo 'GUARD_FAIL desktop-canonicalize'; exit 2; }
  { [ -n "$PI_DESKTOP" ] && [ -d "$PI_DESKTOP" ]; } || { echo 'GUARD_FAIL desktop-invalid'; exit 2; }
  [ "$PI_DESKTOP" != "$PI_HOME" ] || { echo 'GUARD_FAIL desktop-not-dedicated'; exit 2; }
  PI_HELPER="$PI_DESKTOP/pi_live_hailo_mavlink_dashboard.sh"
  { [ -f "$PI_HELPER" ] && [ -r "$PI_HELPER" ]; } || { echo "GUARD_FAIL helper-missing $PI_HELPER"; exit 2; }
  echo "GUARD_OK desktop=$PI_DESKTOP"
  printf '%s  %s\n' '31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa' \
    "$PI_HELPER" | sha256sum -c - || { echo 'GUARD_FAIL helper-hash'; exit 2; }
  mkdir -p "$PI_HOME/probe_dryrun_2026-08-05" || { echo 'GUARD_FAIL mkdir'; exit 2; }
  OUT="$PI_HOME/probe_dryrun_2026-08-05/mavros_source_probe.py"
  awk '/^cat >"\$MAVROS_SOURCE_PROBE" <</{c=1;next} c&&/^PYTHON_SOURCE_PROBE$/{c=0} c' \
    "$PI_HELPER" > "$OUT" || { echo 'GUARD_FAIL extract'; exit 2; }
  [ -s "$OUT" ] || { echo 'GUARD_FAIL extract-empty'; exit 2; }
  printf '%s  %s\n' '571be8f5811488f8a47903f2857f62a82be54f126e562fea343bdb202207bff4' \
    "$OUT" | sha256sum -c - || { echo 'GUARD_FAIL probe-hash'; exit 2; }
  echo "FALLBACK_DONE path=$OUT"
)
```

Proceed only on `FALLBACK_DONE`, then set `RUN=~/probe_dryrun_2026-08-05` in the
outer shell. Any `GUARD_FAIL` stops the block.

Every check in that block is an explicit failure branch rather than a shell
error-exit setting. An earlier draft relied on `set -euo pipefail` to abort on a
failed `sha256sum -c -`; direct testing of the negative path showed the subshell
continuing past a genuine mismatch in one invoking context while aborting in
another. A guard whose effect depends on the calling shell is not a guard, so
the dependence was removed. Both the mismatch and missing-helper paths were then
observed exiting `2`, and the matching path reaching `FALLBACK_DONE`.

Step 3, three timed dry-runs. The `3` is the settle budget the defaults produce
(`bound 6` minus `reserve 3`), and the five topics are `MAVROS_SOURCE_TOPICS` in
declaration order (`:610-616`), matching the vector the helper builds at
`:678-681`:

```bash
for i in 1 2 3; do
  printf '\n--- probe dry-run %d ---\n' "$i"
  time python3 "$RUN/mavros_source_probe.py" 3 \
    /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
    /mavros/battery /mavros/rc/in
  printf 'exit=%d\n' "$?"
done
```

Three repetitions rather than one, because run 1 is cold and runs 2 and 3 are
warm, and a single sample on this host does not support a budget decision.
Expected per run: five `TOPIC:` blocks each followed by `Publisher count: 0`
with no endpoint lines, `exit=0`, and a real time near `4.7 s`.

A publisher count above zero is a hard stop, not a data point. It means
something is publishing on domain `12` inside the subnet discovery range -
MAVROS still running on the Pi, or another host on the same domain. Any topic
above zero means the idle assumption is broken. All five above zero additionally
invalidates the timing, because the probe's completion predicate returns as soon
as every topic reports at least one publisher with at least one endpoint record
(`:1439-1443`), so the spin loop exits early and the run reports a short time
that measured nothing about the settle budget. Restore an idle Pi and repeat the
block rather than reading the number.

No `MAVROS_SOURCE_PROBE_RUN` line appears anywhere in Block A, and its absence
carries no information. That marker is emitted by the Bash wrapper
`mavros_source_probe_generation` through `log_error`; the probe program itself
writes only `TOPIC:`, `Publisher count:` and endpoint lines to standard output
(`:1463-1466`). The marker exists only in a helper run with the flag on.

### Reading the Block A timing

Non-spin overhead is the real time minus `3 s`. `TIMEOUT` occurs when the total
reaches `6 s`, that is when overhead reaches the `3 s` reserve.

| Reading | Verdict |
| --- | --- |
| Under `5.0 s` on all three runs | Defaults hold with over a second of headroom. Block B at `6`/`3`. |
| Between `5.0 s` and `6.0 s` | Idle passes with under a second of slack, and Block B adds Hailo, MAVROS, MAVProxy and thermal-watchdog load, which is the unmeasured case. Block B at `LIVE_PROBE_MAX_SECONDS=8` and `LIVE_PROBE_STARTUP_RESERVE=5`, recorded as non-default. |
| At or above `6.0 s` | Bound too tight on this host. Same raise, mandatory. A host-capacity result, not a defect. |
| Non-zero exit, import error, or a malformed block set | Stop. No Block B. |

The middle band defines the "comfortably under `6 s`" wording above, which set
no threshold. The `8`/`5` raise keeps the settle budget at `3 s`, identical to
the default, so it buys startup margin only and changes nothing about discovery
or about what Block B tests.

### Two Block B facts established at Gate 0

Both are recorded now and neither is acted on until Block B is approved.

- The compound command the supervisor prints ends in
  `exec env WORKSTATION_IP=... "$PI_HELPER"`
  (`tools/live_dashboard_preflight.sh:514`). It is plain `env` with no `-i`, so
  an exported `LIVE_MAVROS_SOURCE_BATCH=1` propagates through the pasted
  subshell to the helper.
- `mavros_source_probe_selftest` runs at `:2020`, immediately after
  `PI_SOURCE_STACK_READY=PASS` and immediately before the window opens, and logs
  through `log_error`, which writes to standard error as well as the log. A
  flag-on run therefore shows a `MAVROS_SOURCE_PROBE_RUN` line in the Pi
  terminal within seconds of readiness. Because the call is followed by `|| die`,
  a budget too tight to start aborts the run at that point rather than mid-window,
  and no `MAVROS_SOURCE_PROBE_RUN` line at that moment means the flag was not
  set.

### Bounded Gate 0 non-claims

- These are documentation corrections. No production file, test suite, or flag
  default was changed, and both pins are unchanged.
- The probe has still never executed against real `rclpy`. Reading the source
  does not measure interpreter start, import cost, or discovery behaviour on the
  Pi; Block A is what supplies those.
- The identity agreement above proves the preserved artifact matches the pinned
  helper's generator. It says nothing about whether the probe works.
- Nothing here bears on the graph race, its lower DDS/RMW/network trigger,
  browser-last ordering, or the separate `live_dashboard_20260724_175832`
  cumulative timing cause.

## Block A executed - probe dry-run, offline (05/08/2026)

Operator-run on the Pi desktop session at `15:14`-`15:25`, `imtaquadrone-desktop`,
one terminal, nothing else started. The control box was powered but its supply is
separate from the Pi's, and Block A used neither the FCU, the camera, the serial
link, nor any service.

### Preconditions

| Check | Value |
| --- | --- |
| Conflicting processes | `NONE_RUNNING` |
| Temperature | `56,750` mC / `56.75 C` |
| Interpreter | `/usr/bin/python3` |
| `rclpy` | `/opt/ros/jazzy/lib/python3.12/site-packages/rclpy/__init__.py` |
| Probe file | `1,316` bytes, `571be8f5811488f8a47903f2857f62a82be54f126e562fea343bdb202207bff4`, verified `OK` on the Pi |

The `rclpy` path is identical to the one recorded on 04/08/2026, so the probe
resolves the same module the helper invokes. The primary run directory still held
the probe, so the fallback extraction was not used.

The Pi was not idle in the strict sense. Load average read `1.43, 0.51, 0.21` and
then `1.53, 1.02, 0.47`, with `gnome-remote-desktop` and `gnome-shell` the only
non-trivial consumers. The session was being driven over RDP, and an active
remote-desktop encoder accounts for roughly one core of a four-core host. The
figures below therefore include desktop-session cost rather than representing a
bare idle host. `ps` reports average CPU since process start, so its `5.7` percent
for the encoder understates its instantaneous share.

### First attempt did not run

The first pass at the timed block produced
`python3: can't open file '/mavros_source_probe.py'` three times, `exit=2`, real
time `0.05 s`. `RUN` was unset in that shell, so the path expanded to root. The
timed block had been written to depend on shell state established two steps
earlier instead of setting what it needs. Nothing executed, no measurement was
taken and no state changed. The block was reissued self-contained - environment,
`RUN`, and an explicit `ABORT probe-not-found` guard in one paste - and that
form is the one recorded above.

### Timing

Three runs, all `exit=0`, all five topics emitted in `MAVROS_SOURCE_TOPICS`
declaration order, every `Publisher count: 0`, no endpoint lines, no
`MAVROS_SOURCE_PROBE_RUN` marker. No hard stop triggered. Overhead is real time
minus the `3 s` settle budget; because the bound is `settle + reserve`, the
unused reserve equals the margin to the `6 s` hard bound.

| Run | Real | User | Sys | Overhead | Margin to `6 s` |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1, cold | `4.618 s` | `0.852 s` | `0.193 s` | `1.618 s` | `1.382 s` |
| 2, warm | `4.116 s` | `0.888 s` | `0.127 s` | `1.116 s` | `1.884 s` |
| 3, warm | `4.076 s` | `0.858 s` | `0.117 s` | `1.076 s` | `1.924 s` |

Cold-to-warm delta is `0.52 s` of page-cache warming. Warm overhead is stable at
`1.08`-`1.12 s`, about a third of the `3 s` reserve.

### Verdict - defaults retained

Block B runs at `LIVE_PROBE_MAX_SECONDS=6` and `LIVE_PROBE_STARTUP_RESERVE=3`.

The warm runs are the relevant samples. By the time
`mavros_source_probe_selftest` fires at `:2020`, the helper has already run
`initial_graph_gate`, `require_publisher_count` and the
`ros2_graph_query topic list` at `:2011`; each is a `ros2` CLI invocation that
imports `rclpy` through the same interpreter, so page cache is warm at the
self-test by construction.

Total CPU is about `1.0 s` against `4.1 s` wall, so the probe is not CPU-bound -
the `3 s` spin is wall-clock inside `spin_once`, and additional load can inflate
only the `~1.1 s` startup and teardown portion. That portion would have to
roughly triple to consume the reserve. Keeping the defaults also makes the first
enabled run a test of the shipped configuration rather than of a hand-raised one,
which is the stronger feasibility claim. If the budget is nevertheless too tight,
the failure is loud, early and safe: the self-test is followed by `|| die`, so it
aborts at a known point instead of truncating the window, and that outcome is
itself the capacity result.

### Correction to the self-test failure rule

`mavros_source_probe_selftest` is called with deadline `0` at `:2020`. With a
zero deadline, `mavros_source_probe_generation` skips its deadline branch
entirely, so `SKIPPED` is unreachable there, and the timeout branch's
`[ "$deadline" -ne 0 ]` guard cannot fire either. The self-test returns only `0`
or `1`; it can never return `75`. A `75` can only arise from a later
deadline-bearing call. `TIMEOUT` at the self-test takes the `8`/`5` raise;
`FAILED` and `INCOMPLETE` are defects and must not be answered with a budget
raise.

### What Block A establishes

The probe has now executed against real `rclpy` on the Pi. Interpreter
resolution, `import rclpy`, argument parsing, node creation, the spin loop,
serialization and teardown all work, and a zero-publisher graph correctly yields
`Publisher count: 0` with exit `0` rather than failing closed. That path had only
ever run against the fake module.

### Bounded Block A non-claims

- The populated path is untested. Every count was zero, so
  `get_publishers_info_by_topic` was never observed returning an endpoint and
  `str(TopicEndpointInfo)` was never serialized against real data. The block
  validation requiring node name, namespace and GID has still never run on real
  output. Block B is the first test of it.
- The measurement includes RDP desktop-session load and excludes Hailo, MAVROS,
  MAVProxy, the thermal watchdog and the heavier encoder load of a live video
  window. It is a floor for Block B conditions, not a prediction of them.
- The `1.701 s` idle lifecycle figure recorded on 04/08/2026 covers `init`,
  `create_node`, `destroy_node` and `shutdown`. Today's `1.08`-`1.12 s` covers
  all of that plus interpreter start, `import rclpy`, gather and serialization -
  a strictly larger scope, yet a smaller number. Today's figure is three samples
  of the real program; the earlier one was a single sample. The earlier figure is
  not reproduced and today's is the better basis.
- Nothing here bears on the graph race, its lower trigger, browser-last ordering,
  or the separate cumulative timing cause.

## Block B executed - first enabled run (05/08/2026)

Operator-run. Workstation supervisor `live_dashboard_workstation_20260805_163802`
in W1, logs at `/home/ghostzero/Desktop/live_dashboard_workstation_20260805_163802`;
Pi run `live_dashboard_20260805_163818`, logs at
`/home/imt-aqua-drone/hailo_coco_overlay_2026-07-10/logs/live_dashboard_20260805_163818`.
`LIVE_MAVROS_SOURCE_BATCH=1` exported in the Pi shell that ran the pasted
compound command. Budgets left at their defaults: every probe-run summary reports
`bound=6s settle=3s reserve=3s`. Stop order was Pi, then browser, then
workstation, matching 04/08/2026.

### Probe outcomes

| Result | Count |
| --- | ---: |
| `OK` | `18` |
| `TIMEOUT` | `0` |
| `INCOMPLETE` | `0` |
| `FAILED` | `0` |
| `SKIPPED` | `0` |

Every summary carries `topics=5`, so each probe run served all five source
topics from one participant. No probe hit its bound and no generation was
rejected.

The flag-took witness is unambiguous. `PI_SOURCE_STACK_READY=PASS` is at line
`67`; the self-test summary follows at line `70`, `2.4 s` later, exactly where
`:2020` places it. Four further summaries precede readiness at lines `22`, `39`,
`48` and `65` - the two pre-readiness invocation groups and their retries - and
the rest fall in the window, final verification and the monitored hold. All four
invocation groups therefore exercised the batched path.

### Window, verification and lifecycle

`PI_SOURCE_WINDOW=COMPLETE target=120s monitored=120s final_verification=85s
elapsed=205s peak=66C`.

`monitored` equals `target`, so the window was not truncated. Final verification
used `85 s` of its `180 s` budget. Thermal peak `66 C`, below the `80 C` abort.
`PI_SUPERVISOR_EXIT status=0` appears once. On the workstation,
`W5_RATE_PROBES=PASS topics=6 duration_each=10s` with
`/hailo/overlay/image_raw` at `7.40 Hz` (`N=73`, interval mean/std
`135.17`/`20.82 ms`) and all five MAVROS topics at `1.00 Hz` with interval
standard deviations between `20.01` and `30.09 ms`;
`WORKSTATION_TEARDOWN=PASS` and
`SUPERVISOR_EXIT status=0 trigger=signal signal=INT stop_phase=supervision
failed_phase=none cleanup_rc=0`.

### Feasibility verdict - PASS

All four acceptance conditions hold:

- the batched path ran on the Pi against real `rclpy`, `18` runs, no failure of
  any kind;
- it stayed inside its budget at the shipped defaults, with no `TIMEOUT`;
- it served all five topics from one participant per run;
- the source window and final verification completed intact, with clean teardown
  and `status=0` on both supervisors.

### The populated endpoint path is now exercised

Block A left this open: every count was zero, so an endpoint record had never
been serialized from real data. This run closes it. Sixteen serves returned
populated blocks that passed validation, which requires a publisher endpoint
record carrying node name, namespace and GID whenever the count is above zero.
`str(TopicEndpointInfo)` therefore round-trips through the generation, the cache
and the existing Bash identity parser on real output.

### The race still occurs under the batched path

Two non-verifying readings, both on `/mavros/state`, both `attempt=1`, both
`query_rc=0`, both `verdict=publisher identity temporarily unknown`, both before
readiness, both recovered on attempt two:

| Episode | Failing attempt | Recovery probe | Gap |
| --- | --- | --- | ---: |
| 1 | `1785940806.550` | `1785940809.186` | `2.6 s` |
| 2 | `1785940830.508` | `1785940833.913` | `3.4 s` |

Each failure discarded its generation and forced a fresh probe run on the next
attempt, which is the consume-and-refresh contract behaving as designed and
observed live for the first time.

The failure mode is identity-unknown, not publisher-count-zero. The endpoint
record existed and carried a GID, but the publisher's node identity had not
resolved. Both modes were present in the combined 03/08/2026 baseline - `12`
count-zero and `2` identity-unknown - so this is a known mode, not a new one.
Batching the query did not prevent it.

### Workstation interrupt noise

Ctrl+C in W1 arrived while the supervisor was inside a `ros2 node list`
monitoring query. The signal reached that child, which printed a
`KeyboardInterrupt` traceback from `ros2cli` before the supervisor's own handler
ran. Teardown then proceeded normally: all three children stopped,
`WORKSTATION_TEARDOWN=PASS`, `failed_phase=none`, `cleanup_rc=0`, exit `0`. This
is terminal noise from an interrupted child, not a supervisor defect. It is
recorded because it was not seen on 04/08/2026, where the interrupt landed at a
different moment.

### Bounded Block B non-claims

- **No reduction claim.** Per-run flag-off counts are `11`, `3` and `2`. This
  enabled run produced `2`, which sits inside the control range and is
  indistinguishable from it. One run cannot separate a modest improvement from
  ordinary between-run variation, and today's design was never able to.
- Final verification took `85 s` against `115 s` on 04/08/2026. These are single
  samples from runs that differ in more than the flag, and the separate
  `live_dashboard_20260724_175832` cumulative timing cause remains open. No
  timing conclusion follows.
- Feasibility does not mean the graph race is fixed or explained. It recurred in
  this run.
- The lower DDS/RMW/network trigger stays unidentified. Matching GIDs and
  unresolved identities remain a proximate description, not a cause.
- No episode reached attempt three, so `probe_mavros_source_dataplane` has still
  never fired live.
- Browser-last ordering is still not obtained; the browser was closed after the
  Pi and before the workstation, matching 04/08/2026 by design.
- Post-teardown temperature, endurance, GPS fix, detector quality and all FCU
  write paths remain out of scope and were not exercised.

## Block C - decision (05/08/2026)

The feasibility question is answered and closed. The batched path is live-viable
at shipped defaults. **No run count is scheduled.**

### Why more runs of today's design would not settle anything

The measured quantity is the wrong one. A control that ranges from `2` to `11`
readings per run has a spread wider than any plausible effect, so separating a
real improvement from noise would need on the order of ten runs per arm - many
days of live time for a single number, with the boat, control box, workstation
and operator occupied throughout.

### What would make further enabled runs informative

Three changes, in descending order of value, all design-only and none approved:

1. **Pair the arms within one session.** The `11`, `3`, `2` spread is between
   sessions, which suggests session-level conditions - network, DDS state,
   participant history - dominate the variance. Alternating flag-off and flag-on
   phases inside one run would hold those constant and remove the largest noise
   term. This is the single highest-value change and it costs no extra live days.
2. **Measure a lower-variance quantity.** Probe runs per verification phase is
   deterministic and already logged: `1` on the clean path, `+2` per problematic
   topic, against five CLI invocations per phase when the flag is off. Today's
   `18` summaries with `topics=5` each are already this evidence. It measures the
   design change directly rather than through the race it is meant to survive.
3. **Record the failing mode, not just the count.** Today's two readings were
   identity-unknown where 04/08's two were count-zero. A design that only counts
   readings cannot see that shift, and the shift is more informative than the
   count.

### Open, unchanged

The lower trigger of the graph race, browser-last ordering, the
`live_dashboard_20260724_175832` cumulative timing cause, and the never-fired
terminal data-plane probe all remain open. Task 2 stays retired, and Task 3
stays behind the powered-off, propellers-removed wiring gate.
