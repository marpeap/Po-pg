## HiddenCave — entrée de donjon dissimulée.
## Révélée par proximité (<180px). Toucher ouvre le donjon (DungeonFloor).
## sprite: dungeon_entrance.png (64×64), visible seulement après reveal.
## ADR-002: Area2D avec input_pickable pour détection tactile.
## NPC reward "cave_radius_+20px" (Lira step 1): sets radius_bonus = 20.0 via class static.
class_name HiddenCave
extends Area2D

const REVEAL_RADIUS := 180.0
const HERO_TOUCH_RADIUS := 200.0

## Added by Main._on_npc_step_reward() on "cave_radius_+20px" reward.
static var radius_bonus: float = 0.0

## Kenney Tiny Dungeon — entrée de grotte/donjon
const CAVE_SPRITE := "res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_03.png"
const CAVE_FALLBACK := "res://assets/sprites/garrison/rock.png"

var _revealed: bool = false
var _entered: bool = false
var _zone_idx: int = 0
var _seed_val: int = 0
var _hero_nearby: bool = false
var _sprite: Sprite2D = null
var _pulse_time: float = 0.0

signal cave_revealed(cave: Node)
signal dungeon_entered(zone_idx: int, seed_val: int)

func setup(zone_idx: int, seed_val: int) -> void:
	_zone_idx = zone_idx
	_seed_val = seed_val
	_build_visuals()
	visible = false
	input_pickable = false
	input_event.connect(_on_input_event)
	add_to_group("hidden_cave")
	add_to_group("interactables")

func _build_visuals() -> void:
	_sprite = Sprite2D.new()
	var tex: Texture2D = load(CAVE_SPRITE)
	if tex == null:
		tex = load(CAVE_FALLBACK)
	if tex != null:
		_sprite.texture = tex
	_sprite.scale = Vector2(0.90, 0.90)
	_sprite.modulate = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 32.0)
	col.shape = shape
	add_child(col)

## Called every frame by ExplorationMap or Main to check hero proximity.
func check_reveal(hero_pos: Vector2) -> void:
	if _revealed or _entered:
		return
	var dist: float = global_position.distance_to(hero_pos)
	_hero_nearby = dist < HERO_TOUCH_RADIUS
	## SIXIEME_SENS skill increases reveal radius to 250 px (vs default 180 px).
	var effective_reveal: float = (SkillTree.get_cave_reveal_radius() if SkillTree != null else REVEAL_RADIUS) + radius_bonus
	if dist <= effective_reveal:
		reveal()

## Force the cave to become visible (called by Scout NPC or proximity).
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	input_pickable = true
	cave_revealed.emit(self)
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(0.70, 0.95, 1.00, 1.0), 0.8)

## Gentle alpha pulse once revealed.
func _process(delta: float) -> void:
	if not _revealed or _entered or _sprite == null:
		return
	_pulse_time += delta * 2.0
	_sprite.modulate.a = 0.80 + sin(_pulse_time) * 0.20

## Returns the proximity-interact label.
func get_interact_label() -> String:
	return "Explorer"

## Returns true when cave can be entered.
func is_interactable() -> bool:
	return _revealed and not _entered

## Called by proximity button or tap.
func interact() -> void:
	_enter_dungeon()

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _revealed or _entered:
		return
	if event is InputEventScreenTouch and event.pressed:
		## Only respond to touch if hero is nearby (within HERO_TOUCH_RADIUS).
		if _hero_nearby:
			_enter_dungeon()

func _enter_dungeon() -> void:
	if _entered:
		return
	_entered = true
	input_pickable = false
	dungeon_entered.emit(_zone_idx, _seed_val)
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	## Darken sprite to indicate used entrance.
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(0.25, 0.25, 0.30, 0.70), 0.30)
