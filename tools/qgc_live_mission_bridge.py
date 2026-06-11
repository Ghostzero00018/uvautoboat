#!/usr/bin/env python3
"""Serve confirmed AutoBoat waypoints to local QGroundControl over MAVLink."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import sys
import time
from typing import Any, Callable


TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from qgc_plan_from_dashboard import (  # noqa: E402
    _finite_float,
    _validate_origin,
    _waypoints,
    local_to_gps,
)

try:
    import rclpy
    from rclpy.executors import ExternalShutdownException
    from rclpy.node import Node
    from std_msgs.msg import String
except ImportError:
    rclpy = None
    ExternalShutdownException = Exception
    Node = object
    String = None


MAV_AUTOPILOT_ARDUPILOTMEGA = 3
MAV_CMD_NAV_WAYPOINT = 16
MAV_COMP_ID_AUTOPILOT1 = 1
MAV_FRAME_GLOBAL_RELATIVE_ALT_INT = 6
MAVLINK_VERSION = 3
MAV_MISSION_ACCEPTED = 0
MAV_MISSION_ERROR = 1
MAV_MISSION_UNSUPPORTED = 3
MAV_MISSION_TYPE_MISSION = 0
MAV_MISSION_TYPE_FENCE = 1
MAV_MISSION_TYPE_RALLY = 2
MAV_MODE_FLAG_CUSTOM_MODE_ENABLED = 1
MAV_PARAM_TYPE_REAL32 = 9
MAV_RESULT_UNSUPPORTED = 3
MAV_STATE_STANDBY = 3
MAV_TYPE_SURFACE_BOAT = 11

MISSION_REQUEST_TYPES = {"MISSION_REQUEST", "MISSION_REQUEST_INT"}
SUPPORTED_MISSION_TYPES = {MAV_MISSION_TYPE_MISSION, None}


@dataclass(frozen=True)
class MissionItem:
    """One MAVLink mission item derived from a local planner waypoint."""

    seq: int
    lat: float
    lon: float
    altitude: float
    lat_int: int
    lon_int: int


@dataclass(frozen=True)
class MissionSnapshot:
    """Confirmed mission state exposed to QGC."""

    home_lat: float
    home_lon: float
    altitude: float
    items: tuple[MissionItem, ...]
    source_state: str
    created_monotonic: float

    @property
    def count(self) -> int:
        return len(self.items)


def _json_object(payload: str | dict[str, Any], name: str) -> dict[str, Any]:
    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except json.JSONDecodeError as exc:
            raise ValueError(f"{name} is not valid JSON") from exc

    if not isinstance(payload, dict):
        raise ValueError(f"{name} must be a JSON object")

    if isinstance(payload.get("data"), str):
        try:
            decoded = json.loads(payload["data"])
        except json.JSONDecodeError as exc:
            raise ValueError(f"{name}.data is not valid JSON") from exc
        if not isinstance(decoded, dict):
            raise ValueError(f"{name}.data must decode to a JSON object")
        return decoded

    return payload


def _config_origin(config_payload: dict[str, Any]) -> tuple[float, float]:
    if not config_payload.get("gps_ready", False):
        raise ValueError("gps_ready is false; cannot expose a QGC mission yet")

    start_lat = _finite_float(config_payload.get("start_lat"), "start_lat")
    start_lon = _finite_float(config_payload.get("start_lon"), "start_lon")
    _validate_origin(start_lat, start_lon)
    return start_lat, start_lon


def _state_from(payload: dict[str, Any]) -> str | None:
    state = payload.get("state")
    if isinstance(state, str) and state:
        return state.upper()
    return None


def _mission_item(
    seq: int,
    x: float,
    y: float,
    ref_lat: float,
    ref_lon: float,
    altitude: float,
) -> MissionItem:
    lat, lon = local_to_gps(x, y, ref_lat, ref_lon)
    return MissionItem(
        seq=seq,
        lat=lat,
        lon=lon,
        altitude=altitude,
        lat_int=int(round(lat * 1e7)),
        lon_int=int(round(lon * 1e7)),
    )


def build_mission_snapshot(
    waypoint_payload: str | dict[str, Any],
    config_payload: str | dict[str, Any],
    *,
    altitude: float = 0.0,
    created_monotonic: float | None = None,
) -> MissionSnapshot:
    """Build a confirmed mission snapshot from planner JSON payloads."""
    waypoints_payload = _json_object(waypoint_payload, "waypoint payload")
    config = _json_object(config_payload, "config payload")
    ref_lat, ref_lon = _config_origin(config)
    altitude = _finite_float(altitude, "altitude")
    state = _state_from(config) or "READY"

    items = tuple(
        _mission_item(seq, x, y, ref_lat, ref_lon, altitude)
        for seq, (x, y) in enumerate(_waypoints(waypoints_payload))
    )
    return MissionSnapshot(
        home_lat=ref_lat,
        home_lon=ref_lon,
        altitude=altitude,
        items=items,
        source_state=state,
        created_monotonic=created_monotonic or time.monotonic(),
    )


def mission_signature(
    waypoint_payload: str | dict[str, Any],
    config_payload: str | dict[str, Any],
    *,
    altitude: float = 0.0,
) -> tuple[Any, ...]:
    """Return a stable signature for the QGC mission payload."""
    waypoints_payload = _json_object(waypoint_payload, "waypoint payload")
    config = _json_object(config_payload, "config payload")
    ref_lat, ref_lon = _config_origin(config)
    altitude = _finite_float(altitude, "altitude")
    waypoint_xy = tuple(_waypoints(waypoints_payload))
    return (
        int(round(ref_lat * 1e7)),
        int(round(ref_lon * 1e7)),
        int(round(altitude * 1000.0)),
        waypoint_xy,
    )


def mission_count_for_type(snapshot: MissionSnapshot | None, mission_type: int | None) -> int:
    """Return the mission count QGC should see for the requested mission type."""
    if snapshot is None or mission_type not in SUPPORTED_MISSION_TYPES:
        return 0
    return snapshot.count


class MissionGate:
    """Cache generated waypoints and expose them only after planner READY."""

    def __init__(self, *, altitude: float = 0.0) -> None:
        self.altitude = altitude
        self.active: MissionSnapshot | None = None
        self._config_payload: dict[str, Any] | None = None
        self._waypoint_payload: dict[str, Any] | None = None
        self._state: str | None = None
        self._active_signature: tuple[Any, ...] | None = None

    def update_config(self, payload: str | dict[str, Any]) -> MissionSnapshot | None:
        self._config_payload = _json_object(payload, "config payload")
        state = _state_from(self._config_payload)
        if state:
            self._state = state
        return self._maybe_activate()

    def update_waypoints(self, payload: str | dict[str, Any]) -> MissionSnapshot | None:
        self._waypoint_payload = _json_object(payload, "waypoint payload")
        return self._maybe_activate()

    def update_status(self, payload: str | dict[str, Any]) -> MissionSnapshot | None:
        status = _json_object(payload, "mission status payload")
        state = _state_from(status)
        if state:
            self._state = state
        return self._maybe_activate()

    def _maybe_activate(self) -> MissionSnapshot | None:
        if self._state != "READY":
            return None
        if self._waypoint_payload is None or self._config_payload is None:
            return None

        config_payload = dict(self._config_payload)
        config_payload["state"] = self._state
        signature = mission_signature(
            self._waypoint_payload,
            config_payload,
            altitude=self.altitude,
        )
        if signature == self._active_signature:
            return None

        snapshot = build_mission_snapshot(
            self._waypoint_payload,
            config_payload,
            altitude=self.altitude,
        )
        self.active = snapshot
        self._active_signature = signature
        return snapshot


def _mav_message_type(message: Any) -> str:
    getter = getattr(message, "get_type", None)
    if callable(getter):
        return getter()
    return type(message).__name__


def _mav_source(message: Any) -> tuple[int, int]:
    system_getter = getattr(message, "get_srcSystem", None)
    component_getter = getattr(message, "get_srcComponent", None)
    system_id = system_getter() if callable(system_getter) else 255
    component_id = component_getter() if callable(component_getter) else 0
    return system_id, component_id


class MavlinkMissionServer:
    """MAVLink mission-protocol surface for the fake local QGC vehicle."""

    def __init__(
        self,
        *,
        mavlink_url: str,
        source_system: int,
        source_component: int,
        gate: MissionGate,
        log: Callable[[str], None],
    ) -> None:
        try:
            from pymavlink import mavutil
        except ImportError as exc:
            raise RuntimeError(
                "pymavlink is required for live QGC bridge runtime; "
                "install it in the selected bridge environment before Block E"
            ) from exc

        self.mavutil = mavutil
        self.connection = mavutil.mavlink_connection(
            mavlink_url,
            source_system=source_system,
            source_component=source_component,
        )
        self.source_system = source_system
        self.source_component = source_component
        self.gate = gate
        self.log = log
        self._last_heartbeat = 0.0
        self._last_position = 0.0
        self._target_system = 255
        self._target_component = 0

    def tick(self) -> None:
        now = time.monotonic()
        if self.gate.active is not None and now - self._last_heartbeat >= 1.0:
            self._send_heartbeat()
            self._last_heartbeat = now
        if self.gate.active is not None and now - self._last_position >= 3.0:
            self._send_home_position(self.gate.active)
            self._last_position = now
        self._drain_messages()

    def _drain_messages(self) -> None:
        while True:
            message = self.connection.recv_match(blocking=False)
            if message is None:
                return
            self.handle_message(message)

    def handle_message(self, message: Any) -> None:
        message_type = _mav_message_type(message)
        self._target_system, self._target_component = _mav_source(message)

        if message_type == "HEARTBEAT":
            return
        if message_type == "MISSION_REQUEST_LIST":
            self._handle_mission_request_list(message)
            return
        if message_type in MISSION_REQUEST_TYPES:
            self._handle_mission_item_request(message)
            return
        if message_type == "PARAM_REQUEST_LIST":
            self._send_all_params()
            return
        if message_type == "PARAM_REQUEST_READ":
            self._send_requested_param(message)
            return
        if message_type == "MISSION_CLEAR_ALL":
            mission_type = getattr(message, "mission_type", MAV_MISSION_TYPE_MISSION)
            self._send_mission_ack(MAV_MISSION_UNSUPPORTED, mission_type)
            self.log("rejected QGC clear request; fake mission remains dashboard-owned")
            return
        if message_type == "COMMAND_LONG":
            self._handle_command_long(message)

    def _handle_mission_request_list(self, message: Any) -> None:
        mission_type = getattr(message, "mission_type", MAV_MISSION_TYPE_MISSION)
        count = mission_count_for_type(self.gate.active, mission_type)
        self._send_mission_count(count, mission_type)
        self.log(f"served MISSION_COUNT={count} for mission_type={mission_type}")

    def _handle_mission_item_request(self, message: Any) -> None:
        mission_type = getattr(message, "mission_type", MAV_MISSION_TYPE_MISSION)
        seq = int(getattr(message, "seq", -1))
        if mission_type not in SUPPORTED_MISSION_TYPES:
            self._send_mission_count(0, mission_type)
            return
        snapshot = self.gate.active
        if snapshot is None or seq < 0 or seq >= snapshot.count:
            self._send_mission_ack(MAV_MISSION_ERROR, mission_type)
            self.log(f"rejected mission item request seq={seq}")
            return
        self._send_mission_item(snapshot.items[seq], mission_type)
        self.log(f"served mission item seq={seq}")

    def _handle_command_long(self, message: Any) -> None:
        command = int(getattr(message, "command", 0))
        self._send_command_ack(command, MAV_RESULT_UNSUPPORTED)

    def _send_heartbeat(self) -> None:
        self.connection.mav.heartbeat_send(
            MAV_TYPE_SURFACE_BOAT,
            MAV_AUTOPILOT_ARDUPILOTMEGA,
            MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
            0,
            MAV_STATE_STANDBY,
            MAVLINK_VERSION,
        )

    def _send_home_position(self, snapshot: MissionSnapshot) -> None:
        lat_int = int(round(snapshot.home_lat * 1e7))
        lon_int = int(round(snapshot.home_lon * 1e7))
        alt_mm = int(round(snapshot.altitude * 1000.0))
        self.connection.mav.home_position_send(
            lat_int,
            lon_int,
            alt_mm,
            0.0,
            0.0,
            0.0,
            [1.0, 0.0, 0.0, 0.0],
            0.0,
            0.0,
            0.0,
        )
        self.connection.mav.global_position_int_send(
            int(time.monotonic() * 1000.0) & 0xFFFFFFFF,
            lat_int,
            lon_int,
            alt_mm,
            alt_mm,
            0,
            0,
            0,
            65535,
        )

    def _send_mission_count(self, count: int, mission_type: int | None) -> None:
        try:
            self.connection.mav.mission_count_send(
                self._target_system,
                self._target_component,
                count,
                mission_type or MAV_MISSION_TYPE_MISSION,
            )
        except TypeError:
            self.connection.mav.mission_count_send(
                self._target_system,
                self._target_component,
                count,
            )

    def _send_mission_item(self, item: MissionItem, mission_type: int | None) -> None:
        try:
            self.connection.mav.mission_item_int_send(
                self._target_system,
                self._target_component,
                item.seq,
                MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
                MAV_CMD_NAV_WAYPOINT,
                1 if item.seq == 0 else 0,
                1,
                0.0,
                0.0,
                0.0,
                0.0,
                item.lat_int,
                item.lon_int,
                item.altitude,
                mission_type or MAV_MISSION_TYPE_MISSION,
            )
        except TypeError:
            self.connection.mav.mission_item_int_send(
                self._target_system,
                self._target_component,
                item.seq,
                MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
                MAV_CMD_NAV_WAYPOINT,
                1 if item.seq == 0 else 0,
                1,
                0.0,
                0.0,
                0.0,
                0.0,
                item.lat_int,
                item.lon_int,
                item.altitude,
            )

    def _send_mission_ack(self, result: int, mission_type: int | None) -> None:
        try:
            self.connection.mav.mission_ack_send(
                self._target_system,
                self._target_component,
                result,
                mission_type or MAV_MISSION_TYPE_MISSION,
            )
        except TypeError:
            self.connection.mav.mission_ack_send(
                self._target_system,
                self._target_component,
                result,
            )

    def _send_command_ack(self, command: int, result: int) -> None:
        try:
            self.connection.mav.command_ack_send(
                command,
                result,
                0,
                0,
                self._target_system,
                self._target_component,
            )
        except TypeError:
            self.connection.mav.command_ack_send(command, result)

    def _params(self) -> list[tuple[str, float]]:
        count = float(self.gate.active.count if self.gate.active else 0)
        return [
            ("SYSID_THISMAV", float(self.source_system)),
            ("AUTOBT_COUNT", count),
            ("AUTOBT_ALT", float(self.gate.altitude)),
        ]

    def _send_all_params(self) -> None:
        params = self._params()
        for index, (name, value) in enumerate(params):
            self._send_param(name, value, len(params), index)
        self.log(f"served {len(params)} minimal params")

    def _send_requested_param(self, message: Any) -> None:
        param_index = int(getattr(message, "param_index", -1))
        raw_id = getattr(message, "param_id", b"")
        if isinstance(raw_id, bytes):
            requested_name = raw_id.decode("ascii", "ignore").rstrip("\x00")
        else:
            requested_name = str(raw_id).rstrip("\x00")
        params = self._params()

        if 0 <= param_index < len(params):
            name, value = params[param_index]
            self._send_param(name, value, len(params), param_index)
            return

        for index, (name, value) in enumerate(params):
            if name == requested_name:
                self._send_param(name, value, len(params), index)
                return

    def _send_param(self, name: str, value: float, count: int, index: int) -> None:
        self.connection.mav.param_value_send(
            name.encode("ascii"),
            float(value),
            MAV_PARAM_TYPE_REAL32,
            count,
            index,
        )


class QgcLiveMissionBridgeNode(Node):
    """ROS 2 subscriptions feeding the local MAVLink mission server."""

    def __init__(self, args: argparse.Namespace) -> None:
        super().__init__("qgc_live_mission_bridge")
        self.gate = MissionGate(altitude=args.altitude)
        self.server = MavlinkMissionServer(
            mavlink_url=args.mavlink_url,
            source_system=args.system_id,
            source_component=args.component_id,
            gate=self.gate,
            log=lambda message: self.get_logger().info(message),
        )
        self.create_subscription(String, args.waypoints_topic, self._waypoints_cb, 10)
        self.create_subscription(String, args.config_topic, self._config_cb, 10)
        self.create_subscription(String, args.status_topic, self._status_cb, 10)
        self.create_timer(args.poll_period, self.server.tick)
        self.get_logger().info(
            "waiting for confirmed READY mission before sending QGC heartbeat"
        )

    def _waypoints_cb(self, message: Any) -> None:
        self._update_gate("waypoints", lambda: self.gate.update_waypoints(message.data))

    def _config_cb(self, message: Any) -> None:
        self._update_gate("config", lambda: self.gate.update_config(message.data))

    def _status_cb(self, message: Any) -> None:
        self._update_gate("mission status", lambda: self.gate.update_status(message.data))

    def _update_gate(
        self,
        label: str,
        update: Callable[[], MissionSnapshot | None],
    ) -> None:
        try:
            snapshot = update()
        except ValueError as exc:
            self.get_logger().debug(f"ignored {label}: {exc}")
            return
        if snapshot is not None:
            self.get_logger().info(
                f"active QGC visual mission: {snapshot.count} items, "
                f"origin=({snapshot.home_lat:.8f}, {snapshot.home_lon:.8f})"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Serve confirmed /planning waypoints as a local QGC MAVLink mission."
        )
    )
    parser.add_argument(
        "--mavlink-url",
        default="udpout:127.0.0.1:14550",
        help="Local QGC MAVLink URL; keep Block E on 127.0.0.1:14550",
    )
    parser.add_argument("--system-id", type=int, default=42)
    parser.add_argument("--component-id", type=int, default=MAV_COMP_ID_AUTOPILOT1)
    parser.add_argument("--altitude", type=float, default=0.0)
    parser.add_argument("--waypoints-topic", default="/planning/waypoints")
    parser.add_argument("--config-topic", default="/planning/config")
    parser.add_argument("--status-topic", default="/planning/mission_status")
    parser.add_argument("--poll-period", type=float, default=0.05)
    return parser.parse_args()


def main() -> int:
    if rclpy is None or String is None:
        raise SystemExit("error: ROS 2 Python modules are required")

    args = parse_args()
    try:
        from pymavlink import mavutil  # noqa: F401
    except ImportError as exc:
        raise SystemExit(
            "error: pymavlink is required for live QGC bridge runtime; "
            "install it in the selected bridge environment before Block E"
        ) from exc

    rclpy.init()
    node = None
    try:
        node = QgcLiveMissionBridgeNode(args)
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    except RuntimeError as exc:
        raise SystemExit(f"error: {exc}") from exc
    finally:
        if node is not None:
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
