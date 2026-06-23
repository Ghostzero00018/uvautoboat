# Tuesday 23/06/2026 - Professor onsite next-step check

## Purpose

Use the professor onsite window to decide the next practical direction after the 22/06 console / Herelink hotspot observation. Keep this as a decision and clarification day unless the professor explicitly approves a specific live test.

## Starting Context

- Repo should start clean/synced at `8b63668` or later.
- 22/06 video result: Herelink RTSP transport works at `rtsp://192.168.43.1:8554/fpv_stream` and TCP was clean, but the current stream content is Pi desktop / `rqt_image_view` after starting the Pi camera node, not a direct camera feed. Treat this as a source regression to raise with the professor.
- 22/06 MAVLink result: QGC receives unicast MAVLink from `192.168.43.1:52600` to workstation `192.168.43.160:14550`. QGC owns `14550`; the next read-only telemetry test is QGC MAVLink forwarding to a separate local UDP port and workstation MAVROS on that forwarded port.
- The dashboard remains simulation-first on `/wamv/*`; no real-topic adapter is implemented.
- The Pi RealSense direct dashboard path was already proven on 18/06 via `/camera/camera/color/image_raw`; do not repeat it unless the professor specifically asks.

## Boundaries

- No QGC Upload, mission upload, arming, mode change, parameter write, thruster, actuator, real-FCU command path, or dashboard mission/thruster use.
- No code/config/launch/YAML changes unless explicitly approved.
- No combined RealSense + MAVROS co-load on the Pi 5 unless the dedicated `>=5A` supply is confirmed.
- Keep video, MAVLink telemetry, and `/wamv/*` readiness as separate decisions.

## Block A - Repo Guard

- [x] Run:

  ```bash
  git fetch --prune
  git log --oneline -5
  git status --short --branch
  git rev-parse HEAD origin/main
  ```

- [x] If behind, run `git pull --ff-only`, then re-check.
- [x] If ahead, diverged, or dirty, stop and report.

**Outcome:** repo guard passed on 23/06/2026. `git fetch --prune`
completed, latest commit was `8b63668` (`docs(diary): scaffold 23/06
professor onsite check`), `git status --short --branch` showed clean
`## main...origin/main`, and `git rev-parse HEAD origin/main` returned the
same SHA `8b63668d73eea0470d838d4d5ff4abea7abf3f61` for both refs. The active
23/06 scaffold, the 22/06 console-hotspot diary, and the requested
Board/wiki source anchors were re-read before any diary update.

At this Block A checkpoint, no live QGC, Herelink, Pi, MAVROS, browser, or
network observation has run today.

## Block B - Professor Decision Check

Ask and record:

**Status:** professor was not onsite on 23/06/2026, so the original
professor-decision questions remain unanswered. No live QGC, Herelink, Pi,
MAVROS, browser, or network test is approved today.

- [ ] Should Herelink video be restored to direct camera feed, or is Pi desktop / `rqt_image_view` screen capture intentional?
- [ ] If direct camera feed is desired, who changes the Herelink / Pi image-transmission setup?
- [ ] Is the next telemetry test allowed to use QGC MAVLink forwarding to a local UDP port for workstation MAVROS?
- [ ] Which local port should be reserved for the forwarded MAVROS leg? Avoid QGC's `14550`.
- [ ] Should the next work prioritize video-source repair, read-only MAVROS via QGC forwarding, post-update simulation smoke test, or documentation/planning only?
- [ ] Confirm whether any live test is approved today and who runs it.

### Change of Plan - YOLO / RealSense Training Direction

Planning decision only; no code/config/launch/YAML changes and no live camera
or hardware run.

- Train custom object-detection models on the Linux workstation GPU, not on the
  Pi 5. The Pi 5 remains the capture and deployment-validation target.
- Workstation GPU check on 23/06/2026:
  `NVIDIA RTX A3000 Laptop GPU`, `6144 MiB`, driver `580.159.03`, idle at
  `48 C`, `0 %` utilization, `15 MiB` used. The host GPU is healthy.
- Current Pi 5 YOLO evidence is feasibility only: `yolo26n.pt` loaded,
  exported to `yolo26n_ncnn_model`, and ran static-image CPU inference on the
  `bus.jpg` fallback. This is a stock pretrained COCO-model check, not custom
  USV perception, not a ROS node, not RealSense stream inference, and not
  dashboard integration.
- For "what object is where" use object detection with bounding boxes, not
  whole-image classification.
- Use Pi 5 + RealSense to capture RGB frames at the intended deployment
  viewpoint, lighting, distance, and resolution. Keep diversity higher priority
  than raw frame count for the first dataset.
- Use X-AnyLabeling on the workstation for labeling, review, correction, and
  YOLO-format export. Prefer model-assisted pre-labeling only as a bootstrap;
  manually correct labels before training.
- Run training with the Ultralytics CLI on the workstation for reproducibility,
  starting from `yolo26n.pt`. First pass: `imgsz=640`, batch around `8-16` on
  the 6 GB GPU; if memory fails, reduce batch before reducing image size.
  Keep `yolo11n` as a fallback if `yolo26n` causes a toolchain issue.
- Export the trained model to NCNN on the workstation, then validate on Pi 5:
  inference speed, temperature, power stability, and RealSense coexistence.
- Do not combine heavy RealSense + YOLO + MAVROS workloads on the Pi 5 until
  the dedicated `>=5A` power path is confirmed and monitored.

### YOLO Toolchain And Wiki Closeout

Static YOLO toolchain validation and documentation, with no RealSense live
stream, QGC, Herelink, MAVROS, dashboard, ROS node, or real-FCU path:

- CUDA training gate passed in `~/venvs/yolo-ws`:
  `torch.cuda.is_available()` returned `True` and the device name was
  `NVIDIA RTX A3000 Laptop GPU`.
- One-epoch smoke training ran outside the repo under
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06`:
  `yolo train data=coco8.yaml model=yolo26n.pt epochs=1 imgsz=640 device=0`
  wrote `runs/smoke/weights/best.pt`.
- NCNN export succeeded from that smoke checkpoint and wrote
  `runs/smoke/weights/best_ncnn_model`.
- The smoke metrics are toolchain evidence only. They do not measure project
  detector quality because `coco8.yaml` is a tiny COCO sample and the model
  starts from COCO-pretrained weights.
- The NCNN export disabled the end-to-end branch and produced the classic
  output shape `(1, 84, 8400)`, so Pi-side NCNN inference still needs normal
  NMS postprocessing.
- `wiki/YOLO_Dataset_Plan.md` was added and linked from the wiki/root doc
  surfaces in commit `8fdb975` (`docs(wiki): add YOLO dataset plan and status
  links`). That page records the first-pass classes, label rules, capture
  protocol, dataset layout, clean training shell, export caveat, and Pi
  validation gates.
- X-AnyLabeling `4.0.0-beta.10` launched from the separate
  `~/venvs/x-anylabeling` environment, and a disposable `coco8` image
  successfully exported YOLO-Hbb as a valid `.txt` row using class order
  `buoy`, `vessel`, `dock`, `obstacle`, `person`. The disposable test
  `.txt` / `.json` files were removed after verification.
- Pi 5 static-image handoff check ran on `imt-aqua-drone@10.120.2.249` using
  the workstation-exported `best_ncnn_model` and `000000000042.jpg`. The Pi
  `~/venvs/yolo-pi5` runtime had `ultralytics 8.4.62` and
  `ncnn 1.0.20260526`.
- The Pi loaded the NCNN export and completed three CPU inference runs at
  `imgsz=640`, with `boxes=2` each time. Wall times were `729.1 ms`,
  `304.2 ms`, and `251.6 ms`; reported inference times were `211.4 ms`,
  `281.1 ms`, and `226.0 ms`. Treat run 1 as warm-up.
- Pi CPU temperature stayed stable from `68.85 C` before inference to
  `68.30 C` after inference. `dmesg` showed only boot-time storage-bus voltage
  messages, not undervoltage or throttling evidence.
- This proves the workstation-to-Pi NCNN handoff and Pi CPU inference runtime
  only. The model metadata still contains COCO classes, not the future
  `buoy` / `vessel` / `dock` / `obstacle` / `person` detector. No custom
  RealSense dataset capture, real-data training, live RealSense inference, ROS
  node, dashboard integration, MAVROS, QGC, Herelink, or real-FCU path was run.

## Block C - Optional Live Test Only If Approved

Candidate test, read-only only:

```text
QGC receives on 14550 -> QGC MAVLink forwarding to separate local UDP port -> workstation MAVROS -> ROS 2 topics
```

Do not run until the professor and user explicitly approve the live test.

Pass criteria if run:

- [ ] QGC remains connected and telemetry visible.
- [ ] MAVROS connects on the forwarded port without binding QGC's `14550`.
- [ ] `/mavros/state connected: true`.
- [ ] Live `/mavros/imu/data`.
- [ ] Live GPS topic, even if no fix.
- [ ] Battery/status topic if available.
- [ ] Record `ros2 topic info --verbose` QoS for any topic that might feed dashboard/adapter work later.

## Wrap

- [x] Record professor decisions and exact wording.
- [x] Keep video-source decision separate from MAVLink-forwarding decision.
- [x] Keep `/wamv/*` replacement as design-only unless explicitly approved.
- [x] If docs/diary changed, run:

  ```bash
  git status --short --branch
  git diff --check
  rg -n "^(<{7}|={7}|>{7})" working_diary/2026-06-23_tuesday_professor_onsite_next_steps.md
  ```

- [x] Run the public-repo visibility sweep before any commit.
- [x] End with bounded next steps.

**Wrap outcome:** professor was absent, so there were no professor decisions to
record beyond the unanswered questions above. Video-source repair, QGC-forwarded
MAVROS, and `/wamv/*` replacement remain separate future decisions. Today's
executed work stayed outside live command/control paths: documentation,
workstation YOLO setup, X-AnyLabeling export verification, and a Pi static-image
NCNN handoff check only.

**Next steps:** on a later approved Pi capture day, create the real
`data.yaml` / `dataset_card.md`, capture diverse RealSense RGB frames, label a
first maritime dataset, train on the workstation, export NCNN, and repeat Pi
static-image validation with that custom model before any live RealSense,
ROS/dashboard, MAVROS, QGC, Herelink, or real-FCU integration.
