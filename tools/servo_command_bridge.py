#!/usr/bin/env python3
"""FCU -> VRX command bridge for simulated-thruster integration.

Purpose
-------
This node contains two servo-input modes and two outbound paths:

* Default inbound path (``input_mode:=mavlink_udp``): FCU/SITL
  ``SERVO_OUTPUT_RAW`` messages drive /wamv/thrusters/{left,right}/thrust
  (and optionally /cmd_vel).
* Explicit relay path (``input_mode:=ros_rc_out_relay``): a read-only ROS
  subscription to ``/mavros/rc/out`` emits ``SERVO_OUTPUT_RAW`` on one fixed
  UDP output. By default it creates no UDP receiver, heartbeat, sensor
  subscriptions, or ROS publishers.
* Explicit twin-telemetry leg (``twin_telemetry_role:=sender|receiver``): the
  domain-77 receiver combines validated WAM-V pose and thrust into a dedicated
  loopback UDP stream; the domain-43 relay validates and republishes it as a
  String topic. This leg is disabled by default and carries no command back to
  either the simulator or flight controller.
* Unconditional outbound heartbeat: a 1 Hz HEARTBEAT is sent to the configured
  MAVLink output in the default mode. Nothing in the supported topology binds
  that output, so the heartbeat is unconsumed there.
* Optional outbound sensor injection: the /gps/fix and /imu/data path exists but
  is unsupported, unvalidated, and disabled by default. Keep
  publish_sensors:=false.

The supported inbound path is the point of the exercise: the autopilot computes
its servo outputs and those drive the simulated thrusters.

The default transport is UDP, exactly like the C++ reference. The explicit
relay mode converts MAVROS output already present in ROS into that same UDP
format so a separately isolated receiver can drive VRX. The bridge never opens
the Pi's serial link. Neither topology creates a command route back to the
flight controller.

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
* The relay mode is sender-only in the real-FCU ROS domain. VRX and the default
  receiver remain in their separate ROS domain and meet only at the command
  UDP socket. The opt-in twin-telemetry receiver is loopback-only and publishes
  telemetry; it does not create a return command path.
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

    -p input_mode:=ros_rc_out_relay \
        -p rc_out_topic:=/mavros/rc/out \
        -p target_ip:=127.0.0.1 -p udp_send_port:=14555 \
        -p left_servo_channel:=3 -p right_servo_channel:=1 \
        -p pwm_min:=800 -p pwm_neutral:=800 -p pwm_max:=2200 \
        -p publish_sensors:=false -p publish_cmd_vel:=false

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

from fcu_to_vrx_evidence import (
    bridge_servo_event,
    pwm_to_normalised,
    select_world_transform,
)
from geometry_msgs.msg import Twist
from pymavlink import mavutil
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from rclpy.signals import SignalHandlerOptions
from sensor_msgs.msg import Imu, NavSatFix
from std_msgs.msg import Float64, String

# MAVLink identity constants (avoids importing the dialect module directly).
MAV_TYPE_ONBOARD_CONTROLLER = 18
MAV_AUTOPILOT_INVALID = 8
MAV_STATE_ACTIVE = 4
NAVSAT_STATUS_FIX = 0
RMW_UNKNOWN_NODE_IDENTITIES = frozenset(
    {'_NODE_NAME_UNKNOWN_', '_NODE_NAMESPACE_UNKNOWN_'})
SERVO_OUTPUT_RAW_CHANNEL_FIELDS = tuple(
    name
    for name in mavutil.mavlink.MAVLink_servo_output_raw_message.fieldnames
    if name.startswith('servo') and name.endswith('_raw')
)
SERVO_OUTPUT_RAW_CHANNEL_COUNT = len(SERVO_OUTPUT_RAW_CHANNEL_FIELDS)
TWIN_TELEMETRY_SCHEMA = "uvautoboat.fcu_to_vrx.twin_telemetry.v1"
TWIN_TELEMETRY_SOURCE = "fcu_to_vrx_domain77_bridge"
TWIN_TELEMETRY_MAX_DATAGRAM_BYTES = 8192


class TwinTelemetryError(ValueError):
    """Raised when the isolated VRX telemetry leg violates its contract."""


def _finite_number(value):
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
    )


def _positive_integer(value):
    return not isinstance(value, bool) and isinstance(value, int) and value > 0


def validate_twin_telemetry_payload(
    payload,
    *,
    now_monotonic_ns,
    stale_seconds,
    world_frame,
    max_thrust,
    last_sequence=None,
):
    """Validate one loopback-only domain-77 to domain-43 telemetry sample."""
    if not isinstance(payload, dict) or set(payload) != {
        "schema",
        "source",
        "sequence",
        "sent_unix_ns",
        "sent_monotonic_ns",
        "pose",
        "thrust",
    }:
        raise TwinTelemetryError("twin telemetry envelope is incomplete")
    if payload["schema"] != TWIN_TELEMETRY_SCHEMA:
        raise TwinTelemetryError("twin telemetry schema does not match")
    if payload["source"] != TWIN_TELEMETRY_SOURCE:
        raise TwinTelemetryError("twin telemetry source does not match")
    sequence = payload["sequence"]
    if not _positive_integer(sequence):
        raise TwinTelemetryError("twin telemetry sequence must be positive")
    if last_sequence is not None and sequence <= last_sequence:
        raise TwinTelemetryError("twin telemetry sequence is not increasing")
    sent_unix_ns = payload["sent_unix_ns"]
    sent_monotonic_ns = payload["sent_monotonic_ns"]
    if not _positive_integer(sent_unix_ns) or not _positive_integer(
        sent_monotonic_ns
    ):
        raise TwinTelemetryError("twin telemetry timestamps must be positive")
    if not _positive_integer(now_monotonic_ns):
        raise TwinTelemetryError("receiver monotonic timestamp must be positive")
    if (
        isinstance(stale_seconds, bool)
        or not _finite_number(stale_seconds)
        or float(stale_seconds) <= 0.0
    ):
        raise TwinTelemetryError("twin telemetry stale limit must be positive")
    age_ns = now_monotonic_ns - sent_monotonic_ns
    if age_ns < 0 or age_ns > float(stale_seconds) * 1_000_000_000:
        raise TwinTelemetryError("twin telemetry sample is stale")

    pose = payload["pose"]
    if not isinstance(pose, dict) or set(pose) != {
        "frame_id",
        "child_frame_id",
        "position",
        "orientation",
    }:
        raise TwinTelemetryError("twin telemetry pose is incomplete")
    if pose["frame_id"] != world_frame:
        raise TwinTelemetryError("twin telemetry world frame does not match")
    if not isinstance(pose["child_frame_id"], str) or not pose[
        "child_frame_id"
    ]:
        raise TwinTelemetryError("twin telemetry child frame is empty")
    position = pose["position"]
    orientation = pose["orientation"]
    if not isinstance(position, dict) or set(position) != {"x", "y", "z"}:
        raise TwinTelemetryError("twin telemetry position is incomplete")
    if not isinstance(orientation, dict) or set(orientation) != {
        "x",
        "y",
        "z",
        "w",
    }:
        raise TwinTelemetryError("twin telemetry orientation is incomplete")
    if any(not _finite_number(value) for value in position.values()):
        raise TwinTelemetryError("twin telemetry position is non-finite")
    if any(not _finite_number(value) for value in orientation.values()):
        raise TwinTelemetryError("twin telemetry orientation is non-finite")
    quaternion_norm = math.sqrt(
        sum(float(value) ** 2 for value in orientation.values())
    )
    if not 0.5 <= quaternion_norm <= 1.5:
        raise TwinTelemetryError("twin telemetry orientation is invalid")

    thrust = payload["thrust"]
    if not isinstance(thrust, dict) or set(thrust) != {
        "left_newtons",
        "right_newtons",
    }:
        raise TwinTelemetryError("twin telemetry thrust is incomplete")
    if not _finite_number(max_thrust) or float(max_thrust) <= 0.0:
        raise TwinTelemetryError("twin telemetry thrust limit is invalid")
    for value in thrust.values():
        if not _finite_number(value) or abs(float(value)) > float(max_thrust):
            raise TwinTelemetryError("twin telemetry thrust is invalid")
    return payload


def publisher_node_paths(endpoint_infos):
    """Return one normalized entry per publisher endpoint, including unknowns."""
    paths = []
    for endpoint in endpoint_infos:
        namespace = getattr(endpoint, 'node_namespace', None)
        name = getattr(endpoint, 'node_name', None)
        if not isinstance(namespace, str) or not isinstance(name, str):
            paths.append('<unresolved>')
            continue
        normalized_name = name.strip('/')
        normalized_namespace = namespace.strip('/')
        if (
            not normalized_name
            or normalized_name in RMW_UNKNOWN_NODE_IDENTITIES
            or normalized_namespace in RMW_UNKNOWN_NODE_IDENTITIES
        ):
            paths.append('<unresolved>')
            continue
        paths.append(
            f'/{normalized_namespace}/{normalized_name}'
            if normalized_namespace else f'/{normalized_name}')
    return tuple(sorted(paths))


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
        self.input_mode = self.declare_parameter('input_mode', 'mavlink_udp').value
        self.rc_out_topic = self.declare_parameter(
            'rc_out_topic', '/mavros/rc/out').value
        self.rc_out_publisher = self.declare_parameter(
            'rc_out_publisher', '/mavros/rc').value
        self.rc_out_source_check_seconds = self.declare_parameter(
            'rc_out_source_check_seconds', 0.5).value
        self.twin_telemetry_role = self.declare_parameter(
            'twin_telemetry_role', 'disabled').value
        self.twin_telemetry_udp_port = self.declare_parameter(
            'twin_telemetry_udp_port', 14556).value
        self.twin_telemetry_topic = self.declare_parameter(
            'twin_telemetry_topic', '/fcu_to_vrx/twin_telemetry').value
        self.twin_telemetry_pose_topic = self.declare_parameter(
            'twin_telemetry_pose_topic', '/wamv/pose').value
        self.twin_telemetry_world_frame = self.declare_parameter(
            'twin_telemetry_world_frame', 'sydney_regatta').value
        self.twin_telemetry_stale_seconds = self.declare_parameter(
            'twin_telemetry_stale_seconds', 5).value
        self.twin_telemetry_rate_hz = self.declare_parameter(
            'twin_telemetry_rate_hz', 10.0).value

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
        if self.input_mode not in ('mavlink_udp', 'ros_rc_out_relay'):
            raise ValueError(
                'input_mode must be mavlink_udp or ros_rc_out_relay')
        if self.twin_telemetry_role not in ('disabled', 'sender', 'receiver'):
            raise ValueError(
                'twin_telemetry_role must be disabled, sender or receiver')
        if (
            self.twin_telemetry_role == 'sender'
            and self.input_mode != 'mavlink_udp'
        ):
            raise ValueError(
                'twin_telemetry_role sender requires mavlink_udp input mode')
        if (
            self.twin_telemetry_role == 'receiver'
            and self.input_mode != 'ros_rc_out_relay'
        ):
            raise ValueError(
                'twin_telemetry_role receiver requires ros_rc_out_relay input mode')
        if self.twin_telemetry_role != 'disabled':
            if (
                isinstance(self.twin_telemetry_udp_port, bool)
                or not isinstance(self.twin_telemetry_udp_port, int)
                or not 1 <= self.twin_telemetry_udp_port <= 65535
            ):
                raise ValueError(
                    'twin_telemetry_udp_port must be an integer in 1..65535')
            if (
                not isinstance(self.twin_telemetry_topic, str)
                or not self.twin_telemetry_topic.startswith('/')
                or self.twin_telemetry_topic == '/'
            ):
                raise ValueError(
                    'twin_telemetry_topic must be one absolute ROS topic')
            if (
                not isinstance(self.twin_telemetry_world_frame, str)
                or not self.twin_telemetry_world_frame
            ):
                raise ValueError('twin_telemetry_world_frame must not be empty')
            if not _positive_integer(self.twin_telemetry_stale_seconds):
                raise ValueError(
                    'twin_telemetry_stale_seconds must be a positive integer')
            if (
                isinstance(self.twin_telemetry_rate_hz, bool)
                or not _finite_number(self.twin_telemetry_rate_hz)
                or float(self.twin_telemetry_rate_hz) <= 0.0
            ):
                raise ValueError(
                    'twin_telemetry_rate_hz must be finite and positive')
        if self.input_mode == 'ros_rc_out_relay':
            if self.publish_sensors:
                raise ValueError(
                    'publish_sensors must remain false in ros_rc_out_relay mode')
            if self.publish_cmd_vel:
                raise ValueError(
                    'publish_cmd_vel must remain false in ros_rc_out_relay mode')
            if not self.rc_out_topic:
                raise ValueError(
                    'rc_out_topic must not be empty in ros_rc_out_relay mode')
            if (
                not isinstance(self.rc_out_publisher, str)
                or not self.rc_out_publisher.startswith('/')
                or self.rc_out_publisher == '/'
                or self.rc_out_publisher.endswith('/')
            ):
                raise ValueError(
                    'rc_out_publisher must be one absolute ROS node path')
            if (
                max(self.left_channel, self.right_channel)
                > SERVO_OUTPUT_RAW_CHANNEL_COUNT
            ):
                raise ValueError(
                    'mapped servo channels exceed the SERVO_OUTPUT_RAW dialect width')
            if (
                isinstance(self.rc_out_source_check_seconds, bool)
                or not isinstance(self.rc_out_source_check_seconds, (int, float))
                or not math.isfinite(float(self.rc_out_source_check_seconds))
                or float(self.rc_out_source_check_seconds) <= 0.0
            ):
                raise ValueError(
                    'rc_out_source_check_seconds must be finite and positive')

        # --- MAVLink endpoints ---------------------------------------------
        self.mav_out = mavutil.mavlink_connection(
            f'udpout:{self.target_ip}:{self.udp_send_port}',
            source_system=self.system_id,
            source_component=self.component_id)
        self.mav_in = None
        if self.input_mode == 'mavlink_udp':
            self.mav_in = mavutil.mavlink_connection(
                f'udpin:0.0.0.0:{self.udp_recv_port}')

        # --- ROS interfaces --------------------------------------------------
        self.pub_left = None
        self.pub_right = None
        self.pub_servo_evidence = None
        self.pub_cmd_vel = None
        self.pub_twin_telemetry = None
        if self.input_mode == 'mavlink_udp':
            self.pub_left = self.create_publisher(Float64, left_topic, 10)
            self.pub_right = self.create_publisher(Float64, right_topic, 10)
            self.pub_servo_evidence = self.create_publisher(
                String, '/fcu_to_vrx/servo_output_raw', 10)
            self.pub_cmd_vel = (
                self.create_publisher(Twist, '/cmd_vel', 10)
                if self.publish_cmd_vel else None)

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

        self.sub_gps = None
        self.sub_imu = None
        self.sub_rc_out = None
        self.heartbeat_timer = None
        self.relay_source_timer = None
        self.twin_telemetry_timer = None
        self.twin_telemetry_socket = None
        self.sub_twin_pose = None
        self._relay_source_ready = False
        if self.input_mode == 'mavlink_udp':
            self.sub_gps = self.create_subscription(
                NavSatFix, gps_topic, self.gps_callback, 10)
            self.sub_imu = self.create_subscription(
                Imu, imu_topic, self.imu_callback, 10)
            self.heartbeat_timer = self.create_timer(1.0, self.send_heartbeat)
        else:
            try:
                from mavros_msgs.msg import RCOut
            except ImportError as exc:
                raise RuntimeError(
                    'mavros_msgs is required in ros_rc_out_relay mode') from exc
            self.sub_rc_out = self.create_subscription(
                RCOut, self.rc_out_topic, self.handle_rc_out_relay,
                qos_profile_sensor_data)
            self.relay_source_timer = self.create_timer(
                float(self.rc_out_source_check_seconds),
                self.check_rc_out_relay_source)

        self._twin_telemetry_lock = threading.Lock()
        self._latest_twin_pose = None
        self._latest_twin_pose_monotonic_ns = None
        self._latest_twin_thrust = None
        self._latest_twin_thrust_monotonic_ns = None
        self._twin_telemetry_sequence = None
        self._twin_telemetry_ready = False
        self._last_twin_telemetry_monotonic_ns = None
        if self.twin_telemetry_role == 'sender':
            try:
                from tf2_msgs.msg import TFMessage
            except ImportError as exc:
                raise RuntimeError(
                    'tf2_msgs is required for the twin telemetry sender') from exc
            self.twin_telemetry_socket = socket.socket(
                socket.AF_INET, socket.SOCK_DGRAM)
            self.sub_twin_pose = self.create_subscription(
                TFMessage,
                self.twin_telemetry_pose_topic,
                self.twin_pose_callback,
                10)
            self.twin_telemetry_timer = self.create_timer(
                1.0 / float(self.twin_telemetry_rate_hz),
                self.send_twin_telemetry)
        elif self.twin_telemetry_role == 'receiver':
            self.twin_telemetry_socket = socket.socket(
                socket.AF_INET, socket.SOCK_DGRAM)
            self.twin_telemetry_socket.bind(
                ('127.0.0.1', self.twin_telemetry_udp_port))
            self.twin_telemetry_socket.setblocking(False)
            self.pub_twin_telemetry = self.create_publisher(
                String, self.twin_telemetry_topic, 10)
            self.twin_telemetry_timer = self.create_timer(
                min(0.1, float(self.twin_telemetry_stale_seconds) / 4.0),
                self.pump_twin_telemetry)

        # --- Receive thread ---------------------------------------------------
        self._running = threading.Event()
        self._running.set()
        self._publish_lock = threading.Lock()
        self._start_lock = threading.Lock()
        self._servo_frame_seen = False
        self._relay_frame_seen = False
        self._min_sensor_gap = 1.0 / self.sensor_rate_hz if self.sensor_rate_hz > 0 else 0.0
        self._last_gps_sent = 0.0
        self._last_imu_sent = 0.0
        self.recv_thread = None

        if self.input_mode == 'mavlink_udp':
            self.get_logger().info(
                f'bridge up: recv udp:{self.udp_recv_port} -> '
                f'{left_topic} / {right_topic}; '
                f'send udp:{self.target_ip}:{self.udp_send_port} '
                f'(sensor injection {"ON" if self.publish_sensors else "OFF"}); '
                f'left=SERVO{self.left_channel} right=SERVO{self.right_channel} '
                f'pwm {self.pwm_min}/{self.pwm_neutral}/{self.pwm_max}')
        else:
            self.get_logger().info(
                'FCU_TO_VRX_RC_OUT_RELAY_SOURCE=WAITING '
                f'topic={self.rc_out_topic} '
                f'publisher={self.rc_out_publisher} '
                f'udp={self.target_ip}:{self.udp_send_port} '
                f'left=SERVO{self.left_channel} right=SERVO{self.right_channel} '
                f'pwm={self.pwm_min}/{self.pwm_neutral}/{self.pwm_max}')
        if self.twin_telemetry_role == 'sender':
            self.get_logger().info(
                'FCU_TO_VRX_TWIN_TELEMETRY_SOURCE=WAITING '
                f'pose_topic={self.twin_telemetry_pose_topic} '
                f'world_frame={self.twin_telemetry_world_frame} '
                f'udp=127.0.0.1:{self.twin_telemetry_udp_port} '
                f'stale_seconds={self.twin_telemetry_stale_seconds}')
        elif self.twin_telemetry_role == 'receiver':
            self.get_logger().info(
                'FCU_TO_VRX_TWIN_TELEMETRY_RECEIVER=WAITING '
                f'topic={self.twin_telemetry_topic} '
                f'udp=127.0.0.1:{self.twin_telemetry_udp_port} '
                f'schema={TWIN_TELEMETRY_SCHEMA} '
                f'source={TWIN_TELEMETRY_SOURCE} '
                f'stale_seconds={self.twin_telemetry_stale_seconds}')

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
        if self.input_mode != 'mavlink_udp':
            return
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

    def handle_rc_out_relay(self, msg):
        """Relay MAVROS RCOut to one outbound SERVO_OUTPUT_RAW UDP stream."""
        if not self._running.is_set():
            return
        if not self.check_rc_out_relay_source():
            return
        try:
            channels = list(msg.channels)
            required_count = max(self.left_channel, self.right_channel)
            if len(channels) < required_count:
                raise ValueError(
                    f'RCOut has {len(channels)} channels; '
                    f'SERVO{required_count} is required')
            encoded = []
            for value in channels[:SERVO_OUTPUT_RAW_CHANNEL_COUNT]:
                if isinstance(value, bool):
                    raise ValueError('RCOut channel values must be integers')
                converted = int(value)
                if converted < 0 or converted > 0xFFFF:
                    raise ValueError('RCOut channel value is outside uint16')
                encoded.append(converted)
            encoded.extend(
                [0] * (SERVO_OUTPUT_RAW_CHANNEL_COUNT - len(encoded)))
        except (AttributeError, TypeError, ValueError) as exc:
            self.get_logger().warning(
                f'RCOut relay frame rejected: {exc}',
                throttle_duration_sec=5.0)
            return

        time_usec = int(time.monotonic_ns() // 1_000) & 0xFFFFFFFF
        try:
            self.mav_out.mav.servo_output_raw_send(
                time_usec, 0, *encoded)
        except (OSError, socket.error, ValueError) as exc:
            self.get_logger().warning(
                f'RCOut relay UDP send failed: {exc}',
                throttle_duration_sec=5.0)
            return

        if not self._relay_frame_seen:
            self.get_logger().info(
                'FCU_TO_VRX_RC_OUT_RELAY_FRAME=PASS '
                f'left=SERVO{self.left_channel}:{encoded[self.left_channel - 1]} '
                f'right=SERVO{self.right_channel}:{encoded[self.right_channel - 1]}',
                once=True)
            self._relay_frame_seen = True

    def check_rc_out_relay_source(self):
        """Bind once, then fail the relay if the RCOut source ever changes."""
        if not self._running.is_set():
            return False
        query_error = None
        try:
            publishers = publisher_node_paths(
                self.get_publishers_info_by_topic(self.rc_out_topic))
        except Exception as exc:
            publishers = ()
            query_error = str(exc)

        expected = (self.rc_out_publisher,)
        if publishers == expected:
            if not self._relay_source_ready:
                self._relay_source_ready = True
                self.get_logger().info(
                    'FCU_TO_VRX_RC_OUT_RELAY_READY=PASS '
                    f'topic={self.rc_out_topic} '
                    f'udp={self.target_ip}:{self.udp_send_port} '
                    f'left=SERVO{self.left_channel} '
                    f'right=SERVO{self.right_channel} '
                    f'pwm={self.pwm_min}/{self.pwm_neutral}/{self.pwm_max} '
                    f'publisher={self.rc_out_publisher}')
            return True

        observed = ','.join(publishers) if publishers else 'none'
        detail = (
            f'query_error={query_error}' if query_error is not None
            else f'observed={observed}')
        if not self._relay_source_ready and not publishers:
            self.get_logger().warning(
                'RCOut relay source not yet available: '
                f'expected={self.rc_out_publisher} {detail}',
                throttle_duration_sec=5.0)
            return False

        self._running.clear()
        message = (
            'RCOut relay publisher binding lost: '
            f'expected={self.rc_out_publisher} {detail}')
        self.get_logger().error(
            f'FCU_TO_VRX_RC_OUT_RELAY_STOP=FAIL reason={message}')
        raise RuntimeError(message)

    # ------------------------------------------------------------------
    # Outbound-only VRX telemetry: domain 77 -> loopback UDP -> domain 43
    # ------------------------------------------------------------------

    def twin_pose_callback(self, message):
        """Cache the WAM-V world transform for the opt-in telemetry sender."""
        transform = select_world_transform(
            message.transforms, self.twin_telemetry_world_frame)
        if transform is None:
            return
        translation = transform.transform.translation
        rotation = transform.transform.rotation
        pose = {
            'frame_id': str(transform.header.frame_id),
            'child_frame_id': str(transform.child_frame_id),
            'position': {
                'x': float(translation.x),
                'y': float(translation.y),
                'z': float(translation.z),
            },
            'orientation': {
                'x': float(rotation.x),
                'y': float(rotation.y),
                'z': float(rotation.z),
                'w': float(rotation.w),
            },
        }
        values = tuple(pose['position'].values()) + tuple(
            pose['orientation'].values())
        if any(not _finite_number(value) for value in values):
            return
        now = time.monotonic_ns()
        with self._twin_telemetry_lock:
            self._latest_twin_pose = pose
            self._latest_twin_pose_monotonic_ns = now

    def _fail_twin_telemetry(self, reason):
        self._running.clear()
        self.get_logger().error(
            f'FCU_TO_VRX_TWIN_TELEMETRY_STOP=FAIL reason={reason}')
        raise RuntimeError(reason)

    def send_twin_telemetry(self):
        """Send one fresh, combined VRX pose/thrust sample on loopback only."""
        if not self._running.is_set():
            return False
        now = time.monotonic_ns()
        with self._twin_telemetry_lock:
            pose = self._latest_twin_pose
            pose_seen = self._latest_twin_pose_monotonic_ns
            thrust = self._latest_twin_thrust
            thrust_seen = self._latest_twin_thrust_monotonic_ns
            previous_sequence = self._twin_telemetry_sequence
        if None in (pose, pose_seen, thrust, thrust_seen):
            return False
        stale_ns = self.twin_telemetry_stale_seconds * 1_000_000_000
        if now - pose_seen > stale_ns or now - thrust_seen > stale_ns:
            return False
        sequence = 1 if previous_sequence is None else previous_sequence + 1
        payload = {
            'schema': TWIN_TELEMETRY_SCHEMA,
            'source': TWIN_TELEMETRY_SOURCE,
            'sequence': sequence,
            'sent_unix_ns': time.time_ns(),
            'sent_monotonic_ns': now,
            'pose': pose,
            'thrust': thrust,
        }
        try:
            validate_twin_telemetry_payload(
                payload,
                now_monotonic_ns=now,
                stale_seconds=self.twin_telemetry_stale_seconds,
                world_frame=self.twin_telemetry_world_frame,
                max_thrust=self.max_thrust,
                last_sequence=previous_sequence,
            )
            encoded = json.dumps(
                payload,
                allow_nan=False,
                separators=(',', ':'),
                sort_keys=True,
            ).encode('utf-8')
            if len(encoded) > TWIN_TELEMETRY_MAX_DATAGRAM_BYTES:
                raise TwinTelemetryError('twin telemetry datagram is too large')
            sent = self.twin_telemetry_socket.sendto(
                encoded, ('127.0.0.1', self.twin_telemetry_udp_port))
            if sent != len(encoded):
                raise OSError('short twin telemetry UDP send')
        except (OSError, TypeError, ValueError, socket.error) as exc:
            return self._fail_twin_telemetry(
                f'twin telemetry send failed: {exc}')
        with self._twin_telemetry_lock:
            self._twin_telemetry_sequence = sequence
        return True

    def handle_twin_telemetry_datagram(
        self, datagram, address, *, now_monotonic_ns=None
    ):
        """Validate and republish one isolated loopback telemetry datagram."""
        now = time.monotonic_ns() if now_monotonic_ns is None else now_monotonic_ns
        try:
            if (
                not isinstance(address, tuple)
                or len(address) < 2
                or address[0] != '127.0.0.1'
            ):
                raise TwinTelemetryError(
                    'twin telemetry datagram did not originate on loopback')
            if (
                not isinstance(datagram, bytes)
                or not datagram
                or len(datagram) > TWIN_TELEMETRY_MAX_DATAGRAM_BYTES
            ):
                raise TwinTelemetryError('twin telemetry datagram size is invalid')
            payload = json.loads(datagram.decode('utf-8'))
            validate_twin_telemetry_payload(
                payload,
                now_monotonic_ns=now,
                stale_seconds=self.twin_telemetry_stale_seconds,
                world_frame=self.twin_telemetry_world_frame,
                max_thrust=self.max_thrust,
                last_sequence=self._twin_telemetry_sequence,
            )
            message = String()
            message.data = json.dumps(
                payload,
                allow_nan=False,
                separators=(',', ':'),
                sort_keys=True,
            )
            self.pub_twin_telemetry.publish(message)
        except (
            AttributeError,
            json.JSONDecodeError,
            OSError,
            TypeError,
            UnicodeDecodeError,
            ValueError,
        ) as exc:
            return self._fail_twin_telemetry(
                f'invalid twin telemetry datagram: {exc}')
        self._twin_telemetry_sequence = payload['sequence']
        self._last_twin_telemetry_monotonic_ns = now
        if not self._twin_telemetry_ready:
            self._twin_telemetry_ready = True
            self.get_logger().info(
                'FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS '
                f'topic={self.twin_telemetry_topic} '
                f'udp=127.0.0.1:{self.twin_telemetry_udp_port} '
                f'schema={TWIN_TELEMETRY_SCHEMA} '
                f'source={TWIN_TELEMETRY_SOURCE} '
                f'stale_seconds={self.twin_telemetry_stale_seconds}')
        return True

    def check_twin_telemetry_freshness(self, *, now_monotonic_ns=None):
        """Fail the bound receiver once its validated source becomes stale."""
        if not self._running.is_set() or not self._twin_telemetry_ready:
            return False
        now = time.monotonic_ns() if now_monotonic_ns is None else now_monotonic_ns
        age_ns = now - self._last_twin_telemetry_monotonic_ns
        stale_ns = self.twin_telemetry_stale_seconds * 1_000_000_000
        if age_ns < 0 or age_ns > stale_ns:
            return self._fail_twin_telemetry(
                'twin telemetry source stale after binding')
        return True

    def pump_twin_telemetry(self):
        """Drain bounded UDP input and enforce continuous source freshness."""
        if not self._running.is_set():
            return
        for _attempt in range(64):
            try:
                datagram, address = self.twin_telemetry_socket.recvfrom(
                    TWIN_TELEMETRY_MAX_DATAGRAM_BYTES + 1)
            except BlockingIOError:
                break
            except OSError as exc:
                self._fail_twin_telemetry(
                    f'twin telemetry UDP receive failed: {exc}')
            self.handle_twin_telemetry_datagram(datagram, address)
        self.check_twin_telemetry_freshness()

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
        if getattr(self, 'twin_telemetry_role', 'disabled') == 'sender':
            with self._twin_telemetry_lock:
                self._latest_twin_thrust = {
                    'left_newtons': float(evidence['left_thrust']),
                    'right_newtons': float(evidence['right_thrust']),
                }
                self._latest_twin_thrust_monotonic_ns = time.monotonic_ns()
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

        zero_commands = []
        if self.pub_left is not None:
            zero_commands.append(('left thrust', self.pub_left, Float64()))
        if self.pub_right is not None:
            zero_commands.append(('right thrust', self.pub_right, Float64()))
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

        for conn in (self.mav_in, self.mav_out, self.twin_telemetry_socket):
            if conn is None:
                continue
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
        while rclpy.ok() and node._running.is_set():
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
