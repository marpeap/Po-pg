## EnemyWave — enemy pool (30 nodes) + infinite procedural wave sequencer
## ADR-003: Object pool — no instantiate() during gameplay
## ADR-005: GSM integration — session_reset signal
## ADR-006: direction_to steering (enemies handle their own movement)
## GDD Req: TR-enemy-002, TR-wave-001
##
## Wave system — infinite, budget-based:
##   Budget per wave = BASE_BUDGET + wave_number * BUDGET_PER_WAVE
##   Enemy types unlock progressively (archer wave 3, cavalier wave 5, healer wave 8)
##   Wave tags drive special events every N waves:
##     BOSS  — every 5th wave, one oversized enemy (×BOSS_HP_MULT HP, ×BOSS_SCALE)
##     ELITE — every 3rd wave (non-boss), 33% of enemies have ×ELITE_HP_MULT HP
##     RUSH  — random from wave 6+, all enemies +35% speed
##     HEALER_SURGE — random from wave 9+, healer weight boosted
##   HP/speed multipliers compound every 10-wave cycle (+20% HP, +8% speed per cycle)
extends Node

## Budget system
const BASE_BUDGET      := 80     ## Threat budget at wave 1
const BUDGET_PER_WAVE  := 18     ## Added per wave number (steeper than original 15)
## Threat cost per enemy type [INFANTRY, ARCHER, CAVALIER, HEALER, SHIELDER]
const ENEMY_COSTS: Array[int] = [8, 12, 22, 18, 20]
const MIN_WAVE_COUNT   := 4      ## Floor — always at least 4 enemies
const MAX_WAVE_COUNT   := 40     ## Ceiling — pool is 30, keep some headroom

## Type unlock thresholds (1-indexed wave number)
const UNLOCK_ARCHER   := 3
const UNLOCK_CAVALIER := 5
const UNLOCK_HEALER   := 8
const UNLOCK_SHIELDER := 6       ## Shielders appear from wave 6

## Wave tags
const TAG_NORMAL       := "NORMAL"
const TAG_BOSS         := "BOSS"
const TAG_ELITE        := "ELITE"
const TAG_RUSH         := "RUSH"
const TAG_HEALER_SURGE := "HEALER_SURGE"

## Boss / Elite visual and stat multipliers
const ELITE_HP_MULT := 2.5   ## Elites are noticeably tankier (was 2.0)
const BOSS_HP_MULT  := 6.0   ## Bosses are very beefy (was 5.0)
const BOSS_SCALE    := 1.6   ## Visual scale applied to boss node
const BOSS_GOLD_MULT := 3    ## Boss drops 3× gold

## Stat scaling per 10-wave cycle (applied to all enemies, compound)
const HP_SCALE_PER_CYCLE    := 0.25  ## +25% HP per cycle (was 0.20 — steeper)
const SPEED_SCALE_PER_CYCLE := 0.08  ## +8% speed per cycle
const RUSH_SPEED_BONUS      := 1.35  ## Rush tag: ×1.35 speed on top of cycle scaling

const SPAWN_IVTL := 0.5          ## Seconds between individual enemy spawns
const POOL_SIZE := 30            ## Pre-allocated enemy nodes

## Emitted when a new wave begins (1-indexed).
signal wave_started(wave_number: int)
## Emitted once per wave start with the total enemy count for that wave.
signal wave_enemy_count(count: int)
## Emitted on every individual enemy kill — pos is world position of the kill.
## Consumed by ArcherFormation for Momentum streak tracking (Sprint 5).
signal enemy_killed(pos: Vector2)
## Emitted after every kill with remaining active enemy count (for HUD countdown).
signal enemies_remaining(count: int)
## Emitted when the last enemy in a wave is killed.
signal wave_cleared
## Emitted after wave_cleared — HUD shows the Start Wave button until start_next_wave() is called.
signal wave_start_ready

## Zero-indexed internally; 1-indexed for signals and display.
var current_wave: int = 0
## Running kill counter — displayed on GAME_OVER screen.
var total_kills: int = 0

var _active_enemies: int = 0
var _spawned_this_wave: int = 0
var _wave_enemy_count: int = 0       ## Total enemies to spawn this wave (computed in _start_wave)
var _wave_tag: String = TAG_NORMAL   ## Computed once per wave in _start_wave
var _spawn_timer: float = 0.0
var _wave_in_progress: bool = false
var _waiting_for_next_wave: bool = false

var _pool: ObjectPool
@warning_ignore("unused_private_class_variable")
var _economy: Node  ## Set by Main after instantiation
var _castle: Node   ## Set by Main after instantiation

func _ready() -> void:
	_pool = ObjectPool.new()
	var enemy_script := load("res://src/gameplay/enemy.gd")
	# Pre-allocate 30 enemy Area2D nodes — added to GameWorld (parent) so
	# they participate in y_sort_enabled depth sorting.
	# Guard: get_parent() is null in unit tests; fall back to self.
	var world: Node = get_parent() if get_parent() != null else self
	for i: int in range(POOL_SIZE):
		var e: Area2D = Area2D.new()
		e.set_script(enemy_script)
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 12.0
		col.shape = shape
		e.add_child(col)
		world.add_child(e)
		_pool._available.append(e)

	GameStateMachine.session_reset.connect(_on_session_reset)
	_start_wave(0)

func _process(delta: float) -> void:
	var state := GameStateMachine.current_state
	## During EXPLORING, only run if a boss assault wave is active (force_boss_wave was called).
	## The castle still exists in GameWorld and can take damage even while hidden.
	var exploring_assault: bool = (
		state == GameStateMachine.State.EXPLORING
		and _wave_in_progress
		and _wave_tag == TAG_BOSS
	)
	if state != GameStateMachine.State.PLAYING and not exploring_assault:
		return

	# Waiting for the player to press the Start Wave button
	if _waiting_for_next_wave:
		return

	# Spawn enemies for the current wave
	if _wave_in_progress and _spawned_this_wave < _wave_enemy_count:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_IVTL:
			_spawn_timer = 0.0
			_spawn_enemy()

## Public — called by the HUD Start Wave button press.
## No-op if a wave is already running or the game is not in PLAYING state.
func start_next_wave() -> void:
	if not _waiting_for_next_wave:
		return
	_waiting_for_next_wave = false
	_start_wave(current_wave + 1)

## Public — force-starts a boss assault wave regardless of current state.
## Called when a world boss reaches phase 2 in the exploration map.
## [param tier] is the phase2_wave value from the boss definition (3, 5, or 8).
## This allows the castle to be attacked while the hero is in the RPG world.
func force_boss_wave(tier: int) -> void:
	## Do not stack on top of an active wave — only trigger if idle or waiting.
	if _wave_in_progress and _spawned_this_wave < _wave_enemy_count:
		return
	## Override waiting state to force the assault.
	_waiting_for_next_wave = false
	## Force BOSS tag so a large, named enemy leads the assault.
	_wave_tag = TAG_BOSS
	## Use the tier directly as the wave index to scale enemy stats appropriately.
	var assault_wave_idx: int = maxi(current_wave, tier)
	_wave_enemy_count = clampi(_compute_wave_count(assault_wave_idx), MIN_WAVE_COUNT, 16)
	_spawned_this_wave = 0
	_active_enemies = 0
	_spawn_timer = 0.0
	_wave_in_progress = true
	## Announce the assault via HUD — castle is under attack!
	get_tree().call_group("hud", "show_boss_announce",
		"VAGUE D'ASSAUT !",
		"Le boss déchaîne ses légions sur votre forteresse !")
	wave_started.emit(assault_wave_idx + 1)
	wave_enemy_count.emit(_wave_enemy_count)

## Begin a wave by index (0-based). All wave parameters are computed here.
func _start_wave(wave_index: int) -> void:
	current_wave = wave_index
	_spawned_this_wave = 0
	_active_enemies = 0
	_spawn_timer = 0.0
	_wave_tag = _compute_wave_tag(wave_index)
	_wave_enemy_count = _compute_wave_count(wave_index)
	_wave_in_progress = true
	wave_started.emit(current_wave + 1)
	wave_enemy_count.emit(_wave_enemy_count)

## Preview the next wave — returns a dict for HUD display between waves.
## "wave": 1-indexed number, "tag": wave tag string, "composition": human-readable types.
func get_next_wave_preview() -> Dictionary:
	var next_idx: int = current_wave  ## current_wave advances after wave clears; next = current_wave
	var n: int = next_idx + 1
	## Deterministic tag (no random — avoid side-effects on preview call)
	var tag: String = TAG_NORMAL
	if n % 5 == 0:
		tag = TAG_BOSS
	elif n % 3 == 0:
		tag = TAG_ELITE
	var weights: Array[int] = _compute_type_weights(next_idx)
	var total_w: int = 0
	for w: int in weights:
		total_w += w
	var type_icons: Array[String] = ["⚔", "🏹", "🐎", "💚", "🛡"]
	var parts: Array[String] = []
	for i: int in range(weights.size()):
		if weights[i] > 0 and total_w > 0:
			parts.append("%s%d%%" % [type_icons[i], weights[i] * 100 / total_w])
	return {
		"wave":        n,
		"tag":         tag,
		"composition": "  ".join(parts),
	}

## Return the wave tag for a given 0-based wave index.
## BOSS every 5th wave, ELITE every 3rd (non-boss), random RUSH/HEALER_SURGE beyond that.
func _compute_wave_tag(wave_num: int) -> String:
	var n: int = wave_num + 1   # 1-indexed for human-readable cadence
	if n % 5 == 0:
		return TAG_BOSS
	if n % 3 == 0:
		return TAG_ELITE
	if n >= 6 and randi() % 10 < 2:
		return TAG_RUSH
	if n >= 9 and randi() % 10 < 2:
		return TAG_HEALER_SURGE
	return TAG_NORMAL

## Return the type weight array [INFANTRY, ARCHER, CAVALIER, HEALER, SHIELDER] for a wave.
## Types unlock progressively; healer surge boosts healer weight.
func _compute_type_weights(wave_num: int) -> Array[int]:
	var n: int = wave_num + 1
	var w: Array[int] = [10, 0, 0, 0, 0]
	if n >= UNLOCK_ARCHER:
		w[0] = 7; w[1] = 3
	if n >= UNLOCK_CAVALIER:
		w[0] = 5; w[2] = 2
	if n >= UNLOCK_HEALER:
		w[0] = 3; w[3] = 1
	if n >= UNLOCK_SHIELDER:
		w[0] = maxi(w[0] - 2, 2); w[4] = 2
	if _wave_tag == TAG_HEALER_SURGE:
		w[3] = maxi(w[3], 4)
	return w

## Return the total enemy count for a wave using the budget system.
## Budget grows linearly; boss waves spend budget on 1 giant enemy so count is lower.
func _compute_wave_count(wave_num: int) -> int:
	var n: int = wave_num + 1
	var budget: int = BASE_BUDGET + n * BUDGET_PER_WAVE
	# Boss wave: reserve most budget for the boss itself — spawn fewer normal enemies
	if _wave_tag == TAG_BOSS:
		budget = budget * 55 / 100
	var avg_cost: float = _average_enemy_cost(wave_num)
	var count: int = roundi(float(budget) / avg_cost)
	return clampi(count, MIN_WAVE_COUNT, MAX_WAVE_COUNT)

## Compute average threat cost weighted by the current type weight distribution.
func _average_enemy_cost(wave_num: int) -> float:
	var w: Array[int] = _compute_type_weights(wave_num)
	var total_w: int = 0
	var weighted_cost: float = 0.0
	for i: int in range(w.size()):
		total_w += w[i]
		weighted_cost += float(w[i]) * float(ENEMY_COSTS[i])
	if total_w <= 0:
		return float(ENEMY_COSTS[0])
	return weighted_cost / float(total_w)

## HP multiplier compounding every 10 waves. Wave 0-9 = cycle 0 (×1.0).
func get_stat_multiplier(wave_num: int) -> float:
	return 1.0 + float(wave_num / 10) * HP_SCALE_PER_CYCLE

## Speed multiplier compounding every 10 waves.
func get_speed_multiplier(wave_num: int) -> float:
	var mult: float = 1.0 + float(wave_num / 10) * SPEED_SCALE_PER_CYCLE
	if _wave_tag == TAG_RUSH:
		mult *= RUSH_SPEED_BONUS
	return mult

## Checkout one enemy from the pool and activate it with wave-appropriate type and stats.
func _spawn_enemy() -> void:
	var node: Node = _pool.checkout()
	if node == null:
		return
	var weights: Array[int] = _compute_type_weights(current_wave)
	var spawn_pos: Vector2 = _random_spawn_pos()

	# Determine if this enemy is the wave boss (always first spawn on a boss wave)
	var is_boss: bool = (_wave_tag == TAG_BOSS and _spawned_this_wave == 0)
	# Elites: ~33% of enemies on an elite wave
	var is_elite: bool = (not is_boss and _wave_tag == TAG_ELITE and randi() % 3 == 0)

	var etype: int = _pick_enemy_type(weights)
	# Boss is always Infantry-based (largest sprite, clearest visual signal)
	if is_boss:
		etype = 0   # EnemyType.INFANTRY

	node.activate(spawn_pos, etype, _wave_to_visual_tier(current_wave))
	node._castle = _castle

	# Apply cycle scaling then tag modifiers
	var hp_mult: float = get_stat_multiplier(current_wave)
	var spd_mult: float = get_speed_multiplier(current_wave)

	if is_boss:
		hp_mult *= BOSS_HP_MULT
		node.gold_value *= BOSS_GOLD_MULT
		node.scale = Vector2(BOSS_SCALE, BOSS_SCALE)
	elif is_elite:
		hp_mult *= ELITE_HP_MULT
		node.scale = Vector2(1.0, 1.0)
	else:
		node.scale = Vector2(1.0, 1.0)

	node.hp = roundi(float(node.hp) * hp_mult)
	node._max_hp = node.hp
	node.speed = node.speed * spd_mult
	node._base_speed = node.speed
	## Boss CPUParticles2D aura — red embers orbiting the boss unit
	if node.has_method("set_boss_visual"):
		node.set_boss_visual(is_boss)

	node.enemy_died.connect(_on_enemy_died.bind(node), CONNECT_ONE_SHOT)
	_active_enemies += 1
	_spawned_this_wave += 1

## Select an enemy type index using weighted random selection.
func _pick_enemy_type(weights: Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	if total <= 0:
		return 0
	var roll: int = randi() % total
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return i
	return 0

## Called when an enemy's HP reaches 0.
func _on_enemy_died(_pos: Vector2, node: Node) -> void:
	total_kills += 1
	_active_enemies -= 1
	node.deactivate()
	node.scale = Vector2(1.0, 1.0)   # Reset boss/elite scale
	_pool.return_node(node)
	if _economy != null:
		_economy.on_enemy_died(_pos, node.gold_value, _wave_to_visual_tier(current_wave))
	# Emit per-kill signal — consumed by ArcherFormation momentum tracker.
	# Emitted before wave_cleared so streak bonus call_deferred fires after wave reset.
	enemy_killed.emit(_pos)
	# Remaining count — consumed by HUD to show "N left" during wave.
	enemies_remaining.emit(_active_enemies)
	# Wave complete — wait for player to press Start Wave button
	if _active_enemies <= 0 and _spawned_this_wave >= _wave_enemy_count:
		_wave_in_progress = false
		wave_cleared.emit()
		_waiting_for_next_wave = true
		wave_start_ready.emit()

## Distribute spawn positions along the right edge of the landscape world (1920×1080).
func _random_spawn_pos() -> Vector2:
	var y: float = randf_range(80.0, 1000.0)
	return Vector2(1950.0, y)

## Return visual tier index from wave number.
## T0 Medieval (0-9), T1 Elven (10-24), T2 Tracer (25-49), T3 Laser (50+).
static func _wave_to_visual_tier(wave_num: int) -> int:
	if wave_num >= 50: return 3
	if wave_num >= 25: return 2
	if wave_num >= 10: return 1
	return 0

func _on_session_reset() -> void:
	for e: Node in _pool.all_active():
		e.deactivate()
		e.scale = Vector2(1.0, 1.0)
		_pool.return_node(e)
	current_wave = 0
	total_kills = 0
	_active_enemies = 0
	_spawned_this_wave = 0
	_wave_enemy_count = 0
	_wave_tag = TAG_NORMAL
	_spawn_timer = 0.0
	_wave_in_progress = false
	_waiting_for_next_wave = false
	_start_wave(0)
