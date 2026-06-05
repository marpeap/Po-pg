# Story F04-S01: Camera2D Follow with ADR-004 Lerp

> **Epic**: EPIC-F04 Camera System
> **Status**: Not Started
> **Type**: Logic
> **Test Evidence Required**: Unit test for lerp formula — BLOCKING; Visual inspection at 30fps/60fps — ADVISORY
> **Estimate**: 0.5 day
> **GDD Req ID**: TR-camera-001
> **ADR Refs**: ADR-001, ADR-004

## What to Build

Camera2D configuration + follow script. Camera is a child of Main scene (NOT hero).

```gdscript
# In Main.gd or a dedicated camera_follow.gd
const CAMERA_LERP_F := 0.10
var _camera: Camera2D

func _ready() -> void:
    _camera = $Camera2D
    _camera.position_smoothing_enabled = false
    _camera.limit_left = 0
    _camera.limit_top = 0
    _camera.limit_right = 1080
    _camera.limit_bottom = 1920

func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
        return
    var weight := 1.0 - pow(1.0 - CAMERA_LERP_F, delta * 60.0)
    _camera.position = _camera.position.lerp(_hero.position, weight)
```

Session reset: `_camera.position = HERO_START_POS`

## Engine Notes

- `Camera2D.position_smoothing_enabled = false` is MANDATORY (forbidden pattern if true)
- Camera limits are in WORLD space (0,0 to 1080,1920)
- ADR-004 formula is the ONLY acceptable lerp form

## Acceptance Criteria

- [ ] Camera follows hero position using `1.0 - pow(1.0 - 0.10, delta * 60.0)` weight
- [ ] `Camera2D.position_smoothing_enabled` is `false`
- [ ] Camera never shows world coordinates < 0 or > 1080 (x) / > 1920 (y)
- [ ] Camera does not update during GAME_OVER
- [ ] Camera resets to hero start position on session reset

## Test File

`tests/unit/gameplay/camera_follow_test.gd`

Test cases:
- `test_lerp_weight_at_60fps` — at delta=0.0167, weight ≈ 0.095
- `test_lerp_weight_at_30fps` — at delta=0.0333, weight ≈ 0.181 (normalized equivalent)
- `test_camera_stays_in_world_bounds`
- `test_camera_halts_on_game_over`
