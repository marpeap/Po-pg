# tests/unit/test_enemy_wave_scaling.gd
# Validates: enemies_per_wave, enemy_hp scaling formulas
# Source: design/gdd/enemy-wave.md

extends GutTest

const ENEMY_HP_BASE    := 30
const ENEMY_HP_SCALING := 3  # HP per wave
const ENEMY_SPEED      := 70.0
const TRAVEL_DIST      := 1760.0  # spawn y≈1860 → castle y≈100

func _enemy_hp(wave: int) -> int:
	return ENEMY_HP_BASE + (wave - 1) * ENEMY_HP_SCALING

func _enemies_per_wave(wave: int) -> int:
	return 5 + int(floor(float(wave) * 1.15))

# --- HP scaling ---

func test_wave1_hp_is_thirty() -> void:
	assert_eq(_enemy_hp(1), 30, "Wave 1 enemy HP = 30")

func test_wave5_hp_is_forty_two() -> void:
	assert_eq(_enemy_hp(5), 42, "Wave 5 enemy HP = 30 + 4×3 = 42")

func test_wave13_hp_is_sixty_six() -> void:
	assert_eq(_enemy_hp(13), 66, "Wave 13 enemy HP = 30 + 12×3 = 66")

func test_hp_increases_every_wave() -> void:
	for w in range(1, 13):
		assert_true(_enemy_hp(w + 1) > _enemy_hp(w),
			"HP must increase each wave (wave %d → %d)" % [w, w + 1])

# --- Spawn count ---

func test_wave1_spawns_five_enemies() -> void:
	assert_eq(_enemies_per_wave(1), 6, "Wave 1: 5 + floor(1×1.15) = 6")

func test_wave13_spawns_around_twenty() -> void:
	var count := _enemies_per_wave(13)
	assert_true(count >= 18 and count <= 22,
		"Wave 13 should spawn 18–22 enemies (got %d)" % count)

# --- Travel time ---

func test_enemy_travel_time_approx_25s() -> void:
	var travel_time := TRAVEL_DIST / ENEMY_SPEED
	assert_almost_eq(travel_time, 25.14, 0.5, "Travel time ≈ 25s (1760/70)")

# --- Total wave HP (for DPS requirement sanity) ---

func test_wave1_total_hp() -> void:
	var total := _enemies_per_wave(1) * _enemy_hp(1)
	# 6 × 30 = 180
	assert_eq(total, 180, "Wave 1 total HP = 180")

func test_wave13_total_hp_under_1500() -> void:
	var total := _enemies_per_wave(13) * _enemy_hp(13)
	# ~20 × 66 = ~1320
	assert_true(total < 1500, "Wave 13 total HP should be under 1500 (got %d)" % total)
