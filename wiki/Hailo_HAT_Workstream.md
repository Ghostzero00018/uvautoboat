# Hailo HAT Workstream Memo

This memo is the planning home for the Hailo accelerator branch: the durable
version constraints, OS / runtime gate, artifact pin sheet, and bring-up order.
Day-by-day evidence lives in the dated `working_diary/` entries; keep this memo
for reusable architecture facts, not single-day observations.

## Decision Summary

- The Raspberry Pi AI HAT+ 13 TOPS board is a Hailo-8L INT8 accelerator for
  Raspberry Pi 5. Its relevant project use is object detection on Pi-side camera
  frames.
- RealSense compatibility is not the primary risk. The Hailo runtime consumes
  frames from the host; the RealSense RGB stream can enter through a USB video
  node, a GStreamer path, or the existing ROS 2 image topic
  `/camera/camera/color/image_raw`.
- The primary integration risk is the software stack split: the boat currently
  uses Ubuntu 24.04 with ROS 2 Jazzy, while Raspberry Pi's simple Hailo install
  path targets Raspberry Pi OS Trixie and `hailo-all`.
- Keep ROS 2 Jazzy as the boat spine unless the whole Phase 5 architecture is
  deliberately revisited. Treat Hailo on Ubuntu as a version-pinned,
  self-supported accelerator branch.
- The runtime line is fixed by the hardware, not by "newest": the Hailo-8L is
  served only by the HailoRT 4.x line (the `hailo8` branch). The 5.x line
  (`master`) supports Hailo-10 and Hailo-15 only, so any 5.x driver, runtime,
  Dataflow Compiler, or Model Zoo artifact is the wrong hardware line for this
  board. See the E2 Artifact Pin Sheet.
- Path decision: the official Hailo Dataflow Compiler is the destination for the
  custom `yolo26n` maritime detector because it gives the export, calibration,
  model-script, and post-processing control that int8 accuracy depends on.
  Community / no-account routes remain useful fallbacks: source-build +
  firmware + prebuilt HEFs for runtime and stock smoke, and DeGirum for a fast
  YOLOv8 / YOLO11 HEF if that head is acceptable. Runtime-only work is a
  convenience question, not a quality question. See "No-account routes."
- Live state (01/07/2026): a read-only Pi probe confirmed Ubuntu 24.04.4 /
  kernel `6.8.0-1057-raspi` / Python 3.12.3, HAT healthy on PCIe (`1e60:2864`,
  gen-3 x1) but no Hailo driver/runtime and no `hailo-all` candidate. The
  Raspberry Pi package path is closed for this image; the Ubuntu manual path is
  the branch. Evidence: `working_diary/2026-07-01_wednesday_hailo_hat_bringup.md`.
- Do not reuse the current NCNN export for Hailo. Hailo deployment needs a HEF
  artifact compiled from an ONNX/TFLite-style path with Hailo tooling.

## Current Project Context

The current custom YOLO path is:

```text
RealSense RGB -> ROS 2 image topic -> custom NCNN inference on Pi CPU
```

That path is mechanically proven for short runs, but sustained `imgsz=640` CPU
inference failed the thermal gate on 26/06/2026. The 29/06/2026 workstation run
created a separate `imgsz=320` NCNN export as the next CPU-side thermal lever,
but that export is still gated behind a clean MAVProxy / MAVROS telemetry pass.

Hailo is the active accelerator branch from 01/07/2026 onward. It is being
evaluated as a way to move inference off the Pi CPU, not as a replacement for
the telemetry gate.

## Compatibility Notes

The Raspberry Pi camera demos are convenience paths, not the hardware boundary.
Raspberry Pi documents `rpicam-apps` and Picamera2 integration for supported
vision tasks, but Hailo also provides runtime and application paths that process
other frame sources. Hailo's Raspberry Pi examples include USB camera input and
direct `/dev/video<X>` selection; the newer Hailo Apps repository describes
real-time camera, RTSP, and video-processing pipelines.

For this boat, prefer the ROS-native integration shape:

```text
/camera/camera/color/image_raw
  -> cv_bridge / numpy frame
  -> HailoRT inference with a compiled HEF
  -> vision_msgs/Detection2DArray
```

This keeps the RealSense driver, ROS_DOMAIN_ID discipline, and later dashboard
integration aligned with the existing system.

## Version And OS Gate

Raspberry Pi's official Hailo software guide for AI HAT+ installs:

```bash
sudo apt install dkms
sudo apt install hailo-all
```

That guide assumes Raspberry Pi OS Trixie. The boat Pi uses Ubuntu 24.04 and ROS
2 Jazzy, so the first real gate is not RealSense. It is whether the Hailo PCIe
driver, HailoRT runtime, Python binding, and compiled HEF can be kept on one
compatible 4.x version line on Ubuntu.

Rules for the first Ubuntu attempt:

- Check whether a `hailo_pci` module is already present before adding a DKMS
  driver.
- Pin the Hailo driver, HailoRT runtime, Python binding, and HEF toolchain
  version together.
- Keep this 13 TOPS Hailo-8L board on the HailoRT 4.x line (`hailo8` branch);
  the 5.x `master` line is Hailo-10 / Hailo-15 only. This is a hardware
  constraint, not a preference. See the E2 Artifact Pin Sheet.
- Do not mix the AI HAT+ 2 package path with this board. Raspberry Pi documents
  `hailo-all` for AI HAT+ and a separate `hailo-h10-all` path for AI HAT+ 2.
- Check Python compatibility explicitly because ROS 2 Jazzy on Ubuntu 24.04 uses
  Python 3.12.

## E2 Artifact Pin Sheet

All version numbers below are **confirmed from the Hailo download portal on
01/07/2026**. Hailo ships roughly monthly, so treat this as the pinned row for
this bring-up, not a timeless "newest" claim. The binding rule is the version
LOCK: adopt one coherent release row wholesale rather than mixing components.

Line rule (durable): the Hailo-8L uses the HailoRT 4.x line (`hailo8` branch).
The 5.x line (`master`) is Hailo-10 / Hailo-15 only — never pin a 5.x artifact
for this board. Stated verbatim in the `hailort` README.

Provenance of the pins: the public `hailort` and Model Zoo READMEs confirm the
LINE rules above (Hailo-8L uses HailoRT 4.x / `hailo8` branch + Model Zoo 2.x +
Dataflow Compiler 3.x; 5.x / `master` is Hailo-10 / 15), and the `hailort`
releases page confirms 4.24.0 as the newest public 4.x release. The concrete
downloaded filenames below confirm the login-gated compile-side patch numbers:
Model Zoo 2.19.0 and DFC 3.34.0. The public 2.x changelog still does not expose
that full row, so the downloaded portal artifacts are the evidence for those
patch numbers.

### Pi runtime stack (aarch64, hand-assembled — no `hailo-all` on Ubuntu)

Pin all four to the SAME 4.x version, or the runtime refuses to start
(`Driver version (X) is different from library version (Y)`,
`HAILO_UNSUPPORTED_FW_VERSION`):

| Component | Confirmed artifact (01/07/2026) | Source | Note |
| --- | --- | --- | --- |
| PCIe driver `hailo_pci` | `hailort-pcie-driver_4.24.0_all.deb` | Developer Zone | DKMS driver package; install after matching `linux-headers-$(uname -r)` and `build-essential`. Driver floor for the Pi `6.8-raspi` kernel remains >= 4.19. |
| HailoRT runtime | `hailort_4.24.0_arm64.deb` | Developer Zone | provides `hailortcli` on the Pi |
| Python binding `pyhailort` wheel | `hailort-4.24.0-cp312-cp312-linux_aarch64.whl` | Developer Zone | cp312 exists for the Pi's Ubuntu 24.04 Python 3.12, so no Python 3.11 venv is needed for this pinned row. Keep the venv/source-build route only as a fallback if the row changes later. |
| Firmware `hailo8_fw.<ver>.bin` | bundled with the 4.24.0 driver/runtime packages | Developer Zone packages | verify `/lib/firmware/hailo/hailo8_fw.bin` after Pi install; fetch a standalone firmware file only if the package install does not provide it |

### x86_64 compile toolchain (the Pi never compiles)

Pin all three to the SAME Model Zoo release row; a HEF is locked to both the
runtime line and the device arch:

| Component | Confirmed artifact (01/07/2026) | Note |
| --- | --- | --- |
| Hailo AI Software Suite Docker | `hailo8_ai_sw_suite_2026-07_docker.zip` | Recommended first compile route. Archive integrity passed; it contains `hailo8_ai_sw_suite_2026-07.tar.gz` and `hailo_ai_sw_suite_docker_run.sh`. Verify bundled versions inside the container before compiling. |
| Hailo Dataflow Compiler | `hailo_dataflow_compiler-3.34.0-py3-none-linux_x86_64.whl` | Bare-metal fallback to Docker. x86_64 Ubuntu 20.04 / 22.04, Python 3.10-3.12, 16+ GB RAM (32 GB recommended), AVX CPU, optional NVIDIA GPU (CUDA 11.8 / cuDNN 8.9) for faster optimization. Never DFC 5.x (Hailo-10 / 15). |
| Hailo Model Zoo | `hailo_model_zoo-2.19.0-py3-none-any.whl` | Bare-metal fallback to Docker; `hailomz` CLI wraps parse / optimize / compile |
| HailoRT (x86) | `hailort_4.24.0_amd64.deb` | HEF validation; keeps the line matched |
| Python binding `pyhailort` wheel (x86) | `hailort-4.24.0-cp312-cp312-linux_x86_64.whl` | Optional workstation Python API tests; not required for HEF compilation |
| Compile target arch | `--hw-arch hailo8l` | a `hailo8` (26 TOPS) HEF will not load on this 13 TOPS board |

Use the Docker suite for the first `yolo26n.pt` compile because it bundles a
mutually compatible Dataflow Compiler + HailoRT + Model Zoo + TAPPAS row and
avoids bare-metal TensorFlow/CUDA dependency friction. Keep the bare-metal
wheels and `.deb` files as the fallback/scriptable route. Do not mix commands
between the Docker row and a different bare-metal row without first verifying
the versions match.

Checksums already captured for the two last-added workstation artifacts:

```text
5e9a21f56217b131e49afdcacaebf3e200fd03a4d205d61bcb07ceda9c4542f6  hailo8_ai_sw_suite_2026-07_docker.zip
7818ee8fe70a7f8a90f2485aaf488d0572fe2078d16728ae0716a42905e3d573  hailort-4.24.0-cp312-cp312-linux_x86_64.whl
```

### Ubuntu 24.04 footguns

- No `hailo-all` and no Raspberry Pi apt source on this image. Do not apt-pin
  `archive.raspberrypi.com` onto Ubuntu: those packages target Debian Trixie
  (newer glibc / Python 3.13) and ABI-mismatch Ubuntu Noble.
- Python 3.12 was the main wheel trap, but the pinned row includes both
  `cp312-cp312-linux_aarch64` and `cp312-cp312-linux_x86_64` pyHailoRT wheels.
  A Python 3.11 venv is only a fallback if a later row drops cp312 support.
- The PCIe driver loads out-of-tree on the `6.8-raspi` kernel (no in-tree
  `hailo_pci`, no blacklist needed). Read driver logs with `sudo dmesg` because
  Ubuntu sets `kernel.dmesg_restrict=1`.
- Secure Boot / MOK signing is an x86-host concern only; the Pi 5 boots its own
  bootloader with no UEFI Secure Boot.

### No-account routes

Scope: this is a fallback record from the pre-download stage. Developer Zone
access is no longer the blocker for the 4.24.0 / 3.34.0 / 2.19.0 row above, so
the official artifacts are now the primary path. The routes below remain useful
only if a future download row is unavailable, a package is missing, or a fast
stock smoke test is needed. Everything called "public" below can be fetched
without Hailo Developer Zone access; verify the exact URL and version before
use.

Public / account-free (enough to build the runtime and run a stock smoke test):

- PCIe driver source (`hailort-drivers`, GitHub) — build from source.
- Device firmware (`hailo8_fw.bin`) — public S3, no login.
- HailoRT + `pyhailort` via the source-build path (`hailort` GitHub, `hailo8`
  branch); the account only buys the convenience `.deb` / wheel, not the code.
- Prebuilt `hailo8l` HEFs (e.g. yolov8n / yolo11n) from the public Model Zoo S3 —
  enough to prove the runtime / inference path before a custom model.

Still gated without Hailo account access:

- The Dataflow Compiler, for compiling the custom `yolo26n.pt` -> `hailo8l` HEF.
  No public GitHub, not on PyPI; Developer-Zone-only (free, but registration-gated).
- The convenience version-matched Developer Zone packages (HailoRT `.deb`, cp312
  `pyhailort` wheel, matching firmware) — otherwise obtainable only by building
  from source.

DeGirum path (third-party):

- A legitimate fallback that compiles a custom model to a `hailo8l` HEF in the
  cloud (runs the Hailo Dataflow Compiler server-side) — but currently for
  YOLOv8 / YOLO11, not the current `yolo26n` path.
- Early-access, external service, separate DeGirum account; may change or become
  paid.
- Does not replace the Hailo 4.x runtime requirement on the Pi — HailoRT +
  driver + firmware must still be installed for any HEF to run.

The Ubuntu-24.04 caveat from the pin sheet still applies: the easy public
`hailo-all` apt route is Raspberry Pi OS (Bookworm / Python 3.11) only, so on
this Ubuntu 24.04 image the account-free runtime means building from source.

## Workstation-First Risk Retirement

The make-or-break model risk can be tested before touching the Pi hardware. Do
this on the x86_64 Linux workstation:

```text
best.pt -> ONNX -> Hailo parse / optimize / quantize -> hailo8l HEF
```

Use the campus workstation for this because Hailo DFC export is an x86_64 Linux
toolchain; Raspberry Pi is the deployment target, not the compile host.

Important constraints:

- Current Ultralytics docs state Hailo HEF is not a direct
  `model.export(format="hailo")` target.
- Ultralytics documents the HEF flow as `pt -> ONNX -> HAR -> quantized HAR ->
  HEF`.
- Hailo compilation uses a fixed input shape; preprocessing, letterboxing, model
  script, NMS config, and `imgsz` must match.
- Use deployment-domain calibration images. Start with at least 64, but target a
  much larger maritime calibration set before treating accuracy as meaningful.
- Model-family support (as of 01/07/2026, re-check before effort): a public
  working `yolo26n` -> Hailo-8L pipeline exists (`DanielDubinsky/yolo26_hailo`),
  and Ultralytics documents YOLO26 as Hailo-compilable. Whether the Model Zoo
  2.x branch ships a turnkey `yolo26` config is a login-gated claim, unconfirmed
  from public sources — but the routes below do not need one. The real catch is
  the default NMS-free one-to-one head, whose `TopK` / `GatherElements` ops are
  unsupported on the Hailo-8L NPU, so the stock YOLOv8 / YOLO11 NMS example does
  not transfer unchanged.

For `yolo26n.pt`, three routes, easiest first:

1. Route A (try first): export with `end2end=False` to get the one-to-many
   (YOLOv8-style) head, then compile with the documented `meta_arch=yolov8`
   end-nodes and host-CPU NMS. This sidesteps the unsupported ops entirely.
2. Route B (native NMS-free): cut the ONNX before the head and decode host-side;
   a working Hailo-8L reference is `DanielDubinsky/yolo26_hailo` (read its
   `requirements.txt` for exact pins).
3. Fallback: retrain or convert to `YOLOv8n` / `YOLO11n`, the fully turnkey
   Model Zoo detection families.

Measure int8 mAP retention against the FP32 / NCNN baseline before any Pi driver
work — that quantization result, not the driver install, is the make-or-break.

## Pi Bring-Up Order

Run this when the professor or bench time is available and the offline E2
artifact path has been prepared.

1. Mount hardware and keep the Raspberry Pi Active Cooler fitted.
2. Resolve the PCIe lane decision: AI HAT+ versus NVMe storage on the Pi 5's
   external PCIe path.
3. Confirm power budget with a 5 V / 5 A USB-C power path. Raspberry Pi
   documents reduced peripheral current when Pi 5 is not on a 5 A supply.
4. Install one version-pinned Hailo driver/runtime stack.
5. Verify hardware only:

   ```bash
   lspci | grep -i hailo
   ls -l /dev/hailo*
   hailortcli fw-control identify
   dmesg | grep -i hailo | tail -50
   ```

6. Run a known-good `hailo8l` HEF before any decode work. Preferred: a stock
   `hailo8l` HEF such as `resnet_v1_18` or a public Model Zoo detector compiled
   with `--hw-arch hailo8l`. Current offline caveat: the software-suite bundled
   HEFs inspected on 02/07/2026 were `hailo8`, not `hailo8l`, and must not be
   used as AI HAT+ 13 TOPS / Hailo-8L smoke tests. If no stock `hailo8l` HEF is
   staged, use the compiled project HEF only as a runtime smoke test, not as a
   decode or accuracy proof.
7. For the current project HEF, first prove static HailoRT execution with
   `yolo26n_route_a_six_heads.hef`; it is raw six-output and requires host-side
   decode / NMS.
8. Feed saved RealSense RGB frames into HailoRT.
9. Only then wire live ROS 2 image input and publish detection messages.

## Non-Goals For The Memo Stage

- No Pi package install.
- No change to the active MAVProxy / MAVROS diary.
- No copy of the 320 NCNN export to the Pi.
- No RealSense + Hailo + MAVROS combined-load test.
- No dashboard integration or real-FCU command/write path.

## Source Anchors

- Raspberry Pi AI HATs documentation:
  <https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html>
- Raspberry Pi Hailo software documentation:
  <https://www.raspberrypi.com/documentation/computers/ai.html>
- Raspberry Pi power and thermal documentation:
  <https://www.raspberrypi.com/documentation/computers/raspberry-pi.html>
- Hailo Apps repository:
  <https://github.com/hailo-ai/hailo-apps>
- Ultralytics Hailo integration notes:
  <https://docs.ultralytics.com/integrations/hailo/>
- RealSense ROS wrapper:
  <https://github.com/realsenseai/realsense-ros>

## Navigation

- [Home](Home)
- [YOLO Dataset Plan](YOLO_Dataset_Plan)
- [Roadmap](Roadmap)
