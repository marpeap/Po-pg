## DungeonFloor — système de donjon procédural à 3-5 salles.
## Affiché en overlay sur le jeu (CanvasLayer layer=10).
## 3 types de salles : normale (ressources + combat résumé), piège, boss.
## Le joueur avance de salle en salle (choix GAUCHE/DROITE = avancement linéaire).
## Au boss vaincu : récompenses majeures + fermeture automatique.
## Bouton FUIR disponible à tout moment.
extends CanvasLayer

const MIN_ROOMS := 3
const MAX_ROOMS := 5
## Séquence de types (le boss est toujours en dernière position, généré dynamiquement).
const ROOM_TYPE_POOL: Array[String] = ["normal", "normal", "normal", "trap"]

## Loot de zone par zone_idx (0=Forêt, 1=Clairière, 2=Ruines, …)
const ZONE_RESOURCES: Array[Array] = [
	[ResourceInventory.Type.WOOD,   ResourceInventory.Type.HERB,  ResourceInventory.Type.BIRCH_BARK],
	[ResourceInventory.Type.STONE,  ResourceInventory.Type.CLAY,  ResourceInventory.Type.FLINT],
	[ResourceInventory.Type.BONE,   ResourceInventory.Type.STONE, ResourceInventory.Type.CHARCOAL],
	[ResourceInventory.Type.BONE,   ResourceInventory.Type.SULFUR, ResourceInventory.Type.QUARTZ],
	[ResourceInventory.Type.HERB,   ResourceInventory.Type.REED,  ResourceInventory.Type.ALGAE],
]
const ZONE_NAMES: Array[String] = [
	"Forêt de l'Éveil", "Clairière Dorée", "Ruines Ancestrales",
	"Catacombes", "Marécage", "Forêt de Cristal",
	"Cendres", "Vallée de Feu", "Toundra", "Désert",
	"Temple", "Grottes", "Pics Éthérés", "Nécropole", "Cime Sacrée",
]
## Ressources rares données en récompense de boss selon zone.
const BOSS_RARE_RESOURCES: Array[Array] = [
	[ResourceInventory.Type.SILVER_LICHEN, ResourceInventory.Type.WIND_ESSENCE],
	[ResourceInventory.Type.GOLDEN_SAP,    ResourceInventory.Type.GOLEM_EYE],
	[ResourceInventory.Type.GHOST_MUSHROOM, ResourceInventory.Type.SHADOW_ESSENCE],
	[ResourceInventory.Type.STAR_DUST,     ResourceInventory.Type.ICE_CRYSTAL],
	[ResourceInventory.Type.LAVA_FLOWER,   ResourceInventory.Type.WIND_ESSENCE],
]

signal dungeon_completed(gold: int, resources: Dictionary)
signal dungeon_fled()
signal hero_damaged(amount: int)

var _zone_idx: int = 0
var _seed_val: int = 0
var _rng: RandomNumberGenerator = null
var _rooms: Array[String] = []
var _current_room: int = 0
var _hero_ref: Node2D = null
var _boss_beaten: bool = false

## UI node refs
var _bg: ColorRect = null
var _title_lbl: Label = null
var _desc_lbl: Label = null
var _room_counter_lbl: Label = null
var _left_btn: Button = null
var _right_btn: Button = null
var _flee_btn: Button = null
var _reward_lbl: Label = null
var _icon_rect: ColorRect = null

func _ready() -> void:
	layer = 10

## Entry point — called by Main after instantiating.
func setup(zone_idx: int, seed_val: int, hero: Node2D) -> void:
	_zone_idx = zone_idx
	_seed_val = seed_val
	_hero_ref = hero
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val
	_generate_rooms()
	_build_ui()
	_enter_room(_rooms[0])

## Generate the room sequence: 2-4 non-boss rooms + boss finale.
func _generate_rooms() -> void:
	_rooms.clear()
	var non_boss_count: int = _rng.randi_range(MIN_ROOMS - 1, MAX_ROOMS - 1)
	## Shuffle the pool and pick non_boss_count rooms from it.
	var pool: Array[String] = []
	for t: String in ROOM_TYPE_POOL:
		pool.append(t)
	## Fisher-Yates shuffle using our seeded RNG.
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i: int in range(non_boss_count):
		_rooms.append(pool[i % pool.size()])
	## Always end with boss.
	_rooms.append("boss")

func _build_ui() -> void:
	## Full-screen dark overlay (960×540).
	_bg = ColorRect.new()
	_bg.size = Vector2(960.0, 540.0)
	_bg.color = Color(0.05, 0.03, 0.08, 0.94)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	## Titre principal — "DONJON — Zone N" en haut, centré.
	_title_lbl = Label.new()
	_title_lbl.position = Vector2(0.0, 18.0)
	_title_lbl.size = Vector2(960.0, 34.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color("#FFC107"))
	var zone_name: String = ZONE_NAMES[clampi(_zone_idx, 0, ZONE_NAMES.size() - 1)]
	_title_lbl.text = "DONJON — %s" % zone_name
	add_child(_title_lbl)

	## Compteur de salles — haut-droit.
	_room_counter_lbl = Label.new()
	_room_counter_lbl.position = Vector2(820.0, 18.0)
	_room_counter_lbl.size = Vector2(130.0, 28.0)
	_room_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_room_counter_lbl.add_theme_font_size_override("font_size", 14)
	_room_counter_lbl.add_theme_color_override("font_color", Color("#BDBDBD"))
	_room_counter_lbl.text = "Salle 1/%d" % _rooms.size()
	add_child(_room_counter_lbl)

	## Icône colorée centrale — indique le type de salle (80×80).
	_icon_rect = ColorRect.new()
	_icon_rect.size = Vector2(80.0, 80.0)
	_icon_rect.position = Vector2(440.0, 80.0)
	_icon_rect.color = Color(0.15, 0.55, 0.20)  ## vert = normal par défaut
	add_child(_icon_rect)

	## Description de la salle — centré, 3 lignes max, largeur 700px.
	_desc_lbl = Label.new()
	_desc_lbl.position = Vector2(130.0, 180.0)
	_desc_lbl.size = Vector2(700.0, 80.0)
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_font_size_override("font_size", 15)
	_desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	add_child(_desc_lbl)

	## Récompenses label — centré, couleur or, visible après action dans la salle.
	_reward_lbl = Label.new()
	_reward_lbl.position = Vector2(130.0, 270.0)
	_reward_lbl.size = Vector2(700.0, 60.0)
	_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_lbl.add_theme_font_size_override("font_size", 14)
	_reward_lbl.add_theme_color_override("font_color", Color("#FFD700"))
	_reward_lbl.visible = false
	add_child(_reward_lbl)

	## Bouton GAUCHE — avancer (bleu, bas-gauche).
	_left_btn = _make_btn("< AVANCER", Color("#2980B9"), 100, 380, 200, 50)
	_left_btn.pressed.connect(_on_advance_pressed)
	add_child(_left_btn)

	## Bouton DROITE — avancer (vert, bas-droit).
	_right_btn = _make_btn("AVANCER >", Color("#27AE60"), 660, 380, 200, 50)
	_right_btn.pressed.connect(_on_advance_pressed)
	add_child(_right_btn)

	## Bouton FUIR — centre-bas.
	_flee_btn = _make_btn("FUIR", Color("#7F8C8D"), 410, 460, 140, 36)
	_flee_btn.add_theme_font_size_override("font_size", 13)
	_flee_btn.pressed.connect(_on_flee_pressed)
	add_child(_flee_btn)

func _make_btn(label: String, col: Color, x: int, y: int, w: int, h: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = Vector2(float(x), float(y))
	btn.size = Vector2(float(w), float(h))
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.corner_radius_bottom_left = 6
	st.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", st)
	return btn

## Load and display a room event. Disables advance buttons until resolved.
func _enter_room(room_type: String) -> void:
	_room_counter_lbl.text = "Salle %d/%d" % [_current_room + 1, _rooms.size()]
	_reward_lbl.visible = false
	## Disable advance buttons until player has seen the result.
	_left_btn.disabled = true
	_right_btn.disabled = true

	match room_type:
		"normal":
			_room_normal()
		"trap":
			_room_trap()
		"boss":
			_room_boss()
		_:
			_room_normal()

func _room_normal() -> void:
	_icon_rect.color = Color(0.12, 0.55, 0.18)
	_title_lbl.text = "Salle ordinaire"
	## Pick zone-appropriate resources.
	var zone_res: Array = ZONE_RESOURCES[clampi(_zone_idx, 0, ZONE_RESOURCES.size() - 1)]
	var res_type: int = zone_res[_rng.randi_range(0, zone_res.size() - 1)]
	var res_qty: int = _rng.randi_range(2, 6)
	_desc_lbl.text = "Vous fouilllez la salle et trouvez des matériaux utiles.\nDes créatures rôdaient ici, mais elles ont fui à votre approche."
	## Delayed reward reveal (simulate exploration time).
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		ResourceInventory.add(res_type, res_qty)
		HeroProgression.add_xp(10)
		_reward_lbl.text = "+%d %s  |  +10 XP" % [res_qty, ResourceInventory.SHORT_NAMES[res_type]]
		_reward_lbl.visible = true
		_left_btn.disabled = false
		_right_btn.disabled = false
		AudioManager.play(AudioManager.SFX_DWELL_COMPLETE))

func _room_trap() -> void:
	_icon_rect.color = Color(0.75, 0.10, 0.10)
	## RANDONNEUR skill: trap immunity — the hero avoids all trap damage.
	var immune: bool = SkillTree != null and SkillTree.has_danger_immunity()
	_title_lbl.text = "PIEGE !" if not immune else "PIEGE ! (Immunise)"
	_desc_lbl.text = "Des dalles s'effondrent sous tes pas !\nTu évites le pire mais subis des dégâts."
	var damage: int = _rng.randi_range(5, 15)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		if immune:
			_reward_lbl.text = "Compétence RANDONNEUR : piege evite !"
			_reward_lbl.add_theme_color_override("font_color", Color("#66BB6A"))
		else:
			hero_damaged.emit(damage)
			_reward_lbl.text = "-%d HP !" % damage
			_reward_lbl.add_theme_color_override("font_color", Color("#EF5350"))
			AudioManager.play(AudioManager.SFX_CASTLE_HIT)
		_reward_lbl.visible = true
		_left_btn.disabled = false
		_right_btn.disabled = false)

func _room_boss() -> void:
	_icon_rect.color = Color(0.50, 0.05, 0.60)
	_title_lbl.text = "BOSS — Gardien du Donjon"
	_desc_lbl.text = "Une créature ancienne surgit des ténèbres !\nLe combat fait rage pendant de longues secondes…"
	_left_btn.disabled = true
	_right_btn.disabled = true
	_flee_btn.disabled = true
	## Simulate combat with a 2-second tween delay.
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(_on_boss_defeated)

func _on_boss_defeated() -> void:
	_boss_beaten = true
	var gold: int = _rng.randi_range(30, 80)
	var zone_boss_res: Array = BOSS_RARE_RESOURCES[clampi(_zone_idx, 0, BOSS_RARE_RESOURCES.size() - 1)]
	var rare_qty: int = _rng.randi_range(3, 8)
	var rare_type: int = zone_boss_res[_rng.randi_range(0, zone_boss_res.size() - 1)]
	## Grant XP to hero.
	HeroProgression.add_xp(50)
	## Build result map.
	var res_dict: Dictionary = {}
	res_dict[rare_type] = rare_qty
	_desc_lbl.text = "Victoire ! Le Gardien s'effondre dans un rugissement final.\nSes trésors te sont désormais accessibles."
	_reward_lbl.text = "+%dg  |  +%d %s  |  +50 XP" % [gold, rare_qty, ResourceInventory.SHORT_NAMES[rare_type]]
	_reward_lbl.add_theme_color_override("font_color", Color("#FFD700"))
	_reward_lbl.visible = true
	_flee_btn.visible = false
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	## Show a "QUITTER" button instead of GAUCHE/DROITE.
	_left_btn.text = "QUITTER"
	_left_btn.disabled = false
	_right_btn.text = "QUITTER"
	_right_btn.disabled = false
	## Disconnect advance handlers and wire to completion.
	if _left_btn.pressed.is_connected(_on_advance_pressed):
		_left_btn.pressed.disconnect(_on_advance_pressed)
	if _right_btn.pressed.is_connected(_on_advance_pressed):
		_right_btn.pressed.disconnect(_on_advance_pressed)
	_left_btn.pressed.connect(func() -> void: dungeon_completed.emit(gold, res_dict); queue_free())
	_right_btn.pressed.connect(func() -> void: dungeon_completed.emit(gold, res_dict); queue_free())

func _on_advance_pressed() -> void:
	if _boss_beaten:
		return
	_current_room += 1
	if _current_room >= _rooms.size():
		return
	_enter_room(_rooms[_current_room])

func _on_flee_pressed() -> void:
	dungeon_fled.emit()
	queue_free()
