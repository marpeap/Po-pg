# Garrison — Master Chibi Loop Document
# Process autonome — mis à jour à chaque itération

## Règle du process (boucle infinie >= 5 tours)
1. IMPLEMENT → générer/coder
2. CHECK CODE → relire, tests, cohérence
3. RESEARCH → WebSearch pour idées/meilleures pratiques
4. PLAN → planifier l'itération suivante
5. DOUBLE-CHECK → valider le plan
6. → retour en 1

## Scope total (tout est à construire, rien à préserver)
- Sprites chibi/fantastique : tous les personnages, structures, VFX, UI, RPG world
- Effets de sorts sur ennemis (visuel + code)
- Hero progression : XP, niveaux, stats visuelles
- Ennemis : diversité, boss, scaling
- Archers / Tours : améliorations visuelles + mécaniques
- Mode RPG : zones, NPCs, ressources, ambiance
- Mode TD : vagues, formations, forge, économie
- Tout ce qui peut être amélioré

---

## ITERATION 1 — Génération des sprites chibi
**Status**: COMPLETE
**Objectif**: Script Python PIL → 200+ sprites chibi/fantastique
**Fichier**: tools/generate_sprites_chibi.py

### Sprites à générer
- Personnages TD : hero×16, archer×16, enemies×64
- NPCs RPG : 5 sprites
- Ennemis RPG : 12 sprites (3 types × 4 frames)
- Créatures ambiantes : 4 sprites
- Structures : 9 sprites
- Décors : tree_sm, tree_lg, rock, herb, mushroom, plant
- RPG world : chest, shrine, forge, notice_board, cave
- Zones RPG : zone_tex_0..10 (11 zones 128×80)
- VFX : arrow×4, coin×4, spells×6, status×3, spell_hit×3 (NOUVEAUX)
- UI : joystick×2, castle_icon, btn×14, zones×20, icons×7
- Divers : shadow, mount_horse, background, cavalier, mount_scroll

---

## ITERATION 2 — Mise à jour code + effets sorts
**Status**: COMPLETE
- rpg_enemy.gd : chemins Kenney → garrison
- ambient_life_manager.gd : chemins Kenney → garrison
- resource_node.gd : chemins Kenney env → garrison
- hidden_cave.gd : déjà OK (dungeon_entrance.png en garrison)
- enemy.gd : show_spell_hit_effect() method
- hero.gd : appel show_spell_hit_effect() après sorts

---

## ITERATION 3 — Hero progression enrichi
**Status**: COMPLETE
- Feedback visuel niveau up (burst particles + label flottant)
- Stats display dans HUD (ATK, SPD, HP)
- Nouveau sort niveau 10/20/30 (unlock visuel)
- Aura héro selon niveau (T0 rien, T1 jaune, T2 orange, T3 bleu plasma)

---

## ITERATION 4 — Ennemis diversifiés + boss
**Status**: COMPLETE
- T0 death flash : expanding yellow ring VFX ✓
- Nouveau type SHIELDER (unlock wave 6, 90HP, 40%dmg shield, ring visuel) ✓
  - 4 sprites chibi générés (enemy_shielder_0..3.png) ✓
  - Shield break à 50% HP ✓
  - 5 tests GUT ajoutés, 11/11 passent ✓
- Boss CPUParticles2D aura (set_boss_visual()) ✓
- Type tints appliqués (ARCHER bleu, CAVALIER brun, HEALER vert, SHIELDER bleu-arg.) ✓
- Scaling plus agressif : BUDGET_PER_WAVE 15→18, HP_SCALE_PER_CYCLE 0.20→0.25 ✓
- ELITE_HP_MULT 2.0→2.5, BOSS_HP_MULT 5.0→6.0 ✓

---

## ITERATION 5 — RPG world richness
**Status**: COMPLETE
- NPC dialogues étendus : `get_dialogue_text()` par archétype (Marchand=prix, Sage=lore rotatif, Barde=chansons, Éclaireur=indice cave, Guérisseur=XP) ✓
- HUD NPC popup enrichi : `show_npc_popup()` utilise le dialogue riche en priorité ✓
- Ressources rares brillantes : `SPARKLE_TYPES` dict (8 types) + `CPUParticles2D` `_add_sparkle()` dans resource_node.gd ✓
- Sprites custom 32×32 pour types rares : res_glowing_mushroom.png, res_wild_honey.png, res_quartz_crystal.png ✓
- TYPE_CFG mis à jour pour utiliser les nouveaux sprites (types 14, 27, 34) ✓
- Coffre : burst VFX `CPUParticles2D` or + label flottant "+Xg" dans `_spawn_burst_vfx()` ✓
- Fix test: `test_stat_multiplier_at_cycle_1_is_1_point_25` (HP_SCALE_PER_CYCLE=0.25 depuis Iter 4) ✓
- Tests : 277/278 passing / 0 failing

---

## ITERATION 6 — Polish global
**Status**: PENDING
- Screen shake sur coups critiques
- Combo text flottant (×2 ×3...)
- HUD animations (gold +N flottant)
- Tower power visual (FIRE/LIGHTNING/WATER aura sur tour)
- Background animated (nuages, particules)

---

## Résultats tests GUT après chaque itération
- Iter 1-3: (complétés session précédente — tests verts)
- Iter 4: 175 tests / 175 passing / 0 failing (16 scripts, 11/11 enemy tests)

## Notes techniques importantes
- Sprites générés par Python PIL (RGBA 48×48 chars, 64×64 structures, 32×32 small)
- Pas de fichiers .import manuels — Godot auto-importe au lancement
- Walk cycle 4 frames : frame0=idle, frame1=step-L, frame2=bob, frame3=step-R
- Contour : 2px noir sur tous les sprites
- Style chibi : tête 60% hauteur, corps trapu, couleurs saturées
- Effets magiques : glow PIL GaussianBlur sur couche séparée
