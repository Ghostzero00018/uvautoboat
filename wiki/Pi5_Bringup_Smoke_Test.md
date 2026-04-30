# Pi 5 ↔ Flight Controller Bring-up — Smoke-Test Procedure

> **Status:** bring-up scaffolding only. This procedure confirms the physical Pi 5 ↔ flight-controller serial link works and that one IMU stream is decoded. **It is not the production telemetry path** — production uses `mavros2` (the ROS 2 port of MAVROS), per [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026).
>
> **Owner:** intern bring-up notes. Captured 30/04/2026 from procedural commands shared by the team for first-light verification when the Pi 5 lands at the bench.

---

## 1. What this is — and what it is not

This page documents the first-light bring-up sequence: get a heartbeat between the Pi 5 (companion computer) and the flight controller over the GPIO UART, then confirm at least one IMU message decodes correctly.

**It is** a manual smoke test using `MAVProxy` (interactive) plus a small `pymavlink` Python script (`stream_data.py`).

**It is not:**

- the production telemetry path — that is `mavros2`, which translates MAVLink frames into ROS 2 topics (`/mavros/imu/data`, `/mavros/global_position/global`, …) for the Linux workstation to consume over DDS. See [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026).
- a robust integration test — no error handling, no recovery from disconnect, no logging.
- usable while `mavros2` (or any other MAVLink consumer) is running on the same Pi — the GPIO serial port is exclusive. Only one consumer at a time on `/dev/serial0` unless you fan out via UDP (see §4).

**MAVProxy vs MAVROS clarification.** These are *different* tools that are easy to confuse:

| Tool | Role | Used here |
|:-----|:-----|:----------|
| **MAVROS** (`mavros2`) | MAVLink ↔ ROS topics bridge | Production. Not part of this smoke-test procedure. |
| **MAVProxy** | MAVLink router/multiplexer + interactive terminal | Smoke test (interactive heartbeat check; can also fan out to UDP for parallel consumers). |

MAVProxy does **not** translate MAVLink to ROS. Once the smoke test passes, swap to `mavros2` for the actual integration.

---

## 2. Prerequisites

- Pi 5 running **Ubuntu 24.04 LTS server** (headless), connected to the *IoT IMT Nord Europe* network
- Flight controller wired to Pi 5 GPIO UART (TX → RX, RX → TX, GND; do not feed FC power from Pi unless your wiring guide explicitly says so)
- SSH reachable from the workstation
- User in the `dialout` group: `sudo usermod -a -G dialout $USER` then **log out and back in** for it to take effect (group membership refreshes only on new sessions)
- UART enabled on the Pi 5:
  - `sudo raspi-config` → Interface Options → Serial Port → "Login shell over serial: NO" + "Serial port hardware: YES"
  - Confirm `enable_uart=1` in `/boot/firmware/config.txt`. **Note:** Ubuntu on Pi 5 uses `/boot/firmware/config.txt`, *not* `/boot/config.txt` like older Raspberry Pi OS images.
  - Reboot.

---

## 3. Procedure

### 3.1 Enable SSH on the Pi 5 (one-time)

On the Pi:

```bash
sudo systemctl enable --now ssh
```

From the workstation:

```bash
ssh <user>@<pi-ip>
# example: ssh bot@192.168.43.75
```

### 3.2 Install MAVProxy on the Pi 5

System packages first:

```bash
sudo apt update
sudo apt-get install python3-dev python3-opencv python3-wxgtk4.0 \
    python3-pip python3-matplotlib python3-lxml python3-pygame
```

Then MAVProxy. **Caveat:** Ubuntu 24.04 ships Python 3.12 with PEP 668 ("externally-managed environment"), so `pip install` outside a virtual environment typically fails — even with `--user`. The recommended approach is `pipx`:

```bash
sudo apt install pipx
pipx install mavproxy
pipx inject mavproxy pymavlink PyYAML
pipx ensurepath
```

Open a new shell so the PATH update takes effect, then verify:

```bash
which mavproxy.py   # expect ~/.local/bin/mavproxy.py
```

> **Alternatives if `pipx` is not preferred:** `pip install ... --break-system-packages` (less clean), or create a virtual environment and install MAVProxy there. Plain `pip install --user` does not bypass PEP 668 on Ubuntu 24.04.

Reference: <https://ardupilot.org/mavproxy/index.html>

### 3.3 Verify the heartbeat

```bash
mavproxy.py --master=/dev/serial0 --baudrate=115200
```

The baud rate **must match** the flight controller's `SERIALn_BAUD` parameter (typical ArduPilot default for telemetry on a wired serial: 115200; SiK telemetry radios default to 57600; check the FC's parameter list).

Expected output: `Online system 1`, then a stream of MAVLink messages. `Ctrl-]` exits cleanly.

If no heartbeat appears:

- Wrong baud — try 57600.
- TX/RX swapped — uncommon but possible if the wiring diagram was ambiguous.
- UART not enabled — re-check the prerequisites in §2.
- User not in `dialout` group — `groups` to verify; logout/login if missing.

### 3.4 Stream IMU data via the smoke-test script

The `stream_data.py` script (see §5 below) opens its own MAVLink connection to `/dev/serial0`, requests IMU data, and prints incoming messages.

**MAVProxy must NOT be running at the same time** — only one consumer can hold `/dev/serial0`.

```bash
python3 stream_data.py
```

To run MAVProxy and the smoke-test script in parallel, route through UDP — this is exactly MAVProxy's "router" role:

```bash
# Terminal 1 — MAVProxy as router:
mavproxy.py --master=/dev/serial0 --baudrate=115200 --out=udp:127.0.0.1:14550

# Terminal 2 — smoke-test script reading from UDP instead of the serial port.
# Change the script's mavlink_connection() line to:
#   connection = mavutil.mavlink_connection('udpin:127.0.0.1:14550')
python3 stream_data.py
```

---

## 4. Suggested bring-up order

Run these in sequence; do **not** skip steps. Each one verifies a layer before the next layer is exercised.

1. SSH + UART/dialout setup → `mavproxy.py --master=/dev/serial0 --baudrate=115200`. Confirm "Heartbeat" line appears.
2. Stop MAVProxy. Run `stream_data.py` directly (with the rate-request fix from §6) and confirm IMU messages arrive at the requested rate.
3. Re-launch MAVProxy with `--out=udp:127.0.0.1:14550`. Modify `stream_data.py` to read from `udpin:127.0.0.1:14550`. Confirm parallel access works.
4. **Then** install `mavros2` on the Pi 5; verify `ros2 topic list` shows `/mavros/*` topics; confirm the Linux workstation sees them over DDS (basic `talker` / `listener` round-trip first to verify multicast on the IoT WiFi — see [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026)).
5. **Only then** start wiring into the simulator. `launch/remap.launch.yaml` is the home for sim-vs-real swap-in routing — see [Roadmap §3](Roadmap#3-phase-5--real-hardware-deployment).

Steps 1–3 prove the physical link; step 4 proves the ROS bridge; step 5 is integration. Skipping ahead means debugging multiple layers at once when something breaks.

---

## 5. Original `stream_data.py` (as received 30/04/2026)

This is the script as initially shared by the team. Known issues are catalogued in §6; suggested fixes are in §7. The original is preserved here for traceability — apply fixes as a separate change.

```python
from pymavlink import mavutil
import time

# Establish a MAVLink connection to the OrangeCube
# Replace '/dev/serial0' with the appropriate serial port
connection = mavutil.mavlink_connection('/dev/serial0', baud=115200)

# Wait for the heartbeat message to confirm the connection
print("Waiting for heartbeat...")
connection.wait_heartbeat()
print("Heartbeat received! Connection established.")

# Function to request IMU data
def request_imu_data():
    # Request RAW_IMU data (ID 27)
    connection.mav.request_data_stream_send(
        connection.target_system,  # Target system ID
        connection.target_component,  # Target component ID
        mavutil.mavlink.MAV_DATA_STREAM_EXTRA1,  # Stream ID for RAW_IMU
        1,  # Request rate in Hz
        1   # Start/stop (1 to start, 0 to stop)
    )

# Function to parse and display IMU data
def parse_imu_data(msg):
    if msg.get_type() == 'RAW_IMU':
        print("\n--- IMU Data ---")
        print(f"Accelerometer (X, Y, Z): {msg.xacc}, {msg.yacc}, {msg.zacc}")
        print(f"Gyroscope (X, Y, Z): {msg.xgyro}, {msg.ygyro}, {msg.zgyro}")
        print(f"Magnetometer (X, Y, Z): {msg.xmag}, {msg.ymag}, {msg.zmag}")
    elif msg.get_type() == 'SCALED_IMU2':  # If using SCALED_IMU2 for additional IMU data
        print("\n--- IMU2 Data ---")
        print(f"Accelerometer (X, Y, Z): {msg.xacc}, {msg.yacc}, {msg.zacc}")
        print(f"Gyroscope (X, Y, Z): {msg.xgyro}, {msg.ygyro}, {msg.zgyro}")
        print(f"Magnetometer (X, Y, Z): {msg.xmag}, {msg.ymag}, {msg.zmag}")
    elif msg.get_type() == 'SCALED_IMU3':  # If using SCALED_IMU3 for additional IMU data
        print("\n--- IMU3 Data ---")
        print(f"Accelerometer (X, Y, Z): {msg.xacc}, {msg.yacc}, {msg.zacc}")
        print(f"Gyroscope (X, Y, Z): {msg.xgyro}, {msg.ygyro}, {msg.zgyro}")
        print(f"Magnetometer (X, Y, Z): {msg.xmag}, {msg.ymag}, {msg.zmag}")


# Main loop to continuously read IMU data
try:
    request_imu_data()
    while True:
        # Wait for a MAVLink message
        msg = connection.recv_match(type=['RAW_IMU', 'SCALED_IMU2', 'SCALED_IMU3'], blocking=True)
        if msg:
            parse_imu_data(msg)
        time.sleep(0.1)  # Adjust the sleep time as needed
except KeyboardInterrupt:
    print("Exiting...")
```

---

## 6. Known issues in the original script

| # | Severity | Issue |
|:-:|:---------|:------|
| 1 | **Real bug** | `request_data_stream_send(..., MAV_DATA_STREAM_EXTRA1, 1, 1)` — the third arg is rate in Hz. **1 Hz is too slow for IMU** (autopilots sample 50–200 Hz). The `MAV_DATA_STREAM_*` API is also **legacy/deprecated** — modern MAVLink uses `MAV_CMD_SET_MESSAGE_INTERVAL` per message. Worse: on ArduPilot the `EXTRA1` stream typically carries `ATTITUDE`, not `RAW_IMU` — the stream-to-message mapping varies by autopilot, so requesting EXTRA1 may not actually start IMU streaming at all. |
| 2 | Real bug | `time.sleep(0.1)` after `connection.recv_match(blocking=True)` is dead weight — `blocking=True` already waits. Just adds latency between consecutive messages. |
| 3 | Robustness | `connection.wait_heartbeat()` blocks **forever** with no timeout if no heartbeat arrives (wrong baud, wrong port, autopilot off, FC unpowered). |
| 4 | Robustness | No try/except around `mavlink_connection(...)` — missing or permission-denied `/dev/serial0` raises raw `serial.serialutil.SerialException` instead of a clean error message. |
| 5 | Hardcoding | Port and baud are hardcoded. Not reusable on a different setup without editing the file. |
| 6 | Units (subtle) | `RAW_IMU` accel is in raw sensor counts (sensor-dependent); `SCALED_IMU2/3` accel is in **mG** (already scaled). Print format is identical, so values look comparable across the three but aren't. |
| 7 | DRY | Three `parse_imu_data` branches are 90% identical — could be a helper function. Not a bug, just maintenance. |
| 8 | Cleanup | After `KeyboardInterrupt`, no `connection.close()`. Python GC handles it but explicit close is better for serial-port hygiene. |

---

## 7. Suggested fixes

### 7.1 Replace the rate request with the modern per-message API

```python
def request_imu_data():
    """Request IMU streaming using the modern per-message-interval API."""
    msg_ids = [
        mavutil.mavlink.MAVLINK_MSG_ID_RAW_IMU,       # 27
        mavutil.mavlink.MAVLINK_MSG_ID_SCALED_IMU2,   # 116
        mavutil.mavlink.MAVLINK_MSG_ID_SCALED_IMU3,   # 129
    ]
    interval_us = 100_000  # 100 ms = 10 Hz; use 20_000 for 50 Hz
    for msg_id in msg_ids:
        connection.mav.command_long_send(
            connection.target_system,
            connection.target_component,
            mavutil.mavlink.MAV_CMD_SET_MESSAGE_INTERVAL,
            0,                # confirmation
            msg_id,           # param1: message ID
            interval_us,      # param2: interval in microseconds
            0, 0, 0, 0, 0     # param3-7: unused
        )
```

The legacy `request_data_stream_send` call is removed.

### 7.2 Remove the redundant sleep

In the main loop, delete `time.sleep(0.1)` — `recv_match(blocking=True)` already blocks until a message arrives.

### 7.3 Add a heartbeat timeout + graceful failure

```python
print("Waiting for heartbeat...")
hb = connection.wait_heartbeat(timeout=10)
if hb is None:
    print("No heartbeat after 10 s. Check: baud, /dev/serial0 wiring, FC powered + booted, dialout group.")
    sys.exit(1)
print(f"Heartbeat received from system {connection.target_system}, component {connection.target_component}.")
```

### 7.4 Make port + baud CLI-configurable

```python
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--port', default='/dev/serial0', help='Serial port or UDP endpoint (e.g. udpin:127.0.0.1:14550)')
parser.add_argument('--baud', type=int, default=115200, help='Baud rate (only relevant for serial)')
parser.add_argument('--rate-hz', type=float, default=10, help='IMU stream rate in Hz')
args = parser.parse_args()
```

Then pass `args.port` / `args.baud` into `mavlink_connection`, and compute `interval_us = int(1_000_000 / args.rate_hz)` for the rate request.

### 7.5 Wrap connection + add explicit close

```python
import sys
try:
    connection = mavutil.mavlink_connection(args.port, baud=args.baud)
except Exception as e:
    print(f"Failed to open {args.port}: {e}")
    sys.exit(1)

try:
    # ... main loop ...
except KeyboardInterrupt:
    print("Exiting...")
finally:
    connection.close()
```

---

## 8. Cross-references

- [Roadmap §1.1](Roadmap#11-scope-clarifications-locked-30042026) — production architecture (`mavros2` as the canonical MAVLink ↔ ROS bridge; MAVProxy as a router not a bridge; DDS multicast verification on the IoT WiFi).
- [Roadmap §3 — Phase 5](Roadmap#3-phase-5--real-hardware-deployment) — full Phase 5 hardware-deployment summary, including `launch/remap.launch.yaml` for sim-vs-real swap-in routing.
- ArduPilot MAVProxy: <https://ardupilot.org/mavproxy/index.html>
- pymavlink (Python): <https://mavlink.io/en/mavgen_python/>
- MAVROS (ROS 2 port — what production uses): <https://github.com/mavlink/mavros>
