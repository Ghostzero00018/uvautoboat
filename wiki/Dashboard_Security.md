# Dashboard Security Assessment

Security posture, known vulnerabilities, and recommended mitigations for the AutoBoat web dashboard.

**Status:** Assessment completed 16/04/2026. Initial code fixes (SRI hashes, server-side `PARAM_RANGES` bounds) landed 17/04/2026; dashboard XSS rendering fixes landed 04/05/2026; CSP wrapper + CDN-free Path A vendoring landed 05/05/2026; CSP `'unsafe-inline'` drop on `script-src` + `style-src` + per-request Host derivation landed 06/05/2026. Remaining items below.

---

## Current Security Posture

| Layer | Status |
|:------|:-------|
| Authentication | None — no login required |
| Authorization | None — all users have full control (start mission, emergency stop, modify parameters) |
| Transport encryption | None — plain HTTP (8002), WS (9090), HTTP (8080) |
| Network binding | `0.0.0.0` on all 3 ports — accessible to entire LAN |
| Input validation | **Two-layer (since 17/04/2026):** client-side HTML `min`/`max` attributes + server-side `PARAM_RANGES` rejection in each Python node (`heading_controller`, `waypoint_planner`, `lidar_perception`). Out-of-range values rejected with `Rejected <name>=<value> (valid range: lo–hi)` at WARN level. |
| XSS protection | Improved — world banner, rosout terminal, event logs, mission history, and waypoint validation all write dynamic text via `textContent`. CSP wrapper deployed 05/05/2026 (CDN-free after Roadmap §1.3 path A vendoring landed same day); `'unsafe-inline'` dropped from `script-src` + `style-src` 06/05/2026 — see [Content Security Policy](#content-security-policy) below. |

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

- **File:** `web_dashboard/autoboat/app.js` — `addLog()` function (around L1432)
- **Previous attack vector:** an attacker controls the value passed to a dashboard renderer — typically via something the dashboard quotes back from a remote source — and includes `<script>` tags or `<img onerror=...>`
- **Previous impact:** arbitrary JavaScript execution in the operator's browser
- **Already mitigated (no longer a finding):**
  - **Event logs, mission history, waypoint validation** — dynamic text is written with `.textContent`. **Safe.**
  - **Rosout terminal panel** — `addTerminalLine()` builds the row wrapper via `innerHTML` but writes the actual log message body via `.textContent`, so `<script>` in a ROS log message renders as text. **Safe.**
  - **World banner text** — properly escaped (`<` → `&lt;`).
- **Defense-in-depth (05/05/2026):** the CSP wrapper (`web_dashboard/autoboat/serve_dashboard.py`) blocks any future renderer regression from executing scripts loaded from non-allowed origins, plus inline `eval` is excluded entirely. See [Content Security Policy](#content-security-policy) below.

#### 3. Unencrypted WebSocket

The dashboard connects to rosbridge via plain `ws://` (not `wss://`). All commands and sensor data are visible to network sniffers.

- **File:** `web_dashboard/autoboat/app.js` — WebSocket URL construction
- **Impact:** MITM can read GPS, commands, config; inject fake messages
- **Residual after 05/05/2026 CSP wrapper + 06/05/2026 tightening:** CSP `connect-src` allows `ws://` only to localhost + the host the operator typed (derived per-request from the HTTP `Host` header). This closes the XSS-redirect-WS vector — an injected script cannot redirect the dashboard to a malicious `ws://` endpoint outside the same host. Does NOT address transport encryption — anyone on the LAN can still passively sniff or actively MITM the rosbridge connection. The proper fix remains WSS termination via reverse proxy (Moderate hardening table below).

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

#### 8. ~~CDN dependencies without Subresource Integrity~~ — Resolved; OSM tile availability remains

**Resolved.** This was first mitigated with SRI on 17/04/2026, then superseded by Path A vendoring on 05/05/2026: `roslib.min.js`, Leaflet JS/CSS/images, and Google Fonts now self-load from `web_dashboard/autoboat/vendor/`. Same-origin loads no longer need CDN SRI, and the CDN-compromise vector is gone.

**Adjacent risk now in scope:** tile-server availability. On a network without internet (e.g., the IoT IMT Nord Europe institutional WiFi used for Phase 5 hardware bring-up), dashboard libraries load locally but OpenStreetMap tiles remain unreachable. Path B in [Roadmap §1.3](Roadmap#13-iot-imt-nord-europe--local-only-network-constraint-analysed-30042026) tracks the offline tile server + pre-generated MBTiles mitigation.

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
| Bind to localhost | Pass `127.0.0.1` as the bind arg to `serve_dashboard.py` (e.g., `python3 serve_dashboard.py 8002 127.0.0.1`) in the launch script and docs | `launch_autoboat_complete.sh`, `autoboat.launch.yaml` |
| ~~Add SRI hashes~~ | **Superseded by Path A 05/05/2026** — SRI was added on 17/04 for CDN loads, then removed when `roslib`, Leaflet, and fonts were vendored under same-origin `vendor/`. | (no action) |

### Moderate hardening (~3-5 hours)

| Fix | What to do |
|:----|:-----------|
| Basic authentication | Use nginx as a reverse proxy with `htpasswd` for HTTP basic auth in front of all 3 ports (lands with [Option B](#implementation-paths-recommended-order-of-adoption)) |
| Enable WSS/HTTPS | Configure nginx TLS termination with a self-signed certificate for LAN use (lands with [Option B](#implementation-paths-recommended-order-of-adoption)) |
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

### Content Security Policy

The dashboard's HTTP server (port 8002) sets a CSP header on every response. The CSP blocks any future regression that re-introduces an `innerHTML`-style injection from executing scripts loaded from non-allowed origins, complementing the 04/05/2026 renderer-fix pass (which closed the active injection sites at the source). Implementation in `web_dashboard/autoboat/serve_dashboard.py` (Option A landed 05/05/2026; tightening landed 06/05/2026).

#### Inventory of external loads (post-path-A)

CDN libraries (`roslibjs`, Leaflet JS + CSS + 5 marker / layer images, Google Fonts CSS + 7 WOFF2 files) vendored under `web_dashboard/autoboat/vendor/` since 05/05/2026 (~516 KB); dashboard now self-serves them. Three external loads remain:

| Resource | Origin | Source line |
|:--|:--|:--|
| OSM tiles | `https://*.tile.openstreetmap.org` | `app.js:354` |
| rosbridge WebSocket | `ws://<host>:9090` | `app.js:518` |
| MJPEG camera stream | `http://<host>:8080` | dashboard `<img>` element |

#### Inline-content + eval scan (constraints on the policy)

- Inline `<script>` blocks: 0 — both originals (`index.html:11`, `:971`) externalized 05/05/2026 (commit `da3ec76`).
- Inline `style="…"` attributes: 0 — 21 static attrs migrated to CSS classes 05/05/2026 (commit `a189b48`); runtime style writes / generated style attributes in `app.js` migrated to CSS classes + variables across the (D)-runtime-1/2/3 commits 05/05–06/05/2026.
- Two CSSOM `setProperty('--bar-width', ...)` calls remain in `app.js` (thrust + mission progress bars). These set a CSS custom property; the actual width rule lives in the same-origin `style_merged.css` (`width: var(--bar-width, 0%)`). Browser CSP enforcement of CSSOM writes for custom properties is the one residual surface; verified working on Firefox + Chrome at the 06/05 browser-test gate.
- No `eval()` / `new Function()` / string-form `setTimeout` in `app.js` → `'unsafe-eval'` **not** needed.
- No inline event handlers (`onclick=`, etc.) → modern listeners only.

#### Deployed header

```text
default-src 'self';
script-src 'self';
style-src 'self';
font-src 'self' data:;
img-src 'self' data: https://*.tile.openstreetmap.org http://localhost:8080 http://127.0.0.1:8080 http://<host>:8080;
connect-src 'self' ws://localhost:9090 ws://127.0.0.1:9090 ws://<host>:9090;
frame-ancestors 'none';
base-uri 'self';
form-action 'self';
object-src 'none';
```

`<host>` is derived per-request from the HTTP `Host` header — typically `localhost` for dev, the workstation's LAN IP for field deployment, or an mDNS hostname like `boat-pi.local`. Validated via regex (alphanumeric + dot + hyphen, length ≤ 253); malformed input falls back to `localhost`. Lock to a specific host with `python3 serve_dashboard.py 8002 0.0.0.0 <explicit-IP>`.

| Directive | Why |
|:--|:--|
| `default-src 'self'` | Deny-by-default fallback for any directive not explicitly listed |
| `script-src` | `'self'` only — CDN libraries (roslibjs, Leaflet) vendored locally 05/05/2026 (path A); `'unsafe-inline'` dropped 06/05/2026 after the 2 inline `<script>` blocks were externalized |
| `style-src` | `'self'` only — Leaflet CSS + Google Fonts CSS vendored locally 05/05/2026 (path A); `'unsafe-inline'` dropped 06/05/2026 after static `index.html` inline styles + runtime `app.js` style writes all migrated to CSS classes / variables |
| `font-src` | `'self'` only — Google Fonts WOFF2 vendored locally 05/05/2026 (path A); `data:` for any inline-encoded fallback fonts |
| `img-src` | OSM tiles (3-subdomain wildcard) + MJPEG stream + `data:` for inline favicons / canvas exports. Per-request Host derivation (06/05/2026) appends the request host at `:8080` automatically — covers localhost, LAN IP, and `.local` mDNS hostnames without launcher changes. |
| `connect-src` | Specific `ws://` hosts the dashboard targets — localhost variants + the per-request Host (06/05/2026) so the operator station can reach rosbridge from any same-host URL the browser used. |
| `frame-ancestors 'none'` | Anti-clickjacking — the dashboard is full-page, never embedded |
| `base-uri 'self'` | Block injected `<base href="evil">` redirecting relative links |
| `form-action 'self'` | Defensive (no `<form>`s today, cheap insurance) |
| `object-src 'none'` | No `<object>` / `<embed>` ever needed |

#### Implementation paths (recommended order of adoption)

| Option | Cost | Mechanism |
|:--|:--|:--|
| **A — Wrapper Python script** ✅ landed 05/05/2026 (commit `50ae2af`); tightened 06/05/2026 | ~80 LOC, single file | `web_dashboard/autoboat/serve_dashboard.py` subclasses `SimpleHTTPRequestHandler`, overrides `end_headers()` to inject `Content-Security-Policy` + `X-Content-Type-Options: nosniff` + `Referrer-Policy: strict-origin-when-cross-origin` (modern-browser default; satisfies OSM tile-server's Referer-required policy while still stripping path/query from cross-origin requests). 06/05 update added per-request Host derivation: each response carries a CSP whose `img-src` / `connect-src` allowlist matches the URL the operator typed, validated via regex (alphanumeric + dot + hyphen, length ≤ 253). Argv override available for explicit lock. Drop-in replacement for `python3 -m http.server 8002` in the launch script + docs. |
| **B — Reverse-proxy header injection** (planned; gated on auth landing) | nginx site config (~60 LOC), self-signed cert, htpasswd file, one extra systemd unit | nginx terminates TLS on a single front door (e.g., `https://<host>:8443`) and reverse-proxies all three backends (`/` → :8002, `/ws/` → :9090, `/stream/` → :8080); backends rebind to `127.0.0.1` only (drop from `0.0.0.0`). CSP injection moves to `add_header Content-Security-Policy "..." always;` in the front-door `server` block (the `always` flag matters — without it nginx skips the header on non-2xx responses, silently dropping CSP on 404s and 5xx error pages); `X-Content-Type-Options nosniff` and `Referrer-Policy strict-origin-when-cross-origin` likewise. Per-request Host (Option A's `parse_request_host()` equivalent) becomes `set $csp_host $host;` plus a `map` block validating against the same regex character class (alphanumeric + dot + hyphen, falling back to `localhost` on miss). WSS upgrade: rosbridge stays plain `ws://` on `127.0.0.1:9090`; nginx terminates TLS at the front door with the standard `Upgrade` / `Connection: upgrade` headers under `location /ws/`; CSP `connect-src` flips from `ws://<host>:9090` to `wss://<host>:8443/ws/` — this is the actual transport-encryption fix for finding #3. MJPEG: `location /stream/ { proxy_pass http://127.0.0.1:8080/; }`; CSP `img-src` flips to `https://<host>:8443/stream/` (one-character `app.js` base-URL flip required — only client-side change). Auth: `auth_basic "AutoBoat Dashboard"; auth_basic_user_file /etc/nginx/autoboat.htpasswd;` lands the Moderate-hardening "Basic authentication" row in the same commit. Wrapper-script change: `serve_dashboard.py` keeps its CSP injection as defense-in-depth on direct-to-`127.0.0.1:8002` fallback — only the launch-script bind flag flips from `0.0.0.0` to `127.0.0.1`. Drop-in front door for the existing 3-port surface; lands auth + WSS + CSP in one commit. |
| **C — Caddy / external static webserver** | new runtime dependency | Caddy supports `header` directives natively in its Caddyfile |

Option A landed 05/05/2026 (initial CSP) and tightened 06/05/2026 (drop `'unsafe-inline'` + per-request Host derivation) — confirmed end-to-end via curl + browser hard-refresh on the live :8002. Option B remains the long-term destination once auth lands.

**Triggers for switching A → B (any one suffices):**

- **Authentication becomes mandatory.** Any deployment beyond solo-developer-on-trusted-LAN exposes finding #5 (valid-but-tactically-dangerous commands within bounds, no auth). Today's CSP only closes the XSS-redirect-WS vector (finding #3 residual); it does not address direct rosbridge writes from any LAN client.
- **WSS/HTTPS becomes mandatory.** Triggered by either (a) a browser deprecating mixed-content WS in a future release; or (b) a deployment on a shared / untrusted network where passive sniffing or active MITM of rosbridge traffic is in scope (campus WiFi, public IoT, real-hardware field test outside the lab).
- **Operator-UX consolidation.** Single URL instead of three ports + the same boat IP three times — relevant once non-developer operators are in the loop.

**Migration shape.** Single-shot: install nginx, drop in the site config (~60 LOC), generate cert + htpasswd, flip launcher binds from `0.0.0.0` to `127.0.0.1`, flip the dashboard's WS + MJPEG base URLs (one constant each in `app.js`). The wrapper's CSP injection stays as defense-in-depth — it's idempotent under nginx's own `add_header` (last-header-wins for `Content-Security-Policy` is browser-defined, but in practice both layers carrying the same policy is safe).

**Tightening status.** [Roadmap §1.3](Roadmap#13-iot-imt-nord-europe--local-only-network-constraint-analysed-30042026) **path A landed 05/05/2026** — `roslibjs` + Leaflet (JS + CSS + 5 marker / layer images) + Google Fonts (CSS + 7 WOFF2 files for 4 weights × 7 unicode subsets) all vendored under `web_dashboard/autoboat/vendor/`, ~516 KB total. Three CDN allowances dropped from the live CSP (`script-src` no longer `cdn.jsdelivr.net` + `unpkg.com`; `style-src` no longer `unpkg.com` + `fonts.googleapis.com`; `font-src` no longer `fonts.gstatic.com`). **`'unsafe-inline'` removal landed 06/05/2026** — the 2 inline `<script>` blocks were externalized 05/05 (`da3ec76`); the 21 static `index.html` inline styles migrated to CSS classes 05/05 (`a189b48`); the runtime `app.js` style writes / generated style attributes migrated to CSS classes + variables 05/05–06/05 (D-runtime-1/2/3 commits). Both `script-src` and `style-src` now `'self'` only. Dashboard runs offline-capable for the 3 main library deps; only OSM tiles + MJPEG stream remain external.

One remaining hardening pass:

1. **OSM tile vendoring** — Roadmap §1.3 path B: pre-generate MBTiles for the test region, serve from a local tile server. Once that lands, `img-src` drops `https://*.tile.openstreetmap.org` and instead allows the local tile origin. Required before first IoT-network deployment.

**Catches / doesn't catch.** Catches any future regression that re-introduces an `innerHTML` attack surface — a malicious payload still cannot fetch `script-src` from a non-allowed origin and inline-`eval` is the only remaining vector (excluded via no `'unsafe-eval'`); also catches DOM-clobbering and inline-event-handler vectors. Does **not** catch the operational risk surfaced as finding #5 (valid-but-tactically-dangerous values within bounds, no auth) — that's a different layer, addressed via auth + token-RBAC per the Moderate-hardening / Full-hardening tables above.

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
python3 serve_dashboard.py 8002 127.0.0.1
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
