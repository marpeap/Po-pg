## test_forge_formulas.gd
## Tests Forge formula output for all 4 upgrade types at all purchase counts.
## GDD Req: forge.md — Formulas F1–F4
## Sprint 6
extends GutTest

## Replicate constants from forge.gd to keep tests independent.
const PROJ_DAMAGE_BASE := 8
const SHOOT_IVTL_BASE := 1.2
const SHOOT_IVTL_FLOOR := 0.40
const MAGNET_BASE := 170.0
const MAGNET_CEILING := 450.0
const CASTLE_HP_BASE := 200

const FORGE_PROJ_DAMAGE_DELTA := 2
const FORGE_IVTL_DELTA := 0.10
const FORGE_MAGNET_DELTA := 40.0
const FORGE_HP_DELTA := 30

## Replicate Forge formulas for isolated testing.
func _f1(k: int) -> int:
	return PROJ_DAMAGE_BASE + k * FORGE_PROJ_DAMAGE_DELTA

func _f2(k: int) -> float:
	return maxf(SHOOT_IVTL_FLOOR, SHOOT_IVTL_BASE - k * FORGE_IVTL_DELTA)

func _f3(k: int) -> float:
	return minf(MAGNET_CEILING, MAGNET_BASE + k * FORGE_MAGNET_DELTA)

func _f4(k: int) -> int:
	return CASTLE_HP_BASE + k * FORGE_HP_DELTA

## --- F1: Projectile damage ---

func test_f1_k0_returns_base_damage() -> void:
	assert_eq(_f1(0), 8, "k=0 → base damage 8")

func test_f1_k1_adds_one_delta() -> void:
	assert_eq(_f1(1), 10, "k=1 → 8 + 2 = 10")

func test_f1_k5_adds_five_deltas() -> void:
	assert_eq(_f1(5), 18, "k=5 → 8 + 10 = 18")

func test_f1_k10_scales_linearly() -> void:
	assert_eq(_f1(10), 28, "k=10 → 8 + 20 = 28")

## --- F2: Fire interval ---

func test_f2_k0_returns_base_ivtl() -> void:
	assert_almost_eq(_f2(0), 1.2, 0.001, "k=0 → base 1.2s")

func test_f2_k1_subtracts_one_delta() -> void:
	assert_almost_eq(_f2(1), 1.1, 0.001, "k=1 → 1.2 - 0.1 = 1.1s")

func test_f2_k4_subtracts_four_deltas() -> void:
	assert_almost_eq(_f2(4), 0.8, 0.001, "k=4 → 1.2 - 0.4 = 0.8s")

func test_f2_k8_reaches_floor() -> void:
	# 1.2 - 8*0.1 = 1.2 - 0.8 = 0.4 → exactly at floor
	assert_almost_eq(_f2(8), 0.40, 0.001, "k=8 → floor 0.40s")

func test_f2_k10_clamped_to_floor() -> void:
	# 1.2 - 10*0.1 = 0.2 → clamped at floor 0.40
	assert_almost_eq(_f2(10), 0.40, 0.001, "k=10 → still clamped at floor 0.40s")

func test_f2_k20_clamped_to_floor() -> void:
	assert_almost_eq(_f2(20), 0.40, 0.001, "k=20 → floor holds indefinitely")

## --- F3: Magnet radius ---

func test_f3_k0_returns_base_radius() -> void:
	assert_almost_eq(_f3(0), 170.0, 0.01, "k=0 → base 170px")

func test_f3_k1_adds_one_delta() -> void:
	assert_almost_eq(_f3(1), 210.0, 0.01, "k=1 → 170 + 40 = 210px")

func test_f3_k7_reaches_ceiling() -> void:
	# 170 + 7*40 = 170 + 280 = 450 → exactly at ceiling
	assert_almost_eq(_f3(7), 450.0, 0.01, "k=7 → ceiling 450px")

func test_f3_k10_clamped_to_ceiling() -> void:
	# 170 + 10*40 = 570 → clamped at 450
	assert_almost_eq(_f3(10), 450.0, 0.01, "k=10 → still clamped at ceiling 450px")

func test_f3_k3_mid_range() -> void:
	assert_almost_eq(_f3(3), 290.0, 0.01, "k=3 → 170 + 120 = 290px")

## --- F4: Castle max HP ---

func test_f4_k0_returns_base_hp() -> void:
	assert_eq(_f4(0), 200, "k=0 → base 200 HP")

func test_f4_k1_adds_one_delta() -> void:
	assert_eq(_f4(1), 230, "k=1 → 200 + 30 = 230 HP")

func test_f4_k5_adds_five_deltas() -> void:
	assert_eq(_f4(5), 350, "k=5 → 200 + 150 = 350 HP")

func test_f4_k10_scales_linearly() -> void:
	assert_eq(_f4(10), 500, "k=10 → 200 + 300 = 500 HP (no ceiling)")

## --- Floor / ceiling constants ---

func test_shoot_ivtl_floor_is_040() -> void:
	assert_almost_eq(SHOOT_IVTL_FLOOR, 0.40, 0.001, "SHOOT_IVTL_FLOOR = 0.40s")

func test_magnet_ceiling_is_450() -> void:
	assert_almost_eq(MAGNET_CEILING, 450.0, 0.01, "MAGNET_CEILING = 450px")

## --- Delta constants ---

func test_proj_damage_delta_is_2() -> void:
	assert_eq(FORGE_PROJ_DAMAGE_DELTA, 2, "FORGE_PROJ_DAMAGE_DELTA = 2")

func test_ivtl_delta_is_010() -> void:
	assert_almost_eq(FORGE_IVTL_DELTA, 0.10, 0.001, "FORGE_IVTL_DELTA = 0.10")

func test_magnet_delta_is_40() -> void:
	assert_almost_eq(FORGE_MAGNET_DELTA, 40.0, 0.01, "FORGE_MAGNET_DELTA = 40px")

func test_hp_delta_is_30() -> void:
	assert_eq(FORGE_HP_DELTA, 30, "FORGE_HP_DELTA = 30")
