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
	## Pop animation — scale up then fade
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.20)
	tw.tween_callback(queue_free)
