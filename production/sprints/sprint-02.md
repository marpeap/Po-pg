# Sprint 2 — Movement + Wave System + Economy Base

> **Duration**: 3.5 days (velocity: ~3h/day from vertical slice)
> **Goal**: Camera follows hero, enemies spawn and path toward castle, coins drop and accumulate.
> **Dependency**: Sprint 1 complete (GSM, Hero, Castle wired).

## Stories

| Story ID | Title | Estimate | Type | Test Gate |
|----------|-------|----------|------|-----------|
| F04-S01 | Camera follow system | 0.5d | Logic | BLOCKING — unit test |
| F05-S01 | Enemy node and movement | 1.0d | Logic | BLOCKING — unit test |
| F05-S02 | Enemy pool and wave sequencer | 1.0d | Integration | BLOCKING — integration test |
| C01-S01 | Gold economy and coins | 1.0d | Logic + Integration | BLOCKING — unit + integration |

**Total**: 3.5 days

## Sequencing

```
Day 1:   F04-S01 (camera) + F05-S01 in parallel (enemy node — no cross-dep)
Day 2:   F05-S02 (wave sequencer; depends on F05-S01 enemy node)
Day 3:   C01-S01 (economy + coins; depends on F05-S01 for kill signal)
Day 3.5: Buffer / test fixes
```

## Definition of Done

- [ ] Camera follows hero with ADR-004 lerp, limits clamped to 0–1080 / 0–1920
- [ ] Enemy activates from pool, steers toward castle via `direction_to`, deals 8 HP on contact
- [ ] Wave sequencer runs 5-wave table, fires `wave_started` / `wave_cleared`, tracks `total_kills`
- [ ] INTER_WAVE_PAUSE = 10s enforced between waves
- [ ] Gold counter starts at 60, coin pool (16 nodes) active, magnet collect at 170px
- [ ] All unit and integration tests pass

## Files Produced

- `src/gameplay/camera_follow.gd`
- `src/gameplay/enemy.gd`
- `src/gameplay/enemy_wave.gd`
- `src/gameplay/economy.gd`
- `src/gameplay/coin.gd`
- `tests/unit/gameplay/camera_follow_test.gd`
- `tests/unit/gameplay/enemy_test.gd`
- `tests/unit/gameplay/coin_test.gd`
- `tests/integration/gameplay/enemy_wave_integration_test.gd`
- `tests/integration/gameplay/economy_integration_test.gd`
