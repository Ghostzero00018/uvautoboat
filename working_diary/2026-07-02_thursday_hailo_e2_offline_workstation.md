# Thursday 02/07/2026 - Hailo E2 Offline Workstation Plan

## Day Overview

Tomorrow's Hailo task stays offline and workstation-side. Do not run Pi-side
commands. The goal is to reduce the E2 Ubuntu/manual risk before the next bench
session by either:

1. confirming the official 4.x Hailo artifact row and preparing the workstation
   compile path; or
2. if the official download/access path still has no usable update, using the
   community / no-account route only as a bridge.

The official Hailo Dataflow Compiler remains the destination for the custom
`yolo26n` maritime detector. Community routes are useful for runtime staging,
stock smoke-test HEFs, and a possible YOLOv8 / YOLO11 fallback, but they do not
retire the custom `yolo26n.pt` compile risk by themselves.

## Starting Context

- 01/07/2026 ended clean and pushed at:
  `c7e2aea docs(wiki): record Hailo DFC path decision`.
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
c7e2aea docs(wiki): record Hailo DFC path decision
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

## Block B - Official Access Gate

Purpose: determine whether the official path is usable today.

Manual check in the Hailo download portal and account/email state:

- Is the account approved and able to download software?
- What is the newest HailoRT 4.x row available for Hailo-8 / Hailo-8L?
- Is there an aarch64 Ubuntu-compatible `pyhailort` wheel for Python 3.12
  (`cp312`)?
- What are the matching PCIe driver, runtime, firmware, Dataflow Compiler, and
  Model Zoo versions?
- Are the compile-side pins still the candidate row recorded in the wiki, or has
  a newer coherent 4.x / 3.x / 2.x row landed?

Record exact filenames and checksums when files are downloaded. Do not install
anything on the Pi.

Use this decision:

- If the official downloads are available, follow Block D first.
- If there is still no official access or no usable official download update,
  do not wait idle. Follow Block E as the community / no-account bridge.
- If official package versions are visible but not downloadable yet, record the
  filenames/versions as evidence and still use Block E for bridge work.

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

## Block D - Official Route, If Downloads Are Available

Purpose: lock one coherent official row and prepare the custom-model compile
path.

Create an external artifact ledger outside the repo:

```bash
mkdir -p /home/ghostzero/hailo_artifacts/2026-07-02/{official,logs}
cd /home/ghostzero/hailo_artifacts/2026-07-02

echo "Hailo E2 official artifact ledger - 02/07/2026" > logs/ledger.txt
echo "source: Hailo download portal, checked manually" >> logs/ledger.txt
```

For every downloaded official artifact, record:

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
| Pi runtime | `pyhailort` aarch64 wheel | prefer `cp312` for Ubuntu 24.04 Python 3.12; otherwise plan a Python 3.11 venv |
| Pi runtime | firmware | same 4.x version as driver/runtime |
| Workstation compile | Dataflow Compiler 3.x | x86_64 only; use the row matched to Model Zoo 2.x |
| Workstation compile | Model Zoo 2.x | same row as DFC |
| Workstation validation | HailoRT x86 | same runtime line as the target HEF |

After the row is confirmed, update `wiki/Hailo_HAT_Workstream.md` only if the
candidate pins can be changed to verified filenames/versions with evidence.

## Block E - Community / No-Account Bridge, If Official Path Is Still Blocked

Use this only if Block B has no usable official download/access result.

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
echo "scope: no-account bridge only; official DFC remains primary for yolo26n" >> logs/community_ledger.txt
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

Start this block only if the official DFC / Model Zoo path is installed and
`hailomz` or the equivalent compiler entrypoint runs on the workstation.

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
- official access status and exact evidence;
- whether the official row was confirmed, still blocked, or partially visible;
- downloaded filenames and SHA256 checksums, if any;
- workstation host suitability for DFC or Docker;
- dataset/checkpoint/calibration status;
- whether community / no-account bridge work was used;
- whether DeGirum was checked and what model families it supports;
- whether Route A compile was attempted, reached, blocked, or deferred;
- next gate before any Pi command.

End-state rules:

- If official downloads are available, update the wiki pins from candidate to
  confirmed only with exact filenames/versions.
- If official downloads are still unavailable, record community bridge progress
  but keep the official DFC path as the custom `yolo26n` destination.
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
docs(diary): scaffold 02/07 Hailo E2 offline workstation
```
