# Story FT01-S01: Archer Tower System

> **Epic**: EPIC-FT01 Archer Tower
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Integration test — BLOCKING
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-tower-001
> **ADR Refs**: ADR-002, ADR-003, ADR-005

## What to Build

`src/gameplay/archer_tower.gd` — static structure, auto-fire, shared arrow pool.

```gdscript
extends Node2D

const TOWER_RANGE := 350.0
const TOWER_SHOOT_IVTL := 1.2
const TOWER_PROJ_DAMAGE := 8

var _shoot_timer: float = 0.0
var _arrow_pool: Node  # Reference to shared arrow pool (from ArcherFormation)

func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING: return
    _shoot_timer += delta
    if _shoot_timer >= TOWER_SHOOT_IVTL:
        _shoot_timer = 0.0
        _fire_at_nearest_enemy()

func _fire_at_nearest_enemy() -> void:
    var target = _find_nearest_enemy_in_range(TOWER_RANGE)
    if target == null: return
    var arrow = _arrow_pool.checkout()
    if arrow == null: return
    var dir = (target.position - position).normalized()
    arrow.activate(position, dir)
```

### Tower Purchase Flow

`economy.gd` → emits `tower_purchased` → `EnemyWave`/`Main` instantiates a tower at TOWER_ZONE_POS.

**Note**: Towers are permanent — they do NOT reset on session reset.

### Map Layout

2 TOWER_ZONEs on the map:
- Left flank: `Vector2(135, 490)` — wait, that's RECRUIT_ZONE. Tower zones should be different.
  Left tower zone: `Vector2(135, 700)` (below recruit zone)
  Right tower zone: `Vector2(405, 700)` (right side of map)

(These positions can be adjusted in Sprint 2 based on playtesting.)

## Acceptance Criteria

- [ ] Building a tower (TOWER_ZONE dwell + 100g) spawns a tower node at the zone position
- [ ] Tower fires every 1.2s at the nearest enemy within 350px
- [ ] Tower arrows are drawn from the shared arrow pool (no new pool)
- [ ] Tower arrow deals 8 HP damage on enemy hit
- [ ] Max 2 towers on the map simultaneously
- [ ] Tower zone shows as "purchased" (inactive) after tower is built — no double purchase
- [ ] Towers persist after session reset (permanent structures)

## Test File

`tests/integration/archer_tower_integration_test.gd`

Test cases:
- `test_tower_fires_within_range`
- `test_tower_does_not_fire_outside_range`
- `test_tower_persists_after_session_reset`
- `test_max_2_towers`
