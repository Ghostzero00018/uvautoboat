# Wednesday 24/06/2026 - Pi 5 RealSense YOLO Capture Readiness

## Purpose

Run a bounded Pi 5 RealSense RGB camera check for the future YOLO dataset. The day is about proving that the Pi 5 can publish a stable RealSense color stream and that the workstation can observe it cleanly before any real capture, labeling, training, or live inference work is expanded.

## Starting Context

- Expected starting repo state: `main` clean/synced at `c89e2d4` or later.
- 23/06 workstation YOLO chain is proven: `~/venvs/yolo-ws`, Ultralytics `8.4.75`, `torch-2.12.1+cu130`, CUDA on `NVIDIA RTX A3000 Laptop GPU`, `coco8` smoke training, and NCNN export to `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/smoke/weights/best_ncnn_model`.
- 23/06 X-AnyLabeling is proven for YOLO-Hbb export in `~/venvs/x-anylabeling`, version `4.0.0-beta.10`, using class order `buoy`, `vessel`, `dock`, `obstacle`, `person`.
- 23/06 Pi 5 static-image handoff is proven only for a COCO smoke model: `best_ncnn_model` ran on `imt-aqua-drone@10.120.2.249` with `ultralytics 8.4.62`, `ncnn 1.0.20260526`, CPU inference at `imgsz=640`, and stable temperature from `68.85 C` to `68.30 C`.
- The 23/06 Pi handoff does not prove the future maritime detector, live RealSense inference, ROS/dashboard integration, MAVROS, QGC, Herelink, or any real-FCU path.
- Dataset plan lives in `wiki/YOLO_Dataset_Plan.md`; RealSense camera-only test guidance lives in `wiki/RealSense_Dashboard_Testing.md`.

## Boundaries

- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, real-FCU command path, dashboard mission controls, or dashboard thruster controls.
- No Herelink, QGC, MAVROS, MAVLink forwarding, or workstation router work unless explicitly approved as a separate block.
- No combined RealSense + YOLO + MAVROS co-load on Pi 5 unless the dedicated `>=5A` supply is confirmed.
- No continuous Pi-side YOLO inference on a live RealSense stream today unless the camera-only stream is healthy and the user explicitly approves a separate test.
- No Python, YAML, launch, package, systemd, or config edits unless explicitly approved.
- Hardware and GUI work is user-run by default. Provide copy-paste commands, then interpret pasted output.

## Network Discipline

- Use normal internet WiFi for repo, docs, diary, commit, and push work.
- Use the Pi/workstation ROS DDS network only for the approved RealSense camera check. For the prior camera path this was `IoT IMT Nord Europe` with `ROS_DOMAIN_ID=12`.
- Do not switch to `IMT-Aquatic-drone` for this RealSense camera day unless a separate Herelink/QGC/MAVLink test is explicitly approved.
- Switch back to normal internet WiFi before committing or pushing any diary/docs update.

## Block A - Repo Guard And Source Read

Before making any claim or edit, run from `/home/ghostzero/seal_ws/src/uvautoboat`:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Guard rules:

- If fetch fails while on normal internet WiFi, stop and report.
- If behind `origin/main`, run `git pull --ff-only`, then re-check status.
- If ahead, diverged, or dirty, stop and report before continuing.

Read first:

- `working_diary/2026-06-24_wednesday_pi5_realsense_yolo_capture.md`
- `working_diary/2026-06-23_tuesday_professor_onsite_next_steps.md`
- `wiki/YOLO_Dataset_Plan.md`
- `wiki/RealSense_Dashboard_Testing.md`
- `Board.md` YOLO / RealSense rows
- `wiki/Roadmap.md` YOLO / RealSense rows

## Block B - Pi 5 Preflight

Goal: confirm the Pi, environment, network address, camera readiness, and thermal/power baseline before starting RealSense.

Pi terminal or SSH, user-run:

```bash
hostname
hostname -I
source /opt/ros/jazzy/setup.bash
echo "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-unset}"
echo "ROS_AUTOMATIC_DISCOVERY_RANGE=${ROS_AUTOMATIC_DISCOVERY_RANGE:-unset}"
echo "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY:-unset}"
source ~/venvs/yolo-pi5/bin/activate
python -c "import ultralytics, ncnn; print('ultralytics', ultralytics.__version__); print('ncnn', ncnn.__version__)"
cat /sys/class/thermal/thermal_zone0/temp
sudo dmesg | grep -Ei 'under.?voltage|thrott|voltage' | tail -20
```

Optional process check, user-run:

```bash
pgrep -af 'realsense|mavros|MAVProxy|web_video_server|rosbridge|yolo' || true
```

Pass criteria:

- Pi hostname and IP are recorded.
- Pi power source is confirmed before streaming. Prefer the stable dedicated USB-C supply decoupled from the main `14.8 V` LiPo path; do not rely on the historically weak GPIO-5V path for RealSense load.
- If Herelink video is expected from the same camera path, treat `realsense2_camera` as a possible camera-consumer conflict. Starting it may preempt the existing video fork and interrupt Herelink RTSP until the camera is released.
- `ultralytics` and `ncnn` still import in `~/venvs/yolo-pi5`.
- Temperature is recorded before camera launch.
- No undervoltage or throttle evidence is present in the recent kernel log.
- Any already-running RealSense or heavy process is understood before starting a new camera launch.

## Block C - Camera-Only RealSense Publish

Goal: publish the Pi 5 RealSense color stream only. Do not run YOLO, MAVROS, QGC, Herelink, dashboard, or `web_video_server` in this block.

Pi terminal P1, foreground process:

```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY
ros2 launch realsense2_camera rs_launch.py enable_depth:=false rgb_camera.color_profile:=424x240x15
```

Workstation terminal W1, after P1 is running:

```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY
ros2 daemon stop
ros2 daemon start
ros2 topic list | grep -E '^/camera/camera/color/(image_raw|camera_info)$'
ros2 topic info /camera/camera/color/image_raw --verbose
ros2 topic hz /camera/camera/color/image_raw
```

If `ros2 topic hz` does not report cleanly because of QoS, use the existing probe from the repo:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=12
export ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET
unset ROS_LOCALHOST_ONLY
python3 tools/rate_probe.py --topic /camera/camera/color/image_raw --reliability best_effort --duration 20
```

Pass criteria:

- `/camera/camera/color/image_raw` appears on the workstation.
- `ros2 topic info --verbose` records publisher count and QoS.
- A color stream rate is recorded for at least 20 seconds.
- Pi temperature is recorded again after the camera has been running.
- No undervoltage or throttle evidence appears after the run.

## Block D - Pilot Dataset Setup Only If Block C Passes

Goal: prepare the dataset folder and metadata outside the repo. Do not collect a full dataset yet. If the camera is stable, capture only a small pilot set after choosing and verifying a saver method.

Workstation terminal, outside repo:

```bash
DATASET=/home/ghostzero/datasets/uvautoboat_yolo_2026-06
mkdir -p "$DATASET"/raw/2026-06-24_pi_realsense_rgb
mkdir -p "$DATASET"/images/{train,val} "$DATASET"/labels/{train,val} "$DATASET"/runs
cat > "$DATASET"/data.yaml <<'YAML'
path: /home/ghostzero/datasets/uvautoboat_yolo_2026-06
train: images/train
val: images/val
names:
  0: buoy
  1: vessel
  2: dock
  3: obstacle
  4: person
YAML
```

Pilot capture rules:

- Use the Pi RealSense RGB stream only.
- Prefer diverse frames over near-duplicates.
- Include empty-water / no-target frames when available.
- Record capture conditions in `dataset_card.md`: date, site, Pi hostname/IP, RealSense profile, lighting, distance, angle, background, weather/water state, temperature, and whether any heavy workloads were running.
- Do not move images into `images/train` or `images/val` until obvious duplicates and bad frames are removed.
- Do not label or train until the pilot images are reviewed.

## Block E - Optional Static YOLO Sanity After Camera Shutdown

Only after the RealSense camera process is stopped and temperature is stable, it is acceptable to repeat the 23/06 static-image NCNN check as a regression sanity check.

This does not use the RealSense stream and does not prove live inference. It only confirms that `~/yolo_tests/best_ncnn_model` still loads on the Pi.

Pi terminal, user-run:

```bash
source ~/venvs/yolo-pi5/bin/activate
python - <<'PY'
from pathlib import Path
from time import perf_counter
from ultralytics import YOLO

model_path = Path.home() / "yolo_tests/best_ncnn_model"
image_path = Path.home() / "yolo_tests/images/000000000042.jpg"

model = YOLO(str(model_path), task="detect")
for i in range(3):
    t0 = perf_counter()
    results = model.predict(str(image_path), imgsz=640, device="cpu", verbose=False)
    dt_ms = (perf_counter() - t0) * 1000
    print(f"run={i+1} boxes={len(results[0].boxes)} wall_ms={dt_ms:.1f} speed={results[0].speed}")
PY
```

Pass criteria:

- Model loads without the task warning.
- Three runs complete.
- Timing is recorded as regression evidence only.
- Temperature and voltage/throttle status are checked afterward.

## Wrap

Update this diary with:

- Repo guard outcome.
- Pi hostname/IP and environment versions.
- RealSense launch result.
- Workstation topic/QoS/rate evidence.
- Pi temperature before/after.
- Voltage/throttle evidence.
- Whether any pilot dataset folder or files were created.
- Whether any static YOLO regression check was run.

If docs/diary changed, run:

```bash
git status --short --branch
git diff --check
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-24_wednesday_pi5_realsense_yolo_capture.md
```

If this diary is still untracked in a fresh checkout, use one of:

```bash
git diff --no-index --check /dev/null working_diary/2026-06-24_wednesday_pi5_realsense_yolo_capture.md
```

or:

```bash
git add -N working_diary/2026-06-24_wednesday_pi5_realsense_yolo_capture.md
git diff --check
```

Run the standard public-repo visibility sweep from the terminal before any commit. Eyeball the one-line conventional commit subject before committing.

**Next steps:** If the Pi RealSense RGB stream is stable, collect a small pilot image set, review frames for diversity and duplicates, label the pilot in X-AnyLabeling with YOLO-Hbb, then train a first custom `yolo26n` model on the workstation and export NCNN for a Pi static-image validation.
