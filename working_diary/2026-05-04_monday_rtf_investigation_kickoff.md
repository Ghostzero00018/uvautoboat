# 2026-05-04 — Monday: post-Labour-Day sanity + RTF investigation kickoff

## Context

Pre-scaffold written 03/05 evening (Sunday). First Linux-side work day after the Labour Day weekend (Fri 01/05 holiday + Sat/Sun off). Today picks up the **Gazebo RTF throttle investigation** deferred from the 29/04 cold-boot validation as the main work item; smaller sanity items run first to confirm the 30/04 weekend pushes still hold.

**Week shape recap:**

- **Mon 04/05 (today)** — post-holiday sanity (cold-boot regression + visualizer warn verification + wiki sync) → RTF investigation kickoff. Gazebo LiDAR `/points` runs ~2 Hz vs 10 Hz nominal; libEGL DRI2 fallback on NVIDIA RTX A2000 Laptop GPU is the working hypothesis from 29/04.
- **Tue 05/05 onwards** — depends on RTF root cause: either driver fix + back-to-baseline, or a deeper dive into Gazebo physics / render config / `<physics><real_time_update_rate>`.
- **Pending all week:** formal joint supervisor presentation (rescheduled per 30/04, date depends on IMT Mines Alès availability + power restoration); three Asks to teammate maintainer (Phase A parameter subset, CA placement, validation methodology) — answers may unblock the Phase A mock-sensor scope.

**Why today matters:**

The RTF throttle is a real performance ceiling — at ~20% RTF, every test runs 5× slower than nominal, every demo looks sluggish, and Phase 5 hardware-vs-sim comparisons become noisy. Downstream investigations (long-mission tests, P1 pier/bank stuck investigation, water-quality CA Phase A) all run on the degraded baseline until it's resolved. Worth one focused day to find and fix (or scope the workaround).

The pre-RTF sanity steps are cheap insurance that the weekend's pushes didn't break anything yesterday relied on.

Active blocks for the day:

1. **Block A — Cold-boot regression sanity** (~5 min, AM): confirm `62636e9` SIGPIPE fix + `2c0194a` readiness gates still hold across the weekend; all 5 nodes up, no Apport popup, zero `BrokenPipeError` in probe log.
2. **Block B — Visualizer JSON-parse warning verification** (~5 min, AM): confirm the 30/04 visualizer fix (`waypoint_visualizer.py` `mission_status_callback_modular` warns on bad JSON) actually fires when expected and stays silent under normal operation. Manual malformed-JSON injection.
3. **Block C — Wiki sync propagation check** (~2 min, AM): GitHub Action on push-to-main probably synced the 30/04 doc commits over the weekend; verify on the published wiki; run `scripts/sync_wiki.sh` if not.
4. **Block D — RTF investigation kickoff** (~rest of the day, AM-PM): the actual main work. First diagnostic `glxinfo | grep "OpenGL renderer"` + `ros2 topic hz /clock` to identify whether NVIDIA driver is actually active. Branch tree captured below.
5. **Block E — Day wrap** (~20 min, evening): fill diary outcomes; Board.md milestone row(s); commit + push; fill the Mon "Outcome:" line in the existing external Week 9 diary (the scaffold was already landed Sunday — see "Pre-Monday work" section below).

---

## Pre-Monday work landed Sunday 03/05 (committed + pushed before Monday opens)

Doc cleanup + invisibility hygiene + tomorrow's prep, all in `main` + Gist by the time the Monday session opens.

- **Dashboard_Security refresh** — server-side `PARAM_RANGES` validation now noted in the security posture; XSS finding retargeted from `/rosout` (already safe via `textContent`) to `addLog()` `innerHTML`; "Unauthenticated commands within validated bounds" reframe; SRI finding marked resolved + reframed as CDN-availability risk pointing at Roadmap §1.3.
- **README_WIKI restructure** — reclassified as synced wiki-meta page (matches actual sync — `UPLOAD_INSTRUCTIONS.md` is the only excluded file in both `scripts/sync_wiki.sh` and `.github/workflows/sync-wiki.yml`); inventory updated (`Roadmap.md` + `Pi5_Bringup_Smoke_Test.md` added); stale "Additional Pages Needed" wishlist removed (24 ghost pages including `Atlantis-Architecture.md`).
- **A\* diagram topic fix** in `USER_MANUAL.md` + `Board.md` — `/perception/obstacles` → `/perception/obstacle_info` (the actual published topic).
- **`waypoint_visualizer.py` JSON parse warning** — `mission_status_callback_modular` no longer silently swallows `JSONDecodeError`; now logs at WARN level (matches the sibling `waypoints_callback_modular` pattern). **Block B verifies this on Monday — only new code path from Sunday.**
- **Conventions doc (Gist) trim** — §6 swapped from project-state pinning → canonical-source pointers + 3 method bullets; §10 collapsed to a one-line pointer; §12 smoke test reduced to method/behaviour-only (project-state questions deliberately removed); §1 / §2 / §5 / §11 wording aligned to the new method-only shape; static "Last updated" stamp removed.
- **Pre-commit sweep extended** — keyword set widened, `*.svg` added to the `--include` list, caveat added noting that base64-embedded raster blobs inside SVG slip past textual grep unless decoded.
- **Image-asset cleanup** — `images/logo_autoboat_v2.svg` (SVG-embedded PNG simplified by removing non-essential ancillary chunks; ~73 KB smaller; logo renders unchanged) and `images/LogoBase.png` (same chunk simplification on this orphan source PNG; ~55 KB smaller). Both PNGs preserve the critical chunks (IHDR / IDAT / IEND).
- **Diary prose reword** — `working_diary/2026-04-30_*.md` L483 reworded for clarity (rule's intent stated inline rather than via cross-reference).
- **External Week 9 diary scaffold** created at `Research_intern_IMT_NE/working_diary/Week9_04_05-08_05.md` — Mon 04/05 detailed (cross-links this file's Block A-E); Tue/Wed/Thu blank pending Mon outcome; Fri 08/05 noted as V-E Day public holiday.
- **Tomorrow's Linux-side test plan + this scaffold** drafted Sunday evening — Block A-E breakdown + branch trees + pass criteria + rollover conditions.

**Implication for Monday:** the only new code path landed Sunday is the visualizer JSON warn (Block B verifies). Everything else is doc-only — no runtime test needed for those. Block D (RTF investigation) starts from the 29/04 working hypothesis — nothing landed Sunday on that front.

**Final main-repo §1.6 sweep result before Sunday push:** zero matches across the full keyword set + all included file types (text + binary). Repo is invisibility-clean entering Monday.

---

## Block A — Cold-boot regression sanity (~5 min, AM)

After fresh laptop reboot, before opening anything else:

```bash
cd ~/seal_ws/src/uvautoboat
git pull                                                # weekend's commits land
bash one_click_launch_all/launch_autoboat_complete.sh

# After "AutoBoat System Launched Successfully!" + "Total launch time: N s":
grep -c 'BrokenPipeError' /tmp/autoboat_launcher_probe.log     # expect: 0
ros2 node list | grep -E 'heading_controller|lidar_perception|waypoint_planner|waypoint_visualizer|health_check_service' | wc -l
# expect: 5
```

Pass criteria: all 5 nodes present, no `BrokenPipeError` in probe log, no Apport popup during launch.

If anything fails: capture `/tmp/autoboat_launcher_probe.log` + `/tmp/autoboat_tab_*.log` + any new `/var/crash/_opt_ros_jazzy*.crash`; defer fix; do NOT proceed to Block D until resolved (RTF investigation needs a working baseline).

**Outcome.** [To fill]

---

## Block B — Visualizer JSON-parse warning verification (~5 min, AM)

The 30/04 fix added a WARN log to `mission_status_callback_modular` so RViz no longer silently shows a stale current waypoint when malformed JSON arrives. Verify both directions: silent under normal operation, fires under malformed input.

### Step 1 — Normal operation (silent)

After the launcher is running (from Block A), watch the visualizer terminal tab. Run a short canonical mission for ~30 s:

```bash
ros2 run plan autoboat_cli generate
ros2 run plan autoboat_cli confirm
ros2 run plan autoboat_cli start
# Wait ~30 s, watch the visualizer tab.
```

Expect: `📍 Received N waypoints` info logs at waypoint capture; **NO** `Mission status parse error` warns.

### Step 2 — Force the failure path

```bash
ros2 topic pub --once /planning/mission_status std_msgs/String "data: 'this-is-not-json'"
```

Expect in the visualizer terminal:

```text
[WARN] [waypoint_visualizer_node]: Mission status parse error: Expecting value: line 1 column 1 (char 0)
```

Pass criteria: silent during normal mission, exactly one warn line per malformed publish.

If the warn doesn't fire: check that the visualizer is actually subscribed to `/planning/mission_status` (`ros2 topic info /planning/mission_status` → expect at least one subscriber including `/waypoint_visualizer_node`).

**Outcome.** [To fill]

---

## Block C — Wiki sync propagation check (~2 min, AM)

The GitHub Action `.github/workflows/sync-wiki.yml` runs on every push that touches `wiki/**`. Friday's commits (`82d79b5` and the bundled doc-audit commit) should already be synced by Monday morning.

```bash
cd ~/seal_ws/src/uvautoboat
scripts/sync_wiki.sh "Sync 30/04 doc-audit + bundled fixes"   # no-op exits cleanly if Action already pushed
```

Then visually verify on <https://github.com/Ghostzero00018/uvautoboat/wiki>:

- **Dashboard_Security**: finding #5 reframed ("Unauthenticated commands within validated bounds"); finding #8 marked resolved (SRI in place) and reframed as CDN-availability risk; mitigation table shows SRI + server-side bounds as `~~Already done~~`.
- **README_WIKI**: `Roadmap.md` + `Pi5_Bringup_Smoke_Test.md` in the synced inventory; `UPLOAD_INSTRUCTIONS.md` as the only excluded file; sync workflow describes both `scripts/sync_wiki.sh` AND the GitHub Action.
- **Roadmap**: §1.1 / §1.2 / §1.3 visible; §3 Phase 5 status table shows the Pi 5 bring-up + dashboard offline-capable rows.

If anything mismatches: re-run `scripts/sync_wiki.sh` manually; check the GitHub Action's run history for failures.

**Outcome.** [To fill]

---

## Block D — RTF investigation kickoff (rest of the day)

Deferred from 29/04 cold-boot validation. Working hypothesis from yesterday's diary: **libEGL DRI2 fallback on the NVIDIA RTX A2000 Laptop GPU** (PCI `10de:24b8`). Mesa probes legacy DRI2, fails, falls back to llvmpipe (software) or some other path; the `gpu_ray` LiDAR sensor and shader-coupled physics step throttle when the render pipeline isn't accelerated.

### D1 — Pre-flight measurement (capture the current state before changing anything)

```bash
# Confirm current LiDAR rate (should reproduce the ~2 Hz observation):
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points
# Let it sample for ~30 s. Expect ~2 Hz mean.

# Confirm current RTF via /clock (250 Hz nominal at 0.004 s timestep):
ros2 topic hz /clock
# Sampled rate / 250 = current RTF. Expect ~50-60 Hz (≈ 0.20-0.24 RTF).
```

Record numbers in this diary's Block D outcome.

### D2 — Identify the active GL provider

```bash
glxinfo | grep -E "OpenGL renderer|OpenGL vendor"
# sudo apt install mesa-utils    # if glxinfo missing
```

Three branches based on output:

#### Branch 1: NVIDIA active

```text
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA RTX A2000 Laptop GPU/PCIe/SSE2
```

If `/points` is still 2 Hz despite NVIDIA being active and fast, the bottleneck is NOT render. Move to **D3 (physics branch)**.

#### Branch 2: Mesa-active despite NVIDIA driver loaded

```text
OpenGL vendor string: Mesa  (or  Intel)
OpenGL renderer string: Mesa Intel(R) Graphics ...  or similar
```

NVIDIA driver is installed but Mesa is the active provider — Gazebo is going through Mesa. Try forcing NVIDIA:

```bash
__GLX_VENDOR_LIBRARY_NAME=nvidia ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_DEFAULT
# OR system-wide:
sudo prime-select nvidia
# (logout / login required after prime-select)
```

Re-measure with D1's commands. If `/points` jumps to ~10 Hz, root cause confirmed = wrong GL provider.

#### Branch 3: llvmpipe (software fallback)

```text
OpenGL renderer string: llvmpipe (LLVM 17.0.6, 256 bits)
```

NVIDIA driver isn't loading at all — software rendering. Check driver state:

```bash
nvidia-smi                                              # should show the RTX A2000
lsmod | grep nvidia                                     # nvidia modules should be loaded
ubuntu-drivers devices                                  # recommended driver
```

If `nvidia-smi` errors or the modules aren't loaded, install the matching `nvidia-driver-XXX` package (Ubuntu 24.04 typically `nvidia-driver-550` or `-555` for the RTX A2000):

```bash
sudo apt install nvidia-driver-550   # or whichever ubuntu-drivers recommends
sudo reboot
```

Re-measure with D1.

### D3 — Physics-bottleneck branch (only if NVIDIA active + fast and `/points` still 2 Hz)

The throttle is in the physics step itself, not render. Likely culprits:

- **CPU governor in `powersave` mode** — laptops default to powersave. Check:

  ```bash
  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
  # If 'powersave': switch to 'performance':
  sudo cpupower frequency-set -g performance
  ```

- **`<physics><real_time_update_rate>` set lower than 250** — check `vrx_gz` world SDF for the active competition world; default is 250 (matches the 0.004 s timestep). If lower, `/clock` runs slower → all sensor rates throttle proportionally.
- **Step solver iterations too high** — Gazebo's `<solver><iters>` defaults are conservative; raising them slows physics. Check the WAM-V SDF for any non-default `<solver>` settings.
- **Other CPU contention** — `htop` while sim runs; if a non-Gazebo process is at 100% CPU, that's the bottleneck.

### D4 — Document findings and decide

Whatever the root cause: capture in the diary, push a one-line `Board.md` row + a `wiki/Common_Issues.md` entry if the fix is operator-actionable (e.g., "set GL provider to NVIDIA for full RTF"). If the cause is hardware-environment-specific and not generally applicable, add to the diary only.

If unfixable in a day: document the workaround (e.g., "accept ~20% RTF; multiply all timing budgets by 5 for reasoning") and resume the deferred Phase 5 prep work the rest of the week.

**Outcome.** [To fill]

---

## Block E — Day wrap + Week 9 scaffold (~30 min, evening)

1. `git log --oneline -10` — sanity check today's commits.
2. Pre-commit grep — sweep for blocklist matches; expect 0.
3. Add 04/05 Board.md milestone row(s) for whatever lands (RTF root cause + fix or workaround; visualizer warn verified; cold-boot regression pass).
4. Fill the `[To fill]` placeholders throughout this file.
5. **Create `Week9_04_05-08_05.md` scaffold** in the external diary folder (`Research_intern_IMT_NE/working_diary/`) — carryover from 30/04 Block G. Skeleton: Mon-Fri days; lead item Mon = today's RTF outcome; rest of week depends on RTF resolution + supervisor presentation reschedule.
6. Commit:

   ```bash
   git add working_diary/2026-05-04_monday_rtf_investigation_kickoff.md Board.md
   # Plus any wiki/ or other files touched during Block D / E.
   git commit -m "docs: fill 04/05 working diary with RTF investigation outcomes"
   git push
   ```

**Outcome.** [To fill]

---

## Verification summary — 04/05 (check at end of day)

- [ ] Block A: cold-boot regression pass; SIGPIPE fix + readiness gates hold
- [ ] Block B: visualizer warn fires on bad JSON, silent under normal operation
- [ ] Block C: wiki sync propagated; published wiki shows 30/04 changes
- [ ] Block D: RTF root cause identified (or scoped as deferred); current rate measured + recorded
- [ ] Block E: Board.md row added; diary filled; Week 9 scaffold created in external folder
- [ ] Pre-commit grep clean

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Cold-boot baseline confirmed working | None — Block B/C/D depend on this; if A fails, defer everything else |
| Block B | Visualizer warn verified both directions | Low — non-blocking; defer to Tue if Block D needs the time |
| Block C | Wiki sync verified | Low — non-blocking; cosmetic |
| Block D | RTF root cause identified or scoped | Carryover into Tue if not finished — the actual root cause may need driver install + reboot, eating significant time |
| Block E | Day closed + Week 9 scaffold landed | Hard requirement — Week 9 needs the scaffold to start |

---

## Known unknowns surfaced during the day

Use this section to capture anything surprising — file state drift, unexpected behaviour, hardware quirks, supervisor-meeting reschedule confirmations. Each entry: `file:line` or command + observation + fix or follow-up.

---

## Next steps — Tue 05/05 onwards

### Conditional on Block D outcome

- **If RTF fix landed cleanly:** resume deferred work — long-mission tests, P1 pier/bank investigation, Phase A mock-sensor implementation (once teammate confirms parameter subset).
- **If RTF fix needed driver install + reboot:** Tue is the verification day — re-run D1 measurements; if still wrong, escalate to the physics-bottleneck branch.
- **If RTF deferred as "live with the workaround":** document the workaround prominently; resume deferred work.

### Pending all week

- **Formal joint supervisor presentation** — rescheduled per 30/04; date pending IMT Mines Alès availability + power restoration. Same deck + Asks; rehearsal artefacts intact.
- **Three Asks to teammate maintainer** (sent in writing after 30/04 scoping session): Phase A water-quality parameter subset; CA model compute placement (Linux vs Pi 5); validation methodology (same-day cross-validation vs day-gap return). Answers unblock Phase A scope + Phase E methodology lock.

### Other deferred (not actively scheduled)

- **P1 pier/bank stuck investigation** — diagnostic plan in `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A.
- **Mock water quality sensor implementation (Phase A)** — unblocked once supervisor confirms the parameter set.
- **Real no-regression test for `launch/remap.launch.yaml`** — needs first real-hardware bench (Pi 5).
- **C3 bench verification** — passive wait for real-hardware double-reverse symptom.
- **Dashboard ↔ MP/QGC integration** — Phase 5.2+ scope (post-real-hardware-bringup).
- **24/04 housekeeping carry-overs** — `mono-xsp4` port-8084 disable; `tools/qos_scan.py` single-pass QoS inventory companion to `rate_probe.py`.
- **Dashboard scaffold-without-write audit** — surfaced as a 29/04 Mission Progress architectural lesson; worth a focused audit pass at some point.
- **Dashboard offline-capable for IoT-local network deployment** (per Roadmap §1.3) — Path A vendor libs first, then Path B offline tile server before first on-water deployment.
