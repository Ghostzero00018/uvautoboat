#!/usr/bin/env python3
"""Guarded RC-layer command bridge for a physical ArduRover bench test.

The browser publishes paired steering/throttle requests as ``sensor_msgs/Joy``
on ``/command_ingress/rc_axes``.  This node resolves the connected vehicle's RC
mapping and rails through MAVROS before it creates any override publisher, then
publishes atomic ``mavros_msgs/OverrideRCIn`` frames at 20 Hz.  Measured
``/mavros/rc/out`` values are returned in a JSON status stream for the dashboard.

This bridge deliberately has no arm, disarm, mode, parameter-write, motor-test
or raw-servo-command path.  Arming remains an external operator action.  The
node is inert unless ``allow_real_fcu`` is explicitly true, ROS domain 42 is in
use, every live guard passes twice, the vehicle was first observed disarmed in
MANUAL, and exactly one command publisher exists.
"""

from __future__ import annotations

import json
import math
import os
import signal
import sys
import time
from dataclasses import dataclass
from typing import Dict, Iterable, Mapping, Optional, Sequence

import rclpy
from mavros_msgs.msg import OverrideRCIn, RCIn, RCOut, State
from mavros_msgs.srv import ParamPull
from rcl_interfaces.msg import ParameterType, ParameterValue
from rclpy.node import Node
from rclpy.parameter_client import AsyncParameterClient
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from rclpy.signals import SignalHandlerOptions
from sensor_msgs.msg import Joy
from std_msgs.msg import Bool, String


COMMAND_TOPIC = "/command_ingress/rc_axes"
STATUS_TOPIC = "/command_ingress/status"
OVERRIDE_TOPIC = "/mavros/rc/override"
PARAM_NODE = "/mavros/param"
PARAM_PULL_SERVICE = "/mavros/param/pull"
FRAME_ID = "uvautoboat/rc_axes/v1"
COMMAND_TIMEOUT_SECONDS = 0.150
PUBLISH_PERIOD_SECONDS = 0.050
STATE_TIMEOUT_SECONDS = 2.5
FEEDBACK_TIMEOUT_SECONDS = 1.5
EXPECTED_DOMAIN_ID = "42"
NO_CHANGE = 65535
RELEASE_HIGH_CHANNEL = 65534


class GuardError(RuntimeError):
    """Raised when live vehicle configuration cannot satisfy the bridge guard."""


def decode_parameter_value(
    name: str,
    value: ParameterValue,
    required: bool = True,
) -> Optional[float]:
    """Decode the numeric ROS parameter types emitted by MAVROS."""
    if value.type == ParameterType.PARAMETER_NOT_SET:
        if required:
            raise GuardError(f"no live MAVROS parameter response for {name}")
        return None
    if value.type == ParameterType.PARAMETER_INTEGER:
        return float(value.integer_value)
    if value.type == ParameterType.PARAMETER_DOUBLE:
        return float(value.double_value)
    raise GuardError(f"live MAVROS parameter {name} is not numeric")


@dataclass(frozen=True)
class RcRail:
    minimum: int
    trim: int
    maximum: int
    dead_zone: int
    reversed: int


@dataclass(frozen=True)
class ServoRail:
    minimum: int
    trim: int
    maximum: int
    reversed: int


@dataclass(frozen=True)
class LiveGuard:
    steering_channel: int
    throttle_channel: int
    left_servo: int
    right_servo: int
    steering_rail: RcRail
    throttle_rail: RcRail
    left_servo_rail: ServoRail
    right_servo_rail: ServoRail
    recorded: Mapping[str, float]


def exact_int(name: str, value: float) -> int:
    if not isinstance(value, (int, float)) or not math.isfinite(value):
        raise GuardError(f"{name} is not finite")
    integer = int(value)
    if float(integer) != float(value):
        raise GuardError(f"{name} is not an exact integer: {value}")
    return integer


def require_value(values: Mapping[str, float], name: str) -> float:
    if name not in values:
        raise GuardError(f"missing live parameter {name}")
    value = values[name]
    if not isinstance(value, (int, float)) or not math.isfinite(value):
        raise GuardError(f"invalid live parameter {name}: {value}")
    return float(value)


def discover_channels(values: Mapping[str, float]) -> tuple[int, int, int, int]:
    steering = exact_int("RCMAP_ROLL", require_value(values, "RCMAP_ROLL"))
    throttle = exact_int("RCMAP_THROTTLE", require_value(values, "RCMAP_THROTTLE"))
    if not (1 <= steering <= 16 and 1 <= throttle <= 16 and steering != throttle):
        raise GuardError("RCMAP_ROLL/RCMAP_THROTTLE must be distinct channels in 1..16")

    functions: Dict[int, int] = {}
    for channel in range(1, 17):
        name = f"SERVO{channel}_FUNCTION"
        functions[channel] = exact_int(name, require_value(values, name))
    left = [channel for channel, function in functions.items() if function == 73]
    right = [channel for channel, function in functions.items() if function == 74]
    if len(left) != 1 or len(right) != 1:
        raise GuardError("functions 73 and 74 must each have exactly one SERVO1..16 assignment")
    return steering, throttle, left[0], right[0]


def _rc_rail(values: Mapping[str, float], channel: int) -> RcRail:
    prefix = f"RC{channel}_"
    rail = RcRail(
        exact_int(prefix + "MIN", require_value(values, prefix + "MIN")),
        exact_int(prefix + "TRIM", require_value(values, prefix + "TRIM")),
        exact_int(prefix + "MAX", require_value(values, prefix + "MAX")),
        exact_int(prefix + "DZ", require_value(values, prefix + "DZ")),
        exact_int(prefix + "REVERSED", require_value(values, prefix + "REVERSED")),
    )
    if not (800 <= rail.minimum <= 2200 and 800 <= rail.trim <= 2200
            and 800 <= rail.maximum <= 2200):
        raise GuardError(f"{prefix} rail is outside 800..2200")
    if not (1 <= rail.dead_zone <= 200):
        raise GuardError(f"{prefix}DZ must be in 1..200")
    if rail.reversed not in (0, 1):
        raise GuardError(f"{prefix}REVERSED must be 0 or 1")
    if not (rail.minimum < rail.trim - rail.dead_zone
            < rail.trim + rail.dead_zone < rail.maximum):
        raise GuardError(f"{prefix} rail/dead-zone ordering is invalid")
    option = exact_int(prefix + "OPTION", require_value(values, prefix + "OPTION"))
    if option != 0:
        raise GuardError(f"{prefix}OPTION must be 0")
    return rail


def _servo_rail(values: Mapping[str, float], channel: int) -> ServoRail:
    prefix = f"SERVO{channel}_"
    rail = ServoRail(
        exact_int(prefix + "MIN", require_value(values, prefix + "MIN")),
        exact_int(prefix + "TRIM", require_value(values, prefix + "TRIM")),
        exact_int(prefix + "MAX", require_value(values, prefix + "MAX")),
        exact_int(prefix + "REVERSED", require_value(values, prefix + "REVERSED")),
    )
    if not all(800 <= value <= 2200 for value in (rail.minimum, rail.trim, rail.maximum)):
        raise GuardError(f"{prefix} rail is outside 800..2200")
    if not (rail.minimum < rail.maximum and rail.minimum <= rail.trim <= rail.maximum):
        raise GuardError(f"{prefix} rail ordering is invalid")
    if rail.reversed not in (0, 1):
        raise GuardError(f"{prefix}REVERSED must be 0 or 1")
    return rail


def resolve_guard(values: Mapping[str, float]) -> LiveGuard:
    steering, throttle, left, right = discover_channels(values)

    integer_expectations = {
        "SYSID_THISMAV": range(1, 256),
        "SYSID_MYGCS": range(1, 256),
        "SYSID_ENFORCE": (0,),
        "SERIAL1_PROTOCOL": (2,),
        "FRAME_CLASS": (2,),
        "PILOT_STEER_TYPE": (0,),
        "SCR_ENABLE": (0,),
        "SERVO_32_ENABLE": (0,),
        "BRD_SAFETY_DEFLT": (1,),
    }
    for name, allowed in integer_expectations.items():
        value = exact_int(name, require_value(values, name))
        if value not in allowed:
            raise GuardError(f"{name} has disallowed value {value}")

    if exact_int("SYSID_THISMAV", values["SYSID_THISMAV"]) == exact_int(
            "SYSID_MYGCS", values["SYSID_MYGCS"]):
        raise GuardError("SYSID_THISMAV and SYSID_MYGCS must differ")

    mode_channel = exact_int("MODE_CH", require_value(values, "MODE_CH"))
    if mode_channel in (steering, throttle):
        raise GuardError("a resolved RC ingress channel equals MODE_CH")

    rc_options = exact_int("RC_OPTIONS", require_value(values, "RC_OPTIONS"))
    if rc_options & 0b11:
        raise GuardError("RC_OPTIONS ignores receiver input or MAVLink overrides")
    for channel in range(1, 17):
        option = exact_int(
            f"RC{channel}_OPTION", require_value(values, f"RC{channel}_OPTION")
        )
        if option == 46:
            raise GuardError(f"RC{channel}_OPTION can clear all overrides")

    timeout = require_value(values, "RC_OVERRIDE_TIME")
    if not (0.0 < timeout <= 0.5):
        raise GuardError(f"RC_OVERRIDE_TIME must be in (0, 0.5], got {timeout}")

    for name in (
        "ARMING_CHECK", "ARMING_RUDDER", "ARMING_REQUIRE",
        "BRD_SAFETY_MASK", "BRD_SAFETYOPTION", "FS_THR_ENABLE",
        "FS_THR_VALUE", "FS_TIMEOUT", "FS_ACTION", "FS_OPTIONS",
        "FS_GCS_ENABLE", "FS_GCS_TIMEOUT",
    ):
        require_value(values, name)

    if "DDS_ENABLE" in values and exact_int("DDS_ENABLE", values["DDS_ENABLE"]) != 0:
        raise GuardError("DDS_ENABLE must be absent or 0")

    steering_rail = _rc_rail(values, steering)
    throttle_rail = _rc_rail(values, throttle)
    left_rail = _servo_rail(values, left)
    right_rail = _servo_rail(values, right)

    failsafe_enabled = exact_int("FS_THR_ENABLE", values["FS_THR_ENABLE"]) != 0
    if failsafe_enabled:
        failsafe_pwm = exact_int("FS_THR_VALUE", values["FS_THR_VALUE"])
        if throttle_rail.trim <= failsafe_pwm:
            raise GuardError("the permitted throttle range does not stay above FS_THR_VALUE")

    return LiveGuard(
        steering,
        throttle,
        left,
        right,
        steering_rail,
        throttle_rail,
        left_rail,
        right_rail,
        dict(values),
    )


def encode_axis(demand: float, rail: RcRail) -> int:
    if not math.isfinite(demand) or not -1.0 <= demand <= 1.0:
        raise ValueError("axis demand must be finite and within [-1, 1]")
    effective = -demand if rail.reversed else demand
    if effective == 0.0:
        return rail.trim
    if effective > 0.0:
        continuous = rail.trim + rail.dead_zone + effective * (
            rail.maximum - rail.trim - rail.dead_zone
        )
        return math.floor(continuous)
    continuous = rail.trim - rail.dead_zone + effective * (
        rail.trim - rail.dead_zone - rail.minimum
    )
    return math.ceil(continuous)


def override_channels(
    steering_channel: int,
    steering_pwm: int,
    throttle_channel: int,
    throttle_pwm: int,
) -> list[int]:
    channels = [NO_CHANGE] * 18
    channels[steering_channel - 1] = steering_pwm
    channels[throttle_channel - 1] = throttle_pwm
    return channels


def release_value(channel: int) -> int:
    return OverrideRCIn.CHAN_RELEASE if channel <= 8 else RELEASE_HIGH_CHANNEL


def command_stamp_ns(seconds: int, nanoseconds: int) -> int:
    seconds = exact_int("command stamp seconds", seconds)
    nanoseconds = exact_int("command stamp nanoseconds", nanoseconds)
    if seconds < 0 or not 0 <= nanoseconds < 1_000_000_000:
        raise GuardError("command timestamp is outside the ROS time domain")
    stamp = seconds * 1_000_000_000 + nanoseconds
    if stamp <= 0:
        raise GuardError("command timestamp must be non-zero")
    return stamp


def rc_input_is_neutral(channels: Sequence[int], guard: LiveGuard) -> bool:
    def channel_value(channel: int) -> Optional[int]:
        index = channel - 1
        if index < 0 or index >= len(channels):
            return None
        return int(channels[index])

    return (
        channel_value(guard.steering_channel) == guard.steering_rail.trim
        and channel_value(guard.throttle_channel) == guard.throttle_rail.trim
    )


def feedback_values_valid(
    guard: LiveGuard, rc_in: Sequence[int], rc_out: Sequence[int]
) -> bool:
    def value(channels: Sequence[int], channel: int) -> Optional[int]:
        index = channel - 1
        if index < 0 or index >= len(channels):
            return None
        return int(channels[index])

    steering = value(rc_in, guard.steering_channel)
    throttle = value(rc_in, guard.throttle_channel)
    left = value(rc_out, guard.left_servo)
    right = value(rc_out, guard.right_servo)
    if None in (steering, throttle, left, right):
        return False
    return (
        guard.steering_rail.minimum <= steering <= guard.steering_rail.maximum
        and guard.throttle_rail.minimum <= throttle <= guard.throttle_rail.maximum
        and guard.left_servo_rail.minimum <= left <= guard.left_servo_rail.maximum
        and guard.right_servo_rail.minimum <= right <= guard.right_servo_rail.maximum
    )


class RealFcuRcCommandBridge(Node):
    def __init__(self) -> None:
        super().__init__("real_fcu_rc_command_bridge")
        self.allow_real_fcu = bool(self.declare_parameter("allow_real_fcu", False).value)
        self.max_steering = float(self.declare_parameter("max_steering", 0.20).value)
        self.max_throttle = float(self.declare_parameter("max_throttle", 0.12).value)
        if not (0.0 < self.max_steering <= 0.20):
            raise GuardError("max_steering must be in (0, 0.20]")
        if not (0.0 < self.max_throttle <= 0.12):
            raise GuardError("max_throttle must be in (0, 0.12]")

        self.status_pub = self.create_publisher(String, STATUS_TOPIC, 10)
        self.guard: Optional[LiveGuard] = None
        self.fault = "INHIBITED"
        self.latest_state: Optional[State] = None
        self.latest_state_at = 0.0
        self.latest_rc_in: Sequence[int] = ()
        self.latest_rc_in_at = 0.0
        self.latest_rc_out: Sequence[int] = ()
        self.latest_rc_out_at = 0.0
        self.last_command_at = 0.0
        self.last_command_stamp_ns = 0
        self.last_command = (0.0, 0.0, False)
        self.disarmed_ready = False
        self.arm_epoch_authorized = False
        self.startup_armed = False
        self.has_armed_epoch = False
        self.armed_enable_primed = False
        self.emergency_stop_latched = False
        self.override_pub = None
        self.release_frames_remaining = 0

        self.create_subscription(State, "/mavros/state", self._state_cb, 10)
        self.create_subscription(RCIn, "/mavros/rc/in", self._rc_in_cb, 10)
        self.create_subscription(RCOut, "/mavros/rc/out", self._rc_out_cb, 10)

        if not self.allow_real_fcu:
            self.get_logger().warning("real-FCU output inhibited; set allow_real_fcu:=true explicitly")
            self.timer = self.create_timer(PUBLISH_PERIOD_SECONDS, self._tick)
            return
        if os.environ.get("ROS_DOMAIN_ID") != EXPECTED_DOMAIN_ID:
            raise GuardError(f"ROS_DOMAIN_ID must be {EXPECTED_DOMAIN_ID}")

        self.guard = self._resolve_live_guard()
        self.override_pub = self.create_publisher(OverrideRCIn, OVERRIDE_TOPIC, 10)
        command_qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
        self.create_subscription(Joy, COMMAND_TOPIC, self._command_cb, command_qos)
        self.create_subscription(
            Bool, "/planning/emergency_stop", self._emergency_cb, 10
        )
        self.fault = "WAITING_DISARMED_MANUAL"
        self.timer = self.create_timer(PUBLISH_PERIOD_SECONDS, self._tick)

    def _refresh_parameter_cache(self, client) -> None:
        request = ParamPull.Request()
        request.force_pull = True
        future = client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=5.0)
        if not future.done() or future.result() is None or not future.result().success:
            raise GuardError("MAVROS did not complete a live parameter pull")

    def _pull(
        self,
        client: AsyncParameterClient,
        names: Iterable[str],
        optional: Iterable[str] = (),
    ) -> Dict[str, float]:
        requested = list(names)
        optional_names = set(optional)
        future = client.get_parameters(requested)
        rclpy.spin_until_future_complete(self, future, timeout_sec=5.0)
        if not future.done() or future.result() is None:
            raise GuardError("MAVROS ROS parameter request did not complete")
        response_values = future.result().values
        if len(response_values) != len(requested):
            raise GuardError("MAVROS ROS parameter response is incomplete")
        resolved: Dict[str, float] = {}
        for name, value in zip(requested, response_values):
            decoded = decode_parameter_value(
                name,
                value,
                required=name not in optional_names,
            )
            if decoded is not None:
                resolved[name] = decoded
        return resolved

    def _resolve_live_guard(self) -> LiveGuard:
        parameter_client = AsyncParameterClient(self, PARAM_NODE)
        if not parameter_client.wait_for_services(timeout_sec=10.0):
            raise GuardError(
                f"MAVROS ROS parameter services unavailable: {PARAM_NODE}"
            )
        pull_client = self.create_client(ParamPull, PARAM_PULL_SERVICE)
        if not pull_client.wait_for_service(timeout_sec=10.0):
            raise GuardError(
                f"MAVROS parameter pull service unavailable: {PARAM_PULL_SERVICE}"
            )

        base_names = {
            "SYSID_THISMAV", "SYSID_MYGCS", "SYSID_ENFORCE", "SERIAL1_PROTOCOL",
            "BRD_SAFETY_DEFLT", "BRD_SAFETY_MASK", "BRD_SAFETYOPTION",
            "ARMING_CHECK", "ARMING_RUDDER", "ARMING_REQUIRE", "FRAME_CLASS",
            "PILOT_STEER_TYPE", "MODE_CH", "RC_OPTIONS", "RC_OVERRIDE_TIME",
            "RCMAP_ROLL", "RCMAP_THROTTLE", "SCR_ENABLE", "SERVO_32_ENABLE",
            "FS_THR_ENABLE", "FS_THR_VALUE", "FS_TIMEOUT", "FS_ACTION",
            "FS_OPTIONS", "FS_GCS_ENABLE", "FS_GCS_TIMEOUT",
        }
        base_names.update(f"RC{channel}_OPTION" for channel in range(1, 17))
        base_names.update(f"SERVO{channel}_FUNCTION" for channel in range(1, 17))
        self._refresh_parameter_cache(pull_client)
        discovery = self._pull(parameter_client, sorted(base_names))
        steering, throttle, left, right = discover_channels(discovery)

        dynamic_names = set(base_names)
        for channel in (steering, throttle):
            dynamic_names.update(
                f"RC{channel}_{suffix}"
                for suffix in ("MIN", "TRIM", "MAX", "DZ", "REVERSED", "OPTION")
            )
        for channel in (left, right):
            dynamic_names.update(
                f"SERVO{channel}_{suffix}"
                for suffix in ("MIN", "TRIM", "MAX", "REVERSED")
            )
        dynamic_names.add("DDS_ENABLE")

        self._refresh_parameter_cache(pull_client)
        first = self._pull(
            parameter_client,
            sorted(dynamic_names),
            optional=("DDS_ENABLE",),
        )
        self._refresh_parameter_cache(pull_client)
        second = self._pull(
            parameter_client,
            sorted(dynamic_names),
            optional=("DDS_ENABLE",),
        )
        if first != second:
            raise GuardError("two complete live parameter rounds differ")
        guard = resolve_guard(second)
        self.get_logger().info(
            f"live guard resolved: steering=RC{guard.steering_channel} "
            f"throttle=RC{guard.throttle_channel} left=SERVO{guard.left_servo} "
            f"right=SERVO{guard.right_servo}"
        )
        return guard

    def _state_cb(self, message: State) -> None:
        now = time.monotonic()
        was_armed = bool(self.latest_state and self.latest_state.armed)
        if self.latest_state is None and message.armed:
            self.startup_armed = True
            self.fault = "STARTUP_ARMED"
        if message.armed and not was_armed:
            self.has_armed_epoch = True
            self.arm_epoch_authorized = bool(
                self.disarmed_ready
                and self.guard is not None
                and self.latest_rc_in_at > 0.0
                and now - self.latest_rc_in_at < FEEDBACK_TIMEOUT_SECONDS
                and rc_input_is_neutral(self.latest_rc_in, self.guard)
            )
            self.disarmed_ready = False
            self.armed_enable_primed = False
            self.last_command = (0.0, 0.0, False)
            self.last_command_at = 0.0
        elif was_armed and not message.armed:
            self.arm_epoch_authorized = False
            self.disarmed_ready = False
            self.armed_enable_primed = False
            self.last_command = (0.0, 0.0, False)
            self.last_command_at = 0.0
            self.release_frames_remaining = 3
        self.latest_state = message
        self.latest_state_at = now
        if not message.connected:
            self.fault = "FCU_DISCONNECTED"
        elif self.startup_armed:
            self.fault = "STARTUP_ARMED"
        elif message.mode != "MANUAL" and message.armed:
            self.fault = "MODE_FAULT"

    def _rc_in_cb(self, message: RCIn) -> None:
        self.latest_rc_in = tuple(message.channels)
        self.latest_rc_in_at = time.monotonic()
        if self.guard is not None and self.latest_state is not None \
                and not self.latest_state.armed:
            self.disarmed_ready = rc_input_is_neutral(
                self.latest_rc_in, self.guard
            )

    def _rc_out_cb(self, message: RCOut) -> None:
        self.latest_rc_out = tuple(message.channels)
        self.latest_rc_out_at = time.monotonic()

    def _command_cb(self, message: Joy) -> None:
        if self.emergency_stop_latched:
            self.fault = "EMERGENCY_STOP"
            return
        if message.header.frame_id != FRAME_ID:
            self.fault = "INVALID_COMMAND_FRAME"
            return
        try:
            stamp_ns = command_stamp_ns(
                message.header.stamp.sec, message.header.stamp.nanosec
            )
        except GuardError:
            self.fault = "INVALID_COMMAND_TIMESTAMP"
            return
        if stamp_ns <= self.last_command_stamp_ns:
            self.fault = "NON_MONOTONIC_COMMAND_TIMESTAMP"
            return
        if len(message.axes) != 2 or len(message.buttons) != 1:
            self.fault = "INVALID_COMMAND_SHAPE"
            return
        steering, throttle = (float(message.axes[0]), float(message.axes[1]))
        enable = message.buttons[0]
        if not (math.isfinite(steering) and math.isfinite(throttle)):
            self.fault = "INVALID_COMMAND_VALUE"
            return
        if not (-self.max_steering <= steering <= self.max_steering
                and 0.0 <= throttle <= self.max_throttle and enable in (0, 1)):
            self.fault = "COMMAND_OUT_OF_BOUNDS"
            return
        vehicle_armed = bool(self.latest_state and self.latest_state.armed)
        if vehicle_armed and enable == 0:
            self.armed_enable_primed = True
        elif enable == 1 and not self.armed_enable_primed:
            self.fault = "ENABLE_RESET_REQUIRED"
            return
        self.last_command_stamp_ns = stamp_ns
        self.last_command = (steering, throttle, enable == 1)
        self.last_command_at = time.monotonic()

    def _emergency_cb(self, message: Bool) -> None:
        if not message.data:
            return
        self.emergency_stop_latched = True
        self.armed_enable_primed = False
        self.last_command = (0.0, 0.0, False)
        self.last_command_at = 0.0
        self.fault = "EMERGENCY_STOP"
        if self.guard is not None and self.latest_state is not None \
                and self.latest_state.armed:
            self._publish_pair(
                self.guard.steering_rail.trim,
                self.guard.throttle_rail.trim,
            )

    def _publish_pair(self, steering_pwm: int, throttle_pwm: int) -> None:
        if self.override_pub is None or self.guard is None:
            return
        message = OverrideRCIn()
        message.channels = override_channels(
            self.guard.steering_channel,
            steering_pwm,
            self.guard.throttle_channel,
            throttle_pwm,
        )
        self.override_pub.publish(message)

    def _publish_release(self) -> None:
        if self.override_pub is None or self.guard is None:
            return
        self._publish_pair(
            release_value(self.guard.steering_channel),
            release_value(self.guard.throttle_channel),
        )

    def _feedback_value(self, channels: Sequence[int], channel: int) -> Optional[int]:
        index = channel - 1
        if index < 0 or index >= len(channels):
            return None
        return int(channels[index])

    def _publish_status(self, state: str, steering: float, throttle: float) -> None:
        guard = self.guard
        now = time.monotonic()
        rc_in_age_ms = (
            round((now - self.latest_rc_in_at) * 1000)
            if self.latest_rc_in_at else None
        )
        rc_out_age_ms = (
            round((now - self.latest_rc_out_at) * 1000)
            if self.latest_rc_out_at else None
        )
        payload = {
            "state": state,
            "fault": self.fault,
            "ready": state in ("READY_DISARMED", "ARMED_NEUTRAL", "ACTIVE"),
            "connected": bool(self.latest_state and self.latest_state.connected),
            "armed": bool(self.latest_state and self.latest_state.armed),
            "mode": self.latest_state.mode if self.latest_state else "",
            "command": {"steering": steering, "throttle": throttle},
            "feedback_fresh": bool(
                guard is not None
                and rc_in_age_ms is not None
                and rc_out_age_ms is not None
                and rc_in_age_ms < FEEDBACK_TIMEOUT_SECONDS * 1000
                and rc_out_age_ms < FEEDBACK_TIMEOUT_SECONDS * 1000
                and feedback_values_valid(
                    guard, self.latest_rc_in, self.latest_rc_out
                )
            ),
            "rc_in_age_ms": rc_in_age_ms,
            "rc_out_age_ms": rc_out_age_ms,
            "resolved": None,
            "measured": None,
        }
        if guard:
            payload["resolved"] = {
                "steering_rc": guard.steering_channel,
                "throttle_rc": guard.throttle_channel,
                "left_servo": guard.left_servo,
                "right_servo": guard.right_servo,
            }
            payload["measured"] = {
                "rc_steering_pwm": self._feedback_value(
                    self.latest_rc_in, guard.steering_channel
                ),
                "rc_throttle_pwm": self._feedback_value(
                    self.latest_rc_in, guard.throttle_channel
                ),
                "left_servo_pwm": self._feedback_value(
                    self.latest_rc_out, guard.left_servo
                ),
                "right_servo_pwm": self._feedback_value(
                    self.latest_rc_out, guard.right_servo
                ),
            }
        message = String()
        message.data = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        self.status_pub.publish(message)

    def _tick(self) -> None:
        steering = 0.0
        throttle = 0.0
        state = self.fault
        now = time.monotonic()
        vehicle = self.latest_state
        guard = self.guard

        if guard is None or not self.allow_real_fcu:
            self._publish_status(state, steering, throttle)
            return
        if vehicle is None or now - self.latest_state_at >= STATE_TIMEOUT_SECONDS:
            self.fault = "STATE_STALE"
            if vehicle is not None and vehicle.armed:
                self._publish_pair(
                    guard.steering_rail.trim, guard.throttle_rail.trim
                )
            self._publish_status(self.fault, steering, throttle)
            return
        if self.startup_armed:
            self.fault = "STARTUP_ARMED"
            self._publish_status(self.fault, steering, throttle)
            return
        if self.emergency_stop_latched:
            self.fault = "EMERGENCY_STOP"
            if vehicle.armed:
                self._publish_pair(
                    guard.steering_rail.trim, guard.throttle_rail.trim
                )
            elif self.release_frames_remaining > 0:
                self._publish_release()
                self.release_frames_remaining -= 1
            self._publish_status(self.fault, steering, throttle)
            return

        if not vehicle.armed:
            rc_input_ready = (
                vehicle.mode == "MANUAL"
                and self.latest_rc_in_at > 0.0
                and now - self.latest_rc_in_at < FEEDBACK_TIMEOUT_SECONDS
                and rc_input_is_neutral(self.latest_rc_in, guard)
            )
            self.disarmed_ready = rc_input_ready
            if rc_input_ready:
                state = "READY_DISARMED"
            else:
                state = (
                    "WAITING_DISARMED_MANUAL"
                    if vehicle.mode != "MANUAL"
                    else "WAITING_DISARMED_NEUTRAL_RC"
                )
            if self.has_armed_epoch and self.release_frames_remaining > 0:
                self._publish_release()
                self.release_frames_remaining -= 1
        elif not self.arm_epoch_authorized:
            state = "ARMED_BEFORE_READY"
            self.fault = state
        elif vehicle.mode != "MANUAL":
            state = "MODE_FAULT"
            self.fault = state
            self._publish_pair(guard.steering_rail.trim, guard.throttle_rail.trim)
        else:
            fresh = now - self.last_command_at < COMMAND_TIMEOUT_SECONDS
            feedback_fresh = (
                self.latest_rc_in_at > 0.0
                and now - self.latest_rc_in_at < FEEDBACK_TIMEOUT_SECONDS
                and self.latest_rc_out_at > 0.0
                and now - self.latest_rc_out_at < FEEDBACK_TIMEOUT_SECONDS
                and feedback_values_valid(
                    guard, self.latest_rc_in, self.latest_rc_out
                )
            )
            requested_steering, requested_throttle, enabled = self.last_command
            if not feedback_fresh:
                state = "FEEDBACK_INVALID"
            elif (fresh and enabled and self.armed_enable_primed
                    and self.count_publishers(COMMAND_TOPIC) == 1):
                steering = requested_steering
                throttle = requested_throttle
                state = "ACTIVE"
            else:
                state = "ARMED_NEUTRAL"
            self._publish_pair(
                encode_axis(steering, guard.steering_rail),
                encode_axis(throttle, guard.throttle_rail),
            )
        self.fault = state
        self._publish_status(state, steering, throttle)

    def neutralize_for_shutdown(self) -> None:
        if self.guard is None or self.override_pub is None:
            return
        vehicle = self.latest_state
        for _ in range(3):
            if vehicle is not None and vehicle.armed:
                self._publish_pair(
                    self.guard.steering_rail.trim,
                    self.guard.throttle_rail.trim,
                )
            else:
                self._publish_release()
            time.sleep(PUBLISH_PERIOD_SECONDS)


def main(args: Optional[Sequence[str]] = None) -> None:
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    rclpy.init(args=args, signal_handler_options=SignalHandlerOptions.NO)
    node: Optional[RealFcuRcCommandBridge] = None
    try:
        node = RealFcuRcCommandBridge()
        rclpy.spin(node)
    except GuardError as exc:
        if node is not None:
            node.get_logger().error(str(exc))
        else:
            print(f"real_fcu_rc_command_bridge: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
    except KeyboardInterrupt:
        pass
    finally:
        if node is not None:
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            signal.signal(signal.SIGTERM, signal.SIG_IGN)
            node.timer.cancel()
            node.neutralize_for_shutdown()
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
