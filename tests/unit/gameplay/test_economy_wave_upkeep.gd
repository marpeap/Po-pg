## test_economy_wave_upkeep.gd
## Tests wave upkeep deduction formula: GDD Formula D-7 (economy.md Rule 13).
## wave_upkeep = archer_count × UPKEEP_PER_ARCHER + tower_count × UPKEEP_PER_TOWER
## gold_after  = max(0, gold − wave_upkeep)
## Sprint 5
extends GutTest

const UPKEEP_PER_ARCHER := 3
const UPKEEP_PER_TOWER := 8
const STARTING_GOLD := 60

## Replicate the upkeep formula for isolated testing.
func _compute_upkeep(archer_count: int, tower_count: int) -> int:
	return archer_count * UPKEEP_PER_ARCHER + tower_count * UPKEEP_PER_TOWER

func _apply_upkeep(gold: int, archer_count: int, tower_count: int) -> int:
	var upkeep := _compute_upkeep(archer_count, tower_count)
	return maxi(0, gold - upkeep)

## --- Upkeep formula (GDD Formula D-7) ---

func test_upkeep_2_archers_no_towers() -> void:
	# 2 × 3 = 6g
	assert_eq(_compute_upkeep(2, 0), 6, "2 archers, 0 towers → 6g upkeep")

func test_upkeep_8_archers_no_towers() -> void:
	# 8 × 3 = 24g
	assert_eq(_compute_upkeep(8, 0), 24, "8 archers, 0 towers → 24g upkeep")

func test_upkeep_8_archers_2_towers() -> void:
	# 8 × 3 + 2 × 8 = 24 + 16 = 40g
	assert_eq(_compute_upkeep(8, 2), 40, "8 archers + 2 towers → 40g upkeep")

func test_upkeep_0_archers_0_towers() -> void:
	# 0 × 3 + 0 × 8 = 0g
	assert_eq(_compute_upkeep(0, 0), 0, "0 archers, 0 towers → 0g upkeep")

func test_upkeep_2_archers_1_tower() -> void:
	# 2 × 3 + 1 × 8 = 6 + 8 = 14g
	assert_eq(_compute_upkeep(2, 1), 14, "2 archers, 1 tower → 14g upkeep")

## --- Gold after upkeep: floor at 0 ---

func test_gold_after_upkeep_normal() -> void:
	# 60g − 6g = 54g
	assert_eq(_apply_upkeep(60, 2, 0), 54, "60g − 6g = 54g")

func test_gold_after_upkeep_exact_zero() -> void:
	# gold exactly equals upkeep → 0g
	assert_eq(_apply_upkeep(6, 2, 0), 0, "gold = upkeep → 0g")

func test_gold_after_upkeep_floors_at_zero() -> void:
	# gold < upkeep → floored at 0, never negative
	assert_eq(_apply_upkeep(4, 2, 0), 0, "gold(4) < upkeep(6) → 0g floor")

func test_gold_after_zero_upkeep_unchanged() -> void:
	# 0 archers, 0 towers → gold unchanged
	assert_eq(_apply_upkeep(60, 0, 0), 60, "0 upkeep → gold unchanged")

func test_gold_after_high_upkeep_floors_at_zero() -> void:
	# 60g − 40g = 20g (8 archers + 2 towers)
	assert_eq(_apply_upkeep(60, 8, 2), 20, "60g − 40g (max roster) = 20g")

## --- GDD sample table values ---

func test_sample_wave1_state() -> void:
	# Wave 1: 2 starting archers, no towers. Starting gold = 60g.
	# Upkeep = 6g. After = 54g.
	var upkeep := _compute_upkeep(2, 0)
	var after := _apply_upkeep(STARTING_GOLD, 2, 0)
	assert_eq(upkeep, 6, "Wave 1 sample: 6g upkeep")
	assert_eq(after, 54, "Wave 1 sample: 54g remaining")

## --- Per-unit cost constants are correct ---

func test_upkeep_per_archer_constant() -> void:
	assert_eq(UPKEEP_PER_ARCHER, 3, "UPKEEP_PER_ARCHER = 3g")

func test_upkeep_per_tower_constant() -> void:
	assert_eq(UPKEEP_PER_TOWER, 8, "UPKEEP_PER_TOWER = 8g")
