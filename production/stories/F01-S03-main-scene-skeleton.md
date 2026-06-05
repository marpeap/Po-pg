# Story F01-S03: Main Scene Skeleton + Project Settings

> **Epic**: EPIC-F01 Foundation Infrastructure
> **Status**: Not Started
> **Type**: Integration
> **Test Evidence Required**: Manual walkthrough — ADVISORY
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-scene-001
> **ADR Refs**: ADR-001, ADR-007

## What to Build

Production `Main.tscn` scene skeleton and project settings verification.

### Scene Tree

```
Main (Node2D)
  Camera2D
  GameWorld (Node2D)   ← all gameplay nodes go here
  HUDLayer (CanvasLayer, layer=1)
    HUD (Node)         ← HUD elements, added in EPIC-P01
    GameOverOverlay (Node)  ← added in EPIC-P02, hidden by default
```

### Project Settings

Verify (do not break existing prototype settings):
```ini
[display]
window/size/viewport_width=540
window/size/viewport_height=960
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input_devices]
pointing/emulate_touch_from_mouse=true

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"

[autoload]
GameStateMachine="*res://src/autoloads/game_state_machine.gd"
AudioManager="*res://src/autoloads/audio_manager.gd"
```

### Directory Structure

```
src/
  autoloads/
    game_state_machine.gd
    audio_manager.gd
  gameplay/
    (hero.gd, castle.gd, etc. — future epics)
  ui/
    hud.gd
    game_over_overlay.gd
```

## Acceptance Criteria

- [ ] `Main.tscn` loads without errors in Godot 4.6
- [ ] Viewport is 540×960, canvas_items stretch, keep aspect — confirmed in Godot project settings
- [ ] Both autoloads (GameStateMachine, AudioManager) register and are accessible before any scene `_ready()`
- [ ] `HUDLayer` is a CanvasLayer node with `layer = 1` — NOT a child of Camera2D
- [ ] `GameWorld` node exists as a Node2D child of Main — gameplay nodes will be added here
- [ ] Game launches directly to PLAYING state — no menu shown
