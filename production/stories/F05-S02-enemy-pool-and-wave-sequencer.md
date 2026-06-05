# Story F05-S02: Enemy Pool + Wave Sequencer + Signals

> **Epic**: EPIC-F05 Enemy Wave System
> **Status**: Not Started
> **Type**: Integration
> **Test Evidence Required**: Integration test — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-enemy-002, TR-wave-001
> **ADR Refs**: ADR-003, ADR-005, ADR-006

## What to Build

`src/gameplay/enemy_wave.gd` — enemy pool (30 nodes), wave sequencer, spawn timer, signals.

### Wave Table

```gdscript
const WAVE_TABLE: Array[Dictionary] = [
    { "count": 5,  "hp": 30, "speed": 70.0, "gold": 15 },  # Wave 1
    { "count": 8,  "hp": 40, "speed": 75.0, "gold": 15 },  # Wave 2
    { "count": 12, "hp": 50, "speed": 80.0, "gold": 18 },  # Wave 3
    { "count": 16, "hp": 60, "speed": 85.0, "gold": 18 },  # Wave 4
    { "count": 20, "hp": 80, "speed": 90.0, "gold": 20 },  # Wave 5
]

const INTER_WAVE_PAUSE := 10.0
const SPAWN_IVTL := 0.5  # seconds between each enemy spawn within a wave
```

### Signals

```gdscript
signal wave_started(wave_number: int)
signal wave_cleared

var current_wave: int = 0
var total_kills: int = 0  # Running counter for GAME_OVER stats
var _active_enemies: int = 0
var _spawned_this_wave: int = 0
var _inter_wave_timer: float = 0.0
var _spawn_timer: float = 0.0
```

### Spawn Logic

```gdscript
func _spawn_enemy() -> void:
    var node = _pool.checkout()
    if node == null: return  # pool exhausted — skip spawn (log warning)
    var wave_data = WAVE_TABLE[current_wave]
    var spawn_pos = _random_spawn_pos()  # off-screen bottom edge
    node.activate(spawn_pos, wave_data.hp, wave_data.speed, wave_data.gold)
    node.enemy_died.connect(_on_enemy_died.bind(node))
    _active_enemies += 1
    _spawned_this_wave += 1

func _on_enemy_died(pos: Vector2, node: Node) -> void:
    total_kills += 1
    _active_enemies -= 1
    _pool.return(node)
    if _active_enemies == 0 and _spawned_this_wave >= WAVE_TABLE[current_wave].count:
        wave_cleared.emit()
```

### Spawn Position

Enemies spawn along the bottom edge of the world (y = 1920), distributed across x = 50–1030.
Use randomized x positions with minimum spacing to avoid spawning on top of each other.

### Session Reset

```gdscript
func _on_session_reset() -> void:
    # Drain all active enemies back to pool
    for e in _pool.all_active():
        e.deactivate()
        _pool.return(e)
    current_wave = 0
    total_kills = 0
    _active_enemies = 0
    _spawned_this_wave = 0
    _inter_wave_timer = 0.0
    _start_wave(0)  # Begin wave 1
```

## Acceptance Criteria

- [ ] Wave 1 starts on session start with 5 enemies
- [ ] Enemies spawn with 0.5s spacing (not all at once)
- [ ] `wave_started(1)` fires when wave 1 begins
- [ ] `wave_cleared` fires when last enemy in wave dies
- [ ] After `wave_cleared`: 10.0s pause, then `wave_started(2)` fires and next wave begins
- [ ] Wave 5 completes: `wave_cleared` fires, no wave 6 starts (game proceeds to GAME_OVER victory context or continues until castle falls)
- [ ] `total_kills` increments by 1 for each enemy death
- [ ] Enemy pool never instantiates during gameplay
- [ ] Session reset: all enemies deactivated, wave counter reset to 0, wave 1 restarts

## Test File

`tests/integration/enemy_wave_integration_test.gd`

Test cases:
- `test_wave_1_spawns_correct_count`
- `test_wave_started_signal_fires`
- `test_wave_cleared_when_all_dead`
- `test_inter_wave_pause_before_next_wave`
- `test_total_kills_increments`
- `test_session_reset_clears_enemies`
