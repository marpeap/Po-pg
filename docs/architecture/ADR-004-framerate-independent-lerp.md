# ADR-004: Frame-Rate-Independent Lerp — Camera and Archer Follow

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Garrison targets 60fps on Android but must feel identical at 30fps (low-end devices).
All lerp-based follow systems (Camera2D tracking hero, archer nodes tracking formation slots)
use the formula `weight = 1.0 - pow(1.0 - FACTOR, delta * 60.0)` to normalize decay to
a 60fps baseline. Godot's built-in `position_smoothing_enabled` is disabled everywhere
because it applies `delta` as a raw multiplier (frame-rate-dependent).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting / Camera |
| **Knowledge Risk** | MEDIUM — `position_smoothing_enabled` behavior (frame-rate-dependent) verified against Godot 4.6 docs; the lerp formula itself is engine-agnostic math |
| **References Consulted** | `docs/engine-reference/godot/modules/camera2d.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None — `Camera2D.position_smoothing_enabled`, `lerp()`, `pow()` are stable |
| **Verification Required** | Test camera follow at 30fps (set Engine.time_scale or use a slow device) and 60fps; verify that hero reaches the same relative position in the frame's viewport at both framerates. Acceptable delta: ≤5% position difference at any moment. |

> **Note**: Knowledge Risk MEDIUM — re-validate if upgrading past Godot 4.6, as smoothing internals could change.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-001 (Camera2D setup; this ADR defines the lerp applied after ADR-001 configures limits) |
| **Enables** | None |
| **Blocks** | Camera script implementation, archer formation follow implementation |
| **Ordering Note** | ADR-001 must be Accepted first (defines Camera2D limits and `position_smoothing_enabled = false`) |

## Context

### Problem Statement

`camera.md` GDD specifies: "use manual lerp instead — ADR-004" with `position_smoothing_enabled = false`.
`archer-formation.md` specifies `ARCHER_FOLLOW_LERP = 0.12` validated in prototype 1.
Neither GDD specifies the exact lerp formula. Without a mandated formula, programmers may use
the naive `lerp(pos, target, FACTOR)` — which is frame-rate-dependent and produces noticeably
different feel at 30fps vs 60fps on Android.

### Current State

No camera or archer follow code exists.

### Constraints

- Garrison targets 60fps; minimum viable feel at 30fps (low-end Android)
- `position_smoothing_enabled = true` is explicitly forbidden (frame-rate-dependent per `camera2d.md`)
- ARCHER_FOLLOW_LERP = 0.12 was validated at a specific framerate (prototype 1 — assumed 60fps)
- Camera lerp factor = 0.10 (validated in prototype for camera, per `camera2d.md`)
- Formula must be implementable in GDScript without external libraries
- `pow()` and `lerp()` are both built-in GDScript functions

### Requirements

- Camera follow must feel identical at 30fps and 60fps (≤5% positional difference)
- Archer follow must feel identical at 30fps and 60fps
- ARCHER_FOLLOW_LERP = 0.12 at 60fps baseline must produce exactly the same result at 30fps
- Formula must be understandable and copy-pasteable for any future lerp system
- `Camera2D.position_smoothing_enabled` must be `false` on all Camera2D nodes

## Decision

**Canonical formula** for all lerp-based follow in Garrison:

```gdscript
var weight: float = 1.0 - pow(1.0 - LERP_FACTOR, delta * 60.0)
var new_pos: Vector2 = current_pos.lerp(target_pos, weight)
```

**Why this formula**:
- At 60fps: `delta ≈ 0.01667s` → `weight = 1.0 - pow(1.0 - F, 1.0) = F` — exactly the factor
- At 30fps: `delta ≈ 0.03333s` → `weight = 1.0 - pow(1.0 - F, 2.0)` — applies two 60fps steps worth of decay in one frame. Geometrically correct.
- At any framerate N: `weight = 1.0 - pow(1.0 - F, delta * 60)` = N steps of decay per second

**Validated lerp factors**:

| System | LERP_FACTOR | Validated in | Notes |
|--------|------------|--------------|-------|
| Camera follow | `LERP_FACTOR = 0.10` | Prototype 1 (60fps baseline) | Camera trails slightly behind hero for "weight" feel |
| Archer follow | `ARCHER_FOLLOW_LERP = 0.12` | Prototype 1 (60fps baseline) | Slightly tighter than camera — archers feel responsive |

**Forbidden** (naive frame-rate-dependent lerp):
```gdscript
# WRONG — do not use anywhere in Garrison
new_pos = current_pos.lerp(target_pos, LERP_FACTOR)  # delta not used → frame-rate-dependent
```

**Camera2D `position_smoothing_enabled`**: Set to `false` in `_ready()` on all Camera2D nodes.
Do not set it to `true` at any point. No exceptions.

### Architecture

```
_process(delta) called each frame
        │
        ├─ Camera2D script
        │    target = hero.global_position
        │    weight = 1.0 - pow(1.0 - 0.10, delta * 60.0)
        │    global_position = global_position.lerp(target, weight)
        │    [Camera2D limits applied automatically by Godot after position update]
        │
        └─ ArcherFormation script (per occupied slot)
             slot_world_pos = compute_slot_pos(hero_pos, facing_angle, slot_index)
             weight = 1.0 - pow(1.0 - 0.12, delta * 60.0)
             archer.position = archer.position.lerp(slot_world_pos, weight)
             [Snap check: if distance > ARCHER_SNAP_THRESHOLD → direct assign]
```

### Key Interfaces

```gdscript
# camera_follow.gd — Camera2D script
extends Camera2D

const LERP_FACTOR: float = 0.10  # validated in prototype 1

@export var hero: Node2D  # assign in editor

func _ready() -> void:
    position_smoothing_enabled = false  # MANDATORY — never enable built-in smoothing
    limit_left   = 0
    limit_right  = 1080
    limit_top    = 0
    limit_bottom = 1920

func _process(delta: float) -> void:
    if hero == null:
        return
    var target: Vector2 = hero.global_position
    var weight: float = 1.0 - pow(1.0 - LERP_FACTOR, delta * 60.0)
    global_position = global_position.lerp(target, weight)
    # Camera2D limits are applied by Godot after position update — no manual clamping needed
```

```gdscript
# archer_formation.gd — archer follow per occupied slot (called in _process)
const ARCHER_FOLLOW_LERP: float = 0.12  # validated in prototype 1
const ARCHER_SNAP_THRESHOLD: float = 300.0

func _update_archer_positions(delta: float) -> void:
    var weight: float = 1.0 - pow(1.0 - ARCHER_FOLLOW_LERP, delta * 60.0)
    for i in _current_archer_count:
        var target: Vector2 = _compute_slot_world_pos(i)
        var dist: float = _archer_nodes[i].position.distance_to(target)
        if dist > ARCHER_SNAP_THRESHOLD:
            _archer_nodes[i].position = target  # snap
        else:
            _archer_nodes[i].position = _archer_nodes[i].position.lerp(target, weight)
```

### Implementation Guidelines

1. **Copy the formula verbatim** — do not simplify, reorder, or optimize without benchmarking.
   `pow()` on GDScript is fast; premature optimization here is not warranted.
2. **Constants are tuning knobs** — LERP_FACTOR (camera) and ARCHER_FOLLOW_LERP (archers)
   must be `const` at the top of their scripts and listed in the GDD Tuning Knobs section.
   They must NOT be hardcoded inline.
3. **`_process`, not `_physics_process`** — lerp follow runs in `_process` (visual update)
   because it is positional interpolation, not physics. Camera2D limits apply after
   `_process` position assignment. Confirmed correct by Godot documentation.
4. **Snap threshold check** must come BEFORE the lerp, not after. Compute distance first;
   if above threshold, assign directly (no lerp weight applied).
5. **Any new lerp-based follow system** (HUD elements, UI transitions, enemy pathfinding)
   must use this same formula. Add a code comment referencing ADR-004.
6. **Do not use `Tween` for continuous follow** — Tweens are for one-shot animations.
   Continuous follow requires per-frame lerp in `_process`.

## Alternatives Considered

### Alternative 1: Godot built-in `position_smoothing_enabled = true`

- **Description**: Enable Camera2D's built-in position smoothing.
- **Pros**: Zero code — enable one property, set `position_smoothing_speed`.
- **Cons**: Godot's implementation applies delta as a raw multiplier internally (equivalent
  to the naive formula). At 30fps the camera moves faster per frame than at 60fps —
  the same issue we are solving. Confirmed frame-rate-dependent in `camera2d.md`.
- **Rejection Reason**: Explicitly forbidden by the camera GDD.

### Alternative 2: Exponential decay with `exp(-k * delta)`

- **Description**: `weight = 1.0 - exp(-k * delta)` where k is the decay constant.
- **Pros**: Mathematically equivalent continuous-time formulation.
- **Cons**: k must be derived from the desired per-frame factor: `k = -ln(1 - F) * 60.0`.
  Harder to tune intuitively. Prototype used the `pow()` form — using `exp()` would produce
  identical results but require converting the validated factors.
- **Rejection Reason**: Same result; the `pow()` form matches the prototype's validated
  constants directly and is more readable for GDScript.

### Alternative 3: Fixed-timestep physics process for follow

- **Description**: Run follow in `_physics_process` (fixed 60hz by default).
- **Pros**: Deterministic timestep — no delta variation.
- **Cons**: Visual position updates in `_physics_process` cause jitter at non-60fps
  display rates (stutter between physics steps). Camera and archer positions are visual,
  not physical — they belong in `_process`. Godot's recommended approach for camera follow
  is `_process`.
- **Rejection Reason**: Visual jitter at display rates below the physics rate.

## Consequences

### Positive

- Camera and archer follow feel identical at 30fps and 60fps
- Validated lerp factors from prototype 1 are directly usable with no conversion
- Formula is transparent, testable, and copy-pasteable
- Any future lerp system in Garrison can use the same formula

### Negative

- `pow()` is called once per frame per lerp system (camera + 8 archers = 9 `pow()` calls/frame)
  — negligible on any hardware, but worth noting
- Requires discipline: every programmer must use this formula, not the naive lerp

### Neutral

- The formula produces slightly different weights at fractional framerates (e.g. 45fps)
  compared to the theoretical continuous-time limit — the difference is imperceptible

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Programmer uses naive lerp (no delta in weight) | Medium | Low-Medium (feels different at 30fps) | Code review: grep for `lerp(` in camera and formation scripts; verify delta is in the weight formula |
| ARCHER_FOLLOW_LERP tuned above 0.25 (GDD safe range max) | Low | Low (archers snap) | Tuning knob safe range is documented in archer-formation.md; ADR note references it |
| `position_smoothing_enabled` accidentally set to true | Low | Low-Medium (inconsistent feel) | Validation criterion + code review |

## Performance Implications

| Metric | Built-in smoothing | Manual lerp (chosen) | Budget |
|--------|------------------|----------------------|--------|
| `pow()` calls/frame | 0 | 9 (camera + 8 archers) | Negligible |
| GDScript overhead/frame | 0 | ~0.01ms | 16.6ms |
| Behavioral correctness | Frame-rate-dependent | Frame-rate-independent | Required |

## Migration Plan

No existing camera or follow code. Initial implementation:

1. Create `src/camera/camera_follow.gd` using the key interface above
2. Create `Camera2D` node in main scene; attach `camera_follow.gd`; set `position_smoothing_enabled = false` in `_ready()`
3. In `archer_formation.gd`, implement `_update_archer_positions(delta)` using the archer formula

**Rollback plan**: Replace the formula with `lerp(pos, target, LERP_FACTOR)` (naive form).
The feel will be frame-rate-dependent but functional for testing purposes.

## Validation Criteria

- [ ] Camera at 60fps: hero exits frame center by 400px and returns — camera catches up in ≤1.5s
- [ ] Camera at 30fps (halved): same scenario produces ≤5% positional difference at any moment compared to 60fps run
- [ ] Camera at 30fps: `position_smoothing_enabled` confirmed false — no built-in smoothing interference
- [ ] Archer follow at 60fps: archer placed 100px from slot converges to <5px distance in ≤0.5s
- [ ] Archer follow at 30fps: same convergence behavior — ≤5% difference at any moment vs 60fps
- [ ] Snap: archer at 301px from slot position is placed exactly at slot position in one frame

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/camera.md` | Camera | "position_smoothing_enabled = false — use manual lerp instead (ADR-004)" | Defines the manual lerp formula; mandates position_smoothing_enabled = false |
| `design/gdd/camera.md` | Camera | "lerp_factor = 0.10 (validated in prototype for camera)" | Adopts LERP_FACTOR = 0.10 as the camera constant in the canonical formula |
| `design/gdd/archer-formation.md` | Archer Formation | "ARCHER_FOLLOW_LERP = 0.12 (validated in prototype 1)" | Adopts ARCHER_FOLLOW_LERP = 0.12 in the canonical formula; adds snap threshold check |

## Related

- ADR-001 — Viewport Resolution (Camera2D limits set there; this ADR defines the lerp applied each frame)
- `docs/engine-reference/godot/modules/camera2d.md` — documents `position_smoothing_enabled` frame-rate dependency
