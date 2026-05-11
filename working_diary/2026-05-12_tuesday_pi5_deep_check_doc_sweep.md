# 2026-05-12 — Tuesday: Pi 5 deep check + MP/QGC residuals + doc sweep

## Context

Day after Mon 11/05 — key late-day commits now on `main` include:

- `15ead0e` Herelink video A/B campus side closed (QGC verified-good on
  `Source = Herelink Hotspot` preset + `ffplay rtsp://192.168.43.1:8554/fpv_stream`
  independently confirms underlying LIVE555 H.264 stream).
- `e5412ee` MP-Linux SkiaSharp + libdl host-local fix (musl→glibc swap from
  NuGet `SkiaSharp.NativeAssets.Linux` 2.88.8 + `~/MissionPlanner/libdl.so`
  symlink), making MP-Linux video panel + arm/disarm both work.
- `4c367ec` Wiki Roadmap pointer + Common_Issues residual-issues detailed
  reference for the 6 leftover MP-Linux log entries.
- `0779c40` MP/QGC update-procedures wiki page + QGC stable-channel notes.
- `155fd8c` Block H — Pi 5 Side activity executed (SSH + ED25519 key + ROS 2
  Jazzy install all verified on `IoT IMT Nord Europe` at `10.120.2.50`; DDS
  cross-machine discovery still **inconclusive** pending a long-running
  publisher probe).
- `7a92a9e` post-Block-H stale-claim cleanup (forward-update pointers
  added to superseded Outcome lines + Verification summary supersession note).
- `5457a90` Pi 5 domain-0 caveat closed (followup probe confirmed
  domain-0 = same bare-daemon state as domain 56) + Board.md verbosity tweak.

Repo synced. tmux installed mid-day yesterday. SSH key-auth from workstation
to Pi is durable.

**Lead item today:** the Pi 5 DDS cross-machine probe (the long-running
publisher recipe captured in Mon Block H). Yesterday's empty workstation
`ros2 node list` was **inconclusive** — no named Pi-side node was running
during the test, so the empty result couldn't disambiguate "no Pi nodes to
discover" from "DDS multicast blocked by IoT WiFi". Today's first move
should be a `ros2 topic pub` running on the Pi while the workstation
subscribes, to resolve the multicast question dispositively.

**Week shape recap:**

- **Mon 11/05** — Herelink video A/B campus close + MP-Linux SkiaSharp/libdl
  fix + Pi 5 SSH/ROS 2 install verified + audit cleanup. 6 commits.
- **Tue 12/05 (today)** — Pi 5 deep check (DDS probe + system-desktop GUI
  access PRIMARY; ROS 2 data viz SECONDARY); MP GDAL/OGR/OSR fix attempt
  (conditional); optional QGC update; doc stale-claim sweep.
- **Pending all week** — formal joint supervisor presentation reschedule;
  three Asks to teammate maintainer (Phase A parameter subset, CA placement,
  validation methodology); second-site (lake) Herelink video A/B retest.

**Carry-over from Mon Block F Step 8:** external Week 10 diary Mon Outcome
fill — check status, fill if still placeholder. Tue Outcome fill remains a
Block F / evening Windows-side task.

**Why this matters:**

Pi 5 DDS cross-machine discovery is the **gate** for the rest of Phase 5 —
if multicast works, Phase 5 driver bring-up on Pi can proceed using
standard ROS 2 graph discovery. If multicast is blocked, the next step is a
Fast-DDS Discovery Server (unicast) configuration, which is more work but
unblocks Phase 5 regardless. Yesterday's Block H left this open as the
single biggest Pi-side unknown.

The Pi 5 GUI trial is exploratory but timely. The **PRIMARY** question is
whether the Pi's system desktop / OS GUI can be operated remotely (VNC,
xrdp, or SSH-X for individual apps), because that is the operator's-eye
view of the Pi as a workstation. ROS 2 data visualization (`rviz2` /
Foxglove over Paths A/B/C) is **SECONDARY** and follows only after at least
one system-desktop path is attempted or skipped by the pre-req check.

MP GDAL/OGR/OSR and QGC update are scope-discipline catch-ups documented
yesterday as deferred. Today's check is whether either is worth chasing
right now.

Doc sweep is hygiene — yesterday's MP-Linux fix + Pi 5 Side activity
addendum landed across `Board.md` / `Roadmap.md` / `Common_Issues.md` /
diary; a forward audit catches anything that slipped, with extra attention
on `README.md` which hasn't been touched in the recent flurry.

Active blocks:

1. **Block A — Morning re-orientation** (~10 min, opening): catch up; verify
   yesterday's 6 commits on disk + push state; overnight inputs; VRX §8.2
   state-check (next scheduled cadence is Mon 18/05, not due today).
2. **Block B — Pi 5 deep check** (~45-60 min, single offline window on `IoT
   IMT Nord Europe`): two parts sharing one network switch:
   - **B.1** DDS cross-machine probe (long-running publisher).
   - **B.2** system-desktop GUI access trial (**PRIMARY**: VNC / xrdp /
     SSH-X; rPi Connect skipped today), then ROS 2 data visualization
     (**SECONDARY**: Paths A/B/C) only after PRIMARY is attempted or skipped.
3. **Block C — MP-Linux GDAL/OGR/OSR fix attempt** (~45-90 min, mid-PM,
   conditional): musl→glibc swap pattern from yesterday's SkiaSharp fix.
4. **Block D — QGC stable AppImage update** (~10 min, optional): check
   upstream cadence; update only if newer + wanted.
5. **Block E — Doc stale-claim sweep** (~30-45 min): forward-audit
   `Board.md`, `README.md`, `wiki/Roadmap.md`, `wiki/Common_Issues.md`,
   `wiki/MP_QGC_Update_Procedures.md`, plus README / wiki stamp sweep.
6. **Block F — Day wrap** (~30 min, evening): diary outcomes, Board.md
   update, commit + push.

**Hard boundary:** Pi 5 remains **bare ROS 2** today unless Block B proves
otherwise; no autonomy-stack or real driver-service expectations from the
Pi side yet.

**Fallback if Pi 5 hardware isn't reachable** (e.g., Pi powered off, IoT
network down, hotspot connectivity broken):

- Skip Block B entirely; jump to Block C (MP-Linux work is fully
  workstation-side, no Pi involvement).
- Block D (QGC update) is internet-only — also Pi-independent.
- Block E (doc sweep) is local-only — also Pi-independent.
- Net: lose ~50% of today's planned work but Blocks C / D / E can still
  progress.

---

## Block A — Morning re-orientation (~10 min, opening)

After Mon's heavy 6-commit session, catch up before starting today's blocks:

- `git log --oneline -10` + `git status` — verify Mon's 6 commits on disk +
  branch synced with `origin/main`.
- Re-read Mon 11/05 diary Block G + Block H + the Block H "Updated framing"
  block — the Pi 5 baseline (`imtaqua-pi-01`, Ubuntu 24.04.4 aarch64, ROS 2
  Jazzy at `/opt/ros/jazzy/`, bare daemon under both `ROS_DOMAIN_ID=0` and
  `=56`) is the critical context for today's Block B.
- **Forward-update on Mon Side activity Outcome §1.3 caveat (L146):** Mon
  claimed `IoT IMT Nord Europe` was "different network meaning in user's
  setup" from `wiki/Roadmap.md` §1.3 and queued §1.3 wording for re-check —
  that was a misreading. Per user clarification: the SSID `IoT IMT Nord
  Europe` **is the same network** §1.3 describes; §1.3's local-only / no-
  internet analysis applies directly to the workstation↔Pi link. No §1.3
  wording change needed. Block E.3 below has been updated to reflect this
  resolution. Mon diary left as-is per append-only convention; this bullet
  is the forward-update pointer.
- Check overnight inputs (supervisor / teammate replies, weather,
  presentation reschedule). If email / Slack aren't reachable from this
  Agent context, ask the user.
- **VRX §8.2 weekly cadence** — next scheduled check is Mon 18/05 per the
  Mon 11/05 schedule, so NOT due today. Just verify nothing has changed
  unexpectedly:

  ```bash
  cd ~/seal_ws/src/vrx
  git status --short
  git pull --ff-only
  git branch --show-current                                  # expect autoboat/main
  git log autoboat/main --not upstream/main --oneline | wc -l   # expect 1 (the existing bake-in)
  git tag --sort=-creatordate -l 'v*' | head -3                  # expect v3.1.2 still at top
  ```

- Confirm Pi 5 is reachable (powered on, on IoT network) before committing
  to Block B; otherwise jump to fallback path.

**Outcome.** [To fill — git state, overnight inputs, Pi 5 reachability,
decision branch.]

---

## Block B — Pi 5 deep check (~45-60 min, single offline window on `IoT IMT Nord Europe`)

Two parts over a single offline-window cycle. Recipe pre-staged so the
offline window stays short and you can collect both probes in one switch.
Open **two terminals** before switching: Terminal A for the persistent
SSH-to-Pi publisher, Terminal B for workstation-side ros2 commands.

### B.1 — DDS cross-machine discovery probe (dispositive)

The remaining open question from Mon Block H. A long-running named publisher
on the Pi + workstation subscribe → unambiguous answer.

**Pre-stage** (on workstation, still on `IMT Nord Europe 5G`; local checks
only — Pi SSH will not work until the IoT switch):

```bash
# Verify the key that yesterday's ssh-copy-id installed still exists locally.
ls -la ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub

# Verify NetworkManager still knows both profiles.
nmcli -t -f NAME connection show | grep -E 'IoT IMT Nord Europe|IMT Nord Europe 5G'
```

**Offline window — Terminal A (long-running Pi publisher)**:

```bash
nmcli connection up "IoT IMT Nord Europe"
ip -br addr | grep -v DOWN
ip route get 10.120.2.50
ping -c 3 10.120.2.50

# Verify SSH key auth now that the workstation is on the Pi-reachable network.
ssh -o BatchMode=yes aqpi-01@10.120.2.50 'hostname'   # expect: imtaqua-pi-01

# SSH to Pi, start long-running publisher in foreground
ssh aqpi-01@10.120.2.50 'bash -lc "
  export ROS_DOMAIN_ID=56
  unset ROS_LOCALHOST_ONLY
  source /opt/ros/jazzy/setup.bash
  ros2 topic pub --rate 1 /pi5_dds_probe std_msgs/msg/String \"{data: pi5_probe}\"
"'
# Leave this terminal running — the publisher needs to stay alive for Terminal B's probe.
```

**Offline window — Terminal B (workstation cross-machine subscribe)**:

```bash
# Open new terminal, switch should already be in effect (workstation on IoT WiFi)
export ROS_DOMAIN_ID=56
unset ROS_LOCALHOST_ONLY
unset RMW_IMPLEMENTATION
source /opt/ros/jazzy/setup.bash
ros2 daemon stop && ros2 daemon start
sleep 3                                   # let DDS discovery settle

echo "== workstation env =="
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID  RMW=${RMW_IMPLEMENTATION:-default}  LOCAL_ONLY=${ROS_LOCALHOST_ONLY:-0}"

echo "== ros2 topic list (look for /pi5_dds_probe) =="
ros2 topic list

echo "== ros2 topic echo --once (should print 'data: pi5_probe' if discovery + transport both work) =="
ros2 topic echo /pi5_dds_probe std_msgs/msg/String --once

echo "== ros2 topic info --verbose (publisher count cross-machine) =="
ros2 topic info /pi5_dds_probe --verbose
```

**Outcome branches:**

| Result | Reading | Next move |
|---|---|---|
| Workstation lists `/pi5_dds_probe` + `echo --once` prints `data: pi5_probe` | DDS cross-machine **works** on IoT WiFi. | B.2 PRIMARY system-desktop test runs first regardless; SECONDARY ROS 2 viz can default to Path A (workstation-side `rviz2`) once PRIMARY is attempted. Phase 5 driver bring-up planning can assume standard ROS 2 graph discovery. |
| Workstation `ros2 topic list` doesn't include `/pi5_dds_probe` | DDS multicast / client-isolation **blocked** by IoT WiFi (probable). | B.2 PRIMARY system-desktop is unaffected (VNC / xrdp / SSH-X don't need DDS). If SECONDARY ROS 2 viz is pursued, skip Path A and try Path B (X-forwarding) or Path C (Foxglove). Document as "Fast-DDS Discovery Server needed for Phase 5"; defer that setup to a focused future session. |
| Workstation lists the topic but `echo --once` hangs / no data | Discovery works but RTP transport blocked. Uncommon. | Investigate firewall / port-block on IoT WiFi; possibly TCP-only DDS workaround. |
| Different error class | Record exact symptom. | Stop, report back. |

**Stop the Pi-side publisher** (Terminal A): `Ctrl-C` in the SSH session, or
close Terminal A entirely. Don't leave it running indefinitely.

### B.2 — System-desktop GUI + ROS 2 data viz trial (exploratory)

**Updated goal (Mon 11/05 evening clarification):** today's **PRIMARY** GUI test is visualizing **the Pi 5's system desktop / OS GUI** — the operator's-eye view of the Pi as a workstation (file manager, terminal windows, system settings, network manager, etc.). This is **distinct** from Pi 5 ROS 2 data visualization (`rviz2` / Foxglove subscribing to Pi topics — covered by the existing **Paths A/B/C below as SECONDARY**).

| Goal | Tools | What it shows |
|---|---|---|
| **PRIMARY** — Pi 5 system desktop | VNC / SSH-X for individual GUI apps / xrdp (rPi Connect skipped today) | What you'd see if a monitor were plugged into the Pi |
| **SECONDARY** — Pi 5 ROS 2 data (Paths A/B/C below) | `rviz2` (workstation or Pi-side) / Foxglove Studio | Topic data (point clouds, IMU pose, etc.) rendered as visualizations |

**Order of operations:** start with PRIMARY system-desktop access; only after at least one PRIMARY path is attempted (or skipped per the pre-req check below), proceed to SECONDARY Paths A/B/C.

**Pre-req check (Pi-side desktop / remote-access tooling state):**

```bash
ssh aqpi-01@10.120.2.50 \
  'ls /usr/share/xsessions/ 2>/dev/null; echo "---"; \
   dpkg -l 2>/dev/null | grep -E "vnc|xrdp|gnome-session|xfce4-session|lxde-core|ubuntu-desktop|raspberrypi-ui-mods" | head -20; \
   echo "---"; \
   systemctl status display-manager 2>/dev/null | head -5'
```

Branches:

- **Pi has DE + VNC or xrdp already installed** → use the installed one directly; jump to the matching PRIMARY path.
- **Pi has DE, no remote-access server** → install VNC: `sudo apt install -y tigervnc-standalone-server tigervnc-common && vncserver :1 -geometry 1280x800 -depth 24` on Pi, then `sudo apt install -y tigervnc-viewer && vncviewer 10.120.2.50:5901` on workstation. (xrdp alt: `sudo apt install -y xrdp && sudo systemctl enable --now xrdp` on Pi, then Remmina-RDP from workstation.)
- **Pi has no DE at all** → installing a minimal desktop is ~30-60 min AND **needs internet** (apt over IoT-only WiFi blocked). **Decision point:** if internet-capable network is reachable, install; otherwise **defer PRIMARY today and run only SECONDARY** (Paths A/B/C below) — surface the choice to user before committing time.

**Lightweight PRIMARY alternative (no Pi-side install required):**

```bash
# Workstation, on IoT WiFi — forwards any single GUI app over SSH
ssh -X aqpi-01@10.120.2.50
xeyes                                  # X-forwarding sanity check
nm-connection-editor                   # network manager (if installed on Pi)
gnome-control-center 2>/dev/null       # system settings (if Gnome installed)
```

`ssh -X` only forwards individual GUI apps, not a full desktop — useful if VNC/xrdp setup blocks today but you still need to run one Pi-side tool. If `xeyes` fails, debug `xauth` / `DISPLAY` before pursuing further.

**rPi Connect:** Raspberry Pi's official browser-based remote access; requires Pi to authenticate with `raspberrypi.com` — likely **blocked by IoT-local WiFi** (per `wiki/Roadmap.md` §1.3). **Skip today**; document any one-shot attempt result and defer to an internet-capable session.

**PRIMARY pass criteria:** at least one path delivers a usable view — either full Pi desktop on workstation (VNC / xrdp), or at minimum a single Pi-side GUI app rendered via SSH-X. Latency tolerable for system-admin tasks (clicking through menus, running config tools).

---

Three SECONDARY candidate paths (ROS 2 data viz, ordered from cheapest → fallback). Pursue only **after** at least one PRIMARY path has been attempted, or if pre-req check shows no Pi desktop and PRIMARY is skipped:

#### Path A — Workstation-side `rviz2` subscribing to Pi topics

Requires B.1 to have succeeded (DDS works cross-machine). Cheapest, no
extra installs.

```bash
# Workstation, still on IoT WiFi, ROS env still set from B.1's Terminal B
# Pi-side publisher (Terminal A) must still be running for there to be something to visualize

ros2 run rviz2 rviz2
# In rviz2:
#   Add → By topic → /pi5_dds_probe (or whichever Pi-side topic is publishing)
#   Confirm message rate / data shows up
```

For a richer test, use any real Pi-side driver topic if one exists later
(LiDAR / IMU / GPS / MAVLink bridge). Do not spend time inventing a dummy
`PointCloud2` publisher during this block; the point of Path A is to prove
the visualization path, not to build test publishers.

#### Path B — Pi-side `rviz2` via X-forwarding

Works regardless of DDS multicast (uses SSH transport for the GUI). Slower
3D rendering over WiFi.

```bash
# Workstation, on IoT WiFi
ssh -X aqpi-01@10.120.2.50

# On Pi (inside the SSH session)
source /opt/ros/jazzy/setup.bash
command -v rviz2 || { echo "rviz2 not installed on Pi; skip Path B and install it later from an internet-capable network"; exit 1; }
rviz2 &
# rviz2 GUI window forwards back to the workstation via X11
# Quit rviz2 with: kill %1 from the shell, or close the X window
```

Caveat: X-forwarding 3D rendering over WiFi is **laggy** — fine for
verifying "the path works", probably not usable for real-time point-cloud
debugging. The latency reading itself is a useful data point for Phase 5
planning.

#### Path C — Foxglove Studio via foxglove_bridge

Newest viewer; uses WebSocket transport (bypasses DDS entirely). Requires
internet to load the Foxglove web app — so workstation needs to be on the
campus 5G WiFi while Pi 5 stays on IoT.

Wait — that won't work directly: workstation needs to reach Pi 5 (IoT
network) AND foxglove.dev (internet). Single-WiFi-adapter constraint
applies.

Alternative: install the Foxglove **desktop app** on workstation (no
runtime internet needed once installed), then connect over WebSocket to
Pi 5 while both are on IoT WiFi. This is the cleanest config but adds an
install step.

Preconditions: `ros-jazzy-foxglove-bridge` already installed on the Pi, and
Foxglove Studio desktop already installed on the workstation. If either is
missing, do not install during the IoT offline window — record the missing
piece and defer Path C.

```bash
# On Pi (launch bridge only if already installed)
command -v ros2
ros2 pkg prefix foxglove_bridge || { echo "foxglove_bridge not installed; defer Path C"; exit 1; }
source /opt/ros/jazzy/setup.bash
ros2 launch foxglove_bridge foxglove_bridge_launch.xml port:=8765

# On workstation (separate session)
# Open Foxglove Studio desktop and connect to: ws://10.120.2.50:8765
```

Path C is the most-future-proof option (works around DDS multicast issues
entirely) but has the most install overhead today. **Try only if Paths A +
B both fail or are unusable.**

### Offline window return

```bash
# (Stop Pi-side publisher in Terminal A first)
nmcli connection up "IMT Nord Europe 5G"
ip -br addr show wlp147s0       # confirm 10.1.X.X back
```

**Outcome.** [To fill — B.1 dispositive result + B.2 working path
(A / B / C / none) + latency observations + any surprises.]

---

## Block C — MP-Linux GDAL/OGR/OSR fix attempt (~45-90 min, mid-PM, conditional)

Same musl→glibc native-binding swap pattern as the SkiaSharp fix from Mon
11/05. Recipe template lives in `wiki/Common_Issues.md` MP-Linux entry's
"Residual minor issues — detailed reference" section, item 1. Fully
workstation-side; no Pi or offline window needed.

**Pre-flight — is this worth chasing today?**

- If routine field-test telemetry/video is the only MP-Linux use, **skip
  this block**. The 24/04 decision (treat MP-Linux GIS as degraded;
  MP-Windows handles GIS demos cleanly) still holds.
- If GIS demos / terrain overlay / advanced geo-ref will be needed in the
  next 1-2 weeks, proceed.
- If unsure: skip today; defer to a future focused session when the
  requirement is concrete.

**Recipe** (parallels the SkiaSharp swap; key differences flagged):

1. **Find bundled GDAL/OGR/OSR binaries**:

   ```bash
   find ~/MissionPlanner -name 'gdal_wrap*' -o -name 'ogr_wrap*' -o -name 'osr_wrap*' 2>/dev/null
   ```

   Run `ldd` on each `.so` found. Expect `libc.musl-x86_64.so.1 => not found`
   (matching the SkiaSharp diagnosis).

2. **Match the existing managed-assembly versions**: read the GDAL/OGR/OSR
   .dll versions on MP's install (`strings -e l ~/MissionPlanner/gdal_csharp.dll | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | head` or .NET assembly inspection). Pick NuGet `GDAL.Native`
   versions matching the bundled wrapper assembly versions.

3. **Idempotent backup + install**, three files in parallel:

   ```bash
   for f in gdal_wrap ogr_wrap osr_wrap; do
     SRC=$(find ~/MissionPlanner -name "${f}.so" | head -1)
     [ -n "$SRC" ] && [ ! -f "${SRC}.musl.bak" ] && cp "$SRC" "${SRC}.musl.bak"
   done
   # Then install the glibc replacements (paths depend on extracted NuGet layout)
   ```

4. **CRITICAL extra step** (vs SkiaSharp): GDAL has a MUCH larger dep
   surface. After replacing each `.so`, run `ldd` on each and confirm all
   of:

   - `libc.so.6` (glibc) — should resolve
   - `libproj.so.X` — PROJ; install via `sudo apt install libproj-dev` if missing
   - `libgeos_c.so.X` — GEOS; `sudo apt install libgeos-dev`
   - `libsqlite3.so.X` — typically present
   - `libcurl.so.X` — typically present
   - Any other `not found` line → install corresponding apt package or **abort**

5. **Smoke test**: launch MP; watch the log for GDAL/OGR/OSR error lines.

   ```bash
   missionplanner > /tmp/missionplanner_gdal_test.log 2>&1 &
   sleep 25
   grep -nE 'gdal_wrap|ogr_wrap|osr_wrap|GDAL|OGR|OSR' /tmp/missionplanner_gdal_test.log | head -30
   ```

6. **Rollback** (if anything regresses):

   ```bash
   for f in gdal_wrap ogr_wrap osr_wrap; do
     SRC=$(find ~/MissionPlanner -name "${f}.so" | head -1)
     [ -f "${SRC}.musl.bak" ] && cp "${SRC}.musl.bak" "$SRC"
   done
   ```

**Pass criteria:**

| Result | Reading |
|---|---|
| GDAL/OGR/OSR error lines disappear from MP log + a GIS feature (e.g., terrain background in Flight Data view) renders | Fix worked. Update `wiki/Common_Issues.md` MP-Linux entry. |
| Errors disappear but no GIS feature actually renders | Partial — wrappers load but functionality not connected. Investigate. |
| Different ABI error class | Wrapper / GDAL version mismatch. Rollback; try different NuGet version. |
| Cascading new deps surface | Deeper dep hell. Rollback; document as "tried, defer indefinitely". |
| Skipped per pre-flight | OK — recipe stays in Common_Issues for future attempt. |

**Outcome.** [To fill if Block C ran — branch, errors observed, rollback
status, fix landed or skipped, any docs updated.]

---

## Block D — QGC stable AppImage update (~10 min, PM, optional)

Per `wiki/MP_QGC_Update_Procedures.md`:

```bash
# Check upstream Last-Modified vs local mtime
curl -sI 'https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage' \
  | grep -i '^last-modified'
stat -c '%y' ~/Applications/QGroundControl.AppImage
```

**Decision matrix:**

- Upstream **older or same** as local → skip; record current state.
- Upstream **newer** but no specific reason to upgrade → **skip**; the
  2025-10-09 stable AppImage worked yesterday with the verified
  `Source = Herelink Hotspot` preset. No functional gain to chasing.
- Upstream **newer** + concrete reason (changelog mentions a wanted fix,
  yesterday's session surfaced a bug that's resolved upstream, etc.) →
  proceed to the update workflow.

**If proceeding**: follow `wiki/MP_QGC_Update_Procedures.md` § "QGroundControl
— stable update workflow" steps 1-6. Smoke test post-update: confirm
`Application Settings → General → Video → Source = Herelink Hotspot` still
exists and the video panel still renders (would need an offline-window
switch to actually test against the Herelink — defer that to the next
field-touching session, not today).

**Outcome.** [To fill — upstream Last-Modified result, decision (update or
skip with reason), if updated: new build date + smoke-test outcome.]

---

## Block E — Doc stale-claim sweep (~30-45 min, late PM)

Forward-audit on `Board.md`, `README.md`, `wiki/Roadmap.md`,
`wiki/Common_Issues.md`, `wiki/MP_QGC_Update_Procedures.md`, and the README
/ wiki stamp files below for stale claims, broken cross-refs, outdated
framings, and stale `Last Updated` stamps. **Inspect-only by default** —
flag file:line + claim + correction; let user pick fix-now vs defer per the
standard audit pattern.

**Focus areas (in priority order):**

### E.1 — `Board.md`

- Status summary (header line ~12) — should reflect end-of-day 11/05 state
  correctly post the 6-commit day.
- Phase 5 Hardware-arrival rows (lines ~178-185) — verify install rows
  (MP/QGC install, Herelink A/B retest) have accurate "as-of-11/05"
  wording.
- Timeline row 11/05/2026 — quite long after Block H + domain-0 addendum;
  check for any remaining internal contradictions (e.g., sequencing of
  "initially carried forward / evening execution / domain-0 follow-up").
- Footer `Document Version` + `Last Updated` — should be `9.10 /
  11/05/2026` from Mon's bump. If today lands substantive content, bump
  again at Block F.

### E.2 — `README.md`

- Hasn't been touched in the recent MP/Pi 5 flurry — verify it has no
  stale claims about MP-Linux status (unlikely since MP is a workstation
  install, not a project artifact, but verify with grep).
- VRX clone URL pinning (per 06/05 fork migration) — should still point at
  `Ghostzero00018/vrx` `autoboat/main`.
- `--use-nvidia` Quick Start callout — should still be accurate post the
  04/05 root-cause fix.
- Any stale claims about workstation setup / dependencies?

### E.3 — `wiki/Roadmap.md`

- ~~§1.1 / §1.3 IoT IMT Nord Europe mentions — Mon Side activity Outcome flagged these for re-check on suspicion of SSID-name-vs-network-meaning mismatch.~~ **RESOLVED Mon evening per user clarification:** the SSID `IoT IMT Nord Europe` IS the same network §1.3 describes (workstation↔Pi link uses the same `IoT IMT Nord Europe` SSID as the institutional IoT WiFi referenced by §1.3); §1.3's local-only / no-internet analysis applies directly. **No Roadmap wording change needed for this concern.** Still verify §1.1 / §1.3 are otherwise current (no other stale-claim drift since 30/04).
- §3 Phase 5 status table (line ~182) — should have today's MP-Linux fix
  note from 11/05.
- §9 Revision log — should it have a new entry for the 11/05 MP-Linux fix + Pi 5 verified-bare state? Decide.

### E.4 — `wiki/Common_Issues.md`

- MP-Linux entry — Status bullets should reflect post-fix state (updated
  yesterday); double-check the "Residual minor issues — detailed
  reference" section's 6 items.
- QGC video-missing entry — campus side closed via 11/05 verification
  paragraph; check that lake-side path is still framed as open.
- VLC build caveat (Ubuntu Noble live555 disabled) — still accurate per
  yesterday's diagnostic.
- Any internal cross-refs that broke from yesterday's edits?

### E.5 — `wiki/MP_QGC_Update_Procedures.md`

- Bonus check on yesterday's newly-landed page — should already be clean
  since it's <24h old, but verify the "Current install state" table
  matches today's reality (especially if Block D updates QGC).

### E.6 — README / wiki stamp sweep

- `wiki/Home.md` — current stamp `30/04/2026`; likely stale after the
  06/05 Roadmap §8 rewrite, 07/05 folder-framing READMEs, and new Sun-Mon
  files.
- `wiki/README_WIKI.md` — current stamp `03/05/2026`; likely stale after
  `wiki/VRX_Fork_Migration.md` landed on 06/05 and later wiki edits.
- `working_diary/README.md` — current stamp `07/05/2026`; stale after the
  `2026-05-11_*.md` and `2026-05-12_*.md` diary files were added.
- `USER_MANUAL.md` — current stamp `06/05/2026`; review whether any
  substantive post-06/05 edits require a bump or whether the stamp is still
  defensible.
- `web_dashboard/autoboat/README_autoboat_dashboard.md` — current stamp
  `07/05/2026`; quick confirm only, since the 07/05 tunable-contract update
  may already be the latest substantive edit.

**Approach:**

```bash
# Risky-term grep per file
for f in Board.md README.md USER_MANUAL.md wiki/Roadmap.md wiki/Common_Issues.md wiki/MP_QGC_Update_Procedures.md wiki/Home.md wiki/README_WIKI.md working_diary/README.md web_dashboard/autoboat/README_autoboat_dashboard.md; do
  echo "=== $f ==="
  grep -nIE 'fail|degrad|unresolved|open|TBD|deferred|pending|broken|missing|todo' "$f" | head -10
done
```

Then read each hit in context. Cross-check against today's known state.

**Outcome.** [To fill — list of findings per file (stale / accurate /
borderline), user-picked fix list, anything landed inline.]

---

## Block F — Day wrap (~30 min, evening)

Same shape as Mon 11/05's Block F:

1. `git log --oneline -10` — sanity check today's commits.
2. Pre-commit invisibility sweep — expect 0 matches.
3. Add 12/05/2026 `Board.md` milestone row(s) for whatever lands; bump
   header `**Last Updated**` row + bottom `**Document Version** ... **Last
   Updated**` trailer stamp to 12/05/2026 if anything substantive lands.
   **Use search rather than relying on line numbers** — both rows drift as
   Board.md grows.
4. Fill all `[To fill]` placeholders in this file.
5. Working diary commit; subject template depends on dominant outcome:
   - DDS works + viz path identified:
     `docs: 12/05 Pi 5 DDS cross-machine verified + viz path X`
   - DDS blocked:
     `docs(diary): 12/05 Pi 5 DDS multicast blocked; Discovery Server next`
   - Mixed outcomes:
     `docs(diary): 12/05 Pi 5 deep check + doc sweep findings`
6. Push.
7. **Update Week 10 external diary Mon/Tue Outcome bullets** — Mon Outcome
   is carry-over from Mon Block F Step 8 if still placeholder; Tue Outcome
   is today's fill. External Windows-side weekly diary; deferred to next
   Windows-side session if not Linux-reachable.

**Outcome.** [To fill at end of day.]

---

## Verification summary — 12/05 (check at end of day)

- [ ] Block A: morning re-orientation done; Pi 5 reachability confirmed; VRX §8.2 state-check OK
- [ ] Block B.1: DDS cross-machine probe executed; result categorized (works / blocked / partial / error)
- [ ] Block B.2: GUI viz trial — at least one path identified as working (or all three explicitly attempted + failed)
- [ ] Block C: MP-Linux GDAL/OGR/OSR fix attempted (or explicitly skipped with reason)
- [ ] Block D: QGC stable AppImage version check done; updated or explicitly skipped
- [ ] Block E: doc stale-claim sweep complete across all 4-5 target files; findings list captured
- [ ] Block F: diary filled; pre-commit sweep clean; `Board.md` updated if substantive; commit landed; push done

---

## Rollover checkpoints

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | Re-orientation done; Pi 5 reachability confirmed | None — drives the day's branch |
| Block B.1 | DDS cross-machine result known | **High** — drives Phase 5 driver bring-up planning + B.2 path choice |
| Block B.2 | At least one viz path identified (or all three categorized) | Low — informative regardless |
| Block C | MP-Linux GDAL state known (fixed / attempted+rolled-back / skipped) | Low — orthogonal to Pi 5 / Phase 5 path |
| Block D | QGC version state known | Low — also orthogonal |
| Block E | Stale-doc audit findings collected | Medium — drives any follow-up doc fixes |
| Block F | Day closed | Standard — should always close |

---

## Known unknowns to record during the day

- DDS multicast / client-isolation behaviour of the `IoT IMT Nord Europe`
  WiFi (Block B.1 answers this dispositively).
- Working Pi 5 system-desktop remote-access path + observed latency
  (Block B.2 PRIMARY); ROS 2 data viz path only if SECONDARY is reached.
- Whether MP-Linux GDAL fix is tractable on this Ubuntu Noble install
  (Block C — only if attempted).
- Current QGC stable AppImage cadence (Block D, casually observable).
- Any stale-claim survivors from Mon 11/05's audit + cleanup (Block E).
- Overnight inputs (supervisor / teammate replies / external events).

---

## Next steps — Tue 12/05 → end of week

### Active branch: today's Pi 5 deep check + residuals + doc sweep

Today's outcomes drive the rest of the week:

- **If DDS cross-machine works on IoT WiFi (B.1 success)**: begin Phase 5
  driver bring-up planning on Pi (which drivers to install first — LiDAR /
  GPS / IMU drivers, `mavros2` for MAVLink autopilot bridge, autostart
  strategy on Pi).
- **If DDS multicast blocked (B.1 failure)**: Fast-DDS Discovery Server
  (unicast) setup becomes the next focused Pi 5 session — separate scope,
  ~half-day. Phase 5 driver bring-up still proceeds in parallel using the
  Discovery Server config.
- **If MP-Linux GDAL fix landed (Block C success)**: MP-Linux GIS
  capability unblocked; can demo terrain views from Linux side too. Update
  `Board.md` + `wiki/Common_Issues.md` accordingly.
- **If doc sweep surfaces real stale claims (Block E)**: queue them as
  tomorrow's first task or land them same-day in Block F.

### Pending all week (carried from Mon 11/05)

- Formal joint supervisor presentation reschedule — still pending IMT
  Mines Alès availability + power restoration.
- Three Asks to teammate maintainer (Phase A parameter subset; CA
  placement; validation methodology).
- Second-site (lake) Herelink video A/B retest — deferred from Mon 11/05
  Block D, rolls into next field session under known-good QGC
  `Source = Herelink Hotspot` preset.

### This week's possible time-permitting tasks (explicitly deferred-for-week per user direction; pick up only if any Tue-Fri block runs short)

- **P1 pier/bank stuck investigation** — diagnostic plan in
  `working_diary/2026-04-24_pier_bank_stuck_and_rate_probe.md` Block A.
  Substantial sim work; naturally pauseable. Requires
  `bash one_click_launch_all/launch_autoboat_complete.sh --use-nvidia` to
  hold acceptable RTF (per 04/05 RTF investigation: ~0.32 → ~0.88 with
  the flag). Slot in only if a Tue/Wed/Thu block ends early and a
  pauseable sim activity fits.
- **Real no-regression test for `launch/remap.launch.yaml`** — prereqs
  refined post Mon 11/05 Block H: Pi-side ROS 2 install state confirmed
  (no longer "all TBD"), but the topic-name diff vs sim still needs
  Phase 5 driver bring-up on Pi (LiDAR / GPS / IMU / `mavros2`) so there
  are real-hardware Pi topics to diff. Slot in only if Tue/Wed/Thu sees
  Phase 5 driver bring-up land mid-week; otherwise stays deferred — it
  isn't actionable until driver topics exist.

### Deferred (carried from earlier)

- Mock water quality sensor implementation (Phase A — unblocked once
  supervisor confirms parameter set).
- Roadmap §1.3 Path B (offline tile server with pre-generated MBTiles for
  test area).
- Dashboard CSP Option B (reverse-proxy header injection) and Option C
  (Caddy / external static webserver).
- 24/04 housekeeping carry-overs (`mono-xsp4` port-8084 disable;
  `tools/qos_scan.py` single-pass QoS inventory).
- Dashboard scaffold-without-write audit (29/04 architectural lesson).
- C3 bench verification — passive wait for real-hardware double-reverse
  symptom.
- Sim-to-real comparison — was conditional on a 07/05 rosbag; none
  recorded, N/A until a future field test records autonomy bag data.
- External Week 9 + Week 10 diary outcomes — bilingual EN + 中文,
  Windows-side; deferred to next Windows session.
