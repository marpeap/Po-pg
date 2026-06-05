# EPIC-C01: Economy System

> **Layer**: Core (L3)
> **Status**: Not Started
> **Priority**: HIGH — gold collection + zone dwell = Pillar 2 "Chaque pièce d'or est une décision"
> **GDD Source**: `design/gdd/economy.md`
> **Governing ADRs**: ADR-002 (Area2D), ADR-003 (coin pool), ADR-005 (GSM)
> **Engine Risk**: LOW

---

## Summary

Implement the gold economy: coins drop on enemy death, a magnet radius auto-collects coins
near the hero, a RECRUIT_ZONE dwell trigger (0.8s) recruits archers, and a TOWER_ZONE
dwell trigger purchases Archer Towers. This epic is the spatial decision-making system —
the mechanic that makes the game a strategy.

---

## Scope

### In Scope

- `src/gameplay/economy.gd` — gold counter, coin pool, magnet logic, dwell zones
- Gold coin pool: 16 pre-allocated Area2D nodes (ADR-003)
- Coin drop on `enemy_died(pos)` signal: 1–3 coins at enemy death position (gold_drop per wave table from EPIC-F05)
- Magnet radius: `MAGNET_R = 170.0 px` — coins within range fly toward hero, collected on contact
- `gold_changed(new_gold: int)` signal on every gold change
- `recruit_purchased` signal when archer is successfully recruited
- `RECRUIT_ZONE` dwell trigger: position `(135, 490)`, radius 55px, dwell time 0.8s
- `TOWER_ZONE` dwell trigger: position TBD per map design, radius 55px, dwell time 0.8s
- Archer costs: `ARCHER_COST_T1 = 30g` (archers 1–4), `ARCHER_COST_T2 = 60g` (archers 5–8)
- Tower cost: `TOWER_COST = 100g`
- Zone dwell arc feedback: drawn in world space via `_draw()` (fills clockwise on dwell)
- Zone available pulse: drawn as pulsing circle when `current_gold >= cost`
- Zone unavailable: muted grey static circle
- Starting gold: 60g (`STARTING_GOLD = 60`)
- Session reset: `current_gold = STARTING_GOLD`, drain all coins, reset dwell timers

### Dwell Zone Logic

```
On hero enter zone:
  Start dwell timer (0.0 → DWELL_TIME)
On hero stays in zone each frame:
  Advance dwell timer by delta
  If dwell_timer >= DWELL_TIME AND current_gold >= cost AND can_recruit:
    Deduct cost from current_gold
    Emit recruit_purchased / tower_purchased
    Reset dwell_timer = 0
On hero exit zone (before completion):
  Reset dwell_timer = 0  # No partial carry (GDD R7)
```

### Out of Scope

- Forge zones (Alpha — EPIC-FT02)
- Gold-sink beyond archers + towers (Alpha)
- Archer Tower construction visual (EPIC-FT01)

---

## Dependencies

- EPIC-F01 (GSM — session_reset)
- EPIC-F02 (Hero — hero position for zone proximity + magnet)
- EPIC-F05 (Enemy Wave — enemy_died signal for coin drop)

---

## Unblocks

- EPIC-C02 (Archer Formation — triggered by recruit_purchased signal)
- EPIC-FT01 (Archer Tower — triggered by tower_purchased signal)
- EPIC-P01 (HUD — needs gold_changed signal and affordability check)

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `STARTING_GOLD` | 60 | economy.md |
| `MAGNET_R` | 170.0 | economy.md |
| `DWELL_TIME` | 0.8 | economy.md |
| `ZONE_RADIUS` | 55.0 | economy.md |
| `RECRUIT_ZONE_POS` | `Vector2(135, 490)` | economy.md |
| `ARCHER_COST_T1` | 30 | economy.md |
| `ARCHER_COST_T2` | 60 | economy.md |
| `TOWER_COST` | 100 | economy.md |

---

## Key Acceptance Criteria

- [ ] Coins spawn at enemy death position and move toward hero when within 170px
- [ ] Collected coins increment `current_gold` and emit `gold_changed`
- [ ] RECRUIT_ZONE dwell arc fills over 0.8s when hero is inside zone
- [ ] On dwell completion: gold is deducted, `recruit_purchased` fires, arc resets
- [ ] Exiting zone before 0.8s resets arc to 0 (no partial carry)
- [ ] Zone shows available pulse when `current_gold >= ARCHER_COST`; shows muted grey when not affordable
- [ ] `current_gold` never goes below 0 (Economy enforces non-negative)
- [ ] Coin pool never instantiates nodes during gameplay
- [ ] Session reset: gold = 60, all coins removed, dwell timers = 0

---

## Control Manifest Notes

- Area2D for coins and zone triggers
- Coin pool: pre-allocate 16 in `_ready()`, disable CollisionShape2D on return
- No body_entered signal — use area_entered (Area2D-to-Area2D)
