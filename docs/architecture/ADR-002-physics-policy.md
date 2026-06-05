# ADR-002: Physics Policy — Area2D Overlap Only, No Jolt, No RigidBody2D

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Garrison uses no physics bodies for gameplay. All proximity detection, zone triggers,
gold magnet, and projectile hit detection are implemented with `Area2D` overlap signals.
Jolt physics is excluded: it is 3D-only in Godot 4.6 and irrelevant to this 2D game.
No `RigidBody2D`, `CharacterBody2D`, or `StaticBody2D` nodes are used anywhere.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Collision |
| **Knowledge Risk** | LOW — Area2D overlap API has been stable since Godot 4.0; Jolt 3D-only status confirmed in breaking-changes.md |
| **References Consulted** | `docs/engine-reference/godot/modules/area2d.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None — `Area2D`, `body_entered`, `area_entered` signals are unchanged from 4.3 |
| **Verification Required** | Confirm in a Godot 4.6 project that `Area2D.body_entered` fires for `CharacterBody2D` overlap (not needed in Garrison, but confirms Area2D is functioning); confirm Jolt is absent from 2D physics options |

> **Note**: Knowledge Risk LOW — Area2D is foundational and well-tested.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-003 (projectile pool uses Area2D for hit detection) |
| **Blocks** | All collision/overlap code in: hero-movement, zone triggers (Economy), gold magnet (Economy), projectile hit (Archer Formation), castle hitbox |
| **Ordering Note** | Must be Accepted before any collision node is placed in the scene tree |

## Context

### Problem Statement

Multiple GDD systems require proximity and overlap detection: zone dwell timers
(RECRUIT_ZONE, TOWER_ZONE, 4× FORGE_ZONEs), gold coin magnet radius, arrow-to-enemy
hit detection, and castle damage on enemy contact. Without a physics policy, each
programmer might choose a different physics body type — leading to inconsistent
behavior and unexpected signal routing.

Additionally, Godot 4.6 defaults to Jolt physics. The `area2d.md` reference confirms
Jolt is **3D only** — it does not affect 2D physics. This must be explicitly documented
so no programmer wastes time configuring Jolt for 2D.

### Current State

No physics configuration exists. Project uses Godot 4.6 defaults.

### Constraints

- **2D game**: No 3D physics, no Jolt involvement
- **No movement physics**: Hero movement is joystick-driven via code; enemies march at
  constant speed — no physics forces required
- **Performance**: ≤150 draw calls, 60fps. Area2D overlap is lightweight; physics body
  collision is heavier and overkill for this use case
- **Godot 4.6**: Jolt is default for 3D, irrelevant for 2D. GodotPhysics2D handles all 2D.

### Requirements

- Zone dwell detection must fire `body_entered` / `body_exited` when hero enters/exits zones
- Gold magnet must detect when coin Area2Ds enter the hero magnet radius
- Projectile hit detection must fire when an arrow Area2D overlaps an enemy Area2D
- Castle damage must fire when an enemy reaches the castle position
- All detections must be frame-accurate (signal fires in the same frame overlap begins)
- No physics simulation forces (gravity, velocity, collision response) are required

## Decision

**Physics body usage**: NONE in gameplay. All collision is Area2D overlap only.

**Jolt physics**: Not configured, not used. Jolt is 3D-only in Godot 4.6. Leave all
2D physics settings at Godot defaults (GodotPhysics2D). No Jolt configuration in
Project Settings.

**Collision layers** (defined in Project Settings → Physics → 2D → Layer Names):

| Layer | Name | Used by |
|-------|------|---------|
| 1 | `hero` | Hero node (Area2D) |
| 2 | `enemy` | Enemy nodes (Area2D) |
| 3 | `zone` | RECRUIT_ZONE, TOWER_ZONE, 4× FORGE_ZONEs (Area2D) |
| 4 | `projectile` | Arrow nodes (Area2D) |
| 5 | `coin` | Gold coin nodes (Area2D) |
| 6 | `castle` | Castle hitbox (Area2D) |

**Collision mask rules** (what each node detects):

| Node | `collision_layer` | `collision_mask` | Detects |
|------|------------------|-----------------|---------|
| Hero | `hero` (1) | None needed for hero itself | — |
| HeroMagnet (child of Hero) | None | `coin` (5) | Gold coins |
| Zone areas | `zone` (3) | `hero` (1) | Hero entering zone |
| Enemy | `enemy` (2) | `castle` (6) | Castle contact |
| Arrow | `projectile` (4) | `enemy` (2) | Enemy hit |
| Coin | `coin` (5) | None | (detected by HeroMagnet) |
| Castle | `castle` (6) | `enemy` (2) | Enemy reach |

**Signal routing rules**:
- **Area2D vs PhysicsBody2D overlap**: Use `body_entered` / `body_exited` — NEVER used in Garrison
  (no PhysicsBody2D nodes exist). Do not implement these signals.
- **Area2D vs Area2D overlap**: Use `area_entered` / `area_exited`. This is the ONLY signal
  type used in Garrison.

### Architecture

```
Hero (Node2D)
├─ Sprite2D / AnimatedSprite2D
├─ HeroArea (Area2D) — layer: hero, mask: none
│       └─ CollisionShape2D (circle, r=18px)
└─ HeroMagnet (Area2D) — layer: none, mask: coin
        └─ CollisionShape2D (circle, r=170px)
        └─ area_entered → _on_coin_entered

Zone (Area2D) — layer: zone, mask: hero
└─ CollisionShape2D (circle, r=90px)
└─ area_entered → _on_body_entered  [NOTE: use area_entered, not body_entered]

Enemy (Area2D) — layer: enemy, mask: castle
└─ CollisionShape2D (circle, r=16px)
└─ area_entered → _on_castle_contact

Arrow (Area2D) — layer: projectile, mask: enemy
└─ CollisionShape2D (rect, 12×4px)
└─ area_entered → _on_hit

Coin (Area2D) — layer: coin, mask: none
└─ CollisionShape2D (circle, r=8px)

Castle (Area2D) — layer: castle, mask: enemy
└─ CollisionShape2D (rect, castle width × 20px)
└─ area_entered → _on_enemy_contact
```

### Key Interfaces

```gdscript
# Zone dwell pattern — all zones follow this template
extends Area2D

signal dwell_completed(zone: Area2D)

const DWELL_TIME: float = 0.8
var _dwell_timer: float = 0.0
var _hero_inside: bool = false

func _ready() -> void:
    area_entered.connect(_on_area_entered)   # area_entered, NOT body_entered
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group(&"hero"):
        _hero_inside = true

func _on_area_exited(area: Area2D) -> void:
    if area.is_in_group(&"hero"):
        _hero_inside = false
        _dwell_timer = 0.0

# Gold magnet pattern
extends Area2D  # HeroMagnet node

func _ready() -> void:
    area_entered.connect(_on_coin_entered)

func _on_coin_entered(area: Area2D) -> void:
    if area.is_in_group(&"coin"):
        area.attract_to(global_position)

# Arrow hit pattern
extends Area2D  # Arrow node

func _ready() -> void:
    area_entered.connect(_on_hit)

func _on_hit(area: Area2D) -> void:
    if area.is_in_group(&"enemy"):
        area.take_damage(PROJ_DAMAGE)
        queue_free()  # or return to pool — see ADR-003
```

### Implementation Guidelines

1. **Never use `body_entered`** in Garrison. No `PhysicsBody2D` nodes exist. If `body_entered`
   appears in code review, it is a bug.
2. **Hero detection by zones**: The Hero node's Area2D (HeroArea) is layer `hero`. Zones
   listen with `area_entered` on mask `hero`. Add the Hero's Area2D to group `"hero"` for
   easy `is_in_group` checks.
3. **Monitoring / Monitorable**: Both nodes in any overlap pair must have:
   - `monitoring = true` on the detector node (emits signals)
   - `monitorable = true` on the detected node (can be found by others)
   Default is true for both — do not set to false unless disabling a zone intentionally.
4. **Jolt**: Ignore Jolt entirely. Do not configure it. Do not set `PhysicsServer2D` engine
   in Project Settings. The 2D physics engine is GodotPhysics2D (default and correct).
5. **Collision layer assignment**: Set layer names in Project Settings before writing any
   collision code. Use `set_collision_layer_value(layer_number, true)` in code rather than
   raw bitmask literals for readability.

## Alternatives Considered

### Alternative 1: CharacterBody2D for hero and enemies

- **Description**: Use Godot's `CharacterBody2D` for the hero (standard movement) and
  enemies, with Area2Ds as children for zone detection.
- **Pros**: `move_and_slide()` handles wall collision; built-in velocity model.
- **Cons**: Hero movement in Garrison is joystick-driven with manual position lerping.
  `move_and_slide()` adds friction and velocity decay that fight the lerp model. Enemies
  march in a straight line — no collision response needed. Adding `CharacterBody2D` adds
  overhead with zero benefit.
- **Rejection Reason**: Unnecessary complexity. Manual position setting in `_process` is
  simpler and more predictable for this movement model.

### Alternative 2: RigidBody2D for coins (physics drop)

- **Description**: Coins emit from enemies with a physics-simulated arc.
- **Pros**: Satisfying physics drop feel.
- **Cons**: Requires physics solver per coin. At 5–20 coins per kill × up to 20 enemies,
  could create 100+ active RigidBody2D nodes. Performance risk on mobile. The gold magnet
  logic would need to apply forces to RigidBody2D — more complex. Not required by any GDD.
- **Rejection Reason**: Performance risk. GDD specifies magnet `attract_to()` — implies
  kinematic coin movement, not physics.

## Consequences

### Positive

- Zero physics simulation overhead — Area2D overlap is pure broad-phase AABB, one of the
  cheapest operations in Godot's physics engine
- All overlap detection is deterministic and frame-accurate
- No physics integration step — `_physics_process` is optional; `_process` is sufficient
- Simple to debug (overlap signals are easy to trace)

### Negative

- No automatic collision response (bounce, push) — intentional for this game
- Area2D overlap requires both nodes to be in the scene tree and active — pooled arrows
  returned to pool must disable their CollisionShape2D (not just hide the sprite)
- Team must remember to use `area_entered`, not `body_entered`

### Neutral

- Jolt being irrelevant to 2D is a Godot 4.6 architectural fact, not a project choice.
  Document it here to prevent confusion, not to make a decision about it.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Programmer uses `body_entered` instead of `area_entered` | Medium | Low (signal never fires) | Code review checklist: grep `body_entered` in any zone/projectile/magnet script |
| Collision layer misconfiguration (mask = 0 = all layers) | Low | Medium (false positives) | Set layer names in Project Settings; review all Area2D nodes before first test |
| Arrow pool returns arrow to pool without disabling CollisionShape2D | Medium | High (ghost hits) | ADR-003 pool return sequence: disable shape first, then reposition |

## Performance Implications

| Metric | RigidBody2D approach (avoided) | Area2D approach (chosen) | Budget |
|--------|-------------------------------|--------------------------|--------|
| Physics pairs/frame | O(n²) bodies | O(mask-filtered pairs) | — |
| `_physics_process` calls | Required per body | Not required | — |
| CPU overhead | ~0.5ms+ at 50 bodies | ~0.05ms at 50 areas | ≤16.6ms frame |

## Migration Plan

No existing physics to migrate. Initial project setup:

1. Open Project Settings → Physics → 2D → Layer Names and configure layers 1–6
2. Confirm no `RigidBody2D`, `CharacterBody2D`, or `StaticBody2D` nodes in any scene
3. Add `hero` group to Hero's Area2D node; `coin` group to Coin's Area2D node; etc.

**Rollback plan**: If physics bodies become necessary for a future mechanic, add them
as new layer(s) (e.g., layer 7: `wall`). Existing Area2D nodes are unaffected by
adding new layers.

## Validation Criteria

- [ ] Project Settings shows layer names 1–6 matching the table above
- [ ] No `body_entered` signal connections exist in any zone, magnet, or projectile script
- [ ] Zone dwell: hero entering RECRUIT_ZONE fires `area_entered` within the same frame
- [ ] Gold magnet: coin Area2D entering HeroMagnet radius fires `area_entered`
- [ ] Arrow: arrow Area2D overlapping enemy Area2D fires `area_entered` → `take_damage(8)`
- [ ] Performance: adding 20 simultaneous coin Area2Ds produces no measurable frame time delta

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/economy.md` | Economy | Zone dwell detection (0.8s trigger) | Area2D `area_entered` on zone; dwell timer increments in `_process` |
| `design/gdd/economy.md` | Economy | Gold magnet (170px radius) | HeroMagnet Area2D with r=170px; `area_entered` from coin |
| `design/gdd/archer-formation.md` | Archer Formation | Projectile hit detection (`PROJ_DAMAGE = 8`) | Arrow Area2D `area_entered` enemy Area2D → `take_damage(PROJ_DAMAGE)` |
| `design/gdd/castle.md` | Castle | Enemy contact triggers castle HP loss | Enemy Area2D `area_entered` castle Area2D → `take_damage()` |

## Related

- ADR-003 — Object pool pattern (arrows use Area2D for hit detection; pool return must disable CollisionShape2D)
- `docs/engine-reference/godot/modules/area2d.md` — Garrison-specific Area2D reference
- `docs/engine-reference/godot/breaking-changes.md` — confirms Jolt is 3D only in 4.6
