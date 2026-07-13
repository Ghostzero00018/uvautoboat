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

from contextlib import ExitStack
from unittest import mock

import plan.waypoint_planner as wp
from rclpy.executors import ExternalShutdownException


def test_main_handles_external_shutdown_without_double_shutdown():
    with ExitStack() as stack:
        stack.enter_context(mock.patch.object(wp.rclpy, 'init'))
        mock_node = stack.enter_context(
            mock.patch.object(wp, 'WaypointPlanner'))
        stack.enter_context(
            mock.patch.object(
                wp.rclpy, 'spin',
                side_effect=ExternalShutdownException()))
        mock_try_shutdown = stack.enter_context(
            mock.patch.object(wp.rclpy, 'try_shutdown'))
        mock_shutdown = stack.enter_context(
            mock.patch.object(wp.rclpy, 'shutdown'))

        # Must not raise despite the external shutdown during spin.
        wp.main()

        mock_node.return_value.destroy_node.assert_called_once()
        mock_try_shutdown.assert_called_once()
        mock_shutdown.assert_not_called()
