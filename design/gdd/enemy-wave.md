# Enemy Wave

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 4 — Tension sans panique | Pillar 2 — Chaque pièce d'or est une décision

## Overview

The Enemy Wave system is the threat engine of Garrison. It spawns timed waves of enemies that march in a straight line toward the castle, dealing contact damage when they arrive. Each enemy has hit points that can be depleted by projectiles from the hero and archers, and drops gold on death. Between waves, a countdown pause gives the player time to spend gold before the next horde arrives.

From a data perspective, the Enemy Wave system owns: a wave counter that increments each run, an active enemy array that updates every frame, spawn positions at the edges of the world, a cooldown timer that fires spawns at regular intervals within a wave, and an inter-wave pause timer that separates each wave. On `session_reset`, all enemies are cleared and the wave counter resets to 1.

From the player's perspective, enemies are the only reason anything else in the game matters. Without the approaching horde, collecting gold is pointless, recruiting archers changes nothing, and the castle is just a building. The first enemies of a new wave appear on screen and immediately demand a response — does the player intercept them directly, or run to purchase another archer first? This pressure is what makes Pillar 2 ("Chaque pièce d'or est une décision") land: the urgency of the wave is what makes gold allocation feel consequential.

## Player Fantasy

The Enemy Wave fantasy is **controlled escalation** — the feeling that the threat is always growing, always demanding a response, but never (until the final collapse) arriving faster than the player can react.

The primary joystick moment is not the arrival of enemies at the castle — it is the appearance of the first enemy of a new wave. The player sees the horde emerge at the bottom of the screen and must immediately make a spatial decision: move toward them to intercept, or sprint to the nearest dwell zone to recruit one more archer first? The wave forces the hand. The inter-wave countdown pause is the strategic breathing room that makes this moment feel earned rather than arbitrary — during the pause, the player has agency; the moment the countdown expires, the urgency snaps back.

The secondary fantasy is **the horde as score target**. In the arc of a run, the player is not trying to survive forever — they are trying to kill as many enemies as possible before the castle falls. Every wave survived is an achievement. Every enemy killed before it reaches the castle is a gold drop, an archer funded, a wave-further reach. The castle falling is not a failure — it is the natural end of the run, and the player's score is how far they pushed. This reframes the castle's HP bar from "don't let this hit zero" to "how close to the wall can we get?" The player should feel pride at Wave 12, not failure.

The moment the wave design must deliver: the inter-wave countdown reaching 3… 2… 1… while the player is mid-sprint toward a dwell zone, with three gold coins still to pick up and one archer still unbought. That tension is Pillar 2 — "Chaque pièce d'or est une décision" — made physical. The wave timer is the decision deadline.

## Detailed Design

### Core Rules

1. **Wave Counter**: `wave_number` starts at 1 and increments each time a new wave begins. Resets to 1 on `session_reset`.

2. **Wave Start**: Wave 1 begins spawning immediately when Game State transitions to `PLAYING`. Subsequent waves begin after the inter-wave pause expires.

3. **Enemies Per Wave**: Wave `n` spawns `enemies_per_wave = ENEMIES_PER_WAVE_BASE + (n − 1) × ENEMIES_PER_WAVE_SCALING` enemies. At defaults: Wave 1 = 5, Wave 2 = 7, Wave 3 = 9.

4. **Spawn Positions**: Enemies spawn from a horizontal band near the bottom of the world. Spawn position: `spawn_x = random(SPAWN_X_MIN, SPAWN_X_MAX)`, `spawn_y = SPAWN_Y = 1860`. To reduce visual stacking, each enemy's `spawn_x` is offset by a minimum horizontal separation of `SPAWN_X_MIN_SEP = 80px` from the previous spawn.

5. **Spawn Interval**: Within a wave, one enemy spawns every `SPAWN_INTERVAL = 2.0s`. Enemies do not all appear at once.

6. **Enemy Movement**: On spawn, each enemy computes its direction once: `direction = (CASTLE_POS − spawn_pos).normalized()`. The enemy advances along this direction at `ENEMY_SPEED = 70px/s` every frame. Direction is never recalculated — enemies march in a straight line and do not steer around the hero, archers, or anything else.

7. **Enemy Collision Body**: Each enemy has a circular body with `ENEMY_RADIUS = 12px`. This is the authoritative definition completing the Castle GDD contact formula: `distance(enemy_pos, CASTLE_POS) ≤ CASTLE_RADIUS + ENEMY_RADIUS = 40 + 12 = 52px`.

8. **Enemy Hit Points**: Each enemy spawns with HP computed from the wave number (see Formulas). At defaults: Wave 1 = 30 HP, Wave 3 = 36 HP, Wave 5 = 42 HP.

9. **Hero Interaction**: Enemies do not interact with the hero. The hero cannot block, redirect, or collide with enemies. Enemies march through the hero's position toward the castle without reacting.

10. **Projectile Hits**: When a projectile hits an enemy, the enemy's HP decrements by the projectile's damage value. Projectiles carry their own damage amount — Enemy Wave receives the decrement and applies it.

11. **Enemy Death**: When `enemy_hp ≤ 0`, the enemy is removed from the active array, emits `enemy_died(world_pos: Vector2)`, and the Economy system spawns a gold collectible at that position. Enemies that die do not reach the castle.

12. **Castle Contact**: When a living enemy's distance to `CASTLE_POS` ≤ 52px (at defaults): the enemy calls `castle.take_contact_damage()`, is removed from the active array immediately. The enemy does **not** emit `enemy_died` on castle contact — no gold drops for enemies that reach the castle.

13. **Wave Completion**: A wave is complete when the active enemy array is empty AND the spawn queue for that wave is exhausted (all enemies either spawned, dead, or reached castle).

14. **Inter-Wave Pause**: After wave completion, the system waits `INTER_WAVE_PAUSE = 10.0s`. During this pause, `inter_wave_countdown` counts down from `INTER_WAVE_PAUSE` to 0 and is exposed for the HUD. When it reaches 0, `wave_number` increments and the next wave begins.

15. **Game State Gating**: Spawning, movement, contact detection, and death are active only when Game State = `PLAYING`. On `GAME_OVER`, all enemies freeze in place. On `session_reset`, the active enemy array is cleared, spawn queue cleared, wave counter resets to 1, inter-wave timer resets.

16. **Targeting Interface**: The active enemy array is accessible via `get_nearest_enemy(from_pos: Vector2) → Node` (returns `null` if no enemies). Hero auto-shoot and Archer Formation call this each frame.

---

### States and Transitions

**Wave Manager States:**

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|----------------|
| `IDLE` | Game State ≠ `PLAYING` (initial) | No spawning; counter unchanged | Game State → `PLAYING` → `SPAWNING` Wave 1 |
| `SPAWNING` | New wave begins | Spawns one enemy per `SPAWN_INTERVAL`; decrements remaining spawn count | Queue exhausted → `WAVE_ACTIVE` |
| `WAVE_ACTIVE` | Spawn queue exhausted; enemies still alive | No new spawns; tracking active array | Active array empty → `INTER_WAVE_PAUSE` |
| `INTER_WAVE_PAUSE` | Active array empty, queue exhausted | Countdown timer; exposes `inter_wave_countdown` to HUD | Timer expires → `wave_number++` → `SPAWNING` |
| `HALTED` | Game State = `GAME_OVER` | All enemies freeze; no spawns; no contact detection | `session_reset` → `IDLE` |

**Individual Enemy States:**

| State | Condition | Behavior |
|-------|-----------|----------|
| `ALIVE` | `enemy_hp > 0`; distance to castle > 52px | Moves toward `CASTLE_POS` at `ENEMY_SPEED` each frame; receives projectile damage |
| `AT_CASTLE` | `enemy_hp > 0`; distance ≤ 52px | Calls `castle.take_contact_damage()`; removed from array; no gold drop |
| `DEAD` | `enemy_hp ≤ 0` | Emits `enemy_died(world_pos)`; removed from array; Economy spawns gold |

---

### Interactions with Other Systems

| System | Interface |
|--------|-----------|
| **Game State Machine** | Reads game state to halt all activity when not `PLAYING`. Listens for `session_reset` to clear active array, reset wave counter, clear spawn queue, reset inter-wave timer. |
| **Castle** | Calls `castle.take_contact_damage()` on contact. `ENEMY_RADIUS = 12px` defined here completes Castle GDD contact formula: `52px` threshold at defaults. |
| **Economy** *(downstream)* | Emits `enemy_died(world_pos: Vector2)` on death (not on castle contact). Economy listens and spawns gold. `GOLD_DROP_PER_ENEMY` is Economy's responsibility. |
| **Hero Movement / Archer Formation** *(downstream)* | Exposes `get_nearest_enemy(from_pos: Vector2) → Node` — returns closest active enemy or `null`. Queried each frame by auto-shoot systems. |
| **HUD** *(downstream, provisional)* | Exposes `wave_number: int`, `inter_wave_countdown: float` (0 when not in pause), `active_enemy_count: int`. |

## Formulas

### Formula 1: Enemies Per Wave

`enemies_per_wave(n) = min(ENEMIES_PER_WAVE_MAX, ENEMIES_PER_WAVE_BASE + (n − 1) × ENEMIES_PER_WAVE_SCALING)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave number | `n` | int | 1–∞ | Current wave index; resets to 1 on session_reset |
| Base enemy count | `ENEMIES_PER_WAVE_BASE` | int | 3–10 | Enemy count for Wave 1 |
| Count scaling | `ENEMIES_PER_WAVE_SCALING` | int | 1–4 | Additional enemies added per wave |
| Wave cap | `ENEMIES_PER_WAVE_MAX` | int | 10–30 | Maximum enemies per wave; prevents runaway spawn duration |

**Output Range:** 5 (Wave 1) to 20 (Wave 9+ at defaults). Cap activates at Wave 9 (`5 + (9−1)×2 = 21 > 20`).

**Example values:**

| Wave | Uncapped | After cap |
|------|----------|-----------|
| 1 | 5 | 5 |
| 5 | 13 | 13 |
| 8 | 19 | 19 |
| 9 | 21 | 20 ✓ |
| 10+ | 23+ | 20 ✓ |

---

### Formula 2: Enemy HP Per Wave

`enemy_hp(n) = ENEMY_HP_BASE + (n − 1) × ENEMY_HP_SCALING`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave number | `n` | int | 1–∞ | Current wave index |
| Base HP | `ENEMY_HP_BASE` | int | 10–60 | Enemy HP for Wave 1 |
| HP scaling | `ENEMY_HP_SCALING` | int | 1–10 | Additional HP added per wave |

**Output Range:** 30 (Wave 1) to 57 (Wave 10) to 72 (Wave 15) at defaults. No explicit cap — HP scaling is the late-game difficulty lever once count is capped.

**Example:** Wave 1: `30 + 0×3 = 30 HP`. Wave 5: `30 + 4×3 = 42 HP`. Wave 10: `30 + 9×3 = 57 HP`.

**Design note:** At `PROJ_DAMAGE = 8 HP/hit` (defined in Archer Formation GDD), enemies require `ceil(57/8) = 8` hits to kill at Wave 10. With `ENEMY_SPEED = 70px/s` and spawn distance `≈1740px`, travel time ≈ 24.9s — the primary design constraint on whether archers kill enemies before castle contact. This puts Wave 10 enemies at the upper boundary of the 3–8 hit target range. Validate `ENEMY_HP_SCALING` together with `PROJ_DAMAGE` during balance tuning.

---

### Formula 3: Spawn Position

**Row assignment:**
`enemy_row = floor((enemy_index − 1) / SPAWN_ROW_CAPACITY)`

`spawn_y = SPAWN_Y_BASE − enemy_row × SPAWN_ROW_OFFSET`

`spawn_x` = randomly distributed within `[SPAWN_X_MIN, SPAWN_X_MAX]` with minimum horizontal separation `SPAWN_X_MIN_SEP = 80px` between consecutive spawns in the same row.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemy index within wave | `enemy_index` | int | 1–`enemies_per_wave` | Spawn order within the current wave (1 = first) |
| Capacity per row | `SPAWN_ROW_CAPACITY` | int | 10–20 | Max enemies per spawn row; derived from `floor(world_width / SPAWN_X_MIN_SEP)` |
| Base spawn Y | `SPAWN_Y_BASE` | float | 1800–1900 | Y coordinate of the first spawn row (bottom of world) |
| Row vertical offset | `SPAWN_ROW_OFFSET` | float | 20–60 | Vertical distance between spawn rows |
| Min X separation | `SPAWN_X_MIN_SEP` | float | 24–120 | Minimum horizontal gap between spawn X positions within a row |

**Output Range:**
- Row 0 (enemies 1–13): `spawn_y = 1860`
- Row 1 (enemies 14–20): `spawn_y = 1830`

At `ENEMIES_PER_WAVE_MAX = 20`, at most 2 spawn rows are ever needed.

**Example:** Wave 9 spawns 20 enemies. Enemies 1–13 get `spawn_y = 1860`; enemies 14–20 get `spawn_y = 1830`. Both rows march toward `CASTLE_POS = (540, 120)` with individually computed directions.

**Derived constant:** `SPAWN_ROW_CAPACITY = floor(1080 / 80) = 13`

---

### Formula 4: Spawn Duration

`spawn_duration(n) = (enemies_per_wave(n) − 1) × SPAWN_INTERVAL`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Enemies this wave | `enemies_per_wave(n)` | int | 5–20 | From Formula 1 |
| Spawn interval | `SPAWN_INTERVAL` | float | 0.5–4.0s | Delay between consecutive enemy spawns within a wave |

**Output Range:** 8s (Wave 1, 5 enemies) to 38s (Wave 9+, 20 enemies, capped). After the cap activates, spawn_duration is fixed at 38s regardless of wave number.

**Example:** Wave 1: `(5−1) × 2.0 = 8s`. Wave 9+: `(20−1) × 2.0 = 38s`.

---

### Derived Design Target: Castle Lifespan

Not a formula owned by Enemy Wave — this is a cross-system design constant documented here for transparency:

`max_contacts = CASTLE_MAX_HP / CASTLE_DMG = 200 / 8 = 25 contacts before castle falls`

At `ENEMIES_PER_WAVE_BASE = 5` and `CASTLE_DMG = 8`, Garrison runs are designed to last approximately **Wave 10–15** under normal play, with the castle falling when cumulative enemy leakage exceeds 25 contacts. This is intentional — Garrison is a **score-attack game**. The castle is a countdown, not a health bar to protect indefinitely. The enemy count cap (`ENEMIES_PER_WAVE_MAX = 20`) controls the difficulty ceiling; the castle HP controls the run duration. Tune both together.

## Edge Cases

- **If an enemy is killed by a projectile on the same frame it contacts the castle**: The projectile hit resolves first (enemy HP → 0, enemy removed from array, `enemy_died` emitted, gold drops). Castle contact check runs after — since the enemy is already removed, no contact damage is applied. **No double-processing.** This ordering (projectile resolution before contact check) must be enforced by the Enemy Wave update loop. This resolves the open ordering question flagged in the Castle GDD.

- **If two enemies contact the castle in the same frame**: Both contact events fire independently. Castle takes `CASTLE_DMG × 2 = 16 HP` damage in the same frame. Castle GDD handles this correctly — its suppression flag only prevents duplicate `castle_fell` signals, not duplicate damage. Both enemies are removed from the active array.

- **If `session_reset` fires while enemies are mid-march**: The active enemy array is cleared immediately. All enemies are removed regardless of position. Spawn queue is flushed. `wave_number` resets to 1. The inter-wave pause timer resets. No `enemy_died` signal is emitted for cleared enemies — no gold drops on reset.

- **If `GAME_OVER` fires while enemies are in the `SPAWNING` or `WAVE_ACTIVE` state**: All enemies freeze in place (movement stops). The spawn queue halts. No new enemies spawn. No contact detection runs. Enemies remain in scene visually (frozen) until `session_reset` clears them.

- **If all enemies in a wave die simultaneously** (e.g., area-effect kill in future expansions): The active array becomes empty. Wave completion condition is met. `INTER_WAVE_PAUSE` begins immediately. No degenerate behavior — this is the normal completion path, just faster than expected.

- **If the spawn X assignment exhausts all valid positions in a row** (all 13 slots occupied by `SPAWN_X_MIN_SEP = 80px` spacing): The spawner falls through to the next row. At defaults (`ENEMIES_PER_WAVE_MAX = 20`, 2 rows × 13 capacity = 26 total slots), this cannot overflow — the cap ensures at most 20 enemies, well within 26 slots.

- **If `ENEMIES_PER_WAVE_MAX` is set lower than `ENEMIES_PER_WAVE_BASE`** (misconfiguration): `min(MAX, BASE) = MAX` on every wave. All waves spawn below intended base count. Not a crash, but a logical error. Minimum safe value: `ENEMIES_PER_WAVE_MAX ≥ ENEMIES_PER_WAVE_BASE`.

- **If `ENEMY_HP_BASE` is set to 0 or negative**: Enemies spawn with 0 or negative HP and die on first projectile hit (or immediately on spawn). Minimum safe value: `ENEMY_HP_BASE ≥ 1`.

- **If `SPAWN_INTERVAL = 0`**: All enemies in the wave spawn simultaneously at wave start. Severe visual clustering, no staggered entry. Minimum safe value: `SPAWN_INTERVAL ≥ 0.5s`.

- **If `get_nearest_enemy()` is called when active enemy array is empty**: Returns `null`. All callers (hero auto-shoot, Archer Formation) must handle `null` gracefully by suppressing fire for that frame.

- **If `SPAWN_Y_BASE` is set at or near `CASTLE_POS.y`**: Enemies contact the castle on the first frame of spawning. Minimum safe value for `SPAWN_Y_BASE`: `CASTLE_POS.y + 200px = 320px` (though defaults set it to 1860, far from the castle at 120).

## Dependencies

**Upstream dependencies:**

| System | What Enemy Wave needs | Hard/Soft |
|--------|----------------------|-----------|
| Game State Machine | Current state (`PLAYING`/other); `session_reset` signal | Hard |
| Castle | `CASTLE_POS: Vector2 = (540, 120)` and `CASTLE_RADIUS: float = 40px` — contact threshold requires both | Hard |

**Downstream dependents:**

| System | What they consume from Enemy Wave |
|--------|-----------------------------------|
| Castle | `castle.take_contact_damage()` called on enemy contact; `ENEMY_RADIUS = 12px` defined here (completes Castle GDD contact formula) |
| Economy | `enemy_died(world_pos: Vector2)` signal — triggers gold collectible spawn at death position |
| Hero Movement | `get_nearest_enemy(from_pos: Vector2) → Node` — targeting interface for hero auto-shoot |
| Archer Formation | `get_nearest_enemy(from_pos: Vector2) → Node` — targeting interface for archer auto-shoot |
| HUD *(provisional)* | `wave_number: int`, `inter_wave_countdown: float`, `active_enemy_count: int` — wave status display |

**Note on the Castle relationship:** Enemy Wave and Castle have a tight bidirectional interface. Castle GDD declared `ENEMY_RADIUS` as TBD pending this GDD — it is now defined as `12px`. The contact threshold `52px` (`CASTLE_RADIUS + ENEMY_RADIUS = 40 + 12`) is now fully resolved.

**Note on the projectile damage interface:** Enemy Wave receives projectile damage decrements but does not own projectile damage values. The projectile carries its own `damage` amount and calls `enemy.take_damage(damage)` on hit. Enemy Wave does not need to know the source — only the numeric decrement.

## Tuning Knobs

| Knob | Default | Safe Range | Effect if too low / too high |
|------|---------|------------|------------------------------|
| `ENEMY_SPEED` | 70px/s | 40–150px/s | Too low: enemies crawl — tension collapses, inter-wave pauses feel disconnected from threat. Too high: enemies reach castle before archers have time to fire — wave becomes a timer more than a combat challenge. At 70px/s travel time ≈ 24.9s; at 140px/s ≈ 12.4s (half the archer firing window). |
| `ENEMIES_PER_WAVE_BASE` | 5 | 3–10 | Too low: Wave 1 feels trivial, no pressure to act. Too high: overwhelming difficulty before the player has any archers. |
| `ENEMIES_PER_WAVE_SCALING` | 2 | 1–4 | Too low: wave size grows slowly — mid-game waves feel samey. Too high: cap is reached too quickly, HP scaling carries all difficulty. |
| `ENEMIES_PER_WAVE_MAX` | 20 | 10–30 | Too low: waves feel identical at mid-game. Too high: spawn duration balloons (each +2 enemies = +4s; at cap 30 → 58s per wave). |
| `ENEMY_HP_BASE` | 30 | 10–60 | Too low: Wave 1 enemies die in one hit — no threat, archers irrelevant. Too high: hero can't contribute to kills early, gold earning is slow. |
| `ENEMY_HP_SCALING` | 3 | 1–10 | Too low: enemies never become threatening at Wave 15. Too high: enemies outpace archer damage growth rapidly. **Cross-knob**: validate against `PROJ_DAMAGE` (8 HP, owned by Archer Formation) — target is enemies requiring 3–8 hits through Wave 10 (Wave 10: ceil(57/8) = 8 hits at default). |
| `SPAWN_INTERVAL` | 2.0s | 0.5–4.0s | Too low: enemies flood the screen, all reach castle. Too high: wave spawning drags out, encounters feel disconnected. |
| `INTER_WAVE_PAUSE` | 10.0s | 5–20s | Too low: not enough time to spend gold or reposition. Too high: tension dissipates, "one more wave" momentum collapses. The player should feel "not enough time, but almost enough." |
| `SPAWN_Y_BASE` | 1860 | 1600–1900 | Too low (closer to center): enemies appear close — hero can't intercept proactively. Too high (past world edge): enemies invisible too long after spawn. |
| `SPAWN_ROW_OFFSET` | 30px | 20–60px | Too small: rows visually overlap (min 2 × ENEMY_RADIUS = 24px). Too large: rows appear as two distinct waves rather than one spread horde. |
| `SPAWN_X_MIN_SEP` | 80px | 24–120px | Too small (below 24px): enemies overlap at spawn. Too large: enemies cluster in a narrow column, too easy to intercept. |
| `ENEMY_RADIUS` | 12px | 8–20px | Too small: collision feels imprecise. Too large: enemies block each other and castle contact triggers from too far away. Changing this requires updating Castle GDD contact threshold. |

**Cross-knob interaction: ENEMY_HP_SCALING × PROJ_DAMAGE × ENEMIES_PER_WAVE_MAX**

These three determine when the game shifts from "archer formation can kill everything" to "some enemies will always reach the castle." This shift is the central difficulty escalation of Garrison. Target: shift happens between Wave 8–12 at default tuning. Validate together in first playtest (PROJ_DAMAGE = 8 HP locked in entities.yaml, owned by Archer Formation).

**Cross-knob interaction: ENEMIES_PER_WAVE_MAX × INTER_WAVE_PAUSE × Castle lifespan**

Maximum castle lifespan = `CASTLE_MAX_HP / CASTLE_DMG = 25 contacts`. If `ENEMIES_PER_WAVE_MAX` is increased without increasing castle HP, runs shorten (more leakage per wave). If `INTER_WAVE_PAUSE` is decreased, players recruit fewer archers, leakage starts earlier. Tune all three together to hit the ~10–15 wave run target.

## Acceptance Criteria

### Wave Manager

- **GIVEN** Game State transitions to `PLAYING`, **WHEN** the first frame of `PLAYING` is processed, **THEN** `wave_number` equals 1 and the first enemy spawn event fires within that frame.
- **GIVEN** Wave N is complete (active array empty AND spawn queue exhausted), **WHEN** wave-complete is detected, **THEN** `inter_wave_countdown` begins counting down from 10.0s and the next wave does not begin spawning until `inter_wave_countdown` reaches 0.
- **GIVEN** `inter_wave_countdown` reaches 0 after Wave N, **WHEN** the pause expires, **THEN** `wave_number` increments by exactly 1 and spawning for Wave N+1 begins immediately.
- **GIVEN** the active array is empty but the spawn queue still contains enemies, **WHEN** wave-complete is evaluated, **THEN** the wave is NOT marked complete and `inter_wave_countdown` does not start.
- **GIVEN** `session_reset` fires at any point, **WHEN** reset completes, **THEN** `wave_number = 1`, active enemy array is empty, spawn queue is empty, and `inter_wave_countdown` is not running.

### Enemy Spawning

- **GIVEN** Wave N begins, **WHEN** the spawn queue is built, **THEN** total enemies queued equals `min(20, 5 + (N−1) × 2)`. Spot checks: Wave 1 = 5, Wave 5 = 13, Wave 9 = 20 (capped; not 21).
- **GIVEN** a wave is spawning enemies at index 1–13, **WHEN** each spawns, **THEN** `spawn_y = 1860` and `spawn_x ∈ [60, 1020]`.
- **GIVEN** a wave spawns enemy at index 14 or higher, **WHEN** that enemy spawns, **THEN** `spawn_y = 1830`.
- **GIVEN** a wave is in progress, **WHEN** consecutive enemies spawn, **THEN** time between consecutive spawns is exactly 2.0s.
- **GIVEN** Game State ≠ `PLAYING`, **WHEN** a spawn timer would fire, **THEN** no enemy spawns and the queue is unchanged.

### Enemy Movement

- **GIVEN** an enemy spawns at `(spawn_x, spawn_y)`, **WHEN** its direction is computed, **THEN** `direction = ((540, 120) − (spawn_x, spawn_y)).normalized()` and this vector never changes for that enemy's lifetime.
- **GIVEN** an enemy is moving during `PLAYING`, **WHEN** 1 second of in-game time elapses, **THEN** the enemy has moved exactly 70 pixels along its stored direction.
- **GIVEN** the hero moves or acts while enemies are marching, **WHEN** enemy positions update each frame, **THEN** no enemy changes direction or speed in response.
- **GIVEN** Game State → `GAME_OVER` while enemies are moving, **WHEN** the state change is processed, **THEN** all enemy positions stop updating on subsequent frames and no new spawns occur.

### Enemy Death

- **GIVEN** an enemy with `hp > 0` is struck by a projectile with `damage = D`, **WHEN** the hit is processed, **THEN** `enemy.hp` decrements by exactly D.
- **GIVEN** an enemy's `hp` reaches ≤ 0 from a projectile hit, **WHEN** death is processed, **THEN** the enemy is removed from the active array, `enemy_died(world_pos)` emits exactly once, and the Economy system spawns gold at `world_pos`.
- **GIVEN** `session_reset` fires while enemies are mid-march with `hp > 0`, **WHEN** reset is processed, **THEN** the active array is cleared immediately, `enemy_died` is NOT emitted for any cleared enemy, and no gold drops.

### Castle Contact

- **GIVEN** an enemy's distance to `(540, 120)` becomes ≤ 52px with `enemy_hp > 0`, **WHEN** contact is detected, **THEN** `castle.take_contact_damage()` is called exactly once, the enemy is removed from the active array, and `enemy_died` is NOT emitted.
- **GIVEN** two enemies simultaneously reach ≤ 52px from `(540, 120)` in the same frame, **WHEN** contact resolves, **THEN** `castle.take_contact_damage()` is called exactly twice and both enemies are removed.
- **GIVEN** in a single frame an enemy is hit by a projectile reducing `hp ≤ 0` AND simultaneously within 52px of the castle, **WHEN** both conditions evaluate, **THEN** projectile hit resolves first (enemy removed, `enemy_died` emitted, gold spawned) and no castle contact fires for that enemy.

### State Transitions

- **GIVEN** Game State ≠ `PLAYING`, **WHEN** any frame is processed, **THEN** no spawning event fires, no enemy position updates, and no castle contact check runs.
- **GIVEN** Game State is `PLAYING` and enemies are actively spawning and moving, **WHEN** Game State → `GAME_OVER`, **THEN** all enemies freeze in place, spawning halts, and no further contact checks evaluate.

### Targeting Interface

- **GIVEN** the active enemy array contains at least one enemy, **WHEN** `get_nearest_enemy(from_pos)` is called, **THEN** the returned Node is the enemy whose world position has the smallest Euclidean distance to `from_pos`.
- **GIVEN** the active enemy array is empty, **WHEN** `get_nearest_enemy(from_pos)` is called, **THEN** the return value is `null`.

### Formula Verification

- **GIVEN** Wave 1 begins, **WHEN** spawn queue is built, **THEN** `enemies_per_wave = 5`. **GIVEN** Wave 5, **THEN** `enemies_per_wave = 13`. **GIVEN** Wave 9, **THEN** `enemies_per_wave = 20` (not 21 — cap enforced). **GIVEN** Wave 15, **THEN** `enemies_per_wave = 20` (cap still applies).
- **GIVEN** enemies spawn in Wave 1, **WHEN** HP is set, **THEN** `enemy_hp = 30`. In Wave 5: `enemy_hp = 42`. In Wave 10: `enemy_hp = 57`.
- **GIVEN** Wave 5 spawns exactly 13 enemies, **WHEN** all are spawned, **THEN** all 13 have `spawn_y = 1860` and none have `spawn_y = 1830` (row 1 not triggered at the boundary).
- **GIVEN** Wave 1 begins spawning at t=0, **WHEN** the last (5th) enemy spawns, **THEN** it spawns at exactly t=8.0s. **GIVEN** Wave 9 begins at t=0, **WHEN** the last (20th) enemy spawns, **THEN** it spawns at exactly t=38.0s.

## Open Questions

- **Projectile damage values undefined**: Acceptance criteria AC-DT-01 uses `damage = D` as a placeholder. The projectile's damage amount is not defined in this GDD. Owner: Archer Formation GDD (archer projectile damage) and Hero Movement GDD (hero auto-shoot damage). Target: both GDDs.

- **Frame-ordering guarantee (projectile vs castle contact)**: Edge Case 1 specifies that projectile hit resolves before castle contact check in the same frame. This must be enforced by explicit code ordering in the Enemy Wave update loop — not assumed from engine behavior. Flag for ADR consideration during architecture phase.

- **`SPAWN_X_MIN = 60` and `SPAWN_X_MAX = 1020` missing from Tuning Knobs**: Defined in acceptance criteria and Formulas but absent from the Tuning Knobs table. Should be added if a designer may want to narrow or widen the spawn band before production. Owner: this GDD (minor update).

- **`ENEMY_HP_SCALING` vs. `PROJ_DAMAGE` cross-validation**: `ENEMY_HP_SCALING = 3/wave` targets "3–8 hits to kill through Wave 10." `PROJ_DAMAGE = 8 HP/hit` (Archer Formation GDD) gives `ceil(57/8) = 8` hits at Wave 10 — right at the boundary. If `PROJ_DAMAGE` is tuned, recalculate hits-to-kill across wave range. Owner: balance tuning. Target: first playtest session.

- **`STARTING_GOLD` undefined**: Wave 1 is hero-solo until first enemy kill if starting gold = 0. This shapes Enemy Wave difficulty but is Economy GDD territory. Owner: Economy GDD (next in design order). Target: Economy GDD.

- **Enemy freeze visual on `GAME_OVER`**: When enemies freeze, should they play a stop animation or simply halt? Presentation concern — not an Enemy Wave data concern. Owner: art direction. Target: art bible.
