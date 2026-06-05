## ArcherTower — static structure, auto-fire, 4 visual/stat tiers, elemental powers.
## ADR-002: Area2D for hit detection
## ADR-003: Shared arrow pool (no new pool)
## GDD Req: TR-tower-001
##
## Towers are PERMANENT — they do NOT reset on session_reset.
## Placed by Main when tower_purchased fires. Max 5 on the map.
## Tap a tower to open the tower options panel (power selection + tier upgrade).
extends Node2D

## Visual and stat tier progression.
enum TowerTier {
	WOOD     = 0,  ## Default: wooden platform
	STONE    = 1,  ## Stone blocks: +50 range, +10% dmg  (80g)
	IRON     = 2,  ## Iron tower:   +150 range, +25% dmg, +1 archer (150g)
	FORTRESS = 3,  ## Fortress:     +300 range, +50% dmg, +2 archers (300g)
}

## Elemental powers — selected via HUD options panel.
enum TowerPower {
	NONE,       ## No power (default)
	FIRE,       ## +80% arrow damage
	LIGHTNING,  ## +80% attack speed
	WATER,      ## Arrows apply 80% speed slow to enemies
}

const TOWER_RANGE      := 350.0
const TOWER_SHOOT_IVTL := 1.2        ## Base interval; Forge overrides this
const ARROW_PROJ_SPEED := 400.0      ## Must match Arrow.PROJ_SPEED
const TOWER_TAP_RADIUS := 70.0       ## World-space tap detection radius
const SLOW_FACTOR      := 0.20
const SLOW_DURATION    := 2.5
const FIRE_DMG_MULT    := 1.80
const LIGHTNING_SPD_MULT := 1.80

## Per-tier bonuses (indexed by TowerTier value).
const TIER_RANGE_BONUS:   Array[float]  = [  0.0,  50.0, 150.0, 300.0]
const TIER_DMG_MULT:      Array[float]  = [  1.0,  1.10,  1.25,  1.50]
const TIER_ARCHER_COUNT:  Array[int]    = [    2,     2,     3,     4  ]
const TIER_UPGRADE_COST:  Array[int]    = [    0,    80,   150,   300  ]
const TIER_NAMES:         Array[String] = ["Bois", "Pierre", "Fer", "Forteresse"]
const TIER_SPRITE_PATHS:  Array[String] = [
	"res://assets/sprites/garrison/tower_tier_0.png",
	"res://assets/sprites/garrison/tower_tier_1.png",
	"res://assets/sprites/garrison/tower_tier_2.png",
	"res://assets/sprites/garrison/tower_tier_3.png",
]
## Per-tier archer sprite prefix — 4 walk frames each.
## Tier 0: arc médiéval (vert)  Tier 1: garde police (bleu)
## Tier 2: soldat fusil (kaki)  Tier 3: commando (noir + AR)
const TIER_ARCHER_PREFIXES: Array[String] = [
	"res://assets/sprites/garrison/archer",
	"res://assets/sprites/garrison/archer_t1",
	"res://assets/sprites/garrison/archer_t2",
	"res://assets/sprites/garrison/archer_t3",
]
## Slightly larger sprites for higher-tier soldiers (visual weight).
const TIER_ARCHER_SCALES: Array[float] = [0.36, 0.37, 0.38, 0.40]

## Emitted when player taps this tower — Main responds by showing the options panel.
signal power_requested(tower: Node2D)

var _shoot_timer: float = 0.0
var _arrow_pool: ObjectPool
var _enemy_wave: Node
var _forge: Node
var _power: TowerPower = TowerPower.NONE
var _tier: TowerTier   = TowerTier.WOOD

## Sprite references — cleared and rebuilt each time the tier changes.
var _main_sprite:    Sprite2D          = null
var _archer_sprites: Array[Sprite2D]   = []
var _power_label:    Label             = null
var _tier_label:     Label             = null

## Item effect fields — set by apply_item(); guarded against double-application.
var _applied_items:       Dictionary = {}
var _ballista_range_bonus: float = 0.0   ## BALLISTA_KIT:          +200 range
var _targeting_highest_hp: bool  = false ## TARGETING_RUNE:         target highest-HP enemy
var _power_free:           bool  = false ## POWER_CORE:             powers cost 0g
var _explosive_arrows:     bool  = false ## EXPLOSIVE_TIPS:         +50% effective damage
var _dmg_bonus:            int   = 0     ## REINFORCED_PLATFORM:    +8 per arrow

func _ready() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/garrison/shadow.png")
	shadow.position = Vector2(0.0, 42.0)
	shadow.scale    = Vector2(2.2, 2.2)
	add_child(shadow)

	## Tier label — always present; only shows text for tier > WOOD
	_tier_label = Label.new()
	_tier_label.name      = "TierLabel"
	_tier_label.position  = Vector2(-30.0, -105.0)
	_tier_label.size      = Vector2(60.0, 18.0)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 10)
	_tier_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.35))
	add_child(_tier_label)

	## Power label — shown when an elemental power is active
	_power_label = Label.new()
	_power_label.name     = "PowerLabel"
	_power_label.position = Vector2(-30.0, -88.0)
	_power_label.size     = Vector2(60.0, 22.0)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_label.add_theme_font_size_override("font_size", 13)
	add_child(_power_label)

	_rebuild_sprite()

## Rebuild the tower sprite and archer figures based on the current tier.
## Called once on _ready() and again each time the tier changes.
func _rebuild_sprite() -> void:
	## Remove previous tower sprite
	if _main_sprite != null and is_instance_valid(_main_sprite):
		_main_sprite.queue_free()
		_main_sprite = null
	## Remove previous archer figures
	for sp: Sprite2D in _archer_sprites:
		if is_instance_valid(sp):
			sp.queue_free()
	_archer_sprites.clear()

	## Load tier texture with fallback to the original tower sprite
	var tier_tex: Texture2D = null
	if _tier < TIER_SPRITE_PATHS.size():
		tier_tex = load(TIER_SPRITE_PATHS[_tier]) as Texture2D
	if tier_tex == null:
		tier_tex = load("res://assets/sprites/garrison/archer_tower.png") as Texture2D

	_main_sprite = Sprite2D.new()
	if tier_tex != null:
		_main_sprite.texture = tier_tex
	_main_sprite.scale = Vector2(0.88, 0.88)
	add_child(_main_sprite)

	## Archer figures distributed evenly across the platform.
	## Each tier uses distinct sprites: medieval archer → police → soldat → commando.
	var count: int = TIER_ARCHER_COUNT[_tier]
	var prefix: String = TIER_ARCHER_PREFIXES[_tier]
	var sc: float      = TIER_ARCHER_SCALES[_tier]
	for i: int in range(count):
		var af := Sprite2D.new()
		## Use different walk frames per archer slot for visual variety in the formation.
		af.texture = load("%s_%d.png" % [prefix, i % 4])
		af.scale   = Vector2(sc, sc)
		var offset_x: float
		if count == 1:
			offset_x = 0.0
		else:
			offset_x = -22.0 + float(i) * 44.0 / float(count - 1)
		af.position = Vector2(offset_x, -52.0)
		add_child(af)
		_archer_sprites.append(af)

	## Refresh tier label text
	if _tier_label != null:
		_tier_label.text = "[%s]" % TIER_NAMES[_tier] if _tier > 0 else ""

## Initialize the tower with the shared arrow pool, enemy wave, and optional Forge node.
func setup(arrow_pool: ObjectPool, enemy_wave: Node, forge: Node = null) -> void:
	_arrow_pool  = arrow_pool
	_enemy_wave  = enemy_wave
	_forge       = forge

## Returns the gold cost to upgrade to the next tier (0 if already at max).
func get_next_tier_cost() -> int:
	var next: int = _tier + 1
	if next >= TIER_UPGRADE_COST.size():
		return 0
	return TIER_UPGRADE_COST[next]

## Returns the display name of the next tier, or "" if at max.
func get_next_tier_name() -> String:
	var next: int = _tier + 1
	if next >= TIER_NAMES.size():
		return ""
	return TIER_NAMES[next]

## Upgrade to [param new_tier]. Called by Main after gold is deducted.
func upgrade_to_tier(new_tier: int) -> void:
	_tier = new_tier as TowerTier
	_rebuild_sprite()

## Apply a permanent item effect from crafting. Guarded against double-application.
## item_id values match ItemInventory.Item enum in item_inventory.gd.
func apply_item(item_id: int) -> void:
	if _applied_items.get(item_id, false):
		return
	_applied_items[item_id] = true
	match item_id:
		14:  _ballista_range_bonus = 200.0   ## BALLISTA_KIT
		15:  _explosive_arrows     = true     ## EXPLOSIVE_TIPS
		16:  _targeting_highest_hp = true     ## TARGETING_RUNE
		17:  _power_free           = true     ## POWER_CORE
		18:  _dmg_bonus           += 8        ## REINFORCED_PLATFORM

## Detect taps on this tower and open the options panel.
func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or not event.pressed:
		return
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	var world_pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * event.position
	if world_pos.distance_to(position) <= TOWER_TAP_RADIUS:
		power_requested.emit(self)
		get_viewport().set_input_as_handled()

## Set the active elemental power. Called by Main after gold is deducted
## (or for free if POWER_CORE item has been applied).
func set_power(power_type: int) -> void:
	_power = power_type as TowerPower
	_update_power_label()

## Returns true when powers cost 0g (POWER_CORE item applied).
func is_power_free() -> bool:
	return _power_free

func _update_power_label() -> void:
	if _power_label == null:
		return
	match _power:
		TowerPower.FIRE:      _power_label.text = "[FEU]"
		TowerPower.LIGHTNING: _power_label.text = "[ECLAIR]"
		TowerPower.WATER:     _power_label.text = "[EAU]"
		_:                    _power_label.text = ""

func _process(delta: float) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	_shoot_timer += delta
	var base_ivtl: float = _forge.effective_shoot_ivtl() if _forge != null else TOWER_SHOOT_IVTL
	var ivtl: float = base_ivtl / LIGHTNING_SPD_MULT if _power == TowerPower.LIGHTNING else base_ivtl
	if _shoot_timer >= ivtl:
		_shoot_timer = 0.0
		_fire_at_nearest_enemy()

func _fire_at_nearest_enemy() -> void:
	if _arrow_pool == null or _enemy_wave == null:
		return
	var eff_range: float = TOWER_RANGE + TIER_RANGE_BONUS[_tier] + _ballista_range_bonus
	var target: Node = _find_target(eff_range)
	if target == null:
		return
	var dir: Vector2 = (target.position - position).normalized()

	## Compute effective per-arrow damage
	var base_dmg: int = 8
	if _forge != null and _forge.has_method("effective_proj_damage"):
		base_dmg = _forge.effective_proj_damage()
	var expl_mult: float = 1.50 if _explosive_arrows else 1.0
	var fire_mult: float = FIRE_DMG_MULT if _power == TowerPower.FIRE else 1.0
	var arrow_dmg: int   = roundi(float(base_dmg + _dmg_bonus) * TIER_DMG_MULT[_tier] * expl_mult * fire_mult)

	var slow_f: float = SLOW_FACTOR   if _power == TowerPower.WATER else 1.0
	var slow_d: float = SLOW_DURATION if _power == TowerPower.WATER else 0.0

	## Fire one arrow per stationed archer, with a slight lateral spread
	var count: int   = TIER_ARCHER_COUNT[_tier]
	var vtier: int = _wave_to_visual_tier(_enemy_wave.current_wave)
	for i: int in range(count):
		var arrow: Node = _arrow_pool.checkout()
		if arrow == null:
			break
		var spread_t: float = float(i) - float(count - 1) * 0.5
		var spread: Vector2 = Vector2(-dir.y, dir.x) * spread_t * 6.0
		arrow.activate(position + spread, dir, _arrow_pool, arrow_dmg, slow_f, slow_d, ARROW_PROJ_SPEED, false, false, vtier)

## Find the best target within [param range_px] — nearest by default,
## or highest remaining HP when TARGETING_RUNE has been applied.
func _find_target(range_px: float) -> Node:
	if _enemy_wave == null:
		return null
	var best: Node    = null
	var best_dist: float = range_px
	var best_hp: float   = -1.0
	for enemy: Node in _enemy_wave._pool.all_active():
		var d: float = enemy.position.distance_to(position)
		if d > range_px:
			continue
		if _targeting_highest_hp:
			var hp: float = float(enemy.get("_hp") if enemy.get("_hp") != null else 0)
			if hp > best_hp:
				best_hp   = hp
				best      = enemy
		else:
			if d < best_dist:
				best_dist = d
				best      = enemy
	return best

## Return visual tier index from wave number.
## T0 Medieval (0-9), T1 Elven (10-24), T2 Tracer (25-49), T3 Laser (50+).
static func _wave_to_visual_tier(wave_num: int) -> int:
	if wave_num >= 50: return 3
	if wave_num >= 25: return 2
	if wave_num >= 10: return 1
	return 0
