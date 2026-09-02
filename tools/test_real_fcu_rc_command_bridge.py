#!/usr/bin/env python3
"""Focused pure-function and ROS-node tests for real_fcu_rc_command_bridge.py."""

from __future__ import annotations

import ast
import importlib.util
import hashlib
import inspect
import json
import os
import pathlib
import struct
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

import rclpy
from mavros_msgs.msg import RCOut, State
from rcl_interfaces.msg import ParameterType, ParameterValue
from rclpy.signals import SignalHandlerOptions
from std_msgs.msg import Bool, String
from sensor_msgs.msg import Joy


MODULE_PATH = pathlib.Path(__file__).with_name("real_fcu_rc_command_bridge.py")
SPEC = importlib.util.spec_from_file_location("real_fcu_rc_command_bridge", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def valid_parameters():
    values = {
        "SYSID_THISMAV": 1,
        "SYSID_MYGCS": 255,
        "SYSID_ENFORCE": 0,
        "SERIAL1_PROTOCOL": 2,
        "BRD_SAFETY_DEFLT": 1,
        "BRD_SAFETY_MASK": 0,
        "BRD_SAFETYOPTION": 0,
        "ARMING_CHECK": 0,
        "ARMING_RUDDER": 2,
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
    }
    for channel in range(1, 17):
        values[f"RC{channel}_OPTION"] = 0
        values[f"SERVO{channel}_FUNCTION"] = 0
    values["SERVO3_FUNCTION"] = 73
    values["SERVO1_FUNCTION"] = 74
    for channel in (1, 3):
        values.update({
            f"RC{channel}_MIN": 1000,
            f"RC{channel}_TRIM": 1500,
            f"RC{channel}_MAX": 2000,
            f"RC{channel}_DZ": 30,
            f"RC{channel}_REVERSED": 0,
        })
        values.update({
            f"SERVO{channel}_MIN": 800,
            f"SERVO{channel}_TRIM": 800,
            f"SERVO{channel}_MAX": 2200,
            f"SERVO{channel}_REVERSED": 0,
        })
    return values


class BridgeFunctionsTest(unittest.TestCase):
    @staticmethod
    def endpoint(node_path):
        namespace, name = node_path.rsplit("/", 1)
        return SimpleNamespace(
            node_namespace=namespace or "/",
            node_name=name,
        )

    def test_input_publisher_binding_requires_one_resolved_expected_endpoint(self):
        expected = "/rosbridge_websocket"
        endpoint = self.endpoint(expected)
        self.assertEqual(
            MODULE.input_publisher_binding([endpoint], expected),
            (True, (expected,), 1),
        )
        self.assertEqual(
            MODULE.input_publisher_binding(
                [endpoint, self.endpoint(expected)], expected
            ),
            (False, (expected,), 2),
        )
        self.assertEqual(
            MODULE.input_publisher_binding(
                [self.endpoint("/wrong_publisher")], expected
            ),
            (False, ("/wrong_publisher",), 1),
        )
        unknown = SimpleNamespace(
            node_namespace="_NODE_NAMESPACE_UNKNOWN_",
            node_name="_NODE_NAME_UNKNOWN_",
        )
        self.assertEqual(
            MODULE.input_publisher_binding([unknown], expected),
            (False, (), 1),
        )

    def test_float32_bound_clamp_accepts_only_encoded_endpoint(self):
        def as_float32(value):
            return struct.unpack(">f", struct.pack(">f", value))[0]

        def next_float32(value):
            bits = struct.unpack(">I", struct.pack(">f", value))[0]
            return struct.unpack(">f", struct.pack(">I", bits + 1))[0]

        for upper in (0.05, 0.07, 0.09, 0.10, 0.12, 0.20):
            with self.subTest(upper=upper):
                encoded = as_float32(upper)
                self.assertEqual(
                    MODULE.clamp_float32_axis(encoded, 0.0, upper),
                    upper,
                )
                self.assertIsNone(
                    MODULE.clamp_float32_axis(
                        next_float32(encoded), 0.0, upper
                    )
                )
        encoded_lower = as_float32(-0.20)
        outside_lower = next_float32(encoded_lower)
        self.assertLess(outside_lower, -0.20)
        self.assertIsNone(
            MODULE.clamp_float32_axis(outside_lower, -0.20, 0.20)
        )
        self.assertIsNone(MODULE.clamp_float32_axis(-1e-9, 0.0, 0.12))

    def test_uses_installed_mavros_ros2_parameter_api(self):
        self.assertEqual(MODULE.PARAM_NODE, "/mavros/param")
        self.assertEqual(MODULE.PARAM_PULL_SERVICE, "/mavros/param/pull")

    def test_expected_domain_is_explicit_and_must_match(self):
        source = inspect.getsource(MODULE.RealFcuRcCommandBridge.__init__)
        self.assertIn('declare_parameter("expected_domain_id", "")', source)
        self.assertGreater(
            source.index("validate_ros_domain"),
            source.index("return"),
            "domain validation must remain inside the allow_real_fcu branch",
        )
        for domain_id in ("42", "43"):
            MODULE.validate_ros_domain(domain_id, domain_id)
        with self.assertRaisesRegex(MODULE.GuardError, "must be explicitly set"):
            MODULE.validate_ros_domain("", "42")
        with self.assertRaisesRegex(MODULE.GuardError, "ROS_DOMAIN_ID must be 43"):
            MODULE.validate_ros_domain("43", "42")

    def test_neutral_only_authority_is_explicit_and_omits_command_subscription(self):
        source = inspect.getsource(MODULE.RealFcuRcCommandBridge.__init__)
        self.assertIn('declare_parameter("neutral_only", False)', source)
        self.assertIn("if not self.neutral_only:", source)
        self.assertGreater(
            source.index("if not self.neutral_only:"),
            source.index("self.override_pub = self.create_publisher"),
        )
        self.assertGreater(
            source.index("self.create_subscription(Joy, COMMAND_TOPIC"),
            source.index("if not self.neutral_only:"),
        )
        self.assertIn("String, EMERGENCY_RESET_TOPIC", source)
        self.assertNotIn("Bool, EMERGENCY_RESET_TOPIC", source)

    def test_decodes_integer_double_and_missing_ros_parameters(self):
        integer = ParameterValue(
            type=ParameterType.PARAMETER_INTEGER,
            integer_value=0,
        )
        real = ParameterValue(
            type=ParameterType.PARAMETER_DOUBLE,
            double_value=0.5,
        )
        missing = ParameterValue(type=ParameterType.PARAMETER_NOT_SET)
        self.assertEqual(MODULE.decode_parameter_value("INTEGER", integer), 0.0)
        self.assertEqual(MODULE.decode_parameter_value("DOUBLE", real), 0.5)
        self.assertIsNone(
            MODULE.decode_parameter_value("OPTIONAL", missing, required=False)
        )
        with self.assertRaisesRegex(MODULE.GuardError, "no live MAVROS parameter"):
            MODULE.decode_parameter_value("REQUIRED", missing)

    def test_resolves_function_mapping_and_independent_rails(self):
        guard = MODULE.resolve_guard(valid_parameters())
        self.assertEqual((guard.left_servo, guard.right_servo), (3, 1))
        self.assertEqual((guard.steering_channel, guard.throttle_channel), (1, 3))
        self.assertEqual(guard.left_servo_rail.trim, 800)
        self.assertEqual(guard.throttle_rail.trim, 1500)

    def test_t0b_evidence_rejects_the_legacy_three_parameter_artifact(self):
        legacy_values = {
            "BRD_SAFETY_DEFLT": 1,
            "BRD_SAFETY_MASK": 0,
            "BRD_SAFETYOPTION": 0,
        }
        with self.assertRaisesRegex(MODULE.GuardError, "RCMAP_ROLL"):
            MODULE.t0b_evidence_payload(
                legacy_values, "/dev/ttyAMA0", 43, "t0b_parameters.txt"
            )

    def test_t0b_evidence_reuses_live_mapping_and_rail_resolution(self):
        source = valid_parameters()
        discovery_names = MODULE.t0b_discovery_parameter_names()
        discovery = {name: source[name] for name in discovery_names}
        self.assertEqual(MODULE.discover_channels(discovery), (1, 3, 3, 1))

        rail_names = MODULE.t0b_rail_parameter_names(discovery)
        values = {
            name: source[name]
            for name in (
                "BRD_SAFETY_DEFLT",
                "BRD_SAFETY_MASK",
                "BRD_SAFETYOPTION",
                *discovery_names,
                *rail_names,
            )
        }
        evidence = MODULE.t0b_evidence_payload(
            values, "/dev/ttyAMA0", 43, "t0b_parameters.txt"
        )
        self.assertEqual(evidence["schema"], "uvautoboat.real_fcu.t0b.v2")
        self.assertEqual(evidence["parameter_reads"], 41)
        self.assertEqual(len(evidence["recorded_parameters"]), 41)
        self.assertEqual(
            evidence["safety_parameters"],
            {
                "BRD_SAFETY_DEFLT": 1,
                "BRD_SAFETY_MASK": 0,
                "BRD_SAFETYOPTION": 0,
            },
        )
        self.assertEqual(
            evidence["rcmap"], {"RCMAP_ROLL": 1, "RCMAP_THROTTLE": 3}
        )
        self.assertEqual(len(evidence["servo_functions"]), 16)
        self.assertEqual(
            evidence["resolved"],
            {
                "steering_rc": 1,
                "throttle_rc": 3,
                "left_servo": 3,
                "right_servo": 1,
            },
        )
        self.assertEqual(evidence["rc_rails"]["steering"]["trim"], 1500)
        self.assertEqual(evidence["rc_rails"]["throttle"]["trim"], 1500)
        self.assertEqual(evidence["servo_rails"]["left"]["trim"], 800)
        self.assertEqual(evidence["servo_rails"]["right"]["trim"], 800)

        missing_rail = dict(values)
        del missing_rail["RC1_TRIM"]
        with self.assertRaisesRegex(MODULE.GuardError, "RC1_TRIM"):
            MODULE.t0b_evidence_payload(
                missing_rail, "/dev/ttyAMA0", 43, "t0b_parameters.txt"
            )

    def test_hash_pinned_mavproxy_snapshot_can_supply_t0b_evidence(self):
        values = valid_parameters()
        values["RC_OVERRIDE_TIME"] = 3.0
        values["UNRELATED_PARAMETER"] = 123
        path, digest = self.write_guard_snapshot(values)

        selected, evidence = MODULE.load_t0b_snapshot(
            path,
            digest,
            "/dev/ttyAMA0",
            43,
            "t0b_parameters.txt",
        )

        self.assertEqual(len(selected), 41)
        self.assertNotIn("RC_OVERRIDE_TIME", selected)
        self.assertNotIn("UNRELATED_PARAMETER", selected)
        self.assertEqual(evidence["schema"], "uvautoboat.real_fcu.t0b.v2")
        self.assertEqual(evidence["parameter_source"], "mavproxy-ftp-snapshot")
        self.assertEqual(evidence["snapshot_sha256"], digest)
        self.assertEqual(evidence["snapshot_parameter_count"], len(values))
        self.assertEqual(evidence["resolved"]["left_servo"], 3)
        self.assertEqual(evidence["servo_rails"]["right"]["trim"], 800)

    def test_t0b_snapshot_cli_writes_selected_parameters_and_provenance(self):
        values = valid_parameters()
        values["UNRELATED_PARAMETER"] = 123
        path, digest = self.write_guard_snapshot(values)
        with tempfile.TemporaryDirectory() as directory:
            parameters = pathlib.Path(directory, "t0b_parameters.txt")
            evidence_path = pathlib.Path(directory, "t0b.json")
            self.assertEqual(
                MODULE.cli(
                    [
                        "t0b-snapshot-write-evidence",
                        path,
                        digest,
                        str(parameters),
                        str(evidence_path),
                        "/dev/ttyAMA0",
                        "43",
                    ]
                ),
                0,
            )
            selected = MODULE.read_t0b_parameter_file(str(parameters))
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))

        self.assertEqual(len(selected), 41)
        self.assertNotIn("UNRELATED_PARAMETER", selected)
        self.assertEqual(evidence["snapshot_sha256"], digest)
        self.assertEqual(evidence["snapshot_parameter_count"], len(values))

        with tempfile.TemporaryDirectory() as directory:
            with mock.patch("sys.stderr"):
                self.assertEqual(
                    MODULE.cli(
                        [
                            "t0b-snapshot-write-evidence",
                            path,
                            "0" * 64,
                            str(pathlib.Path(directory, "parameters.txt")),
                            str(pathlib.Path(directory, "evidence.json")),
                            "/dev/ttyAMA0",
                            "43",
                        ]
                    ),
                    2,
                )

    def test_rejects_duplicate_throttle_function(self):
        values = valid_parameters()
        values["SERVO2_FUNCTION"] = 73
        with self.assertRaisesRegex(MODULE.GuardError, "exactly one"):
            MODULE.resolve_guard(values)

    def test_rejects_unbounded_override_timeout(self):
        values = valid_parameters()
        values["RC_OVERRIDE_TIME"] = 3.0
        with self.assertRaisesRegex(MODULE.GuardError, "RC_OVERRIDE_TIME"):
            MODULE.resolve_guard(values)

    def write_guard_snapshot(self, values):
        temporary = tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".parm", delete=False
        )
        self.addCleanup(pathlib.Path(temporary.name).unlink, missing_ok=True)
        with temporary:
            for name, value in sorted(values.items()):
                temporary.write(f"{name} {value}\n")
        payload = pathlib.Path(temporary.name).read_bytes()
        return temporary.name, hashlib.sha256(payload).hexdigest()

    def test_hash_pinned_mavproxy_snapshot_resolves_the_existing_guard(self):
        path, digest = self.write_guard_snapshot(valid_parameters())
        guard, evidence = MODULE.load_guard_snapshot(path, digest)
        self.assertEqual((guard.steering_channel, guard.throttle_channel), (1, 3))
        self.assertEqual((guard.left_servo, guard.right_servo), (3, 1))
        self.assertEqual(evidence["sha256"], digest)
        self.assertEqual(evidence["parameter_count"], len(valid_parameters()))
        self.assertEqual(evidence["critical"]["RC_OVERRIDE_TIME"], 0.5)
        self.assertEqual(evidence["source"], "mavproxy-parameter-snapshot")

    def test_snapshot_selector_is_default_off_and_precedes_override_publisher(self):
        source = inspect.getsource(MODULE.RealFcuRcCommandBridge.__init__)
        self.assertIn('declare_parameter("guard_snapshot_file", "")', source)
        self.assertIn('declare_parameter("guard_snapshot_sha256", "")', source)
        self.assertGreater(
            source.index("self.override_pub = self.create_publisher"),
            source.index("load_guard_snapshot"),
        )

    def test_snapshot_cli_writes_hash_pinned_evidence(self):
        path, digest = self.write_guard_snapshot(valid_parameters())
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory, "snapshot.json")
            self.assertEqual(
                MODULE.cli(
                    ["guard-snapshot-write-evidence", path, digest, str(output)]
                ),
                0,
            )
            evidence = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(evidence["sha256"], digest)
        self.assertEqual(evidence["critical"]["RC_OVERRIDE_TIME"], 0.5)

    def test_guard_snapshot_rejects_hash_drift_and_unbounded_timeout(self):
        path, digest = self.write_guard_snapshot(valid_parameters())
        with self.assertRaisesRegex(MODULE.GuardError, "SHA-256 mismatch"):
            MODULE.load_guard_snapshot(path, "0" * 64)

        values = valid_parameters()
        values["RC_OVERRIDE_TIME"] = 3.0
        unsafe_path, unsafe_digest = self.write_guard_snapshot(values)
        with self.assertRaisesRegex(MODULE.GuardError, "RC_OVERRIDE_TIME"):
            MODULE.load_guard_snapshot(unsafe_path, unsafe_digest)

    def test_guard_snapshot_parser_rejects_duplicate_and_malformed_lines(self):
        for content, expected in (
            ("RCMAP_ROLL 1\nRCMAP_ROLL 1\n", "duplicate snapshot parameter"),
            ("RCMAP_ROLL=1\n", "invalid snapshot line"),
            ("lowercase 1\n", "invalid snapshot parameter name"),
        ):
            temporary = tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", suffix=".parm", delete=False
            )
            self.addCleanup(pathlib.Path(temporary.name).unlink, missing_ok=True)
            with temporary:
                temporary.write(content)
            digest = hashlib.sha256(pathlib.Path(temporary.name).read_bytes()).hexdigest()
            with self.assertRaisesRegex(MODULE.GuardError, expected):
                MODULE.load_guard_snapshot(temporary.name, digest)

    def test_quantization_stays_toward_trim(self):
        rail = MODULE.RcRail(1000, 1500, 2000, 30, 0)
        self.assertEqual(MODULE.encode_axis(0.0, rail), 1500)
        self.assertEqual(MODULE.encode_axis(0.20, rail), 1624)
        self.assertEqual(MODULE.encode_axis(-0.20, rail), 1376)

    def test_reversal_and_channel_aware_release(self):
        rail = MODULE.RcRail(1000, 1500, 2000, 30, 1)
        self.assertLess(MODULE.encode_axis(0.2, rail), rail.trim)
        self.assertEqual(MODULE.release_value(8), 0)
        self.assertEqual(MODULE.release_value(9), 65534)

    def test_override_frame_changes_only_resolved_channels(self):
        channels = MODULE.override_channels(1, 1550, 3, 1600)
        self.assertEqual(len(channels), 18)
        self.assertEqual(channels[0], 1550)
        self.assertEqual(channels[2], 1600)
        self.assertTrue(all(value == 65535 for value in channels[3:]))

    def test_nonnegative_throttle_contract_uses_trim_for_failsafe_floor(self):
        values = valid_parameters()
        values["FS_THR_ENABLE"] = 1
        values["RC3_MIN"] = 900
        values["FS_THR_VALUE"] = 950
        guard = MODULE.resolve_guard(values)
        self.assertEqual(guard.throttle_rail.trim, 1500)

    def test_command_timestamp_is_nonzero_and_strictly_representable(self):
        self.assertEqual(MODULE.command_stamp_ns(1, 25), 1_000_000_025)
        with self.assertRaisesRegex(MODULE.GuardError, "non-zero"):
            MODULE.command_stamp_ns(0, 0)
        with self.assertRaisesRegex(MODULE.GuardError, "ROS time domain"):
            MODULE.command_stamp_ns(1, 1_000_000_000)

    def test_neutral_readiness_uses_live_resolved_rc_channels_and_trims(self):
        guard = MODULE.resolve_guard(valid_parameters())
        channels = [1500, 900, 1500]
        self.assertTrue(MODULE.rc_input_is_neutral(channels, guard))
        channels[guard.throttle_channel - 1] = 1510
        self.assertFalse(MODULE.rc_input_is_neutral(channels, guard))

        outputs = [800, 0, 800]
        self.assertTrue(MODULE.servo_output_is_neutral(outputs, guard))
        outputs[guard.left_servo - 1] = 801
        self.assertFalse(MODULE.servo_output_is_neutral(outputs, guard))

    def test_main_keeps_rclpy_from_taking_signal_ownership(self):
        source = inspect.getsource(MODULE.main)
        self.assertIn("signal_handler_options=SignalHandlerOptions.NO", source)


class RecordingPublisher:
    def __init__(self):
        self.messages = []

    def publish(self, message):
        self.messages.append(message)


class ImmediateFuture:
    def __init__(self, result):
        self._result = result

    def done(self):
        return True

    def result(self):
        return self._result


class RecordingParameterClient:
    def __init__(self, values):
        self.values = values
        self.requests = []

    def wait_for_services(self, timeout_sec):
        return True

    def get_parameters(self, names):
        self.requests.append(tuple(names))
        response = []
        for name in names:
            if name not in self.values:
                response.append(
                    ParameterValue(type=ParameterType.PARAMETER_NOT_SET)
                )
            elif isinstance(self.values[name], int):
                response.append(ParameterValue(
                    type=ParameterType.PARAMETER_INTEGER,
                    integer_value=self.values[name],
                ))
            else:
                response.append(ParameterValue(
                    type=ParameterType.PARAMETER_DOUBLE,
                    double_value=self.values[name],
                ))
        return ImmediateFuture(SimpleNamespace(values=response))


class RecordingPullClient:
    def __init__(self):
        self.requests = []

    def wait_for_service(self, timeout_sec):
        return True

    def call_async(self, request):
        self.requests.append(request)
        return ImmediateFuture(SimpleNamespace(success=True, param_received=1283))


class BridgeNodeStateMachineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["ROS_DOMAIN_ID"] = "42"
        os.environ["ROS_LOG_DIR"] = "/tmp"
        if not rclpy.ok():
            rclpy.init(args=[], signal_handler_options=SignalHandlerOptions.NO)

    @classmethod
    def tearDownClass(cls):
        if rclpy.ok():
            rclpy.shutdown()

    def setUp(self):
        self.node = MODULE.RealFcuRcCommandBridge()
        self.node.timer.cancel()
        self.node.allow_real_fcu = True
        self.node.guard = MODULE.resolve_guard(valid_parameters())
        self.node.override_pub = RecordingPublisher()
        self.node.status_pub = RecordingPublisher()
        self.publisher_info_patch = mock.patch.object(
            self.node,
            "get_publishers_info_by_topic",
            side_effect=self.publishers_for_topic,
        )
        self.publisher_info_patch.start()

    def tearDown(self):
        self.publisher_info_patch.stop()
        self.node.destroy_node()

    def publishers_for_topic(self, topic):
        if topic == MODULE.PERSON_ALERT_TOPIC:
            return [self.endpoint(MODULE.PERSON_ALERT_PUBLISHER)]
        if topic in (
            MODULE.COMMAND_TOPIC,
            MODULE.EMERGENCY_RESET_TOPIC,
            MODULE.CONTROL_OWNER_TOPIC,
        ):
            return [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]
        return []

    @staticmethod
    def vehicle(armed, mode="MANUAL"):
        message = State()
        message.connected = True
        message.armed = armed
        message.mode = mode
        return message

    @staticmethod
    def command(stamp, steering=0.0, throttle=0.0, enable=0):
        message = Joy()
        message.header.frame_id = MODULE.FRAME_ID
        message.header.stamp.sec = stamp
        message.axes = [steering, throttle]
        message.buttons = [enable]
        return message

    @staticmethod
    def person_alert(person_detected=False, feed_fresh=True, reason=""):
        return String(data=json.dumps({
            "person_detected": person_detected,
            "feed_fresh": feed_fresh,
            "reason": reason,
        }))

    @staticmethod
    def dashboard_reset_confirmation():
        return String(data=MODULE.DASHBOARD_NEUTRAL_RESET_CONFIRMATION)

    @staticmethod
    def herelink_reset_confirmation():
        return String(data=MODULE.HERELINK_STICKS_NEUTRAL_CONFIRMATION)

    @staticmethod
    def herelink_owner_confirmation():
        return String(data=MODULE.HERELINK_STICKS_NEUTRAL_CONFIRMATION)

    @staticmethod
    def endpoint(node_path):
        namespace, name = node_path.rsplit("/", 1)
        return SimpleNamespace(
            node_namespace=namespace or "/",
            node_name=name,
        )

    def set_valid_feedback(self, now):
        self.node.latest_rc_in = (1500, 1500, 1500)
        self.node.latest_rc_out = (800, 800, 800)
        self.node.latest_rc_in_at = now - 0.1
        self.node.latest_rc_out_at = now - 0.1

    def publish_rc_out(self, now, channels=(800, 800, 800)):
        message = RCOut()
        message.channels = list(channels)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._rc_out_cb(message)

    def complete_herelink_handover(self, now):
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            for _ in range(3):
                self.node._tick()
        for _ in range(3):
            self.publish_rc_out(now)
            with mock.patch.object(MODULE.time, "monotonic", return_value=now):
                self.node._tick()
        self.publish_rc_out(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()

    def test_live_guard_refreshes_then_reads_ros_parameters_twice(self):
        parameter_client = RecordingParameterClient(valid_parameters())
        pull_client = RecordingPullClient()
        with mock.patch.object(
            MODULE, "AsyncParameterClient", return_value=parameter_client
        ), mock.patch.object(
            self.node, "create_client", return_value=pull_client
        ), mock.patch.object(MODULE.rclpy, "spin_until_future_complete"):
            guard = self.node._resolve_live_guard()
        self.assertEqual((guard.left_servo, guard.right_servo), (3, 1))
        self.assertEqual(len(pull_client.requests), 3)
        self.assertTrue(all(request.force_pull for request in pull_client.requests))
        self.assertEqual(len(parameter_client.requests), 3)
        self.assertNotIn("DDS_ENABLE", parameter_client.requests[0])
        self.assertIn("DDS_ENABLE", parameter_client.requests[1])
        self.assertEqual(
            parameter_client.requests[1], parameter_client.requests[2]
        )
        source = inspect.getsource(self.node._resolve_live_guard)
        self.assertIn("t0b_discovery_parameter_names()", source)
        self.assertIn("t0b_rail_parameter_names(discovery)", source)

    def test_startup_armed_abort_emits_no_override(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.startup_armed = True
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.override_pub.messages, [])

    def test_empty_feedback_cannot_enable_non_neutral_output(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.armed_enable_primed = True
        self.node.last_command = (0.1, 0.1, True)
        self.node.last_command_at = now
        self.node.latest_rc_in_at = now
        self.node.latest_rc_out_at = now
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(self.node, "count_publishers", return_value=1):
            self.node._tick()
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(channels[guard.steering_channel - 1], guard.steering_rail.trim)
        self.assertEqual(channels[guard.throttle_channel - 1], guard.throttle_rail.trim)
        self.assertEqual(self.node.fault, "FEEDBACK_INVALID")

    def test_neutral_only_authority_rejects_commands_and_publishes_trims(self):
        now = 100.0
        self.node.neutral_only = True
        self.node._command_cb(Joy())
        self.assertEqual(self.node.fault, "NEUTRAL_ONLY")
        self.assertEqual(self.node.last_command, (0.0, 0.0, False))

        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.armed_enable_primed = True
        self.node.last_command = (0.1, 0.1, True)
        self.node.last_command_at = now
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(self.node, "count_publishers", return_value=1):
            self.node._tick()
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(channels[guard.steering_channel - 1], guard.steering_rail.trim)
        self.assertEqual(channels[guard.throttle_channel - 1], guard.throttle_rail.trim)
        self.assertEqual(self.node.fault, "ARMED_NEUTRAL")
        status = json.loads(self.node.status_pub.messages[-1].data)
        self.assertIs(status["neutral_only"], True)
        self.assertEqual(status["command"], {"steering": 0.0, "throttle": 0.0})

    def test_float32_command_endpoints_clamp_without_expanding_authority(self):
        def as_float32(value):
            return struct.unpack("f", struct.pack("f", value))[0]

        def next_float32(value):
            bits = struct.unpack(">I", struct.pack(">f", value))[0]
            return struct.unpack(">f", struct.pack(">I", bits + 1))[0]

        def command(stamp, steering, throttle=0.20, enable=0):
            message = Joy()
            message.header.frame_id = MODULE.FRAME_ID
            message.header.stamp.sec = stamp
            message.axes = [as_float32(steering), as_float32(throttle)]
            message.buttons = [enable]
            return message

        positive = as_float32(0.20)
        negative = as_float32(-0.20)
        self.assertGreater(positive, 0.20)
        self.assertLess(negative, -0.20)

        self.node._command_cb(command(1, 0.20))
        self.assertEqual(self.node.last_command, (0.20, 0.20, False))

        self.node._command_cb(command(2, -0.20))
        self.assertEqual(self.node.last_command, (-0.20, 0.20, False))

        accepted = self.node.last_command
        accepted_stamp = self.node.last_command_stamp_ns
        next_outside = next_float32(positive)
        self.node._command_cb(command(3, next_outside))
        self.assertEqual(self.node.fault, "COMMAND_OUT_OF_BOUNDS")
        self.assertEqual(self.node.last_command, accepted)
        self.assertEqual(self.node.last_command_stamp_ns, accepted_stamp)

        self.node._command_cb(command(4, 0.20001))
        self.assertEqual(self.node.fault, "COMMAND_OUT_OF_BOUNDS")
        self.assertEqual(self.node.last_command, accepted)
        self.assertEqual(self.node.last_command_stamp_ns, accepted_stamp)

        self.node.max_throttle = 0.10
        throttle_endpoint = as_float32(self.node.max_throttle)
        self.assertGreater(throttle_endpoint, self.node.max_throttle)
        self.node._command_cb(command(5, 0.0, self.node.max_throttle))
        self.assertEqual(self.node.last_command, (0.0, 0.10, False))

        accepted = self.node.last_command
        accepted_stamp = self.node.last_command_stamp_ns
        self.node._command_cb(command(6, 0.0, next_float32(throttle_endpoint)))
        self.assertEqual(self.node.fault, "COMMAND_OUT_OF_BOUNDS")
        self.assertEqual(self.node.last_command, accepted)
        self.assertEqual(self.node.last_command_stamp_ns, accepted_stamp)

        self.node._command_cb(command(7, 0.0, 0.10001))
        self.assertEqual(self.node.fault, "COMMAND_OUT_OF_BOUNDS")
        self.assertEqual(self.node.last_command, accepted)
        self.assertEqual(self.node.last_command_stamp_ns, accepted_stamp)

        self.node._command_cb(command(8, 0.0, -1e-9))
        self.assertEqual(self.node.fault, "COMMAND_OUT_OF_BOUNDS")
        self.assertEqual(self.node.last_command, accepted)
        self.assertEqual(self.node.last_command_stamp_ns, accepted_stamp)

        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.armed_enable_primed = True
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(self.node, "count_publishers", return_value=1):
            self.node._command_cb(command(9, 0.20, 0.10, enable=1))
            self.node._tick()
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(
            channels[guard.steering_channel - 1],
            MODULE.encode_axis(0.20, guard.steering_rail),
        )
        self.assertEqual(
            channels[guard.throttle_channel - 1],
            MODULE.encode_axis(0.10, guard.throttle_rail),
        )
        self.assertEqual(self.node.fault, "ACTIVE")

    def test_status_payload_includes_live_rc_and_servo_rails(self):
        now = 100.0
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._publish_status("READY_DISARMED", 0.0, 0.0)
        status = json.loads(self.node.status_pub.messages[-1].data)
        self.assertEqual(
            status["rc_rails"]["steering"],
            {
                "channel": 1,
                "minimum": 1000,
                "trim": 1500,
                "maximum": 2000,
                "dead_zone": 30,
                "reversed": 0,
                "option": 0,
            },
        )
        self.assertEqual(
            status["servo_rails"]["left"],
            {
                "channel": 3,
                "function": 73,
                "minimum": 800,
                "trim": 800,
                "maximum": 2200,
                "reversed": 0,
            },
        )
        self.assertEqual(status["servo_rails"]["right"]["channel"], 1)
        self.assertEqual(status["servo_rails"]["right"]["function"], 74)

    def test_one_hertz_state_stream_does_not_false_trip(self):
        now = 100.0
        self.node.latest_state = self.vehicle(False)
        self.node.latest_state_at = now - 1.1
        self.node.latest_rc_in = (1500, 1500, 1500)
        self.node.latest_rc_in_at = now - 0.1
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.fault, "READY_DISARMED")

    def test_stale_armed_state_sends_live_trims_instead_of_silence(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now - 3.0
        self.node.arm_epoch_authorized = True
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(channels[guard.steering_channel - 1], guard.steering_rail.trim)
        self.assertEqual(channels[guard.throttle_channel - 1], guard.throttle_rail.trim)
        self.assertEqual(self.node.fault, "STATE_STALE")

    def test_disarmed_readiness_is_recomputed_after_each_epoch(self):
        now = 100.0
        self.node.disarmed_ready = True
        self.node.latest_state = self.vehicle(False)
        self.node.latest_state_at = now
        self.node.latest_rc_in = (1600, 1500, 1500)
        self.node.latest_rc_in_at = now
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertFalse(self.node.disarmed_ready)
        self.assertEqual(self.node.fault, "WAITING_DISARMED_NEUTRAL_RC")

    def test_arm_transition_rechecks_latest_rc_input(self):
        now = 100.0
        self.node.latest_state = self.vehicle(False)
        self.node.disarmed_ready = True
        self.node.latest_rc_in = (1600, 1500, 1500)
        self.node.latest_rc_in_at = now
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._state_cb(self.vehicle(True))
        self.assertFalse(self.node.arm_epoch_authorized)

    def test_emergency_stop_immediately_overrides_demand_with_live_trims(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        self.node._emergency_cb(Bool(data=True))
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(channels[guard.steering_channel - 1], guard.steering_rail.trim)
        self.assertEqual(channels[guard.throttle_channel - 1], guard.throttle_rail.trim)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")

    def test_person_alert_latches_stop_and_clear_does_not_auto_resume(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert(
                person_detected=True,
                feed_fresh=True,
                reason="person_detected",
            ))
        self.assertTrue(self.node.emergency_stop_latched)
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(
            channels[guard.steering_channel - 1], guard.steering_rail.trim
        )
        self.assertEqual(
            channels[guard.throttle_channel - 1], guard.throttle_rail.trim
        )
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())
        self.assertTrue(self.node.emergency_stop_latched)
        self.assertTrue(self.node.person_hold_clear)

    def test_required_person_alert_rejects_wrong_or_duplicate_publishers(self):
        self.node.require_person_alert = True
        clear = self.person_alert()

        with mock.patch.object(
            self.node,
            "get_publishers_info_by_topic",
            return_value=[self.endpoint(MODULE.PERSON_ALERT_PUBLISHER)],
        ):
            self.node._person_alert_cb(clear)
        self.assertTrue(self.node.person_alert_valid)
        self.assertTrue(self.node.person_hold_clear)
        self.assertFalse(self.node.emergency_stop_latched)

        for publishers in (
            [self.endpoint("/wrong_person_monitor")],
            [
                self.endpoint(MODULE.PERSON_ALERT_PUBLISHER),
                self.endpoint(MODULE.PERSON_ALERT_PUBLISHER),
            ],
        ):
            with self.subTest(publishers=len(publishers)), mock.patch.object(
                self.node,
                "get_publishers_info_by_topic",
                return_value=publishers,
            ):
                self.node.emergency_stop_latched = False
                self.node._person_alert_cb(clear)
                self.assertFalse(self.node.person_alert_valid)
                self.assertFalse(self.node.person_hold_clear)
                self.assertTrue(self.node.emergency_stop_latched)

    def test_reset_and_owner_inputs_require_the_rosbridge_publisher(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.emergency_stop_latched = True
        self.node.emergency_neutral_command_seen = True
        self.set_valid_feedback(now)

        wrong = [self.endpoint("/wrong_browser_gateway")]
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=wrong,
                ):
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
        self.assertTrue(self.node.emergency_stop_latched)

        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]
        # The rejected reset re-latches E-stop and deliberately invalidates the
        # prior neutral command.  Re-establish that independent reset precondition
        # before proving the expected publisher is accepted.
        self.node.emergency_neutral_command_seen = True
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
        self.assertFalse(self.node.emergency_stop_latched)

        duplicate = [
            self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER),
            self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER),
        ]
        with mock.patch.object(
            self.node,
            "get_publishers_info_by_topic",
            return_value=duplicate,
        ):
            self.node._control_owner_cb(self.herelink_owner_confirmation())
            self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertTrue(self.node.emergency_stop_latched)

        self.node.emergency_stop_latched = False
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._control_owner_cb(self.herelink_owner_confirmation())
        self.assertEqual(
            self.node.control_owner,
            MODULE.CONTROL_OWNER_HERELINK,
            self.node.fault,
        )
        self.assertFalse(self.node.emergency_stop_latched)

    def test_active_command_requires_the_single_rosbridge_publisher(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.armed_enable_primed = True
        self.node.last_command = (0.05, 0.04, True)
        self.node.last_command_at = now
        self.set_valid_feedback(now)

        for publishers in (
            [self.endpoint("/wrong_publisher")],
            [
                self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER),
                self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER),
            ],
        ):
            with self.subTest(publishers=len(publishers)), mock.patch.object(
                self.node,
                "get_publishers_info_by_topic",
                return_value=publishers,
            ), mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                    mock.patch.object(self.node, "count_publishers", return_value=1):
                self.node.emergency_stop_latched = False
                self.node.emergency_neutral_command_seen = False
                self.node.armed_enable_primed = True
                self.node.last_command = (0.05, 0.04, True)
                self.node.last_command_at = now
                self.node._tick()
            self.assertTrue(self.node.emergency_stop_latched)
            self.assertEqual(self.node.fault, "EMERGENCY_STOP")

    def test_required_person_alert_staleness_latches_stop(self):
        now = 100.0
        self.node.require_person_alert = True
        self.node.person_alert_required_since = now - 10.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        self.node.person_alert_valid = True
        self.node.person_alert_at = now - MODULE.PERSON_ALERT_TIMEOUT_SECONDS
        self.node.person_hold_clear = True

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()

        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")

    def test_manual_estop_reset_does_not_require_unused_person_feed(self):
        now = 100.0
        self.node.require_person_alert = False
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._emergency_cb(Bool(data=True))
            self.node._command_cb(self.command(1))
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())

        self.assertFalse(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "DASHBOARD_PRIME_REQUIRED")

    def test_person_stop_clear_reset_cycle_is_repeatable(self):
        now = 100.0
        self.node.require_person_alert = True
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)

        stamp = 1
        for _ in range(2):
            with mock.patch.object(MODULE.time, "monotonic", return_value=now):
                self.node._person_alert_cb(self.person_alert(
                    person_detected=True,
                    feed_fresh=True,
                    reason="person_detected",
                ))
                self.node._command_cb(self.command(stamp))
                stamp += 1
                self.node._person_alert_cb(self.person_alert())
                self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
            self.assertFalse(self.node.emergency_stop_latched)
            self.assertEqual(self.node.fault, "DASHBOARD_PRIME_REQUIRED")

    def test_emergency_stop_reset_is_fail_closed_repeatable_and_reprimed(self):
        now = 100.0
        self.node.require_person_alert = True
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())
            self.node._emergency_cb(Bool(data=True))
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(
            self.node._emergency_reset_eligibility(now),
            (False, "COMMAND_NEUTRAL_DISABLED_REQUIRED"),
        )

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._command_cb(self.command(1))
        self.assertTrue(self.node.emergency_neutral_command_seen)
        self.assertEqual(
            self.node._emergency_reset_eligibility(now + 1.0),
            (False, "PERSON_ALERT_STALE"),
        )

        self.node.latest_rc_in = (1510, 1500, 1500)
        self.assertEqual(
            self.node._emergency_reset_eligibility(now),
            (True, ""),
        )
        self.node.latest_rc_in = (1500, 1500, 1500)

        self.node.latest_rc_out = (801, 800, 800)
        self.assertEqual(
            self.node._emergency_reset_eligibility(now),
            (False, "SERVO_OUTPUT_NOT_NEUTRAL"),
        )
        self.node.latest_rc_out = (800, 800, 800)

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert(
                person_detected=True,
                feed_fresh=False,
                reason="detector_feed_lost",
            ))
        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(
            self.node._emergency_reset_eligibility(now),
            (False, "COMMAND_NEUTRAL_DISABLED_REQUIRED"),
        )

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._command_cb(self.command(2))
        self.assertEqual(
            self.node._emergency_reset_eligibility(now),
            (False, "PERSON_HOLD_ACTIVE"),
        )

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
        self.assertFalse(self.node.emergency_stop_latched)
        self.assertFalse(self.node.armed_enable_primed)
        self.assertEqual(self.node.fault, "DASHBOARD_PRIME_REQUIRED")

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._command_cb(self.command(3, 0.05, 0.04, 1))
        self.assertEqual(self.node.fault, "ENABLE_RESET_REQUIRED")
        self.assertEqual(self.node.last_command, (0.0, 0.0, False))

        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(self.node, "count_publishers", return_value=1):
            self.node._command_cb(self.command(4))
            self.node._command_cb(self.command(5, 0.05, 0.04, 1))
            self.node._tick()
        self.assertEqual(self.node.fault, "ACTIVE")

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._emergency_cb(Bool(data=True))
            self.node._command_cb(self.command(6))
            self.node._emergency_reset_cb(self.dashboard_reset_confirmation())
            self.node._command_cb(self.command(7))
        self.assertFalse(self.node.emergency_stop_latched)
        self.assertTrue(self.node.armed_enable_primed)

    def test_herelink_handover_releases_override_and_estop_takes_priority(self):
        now = 100.0
        self.node.require_person_alert = True
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._control_owner_cb(self.herelink_owner_confirmation())
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_HERELINK)
        guard = self.node.guard
        handover_start = len(self.node.override_pub.messages)
        initial = self.node.override_pub.messages[-1].channels
        self.assertEqual(
            initial[guard.steering_channel - 1], guard.steering_rail.trim
        )
        self.assertEqual(
            initial[guard.throttle_channel - 1], guard.throttle_rail.trim
        )

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._command_cb(self.command(1, 0.05, 0.04, 1))
        self.assertEqual(self.node.fault, "HERELINK_CONTROL")

        self.assertEqual(self.node.last_command, (0.0, 0.0, False))

        # RC input is override readback here, not physical-stick evidence.
        self.node.latest_rc_in = (1510, 1500, 1500)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            for _ in range(3):
                self.node._tick()
            self.node._tick()
        self.assertEqual(self.node.handover_release_frames_remaining, 3)
        self.assertEqual(self.node.fault, "HERELINK_HANDOVER")

        for remaining in (2, 1, 0):
            self.publish_rc_out(now)
            with mock.patch.object(MODULE.time, "monotonic", return_value=now):
                self.node._tick()
            self.assertEqual(
                self.node.handover_release_frames_remaining, remaining
            )
            self.assertEqual(self.node.fault, "HERELINK_HANDOVER")

        published_after_release = len(self.node.override_pub.messages)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(
            len(self.node.override_pub.messages), published_after_release
        )
        self.assertEqual(self.node.fault, "HERELINK_HANDOVER")

        self.publish_rc_out(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        published_after_handover = len(self.node.override_pub.messages)
        self.assertEqual(self.node.fault, "HERELINK_CONTROL")
        for message in self.node.override_pub.messages[-3:]:
            self.assertEqual(
                message.channels[guard.steering_channel - 1],
                MODULE.release_value(guard.steering_channel),
            )
            self.assertEqual(
                message.channels[guard.throttle_channel - 1],
                MODULE.release_value(guard.throttle_channel),
            )

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._emergency_cb(Bool(data=True))
        stopped = self.node.override_pub.messages[-1].channels
        self.assertEqual(stopped[guard.steering_channel - 1], guard.steering_rail.trim)
        self.assertEqual(stopped[guard.throttle_channel - 1], guard.throttle_rail.trim)
        self.assertTrue(self.node.emergency_stop_latched)
        self.node._control_owner_cb(String(data=MODULE.CONTROL_OWNER_DASHBOARD))
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_HERELINK)
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())
            self.node._emergency_reset_cb(self.herelink_reset_confirmation())
        self.complete_herelink_handover(now)
        self.assertFalse(self.node.emergency_stop_latched)
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_HERELINK)
        released = self.node.override_pub.messages[-1].channels
        self.assertEqual(
            released[guard.steering_channel - 1],
            MODULE.release_value(guard.steering_channel),
        )
        self.assertEqual(
            released[guard.throttle_channel - 1],
            MODULE.release_value(guard.throttle_channel),
        )

        self.node._control_owner_cb(String(data=MODULE.CONTROL_OWNER_DASHBOARD))
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertFalse(self.node.armed_enable_primed)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._command_cb(self.command(3, 0.05, 0.04, 1))
            self.assertEqual(self.node.fault, "ENABLE_RESET_REQUIRED")
            self.node._command_cb(self.command(4))
            self.node._command_cb(self.command(5, 0.05, 0.04, 1))
        self.assertTrue(self.node.armed_enable_primed)
        self.assertAlmostEqual(self.node.last_command[0], 0.05)
        self.assertAlmostEqual(self.node.last_command[1], 0.04)
        self.assertIs(self.node.last_command[2], True)

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._control_owner_cb(self.herelink_owner_confirmation())
        self.complete_herelink_handover(now)
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_HERELINK)
        self.assertEqual(self.node.fault, "HERELINK_CONTROL")

    def test_herelink_handover_requires_explicit_physical_stick_attestation(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]

        with mock.patch.object(
            self.node,
            "get_publishers_info_by_topic",
            return_value=rosbridge,
        ):
            self.node._control_owner_cb(
                String(data=MODULE.CONTROL_OWNER_HERELINK)
            )
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertEqual(self.node.fault, "HERELINK_NEUTRAL_CONFIRMATION_REQUIRED")

        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._control_owner_cb(
                String(data=MODULE.HERELINK_STICKS_NEUTRAL_CONFIRMATION)
            )
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_HERELINK)

        # RC_CHANNELS reports override_value while override is active, so this
        # value cannot establish the physical Herelink stick position.  The
        # explicit confirmation is the authority for the bounded release.
        self.node.latest_rc_in = (1510, 1500, 1500)
        self.complete_herelink_handover(now)
        self.assertEqual(self.node.fault, "HERELINK_CONTROL")

    def test_invalid_owner_message_still_requires_the_bound_rosbridge_source(self):
        self.node.emergency_stop_latched = False
        wrong = [self.endpoint("/wrong_browser_gateway")]
        with mock.patch.object(
            self.node,
            "get_publishers_info_by_topic",
            return_value=wrong,
        ):
            self.node._control_owner_cb(
                String(data=MODULE.CONTROL_OWNER_HERELINK)
            )
        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")

    def test_herelink_attestation_cannot_be_reused_from_before_the_armed_epoch(self):
        now = 100.0
        self.node.latest_state = self.vehicle(False)
        self.node.latest_state_at = now
        self.set_valid_feedback(now)
        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._control_owner_cb(self.herelink_owner_confirmation())

        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertEqual(self.node.fault, "HERELINK_HANDOVER_NOT_READY")

        self.node.latest_state = self.vehicle(True)
        self.node.arm_epoch_authorized = True
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)

    def test_disarm_revokes_herelink_owner_and_pending_handover(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.control_owner = MODULE.CONTROL_OWNER_HERELINK
        self.node.handover_neutral_frames_remaining = 2
        self.node.handover_release_frames_remaining = 3
        self.node.handover_rc_out_generation = 7

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._state_cb(self.vehicle(False))

        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertEqual(self.node.handover_neutral_frames_remaining, 0)
        self.assertEqual(self.node.handover_release_frames_remaining, 0)
        self.assertIsNone(self.node.handover_rc_out_generation)

        self.node.latest_state = self.vehicle(True)
        self.node.arm_epoch_authorized = True
        self.node.control_owner = MODULE.CONTROL_OWNER_HERELINK
        self.node.handover_release_frames_remaining = 3
        self.node.handover_rc_out_generation = 8
        disconnected = self.vehicle(True)
        disconnected.connected = False
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._state_cb(disconnected)
        self.assertEqual(self.node.control_owner, MODULE.CONTROL_OWNER_DASHBOARD)
        self.assertFalse(self.node.arm_epoch_authorized)
        self.assertEqual(self.node.handover_release_frames_remaining, 0)
        self.assertIsNone(self.node.handover_rc_out_generation)

    def test_herelink_release_requires_measured_neutral_servo_output(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._control_owner_cb(self.herelink_owner_confirmation())

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            for _ in range(3):
                self.node._tick()
        before_release = len(self.node.override_pub.messages)
        self.publish_rc_out(now, (900, 800, 800))
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()

        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")
        self.assertEqual(len(self.node.override_pub.messages), before_release + 1)
        channels = self.node.override_pub.messages[-1].channels
        guard = self.node.guard
        self.assertEqual(
            channels[guard.steering_channel - 1], guard.steering_rail.trim
        )
        self.assertEqual(
            channels[guard.throttle_channel - 1], guard.throttle_rail.trim
        )

    def test_herelink_release_rechecks_servo_output_between_release_frames(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]
        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._control_owner_cb(self.herelink_owner_confirmation())

        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            for _ in range(3):
                self.node._tick()
        self.publish_rc_out(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.handover_release_frames_remaining, 2)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()
        self.assertEqual(self.node.handover_release_frames_remaining, 2)

        self.publish_rc_out(now, (800, 800, 900))
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._tick()

        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "EMERGENCY_STOP")
        self.assertEqual(self.node.handover_release_frames_remaining, 0)

    def test_herelink_estop_reset_requires_matching_stick_confirmation(self):
        now = 100.0
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.node.control_owner = MODULE.CONTROL_OWNER_HERELINK
        self.node.emergency_stop_latched = True
        self.set_valid_feedback(now)
        # Non-neutral RC input is not used as physical-stick evidence while
        # the bridge's neutral override is active.
        self.node.latest_rc_in = (1510, 1500, 1500)
        rosbridge = [self.endpoint(MODULE.ROSBRIDGE_INPUT_PUBLISHER)]

        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._emergency_reset_cb(
                String(data=MODULE.DASHBOARD_NEUTRAL_RESET_CONFIRMATION)
            )
        self.assertTrue(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "HERELINK_NEUTRAL_CONFIRMATION_REQUIRED")

        with mock.patch.object(MODULE.time, "monotonic", return_value=now), \
                mock.patch.object(
                    self.node,
                    "get_publishers_info_by_topic",
                    return_value=rosbridge,
                ):
            self.node._emergency_reset_cb(
                String(data=MODULE.HERELINK_STICKS_NEUTRAL_CONFIRMATION)
            )
        self.assertFalse(self.node.emergency_stop_latched)
        self.assertEqual(self.node.fault, "HERELINK_HANDOVER")

    def test_status_exposes_control_owner_and_reset_eligibility(self):
        now = 100.0
        self.node.require_person_alert = True
        self.node.latest_state = self.vehicle(True)
        self.node.latest_state_at = now
        self.node.arm_epoch_authorized = True
        self.set_valid_feedback(now)
        with mock.patch.object(MODULE.time, "monotonic", return_value=now):
            self.node._person_alert_cb(self.person_alert())
            self.node._emergency_cb(Bool(data=True))
            self.node._command_cb(self.command(1))
            self.node._publish_status("EMERGENCY_STOP", 0.0, 0.0)
        status = json.loads(self.node.status_pub.messages[-1].data)
        self.assertEqual(status["control_owner"], "DASHBOARD")
        self.assertIs(status["emergency_stop_latched"], True)
        self.assertIs(status["emergency_reset_allowed"], True)
        self.assertEqual(status["emergency_reset_block_reason"], "")
        self.assertIs(status["person_alert_fresh"], True)
        self.assertIs(status["person_hold_clear"], True)

    def test_shutdown_neutralizes_before_context_close(self):
        self.node.latest_state = self.vehicle(True)
        with mock.patch.object(MODULE.time, "sleep"):
            self.node.neutralize_for_shutdown()
        self.assertEqual(len(self.node.override_pub.messages), 3)
        guard = self.node.guard
        for message in self.node.override_pub.messages:
            self.assertEqual(
                message.channels[guard.steering_channel - 1],
                guard.steering_rail.trim,
            )
            self.assertEqual(
                message.channels[guard.throttle_channel - 1],
                guard.throttle_rail.trim,
            )


class HardwareSafetyBadgeTests(unittest.TestCase):
    """The badge is display evidence: it must never invent a safety claim."""

    def state(self, sensors_enabled, age):
        return MODULE.hardware_safety_state(
            sensors_enabled, age, MODULE.SYS_STATUS_TIMEOUT_SECONDS
        )

    def test_clear_motor_outputs_bit_reads_engaged(self):
        # ArduPilot sets the bit only when safety_switch_state() != SAFETY_DISARMED,
        # so a clear bit means the switch is engaged and outputs are suppressed.
        self.assertEqual(self.state(0, 0.1), MODULE.HARDWARE_SAFETY_ENGAGED)

    def test_set_motor_outputs_bit_reads_released(self):
        self.assertEqual(
            self.state(MODULE.MOTOR_OUTPUTS_BIT, 0.1),
            MODULE.HARDWARE_SAFETY_RELEASED,
        )

    def test_other_sensor_bits_do_not_imply_released(self):
        self.assertEqual(self.state(0b1111, 0.1), MODULE.HARDWARE_SAFETY_ENGAGED)

    def test_a_stale_sample_is_unknown_not_reassuring(self):
        stale = MODULE.SYS_STATUS_TIMEOUT_SECONDS + 0.001
        self.assertEqual(
            self.state(MODULE.MOTOR_OUTPUTS_BIT, stale),
            MODULE.HARDWARE_SAFETY_UNKNOWN,
        )
        self.assertEqual(self.state(0, stale), MODULE.HARDWARE_SAFETY_UNKNOWN)

    def test_no_sample_yet_is_unknown(self):
        self.assertEqual(
            self.state(MODULE.MOTOR_OUTPUTS_BIT, None),
            MODULE.HARDWARE_SAFETY_UNKNOWN,
        )
        self.assertEqual(self.state(None, 0.1), MODULE.HARDWARE_SAFETY_UNKNOWN)

    def test_a_bool_is_not_accepted_as_a_bitfield(self):
        self.assertEqual(self.state(True, 0.1), MODULE.HARDWARE_SAFETY_UNKNOWN)

    # The safety switch is display evidence. It must not become a gate: neither
    # an enable (a released switch must not unlock anything) nor an interlock
    # (an engaged or stale switch must not suppress a stop). This is enforced
    # by whitelisting every function allowed to read the safety state at all,
    # so a future reader inside a command path fails the suite rather than
    # silently changing the actuation contract.
    SAFETY_STATE_READERS = {
        "hardware_safety_state",  # the pure classifier itself
        "__init__",               # declares the two state attributes
        "_sys_status_cb",         # ingest
        "_publish_status",        # display payload
    }

    def _functions_reading_safety_state(self):
        tree = ast.parse(MODULE_PATH.read_text(encoding="utf-8"))
        markers = (
            "latest_sys_status",
            "hardware_safety_state",
            "MOTOR_OUTPUTS_BIT",
            "SYS_STATUS_TIMEOUT_SECONDS",
            "HARDWARE_SAFETY_",
        )
        readers = set()
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            dumped = ast.dump(node)
            if any(marker in dumped for marker in markers):
                readers.add(node.name)
        return readers

    def test_only_display_surfaces_read_the_safety_state(self):
        self.assertEqual(self._functions_reading_safety_state(), self.SAFETY_STATE_READERS)

    def test_the_whitelisted_readers_touch_no_command_path(self):
        tree = ast.parse(MODULE_PATH.read_text(encoding="utf-8"))
        commands = ("_publish_pair", "_publish_release", "_latch_emergency_stop")
        defined = {node.name for node in ast.walk(tree)
                   if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
        # Guard against the assertions rotting into vacuous truths after a rename.
        for command in commands:
            self.assertIn(command, defined)
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if node.name not in ("_sys_status_cb", "_publish_status"):
                continue
            dumped = ast.dump(node)
            for command in commands:
                self.assertNotIn(command, dumped, f"{node.name} reaches {command}")


if __name__ == "__main__":
    unittest.main()
