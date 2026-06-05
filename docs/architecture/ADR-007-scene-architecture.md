# ADR-007: Scene Architecture and HUD Layout

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Garrison uses a **single persistent main scene** for the entire game loop — no scene transitions
in MVP. The HUD is a `CanvasLayer` child of the main scene (not of the Camera2D). All HUD
transitions use `Tween` instead of `AnimationPlayer` to avoid Godot 4.5–4.6 AnimationPlayer
StringName changes. Session restart resets in-place without scene reloading.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Rendering / UI |
| **Knowledge Risk** | MEDIUM — AnimationPlayer StringName changes in 4.5 (HIGH risk). `CanvasLayer`, `SceneTree.reload_current_scene()`, `Tween` are stable. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — mandating `Tween` specifically avoids the AnimationPlayer StringName risk |
| **Verification Required** | Confirm `CanvasLayer` renders above `Camera2D` viewport correctly at 540×960 (ADR-001); confirm `Tween` callbacks fire correctly in Godot 4.6 |

> **Note**: AnimationPlayer StringName changes are HIGH risk in 4.5–4.6. This ADR mandates
> Tween for HUD animations as a direct mitigation.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-001 (viewport 540×960 — HUD is in logical viewport space), ADR-005 (GSM state — HUD visibility gating) |
| **Enables** | HUD implementation, session restart UX |
| **Blocks** | HUD script, game over screen, any UI node placement |
| **Ordering Note** | ADR-001 and ADR-005 must be Accepted first |

## Context

### Problem Statement

Without a defined scene structure, HUD nodes may be placed as children of Camera2D (causing
them to scroll with the world) or as world-space nodes (causing them to move off-screen when
the camera follows the hero). The HUD must be fixed to the screen regardless of camera position.

Additionally, architecture.md flagged AnimationPlayer StringName changes (4.5 HIGH risk) as
a concern for HUD transitions. A mitigation decision is required before HUD implementation.

### Current State

No scene file exists. No HUD structure defined.

### Constraints

- Viewport: 540×960 logical pixels (ADR-001)
- HUD must not move with Camera2D
- Single Android portrait orientation
- AnimationPlayer StringName changes: HIGH risk in Godot 4.5–4.6 — avoid where possible
- Session restart must be in-place (< 0.5s perceived reset time) — scene reload adds 1–3s

### Requirements

- HUD elements fixed to screen (not world space)
- HUD visible only in PLAYING and WAVE_CLEAR states
- Session restart resets game state without reloading the scene file
- Tween used for all HUD fade/slide animations (no AnimationPlayer on HUD nodes)

## Decision

### Scene Tree Structure

```
Main (Node2D — root of main.tscn)
├─ World (Node2D — world-space content, affected by Camera2D)
│   ├─ Camera2D (CameraFollow script — ADR-001, ADR-004)
│   ├─ Hero (Node2D — HeroMovement script)
│   ├─ ArcherFormation (Node2D — archers + projectile logic)
│   ├─ EnemyWave (Node — spawner + wave logic)
│   ├─ Castle (Area2D — HP tracking)
│   ├─ Economy (Node — zones + gold logic)
│   ├─ ArcherTower (Node2D — tower instances, instantiated on purchase)
│   └─ Forge (Node — 4 FORGE_ZONEs)
│
└─ HUD (CanvasLayer — layer: 1, fixed to screen)
    ├─ GoldLabel (Label — top-right)
    ├─ CastleHPBar (ProgressBar — top-left or top-center)
    ├─ WaveLabel (Label — top-center)
    ├─ ArcherCountLabel (Label — bottom HUD area)
    ├─ GameOverOverlay (Control — full-screen, hidden by default)
    └─ WaveClearOverlay (Control — brief, hidden by default)
```

**CanvasLayer**: `layer = 1` renders above all `Node2D` world content (which renders at layer 0).
Camera2D does NOT affect CanvasLayer — HUD stays fixed to screen regardless of camera position.

**Why not a child of Camera2D?**: Camera2D children are still in world space — they move with the camera. CanvasLayer is viewport-space. CanvasLayer is the correct Godot 4.x pattern for fixed HUD.

### Session Restart: In-Place Reset (No Scene Reload)

MVP uses in-place reset via `GameStateMachine.session_restart` signal:

```
GameStateMachine.session_restart emitted
    → All systems reset their state (economy.gold = 60, slots = 2, etc.)
    → ObjectPoolManager._drain() returns all nodes to pools
    → HUD resets display values
    → No SceneTree.reload_current_scene() call
    → Total perceived reset time: < 1 frame
```

`SceneTree.reload_current_scene()` is **forbidden** — it adds 1–3 seconds of load time
and discards all pre-allocated pool nodes (ADR-003), requiring re-allocation.

### AnimationPlayer: Forbidden on HUD Nodes

**Rule**: No `AnimationPlayer` on any node in the HUD `CanvasLayer` subtree.
**Reason**: Godot 4.5 changed how AnimationPlayer references animation names (StringName migration).
Using `AnimationPlayer` in HUD risks silent failures when animation names are accessed by string.
**Alternative**: Use `Tween` for all HUD transitions.

```gdscript
# CORRECT — use Tween for HUD fade
func show_game_over() -> void:
    game_over_overlay.visible = true
    game_over_overlay.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(game_over_overlay, "modulate:a", 1.0, 0.4)

# FORBIDDEN — do not use AnimationPlayer on HUD
# anim_player.play("game_over_fade_in")  # StringName risk in 4.6
```

**Scope**: This restriction applies only to HUD nodes. `AnimatedSprite2D` on world-space nodes
(archers, enemies) is acceptable — it uses frame indices, not AnimationPlayer StringNames.

### HUD Visibility Gating

HUD visibility is controlled by `GameStateMachine.current_state`:

```gdscript
# hud.gd
func _ready() -> void:
    GameStateMachine.session_started.connect(_show_hud)
    GameStateMachine.wave_clear.connect(_show_hud)
    GameStateMachine.game_over.connect(_show_game_over_overlay)
    GameStateMachine.session_restart.connect(_reset_hud)

func _show_hud(_wave_n: int = 0) -> void:
    visible = true  # CanvasLayer visibility
    game_over_overlay.visible = false
    wave_clear_overlay.visible = false

func _show_game_over_overlay() -> void:
    # Tween game over overlay in
    ...

func _reset_hud() -> void:
    gold_label.text = "60"
    castle_hp_bar.value = 60.0  # CASTLE_MAX_HP
    archer_count_label.text = "2/8"
    game_over_overlay.visible = false
```

### Key Interfaces

```gdscript
# Node path conventions (use these exact names in scenes):
# Main/World/Hero
# Main/World/Camera2D
# Main/World/ArcherFormation
# Main/World/EnemyWave
# Main/World/Castle
# Main/World/Economy
# Main/HUD
# Main/HUD/GoldLabel
# Main/HUD/CastleHPBar
# Main/HUD/WaveLabel
# Main/HUD/ArcherCountLabel
# Main/HUD/GameOverOverlay
# Main/HUD/WaveClearOverlay
```

```gdscript
# Project Settings: main scene
# application/run/main_scene = "res://src/main/main.tscn"
```

### Implementation Guidelines

1. **CanvasLayer, not Node2D** for HUD root. `layer = 1`. Never reparent HUD nodes under
   World or Camera2D.
2. **Tween only** for HUD animations. No AnimationPlayer on any CanvasLayer child.
   `create_tween()` is called on the HUD node itself (not via a singleton).
3. **No `SceneTree.reload_current_scene()`**. Session restart is in-place signal broadcast.
4. **Node naming**: Use the exact paths defined in Key Interfaces. Skills (`/create-stories`,
   `/story-done`) reference node paths by name.
5. **Safe area**: Apply `DisplayServer.get_display_safe_area()` to offset HUD elements near
   screen edges. Top/bottom 40px logical margin covers most Android notches at 2× scale
   (per ADR-001 guidance).
6. **Game Over Overlay**: Full-screen `ColorRect` (semi-transparent black) + retry button or
   auto-timer. The "retry button" may be implemented as a dwell zone or tap-anywhere — resolved
   in UX spec (not this ADR).

## Alternatives Considered

### Alternative 1: HUD as child of Camera2D

- **Description**: HUD nodes parented under the Camera2D node.
- **Pros**: Intuitive to set up in editor.
- **Cons**: Camera2D children are in world space. As the camera lerps, HUD elements drift.
  Not how Godot HUD is intended to work.
- **Rejection Reason**: HUD would move with camera. Incorrect behavior.

### Alternative 2: Multiple scenes with `change_scene_to_file()`

- **Description**: Separate scenes for gameplay, game-over, main menu.
- **Pros**: Clean scene separation. Standard game architecture.
- **Cons**: MVP has no main menu. Session restart via scene reload takes 1–3 seconds.
  Object pools (ADR-003) are discarded on scene reload — pool pre-allocation is wasted.
  Adds complexity with no MVP benefit.
- **Rejection Reason**: Pool architecture requires in-place reset. Scene reload time
  is unacceptable for a "tap to retry" mobile loop.

### Alternative 3: AnimationPlayer for HUD transitions

- **Description**: Use AnimationPlayer on HUD nodes for fade-in/fade-out animations.
- **Pros**: Visual in editor, easy to tweak timing.
- **Cons**: Godot 4.5 AnimationPlayer StringName changes. Animation names referenced as
  strings risk silent failures. `Tween` achieves the same result with zero risk.
- **Rejection Reason**: Post-cutoff HIGH risk domain. Tween is equivalent and safe.

## Consequences

### Positive

- HUD stays fixed to screen regardless of camera position
- Session restart is instant (< 1 frame perceived)
- Pool pre-allocation survives restarts (no re-allocation cost)
- No AnimationPlayer risk on HUD

### Negative

- All HUD animations must be written as `Tween` code — no visual animation editor for HUD
- In-place reset requires every system to correctly handle `session_restart` — no "clean slate" from scene reload

### Neutral

- Single scene file for all of MVP — simpler to manage for solo dev

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| CanvasLayer not rendering above world at first setup | Low | Low (visual bug) | Set `layer = 1` explicitly in editor; verify on first run |
| Tween fires after node is freed (e.g., restart while tween active) | Low | Medium (error log) | Call `tween.kill()` at start of `_reset_hud()` before creating new tweens |
| Node paths change during refactor and break signal connections | Medium | Low | Use `@onready var` with editor-assigned node references rather than `get_node()` paths |

## Performance Implications

| Metric | Scene reload approach | In-place reset (chosen) | Budget |
|--------|----------------------|-------------------------|--------|
| Restart time | 1–3s (scene load) | < 1 frame | Instant feel |
| Pool re-alloc on restart | Yes (full cost) | No (pools persist) | Zero |
| Tween overhead | N/A | Negligible | — |

## Migration Plan

1. Create `src/main/main.tscn` with node structure defined above
2. Set `application/run/main_scene = "res://src/main/main.tscn"` in Project Settings
3. Create `src/hud/hud.gd` — connect to GSM signals, use Tween for all animations
4. Set `CanvasLayer.layer = 1` in editor

## Validation Criteria

- [ ] HUD elements do not move when hero moves to world edges (camera scroll does not affect HUD)
- [ ] `GameOverOverlay` fades in using Tween when `game_over` fires
- [ ] Session restart: HUD resets to initial values (gold=60, HP=60, archers=2/8) within 1 frame
- [ ] No AnimationPlayer nodes exist in the HUD subtree (grep `AnimationPlayer` in `src/hud/`)
- [ ] CanvasLayer renders above all world-space nodes (archer sprites, enemies, zones)

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/hud.md` | HUD | CanvasLayer-based overlay fixed to screen | HUD is CanvasLayer child of Main, layer=1, not Camera2D child |
| `design/gdd/hud.md` | HUD | Visible only in PLAYING and WAVE_CLEAR states | GSM signal-gated visibility in hud.gd |
| `design/gdd/game-state.md` | Game State Machine | Session restart resets all systems without exiting | In-place reset via `session_restart` signal — no `reload_current_scene()` |
| `docs/architecture/architecture.md` | Architecture | AnimationPlayer risk (QQ-03) — mandate Tween for HUD | AnimationPlayer explicitly forbidden on HUD nodes |

## Related

- ADR-001 — Viewport Resolution (HUD in 540×960 logical space)
- ADR-005 — Game State Machine (HUD gates on GSM state)
- `docs/engine-reference/godot/breaking-changes.md` — AnimationPlayer StringName changes (4.5)
