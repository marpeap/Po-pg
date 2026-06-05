## HealingShrine — tap to restore hero HP. Cooldown before reuse.
## Visual feedback: full color when ready, desaturated when on cooldown.
## ADR-002: Area2D, input_pickable for tap detection.
## NPC reward "heal_shrine_cd_-30s" (Senna step 1): sets cd_reduction = 30.0 via class static.
class_name HealingShrine
extends Area2D

const HEAL_AMOUNT  := 15    ## HP restored per use
const COOLDOWN_SEC := 30.0  ## Seconds before shrine recharges
const COOLDOWN_MIN := 10.0  ## Minimum cooldown after reductions

## Set by Main._on_npc_step_reward() on "heal_shrine_cd_-30s" reward.
static var cd_reduction: float = 0.0

var _active: bool = true
var _cooldown_timer: float = 0.0
var _sprite: Sprite2D = null
var _glow_ring: ColorRect = null  ## pulsing ring shown when shrine is ready
var _pulse_time: float = 0.0
var _hero: Node2D = null

## [param hero_ref] used in future for proximity detection; currently tap-only.
func setup(world_pos: Vector2, hero_ref: Node2D) -> void:
	_hero = hero_ref
	position = world_pos
	input_pickable = true
	_build_visuals()
	input_event.connect(_on_input_event)

func _build_visuals() -> void:
	## Pulsing glow ring behind the shrine — visible when ready, hidden on cooldown
	_glow_ring = ColorRect.new()
	_glow_ring.size = Vector2(60.0, 60.0)
	_glow_ring.position = Vector2(-30.0, -30.0)
	_glow_ring.color = Color(0.15, 0.90, 0.50, 0.30)
	add_child(_glow_ring)

	## Shrine sprite — centered
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/shrine.png")
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
## Shows cooldown remaining when shrine is recharging.
func get_interact_label() -> String:
	if _active:
		return "Soigner (+%dHP)" % HEAL_AMOUNT
	return "Soigner (%ds)" % int(ceil(_cooldown_timer))

## Returns true when the shrine is ready to heal.
func is_interactable() -> bool:
	return _active

## Heal the hero — called by proximity button or direct tap.
func interact() -> void:
	_heal()

func _process(delta: float) -> void:
	## Pulse glow ring when shrine is ready
	if _active:
		_pulse_time += delta * 2.0
		if _glow_ring != null:
			_glow_ring.modulate.a = 0.50 + sin(_pulse_time) * 0.50
		return
	## Countdown on cooldown (visual only — no text on map)
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_active = true
		_set_visual_ready(true)

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		_heal()

func _heal() -> void:
	if not _active:
		return
	if _hero == null or not _hero.has_method("heal"):
		return
	_active = false
	_cooldown_timer = maxf(COOLDOWN_MIN, COOLDOWN_SEC - cd_reduction)
	_hero.heal(HEAL_AMOUNT)
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	## Flash bright then dim to cooldown appearance
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tw.tween_property(_sprite, "modulate", Color(0.45, 0.45, 0.45), 0.3)
	_set_visual_ready(false)

func _set_visual_ready(ready: bool) -> void:
	if _sprite == null:
		return
	if ready:
		_sprite.modulate = Color.WHITE
		if _glow_ring != null:
			_glow_ring.visible = true
	else:
		_sprite.modulate = Color(0.45, 0.45, 0.45)
		if _glow_ring != null:
			_glow_ring.visible = false
