## WorldBoss — Boss mondiaux en fin de contenu de zone.
## Inspiré de Monster Hunter (boss multi-phases), FFXIV (raids publics),
## et Diablo (boss marquants qui définissent le power-level).
##
## 3 boss implémentés : Sylvalis (Z0), Ignifex (Z7), Mortalis (Z13).
## Phase 1 : combat en mode EXPLORING (Area2D, attaques spéciales)
## Phase 2 : déclenche une vague TD spéciale via EnemyWave.
##
## Les boss réapparaissent à chaque prestige ou événement saisonnier.
## Persistance : user://world_bosses.cfg
extends Node2D

## ── Boss definitions ─────────────────────────────────────────────────────

enum BossId { SYLVALIS = 0, IGNIFEX = 1, MORTALIS = 2 }

const BOSS_DEFS: Array[Dictionary] = [
	{
		id=BossId.SYLVALIS,
		name="Sylvalis, Gardien de la Foret",
		zone=0,
		hp=2000,
		reward_res=ResourceInventory.Type.GOLDEN_SAP,
		reward_qty=3,
		reward_xp=500,
		lore="Sylvalis existait avant la forêt elle-même. Il est la forêt.",
		phase2_wave=3,  ## déclenche une vague TD de tier 0
		abilities=["root_nova", "growth_pods"],
		tint=Color(0.25, 0.70, 0.25),
		sprite_scale=1.80,
	},
	{
		id=BossId.IGNIFEX,
		name="Ignifex, Cœur du Volcan",
		zone=7,
		hp=4500,
		reward_res=ResourceInventory.Type.PRIMAL_FLAME,
		reward_qty=2,
		reward_xp=800,
		lore="La lave coule depuis Ignifex, pas d'une éruption. Il EST le volcan.",
		phase2_wave=5,
		abilities=["fire_immunity", "cooling_reactor", "eruption"],
		tint=Color(0.90, 0.30, 0.08),
		sprite_scale=2.00,
	},
	{
		id=BossId.MORTALIS,
		name="Mortalis, Archiviste des Morts",
		zone=13,
		hp=7000,
		reward_res=ResourceInventory.Type.CRYSTALLIZED_SHADOW,
		reward_qty=1,
		reward_xp=1200,
		lore="Il ne tue pas ses ennemis. Il les archive pour l'éternité.",
		phase2_wave=8,
		abilities=["soul_drain", "bone_cage", "archive_seal", "reanimation"],
		tint=Color(0.45, 0.35, 0.65),
		sprite_scale=2.20,
	},
]

## ── Runtime state ─────────────────────────────────────────────────────────

var _boss_id: int = -1
var _def: Dictionary = {}
var _hp: int = 0
var _max_hp: int = 0
var _phase: int = 1
var _dead: bool = false
var _hero: Node2D = null

## Ability cooldowns
var _ability_timers: Dictionary = {}

## Area2D for touch/proximity detection
var _area: Area2D = null
var _sprite: Sprite2D = null
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null

const KENNEY := "res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/"

signal boss_hp_changed(current: int, max_hp: int)
signal boss_defeated(boss_id: int)
signal boss_phase2_triggered()
signal ability_used(ability_name: String)

## ── Setup ────────────────────────────────────────────────────────────────

func setup(boss_id: int, hero: Node2D) -> void:
	_boss_id = boss_id
	_hero = hero
	_def = BOSS_DEFS[boss_id]
	_max_hp = _def.hp
	_hp = _max_hp
	_phase = 1
	_dead = false

	## Join "enemies" group so hero auto-attack and spells can hit the boss.
	add_to_group("enemies")

	## Initialize cooldowns for all abilities
	for ab: String in _def.abilities:
		_ability_timers[ab] = 0.0

	_build_visual()

func _build_visual() -> void:
	## Boss sprite (large enemy camp sprite, tinted and scaled)
	_sprite = Sprite2D.new()
	var tex: Texture2D = load(KENNEY + "Structure/medievalStructure_16.png")
	if tex != null:
		_sprite.texture = tex
	_sprite.scale   = Vector2(_def.sprite_scale, _def.sprite_scale)
	_sprite.modulate = _def.tint
	add_child(_sprite)

	## HP bar (above boss)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size     = Vector2(120.0, 10.0)
	_hp_bar_bg.position = Vector2(-60.0, -80.0 * _def.sprite_scale)
	_hp_bar_bg.color    = Color(0.15, 0.05, 0.05)
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size     = Vector2(118.0, 8.0)
	_hp_bar_fill.position = Vector2(-59.0, -79.0 * _def.sprite_scale)
	_hp_bar_fill.color    = _def.tint
	add_child(_hp_bar_fill)

	## Name label
	var name_lbl := Label.new()
	name_lbl.text = _def.name
	name_lbl.position = Vector2(-70.0, -100.0 * _def.sprite_scale)
	name_lbl.size     = Vector2(140.0, 18.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", _def.tint)
	add_child(name_lbl)

	## Interaction area
	_area = Area2D.new()
	_area.input_pickable = true
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80.0 * _def.sprite_scale, 80.0 * _def.sprite_scale)
	col.shape  = shape
	_area.add_child(col)
	add_child(_area)
	_area.input_event.connect(_on_touch)

	## Announce banner via HUD group
	get_tree().call_group("hud", "show_boss_announce",
		_def.name, "Boss Mondial — HP : %d" % _max_hp, 5.0)

## ── Process ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _dead or _hero == null:
		return

	## Update ability cooldowns
	for ab: String in _ability_timers.keys():
		_ability_timers[ab] = maxf(0.0, _ability_timers[ab] - delta)

	## Proximity check — boss abilities activate near hero
	var dist: float = global_position.distance_to(_hero.global_position)
	if dist < 200.0:
		_process_abilities(delta, dist)

	## Phase 2 transition at 50% HP
	if _phase == 1 and _hp <= _max_hp / 2:
		_trigger_phase2()

	## Pulse HP bar fill
	if _hp_bar_fill != null:
		_hp_bar_fill.size.x = 118.0 * (float(_hp) / float(_max_hp))

## ── Abilities ────────────────────────────────────────────────────────────

func _process_abilities(_delta: float, _dist: float) -> void:
	match _boss_id:
		BossId.SYLVALIS:   _sylvalis_abilities()
		BossId.IGNIFEX:    _ignifex_abilities()
		BossId.MORTALIS:   _mortalis_abilities()

func _sylvalis_abilities() -> void:
	## Root nova — slows hero for 2s in proximity
	if _ability_timers.get("root_nova", 0.0) <= 0.0:
		_ability_timers["root_nova"] = 8.0
		if _hero != null and _hero.has_method("apply_slow"):
			_hero.apply_slow(0.40, 2.0)
		ability_used.emit("root_nova")

	## Growth pods — spawns instant resource nodes around boss
	if _ability_timers.get("growth_pods", 0.0) <= 0.0:
		_ability_timers["growth_pods"] = 15.0
		_spawn_resource_pod(ResourceInventory.Type.WILD_BERRY)
		_spawn_resource_pod(ResourceInventory.Type.GOLDEN_SAP)
		ability_used.emit("growth_pods")

func _ignifex_abilities() -> void:
	## Eruption — hero takes damage (placeholder: reduce castle HP via signal)
	if _ability_timers.get("eruption", 0.0) <= 0.0:
		_ability_timers["eruption"] = 12.0
		get_tree().call_group("castle", "take_damage", 5)
		ability_used.emit("eruption")

func _mortalis_abilities() -> void:
	## Soul drain — steals 5 of hero's rarest collected resource
	if _ability_timers.get("soul_drain", 0.0) <= 0.0:
		_ability_timers["soul_drain"] = 10.0
		var nonempty: Array = ResourceInventory.get_nonempty()
		if not nonempty.is_empty():
			## Find rarest
			var rarest: Array = nonempty[0]
			for entry: Array in nonempty:
				if ResourceInventory.get_rarity(entry[0]) > ResourceInventory.get_rarity(rarest[0]):
					rarest = entry
			ResourceInventory.spend(rarest[0], mini(5, rarest[1]))
		ability_used.emit("soul_drain")

func _spawn_resource_pod(res_type: int) -> void:
	var node_script: GDScript = load("res://src/gameplay/resource_node.gd")
	var node: Area2D = Area2D.new()
	node.set_script(node_script)
	node.position = global_position + Vector2(
		randf_range(-120.0, 120.0), randf_range(-60.0, 60.0))
	get_parent().add_child(node)
	node.setup(res_type)

## ── Phase 2 ──────────────────────────────────────────────────────────────

func _trigger_phase2() -> void:
	_phase = 2
	boss_phase2_triggered.emit()
	## Flash red
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 0.2, 0.2), 0.15)
	tw.tween_property(_sprite, "modulate", _def.tint, 0.15)
	tw.set_loops(3)

## ── Damage ────────────────────────────────────────────────────────────────

## Called from hero attacks (hero.gd via group or signal)
func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp = maxi(0, _hp - amount)
	boss_hp_changed.emit(_hp, _max_hp)

	## Hit flash
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		tw.tween_property(_sprite, "modulate", _def.tint, 0.10)

	if _hp <= 0:
		_on_death()

func _on_death() -> void:
	_dead = true
	boss_defeated.emit(_boss_id)
	## Grant rewards
	ResourceInventory.add(_def.reward_res, _def.reward_qty)
	if HeroProgression != null:
		HeroProgression.add_xp(_def.reward_xp)
		HeroProgression.register_discovery()

	## Mark boss as defeated in persistent storage
	var cfg := ConfigFile.new()
	cfg.load("user://world_bosses.cfg")
	cfg.set_value("defeated", "boss_%d" % _boss_id, true)
	cfg.save("user://world_bosses.cfg")

	## Death animation
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: queue_free())

	## Notify HUD
	get_tree().call_group("hud", "show_boss_announce",
		_def.name + " vaincu !", _def.lore, 6.0)

## ── Touch interaction ─────────────────────────────────────────────────────

func _on_touch(_vp: Viewport, event: InputEvent, _si: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		## Show boss info if not in combat proximity
		var dist: float = global_position.distance_to(_hero.global_position) if _hero != null else 9999.0
		if dist > 200.0:
			get_tree().call_group("hud", "show_boss_announce",
				_def.name, _def.lore + "\nHP: %d/%d" % [_hp, _max_hp], 3.0)

## ── Static helpers ────────────────────────────────────────────────────────

static func is_boss_defeated(boss_id: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://world_bosses.cfg") != OK:
		return false
	return cfg.get_value("defeated", "boss_%d" % boss_id, false)
