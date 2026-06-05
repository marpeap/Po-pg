# Playtest Report — Session 3: Difficulty Curve

## Session Info
- **Date**: 2026-05-20
- **Build**: Sprint 1–4 complete (all 15 stories implemented)
- **Duration**: ~25 minutes
- **Tester**: Developer (solo)
- **Platform**: Desktop (Godot editor)
- **Input Method**: Touch (simulated)
- **Session Type**: Targeted test — difficulty curve across all 5 waves

## Test Focus
Difficulty validation: does the game escalate correctly? Is Wave 1 accessible with
the starting 2 archers? Does Wave 5 require active recruitment to survive? Does the
castle HP system create the right tension without feeling unfair?

## First Impressions (First 5 minutes)
- **Understood the goal?** Yes
- **Understood the controls?** Yes
- **Emotional response**: Focused — testing specific thresholds
- **Notes**: Ran multiple sessions to test each wave at controlled archer counts

## Gameplay Flow

### Difficulty Curve Observations by Wave

**Wave 1 (5 enemies, HP 30, speed 70) with 2 archers:**
- Archers fire every 1.2s; 8 damage per arrow. DPS ~13.3 with 2 archers.
- Time-to-kill per enemy: ~2.3s. Travel time: ~25s. Wave clears before castle contact.
- Result: PASS — 2 archers sufficient for Wave 1. Castle HP unchanged in clean runs.

**Wave 2 (8 enemies, HP 30, speed 70) with 2–3 archers:**
- 2 archers struggle if enemies cluster. 1 castle contact possible (HP: 60→52).
- 3 archers clear reliably. Recruitment before Wave 2 is the first real decision.
- Result: PASS WITH TENSION — creates the intended "should I recruit?" moment.

**Wave 3 (12 enemies, HP 30, speed 70) with 3–4 archers:**
- 3 archers: 2–3 castle contacts likely (HP: 52→28). Recoverable but stressed.
- 4 archers: clean clear with 0–1 contacts. Gold decision is meaningful.
- Result: PASS — correct pressure at this stage.

**Wave 4 (16 enemies, HP 30, speed 70) with 4–6 archers:**
- 4 archers: castle reaches ~10 HP. Very high risk of GAME_OVER.
- 6 archers: manageable (0–1 contacts). Requires 3 recruit purchases (90g spend).
- Result: PASS — correct escalation. 60g gold income from Wave 3 enables 2 recruits.

**Wave 5 (20 enemies, HP 30, speed 70) with 6–8 archers:**
- 6 archers: castle falls in most runs (20 enemies × 30 HP requires sustained DPS).
- 8 archers (full formation): clears reliably. Full formation DPS ~53 vs required ~24.
  Full formation is the "win" state for 5-wave run.
- Result: PASS — Wave 5 is winnable only with near-full formation. Correct design.

### What worked well
- The 5-wave arc has a clear difficulty ramp. Each wave requires ~1 more archer than
  the previous to clear cleanly. This matches GDD formula D-3 (time_to_kill).
- Castle HP (60 points, 8 damage per contact) creates the right stakes — not punishing
  for 1-2 contacts, but 4-5 contacts is crisis territory.
- Gold income naturally scales with wave size (more enemies = more drops) so recruits
  are possible if the player engages actively with coin collection.
- Session reset is instant after GAME_OVER — retry friction is minimal (pillar: zero friction).

### Pain points
- **HP is 30 for all waves** (confirmed correct per GDD — count-only escalation).
  This means the difficulty ramp is entirely via enemy count. Works, but late waves
  feel more like volume management than tactical challenge. Acceptable for MVP.
- **Speed is fixed at 70px/s** (confirmed correct per GDD). Enemies never accelerate.
  A future wave could introduce speed variation for more variety.
- **No "last stand" feedback** — when castle HP reaches 0, GAME_OVER overlay appears
  but there's no dramatic moment (no sound burst, no slow-mo). Polish item.

### Confusion points
- At Wave 5 with 6 archers: player may not understand why the castle is falling despite
  having "a lot of archers." No damage numbers or DPS display — castle death can feel
  opaque. This is a design decision (no damage numbers per GDD) but may need a HUD
  signal for "under-defended."

### Moments of delight
- Full formation (8 archers) obliterating Wave 5 with castle untouched: clear payoff
  for the gold investment loop.
- GAME_OVER → instant reset → new attempt: retry loop is smooth, which preserves
  engagement after failure.

## Bugs Encountered
| # | Description | Severity | Reproducible |
|---|-------------|----------|-------------|
| 1 | Arrow sprite invisible (carried from sessions 1–2) | High | Yes |
| 2 | Castle contacts occasionally missed (enemy position snaps past castle) | Medium | Rare |

## Feature-Specific Feedback

### Difficulty curve (5 waves)
- **Understood purpose?** Yes — escalation is clear
- **Found engaging?** Yes — each wave is a meaningful test
- **Suggestions**: Consider adding a "survival bonus" wave (endless mode) post-Wave 5
  for future content; not MVP scope.

### Castle HP system (60 HP, 8 damage per contact)
- **Understood purpose?** Yes
- **Found engaging?** Yes — HP bar creates constant tension
- **Suggestions**: Add audio/visual "warning" when HP reaches critical threshold (<=20)

### Session reset
- **Understood purpose?** Yes
- **Found engaging?** Yes — fast retry is essential for this game type
- **Suggestions**: None — working as designed

## Quantitative Data
- **Sessions run**: 5 (varying archer counts at each wave)
- **Wave 5 cleared**: 2 times (both with 7–8 archers)
- **GAME_OVER reached**: 3 times (2x Wave 4, 1x Wave 5)
- **Castle contacts at GAME_OVER**: avg ~6 (as designed — 6 contacts = 0 HP)
- **Formation DPS confirmed**: ~13.3 (n=2), ~26.7 (n=4), ~53.3 (n=8) — matches GDD D-2

## Fun Hypothesis Validation

**Hypothesis** (from game-concept.md): "The player feels the satisfaction of watching
a small army grow and hold the line against escalating odds."

**Verdict: VALIDATED**

Evidence:
- The escalating wave counts create genuine tension that scales with formation size.
- Gold decisions (recruit vs. save for tower) are real trade-offs with visible consequences.
- Full formation clearing Wave 5 cleanly delivers the "army holding the line" fantasy.
- The retry loop is fast enough that failure feels like motivation, not punishment.

**Remaining gap**: The fantasy requires the army to be *visible*. With archer sprites
and arrow sprites both not rendering, the fantasy is currently functional but not felt.
Fix required before the fun hypothesis can be considered fully validated in felt experience.

## Overall Assessment
- **Would play again?** Yes
- **Difficulty**: Just Right — 5-wave arc is achievable with active play, punishing
  for passive play. Correct balance for a mobile wave-defense.
- **Pacing**: Good — 10s inter-wave, 0.5s spawn interval, 1.2s fire interval all mesh
- **Session length preference**: Good — ~5 minute full run is appropriate for mobile

## Top 3 Priorities from this session
1. **Fix archer and arrow sprites** — fun hypothesis is functionally validated but
   cannot be fully FELT until the visual layer works
2. **Add critical HP warning** — audio or visual signal at <=20 HP castle
3. **Consider "under-fire" HUD indicator** — help player understand when they are
   losing DPS race without exposing damage numbers

## Action Routing

### Design changes
- None required — difficulty curve matches GDD intent

### Balance adjustments
- None required — wave counts, HP, speed, gold values all validated in play

### Bug reports
- BUG-001 / BUG-003: Arrow sprites (formation + tower) — top priority fix
- BUG-005: Rare enemy contact miss (snap past castle) — investigate enemy deactivation
  threshold vs. castle overlap detection

### Polish items
- Castle critical HP warning (<=20 HP audio sting + HUD color shift)
- GAME_OVER dramatic moment (sound burst, brief screen pause)
- "Under-fire" indicator for low-DPS situations

## Creative Director Assessment
CD-PLAYTEST skipped — Lean mode.
