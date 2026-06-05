# Sprint 1 — Foundation Infrastructure

> **Duration**: 3 days (velocity: ~3h/day from vertical slice)
> **Goal**: Autoloads wired, main scene skeleton operational, hero moves, castle HP tracking active.
> **Dependency**: All F01 stories must pass before F02/F03 can begin.

## Stories

| Story ID | Title | Estimate | Type | Test Gate |
|----------|-------|----------|------|-----------|
| F01-S01 | Game State Machine autoload | 0.5d | Logic | BLOCKING — unit test |
| F01-S02 | Audio Manager autoload | 0.5d | Logic | BLOCKING — unit test |
| F01-S03 | Main scene skeleton | 0.5d | Integration | BLOCKING — integration test |
| F02-S01 | Hero joystick movement | 1.0d | Logic + Integration | BLOCKING — unit + integration |
| F03-S01 | Castle system | 0.5d | Logic | BLOCKING — unit test |

**Total**: 3.0 days

## Sequencing

```
Day 1:   F01-S01 → F01-S02 → F01-S03 (foundation must exist before anything)
Day 2:   F02-S01 (hero movement; depends on F01-S01 GSM)
Day 3:   F03-S01 (castle; depends on F01-S01 GSM signals)
```

## Definition of Done

- [ ] GSM autoload registered, typed enum `State`, `game_state_changed` signal works
- [ ] AudioManager autoload registered, `play_sfx` and `play_volley` callable
- [ ] Main.tscn opens without errors in Godot 4.6
- [ ] Hero moves at 200px/s, joystick at (135,800), facing_angle updates
- [ ] Castle HP starts at 200, emits `hp_changed` on damage, emits `castle_fell` at 0
- [ ] All unit tests pass in GUT

## Files Produced

- `src/autoloads/game_state_machine.gd`
- `src/autoloads/audio_manager.gd`
- `src/Main.tscn`
- `src/gameplay/hero.gd`
- `src/gameplay/castle.gd`
- `tests/unit/foundation/game_state_machine_test.gd`
- `tests/unit/foundation/audio_manager_test.gd`
- `tests/unit/foundation/castle_test.gd`
- `tests/unit/gameplay/hero_movement_test.gd`
- `tests/integration/foundation/main_scene_integration_test.gd`
