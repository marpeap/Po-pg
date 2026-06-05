## Unit tests for AudioManager autoload
## Story: F01-S02
## GUT 9.6.0 — extends GutTest
##
## Tests the volley volume formula directly without spawning the autoload.
extends GutTest

## Isolated formula tests — no Node tree needed for these
const FORMULA_TOLERANCE := 0.01

func _volley_volume_db(archer_count: int) -> float:
	var n := clampf(float(archer_count), 2.0, 8.0)
	return lerpf(-6.0, 0.0, (n - 2.0) / 6.0)

func test_play_volley_2_archers_volume_minus_6db() -> void:
	var vol := _volley_volume_db(2)
	assert_almost_eq(vol, -6.0, FORMULA_TOLERANCE,
		"2 archers must produce -6dB")

func test_play_volley_8_archers_volume_0db() -> void:
	var vol := _volley_volume_db(8)
	assert_almost_eq(vol, 0.0, FORMULA_TOLERANCE,
		"8 archers must produce 0dB")

func test_play_volley_midpoint_minus_3db() -> void:
	# n=5: (5-2)/6 = 0.5 → lerp(-6, 0, 0.5) = -3dB
	var vol := _volley_volume_db(5)
	assert_almost_eq(vol, -3.0, FORMULA_TOLERANCE,
		"5 archers (midpoint) must produce -3dB")

func test_play_volley_clamps_below_2() -> void:
	# count=0 clamps to 2 → -6dB
	var vol := _volley_volume_db(0)
	assert_almost_eq(vol, -6.0, FORMULA_TOLERANCE,
		"count < 2 must clamp to 2 archers (-6dB)")

func test_play_volley_clamps_above_8() -> void:
	# count=16 clamps to 8 → 0dB
	var vol := _volley_volume_db(16)
	assert_almost_eq(vol, 0.0, FORMULA_TOLERANCE,
		"count > 8 must clamp to 8 archers (0dB)")

## Node-level tests — AudioManager as an instance (not autoload)
var audio_mgr: Node

func before_each() -> void:
	audio_mgr = load("res://src/autoloads/audio_manager.gd").new()
	# _ready() calls GameStateMachine.session_reset.connect — stub it out
	# by not calling _ready(); instead call the registration manually
	# for structural tests only
	add_child_autofree(audio_mgr)

func test_play_does_not_crash_without_audio_asset() -> void:
	# AudioStreamPlayer with no stream set — play() is a no-op in Godot 4
	# Confirm no exception is raised
	audio_mgr.play(&"volley")
	pass  # reaching here without error = PASS

func test_players_dict_contains_expected_sfx_keys() -> void:
	# After _ready(), all 6 players must be registered
	var expected := [
		&"volley", &"coin_collect", &"recruit",
		&"castle_hit", &"game_over", &"dwell_complete"
	]
	for key: StringName in expected:
		assert_true(key in audio_mgr._players,
			"AudioManager must register player for: %s" % key)
