# Tuesday 07/07/2026 - Hailo Six-Output Decode Contract (Workstation)

## Day Overview

This session opens the next Hailo gate after the closed 03/07/2026 runtime
bring-up and the 06/07/2026 cold-boot residual pass: proving the host-side decode
of the raw six-output `yolo26n_route_a_six_heads` artifact on saved frames, on the
workstation only.

The workstation has no Hailo PCIe device and no bare-metal Hailo tools in PATH, so
the only device-free source of the six output tensors is Dataflow Compiler
emulation inside the official suite Docker. That makes "prove the SDK is
accessible" the hard first gate, not an afterthought. No Pi command runs in this
session, and a blocked emulator does not fall forward to the Pi just to obtain
tensors.

## Success Definition

Success is one of:

1. the six-output decode is proven on a small pinned saved-frame set against a
   reference oracle within explicit tolerance, isolating decode-math correctness
   from int8 quantization error;
2. a precise decode or emulation blocker is documented with exact evidence
   (missing SDK access, tensor-export failure, layout/class-map mismatch); or
3. the session stops at the SDK-access gate with a clean, reproducible blocker and
   no Pi fall-forward.

Detector accuracy is explicitly **not** a success criterion here. The current HEF
is a mechanics-only artifact (28 mixed calibration frames, optimization level 0),
so this gate validates the decode contract, not detection quality.

## Starting Context

- Repo landed clean and pushed at `6143ab5` after the 06/07 residual pass.
- Workstation host `vrx-Precision-7560`: Ubuntu 24.04.4, kernel
  `6.17.0-35-generic`, x86_64, Python 3.12.3, RTX A3000 Laptop GPU, ~14Gi RAM +
  swap. Free `/home` was tight (~17-18G) after the 02/07 suite load; check before
  any large export.
- Suite image `hailo8_ai_sw_suite_2026-07:latest` (image ID `962aeda88f61`),
  DFC `3.34.0`, Model Zoo `2.19.0`, HailoRT `4.24.0`. The container reports
  `No Hailo PCIe device was found` on this host, which is expected and is exactly
  why emulation is the tensor source.
- Suite run dir: `/home/ghostzero/hailo_artifacts/2026-07-02/suite_run/`;
  container shared mount subtree:
  `.../suite_run/shared_with_docker/yolo26n_route_a/`. Container user is
  `hailo:ht` (`uid=10642`, `gid=10600`); host dirs need `chmod -R a+rwX` for
  container writes.
- Artifacts already exported under
  `.../shared_with_docker/yolo26n_route_a/exports/`:
  - ONNX `yolo26n_best_imgsz640_end2end_false_opset13.onnx` (input `images`
    `[1,3,640,640]`, output `output0` `[1,9,8400]`);
  - optimized (quantized) HAR
    `yolo26n_route_a_six_heads_optimized_calib28_no_nms.har`
    (state `Quantized Model`, hw `hailo8l`, SHA256 `1f81fbff...b47c38`);
  - compiled HAR `yolo26n_route_a_six_heads_compiled.har`;
  - HEF `yolo26n_route_a_six_heads.hef` (SHA256 `edc03c3c...b932d`).
- Existing preprocessed calibration input reusable as emulation input:
  `.../calib_npys/calib_raw_28_letterbox_640_uint8_nhwc.npy`, shape
  `(28, 640, 640, 3)`, dtype `uint8`, NHWC, from `calib_raw_28/` frames.
- Six-output contract from `parse-hef` (input `input_layer1` `UINT8`
  `NHWC(640x640x3)`), HN order `output_layer1..6`:

  | Layer | Role | Stride | Format | Shape |
  | --- | --- | --- | --- | --- |
  | `conv61` | box | 8 | NHWC | 80x80x4 |
  | `conv64` | class | 8 | FCR | 80x80x5 |
  | `conv77` | box | 16 | NHWC | 40x40x4 |
  | `conv80` | class | 16 | FCR | 40x40x5 |
  | `conv91` | box | 32 | FCR | 20x20x4 |
  | `conv94` | class | 32 | FCR | 20x20x5 |

- Decode facts already established on 02/07: box heads are **direct 4-channel**
  regression (anchor-free, stride handling), **not** 64-channel DFL; class heads
  are **raw logits** needing host-side sigmoid; output formats are **mixed**
  (`NHWC` and `FCR`) so layout conversion is required before decode. `8400` =
  `80^2 + 40^2 + 20^2`, and `9 = 4 box + 5 class`.
- Class map is five classes and the training `data.yaml` is the authority for
  order (recorded 02/07 as `0 buoy, 1 vessel, 2 dock, 3 obstacle, 4 person`);
  the auto-generated NMS JSON's `classes: 4` value is wrong for this checkpoint
  and must not be trusted.
- Source checkpoint for the oracle:
  `/home/ghostzero/datasets/uvautoboat_yolo_2026-06/runs/baseline_yolo26n/weights/best.pt`.

## Boundaries

- Workstation only. No Pi install, copy, or execution in this session.
- A blocked emulator / tensor export is a **stop**, not a reason to run the HEF on
  the Pi for tensors. Pi saved-frame inference is a separately approved later
  block.
- Markdown docs may be edited. Any decode / comparison script is scratch code that
  lives **outside** the public repo (under the artifact workspace), not a repo
  Python change.
- Keep HEFs, HARs, ONNX, tensors, frames, npys, and logs outside the public repo.
- Stay on the HailoRT 4.x / `hailo8` line; do not mix 5.x artifacts.
- No dashboard, MAVROS, MAVProxy, QGC, Herelink, real-FCU, mission upload, arming,
  mode change, parameter write, thruster, or actuator work.

## Block A - Repo Guard And Source Read

Run from the repo root:

```bash
cd /home/ghostzero/seal_ws/src/uvautoboat
git fetch --prune
git log --oneline -6
git status --short --branch
git rev-parse HEAD origin/main
```

Guard: if fetch fails, stop. If behind, `git pull --ff-only` then re-check. If
ahead, diverged, or dirty, stop and report before decode work.

Read first: this file;
`working_diary/2026-07-02_thursday_hailo_e2_offline_workstation.md`;
`wiki/Hailo_HAT_Workstream.md`; `Board.md`. Record the starting SHA.

## Block B - SDK / Emulator Access Hard Gate

Purpose: prove device-free emulation is actually reachable before promising any
tensor. This is the gate the whole session depends on.

- **Host + terminal:** workstation `vrx-Precision-7560`, user-run terminal; the
  suite run script starts a long-running interactive container, so launch it in
  its own terminal and run the checks inside the container shell.
- **cwd + env:** `cd /home/ghostzero/hailo_artifacts/2026-07-02/suite_run`; ensure
  the shell has Docker group access (`newgrp docker` or a fresh login), since
  `dialout`/`docker` group changes need a real re-login to take effect.

Host-side pre-check:

```bash
docker version
docker image inspect hailo8_ai_sw_suite_2026-07:latest >/dev/null || {
  echo "STOP: suite image missing"
  exit 1
}
docker image inspect --format '{{.Id}} {{.Size}}' hailo8_ai_sw_suite_2026-07:latest
df -h /home
```

If `docker` fails with a permission error, run `newgrp docker` or sign out/in
first; Docker group membership may not refresh just by opening a new terminal.

Start the container with the bundled script, then inside the container:

```bash
hailo --version      # expect HailoRT 4.24.0 + Dataflow Compiler 3.34.0
hailomz --version    # expect Hailo Model Zoo 2.19.0
python - <<'PY'
from hailo_sdk_client import ClientRunner
print("CLIENTRUNNER_IMPORT_OK")
PY
```

Gate - stop and report, do not fall forward to the Pi, if any of:

- Docker is not accessible from the shell, or the suite image is absent;
- `hailo` / `hailomz` versions are not `4.24.0` / `3.34.0` / `2.19.0`;
- `hailo_sdk_client.ClientRunner` does not import.

Confirm the exact emulation entrypoint for DFC `3.34.0` in-container (`hailo
tutorial` ships Jupyter notebooks; `ClientRunner` / `InferenceContext` help is the
source of truth) rather than assuming a signature from an older DFC.

## Block C - Artifact, Pinned-Frame, And Preprocess Contract

Purpose: pin the exact inputs and the two preprocessing variants before any
inference, because the Hailo path and the ONNX oracle path do **not** share a
preprocess.

Inside the container, confirm the artifacts and the six-output contract:

```bash
cd /home/ghostzero/hailo_artifacts/2026-07-02/suite_run/shared_with_docker/yolo26n_route_a
ls -lh exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har \
       exports/yolo26n_best_imgsz640_end2end_false_opset13.onnx \
       calib_npys/calib_raw_28_letterbox_640_uint8_nhwc.npy
hailo har info exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har
```

Pin a small saved-frame set (3-5 frames) from `calib_raw_28/`, preferring frames
where the oracle later returns at least one detection, plus one clear negative.
Record exact filenames and their row indices in
`calib_raw_28_letterbox_640_uint8_nhwc.npy` so the emulation input matches the
calibration preprocess byte-for-byte.

Two preprocess variants, same letterbox geometry, different tail - keep both and
record per-frame letterbox scale and pad so boxes can be mapped back to original
image coordinates:

- **Hailo path:** letterbox to 640, `uint8`, `NHWC`, RGB, values `0-255`. Do
  **not** divide by 255; the optimized HAR's `.alls` carries normalization. Reuse
  the pinned rows of the existing calibration npy.
- **ONNX oracle path:** letterbox to 640, `float32`, `NCHW`, RGB, normalized
  `/255` to match the ONNX `images [1,3,640,640]` input.

Gate: if the pinned frames cannot be traced to the calibration npy rows,
re-letterbox them and verify the arrays match before proceeding.

## Block D - Six-Output Tensor Export via Emulation

Purpose: produce the six raw output tensors for the pinned frames with no device,
at both full precision and quantized precision, so decode-math and quantization
error can be separated later.

Run inside the container. Full-precision output for Tier 1 must come from a
genuine float source, so first confirm which HAR/context provides it: check
whether the optimized (quantized) HAR supports `SDK_NATIVE`. If it does not, take
Tier 1 from the parsed pre-quantization HAR
`yolo26n_route_a_six_heads_no_nms.har`. Tier 2/3 always come from the optimized
HAR via `SDK_QUANTIZED`. Never source Tier 1 and Tier 2 from the same quantized
context - that compares quantized output against itself and voids the decode-math
check. Confirm the API against DFC `3.34.0` first (`hailo tutorial`); the shapes
below are the starting point, not a fixed signature:

```python
from hailo_sdk_client import ClientRunner, InferenceContext
import numpy as np

frames = np.load("calib_npys/pinned_subset_letterbox_640_uint8_nhwc.npy")  # (N,640,640,3) uint8 NHWC

# Tier 1 - full precision. Prefer the optimized HAR's native context; if
# SDK_NATIVE is unavailable there, use the parsed pre-quantization HAR below.
native_runner = ClientRunner(har="exports/yolo26n_route_a_six_heads_no_nms.har")
with native_runner.infer_context(InferenceContext.SDK_NATIVE) as ctx:
    native = native_runner.infer(ctx, frames)

# Tier 2/3 - quantized. Optimized HAR via SDK_QUANTIZED.
quant_runner = ClientRunner(har="exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har")
with quant_runner.infer_context(InferenceContext.SDK_QUANTIZED) as ctx:
    quant = quant_runner.infer(ctx, frames)
```

Record and save outside the repo (`.npz` under the artifact workspace):

- output tensor names and order, each shape and dtype;
- confirmation that shapes equal the `parse-hef` contract exactly
  (`conv61` `80x80x4`, `conv64` `80x80x5`, `conv77` `40x40x4`, `conv80`
  `40x40x5`, `conv91` `20x20x4`, `conv94` `20x20x5`);
- any dequantization scale / zero-point returned, and whether emulation returns
  dequantized float or raw integers;
- which HAR and context provided the Tier 1 full-precision reference versus the
  quantized outputs.

Gate: if the emulation does not return six outputs matching the contract, stop and
record the mismatch. Do not improvise a Pi run to get tensors.

## Block E - Oracle Reference

Purpose: build the independent ground truth on the same pinned frames.

Run in the host YOLO venv (not the container):

```bash
source /home/ghostzero/venvs/yolo-ws/bin/activate
```

- **Detection oracle:** `ultralytics` `YOLO(best.pt)` on the pinned frames at
  `imgsz=640`, fixed `conf` and `iou`, producing reference boxes / classes /
  scores in original-image coordinates. This is the end-to-end reference.
- **Tensor oracle:** `onnxruntime` on
  `yolo26n_best_imgsz640_end2end_false_opset13.onnx` with the float NCHW input,
  producing `output0 [1,9,8400]`. Note `output0` is already post-decode: box
  channels are decoded to pixel `xywh` and class channels are already sigmoid'd
  (producer `/model.23/Concat_3` from `Mul` + `Sigmoid`). This is the reference
  the host decode of the six raw conv outputs must reproduce.

Record the exact `ultralytics` version, `conf`/`iou`, and per-frame reference
detections and `output0` arrays.

## Block F - Host Decode And Three-Tier Tolerance Comparison

Purpose: implement the host decode once and validate it against the oracle in
three tiers that separate decode-math error from quantization error from
end-to-end detection error. Decode / comparison code is scratch, outside the repo.

Host decode steps (per scale 8 / 16 / 32): convert `FCR` class outputs and box
outputs to a common `HWC` layout; build the anchor-center grid for the scale;
apply direct 4-channel box regression with stride handling to pixel `xywh`; apply
sigmoid to the 5 class logits; flatten and concatenate the three scales to
`[8400, 4 + 5]` in the same anchor order as ONNX `output0`.

Tiers and explicit tolerances:

| Tier | Input | Compared against | Pass criterion |
| --- | --- | --- | --- |
| 1 decode math | `SDK_NATIVE` six outputs -> host decode | ONNX `output0` tensor | max relative error `< 1e-3` on box and class channels |
| 2 quantization | `SDK_QUANTIZED` six outputs -> host decode | ONNX `output0` tensor | report error percentiles; gate median box error `< 2 px` and median class-prob error `< 0.05` |
| 3 end to end | `SDK_QUANTIZED` -> host decode -> NMS -> un-letterbox | `ultralytics(best.pt)` detections | every reference detection with `conf >= 0.25` has a same-class match at IoU `>= 0.7` and score delta `<= 0.10`, with no gross unmatched high-score detection |

Additional checks:

- **Class-map alignment:** confirm channel index -> class name against the
  training `data.yaml`, not the auto-NMS JSON. A wrong map silently mislabels.
- **Box-form check:** if Tier 1 fails, the direct-distance assumption is the first
  suspect; inspect `output0` versus the decoded grid for a single anchor before
  changing the decode.

Gate: Tier 1 must pass before Tier 2/3 are meaningful. If Tier 1 fails, the decode
implementation is wrong and quantization/detection comparisons are not yet
informative.

## Block G - Wrap

Update this diary with: repo guard and starting SHA; SDK-access gate result and
in-container tool versions; pinned-frame set and both preprocess variants;
six-output emulation export result (shapes/dtypes/quant info); oracle versions and
reference detections; the three-tier comparison results with the exact tolerances
met or missed; class-map confirmation; and the exact blocker if stopped.

State plainly whether this remains decode-contract evidence only. It is not Pi
saved-frame inference, live RealSense, ROS image input, dashboard, MAVROS, QGC,
Herelink, command/write, or detector-quality evidence.

Before any commit:

```bash
git status --short --branch
git add -N working_diary/2026-07-07_tuesday_hailo_saved_frame_decode.md
git diff --check
git diff --no-index --check /dev/null working_diary/2026-07-07_tuesday_hailo_saved_frame_decode.md
rg -n "^(<{7}|={7}|>{7})" working_diary/2026-07-07_tuesday_hailo_saved_frame_decode.md
rg -n "\[[[:space:]]\]" working_diary/2026-07-07_tuesday_hailo_saved_frame_decode.md
```

Suggested commit subject:

```text
docs(diary): record Hailo decode contract blocker
```

## Session Evidence - 07/07/2026

Repo guard passed before artifact work:

- `git fetch --prune` completed.
- `main` matched `origin/main` at
  `2973e9a275c57752d5c0a473ce66cdbe5ef7242d`.
- `git status --short --branch` returned `## main...origin/main`.
- No pull was needed.

Block B passed after refreshing Docker group membership:

- The initial shell could run the Docker client but could not connect to the
  daemon because the process group list did not include `docker`.
- `newgrp docker` in the host shell changed the active group to `docker`.
- `docker version` then reported Docker Engine `29.6.1`.
- `hailo8_ai_sw_suite_2026-07:latest` was present with image ID prefix
  `962aeda88f61` and size `17173558507` bytes.
- `/home` had `18G` free at the start of the decode work.
- The old named suite container could not resume because its stale
  `/tmp/hailo_docker.xauth` bind no longer matched the expected file type. The
  container was not overridden or deleted; short-lived suite containers were used
  with the same image and shared artifact mount.
- In the suite container, `hailo --version` reported HailoRT `4.24.0` and
  Dataflow Compiler `3.34.0`; `hailomz --version` reported Model Zoo `2.19.0`.
- `hailo_sdk_client.ClientRunner` imported successfully.
- The container reported no Hailo PCIe device, expected for this workstation.

Block C artifact and input checks passed:

- Optimized HAR:
  `exports/yolo26n_route_a_six_heads_optimized_calib28_no_nms.har`, state
  `Quantized Model`, SDK `3.34.0`, hardware `hailo8l`.
- Parsed pre-quantization HAR:
  `exports/yolo26n_route_a_six_heads_no_nms.har`.
- ONNX oracle:
  `exports/yolo26n_best_imgsz640_end2end_false_opset13.onnx`.
- Source calibration npy:
  `calib_npys/calib_raw_28_letterbox_640_uint8_nhwc.npy`, shape
  `(28, 640, 640, 3)`, dtype `uint8`, min/max `0/255`.
- `hailortcli parse-hef exports/yolo26n_route_a_six_heads.hef` re-confirmed:
  input `UINT8 NHWC(640x640x3)` and outputs `conv61`, `conv64`, `conv77`,
  `conv80`, `conv91`, `conv94` with the expected `80/40/20` grid shapes.

Pinned saved-frame subset:

| Row | Filename |
| ---: | --- |
| 0 | `far_20260624_144508_0001.jpg` |
| 6 | `mid_20260624_144445_0001.jpg` |
| 12 | `near_20260624_142112_0001.jpg` |
| 18 | `neg_20260624_150606_0001.jpg` |
| 22 | `oblique_20260624_144553_0001.jpg` |

Selection note: `best.pt` returned zero detections on all 28 calibration frames at
`conf=0.25`, `iou=0.70`, so no positive reference frame existed at the fixed
oracle threshold. The subset covers far, mid, near, negative, and oblique saved
frames. Row order follows sorted `calib_raw_28/` filenames. Rebuilding the
letterbox from source JPEGs matched the source calibration npy within `max_abs=1`
for every selected row.

Preprocess artifacts stayed outside the public repo under
`/home/ghostzero/hailo_artifacts/2026-07-07/decode_contract/`:

- Hailo quantized input:
  `inputs/pinned_20260707_rows_00_06_12_18_22_uint8_nhwc.npy`,
  `(5, 640, 640, 3)`, `uint8`, values `0-255`.
- Full-precision native-HAR input:
  `inputs/pinned_20260707_rows_00_06_12_18_22_float32_nhwc_div255.npy`,
  `(5, 640, 640, 3)`, `float32`, values `0-1`.
- ONNX tensor-oracle input:
  `inputs/pinned_20260707_rows_00_06_12_18_22_exact_uint8_float32_nchw_div255.npy`,
  `(5, 3, 640, 640)`, `float32`, values `0-1`.
- Metadata:
  `inputs/pinned_20260707_rows_00_06_12_18_22_metadata.json`.

Block D tensor export:

- `ClientRunner.infer_context` in DFC `3.34.0` exposes `SDK_NATIVE`,
  `SDK_QUANTIZED`, `SDK_FP_OPTIMIZED`, `SDK_BIT_EXACT`, and `SDK_HAILO_HW`.
- `ClientRunner.infer(ctx, dataset, data_count, batch_size)` returned lists of
  six tensors in HN output order.
- `SDK_NATIVE` on the optimized HAR works, but the correct native input for this
  comparison is float NHWC `/255`; feeding uint8 into that native context
  produced a rejected diagnostic with class probabilities far from ONNX.
- The selected Tier 1 source is the full-precision native path:
  `tier1_prequant_sdk_native_float32_nhwc_div255.npz`. The optimized HAR native
  float diagnostic produced the same tensor ranges.
- Tier 2 source is:
  `tier2_optimized_sdk_quantized_uint8_nhwc.npz`.
- Both selected exports returned six `float32` tensors with exact expected
  shapes: `conv61 (5,80,80,4)`, `conv64 (5,80,80,5)`,
  `conv77 (5,40,40,4)`, `conv80 (5,40,40,5)`,
  `conv91 (5,20,20,4)`, and `conv94 (5,20,20,5)`.
- `ClientRunner.infer` returned tensors only; no dequantization scale or
  zero-point object was returned alongside the arrays.
- Export metadata:
  `logs/hailo_emulation_export_20260707.json` and
  `logs/hailo_prequant_native_export_20260707.json`.

Block E oracle:

- Host YOLO environment: Ultralytics `8.4.75`.
- Detection oracle: `best.pt`, `imgsz=640`, `conf=0.25`, `iou=0.70`; all 28
  calibration frames had `0` detections.
- Tensor oracle: `onnxruntime 1.27.0`, CPU provider, ONNX input `images`
  `[1,3,640,640]`, output `output0 [1,9,8400]`.
- Final tensor oracle used the exact pinned uint8 rows transposed to NCHW and
  divided by `255`, avoiding any re-letterbox approximation:
  `oracle/onnx_output0_pinned_20260707_rows_00_06_12_18_22_exact_uint8.npy`,
  shape `(5, 9, 8400)`, dtype `float32`.

Block F decode and comparison:

- Decode form confirmed: direct `l,t,r,b` distances from grid-center anchors
  `(x + 0.5, y + 0.5)`, multiplied by stride and converted to pixel `xywh`.
- Class form confirmed: sigmoid over the five class logits.
- Scale order confirmed: stride `8` then `16` then `32`.
- The DFC emulation API returned logical NHWC-shaped arrays for all six outputs;
  no extra FCR memory reordering was needed before flattening.
- Class map confirmed from `data.yaml`: `0 buoy`, `1 vessel`, `2 dock`,
  `3 obstacle`, `4 person`.

Tier results:

| Tier | Result | Key evidence |
| --- | --- | --- |
| 1 decode math | FAIL | Box max relative error `0.025359` > `<1e-3`; box max abs `3.7708 px`, median abs `0.01257 px`, p99 abs `0.24448 px`. Class max relative error `0.000912` passed `<1e-3`. |
| 2 quantization | Not gated | Tier 1 failed first. Diagnostic only: median box-channel abs `4.0665 px` and median class-prob abs `1.61e-6`. |
| 3 end to end | Not gated | Tier 1 failed, and the detection oracle had zero positive detections at `conf=0.25`; quantized decode had zero candidates above `0.25`, max class probability `0.002682`. |

Comparison metadata and decoded tensor artifacts:

- `logs/decode_compare_20260707.json`.
- `outputs/decoded_tier1_prequant_sdk_native_float32_nhwc_div255_output0_like.npy`.
- `outputs/decoded_tier2_optimized_sdk_quantized_uint8_nhwc_output0_like.npy`.

Blocker:

The host decode order and formula are identified, and class channels match the
ONNX tensor oracle tightly, but Tier 1 misses the strict box max-relative
tolerance. Per the gate, Tier 2 and Tier 3 are diagnostic only until this
full-precision box residual is explained or a revised tolerance is explicitly
accepted. The session stopped on the workstation with no Pi fall-forward.

This remains decode-contract evidence only. It is not Pi saved-frame inference,
live RealSense, ROS image input, dashboard, MAVROS, QGC, Herelink,
command/write, detector-quality, mission-upload, arming, mode-change,
parameter-write, thruster, or actuator evidence.
