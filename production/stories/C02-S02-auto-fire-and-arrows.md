# Story C02-S02: Auto-Fire Volley + Arrow Pool + Hit Detection

> **Epic**: EPIC-C02 Archer Formation
> **Status**: Not Started
> **Type**: Logic + Integration
> **Test Evidence Required**: Unit test for damage formula — BLOCKING; Integration test for arrow hit — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-archer-002
> **ADR Refs**: ADR-002, ADR-003, ADR-008

## What to Build

Auto-fire timer, arrow pool (24 nodes), projectile movement, hit detection, and audio trigger.

### Arrow Node (`src/gameplay/arrow.gd`)

```gdscript
extends Area2D

const PROJ_SPEED := 400.0
const PROJ_DAMAGE := 8
const SHOOT_RANGE := 300.0

var _direction: Vector2
var _start_pos: Vector2
var _active: bool = false

func activate(start: Vector2, dir: Vector2) -> void:
    position = start
    _start_pos = start
    _direction = dir.normalized()
    _active = true
    $CollisionShape2D.disabled = false
    show()

func deactivate() -> void:
    _active = false
    $CollisionShape2D.disabled = true
    hide()

func _process(delta: float) -> void:
    if not _active: return
    position += _direction * PROJ_SPEED * delta
    if position.distance_to(_start_pos) > SHOOT_RANGE:
        deactivate()
        _pool.return(self)  # Reference to pool injected at checkout

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("enemies"):
        area.take_damage(PROJ_DAMAGE)
        deactivate()
        _pool.return(self)
```

### Auto-Fire in `archer_formation.gd`

```gdscript
const SHOOT_IVTL := 1.2
var _shoot_timer: float = 0.0

func _process(delta: float) -> void:
    # ... formation lerp above ...
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING: return
    _shoot_timer += delta
    if _shoot_timer >= SHOOT_IVTL:
        _shoot_timer = 0.0
        _fire_volley()

func _fire_volley() -> void:
    var target = _find_nearest_enemy()
    if target == null: return
    for i in range(_slots_active):
        var arrow = _arrow_pool.checkout()
        if arrow == null: continue
        var dir = (target.position - _archers[i].position).normalized()
        arrow.activate(_archers[i].position, dir)
    AudioManager.play_volley(_slots_active)
```

### Arrow Pool: 24 pre-allocated arrow Area2D nodes.

## Acceptance Criteria

- [ ] All active archers fire simultaneously every 1.2s toward nearest enemy within SHOOT_RANGE
- [ ] Arrows are drawn from pool — no `instantiate()` during gameplay
- [ ] Arrow deals 8 HP damage on enemy hit; disappears on hit (returns to pool)
- [ ] Arrow disappears when it travels beyond 300px from its start position (returns to pool)
- [ ] Arrow pool of 24 nodes never starves under normal play conditions (8 archers × 1.2s = 6.7 arrows/s max; at 300px range and 400px/s speed, each arrow lasts ~0.75s = ~5 in-flight simultaneously)
- [ ] `AudioManager.play_volley(n)` called on each volley
- [ ] No arrows fired when no enemies are present or within range
- [ ] Shoot timer and all arrows reset on session reset

## Test File

`tests/unit/gameplay/arrow_test.gd`

Test cases:
- `test_arrow_moves_at_correct_speed`
- `test_arrow_deactivates_at_max_range`
- `test_arrow_deals_correct_damage`
- `test_arrow_pool_checkout_returns_null_when_empty`

`tests/integration/archer_volley_integration_test.gd`

Test cases:
- `test_volley_fires_after_shoot_ivtl`
- `test_all_archers_fire_per_volley`
- `test_enemy_killed_by_arrow`
