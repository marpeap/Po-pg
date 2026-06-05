# ADR-008: Audio Architecture — Non-Positional, MVP

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

All audio in Garrison MVP uses `AudioStreamPlayer` (non-positional) rather than
`AudioStreamPlayer2D`. No spatial audio, no reverb bus, no distance attenuation.
Volley fire volume scales with `current_archer_count` via a lerp formula. Audio
nodes live in a dedicated `AudioManager` autoload to keep game scripts clean.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — `AudioStreamPlayer`, `AudioBusLayout`, `AudioServer` are stable since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `AudioStreamPlayer` plays correctly on Android with Godot 4.6 export; verify audio is not muted by default on first launch (Android audio focus) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-005 (GSM session_restart — audio manager mutes on game_over if desired) |
| **Enables** | SFX implementation in ArcherFormation, Economy, Castle, EnemyWave |
| **Blocks** | Any audio call in gameplay scripts |
| **Ordering Note** | Register AudioManager autoload before any gameplay script calls it |

## Context

### Problem Statement

`archer-formation.md` defines 5 audio events with specific volume rules (e.g., volley fire
scales from -6 dB to 0 dB based on `current_archer_count`). Without an architecture decision,
programmers may use `AudioStreamPlayer2D` (positional, requires 2D node position) or embed
`AudioStreamPlayer` nodes in individual gameplay scripts, scattering audio management.

### Constraints

- Android mobile: no headphone spatial audio guarantee; non-positional is safer
- MVP audio budget: minimal — SFX only, no background music
- GDD specifies volume scaling formula for volley: `volume_db = lerp(-6.0, 0.0, (n-2)/6.0)`
- Performance: AudioStreamPlayer is lightweight; no polyphony overhead concern at this scale

### Requirements

- All SFX are non-positional (same volume regardless of hero or enemy position)
- Volley fire volume scales with `current_archer_count` (n=2 → -6dB, n=8 → 0dB)
- SFX names referenced by `StringName` constants, not raw strings
- Session restart: stop any looping audio
- Audio nodes not cluttering gameplay node scripts

## Decision

**Pattern**: `AudioManager` autoload with a fixed set of `AudioStreamPlayer` nodes.
Gameplay scripts call `AudioManager.play(SFX_NAME)` or `AudioManager.play_volley(n)`.

**No `AudioStreamPlayer2D`**: All sounds are non-positional. Mobile players
typically have one earbud or speaker — spatial distance cues add nothing.

**No reverb or effects bus**: MVP has no reverb. Master bus only.

**Polyphony**: Use `AudioStreamPlayer.set_pitch_scale()` and multiple players
for simultaneous SFX. At maximum load (8 impacts/frame + volley), that's 9 simultaneous
players — well within Godot's polyphony limit.

### Architecture

```
AudioManager (Autoload)
├─ _players: Dictionary[StringName, AudioStreamPlayer]
│   ├─ &"volley_fire"      → AudioStreamPlayer (sfx_volley_fire.ogg)
│   ├─ &"archer_recruit"   → AudioStreamPlayer (sfx_archer_recruit.ogg)
│   ├─ &"arrow_impact"     → AudioStreamPlayer × 8 (pool — simultaneous impacts)
│   ├─ &"formation_full"   → AudioStreamPlayer
│   └─ &"castle_hit"       → AudioStreamPlayer
│
└─ play(sfx: StringName) → void
   play_volley(archer_count: int) → void  [volume scaled]
   play_impact(pitch_variation: bool) → void  [±5 cents at n≥6]
   stop_all() → void
```

### Key Interfaces

```gdscript
# autoload/audio_manager.gd
extends Node

const SFX_VOLLEY_FIRE    := &"volley_fire"
const SFX_ARCHER_RECRUIT := &"archer_recruit"
const SFX_ARROW_IMPACT   := &"arrow_impact"
const SFX_FORMATION_FULL := &"formation_full"
const SFX_CASTLE_HIT     := &"castle_hit"

# Volley fire — volume scales with archer count (from archer-formation.md)
func play_volley(archer_count: int) -> void:
    var player: AudioStreamPlayer = _players[SFX_VOLLEY_FIRE]
    player.volume_db = lerp(-6.0, 0.0, float(archer_count - 2) / 6.0)
    player.play()

# Impact — pitch variation at high archer counts (from archer-formation.md)
func play_impact(vary_pitch: bool = false) -> void:
    var player: AudioStreamPlayer = _get_free_impact_player()
    if player == null:
        return
    if vary_pitch:
        player.pitch_scale = 1.0 + randf_range(-0.003, 0.003)  # ±5 cents approx
    else:
        player.pitch_scale = 1.0
    player.play()

# General one-shot SFX
func play(sfx: StringName) -> void:
    if _players.has(sfx):
        _players[sfx].play()

func stop_all() -> void:
    for player in _players.values():
        if player is AudioStreamPlayer:
            player.stop()
        elif player is Array:
            for p in player:
                p.stop()
```

```gdscript
# Usage in archer_formation.gd — no AudioStreamPlayer nodes in this script
func _fire_volley() -> void:
    # ... spawn arrows ...
    AudioManager.play_volley(_current_archer_count)

func _on_recruit_purchased() -> void:
    # ... fill slot ...
    AudioManager.play(AudioManager.SFX_ARCHER_RECRUIT)
```

### Implementation Guidelines

1. **Register `AudioManager` in Project Settings → Autoloads** after `GameStateMachine`
   and `ObjectPoolManager`.
2. **All stream resources assigned in `_ready()`** via `preload()`. No runtime loading.
3. **Impact player pool**: Maintain an array of 8 `AudioStreamPlayer` nodes for arrow
   impacts (simultaneous at full formation). `_get_free_impact_player()` returns the first
   player where `playing == false`, or null if all active (starvation = skip, no error needed
   for audio).
4. **No `AudioStreamPlayer2D`** anywhere in the project. If one appears in code review, replace it.
5. **StringName constants** (`&"name"`) for all SFX identifiers. Never pass raw strings.
6. **Android audio focus**: On Android, the first `AudioStreamPlayer.play()` after app resume
   may be silent if audio focus was lost. No special handling required in MVP — this is
   acceptable behavior.
7. **Placeholder audio**: Ship with silent `AudioStreamPlayer` nodes (empty or 1ms silent wav)
   until final SFX assets are produced. Scripts remain unchanged when assets arrive.

## Consequences

### Positive

- Audio management in one place — gameplay scripts have no audio nodes
- Non-positional audio works correctly on any speaker/headphone configuration
- Simple to replace placeholder audio with final assets

### Negative

- No spatial audio — enemies approaching from different directions sound the same
- 8 impact players is a hard limit; if formation fires simultaneously and all 8 are active, one impact is dropped (acceptable)

### Neutral

- No music in MVP — AudioManager has no music player (add in future ADR when music is added)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Android audio focus lost after minimize | Medium | Low (silent SFX for one frame) | Acceptable for MVP; fix in Polish phase |
| All 8 impact players busy simultaneously | Low | Low (one impact dropped) | Pool of 8 matches max arrow count — only if all arrows hit simultaneously |

## Validation Criteria

- [ ] Volley fire at n=2: AudioStreamPlayer volume_db ≈ -6.0
- [ ] Volley fire at n=8: AudioStreamPlayer volume_db ≈ 0.0
- [ ] 8 simultaneous arrow impacts play (or near-simultaneously) without crash
- [ ] Session restart: all SFX stop (no looping sounds survive reset)
- [ ] No `AudioStreamPlayer2D` nodes in any script or scene

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/archer-formation.md` | Archer Formation | `sfx_volley_fire` volume scales: `lerp(-6.0, 0.0, (n-2)/6.0)` | `AudioManager.play_volley(n)` applies formula |
| `design/gdd/archer-formation.md` | Archer Formation | `sfx_arrow_impact` ±5 cents pitch at n≥6 | `play_impact(vary_pitch: bool)` applies pitch_scale variation |
| `design/gdd/archer-formation.md` | Archer Formation | All `AudioStreamPlayer` (non-positional) | Architecture mandates non-positional only |

## Related

- ADR-005 — GSM `session_restart` → `AudioManager.stop_all()`
