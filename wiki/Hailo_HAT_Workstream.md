# Hailo HAT Workstream Memo

This memo parks the future Hailo accelerator branch separately from the active
MAVProxy / MAVROS telemetry gate. Do not mix Hailo work into the telemetry diary
or use it to widen a MAVProxy heartbeat session.

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

Hailo is a separate future accelerator branch. It should be evaluated as a way
to move inference off the Pi CPU, not as a replacement for the telemetry gate.

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
- Keep this 13 TOPS Hailo-8L board on the HailoRT 4.x vision stack unless a
  future vendor note explicitly says otherwise.
- Do not mix the AI HAT+ 2 package path with this board. Raspberry Pi documents
  `hailo-all` for AI HAT+ and a separate `hailo-h10-all` path for AI HAT+ 2.
- Check Python compatibility explicitly because ROS 2 Jazzy on Ubuntu 24.04 uses
  Python 3.12.

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
- Re-check model-family support before spending effort. Current Ultralytics
  Hailo guidance lists YOLOv8, YOLO11, and YOLO26, but the documented example
  path uses a traditional NMS post-processing flow. YOLO26 is NMS-free, so it
  needs a dedicated post-processing path rather than a direct copy of the YOLO11
  example.

If the current custom checkpoint stays on `yolo26n.pt`, the first Hailo test
should be treated as a compatibility experiment, not a planned deployment. A
traditional detection-head family may be needed for the accelerator branch.

## Pi Bring-Up Order

Run this only after the telemetry gate is no longer active and the professor or
bench time is available.

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

6. Run a stock Hailo detection HEF before using the project model.
7. Feed saved RealSense RGB frames into HailoRT.
8. Only then wire live ROS 2 image input and publish detection messages.

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
