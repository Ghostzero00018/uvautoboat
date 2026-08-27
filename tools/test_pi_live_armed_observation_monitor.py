#!/usr/bin/env python3
"""Focused tests for the Pi helper's opt-in armed-observation monitor."""

from __future__ import annotations

import os
from pathlib import Path
import re
import sys
import tempfile
import types
import unittest
from unittest import mock


HELPER = Path(__file__).with_name("pi_live_hailo_mavlink_dashboard.sh")
MOTOR_OUTPUTS_BIT = 32768


class _Message:
    def __init__(self, **values):
        self.__dict__.update(values)


class _QoSProfile:
    def __init__(self, **_values):
        pass


class _Node:
    def __init__(self, _name):
        self.subscriptions = {}
        self.timers = []

    def create_subscription(self, _message_type, topic, callback, _qos):
        self.subscriptions[topic] = callback
        return callback

    def create_timer(self, _period, callback):
        self.timers.append(callback)
        return callback


def _module(name: str, **values):
    result = types.ModuleType(name)
    for key, value in values.items():
        setattr(result, key, value)
    return result


def _fake_modules():
    message_types = {
        name: type(name, (), {})
        for name in (
            "BatteryState",
            "Bool",
            "Image",
            "Imu",
            "NavSatFix",
            "RCIn",
            "RCOut",
            "State",
            "String",
            "SysStatus",
            "Float64",
        )
    }
    rclpy = _module("rclpy", try_shutdown=lambda: None)
    return {
        "rclpy": rclpy,
        "rclpy.executors": _module(
            "rclpy.executors", ExternalShutdownException=RuntimeError
        ),
        "rclpy.node": _module("rclpy.node", Node=_Node),
        "rclpy.qos": _module(
            "rclpy.qos",
            DurabilityPolicy=types.SimpleNamespace(VOLATILE=0),
            HistoryPolicy=types.SimpleNamespace(KEEP_LAST=0),
            QoSProfile=_QoSProfile,
            ReliabilityPolicy=types.SimpleNamespace(BEST_EFFORT=0),
        ),
        "rclpy.signals": _module(
            "rclpy.signals", SignalHandlerOptions=types.SimpleNamespace(NO=0)
        ),
        "mavros_msgs": _module("mavros_msgs"),
        "mavros_msgs.msg": _module(
            "mavros_msgs.msg",
            RCIn=message_types["RCIn"],
            RCOut=message_types["RCOut"],
            State=message_types["State"],
            SysStatus=message_types["SysStatus"],
        ),
        "sensor_msgs": _module("sensor_msgs"),
        "sensor_msgs.msg": _module(
            "sensor_msgs.msg",
            BatteryState=message_types["BatteryState"],
            Image=message_types["Image"],
            Imu=message_types["Imu"],
            NavSatFix=message_types["NavSatFix"],
        ),
        "std_msgs": _module("std_msgs"),
        "std_msgs.msg": _module(
            "std_msgs.msg",
            Bool=message_types["Bool"],
            Float64=message_types["Float64"],
            String=message_types["String"],
        ),
    }


def _safety_monitor_definitions() -> str:
    source = HELPER.read_text(encoding="utf-8")
    match = re.search(
        r"cat >\"\$SAFETY_MONITOR\" <<'PYTHON_SAFETY'\n(.*?)\nPYTHON_SAFETY",
        source,
        re.DOTALL,
    )
    if match is None:
        raise AssertionError("safety monitor heredoc is not extractable")
    program = match.group(1)
    marker = "rclpy.init(signal_handler_options=SignalHandlerOptions.NO)"
    if marker not in program:
        raise AssertionError("safety monitor entry point changed")
    return program.split(marker, 1)[0]


class ArmedObservationMonitorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.abort_file = self.root / "abort.txt"
        self.status_file = self.root / "status.txt"
        self.enable_file = self.root / "enable"
        self.clock = [100.0]

    def _load(self, enabled: bool, *, max_seconds: str = "30"):
        environment = {
            "COMMAND_ABORT_FILE": str(self.abort_file),
            "ARMED_OBSERVATION": "1" if enabled else "0",
            "ARMED_OBSERVATION_STATUS_FILE": str(self.status_file),
            "ARMED_OBSERVATION_ENABLE_FILE": str(self.enable_file),
            "ARMED_OBSERVATION_MAX_SECONDS": max_seconds,
            "ARMED_OBSERVATION_FINAL_SECONDS": "10",
            "ARMED_OBSERVATION_STALE_SECONDS": "5",
            "ARMED_OBSERVATION_LEFT_CHANNEL": "3",
            "ARMED_OBSERVATION_LEFT_TRIM": "800",
            "ARMED_OBSERVATION_RIGHT_CHANNEL": "1",
            "ARMED_OBSERVATION_RIGHT_TRIM": "800",
        }
        namespace = {"__name__": "armed_observation_test"}
        fake_modules = _fake_modules()
        fake_modules["time"] = _module(
            "time", monotonic=lambda: self.clock[0]
        )
        with mock.patch.dict(os.environ, environment, clear=False), mock.patch.dict(
            sys.modules, fake_modules
        ):
            exec(_safety_monitor_definitions(), namespace)
            node = namespace["DashboardSafetyMonitor"]()
        return node

    def _phase(self) -> str:
        for line in self.status_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("phase="):
                return line.split("=", 1)[1]
        self.fail("monitor status has no phase")

    def _abort_reason(self) -> str:
        line = self.abort_file.read_text(encoding="utf-8").splitlines()[0]
        return line.split()[0].split("=", 1)[1]

    def _publish_required(
        self,
        node,
        *,
        armed: bool = False,
        connected: bool = True,
        left: int = 800,
        right: int = 800,
        safety_on: bool = True,
    ) -> None:
        node.subscriptions["/mavros/state"](
            _Message(armed=armed, connected=connected)
        )
        for topic in (
            "/mavros/global_position/raw/fix",
            "/mavros/imu/data",
            "/mavros/battery",
            "/mavros/rc/in",
            "/hailo/overlay/image_raw",
        ):
            node.subscriptions[topic](_Message())
        channels = [right, 1500, left]
        node.subscriptions["/mavros/rc/out"](_Message(channels=channels))
        sensors_enabled = 0 if safety_on else MOTOR_OUTPUTS_BIT
        node.subscriptions["/mavros/sys_status"](
            _Message(sensors_enabled=sensors_enabled)
        )

    def _ready(self, node) -> None:
        self.enable_file.touch()
        self._publish_required(node)
        node.timers[0]()
        self.assertEqual(self._phase(), "READY")

    def test_selector_off_preserves_unconditional_armed_abort(self):
        node = self._load(False)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.assertEqual(self._abort_reason(), "FCU_ARMED")
        self.assertEqual(len(node.subscriptions), 6)
        self.assertEqual(node.timers, [])

    def test_enabled_selector_rejects_armed_start_before_baseline(self):
        node = self._load(True)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.assertEqual(self._abort_reason(), "FCU_ARMED_BEFORE_BASELINE")

    def test_baseline_requires_fresh_neutral_and_hardware_safe_topics(self):
        node = self._load(True)
        self._publish_required(node)
        node.timers[0]()
        self.assertEqual(self._phase(), "WAIT_BASELINE")

        self.enable_file.touch()
        self._publish_required(node, left=801)
        node.timers[0]()
        self.assertEqual(self._phase(), "WAIT_BASELINE")

        self._publish_required(node, safety_on=False)
        node.timers[0]()
        self.assertEqual(self._phase(), "WAIT_BASELINE")

        self._publish_required(node)
        node.timers[0]()
        self.assertEqual(self._phase(), "READY")

    def test_one_armed_window_completes_only_after_neutral_safe_disarm(self):
        node = self._load(True)
        self._ready(node)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.assertEqual(self._phase(), "ARMED")

        self._publish_required(
            node, armed=False, left=950, right=900, safety_on=False
        )
        node.timers[0]()
        self.assertEqual(self._phase(), "FINALIZING")

        self._publish_required(node, armed=False, safety_on=True)
        node.timers[0]()
        self.assertEqual(self._phase(), "COMPLETE")
        self.assertFalse(self.abort_file.exists())

        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.assertEqual(self._abort_reason(), "UNEXPECTED_SECOND_ARM")

    def test_disconnect_stale_topic_and_armed_deadline_fail_closed(self):
        node = self._load(True)
        self._ready(node)
        node.subscriptions["/mavros/state"](_Message(armed=False, connected=False))
        self.assertEqual(self._abort_reason(), "FCU_DISCONNECTED")

        self.abort_file.unlink()
        self.status_file.unlink()
        node = self._load(True)
        self._ready(node)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.clock[0] += 6
        node.timers[0]()
        self.assertEqual(self._abort_reason(), "REQUIRED_TOPIC_STALE")

        self.abort_file.unlink()
        self.status_file.unlink()
        node = self._load(True)
        self._ready(node)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self.clock[0] += 31
        self._publish_required(node, armed=True, safety_on=False)
        node.timers[0]()
        self.assertEqual(self._abort_reason(), "ARMED_WINDOW_DEADLINE")

    def test_final_restoration_has_its_own_deadline(self):
        node = self._load(True)
        self._ready(node)
        node.subscriptions["/mavros/state"](_Message(armed=True, connected=True))
        self._publish_required(
            node, armed=False, left=950, right=900, safety_on=False
        )
        self.assertEqual(self._phase(), "FINALIZING")
        self.clock[0] += 11
        self._publish_required(
            node, armed=False, left=950, right=900, safety_on=False
        )
        node.timers[0]()
        self.assertEqual(self._abort_reason(), "FINAL_STATE_DEADLINE")

    def test_zero_armed_deadline_keeps_other_fail_closed_checks_active(self):
        node = self._load(True, max_seconds="0")
        self._ready(node)
        node.subscriptions["/mavros/state"](
            _Message(armed=True, connected=True)
        )
        self.clock[0] += 3600
        self._publish_required(node, armed=True, safety_on=False)
        node.timers[0]()
        self.assertEqual(self._phase(), "ARMED")
        self.assertFalse(self.abort_file.exists())

        self.clock[0] += 6
        node.timers[0]()
        self.assertEqual(self._abort_reason(), "REQUIRED_TOPIC_STALE")

    def test_monitor_remains_subscriber_only(self):
        source = _safety_monitor_definitions()
        self.assertNotIn("create_publisher", source)
        self.assertNotIn("create_client", source)

    def test_shell_supervisor_wires_the_selector_into_live_and_final_gates(self):
        source = HELPER.read_text(encoding="utf-8")
        for contract in (
            'ARMED_OBSERVATION="${LIVE_ARMED_OBSERVATION:-0}"',
            "validate_armed_observation() {",
            "enable_armed_observation() {",
            'require_connected_observation_state "$context" "$deadline"',
            'require_armed_observation_complete "$FINAL_VERIFY_DEADLINE"',
            '"ARMED_OBSERVATION=$ARMED_OBSERVATION"',
        ):
            self.assertIn(contract, source)


if __name__ == "__main__":
    unittest.main()
