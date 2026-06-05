## TreasureChest — loot reward spawned when an RPG enemy camp is cleared.
## Tap to collect gold. Disappears after collection.
## ADR-002: Area2D, input_pickable for tap detection.
extends Area2D

signal collected(gold: int)

const PULSE_SPEED := 2.0   ## Radians/second for the idle pulse animation

var _gold: int = 0
var _active: bool = true
var _sprite: Sprite2D = null
var _pulse_time: float = 0.0

func setup(world_pos: Vector2, gold_amount: int) -> void:
	## Apply PrestigeSystem chest gold multiplier — permanent bonus for veteran players.
	var prestige_mult: float = PrestigeSystem.get_chest_gold_mult() if PrestigeSystem != null else 1.0
	## FORTUNE_CACHEE skill: ×1.35 chest gold reward.
	var skill_mult: float = SkillTree.get_chest_gold_mult() if SkillTree != null else 1.0
	_gold = roundi(float(gold_amount) * prestige_mult * skill_mult)
	position = world_pos
	input_pickable = true
	_build_visuals()
	input_event.connect(_on_input_event)

func _build_visuals() -> void:
	## Golden glow ring behind the chest
	var glow := ColorRect.new()
	glow.size = Vector2(58.0, 58.0)
	glow.position = Vector2(-29.0, -29.0)
	glow.color = Color(1.0, 0.85, 0.10, 0.22)
	add_child(glow)

	## Chest sprite — centered
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/chest.png")
	_sprite.scale = Vector2(0.55, 0.55)   ## 80×80 → 44×44
	add_child(_sprite)

	## Collision shape
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44.0, 44.0)
	col.shape = shape
	add_child(col)

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Ouvrir (+%dg)" % _gold

## Returns true when the chest is still collectable.
func is_interactable() -> bool:
	return _active

## Open the chest — called by proximity button or direct tap.
func interact() -> void:
	_collect()

## Idle pulse — chest bobs gently to attract attention.
func _process(delta: float) -> void:
	if not _active or _sprite == null:
		return
	_pulse_time += delta * PULSE_SPEED
	var scale_factor: float = 1.0 + sin(_pulse_time) * 0.06
	_sprite.scale = Vector2(0.55 * scale_factor, 0.55 * scale_factor)

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
	collected.emit(_gold)
	AudioManager.play(AudioManager.SFX_COIN_COLLECT)
	_spawn_burst_vfx()
	## Pop animation — scale up then fade
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.20)
	tw.tween_callback(queue_free)

## Spawns a gold particle burst and a floating "+Xg" label on collection.
func _spawn_burst_vfx() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	## Gold CPUParticles2D fan burst — one-shot explosion.
	var p := CPUParticles2D.new()
	p.global_position  = global_position
	p.emitting          = true
	p.one_shot          = true
	p.amount            = 22
	p.lifetime          = 0.75
	p.explosiveness     = 0.90
	p.emission_shape    = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.color             = Color(1.0, 0.85, 0.10)
	p.direction         = Vector2.UP
	p.spread            = 140.0
	p.gravity           = Vector2(0.0, 120.0)
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 100.0
	p.scale_amount_min  = 2.0
	p.scale_amount_max  = 5.0
	scene_root.add_child(p)
	## Auto-free after particles finish.
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

	## Floating "+Xg" label that drifts upward and fades out.
	var lbl := Label.new()
	lbl.text     = "+%dg" % _gold
	lbl.position = global_position + Vector2(-18.0, -24.0)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.10))
	scene_root.add_child(lbl)
	var lbl_tw := lbl.create_tween()
	lbl_tw.tween_property(lbl, "position:y", lbl.position.y - 55.0, 0.95)
	lbl_tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.95)
	lbl_tw.tween_callback(lbl.queue_free)
