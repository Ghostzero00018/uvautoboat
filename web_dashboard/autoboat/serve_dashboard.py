"""Dashboard HTTP server with security headers.

Drop-in replacement for `python3 -m http.server 8002` that adds the CSP +
X-Content-Type-Options + Referrer-Policy headers documented in the
wiki/Dashboard_Security.md "Content Security Policy" section.

Usage:
    python3 serve_dashboard.py [PORT] [BIND] [HOST]

Defaults: PORT=8002, no bind override (matches `python3 -m http.server 8002`).
HOST defaults to per-request derivation from the browser's Host header — the
CSP allowlist for rosbridge (:9090) and web_video_server (:8080) automatically
matches whatever URL the operator typed (IP, hostname, or .local mDNS name).
This handles every field-network shape (LAN IP, direct AP, mDNS) without
launcher changes. Pass an explicit HOST to lock the CSP to one host
(e.g., `python3 serve_dashboard.py 8002 0.0.0.0 192.168.4.1` for a
deployment where the operator station should only reach the boat at one
specific IP).

For local-only binding, use `python3 serve_dashboard.py 8002 127.0.0.1`.
"""

import http.server
import re
import sys


# Matches IPv4, hostnames, and .local mDNS names (alphanumeric + dot + hyphen).
# IPv6 in brackets isn't covered yet; field deployment is IPv4-only for now.
HOST_PATTERN = re.compile(r'^[a-zA-Z0-9.\-]+$')


def parse_request_host(host_header):
    """Strip port + validate format. Return safe host or 'localhost' on bad input."""
    if not host_header:
        return 'localhost'
    host = host_header.rsplit(':', 1)[0].strip('[]').strip()
    if HOST_PATTERN.match(host) and len(host) <= 253:
        return host
    return 'localhost'


def build_csp(host):
    """Build the CSP string allowing localhost + the given host on :8080 / :9090."""
    return (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self'; "
        "font-src 'self' data:; "
        "img-src 'self' data: https://*.tile.openstreetmap.org "
        f"http://localhost:8080 http://127.0.0.1:8080 http://{host}:8080; "
        f"connect-src 'self' ws://localhost:9090 ws://127.0.0.1:9090 ws://{host}:9090; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'; "
        "object-src 'none';"
    )


def make_handler(explicit_host):
    """Build a handler class. If explicit_host is set, lock CSP to it;
    otherwise derive host per-request from the Host header."""

    class SecureHandler(http.server.SimpleHTTPRequestHandler):
        def end_headers(self):
            host = explicit_host or parse_request_host(self.headers.get('Host', ''))
            self.send_header("Content-Security-Policy", build_csp(host))
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
            super().end_headers()

    return SecureHandler


def main():
    """Parse argv for port + bind + host and start the server."""
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8002
    bind = sys.argv[2] if len(sys.argv) > 2 else None
    explicit_host = sys.argv[3] if len(sys.argv) > 3 else None
    if explicit_host:
        print(f"[serve_dashboard] CSP host locked: {explicit_host}", file=sys.stderr)
    else:
        print("[serve_dashboard] CSP host derived per-request from Host header", file=sys.stderr)
    http.server.test(HandlerClass=make_handler(explicit_host), port=port, bind=bind)


if __name__ == "__main__":
    main()
