# Friday 03/07/2026 - Hailo Pi Runtime Bring-Up

## Day Overview

Today is the first Pi-side Hailo runtime session for the Raspberry Pi AI HAT+
13 TOPS / Hailo-8L board. The workstation compile gate is closed: Route A
produced a valid `hailo8l` HEF, and the Pi-bound runtime payload is staged
outside the repo.

Success today is not live RealSense detection. Success is one of:

1. the Pi installs the pinned HailoRT `4.24.0` runtime stack and proves the
   device with exact evidence;
2. the custom `yolo26n_route_a_six_heads.hef` runs as a bounded runtime smoke
   test on the Hailo-8L device; or
3. the install/runtime blocks with a precise failure, most likely at the
   kernel-header / DKMS gate.

Decode, saved-frame inference, live ROS image input, dashboard integration,
MAVROS, QGC, Herelink, mission upload, arming, mode change, parameter write,
thruster, and actuator work stay out of scope unless explicitly reopened after
the runtime smoke gate passes.

## Starting Context

- Repo is expected clean and pushed at `b6fe508` or later.
- `b57d40a docs(diary): record 02/07 Hailo Route A HEF` recorded the successful
  workstation compile.
- `b6fe508 docs(wiki): update Hailo Pi HEF smoke gate` recorded the
  `hailo8` vs `hailo8l` stock-HEF caveat.
- Official pinned runtime row is HailoRT / driver / pyHailoRT `4.24.0`, with
  DFC `3.34.0` and Model Zoo `2.19.0` already used on the workstation.
- 01/07/2026 Pi probe: Ubuntu 24.04.4, kernel `6.8.0-1057-raspi`, Python
  `3.12.3`, Hailo PCIe device `1e60:2864`, gen-3 x1 link-up, but no
  `/dev/hailo*`, no `hailortcli`, no runtime packages.
- 02/07/2026 workstation compile: `yolo26n_route_a_six_heads.hef` parsed as
  `HAILO8L`, with one `UINT8` `NHWC(640x640x3)` input and six raw output
  vstreams. There is no embedded NMS.
- Pi payload is staged at:

```text
/home/ghostzero/hailo_artifacts/2026-07-02/pi_payload_2026-07-02.tar.gz
```

Payload contents:

```text
hailort-pcie-driver_4.24.0_all.deb
hailort_4.24.0_arm64.deb
hailort-4.24.0-cp312-cp312-linux_aarch64.whl
yolo26n_route_a_six_heads.hef
INSTALL_ORDER.txt
SHA256SUMS.txt
```

Known checksums:

```text
3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b  hailort-pcie-driver_4.24.0_all.deb
9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6  hailort_4.24.0_arm64.deb
72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d  hailort-4.24.0-cp312-cp312-linux_aarch64.whl
edc03c3ca099167970ea0b851af7eea892c76b81aceabfb5a54e9ec46afb932d  yolo26n_route_a_six_heads.hef
```

## Boundaries

- The user runs Pi commands in a real Pi terminal and pastes output back for
  interpretation.
- Do not compile on the Pi.
- Do not use any Hailo 5.x artifact. This board stays on the HailoRT 4.x
  (`hailo8`-family firmware) line and compiles HEFs for `hailo8l`.
- Do not copy package files, HEFs, logs, or payload tarballs into the repo.
- Do not use bundled software-suite HEFs as Pi smoke tests unless `parse-hef`
  proves `HAILO8L`; the inspected bundled suite HEFs were `HAILO8`.
- Keep stock `hailo8l` HEF generation/fetch as a later deliberate network task.

## Block A - Repo Guard And Source Read

Run first on the workstation from the repo root:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -6
git status --short --branch
git rev-parse HEAD origin/main
```

Guard:

- If fetch fails, stop and report.
- If behind `origin/main`, run `git pull --ff-only`, then re-check.
- If ahead, diverged, or dirty, stop and report before Pi work.

Read first:

- `working_diary/2026-07-03_friday_hailo_pi_runtime_bringup.md`
- `working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md`
- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md`
- `wiki/Hailo_HAT_Workstream.md`
- `wiki/YOLO_Dataset_Plan.md`
- `Board.md`

## Block B - Workstation Payload Check

Purpose: prove the Pi payload is still intact before transferring it.

Run on the workstation:

```bash
cd /home/ghostzero/hailo_artifacts/2026-07-02/pi_payload_2026-07-02
sha256sum -c SHA256SUMS.txt
ls -lh

cd ..
ls -lh pi_payload_2026-07-02.tar.gz
tar -tzf pi_payload_2026-07-02.tar.gz | sort
```

Expected:

- all checksum entries report `OK`;
- tarball exists and is around 21M;
- payload contains only the three runtime artifacts, the custom HEF, manifest,
  and checksum file.

Stop if any checksum fails.

## Block C - Transfer And Unpack On The Pi

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  Use a new one-shot terminal for unpack and package inspection.
- **cwd + env:** start from `cd ~`. Do not source ROS.
- **Prereqs:** Pi on stable 5 V / 5 A power, Active Cooler fitted, AI HAT+
  mounted, no MAVProxy / MAVROS / RealSense / YOLO / dashboard load.
- **Run + stop:** copy the tarball to the Pi, unpack, verify checksums. Stop on
  any checksum mismatch.
- **After:** paste the checksum result and `ls -lh` output.

Copy method is flexible. Example from the workstation:

```bash
scp /home/ghostzero/hailo_artifacts/2026-07-02/pi_payload_2026-07-02.tar.gz \
  imtaquadrone-desktop:~/
```

Then on the Pi:

```bash
cd ~
tar -xzf pi_payload_2026-07-02.tar.gz
cd pi_payload_2026-07-02
sha256sum -c SHA256SUMS.txt
cat INSTALL_ORDER.txt
ls -lh
```

## Block D - Pi Preflight Before Any Install

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  One-shot inspection only.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; do not source ROS.
- **Prereqs:** payload checksum passed; internet available if apt needs headers
  or build tools; no Hailo packages installed from a different line.
- **Run + stop:** inspect kernel, headers, disk, HAT PCIe, existing runtime, and
  package candidates. Stop before installing the driver if matching
  `linux-headers-$(uname -r)` is unavailable.
- **After:** paste full output, especially kernel/header/DKMS lines.

```bash
cd ~/pi_payload_2026-07-02

echo "=== host/os/kernel ==="
hostname
date '+%Y-%m-%d %H:%M:%S %Z'
cat /etc/os-release
uname -a
uname -r
python3 --version

echo "=== disk/memory/power ==="
df -h ~ /tmp /
free -h
vcgencmd get_throttled || true
cat /sys/class/thermal/thermal_zone0/temp
sudo dmesg | grep -iE 'undervolt|throttl|voltage|pcie|hailo' | tail -80 || true

echo "=== existing Hailo state ==="
lspci -nn | grep -Ei 'hailo|1e60' || true
ls -l /dev/hailo* 2>/dev/null || true
lsmod | grep -i hailo || true
modinfo hailo_pci 2>/dev/null | head -80 || true
command -v hailortcli || true
dpkg -l | grep -Ei 'hailo|dkms' || true

echo "=== header/build package candidates ==="
apt-cache policy linux-headers-$(uname -r) dkms build-essential python3-venv
```

Gate:

- If `linux-headers-$(uname -r)` has no installed version and no candidate,
  stop. Do not install the driver.
- If Hailo packages from a different version are already installed, stop and
  report before mixing.
- If disk is unexpectedly tight, stop before DKMS.

## Block E - Install Driver, Runtime, And Python Wheel

Only start if Block D proves matching headers/build tools are available.

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  One-shot installs with reboot gates.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; do not source ROS.
- **Prereqs:** payload checksum passed, matching kernel headers present or apt
  candidate available, stable power, no mixed Hailo version already installed.
- **Run + stop:** install prerequisites, install the PCIe driver `.deb`, reboot,
  then verify `/dev/hailo*` before installing runtime and the wheel. Stop on any
  DKMS/build error.
- **After:** paste install output tail, reboot verification output, and runtime
  version output.

Prerequisites:

```bash
cd ~/pi_payload_2026-07-02
sudo apt update
sudo apt install -y dkms build-essential linux-headers-$(uname -r) python3-venv
```

Driver:

```bash
cd ~/pi_payload_2026-07-02
sudo apt install -y ./hailort-pcie-driver_4.24.0_all.deb
sudo reboot
```

After reconnecting:

```bash
cd ~/pi_payload_2026-07-02
lspci -nn | grep -Ei 'hailo|1e60' || true
ls -l /dev/hailo*
lsmod | grep -i hailo
modinfo hailo_pci | head -80
sudo dmesg | grep -i hailo | tail -80
```

Runtime and Python binding:

```bash
cd ~/pi_payload_2026-07-02
sudo apt install -y ./hailort_4.24.0_arm64.deb

python3 -m venv ~/venvs/hailo-rt-4.24.0
source ~/venvs/hailo-rt-4.24.0/bin/activate
python -m pip install --upgrade pip
python -m pip install ./hailort-4.24.0-cp312-cp312-linux_aarch64.whl

command -v hailortcli
hailortcli --version || true
hailortcli fw-control identify
ls -lh /lib/firmware/hailo/hailo8_fw.bin
python - <<'PY'
from hailo_platform import HEF
hef = HEF("yolo26n_route_a_six_heads.hef")
print("HEF_NAME_OK")
PY
```

If the Python wheel import fails but `hailortcli` and `/dev/hailo*` are good,
record it as a Python binding issue. Do not reinstall the driver repeatedly.

## Block F - Custom HEF Static Runtime Smoke

Only start if Block E proves `hailortcli fw-control identify` works.

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  One-shot static HEF inspection and bounded runtime smoke.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; source
  `~/venvs/hailo-rt-4.24.0/bin/activate` only if using Python checks.
- **Prereqs:** `/dev/hailo*` exists, firmware file exists, `hailortcli`
  identifies the device, custom HEF checksum passed.
- **Run + stop:** parse the HEF, then run the smallest available bounded
  HailoRT execution command. Stop after static runtime proof; do not start
  decode, RealSense, ROS, dashboard, MAVROS, QGC, or Herelink.
- **After:** paste parse output, runtime output, and post-run `dmesg` tail.

```bash
cd ~/pi_payload_2026-07-02
HEF=yolo26n_route_a_six_heads.hef

sha256sum -c SHA256SUMS.txt
hailortcli parse-hef "$HEF"
hailortcli --help | sed -n '1,120p'

if hailortcli --help | grep -q ' run'; then
  timeout 60s hailortcli run "$HEF"
elif hailortcli --help | grep -q ' benchmark'; then
  timeout 60s hailortcli benchmark "$HEF"
else
  echo "No run/benchmark subcommand shown; stop after parse-hef and identify."
fi

sudo dmesg | grep -i hailo | tail -80
```

Expected `parse-hef` architecture:

```text
Architecture HEF was compiled for: HAILO8L
```

Expected output contract:

```text
Input:  UINT8 NHWC(640x640x3)
Output: conv61 UINT16 NHWC(80x80x4)
Output: conv64 UINT16 FCR(80x80x5)
Output: conv77 UINT16 NHWC(40x40x4)
Output: conv80 UINT16 FCR(40x40x5)
Output: conv91 UINT16 FCR(20x20x4)
Output: conv94 UINT16 FCR(20x20x5)
```

This proves runtime mechanics only. It does not prove detector quality or
decode correctness.

## Block G - Wrap

Update this diary with:

- repo guard result and starting SHA;
- payload checksum result;
- Pi OS/kernel/Python state;
- header/DKMS preflight result;
- install commands that actually ran;
- DKMS outcome and any reboot result;
- `/dev/hailo*`, firmware, `hailortcli`, and Python binding status;
- `fw-control identify` result;
- HEF `parse-hef` result;
- runtime smoke output, if reached;
- exact blocker if stopped.

Before a diary commit, run:

```bash
git status --short --branch
git diff --check
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-03_friday_hailo_pi_runtime_bringup.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-03_friday_hailo_pi_runtime_bringup.md
```

Suggested commit subject:

```text
docs: add 03/07 Hailo runtime handoff
```
