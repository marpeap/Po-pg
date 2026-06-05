# ADR-005: Game State Machine and Autoload Architecture

## Status

Accepted

## Date

2026-05-19

## Last Verified

2026-05-19

## Decision Makers

Technical setup — Garrison project (Sonnet 4.6)

## Summary

Garrison requires a globally accessible 5-state FSM that any system can query and
connect to for state-change signals. We implement it as a **Godot autoload singleton**
(`GameStateMachine`) using a typed `enum` state and Godot signals for broadcast. All
other systems connect to its signals in their own `_ready()` — the GSM never holds
references to other systems.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — Godot autoload pattern and `SceneTree` signals are stable since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm autoload registers before any scene node's `_ready()` fires — standard Godot behavior, verify on first run |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — Foundation L0 |
| **Enables** | All systems that connect to `game_over`, `session_restart`, `wave_started`, `wave_clear` |
| **Blocks** | Every system that references `GameStateMachine.*`; Scene Architecture ADR-007 |
| **Ordering Note** | Must be Accepted first in the Foundation layer |

## Context

### Problem Statement

10 systems need to react to state changes (game over, session restart, wave clear).
Without a centralized authority, each system must know about every other system —
creating tight coupling. Garrison's "one joystick, zero friction" pillar requires
state to flow outward from one source, not be negotiated between peers.

### Current State

No state machine exists. Systems have no mechanism to synchronize on session start,
game over, or wave transitions.

### Constraints

- GDScript only — no C++ extensions
- Single-player, single-threaded — no concurrency concerns
- All systems are nodes in the same SceneTree
- Godot 4.6 autoloads register before any scene `_ready()` fires — guaranteed

### Requirements

- GSM state readable by any system at any time (`current_state` property)
- State-change signals broadcast to all listeners without the GSM knowing about them
- GSM must not hold direct references to other game systems (one-way dependency)
- Transitions must be explicit and guarded — no invalid transitions allowed
- Session restart must trigger a full-state reset broadcast in one signal

## Decision

**Pattern**: Autoload singleton with typed enum state and Godot signals.

**States:**

```
LOADING → SESSION_RESET → PLAYING ↔ WAVE_CLEAR
                                  ↓ (castle_destroyed)
                              GAME_OVER → SESSION_RESET
```

| State | Meaning |
|-------|---------|
| `LOADING` | Scene is loading; no gameplay |
| `SESSION_RESET` | Transition state: all systems resetting before a new run |
| `PLAYING` | Active wave; enemies spawning, hero moving |
| `WAVE_CLEAR` | Wave complete; brief pause for spending decisions |
| `GAME_OVER` | Castle destroyed; run ended; waiting for restart input |

**Autoload registration**: Add `GameStateMachine` to Project Settings → Autoloads → path `res://autoload/game_state_machine.gd`. Name `GameStateMachine`. This makes it accessible as `GameStateMachine` from any script.

**Dependency direction (critical):**

```
[All Game Systems] → connect signals → [GameStateMachine]
                   ← read state ←

GameStateMachine NEVER holds references to other systems.
GameStateMachine NEVER calls methods on other systems.
Communication is signal-only, one direction: GSM broadcasts, systems listen.
```

### Architecture

```
autoload/game_state_machine.gd  (registered as "GameStateMachine")
        │
        ├─ current_state: GameState  (readable by all)
        │
        ├─ Inbound (systems tell GSM what happened):
        │   ├─ _on_castle_destroyed()  ← Castle.castle_destroyed signal
        │   └─ _on_wave_complete(n)    ← EnemyWave.wave_complete signal
        │
        └─ Outbound (GSM tells world what state changed):
            ├─ signal session_started
            ├─ signal wave_started(wave_n: int)
            ├─ signal wave_clear(wave_n: int)
            ├─ signal game_over
            └─ signal session_restart
```

### Key Interfaces

```gdscript
# autoload/game_state_machine.gd
extends Node

enum GameState {
    LOADING,
    SESSION_RESET,
    PLAYING,
    WAVE_CLEAR,
    GAME_OVER
}

signal session_started
signal wave_started(wave_n: int)
signal wave_clear(wave_n: int)
signal game_over
signal session_restart

var current_state: GameState = GameState.LOADING

func _ready() -> void:
    # GSM connects to Castle and EnemyWave in _ready().
    # These are the only two outbound references — necessary to receive
    # state-change notifications. All other systems connect TO the GSM,
    # not the reverse.
    # Connection pattern: find nodes by group rather than path, for resilience.
    pass  # actual connection deferred until scene is ready via call_deferred

# --- Inbound: called by systems to notify GSM ---

func notify_castle_destroyed() -> void:
    if current_state == GameState.PLAYING or current_state == GameState.WAVE_CLEAR:
        _transition(GameState.GAME_OVER)

func notify_wave_complete(wave_n: int) -> void:
    if current_state == GameState.PLAYING:
        _transition(GameState.WAVE_CLEAR)
        emit_signal("wave_clear", wave_n)

func notify_wave_start(wave_n: int) -> void:
    if current_state == GameState.WAVE_CLEAR or current_state == GameState.SESSION_RESET:
        _transition(GameState.PLAYING)
        emit_signal("wave_started", wave_n)

func request_restart() -> void:
    # Called by restart UI or auto-restart timer after GAME_OVER
    if current_state == GameState.GAME_OVER:
        _transition(GameState.SESSION_RESET)
        emit_signal("session_restart")
        # Brief deferred transition to PLAYING after all systems have reset
        call_deferred("_begin_session")

# --- Private transitions ---

func _transition(new_state: GameState) -> void:
    current_state = new_state
    if new_state == GameState.GAME_OVER:
        emit_signal("game_over")

func _begin_session() -> void:
    _transition(GameState.PLAYING)
    emit_signal("session_started")
    notify_wave_start(1)  # Always begins at wave 1
```

```gdscript
# How any system connects to the GSM (in _ready()):
func _ready() -> void:
    GameStateMachine.session_restart.connect(_on_session_restart)
    GameStateMachine.game_over.connect(_on_game_over)

func _on_session_restart() -> void:
    # Reset this system's state
    pass

func _on_game_over() -> void:
    # Pause/freeze this system
    pass
```

```gdscript
# How Castle notifies the GSM (replaces direct signal connection):
func _on_castle_hp_zero() -> void:
    GameStateMachine.notify_castle_destroyed()
```

### Implementation Guidelines

1. **Register as autoload in Project Settings** — path `res://autoload/game_state_machine.gd`,
   name `GameStateMachine`. This must be done before running the project.

2. **GSM never calls other systems directly.** It emits signals; systems opt-in by connecting
   in their own `_ready()`. No circular dependencies.

3. **Guard all transitions.** `_transition()` must check that the incoming state is a valid
   transition from `current_state`. Invalid transition = push_warning + return (no crash).

4. **SESSION_RESET is a transient state** — no system should stay in SESSION_RESET. After
   `session_restart` is emitted and `call_deferred("_begin_session")` fires, all systems have
   had one frame to process their reset. PLAYING begins after that frame.

5. **ObjectPoolManager** (ADR-003 autoload) must also register in Project Settings and
   connect to `session_restart` to call its `_drain()` method.

6. **Autoload order**: In Project Settings, register `GameStateMachine` BEFORE `ObjectPoolManager`.
   GSM must exist before any scene node tries to connect to it.

7. **Group-based notification**: Castle and EnemyWave call `GameStateMachine.notify_*()` methods
   directly (not via signal). This is explicit and auditable. Alternative (connecting GSM to
   Castle's `castle_destroyed` signal in `_ready()`) is also valid but requires GSM to hold a
   reference to Castle — acceptable only for these two root-level nodes.

## Alternatives Considered

### Alternative 1: Event Bus (pure signal relay)

- **Description**: A global autoload that only relays signals — any system can emit any event,
  any system can listen. No state machine, no enum.
- **Pros**: Maximum decoupling. No central authority.
- **Cons**: No authoritative state — any system can query "are we in GAME_OVER?" but the answer
  is computed from signal history, not from a single source of truth. Debugging state bugs
  requires tracing signal chains. For Garrison's simple 5-state machine, this adds complexity
  with no benefit.
- **Rejection Reason**: Authoritative state query (`current_state`) is required for HUD visibility
  gating, zone activation rules, and session_restart coordination.

### Alternative 2: State stored in each system independently

- **Description**: Each system tracks its own "am I active?" boolean. No global state.
- **Pros**: No autoload. Each system is self-contained.
- **Cons**: "Game over" requires sending a broadcast to every system. Adding a new system
  requires wiring it into the broadcast manually. State divergence risk (two systems disagree
  on whether it's GAME_OVER).
- **Rejection Reason**: 10 systems × 5 state transitions = 50 wiring points. Error-prone.
  Garrison's small scope makes a central FSM straightforward and low-risk.

## Consequences

### Positive

- Single source of truth for game state — any system can query `GameStateMachine.current_state`
- Adding a new system: connect to GSM signals in `_ready()` — zero changes to GSM
- State transitions are explicit, guarded, and in one file

### Negative

- Autoload creates an implicit global dependency — test isolation requires mocking GSM
- Invalid transition bugs (e.g. calling `notify_castle_destroyed` during LOADING) produce
  silent warnings unless the guard is checked

### Neutral

- 2 systems (Castle, EnemyWave) actively notify GSM; all others are passive listeners

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| GSM connects to Castle/EnemyWave before they exist in scene | Low | Medium | Use `call_deferred` or connect in the scene's `_ready()` after all nodes exist |
| Autoload order wrong (ObjectPoolManager before GSM) | Low | Medium | Document order in Project Settings; verify on first run |
| `session_restart` signal fires before some systems have connected | Low | Low | All systems connect in `_ready()`; GSM emits `session_restart` after `call_deferred` → one frame after all `_ready()` calls |

## Performance Implications

Negligible — signal emission with 8–10 listeners costs microseconds.

## Migration Plan

No existing state machine. Initial setup:

1. Create `autoload/game_state_machine.gd`
2. Register in Project Settings → Autoloads (first entry, before ObjectPoolManager)
3. Connect Castle's HP-zero handler to `GameStateMachine.notify_castle_destroyed()`
4. Connect EnemyWave's wave-complete handler to `GameStateMachine.notify_wave_complete(n)`
5. All other systems: connect to GSM signals in `_ready()`

## Validation Criteria

- [ ] `GameStateMachine.current_state` is accessible from any script without `get_node()`
- [ ] `current_state == GameState.PLAYING` during an active wave
- [ ] `game_over` signal fires exactly once per castle destruction (one-shot guard)
- [ ] `session_restart` signal fires when `request_restart()` is called after GAME_OVER
- [ ] `session_restart` followed by `session_started` fires in the correct order (same frame or deferred)
- [ ] Invalid transition (castle_destroyed during LOADING) produces a warning, not a crash

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/game-state.md` | Game State Machine | 5-state FSM (LOADING/SESSION_RESET/PLAYING/WAVE_CLEAR/GAME_OVER) globally accessible | Implemented as Godot autoload singleton with enum and properties |
| `design/gdd/game-state.md` | Game State Machine | `game_over`, `session_restart`, `wave_clear`, `session_started` signals broadcast | Defined as Godot signals on the autoload; all systems connect in `_ready()` |
| `design/gdd/economy.md` | Economy | Session reset returns gold to 60g | Economy connects to `session_restart` signal in `_ready()` |
| `design/gdd/archer-formation.md` | Archer Formation | Session reset clears slots to STARTING_ARCHERS=2 | ArcherFormation connects to `session_restart` signal |
| `design/gdd/castle.md` | Castle | `castle_destroyed` triggers game over | Castle calls `GameStateMachine.notify_castle_destroyed()` |

## Related

- ADR-003 — ObjectPoolManager autoload must connect to `session_restart` for `_drain()`
- ADR-007 — Scene Architecture depends on GSM state for HUD visibility gating
- `docs/architecture/architecture.md` — Module Ownership: GameStateMachine section
