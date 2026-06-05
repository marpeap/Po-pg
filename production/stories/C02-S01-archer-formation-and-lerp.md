# Story C02-S01: Archer Formation + V-Slots + ADR-004 Lerp Follow

> **Epic**: EPIC-C02 Archer Formation
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Unit test for lerp + slot math — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-archer-001
> **ADR Refs**: ADR-004, ADR-005

## What to Build

`src/gameplay/archer_formation.gd` — formation slot calculation, archer lerp follow, slot assignment.

### Formation Slot Offsets (V-shape, 8 positions)

These offsets are in the hero's local facing space. They are rotated by `facing_angle + PI/2` each frame.

```gdscript
const FORMATION: Array[Vector2] = [
    Vector2(0, 50),           # Slot 1 — center rear
    Vector2(-35, 80),         # Slot 2 — left second rank
    Vector2(35, 80),          # Slot 3 — right second rank
    Vector2(-70, 110),        # Slot 4 — left third rank
    Vector2(70, 110),         # Slot 5 — right third rank
    Vector2(-105, 140),       # Slot 6 — left fourth rank
    Vector2(105, 140),        # Slot 7 — right fourth rank
    Vector2(0, 170),          # Slot 8 — rear center
]

const ARCHER_LERP_F := 0.12
const STARTING_ARCHERS := 2
const MAX_FORMATION_SLOTS := 8

signal formation_full

var current_archer_count: int = 0
var _archers: Array[Node2D] = []  # archer node references
var _slots_active: int = STARTING_ARCHERS
```

### Per-Frame Slot Update

```gdscript
func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING: return
    var hero_pos: Vector2 = _hero.position
    var angle: float = _hero.facing_angle + PI / 2.0
    var weight: float = 1.0 - pow(1.0 - ARCHER_LERP_F, delta * 60.0)
    for i in range(_slots_active):
        var slot_offset: Vector2 = FORMATION[i].rotated(angle)
        var target: Vector2 = hero_pos + slot_offset
        _archers[i].position = _archers[i].position.lerp(target, weight)
```

### Recruit Handler

```gdscript
func _on_recruit_purchased() -> void:
    if _slots_active >= MAX_FORMATION_SLOTS: return
    _slots_active += 1
    current_archer_count = _slots_active
    if _slots_active == MAX_FORMATION_SLOTS:
        formation_full.emit()
```

### Session Reset

```gdscript
func _on_session_reset() -> void:
    _slots_active = STARTING_ARCHERS
    current_archer_count = STARTING_ARCHERS
    for archer in _archers:
        archer.position = _hero.position  # Snap to hero on reset
```

## Acceptance Criteria

- [ ] Session starts with 2 archers following the hero
- [ ] Archers lerp to V-formation slots using ADR-004 formula: `1.0 - pow(1.0 - 0.12, delta * 60.0)`
- [ ] Formation rotates correctly as `facing_angle` changes
- [ ] `recruit_purchased` signal adds an archer to the next available slot
- [ ] `formation_full` fires when archer count reaches 8
- [ ] `current_archer_count` is accurate at all times
- [ ] Session reset: archers snap to hero position, count resets to 2

## Test File

`tests/unit/gameplay/archer_formation_test.gd`

Test cases:
- `test_slot_offset_rotated_correctly`
- `test_lerp_weight_frame_rate_independent_at_60fps`
- `test_lerp_weight_frame_rate_independent_at_30fps`
- `test_formation_full_fires_at_8`
- `test_recruit_increments_count`
- `test_session_reset_restores_2_archers`
