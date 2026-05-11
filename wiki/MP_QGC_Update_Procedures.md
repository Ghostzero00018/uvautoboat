# Mission Planner + QGroundControl — Linux Update Procedures

> **Status (11/05/2026)**: Mission Planner is current against ArduPilot's
> `MissionPlanner-latest.msi` (upstream `Last-Modified`: 2025-09-10). QGC is
> current on the official **stable** Linux AppImage channel (upstream
> `Last-Modified`: 2025-10-08 UTC; local file mtime: 2025-10-09 CEST). A newer
> QGC daily build exists, but the workstation is intentionally left on stable;
> this page captures both the stable update workflow and the optional daily
> switch workflow for future use.

This page documents how to update **Mission Planner** (under Mono on Linux)
and **QGroundControl** (AppImage) on the Linux workstation. Both apps are
installed host-locally — not via apt or the ROS 2 workspace — so updates are
manual.

---

## Current install state (11/05/2026)

| App | Install path | Version / build | Source URL |
|:-----|:------|:-------|:------|
| Mission Planner | `~/MissionPlanner/MissionPlanner.exe` | Assembly version `1.3.9384.38250`; `AssemblyFileVersion` `1.3.83`; mtime 2025-09-10 21:15:06 | `https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.msi` |
| QGroundControl | `~/Applications/QGroundControl.AppImage` (symlinked from `~/.local/bin/qgc`) | Stable AppImage dated 2025-10-09 01:42:56 CEST (`Last-Modified`: 2025-10-08 23:42:56 UTC) | `https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage` |

QGC's user-settings live at `~/.config/QGroundControl/`. MP's flight-data
logs (`.tlog` / `.rlog`) live at `~/.local/share/Mission Planner/`. Both
directories are independent of the binary install path and survive updates.

---

## Checking whether an update is available

```bash
# MP — compare upstream Last-Modified header vs local file mtime
curl -sI 'https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.msi' \
  | grep -i '^last-modified'
stat -c '%y' ~/MissionPlanner/MissionPlanner.exe

# QGC stable channel — same idea against the official Linux x86_64 AppImage
curl -sI 'https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage' \
  | grep -i '^last-modified'
stat -c '%y' ~/Applications/QGroundControl.AppImage

# Optional QGC daily-build channel check — use only if intentionally switching
# from stable to daily:
curl -sI 'https://d176tv9ibo4jno.cloudfront.net/builds/master/QGroundControl-x86_64.AppImage' \
  | grep -i '^last-modified'
```

If upstream `Last-Modified` is newer than the local file mtime, a newer
build exists.

For Mission Planner, use the firmware-server `Last-Modified` header as the
practical update signal. The marketing / file version (`1.3.83` in the
current binary's `AssemblyFileVersion`) is decoupled from the `.msi` rebuild
cadence, so a newer binary build doesn't always correspond to a new public
release tag.

---

## Mission Planner — update workflow

ArduPilot publishes continuous MP builds to its firmware server; the file
version inside `MissionPlanner-latest.msi` advances with each build, while
the marketing tag stays at `1.3.83`. Builds are infrequent — the
2025-09-10 build was still the latest as of 11/05/2026.

### Steps

1. **Stop any running MP** before replacing files:

   ```bash
   PIDS=$(ps -eo pid,cmd | awk '/MissionPlanner\.exe/ && !/awk/ {print $1}')
   [ -n "$PIDS" ] && kill -TERM $PIDS
   ```

2. **Back up the current install** (preserves the host-local SkiaSharp +
   libdl fix in case the update regresses something):

   ```bash
   cp -r ~/MissionPlanner ~/MissionPlanner.bak-$(date +%Y-%m-%d)
   ```

3. **Download the new MP `.msi`**:

   ```bash
   cd /tmp
   wget -O MissionPlanner-latest.msi \
     https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.msi
   ```

4. **Extract the .msi to update files in `~/MissionPlanner/`**. MP-on-Linux
   runs the extracted `.exe` under Mono — the `.msi` installer itself isn't
   used. Extract via `msiextract` from the `msitools` apt package:

   ```bash
   sudo apt install -y msitools
   mkdir -p /tmp/mp-new && cd /tmp/mp-new
   msiextract /tmp/MissionPlanner-latest.msi
   # Inspect the extracted tree:
   ls -la
   # Typically contains: MissionPlanner.exe, x64/, x86/, plugins/, *.dll, *.config
   # Copy or rsync the updated files into ~/MissionPlanner/ (overwriting the
   # existing files there). Match the existing layout — particularly the
   # x64/ subdir and the plugins/ layout — verify before bulk-copying.
   ```

   The Linux-side install path on this workstation pre-dated this
   document; the `msiextract` approach above is the canonical extraction
   method for future updates. Verify the extracted layout matches
   `~/MissionPlanner/` before overwriting.

5. **CRITICAL — re-apply the host-local SkiaSharp + libdl fix** after the
   new MP files land. Updating MP overwrites the musl→glibc SkiaSharp swap
   and may remove the `~/MissionPlanner/libdl.so` symlink:

   ```bash
   # Quick check: did the new bundle bring back the broken musl libSkiaSharp?
   ldd ~/MissionPlanner/x64/libSkiaSharp.so | head -3
   # If 'libc.musl-x86_64.so.1 => not found' → re-apply the fix.
   #
   # Also confirm the libdl shim is intact:
   ls -l ~/MissionPlanner/libdl.so
   ```

   See [Common_Issues § Mission Planner on Linux: libSkiaSharp DllNotFoundException](Common_Issues#mission-planner-on-linux-libskiasharp-dllnotfoundexception)
   "Fix applied" subsection — re-run steps 1-4 of the recipe. Match the
   SkiaSharp NuGet version to whatever's in the new
   `~/MissionPlanner/SkiaSharp.dll` managed-assembly version (read via
   `strings -e l ~/MissionPlanner/SkiaSharp.dll | grep -E '^[0-9]+\.[0-9]+\.[0-9]+'`
   or .NET assembly inspection). On the current install: `2.88.8.0`. If the
   new MP bumped its SkiaSharp dependency, swap to the matching NuGet
   version instead of `2.88.8`.

6. **Smoke test** the new MP — launch, verify the video panel renders on
   the Herelink hotspot link, confirm arm/disarm works.

7. **Update tracking docs** if the build version or date changed:

   - `Board.md` Status line + Phase 5 Hardware-arrival install row +
     Timeline entry.
   - `wiki/Roadmap.md` Phase 5 install-prep row.
   - This page's "Current install state" table.

### Rollback

```bash
mv ~/MissionPlanner ~/MissionPlanner.failed-$(date +%Y-%m-%d-%H%M%S)
mv ~/MissionPlanner.bak-<YYYY-MM-DD> ~/MissionPlanner
```

---

## QGroundControl — stable update workflow

QGC is currently installed from the official stable Linux x86_64 AppImage
channel. This is the default update path for the workstation because it keeps
the known-good Herelink Hotspot video preset while avoiding unnecessary daily
build churn.

### Steps

1. **Stop any running QGC**:

   ```bash
   PIDS=$(ps -eo pid,cmd | awk '/QGroundControl\.AppImage/ && !/awk/ {print $1}')
   [ -n "$PIDS" ] && kill -TERM $PIDS
   ```

2. **Back up the current AppImage** (dated suffix preserves it as a
   known-good fallback):

   ```bash
   mv ~/Applications/QGroundControl.AppImage \
      ~/Applications/QGroundControl.AppImage.bak-$(date +%Y-%m-%d)
   ```

3. **Fetch the latest stable AppImage**:

   ```bash
   wget -O ~/Applications/QGroundControl.AppImage \
     https://d176tv9ibo4jno.cloudfront.net/latest/QGroundControl-x86_64.AppImage
   chmod +x ~/Applications/QGroundControl.AppImage
   ```

4. **Smoke test** the new build:

   - Launch via `~/.local/bin/qgc` or directly via the AppImage path.
   - Confirm `Application Settings → General → Video → Source` still
     offers the **`Herelink Hotspot`** preset (this is a built-in QGC
     feature, should survive AppImage version changes — but verify).
   - Verify the video panel renders correctly on the Herelink hotspot
     (SSID `IMT-Aquatic-drone`, gateway `192.168.43.1`).

5. **No SkiaSharp / libdl re-apply needed for QGC** — QGC ships its own
   bundled libraries inside the AppImage, completely separate from
   MP-Linux's Mono-based stack. The host-local fix in `~/MissionPlanner/`
   isn't touched by a QGC update.

6. **Update tracking docs** if the build date changed:

   - `Board.md` Status line + Phase 5 Hardware-arrival install row.
   - `wiki/Roadmap.md` Phase 5 install-prep row.
   - This page's "Current install state" table.

### Optional: switch QGC to the daily-build channel

Daily builds carry newer QGC changes and less test coverage. Use this only
when a specific daily-build fix or feature is needed, or when stable fails
and the QGC changelog / daily notes point to a likely fix.

The current Linux x86_64 daily AppImage URL from the official QGC daily-build
page is:

```bash
https://d176tv9ibo4jno.cloudfront.net/builds/master/QGroundControl-x86_64.AppImage
```

To switch, follow the same backup + smoke-test workflow above, but replace
the stable `wget` URL with the daily-build URL. If daily regresses Herelink
video or connection behaviour, use the rollback recipe immediately and stay
on stable.

### Rollback

```bash
mv ~/Applications/QGroundControl.AppImage \
   ~/Applications/QGroundControl.AppImage.failed-$(date +%Y-%m-%d)
mv ~/Applications/QGroundControl.AppImage.bak-<YYYY-MM-DD> \
   ~/Applications/QGroundControl.AppImage
chmod +x ~/Applications/QGroundControl.AppImage
```

---

## When to update vs leave alone

Both apps are working on this workstation as of 11/05/2026. Routine updates
aren't urgent — recommend updating only when:

- A specific bug fix or feature in the changelog is wanted.
- A field-test session has surfaced an issue that the changelog suggests is
  resolved upstream.
- A long enough interval has passed (e.g., quarterly) that drift between
  installed + upstream becomes a maintenance liability.

Updates carry a non-zero risk of regressing currently-working behaviour.
QGC daily builds are pre-release by design, so treat them as opt-in rather
than routine maintenance. Each update should be followed by the smoke-test
step + revert via the rollback recipe if anything regresses.

---

## Cross-references

- [Common_Issues § Mission Planner on Linux: libSkiaSharp DllNotFoundException](Common_Issues#mission-planner-on-linux-libskiasharp-dllnotfoundexception) — the host-local SkiaSharp + libdl fix to re-apply after any MP update.
- [Common_Issues § QGC / Mission Planner Can Arm via Herelink, but Video Is Missing](Common_Issues#qgc--mission-planner-can-arm-via-herelink-but-video-is-missing) — diagnostic recipe if the video panel breaks after a QGC update.
- [Roadmap §3 — Phase 5: Real-Hardware Deployment](Roadmap#3-phase-5--real-hardware-deployment) — broader context for MP/QGC in the project.
- ArduPilot Mission Planner downloads: <https://firmware.ardupilot.org/Tools/MissionPlanner/>
- QGroundControl download + daily-builds documentation: <https://docs.qgroundcontrol.com/master/en/qgc-user-guide/getting_started/download_and_install.html>
