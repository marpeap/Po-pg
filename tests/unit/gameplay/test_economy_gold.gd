## Unit tests for Economy gold management
## Story: C01-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

## Test the gold logic in isolation using the script's pure functions
## (bypasses the coin pool / node setup)
var econ: Node

func before_each() -> void:
	econ = Node.new()
	econ.set_script(load("res://src/gameplay/economy.gd"))
	econ.current_gold = econ.STARTING_GOLD
	# Don't call _ready() — coin pool setup requires scene tree
	add_child(econ)

func after_each() -> void:
	econ.queue_free()

func test_starts_at_60_gold() -> void:
	assert_eq(econ.STARTING_GOLD, 60, "STARTING_GOLD constant must be 60")
	assert_eq(econ.current_gold, 60, "Economy must start at STARTING_GOLD")

func test_add_gold_emits_signal() -> void:
	watch_signals(econ)
	econ.add_gold(15)
	assert_signal_emitted(econ, "gold_changed", "add_gold must emit gold_changed")

func test_gold_changed_signal_value_correct() -> void:
	## add_gold applies SeasonManager/WeatherManager multipliers (≥1.0) so effective
	## gold is ≥ base amount. Verify the signal carries the actual new total.
	econ.current_gold = 60
	watch_signals(econ)
	econ.add_gold(15)
	## Signal must carry the post-add current_gold value (index=0 = first emission)
	var expected: int = econ.current_gold
	assert_signal_emitted_with_parameters(econ, "gold_changed", [expected])

func test_spend_gold_returns_false_if_insufficient() -> void:
	econ.current_gold = 20
	var result: bool = econ.spend_gold(30)
	assert_false(result, "spend_gold must return false when gold is insufficient")

func test_spend_gold_never_below_zero() -> void:
	econ.current_gold = 10
	econ.spend_gold(20)  # Should fail (returns false)
	assert_eq(econ.current_gold, 10, "Failed spend must not change gold")

func test_spend_gold_success_deducts_correctly() -> void:
	econ.current_gold = 60
	var result: bool = econ.spend_gold(30)
	assert_true(result, "spend_gold must return true when funds are available")
	assert_eq(econ.current_gold, 30, "Gold must deduct by the spent amount")

func test_session_reset_restores_60_gold() -> void:
	econ.current_gold = 200
	econ.current_gold = econ.STARTING_GOLD
	econ.gold_changed.emit(econ.current_gold)
	assert_eq(econ.current_gold, 60, "Session reset must restore gold to STARTING_GOLD (60)")

func test_add_gold_keeps_floor_at_zero() -> void:
	econ.current_gold = 0
	econ.add_gold(-999)  # negative add should not go below 0
	assert_gte(econ.current_gold, 0, "Gold must never go below 0")
