# 2026-04-22 — Remap layer, C1-C3 bug fixes, and docstring refresh

## Context

Scaffold written evening of 21/04 as tomorrow's work template — fill in each section as the day progresses.

Three threads planned, each independently commit-able and stoppable:

1. **C1-C3 bug fixes** — three real bugs confirmed by the 21/04 evening spot-read (two bare-except in perception/planner JSON callbacks + one `force_turn_after_reverse` latch fix in the controller). Clustered into one `_log_bad_json` pattern + one single-line state-machine fix. One commit cycle.
2. **Phase 5 remap layer** — translate the 21/04 paper draft (`working_diary/2026-04-21_to_2026-04-22_remap_launch_draft.md`) into a runnable `launch/remap.launch.yaml`. One commit.
3. **I6 docstring refresh** — three node module-level docstrings updated to match current pub/sub and state-machine surface. One commit.

Plus one short quant task: perception publish-rate baseline for Board.md. Plus the wrap-up diary fill-in at end of day.

Total: ~3 hours of focused work across morning and afternoon.

## Block A — C1-C3 bug fixes

Pull first (grabs tonight's commits):

```bash
cd ~/seal_ws/src/uvautoboat
git pull
```

### C1 + C2 — `_log_bad_json` pattern

Same treatment applied to the CLI's three callbacks on 21/04 (commit `9155cdf`). Pattern: add a module-level helper that logs the topic name + exception with a per-topic 5 s throttle, preserves the "keep previous value" fall-back, and prevents the `except Exception: pass` from silencing real bugs.

Target sites:

- `plan/plan/lidar_perception.py:267-279` — `target_callback`, silent fallback to previous `target_angle` / `front_half_width` on bad JSON.
- `plan/plan/waypoint_planner.py:537-553` — `obstacle_callback`, silent fallback on bad cluster data (consequential — stale clusters feed A*).

Pattern outline for each file:

```python
# Top of class
self._bad_json_log_times = {}  # topic → last-log-time, for 5s throttle

def _log_bad_json(self, topic: str, exc: Exception) -> None:
    """Throttled warn log for malformed JSON on a subscribed topic."""
    now = self.get_clock().now().nanoseconds / 1e9
    last = self._bad_json_log_times.get(topic, 0.0)
    if now - last > 5.0:
        self.get_logger().warn(
            f"Malformed JSON on {topic}: {type(exc).__name__}: {exc}"
        )
        self._bad_json_log_times[topic] = now

# In the callback:
def target_callback(self, msg):
    try:
        data = json.loads(msg.data)
        ...
    except Exception as e:
        self._log_bad_json('/planning/current_target', e)
```

### C3 — `force_turn_after_reverse` latch fix

Current bug: `heading_controller.py:793-797` unconditionally resets the flag to `False` in the fall-through after the critical block, so the flag never persists to the next control tick.

Fix sketch (single-point change around line 796):

```python
# BEFORE (lines 793-797)
# After reverse cap, fall through to avoidance turning
self.reverse_start_time = None
self.reverse_start_pos = None
self.force_turn_after_reverse = False   # ← this line breaks the latch
self.avoidance_mode = True

# AFTER — remove the unconditional reset; rely on the `else` branch
# at line 798-801 (entered when is_critical becomes False) to clear it.
self.reverse_start_time = None
self.reverse_start_pos = None
self.avoidance_mode = True
```

The `else` branch at line 798-801 (entered when `is_critical == False`) already resets `force_turn_after_reverse = False`, so removing the line in the fall-through is sufficient. Verify the `else` path still fires in the `is_critical → not is_critical` transition.

### Auto-iterate verification

```bash
# Per-edit syntax check
python3 -m py_compile plan/plan/lidar_perception.py
python3 -m py_compile plan/plan/waypoint_planner.py
python3 -m py_compile control/control/heading_controller.py

# Full build before commit
cd ~/seal_ws
colcon build --packages-select plan control
```

Expected: all three `py_compile` clean, colcon build 2/2 packages 0 errors.

### Commit

```bash
cd ~/seal_ws/src/uvautoboat
git add plan/plan/lidar_perception.py plan/plan/waypoint_planner.py control/control/heading_controller.py
git commit -m "fix: log bad JSON on subscribers and fix reverse-to-turn latch"
git push
```

**Outcome.** Files modified: `plan/plan/lidar_perception.py`, `plan/plan/waypoint_planner.py`, `control/control/heading_controller.py`. Commit `3389554`. No surprises during build — `py_compile` clean per-file, `colcon build --packages-select plan control --merge-install` finished 2/2 in 1.39 s.

Implementation matched the existing CLI helper from `9155cdf` exactly (attribute name `_bad_json_last_warn`, signature `_log_bad_json(self, topic, exc, throttle_sec=5.0)`, `time.monotonic()` timing, message format `"Failed to parse {topic}: {exc}"`). `lidar_perception.py` needed `import time` added; `waypoint_planner.py` already had it.

**Live verification** (with full stack running):

- **C1** — injected garbage via `ros2 topic pub --once /planning/current_target std_msgs/msg/String "data: 'not json'"` × 5 in rapid succession; saw exactly **one** `[WARN] Failed to parse /planning/current_target: …` per 5 s window in the LiDAR Perception terminal — throttle working. Previously silent.
- **C2** — same injection pattern on `/perception/obstacle_info`; one WARN at the planner, valid obstacle traffic continued at ~5 Hz alongside.
- **C3** — scenario genuinely unreachable in VRX under `sydney_regatta_DEFAULT`. The planner's opportunistic **8 m side-detour** (L23 `📍 Side detour 1/3 (RIGHT)` log) plus the controller's aggressive avoidance turn (`diff_bias` up to 18 at urgency > 40%) resolve head-on buoy/pier encounters before `front_distance` drops below the 6 m critical threshold. Joystick attempts to force head-on approach to a pier got side-turned by avoidance the moment control was released. Shipped on no-regression grounds — fix is 3 lines in a state machine, `py_compile` + build clean, normal mission avoidance healthy. If regressing, symptom is unmistakable (double-reverse cycle, ~8 s where ~4 s is expected).

## Block B — `launch/remap.launch.yaml` runnable

Follow the Deploy Workflow in `working_diary/2026-04-21_to_2026-04-22_remap_launch_draft.md`. All 7 steps are pre-specified there with exact commands and expected outputs.

**Outcome.** File created at `launch/remap.launch.yaml` (140 lines, 9 launch items). Commit `816be9d` — bundled with the Board.md RTF caveat on the perception-rate row to collapse what would otherwise have been a separate docs commit (day's total landed as 4 commits instead of 5 planned).

**Draft bug surfaced.** Jazzy's YAML launch frontend rejects the nested `condition: "..."` key inside `node:` with `ValueError: Unexpected key(s) found in 'node': {'condition'}`. Correct syntax is `if:` / `unless:` as direct siblings of `pkg` / `exec`. Fixed 6× `condition: "unless $(var use_real_hardware)"` → `unless: $(var use_real_hardware)` and 1× `condition: "if $(var use_real_hardware)"` → `if: $(var use_real_hardware)`. Draft markdown untouched (diary history, not tracked as authoritative).

**Verification checkboxes** (from the draft's step-7 block):

- ✅ File created at `launch/remap.launch.yaml` with relay layer A + bridge stub B
- ✅ `topic_tools` package confirmed installed (`/opt/ros/jazzy`)
- ✅ YAML parses via `python3 -c "import yaml; yaml.safe_load(...)"` — 9 items
- ✅ `ros2 launch remap.launch.yaml` starts 6 relay nodes in <3 s (bridge stanza correctly skipped)
- 🟡 `ros2 topic list | grep /sensors/` shows **4** neutral topics, not 6. The 2 actuator relays (`/actuators/thrusters/*/cmd`) are lazy — `topic_tools/relay` auto-detects type from input publisher, and nothing publishes on `/actuators/*` yet (that's Phase 5.2 work). Expected and correct.
- ✅ `/sensors/gps/fix` rate matches source: ~8.7 Hz on both `/wamv/…/gps/fix` and `/sensors/gps/fix` — relay is healthy for GPS.
- 🟡 `/sensors/lidar/points` rate comparison **deferred**. `ros2 topic hz` default QoS (reliable) can't match the best-effort LiDAR publisher, so the probe returns misleading ~3 Hz on both sides. Jazzy's `ros2 topic hz` has no `--qos-*` flag (only `ros2 topic echo` does). Confirmed relay publishes by `ros2 topic echo --qos-reliability best_effort --once /sensors/lidar/points` returning a message.
- 🟡 Full VRX mission no-regression **deferred to Phase 5.1 bench hardware**. Laptop Gazebo RTF drops to 30-40% once VRX + nav stack + 6 relays + probes all compete for CPU, so can't hold 1.0 RTF long enough to establish a clean no-regression baseline. The relay is structurally correct and operationally flowing messages; functional verification under load needs a real-time-capable host.
- ✅ Commit + push landed as `816be9d`.

## Block C — Perception publish-rate profiling

Launch full stack:

```bash
# Use the one-click launcher for consistency
cd ~/seal_ws/src/uvautoboat/one_click_launch_all
bash launch_autoboat_complete.sh sydney_regatta_DEFAULT
# Wait for readiness polls to complete (~20-40 s)
```

Apply Buoy Field preset from the dashboard (port 8002), generate waypoints, start mission.

In an idle terminal:

```bash
source ~/seal_ws/install/setup.bash
ros2 topic hz /perception/obstacle_info
# Let it run for 2 minutes, note:
# - average rate
# - min / max interval
# - any dropped windows
# Ctrl+C to stop; scroll back and copy the summary lines.
```

Record in Board.md Prep Tasks table, row 165 (`Profile /perception/obstacle_info Hz in VRX; document baseline`):

- Flip `⬜` → `✅`
- Append measured value to the cell, e.g. `✅ — 9.8 Hz mean, 0.2 Hz stdev, 2025-04-22 Linux workstation`

Commit:

```bash
git add Board.md
git commit -m "docs: record perception publish-rate baseline for Phase 5 Pi-5 comparison"
git push
```

**Outcome.** `ros2 topic hz /perception/obstacle_info` for 120 s under Buoy Field mission:

- Mean: **20.000 Hz** (2353 samples)
- Min interval: 0.010 s (100 Hz instantaneous — single outlier, likely DDS reconnect)
- Max interval: 0.091 s (11 Hz instantaneous — worst dropout)
- Std dev: **0.00400 s** (~4 ms jitter on 50 ms period — negligible)
- Zero sustained dropouts, no bimodal distribution

Measurement taken in a fresh-session window before RTF degradation. Later in the day, after launching the relay layer + running multiple probes, Gazebo RTF dropped to 30-40% on this host — perception rate tracks RTF proportionally (saw 0.6-0.7 Hz under that load). That behaviour is expected and means the 20 Hz number is the Gazebo-sim-time rate, not a steady-state wall-clock guarantee on this laptop.

Board.md row 165 flipped ⬜ → ✅ in commit `65709a0`; RTF caveat appended in follow-up commit `816be9d` so a reader doesn't misinterpret the number as hardware-independent. Pi 5 on-water is the real Phase 5 baseline to compare against.

## Block D — I6 docstring refresh

Update three module-level docstrings (the `"""..."""` block near the top of each file, not function-level):

### `plan/plan/lidar_perception.py`

Add to Subscribes list:

- `/planning/set_config` (std_msgs/String) — runtime config updates
- `/control/heading_error` (std_msgs/Float64) — body-frame angle error for target-aware VFH

Add to Publishes list:

- `/perception/param_ranges` (std_msgs/String) — JSON param validation ranges for dashboard sync

### `control/control/heading_controller.py`

Add to Subscribes list:

- `/planning/mission_status` (std_msgs/String) — for E-Stop / state-aware control gating

Add to Publishes list:

- `/control/heading_error` (std_msgs/Float64) — body-frame angle error for perception VFH

### `plan/plan/waypoint_planner.py`

Current state-machine docstring (typically mid-file): `INIT → WAITING_CONFIRM → READY → DRIVING → FINISHED`.

Expand to the full set the planner actually emits (confirmed via 21/04 spot-read):

`INIT → WAITING_CONFIRM → READY → DRIVING → FINISHED` plus side-states `PAUSED` (via stop/resume), `JOYSTICK` (manual override), `EMERGENCY_STOP` (latched Bool).

### Commit

Pure docstring change, no runtime behaviour:

```bash
git add plan/plan/lidar_perception.py control/control/heading_controller.py plan/plan/waypoint_planner.py
git commit -m "docs: refresh node docstrings to match current pub/sub + state machine"
git push
```

**Outcome.** Three module-level docstrings refreshed per the 21/04 draft. Commit `cd009c0`.

- `plan/plan/lidar_perception.py` — added `/planning/set_config` + `/control/heading_error` subs, added `/perception/param_ranges` pub, replaced stale "Velocity estimation (moving obstacle tracking)" line with "VFH polar histogram with target-aware gap selection (uses /control/heading_error)".
- `control/control/heading_controller.py` — added `/planning/mission_status` / `/planning/set_config` / `/planning/emergency_stop` subs, added `/control/heading_error` + `/control/param_ranges` pubs, added an inline **Control constants** subsection listing 6 module-scope values (MAX_THRUST, SAFE_THRUST, TURN_POWER_LIMIT, REVERSE_BURST_THRUST, ESCAPE_TURN_POWER, INTEGRAL_LIMIT), rewrote the "turn left until clear" anti-stuck line to "turn toward the clearer side", expanded the Kalman line to mention feed-forward application.
- `plan/plan/waypoint_planner.py` — state machine expanded 5→8 states (happy path + PAUSED / JOYSTICK / EMERGENCY_STOP), Features expanded 4→6 items (multi-level obstacle handling with thresholds + Runtime A* + Hybrid Mode toggle), added 5 new subs (`/perception/obstacle_info`, `/planning/mission_command`, `/planning/set_config`, `/planning/emergency_stop`, `/control/replan_request`), 2 new pubs (`/planning/config`, `/planning/param_ranges`), and a Services section for the two `std_srvs/Trigger` services.

Block D landed on the same 3 files as Block A. Used `git add -p` hunk-split to separate the runtime hunks (init dict, helper method, except-block replacement, latch fix) under the `fix:` commit from the top-docstring hunks under the `docs:` commit. Split verified via `git diff --cached` / `git diff` between commits.

## Block E — Wrap + diary fill-in

1. `git log --oneline -5` — sanity check the day's commits landed cleanly.
2. Pre-commit scan one more time — run the standing repo-wide sweep (the pattern is codified in the local editor-settings hook; expected output: zero matches over active source + doc files).

3. Fill the `[To fill]` placeholders throughout this file with concrete outcomes.
4. Add 22/04 milestone row at the bottom of Board.md's Timeline table.
5. Update the external `Research_intern_IMT_NE/working_diary/Week7_20_04-24_04.md` Wednesday block (scaffold already written) — replace `[Block 结束后填写]` placeholders with real results.
6. Commit the diary / Board updates:

   ```bash
   git add working_diary/2026-04-22_remap_bug_fixes_and_docstring_refresh.md Board.md
   git commit -m "docs: fill 22/04 working diary with day's outcomes"
   git push
   ```

## Post-Block-E — afternoon hardening pass

After the Block-E wrap-up (`114759f` — diary fill + Board timeline row + wiki sync) the day continued with a UX + doc-polish sprint driven by live-testing of the morning's deliverables. Five additional commits landed.

### `2d34847` — IDLE → UNKNOWN sentinel + camera-topic URL pattern guard

Two thematically distinct items bundled because they touched the same two files (`autoboat_cli.py` + `app.js`). Resolves the "Residual IDLE alignment" item carried from 21/04's diary — that item is now closed.

**IDLE rename** (13 mission-state sites renamed across dashboard + CLI; 5 escape-direction sites deliberately preserved). The pre-data mission-state sentinel was `IDLE`, but the planner never emits that state — it emits the 8-state set (`INIT` / `WAITING_CONFIRM` / `READY` / `DRIVING` / `PAUSED` / `JOYSTICK` / `EMERGENCY_STOP` / `FINISHED`). Renamed to `UNKNOWN` so the "no data yet" sentinel is semantically distinct from the planner's `INIT` ("planner up, mission not configured"). Escape-direction `IDLE` ("not escaping") kept as-is — natural value in that enum, not a pre-data sentinel.

**Camera-topic URL pattern guard** (`app.js`): the camera panel's topic input previously passed any string verbatim into a `web_video_server` URL. Added a regex guard (`/^\/[a-zA-Z0-9_/]+$/`) that rejects URL-special chars (`?`, `#`, `&`, spaces, etc.) with a clear error message. Security impact near-zero (web_video_server just returns junk for non-image topics) but protects against user typos and clipboard-paste accidents.

### `6f9f5ac` — camera Refresh hardening

Live stress-testing of the camera panel after `2d34847` surfaced three coordinated issues:

1. **Validation error flashed then disappeared.** MJPEG fires a `load` event on every frame, and the existing load handler unconditionally reset status to "Streaming | Flux en cours", overwriting the user-input validation error within ~30 ms.
2. **Rapid Refresh clicks** triggered an upstream bug in `web_video_server` — the server CPU-pegs near 100 %, port 8080 accepts TCP but returns zero HTTP bytes. Full tab-close + hard-refresh does NOT recover the stuck state; process restart required.
3. **Blank field stayed blank after Refresh** used the default fallback — UX gap, user couldn't tell what topic was actually streaming.

All three mitigated in one `fix:` commit: **2 s Refresh debounce** (initially tried 1 s, bumped after a second stress test triggered the server deadlock even at 1 s rate); **explicit stream tear-down** (`removeAttribute('src')` + 200 ms gap before new URL, so the browser issues a clean TCP close before the next reconnect); **sticky validation-error flag** via `dataset.userError` that the load handler checks before overwriting; **auto-populate the input field** when fallback kicks in.

### `9a66b97` + `bd4e6e3` — `wiki/Common_Issues.md` sweep

Documenting the `web_video_server` deadlock pattern (`9a66b97`) prompted a broader read of `Common_Issues.md`. Audit found 10 Critical + 4 Important + 2 Cosmetic staleness issues — mostly accumulated drift from the 16/04 rename wave + 21/04 hazard-zone removal + "TF tree is not used" decision that was never propagated to the troubleshooting doc.

Representative criticals: `ros2 node list | grep autoboat` pointing at a node name that doesn't exist (grep should hit `heading_controller|lidar_perception|waypoint_planner`); advice to set `stuck_timeout` to 5.0 s "to increase" when default is 12.0 s (wrong direction); `min_range` default claimed as 5.0 m when actual is 2.2; `min_height: -20.0 / max_height: 15.0` recommended when actual YAML is `-1.2 / 1.5` (far-wider range makes detections *worse* by picking up sky/water reflections); Gazebo Classic `source /usr/share/gazebo/setup.sh` (project uses Harmonic via `ros_gz`); `world:=sydney_regatta` (should be `sydney_regatta_DEFAULT`); `ros2 run plan autoboat --ros-args …` (no such executable); a full `view_frames` section despite TF not being used anywhere.

All 16 items fixed in `bd4e6e3` — single-file change, +48 / -42.

### `c92c80d` — Apply/Preset debounce grey-out + bottom E-Stop shortcut

Three dashboard-UX items in one `feat:` commit:

- **Apply/Preset 1 s debounce.** The tuning-panel buttons (4 Apply + 4 Preset) had no debounce. Spam-clicking Apply Config fired N full `/planning/set_config` broadcasts; rapid preset thrashing churned params through N passes. Added two independent 1-second timers (one for Apply group, one for Preset group) so the natural "click Preset → click Apply" flow still works within 1 s, but same-group spam is dropped with a log warning. Separate mechanism from the existing 800 ms `debounceCommand` that covers mission-control buttons.
- **Group grey-out via `.cooldown` CSS class.** During the 1 s window, all 4 buttons in the active group fade (opacity 0.4, `pointer-events: none`). Mirrors the camera Refresh button's visual-feedback pattern so the user can *see* the debounce firing. Uses a separate class (not the `disabled` attribute) so the existing "disabled until first ROS sync" external logic isn't clobbered by the timeout-based re-enable.
- **Floating bottom-right `🚨 E-STOP` shortcut.** Mirrors the existing header badge. Fixed-position FAB, z-index 1000 (below onboarding's 9998). Same scroll-to-and-flash behaviour — takes the user to the real `btn-emergency-stop` and flashes it for 1.2 s, **does not fire** E-Stop directly (safer than a second direct-fire button). Both header and footer badges pulse (`latched` class) while the real E-Stop latch is active. Pattern extracted into a shared handler so future shortcut sites (e.g., a keyboard binding) register with one-liner.

Also in the same commit: reworded the `btn-emergency-stop` click-handler comment to explain that the `confirm()` inside `emergencyStop()` is intentional, not a contradiction of the "no debounce — safety critical" statement. GUI E-Stop has no physical mushroom-head barrier against accidental clicks, so the `confirm()` dialog is the software equivalent.

## Commits landed

```text
3389554 fix: log bad JSON on subscribers and fix reverse-to-turn latch
cd009c0 docs: refresh node docstrings to match current pub/sub + state machine
65709a0 docs: record perception publish-rate baseline for Phase 5 Pi-5 comparison
816be9d feat: add remap.launch.yaml and qualify perception-Hz baseline with RTF note
114759f docs: 22/04 wrap — fill diary + sync Board + wiki
2d34847 refactor: IDLE→UNKNOWN mission-state sentinel + camera-topic URL pattern guard
6f9f5ac fix(dashboard): harden camera refresh — debounce, stream tear-down, sticky validation error, blank-field autofill
9a66b97 docs: Common_Issues — document web_video_server deadlock + prevention
bd4e6e3 docs: Common_Issues — correct stale defaults, node names, Gazebo env, TF refs
c92c80d feat(dashboard): Apply/Preset debounce grey-out + bottom E-Stop shortcut
```

10 commits landed (vs 5 originally scaffolded). The extra five are the afternoon hardening pass — none of them would have been forced by the morning plan, but each one was surfaced by testing the morning's work under real sim load. The biggest single diff was `bd4e6e3` (48+/42- on `Common_Issues.md`) which was pure doc; the longest-value change was `6f9f5ac` (camera Refresh UX, catches a real upstream deadlock). This diary-append commit (the one carrying this text) will make it 11.

## Rollover checkpoints

Natural stopping points if time runs short:

| After | State | Rollover cost |
|:------|:------|:--------------|
| Block A | 3 bugs fixed, no other work | 23/04 starts on Block B (remap) |
| Block B | remap runnable, missions unchanged | 23/04 on Block C (perf profile) |
| Block C | perf baseline recorded | 23/04 on Block D (docstrings) |
| Block D | docstrings refreshed | 23/04 on Block E (diary fill) |
| Block E | diary complete | Week fully closed for 22/04 |

## Known unknowns surfaced during the day

Use this section to capture anything surprising during the day — file state drift, QoS effects, unexpected behaviour. Each entry: file:line or command + observation + fix or follow-up.

- **Draft YAML launch-condition syntax bug.** `working_diary/2026-04-21_to_2026-04-22_remap_launch_draft.md` used `condition: "unless $(var …)"` nested inside `node:`; Jazzy rejects with `ValueError: Unexpected key(s) found in 'node': {'condition'}`. Correct syntax is `if:` / `unless:` as siblings of `pkg` / `exec`. Fixed in the landed `launch/remap.launch.yaml`; draft left untouched (it's working-diary history, not an authoritative reference). Follow-up: any future YAML launch drafts should be syntax-checked against Jazzy's parser (`python3 -c "import yaml; yaml.safe_load(...)"` catches indentation but not schema-level rejections — the real check is `ros2 launch <file>` or reading the current `launch.yaml` frontend schema).
- **Laptop RTF ceiling.** This workstation can't hold Gazebo RTF 1.0 once VRX + 3 nav nodes + 6 relay nodes + 2-3 ROS 2 probing tools are all live. Drops to 30-40%. Affects any no-regression test requiring steady-state wall-clock rate comparison. Phase 5.1 will target Pi 5 on-water; the no-regression test for `remap.launch.yaml` migrates there.
- **`ros2 topic hz` has no QoS flags in Jazzy.** `ros2 topic echo` accepts `--qos-reliability`, `--qos-durability`, etc.; `ros2 topic hz` does not. Best-effort topics (VRX sensor data) can't be rate-probed directly — either echo with matching QoS and count, or measure a downstream consumer (we used `/perception/obstacle_info` as a proxy for LiDAR rate).
- **C3 unreachable in VRX.** Planner-side 8 m opportunistic side-detour + controller's aggressive avoidance turn resolve head-on encounters before the `is_critical` guard (`front_distance < 6 m`) fires. The latch-persistence fix matters in a narrow edge case the wider system mostly prevents from occurring. Shipped as a 3-line no-regression fix; verify on Pi 5 bench if any real-hardware run ever does catch a double-reverse symptom.
- **Bundle vs split decision for commit `816be9d`.** Planned as `feat:` alone; bundled with Board.md RTF caveat because the caveat arose from the same sim observation that also deferred the no-regression test. Clear enough authorship link for a reader reviewing history; avoids two near-empty commits.
- **`web_video_server` deadlocks under connection churn.** Rapid client reconnect cycles — triggered initially by undebounced dashboard Refresh clicks — lock the server into a CPU-pegged state where port 8080 accepts TCP but returns zero HTTP bytes. Full tab-close + hard-refresh does NOT recover; process restart required. Documented in `wiki/Common_Issues.md` with diagnose + recovery steps. Dashboard-side prevention: 2 s debounce + explicit tear-down.
- **GUI E-Stop `confirm()` contradicts the "safety-critical, no debounce" comment.** `app.js:btn-emergency-stop` click handler had a comment asserting no artificial delay, but `emergencyStop()` opens a `confirm()` prompt first. Not a bug — the prompt is the software equivalent of a physical mushroom-head barrier against accidental clicks (GUI has no physical prominence, `confirm()` supplies it). Reworded the comment to make the intent explicit. Phase 5.1 field deployment should revisit: on real water with a time-critical obstacle, the confirm click could cost a second.
- **Dashboard button debounce was already partial.** `debounceCommand()` (800 ms) existed and wrapped all mission-control buttons; missed it in an initial audit because it's a shared-timer function not a per-button `disabled` toggle. Tuning-panel buttons (Apply / Preset) had no protection; `c92c80d` adds that. Two distinct debounce mechanisms now coexist — `debounceCommand` 800 ms for mission-control + `debounceApply` / `debouncePreset` 1000 ms + visual `.cooldown` grey-out for tuning. Plus per-button `disabled + setTimeout` on the camera Refresh. Three patterns; worth knowing before adding a fourth.

## Next steps (for 23/04)

Carrying from 21/04 (unchanged):

1. **Supervisor conversation** — confirm water quality parameter set for Phase A (pH / turbidity / DO / temperature / conductivity — which subset?); confirm CCU low-level architecture for Phase 5 (separate controller board, or direct Pi GPIO?). Single-conversation blockers on otherwise-scoped work.
2. **Phase A implementation** — mock `water_quality` sensor node publishing synthetic readings tied to GPS position at 1 Hz. Blocked on 1.
3. **Pier / bank stuck behaviour** — open navigation issue from 20/04 pressure test. Parallel-able with research-extensions track.

*(Item 4 from the morning draft — "Residual IDLE alignment" — closed by `2d34847` this afternoon.)*

New from 22/04:

4. **Real no-regression test for `launch/remap.launch.yaml`** — needs a host that can hold Gazebo RTF 1.0 under load. Migrates to Phase 5.1 bench hardware (Pi 5) or a spare workstation.
5. **`ros2 topic hz` best-effort alternative** — investigate `ros2 topic bw` / Python rate probe / `ros2 bag record` + post-processing for best-effort rate measurement. Minor unless we keep hitting sensor-rate probing needs.
6. **C3 bench verification** — if Phase 5.1 testing ever produces a double-reverse symptom, the latch fix needs scenario-specific verification. Otherwise the no-regression + build + normal-avoidance-healthy evidence is sufficient.
7. **E-Stop `confirm()` revisit for field deployment.** Keep as-is for sim (accidental-click guard pays off during dev); revisit when moving to real boat on real water. Options if the confirm click becomes a liability: press-and-hold pattern (keeps single-gesture UX, still protects against phantom clicks) or a guarded latch-style trigger.
8. **Shared debounce-pattern consolidation** (low priority). The codebase now has three distinct debounce mechanisms (`debounceCommand` 800 ms, `debounceApply` / `debouncePreset` 1000 ms + `.cooldown` class, and the per-button `disabled + setTimeout` on camera Refresh). Worth a small refactor to unify on one helper the next time anyone touches the dashboard JS.
