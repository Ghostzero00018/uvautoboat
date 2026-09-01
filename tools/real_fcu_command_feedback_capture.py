#!/usr/bin/env python3
"""Capture ordered, read-only evidence for the real-FCU bench tiers."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time
from typing import Any, Callable, Mapping, Optional, Sequence

import rclpy
from mavros_msgs.msg import RCIn, RCOut, State
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from rclpy.signals import SignalHandlerOptions
from rosidl_runtime_py.convert import message_to_ordereddict
from sensor_msgs.msg import Joy
from std_msgs.msg import String


SCHEMA = "uvautoboat.real_fcu.capture.v1"
EXPECTED_ENVIRONMENT = {
    "ROS_DOMAIN_ID": "43",
    "ROS_AUTOMATIC_DISCOVERY_RANGE": "SUBNET",
    "ROS_LOCALHOST_ONLY": "0",
}
TOPICS = {
    "/command_ingress/rc_axes": Joy,
    "/command_ingress/status": String,
    "/mavros/state": State,
}
CALIBRATION_TOPICS = {
    "/mavros/rc/in": RCIn,
    "/mavros/rc/out": RCOut,
}
OPERATOR_OBSERVATION_TOPIC = "operator/esc_threshold"
STATUS_TOPIC = "/command_ingress/status"
CALIBRATION_CORRELATION_MAX_AGE_NS = {
    "/command_ingress/rc_axes": 1_000_000_000,
    "/command_ingress/status": 1_000_000_000,
    "/mavros/state": 2_500_000_000,
    "/mavros/rc/in": 1_000_000_000,
    "/mavros/rc/out": 1_000_000_000,
}
CALIBRATION_MAX_THROTTLE = 0.12
CALIBRATION_SIDES = ("left", "right")
CALIBRATION_MOTIONS = ("stopped", "started", "not-observed")
TIERS = ("t2a", "t2b", "t3a")
CALIBRATION_TIERS = ("t2b", "t3a")
CALIBRATION_STATUS_PUBLISHERS = {
    "t2b": "/real_fcu_rc_command_bridge",
    "t3a": "/real_fcu_rc_command_bridge_t3a",
}


class CaptureError(RuntimeError):
    """Raised when capture setup or retained evidence violates the contract."""


def validate_capture_mode(tier: str, esc_threshold_calibration: bool) -> None:
    if tier not in TIERS:
        raise CaptureError(f"unsupported capture tier: {tier}")
    if tier == "t3a" and not esc_threshold_calibration:
        raise CaptureError("t3a capture tier requires ESC-threshold calibration")
    if esc_threshold_calibration and tier not in CALIBRATION_TIERS:
        raise CaptureError(
            "ESC-threshold calibration requires the t2b capture tier "
            "or the t3a capture tier"
        )


def publisher_node_paths(endpoint_infos: Sequence[Any]) -> tuple[str, ...]:
    paths: set[str] = set()
    for endpoint in endpoint_infos:
        namespace = getattr(endpoint, "node_namespace", None)
        name = getattr(endpoint, "node_name", None)
        if not isinstance(namespace, str) or not isinstance(name, str):
            continue
        normalized_name = name.strip("/")
        if not normalized_name:
            continue
        normalized_namespace = namespace.strip("/")
        paths.add(
            f"/{normalized_namespace}/{normalized_name}"
            if normalized_namespace
            else f"/{normalized_name}"
        )
    return tuple(sorted(paths))


def initial_status_publisher_binding(
    tier: str, esc_threshold_calibration: bool
) -> dict[str, Any]:
    expected = (
        CALIBRATION_STATUS_PUBLISHERS[tier] if esc_threshold_calibration else None
    )
    return {
        "required": esc_threshold_calibration,
        "expected": expected,
        "observed": [],
        "pass": not esc_threshold_calibration,
    }


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


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_ros_environment(
    environment: Mapping[str, str] = os.environ,
) -> dict[str, str]:
    retained: dict[str, str] = {}
    for name, expected in EXPECTED_ENVIRONMENT.items():
        actual = environment.get(name)
        if actual != expected:
            raise CaptureError(f"{name} must be {expected}, got {actual!r}")
        retained[name] = actual
    return retained


def source_stamp_ns(message: Any) -> Optional[int]:
    header = getattr(message, "header", None)
    stamp = getattr(header, "stamp", None)
    if stamp is None:
        return None
    seconds = int(stamp.sec)
    nanoseconds = int(stamp.nanosec)
    if seconds < 0 or not 0 <= nanoseconds < 1_000_000_000:
        raise CaptureError("message source timestamp is invalid")
    return seconds * 1_000_000_000 + nanoseconds


def _git_output(repository: Path, *arguments: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(repository), *arguments),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or "unknown git error"
        raise CaptureError(f"git {' '.join(arguments)} failed: {detail}")
    return result.stdout.strip()


def repository_snapshot(repository: Path) -> dict[str, str]:
    status = _git_output(repository, "status", "--porcelain=v1", "--untracked-files=all")
    if status:
        raise CaptureError("repository worktree or index is not clean")
    head = _git_output(repository, "rev-parse", "HEAD")
    main = _git_output(repository, "rev-parse", "main")
    origin_main = _git_output(repository, "rev-parse", "origin/main")
    if not head == main == origin_main:
        raise CaptureError("HEAD, main and origin/main must match")
    return {"head": head, "main": main, "origin_main": origin_main}


def _receipt_clock() -> tuple[int, int]:
    return time.time_ns(), time.monotonic_ns()


def capture_qos(topic: str) -> Any:
    if topic in (
        "/command_ingress/rc_axes",
        "/mavros/state",
        "/mavros/rc/in",
        "/mavros/rc/out",
    ):
        return QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1 if topic == "/command_ingress/rc_axes" else 10,
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
        )
    return 10


def contains_ordered_subsequence(values: Sequence[str], expected: Sequence[str]) -> bool:
    position = 0
    for value in values:
        if position < len(expected) and value == expected[position]:
            position += 1
    return position == len(expected)


def _finite_number(value: Any) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(value)
    )


def parse_operator_observation(line: str) -> tuple[str, str]:
    """Parse one interactive ESC/motor observation without controller writes."""
    fields = line.strip().lower().split()
    if len(fields) != 2:
        raise CaptureError(
            "observation must be '<left|right> <stopped|started|not-observed>'"
        )
    side, motion = fields
    if side not in CALIBRATION_SIDES or motion not in CALIBRATION_MOTIONS:
        raise CaptureError(
            "observation must be '<left|right> <stopped|started|not-observed>'"
        )
    return side, motion


def status_evidence_error(status: Mapping[str, Any], tier: str) -> Optional[str]:
    """Validate the bridge status shape and phase-bearing state semantics."""
    string_fields = ("state", "fault", "mode")
    boolean_fields = (
        "ready",
        "connected",
        "armed",
        "neutral_only",
        "feedback_fresh",
    )
    if any(not isinstance(status.get(name), str) for name in string_fields):
        return "invalid_status_string_field"
    if any(not isinstance(status.get(name), bool) for name in boolean_fields):
        return "invalid_status_boolean_field"

    command = status.get("command")
    if not isinstance(command, Mapping) or any(
        not _finite_number(command.get(name)) for name in ("steering", "throttle")
    ):
        return "invalid_status_command"
    for name in ("rc_in_age_ms", "rc_out_age_ms"):
        if name not in status:
            return "invalid_status_feedback_age"
        value = status.get(name)
        if value is not None and (
            isinstance(value, bool) or not isinstance(value, int) or value < 0
        ):
            return "invalid_status_feedback_age"

    if "resolved" not in status:
        return "invalid_status_resolved_mapping"
    resolved = status.get("resolved")
    resolved_names = ("steering_rc", "throttle_rc", "left_servo", "right_servo")
    if resolved is not None and (
        not isinstance(resolved, Mapping)
        or any(
            isinstance(resolved.get(name), bool)
            or not isinstance(resolved.get(name), int)
            or resolved.get(name) <= 0
            for name in resolved_names
        )
    ):
        return "invalid_status_resolved_mapping"
    if "measured" not in status:
        return "invalid_status_measured_feedback"
    measured = status.get("measured")
    measured_names = (
        "rc_steering_pwm",
        "rc_throttle_pwm",
        "left_servo_pwm",
        "right_servo_pwm",
    )
    if measured is not None and (
        not isinstance(measured, Mapping)
        or any(
            isinstance(measured.get(name), bool)
            or not isinstance(measured.get(name), int)
            for name in measured_names
        )
    ):
        return "invalid_status_measured_feedback"

    state = status["state"]
    phase_states = {
        "READY_DISARMED": (True, False),
        "ARMED_NEUTRAL": (True, True),
        "ACTIVE": (True, True),
        "EMERGENCY_STOP": (False, None),
    }
    phase_expectation = phase_states.get(state)
    if phase_expectation is None:
        return None
    expected_ready, expected_armed = phase_expectation
    expected_neutral_only = tier == "t2a"
    if not (
        status["ready"] is expected_ready
        and (expected_armed is None or status["armed"] is expected_armed)
        and status["connected"] is True
        and status["mode"] == "MANUAL"
        and status["neutral_only"] is expected_neutral_only
        and status["feedback_fresh"] is True
        and isinstance(status["rc_in_age_ms"], int)
        and not isinstance(status["rc_in_age_ms"], bool)
        and isinstance(status["rc_out_age_ms"], int)
        and not isinstance(status["rc_out_age_ms"], bool)
        and isinstance(resolved, Mapping)
        and isinstance(measured, Mapping)
    ):
        return "invalid_status_phase_evidence"
    return None


class CaptureSession:
    """Retain one globally ordered stream and produce a fail-closed verdict."""

    def __init__(
        self,
        run_dir: Path,
        tier: str,
        receipt_clock: Callable[[], tuple[int, int]] = _receipt_clock,
        esc_threshold_calibration: bool = False,
    ) -> None:
        validate_capture_mode(tier, esc_threshold_calibration)
        self.run_dir = run_dir
        self.tier = tier
        self.receipt_clock = receipt_clock
        self.esc_threshold_calibration = esc_threshold_calibration
        self.expected_status_publisher = (
            CALIBRATION_STATUS_PUBLISHERS[tier]
            if esc_threshold_calibration
            else None
        )
        self.observed_status_publishers: set[str] = set()
        self.subscription_topics = dict(TOPICS)
        if esc_threshold_calibration:
            self.subscription_topics.update(CALIBRATION_TOPICS)
        event_topics = list(self.subscription_topics)
        if esc_threshold_calibration:
            event_topics.append(OPERATOR_OBSERVATION_TOPIC)
        self.evidence_dir = run_dir / "evidence"
        self.log_dir = run_dir / "logs"
        self.evidence_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.log_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.events_path = self.evidence_dir / "events.jsonl"
        self.stream = self.events_path.open("xb", buffering=0)
        self.committed_offset = 0
        self.sequence = 0
        self.counts = {topic: 0 for topic in event_topics}
        self.latest: dict[str, dict[str, Any]] = {}
        self.operator_observations: dict[str, list[dict[str, Any]]] = {
            side: [] for side in CALIBRATION_SIDES
        }
        self.states_seen: list[str] = []
        self.last_armed_state_sequence: Optional[int] = None
        self.invalid_status_count = 0
        self.first_received_unix_ns: Optional[int] = None
        self.last_received_unix_ns: Optional[int] = None
        self.last_received_monotonic_ns: Optional[int] = None
        self.closed = False
        self.finalized = False

    def observe_status_publishers(self, publishers: Sequence[str]) -> None:
        for publisher in publishers:
            if isinstance(publisher, str) and publisher.startswith("/"):
                self.observed_status_publishers.add(publisher)

    def status_publisher_binding(self) -> dict[str, Any]:
        observed = sorted(self.observed_status_publishers)
        required = self.expected_status_publisher is not None
        return {
            "required": required,
            "expected": self.expected_status_publisher,
            "observed": observed,
            "pass": not required or observed == [self.expected_status_publisher],
        }

    def record(
        self,
        topic: str,
        message: Mapping[str, Any],
        source_stamp_ns: Optional[int] = None,
        *,
        _receipt: Optional[tuple[int, int]] = None,
    ) -> dict[str, Any]:
        if self.closed:
            raise CaptureError("capture stream is closed")
        if topic not in self.counts:
            raise CaptureError(f"unexpected capture topic: {topic}")
        if not isinstance(message, Mapping):
            raise CaptureError(f"message for {topic} is not a mapping")
        received_unix_ns, received_monotonic_ns = (
            _receipt if _receipt is not None else self.receipt_clock()
        )
        if not isinstance(received_unix_ns, int) or not isinstance(
            received_monotonic_ns, int
        ):
            raise CaptureError("receipt clock did not return integer nanoseconds")
        if (
            self.last_received_monotonic_ns is not None
            and received_monotonic_ns < self.last_received_monotonic_ns
        ):
            raise CaptureError("receipt monotonic timestamp moved backwards")
        if source_stamp_ns is not None and not isinstance(source_stamp_ns, int):
            raise CaptureError("source timestamp is not integer nanoseconds")

        sequence = self.sequence + 1
        event: dict[str, Any] = {
            "schema": SCHEMA,
            "sequence": sequence,
            "topic": topic,
            "received_unix_ns": received_unix_ns,
            "received_monotonic_ns": received_monotonic_ns,
            "source_stamp_ns": source_stamp_ns,
            "message": dict(message),
        }
        status_invalid = False
        status_state: Optional[str] = None
        if topic == "/command_ingress/status":
            raw = message.get("data")
            try:
                decoded = json.loads(raw) if isinstance(raw, str) else None
            except json.JSONDecodeError:
                decoded = None
            if not isinstance(decoded, dict):
                event["status_error"] = "invalid_status_json"
                status_invalid = True
            else:
                event["decoded"] = decoded
                evidence_error = status_evidence_error(decoded, self.tier)
                if evidence_error:
                    event["status_error"] = evidence_error
                    status_invalid = True
                else:
                    status_state = decoded["state"]

        try:
            encoded = json.dumps(
                event, allow_nan=False, separators=(",", ":"), sort_keys=True
            )
        except (TypeError, ValueError) as exc:
            raise CaptureError(f"message for {topic} is not valid JSON evidence") from exc
        payload = (encoded + "\n").encode("utf-8")
        file_descriptor = self.stream.fileno()
        start_offset = self.committed_offset
        previous_count = self.counts[topic]
        previous_latest = self.latest.get(topic)
        previous_states_length = len(self.states_seen)
        previous_invalid_status_count = self.invalid_status_count
        previous_last_armed_state_sequence = self.last_armed_state_sequence
        previous_first_unix_ns = self.first_received_unix_ns
        previous_last_unix_ns = self.last_received_unix_ns
        previous_last_monotonic_ns = self.last_received_monotonic_ns
        observation_side = (
            message.get("side") if topic == OPERATOR_OBSERVATION_TOPIC else None
        )
        previous_observation_length = (
            len(self.operator_observations[observation_side])
            if observation_side in self.operator_observations
            else None
        )
        previous_mask = signal.pthread_sigmask(
            signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM}
        )
        try:
            written = 0
            while written < len(payload):
                count = os.write(file_descriptor, payload[written:])
                if count <= 0:
                    raise OSError("capture event write made no progress")
                written += count
            self.sequence = sequence
            self.counts[topic] = previous_count + 1
            self.latest[topic] = event
            if status_invalid:
                self.invalid_status_count += 1
            if status_state is not None and (
                not self.states_seen or self.states_seen[-1] != status_state
            ):
                self.states_seen.append(status_state)
            if topic == "/mavros/state" and message.get("armed") is True:
                self.last_armed_state_sequence = sequence
            if observation_side in self.operator_observations:
                self.operator_observations[observation_side].append(event)
            if self.first_received_unix_ns is None:
                self.first_received_unix_ns = received_unix_ns
            self.last_received_unix_ns = received_unix_ns
            self.last_received_monotonic_ns = received_monotonic_ns
            self.committed_offset = start_offset + len(payload)
        except BaseException:
            os.ftruncate(file_descriptor, start_offset)
            os.lseek(file_descriptor, start_offset, os.SEEK_SET)
            self.sequence = sequence - 1
            self.counts[topic] = previous_count
            if previous_latest is None:
                self.latest.pop(topic, None)
            else:
                self.latest[topic] = previous_latest
            del self.states_seen[previous_states_length:]
            self.invalid_status_count = previous_invalid_status_count
            self.last_armed_state_sequence = previous_last_armed_state_sequence
            self.first_received_unix_ns = previous_first_unix_ns
            self.last_received_unix_ns = previous_last_unix_ns
            self.last_received_monotonic_ns = previous_last_monotonic_ns
            if previous_observation_length is not None:
                del self.operator_observations[observation_side][
                    previous_observation_length:
                ]
            self.committed_offset = start_offset
            raise
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return event

    def record_ros_message(self, topic: str, message: Any) -> dict[str, Any]:
        converted = dict(message_to_ordereddict(message))
        return self.record(topic, converted, source_stamp_ns(message))

    @staticmethod
    def _message_from_event(event: Optional[Mapping[str, Any]]) -> Mapping[str, Any]:
        if not event:
            raise CaptureError("calibration correlation is missing a required stream")
        message = event.get("message")
        if not isinstance(message, Mapping):
            raise CaptureError("calibration correlation contains an invalid message")
        return message

    @staticmethod
    def _channel_value(channels: Any, channel: Any, label: str) -> int:
        if (
            isinstance(channel, bool)
            or not isinstance(channel, int)
            or channel <= 0
            or not isinstance(channels, Sequence)
            or isinstance(channels, (str, bytes))
            or channel > len(channels)
        ):
            raise CaptureError(f"calibration correlation cannot resolve {label}")
        value = channels[channel - 1]
        if isinstance(value, bool) or not isinstance(value, int):
            raise CaptureError(f"calibration correlation has invalid {label}")
        return value

    def _calibration_correlation(self, observation_monotonic_ns: int) -> dict[str, Any]:
        required_topics = (
            "/command_ingress/rc_axes",
            "/command_ingress/status",
            "/mavros/state",
            "/mavros/rc/in",
            "/mavros/rc/out",
        )
        events: dict[str, Mapping[str, Any]] = {}
        ages_ms: dict[str, int] = {}
        sequences: dict[str, int] = {}
        for topic in required_topics:
            event = self.latest.get(topic)
            if not event:
                raise CaptureError(f"calibration correlation is missing {topic}")
            received = event.get("received_monotonic_ns")
            sequence = event.get("sequence")
            if (
                isinstance(received, bool)
                or not isinstance(received, int)
                or isinstance(sequence, bool)
                or not isinstance(sequence, int)
            ):
                raise CaptureError(f"calibration correlation has invalid {topic} timing")
            age_ns = observation_monotonic_ns - received
            maximum_age_ns = CALIBRATION_CORRELATION_MAX_AGE_NS[topic]
            if age_ns < 0 or age_ns >= maximum_age_ns:
                raise CaptureError(f"calibration correlation is stale for {topic}")
            events[topic] = event
            ages_ms[topic] = age_ns // 1_000_000
            sequences[topic] = sequence

        status_event = events["/command_ingress/status"]
        status = status_event.get("decoded")
        if "status_error" in status_event or not isinstance(status, Mapping):
            raise CaptureError("calibration correlation has invalid bridge status")
        if not (
            status.get("state") == "ACTIVE"
            and status.get("connected") is True
            and status.get("armed") is True
            and status.get("mode") == "MANUAL"
            and status.get("feedback_fresh") is True
        ):
            raise CaptureError("calibration observation requires ACTIVE fresh feedback")

        state = self._message_from_event(events["/mavros/state"])
        if not (
            state.get("connected") is True
            and state.get("armed") is True
            and state.get("mode") == "MANUAL"
        ):
            raise CaptureError("calibration observation requires an armed MANUAL FCU")

        axes = self._message_from_event(events["/command_ingress/rc_axes"])
        axis_values = axes.get("axes")
        buttons = axes.get("buttons")
        command = status.get("command")
        if (
            not isinstance(axis_values, Sequence)
            or isinstance(axis_values, (str, bytes))
            or len(axis_values) != 2
            or not isinstance(buttons, Sequence)
            or isinstance(buttons, (str, bytes))
            or list(buttons) != [1]
            or not isinstance(command, Mapping)
        ):
            raise CaptureError("calibration observation requires an enabled command")
        steering = axis_values[0]
        throttle = axis_values[1]
        status_steering = command.get("steering")
        status_throttle = command.get("throttle")
        if not all(
            _finite_number(value)
            for value in (steering, throttle, status_steering, status_throttle)
        ):
            raise CaptureError("calibration observation has invalid command values")
        if float(steering) != 0.0 or float(status_steering) != 0.0:
            raise CaptureError("calibration observation requires straight steering")
        if float(throttle) <= 0.0 or float(status_throttle) <= 0.0:
            raise CaptureError("calibration observation requires positive throttle")
        if not math.isclose(
            float(throttle), float(status_throttle), rel_tol=0.0, abs_tol=1e-6
        ):
            raise CaptureError("calibration command and bridge status do not match")

        resolved = status.get("resolved")
        status_measured = status.get("measured")
        if not isinstance(resolved, Mapping) or not isinstance(
            status_measured, Mapping
        ):
            raise CaptureError("calibration correlation lacks resolved feedback")
        rc_in_channels = self._message_from_event(events["/mavros/rc/in"]).get(
            "channels"
        )
        rc_out_channels = self._message_from_event(events["/mavros/rc/out"]).get(
            "channels"
        )
        measured = {
            "rc_steering_pwm": self._channel_value(
                rc_in_channels, resolved.get("steering_rc"), "steering RC input"
            ),
            "rc_throttle_pwm": self._channel_value(
                rc_in_channels, resolved.get("throttle_rc"), "throttle RC input"
            ),
            "left_servo_pwm": self._channel_value(
                rc_out_channels, resolved.get("left_servo"), "left servo output"
            ),
            "right_servo_pwm": self._channel_value(
                rc_out_channels, resolved.get("right_servo"), "right servo output"
            ),
        }
        if any(status_measured.get(name) != value for name, value in measured.items()):
            raise CaptureError("raw feedback and bridge status do not match")
        return {
            "sequences": sequences,
            "ages_ms": ages_ms,
            "command": {
                "steering": float(status_steering),
                "throttle": float(status_throttle),
            },
            "measured": measured,
            "resolved": dict(resolved),
        }

    def record_operator_observation(self, side: str, motion: str) -> dict[str, Any]:
        if not self.esc_threshold_calibration:
            raise CaptureError("operator ESC observation requires calibration mode")
        if side not in CALIBRATION_SIDES or motion not in CALIBRATION_MOTIONS:
            raise CaptureError("invalid ESC-threshold observation")
        prior = self.operator_observations[side]
        if any(
            event["message"].get("motion") in ("started", "not-observed")
            for event in prior
        ):
            raise CaptureError(f"terminal {side} observation was already recorded")
        receipt = self.receipt_clock()
        correlation = self._calibration_correlation(receipt[1])
        return self.record(
            OPERATOR_OBSERVATION_TOPIC,
            {
                "evidence_class": "operator_observed",
                "side": side,
                "motion": motion,
                "correlation": correlation,
            },
            _receipt=receipt,
        )

    def streams_ready(self) -> bool:
        status_event = self.latest.get("/command_ingress/status")
        state_event = self.latest.get("/mavros/state")
        status = (
            status_event.get("decoded")
            if status_event and "status_error" not in status_event
            else None
        )
        state = state_event.get("message") if state_event else None
        expected_neutral_only = self.tier == "t2a"
        base_ready = bool(
            isinstance(status, dict)
            and isinstance(state, dict)
            and status.get("state") == "READY_DISARMED"
            and status.get("connected") is True
            and status.get("armed") is False
            and status.get("mode") == "MANUAL"
            and status.get("feedback_fresh") is True
            and status.get("neutral_only") is expected_neutral_only
            and state.get("connected") is True
            and state.get("armed") is False
            and state.get("mode") == "MANUAL"
        )
        if not base_ready or not self.esc_threshold_calibration:
            return base_ready
        return all(
            topic in self.latest for topic in CALIBRATION_TOPICS
        ) and self.status_publisher_binding()["pass"]

    def _calibration_verdict(self, reasons: list[str]) -> dict[str, Any]:
        summary: dict[str, Any] = {}
        for topic, reason in (
            ("/mavros/rc/in", "calibration_rc_in_missing"),
            ("/mavros/rc/out", "calibration_rc_out_missing"),
        ):
            if self.counts.get(topic, 0) == 0:
                reasons.append(reason)
        for side in CALIBRATION_SIDES:
            observations = self.operator_observations[side]
            servo_pwm_key = f"{side}_servo_pwm"
            stopped = [
                event for event in observations if event["message"]["motion"] == "stopped"
            ]
            terminal = next(
                (
                    event
                    for event in observations
                    if event["message"]["motion"] in ("started", "not-observed")
                ),
                None,
            )
            if not stopped or terminal is None:
                reasons.append(f"calibration_{side}_observation_incomplete")
                summary[side] = None
                continue
            lower = max(
                stopped,
                key=lambda event: (
                    event["message"]["correlation"]["measured"][servo_pwm_key],
                    event["message"]["correlation"]["command"]["throttle"],
                    event["sequence"],
                ),
            )
            lower_throttle = lower["message"]["correlation"]["command"]["throttle"]
            lower_pwm = lower["message"]["correlation"]["measured"][servo_pwm_key]
            terminal_throttle = terminal["message"]["correlation"]["command"][
                "throttle"
            ]
            terminal_pwm = terminal["message"]["correlation"]["measured"][
                servo_pwm_key
            ]
            outcome = terminal["message"]["motion"]
            if terminal["sequence"] <= lower["sequence"] or terminal_throttle < lower_throttle:
                reasons.append(f"calibration_{side}_observation_order_invalid")
            elif outcome == "started" and terminal_throttle <= lower_throttle:
                reasons.append(f"calibration_{side}_threshold_not_bracketed")
            elif terminal_pwm <= lower_pwm:
                reasons.append(f"calibration_{side}_pwm_not_bracketed")
            elif outcome == "not-observed" and not math.isclose(
                terminal_throttle,
                CALIBRATION_MAX_THROTTLE,
                rel_tol=0.0,
                abs_tol=1e-6,
            ):
                reasons.append(f"calibration_{side}_maximum_not_reached")
            summary[side] = {
                "evidence_class": "operator_observed",
                "outcome": outcome,
                "lower_no_rotation": {
                    "sequence": lower["sequence"],
                    "throttle": lower_throttle,
                    "measured": lower["message"]["correlation"]["measured"],
                },
                "terminal_observation": {
                    "sequence": terminal["sequence"],
                    "throttle": terminal_throttle,
                    "measured": terminal["message"]["correlation"]["measured"],
                },
            }
        return summary

    @staticmethod
    def _final_status(event: Optional[Mapping[str, Any]]) -> Optional[dict[str, Any]]:
        if not event or "status_error" in event:
            return None
        decoded = event.get("decoded")
        if not isinstance(decoded, dict):
            return None
        retained = dict(decoded)
        retained["sequence"] = event.get("sequence")
        retained["received_unix_ns"] = event.get("received_unix_ns")
        retained["received_monotonic_ns"] = event.get("received_monotonic_ns")
        return retained

    @staticmethod
    def _final_state(event: Optional[Mapping[str, Any]]) -> Optional[dict[str, Any]]:
        if not event:
            return None
        message = event.get("message")
        if not isinstance(message, dict):
            return None
        retained = dict(message)
        retained["sequence"] = event.get("sequence")
        retained["received_unix_ns"] = event.get("received_unix_ns")
        retained["received_monotonic_ns"] = event.get("received_monotonic_ns")
        retained["source_stamp_ns"] = event.get("source_stamp_ns")
        return retained

    def finalize(self, runtime_error: Optional[str] = None) -> dict[str, Any]:
        if self.finalized:
            raise CaptureError("capture verdict was already finalized")
        os.fsync(self.stream.fileno())

        reasons: list[str] = []
        if runtime_error:
            reasons.append("capture_runtime_error")
        if self.invalid_status_count:
            reasons.append("invalid_status_evidence")
        final_status = self._final_status(
            self.latest.get("/command_ingress/status")
        )
        final_state = self._final_state(self.latest.get("/mavros/state"))
        expected_status_state = "READY_DISARMED" if self.tier == "t2a" else "EMERGENCY_STOP"
        expected_neutral_only = self.tier == "t2a"
        if not final_status:
            reasons.append("final_status_missing")
        elif not (
            final_status.get("state") == expected_status_state
            and final_status.get("connected") is True
            and final_status.get("armed") is False
            and final_status.get("mode") == "MANUAL"
            and final_status.get("feedback_fresh") is True
            and final_status.get("neutral_only") is expected_neutral_only
        ):
            reasons.append("final_status_not_disarmed")
        if not final_state:
            reasons.append("final_state_missing")
        elif not (
            final_state.get("connected") is True
            and final_state.get("armed") is False
            and final_state.get("mode") == "MANUAL"
        ):
            reasons.append("final_state_not_disarmed")

        axes_count = self.counts["/command_ingress/rc_axes"]
        if self.tier == "t2a" and axes_count:
            reasons.append("t2a_rc_axes_observed")
        if self.tier in ("t2b", "t3a") and not axes_count:
            reasons.append(f"{self.tier}_rc_axes_missing")
        expected_status_sequence = (
            ("READY_DISARMED", "ARMED_NEUTRAL", "READY_DISARMED")
            if self.tier == "t2a"
            else ("READY_DISARMED", "ARMED_NEUTRAL", "ACTIVE", "EMERGENCY_STOP")
        )
        if self.last_armed_state_sequence is None:
            reasons.append("armed_state_not_observed")
        if not contains_ordered_subsequence(self.states_seen, expected_status_sequence):
            reasons.append("tier_status_sequence_incomplete")
        if self.tier == "t2a" and any(
            state in ("ACTIVE", "EMERGENCY_STOP") for state in self.states_seen
        ):
            reasons.append("t2a_forbidden_status_state")

        calibration = None
        status_publisher_binding = self.status_publisher_binding()
        if self.esc_threshold_calibration:
            if not status_publisher_binding["observed"]:
                reasons.append("status_publisher_binding_missing")
            elif not status_publisher_binding["pass"]:
                reasons.append("status_publisher_binding_mismatch")
            calibration = self._calibration_verdict(reasons)

        verdict = {
            "schema": SCHEMA,
            "pass": not reasons,
            "tier": self.tier,
            "finalized_unix_ns": time.time_ns(),
            "event_count": self.sequence,
            "event_counts": dict(self.counts),
            "first_received_unix_ns": self.first_received_unix_ns,
            "last_received_unix_ns": self.last_received_unix_ns,
            "states_seen": list(self.states_seen),
            "last_armed_state_sequence": self.last_armed_state_sequence,
            "invalid_status_count": self.invalid_status_count,
            "final_status": final_status,
            "final_state": final_state,
            "runtime_error": runtime_error,
            "reasons": reasons,
            "events_file": self.events_path.name,
            "esc_threshold_calibration": self.esc_threshold_calibration,
            **(
                {"status_publisher_binding": status_publisher_binding}
                if self.esc_threshold_calibration
                else {}
            ),
            "calibration": calibration,
        }
        if self.esc_threshold_calibration:
            update_session_manifest_binding(self.run_dir, status_publisher_binding)
        atomic_write_json(self.evidence_dir / "verdict.json", verdict)
        self.finalized = True
        self.close()
        return verdict

    def close(self) -> None:
        if self.closed:
            return
        os.fsync(self.stream.fileno())
        self.stream.close()
        self.closed = True


class CaptureNode(Node):
    """Application subscriber for command, bridge-status and FCU-state evidence."""

    def __init__(self, session: CaptureSession) -> None:
        super().__init__(
            "real_fcu_command_feedback_capture",
            cli_args=[],
            use_global_arguments=False,
            enable_rosout=False,
            start_parameter_services=False,
            enable_logger_service=False,
        )
        self.session = session
        self.streams_announced = False
        for topic, message_type in session.subscription_topics.items():
            self.create_subscription(
                message_type,
                topic,
                lambda message, selected=topic: self._capture(selected, message),
                capture_qos(topic),
            )

    def _capture(self, topic: str, message: Any) -> None:
        if topic == STATUS_TOPIC and self.session.esc_threshold_calibration:
            self._capture_status_publisher_binding()
        self.session.record_ros_message(topic, message)
        if not self.streams_announced and self.session.streams_ready():
            self.streams_announced = True
            calibration_suffix = (
                " rc_in=received rc_out=received esc_threshold_calibration=true"
                if self.session.esc_threshold_calibration
                else " esc_threshold_calibration=false"
            )
            print(
                "REAL_FCU_CAPTURE_STREAMS=PASS status=received state=received"
                f"{calibration_suffix}",
                flush=True,
            )

    def _capture_status_publisher_binding(self) -> None:
        try:
            endpoints = self.get_publishers_info_by_topic(STATUS_TOPIC)
        except Exception:
            endpoints = ()
        self.session.observe_status_publishers(publisher_node_paths(endpoints))


def _append_diagnostic(path: Path, message: str) -> None:
    with path.open("a", encoding="utf-8") as stream:
        stream.write(f"received_unix_ns={time.time_ns()} {message}\n")


def create_run_dir(
    output_root: Path, tier: str, esc_threshold_calibration: bool = False
) -> Path:
    root = output_root.expanduser().resolve()
    if not root.is_absolute():
        raise CaptureError("capture output root must be absolute")
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S", time.localtime())
    mode = f"{tier}_esc_threshold" if esc_threshold_calibration else tier
    run_dir = root / f"real_fcu_capture_{mode}_{timestamp}"
    try:
        run_dir.mkdir(mode=0o700)
    except FileExistsError as exc:
        raise CaptureError(f"capture run directory already exists: {run_dir}") from exc
    return run_dir


def write_session_manifest(
    run_dir: Path,
    tier: str,
    environment: Mapping[str, str],
    repository: Mapping[str, str],
    helper_path: Path,
    esc_threshold_calibration: bool = False,
) -> None:
    atomic_write_json(
        run_dir / "manifest/session.json",
        {
            "schema": SCHEMA,
            "tier": tier,
            "started_unix_ns": time.time_ns(),
            "environment": dict(environment),
            "repository": dict(repository),
            "helper": {
                "path": str(helper_path),
                "sha256": sha256_file(helper_path),
            },
            "topics": list(TOPICS),
            "subscription_topics": list(
                {
                    **TOPICS,
                    **(CALIBRATION_TOPICS if esc_threshold_calibration else {}),
                }
            ),
            "esc_threshold_calibration": esc_threshold_calibration,
            **(
                {
                    "status_publisher_binding": initial_status_publisher_binding(
                        tier, esc_threshold_calibration
                    )
                }
                if esc_threshold_calibration
                else {}
            ),
            "calibration_max_throttle": (
                CALIBRATION_MAX_THROTTLE if esc_threshold_calibration else None
            ),
            "operator_observation_interface": (
                "stdin" if esc_threshold_calibration else None
            ),
            "writes": "none",
        },
    )


def update_session_manifest_binding(
    run_dir: Path, status_publisher_binding: Mapping[str, Any]
) -> None:
    manifest_path = run_dir / "manifest/session.json"
    if not manifest_path.is_file():
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise CaptureError("capture session manifest is not a JSON object")
    manifest["status_publisher_binding"] = dict(status_publisher_binding)
    atomic_write_json(manifest_path, manifest)


def close_ros_runtime(node: Optional[Node]) -> Optional[str]:
    """Attempt every ROS cleanup step and return one retained error string."""
    errors: list[str] = []
    if node is not None:
        try:
            node.destroy_node()
        except Exception as exc:
            errors.append(f"destroy_node {type(exc).__name__}: {exc}")
    try:
        context_ok = rclpy.ok()
    except Exception as exc:
        errors.append(f"context_check {type(exc).__name__}: {exc}")
        context_ok = False
    if context_ok:
        try:
            rclpy.shutdown()
        except Exception as exc:
            errors.append(f"shutdown {type(exc).__name__}: {exc}")
    return "; ".join(errors) or None


def run_capture(
    tier: str, output_root: Path, esc_threshold_calibration: bool = False
) -> int:
    validate_capture_mode(tier, esc_threshold_calibration)
    helper_path = Path(__file__).resolve()
    repository_root = helper_path.parent.parent
    environment = validate_ros_environment()
    repository = repository_snapshot(repository_root)
    resolved_output_root = output_root.expanduser().resolve()
    try:
        resolved_output_root.relative_to(repository_root)
    except ValueError:
        pass
    else:
        raise CaptureError("capture output root must be outside the repository")

    run_dir = create_run_dir(
        resolved_output_root,
        tier,
        esc_threshold_calibration=esc_threshold_calibration,
    )
    session = CaptureSession(
        run_dir, tier, esc_threshold_calibration=esc_threshold_calibration
    )
    diagnostic_path = session.log_dir / "capture.log"
    write_session_manifest(
        run_dir,
        tier,
        environment,
        repository,
        helper_path,
        esc_threshold_calibration=esc_threshold_calibration,
    )
    _append_diagnostic(diagnostic_path, f"capture_start tier={tier}")

    node: Optional[CaptureNode] = None
    runtime_error: Optional[str] = None
    operator_stop = False
    try:
        rclpy.init(args=[], signal_handler_options=SignalHandlerOptions.NO)
        node = CaptureNode(session)
        print(
            f"REAL_FCU_CAPTURE_READY=PASS tier={tier.upper()} "
            f"subscriptions={len(session.subscription_topics)} "
            f"esc_threshold_calibration={str(esc_threshold_calibration).lower()} "
            f"run_dir={run_dir}",
            flush=True,
        )
        if esc_threshold_calibration:
            print(
                "REAL_FCU_ESC_THRESHOLD_INPUT=READY commands='<left|right> "
                "<stopped|started|not-observed>' steering=0 required",
                flush=True,
            )
            while rclpy.ok():
                rclpy.spin_once(node, timeout_sec=0.1)
                readable, _, _ = select.select((sys.stdin,), (), (), 0)
                if not readable:
                    continue
                line = sys.stdin.readline()
                if line == "":
                    raise CaptureError("calibration operator input closed")
                try:
                    side, motion = parse_operator_observation(line)
                    event = session.record_operator_observation(side, motion)
                except CaptureError as exc:
                    print(
                        f"REAL_FCU_ESC_THRESHOLD_OBSERVATION=REJECTED reason={exc}",
                        file=sys.stderr,
                        flush=True,
                    )
                    continue
                throttle = event["message"]["correlation"]["command"]["throttle"]
                print(
                    "REAL_FCU_ESC_THRESHOLD_OBSERVATION=RECORDED "
                    f"side={side} motion={motion} throttle={throttle:.6f} "
                    f"sequence={event['sequence']}",
                    flush=True,
                )
        else:
            rclpy.spin(node)
        runtime_error = "capture spin returned without operator stop"
    except KeyboardInterrupt:
        operator_stop = True
        _append_diagnostic(diagnostic_path, "operator_stop_requested")
    except Exception as exc:  # fail closed while preserving the run directory
        runtime_error = f"{type(exc).__name__}: {exc}"
        _append_diagnostic(diagnostic_path, f"capture_error {runtime_error}")
    finally:
        cleanup_error = close_ros_runtime(node)

    if cleanup_error:
        _append_diagnostic(diagnostic_path, f"capture_cleanup_error {cleanup_error}")
        runtime_error = (
            f"{runtime_error}; ROS cleanup failed: {cleanup_error}"
            if runtime_error
            else f"ROS cleanup failed: {cleanup_error}"
        )

    if not operator_stop and runtime_error is None:
        runtime_error = "capture ended without operator stop"
    verdict = session.finalize(runtime_error=runtime_error)
    _append_diagnostic(
        diagnostic_path,
        f"capture_final pass={str(verdict['pass']).lower()} events={verdict['event_count']}",
    )
    if verdict["pass"] and operator_stop:
        print(
            f"REAL_FCU_CAPTURE_FINAL=PASS tier={tier.upper()} final=disarmed "
            f"events={verdict['event_count']} "
            f"esc_threshold_calibration={str(esc_threshold_calibration).lower()} "
            f"run_dir={run_dir}",
            flush=True,
        )
        return 0
    reasons = ",".join(verdict["reasons"]) or "operator_stop_missing"
    print(
        f"REAL_FCU_CAPTURE_FINAL=FAIL tier={tier.upper()} reasons={reasons} "
        f"esc_threshold_calibration={str(esc_threshold_calibration).lower()} "
        f"run_dir={run_dir}",
        file=sys.stderr,
        flush=True,
    )
    return 3


def parse_args(arguments: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Capture read-only real-FCU command/feedback evidence"
    )
    parser.add_argument("tier", choices=TIERS)
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path(
            os.environ.get("REAL_FCU_CAPTURE_LOG_ROOT", str(Path.home() / "Desktop"))
        ),
    )
    parser.add_argument(
        "--esc-threshold-calibration",
        action="store_true",
        help="capture raw RC/PWM plus interactive straight-throttle observations",
    )
    options = parser.parse_args(arguments)
    try:
        validate_capture_mode(options.tier, options.esc_threshold_calibration)
    except CaptureError as exc:
        parser.error(str(exc))
    return options


def main(arguments: Optional[Sequence[str]] = None) -> int:
    options = parse_args(arguments)
    try:
        return run_capture(
            options.tier,
            options.output_root,
            esc_threshold_calibration=options.esc_threshold_calibration,
        )
    except (CaptureError, OSError) as exc:
        print(f"real_fcu_command_feedback_capture: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
