#!/usr/bin/env python3
"""Offline characterization tests for bridge imports and PWM mapping."""

import ast
import importlib.util
import json
import pathlib
import subprocess
import sys
import threading
from types import SimpleNamespace
import unittest
from unittest import mock


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


def load_bridge_module():
    spec = importlib.util.spec_from_file_location(
        "servo_command_bridge_direct_input_test", BRIDGE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    tools_path = str(BRIDGE_PATH.parent)
    sys.path.insert(0, tools_path)
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.remove(tools_path)
    return module


def declared_parameter_default(name):
    tree = ast.parse(BRIDGE_PATH.read_text(encoding="utf-8"), filename=str(BRIDGE_PATH))
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if getattr(node.func, "attr", None) != "declare_parameter":
            continue
        if len(node.args) < 2:
            continue
        if (
            isinstance(node.args[0], ast.Constant)
            and node.args[0].value == name
            and isinstance(node.args[1], ast.Constant)
        ):
            return node.args[1].value
    raise AssertionError(f"parameter {name!r} has no literal default")


class RecordingPublisher:
    def __init__(self):
        self.messages = []

    def publish(self, message):
        self.messages.append(message)


class RecordingLogger:
    def __init__(self):
        self.info_messages = []
        self.warning_messages = []
        self.error_messages = []

    def info(self, *_args, **_kwargs):
        self.info_messages.append(_args[0])

    def warning(self, *_args, **_kwargs):
        self.warning_messages.append(_args[0])

    def error(self, *_args, **_kwargs):
        self.error_messages.append(_args[0])


class RecordingMavlink:
    def __init__(self):
        self.servo_frames = []

    def servo_output_raw_send(self, *fields):
        self.servo_frames.append(fields)


def construct_with_recorded_interfaces(module, input_mode, **parameter_overrides):
    logger = RecordingLogger()
    resources = {
        "connections": [],
        "publishers": [],
        "subscriptions": [],
        "timers": [],
        "udp_sockets": [],
        "logger": logger,
    }

    class Connection:
        def __init__(self):
            self.mav = RecordingMavlink()

        def close(self):
            pass

    class DatagramSocket:
        def __init__(self, *_args, **_kwargs):
            self.bound = None
            self.blocking = None
            self.sent = []
            resources["udp_sockets"].append(self)

        def bind(self, address):
            self.bound = address

        def setblocking(self, enabled):
            self.blocking = enabled

        def sendto(self, payload, address):
            self.sent.append((payload, address))
            return len(payload)

        def recvfrom(self, _size):
            raise BlockingIOError

        def close(self):
            pass

    def declare_parameter(_self, name, default):
        value = parameter_overrides.get(name, default)
        if name == "input_mode":
            value = input_mode
        return SimpleNamespace(value=value)

    def create_publisher(_self, *arguments):
        resources["publishers"].append(arguments)
        return RecordingPublisher()

    def create_subscription(_self, *arguments):
        resources["subscriptions"].append(arguments)
        return object()

    def create_timer(_self, *arguments):
        resources["timers"].append(arguments)
        return object()

    def mavlink_connection(endpoint, *_args, **_kwargs):
        resources["connections"].append(endpoint)
        return Connection()

    with (
        mock.patch.object(module.Node, "__init__", lambda *_args, **_kwargs: None),
        mock.patch.object(
            module.ServoCommandBridge, "declare_parameter", declare_parameter
        ),
        mock.patch.object(
            module.ServoCommandBridge, "create_publisher", create_publisher
        ),
        mock.patch.object(
            module.ServoCommandBridge, "create_subscription", create_subscription
        ),
        mock.patch.object(module.ServoCommandBridge, "create_timer", create_timer),
        mock.patch.object(
            module.ServoCommandBridge,
            "get_logger",
            lambda _self: logger,
        ),
        mock.patch.object(
            module.mavutil, "mavlink_connection", mavlink_connection
        ),
        mock.patch.object(module.socket, "socket", DatagramSocket),
    ):
        bridge = module.ServoCommandBridge()
    return bridge, resources


class ServoCommandBridgeMappingTests(unittest.TestCase):
    def test_main_loop_exits_when_a_fail_closed_check_clears_running(self):
        tree = ast.parse(
            BRIDGE_PATH.read_text(encoding="utf-8"), filename=str(BRIDGE_PATH)
        )
        main_function = next(
            node
            for node in tree.body
            if isinstance(node, ast.FunctionDef) and node.name == "main"
        )
        active_loop = next(
            node
            for node in ast.walk(main_function)
            if isinstance(node, ast.While)
            and any(
                isinstance(call, ast.Call)
                and isinstance(call.func, ast.Attribute)
                and call.func.attr == "spin_once"
                for call in ast.walk(node)
            )
            and not any(
                isinstance(name, ast.Name) and name.id == "flush_deadline"
                for name in ast.walk(node)
            )
        )
        self.assertIn("node._running.is_set()", ast.unparse(active_loop.test))

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

    def test_udp_mavlink_remains_the_default_input_mode(self):
        self.assertEqual(
            declared_parameter_default("input_mode"), "mavlink_udp"
        )
        self.assertEqual(
            declared_parameter_default("rc_out_topic"), "/mavros/rc/out"
        )
        self.assertEqual(
            declared_parameter_default("rc_out_publisher"), "/mavros/rc"
        )
        self.assertEqual(
            declared_parameter_default("twin_telemetry_role"), "disabled"
        )

        module = load_bridge_module()
        _bridge, resources = construct_with_recorded_interfaces(
            module, "mavlink_udp"
        )
        self.assertEqual(
            resources["connections"],
            ["udpout:127.0.0.1:14551", "udpin:0.0.0.0:14555"],
        )
        self.assertEqual(len(resources["publishers"]), 3)
        self.assertEqual(len(resources["subscriptions"]), 2)
        self.assertEqual(len(resources["timers"]), 1)

    def test_twin_telemetry_sender_and_receiver_are_explicit_mode_specific(self):
        module = load_bridge_module()
        sender, sender_resources = construct_with_recorded_interfaces(
            module,
            "mavlink_udp",
            twin_telemetry_role="sender",
        )
        receiver, receiver_resources = construct_with_recorded_interfaces(
            module,
            "ros_rc_out_relay",
            twin_telemetry_role="receiver",
        )

        self.assertEqual(sender.twin_telemetry_role, "sender")
        self.assertEqual(len(sender_resources["publishers"]), 3)
        self.assertEqual(len(sender_resources["subscriptions"]), 3)
        self.assertEqual(len(sender_resources["timers"]), 2)
        self.assertIsNone(sender.pub_twin_telemetry)

        self.assertEqual(receiver.twin_telemetry_role, "receiver")
        self.assertEqual(len(receiver_resources["publishers"]), 1)
        self.assertEqual(
            receiver_resources["publishers"][0][1],
            "/fcu_to_vrx/twin_telemetry",
        )
        self.assertEqual(len(receiver_resources["subscriptions"]), 1)
        self.assertEqual(len(receiver_resources["timers"]), 2)
        self.assertIsNotNone(receiver.pub_twin_telemetry)

        with self.assertRaisesRegex(
            ValueError, "twin_telemetry_role sender requires mavlink_udp"
        ):
            construct_with_recorded_interfaces(
                module,
                "ros_rc_out_relay",
                twin_telemetry_role="sender",
            )
        with self.assertRaisesRegex(
            ValueError,
            "twin_telemetry_role receiver requires ros_rc_out_relay",
        ):
            construct_with_recorded_interfaces(
                module,
                "mavlink_udp",
                twin_telemetry_role="receiver",
            )

    def test_default_mode_has_no_module_level_mavros_message_dependency(self):
        tree = ast.parse(BRIDGE_PATH.read_text(encoding="utf-8"))
        module_level_imports = {
            node.module
            for node in tree.body
            if isinstance(node, ast.ImportFrom) and node.module is not None
        }
        self.assertNotIn("mavros_msgs.msg", module_level_imports)
        constructor = next(
            node
            for node in ast.walk(tree)
            if isinstance(node, ast.FunctionDef) and node.name == "__init__"
        )
        self.assertTrue(
            any(
                isinstance(node, ast.ImportFrom)
                and node.module == "mavros_msgs.msg"
                and any(alias.name == "RCOut" for alias in node.names)
                for node in ast.walk(constructor)
            )
        )

    def test_ros_rc_out_relay_is_sender_only(self):
        module = load_bridge_module()
        bridge, resources = construct_with_recorded_interfaces(
            module, "ros_rc_out_relay"
        )

        self.assertEqual(resources["connections"], ["udpout:127.0.0.1:14551"])
        self.assertEqual(resources["publishers"], [])
        self.assertEqual(len(resources["subscriptions"]), 1)
        self.assertEqual(resources["subscriptions"][0][0].__name__, "RCOut")
        self.assertEqual(resources["subscriptions"][0][1], "/mavros/rc/out")
        self.assertEqual(len(resources["timers"]), 1)
        self.assertIsNone(bridge.mav_in)
        self.assertIsNone(bridge.heartbeat_timer)
        self.assertIsNone(bridge.sub_gps)
        self.assertIsNone(bridge.sub_imu)
        self.assertIsNone(bridge.pub_left)
        self.assertIsNone(bridge.pub_right)
        self.assertIsNone(bridge.pub_servo_evidence)
        bridge.start()
        self.assertIsNone(bridge.recv_thread)
        self.assertNotIn(
            "FCU_TO_VRX_RC_OUT_RELAY_READY=PASS ",
            "\n".join(resources["logger"].info_messages),
        )

    def test_ros_rc_out_relay_preserves_real_boat_channels_for_udp_receiver(self):
        module = load_bridge_module()
        relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        relay.left_channel = 3
        relay.right_channel = 1
        relay._running = threading.Event()
        relay._running.set()
        relay._relay_frame_seen = False
        relay._relay_source_ready = True
        relay.rc_out_topic = "/mavros/rc/out"
        relay.rc_out_publisher = "/mavros/rc"
        relay.get_publishers_info_by_topic = lambda _topic: [
            SimpleNamespace(node_namespace="/mavros", node_name="rc")
        ]
        relay.mav_out = SimpleNamespace(mav=RecordingMavlink())
        relay.get_logger = lambda: RecordingLogger()

        relay.handle_rc_out_relay(SimpleNamespace(channels=[800, 0, 2200]))

        self.assertEqual(len(relay.mav_out.mav.servo_frames), 1)
        encoded = relay.mav_out.mav.servo_frames[0]
        self.assertGreaterEqual(encoded[0], 0)
        self.assertLessEqual(encoded[0], 0xFFFFFFFF)
        self.assertEqual(encoded[1], 0)
        self.assertEqual(encoded[2:10], (800, 0, 2200, 0, 0, 0, 0, 0))

        receiver = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        receiver.left_channel = 3
        receiver.right_channel = 1
        receiver.pwm_min = 800
        receiver.pwm_neutral = 800
        receiver.pwm_max = 2200
        receiver.max_thrust = 800.0
        receiver.evidence_config = {
            "left_channel": 3,
            "right_channel": 1,
            "left": {"minimum": 800, "trim": 800, "maximum": 2200},
            "right": {"minimum": 800, "trim": 800, "maximum": 2200},
            "max_thrust": 800.0,
        }
        receiver._running = threading.Event()
        receiver._running.set()
        receiver._publish_lock = threading.Lock()
        receiver._servo_frame_seen = False
        receiver.pub_left = RecordingPublisher()
        receiver.pub_right = RecordingPublisher()
        receiver.pub_servo_evidence = RecordingPublisher()
        receiver.pub_cmd_vel = None
        receiver.get_logger = lambda: RecordingLogger()
        incoming = SimpleNamespace(time_usec=encoded[0])
        for channel, pwm in enumerate(encoded[2:10], start=1):
            setattr(incoming, f"servo{channel}_raw", pwm)

        receiver.handle_servo_output(incoming)

        self.assertEqual(len(receiver.pub_left.messages), 1)
        self.assertEqual(len(receiver.pub_right.messages), 1)
        self.assertEqual(receiver.pub_left.messages[0].data, 800.0)
        self.assertEqual(receiver.pub_right.messages[0].data, 0.0)
        evidence = json.loads(receiver.pub_servo_evidence.messages[0].data)
        self.assertEqual(evidence["left_channel"], 3)
        self.assertEqual(evidence["right_channel"], 1)
        self.assertEqual(evidence["left_pwm"], 2200)
        self.assertEqual(evidence["right_pwm"], 800)
        self.assertEqual(evidence["left_thrust"], 800.0)
        self.assertEqual(evidence["right_thrust"], 0.0)
        self.assertEqual(evidence["mavlink_time_usec"], encoded[0])

    def test_ros_rc_out_relay_rejects_missing_mapped_channel(self):
        module = load_bridge_module()
        relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        relay.left_channel = 3
        relay.right_channel = 1
        relay._running = threading.Event()
        relay._running.set()
        relay._relay_frame_seen = False
        relay._relay_source_ready = True
        relay.rc_out_topic = "/mavros/rc/out"
        relay.rc_out_publisher = "/mavros/rc"
        relay.get_publishers_info_by_topic = lambda _topic: [
            SimpleNamespace(node_namespace="/mavros", node_name="rc")
        ]
        relay.mav_out = SimpleNamespace(mav=RecordingMavlink())
        relay.get_logger = lambda: RecordingLogger()

        relay.handle_rc_out_relay(SimpleNamespace(channels=[800, 0]))

        self.assertEqual(relay.mav_out.mav.servo_frames, [])

    def test_relay_waits_for_source_then_binds_to_exact_mavros_rc_publisher(self):
        module = load_bridge_module()
        relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        relay._running = threading.Event()
        relay._running.set()
        relay._relay_source_ready = False
        relay.rc_out_topic = "/mavros/rc/out"
        relay.rc_out_publisher = "/mavros/rc"
        relay.target_ip = "127.0.0.1"
        relay.udp_send_port = 14555
        relay.left_channel = 3
        relay.right_channel = 1
        relay.pwm_min = 800
        relay.pwm_neutral = 800
        relay.pwm_max = 2200
        logger = RecordingLogger()
        relay.get_logger = lambda: logger
        endpoint_rounds = iter(
            (
                [],
                [SimpleNamespace(node_namespace="/mavros", node_name="rc")],
            )
        )
        relay.get_publishers_info_by_topic = lambda _topic: next(endpoint_rounds)

        self.assertFalse(relay.check_rc_out_relay_source())
        self.assertTrue(relay._running.is_set())
        self.assertTrue(relay.check_rc_out_relay_source())
        self.assertTrue(relay._relay_source_ready)
        self.assertIn(
            "FCU_TO_VRX_RC_OUT_RELAY_READY=PASS ",
            "\n".join(logger.info_messages),
        )

    def test_bound_relay_stops_on_zero_duplicate_or_wrong_source(self):
        module = load_bridge_module()
        invalid_sources = {
            "zero": [],
            "duplicate": [
                SimpleNamespace(node_namespace="/mavros", node_name="rc"),
                SimpleNamespace(node_namespace="/other", node_name="rc"),
            ],
            "duplicate-same-name": [
                SimpleNamespace(node_namespace="/mavros", node_name="rc"),
                SimpleNamespace(node_namespace="/mavros", node_name="rc"),
            ],
            "expected-plus-unresolved": [
                SimpleNamespace(node_namespace="/mavros", node_name="rc"),
                SimpleNamespace(
                    node_namespace="_NODE_NAMESPACE_UNKNOWN_",
                    node_name="_NODE_NAME_UNKNOWN_",
                ),
            ],
            "wrong": [SimpleNamespace(node_namespace="/mavros", node_name="wrong")],
        }
        for label, endpoints in invalid_sources.items():
            with self.subTest(label=label):
                relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
                relay._running = threading.Event()
                relay._running.set()
                relay._relay_source_ready = True
                relay.rc_out_topic = "/mavros/rc/out"
                relay.rc_out_publisher = "/mavros/rc"
                relay.get_publishers_info_by_topic = lambda _topic, value=endpoints: value
                logger = RecordingLogger()
                relay.get_logger = lambda: logger

                with self.assertRaisesRegex(RuntimeError, "publisher binding lost"):
                    relay.check_rc_out_relay_source()
                self.assertFalse(relay._running.is_set())
                self.assertIn(
                    "FCU_TO_VRX_RC_OUT_RELAY_STOP=FAIL",
                    "\n".join(logger.error_messages),
                )

    def test_twin_telemetry_round_trip_is_validated_and_published(self):
        module = load_bridge_module()
        now_ns = 8_000_000_000
        payload = {
            "schema": module.TWIN_TELEMETRY_SCHEMA,
            "source": module.TWIN_TELEMETRY_SOURCE,
            "sequence": 7,
            "sent_unix_ns": 1_788_000_000_000_000_000,
            "sent_monotonic_ns": now_ns - 50_000_000,
            "pose": {
                "frame_id": "sydney_regatta",
                "child_frame_id": "wamv",
                "position": {"x": 12.5, "y": -3.0, "z": 0.2},
                "orientation": {"x": 0.0, "y": 0.0, "z": 0.1, "w": 0.995},
            },
            "thrust": {"left_newtons": 400.0, "right_newtons": 200.0},
        }
        relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        relay._running = threading.Event()
        relay._running.set()
        relay.twin_telemetry_world_frame = "sydney_regatta"
        relay.twin_telemetry_stale_seconds = 5.0
        relay.max_thrust = 800.0
        relay._twin_telemetry_sequence = None
        relay._twin_telemetry_ready = False
        relay._last_twin_telemetry_monotonic_ns = None
        relay.twin_telemetry_topic = "/fcu_to_vrx/twin_telemetry"
        relay.twin_telemetry_udp_port = 14556
        relay.pub_twin_telemetry = RecordingPublisher()
        logger = RecordingLogger()
        relay.get_logger = lambda: logger

        relay.handle_twin_telemetry_datagram(
            json.dumps(payload).encode("utf-8"),
            ("127.0.0.1", 32000),
            now_monotonic_ns=now_ns,
        )

        self.assertTrue(relay._twin_telemetry_ready)
        self.assertEqual(relay._twin_telemetry_sequence, 7)
        self.assertEqual(len(relay.pub_twin_telemetry.messages), 1)
        self.assertEqual(
            json.loads(relay.pub_twin_telemetry.messages[0].data), payload
        )
        self.assertIn(
            "FCU_TO_VRX_TWIN_TELEMETRY_READY=PASS ",
            "\n".join(logger.info_messages),
        )

    def test_twin_telemetry_sender_combines_fresh_world_pose_and_thrust(self):
        module = load_bridge_module()
        sender = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        sender._running = threading.Event()
        sender._running.set()
        sender._twin_telemetry_lock = threading.Lock()
        sender._latest_twin_pose = None
        sender._latest_twin_pose_monotonic_ns = None
        sender._latest_twin_thrust = {
            "left_newtons": 320.0,
            "right_newtons": 160.0,
        }
        sender._latest_twin_thrust_monotonic_ns = 9_900_000_000
        sender._twin_telemetry_sequence = None
        sender.twin_telemetry_world_frame = "sydney_regatta"
        sender.twin_telemetry_stale_seconds = 5
        sender.twin_telemetry_udp_port = 14556
        sender.max_thrust = 800.0
        datagrams = []
        sender.twin_telemetry_socket = SimpleNamespace(
            sendto=lambda payload, address: (
                datagrams.append((payload, address)) or len(payload)
            )
        )
        sender.get_logger = lambda: RecordingLogger()
        world_transform = SimpleNamespace(
            header=SimpleNamespace(frame_id="sydney_regatta"),
            child_frame_id="wamv",
            transform=SimpleNamespace(
                translation=SimpleNamespace(x=2.0, y=-1.0, z=0.1),
                rotation=SimpleNamespace(x=0.0, y=0.0, z=0.0, w=1.0),
            ),
        )
        wrong_transform = SimpleNamespace(
            header=SimpleNamespace(frame_id="other"),
            child_frame_id="sensor",
            transform=world_transform.transform,
        )

        with (
            mock.patch.object(module.time, "monotonic_ns", return_value=10_000_000_000),
            mock.patch.object(
                module.time, "time_ns", return_value=1_788_000_000_000_000_000
            ),
        ):
            sender.twin_pose_callback(
                SimpleNamespace(transforms=[wrong_transform, world_transform])
            )
            self.assertTrue(sender.send_twin_telemetry())

        self.assertEqual(len(datagrams), 1)
        encoded, address = datagrams[0]
        self.assertEqual(address, ("127.0.0.1", 14556))
        payload = json.loads(encoded)
        self.assertEqual(payload["pose"]["frame_id"], "sydney_regatta")
        self.assertEqual(payload["pose"]["child_frame_id"], "wamv")
        self.assertEqual(payload["thrust"]["left_newtons"], 320.0)
        self.assertEqual(payload["thrust"]["right_newtons"], 160.0)
        self.assertEqual(payload["sequence"], 1)

    def test_twin_telemetry_rejects_replay_stale_nonfinite_and_wrong_source(self):
        module = load_bridge_module()
        now_ns = 20_000_000_000
        valid = {
            "schema": module.TWIN_TELEMETRY_SCHEMA,
            "source": module.TWIN_TELEMETRY_SOURCE,
            "sequence": 4,
            "sent_unix_ns": 1_788_000_000_000_000_000,
            "sent_monotonic_ns": now_ns - 100_000_000,
            "pose": {
                "frame_id": "sydney_regatta",
                "child_frame_id": "wamv",
                "position": {"x": 1.0, "y": 2.0, "z": 0.0},
                "orientation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
            },
            "thrust": {"left_newtons": 0.0, "right_newtons": 800.0},
        }
        cases = {
            "replay": dict(valid),
            "stale": {**valid, "sequence": 5, "sent_monotonic_ns": 1},
            "wrong-source": {**valid, "sequence": 5, "source": "other"},
            "nonfinite": {
                **valid,
                "sequence": 5,
                "thrust": {"left_newtons": float("nan"), "right_newtons": 0.0},
            },
        }
        for label, payload in cases.items():
            with self.subTest(label=label):
                with self.assertRaises(module.TwinTelemetryError):
                    module.validate_twin_telemetry_payload(
                        payload,
                        now_monotonic_ns=now_ns,
                        stale_seconds=5.0,
                        world_frame="sydney_regatta",
                        max_thrust=800.0,
                        last_sequence=4,
                    )

    def test_bound_twin_telemetry_source_stops_when_freshness_expires(self):
        module = load_bridge_module()
        relay = module.ServoCommandBridge.__new__(module.ServoCommandBridge)
        relay._running = threading.Event()
        relay._running.set()
        relay._twin_telemetry_ready = True
        relay._last_twin_telemetry_monotonic_ns = 1_000_000_000
        relay.twin_telemetry_stale_seconds = 2.0
        logger = RecordingLogger()
        relay.get_logger = lambda: logger

        with self.assertRaisesRegex(RuntimeError, "telemetry source stale"):
            relay.check_twin_telemetry_freshness(now_monotonic_ns=3_000_000_001)
        self.assertFalse(relay._running.is_set())
        self.assertIn(
            "FCU_TO_VRX_TWIN_TELEMETRY_STOP=FAIL",
            "\n".join(logger.error_messages),
        )


if __name__ == "__main__":
    unittest.main()
