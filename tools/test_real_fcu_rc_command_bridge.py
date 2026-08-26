#!/usr/bin/env python3
"""Focused pure-function and ROS-node tests for real_fcu_rc_command_bridge.py."""

from __future__ import annotations

import importlib.util
import hashlib
import inspect
import json
import os
import pathlib
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

import rclpy
from mavros_msgs.msg import State
from rcl_interfaces.msg import ParameterType, ParameterValue
from rclpy.signals import SignalHandlerOptions
from std_msgs.msg import Bool
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

    def tearDown(self):
        self.node.destroy_node()

    @staticmethod
    def vehicle(armed, mode="MANUAL"):
        message = State()
        message.connected = True
        message.armed = armed
        message.mode = mode
        return message

    def set_valid_feedback(self, now):
        self.node.latest_rc_in = (1500, 1500, 1500)
        self.node.latest_rc_out = (800, 800, 800)
        self.node.latest_rc_in_at = now - 0.1
        self.node.latest_rc_out_at = now - 0.1

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


if __name__ == "__main__":
    unittest.main()
