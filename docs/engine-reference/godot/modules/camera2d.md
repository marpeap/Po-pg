# Godot Camera2D — Quick Reference (Garrison)

Last verified: 2026-05-19 | Engine: Godot 4.6

Garrison uses a follow camera with frame-rate-independent lerp.
World: 1080×1920. Viewport: TBD in ADR-001. Camera must constrain to world bounds.

---

## Key Properties (4.6)

| Property | Type | Default | Garrison usage |
|----------|------|---------|----------------|
| `position_smoothing_enabled` | bool | **false** | Set to false — use manual lerp instead (ADR-004) |
| `position_smoothing_speed` | float | 5.0 | N/A — manual lerp preferred |
| `drag_horizontal_enabled` | bool | false | Off — direct follow |
| `drag_vertical_enabled` | bool | false | Off — direct follow |
| `limit_left` | int | -10000000 | Set to 0 (world left edge) |
| `limit_right` | int | 10000000 | Set to 1080 (world right edge) |
| `limit_top` | int | -10000000 | Set to 0 (world top edge) |
| `limit_bottom` | int | 10000000 | Set to 1920 (world bottom edge) |

**Note on `position_smoothing_enabled`**: Godot's built-in smoothing is frame-rate-dependent
(it uses `delta` internally as a raw multiplier, not frame-rate-independent lerp).
For consistent feel at 30fps vs 60fps on Android, implement manual lerp instead (see ADR-004).

---

## Frame-Rate-Independent Lerp Formula

The correct formula for camera follow that behaves identically at any framerate:

```gdscript
# Frame-rate-independent lerp (ADR-004 pattern)
# lerp_factor = 0.10 (validated in prototype for camera)
# lerp_factor = 0.12 (validated in prototype for archer follow)

func _process(delta: float) -> void:
    var target: Vector2 = hero.global_position
    var weight: float = 1.0 - pow(1.0 - LERP_FACTOR, delta * 60.0)
    global_position = global_position.lerp(target, weight)
```

Where `pow(1.0 - factor, delta * 60.0)` normalises the lerp decay to a 60fps baseline.
At 30fps: one step applies ~double the factor (correct — fewer steps, each larger).
At 60fps: standard factor per frame.

**Do NOT use:**
```gdscript
# WRONG — frame-rate-dependent (feels faster at 60fps than 30fps)
global_position = global_position.lerp(target, LERP_FACTOR)
```

---

## World Bounds Constraint

Garrison world: 1080×1920 px. Camera must not show outside world edges.

```gdscript
func _ready() -> void:
    limit_left = 0
    limit_right = 1080
    limit_top = 0
    limit_bottom = 1920
    position_smoothing_enabled = false  # Manual lerp only
```

Godot applies limits AFTER position update, so manual lerp + limits work correctly together.

---

## Viewport / Zoom Dependency

Camera zoom setting depends on viewport resolution resolution (ADR-001):

| Viewport | World | Zoom needed |
|----------|-------|-------------|
| 540×960 | 1080×1920 | `zoom = Vector2(1, 1)` — world is 2× viewport |
| 1080×1920 | 1080×1920 | `zoom = Vector2(1, 1)` — 1:1 |
| 1080×960 | 1080×1920 | `zoom = Vector2(1, 1)` (width match), vertical scrolls |

**Resolve in ADR-001 before writing Camera code.**

---

## Common Mistakes

- Using `position_smoothing_enabled = true` — frame-rate-dependent, inconsistent on mobile
- Not setting world limits — camera can show black edges outside world bounds
- Lerping `global_position` while camera is child of hero — double-moves; camera must be scene root or independent node, not a hero child
- Forgetting that Camera2D limits are in world space, not viewport space
