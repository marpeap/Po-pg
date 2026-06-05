## ResourceNodeTimed — tap-hold mining node for rare resources.
## Press and hold to fill progress bar; release before completion resets it.
## On completion: yields resource, flashes, becomes depleted for the session.
## Handles: original rares (IRON_ORE-HARDWOOD, idx 5-9) + 9 new rare types (42-50).
## ADR-002: Area2D, input_pickable for touch detection.
extends Area2D

const ENV := "res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/"
const TREE  := "res://assets/sprites/garrison/tree_sm.png"
const ROCK  := "res://assets/sprites/garrison/rock.png"

## Per-type config — keyed by ResourceInventory.Type int value.
## Fields: path, r/g/b (modulate), sx/sy (scale), hw/hh (collision half-size), yield_amt, duration_sec.
const TYPE_CFG: Dictionary = {
	## ─── ORIGINAL RARES (5-9) ────────────────────────────────────────────────
	5:  {path=ROCK,                     r=0.80, g=0.82, b=0.90, sx=0.49, sy=0.50, hw=21, hh=14, y=2, dur=2.5}, ## IRON_ORE — steel blue-gray
	6:  {path=ROCK,                     r=0.35, g=0.32, b=0.30, sx=0.49, sy=0.50, hw=21, hh=14, y=2, dur=2.5}, ## COAL — near black
	7:  {path=ROCK,                     r=0.50, g=0.82, b=1.00, sx=0.49, sy=0.50, hw=21, hh=14, y=1, dur=3.0}, ## CRYSTAL — bright blue
	8:  {path=ROCK,                     r=1.00, g=0.40, b=0.55, sx=0.49, sy=0.50, hw=21, hh=14, y=1, dur=4.0}, ## GEMSTONE — rose red (rare, slower)
	9:  {path=TREE,                     r=0.72, g=0.50, b=0.28, sx=0.55, sy=0.55, hw=19, hh=23, y=2, dur=3.0}, ## HARDWOOD — amber brown
	## ─── NEW RARES (42-50) ───────────────────────────────────────────────────
	42: {path=ENV+"medievalEnvironment_13.png", r=0.78, g=0.88, b=0.72, sx=0.90, sy=0.90, hw=12, hh=12, y=1, dur=3.5}, ## SILVER_LICHEN — silver-green
	43: {path=ENV+"medievalEnvironment_14.png", r=0.82, g=0.95, b=0.98, sx=1.05, sy=1.05, hw=12, hh=12, y=1, dur=3.5}, ## GHOST_MUSHROOM — pale cyan ghost
	44: {path=TREE,                     r=1.00, g=0.88, b=0.18, sx=0.50, sy=0.50, hw=18, hh=20, y=1, dur=4.0}, ## GOLDEN_SAP — golden amber
	45: {path=ENV+"medievalEnvironment_05.png", r=0.38, g=0.78, b=0.40, sx=0.80, sy=0.80, hw=12, hh=9,  y=1, dur=3.5}, ## SNAKE_SCALE — reptile green
	46: {path=ROCK,                     r=0.72, g=0.90, b=1.00, sx=0.52, sy=0.52, hw=21, hh=14, y=1, dur=3.0}, ## ICE_CRYSTAL — ice pale blue
	47: {path=ENV+"medievalEnvironment_14.png", r=1.00, g=0.38, b=0.10, sx=1.00, sy=1.00, hw=12, hh=12, y=1, dur=4.5}, ## LAVA_FLOWER — fiery red-orange
	48: {path=ROCK,                     r=0.70, g=0.60, b=1.00, sx=0.48, sy=0.48, hw=20, hh=13, y=1, dur=4.0}, ## STAR_DUST — violet starlight
	49: {path=ROCK,                     r=0.60, g=0.55, b=0.48, sx=0.58, sy=0.58, hw=23, hh=15, y=1, dur=5.0}, ## GOLEM_EYE — stone gray (rare, slowest)
	50: {path=ENV+"medievalEnvironment_05.png", r=0.80, g=0.92, b=1.00, sx=0.90, sy=0.90, hw=12, hh=9,  y=1, dur=3.5}, ## WIND_ESSENCE — sky blue-white
}

const BAR_W       := 40.0
const BAR_H       :=  6.0
const BAR_Y_OFFSET := 30.0

var _res_type:   int   = 0
var _res_yield:  int   = 1
var _duration:   float = 3.0
var _active:     bool  = true
var _pressing:   bool  = false
var _progress:   float = 0.0
var _touch_id:   int   = -1
var _pulse_time: float = 0.0

var _sprite:   Sprite2D  = null
var _bar_bg:   ColorRect = null
var _bar_fill: ColorRect = null
var _base_tint: Color    = Color.WHITE

## [param res_type] ResourceInventory.Type int value (e.g. ResourceInventory.Type.IRON_ORE = 5).
func setup(res_type: int) -> void:
	if not TYPE_CFG.has(res_type):
		return
	_res_type = res_type
	var cfg: Dictionary = TYPE_CFG[res_type]
	_res_yield = cfg.y
	_duration  = cfg.dur
	_base_tint = Color(cfg.r, cfg.g, cfg.b)
	input_pickable = true
	_build_visuals(cfg)
	input_event.connect(_on_input_event)

func _build_visuals(cfg: Dictionary) -> void:
	_sprite = Sprite2D.new()
	var tex: Texture2D = load(cfg.path)
	if tex != null:
		_sprite.texture = tex
	_sprite.scale    = Vector2(cfg.sx, cfg.sy)
	_sprite.modulate = _base_tint
	add_child(_sprite)

	## Progress bar (hidden until tap)
	_bar_bg = ColorRect.new()
	_bar_bg.size     = Vector2(BAR_W, BAR_H)
	_bar_bg.position = Vector2(-BAR_W * 0.5, BAR_Y_OFFSET)
	_bar_bg.color    = Color(0.15, 0.15, 0.15, 0.80)
	_bar_bg.visible  = false
	add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.size     = Vector2(0.0, BAR_H)
	_bar_fill.position = Vector2(-BAR_W * 0.5, BAR_Y_OFFSET)
	_bar_fill.color    = Color(0.25, 0.85, 0.30)
	_bar_fill.visible  = false
	add_child(_bar_fill)

	## Collision
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cfg.hw * 2.0, cfg.hh * 2.0)
	col.shape  = shape
	add_child(col)

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Extraire"

## Returns true when this node can be mined.
func is_interactable() -> bool:
	return _active

## Instant extraction — called by proximity button.
func interact() -> void:
	if _active:
		_on_complete()

func _process(delta: float) -> void:
	if not _active:
		return
	if not _pressing and _sprite != null:
		_pulse_time += delta * 2.2
		_sprite.modulate = Color(_base_tint.r, _base_tint.g, _base_tint.b,
			0.70 + sin(_pulse_time) * 0.30)
	if _pressing:
		_progress = minf(_progress + delta / _duration, 1.0)
		if _bar_fill != null:
			_bar_fill.size.x = _progress * BAR_W
		if _progress >= 1.0:
			_on_complete()
	else:
		if _progress > 0.0:
			_progress = maxf(_progress - delta * 2.0, 0.0)
			if _bar_fill != null:
				_bar_fill.size.x = _progress * BAR_W
			if _progress <= 0.0 and _bar_bg != null:
				_bar_bg.visible  = false
				_bar_fill.visible = false

func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_pressing = true
			if _bar_bg   != null: _bar_bg.visible   = true
			if _bar_fill != null: _bar_fill.visible  = true
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_pressing = false

func _on_complete() -> void:
	if not _active:
		return
	_active   = false
	_pressing = false
	input_pickable = false
	## PrestigeSystem bonus yield applied at collection time.
	var prestige_mult: float = PrestigeSystem.get_rare_resource_mult() if PrestigeSystem != null else 1.0
	var effective_yield: int = roundi(float(_res_yield) * prestige_mult)
	ResourceInventory.add(_res_type, effective_yield)
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(1.8, 1.8, 1.8), 0.08)
		tw.tween_property(_sprite, "modulate", Color(0.30, 0.30, 0.30, 0.55), 0.25)
	if _bar_bg   != null: _bar_bg.visible   = false
	if _bar_fill != null: _bar_fill.visible  = false
