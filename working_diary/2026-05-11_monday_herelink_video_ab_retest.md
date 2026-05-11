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
   `ffplay rtsp://...` + QGC video source config). Capture outputs.
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
- Check weekend inputs if accessible (supervisor / teammate replies, weather
  updates, field-test rescheduling, presentation reschedule). If email / Slack
  are not reachable from this Agent context, ask the user to report any
  weekend inputs verbally — do NOT silently mark this checked.
- **VRX §8.2 weekly re-eval (~30 sec)** — per Wed 06/05 Block A.5 schedule,
  today is the weekly cadence point. Verify 0/4 §8.2 triggers still hold
  (patch count growth / custom mods / Phase 5+ sim-incompat / upstream major
  release) per `wiki/Roadmap.md` §8.2. This is the §8.2-axis maintenance
  check, separate from Wed 06/05's fork execution which was on the
  onboarding-value axis.
- Confirm Herelink hardware is available + charged + at the campus site OR
  portable.
- Confirm A/B retest is still on; if not, branch into fallback queue.

**Outcome.** Repo state clean and ff-up-to-date on both `uvautoboat` (tip `602831d`, scaffold + guardrails chain landed 11/05/2026) and `vrx` `autoboat/main` (tip `e384cd65`, fork bake-in unchanged since 06/05). 07/05 outcomes re-read (Thu wet test D1/D2 PASS via Herelink manual + QGC/MP MAVLink arm-disarm; laptop-side video FAIL = today's lead diagnostic). **Weekend inputs:** none — no supervisor presentation reschedule yet, no teammate replies on the three Asks (Phase A parameter subset / CA placement / validation methodology). **Herelink hardware:** ready, charged, at the campus working room. **A/B retest go/no-go:** GO, campus-only (second-site/lake retest pre-decided as deferred). **VRX §8.2 weekly cadence (Mon AM):** 0/4 triggers fired, HOLD stands — T1 patch count = 1 bake-in on `autoboat/main` (≪3 threshold), T2 custom mods = 0, T3 N/A pre-Phase-5-sim-coupling, T4 latest upstream tag = `v3.1.2` (vs `v3.1.0` at fork) which is a semver patch bump and doesn't fire the "major release" condition. `git log autoboat/main..upstream/main` empty.

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

**Outcome.** **Deferred** — Pi 5 is reachable only on the `IoT IMT Nord Europe` private workstation↔Pi link (note: this is **not** the institutional IoT-only network described in `wiki/Roadmap.md` §1.3 — same SSID name, different network meaning in user's setup; the §1.3 description should be re-checked next session). The workstation has one WiFi adapter (`wlp147s0`), so reaching the Pi 5 requires a temporary switch off `IMT Nord Europe 5G` campus WiFi (no internet during the offline window, no remote-tooling reach). Single-adapter offline-switch workflow drafted (`nmcli connection up "IoT IMT Nord Europe"` → `ssh <user>@<pi5-ip>` → `ros2 node list` + `ros2 topic list > /tmp/pi5_topics_2026-05-11.txt` + sim diff → `nmcli connection up "IMT Nord Europe 5G"`), but not executed today — Block C consumed the campus-room window first, and the discovery-phase capture needs prerequisites still TBD (Pi 5 IP on the IoT link, SSH user, ROS 2 Jazzy install state with `ROS_DOMAIN_ID=56` matching this workstation, same `RMW_IMPLEMENTATION` on both sides). `launch/remap.launch.yaml` no-regression test stays in its original "needs first real-hardware bench" state — re-evaluate at the next focused Pi 5 session.

---

## Block B — Pre-A/B prep (~15-20 min, AM)

Equipment + settings audit before walking out:

- Herelink Air Unit on the boat (or accessible) + Herelink GCS unit charged.
- Linux laptop with QGC + MP installed; `ffplay` installed
  (`sudo apt install ffmpeg` if not).
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

**Outcome.** Equipment + settings handled implicitly at session start in the intern working room: Herelink Air Unit + Ground Controller powered up, camera feed visible on the controller's own screen, `IMT-Aquatic-drone` hotspot saved profile already on the laptop (verified via `nmcli connection show`), QGC + Mission Planner installed (per 24/04/2026 install row in `Board.md`), no extra equipment moves needed because the working room is the test location and the laptop ↔ Herelink path was already proven 07/05/2026. No formal fill-in form completed under time pressure (consistent with Thu 07/05 Block B outcome).

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

4. Test RTSP directly with `ffplay` (URLs per CubePilot doc —
   `wiki/Common_Issues.md` has the canonical attempts):

   ```bash
   ffplay rtsp://<herelink-ip>:8554/fpv_stream
   # If the default UDP transport hangs in a restrictive network:
   ffplay -rtsp_transport tcp rtsp://<herelink-ip>:8554/fpv_stream
   ```

5. Capture `ffplay` output (success or specific error).
6. If `ffplay` works → configure QGC: Application Settings → General → Video
   → Source = "Herelink Hotspot" for the built-in preset, or "RTSP Video
   Stream" + URL if testing a manual stream source. Restart QGC if needed.
7. If `ffplay` fails → check Herelink controller's video-sharing setting in
   the Herelink configuration app; enable if disabled; retest `ffplay`.

**Pass criteria** (campus branch outcomes):

| Branch | What happened | Implication |
|:------:|:--------------|:------------|
| A1 | `ffplay` + QGC both show video | Campus baseline good; isolates lake failure as a location/link-condition issue → Block D needed for confirmation |
| A2 | `ffplay` works, QGC fails | QGC config issue; document the QGC-side fix |
| A3 | `ffplay` fails, Herelink setting toggle fixes it | Herelink-side default-off issue; document the toggle as the fix that should also resolve the lake case |
| A4 | `ffplay` fails, toggle doesn't help | Deeper issue (firmware, codec, network); escalate before more field tests |

**Outcome.** **A1 with MP-Linux split out as a separate runtime issue** (the original A1-A4 table assumed uniform GCS behaviour; today's evidence shows QGC and MP can fail independently, and MP's failure is GCS-runtime-side rather than Herelink-side):

- **Herelink controller QGC + MP**: both connecting + video both fine (baseline confirms Herelink itself is fine).
- **Linux QGC**: connection + video both fine. Config snapshot: `Application Settings → General → Video → Source = Herelink Hotspot` (built-in QGC preset; no manual URL field involved); all other Video panel settings at QGC defaults (Aspect Ratio `1.777777` = 16:9, Low Latency Mode OFF, Default decode priority, mp4 record format). `.ini` snapshot: `[Video] videoSource=Herelink Hotspot`, `recordingFormat=2`. Screenshot archived at `~/Pictures/Screenshots/qgc_video_settings_2026-05-11_campus.png`. Full config-dir backup at `~/qgc_config_2026-05-11_campus.bak/`.
- **Linux Mission Planner**: connection fine; video panel pops `Send Error` dialog with stack trace `System.TypeInitializationException: The type initializer for 'SkiaSharp.SKObject' threw an exception. ---> System.DllNotFoundException: Unable to load library 'libSkiaSharp'`. GCS-runtime-side, not a Herelink / RTSP / video config issue. Same failure class as the 24/04/2026 `GDAL / OGR / OSR` gap. Split out as a separate `wiki/Common_Issues.md` entry "Mission Planner on Linux: libSkiaSharp DllNotFoundException". Error screenshot archived at `~/Pictures/Screenshots/missionplanner_error_message_video_stream.png`.
- **Independent RTSP verification via `ffplay`** (tool-independent baseline for the underlying stream behind QGC's preset; QGC's "Herelink Hotspot" preset is **consistent with** this verified endpoint — stronger claims like "talking to the exact same server" would need QGC log / packet capture):
  - Workstation IP `192.168.43.160/24` on hotspot; Herelink IP = `192.168.43.1` (gateway, MAC `c0:f5:35:41:5e:4c`); ping 0% loss, RTT ~3-7 ms (one outlier 42 ms in the first round, likely DHCP-warm-up).
  - `ffplay rtsp://192.168.43.1:8554/fpv_stream` ✓ — LIVE555 Streaming Media v2018.02.28 server, H.264 High @ 1920×1080 30 fps, yuv420p progressive. RTP/AVP profile 96, control track `track1`.
  - `ffplay -rtsp_transport tcp rtsp://192.168.43.1:8554/fpv_stream` ✓ — same stream over TCP-interleaved transport.
  - `ffplay rtsp://192.168.43.1:8554/live` ✗ — `method DESCRIBE failed: 404 Stream Not Found` (alternate path doesn't exist on this firmware).
  - `ffplay -rtsp_transport tcp rtsp://192.168.43.1:8554/live` ✗ — same 404.
  - Verbose-log capture at `/tmp/ffplay_rtsp_2026-05-11.log` (decoded video frames + SDP archived).
- **Side-finding: Ubuntu Noble apt VLC is not a viable generic RTSP tool on this workstation.** Initial attempts `vlc rtsp://192.168.43.1:8554/fpv_stream` and `.../live` both failed with `satip stream error: Failed to play RTSP session` and `access_realrtsp stream warning: only real/helix rtsp servers supported for now`. Build config near the top of the verbose VLC log contains `'--enable-realrtsp' '--disable-live555'` — Ubuntu's apt VLC package on this workstation lacks the standard `live555` RTSP access module that mainline VLC uses for IP-camera RTSP. `ffmpeg`/`ffplay`, snap-VLC, or flatpak-VLC are working alternatives. `wiki/Common_Issues.md` Diagnosis step 2 updated to reflect this workstation/build-specific caveat (not a categorical statement about VLC).

Herelink video-sharing settings: not toggled today (didn't need to — QGC already working out of the box on the preset). Time on-station: roughly 1.5 hours including the install rounds (`vlc` then `ffmpeg`) and the second offline-window cycle to swap in `ffplay`.

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
| D2 | B-site video fails identically in `ffplay` | Location-side issue; deeper investigation needed (RF, range, link saturation) |
| D3 | B-site `ffplay` works but QGC fails | QGC config drift between sessions; document |

**Outcome.** **Second-site retest deferred.** Strictly speaking, the A/B comparison is not complete until a second site (e.g. the small artificial lake from 07/05, or any other location with different RF / link conditions) re-verifies the now-known-good QGC `Herelink Hotspot` preset under identical equipment + settings + connection mode. Today's campus result reduces the open hypothesis space for 07/05's QGC failure (the cause class is "QGC video Source setting / network topology / site link condition", not "Herelink-side default-off video sharing") but does NOT close it. Block D rolls into the next field session.

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
| RTSP tool result (`ffplay`) | | | |
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

**Outcome.** **07/05 lake video failure narrowed, not closed:**

- **QGC channel**: open cause class is still "QGC video Source setting / network topology / site link condition" — pending the deferred second-site retest in Block D. Today's campus result shows QGC + Herelink can deliver video on Linux when the `Source = Herelink Hotspot` preset is selected, which materially shrinks the hypothesis space but doesn't isolate the 07/05-specific variable.
- **MP channel**: likely the same MP-Linux runtime class surfacing then (`libSkiaSharp` native library load failure), not a Herelink-side issue at all. The 07/05 MP error screen was not captured at the time, so this remains a probable rather than confirmed mapping.

**Fix path**: laptop-side situational awareness for autonomy field tests should rely on **Linux QGC with `Source = Herelink Hotspot`** preset (known-good baseline, config dir backed up at `~/qgc_config_2026-05-11_campus.bak/`, screenshot at `~/Pictures/Screenshots/qgc_video_settings_2026-05-11_campus.png`). **Mission Planner on Linux** is treated as arm/disarm-only — degraded video, same posture as the 24/04 GDAL decision; MP-Windows (`.msi`) is the serious-MP fallback. **Doc updates landed**: new `wiki/Common_Issues.md` entry "Mission Planner on Linux: libSkiaSharp DllNotFoundException" + edits to the existing "Video Missing" entry (11/05 verification paragraph, `ffplay` swap-in for the apt-VLC-broken case in Diagnosis step 2-4, "Do not chase first" wording, new Diagnosis step 5 on preserving QGC config + capturing the underlying URL during the offline window). `Board.md` Phase 5 Hardware-arrival row for the video A/B retest flipped ⬜ → 🟡 with today's campus partial-pass note; new Timeline row for 11/05; header `Last Updated` + status summary + footer `Document Version` (9.9 → 9.10) + footer `Last Updated` all bumped to 11/05/2026.

---

## Block F — Day wrap (~30 min, evening)

Same shape as Thu 07/05:

1. `git log --oneline -10` — sanity check today's commits.
2. Pre-commit invisibility sweep — expect 0 matches.
3. Add 11/05/2026 Board.md milestone row(s) for whatever lands; bump the
   header `**Last Updated**` row + the bottom `**Document Version** ... **Last Updated**`
   trailer stamp to 11/05/2026 if anything substantive lands. **Use search
   rather than relying on line numbers** — both rows drift as Board.md grows.
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
8. **Update Week 10 external diary Mon section Outcome bullet** — the
   external Windows-side weekly diary (`Week10_11_05-15_05.md`, located in
   the user's research-intern folder on the Windows laptop, **outside** the
   uvautoboat repo and **not relative** to it) was scaffolded ahead of today's
   resume. Fill the Mon `[fill]` placeholder with what actually landed
   (A/B retest result, Pi 5 connectivity status, weekend inputs, VRX §8.2
   re-eval result, fallback work if any). Bilingual EN + 中文 — the Outcome
   bullet has both. **If the external path isn't reachable from this Linux
   session, defer to the next Windows-side session** — the task does not
   block the Mon main-repo wrap, but the external entry stays in "[fill]"
   until done.

**Outcome.** `wiki/Common_Issues.md` + `Board.md` + this diary all updated. Pre-commit invisibility sweep clean. Single-line conventional commit message: `docs: log 11/05 Herelink video A/B campus pass + MP-Linux skia gap` (66 chars). External Week 10 diary Mon-section update deferred to next Windows-side session per scaffold's hard rule. Pi 5 Side activity carry-forward note added to the deferred list — the `launch/remap.launch.yaml` no-regression discovery phase stays in its original state pending a focused next session with Pi 5 IP / SSH user / ROS 2 install state clarified.

---

## Block G — Post-commit MP-Linux SkiaSharp + libdl fix (host-local workaround, ~1.5 h after Block F commit)

Returned to the MP-Linux degraded posture from Block C / E after the Block F
commit landed. Question: is there a reversible host-local fix?

**Investigation**:

- Probed `~/MissionPlanner/` install: `libSkiaSharp.so` IS bundled at
  `x64/libSkiaSharp.so` (10.1 MB, 11/09/2020, ELF x86_64, stripped). But
  `ldd` revealed it's a **musl-libc** build: `libc.musl-x86_64.so.1 => not found`.
  Mono can't load it on Ubuntu (glibc), regardless of search path.
- Bundled `SkiaSharp.dll` managed-assembly version: **2.88.8.0** — that's
  the ABI the .NET bytecode is bound against. Initially considered 2.80.x
  based on `strings` output showing `libSkiaSharp.so.80.0.0` SONAME, but
  the SONAME milestone identifier ≠ SkiaSharp managed-binding version. The
  `.dll` assembly metadata is the authoritative source for the right NuGet
  version to swap in.

**Fix applied (host-local, reversible, no sudo)**:

1. Downloaded `SkiaSharp.NativeAssets.Linux` **2.88.8** from NuGet
   (`https://www.nuget.org/api/v2/package/SkiaSharp.NativeAssets.Linux/2.88.8`,
   15.6 MB `.nupkg` → 9.24 MB extracted `.so`).
2. Verified the extracted `runtimes/linux-x64/native/libSkiaSharp.so` is
   ELF x86_64 glibc-linked (`ldd` shows `libc.so.6`, `libfontconfig.so.1`,
   `libfreetype.so.6`, all on this workstation; no unmet deps).
3. Idempotent backup of the broken bundle to
   `~/MissionPlanner/x64/libSkiaSharp.so.musl.bak`, then installed the new
   `.so` at both `~/MissionPlanner/x64/libSkiaSharp.so` and
   `~/MissionPlanner/libSkiaSharp.so` (Mono's two search candidates).
4. First MP launch attempt with just the SkiaSharp swap surfaced a **new**
   error: `DllNotFoundException: libdl.so`. Ubuntu Noble doesn't ship the
   unversioned `/lib/x86_64-linux-gnu/libdl.so` symlink in the default lib
   path — only `libdl.so.2`. `libc6-dev` is already installed but only
   provides `libdl.a` (static lib), not the runtime symlink.
5. Created a local symlink: `ln -sf /lib/x86_64-linux-gnu/libdl.so.2 ~/MissionPlanner/libdl.so`
   (host-local, no sudo, no system change).
6. Second MP launch: clean — `libdl.so` error gone, SkiaSharp init
   completed. MP progressed all the way through HUD render, map tile
   downloading, airport DB load, plugin loading. **MP-Linux video panel
   verified working; arm/disarm also verified working** at the campus
   working room.

**Shutdown behaviour verified clean**: MP responded to SIGTERM with a
proper graceful shutdown (`MainV2_FormClosing → Saving config →
MainV2_FormClosed → mainv2_Dispose`, plus `stop GStreamer` for the video
pipeline). The `.tlog` at
`~/.local/share/Mission Planner/logs/2026-05-11 14-56-05.tlog` (850 KB) is
the first **post-fix** MP-Linux video + MAVLink validation sample on this
workstation (older pre-fix logs already exist as the no-video baseline).
Keep as a comparison baseline for any future MP-Linux session.

**Out of scope (not chased)**: the 24/04/2026 GDAL/OGR/OSR
`DllNotFoundException` errors still appear in MP's log (they're the next
Mono native-lib gap), but they don't block the video panel — terrain /
advanced geo-ref features remain degraded as documented 24/04, which
doesn't matter for routine field-test telemetry use.

**Notes on additional log entries (not regressions)**:

- MP is configured to accept UDP GStreamer video endpoints on `5000` /
  `5100` / `5600` (H.264) + `5601` (H.265) per AutoConnect config —
  `udpsrc ! decodebin3 ! videoconvert ! appsink` pipelines. The exact
  endpoint used by the successful stream was not packet-captured, so the
  specific UDP port the Herelink forwarded over is an open detail.
- `ERROR httpserver - Possible multiple instances of planner` — Step 4 MP
  (PID 38177) competing with my back-to-back libdl-test launch for the
  same internal http port. Self-induced concurrency from the diagnostic
  session, not a real issue.
- `AltitudeAngelWings.Plugin` failed to load — third-party Windows-deps
  plugin, cosmetic.
- `example23-switch.cs` plugin source had a Roslyn compile ambiguity
  (`error CS0121: The call is ambiguous between the following methods or
  properties: 'System.MemoryExtensions.AsSpan<T>(T[])' and
  'System.MemoryExtensions.AsSpan<T>(T[])'`) — sample-plugin source
  quirk, not a real plugin failure.
- `System.Runtime.InteropServices.MarshalDirectiveException` at
  `MissionPlanner.Utilities.NativeLibrary.dlerror()` — nonfatal
  Mono/PInvoke native-loader diagnostic warning, separate from the
  GDAL/OGR/OSR gap.

**Process-matcher pitfall encountered + corrected**: initial `pgrep -x mono`
checks returned empty during the smoke tests even while MP was alive
(verified via `ps -o etime -p <pid>` showing the process had been alive
~10 minutes when finally SIGTERMed), leading to a mis-report that MP had
exited. Switching to
`ps -eo pid,cmd | awk '/MissionPlanner\.exe/ && !/awk/'` reliably finds
the `mono MissionPlanner.exe` process. The `pgrep -x` mismatch likely
stems from a `comm` (15-char proc-name) vs. `cmdline` matching quirk on
this Mono build — recording here so the next person doesn't repeat the
misread.

**Verification artifact**: Herelink controller's Radio Status panel photo
at `~/Pictures/Camera/herelink_settings.png` captured during the test —
Paired link, Controller signal strength M: -69 dBm / S: -73 dBm, Air Unit
signal strength M: -74 dBm / S: -67 dBm, Uplink Rate 1395 kbps, Uplink
bandwidth 16926 kbps, Fly Distance 0 m. Healthy-link baseline for the
campus working-room setup; useful comparison baseline for the deferred
lake retest.

**Doc updates landed (Block G commit)**:

- `wiki/Common_Issues.md` MP-Linux entry's speculative "If a fix is needed
  later" section replaced with the working recipe + rollback +
  verification log details + caveats.
- `Board.md` status summary + Phase 5 Hardware-arrival row + Timeline row
  11/05 amended to reflect the fix.

**Caveats for future re-application**:

- Host-local workaround — re-apply after any MP reinstall (the install
  may overwrite `~/MissionPlanner/x64/libSkiaSharp.so`).
- The `.musl.bak` is the rollback artifact; don't delete it.
- Match SkiaSharp NuGet version to `SkiaSharp.dll`'s managed-assembly
  version after any MP update.

**Updated framing**: the original Block F outcome's framing ("MP-Linux is
treated as arm/disarm-only — degraded video, same posture as the 24/04
GDAL decision") is now superseded for video specifically — Linux MP is a
viable video tool on this workstation. The 24/04 GDAL decision still
holds for map terrain / advanced geo-ref features. MP-Windows (`.msi`)
remains the serious-MP fallback for the full feature surface.

---

## Verification summary — 11/05 (check at end of day)

- [x] Block A: morning re-orientation done; A/B retest go/no-go decided (GO, campus-only; second-site/lake retest pre-decided as deferred)
- [ ] Side activity (Pi 5 connectivity): **deferred** to next focused session — single-WiFi-adapter offline-switch workflow drafted but not executed; Pi 5 IP on `IoT IMT Nord Europe` + SSH user + ROS 2 install state with `ROS_DOMAIN_ID=56` match still TBD
- [x] Block B: equipment + settings handled implicitly at session start (no formal fill-in form under time pressure, consistent with Thu 07/05 Block B)
- [x] Block C: campus A test executed; outcome = A1 with MP-Linux split out (Linux QGC + `ffplay` both work via QGC `Source = Herelink Hotspot` preset on `rtsp://192.168.43.1:8554/fpv_stream`; Linux MP fails on `libSkiaSharp DllNotFoundException`)
- [x] Block D: second-site retest explicitly deferred to next field session — A/B comparison not yet complete without a second-site re-verification of the now-known-good QGC preset
- [x] Block E: A/B analysis complete; 07/05 root cause narrowed (QGC channel: "config / topology / site link condition" still open pending Block D; MP channel: likely the same MP-Linux runtime class); fix path documented (QGC = Linux video tool of record; MP-Linux = arm/disarm-only)
- [x] Block F: diary filled; pre-commit sweep clean; `Board.md` updated; `wiki/Common_Issues.md` resolved-branch updated + new MP-Linux SkiaSharp entry appended
- [x] Block G (post-commit addendum): MP-Linux SkiaSharp + libdl host-local fix landed; MP video panel + arm/disarm verified working; `wiki/Common_Issues.md` MP-Linux entry's "If a fix is needed later" section replaced with the working recipe + rollback + verification log details; `Board.md` status summary + Phase 5 row + Timeline row 11/05 amended

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
- **Real no-regression test for `launch/remap.launch.yaml`** — discovery phase scheduled as today's Side activity (Pi 5 connectivity + topic ground-truth capture + sim diff). **Conditional update at end of day:** if the Side activity completes (Pi 5 nodes/topics visible from workstation + ground-truth archive landed + sim-vs-Pi5 diff captured), mark the discovery phase as covered and only the patch session itself remains deferred to a focused future window once mismatches are catalogued. If the Side activity is blocked or skipped, this item stays in its original "needs first real-hardware bench" state — re-evaluate at the next test window.
- Sim-to-real comparison — was conditional on a 07/05 rosbag; none recorded,
  so this is N/A until a future field test records autonomy bag data.
- External Week 9 diary Thu 07/05 "Outcome:" line — bilingual EN + 中文,
  Windows-side; deferred to next Windows session.
