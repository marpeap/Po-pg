## RPGEnemy — zone-based enemy for the exploration map.
## Patrols around its camp, chases the hero on aggro, attacks on contact.
## NEVER targets the castle — belongs only to the exploration world.
## Added to group "enemies" so hero spells hit it (ADR-002: group lookup).
## ADR-002: Area2D, no NavMesh, direction_to steering (same as TD enemies).
extends Area2D

enum EState { PATROL, CHASE, ATTACK, RETURN }

## Movement
const SPEED_PATROL  := 65.0    ## px/s while wandering
const SPEED_CHASE   := 135.0   ## px/s while chasing / returning

## Range thresholds
const PATROL_RADIUS := 100.0   ## Max roam distance from camp_center
const AGGRO_RADIUS  := 200.0   ## Hero within this → start chasing
const ATTACK_RANGE  := 48.0    ## Hero within this → deal damage
const CHASE_BREAK   := 330.0   ## Hero beyond this → give up, return

## Combat
const MAX_HP           := 25
const ATTACK_DAMAGE    := 6
const ATTACK_COOLDOWN  := 1.8   ## Seconds between hits

## Visual type — set by RpgEnemyCamp before setup() to pick the correct unit sprite.
## 0=Infantry (tier 0), 1=Archer (tier 1), 2=Elite (tier 2).
var _visual_type: int = 0

## Kenney Medieval RTS unit sprites per visual type (CC0, 64×64).
const UNIT_SPRITE_PATHS: Array[String] = [
	"res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Unit/medievalUnit_01.png",
	"res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Unit/medievalUnit_09.png",
	"res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Unit/medievalUnit_17.png",
]

## Pool-compatible flag — hero_spells._apply_spell() checks enemy.get("_alive").
var _alive: bool = true
var _unit_sprite: Sprite2D = null  ## Unit sprite — used for hit flash modulate
var _hp_bar: ColorRect = null      ## HP bar overlay (green → red)

## Loot table — set by RpgEnemyCamp. Each entry: [ResourceInventory.Type, amount, probability].
var _loot_table: Array = []

var hp: int = MAX_HP
var _max_hp: int = MAX_HP
var _speed_mult: float = 1.0  ## Set by RpgEnemyCamp for difficulty tiers
var _state: int = EState.PATROL
var _camp_center: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _hero_ref: Node2D = null

## Poison state — applied by VENOM_BLADE. Ticks 1 HP/s by default.
var _poisoned: bool = false
var _poison_timer: float = 0.0    ## Remaining poison duration (seconds)
var _poison_dps: float = 0.0     ## Damage per second while poisoned
var _poison_tick: float = 0.0    ## Accumulator — fires damage each full second

## Emitted when this enemy's HP reaches 0. RpgEnemyCamp listens to count deaths.
signal died(pos: Vector2)

## Called by RpgEnemyCamp after add_child(). Sets camp anchor and hero reference.
func setup(camp_pos: Vector2, hero: Node2D) -> void:
	_camp_center = camp_pos
	_hero_ref = hero
	position = camp_pos + Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))
	_pick_patrol_target()
	_build_visuals()
	add_to_group("enemies")

func _build_visuals() -> void:
	## Unit sprite — replaces the red square; type set by RpgEnemyCamp.
	_unit_sprite = Sprite2D.new()
	_unit_sprite.texture = load(UNIT_SPRITE_PATHS[clampi(_visual_type, 0, 2)])
	_unit_sprite.scale = Vector2(0.5, 0.5)
	add_child(_unit_sprite)

	## HP bar background (dark)
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(22.0, 4.0)
	bar_bg.position = Vector2(-11.0, -17.0)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.80)
	add_child(bar_bg)

	## HP bar fill (green, shrinks as HP drops)
	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(22.0, 4.0)
	_hp_bar.position = Vector2(-11.0, -17.0)
	_hp_bar.color = Color(0.20, 0.85, 0.25)
	add_child(_hp_bar)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	col.shape = shape
	add_child(col)

## --- State machine ---

func _process(delta: float) -> void:
	if not _alive:
		return
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return
	match _state:
		EState.PATROL:  _tick_patrol(delta)
		EState.CHASE:   _tick_chase(delta)
		EState.ATTACK:  _tick_attack(delta)
		EState.RETURN:  _tick_return(delta)
	## Poison tick — 1 damage per second while poisoned
	if _poisoned:
		_poison_timer -= delta
		_poison_tick  += delta
		if _poison_tick >= 1.0:
			_poison_tick -= 1.0
			take_damage(int(_poison_dps))
		if _poison_timer <= 0.0:
			_poisoned    = false
			_poison_dps  = 0.0

## Effective aggro radius — reduced by hero's _stealth (Silk Cloak: 0.65 → 35% of base).
func _effective_aggro_radius() -> float:
	var stealth: float = 0.0
	if _hero_ref != null and "_stealth" in _hero_ref:
		stealth = float(_hero_ref.get("_stealth"))
	return AGGRO_RADIUS * (1.0 - stealth)

func _tick_patrol(delta: float) -> void:
	if _hero_ref != null and position.distance_to(_hero_ref.position) < _effective_aggro_radius():
		_state = EState.CHASE
		return
	position += position.direction_to(_patrol_target) * SPEED_PATROL * _speed_mult * delta
	if position.distance_to(_patrol_target) < 8.0:
		_pick_patrol_target()

func _tick_chase(delta: float) -> void:
	if _hero_ref == null:
		_state = EState.RETURN
		return
	var dist: float = position.distance_to(_hero_ref.position)
	if dist > CHASE_BREAK:
		_state = EState.RETURN
		return
	if dist < ATTACK_RANGE:
		_state = EState.ATTACK
		return
	position += position.direction_to(_hero_ref.position) * SPEED_CHASE * _speed_mult * delta

func _tick_attack(delta: float) -> void:
	if _hero_ref == null:
		_state = EState.RETURN
		return
	var dist: float = position.distance_to(_hero_ref.position)
	if dist > ATTACK_RANGE:
		_state = EState.CHASE
		return
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_COOLDOWN
		if _hero_ref.has_method("take_damage"):
			_hero_ref.take_damage(ATTACK_DAMAGE)

func _tick_return(delta: float) -> void:
	position += position.direction_to(_camp_center) * SPEED_CHASE * delta
	if position.distance_to(_camp_center) < 15.0:
		_state = EState.PATROL
		_pick_patrol_target()
	## Re-aggro if hero wanders close while returning
	elif _hero_ref != null and position.distance_to(_hero_ref.position) < _effective_aggro_radius() * 0.65:
		_state = EState.CHASE

## --- Combat ---

## Called by hero_spells._apply_spell() or any future source.
func take_damage(amount: int) -> void:
	if not _alive:
		return
	hp -= amount
	## Brief bright flash on the unit sprite
	if _unit_sprite != null:
		var tw := create_tween()
		tw.tween_property(_unit_sprite, "modulate", Color(3.0, 3.0, 3.0), 0.06)
		tw.tween_property(_unit_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.12)
	## Update HP bar
	if _hp_bar != null:
		var ratio: float = float(hp) / float(max(_max_hp, 1))
		_hp_bar.size.x = 22.0 * ratio
		_hp_bar.color = Color(1.0 - ratio, 0.15 + ratio * 0.70, 0.10)
	if hp <= 0:
		_die()

## Apply poison: stacks duration (takes the max), resets tick accumulator.
func apply_poison(dps: float, duration: float) -> void:
	if not _alive:
		return
	_poisoned    = true
	_poison_dps  = maxf(_poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)
	_poison_tick  = 0.0
	## Green tint while poisoned
	if _unit_sprite != null:
		_unit_sprite.modulate = Color(0.55, 1.0, 0.45)

## Apply speed slow. factor < 1.0 slows; factor ≈ 0 = stun. Resets after duration.
func apply_slow(factor: float, duration: float) -> void:
	if not _alive:
		return
	_speed_mult = minf(_speed_mult, factor)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if _alive:
			_speed_mult = 1.0)

func _die() -> void:
	_alive = false
	visible = false
	_spawn_death_vfx()
	_spawn_loot()
	died.emit(position)

## Expanding orange ring that fades out over 0.3s — added to the parent map.
func _spawn_death_vfx() -> void:
	var vfx := Node2D.new()
	get_parent().add_child(vfx)
	vfx.position = position
	var ring := ColorRect.new()
	ring.size = Vector2(26.0, 26.0)
	ring.position = Vector2(-13.0, -13.0)
	ring.color = Color(1.0, 0.45, 0.10, 0.85)
	vfx.add_child(ring)
	var tw := vfx.create_tween()
	tw.tween_property(vfx, "scale", Vector2(2.6, 2.6), 0.30)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.30)
	tw.tween_callback(vfx.queue_free)

## Spawn floating loot drops according to _loot_table.
## Each entry is [res_type, amount, probability]. Skips entries that fail the roll.
func _spawn_loot() -> void:
	if _loot_table.is_empty():
		return
	var drop_script: GDScript = load("res://src/gameplay/loot_drop.gd")
	for entry: Array in _loot_table:
		var res_type: int    = entry[0]
		var amount: int      = entry[1]
		var prob: float      = entry[2]
		if randf() > prob:
			continue
		var drop: Area2D = Area2D.new()
		drop.set_script(drop_script)
		## Add to parent (exploration_map) so it persists after this enemy is hidden
		get_parent().add_child(drop)
		var offset := Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		drop.setup(position + offset, res_type, amount)

## --- Internal ---

func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(20.0, PATROL_RADIUS)
	_patrol_target = _camp_center + Vector2(cos(angle), sin(angle)) * dist
