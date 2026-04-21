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

**[To fill]** — final file list, commit SHA, any surprises during build.

## Block B — `launch/remap.launch.yaml` runnable

Follow the Deploy Workflow in `working_diary/2026-04-21_to_2026-04-22_remap_launch_draft.md`. All 7 steps are pre-specified there with exact commands and expected outputs.

**[To fill]** — verification checkboxes from the draft (8 items), commit SHA, any QoS / rate surprises.

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

**[To fill]** — measured rate, stdev, any drops, Board.md row updated.

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

**[To fill]** — three docstrings updated, commit SHA.

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

## Commits trail (fill as commits land)

```text
<SHA> fix: log bad JSON on subscribers and fix reverse-to-turn latch
<SHA> feat: add remap.launch.yaml for Phase 5 topic namespace translation
<SHA> docs: record perception publish-rate baseline for Phase 5 Pi-5 comparison
<SHA> docs: refresh node docstrings to match current pub/sub + state machine
<SHA> docs: fill 22/04 working diary with day's outcomes
```

Expected: 5 commits total. Each is independently revertable if post-commit review finds issues.

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

- [To fill]

## Next steps (for 23/04)

Fill at end of day based on what actually landed and what got deferred.

- [To fill]
