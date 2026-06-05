## MainMenu — pre-game menu screen displayed before gameplay begins.
## Shows animated title, Nouvelle Partie / Continuer / Options buttons,
## and the hero's current level from HeroProgression.
## ADR-007: CanvasLayer-based menu; Tween for animations; no AnimationPlayer.
extends CanvasLayer

signal play_pressed()
signal continue_pressed()
signal options_pressed()

const GARRISON_TITLE := "GARRISON"
const SUBTITLE       := "Défendez. Explorez. Survivez."

## Colors
const CLR_TITLE   := Color(1.00, 0.92, 0.40)     ## Gold
const CLR_SUB     := Color(0.85, 0.78, 0.60)     ## Warm parchment
const CLR_BTN_NRM := Color(0.22, 0.20, 0.16)     ## Dark panel
const CLR_BTN_HOV := Color(0.32, 0.28, 0.18)     ## Slightly lighter on press
const CLR_BTN_TXT := Color(1.00, 0.90, 0.65)     ## Warm white
const CLR_OVERLAY := Color(0.06, 0.05, 0.03, 0.88)  ## Near-black translucent BG

## Layout constants (landscape 960×540).
const SCREEN_W := 960.0
const SCREEN_H := 540.0

var _root_panel: ColorRect = null
var _title_lbl:  Label     = null
var _sub_lbl:    Label     = null
var _level_lbl:  Label     = null
var _btn_new:    Button    = null
var _btn_cont:   Button    = null
var _btn_opts:   Button    = null
var _built:      bool      = false

func _ready() -> void:
	layer = 10  ## Above all gameplay layers.
	_build_ui()
	_animate_in()
	## Update hero level display from persistent progression.
	_refresh_level_display()
	if HeroProgression != null:
		HeroProgression.level_up.connect(func(_lvl: int) -> void: _refresh_level_display())

## Build the full menu layout programmatically.
func _build_ui() -> void:
	if _built:
		return
	_built = true

	## Background overlay.
	_root_panel = ColorRect.new()
	_root_panel.size     = Vector2(SCREEN_W, SCREEN_H)
	_root_panel.color    = CLR_OVERLAY
	_root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_panel)

	## Decorative top bar.
	var top_bar := ColorRect.new()
	top_bar.size     = Vector2(SCREEN_W, 4.0)
	top_bar.position = Vector2(0.0, 0.0)
	top_bar.color    = CLR_TITLE
	_root_panel.add_child(top_bar)
	var bot_bar := ColorRect.new()
	bot_bar.size     = Vector2(SCREEN_W, 4.0)
	bot_bar.position = Vector2(0.0, SCREEN_H - 4.0)
	bot_bar.color    = CLR_TITLE
	_root_panel.add_child(bot_bar)

	## Title label.
	_title_lbl = Label.new()
	_title_lbl.text = GARRISON_TITLE
	_title_lbl.add_theme_font_size_override("font_size", 52)
	_title_lbl.add_theme_color_override("font_color", CLR_TITLE)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.size                 = Vector2(SCREEN_W, 70.0)
	_title_lbl.position             = Vector2(0.0, 95.0)
	_title_lbl.modulate.a           = 0.0  ## Start invisible for fade-in
	_root_panel.add_child(_title_lbl)

	## Subtitle.
	_sub_lbl = Label.new()
	_sub_lbl.text = SUBTITLE
	_sub_lbl.add_theme_font_size_override("font_size", 14)
	_sub_lbl.add_theme_color_override("font_color", CLR_SUB)
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.size                 = Vector2(SCREEN_W, 24.0)
	_sub_lbl.position             = Vector2(0.0, 158.0)
	_sub_lbl.modulate.a           = 0.0
	_root_panel.add_child(_sub_lbl)

	## Hero level badge (bottom-left).
	_level_lbl = Label.new()
	_level_lbl.add_theme_font_size_override("font_size", 12)
	_level_lbl.add_theme_color_override("font_color", CLR_SUB)
	_level_lbl.position = Vector2(18.0, SCREEN_H - 28.0)
	_level_lbl.size     = Vector2(200.0, 24.0)
	_root_panel.add_child(_level_lbl)

	## Buttons column — centered.
	var btn_x: float = SCREEN_W * 0.5 - 110.0
	var btn_y: float = 220.0
	var btn_gap: float = 62.0

	_btn_new  = _make_button("Nouvelle Partie", Vector2(btn_x, btn_y))
	_btn_cont = _make_button("Continuer",       Vector2(btn_x, btn_y + btn_gap))
	_btn_opts = _make_button("Options",         Vector2(btn_x, btn_y + btn_gap * 2.0))

	## Disable Continue if no save file exists.
	if HeroProgression != null and HeroProgression.hero_level <= 1 and HeroProgression.hero_xp == 0:
		_btn_cont.modulate.a = 0.38
		_btn_cont.disabled   = true

	_btn_new.pressed.connect(_on_new_pressed)
	_btn_cont.pressed.connect(_on_continue_pressed)
	_btn_opts.pressed.connect(_on_options_pressed)

	for btn: Button in [_btn_new, _btn_cont, _btn_opts]:
		btn.modulate.a = 0.0  ## Start invisible

## Animate the menu fading in.
func _animate_in() -> void:
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_interval(0.2)
	tw.tween_property(_title_lbl, "modulate:a", 1.0, 0.5)
	tw.tween_property(_sub_lbl,   "modulate:a", 1.0, 0.4)
	for btn: Button in [_btn_new, _btn_cont, _btn_opts]:
		tw.tween_property(btn, "modulate:a", 1.0, 0.25)

## Animate the menu fading out then emit the signal.
func animate_out_and_emit(sig: Signal) -> void:
	var tw := create_tween()
	tw.tween_property(_root_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		sig.emit()
		queue_free())

func _make_button(text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = Vector2(220.0, 48.0)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", CLR_BTN_TXT)
	btn.add_theme_color_override("font_hover_color", CLR_TITLE)
	_root_panel.add_child(btn)
	return btn

func _refresh_level_display() -> void:
	if _level_lbl == null:
		return
	if HeroProgression != null:
		_level_lbl.text = "Heros Niveau %d  |  %d XP" % [
			HeroProgression.hero_level, HeroProgression.hero_xp]
	else:
		_level_lbl.text = "Niveau 1"

func _on_new_pressed() -> void:
	if HeroProgression != null:
		HeroProgression.reset_all()
	animate_out_and_emit(play_pressed)

func _on_continue_pressed() -> void:
	animate_out_and_emit(continue_pressed)

func _on_options_pressed() -> void:
	options_pressed.emit()
