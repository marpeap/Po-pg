# Hero Movement

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 1 — Un seul doigt, zéro friction | Pillar 4 — Tension sans panique

## Overview

Hero Movement is the sole direct input system in Garrison. The player controls the hero exclusively via a fixed-anchor virtual joystick in the bottom-left corner of the screen. The hero moves in world space at constant speed in the direction of the joystick, with no acceleration or deceleration. Releasing the joystick stops the hero instantly.

The hero also auto-shoots: every 0.9 seconds, the hero fires a projectile toward the nearest enemy in range. This is automatic — the player never taps to shoot. The only decision the player makes is *where to move*.

This system is the physical expression of Pillar 1 ("Un seul doigt, zéro friction"): one thumb, one joystick, everything else is automatic. The hero is invincible (Pillar 4 — "Tension sans panique") — the player moves freely without fear, and tension comes from the castle's fate, not the hero's survival.

## Player Fantasy

The player fantasy is **effortless command**. The hero glides across the battlefield without friction — no fumbling with buttons, no precise timing, no fear of dying. One thumb controls the entire army's position. The player looks at the battlefield and *goes where they need to be*.

The auto-shoot reinforces this: flicking the joystick toward a cluster of enemies and watching arrows fly without pressing anything creates the sensation of being a general who doesn't need to fight — just to position. Moving through enemy waves while archers behind fire automatically is the moment the fantasy peaks.

Reference: *Vampire Survivors* nails this with WASD — the character fires automatically and the player thinks only in terms of positioning. Garrison amplifies it by making the positioning tactile (one-thumb joystick on mobile) and spatially meaningful (gold collection, zone visits, interception lines).

The hero being invincible is not a design concession — it is the fantasy. The player is never punished for moving boldly. They can walk through enemy hordes. They are untouchable. The castle might fall, but the king never falls.

## Detailed Design

### Core Rules

1. The hero is a circle of radius 18px moving in a 1080×1920 world space.
2. The hero is **invincible** — it takes no damage from any source. No HP. No death state.
3. The hero moves at constant speed in the joystick direction. No acceleration, no deceleration, no friction.
4. Releasing the joystick (finger lifted) stops the hero instantly (velocity = zero).
5. The hero is clamped to world bounds at all times: `x ∈ [18, 1062]`, `y ∈ [18, 1902]`.
6. The hero **faces** the direction of the last non-zero joystick input. Facing angle is used by the Archer Formation system to rotate the V-formation.
7. The hero **auto-shoots** every `SHOOT_IVTL` seconds at the nearest enemy within shoot range. Shooting is not affected by movement — it fires regardless of joystick state.
8. The hero processes movement and shooting **only when Game State is `PLAYING`**.
9. On `session_reset`, the hero teleports to `(540, 1700)` and facing angle resets to `pi` (pointing upward toward the castle — consistent with Archer Formation EC-04).

---

### Virtual Joystick Rules

10. The joystick anchor is fixed at `(135, 800)` in viewport space — it does not move.
11. The joystick activates on `ScreenTouch` if and only if `touch.position.y > VIEWPORT.y × 0.5` (bottom half of screen). Touch events in the top half are ignored by the joystick.
12. Only one touch drives the joystick at a time. The first qualifying touch claims the joystick; subsequent touches are ignored until the active touch is released.
13. The joystick knob is clamped within radius 80px of the anchor: `knob_pos = anchor + clamp(touch − anchor, 80px)`.
14. The joystick direction is `normalize(touch − anchor)`. If `|touch − anchor| < 5px` (dead zone), direction = zero and hero does not move.
15. On touch release, joystick direction = zero and hero velocity = zero.

---

### States and Transitions

| State | Condition | Hero behaviour |
|-------|-----------|----------------|
| Idle | Joystick released or dead zone | Hero stationary; facing angle unchanged; auto-shoot continues |
| Moving | Joystick active outside dead zone | Hero moves at `HERO_SPEED` in joystick direction; facing angle updates |
| Halted | Game State ≠ `PLAYING` | No movement, no shooting, joystick input ignored |

---

### Interactions with Other Systems

| System | Interface |
|--------|-----------|
| **Game State Machine** | Reads game state each frame; halts all processing when not `PLAYING`. Listens for `session_reset` to teleport hero to start position. |
| **Camera** *(downstream)* | Exposes `hero_pos: Vector2` each frame. Camera reads this to compute lerp target. |
| **Archer Formation** *(downstream)* | Exposes `hero_pos: Vector2` and `facing_angle: float` each frame. Formation slots are computed relative to these. |
| **Economy** *(downstream)* | Exposes `hero_pos: Vector2` each frame. Economy reads this to detect dwell zone proximity. |
| **Enemy Wave** *(auto-shoot target)* | Reads enemy positions from Enemy Wave to find nearest target. Fires projectile toward it. Enemy Wave reads projectile position for hit detection. *(Provisional — Enemy Wave GDD not yet written.)* |

## Formulas

### Hero Velocity

`hero_velocity = joystick_dir × HERO_SPEED`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Joystick direction | `joystick_dir` | Vector2 | magnitude 0.0–1.0 | Normalised direction from anchor to touch, clamped to unit circle. Zero when joystick idle or in dead zone. |
| Hero speed | `HERO_SPEED` | float | 150–300 px/s | Maximum movement speed. Validated at 200 px/s in prototype 1. |
| Hero velocity | `hero_velocity` | Vector2 | magnitude 0–200 px/s | Applied to hero position each frame: `hero_pos += hero_velocity × delta` |

**Output Range:** 0 px/s (idle) to 200 px/s (full deflection). Linear — no easing.
**Example:** Joystick at full deflection right → `joystick_dir = (1, 0)` → `hero_velocity = (200, 0)` → hero moves 200px/s rightward.

---

### Hero Position Update

`hero_pos = clamp(hero_pos + hero_velocity × delta, world_min, world_max)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Hero position | `hero_pos` | Vector2 | `(18, 18)` to `(1062, 1902)` | Current hero world position |
| Delta time | `delta` | float | ~0.016s at 60fps | Frame time |
| World min | `world_min` | Vector2 | `(18, 18)` | Left-top world bound (HERO_RADIUS, HERO_RADIUS) |
| World max | `world_max` | Vector2 | `(1062, 1902)` | Right-bottom world bound (WORLD_SIZE − HERO_RADIUS) |

---

### Joystick Direction

`joystick_dir = (touch_pos − JOY_ANCHOR) / JOY_RADIUS` if `|touch_pos − JOY_ANCHOR| > DEAD_ZONE`, else `(0, 0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Touch position | `touch_pos` | Vector2 | Viewport space | Current drag position |
| Joystick anchor | `JOY_ANCHOR` | Vector2 | `(135, 800)` | Fixed viewport-space anchor |
| Joystick radius | `JOY_RADIUS` | float | 80px | Max knob displacement; normalises output to 0–1 |
| Dead zone | `DEAD_ZONE` | float | 5px | Minimum displacement before direction registers |

**Output Range:** Each axis −1.0 to 1.0. Magnitude always ≤ 1.0 (clamped to unit circle).

---

### Auto-Shoot Timer

`shoot_ready = (shoot_timer <= 0)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Shoot interval | `SHOOT_IVTL` | float | 0.5–2.0s | Time between hero/archer projectile bursts. Validated at 0.9s. |
| Shoot timer | `shoot_timer` | float | 0–SHOOT_IVTL | Counts down; resets to SHOOT_IVTL on fire |

**Output:** Boolean — fire when true. Resets timer on fire.
**Note:** Shared shoot timer applies to the hero and all archers simultaneously (see Archer Formation GDD — provisional).

## Edge Cases

- **If the player places two fingers in the bottom half simultaneously**: The first touch claims the joystick. The second touch is ignored until the first is released.
- **If the joystick touch drifts into the top half of the screen during a drag**: The drag continues normally — the activation zone check applies only on initial touch-down, not during an active drag.
- **If `|touch − anchor| < 5px` (dead zone)**: `joystick_dir = (0, 0)`. Hero stops. No facing angle update.
- **If the hero reaches a world boundary**: Position is clamped. Hero stops moving in that axis but continues in the perpendicular axis if the joystick has a component in that direction. No bounce.
- **If `HERO_SPEED` is set to 0**: Hero cannot move. Not a valid play state — treat as a configuration error. Minimum safe value: 50 px/s.
- **If a touch is released while the hero is at a world boundary**: Hero stops instantly (velocity = zero). No sliding.
- **If Game State transitions to `GAME_OVER` mid-drag**: Joystick input is discarded, hero stops. The touch event is not re-processed on restart — the player must lift and re-place their finger.
- **If `shoot_timer` is negative at frame start** (e.g., from a lag spike where delta > SHOOT_IVTL): Fire once, reset timer to SHOOT_IVTL. Do not fire multiple times to "catch up."

## Dependencies

**Upstream dependencies:**

| System | What Hero Movement needs | Hard/Soft |
|--------|--------------------------|-----------|
| Game State Machine | Current state (`PLAYING`/other); `session_reset` signal | Hard |

**Downstream dependents:**

| System | What they consume from Hero Movement |
|--------|--------------------------------------|
| Camera | `hero_pos` (Vector2) — lerp target each frame |
| Archer Formation | `hero_pos` (Vector2) + `facing_angle` (float) — formation slot calculation |
| Economy | `hero_pos` (Vector2) — dwell zone proximity check |
| Enemy Wave *(provisional)* | `hero_pos` (Vector2) — projectile origin; nearest enemy query |

## Tuning Knobs

| Knob | Default | Safe Range | Effect if too low / too high |
|------|---------|------------|------------------------------|
| `HERO_SPEED` | 200 px/s | 100–350 px/s | Too low: hero feels sluggish, can't intercept enemies. Too high: overshoots zones, hard to control. Validated at 200. |
| `JOY_RADIUS` | 80px | 50–120px | Too small: joystick feels cramped. Too large: full deflection requires uncomfortable thumb stretch. |
| `JOY_ANCHOR` | `(135, 800)` | Anywhere in bottom quadrant | Move left for small thumbs; move right if overlapping HUD elements. |
| `DEAD_ZONE` | 5px | 2–15px | Too small: accidental movement from touch noise. Too large: hero doesn't respond to light flicks. |
| `HERO_RADIUS` | 18px | 12–24px | Affects gold magnet visual (draw circle size) and world boundary clamp. No gameplay collision impact (hero is invincible). |

> **Note**: `SHOOT_IVTL` (fire interval for hero auto-shoot and all archers) is **owned by Archer Formation GDD** — tune it there. Hero Movement reads this value from the shared timer; it does not define it.

## Acceptance Criteria

- **GIVEN** the game is in `PLAYING`, **WHEN** the player drags a finger in the bottom half of the screen, **THEN** the hero moves in that direction at 200 px/s.
- **GIVEN** the joystick is active, **WHEN** the player releases their finger, **THEN** the hero stops within the same frame (no sliding).
- **GIVEN** the hero moving toward a world edge, **WHEN** the hero reaches the edge, **THEN** position clamps and hero continues moving along the edge if joystick has a perpendicular component.
- **GIVEN** the player touches the top half of the screen, **WHEN** the touch occurs, **THEN** the joystick does not activate and the hero does not move.
- **GIVEN** two simultaneous touches in the bottom half, **WHEN** both are placed, **THEN** only the first touch controls the joystick.
- **GIVEN** the hero is moving, **WHEN** `shoot_timer` reaches 0, **THEN** a projectile is fired toward the nearest enemy and `shoot_timer` resets to 0.9s — regardless of joystick state.
- **GIVEN** the game transitions to `GAME_OVER`, **WHEN** the transition occurs, **THEN** the hero stops moving and the joystick stops responding to input within the same frame.
- **GIVEN** `session_reset` fires, **WHEN** `PLAYING` resumes, **THEN** hero position is `(540, 1700)` and facing angle is `pi` (pointing toward the castle — upward in world space, aligns with Archer Formation EC-04).
- **GIVEN** the joystick displacement is less than 5px, **WHEN** measured, **THEN** the hero does not move and facing angle does not update.

## Open Questions

- **Auto-shoot range**: Should the hero only shoot enemies within a defined radius, or always shoot the nearest enemy anywhere on the world? Prototype 2 used unlimited range. A visible shoot-range circle may help the player understand the mechanic. Owner: design lead. Target: Hero Movement GDD review.
- **Shared vs. separate shoot timer**: The GDD currently specifies a shared timer for hero + archers. If archers need independent fire rates (e.g., upgraded via Forge), the timer must split. Owner: design lead. Target: Archer Formation GDD authoring.
- **Hero visual during GAME_OVER**: Should the hero freeze in-place or disappear? Currently unspecified. Owner: design lead. Target: HUD GDD or art bible.
- **Multi-touch for future features**: A second touch could activate a future ability. Explicitly anti-pillar 1 for MVP — document as a post-Alpha consideration only.
