# Archer Formation

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-20
> **Implements Pillar**: Pillar 3 — L'armée se voit grandir | Pillar 1 — Un seul doigt, zéro friction

## Overview

The Archer Formation system manages a pool of up to 8 archer units that follow the hero in a V-shaped formation and automatically fire projectiles at the nearest enemy. It operates on two layers: a **data layer** (slot indexing, lerp-based position interpolation from `hero_pos` and `facing_angle`, and a shared shoot timer) and a **player-facing layer** (the visually prominent, growing army that embodies Pillar 3 — *L'armée se voit grandir*). At session start, two archers occupy slots 0–1; additional archers join when the player spends gold in a recruitment zone (Economy). All archers share a single fire timer (`SHOOT_IVTL = 0.9 s`) synchronized with the hero, producing a unified volley rather than staggered individual shots. In MVP, all archers remain mobile with the hero; archer-to-tower transfer is deferred to Vertical Slice.

## Player Fantasy

The player feels like a general on the move, their growing warband sweeping across the battlefield at their heels. Each archer added to the formation is a tangible, permanent reward — a visible upgrade that reinforces every gold-collection decision made in the chaos of a wave. At two archers the hero feels exposed; at eight, the V-formation fills the screen and volleys erupt with every shared fire-timer tick, turning the tide through sheer visual and mechanical dominance. The fantasy is *expansion without effort*: the player never taps an archer directly, never aims a shot — they position well, recruit often, and watch their force multiply. This aligns with Pillar 1 (*Un seul doigt, zéro friction* — one thumb drives the whole army) and makes Pillar 3 (*L'armée se voit grandir*) emotionally legible in every wave.

*Note: creative-director not consulted — Lean mode. Review manually before production.*

## Detailed Design

### Core Rules

1. **Slot pool**: The formation has 8 slots (indices 0–7). A slot is either EMPTY or OCCUPIED by one archer. At session start, slots 0–1 are OCCUPIED (`STARTING_ARCHERS = 2`); slots 2–7 are EMPTY.

2. **Slot fill order**: Slots fill sequentially from index 0 upward. On `recruit_purchased`, the lowest-index EMPTY slot becomes OCCUPIED. Slots are never skipped or reordered.

3. **Capacity cap**: When all 8 slots are OCCUPIED (`current_archer_count = 8`), `recruit_purchased` signals are ignored. Economy queries `current_archer_count` before activating a recruitment zone and suppresses it at capacity.

4. **Formation geometry**: Each slot has a local V-formation offset from the hero, organized in 4 lateral pairs. Offsets are rotated by `facing_angle` each frame:
   `slot_world_pos = hero_pos + slot_local_offset.rotated(facing_angle)`

   | Pair | Slots | Lateral (±, local) | Depth (back, local) |
   |------|-------|--------------------|---------------------|
   | 1 | 0, 1 | ±`ARCHER_INNER_SEP` | `ARCHER_ROW_DEPTH × 1` |
   | 2 | 2, 3 | ±`ARCHER_MID_SEP` | `ARCHER_ROW_DEPTH × 2` |
   | 3 | 4, 5 | ±`ARCHER_OUTER_SEP` | `ARCHER_ROW_DEPTH × 3` |
   | 4 | 6, 7 | ±`ARCHER_OUTERMOST_SEP` | `ARCHER_ROW_DEPTH × 4` |

   Exact pixel values are tuning knobs (see Section G). The 8-slot V layout was validated as readable in prototype 1.

5. **Follow behavior**: Each occupied archer lerps toward its slot world position every frame:
   `archer_pos = lerp(archer_pos, slot_world_pos, ARCHER_FOLLOW_LERP)`
   `ARCHER_FOLLOW_LERP = 0.12` (validated in prototype 1). Unoccupied slots have no visible node and perform no computation.

6. **Shared target acquisition**: Each frame, the formation selects the nearest enemy to `hero_pos` with HP > 0 as the shared target. All occupied archers target the same enemy. If no valid enemy exists, `shared_target` is `null`.

7. **Shared fire timer and volley**: A single `SHOOT_IVTL = 0.9 s` timer is shared by the hero and all archers. On each timer tick: if `shared_target != null`, every OCCUPIED slot fires one projectile from its current `archer_pos` toward `shared_target.position`. If `shared_target == null`, no projectiles are emitted. **More archers = more projectiles per volley, not a higher fire rate.**

8. **Projectile travel**: Each projectile is a kinematic body traveling at `PROJ_SPEED` px/s toward `shared_target.position` at the moment of firing. On contact with any enemy, the projectile deals `PROJ_DAMAGE` HP and is freed. Projectiles are freed on exit from world bounds (`0 ≤ x ≤ 1080`, `0 ≤ y ≤ 1920`).

9. **Formation permanence**: Archers have no individual HP or death mechanic in MVP. Slots are only cleared by session reset.

10. **Session reset**: On `game_over` or `session_restart` from Game State Machine, all slots clear and the formation returns to start state (slots 0–1 OCCUPIED, 2–7 EMPTY). Both `targeting_mode` and `formation_mode` reset to their defaults (`NEAREST`, `V_FORMATION`).

---

### Targeting Priority System (Sprint 5)

11. **Targeting mode (`TargetingMode` enum)**: The formation maintains a `TargetingMode` that determines how `shared_target` is selected each frame. Four modes:
   - `NEAREST` (default): enemy with minimum `distance(enemy.position, hero_pos)` — HP > 0. Unchanged MVP behavior.
   - `FIRST`: enemy with minimum `distance(enemy.position, CASTLE_POS)` — HP > 0. Prioritizes the greatest threat to the castle.
   - `STRONGEST`: enemy with maximum current `hp` — HP > 0. Concentrates fire on the toughest active enemy.
   - `WEAKEST`: enemy with minimum current `hp` (HP > 0, ties broken by lowest entity ID). Maximizes kill throughput by finishing near-dead enemies.

   All modes produce a single shared target; all archers fire at the same enemy — no split fire.

12. **Targeting mode unlock and switching**: Targeting mode cycling is locked to `NEAREST` until the "Targeting Protocol" Forge upgrade is purchased. Once unlocked, a `TARGETING_ZONE` dwell zone appears at world position `TARGETING_ZONE_POS`. Hero dwells inside for `TARGETING_DWELL = 0.6 s` → mode cycles: NEAREST → FIRST → STRONGEST → WEAKEST → NEAREST. Economy owns the zone and emits `targeting_mode_cycled(new_mode: TargetingMode)`. Archer Formation listens and updates `current_targeting_mode`. Without the upgrade the zone does not appear; dwelling at that position has no effect.

13. **Targeting mode persistence**: `current_targeting_mode` persists for the duration of a session. Resets to `NEAREST` on `session_restart` or `game_over`.

---

### Tactical Formations System (Sprint 5)

14. **Formation mode (`FormationMode` enum)**: The formation maintains a `FormationMode` that determines slot world position geometry. Three modes:
   - `V_FORMATION` (default): V-shape geometry (rules 3–4, formula D-5).
   - `LINE`: all 8 slots in a single row perpendicular to the facing direction (formula D-8).
   - `ARC`: slots on a semicircle of radius `ARC_RADIUS` behind the hero (formula D-9).

15. **Formation mode unlock and switching**: Formation mode cycling is locked to `V_FORMATION` until the "Formation Doctrine" Forge upgrade is purchased. Once unlocked, a `FORMATION_ZONE` dwell zone appears at world position `FORMATION_ZONE_POS`. Hero dwells for `FORMATION_DWELL = 0.6 s` → cycles V → LINE → ARC → V. Economy owns the zone and emits `formation_mode_cycled(new_mode: FormationMode)`. Archer Formation updates `current_formation_mode` and immediately recomputes all slot world positions. Without the upgrade the zone does not appear.

16. **LINE formation geometry**: All 8 slots placed in a single row at depth `LINE_DEPTH` behind the hero, perpendicular to the facing axis:
   `slot_world_pos_LINE(i) = hero_pos + behind × (HERO_RADIUS + LINE_DEPTH) + right × (side(i) × LINE_LATERAL_STEP × (pair(i) + 1))`
   Result: 8 archers in a row 58 px behind hero center, spaced 50 px apart laterally. Bounding box: 200 × 58 px. Concentrates all firepower along a single front — effective for choke points.

17. **ARC formation geometry**: Slots placed on a semicircle of radius `ARC_RADIUS` behind and to the sides of the hero:
   `slot_world_pos_ARC(i) = hero_pos + (behind × cos(ARC_ANGLE_STEP × slot_offset(i)) + right × sin(ARC_ANGLE_STEP × slot_offset(i))) × ARC_RADIUS`
   Where `slot_offset(i) = side(i) × (pair(i) + 1)` (range −4 to +4).
   Innermost slots (0,1) at ±22.5° from the behind vector; outermost slots (6,7) at ±90° from behind, flanking the hero directly to the sides. Arc bounding radius: 80 px. Effective against enemies approaching from multiple angles simultaneously.

---

### States and Transitions

**Per-slot states:**

| State | Condition | Visual |
|-------|-----------|--------|
| EMPTY | slot index ≥ `current_archer_count` | No archer node present |
| OCCUPIED | slot index < `current_archer_count` | Archer node active, lerping each frame |

Transition: EMPTY → OCCUPIED on `recruit_purchased` (lowest-index empty slot). OCCUPIED → EMPTY on session reset only.

**Formation-wide fire timer:**

| State | Condition |
|-------|-----------|
| FIRE_COOLDOWN | `shoot_timer > 0` |
| FIRE_READY | `shoot_timer ≤ 0` — volley fires if `shared_target != null`; timer resets to `SHOOT_IVTL` |

**Formation session state:**

| State | Trigger |
|-------|---------|
| ACTIVE | Session running — archers follow and shoot |
| RESETTING | `game_over` / `session_restart` received — clears all slots, re-occupies 0–1 |

**Targeting mode state (Sprint 5):**

| Mode | Selection Rule | Unlock |
|------|---------------|--------|
| NEAREST (default) | `min distance(enemy.position, hero_pos)` — HP > 0 | Always active |
| FIRST | `min distance(enemy.position, CASTLE_POS)` — HP > 0 | Forge: Targeting Protocol |
| STRONGEST | `max enemy.hp` — HP > 0 | Forge: Targeting Protocol |
| WEAKEST | `min enemy.hp` — HP > 0, entity ID tiebreak | Forge: Targeting Protocol |

Transition: any mode → any mode via `targeting_mode_cycled` signal from Economy (Forge-gated). Reset to NEAREST on `session_restart` or `game_over`.

**Formation mode state (Sprint 5):**

| Mode | Geometry | Unlock |
|------|---------|--------|
| V_FORMATION (default) | Formula D-5 — V-shape | Always active |
| LINE | Formula D-8 — single row | Forge: Formation Doctrine |
| ARC | Formula D-9 — semicircle | Forge: Formation Doctrine |

Transition: V → LINE → ARC → V via `formation_mode_cycled` signal from Economy (Forge-gated). Reset to V_FORMATION on `session_restart` or `game_over`.

---

### Interactions with Other Systems

| Direction | System | Data | When |
|-----------|--------|------|------|
| ← Read | Hero Movement | `hero_pos: Vector2`, `facing_angle: float` | Each frame |
| ← Event | Hero Movement | Shared `SHOOT_IVTL` timer tick | Every 0.9 s |
| ← Signal | Economy | `recruit_purchased` | On player purchase |
| ← Read | Enemy Wave | Enemy positions + HP values | Each frame (target acquisition) |
| ← Signal | Game State Machine | `game_over`, `session_restart` | On state change |
| ← Signal | Archer Tower | `tower_purchased` | On tower purchase — release TOWER_ARCHERS_COUNT (2) occupied slots to tower |
| ← Signal | Economy | `targeting_mode_cycled(new_mode)` | Sprint 5 — updates `current_targeting_mode` |
| ← Signal | Economy | `formation_mode_cycled(new_mode)` | Sprint 5 — updates `current_formation_mode`, recomputes slot positions |
| ← Signal | Forge | `targeting_protocol_purchased` | Sprint 5 — unlocks TARGETING_ZONE (informs Economy to activate zone) |
| ← Signal | Forge | `formation_doctrine_purchased` | Sprint 5 — unlocks FORMATION_ZONE (informs Economy to activate zone) |
| → Expose | Economy | `current_archer_count: int` | Each frame (cost tier lookup) |
| → Expose | HUD | `current_archer_count: int` | Each frame (archer counter) |
| → Expose | HUD | `current_targeting_mode: TargetingMode` | Sprint 5 — HUD displays mode indicator |
| → Expose | HUD | `current_formation_mode: FormationMode` | Sprint 5 — HUD displays formation indicator |
| → Apply | Enemy Wave | `PROJ_DAMAGE` applied to target enemy HP | On volley fire |

*Note: Specialist agents not consulted — Lean mode. Review manually before production.*

## Formulas

### D-1 — volley_damage(n)

`volley_damage(n) = n × PROJ_DAMAGE`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Active archers | n | int | 1–8 | Number of OCCUPIED formation slots |
| Projectile damage | PROJ_DAMAGE | constant (int) | fixed at **8** | HP removed from target on one archer's projectile impact |

**Output Range:** 8 (n=1) to 64 (n=8). Linear — each slot adds exactly PROJ_DAMAGE per volley.

**Example:** 5 archers occupied → `volley_damage(5) = 5 × 8 = 40 HP` per volley tick.

---

### D-2 — formation_dps(n)

`formation_dps(n) = (n × PROJ_DAMAGE) / SHOOT_IVTL`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Active archers | n | int | 1–8 | Occupied slots |
| Projectile damage | PROJ_DAMAGE | constant | 8 | Per-archer hit |
| Shared fire interval | SHOOT_IVTL | constant (float, s) | fixed at **0.9 s** | Shared timer; all archers fire simultaneously |

**Output Range:**

| n | formation_dps |
|---|--------------|
| 2 | ~17.78 |
| 4 | ~35.56 |
| 6 | ~53.33 |
| 8 | ~71.11 |

Each additional archer adds exactly `8/0.9 ≈ 8.89 DPS`. No diminishing return in DPS — diminishing return emerges from enemy count (formation DPS is fixed, enemies continue spawning).

**Example:** n=4 → `formation_dps(4) = 32 / 0.9 ≈ 35.56 DPS`.

---

### D-3 — time_to_kill(n, wave)

`time_to_kill(n, wave) = enemy_hp(wave) / formation_dps(n)`

Expanding: `time_to_kill(n, wave) = (ENEMY_HP_BASE + (wave − 1) × ENEMY_HP_SCALING) / ((n × PROJ_DAMAGE) / SHOOT_IVTL)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Active archers | n | int | 1–8 | Occupied slots |
| Wave number | wave | int | 1–13 | Current wave index |
| ENEMY_HP_BASE | — | constant | 30 | Wave 1 enemy HP (registry) |
| ENEMY_HP_SCALING | — | constant | 3 HP/wave | Additive scaling (registry) |
| PROJ_DAMAGE | — | constant | 8 | Per-archer hit |
| SHOOT_IVTL | — | constant | 0.9 s | Shared timer |

**Sample table (seconds to kill one enemy):**

| | Wave 1 (30 HP) | Wave 5 (42 HP) | Wave 10 (57 HP) | Wave 13 (66 HP) |
|---|---|---|---|---|
| **n=2** | 1.69 s | 2.36 s | 3.21 s | 3.71 s |
| **n=4** | 0.84 s | 1.18 s | 1.61 s | 1.86 s |
| **n=6** | 0.56 s | 0.79 s | 1.07 s | 1.24 s |
| **n=8** | 0.42 s | 0.59 s | 0.80 s | 0.93 s |

All values are well below the ~25 s enemy travel time. The bottleneck is enemy count, not per-enemy tankiness — intended.

**Example:** n=4, wave=10 → enemy_hp = 30+9×3 = 57; formation_dps ≈ 35.56 → `time_to_kill ≈ 1.61 s`.

---

### D-4 — wave_clear_dps_requirement(wave)

`wave_clear_dps_requirement(wave) = total_wave_hp(wave) / TRAVEL_TIME`

Where `total_wave_hp(wave) = enemies_per_wave(wave) × enemy_hp(wave)` and `TRAVEL_TIME = TRAVEL_DISTANCE / ENEMY_SPEED ≈ 25 s`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave number | wave | int | 1–13 | — |
| enemies_per_wave(wave) | — | formula | 5–20 | From enemy-wave.md registry |
| enemy_hp(wave) | — | formula | 30–66 | From enemy-wave.md registry |
| TRAVEL_DISTANCE | — | constant (px) | 1760 | Spawn y≈1860 to castle y≈100 |
| ENEMY_SPEED | — | constant (px/s) | 70 | Registry |
| TRAVEL_TIME | — | derived (s) | ≈25 | 1760 / 70 — use 25 s in design arithmetic |

**Required DPS vs formation capability:**

| Wave | Req. DPS | n=2 (17.8) | n=4 (35.6) | n=6 (53.3) | n=8 (71.1) |
|------|----------|-----------|-----------|-----------|-----------|
| 1 | 6.0 | OK | OK | OK | OK |
| 5 | 21.8 | **FAIL** | OK | OK | OK |
| 7 | 32.6 | FAIL | OK | OK | OK |
| 9 | 43.2 | FAIL | **FAIL** | OK | OK |
| 11 | 48.0 | FAIL | FAIL | Marginal | OK |
| 13 | 52.8 | FAIL | FAIL | Marginal | OK |

n=2 collapses at wave 5 — the player must recruit by then. n=6 is intentionally marginal at waves 11–13 (motivates the final Tier 2 recruits). n=8 always wins — the full-army reward must feel decisive.

**Example:** Wave 9 → `total_wave_hp = 20×54 = 1080; required_dps = 1080/25 = 43.2`. Needs at least n=6.

---

### D-5 — slot_world_pos(i, hero_pos, facing_angle)

`slot_world_pos(i) = hero_pos + behind × (HERO_RADIUS + ARCHER_ROW_DEPTH × (pair(i) + 1)) + right × (side(i) × lateral_sep[pair(i)])`

Where:
- `pair(i) = i // 2` → pairs 0,1,2,3 (slot 0→pair 0, slot 2→pair 1, slot 4→pair 2, slot 6→pair 3)
- `side(i) = -1 if i%2==0 else +1` → left/right
- `behind = Vector2(-sin(facing_angle), -cos(facing_angle))` — unit vector opposite to facing
- `right = Vector2(cos(facing_angle), -sin(facing_angle))` — perpendicular lateral axis

**Variables:**

| Variable | Symbol | Type | Default | Description |
|----------|--------|------|---------|-------------|
| Slot index | i | int | 0–7 | Even = left wing, odd = right wing |
| Hero position | hero_pos | Vector2 (px) | runtime | Hero centre |
| Facing angle | facing_angle | float (rad) | runtime | Hero movement direction |
| HERO_RADIUS | — | constant (px) | 18 | Gap before first pair |
| ARCHER_ROW_DEPTH | — | constant (px) | **30** | Depth step per pair |
| ARCHER_INNER_SEP | lateral_sep[0] | constant (px) | **25** | Pair 0 lateral offset |
| ARCHER_MID_SEP | lateral_sep[1] | constant (px) | **50** | Pair 1 lateral offset |
| ARCHER_OUTER_SEP | lateral_sep[2] | constant (px) | **75** | Pair 2 lateral offset |
| ARCHER_OUTERMOST_SEP | lateral_sep[3] | constant (px) | **100** | Pair 3 lateral offset |

Formation bounding box: 200 px wide (2×100) × 138 px deep (18 + 30×4). Fits comfortably in 1080 px world.

**Example:** Hero at (540, 960), facing up (facing_angle=0), slot 6 (pair 3, left):
`behind=(0,-1)`, `right=(1,0)`, depth=18+30×4=138 px, lateral=-100 px
→ `slot_world_pos(6) = (540,960) + (0,-138) + (-100,0) = (440, 822)`.

---

### D-6 — PROJ_SPEED

`PROJ_SPEED = 600 px/s`

Derived from: minimum speed to cross 300 px in ≤0.5 s = 300/0.5 = 600 px/s. At this speed, a projectile fired at a target 300 px away arrives in 0.5 s, during which an enemy moving at 70 px/s moves only 35 px — lead compensation optional. Values below 400 px/s feel visually floaty; values above 900 px/s risk single-frame invisibility at 60 fps. PROJ_SPEED is a feel constant with no balance consequences (damage applies on collision, not per-second).

---

---

### D-7 — targeting_select(mode, enemy_pool) (Sprint 5)

Returns the single shared target from the active enemy pool based on `current_targeting_mode`.

| Mode | Criterion | Tiebreak |
|------|-----------|----------|
| NEAREST | `min distance(e.position, hero_pos)` — e.hp > 0 | Lowest entity ID |
| FIRST | `min distance(e.position, CASTLE_POS)` — e.hp > 0 | Lowest entity ID |
| STRONGEST | `max e.hp` — e.hp > 0 | Lowest entity ID |
| WEAKEST | `min e.hp` — e.hp > 0 | Lowest entity ID |

**Output**: single `Node` reference or `null` (no HP > 0 enemies). Identical null handling to existing rule 6 — no volley fires when null.

**Example (FIRST mode):** Three enemies at castle-distances 120 px, 85 px, 200 px → returns the 85 px enemy (closest to castle = most dangerous).

**Example (WEAKEST mode):** Enemies at 12 HP, 30 HP, 12 HP with entity IDs 4, 9, 2 → returns ID 2 (lowest HP 12, then lowest entity ID as tiebreak).

---

### D-8 — slot_world_pos_LINE(i, hero_pos, facing_angle) (Sprint 5)

`slot_world_pos_LINE(i) = hero_pos + behind × (HERO_RADIUS + LINE_DEPTH) + right × (side(i) × LINE_LATERAL_STEP × (pair(i) + 1))`

Where `behind`, `right`, `side(i)`, `pair(i)` as defined in D-5. `LINE_DEPTH = 40 px`, `LINE_LATERAL_STEP = 25 px`.

**Sample values (hero at (540, 960), facing_angle = π, facing up):**

| Slot | pair | side | X | Y |
|------|------|------|---|---|
| 0 | 0 | −1 | 515 | 1018 |
| 1 | 0 | +1 | 565 | 1018 |
| 2 | 1 | −1 | 490 | 1018 |
| 3 | 1 | +1 | 590 | 1018 |
| 4 | 2 | −1 | 465 | 1018 |
| 5 | 2 | +1 | 615 | 1018 |
| 6 | 3 | −1 | 440 | 1018 |
| 7 | 3 | +1 | 640 | 1018 |

All slots share Y = 960 + 18 + 40 = 1018 px. X spacing = 50 px per pair.

**Example:** Hero at (540, 960), facing_angle = π, slot 3 (pair 1, right):
`behind = (0, 1)`, `right = (1, 0)`, depth = 58 px, lateral = +50 px → `(590, 1018)`.

---

### D-9 — slot_world_pos_ARC(i, hero_pos, facing_angle) (Sprint 5)

`slot_offset(i) = side(i) × (pair(i) + 1)` — range: −4 to +4

`slot_world_pos_ARC(i) = hero_pos + (behind × cos(ARC_ANGLE_STEP × slot_offset(i)) + right × sin(ARC_ANGLE_STEP × slot_offset(i))) × ARC_RADIUS`

Where `behind`, `right`, `side(i)`, `pair(i)` as defined in D-5. `ARC_RADIUS = 80 px`, `ARC_ANGLE_STEP = π/8 rad (22.5°)`.

**Sample values (hero at (540, 960), facing_angle = π):**

| Slot | slot_offset | Angle from behind | X approx | Y approx |
|------|-------------|-------------------|----------|----------|
| 0 | −1 | −22.5° | 509 | 1034 |
| 1 | +1 | +22.5° | 571 | 1034 |
| 2 | −2 | −45° | 483 | 1017 |
| 3 | +2 | +45° | 597 | 1017 |
| 4 | −3 | −67.5° | 466 | 991 |
| 5 | +3 | +67.5° | 614 | 991 |
| 6 | −4 | −90° | 460 | 960 |
| 7 | +4 | +90° | 620 | 960 |

Slots 6,7 are directly to the hero's sides (same Y), flanking the hero. Slots 0,1 trail closely behind.

**Example:** Hero at (540, 960), facing_angle = π, slot 6 (pair 3, left), slot_offset = −4:
`cos(-π/2) = 0`, `sin(-π/2) = -1` → `(behind×0 + right×(-1)) × 80` = `(-1,0)×80` = `(-80, 0)` → `(460, 960)`.

---

### Balance Summary

| n | formation_dps | Sufficient through wave |
|---|--------------|------------------------|
| 2 | ~17.8 | Wave 4 |
| 4 | ~35.6 | Wave 8 |
| 6 | ~53.3 | Wave 13 (marginal at W11+) |
| 8 | ~71.1 | All waves — decisive margin |

*Note: `systems-designer` consulted (Lean mode — HIGH risk section).*

## Edge Cases

- **If `recruit_purchased` fires when `current_archer_count = 8`**: signal is silently discarded — no slot is modified, no error. The Economy system must suppress the recruitment zone before this state is reached; this is a defensive rule, not a primary path.

- **If `shared_target` becomes null mid-volley** (enemy dies between target acquisition and fire timer tick): the volley is suppressed — no projectiles spawn. The timer resets normally. No "ghost shot" is fired.

- **If two enemies are equidistant from `hero_pos`**: resolve by lowest entity ID (stable tiebreak). All archers continue to target the same enemy — no split fire.

- **If a projectile hits an enemy that was already killed by a simultaneous projectile from the same volley**: the second projectile is freed on arrival (enemy HP ≤ 0 at collision). No double-kill is credited. Overkill damage is lost — no pierce or splash in MVP.

- **If `facing_angle` is undefined** (hero is idle, joystick at rest): use the last known `facing_angle`. Formation does not collapse to a point or snap to a default axis. The `facing_angle` is initialized to face up (π) at session start.

- **If an archer's lerp position lags behind its slot world pos by more than `ARCHER_SNAP_THRESHOLD` px** (e.g., after a sudden hero reposition): snap the archer directly to `slot_world_pos` rather than lerping. Prevents archers trailing far offscreen. `ARCHER_SNAP_THRESHOLD` is a tuning knob; default 300 px.

- **If `hero_pos` is within `ARCHER_ROW_DEPTH` of the world edge**: slot world positions may place some archer nodes outside world bounds. Clamp archer visual node positions to `0 ≤ x ≤ 1080`, `0 ≤ y ≤ 1920`. Formation geometry is computed unclamped; clamping is visual-only.

- **If `session_restart` fires while projectiles are in flight**: free all in-flight projectiles immediately on the reset signal. No damage is applied after reset.

- **If `ARCHER_FOLLOW_LERP` is set to 1.0** (during tuning): archers snap to slot positions every frame, disabling the trailing visual. Valid for testing; unacceptable for production. Safe range: 0.05–0.25.

- **If `PROJ_DAMAGE` is set to 0** (configuration error or tuning): projectiles travel and collide but deal no damage. Enemies never die. Log a warning at session start if PROJ_DAMAGE ≤ 0.

- **If no valid enemy exists in the world** (between waves or all enemies dead): `shared_target` is null. No volley fires. Timer continues counting. No crash or log spam.

**Sprint 5 Edge Cases — Targeting Priority:**

- **If targeting mode is FIRST and all enemies are equidistant from CASTLE_POS**: resolve by lowest entity ID (same tiebreak as NEAREST mode). No mode-specific fallback needed.

- **If targeting mode is STRONGEST/WEAKEST and only one valid enemy exists**: that enemy is selected regardless of HP value. No edge to the selection logic.

- **If targeting mode is WEAKEST and two enemies have identical HP > 0**: resolve by lowest entity ID.

- **If `targeting_mode_cycled` fires when Targeting Protocol is not purchased**: signal is not emitted by Economy (zone does not exist). If the signal somehow fires (unit test scenario), Archer Formation applies the mode change without crashing — but this state is unreachable in production.

- **If the hero dwells at TARGETING_ZONE_POS before "Targeting Protocol" is purchased**: Economy does not activate the TARGETING_ZONE; no dwell timer accumulates; no signal fires. From the player's perspective nothing happens at that screen position.

**Sprint 5 Edge Cases — Tactical Formations:**

- **If `formation_mode_cycled` fires while archers are mid-lerp**: slot world positions update immediately on the same frame. Archers' current positions are unchanged; they begin lerping toward the new slot positions from wherever they are. The transition is handled by the existing lerp logic — no snap, no discontinuity, unless positions exceed `ARCHER_SNAP_THRESHOLD`.

- **If LINE or ARC slot positions place archers outside world bounds** (hero near edge): apply the same visual clamp as rule 7 of edge cases (AC-FF-05). Geometry is computed unclamped; visual node position is clamped to `0 ≤ x ≤ 1080`, `0 ≤ y ≤ 1920`.

- **If formation_mode is ARC and `ARC_ANGLE_STEP × 4 > π/2`** (slots 6,7 would wrap past 90°): this would place flanking archers ahead of the hero. `ARC_ANGLE_STEP` safe maximum is `π/8` (22.5°), giving 90° at slot_offset = 4. Exceeding π/8 is a tuning constraint violation — log a warning.

- **If formation mode resets to V_FORMATION on session restart while in LINE or ARC**: slot world positions are immediately recalculated using formula D-5. Archers lerp to V positions from wherever they were. No snapshot or history of previous formation required.

## Dependencies

### Upstream Dependencies (Archer Formation depends on)

| System | Dependency Type | Interface |
|--------|-----------------|-----------|
| Hero Movement | **Hard** | Reads `hero_pos: Vector2` and `facing_angle: float` each frame for slot world pos computation; consumes shared `SHOOT_IVTL` timer event for volley coordination |
| Enemy Wave | **Hard** | Queries enemy positions and HP each frame for `shared_target` acquisition; applies `PROJ_DAMAGE` to enemy HP on projectile collision |
| Economy | **Hard** | Listens for `recruit_purchased` signal to advance `current_archer_count` and fill the next empty slot |
| Game State Machine | **Hard** | Listens for `game_over` and `session_restart` signals to reset slot state to STARTING_ARCHERS = 2 |

### Downstream Dependents (systems that depend on Archer Formation)

| System | Dependency Type | Interface |
|--------|-----------------|-----------|
| Economy | **Hard** | Reads `current_archer_count: int` each frame to determine recruit cost tier (ARCHER_COST_TIER_1 vs ARCHER_COST_TIER_2) and whether to suppress the recruitment zone at capacity |
| HUD | **Soft** | Reads `current_archer_count: int` for the archer-count display. HUD can function without this (omit the counter), but it is expected as a key readout |
| Archer Tower | **Soft (MVP)** | Reads from the archer pool to transfer TOWER_ARCHERS_COUNT (2) occupied slots to a fixed tower position on tower purchase. Interface defined in Archer Tower GDD (R3: slot-release contract). |
| Forge | **Soft (Alpha only)** | `PROJ_DAMAGE_UP` upgrade increases `PROJ_DAMAGE` at runtime by `FORGE_PROJ_DAMAGE_DELTA = 2 HP` per purchase. `SHOOT_IVTL_DOWN` upgrade decreases `SHOOT_IVTL` at runtime by `FORGE_IVTL_DELTA = 0.10s` per purchase (floor: `SHOOT_IVTL_FLOOR = 0.40s`). Sprint 5: `TARGETING_PROTOCOL_PURCHASED` emits when the Targeting Protocol upgrade is bought — Archer Formation sets `targeting_protocol_unlocked = true` and notifies Economy to activate TARGETING_ZONE. `FORMATION_DOCTRINE_PURCHASED` similarly unlocks FORMATION_ZONE. |

### Bidirectional Note

Archer Formation and Economy form a **signal-level cycle**: Economy emits `recruit_purchased` → Archer Formation increments `current_archer_count` → Economy reads `current_archer_count` to determine next cost. This cycle is safe in Godot (signals are deferred by one frame by default, preventing re-entrancy). Both GDDs document their side of this interface.

*Cross-reference: Hero Movement GDD must document that it exposes `hero_pos`, `facing_angle`, and shared `SHOOT_IVTL` timer to Archer Formation (bidirectional consistency). Flag for /design-review.*

## Tuning Knobs

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|-----------|---------|---------|
| `ARCHER_FOLLOW_LERP` | 0.12 | 0.05–0.25 | Formation lags so far behind that archers appear unresponsive; Pillar 3 visual fails | Archers snap stiffly with no trailing motion; loses "living army" feel |
| `PROJ_DAMAGE` | 8 | 4–16 | n=2 can't kill wave-1 enemies in <5 volleys; formation feels impotent | n=2 kills wave-1 enemies in one volley; no incentive to recruit further archers |
| `PROJ_SPEED` | 600 | 300–900 | Projectiles visibly float; misses feel unfair on mobile touch latency | Projectiles invisible on 60 fps mobile (cross multiple tiles per frame) |
| `ARCHER_ROW_DEPTH` | 30 px | 20–50 px | All 4 pairs cluster near the hero; formation is an indistinct blob | Formation stretches 200 px behind hero; archers fall off-camera regularly |
| `ARCHER_INNER_SEP` | 25 px | 15–40 px | Pair 0 archers overlap each other | Pair 0 archers spread wider than pair 1 (ARCHER_INNER_SEP > ARCHER_MID_SEP — violates shape constraint) |
| `ARCHER_MID_SEP` | 50 px | 30–70 px | Must be > ARCHER_INNER_SEP | Must be < ARCHER_OUTER_SEP |
| `ARCHER_OUTER_SEP` | 75 px | 50–90 px | Must be > ARCHER_MID_SEP | Must be < ARCHER_OUTERMOST_SEP |
| `ARCHER_OUTERMOST_SEP` | 100 px | 70–120 px | Must be > ARCHER_OUTER_SEP | Formation width > 240 px; slots 6–7 clip world edge when hero is near the sides |
| `ARCHER_SNAP_THRESHOLD` | 300 px | 100–500 px | Archers snap on normal movement; trailing effect disappears | Archers trail offscreen before snapping; visually broken |
| `STARTING_ARCHERS` | 2 | 1–4 | A single archer is visually weak and fails the formation fantasy on wave 1 | 4 starting archers shortcircuits the early recruitment economy |
| `SHOOT_IVTL` | 0.9s | 0.4–2.0s | Too fast: projectile spam, performance risk on mobile. Too slow: DPS insufficient to hold waves. **Authoritative owner: this GDD.** Hero Movement and Archer Tower read this value — tune it here. Forge SHOOT_IVTL_DOWN upgrade reduces it at runtime (floor: 0.40s). |

| `TARGETING_ZONE_POS` | (135, 750) | (50–270, 500–900) | Zone unreachable during combat (too far from battlefield center) | Zone overlaps RECRUIT_ZONE or enemy path — unintended dwell triggers |
| `TARGETING_DWELL` | 0.6 s | 0.3–1.0 s | Mode cycles too easily while passing through; accidental mode changes | Player must commit too long mid-combat; Pillar 1 friction violation |
| `FORMATION_ZONE_POS` | (810, 750) | (540–960, 500–900) | Zone unreachable; placed symmetrically to TARGETING_ZONE | Zone overlaps TOWER_ZONE or enemy path |
| `FORMATION_DWELL` | 0.6 s | 0.3–1.0 s | Accidental formation switches during combat movement | Too slow for one-thumb play under wave pressure |
| `LINE_DEPTH` | 40 px | 25–60 px | All archers cluster at hero back; looks like V | Archers too far behind; trailing archers miss shots on fast-moving enemies |
| `LINE_LATERAL_STEP` | 25 px | 15–35 px | Archers overlap in LINE mode | Formation width > 200 px; outermost archers clip world edge |
| `ARC_RADIUS` | 80 px | 50–120 px | Arc is too small; formation looks like a blob | Flanking archers at 120 px radius may leave the camera frame on small screens |
| `ARC_ANGLE_STEP` | π/8 rad | π/12–π/8 | Archers cluster near the behind vector; flanking benefit lost | `ARC_ANGLE_STEP × 4 > π/2`: outermost archers wrap past 90° and appear ahead of hero |

### Cross-Knob Interactions

1. **`PROJ_DAMAGE` × `SHOOT_IVTL` (both owned by Archer Formation)**: Both drive `formation_dps`. Adjust together to shift overall power. Halving SHOOT_IVTL doubles DPS more dramatically than doubling PROJ_DAMAGE — use PROJ_DAMAGE for fine-grained balance, SHOOT_IVTL for dramatic feel changes. Hero Movement reads SHOOT_IVTL but does not own it. Forge SHOOT_IVTL_DOWN modifies it at runtime.

2. **V-formation shape constraint**: `ARCHER_INNER_SEP < ARCHER_MID_SEP < ARCHER_OUTER_SEP < ARCHER_OUTERMOST_SEP` must always hold. Violating this produces a formation that narrows or crosses its own wings.

3. **`ARCHER_FOLLOW_LERP` × `ARCHER_SNAP_THRESHOLD`**: Higher lerp reduces the lag that triggers snapping. If lerp is raised to ≥ 0.20, snap threshold can be reduced to 150 px without visual artifacts.

### Knobs Owned by Other GDDs (Reference Only)

| Knob | Owner GDD | Effect on this system |
|------|-----------|----------------------|
| `ARCHER_COST_TIER_1` | Economy | Price to recruit archers 1–4; determines wave timing for formation growth |
| `ARCHER_COST_TIER_2` | Economy | Price to recruit archers 5–8 |

## Visual/Audio Requirements

*`art-director` consulted (REQUIRED section — character movement + combat category).*

### Overall Visual Rule

The Archer Formation is a warm amber-green wedge on a dark battlefield — each archer is a distinct readable silhouette, the volley emits a single sharp simultaneous flash across all slots, and the formation grows slot-by-slot from the front pair outward so every recruit is a visible expansion of the wedge shape. All effects must be legible with peripheral vision (Pillar 1). Nothing here requires the player to look directly at the formation to understand what happened.

---

### Archer Idle Sprite

| Property | Requirement |
|---|---|
| Format | Sprite sheet, single PNG per direction set |
| Directions | 2 base directions (facing-right, facing-up). Use `flip_h = true` for facing-left. Use `flip_v = true` or a separate row for facing-down |
| Frames per direction | 4-frame idle walk cycle minimum, 6 recommended. Playback 8 fps |
| Sprite canvas | 32×32 px per frame at 1080×1920 world resolution (archer radius = 12 px gameplay + 4 px padding) |
| Silhouette requirement | Readable as a distinct bow-armed figure at 32×32 px — bow arc visible as single-pixel detail minimum |
| Color palette | Warm amber-olive tones (desaturated green tunic, amber/leather detail). Contrasts with enemy red and hero blue. Exact hex values deferred to art bible |
| Shared material | All 8 archers use the same `CanvasItemMaterial` (or none). Enables Godot sprite batching → 1 draw call for all archers |

### Projectile (Arrow)

| Property | Requirement |
|---|---|
| Type | `Sprite2D` node — no particle system |
| Dimensions | 12×4 px elongated shape |
| Color | Bright amber-yellow `Color(1.0, 0.92, 0.55)` — warm, distinct from enemy red and gold coins |
| Rotation | Set to `velocity.angle()` once at spawn. Not updated per frame |
| Motion trail | Second `Sprite2D` child at 50% scale, 40% alpha, 6 px behind tip — moves with parent, zero per-frame cost. No particle trail |
| Shared material | All arrow sprites and tail sprites share one material each → 2 draw calls for all 8 arrows + 8 tails |
| Pooling | Object pool of 24 arrow nodes (reset position/rotation on reuse — no free/instantiate per volley) |

---

### Event-by-Event Requirements

#### Event 1 — Archer Follows Hero (Continuous)

**Visual:** Idle walk-cycle animation plays continuously at 8 fps. Facing direction updates when lerp velocity exceeds 2 px/frame; held below that threshold to prevent flicker. No trail, no additional VFX.
**Audio:** None. Continuous motion sound becomes noise on mobile within 30 seconds.
**Performance:** 1 batched draw call for all 8 archers at shared material.

#### Event 2 — Archer Recruit (`recruit_purchased`)

**Visual — the growing moment (Pillar 3 primary reward):**
1. New archer spawns at `slot_world_pos` — invisible, 50% scale
2. Over 0.25 s: lerp scale 50%→120%, fade alpha 0→1
3. Over next 0.10 s: lerp scale 120%→100%
4. On spawn (t=0): one-shot `GPUParticles2D` burst at slot_world_pos — 8 particles, radial spread 360°, speed 40–80 px/s, lifetime 0.3 s, color `Color(1.0, 0.92, 0.55)` → alpha 0, gravity 0, shared 4×4 px texture, `one_shot = true`. Node freed after lifetime.
5. Position locked to `slot_world_pos` during the 0.35 s animation; lerp resumes after.

*What makes this feel rewarding:* scale overshoot gives a "landing" sensation; the new slot expands the V-silhouette — the wedge gets wider, not just more crowded.

**Audio:** `sfx_archer_recruit` — one-shot, non-positional. Character: short "notch and draw" — dry bow-string tension + footstep thud. Duration 0.3–0.5 s. Volume: 0 dB. Must be distinct from volley fire (UI-grade confirmation, not combat).
**Performance:** 1 GPUParticles2D node active for 0.3 s. Maximum 1 concurrent (Economy gating prevents rapid recruits). +1 temporary draw call.

#### Event 3 — Volley Fires (Every 0.9 s, `shared_target != null`)

**Visual:**
1. On fire frame: all occupied archer sprites set `modulate = Color(1.5, 1.5, 1.0, 1.0)` (warm over-bright)
2. Over next 0.08 s: lerp modulate back to `Color(1.0, 1.0, 1.0, 1.0)` via per-archer `float _flash_timer` in `_process`
3. Arrow nodes spawned from pool at each occupied `archer_pos`, traveling toward `shared_target.position`
4. Optional: switch to "draw" frame in atlas on fire; return to walk cycle on next update

**Audio:** `sfx_volley_fire` — one-shot per volley (not per archer). Character: layered bow-string release with short high-frequency swish and deep thud. Duration 0.2–0.35 s. Volume scales with `current_archer_count`: `volume_db = lerp(-6.0, 0.0, (n - 2) / 6.0)` — at n=2 it sounds like a skirmish; at n=8 it sounds like a volley.
**Performance:** 8 archer flash timers (property writes only). 8 arrow + 8 tail sprites from pool = 2 draw calls.

#### Event 4 — Projectile Travels (Arrow in Flight)

**Visual:** Arrow `Sprite2D` translates at `velocity * delta`. No per-frame visual update beyond position. Ghost tail moves with parent — zero additional cost. No particle trail (8 simultaneous GPUParticles2D trails would exceed budget).
**Audio:** None. Volley fire covers launch; impact covers arrival.
**Performance:** All arrows active = 2 batched draw calls (see above).

#### Event 5 — Projectile Hits Enemy

**Visual:**
1. Enemy sprite: set `modulate = Color(1.8, 0.3, 0.3, 1.0)` (harsh red overexposure), lerp back over 0.05 s
2. Impact burst at collision point: pooled `GPUParticles2D`, 12 particles, speed 60–120 px/s, lifetime 0.2 s, 180° spread facing away from arrow travel direction, color `Color(1.0, 0.4, 0.1, 1.0)` → alpha 0, gravity 0. Re-emit via `restart()` on reuse.

No screen shake, no damage numbers, no hit ring. Impact must read at enemy position, not at the player's touch point.

**Audio:** `sfx_arrow_impact` — one-shot per projectile, non-positional. Character: dry thud + brief "shk" transient (flesh/wood, not metal). Duration 0.1–0.15 s. Volume: -4 dB. At n≥6, apply ±5 cents pitch randomization per instance to prevent phase build-up from simultaneous hits.
**Performance:** Maximum 8 impact nodes active simultaneously (one per arrow in a volley), each lives 0.2 s. Pool of 8 pooled `GPUParticles2D` nodes. 96 total particles momentarily (12 × 8) — across 8 independent events; each individual event complies with 50-particle limit.

#### Event 6 — Formation at Full Capacity (Slot 7 Filled)

**Visual:**
1. After the standard recruit animation completes (t=0.35 s), pulse all 8 archer sprites simultaneously: scale `Vector2(1.0,1.0)` → `Vector2(1.1,1.1)` → back over 0.4 s
2. Emit `formation_full` signal — HUD response defined in UI Requirements

No persistent outline, color tint, or ambient particles after the pulse. 8 archers in tight V-formation at full combat output is its own legible state.

**Audio:** `sfx_formation_full` — one-shot, non-positional. Character: triumphant short brass sting or dry military drum roll resolving in 0.5–0.8 s. Volume: +2 dB (game's primary positive milestone sound). Do not loop.
**Performance:** 8 scale lerps for 0.4 s — zero new nodes or draw calls.

#### Event 7 — No Target / Idle Formation (Between Waves)

**Visual:** No special VFX. Walk-cycle animation continues. Absence of projectiles and volley flash communicates "not shooting." Optional: after 3 s idle, reduce `AnimatedSprite2D.speed_scale` to 0.5× (slow breathing effect); restore to 1.0× when `shared_target` becomes non-null.
**Audio:** `sfx_idle_ambient` — ambient loop (optional, MVP-deferred). Handled by audio manager on `formation_idle` signal.
**Performance:** Cheapest state — 1 batched draw call.

---

### Performance Budget Summary

| Formation State | Formation DCs | Projectile DCs | Particle Nodes | Total |
|---|---|---|---|---|
| Idle | 1 | 0 | 0 | 1 |
| Following, no volley | 1 | 0 | 0 | 1 |
| Mid-volley (arrows in flight) | 1 | 2 | 0 | 3 |
| Impact frame (8 simultaneous) | 1 | 0 | 8 pooled | 9 |
| Recruit event | 1 | 0 | 1 (0.3 s) | 2 |
| **Worst case** | **1** | **2** | **8** | **11** |

**Ceiling: 11–12 draw calls** at full 8-archer capacity — within the ≤12 formation budget.

---

### Audio Trigger Summary

| Sound | Trigger | Volume | Notes |
|---|---|---|---|
| `sfx_archer_recruit` | `recruit_purchased` | 0 dB | Dry bow-string + footstep |
| `sfx_volley_fire` | Shoot timer tick, target exists | -6 dB (n=2) to 0 dB (n=8) | Scale with `current_archer_count` |
| `sfx_arrow_impact` | Projectile-enemy collision | -4 dB | ±5 cents pitch randomize at n≥6 |
| `sfx_formation_full` | Slot 7 filled | +2 dB | Brass sting, 0.5–0.8 s |
| `sfx_idle_ambient` | Target null > 3 s | Ambient mix | Optional / MVP-deferred |

All `AudioStreamPlayer` (non-positional). No reverb aux bus in MVP.

---

### Implementation Checklist (Programmer Reference)

- [ ] Single shared `SpriteFrames` resource for all 8 `AnimatedSprite2D` archer nodes
- [ ] Single shared `CanvasItemMaterial` on all archer sprites + all arrow sprites (separate materials, each shared)
- [ ] Object pool of 24 arrow nodes; object pool of 8 impact `GPUParticles2D` nodes
- [ ] Per-archer `float _flash_timer` in `_process` — no `Tween` node per archer
- [ ] Volley audio volume: `audio_player.volume_db = lerp(-6.0, 0.0, (n - 2.0) / 6.0)`
- [ ] Arrow facing: `arrow.rotation = velocity.angle()` once at spawn only
- [ ] Recruit spawn animation: manual `float _spawn_timer` per archer in `_process`
- [ ] `formation_full` signal emitted by Archer Formation, consumed by HUD

## UI Requirements

Archer Formation has no dedicated UI screens. Its UI contributions are:

1. **`current_archer_count: int`** — exposed each frame. The HUD reads this to display the archer counter (e.g., "4/8" or a row of 8 slot icons). Counter display spec belongs to the HUD GDD.

2. **`formation_full` signal** — emitted once when slot 7 is filled. The HUD listens for this signal to display a one-time "Formation Complete" callout or momentary feedback. Visual design of the callout belongs to the HUD GDD.

No recruitment UI is owned by this system — zone activation, cost display, and dwell timer feedback are owned by Economy.

*UX Note: Run `/ux-design hud` before writing epics. Stories referencing the archer counter or `formation_full` callout should cite `design/ux/hud.md`, not this GDD.*

## Acceptance Criteria

*`qa-lead` consulted (Lean mode — HIGH risk section).*

### Slot Management

**AC-SM-01 (Starting state)**
**GIVEN** a new game session has just started, **WHEN** the tester inspects the formation slot debug overlay, **THEN** exactly slots 0 and 1 are OCCUPIED and slots 2–7 are EMPTY (total OCCUPIED = 2, EMPTY = 6).

**AC-SM-02 (Recruit fills lowest EMPTY slot)**
**GIVEN** slots 0–1 OCCUPIED and slots 2–7 EMPTY, **WHEN** one `recruit_purchased` event fires, **THEN** slot 2 transitions to OCCUPIED within the same frame; slots 3–7 remain EMPTY; OCCUPIED count = 3.

**AC-SM-03 (Sequential fill order)**
**GIVEN** slots 0–4 OCCUPIED and slots 5–7 EMPTY, **WHEN** one `recruit_purchased` event fires, **THEN** slot 5 (not 6 or 7) transitions to OCCUPIED; slots 6–7 remain EMPTY.

**AC-SM-04 (Recruit ignored when full)**
**GIVEN** all 8 slots OCCUPIED, **WHEN** `recruit_purchased` fires 3 times in rapid succession, **THEN** OCCUPIED count remains exactly 8; no slot changes; no error in the Godot output log.

**AC-SM-05 (Session reset restores starting archers)**
**GIVEN** all 8 slots OCCUPIED, **WHEN** `game_over` or `session_restart` fires, **THEN** within one frame: slots 0–1 OCCUPIED, slots 2–7 EMPTY (OCCUPIED = 2, EMPTY = 6).

---

### Formation Follow

**AC-FF-01 (Slot world position formula)**
**GIVEN** hero stationary at (540, 960) with `facing_angle = π` (facing up, behind = +Y, right = +X), **WHEN** the tester reads target slot positions for all 8 slots, **THEN** positions match to ±1 px:

| Slot | Expected X | Expected Y |
|------|------------|------------|
| 0 | 515 | 1008 |
| 1 | 565 | 1008 |
| 2 | 490 | 1038 |
| 3 | 590 | 1038 |
| 4 | 465 | 1068 |
| 5 | 615 | 1068 |
| 6 | 440 | 1098 |
| 7 | 640 | 1098 |

**AC-FF-02 (Archer lerps toward slot each frame)**
**GIVEN** an archer is exactly 100 px from its slot world position, **WHEN** one physics frame elapses (snap threshold not triggered), **THEN** the archer's new distance to the slot = 100 × (1 − 0.12) = 88 px ± 0.5 px.

**AC-FF-03 (Snap when lag exceeds threshold)**
**GIVEN** an archer is 301 px from its slot world position (exceeds ARCHER_SNAP_THRESHOLD = 300 px), **WHEN** one physics frame elapses, **THEN** the archer's position is set to exactly the slot world position (distance = 0 px) within that frame.

**AC-FF-04 (Snap boundary — lerp at threshold, not above)**
**GIVEN** an archer is exactly 300 px from its slot, **WHEN** one physics frame elapses, **THEN** the archer lerps (NOT snapped): new distance = 300 × (1 − 0.12) = 264 px ± 0.5 px.

**AC-FF-05 (Visual clamp at world edge)**
**GIVEN** hero at (10, 960) causing a computed archer slot position of X = −15 px, **WHEN** the tester reads the archer's rendered position, **THEN** the displayed X is clamped to 0 px; Y remains within 0–1920 px.

---

### Fire Timer and Volley

**AC-FT-01 (Fire interval = 0.9 s)**
**GIVEN** ≥1 OCCUPIED slot and a valid target, **WHEN** the tester records 10 consecutive volley timestamps, **THEN** each interval between consecutive volleys = 0.9 s ± 0.05 s.

**AC-FT-02 (More archers = more projectiles, not faster rate)**
**GIVEN** Session A with 2 OCCUPIED slots and Session B with 8 OCCUPIED slots, both with valid targets, **WHEN** one fire timer tick occurs in each, **THEN** Session A spawns exactly 2 projectiles; Session B spawns exactly 8; both sessions' intervals remain 0.9 s ± 0.05 s.

**AC-FT-03 (Shared target = nearest enemy to hero)**
**GIVEN** Enemy A at 200 px from hero and Enemy B at 350 px, both HP > 0, **WHEN** the fire timer ticks, **THEN** all projectiles travel toward Enemy A's position; zero projectiles travel toward Enemy B.

**AC-FT-04 (Volley suppressed when no valid target)**
**GIVEN** no enemies present with HP > 0, **WHEN** the fire timer ticks, **THEN** zero projectiles spawn; the fire timer resets so the next tick occurs 0.9 s later.

**AC-FT-05 (No archer death mechanic)**
**GIVEN** 5 OCCUPIED slots with a valid target, **WHEN** any damage source contacts an archer node, **THEN** OCCUPIED count remains 5; the affected slot does not change to EMPTY; the archer fires in the next volley.

---

### Projectile

**AC-PR-01 (PROJ_SPEED = 600 px/s)**
**GIVEN** a projectile spawned at (540, 500) traveling directly upward, **WHEN** exactly 1.0 s of engine time elapses, **THEN** projectile position = (540, −100) ± 2 px.

**AC-PR-02 (PROJ_DAMAGE = 8 HP per hit)**
**GIVEN** an enemy with exactly 16 HP is the target, **WHEN** one projectile contacts the enemy, **THEN** enemy HP = 8 (delta = −8); enemy is not killed.

**AC-PR-03 (Projectile freed on bounds exit)**
**GIVEN** a projectile traveling upward at Y = 1 px (inside bounds), **WHEN** one frame elapses and Y would become −1 px, **THEN** the projectile node is freed from the scene tree; active projectile count decreases by 1.

---

### Formulas

**AC-FM-01 (volley_damage(n) = n × 8)**
**GIVEN** 5 OCCUPIED slots and a target with 100 HP, **WHEN** one complete volley fires and all 5 projectiles hit, **THEN** enemy HP = 60 (delta = −40 = 5 × 8).

**AC-FM-02 (formation_dps over 9 s window)**
**GIVEN** 4 OCCUPIED slots and an enemy with ≥ 10 000 HP, **WHEN** exactly 9.0 s of engine time elapses (10 volleys at 0.9 s each), **THEN** total damage = exactly 320 HP (4 × 8 × 10).

**AC-FM-03 (time_to_kill: n=2, wave=1 ≈ 1.69 s)**
**GIVEN** 2 OCCUPIED slots and a wave-1 enemy (30 HP), **WHEN** the formation begins firing, **THEN** enemy HP reaches 0 between 1.59 s and 1.79 s after the first volley hits.

**AC-FM-04 (time_to_kill: n=8, wave=13 ≈ 0.93 s)**
**GIVEN** 8 OCCUPIED slots and a wave-13 enemy (66 HP), **WHEN** the formation begins firing, **THEN** enemy HP reaches 0 between 0.83 s and 1.03 s after the first volley hits.

---

### Edge Cases

**AC-EC-01 (target null mid-volley)**
**GIVEN** a valid target exists and the fire timer is at 0.85 s, **WHEN** the target is killed at t = 0.88 s (before the 0.9 s tick), **THEN** zero projectiles spawn at the 0.9 s tick; the fire timer resets so the next tick occurs 0.9 s later.

**AC-EC-02 (Two equidistant enemies resolved by lowest entity ID)**
**GIVEN** Entity ID 7 and Entity ID 12 each exactly 200 px from the hero, both HP > 0, **WHEN** the shared target is evaluated, **THEN** all projectiles travel toward Entity ID 7; zero travel toward Entity ID 12.

**AC-EC-03 (Projectile hits already-dead enemy)**
**GIVEN** Enemy A has HP = 0 and a projectile is in flight toward it, **WHEN** the projectile collides with Enemy A, **THEN** projectile is freed; Enemy A HP remains 0 (not negative); no kill event fires a second time; no error in the log.

**AC-EC-04 (facing_angle defaults to π at session start)**
**GIVEN** a new session with no movement input, **WHEN** the tester reads the behind-vector used for slot positions, **THEN** behind = (0, +1) and all 8 slots are positioned below the hero (Y > hero_pos.Y).

**AC-EC-05 (facing_angle retained after movement stops)**
**GIVEN** the hero last moved in the +X direction (facing_angle = π/2) and has been idle for 2.0 s, **WHEN** the tester reads slot world positions, **THEN** positions use facing_angle = π/2 (archers trail to the left); NOT the default π value.

**AC-EC-06 (session_restart frees in-flight projectiles)**
**GIVEN** 5 projectiles are currently in flight (visible in the scene tree), **WHEN** `session_restart` fires, **THEN** all 5 projectile nodes are freed within the same frame; active projectile count = 0 before new session content loads.

**AC-EC-07 (PROJ_DAMAGE = 0 warning at session start)**
**GIVEN** PROJ_DAMAGE is set to 0 (exported variable override), **WHEN** a session starts, **THEN** a warning containing "PROJ_DAMAGE" and "0" is printed to the Godot output log before the first gameplay frame; no crash occurs.

---

### Cross-System (Formation + Economy Cycle)

**AC-CS-01 (Full Economy→Formation→Fire→Damage cycle)**
**GIVEN** a fresh session with 2 OCCUPIED slots and sufficient player currency for 2 recruits,
**WHEN** the player completes two purchase interactions through the in-game zone UI,
**THEN** all four outcomes are measurable:
1. After purchase 1: slot 2 OCCUPIED, OCCUPIED total = 3, currency decreased by the stated recruit cost.
2. After purchase 2: slot 3 OCCUPIED, OCCUPIED total = 4, currency decreased again.
3. On the next fire timer tick (≤ 0.9 s later) with valid target: exactly 4 projectiles spawned.
4. If all 4 projectiles hit the same enemy: enemy HP decreases by exactly 32 HP (4 × 8).

---

### Targeting Priority (Sprint 5)

**AC-TP-01 (NEAREST mode — default behavior)**
**GIVEN** a fresh session (Targeting Protocol not purchased), **WHEN** two enemies exist — A at 150 px from hero, B at 80 px from hero, **THEN** all projectiles travel toward Enemy B (nearest). Mode read from `current_targeting_mode` = NEAREST.

**AC-TP-02 (FIRST mode — castle proximity)**
**GIVEN** Targeting Protocol upgrade purchased and mode cycled to FIRST, **WHEN** two enemies exist — A at distance 200 px from CASTLE_POS and B at distance 80 px from CASTLE_POS — **THEN** all projectiles travel toward Enemy B (closest to castle), regardless of their distances to the hero.

**AC-TP-03 (STRONGEST mode — highest HP)**
**GIVEN** mode = STRONGEST, **WHEN** three enemies have HP [40, 12, 65] and all HP > 0, **THEN** all projectiles travel toward the enemy with HP = 65. Enemy HP = 65 is the shared target.

**AC-TP-04 (WEAKEST mode — lowest HP)**
**GIVEN** mode = WEAKEST, **WHEN** three enemies have HP [40, 12, 65] and all HP > 0, **THEN** all projectiles travel toward the enemy with HP = 12.

**AC-TP-05 (WEAKEST mode — tiebreak)**
**GIVEN** mode = WEAKEST, **WHEN** Enemy ID 7 has HP = 12 and Enemy ID 2 has HP = 12, **THEN** all projectiles target Enemy ID 2 (lowest entity ID wins the tiebreak).

**AC-TP-06 (Mode locked without upgrade)**
**GIVEN** Targeting Protocol upgrade NOT purchased, **WHEN** the hero dwells at TARGETING_ZONE_POS for 2.0 s, **THEN** `current_targeting_mode` remains NEAREST; no `targeting_mode_cycled` signal fires; no error in the log.

**AC-TP-07 (Mode resets on session restart)**
**GIVEN** mode = STRONGEST after upgrade purchased, **WHEN** `session_restart` fires, **THEN** `current_targeting_mode` = NEAREST within the same frame; STRONGEST is not active in the new session.

**AC-TP-08 (Full mode cycle)**
**GIVEN** Targeting Protocol purchased, **WHEN** the hero dwells at TARGETING_ZONE_POS four times consecutively (0.6 s each), **THEN** modes cycle in order: NEAREST → FIRST → STRONGEST → WEAKEST → NEAREST; after the fourth dwell, mode = NEAREST again.

---

### Tactical Formations (Sprint 5)

**AC-TF-01 (V_FORMATION unchanged)**
**GIVEN** `current_formation_mode = V_FORMATION` (default), **WHEN** slot positions are read, **THEN** values match formula D-5 exactly as specified by AC-FF-01.

**AC-TF-02 (LINE slot positions)**
**GIVEN** mode = LINE, hero at (540, 960), `facing_angle = π` (facing up), **WHEN** slot positions are read, **THEN** all 8 slots have Y = 1018 ± 1 px; X values = [515, 565, 490, 590, 465, 615, 440, 640] ± 1 px respectively.

**AC-TF-03 (ARC slot positions — flankers)**
**GIVEN** mode = ARC, hero at (540, 960), `facing_angle = π`, **WHEN** slot positions for slots 6 and 7 are read, **THEN** slot 6 X ≈ 460 ± 2 px, Y ≈ 960 ± 2 px; slot 7 X ≈ 620 ± 2 px, Y ≈ 960 ± 2 px (flanking directly to the sides, same Y as hero).

**AC-TF-04 (ARC slot positions — innermost)**
**GIVEN** mode = ARC, hero at (540, 960), `facing_angle = π`, **WHEN** slot 0 position is read, **THEN** X ≈ 509 ± 2 px, Y ≈ 1034 ± 2 px (trailing slightly left and below).

**AC-TF-05 (Formation locked without upgrade)**
**GIVEN** Formation Doctrine upgrade NOT purchased, **WHEN** hero dwells at FORMATION_ZONE_POS for 2.0 s, **THEN** `current_formation_mode` remains V_FORMATION; no `formation_mode_cycled` signal fires.

**AC-TF-06 (Formation mode resets on session restart)**
**GIVEN** mode = LINE, **WHEN** `session_restart` fires, **THEN** `current_formation_mode` = V_FORMATION within the same frame; slot positions immediately use formula D-5.

**AC-TF-07 (Formation transition — archers lerp to new positions)**
**GIVEN** mode transitions from LINE to ARC (via dwell), **WHEN** one physics frame elapses after the transition, **THEN** each archer's position has moved toward its new ARC slot position by `ARCHER_FOLLOW_LERP` factor (or snapped if distance > `ARCHER_SNAP_THRESHOLD`); no archer teleports to an intermediate position.

**AC-TF-08 (Full formation cycle)**
**GIVEN** Formation Doctrine purchased, **WHEN** hero completes three consecutive FORMATION_ZONE dwells (0.6 s each), **THEN** modes cycle: V_FORMATION → LINE → ARC → V_FORMATION; after the third dwell, mode = V_FORMATION again.

## Open Questions

1. **SHOOT_IVTL ownership bidirectionality**: Hero Movement GDD describes SHOOT_IVTL as shared but does not explicitly list Archer Formation as a downstream dependent. The Hero Movement GDD Dependencies section must be updated — flag for `/design-review hero-movement`. Owner: design lead. Target: before implementation.

2. **Formation geometry validation**: ARCHER_INNER/MID/OUTER/OUTERMOST_SEP and ARCHER_ROW_DEPTH are design-time defaults (25/50/75/100/30 px). Prototype 1 validated 8-slot V readability but did not record explicit pixel values. Verify in the first playable build before locking. Owner: programmer + art-director. Target: first internal playtestable build.

3. **Targeting tie-break — lowest HP vs lowest entity ID**: Lowest entity ID was chosen for determinism and simplicity. "Lowest HP" would prefer nearly-dead enemies and may feel more satisfying. Revisit if playtest feedback indicates targeting feels arbitrary. Owner: design lead. Target: wave-balance playtest.

4. **No pierce/splash in MVP**: Projectiles freed on first contact. At n=6–8, in-flight projectiles may vanish after the shared target dies before they arrive — overkill waste. Pierce as a Forge upgrade (Alpha milestone) would address this. Owner: Forge GDD. Target: Alpha design sprint.

5. **Object pool size formula**: The 24-arrow / 8-impact pool sizes are estimates. If SHOOT_IVTL is tuned below 0.5 s, the pool may undersize. Document the pool size calculation as `pool_size = ceil(PROJ_MAX_FLIGHT_TIME / SHOOT_IVTL) × MAX_ARCHERS` in the governing ADR. Owner: gameplay programmer. Target: first ADR authoring session.
