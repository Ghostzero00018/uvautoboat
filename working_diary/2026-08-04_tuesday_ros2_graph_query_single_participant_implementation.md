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

## Gate 0 certification and pre-Gate 1 corrections (04/08/2026)

Gate 0 ran from the clean pushed revision
`123d8826749fb63ac3fb914fd3582919eff6fef6`, with
`HEAD == main == origin/main` and divergence `0/0`. Commit `123d882` adds only
this `227`-line diary; the helper and workstation supervisor are byte-identical
to their versions at `6f9dfde`, so the starting hashes and sizes above remain
current. The two focused baseline suites passed before this documentation-only
correction:

```text
PASS: Pi lifecycle, local-window, heartbeat, deadline, and monitored-hold contracts
PASS: live-dashboard preflight contracts cases=13
```

This section supersedes the earlier pre-diary statements where they differ.
The `6f9dfde` note records the preparation point before this diary was
committed; `123d882` is the operational Gate 1 starting revision.

The statement that no episode reached attempt 3 is withdrawn. Three episodes
recovered on attempt 3: `/mavros/state` after count-zero then unknown identity,
`/mavros/imu/data` after two count-zero readings, and `/mavros/battery` after
count-zero then unknown identity. No episode *exhausted* all three attempts with
a non-verifying result, which is why `probe_mavros_source_dataplane` still has
not run live. The live margin was therefore thinner than the earlier sentence
stated, while the bounded non-claim about the terminal probe remains valid.

### Corrected Gate 3 payload contract

The enabled `mavros_source_view` payload must preserve both publisher-query
APIs used by the installed `ros2 topic info --verbose` implementation. For each
requested topic, the run-owned `_live_dashboard_graph_probe` node must:

1. obtain the publisher count with `node.count_publishers(topic)`;
2. separately obtain publisher endpoint objects with
   `node.get_publishers_info_by_topic(topic)`; and
3. emit exactly one `Publisher count: <n>` line, followed by each endpoint's
   unmodified `str(TopicEndpointInfo)` block.

The count must not be derived from `len(endpoint_infos)`: that would replace
the metric behind the `12` count-zero baseline readings and invalidate the
later comparison. `str(TopicEndpointInfo)` supplies, in order, `Node name:`,
`Node namespace:`, `Topic type:`, `Topic type hash:`, `Endpoint type:`, `GID:`,
and the QoS fields. This preserves the field order consumed by the existing
Bash identity parser as well as the GID and endpoint diagnostics.

When `MAVROS_SOURCE_BATCH=0`, `mavros_source_view` must delegate directly with
the exact argument vector:

```bash
ros2_graph_query_before "$deadline" topic info --verbose --no-daemon --spin-time 2 "$topic"
```

It must not capture and reprint the result. It must forward standard output
byte-for-byte, keep standard error separate, and return
`ros2_graph_query_before`'s status unchanged. In particular, a hard CLI-query
failure must leave the captured `info` empty so the existing
`MAVROS_SOURCE_EVIDENCE ... raw: <no query output>` behaviour remains intact.

### Corrected Gate 3 and Gate 4 test scope

Replacing the seam also requires narrow updates to the six focused-test
sandboxes that extract `require_mavros_source` alone:

- `MAVROS_SOURCE_DEADLINE_OUTPUT`;
- `MAVROS_SOURCE_EVIDENCE_OUTPUT`;
- `MAVROS_SOURCE_RECOVERY_OUTPUT`;
- `MAVROS_SOURCE_PROBE_HANDOFF`;
- `SOURCE_DEADLINE_ATTRIBUTION_OUTPUT`; and
- `run_third_attempt_interrupt`.

Each sandbox must explicitly extract/evaluate or stub `mavros_source_view` so
it continues to exercise its original deadline, retry, evidence, probe,
attribution, latch, and interrupt contract after the production call changes.
Without that update, four cases fail loudly and two can pass without exercising
their intended query stub. Every sandbox must therefore assert the replacement
seam rather than rely only on a downstream verdict.
The flag-off case must additionally pin the exact CLI argument vector, separate
stdout/stderr streams, and unchanged return status. These six compatibility
updates are part of the smallest Gate 3 test change, not unrelated refactoring.
Gate 4 must leave all six exercising the intended seam before accepting the
full focused suite.

Gate 1 remains characterization-only: add the two missing pre-readiness guards,
prove exact ordered equality across all four five-topic groups, and characterize
the current CLI and `/mavros/_NODE_NAME_UNKNOWN_` behaviour against the
unmodified helper. Every guard must be green before adding a defect test. Gate
2 then adds and runs each defect case independently so an earlier fail-fast
result cannot stand in for a later red result; any temporary case selector must
be removed before final verification.

Do not expand Gate 1 into the unrelated command-subscriber query, wider spin
times, new retry logic, daemon use, alternate status-code work, or live timing
experiments. Gate 2 must include a discriminating payload case in which
`count_publishers(topic)` differs from the endpoint-list length, proving that
the synthesized count uses the former while the blocks use the latter.

These source-derived corrections do not prove that the separate count and
endpoint calls form an atomic graph snapshot, that the `6 s` aggregate probe
bound equals five independent `2 s` discovery windows, or that any live timing
or participant count improves. The byte-identical command-subscriber query
outside `require_mavros_source` remains intentionally unchanged. During Gate 4,
review `Board.md` wording that currently says "one participant per verification
phase" against the implemented consume-and-refresh behaviour before retaining
or correcting that claim.

This documentation correction does not open Gate 1. The existing offline and
live non-claims remain unchanged, and characterization must still be observed
green against the unmodified production helper before any defect test or
implementation edit.

## Gate 1 characterization landed (04/08/2026)

Gate 1 changed `tools/test_pi_live_hailo_mavlink_dashboard.sh` only. Both
production scripts stayed byte-identical, so the starting hashes and sizes above
remain current and the earlier baseline suite results stay valid.

Added guards cover the two previously uncovered pre-readiness groups and their
surrounding anchors, one canonical topic order shared by all four invocation
groups, the phase-three deadline forwarding that the existing monitor trace did
not capture, the current query argument vector and body handling, and the four
previously uncovered identity branches: a MAVROS-namespaced unknown node name
accepted on the first attempt, root-namespace unknown name and unknown namespace
retried to the terminal verdict, immediate foreign-publisher rejection, and a
counted publisher with no publisher endpoint block.

### Corrected Gate 3 sandbox count

The six-sandbox figure recorded earlier is superseded. The Gate 1 guards add six
further sandboxes that locally stub `ros2_graph_query_before`, so Gate 3 must
adapt **twelve** sandboxes, not six:

- the six recorded earlier; and
- `SEAM_CLI_STDOUT` / `SEAM_CLI_STDERR`, `SEAM_STATUS_OUTPUT`,
  `SEAM_NAMESPACED_UNKNOWN_OUTPUT`, `run_unknown_identity_case`,
  `SEAM_FOREIGN_PUBLISHER_OUTPUT`, and `SEAM_NO_PUBLISHER_BLOCK_OUTPUT`.

Once re-pointed, the six new sandboxes carry the flag-off delegation evidence the
corrected Gate 3 contract requires. They already pin the argument vector one
positional argument per line together with its count, compare every attempt's
forwarded body as ordered consumer-visible text, compare standard output and
standard error separately and exactly, and use a discriminating query status of
`42`.

These are text-level comparisons, not raw stream comparisons: command
substitution and the evidence reconstruction both strip trailing newlines. True
raw byte compatibility therefore belongs in Gate 2, as a direct
`mavros_source_view` defect test that writes the flag-off and current-CLI results
to separate files and compares them with `cmp`. That case is planned, not
written; Gate 2 stays closed.

The earlier "four concrete call sites" phrasing is superseded by "four invocation
groups", which is what the guards and this record use.

### Bounded Gate 1 non-claims

- The reference census compares every line mentioning the consumer name in
  order, complete except for leading whitespace, so an added prefix such as a
  wrapper command is visible. A call reached through a variable that never
  spells the name still cannot be detected from the source text.
- The two top-level pre-readiness groups are pinned structurally, not executed.
  They run without a deadline argument, so `require_mavros_source` defaults to
  `0`; no offline guard proves their live behaviour.
- Guard effectiveness was checked by mutating scratch copies of the helper
  outside the repository. Those artifacts are deliberately not tracked, so the
  focused suite does not reproduce that check; it is not certifiable from the
  repository alone.
- Characterization proves only that today's behaviour is pinned. It does not
  prove that any replacement preserves it, and it does not touch the separate
  live graph-race or timing questions.

Gate 2 was closed at the time this section was written. The record continues
below.

## Gate 2 defect cases landed red (04/08/2026)

Gate 2 changed `tools/test_pi_live_hailo_mavlink_dashboard.sh` only. Both
production scripts stayed byte-identical, so the pinned hashes and sizes remain
current and no Pi copy became stale.

### Interface pinned by the red cases

Red-first requires a callable contract before the implementation exists, so
these cases pin the following. Gate 3 must honour it, or change a case and
record why:

- `mavros_source_view <deadline> <topic>`; standard output is what
  `ros2 topic info --verbose` prints for that topic; returns `0` on success,
  `75` on parent-deadline exhaustion, and `1` fail closed.
- `MAVROS_SOURCE_BATCH=0` delegates to `ros2_graph_query_before` with the exact
  argument vector, raw standard output, separate standard error, and unchanged
  status.
- The probe runs synchronously through `timeout --signal=KILL <bound>s ...`,
  matching the seam `probe_mavros_source_dataplane` already uses and that the
  focused suite already stubs.
- The probe stream is per-topic blocks introduced by `TOPIC: <topic>`.
- `PROBE_MAX_SECONDS` is `6`; the cache lives under `$RUN_DIR`.

Cache layout is deliberately not pinned. Freshness and consumption are asserted
behaviourally, by counting probe runs, so Gate 3 keeps its choice of file names
and on-disk shape.

### Case selection

The cases are skipped unless `LIVE_GATE2_CASES` names one or `all`, so the
tracked suite stays green while they accumulate. The skip is printed, not
silent, and an unmatched selector value fails rather than quietly running
nothing. This selector is temporary scaffolding and must be removed at Gate 4 so
the cases run unconditionally.

### Red evidence

Eighteen cases were added and each was observed failing on its own selector
value, never inferred from another case's failure:

| Case | Observed failure |
| --- | --- |
| `flag-off-delegation` | returned `127` instead of the query status `42` |
| `discriminating-count-api` | count not reported from `count_publishers` |
| `one-participant-five-topics` | five topics did not share one probe run |
| `consumed-entry-refresh` | a consumed entry did not force a fresh run |
| `execution-bounds-clean-phase` | a clean phase did not stay within one run |
| `execution-bounds-problematic-topic` | one problematic topic did not cost three runs |
| `execution-bounds-worst-case` | did not settle at `1 + (2 * 5)` runs |
| `finite-deadline-clamp` | no clamped hard bound recorded |
| `deadline-zero-hard-bound` | six-second hard bound absent |
| `probe-status-three-maps-to-one` | raw `3` did not map to view `1` |
| `atomic-publication-crash` | did not fail closed |
| `atomic-publication-exception` | did not fail closed |
| `atomic-publication-timeout` | did not fail closed |
| `atomic-publication-malformed` | did not fail closed |
| `atomic-publication-partial` | did not fail closed |
| `synchronous-no-managed-child` | topic not served, so the result was vacuous |
| `success-summary` | no single `MAVROS_SOURCE_PROBE_RUN` summary |
| `failure-summary-diagnostics` | no summary on the incomplete path |

The worst-case arithmetic is derived, not assumed. With whole-generation
replacement and one consumption per entry, the first read of a topic costs one
run, the two repeat reads cost one each, and each later topic is served once
from the surviving generation before its own two repeats: `1 + (2 * 5) = 11`.

Three cases were rewritten before their red was accepted because they would
otherwise have passed with no implementation at all: the two execution-bound
comparisons were upper bounds satisfied by zero runs, and the child-ownership
case observed empty arrays without ever serving a topic. `execution-bounds` was
also split into three selectable cases so its three independent scenarios are
each observed rather than stopping at the first.

### Bounded Gate 2 non-claims

- Red proves only that each case fails without an implementation. It does not
  prove the pinned contract is achievable, that the probe wire format is the
  right one, or that Gate 3's design is correct.
- The seam and stream format are Gate 2 decisions taken to make red-first
  possible. They are not derived from live evidence.
- The `6` second bound and the eleven-run worst case are contract assertions,
  not measurements. Neither says anything about live discovery behaviour.
- Gate 2 adds no sandbox that extracts `require_mavros_source`, so the Gate 3
  re-pointing set remains the twelve recorded above.

Gate 3 was not open when that section was written. The record continues below.

## Gate 2 rework, Gate 3 and Gate 4 (04/08/2026)

### Gate 2 rework before the red was accepted

Seven defects in the first Gate 2 draft were corrected, several of which would
have produced false evidence:

1. Success fixtures used one-topic streams while `atomic-publication-partial`
   treated that same shape as incomplete. Every success fixture now uses a
   complete five-topic generation, and the partial fixture is a complete-looking
   stream that is missing topics.
2. Successful enabled serves ignored the view status, so an implementation could
   emit plausible output and return `1` every time. Every successful serve now
   requires `0`, and both reads in each atomic-failure case require `1`.
3. All cases shared one run directory, so cache entries leaked between them; the
   problematic-topic case made the worst-case scenario count ten instead of
   eleven. Each case and scenario now gets its own run directory.
4. Producer behaviour was untested: an already-synthesized stream was injected
   through the `timeout` stub. `producer-single-participant` now runs the
   generated program against a fake `rclpy` and observes one participant, the
   hidden node name, and one `count_publishers` plus one
   `get_publishers_info_by_topic` call per topic.
5. Payload fidelity and routing were open. `enabled-payload-routing` now
   compares each topic's served output against its own expected block, with a
   distinct GID per topic, and requires exactly one publisher-count line and no
   leaked stream header.
6. The status-three case could pass without invoking the probe, and the required
   pre-window self-test was missing. Both are fixed, and
   `pre-window-probe-selftest` also requires a column-zero call ahead of the
   live window.
7. The contract wording claimed the enabled path reproduces
   `ros2 topic info --verbose`. It does not: enabled output is the synthesized
   publisher-count line plus the verbatim publisher endpoint blocks. Only the
   flag-off path forwards the complete raw CLI streams.

Twenty-one cases were then observed failing independently, each on its own
assertion. Two of them (`success-summary`, `failure-summary-diagnostics`) were
later found to have stubbed `log_error` onto standard output, which the view
call discards; the stubs were corrected to standard error, matching the real
`log_error`, and both were re-observed red against the pre-implementation helper
before being accepted green.

### Gate 3 implementation

Added to `tools/pi_live_hailo_mavlink_dashboard.sh`:

- `MAVROS_SOURCE_BATCH` from `LIVE_MAVROS_SOURCE_BATCH`, validated `0` or `1`,
  **off by default**, and `PROBE_MAX_SECONDS=6`.
- `mavros_source_probe_program`, emitting a program that creates one
  `_live_dashboard_graph_probe` node and, per topic, calls `count_publishers`
  and `get_publishers_info_by_topic` separately.
- `mavros_source_probe_generation`, running that program once through
  `timeout --signal=KILL`, splitting the stream per topic into a staging
  directory, rejecting any incomplete or unparsable generation, and publishing
  by directory rename so a failed run cannot leave consumable state.
- `mavros_source_probe_selftest`, one bounded probe called before the live
  window, inert while the flag is off.
- `mavros_source_view`, delegating byte-compatibly when the flag is off and
  serving one consumed-once cache entry when it is on.

The only production seam change is inside `require_mavros_source`, where the
query call became `mavros_source_view "$deadline" "$topic"`. The three attempts,
two back-offs, strict count, identity decisions, `75` sites, latch, verdict
text, cleanup, and exit status are unchanged.

Rather than editing twelve sandboxes individually, the extracted
`require_mavros_source` now carries the view family with it, so every existing
sandbox exercises the real delegation path with its own query stub. All previous
contracts stayed green through the seam change.

### Gate 4 offline verification

The temporary case selector was removed; all twenty-one cases run
unconditionally. Four syntax checks, both focused suites, and `git diff --check`
pass.

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `67,523` bytes | `0d29005ecb3d782c679ca6248c429a4d4b2289fefad9505f2e30ad1707ab659d` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `46166bdbf2d543cea58164dab423e2bf296a57187fc164f0709ae74505be99f1` |

All twelve operational pin surfaces were updated in cascade order: eight helper
hashes, one helper size, then the supervisor recomputed after it took the new
helper hash, giving two supervisor hashes and one supervisor size. Each final
pin was compared against the actual file rather than inferred from a green
suite. Historical diary pins were left untouched, including the starting-state
values above.

The `Board.md` wording that called the design "one bounded, run-owned graph
participant per verification phase" was corrected: that describes the clean path
only, and the repeated-read worst case is `1 + (2 * 5)` runs.

### Bounded Gate 3 and Gate 4 non-claims

- The flag is off by default, so nothing in the live path changes until a
  separately approved run opts in.
- Offline green proves the plumbing and the safety contracts. It does not prove
  the graph race is fixed, does not identify the lower DDS/RMW/network trigger,
  does not close the 24/07/2026 incident, and does not resolve the separate
  cumulative timing cause.
- No probe has run against real `rclpy`. The producer case runs against a fake
  module, so the real API shape, timing, and discovery behaviour are unverified.
- The `6` second bound and the eleven-run worst case remain contract
  assertions, not measurements.
- The Pi Desktop copy is now stale: the helper hash changed. Any live run must
  copy and verify the new helper first.
- Reduced participant count and shorter final verification remain predictions
  until a dedicated comparison of at least three runs against the
  14-reading / 11-episode baseline exists.

No live process, Pi copy, browser, or hardware step was run. The live comparison
remains a separate, unapproved gate.

## Implementation rework before certification (04/08/2026)

The first implementation was rejected on review. Seven findings were closed; the
first was substantive rather than cosmetic.

### The probe never accumulated discovery

The generated program queried each topic immediately after creating its node and
exited. Nothing spun, so the six-second bound guarded stalls rather than
discovery, and the enabled path would have reproduced the very defect it
targets. `ros2cli/node/direct.py` spins its node for the whole requested
`spin_time` before reading endpoints; the probe now does the equivalent. It
spins in a poll loop, re-gathers every topic each pass, returns as soon as every
topic reports at least one publisher with at least one endpoint record, and
otherwise runs to an internal settle budget held one second below the external
hard bound.

### Remaining findings

- The program is materialized as `$RUN_DIR/mavros_source_probe.py`, generated by
  a top-level heredoc after the preflight-only exit alongside the other run
  artifacts, and executed as a file rather than through `python3 -c`. Flag
  validation moved into the argument-validation block with the other flags.
- Finite deadlines are re-checked after a fresh generation and before any cached
  serve, so a probe that consumed the parent budget returns `75` instead of
  succeeding late. Extraction, validation, and consumption statuses are all
  checked rather than masked by an unconditional success.
- Publication is a checked atomic rename of a single generation file. Failure is
  reported, never logged as a successful run. Consumption rewrites the pending
  file through the same checked rename.
- Block validation now requires exactly one publisher-count line, a numeric
  count, and - when the count is above zero - a publisher endpoint record with
  node name, namespace, and GID. A complete-looking generation whose blocks
  carry no endpoint record is rejected.
- Probe standard output and standard error are captured to separate files, so
  probe stderr can never enter a cached payload, and every failure path
  including timeout and crash records its raw diagnostics.
- The two sandboxes that previously passed without reaching their query stub now
  assert three recorded queries each.

### Coverage added

Twenty-five cases now run unconditionally. Beyond the earlier set:
`producer-accumulated-discovery` drives the fake graph so nothing is visible for
the first spins and requires the settled reading rather than the first one;
`late-deadline-crossing` requires `75` when a successful probe consumes the
parent budget; `publication-failure-fails-closed` forces the rename to fail and
requires a fail-closed result with no success summary; `probe-stderr-not-cached`
requires that probe stderr never reaches a served payload. The producer case now
runs the materialized program and compares the full emitted stream against an
expected serialization, pinning topic order, count, identity, type, hash,
endpoint type, GID, and QoS, and asserting exactly one participant that spins
before it reads.

Each reworked contract was checked by mutating scratch copies: removing the
spin, removing the settle predicate, removing the view deadline check, weakening
block validation, leaving the publication status unchecked, and merging the
probe streams are all detected.

### Final pins

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `69,861` bytes | `bfcee44f42f03990e6267403284c9400d4d2a44246bcad52da1483d8c7238155` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `3d5a2cbbe91664ca520dd3e72e15d76dc96724a0ad5b56dc6b71582020f77a42` |

All twelve operational surfaces were re-propagated in cascade order and each
final pin was compared against the actual file. `Board.md` no longer carries the
superseded "no correctness fix has been selected", "designed but unapproved and
unimplemented", or "no episode reached a third attempt" statements, and the
live-testing wiki now dates the pins to 04/08/2026 and states that a previously
transferred Pi copy is stale until its hash is checked.

### Bounded non-claims after the rework

- The probe has still never run against real `rclpy`. The producer cases run
  against a fake module, so the real API surface, the interpreter that resolves
  `rclpy` on the Pi, spin timing, and actual discovery behaviour are unverified.
- The settle predicate is a completion condition, not a guarantee. If a topic
  genuinely has no publisher, the probe emits a zero count after its budget and
  the existing Bash retry and verdict path handles it exactly as before.
- The internal settle budget and the six-second outer bound remain contract
  values, not measurements.
- Offline green still does not fix, explain, or close the live graph race, and
  does not touch the separate cumulative timing cause.

## Pre-live review and final corrections (04/08/2026)

A review taken immediately before the first live attempt found three further
defects. All are closed; the helper and its pins changed again.

### Self-test left a pre-window generation

`mavros_source_probe_selftest` published a full five-topic generation and
consumed nothing. Because it runs immediately before the window opens, the first
in-window phase-three check would have served five entries captured before the
window started. The self-test now discards its generation.

### Probe self-timeout was reported as parent-deadline exhaustion

The probe bound is `min(PROBE_MAX_SECONDS, remaining - 1)`, so it is always
strictly below the remaining parent budget and a probe timeout can never mean
the deadline was reached. The code nevertheless returned `75`, the reserved
deadline code. In monitor phase three that breaks out of the window loop, so a
six-second probe overrun early in a run would have ended a `120 s` window while
still logging `PI_SOURCE_WINDOW=COMPLETE`; in final verification it would have
died with `final verification exceeded 180s` after a few seconds. It also
cleared the pending-failure latch, so the probe failure would have been filed as
benign. The timeout branch now returns `75` only when `SECONDS` has actually
reached the deadline, and otherwise fails closed with `1`.

This was a wrong contract, not only a wrong implementation: the earlier
`finite-deadline-clamp` case asserted `75` for exactly this scenario. It now
asserts `1`, and `probe-timeout-crossing-deadline` covers the genuine case.

### A published generation could survive a 75 return

`mavros_source_view` published a generation and could then return `75` on the
deadline check, leaving all five entries in place. Nothing cleared the cache
across a phase boundary, so a later phase running under a different deadline
would have found every topic present and served graph evidence gathered before
that boundary without probing again. The view now discards the generation on
every non-zero return, and `failed-view-leaves-no-cache` proves the next phase
probes again.

### Probe invocation had no bash-level coverage

Every source-view case stubs `timeout`, and the only argument assertion was a
prefix match, so a wrong program path or passing only the first topic would have
kept the suite green and failed closed on the Pi. `probe-invocation-argv` now
compares the whole argument vector, and the flag now has the validation test its
neighbours already had.

Each fix was checked by reintroducing the defect on a scratch copy: reporting a
probe timeout as deadline exhaustion, keeping the generation after a `75`, a
wrong program path, and a single-topic argument list are all detected.

### Final pins

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `70,737` bytes | `b6f91bdecb4f95b063dfecaf08f837a5fda725238ced7eae6f0f8a56abc2f806` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `e0b6099d0dcdd7bd618cd396419ab6b1eed9ab9e72bcd15f36a8b4172bf0735f` |

All twelve operational surfaces were re-propagated in cascade order and compared
against the actual files. Four syntax checks, both focused suites, and
`git diff --check` pass.

### Remaining pre-live non-claims

- The probe has still never executed against real `rclpy`. Interpreter
  resolution, spin timing, and real discovery behaviour on the Pi are unverified.
- The `6 s` bound leaves under one second for interpreter start, import,
  participant creation, and teardown once the `5 s` settle budget is deducted.
  That margin was never measured on the Pi. If it is too small, the probe will
  time out routinely and now fails closed rather than truncating the window.
- No review lens covered the workstation supervisor, the dashboard web surfaces,
  or the Pi-side environment.

## Probe budget split before the live run (04/08/2026)

The last open pre-live risk was the startup margin. With a fixed one-second
reserve, a `6 s` bound left under a second for interpreter start,
`import rclpy`, participant creation and teardown, which is optimistic on a
Pi 5 and would have made the probe hit its bound routinely on the first enabled
run.

The budget is now split explicitly. `LIVE_PROBE_MAX_SECONDS` (default `6`) is
the outer hard bound and `LIVE_PROBE_STARTUP_RESERVE` (default `3`) is withheld
for process startup and teardown; only the remainder is spent spinning, with a
one-second spin floor when a clamped parent deadline leaves less. Both are
validated as positive integers, and the bound must exceed the reserve so a
configuration with no spin time cannot start. The default therefore spins for
`3 s`, still longer than the `2 s` the CLI path spins per query, while giving
startup three times the previous margin. The successful-run summary now records
`bound`, `settle` and `reserve`, so the split used is visible in the run record.

A slow host now loses discovery time rather than overrunning the bound, and if
the reserve is still too small the probe fails closed and retries; it does not
truncate the window.

Guard checks: collapsing the reserve back to one second, reducing the default
reserve, and removing the spin floor are each detected.

### Final pins

| Artifact | Size | SHA-256 |
| --- | --- | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `71,501` bytes | `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877` |

### Correction carried into the run procedure

A probe that hits its own bound returns `1`, not `75`. `75` is returned only
when `SECONDS` has actually reached the parent deadline. A capacity failure will
therefore appear as `MAVROS_SOURCE_PROBE_RUN result=TIMEOUT` followed by the
ordinary retry and three-attempt verdict, not as deadline exhaustion.

The reserve and bound remain unmeasured on the Pi. They are configurable so a
margin problem can be corrected without editing the helper.
