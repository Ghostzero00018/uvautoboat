#!/usr/bin/env python3
"""Focused tests for the non-reusable SITL operator action helper."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).with_name("sitl_operator_once.py")
SPEC = importlib.util.spec_from_file_location("sitl_operator_once", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class FakeMessage:
    def __init__(self, message_type, **values):
        self._message_type = message_type
        self.__dict__.update(values)

    def get_srcSystem(self):
        return MODULE.TARGET_SYSTEM

    def get_srcComponent(self):
        return MODULE.TARGET_COMPONENT

    def get_type(self):
        return self._message_type


class FakeMav:
    def __init__(self):
        self.set_mode_calls = []
        self.command_long_calls = []

    def set_mode_send(self, *args):
        self.set_mode_calls.append(args)

    def command_long_send(self, *args):
        self.command_long_calls.append(args)


class FakeConnection:
    def __init__(self, messages):
        self.messages = list(messages)
        self.mav = FakeMav()
        self.closed = False

    def recv_match(self, *, blocking, **_kwargs):
        if not blocking:
            return None
        if self.messages:
            return self.messages.pop(0)
        return None

    def close(self):
        self.closed = True


def gate_for(action):
    return {
        "schema": MODULE.SCHEMA,
        "action": action,
        "run_dir": "/tmp/example-run",
        "endpoint": MODULE.ENDPOINT,
        "source_system": MODULE.SOURCE_SYSTEM,
        "source_component": MODULE.SOURCE_COMPONENT,
        "target_system": MODULE.TARGET_SYSTEM,
        "target_component": MODULE.TARGET_COMPONENT,
        "deadline_unix_ns": time.time_ns() + 30_000_000_000,
        "nonce": "0123456789abcdef0123456789abcdef",
    }


class GateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.run_dir = Path(self.temporary.name).resolve()
        (self.run_dir / "operator").mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def write_gate(self, action="arm", deadline_offset_ns=30_000_000_000):
        gate = gate_for(action)
        gate["run_dir"] = str(self.run_dir)
        gate["deadline_unix_ns"] = time.time_ns() + deadline_offset_ns
        path = self.run_dir / "operator" / f"{action}.gate.json"
        path.write_text(json.dumps(gate), encoding="utf-8")
        return gate

    def test_loads_only_the_fixed_absolute_gate(self):
        expected = self.write_gate("arm")
        gate = MODULE.load_gate(str(self.run_dir), "arm")
        self.assertEqual(gate["endpoint"], MODULE.ENDPOINT)
        self.assertEqual(gate["nonce"], expected["nonce"])
        with self.assertRaisesRegex(MODULE.OperatorError, "must be absolute"):
            MODULE.load_gate("relative-run", "arm")

    def test_rejects_expiry_drift_and_reuse(self):
        self.write_gate("disarm", deadline_offset_ns=-1)
        with self.assertRaisesRegex(MODULE.OperatorError, "expired"):
            MODULE.load_gate(str(self.run_dir), "disarm")

        gate = self.write_gate("arm")
        path = self.run_dir / "operator" / "arm.gate.json"
        gate["source_system"] = 255
        path.write_text(json.dumps(gate), encoding="utf-8")
        with self.assertRaisesRegex(MODULE.OperatorError, "source_system"):
            MODULE.load_gate(str(self.run_dir), "arm")

        gate = self.write_gate("safety-off")
        loaded = MODULE.load_gate(str(self.run_dir), "safety-off")
        MODULE.claim_gate(loaded)
        with self.assertRaisesRegex(MODULE.OperatorError, "already claimed"):
            MODULE.claim_gate(loaded)

    def test_claimed_failure_is_recorded_and_cannot_be_retried(self):
        self.write_gate("arm")
        with mock.patch.object(
            MODULE, "execute_action", side_effect=MODULE.OperatorError("rejected")
        ):
            self.assertEqual(
                MODULE.main(["--run-dir", str(self.run_dir), "--action", "arm"]),
                1,
            )
        result = json.loads(
            (self.run_dir / "operator" / "arm.json").read_text(encoding="utf-8")
        )
        self.assertFalse(result["success"])
        self.assertIn("OperatorError: rejected", result["error"])
        with self.assertRaisesRegex(MODULE.OperatorError, "already claimed or complete"):
            MODULE.load_gate(str(self.run_dir), "arm")


class ActionTest(unittest.TestCase):
    def run_with_connection(self, gate, messages):
        connection = FakeConnection(messages)
        calls = []

        def factory(endpoint, **kwargs):
            calls.append((endpoint, kwargs))
            return connection

        result = MODULE.execute_action(gate, connection_factory=factory)
        self.assertTrue(connection.closed)
        self.assertEqual(calls[0][0], MODULE.ENDPOINT)
        self.assertEqual(calls[0][1]["source_system"], MODULE.SOURCE_SYSTEM)
        self.assertEqual(calls[0][1]["source_component"], MODULE.SOURCE_COMPONENT)
        self.assertFalse(calls[0][1]["autoreconnect"])
        return result, connection

    def test_safety_off_sends_the_exact_safety_only_set_mode(self):
        messages = [
            FakeMessage("HEARTBEAT"),
            FakeMessage(
                "SYS_STATUS",
                onboard_control_sensors_enabled=(
                    MODULE.mavutil.mavlink.MAV_SYS_STATUS_SENSOR_MOTOR_OUTPUTS
                ),
            ),
        ]
        result, connection = self.run_with_connection(gate_for("safety-off"), messages)
        self.assertTrue(result["success"])
        self.assertEqual(
            connection.mav.set_mode_calls,
            [(
                MODULE.TARGET_SYSTEM,
                MODULE.mavutil.mavlink.MAV_MODE_FLAG_DECODE_POSITION_SAFETY,
                0,
            )],
        )
        self.assertEqual(connection.mav.command_long_calls, [])

    def test_arm_and_disarm_have_no_force_value_or_unused_parameters(self):
        command = MODULE.mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM
        accepted = MODULE.mavutil.mavlink.MAV_RESULT_ACCEPTED
        armed_bit = MODULE.mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED
        for action, requested, heartbeat_mode in (
            ("arm", 1.0, armed_bit),
            ("disarm", 0.0, 0),
        ):
            with self.subTest(action=action):
                messages = [
                    FakeMessage("HEARTBEAT"),
                    FakeMessage("COMMAND_ACK", command=command, result=accepted),
                    FakeMessage(
                        "HEARTBEAT", base_mode=heartbeat_mode, custom_mode=0
                    ),
                ]
                result, connection = self.run_with_connection(
                    gate_for(action), messages
                )
                self.assertTrue(result["success"])
                self.assertEqual(len(connection.mav.command_long_calls), 1)
                self.assertEqual(
                    connection.mav.command_long_calls[0],
                    (
                        MODULE.TARGET_SYSTEM,
                        MODULE.TARGET_COMPONENT,
                        command,
                        0,
                        requested,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                    ),
                )
                self.assertEqual(connection.mav.set_mode_calls, [])


if __name__ == "__main__":
    unittest.main()
