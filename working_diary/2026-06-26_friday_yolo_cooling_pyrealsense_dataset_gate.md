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

- `main` clean/synced at `900d47f` or later.
- Latest landed commit: `docs(diary): scaffold YOLO cooling gate`.

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

**Outcome:** repo guard passed on 26/06/2026 before any branch decision or
diary edit. `git fetch --prune` completed, latest commit was `900d47f`
(`docs(diary): scaffold YOLO cooling gate`), `git status --short --branch`
showed clean `## main...origin/main`, and `git rev-parse HEAD origin/main`
returned the same SHA `900d47f150192058688ab07d4aa94b98aa26d5a0` for both
refs. The 26/06 and 25/06 diaries, `wiki/YOLO_Dataset_Plan.md`, and the
YOLO / RealSense rows in `Board.md` and `wiki/Roadmap.md` were read before the
branch decision.

## Block B - Pick Today's Branch

Choose one branch based on real resources today:

1. If cooling hardware is available, start with Block C.
2. If cooling hardware is not available but useful dataset work is available,
   skip to Block G.
3. If neither is available, park YOLO and choose a separate approved block.

Do not lead with `pyrealsense2` unless the Pi can be cooled or the task is
explicitly limited to install exploration only.

**Outcome:** Block B selected the cooling branch because the user reported the
control box was available with cooling in place. The workstation complete
simulation launcher was not used as Pi thermal load; it is a Gazebo /
workstation stack and does not heat the Pi. The only relevant future Pi load
remains the bounded RealSense camera node plus the NCNN subscriber, and that
load stayed gated behind Block C.

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

**Outcome:** Block C ran from the Pi and was saved in:

```text
/home/ghostzero/Desktop/test_logs_folder/testlogs_26_06_2026_cooling_BlockC.txt
```

The Pi identified as `imtaquadrone-desktop` at `10.120.2.249`. Initial
temperature was `71600` millicelsius (`71.6 C`). The 10 idle samples over about
90 seconds were:

```text
71600
69400
69400
70500
71050
71050
71600
71050
71600
71050
```

That gives an idle-sample range of `69.4-71.6 C` and a mean of about
`70.8 C`; including the initial read gives about `70.9 C`. The before and
after dmesg voltage/throttle tails were unchanged and showed only the same
boot-time storage-bus voltage-switch messages:

```text
[    0.869607] mmc0: cannot verify signal voltage switch
[    0.933670] mmc1: cannot verify signal voltage switch
```

No fresh undervoltage or throttle evidence appeared during the idle baseline.
The fan improved the 25/06 hot idle floor slightly, but the result remained in
the marginal `65-72 C` band rather than the conservative `<=60 C` go band.
Decision: do not run the camera + NCNN loaded retest. Cooling/headroom remains
the live blocker.

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

**Outcome:** skipped. Block C did not produce a clearly cooler baseline, so
`pyrealsense2` was not re-probed or installed on 26/06. Direct SDK work remains
optional and separate; it is not a fix for the current thermal headroom problem
or for default-confidence `0` detections.

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

**Outcome:** skipped. The required cooler Block C gate did not pass, and no
separate `pyrealsense2` environment was proven. No direct-SDK retest was run.

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

**Outcome:** no live detection retest was run. The 25/06 ROS camera-topic ->
custom NCNN path remains the latest live-path evidence. The 26/06 result only
adds that the small fan did not lower idle enough to justify another loaded
thermal spike.

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

**Outcome:** not started. Block G remains the next available productive branch
only if explicitly approved after the cooling no-go decision.

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

**Wrap outcome:** 26/06 selected the cooling branch and ran the Block C idle
baseline only. With the small fan active, the Pi idled at `69.4-71.6 C`
(`70.8 C` mean over the 10 idle samples), which is stable but still too warm
for a responsible camera + NCNN loaded retest. Power/throttle evidence stayed
clean in the recorded dmesg tails. Blocks D and E were skipped because direct
`pyrealsense2` is not a cooling fix and the cooler baseline gate did not pass.
Block F was skipped because `0` boxes should not be chased through camera code,
and the known live blocker is thermal headroom. Block G was not started without
explicit approval.

**Next steps:** inspect the physical cooling mount before any more live
inference attempts: verify a real heatsink or active cooler is seated on the
SoC with usable thermal-pad contact, keep dedicated power, and rerun Block C
before any load test. If hardware cooling cannot be improved today, move to the
workstation-only Block G dataset/model planning branch only after explicit
approval.

**Post-push correction:** after commit `694bf79`, the user clarified that the
RealSense camera node was already running during the 26/06 Block C baseline.
Therefore the recorded `69.4-71.6 C` band must not be treated as a true idle
floor. It is a camera-node plus desktop/remote-session baseline, with no NCNN
subscriber load. The no-go decision for camera + NCNN remains conservative and
unchanged, because the Pi still had only limited headroom below the `80.0 C`
abort threshold. The next cooling check should use plain SSH with the
desktop/remote screen session closed and record both floors: first no-camera to
measure the absolute floor, then headless camera-on with no NCNN subscriber as
the real pre-inference gate. If headless camera-on remains near `70 C`, inspect
the physical cooler before any live inference retest.

**Headless retest result (post `47376f6`):** the full SSH/headless pipeline ran
on `imtaquadrone-desktop` (`10.120.2.249`) and passed the short-run gate under
the corrected operating condition. With the Remmina / desktop screen session
closed, the floors were far below the earlier desktop reading:

- No-camera floor: `51.25-54.00 C`, mean `52.19 C`.
- Camera-on / no-NCNN floor: `50.70-52.35 C`, mean `51.03 C`.
- Camera topic rate: stable mean `14.989 Hz` over `118` samples.

This confirms the active remote desktop session, not the cooler, was the
dominant confound: it had inflated the camera-on floor from about `51 C` to the
`70.9 C` recorded in `baseline_20260626_103348.txt`.

A bounded live `gate2_ros_live_infer.py` retest then completed cleanly through
the ROS camera topic into the custom `best_ncnn_model`: `150` frames in
`18.8 s`, `mean_fps=7.98`, and `mean_inf_ms=123.8`. Temperature went from
`54.55 C` before live inference to `67.75 C` at the helper's final read
(`65.55 C` at the last mid-loop print), then the immediate follow-up sysfs read
was `55.65 C`. No `80.0 C` abort occurred. dmesg stayed clean apart from the
usual boot-time `mmc*` signal-voltage lines. Inference ran about `2.75x` faster
than the 25/06 run (`123.8 ms` versus `340.9 ms`), consistent with the 25/06
spike having run near the thermal limit rather than at full clock.

All snapshot and live inference detections remained `0` boxes. That remains a
data/model/threshold issue, not a camera-path failure. `pyrealsense2` remained
absent from both `~/venvs/yolo-pi5` and `/usr/bin/python3`, and
`python3-pyrealsense2` had no apt candidate; no install was performed. The
installed RealSense C library packages were `librealsense2` `2.58.2`, while the
ROS camera stack remained `ros-jazzy-realsense2-camera` `4.58.1` with
`ros-jazzy-librealsense2` `2.58.1`.

Proven: a short, thermally clean, headless ROS-camera -> custom NCNN live run.
Not proven: detector quality, long-duration sustained inference, dashboard
integration, MAVROS, QGC, Herelink, or real-FCU integration. The `18.8 s` live
run had not reached a thermal plateau, so a multi-minute headless live run is
required before claiming sustained thermal viability.

**Next steps update:** treat the headless camera-on configuration as the
deployment-representative baseline. Cooler-mount inspection is no longer the
blocking step. Before any sustained-inference claim, run a multi-minute
headless live test to find the thermal plateau and confirm it stays under
`80.0 C`. Detector-quality work remains the separate Block G dataset/model
track.

**Late quick MAVProxy / MAVROS check:** before the afternoon YOLO / RealSense
tests, the box had been shut down and then relaunched. The usual startup
music/sound from the box was not heard, so the user suspected a cable or wiring
issue and requested a camera-off telemetry sanity check. Precheck showed no
RealSense / YOLO process, `/dev/ttyAMA0` present, no existing MAVLink UDP
listener on `14550`, `14551`, `14540`, or `5760`, `mavproxy.py` available at
`/home/imt-aqua-drone/.local/bin/mavproxy.py`, and `mavros` installed under
`/opt/ros/jazzy`. MAVProxy could open `/dev/ttyAMA0` at `57600` and start the
UDP fanout to `127.0.0.1:14550` and `127.0.0.1:14551`, but it stayed at
`Waiting for heartbeat from /dev/ttyAMA0` and then reported `link 1 down`.
MAVROS was not launched because the MAVProxy heartbeat gate failed. This points
to the flight-controller / peripheral side not talking to the Pi UART in this
box state, with a loose cable or missing peripheral/FC power as the leading
physical hypothesis. Follow up on Tuesday 30/06/2026 with a physical power and
wiring inspection, then rerun MAVProxy before launching MAVROS.

**End-of-day direct SDK comparison (post `0d83614`):** the final 26/06 check
kept the ROS camera node stopped; the direct RealSense SDK had exclusive camera
access. `pyrealsense2` remained isolated in `~/venvs/yolo-pi5-rs`, while the
direct NCNN helper bridged that package into the proven `~/venvs/yolo-pi5`
runtime through `PYTHONPATH`. The import gate passed with `pyrealsense2 2.58.2`,
`ultralytics 8.4.62`, `ncnn`, and D435I serial `213622070342`.

The direct SDK + NCNN `imgsz=640` short run completed: `150` frames in `23.1 s`,
`mean_fps=6.51`, `mean_inf_ms=151.9`, and `0` boxes. Temperature went from
`57.3 C` before inference to `68.85 C` at the helper's final read; the immediate
post-run sysfs read was `66.65 C`. No `80.0 C` abort occurred, and dmesg again
showed only the usual boot-time `mmc*` signal-voltage lines. This proves a short
direct-SDK camera -> custom NCNN path. At `imgsz=640`, however, the direct SDK
result (`6.51 fps`, `151.9 ms`) falls inside the ROS path's run-to-run spread
(`6.16-7.98 fps`, `123.8-160.6 ms`), so it shows no meaningful capture-overhead
advantage; the workload is inference-bound. It also does not overturn the
sustained thermal result: the earlier multi-run headless ROS + NCNN test still
climbed through the abort threshold (`80.4-82.05 C` aborts), so sustained
inference is not proven viable at the current `imgsz=640` profile.

The optional `--imgsz 320` direct SDK run was not usable as a comparison: it
segfaulted after model load, before any frame-count, FPS, inference-time, or
detection summary was printed. The same helper had just run cleanly at
`imgsz=640`, so the likely issue is the NCNN model path rather than the helper:
the model was exported for the `640` input profile, and a `320` frame can
mismatch the fixed blob shape inside NCNN. A real `imgsz=320` test should use a
separate workstation export at `imgsz=320` and copy that NCNN model to the Pi,
not start with a helper rewrite.

Final 26/06 state: short headless ROS-camera -> NCNN and short direct-SDK ->
NCNN paths are proven; direct camera-only `pyrealsense2` capture is proven; all
live detections remain `0` boxes; sustained inference under the current NCNN
profile failed the thermal gate; pyrealsense2 is not a thermal fix. Block G
dataset/model work was deliberately deferred today. Next bounded steps are:
physical power/wiring inspection plus MAVProxy heartbeat retry on Tuesday
30/06/2026, and a separate model/thermal profile decision before any further
sustained live-inference claim.

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
