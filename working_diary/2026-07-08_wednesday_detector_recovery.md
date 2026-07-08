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

## Session Evidence - 08/07/2026

Repo guard passed before detector-recovery planning:

- `git fetch --prune` completed.
- `main` matched `origin/main` at
  `69f7ad5a3e5ae46a60ac9ccac800be731121b5d4`.
- `git status --short --branch` returned `## main...origin/main`.
- No pull was needed.

Block A baseline inventory:

- Dataset root:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/`.
- Existing YOLO split directories:
  `images/train`, `images/val`, `labels/train`, `labels/val`; no populated
  `images/calib_hailo`, `images/tier3_eval`, `labels/calib_hailo`, or
  `labels/tier3_eval` split exists in the dataset root yet.
- Current split counts:

  | Split | Images | Label files | Labeled instances | Empty labels |
  | --- | ---: | ---: | ---: | ---: |
  | `train` | 9 | 9 | 7 | 3 |
  | `val` | 2 | 2 | 2 | 1 |
  | `calib_hailo` | 0 | 0 | 0 | 0 |
  | `tier3_eval` | 0 | 0 | 0 | 0 |

- Per-class labeled instances across `train` + `val`:

  | Class ID | Class | Instances |
  | ---: | --- | ---: |
  | 0 | `buoy` | 0 |
  | 1 | `vessel` | 0 |
  | 2 | `dock` | 0 |
  | 3 | `obstacle` | 0 |
  | 4 | `person` | 9 |

- `data.yaml` class order is still:
  `0 buoy`, `1 vessel`, `2 dock`, `3 obstacle`, `4 person`.
- The reviewed raw pool still has 11 active raw images under
  `raw/2026-06-24_pi_realsense_rgb/` plus 17 rejected frames. The
  mechanics-only Hailo calibration source remains separate:
  `calib_raw_28` has 28 frames under the Hailo artifact workspace, but it is not
  a scene-disjoint four-way dataset split.
- Current checkpoint:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt`
  exists. The training run metadata records `model: yolo26n.pt`, `epochs: 50`,
  `imgsz: 640`, `batch: 16`, `device: '0'`, `data: data.yaml`, and
  `project: /home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs`.
- The 07/07 "before" state stands: the current `best.pt` returned zero
  detections at `conf=0.25`, including on the 28 saved calibration frames used
  during the decode work; the broader reconnaissance recorded in this scaffold
  found no detections across the 50 available frames, with confidence below
  `0.01` and a ceiling near `0.003`.

Block B data-source decision:

- Use a documented mix, with VRX-rendered frames as the first bootstrap source
  only for the classes that the current local worlds can represent cleanly:
  `buoy` and `dock`.
- Treat VRX `vessel` as spawn-required: `roboboat01` and `roboboat02` exist as
  local models, but they are not spawned in the current VRX worlds.
- Treat VRX `obstacle` and `person` as unsupported without an explicit
  class/source decision. The current VRX `obstacle_course` is round buoys only,
  and the current VRX asset set has no human source.
- Keep RealSense dockside / on-water capture as the required real-domain source
  before detector-quality claims, and as the required source for real `vessel`,
  `obstacle`, and `person` positives unless another approved source is added.
- Do not admit public maritime datasets into this first manifest. A future
  public-source row needs an explicit licence check, class-map alignment, split
  assignment, and reject criteria before any download or conversion.
- VRX is a training-framework and plumbing bootstrap only: it can validate the
  split contract, labeling workflow, retraining path, and later saved-frame
  comparison mechanics, but it is not real-world detector-quality evidence.

Block C manifest:

- Manifest path:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/manifests/2026-07-08_detector_recovery_manifest.md`.
- Manifest summary:
  8 VRX-render rows and 6 RealSense capture rows, each with intended split
  assigned at manifest time. The revised VRX plan covers `train`, `val`,
  `calib_hailo`, and `tier3_eval` for `buoy` / `dock` bootstrap evidence with
  scenario-level disjointness, marks `vessel` as spawn-required, and marks
  `obstacle` / `person` as unsupported by the current VRX asset set. The
  RealSense plan keeps train, validation, calibration, and held-out real-domain
  scenes separate until water / dock access is available.
- No capture, download, render, labeling, retraining, Hailo calibration, or
  Tier 3 execution was run in this session.

Exact blocker:

- The blocker is still missing materially larger multi-class labeled data.
  Today built the training framework: baseline inventory, source decision, and
  split-aware acquisition manifest. Detector retraining is blocked until the
  manifest is executed and the labeled data is materially larger than the 9-box
  pilot.
- A VRX-only execution of Block D can at most prove first-pass firing for
  `buoy` and `dock`; `vessel`, `obstacle`, and `person` held-out positives
  require RealSense capture, public data admitted through the checklist, or
  explicit VRX world / asset authoring.

Bounded non-claims:

- Hailo decode remains proven and closed at `fb308f9`; Hailo is paused on
  detector quality, not on a Hailo defect.
- The next Hailo gate remains positive-bearing saved-frame Tier 3, but it must
  not reopen until a retrained detector fires on held-out positives at sane
  confidence.
- Blocks A-C did not produce new dataset images, labels, weights, runs,
  detections, calibration frames, live inference, ROS image input, dashboard,
  MAVROS, QGC, Herelink, mission-upload, arming, mode-change,
  parameter-write, thruster, or actuator evidence.
- VRX-majority `calib_hailo` is not an accuracy-grade calibration source for the
  real RealSense deployment distribution. Accuracy-grade Hailo work still needs
  representative real calibration frames after detector recovery.

**Next steps:** Start Block D only after explicit approval: execute the external
manifest outside the repo, beginning with the VRX bootstrap if real maritime
access is unavailable this week, then label and split before any retraining.

## EOD Note - 08/07/2026

The day closes at Blocks A-C. Block D was discussed but not started.

Next practical step, only after an explicit Block D start signal: run a minimal
VRX smoke rather than the full synthetic campaign if real dock / water access is
not confirmed. Scope it to the supported VRX classes only (`buoy`, `dock`) and
keep the five-class `data.yaml`; record `vessel`, `obstacle`, and `person` as
untrained / unsupported for this smoke.

Smoke pass condition is mechanics, not detector quality:

- render / capture staging, label export, split creation, and label lint run
  end to end outside the repo;
- split proof shows genuinely disjoint held-out positives, including the
  displaced `dock_2022` pose at `-540 210 0` and distinct buoy viewpoints;
- retrain uses one frozen config with no hyperparameter tuning;
- the eval harness emits a per-class confidence distribution on held-out frames;
- `tier3_eval` has at least about five held-out positives each for `buoy` and
  `dock`, and any firing is clearly above the old `~0.003` noise ceiling.

Non-claims stay unchanged: a VRX-only smoke validates the data / label / split /
retrain / eval harness. It does not validate real RealSense detector quality, it
does not train `vessel`, `obstacle`, or `person`, and it does not reopen Hailo.

## Pre-EOD Hailo Loop Readiness Check - 08/07/2026

A quick workstation-side readiness check was run for the requested
Pi-capture -> workstation-train -> Pi-return -> live-detect loop. Result:
the loop is not ready to claim as a quick Hailo test today.

Confirmed pieces:

- `nvidia-smi` saw the workstation `NVIDIA RTX A3000 Laptop GPU`.
- Dataset root, `data.yaml`, the current `best.pt`, and the 08/07 external
  acquisition manifest exist under
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/`.
- The current Hailo HEF artifact exists at
  `/home/ghostzero/hailo_artifacts/2026-07-02/pi_payload_2026-07-02/yolo26n_route_a_six_heads.hef`.
- Repo search found no existing Pi-side shell launcher or Python runner that
  starts the RealSense camera and performs Hailo live detection from the custom
  HEF.

Blocking facts:

- The current selected workstation YOLO environment reported
  `torch.cuda.is_available() == False` in this shell, despite the GPU being
  visible to `nvidia-smi`; rerun from a normal workstation terminal or fix the
  environment before any retrain.
- The four-way `calib_hailo` and `tier3_eval` dataset directories still do not
  exist in the dataset root.
- The only available custom `best.pt` is still the 9-box pilot checkpoint, and
  the current HEF was compiled from that non-functional detector. Copying it to
  the Pi for live detection would only prove launch mechanics, not detector
  recovery.

Correct next shape:

1. Capture or render frames per the manifest, keeping split assignment at source
   time.
2. Label and lint, then create scene-disjoint `train`, `val`, `calib_hailo`,
   and `tier3_eval` splits outside the repo.
3. Retrain on the workstation from a CUDA-visible YOLO environment.
4. Prove the new `best.pt` fires on held-out `tier3_eval` positives above the
   old `~0.003` noise floor.
5. Only then compile a new Hailo HEF, copy it to the Pi, run saved-frame Hailo
   validation, and add a Pi shell launcher for camera + Hailo live detection.

No Pi camera launch, Hailo compile, Hailo calibration, Pi inference, live
RealSense inference, ROS image integration, dashboard integration, MAVROS, QGC,
Herelink, mission upload, arming, mode change, parameter write, thruster, or
actuator path was run in this check.

## Pi Hailo Runtime Smoke - 08/07/2026

After the readiness check, a bounded Pi-side runtime smoke was run from an
external artifact directory, not from repo code:
`~/hailo_live_smoke_2026-07-08/`.

Check stage passed:

- single interpreter imports passed for HailoRT, RealSense, NumPy, and OpenCV;
- HEF parsed with one `640x640x3` input and six YOLO output tensors:
  `80x80x4`, `80x80x5`, `40x40x4`, `40x40x5`, `20x20x4`, and `20x20x5`;
- RealSense enumerated one `Intel RealSense D435I`, serial `213622070342`,
  firmware `5.14.0`.

Runtime stage passed as a launch-mechanics proof:

- camera opened at `424x240@15`;
- Hailo inference loop processed `30` frames and exited cleanly;
- output tensors arrived as dequantized `float32`;
- per-frame inference time was about `15-27 ms`;
- summary reported `processed=30`, `elapsed_s=3.49`, `fps=8.61`;
- maximum class probability stayed around `0.00262-0.00265`, with
  `score_cells_ge_conf=0` on every frame.

Bounded interpretation: this proves the Pi can run the single-process
RealSense -> Hailo -> decode-summary loop against the current HEF. It does not
prove detector recovery, target detection, RealSense-domain model quality,
workstation retraining, HEF recompilation, Hailo calibration, saved-frame Tier
3, ROS image input, dashboard integration, MAVROS, QGC, Herelink, mission
upload, arming, mode change, parameter write, thruster, or actuator behavior.
Zero detections remain the expected result for the current non-functional pilot
detector.

## Visual Target Decision - 08/07/2026

The live visual-feedback target for the detector is a YOLO-style detection
overlay: per-class colored bounding boxes with class and confidence text labels
(the standard detection-demo look), not instance-segmentation masks or
shape-hugging contours. This was confirmed against a standard YOLO
object-detection reference, which predicts bounding boxes filtered by
non-maximum suppression, not pixel masks.

Consequences pinned before Block D labeling starts:

- Training labels stay YOLO-Hbb boxes (class plus normalized `xywh`); labeling
  continues in box mode, not polygons.
- No segmentation model, polygon/mask labels, or separate compile path is in
  scope for this target.
- The overlay is a later runner-owned step (annotated MJPEG or saved frames
  first, dashboard integration afterward), gated on a retrained detector that
  fires on held-out positives. Not started today; the current HEF draws nothing,
  so there is no overlay to build yet.

**Next steps:** Start Block D only on explicit approval: run the minimal VRX
`buoy` / `dock` smoke if real water access is still unavailable, keep labels as
YOLO-Hbb boxes, then retrain only after materially larger held-out positives
exist.
