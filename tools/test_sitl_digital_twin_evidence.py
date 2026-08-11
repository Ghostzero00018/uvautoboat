#!/usr/bin/env python3
"""Focused pure-state tests for the SITL evidence recorder and evaluator."""

from __future__ import annotations

import importlib.util
import inspect
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_PATH = Path(__file__).with_name("sitl_digital_twin_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "sitl_digital_twin_evidence", MODULE_PATH
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def rail():
    return {"minimum": 1000, "trim": 1500, "maximum": 2000, "reversed": 0}


def snapshot():
    return {
        "schema": MODULE.SCHEMA,
        "parameter_count": MODULE.EXPECTED_PARAMETER_COUNT,
        "parameters": {
            "RC_OVERRIDE_TIME": 0.5,
            "ARMING_RUDDER": 0.0,
            "BRD_SAFETY_DEFLT": 1.0,
        },
        "guard": {
            "steering_channel": 1,
            "throttle_channel": 3,
            "left_servo": 1,
            "right_servo": 3,
            "steering_rail": {**rail(), "dead_zone": 30},
            "throttle_rail": {**rail(), "dead_zone": 30},
            "left_servo_rail": rail(),
            "right_servo_rail": rail(),
            "values": {},
        },
    }


def valid_snapshot_values():
    values = {
        "SYSID_THISMAV": 1,
        "SYSID_MYGCS": 255,
        "SYSID_ENFORCE": 0,
        "SERIAL0_PROTOCOL": 2,
        "SERIAL1_PROTOCOL": 2,
        "SIM_SPEEDUP": 1,
        "SIM_RATE_HZ": 400,
        "BRD_SAFETY_DEFLT": 1,
        "BRD_SAFETY_MASK": 0,
        "BRD_SAFETYOPTION": 0,
        "ARMING_CHECK": 0,
        "ARMING_RUDDER": 0,
        "ARMING_REQUIRE": 1,
        "FRAME_CLASS": 2,
        "PILOT_STEER_TYPE": 0,
        "MODE_CH": 8,
        "RC_OPTIONS": 0,
        "RC_OVERRIDE_TIME": 0.5,
        "RCMAP_ROLL": 1,
        "RCMAP_THROTTLE": 3,
        "SCR_ENABLE": 0,
        "SERVO_32_ENABLE": 0,
        "FS_THR_ENABLE": 0,
        "FS_THR_VALUE": 950,
        "FS_TIMEOUT": 5,
        "FS_ACTION": 0,
        "FS_OPTIONS": 0,
        "FS_GCS_ENABLE": 0,
        "FS_GCS_TIMEOUT": 5,
        "DDS_ENABLE": 0,
    }
    for channel in range(1, 17):
        values[f"RC{channel}_OPTION"] = 0
        values[f"SERVO{channel}_FUNCTION"] = 0
    values["SERVO1_FUNCTION"] = 73
    values["SERVO3_FUNCTION"] = 74
    for channel in (1, 3):
        values.update({
            f"RC{channel}_MIN": 1000,
            f"RC{channel}_TRIM": 1500,
            f"RC{channel}_MAX": 2000,
            f"RC{channel}_DZ": 30,
            f"RC{channel}_REVERSED": 0,
            f"SERVO{channel}_MIN": 1000,
            f"SERVO{channel}_TRIM": 1500,
            f"SERVO{channel}_MAX": 2000,
            f"SERVO{channel}_REVERSED": 0,
        })
    return values


def status_payload(state, *, armed, steering=0.0, throttle=0.0, left=1500, right=1500):
    return {
        "state": state,
        "fault": state,
        "ready": state in ("READY_DISARMED", "ARMED_NEUTRAL", "ACTIVE"),
        "connected": True,
        "armed": armed,
        "mode": "MANUAL",
        "command": {"steering": steering, "throttle": throttle},
        "feedback_fresh": True,
        "resolved": {
            "steering_rc": 1,
            "throttle_rc": 3,
            "left_servo": 1,
            "right_servo": 3,
        },
        "measured": {
            "rc_steering_pwm": 1500,
            "rc_throttle_pwm": 1500,
            "left_servo_pwm": left,
            "right_servo_pwm": right,
        },
    }


def joy(steering, throttle, enabled):
    return {
        "header": {"frame_id": MODULE.FRAME_ID, "stamp": {"sec": 1, "nanosec": 0}},
        "axes": [steering, throttle],
        "buttons": [1 if enabled else 0],
    }


def operator_result(action, sent_time):
    return {
        "schema": "uvautoboat.sitl.operator.v1",
        "action": action,
        "success": True,
        "observation": {"sent_unix_ns": sent_time},
    }


class EvidenceTrackerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.run_dir = Path(self.temporary.name)
        for directory in ("captures", "control", "evidence", "manifest", "operator"):
            (self.run_dir / directory).mkdir()
        (self.run_dir / "manifest" / "repository.txt").write_text(
            "revision=test\n", encoding="utf-8"
        )
        MODULE.atomic_write_json(
            self.run_dir / "manifest" / "mavros_snapshot.json", snapshot()
        )
        self.tracker = MODULE.EvidenceTracker(self.run_dir, snapshot())

    def tearDown(self):
        self.temporary.cleanup()

    def write_operator(self, action, sent_time):
        MODULE.atomic_write_json(
            self.run_dir / "operator" / f"{action}.json",
            operator_result(action, sent_time),
        )

    def ingest_status(self, payload, timestamp):
        self.tracker.ingest(
            "/command_ingress/status", {"data": json.dumps(payload)}, timestamp
        )

    def ingest_state(self, armed, timestamp, *, connected=True, mode="MANUAL"):
        self.tracker.ingest(
            "/mavros/state",
            {
                "connected": connected,
                "armed": armed,
                "mode": mode,
                "system_status": 4,
            },
            timestamp,
        )

    def ingest_override(self, timestamp):
        channels = [65535] * 18
        channels[0] = 0
        channels[2] = 0
        self.tracker.ingest(
            "/mavros/rc/override", {"channels": channels}, timestamp
        )

    def test_complete_ordered_capture_reaches_one_passing_verdict(self):
        self.ingest_state(False, 100)
        self.ingest_status(
            status_payload("WAITING_DISARMED_NEUTRAL_RC", armed=False), 101
        )
        self.assertTrue((self.run_dir / "evidence" / "startup.json").is_file())

        self.write_operator("safety-off", 110)
        self.ingest_state(False, 120)
        self.ingest_status(status_payload("READY_DISARMED", armed=False), 121)

        self.tracker.set_command_publisher_count(1)
        self.tracker.ingest("/command_ingress/rc_axes", joy(0.0, 0.0, False), 130)

        self.write_operator("arm", 140)
        self.ingest_state(True, 150)
        self.ingest_status(status_payload("ARMED_NEUTRAL", armed=True), 151)

        self.tracker.ingest("/command_ingress/rc_axes", joy(0.10, 0.08, True), 160)
        self.ingest_status(
            status_payload(
                "ACTIVE", armed=True, steering=0.10, throttle=0.08,
                left=1600, right=1400
            ),
            161,
        )

        self.tracker.ingest("/command_ingress/rc_axes", joy(0.0, 0.0, False), 170)
        self.ingest_status(status_payload("ARMED_NEUTRAL", armed=True), 171)

        self.tracker.ingest("/command_ingress/rc_axes", joy(-0.04, 0.09, True), 180)
        self.ingest_status(
            status_payload(
                "ACTIVE", armed=True, steering=-0.04, throttle=0.09,
                left=1400, right=1600
            ),
            181,
        )

        self.tracker.ingest("/planning/emergency_stop", {"data": True}, 190)
        self.ingest_status(status_payload("EMERGENCY_STOP", armed=True), 191)

        self.write_operator("disarm", 200)
        self.ingest_state(False, 210)
        self.ingest_override(211)
        self.ingest_override(212)
        self.ingest_override(213)

        MODULE.atomic_write_json(
            self.run_dir / "control" / "teardown_requested.json",
            {"schema": MODULE.SCHEMA, "requested_unix_ns": 220},
        )
        self.ingest_override(221)
        self.ingest_override(222)
        self.ingest_override(223)

        expected = set(MODULE.PHASE_FILES) - {"teardown.json"}
        present = {path.name for path in (self.run_dir / "evidence").iterdir()}
        self.assertTrue(expected.issubset(present))
        shutdown = MODULE.read_json(
            self.run_dir / "control" / "shutdown_frames.json"
        )
        self.assertEqual(len(shutdown["frames"]), 3)

        MODULE.atomic_write_json(
            self.run_dir / "control" / "teardown_runtime.json",
            {
                "schema": MODULE.SCHEMA,
                "cleanup_rc": 0,
                "children_stopped": True,
                "ports_free": True,
                "stop_order": [
                    "dashboard", "rosbridge", "bridge", "evidence",
                    "mavros", "mavproxy", "sitl",
                ],
            },
        )
        self.assertEqual(MODULE.finalize_run(self.run_dir, True, 0), 0)
        verdict = MODULE.read_json(self.run_dir / "evidence" / "verdict.json")
        self.assertEqual(verdict["verdict"], "PASS")
        self.assertEqual(verdict["missing"], [])

    def test_mapping_drift_and_duplicate_command_publishers_fail_closed(self):
        changed = status_payload("READY_DISARMED", armed=False)
        changed["resolved"]["left_servo"] = 2
        self.ingest_status(changed, 1)
        fault = MODULE.read_json(self.run_dir / "control" / "capture_fault.json")
        self.assertEqual(fault["reason"], "bridge_mapping_drift")

        other_run = self.run_dir / "other"
        for directory in ("control", "evidence", "manifest", "operator"):
            (other_run / directory).mkdir(parents=True, exist_ok=True)
        MODULE.atomic_write_json(other_run / "manifest" / "snapshot.json", snapshot())
        tracker = MODULE.EvidenceTracker(other_run, snapshot())
        tracker.set_command_publisher_count(2)
        fault = MODULE.read_json(other_run / "control" / "capture_fault.json")
        self.assertEqual(fault["reason"], "multiple_command_publishers")

    def test_state_evidence_requires_connected_manual_state(self):
        self.ingest_state(False, 10, connected=False)
        self.ingest_state(False, 11, mode="HOLD")
        self.assertIsNone(self.tracker._state_after(False, 10))
        self.ingest_state(False, 12)
        self.assertEqual(
            self.tracker._state_after(False, 10)["received_unix_ns"], 12
        )

    def test_incomplete_run_writes_a_failing_verdict(self):
        MODULE.atomic_write_json(
            self.run_dir / "control" / "teardown_runtime.json",
            {
                "children_stopped": True,
                "ports_free": True,
                "cleanup_rc": 0,
            },
        )
        MODULE.atomic_write_json(
            self.run_dir / "control" / "shutdown_frames.json", {"frames": [{}, {}, {}]}
        )
        self.assertEqual(MODULE.finalize_run(self.run_dir, False, 0), 1)
        verdict = MODULE.read_json(self.run_dir / "evidence" / "verdict.json")
        self.assertEqual(verdict["verdict"], "FAIL")
        self.assertIn("evidence/arm.json", verdict["missing"])

    def test_capture_fault_prevents_an_otherwise_complete_verdict(self):
        for name in set(MODULE.PHASE_FILES) - {"teardown.json"}:
            MODULE.atomic_write_json(
                self.run_dir / "evidence" / name,
                {"schema": MODULE.SCHEMA, "phase": name.removesuffix(".json")},
            )
        MODULE.atomic_write_json(
            self.run_dir / "control" / "capture_fault.json",
            {"schema": MODULE.SCHEMA, "reason": "bridge_mapping_drift"},
        )
        MODULE.atomic_write_json(
            self.run_dir / "control" / "shutdown_frames.json",
            {"frames": [{}, {}, {}]},
        )
        MODULE.atomic_write_json(
            self.run_dir / "control" / "teardown_runtime.json",
            {
                "cleanup_rc": 0,
                "children_stopped": True,
                "ports_free": True,
                "stop_order": [
                    "dashboard", "rosbridge", "bridge", "evidence",
                    "mavros", "mavproxy", "sitl",
                ],
            },
        )
        self.assertEqual(MODULE.finalize_run(self.run_dir, True, 0), 1)
        verdict = MODULE.read_json(self.run_dir / "evidence" / "verdict.json")
        self.assertEqual(verdict["verdict"], "FAIL")
        self.assertEqual(verdict["capture_fault"]["reason"], "bridge_mapping_drift")


class PureContractTest(unittest.TestCase):
    def test_snapshot_validation_pins_overlay_identity_and_live_mapping(self):
        values = valid_snapshot_values()
        guard = MODULE.validate_snapshot_values(
            values, MODULE.EXPECTED_PARAMETER_COUNT
        )
        self.assertEqual((guard.steering_channel, guard.throttle_channel), (1, 3))
        self.assertEqual((guard.left_servo, guard.right_servo), (1, 3))

        for name, value in (
            ("RC_OVERRIDE_TIME", 3.0),
            ("ARMING_RUDDER", 2),
            ("BRD_SAFETY_DEFLT", 0),
        ):
            with self.subTest(name=name):
                changed = dict(values)
                changed[name] = value
                with self.assertRaises(MODULE.EvidenceError):
                    MODULE.validate_snapshot_values(
                        changed, MODULE.EXPECTED_PARAMETER_COUNT
                    )
        with self.assertRaisesRegex(MODULE.EvidenceError, "parameter count"):
            MODULE.validate_snapshot_values(values, 0)

    def test_servo_decode_uses_each_live_rail_and_reversal(self):
        self.assertAlmostEqual(MODULE.normalized_servo_demand(1750, rail()), 0.5)
        reversed_rail = {**rail(), "reversed": 1}
        self.assertAlmostEqual(
            MODULE.normalized_servo_demand(1750, reversed_rail), -0.5
        )

    def test_ros_environment_is_exact_and_has_no_inherited_selectors(self):
        environment = {
            "ROS_DOMAIN_ID": "42",
            "ROS_AUTOMATIC_DISCOVERY_RANGE": "LOCALHOST",
            "ROS_LOCALHOST_ONLY": "1",
        }
        with mock_environment(environment):
            self.assertEqual(MODULE.validate_ros_environment(), environment)
        with mock_environment({**environment, "ROS_STATIC_PEERS": "192.0.2.1"}):
            with self.assertRaisesRegex(MODULE.EvidenceError, "ROS_STATIC_PEERS"):
                MODULE.validate_ros_environment()

    def test_capture_node_has_five_subscriptions_and_no_publisher(self):
        self.assertEqual(
            set(MODULE.TOPICS),
            {
                "/command_ingress/rc_axes",
                "/command_ingress/status",
                "/planning/emergency_stop",
                "/mavros/rc/override",
                "/mavros/state",
            },
        )
        source = inspect.getsource(MODULE.CaptureNode)
        self.assertNotIn("create_publisher", source)
        self.assertNotIn("create_client", source)
        self.assertNotIn("AsyncParameterClient", source)
        self.assertIn("create_subscription", source)


class mock_environment:
    def __init__(self, values):
        self.values = values
        self.previous = None

    def __enter__(self):
        self.previous = os.environ.copy()
        for name in list(os.environ):
            if name.startswith("ROS_") or name in (
                "RMW_IMPLEMENTATION",
                "FASTDDS_DEFAULT_PROFILES_FILE",
                "FASTRTPS_DEFAULT_PROFILES_FILE",
                "CYCLONEDDS_URI",
            ):
                os.environ.pop(name, None)
        os.environ.update(self.values)

    def __exit__(self, exc_type, exc, traceback):
        os.environ.clear()
        os.environ.update(self.previous)


if __name__ == "__main__":
    unittest.main()
