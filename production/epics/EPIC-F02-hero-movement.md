# EPIC-F02: Hero Movement System

> **Layer**: Foundation (L0)
> **Status**: Not Started
> **Priority**: BLOCKER — Camera, Economy, Archer Formation all depend on hero position
> **GDD Source**: `design/gdd/hero-movement.md`
> **Governing ADRs**: ADR-001 (viewport), ADR-002 (Area2D), ADR-004 (lerp formula)
> **Engine Risk**: LOW — touch input, Vector2 movement are stable in Godot 4.6

---

## Summary

Implement the hero entity: fixed-anchor virtual joystick input, hero position update,
facing angle tracking, and auto-fire volley stub. The hero is the only player input
surface — everything in the game flows from where the hero is and where it faces.

---

## Scope

### In Scope

- `src/gameplay/hero.gd` — Node2D, joystick input, position update, facing angle
- Fixed-anchor joystick: anchor `(135, 800)`, activation zone bottom half of screen, 80px clamp radius
- Hero speed: `HERO_SPEED = 200.0 px/s`
- Facing angle: tracks movement direction; resets to `PI/2` (facing down) when stationary
- Touch input via `_input(InputEventScreenTouch / InputEventScreenDrag)`
- Auto-fire stub: emits `volley_fired(pos, angle)` signal at `SHOOT_IVTL = 1.2s` while enemies exist
- Halt all input processing when `GameStateMachine.current_state != PLAYING`
- Visual: joystick base circle + knob circle drawn in `_draw()` (placeholder — no art asset needed)
- Hero sprite placeholder: circle `#F5C518` with directional arrow in `_draw()`

### Out of Scope

- Camera follow (EPIC-F04)
- Archer formation follow (EPIC-C02)
- Projectile spawning (EPIC-C02)
- Zone dwell triggers (EPIC-C01)

---

## Dependencies

- EPIC-F01 (GameStateMachine must exist to check `current_state`)

---

## Unblocks

- EPIC-F04 (Camera — needs hero position to follow)
- EPIC-C01 (Economy — needs hero position for zone proximity)
- EPIC-C02 (Archer Formation — needs hero position + facing angle for V-formation)

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `HERO_SPEED` | 200.0 | hero-movement.md |
| `JOY_ANCHOR` | `Vector2(135, 800)` | hero-movement.md |
| `JOY_RADIUS` | 80.0 | hero-movement.md |
| `SHOOT_IVTL` | 1.2 | archer-formation.md (owned there, referenced here) |
| `HERO_START_POS` | `Vector2(270, 750)` | hero-movement.md |

---

## Key Acceptance Criteria

- [ ] Hero moves at 200px/s in the direction of joystick deflection
- [ ] Joystick anchor is fixed at `(135, 800)` in viewport space — does not reposition on touch
- [ ] Touch in the bottom half of the screen activates the joystick; touch elsewhere is ignored
- [ ] Hero stops immediately on touch release (no momentum)
- [ ] Facing angle updates continuously during movement; holds last angle when stationary
- [ ] `facing_angle` resets to `PI/2` on session reset
- [ ] Hero does not process input when `GameStateMachine.current_state != PLAYING`
- [ ] Hero respawns at `HERO_START_POS` on session reset
- [ ] Joystick visual (base + knob) is drawn in viewport space and updates in real time

---

## Control Manifest Notes

- Frame-rate-independent lerp NOT needed for hero movement (direct positional input, not lerp)
- No physics body — hero position is set directly
- Touch input via `_input` only — no `InputMap` button mapping
