# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Compatibility (recommandé mobile Android)
- **Physics**: GodotPhysics2D — Area2D overlap only. Jolt is 3D-only in 4.6 and not used. (ADR-002)
- **Viewport**: 960×540 px landscape, canvas_items stretch, keep aspect (ADR-001 — landscape refactor Sprint 7)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Android (Mobile)
- **Input Methods**: Touch
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Toute l'UI doit supporter le touch. Pas d'interactions hover-only. Gérer les safe area insets (notch, barre de navigation Android).

## Naming Conventions

- **Classes**: PascalCase (ex: `PlayerController`)
- **Variables**: snake_case (ex: `move_speed`)
- **Signals/Events**: snake_case passé (ex: `health_changed`)
- **Files**: snake_case correspondant à la classe (ex: `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase correspondant au node racine (ex: `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (ex: `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: ≤150 (mobile Android)
- **Memory Ceiling**: ≤512MB

## Testing

- **Framework**: GUT (Godot Unit Testing)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- `Camera2D.position_smoothing_enabled = true` — frame-rate-dependent; use manual lerp (ADR-004)
- `lerp(pos, target, FACTOR)` without delta in the weight — frame-rate-dependent follow (ADR-004)
- `RigidBody2D`, `CharacterBody2D`, `StaticBody2D` — no physics bodies in gameplay (ADR-002)
- `body_entered` signal in zone/projectile/magnet scripts — no PhysicsBody2D nodes exist (ADR-002)
- `Node.instantiate()` per volley/coin spawn — use ObjectPoolManager instead (ADR-003)
- `queue_free()` on pooled nodes — return to pool via `ObjectPoolManager.*.return_node()` (ADR-003)
- `SceneTree.reload_current_scene()` — forbidden; in-place session reset via GSM signal (ADR-007)
- `AnimationPlayer` on HUD CanvasLayer nodes — use Tween instead (ADR-007, StringName risk)
- `AudioStreamPlayer2D` — all audio is non-positional; use `AudioStreamPlayer` via AudioManager (ADR-008)
- `FileAccess.open()` / `ConfigFile` / `JSON` persistence — no save in MVP (ADR-009)
- `NavigationAgent2D` / `NavigationServer2D` — deferred to post-MVP; enemies use direction_to (ADR-006)

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- GUT 9.6.0 — test framework (Godot Unit Testing), installed at `addons/gut/`

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-001: Viewport Resolution — 960×540 landscape, canvas_items stretch, keep aspect → `docs/architecture/ADR-001-viewport-resolution.md`
- ADR-002: Physics Policy — Area2D overlap only; no Jolt, no RigidBody2D → `docs/architecture/ADR-002-physics-policy.md`
- ADR-003: Object Pool Pattern — 24 arrows, 8 impacts, 16 coins; ObjectPoolManager autoload → `docs/architecture/ADR-003-object-pool-pattern.md`
- ADR-004: Frame-Rate-Independent Lerp — `weight = 1.0 - pow(1.0 - F, delta * 60.0)` → `docs/architecture/ADR-004-framerate-independent-lerp.md`
- ADR-005: Game State Machine / Autoload — singleton FSM, signal broadcast → `docs/architecture/ADR-005-game-state-machine.md`
- ADR-006: Enemy Pathfinding MVP — direction_to steering, enemy pool 30 nodes → `docs/architecture/ADR-006-enemy-pathfinding.md`
- ADR-007: Scene Architecture / HUD — CanvasLayer HUD, Tween only, no scene reload → `docs/architecture/ADR-007-scene-architecture.md`
- ADR-008: Audio Architecture — AudioManager autoload, non-positional, volley volume scaling → `docs/architecture/ADR-008-audio-architecture.md`
- ADR-009: Session Persistence — no FileAccess in MVP, score display transient only → `docs/architecture/ADR-009-session-persistence.md`

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
