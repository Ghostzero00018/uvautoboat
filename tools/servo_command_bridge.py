#!/usr/bin/env python3
"""FCU -> VRX command bridge (Python equivalent of tools/servo_command.cpp).

Purpose
-------
Bridge MAVLink and ROS 2 over UDP, in both directions:

  inbound   FCU/SITL  --SERVO_OUTPUT_RAW-->  /wamv/thrusters/{left,right}/thrust
                                             (and optionally /cmd_vel)
  outbound  /gps/fix, /imu/data  --GLOBAL_POSITION_INT, ATTITUDE-->  FCU/SITL
            plus a 1 Hz HEARTBEAT

The inbound direction is the point of the exercise: the autopilot computes its
servo outputs and those drive the simulated thrusters. The outbound direction is
the hardware/software-in-the-loop return path that feeds the autopilot its
sensors.

Transport is UDP, exactly like the C++ reference. It therefore does NOT depend on
the Pi's serial link to the flight controller, which is currently receive-only.
Against a simulated autopilot (SITL on localhost) this bridge is fully usable
today; against the real flight controller the traffic still has to cross that
serial link, so the hardware blocker still applies there.

Differences from the C++ reference (deliberate)
-----------------------------------------------
* HEARTBEAT does not claim to be an armed autopilot. The reference sends
  MAV_MODE_GUIDED_ARMED as MAV_TYPE_SURFACE_BOAT; this node identifies as an
  onboard controller with base_mode 0 (not armed), which is the correct
  convention for a companion computer and avoids impersonating the vehicle.
* Default component id is the standard onboard-computer id rather than an ad-hoc
  value, so the node cannot be mistaken for the autopilot on the same system id.
* Servo decoding uses this vehicle's real mapping: LEFT = SERVO3, RIGHT = SERVO1,
  PWM range 800-2200 with 800 as neutral. The reference hard-codes servo1/servo2
  and a 1500-neutral assumption, which does not match this boat.
* Thrust is published on the project's own VRX topics
  (/wamv/thrusters/{left,right}/thrust, Float64 newtons). /cmd_vel is optional and
  off by default.
* Sensor injection towards the autopilot is OFF by default; enable it explicitly
  with publish_sensors:=true. Sending sensor data into a real flight controller is
  a write, and stays behind the project's normal approval.
* The receive loop uses a bounded wait and shuts down cleanly instead of blocking
  forever on a socket that is closed underneath it.

Safety
------
* This node only drives the SIMULATOR. It never commands a real motor, never
  arms, and sends no COMMAND_LONG / actuator / RC-override message.
* It publishes on /wamv/thrusters/*, which the Pi safety monitor treats as
  protected command topics: running this bridge while the live Pi stack is up
  will correctly abort that run. Use it in simulation, ideally on its own
  ROS_DOMAIN_ID.
* publish_sensors:=true transmits to the autopilot. Leave it false unless a
  hardware/software-in-the-loop session has been approved.

Usage
-----
    python3 tools/servo_command_bridge.py
    python3 tools/servo_command_bridge.py --ros-args \
        -p udp_send_port:=14551 -p udp_recv_port:=14555 \
        -p publish_sensors:=true -p publish_cmd_vel:=true

Requires rclpy and pymavlink (already used by tools/qgc_live_mission_bridge.py).
"""

import math
import socket
import threading

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from sensor_msgs.msg import Imu, NavSatFix
from std_msgs.msg import Float64

from pymavlink import mavutil

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

        # --- Servo -> thrust mapping (this vehicle) -----------------------
        self.left_channel = self.declare_parameter('left_servo_channel', 3).value
        self.right_channel = self.declare_parameter('right_servo_channel', 1).value
        self.pwm_min = self.declare_parameter('pwm_min', 800).value
        self.pwm_neutral = self.declare_parameter('pwm_neutral', 800).value
        self.pwm_max = self.declare_parameter('pwm_max', 2200).value
        self.max_thrust = self.declare_parameter('max_thrust', 100.0).value

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

        if self.pwm_max <= self.pwm_min:
            raise ValueError('pwm_max must be greater than pwm_min')

        # --- MAVLink endpoints ---------------------------------------------
        self.mav_out = mavutil.mavlink_connection(
            f'udpout:{self.target_ip}:{self.udp_send_port}',
            source_system=self.system_id,
            source_component=self.component_id)
        self.mav_in = mavutil.mavlink_connection(f'udpin:0.0.0.0:{self.udp_recv_port}')

        # --- ROS interfaces --------------------------------------------------
        self.pub_left = self.create_publisher(Float64, left_topic, 10)
        self.pub_right = self.create_publisher(Float64, right_topic, 10)
        self.pub_cmd_vel = (
            self.create_publisher(Twist, '/cmd_vel', 10) if self.publish_cmd_vel else None)

        self.sub_gps = self.create_subscription(
            NavSatFix, gps_topic, self.gps_callback, 10)
        self.sub_imu = self.create_subscription(
            Imu, imu_topic, self.imu_callback, 10)

        self.heartbeat_timer = self.create_timer(1.0, self.send_heartbeat)

        # --- Receive thread ---------------------------------------------------
        self._running = threading.Event()
        self._running.set()
        self._min_sensor_gap = 1.0 / self.sensor_rate_hz if self.sensor_rate_hz > 0 else 0.0
        self._last_gps_sent = 0.0
        self._last_imu_sent = 0.0
        self.recv_thread = threading.Thread(target=self.recv_loop, daemon=True)
        self.recv_thread.start()

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
        if pwm is None or pwm <= 0:
            return 0.0
        pwm = float(min(max(pwm, self.pwm_min), self.pwm_max))
        if self.pwm_neutral <= self.pwm_min:
            # Unidirectional: neutral sits at the bottom of the range.
            return (pwm - self.pwm_min) / (self.pwm_max - self.pwm_min)
        if pwm >= self.pwm_neutral:
            return (pwm - self.pwm_neutral) / max(self.pwm_max - self.pwm_neutral, 1.0)
        return -(self.pwm_neutral - pwm) / max(self.pwm_neutral - self.pwm_min, 1.0)

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

    def recv_loop(self):
        while self._running.is_set():
            try:
                msg = self.mav_in.recv_match(blocking=True, timeout=0.5)
            except Exception as exc:  # socket closed during shutdown
                if self._running.is_set():
                    self.get_logger().warning(f'receive failed: {exc}')
                return
            if msg is None:
                continue
            msg_type = msg.get_type()
            if msg_type == 'SERVO_OUTPUT_RAW':
                self.handle_servo_output(msg)
            elif msg_type == 'COMMAND_LONG':
                self.get_logger().info(f'received COMMAND_LONG: {msg.command}')

    def handle_servo_output(self, msg):
        left_pwm = getattr(msg, f'servo{self.left_channel}_raw', 0)
        right_pwm = getattr(msg, f'servo{self.right_channel}_raw', 0)

        left_norm = self.pwm_to_normalised(left_pwm)
        right_norm = self.pwm_to_normalised(right_pwm)

        left_msg = Float64()
        left_msg.data = left_norm * self.max_thrust
        right_msg = Float64()
        right_msg.data = right_norm * self.max_thrust
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
        for conn in (self.mav_in, self.mav_out):
            try:
                conn.close()
            except Exception:
                pass
        if self.recv_thread.is_alive():
            self.recv_thread.join(timeout=2.0)


def main(args=None):
    rclpy.init(args=args)
    node = ServoCommandBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.stop()
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
