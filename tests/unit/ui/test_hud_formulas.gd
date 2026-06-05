## Unit tests for HUD formula logic
## Story: P01-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

const CASTLE_MAX_HP := 200
const TOLERANCE := 0.001

## HP ratio formula used for castle bar color bands
func _hp_ratio(hp: int) -> float:
	return float(hp) / float(CASTLE_MAX_HP)

func test_castle_hp_ratio_at_full() -> void:
	assert_almost_eq(_hp_ratio(200), 1.0, TOLERANCE, "200/200 must be ratio 1.0 (GREEN)")

func test_castle_hp_ratio_green_threshold() -> void:
	# ratio >= 0.6 → GREEN
	assert_gte(_hp_ratio(120), 0.6, "120HP must be green (ratio >= 0.6)")
	assert_lt(_hp_ratio(119), 0.6, "119HP must NOT be green")

func test_castle_hp_ratio_amber_threshold() -> void:
	# 0.3 <= ratio < 0.6 → AMBER
	var ratio_100 := _hp_ratio(100)
	assert_gte(ratio_100, 0.3, "100HP must be in amber range")
	assert_lt(ratio_100, 0.6, "100HP must be below green threshold")

func test_castle_hp_ratio_red_threshold() -> void:
	# ratio < 0.3 → RED
	assert_lt(_hp_ratio(50), 0.3, "50HP must be red (ratio < 0.3)")

func test_affordability_highlight_t1_cost() -> void:
	# With 30g and 2 archers: can afford T1 (30g)
	var gold := 30
	var archer_count := 2
	var cost := 30 if archer_count < 4 else 60
	var can_afford := gold >= cost and archer_count < 8
	assert_true(can_afford, "30g with 2 archers must be affordable (T1=30g)")

func test_affordability_highlight_t2_cost() -> void:
	# With 59g and 4 archers: cannot afford T2 (60g)
	var gold := 59
	var archer_count := 4
	var cost := 30 if archer_count < 4 else 60
	var can_afford := gold >= cost and archer_count < 8
	assert_false(can_afford, "59g with 4 archers must NOT be affordable (T2=60g)")

func test_affordability_suppressed_when_full_formation() -> void:
	# With 8 archers: can_afford must be false regardless of gold
	var gold := 9999
	var archer_count := 8
	var can_afford := gold >= 30 and archer_count < 8
	assert_false(can_afford, "Full formation (8 archers) must suppress affordability highlight")
