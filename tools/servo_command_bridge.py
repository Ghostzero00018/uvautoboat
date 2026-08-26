#!/usr/bin/env python3
"""FCU -> VRX command bridge for simulated-thruster integration.

Purpose
-------
This node contains three distinct MAVLink/ROS 2 paths over UDP:

* Supported inbound path: FCU/SITL ``SERVO_OUTPUT_RAW`` messages drive
  /wamv/thrusters/{left,right}/thrust (and optionally /cmd_vel).
* Unconditional outbound heartbeat: a 1 Hz HEARTBEAT is sent to the configured
  MAVLink output. Nothing in the supported topology binds that output, so the
  heartbeat is unconsumed there.
* Optional outbound sensor injection: the /gps/fix and /imu/data path exists but
  is unsupported, unvalidated, and disabled by default. Keep
  publish_sensors:=false.

The supported inbound path is the point of the exercise: the autopilot computes
its servo outputs and those drive the simulated thrusters.

Transport is UDP, exactly like the C++ reference. The bridge never opens the
Pi's serial link. Against SITL it consumes the simulator's local MAVLink output;
against the real flight controller it consumes the Pi supervisor's outbound-only
MAVLink fanout on the workstation. Neither topology creates a command route back
to the flight controller.

Differences from the C++ reference (deliberate)
-----------------------------------------------
* HEARTBEAT does not claim to be an armed autopilot. The reference sends
  MAV_MODE_GUIDED_ARMED as MAV_TYPE_SURFACE_BOAT; this node identifies as an
  onboard controller with base_mode 0 (not armed), which is the correct
  convention for a companion computer and avoids impersonating the vehicle.
* Default component id is the standard onboard-computer id rather than an ad-hoc
  value, so the node cannot be mistaken for the autopilot on the same system id.
* Servo decoding defaults to LEFT = SERVO3 and RIGHT = SERVO1, which is the
  REAL BOAT's mapping. Rover SITL is the mirror image: it assigns
  SERVO1_FUNCTION 73 (ThrottleLeft) and SERVO3_FUNCTION 74 (ThrottleRight), so
  the defaults decode left and right INVERTED against a stock SITL instance.
  Measured 07/08/2026 on ArduRover 4.6.3 with frame motorboat-skid; the enum
  lives in libraries/SRV_Channel/SRV_Channel.h. Always set the channels from
  the observed SERVO*_FUNCTION values rather than relying on these defaults.
* The PWM defaults (1100/1500/1900) match NEITHER platform. Measured Rover
  SITL is 1000/1500/2000 (neutral at mid-scale, so reverse is available); the
  real boat is 800/800/2200 (neutral at the BOTTOM, so there is no reverse).
  Emitting a mid-scale neutral at the real boat commands roughly half thrust
  on both thrusters while the caller believes it commanded zero. Read the
  rail from the live parameter listing every time; do not trust any
  hard-coded profile, including these defaults.
* Thrust is published on the project's own VRX topics
  (/wamv/thrusters/{left,right}/thrust, Float64 newtons). /cmd_vel is optional and
  off by default.
* Outbound GPS/IMU injection towards the autopilot is unsupported and not
  validated for the SITL-to-VRX path. Keep publish_sensors:=false.
* The receive loop uses a bounded wait and shuts down cleanly instead of blocking
  forever on a socket that is closed underneath it.

Safety
------
* This node only drives the SIMULATOR. It never commands a real motor, never
  arms, and sends no COMMAND_LONG / actuator / RC-override message.
* It publishes on /wamv/thrusters/*, which the Pi safety monitor treats as
  protected command topics. If this bridge and the live Pi helper are discoverable
  in the same ROS domain, the helper will abort on the first protected thrust
  message. Any run must keep the Pi stack down and use a separate explicitly
  isolated ROS_DOMAIN_ID.
* Outbound GPS/IMU injection is outside the supported path. Keep
  publish_sensors:=false; do not enable it for this run.

Usage
-----
Start SITL with an explicit MAVProxy output for this node; the receive endpoint
does not initiate a connection:

    --out=udp:127.0.0.1:14555

At the MAVProxy prompt, inspect all channel functions before starting the bridge:

    param show SERVO*_FUNCTION
    param show SERVO*_MIN
    param show SERVO*_TRIM
    param show SERVO*_MAX

Select ``left_servo_channel`` and ``right_servo_channel`` from the observed
assignments rather than assuming fixed channel numbers. Function 73 is
ThrottleLeft and 74 is ThrottleRight on both platforms; only the channel
numbers carrying those functions differ. Replace the example values below
with the confirmed ones.

Use the same isolated domain for VRX and every bridge/query terminal. Start VRX
alone rather than the complete live-boat launch.

Against stock Rover SITL, the values measured on 07/08/2026 are:

    export ROS_DOMAIN_ID=42
    python3 tools/servo_command_bridge.py --ros-args \
        -p left_servo_channel:=1 -p right_servo_channel:=3 \
        -p pwm_min:=1000 -p pwm_neutral:=1500 -p pwm_max:=2000 \
        -p max_thrust:=800.0 -p publish_sensors:=false

The decimal in ``800.0`` is required by the declared ROS parameter type. The
real boat's profile, which must never be combined with the SITL channel numbers
above, is:

    -p left_servo_channel:=3 -p right_servo_channel:=1 \
        -p pwm_min:=800 -p pwm_neutral:=800 -p pwm_max:=2200

Mixing a channel mapping from one platform with a rail from the other is the
specific mistake this file previously documented; check both together.

Requires rclpy and pymavlink (already used by tools/qgc_live_mission_bridge.py).
"""

import json
import math
import signal
import socket
import threading
import time

from fcu_to_vrx_evidence import bridge_servo_event, pwm_to_normalised
from geometry_msgs.msg import Twist
from pymavlink import mavutil
import rclpy
from rclpy.node import Node
from rclpy.signals import SignalHandlerOptions
from sensor_msgs.msg import Imu, NavSatFix
from std_msgs.msg import Float64, String

# MAVLink identity constants (avoids importing the dialect module directly).
MAV_TYPE_ONBOARD_CONTROLLER = 18
MAV_AUTOPILOT_INVALID = 8
MAV_STATE_ACTIVE = 4
NAVSAT_STATUS_FIX = 0


class ServoCommandBridge(Node):
    """MAVLink <-> ROS 2 bridge for autopilot servo output and sensor return."""

    def __init__(self):
        super().__init__('usv_mav_bridge')

        # --- MAVLink identity and transport -------------------------------
        self.system_id = self.declare_parameter('system_id', 1).value
        self.component_id = self.declare_parameter('component_id', 191).value
        self.target_ip = self.declare_parameter('target_ip', '127.0.0.1').value
        self.udp_send_port = self.declare_parameter('udp_send_port', 14551).value
        self.udp_recv_port = self.declare_parameter('udp_recv_port', 14555).value

        # --- Servo -> thrust mapping --------------------------------------
        self.left_channel = self.declare_parameter('left_servo_channel', 3).value
        self.right_channel = self.declare_parameter('right_servo_channel', 1).value
        self.pwm_min = self.declare_parameter('pwm_min', 1100).value
        self.pwm_neutral = self.declare_parameter('pwm_neutral', 1500).value
        self.pwm_max = self.declare_parameter('pwm_max', 1900).value
        self.max_thrust = self.declare_parameter('max_thrust', 800.0).value

        # --- Direction switches -------------------------------------------
        self.publish_sensors = self.declare_parameter('publish_sensors', False).value
        self.publish_cmd_vel = self.declare_parameter('publish_cmd_vel', False).value
        self.sensor_rate_hz = self.declare_parameter('sensor_rate_hz', 10.0).value

        # --- Topics --------------------------------------------------------
        gps_topic = self.declare_parameter('gps_topic', '/gps/fix').value
        imu_topic = self.declare_parameter('imu_topic', '/imu/data').value
        left_topic = self.declare_parameter(
            'left_thrust_topic', '/wamv/thrusters/left/thrust').value
        right_topic = self.declare_parameter(
            'right_thrust_topic', '/wamv/thrusters/right/thrust').value

        if not 1 <= self.left_channel <= 16 or not 1 <= self.right_channel <= 16:
            raise ValueError('servo channels must be in the MAVLink range 1..16')
        if self.left_channel == self.right_channel:
            raise ValueError('left and right servo channels must be distinct')
        if self.pwm_max <= self.pwm_min:
            raise ValueError('pwm_max must be greater than pwm_min')
        if not self.pwm_min <= self.pwm_neutral <= self.pwm_max:
            raise ValueError('pwm_neutral must be between pwm_min and pwm_max')
        if not math.isfinite(self.max_thrust) or self.max_thrust <= 0.0:
            raise ValueError('max_thrust must be finite and greater than zero')

        # --- MAVLink endpoints ---------------------------------------------
        self.mav_out = mavutil.mavlink_connection(
            f'udpout:{self.target_ip}:{self.udp_send_port}',
            source_system=self.system_id,
            source_component=self.component_id)
        self.mav_in = mavutil.mavlink_connection(f'udpin:0.0.0.0:{self.udp_recv_port}')

        # --- ROS interfaces --------------------------------------------------
        self.pub_left = self.create_publisher(Float64, left_topic, 10)
        self.pub_right = self.create_publisher(Float64, right_topic, 10)
        self.pub_servo_evidence = self.create_publisher(
            String, '/fcu_to_vrx/servo_output_raw', 10)
        self.pub_cmd_vel = (
            self.create_publisher(Twist, '/cmd_vel', 10) if self.publish_cmd_vel else None)

        self.evidence_config = {
            'left_channel': self.left_channel,
            'right_channel': self.right_channel,
            'left': {
                'minimum': self.pwm_min,
                'trim': self.pwm_neutral,
                'maximum': self.pwm_max,
            },
            'right': {
                'minimum': self.pwm_min,
                'trim': self.pwm_neutral,
                'maximum': self.pwm_max,
            },
            'max_thrust': self.max_thrust,
        }

        self.sub_gps = self.create_subscription(
            NavSatFix, gps_topic, self.gps_callback, 10)
        self.sub_imu = self.create_subscription(
            Imu, imu_topic, self.imu_callback, 10)

        self.heartbeat_timer = self.create_timer(1.0, self.send_heartbeat)

        # --- Receive thread ---------------------------------------------------
        self._running = threading.Event()
        self._running.set()
        self._publish_lock = threading.Lock()
        self._start_lock = threading.Lock()
        self._servo_frame_seen = False
        self._min_sensor_gap = 1.0 / self.sensor_rate_hz if self.sensor_rate_hz > 0 else 0.0
        self._last_gps_sent = 0.0
        self._last_imu_sent = 0.0
        self.recv_thread = None

        self.get_logger().info(
            f'bridge up: recv udp:{self.udp_recv_port} -> {left_topic} / {right_topic}; '
            f'send udp:{self.target_ip}:{self.udp_send_port} '
            f'(sensor injection {"ON" if self.publish_sensors else "OFF"}); '
            f'left=SERVO{self.left_channel} right=SERVO{self.right_channel} '
            f'pwm {self.pwm_min}/{self.pwm_neutral}/{self.pwm_max}')

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _now_ms(self):
        return int(self.get_clock().now().nanoseconds / 1_000_000)

    def _rate_ok(self, last_sent):
        if self._min_sensor_gap <= 0.0:
            return True, last_sent
        now = self.get_clock().now().nanoseconds / 1e9
        if now - last_sent < self._min_sensor_gap:
            return False, last_sent
        return True, now

    def pwm_to_normalised(self, pwm):
        """Map a raw servo PWM value to -1.0..1.0 (or 0.0..1.0 when neutral == min).

        A raw value of 0 means the channel is disabled and yields 0.0.
        """
        return pwm_to_normalised(
            pwm, self.pwm_min, self.pwm_neutral, self.pwm_max)

    @staticmethod
    def quaternion_to_rpy(x, y, z, w):
        """Convert a quaternion to roll, pitch, yaw (radians)."""
        sinr_cosp = 2.0 * (w * x + y * z)
        cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
        roll = math.atan2(sinr_cosp, cosr_cosp)

        sinp = 2.0 * (w * y - z * x)
        pitch = math.copysign(math.pi / 2.0, sinp) if abs(sinp) >= 1.0 else math.asin(sinp)

        siny_cosp = 2.0 * (w * z + x * y)
        cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
        yaw = math.atan2(siny_cosp, cosy_cosp)
        return roll, pitch, yaw

    # ------------------------------------------------------------------
    # Outbound: ROS -> MAVLink (opt-in)
    # ------------------------------------------------------------------

    def gps_callback(self, msg):
        if not self.publish_sensors:
            return
        if msg.status.status < NAVSAT_STATUS_FIX:
            return
        allowed, stamp = self._rate_ok(self._last_gps_sent)
        if not allowed:
            return
        self._last_gps_sent = stamp
        try:
            self.mav_out.mav.global_position_int_send(
                self._now_ms(),
                int(msg.latitude * 1e7),
                int(msg.longitude * 1e7),
                int(msg.altitude * 1000.0),
                int(msg.altitude * 1000.0),
                0, 0, 0, 0)
        except (OSError, socket.error) as exc:
            self.get_logger().warning(f'GPS send failed: {exc}')

    def imu_callback(self, msg):
        if not self.publish_sensors:
            return
        allowed, stamp = self._rate_ok(self._last_imu_sent)
        if not allowed:
            return
        self._last_imu_sent = stamp
        roll, pitch, yaw = self.quaternion_to_rpy(
            msg.orientation.x, msg.orientation.y,
            msg.orientation.z, msg.orientation.w)
        try:
            self.mav_out.mav.attitude_send(
                self._now_ms(),
                roll, pitch, yaw,
                msg.angular_velocity.x,
                msg.angular_velocity.y,
                msg.angular_velocity.z)
        except (OSError, socket.error) as exc:
            self.get_logger().warning(f'IMU send failed: {exc}')

    def send_heartbeat(self):
        """Announce this node as an onboard controller - never as an armed vehicle."""
        try:
            self.mav_out.mav.heartbeat_send(
                MAV_TYPE_ONBOARD_CONTROLLER,
                MAV_AUTOPILOT_INVALID,
                0,                      # base_mode: not armed
                0,                      # custom_mode
                MAV_STATE_ACTIVE)
        except (OSError, socket.error) as exc:
            self.get_logger().warning(f'heartbeat send failed: {exc}')

    # ------------------------------------------------------------------
    # Inbound: MAVLink -> ROS
    # ------------------------------------------------------------------

    def start(self):
        """Start MAVLink reception once construction is fully protected."""
        with self._start_lock:
            if self.recv_thread is not None:
                return
            self.recv_thread = threading.Thread(target=self.recv_loop, daemon=True)
            self.recv_thread.start()

    def recv_loop(self):
        while self._running.is_set():
            try:
                msg = self.mav_in.recv_match(blocking=True, timeout=0.5)
                if msg is None:
                    continue
                msg_type = msg.get_type()
                if msg_type == 'SERVO_OUTPUT_RAW':
                    self.handle_servo_output(msg)
                elif msg_type == 'COMMAND_LONG':
                    self.get_logger().info(f'received COMMAND_LONG: {msg.command}')
            except Exception as exc:
                if not self._running.is_set():
                    break
                self.get_logger().warning(
                    f'MAVLink receive/decode/publish failed: {exc}',
                    throttle_duration_sec=5.0)

    def handle_servo_output(self, msg):
        left_pwm = getattr(msg, f'servo{self.left_channel}_raw', 0)
        right_pwm = getattr(msg, f'servo{self.right_channel}_raw', 0)
        evidence = bridge_servo_event(
            self.evidence_config,
            left_pwm=int(left_pwm),
            right_pwm=int(right_pwm),
            time_usec=int(getattr(msg, 'time_usec', 0)),
            received_unix_ns=time.time_ns(),
        )
        left_norm = evidence['left_thrust'] / self.max_thrust
        right_norm = evidence['right_thrust'] / self.max_thrust

        left_msg = Float64()
        left_msg.data = evidence['left_thrust']
        right_msg = Float64()
        right_msg.data = evidence['right_thrust']
        evidence_msg = String()
        evidence_msg.data = json.dumps(
            evidence, allow_nan=False, separators=(',', ':'), sort_keys=True)

        diagnostic = (
            f'SERVO_OUTPUT_RAW: left SERVO{self.left_channel} {left_pwm} -> '
            f'{left_norm:+.3f} -> {left_msg.data:+.1f} N; '
            f'right SERVO{self.right_channel} {right_pwm} -> '
            f'{right_norm:+.3f} -> {right_msg.data:+.1f} N')
        if not self._servo_frame_seen:
            self.get_logger().info(diagnostic, once=True)
            self._servo_frame_seen = True
        else:
            self.get_logger().info(diagnostic, throttle_duration_sec=5.0)

        with self._publish_lock:
            if not self._running.is_set():
                return
            self.pub_servo_evidence.publish(evidence_msg)
            self.pub_left.publish(left_msg)
            self.pub_right.publish(right_msg)

            if self.pub_cmd_vel is not None:
                cmd = Twist()
                cmd.linear.x = (left_norm + right_norm) / 2.0
                cmd.angular.z = (right_norm - left_norm) / 2.0
                self.pub_cmd_vel.publish(cmd)

    # ------------------------------------------------------------------
    # Shutdown
    # ------------------------------------------------------------------

    def stop(self):
        self._running.clear()

        zero_commands = [
            ('left thrust', self.pub_left, Float64()),
            ('right thrust', self.pub_right, Float64()),
        ]
        if self.pub_cmd_vel is not None:
            zero_commands.append(('cmd_vel', self.pub_cmd_vel, Twist()))

        stop_failures = []
        with self._publish_lock:
            for label, publisher, message in zero_commands:
                try:
                    publisher.publish(message)
                except Exception as exc:
                    stop_failures.append(f'{label}: {exc}')
        if stop_failures:
            self.get_logger().warning(
                'failed to publish one or more stop commands: ' + '; '.join(stop_failures))

        for conn in (self.mav_in, self.mav_out):
            try:
                conn.close()
            except Exception:
                pass
        recv_thread = self.recv_thread
        if recv_thread is not None and recv_thread.is_alive():
            recv_thread.join(timeout=2.0)


def main(args=None):
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    rclpy.init(args=args, signal_handler_options=SignalHandlerOptions.NO)
    node = ServoCommandBridge()
    try:
        node.start()
        while rclpy.ok():
            rclpy.spin_once(node, timeout_sec=0.1)
    except KeyboardInterrupt:
        pass
    finally:
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        node.stop()
        flush_deadline = time.monotonic() + 0.5
        while rclpy.ok():
            remaining = flush_deadline - time.monotonic()
            if remaining <= 0.0:
                break
            rclpy.spin_once(node, timeout_sec=min(0.1, remaining))
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
