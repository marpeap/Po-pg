## Unit tests for GameStateMachine autoload
## Story: F01-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

var gsm: Node

func before_each() -> void:
	# Instantiate a fresh copy of the script (not the autoload) for isolation
	gsm = load("res://src/autoloads/game_state_machine.gd").new()
	add_child(gsm)

func after_each() -> void:
	gsm.queue_free()

func test_starts_in_playing_state() -> void:
	assert_eq(gsm.current_state, gsm.State.PLAYING, "Initial state must be PLAYING")

func test_playing_to_game_over_valid() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	assert_eq(gsm.current_state, gsm.State.GAME_OVER, "PLAYING → GAME_OVER must succeed")

func test_game_over_signal_fired_on_transition() -> void:
	watch_signals(gsm)
	gsm.transition_to(gsm.State.GAME_OVER)
	assert_signal_emitted_with_parameters(gsm, "game_state_changed", [gsm.State.GAME_OVER])

func test_game_over_to_resetting_triggers_session_reset() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	watch_signals(gsm)
	gsm.transition_to(gsm.State.RESETTING)
	assert_signal_emitted(gsm, "session_reset", "session_reset must emit when entering RESETTING")

func test_resetting_auto_transitions_to_playing() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	gsm.transition_to(gsm.State.RESETTING)
	assert_eq(gsm.current_state, gsm.State.PLAYING, "After RESETTING, state must auto-return to PLAYING")

func test_invalid_transition_playing_to_resetting_rejected() -> void:
	# PLAYING → RESETTING is not a valid transition
	gsm.transition_to(gsm.State.RESETTING)
	assert_eq(gsm.current_state, gsm.State.PLAYING, "PLAYING → RESETTING must be silently rejected")

func test_duplicate_transition_rejected() -> void:
	# PLAYING → PLAYING is a no-op
	watch_signals(gsm)
	gsm.transition_to(gsm.State.PLAYING)
	assert_signal_not_emitted(gsm, "game_state_changed", "Duplicate transition must not emit signal")
	assert_eq(gsm.current_state, gsm.State.PLAYING)

func test_request_game_over_from_playing() -> void:
	gsm.request_game_over()
	assert_eq(gsm.current_state, gsm.State.GAME_OVER)

func test_request_game_over_from_game_over_ignored() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	watch_signals(gsm)
	gsm.request_game_over()
	assert_signal_not_emitted(gsm, "game_state_changed")

func test_request_restart_from_game_over() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	gsm.request_restart()
	assert_eq(gsm.current_state, gsm.State.PLAYING, "request_restart must cycle through RESETTING back to PLAYING")

# ---------------------------------------------------------------------------
# EXPLORING state (Phase 2)
# ---------------------------------------------------------------------------

func test_playing_to_exploring_valid() -> void:
	gsm.transition_to(gsm.State.EXPLORING)
	assert_eq(gsm.current_state, gsm.State.EXPLORING, "PLAYING → EXPLORING must succeed")

func test_exploring_to_playing_valid() -> void:
	gsm.transition_to(gsm.State.EXPLORING)
	gsm.transition_to(gsm.State.PLAYING)
	assert_eq(gsm.current_state, gsm.State.PLAYING, "EXPLORING → PLAYING must succeed")

func test_exploring_to_game_over_rejected() -> void:
	gsm.transition_to(gsm.State.EXPLORING)
	gsm.transition_to(gsm.State.GAME_OVER)
	assert_eq(gsm.current_state, gsm.State.EXPLORING,
		"EXPLORING → GAME_OVER must be silently rejected (no enemies while exploring)")

func test_request_explore_from_playing() -> void:
	gsm.request_explore()
	assert_eq(gsm.current_state, gsm.State.EXPLORING)

func test_request_explore_from_game_over_ignored() -> void:
	gsm.transition_to(gsm.State.GAME_OVER)
	gsm.request_explore()
	assert_eq(gsm.current_state, gsm.State.GAME_OVER,
		"request_explore must be a no-op when not PLAYING")

func test_request_return_to_td_from_exploring() -> void:
	gsm.request_explore()
	gsm.request_return_to_td()
	assert_eq(gsm.current_state, gsm.State.PLAYING)

func test_request_return_to_td_from_playing_ignored() -> void:
	gsm.request_return_to_td()
	assert_eq(gsm.current_state, gsm.State.PLAYING,
		"request_return_to_td must be a no-op when not EXPLORING")
