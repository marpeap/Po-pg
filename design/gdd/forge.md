# Forge

> **Status**: Designed
> **Author**: User + Agents
> **Last Updated**: 2026-05-19
> **Implements Pillar**: Pillar 3 — L'armée se voit grandir; Pillar 2 — Chaque pièce d'or est une décision

## Overview

The Forge is a run-time upgrade system that converts surplus gold into permanent stat amplification for the current play session. Four dedicated zones are permanently placed in the world — one per upgrade type (FORGE_ZONE_DMG, FORGE_ZONE_SPD, FORGE_ZONE_MAG, FORGE_ZONE_HP). The player chooses an upgrade by walking to the corresponding zone and dwelling for 0.8 seconds; spending 200g completes the purchase and the stat delta is applied immediately. No modal menu, no tap-on-card — selection is spatial, consistent with all other economy actions. Multiple dwells are allowed — upgrades stack — making the Forge a late-game gold sink that rewards players who have built a strong formation and accumulated surplus income. The FORGE_ZONEs are inactive in MVP and Vertical Slice; they activate at the Alpha milestone once archer and tower systems are balanced enough to calibrate upgrade magnitudes meaningfully.

## Player Fantasy

The Forge delivers the fantasy of *becoming unstoppable*. By the time the player can afford the Forge (200g surplus above a full 8-archer formation), they have already lived through waves of tight resource decisions. The Forge moment is the payoff: gold that would otherwise sit idle is transmuted into raw power. The decision carries weight and is made spatially — "I'm walking to the damage zone" — before the dwell even begins. "More damage per shot" means faster wave clears; "faster fire rate" means more total DPS; "wider magnet" means less gold left on the field. There is no wrong answer, but there is *your* answer — the one that fits your reading of the current wave pressure. Pillar 3 ("L'armée se voit grandir") extends here: the formation does not literally grow, but it hits harder, fires faster, and earns more — the army grows *in power* even when it cannot grow in numbers.

## Detailed Design

### Core Rules

**R1 — Milestone gating**: The FORGE_ZONE is inactive (invisible, non-interactable) in MVP and Vertical Slice builds. It becomes present in the game world only from the Alpha milestone onward.

**R2 — Dwell trigger**: The Forge uses the shared Economy dwell mechanic. The hero must remain within ZONE_RADIUS (90px) of the FORGE_ZONE for DWELL_TIME (0.8s) without releasing the joystick. The Economy system owns zone detection, timing, and gold deduction — the Forge system reacts to the resulting signal.

**R3 — Cost gate**: If the player's gold is below FORGE_COST (200g) when the dwell timer fires, the trigger is rejected silently. No menu appears, no gold is spent, and the FORGE_ZONE returns immediately to idle.

**R4 — Gold deduction**: When the dwell succeeds and gold ≥ FORGE_COST, the Economy system deducts FORGE_COST atomically and emits `forge_purchased` (with upgrade_type parameter identifying which zone fired). The Forge system receives this signal and applies the corresponding stat delta immediately. Gold is spent and the effect is applied in the same frame — the act of dwelling is the commitment.

**R5 — Upgrade selection via dedicated FORGE zones** *(redesigned 2026-05-19 — see D-02 in /review-all-gdds 2026-05-19)*: Each upgrade type has its own permanently-placed FORGE_ZONE in the world. The player selects an upgrade by dwelling on the corresponding zone. No modal menu, no tap-on-card — selection is spatial, consistent with all other economy actions. The four upgrade zones:
- `FORGE_ZONE_DMG` — dwell here to purchase `PROJ_DAMAGE_UP` (+FORGE_PROJ_DAMAGE_DELTA HP)
- `FORGE_ZONE_SPD` — dwell here to purchase `SHOOT_IVTL_DOWN` (−FORGE_IVTL_DELTA s, floored at SHOOT_IVTL_FLOOR)
- `FORGE_ZONE_MAG` — dwell here to purchase `GOLD_MAGNET_RADIUS_UP` (+FORGE_MAGNET_DELTA px)
- `FORGE_ZONE_HP`  — dwell here to purchase `CASTLE_MAX_HP_UP` (+FORGE_HP_DELTA HP)

Each zone costs FORGE_COST (200g) per dwell. Gold is deducted atomically on dwell completion. The upgrade applies immediately — no confirmation step.

**Design rationale**: The original modal-menu design required a tap-on-card interaction, creating a second input modality (joystick + tap) that violates Pillar 1 ("Un seul doigt, zéro friction") and the anti-pillar "no buttons/taps mid-combat." The spatial zone approach preserves the joystick-only control contract. The strategic choice ("which upgrade do I want?") is made by walking to the correct zone, not by reading a menu card.

**R6 — Upgrade effect**: The chosen stat delta is applied to the relevant runtime value immediately on dwell completion. The zone becomes available again immediately — no cooldown. Multiple purchases at the same zone are allowed (stacking).

**R7 — No refund**: Gold is committed at dwell completion. Walking away from a zone mid-dwell (before DWELL_TIME = 0.8s) cancels the dwell and costs nothing — the timer resets.

**R8 — Stacking**: The same upgrade may be selected on subsequent Forge dwells. Deltas are additive (e.g., two `PROJ_DAMAGE_UP` selections yield +2 × FORGE_PROJ_DAMAGE_DELTA to the base PROJ_DAMAGE).

**R9 — No purchase cap**: The Forge has no maximum use limit per run. The player may dwell and purchase as many times as accumulated gold allows.

**R10 — Immediate effect**: Upgrades take effect the frame the selection is confirmed. Projectiles already in-flight at the moment of selection use pre-upgrade values. All subsequent volleys use the upgraded values.

**R11 — Run scope**: All Forge-applied stat deltas are session-scoped. They reset to zero on GAME_OVER or run restart. The Forge does not contribute to persistent progression.

### States and Transitions

| State | Description |
|-------|-------------|
| `ZONE_INACTIVE` | FORGE_ZONEs hidden and disabled (MVP before Alpha integration) |
| `ZONE_AVAILABLE` | Zone visible; hero not inside radius, or hero inside but dwell not yet complete |
| `ZONE_DWELL_ACTIVE` | Hero inside ZONE_RADIUS; dwell timer running (owned by Economy) |
| `ZONE_TRIGGERED` | Dwell succeeded, gold deducted, upgrade delta applied immediately — zone returns to ZONE_AVAILABLE |

| From | To | Trigger |
|------|----|---------|
| `ZONE_INACTIVE` | `ZONE_AVAILABLE` | Alpha build detected on scene load |
| `ZONE_AVAILABLE` | `ZONE_DWELL_ACTIVE` | Hero enters ZONE_RADIUS |
| `ZONE_DWELL_ACTIVE` | `ZONE_AVAILABLE` | Hero exits ZONE_RADIUS before dwell completes (no cost) |
| `ZONE_DWELL_ACTIVE` | `ZONE_AVAILABLE` | Dwell completes AND gold < FORGE_COST (rejected silently, no cost) |
| `ZONE_DWELL_ACTIVE` | `ZONE_TRIGGERED` | Dwell completes AND gold ≥ FORGE_COST (gold deducted, upgrade applied immediately) |
| `ZONE_TRIGGERED` | `ZONE_AVAILABLE` | Upgrade applied — zone resets for next purchase (no cooldown) |
| `ZONE_AVAILABLE` | `ZONE_INACTIVE` | GAME_OVER received (all deltas reset on session_reset) |

### Interactions with Other Systems

| System | Direction | Data / Signal | Notes |
|--------|-----------|---------------|-------|
| Economy | Inbound | `forge_purchased` signal per zone | Economy owns zone detection and gold deduction. Each FORGE_ZONE emits its own `forge_purchased` variant (or passes an upgrade_type parameter). Forge applies the corresponding delta immediately. No menu. |
| Archer Formation | Outbound (conditional) | PROJ_DAMAGE runtime delta; SHOOT_IVTL runtime delta | Applied when player selects `PROJ_DAMAGE_UP` or `SHOOT_IVTL_DOWN`. Archer Formation reads modified values on next volley. |
| Economy | Outbound (conditional) | GOLD_MAGNET_RADIUS runtime delta | Applied when player selects `GOLD_MAGNET_RADIUS_UP`. Economy reads modified radius on next collection check. |
| Castle | Outbound (conditional) | CASTLE_MAX_HP runtime delta | Applied when player selects `CASTLE_MAX_HP_UP`. Castle adds delta to current HP cap (does not heal — max HP increases, current HP unchanged). |
| Game State Machine | Inbound | `game_over` signal | Forge resets all accumulated deltas to 0 on GAME_OVER. |

## Formulas

### F1 — upgraded_proj_damage

`upgraded_proj_damage(k) = PROJ_DAMAGE + k × FORGE_PROJ_DAMAGE_DELTA`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base damage | PROJ_DAMAGE | int | 8 HP (locked) | Per-projectile damage, owned by Archer Formation |
| Purchase count | k | int | 0–∞ | Number of PROJ_DAMAGE_UP purchases this run |
| Delta | FORGE_PROJ_DAMAGE_DELTA | int | 2 HP | HP added per purchase |
| Result | upgraded_proj_damage | int | 8–∞ HP | Effective per-projectile damage after k purchases |

**Output range:** k=0→8 HP, k=1→10 HP (+25%), k=2→12 HP (+50%), k=3→14 HP (+75%)
**Example:** 3 purchases: upgraded_proj_damage = 8 + 3×2 = 14 HP; full formation (n=8) volley = 112 HP

---

### F2 — upgraded_shoot_ivtl

`upgraded_shoot_ivtl(k) = max(SHOOT_IVTL_FLOOR, SHOOT_IVTL − k × FORGE_IVTL_DELTA)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base interval | SHOOT_IVTL | float | 0.9s (locked) | Base fire interval, owned by Archer Formation |
| Purchase count | k | int | 0–5 effective | Number of SHOOT_IVTL_DOWN purchases this run |
| Delta | FORGE_IVTL_DELTA | float | 0.10s | Fire interval reduction per purchase |
| Floor | SHOOT_IVTL_FLOOR | float | 0.40s | Minimum fire interval — required to prevent divide-by-zero in DPS formulas |
| Result | upgraded_shoot_ivtl | float | 0.40–0.9s | Effective fire interval after k purchases |

**Output range:** k=0→0.90s, k=1→0.80s, k=2→0.70s, k=3→0.60s, k=5→0.40s (floor, saturated)
**Example:** 3 purchases: upgraded_shoot_ivtl = max(0.40, 0.9 − 3×0.10) = 0.60s
**Cross-system note:** SHOOT_IVTL is shared by formation and Archer Tower. All SHOOT_IVTL_DOWN upgrades simultaneously increase formation_dps and tower_dps.

---

### F3 — upgraded_magnet

`upgraded_magnet(k) = min(GOLD_MAGNET_CEILING, GOLD_MAGNET_RADIUS + k × FORGE_MAGNET_DELTA)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base radius | GOLD_MAGNET_RADIUS | int | 170px (locked) | Base collection radius, owned by Economy |
| Purchase count | k | int | 0–7 effective | Number of GOLD_MAGNET_RADIUS_UP purchases |
| Delta | FORGE_MAGNET_DELTA | int | 40px | Radius increase per purchase |
| Ceiling | GOLD_MAGNET_CEILING | int | 450px | Maximum allowed radius — prevents full-world vacuum (world half-width = 540px) |
| Result | upgraded_magnet | int | 170–450px | Effective collection radius after k purchases |

**Output range:** k=0→170px, k=1→210px, k=2→250px, k=3→290px, k=7→450px (ceiling, saturated)
**Example:** 3 purchases: upgraded_magnet = min(450, 170 + 3×40) = 290px (covers 53.7% of world half-width)
**Ceiling rationale:** At radius ≥ 540px the hero vacuums all drops from any position, eliminating collection as a tactical decision and enabling a runaway gold-loop.

---

### F4 — upgraded_castle_max_hp

`upgraded_castle_max_hp(k) = CASTLE_MAX_HP + k × FORGE_HP_DELTA`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base HP | CASTLE_MAX_HP | int | 200 HP (locked) | Base castle HP pool, owned by Castle |
| Purchase count | k | int | 0–∞ | Number of CASTLE_MAX_HP_UP purchases |
| Delta | FORGE_HP_DELTA | int | 30 HP | HP added per purchase |
| Result | upgraded_castle_max_hp | int | 200–∞ HP | Effective castle max HP after k purchases |

**Output range:** k=0→200 HP (25 contact hits), k=1→230 HP (+3.75 hits), k=2→260 HP (+7.5 hits), k=3→290 HP (+11.25 hits)
**Example:** 3 purchases: upgraded_castle_max_hp = 200 + 3×30 = 290 HP → survives 36 enemy contacts vs base 25
**Note:** Upgrade increases the max HP cap only. Current HP at time of purchase is not affected (no healing).

---

### F5 — effective_formation_dps (combined upgrade scenario)

`effective_formation_dps(n, k_dmg, k_ivtl) = (n × upgraded_proj_damage(k_dmg)) / upgraded_shoot_ivtl(k_ivtl)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Occupied slots | n | int | 1–8 | Archers in mobile formation (can be reduced by tower purchases) |
| Damage purchases | k_dmg | int | 0–∞ | Count of PROJ_DAMAGE_UP buys |
| Speed purchases | k_ivtl | int | 0–5 effective | Count of SHOOT_IVTL_DOWN buys |
| Result | effective_formation_dps | float | 8.89–320 HP/s | Combined formation DPS under upgrade |

**Output range:**

| n | k_dmg | k_ivtl | effective_formation_dps |
|---|-------|--------|------------------------|
| 8 | 0 | 0 | 71.11 HP/s (base) |
| 8 | 3 | 0 | 124.44 HP/s (+75%) |
| 8 | 0 | 3 | 106.67 HP/s (+50%) |
| 8 | 3 | 3 | 186.67 HP/s (+163%) |
| 8 | 3 | 5 (floor) | 224.00 HP/s (+215%) |

**Example:** n=8, k_dmg=2, k_ivtl=2: (8 × 12) / 0.70 = 137.14 HP/s

---

### F6 — forge_purchasable (cost gate)

`forge_purchasable = (current_gold ≥ FORGE_COST)`

| Variable | Type | Description |
|----------|------|-------------|
| current_gold | int | Player's current gold balance |
| FORGE_COST | int | 200g (locked in registry) |
| Result | bool | True = dwell triggers upgrade delta immediately; False = dwell rejected silently |

## Edge Cases

- **If hero exits FORGE_ZONE before the 0.8s dwell completes**: Dwell timer resets. No gold is spent. Zone returns to ZONE_AVAILABLE. Identical behaviour to RECRUIT_ZONE and TOWER_ZONE dwell cancellation.

- **If the player's gold falls below FORGE_COST mid-dwell** (e.g., a RECRUIT_ZONE dwell fires simultaneously): The cost check is evaluated at the moment the dwell timer fires (not during). If gold < 200g at that moment, the trigger is rejected silently. No stat delta. No gold spent.

- **If SHOOT_IVTL_DOWN is purchased and k × FORGE_IVTL_DELTA ≥ (SHOOT_IVTL − SHOOT_IVTL_FLOOR)**: The floor clamps the result at SHOOT_IVTL_FLOOR (0.40s). No negative interval or divide-by-zero can occur. Subsequent purchases beyond the floor are accepted (200g spent, zone triggers) but produce no additional effect. Consider saturation visual feedback on FORGE_ZONE_SPD (see OQ-2).

- **If GOLD_MAGNET_RADIUS_UP is purchased and k × FORGE_MAGNET_DELTA would exceed GOLD_MAGNET_CEILING**: The ceiling clamps the result at 450px. Gold is spent but no additional radius is applied. Consider saturation feedback consistent with SHOOT_IVTL floor behaviour.

- **If CASTLE_MAX_HP_UP is purchased while castle current HP equals max HP**: Max HP ceiling is raised by FORGE_HP_DELTA. Current HP is unchanged — the castle does not heal. The castle is now below its new maximum.

- **If CASTLE_MAX_HP_UP is purchased and GAME_OVER fires in the same frame**: GAME_OVER takes priority. All deltas are discarded and the upgrade is not applied.

- **If GAME_OVER occurs while the hero is mid-dwell at a FORGE_ZONE**: GAME_OVER takes priority. The dwell timer cancels. No gold is deducted (dwell was not complete). All Forge-applied deltas for that run are reset to 0.

- **If PROJ_DAMAGE_UP is purchased mid-wave (projectiles in flight)**: In-flight projectiles retain their at-spawn damage value. The upgraded PROJ_DAMAGE applies only to projectiles spawned after the dwell completes.

- **If the hero purchases the Forge during the inter-wave pause (INTER_WAVE_PAUSE = 10s)**: Valid. The upgrade applies immediately. No combat pressure — this is an intended use pattern.

- **If no FORGE_ZONE exists in the scene** (MVP or Vertical Slice build): The Forge system is dormant — no signal listeners registered, no upgrade delta logic active. The game proceeds without any forge-related behaviour. This is the expected inactive state for pre-Alpha builds.

## Dependencies

| System | Direction | Type | Interface |
|--------|-----------|------|-----------|
| Economy | Upstream (hard) | Hard | Economy owns FORGE_ZONE detection, FORGE_COST deduction, and `forge_purchased` signal emission. Forge cannot function without Economy. |
| Game State Machine | Upstream (hard) | Hard | Forge listens for `game_over` to reset all runtime stat deltas. Without GSM, deltas persist across runs. |
| Archer Formation | Downstream (soft) | Soft | Forge modifies PROJ_DAMAGE and SHOOT_IVTL runtime values. Archer Formation reads these on every volley; Forge writes the overrides on upgrade selection. |
| Castle | Downstream (soft) | Soft | Forge modifies CASTLE_MAX_HP runtime value. Castle reads max HP for damage clamping; Forge writes the override on upgrade selection. |

**Bidirectional note — RESOLVED (2026-05-19)**: Archer Formation GDD has been updated to list Forge as a downstream system that modifies PROJ_DAMAGE and SHOOT_IVTL at runtime. Castle GDD has been updated to list Forge as a downstream system that modifies CASTLE_MAX_HP at runtime. The bidirectional dependency is now documented on both sides.

## Tuning Knobs

| Constant | Value | Safe Range | Effect if Too High | Effect if Too Low |
|----------|-------|------------|-------------------|-------------------|
| `FORGE_COST` | 200g | 100–300g | Forge never reached (player can't save enough) | Forge purchased too early, trivialises early waves; competes with archer recruitment |
| `FORGE_PROJ_DAMAGE_DELTA` | 2 HP | 1–4 HP | DPS scales exponentially — trivialises late waves at moderate k | Upgrade feels irrelevant; players skip PROJ_DAMAGE_UP |
| `FORGE_IVTL_DELTA` | 0.10s | 0.05–0.15s | Saturates at floor too quickly (k=2) — most purchases wasted | Too small a feel difference per purchase — players don't perceive the upgrade |
| `SHOOT_IVTL_FLOOR` | 0.40s | 0.30–0.60s | Floor too high — limits upgrade value; many purchases give no benefit | Floor too low — approaches zero, extreme DPS, may break enemy HP scaling balance |
| `FORGE_MAGNET_DELTA` | 40px | 20–60px | Ceiling reached in 1–3 purchases — remaining upgrades wasted | Change imperceptible on mobile touch; players skip GOLD_MAGNET_RADIUS_UP |
| `GOLD_MAGNET_CEILING` | 450px | 350–520px | Full-world vacuum reachable — removes gold collection risk (runaway loop) | Ceiling hit too early — reduces effective upgrade count to 2–3 max |
| `FORGE_HP_DELTA` | 30 HP | 20–60 HP | Reduces run-ending tension; late game becomes trivial | Too small to compete with DPS upgrades; CASTLE_MAX_HP_UP consistently skipped |

**Cross-knob interaction notes:**
- `FORGE_PROJ_DAMAGE_DELTA` and `FORGE_IVTL_DELTA` interact multiplicatively in `effective_formation_dps`. Increasing both simultaneously compounds DPS far beyond either alone — tune together.
- `FORGE_COST` and `GOLD_DROP_PER_ENEMY` (15g, owned by Economy) are coupled. If GOLD_DROP_PER_ENEMY is ever raised, FORGE_COST may need to rise proportionally to maintain purchase pacing.
- `SHOOT_IVTL_FLOOR` must remain strictly > 0.0s. The floor is a correctness constraint, not just a balance knob.

## Visual/Audio Requirements

**FORGE_ZONE visuals (all four zones):**
- Zone ground indicator: same visual language as RECRUIT_ZONE and TOWER_ZONE (circular pulsing ring, ≤90px radius). Each FORGE_ZONE uses a consistent amber/gold palette to reinforce the "gold becomes power" fantasy — distinguishable from RECRUIT_ZONE (green) and TOWER_ZONE (blue).
- Each zone carries a permanent label above it identifying the upgrade it grants (e.g., "DMG +2", "SPEED↑", "MAGNET +40", "CASTLE HP +30"). Label font size must meet mobile legibility minimums.
- Dwell progress: same fill-arc animation as the other economy zones (0 → full over 0.8s, animated around zone ring perimeter).
- Insufficient gold state: zone ring desaturates or dims when player gold < FORGE_COST (200g). Clears when gold ≥ 200g. All four zones share the same cost gate and desaturate simultaneously.

**Stat saturation feedback:**
- When a stat is at its floor or ceiling (SHOOT_IVTL at SHOOT_IVTL_FLOOR = 0.40s, GOLD_MAGNET_RADIUS at GOLD_MAGNET_CEILING = 450px): the corresponding FORGE_ZONE may display a "MAX" badge or greyed-out ring to indicate the upgrade is saturated. Deferred to polish pass — not required for Alpha launch.

**Audio events:**
- `forge_zone_dwell_complete` — ignition-style sound cue when 200g is spent and the upgrade delta applies. Distinct from recruit/tower dwell sounds — heavier and more powerful in feel. Fires immediately on zone trigger (no menu open/close delay).
- No audio on dwell rejection (silent per R3, consistent with other zones).

> 📌 **Asset Spec** — Visual/Audio requirements defined. After the art bible is approved, run `/asset-spec system:forge` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

- The Forge has no persistent HUD element during normal play. All four FORGE_ZONEs are permanent world objects — always visible in Alpha builds, always displaying their upgrade label and cost.
- Each FORGE_ZONE label must display: upgrade name and delta (e.g., "DMG +2 HP", "SPEED −0.1s", "MAGNET +40px", "CASTLE +30 HP"). Optionally the current stacked value (e.g., "Now: 10 HP") — see OQ-3.
- The FORGE_ZONE dwell prompt (cost display "200g") is owned by the Economy system's zone prompt, consistent with RECRUIT_ZONE and TOWER_ZONE.
- Hero movement remains active at all times — no modal interruption. RECRUIT_ZONE and TOWER_ZONE dwell timers continue normally while the hero dwells on a FORGE_ZONE (independent timers; simultaneous multi-zone dwell is handled by Economy per its rules).
- Accessibility: zone label text must meet the game's minimum font size for mobile legibility. Zones must not rely on color alone to distinguish upgrade types — use both color and label text.

> 📌 **UX Flag — Forge**: This system has world-space UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the four FORGE_ZONE world placements before writing epics. Stories referencing FORGE_ZONE layout should cite `design/ux/forge-zones.md`, not this GDD directly.

## Acceptance Criteria

> Criteria marked `[REQUIRES DEBUG TOOLING]` cannot be verified from the player-facing UI alone. They require a runtime stat overlay, signal log, damage-per-hit log, and/or fixed random seed mode. 26 of 34 criteria require debug tooling; 8 are verifiable from the HUD and screen state alone.

### Section R — Core Rules

**AC-R1a** — **GIVEN** a game binary built at the MVP milestone, **WHEN** the gameplay scene loads, **THEN** no FORGE_ZONE node exists in the scene tree and no forge-related signal listener is registered. `[REQUIRES DEBUG TOOLING]`

**AC-R1b** — **GIVEN** a game binary built at the Vertical Slice milestone, **WHEN** the gameplay scene loads, **THEN** FORGE_ZONE is absent from the scene tree and the Forge system emits no signals. `[REQUIRES DEBUG TOOLING]`

**AC-R2a** — **GIVEN** Alpha build, gold = 200g, hero at rest outside ZONE_RADIUS of FORGE_ZONE_DMG, **WHEN** the hero moves inside ZONE_RADIUS and holds for exactly 0.8 seconds, **THEN** the dwell trigger fires: 200g deducted, PROJ_DAMAGE_UP delta applied (PROJ_DAMAGE increases by FORGE_PROJ_DAMAGE_DELTA), and zone returns to ZONE_AVAILABLE — all within the same frame the timer expires. `[REQUIRES DEBUG TOOLING]`

**AC-R2b** — **GIVEN** Alpha build, gold = 200g, hero inside ZONE_RADIUS for 0.79 seconds, **WHEN** the hero has not yet reached 0.8s of continuous dwell, **THEN** no gold has been deducted and no stat delta has been applied.

**AC-R3a** — **GIVEN** Alpha build, gold = 199g, hero dwells for 0.8 s at any FORGE_ZONE, **WHEN** the dwell timer fires, **THEN** gold remains at 199g, no stat delta is applied, no error message or audio cue plays, and the zone returns to ZONE_AVAILABLE. `[REQUIRES DEBUG TOOLING]`

**AC-R3b** — **GIVEN** Alpha build, gold = 0g, hero dwells for 0.8 s at any FORGE_ZONE, **WHEN** the dwell timer fires, **THEN** gold stays at 0g, no stat delta is applied.

**AC-R4** — **GIVEN** Alpha build, gold = 350g, hero completes 0.8 s dwell at any FORGE_ZONE, **WHEN** the dwell timer fires, **THEN** gold is reduced to 150g and the corresponding stat delta is applied within the same frame. At no point does gold still read 350g after the dwell completes. `[REQUIRES DEBUG TOOLING]`

**AC-R5a** — **GIVEN** Alpha build, **WHEN** the gameplay scene loads, **THEN** exactly 4 FORGE_ZONE nodes are present in the scene tree: FORGE_ZONE_DMG, FORGE_ZONE_SPD, FORGE_ZONE_MAG, FORGE_ZONE_HP — each at its assigned world position. `[REQUIRES DEBUG TOOLING]`

**AC-R5b** — **GIVEN** Alpha build, gold ≥ 200g, hero completes 0.8 s dwell on FORGE_ZONE_DMG, **WHEN** the dwell timer fires, **THEN** PROJ_DAMAGE_UP delta is applied (runtime PROJ_DAMAGE increases by FORGE_PROJ_DAMAGE_DELTA). No other upgrade type is applied. `[REQUIRES DEBUG TOOLING]`

**AC-R5c** — **GIVEN** Alpha build, hero completes 0.8 s dwell on each of the four FORGE_ZONEs in sequence (gold reset to 200g before each), **WHEN** each dwell fires, **THEN** each zone applies exactly its designated upgrade type: FORGE_ZONE_DMG → PROJ_DAMAGE_UP, FORGE_ZONE_SPD → SHOOT_IVTL_DOWN, FORGE_ZONE_MAG → GOLD_MAGNET_RADIUS_UP, FORGE_ZONE_HP → CASTLE_MAX_HP_UP. `[REQUIRES DEBUG TOOLING]`

**AC-R6** — **GIVEN** Alpha build, runtime PROJ_DAMAGE = 8 HP, gold = 200g, **WHEN** the hero completes 0.8 s dwell on FORGE_ZONE_DMG, **THEN** within the same frame: 200g deducted, runtime PROJ_DAMAGE = 10 HP, FORGE_ZONE_DMG returns to ZONE_AVAILABLE. `[REQUIRES DEBUG TOOLING]`

**AC-R7** — **GIVEN** Alpha build, hero has dwelled for 0.5 s inside FORGE_ZONE_DMG (dwell not yet complete), **WHEN** the hero exits ZONE_RADIUS before the 0.8 s timer completes, **THEN** dwell timer resets to 0, no gold is deducted, no stat delta is applied, and zone remains in ZONE_AVAILABLE.

**AC-R8a** — **GIVEN** PROJ_DAMAGE_UP purchased twice in the same run (k_dmg = 2), **WHEN** the second selection is confirmed, **THEN** runtime PROJ_DAMAGE = 8 + 2×2 = 12 HP. `[REQUIRES DEBUG TOOLING]`

**AC-R8b** — **GIVEN** PROJ_DAMAGE_UP purchased once (k_dmg = 1) and SHOOT_IVTL_DOWN purchased once (k_ivtl = 1) in the same run, **THEN** runtime PROJ_DAMAGE = 10 HP and runtime SHOOT_IVTL = 0.80s simultaneously. `[REQUIRES DEBUG TOOLING]`

**AC-R9** — **GIVEN** the player has completed 5 Forge purchases in a single run, gold = 200g, **WHEN** the hero dwells for 0.8 s at any FORGE_ZONE, **THEN** the cost gate passes, 200g is deducted, and the upgrade delta is applied. No UI message states a limit has been reached.

**AC-R10** — **GIVEN** Alpha build, hero completes 0.8 s dwell on FORGE_ZONE_HP mid-wave, **WHEN** the dwell timer fires and gold ≥ 200g, **THEN** the castle's max HP cap is raised by FORGE_HP_DELTA (30 HP) within the same rendered frame. `[REQUIRES DEBUG TOOLING]`

**AC-R11** — **GIVEN** a run in which k_dmg = 3, k_ivtl = 1, k_magnet = 1 have been accumulated, **WHEN** a GAME_OVER event fires, **THEN** runtime values reset: PROJ_DAMAGE = 8 HP, SHOOT_IVTL = 0.90s, GOLD_MAGNET_RADIUS = 170px, CASTLE_MAX_HP = 200 HP — exactly at baseline with no carry-over. `[REQUIRES DEBUG TOOLING]`

---

### Section F — Formulas

**AC-F1a** — **GIVEN** k_dmg = 0 (baseline), **WHEN** player selects PROJ_DAMAGE_UP (k_dmg becomes 1), **THEN** runtime PROJ_DAMAGE = 10 HP (8 + 1×2). `[REQUIRES DEBUG TOOLING]`

**AC-F1b** — **GIVEN** k_dmg = 2 (runtime PROJ_DAMAGE = 12), **WHEN** player selects PROJ_DAMAGE_UP (k_dmg becomes 3), **THEN** runtime PROJ_DAMAGE = 14 HP (8 + 3×2). `[REQUIRES DEBUG TOOLING]`

**AC-F2a** — **GIVEN** k_ivtl = 2 (runtime SHOOT_IVTL = 0.70s), **WHEN** player selects SHOOT_IVTL_DOWN (k_ivtl becomes 3), **THEN** runtime SHOOT_IVTL = max(0.40, 0.9 − 3×0.10) = 0.60s. `[REQUIRES DEBUG TOOLING]`

**AC-F2b** — **GIVEN** k_ivtl = 4 (runtime SHOOT_IVTL = 0.50s), **WHEN** player selects SHOOT_IVTL_DOWN (k_ivtl becomes 5), **THEN** runtime SHOOT_IVTL = max(0.40, 0.40) = 0.40s — at floor exactly, does not go below. `[REQUIRES DEBUG TOOLING]`

**AC-F3a** — **GIVEN** k_magnet = 2 (runtime radius = 250px), **WHEN** player selects GOLD_MAGNET_RADIUS_UP (k_magnet becomes 3), **THEN** runtime GOLD_MAGNET_RADIUS = min(450, 290) = 290px. `[REQUIRES DEBUG TOOLING]`

**AC-F3b** — **GIVEN** k_magnet = 6 (runtime radius = 410px), **WHEN** player selects GOLD_MAGNET_RADIUS_UP (k_magnet becomes 7), **THEN** runtime GOLD_MAGNET_RADIUS = min(450, 450) = 450px — at ceiling exactly, does not exceed. `[REQUIRES DEBUG TOOLING]`

**AC-F4a** — **GIVEN** k_hp = 0 (max HP = 200), **WHEN** player selects CASTLE_MAX_HP_UP, **THEN** castle max HP = 230 HP. `[REQUIRES DEBUG TOOLING]`

**AC-F4b** — **GIVEN** castle current HP = 120, max HP = 200, k_hp = 0, **WHEN** player selects CASTLE_MAX_HP_UP, **THEN** max HP = 230 AND current HP remains exactly 120. `[REQUIRES DEBUG TOOLING]`

**AC-F5a** — **GIVEN** n = 8, k_dmg = 2 (PROJ_DAMAGE = 12), k_ivtl = 2 (SHOOT_IVTL = 0.70s), **WHEN** 10 volleys fire, **THEN** total damage = 10 × 96 = 960 HP delivered in 10 × 0.70 = 7.0s (effective_formation_dps ≈ 137.14 HP/s). `[REQUIRES DEBUG TOOLING]`

**AC-F5b** — **GIVEN** n = 8, no upgrades, **WHEN** volleys fire normally, **THEN** effective_formation_dps = (8 × 8) / 0.90 ≈ 71.11 HP/s. `[REQUIRES DEBUG TOOLING]`

**AC-F6a** — **GIVEN** gold = 200g, hero dwells 0.8s at FORGE_ZONE_DMG, **WHEN** dwell timer fires, **THEN** forge_purchasable = true: 200g deducted, balance = 0g, PROJ_DAMAGE_UP delta applied immediately.

**AC-F6b** — **GIVEN** gold = 199g, hero dwells 0.8s at any FORGE_ZONE, **WHEN** dwell timer fires, **THEN** forge_purchasable = false: no gold deducted, no stat delta applied, zone returns to ZONE_AVAILABLE.

---

### Section E — Edge Cases

**AC-E1** — **GIVEN** hero inside ZONE_RADIUS for 0.5s, **WHEN** hero exits ZONE_RADIUS, **THEN** dwell timer resets to 0, no gold deducted, no stat delta applied, zone returns to ZONE_AVAILABLE. Re-entry starts a fresh 0.8s count.

**AC-E2** — **GIVEN** gold = 200g at zone entry, gold reduced to 190g mid-dwell by a concurrent deduction, **WHEN** the 0.8s dwell timer fires, **THEN** cost gate evaluates at fire time (190g < 200g): rejected silently. Gold stays at 190g, no stat delta applied. `[REQUIRES DEBUG TOOLING]`

**AC-E3** — **GIVEN** Alpha build, hero has dwelled for 0.6 s inside FORGE_ZONE_SPD, **WHEN** the hero exits ZONE_RADIUS before 0.8 s elapses, **THEN** dwell timer resets, no gold deducted, SHOOT_IVTL unchanged, zone returns to ZONE_AVAILABLE. Re-entry starts a fresh 0.8 s count.

**AC-E4** — **GIVEN** SHOOT_IVTL_DOWN purchased 5 times (runtime SHOOT_IVTL = 0.40s, at floor), gold = 400g, **WHEN** player completes a sixth SHOOT_IVTL_DOWN purchase (200g deducted), **THEN** runtime SHOOT_IVTL remains at 0.40s — no change, no error, gold = 200g. `[REQUIRES DEBUG TOOLING]`

**AC-E5** — **GIVEN** GOLD_MAGNET_RADIUS_UP purchased 7 times (runtime radius = 450px, at ceiling), gold = 400g, **WHEN** player completes an eighth GOLD_MAGNET_RADIUS_UP purchase (200g deducted), **THEN** runtime radius remains at 450px — no change, no error, gold = 200g. `[REQUIRES DEBUG TOOLING]`

**AC-E6** — **GIVEN** castle current HP = 80, max HP = 200, **WHEN** player selects CASTLE_MAX_HP_UP, **THEN** max HP = 230 AND current HP = 80 (unchanged). HP bar reads 80/230. `[REQUIRES DEBUG TOOLING]`

**AC-E7** — **GIVEN** k_dmg = 0 (PROJ_DAMAGE = 8), a volley is in flight (projectiles spawned), player then selects PROJ_DAMAGE_UP (k_dmg = 1, runtime PROJ_DAMAGE = 10), **WHEN** the in-flight projectiles hit an enemy, **THEN** each deals 8 HP (pre-upgrade spawn value). The next volley deals 10 HP per projectile. `[REQUIRES DEBUG TOOLING]`

**AC-E8** — **GIVEN** Alpha build, hero is mid-dwell at FORGE_ZONE_DMG (0.5 s elapsed, no gold deducted yet), 2 prior Forge purchases this run (e.g., PROJ_DAMAGE = 12 HP), **WHEN** GAME_OVER fires, **THEN** the dwell timer cancels, all deltas reset (PROJ_DAMAGE = 8 HP), no gold is deducted for the interrupted dwell, and the next run starts at baseline. `[REQUIRES DEBUG TOOLING]`

**AC-E9** — **GIVEN** a run ends with k_dmg = 3, k_ivtl = 5, k_magnet = 7, k_hp = 2, **WHEN** a new run starts, **THEN** PROJ_DAMAGE = 8 HP, SHOOT_IVTL = 0.90s, GOLD_MAGNET_RADIUS = 170px, CASTLE_MAX_HP = 200 HP — all at baseline, no carry-over. `[REQUIRES DEBUG TOOLING]`

**AC-E10** — **GIVEN** Alpha build, hero dwells sequentially on FORGE_ZONE_DMG then FORGE_ZONE_SPD in the same run (gold reset to 200g before each dwell), **WHEN** both dwells complete, **THEN** PROJ_DAMAGE has increased by FORGE_PROJ_DAMAGE_DELTA and SHOOT_IVTL has decreased by FORGE_IVTL_DELTA — each zone applied exactly its own upgrade type and no other. `[REQUIRES DEBUG TOOLING]`

**AC-E11** — **GIVEN** game is in inter-wave pause state (10s countdown, no enemies), gold = 200g, hero dwells 0.8s at FORGE_ZONE_SPD, **WHEN** dwell timer fires, **THEN** full purchase flow executes: 200g deducted, SHOOT_IVTL_DOWN delta applied immediately, zone returns to ZONE_AVAILABLE. Inter-wave state does not suppress Forge interaction.

**AC-E12** — **GIVEN** a game binary flagged as MVP, **WHEN** the full game loop runs (multiple waves, gold collection, GAME_OVER), **THEN** no `forge_purchased` signal is emitted, no FORGE_ZONE node exists in the scene tree, no Forge runtime delta is applied, and no null-reference error or runtime exception occurs. `[REQUIRES DEBUG TOOLING]`

## Open Questions

| # | Question | Owner | Priority |
|---|----------|-------|----------|
| OQ-1 | ~~Should the upgrade menu auto-dismiss after a time limit?~~ **RESOLVED — not applicable.** The spatial zone model has no modal menu; dwell cancel (walking away) is the only exit path. No timer needed. | — | Resolved 2026-05-19 (D-02) |
| OQ-2 | Should FORGE_ZONEs at floor/ceiling (FORGE_ZONE_SPD when SHOOT_IVTL = 0.40s, FORGE_ZONE_MAG when GOLD_MAGNET_RADIUS = 450px) visually indicate saturation (greyed ring, "MAX" badge), or silently accept purchase with no special feedback? | Design/Art | Resolve during Alpha polish |
| OQ-3 | Should each FORGE_ZONE label display how many times that upgrade has been purchased this run (e.g., "DMG +2 HP ×2 → Now: 12 HP")? Useful for informed spatial decision-making; adds label refresh complexity. | Design/UX | Resolve during `/ux-design forge-zones` |
| OQ-4 | SHOOT_IVTL_DOWN amplifies both formation DPS and Archer Tower DPS simultaneously (shared constant). Should TOWER_SHOOT_IVTL be decoupled into a separate constant to enable independent tuning? Flag for architecture pass before Forge implementation. | Architecture | Resolve before Forge implementation |
| OQ-5 | FORGE_ZONE world placement: where in the 1080×1920 world should the zone be positioned? Apply constraints similar to TOWER_ZONE (y: 400–1400px, minimum distance from other zones)? | Level/World Design | Resolve before world scene authoring |
