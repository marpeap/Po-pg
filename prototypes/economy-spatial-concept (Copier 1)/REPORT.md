# Concept Prototype Report: Garrison — Economy Spatial

> **Date**: 2026-05-17
> **Prototype Path**: Engine (Godot 4.6 / GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

Si le joueur doit choisir entre intercepter des ennemis (rester au combat) et marcher
vers la zone pour recruter un archer (dwell 0.8s), il ressentira une tension
décisionnelle genuine — confirmé si le joueur hésite visiblement avant de s'engager
vers la zone.

---

## Riskiest Assumption Tested

**Assumption**: La décision spatiale (se déplacer vers une zone économique vs rester
en combat) crée une tension réelle, pas juste un choix mécanique indifférent.

**Result**: Validé. La tension est présente en continu — le joueur doit arbitrer
entre la pression des vagues immédiates et l'investissement économique qui améliore
la survie à long terme.

---

## Approach

Build minimaliste en pure data + `_draw()` — aucun node CharacterBody2D, aucune
physique, toute la logique en arithmétique Vector2 manuelle.

**Path chosen**: Engine (Godot 4.6)
**Reason for path**: La décision spatiale requiert un rendu natif pour que la
distance physique entre le hero, les ennemis et la zone soit perçue correctement.

**Shortcuts taken (intentional):**
- Valeurs hardcodées partout
- Placeholder art : cercles colorés, pas de sprites
- Pas de menu, pas d'écran de démarrage
- Pas de son ni d'animation
- Pas de gestion d'erreur
- Pas de NavMesh — `direction_to(CASTLE_POS)` uniquement
- Pas de structure de vagues — spawn continu

---

## Result

Le prototype répond exactement aux attentes définies en Phase 4. Aucun bug détecté.
La tension décisionnelle est présente en permanence : le joueur hésite avant de
s'éloigner du combat pour rejoindre la zone de recrutement.

Observations spécifiques :
- Le dwell trigger de 0.8s est bien calibré — ni trop court (pas d'achat accidentel),
  ni trop long (pas de friction excessive)
- La progression en arc autour de la zone donne un feedback clair sur l'engagement
- Le label doré (vert si abordable, gris sinon) rend l'état économique lisible
  sans menu
- La caméra lerp + world 1080×1920 valide que la distance zone ↔ castle crée une
  tension de trajet réelle
- Les flèches off-screen pour le château et la zone maintiennent l'orientation
  spatiale même hors champ

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine (Godot 4.6) |
| Iterations to playable | 1 (zéro bug à la première exécution) |
| Prototype duration | 1 session (~2h) |
| Playtesters | 1 interne |
| Feel assessment | Tension décisionnelle continue — le joueur hésite avant chaque trajet vers la zone |
| Hypothesis verdict | **CONFIRMED** |

---

## Recommendation: PROCEED

La tension économique spatiale est validée. Le joueur ressent un vrai arbitrage
entre combat immédiat et investissement en archers. Le dwell trigger 0.8s, le coût
30g, et la distance zone ↔ front de combat produisent tous ensemble la friction
décisionnelle visée. Aucun bug, aucun moment cassé, fonctionnement conforme à la
spec. Le concept est prêt pour la phase GDD.

---

## If Proceeding

Ce que le prototype révèle pour informer les GDDs :

- **Tuning validés** :
  - Dwell trigger : **0.8s** — confirmé
  - Coût archer : **30g** — confirmé
  - Taille monde : **1080×1920** — la distance crée une vraie tension de trajet
  - Camera lerp : **0.10** — fluide, pas de nausée
  - Magnet radius : **170px** — confortable pour collecter sans effort excessif
  - Enemy speed : **70px/s** — la pression reste gérables avec 2 archers initiaux
  - Castle DMG par contact : **8 HP** — urgence sans destruction instantanée

- **Assumptions confirmées** :
  - Castle comme cible des ennemis (pas le hero) → pattern tower defense cohérent
  - 2 archers initiaux → crée une pression économique immédiate
  - World 2× la taille du viewport → la zone est suffisamment loin pour que le
    déplacement représente un coût réel

- **Assumptions non testées** (à adresser dans les GDDs) :
  - Anti-spiral mechanic (validé conceptuellement, pas encore implémenté)
  - Structure de vagues (spawn continu dans le prototype)
  - Cap archer à 8 (non atteint dans le prototype court)

- **Emergent mechanics** :
  - Aucune émergence inattendue — le prototype s'est comporté exactement comme prévu.
    C'est un signal positif : la conception est cohérente.

**Next steps:**
1. `/gate-check` — valider la readiness à avancer vers la phase Systems Design
2. `/map-systems` — décomposer le concept en systèmes (déjà amorcé en systems-index.md)
3. `/design-system hero-movement` — premier GDD en ordre de dépendance
4. `/design-system enemy-wave` — second GDD (dépend de Hero Movement)
5. `/design-system economy` — GDD critique : utiliser les tuning validés ici

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  Aucune — le prototype a confirmé toutes les hypothèses de conception. Le travail
  de design-review préalable (résolution des 5 blockers) a produit un scope précis
  qui s'est implémenté sans surprise.

- **What surprised us that didn't show up in the brainstorm?**
  La lisibilité des flèches off-screen est suffisante pour maintenir l'orientation
  spatiale sans HUD complexe — plus efficace qu'anticipé.

- **What would we test differently next time?**
  Tester avec un deuxième playtesteur externe pour valider que la tension est perçue
  par quelqu'un qui ne connaît pas le design. Le solo dev ne peut pas avoir de
  première impression neutre.

---

> *Prototype code location: `prototypes/economy-spatial-concept/`*
> *This code is throwaway. Never refactor into production.*
