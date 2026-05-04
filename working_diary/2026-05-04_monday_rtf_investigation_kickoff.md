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

**Outcome.** PASS.

- Launcher reported `Total launch time: 43 s` — matches the 30/04 fresh-boot reading exactly.
- `/tmp/autoboat_launcher_probe.log`: 99 bytes, **0** `BrokenPipeError` matches.
- All 5 expected nodes up: `/heading_controller_node`, `/lidar_perception_node`, `/waypoint_planner_node`, `/waypoint_visualizer_node`, `/health_check_service`.
- No new today-dated `/var/crash/_opt_ros_jazzy*.crash` (only the pre-fix 29/04 `_opt_ros_jazzy_bin_ros2.1002.crash` from 29/04 10:23, untouched).
- No Apport popup; launcher session log clean through the success header.

SIGPIPE fix (`62636e9`) + readiness gates (`2c0194a`) hold across the Labour Day weekend.

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

**Outcome.** PASS — with a recipe caveat worth recording for future verifications.

- **Step 1 (silent under normal mission):** `autoboat_cli generate / confirm / start` ran clean; 30 s wait; `Mission status parse error` count in `/tmp/autoboat_tab_navigation.log` = **0**. `📍 Received 15 waypoints` info log fired twice (once on the initial CLI publish, once on confirm — both expected from `waypoints_callback_modular`). Visualizer nominal.
- **Step 2 (force the failure path):** the playbook's `ros2 topic pub --once /planning/mission_status ...` recipe **did not fire the warn** — `topic info -v` shows three subs (rosbridge_websocket BEST_EFFORT, heading_controller_node RELIABLE, waypoint_visualizer_node RELIABLE). With `--once`, `ros2 topic pub` blocks for the *first* matching subscription (the BEST_EFFORT rosbridge sub matches near-instantly), publishes one message, then exits — the visualizer's RELIABLE sub is still in DDS discovery when the publisher tears down, so the message never lands.
- **Workaround (used today):** `ros2 topic pub --rate 2 --times 5 ...` fans 5 publishes over 2.5 s. Early publishes can be lost in discovery; later publishes arrive after the visualizer sub is fully matched, and the warn fires:

  ```text
  [WARN] [waypoint_visualizer_node]: Mission status parse error: Expecting value: line 1 column 1 (char 0)
  ```

  Got 2 warn lines from 5 publishes — consistent with discovery latency. The fix itself works (source `plan/plan/waypoint_visualizer.py:99-100` `except json.JSONDecodeError → warn`). The Block B recipe in the playbook should switch to the multi-shot form for repeatable verification — `--once` is unreliable for late-discovering subs on a freshly-published topic.

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

**Outcome.** PASS.

- `scripts/sync_wiki.sh "Sync 30/04 + 03/05 doc-audit fixes"` first-run on this laptop: cloned `../uvautoboat.wiki/`, pulled (already up-to-date), copied `wiki/*.md`, no diff → "No wiki changes to sync." The GitHub Action picked up the weekend pushes.
- Wiki repo tip: `46c9b39 Sync wiki from main repo @ f00d2338` — that's the 30/04 doc-audit commit, end-of-week marker.
- Local-side spot-check (browser-side check skipped — `gh` not installed on this workstation):
  - `wiki/Dashboard_Security.md:68` carries the finding-#5 reframe ("Unauthenticated commands within validated bounds (operational risk)"); `:96` + `:133` + `:142` mark SRI + server-side bounds as already done; SRI reframed as CDN-availability risk.
  - `wiki/README_WIKI.md:19` lists `Roadmap.md`, `:22` lists `Pi5_Bringup_Smoke_Test.md`, `:32` flags `UPLOAD_INSTRUCTIONS.md` as the only excluded file (called out in both `scripts/sync_wiki.sh` `EXCLUDE_FILE` and the GitHub Action `rm -f` step).
  - `wiki/Roadmap.md:186` shows the §3 Phase 5 row "Dashboard offline-capable for IoT-local network deployment ❌"; `:516` revision-log entry documents the 30/04 IoT-local analysis.
- `diff <(ls wiki/*.md without UPLOAD_INSTRUCTIONS) <(ls ../uvautoboat.wiki/*.md)` → empty. Local wiki source = published wiki content.

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

**Outcome.** Root cause identified, fix verified end-to-end, documentation landed.

### Hardware ID correction up-front

`nvidia-smi` reports **NVIDIA RTX A3000 Laptop GPU, driver 580.142** — the A3000, not the A2000 the 29/04 diary entry and Sunday's Context section above carried forward. Both Ampere; same 5xx driver line so the working-hypothesis structure didn't shift, but the PCI ID `10de:24b8` claim (A2000-specific) was wrong. Sunday's Context block stays as historical record of the original hypothesis; this Outcome is the corrected reality.

### D1 — baseline (Mesa Intel UHD active, default `prime-select on-demand`)

| Metric | Reading | Window | Notes |
|:--|:-:|:-:|:--|
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | **2.48 Hz** | 73 samples / 30 s, std dev 0.18 s | 25 % of nominal 10 Hz |
| `/clock` | **80.9 Hz** | 2414 samples / 30 s, std dev 0.023 s | RTF **0.32** (`/clock` Hz / 250) |

LiDAR throttle (25 %) is *worse* than the overall RTF ratio (32 %) — flag for the GPU-bound `gpu_ray` raycasting being the dominant factor (the LiDAR shader runs on whatever GL provider Gazebo renders into).

### D2 — Branch 2 confirmed (Mesa active despite NVIDIA driver loaded)

```text
OpenGL vendor:   Intel
OpenGL renderer: Mesa Intel(R) UHD Graphics (TGL GT1)
OpenGL version:  4.6 (Compatibility Profile) Mesa 25.2.8-0ubuntu0.24.04.1
prime-select:    on-demand
nvidia-smi pmon: only Xorg using GPU 0 — no Gazebo entry
```

The 29/04 hypothesis ("libEGL DRI2 fallback") was wrong on mechanism. The NVIDIA driver loads cleanly (`lsmod | grep ^nvidia` shows all four modules; libEGL providers in `ldconfig -p` include `libnvidia-eglcore.so.580.142`). What's actually happening: `prime-select on-demand` is Ubuntu's default, which means apps run on the iGPU unless they request offload. The launcher doesn't request offload, so Gazebo lands on the Intel UHD Graphics (TGL GT1) — adequate for desktop compositing, badly outmatched by VRX's `gpu_ray` LiDAR + scene rendering. The "wrong GL provider" framing was right; the libEGL-DRI2-fallback specifics were noise.

Pre-flight env check (no sim disruption): `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo` flips vendor/renderer to **NVIDIA RTX A3000 Laptop GPU/PCIe/SSE2, OpenGL 4.6.0 NVIDIA 580.142, direct rendering: Yes** — confirmed the env-override path works before disturbing anything.

### D2 — fix verified

Two A/B tests, both with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` prefix.

| Configuration | `/points` Hz | `/clock` Hz | RTF | Verification |
|:--|:-:|:-:|:-:|:--|
| Standalone `ros2 launch vrx_gz competition.launch.py` | 8.95 | 195.9 | **0.78** | `nvidia-smi pmon`: `gz sim server` (PID 34435, SM 26 %) + `gz sim gui` on GPU 0 |
| Full `bash one_click_launch_all/launch_autoboat_complete.sh` | 6.8 | 219.7 | **0.88** | `pmon`: `gz sim server` + `gz sim gui` + `rviz2` all on GPU 0; launch time 44 s |

Headline numbers vs the Mesa baseline: **2.7× full-launcher LiDAR rate, 3.6× standalone LiDAR rate, 2.4–2.7× RTF.** The full-launcher reading is *higher* on `/clock` than the standalone (220 Hz vs 196 Hz) — a touch counter-intuitive but explained by the navigation stack pinning the simulation through the WAM-V controllers (Gazebo doesn't idle as much when there's a consumer holding a stable subscription). LiDAR is slightly lower in the full run (6.8 vs 8.95) likely because RViz2 + rosbridge_websocket are also drawing from the same GPU; not a regression worth chasing.

Critically, the env vars **propagate cleanly through the launcher's `gnome-terminal --tab -- bash -i -c "..."` chain.** No launcher edits required for the prefix invocation to work — the parent's env is inherited through gnome-terminal-server → the spawned bash → `bash -i` (`.bashrc` doesn't unset these vars on this user) → `ros2 launch vrx_gz`. Gazebo Harmonic picks them up and routes rendering through `libGLX_nvidia.so`.

### D3 — secondary factor identified, not yet tested

CPU governor on **all 16 cores** is `powersave`; available governors are `performance powersave`. The orientation's D3 branch and standard practice both put this as the next-largest contributor after the GL provider. Switching needs sudo:

```bash
sudo cpupower frequency-set -g performance
```

The `!`-prefix shell can't prompt for the password — this one belongs in the user's real terminal. Estimated additional ≈ 10–15 % RTF on top of today's 0.88. Reverts on reboot unless persisted. Deferred for the user to run when convenient (recommended next session start).

Thermal snapshot during the NVIDIA full run: `x86_pkg_temp 79 °C`, `TCPU 77 °C`, `TVGA 56 °C`. Well below the Tiger Lake throttle ceiling (~95 °C package), so no thermal headroom concern from the governor change.

### D4 — documentation landed

- `wiki/Common_Issues.md` — "Gazebo Running Slow" section rewritten with diagnostic flow, hybrid-graphics-laptop-only caveat (Pi 5 unaffected), and the measured A/B numbers above. Three numbered subsections: (1) GL provider check + prime-offload fix, (2) CPU governor, (3) other fallbacks (close apps / sensor resolution / headless / accept-and-multiply).
- This diary's Block D outcome.
- Board.md milestone row (Block E).

### Open question for the maintainer

Should `one_click_launch_all/launch_autoboat_complete.sh` bake the prime-offload env vars in by default? The trade-off:

- **For (auto-set):** hands-free dev experience on the laptop; one less thing to forget; matches what every laptop run actually wants.
- **Against (auto-set):** forces NVIDIA on hosts that don't have a discrete GPU (Pi 5 in Phase 5 — though `__NV_PRIME_RENDER_OFFLOAD=1` is harmless there since libnvidia isn't installed; the env vars become inert). Less surprising for new hires reading the script.
- **Compromise:** add a `--use-nvidia` flag (or auto-detect via `command -v nvidia-smi`) that exports the vars; document it in the launcher header and the wiki. Cleaner than forcing.

This is a code change to a `.sh` file — flagged here, deferred to the maintainer's call. For now the recommended invocation is documented in `wiki/Common_Issues.md`.

### Pitfall caught mid-investigation (worth carrying forward)

`pkill -9 -f <pattern>` from any shell whose own argv contains a `<pattern>` substring will **SIGKILL itself** — pkill scans system-wide and matches its own caller. The launcher's `cleanup()` function pkills 14 patterns including `gz sim`, `rosbridge_websocket`, `lidar_perception`, `waypoint_planner`, `heading_controller`, `waypoint_visualizer`, `health_check_service`, `web_video_server`, `autoboat.launch.yaml`, `web_dashboard/autoboat`, `rviz`, `http.server 8002`, `gzserver`, `gzclient`. Any verification script that puts those literal strings in echo lines / case patterns / pgrep arguments gets killed the moment the launcher's trap fires, OR the moment the script itself runs one of those pkills — same self-kill on either side.

**Workaround used today (after burning three Bash calls to it):** keep pattern-bearing operations inside a separate script file (`bash /tmp/foo.sh` — outer caller's cmdline is just the path, no patterns visible to pkill). The script file's content is read from disk, not argv, so pkill can't see it. Saved as `/tmp/kill_sim.sh` + `/tmp/relaunch_full.sh` for the rest of the day.

Worth a `wiki/Common_Issues.md` follow-up if this trap recurs in future investigations — for now logged here as a session lesson.

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

**Outcome.**

- Pre-commit invisibility sweep clean — `grep -rnIEi '(claude|anthropic|...)' --include='*.md' ...` against the full keyword set + 10 file types returned rc=1 (zero matches). Repo stays invisibility-clean.
- Stale-doc audit on what Block D touched: cross-ref scan for "Gazebo Running Slow", "prime-select", "prime-offload", `__NV_PRIME_RENDER_OFFLOAD`, `__GLX_VENDOR` across all `*.md` / `*.py` / `*.sh` etc. surfaced 14 references — all current (today's edits + the 28/04 unrelated `### Known Startup Warnings (Cosmetic)` subsection of `Common_Issues.md`) or historical-immutable (29/04 + 30/04 working diary entries referencing the original A2000 hypothesis + `__GLX_VENDOR_LIBRARY_NAME=nvidia` recipe). The historical entries stay as-is; today's Block D outcome corrects forward, not back. No stale claims to fix.
- Three files modified today, all markdown: `Board.md` (milestone rows + Last-Updated bump), `wiki/Common_Issues.md` ("Gazebo Running Slow" rewrite), `working_diary/2026-05-04_*.md` (Block A-E outcomes + Known Unknowns).
- External `Research_intern_IMT_NE/working_diary/Week9_04_05-08_05.md` Mon "Outcome:" update **deferred to next Windows-laptop session** — the external diary folder lives on the Windows side per the machine-split work pattern; not accessible from this Linux workstation. The 30/04 Block G scaffold for Week 9 already landed Sunday so no fresh scaffold is needed, just the Mon outcome paragraph.
- `git log --oneline -10` sanity: last commit `f9b135c docs(diary): reword 04/05 backfill bullets for clarity` (Sunday push), today's commit pending. No surprises.

Suggested commit subject (≤72 chars, conventional commits):

```text
docs: log 04/05 RTF investigation — prime-offload fixes Gazebo throttle
```

Body (multi-paragraph not requested; one-liner is the default per house style — happy to expand on request).

The full launcher run with `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia` prefix was **left alive in the background at wrap time** (started ~09:53, success header at +44 s), useful for any visual dashboard checks before pushing. Follow-up check found the recorded `gz sim server` PID `38911` no longer present, so treat the sim as already stopped unless a fresh `pgrep -af 'gz sim'` says otherwise. Tear-down recipe when needed: `bash /tmp/kill_sim.sh` (the pattern-isolated cleanup script saved during today's pkill self-kill workaround), then verify ports 8002 / 8080 / 9090 vacant via `ss -tlnp`.

---

## Verification summary — 04/05 (check at end of day)

- [x] Block A: cold-boot regression pass; SIGPIPE fix + readiness gates hold (43 s launch, 0 BrokenPipeError, 5 nodes)
- [x] Block B: visualizer warn fires on bad JSON, silent under normal operation (with `--rate 2 --times 5` workaround for the `--once` discovery race)
- [x] Block C: wiki sync propagated; local wiki/ matches published wiki (Action handled the 30/04 push; tip `46c9b39 @ f00d2338`)
- [x] Block D: RTF root cause identified + fixed end-to-end. Mesa Intel UHD → NVIDIA RTX A3000 via prime-offload env vars; RTF 0.32 → 0.88, LiDAR 2.48 → 6.8 Hz on the full launcher
- [x] Block E: Board.md row added; diary filled; pre-commit grep clean
- [ ] External Week 9 diary Mon "Outcome:" line — *deferred to next Windows session (path lives on the Windows laptop, not this workstation)*

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

- `nvidia-smi` → **RTX A3000 Laptop GPU, driver 580.142**, *not* the A2000 the 29/04 entry + this scaffold's L9 + L133 carried forward. Hypothesis structure unchanged (both Ampere, same driver line), but the PCI-ID claim `10de:24b8` is wrong. Captured inline in Block D outcome; not back-edited into the Sunday Context block (preserves the original-hypothesis history).
- `ros2 topic pub --once` is a **brittle verification tool** when the target topic has both BEST_EFFORT and RELIABLE subscribers — it waits only for the first matching sub, publishes once, and exits before the slower-discovering RELIABLE subs land. Block B's playbook recipe needs the multi-shot form (`--rate N --times M`) for repeatability. Worth a `wiki/Common_Issues.md` debug-commands note if this trap recurs.
- `pkill -9 -f <pattern>` from any shell whose argv contains `<pattern>` substrings will SIGKILL itself. The launcher's `cleanup()` pkills 14 patterns; ANY verification script with those literal strings in echo lines, case patterns, or pgrep arguments is a self-kill. Workaround: keep pattern-bearing operations inside a separate script file (`bash /tmp/foo.sh` — outer caller cmdline is just the path). Documented in Block D outcome; possibly worth promoting to `wiki/Common_Issues.md` if it bites a future investigation.
- Standalone `ros2 launch vrx_gz` in a freshly-cleaned graph shows `/wamv/sensors/lidars/lidar_wamv_sensor/points` advertised within ~0 s on the warm-cache second start of the day — the cold-boot 60 s wait_for_topic budget in the launcher is correct, but warm runs land near-instant. No action; just useful prior for any later launcher tuning.
- Old launcher's `trap cleanup INT TERM` runs the cleanup function but **doesn't `exit`** afterwards — control returns to the `while true; do sleep 6; done` loop, so SIGINT alone leaves the launcher alive. SIGKILL on the launcher PID is the clean kill path, not SIGINT. Worth flagging as a launcher hygiene item the maintainer may want to address (`trap 'cleanup; exit 130' INT TERM`); deferred — code change in `.sh` file.

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
