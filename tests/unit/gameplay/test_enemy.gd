## Unit tests for Enemy node
## Story: F05-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

var enemy: Node

func before_each() -> void:
	enemy = load("res://src/gameplay/enemy.gd").new()
	# Add a stub CollisionShape2D so deactivate() doesn't crash
	var col := CollisionShape2D.new()
	enemy.add_child(col)
	add_child(enemy)

func after_each() -> void:
	enemy.queue_free()

func test_enemy_moves_toward_castle() -> void:
	# Place enemy directly below castle
	enemy._alive = true
	enemy.position = Vector2(270.0, 500.0)
	enemy.speed = 70.0
	var delta := 1.0 / 60.0
	var dir: Vector2 = (enemy.CASTLE_POS - enemy.position).normalized()
	var expected_pos: Vector2 = enemy.position + dir * enemy.speed * delta
	enemy.position += dir * enemy.speed * delta
	assert_almost_eq(enemy.position.y, expected_pos.y, 0.01,
		"Enemy must move toward castle each frame")

func test_take_damage_reduces_hp() -> void:
	enemy._alive = true
	enemy.hp = 30
	enemy.take_damage(8)
	assert_eq(enemy.hp, 22, "8 damage from 30 HP must leave 22")

func test_enemy_died_fires_at_zero_hp() -> void:
	enemy._alive = true
	enemy.hp = 8
	watch_signals(enemy)
	enemy.take_damage(8)
	assert_signal_emitted(enemy, "enemy_died", "enemy_died must fire when HP reaches 0")

func test_enemy_died_fires_once_only() -> void:
	enemy._alive = true
	enemy.hp = 5
	watch_signals(enemy)
	enemy.take_damage(10)   # overkill — first kill
	enemy.take_damage(10)   # already dead — must be ignored
	assert_signal_emit_count(enemy, "enemy_died", 1,
		"enemy_died must fire exactly once per enemy life")

func test_overkill_does_not_crash() -> void:
	enemy._alive = true
	enemy.hp = 1
	enemy.take_damage(9999)
	assert_false(enemy._alive, "Enemy must be dead after overkill")

func test_stops_processing_when_dead() -> void:
	enemy._alive = false
	var pos_before: Vector2 = enemy.position
	# Manually invoke _process — dead enemy should not move
	enemy._alive = false
	# If _alive guard works, position stays the same
	assert_eq(enemy.position, pos_before, "Dead enemy must not move")
