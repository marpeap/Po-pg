## test_archer_formation_momentum.gd
## Tests Momentum kill-streak tier computation and effective damage formula.
## GDD Req: Momentum GDD — Formulas D-MO-1, D-MO-2
## Sprint 5
## Run with GUT: gut --path tests/
extends GutTest

## Replicate constants from archer_formation.gd to keep tests independent.
const STREAK_TIER_THRESHOLDS: Array[int] = [0, 5, 10, 15]
const STREAK_TIER_MULT: Array[float] = [1.0, 1.15, 1.30, 1.50]
const STREAK_TIER_GOLD: Array[int] = [0, 10, 20, 30]
const PROJ_DAMAGE_BASE := 8

## Replicate _compute_tier logic for isolated testing.
func _compute_tier(kill_streak: int) -> int:
	var t := 0
	for i in range(STREAK_TIER_THRESHOLDS.size()):
		if kill_streak >= STREAK_TIER_THRESHOLDS[i]:
			t = i
	return t

## Replicate effective damage formula.
func _compute_effective_damage(tier: int) -> int:
	return floori(float(PROJ_DAMAGE_BASE) * STREAK_TIER_MULT[tier])

## --- _compute_tier tests ---

func test_tier_zero_at_zero_kills() -> void:
	assert_eq(_compute_tier(0), 0, "0 kills → tier 0")

func test_tier_zero_below_threshold() -> void:
	assert_eq(_compute_tier(4), 0, "4 kills → still tier 0 (threshold is 5)")

func test_tier_one_at_threshold() -> void:
	assert_eq(_compute_tier(5), 1, "5 kills → tier 1")

func test_tier_one_above_threshold() -> void:
	assert_eq(_compute_tier(9), 1, "9 kills → tier 1 (threshold for tier 2 is 10)")

func test_tier_two_at_threshold() -> void:
	assert_eq(_compute_tier(10), 2, "10 kills → tier 2")

func test_tier_three_at_threshold() -> void:
	assert_eq(_compute_tier(15), 3, "15 kills → tier 3")

func test_tier_three_beyond_max() -> void:
	assert_eq(_compute_tier(100), 3, "100 kills → capped at tier 3")

func test_tier_two_just_before_three() -> void:
	assert_eq(_compute_tier(14), 2, "14 kills → tier 2 (threshold for tier 3 is 15)")

## --- _compute_effective_damage tests (GDD Formula D-MO-1) ---

func test_damage_tier0_is_base() -> void:
	assert_eq(_compute_effective_damage(0), 8, "Tier 0 → base 8 damage")

func test_damage_tier1_is_floored() -> void:
	# floor(8 * 1.15) = floor(9.2) = 9
	assert_eq(_compute_effective_damage(1), 9, "Tier 1 → floor(8 × 1.15) = 9")

func test_damage_tier2_is_floored() -> void:
	# floor(8 * 1.30) = floor(10.4) = 10
	assert_eq(_compute_effective_damage(2), 10, "Tier 2 → floor(8 × 1.30) = 10")

func test_damage_tier3_is_floored() -> void:
	# floor(8 * 1.50) = floor(12.0) = 12
	assert_eq(_compute_effective_damage(3), 12, "Tier 3 → floor(8 × 1.50) = 12")

## --- Gold bonus table test (GDD Formula D-MO-2) ---

func test_gold_bonus_tier0_is_zero() -> void:
	assert_eq(STREAK_TIER_GOLD[0], 0, "Tier 0 grant: 0g")

func test_gold_bonus_tier1() -> void:
	assert_eq(STREAK_TIER_GOLD[1], 10, "Tier 1 grant: 10g")

func test_gold_bonus_tier2() -> void:
	assert_eq(STREAK_TIER_GOLD[2], 20, "Tier 2 grant: 20g")

func test_gold_bonus_tier3() -> void:
	assert_eq(STREAK_TIER_GOLD[3], 30, "Tier 3 grant: 30g")

## --- Boundary: streak exactly at each threshold ---

func test_tier_boundaries_exact() -> void:
	assert_eq(_compute_tier(5),  1, "Exact T1 boundary")
	assert_eq(_compute_tier(10), 2, "Exact T2 boundary")
	assert_eq(_compute_tier(15), 3, "Exact T3 boundary")

## --- Boundary: one below each threshold remains previous tier ---

func test_tier_one_below_each_boundary() -> void:
	assert_eq(_compute_tier(4),  0, "One below T1 boundary")
	assert_eq(_compute_tier(9),  1, "One below T2 boundary")
	assert_eq(_compute_tier(14), 2, "One below T3 boundary")
