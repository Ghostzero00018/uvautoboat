# Friday 10/07/2026 - Scale-Recovery And Pi Hailo COCO Overlay

## Day Overview

The 09/07 unicolor smoke proved the real-image capture -> YOLO-Hbb label ->
split -> workstation train -> evaluation loop is mechanically valid, but the
trained model fired nowhere at a usable threshold (`val` peaked around `0.016`)
and completely missed the tiny held-out (`tier3_eval` around `0.007`, mAP50
`0.0`). The leading failure hypothesis is a data-distribution gap: too few
genuinely distinct examples plus a single dominant close object scale.

This test asks the one open question directly, on cheap objects and no water:
if the data distribution is fixed - many distinct `near` / `mid` / `far`
black / green scenes - does the same loop and same frozen-config family produce
usable-threshold firing (`conf >= 0.05`, ideally `>= 0.25`) on genuinely
held-out frames? A pass supports the scale / quantity hypothesis for this proxy
and carries that lesson into maritime data design. A fail despite fixed data
points past scale and quantity.

Today contains two independently gated tracks. Track 1 is the unicolor
scale-recovery experiment described above. Track 2 is a bounded, user-run Pi 5
Hailo-8L smoke using a stock COCO detector to produce colored bounding boxes
with class / confidence labels. The second track proves overlay mechanics only;
it does not advance Track 1, maritime recovery, export, or deployment.

Scheduling decision: run the bounded Pi overlay smoke on 10/07 as independent
Track 2 rather than defer it to a later standalone diary. The maritime dataset
design is rescheduled to Wednesday 15/07, leaving this file as the sole 10/07
diary; both tracks keep separate gates and evidence.

## Track 1 - Starting Context

- Repo start SHA: `1174a11fcf2a3a555319e09ca37a57f74d2c6065`.
- 09/07 result to beat: `val` peak `~0.016`, `tier3_eval` peak `~0.007`,
  `tier3_eval` mAP50 `0.0`.
- Class map, proven on 09/07, reused unchanged: `0 black_object`,
  `1 green_object` (black and green nuka cola bottles).
- Proven capture helper: `pi_unicolor_smoke.sh` (preflight / snapshot / capture,
  one-camera-owner start-stop). Reuse and extend for multi-scale capture.
- The 09/07 dataset (`uvautoboat_unicolor_smoke_2026-07-09`) is frozen. This test
  builds a new, separate external dataset and does not reuse or merge it.

## Track 1 - Success Definition

Success is one of:

1. a new multi-scale black / green dataset is captured, labeled, split, and
   trained once with a frozen config, and `best.pt` fires on genuinely held-out
   positives in **both** `val` and `tier3_eval` at `conf >= 0.05`, ideally
   `>= 0.25`; or
2. a precise blocker is recorded with evidence: capture route, labeling
   bottleneck, split leakage, GPU environment, or a firing failure that persists
   even with a fixed multi-scale distribution (which would point past scale /
   quantity).

Track 1 proves the proxy-data fix only. It is not maritime detector quality,
Hailo accuracy, Pi deployment, or dashboard integration.

## Shared And Track Boundaries

- Track 1 uses a new external dataset root, for example
  `/home/ghostzero/datasets/uvautoboat_unicolor_scale_2026-07-10/`. All images,
  labels, manifests, weights, runs, and logs stay outside the public repo.
- Do not reuse or merge the 09/07 `uvautoboat_unicolor_smoke_2026-07-09` data.
- Track 1 Blocks B-F do not use Hailo or a live detector.
- Track 2 may use only a stock, precompiled `HAILO8L` COCO HEF and an external
  reference runner. No Hailo compile, calibration, custom-model Tier 3,
  production HEF replacement, export, or deployment is allowed.
- Neither track uses ROS, dashboard, MAVROS, QGC, Herelink, mission upload,
  arming, mode change, parameter write, thruster, or actuator paths.
- The D435I has one owner during Track 2; no ROS camera node, dashboard camera,
  `rqt_image_view`, detector process, or other camera consumer may run.
- No production repo Python / YAML changes; Markdown-only repo updates (this diary
  and the reusable wiki procedure).
- One frozen training config; do not tune hyperparameters to chase a pass.
- Execution blocks start only after explicit approval.

## Track 1 - Block A Repo Guard And Source Read

Run from the repo root: `git fetch --prune`, `git log --oneline -8`,
`git status --short --branch`, `git rev-parse HEAD origin/main`. Guard: stop if
fetch fails, dirty, ahead, or diverged.

Read first: this file; `working_diary/2026-07-09_thursday_unicolor_training_smoke.md`;
`working_diary/2026-07-15_wednesday_maritime_dashboard_hailo_streaming.md`;
`wiki/YOLO_Dataset_Plan.md`. Record the starting SHA.

### Block A Evidence - 10/07/2026

- `git fetch --prune` completed, `main` matched `origin/main` at
  `1174a11fcf2a3a555319e09ca37a57f74d2c6065`, and the branch was clean with zero
  ahead / behind commits.
- The required source set was read. The maritime dataset diary is now the
  deferred 15/07 reference design; Track 1 in this diary remains the separately
  gated unicolor scale-recovery execution test.
- No new scale-recovery dataset artifacts were present under the repository
  root. Images, labels, manifests, data YAML, weights, runs, logs, and exports
  remain external-only for this test.
- Decisions retained for later blocks: the 09/07 dataset stays frozen and is not
  reused or merged; the class map remains `0 black_object`, `1 green_object` for
  the black and green nuka cola bottles.
- No external dataset root or manifest was created. Per-bucket / per-split
  counts, capture resolution, and training `imgsz` were not decided. Capture,
  labeling, training, evaluation, export, and deployment were not started.
- Exact Block A blocker: none. Block B remains intentionally gated pending
  explicit approval.

## Track 1 - Block B External Multi-Scale Manifest

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

## Track 1 - Block C Near / Mid / Far Capture

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

## Track 1 - Block D Label And Lint

- X-AnyLabeling box mode or direct YOLO-Hbb boxes: `0 black_object`,
  `1 green_object`.
- Both objects boxed in every positive; empty label files for negatives.
- Lint before training (adapt the 09/07 lint helper to the new root and buckets):
  image-to-label one-to-one; empty labels only for negatives; class IDs in
  `{0, 1}`; coordinates normalized and inside `[0, 1]`; rejected frames absent
  from `images/*`; no scene ID in more than one split; `tier3_eval` genuinely
  scene-disjoint; per-bucket per-split counts met.

## Track 1 - Block E One Frozen Retrain

- Clean CUDA-verified shell: `unset PYTHONPATH`, activate `~/venvs/yolo-ws`, and
  gate `torch.cuda.is_available()` (expect `True NVIDIA RTX A3000 Laptop GPU`).
- One frozen config. Record: model seed (`yolo26n.pt`), dataset YAML path, class
  names, `imgsz` (decide against the `far` bucket; higher helps small objects at
  a batch / VRAM cost on the 6 GB A3000), epochs, batch, device, seed, Ultralytics
  and torch versions, and the output run directory.
- No hyperparameter-chasing.

## Track 1 - Block F Val / Tier3 Firing At conf 0.05 And 0.25

- Evaluate `best.pt` on `val` and on the held-out `tier3_eval` (`split=test`).
- Record per-image firing at `conf=0.25` and `conf=0.05`, plus `conf=0.01` as the
  noise-floor reference.
- Record the per-class held-out confidence distribution and mAP.
- Pass means usable-threshold firing (`conf >= 0.05`, ideally `>= 0.25`) on both
  `val` and `tier3_eval`.
- Compare directly against the 09/07 baseline (`val ~0.016`, `tier3 ~0.007`) to
  show whether the fixed multi-scale distribution moved firing above usable
  thresholds.

## Track 1 - Wrap

Update this diary with: starting SHA; manifest path; per-bucket per-split capture
counts; label lint counts; frozen config and run path; `val` and `tier3_eval`
firing at `conf 0.05` and `0.25`; exact blocker if any; bounded non-claims. Close
with `git status --short --branch`, `git diff --check`, and a clear next-step
hint. No export or deployment; record any stock-COCO overlay evidence only under
Track 2.

## Track 1 - Explicit Non-Claims

- No Hailo compile, calibration, custom-model Tier 3, production HEF replacement,
  export, or deployment.
- No dashboard, MAVROS, QGC, Herelink, mission upload, arming, mode change,
  parameter write, thruster, or actuator path.
- No maritime detector-recovery claim; this is a proxy-data scale test only.
- Firing below usable thresholds is a recorded result, not a retune trigger.
- All data and manifests stay outside the public repo; markdown diary updates
  only; Track 1 execution remains gated on explicit approval.

## Track 2 - Pi Hailo COCO Box-Overlay Quick Test

### Purpose And Evidence Boundary

"Contour" in this track means the already-decided YOLO detection overlay:
colored bounding boxes with COCO class and confidence labels. It does not mean a
shape-hugging contour, segmentation mask, or polygon model.

The 08/07 Pi smoke already proved a single-process D435I -> Hailo ->
decode-summary loop for 30 frames at `8.61 FPS`, but the custom six-output HEF
did not fire. This track replaces that non-functional detector only for a stock
COCO mechanics demo. It does not reuse the custom six-output decoder and does
not change the maritime or unicolor detector path.

Track 2 succeeds when the exact stock artifact and runner contract are recorded,
one known-positive saved image produces a plausible annotated output, and a
short single-owner D435I run displays and saves live COCO boxes. A precise
compatibility, dependency, camera-selection, or runtime blocker is also a valid
recorded outcome.

External Pi root:
`~/hailo_coco_overlay_2026-07-10/`. Keep the runner checkout, isolated venv,
HEF, input image, logs, and annotated outputs there. Those runtime artifacts stay
external; only this diary and the reusable Markdown procedure (which embeds the
launcher source as documentation) are tracked in the repo.

### Overlay Gate A - Artifact And Contract Verification

- User-run on Pi `imt-aqua-drone@imtaquadrone-desktop` in a new one-shot
  terminal with no ROS environment sourced.
- Recheck the current host, kernel, Python, CPU temperature, `/dev/hailo0`,
  HailoRT CLI version, `fw-control identify`, D435I serial / firmware, free disk,
  and Hailo / PCIe / DMA fault tail before downloading or running anything.
- Require stable dedicated Pi power, the active cooler, D435I on USB 3, internet
  access, and no existing camera or Hailo consumer. Stop if any prerequisite is
  not green.
- Pin the external Hailo Apps standalone object-detection runner to release
  `26.03.1` and record its exact checkout SHA. Use a fresh root-local venv; do not
  modify the proven `~/venvs/hailo-rt-4.24.0` environment.
- Download only the official Model Zoo `v2.19.0` `hailo8l/yolov11n.hef` primary
  artifact for the first attempt. Record the exact URL, byte size, and SHA-256.
  Do not introduce the NMS-core fallback until the primary result is recorded.
- Run `hailortcli parse-hef` and stop unless the artifact reports `HAILO8L`, a
  `640x640x3` input, and the expected HailoRT postprocess output contract.
- The runner documents HailoRT `4.23.0`, while this Pi has `4.24.0`. Confirm the
  pinned runner's real CLI with `-h`, its isolated imports, and HEF load before
  treating the minor-version difference as compatible. Do not downgrade,
  reinstall, or alter the proven runtime stack to force this smoke.

### Overlay Gate B - Saved Annotated Still

- Use the pinned standalone runner with `yolov11n.hef` and one frozen,
  known-positive COCO JPEG. Prefer the runner's official sample input so the
  compatibility gate is not confounded by the D435I or scene content.
- Run headless under an outer timeout, save stdout / stderr, and write annotated
  output under `output/still/`.
- Pass only if the process exits cleanly, writes an annotated image, and visual
  inspection shows at least one plausible COCO class box with a confidence
  label.
- Stop before live capture if the app cannot import, load the HEF, postprocess
  detections, write output, or produce boxes on the known-positive image. Record
  the exact `4.23`-tested runner versus `4.24` runtime blocker rather than
  changing versions mid-test.

### Overlay Gate C - Bounded D435I Live Overlay

- Start only after Gate B passes and only as a user-run live test. Use two new Pi
  desktop / Remmina terminals: P1 for the foreground detector and P2 for the
  temperature watcher. Do not assume an SSH-only session can display a window.
- Recheck camera and Hailo ownership immediately before launch. Use the D435I
  color source at `640x480@15`; if automatic USB selection chooses the wrong
  RealSense node, stop and map the RGB node rather than guessing.
- Run the pinned standalone detector for `15 s`, with display, saved output,
  `15 FPS`, and an outer `30 s` timeout. P1 remains foreground and stoppable with
  Ctrl+C.
- P2 watches `/sys/class/thermal/thermal_zone0/temp`. Stop P1 immediately at
  `>= 80000`, on camera-open failure, repeated inference / postprocess errors,
  display failure, wrong source selection, Hailo fault output, or power warning.
- Pass when at least one obvious COCO target receives a plausible live class /
  confidence box and the annotated stream is saved. Otherwise record the exact
  blocker without extending duration, changing models, or opening another
  integration path.

### Overlay Gate D - Evidence Record

Record the runner release and checkout SHA; HEF source, size, and SHA-256;
HailoRT / firmware / driver versions; HEF input and postprocess contract; input
source and profile; saved-still result; live duration / frames / FPS; before,
peak, and after temperature; annotated output paths; error / fault tail; and the
exact blocker if any.

### Overlay Gate Evidence - 10/07/2026

Overlay Gates A-C passed and Gate D records the evidence below; the only temperature
gap is the earlier free-run's post-run reading (the later launcher run's is recorded
at `57.85 C`). The stock-COCO live overlay path is
proven on the Pi. Everything stayed under the external root
`~/hailo_coco_overlay_2026-07-10/`.

- Gate A preflight: host `imtaquadrone-desktop`, kernel `6.8.0-1060-raspi`, Python
  `3.12.3`, `/dev/hailo0` present, no camera or Hailo consumer, `throttled=0x0`,
  `59.5 C`, `35 GiB` free. HailoRT CLI and firmware `4.24.0`, device `HAILO8L`.
  D435I serial `213622070342`, firmware `5.14.0`, USB `3.2`. GitHub and the
  model-zoo S3 host resolved. Kernel tail clean: Hailo firmware loaded in
  `177 ms`, ASPM L0s disabled, no DMA / AER / under-voltage faults.
- Gate A runner and HEF: Hailo Apps standalone object-detection release `26.03.1`,
  checkout `891ce701c2ebe239a5d277759eb75a30f76678a9`, in a fresh root-local venv
  (the proven `~/venvs/hailo-rt-4.24.0` runtime was left untouched). HEF: Model
  Zoo `v2.19.0` `hailo8l/yolov11n.hef`, `11712608` bytes, SHA-256
  `d08e140e61befc4fe3c8e5c2d10969fec258bc411363de6813e8b1778dc7cb8e`. Contract:
  input `640x640x3`, output `yolov8_nms_postprocess` (HAILO NMS BY CLASS, `80`
  classes, score `0.20`, IoU `0.70`). HailoRT runs this NMS post-process on the
  host CPU (`engine=cpu` in the model-zoo `.alls`; the `..._nms_core` build runs it
  on the NPU core), so the runner gets final decoded boxes and no host decoder was
  written.
- Compatibility: the runner documents HailoRT `4.23.0` and this Pi runs `4.24.0`;
  the gap was confirmed in practice (imports, HEF load, and live inference all
  succeeded), not assumed.
- Gate B saved still: the pinned runner on the bundled `bus.jpg` exited cleanly
  and wrote `output/still/output_0.png` with correct COCO boxes and labels -
  `bus 93.5%` and four people at `86.8 / 85.3 / 82.7 / 42.5%`.
- Gate C live D435I: the RGB color node was mapped to `/dev/video4` (`YUYV`);
  depth `/dev/video0` and infrared `/dev/video2` were correctly avoided. A bounded
  `15 s` run at `640x480` processed `225` frames at `14.97 FPS`, exited cleanly,
  and saved annotated frames to `output/live`. The live overlay was observed
  producing boxes during this run and the free-run; the confidences are rendered in
  the saved annotated output but were not transcribed or independently inspected, so
  the verified per-box evidence is the Gate B still.
- Extended free-run: an unbounded live run held over five minutes at about `65 C`
  with no throttle and no stop, saved under `output/live_freerun`. Session
  temperature ran `59.5 C` at preflight, `60.6 C` at the contract phase, and about
  `65 C` peak during the free-run (post-run cool-down temperature not recorded).
  Recorded as a single-session observation, not a sustained-thermal qualification.
- Launcher re-validation: two reproducible bounded `20 s` runs on `/dev/video4`, both
  clean exits (`RC=0`). SD (18:25, SHA-256 `7c9d89d2...`): `300` frames at `14.96 FPS`,
  peak `63 C`, post-run `57.85 C`, `throttled=0x0`, `640x480` output; live boxes
  confirmed on extracted frames (`bottle`, `tv`, `laptop`, `mouse`). HD (18:56, SHA-256
  `64426ec4...`, the `OUTRES` window-size version): `res=hd outres=hd`, `281` frames at
  `13.99 FPS`, peak `67 C`, post-run `58.4 C`, `throttled=0x0`, saved AVI a true
  `1280x720` with no distortion. Together these capture the per-run post-run
  temperature the earlier free-run bullet omitted and Pi-validate the current launcher.
- Exact blocker: none for the stock-COCO overlay. The first preflight aborted on a
  helper issue - `vcgencmd get_throttled` needs `/dev/vcio` access this user lacks
  (no `video` group) - fixed by reading the throttle flag through cached sudo and
  continuing on a clear warning when unavailable; every other step passed first
  try.

### Track 2 - Explicit Non-Claims

- No literal contour or segmentation result.
- No maritime or unicolor detector recovery, custom HEF compatibility, detector
  accuracy, compile, calibration, export, deployment, or sustained thermal claim.
- No ROS image path, dashboard, MAVROS, QGC, Herelink, FCU, mission upload,
  arming, mode change, parameter write, thruster, or actuator work.
- A pass proves only this short Pi D435I -> stock COCO HEF -> HailoRT
  postprocess -> box overlay -> display / save path.

## Daily Wrap

Track 1 Block A is complete; Track 1 Block B remains unstarted and requires a
separate explicit approval. Track 2 is complete: overlay Gates A-C passed and Gate D
records the evidence (the earlier free-run's post-run temperature is the only gap),
proving the Pi
`D435I -> Hailo -> HailoRT NMS -> COCO box overlay -> display / save`
path with a stock `yolov11n` HEF at `14.97 FPS`; an added five-minute free-run held
about `65 C` as a single-session observation, not a sustained-thermal result. This
is stock-COCO mechanics only, not maritime or custom-detector recovery, and the
maritime and unicolor detector paths are unchanged.

**Next steps:** The Track 2 overlay smoke is closed. A future maritime or unicolor
detector reuses this runner as a drop-in only if its HEF is compiled with the same
HailoRT NMS-by-class output; a raw or multi-output HEF (like the earlier custom
six-output one) still needs a host decoder and a pipeline change. Track 1 Block B
(external multi-scale manifest) stays gated on explicit approval, and the deferred
15/07 maritime design remains the next planning item.
