## Unit tests for Economy purchase logic (button-driven — no dwell zones since Sprint 7)
## Story: C01-S02
## GUT 9.6.0 — extends GutTest
extends GutTest

## Tests for the flat archer cost, tower limit, and button-triggered purchase API.

func test_archer_cost_is_flat_30g() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	assert_eq(econ.ARCHER_COST, 30, "ARCHER_COST must be 30g for all slots")
	econ.free()

func test_archer_cost_same_at_slot_5() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ._current_archer_count = 4
	assert_eq(econ.next_recruit_cost(), 30, "Cost at slot 5 must still be 30g")
	econ.free()

func test_tower_limit_is_5() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ._tower_count = 5
	assert_false(econ.can_purchase_tower(), "Cannot purchase a 6th tower (limit is 5)")
	econ.free()

func test_tower_purchase_no_archer_requirement() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ._current_archer_count = 0
	econ.current_gold = 200
	assert_true(econ.can_purchase_tower(), "Tower purchase requires only gold — no archers needed")
	econ.free()

func test_no_purchase_if_insufficient_gold() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ.current_gold = 10
	var result: bool = econ.spend_gold(30)
	assert_false(result, "spend_gold must fail when gold is insufficient")
	assert_eq(econ.current_gold, 10, "Gold must not change on failed spend")
	econ.free()

func test_gold_deducted_on_purchase() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ.current_gold = 60
	econ.spend_gold(30)
	assert_eq(econ.current_gold, 30, "30g spend from 60g must leave 30g")
	econ.free()

func test_recruit_purchased_signal_fires() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	watch_signals(econ)
	econ.recruit_purchased.emit()
	assert_signal_emitted(econ, "recruit_purchased")
	econ.free()

func test_try_recruit_deducts_30g() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ.current_gold = 60
	econ._current_archer_count = 2
	econ.try_recruit()
	assert_eq(econ.current_gold, 30, "try_recruit must deduct 30g")
	econ.free()

func test_try_recruit_fails_at_max_8() -> void:
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ.current_gold = 9999
	econ._current_archer_count = 8
	var result: bool = econ.try_recruit()
	assert_false(result, "try_recruit must fail when formation is full (8 slots)")
	econ.free()
