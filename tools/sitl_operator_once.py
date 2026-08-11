#!/usr/bin/env python3
"""Execute one gate-authorised simulator safety, arm, or disarm action."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import time
from typing import Any, Callable, Mapping

from pymavlink import mavutil


SCHEMA = "uvautoboat.sitl.operator.v1"
ENDPOINT = "tcp:127.0.0.1:5762"
SOURCE_SYSTEM = 254
SOURCE_COMPONENT = 190
TARGET_SYSTEM = 1
TARGET_COMPONENT = 1
ALLOWED_ACTIONS = ("safety-off", "arm", "disarm")


class OperatorError(RuntimeError):
    """Raised when a one-shot action cannot satisfy its closed contract."""


def atomic_write_json(path: Path, payload: Mapping[str, Any]) -> None:
    """Write one complete JSON object without exposing a partial result."""
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


def _exact_int(name: str, value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise OperatorError(f"gate {name} is not an integer")
    return value


def load_gate(run_dir_arg: str, action: str, now_ns: int | None = None) -> dict[str, Any]:
    """Load and validate the action-specific, finite, non-reusable gate."""
    if action not in ALLOWED_ACTIONS:
        raise OperatorError(f"unsupported action: {action}")
    run_dir = Path(run_dir_arg)
    if not run_dir.is_absolute():
        raise OperatorError("run directory must be absolute")
    try:
        resolved_run_dir = run_dir.resolve(strict=True)
    except OSError as exc:
        raise OperatorError(f"run directory is unavailable: {run_dir}") from exc
    operator_dir = resolved_run_dir / "operator"
    if not operator_dir.is_dir():
        raise OperatorError(f"operator directory is unavailable: {operator_dir}")

    result_path = operator_dir / f"{action}.json"
    claim_path = operator_dir / f"{action}.claim.json"
    if result_path.exists() or claim_path.exists():
        raise OperatorError(f"action is already claimed or complete: {action}")

    gate_path = operator_dir / f"{action}.gate.json"
    try:
        gate = json.loads(gate_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise OperatorError(f"action gate is unreadable: {gate_path}") from exc
    if not isinstance(gate, dict):
        raise OperatorError("action gate must be a JSON object")

    expected = {
        "schema": SCHEMA,
        "action": action,
        "run_dir": str(resolved_run_dir),
        "endpoint": ENDPOINT,
        "source_system": SOURCE_SYSTEM,
        "source_component": SOURCE_COMPONENT,
        "target_system": TARGET_SYSTEM,
        "target_component": TARGET_COMPONENT,
    }
    for name, value in expected.items():
        if gate.get(name) != value:
            raise OperatorError(f"gate {name} does not match the fixed contract")
    for name in (
        "source_system", "source_component", "target_system", "target_component"
    ):
        _exact_int(name, gate[name])
    nonce = gate.get("nonce")
    if not isinstance(nonce, str) or len(nonce) < 16:
        raise OperatorError("gate nonce is missing or too short")
    deadline_ns = _exact_int("deadline_unix_ns", gate.get("deadline_unix_ns"))
    current_ns = time.time_ns() if now_ns is None else now_ns
    if deadline_ns <= current_ns:
        raise OperatorError("action gate has expired")

    gate["run_dir"] = str(resolved_run_dir)
    gate["gate_path"] = str(gate_path)
    gate["claim_path"] = str(claim_path)
    gate["result_path"] = str(result_path)
    return gate


def claim_gate(gate: Mapping[str, Any]) -> None:
    """Claim a gate exactly once before opening a MAVLink connection."""
    claim_path = Path(str(gate["claim_path"]))
    payload = {
        "schema": SCHEMA,
        "action": gate["action"],
        "nonce": gate["nonce"],
        "claimed_unix_ns": time.time_ns(),
        "pid": os.getpid(),
    }
    encoded = json.dumps(payload, separators=(",", ":"), sort_keys=True) + "\n"
    try:
        descriptor = os.open(
            claim_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
        )
    except FileExistsError as exc:
        raise OperatorError(f"action is already claimed: {gate['action']}") from exc
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        stream.write(encoded)
        stream.flush()
        os.fsync(stream.fileno())


def _remaining_seconds(gate: Mapping[str, Any]) -> float:
    remaining = (int(gate["deadline_unix_ns"]) - time.time_ns()) / 1_000_000_000
    if remaining <= 0.0:
        raise OperatorError("action deadline expired")
    return remaining


def _message_is_from_target(message: Any, gate: Mapping[str, Any]) -> bool:
    return (
        int(message.get_srcSystem()) == int(gate["target_system"])
        and int(message.get_srcComponent()) == int(gate["target_component"])
    )


def _wait_for_target_heartbeat(connection: Any, gate: Mapping[str, Any]) -> Any:
    deadline_ns = int(gate["deadline_unix_ns"])
    while time.time_ns() < deadline_ns:
        message = connection.recv_match(
            type="HEARTBEAT",
            blocking=True,
            timeout=min(1.0, _remaining_seconds(gate)),
        )
        if message is not None and _message_is_from_target(message, gate):
            return message
    raise OperatorError("target 1.1 heartbeat was not received before the deadline")


def _drain_connection(connection: Any) -> None:
    while connection.recv_match(blocking=False) is not None:
        pass


def _run_safety_off(connection: Any, gate: Mapping[str, Any]) -> dict[str, Any]:
    flag = mavutil.mavlink.MAV_MODE_FLAG_DECODE_POSITION_SAFETY
    connection.mav.set_mode_send(int(gate["target_system"]), flag, 0)
    sent_unix_ns = time.time_ns()
    deadline_ns = int(gate["deadline_unix_ns"])
    while time.time_ns() < deadline_ns:
        message = connection.recv_match(
            type="SYS_STATUS",
            blocking=True,
            timeout=min(1.0, _remaining_seconds(gate)),
        )
        if message is None or not _message_is_from_target(message, gate):
            continue
        enabled = int(message.onboard_control_sensors_enabled)
        motor_bit = mavutil.mavlink.MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS
        if enabled & motor_bit:
            return {
                "sent_unix_ns": sent_unix_ns,
                "observed_unix_ns": time.time_ns(),
                "set_mode_base_mode": flag,
                "set_mode_custom_mode": 0,
                "motor_outputs_enabled": True,
            }
    raise OperatorError("fresh SYS_STATUS did not report motor outputs enabled")


def _run_arm_disarm(
    connection: Any, gate: Mapping[str, Any], arm: bool
) -> dict[str, Any]:
    command = mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM
    requested = 1.0 if arm else 0.0
    connection.mav.command_long_send(
        int(gate["target_system"]),
        int(gate["target_component"]),
        command,
        0,
        requested,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
    )
    sent_unix_ns = time.time_ns()
    accepted_ack = None
    matching_heartbeat = None
    deadline_ns = int(gate["deadline_unix_ns"])
    while time.time_ns() < deadline_ns:
        message = connection.recv_match(
            type=["COMMAND_ACK", "HEARTBEAT"],
            blocking=True,
            timeout=min(1.0, _remaining_seconds(gate)),
        )
        if message is None or not _message_is_from_target(message, gate):
            continue
        message_type = message.get_type()
        if message_type == "COMMAND_ACK" and int(message.command) == command:
            result = int(message.result)
            if result != mavutil.mavlink.MAV_RESULT_ACCEPTED:
                raise OperatorError(f"arm/disarm acknowledgement was not accepted: {result}")
            accepted_ack = {
                "command": command,
                "result": result,
                "observed_unix_ns": time.time_ns(),
            }
        elif message_type == "HEARTBEAT":
            armed = bool(
                int(message.base_mode) & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
            )
            if armed == arm:
                matching_heartbeat = {
                    "armed": armed,
                    "base_mode": int(message.base_mode),
                    "custom_mode": int(message.custom_mode),
                    "observed_unix_ns": time.time_ns(),
                }
        if accepted_ack is not None and matching_heartbeat is not None:
            return {
                "sent_unix_ns": sent_unix_ns,
                "command": command,
                "param1": requested,
                "param2": 0.0,
                "ack": accepted_ack,
                "heartbeat": matching_heartbeat,
            }
    raise OperatorError("accepted acknowledgement and matching heartbeat were not both received")


def execute_action(
    gate: Mapping[str, Any],
    connection_factory: Callable[..., Any] = mavutil.mavlink_connection,
) -> dict[str, Any]:
    """Open one non-reconnecting connection and emit the sole allowed request."""
    connection = connection_factory(
        str(gate["endpoint"]),
        source_system=int(gate["source_system"]),
        source_component=int(gate["source_component"]),
        autoreconnect=False,
        dialect="ardupilotmega",
    )
    try:
        _wait_for_target_heartbeat(connection, gate)
        _drain_connection(connection)
        action = str(gate["action"])
        if action == "safety-off":
            observation = _run_safety_off(connection, gate)
        elif action == "arm":
            observation = _run_arm_disarm(connection, gate, True)
        elif action == "disarm":
            observation = _run_arm_disarm(connection, gate, False)
        else:
            raise OperatorError(f"unsupported action: {action}")
        return {
            "schema": SCHEMA,
            "action": action,
            "success": True,
            "nonce": gate["nonce"],
            "endpoint": gate["endpoint"],
            "source_system": gate["source_system"],
            "source_component": gate["source_component"],
            "target_system": gate["target_system"],
            "target_component": gate["target_component"],
            "completed_unix_ns": time.time_ns(),
            "observation": observation,
        }
    finally:
        connection.close()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Execute one runner-gated SITL safety, arm, or disarm request."
    )
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--action", required=True, choices=ALLOWED_ACTIONS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    gate: dict[str, Any] | None = None
    claimed = False
    try:
        gate = load_gate(args.run_dir, args.action)
        claim_gate(gate)
        claimed = True
        result = execute_action(gate)
    except Exception as exc:  # Preserve a result after any claimed transport attempt.
        if gate is None or not claimed:
            print(f"sitl_operator_once: {exc}", file=sys.stderr)
            return 1
        result = {
            "schema": SCHEMA,
            "action": gate["action"],
            "success": False,
            "nonce": gate["nonce"],
            "completed_unix_ns": time.time_ns(),
            "error": f"{type(exc).__name__}: {exc}",
        }
        atomic_write_json(Path(str(gate["result_path"])), result)
        print(f"sitl_operator_once: {result['error']}", file=sys.stderr)
        return 1

    assert gate is not None
    result_path = Path(str(gate["result_path"]))
    atomic_write_json(result_path, result)
    print(
        f"SITL_OPERATOR_RESULT action={gate['action']} success=true path={result_path}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
