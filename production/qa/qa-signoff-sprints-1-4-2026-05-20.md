# QA Sign-Off Report: Sprints 1–4
**Date**: 2026-05-20
**Stage**: Production
**QA Plan**: production/qa/qa-plan-sprints-1-4-2026-05-20.md

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| F01-S01 GameStateMachine | Logic | PASS | — | PASS |
| F01-S02 AudioManager | Logic | PASS | — | PASS |
| F01-S03 Main scene skeleton | Integration | — | Advisory (not run) | DEFERRED |
| F02-S01 Hero movement | Logic | PASS | Advisory (not run) | PASS |
| F03-S01 Castle system | Logic | PASS | — | PASS |
| F04-S01 Camera follow | Logic | PASS | Advisory (not run) | PASS |
| F05-S01 Enemy node + movement | Logic | PASS | — | PASS |
| F05-S02 Enemy wave sequencer | Integration | Not run in GUT | — | PENDING |
| C01-S01 Gold economy + coins | Logic + Integ | Unit PASS / Integ not run | — | PENDING |
| C01-S02 Dwell zone triggers | Logic | PASS | — | PASS |
| C02-S01 Archer formation + lerp | Logic | PASS | — | PASS |
| C02-S02 Auto-fire + arrows | Logic + Integ | Unit PASS / Integ not run | — | PENDING |
| FT01-S01 Archer tower | Logic | Not run in GUT | — | PENDING |
| P01-S01 HUD | UI | PASS (formula) | PASS WITH NOTES | PASS WITH NOTES |
| P02-S01 Game Over overlay | UI | — | BLOCKED → unblocked | RETEST NEEDED |

---

## Bugs Found and Fixed This Session

| ID | Story | Description | Severity | Status |
|----|-------|-------------|----------|--------|
| BUG-001 | All | `Can't change state while flushing queries` — CollisionShape2D.disabled dans callback physique | S2 | FIXED — set_deferred() appliqué sur arrow.gd, coin.gd, enemy.gd |
| BUG-002 | F03-S01 | Château ne prend pas de dégâts — aucun câblage enemy→castle | S1 | FIXED — distance check + _castle ref injectée |
| BUG-003 | C01-S01 | Coins invisibles — _draw() manquant dans coin.gd | S3 | FIXED — _draw() ajouté |
| BUG-004 | C02-S02 | Flèches invisibles — _draw() manquant dans arrow.gd | S3 | FIXED — _draw() ajouté |
| BUG-005 | FT01-S01 | Archers de tour sans visuel — _draw() incomplet | S3 | FIXED — 2 archers ajoutés dans _draw() |
| BUG-006 | FT01-S01 | Tour ne tire qu'1 flèche au lieu de 2 (GDD R3) | S2 | FIXED — boucle TOWER_ARCHERS_COUNT |
| BUG-007 | FT01-S01 / C02-S01 | Slot-release archers → tour non implémenté (GDD R3) | S2 | FIXED — on_tower_purchased() + gate formation>=2 |
| BUG-008 | C01-S02 / F01-S03 | Zones dwell invisibles — aucun marqueur visuel | S3 | FIXED — zone markers ajoutés dans Main.gd |

---

## Integration Tests Status

4 fichiers d'intégration présents mais non exécutés dans GUT cette session :
- `tests/integration/gameplay/enemy_wave_integration_test.gd`
- `tests/integration/gameplay/economy_coin_integration_test.gd` *(créé ce jour)*
- `tests/integration/gameplay/archer_volley_integration_test.gd`
- `tests/integration/gameplay/archer_tower_integration_test.gd`

**Action requise** : configurer GUT pour inclure `tests/integration/` et exécuter.

---

## Smoke Check

Aucun rapport `production/qa/smoke-*.md` — UNKNOWN.
Le jeu lance sans crash, château prend des dégâts, ennemis spawn, archers tirent. Smoke informel : PASS.

---

## Verdict: APPROVED WITH CONDITIONS

**Conditions avant d'avancer au stage Polish :**

1. Exécuter les 4 tests d'intégration dans GUT et confirmer PASS
2. Retester P02-S01 Game Over (château désormais fonctionnel)
3. Documenter les notes du P01-S01 HUD (PASS WITH NOTES — notes non formalisées)

**Conditions non bloquantes (Polish) :**
- Smoke check formel (`/smoke-check sprint`)
- Walkthroughs HUD + Game Over avec screenshots

---

## Next Step

Conditions légères — résoudre les 3 points ci-dessus puis `/gate-check production` pour avancer au stage Polish.
