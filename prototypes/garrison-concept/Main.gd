# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does joystick + archer V-formation feel like commanding an army?
# Date: 2026-05-17
# Verdict criteria: Player voluntarily changes movement path to position archers tactically.

extends Node2D

# ═══════════════════════════ TUNING ════════════════════════════════════════
const VIEWPORT      := Vector2(540.0, 960.0)

const HERO_SPEED    := 200.0
const HERO_RADIUS   := 18.0

const ARCHER_RADIUS := 12.0
const ARCHER_RANGE  := 340.0
const SHOOT_IVTL    := 0.8      # seconds between shots per archer

const ENEMY_RADIUS  := 16.0
const ENEMY_SPEED   := 75.0
const ENEMY_HP      := 3
const SPAWN_IVTL    := 2.2      # seconds between enemy spawns
const MAX_ENEMIES   := 18

const PROJ_SPEED    := 420.0
const PROJ_LIFETIME := 1.8

const MAGNET_R      := 170.0    # gold attraction radius
const GOLD_SPEED    := 280.0
const GOLD_RADIUS   := 10.0
const COLLECT_R     := 24.0

const JOY_RADIUS    := 80.0
const JOY_DEAD_ZONE := 15.0
const JOY_ANCHOR    := Vector2(135.0, 800.0)   # Fixed bottom-left position

# V-formation offsets relative to hero.
# Y+ = below in screen space. Formation is rotated to face "behind" the hero.
const FORMATION: Array[Vector2] = [
	Vector2(-45.0,  58.0), Vector2(45.0,  58.0),
	Vector2(-82.0, 104.0), Vector2(0.0,  96.0), Vector2(82.0, 104.0),
	Vector2(-118.0,150.0), Vector2(0.0, 142.0), Vector2(118.0,150.0),
]

# ═══════════════════════════ STATE ═════════════════════════════════════════

var _hero_pos:     Vector2 = VIEWPORT / 2.0
var _facing_angle: float   = PI / 2.0      # Start facing down

# {pos: Vector2, shoot_cd: float}
var _archers: Array[Dictionary] = []

# {pos: Vector2, hp: int}
var _enemies: Array[Dictionary] = []

# {pos: Vector2, vel: Vector2, life: float}
var _projs: Array[Dictionary] = []

# Gold coin world positions
var _gold: Array[Vector2] = []
var _gold_count: int = 0

var _spawn_cd: float = 0.8          # First enemy arrives soon

# ── Joystick ──────────────────────────────────────────────────────────────
var _joy_active:    bool    = false
var _joy_touch_idx: int     = -1
var _joy_anchor:    Vector2 = Vector2.ZERO
var _joy_knob:      Vector2 = Vector2.ZERO
var _joy_output:    Vector2 = Vector2.ZERO

# ── UI ────────────────────────────────────────────────────────────────────
var _gold_label: Label

# ═══════════════════════════ INIT ══════════════════════════════════════════

func _ready() -> void:
	_init_archers()
	_init_ui()

func _init_archers() -> void:
	for i in 8:
		_archers.append({
			"pos":      _hero_pos + FORMATION[i],
			"shoot_cd": float(i) * (SHOOT_IVTL / 8.0),  # stagger shots
		})

func _init_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_gold_label = Label.new()
	_gold_label.position = Vector2(16.0, 16.0)
	_gold_label.add_theme_font_size_override("font_size", 36)
	_gold_label.text = "Gold: 0"
	layer.add_child(_gold_label)

	var hint := Label.new()
	hint.position = Vector2(16.0, VIEWPORT.y - 52.0)
	hint.add_theme_font_size_override("font_size", 22)
	hint.text = "Touch anywhere to move   (WASD on PC)"
	hint.modulate = Color(1.0, 1.0, 1.0, 0.45)
	layer.add_child(hint)

# ═══════════════════════════ INPUT ═════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _joy_active and touch.position.y > VIEWPORT.y * 0.5:
			_joy_active    = true
			_joy_touch_idx = touch.index
			_joy_anchor    = JOY_ANCHOR        # Fixed anchor — never moves
			_joy_knob      = touch.position
			_joy_output    = Vector2.ZERO
		elif not touch.pressed and touch.index == _joy_touch_idx:
			_joy_active = false
			_joy_output = Vector2.ZERO

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_touch_idx:
			_joy_knob = drag.position
			var delta_v: Vector2 = drag.position - _joy_anchor
			if delta_v.length() < JOY_DEAD_ZONE:
				_joy_output = Vector2.ZERO
			else:
				_joy_output = delta_v.limit_length(JOY_RADIUS) / JOY_RADIUS

# ═══════════════════════════ UPDATE ════════════════════════════════════════

func _process(delta: float) -> void:
	_update_hero(delta)
	_update_archers(delta)
	_update_enemies(delta)
	_update_projectiles(delta)
	_update_gold(delta)
	_update_spawner(delta)
	queue_redraw()

# ── Hero ──────────────────────────────────────────────────────────────────

func _update_hero(delta: float) -> void:
	var dir: Vector2 = _joy_output
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	_hero_pos += dir * HERO_SPEED * delta
	_hero_pos = _hero_pos.clamp(
		Vector2(HERO_RADIUS, HERO_RADIUS),
		VIEWPORT - Vector2(HERO_RADIUS, HERO_RADIUS)
	)

	if dir.length() > 0.1:
		_facing_angle = dir.angle()

# ── Archers ───────────────────────────────────────────────────────────────

func _update_archers(delta: float) -> void:
	# Find the single nearest enemy in range (all archers share one target).
	var nearest: Dictionary = {}
	var best_dist: float = ARCHER_RANGE
	for e in _enemies:
		var d: float = _hero_pos.distance_to(e["pos"])
		if d < best_dist:
			best_dist = d
			nearest = e

	for i in _archers.size():
		var archer: Dictionary = _archers[i]

		# Rotate the formation slot to sit behind the hero's facing direction.
		# facing_angle + PI/2 places the formation Y+ axis "behind" the hero.
		var offset: Vector2 = FORMATION[i].rotated(_facing_angle + PI / 2.0)
		var slot_pos: Vector2 = _hero_pos + offset

		# Smooth pursuit toward the formation slot (lerp is frame-rate dependent
		# but acceptable for a throwaway prototype).
		archer["pos"] = (archer["pos"] as Vector2).lerp(slot_pos, 0.12)

		# Shoot at the nearest enemy.
		archer["shoot_cd"] = (archer["shoot_cd"] as float) - delta
		if (archer["shoot_cd"] as float) <= 0.0 and not nearest.is_empty():
			archer["shoot_cd"] = SHOOT_IVTL
			_spawn_projectile(archer["pos"], nearest["pos"])

# ── Enemies ───────────────────────────────────────────────────────────────

func _update_enemies(delta: float) -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		var e: Dictionary = _enemies[i]
		var dir: Vector2 = (_hero_pos - (e["pos"] as Vector2)).normalized()
		e["pos"] = (e["pos"] as Vector2) + dir * ENEMY_SPEED * delta

		if (e["pos"] as Vector2).distance_to(_hero_pos) < HERO_RADIUS + ENEMY_RADIUS:
			# Enemy reaches hero — drop gold and despawn (no HP in prototype).
			_gold.append(e["pos"])
			_enemies.remove_at(i)

# ── Projectiles ───────────────────────────────────────────────────────────

func _update_projectiles(delta: float) -> void:
	for i in range(_projs.size() - 1, -1, -1):
		var p: Dictionary = _projs[i]
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = (p["life"] as float) - delta

		if (p["life"] as float) <= 0.0:
			_projs.remove_at(i)
			continue

		# Check collision with any enemy.
		var hit := false
		for j in range(_enemies.size() - 1, -1, -1):
			var e: Dictionary = _enemies[j]
			if (p["pos"] as Vector2).distance_to(e["pos"]) < ENEMY_RADIUS + 6.0:
				e["hp"] = (e["hp"] as int) - 1
				if (e["hp"] as int) <= 0:
					_gold.append(e["pos"])
					_enemies.remove_at(j)
				hit = true
				break

		if hit:
			_projs.remove_at(i)

# ── Gold ──────────────────────────────────────────────────────────────────

func _update_gold(delta: float) -> void:
	for i in range(_gold.size() - 1, -1, -1):
		var dist: float = (_gold[i] as Vector2).distance_to(_hero_pos)
		if dist < MAGNET_R:
			var dir: Vector2 = (_hero_pos - (_gold[i] as Vector2)).normalized()
			_gold[i] = (_gold[i] as Vector2) + dir * GOLD_SPEED * delta
			if dist < COLLECT_R:
				_gold.remove_at(i)
				_gold_count += 1
				_gold_label.text = "Gold: " + str(_gold_count)

# ── Spawner ───────────────────────────────────────────────────────────────

func _update_spawner(delta: float) -> void:
	if _enemies.size() >= MAX_ENEMIES:
		return
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = SPAWN_IVTL
		_spawn_enemy()

# ═══════════════════════════ SPAWN ═════════════════════════════════════════

func _spawn_enemy() -> void:
	var pos: Vector2
	match randi() % 4:
		0: pos = Vector2(randf() * VIEWPORT.x, -ENEMY_RADIUS)
		1: pos = Vector2(randf() * VIEWPORT.x, VIEWPORT.y + ENEMY_RADIUS)
		2: pos = Vector2(-ENEMY_RADIUS, randf() * VIEWPORT.y)
		3: pos = Vector2(VIEWPORT.x + ENEMY_RADIUS, randf() * VIEWPORT.y)
	_enemies.append({"pos": pos, "hp": ENEMY_HP})

func _spawn_projectile(from: Vector2, toward: Vector2) -> void:
	var dir: Vector2 = (toward - from)
	if dir == Vector2.ZERO:
		return
	_projs.append({
		"pos":  from,
		"vel":  dir.normalized() * PROJ_SPEED,
		"life": PROJ_LIFETIME,
	})

# ═══════════════════════════ DRAW ══════════════════════════════════════════

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT), Color(0.07, 0.09, 0.07))

	# Subtle grid — helps perceive movement
	var grid_col := Color(1.0, 1.0, 1.0, 0.04)
	var x: float = 0.0
	while x <= VIEWPORT.x:
		draw_line(Vector2(x, 0.0), Vector2(x, VIEWPORT.y), grid_col, 1.0)
		x += 80.0
	var y: float = 0.0
	while y <= VIEWPORT.y:
		draw_line(Vector2(0.0, y), Vector2(VIEWPORT.x, y), grid_col, 1.0)
		y += 80.0

	# Gold magnet radius ring
	draw_arc(_hero_pos, MAGNET_R, 0.0, TAU, 48, Color(1.0, 0.9, 0.1, 0.07), 1.5)

	# Gold coins
	for g in _gold:
		draw_circle(g, GOLD_RADIUS, Color.GOLD)
		draw_circle(g, GOLD_RADIUS * 0.45, Color(1.0, 1.0, 0.5))

	# Projectiles (small bright dot)
	for p in _projs:
		draw_circle(p["pos"], 5.0, Color(1.0, 0.95, 0.5))

	# Enemies
	for e in _enemies:
		var hp_ratio: float = float(e["hp"]) / float(ENEMY_HP)
		var col: Color = Color(0.85, 0.1, 0.1).lerp(Color(0.35, 0.04, 0.04), 1.0 - hp_ratio)
		draw_circle(e["pos"], ENEMY_RADIUS, col)
		# HP bar above enemy
		var bar_w: float = ENEMY_RADIUS * 2.4
		var bar_y: float = (e["pos"] as Vector2).y - ENEMY_RADIUS - 7.0
		draw_rect(Rect2((e["pos"] as Vector2).x - bar_w * 0.5, bar_y, bar_w, 4.0), Color(0.2, 0.0, 0.0))
		draw_rect(Rect2((e["pos"] as Vector2).x - bar_w * 0.5, bar_y, bar_w * hp_ratio, 4.0), Color(0.1, 0.9, 0.2))

	# Archers (green dots in V-formation)
	for a in _archers:
		draw_circle(a["pos"], ARCHER_RADIUS, Color(0.15, 0.75, 0.25))
		draw_circle(a["pos"], 5.0, Color(0.05, 0.38, 0.12))

	# Hero
	draw_circle(_hero_pos, HERO_RADIUS, Color(0.2, 0.8, 1.0))
	draw_circle(_hero_pos, HERO_RADIUS * 0.42, Color(0.04, 0.28, 0.48))
	# Direction arrow
	var arrow_tip: Vector2 = _hero_pos + Vector2(cos(_facing_angle), sin(_facing_angle)) * (HERO_RADIUS + 11.0)
	draw_line(_hero_pos, arrow_tip, Color.WHITE, 2.5)

	# Virtual joystick — anchor always visible at fixed position
	var joy_alpha: float = 0.35 if _joy_active else 0.12
	draw_arc(JOY_ANCHOR, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, joy_alpha), 2.0)
	draw_circle(JOY_ANCHOR, 8.0, Color(1.0, 1.0, 1.0, joy_alpha))
	if _joy_active:
		var knob_off: Vector2 = (_joy_knob - JOY_ANCHOR).limit_length(JOY_RADIUS)
		draw_circle(JOY_ANCHOR + knob_off, 30.0, Color(1.0, 1.0, 1.0, 0.45))
