# EPIC-F01: Foundation Infrastructure

> **Layer**: Foundation (L0)
> **Status**: Not Started
> **Priority**: BLOCKER — must complete before any other epic
> **GDD Source**: `design/gdd/game-state.md`
> **Governing ADRs**: ADR-005 (GSM), ADR-007 (Scene Architecture), ADR-008 (AudioManager), ADR-009 (No Persistence)
> **Engine Risk**: LOW — autoload and signal patterns are stable in Godot 4.6

---

## Summary

Scaffold the project's autoload infrastructure and main scene skeleton. This epic
produces the two autoload singletons (GameStateMachine, AudioManager), the main
scene file with CanvasLayer HUD node, and the session reset broadcast mechanism.
No gameplay logic — pure plumbing that everything else depends on.

---

## Scope

### In Scope

- `src/autoloads/game_state_machine.gd` — typed enum (PLAYING, GAME_OVER, RESETTING), signals, transitions
- `src/autoloads/audio_manager.gd` — AudioStreamPlayer nodes, `play()`, `play_volley()`, session reset
- `Main.tscn` — production scene skeleton: Node2D root + Camera2D + CanvasLayer (HUD) + GameWorld node
- Project Settings: autoload registrations for GameStateMachine and AudioManager
- `src/` directory structure (subdirectories: autoloads/, core/, gameplay/, ui/)

### Out of Scope

- Audio assets (placeholder silence acceptable — audio architecture only)
- HUD element content (only CanvasLayer node, no Label/ProgressBar children yet)
- Any gameplay logic

---

## Dependencies

None — this is the first epic.

---

## Unblocks

All other epics. No epic can start until GSM autoload exists.

---

## Key Acceptance Criteria

- [ ] `GameStateMachine` autoload is registered and accessible from any script via `GameStateMachine.current_state`
- [ ] `GameStateMachine` starts in `PLAYING` state on launch
- [ ] `game_state_changed(new_state)` signal fires on every valid transition
- [ ] `session_reset` signal fires on RESETTING entry
- [ ] Invalid transitions are silently rejected (no crash, no state corruption)
- [ ] `AudioManager` autoload registers without error; `play(StringName)` calls do not crash even with no audio assets
- [ ] Main.tscn has a CanvasLayer (layer=1) child node for HUD use
- [ ] Project Settings viewport: 540×960, canvas_items stretch, keep aspect

---

## Control Manifest Notes

- GSM must never reference other gameplay systems directly
- Tween only for any future HUD animations (no AnimationPlayer on CanvasLayer)
- No FileAccess anywhere
