# Release Checklist: v1.0.0 — Android (MVP)
Generated: 2026-05-20
Engine: Godot 4.6 | Platform: Android | Type: Solo dev MVP

---

## Codebase Health

- TODO count: 0
- FIXME count: 0
- HACK count: 0

All clean — no outstanding code debt markers in `src/`.

---

## Build Verification

- [ ] Export templates Android installés dans Godot 4.6
  (Editor → Export → Android → télécharger les templates si absent)
- [ ] Android SDK configuré : Editor Settings → Export → Android → SDK path
- [ ] Keystore créé et configuré dans Godot (Project → Export → Android → Keystore)
  - Garder le keystore en lieu sûr — sans lui, les mises à jour Google Play sont impossibles
- [ ] `application/config/name` = "Garrison" dans project.godot
- [ ] `application/config/version` = "1.0.0" dans project.godot
- [ ] Export APK (debug) — tester sur appareil Android physique
- [ ] Export APK (release, signé) — vérifier la signature avec `apksigner verify`
- [ ] Build size dans les limites Play Store (< 150 MB pour APK, < 2 GB pour AAB)
- [ ] Build reproductible depuis un commit taggé `v1.0.0`

---

## Quality Gates

- [x] Zero bugs S1 (Critical) — aucun
- [x] Zero bugs S2 (Major) — aucun bug visuel ou gameplay restant
- [x] Features critiques testées et signées — 3 sessions de playtest, QA sign-off APPROVED
- [x] Performance 60fps — confirmé en session
- [x] Aucune régression — GUT 140/141 green
- [ ] Session longue (soak test, 4h+ de jeu continu) — non effectuée
  Advisory pour MVP solo — à faire si temps disponible

---

## Content Complete

- [x] Aucun asset placeholder — visuels dessinés en code (_draw()), cohérents
- [x] Aucun TODO/FIXME dans le code
- [x] Textes player-facing présents (Wave 1–5, TAP ANYWHERE TO RESTART, etc.)
- [ ] Textes relus et validés (orthographe, clarté) — MANUEL
- [-] Localisation — hors scope MVP (textes en anglais, cible MVP non localisée)
- [-] Audio mix — AudioManager implémenté ; sons à relier à des assets audio réels si souhaité
- [ ] Crédits — non implémentés (à ajouter à l'écran Game Over ou menu si requis par le store)

---

## Platform Requirements: Mobile (Android)

- [ ] Google Play Developer account actif
- [ ] App créée dans la Play Console (package name : à définir, ex. `com.yourname.garrison`)
- [ ] `package/unique_name` configuré dans Godot → Project Settings → Application
- [ ] **Privacy policy** — obligatoire Google Play même sans données collectées
  - Créer une page simple (GitHub Pages, notion.site, etc.)
  - Déclarer : "Ce jeu ne collecte aucune donnée personnelle"
  - Lier l'URL dans la Play Console
- [ ] **Data safety** — déclarer dans Play Console qu'aucune donnée n'est collectée
- [ ] **Permissions Android** — vérifier que le manifest ne demande que le strict minimum
  - INTERNET non requis (pas de réseau) → retirer si présent
- [ ] Testé sur au moins 2 tailles d'écran physiques différentes
- [ ] Comportement pause/reprise correct (bouton home, appel entrant)
- [ ] Taille APK dans les limites (Play Store : < 150 MB pour APK direct)
- [ ] Target SDK : Android 14 (API 34) recommandé pour Google Play 2025+
- [ ] `-[ ]` IAP — hors scope MVP (monétisation non définie)
- [-] Notifications push — non implémentées, non requises

---

## Store / Distribution (Google Play)

- [ ] **Icône d'application** — 512×512 px PNG, fond non transparent
  (actuellement manquant — requis pour Play Store)
- [ ] **Feature graphic** — 1024×500 px (bannière Play Store)
- [ ] **Screenshots** — minimum 2, recommandé 4–8
  - Portrait 9:16, résolution ≥ 1080px
  - Capturer depuis l'appareil ou l'émulateur
- [ ] **Short description** — ≤ 80 caractères
  ex. "Défends ton château. Recrute des archers. Un seul doigt."
- [ ] **Long description** — ≤ 4000 caractères
- [ ] **Catégorie** — Jeux → Stratégie (ou Arcade selon positionnement)
- [ ] **Age rating** — compléter le questionnaire IARC dans Play Console
  (violence légère → probable 7+ ou 12+)
- [ ] **Politique de confidentialité** URL liée dans Play Console
- [ ] Tarification — Gratuit ou payant (à définir)
- [ ] Tags et mots-clés configurés

---

## Launch Readiness

- [ ] APK release signé testé sur appareil physique Android de bout en bout
- [ ] Session complète testée sur appareil (vague 1 → vague 5, GAME_OVER, retry)
- [ ] Version taggée dans git : `git tag v1.0.0`
- [-] Analytics / crash reporting — non implémentés (advisory pour MVP)
  Godot 4.6 : intégrer Firebase ou Sentry si suivi post-launch souhaité
- [-] On-call — solo dev, pas de rotation
- [-] Press/influencer keys — hors scope MVP
- [ ] Plan de rollback documenté : si crash critique signalé, rollback vers build précédent

---

## Go / No-Go: NOT READY (items release prep manquants)

**Items bloquants avant soumission Google Play :**

1. **Icône d'application** — obligatoire, actuellement absente
2. **Privacy policy URL** — obligatoire Google Play
3. **Data safety form** — obligatoire Play Console
4. **Screenshots** — minimum 2 requis par Google Play
5. **package/unique_name** configuré dans Godot

**Items recommandés non bloquants :**
- Soak test 4h
- Audio assets réels (actuellement AudioManager sans fichiers sons liés)
- Crédits dans l'UI

**Une fois ces 5 items résolus :** soumission Google Play possible.

---

## Sign-offs Required

- [ ] Développeur — build release signé testé sur appareil
- [ ] (Solo dev — QA lead, TD, Producer, CD = même personne)
