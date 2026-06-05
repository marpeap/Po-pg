# Sprint 4 — Feature + Presentation Layer

> **Duration**: 2 days (velocity: ~3h/day from vertical slice)
> **Goal**: Archer Tower purchasable, HUD live, GAME_OVER overlay with tap-to-restart. Full loop playable.
> **Dependency**: Sprint 3 complete (formation working, arrows firing).

## Stories

| Story ID | Title | Estimate | Type | Test Gate |
|----------|-------|----------|------|-----------|
| FT01-S01 | Archer Tower system | 0.5d | Integration | BLOCKING — integration test |
| P01-S01 | HUD implementation | 1.0d | UI + Logic | BLOCKING — unit test (HP formula); ADVISORY — manual walkthrough |
| P02-S01 | GAME_OVER overlay | 0.5d | UI | ADVISORY — manual walkthrough + screenshot |

**Total**: 2.0 days

## Sequencing

```
Day 1:   FT01-S01 (tower; depends on C02-S02 arrow pool) + P01-S01 in parallel (HUD; depends on F01-S01 GSM signals)
Day 2:   P02-S01 (GAME_OVER; depends on F01-S01 GSM, F05-S02 kill count)
Day 2:   Full loop smoke test and evidence collection
```

## Definition of Done

- [ ] TOWER_ZONE dwell + 100g → tower node spawned at TOWER_ZONE_POS, max 2 towers
- [ ] Tower fires every 1.2s at nearest enemy within 350px, draws from shared arrow pool
- [ ] Towers persist after session reset (do not reset on `session_reset` signal)
- [ ] HUD strip visible during PLAYING; hidden in GAME_OVER and RESETTING
- [ ] Gold counter: amber when can-afford, white otherwise
- [ ] Castle HP bar: 3 color bands at correct thresholds
- [ ] Wave label: "Wave N" during wave, "Next: Xs" countdown during inter-wave
- [ ] Archer badge: "N/8", gold when full
- [ ] GAME_OVER overlay appears on same frame as `game_state_changed(GAME_OVER)`
- [ ] Panel shows correct wave + kill count
- [ ] "TAP ANYWHERE TO RESTART" pulses at ~1Hz via Tween
- [ ] Tap during GAME_OVER triggers `GameStateMachine.request_restart()`
- [ ] Tap during RESETTING does NOT trigger another restart
- [ ] All tests pass; walkthrough evidence documented in `production/qa/evidence/`

## Files Produced

- `src/gameplay/archer_tower.gd`
- `src/ui/hud.gd`
- `src/ui/game_over_overlay.gd`
- `tests/unit/ui/hud_formulas_test.gd`
- `tests/integration/archer_tower_integration_test.gd`
- `production/qa/evidence/hud_walkthrough.md`
- `production/qa/evidence/game_over_walkthrough.md`

## Post-Sprint: Gate Check

After Sprint 4 completes and all tests pass, run a final smoke check and
confirm the project advances to **Polish** stage via `/gate-check production`.
