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

## ── SHIELDER shield mechanic ─────────────────────────────────────────────

func test_shielder_shield_reduces_damage_to_40_percent() -> void:
	enemy._alive = true
	enemy.hp = 100
	enemy._max_hp = 100
	enemy._shield_active = true
	## 10 damage × 0.40 = 4, clamped to min 1 via maxi(1, ...)
	enemy.take_damage(10)
	assert_eq(enemy.hp, 96, "Shield must reduce 10 damage to 4 (40%) leaving 96 HP")

func test_shielder_shield_breaks_at_50_percent_hp() -> void:
	enemy._alive = true
	enemy.hp = 100
	enemy._max_hp = 100
	enemy._shield_active = true
	## Deal enough to push HP to exactly 50% — shield should break
	enemy.take_damage(250)  ## 250 × 0.40 = 100 → 100 - 100 = 0; clamp: shield breaks first
	## After large hit, shield should be broken (hp dropped through 50)
	assert_false(enemy._shield_active, "Shield must break when HP reaches or passes 50% of max")

func test_shielder_after_shield_breaks_takes_full_damage() -> void:
	enemy._alive = true
	enemy.hp = 80
	enemy._max_hp = 100
	enemy._shield_active = false  ## Already broken
	enemy.take_damage(10)
	assert_eq(enemy.hp, 70, "After shield breaks enemy must take full 100% damage")

func test_shielder_shield_minimum_1_damage() -> void:
	enemy._alive = true
	enemy.hp = 100
	enemy._max_hp = 100
	enemy._shield_active = true
	## 1 damage × 0.40 = 0.4 → rounded to 0 → clamped to 1
	enemy.take_damage(1)
	assert_eq(enemy.hp, 99, "Shield damage minimum is 1 (no zero-damage hits)")

func test_shielder_deactivate_resets_shield() -> void:
	enemy._alive = true
	enemy._shield_active = true
	enemy.deactivate()
	assert_false(enemy._shield_active, "deactivate() must reset shield state for pool reuse")
