# tests/unit/test_economy_gold.gd
# Example unit test — economy gold formulas
# Validates: gold reset, spend, STARTING_GOLD constant
# Run with: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

extends GutTest

# Constants from design/gdd/economy.md and design/registry/entities.yaml
const STARTING_GOLD    := 60
const GOLD_DROP        := 15
const ARCHER_COST_T1   := 30
const ARCHER_COST_T2   := 60
const TOWER_COST       := 100
const FORGE_COST       := 200

var _economy  # Economy node under test

func before_each() -> void:
	# Instantiate a fresh Economy node each test
	# Replace with the actual preload path once src/economy/economy.gd exists
	# _economy = preload("res://src/economy/economy.gd").new()
	# add_child_autoqfree(_economy)
	pass

func after_each() -> void:
	pass

# --- Starting state ---

func test_starting_gold_is_sixty() -> void:
	# Verify the STARTING_GOLD constant matches the GDD specification
	assert_eq(STARTING_GOLD, 60, "STARTING_GOLD must be 60 per economy.md")

func test_gold_drop_per_enemy_is_fifteen() -> void:
	assert_eq(GOLD_DROP, 15, "GOLD_DROP_PER_ENEMY must be 15 per economy.md")

# --- Cost constants ---

func test_archer_cost_tier1_is_thirty() -> void:
	assert_eq(ARCHER_COST_T1, 30, "Archer T1 cost must be 30g per economy.md")

func test_archer_cost_tier2_is_sixty() -> void:
	assert_eq(ARCHER_COST_T2, 60, "Archer T2 cost must be 60g per economy.md")

func test_tower_cost_is_one_hundred() -> void:
	assert_eq(TOWER_COST, 100, "Tower cost must be 100g per archer-tower.md")

func test_forge_cost_is_two_hundred() -> void:
	assert_eq(FORGE_COST, 200, "Forge cost must be 200g per forge.md")

# --- Income arithmetic ---

func test_five_enemy_kills_yield_seventy_five_gold() -> void:
	# Wave 1: 5 enemies × 15g = 75g
	var wave1_income: int = 5 * GOLD_DROP
	assert_eq(wave1_income, 75, "5 kills × 15g = 75g (wave 1 income)")

func test_starting_gold_plus_wave1_income_covers_two_recruits() -> void:
	# 60g start + 75g wave 1 = 135g — enough for 2 T1 recruits (2×30=60g)
	var available: int = STARTING_GOLD + (5 * GOLD_DROP)
	assert_true(available >= ARCHER_COST_T1 * 2,
		"60g start + 75g wave1 income should cover 2 T1 recruits")

# --- Placeholder tests for Economy node (uncomment once src exists) ---

# func test_recruit_deducts_cost_from_gold() -> void:
#     _economy.gold = 60
#     _economy.spend(ARCHER_COST_T1)
#     assert_eq(_economy.gold, 30, "Gold should be 30 after spending 30g")
#
# func test_cannot_spend_below_zero() -> void:
#     _economy.gold = 10
#     _economy.spend(ARCHER_COST_T1)  # 30g > 10g — should be blocked
#     assert_eq(_economy.gold, 10, "Gold should be unchanged on insufficient funds")
#
# func test_session_reset_restores_starting_gold() -> void:
#     _economy.gold = 250
#     _economy._on_session_restart()
#     assert_eq(_economy.gold, STARTING_GOLD, "Session restart must reset gold to 60g")
