## ArcherFormation — V/LINE/ARC formation + targeting priority + momentum kill-streak
## ADR-004: Frame-rate-independent lerp  1.0 - pow(1.0-F, delta*60)
## ADR-002: Area2D overlap only (arrows use Area2D)
## ADR-003: Arrow pool shared with ArcherTower
## GDD Req: TR-archer-001, TR-archer-002
## Sprint 5: Targeting Priority (Rules 11-13), Tactical Formations (Rules 14-17), Momentum
extends Node2D

## Emitted when the formation fills all 8 slots.
signal formation_full
## Emitted when the Momentum streak tier changes (0=none, 1/2/3=TIER_1/2/3).
signal streak_tier_changed(tier: int)
## Emitted when a Momentum tier transition earns a gold bonus; Economy adds the amount.
signal streak_gold_bonus(amount: int)
## Emitted when targeting mode cycles; HUD updates label display.
signal targeting_mode_changed(mode: int)
## Emitted when formation mode cycles; HUD can react.
signal formation_mode_changed(mode: int)

## --- Targeting Priority ---

enum TargetingMode {
	NEAREST,    ## Min distance to archers[0] — always available
	FIRST,      ## Min distance to castle (most dangerous) — Forge-gated
	STRONGEST,  ## Max current HP — Forge-gated
	WEAKEST,    ## Min current HP — Forge-gated
}

## --- Tactical Formations ---

enum FormationMode {
	V_FORMATION,  ## Default V shape — always available
	LINE,          ## Single horizontal line behind hero — Forge-gated
	ARC,           ## Semicircle arc facing enemies — Forge-gated
}

## V-formation slot offsets in hero-local space (rotated each frame by facing_angle + PI/2)
const FORMATION_V: Array[Vector2] = [
	Vector2(0.0,    50.0),    # Slot 1 — center rear
	Vector2(-35.0,  80.0),    # Slot 2 — left second rank
	Vector2(35.0,   80.0),    # Slot 3 — right second rank
	Vector2(-70.0,  110.0),   # Slot 4 — left third rank
	Vector2(70.0,   110.0),   # Slot 5 — right third rank
	Vector2(-105.0, 140.0),   # Slot 6 — left fourth rank
	Vector2(105.0,  140.0),   # Slot 7 — right fourth rank
	Vector2(0.0,    170.0),   # Slot 8 — rear center
]

## LINE: one horizontal row behind hero. y=58 = HERO_RADIUS(18) + LINE_DEPTH(40).
## x pairs: ±25, ±50, ±75, ±100 (LINE_LATERAL_STEP=25px). GDD Formula D-8.
const FORMATION_LINE: Array[Vector2] = [
	Vector2(-25.0,  58.0),   # Slot 0
	Vector2( 25.0,  58.0),   # Slot 1
	Vector2(-50.0,  58.0),   # Slot 2
	Vector2( 50.0,  58.0),   # Slot 3
	Vector2(-75.0,  58.0),   # Slot 4
	Vector2( 75.0,  58.0),   # Slot 5
	Vector2(-100.0, 58.0),   # Slot 6
	Vector2( 100.0, 58.0),   # Slot 7
]

## ARC: semicircle, ARC_RADIUS=80, ARC_ANGLE_STEP=PI/8 (22.5°). GDD Formula D-9.
## Computed as Vector2(sin(angle)*R, cos(angle)*R) in hero-behind space.
const FORMATION_ARC: Array[Vector2] = [
	Vector2(-30.58, 73.91),  # Slot 0 — 22.5° left
	Vector2( 30.58, 73.91),  # Slot 1 — 22.5° right
	Vector2(-56.57, 56.57),  # Slot 2 — 45° left
	Vector2( 56.57, 56.57),  # Slot 3 — 45° right
	Vector2(-73.91, 30.58),  # Slot 4 — 67.5° left
	Vector2( 73.91, 30.58),  # Slot 5 — 67.5° right
	Vector2(-80.0,   0.0),   # Slot 6 — 90° left (direct flank)
	Vector2( 80.0,   0.0),   # Slot 7 — 90° right (direct flank)
]

## Castle world position — used by FIRST targeting mode to find closest-to-castle enemy.
## Must match Castle.CASTLE_POS and enemy.gd CASTLE_POS (landscape world 1920×1080).
const CASTLE_POS := Vector2(200.0, 540.0)

## --- Archer constants ---

const ARCHER_LERP_F := 0.12
const STARTING_ARCHERS := 2
const MAX_FORMATION_SLOTS := 8
const SHOOT_IVTL := 1.2       ## Fallback fire interval when no Forge reference is set
const SHOOT_RANGE := 300.0    ## Max range to target enemy (for NEAREST; applied to all modes)
## Base projectile damage — fallback when no Forge reference is set.
const PROJ_DAMAGE_BASE := 8
## Base arrow speed — must match Arrow.PROJ_SPEED in arrow.gd.
const PROJ_SPEED_BASE := 400.0

## --- Momentum constants ---

const STREAK_WINDOW := 4.0     ## Seconds of inactivity before streak resets mid-wave
## Tier thresholds: TIER_1 at 5 kills, TIER_2 at 10, TIER_3 at 15.
const STREAK_TIER_THRESHOLDS: Array[int] = [0, 5, 10, 15]
## DPS multipliers per tier (applied to PROJ_DAMAGE_BASE). GDD Formula D-MO-1.
const STREAK_TIER_MULT: Array[float] = [1.0, 1.15, 1.30, 1.50]
## Gold bonus granted on tier transition (index = new tier). GDD Formula D-MO-2.
const STREAK_TIER_GOLD: Array[int] = [0, 10, 20, 30]

## --- Forge gate flags ---
## Forge system (Alpha) will set these false at startup and unlock them via upgrade.
## Defaulting to true until Forge is built — all Sprint 5 modes available from the start.
@export var targeting_protocol_unlocked := true
@export var formation_doctrine_unlocked := true

## --- Public state ---

var current_archer_count: int = 0
var current_targeting_mode: TargetingMode = TargetingMode.NEAREST
var current_formation_mode: FormationMode = FormationMode.V_FORMATION
var kill_streak: int = 0

## --- Private state ---

var _archers: Array[Node2D] = []
var _slots_active: int = STARTING_ARCHERS
var _shoot_timer: float = 0.0
var _streak_tier: int = 0
var _time_since_last_kill: float = 0.0
var _current_archer_tier: int = -1  ## Tracks applied archer visual tier to detect changes

var _hero: Node2D           ## Set by Main
var _enemy_wave: Node       ## Set by Main — provides active enemy list
var _arrow_pool: ObjectPool ## Shared with ArcherTower — set by Main
var _forge: Node            ## Optional Forge reference — set by Main for live stat scaling

## Crafting equipment bonuses — applied by Main._apply_crafted_item_effects() on return.
var _crafted_arrow_dmg_bonus: int   = 0    ## Iron Arrowheads / Heavy Broadhead
var _crafted_speed_bonus:     float = 1.0  ## Silk Quiver: arrow speed multiplier
var _has_poison_quiver:       bool  = false ## POISON_QUIVER: 25% proc chance on hit
var _has_fire_quiver:         bool  = false ## FIRE_QUIVER:   33% proc chance on hit
var _has_formation_banner:    bool  = false ## FORMATION_BANNER: lerp 30% faster
## NPC Caelo "momentum_boost": multiplies all streak gold bonuses by 1.50.
var _momentum_gold_mult: float = 1.0

## Quest chapter rewards (applied by Main._on_quest_chapter_completed).
var _range_bonus:       float = 0.0   ## "archer_range_+10": flat px added to SHOOT_RANGE
var _arrow_speed_mult:  float = 1.0   ## "arrow_speed_+15pct": multiplied onto PROJ_SPEED_BASE
var _damage_bonus_mult: float = 1.0   ## "archer_dmg_+10pct": multiplied onto compute_arrow_damage

func _ready() -> void:
	GameStateMachine.session_reset.connect(_on_session_reset)

## Called by Main after all nodes are set up.
## forge param is optional; when null the formation uses PROJ_DAMAGE_BASE and SHOOT_IVTL constants.
func setup(hero: Node2D, enemy_wave: Node, arrow_pool: ObjectPool, forge: Node = null) -> void:
	_hero = hero
	_enemy_wave = enemy_wave
	_arrow_pool = arrow_pool
	_forge = forge
	# Spawn archer visual nodes — added to GameWorld (parent) so
	# they participate in GameWorld's y_sort_enabled depth sorting.
	# Guard: get_parent() is null in unit tests (no scene tree parent); fall back to self.
	var world: Node = get_parent() if get_parent() != null else self
	var archer_script := load("res://src/gameplay/archer.gd")
	for i in range(MAX_FORMATION_SLOTS):
		var a: Node2D = Node2D.new()
		a.set_script(archer_script)
		world.add_child(a)
		_archers.append(a)
		if i >= STARTING_ARCHERS:
			a.hide()
	current_archer_count = STARTING_ARCHERS

func _process(delta: float) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	if _hero == null:
		return

	# Momentum streak window — reset if no kill for STREAK_WINDOW seconds
	if kill_streak > 0:
		_time_since_last_kill += delta
		if _time_since_last_kill > STREAK_WINDOW:
			_reset_streak()

	# Formation lerp (ADR-004) — FORMATION_BANNER speeds repositioning by 30%
	var hero_pos: Vector2 = _hero.position
	var angle: float = _hero.facing_angle + PI / 2.0
	var lerp_f: float = ARCHER_LERP_F * (1.30 if _has_formation_banner else 1.0)
	var weight: float = 1.0 - pow(1.0 - lerp_f, delta * 60.0)
	var formation_array: Array[Vector2] = _get_formation_array()
	for i in range(_slots_active):
		var slot_offset: Vector2 = formation_array[i].rotated(angle)
		var target: Vector2 = hero_pos + slot_offset
		_archers[i].position = _archers[i].position.lerp(target, weight)

	# Auto-fire
	_shoot_timer += delta
	var ivtl: float = _forge.effective_shoot_ivtl() if _forge != null else SHOOT_IVTL
	if _shoot_timer >= ivtl:
		_shoot_timer = 0.0
		_fire_volley()

## Return the slot-offset array for the current formation mode.
func _get_formation_array() -> Array[Vector2]:
	match current_formation_mode:
		FormationMode.LINE: return FORMATION_LINE
		FormationMode.ARC:  return FORMATION_ARC
	return FORMATION_V  # V_FORMATION (default)

## Fire all active archers toward the selected target within SHOOT_RANGE.
## Applies Momentum effective_damage to each arrow.
func _fire_volley() -> void:
	if _arrow_pool == null or _enemy_wave == null:
		return
	var target: Node = _targeting_select()
	if target == null:
		return
	var effective_damage: int = _compute_effective_damage()
	var effective_speed: float = PROJ_SPEED_BASE * _crafted_speed_bonus * _arrow_speed_mult
	var vtier: int = _wave_to_visual_tier(_enemy_wave.current_wave)
	## Update archer sprites when visual tier changes (wave threshold crossed).
	if vtier != _current_archer_tier:
		_current_archer_tier = vtier
		for a: Node2D in _archers:
			if a.has_method("set_visual_tier"):
				a.set_visual_tier(vtier)
	for i in range(_slots_active):
		var arrow: Node = _arrow_pool.checkout()
		if arrow == null:
			continue
		var dir: Vector2 = (target.position - _archers[i].position).normalized()
		var do_poison: bool = _has_poison_quiver and randf() < 0.25
		var do_fire:   bool = _has_fire_quiver   and randf() < 0.33
		arrow.activate(_archers[i].position, dir, _arrow_pool, effective_damage, 1.0, 0.0, effective_speed, do_poison, do_fire, vtier)
	AudioManager.play_volley(_slots_active)

## Compute effective damage = floor((base_damage + crafted_bonus) * streak_multiplier). GDD Formula D-MO-1.
## Base damage comes from Forge F1 when available, else PROJ_DAMAGE_BASE constant.
## _crafted_arrow_dmg_bonus: +8 Iron Arrowheads, +15 Heavy Broadhead (set by Main on TD return).
func _compute_effective_damage() -> int:
	var base: int = _forge.effective_proj_damage() if _forge != null else PROJ_DAMAGE_BASE
	return floori(float(base + _crafted_arrow_dmg_bonus) * STREAK_TIER_MULT[_streak_tier] * _damage_bonus_mult)

## Select a target enemy according to current_targeting_mode.
## Filters to SHOOT_RANGE first, then applies selection criterion. GDD Formula D-7.
func _targeting_select() -> Node:
	if _enemy_wave == null or _archers.is_empty():
		return null
	var pool: Array = _enemy_wave._pool.all_active()

	# Range filter — all modes only fire at enemies within SHOOT_RANGE of archers[0]
	var weather_range_mult: float = WeatherManager.get_archer_range_mult() if WeatherManager != null else 1.0
	var effective_range: float = (SHOOT_RANGE + _range_bonus) * weather_range_mult
	var in_range: Array = []
	for enemy: Node in pool:
		if enemy.position.distance_to(_archers[0].position) <= effective_range:
			in_range.append(enemy)

	if in_range.is_empty():
		return null

	match current_targeting_mode:
		TargetingMode.FIRST:
			# Enemy closest to the castle — most threatening, ignore archer proximity
			var best: Node = null
			var best_dist := INF
			for enemy: Node in in_range:
				var d: float = enemy.position.distance_to(CASTLE_POS)
				if d < best_dist:
					best_dist = d
					best = enemy
			return best

		TargetingMode.STRONGEST:
			# Enemy with highest remaining HP — focus fire for efficient kills
			var best: Node = null
			var best_hp: int = -1
			for enemy: Node in in_range:
				if (enemy.hp as int) > best_hp:
					best_hp = enemy.hp
					best = enemy
			return best

		TargetingMode.WEAKEST:
			# Enemy with lowest remaining HP — finish-off priority
			var best: Node = null
			var best_hp: int = 999999
			for enemy: Node in in_range:
				if (enemy.hp as int) < best_hp:
					best_hp = enemy.hp
					best = enemy
			return best

		_:  # TargetingMode.NEAREST (default)
			var best: Node = null
			var best_dist := INF
			for enemy: Node in in_range:
				var d: float = enemy.position.distance_to(_archers[0].position)
				if d < best_dist:
					best_dist = d
					best = enemy
			return best

## --- Momentum ---

## Called by Main when enemy_wave.enemy_killed fires.
## pos parameter required to match signal signature (pos unused for momentum).
func on_enemy_killed(_pos: Vector2) -> void:
	_time_since_last_kill = 0.0
	kill_streak += 1
	var new_tier: int = _compute_tier()
	if new_tier != _streak_tier:
		_streak_tier = new_tier
		streak_tier_changed.emit(new_tier)
		_update_streak_visuals()
		# call_deferred ensures wave_cleared resets streak BEFORE bonus is granted.
		# If this kill is the final wave kill, wave_cleared fires synchronously
		# (in the same frame), resetting kill_streak to 0 before _grant_streak_bonus runs.
		# The deferred call then sees kill_streak == 0 and skips the grant (AC-MO-11).
		call_deferred("_grant_streak_bonus", new_tier)

## Deferred — runs after any same-frame wave_cleared signal has reset the streak.
func _grant_streak_bonus(tier: int) -> void:
	if kill_streak == 0:
		return  # Final kill of wave — no bonus per AC-MO-11
	streak_gold_bonus.emit(int(float(STREAK_TIER_GOLD[tier]) * _momentum_gold_mult))

## Compute tier (0–3) from current kill_streak.
func _compute_tier() -> int:
	var t := 0
	for i in range(STREAK_TIER_THRESHOLDS.size()):
		if kill_streak >= STREAK_TIER_THRESHOLDS[i]:
			t = i
	return t

## Called by Main when enemy_wave.wave_cleared fires — resets streak per GDD Rule MO-4.
func _on_wave_cleared() -> void:
	_reset_streak()

func _reset_streak() -> void:
	kill_streak = 0
	_time_since_last_kill = 0.0
	if _streak_tier != 0:
		_streak_tier = 0
		streak_tier_changed.emit(0)
		_update_streak_visuals()

## Apply modulate tint to all archers based on streak tier.
func _update_streak_visuals() -> void:
	var tint: Color
	match _streak_tier:
		1: tint = Color(1.0, 0.90, 0.70)   # TIER_1 — warm amber tint
		2: tint = Color(1.0, 0.80, 0.40)   # TIER_2 — deep orange
		3: tint = Color(1.0, 0.70, 0.00)   # TIER_3 — full gold overcharge
		_: tint = Color.WHITE               # No streak
	for archer: Node2D in _archers:
		archer.modulate = tint

## --- Targeting / Formation cycle (called by Economy zones) ---

## Cycle to the next available targeting mode. Forge-gated modes skip if not unlocked.
func cycle_targeting_mode() -> void:
	if not targeting_protocol_unlocked:
		return  # Zone active before upgrade — no-op per GDD Edge Case TP-E3
	var all_modes: Array[TargetingMode] = [
		TargetingMode.NEAREST,
		TargetingMode.FIRST,
		TargetingMode.STRONGEST,
		TargetingMode.WEAKEST,
	]
	var idx: int = all_modes.find(current_targeting_mode)
	current_targeting_mode = all_modes[(idx + 1) % all_modes.size()]
	targeting_mode_changed.emit(current_targeting_mode)

## Cycle to the next available formation mode. Forge-gated modes skip if not unlocked.
func cycle_formation_mode() -> void:
	if not formation_doctrine_unlocked:
		return  # Zone active before upgrade — no-op per GDD Edge Case TF-E6
	var all_modes: Array[FormationMode] = [
		FormationMode.V_FORMATION,
		FormationMode.LINE,
		FormationMode.ARC,
	]
	var idx: int = all_modes.find(current_formation_mode)
	current_formation_mode = all_modes[(idx + 1) % all_modes.size()]
	formation_mode_changed.emit(current_formation_mode)

## --- Archer management ---

## Called by Economy.recruit_purchased — adds one archer to the formation.
func on_recruit_purchased() -> void:
	if _slots_active >= MAX_FORMATION_SLOTS:
		return
	_archers[_slots_active].show()
	_slots_active += 1
	current_archer_count = _slots_active
	if _slots_active == MAX_FORMATION_SLOTS:
		formation_full.emit()

## Called by Main.on_tower_purchased — releases 2 archer slots to the tower (GDD R3).
## TOWER_ARCHERS_COUNT = 2 (fixed per archer-tower.md tuning knobs).
func on_tower_purchased() -> void:
	const TOWER_ARCHERS_COUNT := 2
	for i in range(TOWER_ARCHERS_COUNT):
		if _slots_active <= 0:
			break
		_slots_active -= 1
		_archers[_slots_active].hide()
	current_archer_count = _slots_active

func _on_session_reset() -> void:
	_slots_active = STARTING_ARCHERS
	current_archer_count = STARTING_ARCHERS
	_shoot_timer = 0.0
	# Reset targeting/formation to defaults (GDD Rule 10 — session_reset)
	current_targeting_mode = TargetingMode.NEAREST
	current_formation_mode = FormationMode.V_FORMATION
	# Reset momentum
	kill_streak = 0
	_streak_tier = 0
	_time_since_last_kill = 0.0
	_current_archer_tier = -1  ## Force tier reload on next fire after reset
	_update_streak_visuals()
	for i in range(MAX_FORMATION_SLOTS):
		if _hero != null:
			_archers[i].position = _hero.position
		if i < STARTING_ARCHERS:
			_archers[i].show()
		else:
			_archers[i].hide()

## Return visual tier index from wave number.
## T0 Medieval (0-9), T1 Elven (10-24), T2 Tracer (25-49), T3 Laser (50+).
static func _wave_to_visual_tier(wave_num: int) -> int:
	if wave_num >= 50: return 3
	if wave_num >= 25: return 2
	if wave_num >= 10: return 1
	return 0
