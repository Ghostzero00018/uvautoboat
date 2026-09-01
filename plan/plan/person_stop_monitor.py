#!/usr/bin/env python3
"""
Person-stop monitor — turns camera detections into a single hold decision.

The camera stack reports whatever its detector saw. This node owns the policy
that decides whether the boat may move: which class counts as an obstacle, how
confident a sighting has to be, how long a hold survives a dropped frame, and
whether the hold releases on its own.

Keeping that policy here rather than in the detector means it can be tested
without a camera, tuned without touching a pinned vendor file, and reasoned
about in one place.

Inputs
    /perception/detections   std_msgs/String — JSON produced by the camera host:
        {"stamp": <float seconds, optional>,
         "detections": [{"label": "person", "score": 0.91}, ...]}

Outputs
    /perception/person_alert std_msgs/String — JSON hold verdict, consumed by
        navigation and, in the opt-in physical showcase, the guarded command
        bridge and dashboard.
    /planning/emergency_stop std_msgs/Bool — the existing safety latch, raised
        while a hold is active so every consumer of that channel cuts thrust
        without needing to learn a new contract.

Design notes
    - `person` is the only class that stops the boat. Everything else is
      ignored here; LiDAR obstacle handling is unchanged and lives elsewhere.
    - The hold tracks what the camera can see, with `clear_hold_s` of
      hysteresis so a dropped frame cannot flicker it. It does NOT latch.
      Latching here would be a dead end: the planner refuses restart commands
      while the hold is up, so a hold that only an operator could clear could
      never be cleared at all.
    - Neither the simulated nor physical boat resumes merely because the
      camera hold clears. In simulation, a resume-family mission command clears
      the planner latch. In the opt-in physical showcase,
      `tools/real_fcu_rc_command_bridge.py` clears its latch only after an
      explicit `/command_ingress/emergency_reset` request and fresh evidence
      that the detector feed is clear, commands and mapped feedback are
      neutral, and the FCU remains connected in the required state. This node
      must therefore let its descriptive alert clear: that fresh-clear alert is
      one of the bridge reset prerequisites. A continuing person sighting or a
      stale detector feed keeps the hold up and blocks the reset.
    - A missing detector feed only stops the boat when `require_detection_feed`
      is set. The default is off so the simulation stack, which has no camera
      at all, behaves exactly as it did before this node existed.
"""

import json
import math

import rclpy
from rclpy.node import Node

from std_msgs.msg import Bool, String


DETECTIONS_TOPIC = '/perception/detections'
DETECTIONS_PUBLISHER_NODE = '/hailo_person_stop_bridge'
RMW_UNKNOWN_NODE_IDENTITIES = frozenset(
    {'_NODE_NAME_UNKNOWN_', '_NODE_NAMESPACE_UNKNOWN_'}
)


def detection_publisher_binding(
        endpoint_infos, expected_node_path=DETECTIONS_PUBLISHER_NODE):
    """Require one resolved detection publisher from the pinned Hailo node."""
    endpoints = tuple(endpoint_infos)
    paths = []
    for endpoint in endpoints:
        namespace = getattr(endpoint, 'node_namespace', None)
        name = getattr(endpoint, 'node_name', None)
        if not isinstance(namespace, str) or not isinstance(name, str):
            paths.append('<unresolved>')
            continue
        normalized_namespace = namespace.strip('/')
        normalized_name = name.strip('/')
        if (
            not normalized_name
            or normalized_name in RMW_UNKNOWN_NODE_IDENTITIES
            or normalized_namespace in RMW_UNKNOWN_NODE_IDENTITIES
        ):
            paths.append('<unresolved>')
            continue
        paths.append(
            f'/{normalized_namespace}/{normalized_name}'
            if normalized_namespace else f'/{normalized_name}'
        )
    resolved = tuple(sorted(paths))
    return (
        len(endpoints) == 1 and resolved == (expected_node_path,),
        resolved,
        len(endpoints),
    )


def _read_detection(entry):
    """
    Validate one detection box, returning its lowercased label and score.

    Raises ValueError on anything we cannot read with confidence. The caller
    rejects the whole frame rather than skipping the entry, because an entry we
    cannot parse might have been the person.

    Module-level and instance-free on purpose: a test stub should not have to
    reimplement or re-bind it to exercise the parsing rules.
    """
    if not isinstance(entry, dict):
        raise ValueError(f'detection entry is not an object: {entry!r}')

    if 'label' not in entry:
        raise ValueError(f'detection entry has no label: {entry!r}')
    label = entry['label']
    if not isinstance(label, str):
        raise ValueError(f'detection label is not a string: {label!r}')
    if not label.strip():
        raise ValueError('detection label is empty')

    if 'score' not in entry:
        raise ValueError(f'detection {label!r} has no score')
    raw = entry['score']
    # bool is a subclass of int, so float(True) would quietly become 1.0 —
    # a full-confidence sighting invented out of a flag.
    if isinstance(raw, bool) or not isinstance(raw, (int, float)):
        raise ValueError(f'detection {label!r} has a non-numeric score: {raw!r}')
    score = float(raw)
    if not math.isfinite(score):
        raise ValueError(f'detection {label!r} has a non-finite score: {raw!r}')
    # The contract is a confidence, compared against a threshold on the same
    # scale. A value outside [0, 1] is not a low-confidence sighting — it means
    # the producer is on a different scale, and every threshold comparison in
    # this node would then be meaningless.
    if not 0.0 <= score <= 1.0:
        raise ValueError(
            f'detection {label!r} score {score!r} is outside the [0, 1] confidence range'
        )

    return label.strip().lower(), score


class PersonStopMonitor(Node):
    """Publish a person-hold verdict derived from camera detections."""

    def __init__(self):
        super().__init__('person_stop_monitor_node')

        # Which detector class stops the boat, and how sure we must be.
        self.declare_parameter('person_class', 'person')
        self.declare_parameter('score_threshold', 0.5)
        # How long a sighting keeps the hold alive after the last frame that
        # contained it. Absorbs detector flicker; also the auto-clear delay.
        self.declare_parameter('clear_hold_s', 5.0)
        # A feed older than this is treated as absent.
        self.declare_parameter('detection_timeout_s', 2.0)
        # Stop when the detector feed is missing (real boat) or carry on
        # without it (simulation, which has no camera).
        self.declare_parameter('require_detection_feed', False)
        # Raise the shared safety latch as well as the descriptive alert.
        self.declare_parameter('latch_emergency_stop', True)
        self.declare_parameter('publish_rate_hz', 5.0)

        self.person_class = str(self.get_parameter('person_class').value)
        self.score_threshold = float(self.get_parameter('score_threshold').value)
        self.clear_hold_s = float(self.get_parameter('clear_hold_s').value)
        self.detection_timeout_s = float(self.get_parameter('detection_timeout_s').value)
        self.require_detection_feed = bool(
            self.get_parameter('require_detection_feed').value
        )
        self.latch_emergency_stop = bool(self.get_parameter('latch_emergency_stop').value)
        publish_rate = float(self.get_parameter('publish_rate_hz').value)

        # --- STATE ---
        self.person_hold = False
        self.last_person_seen_s = None
        self.last_feed_s = None
        self.last_score = 0.0
        self.last_count = 0
        self._last_published_hold = None

        self.create_subscription(
            String,
            DETECTIONS_TOPIC,
            self.detections_callback,
            10
        )

        self.pub_alert = self.create_publisher(String, '/perception/person_alert', 10)
        self.pub_emergency = self.create_publisher(Bool, '/planning/emergency_stop', 1)

        period = 1.0 / publish_rate if publish_rate > 0.0 else 0.2
        self.create_timer(period, self.publish_alert)

        self.get_logger().info("=" * 50)
        self.get_logger().info("Person Stop Monitor — camera hold policy")
        self.get_logger().info(
            f"class='{self.person_class}' score>={self.score_threshold} "
            f"clear_hold={self.clear_hold_s}s"
        )
        self.get_logger().info(
            f"require_detection_feed={self.require_detection_feed}, "
            f"latch_emergency_stop={self.latch_emergency_stop}"
        )
        self.get_logger().info("=" * 50)

    def _now_s(self):
        return self.get_clock().now().nanoseconds / 1e9

    def _detection_source_is_bound(self):
        """Reject missing, ambiguous, unresolved, or impersonating sources."""
        try:
            endpoint_infos = self.get_publishers_info_by_topic(DETECTIONS_TOPIC)
        except Exception as exc:
            self.get_logger().warn(
                f'Detection publisher query failed: {exc}',
                throttle_duration_sec=1.0,
            )
            return False
        bound, paths, count = detection_publisher_binding(endpoint_infos)
        if not bound:
            identities = ','.join(paths) if paths else '<none>'
            self.get_logger().warn(
                'Rejecting detection source: '
                f'expected={DETECTIONS_PUBLISHER_NODE} '
                f'endpoint_count={count} identities={identities}',
                throttle_duration_sec=1.0,
            )
        return bound

    def detections_callback(self, msg, now_s=None):
        """Record the newest detection frame, keeping only the stopping class."""
        if now_s is None:
            now_s = self._now_s()

        # The physical path may only accept clear-water evidence from the one
        # generated Hailo publisher. Check on every frame so a second publisher
        # appearing after readiness cannot impersonate a live detector or mask
        # loss of the real feed. Simulation keeps its historical optional-feed
        # behaviour and performs no graph query.
        if self.require_detection_feed and not self._detection_source_is_bound():
            return

        try:
            data = json.loads(msg.data)
            if not isinstance(data, dict):
                raise ValueError('detections payload must be a JSON object')
            # The field must be PRESENT, not merely defaultable. An empty
            # object carries no evidence about the water, and treating it as an
            # empty frame would both drop a hold and make a dead detector look
            # alive to the require_detection_feed watchdog.
            if 'detections' not in data:
                raise ValueError("payload is missing the 'detections' field")
            detections = data['detections']
            if not isinstance(detections, list):
                raise ValueError('detections must be a list')
        except (json.JSONDecodeError, TypeError, ValueError, AttributeError) as e:
            # Fail closed: an unreadable frame is not evidence the water is
            # clear, so it must never advance the feed clock or drop a hold.
            self.get_logger().warn(f"Invalid detections payload: {e}")
            return

        # A detector that reports an unreadable box must not be able to kill
        # this node: an exception escaping the callback would end the process,
        # and with it every future person alert — a silent fail-open on the one
        # node that implements the stopping policy.
        #
        # An unreadable score on a person-class box rejects the WHOLE frame.
        # NaN in particular is not an exception and not a small score: every
        # comparison against it is false, so it would silently read as "no
        # person" while still advancing the freshness clock, making a broken
        # detector look like a clear waterway. We cannot tell whether that box
        # was a person, so the frame carries no usable evidence.
        # Every entry is validated, not just the ones that look like people.
        # A frame we cannot fully read is not evidence of anything: skipping a
        # malformed entry would silently downgrade "I could not tell" into
        # "no person here", on a feed that still looked fresh.
        wanted = self.person_class.lower()
        scores = []
        for entry in detections:
            try:
                label, score = _read_detection(entry)
            except ValueError as e:
                self.get_logger().warn(f"Rejecting detection frame: {e}")
                return
            if label != wanted:
                continue
            if score >= self.score_threshold:
                scores.append(score)

        self.last_feed_s = now_s
        self.last_count = len(scores)
        if scores:
            self.last_score = max(scores)
            self.last_person_seen_s = now_s

    def evaluate(self, now_s):
        """Return the current hold verdict and update the latch."""
        person_recent = (
            self.last_person_seen_s is not None
            and (now_s - self.last_person_seen_s) <= self.clear_hold_s
        )
        feed_stale = (
            self.last_feed_s is None
            or (now_s - self.last_feed_s) > self.detection_timeout_s
        )
        feed_lost = self.require_detection_feed and feed_stale

        # A pure function of what the camera can currently see. The hold does
        # not latch — see the module docstring: the /planning/emergency_stop
        # latch is what requires an operator to act, and a hold that latched
        # here could never be cleared, because the planner refuses the very
        # resume command that would clear it.
        self.person_hold = bool(person_recent or feed_lost)

        if person_recent:
            reason = 'person_detected'
        elif feed_lost:
            reason = 'detector_feed_lost'
        else:
            reason = ''

        return {
            'person_detected': self.person_hold,
            # Whether a valid detection frame arrived recently. Consumers need
            # this to tell "the camera says the water is clear" apart from
            # "nothing has told us anything" — the two look identical in
            # person_detected, and only one of them justifies a green light.
            'feed_fresh': not feed_stale,
            'reason': reason,
            'score': round(self.last_score, 3) if self.last_count else 0.0,
            'count': int(self.last_count),
            'stamp': round(now_s, 3),
        }

    def publish_alert(self):
        """Publish the verdict, and hold the shared safety latch while stopped."""
        verdict = self.evaluate(self._now_s())

        msg = String()
        msg.data = json.dumps(verdict)
        self.pub_alert.publish(msg)

        if verdict['person_detected'] and self.latch_emergency_stop:
            # Republished every tick rather than once on the rising edge: the
            # consumers subscribe with volatile QoS, so a late-joining bridge
            # would otherwise never learn the boat is being held.
            self.pub_emergency.publish(Bool(data=True))

        if verdict['person_detected'] != self._last_published_hold:
            self._last_published_hold = verdict['person_detected']
            if verdict['person_detected']:
                self.get_logger().warn(
                    f"🚸 PERSON HOLD ACTIVE ({verdict['reason']}, "
                    f"count={verdict['count']}, score={verdict['score']})"
                )
            else:
                self.get_logger().info("✅ Person hold cleared.")


def main(args=None):
    """Spin the person-stop monitor."""
    rclpy.init(args=args)
    node = PersonStopMonitor()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
