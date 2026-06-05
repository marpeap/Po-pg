# Castle

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 4 — Tension sans panique

## Overview

The Castle is the fixed defensive structure the player must protect throughout each run. It sits at a fixed world position and has a pool of hit points that decrements each time an enemy reaches it and makes contact. When its HP reaches zero, the castle emits `castle_fell`, triggering the Game Over state. It is the only structure that can be destroyed — and therefore the only way to lose.

From a data perspective, the Castle is an HP counter that decrements on enemy contact and emits a signal at zero. It has no movement, no AI, and no active decision-making. It reads `session_reset` to restore HP to full at the start of each run.

From the player's perspective, the Castle is the entire pressure system. Because the hero is invincible (Pillar 4 — "Tension sans panique"), the castle's HP bar is the only indicator of how close the player is to losing. Every enemy that slips past the formation is a direct deduction from the run's remaining time. The tension of Garrison is not "will my hero survive?" but "will my castle hold long enough?" The castle doesn't fight — it waits, and suffers.

## Player Fantasy

The Castle fantasy is **dread made visible**. The HP bar is not abstract — it is the run's life expectancy, counted down in enemy contact. Every enemy that breaks through feels like a personal failure. The player is never punished for it directly (the hero can't die), but the castle remembers.

At full HP, the castle is a promise: "You have time to build." As the bar drops, the promise narrows. By the time the bar is red, every gold coin is urgent, every movement decision is weighed against the castle's remaining capacity to absorb punishment. This is the exact emotional arc of Pillar 4 — "Tension sans panique." The player is stressed, not panicked. They see the threat clearly, have time to respond, and feel the cost of every delay.

Reference: *Clash Royale* nails the same feeling with tower HP bars — the moment a tower enters the red zone, the player's entire attention shifts. Garrison amplifies it by making the castle the *only* thing with HP. There is no distributed pressure across units — all tension concentrates into one bar.

The most powerful Castle moment is the first hit. An enemy piercing the formation and reaching the castle for the first time signals a failure of positioning — and puts the player into recovery mode for the rest of the run. Subsequent hits each carry that same weight.

## Detailed Design

### Core Rules

1. The castle is a fixed structure at world position `CASTLE_POS = (540, 120)`. It does not move.
2. The castle has a circular body with radius `CASTLE_RADIUS = 40px`. Enemies are considered "in contact" when their distance to `CASTLE_POS` is less than or equal to `CASTLE_RADIUS + ENEMY_RADIUS`.
3. The castle starts each run at full HP: `castle_hp = CASTLE_MAX_HP = 200`.
4. When an enemy makes contact with the castle, it deals `CASTLE_DMG = 8 HP` damage. Each enemy can deal damage at most **once per contact event** (not every frame — damage is applied on first contact, then suppressed until the enemy leaves and re-enters the radius).
5. When `castle_hp ≤ 0`, the castle clamps HP to 0 and emits the `castle_fell` signal.
6. `castle_fell` is emitted **once per run** — the signal is suppressed after the first emission (no duplicate signals).
7. The castle has **no HP regeneration** in MVP. HP only increases on `session_reset`.
8. On `session_reset`, castle HP resets to `CASTLE_MAX_HP` and the `castle_fell` suppression flag resets.
9. The castle exposes `castle_hp: int` and `castle_max_hp: int` each frame for the HUD to display.
10. The castle processes damage events only when Game State is `PLAYING`.

---

### States and Transitions

| State | Condition | Castle behavior |
|-------|-----------|-----------------|
| Intact | `castle_hp > 0`, Game State = `PLAYING` | Receives damage on enemy contact; exposes HP to HUD |
| Damaged | `castle_hp > 0`, one or more contacts applied | Intact behavior + visual damage feedback (HP bar updates) |
| Fallen | `castle_hp ≤ 0` | Clamps HP to 0; emits `castle_fell`; no further damage processed |
| Halted | Game State ≠ `PLAYING` | No damage processed; HP unchanged |
| Resetting | `session_reset` received | HP restores to `CASTLE_MAX_HP`; suppression flag clears; returns to Intact |

---

### Interactions with Other Systems

| System | Interface |
|--------|-----------|
| **Game State Machine** | Emits `castle_fell` signal when HP ≤ 0. Listens for `session_reset` to reset HP and suppression flag. Reads game state to halt damage processing when not `PLAYING`. |
| **Enemy Wave** *(downstream, provisional)* | Enemies query `castle_pos` and `castle_radius` as their pathfinding destination. Enemies notify the Castle on contact to trigger damage. *(Provisional — Enemy Wave GDD not yet written.)* |
| **HUD** *(downstream, provisional)* | Reads `castle_hp: int` and `castle_max_hp: int` each frame to render the HP bar. *(Provisional — HUD GDD not yet written.)* |
| **Camera** | Provides `CASTLE_POS = (540, 120)` as the world coordinate for the off-screen indicator. (Confirmed — matches Camera GDD assumption.) |

## Formulas

### Contact Detection

`in_contact = distance(enemy_pos, CASTLE_POS) ≤ (CASTLE_RADIUS + ENEMY_RADIUS)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy position | `enemy_pos` | Vector2 | World space | Current world position of the enemy |
| Castle position | `CASTLE_POS` | Vector2 | `(540, 120)` | Fixed world position of the castle |
| Castle radius | `CASTLE_RADIUS` | float | 40px | Collision radius of the castle structure |
| Enemy radius | `ENEMY_RADIUS` | float | TBD (provisional) | Collision radius of each enemy unit — defined in Enemy Wave GDD |

**Output:** Boolean — `true` if the enemy is within contact range. `ENEMY_RADIUS` is provisional until Enemy Wave GDD is authored.
**Example:** Enemy at `(540, 170)`, `CASTLE_RADIUS = 40`, `ENEMY_RADIUS = 12` (provisional). Distance = `|170 − 120| = 50`. `50 ≤ 40 + 12 = 52` → `true`, contact.

---

### Damage Application

`castle_hp = max(0, castle_hp − CASTLE_DMG)` *(applied once per contact event)*

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Castle HP (current) | `castle_hp` | int | 0–`CASTLE_MAX_HP` | Current hit points; never negative |
| Damage per contact | `CASTLE_DMG` | int | 1–30 | Flat HP removed per enemy contact event. Validated at 8 in prototype 2. |
| Castle max HP | `CASTLE_MAX_HP` | int | 100–500 | Starting HP per run. Validated at 200. |

**Output Range:** `castle_hp ∈ [0, CASTLE_MAX_HP]`. At `CASTLE_DMG = 8` and `CASTLE_MAX_HP = 200`, the castle can absorb exactly 25 contact events before falling.
**Example:** `castle_hp = 16`, enemy contacts castle. `castle_hp = max(0, 16 − 8) = 8`. One more contact → `castle_hp = 0` → emit `castle_fell`.

---

### HP Bar Fill Ratio (for HUD)

`hp_ratio = castle_hp / castle_max_hp`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current HP | `castle_hp` | int | 0–200 | Current hit points |
| Maximum HP | `castle_max_hp` | int | 200 | Starting HP (= `CASTLE_MAX_HP`) |
| HP ratio | `hp_ratio` | float | 0.0–1.0 | Fraction of HP remaining; drives HUD bar width |

**Output Range:** 1.0 (full health) to 0.0 (fallen). HUD system multiplies this by the bar's pixel width to get the filled region.
**Example:** `castle_hp = 50`, `castle_max_hp = 200`. `hp_ratio = 0.25` → bar shows 25% filled.

## Edge Cases

- **If two enemies contact the castle in the same frame**: Both damage events apply. HP decrements twice in the same frame. If both bring HP to 0 or below, HP clamps to 0 once and `castle_fell` fires once (suppression flag prevents duplicates). Matches Game State Machine GDD edge case: "HP clamps to 0. Only one `castle_fell` signal fires."
- **If `CASTLE_DMG` is set higher than `castle_hp`**: Damage is capped at `castle_hp`. `max(0, castle_hp − CASTLE_DMG)` ensures HP never goes negative. No special guard needed beyond the formula.
- **If `castle_hp = 0` and an enemy makes contact again**: Damage is not applied (Fallen state — no further damage processing). `castle_fell` is not re-emitted (suppression flag). The Game State Machine should already be in `GAME_OVER` at this point — this guard is a safety redundancy.
- **If `castle_fell` fires but Game State Machine is already in `GAME_OVER`**: The Game State Machine GDD explicitly handles this: "If `castle_fell` fires while already in `GAME_OVER`: Ignore duplicate signals." No special handling needed in Castle.
- **If an enemy is destroyed exactly at the castle contact boundary** (e.g., by an archer on the same frame): The damage event does not fire — the enemy is removed before its contact check completes. The order of operations (projectile hits resolved before contact damage) must be defined by Enemy Wave GDD. Flag as a provisional ordering dependency.
- **If `CASTLE_RADIUS = 0`**: Castle becomes a point — enemies must reach exact pixel position. Not a valid play state. Minimum safe value: 20px.
- **If `CASTLE_MAX_HP` is set to 0**: Castle begins the run already fallen. Not a valid configuration — minimum safe value: 1 HP.
- **If `session_reset` fires before `castle_fell` was emitted** (player quits mid-run): HP resets to full normally. No `castle_fell` needed — the run is simply discarded.

## Dependencies

**Upstream dependencies:**

| System | What Castle needs | Hard/Soft |
|--------|-------------------|-----------|
| Game State Machine | Current state (`PLAYING`/other); `session_reset` signal | Hard |

**Downstream dependents:**

| System | What they consume from Castle |
|--------|-------------------------------|
| Game State Machine | `castle_fell` signal — triggers `GAME_OVER` transition |
| Enemy Wave *(provisional)* | `CASTLE_POS: Vector2` and `CASTLE_RADIUS: float` — pathfinding destination for enemies; contact boundary for damage trigger |
| HUD *(provisional)* | `castle_hp: int` and `castle_max_hp: int` — HP bar rendering |
| Camera | Confirmed: `CASTLE_POS = (540, 120)` — used for off-screen indicator arrow |
| Forge *(Alpha, downstream)* | `CASTLE_MAX_HP_UP` upgrade increases `CASTLE_MAX_HP` at runtime by `FORGE_HP_DELTA = 30 HP` per purchase. Does not heal current `castle_hp`. Castle must listen for the Forge's upgrade signal and adjust its maximum HP ceiling accordingly. |

**Note:** The relationship between Castle and Game State Machine is bidirectional: Castle depends on GSM for game state and reset signal; GSM depends on Castle's `castle_fell` signal to trigger Game Over. This is explicitly documented in the Game State Machine GDD.

## Tuning Knobs

| Knob | Default | Safe Range | Effect if too low / too high |
|------|---------|------------|------------------------------|
| `CASTLE_MAX_HP` | 200 | 100–500 | Too low: run ends too quickly — no time to build an economy. Too high: castle never feels threatened — tension collapses. Validated at 200 in prototype 2 (provisional). |
| `CASTLE_DMG` | 8 HP | 1–30 HP | Too low: even sustained enemy contact barely threatens the castle. Too high: 2-3 breakthroughs end the run immediately — no recovery window. Validated at 8 in prototype 2 (provisional). |
| `CASTLE_RADIUS` | 40px | 20–80px | Too small: enemies must walk nearly on top of the castle structure — visually incorrect. Too large: enemies deal damage from a distance that feels unfair. |
| `CASTLE_POS` | `(540, 120)` | Fixed for MVP | Moving the castle changes all pathfinding assumptions, the off-screen indicator in Camera GDD, and the run's spatial layout. Treat as fixed for MVP. |

**Cross-knob interaction:** `CASTLE_MAX_HP ÷ CASTLE_DMG = max contact events per run`. At defaults: `200 ÷ 8 = 25` contacts before Game Over. If enemy wave volume is tuned up (more enemies reaching the castle per wave), `CASTLE_MAX_HP` must scale proportionally or runs will be too short. Validate together with Enemy Wave tuning.

## Acceptance Criteria

- **GIVEN** the game launches, **WHEN** the first frame renders, **THEN** `castle_hp = 200` and the HP bar shows full.
- **GIVEN** the game is in `PLAYING` and an enemy reaches `CASTLE_POS` within `CASTLE_RADIUS + ENEMY_RADIUS`, **WHEN** contact is detected, **THEN** `castle_hp` decrements by 8 in the same frame.
- **GIVEN** an enemy is in continuous contact with the castle, **WHEN** measured over multiple frames, **THEN** damage is applied once per contact event — not once per frame. HP decrements by 8 exactly once until the enemy leaves and re-enters the radius.
- **GIVEN** `castle_hp = 8` and one enemy contacts the castle, **WHEN** damage is applied, **THEN** `castle_hp = 0`, the `castle_fell` signal fires once, and the game transitions to `GAME_OVER` within the same frame.
- **GIVEN** `castle_hp = 0`, **WHEN** a subsequent enemy contacts the castle, **THEN** no additional damage is applied and `castle_fell` is not emitted again.
- **GIVEN** two enemies contact the castle in the same frame with `castle_hp = 10`, **WHEN** both contacts resolve, **THEN** HP decrements twice (resulting in `castle_hp = max(0, 10 − 8 − 8) = 0`), `castle_fell` fires exactly once.
- **GIVEN** `castle_hp = 50`, **WHEN** computed, **THEN** `hp_ratio = 50 / 200 = 0.25` — HUD bar renders at 25% width.
- **GIVEN** `session_reset` fires, **WHEN** `PLAYING` resumes, **THEN** `castle_hp = 200`, HP bar shows full, and no `castle_fell` suppression is active.
- **GIVEN** the game is in `GAME_OVER` (castle has fallen), **WHEN** measured, **THEN** `castle_hp` remains at 0 and does not change until the next `session_reset`.
- **GIVEN** the castle is at world position `(540, 120)`, **WHEN** provided to the Camera system, **THEN** the off-screen indicator arrow correctly points toward `(540, 120)` when that position is outside the viewport.

## Open Questions

- **Enemy radius**: The contact detection formula uses `ENEMY_RADIUS` which is undefined until the Enemy Wave GDD is authored. CASTLE_RADIUS = 40px is set, but the contact threshold depends on both values. Owner: Enemy Wave GDD authoring. Target: Enemy Wave GDD.
- **Damage resolution order**: If an enemy is killed by an archer on the same frame it contacts the castle, does the castle take damage? This GDD assumes projectile hits resolve before contact damage (enemy removed first → no castle damage). Enemy Wave GDD must confirm this ordering. Owner: Enemy Wave GDD. Target: Enemy Wave GDD.
- **Castle visual state feedback**: Should the castle sprite/appearance change as HP decreases (e.g., cracks at 50% HP, fire at 25%)? Currently unspecified — this GDD defines the data; the art bible and HUD GDD define the visual representation. Owner: art direction + HUD GDD. Target: art bible and HUD GDD authoring.
- **Castle HP tinting**: Some tower defense games tint the castle red when HP is low. If implemented, this is a Camera/HUD concern, not a Castle system concern. Castle only exposes `hp_ratio`. Owner: HUD GDD. Target: HUD GDD authoring.
- **Multiple castles (future)**: This GDD assumes exactly one castle. If future maps have multiple structures to defend, the Castle system must become a collection. Document as post-MVP and not in scope for MVP or Vertical Slice.
