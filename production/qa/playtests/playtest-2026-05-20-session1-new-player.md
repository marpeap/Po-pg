# Playtest Report — Session 1: New Player Experience

## Session Info
- **Date**: 2026-05-20
- **Build**: Sprint 1–4 complete (all 15 stories implemented)
- **Duration**: ~15 minutes
- **Tester**: Developer (solo)
- **Platform**: Desktop (Godot editor, Android target)
- **Input Method**: Touch (simulated via mouse in editor)
- **Session Type**: First structured playtest of full build

## Test Focus
New player onboarding: can the player understand the core loop (move hero → recruit
archers → defend castle) within the first 2 minutes without guidance?

## First Impressions (First 5 minutes)
- **Understood the goal?** Partially — the castle is visible and enemies march toward
  it, which communicates "defend the castle." The recruit zone is not labelled; tester
  had to discover it by moving the hero around.
- **Understood the controls?** Yes — virtual joystick activates naturally on bottom-half
  touch. No confusion about the input method.
- **Emotional response**: Engaged — enemies moving toward the castle create immediate
  tension. The formation of archers firing autonomously feels powerful.
- **Notes**: The first 30 seconds communicate threat clearly. The gold loop is less
  immediately obvious — coins appear but their purpose requires more time to discover.

## Gameplay Flow

### What worked well
- Virtual joystick activates reliably on bottom-half touch; no misfires observed
- Camera follow is smooth; world edges are not visible (correct limit clamping)
- Enemies spawn at bottom of screen and march upward — clear threat vector
- Arrow damage is applied correctly; enemies die and drop coins
- Session reset after GAME_OVER is instant and clean — gold/archers/castle all restored

### Pain points
- **Arrow sprites invisible** — archers appear to fire (interval fires, damage dealt)
  but no projectile is visible. Player has no visual feedback that archers are active.
  Severity: **High** (Visual/Feel — breaks fantasy of "watching your army fight")
- **RECRUIT_ZONE not visually signalled** — no indicator shows where to stand to recruit.
  Tester discovered it by accident after ~90 seconds. Severity: **Medium**
- **Archer figures on formation not visible** — archers exist and fire, but their
  sprites are not rendered. Player cannot see the army growing. Severity: **High**

### Confusion points
- "Why is my gold going down?" — no visual cue for the recruit cost moment (zone dwell
  auto-purchases; no confirmation UI). Player may not know a purchase happened.
- Coin magnet range not obvious — coins attracted only at close range initially; some
  players may not realise the magnet exists.

### Moments of delight
- First wave cleared with 2 archers: satisfying to watch enemies die before reaching
  the castle even with minimal force.
- Gold counter ticks up as coins are collected — visible and responsive.

## Bugs Encountered
| # | Description | Severity | Reproducible |
|---|-------------|----------|-------------|
| 1 | Arrow sprite not rendered — projectile travels and damages but is invisible | High | Yes |
| 2 | Archer formation figures not rendered — nodes exist, signals fire, sprites absent | High | Yes |

## Feature-Specific Feedback

### Hero movement
- **Understood purpose?** Yes
- **Found engaging?** Yes — joystick feels responsive; fixed-anchor pattern works well
- **Suggestions**: None — core feel is good

### Archer recruitment (zone dwell)
- **Understood purpose?** Partially — requires discovering the zone
- **Found engaging?** Yes, once discovered — the 0.8s dwell creates a small tension moment
- **Suggestions**: Add a visual indicator for RECRUIT_ZONE (glow, text, or icon)

### Castle defense
- **Understood purpose?** Yes — immediately clear
- **Found engaging?** Yes — HP bar going red creates urgency
- **Suggestions**: None at this stage

## Overall Assessment
- **Would play again?** Yes
- **Difficulty**: Just Right (Wave 1–2 with 2 archers is achievable but requires
  active gold management)
- **Pacing**: Good — wave intervals feel appropriate
- **Session length preference**: Good — ~5 minute sessions feel natural

## Top 3 Priorities from this session
1. **Fix arrow sprite rendering** — highest impact visual issue; breaks the core combat
   feedback loop
2. **Fix archer formation sprite rendering** — army must be visible for the "see your
   army grow" pillar to land
3. **Add RECRUIT_ZONE visual indicator** — discoverability is required for new players

## Action Routing

### Bug reports
- BUG-001: Arrow sprite not rendering (Area2D node exists, sprite/texture not assigned)
- BUG-002: Archer formation figures not rendering (nodes present, visual absent)

### Polish items
- RECRUIT_ZONE visual indicator (glow/label on zone)
- Coin magnet radius visual hint (subtle particle or ring)
- Recruit purchase confirmation (brief flash or sound on gold deduct)

## Creative Director Assessment
CD-PLAYTEST skipped — Lean mode.
