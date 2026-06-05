# Concept Prototype Report: Garrison

> **Date**: 2026-05-17
> **Prototype Path**: Engine (Godot 4.6 / GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player moves the hero with a joystick and sees 8 archers follow in V-formation
while auto-shooting enemies, they will feel like a commander leading an army —
evidenced by the player voluntarily changing their movement path to position the
archers tactically rather than fleeing passively.

---

## Riskiest Assumption Tested

The V-formation of 8 archers would remain visually readable and non-chaotic as
archers continuously reposition behind the hero. The risk was that 8 independently
lerp-ing sprites would produce a blob or overlapping mess that broke the "army" fantasy.

**Result**: The assumption proved true. The staggered lerp (0.12 per frame) and
formation slot rotation produced clean, readable formation movement. The "army" feeling
registered immediately.

---

## Approach

Built a single-file Godot 4.6 prototype with no external assets — all visuals rendered
via `_draw()` (colored circles and lines). All game logic lives in `Main.gd` attached
to a single `Node2D` root scene.

**Path chosen**: Engine
**Reason for path**: The formation visuals and joystick feel are spatial and
timing-sensitive. Browser latency would have produced false results about both.

**Shortcuts taken (intentional):**
- All visuals are colored circles — no sprites, no animations
- No CharacterBody2D or physics nodes — all movement is manual Vector2 arithmetic
- All collision is manual distance checks — no Area2D or CollisionShape2D
- No object pooling — raw Array append/remove_at
- No camera — map is fixed viewport (540×960)
- No castle, no wave system, no economy
- No game over / menus / sounds
- Enemy AI is direction_to() only — no NavigationServer2D

---

## Result

The prototype ran without errors on first launch. The core hypothesis was **CONFIRMED**:
the V-formation is visually legible, the archers rotate fluidly behind the hero relative
to movement direction, and the gold magnet mechanic responded correctly.

**UX issue identified**: The joystick is dynamic (anchor appears wherever the player
touches), while the expected behavior is a fixed anchor in the bottom-left zone.
This was the primary friction point during playtesting.

**Out-of-scope gaps noted**: The fixed viewport (no camera) made the map feel static.
This is expected — camera follow was explicitly cut from scope. It is a required
feature for production.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine — Godot 4.6 |
| Iterations to playable | 1 (one-shot) |
| Prototype duration | 1 session |
| Playtesters | 1 internal |
| Feel assessment | Formation rotation smooth; joystick anchor position wrong (center vs. bottom) |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PROCEED

The core fantasy — "move the hero, an army follows" — registered immediately and
without explanation. The formation is readable, the shooting is satisfying, and
the gold magnet adds a natural pull mechanic. The two gaps identified (fixed joystick,
no camera) are both known production requirements, not design failures. The concept
is worth full design documentation.

---

## If Proceeding

**Core tuning values to carry forward into GDDs:**
- Hero speed: 200 px/s
- Enemy speed: 75 px/s
- Spawn interval: 2.2s
- Archer shoot interval: 0.8s
- Magnet radius: 170 px
- Formation lerp factor: 0.12 (smooth enough, no lag complaint)
- Projectile speed: 420 px/s

**Assumptions confirmed:**
- Formation remains readable with 8 archers simultaneously repositioning
- Gold magnet radius of 170px feels natural — not too greedy, not frustrating
- Staggered archer shoot timers (offset by shoot_ivtl / 8) produce continuous
  fire rather than a salvo burst, which feels better

**Assumptions disproved / corrected:**
- Dynamic joystick (appears at touch point) feels wrong for this game. A fixed
  anchor at bottom-left (approx. 135, 800 in 540×960) is required. Fixed joystick
  = player can touch anywhere in the bottom half and the direction is relative to
  the anchor, not the touch point.

**Emergent observations:**
- The formation naturally creates a "safe zone" behind the hero — players
  instinctively moved toward enemies so archers would be in range, then retreated
  through the wave. This is a valid emergent tactic worth formalizing in the AI GDD.
- Enemy spawn from all 4 sides creates natural pressure to keep moving rather than
  standing still — validates the "joystick always active" design pillar.

**Production requirements surfaced:**
- Camera system (smooth follow with lerp) — MVP requirement, not optional
- Fixed joystick anchor at bottom-left — UX requirement before vertical slice

**Next steps:**
1. `/design-review design/gdd/game-concept.md` — validate concept vs. prototype learnings
2. `/gate-check` — confirm readiness for Systems Design phase
3. `/art-bible` — visual identity before GDDs
4. `/map-systems` — decompose into all game systems
5. `/design-system hero-movement` — embed tuning values from this prototype
6. `/design-system archer-formation` — formalize formation math and targeting rules

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  The dynamic joystick felt natural to implement but wrong to play. A fixed anchor
  is mandatory for this genre — the player's thumb has muscle memory for a fixed
  position. This is a standard mobile game pattern that should not be prototyped away.

- **What surprised us that didn't show up in the brainstorm?**
  The "retreat through the wave" tactic emerged naturally without being designed.
  The hero moving through enemies while archers fire creates an interesting risk/reward
  moment that wasn't in the concept doc.

- **What would we test differently next time?**
  Add a basic camera follow (2 lines of code: `camera.global_position = hero.global_position`)
  even in prototype scope. The fixed viewport was the most misleading aspect of
  the build relative to the final game.

---

> *Prototype code location: `prototypes/garrison-concept/`*
> *This code is throwaway. Never refactor into production.*
