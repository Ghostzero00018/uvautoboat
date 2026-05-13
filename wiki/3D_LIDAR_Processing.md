# 3D LIDAR Processing (LiDAR Perception v2.1)

Deep dive into the **Perception** system — 3D LIDAR point cloud processing for obstacle detection.

> 💡 **Related pages:**
>
> - For **term definitions** (point cloud, clustering, temporal filtering, VFH, etc.), see **[Glossary](Glossary)**.
> - For **why these thresholds and algorithm choices** were made, see **[Design_Rationale](Design_Rationale#parameter-thresholds-explained)**.

---

## Overview

The **LiDAR Perception** node is the perception subsystem that processes 3D LIDAR data to detect obstacles in real-time. It uses advanced filtering techniques to provide reliable obstacle information to the navigation system.

---

## What is LIDAR?

**LIDAR** (Light Detection and Ranging) uses laser pulses to create a 3D map of the environment. The WAM-V's 3D LIDAR returns thousands of points per scan, each with X, Y, Z coordinates.

**Key Specifications:**

- **Scan Rate**: ~10-20 Hz
- **Points per Scan**: 10,000-50,000
- **Range**: 0-100m (configurable)
- **Field of View**: 360° horizontal, variable vertical

---

## Processing Pipeline

The Perception node v2.1 uses an 8-step processing pipeline:

```text
┌─────────────────────────────────────────────────────────┐
│  1. RAW POINT CLOUD                                     │
│     ↓ (Gazebo simulation: ~20K points/scan)            │
├─────────────────────────────────────────────────────────┤
│  2. HEIGHT FILTER (-15m to +10m)                        │
│     ↓ Removes sky and extreme water reflections        │
├─────────────────────────────────────────────────────────┤
│  3. RANGE FILTER (5m to 50m)                            │
│     ↓ Ignores boat structure and distant irrelevant    │
├─────────────────────────────────────────────────────────┤
│  4. WATER PLANE REMOVAL                                 │
│     ↓ Estimates water surface, filters reflections     │
├─────────────────────────────────────────────────────────┤
│  5. SECTOR ANALYSIS (Front/Left/Right)                  │
│     ↓ Calculates minimum distance per sector           │
├─────────────────────────────────────────────────────────┤
│  6. TEMPORAL FILTERING (5-scan history)                 │
│     ↓ Requires 3/5 detections to confirm               │
├─────────────────────────────────────────────────────────┤
│  7. OBSTACLE CLUSTERING (DBSCAN, eps=2m)                │
│     ↓ Groups points into distinct obstacles            │
├─────────────────────────────────────────────────────────┤
│  8. GAP DETECTION & VFH POLAR HISTOGRAM                 │
│     ↓ Finds passable gaps, picks target-aware free gap │
└─────────────────────────────────────────────────────────┘
```

---

## Step-by-Step Explanation

### Step 1: Height Filter

**Purpose**: Remove irrelevant points (sky, extreme water reflections)

| Surface | Typical Z | Action |
|:--------|:----------|:-------|
| Sky | > +10m | Filter out |
| Obstacles on dock | 0 to +2m | ✅ Keep |
| Lake bank/terrain | ≈ -2.5m | ✅ Keep |
| Water surface | ≈ -3m | Keep for water plane estimation |
| Extreme reflections | < -15m | Filter out |

**Parameters:**

- `min_height`: -15.0m (default)
- `max_height`: +10.0m (default)

**Rationale**: LIDAR mounted ~2-3m above water, so water appears at negative Z.

---

### Step 2: Range Filter

**Purpose**: Ignore nearby boat structure and distant clutter

| Range | Reason |
|:------|:-------|
| **< 5m** | Boat hull, sensors, dock at spawn point |
| **5-50m** | ✅ Relevant obstacle detection range |
| **> 50m** | Too distant for navigation decisions |

**Parameters:**

- `min_range`: 5.0m (default)
- `max_range`: 50.0m (default)

**Note**: Adjust `min_range` if you see "CRITICAL" warnings at spawn due to nearby dock.

---

### Step 3: Water Plane Removal

**Purpose**: Filter water surface reflections that aren't actual obstacles

**Algorithm:**

1. Calculate **5th percentile** of Z values (low points = likely water)
2. Set water plane Z estimate
3. Remove points within ±0.5m of water plane

**Why 5th percentile?**

- Robust to outliers (not affected by obstacles above water)
- Adapts to varying water surface height in simulation

**Parameter:**

- `water_plane_threshold`: 0.5m (tolerance)

---

### Step 4: Sector Analysis

**Purpose**: Divide 360° view into actionable sectors

#### Sector Definitions

| Sector | Angle Range | Purpose | Width |
|:-------|:------------|:--------|:------|
| **FRONT** | -45° to +45° | Forward collision detection | 90° (adaptive) |
| **LEFT** | +45° to +135° | Left side clearance | 90° |
| **RIGHT** | -135° to -45° | Right side clearance | 90° |

**Adaptive Front Sector:**
The front sector width adjusts based on target heading error:

- Small error → Narrow sector (focused ahead)
- Large error (turning) → Wide sector (check periphery)

#### Minimum Distance Calculation

For each sector, the Perception node finds the **closest point**:

```python
front_clear = min(distance_to_point for point in front_sector)
left_clear = min(distance_to_point for point in left_sector)
right_clear = min(distance_to_point for point in right_sector)
```

If sector is empty → clearance = `max_range` (50m)

---

### Step 5: Temporal Filtering

**Purpose**: Reduce false positives from noise or transient reflections

**Algorithm:**

- Maintain **5-scan history** (rolling window)
- For each sector, count detections in last 5 scans
- Confirm obstacle only if detected in **≥3 out of 5 scans** (60%)

**Parameters:**

- `temporal_history_size`: 5 (default)
- `temporal_threshold`: 3 (default)

**Benefits:**

- **Reduces flickering**: Transient reflections don't trigger false alarms
- **Maintains responsiveness**: 3/5 threshold allows quick detection (≤500ms)
- **Adapts to scan rate**: Works with varying LIDAR frequencies

**Example:**

```text
Scan 1: Front obstacle at 8m ✓
Scan 2: Front clear (noise)
Scan 3: Front obstacle at 7.5m ✓
Scan 4: Front obstacle at 7m ✓
Scan 5: Front clear (noise)
→ 3/5 detections → CONFIRMED obstacle
```

---

### Step 6: Distance-Weighted Urgency

**Purpose**: Smooth control response instead of binary "obstacle yes/no"

**Urgency Score**: 0.0 (safe) to 1.0 (critical)

```python
if distance > safe_distance:
    urgency = 0.0  # No concern
elif distance < critical_distance:
    urgency = 1.0  # Maximum urgency
else:
    # Linear interpolation
    urgency = 1.0 - (distance - critical_distance) / (safe_distance - critical_distance)
```

| Distance | Urgency | Meaning |
|:---------|:--------|:--------|
| > 15m | 0.0 | ✅ Clear |
| 10m | 0.5 | ⚠️ Caution |
| 5m | 1.0 | 🚨 Critical |

**Benefits:**

- **Smooth thrust reduction**: Gradual slowdown instead of sudden stop
- **Proportional response**: Closer obstacles → stronger reaction
- **Better control**: No oscillation between "go" and "stop"

---

### Step 7: Obstacle Clustering

**Purpose**: Group nearby points into distinct obstacles

**Algorithm**: DBSCAN (Density-Based Spatial Clustering)

**Parameters:**

- `cluster_distance` (eps): 2.0m (max distance between cluster points)
- `min_cluster_size` (min_samples): 3 (min points to form obstacle)

**Output**: List of obstacles with:

- **Centroid**: Average (x, y) position
- **Size**: Number of points
- **Distance**: Range from boat
- **Angle**: Bearing (degrees)

**Example JSON:**

```json
"clusters": [
  {"x": 8.2, "y": 1.5, "size": 25, "distance": 8.5, "angle_deg": 10.3},
  {"x": 12.0, "y": -3.0, "size": 18, "distance": 12.4, "angle_deg": -14.0}
]
```

---

### Step 8: Gap Detection

**Purpose**: Find passable gaps between obstacles for navigation

**Algorithm:**

1. Sort obstacles by angle
2. Calculate angular gap between consecutive obstacles
3. Filter gaps > minimum width (3m default)

**Output**: List of gaps with:

- **Angle**: Direction (degrees)
- **Width**: Gap size (meters)
- **Distance**: Range to gap

**Example JSON:**

```json
"gaps": [
  {"angle_deg": -25.0, "width": 5.2, "distance": 15.0},
  {"angle_deg": 45.0, "width": 8.1, "distance": 20.0}
]
```

**Use Case**: Controller can steer toward gaps when obstacles block direct path.

---

## Output Message Format

The Perception node publishes obstacle information to `/perception/obstacle_info` as JSON:

```json
{
  "obstacle_detected": true,
  "min_distance": 8.5,
  "front_clear": 10.2,
  "left_clear": 45.0,
  "right_clear": 12.3,
  "is_critical": false,
  "front_urgency": 0.45,
  "left_urgency": 0.0,
  "right_urgency": 0.35,
  "overall_urgency": 0.45,
  "clusters": [
    {"x": 8.2, "y": 1.5, "size": 25, "distance": 8.5, "angle_deg": 10.3}
  ],
  "gaps": [
    {"angle_deg": -25.0, "width": 5.2, "distance": 15.0}
  ],
  "water_plane_z": -2.8,
  "temporal_confidence": 1.0
}
```

---

## Configuration Parameters

### In `autoboat.launch.yaml` (Perception node)

| Parameter | Default | Description |
|:----------|:--------|:------------|
| `perception_min_safe_distance` | 10.0 | Safe clearance distance (m) |
| `perception_critical_distance` | 5.5 | Critical stop distance (m) |
| `min_height` | -15.0 | Minimum Z to keep (m) |
| `max_height` | 10.0 | Maximum Z to keep (m) |
| `min_range` | 5.0 | Minimum detection range (m) |
| `max_range` | 50.0 | Maximum detection range (m) |
| `temporal_history_size` | 5 | Scans in history |
| `temporal_threshold` | 3 | Min detections to confirm |
| `cluster_distance` | 2.0 | DBSCAN eps (m) |
| `min_cluster_size` | 3 | DBSCAN min samples |
| `water_plane_threshold` | 0.5 | Water filtering tolerance (m) |

---

## Tuning Guide

### Problem: Too Many False Alarms

**Solution**: Increase temporal filtering

```yaml
temporal_history_size: 7
temporal_threshold: 5  # Require 5/7 detections
```

### Problem: Slow Reaction to Obstacles

**Solution**: Reduce temporal filtering

```yaml
temporal_history_size: 3
temporal_threshold: 2  # Require 2/3 detections
```

### Problem: Water Reflections Detected as Obstacles

**Solution**: Adjust water plane removal

```yaml
water_plane_threshold: 0.8  # More aggressive filtering
```

### Problem: Missing Small Obstacles

**Solution**: Reduce cluster size requirement

```yaml
min_cluster_size: 2  # Detect obstacles with only 2 points
```

### Problem: "CRITICAL" Warning at Spawn

**Solution**: Increase minimum range

```yaml
min_range: 7.0  # Ignore nearby dock
```

---

## Monitoring Perception

### Check LIDAR Data

```bash
# Check scan rate
ros2 topic hz /wamv/sensors/lidars/lidar_wamv_sensor/points

# View raw point cloud (first scan)
ros2 topic echo /wamv/sensors/lidars/lidar_wamv_sensor/points --once
```

### Monitor Obstacle Info

```bash
ros2 topic echo /perception/obstacle_info
```

### Visualize in RViz

```bash
rviz2
# Add PointCloud2 display
# Topic: /wamv/sensors/lidars/lidar_wamv_sensor/points
# Fixed Frame: wamv/base_link
```

---

## Performance Characteristics

| Metric | Value |
|:-------|:------|
| **Processing Latency** | ~10-50ms per scan |
| **Detection Range** | 5-50m |
| **Update Rate** | 10-20 Hz |
| **False Positive Rate** | < 5% (with temporal filtering) |
| **False Negative Rate** | < 2% (for obstacles > 0.5m diameter) |

---

## VFH (Vector Field Histogram) — Optional Advanced Avoidance

In addition to the 3-sector Front/Left/Right summary, the Perception node also implements a **Vector Field Histogram (VFH)** algorithm that produces a finer-grained obstacle analysis. This output is made available to the Controller via the `use_vfh_bias` parameter — when enabled, the Controller biases its steering command toward VFH's "best gap" direction. **In the default YAML config, `use_vfh_bias` is `false`** and the system uses the simpler 3-sector method.

### What VFH is

VFH is a classical reactive obstacle-avoidance algorithm invented by Johann Borenstein and Yoram Koren at the University of Michigan in 1991. The name captures two ideas:

1. Obstacles are treated as a repulsive **vector field** pushing the robot away.
2. This field is summarised as a **polar histogram** — a 1D graph indexed by heading angle.

### The algorithm in three steps

1. **Build a polar histogram around the robot.** Divide the 360° space around the boat into angular bins (e.g., 5° each = 72 bins). For each bin, sum the "obstacle density" — LiDAR points that fall in that direction, weighted by how close they are (closer obstacles contribute more). X-axis = heading angle, Y-axis = obstacle density.

2. **Threshold to find openings.** Compare each bin to a threshold. Bins below the threshold are "traversable". Contiguous traversable bins form a **candidate gap** (opening) with a centre angle and an angular width.

3. **Pick the best gap.** From all candidate gaps, choose the one that balances two criteria: (a) wide enough to fit the boat safely, (b) closest to the current target direction so the boat does not veer off course. The centre of that gap becomes the new steering heading.

### Why VFH is disabled by default

In clean worlds like `sydney_regatta_DEFAULT` there are few obstacles, so the simpler 3-sector avoidance is not only sufficient but actually **more stable** — it has fewer parameters to tune and does not oscillate when the best-gap jumps between two similar openings frame-to-frame.

VFH shines in **cluttered worlds** (buoy fields, piers, anchored boat fleets) where the *structure* of the whole obstacle field matters. That is why 3 out of 4 dashboard tuning presets that enable VFH are named for cluttered scenarios (`Buoy Field`, `Pier`, `Universal`).

### Limitations

VFH is a **local, reactive** method — it reacts to what it sees *now*, with no memory and no global planning. It can get stuck in local minima (dead-end corridors where the widest gap leads back the way the robot came). That is why VFH is paired with the Planner's global lawnmower + A\* rerouting — VFH handles "how to squeeze through obstacles locally", the Planner handles "where to go overall".

### Variants

- **VFH (1991)** — the original algorithm above
- **VFH+ (1998)** — adds kinematic constraints (turning radius)
- **VFH\* (2000)** — combines VFH with A\*-style lookahead for more global planning

This project implements a basic VFH.

---

## Threshold Rationale

All numeric thresholds in the pipeline are tuned empirically for VRX scenarios. This table explains **why** each parameter has its current value:

| Parameter | Value | Why this value |
|:----------|:------|:----------------|
| **Range filter** lower bound | 2.2 m | Below this, returns are from the boat's own hull (pontoons/deck). Filtering them out prevents "permanent obstacles in front of the boat". |
| **Range filter** upper bound | 100 m | Beyond this, returns are too distant to act on in a 20 Hz control loop; dropping them reduces noise. |
| **Height filter** lower bound | −1.2 m | Captures low piers and floating debris while excluding deep underwater returns. |
| **Height filter** upper bound | 1.5 m | Focused on actual navigation hazards; points higher than this (birds, high overhangs) are not threats to the hull. |
| **Water plane threshold** | 0.32 m | Tolerance for the dynamic 5th-percentile water-plane Z estimate. Points within this tolerance are dropped. Chosen to reject small ripples without dropping low-floating debris. |
| **Cluster distance** | 3.0 m | Max distance between points in the same cluster. Matches the typical spacing of points returned from a single obstacle at moderate range — a finer value splits real obstacles, a coarser one merges distinct obstacles. |
| **Minimum cluster size** | 8 points | Rejects solitary points (sensor noise) while accepting small real obstacles like buoys. |
| **Temporal history** | 3 scans | Rolling buffer of recent scans. |
| **Temporal threshold** | 2 scans | An obstacle must appear in 2 of the last 3 scans before it is confirmed. At 10 Hz LiDAR rate, this adds ~200 ms of confirmation latency — a worthwhile trade for rejecting single-frame ghosts. |
| **Sector clearance percentile** | 10th | For each sector, clearance is the 10th percentile of point distances in that direction. Lower than the median but above the absolute minimum — resistant to a single outlier point (which would collapse clearance to near-zero) while still capturing the "closest credible threat". |

For the **trade-off analysis** behind each choice, see **[Design_Rationale: Parameter Thresholds Explained](Design_Rationale#parameter-thresholds-explained)**.

---

## Related Pages

- **[Glossary](Glossary)** — Definitions of every term used above
- **[Design_Rationale](Design_Rationale)** — Why these algorithm and parameter choices were made
- **[System_Overview](System_Overview)** — High-level architecture
- **[SASS](SASS)** — Anti-stuck recovery system
- **[Common_Issues](Common_Issues)** — Troubleshooting guide
