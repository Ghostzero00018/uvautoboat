#!/usr/bin/env python3
"""Convert dashboard cached waypoints into a QGroundControl .plan file."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


EARTH_RADIUS_M = 6371000.0
MAV_AUTOPILOT_ARDUPILOTMEGA = 3
MAV_TYPE_SURFACE_BOAT = 11
MAV_FRAME_GLOBAL_RELATIVE_ALT = 3
MAV_CMD_NAV_WAYPOINT = 16
QGC_ALTITUDE_MODE_RELATIVE = 1


def _finite_float(value: Any, name: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be a finite number") from exc
    if not math.isfinite(number):
        raise ValueError(f"{name} must be a finite number")
    return number


def local_to_gps(x: float, y: float, ref_lat: float, ref_lon: float) -> tuple[float, float]:
    """Port of web_dashboard/autoboat/app.js localToGPS."""
    ref_lat_rad = ref_lat * math.pi / 180.0
    d_lat = y / EARTH_RADIUS_M
    d_lon = x / (EARTH_RADIUS_M * math.cos(ref_lat_rad))

    lat = ref_lat + d_lat * 180.0 / math.pi
    lon = ref_lon + d_lon * 180.0 / math.pi
    return lat, lon


def _unwrap_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("input JSON must be an object")

    if "waypoints" not in payload and isinstance(payload.get("data"), str):
        try:
            decoded = json.loads(payload["data"])
        except json.JSONDecodeError as exc:
            raise ValueError("data field is not valid JSON") from exc
        if not isinstance(decoded, dict):
            raise ValueError("decoded data field must be a JSON object")
        return decoded

    return payload


def _origin(
    payload: dict[str, Any],
    start_lat: float | None,
    start_lon: float | None,
) -> tuple[float, float]:
    if (start_lat is None) != (start_lon is None):
        raise ValueError("--start-lat and --start-lon must be provided together")

    if start_lat is not None and start_lon is not None:
        origin = (
            _finite_float(start_lat, "--start-lat"),
            _finite_float(start_lon, "--start-lon"),
        )
        _validate_origin(*origin)
        return origin

    if payload.get("startLat") is None or payload.get("startLon") is None:
        raise ValueError("missing startLat/startLon; provide --start-lat and --start-lon")

    origin = (
        _finite_float(payload["startLat"], "startLat"),
        _finite_float(payload["startLon"], "startLon"),
    )
    _validate_origin(*origin)
    return origin


def _validate_origin(start_lat: float, start_lon: float) -> None:
    if start_lat == 0.0 and start_lon == 0.0:
        raise ValueError("startLat/startLon cannot both be 0; provide a real GPS origin")


def _waypoint_xy(raw_waypoint: Any, index: int) -> tuple[float, float]:
    label = f"waypoints[{index}]"
    if isinstance(raw_waypoint, dict):
        if "x" not in raw_waypoint or "y" not in raw_waypoint:
            raise ValueError(f"{label} dict must contain x and y")
        return (
            _finite_float(raw_waypoint["x"], f"{label}.x"),
            _finite_float(raw_waypoint["y"], f"{label}.y"),
        )

    if isinstance(raw_waypoint, (list, tuple)) and len(raw_waypoint) >= 2:
        return (
            _finite_float(raw_waypoint[0], f"{label}[0]"),
            _finite_float(raw_waypoint[1], f"{label}[1]"),
        )

    raise ValueError(f"{label} must be [x, y] or {{x, y}}")


def _waypoints(payload: dict[str, Any]) -> list[tuple[float, float]]:
    raw_waypoints = payload.get("waypoints")
    if not isinstance(raw_waypoints, list) or not raw_waypoints:
        raise ValueError("waypoints must be a non-empty list")

    return [_waypoint_xy(raw_waypoint, index) for index, raw_waypoint in enumerate(raw_waypoints)]


def _mission_item(seq: int, lat: float, lon: float, altitude: float) -> dict[str, Any]:
    return {
        "AMSLAltAboveTerrain": None,
        "Altitude": altitude,
        "AltitudeMode": QGC_ALTITUDE_MODE_RELATIVE,
        "autoContinue": True,
        "command": MAV_CMD_NAV_WAYPOINT,
        "doJumpId": seq,
        "frame": MAV_FRAME_GLOBAL_RELATIVE_ALT,
        "params": [0.0, 0.0, 0.0, None, lat, lon, altitude],
        "type": "SimpleItem",
    }


def build_plan(
    payload: dict[str, Any],
    *,
    start_lat: float | None = None,
    start_lon: float | None = None,
    altitude: float = 0.0,
) -> dict[str, Any]:
    payload = _unwrap_payload(payload)
    ref_lat, ref_lon = _origin(payload, start_lat, start_lon)
    altitude = _finite_float(altitude, "altitude")

    items = []
    for seq, (x, y) in enumerate(_waypoints(payload), start=1):
        lat, lon = local_to_gps(x, y, ref_lat, ref_lon)
        items.append(_mission_item(seq, lat, lon, altitude))

    return {
        "fileType": "Plan",
        "geoFence": {
            "circles": [],
            "polygons": [],
            "version": 2,
        },
        "groundStation": "QGroundControl",
        "mission": {
            "cruiseSpeed": 15.0,
            "firmwareType": MAV_AUTOPILOT_ARDUPILOTMEGA,
            "globalPlanAltitudeMode": QGC_ALTITUDE_MODE_RELATIVE,
            "hoverSpeed": 5.0,
            "items": items,
            "plannedHomePosition": [ref_lat, ref_lon, altitude],
            "vehicleType": MAV_TYPE_SURFACE_BOAT,
            "version": 2,
        },
        "rallyPoints": {
            "points": [],
            "version": 2,
        },
        "version": 1,
    }


def load_payload(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        payload = json.load(stream)
    if not isinstance(payload, dict):
        raise ValueError("input JSON must be an object")
    return payload


def write_plan(plan: dict[str, Any], path: Path) -> None:
    with path.open("w", encoding="utf-8") as stream:
        json.dump(plan, stream, indent=2)
        stream.write("\n")


def _default_output_path(input_path: Path) -> Path:
    return input_path.with_suffix(".plan")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert AutoBoat dashboard cached waypoints into a QGroundControl .plan file."
    )
    parser.add_argument(
        "input_json",
        type=Path,
        help="JSON file from autoboat_cached_waypoints or /planning/waypoints",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output .plan path; defaults to input basename with .plan",
    )
    parser.add_argument(
        "--start-lat",
        type=float,
        help="Override origin latitude for raw /planning/waypoints JSON",
    )
    parser.add_argument(
        "--start-lon",
        type=float,
        help="Override origin longitude for raw /planning/waypoints JSON",
    )
    parser.add_argument(
        "--altitude",
        type=float,
        default=0.0,
        help="Waypoint and home altitude in metres",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_path = args.output or _default_output_path(args.input_json)
    try:
        payload = load_payload(args.input_json)
        plan = build_plan(
            payload,
            start_lat=args.start_lat,
            start_lon=args.start_lon,
            altitude=args.altitude,
        )
        write_plan(plan, output_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        raise SystemExit(f"error: {exc}") from exc

    print(f"Wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
