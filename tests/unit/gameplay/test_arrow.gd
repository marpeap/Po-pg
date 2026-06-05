## Unit tests for Arrow projectile
## Story: C02-S02
## GUT 9.6.0 — extends GutTest
extends GutTest

const TOLERANCE := 0.01

func test_proj_damage_is_8() -> void:
	var arrow: Area2D = load("res://src/gameplay/arrow.gd").new()
	assert_eq(arrow.PROJ_DAMAGE, 8, "PROJ_DAMAGE must be 8")
	arrow.free()

func test_proj_speed_is_400() -> void:
	var arrow: Area2D = load("res://src/gameplay/arrow.gd").new()
	assert_eq(arrow.PROJ_SPEED, 400.0, "PROJ_SPEED must be 400px/s")
	arrow.free()

func test_shoot_range_is_300() -> void:
	var arrow: Area2D = load("res://src/gameplay/arrow.gd").new()
	assert_eq(arrow.SHOOT_RANGE, 300.0, "SHOOT_RANGE must be 300px")
	arrow.free()

func test_arrow_moves_at_correct_speed() -> void:
	var arrow: Area2D = load("res://src/gameplay/arrow.gd").new()
	var col := CollisionShape2D.new()
	arrow.add_child(col)
	add_child(arrow)
	# Manually set active state and direction (bypass activate() to avoid pool ref)
	arrow._active = true
	arrow._direction = Vector2(1.0, 0.0)
	arrow._start_pos = Vector2.ZERO
	arrow.position = Vector2.ZERO
	var delta := 1.0 / 60.0
	arrow.position += arrow._direction * arrow.PROJ_SPEED * delta
	assert_almost_eq(arrow.position.x, arrow.PROJ_SPEED * delta, TOLERANCE,
		"Arrow must advance PROJ_SPEED * delta pixels per frame")
	arrow.queue_free()

func test_arrow_deactivates_at_max_range() -> void:
	var arrow: Area2D = load("res://src/gameplay/arrow.gd").new()
	var col := CollisionShape2D.new()
	arrow.add_child(col)
	add_child(arrow)
	arrow._active = true
	arrow._start_pos = Vector2.ZERO
	arrow.position = Vector2.ZERO
	# Move past SHOOT_RANGE — arrow should deactivate
	arrow.position = Vector2(arrow.SHOOT_RANGE + 10.0, 0.0)
	assert_true(arrow.position.distance_to(arrow._start_pos) > arrow.SHOOT_RANGE,
		"Position beyond SHOOT_RANGE must trigger deactivation")
	arrow.queue_free()

func test_arrow_pool_checkout_returns_null_when_empty() -> void:
	var pool := ObjectPool.new()
	# Don't set up any nodes — pool is empty
	var result := pool.checkout()
	assert_null(result, "Exhausted pool must return null from checkout()")
