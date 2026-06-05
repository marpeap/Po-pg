# Sprint 3 — Core Systems (Dwell Zones + Archers + Auto-Fire)

> **Duration**: 3 days (velocity: ~3h/day from vertical slice)
> **Goal**: Recruiting archers works, formation follows hero, volley fires at enemies.
> **Dependency**: Sprint 2 complete (enemies alive, gold accumulating).

## Stories

| Story ID | Title | Estimate | Type | Test Gate |
|----------|-------|----------|------|-----------|
| C01-S02 | Dwell zone triggers | 0.5d | Integration | BLOCKING — integration test |
| C02-S01 | Archer formation and lerp | 1.0d | Logic | BLOCKING — unit test |
| C02-S02 | Auto-fire volley + arrow pool | 1.5d | Logic + Integration | BLOCKING — unit + integration |

**Total**: 3.0 days

## Sequencing

```
Day 1:   C01-S02 (dwell zones; depends on C01-S01 economy)
Day 1-2: C02-S01 (formation; depends on F02-S01 hero facing_angle)
Day 2-3: C02-S02 (auto-fire; depends on C02-S01 formation + F05-S01 enemy targets)
```

## Definition of Done

- [ ] RECRUIT_ZONE at (135,490): hero dwell 0.8s → costs 30g → archer added to formation
- [ ] TOWER_ZONE at (270,490): hero dwell 0.8s → costs 100g → tower spawned (Sprint 4)
- [ ] 8 V-formation slots rotate with `facing_angle + PI/2`; ADR-004 lerp at F=0.12
- [ ] Formation starts at 2 archers; `recruit_purchased` adds one; `formation_full` fires at 8
- [ ] Session reset snaps archers to hero position, resets to 2
- [ ] Arrow pool: 24 nodes pre-allocated, no `instantiate()` during volley
- [ ] Volley fires every 1.2s; all active archers fire simultaneously toward nearest enemy in 300px
- [ ] Arrow deals 8 HP on hit, deactivates beyond 300px travel
- [ ] `AudioManager.play_volley(n)` called on each volley
- [ ] All unit and integration tests pass

## Files Produced

- `src/gameplay/archer_formation.gd`
- `src/gameplay/archer.gd`
- `src/gameplay/arrow.gd`
- `src/gameplay/object_pool_manager.gd` (if not already in Sprint 1)
- `tests/unit/gameplay/archer_formation_test.gd`
- `tests/unit/gameplay/arrow_test.gd`
- `tests/integration/gameplay/archer_volley_integration_test.gd`
- `tests/integration/gameplay/dwell_zone_integration_test.gd`
