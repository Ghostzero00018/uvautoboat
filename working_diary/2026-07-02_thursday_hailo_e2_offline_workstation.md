# Thursday 02/07/2026 - Hailo E2 Offline Workstation Plan

## Day Overview

Tomorrow's Hailo task stays offline and workstation-side. Do not run Pi-side
commands. The official E2 artifact row is now in hand and pinned, so the goal is
to prepare the workstation toolchain and retire the custom-model compile risk:

1. move the downloaded official artifacts into the external ledger and record
   checksums;
2. use the Hailo AI Software Suite Docker as the first compile route; and
3. attempt the `yolo26n.pt` -> `hailo8l` HEF path with disciplined stop points.

The official Hailo Dataflow Compiler remains the destination for the custom
`yolo26n` maritime detector. Community / no-account routes are fallback-only
now: useful for stock smoke-test HEFs or a possible YOLOv8 / YOLO11 fallback,
but not the primary path for this session.

## Starting Context

- 01/07/2026 ended clean and pushed at `ce23aa3` or later; the key landed
  state is `ce23aa3 docs(wiki): confirm Hailo E2 artifact row`.
- `wiki/Hailo_HAT_Workstream.md` is the durable planning surface.
- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md` is the live
  evidence log.
- Pipeline 1 proved the HAT is healthy at the PCIe layer on the Pi 5:
  Ubuntu 24.04.4, kernel `6.8.0-1057-raspi`, Python 3.12.3, Hailo `1e60:2864`,
  gen-3 x1 link-up.
- The same probe found no Hailo runtime: no `/dev/hailo*`, no `hailortcli`, no
  `hailo-all`, no `hailort`, no `python3-hailort`, no `hailo-tappas-core`, and
  no Raspberry Pi apt source after `sudo apt update`.
- Branch decision from 01/07/2026: close E1 for this live Ubuntu image. The
  active path is E2 Ubuntu/manual.
- Official Hailo access landed on 01/07/2026. The full 4.24.0 runtime row,
  DFC 3.34.0, Model Zoo 2.19.0, both cp312 pyHailoRT wheels, and the
  `hailo8_ai_sw_suite_2026-07_docker.zip` image were downloaded and inspected.
- `wiki/Hailo_HAT_Workstream.md` now records these pins as confirmed and
  recommends the Docker suite as the first compile route.

## Session Evidence - 02/07/2026

Repo guard passed at the start of the session:

- `main` matched `origin/main` at
  `f090158e59b7042809b1eb4b84c66334f72cdaaa`.
- No pull was needed.
- `git status --short --branch` returned `## main...origin/main`.

The official artifact row was present, then staged outside the repo under:

```text
/home/ghostzero/hailo_artifacts/2026-07-02/
```

The Docker zip was moved into `official/` to avoid a duplicate 8.5G copy.
The smaller `.deb` and `.whl` files were copied into the same directory. The
external ledger is:

```text
/home/ghostzero/hailo_artifacts/2026-07-02/logs/ledger.txt
/home/ghostzero/hailo_artifacts/2026-07-02/logs/sha256sums_official.txt
```

The byte-identical duplicate
`hailort-pcie-driver_4.24.0_all(1).deb` was deleted from `Downloads` after
`cmp` passed and both files matched SHA256
`3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b`.

Official checksums:

```text
5e9a21f56217b131e49afdcacaebf3e200fd03a4d205d61bcb07ceda9c4542f6  hailo8_ai_sw_suite_2026-07_docker.zip
f539ebb5997149ec68ca443a547196a03d28c624fbb072fdcd22a7d37fad9fb1  hailo_dataflow_compiler-3.34.0-py3-none-linux_x86_64.whl
3f574626abf8fae103812bb8136431974a89ea693b098866d2455a2c7b7103c7  hailo_model_zoo-2.19.0-py3-none-any.whl
72b6becf9334466b055d5f90a69a1cd609c84abd6929bd6a37a730243a2fb21d  hailort-4.24.0-cp312-cp312-linux_aarch64.whl
7818ee8fe70a7f8a90f2485aaf488d0572fe2078d16728ae0716a42905e3d573  hailort-4.24.0-cp312-cp312-linux_x86_64.whl
3d13d833cfafe1231f42ead9b02f1c08348fa640fd282119e57baa848b31618b  hailort-pcie-driver_4.24.0_all.deb
1df39dfe1ce2c5beaa70c8d8a7ce807ff8ff81fa18a4b06d3ca06247d0203c47  hailort_4.24.0_amd64.deb
9ac1a633cf8adb3e036544ddc2ac9568acacc31bef41a518da7e14343b4e5cc6  hailort_4.24.0_arm64.deb
```

Firmware note: no standalone firmware file was staged today. The pinned row
treats `hailo8_fw.bin` as bundled with the 4.24.0 driver/runtime packages;
verify `/lib/firmware/hailo/hailo8_fw.bin` only during a later Pi install.

Same-batch TAPPAS 5.3.1 downloads were deliberately excluded from the official
4.24.0 / 3.34.0 / 2.19.0 ledger and left in `Downloads`:

```text
d67b3df147e70f6ee89d115237827cd3d82fcd050818340f7cb224886851cbac  hailo-tappas-core_5.3.1_amd64.deb
9db31ee78ee0eade7f6e350abc3426d6c35e792a6dc18112f8fa908c80667e90  hailo-tappas-core_5.3.1_arm64.deb
8c1151b135b782d9e3e44c193ba2883b50ae57a00acfb47d71a3292b123e84b1  hailo_tappas_core_python_binding-5.3.1-py3-none-any.whl
```

Workstation host check:

- Host: `vrx-Precision-7560`.
- OS/kernel: Ubuntu 24.04.4 LTS, kernel `6.17.0-35-generic`.
- Architecture: `x86_64`.
- Python: `3.12.3`.
- CPU: 16 logical processors, AVX and AVX2 present.
- Memory: 14Gi physical RAM, 4.0Gi swap, 10Gi available.
- Disk: `/home` and `/tmp` have 50G available.
- GPU: a follow-up host-terminal `nvidia-smi` check reported driver
  `580.159.03`, CUDA `13.0`, and `NVIDIA RTX A3000 Laptop GPU` with 6GiB VRAM.
  This is a positive optional acceleration signal for DFC optimization; it does
  not remove the Docker gate or the physical-RAM warning.
- Container tooling: `docker`, `podman`, and `nerdctl` were not in `PATH`.
- Bare-metal Hailo compile tooling: `hailomz` and `hailo` were not in `PATH`.

Dataset/checkpoint check:

- Checkpoint exists:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt`
  at 5.2M.
- Current curated split has 11 images and 11 label files.
- This is enough to prove file plumbing only. It is below the 64-frame
  mechanics target for a first calibration run and far below the 500-1024
  maritime-frame range needed for meaningful int8 accuracy.

Docker archive inspection:

- `hailo8_ai_sw_suite_2026-07_docker.zip` contains exactly:
  `hailo8_ai_sw_suite_2026-07.tar.gz` and
  `hailo_ai_sw_suite_docker_run.sh`.
- The run script is Docker-first: it checks Docker installation/user access,
  validates DFC system requirements, then calls `docker load -i` on the bundled
  tarball.
- Initial blocker: no Docker command existed on this host. The host also has
  only 14Gi physical RAM versus the DFC 16GB documented floor; the bundled
  script's shell check counts swap in its total-memory line, so swap-on allowed
  the requirement check to pass after Docker was installed.

Docker host remediation and suite load:

- Docker Engine was installed from the official apt repo. `hello-world` passed
  and `docker --version` reported `Docker version 29.6.1, build 8900f1d`.
- NVIDIA Container Toolkit `1.19.1-1` was installed before the first Hailo suite
  run. `/etc/docker/daemon.json` gained the `nvidia` runtime, Docker was
  restarted, and `sudo docker run --rm --runtime=nvidia --gpus all ubuntu
  nvidia-smi` showed driver `580.159.03`, CUDA `13.0`, and the RTX A3000 Laptop
  GPU inside the container.
- `sudo usermod -aG docker $USER` plus `newgrp docker` enabled non-root Docker
  access in the active shell. `docker info` showed runtime `nvidia`, default
  runtime `runc`, 16 CPUs, total memory `14.83GiB`, and Docker root
  `/var/lib/docker`.
- The suite was extracted into
  `/home/ghostzero/hailo_artifacts/2026-07-02/suite_run/`, leaving the official
  archive byte-stable in `official/`. Free space before suite load was 41G.
- `./hailo_ai_sw_suite_docker_run.sh` passed the vendor system requirement
  check with the expected below-32GB RAM warning, loaded image
  `hailo8_ai_sw_suite_2026-07:latest`, and started
  `hailo8_ai_sw_suite_2026-07_container` with `--gpus all`.
- Inside the container, `hailo --version` reported HailoRT `4.24.0` and Hailo
  Dataflow Compiler `3.34.0`; `hailomz --version` reported Hailo Model Zoo
  `2.19.0`.
- The container reported `No Hailo PCIe device was found`, which is expected on
  the workstation.
- After image load was verified, the extracted
  `hailo8_ai_sw_suite_2026-07.tar.gz` was deleted. `docker images` showed
  `hailo8_ai_sw_suite_2026-07:latest` with image ID `962aeda88f61`, disk usage
  34.7GB, and content size 17.2GB. `df -h /home` then showed 18G free.

Compile status after Docker gate close:

- Route A preflight staged
  `/home/ghostzero/hailo_artifacts/2026-07-02/suite_run/shared_with_docker/yolo26n_route_a/`.
- `weights/yolo26n_best.pt` was copied from the dataset run checkpoint.
- `calib_raw_28/` contains 28 RealSense RGB frames copied from the raw capture
  tree: 11 top-level curated frames plus 17 frames from
  `rejected_2026-06-24/`. The rejected frames are usable as unlabeled
  deployment-domain pixels for calibration mechanics only; this remains below
  the minimum 64-frame mechanics target and far below quality calibration scale.
- First container write test failed because the container user is
  `hailo:ht` (`uid=10642`, `gid=10600`) while the host-created subdirectories
  were owned by host UID `1002`. After removing the root-owned test file and
  running `chmod -R a+rwX shared_with_docker/yolo26n_route_a`, the container
  write test passed with `WRITE_OK`.
- Hailo container Python has `torch 2.9.1+cu128`, `onnx 1.16.0`, and
  `onnxsim 0.4.36`, but no `ultralytics` module and no `yolo` CLI.
- Host YOLO environment `/home/ghostzero/venvs/yolo-ws` has Ultralytics
  `8.4.75`; `yolo cfg` includes `end2end`, `nms`, `dynamic`, `simplify`,
  `opset`, and `imgsz` export settings.
- First host-side ONNX export succeeded after Ultralytics auto-installed missing
  ONNX export dependencies into `/home/ghostzero/venvs/yolo-ws`: `onnx 1.22.0`,
  `onnxruntime 1.27.0`, and `onnxslim 0.1.94`.
- Export command used `imgsz=640`, `dynamic=False`, `simplify=True`,
  `opset=13`, `nms=False`, `end2end=False`, and `device=cpu`.
- Output ONNX:
  `exports/yolo26n_best_imgsz640_end2end_false_opset13.onnx`, size 9.4M,
  SHA256 `6a6fca85b9f78fed48b792a953f131f3c2c9f316e3bb6b388f2d57dee0287616`.
- Local ONNX inspection showed IR version 7, opset 13, input `images`
  `[1, 3, 640, 640]`, output `output0` `[1, 9, 8400]`, 368 nodes, and no
  `TopK` or `GatherElements` operators in the exported graph.
- Container ONNX inspection confirmed the same graph summary.
- First Hailo parse attempt used `hailomz parse yolo26n --ckpt <onnx>
  --hw-arch hailo8l`. It failed with `PARSE_STATUS=1` because the Model Zoo
  `yolo26n` config looked for one-to-one head end nodes
  `/model.23/one2one_cv*`, which are absent from the Route A `end2end=False`
  one-to-many export.
- Follow-up ONNX graph inspection found the actual output producer node is
  `/model.23/Concat_3`, producing `output0` from `/model.23/Mul_2_output_0`
  and `/model.23/Sigmoid_output_0`.
- Raw DFC parser attempt succeeded with `RAW_PARSE_STATUS=0` using
  `hailo parser onnx ... --hw-arch hailo8l --end-node-names /model.23/Concat_3`.
  The parser detected a YOLOv6-equivalent NMS structure, recommended the six
  detection-head Conv end nodes, reran translation with those mapped end nodes,
  and added an NMS postprocess command to the model script.
- Raw parser outputs:
  `exports/yolo26n_route_a_raw_parser.har` (9.7M, SHA256
  `02987e05d6733ab871123451fe58c21525aabbf2c4227fad8e1db692a7fd5ab3`),
  `exports/yolo26n_route_a_augmented.onnx` (9.4M), and
  `logs/hailo_parser_onnx_yolo26n_route_a_report.html` (474K).
- `hailo har info exports/yolo26n_route_a_raw_parser.har` reports model name
  `yolo26n_route_a`, state `Hailo Model`, NMS meta architecture `Yolov6`,
  NMS target device `Nn_Core`, SDK version `3.34.0`, hardware architecture
  `hailo8l`, and HAR files including `.hn`, `.alls`, `.nms.json`, `.npz`,
  `.postprocess.onnx`, and `.metadata.json`.
- `hailo optimize --help` requires either `--calib-set-path` to a preprocessed
  calibration `.npy` shaped `(calib_size, h, w, c)` or
  `--use-random-calib-set`; `hailo compiler --help` accepts a HAR plus
  `--hw-arch hailo8l` and an output directory / output HAR path.
- A mechanics-only calibration file was created at
  `calib_npys/calib_raw_28_letterbox_640_uint8_nhwc.npy`: 28 images,
  shape `(28, 640, 640, 3)`, dtype `uint8`, min/max `0/255`, size 33M.
- First optimize attempt used the raw-parser HAR, `--hw-arch hailo8l`, that
  calibration `.npy`, and output path
  `exports/yolo26n_route_a_optimized_calib28.har`. It failed with
  `OPTIMIZE_STATUS=1`; no optimized HAR was produced.
- Optimizer failure is localized to the auto-added NMS postprocess. The HAR's
  `yolo26n_route_a.alls` contains only `nms_postprocess(meta_arch=yolov6)`, and
  `yolo26n_route_a.nms.json` has three bbox decoders with empty `reg_layer` and
  `cls_layer` values. The traceback ends with
  `HailoNNException: The layer named  doesn't exist in the HN`.
- The HN output layer order is unambiguous:
  `conv61/conv64` at 80x80, `conv77/conv80` at 40x40, and `conv91/conv94` at
  20x20. The reg layers have 4 channels and the class layers have 5 channels.
- Follow-up syntax discovery wrote
  `logs/nms_postprocess_examples_head.txt` and `logs/yolo_config_paths.txt`.
  The shipped examples consistently use `nms_postprocess("<json>",
  meta_arch=..., engine=...)` for YOLO-style models, including `yolo26n.alls`,
  `yolov8n.alls`, `yolov6n.alls`, and `yolov6n_0.2.1_nms_core.alls`.
  Available reference configs include `cfg/postprocess_config/yolov8n_nms_config.json`,
  `cfg/postprocess_config/nms_config_yolov6n.json`, and
  `cfg/postprocess_config/yolov6n_0_2_1_nms_config.json`.
- Schema inspection wrote `logs/nms_reference_schema.txt`. The shipped
  `yolo26n.alls` uses the same head layer names already found in this HAR
  (`conv61`, `conv77`, `conv91`, `conv64`, `conv80`, `conv94`) but does not
  add NMS. The `yolov8n_nms_config.json` schema matches a two-layer
  anchorless decoder with `reg_layer` and `cls_layer`, while
  `yolov6n_0_2_1_nms_config.json` keeps blank decoder layers for the
  NMS-core fused-decoder path and is the wrong pattern for the current
  optimizer failure.
- Explicit six-head parse used the six parser-recommended Conv endpoints and
  answered `n` to the NMS postprocess prompt. It succeeded with
  `SIX_HEAD_PARSE_STATUS=0` and wrote
  `exports/yolo26n_route_a_six_heads_no_nms.har`.
- The six-head HAR still contains `yolo26n_route_a_six_heads.nms.json`,
  `yolo26n_route_a_six_heads.postprocess.onnx`, and metadata marking
  `nms_meta_arch` as `yolov6` and `nms_engine` as `nn_core`. It does not
  contain a `.alls` file. The retained NMS JSON still has `classes: 4` and
  blank `reg_layer` / `cls_layer` fields.
- HN inspection confirms the six output layers are present in order:
  `conv61`, `conv64`, `conv77`, `conv80`, `conv91`, `conv94`, with
  `output_layer1` through `output_layer6`.
- The compile precheck was run before the six-head optimize block produced an
  optimized HAR. `hailo compiler --help` confirmed `--hw-arch`, `--output-dir`,
  `--output-har-path`, and `--model-script` are accepted by DFC `3.34.0`, but
  `hailo har info exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har`
  failed with `FileNotFoundError`. Host-side inspection confirmed there is no
  six-head optimized HAR and no six-head optimize log yet. This is an ordering
  miss, not a compile or graph failure.
- Six-head optimize then succeeded with `SIX_HEAD_OPTIMIZE_STATUS=0` using the
  mechanics-only no-NMS model script, 28-image calibration set, `--hw-arch
  hailo8l`, and output path
  `exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har`.
- The optimize log confirms no `nms_postprocess` command was applied. It used
  28 calibration entries, ran optimization level 0, skipped finetune,
  bias correction, Adaround, quantization-aware fine-tuning, and layer-noise
  analysis, and saved the optimized HAR.
- Optimized HAR:
  `exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har`, size 55M,
  SHA256 `1f81fbff5a7446b03f2ca43991bb0670673bee5f2c87b65ae6eb8adca8b47c38`.
- `hailo har info` on the optimized HAR reports model name
  `yolo26n_route_a_six_heads`, state `Quantized Model`, SDK version `3.34.0`,
  and hardware architecture `hailo8l`.
- The optimized HAR's `.alls` contains normalization, calibration config,
  optimization level 0, and quantization params for `dw1`, `dw6`, `dw7`,
  `dw8`, the six head convs, and `output_layer1` through `output_layer6`; it
  does not contain `nms_postprocess`.
- Six-head compile succeeded with `SIX_HEAD_COMPILE_STATUS=0`. The compiler
  reported successful mapping, built the HEF, and saved:
  `exports/yolo26n_route_a_six_heads.hef` and
  `exports/yolo26n_route_a_six_heads_compiled.har`.
- Compile artifacts:
  `exports/yolo26n_route_a_six_heads.hef`, size 11M, SHA256
  `edc03c3ca099167970ea0b851af7eea892c76b81aceabfb5a54e9ec46afb932d`;
  `exports/yolo26n_route_a_six_heads_compiled.har`, size 66M, SHA256
  `6e20ebbf2dec853e941b09deada71998f06fd32edd4dad3e096592298478f7d3`.
- `hailortcli parse-hef exports/yolo26n_route_a_six_heads.hef` confirms
  architecture `HAILO8L`, network group `yolo26n_route_a_six_heads`,
  multi-context with 6 contexts, input `input_layer1` as `UINT8`
  `NHWC(640x640x3)`, and six raw output vstreams:
  `conv61` `UINT16` `NHWC(80x80x4)`, `conv64` `UINT16` `FCR(80x80x5)`,
  `conv77` `UINT16` `NHWC(40x40x4)`, `conv80` `UINT16` `FCR(40x40x5)`,
  `conv91` `UINT16` `FCR(20x20x4)`, and `conv94` `UINT16` `FCR(20x20x5)`.
- The HEF is a raw six-output artifact with no embedded HailoRT NMS /
  postprocess stage. Decode and NMS remain host-side for the future Pi runtime
  path.
- Dataset class mapping is five classes: `0 buoy`, `1 vessel`, `2 dock`,
  `3 obstacle`, `4 person`, matching the HEF's 5-channel class outputs. The
  earlier auto-generated NMS JSON's `classes: 4` value was wrong for this
  checkpoint and is another reason not to use the auto-NMS path.
- Decode handoff details for the future runtime session:
  the box heads are 4-channel outputs (`conv61`, `conv77`, `conv91`), not
  64-channel YOLOv8 DFL tensors. The ONNX export's `output0` shape
  `[1, 9, 8400]` resolves this as 4 box channels plus 5 class channels over
  80x80 + 40x40 + 20x20 positions, so the future decoder should use direct
  4-channel box regression with anchor-center / stride handling, not a
  64-channel DFL softmax / projection decoder. The class heads (`conv64`,
  `conv80`, `conv94`) are raw logits in this artifact; host-side decode should
  apply sigmoid. The output formats are mixed (`NHWC` and `FCR`), so the
  runtime reader must handle layout conversion before decode / NMS.
- Block E remains fallback-only; no community HEF or DeGirum path was used.

Next gate before any Pi command:

1. Keep using the `newgrp docker` shell, or sign out/in later before opening new
   terminals that need non-root Docker.
2. Treat Route A workstation compile as closed: valid `hailo8l` HEF exists at
   `exports/yolo26n_route_a_six_heads.hef`, but it is mechanics-only because
   calibration used 28 mixed curated/rejected frames and optimization level 0.
3. Before any Pi-side runtime work, plan the deployment contract for this raw
   six-output HEF: preprocessing, output tensor order / format handling, decode,
   direct 4-channel box regression with anchor-center / stride handling, class
   sigmoid, NMS, class mapping, and artifact copy path.
4. If manual NMS is attempted later, prefer the `yolov8n_nms_config.json`
   two-layer schema with explicit HN layer names; avoid the blank-layer
   NMS-core fused-decoder schema for this route.
5. Keep the current 28-frame calibration set classified as mechanics-only; it is
   not an accuracy-quality int8 calibration set.
6. Treat free disk as tight at 17G. Monitor `df -h /home` during Route A and do
   not create large duplicate exports outside `shared_with_docker`.
7. Only after an explicit new session starts for Pi runtime should Pi-side
   install, copy, or execution commands be considered.

## Boundaries

- Markdown docs may be edited. Do not edit Python, YAML, launch files,
  JavaScript, package files, shell scripts, or helper code unless explicitly
  requested.
- No Pi commands tomorrow unless the user explicitly changes the scope.
- No runtime install on the Pi. Success tomorrow is a prepared artifact /
  compile path, not `/dev/hailo0`.
- Keep downloaded packages, wheels, HEFs, calibration images, logs, and vendor
  artifacts outside the public repo.
- Do not mix Hailo 5.x artifacts into this board's path. The 13 TOPS Hailo-8L
  board stays on the HailoRT 4.x / `hailo8` line.
- Do not combine this with MAVProxy, MAVROS, QGC, Herelink, dashboard, real-FCU,
  mission upload, arming, mode change, parameter write, thruster, or actuator
  work.

## Block A - Repo Guard And Source Read

Run from the repo root:

```bash
git fetch --prune
git log --oneline -5
git status --short --branch
git rev-parse HEAD origin/main
```

Expected starting point:

```text
ce23aa3 docs(wiki): confirm Hailo E2 artifact row, or later
```

Read first:

- `working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md`
- `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md`
- `wiki/Hailo_HAT_Workstream.md`
- `wiki/YOLO_Dataset_Plan.md`
- `Board.md`

Guard:

- If behind `origin/main`, run `git pull --ff-only`, then re-check.
- If ahead, diverged, or dirty, stop and report before starting artifact work.
- Record the exact starting SHA and whether a pull was needed.

## Block B - Official Artifact Presence Gate

Purpose: confirm the downloaded official set is still present and complete
before installing or loading anything.

Inspect the local downloads first:

```bash
cd /home/ghostzero/Downloads

ls -lh \
  hailort-pcie-driver_4.24.0_all.deb \
  hailort_4.24.0_arm64.deb \
  hailort-4.24.0-cp312-cp312-linux_aarch64.whl \
  hailort_4.24.0_amd64.deb \
  hailort-4.24.0-cp312-cp312-linux_x86_64.whl \
  hailo_dataflow_compiler-3.34.0-py3-none-linux_x86_64.whl \
  hailo_model_zoo-2.19.0-py3-none-any.whl \
  hailo8_ai_sw_suite_2026-07_docker.zip
```

Also check the Hailo portal only for drift:

- Is the pinned 4.24.0 / 3.34.0 / 2.19.0 row still the intended row for
  Hailo-8L?
- Has a newer coherent 4.x / 3.x / 2.x row landed since the files were
  downloaded?
- If a newer row exists, decide deliberately whether to stay pinned for this
  bring-up or replace the whole row. Do not mix.

Record exact filenames and checksums in the external ledger. Do not install
anything on the Pi.

Use this decision:

- If the official downloads are present, follow Block D and then Block F.
- If one file is missing, recover the same exact row from the portal before
  compiling.
- If the Docker suite cannot load or DFC cannot run, use Block E only as a
  fallback record, not as the main path.

## Block C - Workstation Host And Dataset Check

Run on the x86_64 Linux workstation:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat

echo "=== repo ==="
git status --short --branch
git log --oneline -5

echo "=== host ==="
hostname
date '+%Y-%m-%d %H:%M:%S %Z'
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release
uname -m
python3 --version

echo "=== resources ==="
free -h
nproc
grep -m1 -i 'flags' /proc/cpuinfo | grep -o 'avx[^ ]*' | sort -u || true
df -h /home /tmp

echo "=== optional acceleration / container ==="
nvidia-smi || true
docker --version || true
docker info >/tmp/hailo_docker_info_20260702.txt 2>&1; tail -40 /tmp/hailo_docker_info_20260702.txt || true
```

Dataset and checkpoint check. Confirm these paths first and adjust them if
tomorrow's export workspace differs:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06

echo "=== checkpoint ==="
test -f runs/baseline_yolo26n/weights/best.pt
ls -lh runs/baseline_yolo26n/weights/best.pt

echo "=== data counts ==="
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | wc -l
find labels/train labels/val -type f -iname '*.txt' | wc -l

echo "=== first calibration candidates ==="
find images/train images/val -type f \( -iname '*.jpg' -o -iname '*.png' \) | sort | head -40
```

Interpretation:

- The Pi never compiles. If the workstation cannot run DFC bare-metal, prefer
  the official Hailo software-suite Docker route if available.
- A tiny calibration pool is enough only for mechanics. Treat meaningful int8
  accuracy as requiring a larger deployment-domain maritime set.
- Do not copy artifacts into the repo.

## Block D - Official Docker-First Route

Purpose: ledger the confirmed official row, load the Docker suite if host checks
pass, and prepare the custom-model compile path.

Create an external artifact ledger outside the repo:

```bash
mkdir -p /home/ghostzero/hailo_artifacts/2026-07-02/{official,logs}
cd /home/ghostzero/hailo_artifacts/2026-07-02

echo "Hailo E2 official artifact ledger - 02/07/2026" > logs/ledger.txt
echo "source: Hailo download portal, checked manually on 01/07/2026" >> logs/ledger.txt
```

Move or copy the downloaded official artifacts into `official/`, keeping them
outside the repo. Delete the duplicate `(1)` driver copy if it is byte-identical.
For every official artifact, record:

- filename;
- version;
- architecture;
- Python tag, if a wheel;
- source page label;
- SHA256 checksum;
- whether it is runtime-side, compile-side, or firmware.

Checksum template:

```bash
cd /home/ghostzero/hailo_artifacts/2026-07-02/official
sha256sum * | tee ../logs/sha256sums_official.txt
```

Minimum official row to confirm:

| Layer | Needed artifact | Constraint |
| --- | --- | --- |
| Pi runtime | PCIe driver | HailoRT 4.x / `hailo8`; driver floor >= 4.19 for the Pi's `6.8-raspi` kernel |
| Pi runtime | HailoRT arm64 runtime | same 4.x version as driver and firmware |
| Pi runtime | `pyhailort` aarch64 wheel | `cp312` is confirmed for Ubuntu 24.04 Python 3.12 in the pinned row |
| Pi runtime | firmware | same 4.x version as driver/runtime |
| Workstation compile | Dataflow Compiler 3.x | x86_64 only; use the row matched to Model Zoo 2.x |
| Workstation compile | Model Zoo 2.x | same row as DFC |
| Workstation validation | HailoRT x86 | same runtime line as the target HEF |

Primary workstation path:

1. Load the Hailo AI Software Suite Docker image from
   `hailo8_ai_sw_suite_2026-07_docker.zip`.
2. Start the container with the bundled run script.
3. Inside the container, verify the bundled versions before compiling:
   `hailo --version`, `hailomz --version`, and any HailoRT version command
   available.
4. Use this same container for the first `yolo26n.pt` compile attempt.

Bare-metal wheels remain fallback/scriptable artifacts. Do not mix Docker and
bare-metal commands unless the versions match.

## Block E - Fallback Routes, Only If Official Compile Path Blocks

Use this only if Block D cannot load the Docker image, the DFC cannot run, or a
needed official artifact is missing and cannot be recovered quickly.

Purpose: keep progress moving without pretending the custom `yolo26n` risk is
solved.

Allowed bridge work:

- Stage public HailoRT 4.x / `hailo8` source references for later source-build
  planning.
- Stage the public PCIe driver source reference.
- Stage a public Hailo-8L firmware reference.
- Stage a prebuilt public `hailo8l` HEF such as a stock YOLOv8n or YOLO11n
  model for a later smoke test.
- Check whether DeGirum access is available for a YOLOv8 / YOLO11 HEF path.

Do not claim:

- that DeGirum solves the current `yolo26n` custom-model path;
- that a stock HEF proves custom maritime-detector quality;
- that source-build runtime staging means the Pi is ready to install;
- that any community HEF replaces the official DFC path for `yolo26n`.

Bridge ledger:

```bash
mkdir -p /home/ghostzero/hailo_artifacts/2026-07-02/{community,logs}
cd /home/ghostzero/hailo_artifacts/2026-07-02

echo "Hailo E2 community bridge ledger - 02/07/2026" > logs/community_ledger.txt
echo "scope: fallback bridge only; official Docker/DFC remains primary for yolo26n" >> logs/community_ledger.txt
```

If a public stock HEF is downloaded, record:

- model name;
- device architecture, must be `hailo8l`;
- source label;
- SHA256 checksum;
- intended later use: stock runtime smoke test only.

If DeGirum is used, record:

- account/access status;
- supported model family shown by the tool;
- whether YOLOv8 / YOLO11 is accepted;
- whether `yolo26n` is unsupported;
- output HEF filename, if any;
- statement that this is a fallback model-family experiment, not the custom
  `yolo26n` result.

## Block F - Route A Custom HEF Experiment, Only If DFC Runs

Start this block only if the official Docker container is running, or the
bare-metal DFC / Model Zoo fallback is installed and `hailomz` or the equivalent
compiler entrypoint runs on the workstation.

First inspect tool versions:

```bash
cd /home/ghostzero/datasets/uvautoboat_yolo_2026-06

echo "=== Hailo tools ==="
command -v hailomz || true
command -v hailo || true
hailomz --version 2>/dev/null || true
hailo --version 2>/dev/null || true
python3 --version

echo "=== Ultralytics ==="
python3 - <<'PY'
import ultralytics
print(ultralytics.__version__)
PY
```

Route A target:

```text
runs/baseline_yolo26n/weights/best.pt
  -> ONNX with the one-to-many / YOLOv8-style head if export supports it
  -> Hailo parse / optimize / quantize
  -> HEF with --hw-arch hailo8l
  -> parse-hef / architecture check
  -> emulation or evaluation if supported
```

Stop points:

- If export cannot produce a graph without unsupported `TopK` /
  `GatherElements` head ops, Route A is blocked.
- If end-node mapping is unclear, use Netron or compiler logs to identify the
  cut nodes; do not guess blindly.
- If compile succeeds but int8 mAP retention is bad, the HEF is not viable yet.
- If Route A blocks, record the failure and choose between Route B investigation
  or the YOLOv8 / YOLO11 fallback. Do not grind on repeated compile attempts
  without a new hypothesis.

Success definition:

- a HEF is produced for `hailo8l`;
- `parse-hef` or equivalent inspection confirms the architecture;
- tool versions and artifact paths are recorded;
- emulation/evaluation result is recorded if available;
- quality is compared against the FP32 / NCNN baseline before any Pi install.

## Block G - Wrap

Update this diary with:

- repo guard result and starting SHA;
- official artifact presence and exact evidence;
- whether the Docker suite loaded and which bundled versions it reports;
- downloaded filenames and SHA256 checksums, if any;
- workstation host suitability for DFC or Docker;
- dataset/checkpoint/calibration status;
- whether community / no-account bridge work was used;
- whether DeGirum was checked and what model families it supports;
- whether Route A compile was attempted, reached, blocked, or deferred;
- next gate before any Pi command.

End-state rules:

- The wiki pins are already confirmed. Update the wiki again only if tomorrow's
  actual Docker/tool versions differ from the recorded row.
- If the official Docker route fails, record fallback progress but keep the
  official DFC path as the custom `yolo26n` destination.
- No Pi runtime install until the artifact row and HEF path are understood.

Before any commit:

```bash
git status --short --branch
git diff --check
git diff --no-index --check /dev/null working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md
```

Before committing, grep the staged diff for secrets, generated artifacts,
external package paths, or local-only notes that should not be public. End with
bounded next steps and no stale completed action.

Suggested commit subject:

```text
docs(diary): record 02/07 Hailo Route A HEF
```
