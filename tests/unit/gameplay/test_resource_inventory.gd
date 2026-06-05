## Unit tests for ResourceInventory autoload
## GUT 9.6.0 — extends GutTest
extends GutTest

## Use the real autoload (already in scene tree as singleton).
## Each test resets counts manually to ensure isolation.

func before_each() -> void:
	## Reset all counts to 0 before each test
	for i: int in range(3):
		while ResourceInventory.get_count(i) > 0:
			ResourceInventory.spend(i, ResourceInventory.get_count(i))

# ---------------------------------------------------------------------------
# Type enum values
# ---------------------------------------------------------------------------

func test_type_wood_is_0() -> void:
	assert_eq(ResourceInventory.Type.WOOD,  0, "WOOD must be index 0")

func test_type_stone_is_1() -> void:
	assert_eq(ResourceInventory.Type.STONE, 1, "STONE must be index 1")

func test_type_herb_is_2() -> void:
	assert_eq(ResourceInventory.Type.HERB,  2, "HERB must be index 2")

# ---------------------------------------------------------------------------
# add / get_count
# ---------------------------------------------------------------------------

func test_starts_at_zero() -> void:
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.WOOD),  0)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.STONE), 0)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.HERB),  0)

func test_add_increases_count() -> void:
	ResourceInventory.add(ResourceInventory.Type.WOOD, 3)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.WOOD), 3)

func test_add_accumulates() -> void:
	ResourceInventory.add(ResourceInventory.Type.HERB, 4)
	ResourceInventory.add(ResourceInventory.Type.HERB, 4)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.HERB), 8)

# ---------------------------------------------------------------------------
# spend / has_enough
# ---------------------------------------------------------------------------

func test_spend_reduces_count() -> void:
	ResourceInventory.add(ResourceInventory.Type.STONE, 6)
	ResourceInventory.spend(ResourceInventory.Type.STONE, 3)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.STONE), 3)

func test_spend_returns_true_when_sufficient() -> void:
	ResourceInventory.add(ResourceInventory.Type.WOOD, 5)
	assert_true(ResourceInventory.spend(ResourceInventory.Type.WOOD, 5))

func test_spend_returns_false_when_insufficient() -> void:
	assert_false(ResourceInventory.spend(ResourceInventory.Type.STONE, 99),
		"spend must fail when count < amount")

func test_spend_does_not_change_count_on_failure() -> void:
	ResourceInventory.add(ResourceInventory.Type.HERB, 1)
	ResourceInventory.spend(ResourceInventory.Type.HERB, 10)   ## Should fail
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.HERB), 1,
		"count must be unchanged after a failed spend")

func test_has_enough_true_when_exactly_sufficient() -> void:
	ResourceInventory.add(ResourceInventory.Type.WOOD, 5)
	assert_true(ResourceInventory.has_enough(ResourceInventory.Type.WOOD, 5))

func test_has_enough_false_when_below() -> void:
	assert_false(ResourceInventory.has_enough(ResourceInventory.Type.STONE, 1))

# ---------------------------------------------------------------------------
# resource_changed signal
# ---------------------------------------------------------------------------

func test_resource_changed_emits_on_add() -> void:
	watch_signals(ResourceInventory)
	ResourceInventory.add(ResourceInventory.Type.WOOD, 2)
	assert_signal_emitted(ResourceInventory, "resource_changed")

func test_resource_changed_emits_on_spend() -> void:
	ResourceInventory.add(ResourceInventory.Type.HERB, 4)
	watch_signals(ResourceInventory)
	ResourceInventory.spend(ResourceInventory.Type.HERB, 2)
	assert_signal_emitted(ResourceInventory, "resource_changed")

# ---------------------------------------------------------------------------
# Session reset
# ---------------------------------------------------------------------------

func test_session_reset_clears_all_counts() -> void:
	ResourceInventory.add(ResourceInventory.Type.WOOD,  5)
	ResourceInventory.add(ResourceInventory.Type.STONE, 3)
	ResourceInventory.add(ResourceInventory.Type.HERB,  7)
	ResourceInventory._on_session_reset()
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.WOOD),  0)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.STONE), 0)
	assert_eq(ResourceInventory.get_count(ResourceInventory.Type.HERB),  0)
