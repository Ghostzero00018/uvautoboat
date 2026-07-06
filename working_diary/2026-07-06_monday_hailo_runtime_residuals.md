# Monday 06/07/2026 - Hailo Runtime Installation Residuals

## Day Overview

Monday is a post-install hygiene day for the Raspberry Pi AI HAT+ 13 TOPS /
Hailo-8L runtime stack. The 03/07/2026 milestone is already closed: the pinned
HailoRT / driver / pyHailoRT `4.24.0` stack installed on the Pi, `/dev/hailo0`
was proven, `fw-control identify` reported `HAILO8L`, and
`hailortcli run yolo26n_route_a_six_heads.hef` completed `293` frames at
`58.22 FPS`.

Success on Monday is not a new detector milestone. Success is one of:

1. the installed Hailo stack survives a fresh Pi boot and the package, DKMS,
   firmware, CLI, and Python-binding inventory is captured cleanly;
2. a small residual install issue is found and documented with exact evidence;
3. the session stops with a precise blocker, without repeated reinstall churn.

## Starting Context

- Expected starting repo state: `main == origin/main` at
  `e51b318b5a72089b1175f9bd703f4b4a91a859ac` or later.
- The 03/07/2026 diary recorded the runtime proof and the bounded custom HEF
  smoke.
- Durable milestone docs updated on 03/07/2026:
  `Board.md`, `wiki/Hailo_HAT_Workstream.md`, and `wiki/Roadmap.md`.
- The 06/07 scaffold also retouches `wiki/Hailo_HAT_Workstream.md` and
  `wiki/Home.md` so they point at the proven runtime baseline and next
  integration gates rather than the pre-smoke bring-up order.
- Pi runtime row remains pinned at:
  `hailort-pcie-driver` `4.24.0`, `hailort` `4.24.0`, and pyHailoRT
  `4.24.0`.
- The 03/07 install ran on Ubuntu `24.04.4 LTS`, kernel
  `6.8.0-1060-raspi`, Python `3.12.3`, with matching headers
  `linux-headers-6.8.0-1060-raspi` `6.8.0-1060.64`.
- The custom HEF remains `yolo26n_route_a_six_heads.hef`, compiled for
  `HAILO8L`, one `UINT8` `NHWC(640x640x3)` input, and six raw output vstreams.

## Boundaries

- User runs all Pi commands in a real Pi terminal and pastes output back.
- This is residual runtime-installation proof only.
- Do not compile on the Pi.
- Do not run decode, saved-frame inference, live RealSense, ROS image input,
  dashboard integration, MAVROS, QGC, Herelink, mission upload, arming,
  mode change, parameter write, thruster, or actuator work.
- Do not run `apt upgrade`, kernel upgrades, or a reboot to chase a different
  kernel unless explicitly approved.
- Do not reinstall Hailo packages unless a specific residual install defect is
  proven and the user explicitly reopens repair.
- Keep logs, HEFs, packages, and payload tarballs outside the repo.

## Block A - Repo Guard And Source Read

Run first on the workstation:

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

- `working_diary/2026-07-06_monday_hailo_runtime_residuals.md`
- `working_diary/2026-07-03_friday_hailo_pi_runtime_bringup.md`
- `working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md`
- `wiki/Hailo_HAT_Workstream.md`
- `wiki/Roadmap.md`
- `Board.md`

Record the starting SHA and whether a pull was needed.

## Block B - Pi Cold-Boot Install Inventory

Purpose: prove the installed stack is still coherent after a normal boot,
without reinstalling anything.

- **Host + terminal:** Pi `imtaquadrone-desktop`, user-run real Pi terminal,
  one-shot read-only inventory.
- **cwd + env:** `cd ~/pi_payload_2026-07-02`; do not source ROS.
- **Prereqs:** Pi has actually been power-cycled or rebooted since the
  03/07/2026 session. If it has been running continuously, perform one normal
  reboot before Block B so this is a real cold-boot survival check. This is a
  same-stack reboot, not a kernel-chase; do not run `apt upgrade` or install a
  new kernel. Clock is close enough for logs and apt metadata reads; no install
  commands in this block.
- **Run + stop:** collect time, boot timestamp, kernel, packages, DKMS, apt
  policy, service, and hold-state evidence. Stop if the boot timestamp predates
  the 03/07/2026 session, kernel drifted away from the installed DKMS
  target or mixed Hailo packages appear.
- **After:** paste the full output.

```bash
cd ~/pi_payload_2026-07-02
mkdir -p ~/hailo_runtime_logs_20260706

{
  echo "=== time/kernel/python ==="
  date '+%Y-%m-%d %H:%M:%S %Z'
  uptime -s
  uptime -p
  timedatectl status --no-pager
  uname -a
  uname -r
  python3 --version

  echo "=== installed packages ==="
  dpkg -l | grep -Ei "hailo|dkms|linux-headers-$(uname -r)|python3-venv|build-essential" || true

  echo "=== apt policy read-only ==="
  apt-cache policy hailort hailort-pcie-driver "linux-headers-$(uname -r)" dkms python3-venv || true

  echo "=== package holds ==="
  apt-mark showhold | grep -Ei 'hailo|linux|dkms' || true

  echo "=== hailort service ==="
  systemctl is-enabled hailort.service || true
  systemctl is-active hailort.service || true
  systemctl status hailort.service --no-pager || true
} 2>&1 | tee ~/hailo_runtime_logs_20260706/block_b_install_inventory.log
```

Gate:

- If `uname -r` is no longer `6.8.0-1060-raspi`, stop and report before trying
  any repair.
- If `uptime -s` predates the 03/07/2026 session, stop before treating this as
  cold-boot survival evidence.
- If `dkms status` later shows no module for the running kernel, stop and
  diagnose from the package/kernel evidence.
- If any Hailo package is not `4.24.0`, stop and report the mixed-version state.

## Block C - Device, Module, Firmware, And Fault Scan

Purpose: prove the PCIe device, loaded module, firmware files, and device node
still exist after the cold boot, with the broader fault scan that was identified
after the 03/07 smoke pass.

```bash
cd ~/pi_payload_2026-07-02
mkdir -p ~/hailo_runtime_logs_20260706

{
  echo "=== PCIe device ==="
  lspci -nn | grep -Ei 'hailo|1e60' || true

  echo "=== device node ==="
  ls -l /dev/hailo*

  echo "=== loaded module ==="
  lsmod | grep -i hailo

  echo "=== module info ==="
  modinfo hailo_pci | head -80

  echo "=== dkms status ==="
  dkms status || true

  echo "=== firmware files ==="
  ls -lh /lib/firmware/hailo/ || true

  echo "=== broad kernel fault scan ==="
  sudo dmesg | grep -iE 'hailo|aer|dmar|dma|call trace|oops' | tail -160
} 2>&1 | tee ~/hailo_runtime_logs_20260706/block_c_device_module_firmware.log
```

Gate:

- `/dev/hailo0`, `hailo_pci`, `modinfo hailo_pci` version `4.24.0`, and a
  DKMS entry for the running kernel must all be present before moving on.
- If the broad fault scan shows DMA, PCIe AER, firmware assert, call trace, or
  oops lines, stop and paste the exact tail before retrying anything.

## Block D - Runtime CLI And Python Binding Recheck

Purpose: prove the runtime userland and Python binding still load against the
installed stack.

```bash
cd ~/pi_payload_2026-07-02
mkdir -p ~/hailo_runtime_logs_20260706

{
  echo "=== hailortcli ==="
  command -v hailortcli
  hailortcli --version
  hailortcli fw-control identify
} 2>&1 | tee ~/hailo_runtime_logs_20260706/block_d_hailortcli_identify.log
rc=${PIPESTATUS[0]}
echo "FW_IDENTIFY_RC=$rc"
if [ "$rc" -ne 0 ]; then echo "STOP: fw-control identify failed"; exit "$rc"; fi

source ~/venvs/hailo-rt-4.24.0/bin/activate
{
  echo "=== python binding ==="
  python - <<'PY'
from hailo_platform import HEF
hef = HEF("yolo26n_route_a_six_heads.hef")
print("HEF_NAME_OK")
PY
} 2>&1 | tee ~/hailo_runtime_logs_20260706/block_d_python_binding.log
rc=${PIPESTATUS[0]}
echo "PYTHON_HEF_IMPORT_RC=$rc"
if [ "$rc" -ne 0 ]; then echo "STOP: Python HEF import failed"; exit "$rc"; fi
```

Gate:

- If `fw-control identify` fails, do not reinstall first. Use Blocks B/C logs to
  decide whether this is driver, firmware, service, device, or userland drift.
- If Python import fails while CLI/device proof passes, record it as a Python
  binding or venv issue only.

## Block E - Optional Bounded Repeat Smoke

Run this only if Blocks B-D pass and the user explicitly wants a cold-boot
runtime repeat. This remains mechanics-only and must stop before decode or live
input.

```bash
cd ~/pi_payload_2026-07-02
mkdir -p ~/hailo_runtime_logs_20260706
HEF=yolo26n_route_a_six_heads.hef

sha256sum -c SHA256SUMS.txt || { echo "GATE-FAIL: payload checksum mismatch"; exit 1; }
hailortcli parse-hef "$HEF" 2>&1 | tee ~/hailo_runtime_logs_20260706/block_e_parse_hef.log
rc=${PIPESTATUS[0]}
echo "PARSE_HEF_RC=$rc"
if [ "$rc" -ne 0 ]; then echo "STOP: parse-hef failed"; exit "$rc"; fi

if hailortcli --help | grep -Eq '(^|[[:space:]])run([[:space:]]|$)'; then
  timeout 60s hailortcli run "$HEF" 2>&1 | tee ~/hailo_runtime_logs_20260706/block_e_runtime_smoke.log
  rc=${PIPESTATUS[0]}
  echo "RUNTIME_SMOKE_CMD=run"
  echo "RUNTIME_SMOKE_RC=$rc"
elif hailortcli --help | grep -Eq '(^|[[:space:]])benchmark([[:space:]]|$)'; then
  timeout 60s hailortcli benchmark "$HEF" 2>&1 | tee ~/hailo_runtime_logs_20260706/block_e_runtime_smoke.log
  rc=${PIPESTATUS[0]}
  echo "RUNTIME_SMOKE_CMD=benchmark"
  echo "RUNTIME_SMOKE_RC=$rc"
else
  echo "STOP: no run/benchmark subcommand shown"
  exit 1
fi
if [ "$rc" -ne 0 ]; then echo "STOP: runtime smoke failed"; exit "$rc"; fi

sudo dmesg | grep -iE 'hailo|aer|dmar|dma|call trace|oops' | tail -160 \
  | tee ~/hailo_runtime_logs_20260706/block_e_post_smoke_fault_scan.log
```

## Session Evidence - 06/07/2026

Repo guard and repo-side hygiene:

- Initial workstation guard passed: `git fetch --prune` completed, `main`
  matched `origin/main` at
  `c5144a5ebe96f316eab5e33d986553f748d93e1c`, and
  `git status --short --branch` returned `## main...origin/main`.
- Before Pi Block B, the cold-boot timestamp gate was committed and pushed as
  `7a7e29f docs(diary): add Hailo cold-boot timestamp gate`. A follow-up guard
  rechecked `main == origin/main` at
  `7a7e29f9a0ca80ca7c723f0f1df4d83d5e9698ac`, with a clean worktree.
- The repo-wide visibility sweep was run from the terminal and returned zero
  matches. No `2026 residue removed`, `pre-2026 residue left untouched`, or
  `false positive` classification rows were needed.

Block B cold-boot install inventory passed:

- Pi log time was `06/07/2026 13:59:57 CEST`.
- Cold-boot authority is the monotonic uptime and this-boot kernel log, not the
  stale service wall-clock timestamp. `uptime -p` reported `up 10 minutes`, and
  the Block C kernel log later showed the Hailo driver and firmware re-initialized
  during this boot at monotonic timestamps `[4.669818]` through `[4.876857]`.
- `uptime -s` printed `2026-07-06 13:49:28`, but the Pi also reported
  `System clock synchronized: no` and `NTP service: inactive`, so wall-clock
  stamps are treated as useful context rather than primary boot proof.
- The stale `hailort.service` status line reported active since
  `03/07/2026 17:14:44 CEST`; that is consistent with the unsynced boot clock and
  is not treated as continuous-service evidence.
- Kernel remained `6.8.0-1060-raspi`; Python remained `3.12.3`.
- Installed packages included `hailort` `4.24.0`,
  `hailort-pcie-driver` `4.24.0`, `dkms` `3.0.11-1ubuntu13`,
  `linux-headers-6.8.0-1060-raspi` `6.8.0-1060.64`,
  `build-essential` `12.10ubuntu1`, and `python3-venv`
  `3.12.3-0ubuntu2.1`.
- Apt policy showed `hailort` and `hailort-pcie-driver` installed and candidate
  versions both at `4.24.0`; the matching kernel headers remained installed with
  candidate `6.8.0-1060.64`.
- `apt-mark showhold` returned no Hailo, Linux, or DKMS holds. This is a flag-only
  residual hygiene note: the current stack is coherent, but a later upgrade could
  still move the kernel or runtime row unless a hold policy is explicitly chosen
  in a separate maintenance block.
- `hailort.service` was present, enabled, and active.

Block C device, module, firmware, and fault scan passed:

- `lspci -nn` still showed the Hailo PCIe device at `0000:01:00.0`,
  `1e60:2864`.
- `/dev/hailo0` existed as character device major/minor `234, 0`.
- `lsmod` showed `hailo_pci`.
- `modinfo hailo_pci` reported version `4.24.0`, module path
  `/lib/modules/6.8.0-1060-raspi/updates/dkms/hailo_pci.ko.zst`, and matching
  `vermagic` for `6.8.0-1060-raspi`.
- `dkms status` reported
  `hailo_pci/4.24.0, 6.8.0-1060-raspi, aarch64: installed`.
- Firmware evidence showed `/lib/firmware/hailo/hailo8_fw.4.24.0.bin` and the
  `hailo8_fw.bin` symlink pointing to it.
- The broad kernel fault scan showed normal DMA pool / IOMMU / ADMA init, PCIe
  AER enablement, the expected out-of-tree unsigned-module taint lines, and clean
  Hailo probe / firmware-load / `/dev/hailo0` creation. No relevant PCIe AER
  error, DMA failure, firmware assert, call trace, or oops line appeared in the
  pasted tail.

Block D runtime CLI and Python binding recheck passed:

- `command -v hailortcli` returned `/usr/bin/hailortcli`.
- `hailortcli --version` returned `HailoRT-CLI version 4.24.0`.
- `hailortcli fw-control identify` succeeded with `FW_IDENTIFY_RC=0`; it executed
  on device `0000:01:00.0`, reported control protocol version `2`, firmware
  version `4.24.0`, and device architecture `HAILO8L`.
- In venv `~/venvs/hailo-rt-4.24.0`, Python imported `HEF`, loaded
  `yolo26n_route_a_six_heads.hef`, printed `HEF_NAME_OK`, and returned
  `PYTHON_HEF_IMPORT_RC=0`.

Block E optional repeat smoke was not run. Success condition reached: the pinned
Hailo runtime stack survived a fresh boot and the package, DKMS, firmware, CLI,
and Python-binding inventory was captured cleanly. This remains residual runtime
installation proof only; it is not decode, saved-frame inference, live RealSense,
ROS image input, dashboard integration, MAVROS, QGC, Herelink, mission upload,
arming, mode-change, parameter-write, thruster, actuator, or detector-quality
evidence.

## Block F - Wrap

Completed in `Session Evidence - 06/07/2026`.

Before a diary commit, run:

```bash
git status --short --branch
git add -N working_diary/2026-07-06_monday_hailo_runtime_residuals.md
git diff --check
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-06_monday_hailo_runtime_residuals.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-06_monday_hailo_runtime_residuals.md
```

Suggested commit subject:

```text
docs(diary): record Hailo cold-boot residual pass
```
