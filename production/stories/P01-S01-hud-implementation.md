# Story P01-S01: HUD — All 4 Elements

> **Epic**: EPIC-P01 HUD System
> **Status**: Not Started
> **Type**: UI
> **Test Evidence Required**: Manual walkthrough + screenshot — ADVISORY; Unit test for HP ratio formula — BLOCKING
> **Estimate**: 1 day
> **GDD Req ID**: TR-hud-001
> **ADR Refs**: ADR-007, ADR-005

## What to Build

`src/ui/hud.gd` — attached to HUDLayer (CanvasLayer, layer=1) in Main.tscn.

### Node Structure

```
HUDLayer (CanvasLayer, layer=1)
  HUD (Node)
    HUDStrip (ColorRect, 540×48, Color(0,0,0,0.55))
    GoldLabel (Label)          # "60" — top-left + 12px inset
    CastleBar (ProgressBar)    # top-center
    CastleHPLabel (Label)      # numeric HP beside bar
    WaveLabel (Label)          # top-right
    ArcherBadge (Label)        # below wave label
```

### Gold Counter

```gdscript
func _on_gold_changed(new_gold: int) -> void:
    gold_label.text = str(new_gold)
    _update_affordability_highlight()

func _update_affordability_highlight() -> void:
    var cost := ARCHER_COST_T1 if _archer_count < 4 else ARCHER_COST_T2
    var can_afford := _current_gold >= cost and _archer_count < MAX_FORMATION_SLOTS
    gold_label.modulate = Color("#F5C518") if can_afford else Color.WHITE
```

### Castle HP Bar

```gdscript
func _on_hp_changed(new_hp: int) -> void:
    castle_bar.value = new_hp
    castle_hp_label.text = str(new_hp)
    var ratio: float = float(new_hp) / float(CASTLE_MAX_HP)
    if ratio >= 0.6:
        castle_bar.modulate = Color("#4CAF50")   # GREEN
    elif ratio >= 0.3:
        castle_bar.modulate = Color("#FFC107")   # AMBER
    else:
        castle_bar.modulate = Color("#F44336")   # RED
```

### Wave Indicator

```gdscript
var _wave_active: bool = false
var _countdown: float = 0.0

func _on_wave_started(wave_number: int) -> void:
    _wave_active = true
    wave_label.text = "Wave %d" % wave_number
    wave_label.modulate = Color.WHITE

func _on_wave_cleared() -> void:
    _wave_active = false
    _countdown = INTER_WAVE_PAUSE
    wave_label.modulate = Color("#F5C518")

func _process(delta: float) -> void:
    if not _wave_active and _countdown > 0.0:
        _countdown = max(_countdown - delta, 0.0)
        wave_label.text = "Next: %ds" % int(_countdown)
    # Stop processing when HUD hidden
```

### Archer Badge

```gdscript
func _on_recruit_purchased() -> void:
    _archer_count = archer_formation.current_archer_count
    archer_badge.text = "%d/8" % _archer_count
    _update_affordability_highlight()

func _on_formation_full() -> void:
    archer_badge.modulate = Color("#F5C518")
```

### Safe Area

```gdscript
func _ready() -> void:
    var safe_rect := DisplayServer.get_display_safe_area()
    # Offset HUD strip top by safe_rect.position.y
    hud_strip.position.y = safe_rect.position.y
    # Offset all elements accordingly
```

### Session Init (on game_state_changed → PLAYING)

```gdscript
func _on_game_state_changed(new_state) -> void:
    if new_state == GameStateMachine.State.PLAYING:
        visible = true
        _current_gold = economy.current_gold
        gold_label.text = str(_current_gold)
        castle_bar.value = castle.castle_hp
        castle_hp_label.text = str(castle.castle_hp)
        _archer_count = archer_formation.current_archer_count
        archer_badge.text = "%d/8" % _archer_count
        archer_badge.modulate = Color.WHITE
        wave_label.text = "Wave 1"
        _wave_active = false
        _countdown = 0.0
        _update_affordability_highlight()
    else:
        visible = false
```

## Acceptance Criteria

- [ ] HUD strip visible during PLAYING; hidden in GAME_OVER and RESETTING
- [ ] Gold counter updates instantly on `gold_changed`
- [ ] Gold counter turns amber when can-afford-recruit; returns to white when cannot
- [ ] Castle HP bar fill and color band correct at 200/200 (green), 100/200 (amber), 50/200 (red)
- [ ] Castle HP numeric always visible alongside bar
- [ ] Wave label: "Wave N" during wave; "Next: Xs" during inter-wave
- [ ] Archer badge: "2/8" at start; increments on recruit; gold color when full
- [ ] All elements initialized correctly on session start
- [ ] HUD elements inside safe area on device with camera notch

## Test File

`tests/unit/ui/hud_formulas_test.gd`

Test cases:
- `test_castle_hp_ratio_at_full`
- `test_castle_hp_ratio_green_threshold`
- `test_castle_hp_ratio_amber_threshold`
- `test_castle_hp_ratio_red_threshold`
- `test_affordability_highlight_t1_cost`
- `test_affordability_highlight_t2_cost`
- `test_affordability_suppressed_when_full_formation`
