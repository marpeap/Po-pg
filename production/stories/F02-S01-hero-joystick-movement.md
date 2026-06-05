# Story F02-S01: Hero Node + Virtual Joystick + Movement

> **Epic**: EPIC-F02 Hero Movement
> **Status**: Not Started
> **Type**: Logic + Visual
> **Test Evidence Required**: Unit test for joystick math — BLOCKING; Screenshot of hero moving — ADVISORY
> **Estimate**: 1 day
> **GDD Req ID**: TR-hero-001
> **ADR Refs**: ADR-002 (Area2D), ADR-001 (viewport coords)

## What to Build

`src/gameplay/hero.gd` — Node2D, virtual joystick, movement, facing angle, draw placeholder.

### Key Implementation

```gdscript
extends Node2D

const HERO_SPEED := 200.0
const JOY_ANCHOR := Vector2(135.0, 800.0)
const JOY_RADIUS := 80.0
const HERO_START_POS := Vector2(270.0, 750.0)

var _joy_active: bool = false
var _joy_touch_id: int = -1
var _joy_direction: Vector2 = Vector2.ZERO
var facing_angle: float = PI / 2.0  # Facing down by default

func _input(event: InputEvent) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
        return
    # Bottom-half activation: event.position.y > 480 (half of 960)
    # Single-touch: first touch claims joystick
    # Knob: direction = clamp(touch - anchor, JOY_RADIUS)

func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
        return
    if _joy_active and _joy_direction.length() > 0.1:
        position += _joy_direction * HERO_SPEED * delta
        facing_angle = _joy_direction.angle()
    # Clamp hero to world bounds (0,0)-(1080,1920)

func _draw() -> void:
    # Hero circle + facing arrow
    # Joystick base + knob (in local space — needs viewport-to-world transform)
```

### Session Reset

Connect to `GameStateMachine.session_reset`:
- `position = HERO_START_POS`
- `facing_angle = PI / 2.0`
- `_joy_active = false`
- `_joy_direction = Vector2.ZERO`

## Engine Notes

- Joystick visual is in VIEWPORT space; hero is in WORLD space. The `_draw()` call happens in local (world) space. Joystick must be drawn on a CanvasLayer or converted via `get_viewport_transform().affine_inverse()`.
- Alternative: draw joystick separately in a dedicated Node2D on HUDLayer.

## Acceptance Criteria

- [ ] Hero moves at 200px/s in joystick direction
- [ ] Joystick anchor is fixed at `(135, 800)` viewport space — does not reposition on touch
- [ ] Only touches starting in the bottom half of the screen activate the joystick
- [ ] Hero stops immediately when touch is released
- [ ] `facing_angle` updates to current movement direction while moving
- [ ] `facing_angle` holds last value when stationary (does not snap to default)
- [ ] `facing_angle` resets to `PI/2` on session reset
- [ ] Hero position resets to `(270, 750)` on session reset
- [ ] Hero stays within world bounds (0,0)–(1080,1920) at all times

## Test File

`tests/unit/gameplay/hero_movement_test.gd`

Test cases:
- `test_joystick_direction_normalized`
- `test_hero_speed_correct_displacement`
- `test_bottom_half_activation_only`
- `test_facing_angle_updates_on_move`
- `test_session_reset_restores_start_pos`
- `test_hero_clamped_to_world_bounds`
