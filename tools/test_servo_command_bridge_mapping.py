#!/usr/bin/env python3
"""Offline characterization tests for bridge imports and PWM mapping."""

import ast
import importlib.util
import pathlib
import subprocess
import sys
import unittest


BRIDGE_PATH = pathlib.Path(__file__).with_name("servo_command_bridge.py")
EVIDENCE_PATH = pathlib.Path(__file__).with_name("fcu_to_vrx_evidence.py")
EVIDENCE_SPEC = importlib.util.spec_from_file_location(
    "fcu_to_vrx_evidence_mapping_test", EVIDENCE_PATH
)
EVIDENCE = importlib.util.module_from_spec(EVIDENCE_SPEC)
assert EVIDENCE_SPEC.loader is not None
sys.modules[EVIDENCE_SPEC.name] = EVIDENCE
EVIDENCE_SPEC.loader.exec_module(EVIDENCE)


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
    namespace = {"pwm_to_normalised": EVIDENCE.pwm_to_normalised}
    exec(compile(module, str(BRIDGE_PATH), "exec"), namespace)
    return namespace["MappingProbe"]


MappingProbe = load_mapping_probe()


class ServoCommandBridgeMappingTests(unittest.TestCase):
    def test_bridge_imports_with_real_script_path_semantics(self):
        import_probe = (
            "import runpy, sys\n"
            f"sys.path[0] = {str(BRIDGE_PATH.parent)!r}\n"
            f"runpy.run_path({str(BRIDGE_PATH)!r}, "
            "run_name='servo_command_bridge_import_test')\n"
        )
        completed = subprocess.run(
            [sys.executable, "-c", import_probe],
            cwd=BRIDGE_PATH.parent,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(
            completed.returncode,
            0,
            msg=completed.stdout + completed.stderr,
        )

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
