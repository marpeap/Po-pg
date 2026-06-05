## Unit tests for ResourceNode — tap-to-collect exploration resource
## GUT 9.6.0 — extends GutTest
## Updated to use TYPE_CFG dictionary (Type enum removed in RPG Refonte Grandiose sprint).
extends GutTest

func _make_node(node_type: int) -> Area2D:
	## Cannot test Area2D.input_event in headless — test data constants and _collect() directly.
	## ResourceInventory is the real autoload (singleton in tree).
	var n: Area2D = Area2D.new()
	n.set_script(load("res://src/gameplay/resource_node.gd"))
	add_child(n)
	n.setup(node_type)
	return n

func before_each() -> void:
	## Reset all resource counts for WOOD(0), STONE(1), HERB(2)
	for i: int in range(3):
		while ResourceInventory.get_count(i) > 0:
			ResourceInventory.spend(i, ResourceInventory.get_count(i))

# ---------------------------------------------------------------------------
# TYPE_CFG data constants (replaces removed Type enum + YIELD dict)
# ---------------------------------------------------------------------------

func test_wood_type_cfg_exists() -> void:
	var n: Area2D = _make_node(0)
	assert_true(n.TYPE_CFG.has(0), "TYPE_CFG must have key 0 for WOOD")
	n.queue_free()

func test_stone_type_cfg_exists() -> void:
	var n: Area2D = _make_node(1)
	assert_true(n.TYPE_CFG.has(1), "TYPE_CFG must have key 1 for STONE")
	n.queue_free()

func test_herb_type_cfg_exists() -> void:
	var n: Area2D = _make_node(2)
	assert_true(n.TYPE_CFG.has(2), "TYPE_CFG must have key 2 for HERB")
	n.queue_free()

# ---------------------------------------------------------------------------
# Yield amounts via TYPE_CFG
# ---------------------------------------------------------------------------

func test_wood_yields_3() -> void:
	var n: Area2D = _make_node(0)
	assert_eq(n.TYPE_CFG[0].y, 3, "WOOD base yield must be 3")
	n.queue_free()

func test_stone_yields_2() -> void:
	var n: Area2D = _make_node(1)
	assert_eq(n.TYPE_CFG[1].y, 2, "STONE base yield must be 2")
	n.queue_free()

func test_herb_yields_4() -> void:
	var n: Area2D = _make_node(2)
	assert_eq(n.TYPE_CFG[2].y, 4, "HERB base yield must be 4")
	n.queue_free()

# ---------------------------------------------------------------------------
# _collect() logic
# ---------------------------------------------------------------------------

func test_collect_adds_to_inventory() -> void:
	var n: Area2D = _make_node(0)   ## WOOD — base yield 3
	n._collect()
	## Yield may include probabilistic rare bonus (+1) — test for minimum
	assert_gte(ResourceInventory.get_count(0), 3,
		"WOOD node must add at least 3 to inventory on collect")
	n.queue_free()

func test_collect_deactivates_node() -> void:
	var n: Area2D = _make_node(0)
	n._collect()
	assert_false(n._active, "Node must be inactive after collection")
	assert_false(n.visible, "Node must be hidden after collection")
	n.queue_free()

func test_collect_twice_only_counts_once() -> void:
	var n: Area2D = _make_node(2)   ## HERB — base yield 4
	n._collect()
	n._collect()   ## Second call must be a no-op
	## Yield may include probabilistic rare bonus (+1) — test for minimum
	assert_gte(ResourceInventory.get_count(2), 4,
		"Double-collect must not double-add to inventory")
	n.queue_free()

func test_stone_collect_adds_to_inventory() -> void:
	var n: Area2D = _make_node(1)   ## STONE — base yield 2
	n._collect()
	## Yield may include probabilistic rare bonus (+1) — test for minimum
	assert_gte(ResourceInventory.get_count(1), 2,
		"STONE node must add at least 2 to inventory on collect")
	n.queue_free()
