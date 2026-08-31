#!/usr/bin/env python3
"""Focused tests for the real-FCU command/feedback capture helper."""

from __future__ import annotations

from contextlib import redirect_stderr
import importlib.util
import inspect
import io
import json
from pathlib import Path
import sys
import tempfile
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
) -> dict[str, str]:
    return {
        "data": json.dumps(
            {
                "state": state,
                "fault": state,
                "ready": state in ("READY_DISARMED", "ARMED_NEUTRAL", "ACTIVE"),
                "connected": True,
                "armed": armed,
                "mode": "MANUAL",
                "neutral_only": neutral_only,
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
    left_pwm: int | None = None,
    right_pwm: int | None = None,
) -> None:
    left_pwm = pwm if left_pwm is None else left_pwm
    right_pwm = pwm if right_pwm is None else right_pwm
    session.record("/mavros/state", state_message(True))
    session.record(
        "/command_ingress/rc_axes",
        {"header": {}, "axes": [0.0, throttle], "buttons": [1]},
    )
    session.record("/mavros/rc/in", feedback_message([1515, 0, pwm]))
    session.record("/mavros/rc/out", feedback_message([right_pwm, 0, left_pwm]))
    session.record(
        "/command_ingress/status",
        status_message(
            "ACTIVE",
            True,
            False,
            throttle=throttle,
            rc_throttle_pwm=pwm,
            left_servo_pwm=left_pwm,
            right_servo_pwm=right_pwm,
        ),
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
            (index * 1_000_000, index * 100_000_000) for index in range(1, 30)
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

    def test_calibration_observation_rejects_non_straight_or_stale_evidence(self):
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
                {"header": {}, "axes": [0.01, 0.04], "buttons": [1]},
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
                    steering=0.01,
                    throttle=0.04,
                    rc_steering_pwm=1525,
                    rc_throttle_pwm=1550,
                    left_servo_pwm=850,
                    right_servo_pwm=850,
                ),
            )
            with self.assertRaisesRegex(
                MODULE.CaptureError, "straight steering"
            ):
                session.record_operator_observation("left", "stopped")
            session.close()

        stale_receipts = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 200_000_000),
                (3_000_000, 300_000_000),
                (4_000_000, 400_000_000),
                (5_000_000, 500_000_000),
                (6_000_000, 2_000_000_000),
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
            with self.assertRaisesRegex(MODULE.CaptureError, "stale"):
                session.record_operator_observation("left", "stopped")
            session.close()

        self.assertEqual(
            MODULE.parse_operator_observation("left stopped"),
            ("left", "stopped"),
        )
        with self.assertRaises(MODULE.CaptureError):
            MODULE.parse_operator_observation("left spinning")

    def test_calibration_state_age_matches_bridge_guard(self):
        accepted_receipts = iter(
            (
                (1_000_000, 100_000_000),
                (2_000_000, 1_300_000_000),
                (3_000_000, 1_400_000_000),
                (4_000_000, 1_500_000_000),
                (5_000_000, 1_600_000_000),
                (6_000_000, 2_200_000_000),
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
            event = session.record_operator_observation("left", "stopped")
            self.assertEqual(
                event["message"]["correlation"]["ages_ms"]["/mavros/state"],
                2100,
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
                session.record_operator_observation("left", "stopped")
            session.close()

    def test_not_observed_requires_the_governed_maximum_throttle(self):
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
            record_active_calibration_sample(session, 0.04, 850)
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
                session, MODULE.CALIBRATION_MAX_THROTTLE, 900
            )
            session.record_operator_observation("left", "not-observed")
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
        self.assertIn("calibration_left_observation_order_invalid", verdict["reasons"])
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
