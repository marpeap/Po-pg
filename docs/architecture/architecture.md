# Garrison — Master Architecture

## Document Status

| Field | Value |
|-------|-------|
| **Version** | 1.0 |
| **Date** | 2026-05-19 |
| **Engine** | Godot 4.6 / GDScript / Compatibility Renderer |
| **GDDs Covered** | game-state, hero-movement, camera, castle, enemy-wave, economy, archer-formation, hud, archer-tower, forge |
| **ADRs Referenced** | ADR-001, ADR-002, ADR-003, ADR-004 |
| **Technical Director Sign-Off** | 2026-05-19 — APPROVED |
| **Lead Programmer Feasibility** | Lean mode — skipped |

---

## Engine Knowledge Gap Summary

| Domain | Risk | Notes |
|--------|------|-------|
| Rendering (glow, D3D12) | HIGH | Garrison uses Compatibility renderer — glow rework in 4.6 does not affect Compatibility. D3D12 Windows-only. Not relevant to Android. |
| Animation (IK, StringName) | HIGH | Garrison uses `AnimatedSprite2D` (not `AnimationPlayer` directly). StringName changes affect AnimationPlayer — use string-based frame names sparingly. |
| Scripting (@abstract, variadic) | MEDIUM | Garrison does not use @abstract. Verify variadic arg syntax if GDScript version changes. |
| Accessibility (AccessKit) | MEDIUM | MVP has no accessibility requirements. Document for future reference only. |
| GPUParticles2D | MEDIUM | Emission shape API changes in 4.5–4.6. Verify `emission_shape` and `restart()` behavior on first Godot 4.6 run. |
| Input (Touch) | LOW | `InputEventScreenTouch`, `InputEventScreenDrag`, finger index behavior — stable since 4.0. |
| Area2D overlap | LOW | Signals, `monitoring`, `monitorable` — stable since 4.0. |
| Camera2D | LOW | Limits, `position_smoothing_enabled` — stable since 4.0. |

**Verified**: Jolt physics is 3D-only in Godot 4.6. 2D physics uses GodotPhysics2D (default). No Jolt configuration required.

---

## Architecture Principles

1. **One joystick, zero additional inputs.** All systems must be drivable by the hero's position alone. No modal dialogs, no tap targets, no buttons. Architectural consequence: all inter-system triggers are either positional (Area2D overlap) or automatic (timers, signals). See game-concept.md Pillar 1.

2. **Area2D overlap for all proximity detection.** No RigidBody2D, no CharacterBody2D, no Jolt. See ADR-002. Consequence: every collision node is `Area2D`; both nodes must be monitorable.

3. **Frame-rate-independent lerp for all continuous follow.** Use `1.0 - pow(1.0 - F, delta * 60.0)` everywhere lerp is applied. Naive `lerp(a, b, F)` is forbidden. See ADR-004.

4. **Object pools for high-frequency spawns.** Arrows, impacts, coins: pre-allocated at scene load, recycled on return. No `instantiate()` / `queue_free()` per gameplay event. See ADR-003.

5. **Signals for cross-system events; direct reads for per-frame data.** Signals communicate discrete state changes (wave complete, purchase, game over). Per-frame data (hero_pos, facing_angle, current_archer_count) is read directly via exposed properties — no signal overhead for continuous frame data.

---

## System Layer Map

```
┌────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                                │
│  ├─ HUD (CanvasLayer — gold counter, castle HP, wave, archer count)│
│  └─ VFX (integrated into Archer Formation — see ADR-003)          │
├────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER (Alpha)                                             │
│  ├─ Archer Tower (fixed-position firing unit; slot-release R3)     │
│  └─ Forge (4 spatial zones; PROJ_DAMAGE_UP / SHOOT_IVTL_DOWN)     │
├────────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                        │
│  ├─ Economy (gold balance, zone dwell, coin magnet, purchases)     │
│  └─ Archer Formation (8-slot V, projectiles, pools, targeting)     │
├────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                                  │
│  ├─ Game State Machine (global autoload — 5-state FSM)             │
│  ├─ Hero Movement (joystick input, hero_pos, facing_angle, timer)  │
│  ├─ Camera (Camera2D follow, world bounds)                         │
│  ├─ Castle (Area2D hitbox, HP tracking, castle_destroyed signal)   │
│  └─ Enemy Wave (spawn, pathfinding, wave counter)                  │
├────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                    │
│  └─ Godot 4.6 / Android / Compatibility Renderer / GodotPhysics2D │
└────────────────────────────────────────────────────────────────────┘
```

**Layer rules** (from systems-index.md dependency graph):
- Foundation L0 (no deps): Game State Machine, Hero Movement
- Foundation L1 (→ L0): Camera → Hero Movement; Castle → Game State Machine
- Foundation L2 (→ L1): Enemy Wave → Castle
- Core L3 (→ L0+L2): Economy → Hero+Enemy; Archer Formation → Hero+Enemy
- Feature L4 (→ L3): Archer Tower → Formation+Economy; Forge → Economy+GameState
- Presentation L5 (→ L2+L3): HUD → Economy+Castle+EnemyWave

---

## Module Ownership

### Foundation Layer

#### Game State Machine (Autoload: `GameStateMachine`)

| Field | Detail |
|-------|--------|
| **Owns** | `current_state: GameState` enum, state transition history |
| **Exposes** | Signals: `session_started`, `wave_started(wave_n)`, `wave_clear`, `game_over`, `session_restart`; Property: `current_state` (read-only external) |
| **Consumes** | `castle_destroyed` from Castle; `wave_complete` from Enemy Wave |
| **Engine APIs** | Autoload singleton, `SceneTree` signals, `Node._ready()` |
| **Knowledge Risk** | LOW — autoload pattern stable since 4.0 |

**State machine:**
```
LOADING → SESSION_RESET → PLAYING ↔ WAVE_CLEAR
                                  ↓ (castle destroyed)
                              GAME_OVER → SESSION_RESET
```

#### Hero Movement (`hero_movement.gd`, `Node2D`)

| Field | Detail |
|-------|--------|
| **Owns** | `hero_pos: Vector2`, `facing_angle: float`, `_joystick_finger: int`, `_joystick_vector: Vector2`, shoot timer (`_shoot_timer: float`) |
| **Exposes** | `hero_pos` (property), `facing_angle` (property), signal `shoot_interval_tick` (every SHOOT_IVTL = 0.9s) |
| **Consumes** | `InputEventScreenTouch`, `InputEventScreenDrag` (via `_input(event)`) |
| **Engine APIs** | `InputEventScreenTouch`, `InputEventScreenDrag` — LOW risk |
| **ADR** | ADR-004 (lerp if any hero follow effect needed) |

Joystick: fixed anchor (135, 800), radius 80px, single-finger, vector clamped via `limit_length()`.
Hero moves at `HERO_SPEED = 240 px/s` scaled by joystick magnitude.
`facing_angle` updates when `_joystick_vector.length() > 0.1`; held on idle.
Initializes to `π` (facing up) at session start.

#### Camera (`camera_follow.gd`, `Camera2D`)

| Field | Detail |
|-------|--------|
| **Owns** | Camera position (derived — follows hero) |
| **Exposes** | Nothing (rendering-only) |
| **Consumes** | `hero.hero_pos` (direct property read each frame) |
| **Engine APIs** | `Camera2D` — LOW risk; `position_smoothing_enabled = false` (required) |
| **ADR** | ADR-001 (viewport: 540×960), ADR-004 (lerp formula: factor 0.10) |

World limits: `limit_left=0`, `limit_right=1080`, `limit_top=0`, `limit_bottom=1920`.
Applied in `_ready()`. Godot applies limits after position update — no manual clamping.

#### Castle (`castle.gd`, `Area2D`)

| Field | Detail |
|-------|--------|
| **Owns** | `CASTLE_HP: int` (current), `_castle_destroyed_emitted: bool` |
| **Exposes** | `current_hp: int` (read-only), `hp_changed(new_hp)` signal, `castle_destroyed` signal |
| **Consumes** | Enemy `area_entered` → `take_contact_damage()` |
| **Engine APIs** | `Area2D`, `area_entered` signal — LOW risk |
| **ADR** | ADR-002 (Area2D, collision layer 6: castle, mask: enemy) |

Castle HP: 60 (CASTLE_MAX_HP). Each enemy contact: -10 HP (CASTLE_DAMAGE_PER_CONTACT).
6 contacts = game_over. One-shot signal guard (`_castle_destroyed_emitted`) prevents re-emission.
Session reset: HP returns to CASTLE_MAX_HP.

⚠️  **Engine note**: Area2D `area_entered` signal for enemy contact confirmed in ADR-002.
Use `area_entered`, NOT `body_entered`.

#### Enemy Wave (`enemy_wave.gd`, `Node2D`)

| Field | Detail |
|-------|--------|
| **Owns** | Active enemy pool, `_wave_index: int`, `_spawn_interval: float`, wave state |
| **Exposes** | `enemy_died(position: Vector2)` signal, `wave_complete` signal; enemy nodes (readable for target acquisition) |
| **Consumes** | `session_restart` from GameStateMachine; `castle_pos: Vector2` (constant or Castle property) |
| **Engine APIs** | `Area2D` (enemy hitbox, layer: enemy), `Node2D._process()` |
| **ADR** | ADR-002 (Area2D, collision layer 2: enemy; mask: castle) |

Spawn formula: `enemies_per_wave(w) = 5 + floor(w × 1.15)` (approx, see enemy-wave.md).
Enemy HP: `30 + (wave - 1) × 3`. Enemy speed: 70 px/s toward castle.
Steering: `velocity = direction_to(castle_pos) × ENEMY_SPEED` — no NavMesh, no avoidance in MVP.

⚠️  **Known gap**: No enemy object pool in current ADRs. Required new ADR (ADR-008 or dedicated enemy pool ADR). At 20 enemies/wave × 13 waves = 260 enemy nodes over a session. Recommend pre-allocating a pool of 30 enemy nodes.

---

### Core Layer

#### Economy (`economy.gd`, `Node`)

| Field | Detail |
|-------|--------|
| **Owns** | `gold: int`, zone dwell timers (one per zone), coin nodes (via pool) |
| **Exposes** | `gold_changed(new_gold: int)` signal, `recruit_purchased`, `tower_purchased`, `forge_upgrade_purchased(upgrade_type: StringName)` signals |
| **Consumes** | `hero_pos` (zone dwell check via Area2D), `current_archer_count` from ArcherFormation, `enemy_died(position)` from EnemyWave, `session_restart` from GameStateMachine |
| **Engine APIs** | `Area2D` (zones + magnet + coins), `area_entered`, `area_exited` — LOW risk |
| **ADR** | ADR-002 (collision layers 3: zone, 5: coin), ADR-003 (coin pool) |

Gold sources: GOLD_DROP_PER_ENEMY=15g per kill (coin drops at enemy death position, attracted by HeroMagnet r=170px).
Session start: gold=60 (STARTING_GOLD).

**Zone table:**

| Zone | Cost | Condition | Signal |
|------|------|-----------|--------|
| RECRUIT_ZONE | 30g (T1, n<4) or 60g (T2, n≥4) | `current_archer_count < 8` | `recruit_purchased` |
| TOWER_ZONE | 100g | Always active (MVP) | `tower_purchased` |
| FORGE_ZONE_PROJ | 200g | Always active (Alpha) | `forge_upgrade_purchased("proj_damage_up")` |
| FORGE_ZONE_IVTL | 200g | Always active (Alpha) | `forge_upgrade_purchased("shoot_ivtl_down")` |
| FORGE_ZONE_CASTLE | 200g | Always active (Alpha) | `forge_upgrade_purchased("castle_hp_up")` |
| FORGE_ZONE_MAGNET | 200g | Always active (Alpha) | `forge_upgrade_purchased("magnet_radius_up")` |

All zones: dwell 0.8s → action. Dwell timer resets on `area_exited`.

#### Archer Formation (`archer_formation.gd`, `Node2D`)

| Field | Detail |
|-------|--------|
| **Owns** | `_slot_states: Array[bool]` (8), `current_archer_count: int`, archer `Node2D` array, `_shoot_timer: float`, shared target reference |
| **Exposes** | `current_archer_count: int` (property), `formation_full` signal |
| **Consumes** | `hero_pos`, `facing_angle` from HeroMovement (frame); `shoot_interval_tick` from HeroMovement; `recruit_purchased` from Economy; `tower_purchased` from ArcherTower; `session_restart` from GameStateMachine; enemy positions from EnemyWave |
| **Engine APIs** | `Area2D` (arrows via pool), `AnimatedSprite2D` (archer sprites), `GPUParticles2D` (recruit burst, impact burst) ⚠️ MEDIUM risk |
| **ADR** | ADR-002 (arrows: layer 4 projectile, mask 2 enemy), ADR-003 (pools), ADR-004 (archer lerp 0.12) |

Formation slot world pos: `hero_pos + behind × depth_offset + right × lateral_offset`. Per-frame.
Snap threshold: 300px. Fire on `shoot_interval_tick` if `shared_target != null`.
`tower_purchased` → release slots `[6, 7]` (or highest occupied pair) to tower.

⚠️  **GPUParticles2D risk**: Verify `one_shot`, `restart()`, and emission properties in Godot 4.6 against `docs/engine-reference/godot/modules/` before implementing particle bursts.

---

### Feature Layer

#### Archer Tower (`archer_tower.gd`, `Node2D` per tower instance)

| Field | Detail |
|-------|--------|
| **Owns** | Tower position (fixed), tower archer count (TOWER_ARCHERS_COUNT=2), tower fire timer |
| **Exposes** | — (receives tower_purchased from Economy, coordinates slot release via ArcherFormation) |
| **Consumes** | `tower_purchased` from Economy; slot transfer from ArcherFormation (R3) |
| **Engine APIs** | `Area2D` (tower arrow hitbox), ObjectPool (tower arrows — shares ADR-003 pool or extends it) |
| **ADR** | ADR-002 (tower arrows: same as formation arrows), ADR-003 (pool extends to tower arrows) |

Tower fires independently on its own timer (not shared with SHOOT_IVTL).
Tower DPS ≈ 21.3 (estimated; see archer-tower.md).
Tower arrows use the same ADR-003 arrow pool (shared pool sized to accommodate both formation + tower).

**ADR gap**: ADR-003 pools formation arrows only (24). Tower arrows need pool capacity extension. Update pool size formula when tower is implemented.

#### Forge (`forge.gd`, `Node`)

| Field | Detail |
|-------|--------|
| **Owns** | Upgrade counts per type, FORGE_ZONE Area2D nodes (4 zones) |
| **Exposes** | Upgrade signals consumed by ArcherFormation and Castle |
| **Consumes** | `forge_upgrade_purchased(type)` from Economy; `session_restart` from GameStateMachine |
| **Engine APIs** | Area2D (FORGE_ZONEs — same as Economy zone pattern) |
| **ADR** | ADR-002 (zone Area2D) |

Alpha-tier system. Implementation deferred until archer + tower balance is tuned.
Session reset: upgrade counts return to 0 (upgrades are run-scoped, not persistent).

---

### Presentation Layer

#### HUD (`hud.gd`, `CanvasLayer`)

| Field | Detail |
|-------|--------|
| **Owns** | HUD display nodes (Label, ProgressBar, etc.) |
| **Exposes** | Nothing (output only) |
| **Consumes** | `gold_changed` from Economy; `hp_changed` from Castle; `wave_started` from EnemyWave; `current_archer_count` from ArcherFormation; `current_state` from GameStateMachine |
| **Engine APIs** | `CanvasLayer`, `Label`, `ProgressBar`, `AnimationPlayer` (HUD state transitions) ⚠️ AnimationPlayer MEDIUM risk |
| **ADR** | None yet — requires ADR-005 (HUD architecture) |

HUD visible only in PLAYING and WAVE_CLEAR states (GameStateMachine governs visibility).
CanvasLayer ensures HUD renders above world content regardless of camera position.

⚠️  **AnimationPlayer risk**: Godot 4.6 AnimationPlayer StringName changes (4.5 migration). Recommendation: use `Tween` for simple one-shot HUD animations instead of AnimationPlayer to avoid post-cutoff risk.

---

## Data Flow

### 1. Frame Update Path (60fps tick)

```
_input(event)
    └─ HeroMovement._handle_joystick_touch/drag(event)
            └─ updates _joystick_vector

_process(delta)
    │
    ├─ HeroMovement._process(delta)
    │    ├─ hero_pos += _joystick_vector * HERO_SPEED * delta
    │    ├─ facing_angle = updated from _joystick_vector
    │    └─ _shoot_timer -= delta
    │         └─ if ≤ 0: emit shoot_interval_tick; reset to SHOOT_IVTL
    │
    ├─ CameraFollow._process(delta)
    │    └─ global_position.lerp(hero.hero_pos, weight)  [ADR-004]
    │
    ├─ ArcherFormation._process(delta)
    │    ├─ compute slot world positions (hero_pos, facing_angle)
    │    ├─ lerp each archer toward slot [ADR-004]
    │    ├─ acquire shared_target (nearest enemy, HP > 0)
    │    └─ on shoot_interval_tick: fire_volley() → checkout from ArrowPool [ADR-003]
    │
    ├─ EnemyWave._process(delta)
    │    └─ per enemy: velocity = direction_to(castle_pos) × ENEMY_SPEED
    │
    └─ Economy._process(delta)  [zone dwell timers only]
         └─ if hero_inside_zone: _dwell_timer += delta → emit purchase signal
```

### 2. Event / Signal Path

```
Enemy contacts Castle (Area2D area_entered)
    └─ Castle.take_contact_damage()
            └─ current_hp -= CASTLE_DAMAGE_PER_CONTACT
            └─ emit hp_changed(current_hp) → HUD.update_castle_hp()
            └─ if current_hp ≤ 0: emit castle_destroyed
                    └─ GameStateMachine._on_castle_destroyed()
                            └─ transition to GAME_OVER
                            └─ emit game_over → ALL systems reset

Enemy dies (HP ≤ 0, arrow_hit)
    └─ EnemyWave._on_enemy_died(enemy)
            └─ emit enemy_died(enemy.global_position)
            └─ Economy._on_enemy_died(position)
                    └─ checkout coin from CoinPool [ADR-003]
                    └─ coin attracts to HeroMagnet [ADR-002]
                    └─ coin.collected: gold += GOLD_DROP_PER_ENEMY
                    └─ emit gold_changed(gold) → HUD.update_gold()

Zone dwell completed (0.8s in RECRUIT_ZONE)
    └─ Economy._on_dwell_completed(zone)
            └─ if gold >= cost: gold -= cost; emit recruit_purchased
            └─ ArcherFormation._on_recruit_purchased()
                    └─ fill lowest EMPTY slot → OCCUPIED
                    └─ if all 8 full: emit formation_full → HUD callout

tower_purchased event
    └─ Economy emits tower_purchased
    └─ ArcherTower._on_tower_purchased()
    └─ ArcherFormation._on_tower_purchased()
            └─ release 2 highest occupied slots → EMPTY
            └─ transfer 2 archer nodes to tower position
```

### 3. Session Reset Path

```
GameStateMachine receives castle_destroyed
    └─ transition: PLAYING → GAME_OVER
    └─ wait for restart trigger (player input or timer)
    └─ transition: GAME_OVER → SESSION_RESET
    └─ emit session_restart

session_restart received by ALL systems:
    ├─ Economy: gold = 60, dwell timers = 0, all zones reset
    ├─ ArcherFormation: slots 0-1 OCCUPIED, 2-7 EMPTY; _shoot_timer = 0
    ├─ EnemyWave: all enemies killed; _wave_index = 0; spawn timer reset
    ├─ Castle: current_hp = CASTLE_MAX_HP
    ├─ ObjectPoolManager._drain(): force-return all checked-out nodes [ADR-003]
    └─ HUD: reset all counters to initial values

GameStateMachine: SESSION_RESET → PLAYING
    └─ emit session_started
```

### 4. Initialization Order

```
Scene load (_ready() order by scene tree position):
  1. GameStateMachine (autoload — before scene loads)
  2. ObjectPoolManager (autoload — pre-allocates all pools)
  3. Castle._ready() — set up Area2D, HP initialized
  4. EnemyWave._ready() — connect to castle_pos; connect session_restart
  5. HeroMovement._ready() — initialize joystick state; facing_angle = π
  6. CameraFollow._ready() — set limits, position_smoothing_enabled = false [ADR-001]
  7. ArcherFormation._ready() — pre-place 2 starting archers; connect signals
  8. Economy._ready() — connect to hero zone Areas; connect enemy_died signal
  9. HUD._ready() — connect to Economy.gold_changed, Castle.hp_changed, etc.
  10. ArcherTower._ready() — connect to tower_purchased (if towers exist in scene)
  11. Forge._ready() — connect to forge_upgrade_purchased signals (Alpha)
```

---

## API Boundaries

### GameStateMachine Autoload API

```gdscript
# autoload/game_state_machine.gd
signal session_started
signal wave_started(wave_n: int)
signal wave_clear(wave_n: int, gold_bonus: int)
signal game_over
signal session_restart

enum GameState { LOADING, PLAYING, WAVE_CLEAR, GAME_OVER, SESSION_RESET }
var current_state: GameState = GameState.LOADING  # read-only externally

# Called by Castle when HP reaches 0
func _on_castle_destroyed() -> void: ...

# Called by EnemyWave when last enemy dies
func _on_wave_complete(wave_n: int) -> void: ...
```

### HeroMovement Public API

```gdscript
# src/hero/hero_movement.gd
var hero_pos: Vector2  # read each frame by Camera, ArcherFormation, Economy
var facing_angle: float  # read each frame by ArcherFormation

signal shoot_interval_tick  # emitted every SHOOT_IVTL = 0.9s

const HERO_SPEED: float = 240.0
const SHOOT_IVTL: float = 0.9
```

### Economy Public API

```gdscript
# src/economy/economy.gd
var gold: int  # read by HUD; modified internally only

signal gold_changed(new_gold: int)
signal recruit_purchased
signal tower_purchased
signal forge_upgrade_purchased(upgrade_type: StringName)
```

### ArcherFormation Public API

```gdscript
# src/archer/archer_formation.gd
var current_archer_count: int  # read by Economy (cost tier), HUD

signal formation_full

# Called when tower_purchased signal is received
func _on_tower_purchased() -> void:
    # releases TOWER_ARCHERS_COUNT slots from the highest occupied pair
    ...
```

### Castle Public API

```gdscript
# src/castle/castle.gd
var current_hp: int  # read by HUD

signal hp_changed(new_hp: int)
signal castle_destroyed

# Called by enemy Area2D overlap (area_entered)
func take_contact_damage() -> void:
    current_hp -= CASTLE_DAMAGE_PER_CONTACT
    emit_signal("hp_changed", current_hp)
    if current_hp <= 0 and not _castle_destroyed_emitted:
        _castle_destroyed_emitted = true
        emit_signal("castle_destroyed")
```

### ObjectPoolManager Autoload API (ADR-003)

```gdscript
# autoload/object_pool_manager.gd
var arrow_pool: _NodePool   # 24 Arrow nodes
var impact_pool: _NodePool  # 8 GPUParticles2D nodes
var coin_pool: _NodePool    # 16 Coin nodes

# checkout() → Node | null (null = pool starved, log warning, skip spawn)
# return_node(node: Node) → void (disables CollisionShape2D, hides, resets)

# Called on session_restart to force-return all checked-out nodes
func _drain() -> void: ...
```

---

## ADR Audit

| ADR | Engine Compat | Version Stamped | GDD Linkage | Layer Conflicts | Valid |
|-----|--------------|-----------------|-------------|-----------------|-------|
| ADR-001: Viewport Resolution | ✅ | ✅ 4.6 | ✅ camera.md, hero-movement.md, hud.md | None | ✅ |
| ADR-002: Physics Policy | ✅ | ✅ 4.6 | ✅ economy.md, archer-formation.md, castle.md | None | ✅ |
| ADR-003: Object Pool | ✅ | ✅ 4.6 | ✅ archer-formation.md, economy.md | None | ✅ |
| ADR-004: Lerp Formula | ✅ | ✅ 4.6 | ✅ camera.md, archer-formation.md | None | ✅ |

All 4 existing ADRs have Engine Compatibility sections, version stamps, GDD linkage, and no architectural conflicts. No deprecated APIs used.

---

## Traceability Matrix

| Req ID | Requirement | ADR / Architecture Coverage | Status |
|--------|-------------|------------------------------|--------|
| TR-gsm-001 | Game State Machine (5-state FSM, global) | ADR-005 (Accepted 2026-05-19) | ✅ |
| TR-gsm-002 | session_started/wave_started/game_over/session_restart signals | Architecture Data Flow §3 + ADR-005 | ✅ |
| TR-hero-001 | Fixed-anchor virtual joystick | Architecture Module Ownership (HeroMovement) + ADR-005 | ✅ |
| TR-hero-002 | hero_pos, facing_angle per-frame readable | Architecture API Boundaries (HeroMovement) | ✅ |
| TR-hero-003 | SHOOT_IVTL shared timer tick | Architecture API Boundaries | ✅ |
| TR-cam-001 | Frame-rate-independent lerp 0.10 | ADR-004 | ✅ |
| TR-cam-002 | World bounds constraint | ADR-001 | ✅ |
| TR-castle-001 | Area2D enemy contact → damage | ADR-002 | ✅ |
| TR-castle-002 | castle_destroyed signal | Architecture API Boundaries | ✅ |
| TR-wave-001 | 13-wave parameterized spawn | Architecture Module Ownership (EnemyWave) | ✅ |
| TR-wave-002 | direction_to steering, no NavMesh | ADR-006 (Accepted 2026-05-19) | ✅ |
| TR-wave-003 | enemy_died(position) signal | Architecture API Boundaries | ✅ |
| TR-eco-001 | Zone dwell trigger (0.8s) Area2D | ADR-002 | ✅ |
| TR-eco-002 | Gold magnet Area2D r=170px | ADR-002 | ✅ |
| TR-eco-003 | Deterministic costs | Architecture Module Ownership (Economy) | ✅ |
| TR-eco-004 | session_restart resets gold | Architecture Data Flow §3 + ADR-005 | ✅ |
| TR-form-001 | 8-slot V-formation per-frame | Architecture Module Ownership (ArcherFormation) | ✅ |
| TR-form-002 | Object pools 24 arrows + 8 impacts + 30 enemies | ADR-003 + ADR-006 | ✅ |
| TR-form-003 | tower_purchased releases 2 slots | Architecture Data Flow §2 + API Boundaries | ✅ |
| TR-form-004 | Lerp 0.12 archer follow | ADR-004 | ✅ |
| TR-hud-001 | CanvasLayer HUD | ADR-007 (Accepted 2026-05-19) | ✅ |
| TR-hud-002 | HUD visible in PLAYING/WAVE_CLEAR only | Architecture Data Flow §2 + ADR-005 | ✅ |
| TR-tower-001 | Slot-release R3 contract | Architecture API Boundaries (ArcherFormation) | ✅ |
| TR-tower-002 | Tower independent fire timer | Architecture Module Ownership (ArcherTower) | ✅ |
| TR-forge-001 | 4 spatial FORGE_ZONEs | Architecture Module Ownership (Forge) | ✅ |
| TR-forge-002 | PROJ_DAMAGE_UP / SHOOT_IVTL_DOWN signals | Architecture Module Ownership (Forge) | ✅ |

**Summary**: 26/26 covered. 0 gaps. ADR-005–009 resolved all prior gaps (updated 2026-05-19).

---

## Required ADRs

### Foundation Layer — Must Exist Before Coding Starts

**ADR-005: Game State Machine and Autoload Architecture**
- Defines: autoload singleton pattern, Godot 4.6 autoload configuration, signal routing from GSM to all systems, initialization order, scene tree structure.
- Covers: TR-gsm-001, TR-hero-001 (joystick input integrated into Hero Movement module, loaded in scene not autoload)
- Blocks: any code that calls `GameStateMachine.*` or connects to GSM signals

**ADR-006: Enemy Pathfinding (MVP — direction_to, No NavMesh)**
- Defines: steering behavior (`direction_to(castle_pos) × ENEMY_SPEED`), enemy group composition, no-avoidance policy for MVP, NavigationAgent2D deferral to Alpha/post-MVP.
- Also defines: enemy node pool (recommend 30 nodes; currently unaddressed by ADR-003).
- Covers: TR-wave-002; enemy pool gap identified in this document.
- Blocks: EnemyWave implementation.

**ADR-007: Scene Architecture — Main Scene and HUD Layout**
- Defines: main scene structure (world root + CanvasLayer for HUD), scene loading pattern (single main scene in MVP — no scene transitions except for loading screen), CanvasLayer z-index for HUD above world, node naming conventions for scene references.
- Covers: TR-hud-001; addresses how the HUD CanvasLayer integrates with the game world scene.
- Blocks: HUD implementation; scene organization.

### Core Layer — Should Exist Before System Is Built

**ADR-008: Audio Architecture (Non-Positional, MVP)**
- Defines: `AudioStreamPlayer` (non-positional), no spatial audio, no reverb bus in MVP, volume scaling pattern for volley audio (`lerp(-6.0, 0.0, (n-2)/6.0)`), audio manager pattern or direct node references.
- Blocks: audio implementation in ArcherFormation (sfx_volley_fire, sfx_archer_recruit), Castle, EnemyWave.

**ADR-009: Session Persistence (MVP — No Save)**
- Defines: session-only state (all game state resets on session_restart), no file persistence in MVP, high-score display (transient, not written to disk), `FileAccess` deferral to post-MVP.
- Clarifies scope: prevents programmers from implementing save/load prematurely.

### Can Defer to Implementation

- **Forge zone state machine** — Alpha tier, document when Forge enters production sprint.
- **Tower arrow pool extension** — Extend ADR-003 at tower implementation time.

---

## Open Questions

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | Enemy pool: 30 nodes is an estimate — validate against 13-wave session profiling | Medium | ADR-006 + first performance profile run |
| QQ-02 | Tower arrow pool: ADR-003 sizes for formation only; tower adds up to N arrow/sec — pool formula needs update | Medium | Update ADR-003 when ArcherTower is implemented |
| QQ-03 | AnimationPlayer StringName changes (4.5 HIGH risk) — HUD animations should use Tween instead | Medium | ADR-007 (HUD arch) to mandate Tween for HUD transitions |
| QQ-04 | GPUParticles2D `restart()` and `one_shot` behavior in 4.6 — verify on first engine run | High | Verify in first engine integration test before implementing VFX |
| QQ-05 | Forge Alpha scope: upgrade deltas (PROJ_DAMAGE +2, SHOOT_IVTL -0.10s) — validate before Alpha sprint | Low | forge.md acceptance criteria + balance playtest |
| QQ-06 | HeroMovement speed: 240px/s in current GDD vs 200px/s in prototype. Prototype value validated — GDD may have been updated. Confirm authoritative value. | Medium | Cross-check hero-movement.md and reconcile with entities.yaml |
