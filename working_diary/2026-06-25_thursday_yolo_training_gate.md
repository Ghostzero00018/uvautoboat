# Thursday 25/06/2026 - YOLO Training Gate

## Purpose

Continue the 24/06 Pi RealSense YOLO workflow from the completed R3 split. Keep this workstation-only first: verify the YOLO environment and CUDA path, train a tiny pipeline-validation model, then export NCNN if training succeeds.

This is not detector-quality training. The current split is deliberately small and will overfit; use it to prove the capture -> label -> split -> train -> export chain.

## Starting Context

Expected starting repo state: `main` clean/synced at `60dc7a4` or later.

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

**Outcome:** repo guard passed on 25/06/2026 before dataset or training work.
`git fetch --prune` completed, latest commit was `60dc7a4`
(`docs(diary): scaffold YOLO training gate`), `git status --short --branch`
showed clean `## main...origin/main`, and `git rev-parse HEAD origin/main`
returned the same SHA `60dc7a4bb0af988dfc48e8af4516663a07cb539c` for both
refs. The required 24/06 diary, YOLO dataset plan, Board YOLO / RealSense rows,
and Roadmap YOLO / RealSense rows were read before the workstation gate.

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

**Outcome:** Block B passed. Dataset counts were `9` train images,
`9` train labels, `2` val images, and `2` val labels. Stem parity was complete
for both splits, no rejected image stem appeared in the active train/val
images, and the label rows contained `9` boxes total with `0` bad field counts,
`0` non-`4` class IDs, and `0` out-of-range normalized coordinates.
`data.yaml` still points to
`/home/ghostzero/datasets/uvautoboat_yolo_2026-06` with class order `0: buoy`,
`1: vessel`, `2: dock`, `3: obstacle`, `4: person`.

The workstation YOLO environment passed after activating `~/venvs/yolo-ws`
with `PYTHONPATH` unset: CUDA was `True` on `NVIDIA RTX A3000 Laptop GPU`,
Ultralytics was `8.4.75`, and `ncnn` imported as `1.0.20260526`. No package
install was needed, and no CPU training fallback was used.

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

**Outcome:** Block C passed with the primary run name and no batch fallback.
The command used was:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
yolo train data=data.yaml model=yolo26n.pt epochs=50 imgsz=640 device=0 \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=baseline_yolo26n
```

Training ran with Ultralytics `8.4.75`, Python `3.12.3`,
`torch-2.12.1+cu130`, and CUDA device `0`
(`NVIDIA RTX A3000 Laptop GPU`, 5804 MiB visible to PyTorch). It completed all
50 epochs in about `0.006` hours, used about `1.38G` GPU memory after warmup,
and saved results to:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n
```

`weights/best.pt` and `weights/last.pt` both exist. The built-in final
validation reported `person` metrics `P=0.00873`, `R=1`, `mAP50=0.578`, and
`mAP50-95=0.565`; these are informational only because the split has only
2 validation images and 2 validation boxes.

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

**Outcome:** Block D passed. The explicit validation command completed against
`runs/baseline_yolo26n/weights/best.pt`; Ultralytics' default artifact path was
`/home/ghostzero/runs/detect/val`, so validation was rerun with an explicit
dataset-local output path:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
yolo val data=data.yaml model=runs/baseline_yolo26n/weights/best.pt \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=val_baseline_yolo26n
```

The recorded validation artifact is:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/val_baseline_yolo26n
```

The informational validation metrics were `P=0.00855`, `R=1`, `mAP50=0.566`,
and `mAP50-95=0.555` for both `all` and `person`, with `2` images and
`2` instances.

NCNN export succeeded from:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt
```

The export wrote:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best_ncnn_model
```

Required files are present:

- `model.ncnn.param` (`26394` bytes)
- `model.ncnn.bin` (`9604452` bytes)

Export reported NCNN `1.0.20260526`, PNNX `20260526`, disabled the unsupported
end-to-end branch, and produced output shape `(1, 9, 8400)`. This proves the
custom pilot split can train and export to NCNN on the workstation; it does not
prove detector quality, Pi loading, live RealSense inference, or any ROS /
dashboard / control-path integration.

## Block E - Pi Static Validation Gate

Do not run this unless explicitly approved after Block D. If approved, keep it static-image only:

- Camera stopped.
- No RealSense stream.
- No MAVROS, QGC, Herelink, dashboard, or real-FCU path.
- Record Pi YOLO environment versions, input image, model path, timing, temperature via `/sys/class/thermal/thermal_zone0/temp`, and dmesg undervoltage/throttle tail.

This block validates a custom exported model can load and run on the Pi. It still does not prove live camera inference or any ROS/dashboard integration.

**Outcome:** Block E passed as a static-image Pi custom-model load/run check
from `/home/ghostzero/Desktop/test_logs_folder/testlogs_25_06_2026.txt`.
Workstation W0 reached `imt-aqua-drone@10.120.2.249`; the Pi reported hostname
`imtaquadrone-desktop` and IP `10.120.2.249`. W1 copied the custom NCNN export,
the two validation JPGs, and helper script to:

```text
/home/imt-aqua-drone/yolo_tests/custom_20260625_static
```

The copied model files were present on the Pi:

- `best_ncnn_model/model.ncnn.param` (`26394` bytes)
- `best_ncnn_model/model.ncnn.bin` (`9604452` bytes)
- `best_ncnn_model/metadata.yaml` (`401` bytes)
- `best_ncnn_model/model_ncnn.py` (`729` bytes)

Copied static inputs were:

- `images/oblique_20260624_144553_0006.jpg` (`41231` bytes)
- `images/neg_20260624_150606_0004.jpg` (`39927` bytes)

Pi preflight found no matching RealSense, MAVROS, MAVProxy,
`web_video_server`, rosbridge, or YOLO processes. `~/venvs/yolo-pi5` imported
Ultralytics `8.4.62` and `ncnn 1.0.20260526`. Pre-run temperature was `66650`
from `/sys/class/thermal/thermal_zone0/temp` (`66.65 C`). The pre-run dmesg
filter showed only the two boot-time storage-bus voltage-switch messages, not
undervoltage or throttle evidence.

The Pi loaded the custom NCNN model from:

```text
/home/imt-aqua-drone/yolo_tests/custom_20260625_static/best_ncnn_model
```

Both static images ran at `imgsz=640` on CPU. The positive validation image
`oblique_20260624_144553_0006.jpg` returned `0` boxes on all three runs, with
wall times `508.2 ms`, `257.4 ms`, and `287.1 ms`; NCNN inference times were
`194.7 ms`, `234.7 ms`, and `268.1 ms`. The clean negative image
`neg_20260624_150606_0004.jpg` also returned `0` boxes on all three runs, with
wall times `234.4 ms`, `180.0 ms`, and `183.4 ms`; NCNN inference times were
`213.8 ms`, `158.4 ms`, and `163.7 ms`.

Post-run temperature was `69950` (`69.95 C`). The post-run dmesg filter again
showed only the same two boot-time storage-bus voltage-switch messages, with no
new undervoltage or throttle evidence. This proves the custom exported NCNN
model directory can be copied to the Pi, loaded by the Pi YOLO environment, and
run on static images. The zero detections are informational only and do not
prove detector quality. No RealSense stream, live inference, ROS/dashboard
integration, MAVROS, QGC, Herelink, or real-FCU path was run.

## Block F - RealSense NCNN Procedure Spike

Do not start this block unless Block E is complete and the Pi is on dedicated
USB-C power. This block is a procedure and power/thermal spike using the
current custom NCNN export and current tiny dataset result. It is not a
detector-quality test.

Boundaries:

- Run from a Pi terminal on `imtaquadrone-desktop`.
- Use `~/venvs/yolo-pi5`.
- Use the already copied custom model at
  `/home/imt-aqua-drone/yolo_tests/custom_20260625_static/best_ncnn_model`.
- Use the D435I serial `213622070342` at `RGB8 424x240x15`.
- For the ROS fallback, run only the RealSense camera node plus the ROS CLI /
  helper subscribers needed for this test.
- Keep dashboard, MAVROS, QGC, Herelink, and real-FCU paths stopped.
- Treat detection counts as informational only; expect `0` boxes from the
  current tiny overfit model at the default confidence threshold.
- Stop on any fresh undervoltage/throttle evidence or fast temperature rise.

### F0 - Pi Preflight

The direct `pyrealsense2` helper path was blocked before the ROS fallback:
`pyrealsense2` was absent from `~/venvs/yolo-pi5`, and `/usr/bin/python3` also
had no system `pyrealsense2` module. No direct-SDK capture or inference was
run. The fallback used the ROS camera node already proven on 24/06.

**Outcome:** ROS fallback F0 passed from
`/home/ghostzero/Desktop/test_logs_folder/testlogs_25_06_2026_BlockF.txt`.
The workstation reached `imt-aqua-drone@10.120.2.249`, and helper scripts were
copied to:

```text
/home/imt-aqua-drone/yolo_tests/realsense_spike_20260625
```

Pi preflight ran on `imtaquadrone-desktop` with `matching_process_count 0`.
After sourcing `/opt/ros/jazzy/setup.bash` and `~/venvs/yolo-pi5`, imports
worked for `rclpy`, `sensor_msgs`, Ultralytics `8.4.62`, `ncnn 1.0.20260526`,
OpenCV `4.11.0`, and NumPy `1.26.4`. The custom NCNN files were present:

- `model.ncnn.param` (`26394` bytes)
- `model.ncnn.bin` (`9604452` bytes)
- `metadata.yaml` (`401` bytes)
- `model_ncnn.py` (`729` bytes)

Preflight temperature was `73.8 C` from the helper and `72.7 C` from the
follow-up thermal read. The dmesg voltage/throttle filter showed only the two
boot-time storage-bus voltage-switch messages, not undervoltage or throttle
evidence.

### F1 - Snapshot Then Static Inference

The ROS fallback launched the camera in a separate Pi terminal with:

```bash
ros2 launch realsense2_camera rs_launch.py enable_depth:=false rgb_camera.color_profile:=424x240x15
```

The camera node reported RealSense ROS `v4.58.1`, LibRealSense `v2.58.1`,
D435I serial `213622070342`, firmware `5.14.0`, USB type `3.2`, and profile
`RGB8 424x240x15`. It reached `RealSense Node Is Up!`.

Camera-only ROS topic flow was steady before inference. `ros2 topic hz
/camera/camera/color/image_raw --window 30` reported rates from about
`14.939` to `15.012` Hz. The camera-only follow-up thermal read was `73.25 C`,
and the dmesg voltage/throttle filter still showed only the same two boot-time
storage-bus voltage-switch messages.

F1 then ran `gate1_ros_snapshot_infer.py` from
`~/yolo_tests/realsense_spike_20260625` using:

```text
/home/imt-aqua-drone/venvs/yolo-pi5/bin/python
```

The helper warmed up 20 frames, saved 5 ROS snapshots as `rgb8` images with
shape `(240, 424, 3)`, and each write returned `ok True`:

- `ros_snap_00.jpg`
- `ros_snap_01.jpg`
- `ros_snap_02.jpg`
- `ros_snap_03.jpg`
- `ros_snap_04.jpg`

The custom NCNN model loaded from:

```text
/home/imt-aqua-drone/yolo_tests/custom_20260625_static/best_ncnn_model
```

All 5 snapshots returned `0` boxes at the default confidence threshold. Wall
times were `785.0 ms`, `225.0 ms`, `374.8 ms`, `380.3 ms`, and `348.8 ms`;
recorded NCNN inference times were `309.3 ms`, `197.5 ms`, `352.7 ms`,
`358.9 ms`, and `326.4 ms`. F1 temperatures were `75.45 C` before capture,
`76.0 C` after capture, and `77.65 C` after inference; the follow-up thermal
read was `73.8 C`. The dmesg voltage/throttle filter remained clean apart from
the same boot-time storage-bus messages.

### F2 - Short Live Inference

Only run if F1 is clean. The first F2 command was issued from the wrong working
directory and failed with a missing-script path; the user then changed to
`~/yolo_tests/realsense_spike_20260625` and reran the helper successfully.

**Outcome:** F2 exercised the ROS image topic -> custom NCNN live path, but it
ended by the intended thermal abort rather than by the full time/frame cap. The
run warmed up 15 frames, loaded the same custom NCNN model, processed `30`
frames in `10.4 s`, and reported `mean_fps=2.90` with `mean_inf_ms=340.9`.
The live status lines were:

- `t=5.3s`, `n=14`, `fps=2.6`, `inf_ms=435`, `boxes=0`, `temp=79.30C`
- `t=10.4s`, `n=30`, `fps=2.9`, `inf_ms=416`, `boxes=0`, `temp=80.95C`

The helper then printed `TEMP ABORT 80.95`. Its final temperature was
`80.95 C`; the follow-up thermal read was `75.45 C`. The post-F2 dmesg
voltage/throttle filter again showed only the same boot-time storage-bus
voltage-switch messages. The camera node was then stopped with `Ctrl+C` and
reported `Stop Sensor: RGB Camera`, `Close Sensor - Done`, and a clean process
finish.

### F Outcome

Block F proved the ROS fallback procedure can run the current RealSense color
topic through the custom NCNN model on the Pi, and that the safety abort path
works. It did not prove the direct `pyrealsense2` path, because that module was
missing. It did not prove detector quality; all snapshot and live frames
returned `0` boxes at the default confidence threshold. It also did not prove a
thermally clean sustained live-inference profile: the short live run hit the
`80.0 C` abort threshold after `10.4 s`. The likely limiter is thermal headroom:
the Pi was already around `72.7-73.8 C` before the camera/inference spike, the
camera-only baseline was `73.25 C`, and F2 began at `76.55 C` before reaching
`80.95 C`. This is a cooling-baseline finding, not proof that the model is too
heavy. No undervoltage or throttle evidence appeared in the recorded dmesg
filters. No dashboard, MAVROS, QGC, Herelink, or real-FCU path was run.

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

**Wrap outcome:** the tiny pilot chain has now passed capture -> label ->
split -> train -> validate -> export -> Pi static-image load/run, plus a
bounded ROS-camera-node fallback procedure that fed RealSense RGB frames into
the custom NCNN model on the Pi. It is still not detector-quality evidence, and
it is not a sustained thermally clean live-inference result because the live
run hit the `80.0 C` abort threshold after `10.4 s` from an already-hot
`72.7-73.8 C` baseline. The direct `pyrealsense2` path remains unproven.
Dashboard integration, MAVROS, QGC, Herelink, and real-FCU paths remain
unproven.

**Next steps:** decide whether to park YOLO here or plan a separate thermal /
load-reduction pass for live inference. Any retest should keep the same safety
guards, start from a cooled Pi, and remain separate from dashboard, MAVROS,
QGC, Herelink, and real-FCU paths unless those blocks are explicitly approved.
