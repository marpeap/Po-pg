# Story C01-S01: Gold Economy + Coin Pool + Magnet Collect

> **Epic**: EPIC-C01 Economy System
> **Status**: Not Started
> **Type**: Logic + Integration
> **Test Evidence Required**: Unit test for formulas — BLOCKING; Integration test for drop+collect — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-economy-001
> **ADR Refs**: ADR-002, ADR-003, ADR-005

## What to Build

`src/gameplay/economy.gd` — gold counter, coin pool (16 nodes), drop on enemy_died, magnet collect.

### Gold Management

```gdscript
signal gold_changed(new_gold: int)

var current_gold: int = 60
const STARTING_GOLD := 60
const MAGNET_R := 170.0

func add_gold(amount: int) -> void:
    current_gold = max(current_gold + amount, 0)
    gold_changed.emit(current_gold)

func spend_gold(amount: int) -> bool:
    if current_gold < amount: return false
    current_gold -= amount
    gold_changed.emit(current_gold)
    return true
```

### Coin Pool + Drop

```gdscript
# On enemy_died(pos) signal:
func _on_enemy_died(pos: Vector2) -> void:
    var wave_gold: int = # current wave's gold_value
    # Drop 1 coin with full gold value at pos (simplified vs. 1-3 split)
    var coin = _coin_pool.checkout()
    if coin == null: return
    coin.activate(pos, wave_gold)
```

### Magnet Logic (per-frame)

```gdscript
func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING: return
    for coin in _coin_pool.all_active():
        var dist: float = coin.position.distance_to(_hero.position)
        if dist <= MAGNET_R:
            # Move coin toward hero
            coin.position = coin.position.move_toward(_hero.position, 400.0 * delta)
            if dist <= 12.0:  # Collect radius
                add_gold(coin.gold_value)
                _coin_pool.return(coin)
```

### Session Reset

- `current_gold = STARTING_GOLD`
- Return all coins to pool
- Emit `gold_changed(STARTING_GOLD)`

## Acceptance Criteria

- [ ] Session starts with 60g
- [ ] Coins spawn at enemy death position
- [ ] Coins move toward hero when within 170px
- [ ] Collecting a coin adds its gold_value to `current_gold` and emits `gold_changed`
- [ ] `current_gold` never goes below 0 (spend_gold returns false if insufficient)
- [ ] Coin pool never instantiates during gameplay — pre-allocated 16 nodes
- [ ] Session reset: gold = 60, all coins returned to pool

## Test File

`tests/unit/gameplay/economy_gold_test.gd`

Test cases:
- `test_starts_at_60_gold`
- `test_add_gold_emits_signal`
- `test_spend_gold_returns_false_if_insufficient`
- `test_spend_gold_never_below_zero`
- `test_gold_changed_signal_value_correct`
- `test_session_reset_restores_60_gold`
