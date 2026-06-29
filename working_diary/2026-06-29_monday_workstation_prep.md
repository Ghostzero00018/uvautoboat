# Monday 29/06/2026 - Workstation YOLO prep and docs hygiene

## Day Overview

Continue from the pushed 26/06/2026 YOLO / RealSense and MAVProxy closeout.
Monday should be a workstation work day, not a pure buffer. Start with a short
docs/status hygiene sweep because `Board.md`, `wiki/Roadmap.md`, and
`wiki/YOLO_Dataset_Plan.md` were just refreshed in commit `c3273ed`; if that
sweep is clean, move to the useful unblocked workstation work: prepare a
separate `imgsz=320` NCNN export for the custom model, then decide whether any
realistic Block G dataset/model planning can be advanced.

Expected starting repo state: `main` clean/synced at `c3273ed` or later.

## Starting Context

- 26/06/2026 durable docs were refreshed in commit `c3273ed`.
- Headless RealSense / YOLO testing separated the remote-desktop thermal
  confound from deployment load: the camera-on / no-NCNN floor was about
  `51.03 C`, not the earlier desktop-session `70.9 C`.
- Short headless ROS-camera -> custom NCNN inference passed at `imgsz=640`:
  `150` frames in `18.8 s`, `mean_fps=7.98`, `mean_inf_ms=123.8`, no
  `80.0 C` abort.
- Sustained headless ROS + NCNN inference at the current `imgsz=640` profile
  failed the thermal gate, climbing through `80.4-82.05 C` aborts. Do not call
  sustained inference viable yet.
- `pyrealsense2 2.58.2` is proven only in the separate
  `~/venvs/yolo-pi5-rs`; it must stay separate from `~/venvs/yolo-pi5`.
- Direct camera-only SDK capture passed (`900` frames / `60.0 s` /
  `14.99 fps`), and short direct-SDK -> custom NCNN inference passed
  (`150` frames / `23.1 s` / `mean_fps=6.51` / `mean_inf_ms=151.9`), but it
  showed no meaningful capture-overhead advantage over the ROS path.
- The optional direct `imgsz=320` run segfaulted after model load. A real
  low-resolution thermal test needs a separate workstation NCNN export at
  `imgsz=320`, not a helper rewrite.
- All custom live detections remain `0` boxes. This is still a
  data/model/threshold issue, not a camera-path failure.
- The tiny pilot dataset remains outside the repo at
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06`. It is pipeline
  validation only, not detector-quality data.
- The late 26/06/2026 MAVProxy check was camera-off. MAVProxy opened
  `/dev/ttyAMA0:57600`, but no heartbeat arrived and it reported
  `link 1 down` after the box had relaunched without the usual startup
  music/sound. Treat this as a physical power/wiring follow-up for Tuesday
  30/06/2026 before rerunning MAVProxy/MAVROS.

## Boundaries

- In scope: quick docs maintenance, workstation-only `imgsz=320` export prep,
  and workstation-only dataset/model planning.
- Markdown docs may be edited if a current-facing stale claim is found.
- Workstation artifacts stay outside the repo under
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06`.
- Do not edit Python, YAML, launch files, JavaScript, package files, shell
  scripts, or helper code unless the user explicitly asks for that work.
- Do not run RealSense, YOLO inference on the Pi, MAVProxy, MAVROS, QGC,
  Herelink, dashboard, or real-FCU tests on Monday unless the user explicitly
  starts a separate live block.
- Do not mutate `~/venvs/yolo-pi5`. Do not install packages from this Monday
  scaffold.
- Do not collect easy extra person images just to increase count. Useful new
  data means operational classes or realistic proxies from the boat-level
  viewpoint.
- Keep copied logs, generated models, datasets, and export runs outside the
  repo.
- Past `working_diary/` entries are historical. Append current notes or update
  live docs; do not rewrite old diary evidence.

## Block A - Repo Guard And Source Read

Run first:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Guard:

- If `git fetch --prune` fails while on normal internet WiFi, stop and report.
- If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- If ahead, diverged, or dirty, stop and report before continuing.

Read first:

- `working_diary/2026-06-29_monday_workstation_prep.md`
- `working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md`
- `working_diary/2026-06-25_thursday_yolo_training_gate.md`
- `Board.md`
- `wiki/Roadmap.md`
- `wiki/YOLO_Dataset_Plan.md`
- `README.md`
- `USER_MANUAL.md`
- `wiki/Home.md`
- `working_diary/README.md`

Record the exact starting SHA and whether a pull was needed.

**Outcome:** repo guard passed on 29/06/2026 before any branch decision or
edit. `git fetch --prune` completed, `git log --oneline -5` showed
`389b659 docs(diary): scaffold 29/06 workstation prep` at HEAD, and
`git status --short --branch` showed clean `## main...origin/main`.
`git rev-parse HEAD origin/main` returned the same SHA for both refs:
`389b659cf2fb1b688748f467135b51f33629434e`. No pull was needed.

Files inspected before work: this diary, the 26/06 and 25/06 YOLO diaries,
`Board.md`, `wiki/Roadmap.md`, `wiki/YOLO_Dataset_Plan.md`, `README.md`,
`USER_MANUAL.md`, `wiki/Home.md`, and `working_diary/README.md`.

## Block B - Monday Scope Decision

Default route:

1. Run the quick docs/status sweep in Block C.
2. If stale current-facing Markdown is found, patch it narrowly.
3. If the sweep is clean or only minor, move to Block D for the workstation
   `imgsz=320` NCNN export.
4. If the export is prepared, use Block F to decide the realistic dataset/model
   branch.

Do not convert Monday into a live hardware day by drift. The MAVProxy physical
power/wiring follow-up is already bounded to Tuesday 30/06/2026 unless the user
explicitly reschedules it.

**Outcome:** default workstation route selected: quick docs/status hygiene
sweep first, then the `imgsz=320` NCNN export, then dataset/model planning.
No live Pi, RealSense, MAVProxy, MAVROS, QGC, Herelink, dashboard, or real-FCU
test was started.

## Block C - Quick Current-State Docs Sweep

This is a warm-up, not the whole day. Check for stale or incomplete
current-facing claims after the 26/06/2026 closeout:

```bash
rg -n "pyrealsense2.*remain|remain.*pyrealsense2|direct.*SDK|sustained.*unproven|sustained.*not viable|80\\.4-82\\.05|imgsz=320|link 1 down|30/06/2026" Board.md wiki README.md USER_MANUAL.md working_diary/README.md
rg -n "26/06/2026|51\\.03|52\\.19|14\\.989|6\\.51|151\\.9|7\\.98|123\\.8|0 boxes|thermal gate|capture-overhead" Board.md wiki/Roadmap.md wiki/YOLO_Dataset_Plan.md README.md USER_MANUAL.md
rg -n "Last updated|Last Updated|Document Version|Revision log|Timeline|Next steps" Board.md wiki README.md USER_MANUAL.md working_diary/README.md
```

Classify findings:

- Current-facing stale claim to fix now.
- Historical row or diary note that must stay unchanged.
- Generic guide wording that needs a short current-state caveat.
- Optional refresh that can be deferred.

Expected correct current state:

- Direct `pyrealsense2` is no longer unrun: camera-only and short direct-SDK
  -> NCNN mechanics are proven in the separate venv.
- Sustained inference at the current `imgsz=640` profile is tested and not
  viable yet, not merely untested.
- Direct SDK showed no meaningful overhead advantage over the ROS path.
- A real `imgsz=320` test needs a separate workstation NCNN export at
  `imgsz=320`.
- MAVProxy/MAVROS install history remains valid, but the current 26/06/2026
  heartbeat failure is a physical power/wiring caveat to inspect on Tuesday
  30/06/2026.
- `0` detections remain a dataset/model/threshold issue.

If no stale current-facing docs are found, record a negative docs result and do
not stretch the sweep.

**Outcome:** the three scaffolded `rg` sweeps were run across the requested
current-facing docs. Classification:

- Current-facing stale claim to fix now: `Board.md` top and footer metadata
  still said `25/06/2026` even though the 26/06 YOLO / RealSense and MAVProxy
  rows were already present. Fixed narrowly by updating `Last Updated` to
  `26/06/2026` and `Document Version` to `9.35`.
- Historical rows or diary notes to leave unchanged: dated 09/06, 25/06, and
  26/06 Board/Roadmap rows, including the earlier stock `imgsz=320` COCO
  feasibility result and the 26/06 `link 1 down` caveat.
- Generic guide needing a short caveat: none found in `README.md`,
  `USER_MANUAL.md`, `wiki/Home.md`, or `working_diary/README.md`.
- Optional refresh deferred: stale-looking generic `Last updated` stamps in
  non-status index/manual files were not YOLO status claims and were left
  unchanged.

## Block D - Workstation `imgsz=320` NCNN Export Prep

Run only after Block C is recorded or explicitly skipped by the user.

Purpose: create a separate low-resolution NCNN export so Tuesday's Pi session
can test the real software thermal lever without reusing the fixed-shape
`imgsz=640` export.

Workstation only. Do not touch the Pi or `~/venvs/yolo-pi5`.

Precheck:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
source ~/venvs/yolo-ws/bin/activate
python -c "import ultralytics, torch, ncnn; print('ultralytics', ultralytics.__version__); print('torch', torch.__version__, 'cuda', torch.cuda.is_available()); print('ncnn ok')"
test -f runs/baseline_yolo26n/weights/best.pt
```

Prepare an isolated export source so the existing `imgsz=640` export is not
overwritten:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
mkdir -p runs/export_imgsz320
cp runs/baseline_yolo26n/weights/best.pt runs/export_imgsz320/best_imgsz320.pt
yolo export model=runs/export_imgsz320/best_imgsz320.pt format=ncnn imgsz=320
find runs/export_imgsz320 -maxdepth 3 -type f \( -name "*.param" -o -name "*.bin" \) -print -exec ls -lh {} \;
```

Expected artifact shape:

- `runs/export_imgsz320/best_imgsz320_ncnn_model/model.ncnn.param`
- `runs/export_imgsz320/best_imgsz320_ncnn_model/model.ncnn.bin`

If the export command writes to a different path, record the exact path and do
not guess. If it fails, paste the error and stop before any Pi work.

**Outcome:** workstation export prep passed. The precheck used:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
source ~/venvs/yolo-ws/bin/activate
python -c "import ultralytics, torch, ncnn; print('ultralytics', ultralytics.__version__); print('torch', torch.__version__, 'cuda', torch.cuda.is_available()); print('ncnn ok')"
test -f runs/baseline_yolo26n/weights/best.pt
```

It reported `ultralytics 8.4.75`, `torch 2.12.1+cu130`, `cuda False`, and
`ncnn ok`; `runs/baseline_yolo26n/weights/best.pt` existed. CUDA was not
needed for export, so the difference from the 25/06 `cuda True` training gate
was recorded but not investigated.

The isolated export source was created at:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/export_imgsz320/best_imgsz320.pt
```

`yolo export model=runs/export_imgsz320/best_imgsz320.pt format=ncnn imgsz=320`
completed with input shape `(1, 3, 320, 320)` and output shape `(1, 9, 2100)`.
Export output:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/export_imgsz320/best_imgsz320_ncnn_model
```

Required files are present:

- `model.ncnn.param` (`26K`)
- `model.ncnn.bin` (`9.1M`)
- `metadata.yaml` (`401` bytes)
- `model_ncnn.py`

## Block E - Optional Workstation Static Smoke

Run only if Block D exports cleanly and time remains.

This is a load/import check only. It does not prove detector quality.

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
source ~/venvs/yolo-ws/bin/activate
yolo predict model=runs/export_imgsz320/best_imgsz320_ncnn_model source=images/val imgsz=320 conf=0.25 project=runs/predict_imgsz320 name=static_smoke exist_ok=True
```

If the validation image path differs, inspect the dataset layout first and use
the real val image directory. Do not create repo artifacts.

Record:

- exact model path;
- source image path;
- whether the NCNN export loads;
- boxes, if any, as informational only;
- output directory under the dataset root.

Do not copy to the Pi on Monday unless the user explicitly approves a separate
handoff step.

**Outcome:** optional workstation static smoke passed as a load/import check.
A first command used a mistyped venv path and produced no output. A later
relative-`project` smoke run loaded the model but saved under
`/home/ghostzero/runs/detect/...`; that stray `static_smoke` output was
removed while the older parent tree was left untouched, and the check was
rerun with an absolute dataset-local project path:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06
source ~/venvs/yolo-ws/bin/activate
yolo predict task=detect model=runs/export_imgsz320/best_imgsz320_ncnn_model source=images/val imgsz=320 conf=0.25 project=/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/predict_imgsz320 name=static_smoke exist_ok=True
```

NCNN loaded from the new `imgsz=320` export. Source images were:

- `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/images/val/neg_20260624_150606_0004.jpg`
- `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/images/val/oblique_20260624_144553_0006.jpg`

Both images returned no detections at `conf=0.25`. The negative image was
correctly empty, but `oblique_20260624_144553_0006.jpg` has `2` labeled
persons, so the smoke result is a `0/2` recall miss on the positive validation
image. This is a weak detector-quality warning consistent with the prior
`imgsz=640` custom-model `0`-box results; it does not invalidate the NCNN
load/export check. Smoke timing was about `12.3 ms` inference per image at
shape `(1, 3, 320, 320)`. Output directory:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/predict_imgsz320/static_smoke
```

## Block F - Block G Dataset/Model Planning

Run after the export path is handled, or sooner if export is blocked.

Goal: decide whether useful detector-quality work is possible from the data
available now.

Check:

- Which operational classes or realistic proxies are actually available.
- Whether the camera viewpoint matches the boat-level RealSense viewpoint.
- Whether labels would help the real deployment task.
- Whether a retrain would be meaningful from the new data.

Do not collect more easy `person` images just to increase count. The 24/06 split
already proved the pipeline and still has only `7` person images, `4` clean
negatives, `9` total class-4 boxes, and `2` validation images.

If no useful buoys, vessels, docks, obstacles, or realistic proxy scenes are
available, park dataset work and record that result.

**Outcome:** detector-quality dataset/model work is parked. Dataset inventory
still shows only the 24/06 indoor RealSense pilot: `9` train images/labels,
`2` val images/labels, `9` total boxes, all class `4` (`person`), plus
`17` rejected same-scene raw images. `data.yaml` declares `buoy`, `vessel`,
`dock`, `obstacle`, and `person`, but only `person` is populated.

No available buoy, vessel, dock, obstacle, water-level scene, or realistic
proxy set was found under the dataset tree. Adding more easy person frames
would only inflate the already-proven pipeline-validation class, not improve
the real deployment detector.

## Block G - Tuesday Hardware Handoff Note

Use only after the workstation work is recorded.

Keep it docs-only. Do not run the hardware test on Monday.

Tuesday 30/06/2026 candidate order:

1. Inspect physical power and wiring after the missing startup music/sound.
2. Confirm the flight-controller/peripheral side is powered.
3. Check the `/dev/ttyAMA0` cable path and seating.
4. Rerun MAVProxy heartbeat on `/dev/ttyAMA0:57600`.
5. Launch MAVROS only after MAVProxy receives heartbeat again.
6. If a new `imgsz=320` NCNN export exists, copy it to the Pi and run only the
   short bounded thermal comparison after the MAVProxy/wiring issue is no
   longer blocking.

No dashboard, QGC upload, Herelink, or real-FCU command path is needed for that
quick MAVProxy retry.

**Outcome / Tuesday note:** Tuesday 30/06/2026 remains Pi-side and
hardware-first. Candidate order:

1. Inspect physical power and wiring after the missing startup music/sound.
2. Confirm the flight-controller/peripheral side is powered.
3. Check the `/dev/ttyAMA0` cable path and seating.
4. Rerun MAVProxy heartbeat on `/dev/ttyAMA0:57600`.
5. Launch MAVROS only after MAVProxy receives heartbeat again.
6. Only after that gate is no longer blocking, and only if explicitly
   approved, copy the new `imgsz=320` NCNN export to the Pi and run a short
   bounded thermal comparison.

Monday skipped all live Pi / hardware blocks by design.

## Block H - Wrap

Update this diary with:

- Repo guard outcome and final SHA.
- Files inspected and sweep commands run.
- Findings classification.
- Markdown edits made, or explicit no-edit result.
- `imgsz=320` export result and exact artifact path if Block D ran.
- Static smoke result if Block E ran.
- Dataset/model planning decision if Block F ran.
- Skipped live/hardware blocks and why.
- Bounded next steps for Tuesday 30/06/2026.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-06-29_monday_workstation_prep.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-29_monday_workstation_prep.md
rg -n "\[[[:space:]]\]" working_diary/2026-06-29_monday_workstation_prep.md
```

Run the standard public-repo visibility sweep before committing. End with
bounded next steps and no stale completed action.

**Wrap outcome:** Monday completed the intended workstation path. Repo guard
started clean/synced at
`389b659cf2fb1b688748f467135b51f33629434e`; docs/status hygiene found only
stale `Board.md` metadata, fixed narrowly; the custom model has a separate
workstation `imgsz=320` NCNN export at
`/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/export_imgsz320/best_imgsz320_ncnn_model`;
the dataset-local static smoke loaded that export and produced no detections on
the two validation images, including a `0/2` miss on the labeled positive
image; Block G detector-quality work is parked until useful operational or
realistic proxy data is available.

**Next steps:** Tuesday 30/06/2026 should start with the physical
power/wiring inspection and MAVProxy heartbeat retry. Do not launch MAVROS
until MAVProxy receives heartbeat again. Do not copy or test the new 320 NCNN
export on the Pi until the heartbeat gate is no longer blocking and that
thermal comparison is explicitly approved.

Suggested commit subject for this wrap:

```text
docs: record 29/06 workstation export prep
```
