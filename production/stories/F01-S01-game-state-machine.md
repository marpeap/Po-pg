# Story F01-S01: GameStateMachine Autoload

> **Epic**: EPIC-F01 Foundation Infrastructure
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Automated unit test (GUT) — BLOCKING
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-gsm-001
> **ADR Refs**: ADR-005

## What to Build

`src/autoloads/game_state_machine.gd` — Godot autoload singleton.

```gdscript
# game_state_machine.gd
extends Node

enum State { PLAYING, GAME_OVER, RESETTING }

signal game_state_changed(new_state: State)
signal session_reset

var current_state: State = State.PLAYING

func transition_to(new_state: State) -> void:
    # Guard: only allow valid transitions
    # PLAYING → GAME_OVER
    # GAME_OVER → RESETTING
    # RESETTING → PLAYING
    ...
    current_state = new_state
    game_state_changed.emit(new_state)
    if new_state == State.RESETTING:
        session_reset.emit()
        transition_to(State.PLAYING)

func request_game_over() -> void:
    if current_state == State.PLAYING:
        transition_to(State.GAME_OVER)

func request_restart() -> void:
    if current_state == State.GAME_OVER:
        transition_to(State.RESETTING)
```

Register in Project Settings → Autoloads as `GameStateMachine`.

## Engine Notes

- Autoload registers before any scene `_ready()` fires in Godot 4.6 — standard behavior
- `signal` declarations use typed parameters (Godot 4 syntax)
- No direct references to other systems

## Acceptance Criteria

- [ ] `GameStateMachine.current_state` is `PLAYING` immediately on launch
- [ ] `transition_to(State.GAME_OVER)` emits `game_state_changed(GAME_OVER)` and sets `current_state`
- [ ] `transition_to(State.RESETTING)` emits `session_reset` then immediately transitions to `PLAYING`
- [ ] Invalid transitions (e.g., `PLAYING → RESETTING`) are silently rejected — state does not change
- [ ] Duplicate transitions (same state → same state) are silently rejected
- [ ] Accessible from any script as `GameStateMachine.current_state`

## Test File

`tests/unit/foundation/game_state_machine_test.gd`

Test cases:
- `test_starts_in_playing_state`
- `test_playing_to_game_over_valid`
- `test_game_over_to_resetting_triggers_session_reset`
- `test_resetting_auto_transitions_to_playing`
- `test_invalid_transition_playing_to_resetting_rejected`
- `test_game_over_signal_fired_on_transition`
