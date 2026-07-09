# Friday 10/07/2026 - Unicolor Scale-Recovery Test

## Day Overview

The 09/07 unicolor smoke proved the real-image loop is mechanically valid, but
the trained model fired nowhere at a usable threshold (`val` peaked around
`0.016`) and completely missed the tiny held-out (`tier3_eval` around `0.007`,
mAP50 `0.0`). The diagnosis was data, not pipeline: too few genuinely distinct
examples plus a single dominant object scale.

This test asks the one open question directly, on cheap objects and no water:
if the data distribution is fixed - many distinct `near` / `mid` / `far`
black / green scenes - does the same loop and same frozen-config family produce
usable-threshold firing (`conf >= 0.05`, ideally `>= 0.25`) on genuinely
held-out frames? A pass means the scale / quantity fix works and transfers to
maritime data design. A fail despite fixed data means something deeper than
scale and quantity.

Execution is gated: blocks start only on explicit approval. All data stays
outside the repo. This is not maritime recovery, Hailo, export, or deployment
work.

## Starting Context

- Repo start SHA: fill at Block A.
- 09/07 result to beat: `val` peak `~0.016`, `tier3_eval` peak `~0.007`,
  `tier3_eval` mAP50 `0.0`.
- Class map, proven on 09/07, reused unchanged: `0 black_object`,
  `1 green_object` (black and green nuka cola bottles).
- Proven capture helper: `pi_unicolor_smoke.sh` (preflight / snapshot / capture,
  one-camera-owner start-stop). Reuse and extend for multi-scale capture.
- The 09/07 dataset (`uvautoboat_unicolor_smoke_2026-07-09`) is frozen. This test
  builds a new, separate external dataset and does not reuse or merge it.

## Success Definition

Success is one of:

1. a new multi-scale black / green dataset is captured, labeled, split, and
   trained once with a frozen config, and `best.pt` fires on genuinely held-out
   positives in **both** `val` and `tier3_eval` at `conf >= 0.05`, ideally
   `>= 0.25`; or
2. a precise blocker is recorded with evidence: capture route, labeling
   bottleneck, split leakage, GPU environment, or a firing failure that persists
   even with a fixed multi-scale distribution (which would point past scale /
   quantity).

This proves the proxy-data fix only. It is not maritime detector quality, Hailo
accuracy, Pi deployment, or dashboard integration.

## Boundaries

- New external dataset root, for example
  `/home/ghostzero/datasets/uvautoboat_unicolor_scale_2026-07-10/`. All images,
  labels, manifests, weights, runs, and logs stay outside the public repo.
- Do not reuse or merge the 09/07 `uvautoboat_unicolor_smoke_2026-07-09` data.
- No Hailo compile / calibration / Tier 3 / HEF, no export, no deployment, no
  dashboard, MAVROS, QGC, Herelink, mission upload, arming, mode change,
  parameter write, thruster, or actuator work.
- No production repo Python / YAML changes; markdown diary updates only.
- One frozen training config; do not tune hyperparameters to chase a pass.
- Execution blocks start only after explicit approval.

## Block A - Repo Guard And Source Read

Run from the repo root: `git fetch --prune`, `git log --oneline -8`,
`git status --short --branch`, `git rev-parse HEAD origin/main`. Guard: stop if
fetch fails, dirty, ahead, or diverged.

Read first: this file; `working_diary/2026-07-09_thursday_unicolor_training_smoke.md`;
`working_diary/2026-07-10_friday_maritime_dataset_design.md`;
`wiki/YOLO_Dataset_Plan.md`. Record the starting SHA.

## Block B - External Multi-Scale Manifest

Before capture, write a manifest outside the repo defining:

- class map `0 black_object`, `1 green_object`, with the exact object identities;
- distance buckets by apparent size: `near` taller than about one third of frame
  height, `mid` about one tenth to one third, `far` below about one tenth;
- capture resolution decision: choose so the `far` bucket is actually labelable.
  The 09/07 `far` miss was roughly `30 px` objects at `640x480`; compare against
  a higher profile (for example `1280x720`) and record the chosen profile;
- many genuinely distinct scenes per bucket per split - this is the core 09/07
  fix. Not repeated static frames. Target a materially larger, more varied set
  than the 09/07 near-duplicate ~30 images (fill per-bucket per-split counts);
- split rule: `train`, `val`, and `tier3_eval` span the **same** near / mid /
  far range, but stay scene- and placement-disjoint. `calib_hailo` placeholder
  only;
- negatives in every active split at each bucket.

## Block C - Near / Mid / Far Capture

- Reuse `pi_unicolor_smoke.sh` preflight / snapshot; extend capture for scale and
  many distinct scenes at the chosen resolution.
- One camera owner; no live detector; no ROS / dashboard / `rqt_image_view`
  co-consumer.
- Per bucket, capture many distinct scenes - change placement, spacing,
  orientation, distance, and lighting between scenes rather than holding one
  static setup.
- Both bottles visible in every positive; capture negatives per bucket.
- Assign the split at scene time; keep scenes disjoint across `train`, `val`, and
  `tier3_eval`.
- Record camera, resolution, FPS, distance, measured apparent size, lighting, and
  rejected frames per scene. Copy artifacts back to the workstation root.

## Block D - Label And Lint

- X-AnyLabeling box mode or direct YOLO-Hbb boxes: `0 black_object`,
  `1 green_object`.
- Both objects boxed in every positive; empty label files for negatives.
- Lint before training (adapt the 09/07 lint helper to the new root and buckets):
  image-to-label one-to-one; empty labels only for negatives; class IDs in
  `{0, 1}`; coordinates normalized and inside `[0, 1]`; rejected frames absent
  from `images/*`; no scene ID in more than one split; `tier3_eval` genuinely
  scene-disjoint; per-bucket per-split counts met.

## Block E - One Frozen Retrain

- Clean CUDA-verified shell: `unset PYTHONPATH`, activate `~/venvs/yolo-ws`, and
  gate `torch.cuda.is_available()` (expect `True NVIDIA RTX A3000 Laptop GPU`).
- One frozen config. Record: model seed (`yolo26n.pt`), dataset YAML path, class
  names, `imgsz` (decide against the `far` bucket; higher helps small objects at
  a batch / VRAM cost on the 6 GB A3000), epochs, batch, device, seed, Ultralytics
  and torch versions, and the output run directory.
- No hyperparameter-chasing.

## Block F - Val / Tier3 Firing At conf 0.05 And 0.25

- Evaluate `best.pt` on `val` and on the held-out `tier3_eval` (`split=test`).
- Record per-image firing at `conf=0.25` and `conf=0.05`, plus `conf=0.01` as the
  noise-floor reference.
- Record the per-class held-out confidence distribution and mAP.
- Pass means usable-threshold firing (`conf >= 0.05`, ideally `>= 0.25`) on both
  `val` and `tier3_eval`.
- Compare directly against the 09/07 baseline (`val ~0.016`, `tier3 ~0.007`) to
  show whether the fixed multi-scale distribution moved firing above usable
  thresholds.

## Wrap

Update this diary with: starting SHA; manifest path; per-bucket per-split capture
counts; label lint counts; frozen config and run path; `val` and `tier3_eval`
firing at `conf 0.05` and `0.25`; exact blocker if any; bounded non-claims. Close
with `git status --short --branch`, `git diff --check`, and a clear
`**Next steps:**` hint. No export, deployment, or Hailo work.

## Explicit Non-Claims

- No Hailo compile, calibration, Tier 3, HEF, export, or deployment.
- No dashboard, MAVROS, QGC, Herelink, mission upload, arming, mode change,
  parameter write, thruster, or actuator path.
- No maritime detector-recovery claim; this is a proxy-data scale test only.
- Firing below usable thresholds is a recorded result, not a retune trigger.
- All data and manifests stay outside the public repo; markdown diary updates
  only; execution gated on explicit approval.

**Next steps:** On approval, start Block A repo guard, then design the external
multi-scale manifest with per-bucket per-split counts and the capture-resolution
decision before any capture.
