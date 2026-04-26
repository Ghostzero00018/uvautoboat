import os
import re
import subprocess
import threading
from pathlib import Path

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from std_srvs.srv import Trigger

# Derive the script path from this file's location instead of hardcoding
# ~/seal_ws/... so the dashboard Health Check works regardless of where the
# workspace lives on disk (matches the pattern used in autoboat_cli.py).
_REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = str(_REPO_ROOT / 'one_click_launch_all' / 'health_check_autoboat.sh')
ANSI_ESCAPE = re.compile(r'\x1b\[[0-9;]*m')


class HealthCheckService(Node):
    def __init__(self):
        super().__init__('health_check_service')
        self.srv = self.create_service(Trigger, '/health_check/run', self.handle_run)
        self.line_pub = self.create_publisher(String, '/health_check/line', 100)
        self.status_pub = self.create_publisher(String, '/health_check/status', 10)
        self._lock = threading.Lock()
        self._running = False
        self.get_logger().info(
            f'Health check service ready: call /health_check/run, subscribe /health_check/line (script: {SCRIPT_PATH})'
        )

    def handle_run(self, request, response):
        with self._lock:
            if self._running:
                response.success = False
                response.message = 'A health check is already running — wait for the current one to finish.'
                return response
            self._running = True

        if not os.path.isfile(SCRIPT_PATH):
            with self._lock:
                self._running = False
            response.success = False
            response.message = f'Health check script not found at {SCRIPT_PATH}'
            self.get_logger().error(response.message)
            return response

        thread = threading.Thread(target=self._run_script, daemon=True)
        thread.start()

        response.success = True
        response.message = 'Health check started — lines will stream to /health_check/line'
        return response

    def _run_script(self):
        self.get_logger().info('Running health check...')
        self._publish_status('running')
        exit_ok = False
        process = None
        timed_out = threading.Event()
        watchdog = None
        try:
            process = subprocess.Popen(
                ['bash', SCRIPT_PATH],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )

            # Wall-clock watchdog: fires after 90 s regardless of whether the
            # script is producing output. The previous `process.wait(timeout=90)`
            # only ran AFTER the stdout iterator drained, so a script that hung
            # without writing anything would never reach the timeout path.
            def _kill_on_timeout():
                timed_out.set()
                try:
                    process.kill()
                except Exception:
                    pass

            watchdog = threading.Timer(90.0, _kill_on_timeout)
            watchdog.daemon = True
            watchdog.start()

            for line in process.stdout:
                clean = ANSI_ESCAPE.sub('', line.rstrip('\n'))
                self._publish_line(clean)
            process.wait()

            if timed_out.is_set():
                self._publish_line('[ERROR] Health check timed out after 90 seconds (script may have hung without output)')
                self.get_logger().error('Health check timed out')
            else:
                exit_ok = (process.returncode == 0)
                self.get_logger().info(f'Health check finished (exit={process.returncode})')
        except Exception as e:
            self._publish_line(f'[ERROR] Health check failed: {e}')
            self.get_logger().error(f'Health check failed: {e}')
        finally:
            if watchdog is not None:
                watchdog.cancel()

        self._publish_status('ok' if exit_ok else 'error')

        with self._lock:
            self._running = False

    def _publish_line(self, text):
        msg = String()
        msg.data = text
        self.line_pub.publish(msg)

    def _publish_status(self, status):
        msg = String()
        msg.data = status
        self.status_pub.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = HealthCheckService()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    rclpy.shutdown()


if __name__ == '__main__':
    main()
