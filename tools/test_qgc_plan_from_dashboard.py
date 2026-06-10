#!/usr/bin/env python3
"""Tests for dashboard waypoint cache to QGC plan conversion."""

import importlib.util
import math
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).with_name("qgc_plan_from_dashboard.py")
SPEC = importlib.util.spec_from_file_location("qgc_plan_from_dashboard", MODULE_PATH)
converter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(converter)


class QgcPlanFromDashboardTest(unittest.TestCase):
    def test_builds_qgc_plan_from_cached_payload(self):
        payload = {
            "waypoints": [
                [0.0, 0.0],
                [10.0, 0.0],
                {"x": 10.0, "y": 20.0},
            ],
            "totalWaypoints": 3,
            "startLat": 50.0,
            "startLon": 3.0,
        }

        plan = converter.build_plan(payload)
        mission = plan["mission"]
        items = mission["items"]

        self.assertEqual(plan["groundStation"], "QGroundControl")
        self.assertEqual(plan["fileType"], "Plan")
        self.assertEqual(plan["version"], 1)
        self.assertEqual(plan["geoFence"], {"circles": [], "polygons": [], "version": 2})
        self.assertEqual(plan["rallyPoints"], {"points": [], "version": 2})
        self.assertEqual(mission["firmwareType"], 3)
        self.assertEqual(mission["vehicleType"], 11)
        self.assertEqual(mission["plannedHomePosition"], [50.0, 3.0, 0.0])
        self.assertEqual(len(items), 3)

        first = items[0]
        self.assertEqual(first["type"], "SimpleItem")
        self.assertEqual(first["command"], 16)
        self.assertEqual(first["frame"], 3)
        self.assertEqual(first["doJumpId"], 1)
        self.assertEqual(first["params"], [0.0, 0.0, 0.0, None, 50.0, 3.0, 0.0])

        expected_lon = (
            3.0
            + (10.0 / (6371000.0 * math.cos(math.radians(50.0))))
            * 180.0
            / math.pi
        )
        expected_lat = 50.0 + (20.0 / 6371000.0) * 180.0 / math.pi
        self.assertAlmostEqual(items[1]["params"][4], 50.0, places=12)
        self.assertAlmostEqual(items[1]["params"][5], expected_lon, places=12)
        self.assertAlmostEqual(items[2]["params"][4], expected_lat, places=12)
        self.assertAlmostEqual(items[2]["params"][5], expected_lon, places=12)

    def test_missing_origin_fails_loudly(self):
        payload = {
            "waypoints": [[0.0, 0.0]],
            "startLat": None,
            "startLon": 3.0,
        }

        with self.assertRaisesRegex(ValueError, "startLat/startLon"):
            converter.build_plan(payload)

    def test_zero_zero_origin_fails_loudly(self):
        payload = {
            "waypoints": [[0.0, 0.0]],
            "startLat": 0.0,
            "startLon": 0.0,
        }

        with self.assertRaisesRegex(ValueError, "cannot both be 0"):
            converter.build_plan(payload)

    def test_origin_override_supports_raw_waypoint_payload(self):
        payload = {
            "waypoints": [[0.0, 5.0]],
            "total": 1,
        }

        plan = converter.build_plan(payload, start_lat=1.0, start_lon=2.0)
        item = plan["mission"]["items"][0]
        expected_lat = 1.0 + (5.0 / 6371000.0) * 180.0 / math.pi

        self.assertEqual(plan["mission"]["plannedHomePosition"], [1.0, 2.0, 0.0])
        self.assertAlmostEqual(item["params"][4], expected_lat, places=12)
        self.assertAlmostEqual(item["params"][5], 2.0, places=12)

    def test_ros_string_wrapper_payload_is_unwrapped(self):
        payload = {
            "data": (
                '{"waypoints":[[0.0,0.0]],'
                '"startLat":50.0,'
                '"startLon":3.0}'
            )
        }

        plan = converter.build_plan(payload)

        self.assertEqual(plan["mission"]["plannedHomePosition"], [50.0, 3.0, 0.0])
        self.assertEqual(len(plan["mission"]["items"]), 1)


if __name__ == "__main__":
    unittest.main()
