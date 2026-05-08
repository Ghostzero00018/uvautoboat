# 2026-05-11 — Monday: Herelink video A/B retest + carry-over follow-ups

## Context

First work day after the long weekend. Last work day was Thu 07/05, when the
first wet test ran on D1+D2 hardware-only scope: boat survived in-water
bring-up, Herelink manual control worked, QGC + Mission Planner over MAVLink
could arm/disarm, but laptop-side video feed in QGC + MP did not display.
Diagnostic recipe captured in
[`wiki/Common_Issues.md` § QGC / Mission Planner Can Arm via Herelink, but Video Is Missing](../wiki/Common_Issues.md#qgc--mission-planner-can-arm-via-herelink-but-video-is-missing).
Professor's clue (07/05): the same video stream reportedly worked at the
campus site previously — a location/topology variable to isolate before
declaring the cause purely configuration-side.

**Lead item today:** controlled campus-vs-second-site A/B retest of the Herelink
video pipeline to identify whether the 07/05 video failure is configuration-side
or location/link-condition-side. This unblocks later autonomy field tests
(laptop-side situational awareness is needed before D3+ scenarios).

**Week shape recap:**

- **Thu 07/05 (last work day)** — first wet test passed for D1/D2 hardware-only
  scope. 10 commits including the wet-test diary close, a published-but-
  unconsumed param fix (`drift_compensation_gain` end-to-end), an MD037
  fence-aware `A\*` escape sweep, folder-framing READMEs for `working_diary/`
  and `legacy/`, and a `PARAM_RANGES` tunable-contract policy doc. See
  `working_diary/2026-05-07_thursday_first_field_test.md` for per-block
  outcomes.
- **Fri 08/05** — V-E Day public holiday; no work.
- **Sat-Sun 09-10/05** — normal weekend.
- **Mon 11/05 (today)** — Herelink video A/B retest is the lead item;
  carry-overs slot in if A/B finishes early or has a blocking gap.
- **Pending all week:** formal joint supervisor presentation reschedule
  (per 30/04); three Asks to teammate maintainer (Phase A parameter subset, CA
  placement, validation methodology).

**Why the A/B retest matters:**

The 07/05 video failure has multiple plausible causes: Herelink not
re-streaming externally, QGC video source URL unset/wrong, location-dependent
link issue, or codec/pipeline issue. Without isolating the variable, future
field tests will keep tripping on the same gap. A controlled A/B at the
reported-good campus site followed by another field site with one variable
changing at a time is the cheapest way to identify the cause class.

Active blocks:

1. **Block A — Morning re-orientation** (~10 min, opening): catch up after the
   long weekend; check git log + status; review 07/05 outcomes; identify any
   weekend inputs (supervisor / teammate replies); confirm A/B retest go/no-go.
2. **Block B — Pre-A/B prep** (~15-20 min, AM): equipment + settings audit;
   re-read the `wiki/Common_Issues.md` diagnostic recipe; pre-decide which
   Herelink video-sharing settings to toggle if needed.
3. **Block C — Campus A test** (~30-60 min, AM-mid PM): full diagnostic chain
   at the reported-good campus site (`ip route` + `arp -a` +
   `vlc rtsp://...` + QGC video source config). Capture outputs.
4. **Block D — Second-site B test** (conditional, ~30-60 min, PM): only if
   Block C result demands the comparison AND a second site is reachable
   today. Same diagnostic chain with the same equipment + settings, single
   variable changed (location).
5. **Block E — A/B analysis + decision** (~30 min, late PM): compare Block C
   vs D outputs; categorize the failure class; document fix path.
6. **Block F — Day wrap** (~30 min, evening): diary outcomes, `Board.md`
   timeline row, update `wiki/Common_Issues.md` resolved branch, commit + push.

**Fallback if A/B retest can't run:**

If Herelink hardware isn't available, supervisor unavailable, or scheduling
slips, switch to interrupt-safe carry-overs (pausable on 5 min notice). Top of
fallback queue:

- **P1 pier/bank stuck investigation** — diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A.
  Substantial sim work, naturally pauseable. Requires
  `bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia` to
  hold acceptable RTF (per 04/05 RTF investigation: ~0.32 vs ~0.88 with the
  flag).
- **Roadmap §1.3 Path B prep** — research MBTiles options for the test region;
  required before first IoT-network field deployment.
- **Other deferred items** per 06/05 + 07/05 Next steps lists (24/04
  housekeeping carry-overs, dashboard scaffold-without-write audit, C3 bench
  verification, `launch/remap.launch.yaml` no-regression test).

---

## Block A — Morning re-orientation (~10 min, opening)

After a 3-day gap (Fri-Sun), catch up before starting field work:

- `git log --oneline -5` + `git status` — confirm tree clean, branch synced.
- Re-read 07/05 diary Block C/D/E outcomes + Block F next-steps list.
- Check email / Slack for: supervisor / teammate replies, weather updates,
  any field-test rescheduling, presentation reschedule.
- Confirm Herelink hardware is available + charged + at the campus site OR
  portable.
- Confirm A/B retest is still on; if not, branch into fallback queue.

**Outcome.** [To fill — git state, weekend inputs, A/B retest go/no-go.]

---

## Side activity — Pi 5 ↔ Linux workstation connectivity + ROS 2 topic capture (~30-45 min, AM, parallel-safe)

Long-deferred **"Real no-regression test for `launch/remap.launch.yaml`"** finally gets a chance — first time the Pi 5 is available on the lab network for an actual ROS 2 graph cross-machine handshake. Runs parallel to the A/B retest flow because the Pi 5 lives at the workstation, not the field site; slot into the Block A re-orientation gap, the Block B pre-prep window, or any wait period during Block C/D field hops.

**Pre-conditions:** Pi 5 powered on, on the same network as the Linux workstation, `ROS_DOMAIN_ID` matched both sides, both machines using the same `RMW_IMPLEMENTATION`.

1. **Network reachability** — `ping <pi5-ip>` from workstation; SSH if access is set up; `echo $ROS_DOMAIN_ID` on each machine to confirm match (default 0; agree on a non-zero value if multiple teams share the network).
2. **ROS 2 multi-machine discovery** — from workstation:

   ```bash
   ros2 daemon stop && ros2 daemon start   # clear stale discovery cache
   ros2 node list                           # expect Pi 5 nodes to surface
   ros2 topic list                          # expect Pi 5 topics to surface
   ```

   If neither shows up, debug in this order: `ROS_DOMAIN_ID` mismatch → `RMW_IMPLEMENTATION` mismatch (`echo $RMW_IMPLEMENTATION`) → DDS multicast / firewall on the lab network → IP routing.
3. **Topic name ground-truth capture** — save the full Pi 5 topic list to `/tmp/pi5_topics_2026-05-11.txt`:

   ```bash
   ros2 topic list > /tmp/pi5_topics_2026-05-11.txt
   wc -l /tmp/pi5_topics_2026-05-11.txt
   ```

   This is the first authoritative real-hardware ROS 2 topic snapshot — the ground truth `launch/remap.launch.yaml` was always supposed to bridge against.
4. **Compare to sim** — launch the sim briefly in another terminal (`bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia`), capture sim topic list, diff against Pi 5's. Identify any names that don't match: `/wamv/sensors/gps/gps/fix` vs whatever the real boat publishes, etc.

   ```bash
   diff <(sort /tmp/pi5_topics_2026-05-11.txt) <(ros2 topic list | sort)
   ```

5. **Document findings** — append discovery gotchas to `wiki/Common_Issues.md` (e.g., `ROS_DOMAIN_ID` setup, DDS multicast on lab network, mDNS resolution); flag the topic-name mismatches as deferred items for a future focused `launch/remap.launch.yaml` patch session.

**Hard rule:** do **NOT** modify `launch/remap.launch.yaml` today — capture findings only. The patch + no-regression test deserves its own focused session, not an inline change while doing field work.

**Pass criteria:** Pi 5 nodes + topics visible from workstation, full topic list archived to `/tmp/pi5_topics_2026-05-11.txt`, name-mismatch diff captured.

**Outcome.** [To fill — Pi 5 IP + connection mode, ROS_DOMAIN_ID + RMW_IMPLEMENTATION on each side, topic list line count, mismatches vs sim, doc updates landed in `wiki/Common_Issues.md`.]

---

## Block B — Pre-A/B prep (~15-20 min, AM)

Equipment + settings audit before walking out:

- Herelink Air Unit on the boat (or accessible) + Herelink GCS unit charged.
- Linux laptop with QGC + MP installed; VLC installed
  (`sudo apt install vlc` if not).
- Laptop charged; Ethernet/USB cable for Herelink connection (same mode as
  07/05 if known).
- `wiki/Common_Issues.md` "QGC / Mission Planner Can Arm via Herelink, but
  Video Is Missing" entry re-read; URL set ready.
- CubePilot Herelink video-sharing doc bookmarked or relevant section saved
  offline (in case campus has no internet for QGC tile fetch + reference).
- **Pre-decide:** which Herelink video-sharing setting to toggle if it's
  currently disabled. **Document the setting state before changing it** so
  the change is reversible if it doesn't help.

Pass criteria: equipment present + URLs ready + setting starting state
recorded.

**Outcome.** [To fill — equipment state, settings starting state, blockers.]

---

## Block C — Campus A test (~30-60 min, AM-mid PM)

At the reported-good campus site (where video reportedly worked previously per
professor's clue):

1. Connect laptop to Herelink GCS link (USB / Ethernet / hotspot — same mode
   as lake on 07/05 if known).
2. Verify MAVLink: open QGC, confirm arm/disarm works (same baseline as 07/05).
3. Capture network state:

   ```bash
   ip route
   arp -a
   ```

4. Test RTSP directly in VLC (URLs per CubePilot doc — `wiki/Common_Issues.md`
   has the canonical attempts):

   ```bash
   vlc rtsp://<herelink-ip>:8554/fpv_stream
   # OR if the doc points elsewhere:
   vlc rtsp://<herelink-ip>:8554/live
   ```

5. Capture VLC output (success or specific error).
6. If VLC works → configure QGC: Application Settings → General → Video →
   Source = "RTSP Video Stream", URL = the working VLC URL. Restart QGC. Test.
7. If VLC fails → check Herelink controller's video-sharing setting in the
   Herelink configuration app; enable if disabled; retest VLC.

**Pass criteria** (campus branch outcomes):

| Branch | What happened | Implication |
|:------:|:--------------|:------------|
| A1 | VLC + QGC both show video | Campus baseline good; isolates lake failure as a location/link-condition issue → Block D needed for confirmation |
| A2 | VLC works, QGC fails | QGC config issue; document the QGC-side fix |
| A3 | VLC fails, Herelink setting toggle fixes it | Herelink-side default-off issue; document the toggle as the fix that should also resolve the lake case |
| A4 | VLC fails, toggle doesn't help | Deeper issue (firmware, codec, network); escalate before more field tests |

**Outcome.** [To fill — branch (A1/A2/A3/A4), VLC output, Herelink settings
checked, QGC config used, time taken.]

---

## Block D — Second-site B test (conditional, ~30-60 min, PM)

Run only if **(a)** Block C result demands the comparison (e.g., A1 — campus
baseline good; need to confirm lake-specific failure) AND **(b)** a second
site is reachable today.

Same diagnostic chain as Block C with the same equipment + settings. Capture
the same outputs. Note any environmental differences (RF noise, range,
weather, link-quality indicators).

**Pass criteria** (B-site branch outcomes):

| Branch | What happened | Implication |
|:------:|:--------------|:------------|
| D1 | B-site video also works | Not a location issue; the campus fix solves the original 07/05 problem; document |
| D2 | B-site video fails identically (in VLC) | Location-side issue; deeper investigation needed (RF, range, link saturation) |
| D3 | B-site VLC works but QGC fails | QGC config drift between sessions; document |

**Outcome.** [To fill if Block D ran — branch (D1/D2/D3), B-site
observations, comparison vs campus.]

If Block C identifies the fix unambiguously (A2 or A3 with a reproducible
toggle), Block D may be deferred to a future combined autonomy test.

---

## Block E — A/B analysis + decision (~30 min, late PM)

Compare Block C and D outputs side by side:

| Variable | Campus (Block C) | B-site (Block D) | Notes |
|:---------|:-----------------|:-----------------|:------|
| `ip route` (default gateway) | | | |
| `arp -a` (Herelink IP) | | | |
| Connection mode (USB / Ethernet / hotspot) | | | |
| Herelink video-sharing setting | | | |
| RTSP URL attempted | | | |
| VLC result | | | |
| QGC video source setting | | | |
| QGC result | | | |

Categorize the cause:

- **Herelink-side config** (video-sharing disabled by default) → enable +
  document setting in `wiki/Common_Issues.md` resolved branch + add a
  Herelink-onboarding note.
- **QGC config drift** → fix QGC settings + add to setup guide / Common_Issues.
- **Location/link-condition** → investigate range / RF / network topology;
  flag as a constraint for lake operations + add to `Roadmap.md` as an open
  item before D3+ autonomy.
- **Mixed / inconclusive** → escalate to supervisor / teammate maintainer;
  document open question; possibly add to Phase 5 risks in `Board.md`.

**Outcome.** [To fill — root cause category, fix path, doc updates needed.]

---

## Block F — Day wrap (~30 min, evening)

Same shape as Thu 07/05:

1. `git log --oneline -10` — sanity check today's commits.
2. Pre-commit invisibility sweep — expect 0 matches.
3. Add 11/05/2026 Board.md milestone row(s) for whatever lands; bump
   header (L11) + trailer stamp to 11/05/2026 if anything substantive lands.
4. Fill all `[To fill]` placeholders in this file.
5. Update `wiki/Common_Issues.md` "QGC / Mission Planner Can Arm via Herelink,
   but Video Is Missing" entry — replace the speculative branch list with the
   confirmed root cause + fix; keep the diagnostic recipe so future readers can
   reproduce the test.
6. Working diary commit; subject template depends on outcome:
   - A/B identifies the fix:
     `docs: 11/05 Herelink video A/B retest — <root cause> identified`
   - A/B inconclusive:
     `docs(diary): log 11/05 Herelink video A/B retest (inconclusive)`
   - Fallback work landed:
     `docs(diary): log 11/05 fallback work; A/B retest deferred`
7. Push.

**Outcome.** [To fill at end of day.]

---

## Verification summary — 11/05 (check at end of day)

- [ ] Block A: morning re-orientation done; A/B retest go/no-go decided
- [ ] Side activity (Pi 5 connectivity): Pi 5 ↔ workstation ROS 2 graph handshake done; topic list archived; sim diff captured; `launch/remap.launch.yaml` patch deferred per the hard rule
- [ ] Block B: equipment + settings audit complete
- [ ] Block C: campus A test executed; outcome branch (A1/A2/A3/A4) recorded
- [ ] Block D: B-site test executed (if Block C demanded it) OR explicitly
      skipped with reason
- [ ] Block E: A/B analysis complete; root cause categorized; fix path
      documented
- [ ] Block F: diary filled; pre-commit sweep clean; `Board.md` updated;
      `wiki/Common_Issues.md` resolved-branch updated

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation done; go/no-go decided | None — drives the rest of the day |
| Side activity (Pi 5) | Pi 5 ↔ workstation ROS 2 graph verified; topic ground-truth captured | Low — interrupt-safe; partial completion (e.g., reachability OK but discovery fails) is informative on its own |
| Block B | Pre-A/B prep done | Low — useful regardless of A/B outcome |
| Block C | Campus baseline known | Medium — A/B retest stops here if Block C identifies the fix unambiguously (A2/A3) |
| Block D | B-site test complete (if run) | Hard requirement under A1 — without B-site confirmation, the location-variable hypothesis can't close |
| Block E | Root cause known | Medium — drives doc updates + future-test prep |
| Block F | Day closed | Standard — should always close |

---

## Known unknowns to record during the day

- Herelink video-sharing setting current state (enabled / disabled) before any
  toggling.
- Exact RTSP URL that works (or doesn't) at campus.
- Connection mode used at campus vs B-site (USB tether / Ethernet / hotspot
  / Wi-Fi).
- QGC version + Mission Planner version on each laptop.
- Whether the prof's machine reproduces the same outcome at campus.
- Range / RF environment differences between campus and B-site (if Block D
  runs).
- Whether the supervisor presentation reschedule arrived over the weekend.
- Any other weekend inputs (issue replies, teammate updates).

---

## Next steps — Mon 11/05 → end of week

### Active branch: today's A/B retest

Today's outcome drives the rest of the week's plan. After 11/05:

- **If A/B identifies the fix:** apply fix + plan a confirmation test
  (combined with the next field session); update `wiki/Common_Issues.md`
  resolved branch.
- **If A/B inconclusive:** escalate to supervisor / teammate maintainer;
  possibly add Herelink video as an open Phase 5 risk in `Board.md` /
  `wiki/Roadmap.md`.

### Pending all week (carried from 07/05)

- Formal joint supervisor presentation reschedule — date pending IMT Mines
  Alès availability + power restoration.
- Three Asks to teammate maintainer: Phase A water-quality parameter subset;
  CA model compute placement (Linux vs Pi 5); validation methodology.
  Field-test outcomes feed back into these.

### Deferred (carried from earlier)

- P1 pier/bank stuck investigation (diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A) —
  fallback target if A/B retest can't run today.
- Mock water quality sensor implementation (Phase A) — unblocked once
  supervisor confirms the parameter set.
- Roadmap §1.3 Path B (offline tile server, pre-generated MBTiles for test
  area) — required before first IoT-network field deployment.
- Dashboard CSP Option B (reverse-proxy header injection) and Option C
  (Caddy / external static webserver) — Option A landed; Option B is the
  long-term destination once auth lands.
- 24/04 housekeeping carry-overs: `mono-xsp4` port-8084 disable;
  `tools/qos_scan.py` single-pass QoS inventory.
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware double-reverse
  symptom.
- ~~Real no-regression test for `launch/remap.launch.yaml` — needs first real-hardware bench~~ — **discovery phase covered today's Side activity (Pi 5 connectivity + topic capture); patch session for the actual `remap.launch.yaml` no-regression test remains deferred to a focused future window once mismatches are catalogued.**
- Sim-to-real comparison — was conditional on a 07/05 rosbag; none recorded,
  so this is N/A until a future field test records autonomy bag data.
- External Week 9 diary Thu 07/05 "Outcome:" line — bilingual EN + 中文,
  Windows-side; deferred to next Windows session.
