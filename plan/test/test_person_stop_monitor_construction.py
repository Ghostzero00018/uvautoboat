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

"""
Build the real node, not a stub.

The policy tests drive unbound methods against hand-written stubs, which is
fast and precise but blind to anything __init__ does — a startup log line
referring to a parameter that no longer exists raises AttributeError at launch
and every stub test still passes. This file exists to catch exactly that.
"""

from pathlib import Path

from plan.person_stop_monitor import PersonStopMonitor
import pytest
import rclpy
import yaml


# Parameters rclpy declares on every node; not ours to assert on.
BUILT_IN_PARAMS = {'use_sim_time', 'start_type_description_service'}

LAUNCH_FILE = Path(__file__).resolve().parents[2] / 'launch' / 'autoboat.launch.yaml'


def _launch_params(exec_name):
    """Return the parameter block the launch file gives an executable."""
    document = yaml.safe_load(LAUNCH_FILE.read_text())
    for entry in document['launch']:
        node = entry.get('node')
        if node and node.get('exec') == exec_name:
            return {p['name']: p['value'] for p in node.get('param') or []}
    raise AssertionError(f'{exec_name} is not launched by {LAUNCH_FILE.name}')


@pytest.fixture
def ros_context():
    rclpy.init(args=[])
    try:
        yield
    finally:
        if rclpy.ok():
            rclpy.shutdown()


def test_node_constructs_with_launch_defaults(ros_context):
    node = PersonStopMonitor()
    try:
        assert node.get_name() == 'person_stop_monitor_node'
        # Every attribute the node advertises must actually exist.
        assert node.person_class == 'person'
        assert node.score_threshold == pytest.approx(0.5)
        assert node.clear_hold_s == pytest.approx(5.0)
        assert node.detection_timeout_s == pytest.approx(2.0)
        assert node.require_detection_feed is False
        assert node.latch_emergency_stop is True
        assert node.person_hold is False
    finally:
        node.destroy_node()


def test_launch_file_sets_no_parameter_the_node_does_not_declare(ros_context):
    # Read the real launch file: a param the node dropped, or a typo, would
    # otherwise only surface as a runtime override failure on the boat.
    launched = _launch_params('person_stop_monitor')
    node = PersonStopMonitor()
    try:
        declared = set(node._parameters) - BUILT_IN_PARAMS
    finally:
        node.destroy_node()
    assert launched, 'launch file gives the monitor no parameters'
    assert set(launched) <= declared, \
        f'launch sets undeclared parameters: {sorted(set(launched) - declared)}'


def test_launch_values_match_the_node_defaults(ros_context):
    # The node's defaults and the launch file are two copies of one contract.
    # Drift between them means the tested behaviour is not the shipped one.
    launched = _launch_params('person_stop_monitor')
    node = PersonStopMonitor()
    try:
        for name, launch_value in launched.items():
            assert node.get_parameter(name).value == launch_value, name
    finally:
        node.destroy_node()


def test_the_removed_latch_parameter_is_gone_from_both_surfaces(ros_context):
    # auto_clear made the hold unrecoverable; it must not come back in either
    # the node or the launch file.
    assert 'auto_clear' not in _launch_params('person_stop_monitor')
    node = PersonStopMonitor()
    try:
        assert 'auto_clear' not in node._parameters
        assert not hasattr(node, 'auto_clear')
    finally:
        node.destroy_node()


def test_a_clear_frame_then_a_person_drives_the_real_publishers(ros_context):
    node = PersonStopMonitor()
    try:
        published = []
        node.pub_emergency.publish = lambda msg: published.append(msg.data)
        node.detections_callback(
            type('Msg', (), {'data': '{"detections": [{"label": "boat", "score": 0.9}]}'})(),
            now_s=node._now_s(),
        )
        node.publish_alert()
        assert published == []

        node.detections_callback(
            type('Msg', (), {'data': '{"detections": [{"label": "person", "score": 0.9}]}'})(),
            now_s=node._now_s(),
        )
        node.publish_alert()
        assert published == [True]
    finally:
        node.destroy_node()
