#!/usr/bin/env python3
"""QoS-aware publisher-rate probe for ROS 2 topics.

`ros2 topic hz` on Jazzy has no --qos-* flag (only `ros2 topic echo` does).
Probing a BEST_EFFORT publisher with the default RELIABLE subscription
drops messages silently and reports a misleadingly low rate. This script
subscribes with a configurable QoS, counts arrivals, and prints
mean Hz + inter-arrival statistics.

Run directly (no colcon build needed):

    source ~/seal_ws/install/setup.bash
    python3 tools/rate_probe.py --topic /perception/obstacle_info \\
            --reliability best_effort --duration 30
"""
import argparse
import importlib
import statistics
import sys
import time

import rclpy
from rclpy.qos import HistoryPolicy, QoSProfile, ReliabilityPolicy


def load_msg_class(type_str):
    parts = type_str.split('/')
    if len(parts) == 3:
        pkg, subdir, name = parts
    elif len(parts) == 2:
        pkg, name = parts
        subdir = 'msg'
    else:
        raise ValueError(f'unrecognised type string: {type_str!r}')
    module = importlib.import_module(f'{pkg}.{subdir}')
    return getattr(module, name)


def discover_type(node, topic, tries=10, interval_s=0.2):
    for _ in range(tries):
        for name, types in node.get_topic_names_and_types():
            if name == topic and types:
                return types[0]
        rclpy.spin_once(node, timeout_sec=interval_s)
    return None


def parse_args():
    p = argparse.ArgumentParser(
        description='QoS-aware publisher-rate probe for ROS 2 topics.',
    )
    p.add_argument('--topic', required=True,
                   help='Topic name, e.g. /perception/obstacle_info')
    p.add_argument('--type', dest='msg_type',
                   help='Message type (e.g. sensor_msgs/msg/PointCloud2). '
                        'If omitted, discovered via rclpy.')
    p.add_argument('--reliability', choices=('reliable', 'best_effort'),
                   default='best_effort')
    p.add_argument('--depth', type=int, default=10,
                   help='QoS history depth (default 10).')
    p.add_argument('--duration', type=float, default=10.0,
                   help='Sampling window in seconds (default 10).')
    return p.parse_args()


def main():
    args = parse_args()
    rclpy.init()
    node = rclpy.create_node('rate_probe')
    try:
        type_str = args.msg_type or discover_type(node, args.topic)
        if not type_str:
            print(f'ERROR: could not determine type for {args.topic} '
                  f'(try --type sensor_msgs/msg/...)', file=sys.stderr)
            return 2
        try:
            msg_class = load_msg_class(type_str)
        except (ImportError, AttributeError, ValueError) as exc:
            print(f'ERROR: failed to import {type_str!r}: {exc}', file=sys.stderr)
            return 2

        qos = QoSProfile(
            reliability=(ReliabilityPolicy.RELIABLE
                         if args.reliability == 'reliable'
                         else ReliabilityPolicy.BEST_EFFORT),
            history=HistoryPolicy.KEEP_LAST,
            depth=args.depth,
        )

        stamps = []
        node.create_subscription(
            msg_class, args.topic,
            lambda _m: stamps.append(time.monotonic()),
            qos,
        )

        print(f'Probing {args.topic} ({type_str}) '
              f'reliability={args.reliability} depth={args.depth} '
              f'duration={args.duration}s ...', flush=True)

        start = time.monotonic()
        deadline = start + args.duration
        try:
            while rclpy.ok() and time.monotonic() < deadline:
                rclpy.spin_once(node, timeout_sec=0.05)
        except KeyboardInterrupt:
            pass

        elapsed = time.monotonic() - start
        n = len(stamps)
        if n == 0:
            print(f'received 0 messages in {elapsed:.2f}s — no publishers, '
                  f'QoS mismatch, or topic idle')
            return 1
        if n == 1:
            print(f'received 1 message in {elapsed:.2f}s — need >=2 for rate')
            return 1
        span = stamps[-1] - stamps[0]
        mean_hz = (n - 1) / span if span > 0 else float('nan')
        interval_ms = [1000.0 * (b - a) for a, b in zip(stamps, stamps[1:])]
        std_ms = statistics.stdev(interval_ms) if len(interval_ms) >= 2 else 0.0
        print(f'N={n}  elapsed={elapsed:.2f}s  mean={mean_hz:.2f} Hz  '
              f'interval mean/std={statistics.mean(interval_ms):.2f}/'
              f'{std_ms:.2f} ms')
        return 0
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    sys.exit(main())
