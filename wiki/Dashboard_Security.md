# Dashboard Security Assessment

Security posture, known vulnerabilities, and recommended mitigations for the AutoBoat web dashboard.

**Status:** Assessment completed 16/04/2026. Initial code fixes (SRI hashes, server-side `PARAM_RANGES` bounds) landed 17/04/2026; dashboard XSS rendering fixes landed 04/05/2026. Remaining items below.

---

## Current Security Posture

| Layer | Status |
|:------|:-------|
| Authentication | None — no login required |
| Authorization | None — all users have full control (start mission, emergency stop, modify parameters) |
| Transport encryption | None — plain HTTP (8002), WS (9090), HTTP (8080) |
| Network binding | `0.0.0.0` on all 3 ports — accessible to entire LAN |
| Input validation | **Two-layer (since 17/04/2026):** client-side HTML `min`/`max` attributes + server-side `PARAM_RANGES` rejection in each Python node (`heading_controller`, `waypoint_planner`, `lidar_perception`). Out-of-range values rejected with `Rejected <name>=<value> (valid range: lo–hi)` at WARN level. |
| XSS protection | Improved — world banner, rosout terminal, event logs, mission history, and waypoint validation all write dynamic text via `textContent`; no Content Security Policy yet. |

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

#### 2. ~~XSS via `addLog()` event-log helper~~ — Resolved 04/05/2026

Resolved. The generic `addLog(message, type)` helper previously built its DOM via an `innerHTML` template literal with the message body interpolated unescaped. Mission history and waypoint validation used the same string-rendering pattern. All three paths now create DOM nodes explicitly and write dynamic text with `textContent`.

- **File:** `web_dashboard/autoboat/app.js` — `addLog()` function (around L1419)
- **Previous attack vector:** an attacker controls the value passed to a dashboard renderer — typically via something the dashboard quotes back from a remote source — and includes `<script>` tags or `<img onerror=...>`
- **Previous impact:** arbitrary JavaScript execution in the operator's browser
- **Already mitigated (no longer a finding):**
  - **Event logs, mission history, waypoint validation** — dynamic text is written with `.textContent`. **Safe.**
  - **Rosout terminal panel** — `addTerminalLine()` builds the row wrapper via `innerHTML` but writes the actual log message body via `.textContent`, so `<script>` in a ROS log message renders as text. **Safe.**
  - **World banner text** — properly escaped (`<` → `&lt;`).

#### 3. Unencrypted WebSocket

The dashboard connects to rosbridge via plain `ws://` (not `wss://`). All commands and sensor data are visible to network sniffers.

- **File:** `web_dashboard/autoboat/app.js` — WebSocket URL construction
- **Impact:** MITM can read GPS, commands, config; inject fake messages

#### 4. All services bound to 0.0.0.0

The HTTP server, rosbridge, and web_video_server all bind to all network interfaces by default.

- **Files:** `launch/autoboat.launch.yaml` (HTTP server command), rosbridge default config
- **Impact:** any device on the LAN can connect

### High

#### 5. Unauthenticated commands within validated bounds (operational risk)

PID gains, speeds, safety distances, A* settings, and other tunables are now validated **server-side** against `PARAM_RANGES` in each Python node (added 17/04/2026). Out-of-range values are rejected with `Rejected <name>=<value> (valid range: lo–hi)` at WARN level, surfaced as a red toast on the dashboard. So `max_speed: 99999` no longer lands.

**Residual risk:** any LAN client (no auth — see #1) can still send **valid-but-tactically-dangerous** values **within** the allowed bounds — e.g., `max_speed: 800` (the upper bound) at the wrong moment, an emergency-stop release during a near-collision, or a `waypoint_tolerance` so loose the boat skips real targets. Range validation is a guard against numeric mistakes, not against an adversary inside the bounds.

- **Files:** `control/control/heading_controller.py` (`_validate`), `plan/plan/waypoint_planner.py` (`_validate`), `plan/plan/lidar_perception.py` (range check inside config callback)
- **Impact:** range-out values rejected; valid-but-unsafe operational commands still succeed without authentication.

#### 6. Camera topic input — only syntactic validation, no type check

The camera topic input is validated against `ROS_TOPIC_PATTERN` (`/^\/[a-zA-Z0-9_/]+$/`), which blocks URL-special characters (`?`, `#`, `&`, spaces) and enforces ROS-shaped names. As of 23/04/2026 the combobox also restricts the dropdown to topics that `/rosapi/topics_for_type` reports as `sensor_msgs/Image` or `sensor_msgs/CompressedImage`, filtered by an `image_{raw,rect,color,compressed}` name pattern.

Residual gap: free-text input still bypasses the dropdown whitelist, and `web_video_server` does not itself enforce that a requested topic is image-typed — it will subscribe to any name as `sensor_msgs/Image` and leak a zombie subscription if the real publisher type differs.

- **File:** `web_dashboard/autoboat/app.js` — `updateCameraStream`, `populateCameraTopicList`
- **Impact:** attacker with dashboard access can still construct an arbitrary `image_raw`-named stream URL; mostly a nuisance (fails silently) rather than an exfiltration path, but contributes to `web_video_server` state leaks.

#### 7. Direct thrust publishing via rosbridge

rosbridge allows any connected client to publish to `/wamv/thrusters/left/thrust` and `/wamv/thrusters/right/thrust` directly, bypassing the controller entirely.

- **Impact:** network attacker can directly drive the boat's motors

### Medium

#### 8. ~~CDN dependencies without Subresource Integrity~~ — Resolved; downgraded to availability risk

**Resolved.** `roslib.min.js`, `leaflet.js`, and `leaflet.css` in `web_dashboard/autoboat/index.html` (L18–26) all carry `integrity="sha384-…"` + `crossorigin="anonymous"` attributes — a compromised CDN cannot serve malicious replacement code without breaking the SRI check.

**Adjacent risk now in scope:** CDN *availability*. On a network without internet (e.g., the IoT IMT Nord Europe institutional WiFi used for Phase 5 hardware bring-up), the CDNs are unreachable and the dashboard loses critical functionality (no roslib → no boat connection; no Leaflet → no map). Three mitigation paths captured in [Roadmap §1.3](Roadmap#13-iot-imt-nord-europe--local-only-network-constraint-analysed-30042026): vendor libs locally / offline tile server / map-less fallback.

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
| ~~Fix dashboard XSS renderers~~ | **Already done 04/05/2026** — `addLog()`, mission history, and waypoint validation now write dynamic text with `textContent`, mirroring the rosout terminal pattern. | `app.js` |
| Bind to localhost | Add `-b 127.0.0.1` to `python3 -m http.server 8002` in the launch script and docs | `launch_autoboat_complete.sh`, `autoboat.launch.yaml` |
| ~~Add SRI hashes~~ | **Already done** — `index.html` `<script>` tags for `roslib`, `leaflet.js`, and `leaflet.css` carry `integrity="sha384-…"` + `crossorigin="anonymous"` attributes. | (no action) |

### Moderate hardening (~3-5 hours)

| Fix | What to do |
|:----|:-----------|
| Basic authentication | Use nginx as a reverse proxy with `htpasswd` for HTTP basic auth in front of all 3 ports |
| Enable WSS/HTTPS | Configure nginx TLS termination with a self-signed certificate for LAN use |
| Whitelist camera topics | **Partially implemented 23/04/2026** — combobox dropdown is restricted to topics advertising `sensor_msgs/Image` via `/rosapi/topics_for_type`, plus an `image_raw`/`image_rect`/etc. name-pattern filter. Remaining gap: free-text input in the same field still bypasses the whitelist; a complete fix would reject non-image topics at `updateCameraStream` entry before hitting web_video_server. |
| ~~Server-side param bounds~~ | **Already done 17/04/2026** — `PARAM_RANGES` rejection in each node's config callback (`heading_controller`, `waypoint_planner`, `lidar_perception`). See finding #5 above for the residual operational risk (valid-but-tactically-dangerous values within bounds + missing auth). |

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
