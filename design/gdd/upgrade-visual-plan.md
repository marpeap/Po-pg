# Plan d'Améliorations Visuelles & Performance — Garrison
> Dernière mise à jour : 2026-06-05
> Ce document est la référence de planification pour tous les systèmes d'upgrade visuels et de performance.
> Ne pas coder avant validation de l'ensemble du plan.

---

## Philosophie des Tiers

Le jeu progresse à travers **4 paliers visuels** qui traversent plusieurs genres artistiques de manière assumée.
Le mélange est intentionnel : le contraste entre le médiéval de départ et le cosmique final doit surprendre et délectr le joueur.

| Palier | Nom | Genre visuel | Déclencheur TD | Déclencheur RPG |
|--------|-----|-------------|----------------|-----------------|
| **T0** | Médiéval Classique | Actuel — bois, pierre, tissu, tons bruns chauds | Vagues 1–9 | Niveau 1–9 |
| **T1** | Fantastique Runique | Magie médiévale — runes dorées, lueurs bleues/violettes, auras | Vague 10+ | Niveau 10+ |
| **T2** | Chibi Steampunk | Personnages miniatures expressifs, rouages, tuyaux, palette vive saturée | Vague 25+ | Niveau 25+ |
| **T3** | Néo-Cosmique | Mécha, hologrammes, plasma néon, IA, palette cyan/violet sur fond sombre | Vague 50+ | Niveau 50 (max) |

**Règle d'or** : chaque tier doit être **immédiatement lisible** à 80×80 px sur mobile.
**Règle de mixité** : un composant peut avoir T1 fantastique + T2 sci-fi — les genres ne doivent pas forcément suivre la même progression entre composants.

---

## Sources de Sprites Recommandées

### Gratuits CC0 (Kenney.nl)
| Pack | Contenu utile | URL |
|------|--------------|-----|
| Fantasy Town Kit | Bâtiments médiévaux–fantastiques | kenney.nl/assets/fantasy-town-kit |
| Tiny Dungeon | Tuiles RPG, objets, monstres | kenney.nl/assets/tiny-dungeon |
| Sci-Fi RTS | Unités sci-fi, bâtiments | kenney.nl/assets/sci-fi-rts |
| Robots | Sprites robots isométriques | kenney.nl/assets/robots |
| Creatures | Monstres et ennemis variés | kenney.nl/assets/creatures |
| Fantasy Characters | Héros, NPCs médiévaux | kenney.nl/assets/fantasy-characters |
| RPG Urban Kit | Environnement RPG top-down | kenney.nl/assets/rpg-urban-kit |

### Payants / Itch.io recommandés
| Pack | Style | Prix | URL |
|------|-------|------|-----|
| Sprout Lands (LimeZu) | Chibi top-down très expressif | ~$6 | limezu.itch.io/sproutlands |
| Tiny Swords (Pixel Frog) | Médié-fantastique top-down HD | ~$10 | pixelfrog.itch.io/tiny-swords |
| Aekashics Liberated Pixel Cup | Sprites monstres variés CC0 | Gratuit | opengameart.org/users/aekashics |
| DungeonTileset II (0x72) | Donjon top-down CC0 | Gratuit | 0x72.itch.io/dungeontileset-ii |
| Fantasy RPG Characters (Szadi) | Personnages RPG animés | ~$5 | szadiart.itch.io |

### Icons HUD (game-icons.net, CC BY 3.0)
Toutes les icônes référencées ci-dessous sont disponibles via :
`https://game-icons.net/icons/ffffff/transparent/1x1/{author}/{name}.png`

---

## MODE TD — Tower Defense

### 1. Héros (Commandant de Garnison)

**Rôle actuel** : Cavalier médiéval sur cheval brun, 3 sorts (Feu/Éclair/Glace), navigation joystick.

| Tier | Nom | Description Visuelle | Bonus Stats | Icon HUD | Source Sprite |
|------|-----|---------------------|-------------|----------|--------------|
| **T0** | Cavalier Médiéval | Cheval brun, épée courte, armure de plates basique, cape grenat | — (baseline) | `lorc/horseman` | Actuel `hero_0-3.png` |
| **T1** | Paladin Solaire | Armure dorée ciselée, cape blanche lumineuse, cheval blanc avec sabots qui brillent, halo discret | +15% vitesse, sorts +20% puissance | `lorc/crowned-heart` | Kenney Fantasy Characters + recolor or Tiny Swords |
| **T2** | Chevalier-Automate | Armure steampunk cuivrée avec rouages apparents, lunettes goggle, monture mi-cheval mi-mécanique, fumée | +30% vitesse, sorts +40% puissance, +1 sort slot | `lorc/clockwork` | Szadi Art "Steampunk Characters" |
| **T3** | Commandant Néo-Synthétique | Silhouette élancée en armure holographique bleue/cyan, monture drone quadrupède, trace lumineuse derrière lui | +50% vitesse, sorts +80% puissance, +2 sorts, sorts traversent ennemis | `lorc/megabot` | Commissionner ou générer via IA img |

**Détails sorts par tier :**
- T0 : Feu (boule), Éclair (arc), Glace (cône)
- T1 : Feu (tempête de flammes), Éclair (chaîne qui rebondit), Glace (mur de glace)
- T2 : Feu (bombe à fragmentation), Éclair (grille tesla), Glace (ralentissement de zone + cristallisation)
- T3 : Plasma (AOE), Singularité (aspire ennemis), Gel quantique (freeze temporel)

---

### 2. Archers de Formation

**Rôle actuel** : 2–4 archers stationnés sur les tours (T0: médiéval, T1: police, T2: soldat, T3: commando). Déjà 4 tiers de skin mais sans progression de stats côté formation.

| Tier | Nom | Description Visuelle | Bonus Stats | Icon HUD | Source Sprite |
|------|-----|---------------------|-------------|----------|--------------|
| **T0** | Archers Médiévaux | Archer bois (vert), tunique de cuir, arc en bois, 2 par formation min | — (baseline) | `lorc/bowman` | Actuel `archer_0-3.png` |
| **T1** | Gardes Elfiques | Silhouettes fines, oreilles pointues, arc en corne enchantée brillante, flèches lumineuses, tunique verte/dorée | Flèches pénètrent 1 ennemi, +20% portée, +15% dmg | `lorc/elf` (si dispo) ou `lorc/wing-cloak` | Tiny Swords "Elf Archer" ou Kenney Fantasy |
| **T2** | Tireurs Chibi | Petits soldats ronds expressifs (style chibi), casque rond, fusil laser court, expressions faciales visibles | Tirs en rafale (3 projectiles), +40% cadence, traçantes colorées | `lorc/cog` (tech) | LimeZu Sprout Lands – warriors |
| **T3** | Drones Autonomes | Sphères flottantes dorées/bleues avec oeil central, pas de jambes, lévitent autour de la tour, faisceau laser continu | Laser continu (DPS), +100% portée, tourelle 360°, self-repair | `lorc/android-mask` | Kenney Robots pack + recolor |

**Note UX** : Les archers de formation et de tour partagent le même sprite pool. Le tier de la tour (`_tier`) détermine quel set d'archers afficher.

---

### 3. Tours d'Archers

**Rôle actuel** : 4 tiers déjà implémentés (Bois, Pierre, Fer, Forteresse). Ce plan enrichit chaque tier avec des effets visuels et des visuels de structure plus distincts.

| Tier | Nom | Structure Visuelle | Effets Visuels | Bonus Stats | Icon HUD | Source Sprite |
|------|-----|--------------------|---------------|-------------|----------|--------------|
| **T0** | Plateforme de Bois | Rondins empilés, planches horizontales, look rustique | Aucun | — (baseline) | `lorc/wooden-fence` | Actuel `tower_tier_0.png` |
| **T1** | Bastille de Pierre | Maçonnerie grise, meurtrières, créneaux simples, banner flottant | Particules de poussière à l'impact | +50 portée, +10% dmg | `lorc/guarded-tower` | Tiny Swords "Tower" ou Kenney Fantasy Town |
| **T2** | Tour de Fer Steampunk | Métal riveté, engrenage visible en rotation lente, baliste automatique, tuyaux de vapeur | Fumée blanche des tuyaux, baliste animée | +150 portée, +25% dmg, +1 archer | `lorc/cogsplosion` | Kenney Sci-fi RTS + recolor métal |
| **T3** | Citadelle Plasma | Structure cristalline noire, noyau d'énergie violet pulsant, 4 tourelles rotatives, halo | Champ de force visible, éclairs ambiants, lueur violette | +300 portée, +50% dmg, +2 archers, AoE | `lorc/tesla-coil` | Asset original / commissionner |

**Effet de pouvoir par tier + power active :**
- FIRE active : flammes ondulantes sur la tour (particules rouges/orange)
- LIGHTNING active : arcs électriques courant sur les murs
- WATER active : givre sur les créneaux, condensation au sol

---

### 4. Château (Base à Défendre)

**Rôle actuel** : Structure fixe gauche-centre, prend des dégâts, HP bar dans HUD. Sprite `castle.png` basique.

| Tier | Nom | Description Visuelle | Indicateur Santé | Bonus | Icon HUD | Source Sprite |
|------|-----|---------------------|-----------------|-------|----------|--------------|
| **T0** | Forteresse Médiévale | Donjon en pierre grise, 2 tours, porte en bois | Porte s'effrite, pierre craquelée (overlays) | — | `lorc/white-tower` | Actuel `castle.png` |
| **T1** | Château Enchanté | Pierre lumineuse, runes dorées sur les murs, bannières animées aux couleurs de la guilde, cristaux aux tourelles | Runes s'éteignent progressivement selon les HP | +20 HP max, regen +50% | `lorc/heart-tower` | Kenney Fantasy Town Kit – Castle |
| **T2** | Forteresse Mécano | Acier riveté, canons automatiques (décoratifs), tourelles rotatrices, portes hydrauliques | Canons endommagés tombent progressivement | +50 HP max, regen passive, repair drone autour | `lorc/gears` | Kenney Sci-fi RTS – Fortress |
| **T3** | Station Orbitale Ancrée | Structure en métal sombre avec dome d'énergie bleu pulsant, plateformes lévitantes, hologrammes décoratifs | Dome s'amincit selon HP (anim shader) | +100 HP max, bouclier absorbe 10% dégâts, regen élevée | `lorc/processor` | Asset original / génération IA |

---

### 5. Ennemis — Infantry (Fantassin)

**Rôle actuel** : Unité équilibrée, 40 HP, vitesse 65, teinture blanche/neutre.

| Tier Vague | Nom | Description Visuelle | HP / Vitesse | Comportement Spécial | Source Sprite |
|-----------|-----|---------------------|-------------|---------------------|--------------|
| **Vague 1–9** | Fantassin de Terre | Soldat en armure de cuir, bouclier rond en bois, épée courte | 40 HP / 65 | Standard | `enemy_infantry_0-3.png` (actuel) |
| **Vague 10–24** | Guerrier Runique | Armure noire avec runes rouges incandescentes, hache de guerre, casque cornu | 55 HP / 72 | Résistance aux ralentissements (-30%) | Kenney Creatures ou 0x72 DungeonTileset |
| **Vague 25–49** | Golem de Pierre Chibi | Corps de pierre arrondi expressif, bras énormes, petites jambes, fissures lumineuses orangées | 90 HP / 55 | Immunité aux petits projectiles (-50% dmg flèches standard) | Aekashics Liberated Pixel Cup – Golem |
| **Vague 50+** | Colosse Mécha | Robot anthropomorphe massif, bouclier énergie avant, missiles sur l'épaule, style mécha chibi | 150 HP / 60 | Bouclier frontal (50% réduction face), tire missiles toutes les 8s | Kenney Robots pack + upscale |

---

### 6. Ennemis — Archer (Arbalétrier)

**Rôle actuel** : Rapide, faible HP, teinte bleue.

| Tier Vague | Nom | Description Visuelle | HP / Vitesse | Comportement Spécial | Source Sprite |
|-----------|-----|---------------------|-------------|---------------------|--------------|
| **Vague 3–9** | Arbalétrier de Brousse | Tenue légère en cuir brun, capuche, arbalète en bois | 22 HP / 88 | Tire sur les archers (déviation) | `enemy_archer_0-3.png` (actuel) |
| **Vague 10–24** | Sniper Elfe Sylvestre | Silhouette mince, cape de camouflage verte, arc elfique en corne, flèches lumineuses | 30 HP / 100 | Tire depuis les bords, evade les flèches (30% esquive) | Tiny Swords Elf Archer |
| **Vague 25–49** | Drone Tireur Chibi | Petit drone rond volant, oeil rotatif, canon rétractable, style anime | 45 HP / 115 | Vole (ignore terrain), tire en rafale, s'auto-répare à 25% HP | LimeZu ou asset IA |
| **Vague 50+** | Sniper Orbital | Fine silhouette en combinaison blanche, fusil plasma long, viseur holographique, lévitation légère | 60 HP / 130 | Cible en priorité les archers de tour, tir pénétrant | Asset original |

---

### 7. Ennemis — Cavalier (Cavalerie)

**Rôle actuel** : Tank rapide, 70 HP, vitesse 108, teinte dorée.

| Tier Vague | Nom | Description Visuelle | HP / Vitesse | Comportement Spécial | Source Sprite |
|-----------|-----|---------------------|-------------|---------------------|--------------|
| **Vague 5–9** | Cavalier de Guerre | Cheval brun, armure complète, lance, bouclier armorié | 70 HP / 108 | Charge (accélère les 2 dernières secondes) | `enemy_cavalier_0-3.png` (actuel) |
| **Vague 10–24** | Centaure Doré | Corps de cheval or et blanc, torse humanoïde musculeux, arc à double courbure, crinière dorée | 100 HP / 120 | Charge ET tire des flèches en approchant | Kenney Creatures – Centaur ou Aekashics |
| **Vague 25–49** | Biker Chibi Steampunk | Petit personnage chibi sur moto à vapeur (rouages, soupapes), casque arrondi, écharpe au vent | 140 HP / 140 | Boost de nitro (×2 vitesse pendant 3s) toutes les 15s, laisse trainée de fumée | LimeZu style ou générer |
| **Vague 50+** | Speeder Gravitonique | Planche de lévitation fine transparente, pilote en armure néon cyan, sillage de lumière | 200 HP / 160 | Champ de force (absorbe 3 hits avant de s'activer), décélère plus lentement dans l'eau | Asset original |

---

### 8. Ennemis — Healer (Guérisseur)

**Rôle actuel** : Lent, soigne les alliés dans un rayon, teinte verte.

| Tier Vague | Nom | Description Visuelle | HP / Vitesse | Comportement Spécial | Source Sprite |
|-----------|-----|---------------------|-------------|---------------------|--------------|
| **Vague 8–9** | Chaman Tribale | Robe de peau, masque en os, bâton avec crâne, aura verte diffuse autour | 28 HP / 55 | Soigne 8 HP / 3s dans r=150 | `enemy_healer_0-3.png` (actuel) |
| **Vague 10–24** | Ange Corrompu | Silhouette en robe blanche tachée, ailes d'ange froissées noires, halo brisé, mains rayonnantes | 40 HP / 62 | Soigne 15 HP / 2.5s, applique bouclier temporaire sur une cible (500ms invulnérabilité) | Aekashics – Angel sprite |
| **Vague 25–49** | Nanobot Médic Chibi | Petit robot carré blanc avec croix rouge, bras-seringues articulés, antennes vibrantes | 60 HP / 68 | Soigne 25 HP / 2s, peut réssusciter un ennemi mort (1 fois / vague) | Kenney Robots + recolor |
| **Vague 50+** | Suprême Régénérateur | Entité translucide dorée, humanoïde flottant, organes visibles en verre, aura pulsante qui croît | 90 HP / 75 | Soigne TOUS les ennemis en rayon (r=250), se duplique en 2 fantômes à 50% HP | Asset original / génération IA |

---

### 9. Projectiles (Flèches)

**Rôle actuel** : Sprite `arrow.png` basique, blanc/gris.

| Tier | Nom | Visuel | Effet au contact | Source |
|------|-----|--------|-----------------|--------|
| **T0** | Flèche de Bois | Trait brun fin, pointe de métal | Rien | Actuel `arrow.png` |
| **T1** | Flèche Runique | Trait lumineux doré/bleu, traînée de particules magiques | Flash de lumière à l'impact | Générer via PIL (lueur sur le trait actuel) |
| **T2** | Balle Traçante | Sphère lumineuse compacte, traînée colorée selon le type (rouge feu, jaune éclair, bleu glace) | Explosion de particules colorées | Cercle PIL avec glow |
| **T3** | Faisceau Plasma | Segment laser fin de 3px, couleur cyan/violet, oscillation sub-pixel | Pulse néon à l'impact, mini explosion | Segment PIL avec blur |

**Note** : Le type de projectile découle du `_power` actif sur la tour (TowerPower). Chaque power donne une couleur distincte à la flèche même au T0.

---

### 10. Pièces d'Or / Monnaie

**Rôle actuel** : Sprite `coin.png` rond doré, tombe des ennemis vaincus.

| Tier | Nom | Visuel | Animation | Source |
|------|-----|--------|-----------|--------|
| **T0** | Pièce d'Or | Disque doré simple avec relief | Bounce simple vers le bas | Actuel `coin.png` |
| **T1** | Gemme Enchantée | Cristal taillé 8 faces, reflets dynamiques, lueur interne | Rotation lente + pulse | PIL : octogone avec gradient radial |
| **T2** | Sphère d'Énergie | Sphère translucide avec noyau brillant, 3 couleurs possibles selon type ennemi | Orbite + pulsation | PIL : cercle avec blur gaussien + saturation |
| **T3** | Crédit Holographique | Hexagone fin translucide bleu, données flottantes autour, mini-hologramme | Rotation 3D simulée (frame-by-frame) | PIL : hexagone + données matricielles |

---

### 11. Forge (Structure)

**Rôle actuel** : Sprite `forge.png`, enclume basique. Génère 4 upgrades (DMG/VIT/MAG/HP).

| Tier | Nom | Description Visuelle | Effets Ambiants | Upgrade Costs | Source Sprite |
|------|-----|---------------------|-----------------|--------------|--------------|
| **T0** | Enclume Rustique | Enclume en fer sur billot de bois, marteau posé, tas de charbon | Aucun | 200g × 4 slots (actuel) | Actuel `forge.png` |
| **T1** | Atelier des Runes | Enclume en obsidienne gravée de runes dorées, sphère magique flottante au-dessus, marteau runique | Étincelles dorées autour de l'enclume | 250g × 4 slots | Kenney Fantasy Characters props |
| **T2** | Fonderie Steampunk | Machine complexe avec engrenages rotatifs, soufflets mécaniques, tuyaux de vapeur, écran de contrôle | Vapeur, engrenages en mouvement (anim) | 300g × 4 slots, effets stackables | Kenney Sci-fi RTS – Workshop |
| **T3** | Nanofabricateur | Capsule ovale translucide, bras robotiques multiples, lumières bleues, interface holographique | Bras rotatifs, projections hologrammes | 350g × 4 slots, upgrades peuvent se combiner | Asset original |

---

### 12. Sorts du Héros

**Rôle actuel** : 3 sorts — Feu, Éclair, Glace. Boutons ronds avec icônes remplacées.

| Sort | T0 Actuel | T1 Fantastique | T2 Hybride | T3 Cosmique |
|------|-----------|---------------|------------|-------------|
| **Feu** | Boule de feu en arc diagonal | Tempête de météores (AOE) | Bombe incendiaire à fragmentation (style militaire chibi) | Supernova (cercle de plasma, tout brûle) |
| **Éclair** | Arc électrique ligne droite | Chaîne d'éclairs (rebondit sur 3 ennemis) | Grille Tesla (zone carrée, dmg/s) | Singularité électrique (aspire et détruit) |
| **Glace** | Cône de gel | Mur de glace (bloque temporairement) | Bombe cryo (AOE freeze 3s) | Arrêt temporel (tout freeze zone 5s) |

**Icônes sorts par tier :**
- T0 : Actuels `spell_fire/lightning/ice.png` (game-icons.net déjà installés)
- T1 : `lorc/meteor-impact`, `lorc/lightning-storm`, `lorc/frozen-orb`
- T2 : `lorc/fire-bomb`, `lorc/tesla-coil`, `lorc/cryo-chamber`
- T3 : `lorc/plasma-bolt`, `lorc/laser-sparks`, `lorc/crystal-cluster`

---

### 13. Zones d'Action (Marqueurs au sol)

**Rôle actuel** : Cercles colorés pour RECRUIT, TOWER, TARGETING, FORMATION, FORGE. Sprites `zone_*.png`.

| Tier | Style Zone | Visuel | Effet | Source |
|------|-----------|--------|-------|--------|
| **T0** | Cercle peint | Demi-cercle de peinture blanche/colorée au sol | Statique | Actuel `zone_*.png` |
| **T1** | Rune au sol | Cercle de runes gravées qui pulsent selon l'activité, couleur propre à chaque zone | Pulsation lente | PIL : cercle avec ornements runiques |
| **T2** | Hologramme 3D | Projection holographique en perspective (anneau flottant légèrement), style sci-fi | Rotation de l'anneau, scanlines | PIL : ellipse avec dégradé radial |
| **T3** | Champ Quantique | Zone de distorsion lumineuse, bord flou, effet de shimmer, mini-étoiles | Particules dynamiques Godot (CPUParticles2D) | Code shader + CPUParticles2D |

---

## MODE RPG — Exploration

### 1. Héros en Exploration

**Rôle actuel** : Même sprite cavalier que le mode TD, se déplace sur la carte RPG 9600×3240 à pied ou à cheval.

| Tier | Nom | Description Visuelle | Capacités Visuelles | Source Sprite |
|------|-----|---------------------|--------------------|--------------|
| **T0** | Éclaireur Médiéval | Cavalier/piéton en armure de cuir, cape, épée au côté | Ombre simple au sol | Actuel `hero_0-3.png` |
| **T1** | Ranger Mystique | Armure légère en cuir avec symboles dorés, arc sur le dos, capuche, lueur légère des yeux | Trail lumineux lors du sprint, vêtements qui ondulent | Kenney Fantasy Characters – Ranger |
| **T2** | Explorateur Chibi | Petit personnage rond expressif, jumelles sur le front, sac à dos avec gadgets, style LimeZu | Exclamation chibi en découvrant un lieu, bulles d'expressions | LimeZu Sprout Lands – Farmer/Adventurer |
| **T3** | Voyageur Quantique | Silhouette en combinaison légère translucide, dispositifs de scan sur les bras, moteur de lévitation discret aux pieds | Scintillement lors du mouvement, carte mini holographique flottante | Asset original / génération IA |

---

### 2. Noeuds de Ressources — Bois

**Rôle actuel** : `tree_sm.png` (arbre Kenney) à ×0.55. Délai de respawn 900s.

| Tier | Nom | Visuel de l'arbre | Récolte Visuelle | Rendement | Source |
|------|-----|--------------------|-----------------|-----------|--------|
| **T0** | Chêne Rustique | Petit arbre pixel-art vert simple, tronc brun | Feuilles qui tombent | 1–3 Bois / récolte | Actuel `tree_sm.png` |
| **T1** | Arbre Ancien | Grand arbre majestueux, racines visibles, feuillage dense lumineux, champignons à la base | Feuilles magiques dorées | 3–6 Bois, chance 10% Bois Rare | Kenney Fantasy Town Kit – Old Tree |
| **T2** | Conifère Cristallin | Arbre avec aiguilles translucides bleues/vertes, sève brillante, cristaux à mi-tronc | Éclats de cristal lors de la récolte | 5–8 Bois Cristallin, utilisable en artisanat avancé | Sprite PIL : arbre Kenney + overlay cristal |
| **T3** | Séquoia Biomécanique | Immense arbre dont le tronc intègre des câbles et circuits, feuilles en fibre optique, lumières à l'écorce | Animation de déconnexion circuit | 8–12 Bois Nano-Fibre (ressource rare), 20% cristal | Asset original |

---

### 3. Noeuds de Ressources — Pierre / Minerai

**Rôle actuel** : `rock.png` Kenney, modulate coloré selon type (ore/coal/crystal/gemstone).

| Tier | Nom | Visuel | Ressource | Source |
|------|-----|--------|-----------|--------|
| **T0** | Rocher Commun | Rocher gris arrondi simple | Pierre ×2–5 | Actuel `rock.png` |
| **T1** | Filons de Gemmes | Rocher avec veines de minerai brillant visibles (or, rubis, saphir selon type), lueur interne faible | Pierre +3, Gemme ×1–2 | Kenney Tiny Dungeon – tileset pierres + overlay PIL |
| **T2** | Astéroïde Localisé | Rocher d'aspect météoritique, texture noire avec inclusions métalliques brillantes, légèrement lévitant | Métal Météoritique ×2–4, Pierre ×2 | PIL : rocher Kenney + effet spatial |
| **T3** | Nœud d'Énergie Tellurique | Cristal géant émergeant du sol, pulsation interne bleue, fils d'énergie vers le sol | Cristal d'Énergie ×3–6 (craft avancé), EXP bonus | Asset original |

---

### 4. Noeuds de Ressources — Herbes / Plantes

**Rôle actuel** : Fallback ColorRect, types HERB/MUSHROOM/SILK non spritifiés.

| Tier | Nom | Visuel | Ressource | Source |
|------|-----|--------|-----------|--------|
| **T0** | Herbe Médicinale | Touffe d'herbe verte simple, 3-4 tiges | Herbe ×1–3 | Sprite PIL basique |
| **T1** | Fleur Lumineuse | Fleur épanouie avec pétales rouges/violets luminescents la nuit, pollen doré | Herbe Rare + Essence Magique | Kenney Fantasy Town – plants |
| **T2** | Champignon Bioluminescent | Grand chapeau rond orange/bleu, spores flottantes visibles, halo circulaire discret au sol | Champignon Toxique/Médicinal (choix selon récolte), XP craft | Aekashics resources ou générer PIL |
| **T3** | Orchidée Nanobiotique | Fleur artificielle semi-organique, câbles organiques, couleurs changeantes selon l'heure | Essence Nanobiotique (craft tier 3 seulement), bonus XP permanent +5% | Asset original |

---

### 5. NPCs (Personnages Non-Joueurs)

**Rôle actuel** : 5 types (Marchand, Scout, Sage, Barde, Guérisseur), sprites actuel dans `npc_*.png`. Style médiéval basique.

| Tier | Style NPC | Apparences | Dialogues / Offres | Source Sprite |
|------|----------|------------|-------------------|--------------|
| **T0** | Médiéval Rustique | Robes de voyage usées, couleurs ternes, expressions limitées | Marchands simples, missions basiques | Actuel `npc_*.png` |
| **T1** | Pèlerins Fantastiques | Elfes fins, Nains trapus, Hybrides humain/animal (half-elfe, mi-félin), robes aux symboles magiques | Quêtes de guilde, recettes rares, lore | Kenney Fantasy Characters set |
| **T2** | Chibi Voyageurs | Style "Animal Crossing" — personnages ronds expressifs, accessoires distinctifs (chapeau de voyage, cartes, lunettes de chimiste) | Échanges plus riches, défis quotidiens, mini-jeux | LimeZu Sprout Lands – NPC set |
| **T3** | Entités de Connaissance | Hologrammes de bibliothèque flottants, IA incarnées en formes humanoïdes translucides, cristaux parlants | Lore profond, technologies avancées, recettes cosmiques, reset skills | Asset original / génération IA |

**Note** : Les NPCs ne progressent pas par tier de jeu — chaque NPC a un type fixe. Cependant, les zones plus avancées de la carte RPG pourraient avoir des NPCs de tier plus élevé.

---

### 6. Coffres au Trésor

**Rôle actuel** : `chest.png` Kenney Tiny Dungeon tile_0050, 80×80 upscalé.

| Tier | Nom | Visuel | Loot | Icon HUD | Source |
|------|-----|--------|------|----------|--------|
| **T0** | Coffre de Bois | Coffre en bois avec penture métallique simple, lock rouillé | Ressources communes, or | Actuel `chest.png` | Kenney Tiny Dungeon (actuel) |
| **T1** | Coffre Runique | Coffre en fer avec runes incrustées qui brillent, serrure magique, ornements en or | Recettes, Gemmes, Équipement rare | `lorc/chest-armor` | Kenney RPG Urban Kit ou Tiny Swords |
| **T2** | Capsule Steampunk | Container métallique rond avec hublot en verre, voyant lumineux (vert = intact / rouge = piégé), jauge de pression | Crafting avancé, schémas tech | `lorc/cog` | Kenney Sci-fi RTS – Containers |
| **T3** | Vault Dimensionnel | Cube holographique flottant, faces transparentes avec items visibles à l'intérieur, tourne lentement | Items légendaires, artefacts, recettes tier 3 | `lorc/gem-chain` | Asset original |

---

### 7. Sanctuaires de Guérison

**Rôle actuel** : `shrine.png` Kenney Tiny Dungeon tile_0108, 80×80 upscalé.

| Tier | Nom | Visuel | Soin | Cooldown | Source |
|------|-----|--------|------|----------|--------|
| **T0** | Autel de Pierre | Pierre rustique taillée, mousse, croix ou symbole gravé | +20 HP | 60s | Actuel `shrine.png` |
| **T1** | Temple des Anciens | Colonnes brisées avec vigne, bassin d'eau lumineuse au centre, eau animée | +40 HP, +suppression états | 45s | Kenney Fantasy Town – Temple pillar |
| **T2** | Station Médicale Mobile | Borne automatique en acier blanc, écran digital "MEDIC", bras-seringue auto | Soin complet HP, buff temporaire +15% vitesse | 30s | Kenney Sci-fi RTS – Structure |
| **T3** | Fontaine Quantique | Sphère d'eau lumineuse en lévitation, eau qui monte vers le ciel puis retombe, fractales | Soin complet HP + MAX HP +10% permanent (1 fois) | 120s (puissant) | Asset original |

---

### 8. Camps Ennemis

**Rôle actuel** : Structures simples dans la carte exploration, dégâts si le héros s'approche, `rpg_enemy_camp.gd`.

| Tier | Nom | Visuel Structure | Ennemis Gardiens | Récompense Libération | Source |
|------|-----|-----------------|-----------------|----------------------|--------|
| **T0** | Camp Pillard | Tentes en peau, palissade de bois, feu de camp | 3–5 bandits médiévaux | Or + ressources communes | Kenney Fantasy Town – Camp props |
| **T1** | Forteresse Corrompue | Tour en pierre corrompue, murs noirs avec runes rouges, bannières ennemies | 5–8 guerriers runiques + 1 garde élite | Gemmes + recettes T1 + XP bonus | Kenney + overlay couleurs corrompues |
| **T2** | Avant-poste Industriel | Structures métalliques grises, cheminées, clôture barbelée, projecteur tournant | Drones + soldats chibi armés | Matériaux rares + schémas T2 | Kenney Sci-fi RTS |
| **T3** | Nexus Alien | Cristal géant corrompu entouré de structures organiques-mécaniques, aura de distorsion | Boss unique + 10 gardes T3 | Artefact unique + XP massif + accès zone cachée | Asset original |

---

### 9. Tableau de Contrats / Missions

**Rôle actuel** : `bulletin_board.png`, `notice_board.png`. Panneau en bois avec des parchemins.

| Tier | Nom | Visuel | Contrats Disponibles | Interface | Source |
|------|-----|--------|---------------------|-----------|--------|
| **T0** | Tableau d'Affichage | Planche de bois avec parchemins épinglés, encre noire | 3 contrats simples (récolte, kill, livraison) | Panel HUD basique texte | Actuel `notice_board.png` |
| **T1** | Guilde des Aventuriers | Panneau doré avec écusson de guilde, parchemins de qualité avec sceaux de cire | 5 contrats, chaînes de quêtes, réputation | Panel HUD avec badges de réputation | Kenney RPG props + PIL overlay |
| **T2** | Terminal de Missions | Borne tactile holographique, interface numérique, icônes de mission animées | 8 contrats, missions temporisées, bonus streak | Interface HUD modernisée avec timer et barre XP | Kenney Sci-fi – Terminal |
| **T3** | Oracle des Destinées | Entité semi-transparente, projections de missions dans l'air, hologrammes 3D | 12 contrats, missions de world-event, mythiques | Interface cosmique avec étoiles et constellations comme carte de mission | Asset original |

---

### 10. Événements Dynamiques

**Rôle actuel** : `dynamic_event_manager.gd`, 7 types d'événements, banner dans le HUD.

| Tier | Style Banner | Événements Disponibles | Visuel sur la carte | Source |
|------|-------------|----------------------|--------------------|----|
| **T0** | Parchemin enroulé (banner simple) | Météo, raids, migrations, foires | Rien de visible sur la map | Actuel code HUD |
| **T1** | Bannière de Guilde | +3 événements : Tournoi, Apparition de reliques, Nuit des sorciers | Aura colorée sur la zone concernée | PIL : banner avec décoration runique |
| **T2** | Alerte Industrielle | +3 : Panne de générateur, Invasion de drones, Marché noir | Icône d'alerte pulsante sur la zone carte | Style HUD `StyleBoxFlat` colorisé |
| **T3** | Transmission Cosmique | +3 : Pluie de météorites (ressources rares), Rift dimensionnel (nouvelle zone temporaire), Signal d'une ancienne IA | Portail visible sur la carte avec particules | Asset original + CPUParticles2D |

---

### 11. Monture (Cheval / Alternative)

**Rôle actuel** : `mount_horse.png` cheval brun, `mount_scroll.png` rouleaux de déplacement. Toggle entre monté/pied.

| Tier | Nom | Description | Bonus Vitesse | Source Sprite |
|------|-----|-------------|--------------|--------------|
| **T0** | Destrier de Base | Cheval brun standard, selle simple | ×2.0 vitesse de déplacement | Actuel `mount_horse.png` |
| **T1** | Pégase Runique | Cheval blanc avec ailes déployées, sabots lumineux, ornements dorés | ×2.5 vitesse + saut de fossé | Kenney Fantasy Characters – Horse / Tiny Swords |
| **T2** | Kart Steampunk Chibi | Petit véhicule carré à vapeur, rouages latéraux, siège rembourré, klaxon | ×3.0 vitesse + mini-canon décoratif | LimeZu ou générer PIL |
| **T3** | Surfeur de Mémorisation | Planche de lévitation plasma, sillage lumineux cyan, posture de surf | ×4.0 vitesse + triple-saut + immunité aux ralentissements | Asset original |

---

## Double-Check & Améliorations Additionnelles

Après révision, voici les éléments **oubliés dans la planification initiale** et les **améliorations à intégrer** :

### Éléments Oubliés — Mode TD

**A. Effets visuels de dégâts (hit flash / impact)**
- T0 : Flash blanc basique sur l'ennemi (actuel)
- T1 : Particules d'étoiles/runes à l'impact
- T2 : Mini-explosion mécanique (ressort, boulon qui vole)
- T3 : Disintegration en pixels lumineux

**B. Indicateurs de santé ennemis (barre HP)**
- T0 : Barre HP rouge/verte basique au-dessus (actuel ?)
- T1 : Barre stylisée avec symboles runiques aux extrémités
- T2 : Affichage numérique style HUD militaire
- T3 : Hologramme circulaire de santé autour de l'ennemi

**C. Effet de mort ennemi**
- T0 : Disparition simple (retour au pool actuel)
- T1 : Explosion de particules magiques + petit esprit qui monte
- T2 : Effondrement mécanique (pièces qui tombent brièvement)
- T3 : Désintégration en lumière + décompte de données affiché

**D. Le sol / Background du mode TD**
- T0 : `background.png` statique paysage (actuel)
- T1 : Champ de bataille avec runes discrètes au sol, herbe animée
- T2 : Zone industrielle avec grilles et rouages en arrière-plan
- T3 : Surface planétaire ou asteroïde, étoiles en background, néon ambient

**E. Effet de vague (wave start banner)**
- T0 : Texte simple "Vague N" (actuel)
- T1 : Banner parchemin animé déployé
- T2 : Sirène d'alarme style militaire
- T3 : Transmission holographique de l'ennemi avec compte à rebours

### Éléments Oubliés — Mode RPG

**F. Journal / Interface de quêtes**
- T0 : Panel texte simple (actuel `journal_panel.gd`)
- T1 : Livre de cuir animé qui s'ouvre, pages qui tournent
- T2 : Tablet numérique, interface tactile
- T3 : Interface neurale flottante avec onglets 3D

**G. Arbre de compétences / Talents**
- T0 : Grille de boutons basiques (actuel `skill_tree_panel`)
- T1 : Arbre avec branches dorées et nœuds lumineux
- T2 : Circuit électronique, nœuds style tech-tree
- T3 : Constellation cosmique, étoiles connectées

**H. Météo et heure du jour**
- T0 : Fond statique (actuel)
- T1 : Nuages animés, pluie de particules, lever/coucher soleil (teinte)
- T2 : Système météo steampunk (indicateurs baromètre HUD)
- T3 : Perturbations météo cosmiques (aurores boréales, pluies de météorites)

**I. Portail / Entrée du Mode TD**
- T0 : Zone de transition simple `dungeon_entrance.png`
- T1 : Arc en pierre avec runes actives, brume dorée
- T2 : Sas hydraulique, sirène d'alerte
- T3 : Portail de distorsion quantique, effet de warp

---

## Plan d'Implémentation Suggéré

### Phase A — Quickwins Visuels (faible effort, impact fort)
1. Projectiles T1 (lueur sur les flèches — PIL + pas de code)
2. Pièces d'or T1 (gemme cristal — PIL)
3. Zones d'action T1 (runes au sol — PIL)
4. Sprites NPCs T1 (Kenney Fantasy Characters — remplacement direct)

### Phase B — Tiers Ennemis (effort moyen, impact gameplay)
1. Sprites ennemis T1 pour les vagues 10+ (Kenney Creatures + recolor)
2. Sprites ennemis T2 pour les vagues 25+ (chibi style — LimeZu ou générer)
3. Effets de mort améliorés (CPUParticles2D)

### Phase C — Héros & Structures (effort élevé, identité du jeu)
1. Héros T1 (Paladin Solaire — Tiny Swords ou Kenney)
2. Tours T1 et T2 amélioration visuels (Kenney + PIL)
3. Château T1 (Kenney Fantasy Town)

### Phase D — Sci-fi & Cosmique (effort élevé, contenu late-game)
1. Héros T3 et archers T3 (drones)
2. Ennemis T3 (mécha)
3. Background T3 (planétaire)
4. Sorts T3 (nouveaux sprites de projectiles)

---

## Résumé des Sources à Acheter / Obtenir

| Priorité | Source | Coût | Couvre |
|---------|--------|------|--------|
| HAUTE | Kenney Fantasy Characters (CC0) | Gratuit | Héros T1, NPCs T1, Archers T1 |
| HAUTE | Kenney Tiny Dungeon (CC0) | Gratuit | Coffres, RPG tiles |
| HAUTE | Kenney Creatures (CC0) | Gratuit | Ennemis T1 |
| HAUTE | 0x72 DungeonTileset II (CC0) | Gratuit | Ennemis et décors |
| MOYENNE | LimeZu Sprout Lands (~6€) | ~6€ | Chibi T2 global |
| MOYENNE | Tiny Swords (Pixel Frog, ~10€) | ~10€ | Héros T1, Tours T1 |
| BASSE | Assets originaux IA/Commission | Variable | T3 Cosmique |

**Total budget estimé accès assets** : ~16–25€ pour couvrir T0 → T2 complet.
**T3 Cosmique** : génération PIL avancée + assets IA ou commission (~50–100€).

---

*Document généré le 2026-06-05. Réviser avant chaque sprint d'implémentation visuelle.*
