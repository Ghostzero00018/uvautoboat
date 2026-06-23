# YOLO Dataset Plan

This page defines the first custom object-detection dataset plan for Pi 5
RealSense frames and workstation YOLO training. It is a planning and data
quality guide, not a ROS node, dashboard adapter, or real-FCU command path.

## Current Evidence

| Area | Verified state |
|:-----|:---------------|
| Pi 5 inference | 09/06/2026 and 10/06/2026 proved Pi-local static-image YOLO feasibility: `yolo26n.pt` loaded, exported to `yolo26n_ncnn_model`, and ran CPU inference on `bus.jpg`. This used a stock pretrained COCO model, not a custom maritime dataset. |
| RealSense source | The Pi 5 RealSense D435i has published `/camera/camera/color/image_raw`; the workstation dashboard displayed the feed on 18/06/2026 through DDS, loopback-only rosbridge, and `web_video_server`. This remains camera-display evidence only. |
| Workstation training | 23/06/2026 workstation smoke test passed with `Ultralytics 8.4.75`, `torch-2.12.1+cu130`, and CUDA on `NVIDIA RTX A3000 Laptop GPU`. One-epoch `coco8.yaml` training wrote `runs/smoke/weights/best.pt`, then NCNN export wrote `runs/smoke/weights/best_ncnn_model`. |
| Project scope | Pi 5 is the capture and deployment-validation target. Custom training runs on the Linux workstation GPU. |

The `coco8.yaml` smoke-test metrics are not project quality evidence. They only
prove the local train-to-export toolchain; the sample dataset is a tiny COCO
subset and the model starts from COCO-pretrained weights.

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
  images/
    train/
    val/
  labels/
    train/
    val/
  runs/
```

Use `project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs` for
Ultralytics commands so `runs/` does not appear under the repository root.

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
