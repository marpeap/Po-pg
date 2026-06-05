## Unit tests for RPGEnemy — zone-based exploration enemy
## GUT 9.6.0 — extends GutTest
##
## Note: setup() requires a hero Node2D and calls randf_range — both are fine in tests.
## State-machine _process() checks current_state == EXPLORING; tests do not tick _process.
extends GutTest

func _make_enemy() -> Area2D:
	var e: Area2D = Area2D.new()
	e.set_script(load("res://src/gameplay/rpg_enemy.gd"))
	add_child(e)
	return e

func _make_hero_stub() -> Node2D:
	var h: Node2D = Node2D.new()
	add_child(h)
	return h

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_max_hp_is_25() -> void:
	var e: Area2D = _make_enemy()
	assert_eq(e.MAX_HP, 25)
	e.queue_free()

func test_attack_damage_is_6() -> void:
	var e: Area2D = _make_enemy()
	assert_eq(e.ATTACK_DAMAGE, 6)
	e.queue_free()

func test_aggro_radius_is_200() -> void:
	var e: Area2D = _make_enemy()
	assert_almost_eq(e.AGGRO_RADIUS, 200.0, 0.001)
	e.queue_free()

func test_attack_range_is_48() -> void:
	var e: Area2D = _make_enemy()
	assert_almost_eq(e.ATTACK_RANGE, 48.0, 0.001)
	e.queue_free()

func test_attack_cooldown_is_1pt8() -> void:
	var e: Area2D = _make_enemy()
	assert_almost_eq(e.ATTACK_COOLDOWN, 1.8, 0.001)
	e.queue_free()

# ---------------------------------------------------------------------------
# HP and take_damage
# ---------------------------------------------------------------------------

func test_starts_alive_with_full_hp() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	assert_eq(e.hp, e.MAX_HP)
	assert_true(e._alive)
	e.queue_free()
	hero.queue_free()

func test_take_damage_reduces_hp() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	e.take_damage(10)
	assert_eq(e.hp, e.MAX_HP - 10)
	e.queue_free()
	hero.queue_free()

func test_take_damage_to_zero_kills_enemy() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	e.take_damage(e.MAX_HP)
	assert_false(e._alive, "Enemy must be dead after lethal damage")
	assert_false(e.visible, "Dead enemy must be invisible")
	e.queue_free()
	hero.queue_free()

func test_died_signal_emitted_on_lethal_damage() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	watch_signals(e)
	e.take_damage(e.MAX_HP)
	assert_signal_emitted(e, "died")
	e.queue_free()
	hero.queue_free()

func test_take_damage_no_ops_when_dead() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	e.take_damage(e.MAX_HP)   ## Kill
	watch_signals(e)
	e.take_damage(99)          ## Should no-op
	assert_signal_not_emitted(e, "died", "died must not emit twice")
	e.queue_free()
	hero.queue_free()

# ---------------------------------------------------------------------------
# Group membership
# ---------------------------------------------------------------------------

func test_enemy_in_enemies_group_after_setup() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	assert_true(e.is_in_group("enemies"),
		"RPGEnemy must be in group 'enemies' so hero spells can hit it")
	e.queue_free()
	hero.queue_free()

# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_starts_in_patrol_state() -> void:
	var e: Area2D = _make_enemy()
	var hero: Node2D = _make_hero_stub()
	e.setup(Vector2(500.0, 300.0), hero)
	assert_eq(e._state, e.EState.PATROL)
	e.queue_free()
	hero.queue_free()
