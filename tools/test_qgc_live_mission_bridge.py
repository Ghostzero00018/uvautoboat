#!/usr/bin/env python3
"""Tests for the live QGC mission bridge helper logic."""

import importlib.util
import json
import math
from pathlib import Path
import sys
import unittest


MODULE_PATH = Path(__file__).with_name("qgc_live_mission_bridge.py")
SPEC = importlib.util.spec_from_file_location("qgc_live_mission_bridge", MODULE_PATH)
bridge = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = bridge
SPEC.loader.exec_module(bridge)


class QgcLiveMissionBridgeTest(unittest.TestCase):
    def _snapshot(self):
        return bridge.build_mission_snapshot(
            {"waypoints": [[0.0, 0.0]], "total": 1},
            {
                "gps_ready": True,
                "start_lat": 50.0,
                "start_lon": 3.0,
                "state": "READY",
            },
        )

    def test_builds_mission_snapshot_from_ready_payload(self):
        waypoint_payload = {
            "waypoints": [
                [0.0, 0.0],
                {"x": 10.0, "y": 20.0},
            ],
            "total": 2,
        }
        config_payload = {
            "gps_ready": True,
            "start_lat": 50.0,
            "start_lon": 3.0,
            "state": "READY",
        }

        snapshot = bridge.build_mission_snapshot(waypoint_payload, config_payload)

        self.assertEqual(snapshot.count, 2)
        self.assertEqual(snapshot.home_lat, 50.0)
        self.assertEqual(snapshot.home_lon, 3.0)
        self.assertEqual(snapshot.items[0].seq, 0)
        self.assertEqual(snapshot.items[0].lat_int, int(round(50.0 * 1e7)))
        self.assertEqual(snapshot.items[0].lon_int, int(round(3.0 * 1e7)))

        expected_lat = 50.0 + (20.0 / 6371000.0) * 180.0 / math.pi
        expected_lon = (
            3.0
            + (10.0 / (6371000.0 * math.cos(math.radians(50.0))))
            * 180.0
            / math.pi
        )
        self.assertAlmostEqual(snapshot.items[1].lat, expected_lat, places=12)
        self.assertAlmostEqual(snapshot.items[1].lon, expected_lon, places=12)
        self.assertEqual(snapshot.items[1].lat_int, int(round(expected_lat * 1e7)))
        self.assertEqual(snapshot.items[1].lon_int, int(round(expected_lon * 1e7)))

    def test_missing_gps_origin_fails_loudly(self):
        waypoint_payload = {"waypoints": [[0.0, 0.0]]}
        config_payload = {
            "gps_ready": False,
            "start_lat": None,
            "start_lon": None,
            "state": "READY",
        }

        with self.assertRaisesRegex(ValueError, "gps_ready"):
            bridge.build_mission_snapshot(waypoint_payload, config_payload)

    def test_gate_waits_for_ready_state(self):
        gate = bridge.MissionGate()
        config_payload = {
            "gps_ready": True,
            "start_lat": 50.0,
            "start_lon": 3.0,
            "state": "WAITING_CONFIRM",
        }
        waypoints_payload = {"waypoints": [[0.0, 0.0]], "total": 1}

        self.assertIsNone(gate.update_config(json.dumps(config_payload)))
        self.assertIsNone(gate.update_waypoints(json.dumps(waypoints_payload)))
        self.assertIsNone(gate.active)

        snapshot = gate.update_status(json.dumps({"state": "READY"}))

        self.assertIs(snapshot, gate.active)
        self.assertEqual(snapshot.count, 1)

    def test_repeated_ready_status_does_not_rebuild_same_snapshot(self):
        gate = bridge.MissionGate()
        config_payload = {
            "gps_ready": True,
            "start_lat": 50.0,
            "start_lon": 3.0,
            "state": "WAITING_CONFIRM",
        }
        waypoints_payload = {"waypoints": [[0.0, 0.0]], "total": 1}

        self.assertIsNone(gate.update_config(json.dumps(config_payload)))
        self.assertIsNone(gate.update_waypoints(json.dumps(waypoints_payload)))
        first_snapshot = gate.update_status(json.dumps({"state": "READY"}))
        self.assertIs(first_snapshot, gate.active)

        self.assertIsNone(gate.update_status(json.dumps({"state": "READY"})))
        self.assertIs(gate.active, first_snapshot)

    def test_unsupported_mission_types_are_empty(self):
        snapshot = self._snapshot()

        self.assertEqual(
            bridge.mission_count_for_type(snapshot, bridge.MAV_MISSION_TYPE_MISSION),
            1,
        )
        self.assertEqual(
            bridge.mission_count_for_type(snapshot, bridge.MAV_MISSION_TYPE_FENCE),
            0,
        )
        self.assertEqual(
            bridge.mission_count_for_type(snapshot, bridge.MAV_MISSION_TYPE_RALLY),
            0,
        )

    def test_mission_request_list_and_item_use_fake_connection(self):
        server = FakeServer(self._snapshot())

        server.handle_message(FakeMessage("MISSION_REQUEST_LIST", mission_type=0))
        server.handle_message(FakeMessage("MISSION_REQUEST_INT", seq=0, mission_type=0))

        self.assertEqual(server.connection.mav.calls[0][0], "mission_count_send")
        self.assertEqual(server.connection.mav.calls[0][1][2], 1)
        self.assertEqual(server.connection.mav.calls[1][0], "mission_item_int_send")
        self.assertEqual(server.connection.mav.calls[1][1][2], 0)

    def test_clear_all_is_rejected_and_fake_mission_retained(self):
        snapshot = self._snapshot()
        server = FakeServer(snapshot)

        server.handle_message(FakeMessage("MISSION_CLEAR_ALL", mission_type=0))

        self.assertIs(server.gate.active, snapshot)
        self.assertEqual(server.connection.mav.calls[0][0], "mission_ack_send")
        self.assertEqual(
            server.connection.mav.calls[0][1][2],
            bridge.MAV_MISSION_UNSUPPORTED,
        )

    def test_param_request_list_serves_minimal_params(self):
        server = FakeServer(self._snapshot())

        server.handle_message(FakeMessage("PARAM_REQUEST_LIST"))

        param_calls = [
            call for call in server.connection.mav.calls
            if call[0] == "param_value_send"
        ]
        self.assertEqual(len(param_calls), 3)
        self.assertEqual(param_calls[0][1][0], b"SYSID_THISMAV")

    def test_heartbeat_uses_local_mavlink_version(self):
        server = FakeServer(self._snapshot())

        server._send_heartbeat()

        self.assertEqual(server.connection.mav.calls[0][0], "heartbeat_send")
        self.assertEqual(
            server.connection.mav.calls[0][1],
            (
                bridge.MAV_TYPE_SURFACE_BOAT,
                bridge.MAV_AUTOPILOT_ARDUPILOTMEGA,
                bridge.MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
                0,
                bridge.MAV_STATE_STANDBY,
                bridge.MAVLINK_VERSION,
            ),
        )

    def test_home_position_uses_current_pymavlink_signature(self):
        server = FakeServer(self._snapshot())

        server._send_home_position(server.gate.active)

        home_call = server.connection.mav.calls[0]
        global_call = server.connection.mav.calls[1]
        self.assertEqual(home_call[0], "home_position_send")
        self.assertEqual(len(home_call[1]), 10)
        self.assertEqual(home_call[1][0], int(round(50.0 * 1e7)))
        self.assertEqual(home_call[1][1], int(round(3.0 * 1e7)))
        self.assertEqual(global_call[0], "global_position_int_send")


class FakeMessage:
    def __init__(self, message_type, **fields):
        self._message_type = message_type
        for name, value in fields.items():
            setattr(self, name, value)

    def get_type(self):
        return self._message_type

    def get_srcSystem(self):
        return 255

    def get_srcComponent(self):
        return 190


class FakeMav:
    def __init__(self):
        self.calls = []

    def heartbeat_send(self, *args):
        self.calls.append(("heartbeat_send", args))

    def home_position_send(self, *args):
        self.calls.append(("home_position_send", args))

    def global_position_int_send(self, *args):
        self.calls.append(("global_position_int_send", args))

    def mission_count_send(self, *args):
        self.calls.append(("mission_count_send", args))

    def mission_item_int_send(self, *args):
        self.calls.append(("mission_item_int_send", args))

    def mission_ack_send(self, *args):
        self.calls.append(("mission_ack_send", args))

    def param_value_send(self, *args):
        self.calls.append(("param_value_send", args))


class FakeConnection:
    def __init__(self):
        self.mav = FakeMav()

    def recv_match(self, blocking=False):
        return None


class FakeServer(bridge.MavlinkMissionServer):
    def __init__(self, snapshot):
        self.connection = FakeConnection()
        self.source_system = 42
        self.source_component = bridge.MAV_COMP_ID_AUTOPILOT1
        self.gate = bridge.MissionGate()
        self.gate.active = snapshot
        self.log_messages = []
        self.log = self.log_messages.append
        self._last_heartbeat = 0.0
        self._last_position = 0.0
        self._target_system = 255
        self._target_component = 190


if __name__ == "__main__":
    unittest.main()
