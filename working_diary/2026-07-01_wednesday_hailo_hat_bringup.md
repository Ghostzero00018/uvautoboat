# Wednesday 01/07/2026 - Hailo HAT Bring-Up

## Day Overview

Today's main task is to explore the mounted Raspberry Pi AI HAT+ 13 TOPS board
on the Pi 5, install only the software path that matches the live OS/package
state, and decide whether Hailo inference can later work with the RealSense
camera path.

Run the day as two parallel tracks:

1. Workstation-first model risk retirement: check whether the current custom
   checkpoint can reach a `hailo8l` HEF artifact.
2. Pi hardware/runtime bring-up: inspect the mounted board, gate on
   `apt-cache policy hailo-all`, and install only if the package branch is
   clear.

Do not make RealSense the first risk. RealSense source selection matters, but
the real early unknowns are the HEF compile path and the Pi OS/runtime package
line.

Expected starting repo state: `main` clean/synced at `46debb7` or later.

## Starting Context

- 30/06/2026 pushed commit:
  `46debb7 docs: record 30/06 telemetry sanity check`.
- Hailo memo commit:
  `9457cf3 docs: add Hailo HAT workstream memo`.
- `wiki/Hailo_HAT_Workstream.md` already frames Hailo as a separate
  accelerator branch, not a MAVProxy / MAVROS telemetry expansion.
- The mounted board is the Raspberry Pi AI HAT+ 13 TOPS variant, so the target
  accelerator architecture is `hailo8l` / Hailo-8L, not Hailo-8.
- The current boat Pi baseline in durable docs is Ubuntu 24.04 + ROS 2 Jazzy,
  but the live Pi must still be checked today because a reflash could change the
  OS/package branch.
- Existing custom model state is NCNN/CPU-side only. Hailo deployment needs a
  HEF compiled from an ONNX/Hailo toolchain path; do not reuse the current NCNN
  export as a Hailo artifact.
- The current custom checkpoint family is `yolo26n.pt`. Treat the first Hailo
  compile as a compatibility experiment because the documented Hailo examples
  assume a conventional NMS post-processing flow.
- The RealSense D435i path is proven as camera evidence through
  `/camera/camera/color/image_raw`, but RealSense USB `/dev/video<X>` input and
  ROS image-topic input are separate integration paths.

## Boundaries

- Markdown docs may be edited. Do not edit Python, YAML, launch files,
  JavaScript, package files, shell scripts, or helper code unless the user
  explicitly asks for that work.
- Pi install and live hardware commands are run on the box, then the pasted
  output is interpreted here.
- Do not run MAVProxy, MAVROS, QGC, Herelink, dashboard, real-FCU, arming,
  mission upload, mode change, parameter write, thruster, or actuator tests in
  this Hailo bring-up.
- Do not combine Hailo + RealSense + MAVROS today.
- Do not start RealSense until stock Hailo hardware/runtime verification passes.
- Do not install random Ubuntu repositories or mix unpinned Hailo driver/runtime
  packages. If the package branch is unclear, stop and record the blocker.
- Keep generated models, HEFs, calibration images, logs, and downloaded vendor
  artifacts outside the public repo.

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

- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md`
- `wiki/Hailo_HAT_Workstream.md`
- `working_diary/2026-06-30_tuesday_pi_mavproxy_wiring.md`
- `working_diary/2026-06-29_monday_workstation_prep.md`
- `Board.md`
- `wiki/YOLO_Dataset_Plan.md`

Record the exact starting SHA and whether a pull was needed.

## Block B - Live Pipeline Header

Use this header before running Pi-side Hailo commands.

- **Host + terminal:** Pi `imtaquadrone-desktop`, run by the user on the box.
  Use a new terminal for one-shot inspection and a separate new terminal for any
  foreground demo.
- **cwd + env:** start from `cd ~`. Do not source ROS for Hailo hardware/package
  checks. Source ROS only later if a ROS image-topic bridge is explicitly
  started.
- **Prereqs:** Pi 5 powered from a stable 5 V / 5 A path, Active Cooler fitted,
  AI HAT+ mounted and connected through the PCIe ribbon, RealSense plugged in
  only for later camera-source checks, no MAVROS / MAVProxy / YOLO / dashboard
  load.
- **Run + stop:** read-only hardware/package inspection first. Install only after
  the package branch is clear. Reboot when the selected Hailo install path
  requires it. Stop before RealSense if Hailo hardware/runtime verification
  fails.
- **After:** paste back the full inspection output, selected package branch,
  install result if run, reboot result, `hailortcli fw-control identify`, and any
  stock demo result.

## Block C - Workstation HEF Compile Risk

Purpose: retire the make-or-break model artifact risk without using bench time
on the Pi.

Run this on the x86_64 Linux workstation, not on the Pi:

Confirm these dataset paths first and adjust them if today's export workspace
differs.

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06

echo "=== source checkpoint ==="
test -f runs/baseline_yolo26n/weights/best.pt
ls -lh runs/baseline_yolo26n/weights/best.pt

echo "=== candidate calibration pool ==="
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | wc -l
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | head -20

echo "=== Hailo compile tooling ==="
command -v hailomz || true
command -v hailo || true
python3 --version
```

Interpretation:

- If Hailo compile tooling is absent, do not improvise from the Pi. Record that
  DFC/model-zoo tooling must be installed on the workstation before custom-model
  Hailo validation can proceed.
- If tooling exists, target `hailo8l` only. A `hailo8` HEF is the wrong device
  architecture for the 13 TOPS board.
- If the current `yolo26n.pt` path fails because of post-processing or end-node
  support, record it as a model-family compatibility finding. The fallback is to
  evaluate a conventional detection-head family such as YOLOv8 or YOLO11 for the
  Hailo branch, not to patch the Pi runtime first.
- Calibration images must come from the deployment domain. The current tiny split
  is enough for a compile mechanics experiment only, not detector quality.

Record:

- exact checkpoint path;
- exact Hailo tool versions if available;
- `hw_arch` used;
- whether ONNX export, parse, optimize/quantize, and HEF compile were reached;
- output HEF path if any;
- whether failure points to tooling, model family, calibration data, or device
  architecture.

## Block D - Pi Read-Only Hailo Inspection

Run on the Pi before any install:

```bash
cd ~

echo "=== host/os/kernel ==="
hostname
date '+%Y-%m-%d %H:%M:%S %Z'
cat /etc/os-release
uname -a
python3 --version

echo "=== power/thermal ==="
vcgencmd get_throttled || true
cat /sys/class/thermal/thermal_zone0/temp
sudo dmesg | grep -iE 'undervolt|throttl|voltage|pcie|hailo' | tail -80 || true

echo "=== Hailo hardware/runtime state ==="
command -v lspci && lspci -nn | grep -Ei 'hailo|accelerator|1e60' || true
ls -l /dev/hailo* 2>/dev/null || true
lsmod | grep -i hailo || true
modinfo hailo_pci 2>/dev/null | head -60 || true
command -v hailortcli || true
hailortcli fw-control identify 2>/dev/null || true

echo "=== package candidates ==="
apt-cache policy dkms hailo-all hailort hailo-dkms python3-hailort hailo-tappas-core
apt-cache policy linux-headers-$(uname -r) build-essential

echo "=== camera/process state ==="
lsusb -d 8086:0b3a || true
v4l2-ctl --list-devices 2>/dev/null || true
pgrep -af 'mavproxy|mavros|realsense|yolo|hailo|web_video|rosbridge' || true
```

Pass/fail hints:

- `lspci` should show vendor `1e60`; stale PCI IDs may show only the raw ID.
- `/dev/hailo0` is required for usable runtime access. `lspci` alone is not
  enough.
- `hailortcli fw-control identify` is the first clean runtime proof.
- `apt-cache policy hailo-all` is the real branch gate. Use the package
  candidate, not only the OS name.
- If `hailo-all` shows no candidate, run `sudo apt update` and re-check
  `apt-cache policy hailo-all` before deciding the package is genuinely absent.
  This refreshes package lists only; it does not install anything.

## Block E - Package Branch Decision

Choose exactly one branch from Block D.

### Branch E1 - Raspberry Pi Package Path

Use this only if `apt-cache policy hailo-all` returns a real candidate.

First refresh Raspberry Pi OS packages and firmware, then reboot:

```bash
cd ~
sudo apt update
sudo apt full-upgrade -y
sudo rpi-eeprom-update -a
sudo reboot
```

After reconnecting, install the Hailo package path and reboot again:

```bash
cd ~
sudo apt install dkms
sudo apt install hailo-all
sudo reboot
```

After the second reboot:

```bash
cd ~
hailortcli fw-control identify
ls -l /dev/hailo*
sudo dmesg | grep -i hailo | tail -80
```

Notes:

- `dkms` is required before `hailo-all`; otherwise PCIe enumeration can exist
  without a usable `/dev/hailo0`.
- Do not install the AI HAT+ 2 package path on the 13 TOPS board.

### Branch E2 - Ubuntu 24.04 Manual Path

Use this if the Pi is Ubuntu 24.04 / Jazzy and `hailo-all` has no candidate.
This is a stop-and-plan branch unless the exact Hailo package files and versions
are already available.

Before installing anything, verify:

```bash
cd ~
uname -r
apt-cache policy linux-headers-$(uname -r) build-essential dkms
python3 --version
```

Ubuntu gotchas to record before any install:

- The PCIe driver package is DKMS-based, so matching kernel headers and
  `build-essential` must exist before driver installation.
- Use a driver/runtime line that supports the Pi's current `linux-raspi` kernel.
  Treat drivers older than `4.19.0` as suspect on Ubuntu 24.04 unless today's
  vendor package notes prove otherwise.
- Ubuntu 24.04 / ROS 2 Jazzy uses Python 3.12. If the available Python binding is
  built for Python 3.11, keep it outside the ROS interpreter path and use a
  separate Python 3.11 environment for Hailo-only experiments.
- Pin one version line across driver, HailoRT, Python binding, firmware, and any
  post-processing package. Mismatched versions can produce driver/runtime
  incompatibility errors.
- Treat Ubuntu 24.04 as a self-supported boat branch. Do not replace the ROS 2
  Jazzy spine just to simplify Hailo.

Stop condition:

- If the exact versioned package set is not available, stop after recording the
  missing package/version evidence. Do not add random repositories.

### Branch E3 - Already Installed Path

Use this if Block D already shows `/dev/hailo0` and
`hailortcli fw-control identify` succeeds.

Record:

- driver version;
- firmware version;
- device architecture;
- package versions from `dpkg -l | grep -Ei 'hailo|tappas'`;
- whether `/dev/hailo0` persists after reboot.

Then proceed to stock HEF smoke only.

## Block F - Stock Hailo Smoke Before RealSense

Run only after Branch E1 or E3 proves Hailo runtime access.

Goal: prove the accelerator with a known-good `hailo8l` model before using the
project checkpoint or RealSense.

```bash
cd ~

echo "=== runtime ==="
hailortcli fw-control identify

echo "=== local HEF candidates ==="
find /usr/share /opt "$HOME" -iname '*.hef' 2>/dev/null | head -50
```

If a known `hailo8l` YOLO HEF is already installed, run the smallest available
stock example for a bounded time and record the command. If no HEF exists,
download or copy only a prebuilt `hailo8l` HEF from an approved source, such as
the Hailo Model Zoo compiled `hailo8l` model path; do not compile on the Pi.

Before running a HEF, inspect it if the installed CLI supports parsing:

```bash
HEF=/path/to/hailo8l_model.hef
hailortcli parse-hef "$HEF" 2>/dev/null || true
```

Bound the smoke run and capture post-load health evidence:

```bash
timeout 60s hailortcli benchmark "$HEF"
cat /sys/class/thermal/thermal_zone0/temp
sudo dmesg | tail -30
```

Pass evidence:

- model architecture is `hailo8l`;
- command starts and exits cleanly, or is stopped with `Ctrl+C` after visible
  inference output;
- temperature and `dmesg` stay clean.

## Block G - RealSense Source Probe

Run only after stock Hailo smoke passes.

This is still not ROS integration. It is only source-selection discovery for the
RealSense as a USB camera.

```bash
cd ~

echo "=== RealSense USB ==="
lsusb -d 8086:0b3a || true

echo "=== video devices ==="
v4l2-ctl --list-devices

echo "=== formats ==="
for dev in /dev/video*; do
  echo "===== $dev ====="
  v4l2-ctl -d "$dev" --list-formats-ext 2>/dev/null | sed -n '1,120p'
done
```

Interpretation:

- The RealSense exposes multiple nodes. Pick the color/UVC node, not depth, IR,
  or metadata.
- If the Hailo example accepts `/dev/video<X>`, use the specific color node
  rather than a generic `--input usb` if auto-detection chooses the wrong device.
- If format negotiation fails, record supported formats and caps; do not rewrite
  code today.
- ROS `/camera/camera/color/image_raw` is a separate path from USB
  `/dev/video<X>`. Do not collapse those results.

## Block H - Optional ROS Shape Decision

Do not implement a ROS node today unless explicitly approved later.

If Hailo runtime and RealSense source probing both pass, record the likely
future ROS shape:

```text
/camera/camera/color/image_raw
  -> cv_bridge / numpy frame
  -> HailoRT inference with a hailo8l HEF
  -> vision_msgs/Detection2DArray
```

Also record open design choices:

- USB camera pipeline versus ROS image-topic pipeline;
- project checkpoint compatibility versus fallback detector family;
- calibration image count and domain quality;
- whether Hailo post-processing should live in HailoRT, Python, or a GStreamer
  path;
- thermal/power budget before any combined camera + accelerator + telemetry
  run.

## Block I - Wrap

Update this diary with:

- repo guard outcome and starting SHA;
- workstation Hailo compile-tooling status;
- checkpoint and calibration source checked;
- Pi OS, kernel, Python version, and package branch;
- `lspci` / `/dev/hailo0` / `hailortcli` result;
- installed Hailo package versions, if any;
- stock HEF smoke result, if reached;
- RealSense `/dev/video<X>` color-node finding, if reached;
- explicit confirmation that MAVROS, QGC, Herelink, dashboard, real-FCU, and
  command/write paths stayed closed.

**Pipeline 1 outcome:** the read-only probe was copied to
`/home/ghostzero/Desktop/test_logs_folder/hailo_20260701_logs.txt` and reviewed
on 01/07/2026. The Pi is still Ubuntu 24.04.4 Noble with kernel
`6.8.0-1057-raspi` and Python `3.12.3`. The HAT is healthy at the PCIe layer:
kernel logs show gen-3 PCIe link-up at `8.0 GT/s` x1, and `lspci` reports
`0000:01:00.0` as Hailo `1e60:2864`. The device enumerates with the Hailo-8
PCI ID label; this is expected for the 13 TOPS Hailo-8L board, and the usable
device architecture must still be confirmed later through HailoRT / HEF tooling.
The x1 bandwidth note is informational for this HAT path, not an error.

No usable Hailo runtime was present in the probe: no `/dev/hailo*` node was
listed, no `hailortcli` output appeared, and the mistyped fallback `|| tru`
after `lsmod | grep -i hailo` produced a shell error only because no Hailo
module was found. The package cache showed `dkms` available, matching
`linux-headers-6.8.0-1057-raspi` available, and `build-essential` already
installed. It showed no output for `hailo-all`, `hailort`, `python3-hailort`, or
`hailo-tappas-core`, so the current evidence points to the Ubuntu/manual branch
unless `sudo apt update` plus a package-source check changes the package
candidate state.

Power evidence was acceptable for the read-only probe: temperature was `57.3 C`,
and the filtered `dmesg` output showed PCIe and storage voltage-switch messages
but no undervoltage or throttling event. `vcgencmd get_throttled` could not open
`/dev/vcio` on this Ubuntu image, so `dmesg` remains the useful power-history
source. RealSense was plugged in and visible as USB `8086:0b3a`, with
`/dev/video0` through `/dev/video5` listed for the RealSense device, but no
RealSense source test was run. The only process hit was the probe's own `tee`
command; no MAVROS, RealSense node, YOLO, dashboard, QGC, Herelink, or
command/write path was started.

The package-source re-check was run next:

```bash
sudo apt update
apt-cache policy hailo-all hailort python3-hailort hailo-tappas-core hailort-pcie-driver dkms linux-headers-$(uname -r) build-essential
grep -ri raspberrypi /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || echo "no raspberrypi apt source"
```

`apt update` reached only the RealSense, Ubuntu ports, and ROS 2 Noble sources;
all package lists were already current. The re-check still had no package for
`hailo-all`, `hailort`, `python3-hailort`, `hailo-tappas-core`, or
`hailort-pcie-driver`; `dkms` and the matching raspi kernel headers remained
available, and `build-essential` remained installed. The source grep returned
`no raspberrypi apt source`.

Decision: close E1 for this live Pi image. Today is the Ubuntu/manual E2 branch,
and it is a stop-and-plan branch until a version-pinned Hailo artifact set is
assembled offline. That set must account for kernel `6.8.0-1057-raspi`, Python
`3.12.3`, and a Hailo PCIe driver/runtime line new enough to create
`/dev/hailo0` on this kernel.

**Next steps:** E2 planning now lives in `wiki/Hailo_HAT_Workstream.md` (E2
Artifact Pin Sheet + version-line rule + `yolo26n.pt` compile routes). The next
work is offline: pin the Hailo 4.x artifact set and retire the `yolo26n.pt` ->
`hailo8l` HEF compile risk on the x86_64 workstation. No further Pi commands
until that set is assembled.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-07-01_wednesday_hailo_hat_bringup.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-01_wednesday_hailo_hat_bringup.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-01_wednesday_hailo_hat_bringup.md
```

Before committing, grep the staged diff for secrets, generated artifacts,
external package paths, or local-only notes that should not be public. End with
bounded next steps and no stale completed action.

Suggested commit subject for this evidence update:

```text
docs(diary): record 01/07 Hailo Pipeline 1, Ubuntu/manual branch
```
