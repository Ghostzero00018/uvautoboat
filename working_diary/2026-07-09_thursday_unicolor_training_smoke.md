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
