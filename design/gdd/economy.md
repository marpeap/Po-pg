# Economy

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-05-20
> **Implements Pillar**: Pillar 2 — Chaque pièce d'or est une décision

## Overview

The Economy system is the resource engine of Garrison. It owns a gold counter that increments when enemies die and decrements when the player spends at dwell zones. Gold enters the run as collectible drops at enemy death positions; it exits through three purchase categories — archer recruitment, tower construction, and forge upgrades. Between these two endpoints, a gold magnet radius auto-collects nearby coins as the hero moves, and a dwell trigger fires a timed purchase when the hero lingers over an active zone for `DWELL_TIME = 0.8s`.

From a data perspective, the Economy system owns: the current gold balance (`gold: int`), the active collectible array (gold coins in the world), the dwell timer and zone detection logic, and the three purchase price constants. It listens for `enemy_died(world_pos)` signals to spawn collectibles, reads `hero_pos` from Hero Movement each frame to check magnet collection and zone proximity, and emits purchase-confirmation signals consumed by Archer Formation, Archer Tower, and Forge. On `session_reset`, the gold balance resets to `STARTING_GOLD` and all active collectibles are cleared.

From the player's perspective, the Economy is the only reason movement decisions have consequences. Intercepting enemies early earns more gold — enemies that reach the castle drop no coins. Collecting gold efficiently requires moving through the battlefield rather than staying safe. Spending it wisely requires physically visiting zones during the narrow inter-wave pause window. Every second the hero spends away from a dwell zone is a decision about whether killing more enemies is worth delaying the next archer purchase. This is Pillar 2 — "Chaque pièce d'or est une décision" — made spatial and time-pressured.

## Player Fantasy

The Economy fantasy is **the scramble** — the ten seconds after a wave ends when the player has gold in their pocket and a dwell zone 200 pixels away, and the next wave countdown has already started. Everything about the Economy is designed to create that moment: gold that appears on the battlefield (not in a menu), zones that require physical presence (not a button tap), and a dwell timer that punishes abandonment mid-fill.

The primary fantasy is **earned power**. Unlike a shop with a button, the Economy demands spatial commitment: the player must move to where the gold is, move to where the zone is, and hold still long enough to trigger the purchase. The hero who stays near the action earns more gold; the hero who sprints to the zone spends it faster. These two pressures — earn and spend — pull in opposite directions, and the tension between them is where Pillar 2 lives.

The secondary fantasy is **the moment the dwell bar fills**. A new archer joins the formation. The visible count changes. Pillar 3 ("L'armée se voit grandir") is delivered by the Economy: the gold expenditure is the invisible mechanism, but the payoff is an archer appearing and taking their place in the V. The Economy is the "why" behind every other system's visible growth.

Reference: *Vampire Survivors* has gold drops collected by proximity — no spatial commitment beyond walking near them. Garrison amplifies the tension by requiring the hero to leave the action entirely to spend. The player who chases one more kill risks missing the dwell zone before the next wave starts. That's the spatial tension the Economy Sketch described and the prototype validated.

The most powerful Economy moment: arriving at the recruit zone with exactly 30 gold, the dwell bar filling as the countdown hits 3 seconds, and the new archer appearing in the formation just before enemies emerge. The player had enough, barely.

## Detailed Design

### Core Rules

1. **Gold balance initialization**: On game start and on `session_reset`, `gold` is set to `STARTING_GOLD = 60g`. The player begins each run with enough gold for 2 archers. `STARTING_ARCHERS = 2` (the initial formation) is managed by Archer Formation GDD — Economy only owns the gold balance reset.

2. **Collectible spawn**: When Economy receives the `enemy_died(world_pos)` signal, it instantiates a GoldCoin collectible at `world_pos` with value `GOLD_DROP_PER_ENEMY = 15g`. Multiple coins may coexist simultaneously.

3. **Magnet collection**: Each frame during PLAYING state, Economy measures the Euclidean distance from `hero_pos` to each active GoldCoin. Any coin within `GOLD_MAGNET_RADIUS = 170px` is collected immediately: `gold += coin.value`, coin removed from the collectibles array. Collection is instantaneous — no travel animation required in MVP.

4. **Collectible persistence**: GoldCoins remain in the world until magnetically collected. They do not despawn on wave start. On `session_reset`, all active coins are cleared without granting gold.

5. **Dwell zone detection**: Each frame, Economy checks whether `distance(hero_pos, zone.center) ≤ ZONE_RADIUS = 90px` for all active zones. In MVP, `RECRUIT_ZONE` and `TOWER_ZONE` are active. `FORGE_ZONE` is reserved for Alpha. *(Archer Tower was promoted to MVP scope on 2026-05-19 to resolve Pillar 2 gold-sink gap — see /review-all-gdds report D-01.)*

6. **Dwell timer accumulation**: While the hero remains inside a zone, `dwell_timer` increments by `delta` each frame. When `dwell_timer ≥ DWELL_TIME = 0.8s`, a purchase attempt fires.

7. **Dwell interruption**: If the hero exits the zone (distance > `ZONE_RADIUS`) before `dwell_timer ≥ DWELL_TIME`, `dwell_timer` resets to 0. Re-entry starts the timer from zero — there is no partial-fill carry.

8. **Purchase attempt**: When `dwell_timer ≥ DWELL_TIME`, Economy evaluates affordability using the current tier cost (see Formula D-6). For `RECRUIT_ZONE`: cost = `ARCHER_COST_TIER_1 = 30g` if `current_archer_count < 4`, else `ARCHER_COST_TIER_2 = 60g`. Economy reads `current_archer_count` from Archer Formation. If `gold ≥ cost`: purchase succeeds. If false: purchase fails silently — no "not enough gold" feedback in MVP. In both outcomes, `dwell_timer` resets to 0.

9. **Successful purchase**: Economy decrements `gold` by `zone.cost`, emits the zone's purchase signal, and resets `dwell_timer` to 0. The zone is immediately available for the next purchase — no post-purchase cooldown.

10. **Purchase signals consumed**: `recruit_purchased` → Archer Formation adds one archer. `tower_purchased` (MVP) → Archer Tower places a tower. `forge_purchased` (Alpha) → Forge applies an upgrade.

11. **Game state gating**: Economy processes magnet, dwell, and purchase logic only during `PLAYING` state — both wave-active and inter-wave pause sub-states. Economy is suspended during `GAME_OVER`.

12. **HUD data exposure**: Economy emits `gold_changed(new_amount: int)` whenever `gold` changes. Economy also exposes `dwell_fill_ratio: float` = `clamp(dwell_timer / DWELL_TIME, 0.0, 1.0)`, read by HUD each frame to render the dwell progress bar.

---

### Gold Maintenance System (Sprint 5)

13. **Wave upkeep deduction**: At the end of each wave (immediately after the last enemy HP reaches 0, before the inter-wave pause begins), Economy deducts `wave_upkeep` from gold:
   `wave_upkeep = current_archer_count × UPKEEP_PER_ARCHER + tower_count × UPKEEP_PER_TOWER`
   Deduction is automatic — no player action required.

14. **Upkeep floor**: If `gold < wave_upkeep`, deduct as much gold as available and clamp `gold = 0`. No archers are dismissed. No debt carries forward. The floor is zero — the player cannot go negative.

15. **Upkeep notification**: Economy emits `upkeep_deducted(amount: int, new_balance: int)` immediately after deduction. HUD displays a brief notification (e.g., "Upkeep: −Ng") for `UPKEEP_NOTICE_DURATION = 1.5 s`. The notification is informational — it does not block wave start or require player input.

16. **Upkeep scope**: Only active archers (OCCUPIED slots in Archer Formation) and placed towers (active Archer Tower nodes) are counted. Upkeep applies even during the first inter-wave pause (after Wave 1). Starting archers (slots 0–1, `STARTING_ARCHERS = 2`) are counted — upkeep applies from Wave 1 end onward.

17. **Upkeep during session reset**: On `session_reset`, no upkeep fires. The wave-end upkeep event is only triggered by a natural wave completion (all enemies dead). GAME_OVER that occurs mid-wave does not trigger upkeep.

18. **Targeting and formation zone upkeep**: TARGETING_ZONE and FORMATION_ZONE (Sprint 5, archer-formation.md) are owned by Economy. Economy activates them on receiving Forge upgrade signals. Dwell interaction with these zones follows the same dwell timer rules as RECRUIT_ZONE (rules 6–7).

### States and Transitions

The dwell interaction has three implicit states:

| Dwell State | Condition | Behavior |
|-------------|-----------|----------|
| **IDLE** | Hero outside all active zones | `dwell_timer` holds at 0; no processing |
| **DWELLING** | Hero inside a zone; `dwell_timer < DWELL_TIME` | Timer increments each frame; HUD shows partial fill |
| **TRIGGERED** | `dwell_timer ≥ DWELL_TIME` | Purchase attempt fires; timer resets; transitions to IDLE or back to DWELLING if hero still inside zone |

Economy processing is gated by Game State Machine state:

| Game State | Economy Active? |
|------------|----------------|
| PLAYING (wave active) | Yes — full economy runs |
| PLAYING (inter-wave pause) | Yes — full economy runs (prime spending window) |
| GAME_OVER | No — frozen; gold preserved for score display |
| RESETTING | No — frozen; gold resets to STARTING_GOLD on session_reset signal |

### Interactions with Other Systems

| Direction | System | Data / Signal | Description |
|-----------|--------|---------------|-------------|
| ← Read | Hero Movement | `hero_pos: Vector2` | Read every frame for magnet and zone detection. Economy does not modify hero position. |
| ← Read | Archer Formation | `current_archer_count: int` | Read at each purchase attempt to determine the active recruit cost tier (tier 1 if count < 4, tier 2 if count ≥ 4). |
| ← Signal | Enemy Wave | `enemy_died(world_pos: Vector2)` | Triggers GoldCoin spawn at `world_pos`. |
| ← Signal | Game State Machine | `session_reset` | Resets `gold` to `STARTING_GOLD` (60g), clears all collectibles, resets `dwell_timer`. |
| → Signal | Archer Formation | `recruit_purchased` | Archer Formation adds one archer on receipt. |
| → Signal | Archer Tower | `tower_purchased` *(MVP)* | Tower placement triggered on receipt. |
| → Signal | Forge | `forge_purchased` *(Alpha)* | Upgrade applied on receipt. |
| → Signal | HUD | `gold_changed(new_amount: int)` | Emitted on every gold change; HUD updates counter. |
| → Property | HUD | `dwell_fill_ratio: float` | HUD polls this each frame for the progress bar (0.0–1.0). |

## Formulas

### Formula D-1: Gold Available Per Wave

The maximum gold collectible from a wave, assuming all enemies are killed:

`gold_max(n) = enemies_per_wave(n) × GOLD_DROP_PER_ENEMY`

Where `enemies_per_wave(n) = min(20, 5 + (n − 1) × 2)` (defined in Enemy Wave GDD).

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave number | `n` | int | 1–∞ | Current wave (1-indexed) |
| Enemies this wave | `enemies_per_wave(n)` | int | 5–20 | Capped at 20 from Wave 9 onward |
| Drop per enemy | `GOLD_DROP_PER_ENEMY` | int | 5–30g | Gold spawned on each enemy death |
| Max gold | `gold_max(n)` | int | 75–300g | Ceiling: all enemies killed and collected |

**Output Range:** 75g (Wave 1) to 300g (Wave 9+). Actual gold earned is `gold_max(n) × kill_rate` where kill_rate ≤ 1.0 depends on formation size and player positioning. A hero who stays near the action earns the full ceiling; a hero who retreats to the castle lets enemies reach it and loses both gold and HP.

**Worked example — Wave 3:**
`enemies_per_wave(3) = 5 + 2×2 = 9`. `gold_max(3) = 9 × 15 = 135g`.

---

### Formula D-2: Magnet Collection Check

`collected = distance(hero_pos, coin_pos) ≤ GOLD_MAGNET_RADIUS`

Expanded: `sqrt((hero_pos.x − coin_pos.x)² + (hero_pos.y − coin_pos.y)²) ≤ 170`

GDScript implementation: `hero_pos.distance_to(coin_pos) <= GOLD_MAGNET_RADIUS`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Hero position | `hero_pos` | Vector2 | (0,0)–(1080,1920) | Read from Hero Movement each frame |
| Coin position | `coin_pos` | Vector2 | (0,0)–(1080,1920) | Fixed at enemy death position; coins do not move |
| Magnet radius | `GOLD_MAGNET_RADIUS` | float | 100–250px | Validated = 170px |
| Result | `collected` | bool | true/false | If true: `gold += coin.value`, coin removed from array |

**Output Range:** Boolean, evaluated per coin per frame. All coins within 170px are collected in the same frame — no priority queue. Coins spawn at enemy death positions deep in the field, so the hero must move forward to collect efficiently; retreating to the castle economically underperforms.

**Worked example:**
Hero at (540, 900), coin at (650, 980): `distance = sqrt(110² + 80²) ≈ 136px`. 136 ≤ 170 → collected.

---

### Formula D-3: Zone Proximity Check

`inside_zone = distance(hero_pos, zone.center) ≤ ZONE_RADIUS`

GDScript: `hero_pos.distance_to(zone.center) <= ZONE_RADIUS`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Hero position | `hero_pos` | Vector2 | (0,0)–(1080,1920) | Read from Hero Movement each frame |
| Zone center | `zone.center` | Vector2 | Fixed per zone | World position; set at scene placement |
| Zone radius | `ZONE_RADIUS` | float | 60–120px | Touch-safe radius; set to 90px |
| Result | `inside_zone` | bool | true/false | If true: dwell timer increments (Formula D-4 activates) |

**Output Range:** Boolean, evaluated per active zone per frame. In MVP, one zone (RECRUIT_ZONE) → one check per frame.

**Worked example:**
RECRUIT_ZONE center at (200, 1650). Hero at (240, 1680): `distance = sqrt(40² + 30²) = 50px`. 50 ≤ 90 → inside_zone = true.

---

### Formula D-4: Dwell Fill Ratio

`dwell_fill_ratio = clamp(dwell_timer / DWELL_TIME, 0.0, 1.0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Dwell timer | `dwell_timer` | float | 0.0–DWELL_TIME | Accumulated seconds inside zone without interruption; resets on exit or purchase |
| Dwell threshold | `DWELL_TIME` | float | 0.5–2.0s | Validated = 0.8s |
| Fill ratio | `dwell_fill_ratio` | float | 0.0–1.0 | 0 = no progress; 1.0 = purchase fires |

**Output Range:** 0.0 (hero outside zone) to 1.0 (purchase fires). Clamp prevents floating-point overshoot. HUD reads this property each frame to render the dwell progress bar.

**Worked example:** Hero inside zone for 0.5s. `0.5 / 0.8 = 0.625`. HUD bar at 62.5%.

---

### Formula D-5: Purchase Affordability Check

`can_purchase = (gold ≥ recruit_cost(n)) AND (dwell_timer ≥ DWELL_TIME) AND (zone.is_active)`

If `can_purchase = true`: `gold_new = gold − recruit_cost(n)`

Where `recruit_cost(n)` is defined by Formula D-6 and `n = current_archer_count`.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Gold balance | `gold` | int | 0–∞ | Current gold |
| Recruit cost | `recruit_cost(n)` | int | 30–200g | Tiered cost (see D-6); `n` = current archer count |
| Zone active | `zone.is_active` | bool | true/false | RECRUIT_ZONE = true in MVP |
| Dwell timer | `dwell_timer` | float | 0.0–∞ | Must reach DWELL_TIME |
| Result | `can_purchase` | bool | true/false | All three conditions true → purchase executes |
| New balance | `gold_new` | int | 0–∞ | Gold after deduction |

**Worked example — success:** `gold = 70`, `current_archer_count = 3` → `recruit_cost = 30g`. `70 ≥ 30`, timer met, zone active → purchase. `gold_new = 40g`. `recruit_purchased` emitted.

**Worked example — failure:** `gold = 50`, `current_archer_count = 4` → `recruit_cost = 60g`. `50 < 60` → fails silently. Timer resets.

---

### Formula D-6: Archer Recruit Cost (Tiered)

`recruit_cost(n) = ARCHER_COST_TIER_1 if n < 4 else ARCHER_COST_TIER_2`

Where `n = current_archer_count` (read from Archer Formation before the purchase attempt).

| Tier | Purchase | Cost | Kills required |
|------|----------|------|----------------|
| Tier 1 | Archer 1–4 | `ARCHER_COST_TIER_1 = 30g` | 2 enemy kills |
| Tier 2 | Archer 5–8 | `ARCHER_COST_TIER_2 = 60g` | 4 enemy kills |

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current count | `n` | int | 0–7 | Archers in formation before this purchase; 8 = full, zone shows unavailable |
| Tier 1 cost | `ARCHER_COST_TIER_1` | int | 20–50g | Cost for archers 1–4 |
| Tier 2 cost | `ARCHER_COST_TIER_2` | int | 40–100g | Cost for archers 5–8 |
| Result | `recruit_cost` | int | 30 or 60g | Price of the next archer |

**Output Range:** 30g (n < 4) or 60g (n ≥ 4). If `n = 8`, the formation is full — RECRUIT_ZONE displays as unavailable.

**Progression worked example** (all enemies killed; GDScript canon: STARTING_GOLD = 60g, STARTING_ARCHERS = 2):

| After inter-wave | Gold earned (wave) | Balance | Archers bought | Archers total | Gold remaining |
|------------------|--------------------|---------|----------------|---------------|----------------|
| Start | — | 60g | — | 2 | 60g |
| Wave 1 (5 enemies) | 75g | 135g | 3 (@30g), 4 (@30g), 5 (@60g) | 5 | 15g |
| Wave 2 (7 enemies) | 105g | 120g | 6 (@60g), 7 (@60g) | 7 | 0g |
| Wave 3 (9 enemies) | 135g | 135g | 8 (@60g) | 8 (full) | 75g |

Formation reaches 8 archers by end of Wave 3 inter-wave pause (theoretical max kill rate = 1.0). The Tier 2 price (60g = 4 kills) creates concrete "do I have enough?" decisions for archers 5–8. Gold surplus post-cap has the MVP gold sink: `TOWER_COST = 100g` (Archer Tower, promoted to MVP 2026-05-19).

---

### Formula D-7: Wave Upkeep (Sprint 5)

`wave_upkeep = current_archer_count × UPKEEP_PER_ARCHER + tower_count × UPKEEP_PER_TOWER`

`gold_after = max(0, gold − wave_upkeep)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Active archers | `current_archer_count` | int | 2–8 | OCCUPIED slots in Archer Formation at wave end |
| Active towers | `tower_count` | int | 0–∞ | Placed Archer Tower nodes at wave end |
| Archer upkeep | `UPKEEP_PER_ARCHER` | int | 1–8g | Maintenance cost per archer per wave |
| Tower upkeep | `UPKEEP_PER_TOWER` | int | 4–20g | Maintenance cost per tower per wave |
| Total upkeep | `wave_upkeep` | int | 6–∞ | Total deduction at wave end |
| New balance | `gold_after` | int | 0–∞ | Gold after deduction; floored at 0 |

**Output Range at default values (`UPKEEP_PER_ARCHER = 3g`, `UPKEEP_PER_TOWER = 8g`):**

| Archers | Towers | Upkeep | Wave 1 max gold (75g) | Net after upkeep |
|---------|--------|--------|----------------------|------------------|
| 2 | 0 | 6g | 75g | 69g |
| 4 | 0 | 12g | 75g | 63g |
| 4 | 1 | 20g | 75g | 55g |
| 8 | 2 | 40g | 75g (W1) / 300g (W9+) | 35g / 260g |

Upkeep is noticeable but not crippling. A player who kills all enemies in any wave always earns enough to cover upkeep and still afford upgrades. The pressure is felt when kill efficiency drops (late waves, early recruitment).

**Design intent**: Upkeep extends Pillar 2 ("Chaque pièce d'or est une décision") beyond the early formation-filling phase. A fully-recruited army (8 archers + 2 towers, 40g/wave) requires sustained kill efficiency to maintain. Players who recruit rapidly must also earn rapidly — the two objectives pull in opposite directions, maintaining strategic tension into the late game.

**Example:** Wave 5 ends. 6 archers, 1 tower. `wave_upkeep = 6×3 + 1×8 = 26g`. Gold balance = 90g → `gold_after = 64g`. HUD shows "Upkeep: −26g". Player enters inter-wave pause with 64g — enough for one Tier 2 archer (60g) but nothing left over.

---

## Edge Cases

- **If `gold < 0` after any operation**: Cannot happen under normal rules (purchase only fires when `gold ≥ cost`), but if future simultaneous purchases are introduced: clamp `gold` to 0 as a safety floor. Never allow negative gold.

- **If `current_archer_count = 8` (formation full) and the hero dwells RECRUIT_ZONE**: The dwell timer does not increment. The zone is inactive (`zone.is_active = false`) when the formation is full. No purchase fires, no fill bar is displayed.

- **If two GoldCoins spawn at the same world position** (two enemies die at the same pos in the same frame): Both coins are collected independently. Gold increases by `2 × GOLD_DROP_PER_ENEMY`. No deduplication needed — treat them as two distinct collectibles.

- **If an enemy dies outside the world bounds** (e.g., pushed by collision to x < 0 or x > 1080): GoldCoin spawns at `(clamp(x, 0, 1080), clamp(y, 0, 1920))`. Do not spawn collectibles outside world bounds.

- **If the hero is simultaneously inside two zones** (overlapping areas): In MVP, only one zone is active — this cannot occur. For Vertical Slice+, apply priority: TOWER_ZONE > RECRUIT_ZONE. Only the highest-priority zone runs a dwell timer; others are ignored.

- **If `session_reset` fires while `dwell_timer > 0`**: Reset `dwell_timer` to 0, reset `gold` to `STARTING_GOLD = 60g`, clear all collectibles. The in-progress dwell is abandoned; no purchase fires from the reset.

- **If `session_reset` fires while coins exist in the world**: All GoldCoin nodes are freed immediately. Their value is not granted to the player — cleared coins do not add to the reset gold balance.

- **If the hero moves through RECRUIT_ZONE without stopping** (enters and exits in under 0.8s): `dwell_timer` increments while inside, then resets on exit. No purchase fires. Correct behavior — spatial commitment requires holding still.

- **If `GOLD_DROP_PER_ENEMY` is tuned to 0**: No coins spawn. Gold never increases. Archers become unaffordable and the run is unwinnable. This is outside the safe range (minimum 5g) — treat as a configuration error.

- **If the active coin array grows unbounded** (player never collects coins, 20 enemies/wave across many waves): If active coin count exceeds `COIN_POOL_MAX = 120`, the oldest coins are freed without granting gold to prevent unbounded memory growth. Log a warning in development when this cap triggers — it indicates the player is not collecting efficiently, which is a design signal worth monitoring.

- **If `DWELL_TIME = 0`**: Purchase fires on the first frame the hero enters a zone. This removes all spatial commitment and breaks Pillar 2. Outside the safe range (minimum 0.5s) — treat as a configuration error.

**Sprint 5 Edge Cases — Gold Maintenance:**

- **If all enemies die simultaneously in one volley** (e.g., last 3 enemies all killed at once): the `wave_end` event fires once; upkeep deducts once. Multiple simultaneous `enemy_died` signals in the same frame do not trigger multiple upkeep deductions.

- **If `gold = 0` at wave end** (player spent all gold buying archers): `wave_upkeep > 0` but `gold_after = max(0, 0 − N) = 0`. Upkeep fires, deducts 0g, `upkeep_deducted(0, 0)` emitted. HUD shows "Upkeep: −0g" (or suppresses the notification if amount = 0 — HUD decision, see hud.md).

- **If `tower_count` changes between wave start and wave end** (e.g., a tower is purchased mid-wave via TOWER_ZONE): `tower_count` is read at the moment upkeep fires (wave end), after all mid-wave purchases. A tower bought mid-wave counts for upkeep in that same wave.

- **If `current_archer_count` is 0 at wave end** (hypothetical configuration): `wave_upkeep = 0`, no deduction, no notification. In practice, `STARTING_ARCHERS = 2` prevents this.

- **If the hero is inside TARGETING_ZONE or FORMATION_ZONE when wave_end fires**: Upkeep deducts from gold, then `gold_changed` fires. If the deduction drops gold below the cost of whatever the hero is dwelling toward, the dwell timer continues but the purchase will fail silently when it fires (same behavior as RECRUIT_ZONE affordability check in rule 8).

- **If UPKEEP_PER_ARCHER is 0 (tuning error)**: Upkeep system fires but deducts 0g. Log a warning in development. This disables the strategic tension the system is designed to create — outside the safe range.

## Dependencies

### Upstream (Economy depends on these systems)

| System | GDD | Type | Interface |
|--------|-----|------|-----------|
| Hero Movement | `hero-movement.md` | Hard | Economy reads `hero_pos: Vector2` every frame for magnet collection and zone detection. Hero Movement owns this value; Economy only reads it. |
| Enemy Wave | `enemy-wave.md` | Hard | Economy listens for `enemy_died(world_pos: Vector2)` signal. Without this signal, no gold enters the system. Economy listens for `wave_cleared` signal (Sprint 5) to trigger wave upkeep deduction. |
| Game State Machine | `game-state.md` | Hard | Economy subscribes to `session_reset` to clear state. Economy gates all processing on `PLAYING` state. |
| Archer Formation | `archer-formation.md` | Soft (MVP) | Economy reads `current_archer_count: int` at each RECRUIT_ZONE purchase (Formula D-6). Sprint 5: reads `current_archer_count` at wave end for upkeep calculation (Formula D-7). Also owns and activates TARGETING_ZONE and FORMATION_ZONE on `targeting_protocol_purchased` and `formation_doctrine_purchased` Forge signals. |
| Archer Tower | `archer-tower.md` | Hard (MVP) | Sprint 5: Economy reads `tower_count: int` at wave end for upkeep calculation (Formula D-7). |
| Forge | `forge.md` | Soft (Alpha) | Economy listens for `targeting_protocol_purchased` and `formation_doctrine_purchased` to activate new dwell zones. |

### Downstream (these systems depend on Economy)

| System | GDD | Type | Interface |
|--------|-----|------|-----------|
| Archer Formation | `archer-formation.md` | Hard | Listens for `recruit_purchased` to add one archer to the V-formation. Cannot grow without Economy. |
| HUD | `hud.md` | Hard | Subscribes to `gold_changed(new_amount: int)` for the gold counter; reads `dwell_fill_ratio` each frame for the dwell progress bar. |
| Archer Tower | `archer-tower.md` | Hard (MVP) | Listens for `tower_purchased`. Active in MVP (promoted from Vertical Slice 2026-05-19 — see D-01). |
| Forge | `forge.md` | Hard (Alpha) | Listens for `forge_purchased`. Not active in MVP. |

### Bidirectional Dependency — Economy ↔ Archer Formation

Economy reads `current_archer_count` from Archer Formation (to compute cost tier), and Archer Formation listens for Economy's `recruit_purchased` signal (to add an archer). This is a signal-level cycle, not a code-level import cycle — safe in Godot's signal architecture. The Archer Formation GDD's Dependencies section must document this relationship for consistency.

## Tuning Knobs

| Knob | Default | Safe Range | Effect if changed |
|------|---------|------------|-------------------|
| `STARTING_GOLD` | 60g | 0–120g | Lower = harder early ramp, fewer starting options. Higher = formation fills faster, early tension reduced. Validated at 60g in prototype 2. |
| `GOLD_DROP_PER_ENEMY` | 15g | 5–30g | Lower = slower economy, more strategic. Higher = gold floods in, decisions become trivial. **Coupled with `ARCHER_COST_TIER_1`** — change the pair together, never individually. |
| `GOLD_MAGNET_RADIUS` | 170px | 100–250px | Lower = player must position more precisely near deaths; higher skill expression. Higher = passive collection, reduces movement incentive. Validated at 170px in prototype 1. |
| `DWELL_TIME` | 0.8s | 0.5–2.0s | Lower = faster purchases, less zone commitment. Higher = more commitment required; frustration risk if zone is in a dangerous position. Validated at 0.8s in prototype 2. |
| `ZONE_RADIUS` | 90px | 60–120px | Lower = tighter spatial commitment; touch frustration below ~70px. Higher = zone entry too easy, spatial tension reduced. Tune alongside zone placement. |
| `ARCHER_COST_TIER_1` | 30g | 20–50g | Cost for archers 1–4. Lower = formation fills too fast. Higher = early game starved, Wave 1–2 too fragile. |
| `ARCHER_COST_TIER_2` | 60g | 40–100g | Cost for archers 5–8. Lower = formation fills too fast at mid-game. Higher = formation may never fully fill in a 13-wave run. |
| `TOWER_COST` | 100g | 60–200g | (MVP) Cost of placing an Archer Tower. Tune relative to `ARCHER_COST_TIER_2` — tower should feel like a significant investment. Archer Tower promoted to MVP 2026-05-19 (D-01). |
| `FORGE_COST` | 200g | 100–300g | (Alpha) Cost of a Forge upgrade. Should represent a gold commitment that directly competes with filling the formation. |
| `COIN_POOL_MAX` | 120 | 60–240 | Safety cap on active GoldCoin count. Too low = coins silently lost during high-kill waves. Too high = unbounded memory in edge cases. |
| `UPKEEP_PER_ARCHER` | 3g | 1–8g | Sprint 5 — Maintenance cost per archer per wave. Lower = upkeep barely noticeable; strategic tension diminished. Higher = players cannot afford to maintain large formations without near-perfect kill efficiency. **Coupled with `GOLD_DROP_PER_ENEMY`** — increase drop if upkeep is increased. |
| `UPKEEP_PER_TOWER` | 8g | 4–20g | Sprint 5 — Maintenance cost per tower per wave. Should roughly equal the cost of keeping 2–3 archers, since a tower replaces 2 formation archers. At 8g, one tower = ~2.67 archer-equivalents of upkeep — intentionally slightly more expensive to reflect the tower's superior firepower. |
| `UPKEEP_NOTICE_DURATION` | 1.5s | 0.5–3.0s | Sprint 5 — Duration of the HUD upkeep notification. Too short = players miss the feedback and confuse upkeep with gold drain from purchases. Too long = notification persists into the next wave. |
| `TARGETING_ZONE_POS` | (135, 750) | (50–270, 500–900) | Sprint 5 — World position of the Targeting Priority dwell zone. Only active after "Targeting Protocol" Forge upgrade. Place away from common enemy paths and existing zones. |
| `FORMATION_ZONE_POS` | (810, 750) | (540–960, 500–900) | Sprint 5 — World position of the Formation Mode dwell zone. Only active after "Formation Doctrine" Forge upgrade. Symmetric to TARGETING_ZONE_POS. |

### Cross-Knob Interactions

- **`GOLD_DROP_PER_ENEMY` × `ARCHER_COST_TIER_1`**: The ratio `ARCHER_COST_TIER_1 / GOLD_DROP_PER_ENEMY = 2.0` is the kill-to-archer ratio (2 kills = 1 Tier 1 archer). This ratio is the primary pacing lever. Always adjust the pair together.
- **`DWELL_TIME` × `INTER_WAVE_PAUSE`** (INTER_WAVE_PAUSE owned by Enemy Wave GDD): `INTER_WAVE_PAUSE / DWELL_TIME = 12.5` = max archers purchasable per pause. If INTER_WAVE_PAUSE is decreased (tighter windows), DWELL_TIME should also decrease proportionally to preserve purchase throughput.
- **`ZONE_RADIUS` × zone world position**: If ZONE_RADIUS increases, the zone center must move further from common combat positions to prevent accidental dwell entry during active waves. These two values must be tuned together with the level designer.

## Acceptance Criteria

### H-1 — Session Reset

- **GIVEN** the player has any gold amount, **WHEN** `session_reset` fires, **THEN** `gold` equals exactly 60 in the same frame.
- **GIVEN** `dwell_timer = 0.5s` while the hero is inside a zone, **WHEN** `session_reset` fires, **THEN** `dwell_timer = 0.0` and HUD fill ratio = 0.0.
- **GIVEN** 10 GoldCoins exist in the world (150g total), **WHEN** `session_reset` fires, **THEN** all 10 coins are freed and `gold = 60` (not 210) — cleared coins grant no gold.
- **GIVEN** `dwell_timer = 0.79s` (just below threshold), **WHEN** `session_reset` fires, **THEN** no `recruit_purchased` signal is emitted and `gold = 60`.

### H-2 — Gold Drop on Enemy Death

- **GIVEN** an enemy dies at position (450, 800), **WHEN** `enemy_died(Vector2(450, 800))` fires, **THEN** exactly one GoldCoin is instantiated at (450, 800) with value 15.
- **GIVEN** any enemy dies, **WHEN** the coin is inspected immediately after spawn, **THEN** its value property equals exactly 15.
- **GIVEN** 5 enemies die in the same frame at distinct positions, **WHEN** all 5 `enemy_died` signals fire, **THEN** exactly 5 GoldCoins exist, one at each position.

### H-3 — Magnet Collection (Formula D-2)

- **GIVEN** a coin at (300, 500) and hero at (300, 500) (distance = 0px), **WHEN** the next frame processes, **THEN** `gold += 15`, coin is freed, `gold_changed` emitted.
- **GIVEN** a coin exactly 170px from the hero, **WHEN** the next frame processes, **THEN** the coin is collected (boundary is inclusive).
- **GIVEN** a coin exactly 171px from the hero, **WHEN** the next frame processes, **THEN** the coin is NOT collected and remains in the scene tree.
- **GIVEN** 4 coins all within 100px of the hero, **WHEN** the next frame processes, **THEN** all 4 are freed and `gold += 60`.
- **GIVEN** a coin is within 50px of the hero and the game is in GAME_OVER, **WHEN** a frame processes, **THEN** coin is not collected and `gold` is unchanged.

### H-4 — Coin Persistence and Pool Cap

- **GIVEN** a GoldCoin was spawned 30 seconds ago and the hero has never been near it, **WHEN** the coin is inspected, **THEN** it still exists with value 15.
- **GIVEN** exactly 120 coins exist (pool full), **WHEN** a 121st coin spawns, **THEN** the oldest coin is freed and total count remains 120.
- **GIVEN** pool eviction frees the oldest coin, **WHEN** the eviction processes, **THEN** `gold` does not change and `gold_changed` is not emitted.

### H-5 — Dwell Timer and Zone Proximity (Formulas D-3, D-4)

- **GIVEN** the hero is at the zone center, **WHEN** 0.4s of game time accumulate, **THEN** `dwell_timer ≈ 0.4` (within one frame's delta tolerance).
- **GIVEN** `dwell_timer = 0.5s`, **WHEN** the hero moves to 91px from the zone center, **THEN** `dwell_timer = 0.0` in that same frame.
- **GIVEN** `dwell_timer = 0.0`, **WHEN** `dwell_fill_ratio` is read, **THEN** it equals 0.0. **GIVEN** `dwell_timer ≥ 0.8`, **WHEN** `dwell_fill_ratio` is read, **THEN** it equals exactly 1.0 (not greater).
- **GIVEN** `dwell_timer = 0.4`, **WHEN** `dwell_fill_ratio` is read, **THEN** it equals 0.5.
- **GIVEN** the hero enters the zone, stays 0.79s, then exits, **WHEN** the hero exits, **THEN** `dwell_timer = 0.0`, no `recruit_purchased` emitted, `gold` unchanged.

### H-6 — Purchase Logic (Formulas D-5, D-6)

- **GIVEN** `current_archer_count ∈ {0, 1, 2, 3}`, **WHEN** `recruit_cost(n)` is evaluated, **THEN** result equals exactly 30.
- **GIVEN** `current_archer_count ∈ {4, 5, 6, 7}`, **WHEN** `recruit_cost(n)` is evaluated, **THEN** result equals exactly 60.
- **GIVEN** `gold = 40`, `current_archer_count = 2` (cost = 30g), `dwell_timer ≥ 0.8s`, zone active, **WHEN** purchase fires, **THEN** `gold = 10`, `recruit_purchased` emitted once, `dwell_timer = 0.0`.
- **GIVEN** `gold = 25`, `current_archer_count = 0` (cost = 30g), `dwell_timer ≥ 0.8s`, **WHEN** purchase evaluates, **THEN** `gold = 25`, `recruit_purchased` NOT emitted, `dwell_timer = 0.0`, no error logged.
- **GIVEN** a purchase succeeds and `dwell_timer` resets, **WHEN** the hero remains inside the zone and dwells another 0.8s, **THEN** a second purchase can succeed (no cooldown).
- **GIVEN** `gold ≥ cost` AND `dwell_timer ≥ 0.8s` BUT `zone.is_active = false`, **WHEN** the purchase is evaluated, **THEN** no purchase occurs and `recruit_purchased` is not emitted.

### H-7 — Full Formation Edge Case

- **GIVEN** `current_archer_count = 7` and a purchase succeeds, **WHEN** the purchase completes, **THEN** `zone.is_active = false` before the next frame.
- **GIVEN** `current_archer_count = 8` and `zone.is_active = false`, and the hero stands at zone center for 5 seconds, **WHEN** those 5 seconds pass, **THEN** `dwell_timer = 0.0` throughout.

### H-8 — HUD Signals

- **GIVEN** a coin is collected and `gold` changes from 60 to 75, **WHEN** collection processes, **THEN** `gold_changed(75)` is emitted.
- **GIVEN** `gold = 90` and a Tier 1 purchase succeeds, **WHEN** deduction occurs, **THEN** `gold_changed(60)` is emitted.
- **GIVEN** pool eviction frees a coin (no gold granted), **WHEN** eviction processes, **THEN** `gold_changed` is NOT emitted.

### H-9 — Wave Gold Formula (Formula D-1)

- **GIVEN** wave N has E enemies, all die and all coins are collected, **WHEN** the wave ends, **THEN** gold gained from that wave equals exactly `E × 15`.
- **GIVEN** wave N has 10 enemies but only 6 coins are collected, **WHEN** the wave ends, **THEN** `gold` increased by exactly 90 (not 150) — uncollected coins grant no gold passively.

### H-10 — Economy Active State

- **GIVEN** game is in PLAYING state during the 10s inter-wave pause, **WHEN** the hero moves within 170px of a coin, **THEN** coin is collected normally.
- **GIVEN** game is in GAME_OVER, **WHEN** coins exist and the hero overlaps them, **THEN** no coins are collected, dwell timer does not increment, `gold` unchanged.

### H-11 — Wave Upkeep (Sprint 5, Formula D-7)

- **GIVEN** a wave ends with 4 archers and 0 towers (`wave_upkeep = 12g`), gold = 80g, **WHEN** upkeep fires, **THEN** `gold = 68g`, `gold_changed(68)` emitted, `upkeep_deducted(12, 68)` emitted.

- **GIVEN** a wave ends with 8 archers and 2 towers (`wave_upkeep = 40g`), gold = 30g, **WHEN** upkeep fires, **THEN** `gold = 0` (floored), `upkeep_deducted(30, 0)` emitted (not 40 — only 30 was available).

- **GIVEN** `gold = 0` at wave end, `wave_upkeep > 0`, **WHEN** upkeep fires, **THEN** `gold` remains 0; no negative balance; `upkeep_deducted(0, 0)` emitted.

- **GIVEN** a wave ends, upkeep fires and deducts 18g, **WHEN** deduction processes, **THEN** `gold_changed` is emitted ONCE (not once per archer/tower) with the final new balance.

- **GIVEN** GAME_OVER fires mid-wave (castle falls), **WHEN** GAME_OVER processes, **THEN** no upkeep deduction fires — wave was not cleared; `upkeep_deducted` is not emitted.

- **GIVEN** wave_end fires, **WHEN** 1.5s pass after `upkeep_deducted`, **THEN** the HUD notification has been displayed and dismissed (exact timing spec belongs to hud.md).

- **GIVEN** a tower is purchased mid-wave (during PLAYING state), `tower_count` changes from 0 to 1, **WHEN** that wave ends and upkeep fires, **THEN** `tower_count = 1` is used in the formula; upkeep includes `UPKEEP_PER_TOWER = 8g` for that tower.

### H-12 — Sprint 5 Zones (Targeting, Formation)

- **GIVEN** "Targeting Protocol" upgrade NOT purchased, **WHEN** the hero dwells at TARGETING_ZONE_POS for 3.0s, **THEN** `targeting_mode_cycled` signal is NOT emitted; Economy dwell timer does NOT accumulate for that position.

- **GIVEN** "Targeting Protocol" upgrade purchased, **WHEN** the hero dwells at TARGETING_ZONE_POS for 0.6s, **THEN** `targeting_mode_cycled(FIRST)` is emitted (first cycle from NEAREST); Economy's dwell timer for that zone resets.

- **GIVEN** "Formation Doctrine" upgrade purchased, **WHEN** the hero dwells at FORMATION_ZONE_POS for 0.6s, **THEN** `formation_mode_cycled(LINE)` is emitted.

- **GIVEN** the hero is simultaneously inside TARGETING_ZONE and RECRUIT_ZONE (overlapping due to proximity tuning error), **WHEN** dwell timers run, **THEN** both zones accumulate independently — both can trigger on the same dwell session. Flag this as a tuning error in the level edit if it occurs.

## Open Questions

1. **Zone world position (RECRUIT_ZONE center)**: Not yet defined. Must be placed by the level designer such that: (a) it is reachable in ≤ 2s of hero movement from the castle area, (b) it does not overlap with common enemy patrol paths (to prevent accidental dwell), (c) it is visible on screen during the inter-wave pause. Owner: Level/World design. Target: before Vertical Slice.

2. **Silent failure UX (Section C Rule 8)**: Players who dwell 0.8s but cannot afford the purchase receive no feedback. The HUD gold counter communicates affordability indirectly, but there is no connection between the zone and the cost display. Risk of player confusion. Consider adding an always-visible cost label on the zone. Owner: UX/HUD design. Target: HUD GDD.

3. **Post-cap gold sink — RESOLVED (2026-05-19)**: Archer Tower promoted to MVP scope. Once all 8 archers are recruited, TOWER_COST = 100g provides ongoing spending decisions via TOWER_ZONE. Pillar 2 ("Chaque pièce d'or est une décision") extends beyond Wave 3. See /review-all-gdds 2026-05-19 D-01 for rationale.

4. **`ARCHER_COST_TIER_1 / GOLD_DROP_PER_ENEMY` coupling**: These two constants are paired — the kill-to-archer ratio is 2.0. They must be tuned together. Document as a locked pair in the balance spreadsheet. Owner: Balance / Economy. Target: before Production.

5. **Dwell timer grace window**: An agent flagged that resetting the timer hard on zone exit (rather than after a 0.1–0.2s grace) creates a harsh UX edge at high fill ratios (e.g. 98% fill, brief joystick overshoot → full reset). Validate in playtest: if testers consistently express frustration at near-complete dwell resets, add a 0.15s grace period before the timer zeroes. Owner: Playtest / UX. Target: after first internal playtest.

6. **Coin despawn or wave sweep**: The agents flagged that uncollected coins accumulate across waves, potentially hitting `COIN_POOL_MAX`. An alternative to the pool cap is a wave-start sweep that clears all coins (without granting gold). This is simpler to implement but more abrupt. Decide before implementation. Owner: Programmer / Economy. Target: before Production.
