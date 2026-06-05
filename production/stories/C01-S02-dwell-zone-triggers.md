# Story C01-S02: Dwell Zone Triggers (RECRUIT_ZONE + TOWER_ZONE)

> **Epic**: EPIC-C01 Economy System
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Unit test for dwell logic — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-economy-002
> **ADR Refs**: ADR-002, ADR-005

## What to Build

Dwell zone system within `economy.gd`: proximity detection, dwell timer, affordability check, purchase signals, dwell arc visual.

### Dwell Zone Data

```gdscript
const ZONE_RADIUS := 55.0
const DWELL_TIME := 0.8

const RECRUIT_ZONE_POS := Vector2(135.0, 490.0)
const TOWER_ZONE_POS := Vector2(810.0, 490.0)  # TBD exact position

const ARCHER_COST_T1 := 30
const ARCHER_COST_T2 := 60
const TOWER_COST := 100
```

### Zone Logic Per Frame

```gdscript
signal recruit_purchased
signal tower_purchased

var _recruit_dwell: float = 0.0
var _tower_dwell: float = 0.0

func _process(delta: float) -> void:
    _update_zone(_hero.position, RECRUIT_ZONE_POS, _recruit_dwell,
                 _get_recruit_cost(), delta, "recruit")
    _update_zone(_hero.position, TOWER_ZONE_POS, _tower_dwell,
                 TOWER_COST, delta, "tower")

func _update_zone(hero_pos, zone_pos, dwell_ref, cost, delta, zone_id):
    var dist = hero_pos.distance_to(zone_pos)
    if dist <= ZONE_RADIUS and current_gold >= cost:
        dwell_ref += delta
        if dwell_ref >= DWELL_TIME:
            _execute_purchase(zone_id, cost)
            dwell_ref = 0.0
    else:
        dwell_ref = 0.0  # No partial carry on exit (GDD R7)

func _get_recruit_cost() -> int:
    return ARCHER_COST_T1 if _current_archer_count < 4 else ARCHER_COST_T2
```

### Visual Feedback

In `_draw()` (or a dedicated zone node):
- Available zone: pulsing green circle at zone position (pulse driven by `Time.get_ticks_msec()`)
- Dwell arc: draw clockwise arc from 12 o'clock, progress = dwell/DWELL_TIME
- Unavailable (can't afford): muted grey static circle
- No pulse, no arc when `_recruited_full` (all 8 slots filled, no tower remaining)

## Acceptance Criteria

- [ ] Hero entering RECRUIT_ZONE while having ≥ ARCHER_COST fills a dwell arc over 0.8s
- [ ] At 0.8s dwell: `recruit_purchased` fires, gold deducted, arc resets
- [ ] Exiting zone before 0.8s resets arc to 0 (no partial carry)
- [ ] Zone shows muted grey when `current_gold < cost`
- [ ] Zone shows green pulse when `current_gold >= cost`
- [ ] TOWER_ZONE has identical dwell logic at 100g cost
- [ ] Session reset: all dwell timers = 0

## Test File

`tests/unit/gameplay/economy_dwell_test.gd`

Test cases:
- `test_dwell_fires_at_0_8s`
- `test_dwell_resets_on_exit`
- `test_no_purchase_if_insufficient_gold`
- `test_gold_deducted_on_purchase`
- `test_recruit_purchased_signal_fires`
- `test_dwell_cost_tier1_vs_tier2`
