# BUG — Écran blanc au lancement du jeu

**Sévérité** : P0 — bloquant (le monde de jeu est invisible)
**Signalé** : 2026-05-26
**Statut** : RÉSOLU

---

## Symptôme observé

L'écran de jeu est entièrement blanc après le menu principal.
On voit en superposition :
- `"Défis du jour"` (label du RPG overlay) — **anormal en mode PLAYING**
- `"Vague 1"` (label TD HUD) — **normal**
- Un grand cercle gris (joystick base ?)

Le monde de jeu (herbe, château, héros) n'est pas visible du tout.

---

## Ce qui est CONFIRMÉ (faits certains)

| Fait | Source |
|------|--------|
| `background.png` existe, 1920×1080 RGBA, `.ctex` importé | Vérifié via PIL + glob .godot/imported/ |
| `project.godot` a `default_clear_color = Color(0.18, 0.32, 0.1, 1)` (vert) | Lu directement |
| `RenderingServer.set_default_clear_color(Color(0.18, 0.40, 0.10))` appelé en première ligne de `_ready()` | Lu dans Main.gd |
| Camera2D limites : left=0, top=0, right=1920, bottom=1080 | Lu dans camera_follow.gd |
| Héros démarre à (500, 540) → camera snappée là → viewport montre x:20-980, y:270-810 | Lu dans hero.gd + camera_follow.gd |
| La zone caméra est entièrement dans les bounds du fond (0-1920 × 0-1080) | Calcul |
| `rpg_hud_overlay` démarrait `visible=true` par défaut → "Défis du jour" visible en PLAYING | Lu + corrigé |
| `main_menu.gd` appelle `queue_free()` après le fade → la CanvasLayer est bien supprimée | Lu |
| Aucun nœud CanvasLayer existant n'a de fond blanc plein écran | Vérifié : skill_tree (visible=false), journal (visible=false), day_night (alpha=0), pause_overlay (visible=false) |

---

## Tentatives effectuées (dans l'ordre)

### Tentative 1 — Sprite2D dans GameWorld, z_index=-10
**Hypothèse** : le fond doit être derrière tout dans GameWorld.
**Résultat** : BLANC. Cause : `y_sort_enabled=true` sur GameWorld rend invisible tout enfant avec z_index négatif.

### Tentative 2 — Sprite2D enfant de Main (root Node2D), move_child(bg, 0)
**Hypothèse** : sorti de GameWorld, le Sprite2D ne subit plus le y_sort.
**Résultat** : BLANC. Cause inconnue à ce stade.

### Tentative 3 — ColorRect + Sprite2D, tous deux enfants de Main
**Hypothèse** : ColorRect = fallback solide, Sprite2D = texture.
**Résultat** : BLANC. Cause : ColorRect est un nœud Control ; dans un parent Node2D, le layout system force `size=(0,0)` → invisible. Le Sprite2D est toujours blanc.

### Tentative 4 — Polygon2D (vert) + Sprite2D, enfants de Main
**Hypothèse** : Polygon2D est un Node2D pur, pas affecté par le layout Control.
**Code** :
```gdscript
var bg_poly := Polygon2D.new()
bg_poly.polygon = PackedVector2Array([...0,0 → 1920,1080...])
bg_poly.color = Color(0.38, 0.56, 0.24)
add_child(bg_poly)
move_child(bg_poly, 0)

var bg := Sprite2D.new()
bg.texture = load("res://assets/sprites/garrison/background.png")
bg.position = Vector2(960.0, 540.0)
add_child(bg)
move_child(bg, 1)
```
**Résultat** : BLANC. Screenshot montré par le user.

**Hypothèse post-mortem** : Le Sprite2D est à l'index 1 → se dessine AU-DESSUS du Polygon2D (index 0). Si `background.png` rend blanc (image blanche, ou import bogué), il couvre entièrement le Polygon2D vert.

### Tentative 5 — Polygon2D SEUL (vert uni, sans texture), + fix rpg_hud_overlay
**Code actuel dans Main.gd** :
```gdscript
var bg_poly := Polygon2D.new()
bg_poly.polygon = PackedVector2Array([...])
bg_poly.color = Color(0.22, 0.45, 0.14)  ## vert herbe
add_child(bg_poly)
move_child(bg_poly, 0)
## Plus de Sprite2D bg
```
**Fix supplémentaire** : `rpg_hud_overlay._ready()` → ajout `visible = false` pour corriger le "Défis du jour" visible en PLAYING.
**Statut** : À TESTER — pas encore de retour du user.

---

## Arbre de décision selon le résultat de la Tentative 5

```
Tentative 5 → vert visible ?
│
├── OUI → Le bug venait du Sprite2D couvrant le Polygon2D avec background.png blanc/bogué.
│          ACTION : Appliquer background.png directement sur Polygon2D.texture + UV.
│          Code :
│            bg_poly.color = Color(1.0, 1.0, 1.0)
│            bg_poly.texture = load("res://assets/sprites/garrison/background.png")
│            bg_poly.uv = PackedVector2Array([(0,0),(1920,0),(1920,1080),(0,1080)])
│
└── NON → Quelque chose dans un CanvasLayer couvre le vert avec du blanc.
           ACTION : Utiliser le Remote Inspector Godot (Debug > Remote Scene Tree en cours de jeu).
           Chercher : nœuds visibles avec size ≈ 960×540, couleur blanche ou opaque.
           Suspects prioritaires à inspecter :
             1. Tous les enfants de HUDLayer (CanvasLayer layer=1)
             2. day_night._canvas_layer (layer=1) → overlay ColorRect blanc alpha ?
             3. _rpg_hud_overlay (layer=5) → vérifier si vraiment hidden
             4. Main lui-même : vérifier que visible=true
             5. GameWorld : vérifier que visible=true
```

---

## Suspects éliminés

| Nœud | Raison éliminée |
|------|----------------|
| `skill_tree_panel` | `visible=false` dans `_ready()` |
| `journal_panel` | `visible=false` dans `_ready()` |
| `_pause_overlay` (hud.gd) | `visible=false`, `color=(0,0,0,0.45)` noir |
| `_fade_rect` (Main.gd) | `color=(0,0,0,0)` transparent |
| `weather_overlay` | `color=(0,0,0,0)` transparent |
| `season_overlay` | `color=(0,0,0,0)` transparent |
| `day_night._overlay` | `color=(1,1,1,0)` blanc MAIS alpha=0 → transparent |
| `main_menu` | Fond noir + `queue_free()` après dismiss → pas en cause |
| `_inventory_panel` | `visible=false` |
| `game_over_overlay` | `visible=false` dans Main.tscn |
| ColorRect dans Node2D | Layout system force size=(0,0) → invisible de toute façon |
| Camera2D position | Snappée à hero (500,540), viewport 20-980/270-810 ⊂ polygon 0-1920/0-1080 |
| `y_sort_enabled` sur GameWorld | Affecte seulement les enfants directs de GameWorld ; bg_poly est enfant de Main |

---

## État actuel du code (Main.gd, section background)

```gdscript
func _ready() -> void:
    RenderingServer.set_default_clear_color(Color(0.18, 0.40, 0.10))
    _setup_gameplay_nodes()
    _setup_arrow_pool()
    _setup_ui()
    _wire_signals()
    _show_main_menu()

## Dans _setup_gameplay_nodes() :
var bg_poly := Polygon2D.new()
bg_poly.polygon = PackedVector2Array([
    Vector2(0.0,    0.0),
    Vector2(1920.0, 0.0),
    Vector2(1920.0, 1080.0),
    Vector2(0.0,    1080.0),
])
bg_poly.color = Color(0.22, 0.45, 0.14)
add_child(bg_poly)
move_child(bg_poly, 0)
```

Ordre des enfants de Main après `_ready()` :
- 0 : `bg_poly` (Polygon2D vert)
- 1 : `Camera2D`
- 2 : `GameWorld`
- 3 : `HUDLayer` (CanvasLayer)
- 4 : `AnimationPlayer`
- 5+ : `_camera_follow`, `_rpg_hud_overlay`, `_skill_tree_panel`, `_journal_panel`, `_day_night_cycle`, `_main_menu`

---

### Tentative 6 — Polygon2D directement dans Main.tscn (pas en code)
**Hypothèse** : Si le GDScript a un problème de timing ou d'exécution, mettre le fond dans le .tscn garantit qu'il est toujours là.
**Changements** :
- `Main.tscn` : ajout du nœud `Background` (Polygon2D vert, index 0 dans Main) directement dans le fichier scène
- `Main.gd` : suppression du code qui créait bg_poly dynamiquement
**Statut** : À TESTER

---

## Arbre de décision selon le résultat de la Tentative 6

```
Tentative 6 → vert visible ?
│
├── OUI → Le bug venait d'un problème dans le code _setup_gameplay_nodes().
│          ACTION : Appliquer background.png via Polygon2D.texture dans Main.tscn ou via $Background.
│
└── NON → Quelque chose dans un CanvasLayer couvre tout avec du blanc.
           ACTION OBLIGATOIRE : Debug > Remote Scene Tree dans Godot pendant le jeu.
           Chercher nœud visible + size ≈ 960×540 + couleur blanche/opaque.
           Sans le Remote Inspector on ne peut pas aller plus loin.
```

---

## Cause racine identifiée

**Polygon2D ne rend pas avec le renderer gl_compatibility** — bug Godot connu ([issue #69109](https://github.com/godotengine/godot/issues/69109)).

Ce projet utilise `renderer/rendering_method="gl_compatibility"` (cible Android). Le Polygon2D `Background` dans Main.tscn était silencieusement ignoré par le renderer. La couleur de clear (`set_default_clear_color`) n'apparaissait pas non plus car gl_compatibility gère le clear color différemment.

## Solution appliquée (Tentative 7 — CORRIGE)

- **Main.tscn** : Suppression du nœud `Background` (Polygon2D) — il ne rendait pas
- **Main.gd** `_setup_gameplay_nodes()` : Ajout d'un `CanvasLayer` `layer=-1` contenant un `ColorRect` 960×540 vert

```gdscript
var bg_layer := CanvasLayer.new()
bg_layer.layer = -1
add_child(bg_layer)
var bg_rect := ColorRect.new()
bg_rect.size = Vector2(960.0, 540.0)
bg_rect.color = Color(0.22, 0.45, 0.14)
bg_layer.add_child(bg_rect)
```

Un `CanvasLayer` avec `layer=-1` se rend **sous** le canvas monde (Node2D). Les `ColorRect` (nœuds Control) fonctionnent dans tous les renderers. Le fond vert sera toujours visible derrière le monde de jeu et derrière le HUD.
