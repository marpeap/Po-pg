# RPG Monde — Plan de Refonte Grandiose
# Session: 2026-05-25 — NE PAS SUPPRIMER

## Objectif validé par l'utilisateur
- Map 25x plus grande (48000×2160px, 15 zones)
- 65 ressources (35 communes + 15 rares + 10 légendaires + 5 épiques)
- NPCs aléatoires (marchands, ermites, quêtiers)
- Événements dynamiques (embuscades, spawns rares, caravanes)
- Grottes cachées (secrets, dopamine de découverte)
- Progression héros persistante (XP, niveaux, maîtrise de zone)
- Contrats de collecte (panneau à l'entrée)
- Menu principal avant le jeu
- Règle des 30 secondes (contenu visible en permanence)
- Ressources en tiers de rareté
- Densité × 25 : POI tous les ~200px

---

## STATUT DES FICHIERS (mettre à jour au fur et à mesure)

| # | Fichier | Action | Statut |
|---|---------|--------|--------|
| 1 | `src/autoloads/resource_inventory.gd` | RÉÉCRITURE — 65 ressources | DONE |
| 2 | `src/autoloads/hero_progression.gd` | CRÉATION — XP/niveaux/maîtrise | DONE |
| 3 | `src/ui/main_menu.gd` | CRÉATION — menu principal | DONE |
| 4 | `src/gameplay/npc_wanderer.gd` | CRÉATION — NPCs aléatoires | DONE |
| 5 | `src/gameplay/hidden_cave.gd` | CRÉATION — grottes secrètes | DONE |
| 6 | `src/gameplay/dynamic_event_manager.gd` | CRÉATION — événements | DONE |
| 7 | `src/gameplay/contract_board.gd` | CRÉATION — tableau contrats | DONE |
| 8 | `src/gameplay/resource_node.gd` | MISE À JOUR — rarités + 35 types communs | DONE |
| 9 | `src/gameplay/resource_node_timed.gd` | MISE À JOUR — 15 types rares | DONE |
| 10 | `src/scenes/exploration_map.gd` | RÉÉCRITURE COMPLÈTE — 48000×2160, 15 zones | DONE |
| 11 | `src/Main.gd` | MISE À JOUR — menu principal + hero progression | DONE |
| 12 | `project.godot` | MISE À JOUR — nouveaux autoloads | DONE |

---

## ARCHITECTURE DES 65 RESSOURCES

### COMMON (0–34) — 35 types
```
Zone A — Forêt de l'Éveil (x 0–3200):
  0  WOOD           Bois                  collecte instant
  1  HERB           Herbe                 collecte instant
  2  SILK           Soie                  collecte instant
  3  BIRCH_BARK     Écorce de Bouleau     collecte instant
  4  WILD_HONEY     Miel Sauvage          collecte instant
  5  ACORN          Gland                 collecte instant
  6  MOSS           Mousse                collecte instant
  7  WILD_BERRY     Baie Sauvage          collecte instant
  8  FEATHER        Plume                 drop ennemi
  9  RESIN          Résine                collecte instant

Zone B — Clairière Dorée (x 3200–6400):
  10 STONE          Pierre                collecte instant
  11 CLAY           Argile                collecte instant
  12 FLINT          Silex                 collecte instant
  13 LIMESTONE      Calcaire              collecte instant
  14 MUSHROOM       Champignon            collecte instant

Zone C — Ruines Ancestrales (x 6400–9600):
  15 IRON_ORE       Minerai de Fer        minage temporisé
  16 BONE           Os                    drop ennemi
  17 BRONZE_SCRAP   Éclat de Bronze       collecte instant
  18 ROPE_FIBER     Fibre de Corde        collecte instant
  19 CHARCOAL       Charbon de Bois       collecte instant

Zone D — Catacombes Oubliées (x 9600–12800):
  20 COAL           Charbon               minage temporisé
  21 SULFUR         Soufre                collecte instant
  22 QUARTZ         Quartz                minage temporisé
  23 ROCK_SALT      Sel Gemme             collecte instant

Zone E — Marécage Murmurant (x 12800–16000):
  24 REED           Roseau                collecte instant
  25 FROG_SKIN      Peau de Grenouille    drop ennemi
  26 ALGAE          Algues                collecte instant
  27 SWAMP_HERB     Herbe des Marais      collecte instant
  28 MUD_CLAY       Argile Boueuse        collecte instant

Zone F — Forêt de Cristal (x 16000–19200):
  29 GLOWING_MUSHROOM Champignon Lumineux collecte instant
  30 GNARLED_ROOT   Racine Noueuse        collecte instant
  31 CLIMBING_VINE  Liane Grimpante       collecte instant

Zone G–I (Ash/Fire/Ice):
  32 ASH            Cendre                collecte instant
  33 BLACK_SOIL     Terre Noire           collecte instant
  34 DEAD_WOOD      Bois Mort             collecte instant
```

### RARE (35–49) — 15 types
```
  35 HARDWOOD       Bois Dur              minage (arbres anciens)
  36 CRYSTAL        Cristal               minage temporisé
  37 GEMSTONE       Gemme Précieuse       minage (rare)
  38 HIDE           Cuir                  drop cavalier/élite
  39 SHADOW_ESSENCE Essence d'Ombre       drop boss seulement
  40 SILVER_LICHEN  Lichen Argenté        grottes secrètes
  41 GHOST_MUSHROOM Champignon Fantôme    zone hantée
  42 GOLDEN_SAP     Sève Dorée            arbres anciens rares
  43 SNAKE_SCALE    Écaille de Serpent    drop serpent géant
  44 ICE_CRYSTAL    Cristal de Glace      zone glacée
  45 LAVA_FLOWER    Fleur de Lave         zone volcanique
  46 STAR_DUST      Poussière d'Étoile    zone sacrée (nuit)
  47 GOLEM_EYE      Oeil de Golem         drop golem
  48 WIND_ESSENCE   Essence des Vents     pics éthérés
  49 VOID_SHARD     Éclat du Néant        zone temple interdit
```

### LEGENDARY (50–59) — 10 types
```
  50 ADAMANTITE     Adamantite            forge légendaire
  51 MYTHRIL        Mythril               cime sacrée seulement
  52 MOONSTONE      Pierre de Lune        grottes nocturnes
  53 DRAGON_HEART   Coeur de Dragon       drop boss dragon
  54 ETERNAL_ESSENCE Essence Éternelle    zone temple
  55 TIME_FRAGMENT  Fragment du Temps     événement rare
  56 GODS_TEAR      Larme des Dieux       sanctuaire sacré
  57 PRIMAL_FLAME   Flamme Primordiale    gouffre de feu
  58 CRYSTALLIZED_SHADOW Ombre Cristallisée nécropole
  59 GOLDEN_DAWN    Aube Dorée            cime sacrée
```

### EPIC (60–64) — 5 types
```
  60 WORLD_CORE     Noyau du Monde        boss final zone 15
  61 VOID_BREATH    Souffle du Néant      boss néant
  62 TITAN_BLOOD    Sang des Titans       boss titan
  63 ANCIENT_RUNE   Rune Ancienne         coffre légendaire caché
  64 CHAOS_ESSENCE  Essence du Chaos      événement chaos (extrêmement rare)
```

---

## ARCHITECTURE DE LA MAP (48000×2160)

### 15 Zones (3200px chacune)
```
Zone  1 — Forêt de l'Éveil       x    0– 3200  vert clair    difficulté 1
Zone  2 — Clairière Dorée        x 3200– 6400  jaune doré    difficulté 1
Zone  3 — Ruines Ancestrales     x 6400– 9600  ocre brun     difficulté 2
Zone  4 — Catacombes Oubliées    x 9600–12800  gris sombre   difficulté 2
Zone  5 — Marécage Murmurant     x12800–16000  vert sombre   difficulté 3
Zone  6 — Forêt de Cristal       x16000–19200  bleu-vert     difficulté 3
Zone  7 — Plaines de Cendres     x19200–22400  gris cendre   difficulté 4
Zone  8 — Gouffre de Feu         x22400–25600  rouge lava    difficulté 4
Zone  9 — Toundra Glacée         x25600–28800  blanc-bleu    difficulté 5
Zone 10 — Pics Éthérés           x28800–32000  violet pâle   difficulté 5
Zone 11 — Forêt Hantée           x32000–35200  violet sombre difficulté 6
Zone 12 — Nécropole              x35200–38400  gris-violet   difficulté 6
Zone 13 — Désert d'Os            x38400–41600  beige mort    difficulté 7
Zone 14 — Temple Interdit        x41600–44800  or-noir       difficulté 7
Zone 15 — Cime Sacrée            x44800–48000  blanc brillant difficulté 8
```

### 3 Voies d'exploration
```
Voie haute  y = 720   (ressources rares, plus dangereux)
Voie centre y = 1080  (chemin principal, commun)
Voie basse  y = 1440  (ressources mixtes, ennemis latéraux)
```

### Densité de contenu (règle des 30 secondes)
```
Par zone (3200px ÷ 200px/POI = 16 slots horizontaux × 3 voies = 48 POI max par zone)
Répartition cible par zone:
  - 12–18 noeuds ressources instant
  -  4–8  noeuds ressources temporisés
  -  1–3  camps ennemis
  -  1–2  sanctuaires de soin
  -  0–1  enclume de forge
  -  3–6  objets interactifs cachés (ruines, coffres, inscriptions)
  -  1–3  fragments de lore
  -  1–2  secrets (grottes, passages)
  -  Zone-specific: arbres, rochers, décorations (non-interactifs mais visuellement riches)
```

---

## SYSTÈME NPC (npc_wanderer.gd)

### 5 types de NPCs
```
MERCHANT    — Marchand ambulant: vend 3 ressources rares contre or
QUEST_GIVER — Voyageur perdu: donne une quête simple (rapporter X ressources)
HERMIT      — Ermite sage: caché en grotte, buff permanent unique par session
REFUGEE     — Réfugié: révèle camp caché, fuite animation
GUARD       — Garde de caravane: escorte héros 60s, réduit dégâts ennemis
```

### Placement
- 3–5 NPCs par session, positions aléatoires (seed = frame count au chargement)
- Chaque NPC a une hitbox Area2D + sprite Kenney + label flottant
- Dialogue via popup Label (pas de UI complexe)
- Marchand: fenêtre de commerce simplifiée (3 offres fixes)

---

## SYSTÈME ÉVÉNEMENTS DYNAMIQUES (dynamic_event_manager.gd)

### Timer: déclenche un événement aléatoire toutes les 90–180 secondes

### 7 types d'événements
```
AMBUSH          — Groupe 3–5 ennemis attaque le héros (combat → or)
RARE_SPAWN      — Ennemi légendaire apparaît 60s avec drop spécial
MERCHANT_CARAVAN — Caravane traverse la map, 45s pour commercer
MYSTIC_AURORA   — Zone F–H: rendement cristal doublé 120s
CAMP_RAID       — Camp envoie patrouille vers les noeuds proches
EARTH_TREMOR    — Fait apparaître 3 noeuds de ressources rares temporaires
BLESSING_RAIN   — Pluie dorée: tous les noeuds régénèrent 1 fois
```

---

## GROTTES CACHÉES (hidden_cave.gd)

### 8 grottes par session, positions fixes mais contenu variable
```
Zones 3, 4, 6, 8, 9, 11, 13, 14
Chaque grotte:
  - Entrée: rochers qui semblent normaux mais ont une Area2D de détection
  - À 40px de l'entrée: CanvasItem change (légère lueur)
  - Intérieur: 1–3 ressources rares/légendaires + 1 NPC possible
  - Premier accès: enregistré dans HeroProgression.discoveries_found
  - Récompense: +50 XP héros + ressources
```

---

## PROGRESSION HÉROS (hero_progression.gd)

### Persistance: ConfigFile (post-MVP, stage Release)
```gdscript
var hero_level: int = 1          # 1–50
var hero_xp: int = 0
var xp_per_level: Array = [...]  # courbe exponentielle
var zone_mastery: Array[int]     # [0]*15 — fois qu'on a complété la zone
var discoveries_found: int = 0   # grottes découvertes / 8
var permanent_bonuses: Dictionary = {
    "collect_radius_bonus": 0.0,   # +10% par niveau de maîtrise
    "rare_chance_bonus": 0.0,      # chance drop rare accrue
    "hero_speed_bonus": 0.0,       # vitesse héros
    "xp_multiplier": 1.0,          # multiplicateur XP
}
```

### XP par action
```
Collecte common:    +2 XP
Collecte rare:      +5 XP
Collecte legendary: +15 XP
Collecte epic:      +40 XP
Camp nettoyé:       +30 XP
Grotte découverte:  +50 XP
Quête complétée:    +25 XP
Événement survécu:  +10 XP
```

---

## TABLEAU DE CONTRATS (contract_board.gd)

### Panneau à l'entrée de la map (x=200, y=1080)
- 3 contrats aléatoires par session (seed basé sur GameStateMachine session count)
- Chaque contrat: [ressource_type, quantité, récompense_or]
- Exemple: "5 Herbes → 80 or", "2 Cristaux → 150 or", "1 Gemme → 300 or"
- Rendu: label + progress bar + bouton "Remettre" (actif si quantité atteinte)
- Auto-complète si ressources suffisantes

---

## MENU PRINCIPAL (main_menu.gd)

### Structure visuelle
```
- Fond: ColorRect noir + particules ambiantes (Sprite2D animés)
- Titre: "GARRISON" — label grand format, couleur dorée
- Sous-titre: "Défends. Explore. Conquiers."
- Boutons:
    [NOUVELLE PARTIE]  — démarre une session fraîche
    [CONTINUER]        — reprend (visible si HeroProgression.hero_level > 1)
    [OPTIONS]          — volume, langue (placeholder pour l'instant)
- Bas: version + crédits minimaux
- Animation: pulse léger sur le titre (Tween sin)
```

### Intégration dans Main.gd
```
- Main.tscn démarre sur MainMenu (CanvasLayer layer=10)
- [NOUVELLE PARTIE] → hide MainMenu → démarrer GameStateMachine PLAYING
- [CONTINUER] → idem mais avec HeroProgression chargé
```

---

## PLAN D'IMPLÉMENTATION (ordre strict)

### PHASE 1 — Fondations (à faire EN PREMIER)
```
[1] resource_inventory.gd  — 65 types + SHORT_NAMES + RARITIES
[2] hero_progression.gd    — nouveau autoload (XP, niveaux, ConfigFile)
[3] project.godot           — ajouter HeroProgression autoload
```

### PHASE 2 — Noeuds de ressources
```
[4] resource_node.gd       — support 35 types communs + rarité visuelle
[5] resource_node_timed.gd — support 10+ types (IRON_ORE, COAL, CRYSTAL, GEMSTONE, HARDWOOD + nouveaux)
```

### PHASE 3 — Systèmes RPG
```
[6] npc_wanderer.gd        — 5 types NPC, dialogue, commerce
[7] hidden_cave.gd         — grottes avec détection entrée + intérieur
[8] dynamic_event_manager.gd — 7 types événements, timer
[9] contract_board.gd      — 3 contrats par session
```

### PHASE 4 — Map et Menu
```
[10] exploration_map.gd    — RÉÉCRITURE COMPLÈTE (48000×2160, 15 zones, procédural)
[11] main_menu.gd          — menu avec titre + boutons
[12] Main.gd               — intégration menu + hero progression + nouveaux systèmes
```

---

## NOTES TECHNIQUES IMPORTANTES

### Performance (Compatibility renderer, mobile Android)
- Tous les sprites hors caméra ne sont PAS rendus par Godot (frustum culling auto)
- MAIS les nodes Area2D ont _process() actif → limiter les _process() aux nodes proches
- Solution: désactiver _process() sur les nodes à > 2000px du héros
  → ExplorationMap._process() gère un "chunk actif" de ±2000px autour du héros
- Total sprites: ~800 sprites × 15 zones = 12000 sprites → ok pour Godot/GL Compat
- Total Area2D interactifs: ~300 → ok

### Compatibilité avec l'existant
- ResourceInventory.Type enum: les INDEX changent (WOOD=0 reste, mais MUSHROOM passe de 3 à 14)
  → Tous les fichiers qui utilisent ResourceInventory.Type.MUSHROOM doivent être mis à jour
  → Fichiers concernés: resource_node.gd, exploration_map.gd, item_inventory.gd, crafting_system.gd
- Le pont TD→RPG dans Main._do_return() utilise des types spécifiques → mettre à jour les indices

### Sprites disponibles (Kenney Medieval RTS)
- Environment: env_01 à env_21 (arbres, rochers, campfires, etc.)
- Structure: str_01 à str_23 (tentes, arches, ruines, etc.)
- Pour les nouvelles zones (glace, feu, désert): utiliser modulate coloré sur sprites existants
  → Glace: rock.png + Color(0.6, 0.85, 1.0)
  → Lave: rock.png + Color(1.1, 0.4, 0.1)
  → Cendre: env_08 + Color(0.5, 0.5, 0.5)

---

## FICHIERS EXISTANTS À NE PAS TOUCHER
- src/autoloads/game_state_machine.gd (OK tel quel)
- src/autoloads/audio_manager.gd (OK tel quel)
- src/autoloads/item_inventory.gd (vérifier compatibilité après resource_inventory changement)
- src/gameplay/hero.gd (OK tel quel)
- src/gameplay/castle.gd (OK tel quel)
- src/gameplay/enemy*.gd (OK tel quel)
- src/gameplay/economy.gd (OK tel quel)
- src/gameplay/forge.gd (OK tel quel)
- src/ui/hud.gd (à mettre à jour légèrement pour hero level)

---

## REPRISE APRÈS INTERRUPTION
Si le contexte est perdu, lire ce fichier + production/session-state/active.md
puis reprendre au prochain fichier TODO dans le tableau STATUT.
