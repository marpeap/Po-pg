# Godot Touch Input — Quick Reference (Garrison)

Last verified: 2026-05-19 | Engine: Godot 4.6

Garrison uses joystick-only touch input. No tap/button interactions during gameplay.
This doc covers only the surfaces used by this project.

---

## Core Event Types

### InputEventScreenTouch

Fires when a finger touches or lifts from the screen.

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var finger_index: int = event.index       # 0 = first finger, 1 = second, etc.
        var touch_pos: Vector2 = event.position   # Screen coords
        var is_pressed: bool = event.pressed       # true = down, false = up
```

**Android behaviour:** Finger indices are dynamically assigned. When ALL fingers lift,
indices reset — the next touch always starts at index 0. Do not track finger identity
across gestures.

### InputEventScreenDrag

Fires continuously while a finger moves on-screen.

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        var finger_index: int = event.index
        var drag_pos: Vector2 = event.position      # Current screen position
        var delta: Vector2 = event.relative         # Delta since last drag event
        var drag_vel: Vector2 = event.velocity      # Pixels/second
```

---

## Virtual Joystick Pattern (Garrison)

Garrison's joystick is fixed-anchor, not follow-finger.

```gdscript
const JOYSTICK_ANCHOR: Vector2 = Vector2(135.0, 800.0)  # Validated in prototype
const JOYSTICK_RADIUS: float = 80.0

var _joystick_finger: int = -1  # -1 = not active
var _joystick_vector: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_joystick_touch(event)
    elif event is InputEventScreenDrag:
        _handle_joystick_drag(event)

func _handle_joystick_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        # Accept the first finger that lands near the anchor
        var dist: float = event.position.distance_to(JOYSTICK_ANCHOR)
        if _joystick_finger == -1 and dist <= JOYSTICK_RADIUS * 1.5:
            _joystick_finger = event.index
    else:
        # Finger lifted
        if event.index == _joystick_finger:
            _joystick_finger = -1
            _joystick_vector = Vector2.ZERO

func _handle_joystick_drag(event: InputEventScreenDrag) -> void:
    if event.index != _joystick_finger:
        return
    var offset: Vector2 = event.position - JOYSTICK_ANCHOR
    _joystick_vector = offset.limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS

func get_movement_vector() -> Vector2:
    return _joystick_vector
```

---

## Project Settings (Garrison)

**Disable mouse emulation from touch** — Garrison handles touch natively:
```
Project Settings → Input Devices → Pointing → Emulate Mouse From Touch → OFF
```

**Disable touch emulation from mouse** for desktop testing clarity:
```
Project Settings → Input Devices → Pointing → Emulate Touch From Mouse → ON (dev only)
```

---

## Common Mistakes

- Assuming finger index 0 is always the same finger — indices reset when all fingers lift
- Using `Input.get_touch_position(index)` in `_process()` instead of caching from events
- Not limiting the joystick vector with `limit_length()` — raw offset can exceed radius on fast swipes
- Forgetting to disable mouse emulation — without it, touch events also fire mouse events, doubling input
