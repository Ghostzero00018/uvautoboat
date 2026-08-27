#!/usr/bin/env python3
"""Read-only observers and adjudication for the live FCU-to-VRX path."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import signal
import sys
import time
from typing import Any, Mapping, Sequence


SCHEMA = "uvautoboat.fcu_to_vrx.evidence.v1"
MOTOR_OUTPUTS_BIT = 32768
# Pose is recorded at most this often. 20 Hz is far finer than the motion
# correlation needs and keeps a long pre-Pi hold from dominating the stream.
POSE_EVENT_MIN_GAP_NS = 50_000_000


class EvidenceError(RuntimeError):
    """Raised when observed evidence does not satisfy the live contract."""


def _finite_number(value: Any) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(value)
    )


def validate_config(
    config: Mapping[str, Any], *, require_max_thrust: bool = True
) -> dict[str, Any]:
    result = {
        "left_channel": config.get("left_channel"),
        "right_channel": config.get("right_channel"),
        "left": dict(config.get("left", {})),
        "right": dict(config.get("right", {})),
    }
    for name in ("left_channel", "right_channel"):
        value = result[name]
        if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= 16:
            raise EvidenceError(f"{name} must be an integer in 1..16")
    if result["left_channel"] == result["right_channel"]:
        raise EvidenceError("left and right channels must be distinct")
    for side in ("left", "right"):
        rail = result[side]
        if set(rail) != {"minimum", "trim", "maximum"}:
            raise EvidenceError(f"{side} rail is incomplete")
        values = (rail["minimum"], rail["trim"], rail["maximum"])
        if any(isinstance(value, bool) or not isinstance(value, int) for value in values):
            raise EvidenceError(f"{side} rail values must be integers")
        if not rail["minimum"] <= rail["trim"] < rail["maximum"]:
            raise EvidenceError(f"{side} rail must satisfy minimum <= trim < maximum")
    if require_max_thrust:
        max_thrust = config.get("max_thrust")
        if not _finite_number(max_thrust) or max_thrust <= 0.0:
            raise EvidenceError("max_thrust must be finite and greater than zero")
        result["max_thrust"] = float(max_thrust)
    return result


def pwm_to_normalised(pwm: Any, minimum: int, trim: int, maximum: int) -> float:
    if pwm is None or isinstance(pwm, bool) or not _finite_number(pwm) or pwm <= 0:
        return 0.0
    bounded = float(min(max(pwm, minimum), maximum))
    if trim <= minimum:
        return (bounded - minimum) / (maximum - minimum)
    if bounded >= trim:
        return (bounded - trim) / max(maximum - trim, 1.0)
    return -(trim - bounded) / max(trim - minimum, 1.0)


def pwm_to_thrust(config: Mapping[str, Any], side: str, pwm: int) -> float:
    checked = validate_config(config)
    rail = checked[side]
    return pwm_to_normalised(
        pwm, rail["minimum"], rail["trim"], rail["maximum"]
    ) * checked["max_thrust"]


def bridge_servo_event(
    config: Mapping[str, Any],
    *,
    left_pwm: int,
    right_pwm: int,
    time_usec: int,
    received_unix_ns: int,
) -> dict[str, Any]:
    checked = validate_config(config)
    for name, value in (("left_pwm", left_pwm), ("right_pwm", right_pwm)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise EvidenceError(f"{name} must be a non-negative integer")
    if isinstance(time_usec, bool) or not isinstance(time_usec, int) or time_usec < 0:
        raise EvidenceError("time_usec must be a non-negative integer")
    if (
        isinstance(received_unix_ns, bool)
        or not isinstance(received_unix_ns, int)
        or received_unix_ns <= 0
    ):
        raise EvidenceError("received_unix_ns must be a positive integer")
    return {
        "schema": SCHEMA,
        "kind": "servo_output_raw",
        "bridge_received_unix_ns": received_unix_ns,
        "mavlink_time_usec": time_usec,
        "left_channel": checked["left_channel"],
        "right_channel": checked["right_channel"],
        "left_pwm": left_pwm,
        "right_pwm": right_pwm,
        "left_thrust": pwm_to_thrust(checked, "left", left_pwm),
        "right_thrust": pwm_to_thrust(checked, "right", right_pwm),
    }


def append_event(path: Path, kind: str, **values: Any) -> dict[str, Any]:
    payload = {
        "schema": SCHEMA,
        "kind": kind,
        "captured_unix_ns": time.time_ns(),
        "captured_monotonic_ns": time.monotonic_ns(),
        **values,
    }
    encoded = json.dumps(payload, allow_nan=False, separators=(",", ":"), sort_keys=True)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as stream:
        stream.write(encoded)
        stream.write("\n")
        stream.flush()
    return payload


def sync_evidence(path: Path) -> None:
    with path.open("rb") as stream:
        os.fsync(stream.fileno())


def required_streams_are_live(
    required: Any, last_seen: Mapping[str, int], now: int, stale_seconds: int
) -> bool:
    """All required streams present, and fresh when a limit is set.

    Membership alone would let a pose sample recorded during the long pre-Pi
    hold satisfy readiness minutes later, after the operator has started the
    Pi. Record-only mode (stale_seconds == 0) keeps membership semantics; the
    fail-closed mode that gates arming also requires every stream to be within
    its limit, so READY means four concurrently live streams.
    """
    if not set(required).issubset(last_seen):
        return False
    if stale_seconds == 0:
        return True
    limit = stale_seconds * 1_000_000_000
    return all(now - last_seen[kind] <= limit for kind in required)


def pose_event_is_due(last_event_ns: int | None, now_ns: int) -> bool:
    """Whether another pose sample should be written to the retained stream.

    Readiness and staleness observe every message; only the retained record is
    thinned, so the correlation contracts are unaffected.
    """
    return (
        last_event_ns is None
        or now_ns - last_event_ns >= POSE_EVENT_MIN_GAP_NS
    )


def observed_parent_frames(transforms: Any) -> list[str]:
    """Parent frame ids present in one TFMessage, sorted and de-duplicated."""
    return sorted({str(item.header.frame_id) for item in transforms})


def select_world_transform(transforms: Any, world_frame: str) -> Any:
    """Return the transform published directly against the world frame.

    In this workspace the WAM-V gz PosePublisher runs with
    publish_link_pose=false and publish_model_pose=true. The second value is
    not upstream VRX's default: it comes from this workspace's own vrx commit
    e384cd65, applied by one_click_launch_all/patch_vrx.sh. With it in place
    the only transform carrying WAM-V world displacement is the model root,
    whose parent is the world frame (the launched world name, e.g.
    sydney_regatta) and whose child is the bare model name.

    Link names such as base_link appear only as parents of sensor transforms
    -- observed as the double-prefixed wamv/wamv/base_link -- and never as the
    child of a moving one, so selecting on the child name matches nothing.

    If the patch is absent, publish_model_pose is false, no transform carries
    the world frame as parent, and this returns None on every message. The
    caller reports that as a frame mismatch listing the observed parents,
    which is also the signature of a genuinely wrong world name.

    The world frame is supplied by the caller from the launched world name;
    the vehicle's own model name is never assumed here.
    """
    if not world_frame:
        return None
    for item in transforms:
        if str(item.header.frame_id) == world_frame:
            return item
    return None


def write_status(path: Path, phase: str, **values: Any) -> None:
    payload = {"schema": SCHEMA, "phase": phase, **values}
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(payload, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def read_events(path: Path) -> list[dict[str, Any]]:
    events = []
    with path.open("r", encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            try:
                payload = json.loads(line)
            except json.JSONDecodeError as exc:
                raise EvidenceError(f"invalid JSON at {path}:{line_number}: {exc}") from exc
            if not isinstance(payload, dict) or payload.get("schema") != SCHEMA:
                raise EvidenceError(f"invalid evidence schema at {path}:{line_number}")
            timestamp = payload.get("captured_unix_ns")
            if isinstance(timestamp, bool) or not isinstance(timestamp, int) or timestamp <= 0:
                raise EvidenceError(f"invalid capture timestamp at {path}:{line_number}")
            events.append(payload)
    if not events:
        raise EvidenceError(f"evidence file is empty: {path}")
    return events


def _events(events: Sequence[Mapping[str, Any]], kind: str) -> list[Mapping[str, Any]]:
    return sorted(
        (event for event in events if event.get("kind") == kind),
        key=lambda event: int(event["captured_unix_ns"]),
    )


def _observer_config(events: Sequence[Mapping[str, Any]], side: str) -> dict[str, Any]:
    starts = [
        event
        for event in events
        if event.get("kind") == "observer_started" and event.get("side") == side
    ]
    if len(starts) != 1:
        raise EvidenceError(f"expected one {side} observer start event")
    config = starts[0].get("config")
    if not isinstance(config, Mapping):
        raise EvidenceError(f"{side} observer start event has no configuration")
    return validate_config(config, require_max_thrust=side == "vrx")


def _in_rail(config: Mapping[str, Any], side: str, pwm: Any) -> bool:
    if isinstance(pwm, bool) or not isinstance(pwm, int):
        return False
    rail = config[side]
    return rail["minimum"] <= pwm <= rail["maximum"]


def _matching_value_event(
    events: Sequence[Mapping[str, Any]],
    *,
    after_ns: int,
    deadline_ns: int,
    expected: float,
) -> Mapping[str, Any] | None:
    for event in events:
        timestamp = int(event["captured_unix_ns"])
        if timestamp < after_ns:
            continue
        if timestamp > deadline_ns:
            break
        value = event.get("value")
        if _finite_number(value) and math.isclose(float(value), expected, abs_tol=1e-6):
            return event
    return None


def _measurement_ready_ns(
    events: Sequence[Mapping[str, Any]], side: str
) -> int:
    if _events(events, "observer_abort"):
        raise EvidenceError(f"{side} observer recorded an abort")
    ready = [
        event
        for event in _events(events, "observer_ready")
        if event.get("side") == side
    ]
    if len(ready) != 1:
        raise EvidenceError(f"{side} observer did not record exactly one READY event")
    return int(ready[0]["captured_unix_ns"])


def _measurement_events(
    events: Sequence[Mapping[str, Any]], kind: str, start_ns: int, end_ns: int
) -> list[Mapping[str, Any]]:
    selected = [
        event
        for event in _events(events, kind)
        if start_ns <= int(event["captured_unix_ns"]) <= end_ns
    ]
    if len(selected) < 2:
        raise EvidenceError(
            f"measurement window needs at least two {kind} events"
        )
    return selected


def _max_gap_seconds(events: Sequence[Mapping[str, Any]]) -> float:
    timestamps = [int(event["captured_unix_ns"]) for event in events]
    return round(
        max(second - first for first, second in zip(timestamps, timestamps[1:]))
        / 1_000_000_000,
        9,
    )


def _matching_thrust_delay_ns(
    events: Sequence[Mapping[str, Any]], *, after_ns: int, expected: float
) -> int:
    match = _matching_value_event(
        events,
        after_ns=after_ns,
        deadline_ns=max(int(event["captured_unix_ns"]) for event in events),
        expected=expected,
    )
    if match is None:
        raise EvidenceError("a UDP servo frame has no matching thrust publication")
    return int(match["captured_unix_ns"]) - after_ns


def summarize_disarmed_events(
    pi_events: Sequence[Mapping[str, Any]],
    vrx_events: Sequence[Mapping[str, Any]],
    *,
    window_seconds: int,
) -> dict[str, Any]:
    """Measure, but do not choose, the limits for the armed Test B run."""
    if (
        isinstance(window_seconds, bool)
        or not isinstance(window_seconds, int)
        or window_seconds <= 0
    ):
        raise EvidenceError("window_seconds must be a positive integer")

    pi_config = _observer_config(pi_events, "pi")
    vrx_config = _observer_config(vrx_events, "vrx")
    for name in ("left_channel", "right_channel", "left", "right"):
        if pi_config[name] != vrx_config[name]:
            raise EvidenceError("Pi and VRX observer mapping or rails differ")

    start_ns = max(
        _measurement_ready_ns(pi_events, "pi"),
        _measurement_ready_ns(vrx_events, "vrx"),
    )
    end_ns = start_ns + window_seconds * 1_000_000_000
    for side, events in (("pi", pi_events), ("vrx", vrx_events)):
        if max(int(event["captured_unix_ns"]) for event in events) < end_ns:
            raise EvidenceError(f"{side} evidence does not cover the measurement window")

    pi_kinds = ("state", "sys_status", "rc_out", "camera")
    vrx_kinds = ("servo_output_raw", "left_thrust", "right_thrust", "pose")
    pi_series = {
        kind: _measurement_events(pi_events, kind, start_ns, end_ns)
        for kind in pi_kinds
    }
    vrx_series = {
        kind: _measurement_events(vrx_events, kind, start_ns, end_ns)
        for kind in vrx_kinds
    }

    if not all(
        event.get("connected") is True and event.get("armed") is False
        for event in pi_series["state"]
    ):
        raise EvidenceError("measurement state must stay connected and disarmed")
    if not all(
        event.get("hardware_safety_on") is True
        for event in pi_series["sys_status"]
    ):
        raise EvidenceError("measurement must keep hardware safety ON")

    left_trim = pi_config["left"]["trim"]
    right_trim = pi_config["right"]["trim"]
    if not all(
        event.get("left_pwm") == left_trim
        and event.get("right_pwm") == right_trim
        for event in pi_series["rc_out"]
    ):
        raise EvidenceError("Pi RC output was not neutral during measurement")
    if not all(
        event.get("left_pwm") == left_trim
        and event.get("right_pwm") == right_trim
        and math.isclose(float(event.get("left_thrust", math.nan)), 0.0, abs_tol=1e-6)
        and math.isclose(float(event.get("right_thrust", math.nan)), 0.0, abs_tol=1e-6)
        for event in vrx_series["servo_output_raw"]
    ):
        raise EvidenceError("UDP servo output was not neutral during measurement")
    for kind in ("left_thrust", "right_thrust"):
        if not all(
            _finite_number(event.get("value"))
            and math.isclose(float(event["value"]), 0.0, abs_tol=1e-6)
            for event in vrx_series[kind]
        ):
            raise EvidenceError("VRX thrust was not zero during measurement")

    rc_events = pi_series["rc_out"]
    raw_events = vrx_series["servo_output_raw"]
    for raw in raw_events:
        received = raw.get("bridge_received_unix_ns")
        if isinstance(received, bool) or not isinstance(received, int) or received <= 0:
            raise EvidenceError("UDP servo frame has no bridge receive timestamp")
    pwm_skews = [
        min(
            abs(int(raw["bridge_received_unix_ns"]) - int(rc["captured_unix_ns"]))
            for raw in raw_events
            if raw.get("left_pwm") == rc.get("left_pwm")
            and raw.get("right_pwm") == rc.get("right_pwm")
        )
        for rc in rc_events
    ]
    pwm_skews.extend(
        min(
            abs(int(raw["bridge_received_unix_ns"]) - int(rc["captured_unix_ns"]))
            for rc in rc_events
            if raw.get("left_pwm") == rc.get("left_pwm")
            and raw.get("right_pwm") == rc.get("right_pwm")
        )
        for raw in raw_events
    )

    left_events = _events(vrx_events, "left_thrust")
    right_events = _events(vrx_events, "right_thrust")
    thrust_delays = []
    for raw in raw_events:
        received = int(raw["bridge_received_unix_ns"])
        thrust_delays.append(
            _matching_thrust_delay_ns(
                left_events, after_ns=received, expected=float(raw["left_thrust"])
            )
        )
        thrust_delays.append(
            _matching_thrust_delay_ns(
                right_events, after_ns=received, expected=float(raw["right_thrust"])
            )
        )

    poses = vrx_series["pose"]
    baseline_x = float(poses[0].get("x", math.nan))
    baseline_y = float(poses[0].get("y", math.nan))
    if not math.isfinite(baseline_x) or not math.isfinite(baseline_y):
        raise EvidenceError("VRX pose contains a non-finite value")
    drift = 0.0
    for pose in poses:
        x = float(pose.get("x", math.nan))
        y = float(pose.get("y", math.nan))
        if not math.isfinite(x) or not math.isfinite(y):
            raise EvidenceError("VRX pose contains a non-finite value")
        drift = max(drift, math.hypot(x - baseline_x, y - baseline_y))

    return {
        "schema": SCHEMA,
        "verdict": "MEASURED",
        "window_seconds": window_seconds,
        "max_gap_seconds": {
            "pi": {kind: _max_gap_seconds(pi_series[kind]) for kind in pi_kinds},
            "vrx": {kind: _max_gap_seconds(vrx_series[kind]) for kind in vrx_kinds},
        },
        "max_pwm_skew_ms": round(max(pwm_skews) / 1_000_000, 6),
        "max_thrust_delay_ms": round(max(thrust_delays) / 1_000_000, 6),
        "stationary_pose_drift_metres": round(drift, 9),
        "sample_counts": {
            "pi": {kind: len(pi_series[kind]) for kind in pi_kinds},
            "vrx": {kind: len(vrx_series[kind]) for kind in vrx_kinds},
        },
    }


def adjudicate_events(
    pi_events: Sequence[Mapping[str, Any]],
    vrx_events: Sequence[Mapping[str, Any]],
    *,
    max_pwm_skew_ns: int,
    max_thrust_delay_ns: int,
    max_motion_delay_ns: int,
    min_motion_metres: float,
) -> dict[str, Any]:
    for name, value in (
        ("max_pwm_skew_ns", max_pwm_skew_ns),
        ("max_thrust_delay_ns", max_thrust_delay_ns),
        ("max_motion_delay_ns", max_motion_delay_ns),
    ):
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            raise EvidenceError(f"{name} must be a positive integer")
    if not _finite_number(min_motion_metres) or min_motion_metres <= 0.0:
        raise EvidenceError("min_motion_metres must be finite and greater than zero")

    for side, events in (("pi", pi_events), ("vrx", vrx_events)):
        if _events(events, "observer_abort"):
            raise EvidenceError(f"{side} observer recorded an abort")
        ready = [
            event
            for event in _events(events, "observer_ready")
            if event.get("side") == side
        ]
        if len(ready) != 1:
            raise EvidenceError(f"{side} observer did not record exactly one READY event")

    pi_config = _observer_config(pi_events, "pi")
    config = _observer_config(vrx_events, "vrx")
    for name in ("left_channel", "right_channel", "left", "right"):
        if pi_config[name] != config[name]:
            raise EvidenceError("Pi and VRX observer mapping or rails differ")

    states = _events(pi_events, "state")
    armed = next(
        (
            event
            for event in states
            if event.get("connected") is True and event.get("armed") is True
        ),
        None,
    )
    if armed is None:
        raise EvidenceError("no connected armed state was observed")
    armed_ns = int(armed["captured_unix_ns"])
    if not any(
        event.get("connected") is True
        and event.get("armed") is False
        and int(event["captured_unix_ns"]) < armed_ns
        for event in states
    ):
        raise EvidenceError("no connected disarmed baseline precedes arming")

    rc_events = _events(pi_events, "rc_out")
    excursion = None
    for event in rc_events:
        timestamp = int(event["captured_unix_ns"])
        if timestamp < armed_ns:
            continue
        left_pwm = event.get("left_pwm")
        right_pwm = event.get("right_pwm")
        if not _in_rail(config, "left", left_pwm) or not _in_rail(
            config, "right", right_pwm
        ):
            raise EvidenceError("dashboard servo output is outside the live-read rails")
        left_delta = left_pwm - config["left"]["trim"]
        right_delta = right_pwm - config["right"]["trim"]
        if (left_delta or right_delta) and left_delta != right_delta:
            excursion = event
            break
    if excursion is None:
        raise EvidenceError("no asymmetric dashboard servo excursion was observed")
    excursion_ns = int(excursion["captured_unix_ns"])

    raw_match = None
    for event in _events(vrx_events, "servo_output_raw"):
        received_ns = event.get("bridge_received_unix_ns")
        if isinstance(received_ns, bool) or not isinstance(received_ns, int):
            raise EvidenceError("UDP servo frame has no bridge receive timestamp")
        if abs(received_ns - excursion_ns) > max_pwm_skew_ns:
            continue
        if (
            event.get("left_pwm") == excursion["left_pwm"]
            and event.get("right_pwm") == excursion["right_pwm"]
        ):
            raw_match = event
            break
    if raw_match is None:
        raise EvidenceError("no matching UDP servo frame within the PWM skew limit")
    raw_received_ns = int(raw_match["bridge_received_unix_ns"])
    expected_left = pwm_to_thrust(config, "left", int(excursion["left_pwm"]))
    expected_right = pwm_to_thrust(config, "right", int(excursion["right_pwm"]))
    if not math.isclose(float(raw_match.get("left_thrust", math.nan)), expected_left, abs_tol=1e-6):
        raise EvidenceError("bridge left-thrust mapping does not match the live rail")
    if not math.isclose(float(raw_match.get("right_thrust", math.nan)), expected_right, abs_tol=1e-6):
        raise EvidenceError("bridge right-thrust mapping does not match the live rail")

    thrust_deadline = raw_received_ns + max_thrust_delay_ns
    left_thrust = _matching_value_event(
        _events(vrx_events, "left_thrust"),
        after_ns=raw_received_ns,
        deadline_ns=thrust_deadline,
        expected=expected_left,
    )
    right_thrust = _matching_value_event(
        _events(vrx_events, "right_thrust"),
        after_ns=raw_received_ns,
        deadline_ns=thrust_deadline,
        expected=expected_right,
    )
    if left_thrust is None or right_thrust is None:
        raise EvidenceError("bridge thrust topics did not match the UDP servo frame in time")

    poses = _events(vrx_events, "pose")
    baseline_pose = next(
        (
            event
            for event in reversed(poses)
            if int(event["captured_unix_ns"]) <= raw_received_ns
        ),
        None,
    )
    if baseline_pose is None:
        raise EvidenceError("no VRX pose baseline precedes the servo excursion")
    motion_metres = 0.0
    for pose in poses:
        timestamp = int(pose["captured_unix_ns"])
        if timestamp < raw_received_ns:
            continue
        if timestamp > raw_received_ns + max_motion_delay_ns:
            break
        distance = math.hypot(
            float(pose["x"]) - float(baseline_pose["x"]),
            float(pose["y"]) - float(baseline_pose["y"]),
        )
        motion_metres = max(motion_metres, distance)
    if motion_metres < min_motion_metres:
        raise EvidenceError("VRX motion threshold was not reached in time")

    neutral_rc = next(
        (
            event
            for event in rc_events
            if int(event["captured_unix_ns"]) > excursion_ns
            and event.get("left_pwm") == config["left"]["trim"]
            and event.get("right_pwm") == config["right"]["trim"]
        ),
        None,
    )
    if neutral_rc is None:
        raise EvidenceError("dashboard servo output did not return to neutral")
    neutral_rc_ns = int(neutral_rc["captured_unix_ns"])

    neutral_raw = next(
        (
            event
            for event in _events(vrx_events, "servo_output_raw")
            if int(event["bridge_received_unix_ns"]) > raw_received_ns
            and event.get("left_pwm") == config["left"]["trim"]
            and event.get("right_pwm") == config["right"]["trim"]
            and abs(int(event["bridge_received_unix_ns"]) - neutral_rc_ns)
            <= max_pwm_skew_ns
        ),
        None,
    )
    if neutral_raw is None:
        raise EvidenceError("UDP servo output did not correlate with neutral return")
    neutral_raw_ns = int(neutral_raw["bridge_received_unix_ns"])
    neutral_deadline = neutral_raw_ns + max_thrust_delay_ns
    if _matching_value_event(
        _events(vrx_events, "left_thrust"),
        after_ns=neutral_raw_ns,
        deadline_ns=neutral_deadline,
        expected=0.0,
    ) is None or _matching_value_event(
        _events(vrx_events, "right_thrust"),
        after_ns=neutral_raw_ns,
        deadline_ns=neutral_deadline,
        expected=0.0,
    ) is None:
        raise EvidenceError("VRX thrust did not return to zero in time")

    disarmed = next(
        (
            event
            for event in states
            if int(event["captured_unix_ns"]) > neutral_rc_ns
            and event.get("connected") is True
            and event.get("armed") is False
        ),
        None,
    )
    if disarmed is None:
        raise EvidenceError("connected disarm was not observed after neutral return")
    disarmed_ns = int(disarmed["captured_unix_ns"])
    safety = next(
        (
            event
            for event in _events(pi_events, "sys_status")
            if int(event["captured_unix_ns"]) >= disarmed_ns
            and event.get("hardware_safety_on") is True
        ),
        None,
    )
    if safety is None:
        raise EvidenceError("restored hardware safety was not observed after disarm")
    if not any(
        armed_ns <= int(event["captured_unix_ns"]) <= disarmed_ns
        for event in _events(pi_events, "camera")
    ):
        raise EvidenceError("no Hailo camera frame was observed during the armed window")

    return {
        "schema": SCHEMA,
        "verdict": "PASS",
        "pwm": {"left": excursion["left_pwm"], "right": excursion["right_pwm"]},
        "thrust": {"left": expected_left, "right": expected_right},
        "pwm_skew_ns": abs(int(raw_match["bridge_received_unix_ns"]) - excursion_ns),
        "motion_metres": motion_metres,
        "final": "connected-disarmed-neutral-hardware-safe",
    }


def _config_from_args(args: argparse.Namespace) -> dict[str, Any]:
    config = {
        "left_channel": args.left_channel,
        "right_channel": args.right_channel,
        "left": {
            "minimum": args.left_min,
            "trim": args.left_trim,
            "maximum": args.left_max,
        },
        "right": {
            "minimum": args.right_min,
            "trim": args.right_trim,
            "maximum": args.right_max,
        },
    }
    if args.side == "vrx":
        config["max_thrust"] = args.max_thrust
    return validate_config(config, require_max_thrust=args.side == "vrx")


def _validate_domain(side: str) -> None:
    expected = (
        {
            "ROS_DOMAIN_ID": "12",
            "ROS_AUTOMATIC_DISCOVERY_RANGE": "SUBNET",
        }
        if side == "pi"
        else {
            "ROS_DOMAIN_ID": "77",
            "ROS_AUTOMATIC_DISCOVERY_RANGE": "LOCALHOST",
            "ROS_LOCALHOST_ONLY": "1",
        }
    )
    for name, value in expected.items():
        if os.environ.get(name) != value:
            raise EvidenceError(f"{name} must be {value} for the {side} observer")
    if side == "pi" and os.environ.get("ROS_LOCALHOST_ONLY") not in (None, ""):
        raise EvidenceError("ROS_LOCALHOST_ONLY must be unset for the pi observer")


def _run_observer(args: argparse.Namespace) -> int:
    _validate_domain(args.side)
    config = _config_from_args(args)
    output = Path(args.output)
    status = Path(args.status)
    if output.exists() or status.exists():
        raise EvidenceError("observer output and status paths must not already exist")
    append_event(output, "observer_started", side=args.side, config=config)
    write_status(status, "WAIT_DATA", side=args.side)

    import rclpy
    from rclpy.node import Node
    from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
    from rclpy.signals import SignalHandlerOptions

    best_effort = QoSProfile(
        history=HistoryPolicy.KEEP_LAST,
        depth=10,
        reliability=ReliabilityPolicy.BEST_EFFORT,
        durability=DurabilityPolicy.VOLATILE,
    )

    class Observer(Node):
        def __init__(self) -> None:
            super().__init__(f"fcu_to_vrx_{args.side}_observer")
            self.failed = False
            self.ready = False
            self.pose_mismatch_reported = False
            self.last_pose_event_ns: int | None = None
            self.last_seen: dict[str, int] = {}
            if args.side == "pi":
                from mavros_msgs.msg import RCOut, State, SysStatus
                from sensor_msgs.msg import Image

                self.required = {"state", "rc_out", "sys_status", "camera"}
                self.create_subscription(State, "/mavros/state", self.state_cb, best_effort)
                self.create_subscription(RCOut, "/mavros/rc/out", self.rc_out_cb, best_effort)
                self.create_subscription(
                    SysStatus, "/mavros/sys_status", self.sys_status_cb, best_effort
                )
                self.create_subscription(
                    Image, "/hailo/overlay/image_raw", self.camera_cb, best_effort
                )
            else:
                from std_msgs.msg import Float64, String
                from tf2_msgs.msg import TFMessage

                self.required = {"servo_output_raw", "left_thrust", "right_thrust", "pose"}
                self.create_subscription(
                    String, args.servo_topic, self.servo_output_cb, 10
                )
                self.create_subscription(
                    Float64, args.left_thrust_topic, self.left_thrust_cb, 10
                )
                self.create_subscription(
                    Float64, args.right_thrust_topic, self.right_thrust_cb, 10
                )
                self.create_subscription(TFMessage, args.pose_topic, self.pose_cb, 10)
            self.create_timer(0.25, self.check_health)
            print(
                f"FCU_TO_VRX_{args.side.upper()}_OBSERVER_STARTED=PASS "
                f"topics={len(self.required)} publishers=0",
                flush=True,
            )

        def seen(self, kind: str) -> None:
            now = time.monotonic_ns()
            self.last_seen[kind] = now
            if not self.ready and required_streams_are_live(
                self.required, self.last_seen, now, args.stale_seconds
            ):
                self.ready = True
                append_event(output, "observer_ready", side=args.side)
                write_status(status, "READY", side=args.side)
                print(
                    f"FCU_TO_VRX_{args.side.upper()}_OBSERVER_READY=PASS "
                    f"topics={len(self.required)}",
                    flush=True,
                )

        def abort(self, reason: str) -> None:
            if self.failed:
                return
            self.failed = True
            append_event(output, "observer_abort", side=args.side, reason=reason)
            write_status(status, "ABORT", side=args.side, reason=reason)
            print(f"FCU_TO_VRX_OBSERVER_ABORT side={args.side} reason={reason}", flush=True)
            rclpy.try_shutdown()

        def check_health(self) -> None:
            if self.failed or args.stale_seconds == 0:
                return
            limit = args.stale_seconds * 1_000_000_000
            now = time.monotonic_ns()
            if not self.ready:
                first_raw = self.last_seen.get("servo_output_raw")
                if args.side == "vrx" and first_raw is not None \
                        and now - first_raw > limit:
                    missing = sorted(self.required - self.last_seen.keys())
                    self.abort("ready_timeout:" + ",".join(missing))
                return
            for kind in sorted(self.required):
                if now - self.last_seen[kind] > limit:
                    self.abort(f"stale_{kind}")
                    return

        def state_cb(self, message: Any) -> None:
            self.seen("state")
            append_event(
                output,
                "state",
                connected=bool(message.connected),
                armed=bool(message.armed),
                mode=str(message.mode),
            )

        def rc_out_cb(self, message: Any) -> None:
            channels = list(message.channels)
            if len(channels) < max(config["left_channel"], config["right_channel"]):
                self.abort("rc_out_channel_count")
                return
            left_pwm = int(channels[config["left_channel"] - 1])
            right_pwm = int(channels[config["right_channel"] - 1])
            if not _in_rail(config, "left", left_pwm) or not _in_rail(
                config, "right", right_pwm
            ):
                self.abort("rc_outside_live_rails")
                return
            self.seen("rc_out")
            append_event(output, "rc_out", left_pwm=left_pwm, right_pwm=right_pwm)

        def sys_status_cb(self, message: Any) -> None:
            enabled = int(message.sensors_enabled)
            self.seen("sys_status")
            append_event(
                output,
                "sys_status",
                sensors_enabled=enabled,
                hardware_safety_on=not bool(enabled & MOTOR_OUTPUTS_BIT),
            )

        def camera_cb(self, message: Any) -> None:
            stamp = getattr(getattr(message, "header", None), "stamp", None)
            source_stamp_ns = None
            if stamp is not None:
                source_stamp_ns = int(stamp.sec) * 1_000_000_000 + int(stamp.nanosec)
            self.seen("camera")
            append_event(output, "camera", source_stamp_ns=source_stamp_ns)

        def servo_output_cb(self, message: Any) -> None:
            try:
                payload = json.loads(message.data)
                if payload.get("schema") != SCHEMA or payload.get("kind") != "servo_output_raw":
                    raise EvidenceError("invalid bridge evidence schema")
                expected = bridge_servo_event(
                    config,
                    left_pwm=int(payload["left_pwm"]),
                    right_pwm=int(payload["right_pwm"]),
                    time_usec=int(payload["mavlink_time_usec"]),
                    received_unix_ns=int(payload["bridge_received_unix_ns"]),
                )
                if payload != expected:
                    raise EvidenceError("bridge evidence values do not match live configuration")
                if args.stale_seconds > 0 and (
                    not _in_rail(config, "left", int(payload["left_pwm"]))
                    or not _in_rail(config, "right", int(payload["right_pwm"]))
                ):
                    raise EvidenceError("bridge servo output is outside live rails")
            except (EvidenceError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
                self.abort(f"invalid_servo_output:{type(exc).__name__}")
                return
            self.seen("servo_output_raw")
            append_event(
                output,
                "servo_output_raw",
                **{key: value for key, value in payload.items() if key not in ("schema", "kind")},
            )

        def left_thrust_cb(self, message: Any) -> None:
            value = float(message.data)
            if not math.isfinite(value):
                self.abort("nonfinite_left_thrust")
                return
            self.seen("left_thrust")
            append_event(output, "left_thrust", value=value)

        def right_thrust_cb(self, message: Any) -> None:
            value = float(message.data)
            if not math.isfinite(value):
                self.abort("nonfinite_right_thrust")
                return
            self.seen("right_thrust")
            append_event(output, "right_thrust", value=value)

        def note_pose_frame_mismatch(self, message: Any) -> None:
            """Name a wrong or missing world frame once, instead of stalling silently."""
            if self.pose_mismatch_reported:
                return
            self.pose_mismatch_reported = True
            observed = observed_parent_frames(message.transforms)
            append_event(
                output,
                "pose_frame_mismatch",
                side=args.side,
                expected_frame=args.world_frame,
                observed_frames=observed,
            )
            print(
                f"FCU_TO_VRX_{args.side.upper()}_POSE_FRAME_MISMATCH "
                f"expected={args.world_frame} "
                f"observed={','.join(observed) if observed else 'none'}",
                flush=True,
            )

        def pose_cb(self, message: Any) -> None:
            transform = select_world_transform(
                message.transforms, args.world_frame
            )
            if transform is None:
                self.note_pose_frame_mismatch(message)
                return
            translation = transform.transform.translation
            self.seen("pose")
            # Readiness and staleness see every message; the retained stream
            # does not. VRX publishes pose at the simulator step rate, and the
            # pre-Pi hold lasts as long as the operator takes to start the Pi.
            now = time.monotonic_ns()
            if not pose_event_is_due(self.last_pose_event_ns, now):
                return
            self.last_pose_event_ns = now
            append_event(
                output,
                "pose",
                frame_id=str(transform.header.frame_id),
                child_frame_id=str(transform.child_frame_id),
                x=float(translation.x),
                y=float(translation.y),
                z=float(translation.z),
            )

    rclpy.init(signal_handler_options=SignalHandlerOptions.NO)
    node = Observer()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        failed = node.failed
        node.destroy_node()
        rclpy.try_shutdown()
        sync_evidence(output)
    return 70 if failed else 0


def _add_config_arguments(
    parser: argparse.ArgumentParser, *, include_max_thrust: bool
) -> None:
    parser.add_argument("--left-channel", type=int, required=True)
    parser.add_argument("--right-channel", type=int, required=True)
    parser.add_argument("--left-min", type=int, required=True)
    parser.add_argument("--left-trim", type=int, required=True)
    parser.add_argument("--left-max", type=int, required=True)
    parser.add_argument("--right-min", type=int, required=True)
    parser.add_argument("--right-trim", type=int, required=True)
    parser.add_argument("--right-max", type=int, required=True)
    if include_max_thrust:
        parser.add_argument("--max-thrust", type=float, required=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command, side in (("observe-pi", "pi"), ("observe-vrx", "vrx")):
        observer = subparsers.add_parser(command)
        observer.set_defaults(side=side)
        observer.add_argument("--output", required=True)
        observer.add_argument("--status", required=True)
        observer.add_argument("--stale-seconds", type=int, default=0)
        _add_config_arguments(observer, include_max_thrust=side == "vrx")
        if side == "vrx":
            observer.add_argument(
                "--servo-topic", default="/fcu_to_vrx/servo_output_raw"
            )
            observer.add_argument(
                "--left-thrust-topic", default="/wamv/thrusters/left/thrust"
            )
            observer.add_argument(
                "--right-thrust-topic", default="/wamv/thrusters/right/thrust"
            )
            observer.add_argument("--pose-topic", default="/wamv/pose")
            observer.add_argument("--world-frame", required=True)
    adjudicate = subparsers.add_parser("adjudicate")
    adjudicate.add_argument("--pi-events", required=True)
    adjudicate.add_argument("--vrx-events", required=True)
    adjudicate.add_argument("--max-pwm-skew-ms", type=int, required=True)
    adjudicate.add_argument("--max-thrust-delay-ms", type=int, required=True)
    adjudicate.add_argument("--max-motion-delay-seconds", type=float, required=True)
    adjudicate.add_argument("--min-motion-metres", type=float, required=True)
    summarize = subparsers.add_parser("summarize-disarmed")
    summarize.add_argument("--pi-events", required=True)
    summarize.add_argument("--vrx-events", required=True)
    summarize.add_argument("--window-seconds", type=int, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command.startswith("observe-"):
            if args.stale_seconds < 0:
                raise EvidenceError("stale_seconds must be zero or a positive integer")
            return _run_observer(args)
        if args.command == "summarize-disarmed":
            verdict = summarize_disarmed_events(
                read_events(Path(args.pi_events)),
                read_events(Path(args.vrx_events)),
                window_seconds=args.window_seconds,
            )
        else:
            verdict = adjudicate_events(
                read_events(Path(args.pi_events)),
                read_events(Path(args.vrx_events)),
                max_pwm_skew_ns=args.max_pwm_skew_ms * 1_000_000,
                max_thrust_delay_ns=args.max_thrust_delay_ms * 1_000_000,
                max_motion_delay_ns=int(args.max_motion_delay_seconds * 1_000_000_000),
                min_motion_metres=args.min_motion_metres,
            )
    except (EvidenceError, OSError) as exc:
        print(f"FCU_TO_VRX_EVIDENCE=FAIL reason={exc}", file=sys.stderr)
        return 1
    print(json.dumps(verdict, allow_nan=False, separators=(",", ":"), sort_keys=True))
    if args.command == "summarize-disarmed":
        print(
            "FCU_TO_VRX_DISARMED_MEASUREMENT=PASS "
            f"window_seconds={args.window_seconds} thresholds=not-selected"
        )
    else:
        print(
            "FCU_TO_VRX_EVIDENCE=PASS "
            "stages=dashboard-rc-out,udp-14555,bridge-thrust,vrx-motion "
            "final=connected-disarmed-neutral-hardware-safe"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
