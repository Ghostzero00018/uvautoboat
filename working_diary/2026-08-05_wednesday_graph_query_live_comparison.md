# Wednesday 05/08/2026 - probe dry-run and first enabled run

> **PRE-DIARY - NOT STARTED.** Prepared at EOD 04/08/2026. This file does not
> authorize work. Start only after explicit approval. Block A is offline on the
> Pi. Block B is live and needs the Pi, control box, workstation supervisor and
> browser. No FCU write, no arming, no motor command, no dataset or detector
> work.

## Starting state

- Clean `main` at `3bfcdde`, the last of four 04/08/2026 commits: `63d6e9a`
  carries the batched source view, `c8a0ecd`, `12bcc6a` and `3bfcdde` the
  documentation.
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
time python3 "$RUN/mavros_source_probe.py" 3 \
  /mavros/state /mavros/global_position/raw/fix /mavros/imu/data \
  /mavros/battery /mavros/rc/in
```

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

Failure classification:

- `result=TIMEOUT` is a startup-margin result; raise the two budget variables,
  keeping the bound above the reserve.
- `result=INCOMPLETE` is a partial or malformed generation; keep the raw
  diagnostics.
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
