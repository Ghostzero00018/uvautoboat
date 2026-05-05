"""Dashboard HTTP server with security headers.

Drop-in replacement for `python3 -m http.server 8002` that adds the CSP +
X-Content-Type-Options + Referrer-Policy headers documented in the
wiki/Dashboard_Security.md "Proposed Content Security Policy" section.

Usage:
    python3 serve_dashboard.py [PORT] [BIND]

Defaults: PORT=8002, no bind override (matches `python3 -m http.server 8002`).
For local-only binding, use `python3 serve_dashboard.py 8002 127.0.0.1`.
"""

import http.server
import sys


CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline'; "
    "style-src 'self' 'unsafe-inline'; "
    "font-src 'self' data:; "
    "img-src 'self' data: https://*.tile.openstreetmap.org "
    "http://localhost:8080 http://127.0.0.1:8080; "
    "connect-src 'self' ws://localhost:9090 ws://127.0.0.1:9090; "
    "frame-ancestors 'none'; "
    "base-uri 'self'; "
    "form-action 'self'; "
    "object-src 'none';"
)


class SecureHandler(http.server.SimpleHTTPRequestHandler):
    """SimpleHTTPRequestHandler subclass that adds security headers."""

    def end_headers(self):
        """Inject security headers before the standard headers terminate."""
        self.send_header("Content-Security-Policy", CSP)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        super().end_headers()


def main():
    """Parse argv for port + bind address and start the server."""
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8002
    bind = sys.argv[2] if len(sys.argv) > 2 else None
    http.server.test(HandlerClass=SecureHandler, port=port, bind=bind)


if __name__ == "__main__":
    main()
