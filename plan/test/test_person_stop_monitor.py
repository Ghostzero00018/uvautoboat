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

from plan.person_stop_monitor import PersonStopMonitor, detection_publisher_binding


class _Logger:

    def __init__(self):
        self.warnings = []

    def warn(self, message, **kwargs):
        self.warnings.append(message)

    def info(self, message, **kwargs):
        pass


class _Pub:

    def __init__(self):
        self.messages = []

    def publish(self, msg):
        self.messages.append(getattr(msg, 'data', msg))


class _MonitorStub:
    """PersonStopMonitor stand-in covering both the policy and its publishers."""

    def __init__(self, **overrides):
        self.person_class = 'person'
        self.score_threshold = 0.5
        self.clear_hold_s = 5.0
        self.detection_timeout_s = 2.0
        self.require_detection_feed = False
        self.latch_emergency_stop = True
        self.person_hold = False
        self.last_person_seen_s = None
        self.last_feed_s = None
        self.last_score = 0.0
        self.last_count = 0
        self._last_published_hold = None
        self.detection_source_bound = True
        self.detection_source_checks = 0
        self.pub_alert = _Pub()
        self.pub_emergency = _Pub()
        self.now_s = 0.0
        self.logger = _Logger()
        for key, value in overrides.items():
            setattr(self, key, value)

    def get_logger(self):
        return self.logger

    def _now_s(self):
        return self.now_s

    def evaluate(self, now_s):
        # Exercise the real policy body against this stub.
        return PersonStopMonitor.evaluate(self, now_s)

    def _detection_source_is_bound(self):
        self.detection_source_checks += 1
        return self.detection_source_bound


class _Endpoint:

    def __init__(self, namespace='/', name='hailo_person_stop_bridge'):
        self.node_namespace = namespace
        self.node_name = name


def _msg(payload):
    return type('Msg', (), {'data': json.dumps(payload)})()


def _detections(*labels_and_scores):
    return {
        'detections': [
            {'label': label, 'score': score}
            for label, score in labels_and_scores
        ]
    }


# --- Hailo source binding ----------------------------------------------------

def test_detection_source_requires_exactly_one_expected_publisher():
    assert detection_publisher_binding([_Endpoint()]) == (
        True, ('/hailo_person_stop_bridge',), 1)


def test_detection_source_rejects_missing_wrong_duplicate_and_unresolved_publishers():
    cases = (
        [],
        [_Endpoint(name='impostor')],
        [_Endpoint(), _Endpoint()],
        [_Endpoint(name='_NODE_NAME_UNKNOWN_')],
        [object()],
    )
    for endpoints in cases:
        bound, _paths, count = detection_publisher_binding(endpoints)
        assert bound is False
        assert count == len(endpoints)


def test_required_feed_rejects_frames_from_an_unbound_detection_source():
    stub = _MonitorStub(
        require_detection_feed=True,
        detection_source_bound=False,
        detection_timeout_s=2.0,
    )
    PersonStopMonitor.detections_callback(
        stub, _msg(_detections()), now_s=10.0)
    assert stub.detection_source_checks == 1
    assert stub.last_feed_s is None
    verdict = PersonStopMonitor.evaluate(stub, 10.5)
    assert verdict['person_detected'] is True
    assert verdict['reason'] == 'detector_feed_lost'


def test_optional_feed_preserves_simulation_without_graph_source_checks():
    stub = _MonitorStub(
        require_detection_feed=False,
        detection_source_bound=False,
    )
    PersonStopMonitor.detections_callback(
        stub, _msg(_detections()), now_s=10.0)
    assert stub.detection_source_checks == 0
    assert stub.last_feed_s == 10.0


# --- class filtering ---------------------------------------------------------

def test_person_above_threshold_arms_the_hold():
    stub = _MonitorStub()
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.91))), now_s=10.0)
    assert stub.last_person_seen_s == 10.0
    assert stub.last_count == 1
    assert PersonStopMonitor.evaluate(stub, 10.0)['person_detected'] is True


def test_person_is_the_sole_obstacle_class():
    stub = _MonitorStub()
    payload = _detections(('boat', 0.99), ('buoy', 0.98), ('dog', 0.97))
    PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
    assert stub.last_person_seen_s is None
    assert PersonStopMonitor.evaluate(stub, 10.0)['person_detected'] is False


def test_low_confidence_person_is_ignored():
    stub = _MonitorStub(score_threshold=0.5)
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.31))), now_s=10.0)
    assert stub.last_person_seen_s is None


def test_feed_timestamp_updates_even_with_no_person():
    stub = _MonitorStub()
    PersonStopMonitor.detections_callback(stub, _msg(_detections()), now_s=7.0)
    assert stub.last_feed_s == 7.0
    assert stub.last_person_seen_s is None


def test_malformed_payload_does_not_release_an_active_hold():
    stub = _MonitorStub(person_hold=True, last_person_seen_s=1.0)
    bad = type('Msg', (), {'data': '<<not json>>'})()
    PersonStopMonitor.detections_callback(stub, bad, now_s=10.0)
    assert stub.person_hold is True
    assert stub.logger.warnings


# --- hold policy -------------------------------------------------------------

def test_hold_persists_through_a_detection_flicker():
    stub = _MonitorStub(clear_hold_s=5.0)
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.8))), now_s=10.0)
    PersonStopMonitor.evaluate(stub, 10.0)
    # Frame drops the person for 2 s — inside the clear-hold window.
    assert PersonStopMonitor.evaluate(stub, 12.0)['person_detected'] is True


def test_hold_releases_after_the_clear_window():
    # The hold must not latch: the planner refuses the resume command while it
    # is up, so a hold only an operator could clear could never be cleared.
    stub = _MonitorStub(clear_hold_s=5.0)
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.8))), now_s=10.0)
    assert PersonStopMonitor.evaluate(stub, 12.0)['person_detected'] is True
    assert PersonStopMonitor.evaluate(stub, 16.0)['person_detected'] is False
    assert PersonStopMonitor.evaluate(stub, 1000.0)['person_detected'] is False


def test_stale_feed_holds_only_when_the_feed_is_required():
    optional = _MonitorStub(require_detection_feed=False, detection_timeout_s=2.0)
    assert PersonStopMonitor.evaluate(optional, 50.0)['person_detected'] is False

    required = _MonitorStub(require_detection_feed=True, detection_timeout_s=2.0)
    verdict = PersonStopMonitor.evaluate(required, 50.0)
    assert verdict['person_detected'] is True
    assert verdict['reason'] == 'detector_feed_lost'


def test_live_feed_with_no_person_does_not_hold_when_feed_required():
    stub = _MonitorStub(require_detection_feed=True, detection_timeout_s=2.0)
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('boat', 0.9))), now_s=10.0)
    assert PersonStopMonitor.evaluate(stub, 11.0)['person_detected'] is False


def test_verdict_reports_person_reason_and_score():
    stub = _MonitorStub()
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.77))), now_s=10.0)
    verdict = PersonStopMonitor.evaluate(stub, 10.0)
    assert verdict['reason'] == 'person_detected'
    assert verdict['score'] == 0.77
    assert verdict['count'] == 1


# --- publishing: this node's only write to the shared safety latch -----------
# What that latch does downstream on the physical path is unwired and unproven;
# these cases cover this node's output, nothing beyond it.

def test_hold_raises_the_shared_emergency_latch_every_tick():
    stub = _MonitorStub()
    stub.now_s = 10.0
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.8))))
    for tick in range(3):
        stub.now_s = 10.0 + tick
        PersonStopMonitor.publish_alert(stub)
    # Republished, not edge-triggered: consumers subscribe volatile, so a
    # late-joining bridge must still learn the boat is held.
    assert stub.pub_emergency.messages == [True, True, True]


def test_no_latch_is_raised_when_nothing_is_held():
    stub = _MonitorStub()
    stub.now_s = 10.0
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('boat', 0.99))))
    PersonStopMonitor.publish_alert(stub)
    assert stub.pub_emergency.messages == []


def test_latch_publishing_can_be_switched_off():
    stub = _MonitorStub(latch_emergency_stop=False)
    stub.now_s = 10.0
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.8))))
    PersonStopMonitor.publish_alert(stub)
    assert stub.pub_emergency.messages == []
    assert json.loads(stub.pub_alert.messages[-1])['person_detected'] is True


def test_alert_payload_matches_the_verdict():
    stub = _MonitorStub()
    stub.now_s = 10.0
    PersonStopMonitor.detections_callback(stub, _msg(_detections(('person', 0.77))))
    PersonStopMonitor.publish_alert(stub)
    payload = json.loads(stub.pub_alert.messages[-1])
    assert payload['person_detected'] is True
    assert payload['reason'] == 'person_detected'
    assert payload['score'] == 0.77
    assert payload['count'] == 1


def test_alert_is_published_on_every_tick_even_when_clear():
    stub = _MonitorStub()
    stub.now_s = 5.0
    PersonStopMonitor.publish_alert(stub)
    PersonStopMonitor.publish_alert(stub)
    assert len(stub.pub_alert.messages) == 2
    assert json.loads(stub.pub_alert.messages[0])['person_detected'] is False


# --- malformed detector output must never kill the node ----------------------

def test_unreadable_scores_reject_the_frame_without_raising():
    for bad in (None, 'high', {}, []):
        stub = _MonitorStub()
        payload = {'detections': [{'label': 'person', 'score': bad}]}
        PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
        assert stub.last_person_seen_s is None, bad
        assert stub.last_feed_s is None, bad
        assert stub.logger.warnings, bad
        assert PersonStopMonitor.evaluate(stub, 10.0)['person_detected'] is False


def test_an_unreadable_person_box_rejects_the_whole_frame():
    # We cannot tell whether that box was a person, so the frame carries no
    # usable evidence — counting the readable boxes beside it would be a guess.
    stub = _MonitorStub()
    payload = {'detections': [
        {'label': 'person', 'score': None},
        {'label': 'person', 'score': 0.88},
    ]}
    PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
    assert stub.last_feed_s is None
    assert stub.last_count == 0
    assert stub.logger.warnings


def test_non_finite_scores_never_read_as_a_clear_waterway():
    # NaN raises nothing and compares false against every threshold, so without
    # an explicit check it would mean "no person" on a fresh-looking feed.
    for raw in ('NaN', '-NaN', 'Infinity', '-Infinity', '"nan"', '"inf"'):
        stub = _MonitorStub(require_detection_feed=True)
        data = '{"detections": [{"label": "person", "score": %s}]}' % raw
        PersonStopMonitor.detections_callback(
            stub, type('Msg', (), {'data': data})(), now_s=10.0)
        assert stub.last_feed_s is None, raw
        assert stub.last_count == 0, raw
        verdict = PersonStopMonitor.evaluate(stub, 10.5)
        assert verdict['person_detected'] is True, raw
        assert verdict['reason'] == 'detector_feed_lost', raw


def test_structurally_invalid_entries_reject_the_whole_frame():
    # Each of these used to be skipped, silently turning "I could not read
    # this box" into "no person here" on a feed that still looked fresh.
    shapes = {
        'null entry': '[null]',
        'empty object': '[{}]',
        'missing label': '[{"score": 0.9}]',
        'missing score': '[{"label": "person"}]',
        'boolean score': '[{"label": "person", "score": true}]',
        'non-string label': '[{"label": 42, "score": 0.9}]',
        'string score': '[{"label": "person", "score": "0.9"}]',
        'nested list': '[[{"label": "person", "score": 0.9}]]',
    }
    for name, entries in shapes.items():
        stub = _MonitorStub(require_detection_feed=True)
        data = '{"detections": %s}' % entries
        PersonStopMonitor.detections_callback(
            stub, type('Msg', (), {'data': data})(), now_s=10.0)
        assert stub.last_feed_s is None, name
        assert stub.last_count == 0, name
        assert stub.logger.warnings, name
        assert PersonStopMonitor.evaluate(stub, 10.5)['reason'] == 'detector_feed_lost', name


def test_a_malformed_entry_beside_a_valid_person_still_rejects_the_frame():
    stub = _MonitorStub()
    payload = {'detections': [
        {'label': 'person', 'score': 0.95},
        {'no_label': True},
    ]}
    PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
    assert stub.last_feed_s is None
    assert stub.last_person_seen_s is None


def test_scores_outside_the_confidence_range_reject_the_frame():
    # The contract is a confidence compared against a threshold on the same
    # scale. A negative score would otherwise refresh the feed clock and pass
    # as a low-confidence sighting on a frame that did contain a person.
    for bad in ('-0.1', '1.1', '-1', '2'):
        stub = _MonitorStub(require_detection_feed=True)
        data = '{"detections": [{"label": "person", "score": %s}]}' % bad
        PersonStopMonitor.detections_callback(
            stub, type('Msg', (), {'data': data})(), now_s=10.0)
        assert stub.last_feed_s is None, bad
        assert stub.logger.warnings, bad
        assert PersonStopMonitor.evaluate(stub, 10.5)['reason'] == 'detector_feed_lost', bad


def test_the_confidence_range_endpoints_are_accepted():
    for good in ('0.0', '1.0'):
        stub = _MonitorStub()
        data = '{"detections": [{"label": "person", "score": %s}]}' % good
        PersonStopMonitor.detections_callback(
            stub, type('Msg', (), {'data': data})(), now_s=10.0)
        assert stub.last_feed_s == 10.0, good


def test_blank_labels_reject_the_frame():
    for bad in ('""', '"   "', r'"\t"'):
        stub = _MonitorStub(require_detection_feed=True)
        data = '{"detections": [{"label": %s, "score": 0.9}]}' % bad
        PersonStopMonitor.detections_callback(
            stub, type('Msg', (), {'data': data})(), now_s=10.0)
        assert stub.last_feed_s is None, bad
        assert stub.logger.warnings, bad


def test_surrounding_whitespace_on_a_label_is_tolerated():
    stub = _MonitorStub()
    data = '{"detections": [{"label": "  Person  ", "score": 0.9}]}'
    PersonStopMonitor.detections_callback(
        stub, type('Msg', (), {'data': data})(), now_s=10.0)
    assert stub.last_count == 1


def test_a_well_formed_mixed_frame_is_accepted():
    stub = _MonitorStub()
    payload = {'detections': [
        {'label': 'boat', 'score': 0.99},
        {'label': 'person', 'score': 0.61},
        {'label': 'buoy', 'score': 0.2},
    ]}
    PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
    assert stub.last_feed_s == 10.0
    assert stub.last_count == 1
    assert stub.last_score == 0.61


# --- freshness reaches the consumers -----------------------------------------

def test_verdict_reports_feed_freshness():
    stub = _MonitorStub(detection_timeout_s=2.0)
    assert PersonStopMonitor.evaluate(stub, 10.0)['feed_fresh'] is False
    PersonStopMonitor.detections_callback(stub, _msg(_detections()), now_s=10.0)
    assert PersonStopMonitor.evaluate(stub, 11.0)['feed_fresh'] is True
    assert PersonStopMonitor.evaluate(stub, 13.0)['feed_fresh'] is False


def test_a_clear_frame_without_a_camera_is_not_reported_as_fresh():
    # Simulation runs with require_detection_feed false, so the hold stays
    # down — but the verdict must still say no camera has reported.
    stub = _MonitorStub(require_detection_feed=False)
    verdict = PersonStopMonitor.evaluate(stub, 500.0)
    assert verdict['person_detected'] is False
    assert verdict['feed_fresh'] is False


def test_a_non_finite_score_on_another_class_also_rejects_the_frame():
    # Every entry is validated, not just the person boxes. A detector emitting
    # NaN for boats is malfunctioning, and its person boxes are no more
    # trustworthy — so the frame carries no evidence either way.
    stub = _MonitorStub(require_detection_feed=True)
    data = '{"detections": [{"label": "boat", "score": NaN}]}'
    PersonStopMonitor.detections_callback(
        stub, type('Msg', (), {'data': data})(), now_s=10.0)
    assert stub.last_feed_s is None
    assert stub.logger.warnings
    assert PersonStopMonitor.evaluate(stub, 10.5)['reason'] == 'detector_feed_lost'


def test_non_object_payload_shapes_are_rejected():
    for payload in ('[]', '123', 'null', '"text"', '{bad}'):
        stub = _MonitorStub(person_hold=True, last_person_seen_s=1.0)
        bad = type('Msg', (), {'data': payload})()
        PersonStopMonitor.detections_callback(stub, bad, now_s=10.0)
        assert stub.person_hold is True, payload
        assert stub.last_feed_s is None, payload


def test_empty_object_is_not_a_detection_frame():
    # An empty object carries no evidence about the water. Accepting it would
    # drop a hold AND make a dead detector look alive to the feed watchdog.
    stub = _MonitorStub(require_detection_feed=True, last_person_seen_s=1.0)
    PersonStopMonitor.detections_callback(stub, _msg({}), now_s=10.0)
    assert stub.last_feed_s is None
    assert stub.logger.warnings
    assert PersonStopMonitor.evaluate(stub, 10.0)['reason'] == 'detector_feed_lost'


def test_null_detections_field_is_rejected():
    stub = _MonitorStub(require_detection_feed=True)
    PersonStopMonitor.detections_callback(stub, _msg({'detections': None}), now_s=10.0)
    assert stub.last_feed_s is None
    assert PersonStopMonitor.evaluate(stub, 10.0)['person_detected'] is True


def test_an_explicitly_empty_frame_is_still_a_live_frame():
    stub = _MonitorStub(require_detection_feed=True)
    PersonStopMonitor.detections_callback(stub, _msg({'detections': []}), now_s=10.0)
    assert stub.last_feed_s == 10.0
    assert PersonStopMonitor.evaluate(stub, 10.5)['person_detected'] is False


def test_highest_scoring_person_is_reported():
    stub = _MonitorStub()
    payload = _detections(('person', 0.55), ('person', 0.93), ('boat', 0.99))
    PersonStopMonitor.detections_callback(stub, _msg(payload), now_s=10.0)
    assert stub.last_score == 0.93
    assert stub.last_count == 2
