## Economy — gold counter + coin pool + magnet collect + button-triggered purchases
## ADR-002: Area2D overlap only
## ADR-003: Coin pool pre-allocated (16 nodes), no instantiate()
## ADR-005: GSM session_reset integration
## GDD Req: TR-economy-001, TR-economy-002
## Landscape refactor: dwell zones replaced by HUD button calls (Sprint 7)
extends Node

signal gold_changed(new_gold: int)
## Emitted whenever gold is deducted via spend_gold(). Used by DailyChallenge SPEND_GOLD tracking.
signal gold_spent(amount: int)
signal recruit_purchased
signal tower_purchased
## Emitted at wave end with the total gold deducted for army upkeep (Sprint 5, GDD Rule 13).
signal upkeep_deducted(amount: int)
## Forge purchase signals — one per upgrade type. Main wires these to Forge.on_*_purchased().
signal forge_dmg_purchased
signal forge_spd_purchased
signal forge_mag_purchased
signal forge_hp_purchased

const STARTING_GOLD := 60
const MAGNET_R := 170.0           ## Fallback magnet radius when no Forge reference is set
const COLLECT_R := 12.0           ## Radius at which coins are collected
const MAGNET_SPEED := 400.0       ## px/s coin move speed when magnetized
const COIN_POOL_SIZE := 16

const ARCHER_COST := 30      ## Fixed cost per archer (all 8 slots)
const TOWER_COST := 100
const FORGE_COST := 200

## Sprint 5 — Wave upkeep deducted at wave end (GDD economy.md Rule 13).
const UPKEEP_PER_ARCHER := 3
const UPKEEP_PER_TOWER := 8

var current_gold: int = STARTING_GOLD
var _current_archer_count: int = 2   ## Updated by ArcherFormation
var _tower_count: int = 0            ## Incremented on tower_purchased
## NPC chain reward — Marchand Darro "gold_bonus_10pct" / "gold_bonus_20pct"
var _npc_gold_bonus_mult: float = 1.0
## Quest chapter reward — "coin_magnet_+30px": flat bonus added to effective magnet radius.
var _magnet_r_bonus: float = 0.0

var _coin_pool: ObjectPool
var _hero: Node2D   ## Set by Main after setup
var _forge: Node    ## Optional Forge reference — set by Main for live magnet radius

func _ready() -> void:
	## Join "economy" group so DailyChallenge, ContractBoard, NPC, and WorldBoss
	## can grant gold via call_group("economy", "add_gold", amount).
	add_to_group("economy")

	_coin_pool = ObjectPool.new()
	var coin_script := load("res://src/gameplay/coin.gd")
	for i in range(COIN_POOL_SIZE):
		var c: Area2D = Area2D.new()
		c.set_script(coin_script)
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 8.0
		col.shape = shape
		c.add_child(col)
		add_child(c)
		_coin_pool._available.append(c)

	GameStateMachine.session_reset.connect(_on_session_reset)

func _process(delta: float) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	if _hero == null:
		return
	# Magnet collect — radius from Forge F3 when available, else fallback constant
	var magnet_r: float = (_forge.effective_magnet_r() if _forge != null else MAGNET_R) + _magnet_r_bonus
	var to_collect: Array[Node] = []
	for coin: Node in _coin_pool.all_active():
		var dist: float = coin.position.distance_to(_hero.position)
		if dist <= magnet_r:
			coin.position = coin.position.move_toward(_hero.position, MAGNET_SPEED * delta)
			if dist <= COLLECT_R:
				to_collect.append(coin)
	for coin: Node in to_collect:
		add_gold(coin.gold_value)
		coin.deactivate()
		_coin_pool.return_node(coin)

## --- Button-triggered purchase methods ---
## Called directly by HUD button signals (via Main wiring). No dwell logic.

## Recruit one archer. Fixed cost 30g for all 8 slots.
## Returns true if purchase succeeded.
func try_recruit() -> bool:
	if _current_archer_count >= 8:
		return false
	if not spend_gold(ARCHER_COST):
		return false
	_current_archer_count += 1
	recruit_purchased.emit()
	return true

## Purchase one archer tower. Max 5. Tower comes with its own 2 archers — no formation requirement.
## Returns true if purchase succeeded.
func try_purchase_tower() -> bool:
	if _tower_count >= 5:
		return false
	if not spend_gold(TOWER_COST):
		return false
	_tower_count += 1
	tower_purchased.emit()
	return true

## Forge upgrade purchases — each costs FORGE_COST gold.
func try_forge_dmg() -> bool:
	if not spend_gold(FORGE_COST):
		return false
	forge_dmg_purchased.emit()
	return true

func try_forge_spd() -> bool:
	if not spend_gold(FORGE_COST):
		return false
	forge_spd_purchased.emit()
	return true

func try_forge_mag() -> bool:
	if not spend_gold(FORGE_COST):
		return false
	forge_mag_purchased.emit()
	return true

func try_forge_hp() -> bool:
	if not spend_gold(FORGE_COST):
		return false
	forge_hp_purchased.emit()
	return true

## Cost of next archer recruit — always ARCHER_COST (flat).
func next_recruit_cost() -> int:
	return ARCHER_COST

## True when the player can afford and has room for another archer.
func can_recruit() -> bool:
	return _current_archer_count < 8 and current_gold >= ARCHER_COST

## True when the player can afford a tower (max 5; no archer count requirement).
func can_purchase_tower() -> bool:
	return _tower_count < 5 and current_gold >= TOWER_COST

## Sprint 5 — Wave upkeep deducted at wave end. GDD Formula D-7 (economy.md Rule 13).
func _on_wave_cleared() -> void:
	if GameStateMachine.current_state == GameStateMachine.State.GAME_OVER:
		return
	var upkeep: int = _current_archer_count * UPKEEP_PER_ARCHER + _tower_count * UPKEEP_PER_TOWER
	if upkeep <= 0:
		return
	var deducted: int = mini(current_gold, upkeep)
	current_gold = maxi(0, current_gold - upkeep)
	gold_changed.emit(current_gold)
	if deducted > 0:
		upkeep_deducted.emit(deducted)

## Called by ArcherFormation to keep archer count in sync.
func set_archer_count(count: int) -> void:
	_current_archer_count = count

## Called by EnemyWave._on_enemy_died — drop a coin at the death position.
## visual_tier: 0=Gold 1=Crystal Rune 2=Circuit Token 3=Plasma Orb.
func on_enemy_died(pos: Vector2, gold: int, visual_tier: int = 0) -> void:
	var coin: Node = _coin_pool.checkout()
	if coin == null:
		return  # Pool exhausted — coin not dropped (rare edge case)
	coin.activate(pos, gold, visual_tier)

## Add gold to the counter and emit gold_changed.
## _npc_gold_bonus_mult applied when > 1.0 (Darro NPC chain reward).
func add_gold(amount: int) -> void:
	var season_mult: float = SeasonManager.get_gold_multiplier() if SeasonManager != null else 1.0
	var weather_mult: float = WeatherManager.get_coin_mult() if WeatherManager != null else 1.0
	var effective: int = int(float(amount) * _npc_gold_bonus_mult * season_mult * weather_mult)
	current_gold = max(current_gold + effective, 0)
	gold_changed.emit(current_gold)

## Deduct gold. Returns false if insufficient funds — gold never goes below 0.
func spend_gold(amount: int) -> bool:
	if current_gold < amount:
		return false
	current_gold -= amount
	gold_changed.emit(current_gold)
	gold_spent.emit(amount)
	return true

func _on_session_reset() -> void:
	for coin: Node in _coin_pool.all_active():
		coin.deactivate()
		_coin_pool.return_node(coin)
	current_gold = STARTING_GOLD
	gold_changed.emit(current_gold)
	_current_archer_count = 2
