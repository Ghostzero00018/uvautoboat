# Friday 26/06/2026 - YOLO Cooling, Pyrealsense, And Dataset Gate

## Purpose

Continue from the 25/06 YOLO / RealSense chain after the completed tiny-pilot
training gate, Pi static custom NCNN load/run, and bounded ROS-camera-node live
procedure spike.

Priority order for today:

1. Cooling first, if hardware is available.
2. Dataset/model work, if cooling hardware is not available.
3. `pyrealsense2` explore only as a gated optional path, not as the main fix.
4. If neither cooling nor useful dataset work is available, park YOLO and switch
   only after an explicit new block is approved.

The two known issues are separate:

- `0` boxes is a data/model problem. The current split is a tiny
  pipeline-validation set, not detector-quality data.
- The 25/06 live run thermal abort is a cooling/headroom problem. The Pi started
  near `72.7-73.8 C` and reached `80.95 C` after `10.4 s`.

`pyrealsense2` can reduce ROS overhead for a future direct-SDK retest, but it
does not fix detector quality and it does not fix the Pi cooling baseline.

## Starting Context

Expected repo state:

- `main` clean/synced at `c963d06` or later.
- Latest landed commit: `docs: record RealSense NCNN procedure status`.

25/06 EOD quick sweep found no additional live-doc update needed. Current live
rows in `Board.md`, `wiki/Roadmap.md`, and `wiki/YOLO_Dataset_Plan.md` already
record the Block F result, the `80.95 C` thermal abort, and the cooling rather
than model-infeasibility diagnosis. Remaining stale-looking phrases are frozen
dated rows or still-true boundaries.

Facts to preserve:

- Dataset stays outside the repo at
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06`.
- R3 split is tiny: `9` train images/labels and `2` val images/labels.
- Pilot content is 7 `person` images plus 4 clean negatives; `9` total boxes,
  all class `4` `person`, normalized coordinates.
- This proves capture -> label -> split -> train -> validate -> export -> Pi
  static load/run plus bounded ROS camera-topic -> custom NCNN procedure only.
- It is not detector-quality data, and it is not sustained thermally clean live
  inference.
- 25/06 Block F used `realsense2_camera` v4.58.1 / LibRealSense v2.58.1 on
  D435I serial `213622070342` at `RGB8 424x240x15`.
- Camera-only topic flow before inference was about `14.939-15.012 Hz`.
- F2 processed `30` frames in `10.4 s`, `mean_fps=2.90`,
  `mean_inf_ms=340.9`, then hit the intended `80.0 C` safety abort at
  `80.95 C`.
- Direct `pyrealsense2` was absent from both `~/venvs/yolo-pi5` and
  `/usr/bin/python3` on 25/06.
- No dashboard integration, MAVROS, QGC, Herelink, or real-FCU path is proven.

## Boundaries

- Do not mutate `~/venvs/yolo-pi5`; it is the proven Pi YOLO environment.
- Do not blind-install `pyrealsense2` with `pip`.
- Any `pyrealsense2` work must use an apt-first probe and a separate venv.
- Do not run dashboard, MAVROS, QGC, Herelink, or real-FCU tests in this block.
- Do not run a live inference retest unless the Pi starts from a clearly cooler
  baseline and the safety aborts remain active.
- Keep dataset, weights, exports, logs, and helper outputs outside the repo.

## Block A - Repo Guard And Source Read

Before making any claim or edit, run from the repo root:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

If fetch fails while on normal internet WiFi, stop and report. If behind
`origin/main`, run `git pull --ff-only`, then re-check status. If ahead,
diverged, or dirty, stop and report before continuing.

Read first:

- `working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md`
- `working_diary/2026-06-25_thursday_yolo_training_gate.md`
- `wiki/YOLO_Dataset_Plan.md`
- `Board.md` YOLO / RealSense rows
- `wiki/Roadmap.md` YOLO / RealSense rows

## Block B - Pick Today's Branch

Choose one branch based on real resources today:

1. If cooling hardware is available, start with Block C.
2. If cooling hardware is not available but useful dataset work is available,
   skip to Block G.
3. If neither is available, park YOLO and choose a separate approved block.

Do not lead with `pyrealsense2` unless the Pi can be cooled or the task is
explicitly limited to install exploration only.

## Block C - Pi Cooling Baseline

Run only from the Pi, preferably through Remmina so the desktop state is visible.
Use dedicated USB-C power. If a fan/heatsink is available, install/enable it
before the baseline.

Pi terminal:

```bash
hostname
hostname -I
cat /sys/class/thermal/thermal_zone0/temp
sudo dmesg | grep -Ei 'under.?voltage|throttl|voltage' | tail -10
```

Record a short idle baseline:

```bash
for i in $(seq 1 10); do
  date '+%H:%M:%S'
  cat /sys/class/thermal/thermal_zone0/temp
  sleep 10
done
```

Decision:

- If idle remains near the 25/06 `72.7-73.8 C` baseline, do not run live
  inference. Cooling is not fixed.
- If idle is clearly lower and stable, continue to Block D or Block E.

## Block D - Optional Pyrealsense Explore

This block only checks whether the direct-SDK path can be installed cleanly. It
does not run live inference by itself.

Do not touch `~/venvs/yolo-pi5`.

Pi terminal:

```bash
apt-cache policy python3-pyrealsense2 librealsense2-utils librealsense2-dev
dpkg -l | grep -Ei 'realsense|librealsense' || true
/usr/bin/python3 - <<'PY'
try:
    import pyrealsense2 as rs
    print("system pyrealsense2", getattr(rs, "__version__", "version_unavailable"))
    print("devices", [d.get_info(rs.camera_info.serial_number) for d in rs.context().query_devices()])
except Exception as e:
    print("system pyrealsense2 missing/error:", repr(e))
PY
```

Stop and review before installing anything. The preferred install route is an
apt package matching the system LibRealSense `2.58.x` stack. If no matching apt
package exists, treat this as a source-build decision, not a one-line install.

If install is approved and succeeds, create a separate environment such as:

```bash
python3 -m venv --system-site-packages ~/venvs/yolo-pi5-rs
source ~/venvs/yolo-pi5-rs/bin/activate
python - <<'PY'
import pyrealsense2 as rs
print("pyrealsense2", getattr(rs, "__version__", "version_unavailable"))
print("devices", [d.get_info(rs.camera_info.serial_number) for d in rs.context().query_devices()])
PY
```

Only add Ultralytics / NCNN packages to this separate venv if the import gate is
clean and a direct-SDK retest is still useful after the cooling baseline.

## Block E - Direct-SDK Retest Gate

Run only if both are true:

- Block C shows the Pi starts from a clearly cooler baseline.
- Block D proves `pyrealsense2` imports in a separate environment.

Keep this separate from the 25/06 ROS fallback directory, for example:

```text
/home/imt-aqua-drone/yolo_tests/realsense_direct_20260626
```

Retest shape:

1. Direct-SDK preflight: imports, D435I serial `213622070342`, model files,
   temperature, dmesg tail.
2. Snapshot -> static NCNN inference with camera stopped before inference.
3. Short live direct-SDK inference only if the snapshot step and thermal state
   are clean.

Abort rules:

- Stop on fresh undervoltage/throttle evidence.
- Stop at or before `80.0 C`.
- Stop if no frames arrive within the helper timeout.

Expected detections are still informational only. `0` boxes does not mean the
camera path failed; the current model is not detector-quality.

## Block F - If Live Camera Detection Is The Question

The current live camera path already reached frames -> custom NCNN inference on
25/06 through the ROS camera topic. The reason it returned `0` boxes is almost
certainly the tiny model/data/threshold state, not the RealSense subscriber.

Valid next checks:

- A low-confidence diagnostic can compare Pi output against workstation
  expectations, but it is still not detector-quality evidence.
- A real detector improvement needs more relevant labeled data and retraining.
- A cooled Pi can answer whether sustained live inference is thermally viable.

Do not treat `pyrealsense2` as the detection fix. It is only a lower-overhead
capture route.

## Block G - Dataset/Model Branch

Use this branch if cooling hardware is not available.

Workstation-only. Keep outputs outside the repo under:

```text
/home/ghostzero/datasets/uvautoboat_yolo_2026-06
```

Do not collect more easy `person` examples just to increase count. The useful
data targets are operational classes and water-level viewpoints. If no buoys,
vessels, docks, obstacles, or relevant proxy scenes are available, park the
dataset work rather than expanding the wrong distribution.

Minimum planning outputs:

- Which class(es) can be collected realistically.
- Whether the camera viewpoint matches the boat RealSense height/angle.
- Whether labels will be useful for the real deployment task.
- Whether retraining would be meaningful from the new data.

## Block H - Wrap

Update this diary with:

- Repo guard outcome and final SHA.
- Which branch was selected and why.
- Cooling baseline temperatures and dmesg tail if Block C ran.
- `pyrealsense2` package/import status if Block D ran.
- Direct-SDK retest result if Block E ran.
- Dataset/model decision if Block G ran.
- Explicit skipped blocks and why.
- Bounded next steps.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md
rg -n "\[[[:space:]]\]" working_diary/2026-06-26_friday_yolo_cooling_pyrealsense_dataset_gate.md
```

Run the standard public-repo visibility sweep before committing. End with
bounded next steps and no stale completed action.
