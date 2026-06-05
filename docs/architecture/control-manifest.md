# Control Manifest — Garrison

> **Version**: 1.0
> **Date**: 2026-05-19
> **Source ADRs**: ADR-001 through ADR-009 (all Accepted)
> **Purpose**: Flat actionable rules for all programmers. Every rule traces to an ADR.
> **How to use**: Before writing any code, find your system below and apply its rules.
>   If something isn't listed here, defer to the governing ADR. If still unclear, raise with technical director.

---

## Global Rules (apply to every file in `src/`)

### ALWAYS

| Rule | ADR |
|------|-----|
| Use GDScript only — no C++ extensions | Architecture |
| Static type all function signatures and variables | Coding Standards |
| Use `UPPER_SNAKE_CASE` for constants, `snake_case` for variables, `PascalCase` for classes | Coding Standards |
| Check `GameStateMachine.current_state == State.PLAYING` before processing any gameplay logic | ADR-005 |
| Connect to GSM signals in `_ready()` — subscribe, never poll | ADR-005 |
| Use `Tween` for any UI or HUD animation | ADR-007 |

### NEVER

| Forbidden pattern | Reason | ADR |
|-------------------|--------|-----|
| `lerp(pos, target, FACTOR)` with a constant weight in `_process` | Frame-rate-dependent — feel changes at 30fps | ADR-004 |
| `Camera2D.position_smoothing_enabled = true` | Frame-rate-dependent smoothing | ADR-004 |
| `RigidBody2D`, `CharacterBody2D`, `StaticBody2D` | No physics bodies in gameplay | ADR-002 |
| `body_entered` signal on gameplay nodes | No PhysicsBody2D nodes exist — will never fire | ADR-002 |
| `NavigationAgent2D` / `NavigationServer2D` | Deferred to post-MVP | ADR-006 |
| `Node.instantiate()` for arrows, coins, or impact VFX per event | GC spikes on mobile — use pool | ADR-003 |
| `queue_free()` on pooled nodes | Returns them to limbo — use pool return method | ADR-003 |
| `SceneTree.reload_current_scene()` | Forbidden — in-place session reset only | ADR-007 |
| `AnimationPlayer` on HUD / CanvasLayer nodes | StringName API changed in 4.5–4.6 | ADR-007 |
| `AudioStreamPlayer2D` | All audio is non-positional | ADR-008 |
| `FileAccess.open()` / `ConfigFile` / `JSON` write to disk | No persistence in MVP | ADR-009 |
| Any direct reference from GSM to other systems | GSM is one-way broadcast only | ADR-005 |

---

## Layer 0 — Foundation

### GameStateMachine (autoload)

**File**: `src/autoloads/game_state_machine.gd`

| Rule | ADR |
|------|-----|
| Implement as Godot autoload singleton | ADR-005 |
| Use typed `enum State { PLAYING, GAME_OVER, RESETTING }` | ADR-005 |
| Expose `current_state: State` as a readable property | ADR-005 |
| Emit `game_state_changed(new_state: State)` on every transition | ADR-005 |
| Emit `session_reset` signal on every RESETTING entry | ADR-005 |
| Valid transitions only: `PLAYING → GAME_OVER`, `GAME_OVER → RESETTING`, `RESETTING → PLAYING` | ADR-005 |
| Never store references to Castle, Economy, EnemyWave, or any gameplay system | ADR-005 |
| Listen for `castle_fell` signal from Castle — transition to GAME_OVER | ADR-005 |
| Process touch input only in `GAME_OVER` state (to trigger restart) | ADR-005 |

**Forbidden for GSM**:
- Calling methods on other systems directly
- Storing gameplay values (HP, gold, wave count)
- Having more than 3 states in MVP

---

### AudioManager (autoload)

**File**: `src/autoloads/audio_manager.gd`

| Rule | ADR |
|------|-----|
| Implement as Godot autoload singleton | ADR-008 |
| Use `AudioStreamPlayer` nodes only (no `AudioStreamPlayer2D`) | ADR-008 |
| Expose `play(sfx_name: StringName)` as the only public method for simple SFX | ADR-008 |
| Expose `play_volley(archer_count: int)` for scaled volley volume | ADR-008 |
| Volley volume formula: `volume_db = lerp(-6.0, 0.0, (archer_count - 2) / 6.0)` | ADR-008 |
| Use `StringName` constants for all SFX names (no raw strings) | ADR-008 |
| Stop all active audio on `session_reset` signal | ADR-008 |
| Master bus only — no reverb, no effects bus in MVP | ADR-008 |

**Forbidden for AudioManager**:
- `AudioStreamPlayer2D` — any positional audio
- Raw string SFX names passed between scripts
- Audio logic embedded in gameplay scripts (Economy.gd, etc.)

---

### Viewport / Project Settings

| Setting | Value | ADR |
|---------|-------|-----|
| `display/window/size/viewport_width` | 540 | ADR-001 |
| `display/window/size/viewport_height` | 960 | ADR-001 |
| `display/window/stretch/mode` | `canvas_items` | ADR-001 |
| `display/window/stretch/aspect` | `keep` | ADR-001 |
| `rendering/renderer/rendering_method` | `gl_compatibility` | ADR-001 |
| `rendering/renderer/rendering_method.mobile` | `gl_compatibility` | ADR-001 |
| `input_devices/pointing/emulate_touch_from_mouse` | `true` (dev only) | ADR-001 |

---

## Layer 1 — Core

### Physics Policy

| Rule | ADR |
|------|-----|
| All proximity/overlap detection uses `Area2D` nodes | ADR-002 |
| Connect to `area_entered` / `area_exited` for Area2D-to-Area2D detection | ADR-002 |
| Enemies are `Area2D` nodes (not CharacterBody2D) | ADR-002 |
| Gold coins are `Area2D` nodes | ADR-002 |
| Arrows/projectiles are `Area2D` nodes | ADR-002 |
| Zone triggers (RECRUIT_ZONE, TOWER_ZONE) are `Area2D` nodes | ADR-002 |
| All actual position movement is manual (`position += velocity * delta`) | ADR-002 |
| Disable `CollisionShape2D` on pooled nodes when returning to pool | ADR-002, ADR-003 |

**Forbidden physics patterns**:
- `RigidBody2D.apply_impulse()` or any physics force
- `CharacterBody2D.move_and_slide()` or `move_and_collide()`
- Jolt physics configuration (3D-only, irrelevant)

---

### Frame-Rate-Independent Lerp

**Formula** (mandatory for all follow systems):

```gdscript
# CORRECT — frame-rate independent
var weight: float = 1.0 - pow(1.0 - FACTOR, delta * 60.0)
new_pos = lerp(current_pos, target_pos, weight)

# FORBIDDEN — frame-rate dependent
new_pos = lerp(current_pos, target_pos, FACTOR)  # DO NOT USE
```

| System | FACTOR value | ADR |
|--------|-------------|-----|
| Camera2D follow | `0.10` | ADR-004 |
| Archer formation follow | `0.12` (ARCHER_FOLLOW_LERP) | ADR-004 |

| Rule | ADR |
|------|-----|
| All `lerp()` in `_process` must apply the formula above | ADR-004 |
| `Camera2D.position_smoothing_enabled` must be `false` on all Camera2D nodes | ADR-004 |
| New lerp systems must define their `FACTOR` constant and document the feel intent | ADR-004 |

---

### Enemy Movement

| Rule | ADR |
|------|-----|
| Enemy moves via: `position += (castle_pos - position).normalized() * ENEMY_SPEED * delta` | ADR-006 |
| `ENEMY_SPEED = 70.0` px/s (base). Elite enemies use `ENEMY_SPEED * 1.4`. | ADR-006 |
| Castle position constant: `CASTLE_POS = Vector2(270.0, 62.0)` | ADR-006 |
| No avoidance — enemies may overlap each other | ADR-006 |
| Enemy pool: 30 pre-allocated nodes max | ADR-006 |
| Drain enemy pool on `session_reset` signal | ADR-006 |
| Emit `enemy_died(position: Vector2)` signal on HP reaching 0 | ADR-006 |

**Forbidden for enemy movement**:
- `NavigationAgent2D` — deferred to post-MVP
- `NavigationServer2D` — deferred to post-MVP
- Any steering behavior beyond straight-line direction_to

---

## Layer 2 — Feature

### Object Pool Policy

| Pool | Size | Node type | Owner system | ADR |
|------|------|-----------|--------------|-----|
| Arrows | 24 | Area2D + Sprite2D | ArcherFormation | ADR-003 |
| Impact VFX | 8 | GPUParticles2D | ArcherFormation | ADR-003 |
| Gold coins | 16 | Area2D + Sprite2D | Economy | ADR-003 |
| Enemies | 30 | Area2D + Sprite2D | EnemyWave | ADR-006 |

| Rule | ADR |
|------|-----|
| Pre-allocate all pool nodes at scene load (`_ready()`) — never at spawn time | ADR-003 |
| On checkout: `node.show()`, enable CollisionShape2D, set position, set active | ADR-003 |
| On return: `node.hide()`, disable CollisionShape2D, reset velocity/state | ADR-003 |
| Use `GPUParticles2D.restart()` for impact VFX reuse (not queue_free) | ADR-003 |
| On `session_reset`: return ALL active nodes to their pools | ADR-003 |
| If pool is exhausted (all nodes checked out): log a warning, skip spawn — do NOT instantiate | ADR-003 |

**Forbidden pool patterns**:
- `Node.instantiate()` for any pooled node type during gameplay
- `queue_free()` on any pooled node
- Growing pool size dynamically at runtime

---

### Scene Architecture

| Rule | ADR |
|------|-----|
| Single persistent main scene for entire game loop | ADR-007 |
| HUD implemented as `CanvasLayer` (layer = 1), child of main scene | ADR-007 |
| HUD is NOT a child of Camera2D — it must be screen-space fixed | ADR-007 |
| Game Over overlay is a child of the same `CanvasLayer` as HUD | ADR-007 |
| Session restart resets all state in-place — no scene file reload | ADR-007 |
| HUD visibility controlled by `game_state_changed` signal | ADR-007 |
| Safe area insets: read `DisplayServer.get_display_safe_area()` at startup, offset HUD anchors | ADR-007 |

**Forbidden scene patterns**:
- `SceneTree.reload_current_scene()` or `change_scene_to_*()` for session reset
- `AnimationPlayer` on any node under the `CanvasLayer`
- HUD nodes as children of Camera2D

---

### Session Persistence

| Rule | ADR |
|------|-----|
| No `FileAccess` calls anywhere in MVP | ADR-009 |
| Score (waves survived) is a transient `int` on GameStateMachine — not written to disk | ADR-009 |
| All game state resets identically via `session_reset` signal | ADR-009 |

**Forbidden persistence patterns**:
- `FileAccess.open()` — any file read/write
- `FileAccess.file_exists()`
- `ConfigFile.load()` / `ConfigFile.save()`
- `JSON.stringify()` / `JSON.parse()` for persistent data

---

## Layer 3 — Presentation

### HUD Rules

| Rule | ADR / Source |
|------|-------------|
| HUD owns no game state — reads from upstream via signals | `design/gdd/hud.md` |
| 4 elements only: Gold counter, Castle HP bar, Wave indicator, Archer badge | `design/gdd/hud.md` |
| Castle HP bar must display numeric HP alongside fill — not color alone | `design/accessibility-requirements.md` |
| All HUD elements inside Android safe area rect | ADR-007, ADR-001 |
| Countdown timer in `_process` only when `wave_active == false` | `design/gdd/hud.md` |
| Check `is_visible()` before processing countdown to prevent orphaned ticks | `design/gdd/hud.md` |

### Audio Rules (repeat from Layer 0 for clarity)

| Rule | ADR |
|------|-----|
| Call `AudioManager.play(&"sfx_name")` for all game audio | ADR-008 |
| Never embed `AudioStreamPlayer` in gameplay scripts | ADR-008 |
| Volley audio uses `AudioManager.play_volley(archer_count)` | ADR-008 |

---

## Quick Reference Card

```
CAN DO                              CANNOT DO
───────────────────────────────     ─────────────────────────────────────
Area2D.area_entered / area_exited   RigidBody2D / CharacterBody2D
position += dir * speed * delta     move_and_slide() / move_and_collide()
lerp(a, b, 1.0 - pow(1-F, dt*60))  lerp(a, b, FACTOR)  ← no delta
Pool.checkout() / Pool.return()     instantiate() / queue_free()  ← pooled
AudioManager.play(&"sfx")          AudioStreamPlayer2D
Tween.tween_property(...)          AnimationPlayer  ← on HUD nodes
GameStateMachine.current_state      SceneTree.reload_current_scene()
session_reset signal broadcast      FileAccess.open() / ConfigFile
```

---

*Control Manifest v1.0 — extracted from ADRs 001–009, all Accepted, 2026-05-19.*
*Update when a new ADR is Accepted. Version increment required on any rule change.*
