# YOLO Dataset Plan

This page defines the first custom object-detection dataset plan for Pi 5
RealSense frames and workstation YOLO training. It is a planning and data
quality guide, not a ROS node, dashboard adapter, or real-FCU command path.

## Current Evidence

| Area | Verified state |
|:-----|:---------------|
| Pi 5 inference | 09/06/2026 and 10/06/2026 proved Pi-local static-image YOLO feasibility: `yolo26n.pt` loaded, exported to `yolo26n_ncnn_model`, and ran CPU inference on `bus.jpg`. This used a stock pretrained COCO model, not a custom maritime dataset. |
| Workstation-to-Pi handoff | 23/06/2026 proved a workstation-exported NCNN model can run on the Pi 5 runtime: `best_ncnn_model` from the workstation `coco8.yaml` smoke test was copied to `imt-aqua-drone@10.120.2.249` and ran 3 static CPU inferences at `imgsz=640` on `000000000042.jpg`, with `boxes=2`, steady-state inference `226.0-281.1` ms, and temp `68.85 C -> 68.30 C`. This remains COCO-model handoff evidence, not custom maritime-detector evidence. |
| RealSense source | The Pi 5 RealSense D435i has published `/camera/camera/color/image_raw`; the workstation dashboard displayed the feed on 18/06/2026 through DDS, loopback-only rosbridge, and `web_video_server`. This remains camera-display evidence only. |
| Workstation training | 23/06/2026 workstation smoke test passed with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, and CUDA on `NVIDIA RTX A3000 Laptop GPU`. One-epoch `coco8.yaml` training wrote `runs/smoke/weights/best.pt`, then NCNN export wrote `runs/smoke/weights/best_ncnn_model`. |
| Project scope | Pi 5 is the capture and deployment-validation target. Custom training runs on the Linux workstation GPU. |
| First pilot split and training gate | 24/06/2026 camera-only RealSense RGB capture at `424x240x15` produced a tiny pipeline-validation pilot outside the repo. After review/dedup, X-AnyLabeling YOLO-Hbb export, and lint, 7 `person` images plus 4 clean negatives were copied into a 9/2 train/val split. On 25/06/2026, that split trained on the workstation with `yolo26n.pt` for 50 epochs into `runs/baseline_yolo26n/weights/best.pt`, validated informationally into `runs/val_baseline_yolo26n`, and exported NCNN to `runs/baseline_yolo26n/weights/best_ncnn_model` with `model.ncnn.param` and `model.ncnn.bin`. Later the same day, that custom NCNN export loaded and ran on the Pi as a static-image CPU check in `~/venvs/yolo-pi5`; both saved validation images returned `0` boxes at the default confidence threshold. A bounded ROS-camera-node fallback then fed RealSense RGB frames into the custom NCNN model: F1 saved 5 snapshots and ran inference, and F2 processed 30 live frames in `10.4 s` at `mean_fps=2.90` and `mean_inf_ms=340.9` before the intended `80.0 C` safety abort fired at `80.95 C` from a roughly `72.7-73.8 C` baseline. This proves capture -> label -> split -> train -> validate -> export -> Pi static load/run plus bounded ROS camera-topic -> custom NCNN procedure/safety-abort mechanics only; it is not detector-quality data or sustained thermally clean live-inference evidence. Dashboard integration, MAVROS, QGC, Herelink, and real-FCU paths remain unproven. |
| 26/06/2026 thermal and direct-SDK follow-up | Headless SSH retesting showed the active remote-desktop session, not the cooler, was the dominant thermal confound: the camera-on / no-NCNN floor dropped to `50.70-52.35 C` (mean `51.03 C`). A short ROS-camera -> custom NCNN run passed (`150` frames in `18.8 s`, `mean_fps=7.98`, `mean_inf_ms=123.8`, no abort), but a sustained ROS + NCNN loop climbed through repeated `80.4-82.05 C` aborts, so sustained inference at the current `imgsz=640` profile is tested and not viable yet. `pyrealsense2 2.58.2` is proven only in the separate `~/venvs/yolo-pi5-rs`; direct camera-only capture passed (`900` frames / `60.0 s` / `14.99 fps`), and direct-SDK -> custom NCNN short inference passed (`150` frames / `23.1 s` / `mean_fps=6.51` / `mean_inf_ms=151.9`), but it showed no meaningful overhead advantage over ROS. The optional direct `imgsz=320` run segfaulted after model load; a real low-resolution thermal test needs a separate workstation NCNN export at `imgsz=320`. |
| 08/07/2026 detector-recovery planning | Blocks A-C closed as planning evidence only. Inventory confirmed the maritime dataset still has `9` labeled instances, all class `person`, with zero `buoy`, `vessel`, `dock`, or `obstacle` examples. The current `best.pt` still returns no detections at `conf=0.25` and stays near the old `~0.003` confidence floor. The external acquisition manifest assigns splits at source time: VRX can bootstrap `buoy` / `dock`, `vessel` needs explicit spawning, and `obstacle` / `person` need RealSense, admitted public data, or explicit world / asset authoring. The live visual target is YOLO-style colored boxes with class / confidence labels, not masks or polygons. |
| 09/07/2026 unicolor proxy scaffold | The next scaffold is an isolated real-image smoke using simple unicolor objects before maritime capture. It is designed to validate RealSense capture -> YOLO-Hbb box labels -> split -> workstation retrain -> held-out firing on easy targets. Proxy data uses temporary classes such as `red_object`, `blue_object`, and `green_object`; it must stay outside this maritime dataset and outside the public repo. |

The `coco8.yaml` smoke-test metrics are not project quality evidence. They only
prove the stock-sample local train-to-export toolchain; the sample dataset is a
tiny COCO subset and the model starts from COCO-pretrained weights. The
25/06/2026 pilot metrics are also not detector-quality evidence: they prove the
custom tiny split can train, validate, and export to NCNN, but the validation
split has only 2 images and 2 boxes.

## Non-Goals

- No mission upload, arming, mode change, parameter write, thruster, actuator,
  or real-FCU command path.
- No dashboard topic remap or `/wamv/*` replacement.
- No ROS image-classification node or continuous Pi camera inference yet.
- No heavy combined Pi workload until the dedicated `>=5A` Pi power path is
  confirmed and monitored.

## Dataset Location

Keep all images, labels, trained weights, exports, and run artifacts outside the
public repo:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/
  data.yaml
  dataset_card.md
  raw/
    2026-06-24_pi_realsense_rgb/
      rejected_2026-06-24/
    labels/
  images/
    train/
    val/
    calib_hailo/     # planned; create when accuracy-grade campaign starts
    tier3_eval/      # planned; held out from train/val/calib_hailo
  labels/
    train/
    val/
    calib_hailo/     # planned; paired labels or empty files for negatives
    tier3_eval/      # planned; held-out labels or empty files for negatives
  runs/
```

Use `project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs` for
Ultralytics commands so `runs/` does not appear under the repository root.

As of 08/07/2026, only the `train` / `val` split exists physically in the
maritime dataset root. `calib_hailo` and `tier3_eval` are planned split names
from the four-way contract below and should be created only when frames are
assigned to those splits.

X-AnyLabeling may write native `.json` sidecars beside raw images and export
YOLO `.txt` files into `raw/labels/`. Copy only reviewed active stems into
`images/{train,val}` and `labels/{train,val}`. Rejected frames and labels stay
out of train/val.

## First-Pass Classes

Keep the first dataset small and coarse. Add finer classes only after enough
examples exist and the distinction is task-critical.

| Class | Label when | Do not label when |
|:------|:-----------|:------------------|
| `buoy` | Floating marker or buoy-shaped navigation object visible in the water. Include partial buoys if the visible part is identifiable. | Shore fixtures, dock posts, or distant colored pixels that cannot be confidently identified as a buoy. Do not split red/green yet unless color becomes a control requirement with enough examples. |
| `vessel` | Other boats, kayaks, or surface craft that are not part of the ego boat. | Reflections, own-boat hardware, or decorative background objects that are not navigable surface craft. |
| `dock` | Fixed dock, pontoon, pier, berth edge, or landing structure visible as a navigational obstacle or shoreline feature. | Open shoreline without a structure, or tiny background fragments too small to localize consistently. |
| `obstacle` | Floating or protruding obstacle that is not better covered by another class: debris, logs, posts, marker hardware, or unknown solid hazards. | Ambiguous texture, water reflection, wake, foam, or objects that should be labeled as `buoy`, `vessel`, `dock`, or `person`. |
| `person` | Human in the scene, on a dock, in a vessel, or near the water where detection matters for safety. | Posters, mannequins, reflections, or body parts too small/blurred to identify consistently. |

Possible later splits:

- `red_buoy` / `green_buoy` only if color-specific navigation becomes required.
- `swimmer` only if water-person examples are available and separate handling is
  needed.
- Dedicated VRX-object classes only if there is a real-world counterpart or a
  simulator-specific dataset is deliberately created.

## Labeling Rules

- Use object detection boxes, not whole-image classification.
- Keep labels as YOLO-Hbb boxes. Do not switch this dataset to masks or polygon
  labels unless a separate model path is explicitly opened.
- Draw boxes around the visible object extent, not the guessed hidden extent.
- Label partially occluded objects only when the class remains clear.
- Skip objects too small or blurred for a human labeler to classify repeatably.
- Keep class names and numeric IDs stable once labeling starts.
- Review model-assisted pre-labels manually; never accept a pre-label batch
  without correction.
- For negative images, keep the image and create an empty matching label file.
  This makes no-target frames explicit and helps reduce false positives.

## Capture Protocol

Capture with the Pi 5 RealSense RGB stream from the intended deployment
viewpoint. The first pass should prioritize diversity over raw frame count.

Record these conditions in `dataset_card.md`:

- date, site, camera, resolution, and frame-rate profile;
- lighting: overcast, sun, glare, backlight, dusk, indoor bench if used;
- distance: near, mid-range, and far targets;
- angle: head-on, side, oblique, and partially occluded views;
- background: open water, shoreline, dock, vegetation, vessels, and clutter;
- weather and water state when relevant;
- whether MAVROS, Herelink video, dashboard, or other heavy workloads were also
  running.

Sampling rules:

- Avoid keeping dense 30 fps near-duplicates.
- Prefer sparse frames on scene change, target distance change, lighting change,
  or target orientation change.
- Include empty-water and background-only negative frames.
- Keep raw captures until labels are reviewed; only curated train/val files
  enter the YOLO layout.

## Train / Val Split

Split by capture condition, not by adjacent frames. Near-duplicate frames from
one clip should stay in the same split.

Default first split:

```text
train: 80 %
val:   20 %
```

Validation should include at least one example of each class that appears in the
training set, plus negative frames. If a class has too few examples for both
splits, collect more data before treating metrics as meaningful.

## Four-Way Split Contract For The Hailo Path

The Hailo accelerator path needs two extra splits beyond `train` / `val`:

- `calib_hailo` — frames used only to calibrate the INT8 HEF.
- `tier3_eval` — held-out reference frames for the Hailo saved-frame detection
  gate (host decode + NMS + un-letterbox versus the reference detector).

Rules, decided at capture / review time, not after the fact:

- `calib_hailo` and `tier3_eval` must be **disjoint**, and `tier3_eval` must
  also be held out from `train` and `val`. Otherwise the detection gate grades
  the model on data it was fit or calibrated against.
- Disjoint at the **capture-condition / scene level**, not just by frame stem —
  the same "near-duplicate frames from one clip stay together" rule above
  applies across all four splits, because two frames a fraction of a second
  apart are effectively the same image.
- Tag each frame's intended split at review time. Rejected frames stay out of
  all four.
- `tier3_eval` must contain at least one clear example of every class so the
  class-map decode is actually exercised end to end, plus negative frames.

Collection sizing target before the next full campaign:

- Aim for hundreds of labeled object instances per active class before treating
  the detector as functional. Do not repeat the 9-box pilot and expect a stable
  maritime detector.
- Reserve a few hundred representative `calib_hailo` frames for the
  accuracy-grade HEF. The earlier 28-frame set was a mechanics-only calibration
  proof, not an accuracy baseline.
- Keep enough `tier3_eval` positives per class, plus negatives, to record a
  meaningful held-out confidence distribution before comparing the quantized
  path.

## Training Environment

Use a clean terminal that does not inherit ROS Python paths:

```bash
unset PYTHONPATH
source ~/venvs/yolo-ws/bin/activate
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
```

Gate before training:

```bash
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Expected:

```text
True NVIDIA RTX A3000 Laptop GPU
```

Pre-install export dependencies so the export step does not mutate the
environment at runtime:

```bash
pip install ncnn pnnx
```

## Data File

Create `data.yaml` in the dataset root:

```yaml
path: /home/ghostzero/datasets/uvautoboat_yolo_2026-06
train: images/train
val: images/val

names:
  0: buoy
  1: vessel
  2: dock
  3: obstacle
  4: person
```

## First Training Command

Start from the same model family already proven on Pi:

```bash
yolo train data=data.yaml model=yolo26n.pt epochs=50 imgsz=640 device=0 \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=baseline_yolo26n
```

If GPU memory fails, reduce batch first before reducing `imgsz`:

```bash
yolo train data=data.yaml model=yolo26n.pt epochs=50 imgsz=640 batch=8 device=0 \
  project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs name=baseline_yolo26n_b8
```

Use `yolo11n.pt` only as a fallback if the `yolo26n.pt` path hits a toolchain
issue.

## Export

Export the selected checkpoint to NCNN on the workstation:

```bash
yolo export model=runs/baseline_yolo26n/weights/best.pt format=ncnn
```

The 23/06/2026 NCNN smoke export reported that the end-to-end branch was
disabled and produced classic output shaped like:

```text
(1, 84, 8400)
```

That means Pi-side inference must include normal NMS postprocessing. This is
expected for the current NCNN export path.

## Validation Gates

Workstation gate:

- `torch.cuda.is_available()` is `True`.
- training completes without writing under the repo root;
- `weights/best.pt` exists;
- NCNN export creates a `*_ncnn_model/` directory containing
  `model.ncnn.param` and `model.ncnn.bin`.

Pi 5 gate:

- validate static images before any live camera stream;
- record preprocess / inference / postprocess timing separately;
- record Pi temperature and throttling / power-warning state;
- test RealSense coexistence without MAVROS first;
- do not combine RealSense + YOLO + MAVROS until the dedicated `>=5A` supply is
  confirmed.

## Navigation

- [Home](Home)
- [Roadmap](Roadmap)
- [RealSense Dashboard Testing](RealSense_Dashboard_Testing)
- [Hailo HAT Workstream Memo](Hailo_HAT_Workstream)
