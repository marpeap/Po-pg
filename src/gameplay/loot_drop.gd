## LootDrop — floating collectible spawned when an RPG enemy dies.
## Represents a resource drop (Bone, Hide, Shadow Essence, etc.).
## Bobs gently to attract attention. Tap to collect.
## Auto-despawns after 20 seconds if not collected.
## ADR-002: Area2D, input_pickable for touch detection.
extends Area2D

const BOB_SPEED    := 3.0     ## Radians/s for idle float animation
const DESPAWN_SEC  := 20.0   ## Seconds before auto-disappear
const FLOAT_AMP    := 5.0    ## Pixels of vertical bobbing
const MAGNET_RADIUS := 80.0  ## px — hero within this range pulls the drop
const MAGNET_SPEED  := 220.0 ## px/s toward hero when in magnet range

var _type: int = ResourceInventory.Type.BONE
var _amount: int = 1
var _active: bool = true
var _age: float = 0.0
var _rect: ColorRect = null
var _hero_ref: Node2D = null  ## Cached once from "players" group

## Drop colors per resource type (12 defined — matches ResourceInventory.Type)
const DROP_COLORS: Array[Color] = [
	Color(0.40, 0.25, 0.10),  ## WOOD
	Color(0.55, 0.55, 0.55),  ## STONE
	Color(0.15, 0.70, 0.20),  ## HERB
	Color(0.55, 0.28, 0.70),  ## MUSHROOM
	Color(0.90, 0.90, 0.85),  ## SILK
	Color(0.55, 0.55, 0.65),  ## IRON_ORE
	Color(0.22, 0.22, 0.22),  ## COAL
	Color(0.35, 0.70, 1.00),  ## CRYSTAL
	Color(1.00, 0.30, 0.30),  ## GEMSTONE
	Color(0.42, 0.28, 0.08),  ## HARDWOOD
	Color(0.85, 0.85, 0.75),  ## BONE
	Color(0.65, 0.42, 0.22),  ## HIDE
	Color(0.45, 0.00, 0.55),  ## SHADOW_ESSENCE
]

func setup(world_pos: Vector2, res_type: int, res_amount: int) -> void:
	_type   = res_type
	_amount = res_amount
	position = world_pos
	input_pickable = true
	_build_visuals()
	input_event.connect(_on_input_event)

func _build_visuals() -> void:
	var col_idx: int = clampi(_type, 0, DROP_COLORS.size() - 1)
	var col: Color = DROP_COLORS[col_idx]

	## Small glowing circle
	_rect = ColorRect.new()
	_rect.size = Vector2(16.0, 16.0)
	_rect.position = Vector2(-8.0, -8.0)
	_rect.color = col
	add_child(_rect)

	## Brighter inner dot
	var inner := ColorRect.new()
	inner.size = Vector2(8.0, 8.0)
	inner.position = Vector2(-4.0, -4.0)
	inner.color = col.lightened(0.40)
	add_child(inner)

	## Amount label above the drop
	var lbl := Label.new()
	lbl.text = "+%d" % _amount
	lbl.position = Vector2(-10.0, -22.0)
	lbl.size = Vector2(20.0, 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", col.lightened(0.25))
	add_child(lbl)

	## Collision
	var c := CollisionShape2D.new()
	c.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	c.shape = shape
	add_child(c)

func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	## One-time hero lookup via group
	if _hero_ref == null and is_inside_tree():
		var players: Array[Node] = get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			_hero_ref = players[0] as Node2D
	## Magnet: move toward hero when within MAGNET_RADIUS
	var dist_to_hero: float = INF
	if _hero_ref != null:
		dist_to_hero = position.distance_to(_hero_ref.position)
	if dist_to_hero < MAGNET_RADIUS:
		position = position.move_toward(_hero_ref.position, MAGNET_SPEED * delta)
		## Auto-collect on contact
		if dist_to_hero < 16.0:
			_collect()
			return
	else:
		## Gentle vertical bob only when not magnetised
		position.y += sin(_age * BOB_SPEED) * FLOAT_AMP * delta
	## Fade out last 4 seconds before despawn
	if _age > DESPAWN_SEC - 4.0:
		modulate.a = clampf((DESPAWN_SEC - _age) / 4.0, 0.0, 1.0)
	if _age >= DESPAWN_SEC:
		queue_free()

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		_collect()

func _collect() -> void:
	if not _active:
		return
	_active = false
	input_pickable = false
	ResourceInventory.add(_type, _amount)
	AudioManager.play(AudioManager.SFX_COIN_COLLECT)
	## Quick scale-up then disappear
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.10)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
