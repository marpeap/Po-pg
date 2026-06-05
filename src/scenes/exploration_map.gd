## ExplorationMap — 9600×3240 procedural RPG world with 15 themed zones.
## Zones: 5 columns × 3 rows = 15 zones. Each zone is 1920×1080 px.
## Zone index formula: zone_idx = row * 5 + col.
## Zone origin (top-left): Vector2(col * 1920.0, row * 1080.0).
## Difficulty increases south/east — row 0 safe, row 1 mid, row 2 elite.
## Content generated deterministically per zone (seed = zone_idx × 1337).
## Systems: 15+ resources per zone, NPCs, hidden caves, dynamic events, contract boards, hero progression.
##
## Lifecycle: instantiated by Main._do_explore(), freed by Main._do_return().
## Call init(hero) then build_map() after add_child() in Main.
extends Node2D

const MAP_W      := 9600.0
const MAP_H      := 3240.0
const ZONE_W     := 1920.0
const ZONE_H     := 1080.0
const ZONE_COLS  := 5
const ZONE_ROWS  := 3
const ZONE_COUNT := 15

## Hero entry position — Zone 0, left of center, vertically centered.
const ENTRY_POS := Vector2(320.0, 540.0)

## Range around hero within which interactive nodes are active (frustum + process guard).
const ACTIVE_RANGE := 5000.0

## Zone blessing: 30 s dwell in same zone grants a one-time resource bonus.
const BLESSING_DWELL_SEC := 30.0

const KENNEY := "res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/"

## ── Zone definitions ───────────────────────────────────────────────────────
## Each zone: {name, bg_color, instant_pool, timed_pool, danger (bool), deco_style}
## instant_pool / timed_pool: Array of ResourceInventory.Type ints available in this zone.
## danger: true → red vignette pulsing in this zone.
const ZONE_DEFS: Array = [
	## 0  Forêt de l'Éveil
	{n="FORET EVEIL",   col=Color(0.12,0.34,0.12), inst=[0,2,13,14,15,16,17,18,19], timed=[9],      danger=false, deco=0},
	## 1  Clairière Dorée
	{n="CLAIRIERE",     col=Color(0.38,0.34,0.20), inst=[1,20,21,22,23,24],          timed=[5],      danger=false, deco=1},
	## 2  Ruines Ancestrales
	{n="RUINES",        col=Color(0.30,0.26,0.18), inst=[1,10,25],                   timed=[5,6],    danger=false, deco=2},
	## 3  Catacombes Oubliées
	{n="CATACOMBES",    col=Color(0.18,0.15,0.22), inst=[26,27,28],                  timed=[7,8],    danger=false, deco=3},
	## 4  Marécage Murmurant
	{n="MARECAGE",      col=Color(0.14,0.22,0.12), inst=[2,3,29,30,31,32,33],        timed=[7],      danger=false, deco=4},
	## 5  Forêt de Cristal
	{n="FORET CRISTAL", col=Color(0.10,0.20,0.28), inst=[0,34,35,36],                timed=[7,9],    danger=false, deco=5},
	## 6  Terres des Cendres
	{n="CENDRES",       col=Color(0.20,0.18,0.16), inst=[37,38,39,25],               timed=[6],      danger=true,  deco=6},
	## 7  Vallée de Feu
	{n="VALLEE FEU",    col=Color(0.30,0.12,0.05), inst=[41,37],                     timed=[47],     danger=true,  deco=7},
	## 8  Toundra Gelée
	{n="TOUNDRA",       col=Color(0.72,0.82,0.88), inst=[28,39],                     timed=[46,48],  danger=true,  deco=8},
	## 9  Désert de Pierre
	{n="DESERT",        col=Color(0.48,0.42,0.28), inst=[20,33,40,28],               timed=[5,8],    danger=false, deco=1},
	## 10 Temple Sacré
	{n="TEMPLE",        col=Color(0.30,0.26,0.38), inst=[22,4,19],                   timed=[7,44],   danger=false, deco=9},
	## 11 Grottes Profondes
	{n="GROTTES",       col=Color(0.14,0.12,0.18), inst=[10,26,27],                  timed=[42,43],  danger=true,  deco=3},
	## 12 Pics Éthérés
	{n="PICS ETHERES",  col=Color(0.55,0.60,0.75), inst=[16,15],                     timed=[48,50],  danger=true,  deco=10},
	## 13 Nécropole
	{n="NECROPOLE",     col=Color(0.12,0.10,0.16), inst=[10,12],                     timed=[49],     danger=true,  deco=6},
	## 14 Cime Sacrée
	{n="CIME SACREE",   col=Color(0.62,0.65,0.80), inst=[27,22],                     timed=[51,52],  danger=true,  deco=10},
]

## Zone blessing resources — one per zone matching ZONE_DEFS order.
const ZONE_BLESSING_RES: Array[int] = [
	0, 1, 25, 27, 2, 7, 37, 41, 46, 20, 4, 42, 48, 10, 52
]
const ZONE_BLESSING_AMT: Array[int] = [
	3, 3, 2, 2, 3, 1, 2, 1, 1, 3, 1, 1, 1, 1, 1
]

## NPC type per zone (cycles through 5 NPC types for variety).
const ZONE_NPC_TYPE: Array[int] = [0,1,2,3,4, 0,1,2,3,4, 0,1,2,3,4]

## Healing shrine every 2 zones (zones 0,2,4,6,8,10,12,14).
const SHRINE_ZONES: Array[int] = [0, 2, 4, 6, 8, 10, 12, 14]

## Crafting anvil zones.
const ANVIL_ZONES: Array[int] = [2, 6, 10, 14]

## Hidden cave count per zone (total 8 per session — distributed across map).
const CAVE_ZONES: Array[int] = [1, 3, 5, 7, 9, 11, 12, 13]

## Camp tier per zone — escalates by row.
const ZONE_CAMP_TIER: Array[int] = [
	0, 0, 0, 1, 1,   ## Row 0: zones 0-4 (0-1 slight escalation in cols 3-4)
	1, 1, 1, 1, 1,   ## Row 1: zones 5-9
	2, 2, 2, 2, 2,   ## Row 2: zones 10-14
]

## Enemy camps per zone.
const ZONE_CAMP_COUNT: Array[int] = [1,1,2,1,2,1,2,2,1,1,2,2,1,2,1]

## ── Runtime state ──────────────────────────────────────────────────────────

var _hero: Node2D = null
var _crafting_system: Node = null
var _dynamic_events: Node = null
var _interactables: Array[Node2D] = []
var _camp_markers: Array[CanvasItem] = []
var _camps: Array[Node] = []
var _camp_tiers: Array[int] = []   ## Parallel array: tier for each camp by index
var _camps_cleared: int = 0
var _npcs: Array[Node2D] = []
var _danger_vignette_rects: Array[ColorRect] = []
var _vignette_phase: float = 0.0

## Zone blessing state.
var _current_zone_idx: int = -1
var _zone_dwell_timer: float = 0.0
var _zone_blessed: Array[bool] = []

signal gold_earned(amount: int)
signal camp_cleared(camp_index: int)
signal blessing_granted(label: String)
signal event_banner_requested(title: String, description: String, duration: float)
signal dungeon_entered(zone_idx: int, seed_val: int)
## Emitted when any world boss hits phase 2 — Main wires this to EnemyWave.force_boss_wave.
signal boss_phase2_triggered(wave_tier: int)

## ── Zone helper functions ───────────────────────────────────────────────────

func _zone_col(z: int) -> int:
	return z % ZONE_COLS

func _zone_row(z: int) -> int:
	return z / ZONE_COLS

func _zone_origin(z: int) -> Vector2:
	return Vector2(float(_zone_col(z)) * ZONE_W, float(_zone_row(z)) * ZONE_H)

func _zone_center(z: int) -> Vector2:
	return _zone_origin(z) + Vector2(ZONE_W * 0.5, ZONE_H * 0.5)

## Returns zone index for a world position (hero detection).
## Used in _process() to detect current zone.
func _zone_at(world_pos: Vector2) -> int:
	var col: int = clampi(int(world_pos.x / ZONE_W), 0, ZONE_COLS - 1)
	var row: int = clampi(int(world_pos.y / ZONE_H), 0, ZONE_ROWS - 1)
	return row * ZONE_COLS + col

## ── Lifecycle ──────────────────────────────────────────────────────────────

func init(hero: Node2D) -> void:
	_hero = hero
	_zone_blessed.resize(ZONE_COUNT)
	_zone_blessed.fill(false)

	_crafting_system = Node.new()
	_crafting_system.set_script(load("res://src/gameplay/crafting_system.gd"))
	add_child(_crafting_system)
	ItemInventory.item_crafted.connect(_on_item_crafted)

	## Dynamic event manager
	_dynamic_events = Node.new()
	_dynamic_events.set_script(load("res://src/gameplay/dynamic_event_manager.gd"))
	add_child(_dynamic_events)
	_dynamic_events.event_started.connect(_on_event_started)
	_dynamic_events.spawn_ambush_requested.connect(_on_spawn_ambush)
	_dynamic_events.spawn_meteor_nodes_requested.connect(_on_spawn_meteor_nodes)
	_dynamic_events.spawn_migration_drops_requested.connect(_on_spawn_migration_drops)
	_dynamic_events.spawn_rift_camp_requested.connect(_on_spawn_rift_camp)
	_dynamic_events.reveal_zone_resources_requested.connect(_on_reveal_zone_resources)
	add_to_group("exploration_map")

func build_map() -> void:
	_build_background()
	for z: int in range(ZONE_COUNT):
		_build_zone(z)
	_build_contract_board()
	_build_return_portal()
	_build_entry_marker()
	_add_danger_vignettes()
	if _hero != null:
		_dynamic_events.start_events(_hero)

## ── Per-zone procedural build ─────────────────────────────────────────────

func _build_zone(z: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = z * 1337 + 42

	var origin: Vector2 = _zone_origin(z)
	var def: Dictionary = ZONE_DEFS[z]

	## Background decorations (very cheap — just Sprite2D nodes)
	_build_zone_decorations(z, origin, rng, def.deco)

	## Resource nodes — ~16-24 instant per zone across full 2D area
	_spawn_zone_instant_resources(z, origin, rng, def.inst)
	_spawn_zone_timed_resources(z, origin, rng, def.timed)

	## Enemy camps
	_spawn_zone_camps(z, origin, rng)

	## Healing shrine (every other zone) — quadrant position for exploration incentive
	if z in SHRINE_ZONES:
		var shrine_y_frac: float = 0.30 if (_zone_row(z) % 2 == 0) else 0.70
		var shrine_pos := Vector2(
			origin.x + ZONE_W * 0.60,
			origin.y + ZONE_H * shrine_y_frac)
		_spawn_shrine(shrine_pos)

	## Crafting anvil — zone center-right to reward deeper exploration
	if z in ANVIL_ZONES:
		var anvil_pos := Vector2(origin.x + ZONE_W * 0.70, origin.y + ZONE_H * 0.50)
		_spawn_anvil(anvil_pos)

	## Hidden cave — random 2D position within zone
	if z in CAVE_ZONES:
		var cave_pos := Vector2(
			origin.x + rng.randf_range(300.0, ZONE_W - 300.0),
			origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
		_spawn_cave(cave_pos, z, z * 7919 + 13)

	## NPC wanderer — varied 2D position
	var npc_pos := Vector2(
		origin.x + rng.randf_range(400.0, ZONE_W - 400.0),
		origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
	_spawn_npc(npc_pos, ZONE_NPC_TYPE[z])

	## Lore fragment — random 2D position
	var lore_pos := Vector2(
		origin.x + rng.randf_range(300.0, ZONE_W - 300.0),
		origin.y + rng.randf_range(150.0, ZONE_H - 150.0))
	_make_lore_tablet(lore_pos, z)

	## World Boss — zones 0, 7, 13 each host a world boss (Sylvalis / Ignifex / Mortalis).
	## Boss is skipped if previously defeated (ConfigFile check).
	const BOSS_ZONES: Array[int] = [0, 7, 13]
	const BOSS_IDS:   Array[int] = [0, 1, 2]
	var boss_zone_idx: int = BOSS_ZONES.find(z)
	if boss_zone_idx != -1:
		var bid: int = BOSS_IDS[boss_zone_idx]
		var cfg := ConfigFile.new()
		var already_dead: bool = false
		if cfg.load("user://world_bosses.cfg") == OK:
			already_dead = cfg.get_value("defeated", "boss_%d" % bid, false)
		if not already_dead:
			## Place boss in far-right area of the zone (reward for deep exploration)
			var boss_pos := Vector2(origin.x + ZONE_W * 0.82, origin.y + ZONE_H * 0.50)
			_spawn_world_boss(boss_pos, bid)

## ── Background ────────────────────────────────────────────────────────────

func _build_background() -> void:
	for z: int in range(ZONE_COUNT):
		var origin: Vector2 = _zone_origin(z)
		var def: Dictionary = ZONE_DEFS[z]
		## Main zone rect — full 1920×1080 colored background
		var r := ColorRect.new()
		r.size     = Vector2(ZONE_W, ZONE_H)
		r.position = origin
		r.color    = def.col
		r.z_index  = -20
		add_child(r)
		## Procedural texture overlay — tiled 128×128 zone texture at 35% alpha
		var tex_path: String = "res://assets/sprites/garrison/zone_tex_%d.png" % int(def.deco)
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex != null:
			var tr := TextureRect.new()
			tr.texture             = tex
			tr.stretch_mode        = TextureRect.STRETCH_TILE
			tr.texture_repeat      = CanvasItem.TEXTURE_REPEAT_ENABLED
			tr.size                = Vector2(ZONE_W, ZONE_H)
			tr.position            = origin
			tr.modulate            = Color(1.0, 1.0, 1.0, 0.35)
			tr.z_index             = -19
			add_child(tr)
		## Subtle gradient overlay at the BOTTOM edge — darkens the ground
		var ground := ColorRect.new()
		ground.size     = Vector2(ZONE_W, 80.0)
		ground.position = origin + Vector2(0.0, ZONE_H - 80.0)
		ground.color    = Color(0.0, 0.0, 0.0, 0.22)
		ground.z_index  = -19
		add_child(ground)
		## Subtle gradient overlay at the TOP edge — lighter sky
		var sky := ColorRect.new()
		sky.size     = Vector2(ZONE_W, 60.0)
		sky.position = origin
		sky.color    = Color(1.0, 1.0, 1.0, 0.08)
		sky.z_index  = -19
		add_child(sky)
		## Zone border (right and bottom edges only — 4px dark separator)
		if _zone_col(z) < ZONE_COLS - 1:
			var div_right := ColorRect.new()
			div_right.size     = Vector2(4.0, ZONE_H)
			div_right.position = origin + Vector2(ZONE_W - 2.0, 0.0)
			div_right.color    = Color(0.0, 0.0, 0.0, 0.40)
			div_right.z_index  = -17
			add_child(div_right)
		if _zone_row(z) < ZONE_ROWS - 1:
			var div_bottom := ColorRect.new()
			div_bottom.size     = Vector2(ZONE_W, 4.0)
			div_bottom.position = origin + Vector2(0.0, ZONE_H - 2.0)
			div_bottom.color    = Color(0.0, 0.0, 0.0, 0.40)
			div_bottom.z_index  = -17
			add_child(div_bottom)
		## Zone label — subtle, top-left of zone, alpha 0.40
		var lbl := Label.new()
		lbl.text     = def.n
		lbl.position = origin + Vector2(16.0, 12.0)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.40))
		lbl.z_index  = -16
		add_child(lbl)

## ── Zone decorations ──────────────────────────────────────────────────────

func _build_zone_decorations(z: int, origin: Vector2, rng: RandomNumberGenerator, style: int) -> void:
	## Distribute ~25-30 decorative Sprite2D per zone across the full 2D zone area.
	const ENV := "Environment/"
	const STR := "Structure/"
	var tree_tex := [
		KENNEY + ENV + "medievalEnvironment_01.png",
		KENNEY + ENV + "medievalEnvironment_02.png",
		KENNEY + ENV + "medievalEnvironment_03.png",
		KENNEY + ENV + "medievalEnvironment_04.png",
	]
	var rock_tex := [
		KENNEY + ENV + "medievalEnvironment_07.png",
		KENNEY + ENV + "medievalEnvironment_08.png",
		KENNEY + ENV + "medievalEnvironment_09.png",
	]

	match style:
		0:  ## Forest
			for _i: int in range(30):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), tree_tex[rng.randi_range(0, tree_tex.size()-1)], 0.70 + rng.randf() * 0.40, Color.WHITE)
		1:  ## Cleared / ruins
			for _i: int in range(20):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), rock_tex[rng.randi_range(0, rock_tex.size()-1)], 0.80, Color(0.85, 0.80, 0.65))
		2:  ## Ancient ruins
			for _i: int in range(20):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				var tex_choice: int = rng.randi_range(0, 5)
				var t := KENNEY + STR + ("medievalStructure_0%d.png" % (tex_choice + 1))
				_make_sprite(Vector2(px, py), t, 0.65, Color(0.70, 0.65, 0.55, 0.70))
		3:  ## Catacombs / caves
			for _i: int in range(25):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), rock_tex[rng.randi_range(0, rock_tex.size()-1)], 0.75, Color(0.55, 0.48, 0.70))
		4:  ## Swamp
			for _i: int in range(25):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				var t: String = tree_tex[rng.randi_range(0, tree_tex.size()-1)]
				_make_sprite(Vector2(px, py), t, 0.70, Color(0.42, 0.58, 0.38))
		5:  ## Crystal forest
			for _i: int in range(25):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), tree_tex[rng.randi_range(0, tree_tex.size()-1)], 0.80, Color(0.60, 0.85, 1.10))
		6:  ## Ash / dark
			for _i: int in range(20):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), tree_tex[rng.randi_range(0, tree_tex.size()-1)], 0.65, Color(0.35, 0.32, 0.30))
		7:  ## Lava / volcanic
			for _i: int in range(20):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), rock_tex[rng.randi_range(0, rock_tex.size()-1)], 0.80, Color(0.80, 0.35, 0.12))
		8:  ## Ice / tundra
			for _i: int in range(25):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), rock_tex[rng.randi_range(0, rock_tex.size()-1)], 0.85, Color(0.80, 0.92, 1.00))
		9:  ## Temple / sacred
			for _i: int in range(20):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				var tex_choice2: int = rng.randi_range(6, 11)
				var t2 := KENNEY + STR + ("medievalStructure_%02d.png" % tex_choice2)
				_make_sprite(Vector2(px, py), t2, 0.70, Color(0.82, 0.78, 1.00))
		10: ## Ethereal peaks
			for _i: int in range(25):
				var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
				var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
				_make_sprite(Vector2(px, py), rock_tex[rng.randi_range(0, rock_tex.size()-1)], 0.90, Color(0.85, 0.90, 1.20, 0.80))

## ── Resource node spawning ────────────────────────────────────────────────

func _spawn_zone_instant_resources(z: int, origin: Vector2, rng: RandomNumberGenerator, pool: Array) -> void:
	if pool.is_empty():
		return
	var node_script: GDScript = load("res://src/gameplay/resource_node.gd")
	## Divide zone into a 5×4 cell grid (each cell ~384×270 px)
	## Place 1–2 resources per cell with random offset within the cell
	const GRID_COLS := 5
	const GRID_ROWS := 4
	const CELL_W    := 384.0  ## ZONE_W / GRID_COLS = 1920/5
	const CELL_H    := 270.0  ## ZONE_H / GRID_ROWS = 1080/4
	const MARGIN    := 40.0   ## Keep nodes away from cell edges
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			## Skip ~20% of cells to avoid uniform coverage
			if rng.randf() < 0.20:
				continue
			## 1 node per cell always, second node only 40% of the time
			var nodes_in_cell: int = 1 + (1 if rng.randf() < 0.40 else 0)
			for _n: int in range(nodes_in_cell):
				var cell_origin_x: float = origin.x + float(col) * CELL_W
				var cell_origin_y: float = origin.y + float(row) * CELL_H
				var px: float = cell_origin_x + rng.randf_range(MARGIN, CELL_W - MARGIN)
				var py: float = cell_origin_y + rng.randf_range(MARGIN, CELL_H - MARGIN)
				var res_type: int = pool[rng.randi_range(0, pool.size() - 1)]
				var node: Area2D = Area2D.new()
				node.set_script(node_script)
				node.position = Vector2(px, py)
				add_child(node)
				node.setup(res_type)
				_interactables.append(node)

func _spawn_zone_timed_resources(z: int, origin: Vector2, rng: RandomNumberGenerator, pool: Array) -> void:
	if pool.is_empty():
		return
	var node_script: GDScript = load("res://src/gameplay/resource_node_timed.gd")
	var count: int = rng.randi_range(2, 4)
	## Timed nodes favor corners and edges — harder to find
	const POSITIONS: Array[Vector2] = [
		Vector2(0.15, 0.15),   ## Top-left quadrant
		Vector2(0.85, 0.15),   ## Top-right quadrant
		Vector2(0.15, 0.85),   ## Bottom-left quadrant
		Vector2(0.85, 0.85),   ## Bottom-right quadrant
		Vector2(0.50, 0.20),   ## Top center
		Vector2(0.50, 0.80),   ## Bottom center
	]
	## Shuffle to pick random positions without duplicates
	var indices: Array[int] = [0, 1, 2, 3, 4, 5]
	for i in range(indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	for i: int in range(mini(count, indices.size())):
		var pos_frac: Vector2 = POSITIONS[indices[i]]
		var px: float = origin.x + pos_frac.x * ZONE_W + rng.randf_range(-80.0, 80.0)
		var py: float = origin.y + pos_frac.y * ZONE_H + rng.randf_range(-60.0, 60.0)
		px = clampf(px, origin.x + 60.0, origin.x + ZONE_W - 60.0)
		py = clampf(py, origin.y + 60.0, origin.y + ZONE_H - 60.0)
		var res_type: int = pool[rng.randi_range(0, pool.size() - 1)]
		var node: Area2D = Area2D.new()
		node.set_script(node_script)
		node.position = Vector2(px, py)
		add_child(node)
		node.setup(res_type)
		_interactables.append(node)

## ── Camp spawning ─────────────────────────────────────────────────────────

func _spawn_zone_camps(z: int, origin: Vector2, rng: RandomNumberGenerator) -> void:
	var camp_script: GDScript = load("res://src/gameplay/rpg_enemy_camp.gd")
	var tier: int = ZONE_CAMP_TIER[z]
	var count: int = ZONE_CAMP_COUNT[z]
	## Define forbidden area: zone 0's entry region (first 400px of zone 0)
	## For all other zones, camps can be anywhere in the inner 80% of the zone
	const CAMP_MARGIN := 200.0
	## For multi-camp zones, ensure camps are at least 400px apart
	var placed_positions: Array[Vector2] = []
	for _i: int in range(count):
		var attempts: int = 0
		var camp_pos: Vector2 = Vector2.ZERO
		while attempts < 20:
			camp_pos = Vector2(
				origin.x + rng.randf_range(CAMP_MARGIN, ZONE_W - CAMP_MARGIN),
				origin.y + rng.randf_range(CAMP_MARGIN, ZONE_H - CAMP_MARGIN))
			## For zone 0: push camps away from entry (x > 500)
			if z == 0:
				camp_pos.x = maxf(camp_pos.x, origin.x + 500.0)
			## Check minimum separation from other camps in this zone
			var too_close: bool = false
			for prev: Vector2 in placed_positions:
				if camp_pos.distance_to(prev) < 400.0:
					too_close = true
					break
			if not too_close:
				break
			attempts += 1
		placed_positions.append(camp_pos)
		_add_camp_marker(camp_pos, tier)
		var camp: Node = Node.new()
		camp.set_script(camp_script)
		add_child(camp)
		var camp_idx: int = _camps.size()
		camp.setup(camp_pos, _hero, self, tier)
		camp.cleared.connect(
			func(pos: Vector2, gold: int) -> void: _on_camp_cleared(camp_idx, pos, gold))
		_camps.append(camp)
		_camp_tiers.append(tier)

## ── NPC spawning ──────────────────────────────────────────────────────────

func _spawn_npc(pos: Vector2, npc_type: int) -> void:
	var npc_script: GDScript = load("res://src/gameplay/npc_wanderer.gd")
	var npc: Area2D = Area2D.new()
	npc.set_script(npc_script)
	npc.position = pos
	add_child(npc)
	npc.setup(npc_type, pos.x)
	npc.popup_requested.connect(_on_npc_popup)
	_npcs.append(npc)
	_interactables.append(npc)

## ── Cave spawning ─────────────────────────────────────────────────────────

func _spawn_cave(pos: Vector2, zone_idx: int, seed_val: int) -> void:
	var cave_script: GDScript = load("res://src/gameplay/hidden_cave.gd")
	var cave: Area2D = Area2D.new()
	cave.set_script(cave_script)
	cave.position = pos
	add_child(cave)
	cave.setup(zone_idx, seed_val)
	cave.cave_revealed.connect(_on_cave_revealed)
	cave.dungeon_entered.connect(func(z: int, s: int) -> void: dungeon_entered.emit(z, s))
	_interactables.append(cave)

## ── Shrine / anvil spawning ───────────────────────────────────────────────

## Spawn a WorldBoss node at the given position.
## Boss is a persistent encounter that requires real fighting — hero auto-attacks + spells.
func _spawn_world_boss(pos: Vector2, boss_id: int) -> void:
	var boss_script: GDScript = load("res://src/gameplay/world_boss.gd")
	if boss_script == null:
		return
	var boss: Node2D = Node2D.new()
	boss.set_script(boss_script)
	boss.position = pos
	add_child(boss)
	boss.setup(boss_id, _hero)
	## Connect boss defeat signal to announce completion and grant gold bonus
	boss.boss_defeated.connect(func(bid: int) -> void:
		var gold_bonus: int = 80 + bid * 60
		var econ_nodes: Array = get_tree().get_nodes_in_group("economy")
		if not econ_nodes.is_empty() and econ_nodes[0].has_method("add_gold"):
			econ_nodes[0].add_gold(gold_bonus)
		get_tree().call_group("hud", "show_boss_announce",
			"Boss Vaincu !", "+%dg  |  Rare loot accordé" % gold_bonus))
	## Phase 2 — boss unleashes an assault wave on the castle (multi-front battle).
	## Read phase2_wave from the boss definition to determine wave tier.
	var wave_tier: int = boss.BOSS_DEFS[boss_id].phase2_wave
	boss.boss_phase2_triggered.connect(func() -> void:
		boss_phase2_triggered.emit(wave_tier))

func _spawn_shrine(pos: Vector2) -> void:
	var shrine_script: GDScript = load("res://src/gameplay/healing_shrine.gd")
	var shrine: Area2D = Area2D.new()
	shrine.set_script(shrine_script)
	add_child(shrine)
	shrine.setup(pos, _hero)
	_interactables.append(shrine)

func _spawn_anvil(pos: Vector2) -> void:
	var anvil_script: GDScript = load("res://src/gameplay/crafting_anvil.gd")
	var anvil: Area2D = Area2D.new()
	anvil.set_script(anvil_script)
	add_child(anvil)
	anvil.setup(pos, _crafting_system)
	_interactables.append(anvil)

## ── Contract board ────────────────────────────────────────────────────────

func _build_contract_board() -> void:
	var board_script: GDScript = load("res://src/gameplay/contract_board.gd")
	## Board 1: Zone 0, right of entry — early contract availability
	var board1_pos := Vector2(600.0, 540.0)
	var board: Area2D = Area2D.new()
	board.set_script(board_script)
	board.position = board1_pos
	add_child(board)
	board.setup(12345)
	board.contracts_panel_requested.connect(_on_contracts_panel_requested)
	board.contract_fulfilled.connect(_on_contract_fulfilled)
	_interactables.append(board)
	## Board 2: Zone 7 center (col=2, row=1) — mid-world hub
	var zone7_origin: Vector2 = _zone_origin(7)
	var board2_pos := zone7_origin + Vector2(ZONE_W * 0.50, ZONE_H * 0.50)
	var board2: Area2D = Area2D.new()
	board2.set_script(board_script)
	board2.position = board2_pos
	add_child(board2)
	board2.setup(67890)
	board2.contracts_panel_requested.connect(_on_contracts_panel_requested)
	board2.contract_fulfilled.connect(_on_contract_fulfilled)
	_interactables.append(board2)

## ── Camp markers ──────────────────────────────────────────────────────────

func _add_camp_marker(camp_pos: Vector2, tier: int) -> void:
	const TENT_TINTS: Array[Color] = [
		Color(1.05, 0.82, 0.65),
		Color(1.05, 0.90, 0.50),
		Color(0.85, 0.60, 1.10),
	]
	var tint: Color = TENT_TINTS[mini(tier, 2)]
	var tent: Sprite2D = _make_sprite(camp_pos + Vector2(-20.0, -18.0),
		KENNEY + "Structure/medievalStructure_16.png", 0.85, tint)
	_camp_markers.append(tent)
	_make_sprite(camp_pos + Vector2(18.0, -12.0),
		KENNEY + "Structure/medievalStructure_01.png", 0.70, tint)
	_make_sprite(camp_pos + Vector2(4.0, 28.0),
		KENNEY + "Environment/medievalEnvironment_21.png", 0.70)
	if tier >= 1:
		_make_sprite(camp_pos + Vector2(-8.0, -36.0),
			KENNEY + "Structure/medievalStructure_17.png", 0.65, tint)

## ── Lore tablet ───────────────────────────────────────────────────────────

const LORE_TEXTS: Array[String] = [
	"Les anciens arbres murmurent.\nCelui qui ecoute entend\nles secrets de la foret.",
	"Ces terres doraient autrefois.\nL'or est parti, la pierre reste.",
	"Ces ruines datent de\nl'ere des Conquerants.\nNul ne sait ce qu'ils cherchaient.",
	"Sous ces catacombes dort\nun tresor oublie depuis\ndes siecles.",
	"L'eau du Marecage n'est\npas corrompue, elle est\nancienne. Tres ancienne.",
	"La Foret de Cristal\nbrille de mille feux\nlorsque la lune se leve.",
	"Les cendres ne meurent\njamais completement.\nElles attendent.",
	"Au coeur du volcan bat\nun feu qui ne s'eteindra\njamais.",
	"La glace ici n'est pas froide.\nElle est endormie.\nElle se souvient.",
	"Le desert garde ses secrets\nsous des couches de sable\net d'os oublies.",
	"Ce temple fut construit\npar des mains inconnues.\nPour des dieux inconnus.",
	"Plus on s'enfonce, plus\nla lumiere devient\nune ancienne amie.",
	"Au-dela des nuages\nvivent des choses qui\nne connaissent pas la peur.",
	"Les morts ici ne\nreposent pas. Ils\nse souviennent aussi.",
	"La Cime Sacree cache\nle secret de la creation\ndu monde entier.",
]

func _make_lore_tablet(world_pos: Vector2, zone_idx: int) -> void:
	_make_sprite(world_pos + Vector2(0.0, -14.0),
		KENNEY + "Structure/medievalStructure_12.png",
		0.68, Color(0.68, 0.62, 0.55, 0.90))
	var icon := Label.new()
	icon.text     = "?"
	icon.position = world_pos - Vector2(6.0, 28.0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 0.85))
	add_child(icon)
	var area := Area2D.new()
	area.input_pickable = true
	area.position = world_pos
	add_child(area)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36.0, 44.0)
	col.shape  = shape
	area.add_child(col)
	var lore_txt: String = LORE_TEXTS[zone_idx % LORE_TEXTS.size()]
	var popup := Label.new()
	popup.text = lore_txt
	popup.position = world_pos + Vector2(-100.0, -90.0)
	popup.size = Vector2(200.0, 80.0)
	popup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup.add_theme_font_size_override("font_size", 10)
	popup.add_theme_color_override("font_color", Color(0.95, 0.92, 0.72))
	var bg := ColorRect.new()
	bg.size     = Vector2(204.0, 84.0)
	bg.position = Vector2(-2.0, -2.0)
	bg.color    = Color(0.18, 0.14, 0.09, 0.90)
	popup.add_child(bg)
	bg.z_index  = -1
	popup.visible = false
	add_child(popup)
	area.input_event.connect(func(_vp: Viewport, event: InputEvent, _si: int) -> void:
		if event is InputEventScreenTouch and event.pressed:
			popup.visible = not popup.visible
			if popup.visible:
				var t := get_tree().create_timer(5.0)
				t.timeout.connect(func() -> void:
					if is_instance_valid(popup):
						popup.visible = false))

## ── Return portal ─────────────────────────────────────────────────────────

func _build_return_portal() -> void:
	## Zone 0, just left of entry — the "gate home"
	const PORTAL_POS := Vector2(100.0, 540.0)
	const RING: Array[Vector2] = [
		Vector2(0.0, -50.0), Vector2(43.0, -25.0), Vector2(43.0, 25.0),
		Vector2(0.0, 50.0), Vector2(-43.0, 25.0), Vector2(-43.0, -25.0),
	]
	for off: Vector2 in RING:
		_make_sprite(PORTAL_POS + off,
			KENNEY + "Environment/medievalEnvironment_10.png",
			0.90, Color(0.55, 0.85, 1.30))
	_make_sprite(PORTAL_POS, "res://assets/sprites/garrison/shrine.png",
		0.85, Color(0.40, 1.10, 1.40, 0.92))

func _build_entry_marker() -> void:
	_make_sprite(ENTRY_POS + Vector2(-28.0, 18.0),
		KENNEY + "Environment/medievalEnvironment_21.png", 0.90, Color(1.20, 1.00, 0.60))
	_make_sprite(ENTRY_POS + Vector2(28.0, 18.0),
		KENNEY + "Environment/medievalEnvironment_21.png", 0.90, Color(1.20, 1.00, 0.60))

## ── Danger vignettes ──────────────────────────────────────────────────────

func _add_danger_vignettes() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	const THICKNESS := 14.0
	const W := 960.0
	const H := 540.0
	for edge: Dictionary in [
		{rect=Rect2(0.0, 0.0, W, THICKNESS)},
		{rect=Rect2(0.0, H - THICKNESS, W, THICKNESS)},
		{rect=Rect2(0.0, 0.0, THICKNESS, H)},
		{rect=Rect2(W - THICKNESS, 0.0, THICKNESS, H)},
	]:
		var r := ColorRect.new()
		r.position = edge.rect.position
		r.size     = edge.rect.size
		r.color    = Color(0.70, 0.08, 0.08, 0.0)
		cl.add_child(r)
		_danger_vignette_rects.append(r)

## ── Process ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _hero == null:
		return
	var hero_pos: Vector2 = _hero.position

	## Danger vignette — pulses red in danger zones.
	var zone_idx_now: int = _zone_at(hero_pos)
	var in_danger: bool = ZONE_DEFS[zone_idx_now].danger
	_vignette_phase += delta * 2.2
	var target_alpha: float = 0.0
	if in_danger:
		target_alpha = 0.18 + 0.14 * sin(_vignette_phase)
	for r: ColorRect in _danger_vignette_rects:
		r.color.a = move_toward(r.color.a, target_alpha, delta * 1.5)

	## Hidden cave proximity reveal check.
	for node: Node2D in _interactables:
		if node.has_method("check_reveal"):
			node.check_reveal(hero_pos)

	## Zone blessing — 30s dwell grant.
	if zone_idx_now != _current_zone_idx:
		_current_zone_idx = zone_idx_now
		_zone_dwell_timer = 0.0
	elif not _zone_blessed[zone_idx_now]:
		_zone_dwell_timer += delta
		if _zone_dwell_timer >= BLESSING_DWELL_SEC:
			_zone_blessed[zone_idx_now] = true
			var res_type: int = ZONE_BLESSING_RES[zone_idx_now]
			var amount: int   = ZONE_BLESSING_AMT[zone_idx_now]
			ResourceInventory.add(res_type, amount)
			var def_name: String = ZONE_DEFS[zone_idx_now].n
			blessing_granted.emit("Benediction %s : +%d" % [def_name, amount])
			HeroProgression.add_xp(20)

## ── Sprite helper ─────────────────────────────────────────────────────────

func _make_sprite(pos: Vector2, tex_path: String, scale_xy: float = 1.0, tint: Color = Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = load(tex_path)
	if tex != null:
		s.texture = tex
	s.position = pos
	s.scale    = Vector2(scale_xy, scale_xy)
	s.modulate = tint
	add_child(s)
	return s

## ── Interactables accessor ────────────────────────────────────────────────

func get_interactables() -> Array[Node2D]:
	return _interactables

## ── Event handlers ────────────────────────────────────────────────────────

func _on_camp_cleared(index: int, camp_pos: Vector2, gold: int) -> void:
	_camps_cleared += 1
	camp_cleared.emit(index)
	## Use stored tier for XP (index ≠ zone_idx — fixed from original bug)
	var tier: int = get_camp_tier(index)
	HeroProgression.add_xp(30 + tier * 20)
	if index >= 0 and index < _camp_markers.size():
		_camp_markers[index].modulate = Color(0.38, 0.38, 0.38, 0.55)
	_spawn_chest(camp_pos + Vector2(0.0, -50.0), gold)

## Returns the tier (0-2) of the camp at [param index]. Returns 0 if unknown.
func get_camp_tier(index: int) -> int:
	if index >= 0 and index < _camp_tiers.size():
		return _camp_tiers[index]
	return 0

func _spawn_chest(pos: Vector2, gold: int) -> void:
	var chest_script: GDScript = load("res://src/gameplay/treasure_chest.gd")
	var chest: Area2D = Area2D.new()
	chest.set_script(chest_script)
	add_child(chest)
	chest.setup(pos, gold)
	chest.collected.connect(func(g: int) -> void: gold_earned.emit(g))

func _on_npc_popup(npc: Node, npc_type: int, title: String) -> void:
	## Forward to Main/HUD for popup display — simple approach via group.
	get_tree().call_group("hud", "show_npc_popup", npc, npc_type, title)

func _on_cave_revealed(_cave: Node) -> void:
	## Notify achievement system of cave discovery.
	AchievementSystem.on_cave_discovered()

func _on_contracts_panel_requested() -> void:
	get_tree().call_group("hud", "show_contracts_panel")

func _on_contract_fulfilled(idx: int, gold: int, xp: int) -> void:
	gold_earned.emit(gold)
	if HeroProgression != null:
		HeroProgression.add_xp(xp)
	if DailyChallenge != null:
		DailyChallenge.on_contract_completed()

func _on_event_started(evt_type: int, name_str: String, description: String, duration: float) -> void:
	event_banner_requested.emit(name_str, description, duration)

func _on_spawn_ambush(world_pos: Vector2) -> void:
	var camp_script: GDScript = load("res://src/gameplay/rpg_enemy_camp.gd")
	var camp: Node = Node.new()
	camp.set_script(camp_script)
	add_child(camp)
	var idx: int = _camps.size()
	camp.setup(world_pos, _hero, self, 2)
	camp.cleared.connect(func(pos: Vector2, gold: int) -> void: _on_camp_cleared(idx, pos, gold))
	_camps.append(camp)
	_add_camp_marker(world_pos, 2)

func _on_spawn_meteor_nodes(zone_idx: int) -> void:
	## Spawn 3 STAR_DUST nodes in the zone using 2D origin.
	var origin: Vector2 = _zone_origin(zone_idx)
	var rng := RandomNumberGenerator.new()
	rng.seed = zone_idx * 5003 + int(Time.get_ticks_msec())
	var node_script: GDScript = load("res://src/gameplay/resource_node_timed.gd")
	for _i: int in range(3):
		var node: Area2D = Area2D.new()
		node.set_script(node_script)
		node.position = Vector2(
			origin.x + rng.randf_range(200.0, ZONE_W - 200.0),
			origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
		add_child(node)
		node.setup(ResourceInventory.Type.STAR_DUST)
		_interactables.append(node)

func _on_spawn_migration_drops(world_pos: Vector2) -> void:
	## Spawn 5 instant drop nodes (FEATHER, FROG_SKIN, BONE).
	var node_script: GDScript = load("res://src/gameplay/resource_node.gd")
	var drop_types: Array[int] = [
		ResourceInventory.Type.FEATHER,
		ResourceInventory.Type.FROG_SKIN,
		ResourceInventory.Type.BONE,
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world_pos.x)
	for i: int in range(5):
		var node: Area2D = Area2D.new()
		node.set_script(node_script)
		node.position = world_pos + Vector2(rng.randf_range(-200.0, 200.0),
			rng.randf_range(-100.0, 100.0))
		add_child(node)
		node.setup(drop_types[rng.randi_range(0, drop_types.size() - 1)])
		_interactables.append(node)

func _on_spawn_rift_camp(world_pos: Vector2) -> void:
	_on_spawn_ambush(world_pos)  ## Elite tier 2 camp — same as ambush.

func _on_reveal_zone_resources(zone_idx: int) -> void:
	## Spawn bonus instant resources in the zone.
	_on_spawn_meteor_nodes(zone_idx)

## Called by Scout NPC via group.
func reveal_nearest_cave(from_pos: Vector2) -> void:
	var closest_dist: float = 99999.0
	var closest_cave: Node2D = null
	for node: Node2D in _interactables:
		if node.has_method("reveal") and node.has_method("is_interactable"):
			if node.is_interactable():
				var d: float = node.global_position.distance_to(from_pos)
				if d < closest_dist:
					closest_dist = d
					closest_cave = node
	if closest_cave != null:
		closest_cave.reveal()

## Called by Main when hero returns — refresh contracts for next expedition.
## Public accessor for the current zone index (used by Main and WorldStateManager).
var current_zone_idx: int:
	get: return _current_zone_idx

## Called by QuestManager routing from Main.
func on_zone_entered(_zone_idx: int) -> void:
	pass  ## Placeholder — QuestManager handles tracking via on_zone_entered directly.

## Spawn a STAR_DUST timed resource node at a random position in the given zone.
## Called by Main._on_star_dust_spawn() during night phase of DayNightCycle.
func spawn_star_dust(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= ZONE_COUNT:
		return
	var origin: Vector2 = _zone_origin(zone_idx)
	var pos := Vector2(origin.x + randf_range(200.0, ZONE_W - 200.0),
			origin.y + randf_range(200.0, ZONE_H - 200.0))
	## ResourceInventory.Type.STAR_DUST = 51 (from resource_inventory.gd index)
	const STAR_DUST_TYPE := 51
	var node_script: GDScript = load("res://src/gameplay/resource_node_timed.gd")
	var node: Area2D = Area2D.new()
	node.set_script(node_script)
	node.position = pos
	add_child(node)
	node.setup(STAR_DUST_TYPE)
	_interactables.append(node)

func on_hero_returned() -> void:
	get_tree().call_group("contract_board", "refresh_contracts")
	if _dynamic_events != null:
		_dynamic_events.stop_events()

func _on_item_crafted(item_id: int) -> void:
	match item_id:
		ItemInventory.Item.IRON_SWORD:
			if _hero != null and _hero.get("_atk_damage_bonus") != null:
				_hero.set("_atk_damage_bonus", (_hero.get("_atk_damage_bonus") as int) + 5)
		ItemInventory.Item.BONE_BOW:
			if _hero != null and _hero.get("_atk_range_bonus") != null:
				_hero.set("_atk_range_bonus", (_hero.get("_atk_range_bonus") as float) + 70.0)
		ItemInventory.Item.HIDE_JERKIN:
			if _hero != null:
				_hero.set("_hp_max_bonus", (_hero.get("_hp_max_bonus") as int) + 20)
		ItemInventory.Item.SILK_CLOAK:
			if _hero != null:
				_hero.set("_stealth", 0.65)
		ItemInventory.Item.CRYSTAL_AMULET:
			if _hero != null:
				_hero.set("_regen_rate", 1.0)
		ItemInventory.Item.SHADOW_MAIL:
			if _hero != null:
				_hero.set("_dmg_reduction", 0.40)
		ItemInventory.Item.CRYSTAL_STAFF:
			if _hero != null:
				_hero.set("_spell_dmg_mult", 1.30)
		_:
			pass
