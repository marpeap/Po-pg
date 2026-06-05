# RPG Progression System — Technical Specification

> **Status**: Designed
> **Author**: Research synthesis — Path of Exile / Diablo 3-4 / Monster Hunter / FFXIV / Zelda BOTW / Dark Souls / Stardew Valley
> **Last Updated**: 2026-05-25
> **Game Context**: Garrison — Godot 4.6 / GDScript / Android landscape / 960x540 viewport
> **Integration Target**: Extends existing hero.gd XP system (3 tiers), equipment bonuses (_atk_damage_bonus etc.), and EXPLORING GSM state.

---

## Design Philosophy

Seven reference games were analyzed for their core progression insight:

- **Path of Exile** — Spatial passive tree creates build identity through routing, not just node selection. Every node you skip is a decision.
- **Diablo 3/4** — Paragon/seasonal layers give post-cap players infinite growth with diminishing returns, avoiding power cliffs.
- **Monster Hunter** — Equipment crafting from enemy drops creates a hunt-to-upgrade loop that makes every enemy meaningful. Set bonuses reward commitment.
- **Final Fantasy XIV** — Job system separates role identity from mechanical expression. Unlocking a job feels like a rite of passage.
- **Zelda BOTW** — Heart containers and stamina wheels are parallel currencies that create genuine tradeoffs (survival vs. exploration reach).
- **Dark Souls** — Stat investment gates weapon requirements and creates builds that feel intentionally fragile or intentionally tanky. Nothing is purely additive.
- **Stardew Valley** — Skill levels and profession forks create moment-of-commitment decisions that differentiate two players with identical playtime.

Mobile TD/RPG constraint applied to all of the above: **every interaction must be resolvable with one thumb, in under 3 seconds, without a keyboard**. Deep systems must be accessible via a single confirmation tap on a pre-legible card, not via a sub-menu tree.

---

## Overview

The progression system has seven interlocking layers. Each layer has an independent unlock cadence so the player always has at least one active growth axis regardless of their session length.

```
Layer               Unlocks at          Resets on NG+?   Primary Currency
─────────────────────────────────────────────────────────────────────────
1. Hero Class       Level 1 (pick)      No               None
2. Class Evolution  Levels 10/25/40     No               None (threshold)
3. Passive Tree     Level 2 (first pt)  No               Skill Points (SP)
4. Active Skills    Level 3/8/15        No               None (threshold)
5. Equipment        Any time            No (carry over)  Crafting Mats
6. Mastery          Zone/Enemy counts   No               Rep (per source)
7. NPC Affinity     Interaction counts  No               Gifts / visits
─────────────────────────────────────────────────────────────────────────
Post-cap Prestige   Level 50            Partial          Prestige Tokens
```

Session-scoped Forge upgrades (existing system) remain separate and continue to reset on GAME_OVER. This document covers only persistent progression.

---

## 1. Hero Class System

### 1.1 Starting Classes

At the first launch (before wave 1), the player selects one of three starting classes. The selection is presented as a full-screen card swipe (3 cards, landscape, one per class). No tutorial is gated behind the choice — the player can start fighting immediately.

```
CLASS           ROLE            BASE STATS (at Lv 1)
──────────────────────────────────────────────────────────────────────
Cavalier        Mobile skirmisher   HP 50 / ATK 10 / SPD 1.0x / RANGE 130
                                    (matches current hero.gd defaults)
Warden          Defensive anchor    HP 75 / ATK 7  / SPD 0.7x / RANGE 160
Arcane Scout    Ranged burst        HP 35 / ATK 14 / SPD 1.2x / RANGE 200
```

**Stat formula per level (all classes):**
```
hp_max(lv) = BASE_HP + (lv - 1) * HP_PER_LEVEL
atk(lv)    = BASE_ATK + (lv - 1) * ATK_PER_LEVEL
```

| Class | BASE_HP | HP_PER_LEVEL | BASE_ATK | ATK_PER_LEVEL | BASE_SPD | BASE_RANGE |
|---|---|---|---|---|---|---|
| Cavalier | 50 | 4 | 10 | 1 | 200px/s | 130px |
| Warden | 75 | 7 | 7 | 1 | 140px/s | 160px |
| Arcane Scout | 35 | 3 | 14 | 2 | 240px/s | 200px |

**ATK_COOLDOWN base:** Cavalier 1.5s / Warden 2.0s / Arcane Scout 1.0s

### 1.2 Class Evolutions (Branching at Lv 10 / 25 / 40)

Each evolution is a permanent fork. The player taps a confirmation card when they reach the threshold level. Both branches remain theoretically valid for any playstyle — neither is strictly superior.

#### Cavalier Evolution Tree

```
Lv 1   CAVALIER
         |
Lv 10  ┌─────────────────┐
       Knight-Commander   Shadow Rider
         |                   |
Lv 25  ┌────┐           ┌────┐
      Paladin Ironclad  Voidhunter  Shadowmeld
         |      |           |          |
Lv 40  ──────────────────────────────────────
       (4 terminal evolutions — one per branch path)
```

**Lv 10 Fork — Cavalier:**

| Evolution | Stat Change | Playstyle | Exploration Bonus |
|---|---|---|---|
| Knight-Commander | +15 HP, archers +5% dmg aura (40px) | Tank front-line, buff tower archers | Can recruit NPC allies at camps (+1 temp archer per expedition) |
| Shadow Rider | +20% SPD permanently, stealth 0.4s on dodge | Kite and burst, solo exploration | Hostile camps offer bribe dialogue (avoid combat, pay 30g) |

**Lv 10 Fork — Warden:**

| Evolution | Stat Change | Playstyle | Exploration Bonus |
|---|---|---|---|
| Sentinel | +25 HP, castle regen +0.03/s while hero is within 300px of castle | Stationary defensive anchor | Resource nodes near castle yield +25% output |
| Ranger | +40px range, auto-attack pierces 1 additional enemy | Long-range harassment | Can access elevated terrain nodes (extra wood/stone, map edges) |

**Lv 10 Fork — Arcane Scout:**

| Evolution | Stat Change | Playstyle | Exploration Bonus |
|---|---|---|---|
| Elementalist | Spell damage +30%, spell cooldown -20% | Spell-centric burst, fragile | Crafting anvils produce 1 extra component when used |
| Battle Mage | +20 HP, auto-attack applies 1s slow (factor 0.4) | Hybrid melee/spell | Healing shrines restore 15 extra HP (instead of base 10) |

**Lv 25 Forks** (each Lv 10 branch splits again):

Each Lv 25 fork adds a **signature passive** — a unique mechanic not achievable through the skill tree:

| Path | Signature Passive | Description |
|---|---|---|
| Knight-Commander → Paladin | Divine Shield | Once per expedition, absorb 1 lethal hit (HP set to 1 instead of 0). Cooldown resets on castle return. |
| Knight-Commander → Ironclad | Fortress Aura | Archers within 80px of hero gain +10% damage and -15% damage taken. |
| Shadow Rider → Voidhunter | Death Mark | First hit on a new enemy applies a 5s mark; marked enemies take +25% damage from all sources. |
| Shadow Rider → Shadowmeld | Phase Step | Dodge input (double-tap joystick) triggers 0.3s invincibility + 80px dash in joystick direction. Cooldown 4s. |
| Sentinel → Bulwark | Wall of Stone | Hero can place 1 temporary barrier (200 HP, 10s duration, 3x per expedition) blocking enemies. |
| Sentinel → Chaplain | Battle Blessing | Every 15s, emit a pulse (150px) that heals all allies (including archers) for 5 HP. |
| Ranger → Sniper | Headshot | Every 5th auto-attack deals 3x damage and applies 0.5s stun. Counter resets on death/return. |
| Ranger → Tracker | Scent Trail | Enemy HP bars visible through walls; rare resource node locations revealed on minimap. |
| Elementalist → Archmage | Mana Overload | All spells can be held 1s to charge for 2x effect at 1.5x mana cost. |
| Elementalist → Runesmith | Rune Inscription | Place up to 3 runes in the world (120px AoE trap). Each rune has a type matching equipped spell. |
| Battle Mage → Spellblade | Enchant Strike | Auto-attacks consume 5 mana; if ≥20 mana: attacks deal +8 bonus magic damage. |
| Battle Mage → Mystic Warden | Soul Barrier | Mana acts as a secondary shield. Each point of mana absorbs 0.5 damage before HP is consumed. |

**Lv 40 Forks** — Each Lv 25 branch reaches a terminal **Ascendant** form. Effect: +1 active skill slot (from 3 to 4), unlock a unique Legendary item recipe at the crafting anvil, and gain a permanent visual transformation (sprite palette swap + glow).

### 1.3 Class Effect on World Exploration

Different classes change what the player finds and how NPCs respond:

| Class Family | Resource Drops | NPC Dialogue | Zone Access |
|---|---|---|---|
| Cavalier lineage | Enemies drop Iron Scraps +20% | Blacksmith offers 10% discount on enhancement | Can break fortified doors (stone walls, requires Lv 10+) |
| Warden lineage | Stone nodes yield +30% | Village elder gives bonus quests (extra gold rewards) | Can traverse swamp zones (others take 5 HP/s from toxic ground) |
| Arcane Scout lineage | Herb/mushroom nodes yield +50% | Mage tower NPC offers spell scrolls unavailable in shop | Can interact with arcane seals (hidden loot rooms, require Lv 10+) |

---

## 2. Passive Skill Tree

### 2.1 Structure

Mobile-friendly PoE-inspired tree. Three clusters of 5 nodes each = 15 total nodes per class. All classes share the same tree layout; the starting position and pre-allocated nodes differ.

```
TREE LAYOUT (top-down view, 3 clusters):

         [CLUSTER A — Combat]          [CLUSTER B — Survival]         [CLUSTER C — Utility]
         ┌───────────────────┐         ┌───────────────────┐         ┌───────────────────┐
         │  A1  A2  A3       │         │  B1  B2  B3       │         │  C1  C2  C3       │
         │   \  |  /        │         │   \  |  /        │         │   \  |  /        │
         │    A4  A5        │         │    B4  B5        │         │    C4  C5        │
         └───────────────────┘         └───────────────────┘         └───────────────────┘
                 │                             │                             │
                 └─────────────────────────────┴─────────────────────────────┘
                                         (all clusters share 1 SP pool)
```

**Node unlock rule:** Nodes must be unlocked adjacent to an already-unlocked node. Each cluster has 1 entry node (A1, B1, C1). To access a new cluster, you must unlock the entry node of that cluster (no cross-cluster bridges at the tree level — you re-enter at each cluster's root).

**Skill Points (SP):** 1 SP per level (Lv 2 to Lv 50 = 49 SP). Maximum 15 nodes in tree = player can unlock all of them by Lv 17 and then banks SP for post-cap use (see Prestige). This intentional surfeit means the player feels powerful by mid-game.

### 2.2 Node Types

Three types of nodes exist:

**Type I — Stat Boost** (plain circular node, grey background): Pure numeric increase. No activation requirement.

**Type II — New Ability** (diamond node, gold border): Grants a passive triggered mechanic. No active input required. Activates automatically under defined conditions.

**Type III — World Unlock** (star node, teal border): Permanently changes what the player can do in the exploration map. Unique per playthrough.

### 2.3 Combat Cluster (A)

| Node | Type | Name | Effect | Class Starting Pre-Alloc |
|---|---|---|---|---|
| A1 | I | Iron Strikes | +2 ATK flat (additive with equipment) | Cavalier, Warden |
| A2 | I | Rapid Cadence | ATK_COOLDOWN -0.15s (minimum 0.3s) | Arcane Scout |
| A3 | II | Exploit Wound | Enemies below 30% HP take +20% damage from hero | None |
| A4 | I | Cleave | Auto-attack AoE cone widens from 60° to 90°; +1 target hit | None |
| A5 | III | Battle Mastery | Unlocks Coliseum zone on exploration map (elite enemy arena; drops Rare+ loot only) | None |

### 2.4 Survival Cluster (B)

| Node | Type | Name | Effect | Class Starting Pre-Alloc |
|---|---|---|---|---|
| B1 | I | Thick Hide | +10 HP flat | Warden |
| B2 | I | Resilience | Damage reduction +5% (additive with equipment; soft cap 50%) | None |
| B3 | II | Last Stand | Below 25% HP: all healing received is doubled | None |
| B4 | II | Blood Price | On hero kill: recover 8 HP | None |
| B5 | III | Survival Instinct | Unlocks hidden underground passages between zones (shortcut travel, skips 1 zone of enemies per expedition) | None |

### 2.5 Utility Cluster (C)

| Node | Type | Name | Effect | Class Starting Pre-Alloc |
|---|---|---|---|---|
| C1 | I | Keen Eye | Resource nodes visible 200px further on minimap | Arcane Scout |
| C2 | I | Gold Sense | Coin magnet radius +25px (stacks with Forge F3 upgrade) | None |
| C3 | II | Windfall | 15% chance on kill: extra coin spawns (value = 5g) | None |
| C4 | II | Forager | Timed resource nodes yield +1 extra unit on depletion | None |
| C5 | III | Ancient Knowledge | Unlocks lore-sealed vaults in exploration map (4 vaults total; each contains 1 guaranteed Legendary item and 1 NPC affinity gift item) | None |

### 2.6 Mobile UI for the Tree

The passive tree is accessed from the Hero tab in the pause menu (one tap). It renders as a 3-column grid. Each node is a 96×96px touch target (above the 48px Android minimum). Locked nodes are greyed out. Unlocked nodes pulse gold. SP counter shown top-right. Unlocking a node: tap → confirm card appears (shows effect) → tap "Confirm" → node illuminates. No drag, no zoom required.

---

## 3. Active Skill Slots

### 3.1 Slot Structure

Each hero has **3 active skill slots** (4 at Lv 40 Ascendant). Skills are placed in slots and activated via dedicated HUD buttons (bottom-right quadrant, matching the existing ARCHER/TOUR/CIBLE/FORM/FORGE layout). Skill buttons appear only in EXPLORING state; they hide in PLAYING state.

```
HUD layout during EXPLORING (bottom-right):
┌──────────────────────────────────────────┐
│                          [SKILL 1] [SKILL 2] │
│                          [SKILL 3] [RETURN]  │
└──────────────────────────────────────────┘
Each skill button: 80×80px touch target, shows icon + cooldown arc overlay.
```

### 3.2 Skill Acquisition

Skills are not class-locked. They are acquired through:

| Source | Example | Notes |
|---|---|---|
| Level threshold | Lv 3 → Slot 1 unlocks; player picks from 3 offered skills | Draft offer: 3 random from class-appropriate pool, pick 1 |
| Lv 8 → Slot 2 | Second draft | Same draft mechanic |
| Lv 15 → Slot 3 | Third draft | Same draft mechanic |
| Lv 40 → Slot 4 | Ascendant bonus | Free choice from full pool |
| NPC shop | Purchased for 150g | Replaces current slot skill; old skill is lost |
| Loot drop (Epic+) | Found in exploration | Equip from inventory screen |

**Draft pool by class:**

| Class | Weighted-toward Skills |
|---|---|
| Cavalier | Charge, Shield Bash, War Cry, Rally |
| Warden | Stone Wall, Bulwark Stance, Earth Spike, Mending Touch |
| Arcane Scout | Arcane Bolt, Blink, Frost Nova, Chain Lightning |

Off-class skills appear in the pool at 20% weight (cross-class builds are viable but rare by default).

### 3.3 Skill Catalogue

20 skills total. Each has a mana cost, cooldown, and effect.

**Mana system:** Hero starts each expedition with 100 mana. Mana regenerates at 5/s passively. No regen in TD mode (skills deactivated). Mana lost on death, restored to 100 on castle return.

| Skill | Class Affinity | Mana | CD (s) | Effect |
|---|---|---|---|---|
| Charge | Cavalier | 20 | 6 | Hero dashes 300px in joystick direction; first enemy hit takes 25 damage and is knocked back 80px |
| Shield Bash | Cavalier | 15 | 5 | 90° cone, 100px range: stuns enemies for 1.5s |
| War Cry | Cavalier | 30 | 12 | 200px pulse: archers +20% fire rate for 8s |
| Rally | Cavalier | 25 | 10 | Restore 20 HP and remove all slow/poison effects |
| Stone Wall | Warden | 35 | 18 | Place a 200 HP barrier at hero position (persists 12s or until destroyed) |
| Bulwark Stance | Warden | 20 | 8 | For 5s: hero takes -40% damage, speed -50%; auto-attack range +50% |
| Earth Spike | Warden | 25 | 7 | Line AoE (400px long, 60px wide): 30 damage + 2s root |
| Mending Touch | Warden | 20 | 15 | Heal self 30 HP; if HP full: grant 20-HP shield instead (lasts 6s) |
| Arcane Bolt | Arcane Scout | 10 | 2 | Single target: 35 damage, bounces to 1 enemy within 120px for 17 damage |
| Blink | Arcane Scout | 15 | 4 | Teleport to touched screen position (up to 350px); invincible during transit |
| Frost Nova | Arcane Scout | 30 | 10 | 180px AoE: 20 damage + 3s slow (factor 0.25) to all enemies hit |
| Chain Lightning | Arcane Scout | 40 | 14 | 5-chain bounce: 40 / 28 / 20 / 14 / 10 damage per bounce; max 500px chain length |
| Blood Ritual | Any | 35 | 20 | Sacrifice 15 HP to reset all skill cooldowns instantly |
| Iron Skin | Any | 20 | 12 | Absorb next 40 damage taken as a shield (shield lasts 8s) |
| Smoke Bomb | Any | 15 | 8 | Enemies in 150px radius lose aggro for 4s (ignore hero) |
| Berserker Rage | Any | 25 | 16 | For 6s: +40% ATK, -20% damage reduction |
| Mana Surge | Any | 0 | 30 | Convert 30 HP to 60 mana (useful for mana-heavy builds) |
| Thunder Step | Any | 30 | 10 | 250px dash; upon arrival: 80px lightning burst for 20 damage + 1s stun |
| Nature's Grasp | Any | 20 | 9 | Root nearest 3 enemies for 2s; rooted enemies take +15% damage from all sources |
| Spectral Arrow | Any | 25 | 7 | Fire a piercing arrow (unlimited range, 60px wide): 30 damage per enemy hit |

### 3.4 Skill Upgrade

Each skill has 5 upgrade levels (I to V). Upgrade currency: **Skill Shards** (found in loot, purchased from mage NPC). Shard cost per level: 1 / 2 / 3 / 5 / 8 (Fibonacci progression).

Upgrade effect per skill: +15% damage/heal/shield per level, -5% cooldown per level (multiplicative). Level V also unlocks a **bonus modifier** unique to each skill (e.g., Arcane Bolt Lv V: bounce count increases to 3; Charge Lv V: leaves a 2s fire trail dealing 5 DPS).

### 3.5 Skill Combo Mechanic

"Skill combos" trigger when two specific skills are used within a 3-second window. The combo fires automatically — no extra input required. Combos create build diversity by rewarding specific skill pairings.

**Combo table (8 combos total):**

| Skill A | Skill B (within 3s after A) | Combo Name | Bonus Effect |
|---|---|---|---|
| Frost Nova | Chain Lightning | Shatter Storm | Frozen enemies explode for +100% lightning damage |
| Charge | Shield Bash | Cavalry Break | Knock-back radius doubles (160px); +10 bonus damage |
| Earth Spike | Stone Wall | Fortress Rising | Wall HP +100 and reflects 10 damage to attackers |
| Blink | Arcane Bolt | Phase Shot | Bolt fires in 8 directions from teleport destination |
| War Cry | Berserker Rage | Battle Frenzy | Effect durations extend to 12s each (instead of 8/6s) |
| Mending Touch | Iron Skin | Ironflesh | Shield value doubles (80 damage absorbed) |
| Smoke Bomb | Blood Ritual | Shadow Pact | No HP sacrifice; cooldowns reset for free |
| Thunder Step | Nature's Grasp | Tempest Prison | Rooted enemies are additionally stunned for 1.5s |

Combo eligibility: the player must have both combo skills equipped simultaneously. Combos display a brief banner ("CAVALRY BREAK!") and a 0.5s camera shake (magnitude 4px, existing Tween pattern).

---

## 4. Equipment System

### 4.1 Slots

Six equipment slots. Each slot accepts one item. Items are not stack-limited (one per slot).

```
SLOT            STAT FOCUS              VISUAL POSITION ON HERO
──────────────────────────────────────────────────────────────────
Weapon          ATK, ATK_COOLDOWN       Right hand / holster
Armor           HP_MAX, DMG_REDUCTION   Torso
Helm            HP_MAX, SPD mult        Head
Ring            Any 1 stat (random)     Left hand
Amulet          Any 2 stats (random)    Neck
Boots           SPD mult, RANGE         Feet
```

### 4.2 Rarity Tiers

Five rarity tiers. Higher rarity = more stat rolls + higher roll ranges.

| Tier | Color | Stat Rolls | Drop Rate (from enemies) | Source |
|---|---|---|---|---|
| Common | White | 1 roll | 50% | Any enemy |
| Rare | Blue | 2 rolls | 30% | Any enemy |
| Epic | Purple | 3 rolls | 15% | Elite enemies, chests |
| Legendary | Orange | 4 rolls + unique passive | 4% | Boss enemies, lore vaults |
| Mythic | Red | 5 rolls + 2 unique passives | 1% (NG+2 only) | Prestige endgame only |

**Stat roll ranges (per roll, at item level = hero level):**

| Stat | Common | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|
| ATK flat | 1-3 | 2-5 | 4-8 | 6-12 | 9-18 |
| HP flat | 3-8 | 6-15 | 12-25 | 20-40 | 30-60 |
| SPD mult | 1.02-1.05 | 1.04-1.08 | 1.07-1.12 | 1.10-1.20 | 1.15-1.30 |
| DMG reduction | 0.02-0.05 | 0.04-0.08 | 0.07-0.12 | 0.10-0.18 | 0.14-0.25 |
| ATK_COOLDOWN reduction | 0.05-0.10s | 0.08-0.15s | 0.12-0.20s | 0.18-0.30s | 0.25-0.40s |
| RANGE flat | 5-10px | 8-18px | 15-30px | 25-50px | 35-70px |

**Legendary unique passives (examples):**

| Item Name | Slot | Unique Passive |
|---|---|---|
| Venom Blade | Weapon | Auto-attacks apply 3 DPS poison for 4s (already in hero.gd — canonize here) |
| Iron Sword | Weapon | 60° AoE cone swing hits 2 additional enemies at 40% damage (already in hero.gd — canonize here) |
| Shadow Mail | Armor | Poison immune; enemies have -30% aggro range toward hero |
| Crystal Staff | Weapon | All spell damage x1.30 (already in hero.gd — canonize here) |
| Crystal Amulet | Amulet | Regenerate 2 HP every 4s (already in hero.gd — canonize here) |
| Speed Elixir (consumable) | Boots slot | SPD x1.5 for 12s (already in hero.gd — canonize here) |
| Silk Cloak | Armor | Enemy aggro radius toward hero reduced by 40% (_stealth 0.4) |
| Warden's Bulwark | Armor | While standing still for >1s: DMG_REDUCTION +0.15 |
| Herald of Ash | Weapon | On kill: 60px fire burst deals 15 damage to surrounding enemies |
| Stormcaller Ring | Ring | Chain Lightning bounces +2 extra times |

### 4.3 Set Bonuses

Items from the same named set grant bonuses at 2/4/6 piece thresholds.

**Set: Iron Phalanx** (Warden-themed, Armor/Helm/Boots focus)

| Pieces | Bonus |
|---|---|
| 2 | +15 HP flat |
| 4 | Damage reduction stacks up to 60% (normally soft-capped at 50%) |
| 6 | Stone Wall and Bulwark Stance cooldowns -50%; Fortress Rising combo unlocks regardless of skill equip |

**Set: Phantom Stride** (Arcane Scout-themed, Boots/Ring/Amulet)

| Pieces | Bonus |
|---|---|
| 2 | +0.10x SPD mult |
| 4 | Blink cooldown -2s; teleport range +100px |
| 6 | On Blink: all nearby enemies (200px) are slowed 0.5 for 2s; Phase Shot combo always active |

**Set: Warlord's Regalia** (Cavalier-themed, Weapon/Armor/Helm)

| Pieces | Bonus |
|---|---|
| 2 | +3 ATK flat |
| 4 | War Cry aura radius doubles (400px); also affects castle archers (not just formation) |
| 6 | Charge becomes free (0 mana cost); Battle Frenzy combo always active |

**Set: Arcane Ascendancy** (Arcane Scout, Weapon/Amulet/Ring)

| Pieces | Bonus |
|---|---|
| 2 | Spell damage +15% |
| 4 | On spell kill: restore 8 mana |
| 6 | Mana pool +50 (cap 150); Mana Overload charge time -0.3s |

### 4.4 Item Acquisition

Items are found via three paths:

**Path A — Enemy drops:** Enemies drop items on kill at rarity-weighted rates. Drop uses the pool system (existing ObjectPoolManager) with up to 8 item drops in flight. Each drop is a glowing orb that persists 30s before despawning. Hero walks over it to collect (same magnet radius as coins).

**Path B — Crafting:** At the crafting anvil (existing exploration node), the player can combine materials into items.

Crafting recipe structure:
```
OUTPUT               = BASE_MATERIAL x N + CATALYST x 1
──────────────────────────────────────────────────────────
Common item (any slot)  = 3 Iron Scraps + nothing
Rare item (any slot)    = 5 Iron Scraps + 1 Binding Rune
Epic item (chosen slot) = 8 Iron Scraps + 2 Binding Runes + 1 Essence
Legendary (known recipe)= 12 Iron Scraps + 3 Binding Runes + 2 Essences + 1 Soul Crystal
```

Materials drop from specific sources:
- Iron Scraps: Infantry enemies (40%), Stone resource nodes (20%)
- Binding Rune: Cavalier enemies (30%), Treasure chests (50%)
- Essence: Healer enemies (20%), Healing shrines (after depletion, 25% chance)
- Soul Crystal: Boss enemies only (100% drop), Lore vaults (1 each)

Crafting is instant (no wait timer) — one tap at the anvil after material check passes.

**Path C — Enhancement (upgrade levels +1 to +10):**

Any item can be enhanced at the anvil. Enhancement increases all stat rolls by 8% per level (+1 level = +8% to each numeric stat). Enhancement cost: 2 Iron Scraps per level for Common; 3 per level for Rare; 4 per level for Epic; 5 per level for Legendary. Enhancement never fails (no destruction mechanic — mobile-friendly decision).

```
enhanced_stat(level, base) = base * (1.0 + level * 0.08)
```

Enhancement cap: +10 (all rarities). A +10 Legendary is the strongest achievable item outside Mythic.

---

## 5. Prestige / Ascension System

### 5.1 Unlock Condition

Prestige unlocks at character level 50. The level cap is hard at 50. Prestige is voluntary — the player chooses when to trigger it from the hero menu.

### 5.2 What Resets on Prestige

| System | Resets? | Notes |
|---|---|---|
| Hero level | Yes → back to Lv 1 | XP thresholds scale by +20% per Prestige tier |
| Passive tree SP | Yes → all refunded | Tree layout unchanged; re-allocate from scratch |
| Active skill slots | Yes → empty | Must re-acquire skills (levels 3/8/15 gates reset) |
| Class choice | No | Cannot change class on Prestige |
| Class evolution | No | Lv 10/25/40 forks preserved; instantly re-granted at correct level |
| Equipment | No | All items and enhancements carry over |
| Mastery progress | No | All tiers preserved |
| NPC affinity | No | All affinity levels preserved |
| Gold (session) | Yes | Session gold resets to STARTING_GOLD on GAME_OVER regardless |
| Prestige tier | +1 | Tracks how many times the player has prestiged |

### 5.3 Prestige Rewards (per tier)

| Prestige Tier | New Reward |
|---|---|
| P1 | Prestige Token x1; world skin palette swap (warmer/cooler tones); castle max HP +20 base permanent |
| P2 | Prestige Token x1; unlock Mythic item drops (NG+2 only); enemy HP +25% across all waves |
| P3 | Prestige Token x1; new enemy type: "Veteran" (double base stats, drops Epic minimum) |
| P4 | Prestige Token x1; castle regen rate doubles permanently (+0.015/s stacked) |
| P5 | Prestige Token x1; unlock "Garrison Mode" (all 4 class evolutions simultaneously — cosmetic, no stat change) |
| P5+ | Prestige Token x1 per tier; enemy HP +10% per tier (diminishing pressure curve) |

**Prestige Tokens** are a meta-currency spent on permanent unlocks that persist across all future Prestiges:

| Token Cost | Unlock |
|---|---|
| 1 | +5 base gold at session start (stacks, max 10 purchases = +50g baseline) |
| 2 | Unlock a new NPC type in exploration (see Section 7) |
| 3 | Add 1 crafting recipe to anvil (rotates from a pool of 20 locked recipes) |
| 5 | Cosmetic: hero portrait frame (gold border, animated) |
| 10 | Permanent: 1 additional archer formation slot (max 2 purchases = 10 archers total) |

### 5.4 NG+ World Changes

Each Prestige tier makes the world harder and more interesting:

| Change | P1 | P2 | P3+ |
|---|---|---|---|
| Enemy HP | Base | +25% | +10% per tier |
| Enemy count per wave | Base | +2 per wave | +1 per tier |
| New resource variants | Ore nodes → Mithril Ore (Iron Scraps x2) | Crystal nodes → Void Crystal (Essence x2) | P3: Void Essence (Soul Crystal substitute) |
| New NPC dialogue | NPCs mention Prestige ("You look... different.") | New questline unlocks | Unique cosmetic reward at P3+ |
| Locked zones | None | Corrupted Forest (new zone, Veteran enemies) | P3: Void Rift (high-risk zone, Mythic drops) |

---

## 6. Mastery Systems

Three mastery axes: Zone, Resource, Enemy. Each has 5 tiers. Tiers unlock by reaching cumulative thresholds (totals, not per-session).

### 6.1 Zone Mastery

Tracked per exploration zone. "Visits" = completing an expedition that passes through that zone.

**Zones (matches existing exploration map):**

- Grassland (starting zone)
- Dark Forest
- Stone Ridge
- Enemy Camp
- Swamp (Warden-gated)
- Coliseum (Tree A5-gated)
- Underground (Tree B5-gated)
- Lore Vaults (Tree C5-gated)

**Zone Mastery Tier Formula:**

```
ZONE_MASTERY_TIERS = [5, 15, 30, 60, 100]  # cumulative visit thresholds
```

| Tier | Visits Required | Bonus Granted |
|---|---|---|
| 1 | 5 | Resource node spawn rate in zone +10% |
| 2 | 15 | Enemy drop rate in zone +10% |
| 3 | 30 | Rare enemy variant unlocks in zone (higher loot quality) |
| 4 | 60 | One permanent chest spawns in zone each expedition |
| 5 | 100 | Zone boss spawns every 10 visits; drops guaranteed Legendary |

Zone Mastery is zone-specific and persists across Prestige. At Tier 5 on all 8 zones, a "World Master" title unlocks (cosmetic only).

### 6.2 Resource Mastery

Tracked per resource type. "Harvest" = one depletion of a node.

**Resource types:** Wood, Stone, Herb, Mushroom, Silk, Ore, Coal, Crystal, Hardwood, Mithril Ore (P1+), Void Crystal (P2+)

```
RESOURCE_MASTERY_TIERS = [10, 30, 75, 150, 300]  # cumulative harvests
```

| Tier | Harvests Required | Bonus Granted |
|---|---|---|
| 1 | 10 | Yield +1 unit per harvest of that type |
| 2 | 30 | 20% chance: double yield on any harvest |
| 3 | 75 | Unlock a crafting shortcut: this material counts as 1.5x in recipes |
| 4 | 150 | Auto-harvest: nodes of this type within 80px are collected without interaction |
| 5 | 300 | Mastered material: crafted items using this material gain +1 enhancement level free |

### 6.3 Enemy Mastery (Bestiary)

Tracked per enemy type. "Kill" = hero auto-attack kills (not archer kills).

**Enemy types:** Infantry, Archer, Cavalier, Healer, Boss (wave boss), Elite, Veteran (P1+), Corrupted (P2+)

```
ENEMY_MASTERY_TIERS = [10, 30, 75, 150, 300]  # cumulative kills
```

| Tier | Kills Required | Bonus Granted |
|---|---|---|
| 1 | 10 | +2% damage against this enemy type |
| 2 | 30 | +4% damage against this enemy type (total +6%) |
| 3 | 75 | Drop rate of this enemy's unique material +25% |
| 4 | 150 | Bestiary entry unlocked: enemy full stat sheet visible, weak spot noted |
| 5 | 300 | Signature bonus: enemy-type-specific unique effect (see below) |

**Tier 5 Signature Bonuses (enemy-specific):**

| Enemy Mastered | Tier 5 Bonus |
|---|---|
| Infantry | On kill: 10% chance to chain-kill adjacent Infantry instantly |
| Archer | Archer enemies' ranged attacks miss hero 20% of the time |
| Cavalier | Charge skill gains a secondary collision effect: knock-back all enemies in 80px of path |
| Healer | Hero kills Healers instantly if their HP is below 40% |
| Boss | Boss HP bars revealed from spawn (no fog of HP) |
| Elite | Elite drops always contain at least 1 Rare item |
| Veteran | Veteran kills grant double gold |
| Corrupted | Corrupted kills restore 5 mana |

---

## 7. NPC Affinity System

### 7.1 NPC Types

Six NPC types exist in the exploration map. Each has a unique role and affinity reward track.

| NPC | Location | Default Service |
|---|---|---|
| Blacksmith | Castle courtyard (always available) | Equipment enhancement |
| Merchant | Grassland / Stone Ridge | Buy/sell items for gold |
| Mage | Dark Forest (Arcane Scout preferred path) | Sell skill scrolls, Skill Shards |
| Elder | Village (near castle, Warden preferred path) | Quests, gold rewards |
| Wanderer | Random zone each expedition | One-time boons, lore hints |
| Arcanist | Lore Vault entrance (Tree C5-gated) | Legendary crafting recipes, Prestige Token exchange |

### 7.2 Affinity Levels (3 per NPC type)

Affinity is per NPC type, not per instance. All Blacksmiths in the world share the same Blacksmith affinity level.

```
AFFINITY_THRESHOLDS = [0, 10, 30]  # cumulative affinity points to reach tier 1, 2, 3
```

| Tier | Points Required | Name | Description |
|---|---|---|---|
| 0 | 0 | Stranger | Default relationship; standard prices |
| 1 | 10 | Acquaintance | NPCs acknowledge the player by name; small discount/bonus |
| 2 | 30 | Trusted | Expanded services and off-menu options unlocked |
| 3 | 60 | Bonded | Unique permanent bonus; NPC offers a quest that grants a Legendary item |

### 7.3 Building Affinity

Affinity is earned through interactions:

| Interaction | Affinity Points Earned |
|---|---|
| Use NPC's service (buy, enhance, quest complete) | +2 |
| Gift: Common item | +1 |
| Gift: Rare item | +3 |
| Gift: Epic item | +6 |
| Gift: Legendary item | +12 |
| Repeated visit without transacting (proximity scan INTERACT_RADIUS=90px) | +1 per visit (once per expedition) |
| Complete NPC's repeatable quest | +4 |

Gifts are given via the interact button (INTERACT_RADIUS = 90px, existing system). A "Gift" sub-option appears in the interact menu when the player has items in inventory. The gifted item is consumed permanently.

### 7.4 Affinity Rewards Per NPC

**Blacksmith:**

| Tier | Reward |
|---|---|
| 1 | Enhancement cost -20% for all items |
| 2 | Can enhance to +12 (normally capped at +10) |
| 3 | Forges one free +5 enhanced item per expedition (random slot, Rare quality) |

**Merchant:**

| Tier | Reward |
|---|---|
| 1 | Item sale prices +15% gold; purchase prices -10% |
| 2 | Stock expands: Merchant carries 1 Epic item per day (real-time daily refresh) |
| 3 | Trade Route: merchant delivers 20g to castle treasury per wave automatically |

**Mage:**

| Tier | Reward |
|---|---|
| 1 | Skill Shard prices -25% |
| 2 | Offers skill upgrade to Lv VI (bonus modifier variant — different from standard Lv V) |
| 3 | Once per expedition: grants a random skill scroll (any pool skill, free) |

**Elder:**

| Tier | Reward |
|---|---|
| 1 | Quest gold rewards +20% |
| 2 | Unlocks "Village Defense" quest: complete to gain +10 castle max HP permanently |
| 3 | Village sends an NPC archer to reinforce the castle formation once per expedition (free temp archer, 1 wave duration) |

**Wanderer:**

| Tier | Reward |
|---|---|
| 1 | Wanderer reveals one hidden zone node on minimap each expedition |
| 2 | Wanderer carries one consumable item for free each encounter |
| 3 | Wanderer joins expedition as ally: follows hero, auto-attacks enemies for 8 damage/s at 150px range |

**Arcanist:**

| Tier | Reward |
|---|---|
| 1 | Unlocks 3 additional Legendary recipes at crafting anvil |
| 2 | Soul Crystals can be purchased from Arcanist for 200g each |
| 3 | Reveals Mythic crafting recipe (requires 3 Soul Crystals + full Iron Phalanx set; produces unique Mythic item) |

---

## 8. GDScript Implementation Reference

### 8.1 Data Structures

All progression data is stored in a single autoload: `ProgressionManager`. It persists via `FileAccess` (post-MVP, replacing ADR-009's no-save policy — Prestige requires persistence). In MVP, these values are session-only.

```gdscript
# src/autoloads/progression_manager.gd
extends Node

## Hero identity
var hero_class: int = 0                   ## 0=Cavalier, 1=Warden, 2=Arcane Scout
var hero_level: int = 1
var hero_xp: int = 0
var evolution_tier_1: int = -1            ## Index of Lv10 evolution chosen (-1 = none)
var evolution_tier_2: int = -1            ## Lv25 evolution
var evolution_tier_3: int = -1            ## Lv40 Ascendant

## Passive tree
var skill_points_available: int = 0
var skill_points_spent: int = 0
var tree_nodes_unlocked: Array[bool] = []  ## 15 elements (A1-A5, B1-B5, C1-C5)

## Active skills
var skill_slot: Array[int] = [-1, -1, -1, -1]  ## Slot 0-3; -1 = empty; value = skill ID
var skill_levels: Array[int] = [1, 1, 1, 1]

## Equipment
var equipped_items: Array[Dictionary] = []  ## 6 slots, each: {slot, rarity, stats[], set_id, enhancement}

## Mastery
var zone_mastery: Dictionary = {}         ## {zone_id: visit_count}
var resource_mastery: Dictionary = {}     ## {resource_type: harvest_count}
var enemy_mastery: Dictionary = {}        ## {enemy_type: kill_count}

## NPC affinity
var npc_affinity: Dictionary = {}         ## {npc_type: affinity_points}

## Prestige
var prestige_tier: int = 0
var prestige_tokens: int = 0

## Computed: XP thresholds
const XP_PER_LEVEL: int = 50             ## Base XP per level
const XP_SCALE_PER_PRESTIGE: float = 1.20

func xp_required_for_level(lv: int) -> int:
    return roundi(float(XP_PER_LEVEL) * lv * pow(XP_SCALE_PER_PRESTIGE, prestige_tier))

## Computed: Hero stats (called by hero.gd on level-up or equipment change)
func compute_hp_max() -> int:
    var base: Array[int] = [50, 75, 35]
    var per_level: Array[int] = [4, 7, 3]
    var from_levels: int = base[hero_class] + (hero_level - 1) * per_level[hero_class]
    var from_equipment: int = _sum_equipment_stat("hp")
    var from_tree: int = _tree_bonus_hp()
    return from_levels + from_equipment + from_tree

func compute_atk() -> int:
    var base: Array[int] = [10, 7, 14]
    var per_level: Array[int] = [1, 1, 2]
    var from_levels: int = base[hero_class] + (hero_level - 1) * per_level[hero_class]
    var from_equipment: int = _sum_equipment_stat("atk")
    var from_tree: int = _tree_bonus_atk()
    return from_levels + from_equipment + from_tree

func compute_speed_mult() -> float:
    var base: Array[float] = [1.0, 0.7, 1.2]
    var mult: float = base[hero_class]
    mult *= _equipment_speed_mult()
    return mult

func compute_dmg_reduction() -> float:
    var from_tree: float = 0.05 if is_node_unlocked(6) else 0.0  ## B2
    var from_equipment: float = _sum_equipment_stat_float("dmg_reduction")
    return minf(from_tree + from_equipment, 0.50)  ## Soft cap 50%

func compute_range() -> float:
    var base: Array[float] = [130.0, 160.0, 200.0]
    return base[hero_class] + _sum_equipment_stat_float("range") + _tree_bonus_range()

## Tree node index mapping:
## A cluster: indices 0-4 (A1=0, A2=1, A3=2, A4=3, A5=4)
## B cluster: indices 5-9 (B1=5, B2=6, B3=7, B4=8, B5=9)
## C cluster: indices 10-14 (C1=10, C2=11, C3=12, C4=13, C5=14)
func is_node_unlocked(index: int) -> bool:
    if index < 0 or index >= tree_nodes_unlocked.size():
        return false
    return tree_nodes_unlocked[index]

func unlock_node(index: int) -> bool:
    if skill_points_available <= 0:
        return false
    if not _is_node_adjacent_to_unlocked(index):
        return false
    tree_nodes_unlocked[index] = true
    skill_points_available -= 1
    skill_points_spent += 1
    return true

## Mastery update helpers
func record_zone_visit(zone_id: String) -> void:
    zone_mastery[zone_id] = zone_mastery.get(zone_id, 0) + 1

func record_resource_harvest(resource_type: String) -> void:
    resource_mastery[resource_type] = resource_mastery.get(resource_type, 0) + 1

func record_enemy_kill(enemy_type: String) -> void:
    enemy_mastery[enemy_type] = enemy_mastery.get(enemy_type, 0) + 1

func get_zone_mastery_tier(zone_id: String) -> int:
    var visits: int = zone_mastery.get(zone_id, 0)
    var thresholds: Array[int] = [5, 15, 30, 60, 100]
    for i: int in range(thresholds.size() - 1, -1, -1):
        if visits >= thresholds[i]:
            return i + 1
    return 0

func get_resource_mastery_tier(resource_type: String) -> int:
    var harvests: int = resource_mastery.get(resource_type, 0)
    var thresholds: Array[int] = [10, 30, 75, 150, 300]
    for i: int in range(thresholds.size() - 1, -1, -1):
        if harvests >= thresholds[i]:
            return i + 1
    return 0

func get_enemy_mastery_tier(enemy_type: String) -> int:
    var kills: int = enemy_mastery.get(enemy_type, 0)
    var thresholds: Array[int] = [10, 30, 75, 150, 300]
    for i: int in range(thresholds.size() - 1, -1, -1):
        if kills >= thresholds[i]:
            return i + 1
    return 0

## Affinity helpers
const AFFINITY_THRESHOLDS: Array[int] = [10, 30, 60]

func add_affinity(npc_type: String, amount: int) -> void:
    npc_affinity[npc_type] = npc_affinity.get(npc_type, 0) + amount

func get_affinity_tier(npc_type: String) -> int:
    var pts: int = npc_affinity.get(npc_type, 0)
    for i: int in range(AFFINITY_THRESHOLDS.size() - 1, -1, -1):
        if pts >= AFFINITY_THRESHOLDS[i]:
            return i + 1
    return 0

## Prestige
func trigger_prestige() -> void:
    if hero_level < 50:
        return
    prestige_tier += 1
    prestige_tokens += 1
    hero_level = 1
    hero_xp = 0
    skill_points_available = 0
    skill_points_spent = 0
    tree_nodes_unlocked.fill(false)
    skill_slot = [-1, -1, -1, -1]
    skill_levels = [1, 1, 1, 1]
    ## Equipment, mastery, affinity, evolution: NOT reset
```

### 8.2 Skill Combo Detection

```gdscript
# src/gameplay/skill_combo_tracker.gd
extends Node

## Combo pairs: [skill_id_A, skill_id_B, combo_id]
const COMBOS: Array = [
    [2, 11, 0],   ## Frost Nova + Chain Lightning = Shatter Storm
    [0, 1, 1],    ## Charge + Shield Bash = Cavalry Break
    [6, 4, 2],    ## Earth Spike + Stone Wall = Fortress Rising
    [10, 8, 3],   ## Blink + Arcane Bolt = Phase Shot
    [3, 15, 4],   ## War Cry + Berserker Rage = Battle Frenzy
    [7, 13, 5],   ## Mending Touch + Iron Skin = Ironflesh
    [14, 12, 6],  ## Smoke Bomb + Blood Ritual = Shadow Pact
    [19, 18, 7],  ## Thunder Step + Nature's Grasp = Tempest Prison
]

const COMBO_WINDOW: float = 3.0

var _last_skill_used: int = -1
var _last_skill_time: float = 0.0

signal combo_triggered(combo_id: int)

func on_skill_used(skill_id: int) -> void:
    var now: float = Time.get_ticks_msec() / 1000.0
    if _last_skill_used >= 0 and (now - _last_skill_time) <= COMBO_WINDOW:
        for combo: Array in COMBOS:
            if (combo[0] == _last_skill_used and combo[1] == skill_id) or \
               (combo[1] == _last_skill_used and combo[0] == skill_id):
                combo_triggered.emit(combo[2])
                _last_skill_used = -1
                return
    _last_skill_used = skill_id
    _last_skill_time = now
```

### 8.3 Equipment Stat Computation

```gdscript
## Called by ProgressionManager._sum_equipment_stat()
func _sum_equipment_stat(stat_name: String) -> int:
    var total: int = 0
    for item: Dictionary in equipped_items:
        if item.is_empty():
            continue
        var enh_mult: float = 1.0 + item.get("enhancement", 0) * 0.08
        for roll: Dictionary in item.get("stats", []):
            if roll.get("stat") == stat_name:
                total += roundi(float(roll.get("value", 0)) * enh_mult)
    ## Check set bonuses
    total += _compute_set_bonuses_for_stat(stat_name)
    return total
```

### 8.4 Integration with Existing hero.gd

The existing hero.gd equipment bonus variables (`_atk_damage_bonus`, `_hp_max_bonus`, `_dmg_reduction`, `_atk_range_bonus`, `_speed_mult`) are already in place. They are populated by calling `ProgressionManager.compute_*()` at:

1. Session start (`_on_session_reset`)
2. Level-up events (`add_xp` when `new_level != _xp_level`)
3. Item equip/unequip events (new `equip_item()` signal from ProgressionManager)

The existing `XP_THRESHOLDS = [0, 30, 80]` and `LEVEL_NAMES` in hero.gd are MVP stubs. They are replaced by `ProgressionManager.xp_required_for_level(lv)` which scales to 50 levels and Prestige.

---

## 9. Balance Summary Table

| Parameter | Value | Rationale |
|---|---|---|
| Level cap | 50 | ~15-20 hours to reach legitimately; Prestige adds replayability |
| XP per enemy kill (hero) | 2 (existing) → scale by enemy tier | Infantry=2, Cavalier=4, Healer=6, Elite=10, Boss=25 |
| XP per resource harvest | 1 | Small but consistent reward for exploration |
| XP per wave cleared | 15 | Core TD loop still progresses hero |
| Skill Points total | 49 (Lv 2-50) | Can fill all 15 tree nodes and bank 34 SP |
| Banked SP use | Convert 5 SP → 1 Prestige-grade bonus node (post-cap, post Prestige) | Prevents SP feeling wasted |
| Items per expedition | ~5-8 drops expected | 30 enemies × ~20% drop rate average |
| Enhancement cost cap | +10 at 5 Scraps/level = 50 Scraps for Legendary | Gives crafting loop 10+ harvests of purpose |
| NPC affinity Tier 3 | 60 points | ~30 expeditions of consistent interaction |
| Zone Mastery Tier 5 | 100 visits | ~50 expeditions; long-term goal |
| Enemy Mastery Tier 5 | 300 kills | Possible mid-Prestige |
| Prestige trigger | Lv 50 | Voluntary; never forced |

---

## 10. Mobile UX Constraints Applied

All menus are designed for one-thumb portrait-landscape use at 960x540 viewport.

| System | Menu Pattern | Max Depth | Touch Target Min |
|---|---|---|---|
| Class selection | Full-screen card swipe (3 cards) | 1 screen | 200x300px card |
| Evolution fork | Overlay card at level-up | 1 tap confirm | 160x200px per option |
| Passive tree | Scrollable 3-column grid in pause menu | 2 taps (tap + confirm) | 96x96px per node |
| Skill equip | Bottom sheet, 3 skill slots shown | 2 taps | 80x80px per skill |
| Equipment | 6-slot grid, tap to view/equip | 2 taps | 80x80px per slot |
| Crafting | Material list → confirm button | 2 taps | Full-width confirm button |
| NPC affinity | Progress bar shown on NPC interact | 0 (passive display) | N/A |
| Mastery | Viewed in pause menu stats tab | 1 tap | N/A |
| Prestige | Confirmation dialog at Lv 50 | 2 taps (red confirm) | 120x60px confirm |

All menus use `CanvasLayer` with `layer = 2` (above HUD layer 1). All animations use `Tween` only (per ADR-007). No `AnimationPlayer` on CanvasLayer nodes.

---

## 11. Dependencies on Existing Systems

| Existing System | Dependency Type | What This Spec Adds |
|---|---|---|
| `hero.gd` | Extends | Level formula replaces `XP_THRESHOLDS`; stat vars populated by `ProgressionManager` |
| `game_state_machine.gd` | Reads | EXPLORING state guard on skill use; PLAYING state disables skill buttons |
| `economy.gd` | Reads | Gold checks for NPC shop purchases, gift transactions |
| `audio_manager.gd` | Extends | 4 new SFX channels: skill_cast, level_up, item_drop, combo_trigger |
| `resource_node.gd` | Extends | `record_resource_harvest()` call on depletion |
| `enemy.gd` / `rpg_enemy.gd` | Extends | `record_enemy_kill()` call on death; XP grant scaled by type |
| `healing_shrine.gd` | Extends | Adds affinity +1 to Mage on use; Battle Mage class gets +15 HP bonus |
| `treasure_chest.gd` | Extends | Item drop generation using rarity table |
| `crafting_anvil.gd` | Extends | Full crafting UI and enhancement flow |
| `main.gd` | Extends | Zone visit tracking on map node entry; NPC proximity scan extended with affinity UI |
| `hud.gd` | Extends | Skill button panel (3-4 buttons, EXPLORING only); XP bar; level display |
| `object_pool.gd` | Uses | Item drop orbs use pool (max 8 in flight, matches existing pattern) |
