## NpcWanderer — ambient NPC that roams the exploration map.
## 5 NPC types with distinct behaviours: MERCHANT, SCOUT, SAGE, BARD, HEALER.
## Tap the NPC to open a context popup (trade / info / quest / reward).
## Merchant type: buy/sell resources via Economy gold bridge.
## ADR-002: Area2D with input_pickable for touch detection.
extends Area2D

## NPC archetype — determines popup content and interaction effect.
enum NpcType {
	MERCHANT = 0,  ## Sells rare resources for gold; buys common stacks.
	SCOUT    = 1,  ## Reveals nearby hidden caves; gives zone tip.
	SAGE     = 2,  ## Grants XP burst and lore hint.
	BARD     = 3,  ## Boosts hero speed for 30 s; optional tip.
	HEALER   = 4,  ## Restores hero HP (for future HP system); grants small XP.
}

## Display name shown in the popup header.
const TYPE_NAMES: Array[String] = [
	"Marchand Itinerant",
	"Eclaireur",
	"Sage Ancien",
	"Barde Vagabond",
	"Guerisseur",
]

## PIL-generated NPC sprites, one per archetype.
const NPC_SPRITES: Array[String] = [
	"res://assets/sprites/garrison/npc_merchant.png",  ## MERCHANT
	"res://assets/sprites/garrison/npc_scout.png",     ## SCOUT
	"res://assets/sprites/garrison/npc_sage.png",      ## SAGE
	"res://assets/sprites/garrison/npc_bard.png",      ## BARD
	"res://assets/sprites/garrison/npc_healer.png",    ## HEALER
]

## Scale per archetype (sprites are different sizes).
const NPC_SCALES: Array[Vector2] = [
	Vector2(0.85, 0.85),  ## MERCHANT
	Vector2(0.82, 0.82),  ## SCOUT
	Vector2(0.80, 0.80),  ## SAGE
	Vector2(0.82, 0.82),  ## BARD
	Vector2(0.83, 0.83),  ## HEALER
]

## Fallback ColorRect colors when sprite fails to load.
const NPC_FALLBACK_COLORS: Array[Color] = [
	Color("#8B6914"),  ## MERCHANT — or
	Color("#2D6A2D"),  ## SCOUT   — vert
	Color("#6B3FA0"),  ## SAGE    — violet
	Color("#C0392B"),  ## BARD    — rouge
	Color("#2980B9"),  ## HEALER  — bleu
]

const NPC_TINTS: Array[Color] = [
	Color(1.00, 0.88, 0.35),  ## MERCHANT — gold
	Color(0.55, 0.88, 0.55),  ## SCOUT — green
	Color(0.55, 0.70, 1.00),  ## SAGE — blue
	Color(1.00, 0.60, 0.85),  ## BARD — pink
	Color(0.70, 1.00, 0.78),  ## HEALER — mint
]

## NPC wander speed (world px/s).
const WANDER_SPEED := 40.0
## NPC turns around at ±this offset from spawn x.
const WANDER_HALF_RANGE := 120.0
## Speed bonus granted by Bard (added to HeroProgression base).
const BARD_SPEED_BONUS := 0.20
const BARD_SPEED_DURATION := 30.0

## Merchant shop: resource type → {cost_gold, yield_amount}.
const MERCHANT_SHOP: Dictionary = {
	ResourceInventory.Type.CRYSTAL:    {cost=20, amt=1},
	ResourceInventory.Type.GEMSTONE:   {cost=40, amt=1},
	ResourceInventory.Type.IRON_ORE:   {cost=10, amt=2},
	ResourceInventory.Type.SILVER_LICHEN: {cost=30, amt=1},
	ResourceInventory.Type.GHOST_MUSHROOM:{cost=25, amt=1},
	ResourceInventory.Type.GOLDEN_SAP: {cost=35, amt=1},
	ResourceInventory.Type.ICE_CRYSTAL:{cost=30, amt=1},
}

## How much gold the merchant pays for common stacks (per unit).
const MERCHANT_BUY: Dictionary = {
	ResourceInventory.Type.WOOD:  3,
	ResourceInventory.Type.STONE: 2,
	ResourceInventory.Type.HERB:  4,
	ResourceInventory.Type.CLAY:  3,
	ResourceInventory.Type.REED:  2,
}

signal popup_requested(npc: Node, npc_type: int, title: String)
signal bard_speed_buff_started(duration: float, bonus: float)

var _npc_type:   int     = NpcType.MERCHANT
var _active:     bool    = true
var _sprite:     Sprite2D = null
var _wander_dir: float   = 1.0  ## +1 = right, -1 = left
var _spawn_x:    float   = 0.0
var _pulse_time: float   = 0.0
var _bard_timer: float   = 0.0
var _bard_active: bool   = false

func setup(npc_type: int, spawn_x: float) -> void:
	_npc_type = clampi(npc_type, 0, NpcType.HEALER)
	_spawn_x  = spawn_x
	input_pickable = true

	## Sprite — load PIL-generated garrison sprite, fallback to colored rect.
	_sprite = Sprite2D.new()
	var tex_path: String = NPC_SPRITES[_npc_type]
	var tex: Texture2D = load(tex_path)
	if tex != null:
		_sprite.texture = tex
		_sprite.scale   = NPC_SCALES[_npc_type]
		add_child(_sprite)
	else:
		## Fallback: distinct colored rect per archetype.
		var cr := ColorRect.new()
		cr.size     = Vector2(24.0, 32.0)
		cr.position = Vector2(-12.0, -32.0)
		cr.color    = NPC_FALLBACK_COLORS[_npc_type]
		add_child(cr)
		## Keep _sprite reference non-null so _process flip_h is safe.
		_sprite = null

	## Interaction indicator — "?" label pulsing above the NPC.
	var interact_lbl := Label.new()
	interact_lbl.name        = "InteractLbl"
	interact_lbl.text        = "?"
	interact_lbl.position    = Vector2(-6.0, -52.0)
	interact_lbl.add_theme_font_size_override("font_size", 16)
	interact_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	add_child(interact_lbl)

	## Collision
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22.0, 32.0)
	col.shape  = shape
	add_child(col)

	input_event.connect(_on_input_event)

func _process(delta: float) -> void:
	if not _active:
		return
	## Wander left-right around spawn point
	position.x += _wander_dir * WANDER_SPEED * delta
	if position.x > _spawn_x + WANDER_HALF_RANGE:
		_wander_dir = -1.0
	elif position.x < _spawn_x - WANDER_HALF_RANGE:
		_wander_dir = 1.0
	if _sprite != null:
		_sprite.flip_h = (_wander_dir < 0.0)

	## Gentle alpha pulse on sprite.
	_pulse_time += delta * 1.5
	if _sprite != null:
		_sprite.modulate.a = 0.85 + sin(_pulse_time) * 0.15

	## Pulse the interaction "?" label scale.
	var interact_lbl: Node = get_node_or_null("InteractLbl")
	if interact_lbl != null:
		var pulse_scale: float = 1.0 + sin(Time.get_ticks_msec() / 400.0) * 0.12
		interact_lbl.scale = Vector2(pulse_scale, pulse_scale)

	## Bard buff timer
	if _bard_active:
		_bard_timer -= delta
		if _bard_timer <= 0.0:
			_bard_active = false

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Parler"

## Returns true when NPC can be interacted with.
func is_interactable() -> bool:
	return _active

## Trigger NPC interaction — called by proximity button or tap.
func interact() -> void:
	if not _active:
		return
	popup_requested.emit(self, _npc_type, TYPE_NAMES[_npc_type])

## Called by the HUD/Main after the popup is dismissed with a choice.
## [param choice] 0=accept/buy, 1=decline/sell, -1=close.
func resolve_interaction(choice: int) -> void:
	match _npc_type:
		NpcType.MERCHANT:
			_resolve_merchant(choice)
		NpcType.SCOUT:
			_resolve_scout(choice)
		NpcType.SAGE:
			_resolve_sage()
		NpcType.BARD:
			_resolve_bard()
		NpcType.HEALER:
			_resolve_healer()

func _resolve_merchant(choice: int) -> void:
	## choice 0 = buy first item in shop (simplified for mobile one-tap flow).
	if choice == 0:
		var keys: Array = MERCHANT_SHOP.keys()
		if keys.is_empty():
			return
		var res_type: int = keys[0]
		var entry: Dictionary = MERCHANT_SHOP[res_type]
		## Spend gold via economy group node (same pattern as economy.gd).
		var econ_nodes: Array = get_tree().get_nodes_in_group("economy")
		if econ_nodes.is_empty():
			return
		var econ: Node = econ_nodes[0]
		if econ.has_method("spend_gold") and econ.spend_gold(entry.cost):
			ResourceInventory.add(res_type, entry.amt)
	## After first transaction NPC stays; mark as partially used.

func _resolve_scout(_choice: int = 0) -> void:
	## Scout reveals the nearest hidden cave (emits a signal ExplorationMap handles).
	get_tree().call_group("exploration_map", "reveal_nearest_cave", global_position)

func _resolve_sage() -> void:
	HeroProgression.add_xp(80)

func _resolve_bard() -> void:
	if not _bard_active:
		_bard_active = true
		_bard_timer  = BARD_SPEED_DURATION
		bard_speed_buff_started.emit(BARD_SPEED_DURATION, BARD_SPEED_BONUS)

func _resolve_healer() -> void:
	HeroProgression.add_xp(30)
	## Future: emit heal_hero signal when hero HP system exists.

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		interact()
