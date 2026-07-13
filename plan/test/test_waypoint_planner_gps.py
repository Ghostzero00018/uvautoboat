# Copyright 2026 Ghostzero00018
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import math

from plan.waypoint_planner import WaypointPlanner
import pytest
from sensor_msgs.msg import NavSatFix


class _Logger:

    def __init__(self):
        self.info_messages = []

    def info(self, message):
        self.info_messages.append(message)


class _PlannerState:

    def __init__(self):
        self.current_gps = None
        self.start_gps = None
        self.logger = _Logger()

    def get_logger(self):
        return self.logger


def _fix(status, latitude, longitude):
    message = NavSatFix()
    message.status.status = status
    message.latitude = latitude
    message.longitude = longitude
    return message


@pytest.mark.parametrize(
    'message',
    [
        _fix(-2, 0.0, 0.0),
        _fix(-1, 48.1, 2.3),
        _fix(0, math.nan, 2.3),
        _fix(0, 48.1, math.inf),
    ],
)
def test_gps_callback_rejects_unusable_first_fix(message):
    planner = _PlannerState()

    WaypointPlanner.gps_callback(planner, message)

    assert planner.current_gps is None
    assert planner.start_gps is None


def test_gps_callback_accepts_valid_zero_coordinates_after_no_fix():
    planner = _PlannerState()

    WaypointPlanner.gps_callback(planner, _fix(-1, 0.0, 0.0))
    WaypointPlanner.gps_callback(planner, _fix(0, 0.0, 0.0))

    assert planner.current_gps == (0.0, 0.0)
    assert planner.start_gps == (0.0, 0.0)


def test_gps_callback_updates_current_fix_without_moving_origin():
    planner = _PlannerState()

    WaypointPlanner.gps_callback(planner, _fix(0, 0.0, 0.0))
    WaypointPlanner.gps_callback(planner, _fix(1, 48.1, 2.3))

    assert planner.current_gps == (48.1, 2.3)
    assert planner.start_gps == (0.0, 0.0)


def test_gps_callback_holds_last_valid_position_during_no_fix():
    planner = _PlannerState()

    WaypointPlanner.gps_callback(planner, _fix(0, 48.1, 2.3))
    WaypointPlanner.gps_callback(planner, _fix(-1, 0.0, 0.0))

    assert planner.current_gps == (48.1, 2.3)
    assert planner.start_gps == (48.1, 2.3)
