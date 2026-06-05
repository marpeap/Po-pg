# Godot Area2D — Quick Reference (Garrison)

Last verified: 2026-05-19 | Engine: Godot 4.6

Garrison uses Area2D overlap exclusively for all proximity detection:
zone triggers (RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs), gold magnet, and projectile hits.
No RigidBody2D or CharacterBody2D physics. No Jolt involvement (3D only).

---

## Signals

| Signal | Signature | Fires when |
|--------|-----------|------------|
| `body_entered` | `(body: Node2D)` | A PhysicsBody2D or TileMapLayer enters this Area2D |
| `body_exited` | `(body: Node2D)` | A PhysicsBody2D or TileMapLayer exits this Area2D |
| `area_entered` | `(area: Area2D)` | Another Area2D overlaps this Area2D |
| `area_exited` | `(area: Area2D)` | Another Area2D stops overlapping |

**No breaking changes in 4.6** — signal signatures and behaviour are stable from 4.3.

---

## Required Properties

Both overlapping nodes must have:

| Property | Default | Required setting |
|----------|---------|------------------|
| `monitoring` | `true` | Must be `true` to detect other bodies/areas |
| `monitorable` | `true` | Must be `true` to be detected by other Area2Ds |

If `monitoring = false`, the area emits no signals. If `monitorable = false`,
other areas cannot detect it.

---

## Collision Layers & Masks

Garrison collision layer assignments (to define in Project Settings):

| Layer | Name | Used by |
|-------|------|---------|
| 1 | `hero` | Hero body |
| 2 | `enemy` | Enemy bodies |
| 3 | `zone` | RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs |
| 4 | `projectile` | Arrows |
| 5 | `coin` | Gold coins |
| 6 | `castle` | Castle hitbox |

Rules:
- Zone areas: `collision_layer = zone`, `collision_mask = hero` (detect hero only)
- Coin areas: `collision_layer = coin`, `collision_mask = hero` (hero collects)
- Projectile areas: `collision_layer = projectile`, `collision_mask = enemy` (hit detection)

---

## Garrison Usage Patterns

### Zone Dwell (RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs)

```gdscript
extends Area2D

signal dwell_completed(zone: Area2D)

const DWELL_TIME: float = 0.8  # Validated in prototype
var _dwell_timer: float = 0.0
var _hero_inside: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
    if _hero_inside:
        _dwell_timer += delta
        if _dwell_timer >= DWELL_TIME:
            dwell_completed.emit(self)
            _dwell_timer = 0.0  # Prevent repeat-firing; disable zone next frame

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group(&"hero"):
        _hero_inside = true

func _on_body_exited(body: Node2D) -> void:
    if body.is_in_group(&"hero"):
        _hero_inside = false
        _dwell_timer = 0.0
```

### Gold Magnet (Economy)

```gdscript
# On the HeroMagnet Area2D node — radius 170px, validated in prototype
extends Area2D

func _ready() -> void:
    area_entered.connect(_on_coin_entered)

func _on_coin_entered(area: Area2D) -> void:
    if area.is_in_group(&"coin"):
        area.attract_to(global_position)
```

### Projectile Hit Detection (Archer → Enemy)

```gdscript
# On each Arrow Area2D
extends Area2D

func _ready() -> void:
    area_entered.connect(_on_hit)

func _on_hit(area: Area2D) -> void:
    if area.is_in_group(&"enemy"):
        area.take_damage(PROJ_DAMAGE)
        queue_free()  # Arrow consumed on hit (or return to pool)
```

---

## Common Mistakes

- Setting `monitoring = false` accidentally (area emits no signals, zone never triggers)
- Connecting `body_entered` when two Area2Ds overlap (use `area_entered` for Area2D vs Area2D)
- Not setting collision mask — area fires for ALL physics bodies if mask = 0 (all layers)
- Not disconnecting signals before `queue_free()` — use `queue_free()` only; Godot auto-disconnects
