# Simple Anti-Stuck System (SASS)

Recovery system that frees the boat when it becomes trapped or immobilized by obstacles, currents, or navigation errors.

> 💡 **Related pages:**
>
> - For **term definitions** (Kalman filter, differential thrust, etc.), see **[Glossary](Glossary)**.
> - For **why these parameter values** (12 s timeout, 1 m threshold) were chosen, see **[Design_Rationale](Design_Rationale#timing-thresholds)**.

---

## Design Evolution

The anti-stuck recovery has evolved through several iterations:

| Version | Behaviour | Status |
|:--------|:----------|:-------|
| Legacy SASS v2.x (see `legacy/fixed_variants/heading_controller_fixed.py`) | Multi-phase escape: PROBE → REVERSE → TURN → FORWARD, with Kalman-filtered drift compensation during each phase | Moved to `legacy/` |
| Current "Simple Anti-Stuck" | **Turn toward the clearer side** (Left or Right based on `left_clear` vs `right_clear` sector distances) until front is clear; request waypoint skip after 3 consecutive failures | **Active in production** |

**Why the simplification?** The multi-phase v2 logic had several subtle failure modes: phase transitions could get stuck, the "PROBE" phase often wasted time, and tuning the per-phase parameters was fragile. The current single-phase design is both easier to reason about and more reliable — it just picks whichever side has more room and keeps turning until the path opens up, with a skip-waypoint fallback if the boat is genuinely stuck.

> **Note on wording:** older code comments and some log messages still say "turn left until clear" — this was the original behaviour before the direction-selection fix. The actual current behaviour is "turn toward the clearer side", based on sector clearance comparison in `execute_smart_escape()`.

---

## Overview

The **Simple Anti-Stuck System (SASS)** is a straightforward recovery mechanism implemented in the Heading Controller. When the boat detects it's stuck (minimal movement despite thrust), SASS executes a simple escape: **turn toward whichever side (left or right) has more clearance** until the front is clear, then resume navigation.

---

## Key Features

| Feature | Description |
|:--------|:------------|
| **Simple Escape** | Turn toward the clearer side (left or right) until `front_clear > min_safe_distance` |
| **Stuck Detection** | Monitors position movement over configurable timeout |
| **Skip During Avoidance** | Won't trigger stuck detection while actively avoiding obstacles |
| **Kalman Drift Compensation** | Estimates current/wind with uncertainty |
| **Mission-Aware** | Automatically resets when mission stops |

---

## When SASS Activates

SASS triggers when the boat is **stuck**:

| Condition | Value |
|:----------|:------|
| **Time without progress** | > 12.0 seconds (default `stuck_timeout`) |
| **Movement threshold** | < 1.0 meters (default `stuck_threshold`) |
| **Not during avoidance** | Only triggers when path should be clear |

**Example Log:**

```text
🚨 BLOQUÉ! | STUCK! - No progress for 12.5s
```

---

## Escape Strategy

SASS uses a simple, reliable approach — **turn toward the clearer side until the front is clear**:

```text
1. Stuck Detection:
   - Track boat position every second
   - If movement < stuck_threshold (1.0m) for stuck_timeout (12s)
   - AND path is clear (not during obstacle avoidance)
   - Trigger escape mode

2. Simple Escape:
   - Compare left_clear vs right_clear sector distances
   - Apply differential thrust biased toward whichever side has more room
   - Check front_clear distance every iteration
   - Exit when front_clear > min_safe_distance

3. Resume Navigation:
   - Reset PID integral error
   - Clear stuck state
   - Continue to current waypoint
```

---

## Kalman Filter Drift Compensation

SASS uses a **2D Kalman filter** to estimate environmental drift (currents, wind):

### State Estimation

```python
x = [drift_x, drift_y]    # State estimate (m/s)
P = uncertainty           # Covariance matrix (confidence)
Q = 0.01                  # Process noise (drift changes slowly)
R = 0.5                   # Measurement noise (GPS/IMU error)
```

### Update Cycle

1. **Predict**: Uncertainty grows (`P = P + Q`)
2. **Measure**: Compare expected vs actual movement
3. **Update**: Correct estimate with measurement
   - `K = P / (P + R)` (Kalman gain)
   - `x = x + K(z - x)` (new estimate)
   - `P = (1 - K) * P` (reduced uncertainty)

### Dashboard Display

**Uncertainty Colors:**

- 🟢 **< 0.05** — High confidence
- 🟡 **0.05 - 0.15** — Moderate confidence
- 🔴 **> 0.15** — Low confidence (more measurements needed)

**Example:**

```text
Drift Estimate: vx=0.12 m/s, vy=-0.05 m/s
Uncertainty: 0.03 (🟢 confident)
```

---

## Interaction with Waypoint Skip

When SASS alone cannot free the boat, the waypoint skip strategy takes over:

| Situation | Action |
|:----------|:-------|
| Stuck detected | SASS: turn toward clearer side until clear |
| Still blocked after 45s | The Planner skips to next waypoint |
| Go Home mode blocked 15s | The Planner inserts detour waypoint |

---

## Configuration Parameters

### In `autoboat.launch.yaml` (Controller node)

| Parameter | Default | Description |
|:----------|:--------|:------------|
| `stuck_timeout` | 12.0 | Seconds without progress to trigger SASS |
| `stuck_threshold` | 1.0 | Minimum movement (meters) to not be stuck |
| `drift_compensation_gain` | 0.3 | Kalman drift correction strength |
| `kalman_process_noise` | 0.01 | Drift estimation process noise |
| `kalman_measurement_noise` | 0.5 | Drift estimation measurement noise |

### Runtime Tuning (via CLI)

```bash
# Example: Increase stuck detection sensitivity
ros2 param set /heading_controller stuck_timeout 2.0
ros2 param set /heading_controller stuck_threshold 0.3
```

---

## SASS vs Waypoint Skip

Two complementary strategies for handling blocked waypoints:

| Strategy | Trigger | Action |
|:---------|:--------|:-------|
| **SASS** | Boat physically stuck (no movement) | Turn toward clearer side until clear |
| **Waypoint Skip** | Obstacle blocking for 45s | Skip to next waypoint |

**Typical Flow:**

1. Boat approaches waypoint
2. Obstacle detected → slow down and navigate around
3. If stuck → SASS activates (single-phase: rotate toward clearer side)
4. If still can't reach after 45s → Skip waypoint
5. Continue to next waypoint

---

## Real-World Example

**Scenario**: Boat gets wedged between two buoys

```text
T=0s:    Boat stuck between buoys
         LEFT: 2.1m | RIGHT: 5.8m | FRONT: 1.4m
         movement over last 12s: 0.4m (< 1.0m threshold)
         → SASS activates, escape_mode = True

T=0-Xs:  Single-phase rotation
         right_clear > left_clear → bias differential thrust to the RIGHT
         (boat rotates toward the clearer side)
         front_clear still below min_safe_distance → keep rotating

T=Xs:    front_clear > min_safe_distance
         → escape_mode = False, PID integral reset
         → Resume normal navigation toward current waypoint
```

If the boat fails to clear after repeated attempts (`consecutive_stuck_count`
increases), the waypoint skip strategy kicks in — see next section.

---

## Monitoring SASS

### Dashboard Panel

The dashboard's **Anti-Stuck Status** panel shows the fields published on
`/control/anti_stuck_status`:

- **Escape mode** (boolean — is SASS currently active?)
- **Front clearance** (metres — front sector distance from LiDAR Perception)
- **Consecutive attempts** (how many times SASS has fired without resolving)
- **Drift vector** (estimated currents/wind in m/s, from the 2D Kalman filter)
- **Drift uncertainty** (colour-coded confidence in the drift estimate)

### Terminal Output

Typical log sequence when SASS triggers and resolves:

```text
🚨 STUCK! Simple escape (Attempt 1)
(front: 1.4m L: 2.1m R: 5.8m)
...
✅ Path clear - escape complete
```

### ROS 2 Topic

```bash
ros2 topic echo /control/anti_stuck_status
```

**JSON Format:**

```json
{
  "is_stuck": true,
  "escape_mode": true,
  "escape_direction": "RIGHT",
  "consecutive_attempts": 1,
  "front_clear": 1.4,
  "drift_vector": [0.12, -0.05],
  "drift_uncertainty": [0.03, 0.04],
  "drift_kalman_gain": [0.12, 0.10]
}
```

`escape_direction` is `"LEFT"`, `"RIGHT"`, or `"IDLE"` — tracks which side the controller is currently turning toward during an active escape, based on the live comparison of `left_clear` and `right_clear`. `"IDLE"` when not escaping.

---

## Troubleshooting

### SASS Activates Too Often

**Cause**: Stuck detection too sensitive

**Solution**: Increase timeout or threshold

```bash
ros2 param set /heading_controller stuck_timeout 5.0
ros2 param set /heading_controller stuck_threshold 1.0
```

### SASS Doesn't Escape

**Cause**: Both sector clearances are tight and the boat can't find a clear direction

**Solution**:

- Check if `perception_critical_distance` / `min_safe_distance` are appropriate for your obstacles
- Verify drift compensation is working (check Kalman uncertainty on the dashboard)
- If SASS exits back to idle without clearing, `consecutive_stuck_count` will climb and the Planner will request a waypoint skip after repeated attempts

**Cause**: Boat getting stuck repeatedly in obstacle-dense areas

**Solution**:

- Enable A* detour planning (`astar_enabled: true`, default) so the Planner routes around the obstacle cluster rather than relying on SASS to escape it
- Use the waypoint skip strategy (automatic after the 45 s `waypoint_skip_timeout`) to move past difficult areas

---

## Related Pages

- **[Glossary](Glossary)** — Definitions of Kalman filter, differential thrust, and other terms used above
- **[Design_Rationale](Design_Rationale)** — Why 12 s timeout, 1 m threshold, and "turn toward clearer side" were chosen
- **[System_Overview](System_Overview)** — High-level architecture
- **[3D_LIDAR_Processing](3D_LIDAR_Processing)** — LiDAR Perception that provides the `left_clear`/`right_clear` data SASS uses
- **[Common_Issues](Common_Issues)** — Troubleshooting guide
