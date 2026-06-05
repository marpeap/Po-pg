## CameraFollow — attaches to Camera2D child of Main
## ADR-004: Frame-rate-independent lerp
## ADR-001: Viewport 960×540 (landscape), world 1920×1080 (TD) / 3840×1080 (EXPLORING)
## GDD Req: TR-camera-001
##
## Camera2D follows the hero using the ADR-004 frame-rate-independent lerp.
## position_smoothing_enabled MUST remain false (forbidden pattern).
## Limits expand to 3840×1080 when entering EXPLORING and restore to 1920×1080 on PLAYING.
extends Node

const CAMERA_LERP_F := 0.10

## TD world bounds (landscape 1920×1080)
const LIMIT_LEFT   := 0
const LIMIT_TOP    := 0
const LIMIT_RIGHT  := 1920
const LIMIT_BOTTOM := 1080

## Exploration world bounds — extended (9600×3240)
const EXPL_LIMIT_RIGHT  := 9600
const EXPL_LIMIT_BOTTOM := 3240

var _camera: Camera2D
var _hero: Node2D

## Screen shake state — intensity in world-px, countdown in seconds.
var _shake_intensity: float = 0.0
var _shake_remaining: float = 0.0
var _shake_duration: float = 0.001   ## Total duration for linear decay (avoids div/0)

## Trigger a screen shake: intensity px offset, duration seconds.
func shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_remaining = maxf(_shake_remaining, duration)
	_shake_duration = maxf(_shake_remaining, 0.001)

func setup(camera: Camera2D, hero: Node2D) -> void:
	_camera = camera
	_hero = hero
	_camera.position_smoothing_enabled = false
	_camera.limit_left   = LIMIT_LEFT
	_camera.limit_top    = LIMIT_TOP
	_camera.limit_right  = LIMIT_RIGHT
	_camera.limit_bottom = LIMIT_BOTTOM
	_camera.position = _hero.global_position  ## Snap immediately — prevents jarring drift at game start
	_camera.force_update_scroll()  ## Force viewport transform update — without this, camera stays at (0,0) until next frame
	print("[DIAG] camera snapped to ", _camera.position, " | hero.global_pos=", _hero.global_position)
	GameStateMachine.session_reset.connect(_on_session_reset)
	GameStateMachine.game_state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if _camera == null or _hero == null:
		return
	var state := GameStateMachine.current_state
	if state != GameStateMachine.State.PLAYING and state != GameStateMachine.State.EXPLORING:
		return
	var weight: float = 1.0 - pow(1.0 - CAMERA_LERP_F, delta * 60.0)
	_camera.position = _camera.position.lerp(_hero.global_position, weight)
	## Screen shake — linearly damps to zero as remaining countdown expires.
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - delta)
		var t: float = _shake_remaining / _shake_duration  ## 1.0 → 0.0 over full duration
		_camera.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity) * t,
			randf_range(-_shake_intensity, _shake_intensity) * t
		)
	else:
		_camera.offset = Vector2.ZERO

func _on_state_changed(new_state: int) -> void:
	if _camera == null:
		return
	if new_state == GameStateMachine.State.EXPLORING:
		_camera.limit_right  = EXPL_LIMIT_RIGHT
		_camera.limit_bottom = EXPL_LIMIT_BOTTOM
	else:
		_camera.limit_right  = LIMIT_RIGHT
		_camera.limit_bottom = LIMIT_BOTTOM

func _on_session_reset() -> void:
	if _camera != null and _hero != null:
		_camera.position = _hero.global_position
		_camera.force_update_scroll()
