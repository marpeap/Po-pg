# Story F05-S01: Enemy Node + Movement + HP + Death Signal

> **Epic**: EPIC-F05 Enemy Wave System
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Automated unit test — BLOCKING
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-enemy-001
> **ADR Refs**: ADR-002, ADR-006

## What to Build

`src/gameplay/enemy.gd` — Area2D, manual movement via direction_to, HP, death signal.

```gdscript
extends Area2D

signal enemy_died(position: Vector2)

var hp: int = 30
var speed: float = 70.0
var gold_value: int = 15
var _alive: bool = true

const CASTLE_POS := Vector2(270.0, 62.0)

func _process(delta: float) -> void:
    if not _alive: return
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING: return
    var dir: Vector2 = (CASTLE_POS - position).normalized()
    position += dir * speed * delta

func take_damage(amount: int) -> void:
    if not _alive: return
    hp -= amount
    if hp <= 0:
        _alive = false
        enemy_died.emit(position)
        # Return to pool (called by pool manager)

func activate(start_pos: Vector2, enemy_hp: int, enemy_speed: float, gold: int) -> void:
    position = start_pos
    hp = enemy_hp
    speed = enemy_speed
    gold_value = gold
    _alive = true
    $CollisionShape2D.disabled = false
    show()

func deactivate() -> void:
    _alive = false
    $CollisionShape2D.disabled = true
    hide()
```

Draw placeholder in `_draw()`: angular triangle `#C0392B`, HP bar above sprite.

## Acceptance Criteria

- [ ] Enemy moves toward `Vector2(270, 62)` every frame
- [ ] Enemy position advances by `speed * delta` px per frame in the direction of castle
- [ ] `take_damage(amount)` reduces HP and emits `enemy_died(position)` when HP <= 0
- [ ] `enemy_died` fires exactly once per kill
- [ ] Enemy stops processing when `_alive == false`
- [ ] `activate()` and `deactivate()` correctly show/hide and enable/disable collision

## Test File

`tests/unit/gameplay/enemy_test.gd`

Test cases:
- `test_enemy_moves_toward_castle`
- `test_take_damage_reduces_hp`
- `test_enemy_died_fires_at_zero_hp`
- `test_enemy_died_fires_once_only`
- `test_overkill_does_not_crash`
