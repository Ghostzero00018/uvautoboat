#!/usr/bin/env python3
"""
Mission CLI - Terminal-based mission control for AutoBoat

Use this when the web dashboard is unavailable. Targets the modular
Waypoint Planner + Heading Controller pipeline.

Usage:
    # Generate waypoints with default parameters
    ros2 run plan autoboat_cli generate

    # Generate waypoints with custom parameters
    ros2 run plan autoboat_cli generate --lanes 8 --length 50 --width 20

    # Start / Stop / Resume / Reset mission
    ros2 run plan autoboat_cli start
    ros2 run plan autoboat_cli stop
    ros2 run plan autoboat_cli resume
    ros2 run plan autoboat_cli reset

    # Go home (return to spawn)
    ros2 run plan autoboat_cli home

    # Confirm waypoints
    ros2 run plan autoboat_cli confirm

    # Set PID parameters
    ros2 run plan autoboat_cli pid --kp 400 --ki 20 --kd 100

    # Set speed
    ros2 run plan autoboat_cli speed --base 500 --max 800

    # Generate with custom parameters (PID, speed, and turn angle)
    ros2 run plan autoboat_cli generate --kp 500 --ki 20 --kd 150 --base 400 --max 800 --max-turn 20

    # Generate with anti-stuck parameters (for navigation tuning)
    ros2 run plan autoboat_cli generate --stuck-timeout 12.0 --stuck-threshold 1.0

    # Generate with perception parameters (for low pier detection)
    ros2 run plan autoboat_cli generate --min-height -1.2

    # Full custom configuration (all parameters)
    ros2 run plan autoboat_cli generate --kp 500 --base 400 --max 800 --max-turn 20 --stuck-timeout 12.0 --stuck-threshold 1.0 --min-height -1.2

    # Show current status
    ros2 run plan autoboat_cli status

    # Interactive mode
    ros2 run plan autoboat_cli interactive

Interactive vs one-shot mode
----------------------------

Interactive mode (`ros2 run plan autoboat_cli interactive`) is the recommended
way to run multi-step command sequences. Each command runs in a single
long-lived node whose subscriptions stay warm across commands, so the
`_wait_for_state` observer reliably catches state transitions.

One-shot commands (e.g. `autoboat_cli start`) create a fresh node per
invocation. Between node creation and the observer's 2 s window closing, DDS
late-joiner discovery plus the planner's 5 Hz publish cadence mean the
first fresh `/planning/mission_status` message may not arrive in time —
you'll see `state did not reach DRIVING within 2 s (current: ...)` even when
the planner actually transitioned fine. The observer is being honest about
what it saw in its window; it is not a missed transition on the planner
side. Use interactive mode for sequences, or verify with
`ros2 topic echo /planning/mission_status --once` when one-shot timing
matters.
"""

import rclpy
from rclpy.node import Node
from std_msgs.msg import String, Bool
from std_srvs.srv import Trigger
import json
import sys
import argparse
import time
from pathlib import Path
from typing import Optional, Tuple

# Derive repo root from this file's location: plan/plan/autoboat_cli.py -> repo root
_REPO_ROOT = Path(__file__).resolve().parents[2]
_LAUNCH_FILE = _REPO_ROOT / 'launch' / 'autoboat.launch.yaml'


class MissionCLI(Node):
    def __init__(self):
        super().__init__('autoboat_cli')

        # Publishers
        self.config_pub = self.create_publisher(String, '/planning/set_config', 10)
        self.command_pub = self.create_publisher(String, '/planning/mission_command', 10)
        # Dedicated E-Stop channel — RELIABLE QoS delivers without retries.
        self.estop_pub = self.create_publisher(Bool, '/planning/emergency_stop', 1)

        # Service clients — request/response replaces fire-and-hope retries.
        self.stop_client = self.create_client(Trigger, '/planning/stop_mission')
        self.generate_client = self.create_client(Trigger, '/planning/generate_waypoints')

        # Subscribers for status
        self.mission_status = None
        self.config_status = None
        self.controller_status = None

        self.create_subscription(
            String,
            '/planning/mission_status',
            self.mission_status_callback,
            10
        )

        self.create_subscription(
            String,
            '/planning/config',
            self.config_callback,
            10
        )

        self.create_subscription(
            String,
            '/control/status',
            self.controller_status_callback,
            10
        )

        # Per-topic last-warn timestamps for _log_bad_json throttle.
        self._bad_json_last_warn: dict = {}

        # Wait for connection
        time.sleep(0.5)

    def _log_bad_json(self, topic: str, exc: Exception, throttle_sec: float = 5.0) -> None:
        """Warn once per `throttle_sec` when a status topic delivers unparseable JSON."""
        now = time.monotonic()
        last = self._bad_json_last_warn.get(topic, 0.0)
        if now - last >= throttle_sec:
            self.get_logger().warn(f"Failed to parse {topic}: {exc}")
            self._bad_json_last_warn[topic] = now

    def _spin_for_status(self, timeout: float = 1.5) -> Tuple[Optional[dict], Optional[dict]]:
        """
        Spin briefly to refresh mission/config status.
        Returns (mission_status, config_status).
        """
        start = time.time()
        while time.time() - start < timeout:
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.mission_status or self.config_status:
                break
        return self.mission_status, self.config_status

    # TODO(tier2-option-a): start/resume/go_home are still topic-based commands
    # on /planning/mission_command. If multi-operator coordination becomes a
    # requirement, migrate them to std_srvs/Trigger services matching the
    # stop/generate pattern already in place. Until then, the observer below
    # gives us deterministic state confirmation without a protocol change.
    def _wait_for_state(self, expected: set, timeout: float = 2.0) -> Tuple[bool, str]:
        """
        Spin until mission_status.state is in `expected`, or timeout expires.
        Returns (reached, observed_state). `observed_state` is the last state
        seen (may be None-stringified 'unknown' if no status ever arrived).
        """
        start = time.time()
        observed = 'unknown'
        while time.time() - start < timeout:
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.mission_status:
                observed = self.mission_status.get('state', 'unknown') or 'unknown'
                if observed in expected:
                    return True, observed
        return False, observed

    def _waypoint_info(self) -> Tuple[int, str]:
        """
        Best-effort extraction of waypoint count and state across modes.
        Returns (count, state_string)
        """
        state = None
        count = 0
        if self.mission_status:
            state = self.mission_status.get('state', None)
            count = int(self.mission_status.get('total_waypoints', 0) or 0)
            # Planner exposes current_waypoint instead of waypoint index
            if count == 0 and 'current_waypoint' in self.mission_status:
                count = int(self.mission_status.get('current_waypoint') or 0)
        if self.config_status:
            state = self.config_status.get('state', state)
            if 'total_waypoints' in self.config_status:
                count = max(count, int(self.config_status.get('total_waypoints') or 0))
            if 'waypoint_count' in self.config_status:
                count = max(count, int(self.config_status.get('waypoint_count') or 0))
        return count, state or 'UNKNOWN'

    def _auto_confirm_if_needed(self, for_command='start') -> bool:
        """
        Ensure waypoints are confirmed before starting/resuming.
        Returns True if we can proceed with start/resume.
        """
        self._spin_for_status()
        count, state = self._waypoint_info()

        # Special handling for FINISHED state
        if state == "FINISHED":
            if count <= 1:
                # After go_home, only 1 waypoint (home location) - need to regenerate
                print("⚠️ Mission finished. Run 'generate' to create new waypoints.")
                return False
            # Normal FINISHED - can restart with existing waypoints
            print(f"ℹ️ Restarting from FINISHED state with {count} waypoints...")
            return True

        if count == 0:
            print("⚠️ No waypoints defined. Run 'generate' first.")
            return False

        # If already armed/running, nothing to do
        armed = False
        if self.config_status and 'mission_armed' in self.config_status:
            armed = bool(self.config_status.get('mission_armed'))
        elif self.mission_status and 'mission_armed' in self.mission_status:
            armed = bool(self.mission_status.get('mission_armed'))

        if state == "DRIVING":
            if for_command == 'start':
                print("ℹ️ Mission already running.")
            return armed  # Only proceed if actually armed

        # READY state - good to go
        if state == "READY":
            return True

        # PAUSED state - only allow resume, not start
        if state == "PAUSED":
            if for_command == 'start':
                print("ℹ️ Mission is PAUSED. Use 'resume' to continue or 'reset' to restart.")
                return False
            return True

        # States that still need confirmation
        needs_confirm = state in ["WAITING_CONFIRM", "INIT", "IDLE", None, "UNKNOWN"]
        if needs_confirm:
            print("✅ Auto-confirming waypoints before start...")
            self.confirm_waypoints()
            # Give time for the nav stack to process confirmation
            self._spin_for_status(timeout=1.0)
        return True
        
    def mission_status_callback(self, msg):
        try:
            self.mission_status = json.loads(msg.data)
        except Exception as e:
            self._log_bad_json('/planning/mission_status', e)

    def config_callback(self, msg):
        try:
            self.config_status = json.loads(msg.data)
        except Exception as e:
            self._log_bad_json('/planning/config', e)

    def controller_status_callback(self, msg):
        try:
            self.controller_status = json.loads(msg.data)
        except Exception as e:
            self._log_bad_json('/control/status', e)
    
    def wait_for_ready(self, timeout=5.0):
        """Wait for navigation system to be ready"""
        print("⏳ Waiting for navigation system...")
        start = time.time()
        while time.time() - start < timeout:
            rclpy.spin_once(self, timeout_sec=0.2)
            if self.config_status is not None:
                print("✅ Navigation system ready!")
                return True
        print("⚠️ Navigation system not responding. Is it running?")
        print(f"   Start with: ros2 launch {_LAUNCH_FILE}")
        return False
    
    def send_command(self, command):
        """Send mission command"""
        msg = String()
        msg.data = json.dumps({'command': command})
        self.command_pub.publish(msg)
        self.get_logger().info(f"Sent command: {command}")
        
    def send_config(self, config):
        """Send configuration"""
        msg = String()
        msg.data = json.dumps(config)
        self.config_pub.publish(msg)
        self.get_logger().info(f"Sent config: {config}")
        
    def generate_waypoints(self, lanes=8, length=50.0, width=20.0,
                            kp=None, ki=None, kd=None, base_speed=None, max_speed=None, max_turn=None,
                            stuck_timeout=None, stuck_threshold=None,
                            min_height=None, safe_dist=None, perception_safe_dist=None, approach_dist=None, approach_factor=None,
                            astar=False, astar_hybrid=False, astar_resolution=None, astar_safety=None, astar_max=None):
        """Generate waypoints with specified parameters and optional PID/speed/turn/A* config"""
        # Wait for navigation system to be ready
        if not self.wait_for_ready():
            return False
            
        # Waypoint config (for planner)
        config = {
            'lanes': lanes,
            'scan_length': length,
            'scan_width': width
        }
        
        # Add PID/speed/turn if specified (controller also listens to /planning/set_config)
        if kp is not None:
            config['kp'] = kp
        if ki is not None:
            config['ki'] = ki
        if kd is not None:
            config['kd'] = kd
        if base_speed is not None:
            config['base_speed'] = base_speed
        if max_speed is not None:
            config['max_speed'] = max_speed
        if max_turn is not None:
            config['max_avoidance_turn_deg'] = max_turn

        # Simple anti-stuck parameters (for controller)
        if stuck_timeout is not None:
            config['stuck_timeout'] = stuck_timeout
        if stuck_threshold is not None:
            config['stuck_threshold'] = stuck_threshold

        # Perception parameters
        if min_height is not None:
            config['min_height'] = min_height

        # Controller distance parameters
        if safe_dist is not None:
            config['min_safe_distance'] = safe_dist
        # Perception distance parameter (separate from controller's min_safe_distance)
        if perception_safe_dist is not None:
            config['perception_min_safe_distance'] = perception_safe_dist
        if approach_dist is not None:
            config['approach_slow_distance'] = approach_dist
        if approach_factor is not None:
            config['approach_slow_factor'] = approach_factor

        # A* options
        if astar:
            config['astar_enabled'] = True
        if astar_hybrid:
            config['astar_hybrid_mode'] = True
        if astar_resolution is not None:
            config['astar_resolution'] = astar_resolution
        if astar_safety is not None:
            config['astar_safety_margin'] = astar_safety
        if astar_max is not None:
            config['astar_max_expansions'] = astar_max
            
        self.send_config(config)
        # Config is a topic (no ACK), generate is a service. rclpy's single-threaded
        # executor processes the config subscription before dispatching the service
        # call, so no hand-tuned sleep is needed for config to be applied first.
        if not self.generate_client.wait_for_service(timeout_sec=1.0):
            print("⚠️ Generate service unavailable — planner not running?")
            return False
        future = self.generate_client.call_async(Trigger.Request())
        rclpy.spin_until_future_complete(self, future, timeout_sec=3.0)
        result = future.result()
        if result is None or not result.success:
            msg = result.message if result else "no response"
            print(f"⚠️ Generate rejected: {msg}")
            return False

        print(f"\n✅ Waypoints generated: {lanes} lanes × {length}m length × {width}m width")
        print(f"   Estimated waypoints: {lanes * 2 - 1}")
        print(f"   Estimated distance: {length * lanes + width * (lanes - 1):.0f}m")
        
        # Show PID/speed if configured
        pid_info = []
        if kp is not None:
            pid_info.append(f"Kp={kp}")
        if ki is not None:
            pid_info.append(f"Ki={ki}")
        if kd is not None:
            pid_info.append(f"Kd={kd}")
        if pid_info:
            print(f"   PID: {', '.join(pid_info)}")
            
        speed_info = []
        if base_speed is not None:
            speed_info.append(f"base={base_speed}")
        if max_speed is not None:
            speed_info.append(f"max={max_speed}")
        if speed_info:
            print(f"   Speed: {', '.join(speed_info)}")
        
    def start_mission(self):
        """Start the mission"""
        if not self._auto_confirm_if_needed(for_command='start'):
            return
        self.send_command('start_mission')
        reached, observed = self._wait_for_state({"DRIVING"})
        if reached:
            print("\n🚀 Mission STARTED — state: DRIVING")
        else:
            print(f"\n⚠️ Mission start sent, but state did not reach DRIVING within 2 s (current: {observed})")
        
    def stop_mission(self):
        """Stop the mission via service — ACK confirms delivery."""
        print("\n🛑 Stopping mission...")
        if not self.stop_client.wait_for_service(timeout_sec=1.0):
            print("⚠️ Stop service unavailable — planner not running?")
            return
        future = self.stop_client.call_async(Trigger.Request())
        rclpy.spin_until_future_complete(self, future, timeout_sec=2.0)
        result = future.result()
        if result is None:
            print("⚠️ Stop service did not respond within 2s")
            return
        if result.success:
            print(f"✅ Mission STOPPED — {result.message}")
        else:
            print(f"⚠️ Stop rejected: {result.message}")
        
    def emergency_stop(self):
        """Emergency stop — cuts thrust and latches stop override"""
        print("\n🚨 EMERGENCY STOP...")
        self.estop_pub.publish(Bool(data=True))
        reached, observed = self._wait_for_state({"EMERGENCY_STOP"})
        if reached:
            print("🚨 EMERGENCY STOP confirmed. Use 'resume' or 'reset' to recover.")
        else:
            print(f"⚠️ Emergency stop sent, but state did not reach EMERGENCY_STOP within 2 s (current: {observed})")

    def resume_mission(self):
        """Resume the mission"""
        if not self._auto_confirm_if_needed(for_command='resume'):
            return
        self.send_command('resume_mission')
        reached, observed = self._wait_for_state({"DRIVING"})
        if reached:
            print("\n▶️ Mission RESUMED — state: DRIVING")
        else:
            print(f"\n⚠️ Resume sent, but state did not reach DRIVING within 2 s (current: {observed})")
        
    def reset_mission(self):
        """Reset the mission"""
        self.send_command('reset_mission')
        print("\n🔄 Mission RESET command sent!")
    
    def go_home(self):
        """Navigate back to spawn point"""
        # go_home sets its own waypoints, so just check if GPS is ready
        self._spin_for_status()
        gps_ready = False
        if self.config_status:
            gps_ready = self.config_status.get('gps_ready', False)
        if not gps_ready:
            print("⚠️ GPS not ready yet. Wait for GPS signal.")
            return

        self.send_command('go_home')
        reached, observed = self._wait_for_state({"DRIVING"})
        if reached:
            print("\n🏠 GO HOME — state: DRIVING, returning to spawn point")
        else:
            print(f"\n⚠️ Go home sent, but state did not reach DRIVING within 2 s (current: {observed})")
        print("   Note: After arriving home, run 'generate' to create new waypoints.")
        
    def confirm_waypoints(self):
        """Confirm waypoints"""
        self.send_command('confirm_waypoints')
        print("\n✅ Waypoints CONFIRMED!")
        
    def set_pid(self, kp=None, ki=None, kd=None):
        """Set PID parameters"""
        config = {}
        if kp is not None:
            config['kp'] = kp
        if ki is not None:
            config['ki'] = ki
        if kd is not None:
            config['kd'] = kd
        if config:
            self.send_config(config)
            print(f"\n⚙️ PID parameters updated: {config}")
            
    def set_speed(self, base=None, max_speed=None):
        """Set speed parameters"""
        config = {}
        if base is not None:
            config['base_speed'] = base
        if max_speed is not None:
            config['max_speed'] = max_speed
        if config:
            self.send_config(config)
            print(f"\n⚙️ Speed parameters updated: {config}")
            
    def show_status(self):
        """Show current status"""
        # Spin longer to ensure we receive status messages
        print("\n⏳ Waiting for status...")
        for _ in range(30):
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.mission_status or self.config_status:
                break
            
        print("\n" + "=" * 50)
        print("AUTOBOAT STATUS")
        print("=" * 50)
        
        # Mission status (only available during DRIVING state)
        if self.mission_status:
            state = self.mission_status.get('state', 'Unknown')
            waypoint = self.mission_status.get('current_waypoint', '?')
            total = self.mission_status.get('total_waypoints', '?')
            progress = self.mission_status.get('progress_percent', '?')
            elapsed = self.mission_status.get('elapsed_time', '?')
            position = self.mission_status.get('position', ['?', '?'])
            
            print(f"State: {state}")
            print(f"Waypoint: {waypoint}/{total}")
            print(f"Progress: {progress}%")
            print(f"Elapsed Time: {elapsed}s")
            print(f"Position: ({position[0]}, {position[1]})")
        else:
            # Check if we at least have config (system is running but mission not active)
            if self.config_status:
                state = self.config_status.get('state', 'IDLE')
                waypoint_count = self.config_status.get('waypoint_count', 0)
                gps_ready = self.config_status.get('gps_ready', False)
                mission_armed = self.config_status.get('mission_armed', False)
                
                print(f"State: {state}")
                print(f"Waypoints: {waypoint_count} defined")
                print(f"GPS: {'✅ Ready' if gps_ready else '⏳ Waiting...'}")
                print(f"Armed: {'✅ Yes' if mission_armed else '❌ No (use confirm command)'}")
                print("\n💡 Mission status updates during DRIVING state only")
            else:
                print("⚠️ No status received")
                print("   Check if the navigation system is running:")
                print(f"   ros2 launch {_LAUNCH_FILE}")
        
        # Planner config (waypoint generation settings)
        if self.config_status:
            print(f"\nPlanner Config (Waypoints):")
            print(f"  Lanes: {self.config_status.get('lanes', '?')}")
            print(f"  Scan Length: {self.config_status.get('scan_length', '?')}m")
            print(f"  Scan Width: {self.config_status.get('scan_width', '?')}m")
            print(f"  Tolerance: {self.config_status.get('waypoint_tolerance', '?')}m")
        
        # Controller status (obstacle avoidance)
        if self.controller_status:
            print(f"\nController Status:")
            print(f"  Mode: {self.controller_status.get('mode', '?')}")
            avoidance = self.controller_status.get('avoidance_active', False)
            obstacle = self.controller_status.get('obstacle_detected', False)
            distance = self.controller_status.get('obstacle_distance', '?')
            urgency = self.controller_status.get('urgency', 0.0)
            obs_count = self.controller_status.get('obstacle_count', 0)
            is_critical = self.controller_status.get('is_critical', False)
            
            # Perception v2.0 enhanced display
            if is_critical:
                print(f"  Obstacle: 🚨 CRITICAL ({distance}m) [{obs_count} clusters]")
            elif obstacle:
                print(f"  Obstacle: ⚠️ DETECTED ({distance}m) [{obs_count} clusters]")
            else:
                print(f"  Obstacle: ✅ Clear ({distance}m)")
            
            print(f"  Urgency: {urgency*100:.0f}%")
            print(f"  Avoidance: {'🔄 Active' if avoidance else 'Inactive'}")
            print(f"  Heading: {self.controller_status.get('current_yaw', '?')}°")
        
        # Tip: PID/Speed and other controller params are synced to the ROS
        # parameter server on every /planning/set_config, so direct param
        # queries are authoritative.
        print(f"\n💡 Verify runtime param values with e.g.:")
        print(f"   ros2 param get /heading_controller_node kp")
        
        print("=" * 50)
        
    def interactive_mode(self):
        """Interactive command mode"""
        print("\n" + "=" * 60)
        print("AUTOBOAT INTERACTIVE MODE")
        print("=" * 60)
        print("Commands:")
        print("  g [lanes] [length] [width] - Generate waypoints")
        print("  c                          - Confirm waypoints")
        print("  s                          - Start mission")
        print("  x                          - Stop mission")
        print("  e                          - 🚨 Emergency stop")
        print("  r                          - Resume mission")
        print("  reset                      - Reset mission")
        print("  home                       - 🏠 Go home (return to spawn)")
        print("  status                     - Show status")
        print("  pid <kp> <ki> <kd>         - Set PID")
        print("  speed <base> <max>         - Set speed")
        print("  q                          - Quit")
        print("=" * 60)
        
        while True:
            try:
                cmd = input("\nautoboat> ").strip().lower().split()
                if not cmd:
                    continue
                    
                if cmd[0] == 'q' or cmd[0] == 'quit':
                    print("Goodbye!")
                    break
                elif cmd[0] == 'g' or cmd[0] == 'generate':
                    lanes = int(cmd[1]) if len(cmd) > 1 else 8
                    length = float(cmd[2]) if len(cmd) > 2 else 50.0
                    width = float(cmd[3]) if len(cmd) > 3 else 20.0
                    self.generate_waypoints(lanes, length, width)
                elif cmd[0] == 'c' or cmd[0] == 'confirm':
                    self.confirm_waypoints()
                elif cmd[0] == 's' or cmd[0] == 'start':
                    self.start_mission()
                elif cmd[0] == 'x' or cmd[0] == 'stop':
                    self.stop_mission()
                elif cmd[0] == 'e' or cmd[0] == 'emergency':
                    self.emergency_stop()
                elif cmd[0] == 'r' or cmd[0] == 'resume':
                    self.resume_mission()
                elif cmd[0] == 'reset':
                    self.reset_mission()
                elif cmd[0] == 'home':
                    self.go_home()
                elif cmd[0] == 'status':
                    self.show_status()
                elif cmd[0] == 'pid' and len(cmd) >= 4:
                    self.set_pid(float(cmd[1]), float(cmd[2]), float(cmd[3]))
                elif cmd[0] == 'speed' and len(cmd) >= 3:
                    self.set_speed(float(cmd[1]), float(cmd[2]))
                else:
                    print("Unknown command. Type 'q' to quit.")
                    
                # Brief spin to process callbacks
                rclpy.spin_once(self, timeout_sec=0.1)
                    
            except KeyboardInterrupt:
                print("\nInterrupted. Goodbye!")
                break
            except ValueError as e:
                print(f"Invalid value: {e}")
            except Exception as e:
                print(f"Error: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='AutoBoat Mission CLI - Terminal control for autonomous boat',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate waypoints only
  ros2 run plan autoboat_cli generate --lanes 8 --length 50 --width 20
  
  # Generate with PID and speed in one command
  ros2 run plan autoboat_cli generate --lanes 10 --length 60 --width 25 --kp 400 --ki 20 --kd 100 --base 500 --max 800
  
  # Mission control
  ros2 run plan autoboat_cli confirm
  ros2 run plan autoboat_cli start
  ros2 run plan autoboat_cli status
  ros2 run plan autoboat_cli stop
  ros2 run plan autoboat_cli home
  
  # Separate PID/speed commands
  ros2 run plan autoboat_cli pid --kp 500 --ki 25 --kd 120
  ros2 run plan autoboat_cli speed --base 600 --max 900
  
  # Interactive mode
  ros2 run plan autoboat_cli interactive
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # Generate command with optional PID/speed
    gen_parser = subparsers.add_parser('generate', help='Generate waypoints (with optional PID/speed/A*)')
    gen_parser.add_argument('--lanes', '-l', type=int, default=8, help='Number of lanes')
    gen_parser.add_argument('--length', '-L', type=float, default=50.0, help='Lane length in meters')
    gen_parser.add_argument('--width', '-w', type=float, default=20.0, help='Lane width in meters')
    gen_parser.add_argument('--kp', type=float, help='PID Proportional gain (optional)')
    gen_parser.add_argument('--ki', type=float, help='PID Integral gain (optional)')
    gen_parser.add_argument('--kd', type=float, help='PID Derivative gain (optional)')
    gen_parser.add_argument('--base', type=float, help='Base speed in N (optional)')
    gen_parser.add_argument('--max', type=float, help='Max speed in N (optional)')
    gen_parser.add_argument('--max-turn', type=float, help='Max avoidance turn angle in degrees (optional, controller)')
    # Simple anti-stuck parameters (for controller)
    gen_parser.add_argument('--stuck-timeout', type=float, help='Stuck detection timeout in seconds (optional, controller)')
    gen_parser.add_argument('--stuck-threshold', type=float, help='Stuck detection threshold in meters (optional, controller)')
    # Perception parameters
    gen_parser.add_argument('--min-height', type=float, help='Min LiDAR height threshold in meters (optional, perception)')
    # Controller distance parameters
    gen_parser.add_argument('--safe-dist', type=float, help='Min safe distance in meters (optional, controller)')
    gen_parser.add_argument('--perception-safe-dist', type=float, help='Perception detection safe distance in meters (optional, perception)')
    gen_parser.add_argument('--approach-dist', type=float, help='Approach slow-down distance in meters (optional, controller)')
    gen_parser.add_argument('--approach-factor', type=float, help='Approach slow-down speed factor 0-1 (optional, controller)')
    # A* options (forwarded to planner)
    gen_parser.add_argument('--astar', action='store_true', help='Enable runtime A* detours (planner)')
    gen_parser.add_argument('--astar-hybrid', action='store_true', help='Enable A* hybrid mode (pre-plan routes)')
    gen_parser.add_argument('--astar-resolution', type=float, help='A* grid resolution (m)')
    gen_parser.add_argument('--astar-safety', type=float, help='A* safety margin (m)')
    gen_parser.add_argument('--astar-max', type=int, help='A* max expansions')
    
    # Simple commands
    subparsers.add_parser('start', help='Start mission')
    subparsers.add_parser('stop', help='Stop mission')
    subparsers.add_parser('emergency', help='🚨 Emergency stop — cuts thrust and latches stop')
    subparsers.add_parser('resume', help='Resume mission')
    subparsers.add_parser('reset', help='Reset mission')
    subparsers.add_parser('home', help='🏠 Go home - Return to spawn point')
    subparsers.add_parser('confirm', help='Confirm waypoints')
    subparsers.add_parser('status', help='Show status')
    subparsers.add_parser('interactive', help='Interactive mode')
    
    # PID command
    pid_parser = subparsers.add_parser('pid', help='Set PID parameters')
    pid_parser.add_argument('--kp', type=float, help='Proportional gain')
    pid_parser.add_argument('--ki', type=float, help='Integral gain')
    pid_parser.add_argument('--kd', type=float, help='Derivative gain')
    
    # Speed command
    speed_parser = subparsers.add_parser('speed', help='Set speed parameters')
    speed_parser.add_argument('--base', type=float, help='Base speed')
    speed_parser.add_argument('--max', type=float, help='Max speed')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    rclpy.init()
    cli = MissionCLI()
    
    try:
        if args.command == 'generate':
            cli.generate_waypoints(
                args.lanes, args.length, args.width,
                kp=args.kp, ki=args.ki, kd=args.kd,
                base_speed=args.base, max_speed=args.max, max_turn=args.max_turn,
                stuck_timeout=args.stuck_timeout, stuck_threshold=args.stuck_threshold,
                min_height=args.min_height,
                safe_dist=args.safe_dist, perception_safe_dist=args.perception_safe_dist,
                approach_dist=args.approach_dist,
                approach_factor=args.approach_factor,
                astar=args.astar, astar_hybrid=args.astar_hybrid,
                astar_resolution=args.astar_resolution,
                astar_safety=args.astar_safety, astar_max=args.astar_max
            )
        elif args.command == 'start':
            cli.start_mission()
        elif args.command == 'stop':
            cli.stop_mission()
        elif args.command == 'emergency':
            cli.emergency_stop()
        elif args.command == 'resume':
            cli.resume_mission()
        elif args.command == 'reset':
            cli.reset_mission()
        elif args.command == 'home':
            cli.go_home()
        elif args.command == 'confirm':
            cli.confirm_waypoints()
        elif args.command == 'status':
            cli.show_status()
        elif args.command == 'interactive':
            cli.interactive_mode()
        elif args.command == 'pid':
            cli.set_pid(args.kp, args.ki, args.kd)
        elif args.command == 'speed':
            cli.set_speed(args.base, args.max)
            
        # Keep alive longer to ensure messages are sent and processed
        time.sleep(0.5)
        rclpy.spin_once(cli, timeout_sec=0.2)

    finally:
        cli.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
