# Garrison — Endgame & Community System Design
**Status**: Designed
**Author**: Game Designer
**Date**: 2026-05-25
**Dependencies**: hero-progression.md, economy.md, forge.md, exploration-map design, crafting_system.gd, resource_inventory.gd, game_state_machine.gd

---

## Overview

This document specifies the complete endgame and community layer for Garrison, activated once the player reaches level 30+ and has cleared all 15 base zones. The system extends session longevity from weeks to months through five interlocking loops: Zone Prestige, World Boss rotation, Legendary Crafting, Challenge Rifts, and Guild Expeditions. The core philosophy is "massively single-player" — every community feature is consumed solo, asynchronously, but feeds a sense of shared history with other players.

All systems are built on top of existing infrastructure: `HeroProgression` (levels 1-50, zone mastery, ConfigFile persistence), `ResourceInventory` (65 resource types including 5 Epic tiers), `CraftingSystem` (27 base recipes extensible to legendary), `GameStateMachine` (PLAYING/EXPLORING FSM), and `EnemyWave` (budget-based infinite waves with boss/elite/rush tags).

---

## 1. Endgame Loop — What a Level-50 Player Does

### 1.1 Daily Session Flow (Level 50 target)

A level-50 player opens Garrison and faces this decision tree, each branch taking 8–20 minutes on mobile:

```
Start Session
    |
    +-- Check Guild Vault (async contributions overnight?) ─────────────────+
    |                                                                        |
    +-- Check World Boss phase (pre-fight expedition or boss week?) ─────── |
    |                                                                        |
    +-- Select activity:                                                     |
        |                                                                    |
        +-- Zone Prestige run (selected zone, +1 mastery, legendary hunt)   |
        |                                                                    |
        +-- Challenge Rift (push leaderboard rank, timed dungeon)           |
        |                                                                    |
        +-- Legendary Crafting expedition (farm specific rare material)      |
        |                                                                    |
        +-- Guild Contract (contribute to shared objective)                 |
```

**Engagement hooks by day:**
- Day 1 of week: World Boss phase resets — announce new target
- Day 3: Guild Contract refresh (3 new objectives posted)
- Day 7: Challenge Rift leaderboard snapshot + seasonal points awarded
- Daily: Prestige bonus resource (one zone highlighted with +50% drop rate)

### 1.2 Five Endgame Activities

#### (a) Zone Prestige

**Design reference**: Diablo 3 Greater Rifts difficulty tiers, Path of Exile Atlas progression.

**Concept**: After a zone is cleared once at any mastery level, the player can "Prestige" it — wiping all resource nodes and enemy camps, replacing them with harder variants, and enabling legendary material drops. Each prestige adds one mastery tier (0-5). Zone Prestige is the primary source of legendary resources (types 51-59 in `ResourceInventory`).

**Unlock condition**: `HeroProgression.zone_clears[zone_idx] >= 1` AND `hero_level >= 30`.

**Mechanics per prestige tier:**

| Tier | HP mult | Speed mult | Resource rarity shift | Legendary chance | Special |
|------|---------|------------|----------------------|------------------|---------|
| P1   | ×1.5    | ×1.1       | +10% rare nodes      | 5%               | — |
| P2   | ×2.0    | ×1.2       | +20% rare nodes      | 12%              | Elite camps appear |
| P3   | ×2.8    | ×1.35      | +15% legendary nodes | 22%              | Zone Boss spawns |
| P4   | ×3.8    | ×1.50      | +25% legendary nodes | 35%              | Boss + Elite wave |
| P5   | ×5.0    | ×1.65      | All nodes are rare+  | 55%              | Zone Boss guaranteed |

**Integration with existing code**: `HeroProgression.get_zone_mastery(zone_idx)` already returns 0-5 from `zone_clears`. The `ExplorationMap._build_zone()` method reads zone definitions at construction time. A `prestige_tier` parameter passed to `build_map()` scales the `_spawn_zone_camps()` `ZONE_CAMP_TIER` and modifies the `_spawn_zone_instant_resources()` and `_spawn_zone_timed_resources()` pools to inject legendary-tier types.

**Legendary drop formula**: `P(legendary) = 0.05 * prestige_tier^1.4 + HeroProgression.get_rare_chance_bonus()`. Capped at 0.70. Rolls once per resource node collected.

**Zone Prestige reward on zone clear**:
- Zone Prestige Points (ZPP): `50 + zone_idx * 15` per prestige tier completed
- 1× guaranteed legendary resource from zone's biome pool
- Cosmetic: zone color palette permanently shifts (gold tint for P3, silver shimmer for P5)

#### (b) World Boss Rotation

Detailed in Section 2.

#### (c) Legendary Crafting

**Design reference**: Monster Hunter World Arch-Tempered hunts, FFXIV Savage raid BiS crafting.

**Concept**: One-of-a-kind gear pieces that require 10+ rare/legendary resources AND completion of a specific quest chain. Only one legendary item can be equipped per slot. Legendary items provide dramatic effects that standard crafted items cannot, but require weeks of preparation.

**Recipe structure** (extends `CraftingSystem.RECIPES`):

```
LegendaryRecipe {
  id: LegendaryItem enum value,
  name: String,
  slot: "weapon" | "armor" | "passive",
  description: String (dramatic, one unique effect),
  ingredients: [[ResourceInventory.Type, int], ...],  # 8-14 ingredients
  quest_gate: String,  # Quest ID that must be completed first
  forge_level_required: int,  # Minimum forge DMG/SPD/HP level
  unique: true,  # Only one can exist in inventory
}
```

**15 legendary items** (one per zone biome):

| ID | Name | Zone source | Key ingredient | Effect |
|----|------|-------------|----------------|--------|
| LEG_01 | Lame de la Foret Eternelle | Zone 0 (Foret Eveil) | GOLDEN_SAP ×5 + ADAMANTITE ×3 | Hero attacks poison all nearby enemies simultaneously (120px radius) |
| LEG_02 | Arc du Souvenir Doré | Zone 1 (Clairiere) | MYTHRIL ×3 + GEMSTONE ×8 | Archers fire 2 arrows per shot |
| LEG_03 | Armure des Ancetres | Zone 2 (Ruines) | ANCIENT_RUNE ×2 + IRON_ORE ×15 | Castle absorbs first 10 damage per wave completely |
| LEG_04 | Cristal des Profondeurs | Zone 3 (Catacombes) | CRYSTALLIZED_SHADOW ×3 + MOONSTONE ×2 | Hero spells cost 0 mana for 8s after any kill |
| LEG_05 | Cape du Marécage Ancien | Zone 4 (Marecage) | GHOST_MUSHROOM ×8 + SILK ×12 | All enemies within 200px of hero are permanently slowed -50% |
| LEG_06 | Baton du Cristal Vivant | Zone 5 (Foret Cristal) | STAR_DUST ×5 + CRYSTAL ×20 | Hero spells chain to 2 additional enemies |
| LEG_07 | Etendard des Cendres | Zone 6 (Cendres) | PRIMAL_FLAME ×2 + ASH ×30 | Archer formation gains FIRE power permanently (no 150g cost) |
| LEG_08 | Coeur de Volcan | Zone 7 (Vallee Feu) | DRAGON_HEART ×1 + LAVA_FLOWER ×10 | Castle regen rate ×5 and triggers burst heal +20 HP on wave clear |
| LEG_09 | Armure de Glace Primordiale | Zone 8 (Toundra) | ICE_CRYSTAL ×15 + WIND_ESSENCE ×5 | All tower arrows apply Water slow permanently |
| LEG_10 | Sceptre du Desert Enseveli | Zone 9 (Desert) | ETERNAL_ESSENCE ×3 + GOLEM_EYE ×5 | Targeting priority cycles automatically each wave (best mode per enemy type) |
| LEG_11 | Relique du Temple Sacré | Zone 10 (Temple) | GODS_TEAR ×2 + MOONSTONE ×3 | All Forge upgrades cost -50% gold |
| LEG_12 | Ame des Grottes | Zone 11 (Grottes) | SILVER_LICHEN ×10 + SHADOW_ESSENCE ×5 | Enemy healers converted to allies for 6s on hero hit |
| LEG_13 | Manteau des Pics | Zone 12 (Pics Etheres) | VOID_BREATH ×1 + STAR_DUST ×8 | Hero can fly (pass through enemies) during EXPLORING, +100% speed |
| LEG_14 | Couronne de la Necropole | Zone 13 (Necropole) | TITAN_BLOOD ×1 + CRYSTALLIZED_SHADOW ×5 | Dead enemies have 25% chance to rise as friendly archers for 10s |
| LEG_15 | Eclat de la Cime | Zone 14 (Cime Sacree) | WORLD_CORE ×1 + MYTHRIL ×5 + ADAMANTITE ×5 | +1 castle HP per enemy killed during TD waves |

**Legendary Crafting flow**:
1. Player explores zone, finds "Anvil Legendaire" (only at ANVIL_ZONES at P3+)
2. Legendary anvil shows recipe — most ingredients red (missing)
3. Player sees which World Boss drops the key material (e.g., DRAGON_HEART from Zone 7 boss)
4. Quest gate shown: "Defeat the Roi du Volcan" must appear in quest log as complete
5. Player spends 2-4 weeks farming, fighting boss, running prestige
6. Crafting moment: ~3 second animated sequence (Tween on anvil sprite, procedural PCM burst from AudioManager)

**Save**: Legendary items persist via ConfigFile in `user://legendary_inventory.cfg`. They survive season resets.

#### (d) Challenge Rifts

**Design reference**: Diablo 3 Greater Rifts, Path of Exile Delve.

**Concept**: A procedurally generated dungeon that combines exploration (EXPLORING state) with a TD wave defense in a compressed arena. The rift has a 10-minute timer. Score = enemies killed × wave reached × speed bonus. Leaderboard ranks updated weekly via cloud API (see Section 7).

**Rift structure**:
- 5-room dungeon: 4 exploration rooms (resource sprint) + 1 boss room (TD wave arena)
- Room 1-4: 60 seconds each. Hero collects resources while rpg_enemy_camp hostiles spawn every 15s
- Room 5 (boss room): Switches to PLAYING state in a 960×540 arena, 8 waves, enemies spawn from all 4 sides
- Timer runs continuously across all rooms. Pausing costs 30s penalty.
- Arena uses existing EnemyWave budget system but compressed: BASE_BUDGET=200, no wave break timer

**Rift modifiers** (one random per rift, drawn from 20 pool):
- Berserk: all enemies +50% speed, +30% gold drops
- Cursed Vaults: all resource nodes yield 3× but enemies are Elite-tier
- Storm: hero speed -25% but archer range +40%
- Siege: castle takes 2× damage but wave gold multiplier ×2
- Phantom: enemies invisible until they enter 150px of castle

**Rift scoring formula**:
```
score = (total_kills × 10) + (waves_survived × 500) + (time_remaining_seconds × 50)
score += rift_modifier_bonus (0-2000)
score = floor(score × hero_level_bonus)   # hero_level_bonus = 1.0 + (hero_level - 30) * 0.02
```

**Leaderboard**: Top 100 global, top 10 regional (see Section 7). Player's personal best stored locally in ConfigFile.

**Rewards per rift**:
- Gold: `400 + (waves_survived × 50)` gold added on return via `Economy.add_gold()`
- Resources: 3 random drops from Zone 11-14 pools (deep zone materials)
- First rift of the day: +500 XP to `HeroProgression.add_xp()`
- Seasonal points: 50 per rift completed (see Section 3)

#### (e) Guild Expedition

Detailed in Section 4.

---

## 2. World Boss System

### 2.1 Architecture

**15 World Bosses**, one per zone. A boss spawns after the player completes all enemy camps in a zone at Prestige 1+. The boss is not part of the regular `EnemyWave` pool — it is a standalone scene instantiated in the EXPLORING state at a fixed position (zone center of the LANE_CENTER, at `zone_x + ZONE_W * 0.5`).

The boss fight integrates both game modes:
- **Phase 1 (RPG)**: Hero fights boss in EXPLORING state. Boss has special attacks, hero uses spells via `HeroSpells`. Boss is implemented as a large `Area2D` node using the same pattern as `rpg_enemy_camp.gd` but with multi-phase AI.
- **Phase 2 (TD)**: Boss retreats to castle and triggers a PLAYING state wave where it acts as the wave boss (`is_boss=true`) but with unique abilities layered on top via a `world_boss_overlay.gd` component.
- **Phase 3 (Combined)**: Boss is simultaneously present in exploration zone AND reinforcing TD enemies from a rift portal (visual only — spawns 3 extra enemies per wave-boss attack cycle).

**Spawn cadence**: A boss "respawns" every 7 days (weekly rotation). A different boss is featured each week. The 15-week cycle repeats with escalating difficulty multipliers per repeat (+15% HP, +10% all damage, new attack pattern variant).

**Boss reward**:
- Unique legendary material (one per boss, required for the zone's legendary recipe)
- World Boss Trophy (cosmetic, displayed in Guild Hall)
- 200 Seasonal Points
- 3× Zone Prestige Points bonus for that zone this week

**Boss health persistence**: Boss HP is stored in ConfigFile (`user://boss_state.cfg`). Boss does not reset between sessions — the player may need multiple expeditions over several days to defeat it. Reinforcement mechanic: each day a boss survives, it gains +5% HP back.

### 2.2 Three Concrete Boss Examples

#### Boss 1 — Sylvalis, Gardien de la Foret (Zone 0: Foret de l'Eveil)

**World position**: `Vector2(1600, 1080)` in exploration world.
**Base HP**: 2000 at first encounter. Scales +15% per weekly repeat cycle.
**Drop**: GOLDEN_SAP ×3 (required for LEG_01).

**Phase 1 — Forest Guardian (EXPLORING)**:
- Sylvalis is a 240×240 sprite (3× tree sprite scaled, green tinted)
- Attack 1 — Root Burst: every 8s, spawns 6 `ResourceNode`-sized Area2D "root spikes" at player position with 1.5s delay telegraphed by ground crack (ColorRect red line). Each spike deals 15 damage on overlap.
- Attack 2 — Vine Pull: every 15s, hero movement speed reduced to 30% for 4s (modulate `Hero._speed` via signal)
- Attack 3 — Spore Cloud: at 50% HP, spawns a `RpgEnemycamp` tier-1 at boss position (reinforcements)
- Hero response: hero spells deal normal damage. The `BONE_BOW` legendary item (LEG_01 prerequisite) deals +50% damage to Sylvalis specifically (boss has `BOSS_WEAKNESS = "GOLDEN_SAP"` tag checked against equipped item)

**Phase 2 — Entangled Siege (PLAYING)**:
- GSM transitions to PLAYING. Sylvalis appears as a boss-tagged enemy in the TD wave.
- Special mechanic: every 5 kills by Sylvalis-wave enemies, Sylvalis vomits a "Growth Pod" (a slow-moving Area2D) that on reaching castle position adds a -15% archer fire rate debuff stack for 10s
- Castle archers and towers fight normally. Hero can return to TD zone to assist.
- Killing Sylvalis in Phase 2 (reducing HP to 0 via TD damage) ends the fight.

**Phase 3 — Root Network** (triggers at Prestige 3+ encounter):
- While Phase 2 is active, exploration map shows 3 "Root Nodes" (glowing green ColorRects). Hero must destroy them (3 hits each via hero melee attack, Area2D overlap) to remove the Growth Pod mechanic.
- Adds time pressure: hero has ~90s to clear root nodes before the Growth Pod debuffs stack to -75% fire rate (which ends the run).

---

#### Boss 2 — Le Roi du Volcan, Ignifex (Zone 7: Vallee de Feu)

**World position**: `Vector2(23200, 1080)` (zone 7 center).
**Base HP**: 4500. High HP because player needs ~3 expeditions to defeat at first encounter.
**Drop**: DRAGON_HEART ×1 (required for LEG_08 — rarest item, only 1 per kill, boss must be fully defeated).

**Phase 1 — Magma Sovereign (EXPLORING)**:
- Ignifex is a 320×320 sprite (red/orange dragon silhouette, uses Kenney asset with heavy red modulate)
- Attack 1 — Meteor Rain: every 12s, 8 LAVA_FLOWER-sized impact nodes fall in a cross pattern around hero. Each explodes after 2s (Area2D, 25 damage, visual: red ColorRect expanding from 4px to 60px over 0.5s via Tween).
- Attack 2 — Lava Wall: every 20s, creates a horizontal barrier of 5 connected Area2D nodes across the lane (blocks hero path for 5s). Hero must go around via LANE_UPPER or LANE_LOWER.
- Attack 3 — Engulf (below 30% HP): Ignifex gains permanent +200% speed and charges hero directly. If overlap occurs: 40 damage per second contact (catastrophic — forces hero retreat or death).
- Special: LAVA_FLOWER resources in Zone 7 during this boss fight yield 3× because the boss's "heat aura" activates them.

**Phase 2 — Siege of the Fortress (PLAYING)**:
- Ignifex acts as the wave boss. All wave enemies have FIRE power applied automatically (×1.80 arrow damage negated because they ARE fire-type — enemy immunity: fire arrows deal only 0.3× damage to fire enemies).
- Special mechanic: "Lava Breach" — every 30 seconds Ignifex attacks the castle directly for 25 HP regardless of defensive structures. This forces the player to end the wave quickly.
- Counter: equipping LEG_07 (Etendard des Cendres) removes the fire immunity and restores normal fire arrow damage.
- Tower WATER power is effective: WATER arrows slow Ignifex's movement and increase time between Lava Breach attacks by +50%.

**Phase 3 — Core Meltdown** (P3+):
- During Phase 2, a "Cooling Reactor" objective appears in EXPLORING zone: a special resource node (ICE_CRYSTAL) that, if collected during the fight (requiring hero to switch to EXPLORING mid-TD), reduces Ignifex's Phase 2 HP by 500 immediately.
- Rewards the dual-mode mastery that is Garrison's identity.

---

#### Boss 3 — L'Archiviste Mort, Mortalis (Zone 13: Necropole)

**World position**: `Vector2(44800, 1080)` (zone 13 center).
**Base HP**: 7000. Intended for players at Prestige 4+ in zone 13. Multi-session fight design: ~1500 damage per reasonable expedition. Full defeat takes 4-5 sessions.
**Drop**: TITAN_BLOOD ×1 (required for LEG_14 — the most powerful legendary in the game).

**Phase 1 — The Archive (EXPLORING)**:
- Mortalis appears as a giant armored skeleton (180×240, dark purple tinted).
- Attack 1 — Soul Drain: every 10s, all resources the hero has collected this session are reduced by 10% (rounded down, min 0). Punishes hoarding — player must use/store resources or lose them.
- Attack 2 — Bone Cage: hero is imprisoned in a 6-node hexagonal Area2D cage. Must tap each node once to break (6 taps within 4s or takes 50 damage). Tests dexterity on mobile.
- Attack 3 — Undead Army: at 60% HP and 30% HP, spawns 3 `rpg_enemy_camp.gd` tier-2 camps simultaneously in the zone. Hero must fight through them to reach Mortalis again.
- Special: the zone's `SHADOW_ESSENCE` resource drops are doubled during the Mortalis encounter — incentive to fight even when progress is slow.

**Phase 2 — The Siege of the Dead (PLAYING)**:
- Mortalis replaces the normal wave boss with a unique ability: on death of any wave enemy, 30% chance the enemy "reanimates" (respawns from pool immediately at 30% max HP, BONE drop disabled). This dramatically extends wave length.
- Counter: LEG_14's effect (enemies have 25% chance to rise as friendly archers) creates a spectacular mirror of Mortalis's own mechanic — a direct gameplay commentary.
- Special mechanic: "Archive Seal" — a floating seal orbits the castle. If it completes 3 full orbits (180 seconds), Mortalis heals 500 HP. Hero must move to the seal during EXPLORING phase and dispel it (Area2D overlap, 3-second channel, hero cannot move during channel — the most complex interaction in the game).

**Phase 3 — The Corruption** (P4+):
- Mortalis begins corrupting ZONE_BLESSING resources. Each minute of Phase 3 active, one zone's blessing resource type is permanently replaced this session with BONE (the worst trade). Forces player to prioritize ending the fight.
- On defeat: a unique cutscene-style sequence of 5 lore tablets appears at the boss location, narrating the Archive's history. These are the only lore tablets in the game that connect all 15 zone lore fragments into a coherent narrative.

---

## 3. Seasonal League System

### 3.1 Season Structure

**Duration**: 90 days (3 months).
**Theme**: Each season has one world-altering theme that changes zone appearance, resource availability, and enemy behaviors.

**Season 1 — Le Reveil des Titans** (Launch season):
- Titan Blood resource appears in all zones at reduced rates (normally Zone 13 only)
- Enemy CAVALIER type has 30% spawn weight increase across all waves
- New zone variant: "Terres Brulees" overlays zones 0-7 with ash particle effects (ColorRect alpha animation)
- Seasonal currency: Eclat de Titan (earned from kills, bosses, prestige, rift)

**Season 2 — L'Age de Glace** (Month 4):
- ICE_CRYSTAL appears in zones 0-8 (normally only Zone 8)
- All enemies have -15% speed but +30% HP
- Hero gains ice-slip on castlezone floor — movement less precise (directional input reduced 20%)
- Zone 8 (Toundra) becomes the season's hub zone with doubled resource density

**Season 3 — L'Eveil du Neant** (Month 7):
- VOID_BREATH resource seeps into all zones
- New enemy type: Wraith (intangible — ignores WATER slow, resists FIRE, dies to LIGHTNING)
- Night/day cycle added to exploration map (cosmetic: color shift on ColorRect backgrounds every 4 minutes)

### 3.2 Seasonal Quest Line (8 Chapters)

Each season has an 8-chapter quest line. Chapters unlock on a 10-day cadence (chapter 1 available day 1, chapter 8 available day 71). This creates a sustained content rhythm.

**Quest tracking**: `user://season_N_quests.cfg` (ConfigFile), separate from hero progress.

**Season 1 example chapters**:

| Chapter | Title | Objective | Reward |
|---------|-------|-----------|--------|
| 1 | L'Appel des Titans | Clear Zone 0 at any prestige | 100 Eclat de Titan + IRON_ORE ×20 |
| 2 | La Forge des Anciens | Craft any item at Forge level 3+ | MYTHRIL ×1 + COAL ×30 |
| 3 | Les Sentinelles | Defeat 50 CAVALIER enemies | TITAN_BLOOD fragment (×0.5 — half a material, must collect twice) |
| 4 | La Premiere Vague | Complete a Challenge Rift | ADAMANTITE ×2 + 200 Eclat |
| 5 | L'Alliance | Contribute to Guild Vault 5× | Guild XP ×2 bonus for 24h |
| 6 | Le Roi de Sang | Defeat any World Boss | Unique seasonal hero skin unlock |
| 7 | Prestige des Titans | Complete Prestige 3 on any zone | LEG_SEASONAL_01 recipe unlock |
| 8 | L'Heritier | Complete all previous chapters | Season Trophy cosmetic + 1000 Eclat |

**Seasonal quest narrative**: Each chapter has a 2-3 sentence lore blurb displayed on a "seasonal tablet" in Zone 6 (Cendres — the thematic center of the game world at position 7 in zone ordering). Lore builds on the 15 existing lore tablet texts from `ExplorationMap.LORE_TEXTS`.

### 3.3 Seasonal Cosmetics

**Earned exclusively during a season, cannot be obtained after season ends**:

| Tier | Eclat cost | Item |
|------|-----------|------|
| 100  | Hero color palette: Titan Bronze |
| 300  | Castle banner: Titan Crest (animated ColorRect overlay on castle) |
| 600  | Archer tint: Ember Glow (warm orange modulate on all archer sprites) |
| 1000 | Zone palette: Scorched Earth (all zones gain slight orange tint via global ColorRect) |
| 2000 | Hero skin: Titan Rider (replaces cavalier sprite with titan-armored version) |
| 5000 | Season Trophy: Displayed in Guild Hall, persists across seasons (cosmetic only) |

**Seasonal legendary recipe** (Chapter 7 reward):
```
LEG_SEASONAL_01 — Lance des Titans
Slot: weapon
Effect: Hero melee attack chains to 3 enemies simultaneously (was 1)
Ingredients: TITAN_BLOOD ×3 + ADAMANTITE ×5 + DRAGON_HEART ×1 + PRIMAL_FLAME ×5
Quest gate: Season Chapter 7 complete
```

### 3.4 Season Reset Rules

At end of season (day 90):

**Kept permanently**:
- All `HeroProgression` data (level, XP, zone clears, discoveries)
- All legendary items crafted during the season (`user://legendary_inventory.cfg`)
- All base crafted items in `ItemInventory`
- Seasonal cosmetics earned (skin, trophy, palettes)
- Season Trophy displayed permanently in Guild Hall

**Reset at season end**:
- Seasonal currency (Eclat de Titan) — cannot be carried over, excess converted: 10 Eclat = 1g starting next season
- Season quest progress — quest log clears, chapter 1 of new season unlocks
- Zone prestige levels — reset to 0 (deliberate: prestige grind is the season's core loop)
- Guild Boss HP — fresh fight each season
- World Boss HP (all 15) — reset to base HP (no more multi-session accumulation from last season)

**NOT reset**:
- Zone `zone_clears` count in `HeroProgression` — unlock conditions for prestige persist
- Resource inventory counts in `ResourceInventory` — resources are permanent, not seasonal
- Legendary item recipes unlocked — player can re-craft without redoing the quest gate

**Season end ceremony** (in-game): A `event_banner_requested` signal fires from `ExplorationMap` with a 10-second banner: "Saison [N] terminée — [PlayerName] a atteint [score] points. Récompense saisonnière débloquée." followed by an unlocked cosmetic popup.

### 3.5 Seasonal Scoring

**Points earned** (accumulated throughout season, displayed in Guild Hall):

| Activity | Points |
|----------|--------|
| Zone cleared (any prestige) | 10 |
| Zone cleared at P3+ | 50 |
| World Boss defeated | 200 |
| Challenge Rift completed | 50 |
| Legendary item crafted | 500 |
| Guild Contract completed | 30 |
| Season Quest chapter completed | 100 |
| Daily bonus (first 8-min session per day) | 20 |

**End-of-season rank tiers**:

| Tier | Points required | Reward |
|------|----------------|--------|
| Bronze | 500 | 200 Eclat next season + Bronze frame |
| Silver | 2000 | 500 Eclat + Silver frame + bonus resource pack |
| Gold | 5000 | 1000 Eclat + Gold frame + exclusive hero emote |
| Titan | 10000 | 2000 Eclat + Titan frame + access to Titan Vault (exclusive legendary recipe) |
| Legend | 25000 | All above + permanent "Legend" title in Guild Hall |

---

## 4. Async Guild System

### 4.1 Guild Architecture

**Maximum size**: 20 players per guild.
**Guild Hall location**: Zone 6 (Terres des Cendres) at world position `Vector2(20800, 1080)`. Represented as a large Sprite2D structure in the exploration map, accessible via proximity interact button showing "Guilde".

**Async model**: No real-time server required. Guilds are implemented using one of two approaches based on deployment:

**Approach A — Cloud Save Comparison (Recommended)**:
- Each player's contribution is stored locally in `user://guild_state.cfg`
- On session start, game fetches a lightweight JSON from a static CDN URL (e.g., GitHub Pages hosted file updated by a server-side cron or Godot Headless CI): `https://garrison-guild.example.com/guild_{guild_id}.json`
- The JSON contains: `{guild_level, vault_resources, member_contributions, boss_hp, active_contracts, leaderboard_snapshot}`
- Player reads the state, plays their contribution, then on session end uploads their delta to a simple REST endpoint (or contributes via the Godot HTTP client to a serverless function like Cloudflare Worker)
- Other members see the accumulated state next time they open the app
- **No real-time server**: a 5-10 minute sync delay is acceptable and expected for async play

**Approach B — Local-only with QR Code sharing** (Fallback for no-server launch):
- Guild state exported as a QR code (base64 JSON compressed) from Guild Hall
- Guild leader scans all members' QR codes and generates a merged state QR
- Each member imports the merged state — no internet required
- Cruder but viable for early access without backend infrastructure

**Approach A is the target for v1.1+**. The `ConfigFile`-based local save from `HeroProgression` provides the pattern; the guild layer adds a sync layer on top.

### 4.2 Guild Levels 1-10

| Level | XP required | Unlocked benefit |
|-------|-------------|------------------|
| 1 | 0 (start) | Guild Vault (donate resources) + Guild Chat log (async text) |
| 2 | 500 | Shared buff: All members +5% resource drop rate |
| 3 | 1500 | Guild Contracts board unlocked (3 rotating objectives) |
| 4 | 3000 | Bonus resource drops: +10% yield on timed resource nodes |
| 5 | 6000 | Guild Boss unlocked (shared HP pool fight) |
| 6 | 12000 | Guild-exclusive recipe: "Bouclier de Guilde" (Castle +100 HP, requires Guild materials) |
| 7 | 20000 | Shared buff: +10% XP gain for all members |
| 8 | 35000 | Guild Expedition feature unlocked (send hero on 8h timer mission, returns with resources) |
| 9 | 55000 | Guild-exclusive recipe: "Arme de Guilde" (Hero weapon with +20 ATK, Guild-only) |
| 10 | 80000 | Guild Hall expansion: all shared buffs +50%, Guild Trophy room unlocked, unique guild cosmetic |

**Guild XP sources**:
- Resource donation to vault: 1 XP per resource unit (common), 5 (rare), 20 (legendary), 50 (epic)
- Guild Contract completion: 100-300 XP per contract
- Guild Boss damage dealt: 1 XP per 10 HP of boss damage
- Daily member login with guild assigned: 10 XP per active member per day

### 4.3 Guild Vault

**Purpose**: Shared resource pool. Members donate, recipes consume from vault.
**Capacity**: 500 units per resource type, scales +200 per guild level.
**Guild-only recipes** consume from the vault, not the player's personal `ResourceInventory`.

**Vault UI**: In Guild Hall (EXPLORING state), a scrollable panel shows all 65 resource types with vault counts. Player taps resource, taps "Donner ×10" button — triggers `ResourceInventory.spend(type, 10)` locally and adds to vault via cloud sync delta.

**Anti-drain rule**: Players cannot withdraw from vault for personal use. Vault resources only consumed by Guild recipes and Guild Boss rewards. This prevents the "one player drains the vault" failure mode seen in guild MMO economies.

### 4.4 Guild Contracts

**Refresh cadence**: 3 new contracts every Monday (async — checked via device date, no server clock).
**Contract types** (pool of 15, 3 shown per week):
- Resource contribution: "Déposer 50 IRON_ORE dans le coffre" (count from all members combined)
- Kill milestone: "Tuer 500 ennemis CAVALIER cette semaine" (cumulative across guild)
- Zone prestige: "Compléter 3 runs de prestige collectivement"
- Boss milestone: "Infliger 5000 dégâts au World Boss cette semaine"
- Rift milestone: "Compléter 5 Challenge Rifts collectivement"

**Reward**: Guild XP + seasonal points for all contributing members + 1× bonus resource from vault.

### 4.5 Guild Boss

**Structure**: A unique 20-player shared boss with 50,000 base HP. HP persists in cloud save. Any member's damage dealt to the boss is recorded as their contribution delta and synced on next server check.

**The Guild Boss**: Varathos, le Titan Consumé — a zone 6 (Cendres) variant of the normal World Boss. Unique appearance: triple the size of Ignifex, combines fire and shadow aesthetics (orange + dark purple modulate).

**Fight mechanic**: Each expedition against Varathos uses the same Phase 1+2 fight structure as World Bosses (Section 2). A player's solo damage contributes to the shared pool. Varathos HP in cloud save shows "12,450 / 50,000 HP remaining."

**Guild Boss weekly schedule**:
- Monday: Boss spawns at full HP (or remains if not defeated last week)
- Each member can fight once per day (daily contribution limit: prevents one player soloing it, preserves the "we did it together" feeling)
- If defeated before Sunday: all members receive Guild Boss Reward regardless of contribution level (minimum 1 expedition required)
- If not defeated: boss gains +10% HP per surviving day (escalating urgency for next week)

**Reward on defeat** (all members):
- Guild XP: 1000
- Seasonal Points: 500
- Unique material: CHAOS_ESSENCE ×1 per member (required for Guild-exclusive Tier 10 recipe)
- Guild Trophy: "Varathos vaincu — Semaine [N] de la Saison [S]" displayed in Guild Hall

---

## 5. Trading Post

### 5.1 Design Philosophy

**No backend server for MVP Trading Post**. The system uses a leaderboard-as-database approach via a third-party service (e.g., Google Play Games Services leaderboard API for Android, or a free-tier Firebase Realtime Database). The key insight: a trading post only needs to read/write ~500 active listings at a time — this fits comfortably in a leaderboard or a Firebase document.

### 5.2 Transaction Rules (Inflation Prevention)

| Rule | Value | Rationale |
|------|-------|-----------|
| Daily listing limit | 5 items per player | Prevents flooding |
| Transaction tax | 10% of sale price (gold) destroyed, not transferred | Gold sink |
| Price floor | Common: 5g, Rare: 20g, Legendary: 100g, Epic: 500g | Prevents dump-selling |
| Price ceiling | Common: 200g, Rare: 800g, Legendary: 3000g, Epic: 10,000g | Prevents hyperinflation |
| Listing duration | 72 hours, auto-expires | Keeps market fresh |
| Buyout only | No auction — fixed price listings only | Simpler UX for mobile |

**Gold tap/sink analysis**:
- Taps: Enemy kills (wave gold), zone camps, contracts, chest loots
- Sinks: Archer recruit (30g), Tower (100g), Forge upgrades (200g), transaction tax (10%), prestige entry fee (50g × prestige tier)
- Trading post tax is the largest gold sink for active traders — prevents gold accumulation spiral

### 5.3 Technical Implementation

**Option A — Firebase Realtime Database (Recommended)**:
- Free tier: 1GB storage, 10GB/month bandwidth — more than sufficient for 5,000 active players
- Each listing is a Firebase document: `{player_id, resource_type, amount, price_per_unit, timestamp, expires_at}`
- Godot 4.6 makes HTTPS requests via `HTTPRequest` node (already permitted — no `FileAccess` restriction applies to HTTP)
- Player listings cached locally in ConfigFile, refreshed every 5 minutes or on Trading Post open
- Purchase: atomic Firebase transaction (read-then-write with version check) prevents double-buying

**Option B — Google Play Games Services Leaderboard Hack**:
- Each "score" entry encodes: `resource_type * 10^12 + amount * 10^6 + price`
- Maximum 25 entries per day per player (Google limit — enforces our 5-listing rule naturally)
- No server cost. Tradeoff: no player names in listings (anonymous market) + 24h refresh delay
- Not recommended for production but viable for soft launch

**Option C — No backend, local simulation (Offline fallback)**:
- Trading Post shows "simulated" listings generated procedurally from a seed (device date × game version)
- Prices follow realistic supply/demand curves based on zone progression tier
- Player can "buy" from simulated listings (gold deducted, resource received from thin air — these are NPC merchant listings)
- This fallback makes the feature feel alive even with 0 online players

**Recommended launch sequence**: Option C for v1.0 (no backend), Option A for v1.1 (after player base established).

### 5.4 Trading Post UI

Located in Guild Hall (Zone 6), second interactive node next to Guild Boss entrance. Separate from Guild Vault.

**Tabs**:
1. Marche — Browse active listings sorted by resource type / price
2. Mes annonces — Player's active listings (max 5), cancel option
3. Historique — Last 20 personal transactions (local ConfigFile)

**Listing flow**:
1. Player selects resource type from `ResourceInventory.get_nonempty()`
2. Enters amount (1-50 per listing for common, 1-10 for rare, 1-3 for legendary)
3. Sets price (slider between floor and ceiling with suggested price shown)
4. Confirms — resource deducted from local inventory, listing uploaded to Firebase
5. On sale: gold added automatically on next session open (Firebase check on _ready())

---

## 6. Achievement & Prestige Cosmetics

### 6.1 Achievement Framework

**200 achievements across 10 categories, 20 per category**.

| Category | ID | Theme | Example achievements |
|----------|----|-------|---------------------|
| Explorateur | EXP | Zone exploration | "Beni des Forets" (Zone 0 blessing), "Cartographe" (all zones visited), "Speleonaut" (all 8 caves found) |
| Guerrier | WAR | Combat and TD | "Tueur de Vagues" (50 waves cleared), "Boss Slayer" (first World Boss), "Sans Merci" (clear wave with 0 damage taken) |
| Collectionneur | COL | Resources | "Botaniste" (all herb-type resources), "Mineur Fou" (1000 timed resource harvests), "L'Epicurien" (all 5 Epic resources) |
| Forgeron | SMI | Crafting | "Premier Chef-d'oeuvre" (first craft), "Maitre Forgeron" (all 27 base recipes), "Legendaire" (first legendary item) |
| Stratege | STR | Formation and tactics | "Formation Parfaite" (ARC formation, all 8 archers, Wave 20+), "Multi-Cibles" (STRONGEST targeting, 500 kills), "Momentum Max" (streak tier 3) |
| Guilde | GLD | Guild activities | "Compagnon Fidele" (contribute 50× to vault), "Tueur de Varathos" (Guild Boss defeat), "Maitre de Guilde" (guild level 10) |
| Economiste | ECO | Gold and economy | "Millionnaire" (1000g at once), "Marchand Avisé" (10 Trading Post sales), "Zero Dette" (upkeep always affordable for 10 waves) |
| Saison | SEA | Seasonal content | "Titan Bronze" (Bronze rank), "Veteran Saisonnier" (complete 3 seasons), "Legende" (Legend rank any season) |
| Rogue | ROG | Secret/hidden | "Speleologue Secret" (find hidden cave not marked on map), "Silence Eternel" (defeat Mortalis without hero taking damage in Phase 1) |
| Cosmete | COS | Cosmetics | "Habille pour Tuer" (equip hero skin), "Decorateur" (3 castle decorations active), "Palette Complete" (all zone palette variants unlocked) |

### 6.2 Cosmetic Unlocks (Zero Gameplay Advantage)

All unlocks are purely visual. The game is balanced as if no cosmetics are equipped.

**Hero skins** (replace cavalier sprite at 120×96 px, same hitbox):
- Default: Cavalier Brun (default cavalry, brown horse)
- Season 1 Chapter 6 reward: Cavalier Titan (armored horse, orange/gold palette)
- Achievement "Legendaire": Cavalier Arc-en-Ciel (prismatic color-cycling modulate via Tween)
- Achievement "Silence Eternel": Cavalier de l'Ombre (dark purple transparency, half-opacity)
- Titan rank seasonal: Cavalier des Titans (titan-scale horse, 130×108 — same hitbox, larger sprite)

**Zone color palette overlays** (ColorRect alpha layer added to zone backgrounds):
- P3 zone clear: Golden shimmer (Color(1.0, 0.85, 0.3, 0.12) CanvasLayer overlay)
- P5 zone clear: Silver shimmer (Color(0.85, 0.90, 1.0, 0.18))
- Achievement "Cartographe": Sepia exploration view (Color(0.3, 0.2, 0.1, 0.08) global overlay)

**Castle decorations** (Sprite2D nodes added to castle position in Main.tscn):
- Achievement "Tueur de Vagues" (50 waves): Banniere de Victoire (flag sprite above castle, waves via Tween)
- Achievement "Boss Slayer": Trophée de Boss (mounted boss trophy sprite at castle gate)
- Season trophy: Plaque de Saison (seasonal emblem on castle wall, unique per season)
- Guild level 10: Embleme de Guilde (guild crest on castle banner)

**NPC dialogue variants** (in `npc_wanderer.gd`, NPCs check cosmetic flags):
- Default NPC: generic merchant dialogue
- Player with "Maitre Forgeron" achievement: NPC says "Ah, le grand Forgeron! J'ai entendu parler de vous..." (recognition dialogue tier 2)
- Player with Legend rank: NPCs bow (sprite flip_v briefly via Tween) before speaking
- Player with all 8 caves found: Scout NPC gives a unique extra hint about a 9th "secret" cave (lore-only, no gameplay effect)

**Weapon visual effects** (modulate cycling on hero sprite during attack animation, implemented via Tween in `hero.gd`):
- Achievement "Guerrier" category complete (all 20): Hero attacks emit a gold flash (modulate to Color(2,2,0.5,1) then back over 0.1s)
- Legendary weapon equipped (any): Soft glow pulse on weapon hit (modulate oscillation, Tween loop)
- Achievement "Sans Merci": Perfect run — a small "crown" ColorRect floats above hero for remainder of session

**Implementation note**: All cosmetics are stored in `user://cosmetics.cfg`. A `CosmeticsManager` autoload (not yet implemented) reads this on start and applies modulates/sprite swaps. No Tween on CanvasLayer (per ADR-007: AnimationPlayer forbidden on HUD, but Tween is permitted). Cosmetics applied to world nodes (not HUD) are not restricted.

---

## 7. Living Leaderboard

### 7.1 Leaderboard Categories

**Global leaderboards** (top 100, weekly snapshot):
1. Fastest Zone Clear — minimum time from wave 1 to zone prestige complete (P1+)
2. Most Resources Collected — cumulative this week (all 65 types, raw count)
3. Highest Boss DPS — peak damage-per-second dealt to any World Boss this week
4. Longest Streak — maximum kill streak tier × duration achieved this week
5. Most Guild Contributions — total vault donations this week
6. Challenge Rift Score — highest single rift score this week
7. Most Waves Survived — highest wave number reached this week

**Regional leaderboards** (top 10 by country, detected from device locale):
- Fastest Zone Clear (regional)
- Most Resources Collected (regional)

### 7.2 Data Collection (Client-Side)

Metrics collected locally during play:
```
# In user://leaderboard_week.cfg
[week]
week_id = 20260601      # YYYYWW format, checked on _ready()
fastest_zone_clear = 0  # seconds
resources_collected = 0
highest_boss_dps = 0.0
max_streak_score = 0
guild_contributions = 0
best_rift_score = 0
max_wave = 0
```

On session end, data submitted to Google Play Games Services (GPGS) leaderboard IDs. GPGS provides global ranking for free, handles anti-cheat (server-side max validation on score delta), and is available to all Android apps.

Godot 4.6 integrates GPGS via the `GodotGooglePlayGameServices` plugin (GDExtension). If the plugin is unavailable, scores are stored locally only and displayed as "Score local (non synchronisé)."

### 7.3 Guild Hall Display

The Guild Hall (Zone 6, EXPLORING state) has a "Tableau des Champions" section with three panels:

**Panel 1 — Classement Mondial** (last synced snapshot):
- Scrollable Label list showing top 10 entries per category
- Each entry: `[Rank] [PlayerName] [Score]` (PlayerName = GPGS display name or "Inconnu")
- Refresh button (HTTPRequest to GPGS API — 30 second cooldown)
- Last updated timestamp displayed

**Panel 2 — Classement de Guilde**:
- Guild member rankings within the guild this week
- Sourced from cloud save guild data (Section 4.1)
- Shows: member name, seasonal points, guild XP contributed, boss damage

**Panel 3 — Mon Historique**:
- Player's own best scores across all categories for last 4 weeks
- Trend indicators: up/down arrows per category vs. previous week
- Sourced entirely from local ConfigFile — no network needed

### 7.4 "Massively Single-Player" Design Principles

The leaderboard is the primary mechanism for the "massively single-player" feeling — the player is always alone but always aware of others. Key design decisions:

**Ghost presence system**: The leaderboard top-5 scores are displayed not just as numbers but as presence indicators in the world. In the exploration map, small "ghost hero" sprites (semi-transparent cavalier, 40% alpha) appear at positions derived from the top-5 players' zone progress snapshot. These ghosts are purely cosmetic — they move slowly across the map at a speed proportional to their leaderboard rank. They cannot be interacted with. They create a sense that other players exist in the same world.

**"N players cleared this boss last week"**: When the player approaches a World Boss for the first time, the Guild Hall bulletin board (a Label in Zone 6) shows "127 joueurs ont vaincu ce boss la semaine derniere." This number comes from the GPGS leaderboard count for that boss's category score (score > 0 = defeated). Creates social proof without requiring any social interaction.

**Seasonal shared milestones**: A global milestone tracker (fetched from CDN JSON): "La communaute a collecté 4,521,000 IRON_ORE cette saison." When milestones are hit (every 1M of common resources, every 1000 boss kills globally), all players receive a small bonus resource drop for the next 24 hours. This creates shared history without real-time coordination.

**Async friendship without a friends system**: Players can display a "Devise" (motto) — a 30-character string stored on their GPGS profile. Mottos appear next to leaderboard entries. Players discover each other's personality through these brief texts. No friend requests, no chat, no grief vectors. The motto is the only player-to-player communication channel.

---

## 8. Integration Points with Existing Code

### 8.1 HeroProgression Extension

The existing `hero_progression.gd` already provides:
- `hero_level` (1-50), `hero_xp`, `zone_clears[15]`, `get_zone_mastery(zone_idx)` (0-5)
- `add_xp()`, `register_zone_clear()`, `register_discovery()`

**New fields needed** (add to ConfigFile save/load):
```gdscript
var prestige_tiers: Array[int] = []   # Per-zone prestige level (0-5), persists season reset? NO — reset
var seasonal_points: int = 0          # Current season total
var season_rank: int = 0              # 0=Bronze 1=Silver 2=Gold 3=Titan 4=Legend
var legendary_items_owned: Array[bool] = []  # 15 booleans
var achievements_earned: Array[bool] = []    # 200 booleans
```

### 8.2 EnemyWave Extension (World Boss)

World Boss Phase 2 uses the existing `EnemyWave._spawn_enemy()` system. The boss node is activated with:
```gdscript
# In world_boss.gd Phase 2 transition:
_enemy_wave._wave_tag = EnemyWave.TAG_BOSS
# The existing BOSS_HP_MULT (×5.0), BOSS_SCALE (1.6), BOSS_GOLD_MULT (3) apply
# Additional world boss overlay: attach world_boss_phase2_overlay.gd as child of boss node
```

### 8.3 GameStateMachine Extension

World Boss Phase 2 requires a new GSM state or the repurposing of PLAYING. Recommended: add `BOSS_ARENA` state that behaves identically to PLAYING but with locked castle position and boss-specific enemy spawn coordinates.

Valid transitions:
```
EXPLORING → BOSS_ARENA   (hero enters boss Phase 2 trigger zone)
BOSS_ARENA → EXPLORING   (Phase 2 complete — boss defeated or fled)
BOSS_ARENA → GAME_OVER   (castle destroyed during boss fight)
```

### 8.4 ExplorationMap Extension (Guild Hall, Boss, Rift Entrance)

Three new spawn methods in `exploration_map.gd`:
- `_spawn_guild_hall(pos)` — Zone 6 center, permanently present
- `_spawn_world_boss(zone_idx)` — One per zone, spawns only at P1+
- `_spawn_rift_portal(pos)` — Zone 11+ zones, one per zone, permanent

All three use the existing `_spawn_*` pattern (Area2D + script + setup() call + signal wire).

### 8.5 New Autoloads Required

| Autoload | File | Purpose |
|----------|------|---------|
| `SeasonManager` | `src/autoloads/season_manager.gd` | Season state, quest tracking, seasonal points, cosmetic flags |
| `GuildManager` | `src/autoloads/guild_manager.gd` | Guild state, vault, contracts, boss HP |
| `LeaderboardManager` | `src/autoloads/leaderboard_manager.gd` | GPGS submit/fetch, local cache, ghost position data |
| `AchievementManager` | `src/autoloads/achievement_manager.gd` | 200 achievement checks, cosmetic unlock triggers |
| `CosmeticsManager` | `src/autoloads/cosmetics_manager.gd` | Apply/remove cosmetics on hero, castle, zone overlays |

All follow the existing pattern: `extends Node`, ConfigFile persistence, signal-driven updates, `session_reset` integration via `GameStateMachine.session_reset.connect()`.

---

## 9. Tuning Knobs

| Value | Current | Note |
|-------|---------|------|
| `PRESTIGE_HP_MULTS` | [1.5, 2.0, 2.8, 3.8, 5.0] | Scale if P5 is too punishing |
| `PRESTIGE_LEGENDARY_CHANCE` | [0.05, 0.12, 0.22, 0.35, 0.55] | Reduce if legendary items drop too fast |
| `WORLD_BOSS_BASE_HP` | [2000, 2500, 3000, 3500, 4000, 4500, 5000, 5000, 5500, 5500, 6000, 6000, 6500, 7000, 8000] | Per zone (0-14) |
| `BOSS_HP_REGEN_PER_DAY` | 5% | Increase if bosses survive too long |
| `GUILD_MAX_MEMBERS` | 20 | Reduce to 10 if async sync complexity too high |
| `SEASON_DURATION_DAYS` | 90 | Can be 60 for faster seasonal rhythm |
| `RIFT_TIME_LIMIT_SECONDS` | 600 | Reduce to 480 for higher pressure |
| `TRADING_POST_DAILY_LIMIT` | 5 listings | Increase to 10 once market health is verified |
| `TRADING_POST_TAX_RATE` | 0.10 | Increase to 0.15 if inflation observed |
| `GUILD_BOSS_HP` | 50000 | Scale with average guild size at launch |
| `SEASONAL_POINTS_PER_RIFT` | 50 | Adjust if rift is over-rewarded vs. boss fights |

---

## 10. Acceptance Criteria

| ID | Criterion | Test method |
|----|-----------|-------------|
| AC-EG-01 | Level 50 player has at least 3 distinct meaningful activities per session | Playtest with level-50 save |
| AC-EG-02 | Zone Prestige P5 is achievable without legendary items, difficult but not impossible at level 50 | Automated formula check + manual playtest |
| AC-EG-03 | World Boss requires minimum 2 expeditions at first attempt (cannot be one-shot) | HP vs. max DPS calculation |
| AC-EG-04 | Legendary item crafting requires at minimum 2 weeks of daily play | Ingredient drop rate simulation |
| AC-EG-05 | Challenge Rift completes in 8-12 minutes on average | Timer-based playtest |
| AC-EG-06 | Season reaches Gold tier in ~40 hours of cumulative play (not 40 days) | Points-per-hour formula check |
| AC-EG-07 | Guild system functions offline (no server) in Approach C mode | Offline device test |
| AC-EG-08 | Trading post tax removes at least 15% of gold in circulation per week among active traders | Economy simulation |
| AC-EG-09 | Leaderboard ghost presence visible in exploration map without degrading 60fps budget | Profiler check (≤150 draw calls) |
| AC-EG-10 | All 200 achievements achievable without paying any money | Design review |
| AC-EG-11 | Zero achievements provide gameplay advantage (cosmetics only) | Design review |
| AC-EG-12 | Season reset does not destroy the player's base progression (level, legendaries, recipes) | Save file diff test |
