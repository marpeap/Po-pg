## RpgHealer — support enemy for tier-2 camps.
## Stays near camp center, heals nearby allies every HEAL_INTERVAL seconds.
## Does NOT attack the hero directly — must be killed to stop the healing loop.
## ADR-002: Area2D, no NavMesh.
extends Area2D

const SPEED_PATROL  := 45.0    ## px/s while wandering (slower than combat enemies)
const PATROL_RADIUS := 60.0    ## Max roam distance from camp center
const AGGRO_RADIUS  := 100.0   ## Aggro on hero — just retreats back to camp center
const HEAL_RADIUS   := 120.0   ## px — heals allies within this distance
const HEAL_INTERVAL := 3.0     ## Seconds between heal pulses
const HEAL_AMOUNT   := 15      ## HP restored per pulse per ally
const MAX_HP        := 18      ## Healers are fragile — kill priority for player
const PATROL_SPEED_MULT := 1.0 ## Overridden by RpgEnemyCamp if needed

## Pool-compatible flag
var _alive: bool = true
var _hp: int = MAX_HP
var _max_hp: int = MAX_HP
var _camp_center: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _heal_timer: float = HEAL_INTERVAL  ## Start first heal after interval
var _unit_sprite: Sprite2D = null
var _hp_bar: ColorRect = null
var _loot_table: Array = []

signal died(pos: Vector2)

## Called by RpgEnemyCamp after add_child().
func setup(camp_pos: Vector2, _hero: Node2D) -> void:
	_camp_center = camp_pos
	position = camp_pos + Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 30.0))
	_pick_patrol_target()
	_build_visuals()
	add_to_group("enemies")

func _build_visuals() -> void:
	## Green-tinted cleric sprite to distinguish from combat enemies
	_unit_sprite = Sprite2D.new()
	_unit_sprite.texture = load(
		"res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Unit/medievalUnit_05.png")
	_unit_sprite.scale = Vector2(0.5, 0.5)
	_unit_sprite.modulate = Color(0.55, 1.0, 0.60)  ## Green tint = healer
	add_child(_unit_sprite)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(22.0, 4.0)
	bar_bg.position = Vector2(-11.0, -17.0)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.80)
	add_child(bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(22.0, 4.0)
	_hp_bar.position = Vector2(-11.0, -17.0)
	_hp_bar.color = Color(0.20, 0.85, 0.25)
	add_child(_hp_bar)

	## "+" label so player immediately identifies this as a healer
	var lbl := Label.new()
	lbl.text = "+"
	lbl.position = Vector2(-5.0, -28.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.45))
	add_child(lbl)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)

func _process(delta: float) -> void:
	if not _alive:
		return
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return

	## Patrol slowly around camp center
	position += position.direction_to(_patrol_target) * SPEED_PATROL * delta
	if position.distance_to(_patrol_target) < 8.0:
		_pick_patrol_target()

	## Heal pulse
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = HEAL_INTERVAL
		_pulse_heal()

func _pulse_heal() -> void:
	var healed_any: bool = false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		if node.get("_alive") == false:
			continue
		if not node.has_method("take_damage"):
			continue
		var dist: float = position.distance_to((node as Node2D).position)
		if dist > HEAL_RADIUS:
			continue
		## Apply heal via hp property directly (enemies don't have a heal() method)
		var cur_hp: int = node.get("hp") as int
		var max_hp: int = node.get("_max_hp") as int
		var new_hp: int = mini(cur_hp + HEAL_AMOUNT, max_hp)
		node.set("hp", new_hp)
		## Update the ally's HP bar if it has one
		var ally_bar: ColorRect = node.get("_hp_bar") as ColorRect
		if ally_bar != null and max_hp > 0:
			var ratio: float = float(new_hp) / float(max_hp)
			ally_bar.size.x = 22.0 * ratio
			ally_bar.color = Color(1.0 - ratio, 0.15 + ratio * 0.70, 0.10)
		healed_any = true
	## Visual pulse: brief white flash on healer sprite when it heals
	if healed_any and _unit_sprite != null:
		var tw := create_tween()
		tw.tween_property(_unit_sprite, "modulate", Color(2.5, 3.0, 2.5), 0.08)
		tw.tween_property(_unit_sprite, "modulate", Color(0.55, 1.0, 0.60), 0.18)

func take_damage(amount: int) -> void:
	if not _alive:
		return
	_hp -= amount
	if _unit_sprite != null:
		var tw := create_tween()
		tw.tween_property(_unit_sprite, "modulate", Color(3.0, 3.0, 3.0), 0.06)
		tw.tween_property(_unit_sprite, "modulate", Color(0.55, 1.0, 0.60), 0.12)
	if _hp_bar != null:
		var ratio: float = float(_hp) / float(max(_max_hp, 1))
		_hp_bar.size.x = 22.0 * ratio
		_hp_bar.color = Color(1.0 - ratio, 0.15 + ratio * 0.70, 0.10)
	if _hp <= 0:
		_die()

func _die() -> void:
	_alive = false
	visible = false
	_spawn_death_vfx()
	_spawn_loot()
	died.emit(position)

func _spawn_death_vfx() -> void:
	var vfx := Node2D.new()
	get_parent().add_child(vfx)
	vfx.position = position
	var ring := ColorRect.new()
	ring.size = Vector2(24.0, 24.0)
	ring.position = Vector2(-12.0, -12.0)
	ring.color = Color(0.40, 1.0, 0.45, 0.85)  ## Green death flash for healer
	vfx.add_child(ring)
	var tw := vfx.create_tween()
	tw.tween_property(vfx, "scale", Vector2(2.6, 2.6), 0.30)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.30)
	tw.tween_callback(vfx.queue_free)

func _spawn_loot() -> void:
	if _loot_table.is_empty():
		return
	var drop_script: GDScript = load("res://src/gameplay/loot_drop.gd")
	for entry: Array in _loot_table:
		var res_type: int   = entry[0]
		var amount: int     = entry[1]
		var prob: float     = entry[2]
		if randf() > prob:
			continue
		var drop: Area2D = Area2D.new()
		drop.set_script(drop_script)
		get_parent().add_child(drop)
		var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		drop.setup(position + offset, res_type, amount)

func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(10.0, PATROL_RADIUS)
	_patrol_target = _camp_center + Vector2(cos(angle), sin(angle)) * dist
