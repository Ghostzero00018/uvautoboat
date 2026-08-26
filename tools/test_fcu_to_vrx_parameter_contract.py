#!/usr/bin/env python3
"""Dependency-free tests binding the supervisor's bridge overrides to the
bridge's own parameter declarations.

An override whose name is not declared by the bridge is stored by rclpy and
never applied, so the bridge silently keeps its own default. For the PWM rails
that means a mid-scale neutral against a bottom-neutral boat, which the
supervisor would still report as the live-read rails. These tests make that
drift a test failure instead of a runtime surprise.
"""

import ast
import pathlib
import subprocess
import tempfile
import unittest


SUPERVISOR_PATH = pathlib.Path(__file__).with_name("fcu_to_vrx_workstation.sh")
BRIDGE_PATH = pathlib.Path(__file__).with_name("servo_command_bridge.py")

VALID_ENVIRONMENT = {
    "FCU_VRX_LEFT_SERVO_CHANNEL": "3",
    "FCU_VRX_RIGHT_SERVO_CHANNEL": "1",
    "FCU_VRX_LEFT_PWM_MIN": "800",
    "FCU_VRX_LEFT_PWM_NEUTRAL": "800",
    "FCU_VRX_LEFT_PWM_MAX": "2200",
    "FCU_VRX_RIGHT_PWM_MIN": "800",
    "FCU_VRX_RIGHT_PWM_NEUTRAL": "800",
    "FCU_VRX_RIGHT_PWM_MAX": "2200",
    "FCU_VRX_MAX_THRUST": "800.0",
}

EXPECTED_OVERRIDE_NAMES = frozenset(
    {
        "udp_recv_port",
        "udp_send_port",
        "target_ip",
        "left_servo_channel",
        "right_servo_channel",
        "pwm_min",
        "pwm_neutral",
        "pwm_max",
        "max_thrust",
        "publish_sensors",
        "publish_cmd_vel",
    }
)


def constructed_bridge_arguments():
    """Return the bridge argument vector the supervisor actually builds."""
    script = (
        'source "$1"\n'
        "fcuvrx_validate_configuration\n"
        "fcuvrx_build_commands\n"
        'printf "%s\\n" "${FCUVRX_BRIDGE_COMMAND[@]}"\n'
    )
    completed = subprocess.run(
        ["bash", "-c", script, "_", str(SUPERVISOR_PATH)],
        env=dict(VALID_ENVIRONMENT, PATH="/usr/bin:/bin", HOME="/nonexistent"),
        capture_output=True,
        text=True,
        check=True,
    )
    return completed.stdout.splitlines()


def override_names(arguments):
    """Collect the name of every `-p name:=value` override, in order."""
    names = []
    for index, argument in enumerate(arguments):
        if argument != "-p":
            continue
        if index + 1 >= len(arguments):
            raise AssertionError("trailing -p with no override value")
        override = arguments[index + 1]
        if ":=" not in override:
            raise AssertionError(f"override is not name:=value: {override}")
        names.append(override.split(":=", 1)[0])
    return names


def declared_parameter_names(source, filename):
    """Collect every name passed to a `declare_parameter` call."""
    names = set()
    for node in ast.walk(ast.parse(source, filename=filename)):
        if not isinstance(node, ast.Call):
            continue
        function = node.func
        attribute = getattr(function, "attr", None) or getattr(function, "id", None)
        if attribute != "declare_parameter" or not node.args:
            continue
        first = node.args[0]
        if isinstance(first, ast.Constant) and isinstance(first.value, str):
            names.add(first.value)
    return names


class BridgeParameterContractTests(unittest.TestCase):
    def test_every_override_is_declared_by_the_bridge(self):
        names = override_names(constructed_bridge_arguments())
        self.assertEqual(
            len(names), len(set(names)), f"duplicate override in command: {names}"
        )
        self.assertEqual(
            set(names),
            set(EXPECTED_OVERRIDE_NAMES),
            "supervisor override set changed; update the bridge contract "
            "deliberately rather than by drift",
        )
        declared = declared_parameter_names(
            BRIDGE_PATH.read_text(encoding="utf-8"), str(BRIDGE_PATH)
        )
        undeclared = sorted(set(names) - declared)
        self.assertEqual(
            undeclared,
            [],
            f"overrides are not declared by {BRIDGE_PATH.name} and would be "
            f"silently ignored, leaving the bridge default live: {undeclared}",
        )

    def test_a_renamed_bridge_parameter_is_rejected(self):
        source = BRIDGE_PATH.read_text(encoding="utf-8")
        original = "declare_parameter('pwm_neutral'"
        self.assertEqual(
            source.count(original),
            1,
            "drift fixture anchor is no longer unique; update the fixture",
        )
        drifted = source.replace(original, "declare_parameter('pwm_neutral_v2'")

        with tempfile.TemporaryDirectory() as directory:
            drifted_path = pathlib.Path(directory) / "servo_command_bridge.py"
            drifted_path.write_text(drifted, encoding="utf-8")
            declared = declared_parameter_names(
                drifted_path.read_text(encoding="utf-8"), str(drifted_path)
            )

        self.assertNotIn("pwm_neutral", declared)
        self.assertIn("pwm_neutral_v2", declared)

        names = override_names(constructed_bridge_arguments())
        undeclared = sorted(set(names) - declared)
        self.assertEqual(
            undeclared,
            ["pwm_neutral"],
            "the contract check failed to reject a renamed bridge parameter",
        )


if __name__ == "__main__":
    unittest.main()
