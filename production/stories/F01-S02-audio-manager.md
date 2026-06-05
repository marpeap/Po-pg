# Story F01-S02: AudioManager Autoload

> **Epic**: EPIC-F01 Foundation Infrastructure
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Automated unit test (GUT) — BLOCKING
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-audio-001
> **ADR Refs**: ADR-008

## What to Build

`src/autoloads/audio_manager.gd` — Godot autoload singleton.

```gdscript
# audio_manager.gd
extends Node

const SFX_VOLLEY := &"volley"
const SFX_COIN_COLLECT := &"coin_collect"
const SFX_RECRUIT := &"recruit"
const SFX_CASTLE_HIT := &"castle_hit"
const SFX_GAME_OVER := &"game_over"
const SFX_DWELL_COMPLETE := &"dwell_complete"

# AudioStreamPlayer nodes as @onready children
@onready var _players: Dictionary = {}  # StringName → AudioStreamPlayer

func play(sfx_name: StringName) -> void:
    if sfx_name in _players:
        _players[sfx_name].play()

func play_volley(archer_count: int) -> void:
    var n := clampf(float(archer_count), 2.0, 8.0)
    var volume_db := lerpf(-6.0, 0.0, (n - 2.0) / 6.0)
    if SFX_VOLLEY in _players:
        _players[SFX_VOLLEY].volume_db = volume_db
        _players[SFX_VOLLEY].play()

func _on_session_reset() -> void:
    for player in _players.values():
        player.stop()
```

- Audio assets: silence/placeholder acceptable — architecture registers players regardless
- Register in Project Settings → Autoloads as `AudioManager`
- Connect to `GameStateMachine.session_reset` in `_ready()`

## Engine Notes

- `AudioStreamPlayer` (non-positional) only — ADR-008
- `StringName` constants (& prefix) for SFX names — no raw strings
- Volley formula: `volume_db = lerp(-6.0, 0.0, (n-2)/6.0)` — n=2 → -6dB, n=8 → 0dB

## Acceptance Criteria

- [ ] `AudioManager` accessible from any script
- [ ] `AudioManager.play(&"sfx_name")` does not crash when called (even with no audio assets loaded)
- [ ] `AudioManager.play_volley(2)` sets volume ≈ -6dB; `play_volley(8)` sets volume ≈ 0dB
- [ ] `play_volley(5)` (midpoint, 3/6 of range) sets volume ≈ -3dB
- [ ] All players stop on `session_reset` signal

## Test File

`tests/unit/foundation/audio_manager_test.gd`

Test cases:
- `test_play_volley_2_archers_volume_minus_6db`
- `test_play_volley_8_archers_volume_0db`
- `test_play_volley_clamps_below_2`
- `test_play_does_not_crash_without_audio_asset`
