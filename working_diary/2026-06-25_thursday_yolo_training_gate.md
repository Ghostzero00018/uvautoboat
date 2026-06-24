# Thursday 25/06/2026 - YOLO Training Gate

## Purpose

Continue the 24/06 Pi RealSense YOLO workflow from the completed R3 split. Keep this workstation-only first: verify the YOLO environment and CUDA path, train a tiny pipeline-validation model, then export NCNN if training succeeds.

This is not detector-quality training. The current split is deliberately small and will overfit; use it to prove the capture -> label -> split -> train -> export chain.

## Starting Context

Expected starting repo state: `main` clean/synced at `500f16c` or later.

The 24/06 camera-only RealSense readiness check passed at `424x240x15` on `/camera/camera/color/image_raw`: publisher count 1, QoS `RELIABLE` / `TRANSIENT_LOCAL`, about 15 Hz, Pi temperature `68.85-72.7 C`, and no undervoltage/throttle evidence.

The 24/06 dataset pilot is outside the repo at:

```bash
/home/ghostzero/datasets/uvautoboat_yolo_2026-06
```

R1/R2/R3 produced a tiny active YOLO split:

- `images/train`: 9 images, 9 labels
- `images/val`: 2 images, 2 labels
- Active content: 7 `person` images plus 4 clean negatives
- Total boxes: 9 rows, all class `4` (`person`), normalized coordinates
- Val set: `oblique_20260624_144553_0006` with 2 person boxes plus `neg_20260624_150606_0004` as an empty negative
- Rejected frames remain under `raw/2026-06-24_pi_realsense_rgb/rejected_2026-06-24/` and must stay out of train/val

No custom model training, custom NCNN export, Pi custom-model validation, live RealSense inference, dashboard integration, MAVROS, QGC, Herelink, or real-FCU path has been proven yet.

## Boundaries

- Workstation-only unless a separate Pi static-validation block is explicitly approved.
- Do not run Pi, RealSense, ROS camera streaming, dashboard, MAVROS, QGC, Herelink, or real-FCU tests in this block.
- Do not run live RealSense YOLO inference.
- Do not combine RealSense + YOLO + MAVROS on the Pi.
- Keep all training/export outputs outside the repo under `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs`.
- No Python/YAML/launch/package/systemd/config changes unless explicitly approved.

## Block A - Repo Guard And Source Read

Before making any claim or edit, run from the repo root:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Guard:

- If fetch fails while on normal internet WiFi, stop and report.
- If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- If ahead, diverged, or dirty, stop and report before continuing.

Read first:

- `working_diary/2026-06-24_wednesday_pi5_realsense_yolo_capture.md`
- `wiki/YOLO_Dataset_Plan.md`
- `Board.md` YOLO / RealSense rows
- `wiki/Roadmap.md` YOLO / RealSense rows

## Block B - Dataset Lint And Environment Gate

Run in a clean workstation terminal, not a ROS-sourced shell:

```bash
DATASET=/home/ghostzero/datasets/uvautoboat_yolo_2026-06

find "$DATASET/images/train" -maxdepth 1 -type f -name '*.jpg' | wc -l
find "$DATASET/labels/train" -maxdepth 1 -type f -name '*.txt' | wc -l
find "$DATASET/images/val" -maxdepth 1 -type f -name '*.jpg' | wc -l
find "$DATASET/labels/val" -maxdepth 1 -type f -name '*.txt' | wc -l

unset PYTHONPATH
source ~/venvs/yolo-ws/bin/activate
cd "$DATASET"
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
python -c "import ultralytics; print(ultralytics.__version__)"
```

Expected:

- Train image/label counts are `9` / `9`
- Val image/label counts are `2` / `2`
- CUDA check prints `True NVIDIA RTX A3000 Laptop GPU`
- Ultralytics is the workstation YOLO environment, previously proven on 23/06

Install or confirm export dependencies before training:

```bash
pip install ncnn pnnx
python -c "import ncnn; print('ncnn ok')"
```

If the CUDA check fails or imports are broken, stop and record the environment issue. Do not fall back to CPU training unless explicitly approved.

## Block C - Train Pipeline-Validation Model

Only start after Block B passes.

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
yolo train data=data.yaml model=yolo26n.pt epochs=50 imgsz=640 device=0 \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=baseline_yolo26n
```

If GPU memory fails, reduce batch first and use a distinct run name:

```bash
yolo train data=data.yaml model=yolo26n.pt epochs=50 imgsz=640 batch=8 device=0 \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=baseline_yolo26n_b8
```

Use `yolo11n.pt` only if `yolo26n.pt` hits a toolchain issue, and record the reason.

Pass criteria:

- Training completes.
- `runs/baseline_yolo26n/weights/best.pt` exists, or the chosen fallback run has its own `weights/best.pt`.
- Nothing is written under the repo root.
- Metrics are recorded as informational only; do not treat mAP as detector-quality evidence.

## Block D - Validate And Export

If training succeeds, run validation as an informational check:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
yolo val data=data.yaml model=runs/baseline_yolo26n/weights/best.pt
```

If the training run name changed, adjust the model path.

Export NCNN:

```bash
yolo export model=runs/baseline_yolo26n/weights/best.pt format=ncnn
```

Pass criteria:

- Export creates an NCNN model directory beside `best.pt`.
- The export directory contains `model.ncnn.param` and `model.ncnn.bin`.
- Record the export path exactly.

Note: the NCNN export path is for later static Pi validation only. It does not prove live RealSense inference.

## Block E - Pi Static Validation Gate

Do not run this unless explicitly approved after Block D. If approved, keep it static-image only:

- Camera stopped.
- No RealSense stream.
- No MAVROS, QGC, Herelink, dashboard, or real-FCU path.
- Record Pi YOLO environment versions, input image, model path, timing, temperature via `/sys/class/thermal/thermal_zone0/temp`, and dmesg undervoltage/throttle tail.

This block validates a custom exported model can load and run on the Pi. It still does not prove live camera inference or any ROS/dashboard integration.

## Wrap

Update this diary with:

- Repo guard outcome and final SHA.
- Dataset lint counts.
- Environment versions and CUDA result.
- Training command, run path, and whether `best.pt` exists.
- Validation result if run.
- NCNN export path and file presence if run.
- Any skipped block and why.

Before any commit:

```bash
git status --short --branch
git diff --check
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-25_thursday_yolo_training_gate.md
rg -n "\[[[:space:]]\]" working_diary/2026-06-25_thursday_yolo_training_gate.md
```

Run the standard public-repo visibility sweep from the terminal before any commit. Eyeball the one-line conventional commit subject before committing.

**Next steps:** If Block D passes, the next explicit approval point is a Pi static-image validation of the custom NCNN export. Keep live RealSense inference, ROS/dashboard integration, MAVROS, QGC, Herelink, and real-FCU paths deferred.
