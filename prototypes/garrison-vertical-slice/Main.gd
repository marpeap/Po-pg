# VERTICAL SLICE — NOT FOR PRODUCTION
# Validation Question: Does the full Garrison loop (joystick + V-formation +
#   castle HP + wave system + economy dwell zones) deliver the "commanding
#   general defending a castle" fantasy AND the "each gold piece is a decision"
#   tension within a single play session of 3+ waves, without developer guidance?
# Date: 2026-05-19
# Build scope: Hero movement, archer formation, castle HP + game over,
#   3-wave system with inter-wave pause, economy (gold drops + magnet +
#   RECRUIT_ZONE dwell), session reset, HUD (4 elements + dwell bar).
# Known simplification: fixed viewport 540×960 (no camera scroll).
#   The concept prototype REPORT noted camera follow is a production requirement —
#   intentionally excluded here to isolate core loop validation.

extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# GAME STATE
# ═══════════════════════════════════════════════════════════════════════════════

enum State { PLAYING, WAVE_CLEAR, GAME_OVER, RESETTING }
var _state: State = State.RESETTING

# ═══════════════════════════════════════════════════════════════════════════════
# TUNING CONSTANTS  (all values from GDD + ADR decisions, scaled to 540×960 VS)
# ═══════════════════════════════════════════════════════════════════════════════

const VP := Vector2(540.0, 960.0)

# -- Hero --
const HERO_SPEED    := 200.0       # px/s — matches hero-movement.md
const HERO_RADIUS   := 18.0        # px

# -- Archer Formation --
const ARCHER_RADIUS    := 12.0
const ARCHER_RANGE     := 320.0    # px — targeting radius from hero center
const SHOOT_IVTL       := 1.2      # seconds — matches archer-formation.md
const SHOOT_STAGGER    := 0.15     # seconds offset between archers (continuous fire feel)
const PROJ_SPEED       := 420.0
const PROJ_LIFETIME    := 1.4      # seconds
const ARCHER_LERP_F    := 0.12     # frame-rate-independent factor base (ADR-004)
const STARTING_ARCHERS := 2
const MAX_ARCHERS      := 8

# V-formation slot offsets relative to hero (same as concept prototype — validated)
const FORMATION: Array[Vector2] = [
	Vector2(-45.0,  58.0), Vector2( 45.0,  58.0),
	Vector2(-82.0, 104.0), Vector2(  0.0,  96.0), Vector2( 82.0, 104.0),
	Vector2(-118.0,150.0), Vector2(  0.0, 142.0), Vector2(118.0, 150.0),
]

# -- Enemies --
const ENEMY_RADIUS   := 16.0
const ENEMY_SPEED    := 62.0       # px/s (GDD: 70 world px/s, scaled ~0.88 for VS pacing)
const ENEMY_HP_BASE  := 3          # HP at wave 1 (GDD: 30, scaled 1:10 for 1-damage arrows)
const ENEMY_HP_SCALE := 1          # +HP per wave (GDD: 3, scaled 1:3)

# -- Castle --
const CASTLE_POS       := Vector2(270.0, 62.0)    # top center of viewport
const CASTLE_RADIUS    := 38.0
const CASTLE_MAX_HP    := 60       # matches castle.md exactly
const CASTLE_DMG       := 10       # per enemy contact — matches castle.md

# -- Economy --
const STARTING_GOLD   := 60        # matches economy.md
const ARCHER_COST_T1  := 30        # archers 3+4 — matches economy.md
const ARCHER_COST_T2  := 60        # archers 5+ — matches economy.md
const GOLD_MAGNET_R   := 120.0     # px (GDD: 170 world px, scaled for 540×960 VS)
const GOLD_SPEED      := 280.0
const GOLD_COLLECT_R  := 22.0
const GOLD_RADIUS     := 9.0
const GOLD_DROP_MIN   := 1         # coins per enemy kill
const GOLD_DROP_MAX   := 3

# -- Recruit Zone --
const RECRUIT_ZONE_POS := Vector2(135.0, 490.0)   # mid-field left — requires movement to reach
const ZONE_RADIUS      := 55.0     # px (GDD: 90 world px, scaled; bumped 10 for touch usability)
const DWELL_TIME       := 0.8      # seconds — matches economy.md exactly

# -- Wave System --
const WAVE_CLEAR_PAUSE := 6.0      # seconds inter-wave — (GDD suggests 5s + 2s×N; VS uses 6s flat)
const BASE_WAVE_COUNT  := 5        # VS tests 5 waves; game continues until castle falls after that

# -- Joystick --
const JOY_RADIUS   := 80.0
const JOY_DEAD_ZONE := 5.0
const JOY_ANCHOR   := Vector2(135.0, 800.0)   # fixed bottom-left — validated in concept prototype

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION STATE
# ═══════════════════════════════════════════════════════════════════════════════

# Hero
var _hero_pos:     Vector2 = Vector2(270.0, 820.0)
var _facing_angle: float   = -PI / 2.0   # start facing upward toward castle

# Archers: Array of {pos:Vector2, shoot_cd:float, active:bool}
var _archer_slots: Array[Dictionary] = []
var _archer_count: int = STARTING_ARCHERS

# Game entities
var _enemies:    Array[Dictionary] = []   # {pos, hp, max_hp}
var _projs:      Array[Dictionary] = []   # {pos, vel, life}
var _gold_coins: Array[Vector2]    = []

# Economy
var _gold: int = STARTING_GOLD
var _dwell_timer: float = 0.0
var _in_zone: bool = false

# Castle
var _castle_hp: int = CASTLE_MAX_HP

# Wave
var _current_wave: int  = 0
var _wave_active:  bool = false
var _wave_clear_timer: float = 0.0

# GAME_OVER
var _restart_timer: float = 0.0
var _can_restart: bool = false

# Joystick
var _joy_active:    bool    = false
var _joy_touch_idx: int     = -1
var _joy_output:    Vector2 = Vector2.ZERO
var _joy_knob:      Vector2 = JOY_ANCHOR

# ═══════════════════════════════════════════════════════════════════════════════
# HUD NODES
# ═══════════════════════════════════════════════════════════════════════════════

var _hud_layer:     CanvasLayer
var _lbl_gold:      Label
var _lbl_wave:      Label
var _lbl_archers:   Label
var _lbl_status:    Label
var _lbl_hint:      Label
var _hp_bar_fill:   ColorRect
var _hp_bar_bg:     ColorRect

# ═══════════════════════════════════════════════════════════════════════════════
# INIT
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_init_ui()
	_session_reset()


func _init_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 1
	add_child(_hud_layer)

	# HUD background strip
	var strip := ColorRect.new()
	strip.color   = Color(0.0, 0.0, 0.0, 0.58)
	strip.position = Vector2.ZERO
	strip.size     = Vector2(VP.x, 54.0)
	_hud_layer.add_child(strip)

	# Gold counter — top left
	_lbl_gold = _lbl("Gold: 60", Vector2(8.0, 4.0), 20, Color(1.0, 0.88, 0.12))
	_hud_layer.add_child(_lbl_gold)

	# Castle HP bar background
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color    = Color(0.18, 0.0, 0.0, 0.9)
	_hp_bar_bg.position = Vector2(8.0, 34.0)
	_hp_bar_bg.size     = Vector2(188.0, 14.0)
	_hud_layer.add_child(_hp_bar_bg)

	# Castle HP bar fill
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color    = Color(0.15, 0.82, 0.25)
	_hp_bar_fill.position = Vector2(8.0, 34.0)
	_hp_bar_fill.size     = Vector2(188.0, 14.0)
	_hud_layer.add_child(_hp_bar_fill)

	# Castle HP text
	var lbl_hp := _lbl("HP", Vector2(202.0, 32.0), 16, Color(0.7, 0.7, 0.7))
	_hud_layer.add_child(lbl_hp)

	# Wave label — top center
	_lbl_wave = _lbl("Wave 1", Vector2(VP.x * 0.5 - 36.0, 4.0), 20, Color.WHITE)
	_hud_layer.add_child(_lbl_wave)

	# Archer badge — top right
	_lbl_archers = _lbl("2 / 8", Vector2(VP.x - 72.0, 4.0), 20, Color(0.35, 0.95, 0.45))
	_hud_layer.add_child(_lbl_archers)

	# Status label — center screen (wave clear, game over)
	_lbl_status = _lbl("", Vector2(0.0, VP.y * 0.42), 36, Color(1.0, 0.92, 0.3))
	_lbl_status.custom_minimum_size = Vector2(VP.x, 48.0)
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_lbl_status)

	# Hint — bottom
	_lbl_hint = _lbl("Touch bottom half to move", Vector2(0.0, VP.y - 32.0), 17, Color(1.0, 1.0, 1.0, 0.35))
	_lbl_hint.custom_minimum_size = Vector2(VP.x, 28.0)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_lbl_hint)


func _lbl(text: String, pos: Vector2, font_size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.modulate = col
	l.add_theme_font_size_override("font_size", font_size)
	return l

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION RESET  (GSM pattern: RESETTING → PLAYING — matches ADR-005)
# ═══════════════════════════════════════════════════════════════════════════════

func _session_reset() -> void:
	_hero_pos      = Vector2(270.0, 820.0)
	_facing_angle  = -PI / 2.0
	_gold          = STARTING_GOLD
	_archer_count  = STARTING_ARCHERS
	_castle_hp     = CASTLE_MAX_HP
	_current_wave  = 0
	_wave_active   = false
	_dwell_timer   = 0.0
	_in_zone       = false
	_can_restart   = false
	_restart_timer = 0.0

	_enemies.clear()
	_projs.clear()
	_gold_coins.clear()

	# Rebuild archer slots
	_archer_slots.clear()
	for i in MAX_ARCHERS:
		_archer_slots.append({
			"pos":      _hero_pos + FORMATION[i],
			"shoot_cd": float(i) * SHOOT_STAGGER,
			"active":   i < STARTING_ARCHERS,
		})

	_lbl_hint.visible = true
	_lbl_status.text = ""
	_update_hud()
	_state = State.PLAYING
	_start_next_wave()

# ═══════════════════════════════════════════════════════════════════════════════
# WAVE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func _start_next_wave() -> void:
	_current_wave += 1
	_wave_active = true
	# Spawn count: GDD formula 5 + floor(wave × 1.15), capped for VS pacing
	var count: int = mini(5 + int(floor(float(_current_wave) * 1.15)), 14)
	for _i in count:
		_spawn_enemy(_current_wave)
	_update_hud()


func _spawn_enemy(wave: int) -> void:
	var hp: int = ENEMY_HP_BASE + (wave - 1) * ENEMY_HP_SCALE
	# Spawn near bottom of viewport, spread horizontally
	var sx: float = randf_range(ENEMY_RADIUS + 10.0, VP.x - ENEMY_RADIUS - 10.0)
	var sy: float = randf_range(VP.y * 0.7, VP.y - ENEMY_RADIUS - 5.0)
	_enemies.append({
		"pos":    Vector2(sx, sy),
		"hp":     hp,
		"max_hp": hp,
	})


func _check_wave_complete() -> void:
	if _wave_active and _enemies.is_empty() and _state == State.PLAYING:
		_wave_active = false
		_wave_clear_timer = WAVE_CLEAR_PAUSE
		_lbl_status.text = "Wave %d  Clear!" % _current_wave
		_state = State.WAVE_CLEAR

# ═══════════════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Joystick: bottom half only
			if not _joy_active and touch.position.y > VP.y * 0.5:
				_joy_active    = true
				_joy_touch_idx = touch.index
				_joy_knob      = touch.position
				_joy_output    = Vector2.ZERO
			# Restart tap in GAME_OVER
			if _can_restart and _state == State.GAME_OVER:
				_state = State.RESETTING
		elif not touch.pressed and touch.index == _joy_touch_idx:
			_joy_active = false
			_joy_output = Vector2.ZERO

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_touch_idx:
			_joy_knob = drag.position
			var dv: Vector2 = drag.position - JOY_ANCHOR
			if dv.length() < JOY_DEAD_ZONE:
				_joy_output = Vector2.ZERO
			else:
				_joy_output = dv.limit_length(JOY_RADIUS) / JOY_RADIUS

	elif event is InputEventKey:
		var key := event as InputEventKey
		# Keyboard restart (desktop testing)
		if key.pressed and key.keycode == KEY_R and _can_restart and _state == State.GAME_OVER:
			_state = State.RESETTING

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	match _state:
		State.PLAYING:
			_update_hero(delta)
			_update_archers(delta)
			_update_enemies(delta)
			_update_projectiles(delta)
			_update_gold(delta)
			_update_economy(delta)
			_check_wave_complete()

		State.WAVE_CLEAR:
			# Hero/economy still active during inter-wave pause (intentional — buy archers now!)
			_update_hero(delta)
			_update_archers(delta)
			_update_gold(delta)
			_update_economy(delta)
			_wave_clear_timer -= delta
			var secs: int = ceili(_wave_clear_timer)
			_lbl_status.text = "Wave %d  Clear!  Next in %ds" % [_current_wave, secs]
			if _wave_clear_timer <= 0.0:
				_lbl_status.text = ""
				_start_next_wave()
				_state = State.PLAYING

		State.GAME_OVER:
			_restart_timer += delta
			if _restart_timer >= 1.5:
				_can_restart = true
				_lbl_status.text = "Castle Fell — Wave %d\n\nTap to Restart" % _current_wave

		State.RESETTING:
			_session_reset()   # Runs once: sets state → PLAYING

	queue_redraw()

# ═══════════════════════════════════════════════════════════════════════════════
# HERO UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_hero(delta: float) -> void:
	var dir: Vector2 = _joy_output
	# Keyboard fallback for desktop testing
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	_hero_pos += dir * HERO_SPEED * delta
	# Clamp: prevent hero from entering HUD strip at top (y < 56 + radius)
	_hero_pos = _hero_pos.clamp(
		Vector2(HERO_RADIUS, 56.0 + HERO_RADIUS),
		VP - Vector2(HERO_RADIUS, HERO_RADIUS)
	)

	if dir.length() > 0.1:
		_facing_angle = dir.angle()

# ═══════════════════════════════════════════════════════════════════════════════
# ARCHER FORMATION UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_archers(delta: float) -> void:
	# Find nearest enemy within range (all archers share one target — GDD rule)
	var nearest: Dictionary = {}
	var best_dist: float    = ARCHER_RANGE
	for e in _enemies:
		var d: float = _hero_pos.distance_to(e["pos"])
		if d < best_dist:
			best_dist = d
			nearest   = e

	# Frame-rate-independent lerp weight (ADR-004 pattern)
	var lerp_w: float = 1.0 - pow(1.0 - ARCHER_LERP_F, delta * 60.0)

	for i in MAX_ARCHERS:
		var a: Dictionary = _archer_slots[i]
		if not a["active"]:
			continue

		# Rotate formation slot to sit BEHIND the hero facing direction
		var offset:   Vector2 = FORMATION[i].rotated(_facing_angle + PI / 2.0)
		var slot_pos: Vector2 = _hero_pos + offset
		a["pos"] = (a["pos"] as Vector2).lerp(slot_pos, lerp_w)

		# Shoot at nearest enemy when cooldown reaches zero
		a["shoot_cd"] = (a["shoot_cd"] as float) - delta
		if (a["shoot_cd"] as float) <= 0.0 and not nearest.is_empty():
			a["shoot_cd"] = SHOOT_IVTL
			_spawn_proj(a["pos"], nearest["pos"])

# ═══════════════════════════════════════════════════════════════════════════════
# ENEMY UPDATE  (enemies march toward CASTLE — not hero)
# ═══════════════════════════════════════════════════════════════════════════════

func _update_enemies(delta: float) -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		var e: Dictionary = _enemies[i]
		# Steer toward castle (ADR-006 pattern: direction_to × speed)
		var dir: Vector2 = (CASTLE_POS - (e["pos"] as Vector2)).normalized()
		e["pos"] = (e["pos"] as Vector2) + dir * ENEMY_SPEED * delta

		# Castle contact check
		if (e["pos"] as Vector2).distance_to(CASTLE_POS) < CASTLE_RADIUS + ENEMY_RADIUS:
			_castle_hp = max(0, _castle_hp - CASTLE_DMG)
			_enemies.remove_at(i)
			_update_hud()
			if _castle_hp <= 0:
				_trigger_game_over()
			continue


func _trigger_game_over() -> void:
	_state         = State.GAME_OVER
	_restart_timer = 0.0
	_can_restart   = false
	_lbl_hint.visible = false
	_lbl_status.text  = "Castle Fell — Wave %d" % _current_wave

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECTILE UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_projectiles(delta: float) -> void:
	for i in range(_projs.size() - 1, -1, -1):
		var p: Dictionary = _projs[i]
		p["pos"]  = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = (p["life"] as float) - delta

		if (p["life"] as float) <= 0.0:
			_projs.remove_at(i)
			continue

		# Hit the first enemy in range
		var hit := false
		for j in range(_enemies.size() - 1, -1, -1):
			var e: Dictionary = _enemies[j]
			if (p["pos"] as Vector2).distance_to(e["pos"]) < ENEMY_RADIUS + 5.0:
				e["hp"] = (e["hp"] as int) - 1
				if (e["hp"] as int) <= 0:
					# Enemy killed → drop gold
					var count: int = randi_range(GOLD_DROP_MIN, GOLD_DROP_MAX)
					for _k in count:
						var scatter := Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
						_gold_coins.append((e["pos"] as Vector2) + scatter)
					_enemies.remove_at(j)
				hit = true
				break

		if hit:
			_projs.remove_at(i)

# ═══════════════════════════════════════════════════════════════════════════════
# GOLD MAGNET UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_gold(delta: float) -> void:
	for i in range(_gold_coins.size() - 1, -1, -1):
		var coin_pos: Vector2 = _gold_coins[i]
		var dist: float = coin_pos.distance_to(_hero_pos)
		if dist < GOLD_MAGNET_R:
			var dir: Vector2 = (_hero_pos - coin_pos).normalized()
			_gold_coins[i] = coin_pos + dir * GOLD_SPEED * delta
			if _gold_coins[i].distance_to(_hero_pos) < GOLD_COLLECT_R:
				_gold_coins.remove_at(i)
				_gold += 1
				_update_hud()

# ═══════════════════════════════════════════════════════════════════════════════
# ECONOMY / DWELL ZONE UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_economy(delta: float) -> void:
	var dist: float = _hero_pos.distance_to(RECRUIT_ZONE_POS)
	if dist <= ZONE_RADIUS:
		_in_zone      = true
		_dwell_timer += delta
		if _dwell_timer >= DWELL_TIME:
			_attempt_recruit()
			_dwell_timer = 0.0   # reset — zone immediately re-available (GDD R9: no cooldown)
	else:
		_in_zone     = false
		_dwell_timer = 0.0       # no partial carry (GDD R7)


func _attempt_recruit() -> void:
	if _archer_count >= MAX_ARCHERS:
		return
	# Cost tier: T1 for archers 3+4, T2 for archers 5–8 (GDD economy.md R8)
	var cost: int = ARCHER_COST_T1 if _archer_count < 4 else ARCHER_COST_T2
	if _gold >= cost:
		_gold -= cost
		_archer_slots[_archer_count]["active"] = true
		_archer_count += 1
		_update_hud()

# ═══════════════════════════════════════════════════════════════════════════════
# HUD UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func _update_hud() -> void:
	_lbl_gold.text     = "Gold: %d" % _gold
	_lbl_archers.text  = "%d / %d" % [_archer_count, MAX_ARCHERS]
	_lbl_wave.text     = "Wave %d" % _current_wave

	# Castle HP bar
	var ratio: float = float(_castle_hp) / float(CASTLE_MAX_HP)
	_hp_bar_fill.size.x = 188.0 * ratio
	if ratio > 0.5:
		_hp_bar_fill.color = Color(0.15, 0.82, 0.25)    # green
	elif ratio > 0.25:
		_hp_bar_fill.color = Color(0.88, 0.52, 0.06)    # amber
	else:
		_hp_bar_fill.color = Color(0.85, 0.1, 0.12)     # red

# ═══════════════════════════════════════════════════════════════════════════════
# SPAWN HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_proj(from: Vector2, toward: Vector2) -> void:
	var dir: Vector2 = toward - from
	if dir == Vector2.ZERO:
		return
	_projs.append({
		"pos":  from,
		"vel":  dir.normalized() * PROJ_SPEED,
		"life": PROJ_LIFETIME,
	})

# ═══════════════════════════════════════════════════════════════════════════════
# RENDERING
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	# Background — dark green field
	draw_rect(Rect2(Vector2.ZERO, VP), Color(0.06, 0.10, 0.06))

	# Subtle grid (depth/movement perception)
	var gc := Color(1.0, 1.0, 1.0, 0.032)
	for xi in range(0, int(VP.x) + 1, 80):
		draw_line(Vector2(float(xi), 0.0), Vector2(float(xi), VP.y), gc)
	for yi in range(0, int(VP.y) + 1, 80):
		draw_line(Vector2(0.0, float(yi)), Vector2(VP.x, float(yi)), gc)

	# ── Castle ──────────────────────────────────────────────────────────────
	var hp_ratio: float = float(_castle_hp) / float(CASTLE_MAX_HP)
	var castle_col: Color
	if hp_ratio > 0.5:
		castle_col = Color(0.52, 0.54, 0.64)
	elif hp_ratio > 0.25:
		castle_col = Color(0.62, 0.40, 0.12)
	else:
		castle_col = Color(0.72, 0.14, 0.14)
	draw_circle(CASTLE_POS, CASTLE_RADIUS, castle_col)
	draw_circle(CASTLE_POS, CASTLE_RADIUS * 0.55, castle_col.darkened(0.28))
	# Battlement bumps
	for b in 5:
		var ang: float = (float(b) / 5.0) * TAU
		draw_circle(CASTLE_POS + Vector2(cos(ang), sin(ang)) * CASTLE_RADIUS * 0.82, 6.0, castle_col.lightened(0.18))
	# Castle HP number (accessibility: not just color)
	draw_string(ThemeDB.fallback_font, CASTLE_POS + Vector2(-16.0, 7.0), str(_castle_hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# ── Recruit Zone ────────────────────────────────────────────────────────
	if _state == State.PLAYING or _state == State.WAVE_CLEAR:
		var can_afford: bool = (_gold >= _recruit_cost()) and (_archer_count < MAX_ARCHERS)
		var zone_alpha: float
		var zone_hue: Color
		if _in_zone:
			# Pulsing when inside
			zone_alpha = 0.50 + sin(Time.get_ticks_msec() * 0.012) * 0.12
			zone_hue   = Color(0.14, 0.95, 0.35, zone_alpha)
		elif can_afford:
			zone_alpha = 0.22 + sin(Time.get_ticks_msec() * 0.006) * 0.06
			zone_hue   = Color(0.14, 0.72, 0.28, zone_alpha)
		else:
			zone_hue   = Color(0.35, 0.35, 0.35, 0.16)

		draw_circle(RECRUIT_ZONE_POS, ZONE_RADIUS, zone_hue)
		draw_arc(RECRUIT_ZONE_POS, ZONE_RADIUS, 0.0, TAU, 32, zone_hue.lightened(0.25) * Color(1,1,1,2.0), 2.0)

		# Dwell fill arc (shows timer progress — clockwise from top)
		if _in_zone and _dwell_timer > 0.0:
			var fill: float = _dwell_timer / DWELL_TIME
			draw_arc(RECRUIT_ZONE_POS, ZONE_RADIUS - 5.0, -PI * 0.5, -PI * 0.5 + fill * TAU, 32,
					Color(0.25, 1.0, 0.5, 0.95), 5.0)

		# Zone label — cost and slot info
		var slot_str: String
		if _archer_count >= MAX_ARCHERS:
			slot_str = "FULL"
		else:
			slot_str = "%dg" % _recruit_cost()
		draw_string(ThemeDB.fallback_font,
				RECRUIT_ZONE_POS + Vector2(-20.0, ZONE_RADIUS + 18.0),
				"RECRUIT  " + slot_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.85, 1.0, 0.85, 0.85))

	# ── Gold Coins ───────────────────────────────────────────────────────────
	for g in _gold_coins:
		draw_circle(g, GOLD_RADIUS, Color.GOLD)
		draw_circle(g, GOLD_RADIUS * 0.42, Color(1.0, 1.0, 0.62))

	# ── Gold magnet radius ring (subtle) ─────────────────────────────────────
	draw_arc(_hero_pos, GOLD_MAGNET_R, 0.0, TAU, 48, Color(1.0, 0.85, 0.1, 0.055), 1.5)

	# ── Projectiles ──────────────────────────────────────────────────────────
	for p in _projs:
		draw_circle(p["pos"], 4.5, Color(1.0, 0.94, 0.48))

	# ── Enemies ──────────────────────────────────────────────────────────────
	for e in _enemies:
		var ehp_r: float = float(e["hp"]) / float(e["max_hp"])
		var ecol: Color  = Color(0.80, 0.10, 0.10).lerp(Color(0.28, 0.03, 0.03), 1.0 - ehp_r)
		draw_circle(e["pos"], ENEMY_RADIUS, ecol)
		# Direction indicator (enemies face the castle — small tick toward castle)
		var edir: Vector2 = (CASTLE_POS - (e["pos"] as Vector2)).normalized()
		draw_line(e["pos"], (e["pos"] as Vector2) + edir * (ENEMY_RADIUS + 5.0), Color(1.0, 0.3, 0.3, 0.7), 2.0)
		# HP bar
		var bw: float = ENEMY_RADIUS * 2.4
		var by: float = (e["pos"] as Vector2).y - ENEMY_RADIUS - 7.0
		var bx: float = (e["pos"] as Vector2).x - bw * 0.5
		draw_rect(Rect2(bx, by, bw, 4.0), Color(0.14, 0.0, 0.0))
		draw_rect(Rect2(bx, by, bw * ehp_r, 4.0), Color(0.10, 0.85, 0.22))

	# ── Archers ──────────────────────────────────────────────────────────────
	for i in MAX_ARCHERS:
		if not _archer_slots[i]["active"]:
			continue
		draw_circle(_archer_slots[i]["pos"], ARCHER_RADIUS, Color(0.18, 0.72, 0.28))
		draw_circle(_archer_slots[i]["pos"], 5.0, Color(0.06, 0.34, 0.12))

	# ── Hero ─────────────────────────────────────────────────────────────────
	draw_circle(_hero_pos, HERO_RADIUS, Color(0.92, 0.76, 0.12))        # gold
	draw_circle(_hero_pos, HERO_RADIUS * 0.44, Color(0.46, 0.36, 0.04)) # inner darker
	# Facing arrow
	var tip: Vector2 = _hero_pos + Vector2(cos(_facing_angle), sin(_facing_angle)) * (HERO_RADIUS + 12.0)
	draw_line(_hero_pos, tip, Color.WHITE, 2.5)

	# ── Virtual Joystick ──────────────────────────────────────────────────────
	var ja: float = 0.38 if _joy_active else 0.12
	draw_arc(JOY_ANCHOR, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, ja), 2.0)
	draw_circle(JOY_ANCHOR, 9.0, Color(1.0, 1.0, 1.0, ja))
	if _joy_active:
		var koff: Vector2 = (_joy_knob - JOY_ANCHOR).limit_length(JOY_RADIUS)
		draw_circle(JOY_ANCHOR + koff, 28.0, Color(1.0, 1.0, 1.0, 0.42))

	# ── GAME OVER overlay ────────────────────────────────────────────────────
	if _state == State.GAME_OVER:
		draw_rect(Rect2(Vector2.ZERO, VP), Color(0.0, 0.0, 0.0, 0.52))

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _recruit_cost() -> int:
	return ARCHER_COST_T1 if _archer_count < 4 else ARCHER_COST_T2
