# Thursday 09/07/2026 - Unicolor Object Training Smoke

## Day Overview

Today validates the real-image training process with simple unicolor physical
objects before spending scarce water / dock time on maritime data. The target is
not detector recovery for `buoy`, `vessel`, `dock`, `obstacle`, or `person`.
The target is a controlled proxy loop:

RealSense capture -> reviewed frames -> YOLO-Hbb labels -> split -> workstation
training -> held-out firing evaluation.

This proxy must stay outside the public repo and outside the maritime dataset so
it cannot contaminate the real class map or later detector-quality evidence.
This proxy smoke intentionally precedes the VRX `buoy` / `dock` route from the
08/07 handoff because it tests the real RealSense capture -> manual box labeling
-> workstation retrain -> held-out firing loop directly, using easy targets that
should fire before maritime access is available.

## Starting Context

- Repo start point after the 08/07 close:
  `047eb3fb8ee74d7c060e38a41c98566fff2fb16b`
  (`docs(diary): add Pi smoke and visual-target decision`).
- The 08/07 detector-recovery session closed Blocks A-C only: baseline inventory,
  source decision, and external acquisition manifest. Block D was not started.
- Current maritime detector remains non-functional: the tiny pilot `best.pt`
  still fires on none of the available saved pools at `conf=0.25`, with
  confidence around the old `~0.003` noise ceiling.
- Current maritime data reality remains: 9 labeled instances total, all class
  `person`; `buoy`, `vessel`, `dock`, and `obstacle` have zero labeled examples.
- Hailo decode is proven and closed at `fb308f9`; Hailo is paused on detector
  quality, not on a Hailo defect.
- The 08/07 Pi smoke proved single-process RealSense -> Hailo ->
  decode-summary mechanics with the current HEF, but zero detections remain the
  expected result for that non-functional pilot detector.
- The live visual target is YOLO-style colored bounding boxes with class /
  confidence labels, not segmentation masks or polygon labels. Training labels
  stay YOLO-Hbb boxes.

## Pre-Start Durable-Doc Sweep

The 08/07 diary is currently the canonical source for the latest detector work.
The durable docs have propagation gaps, but no contradiction was found:

- `Board.md`: stale metadata (`Last Updated: 07/07/2026`, version `9.38`) and no
  08/07 timeline row for the detector-recovery A-C manifest, Pi Hailo runtime
  smoke, or boxes-not-masks visual decision. The Next Priorities detector item
  still points broadly to collect / label / retrain.
- `wiki/Roadmap.md`: §3 YOLO/Hailo rows and the revision log stop at the 07/07
  decode/scaffold state; no 08/07 A-C result, Pi runtime smoke, or visual-target
  decision is propagated.
- `wiki/YOLO_Dataset_Plan.md`: Current Evidence stops at 26/06, and the dataset
  tree still shows only `train` / `val` as physical directories even though the
  four-way `calib_hailo` / `tier3_eval` contract is already documented later in
  the same file. It also does not yet mention the 08/07 manifest decision or the
  boxes-not-masks visual target.
- `wiki/Hailo_HAT_Workstream.md`: Hailo gate ordering remains factually correct
  through the 07/07 decode proof, but it lacks a pointer to the 08/07
  detector-recovery manifest and the later Pi single-process runtime smoke.
- `wiki/Home.md`, `wiki/README_WIKI.md`, and `USER_MANUAL.md` have only cosmetic
  `07/07/2026` footers for this workstream.

Do not fold this propagation into the training-smoke work unless explicitly
approved. If updated, keep it as a separate docs-propagation commit.

## Success Definition

Success is one of:

1. a small, real-image unicolor-object dataset is captured / reviewed / labeled /
   split outside the repo, the workstation training run completes with a frozen
   config, and the resulting model fires on genuinely held-out unicolor-object
   positives above the old `~0.003` noise floor; or
2. a precise blocker is recorded with evidence: camera unavailable, workspace
   GPU unavailable, labeling bottleneck, split leakage risk, or insufficient
   held-out positives.

This proves the training process on easy real objects only. It does not prove
maritime detector quality, Hailo accuracy, Pi deployment, dashboard integration,
or real-world target detection.

## Boundaries

- All images, labels, manifests, dataset YAML, weights, runs, logs, and exports
  stay outside the public repo.
- Use an isolated proxy dataset root, for example:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/`.
- Do not merge unicolor proxy images or labels into
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/`.
- Do not reuse maritime class names for proxy objects unless the object is
  actually that maritime class. Prefer temporary classes such as `red_object`,
  `blue_object`, and `green_object`, recorded in the proxy `data.yaml`.
- No Hailo compile, Hailo calibration, Hailo Tier 3, production HEF replacement,
  detector deployment, dashboard integration, MAVROS, QGC, Herelink, mission
  upload, arming, mode change, parameter write, thruster, or actuator work.
- No production repo Python / YAML changes. Markdown diary updates are allowed.
- Execution blocks start only after explicit approval.
- Do not tune hyperparameters to chase a pass. Use one frozen training config and
  log it.

## Block A - Repo Guard And Source Read

Run from the repo root:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -8
git status --short --branch
git rev-parse HEAD origin/main
```

Guard: if fetch fails, stop and report. If behind only, run `git pull --ff-only`
and re-check. If dirty, ahead, or diverged, stop and report before training-smoke
work.

Read first:

- this file;
- `working_diary/2026-07-08_wednesday_detector_recovery.md`;
- `wiki/YOLO_Dataset_Plan.md`;
- `wiki/Hailo_HAT_Workstream.md`;
- `Board.md`;
- `wiki/Roadmap.md`.

Record the starting SHA and whether the durable-doc propagation gaps above still
stand.

## Block B - Proxy Dataset Design

Before capture, define the proxy dataset in a manifest outside the repo.

Minimum useful shape:

- 2-3 unicolor physical objects with high visual contrast;
- exact object names / colors recorded before capture;
- at least three scene groups: `train`, `val`, and `tier3_eval`;
- optional `calib_hailo` only as a placeholder split, not for Hailo work today;
- negative frames in every split;
- held-out scenes genuinely disjoint by background / distance / lighting / pose,
  not near-duplicates from the same clip.

Target a small but diagnostic dataset, not a large campaign:

- enough positives per proxy class to make training meaningful;
- at least about 5 held-out positives per active proxy class in `tier3_eval`;
- enough negatives to catch overfitting and false positives.

Write the manifest outside the repo before capture, for example:

```text
/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/manifests/
  2026-07-09_unicolor_training_smoke_manifest.md
```

## Block C - Capture Real Images

Capture still RGB frames with the RealSense, keeping split assignment at scene
time. Prefer a simple direct capture path over a ROS / dashboard path unless the
day explicitly reopens ROS image integration.

Default capture host: use the workstation USB path if the D435I is available
there; otherwise capture on the Pi and copy the dataset artifacts back to the
workstation dataset root before labeling / training.

Rules:

- one camera owner at a time;
- no live detector during capture;
- no dashboard or `rqt_image_view` co-consumer unless the capture route is
  deliberately changed;
- record camera, resolution, FPS, lighting, distance range, object placement,
  and rejected frames;
- do not capture from the same physical setup into both train and held-out
  splits.

## Block D - Label And Lint

Label in X-AnyLabeling box mode, exporting YOLO-Hbb labels:

```text
class_id x_center y_center width height
```

Lint before training:

- every image has a matching label file;
- empty label files are allowed only for negatives;
- class IDs match the proxy `data.yaml`;
- all coordinates are normalized and inside `[0, 1]`;
- no rejected frames are copied into active splits;
- no train / val / `tier3_eval` scene leakage.

## Block E - Workstation Retrain

Run training on the workstation GPU from a clean YOLO environment. First verify
CUDA from the real terminal that will train:

```bash
unset PYTHONPATH
source ~/venvs/yolo-ws/bin/activate
cd /home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

If CUDA is not visible, stop and fix the environment before training.

Use one frozen config. Record:

- model seed checkpoint;
- dataset YAML path;
- class names;
- image size;
- epochs;
- batch;
- device;
- Ultralytics version;
- output run directory.

## Block F - Held-Out Firing Evaluation

Evaluate on `tier3_eval`, not on training examples:

- record per-class confidence distribution;
- record detections at a fixed confidence threshold;
- confirm firing is clearly above the old `~0.003` noise ceiling;
- inspect failures and false positives.

Pass means the real-image training loop is mechanically valid for easy proxy
objects. It is still not maritime detector recovery.

## Block G - Optional Export Check

Only if Block F passes and time remains, optionally export the proxy model as a
deployment-format artifact outside the repo. Do not replace the maritime
checkpoint, do not compile a Hailo HEF, and do not deploy it as the production
detector.

## Wrap

Update this diary with:

- starting SHA;
- docs sweep confirmation;
- proxy dataset root and manifest path;
- class list and capture counts per split;
- label lint counts;
- training config and run path;
- held-out confidence summary;
- exact blocker if any;
- bounded non-claims.

Close with `git status --short --branch`, `git diff --check`, and a clear
`**Next steps:**` hint. If commit-ready, keep the commit markdown-only.

## Session Evidence - 09/07/2026

Block A repo guard and source read:

- `git fetch --prune` completed.
- `main` matched `origin/main` at
  `14c1a406a1e65523db76a6d8883d3a68b0b9611e`.
- `git status --short --branch` returned `## main...origin/main`.
- Recent history confirmed the pre-diary scaffold landed at `1f6f4ec`, then the
  durable-doc propagation landed at `14c1a40`.
- The durable-doc propagation gap recorded in the pre-start note is now
  superseded. `Board.md`, `wiki/Roadmap.md`,
  `wiki/YOLO_Dataset_Plan.md`, and `wiki/Hailo_HAT_Workstream.md` carry the
  08/07-09/07 detector / proxy-smoke status. `wiki/Home.md`,
  `wiki/README_WIKI.md`, and `USER_MANUAL.md` carry the 09/07 footer date; their
  existing navigation continues to point at those status-bearing pages.
- Repo artifact check found no proxy dataset root, labels, weights, ONNX, HEF,
  `data.yaml`, run, or log artifact under the public repo. The image-extension
  files found under the repo were existing documentation / dashboard static
  assets, not training-smoke dataset artifacts.

Block B proxy dataset design:

- Proxy dataset root:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/`.
- Manifest path:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/manifests/2026-07-09_unicolor_training_smoke_manifest.md`.
- Directory scaffold created outside the repo for `raw/`, `images/`, `labels/`,
  `logs/`, `runs/`, and `manifests/`.
- Temporary class list:

  | Class ID | Class |
  | ---: | --- |
  | 0 | `red_object` |
  | 1 | `blue_object` |
  | 2 | `green_object` |

- Planned splits are assigned at scene time in the manifest:
  `train`, `val`, `tier3_eval`, plus an empty `calib_hailo` placeholder only.
  The planned minimum accepted positives are 16 per active class in `train`, 4
  per active class in `val`, and 10 per active class in `tier3_eval`, plus
  negatives in each active split.
- Capture counts: `0` images. Block C has not started.
- Label lint counts: not run; no labels exist yet.
- Training config / run path: not created; no retraining run exists yet.
- Held-out confidence summary: not run; no `tier3_eval` detections exist yet.

Exact blocker:

- Block C is waiting for explicit capture approval, one camera owner, a confirmed
  workstation-USB or Pi fallback route, and exact red / blue / green physical
  object descriptions recorded before the first accepted frame.

Bounded non-claims:

- No maritime detector recovery was attempted or proven.
- The current maritime detector remains non-functional and the maritime dataset
  remains at 9 labeled instances, all `person`, with zero `buoy`, `vessel`,
  `dock`, or `obstacle` examples.
- No Hailo compile, Hailo calibration, Hailo Tier 3, production HEF replacement,
  detector deployment, dashboard integration, MAVROS, QGC, Herelink, mission
  upload, arming, mode change, parameter write, thruster, or actuator work was
  run.

Block C capture and copy-back:

- Capture route used the Pi 5 direct RealSense RGB still-frame path, then copied
  artifacts back to the workstation external dataset root.
- Pi preflight confirmed `imt-aqua-drone@imtaquadrone-desktop` on
  `10.120.2.249`, RealSense D435I serial `213622070342`, firmware `5.14.0`,
  and a working `640x480@15` color stream.
- Active proxy class map was revised before capture after available objects were
  confirmed:

  | Class ID | Class | Object identity |
  | ---: | --- | --- |
  | 0 | `black_object` | black nuka cola bottle |
  | 1 | `green_object` | green nuka cola bottle |

- Captured raw frame counts after copy-back:

  | Split | Positive frames | Negative frames | Total frames |
  | --- | ---: | ---: | ---: |
  | `train` | 24 | 6 | 30 |
  | `val` | 6 | 2 | 8 |
  | `tier3_eval` | 12 | 6 | 18 |
  | Total | 42 | 14 | 56 |

- Per-scene raw counts matched the manifest exactly:
  `S01_train_table_close` 12, `S01_train_table_close_neg` 3,
  `S02_train_floor_mid` 12, `S02_train_floor_mid_neg` 3,
  `S03_val_table_alt` 6, `S03_val_table_alt_neg` 2,
  `S04_tier3_eval_far_oblique` 6,
  `S04_tier3_eval_far_oblique_neg` 3,
  `S05_tier3_eval_clutter` 6, and `S05_tier3_eval_clutter_neg` 3.
- Rejected frame count is `0`.
- All accepted raw images are `640x480` JPEGs.
- The capture log has 62 rows because `S04_tier3_eval_far_oblique` was
  re-shot once after discarding the first take. The on-disk 56 raw JPGs are the
  authoritative Block D source set.

Block D split materialization and current lint state:

- `data.yaml` created outside the repo at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/data.yaml`.
- Active split copies created outside the repo:
  `images/train`, `images/val`, and `images/tier3_eval`.
  `calib_hailo` remains empty.
- Empty label files were created only for the 14 planned negative frames.
- Reusable lint helper installed outside the repo at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/logs/lint_unicolor_yolo_hbb_20260709.py`.
- Negative-label restore helper installed outside the repo at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/logs/restore_unicolor_negative_labels_20260709.py`.
- Final Block D lint state after positive YOLO-Hbb labels were added directly
  into `labels/{train,val,tier3_eval}`:

  | Check | Result |
  | --- | --- |
  | Active images | 56 |
  | Label files present | 56 |
  | Missing labels | 0 |
  | Empty positive labels | 0 |
  | Empty negative labels | 14 |
  | Non-empty negative labels | 0 |
  | Class counts | `0 black_object`: 42; `1 green_object`: 42 |
  | Positive label box histogram | 42 files with 2 boxes each |
  | Scene leakage | none found |
  | Unknown scenes | none found |
  | Lint errors | 0 |

- Overlay spot-checks on the first and last positive frames for `S01` through
  `S05` confirmed the class-object correspondence: class `0` labels the black
  bottle and class `1` labels the green bottle.

Bounded non-claims:

- The proxy `tier3_eval` split shares the same room and the same two physical
  bottles as `train`; it varies distance, pose, and clutter only. A later firing
  pass can prove the real-image training loop for easy proxy objects, but it
  cannot prove background generalization, new-object generalization, maritime
  detector recovery, Hailo accuracy, Pi deployment, dashboard integration,
  MAVROS, QGC, Herelink, mission upload, arming, mode change, parameter write,
  thruster, or actuator behavior.
- The labels are sufficient for this loop smoke but are not a human-grade
  maritime annotation benchmark. The train / validation positives are much
  larger than the `tier3_eval` positives, so a later validation fire with weak
  `tier3_eval` firing should be interpreted first as a scale gap.

Block E workstation CUDA gate:

- `git fetch --prune` completed before Block E, and `main` matched
  `origin/main` at `3686263a44d14e9566d9d0f136cb1186e06ba3d9`.
- `git status --short --branch` showed the intentional diary-only working tree
  change.
- Dataset lint was green before the training gate:
  56 images, 56 labels, 42 `black_object` boxes, 42 `green_object` boxes, and
  0 lint errors.
- The first shell probe saw the workstation GPU through `nvidia-smi`:
  `NVIDIA RTX A3000 Laptop GPU`, 6144 MiB, driver `580.159.03`.
- That first YOLO environment probe returned a false CUDA gate:

  ```text
  torch.cuda.is_available(): False
  device: NO_CUDA
  torch: 2.12.1+cu130
  ultralytics: 8.4.75
  ```

- Narrow diagnostics from the same environment showed `torch.version.cuda`
  `13.0`, CUDA built into PyTorch, `device_count` 0, and
  `RuntimeError: No CUDA GPUs are available` from `torch.cuda.init()`.
- `PYTHONPATH` and `CUDA_VISIBLE_DEVICES` were unset. Removing
  `LD_LIBRARY_PATH` did not make PyTorch see CUDA, and also made `nvidia-smi`
  unable to communicate with the driver in that probe.
- A later fresh workstation training terminal cleared the CUDA gate in the same
  `~/venvs/yolo-ws` environment after unsetting both `PYTHONPATH` and
  `CUDA_VISIBLE_DEVICES`:

  ```text
  torch.cuda.is_available(): True
  device: NVIDIA RTX A3000 Laptop GPU
  GPU matmul OK: True
  VRAM: 6086 MB
  torch: 2.12.1+cu130
  ```

- A driver probe in that terminal also reported `cuInit` success,
  `cuDeviceGetCount = 1`, and CUDA driver support for CUDA `13.0`, matching the
  PyTorch `cu130` build.

Training status:

- Block E environment gate was green for the host-context training shell.
- Frozen config was recorded outside the repo at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/logs/train_config_unicolor_smoke_20260709.yaml`.
- Seed checkpoint `yolo26n.pt` was downloaded into the external dataset root.
  Checksum:
  `9b09cc8bf347f0fc8a5f7657480587f25db09b34bf33b0652110fb03a8ad4fef`.
- Training command used the single frozen config:
  `model=yolo26n.pt`, `data=data.yaml`, `epochs=100`, `imgsz=640`,
  `batch=16`, `device=0`, `seed=0`, `project=runs`,
  `name=unicolor_smoke_20260709`, `exist_ok=False`.
- Training completed 100 epochs on CUDA in `0.018` hours with peak GPU memory
  around `2.41G`.
- Training log:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/logs/train_unicolor_20260709.log`.
- Ultralytics wrote the original run under:
  `/home/ghostzero/runs/detect/runs/unicolor_smoke_20260709`.
- The completed run was mirrored back into the external dataset root at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/runs/unicolor_smoke_20260709`.
- Mirrored checkpoint hashes match the original run outputs:
  `best.pt`
  `5c52354672a60cc19f4eabb238431dfc402e1f117e1d79040d4eae3bc8b85bd0`;
  `last.pt`
  `d0aab4d3801667fd33307ab57d9c1c4708bc2742b08345793ad8805b92ad9907`.
- The run's final epoch row in `results.csv` recorded the normal validation
  metric line:
  precision `0.96389`, recall `1`, mAP50 `0.995`, and mAP50-95 `0.5122` on
  the validation split.
- The final standalone `best.pt` validation pass selected the best checkpoint
  and printed mAP50 `0.995` and mAP50-95 `0.698` overall and for both classes:

  | Class | Images | Instances | Recall | mAP50 | mAP50-95 |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | all | 8 | 12 | 1 | 0.995 | 0.698 |
  | `black_object` | 6 | 6 | 1 | 0.995 | 0.698 |
  | `green_object` | 6 | 6 | 1 | 0.995 | 0.698 |

- The same standalone validation printout also showed very low precision values
  at Ultralytics' low validation confidence setting. Those values are not the
  fixed-threshold firing behavior and should not be read as a broken model.
  Block F will use explicit confidence thresholds and saved predictions for the
  firing readout.

Block F status:

- Block F held-out evaluation is complete.
- Verification summary was recorded outside the repo at:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/logs/block_f_eval_summary_20260709.txt`.
- Original Ultralytics evaluation / prediction artifacts were under
  `/home/ghostzero/runs/detect/runs/` and were mirrored into the external
  dataset root as:
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/runs/tier3eval`,
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/runs/tier3pred`,
  and
  `/home/ghostzero/datasets/uvautoboat_unicolor_smoke_2026-07-09/runs/tier3pred_1280`.
- Validation split summary:

  | Split | Objects | mAP50 | Fixed-threshold firing |
  | --- | --- | ---: | --- |
  | `val` (`S03`) | large, new placement | 0.995 | no boxes at `conf=0.25` or `conf=0.05`; boxes appear on positives at `conf=0.01`, with no boxes on negatives |
  | `tier3_eval` (`S04` / `S05`) | tiny / far | 0.0 | no boxes at `conf=0.25`, `conf=0.05`, or `conf=0.01` |

- The explicit fixed-threshold readout at `imgsz=640` was:

  | Split | Confidence | Total boxes | Positive boxes | Negative boxes | Max confidence |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | `val` | 0.25 | 0 | 0 | 0 | 0 |
  | `val` | 0.05 | 0 | 0 | 0 | 0 |
  | `val` | 0.01 | 80 | 80 | 0 | 0.01627 |
  | `tier3_eval` | 0.25 | 0 | 0 | 0 | 0 |
  | `tier3_eval` | 0.05 | 0 | 0 | 0 | 0 |
  | `tier3_eval` | 0.01 | 0 | 0 | 0 | 0 |

- Lowering `tier3_eval` to `conf=0.005` produced flooded low-confidence boxes
  on positives and negatives, with peak confidence only about `0.00765`.
  Increasing inference resolution did not recover held-out firing:

  | Image size | Tier3 max confidence | Tier3 positive max confidence |
  | ---: | ---: | ---: |
  | 640 | 0.00765 | 0.00765 |
  | 1280 | 0.00828 | 0.00791 |
  | 1920 | 0.00801 | 0.00776 |

Interpretation:

- The real-image capture -> label -> split -> workstation train loop is
  mechanically valid: the run trains, validates, writes checkpoints, and reaches
  high validation mAP on the easy proxy validation split.
- Fixed-threshold firing is weak even on `val`: the model does not emit boxes at
  `conf=0.05` or `conf=0.25`, and only appears around `conf=0.01`.
- The held-out `tier3_eval` split does not fire at `conf=0.01` or higher and
  scores mAP50 `0.0`. This is consistent with the planned scale / context gap:
  the training positives are large close objects, while `tier3_eval` contains
  tiny far objects.
- This is not maritime detector recovery and not Hailo evidence. It is a proxy
  training-loop proof with a concrete data lesson: the real maritime collection
  must cover the deployment distance / object-scale range.
- No retune was attempted after the frozen run. Block G export was not run
  because the proxy model does not fire on the designated held-out tier3 split.

**Next steps:** Commit the markdown-only diary update when ready. For any future
proxy iteration, collect train / val examples across the same near-to-far scale
range expected in `tier3_eval` before interpreting held-out firing as model
quality.
