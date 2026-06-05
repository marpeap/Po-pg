# ADR-003: Object Pool Pattern — Arrows, Impacts, Coins

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Arrow nodes, impact particle bursts, and gold coins are spawned and freed at high
frequency during gameplay. To avoid per-frame `instantiate()` / `queue_free()` overhead
on mobile, Garrison uses a **fixed-size pre-allocated object pool** for each of these
three node types. Nodes are hidden and disabled on return, reactivated on checkout.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — GDScript node instantiation, `hide()`, `show()`, `set_process()` are stable since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/modules/area2d.md` (pool return sequence), `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Profile arrow pool checkout/return latency on target Android device; confirm 24-arrow pool never starves at SHOOT_IVTL=0.9s |

> **Note**: Knowledge Risk LOW.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-002 (Area2D collision policy — pool return must disable CollisionShape2D) |
| **Enables** | None directly |
| **Blocks** | Arrow spawn implementation (archer-formation), impact VFX (archer-formation), coin spawn (economy/enemy-wave) |
| **Ordering Note** | Pool classes should be implemented before any system that spawns projectiles or particles |

## Context

### Problem Statement

At 8 archers firing every 0.9 seconds, Garrison spawns up to 8 arrow nodes and 8 impact
particle nodes per volley cycle. On mobile (Godot's GDScript + Android), `Node.instantiate()`
triggers a heap allocation + scene tree insert + signal connect for every arrow. Over a
13-wave session (each wave ~25 seconds), this is ~1,150 arrow instantiations and ~1,150 frees.
On lower-end Android hardware, GC pressure from repeated small allocations can cause
intermittent frame spikes.

Coin drops: each enemy death spawns 1–3 coins. At 20 enemies/wave × up to 15 coins per
kill cluster, that's up to 300 coin instantiations per wave.

The `archer-formation.md` GDD already specifies: "Object pool of 24 arrow nodes" and
"pool of 8 impact GPUParticles2D nodes". This ADR documents the implementation contract.

### Current State

No object pool exists. No spawn infrastructure exists.

### Constraints

- GDScript only — no C++ extensions
- Godot 4.6 Compatibility renderer (mobile Android)
- Pool must survive `session_restart` (nodes returned to pool, counts reset)
- Arrow pool nodes must disable their `CollisionShape2D` when returned to prevent ghost hits (per ADR-002)
- Impact pool nodes use `GPUParticles2D.restart()` for reuse, not `queue_free()`

### Requirements

- Arrow pool: 24 nodes (see size formula below), pre-allocated at scene load
- Impact pool: 8 nodes (one per max simultaneous arrow; volleys are synchronous)
- Coin pool: 16 nodes (covers worst-case drop cluster; coins are short-lived)
- Pool checkout is O(1) — no linear scan
- Pool return is O(1)
- Pool starvation (checkout when empty) produces a logged warning and returns null; the
  caller skips the spawn (no crash, no instantiation fallback)
- All pools are owned by a single `ObjectPoolManager` autoload

## Decision

**Pattern**: Fixed-size pre-allocated pool using a typed array + integer pointer.

**Pool size rationale**:
```
arrow_pool_size = ceil(PROJ_MAX_FLIGHT_TIME / SHOOT_IVTL) × MAX_ARCHERS
                = ceil(0.5 / 0.9) × 8
                = ceil(0.556) × 8
                = 1 × 8 = 8 minimum

With tuning headroom (SHOOT_IVTL floor = 0.40s):
arrow_pool_size = ceil(0.5 / 0.40) × 8 = ceil(1.25) × 8 = 2 × 8 = 16
Safety buffer × 1.5 → 24 (matches GDD spec)
```

```
impact_pool_size = MAX_ARCHERS = 8 (one impact per arrow, volleys are synchronous)
coin_pool_size   = 16 (covers drops from 2–3 simultaneous enemy deaths)
```

**Pool node state lifecycle**:

```
AVAILABLE (in pool)          ACTIVE (in scene, visible)
     │                               │
checkout() ──────────────────────────►
     │    position/reset/show/enable │
     │                               │
     ◄────────────────────────────── return()
              hide/disable           │
```

**Node state on RETURN** (order matters):
1. `collision_shape.set_deferred("disabled", true)` — disable physics FIRST (deferred to avoid mid-physics-step errors)
2. `hide()` — remove from rendering
3. `set_process(false)`, `set_physics_process(false)` — no per-frame cost
4. Reposition to pool storage position (e.g., `position = Vector2(-9999, -9999)`)
5. Append to `_available` array

**Node state on CHECKOUT**:
1. Pop from `_available` array
2. Set `position` to spawn point
3. Set velocity, rotation, or any other per-use data
4. `collision_shape.disabled = false` — enable physics
5. `show()` — add to rendering
6. `set_process(true)` (if needed)

### Architecture

```
ObjectPoolManager (Autoload)
├─ ArrowPool
│   ├─ _nodes: Array[Node2D]  (24 Arrow nodes, pre-instantiated)
│   ├─ _available: Array[int] (indices of available nodes)
│   ├─ checkout() → Node2D | null
│   └─ return(node: Node2D) → void
├─ ImpactPool
│   ├─ _nodes: Array[GPUParticles2D]  (8 impact nodes)
│   ├─ _available: Array[int]
│   ├─ checkout() → GPUParticles2D | null
│   └─ return(node: GPUParticles2D) → void
└─ CoinPool
    ├─ _nodes: Array[Node2D]  (16 coin nodes)
    ├─ _available: Array[int]
    ├─ checkout() → Node2D | null
    └─ return(node: Node2D) → void
```

### Key Interfaces

```gdscript
# autoload/object_pool_manager.gd
extends Node

const ARROW_POOL_SIZE  := 24
const IMPACT_POOL_SIZE := 8
const COIN_POOL_SIZE   := 16

var arrow_pool:  _NodePool
var impact_pool: _NodePool
var coin_pool:   _NodePool

func _ready() -> void:
    var arrow_scene  := preload("res://src/gameplay/projectile/arrow.tscn")
    var impact_scene := preload("res://src/gameplay/vfx/impact_burst.tscn")
    var coin_scene   := preload("res://src/gameplay/economy/coin.tscn")
    arrow_pool  = _NodePool.new(arrow_scene,  ARROW_POOL_SIZE,  self)
    impact_pool = _NodePool.new(impact_scene, IMPACT_POOL_SIZE, self)
    coin_pool   = _NodePool.new(coin_scene,   COIN_POOL_SIZE,   self)

# --- Inner pool class ---
class _NodePool:
    var _nodes: Array[Node]
    var _available: Array[int]

    func _init(scene: PackedScene, size: int, parent: Node) -> void:
        _nodes.resize(size)
        for i in size:
            var node := scene.instantiate()
            node.hide()
            node.set_process(false)
            node.set_physics_process(false)
            # Disable collision shape if it exists
            for child in node.get_children():
                if child is CollisionShape2D:
                    child.disabled = true
            node.position = Vector2(-9999.0, -9999.0)
            parent.add_child(node)
            _nodes[i] = node
            _available.append(i)

    func checkout() -> Node:
        if _available.is_empty():
            push_warning("ObjectPool: pool starved — returning null")
            return null
        var idx := _available.pop_back()
        return _nodes[idx]

    func return_node(node: Node) -> void:
        var idx := _nodes.find(node)
        if idx == -1:
            push_warning("ObjectPool: node not owned by this pool")
            return
        node.hide()
        node.set_process(false)
        node.set_physics_process(false)
        for child in node.get_children():
            if child is CollisionShape2D:
                child.set_deferred(&"disabled", true)
        node.position = Vector2(-9999.0, -9999.0)
        _available.append(idx)
```

```gdscript
# Usage in archer_formation.gd — spawn arrow
func _fire_volley() -> void:
    for i in _current_archer_count:
        var arrow: Node2D = ObjectPoolManager.arrow_pool.checkout()
        if arrow == null:
            return  # Pool starved — skip this archer's projectile
        arrow.position = _archer_positions[i]
        arrow.rotation = (_shared_target.global_position - arrow.position).angle()
        # enable collision shape
        for child in arrow.get_children():
            if child is CollisionShape2D:
                child.disabled = false
        arrow.show()
        arrow.set_process(true)
```

```gdscript
# Usage in arrow.gd — return to pool on hit or bounds exit
func _on_hit(area: Area2D) -> void:
    if area.is_in_group(&"enemy"):
        area.take_damage(PROJ_DAMAGE)
        ObjectPoolManager.arrow_pool.return_node(self)

func _on_bounds_exit() -> void:
    ObjectPoolManager.arrow_pool.return_node(self)
```

### Implementation Guidelines

1. **Pre-allocate at scene load**, not lazily. Call `_ready()` of ObjectPoolManager during
   the loading screen / session start, before any gameplay frame.
2. **Starvation is a warning, not a crash**. If `checkout()` returns null, the caller skips
   that spawn. This is correct: at tuned values, starvation should not occur. If it occurs
   in testing, increase pool size or investigate SHOOT_IVTL tuning.
3. **GPUParticles2D reuse**: Impact pool nodes use `GPUParticles2D`. On checkout: call
   `restart()` to re-emit the burst without `queue_free()`. On return: the node has
   `one_shot = true` and auto-hides after emission — the pool return is triggered by a
   timer in the impact node equal to `lifetime + 0.1s`.
4. **Session restart**: On `game_over` / `session_restart`, force-return all checked-out
   nodes to their pools. The pool manager listens for the Game State Machine's
   `session_restart` signal and calls a `_drain()` method that returns all non-available
   nodes.
5. **Index-based O(1)**: The `_available` array stores indices, not node references.
   `pop_back()` is O(1). `find()` in `return_node` is O(n) — acceptable for pools of
   ≤24 nodes. If pools grow larger, switch to a reverse-lookup Dictionary.
6. **Thread safety**: All pool operations occur on the main thread. No locking needed.

## Alternatives Considered

### Alternative 1: `queue_free()` and `instantiate()` per spawn (no pool)

- **Description**: Standard Godot approach for infrequently spawned nodes.
- **Pros**: Simple — no infrastructure code.
- **Cons**: On mobile, heap allocation for each instantiation can cause GC pauses.
  At 8 arrows × 1 volley/0.9s, this is ~8.9 instantiations/second × 25s wave = ~220
  allocations per wave. On low-end Android, each `instantiate()` can take 0.1–0.5ms,
  adding up to 110ms of allocation cost per wave — enough for frame spikes.
- **Rejection Reason**: GDD explicitly specifies "Object pool of 24 arrow nodes."
  Performance requirement.

### Alternative 2: Lazy pool (allocate up to max, never free)

- **Description**: Pre-allocate 0 nodes; grow pool on first checkout up to max; never shrink.
- **Pros**: Avoids allocating nodes that are never needed (e.g., if archer count stays at 2).
- **Cons**: First-use allocation still causes a spike. Pool size is not guaranteed at session
  start. More complex lifecycle.
- **Rejection Reason**: Pre-allocation at load is simpler and guarantees no runtime spikes.
  Session load time is a better tradeoff than runtime frame spikes.

### Alternative 3: `MultiMeshInstance2D` for arrows

- **Description**: Use a MultiMesh to render all arrow instances in one draw call.
- **Pros**: Single draw call regardless of arrow count. Maximum GPU efficiency.
- **Cons**: MultiMesh requires manual transform management. Area2D hit detection cannot
  be attached to MultiMesh instances — would require a separate physics-only node array.
  Significant complexity increase. Arrow count is at most 8 — the 2 draw calls from the
  current sprite batching approach (arrows + tails) are within budget.
- **Rejection Reason**: Overcomplicated for 8 arrows max. Budget-compliant without it.

## Consequences

### Positive

- Zero runtime heap allocation during gameplay (post-load)
- Deterministic frame timing — no GC pauses during combat
- Pool starvation is observable (logged warning) and non-crashing
- Session restart cleanly resets pool state

### Negative

- Slightly longer loading time (pre-allocation at scene load)
- Pool starvation must be monitored during tuning — if SHOOT_IVTL is reduced, pool size
  formula must be re-evaluated
- `return_node()` with `find()` is O(n) — acceptable for small pools, requires refactor
  at larger scales

### Neutral

- ObjectPoolManager autoload adds one node to the scene tree always — negligible

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Pool starves if SHOOT_IVTL tuned below 0.4s floor | Low | Medium (projectiles silently dropped) | Alert log + re-evaluate pool size formula if SHOOT_IVTL floor changes |
| Arrow returned to pool without disabling CollisionShape2D | Medium | High (ghost hits after return) | return_node() always calls `set_deferred("disabled", true)` on CollisionShape2D |
| Session restart race (arrow in-flight when reset fires) | Low | Medium (arrow ghost after reset) | `_drain()` in ObjectPoolManager forces return of all checked-out nodes on `session_restart` signal |

## Performance Implications

| Metric | instantiate/free approach | Object pool approach (chosen) | Budget |
|--------|--------------------------|-------------------------------|--------|
| Heap allocations/wave | ~220 (arrows + impacts) | 0 (post-load) | — |
| Frame spike from alloc | ~0.1–0.5ms per alloc | 0 | 16.6ms |
| Load time overhead | 0 | ~5–15ms (one-time) | — |

## Migration Plan

No existing spawn code to migrate. Implementation sequence:

1. Create `autoload/object_pool_manager.gd` and add to Project Settings → Autoloads
2. Create placeholder `arrow.tscn`, `impact_burst.tscn`, `coin.tscn` scenes (collision shapes disabled by default)
3. Pool pre-allocates at scene root `_ready()`
4. Update `archer_formation.gd` to call `ObjectPoolManager.arrow_pool.checkout()` instead of `instantiate()`
5. Connect Game State Machine `session_restart` signal to `ObjectPoolManager._drain()`

**Rollback plan**: Remove ObjectPoolManager autoload; replace `checkout()` / `return_node()`
calls with `instantiate()` / `queue_free()`. No other architectural change required.

## Validation Criteria

- [ ] Pool pre-allocates exactly 24 arrows, 8 impacts, 16 coins at scene load — verify node count in Godot Remote Inspector
- [ ] No new nodes appear in the scene tree during a volley (pool is reusing nodes)
- [ ] Pool starvation warning appears in Godot output log when pool is manually exhausted (test: checkout all 24 arrows without returning)
- [ ] No ghost hits: returned arrows do not trigger `area_entered` after being returned to pool
- [ ] Session restart: all in-flight arrows disappear immediately; pool available count returns to 24

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/archer-formation.md` | Archer Formation | "Object pool of 24 arrow nodes (reset position/rotation on reuse — no free/instantiate per volley)" | Implements exactly 24-node pre-allocated arrow pool with position/rotation reset on checkout |
| `design/gdd/archer-formation.md` | Archer Formation | "pool of 8 pooled GPUParticles2D nodes" | Implements 8-node impact pool with GPUParticles2D.restart() on checkout |
| `design/gdd/economy.md` | Economy | Gold coin spawning on enemy death | Implements 16-node coin pool; coin spawn calls CoinPool.checkout() |
| `design/gdd/archer-formation.md` | Archer Formation | Open Question OQ-5: "Document pool size calculation as pool_size = ceil(PROJ_MAX_FLIGHT_TIME / SHOOT_IVTL) × MAX_ARCHERS in the governing ADR" | Formula documented in Decision section; pool_size = 24 derived from formula |

## Related

- ADR-002 — Physics Policy (Area2D; pool return must disable CollisionShape2D)
- `docs/engine-reference/godot/modules/area2d.md` — collision disable sequence
