# 2026-05-05 — Tuesday: first field test (small artificial lake, afternoon if confirmed)

## Context

Pre-scaffold drafted Mon 04/05 evening. Tomorrow's lead item is the **first wet test of the autonomy stack** at a small artificial lake in a park, **expected afternoon** but the schedule is not officially confirmed yet — could slip to Wed 06/05 or later in the week. The day is structured around two branches: (a) test confirmed → on-site deployment; (b) test deferred → fall back to deferred sim work and stay ready to deploy on short notice.

Until now every claim about the autonomy stack has rested on VRX simulation behaviour on the campus workstation. Sim-to-real gap surfaces will be the dominant unknowns: GPS lock time + accuracy under open sky vs sim-perfect coordinates, IMU drift on a real water surface, thruster response under real water resistance, network reach between operator station and boat, and any hardware-bring-up quirks that didn't show on the bench.

**Week shape recap:**

- **Mon 04/05 (yesterday)** — RTF investigation root-caused (prime-offload to NVIDIA, RTF 0.32 → 0.88); evening Block F lint debt cleanup + dashboard XSS remediation. Ten commits on `origin/main`.
- **Tue 05/05 (today)** — first field test if confirmed; otherwise deferred sim work with on-call readiness.
- **Wed 06/05 onwards** — depends on Tue outcome: post-test sim-vs-real comparison, hardware-quirk fixes, or carry the field-test scaffold forward to whichever day actually happens.
- **Pending all week:** formal joint supervisor presentation reschedule (per 30/04); three Asks to teammate maintainer (Phase A parameter subset, CA placement, validation methodology); V-E Day public holiday Fri 08/05 (no work).

**Why this matters:**

A small artificial lake in a park is a **bounded-risk first wet test**: small enclosed water body (no current, no surf, no commercial traffic), shore-accessible recovery, low-stakes if something fails. First chance to discover the surprises that simulation can't reproduce — and any failure mode it does surface is far less expensive to chase here than later at a larger water body.

Active blocks (conditional on test confirmation, marked PM-only as such):

1. **Block A — AM confirmation check** (~5 min, opening): is the field test happening this afternoon? Branch on the answer.
2. **Block B — Pre-deployment workstation prep** (~30-60 min, AM): irrespective of A, do the prep that's cheap and useful in either branch — final sim sanity, rosbag config dry-run, deployment artifact bundle.
3. **Block C — Hardware bring-up on-site** (PM, **conditional on A=GO**): physical setup, sensor calibration, dry-land sanity, network up.
4. **Block D — In-water test scenarios** (PM, **conditional on A=GO and C=PASS**): the actual mission cases, with abort criteria spelled out per scenario.
5. **Block E — Post-test data capture + debrief** (early evening, **conditional on A=GO**): rosbag offload, immediate observations, photo / video index.
6. **Block F — Day wrap** (~30 min, evening): diary outcomes, Board.md, commit + push.

**Fallback if A=NO-GO:**

If the field test is not confirmed by ~13:00 local, switch to deferred sim work for the afternoon and keep on-call readiness in case confirmation comes late:

- **Top of fallback queue:** P1 pier/bank stuck investigation (diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A) — substantial sim work, naturally pauseable.
- **Secondary:** `--use-nvidia` discoverability follow-up (single-line additions to README's Quick Start + `wiki/Quick_Start.md` per yesterday's diary deferred list).
- **Tertiary:** Dashboard Content Security Policy scoping (per yesterday's deferred list — research what `default-src` / `script-src` headers should look like for the dashboard's `python3 -m http.server 8002` source).

Anything started in fallback mode must be **interrupt-safe** — pausable on 5 min notice if the test gets a late green light.

---

## Block A — AM confirmation check (~5 min, opening)

The trigger for the day's branch. Check whichever channel the field-test confirmation is expected on (email / Slack / direct ping from teammate or supervisor) and decide:

- **Confirmed PM** → Blocks B → C → D → E → F.
- **Confirmed but slipped (Wed/Thu)** → Block B (cheap prep so we're ready), then fallback queue.
- **Not confirmed by ~13:00** → fallback queue, re-check at ~15:00.
- **Cancelled outright** → fallback queue full afternoon, carry the field-test scaffold forward to whichever day it lands on.

**Outcome.** [To fill — confirmation status + decision branch + time of decision.]

---

## Block B — Pre-deployment workstation prep (~30-60 min, AM)

Cheap prep that's worth doing whether or not the test runs today. Most of this is verification that nothing in yesterday's evening Block F broke the deployment path, plus laying the groundwork that makes a same-afternoon green light low-friction.

### B1 — Final sim sanity post-Block-F

Yesterday's evening Block F touched lint across `control/` + `plan/` and rewrote dashboard renderers. Sim was tested but only for "no contract surface shifted". One last full mission run end-to-end to confirm:

```bash
cd ~/seal_ws/src/uvautoboat
git pull
bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia
# After "AutoBoat System Launched Successfully!":
ros2 run plan autoboat_cli generate
ros2 run plan autoboat_cli confirm
ros2 run plan autoboat_cli start
# Watch a full mission cycle (~2-5 min depending on waypoints).
```

Pass criteria: 5/5 nodes up, dashboard connects + renders correctly (events log / mission history / waypoint validation post-XSS-rewrite), mission generates + confirms + starts + completes (or pauses cleanly), no fresh crashes in `/var/crash/`.

### B2 — Rosbag config dry-run

Decide what topics to record in the field. Likely scope for the autonomy stack:

- `/wamv/sensors/gps/gps/fix` (NavSatFix — GPS position)
- `/wamv/sensors/imu/imu/data` (Imu — orientation)
- `/wamv/thrusters/left/thrust` + `/wamv/thrusters/right/thrust` (Float64 — commanded thrust)
- `/perception/obstacle_info` (String JSON — obstacle classification, **only if LiDAR is on the real boat — TBD**)
- `/planning/current_target`, `/planning/mission_status`, `/planning/waypoints` (planner state)
- `/control/status`, `/control/heading_error`, `/control/anti_stuck_status` (controller state)
- `/health_check/line`, `/health_check/status` (operator-side health stream)
- `/planning/emergency_stop` (Bool latched — capture so the timeline of E-stop events is in the bag)

**[TBD: confirm real-hardware topic names match the sim names — they should via `launch/remap.launch.yaml`, but this is exactly what the deferred "Real no-regression test for `launch/remap.launch.yaml`" item exists to check.]**

Dry-run command — record 30 s of sim, verify the bag contains all expected topics, no `Topic not yet subscribed` warnings:

```bash
ros2 bag record -o /tmp/autoboat_dryrun \
    /wamv/sensors/gps/gps/fix /wamv/sensors/imu/imu/data \
    /wamv/thrusters/left/thrust /wamv/thrusters/right/thrust \
    /perception/obstacle_info \
    /planning/current_target /planning/mission_status /planning/waypoints \
    /planning/emergency_stop \
    /control/status /control/heading_error /control/anti_stuck_status \
    /health_check/line /health_check/status
# Ctrl+C after ~30 s
ros2 bag info /tmp/autoboat_dryrun
```

Pass criteria — split by topic class:

- **Continuous telemetry topics** (sensors, thrusters, planner state, controller state) — expect non-zero message counts after a 30 s mission run with `--use-nvidia` sim.
- **Event-driven topics** (`/health_check/line`, `/health_check/status`, `/planning/emergency_stop`) — these only publish when triggered. Either fire them during the dry-run (run a health check; briefly toggle dashboard E-stop and reset) to verify they're recordable, or treat zero count on these three as expected for a passive run and confirm the publishers are at least *advertised* via `ros2 topic info <topic>`.

### B3 — Deployment artifact bundle

If the test is happening this afternoon, what gets carried to the lake? A short checklist worth writing down before the rush. Categories — actual contents are user-specific and depend on the hardware build:

- [ ] **Boat hardware** [TBD inventory — battery state of charge, propellers, hull, sensor mounts, power-on order]
- [ ] **Operator station** [TBD — laptop or Pi 5 + dashboard? Tethered or wireless rosbridge?]
- [ ] **Network gear** [TBD — router / hotspot / direct ethernet?]
- [ ] **Tools** [TBD — basic toolkit, multimeter, spare cables, charger]
- [ ] **Recovery / safety** [TBD — boat hook / tether line / life preserver if working from shore]
- [ ] **Logging media** [phone for photos + video; USB drive for rosbag offload if the operator station can't carry it back directly]
- [ ] **Permits / permissions** [TBD — park rules, prior notification given to whoever manages the lake]

### B4 — VRX fork-or-don't periodic re-evaluation (Windows-side, parallel — not Linux-blocking)

Per `wiki/Roadmap.md` §8.5 ("re-open this section only when one of the §8.2 triggers fires"), Mon 04/05 evening review-pass found **0/4 triggers fired**:

- Patch count growth: not fired (1 patch — `patch_vrx.sh`, upstream issue #876).
- Custom worlds / sensors / WAM-V mods upstream wouldn't merge: not fired (custom content lives in `test_environment/`, independent of VRX repo layout).
- Phase 5+ hardware integration with sim-side incompatibilities: not fired (Phase 5 not started; first wet test scaffolded for this very afternoon if A=GO).
- Long-term maintenance balance flips: not fired (no upstream major release flagged).

**Decision: HOLD.** Plan file with full feasibility assessment + ready-to-execute swap procedure (if a trigger ever fires) lives off-repo on the Windows-side machine (full path noted in Mon 04/05 evening session — kept out of tracked prose because the host directory is privacy-flagged). Two execution-detail corrections to fold into that plan-doc:

1. **§3 reference-surface table — split into three semantic tiers.** Real swap face narrows from 14 lines to:
   - **Must-swap (5 lines)** — `README.md` L62, `USER_MANUAL.md` L357, `wiki/Installation_Guide.md` L51 + L55 + L94. These are the active install/clone URLs.
   - **Dual-link (1 line)** — `USER_MANUAL.md` L346, Installation prerequisites context: write as "depends on fork at `<URL>` (canonical project: `github.com/osrf/vrx`)" so the dependency arrow and the upstream-attribution arrow are both explicit.
   - **Keep `osrf/vrx` (9 lines)** — `USER_MANUAL.md` L51 (Abstract / canonical project link), L477 (tutorial credit), L1702 (VRX Wiki), L1713 (Virtual RobotX project link); `wiki/Home.md` L78 (VRX Official Wiki); `wiki/Installation_Guide.md` L246 (reference link); `wiki/System_Overview.md` L14 (architecture text); `test_environment/sydney_regatta_DEFAULT.sdf` L8 + `test_environment/wamv_3d_lidar.xacro` L8 (copied-from-upstream attribution headers).
2. **§5.1 fork-creation step — add directory-name invariant.** Fork repo basename must remain `vrx` so the checkout dir at `~/seal_ws/src/vrx` matches `patch_vrx.sh` L20 hardcoded path during the patch-as-safety-net transition (the patch script stays as idempotent no-op for ≥2 release cycles after fork-bake-in). Fallback if a future fork is renamed: `git clone <fork-URL> vrx` to force the directory name — but every contributor would need to remember the parameter. Preferred: don't rename the fork basename.

P3 deferral: `wiki/Roadmap.md` §8.1 baseline wording is stale (`consumes upstream VRX via apt + patch` → actual is `source clone + colcon build + runtime patch`). Doesn't affect the HOLD/GO judgment; fix only when §8 narrative is next touched (i.e., if/when a trigger fires and §8 gets rewritten as the swap-rationale narrative).

**Path-permission note:** if the off-repo plan-doc path isn't in the writable-roots set tomorrow, fall back to staging the corrected §3 + §5.1 sections in chat for manual paste — **do not** stage copies of the off-repo plan-doc inside the workspace (its host directory sits under privacy-flagged tooling state and any copy here would not survive a pre-commit invisibility sweep).

Interrupt-safe — pause on 5 min notice if Block A returns a late green light.

**Outcome.** [To fill — sanity run result (B1) + rosbag dry-run topic counts (B2) + deployment-bundle status (B3) + VRX HOLD logging confirmation + plan-doc §3/§5.1 correction status (B4, write-permission-dependent).]

---

## Block C — Hardware bring-up on-site (PM, conditional on A=GO)

First wet-test brings up the boat for the first time outside controlled bench conditions. Order of operations, dry-land before water:

1. **Visual + mechanical inspection** — hull integrity, propeller condition, no loose connections, all sensors mounted at expected angles.
2. **Power-on sequence** — match whatever the bench-tested order is (likely: low-voltage / control electronics first, thrusters last). Record battery starting voltage.
3. **Sensor sanity (dry land)** — `ros2 topic echo --once /wamv/sensors/gps/gps/fix` (open-sky GPS lock — should converge within ~30 s of clear-sky boot in a park; record time-to-lock); `/wamv/sensors/imu/imu/data` (IMU orientation makes sense relative to physical orientation); LiDAR or any other sensors the real boat carries.
4. **Network up** — operator station ↔ boat link verified. `ros2 node list` from operator station shows the boat's nodes; dashboard at the chosen port responds. **Watch for the rosbridge close-handler resilience verified yesterday in Block F6** — if the field network drops momentarily and reconnects, the dashboard should resubscribe cleanly without the operator clicking refresh.
5. **E-stop test (dry land, motors disabled OR boat held off the ground)** — verify the dedicated `/planning/emergency_stop` path latches as expected. Click the dashboard's E-stop, watch the controller terminal log "E-Stop received", verify thrusters do not respond to subsequent commands until reset. Critical to do this BEFORE any in-water test.
6. **Tethered short thruster test (dry-dock or boat lifted off ground)** — brief differential-thrust command via dashboard or `ros2 run control keyboard_teleop`; observe thrusters spin in expected direction (left command → left propeller, etc.). Cut power before anything's in the water.

Pass criteria: every step green, no surprise warnings in any node's terminal.

If anything fails: capture the specific symptom + log + photo, abort the in-water portion, debrief at the workstation. A failed dry-land bring-up is **not** a failed day — it's the test surfacing exactly the kind of issue the field test exists to catch.

**Outcome.** [To fill if applicable — pass / partial / abort, with specifics + GPS lock time + battery starting voltage.]

---

## Block D — In-water test scenarios (PM, conditional on A=GO and C=PASS)

Scope: a small artificial lake in a park is a bounded environment. Recommended scenario order, simplest first, each gated by the previous one passing. Tether is the ultimate abort path through D3 — keep it on as long as practical.

### D1 — Tethered float (no autonomy, motors off)

Boat in the water, held by tether. Verify it floats level, no leaks visible, no electronics issues from water proximity (RF reflection, condensation, shifted IMU bias). Watch for ~5 min. Capture starting GPS coordinates.

### D2 — Tethered keyboard teleop (manual control)

Boat in water, held by tether. Operator drives thrusters via `keyboard_teleop` or dashboard manual control. Verify forward / reverse / turn commands produce expected motion, that the boat can recover from a stop, and that thruster response feels reasonable. Tether limits travel; this is a thrust-and-controls sanity check, not a navigation test.

### D3 — Tethered single-waypoint autonomous (short-leash autonomy)

Boat in water, tether long enough to allow ~5-10 m of travel. Place a single GPS waypoint nearby (relative to the boat's starting GPS captured in D1). Run `autoboat_cli generate / confirm / start` for a one-waypoint mission. Observe: does the boat point in the right direction? Does it close on the waypoint? Does it stop when arrived (within `waypoint_tolerance` = 3.5 m default)? **Tether is the ultimate abort path** — if the controller misbehaves, the tether limits the blast radius.

### D4 — Untethered short autonomous mission (full autonomy, bounded scope)

Only if D3 went cleanly. Multi-waypoint short mission much smaller than the sim default (sim runs `lanes=10`, `scan_width=30` — for a small lake start with `lanes=2`, `scan_width=10` or whatever fits the lake's actual dimensions). Operator monitors via dashboard, ready to issue `/planning/mission_command stop` or trigger `/planning/emergency_stop` on any anomaly. Recovery plan: tether retrieval, boat hook from shore, or other authorized shore-side recovery means. Water entry only if explicitly permitted by site rules, supervised, and with appropriate safety gear (life preserver / wading boots / etc.) — not the default plan.

### D5 — Obstacle / edge handling (only if D4 stable)

Drive a path that brings the boat close to the lake's edge or a known obstacle (a buoy, the bank). Observe whether perception sees it (if LiDAR is on board), whether the planner avoids it, whether the controller turns away. This is the actual sim-to-real comparison for obstacle avoidance.

### Abort criteria (any scenario)

- Boat starts moving in an unexpected direction → E-stop, recover.
- GPS coordinates jump > a few metres → E-stop, debug from shore.
- Any node crashes (`ros2 node list` drops a name) → E-stop, recover.
- Battery drops below the safe operating threshold → return-home or E-stop.
- Visible water ingress → E-stop, recover immediately.
- Person, animal, or floating object enters the test zone → E-stop, wait, resume.
- Field network drops for > a few seconds without dashboard auto-recovery → E-stop, recover, then debug whether yesterday's reconnect fix actually held in field conditions.

**Outcome.** [To fill per scenario — D1, D2, D3, D4, D5 each with pass / partial / abort + observations + measurements vs sim expectations (GPS lock time, time-to-waypoint, thruster command vs realised motion, dashboard latency).]

---

## Block E — Post-test data capture + debrief (early evening, conditional)

Immediately after the boat is out of the water and powered down, before anything reboots or memory fades:

1. **Rosbag offload** — copy the bag from the operator station to a stable location (USB drive or laptop disk). Re-verify `ros2 bag info` shows expected topic counts. If recording was on the boat itself, offload before powering anything down on that side.
2. **Photo / video index** — collect any phone photos or video into a single folder; rough timestamp + scenario label per asset.
3. **Battery final voltage** — record. Compare against starting voltage to estimate consumption per mission length — first real measurement, will calibrate future field-test budgets.
4. **Surface impressions** — write down anything surprising while it's fresh: thruster noise, GPS lock time, dashboard latency over the field network, perception behaviour at the lake edge, anything that didn't match sim. Goes into "Known unknowns" below.
5. **Hardware return state** — anything damaged / leaking / out-of-spec → flag for next-day inspection, don't rely on memory tomorrow.

**Outcome.** [To fill — files captured (rosbag size + path; photo count), immediate observations, hardware state.]

---

## Block F — Day wrap (~30 min, evening)

Same shape as yesterday's wrap:

1. `git log --oneline -10` — sanity check today's commits (if any).
2. Pre-commit grep — sweep for blocklist matches; expect 0.
3. Add 05/05 Board.md milestone row(s) for whatever lands.
4. Fill the `[To fill]` placeholders throughout this file.
5. Working diary commit; suggested subject template depends on outcome:
   - Field test happened: `docs: log 05/05 first field test outcomes`
   - Test deferred: `docs: log 05/05 fallback work; field test rescheduled`

If the field test happened, **also** write a short "first wet test" entry in the external Week 9 diary (`Research_intern_IMT_NE/working_diary/Week9_04_05-08_05.md`) — that's a higher-level milestone worth recording cross-document. Deferred to the next Windows-side session if the external diary is only accessible there.

**Outcome.** [To fill at end of day.]

---

## Verification summary — 05/05 (check at end of day)

- [ ] Block A: confirmation status determined; decision branch logged
- [ ] Block B: B1 sim sanity pass, B2 rosbag dry-run pass, B3 deployment bundle status recorded
- [ ] Block C: hardware bring-up [pass / partial / abort + reason]
- [ ] Block D: in-water scenarios [per-scenario status]
- [ ] Block E: data offloaded, observations captured
- [ ] Block F: diary filled; pre-commit sweep clean; Board.md updated
- [ ] External Week 9 diary Tue "Outcome:" line *(deferred to next Windows session if field test ran)*

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Decision branch chosen | None — drives the rest of the day |
| Block B | Pre-deployment prep done | Low — useful regardless of A outcome |
| Block C | Hardware bring-up state known | High if abort — debrief is the day; in-water portion slips to next test window |
| Block D | First wet-test scenarios complete | Carryover into Wed if any scenario aborted before completion |
| Block E | Data captured | Hard requirement — without rosbag + photos + voltages, the test isn't reproducible / debuggable later |
| Block F | Day closed | Standard — should always close |

---

## Known unknowns to record during the day

Same shape as yesterday — capture surprises with `file:line` / command + observation + follow-up. Pre-seeded with the categories most likely to surface; fill or delete as they resolve.

- [Field-test confirmation timing — when did the green light arrive, if at all]
- [Hardware quirks surfaced during Block C bring-up]
- [GPS lock time + accuracy in this specific park (sim assumes instant lock + perfect coordinates)]
- [Thruster behaviour vs sim expectations — overshoot, undershoot, asymmetry, dead-zone]
- [IMU drift rate on a real water surface — sim has no surface noise]
- [Dashboard latency over the field network — sim is localhost; field may be wireless / hotspot]
- [Sensor topic name mismatches between sim and real (the deferred `remap.launch.yaml` no-regression check)]
- [Battery drain per mission length — first real measurement]
- [Whether the rosbridge reconnect resilience verified yesterday holds in field conditions (intermittent wifi, not just `pkill rosbridge_websocket`)]
- [Perception behaviour at lake-edge transitions (water → bank) if LiDAR is on the boat]

---

## Next steps — Wed 06/05 onwards

### Conditional on Block D outcome

- **If field test ran cleanly:** sim-to-real comparison day on Wed — replay the rosbag through analysis tools, compare measured trajectories vs planner outputs, document any sim-to-real gaps in `wiki/`. Schedule a short report for the supervisor / teammate maintainer.
- **If field test aborted partway:** debrief the abort cause (hardware fix? code fix? environmental factor?), schedule the fix, and re-attempt as soon as repaired and weather-permitting.
- **If field test deferred to a later date:** carry this scaffold forward to whichever day actually happens — copy this file to the new date with `[To fill]` placeholders re-blanked.

### Pending all week

- **Formal joint supervisor presentation** — rescheduled per 30/04; date pending IMT Mines Alès availability + power restoration.
- **Three Asks to teammate maintainer** (sent in writing after 30/04 scoping session): Phase A water-quality parameter subset; CA model compute placement (Linux vs Pi 5); validation methodology. Field-test outcomes feed back into these — especially CA placement (real-hardware compute headroom is now measurable post-test).
- **V-E Day Fri 08/05** — public holiday, no work.

### Deferred (carried over from 04/05)

- P1 pier/bank stuck investigation (diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A) — fallback target for today.
- Mock water quality sensor implementation (Phase A) — unblocked once supervisor confirms the parameter set.
- `--use-nvidia` discoverability follow-up (5 user-facing docs to update — `README.md`, `wiki/Quick_Start.md`, `USER_MANUAL.md`, `web_dashboard/autoboat/README_autoboat_dashboard.md`, `wiki/Common_Issues.md`).
- Dashboard Content Security Policy — residual XSS hardening surface flagged in `wiki/Dashboard_Security.md` after yesterday's renderer-fix pass.
- Dashboard offline-capable for IoT-local network deployment (per Roadmap §1.3).
- 24/04 housekeeping carry-overs: `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory.
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware double-reverse symptom (today's field test may surface this naturally).
- Real no-regression test for `launch/remap.launch.yaml` — needs first real-hardware bench (today's deployment may exercise this, if the field stack uses the remap layer).
