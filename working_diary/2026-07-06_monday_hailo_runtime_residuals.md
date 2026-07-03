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
- **Prereqs:** Pi has booted normally; clock is close enough for logs and apt
  metadata reads; no install commands in this block.
- **Run + stop:** collect time, kernel, packages, DKMS, apt policy, service, and
  hold-state evidence. Stop if kernel drifted away from the installed DKMS
  target or mixed Hailo packages appear.
- **After:** paste the full output.

```bash
cd ~/pi_payload_2026-07-02
mkdir -p ~/hailo_runtime_logs_20260706

{
  echo "=== time/kernel/python ==="
  date '+%Y-%m-%d %H:%M:%S %Z'
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

## Block F - Wrap

Update this diary with:

- repo guard and starting SHA;
- whether the repo was clean/synced after the 03/07 milestone push;
- Pi time/kernel/Python state;
- package inventory and apt-policy observations;
- DKMS/module/firmware/device-node status;
- `hailort.service` status, if present;
- broad kernel fault-scan result;
- `fw-control identify` result;
- Python `HEF` import result;
- optional repeat-smoke result, if explicitly run;
- exact blocker if stopped.

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
docs(diary): scaffold 06/07 Hailo runtime residual checks
```
