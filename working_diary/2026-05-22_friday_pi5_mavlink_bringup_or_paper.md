# 2026-05-22 — Friday: Pi 5 Block A (live) or Slab 3 / 4 (paper)

## Day overview

Pi-availability-conditional day continuing from Thu 21/05/2026 ([`2026-05-21`](2026-05-21_thursday_pi5_mavlink_bridge_deploy.md)):

- **If Pi 5 back + reflashed and reachable** (prof finished setup, control box returned): live Block A pre-flight using yesterday's `## Afternoon prep — Fast Block A pre-flight checklist` (4-step gate: OS identification → baseline access + Pi-side state → Route 1 viability → route decision + go / no-go for Block B). Promote to Block B install (Route 1 = apt `ros-jazzy-mavros` default per Thu §D.1) if Block A green.
- **If Pi 5 still at prof's office**: paper-day. Pick up slab 3 (Pi-side `systemd` autostart strategy for the bridge) or slab 4 (hardware-design pass layout sketch — regulated ≥5A 5V supply, bulk caps, USB hub for RealSense decoupling) — both deferred from Thu.

Final commitment is a Block A decision based on actual Pi availability when the day starts.

## Boundaries

- **In scope:** live Block A pre-flight + Block B install (if Pi back) OR slab 3 / 4 paper deliverable (if Pi missing), plus debrief + action-item capture.
- **Out of scope:** controller integration, autoboat-stack launch rewiring, repo `.py` / `.yaml` edits, premature `Board.md` / `wiki/Roadmap.md` edits (defer to Block D).
- **Pi 5 OS posture:** full desktop GUI image (per 21/05/2026 supervisor reversal of the 13/05/2026 "headless permanently" directive). DE / GUI / VNC-server proposals on the Pi are unblocked. Exact OS the prof flashed (Ubuntu Desktop / RPi OS Bookworm / Server-plus-DE) unknown until Block A — drives the §D.1 decision tree from Thu (RPi OS Bookworm forces Route 2 source build; Ubuntu variants keep Route 1 viable).
- **13/05 Pi-side state is gone post re-flash** — ROS 2 Jazzy install, SSH keys, dialout config, `/boot/firmware/config.txt` + `logind.conf` edits. Bring-up effectively restarts. Yesterday's prep checklist Step 2 already accounts for this.
- **Validation methodology** Three Ask: still pending external confirmation (teammate maintainer reply or 03/06/2026 meeting). Not blocking today; carry forward.

## Block A — Pre-flight (≈ 30 min if live; ≈ 5 min "Pi unavailable" call if not)

Live branch — drive Thu's `## Afternoon prep — Fast Block A pre-flight checklist` 4-step gate:

- [x] **Step 1** — Identify OS / image the prof flashed (`cat /etc/os-release`, `lsb_release -a`, `dpkg --print-architecture`, `uname -a`). Match against the 4-row branch table.
- [x] **Step 2** — Baseline access + Pi-side state (SSH from workstation; on Pi: hostname / dialout / UART / device nodes for autopilot link; ROS 2 Jazzy install present?).
- [x] **Step 3** — Route 1 viability gate (`packages.ros.org` reachable? `apt-cache policy ros-jazzy-mavros` shows candidate? — closes the live-confirmation gap left open at end of Thu).
- [x] **Step 4** — Route decision per Thu §D.1 decision tree + go / no-go for Block B.

Paper branch (Pi unavailable): record blocked state; pivot to slab 3 or slab 4. Capture the slab choice rationale in Block A Outcome.

**Outcome:** Pre-flight green across all four steps. Step 1 OS = Ubuntu Desktop 24.04.4 LTS Noble on `linux-raspi` 6.8.0-1056 (aarch64) — Tier 1 for ROS 2 Jazzy per REP-2000, drives §D.1 decision-tree branch 1. Step 2 baseline: hostname `imtaquadrone-desktop`, login `imt-aqua-drone` (uid 1000, in `sudo` ✓ but NOT in `dialout` — queued for Block B prep), IP `10.120.2.162/23` on `wlan0` (DHCP reassigned post-reflash from `.50`), `enable_uart=1` in `/boot/firmware/config.txt` ✓, no `/dev/ttyUSB*` / `/dev/ttyACM*` / `/dev/serial/by-id/` entries (autopilot not physically present today), ROS 2 Jazzy pre-installed by the prof (`/opt/ros/jazzy/bin/ros2` present; `ros-jazzy-ros-base` `0.11.0-1noble.20260413.034045`), `openssh-server` initially absent — installed + enabled mid-Block A (`ssh.service` active running via socket-activation, `0.0.0.0:22 LISTEN`, UFW inactive). Bonus finds: RealSense apt repo (`librealsense.realsenseai.com/Debian/apt-repo`) already configured by the prof; `snapd` upgraded `2.74.1 → 2.75.2` during the apt-refresh cycle. Step 3 viability gate: NTP clock skew (Pi ~24h behind, RTC at epoch) fixed via `sudo timedatectl set-ntp true`; apt `Hit:2 http://packages.ros.org/ros2/ubuntu noble InRelease` proves ROS index egress on the IoT network (closes the 13/05 gap that had only tested `archive.ubuntu.com`); `apt-cache policy ros-jazzy-mavros` shows candidate `2.14.0-1noble.20260412.205154` from `packages.ros.org/ros2/ubuntu noble/main arm64`; `apt install --dry-run` resolves the dep chain cleanly (`libgeographiclib*` + `geographiclib-tools`, `libasio-dev`, `libboost*1.83*`, `ros-jazzy-{eigen-stl-containers, geographic-msgs, mavlink, libmavconn, mavros-msgs, mavros}`). Step 4 route decision: **Route 1 (apt `ros-jazzy-mavros`) GREEN** per §D.1 decision-tree branch 1. Block A → B gate: GO for install-only today (autopilot heartbeat verification on `/mavros/state` deferred until the boat is physically connected). Dialout add (`sudo usermod -aG dialout imt-aqua-drone`) queued as Block B prep, not blocking install.

## Block B — Install + configure (live, ≈ 60-90 min) OR Slab 3 / 4 paper (≈ 60-90 min)

Live branch — for Route 1 default (apt path):

- [x] Install packages: `sudo apt update && sudo apt install ros-jazzy-mavros ros-jazzy-mavros-extras ros-jazzy-mavros-msgs` (record exact versions captured by apt).
- [x] GeographicLib datasets (skip if not using altitude plugins; defaults installed via corrected ROS 2 ament executable path): `sudo /opt/ros/jazzy/lib/mavros/install_geographiclib_datasets.sh`.
- [ ] Configure FCU connection string (`serial:///dev/ttyACM0:115200` if USB-tethered autopilot per Step 2; `serial:///dev/serial0:115200` if GPIO UART; `udp://:14550@` if SITL) — deferred until autopilot hardware is connected.
- [ ] First launch attempt — capture stdout / stderr verbatim; flag missing deps or plugin-load errors — deferred until autopilot hardware is connected.
- [ ] Iterate on config until the bridge node starts cleanly (no immediate exits, no flood of plugin-load failures) — deferred until autopilot hardware is connected.

Paper branch (slab 3): `systemd` unit shape for the bridge — `[Unit]` deps (`network-online.target`, ROS daemon?), `[Service]` Restart policy (`Restart=on-failure`, `RestartSec=5s`?), ExecStart sourcing `/opt/ros/jazzy/setup.bash` then `ros2 launch ...`, log routing via journalctl, log rotation. Draft the unit file paper-side; no Pi-side install today.

Paper branch (slab 4): hardware-design layout sketch — regulated ≥5A 5V supply options (LM2596 buck vs dedicated 5V module), bulk capacitance near Pi power input (electrolytic + ceramic placement), thick-short GPIO leads vs proper USB-C input, powered USB hub between Pi and RealSense for current-spike decoupling (Anker / Sabrent options). Sketch only — no buy decisions.

**Outcome:** Install-only path executed cleanly. `sudo apt install ros-jazzy-mavros ros-jazzy-mavros-extras ros-jazzy-mavros-msgs` installed 21 new packages at exact versions matching the Block A Step 3 dry-run forecast: `ros-jazzy-mavros` `2.14.0-1noble.20260412.205154`, `ros-jazzy-mavros-extras` `2.14.0-1noble.20260412.212728`, `ros-jazzy-mavros-msgs` `2.14.0-1noble.20260412.083633`, plus 18 deps spanning `libboost*1.83*`, `libgeographiclib{26,-dev}`, `geographiclib-tools`, `libasio-dev`, and `ros-jazzy-{eigen-stl-containers,geographic-msgs,mavlink,libmavconn}`; apt reported `0 upgraded, 21 newly installed, 0 to remove`, 20.3 MB fetched, 273 MB installed. Post-install sanity green: `ros2 pkg list | grep mavros` returns `mavros`, `mavros_extras`, `mavros_msgs`; `ros2 pkg executables mavros | sort` returns `install_geographiclib_datasets.sh`, `mav`, `mavros_node`. GeographicLib default datasets installed via `/opt/ros/jazzy/lib/mavros/install_geographiclib_datasets.sh` — `egm96-5` geoid, `egm96` gravity, `emm2015` magnetic; defaults are small (~30 MB class), while the full optional geoid / gravity / magnetic catalogue would be much larger and is unnecessary today. Path correction captured: ROS 2 ament installs registered executables under `<prefix>/lib/<pkg>/`, not the ROS 1-style `<prefix>/share/<pkg>/` path; the old path returned `command not found`, and `find /opt/ros/jazzy -name install_geographiclib_datasets.sh` resolved the correct path. Access prep also passes: `imt-aqua-drone` added to `dialout`; after reboot, `groups | grep dialout` confirms membership persists. Block B → C gate: install side fully green; FCU config, first launch, and heartbeat verification on `/mavros/state` are deferred until the autopilot / boat is physically connected.

## Block C — Smoke-test (live, ≈ 30 min) OR Paper continuation (≈ 20-30 min)

Live branch:

- [ ] `ros2 topic list` — confirm `/mavros/*` topics appear (or `/mavros/state` at minimum if a sub-set is enabled by plugin config).
- [ ] `ros2 topic echo /mavros/state` — confirm heartbeat flows (`mavros_msgs/State`, `connected: true`).
- [ ] Capture one full sample message dump for at least one topic as evidence (paste into Block C Outcome).
- [ ] Optional second-pass: `/mavros/global_position/raw/fix` or `/mavros/imu/data` for telemetry path beyond heartbeat.

Paper branch: cross-reference slab 3 / 4 deliverable against the §D.2 topic-name scheme alignment from Thu 21/05 — does the autostart unit launch the bridge with the right `fcu_url` + launch-time remaps onto `/sensors/*`? Does the hardware layout decouple RealSense current spikes from Pi power as expected?

**Outcome:** N/A today — no autopilot connected to Pi 5, so `/mavros/*` topic surface and `/mavros/state` heartbeat smoke-test are deferred to autopilot / boat physical bring-up. Topic-name scheme alignment and Layer B bridge-node shape remain anchored to Thu 21/05 §D.2 as the validation baseline.

## Block D — Debrief + action-item extraction (≈ 20 min)

- [x] Capture lessons learned — route choice rationale, install gotchas, working config strings (live); or slab insights / open design questions (paper).
- [x] List follow-ups — missing hardware (USB hub, regulated supply, etc.), missing software (specific `mavros` plugins, dependencies), missing config (UART permissions, baud rates).
- [x] Doc-edit decision — by default DO NOT touch `Board.md` / `wiki/Roadmap.md` today; flag for a targeted edit only if a sharp directional outcome lands (live route confirmed end-to-end, or slab deliverable that updates Phase 5 planning state).

**Outcome:** Lessons learned: Route 1 (apt `ros-jazzy-mavros`) end-to-end install path validated on the prof's reflashed Ubuntu Desktop 24.04 Noble + `linux-raspi` 6.8.0-1056 + aarch64 baseline. Block A → B install chain is green from OS ID through dependency resolution through binary installation; 21 packages landed at the exact versions forecast by the Block A Step 3 dry-run. The Pi 5 reflash arrived with substantial prof-side preconfiguration: ROS 2 Jazzy base (`ros-jazzy-ros-base` 0.11.0), RealSense apt repo (`librealsense.realsenseai.com`), and UART enabled in `/boot/firmware/config.txt`, accelerating Phase 5 driver bring-up versus a clean-image start. NTP clock sync is the first post-reflash fix: the Pi was ~24h behind reality with RTC at epoch; `sudo timedatectl set-ntp true` fixed it, and future reflash recipes should do this early because severe clock skew can break TLS, apt release validation, and outbound HTTPS. Ubuntu Desktop 24.04 did not include `openssh-server` by default; symptom was workstation `Connection refused`, fixed by installing and enabling SSH. ROS 2 ament executable layout matters: registered executables land under `<prefix>/lib/<pkg>/`, not the ROS 1-style `<prefix>/share/<pkg>/`; specific case was `install_geographiclib_datasets.sh` at `/opt/ros/jazzy/lib/mavros/`. Supplementary group activation (`dialout`) needs a real sign-out/sign-in or reboot; reopening a terminal inside the same graphical session is not enough. `packages.ros.org` egress on `IoT IMT Nord Europe` is confirmed via apt `Hit:2`, closing the 13/05 partial-egress question that had only tested `archive.ubuntu.com`. New Pi identity is `imt-aqua-drone@imtaquadrone-desktop` at `10.120.2.162/23` on `wlan0` (old pre-reflash identity was `ghostzero@imtaqua-pi-01` at `10.120.2.50`), matching the IMT-Aquatic-drone / Herelink naming line.

Follow-ups: Autopilot physical connection remains the gating item: Block B FCU connection string selection (`serial:///dev/ttyACM*:115200`, `serial:///dev/serial0:115200`, or `udp://:14550@`) and Block C heartbeat smoke-test on `/mavros/state` both wait on hardware. Pi 5 hardware-design pass D2 from 20/05/2026 remains relevant: regulated ≥5A 5V supply, bulk caps, and powered USB hub for RealSense decoupling are more load-relevant under the full-DE image and should pre-empt the 13/05 brownout symptom under RealSense streaming load via GPIO power. Slab 3 paper deliverable (Pi-side `systemd` autostart strategy for the bridge) remains deferred and becomes production-deployment work after Block C completes. Workstation→Pi SSH public-key reinstallation is a convenience follow-up (`ssh-copy-id imt-aqua-drone@10.120.2.162`), not a blocker; first SSH after the reflash used password auth because the 11/05 key was wiped.

Doc-edit decision: defer. Today's outcome validates Route 1 install end-to-end on the reflashed image, but the meaningful Phase 5 milestone for `wiki/Roadmap.md` §3 is Block C heartbeat on a real autopilot. `Board.md` / roadmap edits should wait until that hardware smoke-test lands; no broader doc edits today.

## Block E — Day wrap (≈ 10 min)

- [x] Final checks: `git status`, `git diff --check`, and placeholder/conflict-marker scan over this diary.
- [x] Fill Block E Outcome BEFORE the wrap commit (19/05/2026 lesson learned: a placeholder slipped into `faa9ba1` and needed a follow-up `3cd8861` correction).
- [x] Run the standard pre-commit sweep before the wrap commit.
- [x] Set Sat 23/05 no-Pi-work note + Tue 26/05/2026 startup hint based on today's outcome.
- [ ] Commit + push (commit subject in the wrap; run from repo root after Block E Outcome is filled).

**Outcome:** Day closed live-branch — Pi 5 returned and reflashed with full-DE image; Route 1 (apt `ros-jazzy-mavros`) drove Block A → B install chain end-to-end on the new Ubuntu Desktop 24.04 Noble + `linux-raspi` + aarch64 baseline. Block A green across Steps 1-4; Block B install-only green (21 MAVROS packages + 3 default GeographicLib models, `dialout` activated, `openssh-server` installed and enabled mid-Block A); Block C N/A (no autopilot, heartbeat deferred to physical bring-up); Block D debrief captured lessons and autopilot-arrival follow-ups; doc edits deferred to Block C completion. Pre-wrap checks clean: `git diff --check` clean; focused placeholder / conflict-marker scan clean; focused §1.6 AI-tooling sweep clean on the modified diary. Proposed wrap commit subject: `docs(diary): wrap 22/05 MAVROS apt install + datasets on Pi 5`.

## Three Asks status carry-forward

- Phase A scope: cleared 20/05/2026 — not the internship's work.
- CA placement: Linux side confirmed 20/05/2026 (mild hedge).
- Validation methodology: pending external confirmation (teammate maintainer reply or 03/06/2026 meeting).

## Next steps (Active branch)

- Sat 23/05/2026: no Pi 5 work planned.
- Tue 26/05/2026 startup hint: Pi 5 has MAVROS installed and ready; Block C is a single-shot test when the autopilot / boat is physically connected to the Pi.
- If the autopilot / boat reaches Pi 5 by Tue: live Block C — `ros2 topic list` for `/mavros/*`, `ros2 topic echo /mavros/state` for `connected: true` heartbeat, against the correct FCU connection string (`serial:///dev/ttyACM0:115200` if USB-tethered, `serial:///dev/serial0:115200` if GPIO UART, `udp://:14550@` if SITL).
- If the autopilot is still unavailable Tue: paper continuation — slab 3 (Pi-side `systemd` autostart, deferred from Thu) or slab 4 (hardware-design pass layout sketch, deferred from 20/05 + Thu; more load-relevant under the full-DE image).
- Either path: Pi 5 install side is fully green and ready (`mavros` 2.14.0 + GeographicLib defaults + `dialout` active + `openssh-server` up); Block C is a single-shot test when conditions allow.
- D2 hardware-design pass revisit scheduled week's end — under full-DE image D2 is more load-relevant than under the prior headless-Server posture (RealSense + GUI + workstation viewers all share the Pi 5 power rail).
- VRX §8.2 weekly cadence next check **Tue 26/05/2026** (Monday intentionally skipped; no action Fri).

## Post-wrap addendum — GNOME Remote Desktop / RDP setup (after `534f9f4`)

After wrap commit `534f9f4 docs(diary): wrap 22/05 MAVROS apt install + datasets on Pi 5` landed, set up workstation → Pi 5 desktop remote-control to simplify future interaction with the full-DE Pi image. This was a live-branch convenience addendum, not part of the original scaffold.

### Path choice — GNOME Remote Desktop over RDP, not VNC

The first in-session idea was `wayvnc` on the Pi, but that depends on the Wayland compositor family. The Pi diagnostic returned:

```bash
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP $DESKTOP_SESSION"
# wayland ubuntu:GNOME ubuntu
```

That confirms Ubuntu Desktop 24.04 GNOME on Mutter, not a wlroots compositor. `wayvnc` is therefore the wrong default here: it fits wlroots compositors such as `sway`, `labwc`, `river`, `hyprland`, and `niri`, but not GNOME / Mutter. Path corrected to the Ubuntu-native GNOME Remote Desktop route over RDP, which is Wayland-native through PipeWire screen capture. RealVNC Server remains a fallback only if the Pi session is switched to "Ubuntu on Xorg"; RealVNC Linux service-mode capture is not the right fit for GNOME Wayland.

### Pi-side setup

Settings → System → Remote Desktop on the Pi:

- **Desktop Sharing:** ON — mirrors the existing logged-in Pi desktop session, matching the "see and control the same physical monitor / HUD" goal.
- **Remote Control:** ON — required for mouse / keyboard input; without it the session is view-only.
- **Remote Login:** OFF — this creates a separate GNOME session and would defeat the physical-monitor mirror goal.
- **Port:** 3389.
- **Hostname:** `imtaquadrone-desktop`.
- **Login details:** use the GNOME Remote Desktop credentials displayed in the Settings pane. Do not record the generated password in the repo; if exposed, rotate it from the Settings pane before relying on it long-term.

### Workstation-side setup and verification

```bash
sudo apt install remmina remmina-plugin-rdp
```

Both packages were already present at `1.4.35+dfsg-0ubuntu5.2` on the Ubuntu Noble workstation; no upgrade was needed. GTK warnings on Remmina launch (`gtk_menu_attach_to_widget` / `gtk_menu_detach`) were cosmetic Remmina + GTK noise, not functional failures.

Connection profile: Remmina → RDP → server `10.120.2.162:3389` → username as shown in the Pi GNOME Remote Desktop pane → GNOME-generated password from that pane → Save and Connect. First connection may show a self-signed TLS certificate prompt; accept / trust the fingerprint for this Pi.

Verification: Remmina connected from the workstation and showed the Pi 5 desktop mirroring the physical monitor; mouse / keyboard input forwarded correctly. Closing Remmina drops the remote view because the RDP client owns the TCP session; minimizing keeps it connected. The Pi-side desktop session persists either way, so disconnecting Remmina does not log out the Pi user or stop Pi-side processes.

### Lessons and follow-ups

- Compositor compatibility is load-bearing for desktop-access advice. Check `echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"` before recommending a VNC server on Wayland.
- GNOME Remote Desktop has two distinct modes: Desktop Sharing mirrors the current desktop session; Remote Login creates an independent session. They are not additive for the HUD mirror goal.
- Save a Remmina profile so future workstation → Pi sessions are one-click.
- Rotate the GNOME Remote Desktop generated password if it is ever exposed; document only that GNOME-generated credentials exist, not their literal value.
