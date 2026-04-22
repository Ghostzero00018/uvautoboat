# Dashboard Security Assessment

Security posture, known vulnerabilities, and recommended mitigations for the AutoBoat web dashboard.

**Status:** Assessment completed 16/04/2026. No code fixes applied yet — documentation only.

---

## Current Security Posture

| Layer | Status |
|:------|:-------|
| Authentication | None — no login required |
| Authorization | None — all users have full control (start mission, emergency stop, modify parameters) |
| Transport encryption | None — plain HTTP (8002), WS (9090), HTTP (8080) |
| Network binding | `0.0.0.0` on all 3 ports — accessible to entire LAN |
| Input validation | Client-side only (HTML `min`/`max` attributes in `index.html`) |
| XSS protection | Partial — world banner escaped, but rosout log messages inserted via `innerHTML` without escaping |

### Open Ports

| Port | Service | Protocol | Binding | Auth | TLS |
|:-----|:--------|:---------|:--------|:-----|:----|
| 8002 | Dashboard HTTP server | HTTP | 0.0.0.0 | None | No |
| 9090 | rosbridge_websocket | WS | 0.0.0.0 | None | No |
| 8080 | web_video_server | HTTP | 0.0.0.0 | None | No |

---

## Known Vulnerabilities

### Critical

#### 1. No authentication

Anyone on the same network can access `http://<boat-ip>:8002` and immediately control the boat — start missions, change parameters, trigger emergency stop, modify waypoints.

- **Files:** entire dashboard (`app.js`, `index.html`)
- **Impact:** full unauthorized control

#### 2. XSS in terminal log panel

ROS log messages from `/rosout` are inserted into the DOM via `innerHTML` without HTML escaping.

- **File:** `web_dashboard/autoboat/app.js` (log display function)
- **Attack vector:** a ROS node publishes a log message containing `<script>` tags — the dashboard executes it
- **Impact:** arbitrary JavaScript execution in the operator's browser
- **Note:** the world banner text IS properly escaped (`<` → `&lt;`), but the log panel is not

#### 3. Unencrypted WebSocket

The dashboard connects to rosbridge via plain `ws://` (not `wss://`). All commands and sensor data are visible to network sniffers.

- **File:** `web_dashboard/autoboat/app.js` — WebSocket URL construction
- **Impact:** MITM can read GPS, commands, config; inject fake messages

#### 4. All services bound to 0.0.0.0

The HTTP server, rosbridge, and web_video_server all bind to all network interfaces by default.

- **Files:** `launch/autoboat.launch.yaml` (HTTP server command), rosbridge default config
- **Impact:** any device on the LAN can connect

### High

#### 5. No server-side parameter validation

PID gains, speeds, safety distances, and A* settings are validated only by HTML `min`/`max` attributes in the browser. A network attacker bypassing the dashboard can send arbitrary values directly to rosbridge.

- **File:** `web_dashboard/autoboat/app.js` — config send functions
- **Impact:** dangerous parameter values (e.g., `max_speed: 99999`) accepted by ROS nodes

#### 6. Camera topic input unsanitized

The camera topic input field passes user-provided strings directly to web_video_server without validation.

- **File:** `web_dashboard/autoboat/app.js` — camera stream URL construction
- **Impact:** arbitrary ROS topic data could be requested via web_video_server

#### 7. Direct thrust publishing via rosbridge

rosbridge allows any connected client to publish to `/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust` directly, bypassing the controller entirely.

- **Impact:** network attacker can directly drive the boat's motors

### Medium

#### 8. CDN dependencies without Subresource Integrity

`roslib.js` and `leaflet.js` are loaded from CDNs (`cdn.jsdelivr.net`, `unpkg.com`) without SRI hashes.

- **File:** `web_dashboard/autoboat/index.html` — `<script>` tags
- **Impact:** if the CDN is compromised, malicious JavaScript runs in the dashboard

#### 9. GPS coordinates exposed to OpenStreetMap

Map tile requests to `https://tile.openstreetmap.org` include the viewport coordinates, revealing the boat's approximate location to the tile provider.

#### 10. Cached waypoints in localStorage

Waypoint coordinates are stored in `localStorage` under `autoboat_cached_waypoints`, readable by browser extensions or other scripts on the same origin.

#### 11. Full ROS logs visible

The `/rosout` subscription displays all debug/info/warning/error messages from all nodes, which may expose internal file paths, parameter values, and system state.

---

## Risk by Environment

| Environment | Risk | Key concern |
|:------------|:-----|:------------|
| **Local machine (simulation)** | Low | Only you can access; acceptable for development |
| **Lab network (controlled)** | Low-Medium | Trusted users, but accidental interference possible if multiple teams share the network |
| **Campus / shared WiFi** | High | Untrusted devices can discover open ports and control the boat |
| **Field deployment (real hardware)** | Critical | Physical safety — unauthorized commands could damage hardware or endanger people nearby |

---

## Recommended Mitigations (Future Work)

### Quick fixes (~1-2 hours)

| Fix | What to do | Files |
|:----|:-----------|:------|
| Fix XSS | Escape HTML entities in rosout messages before `innerHTML` assignment (use `textContent` or manual escaping) | `app.js` |
| Bind to localhost | Add `-b 127.0.0.1` to `python3 -m http.server 8002` in the launch script and docs | `launch_autoboat_complete.sh`, `autoboat.launch.yaml` |
| Add SRI hashes | Add `integrity` and `crossorigin` attributes to CDN `<script>` tags | `index.html` |

### Moderate hardening (~3-5 hours)

| Fix | What to do |
|:----|:-----------|
| Basic authentication | Use nginx as a reverse proxy with `htpasswd` for HTTP basic auth in front of all 3 ports |
| Enable WSS/HTTPS | Configure nginx TLS termination with a self-signed certificate for LAN use |
| Whitelist camera topics | Validate camera topic input against a list of known sensor topics before constructing the URL |
| Server-side param bounds | Add `min`/`max` range checks in the Python nodes' `config_callback` functions |

### Full hardening (future architecture)

| Fix | What to do |
|:----|:-----------|
| Token-based auth for rosbridge | Configure rosbridge authentication (requires custom middleware or rosbridge fork) |
| Role-based access control | Define viewer (read-only) / operator (commands) / admin (config) roles |
| Audit logging | Log all mission commands with timestamp, source IP, and command type |
| Network segmentation | Run ROS on an isolated subnet; dashboard on a gateway with firewall rules |
| End-to-end encryption | Encrypt sensitive data in localStorage; use HTTPS for all external requests |

---

## Usage Guidelines

### For development (local simulation)

No special precautions needed. The dashboard is designed for this use case.

### For shared networks (campus WiFi, lab)

Restrict access with a firewall before launching:

```bash
# Allow only your IP to access dashboard ports
sudo ufw allow from <your-ip> to any port 8002
sudo ufw allow from <your-ip> to any port 9090
sudo ufw allow from <your-ip> to any port 8080
sudo ufw deny 8002
sudo ufw deny 9090
sudo ufw deny 8080
```

Or bind services to localhost only (prevents all remote access):

```bash
# In launch script, change the HTTP server command to:
python3 -m http.server -b 127.0.0.1 8002
```

### For field deployment

**Do not deploy on real hardware without implementing at least the "moderate hardening" mitigations.** Unauthorized motor commands on a physical boat pose safety risks.

### General rules

- Never expose ports 8002, 9090, or 8080 to the internet
- Never run the dashboard on untrusted public WiFi without firewall rules
- If multiple teams share a network, use different `ROS_DOMAIN_ID` values to isolate ROS traffic (but note: this does not protect the dashboard HTTP/WS ports)

---

## See Also

- **[System_Overview](System_Overview)** — Architecture and web communication stack
- **[Design_Rationale](Design_Rationale)** — Why ROSBridge + web dashboard was chosen
- **[Common_Issues](Common_Issues)** — Dashboard connection troubleshooting
