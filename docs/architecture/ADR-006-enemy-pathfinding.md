# ADR-006: Enemy Pathfinding — direction_to Steering, No NavMesh (MVP)

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Enemies march in a straight line toward the castle using `direction_to(castle_pos) × ENEMY_SPEED`
— no NavMesh, no avoidance, no NavigationAgent2D in MVP. This matches the GDD steering
specification, keeps physics overhead near zero on mobile, and defers pathfinding complexity
to post-MVP. An enemy node pool of 30 pre-allocated nodes is defined here (gap identified
in architecture.md).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Physics |
| **Knowledge Risk** | LOW — `Node2D.position`, `Vector2.direction_to()`, `move_toward()` are stable since 4.0. NavigationServer2D changes in 4.4–4.5 are irrelevant (not used in MVP). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/modules/area2d.md` |
| **Post-Cutoff APIs Used** | None — `Vector2.direction_to()` and manual position update are engine-agnostic math |
| **Verification Required** | Profile 20 simultaneous enemies in `_process` on target Android device; confirm frame time stays under 16.6ms |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-002 (Area2D physics policy — enemy is an Area2D node), ADR-005 (GSM session_restart for enemy pool drain) |
| **Enables** | EnemyWave implementation |
| **Blocks** | EnemyWave script, enemy pool, castle damage testing |
| **Ordering Note** | ADR-005 must be Accepted (session_restart signal needed for enemy pool drain) |

## Context

### Problem Statement

`enemy-wave.md` specifies: "Steering MVP: direction_to straight line toward castle (no NavMesh)."
The architecture.md identified that no ADR covers enemy movement or enemy pooling.
Without this decision, a programmer could implement NavigationAgent2D prematurely,
adding complexity and overhead the GDD explicitly defers.

### Current State

No enemy implementation exists. ADR-003 pools arrows/impacts/coins but not enemies.

### Constraints

- Performance budget: 20 enemies × `_process` per frame at 60fps on mobile
- Area2D-only physics policy (ADR-002) — enemies are Area2D, not CharacterBody2D
- No collision avoidance in MVP — enemies can overlap each other
- Enemy speed: `ENEMY_SPEED = 70 px/s`
- Enemy travel distance: ~1760px (spawn y≈1860 → castle y≈100) = ~25s travel time

### Requirements

- Enemy moves toward `castle_pos` at constant speed every frame
- No pathfinding library, no NavMesh, no avoidance
- Enemy emits `enemy_died(position)` signal on HP reaching 0 (for Economy gold drop)
- Enemy pool: pre-allocated, session-reset drains all active enemies
- Maximum simultaneous enemies: 20 (wave 13 cap)

## Decision

**Movement**: Manual position update in `_process(delta)`:

```gdscript
position += direction_to(castle_pos) × ENEMY_SPEED × delta
```

`direction_to()` is computed once per frame per enemy (O(1) per enemy — just subtraction + normalize).

**Enemy is an `Area2D` node** (not `CharacterBody2D`) per ADR-002. Position is set manually
via `position +=` — no `move_and_slide()`, no physics body velocity.

**Enemy pool**: 30 pre-allocated nodes (covers wave 13 cap of 20 + spawn overlap during transitions).
Pool owner: `ObjectPoolManager.enemy_pool` (extend ADR-003 pool pattern).

**Pool size formula**:
```
enemy_pool_size = MAX_ENEMIES_PER_WAVE + SPAWN_OVERLAP_BUFFER
               = 20 + 10 = 30
```
(Buffer accounts for enemies still alive from previous wave when next wave begins to spawn.)

**Castle position**: Stored as a constant `CASTLE_POS: Vector2` in `EnemyWave` (or read from Castle node in `_ready()`). Not queried per frame — set once at scene load.

**Enemy HP on contact with castle**: Enemy does NOT die on castle contact. It triggers
`castle.take_contact_damage()` then the enemy continues moving. The castle Area2D's
`area_entered` signal handles the damage notification (per ADR-002). The enemy is freed/pooled
when its HP reaches 0 (killed by formation projectiles) or when it exits world bounds.

### Architecture

```
EnemyWave (Node2D — scene root child)
├─ _spawn_timer: float      — counts down to next spawn
├─ _wave_index: int         — current wave (1–13)
├─ _active_enemies: Array   — currently checked-out enemy nodes
└─ ObjectPoolManager.enemy_pool (30 pre-allocated Enemy nodes)

Enemy (Area2D — pooled node)
├─ CollisionShape2D (circle, r=16px)   layer: enemy  mask: castle
├─ Sprite2D / AnimatedSprite2D
├─ _hp: int                 — current HP
├─ _castle_pos: Vector2     — set on checkout; constant
└─ _process(delta):
       position += global_position.direction_to(_castle_pos) × ENEMY_SPEED × delta
```

### Key Interfaces

```gdscript
# src/enemy/enemy.gd
extends Area2D

signal enemy_died(position: Vector2)

const ENEMY_SPEED: float = 70.0

var _hp: int = 0
var _castle_pos: Vector2 = Vector2.ZERO

func setup(hp: int, castle_pos: Vector2) -> void:
    _hp = hp
    _castle_pos = castle_pos

func take_damage(amount: int) -> void:
    _hp -= amount
    if _hp <= 0:
        emit_signal("enemy_died", global_position)
        ObjectPoolManager.enemy_pool.return_node(self)

func _process(delta: float) -> void:
    position += global_position.direction_to(_castle_pos) * ENEMY_SPEED * delta
    # Bounds check — free if enemy somehow exits world
    if position.y < -50.0:
        ObjectPoolManager.enemy_pool.return_node(self)
```

```gdscript
# src/enemy/enemy_wave.gd
extends Node

signal wave_complete(wave_n: int)

const CASTLE_POS: Vector2 = Vector2(540.0, 100.0)  # approximate castle center

var _wave_index: int = 0
var _spawn_timer: float = 0.0
var _enemies_remaining: int = 0

func _on_session_restart() -> void:
    _wave_index = 0
    # Force-return all active enemies (ObjectPoolManager._drain() handles this)

func _on_wave_start(wave_n: int) -> void:
    _wave_index = wave_n
    _enemies_remaining = _enemies_per_wave(wave_n)
    _spawn_timer = 0.0

func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.GameState.PLAYING:
        return
    _spawn_timer -= delta
    if _spawn_timer <= 0.0 and _enemies_remaining > 0:
        _spawn_enemy()
        _enemies_remaining -= 1
        _spawn_timer = SPAWN_INTERVAL

func _spawn_enemy() -> void:
    var enemy = ObjectPoolManager.enemy_pool.checkout()
    if enemy == null:
        return  # Pool starved — skip this spawn (logged by pool)
    var spawn_x: float = randf_range(100.0, 980.0)
    enemy.global_position = Vector2(spawn_x, 1860.0)
    enemy.setup(_enemy_hp(_wave_index), CASTLE_POS)
    enemy.enemy_died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
    enemy.show()
    enemy.set_process(true)

func _on_enemy_died(position: Vector2) -> void:
    emit_signal("enemy_died", position)  # Economy listens for gold drop
    _check_wave_complete()

func _check_wave_complete() -> void:
    # Wave complete when no enemies remain in pool AND no more to spawn
    if _enemies_remaining == 0 and ObjectPoolManager.enemy_pool.active_count() == 0:
        emit_signal("wave_complete", _wave_index)
        GameStateMachine.notify_wave_complete(_wave_index)

# Spawn formulas (from enemy-wave.md):
func _enemies_per_wave(w: int) -> int:
    return 5 + int(floor(float(w) * 1.15))

func _enemy_hp(w: int) -> int:
    return 30 + (w - 1) * 3
```

### Implementation Guidelines

1. **Area2D, not CharacterBody2D.** Enemy moves via `position +=` in `_process`. ADR-002
   forbids CharacterBody2D. Collision with castle is detected by Castle's Area2D `area_entered`
   signal — enemies don't need to "know" about the castle collision.

2. **No per-enemy `direction_to()` caching needed.** At 20 enemies × 1 normalize per frame =
   20 vector normalizations per frame. Negligible on any hardware.

3. **`CONNECT_ONE_SHOT`** on `enemy_died` signal connection in `_spawn_enemy()` prevents the
   handler from firing multiple times if the enemy is recycled (pool return automatically
   disconnects signals via Godot's auto-disconnect on `queue_free()` equivalent).
   Alternative: disconnect explicitly in `return_node()`.

4. **Spawn position**: random X in [100, 980] (90px margins from world edges). Y = 1860
   (just below world bottom, above camera scroll limit). Enemies appear to march in from the bottom.

5. **Enemy exits world bounds without dying**: if enemy reaches Y < -50 (above castle, past top
   of world), it is returned to pool. This handles the edge case where all castle HP is
   consumed before the enemy is killed (castle destroyed = game_over, but enemies in flight
   should be cleaned up).

6. **Pool `active_count()`**: Add this method to `_NodePool` in `ObjectPoolManager` —
   returns `_nodes.size() - _available.size()`.

7. **NavigationAgent2D deferral**: Do NOT add NavigationAgent2D or NavigationServer2D calls
   in MVP. The GDD explicitly defers NavMesh to post-MVP. If added prematurely, remove it.

## Alternatives Considered

### Alternative 1: NavigationAgent2D with NavigationServer2D

- **Description**: Each enemy uses `NavigationAgent2D.get_next_path_position()` toward castle.
- **Pros**: Enemies can navigate around obstacles; avoidance possible.
- **Cons**: NavigationServer2D has changes in 4.4–4.5 (HIGH risk post-cutoff). NavMesh must
  be baked for the map. GDD explicitly says "pas de NavMesh en MVP". Adds 0.5–2ms overhead
  per frame for pathfinding at 20 agents. Overkill for enemies that march in a straight line.
- **Rejection Reason**: GDD explicit decision. Post-cutoff risk. Performance overhead.

### Alternative 2: CharacterBody2D with `move_and_slide()`

- **Description**: Enemies are CharacterBody2D; velocity set per frame; `move_and_slide()` handles
  collision response.
- **Pros**: Built-in collision sliding.
- **Cons**: ADR-002 explicitly forbids CharacterBody2D. Collision response adds physics step
  overhead. Enemies colliding with each other would scatter unpredictably. Unnecessary for
  straight-line movement.
- **Rejection Reason**: ADR-002 prohibits CharacterBody2D.

## Consequences

### Positive

- Zero pathfinding overhead — pure arithmetic per frame
- No NavMesh baking step — faster iteration
- Enemies overlap each other (intentional "horde" aesthetic at wave 13)
- Simple to test and debug — position update is one line

### Negative

- Enemies cannot navigate around obstacles (none exist in MVP map — not a real constraint)
- No flocking or avoidance — multiple enemies on same path converge

### Neutral

- NavigationAgent2D is explicitly deferred — ADR update required when implemented

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Enemy pool of 30 understated if spawn overlap exceeds buffer | Low | Low (pool starvation warning, spawn skipped) | Profile wave 12–13 transition; increase pool if warnings occur |
| `CONNECT_ONE_SHOT` not working as expected in Godot 4.6 | Low | Medium (enemy_died fires twice) | Verify in unit test: spawn, kill, recycle, kill again — confirm signal fires once each time |
| Enemy exits world without triggering castle damage (e.g. Y < 0 without passing castle) | Low | Low (bounds check returns to pool) | Add bounds check in `_process`; castle's Area2D is the authoritative damage trigger |

## Performance Implications

| Metric | 20 enemies, direction_to | Budget |
|--------|--------------------------|--------|
| `_process` calls | 20/frame | ≤150 draw calls total (unrelated) |
| Vector ops | 20 × (subtract + normalize + multiply) | ~0.01ms at 60fps |
| Pool checkout/return | O(1) per spawn/death | Negligible |

## Migration Plan

1. Extend `ObjectPoolManager` with `enemy_pool` (30 nodes, using Enemy scene)
2. Add `active_count()` method to `_NodePool`
3. Create `src/enemy/enemy.gd` per key interface above
4. Create `src/enemy/enemy_wave.gd` per key interface above
5. Connect `GameStateMachine.session_restart` → `EnemyWave._on_session_restart()` in `_ready()`
6. Connect `GameStateMachine.wave_started` → `EnemyWave._on_wave_start(wave_n)` in `_ready()`

## Validation Criteria

- [ ] Enemy spawns at Y=1860, reaches castle area (Y≈100) in approximately 25s (1760/70)
- [ ] 20 simultaneous enemies produce no frame time spike above 16.6ms on reference Android device
- [ ] Enemy pool: no new nodes appear in scene tree during wave (pool reuse confirmed)
- [ ] `enemy_died` signal fires exactly once per enemy death; Economy receives it and spawns coin
- [ ] Session restart: all active enemies return to pool (active_count == 0 after session_restart)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/enemy-wave.md` | Enemy Wave | "Steering MVP: direction_to straight line toward castle (pas de NavMesh)" | Manual `direction_to(castle_pos) × ENEMY_SPEED` in `_process` — no NavMesh |
| `design/gdd/enemy-wave.md` | Enemy Wave | `enemy_died(position)` signal for Economy gold drop | `enemy.gd` emits signal on HP ≤ 0; EnemyWave relays to Economy |
| `design/gdd/archer-formation.md` | Archer Formation | Enemy positions readable each frame for target acquisition | Enemy nodes are Area2D in scene tree; ArcherFormation queries via group iteration |
| `docs/architecture/architecture.md` | Architecture | Enemy pool gap (30 nodes) identified in architecture document | Defines 30-node enemy pool and `active_count()` method |

## Related

- ADR-002 — Physics Policy (Area2D for enemies; no CharacterBody2D)
- ADR-003 — Object Pool (enemy pool extends ADR-003 pattern)
- ADR-005 — Game State Machine (session_restart drains enemy pool)
