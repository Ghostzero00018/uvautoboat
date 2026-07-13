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

from plan.waypoint_planner import WaypointPlanner
from rclpy.time import Time


def _t(seconds):
    return Time(nanoseconds=int(seconds * 1e9))


class _Logger:

    def __init__(self):
        self.warnings = []

    def warn(self, message):
        self.warnings.append(message)

    def info(self, message):
        pass


class _Clock:

    def __init__(self):
        self.value = _t(0)

    def now(self):
        return self.value


class _MissionStub:
    """Minimal WaypointPlanner stand-in exercising publish_mission_status."""

    def __init__(self, start_gps=None):
        self.mission_start_time = None
        self.start_gps = start_gps
        self.current_gps = start_gps
        self.gps_init_time = None
        self.gps_timeout = 30.0
        self.gps_timeout_warned = False
        self.state = 'INIT'
        self.current_wp_index = 0
        self.waypoints = []
        self.mission_armed = False
        self.detour_waypoint_inserted = False
        self.go_home_mode = False
        self.blocked_reason = ''
        self.pub_mission_status = object()
        self.clock = _Clock()
        self.logger = _Logger()
        self.published = []

    def get_clock(self):
        return self.clock

    def get_logger(self):
        return self.logger

    def _publish_json(self, publisher, payload, label):
        self.published.append(payload)


def _last_ready(stub):
    return stub.published[-1]['gps_ready']


def test_timeout_never_forces_ready():
    stub = _MissionStub(start_gps=None)
    WaypointPlanner.publish_mission_status(stub, 0.0, 0.0)
    assert _last_ready(stub) is False
    stub.clock.value = _t(31)
    WaypointPlanner.publish_mission_status(stub, 0.0, 0.0)
    assert _last_ready(stub) is False
    assert len(stub.logger.warnings) == 1


def test_late_gps_warning_is_one_time():
    stub = _MissionStub(start_gps=None)
    WaypointPlanner.publish_mission_status(stub, 0.0, 0.0)
    for seconds in (31, 45, 90):
        stub.clock.value = _t(seconds)
        WaypointPlanner.publish_mission_status(stub, 0.0, 0.0)
    assert len(stub.logger.warnings) == 1
    assert stub.gps_timeout_warned is True


def test_valid_fix_is_ready_without_warning():
    stub = _MissionStub(start_gps=(0.0, 0.0))
    WaypointPlanner.publish_mission_status(stub, 5.0, 6.0)
    assert _last_ready(stub) is True
    stub.clock.value = _t(120)
    WaypointPlanner.publish_mission_status(stub, 5.0, 6.0)
    assert _last_ready(stub) is True
    assert stub.logger.warnings == []
    assert stub.gps_init_time is None
