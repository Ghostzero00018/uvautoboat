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

import json

from plan.waypoint_planner import WaypointPlanner
from rclpy.time import Time


class _Logger:

    def __init__(self):
        self.warnings = []
        self.infos = []
        self.errors = []

    def warn(self, message, **kwargs):
        self.warnings.append(message)

    def info(self, message, **kwargs):
        self.infos.append(message)

    def error(self, message, **kwargs):
        # Recorded, not swallowed: mission_command_callback wraps its body in a
        # blanket except, so a stub missing an attribute would otherwise turn a
        # crash into a passing "the command was refused" assertion.
        self.errors.append(message)


class _Clock:

    def now(self):
        return Time(nanoseconds=0)


class _CommandStub:
    """Minimal WaypointPlanner stand-in exercising mission_command_callback."""

    def __init__(self, state='READY', person_stop_active=False):
        self.state = state
        self.person_stop_active = person_stop_active
        self.waypoints = [(0.0, 0.0), (10.0, 10.0)]
        self.current_wp_index = 0
        self.mission_armed = False
        self.mission_start_time = None
        self.go_home_mode = False
        self.detour_waypoint_inserted = False
        self.detour_count = 0
        self.obstacle_blocking_time = 0.0
        self.blocked_reason = ''
        # Home and current position deliberately far apart, so the go_home
        # at-home guard cannot stand in for the person-hold refusal.
        self.start_gps = (0.0, 0.0)
        self.current_gps = (0.001, 0.001)
        self.waypoint_tolerance = 3.0
        self.logger = _Logger()
        self.clock = _Clock()
        self.status_publishes = 0
        self.waypoint_publishes = 0

    def get_logger(self):
        return self.logger

    def get_clock(self):
        return self.clock

    def publish_mission_status_timer(self):
        self.status_publishes += 1

    def publish_waypoints(self):
        self.waypoint_publishes += 1

    def _publish_current_target_immediate(self):
        pass

    def latlon_to_meters(self, lat, lon):
        # Crude local metres; enough for the at-home distance guard.
        return (lon * 111000.0, lat * 111000.0)


def _command(name):
    return type('Msg', (), {'data': json.dumps({'command': name})})()


def _alert(detected, reason='person_detected'):
    payload = {
        'person_detected': detected,
        'feed_fresh': True,
        'reason': reason if detected else '',
    }
    return type('Msg', (), {'data': json.dumps(payload)})()


# --- alert ingest ------------------------------------------------------------

def test_alert_sets_the_blocked_reason():
    stub = _CommandStub()
    WaypointPlanner.person_alert_callback(stub, _alert(True))
    assert stub.person_stop_active is True
    assert stub.blocked_reason == 'person_detected'


def test_clearing_alert_releases_only_its_own_blocked_reason():
    stub = _CommandStub()
    WaypointPlanner.person_alert_callback(stub, _alert(True))
    WaypointPlanner.person_alert_callback(stub, _alert(False))
    assert stub.person_stop_active is False
    assert stub.blocked_reason == ''

    # The hold must actually be active first, or the no-change guard returns
    # before the release branch and the assertion proves nothing.
    other = _CommandStub(person_stop_active=True)
    other.blocked_reason = 'obstacle_persistent'
    WaypointPlanner.person_alert_callback(other, _alert(False))
    assert other.person_stop_active is False
    assert other.blocked_reason == 'obstacle_persistent'


def test_malformed_alert_does_not_release_an_active_hold():
    stub = _CommandStub(person_stop_active=True)
    bad = type('Msg', (), {'data': 'not json'})()
    WaypointPlanner.person_alert_callback(stub, bad)
    assert stub.person_stop_active is True
    assert stub.logger.warnings


def test_an_alert_without_an_explicit_verdict_never_releases_the_hold():
    # An empty object, or a non-boolean verdict, is not an all-clear.
    for payload in ({}, {'reason': 'person_detected'},
                    {'person_detected': None}, {'person_detected': 0},
                    {'person_detected': 'false'}, [], 123,
                    {'person_detected': False},
                    {'person_detected': False, 'feed_fresh': 'false'},
                    {'person_detected': False, 'feed_fresh': 1}):
        stub = _CommandStub(person_stop_active=True)
        msg = type('Msg', (), {'data': json.dumps(payload)})()
        WaypointPlanner.person_alert_callback(stub, msg)
        assert stub.person_stop_active is True, payload
        assert stub.logger.warnings, payload


def test_person_hold_recovers_through_the_operator_resume_path():
    # The full recovery contract: the hold releases when the frame clears, and
    # the operator's resume is then accepted. Neither half alone is enough.
    stub = _CommandStub(state='EMERGENCY_STOP', person_stop_active=True)
    WaypointPlanner.mission_command_callback(stub, _command('resume_mission'))
    assert stub.state == 'EMERGENCY_STOP', 'resume must be refused while held'

    WaypointPlanner.person_alert_callback(stub, _alert(False))
    WaypointPlanner.mission_command_callback(stub, _command('resume_mission'))
    assert stub.state == 'DRIVING'
    assert stub.mission_armed is True
    assert stub.logger.errors == []


# --- restart guards ----------------------------------------------------------

def test_start_mission_is_refused_while_a_person_is_held():
    stub = _CommandStub(state='READY', person_stop_active=True)
    WaypointPlanner.mission_command_callback(stub, _command('start_mission'))
    assert stub.state == 'READY'
    assert stub.mission_armed is False
    assert stub.logger.warnings
    assert stub.logger.errors == []


def test_resume_mission_is_refused_while_a_person_is_held():
    stub = _CommandStub(state='EMERGENCY_STOP', person_stop_active=True)
    WaypointPlanner.mission_command_callback(stub, _command('resume_mission'))
    assert stub.state == 'EMERGENCY_STOP'
    assert stub.mission_armed is False
    assert stub.logger.warnings
    assert stub.logger.errors == []


def test_go_home_is_refused_while_a_person_is_held():
    stub = _CommandStub(state='PAUSED', person_stop_active=True)
    WaypointPlanner.mission_command_callback(stub, _command('go_home'))
    assert stub.state == 'PAUSED'
    assert stub.mission_armed is False
    assert stub.logger.warnings
    # A swallowed AttributeError would otherwise masquerade as a refusal.
    assert stub.logger.errors == []


def test_go_home_reaches_driving_once_the_frame_is_clear():
    # Proves the previous test is measuring the guard, not a stub crash.
    stub = _CommandStub(state='PAUSED', person_stop_active=False)
    WaypointPlanner.mission_command_callback(stub, _command('go_home'))
    assert stub.state == 'DRIVING'
    assert stub.logger.errors == []


def test_start_mission_still_works_once_the_frame_is_clear():
    stub = _CommandStub(state='READY', person_stop_active=True)
    WaypointPlanner.person_alert_callback(stub, _alert(False))
    WaypointPlanner.mission_command_callback(stub, _command('start_mission'))
    assert stub.state == 'DRIVING'
    assert stub.mission_armed is True


def test_repeated_estop_assertions_latch_once():
    stub = _CommandStub(state='DRIVING')
    msg = type('Msg', (), {'data': True})()
    for _ in range(5):
        WaypointPlanner.emergency_stop_latched_callback(stub, msg)
    assert stub.state == 'EMERGENCY_STOP'
    assert stub.status_publishes == 1


def test_stopping_commands_are_never_blocked_by_the_hold():
    stub = _CommandStub(state='DRIVING', person_stop_active=True)
    WaypointPlanner.mission_command_callback(stub, _command('reset_mission'))
    assert stub.state == 'INIT'
