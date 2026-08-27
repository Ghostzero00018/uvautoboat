#!/usr/bin/env python3
"""Pure tests for live FCU-to-VRX evidence correlation."""

from __future__ import annotations

from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).with_name("fcu_to_vrx_evidence.py")
SPEC = importlib.util.spec_from_file_location("fcu_to_vrx_evidence", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


CONFIG = {
    "left_channel": 3,
    "right_channel": 1,
    "left": {"minimum": 800, "trim": 800, "maximum": 2200},
    "right": {"minimum": 800, "trim": 800, "maximum": 2200},
    "max_thrust": 800.0,
}


def event(kind, timestamp, **values):
    return {
        "schema": MODULE.SCHEMA,
        "kind": kind,
        "captured_unix_ns": timestamp,
        **values,
    }


def passing_events():
    base = 1_000_000_000_000
    pi = [
        event("observer_started", base, side="pi", config=CONFIG),
        event("observer_ready", base + 1_000_000, side="pi"),
        event("state", base + 10_000_000, connected=True, armed=False),
        event("sys_status", base + 20_000_000, hardware_safety_on=True),
        event("rc_out", base + 30_000_000, left_pwm=800, right_pwm=800),
        event("state", base + 1_000_000_000, connected=True, armed=True),
        event("camera", base + 1_100_000_000, source_stamp_ns=11),
        event("rc_out", base + 2_000_000_000, left_pwm=940, right_pwm=800),
        event("rc_out", base + 4_000_000_000, left_pwm=800, right_pwm=800),
        event("state", base + 5_000_000_000, connected=True, armed=False),
        event("sys_status", base + 5_100_000_000, hardware_safety_on=True),
    ]
    expected_left = 80.0
    vrx = [
        event("observer_started", base, side="vrx", config=CONFIG),
        event("observer_ready", base + 2_000_000, side="vrx"),
        event("pose", base + 1_900_000_000, x=0.0, y=0.0, z=0.0),
        event(
            "servo_output_raw",
            base + 2_040_000_000,
            bridge_received_unix_ns=base + 2_030_000_000,
            left_pwm=940,
            right_pwm=800,
            left_thrust=expected_left,
            right_thrust=0.0,
        ),
        # Cross-topic callbacks may be processed before the evidence callback
        # even though the bridge publishes the evidence message first.
        event("left_thrust", base + 2_035_000_000, value=expected_left),
        event("right_thrust", base + 2_037_000_000, value=0.0),
        event("pose", base + 3_000_000_000, x=0.3, y=0.0, z=0.0),
        event(
            "servo_output_raw",
            base + 4_020_000_000,
            bridge_received_unix_ns=base + 4_010_000_000,
            left_pwm=800,
            right_pwm=800,
            left_thrust=0.0,
            right_thrust=0.0,
        ),
        event("left_thrust", base + 4_030_000_000, value=0.0),
        event("right_thrust", base + 4_040_000_000, value=0.0),
    ]
    return pi, vrx


class CorrelationTests(unittest.TestCase):
    def adjudicate(self, pi, vrx):
        return MODULE.adjudicate_events(
            pi,
            vrx,
            max_pwm_skew_ns=100_000_000,
            max_thrust_delay_ns=100_000_000,
            max_motion_delay_ns=2_000_000_000,
            min_motion_metres=0.2,
        )

    def test_complete_value_and_time_correlation_passes(self):
        pi, vrx = passing_events()
        verdict = self.adjudicate(pi, vrx)
        self.assertEqual(verdict["verdict"], "PASS")
        self.assertEqual(verdict["pwm"], {"left": 940, "right": 800})
        self.assertGreaterEqual(verdict["motion_metres"], 0.2)

    def test_pwm_drift_between_dashboard_and_udp_is_rejected(self):
        pi, vrx = passing_events()
        raw = next(item for item in vrx if item["kind"] == "servo_output_raw")
        raw["left_pwm"] = 941
        with self.assertRaisesRegex(MODULE.EvidenceError, "matching UDP servo frame"):
            self.adjudicate(pi, vrx)

    def test_missing_motion_and_final_safety_are_rejected(self):
        pi, vrx = passing_events()
        poses = [item for item in vrx if item["kind"] == "pose"]
        poses[-1]["x"] = 0.05
        with self.assertRaisesRegex(MODULE.EvidenceError, "motion threshold"):
            self.adjudicate(pi, vrx)

        pi, vrx = passing_events()
        pi[:] = [item for item in pi if not (
            item["kind"] == "sys_status"
            and item["captured_unix_ns"] > pi[0]["captured_unix_ns"] + 1_000_000_000
        )]
        with self.assertRaisesRegex(MODULE.EvidenceError, "restored hardware safety"):
            self.adjudicate(pi, vrx)

    def test_observer_abort_is_never_adjudicated_as_a_pass(self):
        pi, vrx = passing_events()
        vrx.append(event("observer_abort", 2_000_000_000_000, side="vrx"))
        with self.assertRaisesRegex(MODULE.EvidenceError, "vrx observer recorded an abort"):
            self.adjudicate(pi, vrx)

    def test_bridge_event_uses_live_mapping_and_received_timestamp(self):
        payload = MODULE.bridge_servo_event(
            CONFIG,
            left_pwm=940,
            right_pwm=800,
            time_usec=123,
            received_unix_ns=456,
        )
        self.assertEqual(payload["bridge_received_unix_ns"], 456)
        self.assertEqual(payload["left_thrust"], 80.0)
        self.assertEqual(payload["right_thrust"], 0.0)

    def test_bridge_publishes_structured_raw_evidence_before_thrust(self):
        source = Path(__file__).with_name("servo_command_bridge.py").read_text(
            encoding="utf-8"
        )
        publisher = "self.pub_servo_evidence.publish(evidence_msg)"
        left_thrust = "self.pub_left.publish(left_msg)"
        right_thrust = "self.pub_right.publish(right_msg)"
        self.assertIn("String, '/fcu_to_vrx/servo_output_raw', 10", source)
        self.assertIn("received_unix_ns=time.time_ns()", source)
        self.assertLess(source.index(publisher), source.index(left_thrust))
        self.assertLess(source.index(publisher), source.index(right_thrust))

    def test_observers_are_subscriber_only(self):
        source = MODULE_PATH.read_text(encoding="utf-8")
        self.assertNotIn("create_publisher", source)
        self.assertNotIn("create_client", source)

    def test_event_capture_syncs_once_at_finalization_not_per_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            with mock.patch.object(MODULE.os, "fsync") as fsync:
                MODULE.append_event(path, "sample", value=1)
                fsync.assert_not_called()
                MODULE.sync_evidence(path)
                fsync.assert_called_once()

    def test_adjudicate_cli_reads_retained_jsonl_and_emits_pass_marker(self):
        pi, vrx = passing_events()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pi_path = root / "pi.jsonl"
            vrx_path = root / "vrx.jsonl"
            for path, events in ((pi_path, pi), (vrx_path, vrx)):
                path.write_text(
                    "".join(
                        json.dumps(item, separators=(",", ":"), sort_keys=True) + "\n"
                        for item in events
                    ),
                    encoding="utf-8",
                )
            output = io.StringIO()
            with redirect_stdout(output):
                rc = MODULE.main(
                    [
                        "adjudicate",
                        "--pi-events",
                        str(pi_path),
                        "--vrx-events",
                        str(vrx_path),
                        "--max-pwm-skew-ms",
                        "100",
                        "--max-thrust-delay-ms",
                        "100",
                        "--max-motion-delay-seconds",
                        "2",
                        "--min-motion-metres",
                        "0.2",
                    ]
                )
        self.assertEqual(rc, 0)
        self.assertIn("FCU_TO_VRX_EVIDENCE=PASS", output.getvalue())


class _Header:
    def __init__(self, frame_id):
        self.frame_id = frame_id


class _Transform:
    """Minimal duck type for geometry_msgs/TransformStamped."""

    def __init__(self, frame_id, child_frame_id):
        self.header = _Header(frame_id)
        self.child_frame_id = child_frame_id


# The shape observed on /wamv/pose in this workspace. The gz PosePublisher
# runs with publish_link_pose=false and publish_model_pose=true (the latter
# from this workspace's vrx commit e384cd65), so the moving transform is the
# model root under the world frame, with the bare model name as its child.
# Sensor parents are double-prefixed, as recorded on 10/04/2026: the frame is
# wamv/wamv/base_link, not wamv/base_link. That name does end in "base_link",
# which is why the previous filter looked plausible -- but it appears only as
# a PARENT here, never as a child_frame_id.
VRX_POSE_MESSAGE = [
    _Transform("sydney_regatta", "wamv"),
    _Transform(
        "wamv/wamv/base_link", "wamv/wamv/base_link/front_left_camera_sensor"
    ),
    _Transform("wamv/wamv/base_link", "wamv/wamv/base_link/lidar_wamv_sensor"),
]


class WorldTransformSelectionTests(unittest.TestCase):
    def test_selects_the_model_root_under_the_world_frame(self):
        transform = MODULE.select_world_transform(
            VRX_POSE_MESSAGE, "sydney_regatta"
        )
        self.assertIsNotNone(transform)
        self.assertEqual(transform.child_frame_id, "wamv")
        self.assertEqual(transform.header.frame_id, "sydney_regatta")

    def test_the_previous_base_link_child_filter_matched_nothing(self):
        # Regression guard for the defect this replaced: base_link never
        # appears as a child_frame_id, so the old filter starved the pose
        # stream and the observer stayed in WAIT_DATA forever.
        matched = [
            item
            for item in VRX_POSE_MESSAGE
            if str(item.child_frame_id).endswith("base_link")
        ]
        self.assertEqual(matched, [])

    def test_a_wrong_world_frame_selects_nothing(self):
        self.assertIsNone(
            MODULE.select_world_transform(VRX_POSE_MESSAGE, "not_the_world")
        )

    def test_an_empty_world_frame_selects_nothing(self):
        self.assertIsNone(MODULE.select_world_transform(VRX_POSE_MESSAGE, ""))

    def test_a_message_without_the_world_parent_selects_nothing(self):
        sensors_only = [
            item
            for item in VRX_POSE_MESSAGE
            if item.header.frame_id != "sydney_regatta"
        ]
        self.assertIsNone(
            MODULE.select_world_transform(sensors_only, "sydney_regatta")
        )

    def test_observed_parent_frames_are_sorted_and_deduplicated(self):
        self.assertEqual(
            MODULE.observed_parent_frames(VRX_POSE_MESSAGE),
            ["sydney_regatta", "wamv/wamv/base_link"],
        )

    def test_observed_parent_frames_is_empty_for_an_empty_message(self):
        self.assertEqual(MODULE.observed_parent_frames([]), [])


REQUIRED = {"servo_output_raw", "left_thrust", "right_thrust", "pose"}
SECOND = 1_000_000_000


class ObserverReadinessTests(unittest.TestCase):
    def test_readiness_needs_every_required_stream(self):
        partial = {kind: 10 * SECOND for kind in REQUIRED - {"pose"}}
        self.assertFalse(
            MODULE.required_streams_are_live(REQUIRED, partial, 10 * SECOND, 5)
        )

    def test_record_only_mode_keeps_membership_semantics(self):
        # stale_seconds == 0 is the record-only default; an old pose still
        # counts, because that mode carries no acceptance semantics.
        last_seen = dict.fromkeys(REQUIRED, 1 * SECOND)
        last_seen["pose"] = 1
        self.assertTrue(
            MODULE.required_streams_are_live(
                REQUIRED, last_seen, 900 * SECOND, 0
            )
        )

    def test_fail_closed_mode_rejects_a_stale_pre_pi_pose(self):
        # The pose baseline is recorded before the Pi starts, so without a
        # recency check it could satisfy the arming gate minutes later.
        last_seen = dict.fromkeys(REQUIRED, 900 * SECOND)
        last_seen["pose"] = 5 * SECOND
        self.assertFalse(
            MODULE.required_streams_are_live(
                REQUIRED, last_seen, 900 * SECOND, 5
            )
        )

    def test_fail_closed_mode_accepts_four_concurrently_live_streams(self):
        last_seen = dict.fromkeys(REQUIRED, 898 * SECOND)
        self.assertTrue(
            MODULE.required_streams_are_live(
                REQUIRED, last_seen, 900 * SECOND, 5
            )
        )

    def test_a_stream_exactly_at_the_limit_is_still_live(self):
        last_seen = dict.fromkeys(REQUIRED, 895 * SECOND)
        self.assertTrue(
            MODULE.required_streams_are_live(
                REQUIRED, last_seen, 900 * SECOND, 5
            )
        )


class PoseRecordingRateTests(unittest.TestCase):
    def test_the_first_pose_sample_is_always_recorded(self):
        self.assertTrue(MODULE.pose_event_is_due(None, 0))

    def test_samples_inside_the_gap_are_not_recorded(self):
        self.assertFalse(
            MODULE.pose_event_is_due(0, MODULE.POSE_EVENT_MIN_GAP_NS - 1)
        )

    def test_samples_at_or_beyond_the_gap_are_recorded(self):
        self.assertTrue(
            MODULE.pose_event_is_due(0, MODULE.POSE_EVENT_MIN_GAP_NS)
        )

    def test_the_gap_is_fine_enough_for_motion_correlation(self):
        # The adjudicator's motion window is measured in seconds, so the
        # retained rate must stay well below it.
        self.assertLessEqual(MODULE.POSE_EVENT_MIN_GAP_NS, SECOND // 10)


if __name__ == "__main__":
    unittest.main()
