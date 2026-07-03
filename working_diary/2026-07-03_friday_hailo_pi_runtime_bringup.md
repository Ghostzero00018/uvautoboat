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
sha256sum -c SHA256SUMS.txt || { echo "GATE-FAIL: payload checksum mismatch"; exit 1; }
cat INSTALL_ORDER.txt
ls -lh
```

## Block D - Pi Preflight Before Any Install

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  One-shot inspection only.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; do not source ROS.
- **Prereqs:** payload checksum passed; internet available if apt needs headers
  or build tools; Pi clock close enough for DNS/TLS/apt; no Hailo packages
  installed from a different line.
- **Run + stop:** inspect kernel, headers, disk, HAT PCIe, existing runtime, and
  package candidates. Stop before installing the driver if matching
  `linux-headers-$(uname -r)` is unavailable.
- **After:** paste full output, especially clock/NTP and kernel/header/DKMS
  lines.

Note: `vcgencmd` may be absent on Ubuntu. That is not a blocker by itself; the
command-not-found line is useful context, and the `dmesg` filter below remains
the power/throttle evidence source.

If the Pi boots with a stale clock, fix time before any apt-dependent step.
Record whether NTP repaired it or whether a one-time manual `timedatectl
set-time` was needed.

Clock repair fallback, only if the preflight shows stale time and NTP has not
settled yet. Stock Ubuntu 24.04 Desktop normally uses `systemd-timesyncd`; if
the preflight shows a different NTP client, stop and report that line instead of
guessing service commands.

```bash
timedatectl status --no-pager
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
sleep 10
timedatectl status --no-pager
```

If the Pi still cannot sync and internet access depends on correcting the
clock, use a one-time manual local-time set before re-enabling NTP:

```bash
sudo timedatectl set-ntp false
sudo timedatectl set-timezone Europe/Paris
sudo timedatectl set-time '2026-07-03 HH:MM:00'
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
timedatectl status --no-pager
```

Replace the date and `HH:MM` with the current local time before running the
manual command.

```bash
cd ~/pi_payload_2026-07-02

echo "=== time/network preflight ==="
date '+%Y-%m-%d %H:%M:%S %Z'
timedatectl status --no-pager
timedatectl show -p NTPSynchronized -p NTP -p Timezone
systemctl is-active systemd-timesyncd || true
timedatectl timesync-status || true
getent hosts ntp.ubuntu.com ports.ubuntu.com archive.ubuntu.com || true

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
- If clock/NTP is wrong enough to break `apt-cache` / `apt update`, stop and
  repair time first; do not treat header absence as real until apt metadata can
  be queried with a valid clock.
- If Hailo packages from a different version are already installed, stop and
  report before mixing.
- If disk is unexpectedly tight, stop before DKMS.

## Block E - Install Driver, Runtime, And Python Wheel

Only start if Block D proves matching headers/build tools are available.

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal.
  One-shot installs with reboot gates.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; do not source ROS.
- **Prereqs:** payload checksum passed, matching kernel headers present or apt
  candidate available, Pi clock valid for apt, stable power, no mixed Hailo
  version already installed.
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

sha256sum -c SHA256SUMS.txt || { echo "GATE-FAIL: payload checksum mismatch"; exit 1; }
hailortcli parse-hef "$HEF"
hailortcli --help | sed -n '1,120p'

if hailortcli --help | grep -Eq '(^|[[:space:]])run([[:space:]]|$)'; then
  timeout 60s hailortcli run "$HEF"
elif hailortcli --help | grep -Eq '(^|[[:space:]])benchmark([[:space:]]|$)'; then
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

## Session Evidence - 03/07/2026

Repo guard passed at the start of the session:

- `git fetch --prune` completed successfully.
- `main` matched `origin/main` at
  `05459e671e499863c1d609267642000d4d73d260`.
- `git status --short --branch` returned `## main...origin/main`.
- No pull was needed.

Block B workstation payload verification passed at 13:39 CEST:

- `/home/ghostzero/hailo_artifacts/2026-07-02/pi_payload_2026-07-02`
  passed `sha256sum -c SHA256SUMS.txt` for all five entries:
  `hailort_4.24.0_arm64.deb`,
  `hailort-4.24.0-cp312-cp312-linux_aarch64.whl`,
  `hailort-pcie-driver_4.24.0_all.deb`,
  `yolo26n_route_a_six_heads.hef`, and `INSTALL_ORDER.txt`.
- Payload directory size was `26M`.
- `pi_payload_2026-07-02.tar.gz` existed at `21M`.
- Tarball contents were exactly the payload directory plus:
  `INSTALL_ORDER.txt`, `SHA256SUMS.txt`,
  `hailort-4.24.0-cp312-cp312-linux_aarch64.whl`,
  `hailort-pcie-driver_4.24.0_all.deb`,
  `hailort_4.24.0_arm64.deb`, and
  `yolo26n_route_a_six_heads.hef`.

Block C transfer and Pi payload verification passed:

- Workstation transfer used
  `scp ... imt-aqua-drone@10.100.249.131:~/` and copied the `21M` payload
  successfully.
- On the Pi, `sha256sum -c SHA256SUMS.txt` passed for all five payload entries.
- `INSTALL_ORDER.txt` confirmed the intended install order:
  driver `.deb` -> runtime `.deb` -> cp312 aarch64 wheel, then firmware and
  `hailortcli` verification with `yolo26n_route_a_six_heads.hef`.
- Payload directory on the Pi was `26M` and contained only the expected three
  runtime artifacts, HEF, install-order file, and checksum file.

Block D Pi preflight passed the install gate:

- Hostname: `imtaquadrone-desktop`.
- Clock/network: local time was `03/07/2026 14:51 CEST`; timezone was
  `Europe/Paris`; NTP was enabled and `systemd-timesyncd` was active, but
  `NTPSynchronized=no` and packet count was `0`. DNS resolved
  `ntp.ubuntu.com`, `ports.ubuntu.com`, and `archive.ubuntu.com`, and
  `apt-cache policy` returned valid package metadata. The wall clock was
  already correct enough for apt, so the clock repair fallback was not needed
  before the install gate. If `sudo apt update` later fails on clock validity,
  repair time first rather than changing kernels.
- OS/kernel/Python: Ubuntu `24.04.4 LTS`, kernel `6.8.0-1060-raspi`,
  Python `3.12.3`. This is a drift from the historical 01/07 probe kernel
  `6.8.0-1057-raspi`; it is acceptable because the matching header candidate
  for the currently running `6.8.0-1060-raspi` kernel is available. Post-reboot
  proof must still confirm `uname -r` remains `6.8.0-1060-raspi`.
- Disk/memory: `/` had `36G` free on a `58G` filesystem; memory had `14Gi`
  available with `1.0Gi` swap unused.
- Thermal/power: CPU temperature was `58950` milli-C (`58.95 C`).
  `vcgencmd get_throttled` could not open `/dev/vcio`, which is not a blocker
  on this Ubuntu image. The filtered `dmesg` showed PCIe link-up and only the
  known boot-time MMC voltage-switch messages, not an undervoltage/throttle
  report.
- PCIe/HAT: `lspci` showed
  `Hailo Technologies Ltd. Hailo-8 AI Processor [1e60:2864] (rev 01)`;
  `dmesg` showed gen-3 x1 link-up at `8.0 GT/s` with `7.876 Gb/s` available
  bandwidth.
- Existing Hailo state: no `/dev/hailo*`, no loaded Hailo module, no
  `modinfo hailo_pci`, no `hailortcli`, and no installed `hailo` / `dkms`
  packages were reported. This preserves the clean manual-install starting
  point.
- Header/DKMS gate: `linux-headers-6.8.0-1060-raspi` was not installed, but
  candidate `6.8.0-1060.64` was available from
  `http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 Packages`.
  `dkms` candidate `3.0.11-1ubuntu13` was available; `build-essential`
  `12.10ubuntu1` and `python3-venv` `3.12.3-0ubuntu2.1` were already installed.

At this point, Block E was allowed to start from the prerequisite install step.
The running kernel was not changed before installing the matching
`linux-headers-6.8.0-1060-raspi` candidate.

Block E1 prerequisite install passed:

- `sudo apt update` succeeded with `APT_UPDATE_RC=0`. It reached
  `ports.ubuntu.com`, the RealSense apt source, and the ROS 2 apt source. Apt
  reported one unrelated package upgradable; no upgrade was run.
- `sudo apt install -y dkms build-essential linux-headers-$(uname -r)
  python3-venv` succeeded with `PREREQS_INSTALL_RC=0`.
- Installed new packages: `dkms` `3.0.11-1ubuntu13`,
  `linux-raspi-headers-6.8.0-1060` `6.8.0-1060.64`, and
  `linux-headers-6.8.0-1060-raspi` `6.8.0-1060.64`.
- Already present: `build-essential` `12.10ubuntu1` and `python3-venv`
  `3.12.3-0ubuntu2.1`.
- `uname -r` remained `6.8.0-1060-raspi` after the prerequisite install.
- `dkms status` was empty, as expected before installing the Hailo PCIe driver.

Block E2 driver install then proceeded from this prerequisite pass.

Block E2 driver install passed before reboot:

- `sudo apt install -y ./hailort-pcie-driver_4.24.0_all.deb` succeeded with
  `DRIVER_INSTALL_RC=0`.
- The installed package was `hailort-pcie-driver` `4.24.0`.
- The installer printed `Please reboot your computer for the installation to
  take effect.`
- Pre-reboot `uname -r` remained `6.8.0-1060-raspi`.
- Pre-reboot `dkms status` reported
  `hailo_pci/4.24.0, 6.8.0-1060-raspi, aarch64: installed`.
- Pre-reboot package list showed `dkms` `3.0.11-1ubuntu13`,
  `hailort-pcie-driver` `4.24.0`, and
  `linux-headers-6.8.0-1060-raspi` `6.8.0-1060.64`.

Block E3 post-reboot driver proof passed:

- Post-reboot time: `03/07/2026 16:20 CEST`.
- `uname -r` remained `6.8.0-1060-raspi`.
- `lspci` still showed
  `Hailo Technologies Ltd. Hailo-8 AI Processor [1e60:2864] (rev 01)`.
- `/dev/hailo0` existed as `crw-rw-rw-`, major/minor `234, 0`.
- `lsmod` showed `hailo_pci`.
- `modinfo hailo_pci` reported driver version `4.24.0`, module path
  `/lib/modules/6.8.0-1060-raspi/updates/dkms/hailo_pci.ko.zst`, and matching
  `vermagic` for `6.8.0-1060-raspi`.
- `dkms status` still reported
  `hailo_pci/4.24.0, 6.8.0-1060-raspi, aarch64: installed`.
- `dmesg` showed the expected out-of-tree / unsigned-module taint warnings,
  then clean probe/bind evidence on `0000:01:00.0`: driver version `4.24.0`,
  device enabled, BARs mapped, 64-bit DMA enabled, `hailo/hailo8_fw.bin`,
  `hailo/hailo8_board_cfg.bin`, and `hailo/hailo8_fw_cfg.bin` written
  successfully, `NNC Firmware loaded successfully`, and
  `Added board 1e60-2864, /dev/hailo0`.

The pinned PCIe driver and firmware path are proven at the device-node level.
Block E4 runtime and Python binding proof passed:

- `sudo apt install -y ./hailort_4.24.0_arm64.deb` succeeded with
  `RUNTIME_INSTALL_RC=0`.
- The installed runtime package was `hailort` `4.24.0`; it created the
  `hailort.service` systemd symlink.
- `command -v hailortcli` returned `/usr/bin/hailortcli`.
- `hailortcli --version` returned `HailoRT-CLI version 4.24.0`.
- `/lib/firmware/hailo/hailo8_fw.bin` existed as a symlink to
  `/lib/firmware/hailo/hailo8_fw.4.24.0.bin`.
- `/dev/hailo0` and the loaded `hailo_pci` module were still present.
- `hailortcli fw-control identify` succeeded with `FW_IDENTIFY_RC=0` and
  reported device `0000:01:00.0`, control protocol version `2`, firmware
  version `4.24.0`, and device architecture `HAILO8L`.
- Python venv `~/venvs/hailo-rt-4.24.0` was created, `pip` upgraded to
  `26.1.2`, and the cp312 aarch64 wheel installed `hailort-4.24.0` plus
  dependencies including `numpy`, `netaddr`, `netifaces`, `future`,
  `contextlib2`, and `argcomplete`.
- Python binding proof passed: the wheel install log ended with
  `Successfully installed ... hailort-4.24.0`, then
  `from hailo_platform import HEF` loaded `yolo26n_route_a_six_heads.hef`,
  printed `HEF_NAME_OK`, and returned `PYTHON_HEF_IMPORT_RC=0`. The echoed
  `PYHAILORT_INSTALL_RC=0` is not used as primary evidence because the pasted
  block did not refresh `rc` immediately after the wheel install.

The pinned runtime stack is installed and the device is proven through
`fw-control identify`.

Block F custom HEF static runtime smoke passed:

- Payload checksum was rechecked and all five entries still returned `OK`.
- `hailortcli parse-hef yolo26n_route_a_six_heads.hef` returned
  `PARSE_HEF_RC=0`.
- `parse-hef` confirmed architecture `HAILO8L`, network group
  `yolo26n_route_a_six_heads`, multi-context with `6` contexts, one input
  `UINT8` `NHWC(640x640x3)`, and six raw output vstreams:
  `conv61` `UINT16` `NHWC(80x80x4)`, `conv64` `UINT16` `FCR(80x80x5)`,
  `conv77` `UINT16` `NHWC(40x40x4)`, `conv80` `UINT16` `FCR(40x40x5)`,
  `conv91` `UINT16` `FCR(20x20x4)`, and `conv94` `UINT16` `FCR(20x20x5)`.
- The `HAILO8L` grep gate returned `PARSE_HEF_HAILO8L_GREP_RC=0`.
- `hailortcli --help` showed both `run` and `benchmark`; the bounded smoke used
  `hailortcli run`.
- Runtime smoke completed with `RUNTIME_SMOKE_CMD=run` and
  `RUNTIME_SMOKE_RC=0`. It ran streaming inference on the HEF with autogenerated
  quantized input, processed `293` frames, and reported `FPS: 58.22`,
  send rate `572.30 Mbit/s`, and receive rate `95.38 Mbit/s`.
- The Block F pasted output contained no HailoRT error / critical / assert
  lines. Post-smoke `dmesg` still showed the same clean probe / firmware-load
  tail from boot, with no new Hailo DMA or firmware fault in the pasted tail.

Success condition reached: the pinned runtime stack installed, `/dev/hailo0`
was proven, `fw-control identify` reported `HAILO8L`, and the custom
`yolo26n_route_a_six_heads.hef` ran as a bounded static smoke test on the
Hailo-8L device. This remains runtime mechanics only; it is not decode,
RealSense, ROS, dashboard, MAVROS, QGC, Herelink, mission, arming, mode-change,
parameter-write, thruster, actuator, or detector-quality evidence.

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
- runtime smoke output;
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
docs(diary): record 03/07 Hailo-8L Pi runtime install and HEF smoke
```
