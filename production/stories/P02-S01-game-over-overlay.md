# Story P02-S01: GAME_OVER Overlay + Tap-to-Restart + Session Reset UX

> **Epic**: EPIC-P02 Game Over Screen + Session Reset UX
> **Status**: Not Started
> **Type**: UI
> **Test Evidence Required**: Manual walkthrough + screenshot — ADVISORY
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-gameover-001
> **ADR Refs**: ADR-005, ADR-007, ADR-009

## What to Build

`src/ui/game_over_overlay.gd` — GAME_OVER overlay, panel, stats, tap-to-restart.

### Node Structure

```
HUDLayer (CanvasLayer, layer=1)
  ...HUD nodes...
  GameOverOverlay (CanvasControl — Control node filling full screen)
    DarkOverlay (ColorRect, 540×960, Color(0.05,0.05,0.08,0.70))
    Panel (PanelContainer or NinePatchRect, centered 340×280)
      VBoxContainer
        HeadlineLabel ("CASTLE FELL", 24px, bold, centered)
        WaveReachedLabel ("Wave reached: N", 16px, centered)
        KillsLabel ("Enemies defeated: N", 16px, centered)
        RestartLabel ("TAP ANYWHERE TO RESTART", 14px, centered)
```

### Panel Entrance Animation (Tween)

```gdscript
func _show_overlay() -> void:
    visible = true
    panel.scale = Vector2(0.8, 0.8)
    var tween := create_tween()
    tween.tween_property(panel, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

func _pulse_restart_label() -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(restart_label, "modulate:a", 0.6, 1.0).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(restart_label, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT)
```

### Stat Population

```gdscript
func _on_game_state_changed(new_state) -> void:
    if new_state == GameStateMachine.State.GAME_OVER:
        wave_label.text = "Wave reached: %d" % enemy_wave.current_wave
        kills_label.text = "Enemies defeated: %d" % enemy_wave.total_kills
        _show_overlay()
        _pulse_restart_label()
    else:
        visible = false
```

### Tap-to-Restart

```gdscript
func _input(event: InputEvent) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.GAME_OVER: return
    if event is InputEventScreenTouch and event.pressed:
        GameStateMachine.request_restart()
```

## Acceptance Criteria

- [ ] GAME_OVER overlay appears on the same frame as `game_state_changed(GAME_OVER)`
- [ ] Overlay covers the full screen; game world visible underneath
- [ ] Panel shows correct wave reached and kill count
- [ ] "TAP ANYWHERE TO RESTART" text pulses at ~1Hz via Tween
- [ ] Panel entrance scale animation: 0.8→1.0 in ≤0.2s
- [ ] Tapping anywhere during GAME_OVER triggers `GameStateMachine.request_restart()`
- [ ] Tapping during RESETTING does not trigger another restart
- [ ] Overlay is invisible during PLAYING and RESETTING
- [ ] No `AnimationPlayer` used — Tween only

## Manual Walkthrough Evidence

`production/qa/evidence/game_over_walkthrough.md` — screenshots at:
1. Moment of castle fall — overlay appears
2. Panel with stats visible
3. Post-tap — game restarted, overlay gone
