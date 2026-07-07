# Wednesday 08/07/2026 - Detector Recovery Block (Workstation + Acquisition Planning)

## Day Overview

The Hailo saved-frame decode contract is proven (07/07/2026, `fb308f9`), so the
Hailo branch is intentionally paused. The real blocker is upstream: the current
`best.pt` is non-functional and fires on nothing, because the dataset only ever
contained one class. This block rebuilds the detector in order: baseline
inventory, data-source decision, source-specific acquisition manifest,
collect/label to the sizing target, retrain, and prove the new model fires on a
held-out set. Hailo accuracy-grade calibration and Tier 3 only reopen after
that.

## Success Definition

Success is one of:

1. a source-specific acquisition manifest plus a materially larger multi-class
   labeled dataset that meets the sizing target, a retrained `best.pt` that
   fires on held-out `tier3_eval` at sane confidence, and a recorded held-out
   confidence distribution with per-class coverage; or
2. a precise, evidence-backed blocker (for example no maritime capture access
   this week) with the data-source decision and acquisition manifest recorded so
   the collection can proceed as soon as the blocker clears.

Non-goals: any Hailo compile / calibration / Tier 3, Pi inference, detector
deployment, or live integration work.

## Starting Context (verified 07/07/2026)

- Dataset root: `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/`. Current
  split is `9` train / `2` val images. Label reality: **`9` labeled instances,
  all class `person`; `buoy`, `vessel`, `dock`, and `obstacle` have zero
  examples.** `data.yaml` declares five classes `0 buoy, 1 vessel, 2 dock,
  3 obstacle, 4 person`.
- `best.pt` at `runs/baseline_yolo26n/weights/best.pt` (50 epochs on the 9-box
  pilot). Reconnaissance on 07/07: peak confidence below `0.01` on all `50`
  available frames (`9` train + `2` val + `28` calib + `11` raw), including its
  own training images; confidence ceiling about `0.003`. Non-functional as a
  reference detector.
- Mechanics-only calibration set `calib_raw_28` (28 mixed frames) at
  `/home/ghostzero/hailo_artifacts/2026-07-02/suite_run/shared_with_docker/yolo26n_route_a/calib_raw_28/`.
- The four-way split contract and collection sizing target are recorded at
  `c09b090` in `wiki/YOLO_Dataset_Plan.md` (four-way scene-disjoint
  `train`/`val`/`calib_hailo`/`tier3_eval`; hundreds of instances per active
  class; a few hundred `calib_hailo` frames).
- Hailo status: decode proven at `fb308f9`; the branch is paused on detector
  quality, not on any Hailo defect.

## Boundaries

- No Hailo compile, calibration, or Tier 3 in this block. No Pi inference or
  integration, no live RealSense inference, no ROS wiring, no dashboard, no
  MAVROS / QGC / Herelink, no mechanics-only Tier 3.
- Single camera exception: RealSense RGB **capture for dataset collection** is
  in scope, because it is the point of the block. It is a separate
  hardware / logistics task, may be gated by capture-location access, and runs
  no inference stack during capture.
- All dataset artifacts (raw frames, labels, weights, runs,
  manifests / inventories) stay outside the public repo.
- No Python / YAML edits without explicit permission. Training commands run on
  the workstation GPU and are user-run.

## Block A - Repo Guard And Baseline Inventory

Guard the repo (`git fetch --prune`, `git status`, record starting SHA). Then
inventory as baseline evidence only, no changes:

- Dataset root tree, per-class instance counts across `train` + `val`, and the
  current `best.pt` training config.
- Recap the 07/07 firing reconnaissance as the documented "before" state.

Confirm the baseline: five declared classes, one class with data, model fires on
nothing.

## Block B - Data Source And Acquisition Decision

Decide where the multi-class maritime frames come from, since four of five
classes currently have zero data and need source coverage. Weigh and record:

- on-water / dockside RealSense capture (needs water access);
- supplementary public maritime detection datasets (licence and class-map
  alignment checked);
- VRX-rendered frames (strong bootstrap candidate for buoy / vessel / dock
  coverage, with a domain-gap caveat versus real RealSense input);
- a documented mix.

Record the chosen source(s) and why. This decision gates whether the sizing
target is reachable in the available time. If maritime access is not available
this week, VRX-primary bootstrap plus real RealSense `person` data may be the
best first-pass recovery route, but it validates detector-recovery plumbing and
later Tier 3 mechanics only; real-world detector quality still needs real
maritime frames.

## Block C - Source-Specific Acquisition Manifest

Build a manifest / inventory outside the repo **before** any capture,
download, or render. Its shape depends on Block B:

- RealSense capture: one row per planned physical scene:

  | scene_id | date/time | location + conditions | target classes | intended split | est. frames |
  | --- | --- | --- | --- | --- | --- |
  | example | 08/07 14:00 | dock, bright, mid distance | vessel, dock | train | 40 |

- Public dataset: one row per source / subset, including licence, class-map
  alignment, planned class use, intended split, and reject criteria.
- VRX render: one row per rendered scenario, including world / asset setup,
  target classes, environmental variation, intended split, and frame count.

Rules: assign the intended split at manifest time; keep scene / source /
scenario-level disjointness across all four splits per the `c09b090` contract;
`tier3_eval` scenes are held out from `train`, `val`, and `calib_hailo`.
Conditions should vary (lighting, distance, background, sea state / simulated
state) so the splits are not trivially correlated.

## Block D - Collect And Label To The Sizing Target

Capture, acquire, or render per manifest; review / dedup; label with the
first-pass class rules in `wiki/YOLO_Dataset_Plan.md`; keep scene / source /
scenario-level split separation; rejected frames stay out of all four splits.
Target hundreds of instances per active class, a few hundred `calib_hailo`
frames, and enough `tier3_eval` positives plus negatives for a meaningful
held-out distribution. This is likely a multi-day effort, not a single day; size
the campaign accordingly.

## Block E - Retrain

Retrain `best.pt` on the workstation GPU (user-run), fixed config. Record
epochs, `imgsz`, augmentation, dataset counts per class per split, and the
Ultralytics version.

## Block F - Prove Firing And Record Distribution

Run the new `best.pt` on held-out `tier3_eval`:

- confirm it fires at sane confidence (not noise-floor);
- record the per-class confidence distribution at fixed thresholds and per-class
  coverage (every class represented and detected at least once);
- flag any class that still does not fire.

Gate: if the retrained model still does not fire on held-out positives, stop and
rebalance / collect more before touching Hailo. Do not lower the threshold into
noise to claim a pass.

## Block G - Reopen-Hailo Gate

Only if Block F passes: a later, separate block compiles an accuracy-grade HEF
from `calib_hailo` and runs Tier 3a (full precision) then Tier 3b (quantized)
versus Ultralytics on `tier3_eval`. Not this block.

## Wrap

Update this diary with the baseline inventory, the data-source decision, the
source-specific manifest / inventory, collection / acquisition / render and
label counts per class per split, the retrain config, the held-out confidence
distribution with per-class coverage, and the reopen-Hailo gate result or the
exact blocker. Close with a clean tree and a `**Next steps:**` hint.

This block is detector-recovery evidence only. It is not Hailo calibration /
Tier 3, Pi saved-frame inference, live RealSense inference, ROS image input,
dashboard, MAVROS, QGC, Herelink, command / write, mission-upload, arming,
mode-change, parameter-write, thruster, or actuator evidence.
