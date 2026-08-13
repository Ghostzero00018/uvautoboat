#!/usr/bin/env python3
"""Capture and evaluate non-commanding evidence for the guarded SITL thrust loop."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import sys
import time
from typing import Any, Iterable, Mapping, Optional, Sequence

import rclpy
from mavros_msgs.msg import OverrideRCIn, State
from mavros_msgs.srv import ParamPull
from rclpy.node import Node
from rclpy.parameter_client import AsyncParameterClient
from rclpy.signals import SignalHandlerOptions
from rosidl_runtime_py.convert import message_to_ordereddict
from sensor_msgs.msg import Joy
from std_msgs.msg import Bool, String

from real_fcu_rc_command_bridge import (
    PARAM_NODE,
    PARAM_PULL_SERVICE,
    GuardError,
    decode_parameter_value,
    discover_channels,
    release_value,
    resolve_guard,
)


SCHEMA = "uvautoboat.sitl.evidence.v1"
EXPECTED_DOMAIN_ID = "42"
EXPECTED_DISCOVERY_RANGE = "LOCALHOST"
EXPECTED_LOCALHOST_ONLY = "1"
EXPECTED_PARAMETER_COUNT = 1283
FRAME_ID = "uvautoboat/rc_axes/v1"

TOPICS = {
    "/command_ingress/rc_axes": (Joy, "rc_axes.jsonl"),
    "/command_ingress/status": (String, "status.jsonl"),
    "/planning/emergency_stop": (Bool, "emergency_stop.jsonl"),
    "/mavros/rc/override": (OverrideRCIn, "override.jsonl"),
    "/mavros/state": (State, "mavros_state.jsonl"),
}

PHASE_FILES = (
    "startup.json",
    "ready_disarmed.json",
    "browser_ready.json",
    "arm.json",
    "positive.json",
    "release.json",
    "negative.json",
    "estop.json",
    "disarm.json",
    "teardown.json",
)


class EvidenceError(RuntimeError):
    """Raised when captured state cannot satisfy the evidence contract."""


def atomic_write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    encoded = json.dumps(
        dict(payload), allow_nan=False, separators=(",", ":"), sort_keys=True
    )
    with temporary.open("x", encoding="utf-8") as stream:
        stream.write(encoded)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def read_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"cannot read JSON evidence: {path}") from exc
    if not isinstance(payload, dict):
        raise EvidenceError(f"JSON evidence is not an object: {path}")
    return payload


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _exact_int(name: str, value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise EvidenceError(f"{name} is not numeric")
    converted = int(value)
    if float(value) != float(converted):
        raise EvidenceError(f"{name} is not an exact integer")
    return converted


def _finite_float(name: str, value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise EvidenceError(f"{name} is not numeric")
    converted = float(value)
    if not math.isfinite(converted):
        raise EvidenceError(f"{name} is not finite")
    return converted


def validate_ros_environment() -> dict[str, str]:
    expected = {
        "ROS_DOMAIN_ID": EXPECTED_DOMAIN_ID,
        "ROS_AUTOMATIC_DISCOVERY_RANGE": EXPECTED_DISCOVERY_RANGE,
        "ROS_LOCALHOST_ONLY": EXPECTED_LOCALHOST_ONLY,
    }
    for name, value in expected.items():
        if os.environ.get(name) != value:
            raise EvidenceError(f"{name} must be {value}")
    forbidden = (
        "ROS_STATIC_PEERS",
        "ROS_DISCOVERY_SERVER",
        "RMW_IMPLEMENTATION",
        "FASTDDS_DEFAULT_PROFILES_FILE",
        "FASTRTPS_DEFAULT_PROFILES_FILE",
        "CYCLONEDDS_URI",
    )
    inherited = [name for name in forbidden if os.environ.get(name)]
    if inherited:
        raise EvidenceError(f"forbidden ROS selector remains set: {inherited[0]}")
    return expected


def base_parameter_names() -> set[str]:
    names = {
        "SYSID_THISMAV", "SYSID_MYGCS", "SYSID_ENFORCE",
        "SERIAL0_PROTOCOL", "SERIAL1_PROTOCOL", "SIM_SPEEDUP", "SIM_RATE_HZ",
        "BRD_SAFETY_DEFLT", "BRD_SAFETY_MASK", "BRD_SAFETYOPTION",
        "ARMING_CHECK", "ARMING_RUDDER", "ARMING_REQUIRE", "FRAME_CLASS",
        "PILOT_STEER_TYPE", "MODE_CH", "RC_OPTIONS", "RC_OVERRIDE_TIME",
        "RCMAP_ROLL", "RCMAP_THROTTLE", "SCR_ENABLE", "SERVO_32_ENABLE",
        "FS_THR_ENABLE", "FS_THR_VALUE", "FS_TIMEOUT", "FS_ACTION",
        "FS_OPTIONS", "FS_GCS_ENABLE", "FS_GCS_TIMEOUT",
    }
    names.update(f"RC{channel}_OPTION" for channel in range(1, 17))
    names.update(f"SERVO{channel}_FUNCTION" for channel in range(1, 17))
    return names


def dynamic_parameter_names(values: Mapping[str, float]) -> set[str]:
    steering, throttle, left, right = discover_channels(values)
    names = base_parameter_names()
    for channel in (steering, throttle):
        names.update(
            f"RC{channel}_{suffix}"
            for suffix in ("MIN", "TRIM", "MAX", "DZ", "REVERSED", "OPTION")
        )
    for channel in (left, right):
        names.update(
            f"SERVO{channel}_{suffix}"
            for suffix in ("MIN", "TRIM", "MAX", "REVERSED")
        )
    names.add("DDS_ENABLE")
    return names


def validate_snapshot_values(values: Mapping[str, float], parameter_count: int) -> Any:
    if parameter_count != EXPECTED_PARAMETER_COUNT:
        raise EvidenceError(
            f"parameter count is {parameter_count}, expected {EXPECTED_PARAMETER_COUNT}"
        )
    exact = {
        "SYSID_THISMAV": 1,
        "SYSID_MYGCS": 255,
        "SERIAL0_PROTOCOL": 2,
        "SERIAL1_PROTOCOL": 2,
        "SIM_SPEEDUP": 1,
        "ARMING_RUDDER": 0,
        "BRD_SAFETY_DEFLT": 1,
    }
    for name, expected in exact.items():
        actual = _exact_int(name, values.get(name))
        if actual != expected:
            raise EvidenceError(f"{name} is {actual}, expected {expected}")
    timeout = _finite_float("RC_OVERRIDE_TIME", values.get("RC_OVERRIDE_TIME"))
    if timeout != 0.5:
        raise EvidenceError(f"RC_OVERRIDE_TIME is {timeout}, expected 0.5")
    if _finite_float("SIM_RATE_HZ", values.get("SIM_RATE_HZ")) <= 0.0:
        raise EvidenceError("SIM_RATE_HZ must be positive")
    try:
        return resolve_guard(values)
    except GuardError as exc:
        raise EvidenceError(str(exc)) from exc


class SnapshotNode(Node):
    """Request live MAVROS parameters without publishing commands or changing values."""

    def __init__(self) -> None:
        super().__init__("sitl_digital_twin_snapshot")
        self.latest_state: Optional[State] = None
        self.create_subscription(State, "/mavros/state", self._state_cb, 10)
        self.parameter_client = AsyncParameterClient(self, PARAM_NODE)
        self.pull_client = self.create_client(ParamPull, PARAM_PULL_SERVICE)

    def _state_cb(self, message: State) -> None:
        self.latest_state = message

    def wait_for_disarmed_manual(self, timeout_seconds: float) -> State:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=min(0.2, deadline - time.monotonic()))
            state = self.latest_state
            if state and state.connected:
                if state.armed:
                    raise EvidenceError("MAVROS reported an already-armed startup")
                if state.mode != "MANUAL":
                    raise EvidenceError(f"MAVROS startup mode is {state.mode}, expected MANUAL")
                return state
        raise EvidenceError("fresh connected MAVROS state was not received")

    def _refresh_parameters(self, timeout_seconds: float) -> int:
        if not self.pull_client.wait_for_service(timeout_sec=timeout_seconds):
            raise EvidenceError(f"MAVROS pull service unavailable: {PARAM_PULL_SERVICE}")
        request = ParamPull.Request()
        request.force_pull = True
        future = self.pull_client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=timeout_seconds)
        if not future.done() or future.result() is None or not future.result().success:
            raise EvidenceError("MAVROS did not complete a live parameter pull")
        return int(future.result().param_received)

    def _get_parameters(
        self,
        names: Sequence[str],
        timeout_seconds: float,
        optional: Iterable[str] = (),
    ) -> dict[str, float]:
        if not self.parameter_client.wait_for_services(timeout_sec=timeout_seconds):
            raise EvidenceError(f"MAVROS parameter services unavailable: {PARAM_NODE}")
        future = self.parameter_client.get_parameters(list(names))
        rclpy.spin_until_future_complete(self, future, timeout_sec=timeout_seconds)
        if not future.done() or future.result() is None:
            raise EvidenceError("MAVROS ROS parameter read did not complete")
        response = future.result().values
        if len(response) != len(names):
            raise EvidenceError("MAVROS ROS parameter response is incomplete")
        optional_names = set(optional)
        decoded: dict[str, float] = {}
        for name, value in zip(names, response):
            try:
                numeric = decode_parameter_value(
                    name, value, required=name not in optional_names
                )
            except GuardError as exc:
                raise EvidenceError(str(exc)) from exc
            if numeric is not None:
                decoded[name] = numeric
        return decoded

    def take_snapshot(self, timeout_seconds: float) -> dict[str, Any]:
        state = self.wait_for_disarmed_manual(timeout_seconds)
        count = self._refresh_parameters(timeout_seconds)
        base_names = sorted(base_parameter_names())
        discovery = self._get_parameters(base_names, timeout_seconds)
        names = sorted(dynamic_parameter_names(discovery))
        count = self._refresh_parameters(timeout_seconds)
        first = self._get_parameters(names, timeout_seconds, optional=("DDS_ENABLE",))
        count = self._refresh_parameters(timeout_seconds)
        second = self._get_parameters(names, timeout_seconds, optional=("DDS_ENABLE",))
        if first != second:
            raise EvidenceError("two complete MAVROS parameter rounds differ")
        guard = validate_snapshot_values(second, count)
        return {
            "schema": SCHEMA,
            "captured_unix_ns": time.time_ns(),
            "environment": validate_ros_environment(),
            "mavros_state": {
                "connected": bool(state.connected),
                "armed": bool(state.armed),
                "mode": str(state.mode),
                "system_status": int(state.system_status),
            },
            "parameter_count": count,
            "parameters": dict(sorted(second.items())),
            "guard": asdict(guard),
        }


def run_snapshot(run_dir: Path, timeout_seconds: float) -> int:
    validate_ros_environment()
    rclpy.init(args=[], signal_handler_options=SignalHandlerOptions.NO)
    node: Optional[SnapshotNode] = None
    try:
        node = SnapshotNode()
        snapshot = node.take_snapshot(timeout_seconds)
        path = run_dir / "manifest" / "mavros_snapshot.json"
        atomic_write_json(path, snapshot)
        print(
            f"SITL_MAVROS=READY parameters={snapshot['parameter_count']} "
            f"state=disarmed mode=MANUAL snapshot={path}",
            flush=True,
        )
        return 0
    finally:
        if node is not None:
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


def normalized_servo_demand(value: Any, rail: Mapping[str, Any]) -> float:
    pwm = _exact_int("servo PWM", value)
    minimum = _exact_int("servo minimum", rail.get("minimum"))
    trim = _exact_int("servo trim", rail.get("trim"))
    maximum = _exact_int("servo maximum", rail.get("maximum"))
    reversed_flag = _exact_int("servo reversed", rail.get("reversed"))
    if not minimum < trim < maximum or reversed_flag not in (0, 1):
        raise EvidenceError("servo rail is invalid")
    if not minimum <= pwm <= maximum:
        raise EvidenceError("servo PWM is outside its live rail")
    if pwm >= trim:
        demand = (pwm - trim) / (maximum - trim)
    else:
        demand = (pwm - trim) / (trim - minimum)
    return -demand if reversed_flag else demand


def _event_time(event: Optional[Mapping[str, Any]]) -> int:
    return int(event.get("received_unix_ns", 0)) if event else 0


# Command demands reach this recorder as float32 and are read back widened.
# `sensor_msgs/Joy.axes` is `float32[]`, so a dashboard demand of 0.10 arrives
# as 0.10000000149011612, and the bridge copies that same quantised value into
# its status JSON. A tolerance tighter than float32 rounding can therefore never
# match a real frame: 0.10, 0.08 and 0.09 miss by 1.5e-9, 1.8e-9 and 3.6e-9.
#
# 1e-6 is above that noise and still four orders of magnitude below the 0.01
# slider step, so an adjacent slider position remains distinguishable.
FLOAT32_COMMAND_TOLERANCE = 1e-6


def _close_float(actual: Any, expected: float) -> bool:
    try:
        return math.isclose(
            float(actual),
            expected,
            rel_tol=0.0,
            abs_tol=FLOAT32_COMMAND_TOLERANCE,
        )
    except (TypeError, ValueError):
        return False


class EvidenceTracker:
    """Turn ordered subscriber messages into phase-specific atomic evidence."""

    def __init__(self, run_dir: Path, snapshot: Mapping[str, Any]) -> None:
        self.run_dir = run_dir
        self.snapshot = dict(snapshot)
        self.guard = dict(self.snapshot["guard"])
        self.evidence_dir = run_dir / "evidence"
        self.control_dir = run_dir / "control"
        self.latest: dict[str, dict[str, Any]] = {}
        self.histories: dict[str, list[dict[str, Any]]] = {
            topic: [] for topic in TOPICS
        }
        self.command_publisher_count = 0
        self.new_markers: list[str] = []

    def _fault(self, reason: str) -> None:
        path = self.control_dir / "capture_fault.json"
        if not path.exists():
            atomic_write_json(
                path,
                {
                    "schema": SCHEMA,
                    "captured_unix_ns": time.time_ns(),
                    "reason": reason,
                },
            )
            self.new_markers.append(f"SITL_CAPTURE_FAULT reason={reason}")

    def _emit(self, filename: str, payload: Mapping[str, Any]) -> None:
        path = self.evidence_dir / filename
        if path.exists():
            return
        complete = {
            "schema": SCHEMA,
            "phase": filename.removesuffix(".json"),
            "captured_unix_ns": time.time_ns(),
            **dict(payload),
        }
        atomic_write_json(path, complete)
        self.new_markers.append(
            f"SITL_EVIDENCE=PASS phase={complete['phase']} path={path}"
        )

    def _operator(self, action: str) -> Optional[dict[str, Any]]:
        path = self.run_dir / "operator" / f"{action}.json"
        if not path.exists():
            return None
        try:
            result = read_json(path)
        except EvidenceError as exc:
            self._fault(str(exc).replace(" ", "_"))
            return None
        if result.get("action") != action or result.get("success") is not True:
            self._fault(f"operator_{action}_failed")
            return None
        return result

    def _operator_sent_time(self, action: str) -> int:
        result = self._operator(action)
        if result is None:
            return 0
        observation = result.get("observation")
        if not isinstance(observation, dict):
            return 0
        return int(observation.get("sent_unix_ns", 0))

    def _status(self) -> Optional[dict[str, Any]]:
        event = self.latest.get("/command_ingress/status")
        if not event:
            return None
        decoded = event.get("decoded")
        return decoded if isinstance(decoded, dict) else None

    def _mapping_matches(self, status: Mapping[str, Any]) -> bool:
        resolved = status.get("resolved")
        if not isinstance(resolved, dict):
            return False
        return resolved == {
            "steering_rc": self.guard["steering_channel"],
            "throttle_rc": self.guard["throttle_channel"],
            "left_servo": self.guard["left_servo"],
            "right_servo": self.guard["right_servo"],
        }

    def _measured_neutral(self, status: Mapping[str, Any]) -> bool:
        measured = status.get("measured")
        if not isinstance(measured, dict):
            return False
        return (
            measured.get("rc_steering_pwm") == self.guard["steering_rail"]["trim"]
            and measured.get("rc_throttle_pwm") == self.guard["throttle_rail"]["trim"]
            and measured.get("left_servo_pwm") == self.guard["left_servo_rail"]["trim"]
            and measured.get("right_servo_pwm") == self.guard["right_servo_rail"]["trim"]
        )

    def _state_after(self, armed: bool, threshold_ns: int) -> Optional[dict[str, Any]]:
        for event in reversed(self.histories["/mavros/state"]):
            message = event["message"]
            if (
                _event_time(event) >= threshold_ns
                and message.get("connected") is True
                and message.get("mode") == "MANUAL"
                and bool(message.get("armed")) == armed
            ):
                return event
        return None

    def _joy_matches(self, steering: float, throttle: float, enabled: bool) -> bool:
        event = self.latest.get("/command_ingress/rc_axes")
        if not event:
            return False
        message = event["message"]
        axes = message.get("axes")
        buttons = message.get("buttons")
        header = message.get("header")
        return (
            isinstance(header, dict)
            and header.get("frame_id") == FRAME_ID
            and isinstance(axes, list)
            and len(axes) == 2
            and _close_float(axes[0], steering)
            and _close_float(axes[1], throttle)
            and buttons == [1 if enabled else 0]
        )

    def _manifest_hashes(self) -> dict[str, str]:
        hashes = {}
        manifest_dir = self.run_dir / "manifest"
        for path in sorted(manifest_dir.iterdir()):
            if path.is_file():
                hashes[str(path.relative_to(self.run_dir))] = sha256_file(path)
        return hashes

    def ingest(self, topic: str, message: Mapping[str, Any], received_unix_ns: int) -> None:
        event: dict[str, Any] = {
            "schema": SCHEMA,
            "topic": topic,
            "received_unix_ns": received_unix_ns,
            "received_monotonic_ns": time.monotonic_ns(),
            "message": dict(message),
        }
        if topic == "/command_ingress/status":
            raw = message.get("data")
            try:
                decoded = json.loads(raw) if isinstance(raw, str) else None
            except json.JSONDecodeError:
                decoded = None
            if not isinstance(decoded, dict):
                self._fault("invalid_bridge_status_json")
            else:
                event["decoded"] = decoded
                if decoded.get("resolved") is not None and not self._mapping_matches(decoded):
                    self._fault("bridge_mapping_drift")
        self.latest[topic] = event
        history = self.histories[topic]
        history.append(event)
        if len(history) > 256:
            del history[:-256]
        self.evaluate()

    def set_command_publisher_count(self, count: int) -> None:
        self.command_publisher_count = count
        if count > 1:
            self._fault("multiple_command_publishers")
        self.evaluate()

    def evaluate(self) -> None:
        status_event = self.latest.get("/command_ingress/status")
        status = self._status()
        state_event = self.latest.get("/mavros/state")

        if status and self._mapping_matches(status):
            self._emit(
                "startup.json",
                {
                    "repository_manifest_sha256": self._manifest_hashes(),
                    "mavros_snapshot": self.snapshot,
                    "bridge_status": status_event,
                },
            )

        safety_sent = self._operator_sent_time("safety-off")
        if (
            safety_sent
            and status
            and _event_time(status_event) >= safety_sent
            and _event_time(state_event) >= safety_sent
            and status.get("state") == "READY_DISARMED"
            and status.get("connected") is True
            and status.get("armed") is False
            and status.get("mode") == "MANUAL"
            and status.get("feedback_fresh") is True
            and self._measured_neutral(status)
            and state_event
            and state_event["message"].get("armed") is False
        ):
            self._emit(
                "ready_disarmed.json",
                {
                    "operator": self._operator("safety-off"),
                    "bridge_status": status_event,
                    "mavros_state": state_event,
                },
            )

        if (
            (self.evidence_dir / "ready_disarmed.json").exists()
            and self.command_publisher_count == 1
            and self._joy_matches(0.0, 0.0, False)
        ):
            self._emit(
                "browser_ready.json",
                {
                    "command_publisher_count": self.command_publisher_count,
                    "disabled_frame": self.latest["/command_ingress/rc_axes"],
                },
            )

        arm_sent = self._operator_sent_time("arm")
        armed_state = self._state_after(True, arm_sent) if arm_sent else None
        if (
            arm_sent
            and (self.evidence_dir / "browser_ready.json").exists()
            and status
            and _event_time(status_event) >= arm_sent
            and status.get("state") == "ARMED_NEUTRAL"
            and status.get("armed") is True
            and status.get("mode") == "MANUAL"
            and status.get("feedback_fresh") is True
            and self._measured_neutral(status)
            and armed_state is not None
        ):
            self._emit(
                "arm.json",
                {
                    "operator": self._operator("arm"),
                    "bridge_status": status_event,
                    "mavros_state": armed_state,
                },
            )

        if (
            (self.evidence_dir / "arm.json").exists()
            and status
            and status.get("state") == "ACTIVE"
            and status.get("feedback_fresh") is True
            and self._joy_matches(0.10, 0.08, True)
            and _close_float(status.get("command", {}).get("steering"), 0.10)
            and _close_float(status.get("command", {}).get("throttle"), 0.08)
        ):
            measured = status.get("measured", {})
            try:
                left = normalized_servo_demand(
                    measured.get("left_servo_pwm"), self.guard["left_servo_rail"]
                )
                right = normalized_servo_demand(
                    measured.get("right_servo_pwm"), self.guard["right_servo_rail"]
                )
            except EvidenceError:
                left = right = 0.0
            if left > right:
                self._emit(
                    "positive.json",
                    {
                        "bridge_status": status_event,
                        "request": self.latest["/command_ingress/rc_axes"],
                        "decoded_output": {"left": left, "right": right},
                    },
                )

        if (
            (self.evidence_dir / "positive.json").exists()
            and status
            and status.get("state") == "ARMED_NEUTRAL"
            and status.get("feedback_fresh") is True
            and self._joy_matches(0.0, 0.0, False)
            and _close_float(status.get("command", {}).get("steering"), 0.0)
            and _close_float(status.get("command", {}).get("throttle"), 0.0)
            and self._measured_neutral(status)
        ):
            self._emit(
                "release.json",
                {
                    "bridge_status": status_event,
                    "request": self.latest["/command_ingress/rc_axes"],
                },
            )

        if (
            (self.evidence_dir / "release.json").exists()
            and status
            and status.get("state") == "ACTIVE"
            and status.get("feedback_fresh") is True
            and self._joy_matches(-0.04, 0.09, True)
            and _close_float(status.get("command", {}).get("steering"), -0.04)
            and _close_float(status.get("command", {}).get("throttle"), 0.09)
        ):
            measured = status.get("measured", {})
            try:
                left = normalized_servo_demand(
                    measured.get("left_servo_pwm"), self.guard["left_servo_rail"]
                )
                right = normalized_servo_demand(
                    measured.get("right_servo_pwm"), self.guard["right_servo_rail"]
                )
            except EvidenceError:
                left = right = 0.0
            if left < right:
                self._emit(
                    "negative.json",
                    {
                        "bridge_status": status_event,
                        "request": self.latest["/command_ingress/rc_axes"],
                        "decoded_output": {"left": left, "right": right},
                    },
                )

        estop_event = self.latest.get("/planning/emergency_stop")
        if (
            (self.evidence_dir / "negative.json").exists()
            and estop_event
            and estop_event["message"].get("data") is True
            and status
            and status.get("state") == "EMERGENCY_STOP"
            and status.get("feedback_fresh") is True
            and _close_float(status.get("command", {}).get("steering"), 0.0)
            and _close_float(status.get("command", {}).get("throttle"), 0.0)
            and self._measured_neutral(status)
        ):
            self._emit(
                "estop.json",
                {"emergency_stop": estop_event, "bridge_status": status_event},
            )

        disarm_sent = self._operator_sent_time("disarm")
        disarmed_state = self._state_after(False, disarm_sent) if disarm_sent else None
        disarm_release_events = []
        if disarm_sent:
            steering_index = int(self.guard["steering_channel"]) - 1
            throttle_index = int(self.guard["throttle_channel"]) - 1
            steering_release = release_value(int(self.guard["steering_channel"]))
            throttle_release = release_value(int(self.guard["throttle_channel"]))
            for event in self.histories["/mavros/rc/override"]:
                if _event_time(event) < disarm_sent:
                    continue
                channels = event["message"].get("channels")
                if not isinstance(channels, list):
                    continue
                if max(steering_index, throttle_index) >= len(channels):
                    continue
                if (
                    channels[steering_index] == steering_release
                    and channels[throttle_index] == throttle_release
                ):
                    disarm_release_events.append(event)
        release_event = disarm_release_events[0] if disarm_release_events else None
        if (
            disarm_sent
            and disarmed_state is not None
            and release_event is not None
        ):
            self._emit(
                "disarm.json",
                {
                    "operator": self._operator("disarm"),
                    "mavros_state": disarmed_state,
                    "first_release_frame": release_event,
                },
            )
        disarm_release_path = self.control_dir / "disarm_release_frames.json"
        if len(disarm_release_events) >= 3 and not disarm_release_path.exists():
            atomic_write_json(
                disarm_release_path,
                {
                    "schema": SCHEMA,
                    "captured_unix_ns": time.time_ns(),
                    "frames": disarm_release_events[:3],
                },
            )
            self.new_markers.append(
                f"SITL_DISARM_RELEASE_FRAMES=PASS count=3 path={disarm_release_path}"
            )

        request_path = self.control_dir / "teardown_requested.json"
        shutdown_path = self.control_dir / "shutdown_frames.json"
        if request_path.exists() and not shutdown_path.exists():
            try:
                threshold = int(read_json(request_path)["requested_unix_ns"])
            except (EvidenceError, KeyError, TypeError, ValueError):
                self._fault("invalid_teardown_request")
            else:
                frames = []
                steering_index = int(self.guard["steering_channel"]) - 1
                throttle_index = int(self.guard["throttle_channel"]) - 1
                steering_release = release_value(int(self.guard["steering_channel"]))
                throttle_release = release_value(int(self.guard["throttle_channel"]))
                for event in self.histories["/mavros/rc/override"]:
                    if _event_time(event) < threshold:
                        continue
                    channels = event["message"].get("channels")
                    if not isinstance(channels, list):
                        continue
                    if max(steering_index, throttle_index) >= len(channels):
                        continue
                    if (
                        channels[steering_index] == steering_release
                        and channels[throttle_index] == throttle_release
                    ):
                        frames.append(event)
                if len(frames) >= 3:
                    atomic_write_json(
                        shutdown_path,
                        {
                            "schema": SCHEMA,
                            "captured_unix_ns": time.time_ns(),
                            "frames": frames[:3],
                        },
                    )
                    self.new_markers.append(
                        f"SITL_SHUTDOWN_FRAMES=PASS count=3 path={shutdown_path}"
                    )


class CaptureNode(Node):
    """Subscriber-only recorder for the five acceptance topics."""

    def __init__(self, run_dir: Path) -> None:
        super().__init__("sitl_digital_twin_evidence")
        snapshot = read_json(run_dir / "manifest" / "mavros_snapshot.json")
        self.run_dir = run_dir
        self.tracker = EvidenceTracker(run_dir, snapshot)
        self.streams: dict[str, Any] = {}
        captures = run_dir / "captures"
        captures.mkdir(mode=0o700, parents=True, exist_ok=True)
        for topic, (message_type, filename) in TOPICS.items():
            self.streams[topic] = (captures / filename).open(
                "a", encoding="utf-8", buffering=1
            )
            self.create_subscription(
                message_type,
                topic,
                lambda message, selected=topic: self._capture(selected, message),
                10,
            )
        self.create_timer(0.1, self._poll)

    def _capture(self, topic: str, message: Any) -> None:
        received_unix_ns = time.time_ns()
        converted = dict(message_to_ordereddict(message))
        envelope = {
            "schema": SCHEMA,
            "topic": topic,
            "received_unix_ns": received_unix_ns,
            "received_monotonic_ns": time.monotonic_ns(),
            "message": converted,
        }
        stream = self.streams[topic]
        stream.write(
            json.dumps(
                envelope, allow_nan=False, separators=(",", ":"), sort_keys=True
            )
            + "\n"
        )
        stream.flush()
        self.tracker.ingest(topic, converted, received_unix_ns)
        self._print_markers()

    def _poll(self) -> None:
        count = self.count_publishers("/command_ingress/rc_axes")
        self.tracker.set_command_publisher_count(count)
        self.tracker.evaluate()
        self._print_markers()

    def _print_markers(self) -> None:
        while self.tracker.new_markers:
            print(self.tracker.new_markers.pop(0), flush=True)

    def close(self) -> None:
        for stream in self.streams.values():
            stream.flush()
            os.fsync(stream.fileno())
            stream.close()


def run_recorder(run_dir: Path) -> int:
    validate_ros_environment()
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    rclpy.init(args=[], signal_handler_options=SignalHandlerOptions.NO)
    node: Optional[CaptureNode] = None
    try:
        node = CaptureNode(run_dir)
        print(
            "SITL_CAPTURE=READY subscriptions=5 "
            "topics=rc_axes,status,emergency_stop,override,mavros_state",
            flush=True,
        )
        rclpy.spin(node)
        return 0
    except KeyboardInterrupt:
        return 0
    finally:
        if node is not None:
            node.close()
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


def latest_state(run_dir: Path) -> int:
    path = run_dir / "captures" / "mavros_state.jsonl"
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        print("SITL_LATEST_STATE=UNKNOWN")
        return 4
    for line in reversed(lines):
        try:
            event = json.loads(line)
            message = event["message"]
            armed = bool(message["armed"])
        except (json.JSONDecodeError, KeyError, TypeError):
            continue
        print(f"SITL_LATEST_STATE={'ARMED' if armed else 'DISARMED'}")
        return 3 if armed else 0
    print("SITL_LATEST_STATE=UNKNOWN")
    return 4


def finalize_run(run_dir: Path, session_complete: bool, cleanup_rc: int) -> int:
    evidence_dir = run_dir / "evidence"
    control_dir = run_dir / "control"
    capture_fault = None
    capture_fault_path = control_dir / "capture_fault.json"
    if capture_fault_path.exists():
        try:
            capture_fault = read_json(capture_fault_path)
        except EvidenceError as exc:
            capture_fault = {"error": str(exc)}
    try:
        runtime = read_json(control_dir / "teardown_runtime.json")
        shutdown_frames = read_json(control_dir / "shutdown_frames.json")
    except EvidenceError as exc:
        runtime = {"error": str(exc), "ports_free": False, "children_stopped": False}
        shutdown_frames = {"frames": []}

    frames = shutdown_frames.get("frames")
    expected_stop_order = [
        "dashboard", "rosbridge", "bridge", "evidence",
        "mavros", "mavproxy", "sitl",
    ]
    teardown_pass = bool(
        capture_fault is None
        and cleanup_rc == 0
        and runtime.get("cleanup_rc") == cleanup_rc
        and runtime.get("ports_free") is True
        and runtime.get("children_stopped") is True
        and runtime.get("stop_order") == expected_stop_order
        and isinstance(frames, list)
        and len(frames) == 3
    )
    teardown_path = evidence_dir / "teardown.json"
    atomic_write_json(
        teardown_path,
        {
            "schema": SCHEMA,
            "phase": "teardown",
            "captured_unix_ns": time.time_ns(),
            "pass": teardown_pass,
            "cleanup_rc": cleanup_rc,
            "capture_fault": capture_fault,
            "runtime": runtime,
            "shutdown_frames": shutdown_frames,
        },
    )

    required_paths = [evidence_dir / name for name in PHASE_FILES]
    missing = [str(path.relative_to(run_dir)) for path in required_paths if not path.is_file()]
    hashes = {
        str(path.relative_to(run_dir)): sha256_file(path)
        for path in required_paths
        if path.is_file()
    }
    verdict_pass = session_complete and teardown_pass and not missing
    verdict = {
        "schema": SCHEMA,
        "captured_unix_ns": time.time_ns(),
        "verdict": "PASS" if verdict_pass else "FAIL",
        "session_complete": session_complete,
        "cleanup_rc": cleanup_rc,
        "capture_fault": capture_fault,
        "missing": missing,
        "evidence_sha256": hashes,
    }
    verdict_path = evidence_dir / "verdict.json"
    atomic_write_json(verdict_path, verdict)
    print(
        f"SITL_VERDICT={verdict['verdict']} run_dir={run_dir} verdict={verdict_path}",
        flush=True,
    )
    return 0 if verdict_pass else 1


def absolute_run_dir(value: str) -> Path:
    path = Path(value)
    if not path.is_absolute():
        raise argparse.ArgumentTypeError("run directory must be absolute")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise argparse.ArgumentTypeError(f"run directory is unavailable: {path}") from exc
    return resolved


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="mode", required=True)

    snapshot_parser = subparsers.add_parser("snapshot")
    snapshot_parser.add_argument("--run-dir", required=True, type=absolute_run_dir)
    snapshot_parser.add_argument("--timeout", type=float, default=30.0)

    record_parser = subparsers.add_parser("record")
    record_parser.add_argument("--run-dir", required=True, type=absolute_run_dir)

    state_parser = subparsers.add_parser("latest-state")
    state_parser.add_argument("--run-dir", required=True, type=absolute_run_dir)

    finalize_parser = subparsers.add_parser("finalize")
    finalize_parser.add_argument("--run-dir", required=True, type=absolute_run_dir)
    finalize_parser.add_argument("--session-complete", required=True, choices=("0", "1"))
    finalize_parser.add_argument("--cleanup-rc", required=True, type=int)
    return parser.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parse_args(argv)
    try:
        if args.mode == "snapshot":
            if not math.isfinite(args.timeout) or args.timeout <= 0.0:
                raise EvidenceError("snapshot timeout must be positive and finite")
            return run_snapshot(args.run_dir, args.timeout)
        if args.mode == "record":
            return run_recorder(args.run_dir)
        if args.mode == "latest-state":
            return latest_state(args.run_dir)
        if args.mode == "finalize":
            return finalize_run(
                args.run_dir, args.session_complete == "1", args.cleanup_rc
            )
    except EvidenceError as exc:
        print(f"sitl_digital_twin_evidence: {exc}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
