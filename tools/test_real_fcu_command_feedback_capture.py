#!/usr/bin/env python3
"""Focused tests for the real-FCU command/feedback capture helper."""

from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import inspect
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

from mavros_msgs.msg import State
from sensor_msgs.msg import Joy


MODULE_PATH = Path(__file__).with_name("real_fcu_command_feedback_capture.py")
SPEC = importlib.util.spec_from_file_location(
    "real_fcu_command_feedback_capture", MODULE_PATH
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load module from {MODULE_PATH}")
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def status_message(
    state: str,
    armed: bool,
    neutral_only: bool,
    *,
    steering: float = 0.0,
    throttle: float = 0.0,
    rc_steering_pwm: int = 1515,
    rc_throttle_pwm: int = 1515,
    left_servo_pwm: int = 800,
    right_servo_pwm: int = 800,
    control_owner: str = "DASHBOARD",
) -> dict[str, str]:
    return {
        "data": json.dumps(
            {
                "state": state,
                "fault": state,
                "ready": state in (
                    "READY_DISARMED",
                    "ARMED_NEUTRAL",
                    "ACTIVE",
                    "HERELINK_CONTROL",
                ),
                "connected": True,
                "armed": armed,
                "mode": "MANUAL",
                "neutral_only": neutral_only,
                "control_owner": control_owner,
                "command": {"steering": steering, "throttle": throttle},
                "feedback_fresh": True,
                "rc_in_age_ms": 10,
                "rc_out_age_ms": 20,
                "resolved": {
                    "steering_rc": 1,
                    "throttle_rc": 3,
                    "left_servo": 3,
                    "right_servo": 1,
                },
                "measured": {
                    "rc_steering_pwm": rc_steering_pwm,
                    "rc_throttle_pwm": rc_throttle_pwm,
                    "left_servo_pwm": left_servo_pwm,
                    "right_servo_pwm": right_servo_pwm,
                },
                "separator_probe": "---",
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    }


def state_message(armed: bool) -> dict[str, object]:
    return {
        "header": {"stamp": {"sec": 12, "nanosec": 34}, "frame_id": ""},
        "connected": True,
        "armed": armed,
        "guided": False,
        "manual_input": True,
        "mode": "MANUAL",
        "system_status": 4,
    }


def feedback_message(channels: list[int]) -> dict[str, object]:
    return {
        "header": {"stamp": {"sec": 12, "nanosec": 34}, "frame_id": ""},
        "rssi": 0,
        "channels": channels,
    }


def begin_calibration_lifecycle(session) -> None:
    session.observe_status_publishers((session.expected_status_publisher,))
    session.record(
        "/command_ingress/status",
        status_message("READY_DISARMED", False, False),
    )
    session.record("/mavros/state", state_message(False))
    session.record("/mavros/rc/in", feedback_message([1515, 0, 1515]))
    session.record("/mavros/rc/out", feedback_message([800, 0, 800]))
    session.record(
        "/command_ingress/status",
        status_message("ARMED_NEUTRAL", True, False),
    )
    session.record("/mavros/state", state_message(True))


def record_active_calibration_sample(
    session,
    throttle: float,
    pwm: int,
    *,
    steering: float = 0.0,
    rc_steering_pwm: int = 1515,
    left_pwm: int | None = None,
    right_pwm: int | None = None,
    release: bool = True,
) -> None:
    left_pwm = pwm if left_pwm is None else left_pwm
    right_pwm = pwm if right_pwm is None else right_pwm
    session.record("/mavros/state", state_message(True))
    session.record(
        "/command_ingress/rc_axes",
        {"header": {}, "axes": [steering, throttle], "buttons": [1]},
    )
    session.record("/mavros/rc/in", feedback_message([rc_steering_pwm, 0, pwm]))
    session.record("/mavros/rc/out", feedback_message([right_pwm, 0, left_pwm]))
    session.record(
        "/command_ingress/status",
        status_message(
            "ACTIVE",
            True,
            False,
            steering=steering,
            throttle=throttle,
            rc_steering_pwm=rc_steering_pwm,
            rc_throttle_pwm=pwm,
            left_servo_pwm=left_pwm,
            right_servo_pwm=right_pwm,
        ),
    )
    if release:
        release_active_calibration_sample(session)


def release_active_calibration_sample(session) -> None:
    session.record(
        "/command_ingress/rc_axes",
        {"header": {}, "axes": [0.0, 0.0], "buttons": [0]},
    )
    session.record(
        "/command_ingress/status",
        status_message("ARMED_NEUTRAL", True, False),
    )


def finish_calibration_lifecycle(session) -> None:
    session.record(
        "/command_ingress/status",
        status_message("EMERGENCY_STOP", True, False),
    )
    session.record(
        "/command_ingress/status",
        status_message("EMERGENCY_STOP", False, False),
    )
    session.record("/mavros/state", state_message(False))


class CaptureContractTest(unittest.TestCase):
    def test_calibration_axis_bounds_accept_only_exact_float32_endpoints(self):
        steering_upper = struct.unpack("!f", struct.pack("!f", 0.20))[0]
        steering_lower = struct.unpack("!f", struct.pack("!f", -0.20))[0]
        throttle_upper = struct.unpack("!f", struct.pack("!f", 0.12))[0]
        self.assertEqual(
            MODULE.normalize_float32_axis(steering_upper, -0.20, 0.20), 0.20
        )
        self.assertEqual(
            MODULE.normalize_float32_axis(steering_lower, -0.20, 0.20), -0.20
        )
        self.assertEqual(MODULE.normalize_float32_axis(throttle_upper, 0.0, 0.12), 0.12)

        steering_outside = struct.unpack(
            "!f", struct.pack("!I", struct.unpack("!I", struct.pack("!f", 0.20))[0] + 1)
        )[0]
        throttle_outside = struct.unpack(
            "!f", struct.pack("!I", struct.unpack("!I", struct.pack("!f", 0.12))[0] + 1)
        )[0]
        self.assertIsNone(MODULE.normalize_float32_axis(steering_outside, -0.20, 0.20))
        self.assertIsNone(MODULE.normalize_float32_axis(throttle_outside, 0.0, 0.12))

    def test_calibration_correlation_normalizes_float32_command_endpoints(self):
        steering_upper = struct.unpack("!f", struct.pack("!f", 0.20))[0]
        throttle_upper = struct.unpack("!f", struct.pack("!f", 0.12))[0]
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 30)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(
                session,
                throttle_upper,
                1927,
                steering=steering_upper,
                rc_steering_pwm=1927,
                left_pwm=1100,
                right_pwm=800,
            )
            event = session.record_operator_observation("left", "started")
            session.close()

        self.assertEqual(
            event["message"]["correlation"]["command"],
            {"steering": 0.20, "throttle": 0.12},
        )

    def test_ros_environment_is_exactly_domain_43_subnet(self):
        valid = {
            "ROS_DOMAIN_ID": "43",
            "ROS_AUTOMATIC_DISCOVERY_RANGE": "SUBNET",
            "ROS_LOCALHOST_ONLY": "0",
        }
        self.assertEqual(MODULE.validate_ros_environment(valid), valid)
        for name in valid:
            broken = dict(valid)
            broken[name] = "wrong"
            with self.assertRaisesRegex(MODULE.CaptureError, name):
                MODULE.validate_ros_environment(broken)

    def test_capture_node_has_only_the_three_application_subscriptions(self):
        self.assertEqual(
            set(MODULE.TOPICS),
            {
                "/command_ingress/rc_axes",
                "/command_ingress/status",
                "/mavros/state",
            },
        )
        source = inspect.getsource(MODULE.CaptureNode)
        self.assertIn("create_subscription", source)
        self.assertNotIn("create_publisher", source)
        self.assertNotIn("create_client", source)
        self.assertIn("get_publishers_info_by_topic", source)
        self.assertIn("enable_rosout=False", source)
        self.assertIn("start_parameter_services=False", source)
        command_qos = MODULE.capture_qos("/command_ingress/rc_axes")
        self.assertEqual(
            command_qos.reliability, MODULE.ReliabilityPolicy.BEST_EFFORT
        )
        self.assertEqual(command_qos.depth, 1)
        self.assertEqual(MODULE.capture_qos("/command_ingress/status"), 10)
        state_qos = MODULE.capture_qos("/mavros/state")
        self.assertEqual(
            state_qos.reliability, MODULE.ReliabilityPolicy.BEST_EFFORT
        )
        self.assertEqual(state_qos.depth, 10)

    def test_calibration_status_publisher_binding_is_tier_specific(self):
        expected_publishers = {
            "t2b": "/real_fcu_rc_command_bridge",
            "t3a": "/real_fcu_rc_command_bridge_t3a",
        }
        with tempfile.TemporaryDirectory() as directory:
            for tier, expected in expected_publishers.items():
                session = MODULE.CaptureSession(
                    Path(directory) / tier,
                    tier,
                    esc_threshold_calibration=True,
                )
                self.assertEqual(session.expected_status_publisher, expected)
                self.assertEqual(
                    session.status_publisher_binding(),
                    {
                        "required": True,
                        "expected": expected,
                        "observed": [],
                        "pass": False,
                    },
                )
                session.close()

            normal = MODULE.CaptureSession(Path(directory) / "normal", "t2b")
            self.assertEqual(
                normal.status_publisher_binding(),
                {
                    "required": False,
                    "expected": None,
                    "observed": [],
                    "pass": True,
                },
            )
            MODULE.write_session_manifest(
                normal.run_dir,
                "t2b",
                MODULE.EXPECTED_ENVIRONMENT,
                {"head": "a", "main": "a", "origin_main": "a"},
                MODULE_PATH,
            )
            normal_manifest = json.loads(
                (normal.run_dir / "manifest/session.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertNotIn("status_publisher_binding", normal_manifest)
            normal.close()

    def test_capture_node_records_the_status_publisher_endpoint_identity(self):
        endpoints = [
            SimpleNamespace(
                node_namespace="/_NODE_NAMESPACE_UNKNOWN_",
                node_name="_NODE_NAME_UNKNOWN_",
            ),
            SimpleNamespace(
                node_namespace="/", node_name="real_fcu_rc_command_bridge_t3a"
            ),
        ]
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
            )
            node = SimpleNamespace(
                session=session,
                get_publishers_info_by_topic=mock.Mock(return_value=endpoints),
            )
            MODULE.CaptureNode._capture_status_publisher_binding(node)

            node.get_publishers_info_by_topic.assert_called_once_with(
                "/command_ingress/status"
            )
            self.assertEqual(
                session.status_publisher_binding()["observed"],
                ["/real_fcu_rc_command_bridge_t3a"],
            )
            session.close()

    def test_unknown_endpoint_identity_does_not_satisfy_publisher_binding(self):
        endpoints = [
            SimpleNamespace(
                node_namespace="/_NODE_NAMESPACE_UNKNOWN_",
                node_name="_NODE_NAME_UNKNOWN_",
            )
        ]
        self.assertEqual(MODULE.publisher_node_paths(endpoints), ())

        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
            )
            session.observe_status_publishers(MODULE.publisher_node_paths(endpoints))
            binding = session.status_publisher_binding()
            self.assertEqual(binding["observed"], [])
            self.assertFalse(binding["pass"])
            session.close()

    def test_calibration_status_binding_fails_missing_and_cross_tier(self):
        cases = (
            (
                "t2b",
                None,
                "status_publisher_binding_missing",
            ),
            (
                "t2b",
                "/real_fcu_rc_command_bridge_t3a",
                "status_publisher_binding_mismatch",
            ),
            (
                "t3a",
                "/real_fcu_rc_command_bridge",
                "status_publisher_binding_mismatch",
            ),
        )
        with tempfile.TemporaryDirectory() as directory:
            for index, (tier, observed, expected_reason) in enumerate(cases):
                run_dir = Path(directory) / f"case-{index}"
                session = MODULE.CaptureSession(
                    run_dir,
                    tier,
                    esc_threshold_calibration=True,
                )
                MODULE.write_session_manifest(
                    run_dir,
                    tier,
                    MODULE.EXPECTED_ENVIRONMENT,
                    {"head": "a", "main": "a", "origin_main": "a"},
                    MODULE_PATH,
                    esc_threshold_calibration=True,
                )
                if observed is not None:
                    session.observe_status_publishers((observed,))
                verdict = session.finalize()
                manifest = json.loads(
                    (run_dir / "manifest/session.json").read_text(encoding="utf-8")
                )

                self.assertFalse(verdict["pass"])
                self.assertIn(expected_reason, verdict["reasons"])
                self.assertEqual(
                    verdict["status_publisher_binding"]["observed"],
                    [] if observed is None else [observed],
                )
                self.assertEqual(
                    manifest["status_publisher_binding"],
                    verdict["status_publisher_binding"],
                )

    def test_calibration_adds_raw_feedback_without_changing_normal_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            normal = MODULE.CaptureSession(Path(directory) / "normal", "t2b")
            calibration = MODULE.CaptureSession(
                Path(directory) / "calibration",
                "t2b",
                esc_threshold_calibration=True,
            )
            self.assertEqual(set(normal.subscription_topics), set(MODULE.TOPICS))
            self.assertEqual(
                set(calibration.subscription_topics),
                {
                    *MODULE.TOPICS,
                    "/mavros/rc/in",
                    "/mavros/rc/out",
                },
            )
            self.assertIn(MODULE.OPERATOR_OBSERVATION_TOPIC, calibration.counts)
            self.assertNotIn(MODULE.OPERATOR_OBSERVATION_TOPIC, normal.counts)
            calibration.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, False),
            )
            calibration.record("/mavros/state", state_message(False))
            self.assertFalse(calibration.streams_ready())
            calibration.record(
                "/mavros/rc/in", feedback_message([1515, 0, 1515])
            )
            calibration.record(
                "/mavros/rc/out", feedback_message([800, 0, 800])
            )
            self.assertFalse(calibration.streams_ready())
            calibration.observe_status_publishers(
                (calibration.expected_status_publisher,)
            )
            self.assertTrue(calibration.streams_ready())
            normal.close()
            calibration.close()

        for topic in ("/mavros/rc/in", "/mavros/rc/out"):
            qos = MODULE.capture_qos(topic)
            self.assertEqual(qos.reliability, MODULE.ReliabilityPolicy.BEST_EFFORT)
            self.assertEqual(qos.depth, 10)

        with self.assertRaisesRegex(
            MODULE.CaptureError, "requires the t2b capture tier"
        ):
            MODULE.CaptureSession(
                Path("/tmp/not-created"),
                "t2a",
                esc_threshold_calibration=True,
            )

        options = MODULE.parse_args(("t2b", "--esc-threshold-calibration"))
        self.assertTrue(options.esc_threshold_calibration)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            MODULE.parse_args(("t2a", "--esc-threshold-calibration"))

    def test_t3a_requires_calibration_and_retains_demand_lifecycle(self):
        self.assertIn("t3a", MODULE.TIERS)
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            MODULE.parse_args(("t3a",))
        options = MODULE.parse_args(("t3a", "--esc-threshold-calibration"))
        self.assertEqual(options.tier, "t3a")
        self.assertTrue(options.esc_threshold_calibration)

        with self.assertRaisesRegex(
            MODULE.CaptureError, "t3a capture tier requires ESC-threshold calibration"
        ):
            MODULE.CaptureSession(Path("/tmp/not-created"), "t3a")

        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 40)
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            run_dir = MODULE.create_run_dir(
                root, "t3a", esc_threshold_calibration=True
            )
            session = MODULE.CaptureSession(
                run_dir,
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            self.assertEqual(
                set(session.subscription_topics),
                {*MODULE.TOPICS, *MODULE.CALIBRATION_TOPICS},
            )
            MODULE.write_session_manifest(
                run_dir,
                "t3a",
                MODULE.EXPECTED_ENVIRONMENT,
                {"head": "a", "main": "a", "origin_main": "a"},
                MODULE_PATH,
                esc_threshold_calibration=True,
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.03, 830)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(session, 0.04, 850)
            session.record_operator_observation("left", "started")
            session.record_operator_observation("right", "started")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()
            manifest = json.loads(
                (run_dir / "manifest/session.json").read_text(encoding="utf-8")
            )

        self.assertTrue(verdict["pass"])
        self.assertEqual(verdict["tier"], "t3a")
        self.assertEqual(verdict["final_status"]["state"], "EMERGENCY_STOP")
        self.assertFalse(verdict["final_state"]["armed"])
        self.assertTrue(
            run_dir.name.startswith("real_fcu_capture_t3a_esc_threshold_")
        )
        self.assertEqual(manifest["tier"], "t3a")
        self.assertTrue(manifest["esc_threshold_calibration"])
        self.assertEqual(manifest["calibration_max_steering"], 0.20)
        self.assertEqual(manifest["calibration_max_throttle"], 0.12)
        self.assertEqual(manifest["operator_observation_grace_seconds"], 10)
        self.assertEqual(len(manifest["subscription_topics"]), 5)
        expected_binding = {
            "required": True,
            "expected": "/real_fcu_rc_command_bridge_t3a",
            "observed": ["/real_fcu_rc_command_bridge_t3a"],
            "pass": True,
        }
        self.assertEqual(verdict["status_publisher_binding"], expected_binding)
        self.assertEqual(manifest["status_publisher_binding"], expected_binding)

    def test_t3a_runtime_markers_keep_the_distinct_tier(self):
        class FakeSession:
            def __init__(
                self,
                run_dir,
                tier,
                receipt_clock=MODULE._receipt_clock,
                esc_threshold_calibration=False,
            ):
                self.log_dir = run_dir / "logs"
                self.log_dir.mkdir(mode=0o700, parents=True)
                self.subscription_topics = {
                    **MODULE.TOPICS,
                    **MODULE.CALIBRATION_TOPICS,
                }

            def finalize(self, runtime_error=None):
                return {"pass": True, "event_count": 12, "reasons": []}

        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / "real_fcu_capture_t3a_esc_threshold_test"
            run_dir.mkdir(mode=0o700)
            output = io.StringIO()
            with (
                mock.patch.object(
                    MODULE, "validate_ros_environment", return_value={}
                ),
                mock.patch.object(MODULE, "repository_snapshot", return_value={}),
                mock.patch.object(MODULE, "create_run_dir", return_value=run_dir),
                mock.patch.object(MODULE, "CaptureSession", FakeSession),
                mock.patch.object(MODULE, "write_session_manifest"),
                mock.patch.object(MODULE, "_append_diagnostic"),
                mock.patch.object(MODULE, "CaptureNode", return_value=object()),
                mock.patch.object(MODULE.rclpy, "init"),
                mock.patch.object(MODULE.rclpy, "ok", return_value=True),
                mock.patch.object(
                    MODULE.rclpy, "spin_once", side_effect=KeyboardInterrupt
                ),
                mock.patch.object(MODULE, "close_ros_runtime", return_value=None),
                redirect_stdout(output),
            ):
                result = MODULE.run_capture(
                    "t3a", Path(directory), esc_threshold_calibration=True
                )

        self.assertEqual(result, 0)
        markers = output.getvalue()
        self.assertIn("REAL_FCU_CAPTURE_READY=PASS tier=T3A", markers)
        self.assertIn("steering=-0.20..0.20 bracket=per-side-pwm", markers)
        self.assertIn("release-Apply-before-input=true", markers)
        self.assertNotIn("steering=0 required", markers)
        self.assertIn("REAL_FCU_CAPTURE_FINAL=PASS tier=T3A", markers)

    def test_events_use_one_global_order_and_uniform_receipt_timestamps(self):
        receipts = iter(((1000, 100), (2000, 200), (3000, 300)))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2b", receipt_clock=lambda: next(receipts)
            )
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, False),
            )
            session.record(
                "/mavros/state", state_message(False), source_stamp_ns=12_000_000_034
            )
            session.record(
                "/command_ingress/rc_axes",
                {
                    "header": {
                        "stamp": {"sec": 21, "nanosec": 43},
                        "frame_id": "uvautoboat/rc_axes/v1",
                    },
                    "axes": [0.0, 0.0],
                    "buttons": [0],
                },
                source_stamp_ns=21_000_000_043,
            )
            session.close()

            events = [
                json.loads(line)
                for line in (Path(directory) / "evidence/events.jsonl")
                .read_text(encoding="utf-8")
                .splitlines()
            ]
        self.assertEqual([event["sequence"] for event in events], [1, 2, 3])
        self.assertEqual(
            [event["received_unix_ns"] for event in events], [1000, 2000, 3000]
        )
        self.assertEqual(
            [event["received_monotonic_ns"] for event in events], [100, 200, 300]
        )
        self.assertIsNone(events[0]["source_stamp_ns"])
        self.assertEqual(events[1]["source_stamp_ns"], 12_000_000_034)
        self.assertEqual(events[2]["source_stamp_ns"], 21_000_000_043)
        self.assertEqual(events[0]["decoded"]["separator_probe"], "---")

    def test_ros_message_headers_are_retained_without_topic_echo(self):
        receipts = iter(((1000, 100), (2000, 200)))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2b", receipt_clock=lambda: next(receipts)
            )
            state = State()
            state.header.stamp.sec = 12
            state.header.stamp.nanosec = 34
            state.connected = True
            state.mode = "MANUAL"
            axes = Joy()
            axes.header.stamp.sec = 21
            axes.header.stamp.nanosec = 43
            axes.header.frame_id = "uvautoboat/rc_axes/v1"
            axes.axes = [0.0, 0.0]
            axes.buttons = [0]
            session.record_ros_message("/mavros/state", state)
            session.record_ros_message("/command_ingress/rc_axes", axes)
            session.close()
            events = [
                json.loads(line)
                for line in (Path(directory) / "evidence/events.jsonl")
                .read_text(encoding="utf-8")
                .splitlines()
            ]
        self.assertEqual(events[0]["source_stamp_ns"], 12_000_000_034)
        self.assertEqual(events[1]["source_stamp_ns"], 21_000_000_043)
        self.assertEqual(events[1]["message"]["buttons"], [0])

    def test_interrupted_write_rolls_back_the_partial_final_event(self):
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(Path(directory), "t2a")
            real_write = MODULE.os.write
            interrupted = False

            def partial_then_interrupt(file_descriptor, payload):
                nonlocal interrupted
                if not interrupted:
                    interrupted = True
                    real_write(file_descriptor, payload[:12])
                    raise KeyboardInterrupt
                return real_write(file_descriptor, payload)

            with mock.patch.object(MODULE.os, "write", partial_then_interrupt):
                with self.assertRaises(KeyboardInterrupt):
                    session.record(
                        "/command_ingress/status",
                        status_message("READY_DISARMED", False, True),
                    )
            session.close()
            retained = (Path(directory) / "evidence/events.jsonl").read_bytes()
        self.assertEqual(retained, b"")
        self.assertEqual(session.sequence, 0)

    def test_ros_cleanup_errors_do_not_skip_remaining_cleanup(self):
        class BrokenNode:
            def destroy_node(self):
                raise RuntimeError("destroy failed")

        with mock.patch.object(MODULE.rclpy, "ok", return_value=True), mock.patch.object(
            MODULE.rclpy, "shutdown", side_effect=RuntimeError("shutdown failed")
        ) as shutdown:
            error = MODULE.close_ros_runtime(BrokenNode())
        shutdown.assert_called_once_with()
        self.assertIn("destroy_node RuntimeError: destroy failed", error)
        self.assertIn("shutdown RuntimeError: shutdown failed", error)

    def test_t2a_finalization_requires_clean_disarm_and_no_axes(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 7))
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory)
            session = MODULE.CaptureSession(
                run_dir, "t2a", receipt_clock=lambda: next(receipts)
            )
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, True),
            )
            session.record("/mavros/state", state_message(False))
            session.record(
                "/command_ingress/status",
                status_message("ARMED_NEUTRAL", True, True),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, True),
            )
            session.record("/mavros/state", state_message(False))
            verdict = session.finalize()
            retained = json.loads(
                (run_dir / "evidence/verdict.json").read_text(encoding="utf-8")
            )
        self.assertTrue(verdict["pass"])
        self.assertEqual(verdict, retained)
        self.assertEqual(verdict["event_counts"]["/command_ingress/rc_axes"], 0)
        self.assertEqual(verdict["final_status"]["state"], "READY_DISARMED")
        self.assertFalse(verdict["final_state"]["armed"])

    def test_stream_readiness_requires_valid_disarmed_tier_matched_samples(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 4))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2a", receipt_clock=lambda: next(receipts)
            )
            session.record("/command_ingress/status", {"data": "not-json"})
            session.record("/mavros/state", state_message(False))
            self.assertFalse(session.streams_ready())
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, True),
            )
            self.assertTrue(session.streams_ready())
            session.close()

    def test_armed_final_state_and_invalid_status_fail_closed(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 4))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2a", receipt_clock=lambda: next(receipts)
            )
            session.record("/command_ingress/status", {"data": "not-json\n---\n"})
            session.record("/mavros/state", state_message(True))
            verdict = session.finalize()
        self.assertFalse(verdict["pass"])
        self.assertIn("invalid_status_evidence", verdict["reasons"])
        self.assertIn("final_state_not_disarmed", verdict["reasons"])

    def test_transient_state_stale_accepts_null_feedback_without_weakening_phases(self):
        transient = json.loads(status_message("READY_DISARMED", False, False)["data"])
        transient.update(
            {
                "state": "STATE_STALE",
                "fault": "STATE_STALE",
                "ready": False,
                "connected": False,
                "mode": "",
                "feedback_fresh": False,
                "rc_in_age_ms": None,
                "rc_out_age_ms": None,
                "measured": {
                    "rc_steering_pwm": None,
                    "rc_throttle_pwm": None,
                    "left_servo_pwm": None,
                    "right_servo_pwm": None,
                },
            }
        )
        self.assertIsNone(MODULE.status_evidence_error(transient, "t3a"))

        malformed = json.loads(json.dumps(transient))
        malformed["measured"]["left_servo_pwm"] = "unknown"
        self.assertEqual(
            MODULE.status_evidence_error(malformed, "t3a"),
            "invalid_status_measured_feedback",
        )

        missing = json.loads(json.dumps(transient))
        del missing["measured"]["left_servo_pwm"]
        self.assertEqual(
            MODULE.status_evidence_error(missing, "t3a"),
            "invalid_status_measured_feedback",
        )

        phase = json.loads(status_message("ACTIVE", True, False)["data"])
        phase["measured"]["left_servo_pwm"] = None
        self.assertEqual(
            MODULE.status_evidence_error(phase, "t3a"),
            "invalid_status_measured_feedback",
        )

        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t3a", esc_threshold_calibration=True
            )
            session.record(
                "/command_ingress/status",
                {"data": json.dumps(transient, separators=(",", ":"))},
            )
            self.assertEqual(session.invalid_status_count, 0)
            self.assertEqual(session.states_seen, ["STATE_STALE"])
            session.close()

    def test_herelink_phase_status_is_schema_valid_but_not_calibration_evidence(self):
        legacy = json.loads(
            status_message(
                "HERELINK_WAITING_NEUTRAL",
                True,
                False,
                control_owner="HERELINK",
            )["data"]
        )
        self.assertEqual(
            MODULE.status_evidence_error(legacy, "t3a"),
            "invalid_status_legacy_herelink_wait",
        )

        for state, expected_ready in (
            ("HERELINK_HANDOVER", False),
            ("HERELINK_CONTROL", True),
        ):
            with self.subTest(state=state):
                status = json.loads(
                    status_message(
                        state,
                        True,
                        False,
                        control_owner="HERELINK",
                    )["data"]
                )
                self.assertIs(status["ready"], expected_ready)
                self.assertIsNone(MODULE.status_evidence_error(status, "t3a"))
                status["control_owner"] = "DASHBOARD"
                self.assertEqual(
                    MODULE.status_evidence_error(status, "t3a"),
                    "invalid_status_control_owner",
                )

        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 50)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.12, 1927)
            session.record(
                "/command_ingress/status",
                status_message(
                    "HERELINK_CONTROL",
                    True,
                    False,
                    control_owner="HERELINK",
                ),
            )
            with self.assertRaisesRegex(MODULE.CaptureError, "recent ACTIVE plateau"):
                session.record_operator_observation("left", "stopped")
            session.close()

    def test_disarmed_only_capture_cannot_pass_a_tier(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 3))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2a", receipt_clock=lambda: next(receipts)
            )
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, True),
            )
            session.record("/mavros/state", state_message(False))
            verdict = session.finalize()
        self.assertFalse(verdict["pass"])
        self.assertIn("armed_state_not_observed", verdict["reasons"])
        self.assertIn("tier_status_sequence_incomplete", verdict["reasons"])

    def test_incomplete_status_objects_cannot_supply_the_tier_sequence(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 6))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2a", receipt_clock=lambda: next(receipts)
            )
            session.record(
                "/command_ingress/status",
                {"data": json.dumps({"state": "READY_DISARMED"})},
            )
            session.record(
                "/command_ingress/status",
                {"data": json.dumps({"state": "ARMED_NEUTRAL"})},
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, True),
            )
            session.record("/mavros/state", state_message(False))
            verdict = session.finalize()
        self.assertFalse(verdict["pass"])
        self.assertIn("invalid_status_evidence", verdict["reasons"])
        self.assertIn("tier_status_sequence_incomplete", verdict["reasons"])

    def test_tier_axes_policy_fails_closed(self):
        def final_status(neutral_only: bool) -> dict[str, str]:
            return status_message(
                "READY_DISARMED" if neutral_only else "EMERGENCY_STOP",
                False,
                neutral_only,
            )

        with tempfile.TemporaryDirectory() as directory:
            receipts = iter((index * 1000, index * 100) for index in range(1, 4))
            t2a = MODULE.CaptureSession(
                Path(directory) / "t2a", "t2a", receipt_clock=lambda: next(receipts)
            )
            t2a.record("/command_ingress/status", final_status(True))
            t2a.record("/mavros/state", state_message(False))
            t2a.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.0], "buttons": [0]},
            )
            self.assertIn("t2a_rc_axes_observed", t2a.finalize()["reasons"])

            receipts = iter((index * 1000, index * 100) for index in range(1, 3))
            t2b = MODULE.CaptureSession(
                Path(directory) / "t2b", "t2b", receipt_clock=lambda: next(receipts)
            )
            t2b.record("/command_ingress/status", final_status(False))
            t2b.record("/mavros/state", state_message(False))
            self.assertIn("t2b_rc_axes_missing", t2b.finalize()["reasons"])

    def test_t2b_complete_status_sequence_and_command_frame_can_pass(self):
        receipts = iter((index * 1000, index * 100) for index in range(1, 10))
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory), "t2b", receipt_clock=lambda: next(receipts)
            )
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, False),
            )
            session.record("/mavros/state", state_message(False))
            session.record(
                "/command_ingress/status",
                status_message("ARMED_NEUTRAL", True, False),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.1, 0.08], "buttons": [1]},
            )
            session.record(
                "/command_ingress/status", status_message("ACTIVE", True, False)
            )
            session.record(
                "/command_ingress/status",
                status_message("EMERGENCY_STOP", True, False),
            )
            session.record(
                "/command_ingress/status",
                status_message("EMERGENCY_STOP", False, False),
            )
            session.record("/mavros/state", state_message(False))
            verdict = session.finalize()
        self.assertTrue(verdict["pass"])
        self.assertNotIn("status_publisher_binding", verdict)
        self.assertEqual(
            verdict["states_seen"],
            ["READY_DISARMED", "ARMED_NEUTRAL", "ACTIVE", "EMERGENCY_STOP"],
        )

    def test_calibration_requires_raw_feedback_and_both_side_observations(self):
        with tempfile.TemporaryDirectory() as directory:
            receipts = iter((index * 1000, index * 100) for index in range(1, 10))
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            session.record(
                "/command_ingress/status",
                status_message("READY_DISARMED", False, False),
            )
            session.record("/mavros/state", state_message(False))
            session.record(
                "/command_ingress/status",
                status_message("ARMED_NEUTRAL", True, False),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.04], "buttons": [1]},
            )
            session.record(
                "/command_ingress/status",
                status_message("ACTIVE", True, False, throttle=0.04),
            )
            session.record(
                "/command_ingress/status",
                status_message("EMERGENCY_STOP", False, False),
            )
            session.record("/mavros/state", state_message(False))
            verdict = session.finalize()

        self.assertFalse(verdict["pass"])
        self.assertIn("calibration_rc_in_missing", verdict["reasons"])
        self.assertIn("calibration_rc_out_missing", verdict["reasons"])
        self.assertIn("calibration_left_observation_incomplete", verdict["reasons"])
        self.assertIn("calibration_right_observation_incomplete", verdict["reasons"])

    def test_complete_correlated_calibration_observations_can_pass(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 50)
        )
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory)
            session = MODULE.CaptureSession(
                run_dir,
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.03, 830)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(session, 0.04, 850)
            session.record_operator_observation("left", "started")
            record_active_calibration_sample(session, 0.05, 870)
            session.record_operator_observation("right", "started")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()
            retained = json.loads(
                (run_dir / "evidence/verdict.json").read_text(encoding="utf-8")
            )

        self.assertTrue(verdict["pass"])
        self.assertEqual(verdict, retained)
        self.assertEqual(verdict["calibration"]["left"]["outcome"], "started")
        self.assertEqual(verdict["calibration"]["right"]["outcome"], "started")
        self.assertEqual(
            verdict["calibration"]["left"]["lower_no_rotation"]["throttle"],
            0.03,
        )
        self.assertEqual(
            verdict["calibration"]["left"]["terminal_observation"]["throttle"],
            0.04,
        )

    def test_calibration_observation_rejects_out_of_bounds_or_expired_evidence(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 10)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.21, 0.04], "buttons": [1]},
            )
            session.record(
                "/mavros/rc/in", feedback_message([1525, 0, 1550])
            )
            session.record(
                "/mavros/rc/out", feedback_message([850, 0, 850])
            )
            session.record(
                "/command_ingress/status",
                status_message(
                    "ACTIVE",
                    True,
                    False,
                    steering=0.21,
                    throttle=0.04,
                    rc_steering_pwm=1525,
                    rc_throttle_pwm=1550,
                    left_servo_pwm=850,
                    right_servo_pwm=850,
                ),
            )
            with self.assertRaisesRegex(
                MODULE.CaptureError, "steering is outside calibration bounds"
            ):
                session._calibration_correlation(600_000_000)
            session.close()

        stale_receipts = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 200_000_000),
                (3_000_000, 300_000_000),
                (4_000_000, 400_000_000),
                (5_000_000, 500_000_000),
                (6_000_000, 600_000_000),
                (7_000_000, 700_000_000),
                (8_000_000, 12_000_000_000),
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(stale_receipts),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.04], "buttons": [1]},
            )
            session.record(
                "/mavros/rc/in", feedback_message([1515, 0, 1550])
            )
            session.record(
                "/mavros/rc/out", feedback_message([850, 0, 850])
            )
            session.record(
                "/command_ingress/status",
                status_message(
                    "ACTIVE",
                    True,
                    False,
                    throttle=0.04,
                    rc_throttle_pwm=1550,
                    left_servo_pwm=850,
                    right_servo_pwm=850,
                ),
            )
            release_active_calibration_sample(session)
            with self.assertRaisesRegex(MODULE.CaptureError, "expired"):
                session.record_operator_observation("left", "stopped")
            session.close()

        self.assertEqual(
            MODULE.parse_operator_observation("left stopped"),
            ("left", "stopped"),
        )
        with self.assertRaises(MODULE.CaptureError):
            MODULE.parse_operator_observation("left spinning")

    def test_operator_observation_can_bind_to_recent_released_active_plateau(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 40)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.12, 1927)

            left = session.record_operator_observation("left", "stopped")
            right = session.record_operator_observation("right", "stopped")
            self.assertEqual(
                left["message"]["correlation"]["source"],
                "recent_active_plateau",
            )
            self.assertGreater(left["message"]["correlation"]["operator_delay_ms"], 0)
            self.assertEqual(
                right["message"]["correlation"]["sequences"],
                left["message"]["correlation"]["sequences"],
            )
            session.close()

    def test_operator_observation_rejects_live_or_non_neutral_release(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 50)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.12, 1927, release=False)
            with self.assertRaisesRegex(MODULE.CaptureError, "disabled neutral release"):
                session.record_operator_observation("left", "stopped")
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.01, 0.0], "buttons": [0]},
            )
            with self.assertRaisesRegex(MODULE.CaptureError, "disabled neutral release"):
                session.record_operator_observation("left", "stopped")
            release_active_calibration_sample(session)
            session.record_operator_observation("left", "stopped")
            session.close()

    def test_stale_unknown_or_invalid_status_clears_released_plateau(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 100)
        )
        for state in ("STATE_STALE", "UNKNOWN", "BOOTING"):
            with self.subTest(state=state), tempfile.TemporaryDirectory() as directory:
                session = MODULE.CaptureSession(
                    Path(directory),
                    "t3a",
                    esc_threshold_calibration=True,
                    receipt_clock=lambda: next(receipts),
                )
                begin_calibration_lifecycle(session)
                record_active_calibration_sample(session, 0.12, 1927)
                transient = json.loads(status_message(state, True, False)["data"])
                transient["ready"] = False
                transient["feedback_fresh"] = False
                transient["rc_in_age_ms"] = None
                transient["rc_out_age_ms"] = None
                session.record(
                    "/command_ingress/status",
                    {"data": json.dumps(transient, separators=(",", ":"))},
                )
                with self.assertRaisesRegex(MODULE.CaptureError, "recent ACTIVE plateau"):
                    session.record_operator_observation("left", "stopped")
                session.close()

        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.12, 1927)
            invalid = json.loads(status_message("ACTIVE", True, False)["data"])
            invalid["measured"]["left_servo_pwm"] = None
            session.record(
                "/command_ingress/status",
                {"data": json.dumps(invalid, separators=(",", ":"))},
            )
            with self.assertRaisesRegex(MODULE.CaptureError, "recent ACTIVE plateau"):
                session.record_operator_observation("left", "stopped")
            session.close()

    def test_operator_grace_starts_at_release_not_old_active_sample(self):
        receipt_values = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 200_000_000),
                (3_000_000, 300_000_000),
                (4_000_000, 400_000_000),
                (5_000_000, 500_000_000),
                (6_000_000, 600_000_000),
                (7_000_000, 700_000_000),
                (8_000_000, 800_000_000),
                (9_000_000, 900_000_000),
                (10_000_000, 1_000_000_000),
                (11_000_000, 1_100_000_000),
                (12_000_000, 20_000_000_000),
                (13_000_000, 20_100_000_000),
                (14_000_000, 20_200_000_000),
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipt_values),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.12, 1927, release=False)
            release_active_calibration_sample(session)
            event = session.record_operator_observation("left", "stopped")
            self.assertLess(event["message"]["correlation"]["operator_delay_ms"], 1000)
            session.close()

    def test_recent_plateau_is_cleared_by_new_demand_and_disarm(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 50)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.08, 1700)
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.09], "buttons": [1]},
            )
            with self.assertRaisesRegex(MODULE.CaptureError, "recent ACTIVE plateau"):
                session.record_operator_observation("left", "stopped")

            record_active_calibration_sample(session, 0.09, 1750)
            session.record("/mavros/state", state_message(False))
            with self.assertRaisesRegex(MODULE.CaptureError, "recent ACTIVE plateau"):
                session.record_operator_observation("left", "stopped")
            session.close()

    def test_nonzero_steering_can_bracket_each_side_by_delivered_pwm(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 60)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t3a",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(
                session,
                0.12,
                1927,
                steering=0.02,
                rc_steering_pwm=1556,
                left_pwm=979,
                right_pwm=928,
            )
            session.record_operator_observation("left", "stopped")
            record_active_calibration_sample(
                session,
                0.12,
                1927,
                steering=0.03,
                rc_steering_pwm=1577,
                left_pwm=994,
                right_pwm=913,
            )
            session.record_operator_observation("left", "started")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()

        self.assertNotIn("calibration_left_threshold_not_bracketed", verdict["reasons"])
        self.assertNotIn("calibration_left_pwm_not_bracketed", verdict["reasons"])
        self.assertEqual(verdict["calibration"]["left"]["outcome"], "started")
        self.assertEqual(
            verdict["calibration"]["left"]["lower_no_rotation"]["steering"],
            0.02,
        )
        self.assertEqual(
            verdict["calibration"]["left"]["terminal_observation"]["steering"],
            0.03,
        )

    def test_calibration_state_age_matches_bridge_guard(self):
        accepted_receipts = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 1_300_000_000),
                (3_000_000, 1_400_000_000),
                (4_000_000, 1_500_000_000),
                (5_000_000, 1_600_000_000),
                (6_000_000, 2_200_000_000),
                (7_000_000, 2_300_000_000),
                (8_000_000, 2_400_000_000),
                (9_000_000, 2_500_000_000),
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(accepted_receipts),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.04], "buttons": [1]},
            )
            session.record("/mavros/rc/in", feedback_message([1515, 0, 850]))
            session.record("/mavros/rc/out", feedback_message([850, 0, 850]))
            session.record(
                "/command_ingress/status",
                status_message(
                    "ACTIVE",
                    True,
                    False,
                    throttle=0.04,
                    rc_throttle_pwm=850,
                    left_servo_pwm=850,
                    right_servo_pwm=850,
                ),
            )
            release_active_calibration_sample(session)
            event = session.record_operator_observation("left", "stopped")
            self.assertEqual(
                event["message"]["correlation"]["ages_ms"]["/mavros/state"],
                1500,
            )
            session.close()

        rejected_receipts = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 2_700_000_000),
                (3_000_000, 2_800_000_000),
                (4_000_000, 2_900_000_000),
                (5_000_000, 3_000_000_000),
                (6_000_000, 3_100_000_000),
            )
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(rejected_receipts),
            )
            session.record("/mavros/state", state_message(True))
            session.record(
                "/command_ingress/rc_axes",
                {"header": {}, "axes": [0.0, 0.04], "buttons": [1]},
            )
            session.record("/mavros/rc/in", feedback_message([1515, 0, 850]))
            session.record("/mavros/rc/out", feedback_message([850, 0, 850]))
            session.record(
                "/command_ingress/status",
                status_message(
                    "ACTIVE",
                    True,
                    False,
                    throttle=0.04,
                    rc_throttle_pwm=850,
                    left_servo_pwm=850,
                    right_servo_pwm=850,
                ),
            )
            with self.assertRaisesRegex(
                MODULE.CaptureError, "stale for /mavros/state"
            ):
                session._calibration_correlation(3_100_000_000)
            session.close()

    def test_not_observed_requires_the_governed_per_side_envelope_endpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            receipts = iter(
                (index * 1_000_000, index * 100_000_000)
                for index in range(1, 60)
            )
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.03, 830)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(
                session, MODULE.CALIBRATION_MAX_THROTTLE, 900
            )
            session.record_operator_observation("left", "not-observed")
            session.record_operator_observation("right", "not-observed")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()

        self.assertFalse(verdict["pass"])
        self.assertIn("calibration_left_maximum_not_reached", verdict["reasons"])
        self.assertIn("calibration_right_maximum_not_reached", verdict["reasons"])

        with tempfile.TemporaryDirectory() as directory:
            receipts = iter(
                (index * 1_000_000, index * 100_000_000)
                for index in range(1, 60)
            )
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.03, 830)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(
                session,
                MODULE.CALIBRATION_MAX_THROTTLE,
                900,
                steering=MODULE.CALIBRATION_MAX_STEERING,
                rc_steering_pwm=1927,
                left_pwm=1000,
                right_pwm=850,
            )
            session.record_operator_observation("left", "not-observed")
            record_active_calibration_sample(
                session,
                MODULE.CALIBRATION_MAX_THROTTLE,
                900,
                steering=-MODULE.CALIBRATION_MAX_STEERING,
                rc_steering_pwm=1102,
                left_pwm=850,
                right_pwm=1000,
            )
            session.record_operator_observation("right", "not-observed")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()

        self.assertTrue(verdict["pass"])
        self.assertEqual(verdict["calibration"]["left"]["outcome"], "not-observed")
        self.assertEqual(verdict["calibration"]["right"]["outcome"], "not-observed")

    def test_highest_stopped_point_cannot_be_hidden_by_a_lower_repeat(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 70)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.05, 870)
            session.record_operator_observation("left", "stopped")
            record_active_calibration_sample(session, 0.03, 830)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(session, 0.04, 850)
            session.record_operator_observation("left", "started")
            session.record_operator_observation("right", "started")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()

        self.assertFalse(verdict["pass"])
        self.assertIn("calibration_left_pwm_not_bracketed", verdict["reasons"])
        self.assertEqual(
            verdict["calibration"]["left"]["lower_no_rotation"]["throttle"],
            0.05,
        )

    def test_started_observation_requires_higher_delivered_pwm_per_side(self):
        receipts = iter(
            (index * 1_000_000, index * 100_000_000) for index in range(1, 70)
        )
        with tempfile.TemporaryDirectory() as directory:
            session = MODULE.CaptureSession(
                Path(directory),
                "t2b",
                esc_threshold_calibration=True,
                receipt_clock=lambda: next(receipts),
            )
            begin_calibration_lifecycle(session)
            record_active_calibration_sample(session, 0.03, 900)
            session.record_operator_observation("left", "stopped")
            session.record_operator_observation("right", "stopped")
            record_active_calibration_sample(
                session,
                0.04,
                850,
                left_pwm=850,
                right_pwm=920,
            )
            session.record_operator_observation("left", "started")
            session.record_operator_observation("right", "started")
            finish_calibration_lifecycle(session)
            verdict = session.finalize()

        self.assertFalse(verdict["pass"])
        self.assertIn("calibration_left_pwm_not_bracketed", verdict["reasons"])
        self.assertNotIn("calibration_right_pwm_not_bracketed", verdict["reasons"])


if __name__ == "__main__":
    unittest.main()
