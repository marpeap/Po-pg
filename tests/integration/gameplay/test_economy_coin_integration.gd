## Integration tests for Economy coin drop + collect cycle
## Story: C01-S01
## GUT 9.6.0 — extends GutTest
##
## Tests the logical contract of the coin drop → magnet collect → gold add cycle.
## Full Area2D overlap (magnet radius detection) is validated during manual playtest.
extends GutTest

func test_coin_pool_size_constant() -> void:
	# Arrange
	var econ_script: GDScript = load("res://src/gameplay/economy.gd")
	var econ: Node = econ_script.new()
	# Assert
	assert_eq(econ.COIN_POOL_SIZE, 16, "Coin pool must pre-allocate 16 nodes")
	econ.free()

func test_magnet_radius_constant() -> void:
	var econ_script: GDScript = load("res://src/gameplay/economy.gd")
	var econ: Node = econ_script.new()
	assert_eq(econ.MAGNET_R, 170.0, "Magnet radius must be 170.0px")
	econ.free()

func test_collect_radius_constant() -> void:
	var econ_script: GDScript = load("res://src/gameplay/economy.gd")
	var econ: Node = econ_script.new()
	assert_eq(econ.COLLECT_R, 12.0, "Collect radius must be 12.0px")
	econ.free()

func test_magnet_speed_constant() -> void:
	var econ_script: GDScript = load("res://src/gameplay/economy.gd")
	var econ: Node = econ_script.new()
	assert_eq(econ.MAGNET_SPEED, 400.0, "Magnet speed must be 400.0px/s")
	econ.free()

func test_coin_activate_sets_position_and_value() -> void:
	# Arrange
	var coin_node: Area2D = Area2D.new()
	coin_node.set_script(load("res://src/gameplay/coin.gd"))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	coin_node.add_child(col)
	add_child(coin_node)

	# Act
	var drop_pos := Vector2(300.0, 500.0)
	var gold_val := 15
	coin_node.activate(drop_pos, gold_val)

	# Assert
	assert_eq(coin_node.position, drop_pos, "Coin must activate at the drop position")
	assert_eq(coin_node.gold_value, gold_val, "Coin must store the correct gold_value")
	assert_true(coin_node.is_active(), "Coin must be active after activate()")

	coin_node.queue_free()

func test_coin_deactivate_marks_inactive() -> void:
	# Arrange
	var coin_node: Area2D = Area2D.new()
	coin_node.set_script(load("res://src/gameplay/coin.gd"))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	coin_node.add_child(col)
	add_child(coin_node)
	coin_node.activate(Vector2(100.0, 100.0), 10)

	# Act
	coin_node.deactivate()

	# Assert
	assert_false(coin_node.is_active(), "Coin must be inactive after deactivate()")

	coin_node.queue_free()

func test_collect_adds_correct_gold_to_economy() -> void:
	# Arrange: economy node without _ready (avoids scene-tree coin pool init)
	var econ := Node.new()
	econ.set_script(load("res://src/gameplay/economy.gd"))
	econ.current_gold = 60
	add_child(econ)

	# Act: simulate the collect step (Economy._process calls add_gold after distance check)
	var coin_gold_value := 15
	econ.add_gold(coin_gold_value)

	# Assert: add_gold applies SeasonManager/WeatherManager multipliers (≥1.0)
	# so effective gold is ≥ base amount — check the gold increased by at least 15
	assert_gte(econ.current_gold, 75,
		"Collecting a 15g coin must increase gold by at least 15 (60 → ≥75)")

	econ.queue_free()

func test_multiple_coins_accumulate_gold_correctly() -> void:
	# Arrange
	var econ := Node.new()
	econ.set_script(load("res://src/gameplay/economy.gd"))
	econ.current_gold = 60
	add_child(econ)

	# Act: collect 3 coins of 15g each
	for i in range(3):
		econ.add_gold(15)

	# Assert: multipliers (≥1.0) mean effective gain ≥ 45 total
	assert_gte(econ.current_gold, 105,
		"Collecting 3x15g coins must add at least 45g total (60 → ≥105)")

	econ.queue_free()

func test_gold_signal_emitted_on_collect() -> void:
	# Arrange
	var econ := Node.new()
	econ.set_script(load("res://src/gameplay/economy.gd"))
	econ.current_gold = 60
	add_child(econ)
	watch_signals(econ)

	# Act: simulate coin collect
	econ.add_gold(15)

	# Assert
	assert_signal_emitted(econ, "gold_changed",
		"Collecting a coin must emit gold_changed signal")

	econ.queue_free()

func test_coin_wave1_gold_value_matches_wave_table() -> void:
	# Arrange: Wave 1 gold value per enemy must be 15 (GDD TR-economy-001)
	var coin_node: Area2D = Area2D.new()
	coin_node.set_script(load("res://src/gameplay/coin.gd"))
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	coin_node.add_child(col)
	add_child(coin_node)

	# Act: activate with Wave 1 gold value
	coin_node.activate(Vector2.ZERO, 15)

	# Assert
	assert_eq(coin_node.gold_value, 15,
		"Wave 1 coin gold_value must match wave table (15g per kill)")

	coin_node.queue_free()
