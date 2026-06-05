# QA Plan — Garrison Sprints 1–4
**Date**: 2026-05-20
**Scope**: 15 stories — F01-S01 through P02-S01
**Stage**: Production
**Review mode**: lean

---

## Story Classification

| Story | Title | Type | Auto Test | Manual QA | Blocker? |
|-------|-------|------|-----------|-----------|----------|
| F01-S01 | GameStateMachine autoload | Logic | Unit test — BLOCKING | — | No |
| F01-S02 | AudioManager autoload | Logic | Unit test — BLOCKING | — | No |
| F01-S03 | Main scene skeleton | Integration | — | Walkthrough — ADVISORY | No |
| F02-S01 | Hero joystick movement | Logic + Visual | Unit test — BLOCKING | Screenshot — ADVISORY | No |
| F03-S01 | Castle system | Logic | Unit test — BLOCKING | — | No |
| F04-S01 | Camera follow (ADR-004) | Logic | Unit test — BLOCKING | Visual check — ADVISORY | No |
| F05-S01 | Enemy node + movement | Logic | Unit test — BLOCKING | — | No |
| F05-S02 | Enemy pool + wave sequencer | Integration | Integration test — BLOCKING | — | No |
| C01-S01 | Gold economy + coin pool | Logic + Integration | Unit + Integration — BLOCKING | — | No |
| C01-S02 | Dwell zone triggers | Logic | Unit test — BLOCKING | — | No |
| C02-S01 | Archer formation + lerp | Logic | Unit test — BLOCKING | — | No |
| C02-S02 | Auto-fire + arrows | Logic + Integration | Unit + Integration — BLOCKING | — | No |
| FT01-S01 | Archer tower | Logic | Integration test — BLOCKING | — | No |
| P01-S01 | HUD — 4 elements | UI | HP formula unit — BLOCKING | Walkthrough — ADVISORY | No |
| P02-S01 | GAME_OVER overlay | UI | — | Walkthrough — ADVISORY | No |

---

## Automated Test Requirements

| Story | Test File | Status |
|-------|-----------|--------|
| F01-S01 | tests/unit/foundation/game_state_machine_test.gd | PASS (GUT 31/31) |
| F01-S02 | tests/unit/foundation/audio_manager_test.gd | PASS |
| F02-S01 | tests/unit/gameplay/hero_movement_test.gd | PASS |
| F03-S01 | tests/unit/gameplay/castle_test.gd | PASS |
| F04-S01 | tests/unit/gameplay/camera_follow_test.gd | PASS |
| F05-S01 | tests/unit/gameplay/enemy_test.gd | PASS |
| F05-S02 | tests/integration/gameplay/enemy_wave_integration_test.gd | To run |
| C01-S01 | tests/unit/gameplay/economy_gold_test.gd | PASS |
| C01-S01 | tests/integration/gameplay/economy_coin_integration_test.gd | Created 2026-05-20 — To run |
| C01-S02 | tests/unit/gameplay/economy_dwell_test.gd | PASS |
| C02-S01 | tests/unit/gameplay/archer_formation_test.gd | PASS |
| C02-S02 | tests/unit/gameplay/arrow_test.gd | PASS |
| C02-S02 | tests/integration/gameplay/archer_volley_integration_test.gd | To run |
| FT01-S01 | tests/integration/gameplay/archer_tower_integration_test.gd | To run |
| P01-S01 | tests/unit/ui/hud_formulas_test.gd | PASS |

---

## Manual QA Scope

| Story | What to Validate | Evidence File |
|-------|-----------------|---------------|
| F01-S03 | Main.tscn opens without errors, all nodes present in scene tree | Advisory — no file required |
| F02-S01 | Hero visible, moves at correct speed, joystick responds to touch | Advisory — screenshot optional |
| F04-S01 | Camera follows hero smoothly at 60fps and 30fps, limits hold | Advisory — visual observation |
| P01-S01 | All 17 HUD checklist items, screenshot set | production/qa/evidence/hud_walkthrough.md |
| P02-S01 | All 10 Game Over checklist items, screenshot set | production/qa/evidence/game_over_walkthrough.md |

---

## Entry Criteria

- [x] 31/31 GUT unit tests PASS (run 2026-05-20)
- [ ] Integration tests pass (4 files: enemy_wave, economy_coin, archer_volley, archer_tower)
- [ ] Smoke check — UNKNOWN (no report at production/qa/smoke-*.md — run /smoke-check sprint)
- [x] Build launches without crash

## Exit Criteria

- All auto tests pass (unit + integration)
- Walkthroughs for P01-S01 and P02-S01 completed OR explicitly deferred as advisory
- Sign-off report written at production/qa/qa-signoff-sprints-1-4-[date].md

## Out of Scope

- Android device testing (deferred to Polish stage)
- Performance profiling (deferred to Polish stage)
- Audio SFX playback (AudioManager no-ops without .ogg assets — deferred to Polish)
- Forge system (Alpha scope, not in MVP sprints)
