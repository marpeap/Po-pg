# Playtest Report — Session 2: Mid-Game Systems

## Session Info
- **Date**: 2026-05-20
- **Build**: Sprint 1–4 complete (all 15 stories implemented)
- **Duration**: ~20 minutes
- **Tester**: Developer (solo)
- **Platform**: Desktop (Godot editor)
- **Input Method**: Touch (simulated)
- **Session Type**: Targeted test — economy, recruitment, and multi-wave systems

## Test Focus
Mid-game loop validation: does the gold economy create meaningful decisions?
Does the archer formation scaling (2→8) feel progressive? Does inter-wave pacing hold?

## First Impressions (First 5 minutes)
- **Understood the goal?** Yes — by session 2, full loop is understood
- **Understood the controls?** Yes
- **Emotional response**: Engaged — gold accumulation and spending decisions are present
- **Notes**: Focused testing on reaching Wave 3+ and testing T1→T2 recruit cost transition

## Gameplay Flow

### What worked well
- Gold economy functions correctly: enemies drop 15g, recruits cost 30g (T1) / 60g (T2)
- Session reset is reliable — tested 3 consecutive resets, all restored correct state
- Inter-wave 10s pause is noticeable and gives breathing room for gold decisions
- TOWER_ZONE purchase deducts 100g correctly and is tracked (economy._tower_count)
- spend_gold() correctly refuses when insufficient gold (no overdraft possible)
- Wave table escalates correctly: Wave 1 (5 enemies) → Wave 5 (20 enemies)
- Pool of 30 enemy nodes handles Wave 5 count without exhaustion

### Pain points
- **No visual feedback for T1→T2 cost transition** — recruit cost silently doubles at
  4 archers. Player may be confused when 30g is insufficient for the next recruit.
  Severity: **Medium**
- **TOWER_ZONE location not marked** — identical discovery problem to RECRUIT_ZONE.
  Severity: **Medium**
- **No wave number indicator on HUD** — player cannot tell which wave they are on.
  Severity: **Medium** (HUD story P01 covers gold/HP; wave counter is missing)
- **Archer tower arrow sprites also invisible** — same bug as formation archers.
  Tower fires (damage confirmed) but no visual. Severity: **High**

### Confusion points
- At Wave 4 with 6 archers: player unsure whether to save for tower (100g) or recruit
  more archers. This is the intended economic tension — working as designed.
- Dead enemies occasionally clip into castle before deactivating — minor visual glitch,
  no gameplay impact.

### Moments of delight
- Wave cleared with 0 enemies reaching castle: clear moment of victory
- Coin rain after a dense wave cluster: visually satisfying even without archer sprites
- Gold counter at 90g+: sense of economic power building

## Bugs Encountered
| # | Description | Severity | Reproducible |
|---|-------------|----------|-------------|
| 1 | ArcherTower arrow sprites not rendered (same root cause as BUG-001) | High | Yes |
| 2 | Dead enemy clip into castle position before deactivate() call | Low | Intermittent |
| 3 | Wave number not shown on HUD | Medium | Always |

## Feature-Specific Feedback

### Economy (gold/spend)
- **Understood purpose?** Yes
- **Found engaging?** Yes — 30/60/100g tiers create distinct decision points
- **Suggestions**: Surface T2 cost threshold earlier (visual hint when approaching 4 archers)

### Wave escalation (5→8→12→16→20 enemies)
- **Understood purpose?** Yes — each wave is visibly larger
- **Found engaging?** Yes — Wave 4 (16 enemies) creates genuine pressure with 4 archers
- **Suggestions**: None — pacing is correct

### Inter-wave pause (10s)
- **Understood purpose?** Yes
- **Found engaging?** Yes — 10s is tight enough to stay tense but enough to act
- **Suggestions**: None

### Archer Tower
- **Understood purpose?** Yes — 100g for a fixed turret covering a lane
- **Found engaging?** Yes (functionally) — cannot visually assess feel due to invisible arrows
- **Suggestions**: Fix arrow sprites first, then re-evaluate feel

## Quantitative Data
- **Session resets tested**: 3 (all PASS)
- **Waves reached**: Wave 5 (full table)
- **Max archers recruited**: 6 (T2 cost confirmed at 60g each)
- **Tower purchases**: 1 (100g deducted correctly)
- **Coin pool exhaustion**: Not observed (16 node pool sufficient for Wave 1–5)

## Overall Assessment
- **Would play again?** Yes
- **Difficulty**: Just Right up to Wave 3; Wave 4–5 requires active recruitment to survive
- **Pacing**: Good — wave intervals and escalation feel balanced
- **Session length preference**: Good

## Top 3 Priorities from this session
1. **Fix arrow/tower sprite rendering** — applies to both ArcherFormation and ArcherTower
2. **Add wave number to HUD** — critical missing information for the player
3. **Signal T1→T2 cost transition** — prevent silent cost doubling confusion

## Action Routing

### Bug reports
- BUG-003: ArcherTower arrow sprites not rendered (same root as BUG-001)
- BUG-004: Wave number missing from HUD

### Balance adjustments
- Inter-wave pause: no change needed (10s confirmed appropriate)
- Wave enemy counts: no change needed (5/8/12/16/20 feels correct)
- Gold per kill: no change needed (15g is validated)

### Polish items
- T1→T2 cost threshold visual indicator
- TOWER_ZONE visual marker
- Enemy deactivation position (minor clip on death)

## Creative Director Assessment
CD-PLAYTEST skipped — Lean mode.
