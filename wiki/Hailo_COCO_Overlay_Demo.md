# Pi Hailo COCO-Overlay Demo — Build & Run Procedure

Reproducible procedure for the Raspberry Pi 5 + Hailo-8L **live object-detection
overlay pipeline**: `D435I RGB -> HailoRT NMS post-process -> COCO box overlay ->
display / save`. It is proven end to end with a stock COCO `yolov11n` model, so
the camera-to-overlay path is de-risked independently of any custom detector.

This is the reusable framework a future maritime or unicolor detector plugs into
once its own accelerator model is ready; see [Plugging in a custom
detector](#plugging-in-a-custom-detector).

## Purpose And Boundary

- **Proves:** the live path runs on real hardware — camera capture, Hailo
  inference, HailoRT post-processing, and a correct labelled box overlay at an
  interactive ~15 FPS.
- **Does not prove / is not:** maritime or custom-detector recovery, detector
  accuracy, custom-HEF compatibility, Hailo compile / calibration, export, ROS
  integration, or any command / actuator path. A stock COCO model recognises
  `person`, `bus`, `chair`, `bottle`, etc. — not `buoy` / `vessel` / `dock`.
- **Repository boundary:** the runtime artifacts (runner checkout, virtualenv, HEF,
  input images, logs, and annotated outputs) stay **outside** the public repo,
  under an external root on the Pi (below). Only this procedure doc — which embeds
  the launcher source as documentation — and the working-diary record are tracked.

## Prerequisites

The proven Pi runtime baseline from [Hailo HAT Workstream
Memo](Hailo_HAT_Workstream) must be in place:

- Ubuntu 24.04 on kernel `6.8.0-1060-raspi`, Python `3.12`, aarch64.
- HailoRT / driver / pyHailoRT `4.24.0`; `/dev/hailo0` present; `hailo_pci` DKMS
  module matches the running kernel; `hailortcli fw-control identify` reports
  `HAILO8L`.
- Intel RealSense D435I on a USB 3 port; Raspberry Pi Active Cooler fitted;
  dedicated Pi power (confirm `vcgencmd get_throttled` reads `throttled=0x0`; on
  Ubuntu this needs `sudo` because the login user is not in the `video` group).
- Internet access for the one-time build (runner clone + HEF download).

External root used throughout (override with `HAILO_DEMO_ROOT`):
`~/hailo_coco_overlay_2026-07-10/`.

## Pinned Artifacts

| Artifact | Pin |
| --- | --- |
| Runner | Hailo Apps standalone object-detection, release `26.03.1`, checkout `891ce701c2ebe239a5d277759eb75a30f76678a9` |
| HEF | Model Zoo `v2.19.0` `hailo8l/yolov11n.hef`, `11712608` bytes, SHA-256 `d08e140e61befc4fe3c8e5c2d10969fec258bc411363de6813e8b1778dc7cb8e` |
| HEF contract | input `640x640x3`; output `yolov8_nms_postprocess` = HAILO NMS BY CLASS, `80` classes, score `0.20`, IoU `0.70` — HailoRT runs this NMS post-process (yolov11n: host CPU, `engine=cpu`; the `..._nms_core` variant: NPU core), so the runner receives final decoded boxes and no host decoder is written |
| Runtime | HailoRT `4.24.0` (the runner documents `4.23.0`; the minor gap was confirmed working, not assumed) |

## Build (One-Time)

Verify, then build under the external root. Each step is a gate — stop and record
the exact blocker rather than working around it.

1. **Preflight.** Confirm host, kernel, Python, `/dev/hailo0`, HailoRT + firmware
   `4.24.0` / `HAILO8L`, D435I serial / firmware / USB 3, free disk, DNS, and a
   clean kernel fault tail. Require dedicated power, the active cooler, and no
   existing camera or Hailo consumer.
2. **Runner + venv.** Clone the runner at tag `26.03.1`, verify the checkout SHA,
   and create a fresh virtualenv; install the runner requirements plus the pinned
   `hailort-4.24.0` wheel. Do not modify the proven `~/venvs/hailo-rt-4.24.0`
   runtime environment.
3. **HEF.** Download the pinned `yolov11n.hef`, verify byte size and SHA-256, then
   `hailortcli parse-hef` and require `HAILO8L`, a `640x640x3` input, and the
   `yolov8_nms_postprocess` output.
4. **Saved-still sanity.** Run the runner headless on a bundled COCO image
   (`--input bus.jpg --no-display --save-output`) and visually confirm at least one
   correct labelled box before any live capture.

Save the following as a script and run it (`bash build.sh`) — with `set -Eeuo
pipefail` it fails on any pin mismatch instead of continuing:

```bash
set -Eeuo pipefail
ROOT=~/hailo_coco_overlay_2026-07-10
APP="$ROOT/hailo-apps/hailo_apps/python/standalone_apps/object_detection"
WHEEL=~/pi_payload_2026-07-02/hailort-4.24.0-cp312-cp312-linux_aarch64.whl
HEF="$ROOT/models/yolov11n-v2.19.0-hailo8l.hef"
mkdir -p "$ROOT/models" "$ROOT/inputs" "$ROOT/output/still" "$ROOT/logs"

# runner at the pinned tag; assert the checkout SHA
git clone --depth 1 --branch 26.03.1 https://github.com/hailo-ai/hailo-apps.git "$ROOT/hailo-apps"
[ "$(git -C "$ROOT/hailo-apps" rev-parse HEAD)" = 891ce701c2ebe239a5d277759eb75a30f76678a9 ] \
  || { echo "runner SHA mismatch"; exit 1; }

# pinned HailoRT 4.24.0 aarch64/cp312 wheel: assert its SHA before installing
echo "72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d  $WHEEL" | sha256sum -c -
python3 -m venv "$ROOT/venv"
"$ROOT/venv/bin/python" -m pip install -r "$APP/requirements.txt" "$WHEEL"
"$ROOT/venv/bin/python" -m pip check

# HEF: download, assert byte size + SHA-256, then assert the parse-hef contract
curl -fL "https://hailo-model-zoo.s3.eu-west-2.amazonaws.com/ModelZoo/Compiled/v2.19.0/hailo8l/yolov11n.hef" -o "$HEF"
[ "$(stat -c%s "$HEF")" = 11712608 ] || { echo "HEF size mismatch"; exit 1; }
echo "d08e140e61befc4fe3c8e5c2d10969fec258bc411363de6813e8b1778dc7cb8e  $HEF" | sha256sum -c -
hailortcli parse-hef "$HEF" | tee "$ROOT/logs/parse_hef.log"
grep -q 'HAILO8L'                "$ROOT/logs/parse_hef.log" || { echo "parse-hef: not HAILO8L"; exit 1; }
grep -q '640x640x3'              "$ROOT/logs/parse_hef.log" || { echo "parse-hef: input not 640x640x3"; exit 1; }
grep -q 'yolov8_nms_postprocess' "$ROOT/logs/parse_hef.log" || { echo "parse-hef: NMS output missing"; exit 1; }

# known-positive input: download into the external root and assert its SHA
curl -fL "https://hailo-csdata.s3.eu-west-2.amazonaws.com/resources/images/bus.jpg" -o "$ROOT/inputs/bus.jpg"
echo "33b198a1d2839bb9ac4c65d61f9e852196793cae9a0781360859425f6022b69c  $ROOT/inputs/bus.jpg" | sha256sum -c -

# saved-still sanity under an outer timeout (SIGTERM at 120s, SIGKILL 10s later)
timeout -k 10s 120s "$ROOT/venv/bin/python" "$APP/object_detection.py" \
  --hef-path "$HEF" --input "$ROOT/inputs/bus.jpg" \
  --no-display --save-output --output-dir "$ROOT/output/still"
```

## Run (Live Overlay)

1. **Map the D435I RGB node.** The D435I exposes several `/dev/video*` nodes; pick
   the **colour** one (single `YUYV` format), not depth (`Z16`) or infrared
   (`GREY`). On this Pi it is `/dev/video4`. Confirm with:

   ```bash
   for d in /dev/video0 /dev/video2 /dev/video4; do
     echo "=== $d ==="; v4l2-ctl -d "$d" --list-formats 2>/dev/null | grep -E "Type|: '"
   done
   ```

   The high-numbered multiplanar nodes (`/dev/video19`+) are the Pi's own ISP
   pipeline, not the RealSense — never point the runner at them.
2. **Launch with the temperature-guarded script** (below). It runs the detector,
   opens the live overlay window on the desktop, watches the CPU temperature, and
   stops the detector automatically if it reaches the abort threshold.
3. **Stop conditions.** The launcher aborts on temperature `>= 80 C`; also stop
   manually (Ctrl+C) on a wrong / blank stream or repeated inference errors. Run
   from a desktop / Remmina session, not an SSH-only shell, so the window can open
   and the RealSense `plugdev` seat is available.

## Quick-Launch Script

`hailo_coco_demo.sh` is the temperature-guarded launcher. It is a Track 2 artifact,
so it is not committed as an executable — this doc holds its durable source. Copy it
to the Pi under the external root, verify the checksum, `chmod +x`, and run it:

- SHA-256: `64426ec4b9413f9e19f9ba7fa5517e08dca699273baedc9c4d6faf9ecd3c4d6c`
  (Pi-validated 10/07 by a `20 s` HD run: `res=hd`, `RC=0`, saved AVI a true
  `1280x720`)

```bash
# run until Ctrl+C or the temperature abort trips
./hailo_coco_demo.sh
# run for a bounded 60 s (still temperature-guarded)
./hailo_coco_demo.sh 60
```

Tunable via environment variables: `HAILO_DEMO_ROOT`, `HAILO_DEMO_CAM`,
`HAILO_DEMO_RES` and `HAILO_DEMO_OUTRES` (both `sd` / `hd` / `fhd`; see the
window-size note below), `HAILO_DEMO_FPS`, `HAILO_DEMO_ABORT_MC`
(abort temperature in millidegrees, default `80000`), `HAILO_DEMO_POLL_S`,
`HAILO_DEMO_MAX_BAD_READS`, `HAILO_DEMO_GRACE_S`. The launcher starts the detector
so `SIGINT` (Ctrl+C) stops it gracefully and preserves `--save-output`; it stops the
detector by PID only — escalating `INT -> TERM -> KILL`, never pattern-matching — on
a temperature abort, an unreadable sensor (fail-closed after a few reads), Ctrl+C,
or the launcher-side deadline; and it reports the peak temperature and propagates the
detector's exit status (non-zero if the detector itself failed).

**Window size.** The display and the saved AVI are sized by the output resolution.
For a larger, faithful recording set `HAILO_DEMO_RES` (e.g. `hd` or `fhd`) so capture
and output match — `OUTRES` follows `RES` by default. Setting `OUTRES` alone decouples
them: the runner keeps the display aspect-correct but stretches the *saved* AVI to the
literal `OUTRES` preset, so match the two to avoid a distorted recording. The window
is fixed-size (not drag-resizable), so choose the size with these knobs.

Canonical source (the SHA-256 above is of this file):

```bash
#!/usr/bin/env bash
#
# hailo_coco_demo.sh - quick-launch the Pi Hailo-8L stock-COCO live overlay demo,
# with a temperature watchdog that stops the detector automatically if the Pi runs
# too hot. Stock-COCO mechanics only; not a maritime or custom detector.
#
# Usage:
#   ./hailo_coco_demo.sh          # run until Ctrl+C or the temperature abort trips
#   ./hailo_coco_demo.sh 60       # run for 60 s (still temperature-guarded)
#
# Override defaults via env, e.g.:
#   HAILO_DEMO_CAM=/dev/video4 HAILO_DEMO_ABORT_MC=78000 ./hailo_coco_demo.sh
#
# Exit status: 0 on a clean finish or a watchdog/deadline stop; 130 on Ctrl+C
# (SIGINT); otherwise the detector's own non-zero code if it fails.
#
set -Eeuo pipefail

ROOT="${HAILO_DEMO_ROOT:-$HOME/hailo_coco_overlay_2026-07-10}"
VENV="$ROOT/venv"
APP="$ROOT/hailo-apps/hailo_apps/python/standalone_apps/object_detection"
HEF="${HAILO_DEMO_HEF:-$ROOT/models/yolov11n-v2.19.0-hailo8l.hef}"
CAM="${HAILO_DEMO_CAM:-/dev/video4}"        # D435I RGB (YUYV) node
RES="${HAILO_DEMO_RES:-sd}"                 # camera capture: sd=640x480 hd=1280x720 fhd=1920x1080
OUTRES="${HAILO_DEMO_OUTRES:-$RES}"         # display/output window size: sd|hd|fhd (default = camera res)
FPS="${HAILO_DEMO_FPS:-15}"
ABORT_MC="${HAILO_DEMO_ABORT_MC:-80000}"    # hard abort at 80.0 C (millidegrees)
POLL_S="${HAILO_DEMO_POLL_S:-2}"
MAX_BAD_READS="${HAILO_DEMO_MAX_BAD_READS:-3}"  # fail-closed after this many bad temp reads
GRACE_S="${HAILO_DEMO_GRACE_S:-20}"         # launcher-side deadline grace over DURATION
DURATION="${1:-}"                           # optional seconds; empty = until Ctrl+C
THERMAL=/sys/class/thermal/thermal_zone0/temp
OUTDIR="$ROOT/output/live"
LOGDIR="$ROOT/logs"
DET=""
STOPPED_BY_US=0

log() { printf '[hailo-demo] %s\n' "$*"; }
die() { printf '[hailo-demo] STOP: %s\n' "$*" >&2; exit 1; }

# Stop the detector we launched, by PID only, escalating INT -> TERM -> KILL with
# bounded grace so it always dies (and cannot leave the Pi running hot). Idempotent.
stop_detector() {
  local d="${DET:-}" i
  [ -n "$d" ] || return 0
  kill -0 "$d" 2>/dev/null || return 0          # already gone
  kill -INT "$d" 2>/dev/null || true            # graceful; lets --save-output finish
  for i in 1 2 3 4 5; do kill -0 "$d" 2>/dev/null || return 0; sleep 1; done
  kill -TERM "$d" 2>/dev/null || true
  for i in 1 2 3; do kill -0 "$d" 2>/dev/null || return 0; sleep 1; done
  kill -KILL "$d" 2>/dev/null || true
}

# Any exit path (normal, die, errexit via ERR, Ctrl+C) tears the detector down, so
# it is never orphaned holding the camera / Hailo device.
trap 'rc=$?; printf "[hailo-demo] ERROR line %s (exit %s): %s\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR
trap 'stop_detector' EXIT
trap 'STOPPED_BY_US=1; log "interrupted - stopping detector"; stop_detector; exit 130' INT TERM

# keep any sourced ROS environment out of this process
unset ROS_DISTRO ROS_VERSION PYTHONPATH AMENT_PREFIX_PATH COLCON_PREFIX_PATH \
      CMAKE_PREFIX_PATH 2>/dev/null || true

# validate the optional duration and the numeric env knobs up front, so a bad
# override fails closed at startup instead of disabling a guard mid-run
if [ -n "$DURATION" ]; then
  [[ "$DURATION" =~ ^[1-9][0-9]*$ ]] || die "duration must be a positive integer (seconds), got '$DURATION'"
fi
[[ "$ABORT_MC" =~ ^[1-9][0-9]*$ ]]      || die "HAILO_DEMO_ABORT_MC must be a positive integer, got '$ABORT_MC'"
[[ "$POLL_S" =~ ^[1-9][0-9]*$ ]]        || die "HAILO_DEMO_POLL_S must be a positive integer, got '$POLL_S'"
[[ "$MAX_BAD_READS" =~ ^[1-9][0-9]*$ ]] || die "HAILO_DEMO_MAX_BAD_READS must be a positive integer, got '$MAX_BAD_READS'"
[[ "$GRACE_S" =~ ^(0|[1-9][0-9]*)$ ]]   || die "HAILO_DEMO_GRACE_S must be a non-negative integer without leading zeros, got '$GRACE_S'"
[[ "$FPS" =~ ^[1-9][0-9]*$ ]]           || die "HAILO_DEMO_FPS must be a positive integer, got '$FPS'"
[[ "$RES" =~ ^(sd|hd|fhd)$ ]]           || die "HAILO_DEMO_RES must be sd|hd|fhd, got '$RES'"
[[ "$OUTRES" =~ ^(sd|hd|fhd)$ ]]        || die "HAILO_DEMO_OUTRES must be sd|hd|fhd, got '$OUTRES'"

# preflight-lite: the Gate A setup must already exist under ROOT
[ -x "$VENV/bin/python" ]         || die "venv missing at $VENV (run Gate A setup first)"
[ -f "$HEF" ]                     || die "HEF missing at $HEF (run Gate A contract first)"
[ -f "$APP/object_detection.py" ] || die "runner missing at $APP"
[ -c /dev/hailo0 ]                || die "/dev/hailo0 not present"
[ -e "$CAM" ]                     || die "camera node $CAM not present"
[ -r "$THERMAL" ]                 || die "thermal sensor not readable at $THERMAL"

# refuse to start if the camera or the Hailo device is already in use; require
# fuser instead of silently skipping the ownership check (fail closed)
command -v fuser >/dev/null 2>&1 || die "fuser not found (install psmisc); needed for the camera/Hailo ownership check"
[ -z "$(fuser "$CAM" 2>/dev/null || true)" ]      || die "camera $CAM already in use"
[ -z "$(fuser /dev/hailo0 2>/dev/null || true)" ] || die "/dev/hailo0 already in use"

t0="$(cat "$THERMAL" 2>/dev/null || true)"
[[ "$t0" =~ ^[0-9]+$ ]] || die "unreadable thermal value '$t0'"
[ "$t0" -lt "$ABORT_MC" ] || die "already $((t0 / 1000)) C, at/above abort $((ABORT_MC / 1000)) C"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUTDIR="$OUTDIR/$RUN_ID"        # per-run dir so a later run cannot overwrite this output
mkdir -p "$OUTDIR" "$LOGDIR"
LOG="$LOGDIR/hailo_demo_$RUN_ID.log"

log "cam=$CAM res=$RES outres=$OUTRES fps=$FPS abort=$((ABORT_MC / 1000))C start=$((t0 / 1000))C dur=${DURATION:-until Ctrl+C}"

# build args; add the app-side time limit only when a duration was requested
args=(--hef-path "$HEF" --input "$CAM" --camera-resolution "$RES"
  --output-resolution "$OUTRES" --frame-rate "$FPS" --save-output --output-dir "$OUTDIR" --show-fps)
if [ -n "$DURATION" ]; then args+=(--time-to-run "$DURATION"); fi

# Launch in a subshell that resets INT/QUIT to default before exec, so the
# detector actually honours SIGINT (a plain background child inherits SIG_IGN in a
# non-interactive shell and would ignore Ctrl+C / kill -INT).
( trap - INT QUIT; exec "$VENV/bin/python" "$APP/object_detection.py" "${args[@]}" ) >"$LOG" 2>&1 &
DET=$!

# launcher-side hard deadline so a stuck init/teardown cannot run unbounded
deadline=0
if [ -n "$DURATION" ]; then deadline=$((SECONDS + DURATION + GRACE_S)); fi

log "detector PID $DET (live window opens on the desktop); watching temp every ${POLL_S}s, Ctrl+C to stop"
peak="$t0"
bad=0
while kill -0 "$DET" 2>/dev/null; do
  if [ "$deadline" -gt 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
    log "deadline reached (${DURATION}s + ${GRACE_S}s grace) - stopping detector"
    STOPPED_BY_US=1; stop_detector; break
  fi
  t="$(cat "$THERMAL" 2>/dev/null || true)"
  if ! [[ "$t" =~ ^[0-9]+$ ]]; then
    bad=$((bad + 1))
    log "bad thermal read '$t' ($bad/$MAX_BAD_READS)"
    if [ "$bad" -ge "$MAX_BAD_READS" ]; then
      log "ABORT: thermal sensor unreadable ${bad}x - stopping detector (fail-closed)"
      STOPPED_BY_US=1; stop_detector; break
    fi
    sleep "$POLL_S"; continue
  fi
  bad=0
  if [ "$t" -gt "$peak" ]; then peak="$t"; fi
  if [ "$t" -ge "$ABORT_MC" ]; then
    log "ABORT: $((t / 1000)) C >= $((ABORT_MC / 1000)) C - stopping detector"
    STOPPED_BY_US=1; stop_detector; break
  fi
  printf '[hailo-demo] temp=%sC peak=%sC\n' "$((t / 1000))" "$((peak / 1000))"
  sleep "$POLL_S"
done

# surface the detector's real exit status unless we stopped it on purpose
if wait "$DET"; then rc=0; else rc=$?; fi
if [ "$STOPPED_BY_US" = 1 ]; then
  log "stopped by watchdog/operator. peak $((peak / 1000)) C. log: $LOG  output: $OUTDIR"
elif [ "$rc" -eq 0 ]; then
  log "detector finished cleanly. peak $((peak / 1000)) C. log: $LOG  output: $OUTDIR"
else
  log "detector FAILED (exit $rc). peak $((peak / 1000)) C. see $LOG"
  exit "$rc"
fi
```

## Plugging In A Custom Detector

The stock model is a drop-in only because its HEF carries a **HailoRT
NMS-by-class** post-process output, so the runner gets final boxes with no host
decode (for `yolov11n` that NMS runs on the host CPU, `engine=cpu`; a `nms_core`
build runs it on the NPU core). A maritime or unicolor HEF reuses this exact runner
**only if** it is compiled with the same HailoRT NMS output contract. A HEF with
raw or multi-output heads (like
the earlier `yolo26n_route_a_six_heads.hef`) still needs a host-side decoder + NMS
and therefore a pipeline change — that path is tracked in the [Hailo HAT Workstream
Memo](Hailo_HAT_Workstream) accuracy gates, not here.

## Environment Gotchas

- **`vcgencmd get_throttled`** needs `/dev/vcio` access; on Ubuntu-for-Pi the login
  user is not in the `video` group, so read it through `sudo` (or add the group and
  re-login). A power / throttle check should degrade to a warning, never hard-abort
  a preflight.
- **RGB node** is `/dev/video4` here; auto-detect (`--input usb`) can grab depth or
  a Pi ISP node — always pass the mapped colour node explicitly.
- **Display** emits a benign `Ignoring XDG_SESSION_TYPE=wayland` notice and falls
  back to XWayland; the window still opens on the desktop session.

## Evidence

First proven on 10/07/2026: Gate B still (`bus 93.5%` + four `person` boxes) and a
bounded Gate C live run of `225` frames at `14.97 FPS` on `/dev/video4` at
`640x480`, plus a five-minute free-run holding about `65 C` (a single-session
observation, not a sustained-thermal qualification). Run summary in the
`working_diary/` entry for that date.

## Live Dashboard Integration

The standalone demo above now has a separate, external integration diagnostic
for publishing the annotated frame to the workstation dashboard while minimal
MAVROS telemetry remains view-only. Follow [Live Hailo and MAVROS Dashboard
Testing](Live_Hailo_MAVLink_Dashboard_Testing) for its service order, helper
checksum, safety boundary, pass markers, and shutdown sequence.

On 17/07/2026, two tracked-supervisor runs on `IoT IMT Nord Europe` reached the
six-topic arrival gate. During both runs, the operator confirmed the combined
stock-COCO overlay and MAVLink telemetry browser view. Automatic
probes measured the overlay at `7.40 Hz` and `7.50 Hz`; state, raw GPS, IMU,
battery, and RC were near `1 Hz`.
MAVROS stayed connected and disarmed, and the command sentinel observed zero
messages on its five monitored command topics. Pi thermal peaks were `68.3 C`
and `67.2 C`; both Pi run directories were copied back to the workstation.

In both runs the workstation dashboard stack became unavailable unexpectedly
before the intended Pi-first stop, without deliberate operator intervention.
Pi and workstation teardown markers passed fail-closed, but this is not the
required normal Pi-first operator shutdown. The cause, post-teardown
temperature, full endurance, optimized transport, GPS fix, custom-detector
calibration/accuracy/live integration, and every FCU write remain open.

That diagnostic does not replace or modify the canonical `hailo_coco_demo.sh`
procedure documented here.

## Explicit Non-Claims

- The following claims describe the standalone `hailo_coco_demo.sh` evidence
  above, not the separate live-dashboard diagnostic.
- Stock-COCO mechanics only; no maritime or custom-detector recovery, detector
  accuracy, or custom-HEF compatibility claim.
- No Hailo compile / calibration / Tier 3, no export, no deployment.
- No ROS image path, dashboard, MAVROS, QGC, Herelink, FCU, mission upload,
  arming, mode change, parameter write, thruster, or actuator work.
- No sustained-thermal qualification; the abort threshold is a safety guard, not an
  endurance rating.

## Navigation

- [Home](Home)
- [Live Hailo and MAVROS Dashboard Testing](Live_Hailo_MAVLink_Dashboard_Testing)
- [Hailo HAT Workstream Memo](Hailo_HAT_Workstream)
- [YOLO Dataset Plan](YOLO_Dataset_Plan)
- [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test)
