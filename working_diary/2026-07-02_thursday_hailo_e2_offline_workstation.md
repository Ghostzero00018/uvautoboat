# Thursday 02/07/2026 - Hailo E2 Offline Workstation Plan

## Day Overview

Tomorrow's Hailo task stays offline and workstation-side. Do not run Pi-side
commands. The official E2 artifact row is now in hand and pinned, so the goal is
to prepare the workstation toolchain and retire the custom-model compile risk:

1. move the downloaded official artifacts into the external ledger and record
   checksums;
2. use the Hailo AI Software Suite Docker as the first compile route; and
3. attempt the `yolo26n.pt` -> `hailo8l` HEF path with disciplined stop points.

The official Hailo Dataflow Compiler remains the destination for the custom
`yolo26n` maritime detector. Community / no-account routes are fallback-only
now: useful for stock smoke-test HEFs or a possible YOLOv8 / YOLO11 fallback,
but not the primary path for this session.

## Starting Context

- 01/07/2026 ended clean and pushed at `ce23aa3` or later; the key landed
  state is `ce23aa3 docs(wiki): confirm Hailo E2 artifact row`.
- `wiki/Hailo_HAT_Workstream.md` is the durable planning surface.
- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md` is the live
  evidence log.
- Pipeline 1 proved the HAT is healthy at the PCIe layer on the Pi 5:
  Ubuntu 24.04.4, kernel `6.8.0-1057-raspi`, Python 3.12.3, Hailo `1e60:2864`,
  gen-3 x1 link-up.
- The same probe found no Hailo runtime: no `/dev/hailo*`, no `hailortcli`, no
  `hailo-all`, no `hailort`, no `python3-hailort`, no `hailo-tappas-core`, and
  no Raspberry Pi apt source after `sudo apt update`.
- Branch decision from 01/07/2026: close E1 for this live Ubuntu image. The
  active path is E2 Ubuntu/manual.
- Official Hailo access landed on 01/07/2026. The full 4.24.0 runtime row,
  DFC 3.34.0, Model Zoo 2.19.0, both cp312 pyHailoRT wheels, and the
  `hailo8_ai_sw_suite_2026-07_docker.zip` image were downloaded and inspected.
- `wiki/Hailo_HAT_Workstream.md` now records these pins as confirmed and
  recommends the Docker suite as the first compile route.

## Session Evidence - 02/07/2026

Repo guard passed at the start of the session:

- `main` matched `origin/main` at
  `f090158e59b7042809b1eb4b84c66334f72cdaaa`.
- No pull was needed.
- `git status --short --branch` returned `## main...origin/main`.

The official artifact row was present, then staged outside the repo under:

```text
/home/ghostzero/hailo_artifacts/2026-07-02/
```

The Docker zip was moved into `official/` to avoid a duplicate 8.5G copy.
The smaller `.deb` and `.whl` files were copied into the same directory. The
external ledger is:

```text
/home/ghostzero/hailo_artifacts/2026-07-02/logs/ledger.txt
/home/ghostzero/hailo_artifacts/2026-07-02/logs/sha256sums_official.txt
```

The byte-identical duplicate
`hailort-pcie-driver_4.24.0_all(1).deb` was deleted from `Downloads` after
`cmp` passed and both files matched SHA256
`3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b`.

Official checksums:

```text
5e9a21f56217b131e49afdcacaebf3e200fd03a4d205d61bcb07ceda9c4542f6  hailo8_ai_sw_suite_2026-07_docker.zip
f539ebb5997149ec68ca443a547196a03d28c624fbb072fdcd22a7d37fad9fb1  hailo_dataflow_compiler-3.34.0-py3-none-linux_x86_64.whl
3f574626abf8fae103812bb8136431974a89ea693b098866d2455a2c7b7103c7  hailo_model_zoo-2.19.0-py3-none-any.whl
72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d  hailort-4.24.0-cp312-cp312-linux_aarch64.whl
7818ee8fe70a7f8a90f2485aaf488d0572fe2078d16728ae0716a42905e3d573  hailort-4.24.0-cp312-cp312-linux_x86_64.whl
3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b  hailort-pcie-driver_4.24.0_all.deb
1df39dfe1ce2c5beaa70c8d8a7ce807ff8ff81fa18a4b06d3ca06247d0203c47  hailort_4.24.0_amd64.deb
9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6  hailort_4.24.0_arm64.deb
```

Firmware note: no standalone firmware file was staged today. The pinned row
treats `hailo8_fw.bin` as bundled with the 4.24.0 driver/runtime packages;
verify `/lib/firmware/hailo/hailo8_fw.bin` only during a later Pi install.

Same-batch TAPPAS 5.3.1 downloads were deliberately excluded from the official
4.24.0 / 3.34.0 / 2.19.0 ledger and left in `Downloads`:

```text
d67b3df147e70f6ee89d115237827cd3d82fcd050818340f7cb224886851cbac  hailo-tappas-core_5.3.1_amd64.deb
9db31ee78ee0eade7f6e350abc3426d6c35e792a6dc18112f8fa908c80667e90  hailo-tappas-core_5.3.1_arm64.deb
8c1151b135b782d9e3e44c193ba2883b50ae57a00acfb47d71a3292b123e84b1  hailo_tappas_core_python_binding-5.3.1-py3-none-any.whl
```

Workstation host check:

- Host: `vrx-Precision-7560`.
- OS/kernel: Ubuntu 24.04.4 LTS, kernel `6.17.0-35-generic`.
- Architecture: `x86_64`.
- Python: `3.12.3`.
- CPU: 16 logical processors, AVX and AVX2 present.
- Memory: 14Gi physical RAM, 4.0Gi swap, 10Gi available.
- Disk: `/home` and `/tmp` have 50G available.
- GPU: a follow-up host-terminal `nvidia-smi` check reported driver
  `580.159.03`, CUDA `13.0`, and `NVIDIA RTX A3000 Laptop GPU` with 6GiB VRAM.
  This is a positive optional acceleration signal for DFC optimization; it does
  not remove the Docker gate or the physical-RAM warning.
- Container tooling: `docker`, `podman`, and `nerdctl` were not in `PATH`.
- Bare-metal Hailo compile tooling: `hailomz` and `hailo` were not in `PATH`.

Dataset/checkpoint check:

- Checkpoint exists:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt`
  at 5.2M.
- Current curated split has 11 images and 11 label files.
- This is enough to prove file plumbing only. It is below the 64-frame
  mechanics target for a first calibration run and far below the 500-1024
  maritime-frame range needed for meaningful int8 accuracy.

Docker archive inspection:

- `hailo8_ai_sw_suite_2026-07_docker.zip` contains exactly:
  `hailo8_ai_sw_suite_2026-07.tar.gz` and
  `hailo_ai_sw_suite_docker_run.sh`.
- The archive was inspected but not extracted, loaded, or executed.
- The run script is Docker-first: it checks Docker installation/user access,
  validates DFC system requirements, then calls `docker load -i` on the bundled
  tarball.
- The immediate blocker is workstation/container readiness: no Docker command
  exists on this host. The host also has only 14Gi physical RAM versus the DFC
  16GB documented floor; the bundled script's shell check appears to count swap
  in its total-memory line, so Docker absence is the hard stop on this host.

Compile status:

- Route A did not start.
- No container versions were available for `hailo --version`,
  `hailomz --version`, or HailoRT inspection.
- No ONNX export, Hailo parse, optimize/quantize, or HEF compile was attempted.
- No `hailo8l` HEF was produced.
- Block E remains fallback-only; no community HEF or DeGirum path was used.

Next gate before any Pi command:

1. Use a workstation with Docker installed and accessible to the user, or fix
   Docker/user-group access on this workstation.
2. Prefer a host that meets the DFC floor with at least 16GB physical RAM; 32GB
   remains the recommended target.
3. Re-check disk before extraction because the zip expands to a 9.1G tarball.
4. Extract the Docker tar/run-script pair together, run the official script,
   then verify container versions before Route A.
5. Only after a valid `hailo8l` HEF or a precise compile blocker exists should
   any Pi runtime install be considered.

## Boundaries

- Markdown docs may be edited. Do not edit Python, YAML, launch files,
  JavaScript, package files, shell scripts, or helper code unless explicitly
  requested.
- No Pi commands tomorrow unless the user explicitly changes the scope.
- No runtime install on the Pi. Success tomorrow is a prepared artifact /
  compile path, not `/dev/hailo0`.
- Keep downloaded packages, wheels, HEFs, calibration images, logs, and vendor
  artifacts outside the public repo.
- Do not mix Hailo 5.x artifacts into this board's path. The 13 TOPS Hailo-8L
  board stays on the HailoRT 4.x / `hailo8` line.
- Do not combine this with MAVProxy, MAVROS, QGC, Herelink, dashboard, real-FCU,
  mission upload, arming, mode change, parameter write, thruster, or actuator
  work.

## Block A - Repo Guard And Source Read

Run from the repo root:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Expected starting point:

```text
ce23aa3 docs(wiki): confirm Hailo E2 artifact row, or later
```

Read first:

- `working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md`
- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md`
- `wiki/Hailo_HAT_Workstream.md`
- `wiki/YOLO_Dataset_Plan.md`
- `Board.md`

Guard:

- If behind `origin/main`, run `git pull --ff-only`, then re-check.
- If ahead, diverged, or dirty, stop and report before starting artifact work.
- Record the exact starting SHA and whether a pull was needed.

## Block B - Official Artifact Presence Gate

Purpose: confirm the downloaded official set is still present and complete
before installing or loading anything.

Inspect the local downloads first:

```bash
cd /home/ghostzero/Downloads

ls -lh \
  hailort-pcie-driver_4.24.0_all.deb \
  hailort_4.24.0_arm64.deb \
  hailort-4.24.0-cp312-cp312-linux_aarch64.whl \
  hailort_4.24.0_amd64.deb \
  hailort-4.24.0-cp312-cp312-linux_x86_64.whl \
  hailo_dataflow_compiler-3.34.0-py3-none-linux_x86_64.whl \
  hailo_model_zoo-2.19.0-py3-none-any.whl \
  hailo8_ai_sw_suite_2026-07_docker.zip
```

Also check the Hailo portal only for drift:

- Is the pinned 4.24.0 / 3.34.0 / 2.19.0 row still the intended row for
  Hailo-8L?
- Has a newer coherent 4.x / 3.x / 2.x row landed since the files were
  downloaded?
- If a newer row exists, decide deliberately whether to stay pinned for this
  bring-up or replace the whole row. Do not mix.

Record exact filenames and checksums in the external ledger. Do not install
anything on the Pi.

Use this decision:

- If the official downloads are present, follow Block D and then Block F.
- If one file is missing, recover the same exact row from the portal before
  compiling.
- If the Docker suite cannot load or DFC cannot run, use Block E only as a
  fallback record, not as the main path.

## Block C - Workstation Host And Dataset Check

Run on the x86_64 Linux workstation:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat

echo "=== repo ==="
git status --short --branch
git log --oneline -5

echo "=== host ==="
hostname
date '+%Y-%m-%d %H:%M:%S %Z'
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release
uname -m
python3 --version

echo "=== resources ==="
free -h
nproc
grep -m1 -i 'flags' /proc/cpuinfo | grep -o 'avx[^ ]*' | sort -u || true
df -h /home /tmp

echo "=== optional acceleration / container ==="
nvidia-smi || true
docker --version || true
docker info >/tmp/hailo_docker_info_20260702.txt 2>&1; tail -40 /tmp/hailo_docker_info_20260702.txt || true
```

Dataset and checkpoint check. Confirm these paths first and adjust them if
tomorrow's export workspace differs:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06

echo "=== checkpoint ==="
test -f runs/baseline_yolo26n/weights/best.pt
ls -lh runs/baseline_yolo26n/weights/best.pt

echo "=== data counts ==="
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | wc -l
find labels/train labels/val -type f -iname '*.txt' | wc -l

echo "=== first calibration candidates ==="
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | sort | head -40
```

Interpretation:

- The Pi never compiles. If the workstation cannot run DFC bare-metal, prefer
  the official Hailo software-suite Docker route if available.
- A tiny calibration pool is enough only for mechanics. Treat meaningful int8
  accuracy as requiring a larger deployment-domain maritime set.
- Do not copy artifacts into the repo.

## Block D - Official Docker-First Route

Purpose: ledger the confirmed official row, load the Docker suite if host checks
pass, and prepare the custom-model compile path.

Create an external artifact ledger outside the repo:

```bash
mkdir -p /home/ghostzero/hailo_artifacts/2026-07-02/{official,logs}
cd /home/ghostzero/hailo_artifacts/2026-07-02

echo "Hailo E2 official artifact ledger - 02/07/2026" > logs/ledger.txt
echo "source: Hailo download portal, checked manually on 01/07/2026" >> logs/ledger.txt
```

Move or copy the downloaded official artifacts into `official/`, keeping them
outside the repo. Delete the duplicate `(1)` driver copy if it is byte-identical.
For every official artifact, record:

- filename;
- version;
- architecture;
- Python tag, if a wheel;
- source page label;
- SHA256 checksum;
- whether it is runtime-side, compile-side, or firmware.

Checksum template:

```bash
cd /home/ghostzero/hailo_artifacts/2026-07-02/official
sha256sum * | tee ../logs/sha256sums_official.txt
```

Minimum official row to confirm:

| Layer | Needed artifact | Constraint |
| --- | --- | --- |
| Pi runtime | PCIe driver | HailoRT 4.x / `hailo8`; driver floor >= 4.19 for the Pi's `6.8-raspi` kernel |
| Pi runtime | HailoRT arm64 runtime | same 4.x version as driver and firmware |
| Pi runtime | `pyhailort` aarch64 wheel | `cp312` is confirmed for Ubuntu 24.04 Python 3.12 in the pinned row |
| Pi runtime | firmware | same 4.x version as driver/runtime |
| Workstation compile | Dataflow Compiler 3.x | x86_64 only; use the row matched to Model Zoo 2.x |
| Workstation compile | Model Zoo 2.x | same row as DFC |
| Workstation validation | HailoRT x86 | same runtime line as the target HEF |

Primary workstation path:

1. Load the Hailo AI Software Suite Docker image from
   `hailo8_ai_sw_suite_2026-07_docker.zip`.
2. Start the container with the bundled run script.
3. Inside the container, verify the bundled versions before compiling:
   `hailo --version`, `hailomz --version`, and any HailoRT version command
   available.
4. Use this same container for the first `yolo26n.pt` compile attempt.

Bare-metal wheels remain fallback/scriptable artifacts. Do not mix Docker and
bare-metal commands unless the versions match.

## Block E - Fallback Routes, Only If Official Compile Path Blocks

Use this only if Block D cannot load the Docker image, the DFC cannot run, or a
needed official artifact is missing and cannot be recovered quickly.

Purpose: keep progress moving without pretending the custom `yolo26n` risk is
solved.

Allowed bridge work:

- Stage public HailoRT 4.x / `hailo8` source references for later source-build
  planning.
- Stage the public PCIe driver source reference.
- Stage a public Hailo-8L firmware reference.
- Stage a prebuilt public `hailo8l` HEF such as a stock YOLOv8n or YOLO11n
  model for a later smoke test.
- Check whether DeGirum access is available for a YOLOv8 / YOLO11 HEF path.

Do not claim:

- that DeGirum solves the current `yolo26n` custom-model path;
- that a stock HEF proves custom maritime-detector quality;
- that source-build runtime staging means the Pi is ready to install;
- that any community HEF replaces the official DFC path for `yolo26n`.

Bridge ledger:

```bash
mkdir -p /home/ghostzero/hailo_artifacts/2026-07-02/{community,logs}
cd /home/ghostzero/hailo_artifacts/2026-07-02

echo "Hailo E2 community bridge ledger - 02/07/2026" > logs/community_ledger.txt
echo "scope: fallback bridge only; official Docker/DFC remains primary for yolo26n" >> logs/community_ledger.txt
```

If a public stock HEF is downloaded, record:

- model name;
- device architecture, must be `hailo8l`;
- source label;
- SHA256 checksum;
- intended later use: stock runtime smoke test only.

If DeGirum is used, record:

- account/access status;
- supported model family shown by the tool;
- whether YOLOv8 / YOLO11 is accepted;
- whether `yolo26n` is unsupported;
- output HEF filename, if any;
- statement that this is a fallback model-family experiment, not the custom
  `yolo26n` result.

## Block F - Route A Custom HEF Experiment, Only If DFC Runs

Start this block only if the official Docker container is running, or the
bare-metal DFC / Model Zoo fallback is installed and `hailomz` or the equivalent
compiler entrypoint runs on the workstation.

First inspect tool versions:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06

echo "=== Hailo tools ==="
command -v hailomz || true
command -v hailo || true
hailomz --version 2>/dev/null || true
hailo --version 2>/dev/null || true
python3 --version

echo "=== Ultralytics ==="
python3 - <<'PY'
import ultralytics
print(ultralytics.__version__)
PY
```

Route A target:

```text
runs/baseline_yolo26n/weights/best.pt
  -> ONNX with the one-to-many / YOLOv8-style head if export supports it
  -> Hailo parse / optimize / quantize
  -> HEF with --hw-arch hailo8l
  -> parse-hef / architecture check
  -> emulation or evaluation if supported
```

Stop points:

- If export cannot produce a graph without unsupported `TopK` /
  `GatherElements` head ops, Route A is blocked.
- If end-node mapping is unclear, use Netron or compiler logs to identify the
  cut nodes; do not guess blindly.
- If compile succeeds but int8 mAP retention is bad, the HEF is not viable yet.
- If Route A blocks, record the failure and choose between Route B investigation
  or the YOLOv8 / YOLO11 fallback. Do not grind on repeated compile attempts
  without a new hypothesis.

Success definition:

- a HEF is produced for `hailo8l`;
- `parse-hef` or equivalent inspection confirms the architecture;
- tool versions and artifact paths are recorded;
- emulation/evaluation result is recorded if available;
- quality is compared against the FP32 / NCNN baseline before any Pi install.

## Block G - Wrap

Update this diary with:

- repo guard result and starting SHA;
- official artifact presence and exact evidence;
- whether the Docker suite loaded and which bundled versions it reports;
- downloaded filenames and SHA256 checksums, if any;
- workstation host suitability for DFC or Docker;
- dataset/checkpoint/calibration status;
- whether community / no-account bridge work was used;
- whether DeGirum was checked and what model families it supports;
- whether Route A compile was attempted, reached, blocked, or deferred;
- next gate before any Pi command.

End-state rules:

- The wiki pins are already confirmed. Update the wiki again only if tomorrow's
  actual Docker/tool versions differ from the recorded row.
- If the official Docker route fails, record fallback progress but keep the
  official DFC path as the custom `yolo26n` destination.
- No Pi runtime install until the artifact row and HEF path are understood.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
```

Before committing, grep the staged diff for secrets, generated artifacts,
external package paths, or local-only notes that should not be public. End with
bounded next steps and no stale completed action.

Suggested commit subject:

```text
docs(diary): record 02/07 Hailo E2 host blocker
```
