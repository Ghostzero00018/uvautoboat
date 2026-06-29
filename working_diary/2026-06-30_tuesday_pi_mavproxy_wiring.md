# Tuesday 30/06/2026 - Pi MAVProxy Wiring Gate

## Day Overview

Continue from the pushed 29/06/2026 workstation wrap. The new `imgsz=320`
NCNN export exists on the workstation, but Tuesday starts with the Pi-side
MAVProxy wiring/heartbeat blocker. Do not copy or test the 320 export until
the `/dev/ttyAMA0:57600` heartbeat path is clean again and a separate thermal
block is explicitly approved.

Priority order:

1. Inspect physical power and wiring after the missing startup music/sound.
2. Confirm the flight-controller/peripheral side is powered.
3. Check `/dev/ttyAMA0` availability, ownership, and whether anything holds it.
4. Rerun the proven MAVProxy heartbeat topology on `/dev/ttyAMA0:57600`.
5. Launch MAVROS only after MAVProxy receives heartbeat.
6. Keep the 320 NCNN thermal comparison closed unless explicitly approved after
   the telemetry gate is clean.

Expected starting repo state: `main` clean/synced at `2b13457` or later.

## Starting Context

- 29/06/2026 pushed commit:
  `2b13457 docs: record 29/06 workstation export prep`.
- Monday created the separate workstation custom-model `imgsz=320` NCNN export:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/export_imgsz320/best_imgsz320_ncnn_model
```

- That export contains `model.ncnn.param`, `model.ncnn.bin`, `metadata.yaml`,
  and `model_ncnn.py`, and the workstation static smoke loaded it.
- Static smoke returned no detections on both validation images; the positive
  validation image had `2` labeled persons, so this remains a detector-quality
  warning, not an export-load failure.
- The 26/06/2026 late camera-off MAVProxy check opened `/dev/ttyAMA0:57600`
  but received no heartbeat and reported `link 1 down` after the box relaunched
  without the usual startup music/sound.
- The same `/dev/ttyAMA0:57600` path previously worked on 02/06 and 04/06:
  MAVProxy owned the serial link, fanned out to UDP `14550` and `14551`, and
  MAVROS `apm.launch` with `fcu_url:=udp://127.0.0.1:14550@` reached
  `/mavros/state connected: true`.
- The leading hypothesis is physical power/wiring, not a software route
  regression. The Pi also has prior undervoltage history, so power evidence must
  be checked before reseating or concluding wiring failure.

## Boundaries

- This is a Pi hardware/telemetry day, not a YOLO day.
- The user runs the Pi commands on the box; do not run MAVProxy, MAVROS,
  RealSense, QGC, Herelink, dashboard, or real-FCU tests from the agent side.
- Do not arm, upload missions, change modes, write parameters, or send actuator
  commands.
- Do not start RealSense, YOLO inference, dashboard, QGC, Herelink, or any
  combined-load block during the MAVProxy/MAVROS gate.
- Do not copy or test the 320 NCNN export until the heartbeat/MAVROS gate is
  clean and the user explicitly starts that later thermal block.
- Keep MAVProxy as the sole serial owner. Do not run the bounded MAVProxy probe
  and a persistent MAVProxy instance at the same time.

## Block A - Repo Guard And Source Read

Run first from the workstation repo root:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Guard:

- If `git fetch --prune` fails while on normal internet WiFi, stop and report.
- If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- If ahead, diverged, or dirty, stop and report before continuing.

Read first:

- `working_diary/2026-06-30_tuesday_pi_mavproxy_wiring.md`
- `working_diary/2026-06-29_monday_workstation_prep.md`
- `working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md`
- `Board.md`
- `wiki/Roadmap.md`

Record the exact starting SHA and whether a pull was needed.

## Block B - Live Pipeline Header

Use this header before running the hardware pipeline.

- **Host + terminal:** Pi `imtaquadrone-desktop`, run by the user on the box.
  Use new terminals. Do not run this from the agent side.
- **cwd + env:** start from `cd ~`. MAVProxy preflight does not need ROS
  sourcing. MAVROS only starts later, after MAVProxy heartbeat.
- **Prereqs:** control box powered, Pi booted, no RealSense / YOLO / dashboard
  load needed. Keep the new 320 NCNN export on the workstation for now.
- **Run + stop:** first run one-shot diagnostics, then physical inspection,
  then a bounded MAVProxy heartbeat probe. Stop before MAVROS if no heartbeat.
- **After:** paste back the full diagnostic output, MAVProxy heartbeat/failure
  lines, and `/mavros/state` if MAVROS is reached.

## Block C - Terminal 1 Pi Preflight

Run on the Pi:

```bash
cd ~

echo "=== host/time ==="
hostname
date '+%Y-%m-%d %H:%M:%S %Z'

echo "=== power/thermal ==="
vcgencmd get_throttled || true
cat /sys/class/thermal/thermal_zone0/temp

echo "=== undervoltage history (authoritative on this Pi) ==="
sudo dmesg | grep -iE 'undervolt|throttl|voltage' | tail -20 || true

echo "=== serial path ==="
ls -l /dev/ttyAMA0 || true
groups
id -nG
sudo fuser -v /dev/ttyAMA0 || true

echo "=== mavproxy/tools ==="
command -v mavproxy.py || true
mavproxy.py --version || true

echo "=== conflicting processes/listeners ==="
pgrep -af 'mavproxy|mavros|realsense|yolo|web_video|rosbridge' || true
ss -lunp | grep -E ':(14550|14551|14540|5760)\b' || true
```

Interpretation before touching cables:

- `throttled=0x0` is clean if `vcgencmd` is available.
- Any nonzero `vcgencmd get_throttled` value means under-voltage or throttle
  history/active trouble.
- Kernel `dmesg` voltage/throttle lines are the more authoritative power check
  on this Ubuntu Pi image.
- `/dev/ttyAMA0` must exist.
- `groups` / `id -nG` should include `dialout`.
- `sudo fuser -v /dev/ttyAMA0` should show nothing holding the port.

Then inspect physically:

1. Flight-controller/peripheral power LED.
2. Startup buzzer/sound behavior.
3. `/dev/ttyAMA0` connector path and seating.

## Block D - Terminal 2 Bounded MAVProxy Probe

Run only after Block C and the physical inspection.

```bash
cd ~

timeout 75s mavproxy.py \
  --master=/dev/ttyAMA0 \
  --baudrate 57600 \
  --out=udpout:127.0.0.1:14550 \
  --out=udpout:127.0.0.1:14551
```

Pass evidence:

- `Detected vehicle 1:1`
- `online system 1`
- heartbeat/status text

Known cleanup caveat: ignore a MAVProxy cleanup crash/core-dump after useful
heartbeat evidence. Judge the probe by whether heartbeat / vehicle-online
evidence appeared before exit.

Stop condition:

- If it stays at `Waiting for heartbeat from /dev/ttyAMA0` and then reports
  `link 1 down`, stop. Do not launch MAVROS.

Footgun:

- Do not start a persistent MAVProxy instance in another terminal while the
  bounded probe is still running. The two processes will fight over
  `/dev/ttyAMA0`, and the second will fail with a device-busy error.

## Block E - Keep MAVProxy Running Only If Heartbeat Passes

Run only after Block D passes. Use the same Terminal 2 after the bounded probe
has exited or after stopping it with `Ctrl+C`.

```bash
cd ~

mavproxy.py \
  --master=/dev/ttyAMA0 \
  --baudrate 57600 \
  --out=udpout:127.0.0.1:14550 \
  --out=udpout:127.0.0.1:14551
```

Leave this foregrounded. MAVProxy remains the serial owner.

## Block F - Terminal 3 MAVROS Gate

Run only after Terminal 2 has heartbeat and the persistent MAVProxy fanout is
running.

```bash
cd ~
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12

ros2 launch mavros apm.launch fcu_url:=udp://127.0.0.1:14550@
```

Wait in Terminal 3 for:

```text
CON: Got HEARTBEAT, connected. FCU: ArduPilot
```

Then query from a separate terminal, not from the foreground MAVROS terminal:

```bash
cd ~
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12

timeout 20s ros2 topic echo /mavros/state --once
ros2 topic list | grep '^/mavros/' | wc -l
```

Pass condition:

- `/mavros/state` shows `connected: true`.

Stop after the read-only state check. Do not proceed to 320 NCNN copy/testing
inside this block.

## Block G - Optional 320 NCNN Thermal Block

Do not start this block unless all are true:

- Block D receives MAVProxy heartbeat.
- Block F shows `/mavros/state connected: true`.
- The user explicitly approves copying/testing the new `imgsz=320` NCNN export.

If approved later, use the workstation export path:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/export_imgsz320/best_imgsz320_ncnn_model
```

The thermal block must be short, bounded, headless, and separate from the
MAVProxy/MAVROS wiring gate.

## Block H - Wrap

Update this diary with:

- Repo guard outcome and starting SHA.
- Pi preflight output summary, especially power/throttle and `/dev/ttyAMA0`
  state.
- Physical inspection outcome: FC/peripheral power LED, startup sound, and
  connector seating.
- MAVProxy heartbeat result, including exact pass/fail lines.
- Whether MAVROS was launched, and why.
- `/mavros/state` result if reached.
- Confirmation that 320 NCNN copy/test was skipped unless explicitly approved.
- Bounded next steps.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-06-30_tuesday_pi_mavproxy_wiring.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-30_tuesday_pi_mavproxy_wiring.md
rg -n "\[[[:space:]]\]" working_diary/2026-06-30_tuesday_pi_mavproxy_wiring.md
```

Run the standard public-repo visibility sweep before committing. End with
bounded next steps and no stale completed action.

Suggested commit subject for this scaffold:

```text
docs(diary): scaffold 30/06 MAVProxy wiring gate
```
