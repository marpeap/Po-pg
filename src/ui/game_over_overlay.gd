## GameOverOverlay — GAME_OVER screen with tap-to-restart
## ADR-007: Tween only — no AnimationPlayer on CanvasLayer nodes
## ADR-005: GSM integration — tap calls request_restart()
## GDD Req: TR-gameover-001
##
## Appears on same frame as game_state_changed(GAME_OVER).
## Panel enters with scale 0.8→1.0 in 0.15s (Tween).
## Restart label pulses at ~1Hz. Tap anywhere triggers request_restart().
extends Node2D

## Node references — set by Main via setup()
var panel: Control
var wave_label: Label
var kills_label: Label
var restart_label: Label

var _enemy_wave: Node  ## Set by Main — provides current_wave and total_kills

func setup(
		p_panel: Control,
		p_wave_label: Label,
		p_kills_label: Label,
		p_restart_label: Label,
		p_enemy_wave: Node) -> void:
	panel = p_panel
	wave_label = p_wave_label
	kills_label = p_kills_label
	restart_label = p_restart_label
	_enemy_wave = p_enemy_wave
	GameStateMachine.game_state_changed.connect(_on_game_state_changed)
	visible = false

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameStateMachine.State.GAME_OVER:
		# Populate stats
		if _enemy_wave != null:
			wave_label.text = "Wave reached: %d" % _enemy_wave.current_wave
			kills_label.text = "Enemies defeated: %d" % _enemy_wave.total_kills
		else:
			wave_label.text = "Wave reached: —"
			kills_label.text = "Enemies defeated: —"
		_show_overlay()
		_pulse_restart_label()
	else:
		visible = false

## Show overlay and animate panel scale 0.8 → 1.0 in 0.15s (Tween, EASE_OUT)
func _show_overlay() -> void:
	visible = true
	if panel == null:
		return
	panel.scale = Vector2(0.8, 0.8)
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

## Pulse restart label alpha 1.0 → 0.6 → 1.0 in loop, period ≈ 2s (1Hz blink)
func _pulse_restart_label() -> void:
	if restart_label == null:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(restart_label, "modulate:a", 0.6, 1.0).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(restart_label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT)

func _input(event: InputEvent) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.GAME_OVER:
		return
	if event is InputEventScreenTouch and event.pressed:
		GameStateMachine.request_restart()
