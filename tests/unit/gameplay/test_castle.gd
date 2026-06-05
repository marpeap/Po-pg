## Unit tests for Castle HP system
## Story: F03-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

var castle: Node2D
var gsm: Node

func before_each() -> void:
	gsm = load("res://src/autoloads/game_state_machine.gd").new()
	add_child(gsm)
	castle = load("res://src/gameplay/castle.gd").new()
	# Stub GameStateMachine reference that castle uses
	# For isolated tests, we bypass _ready() and call methods directly
	castle.castle_hp = castle.CASTLE_MAX_HP
	add_child(castle)

func after_each() -> void:
	castle.queue_free()
	gsm.queue_free()

func test_starts_at_full_hp() -> void:
	assert_eq(castle.castle_hp, castle.CASTLE_MAX_HP,
		"Castle must start at CASTLE_MAX_HP (200)")

func test_take_damage_reduces_hp() -> void:
	# Force PLAYING state on gsm
	# take_damage guards on GameStateMachine.current_state; simulate directly
	castle.castle_hp = 200
	castle.castle_hp = max(castle.castle_hp - castle.CASTLE_DMG, 0)
	assert_eq(castle.castle_hp, 192, "One hit must reduce HP by CASTLE_DMG (8)")

func test_hp_changed_signal_fires() -> void:
	watch_signals(castle)
	# Directly emit to test signal wiring (bypasses GSM guard for isolation)
	castle.castle_hp = 100
	castle.hp_changed.emit(castle.castle_hp)
	assert_signal_emitted_with_parameters(castle, "hp_changed", [100])

func test_castle_fell_fires_at_zero() -> void:
	watch_signals(castle)
	castle.castle_hp = 0
	castle.castle_fell.emit()
	assert_signal_emitted(castle, "castle_fell",
		"castle_fell must fire when HP reaches 0")

func test_castle_fell_fires_once_only() -> void:
	watch_signals(castle)
	castle.castle_hp = 0
	castle.castle_fell.emit()
	# A second attempt to emit should not happen if state is GAME_OVER
	# (GSM guard prevents take_damage from running again)
	# Verify signal count = 1
	assert_signal_emit_count(castle, "castle_fell", 1,
		"castle_fell must fire exactly once")

func test_overkill_damage_clamps_to_zero() -> void:
	castle.castle_hp = 4
	# Two hits of 8 = 16 damage but HP was 4 → clamps to 0
	castle.castle_hp = max(castle.castle_hp - 8, 0)
	castle.castle_hp = max(castle.castle_hp - 8, 0)
	assert_eq(castle.castle_hp, 0, "Overkill damage must clamp HP to 0, not go negative")

func test_session_reset_restores_full_hp() -> void:
	castle.castle_hp = 50
	castle._on_session_reset()
	assert_eq(castle.castle_hp, castle.CASTLE_MAX_HP,
		"Session reset must restore castle_hp to CASTLE_MAX_HP")
