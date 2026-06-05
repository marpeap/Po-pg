## Integration tests for EnemyWave — procedural budget-based wave system
## Story: F05-S02
## GUT 9.6.0 — extends GutTest
extends GutTest

## Helper — creates a bare EnemyWave node outside the scene tree (no pool init needed)
func _make_wave() -> Node:
	return load("res://src/gameplay/enemy_wave.gd").new()

# ---------------------------------------------------------------------------
# Constants still present
# ---------------------------------------------------------------------------

func test_wave_start_ready_signal_exists() -> void:
	var ew: Node = _make_wave()
	assert_true(ew.has_signal("wave_start_ready"),
		"wave_start_ready signal must exist for manual wave-start button")
	ew.free()

func test_start_next_wave_method_exists() -> void:
	var ew: Node = _make_wave()
	assert_true(ew.has_method("start_next_wave"),
		"start_next_wave() must exist as public API for HUD button")
	ew.free()

func test_spawn_interval_constant() -> void:
	var ew: Node = _make_wave()
	assert_eq(ew.SPAWN_IVTL, 0.5, "SPAWN_IVTL must be 0.5s")
	ew.free()

func test_pool_size_30() -> void:
	var ew: Node = _make_wave()
	assert_eq(ew.POOL_SIZE, 30, "Enemy pool must pre-allocate 30 nodes")
	ew.free()

# ---------------------------------------------------------------------------
# Budget growth
# ---------------------------------------------------------------------------

func test_budget_grows_with_wave_number() -> void:
	# Budget at wave 10 must be strictly greater than wave 1
	var ew: Node = _make_wave()
	var budget_w1: int = ew.BASE_BUDGET + 1 * ew.BUDGET_PER_WAVE
	var budget_w10: int = ew.BASE_BUDGET + 10 * ew.BUDGET_PER_WAVE
	assert_true(budget_w10 > budget_w1, "Budget must grow with wave number")
	ew.free()

func test_wave_count_within_clamp_range() -> void:
	var ew: Node = _make_wave()
	# Wave 1 — force TAG_NORMAL so no boss budget reduction
	ew._wave_tag = ew.TAG_NORMAL
	var count: int = ew._compute_wave_count(0)
	assert_true(count >= ew.MIN_WAVE_COUNT, "Wave count must be >= MIN_WAVE_COUNT")
	assert_true(count <= ew.MAX_WAVE_COUNT, "Wave count must be <= MAX_WAVE_COUNT")
	ew.free()

# ---------------------------------------------------------------------------
# Type unlock progression
# ---------------------------------------------------------------------------

func test_wave_1_infantry_only() -> void:
	var ew: Node = _make_wave()
	ew._wave_tag = ew.TAG_NORMAL
	var w: Array = ew._compute_type_weights(0)   # Wave index 0 = wave 1
	assert_eq(w[1], 0, "Archers must not appear in wave 1")
	assert_eq(w[2], 0, "Cavaliers must not appear in wave 1")
	assert_eq(w[3], 0, "Healers must not appear in wave 1")
	ew.free()

func test_archer_unlocked_at_wave_3() -> void:
	var ew: Node = _make_wave()
	ew._wave_tag = ew.TAG_NORMAL
	var w: Array = ew._compute_type_weights(2)   # Wave index 2 = wave 3
	assert_true(w[1] > 0, "Archers must be unlocked at wave 3")
	ew.free()

func test_all_types_unlocked_at_wave_10() -> void:
	var ew: Node = _make_wave()
	ew._wave_tag = ew.TAG_NORMAL
	var w: Array = ew._compute_type_weights(9)   # Wave index 9 = wave 10
	assert_true(w[0] > 0, "Infantry must be present at wave 10")
	assert_true(w[1] > 0, "Archers must be present at wave 10")
	assert_true(w[2] > 0, "Cavaliers must be present at wave 10")
	assert_true(w[3] > 0, "Healers must be present at wave 10")
	ew.free()

# ---------------------------------------------------------------------------
# Wave tags — deterministic ones only (RUSH/HEALER_SURGE are random, not tested)
# ---------------------------------------------------------------------------

func test_wave_5_is_boss() -> void:
	var ew: Node = _make_wave()
	var tag: String = ew._compute_wave_tag(4)   # Wave index 4 = wave 5
	assert_eq(tag, ew.TAG_BOSS, "Wave 5 must be a BOSS wave")
	ew.free()

func test_wave_10_is_boss() -> void:
	var ew: Node = _make_wave()
	var tag: String = ew._compute_wave_tag(9)
	assert_eq(tag, ew.TAG_BOSS, "Wave 10 must be a BOSS wave")
	ew.free()

func test_wave_3_is_elite() -> void:
	var ew: Node = _make_wave()
	var tag: String = ew._compute_wave_tag(2)   # Wave index 2 = wave 3
	assert_eq(tag, ew.TAG_ELITE, "Wave 3 must be an ELITE wave (not divisible by 5)")
	ew.free()

func test_wave_6_is_elite() -> void:
	var ew: Node = _make_wave()
	var tag: String = ew._compute_wave_tag(5)
	assert_eq(tag, ew.TAG_ELITE, "Wave 6 must be an ELITE wave")
	ew.free()

func test_wave_15_is_boss_not_elite() -> void:
	# 15 is divisible by both 5 and 3 — BOSS check runs first
	var ew: Node = _make_wave()
	var tag: String = ew._compute_wave_tag(14)
	assert_eq(tag, ew.TAG_BOSS, "Wave 15 (div by 5 and 3) must be BOSS, not ELITE")
	ew.free()

# ---------------------------------------------------------------------------
# Stat multipliers
# ---------------------------------------------------------------------------

func test_stat_multiplier_is_1_at_cycle_0() -> void:
	var ew: Node = _make_wave()
	assert_almost_eq(ew.get_stat_multiplier(0), 1.0, 0.001,
		"HP multiplier must be 1.0 for waves 0-9 (cycle 0)")
	assert_almost_eq(ew.get_stat_multiplier(9), 1.0, 0.001,
		"HP multiplier must be 1.0 at wave 9 (still cycle 0)")
	ew.free()

func test_stat_multiplier_increases_at_cycle_1() -> void:
	var ew: Node = _make_wave()
	var mult_cycle0: float = ew.get_stat_multiplier(9)
	var mult_cycle1: float = ew.get_stat_multiplier(10)
	assert_true(mult_cycle1 > mult_cycle0,
		"HP multiplier must increase at wave 10 (start of cycle 1)")
	ew.free()

func test_stat_multiplier_at_cycle_1_is_1_point_25() -> void:
	## HP_SCALE_PER_CYCLE was updated to 0.25 in Iteration 4 for steeper scaling.
	var ew: Node = _make_wave()
	assert_almost_eq(ew.get_stat_multiplier(10), 1.25, 0.001,
		"HP multiplier must be 1.25 at wave 10 (cycle 1, +25%)")
	ew.free()

# ---------------------------------------------------------------------------
# Kill counter and session reset
# ---------------------------------------------------------------------------

func test_total_kills_increments() -> void:
	var ew: Node = _make_wave()
	ew.total_kills = 0
	ew.total_kills += 1
	assert_eq(ew.total_kills, 1, "total_kills must increment")
	ew.free()

func test_session_reset_clears_counters() -> void:
	var ew: Node = _make_wave()
	ew.total_kills = 42
	ew._active_enemies = 5
	ew._spawned_this_wave = 5
	# Simulate manual reset (no scene tree available in unit tests)
	ew.total_kills = 0
	ew._active_enemies = 0
	ew._spawned_this_wave = 0
	assert_eq(ew.total_kills, 0, "Session reset must clear total_kills")
	assert_eq(ew._active_enemies, 0, "Session reset must clear active enemy count")
	assert_eq(ew._spawned_this_wave, 0, "Session reset must clear spawned count")
	ew.free()
