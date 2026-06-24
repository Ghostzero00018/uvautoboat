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

**Outcome:** repo guard passed on 24/06/2026 before the hardware log review and
diary update. `git fetch --prune` completed, latest commit was `8d1aa29`
(`docs(diary): make RealSense QoS fallback trigger observable`),
`git status --short --branch` showed clean `## main...origin/main`, and
`git rev-parse HEAD origin/main` returned the same SHA
`8d1aa292a80963f7b2de4350b966444da02376c6` for both refs.

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

**Outcome:** Block B passed from
`/home/ghostzero/Desktop/test_logs_folder/testlogs_24_06_2026.txt`. Pi hostname
was `imtaquadrone-desktop`, IP was `10.120.2.249`, `ROS_DOMAIN_ID=12`,
`ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET`, and `ROS_LOCALHOST_ONLY=unset`.
`~/venvs/yolo-pi5` imported `ultralytics 8.4.62` and `ncnn 1.0.20260526`.
Pre-launch temperature was `68850` from `/sys/class/thermal/thermal_zone0/temp`
(`68.85 C`). The process check returned no existing RealSense, MAVROS,
MAVProxy, `web_video_server`, rosbridge, or YOLO process. Power source was a
separate power bank and cable, not the Pi's default charger and not the shared
boat power path. The recent kernel log showed only boot-time
`cannot verify signal voltage switch` storage-bus messages, not undervoltage or
throttle evidence.

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

If `ros2 topic info --verbose` shows `Reliability: BEST_EFFORT`, or if
`ros2 topic hz` reports `0 Hz` / stalls after the topic is listed, use the
existing probe from the repo:

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

**Outcome:** Block C passed as a camera-only RealSense publish check. The Pi ran
`realsense2_camera` ROS `v4.58.1` with LibRealSense `v2.58.1`, detected Intel
RealSense D435I serial `213622070342`, firmware `5.14.0`, USB type `3.2`, and
opened the requested profile: color `RGB8`, width `424`, height `240`, FPS `15`.
The launch reached `RealSense Node Is Up!`.

On the workstation, both `/camera/camera/color/camera_info` and
`/camera/camera/color/image_raw` were visible after the ROS daemon restart.
`ros2 topic info --verbose /camera/camera/color/image_raw` recorded publisher
count `1`, QoS `Reliability: RELIABLE`, `Durability: TRANSIENT_LOCAL`, and
subscription count `0` before the rate subscriber was started. `ros2 topic hz`
then received the image stream cleanly, with repeated averages around
`14.96-15.03 Hz`; the final visible sample was `14.971 Hz` with window `802`,
min `0.037 s`, max `0.127 s`, and std dev `0.00620 s`. The QoS fallback was not
required, but the optional `tools/rate_probe.py` check also received the stream:
`N=298`, elapsed `20.01 s`, mean `14.93 Hz`.

Pi temperature while the camera was still running was `69950` (`69.95 C`), and
after the camera was stopped it was still `69950` (`69.95 C`). Both post-run
kernel-log checks again showed only the two boot-time storage-bus voltage-switch
messages, with no undervoltage or throttle evidence. No YOLO, MAVROS, QGC,
Herelink, dashboard, `web_video_server`, mission control, or real-FCU path was
run in this block.

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

**Outcome:** Block D scaffold was created outside the repo under
`/home/ghostzero/datasets/uvautoboat_yolo_2026-06`. Existing 23/06 smoke
artifacts were preserved (`classes.txt`, `yolo26n.pt`, and `runs/smoke`).
`data.yaml` now records the five-class order `0: buoy`, `1: vessel`, `2: dock`,
`3: obstacle`, `4: person`. `dataset_card.md` records the Pi hostname/IP,
RealSense topic, `RGB8 424x240x15` profile, RELIABLE publisher QoS with a
RELIABLE + VOLATILE + KEEP_LAST capture-subscriber note, the obstacle
precedence rule, and the planned `runs/pilot_2026-06-24` output. Directory
scaffold now includes `raw/2026-06-24_pi_realsense_rgb`,
`images/{train,val}`, `labels/{train,val}`, and `runs/pilot_2026-06-24`. No raw
pilot image files were created yet; saver implementation and capture remain
gated.

**Saver smoke outcome:** D1 passed with a scratch script outside the repo at
`/tmp/realsense_rgb_saver.py`. The workstation subscribed to
`/camera/camera/color/image_raw` with RELIABLE + VOLATILE + KEEP_LAST QoS and
saved five throwaway JPEGs under `/tmp/rs_smoke_2026-06-24` using prefix
`smoke`. The saved files were `424x240`, 3-channel JPEGs, readable by OpenCV,
and a visual check showed normal colors with no obvious red/blue swap. The real
pilot raw directory
`/home/ghostzero/datasets/uvautoboat_yolo_2026-06/raw/2026-06-24_pi_realsense_rgb`
remained empty. Pi temperature after the smoke save was `72150` (`72.15 C`);
the post-run kernel-log filter still showed only the two boot-time
storage-bus voltage-switch messages, with no undervoltage or throttle evidence.
No real pilot capture, labeling, training, live YOLO inference, dashboard,
MAVROS, QGC, Herelink, `/wamv/*` replacement, or real-FCU path was run.

**Pilot capture outcome (D2):** A first 424x240 pilot was captured into the real
raw directory `raw/2026-06-24_pi_realsense_rgb` with the scratch saver (prefix
`pilot`): 30 JPEGs, all `424x240` 3-channel, correct colors, saver exited
cleanly. Pi health stayed clean through the run: temperature `71600`-`72700`
(`71.6`-`72.7 C`), with only the two boot-time storage-bus voltage-switch
messages and no undervoltage or throttle. However, the set is a static-camera
capture: all 30 frames share one fixed lab viewpoint with near-identical file
sizes, the only labelable class present is a small, distant, partially occluded
background `person`, and there is no distance/angle/background variation. It
fails the diversity bar, so it is NOT carried forward to review or labeling; the
frames stay in `raw/` as a holding area pending a diverse re-capture. Capture
mechanics and Pi thermal/power are proven; capture content is not yet usable.

**Pilot re-capture outcome (D2, afternoon):** The morning static set was cleared
and a varied re-capture was run as five short saver passes tagged
`near`/`mid`/`far`/`oblique`/`neg` (28 frames, `424x240`). The saver wrote to the
home directory because `$OUT` was unset in that shell; the 28 JPEGs were then
copied into `raw/2026-06-24_pi_realsense_rgb` (28 verified present). Pi health
stayed clean: `69950` (`69.95 C`), only the two boot-time storage-bus
voltage-switch messages, no undervoltage or throttle. Visual review: diversity
improved over the morning, but a colleague is seated at the far-left desk in
essentially every frame (including the `neg` ones), so the set has no clean
negatives and the foreground subject is framed with the head cut off. Decision:
proceed as a negatives-free single-class `person` pilot - label every visible
person (foreground and background) as `person`, no empty-label negatives. This
remains a pipeline-validation pilot, not detector-quality data.

**Negatives update (D2, afternoon):** The first `neg_20260624_144631_*` set still
showed the background colleague, so it is dropped rather than used as negatives.
A re-shot `neg_20260624_150606_*` set (4 frames, desk vacated, confirmed no
person) is used as the clean empty negatives. The pilot is therefore a
single-class `person` set (24 frames) plus 4 clean negatives, not negatives-free.
The clean negatives were saved to the home directory (the `$OUT` shell variable
was unset again), then moved into `raw/2026-06-24_pi_realsense_rgb` with the
earlier contaminated set removed before R1.

**R1 review/dedup outcome:** The raw top level was culled non-destructively to
11 kept images: `mid_20260624_144445_0001.jpg`,
`far_20260624_144508_0001.jpg`, `far_20260624_144508_0006.jpg`, four
`oblique_20260624_144553_*` frames (`0001`, `0002`, `0004`, `0006`), and the
four clean `neg_20260624_150606_*` negatives. The 17 rejected frames were moved
to `raw/2026-06-24_pi_realsense_rgb/rejected_2026-06-24/`. The `near` run was
dropped because it only shows an arm/hand plus desk; `mid` and `far` were
reduced to small-background-person examples; `oblique` carries the strongest
foreground-person examples. This remains thin, skewed pipeline-validation data,
not detector-quality `person` coverage.

**R2 labeling outcome:** X-AnyLabeling exported YOLO-Hbb labels to
`raw/labels/` rather than beside the active JPGs. The active 11-image set has
matching labels there: 7 person images with class `4` rows and 4 clean
`neg_20260624_150606_*` negatives with empty `.txt` files. A structural and
visual check passed: all active label rows use class `4`, coordinates are
normalized in `[0, 1]`, every visible person in the kept frames is boxed, the
four negatives are genuinely empty, and labels that exist for rejected frames
are ignored for the split.

**R3 split outcome:** The 11 active image/label pairs were copied into the
Ultralytics layout outside the repo. Split: 9 train and 2 val. Train contains
6 positive images and 3 negatives; val contains
`oblique_20260624_144553_0006` (2 person boxes) and
`neg_20260624_150606_0004` (empty negative). Split lint passed: image/label
stem parity is complete, no rejected stems were copied, all class IDs are `4`,
and all box coordinates remain normalized.

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

**Wrap outcome:** the approved 24/06 camera-only readiness check passed, the
pilot dataset scaffold was created outside the repo, and the scratch saver
smoke test wrote five throwaway JPEGs under `/tmp`. A first 424x240 pilot of 30
frames was then captured into the real raw directory, but the static-camera set
was too low-diversity to carry forward. The afternoon re-capture was reviewed
and culled for R1: 11 images are kept at the raw top level and 17 are preserved
in a rejected holding folder. R2 labeling and R3 split then passed structural
lint, producing a tiny 9/2 train/val split for a single-class `person` pilot;
no static YOLO regression check was run. This is RealSense RGB stream
readiness, dataset-layout readiness, saver-smoke, capture-mechanics, R1 cull,
R2 label, and R3 split evidence only; it does not prove detector quality,
training, custom maritime detection, live RealSense inference, dashboard
integration, MAVROS, QGC, Herelink, `/wamv/*` replacement, or any real-FCU
command/write path.

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

**Next steps:** On the workstation, run the YOLO environment/CUDA gate, train a
first custom `yolo26n` pipeline-validation model from `data.yaml`, validate only
as informational evidence because the split is tiny, then export NCNN for a Pi
static-image validation. Keep this separate from live RealSense inference,
MAVROS, QGC, Herelink, dashboard integration, and any real-FCU path.

**Later:** After the 424x240 pipeline-validation pilot, plan a separate higher-resolution detector-seed capture day, starting with a camera-only 640x480x15 check: topic rate, Pi temperature via thermal_zone0, and dmesg undervoltage/throttle tail. If workstation-over-DDS WiFi is unstable at the higher profile, run the saver on the Pi locally and rsync images afterward.
