## CraftingAnvil — interactive world object that opens the crafting UI.
## Placed at fixed positions by ExplorationMap.
## Tap to open; UI closes itself on "X" or on backdrop click.
## ADR-002: Area2D, input_pickable for touch detection.
extends Area2D

var _crafting_system: Node = null   ## Shared CraftingSystem instance (passed by ExplorationMap)
var _ui_open: bool = false
var _glow: ColorRect = null   ## stored for idle pulse animation
var _sprite: Sprite2D = null
var _pulse_time: float = 0.0

## [param world_pos] placement in exploration world space.
## [param crafting_system] shared CraftingSystem node (one per exploration session).
func setup(world_pos: Vector2, crafting_system: Node) -> void:
	_crafting_system = crafting_system
	position = world_pos
	input_pickable = true
	_build_visuals()
	input_event.connect(_on_input_event)

func _build_visuals() -> void:
	## Amber glow underneath — pulses to signal interactability
	var glow := ColorRect.new()
	glow.size = Vector2(70.0, 12.0)
	glow.position = Vector2(-35.0, 22.0)
	glow.color = Color(0.80, 0.60, 0.10, 0.35)
	add_child(glow)
	_glow = glow

	## Forge sprite — centered
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/forge.png")
	_sprite.scale = Vector2(0.35, 0.35)   ## 170×155 → ~60×54
	add_child(_sprite)

	## Collision
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60.0, 54.0)
	col.shape = shape
	add_child(col)

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Forger"

## Returns true when the crafting UI is not already open.
func is_interactable() -> bool:
	return not _ui_open

## Open the crafting UI — called by proximity button or direct tap.
func interact() -> void:
	_open_crafting_ui()

## Idle pulse on the amber glow.
func _process(delta: float) -> void:
	if _ui_open or _glow == null:
		return
	_pulse_time += delta * 2.5
	_glow.modulate.a = 0.55 + sin(_pulse_time) * 0.45

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _ui_open:
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	_open_crafting_ui()

func _open_crafting_ui() -> void:
	if _ui_open or _crafting_system == null:
		return
	_ui_open = true
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)

	## Find the tree root to attach the CanvasLayer
	var ui_script: GDScript = load("res://src/gameplay/crafting_ui.gd")
	var ui: CanvasLayer = CanvasLayer.new()
	ui.set_script(ui_script)
	get_tree().root.add_child(ui)
	ui.init(_crafting_system)
	ui.closed.connect(func() -> void: _ui_open = false)
