# 2026-06-10 - Wednesday: YOLO follow-up and professor check

## Day overview

Continuing from Tue 09/06/2026 ([`2026-06-09`](2026-06-09_tuesday_feedback_and_pi5_yolo_trial.md)).

Primary work for Wed 10/06/2026:

- **Professor check:** show the current state clearly, capture feedback, and record any decision about the next YOLO step.
- **YOLO follow-up:** continue only as a bounded Pi-local feasibility pass unless the user explicitly approves a wider step.

Current state to preserve:

- 09/06 proved the Pi-local YOLO path in `~/venvs/yolo-pi5`: `yolo26n.pt` loaded on aarch64 with `torch-2.12.0+cpu`, NCNN export produced `yolo26n_ncnn_model`, and static-image inference on the `bus.jpg` fallback returned `detections: 5`.
- 09/06 timing at `imgsz=320` was preprocess 17.24 ms, inference 244.42 ms, postprocess 15.05 ms on CPU.
- 09/06 post-run warning filter showed no pasted voltage, throttling, or under-voltage warning for the static-image pass.
- This is still not ROS integration, not camera-stream inference, not dashboard integration, and not command-path work.
- RealSense / combined camera + MAVROS power risk remains open. GPS no-fix / EKF GPS configuration remains open. Command / write path remains unvalidated.
- 09/06 durable docs are already updated: `Board.md` version 9.21 and `wiki/Roadmap.md` Phase 5 / revision-log rows.

## Boundaries

- **Markdown-only by default:** diary, Board, Roadmap, or other docs can be updated if the day's evidence changes durable status.
- **No code/config edits unless explicitly approved:** do not edit Python, YAML, JavaScript, launch, dashboard, service, or adapter implementation files.
- **Execution boundary:** Pi-side commands are run by the user in a real Pi terminal and pasted back here for interpretation and recording.
- **YOLO boundary:** Pi-local feasibility only unless explicitly widened. Do not create a ROS node, dashboard integration, service, launch file, or camera-stream pipeline.
- **Camera boundary:** do not run continuous camera-stream YOLO unless Pi power is stable, `web_video_server` sees `/camera/camera/color/image_raw`, and the user explicitly approves that extra step.
- **Presentation boundary:** if the professor asks for an external slide / `.pptx` refresh, ask for the path first. Do not guess external Windows paths.

## Block A - Repo pre-flight and source refresh

- [ ] Confirm repo state:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [ ] If `git fetch --prune` fails, stop and report the network / auth error. Do not continue from stale remote state.
- [ ] If `HEAD` is behind `origin/main`, run:

  ```bash
  git pull --ff-only
  ```

  If `HEAD` and `origin/main` diverge, stop and report both SHAs.

- [ ] If the tree is dirty before work starts, identify changed files and do not overwrite user changes.
- [ ] Re-read the current anchors:

  ```bash
  sed -n '121,274p' working_diary/2026-06-09_tuesday_feedback_and_pi5_yolo_trial.md
  sed -n '180,186p' Board.md
  sed -n '316,321p' Board.md
  sed -n '188,196p' wiki/Roadmap.md
  sed -n '604,608p' wiki/Roadmap.md
  ```

**Outcome:** [To fill during 10/06 session.]

## Block B - Professor check and feedback capture

Use this short visible story for the professor check:

- MAVProxy / MAVROS camera-off telemetry path is already proven through `/dev/ttyAMA0:57600` and MAVProxy UDP fanout.
- The domain-12 MAVROS telemetry-only graph is clean.
- YOLO is now proven only as Pi-local CPU feasibility: `yolo26n.pt` -> NCNN -> static-image inference at about 244 ms inference time for `imgsz=320`.
- Remaining blockers are still RealSense / combined-load power, GPS no-fix / EKF GPS configuration, and unvalidated command/write path.

- [ ] Record professor feedback exactly as provided by the user.
- [ ] Classify each feedback item:
  - decision that changes the YOLO next step;
  - blocker / risk to keep visible;
  - documentation or graph update needed;
  - implementation request needing explicit code/config approval;
  - camera-stream request needing power checks and explicit approval;
  - external slide / `.pptx` request needing a user-provided path.
- [ ] If the professor asks for implementation, camera-stream inference, dashboard integration, or a slide refresh, stop and ask for the missing approval / path before proceeding.

**Outcome:** [To fill during 10/06 session.]

## Block C - Bounded YOLO follow-up after approval

Start this block only after the professor check is recorded and the user explicitly approves continuing with YOLO work.

Goal: verify the existing 09/06 YOLO artifact remains usable and collect repeatable static-image timing plus light power / thermal evidence. Keep MAVROS, RealSense, `web_video_server`, and camera workloads stopped unless a later block explicitly reopens them.

### C.1 Existing environment and artifact check

Run in a real Pi terminal:

```bash
cd ~
source ~/venvs/yolo-pi5/bin/activate
echo "venv=${VIRTUAL_ENV}"
python - <<'PY'
import platform
import torch
from ultralytics import YOLO

print("arch:", platform.machine())
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
model = YOLO("yolo26n_ncnn_model")
print("model_loaded:", "yolo26n_ncnn_model")
PY
ls -lh ~/yolo26n.pt ~/yolo26n_ncnn_model/model.ncnn.param ~/yolo26n_ncnn_model/model.ncnn.bin ~/yolo26n_ncnn_model/metadata.yaml
```

- [ ] Record whether the venv, model weights, and NCNN export artifacts are still present.
- [ ] If the model or export directory is missing, stop and record the missing artifact before re-exporting.

**Outcome:** [To fill during 10/06 session.]

### C.2 Repeat static-image timing and warning check

Prefer a local static image. Do not start RealSense just to create a test image.

```bash
cd ~
source ~/venvs/yolo-pi5/bin/activate
export ULTRALYTICS_SKIP_REQUIREMENTS_CHECKS=1
export MODEL_EXPORT=yolo26n_ncnn_model
if [ -f /home/imt-aqua-drone/yolo_test.jpg ]; then
  export TEST_IMAGE=/home/imt-aqua-drone/yolo_test.jpg
elif [ -f /home/imt-aqua-drone/bus.jpg ]; then
  export TEST_IMAGE=/home/imt-aqua-drone/bus.jpg
else
  export TEST_IMAGE=https://ultralytics.com/images/bus.jpg
fi
echo "test_source=${TEST_IMAGE}"
awk '{printf "cpu_temp_before_c=%.1f\n", $1/1000}' /sys/class/thermal/thermal_zone0/temp
python - <<'PY'
import os
from statistics import mean
from ultralytics import YOLO

model = YOLO(os.environ["MODEL_EXPORT"])
speeds = []
for i in range(5):
    results = model.predict(
        source=os.environ["TEST_IMAGE"],
        imgsz=320,
        device="cpu",
        verbose=False,
    )
    speed = results[0].speed
    speeds.append(speed)
    print(f"run_{i+1}_speed_ms:", speed)
    print(f"run_{i+1}_detections:", len(results[0].boxes))

print("mean_preprocess_ms:", round(mean(s["preprocess"] for s in speeds), 2))
print("mean_inference_ms:", round(mean(s["inference"] for s in speeds), 2))
print("mean_postprocess_ms:", round(mean(s["postprocess"] for s in speeds), 2))
PY
awk '{printf "cpu_temp_after_c=%.1f\n", $1/1000}' /sys/class/thermal/thermal_zone0/temp
sudo dmesg -T | tail -80 | grep -Ei 'voltage|thrott|under-voltage|usb|error|fail' || true
```

- [ ] Record test image source, five-run timing, detection counts, before/after temperature, and warning-filter output.
- [ ] Treat this as static-image feasibility only. Do not imply camera-stream readiness.

**Outcome:** [To fill during 10/06 session.]

## Block D - Decision gate for any wider YOLO step

Do not start this block automatically. Use it only if the professor check or the repeat timing pass creates a concrete next-step request.

- [ ] If the request is only to keep improving YOLO feasibility, decide whether the next step is a lean environment trial or more static-image timing.
- [ ] If the request is camera-stream YOLO, first verify power stability and that `web_video_server` sees `/camera/camera/color/image_raw`, then ask the user for explicit approval before running any stream inference.
- [ ] If the request is ROS / dashboard / service / launch integration, stop and ask for explicit code/config approval before editing anything.
- [ ] If the request is a graph or slide update, identify whether it is a repo Markdown/diagram file or an external `.pptx`; ask for the external path if needed.

**Outcome:** [To fill during 10/06 session.]

## Block E - Wrap and next steps

- [ ] Fill outcomes for Blocks A-D.
- [ ] If professor feedback changes durable status, update only the relevant Markdown docs.
- [ ] If YOLO remains static-image / Pi-local only, record it as feasibility only, not integration.
- [ ] If no Pi access, network access, or professor feedback is available, record the blocker and prepare the next-session command set from this diary.
- [ ] Run checks after any Markdown edit:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "\[To fill|<{7}|={7}|>{7}" working_diary/2026-06-10_wednesday_yolo_professor_check.md
  ```

  Also run the standard public-repo visibility sweep from the terminal, then eyeball the commit subject manually before commit.

**Outcome:** [To fill during 10/06 session.]

## Next steps

Start 10/06 by recording the professor check outcome before advancing any YOLO block. Keep the next YOLO work static-image / Pi-local unless the user explicitly approves a wider camera-stream, ROS, dashboard, service, launch, or code/config step.
