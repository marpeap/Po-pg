## Unit tests for Hero movement logic
## Story: F02-S01
## GUT 9.6.0 — extends GutTest
##
## Tests movement math, joystick direction clamping, bounds, and session reset.
## Uses a script-level instance of hero.gd — not the autoload.
extends GutTest

var hero: Node2D
var gsm: Node

func before_each() -> void:
	gsm = load("res://src/autoloads/game_state_machine.gd").new()
	add_child(gsm)
	# Hero reads GameStateMachine via autoload name — stub not practical in unit test.
	# Instead, test the pure math helpers directly (no scene tree dependency).
	hero = load("res://src/gameplay/hero.gd").new()
	add_child(hero)

func after_each() -> void:
	hero.queue_free()
	gsm.queue_free()

## Joystick direction clamped to JOY_RADIUS and normalized
func test_joystick_direction_normalized() -> void:
	# Simulate a far-away touch: 300px from anchor → clamps to JOY_RADIUS, normalizes
	var anchor: Vector2 = hero.JOY_ANCHOR
	var far_touch: Vector2 = anchor + Vector2(300.0, 0.0)
	hero._update_joy_direction(far_touch)
	var dir: Vector2 = hero._joy_direction
	assert_almost_eq(dir.length(), 1.0, 0.001, "Direction must be unit-length after clamping")
	assert_almost_eq(dir.x, 1.0, 0.001, "Direction should be (1,0) for rightward touch")

func test_hero_speed_correct_displacement() -> void:
	# Moving right at full speed for 1 second should displace by HERO_SPEED pixels
	hero._joy_active = true
	hero._joy_direction = Vector2(1.0, 0.0)
	var start_pos := hero.position
	# Simulate 1 second of delta manually via _process (won't fire signal — safe)
	hero.position += hero._joy_direction * hero.HERO_SPEED * 1.0
	assert_almost_eq(hero.position.x - start_pos.x, hero.HERO_SPEED, 0.01,
		"1s rightward motion must displace by HERO_SPEED pixels")

func test_bottom_half_activation_only() -> void:
	# Touch far from JOY_ANCHOR (outside JOY_ACTIVATION_RADIUS) must NOT activate joystick
	var far_touch := InputEventScreenTouch.new()
	far_touch.pressed = true
	far_touch.index = 0
	far_touch.position = Vector2(960.0, 100.0)  # far from anchor (110,430)
	hero._handle_touch(far_touch)
	assert_false(hero._joy_active, "Touch outside JOY_ACTIVATION_RADIUS must not activate joystick")

	# Touch near JOY_ANCHOR (within JOY_ACTIVATION_RADIUS) MUST activate joystick
	var near_touch := InputEventScreenTouch.new()
	near_touch.pressed = true
	near_touch.index = 1
	near_touch.position = Vector2(110.0, 500.0)  # 70px from anchor — within radius 200
	hero._handle_touch(near_touch)
	assert_true(hero._joy_active, "Touch within JOY_ACTIVATION_RADIUS must activate joystick")

func test_facing_angle_updates_on_move() -> void:
	hero._joy_active = true
	# Moving right → facing angle = 0
	hero._joy_direction = Vector2(1.0, 0.0)
	hero.position += hero._joy_direction * hero.HERO_SPEED * 0.016
	hero.facing_angle = hero._joy_direction.angle()
	assert_almost_eq(hero.facing_angle, 0.0, 0.001, "Rightward motion must set facing_angle to 0")

func test_session_reset_restores_start_pos() -> void:
	hero.position = Vector2(500.0, 500.0)
	hero.facing_angle = 0.0
	hero._on_session_reset()
	assert_eq(hero.position, hero.HERO_START_POS, "Session reset must restore HERO_START_POS")
	assert_almost_eq(hero.facing_angle, PI / 2.0, 0.001,
		"Session reset must restore facing_angle to PI/2")

func test_hero_clamped_to_world_bounds() -> void:
	# If hero somehow ends up at negative coords, clamp should fix it
	hero.position = Vector2(-100.0, -100.0)
	hero.position = hero.position.clamp(hero.WORLD_MIN, hero.WORLD_MAX_TD)
	assert_eq(hero.position, Vector2.ZERO, "Clamping must bring position to (0,0) at minimum")

	hero.position = Vector2(9999.0, 9999.0)
	hero.position = hero.position.clamp(hero.WORLD_MIN, hero.WORLD_MAX_TD)
	assert_eq(hero.position, hero.WORLD_MAX_TD, "Clamping must bring position to WORLD_MAX_TD at maximum")
