# Game Concept: Garrison

*Created: 2026-05-17*
*Status: Draft*

---

## Elevator Pitch

> C'est un jeu de défense par vagues où tu déplaces ton héro invincible avec un joystick pour
> orchestrer une armée d'archers qui protège ton château contre des hordes ennemies, en
> dépensant intelligemment l'or récupéré sur le champ de bataille pour recruter, construire
> des tours et améliorer tes troupes.
>
> Le joueur ne touche qu'au joystick. Le reste s'organise seul.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Wave defense / auto-shooter / gestion économique spatiale |
| **Platform** | Android (Mobile) |
| **Target Audience** | Joueurs casual-midcore, 18-45 ans, sessions courtes |
| **Player Count** | Single-player |
| **Session Length** | 5-20 minutes par run |
| **Monetization** | À définir (hors scope MVP) |
| **Estimated Scope** | Medium (3-5 mois, solo dev) |
| **Comparable Titles** | Kingshot (démo Unity de référence), Minion Masters, Tower Defense mobile |

---

## Core Fantasy

Tu es le roi. Ton château est attaqué. Ta valeur ne se mesure pas à ton épée, mais à ta capacité
à être au bon endroit au bon moment — ramasser l'or, recruter rapidement, placer tes archers là
où ils feront le plus de dégâts.

Tu regardes ton armée grandir autour de toi. D'un héro solitaire tirant des flèches, tu deviens
le centre d'une machine de guerre : archers qui t'encerclent, tours qui crachent des flèches de
toutes parts. Ton château tient. Pour l'instant.

---

## Unique Hook

C'est comme un tower defense mobile, **ET AUSSI** l'armée est vivante, attachée à toi, et doit
être physiquement positionnée par tes déplacements. Pas de boutons. Pas de menus. Juste un
joystick et des décisions spatiales.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (plaisir sensoriel) | 2 | Feedback visuel de l'armée qui grandit, pièces aspirées, flèches qui volent |
| **Fantasy** (faire semblant) | 3 | Incarner un roi-chef de guerre défendant son château |
| **Narrative** (drame, histoire) | N/A | Pas de narration — loop pur |
| **Challenge** (maîtrise, obstacles) | 2 | Optimisation économique, positionnement, vagues croissantes |
| **Fellowship** (social) | N/A | Solo uniquement |
| **Discovery** (exploration, secrets) | 4 | Découverte des stratégies optimales, des synergies |
| **Expression** (créativité) | N/A | Pas de personnalisation |
| **Submission** (relaxation) | 1 | Auto-play de base, peu de friction, joystick simple |

### Key Dynamics (Comportements émergents attendus)

- Le joueur apprend naturellement à rester en mouvement (collecter l'or, éviter de bloquer)
- Le joueur développe une routine d'allocation : recruter en début de vague, construire en milieu, forger quand les pièces s'accumulent
- Le joueur positionne intuitivement ses tours aux points stratégiques (intersections des chemins ennemis)
- Le joueur ressent de l'urgence lors des vagues intenses sans jamais paniquer (héro invincible)

### Core Mechanics (Systèmes à implémenter)

1. **Joystick + auto-shoot** : le héro tire automatiquement sur les ennemis dans son rayon. Un seul input direct.
2. **Économie à actions spatiales** : recruter / construire / upgrader = marcher sur une zone avec assez d'or. Zéro bouton. *Déclenchement : dwell trigger — le héro doit rester ~0.8s dans la zone pour valider l'achat. Feedback : barre de progression circulaire sur la zone. Pas d'achat accidentel en passant. Zone radius : ~60px (à valider en prototype économique).*
3. **Armée vivante transférable** : les archers suivent le héro (pool unique), transférables dans des tours fixes par passage sur la zone de dépôt. *Trade-off : archer suiveur = DPS mobile qui couvre la zone du héro ; tour fixe = DPS supérieur sur un couloir défini, libère un slot de pool pour recruter davantage.*
4. **Pathfinding ennemi vers château** : les ennemis ignorent le héro, visent le château, attaquent au corps à corps au contact. *Algorithme MVP : steering en ligne droite vers le château (pas de NavMesh en MVP, juste direction_to). Les ennemis ne s'aggrochent pas sur le héro. Conséquence de design : le héro doit aller à la rencontre des ennemis pour les intercepter — son mouvement est actif, pas réactif.*
5. **Vagues infinies avec pause** : escalade de difficulté, countdown visible entre les vagues pour dépenser l'or.

### Economy Sketch (ratios de départ — à affiner dans l'Economy GDD)

| Action | Coût (or) | Ratio | Notes |
| ---- | ---- | ---- | ---- |
| **Recruter archer suiveur** | 30g | 1× | Achat fréquent, DPS mobile |
| **Construire tour** | 100g | 3.3× | Épargne 3+ vagues, DPS fixe supérieur |
| **Forge upgrade** | 200g | 6.7× | Investissement rare, buff global |

**Income estimé** : ~15g par ennemi tué. Vague 1 (~5 ennemis) = ~75g ≈ 2 archers OU épargne toward tour.
**Anti-spiral** : mécanisme à définir dans l'Economy GDD (ex : gold floor, carry-over bonus, auto-scale vague si DPS insuffisant).
**Pause inter-vague** : 5s est un point de départ. Durée réelle à tester lors du prototype économique — probablement à étendre (ex : `5s + 2s × N_vague`) pour permettre les décisions spatiales à scale.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (liberté, choix) | Allocation économique libre : recruter, construire ou forger ? Dans quel ordre ? | Core |
| **Competence** (maîtrise) | Positionnement de plus en plus optimal au fil des runs, score croissant | Supporting |
| **Relatedness** (connexion) | Lien visuel fort avec l'armée qui suit le héro partout | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Armée visible qui croît, compteur or, vagues survivées, HP château à préserver
- [ ] **Explorers** — Découverte limitée (stratégies d'allocation, pas d'exploration de monde)
- [ ] **Socializers** — Solo uniquement
- [ ] **Killers/Competitors** — Pas de PvP ; compétition implicite via score personnel

### Flow State Design

- **Onboarding** : Premier run = héro seul + 1 ennemi. Les zones de recrutement s'illuminent quand l'or est suffisant. Pas de tutoriel texte.
- **Difficulté** : Vagues croissantes en quantité et résistance. Chaque vague teste si l'allocation précédente était optimale.
- **Feedback** : Barre HP château visible en permanence. Nombres de dégâts flottants. Pièces aspirées avec animation. Armée visuellement dénombrable autour du héro.
- **Récupération d'échec** : Game Over immédiat puis retour au menu → nouveau run. Pas de punition, pas de perte de progression. Le run suivant commence identique.

---

## Core Loop

### Moment-to-Moment (30 secondes)

Le héro se déplace via joystick. Il tire automatiquement sur les ennemis dans son rayon (cercle visible). Les ennemis morts droppent des pièces d'or, aspirées automatiquement à proximité. Le joueur gère sa trajectoire pour : (a) rester à portée des ennemis pour les shooter, (b) passer sur les zones économiques (recrutement, construction, forge) quand les seuils sont atteints.

**Verdict de fun isolé** : bouger + voir les flèches partir + voir les pièces se collecter = satisfaisant sans aucun contexte supplémentaire.

### Short-Term (5-15 minutes)

Une vague dure jusqu'à ce que tous les ennemis soient morts. Pause courte avec countdown visible (≈5s). Le joueur dépense ses pièces d'or pendant la pause. Vague suivante = plus d'ennemis, plus résistants. La tension monte progressivement. Le château perd de la vie si les ennemis percent.

### Session-Level (20-30 minutes)

Un run complet = construction progressive d'une forteresse à partir de rien. Le joueur atteint sa limite d'optimisation, le château finit par tomber. Score final (vagues atteintes, ennemis tués). Satisfaction de voir comment loin on est allé.

### Long-Term Progression

Hors scope MVP. Pistes : meilleur score sauvegardé, records personnels, déverrouillage cosmétique (couleurs d'archers, skins du héro).

### Retention Hooks

- **Mastery** : "La prochaine fois je construirai les tours en premier plutôt que de recruter des suiveurs"
- **Investment** : Score personnel à battre
- **Curiosité** : "Est-ce que la forge change vraiment beaucoup les dégâts ?"

---

## Game Pillars

### Pillar 1 : "Un seul doigt, zéro friction"

Le joystick est le seul input direct de toute la session. Tirer, collecter, améliorer = automatique ou positionnel. La complexité vient de OÙ le héro se déplace, pas de COMMENT appuyer.

*Design test* : Si on débat entre "ajouter un bouton de sprint" vs "sprint automatique quand on tire le joystick fort", ce pilier dit : sprint automatique. Toujours.

### Pillar 2 : "Chaque pièce d'or est une décision"

Le budget est la tension principale. Recruter des suiveurs (DPS mobile), construire une tour (DPS fixe zone), upgrader la forge (DPS global) : trois choix concurrents, tous légitimes, aucun optimal en toutes circonstances.

*Design test* : Si un upgrade est toujours la meilleure option sans réflexion, il faut rééquilibrer les coûts ou les effets pour que la décision soit non-triviale.

### Pillar 3 : "L'armée se voit grandir"

La puissance du joueur est visible et spatiale : plus d'archers autour du héro, plus de tours actives. La satisfaction est quantitative et visuelle, pas cachée dans des stats d'écran. Le joueur VOIT son pouvoir.

*Design test* : Si un upgrade n'a pas de représentation visuelle sur la map (flash, nouveau sprite, animation), on revoir le feedback avant de coder la stat.

### Pillar 4 : "Tension sans panique"

Le héro est invincible. La menace pèse sur le château, pas sur le joueur. Le stress vient de regarder la barre de vie rouge baisser, pas de survivre. Le joueur reste dans un état de flow sans frustration.

*Design test* : Si une mécanique proposée crée de la frustration (mort du héro, perte d'unités sans prévenir, interface bloquante), elle compromet ce pilier et doit être revue ou supprimée.

### Anti-Pillars

- **PAS de santé du héro** : casse l'accessibilité mobile, crée de la frustration sans stratégie.
- **PAS de boutons / taps mid-combat** : joystick-only est une contrainte créative, pas une limitation.
- **PAS de loot aléatoire** : l'économie est déterministe. Le joueur sait exactement ce que chaque dépense produit.
- **PAS de menus complexes mid-combat** : toutes les actions sont positionnelles et spatiales, visibles sur la map.

---

## Visual Identity Anchor

**Direction** : *"Lisible avant tout"* — 2D top-down clean, sprites simples mais expressifs, contrast fort entre héro/alliés (tons chauds, or) et ennemis (tons froids/rouges), fond neutre vert/sable.

**Règle visuelle principale** : À tout moment, le joueur doit pouvoir identifier en un coup d'œil : (1) où est son héro, (2) combien d'archers le suivent, (3) où est le château, (4) d'où viennent les ennemis.

**Principes visuels** :
1. Héro = couleur unique distinctive (or/bleu roi), jamais confondu avec les ennemis ou les archers
2. Ennemis = palette distincte et cohérente (rouge foncé, silhouettes menaçantes)
3. Or = jaune vif animé, visible même sur fond clair
4. Zones d'interaction = highlight clair (cercle pulsant vert quand activable, gris quand pas encore)

**Couleurs** : Chaud (or, bleu roi) pour les alliés. Froid/saturé (rouge, violet sombre) pour les ennemis. Neutre (vert herbe, sable) pour la map.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Kingshot (démo Unity) | Mécanique complète : joystick, archers suiveurs, tours, or, pathfinding château | 2D top-down au lieu de 3D isométrique. On retire les éléments non-essentiels. | Proof of concept visuel et mécanique direct |
| Vampire Survivors | Auto-shoot satisfaisant, économie de montée en puissance entre runs | Pas de roguelite, pas de run-to-run progression. Défense d'un point fixe. | Valide l'attrait de l'auto-shooter sur mobile |
| Clash of Clans | Pathfinding ennemi vers structure, attaque corps à corps | Pas de construction de base, pas de multijoueur, pas de timer de construction | Valide l'intérêt pour la défense de base mobile |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-45 ans |
| **Gaming experience** | Casual à mid-core |
| **Time availability** | Sessions courtes (5-20 min) dans les transports, pauses |
| **Platform preference** | Mobile Android, joue principalement sur téléphone |
| **Current games they play** | Subway Surfers, Clash Royale, Vampire Survivors mobile |
| **What they're looking for** | Satisfaction rapide, montée en puissance visible, peu de friction |
| **What would turn them away** | Tutoriels longs, menus complexes, mort punitive, grind excessif |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | Godot 4.6 (GDScript) — configuré. 2D natif, export Android, CLI-friendly. |
| **Key Technical Challenges** | Steering ennemi vers château (MVP : direction_to, pas de NavMesh), NavigationServer2D pour Vertical Slice+, Object Pooling enemies/projectiles dès le début, joystick virtuel fixed-anchor |
| **Device Target** | Android mid-range 2022+ (ex : Snapdragon 680, Adreno 610, 4GB RAM). Frame rate floor : 60fps stable avec 20 ennemis + 8 archers + 4 tours actifs simultanément. |
| **Art Style** | 2D top-down, sprites simples, lisibilité mobile prioritaire |
| **Art Pipeline Complexity** | Low — sprites 2D statiques/animés simples, pas de rig 3D |
| **Audio Needs** | Minimal — SFX tirs, pièces collectées, ennemis morts, alarme château |
| **Networking** | Aucun |
| **Content Volume** | 1 map, 3-5 types d'ennemis, 1 héro, archers, 3-4 zones d'interaction, vagues infinies |
| **Procedural Systems** | Spawn des vagues semi-procédural (escalade paramétrée), pas de génération de map |

---

## Risks and Open Questions

### Design Risks

- **Monotonie du loop** : Une seule map + loop infini peut lasser. Mitigation : escalade de difficulté bien dosée, feedback visuel fort de progression d'armée.
- **Décisions économiques trop évidentes** : Si "recruter des archers" est toujours mieux que "construire une tour", il n'y a plus de tension. Mitigation : tester les coûts en prototype.
- **Lisibilité mobile** : Trop d'unités à l'écran peut rendre la map illisible sur petit écran. Mitigation : cap sur le nombre d'unités simultanées, sprites clairement distincts.

### Technical Risks

- **Pathfinding mobile perf** : NavigationServer2D avec 20-50 ennemis simultanés sur mobile Android. Mitigation : profiling dès le prototype, utiliser NavigationAgent2D avec navigation mesh simple.
- **Object pooling archers + ennemis** : Instancier/détruire en permanence = GC spikes. Mitigation : pool de nodes réutilisables dès le départ.
- **Joystick tactile** : Précision et confort du joystick virtuel Godot sur petits écrans. Mitigation : tester sur device réel très tôt.

### Market Risks

- **Saturé** : Le tower defense mobile est un genre très encombré. Mitigation : le différenciateur "joystick unique / armée spatiale" est concret et démo-able en 30 secondes.
- **Rétention long-terme sans meta-progression** : Sans run-to-run progression, la rétention peut baisser vite. Mitigation : accepté pour la v1, progression prévue en scope étendu.

### Scope Risks

- **Art pipeline solo** : Créer tous les sprites seul peut bloquer. Mitigation : commencer avec des placeholders géométriques (cercles colorés) et remplacer progressivement.

### Open Questions

- **Cap d'archers suiveurs : 8** — validé en prototype (2026-05-17). Formation V lisible et non-chaotique à 8 archers simultanés. Cap définitif à confirmer avec map geometry (formation width vs. corridors navigables).
- **Quel est le coût exact de construction d'une tour ?** → À tester en prototype avec une session de playtest économique.
- **La forge améliore quoi exactement ?** (dégâts, cadence de tir, portée ?) → À définir lors du design system Forge.
- **Combien de tours sur la map ?** → À définir lors du design de la map.

---

## MVP Definition

**Core hypothesis** : *"Le loop joystick-mouvement + auto-shoot + collecte d'or + recrutement d'un archer est satisfaisant à lui seul, sans tours, forge, ni château."*

**Required for MVP** :
1. Héro mobile via joystick virtuel fixe en bas-gauche (ancrage fixe, déclenchement moitié basse de l'écran)
2. Tir automatique du héro sur ennemis dans son rayon (cercle visible)
3. 1 type d'ennemi avec steering en ligne droite vers le château (pas de NavMesh en MVP)
4. Ennemis droppent de l'or, aspiration automatique dans rayon (magnet_r = 170px validé)
5. 1 zone de recrutement d'archer (dwell trigger 0.8s + feedback barre de progression)
6. Archers suivent le héro en formation V, tirent automatiquement
7. **Château avec HP + Game Over** : barre de vie visible, ennemis infligent des dégâts au contact, Game Over si HP = 0 (requis pour tester Pillar 4 "Tension sans panique")
8. **Caméra follow** : caméra suit le héro avec lerp (smooth follow) — requis pour que la map ne soit pas statique

**Explicitly NOT in MVP** :
- Tours construites et dépôt d'archers
- Forge / upgrade
- Vagues structurées (spawn continu d'ennemis, pas de countdown entre vagues)
- Art final (placeholders géométriques acceptés)
- Sons

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 map placeholder, 1 ennemi, 1 bâtiment | Joystick + auto-shoot + or + recrutement archer | 2-3 semaines |
| **Vertical Slice** | 1 map jouable, 3 types ennemis | MVP + tours + dépôt archers + château HP + Game Over + 5 vagues | 6-8 semaines |
| **Alpha** | Map finalisée, 5 types ennemis | Vertical slice + forge + vagues infinies + balancing initial | 10-14 semaines |
| **Full Vision** | Map polished, 5+ ennemis, boss waves | Alpha + art final + SFX + score + rétention légère | 4-5 mois |

---

## Next Steps

- [x] Engine configuré : Godot 4.6 / GDScript / Android
- [x] `/prototype joystick-archer-gold` — **PROCEED** (2026-05-17). Validé : formation V, gold magnet, joystick feel. Learnings : joystick fixe requis, caméra follow MVP-obligatoire. Voir `prototypes/garrison-concept/REPORT.md`.
- [x] `/prototype economy-spatial` — **PROCEED** (2026-05-17). Validé : dwell trigger 0.8s, tension décisionnelle spatiale confirmée. Voir `prototypes/economy-spatial-concept/REPORT.md`.
- [ ] `/art-bible` — établir la direction visuelle avant les GDDs
- [ ] `/map-systems` — décomposer en systèmes individuels (Hero, Archer, Tower, Enemy, Economy, Wave)
- [ ] `/design-system hero-movement` — GDD détaillé du système de déplacement et tir
- [ ] `/design-system economy` — GDD de l'économie (or, coûts, escalade)
- [ ] `/design-system enemy-wave` — GDD des vagues ennemies et pathfinding
- [ ] `/design-system archer-tower` — GDD du pool d'archers et des tours
- [ ] `/create-architecture` — blueprint architectural
- [ ] `/gate-check pre-production` — avant de lancer la production
