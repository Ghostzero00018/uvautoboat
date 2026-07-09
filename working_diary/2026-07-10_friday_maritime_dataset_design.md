# Friday 10/07/2026 - Maritime Dataset Collection Design

## Day Overview

Turn the 09/07 proxy result into a concrete maritime data-collection design. The
proxy already answered the mechanical question: the real-image loop
capture -> label -> split -> train -> held-out firing runs end to end. It failed
only on data. About 30 near-duplicate, single-scale images produced a detector
that was confident nowhere at a usable threshold and blind to the held-out
scale. This diary designs the maritime dataset so the same, already-frozen
training loop produces usable-threshold firing on real held-out maritime frames.

Design only today. No capture, labeling, training, or execution. This is not
another bottle-model recovery pass; the optional proxy below is a logistics
rehearsal only.

## Carry-Over From 09/07

- The loop is mechanically valid; the failure was the dataset, not the pipeline.
- Even large `val` objects fired only around `0.016`; held-out `tier3_eval`
  (tiny) sat at background level around `0.007` with mAP50 `0.0`.
- Root cause: too few distinct examples (weak confidence everywhere) plus a
  single dominant object scale (no far/small generalization).
- Fixes carried into this design:
  1. materially more genuinely distinct examples per class, not more frames of
     one static scene;
  2. train/val scale coverage that spans the held-out distance range;
  3. held-out that stays scene- and placement-disjoint;
  4. a usable-threshold firing gate, not the `~0.003` floor or the `0.01` band.
- The frozen training config (`yolo26n.pt`, `imgsz=640`) is proven. This cycle
  changes the data, not the model, with training `imgsz` kept as an explicit
  small-object knob to decide (higher `imgsz` helps far/small at a batch / VRAM
  cost on the 6 GB RTX A3000).

## Target Classes And Minimum Per-Class Counts

Class map and first-pass label / do-not-label rules stay as defined in
`wiki/YOLO_Dataset_Plan.md`. Current reality: `9` labeled instances, all
`person`; `buoy`, `vessel`, `dock`, and `obstacle` have zero examples. The
dataset plan's sizing target is hundreds of labeled instances per active class;
do not repeat the 9-box pilot.

Fill per-bucket targets at manifest time before any capture:

| ID | Class | Current | Near | Mid | Far | Per-class target | Primary source |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 0 | `buoy` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX bootstrap |
| 1 | `vessel` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX, spawn-required |
| 2 | `dock` | 0 | TBD | TBD | TBD | hundreds (see plan) | VRX bootstrap |
| 3 | `obstacle` | 0 | TBD | TBD | TBD | hundreds (see plan) | RealSense / public / world-authoring |
| 4 | `person` | 9 | TBD | TBD | TBD | hundreds (see plan) | RealSense / public |

Distribution rule: no active bucket, and especially `far`, should fall below
about one third of that class total. The `far` bucket was the 09/07 miss and is
the most data-hungry.

## Distance Buckets

Define buckets by apparent object size so collection is measurable, not by feel:

- `near` - object taller than roughly one third of the frame height;
- `mid` - roughly one tenth to one third of frame height;
- `far` - below roughly one tenth of frame height (small, previously-missed
  regime).

Every active class needs coverage in each deployment-relevant bucket. Record the
measured apparent size per scene in the manifest, not just a subjective label.

## Placement, Lighting, Occlusion, Background Variation

Follow the capture protocol in `wiki/YOLO_Dataset_Plan.md` and prioritize
diversity over frame count:

- placement: vary position in frame, spacing, and orientation across scenes;
- lighting: overcast, direct sun, glare, backlight, dusk; on-water reflections;
- occlusion: partial occlusion where the class stays identifiable; skip frames
  where a target is not labelable;
- background: open water, shoreline, dock, vegetation, vessels, clutter;
- negatives: empty / background-only frames at each distance bucket;
- sampling: sparse frames on scene / distance / lighting / orientation change;
  no dense near-duplicate bursts.

## Split Rules

Use the four-way split contract from `wiki/YOLO_Dataset_Plan.md`
(`train` / `val` / `calib_hailo` / `tier3_eval`), assigned at capture / review
time and disjoint at the scene / condition level.

09/07 correction, binding for this cycle:

- `train`, `val`, and `tier3_eval` must span the **same** distance-bucket range,
  so the held-out set is not a scale-extrapolation trap.
- They must still be **scene- and placement-disjoint**, or the held-out only
  measures memorization.
- `tier3_eval` holds at least a few clear positives per active class in each
  active bucket, plus negatives, to record a meaningful held-out confidence
  distribution.

## Source Plan Per Class

Carry the 08/07 acquisition-manifest decisions:

- VRX can bootstrap `buoy`, `vessel` (spawn-required), and `dock`, with a
  domain-gap caveat versus real RealSense input;
- `obstacle` and `person` need real RealSense capture, admitted public data
  (licence and class-map checked), or explicit world / asset authoring; VRX
  `obstacle` / `person` remain unsupported without a separate source decision.

Fill the chosen source per class per bucket in the manifest before capture. Keep
all manifests, images, labels, weights, and runs outside the public repo.

## Pass Gate

This cycle passes only when a checkpoint trained on the new data fires on **real
held-out maritime** frames at a usable threshold:

- record the per-class held-out confidence distribution;
- require firing at `conf >= 0.05`, ideally `conf >= 0.25`, on `val` and
  `tier3_eval`;
- the `~0.003` floor and the `0.01` band do not count as usable firing.

Only after that gate passes should maritime deployment, dashboard integration,
or the Hailo accuracy-grade / Tier 3 path reopen.

## Optional Proxy Rehearsal

Run only if a capture-logistics rehearsal is wanted before water work. Keep it
short and explicitly not a recovery pass:

- 10-15 genuinely different scenes per distance bucket, not 12 static frames per
  scene;
- both proxy objects visible in every positive; negatives per bucket;
- purpose is to rehearse the multi-scale capture / label / split logistics, not
  to recover a model.

Skippable. The mechanical loop is already proven, so this adds logistics
practice only.

## Explicit Non-Claims

- No Hailo compile, calibration, Tier 3, or HEF work.
- No deployment, dashboard integration, MAVROS, QGC, Herelink, mission upload,
  arming, mode change, parameter write, thruster, or actuator path.
- No maritime detector-recovery claim until real held-out maritime firing works
  at a usable threshold.
- No production repo Python / YAML changes; all data and manifests stay outside
  the public repo.
- Design only today; capture, labeling, and training are gated on explicit
  approval.

**Next steps:** Confirm the per-class and per-bucket targets and the source
assignment, decide the training `imgsz` for the far bucket, then either run the
optional logistics rehearsal or plan the real maritime collection when water or
VRX access is available.
