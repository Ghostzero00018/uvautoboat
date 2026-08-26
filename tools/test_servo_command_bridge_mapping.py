#!/usr/bin/env python3
"""Dependency-free characterization tests for the bridge PWM mapping."""

import ast
import pathlib
import unittest


BRIDGE_PATH = pathlib.Path(__file__).with_name("servo_command_bridge.py")


def load_mapping_probe():
    tree = ast.parse(BRIDGE_PATH.read_text(encoding="utf-8"), filename=str(BRIDGE_PATH))
    bridge_class = next(
        node
        for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "ServoCommandBridge"
    )
    mapping_method = next(
        node
        for node in bridge_class.body
        if isinstance(node, ast.FunctionDef) and node.name == "pwm_to_normalised"
    )
    probe_class = ast.ClassDef(
        name="MappingProbe",
        bases=[],
        keywords=[],
        body=[mapping_method],
        decorator_list=[],
    )
    module = ast.fix_missing_locations(ast.Module(body=[probe_class], type_ignores=[]))
    namespace = {}
    exec(compile(module, str(BRIDGE_PATH), "exec"), namespace)
    return namespace["MappingProbe"]


MappingProbe = load_mapping_probe()


class ServoCommandBridgeMappingTests(unittest.TestCase):
    def make_probe(self, minimum, neutral, maximum):
        probe = MappingProbe()
        probe.pwm_min = minimum
        probe.pwm_neutral = neutral
        probe.pwm_max = maximum
        return probe

    def test_real_fcu_bottom_neutral_mapping_and_clamping(self):
        probe = self.make_probe(800, 800, 2200)
        expected = {
            None: 0.0,
            0: 0.0,
            700: 0.0,
            800: 0.0,
            1500: 0.5,
            2200: 1.0,
            2300: 1.0,
        }
        for pwm, normalised in expected.items():
            with self.subTest(pwm=pwm):
                self.assertAlmostEqual(probe.pwm_to_normalised(pwm), normalised)

    def test_midscale_mapping_remains_bidirectional(self):
        probe = self.make_probe(1000, 1500, 2000)
        expected = {
            1000: -1.0,
            1250: -0.5,
            1500: 0.0,
            1750: 0.5,
            2000: 1.0,
        }
        for pwm, normalised in expected.items():
            with self.subTest(pwm=pwm):
                self.assertAlmostEqual(probe.pwm_to_normalised(pwm), normalised)


if __name__ == "__main__":
    unittest.main()
