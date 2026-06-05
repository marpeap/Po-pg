# EPIC-FT01: Archer Tower System

> **Layer**: Feature (L4)
> **Status**: Not Started
> **Priority**: HIGH (MVP) — resolves gold sink gap; D-01 design decision
> **GDD Source**: `design/gdd/archer-tower.md`
> **Governing ADRs**: ADR-002 (Area2D), ADR-003 (arrow pool shared), ADR-005 (GSM)
> **Engine Risk**: LOW

---

## Summary

Implement the Archer Tower: a fixed map structure that fires arrows at enemies, purchased
via TOWER_ZONE dwell trigger (100g). Towers permanently occupy a map slot and fire
independently at fixed range. This epic resolves the "gold runs out after 8 archers"
design gap — towers provide an ongoing gold sink past max formation.

---

## Scope

### In Scope

- `src/gameplay/archer_tower.gd` — static Node2D, auto-fire toward nearest enemy, range-limited
- TOWER_ZONE dwell trigger handling (via Economy TOWER_ZONE `tower_purchased` signal)
- Tower fire rate: same `SHOOT_IVTL = 1.2s` as formation archers
- Tower damage: `TOWER_PROJ_DAMAGE = 8` (same as archer arrows — uses same arrow pool)
- Tower range: `TOWER_RANGE = 350.0 px` (slightly more than archer SHOOT_RANGE = 300px)
- Tower cost: 100g (defined in Economy — TOWER_COST)
- Maximum towers: 2 in MVP (map has 2 TOWER_ZONEs)
- Tower visual: static square structure `#2A5FC9` (Royal Blue) at zone position
- Tower fires from own position toward nearest enemy within range
- Arrow pool shared with Archer Formation (arrows come from same 24-node pool — EPIC-C02 must be complete)
- `tower_purchased` signal reception from Economy
- Session reset: towers persist (towers are permanent — do not reset on restart)

**Design note**: Towers are permanent map structures. They do not reset between sessions. Once built, they are always there. This is a deliberate design decision — it rewards investment and avoids punishing the player for restarting.

### Out of Scope

- Tower upgrade (Forge — Alpha)
- Archer transfer from formation to tower (Alpha mechanic)
- Tower health / tower destruction

---

## Dependencies

- EPIC-F01 (GSM)
- EPIC-C01 (Economy — tower_purchased signal, TOWER_ZONE dwell)
- EPIC-C02 (Archer Formation — shared arrow pool reference)

---

## Unblocks

Nothing — terminal leaf node in MVP.

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `TOWER_COST` | 100 | economy.md |
| `TOWER_PROJ_DAMAGE` | 8 | archer-tower.md |
| `TOWER_RANGE` | 350.0 | archer-tower.md |
| `TOWER_SHOOT_IVTL` | 1.2 | archer-tower.md |
| Max towers | 2 | archer-tower.md |

---

## Key Acceptance Criteria

- [ ] Purchasing a tower (TOWER_ZONE dwell + 100g) spawns a tower at the zone position
- [ ] Tower fires every 1.2s at the nearest enemy within 350px
- [ ] Tower arrows are drawn from the shared arrow pool
- [ ] Tower arrow deals 8 HP damage on enemy hit
- [ ] Maximum 2 towers can exist on the map simultaneously
- [ ] Towers do not reset on session restart (they persist)
- [ ] Tower visual is distinct from archers and enemies (Royal Blue)
- [ ] TOWER_ZONE shows as purchased/inactive after a tower is built (no second purchase possible for that zone)

---

## Control Manifest Notes

- Shares arrow pool with Archer Formation — coordinate pool size if performance issues arise
- Static structure — no movement, no physics body
- No session reset (permanent structure — intentional)
