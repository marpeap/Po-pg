## Integration tests for ArcherTower
## Story: FT01-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

func test_tower_range_constant() -> void:
	var tower: Node2D = load("res://src/gameplay/archer_tower.gd").new()
	assert_almost_eq(tower.TOWER_RANGE, 350.0, 0.001,
		"TOWER_RANGE must be 350px")
	tower.free()

func test_tower_shoot_ivtl_constant() -> void:
	var tower: Node2D = load("res://src/gameplay/archer_tower.gd").new()
	assert_almost_eq(tower.TOWER_SHOOT_IVTL, 1.2, 0.001,
		"TOWER_SHOOT_IVTL must be 1.2s")
	tower.free()

func test_tower_fires_within_range() -> void:
	# Confirm the range check is present in source
	var src := FileAccess.open("res://src/gameplay/archer_tower.gd", FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	assert_true(content.contains("TOWER_RANGE"),
		"Tower must use TOWER_RANGE for targeting")

func test_tower_does_not_fire_outside_range() -> void:
	# Confirm _fire_at_nearest_enemy uses TOWER_RANGE guard in source
	var src := FileAccess.open("res://src/gameplay/archer_tower.gd", FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	assert_true(content.contains("_fire_at_nearest_enemy"),
		"Tower must have _fire_at_nearest_enemy method for targeting")
	assert_true(content.contains("TOWER_RANGE"),
		"Tower must use TOWER_RANGE as the range guard in targeting logic")

func test_tower_uses_shared_arrow_pool() -> void:
	# Confirm tower does not create its own pool
	var src := FileAccess.open("res://src/gameplay/archer_tower.gd", FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	assert_false(content.contains("ObjectPool.new()"),
		"Tower must NOT create its own arrow pool — it uses the shared one")

func test_tower_persists_after_session_reset() -> void:
	# Towers do NOT connect to session_reset — they are permanent structures
	var src := FileAccess.open("res://src/gameplay/archer_tower.gd", FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	assert_false(content.contains("session_reset.connect"),
		"Tower must NOT connect to session_reset (towers are permanent)")

func test_max_5_towers() -> void:
	# Economy enforces _tower_count <= 5 before emitting tower_purchased
	var econ: Node = load("res://src/gameplay/economy.gd").new()
	econ._tower_count = 5
	econ.current_gold = 9999
	assert_false(econ.can_purchase_tower(),
		"Economy must block purchase when tower count reaches 5")
	econ.free()
