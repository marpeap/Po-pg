# Archer Tower

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 2 — Chaque pièce d'or est une décision; Pillar 3 — L'armée se voit grandir

## Overview

The Archer Tower is a purchasable fixed-position ranged unit. When the player dwells at a TOWER_ZONE for DWELL_TIME (0.8 s) and spends TOWER_COST (100 g), the Economy system emits `tower_purchased`. Archer Tower responds by transferring N archers from the mobile V-formation into a new node anchored at the TOWER_ZONE world position. The tower fires continuously at enemies using the same PROJ_DAMAGE (8 HP) and SHOOT_IVTL (0.9 s) values as the mobile formation — it is not a separate weapon system, but a relocated subset of the archer pool with a fixed world anchor instead of a hero-follow offset.

The player-facing effect is a permanent spatial trade: a smaller, faster-reacting mobile formation in exchange for a turret that covers a fixed corridor regardless of the hero's position. This is the game's primary gold expenditure beyond archer recruitment — TOWER_COST (100 g) is a one-way commitment that persists for the remainder of the run, making it the defining expression of Pillar 2 ("Chaque pièce d'or est une décision") at the Vertical Slice milestone.

The Archer Tower is an **MVP feature** (promoted from Vertical Slice on 2026-05-19 — see /review-all-gdds D-01: gold sink gap resolution). TOWER_ZONE nodes are active in the MVP world scene. The system resolves Pillar 2 dormancy: once all 8 archers are recruited (~Wave 3), the tower provides the next meaningful gold expenditure decision.

## Player Fantasy

Buying a tower feels like a command decision, not a purchase. The player has held the TOWER_ZONE long enough, the gold is gone, and suddenly two archers peel away from the V-formation and lock onto a fixed world position. The formation behind the hero is visibly smaller now — and the tower begins firing immediately.

The fantasy has two simultaneous halves. The first is pride of ownership: the tower stands as permanent evidence of planning. Every arrow it launches while the hero roams freely is a dividend on a strategic commitment made earlier in the run. The second is productive tension: the mobile formation is now thinner, which means the hero must work harder — move smarter, collect gold faster, protect the remaining archers. The tower removes one problem (covering a fixed corridor) while sharpening another (mobile survivability).

This is Pillar 3 made spatial. The army is no longer just the V-formation trailing the hero — it now has a second presence in the world, a fixed anchor the player chose, placed, and paid for. "L'armée se voit grandir" at the Vertical Slice means not just more archers in a line, but archers distributed across the world in positions the player decided.

The tower should feel permanent and earned. It must never feel like a passive bonus — the cost in both gold and formation depth must be legible in the moments immediately after purchase.

## Detailed Design

### Core Rules

**R1 — Zone Availability**
Each TOWER_ZONE node (Area2D, radius ZONE_RADIUS = 90px) is in state ZONE_AVAILABLE at run start. The dwell affordability prompt is visible only when both conditions are met: player gold ≥ TOWER_COST (100g) AND mobile formation archer count ≥ TOWER_ARCHERS_COUNT (2). If either condition is false, the zone appears inactive (no progress ring).

**R2 — Purchase Activation**
Economy handles dwell detection at TOWER_ZONE using the standard mechanic (ZONE_RADIUS = 90px, DWELL_TIME = 0.8s). On successful dwell completion, Economy deducts TOWER_COST and emits `tower_purchased(zone_position: Vector2)`. This is the only signal Archer Tower listens to from Economy.

**R3 — Signal Fan-Out on Purchase**
Both Archer Tower and Archer Formation respond to `tower_purchased`:
- **Archer Formation** removes TOWER_ARCHERS_COUNT slots from the mobile pool immediately. These archers are permanently deassigned from V-formation geometry. Archer Formation emits `formation_count_changed(new_count)` so HUD updates the archer badge.
- **Archer Tower** spawns an ArcherTower node at `zone_position`.

**R4 — Tower Spawn**
The ArcherTower node is a Node2D anchored at `zone_position`. It contains TOWER_ARCHERS_COUNT archer sprites in a compact static arrangement (not V-formation geometry — a tight cluster or side-by-side pair). The tower begins in FIRING state if enemies are already within TOWER_RANGE; otherwise begins in IDLE.

**R5 — Zone Deactivation**
After a tower is placed, the TOWER_ZONE transitions to ZONE_PURCHASED. The dwell prompt disappears permanently. The zone cannot be re-activated during the same run.

**R6 — Firing Behavior**
The ArcherTower maintains a list of enemies within TOWER_RANGE (400px) via Area2D overlap. When the list is non-empty, the tower fires a simultaneous volley of TOWER_ARCHERS_COUNT projectiles at the nearest enemy every SHOOT_IVTL (0.9s) — matching the formation's volley behavior for a sub-group of the same size. Projectile parameters: PROJ_DAMAGE = 8 HP per projectile, PROJ_SPEED = 600 px/s. Targeting priority: nearest enemy by Euclidean distance. If two enemies are equidistant, either may be targeted (no tiebreak required).

**R7 — IDLE Behavior**
If no enemies are within TOWER_RANGE, the tower enters IDLE. No projectiles fire. Archer sprites hold a static rest pose. The tower returns to FIRING immediately when any enemy enters TOWER_RANGE (no delay or warmup).

**R8 — Indestructibility**
Towers cannot be damaged, destroyed, sold, or relocated. Enemies that collide with the tower node's position continue marching toward the castle without interacting with the tower. Towers persist for the entire run including all inter-wave pauses.

**R9 — Multiple Zones**
Multiple TOWER_ZONE nodes may coexist in the world scene. Each operates independently. The player may purchase a tower at each available zone in sequence, subject to the cost and archer count requirements at each purchase moment.

**R10 — Minimum Archer Floor**
There is no minimum archer floor enforced by Archer Tower. If the player has exactly TOWER_ARCHERS_COUNT (2) archers and buys a tower, the result is 0 mobile archers. This is a valid (extreme) player state. Pillar 2 principle: the cost and consequence are visible — the player made the choice.

---

### States and Transitions

**TOWER_ZONE node states:**

| State | Condition | Visual |
|-------|-----------|--------|
| ZONE_AVAILABLE | No tower placed here | Dwell prompt shown when gold ≥ TOWER_COST AND count ≥ TOWER_ARCHERS_COUNT |
| ZONE_PURCHASED | Tower placed | No prompt; zone is inert for the remainder of the run |

**ArcherTower node states:**

| State | Entry Condition | Exit Condition |
|-------|----------------|----------------|
| IDLE | Spawned with 0 enemies in range, OR last enemy leaves TOWER_RANGE | An enemy enters TOWER_RANGE |
| FIRING | ≥1 enemy within TOWER_RANGE | All enemies leave TOWER_RANGE |

---

### Interactions with Other Systems

| Direction | System | Data / Signal |
|-----------|--------|---------------|
| ← Receives | Economy | `tower_purchased(zone_position: Vector2)` — triggers tower spawn |
| ← Responds (same signal) | Archer Formation | Also receives `tower_purchased` — releases TOWER_ARCHERS_COUNT slots and emits `formation_count_changed` |
| ← Detects | Enemy Wave | Enemy node enters/exits TOWER_RANGE via Area2D `body_entered` / `body_exited` |
| → Spawns | Projectile system | Same projectile scene as Archer Formation, fired at rate SHOOT_IVTL |
| → Indirectly triggers | HUD | Via Archer Formation's `formation_count_changed` — HUD archer badge updates |

No outbound signals are defined for Archer Tower in the Vertical Slice. It is a consumer of Economy's signal and a client of the shared projectile system.

---

*Note (lean mode): specialist agents not consulted for Section C. Review manually before production.*

## Formulas

### F1: tower_volley_damage

The tower_volley_damage formula is defined as:

`tower_volley_damage = TOWER_ARCHERS_COUNT × PROJ_DAMAGE`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Archers in tower | TOWER_ARCHERS_COUNT | int | 2 (fixed) | Archers permanently committed to one tower |
| Damage per projectile | PROJ_DAMAGE | int | 8 HP | Damage dealt per projectile on hit |

**Output Range:** Fixed at 16 HP per volley. Constant — does not vary by wave or enemy.
**Example:** `tower_volley_damage = 2 × 8 = 16 HP`

---

### F2: tower_dps

The tower_dps formula is defined as:

`tower_dps = (TOWER_ARCHERS_COUNT × PROJ_DAMAGE) / SHOOT_IVTL`

This is formation_dps(n) with n = TOWER_ARCHERS_COUNT. It is the same formula applied to a fixed sub-pool.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Archers in tower | TOWER_ARCHERS_COUNT | int | 2 (fixed) | — |
| Damage per projectile | PROJ_DAMAGE | int | 8 HP | — |
| Fire interval | SHOOT_IVTL | float | 0.9s | Time between volleys |

**Output Range:** Fixed at 17.78 HP/s per tower. Constant.
**Example:** `tower_dps = (2 × 8) / 0.9 = 17.78 HP/s`

---

### F3: post_purchase_formation_dps

After buying a tower, the mobile formation loses TOWER_ARCHERS_COUNT archers:

`post_purchase_formation_dps(n) = ((n - TOWER_ARCHERS_COUNT) × PROJ_DAMAGE) / SHOOT_IVTL`

where n = formation count before purchase.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Formation count before purchase | n | int | 2–8 | Must be ≥ TOWER_ARCHERS_COUNT for purchase to be valid |
| Archers absorbed | TOWER_ARCHERS_COUNT | int | 2 (fixed) | — |
| PROJ_DAMAGE | — | int | 8 HP | — |
| SHOOT_IVTL | — | float | 0.9s | — |

**Output Range:** 0 HP/s (n=2, entire formation absorbed) to 53.33 HP/s (n=8, formation drops to 6).
**Example (n=6):** `post_purchase_formation_dps = ((6 - 2) × 8) / 0.9 = 35.56 HP/s`

---

### F4: system_dps (combined mobile + tower)

`system_dps(n, t) = formation_dps(n - t×TOWER_ARCHERS_COUNT) + t × tower_dps`

where n = total archers recruited and t = towers purchased.

**Key identity:** When all enemies are within range of both systems simultaneously, `system_dps = formation_dps(n)` — total raw DPS is **unchanged** by tower purchases. Towers redistribute DPS spatially; they do not add to it.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Total archers recruited | n | int | 2–8 | — |
| Towers purchased | t | int | 0–(n÷2) | Limited by archer supply |
| TOWER_ARCHERS_COUNT | — | int | 2 | — |

**Output Range:** 0 HP/s (pathological: n=0) to 71.11 HP/s (n=8, all archers deployed regardless of allocation). System DPS ceiling is locked by total archer count, not tower count.
**Example (n=8, t=2):** `system_dps = formation_dps(4) + 2×17.78 = 35.56 + 35.56 = 71.11 HP/s`

---

### F5: tower_purchasable (purchase gate)

`tower_purchasable = (current_formation_size ≥ TOWER_ARCHERS_COUNT)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current mobile archers | current_formation_size | int | 0–8 | Count at moment of dwell completion |
| Purchase threshold | TOWER_ARCHERS_COUNT | int | 2 | Minimum archers required |

**Output Range:** Boolean. `true` when formation_size ≥ 2; `false` otherwise. When false, TOWER_ZONE dwell progress does not start (same as gold-insufficient behavior at RECRUIT_ZONE).
**Example:** Player has 3 archers → `tower_purchasable = (3 ≥ 2) = true`. After purchase: 1 archer remains. Second purchase: `(1 ≥ 2) = false` — blocked.

---

### F6: volleys_to_kill (tower vs single enemy)

`volleys_to_kill(wave) = ceil(enemy_hp(wave) / tower_volley_damage)`

where `enemy_hp(wave) = ENEMY_HP_BASE + (wave - 1) × ENEMY_HP_SCALING = 30 + (wave - 1) × 3`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave number | wave | int | 1–∞ | Current wave index |
| ENEMY_HP_BASE | — | int | 30 HP | Enemy HP at wave 1 |
| ENEMY_HP_SCALING | — | int | 3 HP/wave | Linear HP growth |
| tower_volley_damage | — | int | 16 HP | Damage per tower volley |

**Output Range:** 2 volleys (wave 1, 30 HP) to ~12 volleys (wave 55, 192 HP). Under current values the tower fires 12 volleys per enemy pass (see F7) and can solo-kill enemies until approximately wave 55.

| Wave | Enemy HP | Volleys to Kill | Time to Kill |
|------|----------|-----------------|--------------|
| 1 | 30 HP | 2 | 1.8s |
| 5 | 42 HP | 3 | 2.7s |
| 10 | 57 HP | 4 | 3.6s |
| 20 | 87 HP | 6 | 5.4s |
| 55 | 192 HP | 12 | 10.8s |

**Example (wave 10):** `volleys_to_kill = ceil(57 / 16) = 4` volleys × 0.9s = 3.6s TTK.

---

### F7: engagement_time (enemy in tower range)

`engagement_time = (2 × TOWER_RANGE) / ENEMY_SPEED`

Assumes enemy travels through the center of the tower's detection circle on a straight vertical path (maximum engagement window).

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Tower range radius | TOWER_RANGE | int | 400px | Engagement radius |
| Enemy speed | ENEMY_SPEED | float | 70 px/s | From entity registry |

**Output Range:** Fixed at 11.43s with current constants. Tower fires `floor(11.43 / 0.9) = 12` volleys per enemy engagement.
**Example:** `engagement_time = 800 / 70 = 11.43s → 12 volleys → 192 HP potential damage per pass`

---

### F8: coverage_fraction (spatial — map design reference)

`coverage_fraction = (2 × TOWER_RANGE) / ENEMY_TRAVEL_DISTANCE = 800 / 1860 ≈ 0.43`

A single tower placed at mid-path covers approximately 43% of the total enemy travel distance. Two non-overlapping towers cover ~86%. Informational — for map designer placement guidance only.

**Output Range:** Fixed at 0.43 with current constants.

---

*Note (lean mode): systems-designer consulted for Section D.*

## Edge Cases

**E1 — Exactly TOWER_ARCHERS_COUNT archers at purchase**
- **If** current_formation_size == TOWER_ARCHERS_COUNT (2) when `tower_purchased` fires: Archer Formation releases all 2 archers. Mobile formation size becomes 0. formation_dps = 0. This is a valid but extreme player state — R10 permits it explicitly. The hero fights alone; the tower provides all DPS.

**E2 — Race condition: `tower_purchased` arrives after archer count drops**
- **If** the player's archer count falls to < TOWER_ARCHERS_COUNT between dwell-start and dwell-completion: Economy checks affordability at dwell-completion, not dwell-start. The gate formula F5 is evaluated at the moment `tower_purchased` would fire. If the count is now insufficient, Economy must NOT emit `tower_purchased` and no gold is deducted. In Vertical Slice, archer count cannot decrease during a run (no archer death mechanic), so this race condition does not apply; flag for future versions.

**E3 — Duplicate `tower_purchased` for same TOWER_ZONE**
- **If** `tower_purchased` is emitted twice for the same zone position (signal reconnection bug, scene reload): Archer Tower checks whether an ArcherTower node already exists at `zone_position` before spawning. If a node exists at that position (within a snap threshold), the second spawn is silently ignored. No double-absorption of archers.

**E4 — Enemy already in TOWER_RANGE at spawn**
- **If** enemies are already within TOWER_RANGE when the tower spawns (purchased mid-wave): Tower enters FIRING state immediately on `_ready()`. No warmup delay. The SHOOT_IVTL timer begins its first cycle immediately.

**E5 — Enemy exits TOWER_RANGE before tower kills it**
- **If** an enemy exits TOWER_RANGE before taking lethal damage: Tower removes it from the target list and transitions to IDLE if no other enemies remain in range. No pursuit or extended-range behavior. The mobile formation or other towers handle the escaped enemy.

**E6 — Enemy dies during SHOOT_IVTL cooldown window**
- **If** the nearest target enemy is killed by the mobile formation or another tower while the ArcherTower is mid-SHOOT_IVTL cycle: On the next volley trigger, the tower recomputes the nearest enemy from the current list. If the list is empty, the volley fires at nothing (discarded). The SHOOT_IVTL cycle continues regardless.

**E7 — Formation and tower fire at same enemy simultaneously**
- **If** both the mobile formation and a tower target the same enemy in the same frame: Both volleys apply independently. The enemy takes tower_volley_damage + formation volley_damage in the same frame. No damage cap per enemy per frame. This is intended — it is the natural outcome of the player positioning the hero near the tower. No conflict resolution needed.

**E8 — TOWER_ZONE available during INTER_WAVE_PAUSE**
- **If** the player dwells at a TOWER_ZONE during the 10s inter-wave pause: Dwell detection is active whenever game state is not HUD_HIDDEN or GAME_OVER. Economy handles TOWER_ZONE dwell during INTER_WAVE_PAUSE exactly as it handles RECRUIT_ZONE dwell — the pause is the intended window for strategic purchases. The tower becomes active immediately and fires when wave N+1 enemies arrive.

**E9 — Hero walks through tower position**
- **If** the hero moves into the same world position as an ArcherTower node: Hero movement is unaffected. Towers do not block hero movement and do not interact with enemies physically — R8 guarantees indestructibility and non-blocking behavior for both hero and enemies.

**E10 — Two TOWER_ZONE nodes with overlapping ranges**
- **If** two TOWER_ZONE nodes are placed close enough that TOWER_RANGE circles overlap: Both towers fire independently. An enemy in the overlap zone is targeted by both towers simultaneously and takes additive damage. This is intended spatial design — overlapping coverage is a power option for a well-funded player.

**E11 — TOWER_ZONE outside current camera view**
- **If** a TOWER_ZONE is positioned outside the current camera viewport when the hero approaches: The affordability prompt becomes visible as the camera follows the hero into range. Level design must ensure TOWER_ZONE nodes are placed in areas naturally traversed by the hero. This is a map authoring constraint, not a system-level edge case.

**E12 — Game over while tower is firing**
- **If** castle HP reaches 0 while one or more towers are in FIRING state: The Game State Machine emits `game_state_changed(GAME_OVER)`. All ArcherTower nodes stop firing (SHOOT_IVTL timer paused or node freed). No cleanup of transferred archers is required — the run ends.

## Dependencies

### Hard Dependencies (system cannot function without these)

| System | Direction | Interface |
|--------|-----------|-----------|
| Economy | Upstream | Emits `tower_purchased(zone_position: Vector2)`. Economy owns TOWER_ZONE dwell detection, gold deduction, and the F5 purchase gate (gold ≥ TOWER_COST AND formation_size ≥ TOWER_ARCHERS_COUNT). |
| Archer Formation | Upstream | Receives `tower_purchased` and releases TOWER_ARCHERS_COUNT slots from the mobile pool. Emits `formation_count_changed(new_count)` as a side-effect so HUD updates. The slot-release interface is defined in this GDD (R3) — Archer Formation GDD must add Archer Tower as a downstream dependent. |
| Enemy Wave | Upstream | Enemy nodes must be detectable via Area2D overlap (body_entered / body_exited). Archer Tower's FIRING state depends on enemy presence within TOWER_RANGE. |
| Game State Machine | Upstream | `game_state_changed(GAME_OVER)` stops all ArcherTower nodes. |

### Soft Dependencies (Vertical Slice)

| System | Direction | Interface |
|--------|-----------|-----------|
| Projectile system (Archer Formation) | Shared | Archer Tower reuses the same projectile scene as Archer Formation. No separate projectile is defined. |

### Downstream Dependents

No other system in the current index depends on Archer Tower. It is a terminal consumer node.

### Bidirectional Consistency Notes

- **Economy GDD** already defines `tower_purchased` and lists Archer Tower as a downstream recipient. Consistent.
- **Archer Formation GDD** lists Archer Tower as a soft downstream dependent with "no interface defined in MVP." This GDD defines that interface (R3). Archer Formation GDD should be updated during /design-review to note this GDD as the interface source.
- **HUD GDD** does not display tower count. The archer badge update on tower purchase flows through Archer Formation's `formation_count_changed` signal — HUD has no direct dependency on Archer Tower. Consistent.

## Tuning Knobs

| Knob | Current Value | Safe Range | Effect if Too Low | Effect if Too High | Owner |
|------|--------------|------------|-------------------|-------------------|-------|
| TOWER_COST | 100g | 60g – 200g | Tower purchased too early (wave 1–2), trivializes the mid-game economy before formation is filled | Tower never affordable within a normal run; feature never reached | economy |
| TOWER_ARCHERS_COUNT | 2 | 1 – 4 | Tower barely affects formation depth; purchase feels inconsequential | Buying one tower wipes most of the formation; risk too punishing for a first playtest | archer-tower |
| TOWER_RANGE | 400px | 150px – 600px | Tower only fires late in enemy approach; lane coverage too narrow for mobile casual play | Tower covers >50% of path from any central position; placement strategy disappears | archer-tower |

### Cross-Knob Interactions

- **TOWER_COST + GOLD_DROP_PER_ENEMY**: Break-even kills to afford tower = TOWER_COST / GOLD_DROP_PER_ENEMY = 100/15 ≈ 7 kills. Raise TOWER_COST without raising GOLD_DROP or the tower becomes unreachable in a normal run. Change these together.
- **TOWER_ARCHERS_COUNT + ARCHER_COST**: If TOWER_ARCHERS_COUNT is raised to 4, opportunity cost = 4 archer slots. At ARCHER_COST_TIER_1 = 30g, that is 120g locked plus 100g tower = 220g effective cost. Adjust TOWER_COST downward if TOWER_ARCHERS_COUNT increases.
- **TOWER_RANGE + ENEMY_SPEED**: engagement_time = (2×TOWER_RANGE) / ENEMY_SPEED. If ENEMY_SPEED doubles to 140 px/s, engagement_time halves to 5.7s → only 6 volleys per pass → tower cannot solo-kill enemies beyond wave 17. Rebalance TOWER_RANGE upward if ENEMY_SPEED increases.

## Visual/Audio Requirements

**Tower Zone visual (ZONE_AVAILABLE)**
Same dwell prompt component as RECRUIT_ZONE (progress ring, affordability color), owned and rendered by the Economy system. The Archer Tower system adds no additional node here. The affordability label must visually distinguish a tower purchase from an archer recruit — either a different icon (tower silhouette vs. archer figure) or a distinct text label at the prompt center.

**Tower Zone visual (ZONE_PURCHASED)**
Prompt disappears entirely. No residual indicator. The placed ArcherTower node provides the visual confirmation that this zone was used.

**ArcherTower node — structural sprite**
A compact base or platform sprite underneath the 2 archer figures. Style: same pixel art register as the rest of the game. Width: ≤80px (fits within the 90px zone radius). Must be visually distinct from the hero formation sprites at a glance — different stance (facing upward toward enemies rather than trailing behind the hero).

**Archer sprites on tower**
Side-by-side arrangement, centered on the tower node. Static pose (no walk/idle cycle animation in Vertical Slice). Archers face the direction of the nearest enemy in FIRING state, or face upward (toward the enemy approach direction) in IDLE.

**Tower firing VFX**
Reuse the existing formation projectile scene. No separate VFX asset needed. Volley of 2 projectiles fires simultaneously — same visual as any 2-archer sub-group in the formation.

**Purchase transition**
When `tower_purchased` fires: 2 archer sprites in the V-formation should visually lerp from their formation positions to the tower position (~0.3s) before the formation closes ranks. This communicates the transfer clearly. If the slot-position interface is unavailable, snap-to-position is the acceptable fallback for the first playable.

**Audio**

| Event | Sound | Owner | Notes |
|-------|-------|-------|-------|
| Tower purchased | Purchase confirmation SFX | Archer Tower | Distinct from archer recruit SFX — more "weighty" (e.g., stone placement). Single shot. |
| Tower volley fires | Arrow release SFX | Archer Tower | May reuse formation arrow SFX. Play once per volley, not once per projectile. |
| Tower IDLE | Silence | — | No ambient tower sound in Vertical Slice. |

*Asset spec pending art bible. Run `/asset-spec system:archer-tower` after art bible is approved.*

> **Asset Spec Flag** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:archer-tower` to produce per-asset visual descriptions and generation prompts from this section.

## UI Requirements

The Archer Tower has no dedicated HUD element in Vertical Slice. The only player-facing UI is the TOWER_ZONE affordability prompt, owned and rendered by the Economy system.

**Archer Tower's UI contract with Economy:**
- Economy must distinguish TOWER_ZONE prompts from RECRUIT_ZONE prompts visually — different icon (tower silhouette vs. archer figure) or distinct text label.
- The affordability condition (gold ≥ TOWER_COST AND formation_size ≥ TOWER_ARCHERS_COUNT) must be reflected in the prompt's visible/hidden state. If either condition fails, the prompt does not appear. No partial-disabled state.
- No gold cost label is displayed on the zone prompt in Vertical Slice (consistent with the recruit zone pattern).

**HUD impact:**
The HUD archer badge (defined in hud.md) updates automatically via `formation_count_changed` when archers transfer to a tower. No additional HUD element is required for Archer Tower. The badge shows remaining mobile archers; the player infers tower archers from the visible ArcherTower node on-screen.

**No new screens or flows** are added by Archer Tower. It has no menus, confirmation dialogs, or separate UI layers.

## Acceptance Criteria

### AC-R1: Zone Availability

**AC-R1a** GIVEN a new run starts, WHEN the scene loads, THEN every TOWER_ZONE node is in state ZONE_AVAILABLE with collision radius exactly 90px.

**AC-R1b** GIVEN gold = 99g and formation_size ≥ 2, WHEN the player dwells inside a ZONE_AVAILABLE, THEN the dwell prompt is not visible.

**AC-R1c** GIVEN gold ≥ 100g and formation_size = 1, WHEN the player dwells inside a ZONE_AVAILABLE, THEN the dwell prompt is not visible.

**AC-R1d** GIVEN gold = 100g and formation_size = 2, WHEN the player dwells inside a ZONE_AVAILABLE, THEN the dwell prompt becomes visible within one rendered frame.

---

### AC-R2: Purchase Activation

**AC-R2a** GIVEN the dwell prompt is visible, WHEN the player continuously dwells for exactly 0.8s, THEN `tower_purchased` fires. If the player exits at 0.79s, `tower_purchased` does NOT fire. *(Requires debug dwell_override.)*

**AC-R2b** GIVEN current gold = 150g, WHEN `tower_purchased` fires, THEN gold = 50g (deducted exactly 100g).

---

### AC-R3: Signal Fan-Out

**AC-R3a** GIVEN formation_size = 4, WHEN `tower_purchased` fires, THEN `formation_count_changed` is emitted and formation_size = 2.

**AC-R3b** GIVEN TOWER_ZONE at world position (X, Y), WHEN `tower_purchased` fires, THEN an ArcherTower node is present in the scene tree at (X, Y) ±0.5px.

---

### AC-R4: Tower Spawn

**AC-R4** GIVEN an ArcherTower has spawned, WHEN the node is inspected, THEN it contains exactly 2 archer sprites in a compact static arrangement (no movement, no animation).

---

### AC-R5: Zone Deactivation

**AC-R5a** GIVEN `tower_purchased` fires for a ZONE_AVAILABLE, THEN zone state = ZONE_PURCHASED and dwell prompt is not visible.

**AC-R5b** GIVEN a ZONE_PURCHASED, WHEN the player re-enters with gold ≥ 100g and formation_size ≥ 2, THEN the dwell prompt does NOT appear.

---

### AC-R6: Firing Behavior

**AC-R6a** GIVEN ≥1 enemy within 400px, WHEN one volley fires, THEN exactly 2 projectile nodes spawn simultaneously (same frame or ≤1 frame apart).

**AC-R6b** GIVEN continuous firing, WHEN intervals between consecutive volley spawns are measured, THEN interval = 0.9s ±0.05s. *(Requires timestamped volley log.)*

**AC-R6c** GIVEN a projectile hits an enemy, THEN enemy HP is reduced by exactly 8 HP per projectile.

**AC-R6d** GIVEN a projectile spawns, WHEN velocity is sampled, THEN magnitude = 600 px/s ±1 px/s. *(Requires debug velocity read.)*

**AC-R6e** GIVEN multiple enemies in range, WHEN a volley fires, THEN both projectiles target the enemy closest to the tower by Euclidean distance.

**AC-R6f** GIVEN no enemies within 400px, THEN zero projectiles spawn from that tower in any observed frame.

---

### AC-R7: Idle Behavior

**AC-R7a** GIVEN no enemies in range, WHEN tower state is inspected, THEN state = IDLE and no projectiles emit.

**AC-R7b** GIVEN tower is IDLE, WHEN an enemy enters within 400px, THEN tower transitions to FIRING and first volley fires within ≤0.9s of entry.

---

### AC-R8: Indestructibility

**AC-R8a** GIVEN an enemy collides with the tower's world position, THEN the ArcherTower node remains in the scene tree unchanged.

**AC-R8b** GIVEN a tower at (X, Y), WHEN an enemy moves through (X, Y), THEN enemy is not blocked, deflected, or destroyed.

**AC-R8c** GIVEN a tower was spawned during the run, WHEN waves complete without GAME_OVER, THEN the tower remains in the scene tree.

---

### AC-R9: Multiple Zones

**AC-R9a** GIVEN Zone A and Zone B both ZONE_AVAILABLE, WHEN `tower_purchased` fires for Zone A only, THEN Zone A = ZONE_PURCHASED and Zone B = ZONE_AVAILABLE.

**AC-R9b** GIVEN two towers — one with enemies in range, one without — WHEN one frame is observed, THEN only the tower with enemies emits projectiles.

---

### AC-R10: No Archer Floor

**AC-R10** GIVEN formation_size = 0 (all archers committed to towers), THEN no crash, error, or forced respawn occurs — game continues normally.

---

### AC-F1 — tower_volley_damage = 16 HP

GIVEN an enemy at 100 HP, WHEN a full tower volley (2 projectiles) hits, THEN enemy HP = 84 HP.

### AC-F2 — tower_dps = 17.78 HP/s

GIVEN an immortal enemy and continuous tower fire, WHEN damage is summed over 9.0s (10 volleys), THEN total damage = 160 HP. *(Requires immortal dummy enemy in test scene.)*

### AC-F3a — post_purchase_formation_dps correct at n=4

GIVEN formation drops from 4 to 2, WHEN formation fires, THEN 2 projectiles per 0.9s interval.

### AC-F3b — post_purchase_formation_dps = 0 at n=0

GIVEN formation_size = 0, THEN zero formation projectiles spawn in any observed frame.

### AC-F4 — System DPS is additive

GIVEN formation and tower both fire at same enemy in same interval, WHEN both volleys resolve, THEN damage = formation_volley_damage + 16 HP (not capped).

### AC-F5 — Purchase gate blocks at formation_size < 2

GIVEN formation_size = 1 and gold ≥ 100g, WHEN player completes full dwell, THEN `tower_purchased` does NOT fire and formation_size remains 1.

### AC-F6a — Volleys to kill at wave 1

GIVEN enemy HP = 30 (wave 1), WHEN tower fires continuously, THEN enemy survives volley 1 (HP = 14) and is destroyed on volley 2.

### AC-F6b — Volleys to kill at wave 3

GIVEN enemy HP = 36 (wave 3), WHEN tower fires continuously, THEN enemy survives volleys 1–2 (HP: 36→20→4) and is destroyed on volley 3. *(Requires `spawn_enemy(hp=36)` debug command.)*

### AC-F7 — engagement_time = 11.43s

GIVEN enemy at ENEMY_SPEED = 70 px/s on a straight path through tower range, WHEN entry and exit are timestamped via Area2D signals, THEN elapsed time = 11.43s ±0.1s.

---

### AC-E1 — Purchase valid at formation_size = 2

GIVEN formation_size = 2 and gold ≥ 100g, WHEN dwell completes, THEN `tower_purchased` fires, tower spawns, formation_size = 0, no crash or error.

### AC-E3 — Duplicate signal ignored

GIVEN zone = ZONE_PURCHASED with 1 tower present, WHEN `tower_purchased` fires again for the same zone, THEN scene tree contains exactly 1 ArcherTower at that position. *(Requires `force_emit_tower_purchased(zone_id)` debug button.)*

### AC-E4 — Fires immediately if enemies present at spawn

GIVEN ≥1 enemy within 400px at moment of tower spawn, WHEN spawn completes, THEN tower is in FIRING state and first volley fires within ≤0.9s.

### AC-E5 — Idles when target exits range

GIVEN tower is FIRING at an enemy, WHEN that enemy moves beyond 400px before dying, THEN tower transitions to IDLE and emits no further projectiles.

### AC-E6 — Retargets on next volley after target dies

GIVEN tower is mid-cycle targeting Enemy A, WHEN Enemy A dies before next volley fires, THEN next volley targets nearest living enemy within 400px — not Enemy A's last position. *(Requires `spawn_enemy(hp=8)` + synchronized formation shot.)*

### AC-E7 — Formation + tower damage is additive

GIVEN formation and tower both fire at same enemy in same cycle, WHEN both volleys resolve, THEN enemy HP reduction = formation_volley_damage + 16 HP (additive, not capped).

### AC-E8 — Purchase valid during INTER_WAVE_PAUSE

GIVEN game is in INTER_WAVE_PAUSE, gold ≥ 100g, formation_size ≥ 2, WHEN player dwells for 0.8s, THEN `tower_purchased` fires and tower spawns identically to mid-wave purchase.

### AC-E9 — Hero passes through tower unaffected

GIVEN tower at (X, Y), WHEN hero moves through (X, Y), THEN hero HP unchanged, hero not blocked, tower unchanged.

### AC-E12 — Towers stop on GAME_OVER

GIVEN one or more towers in FIRING state, WHEN GAME_OVER triggers, THEN all towers cease firing and zero projectile nodes spawn from any tower after the trigger frame. *(Requires post-GAME_OVER spawn log.)*

---

*Note (lean mode): qa-lead consulted. 4 HIGH-severity testability risks require debug infrastructure: dwell_override, timestamped volley log, debug velocity read, spawn_enemy(hp=N). See Open Questions.*

## Open Questions

**OQ-1: Multi-enemy retarget behavior within SHOOT_IVTL cycle**
*Owner: Archer Tower implementer | Resolution: Before first playable build*
When the nearest enemy dies mid-cycle, the tower retargets at the next volley trigger (E6). Confirm: the cycle continues on its existing schedule (not reset from the death moment). New target selected at the original tick time.

**OQ-2: TOWER_ZONE placement constraints for level designers**
*Owner: Level designer | Resolution: Before world scene authoring*
No rules govern TOWER_ZONE count, minimum y-coordinate, or minimum separation between zones. Recommended constraints for Vertical Slice: (a) max 2 TOWER_ZONE nodes per map, (b) minimum zone-center separation ≥ TOWER_RANGE (400px) to prevent trivial coverage overlap, (c) y-coordinate range 400px–1400px (hero-accessible, not in castle or spawn zones).

**OQ-3: Debug infrastructure required by acceptance criteria**
*Owner: Lead programmer | Resolution: Before first QA pass*
4 HIGH-severity ACs require test infrastructure not yet built:
- `dwell_override(duration_ms)` — for AC-R2a timing test
- Timestamped volley log — for AC-R6b fire interval test
- Debug velocity read on projectile — for AC-R6d speed test
- `spawn_enemy(hp=N)` — for AC-F6b wave-HP isolation test
- `force_emit_tower_purchased(zone_id)` — for AC-E3 duplicate signal test
Add to first playable tech backlog.

**OQ-4: Archer Formation GDD bidirectional update needed**
*Owner: GDD author | Resolution: During /design-review of archer-formation.md*
archer-formation.md lists Archer Tower as a soft downstream dependent with "no interface defined in MVP." This GDD (R3) defines that interface. When archer-formation.md is reviewed, update it to reference this GDD as the slot-release interface source.

**OQ-5: Purchase transition animation feasibility**
*Owner: Gameplay programmer | Resolution: First Vertical Slice sprint*
The Visual/Audio section specifies a ~0.3s lerp of archer sprites from formation slots to tower position. This requires the slot-release mechanism to expose slot world positions. If unavailable, snap-to-position is the fallback. Confirm interface before implementing.
