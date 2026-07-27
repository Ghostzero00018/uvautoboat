# Monday 27/07/2026 - FCU-to-VRX Bridge Reference and Python Equivalent

## Status

Vacation side-work (25/07 - 02/08 break), outside the frozen Week 21 plan. Documentation
and one new standalone tool only: no live run, no hardware, no Pi command, no FCU contact,
and no change to the dashboard, the helpers, the write guard, or the safety monitor.

## What landed

`ab16f15` added `tools/servo_command.cpp` (`180` lines), a C++ reference for
autopilot-to-simulator command bridging. It is a reference only: it has no `main()`, no
`rclcpp::init` / `spin`, no `CMakeLists.txt` or `package.xml`, and the `bridge` package
still does not exist, so it does not build into an executable. This is consistent with the
servo-activation reference requested on 24/07, though the commit itself records no source.

## What the reference does

A ROS 2 node (`usv_mav_bridge`) bridging MAVLink and ROS over UDP in both directions:

| Direction | Content |
| --- | --- |
| MAVLink -> ROS | `SERVO_OUTPUT_RAW` decoded to `/cmd_vel` (`geometry_msgs/Twist`) |
| ROS -> MAVLink | `/gps/fix` -> `GLOBAL_POSITION_INT`; `/imu/data` -> `ATTITUDE`; 1 Hz `HEARTBEAT` |

The autopilot computes servo outputs which drive the simulator, and the simulator returns
the sensor stream the autopilot needs. It also logs inbound `COMMAND_LONG`.

## Key finding - the transport is UDP, not the blocked serial link

The 24/07 blocker is that the Pi-to-FCU **serial** link (`/dev/ttyAMA0`) is receive-only.
This reference is UDP-based, which changes what is reachable:

- Against a **simulated autopilot (SITL on localhost)** nothing crosses the serial link, so
  this path is fully usable today and the hardware blocker does not apply.
- Against the **real flight controller** the traffic still has to reach the FCU over that
  same serial link, so the blocker still applies and nothing here fixes it.

The practical consequence: a SITL-based bridge is a way to develop and prove the
autopilot-to-simulator command path while the boat-side wiring fix is pending. It is not a
substitute for that fix, and it proves nothing about real motor output.

## Reference issues found (read-only review)

1. **Heartbeat claims an armed autopilot.** It sends `MAV_MODE_GUIDED_ARMED` as
   `MAV_TYPE_SURFACE_BOAT`, and defaults `system_id` to `1` - the real vehicle's system id.
   A companion process should not identify as the armed vehicle; this conflicts with the
   project's no-arming boundary and risks confusing a ground station on a shared link.
2. **Servo mapping does not match this boat.** It reads `servo1_raw` / `servo2_raw` and
   converts with `(s1 + s2) / 2 / 1000`, i.e. a 1500-neutral assumption. This vehicle is
   LEFT = `SERVO3`, RIGHT = `SERVO1`, PWM `800-2200` with neutral `800` (24/07 finding).
   Applied unchanged, a neutral `800` reading yields `0.800` instead of `0.0` - the
   simulator would be driven at ~80 % forward while the autopilot is commanding stop. The
   file marks this section as an example, so this is an adaptation note, not a defect in a
   reference.
3. **Topic names are generic.** `/gps/fix`, `/imu/data`, `/cmd_vel` rather than this
   project's `/wamv/sensors/...` and `/wamv/thrusters/{left,right}/thrust`.
4. **Ports.** `14551` send / `14555` receive, which is not the established MAVProxy `14550`
   fan-out; routing to it needs an explicit MAVProxy `--out`.

Minor: the receive loop blocks in `receive_from()` with no exception handling while the
destructor closes the socket underneath it, and sensor forwarding is unthrottled.

## Python equivalent added - `tools/servo_command_bridge.py`

A standalone, runnable Python node providing the same bridge, using `rclpy` and
`pymavlink` (already a project dependency via `tools/qgc_live_mission_bridge.py`). It is a
single file with a `main()`; it needs no new ROS package and no build.

Deliberate differences from the reference, all safety- or correctness-driven:

- identifies as an onboard controller with `base_mode 0` (**not armed**) and the standard
  onboard-computer component id, so it never impersonates the vehicle;
- decodes this boat's real mapping - LEFT `SERVO3`, RIGHT `SERVO1`, PWM `800/800/2200` -
  and handles both a neutral-at-minimum (unidirectional) and a centred (bidirectional)
  range;
- publishes the project's own VRX topics `/wamv/thrusters/{left,right}/thrust` (`Float64`
  newtons); `/cmd_vel` is optional and off by default;
- **sensor injection towards the autopilot is off by default** (`publish_sensors`), because
  transmitting into a real flight controller is a write;
- bounded receive with clean shutdown, and rate-limited sensor forwarding.

Verified locally: `python -m py_compile` passes, and the PWM normalisation was checked
against this boat's range (`800 -> 0.000`, `1500 -> 0.500`, `2200 -> 1.000`, disabled
channel `0 -> 0.000`) and against a centred range (`1500 -> 0.000`, `1900 -> +1.000`,
`1100 -> -1.000`). No ROS runtime, MAVLink endpoint, SITL instance, or simulator was
started, so the node is **source-verified only and not runtime-proven**.

## Boundaries

- This bridge drives the **simulator** only. It sends no `COMMAND_LONG`, no actuator or
  RC-override message, and never arms.
- It publishes on `/wamv/thrusters/*`, which the Pi safety monitor treats as protected
  command topics: running it while the live Pi stack is up will correctly abort that run.
  Use it in simulation, ideally on its own `ROS_DOMAIN_ID`.
- `publish_sensors:=true` transmits to the autopilot and stays behind normal approval.
- The dashboard-to-real-motor track is unchanged and still parked on the receive-only
  Pi-to-FCU serial link, behind the arming and propellers-removed bench gate.

## Next step

Nothing further during the break. On 03/08 the main task remains the `ros2 --no-daemon`
graph-query hardening. The bridge work is a Task 3 option: run
`tools/servo_command_bridge.py` against a SITL autopilot to prove the autopilot-to-simulator
command path without touching the blocked serial link, before or independently of the
boat-side wiring fix. Any real-FCU use still needs the link repaired and its own approval.
