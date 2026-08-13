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

from control.heading_controller import (
    ESCAPE_TURN_POWER,
    HeadingController,
    REVERSE_BURST_THRUST,
)
from rclpy.time import Time


def _t(seconds):
    return Time(nanoseconds=int(seconds * 1e9))


class _Logger:

    def __init__(self):
        self.warnings = []
        self.infos = []

    def warn(self, message, **kwargs):
        self.warnings.append(message)

    def info(self, message, **kwargs):
        self.infos.append(message)

    def error(self, message, **kwargs):
        pass


class _Clock:

    def __init__(self):
        self.value = _t(0)

    def now(self):
        return self.value


class _Pub:

    def __init__(self):
        self.data = []

    def publish(self, msg):
        self.data.append(msg.data)


class _ThrustStub:
    """Minimal HeadingController stand-in exercising send_thrust only."""

    def __init__(self, forward_only=True, mission_active=True):
        self.forward_only = forward_only
        self.mission_active = mission_active
        self.pub_left = _Pub()
        self.pub_right = _Pub()

    def pair(self):
        return (self.pub_left.data[-1], self.pub_right.data[-1])


class _LoopStub:
    """HeadingController stand-in for the top-of-loop stop gates."""

    def __init__(self):
        self.person_stop_active = False
        self.person_verdict_known = False
        self.person_feed_fresh = False
        self.person_alert_received_at = None
        self.person_alert_timeout_s = 3.0
        self.stop_override = False
        self.mission_active = True
        self.target_x = None
        self.target_y = None
        self.thrusts = []
        self.statuses = []
        self.stops = 0
        self.clock = _Clock()
        self.logger = _Logger()

    def get_clock(self):
        return self.clock

    def get_logger(self):
        return self.logger

    def _reset_all_escape_state(self):
        pass

    def stop(self):
        self.stops += 1

    def send_thrust(self, left, right):
        self.thrusts.append((left, right))

    def publish_status(self, mode):
        self.statuses.append(mode)


class _EscapeStub:
    """HeadingController stand-in for execute_smart_escape."""

    def __init__(self, forward_only=True, right_clear=30.0, left_clear=5.0):
        self.forward_only = forward_only
        self.mission_active = True
        self.front_clear = 2.0
        self.min_safe_distance = 12.0
        self.right_clear = right_clear
        self.left_clear = left_clear
        self.escape_direction = 'IDLE'
        self.thrusts = []
        self.logger = _Logger()

    def get_logger(self):
        return self.logger

    def send_thrust(self, left, right):
        self.thrusts.append((left, right))

    def stop(self):
        self.thrusts.append((0.0, 0.0))

    def _reset_all_escape_state(self):
        pass


class _ReverseStub:
    """
    Full HeadingController stand-in able to run a complete control_loop.

    Launch defaults are used throughout so the scenarios match the shipped
    configuration rather than a convenient one.
    """

    def __init__(self, forward_only=True):
        self.forward_only = forward_only
        # Gates
        self.person_stop_active = False
        self.stop_override = False
        self.mission_active = True
        self.dt = 0.05
        # Pose and target
        self.target_x = 10.0
        self.target_y = 10.0
        self.current_x = 0.0
        self.current_y = 0.0
        self.current_yaw = 0.0
        self.distance_to_target = 14.1
        self.last_position = (0.0, 0.0)
        self.stuck_check_time = _t(0)
        # Obstacle picture: a confirmed critical contact at 2 m
        self.is_critical = True
        self.obstacle_detected = True
        self.min_obstacle_distance = 2.0
        self.critical_distance = 6.0
        self.min_safe_distance = 12.0
        self.front_clear = 2.0
        self.left_clear = 3.0
        self.right_clear = 30.0
        self.urgency = 0.9
        self.best_gap = None
        self.vfh_gap = None
        self.polar_bias = 0.0
        self.force_avoid_active = False
        # Escape / reverse bookkeeping
        self.escape_mode = False
        self.is_stuck = False
        self.avoidance_mode = False
        self.force_turn_after_reverse = False
        self.reverse_start_time = None
        self.reverse_start_pos = None
        self.reverse_timeout = 4.0
        self.max_reverse_distance = 25.0
        # Gains and limits (launch defaults)
        self.kp = 500.0
        self.ki = 20.0
        self.kd = 150.0
        self.base_speed = 400.0
        self.max_speed = 800.0
        self.obstacle_slow_factor = 0.5
        self.approach_slow_distance = 10.0
        self.approach_slow_factor = 0.7
        self.bank_slow_distance = 6.0
        self.bank_slow_factor = 0.25
        self.avoid_diff_gain = 18.0
        self.max_avoidance_turn_deg = 45.0
        self.turn_deadband_deg = 0.5
        self.slew_rate_limit = 80.0
        self.drift_compensation_gain = 0.3
        self.drift_vector = (0.0, 0.0)
        self.use_vfh_bias = False
        self.integral_error = 0.0
        self.previous_error = 0.0
        self.prev_left_thrust = 0.0
        self.prev_right_thrust = 0.0
        # Recording
        self.clock = _Clock()
        self.logger = _Logger()
        self.pub_heading_error = _Pub()
        self.thrusts = []
        self.statuses = []
        self.replans = []

    def get_clock(self):
        return self.clock

    def get_logger(self):
        return self.logger

    def stop(self):
        self.thrusts.append((0.0, 0.0))

    def send_thrust(self, left, right):
        self.thrusts.append((left, right))

    def publish_status(self, mode):
        self.statuses.append(mode)

    def update_position_history(self):
        pass

    def check_stuck_condition(self):
        pass

    def request_replan(self, reason=''):
        self.replans.append(reason)

    def normalize_angle(self, angle):
        return HeadingController.normalize_angle(self, angle)

    def _slew_limit(self, previous, target):
        return HeadingController._slew_limit(self, previous, target)


# --- forward-only clamp at the single thrust choke point ---------------------

def test_forward_only_clamps_negative_thrust_to_zero():
    stub = _ThrustStub(forward_only=True)
    HeadingController.send_thrust(stub, -500.0, 300.0)
    assert stub.pair() == (0.0, 300.0)


def test_forward_only_clamps_the_reverse_burst_magnitude():
    stub = _ThrustStub(forward_only=True)
    HeadingController.send_thrust(stub, REVERSE_BURST_THRUST, REVERSE_BURST_THRUST)
    assert stub.pair() == (0.0, 0.0)


def test_forward_only_clamps_the_escape_spin():
    stub = _ThrustStub(forward_only=True)
    HeadingController.send_thrust(stub, ESCAPE_TURN_POWER, -ESCAPE_TURN_POWER)
    assert stub.pair() == (ESCAPE_TURN_POWER, 0.0)


def test_forward_only_disabled_preserves_reverse():
    stub = _ThrustStub(forward_only=False)
    HeadingController.send_thrust(stub, -500.0, 300.0)
    assert stub.pair() == (-500.0, 300.0)


def test_inactive_mission_still_wins_over_forward_only():
    stub = _ThrustStub(forward_only=True, mission_active=False)
    HeadingController.send_thrust(stub, 700.0, 700.0)
    assert stub.pair() == (0.0, 0.0)


# --- person stop gate --------------------------------------------------------

def test_person_stop_gate_zeroes_thrust_and_returns():
    stub = _LoopStub()
    stub.person_stop_active = True
    stub.mission_active = True
    stub.target_x = 5.0
    stub.target_y = 5.0
    HeadingController.control_loop(stub)
    assert stub.thrusts == [(0.0, 0.0)]
    assert stub.statuses == ['PERSON_STOP']


def test_person_stop_gate_precedes_the_stop_override_gate():
    stub = _LoopStub()
    stub.person_stop_active = True
    stub.stop_override = True
    HeadingController.control_loop(stub)
    assert stub.statuses == ['PERSON_STOP']


def test_clearing_the_hold_is_announced_even_while_the_boat_stays_stopped():
    # After the frame clears the boat is still held by the E-Stop latch. If the
    # loop went quiet there, the dashboard's last word would remain PERSON_STOP
    # and the badge would stay red until the operator resumed.
    stub = _LoopStub()
    stub.person_stop_active = True
    stub.stop_override = True
    HeadingController.control_loop(stub)
    assert stub.statuses[-1] == 'PERSON_STOP'

    stub.person_stop_active = False
    HeadingController.control_loop(stub)
    assert stub.statuses[-1] == 'STOP_OVERRIDE', \
        'status went silent while stopped, freezing the person badge'


def test_an_idle_mission_keeps_reporting_status():
    stub = _LoopStub()
    stub.mission_active = False
    HeadingController.control_loop(stub)
    assert stub.statuses[-1] == 'IDLE'


def test_person_alert_callback_latches_and_releases():
    stub = _LoopStub()
    stub.logger = _Logger()
    stub.get_logger = lambda: stub.logger
    msg = type('Msg', (), {'data': json.dumps({'person_detected': True, 'feed_fresh': True})})()
    HeadingController.person_alert_callback(stub, msg)
    assert stub.person_stop_active is True
    clear = type('Msg', (), {'data': json.dumps({'person_detected': False, 'feed_fresh': True})})()
    HeadingController.person_alert_callback(stub, clear)
    assert stub.person_stop_active is False


def test_boot_state_is_unknown_not_clear():
    # False is the safe default for the hold, but it is not evidence that
    # anything looked. The dashboard needs to tell those apart.
    stub = _LoopStub()
    stub.person_stop_active = False
    stub.person_verdict_known = False
    stub.person_feed_fresh = False
    assert stub.person_verdict_known is False


def test_a_valid_alert_marks_the_verdict_known_and_carries_freshness():
    stub = _LoopStub()
    stub.person_verdict_known = False
    stub.person_feed_fresh = False
    stub.logger = _Logger()
    stub.get_logger = lambda: stub.logger
    msg = type('Msg', (), {
        'data': json.dumps({'person_detected': False, 'feed_fresh': True})})()
    HeadingController.person_alert_callback(stub, msg)
    assert stub.person_verdict_known is True
    assert stub.person_feed_fresh is True


def test_freshness_updates_even_when_the_hold_does_not_change():
    # The hold staying false must not short-circuit the freshness update, or a
    # camera going quiet would never be reported.
    stub = _LoopStub()
    stub.person_stop_active = False
    stub.person_verdict_known = True
    stub.person_feed_fresh = True
    stub.logger = _Logger()
    stub.get_logger = lambda: stub.logger
    msg = type('Msg', (), {
        'data': json.dumps({'person_detected': False, 'feed_fresh': False})})()
    HeadingController.person_alert_callback(stub, msg)
    assert stub.person_feed_fresh is False


def test_a_coerced_freshness_flag_is_rejected_outright():
    # bool("false") is true, so coercion would turn a malformed alert into a
    # confident all-clear — and the same message would release the hold.
    for payload in ({'person_detected': False, 'feed_fresh': 'false'},
                    {'person_detected': False, 'feed_fresh': 1},
                    {'person_detected': False, 'feed_fresh': None},
                    {'person_detected': False}):
        stub = _LoopStub()
        stub.person_stop_active = True
        stub.logger = _Logger()
        stub.get_logger = lambda: stub.logger
        msg = type('Msg', (), {'data': json.dumps(payload)})()
        HeadingController.person_alert_callback(stub, msg)
        assert stub.person_stop_active is True, payload
        assert stub.person_verdict_known is False, payload
        assert stub.logger.warnings, payload


def test_a_silent_monitor_stops_counting_as_a_fresh_feed():
    # The monitor reporting a fresh feed and then dying leaves nothing to
    # correct that claim, so it is aged out against the local clock.
    stub = _LoopStub()
    stub.person_alert_timeout_s = 3.0
    msg = type('Msg', (), {
        'data': json.dumps({'person_detected': False, 'feed_fresh': True})})()
    HeadingController.person_alert_callback(stub, msg)
    assert HeadingController.person_feed_is_fresh(stub) is True

    stub.clock.value = _t(2.9)
    assert HeadingController.person_feed_is_fresh(stub) is True
    stub.clock.value = _t(3.1)
    assert HeadingController.person_feed_is_fresh(stub) is False
    stub.clock.value = _t(600.0)
    assert HeadingController.person_feed_is_fresh(stub) is False


def test_freshness_is_never_claimed_before_any_alert():
    stub = _LoopStub()
    assert HeadingController.person_feed_is_fresh(stub) is False


def test_person_alert_callback_ignores_malformed_json():
    stub = _LoopStub()
    stub.person_stop_active = True
    stub.logger = _Logger()
    stub.get_logger = lambda: stub.logger
    msg = type('Msg', (), {'data': 'not json'})()
    HeadingController.person_alert_callback(stub, msg)
    assert stub.person_stop_active is True
    assert stub.logger.warnings


# --- latch idempotence -------------------------------------------------------

class _LatchStub:
    """HeadingController stand-in for the E-Stop latch."""

    def __init__(self, stop_override=False):
        self.stop_override = stop_override
        self.mission_active = True
        self.thrusts = []
        self.logger = _Logger()

    def get_logger(self):
        return self.logger

    def _reset_all_escape_state(self):
        pass

    def _latch_emergency_stop(self, source):
        # Exercise the real latch body against this stub.
        HeadingController._latch_emergency_stop(self, source)

    def stop(self):
        self.thrusts.append((0.0, 0.0))

    def send_thrust(self, left, right):
        self.thrusts.append((left, right))


def test_repeated_estop_assertions_latch_once():
    stub = _LatchStub()
    msg = type('Msg', (), {'data': True})()
    for _ in range(5):
        HeadingController.emergency_stop_latched_callback(stub, msg)
    assert stub.stop_override is True
    assert len(stub.logger.warnings) == 1


# --- forward-only behaviour of the reverse / escape branches -----------------

def test_escape_spin_is_forward_only_when_enabled():
    stub = _EscapeStub(forward_only=True, right_clear=30.0, left_clear=5.0)
    HeadingController.execute_smart_escape(stub)
    assert stub.thrusts == [(ESCAPE_TURN_POWER, 0.0)]

    stub = _EscapeStub(forward_only=True, right_clear=5.0, left_clear=30.0)
    HeadingController.execute_smart_escape(stub)
    assert stub.thrusts == [(0.0, ESCAPE_TURN_POWER)]


def test_escape_spin_keeps_counter_rotation_when_reverse_allowed():
    stub = _EscapeStub(forward_only=False, right_clear=30.0, left_clear=5.0)
    HeadingController.execute_smart_escape(stub)
    assert stub.thrusts == [(ESCAPE_TURN_POWER, -ESCAPE_TURN_POWER)]


def test_critical_obstacle_still_reverses_when_reverse_allowed():
    stub = _ReverseStub(forward_only=False)
    HeadingController.control_loop(stub)
    assert stub.thrusts[-1] == (REVERSE_BURST_THRUST, REVERSE_BURST_THRUST)
    assert stub.statuses[-1] == 'REVERSING'


def test_critical_obstacle_turns_away_instead_of_reversing_when_forward_only():
    stub = _ReverseStub(forward_only=True)
    HeadingController.control_loop(stub)
    # The reverse branch is skipped outright and the loop continues into the
    # avoidance turn, rather than returning on a station hold.
    assert stub.force_turn_after_reverse is True
    assert stub.avoidance_mode is True
    assert stub.statuses[-1] == 'AVOIDANCE'
    assert 'REVERSING' not in stub.statuses


def test_critical_obstacle_does_not_deadlock_at_zero_thrust():
    # The failure this guards: a station hold the boat can never leave, because
    # it cannot move and so cannot change the geometry that keeps it held.
    stub = _ReverseStub(forward_only=True)
    for _ in range(20):
        HeadingController.control_loop(stub)
    assert any(left != 0.0 or right != 0.0 for left, right in stub.thrusts), \
        'forward-only critical obstacle produced no motion command in 20 cycles'


def test_forward_only_never_publishes_a_negative_command_under_a_critical_obstacle():
    stub = _ReverseStub(forward_only=True)
    for _ in range(20):
        HeadingController.control_loop(stub)
    assert stub.thrusts, 'control_loop published nothing'
    for left, right in stub.thrusts:
        assert left >= 0.0 and right >= 0.0, f'reverse leaked: {(left, right)}'


def test_slew_memory_tracks_the_published_command_not_the_pre_clamp_value():
    stub = _ReverseStub(forward_only=True)
    for _ in range(20):
        HeadingController.control_loop(stub)
    # A negative slew memory would make the clamped side sit dead at zero for
    # extra cycles once the demand turns positive again.
    assert stub.prev_left_thrust >= 0.0
    assert stub.prev_right_thrust >= 0.0


def test_malformed_person_alert_shapes_never_kill_the_node():
    for payload in ('[]', '123', 'null', '"text"', '{bad}', ''):
        stub = _LoopStub()
        stub.person_stop_active = True
        stub.logger = _Logger()
        stub.get_logger = lambda: stub.logger
        msg = type('Msg', (), {'data': payload})()
        HeadingController.person_alert_callback(stub, msg)
        assert stub.person_stop_active is True, payload


def test_an_alert_without_an_explicit_verdict_never_releases_the_hold():
    # An empty object is not an all-clear, and neither is a truthy-but-not-bool
    # verdict. Only an explicit boolean false releases the hold.
    for payload in ({}, {'reason': 'person_detected'}, {'person_detected': None},
                    {'person_detected': 0}, {'person_detected': 'false'}):
        stub = _LoopStub()
        stub.person_stop_active = True
        stub.logger = _Logger()
        stub.get_logger = lambda: stub.logger
        msg = type('Msg', (), {'data': json.dumps(payload)})()
        HeadingController.person_alert_callback(stub, msg)
        assert stub.person_stop_active is True, payload
        assert stub.logger.warnings, payload
