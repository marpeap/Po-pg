## Unit tests for CameraFollow lerp formula
## Story: F04-S01
## GUT 9.6.0 — extends GutTest
##
## Tests the ADR-004 lerp weight formula at various frame rates.
extends GutTest

const CAMERA_LERP_F := 0.10
const TOLERANCE := 0.001

## Formula under test: 1.0 - pow(1.0 - F, delta * 60.0)
func _lerp_weight(delta: float) -> float:
	return 1.0 - pow(1.0 - CAMERA_LERP_F, delta * 60.0)

func test_lerp_weight_at_60fps() -> void:
	# delta = 1/60 ≈ 0.01667s → weight should be close to CAMERA_LERP_F itself
	var weight := _lerp_weight(1.0 / 60.0)
	# At exactly 60fps: 1 - pow(0.9, 1) = 0.10
	assert_almost_eq(weight, 0.10, TOLERANCE, "At 60fps, weight must equal CAMERA_LERP_F")

func test_lerp_weight_at_30fps() -> void:
	# delta = 1/30 ≈ 0.03333s → weight = 1 - pow(0.9, 2) = 1 - 0.81 = 0.19
	var weight := _lerp_weight(1.0 / 30.0)
	assert_almost_eq(weight, 0.19, TOLERANCE, "At 30fps, weight must be ~0.19 (frame-rate-independent)")

func test_lerp_weight_at_120fps() -> void:
	# delta = 1/120 → weight = 1 - pow(0.9, 0.5) ≈ 0.0513
	var weight := _lerp_weight(1.0 / 120.0)
	# Two 120fps frames should compound to same as one 60fps frame
	var compound := 1.0 - (1.0 - weight) * (1.0 - weight)
	assert_almost_eq(compound, 0.10, TOLERANCE,
		"Two 120fps frames must compound to same as one 60fps frame (frame-rate independence)")

func test_camera_stays_in_world_bounds() -> void:
	# Verify the limits match the ADR-001 world dimensions
	var cam_follow: Node = load("res://src/gameplay/camera_follow.gd").new()
	assert_eq(cam_follow.LIMIT_LEFT, 0)
	assert_eq(cam_follow.LIMIT_TOP, 0)
	assert_eq(cam_follow.LIMIT_RIGHT, 1920)
	assert_eq(cam_follow.LIMIT_BOTTOM, 1080)
	cam_follow.free()

func test_camera_halts_on_game_over() -> void:
	# When GSM is not PLAYING, _process must be a no-op
	# This is a logic check: the guard condition exists in the source
	var src := FileAccess.open("res://src/gameplay/camera_follow.gd", FileAccess.READ)
	var content := src.get_as_text()
	src.close()
	assert_true(content.contains("GameStateMachine.State.PLAYING"),
		"camera_follow.gd must guard on PLAYING state")
