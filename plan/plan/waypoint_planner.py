#!/usr/bin/env python3
"""
Waypoint Planner - GPS Waypoint Navigation Planning

Module: Waypoint Planner
Role:   Generates waypoints, manages mission state, and publishes navigation targets.
See also: LiDAR Perception (Perception) and Heading Controller (Control)

Part of the modular AutoBoat architecture.
Generates lawnmower pattern waypoints, publishes navigation path.

Features:
- Lawnmower pattern generation for systematic coverage
- State machine (8 states):
    INIT -> WAITING_CONFIRM -> READY -> DRIVING -> FINISHED (happy path)
    PAUSED (via stop/resume), JOYSTICK (manual override), EMERGENCY_STOP (latched)
- Multi-level obstacle handling:
    (a) opportunistic side detour if lateral gap >= 8 m (planner-side, no waypoint insertion)
    (b) auto-detour waypoint insertion after 30 s blocked (14 m lateral offset)
    (c) A* reroute or waypoint skip after 45 s blocked
- Runtime A* path planning (default on): 3 m grid, 12 m safety margin, 20k max expansions
- Optional Hybrid Mode (astar_hybrid_mode=false by default): pre-plan full path once vs tick-by-tick replan
- Return home mode with detour insertion

Topics:
    Subscribes:
        /wamv/sensors/gps/gps/fix (NavSatFix) - GPS position
        /perception/obstacle_info (String) - obstacle detection for skip / detour logic
        /planning/mission_command (String) - dashboard / CLI commands (start, resume, confirm, go_home, reset, joystick)
        /planning/set_config (String) - runtime parameter updates from dashboard
        /planning/emergency_stop (Bool, latched RELIABLE depth=1) - dedicated E-Stop channel
        /control/replan_request (String) - reroute trigger from controller when blocked

    Publishes:
        /planning/waypoints (String) - JSON list of waypoints
        /planning/current_target (String) - JSON current target waypoint
        /planning/mission_status (String) - JSON mission state
        /planning/config (String) - runtime parameter snapshot
        /planning/param_ranges (String) - JSON parameter validation ranges for dashboard HTML min/max sync

    Services:
        /planning/stop_mission (std_srvs/Trigger) - ACK-based stop (replaces retry-over-topic)
        /planning/generate_waypoints (std_srvs/Trigger) - ACK-based lawnmower generation
"""

import rclpy
from rclpy.node import Node
import math
import json
import time
import heapq
from pathlib import Path

from sensor_msgs.msg import NavSatFix
from std_msgs.msg import String, Bool
from std_srvs.srv import Trigger


class AStarSolver:
    """Lightweight 8-connected A* for local detours."""
    def __init__(self, resolution=3.0, safety_margin=10.0, max_expansions=20000):
        self.resolution = resolution
        self.safety_margin = safety_margin
        self.max_expansions = max_expansions

    def world_to_grid(self, x, y, min_x, min_y):
        gx = int((x - min_x) / self.resolution)
        gy = int((y - min_y) / self.resolution)
        return gx, gy

    def grid_to_world(self, gx, gy, min_x, min_y):
        wx = (gx * self.resolution) + min_x + (self.resolution / 2.0)
        wy = (gy * self.resolution) + min_y + (self.resolution / 2.0)
        return wx, wy

    def _add_blocked_disc(self, blocked, center, radius_steps):
        cx, cy = center
        for dx in range(-radius_steps, radius_steps + 1):
            for dy in range(-radius_steps, radius_steps + 1):
                if dx * dx + dy * dy <= radius_steps * radius_steps:
                    blocked.add((cx + dx, cy + dy))

    def plan(self, start, goal, obstacles, inflate_radius):
        """
        Plan from start->goal avoiding circular obstacles.
        obstacles: list of (x, y)
        inflate_radius: extra meters to inflate obstacles
        """
        sx, sy = start
        gx, gy = goal

        xs = [sx, gx] + [o[0] for o in obstacles]
        ys = [sy, gy] + [o[1] for o in obstacles]

        if not xs or not ys:
            return None

        pad = max(self.safety_margin * 2.0, inflate_radius * 2.0, 30.0)
        min_x = min(xs) - pad
        max_x = max(xs) + pad
        min_y = min(ys) - pad
        max_y = max(ys) + pad

        grid_w = int((max_x - min_x) / self.resolution) + 1
        grid_h = int((max_y - min_y) / self.resolution) + 1
        if grid_w <= 0 or grid_h <= 0:
            return None

        start_node = self.world_to_grid(sx, sy, min_x, min_y)
        goal_node = self.world_to_grid(gx, gy, min_x, min_y)

        blocked = set()
        # Inflate obstacles
        radius_steps = int((self.safety_margin + inflate_radius) / self.resolution)
        for ox, oy in obstacles:
            ogx, ogy = self.world_to_grid(ox, oy, min_x, min_y)
            self._add_blocked_disc(blocked, (ogx, ogy), radius_steps)

        # If start/goal blocked, fail fast
        if start_node in blocked or goal_node in blocked:
            return None

        def neighbors(node):
            x, y = node
            dirs = [(0, 1), (1, 0), (0, -1), (-1, 0),
                    (1, 1), (1, -1), (-1, 1), (-1, -1)]
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < grid_w and 0 <= ny < grid_h and (nx, ny) not in blocked:
                    cost = 1.414 if dx != 0 and dy != 0 else 1.0
                    yield (nx, ny), cost

        open_set = []
        heapq.heappush(open_set, (0.0, start_node))
        came_from = {}
        g_score = {start_node: 0.0}
        expansions = 0

        while open_set and expansions < self.max_expansions:
            _, current = heapq.heappop(open_set)
            expansions += 1

            if current == goal_node:
                # Reconstruct path
                path = []
                n = current
                while n in came_from:
                    wx, wy = self.grid_to_world(n[0], n[1], min_x, min_y)
                    path.append((wx, wy))
                    n = came_from[n]
                path.reverse()
                return path

            for nb, move_cost in neighbors(current):
                tentative = g_score[current] + move_cost
                if tentative < g_score.get(nb, float('inf')):
                    came_from[nb] = current
                    g_score[nb] = tentative
                    hx = nb[0] - goal_node[0]
                    hy = nb[1] - goal_node[1]
                    h = math.hypot(hx, hy)
                    heapq.heappush(open_set, (tentative + h, nb))

        return None


class WaypointPlanner(Node):
    """
    Waypoint Planner - Trajectory planning system
    (Named after the first artificial satellite)
    """

    # Single source of truth for parameter validation ranges.
    # Published on /planning/param_ranges so the dashboard can sync HTML min/max.
    PARAM_RANGES = {
        'lanes': (1, 100),
        'scan_length': (1.0, 500.0),
        'scan_width': (1.0, 500.0),
        'waypoint_tolerance': (0.5, 50.0),
        'astar_resolution': (0.5, 20.0),
        'astar_safety_margin': (1.0, 50.0),
        'astar_max_expansions': (100, 100000),
    }

    def __init__(self):
        super().__init__('waypoint_planner_node')

        # --- PARAMETERS ---
        self.declare_parameter('scan_length', 15.0)
        self.declare_parameter('scan_width', 30.0)
        self.declare_parameter('lanes', 10)
        self.declare_parameter('waypoint_tolerance', 3.5)
        self.declare_parameter('waypoint_skip_timeout', 45.0)  # Skip waypoint if blocked for this long
        # World metadata (for dashboards)
        self.declare_parameter('world_name', 'unknown')

        self.declare_parameter('plan_avoid_margin', 5.0)  # Planning detour margin
        self.declare_parameter('hull_radius', 1.5)  # Boat hull radius for clearance

        # Get parameters
        self.scan_length = self.get_parameter('scan_length').value
        self.scan_width = self.get_parameter('scan_width').value
        self.lanes = self.get_parameter('lanes').value
        self.waypoint_tolerance = self.get_parameter('waypoint_tolerance').value
        self.waypoint_skip_timeout = self.get_parameter('waypoint_skip_timeout').value
        self.world_name = str(self.get_parameter('world_name').value)

        self.plan_avoid_margin = float(self.get_parameter('plan_avoid_margin').value)
        self.hull_radius = float(self.get_parameter('hull_radius').value)

        # v2.2: Optional A* detour planner (ported from Atlantis)
        self.declare_parameter('astar_enabled', False)
        self.declare_parameter('astar_hybrid_mode', False)  # Pre-plan A* between lawnmower waypoints
        self.declare_parameter('astar_resolution', 3.0)
        self.declare_parameter('astar_safety_margin', 12.0)
        self.declare_parameter('astar_max_expansions', 20000)
        self.astar_enabled = bool(self.get_parameter('astar_enabled').value)
        self.astar_hybrid_mode = bool(self.get_parameter('astar_hybrid_mode').value)
        self.astar = AStarSolver(
            resolution=float(self.get_parameter('astar_resolution').value),
            safety_margin=float(self.get_parameter('astar_safety_margin').value),
            max_expansions=int(self.get_parameter('astar_max_expansions').value),
        )

        # --- STATE ---
        self.start_gps = None
        self.current_gps = None
        self.waypoints = []
        self.current_wp_index = 0
        self.state = "INIT"  # INIT -> WAITING_CONFIRM -> DRIVING -> FINISHED
        self.mission_start_time = None
        self.mission_armed = False  # For manual start mode

        # GPS initialization timeout (for worlds with slow GPS like DEFAULT)
        self.gps_init_time = None  # When node started waiting for GPS
        self.gps_timeout = 30.0  # Give GPS 30 seconds to initialize
        self.gps_timeout_warned = False  # Flag to warn once about GPS timeout

        # Waypoint skip tracking (for obstacles blocking waypoint)
        self.waypoint_start_time = None  # When we started trying to reach current waypoint
        self.obstacle_detected = False
        self.obstacle_clusters = []  # Latest perception clusters for A* detours
        self.front_clear = float('inf')
        self.left_clear = float('inf')
        self.right_clear = float('inf')
        self.min_obstacle_distance = float('inf')
        self.obstacle_blocking_time = 0.0  # Cumulative time obstacle detected near waypoint
        self.blocked_reason = ""  # Human-readable reason for blockage
        self.declare_parameter('max_block_time', 30.0)  # Max seconds to wait before auto-detour/skip
        self.max_block_time = float(self.get_parameter('max_block_time').value)
        # Flipped by config_callback on first successful /planning/set_config.
        # Health check reads this to distinguish baseline-vs-user-tuned values.
        self.declare_parameter('config_tuned', False)
        self.last_obstacle_check = None
        self.go_home_mode = False  # Track if we're in return-home mode
        self.home_detour_timeout = 15.0  # Insert detour after this many seconds in home mode
        self.detour_waypoint_inserted = False
        self.detour_count = 0  # Detours inserted for current original waypoint
        self.max_detours_per_waypoint = 3  # Cap: after this many, skip the waypoint
        self.detour_cooldown = 5.0  # Minimum seconds between detour insertions
        self.last_detour_time = 0.0  # Timestamp of last detour insertion
        self.detour_distance = 14.0  # Lateral distance for detour waypoints
        self.detour_forward_offset = 10.0  # Forward offset when inserting side detour
        self.detour_start_time = None
        self.min_obstacle_distance_for_skip = 15.0  # Skip waypoints within this distance of obstacles

        # --- SUBSCRIBERS ---
        self.create_subscription(
            NavSatFix,
            '/wamv/sensors/gps/gps/fix',
            self.gps_callback,
            10
        )
        
        # Mission command subscriber for CLI/dashboard control
        self.create_subscription(
            String,
            '/planning/mission_command',
            self.mission_command_callback,
            10
        )
        
        # Config subscriber for runtime parameter changes
        self.create_subscription(
            String,
            '/planning/set_config',
            self.config_callback,
            10
        )
        
        # Obstacle info subscriber for waypoint skip logic
        self.create_subscription(
            String,
            '/perception/obstacle_info',
            self.obstacle_callback,
            10
        )
        
        # Detour request from heading controller
        self.create_subscription(
            String,
            '/planning/detour_request',
            self.detour_request_callback,
            10
        )

        # Replan request from heading controller (when path is blocked)
        self.create_subscription(
            String,
            '/control/replan_request',
            self.replan_request_callback,
            10
        )

        # Skip waypoint request from heading controller (after multiple stuck attempts)
        self.create_subscription(
            String,
            '/planning/skip_waypoint',
            self.skip_waypoint_callback,
            10
        )

        # Dedicated safety-critical E-Stop channel. RELIABLE QoS replaces the
        # retry loops previously used on /planning/mission_command for e-stop;
        # DDS guarantees delivery to any running subscriber without the caller
        # needing to fire duplicates.
        self.create_subscription(
            Bool,
            '/planning/emergency_stop',
            self.emergency_stop_latched_callback,
            1
        )

        # --- SERVICES ---
        # Replace retry/delay bandages on the client side with request/response ACK.
        # stop_mission: CLI previously sent 3× with sleeps; dashboard sent 2× 200 ms apart.
        # generate_waypoints: dashboard previously used 500 ms setTimeout after config publish.
        self.srv_stop = self.create_service(Trigger, '/planning/stop_mission', self._srv_stop_mission)
        self.srv_generate = self.create_service(Trigger, '/planning/generate_waypoints', self._srv_generate_waypoints)

        # --- PUBLISHERS ---
        self.pub_waypoints = self.create_publisher(String, '/planning/waypoints', 10)
        self.pub_current_target = self.create_publisher(String, '/planning/current_target', 10)
        self.pub_mission_status = self.create_publisher(String, '/planning/mission_status', 10)
        self.pub_config = self.create_publisher(String, '/planning/config', 10)
        self.pub_param_ranges = self.create_publisher(String, '/planning/param_ranges', 10)

        # Control loop at 10Hz
        self.create_timer(0.1, self.planning_loop)

        # Republish param ranges every 5s so late-subscribing dashboards always get them
        self.create_timer(5.0, self._publish_param_ranges)
        self._publish_param_ranges()  # initial publish on startup
        
        # Publish config at 1Hz
        self.create_timer(1.0, self.publish_config)
        
        # Publish mission status at 5Hz (always, not just during DRIVING)
        self.create_timer(0.2, self.publish_mission_status_timer)

        self.get_logger().info("=" * 50)
        self.get_logger().info("Waypoint Planner v2.2 - Trajectory Planning System")
        self.get_logger().info("=" * 50)
        self.get_logger().info(f"Zone de balayage | Scan Area: {self.scan_length}m × {self.scan_width * self.lanes}m")
        self.get_logger().info(f"Lanes: {self.lanes}, Width: {self.scan_width}m")
        if self.astar_hybrid_mode:
            self.get_logger().info(f"A* Hybrid Mode: ENABLED (pre-plan routes between waypoints)")
        elif self.astar_enabled:
            self.get_logger().info(f"A* Runtime Detours: ENABLED (res={self.astar.resolution}m, margin={self.astar.safety_margin}m)")
        else:
            self.get_logger().info("A* Detours: Disabled")
        self.get_logger().info("Waiting for GPS signal...")
        self.get_logger().info("Commands: ros2 run plan autoboat_cli --help")
        self.get_logger().info("=" * 50)

        # Per-topic last-warn timestamps for _log_bad_json throttle.
        self._bad_json_last_warn: dict = {}

    def _log_bad_json(self, topic: str, exc: Exception, throttle_sec: float = 5.0) -> None:
        """Warn once per `throttle_sec` when a subscribed topic delivers unparseable JSON."""
        now = time.monotonic()
        last = self._bad_json_last_warn.get(topic, 0.0)
        if now - last >= throttle_sec:
            self.get_logger().warn(f"Failed to parse {topic}: {exc}")
            self._bad_json_last_warn[topic] = now

    def gps_callback(self, msg):
        """Handle GPS updates"""
        self.current_gps = (msg.latitude, msg.longitude)

        # First GPS fix - store start position but wait for mission command
        if self.start_gps is None:
            self.start_gps = (msg.latitude, msg.longitude)
            self.get_logger().info(f"Base Point: {self.start_gps[0]:.6f}, {self.start_gps[1]:.6f}")
            self.get_logger().info("GPS acquired - run 'ros2 run plan autoboat_cli generate' to create waypoints")
            
    def _srv_stop_mission(self, request, response):
        """Service-based stop — ACK replaces the old retry loops."""
        prev_state = self.state
        self.state = "PAUSED"
        self.mission_armed = False
        self.get_logger().info(f"🛑 MISSION STOPPED via service (was {prev_state} → now PAUSED)")
        self.publish_mission_status_timer()
        response.success = True
        response.message = f"stopped (was {prev_state})"
        return response

    def _srv_generate_waypoints(self, request, response):
        """Service-based generate — ACK replaces dashboard's 500 ms setTimeout."""
        if self.start_gps is None:
            response.success = False
            response.message = "GPS not available yet"
            self.get_logger().warn("Generate rejected: GPS not available")
            return response
        self.generate_lawnmower_path()
        self.state = "WAITING_CONFIRM"
        self.get_logger().info(f"Waypoints generated via service: {len(self.waypoints)} points")
        self.publish_waypoints()
        self.publish_mission_status_timer()
        response.success = True
        response.message = f"generated {len(self.waypoints)} waypoints"
        return response

    def emergency_stop_latched_callback(self, msg):
        """Safety-critical E-Stop entry point. Bool(data=True) latches EMERGENCY_STOP."""
        if not msg.data:
            return
        prev_state = self.state
        self.state = "EMERGENCY_STOP"
        self.mission_armed = False
        self.get_logger().error(f"🚨 EMERGENCY STOP via latched topic (was {prev_state} → now EMERGENCY_STOP)")
        self.publish_mission_status_timer()

    def mission_command_callback(self, msg):
        """Handle mission commands from CLI/dashboard"""
        try:
            cmd = json.loads(msg.data)
            command = cmd.get('command', '')
            
            self.get_logger().info(f"MISSION COMMAND: {command}")
            
            if command == 'confirm_waypoints':
                if self.waypoints:
                    self.state = "READY"
                    self.get_logger().info("Waypoints confirmed - ready to start")
                    self.publish_mission_status_timer()
                    
            elif command == 'start_mission':
                if self.waypoints and self.state in ["READY", "WAITING_CONFIRM", "PAUSED", "FINISHED"]:
                    if self.state == "FINISHED":
                        self.current_wp_index = 0
                        # CRITICAL: Reset all home-mode and finish-related state when restarting from FINISHED
                        self.go_home_mode = False  # Clear home mode flag
                        self.detour_waypoint_inserted = False
                        self.detour_count = 0
                    self.state = "DRIVING"
                    self.mission_armed = True
                    self.mission_start_time = self.get_clock().now()
                    self.obstacle_blocking_time = 0.0
                    self.detour_waypoint_inserted = False
                    self.detour_count = 0
                    self.get_logger().info("🚀 MISSION STARTED!")
                    # Force immediate publishes so controller responds instantly
                    self.publish_mission_status_timer()
                    self._publish_current_target_immediate()
                else:
                    self.get_logger().warn(f"Cannot start - state={self.state}, waypoints={len(self.waypoints)}")
                    
            elif command == 'resume_mission':
                resumable_states = {"PAUSED", "JOYSTICK", "EMERGENCY_STOP", "WAITING_CONFIRM", "READY"}
                if self.waypoints and self.state in resumable_states:
                    self.state = "DRIVING"
                    self.mission_armed = True
                    # Reset obstacle blocking time for fresh start
                    self.obstacle_blocking_time = 0.0
                    self.detour_waypoint_inserted = False
                    self.detour_count = 0
                    self.get_logger().info(f"▶️ MISSION RESUMED from {self.state}")
                    # Force immediate status publish so controller resets and starts
                    self.publish_mission_status_timer()
                    # Force immediate target publish so controller has target right away
                    self._publish_current_target_immediate()
                else:
                    self.get_logger().warn(f"Cannot resume - state={self.state}, waypoints={len(self.waypoints)}")
                    
            elif command == 'cancel_waypoints':
                # Cancel waypoints, go back to init
                self.waypoints = []
                self.current_wp_index = 0
                self.state = "INIT"
                self.mission_armed = False
                self.go_home_mode = False
                self.get_logger().info("Waypoints CANCELLED")
                self.publish_mission_status_timer()
                    
            elif command == 'reset_mission':
                self.waypoints = []
                self.current_wp_index = 0
                self.state = "INIT"
                self.mission_armed = False
                self.go_home_mode = False
                self.obstacle_blocking_time = 0.0
                self.get_logger().info("🔄 MISSION RESET")
                self.publish_mission_status_timer()
                
            elif command == 'joystick_enable':
                # Enable joystick override mode
                self.state = "JOYSTICK"
                self.mission_armed = False
                self.get_logger().info("JOYSTICK MODE ENABLED")
                self.publish_mission_status_timer()
                
            elif command == 'joystick_disable':
                # Disable joystick mode
                # If we have waypoints, drop to PAUSED so RESUME works immediately; otherwise reset to INIT
                self.state = "PAUSED" if self.waypoints else "INIT"
                self.get_logger().info("JOYSTICK MODE DISABLED")
                self.publish_mission_status_timer()
            
            elif command == 'go_home':
                # Navigate back to spawn point (one-click return home)
                if self.start_gps is not None:
                    # Get current position and home position
                    if self.current_gps:
                        curr_x, curr_y = self.latlon_to_meters(self.current_gps[0], self.current_gps[1])
                    else:
                        curr_x, curr_y = 0.0, 0.0
                    home_x, home_y = self.latlon_to_meters(self.start_gps[0], self.start_gps[1])

                    self.waypoints = [(home_x, home_y)]
                    self.current_wp_index = 0
                    
                    # CRITICAL FIX: If already DRIVING, need to force state transition
                    # to reset controller's escape state. Set to READY first, then DRIVING.
                    if self.state == "DRIVING":
                        # Temporarily transition through READY to reset heading controller
                        self.state = "READY"
                        self.mission_armed = False
                        self.publish_mission_status_timer()  # Publish READY state
                        self.get_logger().info("🏠 GOING HOME! (Transitioning from DRIVING)")
                    else:
                        self.get_logger().info("🏠 GOING HOME!")
                    
                    # Now transition to DRIVING
                    self.state = "DRIVING"
                    self.mission_armed = True
                    self.mission_start_time = self.get_clock().now()
                    self.go_home_mode = True  # Enable home mode for smarter obstacle handling
                    self.obstacle_blocking_time = 0.0
                    self.detour_waypoint_inserted = False
                    self.detour_count = 0
                    self.get_logger().info(f"   Destination: {self.start_gps[0]:.6f}, {self.start_gps[1]:.6f}")
                    self.get_logger().info(f"   Position locale: ({home_x:.1f}m, {home_y:.1f}m)")
                    # Publish updated waypoints
                    self.publish_waypoints()
                    # Force immediate status publish so controller resets escape state
                    self.publish_mission_status_timer()
                    # Force immediate target publish so controller has target right away
                    self._publish_current_target_immediate()
                else:
                    self.get_logger().warn("Cannot go home - no spawn point recorded")
                
        except Exception as e:
            self.get_logger().error(f"Mission command error: {e}")
    
    def obstacle_callback(self, msg):
        """Track obstacle detection for waypoint skip logic"""
        try:
            data = json.loads(msg.data)
            self.obstacle_detected = data.get('obstacle_detected', False)
            self.min_obstacle_distance = float(data.get('min_distance', float('inf')))
            self.front_clear = float(data.get('front_clear', float('inf')))
            self.left_clear = float(data.get('left_clear', float('inf')))
            self.right_clear = float(data.get('right_clear', float('inf')))
            # Capture clusters for A* detours
            clusters = data.get('clusters', [])
            self.obstacle_clusters = [(c.get('x', 0.0), c.get('y', 0.0)) for c in clusters if 'x' in c and 'y' in c]
            # Note: detour_waypoint_inserted is only reset on waypoint reach,
            # advance, or detour timeout — NOT on momentary obstacle clears,
            # which caused a feedback loop inserting 300+ detour waypoints.
        except Exception as e:
            self._log_bad_json('/perception/obstacle_info', e)
    
    def detour_request_callback(self, msg):
        """Handle detour waypoint request from heading controller"""
        try:
            data = json.loads(msg.data)
            # Support both 'x'/'y' and 'detour_x'/'detour_y' keys
            detour_x = data.get('detour_x') or data.get('x')
            detour_y = data.get('detour_y') or data.get('y')
            
            if detour_x is not None and detour_y is not None and self.state == "DRIVING":
                # Insert detour waypoint before current target
                detour_wp = (detour_x, detour_y)
                self.waypoints.insert(self.current_wp_index, detour_wp)
                self.get_logger().info(f"📍 Detour waypoint inserted at ({detour_x:.1f}, {detour_y:.1f})")
                self.publish_waypoints()
        except Exception as e:
            self.get_logger().warn(f"Detour request error: {e}")

    def replan_request_callback(self, msg):
        """Handle replan request from heading controller when path is blocked"""
        try:
            data = json.loads(msg.data)
            reason = data.get('reason', 'unknown')

            if self.state == "DRIVING" and self.astar_enabled:
                self.get_logger().warn(f"🔄 Replan requested by controller: {reason}")
                # Trigger A* replan on next planning cycle
                # This will be handled by the A* detour logic in planning_loop
                self.get_logger().info("A* detour planning will attempt alternative route")
            else:
                self.get_logger().warn(f"Replan request ignored - A* disabled or not DRIVING (state={self.state})")
        except Exception as e:
            self.get_logger().warn(f"Replan request error: {e}")

    def skip_waypoint_callback(self, msg):
        """Handle skip waypoint request from heading controller after multiple stuck attempts"""
        try:
            data = json.loads(msg.data)
            reason = data.get('reason', 'stuck_multiple_times')

            if self.state == "DRIVING" and self.current_wp_index < len(self.waypoints):
                current_wp = self.waypoints[self.current_wp_index]
                self.get_logger().warn(
                    f"⏭️ Controller requested skip waypoint {self.current_wp_index + 1}/{len(self.waypoints)} "
                    f"at ({current_wp[0]:.1f}, {current_wp[1]:.1f}) - reason: {reason}"
                )
                # Advance to next waypoint
                self.advance_to_next_waypoint()
                self.publish_waypoints()
            else:
                self.get_logger().warn(f"Skip waypoint ignored - not DRIVING or at end (state={self.state})")
        except Exception as e:
            self.get_logger().warn(f"Skip waypoint error: {e}")

    def _validate(self, name, value):
        """Validate against PARAM_RANGES[name]. Log + reject if out of bounds."""
        if name not in self.PARAM_RANGES:
            return True  # no range defined, accept
        lo, hi = self.PARAM_RANGES[name]
        if lo <= value <= hi:
            return True
        self.get_logger().warn(f"Rejected {name}={value} (valid range: {lo}–{hi})")
        return False

    def _publish_json(self, publisher, payload, label):
        """Safe JSON publish: refuses to emit NaN/Inf so dashboard parse can't
        silently fail on malformed wire data."""
        try:
            encoded = json.dumps(payload, allow_nan=False)
        except (TypeError, ValueError) as e:
            self.get_logger().error(
                f"Refused to publish malformed JSON ({label}): {e}",
                throttle_duration_sec=1.0,
            )
            return
        msg = String()
        msg.data = encoded
        publisher.publish(msg)

    def _publish_param_ranges(self):
        """Publish validation ranges so the dashboard can sync HTML min/max."""
        self._publish_json(
            self.pub_param_ranges,
            {k: [lo, hi] for k, (lo, hi) in self.PARAM_RANGES.items()},
            'param_ranges',
        )

    def config_callback(self, msg):
        """Handle runtime configuration changes"""
        try:
            config = json.loads(msg.data)
            regenerate = False

            if 'lanes' in config:
                v = int(config['lanes'])
                if self._validate('lanes', v):
                    self.lanes = v
                    regenerate = True
            if 'scan_length' in config:
                v = float(config['scan_length'])
                if self._validate('scan_length', v):
                    self.scan_length = v
                    regenerate = True
            if 'scan_width' in config:
                v = float(config['scan_width'])
                if self._validate('scan_width', v):
                    self.scan_width = v
                    regenerate = True

            # Waypoint approach parameters
            if 'waypoint_tolerance' in config:
                v = float(config['waypoint_tolerance'])
                if self._validate('waypoint_tolerance', v):
                    self.waypoint_tolerance = v
                    self.get_logger().info(f"Waypoint tolerance updated: {self.waypoint_tolerance}m")

            # v2.2: A* detour planning runtime config
            if 'astar_enabled' in config:
                self.astar_enabled = bool(config['astar_enabled'])
                self.get_logger().info(f"A* runtime detours: {'ENABLED' if self.astar_enabled else 'DISABLED'}")
            if 'astar_hybrid_mode' in config:
                self.astar_hybrid_mode = bool(config['astar_hybrid_mode'])
                self.get_logger().info(f"A* hybrid mode: {'ENABLED' if self.astar_hybrid_mode else 'DISABLED'}")
            if 'astar_resolution' in config:
                v = float(config['astar_resolution'])
                if self._validate('astar_resolution', v):
                    self.astar.resolution = v
            if 'astar_safety_margin' in config:
                v = float(config['astar_safety_margin'])
                if self._validate('astar_safety_margin', v):
                    self.astar.safety_margin = v
            if 'astar_max_expansions' in config:
                v = int(config['astar_max_expansions'])
                if self._validate('astar_max_expansions', v):
                    self.astar.max_expansions = v

            # Sync updated values to ROS parameter server
            params_to_sync = []
            for key in config:
                if hasattr(self, key):
                    params_to_sync.append(
                        rclpy.parameter.Parameter(key, value=getattr(self, key))
                    )
            # A* solver attrs live on self.astar, so the hasattr loop misses them
            for cfg_key, solver_attr in (
                ('astar_resolution', 'resolution'),
                ('astar_safety_margin', 'safety_margin'),
                ('astar_max_expansions', 'max_expansions'),
            ):
                if cfg_key in config:
                    params_to_sync.append(
                        rclpy.parameter.Parameter(cfg_key, value=getattr(self.astar, solver_attr))
                    )
            if params_to_sync:
                self.set_parameters(params_to_sync)

            self.get_logger().info(f"Config updated: lanes={self.lanes}, length={self.scan_length}, width={self.scan_width}")
            if not self.get_parameter('config_tuned').value:
                self.set_parameters([rclpy.parameter.Parameter('config_tuned', value=True)])

        except Exception as e:
            self.get_logger().error(f"Config parse error: {e}")
            
    def publish_config(self):
        """Publish current configuration"""
        config = {
            'lanes': self.lanes,
            'scan_length': self.scan_length,
            'scan_width': self.scan_width,
            'waypoint_tolerance': self.waypoint_tolerance,
            'state': self.state,
            'waypoint_count': len(self.waypoints),
            'current_wp': self.current_wp_index,
            'gps_ready': self.start_gps is not None,
            'start_lat': self.start_gps[0] if self.start_gps else None,
            'start_lon': self.start_gps[1] if self.start_gps else None,
            'mission_armed': self.mission_armed,
            'joystick_override': self.state == "JOYSTICK",
            # v2.2: A* detour planning status
            'astar_enabled': self.astar_enabled,
            'astar_hybrid_mode': self.astar_hybrid_mode,
            'astar_resolution': self.astar.resolution,
            'astar_safety_margin': self.astar.safety_margin,
            'astar_max_expansions': self.astar.max_expansions,
            'world_name': self.world_name
        }
        self._publish_json(self.pub_config, config, 'config')

    def latlon_to_meters(self, lat, lon):
        """Convert GPS coordinates to local meters"""
        if self.start_gps is None:
            return 0.0, 0.0
            
        R = 6371000.0  # Earth radius in meters
        d_lat = math.radians(lat - self.start_gps[0])
        d_lon = math.radians(lon - self.start_gps[1])
        lat0 = math.radians(self.start_gps[0])

        x = d_lat * R
        y = d_lon * R * math.cos(lat0)
        return y, x  # (East, North)

    def generate_lawnmower_path(self):
        """Generate zigzag lawn mower pattern waypoints"""
        # First generate main lawnmower waypoints
        main_waypoints = []

        for i in range(self.lanes):
            if i % 2 == 0:
                x_end = self.scan_length
            else:
                x_end = 0.0

            y_pos = i * self.scan_width
            main_waypoints.append((x_end, y_pos))

            if i < self.lanes - 1:
                next_y = (i + 1) * self.scan_width
                main_waypoints.append((x_end, next_y))

        # If hybrid mode enabled, use A* to find routes between main waypoints
        if self.astar_hybrid_mode and self.start_gps is not None:
            self.get_logger().info(f"🧠 Hybrid Mode: Planning A* routes between {len(main_waypoints)} main waypoints...")
            self.waypoints = self._generate_hybrid_waypoints(main_waypoints)
            self.get_logger().info(f"✓ Hybrid generation: {len(main_waypoints)} main → {len(self.waypoints)} total waypoints")
        else:
            self.waypoints = main_waypoints
            self.get_logger().info(f"Generated {len(self.waypoints)} waypoints (simple mode)")

        # Publish waypoints
        self.publish_waypoints()

    def _generate_hybrid_waypoints(self, main_waypoints):
        """
        Generate hybrid waypoints using A* between main lawnmower points.
        Returns expanded waypoint list with A* intermediate points.
        """
        if len(main_waypoints) < 2:
            return main_waypoints

        # Get current position as start (or use 0,0 if not available)
        if self.current_gps:
            start_x, start_y = self.latlon_to_meters(self.current_gps[0], self.current_gps[1])
        else:
            start_x, start_y = 0.0, 0.0

        hybrid_path = []
        inflate = self.plan_avoid_margin + self.hull_radius

        # Use obstacle clusters if available (from perception), otherwise empty
        obstacles = self.obstacle_clusters if hasattr(self, 'obstacle_clusters') and self.obstacle_clusters else []

        # Plan from start to first waypoint
        first_wp = main_waypoints[0]
        path_segment = self.astar.plan(
            (start_x, start_y),
            first_wp,
            obstacles,
            inflate_radius=inflate
        )

        if path_segment:
            # Add A* path, excluding start position
            for pt in path_segment:
                if math.hypot(pt[0] - start_x, pt[1] - start_y) > 1.0:
                    hybrid_path.append(pt)

        # Always include first main waypoint
        hybrid_path.append(first_wp)

        # Plan between consecutive main waypoints
        for i in range(len(main_waypoints) - 1):
            wp_start = main_waypoints[i]
            wp_end = main_waypoints[i + 1]

            # Try A* planning between waypoints
            path_segment = self.astar.plan(
                wp_start,
                wp_end,
                obstacles,
                inflate_radius=inflate
            )

            if path_segment and len(path_segment) > 0:
                # A* found a detour - add intermediate points
                for pt in path_segment:
                    # Skip if too close to start waypoint
                    if math.hypot(pt[0] - wp_start[0], pt[1] - wp_start[1]) > 1.0:
                        hybrid_path.append(pt)

            # Always add the end main waypoint
            hybrid_path.append(wp_end)

        return hybrid_path

    def planning_loop(self):
        """Main planning loop with AutoBoat-style logging"""
        if self.state != "DRIVING" or self.current_gps is None:
            return

        # Get current position
        curr_x, curr_y = self.latlon_to_meters(self.current_gps[0], self.current_gps[1])

        # Check if mission complete
        if self.current_wp_index >= len(self.waypoints):
            self.state = "FINISHED"
            self.mission_armed = False  # Disarm when finished
            self.publish_mission_status(curr_x, curr_y)
            self.finish_mission(curr_x, curr_y)
            return

        # Get target waypoint
        target_x, target_y = self.waypoints[self.current_wp_index]

        # Calculate distance to target
        dx = target_x - curr_x
        dy = target_y - curr_y
        dist = math.hypot(dx, dy)

        # Allow looser tolerance when returning home to avoid lingering near home
        effective_tol = self.waypoint_tolerance
        if self.go_home_mode and (self.current_wp_index >= len(self.waypoints) - 1):
            effective_tol = max(self.waypoint_tolerance, 5.0)

        # Opportunistic side detour for close obstacles (buoy clusters)
        if (self.obstacle_detected and not self.detour_waypoint_inserted and
                self.front_clear < 8.0 and self.min_obstacle_distance < 10.0):
            heading = math.atan2(dy, dx)
            side = 'left' if self.left_clear > self.right_clear else 'right'
            self.insert_side_detour(curr_x, curr_y, heading, side)

        # Check if waypoint reached
        if dist < effective_tol:
            self.get_logger().info(
                f"🎯 PT {self.current_wp_index + 1}/{len(self.waypoints)} ATTEINT! | "
                f"WP REACHED! ({target_x:.1f}, {target_y:.1f})"
            )
            if self.detour_waypoint_inserted:
                # Clear detour state when any waypoint is reached
                self.detour_waypoint_inserted = False
                self.detour_start_time = None
            self.advance_to_next_waypoint()
        else:
            # If stuck on a detour too long, skip it
            if self.detour_waypoint_inserted and self.detour_start_time is not None:
                elapsed = (self.get_clock().now() - self.detour_start_time).nanoseconds / 1e9
                if elapsed > 15.0:  # seconds
                    self.get_logger().warn(
                        f"⏭️ Detour timeout ({elapsed:.1f}s) - skipping detour waypoint"
                    )
                    self.detour_waypoint_inserted = False
                    self.detour_start_time = None
                    self.advance_to_next_waypoint()
                    # Recompute distance after skipping
                    if self.current_wp_index < len(self.waypoints):
                        target_x, target_y = self.waypoints[self.current_wp_index]
                        dx = target_x - curr_x
                        dy = target_y - curr_y
                        dist = math.hypot(dx, dy)

            # Waypoint skip logic - skip if obstacle blocking for too long
            self.check_waypoint_skip(curr_x, curr_y, dist)

        # Bilingual status logging
        self.log_navigation_status(curr_x, curr_y, target_x, target_y, dist)

        # Publish current target
        self.publish_current_target(curr_x, curr_y, target_x, target_y, dist)
        
        # Publish mission status
        self.publish_mission_status(curr_x, curr_y)

    def log_navigation_status(self, curr_x, curr_y, target_x, target_y, dist):
        """Log navigation status in AutoBoat bilingual style"""
        wp_progress = f"{self.current_wp_index + 1}/{len(self.waypoints)}"
        heading = math.degrees(math.atan2(target_y - curr_y, target_x - curr_x))
        
        self.get_logger().info(
            f"PT {wp_progress} | "  # PT = Point de Trajectoire (Waypoint)
            f"Pos: ({curr_x:.1f}, {curr_y:.1f}) | "  # Pos = Position
            f"Cible: ({target_x:.1f}, {target_y:.1f}) | "  # Cible = Target
            f"Dist: {dist:.1f}m | "  # Dist = Distance
            f"Cap: {heading:.0f}°",  # Cap = Heading
            throttle_duration_sec=2.0
        )

    def advance_to_next_waypoint(self):
        """Move to next waypoint and reset skip tracking"""
        self.current_wp_index += 1
        self.waypoint_start_time = None
        self.obstacle_blocking_time = 0.0
        self.blocked_reason = ""
        self.last_obstacle_check = None
        self.detour_waypoint_inserted = False  # Reset for next waypoint
        self.detour_count = 0
        self.last_detour_time = 0.0

    def check_waypoint_skip(self, curr_x, curr_y, dist):
        """
        Check if we should skip waypoint due to persistent obstacle blocking.
        In go_home_mode: Insert detour waypoints instead of skipping.
        In normal mode: Skip to next waypoint after timeout or repeated obstruction.
        """
        now = self.get_clock().now()
        
        # Initialize waypoint start time
        if self.waypoint_start_time is None:
            self.waypoint_start_time = now
            self.obstacle_blocking_time = 0.0
            self.last_obstacle_check = now
            return
        
        # Track obstacle blocking time if we're getting close to waypoint
        if dist < 30.0 and self.obstacle_detected:
            if self.last_obstacle_check is not None:
                dt = (now - self.last_obstacle_check).nanoseconds / 1e9
                self.obstacle_blocking_time += dt
                self.blocked_reason = "obstacle_persistent"
        else:
            # Reset blocking time if no obstacle detected at close range
            if dist < 30.0:
                self.obstacle_blocking_time = 0.0
                self.blocked_reason = ""
        
        self.last_obstacle_check = now
        
        # GO HOME MODE: Insert detours instead of skipping
        if self.go_home_mode:
            # Insert detour after shorter timeout (15s) to avoid circling
            if self.obstacle_blocking_time >= self.home_detour_timeout and not self.detour_waypoint_inserted:
                self.get_logger().warn(
                    f"🏠 HOME MODE: Obstacle blocking for {self.obstacle_blocking_time:.0f}s - Inserting detour"
                )
                self.insert_detour_waypoint(curr_x, curr_y)
                self.obstacle_blocking_time = 0.0  # Reset timer after inserting detour
                self.blocked_reason = "detour_home"
            return  # Don't skip in home mode
        
        # NORMAL MODE: Check if we should skip
        # If blocked too long, try a side detour automatically
        if self.obstacle_blocking_time >= self.max_block_time and not self.detour_waypoint_inserted:
            self.get_logger().warn(
                f"⏳ Obstacle blocking for {self.obstacle_blocking_time:.0f}s - inserting detour waypoint"
            )
            self.insert_detour_waypoint(curr_x, curr_y)
            self.obstacle_blocking_time = 0.0
            self.blocked_reason = "detour_auto"
            return

        # Skip condition 1: Timeout exceeded (reduced timeout for faster response)
        timeout_exceeded = self.obstacle_blocking_time >= self.waypoint_skip_timeout
        
        # Skip condition 2: Obstacle detected AND we're very close (cluster of buoys)
        in_obstacle_cluster = dist < 8.0 and self.obstacle_detected
        
        if timeout_exceeded or in_obstacle_cluster:
            if self.current_wp_index >= len(self.waypoints):
                return  # Already past last waypoint
            wp_num = self.current_wp_index + 1
            total_wp = len(self.waypoints)
            target_x, target_y = self.waypoints[self.current_wp_index]

            # Try A* detour before skipping
            if self.astar_enabled:
                detour_path = self.plan_astar_detour(curr_x, curr_y, target_x, target_y)
                if detour_path:
                    self.get_logger().info(
                        f"🧭 A* DETOUR inserted for WP {wp_num}/{total_wp} ({len(detour_path)} segments)"
                    )
                    self.obstacle_blocking_time = 0.0
                    self.blocked_reason = "detour_astar"
                    return
            
            reason = "timeout" if timeout_exceeded else "obstacle_cluster"
            self.get_logger().warn(
                f"⏭️ SKIP WP {wp_num}/{total_wp} | Reason: {reason} | "
                f"Distance: {dist:.1f}m, Blocking: {self.obstacle_blocking_time:.1f}s "
                f"(target: ({target_x:.1f}, {target_y:.1f}))"
            )
            self.blocked_reason = "skipped_" + reason
            self.skip_blocked_waypoints()

    def skip_blocked_waypoints(self):
        """Skip current waypoint and any subsequent waypoints near known obstacles.
        Handles long linear obstacles (e.g. piers) by skipping the entire blocked
        stretch instead of trying each waypoint individually."""
        skipped = 0
        while self.current_wp_index < len(self.waypoints):
            wx, wy = self.waypoints[self.current_wp_index]
            # Check if this waypoint is near any known obstacle cluster
            near_obstacle = False
            for ox, oy in self.obstacle_clusters:
                if math.hypot(wx - ox, wy - oy) < self.min_obstacle_distance_for_skip:
                    near_obstacle = True
                    break
            # Also check if waypoint is close to current blocked position
            if not near_obstacle and skipped > 0:
                # Stop skipping — this waypoint is likely past the obstacle
                break
            self.current_wp_index += 1
            skipped += 1

        # Reset tracking for the new waypoint
        self.waypoint_start_time = None
        self.obstacle_blocking_time = 0.0
        self.blocked_reason = ""
        self.last_obstacle_check = None
        self.detour_waypoint_inserted = False
        self.detour_count = 0
        self.last_detour_time = 0.0

        if skipped > 1:
            self.get_logger().warn(
                f"⏭️ Burst-skipped {skipped} waypoints (long obstacle detected)"
            )

    def _is_detour_clear(self, detour_x, detour_y, min_clearance=8.0):
        """Check if proposed detour point is far enough from known obstacles."""
        for ox, oy in self.obstacle_clusters:
            if math.hypot(detour_x - ox, detour_y - oy) < min_clearance:
                return False
        return True

    def insert_detour_waypoint(self, curr_x, curr_y):
        """Insert a detour waypoint perpendicular to current heading"""
        import time
        now = time.time()
        if now - self.last_detour_time < self.detour_cooldown:
            return  # Cooldown active
        if self.detour_count >= self.max_detours_per_waypoint:
            self.get_logger().warn(
                f"Detour cap reached ({self.detour_count}/{self.max_detours_per_waypoint}) — burst-skipping blocked waypoints"
            )
            self.skip_blocked_waypoints()
            return

        # Get current heading from GPS velocity or use direction to waypoint
        if self.current_wp_index < len(self.waypoints):
            target_x, target_y = self.waypoints[self.current_wp_index]
            heading = math.atan2(target_y - curr_y, target_x - curr_x)
        else:
            heading = 0.0

        # Choose clearer side based on perception data
        if self.left_clear >= self.right_clear:
            detour_angle = heading + math.pi / 2  # Left
        else:
            detour_angle = heading - math.pi / 2  # Right
        detour_x = curr_x + self.detour_distance * math.cos(detour_angle)
        detour_y = curr_y + self.detour_distance * math.sin(detour_angle)

        # Validate detour point is not obstructed
        if not self._is_detour_clear(detour_x, detour_y):
            # Try opposite side
            detour_angle = heading - math.pi / 2 if self.left_clear >= self.right_clear else heading + math.pi / 2
            detour_x = curr_x + self.detour_distance * math.cos(detour_angle)
            detour_y = curr_y + self.detour_distance * math.sin(detour_angle)
            if not self._is_detour_clear(detour_x, detour_y):
                self.get_logger().warn("Both detour sides obstructed — burst-skipping blocked waypoints")
                self.skip_blocked_waypoints()
                return

        # Insert detour waypoint before current target
        self.waypoints.insert(self.current_wp_index, (detour_x, detour_y))
        self.detour_waypoint_inserted = True
        self.detour_count += 1
        self.last_detour_time = now
        self.detour_start_time = self.get_clock().now()

        self.get_logger().warn(
            f"DETOUR {self.detour_count}/{self.max_detours_per_waypoint}! "
            f"Inserting at ({detour_x:.1f}, {detour_y:.1f})"
        )
        
        # Publish updated waypoints
        self.publish_waypoints()

    def insert_side_detour(self, curr_x, curr_y, heading, side='left'):
        """Insert a perpendicular + forward detour based on obstacle side."""
        import time
        now = time.time()
        if now - self.last_detour_time < self.detour_cooldown:
            return  # Cooldown active
        if self.detour_count >= self.max_detours_per_waypoint:
            self.get_logger().warn(
                f"Detour cap reached ({self.detour_count}/{self.max_detours_per_waypoint}) — burst-skipping blocked waypoints"
            )
            self.skip_blocked_waypoints()
            return

        lateral = self.detour_distance
        forward = self.detour_forward_offset
        angle = heading + (math.pi / 2 if side == 'left' else -math.pi / 2)
        detour_x = curr_x + lateral * math.cos(angle) + forward * math.cos(heading)
        detour_y = curr_y + lateral * math.sin(angle) + forward * math.sin(heading)

        # Validate detour point is not obstructed
        if not self._is_detour_clear(detour_x, detour_y):
            # Try opposite side
            opp_side = 'right' if side == 'left' else 'left'
            angle = heading + (math.pi / 2 if opp_side == 'left' else -math.pi / 2)
            detour_x = curr_x + lateral * math.cos(angle) + forward * math.cos(heading)
            detour_y = curr_y + lateral * math.sin(angle) + forward * math.sin(heading)
            if not self._is_detour_clear(detour_x, detour_y):
                self.get_logger().warn("Both side detour directions obstructed — burst-skipping blocked waypoints")
                self.skip_blocked_waypoints()
                return
            side = opp_side

        self.waypoints.insert(self.current_wp_index, (detour_x, detour_y))
        self.detour_waypoint_inserted = True
        self.detour_count += 1
        self.last_detour_time = now
        self.detour_start_time = self.get_clock().now()
        self.get_logger().warn(
            f"📍 Side detour {self.detour_count}/{self.max_detours_per_waypoint} ({side.upper()}): "
            f"({detour_x:.1f}, {detour_y:.1f}) | "
            f"Front={self.front_clear:.1f}m L={self.left_clear:.1f}m R={self.right_clear:.1f}m"
        )
        self.publish_waypoints()

    def plan_astar_detour(self, curr_x, curr_y, target_x, target_y):
        """Run A* to replace the current leg with a detour path."""
        import time
        now = time.time()
        if now - self.last_detour_time < self.detour_cooldown:
            return None  # Cooldown active
        if self.detour_count >= self.max_detours_per_waypoint:
            return None  # Cap reached — caller will skip

        inflate = self.plan_avoid_margin + self.hull_radius
        obstacles = self.obstacle_clusters if self.obstacle_clusters else []
        path = self.astar.plan(
            (curr_x, curr_y),
            (target_x, target_y),
            obstacles,
            inflate_radius=inflate
        )

        if not path:
            return None

        # Replace current waypoint with the planned segments (include goal)
        # Ensure we don't include the current position as a waypoint
        filtered = [(x, y) for (x, y) in path if math.hypot(x - curr_x, y - curr_y) > 1.0]
        if not filtered:
            return None

        self.waypoints[self.current_wp_index:self.current_wp_index + 1] = filtered
        self.publish_waypoints()
        self.detour_waypoint_inserted = True
        self.detour_count += 1
        self.last_detour_time = now
        return filtered

    def finish_mission(self, final_x, final_y):
        """Complete mission with AutoBoat-style summary"""
        elapsed = 0.0
        if self.mission_start_time:
            elapsed = (self.get_clock().now() - self.mission_start_time).nanoseconds / 1e9
        elapsed_min = elapsed / 60.0

        was_going_home = self.go_home_mode
        self.go_home_mode = False  # Reset home mode

        self.get_logger().info("=" * 60)
        if was_going_home:
            self.get_logger().info("🏠 ARRIVED HOME!")
            self.get_logger().info("=" * 60)
            self.get_logger().info(f"Final Position: ({final_x:.1f}m, {final_y:.1f}m)")
            self.get_logger().info(f"Mission Time: {elapsed_min:.1f} minutes")
            self.get_logger().info("=" * 60)
            # Clear waypoints after go_home so user knows to regenerate
            self.waypoints = []
            self.current_wp_index = 0
            self.state = "INIT"
            self.get_logger().info("Waypoints cleared. Run 'generate' for new waypoints.")
        else:
            self.get_logger().info("✅ MISSION COMPLETE!")
            self.get_logger().info("=" * 60)
            self.get_logger().info(f"Final Position: ({final_x:.1f}m, {final_y:.1f}m)")
            self.get_logger().info(f"Waypoints: {len(self.waypoints)}")
            self.get_logger().info(f"Mission Time: {elapsed_min:.1f} minutes")
            self.get_logger().info("=" * 60)
            # Keep waypoints for potential restart
            self.get_logger().info("Run 'start' to repeat mission or 'generate' for new waypoints.")

    def publish_waypoints(self):
        """Publish all waypoints"""
        self._publish_json(
            self.pub_waypoints,
            {'waypoints': self.waypoints, 'total': len(self.waypoints)},
            'waypoints',
        )

    def publish_current_target(self, curr_x, curr_y, target_x, target_y, dist):
        """Publish current navigation target"""
        self._publish_json(
            self.pub_current_target,
            {
                'current_position': [round(curr_x, 2), round(curr_y, 2)],
                'target_waypoint': [round(target_x, 2), round(target_y, 2)],
                'waypoint_index': self.current_wp_index,
                'total_waypoints': len(self.waypoints),
                'distance_to_target': round(dist, 2),
                'target_heading': round(math.degrees(math.atan2(
                    target_y - curr_y, target_x - curr_x
                )), 1),
            },
            'current_target',
        )

    def publish_mission_status(self, curr_x, curr_y):
        """Publish mission status"""
        elapsed = 0.0
        if self.mission_start_time:
            elapsed = (self.get_clock().now() - self.mission_start_time).nanoseconds / 1e9

        # Check GPS ready status with timeout fallback
        gps_ready = self.current_gps is not None
        
        # Initialize GPS timeout tracking
        if self.gps_init_time is None and self.current_gps is None:
            self.gps_init_time = self.get_clock().now()
        
        # GPS timeout: if no GPS after 30 seconds, assume ready anyway (fallback)
        if self.gps_init_time is not None and not gps_ready:
            gps_wait_time = (self.get_clock().now() - self.gps_init_time).nanoseconds / 1e9
            if gps_wait_time >= self.gps_timeout:
                gps_ready = True  # Fallback: consider GPS ready after timeout
                if not self.gps_timeout_warned:
                    self.get_logger().warn(
                        f"⚠️  GPS NOT RECEIVED after {self.gps_timeout}s - assuming GPS ready anyway (fallback mode)\n"
                        f"   Check: 'ros2 topic echo /wamv/sensors/gps/gps/fix --once'\n"
                        f"   Issue may be: wrong world file, Gazebo plugin problem, or VRX setup issue"
                    )
                    self.gps_timeout_warned = True

        self._publish_json(
            self.pub_mission_status,
            {
                'state': self.state,
                'current_waypoint': min(self.current_wp_index + 1, len(self.waypoints)),
                'total_waypoints': len(self.waypoints),
                'progress_percent': round(100 * min(self.current_wp_index, len(self.waypoints)) / max(1, len(self.waypoints)), 1),
                'elapsed_time': round(elapsed, 1),
                'position': [round(curr_x, 2), round(curr_y, 2)],
                'mission_armed': self.mission_armed,
                'gps_ready': gps_ready,
                'detour_active': self.detour_waypoint_inserted,
                'go_home_mode': self.go_home_mode,
                'joystick_override': self.state == "JOYSTICK",
                'blocked_reason': self.blocked_reason,
            },
            'mission_status',
        )

    def publish_mission_status_timer(self):
        """Timer callback to publish mission status continuously (even when not DRIVING)"""
        if self.current_gps is not None:
            curr_x, curr_y = self.latlon_to_meters(self.current_gps[0], self.current_gps[1])
        else:
            curr_x, curr_y = 0.0, 0.0
        self.publish_mission_status(curr_x, curr_y)

    def _publish_current_target_immediate(self):
        """Immediately publish current target (called on resume/go_home for instant controller response)"""
        if self.current_gps is None:
            self.get_logger().warn("⚠️ Cannot publish target: GPS not available")
            return
        if not self.waypoints:
            self.get_logger().warn("⚠️ Cannot publish target: No waypoints")
            return
        if self.current_wp_index >= len(self.waypoints):
            self.get_logger().warn(f"⚠️ Cannot publish target: Waypoint index {self.current_wp_index} >= {len(self.waypoints)}")
            return

        curr_x, curr_y = self.latlon_to_meters(self.current_gps[0], self.current_gps[1])
        target_x, target_y = self.waypoints[self.current_wp_index]
        dist = math.hypot(target_x - curr_x, target_y - curr_y)
        self.publish_current_target(curr_x, curr_y, target_x, target_y, dist)
        self.get_logger().info(f"📍 Target published: ({target_x:.1f}, {target_y:.1f}) - {dist:.1f}m away")


def main(args=None):
    rclpy.init(args=args)
    node = WaypointPlanner()
    
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
