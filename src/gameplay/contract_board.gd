## ContractBoard — session contract system. 3 active contracts at a time.
## Each contract: collect N of resource type X → receive gold + XP reward.
## Tap the board (Area2D) or proximity-interact to open the contracts panel.
## Contracts refresh each time the hero returns from exploration.
## ADR-002: Area2D with input_pickable.
extends Area2D

## Rarity weight of each resource pool for contract generation.
## Rare contracts pay more gold but require rarer resources.
const COMMON_POOL: Array[int] = [
	ResourceInventory.Type.WOOD,        ## 0
	ResourceInventory.Type.STONE,       ## 1
	ResourceInventory.Type.HERB,        ## 2
	ResourceInventory.Type.CLAY,        ## 20
	ResourceInventory.Type.REED,        ## 29
	ResourceInventory.Type.MOSS,        ## 16
	ResourceInventory.Type.BIRCH_BARK,  ## 13
	ResourceInventory.Type.FLINT,       ## 21
	ResourceInventory.Type.CHARCOAL,    ## 25
	ResourceInventory.Type.WILD_BERRY,  ## 17
]

const RARE_POOL: Array[int] = [
	ResourceInventory.Type.IRON_ORE,      ## 5
	ResourceInventory.Type.COAL,          ## 6
	ResourceInventory.Type.CRYSTAL,       ## 7
	ResourceInventory.Type.HARDWOOD,      ## 9
	ResourceInventory.Type.SILVER_LICHEN, ## 42
	ResourceInventory.Type.ICE_CRYSTAL,   ## 46
	ResourceInventory.Type.GHOST_MUSHROOM,## 43
	ResourceInventory.Type.GOLDEN_SAP,    ## 44
]

const LEGENDARY_POOL: Array[int] = [
	ResourceInventory.Type.GEMSTONE,       ## 8
	ResourceInventory.Type.SHADOW_ESSENCE, ## 12
	ResourceInventory.Type.ADAMANTITE,     ## 51
	ResourceInventory.Type.MYTHRIL,        ## 52
	ResourceInventory.Type.MOONSTONE,      ## 53
]

## Contract difficulty tiers with associated quantity ranges and rewards.
## [rarity_tier (0=common,1=rare,2=leg), qty_min, qty_max, gold_reward, xp_reward]
const TIERS: Array = [
	[0, 5, 12, 20,  10],   ## Easy   — common resource, 5-12 units, 20g
	[1, 2,  5, 50,  30],   ## Medium — rare resource,   2-5 units,  50g
	[2, 1,  2, 120, 80],   ## Hard   — legendary,       1-2 units, 120g
]

## Max active contracts per session.
const MAX_CONTRACTS := 3

## A contract entry: {type, qty_required, qty_current, gold, xp, fulfilled, tier}
var contracts: Array = []
var _rng: RandomNumberGenerator = null
var _sprite: Sprite2D = null
var _active: bool = true
var _exclaim_lbl: Label = null

signal contracts_panel_requested()
signal contract_fulfilled(contract_idx: int, gold_reward: int, xp_reward: int)

func setup(seed_val: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val
	input_pickable = true
	_build_visuals()
	_generate_contracts()
	input_event.connect(_on_input_event)
	## Register in group so ExplorationMap can call refresh_contracts().
	add_to_group("contract_board")

func _build_visuals() -> void:
	## Notice board sprite (96×80, PIL-generated garrison asset).
	_sprite = Sprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/garrison/notice_board.png")
	if tex != null:
		_sprite.texture  = tex
		_sprite.scale    = Vector2(1.8, 1.8)   ## 96px → ~173px visible
		_sprite.modulate = Color(1.0, 1.0, 1.0)
	add_child(_sprite)

	## "!" interaction indicator above the board — pulsing scale in _process.
	_exclaim_lbl = Label.new()
	_exclaim_lbl.text     = "!"
	_exclaim_lbl.position = Vector2(-6.0, -55.0)
	_exclaim_lbl.add_theme_font_size_override("font_size", 18)
	_exclaim_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	add_child(_exclaim_lbl)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96.0, 80.0)   ## matches 96px notice_board sprite at scale 1.8 approx
	col.shape  = shape
	add_child(col)

func _process(_delta: float) -> void:
	## Pulse the "!" label scale to attract player attention.
	if _exclaim_lbl != null:
		var pulse_scale: float = 1.0 + sin(Time.get_ticks_msec() / 400.0) * 0.15
		_exclaim_lbl.scale = Vector2(pulse_scale, pulse_scale)

## Generate a fresh set of 3 contracts. Called on setup and after each return from exploration.
func _generate_contracts() -> void:
	contracts.clear()
	## One contract of each difficulty tier.
	for tier_idx: int in range(TIERS.size()):
		var tier: Array = TIERS[tier_idx]
		var rarity: int = tier[0]
		var res_type: int = _pick_resource(rarity)
		var qty: int  = _rng.randi_range(tier[1], tier[2])
		contracts.append({
			"type":         res_type,
			"qty_required": qty,
			"qty_current":  0,
			"gold":         tier[3],
			"xp":           tier[4],
			"fulfilled":    false,
			"tier":         tier_idx,
		})

## Check if any contracts can be advanced/fulfilled with current inventory.
func check_fulfillment() -> void:
	for i: int in range(contracts.size()):
		var c: Dictionary = contracts[i]
		if c.fulfilled:
			continue
		var have: int = ResourceInventory.get_count(c.type)
		c.qty_current = mini(have, c.qty_required)
		if have >= c.qty_required and not c.fulfilled:
			_fulfill(i)

## Called when hero returns from exploration — refresh unfulfilled contracts.
func refresh_contracts() -> void:
	var any_unfulfilled: bool = false
	for c: Dictionary in contracts:
		if not c.fulfilled:
			any_unfulfilled = true
			break
	if not any_unfulfilled:
		_generate_contracts()

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Contrats"

## Returns true when there is at least one active (unfulfilled) contract.
func is_interactable() -> bool:
	return _active

## Open contracts panel — called by proximity button or tap.
func interact() -> void:
	check_fulfillment()
	contracts_panel_requested.emit()

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		interact()

func _fulfill(idx: int) -> void:
	var c: Dictionary = contracts[idx]
	if c.fulfilled:
		return
	c.fulfilled = true
	## Spend the resources
	ResourceInventory.spend(c.type, c.qty_required)
	## Pay the reward
	HeroProgression.add_xp(c.xp)
	var econ_nodes: Array = get_tree().get_nodes_in_group("economy")
	if not econ_nodes.is_empty():
		var econ: Node = econ_nodes[0]
		if econ.has_method("add_gold"):
			econ.add_gold(c.gold)
	contract_fulfilled.emit(idx, c.gold, c.xp)

func _pick_resource(rarity: int) -> int:
	match rarity:
		0: return COMMON_POOL[_rng.randi_range(0, COMMON_POOL.size() - 1)]
		1: return RARE_POOL[_rng.randi_range(0, RARE_POOL.size() - 1)]
		2: return LEGENDARY_POOL[_rng.randi_range(0, LEGENDARY_POOL.size() - 1)]
	return 0
