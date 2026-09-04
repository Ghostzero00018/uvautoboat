# Raspberry Pi and Hailo Lifecycle Guide

This page is the durable maintenance, recovery and layered-removal guide for
the Hailo-8L runtime on the already-provisioned boat Raspberry Pi 5. It
complements the
[Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test), the
[Hailo HAT Workstream Memo](Hailo_HAT_Workstream), the
[Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo) and the
[Real-FCU Digital Twin Runbook](Real_FCU_Digital_Twin_Runbook).

It assumes that Ubuntu 24.04, ROS 2 Jazzy and the project's Pi user already
exist. A clean-image Ubuntu/ROS installation is outside this page; use the Pi
bring-up page for SSH, UART, MAVProxy and MAVROS checks. The binary Hailo
payload is also not stored in this repository.

Status on 04/09/2026:

- The Ubuntu 24.04 installation sequence for HailoRT, the PCIe driver and the
  Python binding was executed successfully on 03/07/2026.
- Recovery after a Pi kernel update was executed successfully on 04/09/2026 by
  installing headers for the running kernel and rebuilding
  `hailo_pci/4.24.0` through DKMS.
- The exact composite command blocks on this page, including the strengthened
  fresh-install, recovery, post-update, rollback and layered-removal wrappers,
  are **DOCUMENTED / NOT RUN as exact blocks on the project Pi**.
  The package rollback and system-package removal start with an apt simulation;
  application and virtual-environment removal use recoverable quarantine.
  Retain the first execution as new evidence before calling a composite block
  proven.

The install evidence is in the
[03/07/2026 Hailo Pi runtime diary](https://github.com/Ghostzero00018/uvautoboat/blob/main/working_diary/2026-07-03_friday_hailo_pi_runtime_bringup.md).
The running-kernel recovery evidence is in the
[04/09/2026 verification diary](https://github.com/Ghostzero00018/uvautoboat/blob/main/working_diary/2026-09-04_friday_fix_verification_and_docs_update.md#the-hailo-driver-was-gone-a-kernel-update-without-headers).

This page does not authorise a real-flight-controller or actuator run. Stop all
Pi runtime owners before maintenance. Use the real-FCU runbook and a fresh
physical declaration and approval for any later powered hardware test.

## 1. Select the operation

| Goal | Section |
| --- | --- |
| Configure and verify the existing Pi's SSH, UART and MAVLink path | [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test) |
| Install the pinned Hailo system runtime | [Fresh pinned installation](#3-fresh-pinned-installation) |
| Build the stock COCO application root | [Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo) |
| Check the Pi before or after an update | [Routine maintenance](#4-routine-maintenance) |
| Recover `/dev/hailo0` after a kernel update | [Kernel and DKMS recovery](#5-kernel-and-dkms-recovery) |
| Restore the proven `4.24.0` row | [Pinned-version rollback](#6-pinned-version-rollback) |
| Quarantine only the application files | [Application quarantine](#71-application-quarantine) |
| Quarantine the standalone Python environment | [Python-environment quarantine](#72-python-environment-quarantine) |
| Remove the Hailo system packages | [System-package removal](#73-system-package-removal) |
| Diagnose a recurring problem | [Symptom index](#8-recurring-symptom-index) |

## 2. Inventory and retain evidence first

Run this non-actuating inventory block before an install, update, rollback or
removal. It creates an evidence directory, but it does not open the
flight-controller serial port or start Hailo inference. The Hailo identity
command opens `/dev/hailo0` for a read-only firmware/device query, so stop its
normal owner first as required below.

```bash
(
  set -euo pipefail

  EVIDENCE="$HOME/Desktop/pi_hailo_maintenance_$(date +%Y%m%d_%H%M%S)"
  [ ! -e "$EVIDENCE" ] || {
    echo "PI_HAILO_ABORT=evidence-exists path=$EVIDENCE"
    exit 1
  }
  install -d -m 700 "$EVIDENCE"

  {
    date --iso-8601=seconds
    hostname
    cat /etc/os-release
    uname -a
    python3 --version
    timedatectl status --no-pager
    df -h / "$HOME"
    free -h
    cat /sys/class/thermal/thermal_zone0/temp
  } >"$EVIDENCE/host.txt"

  {
    dpkg-query -W -f='${binary:Package}\t${Version}\n' \
      hailort hailort-pcie-driver dkms \
      "linux-headers-$(uname -r)" linux-headers-raspi 2>&1 || true
    dkms status 2>&1 || true
    systemctl status hailort.service --no-pager 2>&1 || true
    command -v hailortcli || true
    hailortcli --version 2>&1 || true
    timeout 15s hailortcli fw-control identify 2>&1 || true
    lspci -nn | grep -Ei 'hailo|1e60' || true
    ls -l /dev/hailo0 2>&1 || true
    lsmod | grep -i hailo || true
    modinfo hailo_pci 2>&1 || true
    dpkg-query -L hailort hailort-pcie-driver 2>&1 || true
    dpkg-query -S \
      /lib/firmware/hailo/hailo8_fw.4.24.0.bin \
      /lib/firmware/hailo/hailo8_fw.bin \
      /lib/firmware/hailo8_fw.bin 2>&1 || true
    find /lib/firmware -maxdepth 4 \
      \( -path '/lib/firmware/hailo' \
      -o -path '/lib/firmware/hailo/*' \
      -o -path '/lib/firmware/hailo/hailo8_fw.bin' \
      -o -name 'hailo8_fw.*.bin' \
      -o -path '/lib/firmware/hailo8_fw.bin' \) \
      -print 2>&1 || true
    find /var/lib/dkms/hailo_pci /usr/src/hailort-pcie-driver \
      -maxdepth 4 -print 2>&1 || true
    find /lib/modules -name 'hailo_pci*' -print 2>&1 || true
  } >"$EVIDENCE/hailo-system.txt"

  PAYLOAD="$HOME/pi_payload_2026-07-02"
  if [ -d "$PAYLOAD" ]; then
    find "$PAYLOAD" -maxdepth 1 -type f -print0 |
      sort -z |
      xargs -0 -r sha256sum >"$EVIDENCE/payload-sha256.txt"
  fi

  MODEL_ROOT="$HOME/hailo_coco_overlay_2026-07-10/models"
  if [ -d "$MODEL_ROOT" ]; then
    find "$MODEL_ROOT" -maxdepth 1 -type f -name '*.hef' -print0 |
      sort -z |
      xargs -0 -r sha256sum >"$EVIDENCE/application-hef-sha256.txt"
  fi

  for VENV in \
    "$HOME/venvs/hailo-rt-4.24.0" \
    "$HOME/hailo_coco_overlay_2026-07-10/venv"
  do
    if [ -x "$VENV/bin/python" ]; then
      "$VENV/bin/python" -m pip freeze >"$EVIDENCE/$(basename "$VENV")-pip-freeze.txt"
    fi
  done

  if [ -d "$HOME/hailo_coco_overlay_2026-07-10/hailo-apps/.git" ]; then
    git -C "$HOME/hailo_coco_overlay_2026-07-10/hailo-apps" \
      rev-parse HEAD >"$EVIDENCE/hailo-apps-revision.txt"
    git -C "$HOME/hailo_coco_overlay_2026-07-10/hailo-apps" \
      status --porcelain=v1 --untracked-files=all \
      >"$EVIDENCE/hailo-apps-status.txt"
  fi

  (
    cd "$EVIDENCE"
    find . -maxdepth 1 -type f ! -name artifacts.sha256 -printf '%P\0' |
      sort -z |
      xargs -0 -r sha256sum >artifacts.sha256
  )
  echo "PI_HAILO_INVENTORY=PASS evidence=$EVIDENCE"
)
```

Before a removal or rollback, also prove that no process owns the accelerator.
Authenticate first so `fuser` failure cannot be mistaken for an unused device:

```bash
(
  set -euo pipefail
  sudo -v

  if sudo fuser -v /dev/hailo0; then
    echo 'PI_HAILO_ABORT=device-in-use'
    exit 1
  else
    rc=$?
    [ "$rc" -eq 1 ] || exit "$rc"
  fi

  echo 'PI_HAILO_DEVICE_FREE=PASS'
)
```

Use each supervisor's normal Ctrl+C teardown first. Do not use a broad process
name kill. If a process remains, inspect and stop its exact PID using the
[process recovery procedure](Common_Issues#a-process-does-not-stop).

## 3. Fresh pinned installation

The project Pi uses the hand-assembled Ubuntu runtime, not Raspberry Pi OS
`hailo-all`. The existing payload was assembled from the Hailo Developer Zone
downloads recorded in the [Hailo HAT Workstream Memo](Hailo_HAT_Workstream)
and transferred to `~/pi_payload_2026-07-02` on 03/07/2026. A maintainer
recreating it must obtain the matching artifacts from Hailo, transfer them to
that exact directory and compare them with the project-pinned hashes below.
The repository does not contain or redistribute these binaries.

If returning here after [system-package removal](#73-system-package-removal),
first quarantine the deliberately retained standalone environment with
[Python-environment quarantine](#72-python-environment-quarantine). The fresh
installation block refuses to overwrite that environment.

The payload contains:

- `hailort-pcie-driver_4.24.0_all.deb`;
- `hailort_4.24.0_arm64.deb`;
- `hailort-4.24.0-cp312-cp312-linux_aarch64.whl`;
- `yolo26n_route_a_six_heads.hef`;
- `INSTALL_ORDER.txt`;
- `SHA256SUMS.txt`.

The driver, runtime and Python binding must stay on the same `4.24.0` line.
Do not trust a locally editable manifest by itself. Verify the five governed
members directly against the project-pinned hashes below. Four of them are
recorded in the 03/07 evidence; the `INSTALL_ORDER.txt` hash was recorded on
04/09/2026 from the workstation's retained copy of the payload,
`~/hailo_artifacts/2026-07-02/pi_payload_2026-07-02/`, which also carries the
other four and is the copy to transfer if the Pi's directory is lost. Then
install the prerequisites for the running kernel:

```bash
(
  set -euo pipefail
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  VENV="$HOME/venvs/hailo-rt-4.24.0"
  cd "$PAYLOAD"

  for package in hailort hailort-pcie-driver; do
    if dpkg-query -W "$package" >/dev/null 2>&1; then
      echo "PI_HAILO_ABORT=existing-system-package-review-state package=$package"
      exit 1
    else
      rc=$?
      if [ "$rc" -ne 1 ]; then
        echo "PI_HAILO_ABORT=package-query-failed package=$package rc=$rc"
        exit "$rc"
      fi
    fi
  done
  if [ -e "$VENV" ] || [ -L "$VENV" ]; then
    echo "PI_HAILO_ABORT=venv-exists path=$VENV"
    exit 1
  fi

  printf '%s  %s\n' \
    '3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b' \
    'hailort-pcie-driver_4.24.0_all.deb' \
    '9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6' \
    'hailort_4.24.0_arm64.deb' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    'hailort-4.24.0-cp312-cp312-linux_aarch64.whl' \
    'edc03c3ca099167970ea0b851af7eea892c76b81aceabfb5a54e9ec46afb932d' \
    'yolo26n_route_a_six_heads.hef' \
    '1a494453fc8b1b10001d913fd1fef0ca623224ccbbebcda3ff195e1eb9a7297e' \
    'INSTALL_ORDER.txt' |
    sha256sum -c -
  sudo apt update
  sudo apt install -y \
    dkms \
    build-essential \
    "linux-headers-$(uname -r)" \
    python3-venv

  KERNEL="$(uname -r)"
  sudo apt install -y ./hailort-pcie-driver_4.24.0_all.deb

  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ] || {
    echo "PI_HAILO_ABORT=dkms-current-kernel-missing kernel=$KERNEL"
    exit 1
  }
  test "$(modinfo -F version hailo_pci)" = 4.24.0

  printf '%s\n' "$DKMS_LINE"
  echo "PI_HAILO_DRIVER_INSTALL=PASS kernel=$KERNEL reboot=required"
)
```

This fresh-install path requires both Hailo system packages to be absent. Use
the rollback section for an existing coherent row. Treat a one-package partial
state as a diagnosis case rather than forcing either workflow.

The explicit DKMS assertion is required because the pinned driver package can
fall back to a direct, non-DKMS module build while its package installation
still succeeds. A package-manager success alone is not a lifecycle pass.

Reboot before installing the runtime. After reconnecting, require the running
kernel, module and device node to agree:

```bash
(
  set -euo pipefail
  KERNEL="$(uname -r)"

  test -e "/lib/modules/$KERNEL/build"
  test -c /dev/hailo0
  test "$(modinfo -F version hailo_pci)" = 4.24.0

  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ]
  awk '$1 == "hailo_pci" { found=1 } END { exit !found }' /proc/modules
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin

  printf '%s\n' "$DKMS_LINE"
  echo "PI_HAILO_DRIVER_BOOT=PASS kernel=$KERNEL version=4.24.0"
)
```

Then install the runtime and create the version-specific verification
environment. This block refuses to overwrite an existing environment:

```bash
(
  set -euo pipefail
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  VENV="$HOME/venvs/hailo-rt-4.24.0"
  cd "$PAYLOAD"

  if [ -e "$VENV" ] || [ -L "$VENV" ]; then
    echo "PI_HAILO_ABORT=venv-exists path=$VENV"
    exit 1
  fi
  printf '%s  %s\n' \
    '9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6' \
    'hailort_4.24.0_arm64.deb' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    'hailort-4.24.0-cp312-cp312-linux_aarch64.whl' |
    sha256sum -c -

  sudo apt install -y ./hailort_4.24.0_arm64.deb
  python3 -m venv "$VENV"
  "$VENV/bin/python" -m pip install --upgrade pip
  "$VENV/bin/python" -m pip install \
    ./hailort-4.24.0-cp312-cp312-linux_aarch64.whl
  "$VENV/bin/python" -m pip check

  test "$(hailortcli --version | awk '{print $NF}')" = 4.24.0
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin

  IDENTIFY="$(timeout 15s hailortcli fw-control identify)"
  printf '%s\n' "$IDENTIFY"
  grep -Ei 'Firmware Version:[[:space:]]*4\.24\.0' <<<"$IDENTIFY"
  grep -Ei 'Device Architecture:[[:space:]]*HAILO8L' <<<"$IDENTIFY"
  "$VENV/bin/python" -c \
    'from importlib.metadata import version; assert version("hailort") == "4.24.0"; from hailo_platform import HEF; print("PYHAILORT_IMPORT=PASS")'

  echo 'PI_HAILO_RUNTIME_INSTALL=PASS version=4.24.0'
)
```

Continue with the [COCO overlay build](Hailo_COCO_Overlay_Demo#build-one-time)
to create `~/hailo_coco_overlay_2026-07-10`, its separate application virtual
environment, pinned `hailo-apps` checkout and HEF.

## 4. Routine maintenance

### Before a Pi update

1. Stop the real-FCU, camera and Hailo supervisors normally.
2. Run the inventory block and copy important logs off the Pi.
3. Confirm the clock, free disk, temperature, running kernel, matching headers
   and current DKMS entry.
4. Keep the pinned payload available for recovery.
5. Preview package changes before accepting them.

```bash
(
  set -euo pipefail
  KERNEL="$(uname -r)"

  if [ -e "/lib/modules/$KERNEL/build" ]; then
    echo "headers=present kernel=$KERNEL"
  else
    echo "PI_HAILO_ABORT=headers-missing kernel=$KERNEL"
    exit 1
  fi
  if DKMS_STATUS="$(dkms status 2>&1)"; then
    printf '%s\n' "$DKMS_STATUS"
  else
    rc=$?
    printf '%s\n' "$DKMS_STATUS" >&2
    echo "PI_HAILO_ABORT=dkms-query-failed rc=$rc"
    exit "$rc"
  fi
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ] || {
    echo "PI_HAILO_ABORT=dkms-current-kernel-missing kernel=$KERNEL"
    exit 1
  }
  apt-cache policy linux-headers-raspi
  sudo -v
  sudo apt-get -s install linux-headers-raspi

  echo "PI_HAILO_PRE_UPDATE=PASS kernel=$KERNEL"
)
```

Ubuntu publishes `linux-headers-raspi` as the Raspberry Pi headers
meta-package. Installing it is the intended way to keep future headers moving
with kernel updates, but this meta-package installation is **NOT RUN on the
project Pi as of 04/09/2026**. Review the simulation output before the first
installation:

```bash
sudo apt install linux-headers-raspi
```

Do not remove old kernel headers or the pinned Hailo payload during the same
maintenance window. They are the recovery path until the new kernel has booted
and passed the post-update checks.

### After a Pi update or reboot

Run this before starting Hailo inference:

```bash
(
  set -euo pipefail
  KERNEL="$(uname -r)"
  DKMS_STATUS="$(dkms status)"

  echo "kernel=$KERNEL"
  test -e "/lib/modules/$KERNEL/build"
  printf '%s\n' "$DKMS_STATUS"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ]
  test -c /dev/hailo0
  test "$(modinfo -F version hailo_pci)" = 4.24.0
  test "$(hailortcli --version | awk '{print $NF}')" = 4.24.0
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin

  IDENTIFY="$(timeout 15s hailortcli fw-control identify)"
  printf '%s\n' "$IDENTIFY"
  grep -Ei 'Firmware Version:[[:space:]]*4\.24\.0' <<<"$IDENTIFY"
  grep -Ei 'Device Architecture:[[:space:]]*HAILO8L' <<<"$IDENTIFY"

  echo "PI_HAILO_POST_UPDATE=PASS kernel=$KERNEL"
)
```

If any assertion fails, do not start the detector or the real-FCU stack. Use
the recovery section next.

## 5. Kernel and DKMS recovery

The 04/09/2026 incident had a new running kernel but no matching Hailo module.
The PCIe device still appeared in `lspci`, while `/dev/hailo0` was absent. The
proven repair is to install the exact running kernel's headers and build the
pinned driver for that kernel; a kernel downgrade is not required.

```bash
(
  set -euo pipefail
  KERNEL="$(uname -r)"

  test "$(dpkg-query -W -f='${Version}' hailort-pcie-driver)" = 4.24.0
  test "$(dpkg-query -W -f='${Version}' hailort)" = 4.24.0
  sudo apt update
  sudo apt install -y "linux-headers-$KERNEL"

  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  if [ -z "$DKMS_LINE" ]; then
    sudo dkms install hailo_pci/4.24.0 -k "$KERNEL"
  fi

  sudo modprobe hailo_pci
  test -c /dev/hailo0
  test "$(modinfo -F version hailo_pci)" = 4.24.0

  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ]
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin

  IDENTIFY="$(timeout 15s hailortcli fw-control identify)"
  printf '%s\n' "$IDENTIFY"
  grep -Ei 'Firmware Version:[[:space:]]*4\.24\.0' <<<"$IDENTIFY"
  grep -Ei 'Device Architecture:[[:space:]]*HAILO8L' <<<"$IDENTIFY"

  echo "PI_HAILO_KERNEL_RECOVERY=PASS kernel=$KERNEL"
)
```

If `linux-headers-$KERNEL` has no candidate, stop. Do not install headers for a
different kernel and do not delete module files manually. Record `uname -r`,
`apt-cache policy "linux-headers-$KERNEL"`, `dkms status`, `lspci -nn` and
`sudo dmesg | grep -i hailo` for diagnosis.

## 6. Pinned-version rollback

This means returning the Hailo driver, system runtime and Python binding to the
proven `4.24.0` row. It does not mean downgrading the Pi kernel. This procedure
is **DOCUMENTED / NOT RUN on the project Pi**.

The exact pinned driver package has unusually broad maintainer scripts. Its
pre-removal path recursively removes every `hailo8_fw.*.bin` below
`/lib/firmware`, `/lib/firmware/hailo8_fw.bin`, the complete
`/lib/firmware/hailo/` directory, and all `hailo_pci` DKMS state and source
trees. Its DKMS uninstall step empties `/var/lib/dkms/hailo_pci` without
removing the directory, deletes only the uncompressed `hailo_pci.ko` under each
kernel's `updates/dkms`, and removes a direct fallback module only from the
running kernel. The compressed `hailo_pci.ko.zst` that DKMS installs on Ubuntu
24.04 therefore survives for every kernel that ever built it. A rollback
reinstalls the same version over the running kernel's copy and leaves the
others stale, so both post-reboot verifiers list every `hailo_pci*` under
`/lib/modules` and report entries outside the running kernel as review items.
A rollback or purge can therefore affect Hailo versions and kernels beyond the
selected package row. Stop if the inventory shows another required Hailo
version or consumer.

Before a rollback or system-package removal, archive those paths and the exact
package control scripts. The pinned payload remains the primary recovery copy:

```bash
(
  set -euo pipefail

  PAYLOAD="$HOME/pi_payload_2026-07-02"
  ARCHIVE_ROOT="$HOME/Desktop/pi_hailo_prechange_$(date +%Y%m%d_%H%M%S)"
  PATH_LIST="$ARCHIVE_ROOT/hailo-system-paths.nul"
  ARCHIVE="$ARCHIVE_ROOT/hailo-system-files.tar.gz"

  [ ! -e "$ARCHIVE_ROOT" ] || {
    echo "PI_HAILO_ABORT=archive-exists path=$ARCHIVE_ROOT"
    exit 1
  }
  install -d -m 700 "$ARCHIVE_ROOT"
  install -d -m 700 \
    "$ARCHIVE_ROOT/target-driver-control" \
    "$ARCHIVE_ROOT/target-runtime-control" \
    "$ARCHIVE_ROOT/installed-package-control"

  cd "$PAYLOAD"
  printf '%s  %s\n' \
    '3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b' \
    'hailort-pcie-driver_4.24.0_all.deb' \
    '9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6' \
    'hailort_4.24.0_arm64.deb' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    'hailort-4.24.0-cp312-cp312-linux_aarch64.whl' \
    'edc03c3ca099167970ea0b851af7eea892c76b81aceabfb5a54e9ec46afb932d' \
    'yolo26n_route_a_six_heads.hef' \
    '1a494453fc8b1b10001d913fd1fef0ca623224ccbbebcda3ff195e1eb9a7297e' \
    'INSTALL_ORDER.txt' |
    sha256sum -c -
  dpkg-deb --control hailort-pcie-driver_4.24.0_all.deb \
    "$ARCHIVE_ROOT/target-driver-control"
  dpkg-deb --control hailort_4.24.0_arm64.deb \
    "$ARCHIVE_ROOT/target-runtime-control"
  sudo find /var/lib/dpkg/info -maxdepth 1 -type f \
    \( -name 'hailort.*' -o -name 'hailort-pcie-driver.*' \) \
    -exec cp --target-directory="$ARCHIVE_ROOT/installed-package-control" \
      -- '{}' +
  test -n "$(
    find "$ARCHIVE_ROOT/installed-package-control" -maxdepth 1 -type f \
      -print -quit
  )"

  (
    cd /
    {
      for path in \
        lib/firmware/hailo \
        lib/firmware/hailo8_fw.bin \
        usr/lib/libhailort.so \
        var/lib/dkms/hailo_pci \
        usr/src/hailort-pcie-driver \
        etc/default/hailort_service \
        etc/systemd/system/hailort.service \
        etc/systemd/system/multi-user.target.wants/hailort.service \
        lib/systemd/system/hailort.service \
        etc/modprobe.d/hailo_pci.conf \
        lib/udev/rules.d/51-hailo-udev.rules
      do
        if [ -e "$path" ] || [ -L "$path" ]; then
          printf '%s\0' "$path"
        fi
      done
      find lib/firmware -name 'hailo8_fw.*.bin' -print0
      find lib/modules -name 'hailo_pci*' -print0
      find usr/src -maxdepth 1 -name 'hailo_pci-*' -print0
    } | sort -zu
  ) >"$PATH_LIST"

  [ -s "$PATH_LIST" ] || {
    echo 'PI_HAILO_ABORT=no-system-paths-to-archive'
    exit 1
  }
  tr '\0' '\n' <"$PATH_LIST" >"$ARCHIVE_ROOT/hailo-system-paths.txt"
  sudo tar --create --gzip --file="$ARCHIVE" --directory=/ \
    --null --files-from="$PATH_LIST"
  dpkg-query -W -f='${binary:Package}\t${Version}\n' \
    hailort hailort-pcie-driver \
    >"$ARCHIVE_ROOT/package-versions.txt"
  dpkg-query -L hailort hailort-pcie-driver \
    >"$ARCHIVE_ROOT/package-files.txt"
  sha256sum "$ARCHIVE" >"$ARCHIVE.sha256"

  echo "PI_HAILO_PRECHANGE_ARCHIVE=PASS path=$ARCHIVE_ROOT"
)
```

Inspect both the installed and target maintainer scripts in that archive before
continuing. During a rollback, the currently installed package's pre-removal
script runs first; a version other than `4.24.0` may have a different scope.

1. Run the inventory and device-free checks.
2. Run the pre-change archive above.
3. Simulate the exact two-package transaction and inspect the proposed changes.
4. Stop and mask the runtime service, install the matching driver and runtime
   in one transaction, verify DKMS, then reboot while the service remains
   masked.
5. Validate the packages, loaded driver, firmware path, device and DKMS row
   after reboot; then unmask and start the service before validating live
   firmware/device identity.
6. Rebuild the standalone and application virtual environments from the pinned
   wheel and checkout; keep both previous environments as recoverable siblings.

Simulation:

```bash
(
  set -euo pipefail
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  cd "$PAYLOAD"

  printf '%s  %s\n' \
    '3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b' \
    'hailort-pcie-driver_4.24.0_all.deb' \
    '9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6' \
    'hailort_4.24.0_arm64.deb' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    'hailort-4.24.0-cp312-cp312-linux_aarch64.whl' \
    'edc03c3ca099167970ea0b851af7eea892c76b81aceabfb5a54e9ec46afb932d' \
    'yolo26n_route_a_six_heads.hef' \
    '1a494453fc8b1b10001d913fd1fef0ca623224ccbbebcda3ff195e1eb9a7297e' \
    'INSTALL_ORDER.txt' |
    sha256sum -c -
  sudo apt-get -s install --allow-downgrades --reinstall \
    ./hailort-pcie-driver_4.24.0_all.deb \
    ./hailort_4.24.0_arm64.deb
)
```

Only continue if the simulation names the two intended Hailo packages and no
unrelated removal. Stop the service and apply that same two-package transaction:

```bash
(
  set -euo pipefail
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  cd "$PAYLOAD"

  printf '%s  %s\n' \
    '3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b' \
    'hailort-pcie-driver_4.24.0_all.deb' \
    '9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6' \
    'hailort_4.24.0_arm64.deb' |
    sha256sum -c -
  sudo systemctl stop hailort.service
  sudo systemctl mask hailort.service
  sudo apt-get install -y --allow-downgrades --reinstall \
    ./hailort-pcie-driver_4.24.0_all.deb \
    ./hailort_4.24.0_arm64.deb

  test "$(dpkg-query -W -f='${Version}' hailort-pcie-driver)" = 4.24.0
  test "$(dpkg-query -W -f='${Version}' hailort)" = 4.24.0
  test "$(modinfo -F version hailo_pci)" = 4.24.0
  ACTIVE_STATE="$(
    systemctl show -p ActiveState --value hailort.service
  )"
  [ "$ACTIVE_STATE" = inactive ]
  SERVICE_STATE="$(
    systemctl show -p UnitFileState --value hailort.service
  )"
  [ "$SERVICE_STATE" = masked ]

  KERNEL="$(uname -r)"
  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ]
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin

  echo "PI_HAILO_ROLLBACK_PACKAGES=PASS kernel=$KERNEL reboot=required service=masked"
)
```

Reboot. Before unmasking the service, verify the booted packages, loaded
driver, firmware symlink, device and DKMS row. Then start the service and
validate the live firmware/device identity:

```bash
(
  set -euo pipefail

  KERNEL="$(uname -r)"
  test "$(dpkg-query -W -f='${Version}' hailort-pcie-driver)" = 4.24.0
  test "$(dpkg-query -W -f='${Version}' hailort)" = 4.24.0
  test -c /dev/hailo0
  test "$(modinfo -F version hailo_pci)" = 4.24.0
  test "$(hailortcli --version | awk '{print $NF}')" = 4.24.0
  test -f /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  test -L /lib/firmware/hailo/hailo8_fw.bin
  test /lib/firmware/hailo/hailo8_fw.bin -ef \
    /lib/firmware/hailo/hailo8_fw.4.24.0.bin
  ACTIVE_STATE="$(
    systemctl show -p ActiveState --value hailort.service
  )"
  [ "$ACTIVE_STATE" = inactive ]
  SERVICE_STATE="$(
    systemctl show -p UnitFileState --value hailort.service
  )"
  [ "$SERVICE_STATE" = masked ]

  DKMS_STATUS="$(dkms status)"
  DKMS_LINE="$(
    awk -v kernel="$KERNEL" '
      index($0, "hailo_pci/4.24.0, " kernel) && /: installed$/ { print }
    ' <<<"$DKMS_STATUS"
  )"
  [ -n "$DKMS_LINE" ]
  find /lib/modules -name 'hailo_pci*' -print |
    while IFS= read -r path; do
      case "$path" in
        "/lib/modules/$KERNEL/"*) echo "module=$path" ;;
        *) echo "PI_HAILO_NOTE=stale-module-outside-running-kernel path=$path" ;;
      esac
    done

  sudo systemctl unmask hailort.service
  sudo systemctl enable --now hailort.service
  systemctl is-active --quiet hailort.service

  IDENTIFY="$(timeout 15s hailortcli fw-control identify)"
  printf '%s\n' "$IDENTIFY"
  grep -Ei 'Firmware Version:[[:space:]]*4\.24\.0' <<<"$IDENTIFY"
  grep -Ei 'Device Architecture:[[:space:]]*HAILO8L' <<<"$IDENTIFY"

  echo 'PI_HAILO_ROLLBACK_SYSTEM=PASS version=4.24.0'
)
```

Python HailoRT exists in a standalone verification environment and in the
integrated application's environment. Rebuild both so the rollback does not
leave one environment on a different version. First rebuild the standalone
environment without deleting the old one:

A virtual environment must be built at its final path: `venv` and `pip` write
that path into `bin/activate` and into every script shebang, so an environment
built elsewhere and renamed keeps working only through `bin/python -m`, while
`activate`, `pip` and the `hailo` console script point at a directory that no
longer exists. Both blocks therefore move the old environment aside first,
build in place, and put the old one back if the build fails.

```bash
(
  set -euo pipefail
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  VENV="$HOME/venvs/hailo-rt-4.24.0"
  STAMP="$(date +%Y%m%d_%H%M%S)"
  OLD="$HOME/venvs/hailo-rt-4.24.0.before-rollback-$STAMP"
  FAILED="$HOME/venvs/hailo-rt-4.24.0.failed-build-$STAMP"

  test -x "$VENV/bin/python"
  printf '%s  %s\n' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    "$PAYLOAD/hailort-4.24.0-cp312-cp312-linux_aarch64.whl" |
    sha256sum -c -
  for path in "$OLD" "$FAILED"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      echo "PI_HAILO_ABORT=venv-path-exists path=$path"
      exit 1
    fi
  done

  mv -- "$VENV" "$OLD"
  if ! (
    python3 -m venv "$VENV" &&
    "$VENV/bin/python" -m pip install \
      "$PAYLOAD/hailort-4.24.0-cp312-cp312-linux_aarch64.whl" &&
    "$VENV/bin/python" -m pip check &&
    "$VENV/bin/python" -c \
      'from importlib.metadata import version; assert version("hailort") == "4.24.0"; from hailo_platform import HEF' &&
    grep -qF "$VENV" "$VENV/bin/activate" &&
    head -n 1 "$VENV/bin/pip" | grep -qF "$VENV" &&
    test -x "$VENV/bin/hailo" &&
    head -n 1 "$VENV/bin/hailo" | grep -qF "$VENV"
  ); then
    [ ! -e "$VENV" ] || mv -- "$VENV" "$FAILED"
    mv -- "$OLD" "$VENV"
    echo "PI_HAILO_ABORT=standalone-venv-rebuild-failed restored=$VENV kept=$FAILED"
    exit 1
  fi

  echo "PI_HAILO_ROLLBACK_STANDALONE_PYTHON=PASS previous=$OLD"
)
```

Then rebuild the integrated application's environment without deleting the old
one:

```bash
(
  set -euo pipefail
  ROOT="$HOME/hailo_coco_overlay_2026-07-10"
  PAYLOAD="$HOME/pi_payload_2026-07-02"
  APP="$ROOT/hailo-apps/hailo_apps/python/standalone_apps/object_detection"
  VENV="$ROOT/venv"
  STAMP="$(date +%Y%m%d_%H%M%S)"
  OLD="$ROOT/venv.before-rollback-$STAMP"
  FAILED="$ROOT/venv.failed-build-$STAMP"

  test -d "$ROOT/hailo-apps/.git"
  test "$(git -C "$ROOT/hailo-apps" rev-parse HEAD)" = \
    891ce701c2ebe239a5d277759eb75a30f76678a9
  test -z "$(
    git -C "$ROOT/hailo-apps" status --porcelain=v1 --untracked-files=all
  )"
  test -s "$APP/requirements.txt"
  test -x "$VENV/bin/python"
  printf '%s  %s\n' \
    '72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d' \
    "$PAYLOAD/hailort-4.24.0-cp312-cp312-linux_aarch64.whl" |
    sha256sum -c -
  for path in "$OLD" "$FAILED"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      echo "PI_HAILO_ABORT=venv-path-exists path=$path"
      exit 1
    fi
  done

  mv -- "$VENV" "$OLD"
  if ! (
    python3 -m venv "$VENV" &&
    "$VENV/bin/python" -m pip install --upgrade pip &&
    "$VENV/bin/python" -m pip install \
      -r "$APP/requirements.txt" \
      "$PAYLOAD/hailort-4.24.0-cp312-cp312-linux_aarch64.whl" &&
    "$VENV/bin/python" -m pip check &&
    "$VENV/bin/python" -c \
      'from importlib.metadata import version; assert version("hailort") == "4.24.0"; from hailo_platform import HEF' &&
    grep -qF "$VENV" "$VENV/bin/activate" &&
    head -n 1 "$VENV/bin/pip" | grep -qF "$VENV" &&
    test -x "$VENV/bin/hailo" &&
    head -n 1 "$VENV/bin/hailo" | grep -qF "$VENV"
  ); then
    [ ! -e "$VENV" ] || mv -- "$VENV" "$FAILED"
    mv -- "$OLD" "$VENV"
    echo "PI_HAILO_ABORT=application-venv-rebuild-failed restored=$VENV kept=$FAILED"
    exit 1
  fi

  echo "PI_HAILO_ROLLBACK_PYTHON=PASS previous=$OLD"
)
```

Run the post-update verification before restoring any live service.

## 7. Layered removal

There is no one-command complete removal. The application root, standalone
verification environment, system packages, retained payload, real-FCU bundles
and run evidence are separate scopes. Apply only the layer that is intended;
the retained payload and evidence remain recovery assets unless a later,
separately reviewed cleanup explicitly names them.

### 7.1 Application quarantine

Use this when the Hailo system packages should remain installed but the project
application checkout, models and application virtual environment should stop
being active. The command moves the exact application root into a recoverable
quarantine; it does not use a wildcard or permanently delete evidence.

```bash
(
  set -euo pipefail
  ROOT="$HOME/hailo_coco_overlay_2026-07-10"
  QUARANTINE="$HOME/hailo_coco_overlay_2026-07-10.removed-$(date +%Y%m%d_%H%M%S)"

  test -d "$ROOT"
  [ ! -e "$QUARANTINE" ]
  mv -- "$ROOT" "$QUARANTINE"

  echo "PI_HAILO_APPLICATION_QUARANTINE=PASS path=$QUARANTINE"
)
```

Copy any required files off the Pi before deciding whether to delete that
quarantine later. The separate `~/venvs/hailo-rt-4.24.0`, system packages,
firmware and driver remain installed.

Commit-named `~/uvautoboat_real_fcu_bundle_*` directories and retained
`~/Desktop` evidence are separate from the Hailo application root. Inventory
and archive them independently; never remove them with a wildcard.

### 7.2 Python-environment quarantine

The standalone verification environment is outside the application root. Move
it separately if Python HailoRT verification should no longer be active:

```bash
(
  set -euo pipefail
  VENV="$HOME/venvs/hailo-rt-4.24.0"
  QUARANTINE="$HOME/venvs/hailo-rt-4.24.0.removed-$(date +%Y%m%d_%H%M%S)"

  test -d "$VENV"
  [ ! -e "$QUARANTINE" ]
  mv -- "$VENV" "$QUARANTINE"

  echo "PI_HAILO_PYTHON_QUARANTINE=PASS path=$QUARANTINE"
)
```

This does not change the system driver, firmware, runtime or application root.
After system-package removal, this quarantine is required before the fresh
installation workflow can recreate the standalone environment.

### 7.3 System-package removal

Use this only after the inventory and device-free checks. It removes the two
Hailo packages but deliberately retains shared tools, application data,
virtual environments, payloads and run evidence. This procedure is
**DOCUMENTED / NOT RUN on the project Pi**.

Run the pre-change archive from the rollback section first. The pinned driver
package's own pre-removal script then recursively deletes every
`hailo8_fw.*.bin` below `/lib/firmware`, `/lib/firmware/hailo8_fw.bin`, the
complete `/lib/firmware/hailo/` directory, the `hailo_pci` source trees and the
contents of `/var/lib/dkms/hailo_pci`. It deletes only the uncompressed
`hailo_pci.ko` under each kernel's `updates/dkms` and a direct fallback module
under the running kernel. This is broader than a version-local uninstall. Do
not proceed if those paths contain another Hailo version or are required by
another application.

On the proven installation, the purge leaves three load-affecting residues
because of how those scripts are written:

- the empty directory `/var/lib/dkms/hailo_pci`, emptied but never removed;
- the compressed module `hailo_pci.ko.zst` under `updates/dkms` for every
  kernel that ever built it, which DKMS installs on Ubuntu 24.04 and the
  script does not name. Until it is moved out and `depmod` is rerun, the
  module is still indexed and still loads on the next boot;
- the dangling symlink `/usr/lib/libhailort.so`, created by the runtime's
  post-install outside its payload and untouched by its removal scripts.

The package scripts also leave `/var/log/hailort-pcie-driver.deb.log`,
`/var/log/hailort.deb.log` and `/var/log/hailo`. They remain intentionally as
diagnostic evidence and are outside the runtime-surface absence verifier.
`/run/hailo` is transient and disappears on reboot.

The remediation block below moves exactly those paths into a dated,
recoverable quarantine after proving that no package owns them, then reruns
`depmod` for each touched kernel. The post-reboot verifier names every failed
check; it passes only once the residues are gone.

Preview first:

```bash
sudo apt-get -s purge hailort hailort-pcie-driver
```

Continue only if the preview removes the two intended Hailo packages and no
unrelated package. Then:

```bash
(
  set -euo pipefail
  sudo -v

  sudo systemctl stop hailort.service

  if sudo fuser -v /dev/hailo0; then
    echo 'PI_HAILO_ABORT=device-still-in-use'
    exit 1
  else
    rc=$?
    [ "$rc" -eq 1 ] || exit "$rc"
  fi

  if grep -qE '^hailo_pci[[:space:]]' /proc/modules; then
    sudo modprobe -r hailo_pci
  else
    rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "PI_HAILO_ABORT=module-state-query-failed rc=$rc"
      exit "$rc"
    fi
  fi
  sudo apt-get purge -y hailort hailort-pcie-driver

  echo 'PI_HAILO_SYSTEM_PACKAGES_REMOVED=PASS reboot=required'
)
```

Do not automatically remove `dkms`, kernel headers, `build-essential`,
`python3-venv`, ROS 2, MAVProxy or RealSense packages, and do not run
`apt autoremove`; they may be shared with other Pi work.

Then quarantine the three expected residues before rebooting. The block
enumerates them exactly, refuses any path that a package still owns, keeps the
tree layout under the quarantine root, and reruns `depmod` for every kernel
whose module it moved:

```bash
(
  set -euo pipefail
  sudo -v
  QUARANTINE="$HOME/Desktop/pi_hailo_residue_$(date +%Y%m%d_%H%M%S)"
  [ ! -e "$QUARANTINE" ] || {
    echo "PI_HAILO_ABORT=quarantine-exists path=$QUARANTINE"
    exit 1
  }
  install -d -m 700 "$QUARANTINE"

  RESIDUE="$(
    {
      [ ! -L /usr/lib/libhailort.so ] || echo /usr/lib/libhailort.so
      [ ! -d /var/lib/dkms/hailo_pci ] || echo /var/lib/dkms/hailo_pci
      find /lib/modules -path '*/updates/dkms/hailo_pci.ko*' -print
    } | sort -u
  )"
  [ -n "$RESIDUE" ] || {
    echo 'PI_HAILO_RESIDUE_QUARANTINE=PASS moved=0'
    exit 0
  }

  KERNELS=""
  while IFS= read -r path; do
    if dpkg -S -- "$path" >/dev/null 2>&1; then
      echo "PI_HAILO_ABORT=path-still-owned-by-a-package path=$path"
      exit 1
    else
      rc=$?
      if [ "$rc" -ne 1 ]; then
        echo "PI_HAILO_ABORT=package-ownership-query-failed path=$path rc=$rc"
        exit "$rc"
      fi
    fi
    if [ -d "$path" ] && [ ! -L "$path" ]; then
      if FIRST_ENTRY="$(
        sudo find "$path" -mindepth 1 -maxdepth 1 -print -quit
      )"; then
        :
      else
        rc=$?
        echo "PI_HAILO_ABORT=directory-inspection-failed path=$path rc=$rc"
        exit "$rc"
      fi
      if [ -n "$FIRST_ENTRY" ]; then
        echo "PI_HAILO_ABORT=directory-not-empty path=$path"
        exit 1
      fi
    fi
    sudo install -d -m 700 "$QUARANTINE$(dirname -- "$path")"
    sudo mv -- "$path" "$QUARANTINE$path"
    echo "moved=$path"
    case "$path" in
      /lib/modules/*/updates/dkms/*)
        kernel="${path#/lib/modules/}"
        KERNELS="$KERNELS ${kernel%%/*}"
        ;;
    esac
  done <<<"$RESIDUE"

  for kernel in $(printf '%s\n' $KERNELS | sort -u); do
    sudo depmod -a "$kernel"
    echo "depmod=$kernel"
  done
  sudo chown -R "$(id -u):$(id -g)" "$QUARANTINE"
  echo "PI_HAILO_RESIDUE_QUARANTINE=PASS path=$QUARANTINE"
)
```

Do not delete anything else by hand. Reboot, then verify that every
runtime-affecting system-package surface governed by this layer is absent. Each
check prints its own name when it fails. This does not check or remove the
application, virtual environments, payloads, bundles, package logs or retained
evidence:

```bash
(
  set -euo pipefail

  assert_package_absent() {
    local package="$1"
    local rc
    if dpkg-query -W "$package" >/dev/null 2>&1; then
      echo "PI_HAILO_CHECK_FAILED=package-still-installed package=$package"
      return 1
    else
      rc=$?
      if [ "$rc" -ne 1 ]; then
        echo "PI_HAILO_ABORT=package-query-failed package=$package rc=$rc"
        return "$rc"
      fi
    fi
  }

  FAILED=0
  absent() {
    if [ -e "$1" ] || [ -L "$1" ]; then
      echo "PI_HAILO_CHECK_FAILED=path-present path=$1"
      FAILED=1
    fi
  }

  assert_package_absent hailort || FAILED=1
  assert_package_absent hailort-pcie-driver || FAILED=1
  if command -v hailortcli >/dev/null 2>&1; then
    echo 'PI_HAILO_CHECK_FAILED=hailortcli-still-on-path'
    FAILED=1
  fi
  command -v modinfo >/dev/null 2>&1
  if modinfo hailo_pci >/dev/null 2>&1; then
    echo 'PI_HAILO_CHECK_FAILED=module-still-indexed'
    FAILED=1
  else
    rc=$?
    [ "$rc" -eq 1 ] || {
      echo "PI_HAILO_ABORT=modinfo-failed rc=$rc"
      exit "$rc"
    }
  fi
  absent /dev/hailo0
  UNIT_LOAD_STATE="$(
    systemctl show -p LoadState --value hailort.service
  )"
  if [ "$UNIT_LOAD_STATE" != not-found ]; then
    echo "PI_HAILO_CHECK_FAILED=unit-still-known state=$UNIT_LOAD_STATE"
    FAILED=1
  fi
  for path in \
    /etc/systemd/system/hailort.service \
    /etc/systemd/system/multi-user.target.wants/hailort.service \
    /lib/systemd/system/hailort.service \
    /lib/firmware/hailo \
    /lib/firmware/hailo8_fw.bin \
    /usr/lib/libhailort.so \
    /var/lib/dkms/hailo_pci \
    /usr/src/hailort-pcie-driver \
    /etc/default/hailort_service \
    /etc/modprobe.d/hailo_pci.conf \
    /lib/udev/rules.d/51-hailo-udev.rules
  do
    absent "$path"
  done

  DKMS_STATUS="$(dkms status 2>&1)"
  if [[ "$DKMS_STATUS" == *hailo_pci* ]]; then
    echo 'PI_HAILO_CHECK_FAILED=dkms-still-lists-hailo_pci'
    FAILED=1
  fi

  RESIDUE_LIST="$(
    {
      find /usr/src -maxdepth 1 -name 'hailo_pci-*' -print || {
        echo 'PI_HAILO_ABORT=residue-scan-failed root=/usr/src' >&2
        exit 1
      }
      find /lib/firmware -name 'hailo8_fw.*.bin' -print || {
        echo 'PI_HAILO_ABORT=residue-scan-failed root=/lib/firmware' >&2
        exit 1
      }
      find /lib/modules -name 'hailo_pci*' -print || {
        echo 'PI_HAILO_ABORT=residue-scan-failed root=/lib/modules' >&2
        exit 1
      }
    } | sort -u
  )"
  if [ -n "$RESIDUE_LIST" ]; then
    while IFS= read -r path; do
      echo "PI_HAILO_CHECK_FAILED=residue path=$path"
    done <<<"$RESIDUE_LIST"
    FAILED=1
  fi

  [ "$FAILED" -eq 0 ] || {
    echo 'PI_HAILO_SYSTEM_PACKAGE_REMOVAL_VERIFY=FAIL'
    exit 1
  }
  echo 'PI_HAILO_SYSTEM_PACKAGE_REMOVAL_VERIFY=PASS'
)
```

If any `PI_HAILO_CHECK_FAILED` line prints, retain the output and stop. A
runtime-affecting residue outside the three the remediation block expects means
a different package or a manual install owns it; diagnose ownership before
taking another removal step, and do not claim this removal layer complete.

## 8. Recurring symptom index

| Symptom | First check | Action |
| --- | --- | --- |
| `/dev/hailo0` missing after a kernel update | `uname -r`, matching headers and `dkms status` | Use [kernel and DKMS recovery](#5-kernel-and-dkms-recovery) |
| Hailo driver and runtime versions differ | `dpkg-query`, `modinfo -F version hailo_pci`, `hailortcli --version` | Restore the coherent [pinned row](#6-pinned-version-rollback) |
| Hailo absent from `lspci` | After full power-off and physical-access approval, verify HAT seating; also check PCIe enablement and power | Stop; HailoRT/driver package reinstallation cannot repair an absent PCIe device |
| `HAILO_DEVICE_IN_USE` or busy device | `sudo fuser -v /dev/hailo0` | Stop the exact owning supervisor or PID normally |
| CLI works but Python import fails | the active virtual environment and `pip freeze` | Rebuild that environment from the pinned wheel; do not reinstall the driver |
| Integrated helper rejects the Hailo checkout | checkout revision, status and governed file hashes | Restore a clean pinned checkout before running |
| Camera node missing or busy | `/dev/video4` mapping and `sudo fuser -v /dev/video4` | Re-map the D435I colour node or stop its exact owner |
| Temperature reaches the `80 C` abort | cooler, airflow, power and current workload | Leave the detector stopped until thermal headroom is restored |
| Apt or HTTPS fails after boot | `timedatectl status` and DNS | Synchronise the clock before treating package availability as real |
| Disk is unexpectedly full | `df -h` and retained run directories | Archive evidence first; remove only reviewed exact targets |

For ROS 2, Gazebo, dashboard, navigation and process-lifecycle problems, use
[Common Issues and Solutions](Common_Issues).

## 9. Evidence and closure

For any first execution of an unproven maintenance block, retain:

- the inventory directory and its checksum file;
- the package-manager simulation and actual output;
- before-and-after package versions and DKMS state;
- the running kernel and matching-header result;
- `/dev/hailo0`, firmware, CLI and Python verification as applicable;
- the exact application or quarantine path;
- the reboot result and any remaining service, module or device state.

Installation, repair, rollback, quarantine and system-package removal are
different claims. Record only the operation that actually completed.

## Navigation

- [Home](Home)
- [Pi 5 Bring-up Smoke Test](Pi5_Bringup_Smoke_Test)
- [Hailo HAT Workstream Memo](Hailo_HAT_Workstream)
- [Pi Hailo COCO-Overlay Demo](Hailo_COCO_Overlay_Demo)
- [Real-FCU Digital Twin Runbook](Real_FCU_Digital_Twin_Runbook)
- [Common Issues](Common_Issues)
