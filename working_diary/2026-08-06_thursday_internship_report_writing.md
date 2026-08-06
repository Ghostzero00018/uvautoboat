# Thursday 06/08/2026 - internship report writing, no repository work

## Status

The day went to the internship report. No work was carried out on this
repository: no code, configuration, test, documentation or wiki change, no Pi
session, no control box, no live run, and no hardware contact of any kind.

The report is tracked in a separate private repository and is out of scope for
this diary. Nothing about its content is recorded here.

## Repository state

`main` is unchanged at the revision that closed 05/08/2026, `ba827c1`, with
`HEAD == main == origin/main` and divergence `0/0`. Production pins are
untouched:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `tools/pi_live_hailo_mavlink_dashboard.sh` | `71,501` bytes | `31bcee05d3d664d4b825648cfac1edd2c116becd1da87108113f1de89d1f56aa` |
| `tools/live_dashboard_preflight.sh` | `28,647` bytes | `958000f4fdae071a2f24a4864d81f88ed885bb8ed1ad71b6ed60eda3111a6877` |

## Planned work deferred

This date was originally scaffolded for ArduPilot SITL and the command-ingress
design. That plan was **not started** and has been moved unchanged in substance
to `working_diary/2026-08-07_friday_ardupilot_sitl_and_command_ingress_design.md`.
This file was renamed to match what the day actually was; it had never been
started, so no record was overwritten.

Four corrections were made while moving it, none of which alter its scope:

- `check_command_sentinel` is referenced at `31` call sites, not "ten-plus".
  The definition is at `:965`. `reject_command_services` (`:535`) and
  `reject_unexpected_command_subscribers` (`:902`) were verified unchanged.
- `LIVE_MAVLINK_VIEW_ONLY` was written in environment-variable form. It is a
  source constant, `const LIVE_MAVLINK_VIEW_ONLY = true;` at
  `web_dashboard/autoboat/app.js:263`, asserted literally by
  `web_dashboard/autoboat/test/mavlink_telemetry.test.js:234`. It cannot be set
  at runtime, and changing it fails the suite. The moved file states this.
- The disk and network figures (`94%`, `13 GB` free, `IoT IMT Nord Europe`) were
  measured on 05/08/2026 and are carried as **stale inputs to be re-measured**
  in Block A rather than as current facts.
- Block C previously pointed at "the domain note in the project's recorded
  configuration" without naming it. The moved file names the mechanism instead
  of a bare number: the helper resolves `DOMAIN="${LIVE_ROS_DOMAIN_ID:-12}"` at
  `:16` and exports it as `ROS_DOMAIN_ID` at `:1343`, so `12` is the default
  rather than a fixed value, and the domain the last live run actually used has
  to be checked rather than assumed.

A scheduling note was added rather than moved: 07/08 is the last working day of
the week, and Block B is the only step whose duration is not under our control.
Blocks A and B are the realistic target; carrying C and D into next week is the
expected outcome, not a failure.

The moved file pins no starting hash, because it was written before the commit
that closes today existed. It names the expected parent in words and requires
certification instead. That is deliberate: a self-describing hash written into
the commit that carries it is stale the moment it lands, which this diary series
has already had to correct once.

## Carried forward, unchanged

The graph-query workstream stays parked, not closed: the lower DDS/RMW/network
trigger is unidentified, browser-last ordering is unobtained, the
`live_dashboard_20260724_175832` cumulative timing cause is open, and the
terminal data-plane probe has never fired.

Real-boat thrust remains behind the powered-off, propellers-removed wiring gate
plus `ARMING_REQUIRE=1` and the safety switch. Task 2 remains retired.

**Next step:** Friday 07/08/2026, the deferred SITL and command-ingress day.
