# Tuesday 04/08/2026 - single-participant ROS 2 source-view implementation

> **PRE-DIARY - NOT STARTED.** Prepared at EOD 03/08/2026. This file does not
> authorize code work. Start only after explicit approval. Tomorrow's main gate
> is offline: no Pi, control box, browser, live service, hardware run, package
> installation, disk cleanup, SITL, VRX, or command/write path.

## Starting state

- Expected start: clean `main` at `6f9dfde`, with
  `HEAD == main == origin/main` and divergence `0/0`. The latest code-bearing
  commit is `bfaf969`; later commits are documentation-only.
- Pi helper: `tools/pi_live_hailo_mavlink_dashboard.sh`, `63,625` bytes,
  SHA-256
  `124d674f89efcee46a24d9bfa11b227324aa0dae292c666993df2a0a687fae98`.
- Workstation supervisor: `tools/live_dashboard_preflight.sh`, `28,647` bytes,
  SHA-256
  `72adfb125533e6b456583c563e5a47716b5514bbd649fa465a06ec5f142dbe2d`.
- Two view-only runs on 03/08/2026 completed the source window, entered the
  hold, passed workstation arrival/rates, and exited cleanly after Pi-first and
  workstation-second signals. Browser-last ordering was not obtained.
- Combined graph evidence: `14` non-verifying readings across `11` episodes,
  comprising `12` publisher-count-zero and `2` identity-unknown readings, all
  with `query_rc=0`. No episode reached attempt 3, so the terminal
  `MAVROS_SOURCE_PROBE` has not run live.
- Matching publisher GIDs confirm incomplete discovery in fresh graph
  participants as a proximate mechanism. They do not identify the lower
  DDS/RMW/network trigger, prove the exact writer state during the 24/07/2026
  incident, or prove the held design fixes the race.
- The separate `live_dashboard_20260724_175832` cumulative timing cause remains
  open. Its `90 s` to `180 s` budget increase was mitigation, not a correctness
  fix.
- Any helper edit makes the Pi desktop copy stale. A later live run must copy
  and verify the new helper before P0, but deployment is outside this day.

## Objective and non-goals

Implement the smallest red-first mitigation for repeated cold daemonless graph
snapshots: one bounded run-owned `rclpy` participant gathers endpoint data for
all five MAVROS source topics, while the existing Bash path retains ownership
of identity checks, retries, deadlines, latching, verdicts, and failure exits.

Offline green proves only that the plumbing and safety contracts work. Closing
the live defect requires a later dedicated comparison of at least three runs
against the `14`-reading / `11`-episode baseline. Do not combine that comparison
with implementation day.

Task 2 window sizing and Task 3 real Pi-to-FCU work stay parked. No query
collapse outside the MAVROS source seam, timeout widen, daemon adoption,
subscription-only identity check, C++ port, bridge work, SITL install, or live
test belongs in this gate.

## Gate 0 - certify and read, no edits

From `/home/ghostzero/seal_ws/src/uvautoboat`:

```bash
git fetch --prune
git log --oneline -8
git status --short --branch
git rev-parse HEAD main origin/main
git rev-list --left-right --count main...origin/main
```

If fetch fails, stop rather than using stale remote state. If behind only, use
`git pull --ff-only` and re-check. Stop for a dirty, ahead, or diverged tree. If
`HEAD` is later than `6f9dfde`, inspect the intervening commits. Confirm this is
still the sole `04/08/2026` diary.

Read the 03/08 diary, this diary, `Board.md`, the Pi helper and its focused
test, the workstation preflight and its focused test, and
`wiki/Live_Hailo_MAVLink_Dashboard_Testing.md`. Run both focused suites once
before edits; a pre-existing failure stops the implementation gate.

## Gate 1 - characterization first

Explicit implementation approval is required before this gate.

Add guards for both currently uncovered pre-readiness five-topic sequences
before changing production code. Pin the exact topic order and equality across
all four concrete call sites:

1. the telemetry pre-readiness sequence;
2. the post-Hailo-readiness sequence;
3. `final_graph_verification`;
4. phase 3 of `monitor_live_stack`.

These are four call sites in three consumer contexts; earlier wording about
three declarations referred to the contexts. Also characterize the flag-off
CLI path and the existing `/mavros/_NODE_NAME_UNKNOWN_` compatibility quirk
without changing either behaviour.

## Gate 2 - independent red tests

Fail-fast masked later assertions twice on 03/08/2026. Add and run each new red
case independently before stacking the next; do not infer one failure from
another. Remove temporary test selection before final verification.

Required red coverage:

- one enabled probe serves the five ordered topics from one participant run;
- a consumed topic entry forces a fresh run, with executable bounds of one on
  the happy path, at most three for one problematic topic, and `11`
  (`1 + (2 * 5)`) per-phase worst case;
- finite parent deadlines clamp the probe and preserve headroom and return
  `75`; parent deadline `0` retains the probe's own finite hard bound;
- raw probe return `3` maps to view return `1`, not `75`, and is covered by a
  pre-window self-test;
- crash, exception, timeout, malformed output, or a partial topic set cannot
  publish consumable cache state;
- the probe is synchronous, never calls `start_child`, and never changes the
  managed-child arrays or cleanup ownership;
- complete success records one `MAVROS_SOURCE_PROBE_RUN` summary with no raw
  per-topic noise; incomplete/failure paths retain their raw diagnostics;
- strict count `1`, publisher GID, MAVROS identity, identity-unknown retry,
  immediate foreign-publisher rejection, exact terminal verdict, deadline
  algebra, latch timing, interrupt deferral, and fail-closed exit remain intact.

## Gate 3 - smallest implementation

Keep `require_mavros_source` as the verdict owner. Replace only its present
`ros2_graph_query_before ... topic info --verbose` seam with
`mavros_source_view <deadline> <topic>`.

The held implementation contracts are:

- one `MAVROS_SOURCE_BATCH` flag; when off, delegate byte-compatibly to today's
  CLI query, and when on, serve one cached result per topic;
- one generated run-owned Python probe using a hidden
  `_live_dashboard_graph_probe` node and `str(TopicEndpointInfo)`, preserving
  node identity, GID, type, endpoint, and QoS representation;
- one filesystem-backed cache under `$RUN_DIR`, because the view is called in
  command substitution; publish complete generations by atomic replacement
  and consume each topic entry once;
- external hard maximum `PROBE_MAX_SECONDS=6`, earlier internal completion,
  early success, finite-parent clamping, and non-zero serialization/teardown
  headroom;
- synchronous execution only, never a managed child;
- startup, self-test, parse, timeout, and exception failures remain fail closed;
- one probe-run summary, with verbatim per-topic output only for incomplete or
  failed views;
- the existing three attempts, two back-offs, command sentinels, strict
  publisher/MAVROS verdict, unknown-identity handling, return `75` sites,
  pending latch, byte-exact die text, cleanup, and exit status stay in Bash.

Wire the enabled branch into both characterized pre-readiness sequences, final
verification, and monitor phase 3. Keep the feature flag off by default until a
separately approved live comparison explicitly opts in.

Do not change `graph_nodes`, command-service/subscriber checks, image checks,
connected/disarmed samples, or the terminal IMU data-plane probe. Do not widen
CLI spin time, add retries, use the ROS daemon, or refactor unrelated queries.

## Gate 4 - offline verification and pins

Run:

```bash
bash -n tools/pi_live_hailo_mavlink_dashboard.sh
bash -n tools/live_dashboard_preflight.sh
bash -n tools/test_pi_live_hailo_mavlink_dashboard.sh
bash -n tools/test_live_dashboard_preflight.sh
bash tools/test_pi_live_hailo_mavlink_dashboard.sh
bash tools/test_live_dashboard_preflight.sh
git diff --check
```

After the helper settles, recompute its SHA-256 and byte size and inventory all
tracked old-pin occurrences. The starting revision has `12` operational pin
surfaces: eight helper hashes, one helper size, two cascading supervisor hashes,
and one supervisor size. Recompute the supervisor after its helper pin changes.
Do not assume the counts or sizes remain unchanged.

Propagate final pins consistently through the preflight, both focused tests,
and the live-testing wiki. Do not rewrite historical diary hashes. Append the
final pins, red/green evidence, verification results, and bounded non-claims to
this diary. The focused suites do not independently prove helper-pin freshness,
so compare each final pin with the actual file.

Stop after offline verification and request a separate live-comparison gate.
No Pi copy, P0/P1, W0/W1, browser, hardware, or live process is authorized.

## Offline acceptance

- Both pre-readiness groups and all four call sites are characterized before
  production edits.
- Every new defect test is observed red independently, then green after the
  smallest implementation.
- Both suites and all four syntax checks pass; the final diff is whitespace
  clean and contains no unrelated work.
- Atomic publication, deadlines, latch timing, verdict text, identity checks,
  child ownership, cleanup, and exit-status honesty remain fail closed.
- Final helper/supervisor hashes and sizes match every operational pin.

Do not claim that offline acceptance fixes the graph race, identifies its lower
trigger, closes the 24/07/2026 incident retroactively, or resolves the separate
timing cause. Reduced participant count and final-verification duration remain
predictions until later live evidence exists.

## EOD 03/08/2026 closure

Before this pre-diary, the repository was clean and pushed at `6f9dfde`. Both
Pi and workstation supervisors were stopped with clean exit and teardown
records, the four run directories remained preserved, and no related service
or dashboard/bridge listener remained. No runtime cleanup is needed tonight.

One non-blocking documentation mismatch remains: the current dashboard task in
`Board.md` still lists post-teardown temperature as open although both
03/08/2026 runs recorded it. Correct that clause during the next documentation
update while retaining the open endurance, browser-last, graph-query, GPS,
detector, and write-path boundaries. Its broad TBD lifecycle row should also
distinguish the accepted Pi/workstation supervisor lifecycle from the open
browser-last and endurance gates. The Roadmap has not yet carried the 03/08/2026
evidence; that is optional follow-up, not an implementation blocker.

Disk remains about `14 GB` free. ArduPilot SITL, `sim_vehicle.py`, and
workstation MAVProxy remain absent. Regenerable-data cleanup and any clone or
installation are separate user-run gates after the main task; retain historical
run evidence and re-check free space first.

`tools/servo_command.cpp` remains an intentionally unbuilt, non-authoritative
reference. The integrated `tools/servo_command_bridge.py` ArduRover SITL + VRX
path remains **NOT RUN**. Neither file needs conversion or movement.

**Next steps:** After explicit approval, certify, run the current suites once,
then start with the two pre-readiness characterization guards. Keep the day
offline and reserve the three-run live comparison for a later dedicated day.
