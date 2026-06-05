# Story F03-S01: Castle Node + HP + Signals

> **Epic**: EPIC-F03 Castle System
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Automated unit test (GUT) — BLOCKING
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-castle-001
> **ADR Refs**: ADR-002, ADR-005

## What to Build

`src/gameplay/castle.gd` — Node2D with Area2D contact zone, HP tracking, signals.

```gdscript
extends Node2D

const CASTLE_MAX_HP := 200
const CASTLE_POS := Vector2(270.0, 62.0)
const CASTLE_DMG := 8

signal hp_changed(new_hp: int)
signal castle_fell

var castle_hp: int = CASTLE_MAX_HP

func take_damage(amount: int) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
        return
    castle_hp = max(castle_hp - amount, 0)
    hp_changed.emit(castle_hp)
    if castle_hp <= 0:
        castle_fell.emit()
        GameStateMachine.request_game_over()

func _on_session_reset() -> void:
    castle_hp = CASTLE_MAX_HP
    hp_changed.emit(castle_hp)
```

Castle has an Area2D "contact zone" (~50px radius). When an enemy enters, it calls `take_damage(CASTLE_DMG)` and is destroyed (enemy.kill() — returns to pool).

Draw placeholder in `_draw()`: circle at CASTLE_POS, color reflects HP ratio.

## Acceptance Criteria

- [ ] `castle_hp` starts at 200 on session start
- [ ] `hp_changed(new_hp)` fires on every `take_damage()` call
- [ ] `castle_fell` fires exactly once when `castle_hp <= 0`
- [ ] `castle_fell` does not fire a second time if already in GAME_OVER
- [ ] Two simultaneous hits in same frame: HP decrements by 16 (2 × 8), clamped to 0; exactly one `castle_fell` fires
- [ ] `castle_hp` resets to 200 on `session_reset`
- [ ] Castle drawn at `Vector2(270, 62)` in world space

## Test File

`tests/unit/gameplay/castle_test.gd`

Test cases:
- `test_starts_at_full_hp`
- `test_take_damage_reduces_hp`
- `test_hp_changed_signal_fires`
- `test_castle_fell_fires_at_zero`
- `test_castle_fell_fires_once_only`
- `test_overkill_damage_clamps_to_zero`
- `test_session_reset_restores_full_hp`
