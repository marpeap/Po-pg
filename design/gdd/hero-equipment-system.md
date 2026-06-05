# GDD — Hero Equipment System
**Status**: Designed
**Version**: 1.0
**Date**: 2026-05-25
**Author**: Research synthesis — Garrison design team

---

## 1. Overview

The Hero Equipment System extends the existing `ItemInventory` and `hero.gd` stat fields into a fully structured slot-based equipment framework. The hero has **4 persistent equipment slots** (Weapon, Armor, Ring, Charm) each holding one item at a time, with **3 tiers per slot** (Commun / Rare / Epique). Items are obtained via three routes: crafting at the anvil, looting from treasure chests, and buying from a merchant NPC. The UI is a compact bottom-right panel usable with one thumb in landscape, consistent with the existing HUD layout. All stat application and removal is handled by a new `EquipmentManager` autoload that calls into the existing hero stat fields.

---

## 2. Player Fantasy

The player feels their cavalier hero growing stronger across exploration runs. Each crafted or looted item is a visible, named upgrade with an immediate, readable effect. Swapping items is a satisfying decision ("do I take the Blade of Venom or the Crystal Staff for this next wave?"). The four-slot layout is scannable in one glance — no scrolling, no menus within menus. Arriving at the forge with rare materials and knowing exactly what legendary item you are building creates anticipation.

---

## 3. Slot Design — Why 4 Slots

### Mobile constraint analysis
Kingdom Rush Frontiers uses hero level + ability upgrades, not gear slots, keeping its UI minimal. Clash Royale-style games use card decks rather than equipment. For Garrison's TD/RPG hybrid on a 960×540 landscape screen with one-thumb play, the sweet spot identified through research and the existing codebase analysis is **4 slots**:

- Fewer than 4 (e.g., 2) feels underdeveloped given the existing resource richness (65 resource types, 27 crafted items).
- More than 4 (e.g., 6+) requires scrolling or a dedicated screen — incompatible with one-thumb touch in the HUD.
- 4 slots fit cleanly in a 2×2 grid within a ~200×120px panel in the bottom-right, reachable by right thumb.

### The 4 Slots

| Slot | Internal ID | Stat domain | Flavor |
|------|-------------|-------------|--------|
| Weapon | `WEAPON` | `_atk_damage_bonus`, `_atk_range_bonus`, `_spell_dmg_mult` | What the hero attacks with |
| Armor | `ARMOR` | `_hp_max_bonus`, `_dmg_reduction`, `_regen_rate` | How the hero survives |
| Ring | `RING` | `_speed_mult`, `_atk_range_bonus` (secondary) | Passive mobility / utility |
| Charm | `CHARM` | `_spell_dmg_mult`, `_regen_rate` (secondary), special passive | Magical passive |

Each slot holds exactly one item at a time. Equipping a new item **unequips the previous one** (stats are removed then the new item's stats are applied). Unequipped items return to a session stash (not lost).

---

## 4. Item Tiers

Three tiers per slot. Tier 1 items can be crafted early with common resources. Tier 2 requires rare resources or boss drops. Tier 3 requires legendary/epic resources and is intentionally rare.

| Tier | Name | Color code | Rarity label | Acquisition |
|------|------|-----------|--------------|-------------|
| 1 | Commun | Gray `Color(0.78, 0.78, 0.78)` | Commun | Craft (common resources) |
| 2 | Rare | Green `Color(0.20, 0.85, 0.35)` | Rare | Craft (rare resources) OR chest drop |
| 3 | Epique | Purple `Color(0.85, 0.30, 1.00)` | Epique | Craft (legendary/epic resources) OR boss chest |

These match the existing `ResourceInventory.RARITY_COLORS` palette for visual consistency.

---

## 5. Complete Item List

### 5.1 Weapon Slot (12 items — 4 per tier, 3 weapon archetypes)

Items in this slot replace the existing `hero_weapon` variable in `ItemInventory`. The IRON_SWORD, CRYSTAL_STAFF, BONE_BOW, and VENOM_BLADE from the current system become **Tier 1 Weapon** items — they are preserved with the same behavior but now slotted properly.

#### Tier 1 — Commun

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `IRON_SWORD` | Épée de Fer | ATK +5; frappe arc 60° (jusqu'à 3 ennemis à 40% dégâts) | `_atk_damage_bonus += 5` |
| `BONE_BOW` | Arc en Os | Portée +70px (130→200px) | `_atk_range_bonus += 70.0` |
| `VENOM_BLADE` | Lame de Venin | Attaques empoisonnent la cible principale (3/s, 4s) | Special (checked in `_try_auto_attack`) |
| `CRYSTAL_STAFF` | Bâton de Cristal | Sorts +30% DMG | `_spell_dmg_mult += 0.30` |

#### Tier 2 — Rare

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `HUNTERS_CROSSBOW` | Arbalète du Chasseur | ATK +10; portée +50px; aucun effet de zone | `_atk_damage_bonus += 10`, `_atk_range_bonus += 50.0` |
| `SHADOW_DAGGER` | Dague d'Ombre | ATK +8; vitesse d'attaque ×1.30 (cooldown ÷1.30) | `_atk_damage_bonus += 8` + `ATK_COOLDOWN` override |
| `FROST_WAND` | Baguette de Givre | Sorts +55% DMG; attaques ralentissent (factor=0.35, 2s) | `_spell_dmg_mult += 0.55` + slow on hit |
| `SERPENT_BLADE` | Lame Serpentine | ATK +12; poison renforcé (5/s, 6s) | `_atk_damage_bonus += 12` + enhanced poison |

#### Tier 3 — Epique

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `DRAGONBONE_SWORD` | Épée d'Os de Dragon | ATK +25; frappe arc 90° (jusqu'à 5 ennemis) | `_atk_damage_bonus += 25` |
| `MYTHRIL_BOW` | Arc en Mythril | Portée +150px; ATK +15; ignore l'armure | `_atk_damage_bonus += 15`, `_atk_range_bonus += 150.0` |
| `VOID_STAFF` | Bâton du Néant | Sorts +100% DMG; portée sorts +80px | `_spell_dmg_mult += 1.00` |
| `CHAOS_BLADE` | Lame du Chaos | ATK +20; 20% chance de double-frappe | `_atk_damage_bonus += 20` + double-hit passive |

---

### 5.2 Armor Slot (12 items — 4 per tier, 3 armor archetypes)

Items in this slot replace the existing `hero_armor` variable. HIDE_JERKIN, SILK_CLOAK, CRYSTAL_AMULET, SHADOW_MAIL become **Tier 1 Armor** items.

#### Tier 1 — Commun

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `HIDE_JERKIN` | Veste de Cuir | HP max +20 | `_hp_max_bonus += 20` |
| `SILK_CLOAK` | Cape de Soie | Rayon aggro ennemis -35% (furtivité) | `_stealth = 0.35` |
| `CRYSTAL_AMULET` | Amulette de Cristal | Regen 1 HP toutes les 4s | `_regen_rate = 1.0` |
| `SHADOW_MAIL` | Armure d'Ombre | Dégâts reçus -40% | `_dmg_reduction = 0.40` |

#### Tier 2 — Rare

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `SCALE_ARMOR` | Armure d'Écailles | HP max +40; dégâts reçus -20% | `_hp_max_bonus += 40`, `_dmg_reduction = 0.20` |
| `GHOST_SHROUD` | Linceul Fantôme | Furtivité -60%; regen 1 HP toutes 3s | `_stealth = 0.60`, `_regen_rate = 1.0` (3s tick) |
| `MOONSTONE_VEST` | Veste en Pierre de Lune | HP max +30; sorts: cooldown -15% | `_hp_max_bonus += 30` + spell cooldown |
| `IRON_PLATE` | Plaque de Fer | Dégâts reçus -55%; vitesse -15% | `_dmg_reduction = 0.55`, `_speed_mult *= 0.85` |

#### Tier 3 — Epique

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `DRAGON_SCALE_MAIL` | Armure Écailles de Dragon | HP max +80; dégâts reçus -60% | `_hp_max_bonus += 80`, `_dmg_reduction = 0.60` |
| `ETERNAL_ROBE` | Robe Éternelle | Regen 3 HP/s (tick 1s); furtivité -40% | `_regen_rate = 3.0`, `_stealth = 0.40` |
| `VOID_PLATE` | Plaque du Néant | HP max +60; immunité poison; dégâts -50% | `_hp_max_bonus += 60`, `_dmg_reduction = 0.50`, `_poison_immune = true` |
| `TITAN_ARMOR` | Armure des Titans | HP max +100; dégâts reçus -45%; vitesse -10% | `_hp_max_bonus += 100`, `_dmg_reduction = 0.45`, `_speed_mult *= 0.90` |

---

### 5.3 Ring Slot (9 items — 3 per tier)

The Ring slot is new — no current equivalent in `ItemInventory`. Rings focus on mobility and utility. Rings that affect `_atk_range_bonus` stack additively with Weapon bonuses.

#### Tier 1 — Commun

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `SWIFT_RING` | Anneau de Vivacité | Vitesse +20% | `_speed_mult *= 1.20` |
| `SCOUT_RING` | Anneau d'Éclaireur | Portée auto-attaque +40px | `_atk_range_bonus += 40.0` |
| `STONE_RING` | Anneau de Pierre | HP max +15 | `_hp_max_bonus += 15` |

#### Tier 2 — Rare

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `WIND_RING` | Anneau des Vents | Vitesse +40% | `_speed_mult *= 1.40` |
| `FAR_SIGHT_RING` | Anneau de Clairvoyance | Portée +80px; portée sorts +60px | `_atk_range_bonus += 80.0` |
| `IRON_WILL_RING` | Anneau de Volonté | HP max +35; dégâts reçus -10% | `_hp_max_bonus += 35`, `_dmg_reduction` additive +0.10 |

#### Tier 3 — Epique

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `VOID_RING` | Anneau du Néant | Vitesse +60%; portée +100px | `_speed_mult *= 1.60`, `_atk_range_bonus += 100.0` |
| `TITAN_RING` | Anneau des Titans | HP max +60; vitesse +25% | `_hp_max_bonus += 60`, `_speed_mult *= 1.25` |
| `CHAOS_RING` | Anneau du Chaos | Vitesse +30%; sorts +40% DMG; portée +50px | `_speed_mult *= 1.30`, `_spell_dmg_mult += 0.40`, `_atk_range_bonus += 50.0` |

---

### 5.4 Charm Slot (9 items — 3 per tier)

The Charm slot is new. Charms focus on spell amplification and passive specials that do not fit cleanly into weapon or armor archetypes.

#### Tier 1 — Commun

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `HERB_CHARM` | Charme aux Herbes | Regen 1 HP toutes 6s | `_regen_rate = 1.0` (6s tick) |
| `FOCUS_CHARM` | Charme de Concentration | Sorts +20% DMG | `_spell_dmg_mult += 0.20` |
| `BONE_CHARM` | Charme en Os | Drops ennemis +1 ressource (passif) | Special (applied in loot_drop.gd) |

#### Tier 2 — Rare

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `CRYSTAL_CHARM` | Charme de Cristal | Sorts +45% DMG; regen 1 HP/4s | `_spell_dmg_mult += 0.45`, `_regen_rate = 1.0` |
| `SHADOW_CHARM` | Charme d'Ombre | Furtivité -50%; sorts +30% DMG | `_stealth = 0.50`, `_spell_dmg_mult += 0.30` |
| `GOLDEN_CHARM` | Charme Doré | +5g par ennemi tué par le héros (exploration) | Special (signal to Economy) |

#### Tier 3 — Epique

| ID | Name (FR) | Effect | `hero.gd` fields modified |
|----|-----------|--------|--------------------------|
| `DRAGON_CHARM` | Charme du Dragon | Sorts +80% DMG; 15% chance de double-sort | `_spell_dmg_mult += 0.80` + double-cast passive |
| `ETERNAL_CHARM` | Charme Éternel | Regen 3 HP/s; sorts +50% DMG | `_regen_rate = 3.0`, `_spell_dmg_mult += 0.50` |
| `WORLD_CHARM` | Charme du Monde | Toutes stats héros +15% (multiplicateur global) | All stats ×1.15 (applied last) |

---

## 6. Item Acquisition

### 6.1 Crafting (Anvil)
All Tier 1 items are craftable from common resources. Tier 2 requires rare resources. Tier 3 requires legendary or epic resources. Recipes follow the same structure as `CraftingSystem.RECIPES`.

| Tier | Example recipe cost |
|------|---------------------|
| T1 | 2-4 common resources |
| T2 | 2-3 rare resources + 1-2 common |
| T3 | 1-2 legendary + 1 epic OR 2 legendary |

### 6.2 Treasure Chests
Chests from clearing RPG enemy camps currently grant only gold. Extended: chests have a weighted loot table that can also drop equipment items.

```
Camp chest (standard):   80% gold, 15% T1 item, 5% T2 item
Elite camp chest:        50% gold, 35% T2 item, 15% T3 item
Boss chest:              20% gold, 40% T2 item, 40% T3 item
```

Item slot dropped is random (uniform across 4 slots). Item within the dropped tier is random (uniform within that slot's tier items).

### 6.3 Merchant NPC (future — not MVP)
A wandering merchant NPC (extends `npc_wanderer.gd`) sells T1 and T2 items for gold. Not implemented in this sprint — placeholder for future session.

---

## 7. UI Panel Design

### 7.1 Layout (landscape 960×540, right-thumb reach)

The Equipment Panel is a `CanvasLayer` (layer=2, above the existing HUD layer=1) opened by tapping an "EQUIP" button added to the existing HUD bottom-right button column. It slides in from the right edge.

```
+------------------------------------------+
|  EQUIPEMENT                           [X] |
|                                           |
|  [ARME]        [ARMURE]                   |
|  Icon 64×64    Icon 64×64                 |
|  Name          Name                       |
|  Tier badge    Tier badge                 |
|                                           |
|  [ANNEAU]      [CHARME]                   |
|  Icon 64×64    Icon 64×64                 |
|  Name          Name                       |
|  Tier badge    Tier badge                 |
|                                           |
|  [Gérer l'inventaire] (opens item picker) |
+------------------------------------------+
```

- Panel size: 340×240px
- Position: right=0, bottom=0 of viewport (960×540)
- Each slot is a 64×64 touchable button with a colored border (gray/green/purple by tier)
- Empty slot shows a faint slot icon (sword outline, shield outline, ring outline, star outline)
- Tapping a filled slot opens the item detail popup (name, full description, stats, [Retirer] button)
- Tapping an empty slot opens the item picker filtered to that slot

### 7.2 Item Picker (sub-panel)
```
+---------------------------------------+
|  ARME — Choisir                   [X] |
|  +--------+ +--------+ +--------+     |
|  |Épée Fer| |Arc Os  | |Lame Ven|     |
|  |T1 gray | |T1 gray | |T1 gray |     |
|  +--------+ +--------+ +--------+     |
|  +--------+                           |
|  |Bâton C.|                           |
|  |T1 gray |                           |
|  +--------+                           |
|  (owned items only, scrollable)        |
+---------------------------------------+
```

- Shows only items the player owns (`ItemInventory._crafted[id] == true` or `_found[id] == true`)
- Currently-equipped item has a gold border
- Tapping an unequipped owned item immediately swaps (old item unequipped, new equipped, stats updated)
- No drag-and-drop: tap-to-equip only (one-thumb safe)

### 7.3 Touch ergonomics
- All tap targets minimum 56×56 px (Android recommendation: 48dp)
- Panel is anchored bottom-right — right thumb reaches all slots without repositioning
- The [X] close button is top-right (reachable with right index or left thumb)
- Scroll within item picker is vertical swipe only (standard)
- Panel opens with a 0.15s slide-in Tween (no AnimationPlayer — ADR-007)

---

## 8. Stat Application Rules

### 8.1 Additive stacking
Multiple items can affect the same stat. Application is always **additive** for flat bonuses and **multiplicative** for multipliers, in this order:

1. Base stat from `hero.gd` constants
2. `+ flat bonuses` from all equipped items (`_atk_damage_bonus`, `_hp_max_bonus`, `_atk_range_bonus`)
3. `× multipliers` from all equipped items (`_speed_mult`, `_spell_dmg_mult`)

### 8.2 `_dmg_reduction` cap
`_dmg_reduction` is capped at `0.80` (80%) regardless of stacking. Enforced in `EquipmentManager.apply_item()`.

### 8.3 `_regen_rate` — tick resolution
Multiple items with regen choose the **shortest tick interval** (fastest regen wins, not additive). Regen amount = sum of all regen items' per-tick values. Example: Crystal Amulet (1 HP / 4s) + Crystal Charm (1 HP / 4s) = 2 HP / 4s tick.

### 8.4 Session persistence
Equipment is session-scoped (same as `ItemInventory`). On `session_reset`:
- All equipped slots are cleared
- All stat bonuses from equipment are removed from hero
- Inventory of owned items is also cleared (consistent with existing ADR-009 behavior)

---

## 9. GDScript Data Structures

### 9.1 Slot enum (add to `EquipmentManager` or `ItemInventory`)

```gdscript
enum Slot {
    WEAPON = 0,
    ARMOR  = 1,
    RING   = 2,
    CHARM  = 3,
}

const SLOT_COUNT := 4
const SLOT_NAMES: Array[String] = ["Arme", "Armure", "Anneau", "Charme"]
```

### 9.2 Item tier enum

```gdscript
enum Tier {
    COMMUN = 0,
    RARE   = 1,
    EPIQUE = 2,
}

const TIER_COLORS: Array[Color] = [
    Color(0.78, 0.78, 0.78),  ## COMMUN — gris
    Color(0.20, 0.85, 0.35),  ## RARE   — vert
    Color(0.85, 0.30, 1.00),  ## EPIQUE — violet
]

const TIER_NAMES: Array[String] = ["Commun", "Rare", "Epique"]
```

### 9.3 Item definition dictionary structure

```gdscript
## Each entry in EQUIPMENT_DB:
## {
##   "id":          int,            ## unique ID (continue from ITEM_COUNT=27)
##   "name":        String,         ## French display name
##   "slot":        Slot,           ## which slot this belongs to
##   "tier":        Tier,           ## rarity tier
##   "description": String,         ## French one-line description for UI
##   "icon":        String,         ## res:// path to 32×32 icon sprite
##   "stats": {                     ## stat deltas applied on equip, removed on unequip
##       "atk_damage_bonus":  int,
##       "atk_range_bonus":   float,
##       "hp_max_bonus":      int,
##       "dmg_reduction":     float,
##       "regen_rate":        float,
##       "regen_interval":    float, ## seconds between regen ticks (default 4.0)
##       "speed_mult":        float, ## multiplied into _speed_mult (1.0 = no change)
##       "spell_dmg_mult":    float, ## added to _spell_dmg_mult (0.0 = no change)
##       "stealth":           float, ## aggro radius reduction fraction
##   },
##   "passive":     String,         ## optional passive ID for special logic ("IRON_SWORD_AOE", "VENOM", etc.)
##   "craft_recipe": Array,         ## [[ResourceInventory.Type, amount], ...] — empty if not craftable
##   "level_req":   int,            ## HeroProgression.hero_level required to equip
## }
```

### 9.4 Partial EQUIPMENT_DB (representative entries)

```gdscript
## In equipment_manager.gd (new autoload):
const EQUIPMENT_DB: Array[Dictionary] = [

    ## ── WEAPON T1 ─────────────────────────────────────────────────────────
    {
        "id": 100, "name": "Épée de Fer", "slot": Slot.WEAPON, "tier": Tier.COMMUN,
        "description": "ATK +5. Frappe 3 ennemis en arc 60°.",
        "icon": "res://assets/sprites/items/weapon_iron_sword.png",
        "stats": { "atk_damage_bonus": 5, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "IRON_SWORD_AOE",
        "craft_recipe": [[3, 3], [6, 1]],  ## IRON_ORE×3, COAL×1
        "level_req": 1,
    },
    {
        "id": 101, "name": "Arc en Os", "slot": Slot.WEAPON, "tier": Tier.COMMUN,
        "description": "Portée auto-attaque +70px.",
        "icon": "res://assets/sprites/items/weapon_bone_bow.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 70.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[0, 2], [10, 2]],  ## WOOD×2, BONE×2
        "level_req": 1,
    },
    {
        "id": 102, "name": "Lame de Venin", "slot": Slot.WEAPON, "tier": Tier.COMMUN,
        "description": "Attaques empoisonnent (3/s, 4s).",
        "icon": "res://assets/sprites/items/weapon_venom_blade.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "VENOM",
        "craft_recipe": [[5, 1], [3, 2]],  ## IRON_ORE×1, MUSHROOM×2
        "level_req": 1,
    },
    {
        "id": 103, "name": "Bâton de Cristal", "slot": Slot.WEAPON, "tier": Tier.COMMUN,
        "description": "Sorts +30% DMG.",
        "icon": "res://assets/sprites/items/weapon_crystal_staff.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.30, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[7, 2], [8, 1]],  ## CRYSTAL×2, GEMSTONE×1
        "level_req": 1,
    },

    ## ── WEAPON T2 ─────────────────────────────────────────────────────────
    {
        "id": 104, "name": "Arbalète du Chasseur", "slot": Slot.WEAPON, "tier": Tier.RARE,
        "description": "ATK +10. Portée +50px.",
        "icon": "res://assets/sprites/items/weapon_crossbow.png",
        "stats": { "atk_damage_bonus": 10, "atk_range_bonus": 50.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[9, 2], [5, 2]],  ## HARDWOOD×2, IRON_ORE×2
        "level_req": 5,
    },
    {
        "id": 105, "name": "Dague d'Ombre", "slot": Slot.WEAPON, "tier": Tier.RARE,
        "description": "ATK +8. Vitesse d'attaque ×1.30.",
        "icon": "res://assets/sprites/items/weapon_shadow_dagger.png",
        "stats": { "atk_damage_bonus": 8, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "FAST_ATTACK_1_30",
        "craft_recipe": [[12, 2], [5, 1]],  ## SHADOW_ESSENCE×2, IRON_ORE×1
        "level_req": 5,
    },

    ## ── WEAPON T3 ─────────────────────────────────────────────────────────
    {
        "id": 106, "name": "Épée d'Os de Dragon", "slot": Slot.WEAPON, "tier": Tier.EPIQUE,
        "description": "ATK +25. Frappe 5 ennemis en arc 90°.",
        "icon": "res://assets/sprites/items/weapon_dragonbone_sword.png",
        "stats": { "atk_damage_bonus": 25, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "AOE_90_5",
        "craft_recipe": [[54, 1], [51, 1]],  ## DRAGON_HEART×1, ADAMANTITE×1
        "level_req": 15,
    },

    ## ── ARMOR T1 ──────────────────────────────────────────────────────────
    {
        "id": 110, "name": "Veste de Cuir", "slot": Slot.ARMOR, "tier": Tier.COMMUN,
        "description": "HP max +20.",
        "icon": "res://assets/sprites/items/armor_hide_jerkin.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 20,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[11, 3]],  ## HIDE×3
        "level_req": 1,
    },
    {
        "id": 111, "name": "Armure d'Ombre", "slot": Slot.ARMOR, "tier": Tier.COMMUN,
        "description": "Dégâts reçus -40%.",
        "icon": "res://assets/sprites/items/armor_shadow_mail.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.40, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[12, 2], [11, 2]],  ## SHADOW_ESSENCE×2, HIDE×2
        "level_req": 1,
    },

    ## ── RING T1 ───────────────────────────────────────────────────────────
    {
        "id": 120, "name": "Anneau de Vivacité", "slot": Slot.RING, "tier": Tier.COMMUN,
        "description": "Vitesse +20%.",
        "icon": "res://assets/sprites/items/ring_swift.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.20, "spell_dmg_mult": 0.0, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[4, 2], [19, 1]],  ## SILK×2, RESIN×1
        "level_req": 1,
    },

    ## ── CHARM T1 ──────────────────────────────────────────────────────────
    {
        "id": 130, "name": "Charme de Concentration", "slot": Slot.CHARM, "tier": Tier.COMMUN,
        "description": "Sorts +20% DMG.",
        "icon": "res://assets/sprites/items/charm_focus.png",
        "stats": { "atk_damage_bonus": 0, "atk_range_bonus": 0.0, "hp_max_bonus": 0,
                   "dmg_reduction": 0.0, "regen_rate": 0.0, "regen_interval": 4.0,
                   "speed_mult": 1.0, "spell_dmg_mult": 0.20, "stealth": 0.0 },
        "passive": "",
        "craft_recipe": [[7, 1], [2, 1]],  ## CRYSTAL×1, HERB×1
        "level_req": 1,
    },
]
```

---

## 10. EquipmentManager Autoload — Full Interface

### 10.1 File: `src/autoloads/equipment_manager.gd`

```gdscript
## EquipmentManager — Autoload singleton
## Manages the 4 hero equipment slots (WEAPON / ARMOR / RING / CHARM).
## Applies and removes stat effects on hero.gd when items are swapped.
## Integrates with ItemInventory (ownership) and HeroProgression (level gates).
## Session-scoped: all slots cleared on session_reset.
extends Node

enum Slot { WEAPON = 0, ARMOR = 1, RING = 2, CHARM = 3 }
enum Tier { COMMUN = 0, RARE = 1, EPIQUE = 2 }

const SLOT_COUNT := 4
const SLOT_NAMES: Array[String] = ["Arme", "Armure", "Anneau", "Charme"]

const TIER_COLORS: Array[Color] = [
    Color(0.78, 0.78, 0.78),
    Color(0.20, 0.85, 0.35),
    Color(0.85, 0.30, 1.00),
]
const TIER_NAMES: Array[String] = ["Commun", "Rare", "Epique"]

## Currently equipped item ID per slot (-1 = empty).
var _equipped: Array[int] = [-1, -1, -1, -1]

## Items owned this session but not currently equipped (stash).
## Array of item IDs.
var _stash: Array[int] = []

## Reference to hero node — set once by Main.gd after scene ready.
var _hero: Node = null

## Emitted when any slot changes (for UI refresh).
signal slot_changed(slot: int, item_id: int)
## Emitted when an item is added to stash.
signal stash_changed()

func _ready() -> void:
    GameStateMachine.session_reset.connect(_on_session_reset)

## Called by Main.gd once hero node is available.
func set_hero(hero_node: Node) -> void:
    _hero = hero_node

## Attempt to equip [param item_id] into its designated slot.
## If the slot is occupied, the old item is moved to stash.
## Returns false if player does not own the item or level requirement not met.
func equip(item_id: int) -> bool:
    var item: Dictionary = _find_item(item_id)
    if item.is_empty():
        return false
    ## Level gate
    if HeroProgression.hero_level < item.get("level_req", 1):
        return false
    ## Ownership check — must be in stash OR currently in any slot
    if not _owns(item_id):
        return false
    var slot: int = item["slot"]
    ## Unequip current occupant into stash
    var current: int = _equipped[slot]
    if current != -1:
        _remove_stats(current)
        _stash.append(current)
        _equipped[slot] = -1
    ## Remove from stash if it was there
    _stash.erase(item_id)
    ## Apply new item
    _equipped[slot] = item_id
    _apply_stats(item_id)
    slot_changed.emit(slot, item_id)
    stash_changed.emit()
    return true

## Unequip item in [param slot], move it to stash.
func unequip(slot: int) -> void:
    var current: int = _equipped[slot]
    if current == -1:
        return
    _remove_stats(current)
    _equipped[slot] = -1
    _stash.append(current)
    slot_changed.emit(slot, -1)
    stash_changed.emit()

## Add an item to stash (called when crafted or found in chest).
## If the relevant slot is empty, auto-equips.
func receive_item(item_id: int) -> void:
    var item: Dictionary = _find_item(item_id)
    if item.is_empty():
        return
    var slot: int = item["slot"]
    if _equipped[slot] == -1:
        ## Auto-equip into empty slot
        _equipped[slot] = item_id
        _apply_stats(item_id)
        slot_changed.emit(slot, item_id)
    else:
        _stash.append(item_id)
        stash_changed.emit()

## Returns the item ID currently in [param slot], or -1 if empty.
func get_equipped(slot: int) -> int:
    if slot < 0 or slot >= SLOT_COUNT:
        return -1
    return _equipped[slot]

## Returns all item IDs in stash for [param slot] (for item picker UI).
func get_stash_for_slot(slot: int) -> Array[int]:
    var result: Array[int] = []
    for id: int in _stash:
        var item: Dictionary = _find_item(id)
        if not item.is_empty() and item["slot"] == slot:
            result.append(id)
    return result

## Returns the full item dictionary for [param item_id], or empty dict.
func get_item(item_id: int) -> Dictionary:
    return _find_item(item_id)

## ── Private ──────────────────────────────────────────────────────────────

func _owns(item_id: int) -> bool:
    if item_id in _stash:
        return true
    for id: int in _equipped:
        if id == item_id:
            return true
    return false

func _find_item(item_id: int) -> Dictionary:
    for item: Dictionary in EQUIPMENT_DB:
        if item["id"] == item_id:
            return item
    return {}

func _apply_stats(item_id: int) -> void:
    if _hero == null:
        return
    var item: Dictionary = _find_item(item_id)
    if item.is_empty():
        return
    var s: Dictionary = item["stats"]
    _hero._atk_damage_bonus += s.get("atk_damage_bonus", 0)
    _hero._atk_range_bonus  += s.get("atk_range_bonus", 0.0)
    _hero._hp_max_bonus     += s.get("hp_max_bonus", 0)
    ## dmg_reduction: additive, capped at 0.80
    _hero._dmg_reduction = minf(_hero._dmg_reduction + s.get("dmg_reduction", 0.0), 0.80)
    ## regen_rate: additive; regen_interval: take the minimum
    var new_regen: float = s.get("regen_rate", 0.0)
    if new_regen > 0.0:
        _hero._regen_rate += new_regen
        ## regen_timer uses _hero._regen_timer internally — interval managed there
    ## speed_mult: multiplicative
    _hero._speed_mult *= s.get("speed_mult", 1.0)
    ## spell_dmg_mult: additive bonus on top of base 1.0
    _hero._spell_dmg_mult += s.get("spell_dmg_mult", 0.0)
    _hero._stealth = maxf(_hero._stealth, s.get("stealth", 0.0))

func _remove_stats(item_id: int) -> void:
    if _hero == null:
        return
    var item: Dictionary = _find_item(item_id)
    if item.is_empty():
        return
    var s: Dictionary = item["stats"]
    _hero._atk_damage_bonus -= s.get("atk_damage_bonus", 0)
    _hero._atk_range_bonus  -= s.get("atk_range_bonus", 0.0)
    _hero._hp_max_bonus     -= s.get("hp_max_bonus", 0)
    _hero._dmg_reduction     = maxf(_hero._dmg_reduction - s.get("dmg_reduction", 0.0), 0.0)
    var old_regen: float = s.get("regen_rate", 0.0)
    if old_regen > 0.0:
        _hero._regen_rate = maxf(_hero._regen_rate - old_regen, 0.0)
    var old_speed_mult: float = s.get("speed_mult", 1.0)
    if old_speed_mult != 1.0:
        _hero._speed_mult = maxf(_hero._speed_mult / old_speed_mult, 1.0)
    _hero._spell_dmg_mult = maxf(_hero._spell_dmg_mult - s.get("spell_dmg_mult", 0.0), 1.0)
    ## stealth: recompute from all remaining equipped items
    _recompute_stealth()

func _recompute_stealth() -> void:
    if _hero == null:
        return
    var max_stealth: float = 0.0
    for id: int in _equipped:
        if id == -1:
            continue
        var item: Dictionary = _find_item(id)
        if not item.is_empty():
            max_stealth = maxf(max_stealth, item["stats"].get("stealth", 0.0))
    _hero._stealth = max_stealth

func _on_session_reset() -> void:
    ## Remove stats from all equipped items before clearing
    for id: int in _equipped:
        if id != -1:
            _remove_stats(id)
    _equipped = [-1, -1, -1, -1]
    _stash.clear()
    for s: int in range(SLOT_COUNT):
        slot_changed.emit(s, -1)
    stash_changed.emit()
```

---

## 11. Integration with hero.gd

### 11.1 Changes required in `hero.gd`

No structural changes to the stat variable declarations are needed — all 9 stat fields already exist. The only additions:

1. Add `_poison_immune` to the reset block (already declared, not yet reset):
   ```gdscript
   ## In _on_session_reset():
   _poison_immune = false
   ```

2. The existing `_try_auto_attack()` method checks `ItemInventory.has_item(ItemInventory.Item.VENOM_BLADE)` for the poison effect. This must be extended to also check the new equipment slot:
   ```gdscript
   ## Replace the VENOM_BLADE check with:
   var weapon_id: int = EquipmentManager.get_equipped(EquipmentManager.Slot.WEAPON)
   var weapon_item: Dictionary = EquipmentManager.get_item(weapon_id)
   var weapon_passive: String = weapon_item.get("passive", "")
   if weapon_passive in ["VENOM", "SERPENT_VENOM"] and nearest.has_method("apply_poison"):
       nearest.apply_poison(3.0, 4.0)
   if weapon_passive in ["IRON_SWORD_AOE", "AOE_90_5"]:
       ## existing AoE cone logic, parameterized by passive
       pass
   ```

3. The `_spell_dmg_mult` field: currently written as a flat multiplier used in `hero_spells.gd`. EquipmentManager adds to it additively on top of the base `1.0`. Ensure `hero_spells.gd` reads `_spell_dmg_mult` from the hero node (already the case based on existing code pattern).

### 11.2 Changes required in `ItemInventory`

The current `receive_item()` auto-equips weapons (id 0-3) and armor (id 4-7) by setting `hero_weapon`/`hero_armor` integers. Going forward:

- Items with IDs 100+ are **equipment system items** routed to `EquipmentManager.receive_item()`.
- Items with IDs 0-26 remain in the legacy `ItemInventory` path (backward-compatible with existing crafting system, archer buffs, castle buffs, consumables).
- The transition plan: when the crafting system adds T2/T3 hero weapons/armors (IDs 100+), they route through `EquipmentManager`. The old T1 items (IDs 0-7) can either remain as-is or be migrated in a future sprint. No breaking change required in this sprint.

```gdscript
## In ItemInventory.receive_item(), add at the top:
if item_id >= 100:
    EquipmentManager.receive_item(item_id)
    return
## ... existing logic for ids 0-99 unchanged
```

### 11.3 Changes required in `Main.gd`

After hero node is available in `_setup_gameplay_nodes()`, register it:
```gdscript
## After _hero is created:
EquipmentManager.set_hero(_hero)
```

### 11.4 Changes required in `CraftingSystem.gd`

Add T2/T3 equipment recipes to `RECIPES` array, using IDs 100+. Category 0 = weapon, category 1 = armor, plus two new categories: 6 = ring, 7 = charm.

```gdscript
## Example addition to RECIPES:
{
    "id": 104,  ## HUNTERS_CROSSBOW
    "name": "Arbalète du Chasseur",
    "category": 0,
    "description": "ATK +10. Portée +50px.",
    "ingredients": [
        [ResourceInventory.Type.HARDWOOD, 2],
        [ResourceInventory.Type.IRON_ORE, 2],
    ],
},
```

---

## 12. Loot Drop Integration (Chest Items)

Extend `TreasureChest.gd` to support equipment item drops:

```gdscript
## In treasure_chest.gd:
## setup() gains an optional parameter:
func setup(world_pos: Vector2, gold_amount: int, loot_item_id: int = -1) -> void:
    _gold = gold_amount
    _loot_item_id = loot_item_id
    ## ...

## In _collect():
func _collect() -> void:
    if not _active:
        return
    _active = false
    input_pickable = false
    if _gold > 0:
        collected.emit(_gold)
    if _loot_item_id >= 100:
        EquipmentManager.receive_item(_loot_item_id)
        item_found.emit(_loot_item_id)
    ## ... animation
```

Loot table logic lives in `rpg_enemy_camp.gd` which spawns chests. The weighted roll:
```gdscript
## In rpg_enemy_camp.gd, _spawn_chest():
func _roll_chest_loot(is_boss: bool) -> int:
    var roll: float = randf()
    var gold_threshold: float = 0.80 if not is_boss else 0.20
    if roll < gold_threshold:
        return -1  ## gold only
    ## Pick a tier
    var tier_roll: float = randf()
    var tier: int
    if is_boss:
        tier = EquipmentManager.Tier.EPIQUE if tier_roll < 0.40 else EquipmentManager.Tier.RARE
    else:
        tier = EquipmentManager.Tier.RARE if tier_roll < 0.05 else EquipmentManager.Tier.COMMUN
    ## Pick a random slot
    var slot: int = randi() % EquipmentManager.SLOT_COUNT
    ## Pick a random item matching slot and tier from EQUIPMENT_DB
    var candidates: Array[int] = []
    for item: Dictionary in EquipmentManager.EQUIPMENT_DB:
        if item["slot"] == slot and item["tier"] == tier:
            candidates.append(item["id"])
    if candidates.is_empty():
        return -1
    return candidates[randi() % candidates.size()]
```

---

## 13. Icon Assets

### Recommended source (CC0)
**OpenGameArt.org** — search for:
- "16x16 Weapon RPG Icons" (CC0) — swords, bows, staffs, daggers
- "CC0 Headgear Icons" / "CC0 Torso Wear Icons" — armor sprites
- "RPG items (Pixel art)" by OpenGameArt contributors

**Kenney.nl** — "RPG Pack" or "Game Icons" (CC0, commercial-friendly):
- URL: `https://kenney.nl/assets`
- The "Tiny Dungeon" sheet (already used for chest.png and shrine.png) contains small weapon/armor icons at 16×16 that can be upscaled to 32×32 for item slots.

### Recommended pipeline
1. Crop individual 16×16 tiles from the Kenney Tiny Dungeon sheet.
2. Import to Godot at 32×32 (nearest-neighbor filter, no mipmaps — pixel art).
3. Name: `weapon_iron_sword.png`, `armor_hide_jerkin.png`, `ring_swift.png`, `charm_focus.png`, etc.
4. Path: `res://assets/sprites/items/`
5. For slots with no icon yet: use a placeholder 32×32 ColorRect-generated texture at runtime.

---

## 14. Formulas

### Effective ATK Damage
```
effective_atk = ATK_DAMAGE + _atk_damage_bonus
```
where `ATK_DAMAGE = 10` (const in hero.gd), `_atk_damage_bonus` is sum of all equipped items' `atk_damage_bonus`.

### Effective ATK Range
```
effective_range = ATK_RANGE + _atk_range_bonus
```
where `ATK_RANGE = 130.0` (const in hero.gd).

### Effective Speed
```
effective_speed = HERO_SPEED × _speed_mult
```
where `HERO_SPEED = 200.0`. Multipliers from multiple items compound: if Ring gives ×1.20 and Charm gives ×1.30, total `_speed_mult = 1.20 × 1.30 = 1.56`.

### Effective Spell DMG
```
effective_spell_mult = _spell_dmg_mult
```
Base value is `1.0` (no bonus). Each item adds its `spell_dmg_mult` value additively: Crystal Staff +0.30 and Focus Charm +0.20 = `_spell_dmg_mult = 1.50`.

### Effective Damage Received
```
final_damage = max(1, round(raw_damage × (1.0 - _dmg_reduction)))
```
`_dmg_reduction` capped at 0.80. Already implemented in `hero.gd.take_damage()`.

### Regen HP per second
```
hp_per_tick = _regen_rate
tick_interval = 4.0   ## seconds (hardcoded in hero.gd _process)
```
Multiple regen items add their `_regen_rate` values. The tick interval is fixed at 4s in the current implementation.

---

## 15. Edge Cases

| Scenario | Resolution |
|----------|------------|
| Player equips T3 item before level requirement | `EquipmentManager.equip()` returns `false`; item stays in stash; UI shows "Niveau X requis" |
| Two items both set `_dmg_reduction` | Values add, cap at 0.80 |
| Two items both set `_speed_mult` | Values multiply (compound) |
| Item removed when hero has 0 HP at that moment | Stats remove cleanly regardless; HP floor already enforced by `take_damage()` |
| Stash full (no cap defined) | No cap — stash is unbounded in session |
| Item found in chest that player already has | Goes to stash as a second copy (stash allows duplicates) |
| `_hero` is null when stat apply called | `_apply_stats()` / `_remove_stats()` guard with `if _hero == null: return` |
| Session reset while item equipped | `_on_session_reset()` calls `_remove_stats()` for each equipped slot before clearing |

---

## 16. Dependencies

- `hero.gd` — stat fields read and written
- `ItemInventory` (autoload) — ownership for items 0-99; routing for items 100+
- `HeroProgression` (autoload) — `hero_level` read for level gate
- `ResourceInventory` (autoload) — ingredient spending for crafting
- `CraftingSystem.gd` — recipe definitions for T1/T2/T3 equipment
- `crafting_anvil.gd` / `crafting_ui.gd` — UI entry point for crafting
- `TreasureChest.gd` — loot drop acquisition
- `rpg_enemy_camp.gd` — chest spawning with loot roll
- `GameStateMachine` (autoload) — `session_reset` signal subscription
- `AudioManager` (autoload) — equip/unequip SFX
- `Main.gd` — `EquipmentManager.set_hero()` call after scene setup

---

## 17. Tuning Knobs

| Parameter | Current value | Purpose |
|-----------|--------------|---------|
| T1 weapon ATK bonus range | +5 to +0 | Flat damage feel at low levels |
| T3 weapon ATK bonus cap | +25 | Ensure TD remains playable (hero not overpowered) |
| `_dmg_reduction` cap | 0.80 | Prevent immortality |
| Chest drop rates | 80/15/5% T1/T2/T3 | Pacing |
| Level requirements | T1=1, T2=5, T3=15 | Progression gate |
| Regen tick interval | 4s | Tunable in hero.gd `_regen_timer` reset |
| Speed mult cap | None (compound) | Monitor for runaway values |

---

## 18. Acceptance Criteria

| # | Criterion | Test type |
|---|-----------|-----------|
| AC-EQ-01 | Equipping an armor item raises `_hp_max_bonus` by the item's value; unequipping removes it | Unit test |
| AC-EQ-02 | Equipping a second armor into the same slot unequips the first and moves it to stash | Unit test |
| AC-EQ-03 | `_dmg_reduction` never exceeds 0.80 when two dmg_reduction items are equipped | Unit test |
| AC-EQ-04 | `_speed_mult` compounds correctly: two ×1.20 items yield `_speed_mult = 1.44` | Unit test |
| AC-EQ-05 | `EquipmentManager.equip()` returns false when `HeroProgression.hero_level < level_req` | Unit test |
| AC-EQ-06 | `session_reset` clears all 4 slots, removes all stat bonuses from hero, clears stash | Unit test |
| AC-EQ-07 | Equipment UI panel opens via "EQUIP" button, shows all 4 slots, closes via X | Manual walkthrough |
| AC-EQ-08 | Item picker shows only owned items for the selected slot | Manual walkthrough |
| AC-EQ-09 | Boss chest can drop a T3 item; standard chest cannot drop T3 | Unit test (loot roll distribution) |
| AC-EQ-10 | Existing T1 items (IRON_SWORD etc. ids 0-7) continue to work unchanged after integration | Regression — existing GUT tests pass |

---

*Sources consulted: OpenGameArt.org CC0 collections, RPGHQ forum discussions on gear slot count, Kingdom Rush Frontiers hero system documentation, Game UI Database mobile patterns, GameDev.net equipment slot design thread.*
