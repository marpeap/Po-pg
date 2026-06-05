# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the dwell trigger (0.8s) + spatial recruit zone create genuine
#           decisional tension when the player must choose between combat and economy?
# Date: 2026-05-17

extends Node2D

# ---------------------------------------------------------------------------
# World / Viewport
# ---------------------------------------------------------------------------
const VIEWPORT   := Vector2(540.0, 960.0)
const WORLD_SIZE := Vector2(1080.0, 1920.0)

# ---------------------------------------------------------------------------
# Castle
# ---------------------------------------------------------------------------
const CASTLE_POS    := Vector2(540.0, 120.0)  # world space, top-center
const CASTLE_SIZE   := Vector2(80.0, 60.0)
const CASTLE_MAX_HP := 200
const CASTLE_DMG    := 8                       # HP lost per enemy contact

# ---------------------------------------------------------------------------
# Hero
# ---------------------------------------------------------------------------
const HERO_RADIUS := 18.0
const HERO_SPEED  := 200.0
const JOY_ANCHOR  := Vector2(135.0, 800.0)
const JOY_RADIUS  := 80.0

# ---------------------------------------------------------------------------
# Archers
# ---------------------------------------------------------------------------
const ARCHER_RADIUS := 10.0
const SHOOT_IVTL    := 0.9    # seconds between global shoot pulses
const PROJ_SPEED    := 400.0
const PROJ_RADIUS   := 5.0
const PROJ_DMG      := 10

# V-formation offsets (slot 0 and 1 used at start; up to 8)
const FORMATION: Array[Vector2] = [
	Vector2(-28.0,  40.0),
	Vector2( 28.0,  40.0),
	Vector2(-56.0,  75.0),
	Vector2( 56.0,  75.0),
	Vector2(-84.0, 110.0),
	Vector2( 84.0, 110.0),
	Vector2(-40.0, 145.0),
	Vector2( 40.0, 145.0),
]
const ARCHER_MAX := 8

# ---------------------------------------------------------------------------
# Recruit Zone
# ---------------------------------------------------------------------------
const ZONE_POS    := Vector2(810.0, 1400.0)  # world space
const ZONE_RADIUS := 60.0
const ZONE_DWELL  := 0.8                     # seconds to trigger purchase
const ARCHER_COST := 30

# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------
const ENEMY_RADIUS  := 14.0
const ENEMY_SPEED   := 70.0
const ENEMY_MAX_HP  := 30
const GOLD_DROP     := 15
const SPAWN_IVTL    := 2.0
const MAX_ENEMIES   := 20

# ---------------------------------------------------------------------------
# Gold
# ---------------------------------------------------------------------------
const GOLD_RADIUS := 7.0
const MAGNET_R    := 170.0
const MAGNET_SPD  := 350.0

# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
const CAM_LERP := 0.10

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _hero_pos: Vector2 = Vector2(540.0, 1700.0)
var _facing_angle: float = 0.0
var _camera_pos: Vector2

var _joy_active: bool = false
var _joy_touch_id: int = -1
var _joy_dir: Vector2 = Vector2.ZERO

var _archers:     Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _enemies:     Array[Dictionary] = []
var _gold_coins:  Array[Vector2]    = []

var _shoot_timer: float = 0.0
var _spawn_timer: float = 0.0
var _gold:        int   = 60     # start with enough for 2 recruits
var _castle_hp:   int   = CASTLE_MAX_HP

var _zone_dwell_timer: float = 0.0
var _in_zone:          bool  = false
var _game_over:        bool  = false

var _font: Font

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	_camera_pos = _hero_pos
	_font = ThemeDB.fallback_font

	# 2 initial archers
	for i in 2:
		_archers.append({
			"pos": _hero_pos + FORMATION[i],
			"shoot_cd": randf() * SHOOT_IVTL,
		})


# ---------------------------------------------------------------------------
# World → screen
# ---------------------------------------------------------------------------
func _w2s(world_pos: Vector2) -> Vector2:
	return world_pos - _camera_pos + VIEWPORT / 2.0


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _game_over:
		return

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.y > VIEWPORT.y * 0.5 and not _joy_active:
				_joy_active    = true
				_joy_touch_id  = t.index
		else:
			if t.index == _joy_touch_id:
				_joy_active   = false
				_joy_touch_id = -1
				_joy_dir      = Vector2.ZERO

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_touch_id:
			var raw := d.position - JOY_ANCHOR
			if raw.length() > JOY_RADIUS:
				raw = raw.normalized() * JOY_RADIUS
			_joy_dir = raw / JOY_RADIUS


# ---------------------------------------------------------------------------
# _process
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _game_over:
		return

	_update_hero(delta)
	_update_camera()
	_update_archers(delta)
	_update_shoot(delta)
	_update_projectiles(delta)
	_update_enemies(delta)
	_update_gold(delta)
	_update_zone(delta)
	queue_redraw()


# ---------------------------------------------------------------------------
# Hero
# ---------------------------------------------------------------------------
func _update_hero(delta: float) -> void:
	var vel := Vector2.ZERO
	if _joy_active and _joy_dir.length() > 0.05:
		vel = _joy_dir * HERO_SPEED
		_facing_angle = _joy_dir.angle()
	_hero_pos += vel * delta
	_hero_pos.x = clampf(_hero_pos.x, HERO_RADIUS, WORLD_SIZE.x - HERO_RADIUS)
	_hero_pos.y = clampf(_hero_pos.y, HERO_RADIUS, WORLD_SIZE.y - HERO_RADIUS)


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------
func _update_camera() -> void:
	_camera_pos = _camera_pos.lerp(_hero_pos, CAM_LERP)
	var half := VIEWPORT / 2.0
	_camera_pos.x = clampf(_camera_pos.x, half.x, WORLD_SIZE.x - half.x)
	_camera_pos.y = clampf(_camera_pos.y, half.y, WORLD_SIZE.y - half.y)


# ---------------------------------------------------------------------------
# Archers: follow hero in V-formation
# ---------------------------------------------------------------------------
func _update_archers(delta: float) -> void:
	for i in _archers.size():
		var slot_pos := _hero_pos + FORMATION[i].rotated(_facing_angle + PI / 2.0)
		_archers[i]["pos"] = (_archers[i]["pos"] as Vector2).lerp(slot_pos, 0.12)
		_archers[i]["shoot_cd"] = (_archers[i]["shoot_cd"] as float) - delta


# ---------------------------------------------------------------------------
# Shoot: each archer fires at nearest enemy on a shared timer
# ---------------------------------------------------------------------------
func _update_shoot(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer > 0.0 or _enemies.is_empty():
		return
	_shoot_timer = SHOOT_IVTL

	for archer in _archers:
		var apos: Vector2 = archer["pos"]
		var best_idx := -1
		var best_dist := INF
		for j in _enemies.size():
			var d: float = apos.distance_to(_enemies[j]["pos"])
			if d < best_dist:
				best_dist = d
				best_idx  = j
		if best_idx < 0:
			continue
		var dir := apos.direction_to(_enemies[best_idx]["pos"])
		_projectiles.append({"pos": apos, "vel": dir * PROJ_SPEED})


# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------
func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var new_pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		_projectiles[i]["pos"] = new_pos

		# Out of world
		if new_pos.x < 0 or new_pos.x > WORLD_SIZE.x or \
		   new_pos.y < 0 or new_pos.y > WORLD_SIZE.y:
			_projectiles.remove_at(i)
			continue

		# Hit check
		var hit := false
		for j in range(_enemies.size() - 1, -1, -1):
			if new_pos.distance_to(_enemies[j]["pos"]) < PROJ_RADIUS + ENEMY_RADIUS:
				_enemies[j]["hp"] = (_enemies[j]["hp"] as int) - PROJ_DMG
				if (_enemies[j]["hp"] as int) <= 0:
					_gold_coins.append(_enemies[j]["pos"])
					_enemies.remove_at(j)
				hit = true
				break
		if hit:
			_projectiles.remove_at(i)


# ---------------------------------------------------------------------------
# Enemies: spawn + move toward castle
# ---------------------------------------------------------------------------
func _update_enemies(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _enemies.size() < MAX_ENEMIES:
		_spawn_timer = SPAWN_IVTL
		_spawn_enemy()

	var castle_rect := Rect2(CASTLE_POS - CASTLE_SIZE / 2.0, CASTLE_SIZE)

	for i in range(_enemies.size() - 1, -1, -1):
		var e: Dictionary    = _enemies[i]
		var epos: Vector2    = e["pos"]
		epos += epos.direction_to(CASTLE_POS) * ENEMY_SPEED * delta
		_enemies[i]["pos"]   = epos

		if castle_rect.has_point(epos):
			_castle_hp -= CASTLE_DMG
			_gold_coins.append(epos)
			_enemies.remove_at(i)
			if _castle_hp <= 0:
				_castle_hp  = 0
				_game_over  = true
				queue_redraw()
				return


func _spawn_enemy() -> void:
	var pos: Vector2
	match randi() % 4:
		0: pos = Vector2(randf_range(0.0, WORLD_SIZE.x), 0.0)
		1: pos = Vector2(randf_range(0.0, WORLD_SIZE.x), WORLD_SIZE.y)
		2: pos = Vector2(0.0, randf_range(0.0, WORLD_SIZE.y))
		_: pos = Vector2(WORLD_SIZE.x, randf_range(0.0, WORLD_SIZE.y))
	_enemies.append({"pos": pos, "hp": ENEMY_MAX_HP})


# ---------------------------------------------------------------------------
# Gold magnet
# ---------------------------------------------------------------------------
func _update_gold(delta: float) -> void:
	for i in range(_gold_coins.size() - 1, -1, -1):
		var gpos: Vector2 = _gold_coins[i]
		var dist: float   = gpos.distance_to(_hero_pos)
		if dist < MAGNET_R:
			if dist < HERO_RADIUS + GOLD_RADIUS:
				_gold += GOLD_DROP
				_gold_coins.remove_at(i)
			else:
				_gold_coins[i] = gpos.move_toward(_hero_pos, MAGNET_SPD * delta)


# ---------------------------------------------------------------------------
# Dwell zone
# ---------------------------------------------------------------------------
func _update_zone(delta: float) -> void:
	_in_zone = _hero_pos.distance_to(ZONE_POS) < ZONE_RADIUS
	if _in_zone:
		_zone_dwell_timer += delta
		if _zone_dwell_timer >= ZONE_DWELL \
				and _gold >= ARCHER_COST \
				and _archers.size() < ARCHER_MAX:
			_gold -= ARCHER_COST
			_archers.append({"pos": ZONE_POS, "shoot_cd": randf() * SHOOT_IVTL})
			_zone_dwell_timer = 0.0
	else:
		_zone_dwell_timer = 0.0


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT), Color(0.08, 0.08, 0.12))

	_draw_grid()
	_draw_castle()
	_draw_zone()
	_draw_gold_coins()
	_draw_projectiles()
	_draw_enemies()
	_draw_archers()
	_draw_hero()
	_draw_joystick()
	_draw_hud()

	if _game_over:
		draw_rect(Rect2(Vector2.ZERO, VIEWPORT), Color(0.0, 0.0, 0.0, 0.6))
		_txt(VIEWPORT / 2.0 + Vector2(0.0, -20.0), "GAME OVER", Color(0.9, 0.2, 0.2), 28, true)
		_txt(VIEWPORT / 2.0 + Vector2(0.0, 20.0), "Le chateau est tombe", Color.WHITE, 18, true)


func _draw_grid() -> void:
	var grid    := 120
	var col     := Color(0.15, 0.15, 0.2, 0.35)
	var off     := _camera_pos - VIEWPORT / 2.0
	var start_x := int(off.x / grid) * grid
	var start_y := int(off.y / grid) * grid
	for gx in range(start_x, int(off.x + VIEWPORT.x) + grid, grid):
		var sx := float(gx) - off.x
		draw_line(Vector2(sx, 0.0), Vector2(sx, VIEWPORT.y), col, 1.0)
	for gy in range(start_y, int(off.y + VIEWPORT.y) + grid, grid):
		var sy := float(gy) - off.y
		draw_line(Vector2(0.0, sy), Vector2(VIEWPORT.x, sy), col, 1.0)


func _draw_castle() -> void:
	var cs := _w2s(CASTLE_POS)
	var visible := Rect2(Vector2.ZERO, VIEWPORT).grow(CASTLE_SIZE.x).has_point(cs)
	if visible:
		draw_rect(Rect2(cs - CASTLE_SIZE / 2.0, CASTLE_SIZE), Color(0.65, 0.55, 0.2))
		# HP bar
		var bw    := CASTLE_SIZE.x
		var ratio := float(_castle_hp) / float(CASTLE_MAX_HP)
		draw_rect(Rect2(cs + Vector2(-bw / 2.0, -42.0), Vector2(bw, 8.0)), Color(0.2, 0.1, 0.1))
		draw_rect(Rect2(cs + Vector2(-bw / 2.0, -42.0), Vector2(bw * ratio, 8.0)), Color(0.9, 0.2, 0.2))
		_txt(cs + Vector2(0.0, -54.0), "Chateau  %d/%d" % [_castle_hp, CASTLE_MAX_HP], Color.WHITE, 14, true)
	else:
		_draw_offscreen_arrow(cs, Color(0.9, 0.8, 0.2), "Chateau")


func _draw_zone() -> void:
	var zs      := _w2s(ZONE_POS)
	var visible := Rect2(Vector2.ZERO, VIEWPORT).grow(ZONE_RADIUS + 10.0).has_point(zs)
	if visible:
		var can_afford := _gold >= ARCHER_COST and _archers.size() < ARCHER_MAX
		var fill_col   := Color(0.2, 1.0, 0.3, 0.18) if can_afford else Color(0.5, 0.5, 0.5, 0.15)
		draw_circle(zs, ZONE_RADIUS, fill_col)
		draw_arc(zs, ZONE_RADIUS, 0.0, TAU, 48, Color(0.4, 0.85, 0.4), 2.0)

		# Dwell progress arc
		if _in_zone and _zone_dwell_timer > 0.0:
			var progress := minf(_zone_dwell_timer / ZONE_DWELL, 1.0)
			var arc_col  := Color(0.2, 1.0, 0.3) if can_afford else Color(0.9, 0.3, 0.2)
			draw_arc(zs, ZONE_RADIUS + 7.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, arc_col, 5.0)

		var label_col := Color(0.2, 1.0, 0.3) if can_afford else Color(0.6, 0.6, 0.6)
		_txt(zs + Vector2(0.0, ZONE_RADIUS + 18.0), "%dg — Archer" % ARCHER_COST, label_col, 15, true)
		_txt(zs + Vector2(0.0, ZONE_RADIUS + 36.0), "%d / %d" % [_archers.size(), ARCHER_MAX], Color(0.55, 0.55, 0.55), 13, true)
	else:
		_draw_offscreen_arrow(zs, Color(0.2, 1.0, 0.3), "%dg" % ARCHER_COST)


func _draw_gold_coins() -> void:
	var vp_grow := Rect2(Vector2.ZERO, VIEWPORT).grow(20.0)
	for gpos in _gold_coins:
		var gs := _w2s(gpos)
		if vp_grow.has_point(gs):
			draw_circle(gs, GOLD_RADIUS, Color(1.0, 0.85, 0.1))


func _draw_projectiles() -> void:
	var vp_grow := Rect2(Vector2.ZERO, VIEWPORT).grow(10.0)
	for p in _projectiles:
		var ps := _w2s(p["pos"])
		if vp_grow.has_point(ps):
			draw_circle(ps, PROJ_RADIUS, Color(1.0, 0.95, 0.3))


func _draw_enemies() -> void:
	var vp_grow := Rect2(Vector2.ZERO, VIEWPORT).grow(20.0)
	for e in _enemies:
		var es := _w2s(e["pos"])
		if vp_grow.has_point(es):
			draw_circle(es, ENEMY_RADIUS, Color(0.85, 0.2, 0.2))
			var ratio: float = float(e["hp"]) / float(ENEMY_MAX_HP)
			draw_rect(Rect2(es + Vector2(-ENEMY_RADIUS, -ENEMY_RADIUS - 8.0), Vector2(ENEMY_RADIUS * 2.0, 4.0)), Color(0.2, 0.1, 0.1))
			draw_rect(Rect2(es + Vector2(-ENEMY_RADIUS, -ENEMY_RADIUS - 8.0), Vector2(ENEMY_RADIUS * 2.0 * ratio, 4.0)), Color(0.9, 0.3, 0.3))


func _draw_archers() -> void:
	var vp_grow := Rect2(Vector2.ZERO, VIEWPORT).grow(20.0)
	for archer in _archers:
		var as_ := _w2s(archer["pos"])
		if vp_grow.has_point(as_):
			draw_circle(as_, ARCHER_RADIUS, Color(0.3, 0.6, 1.0))


func _draw_hero() -> void:
	var hs := _w2s(_hero_pos)
	draw_arc(hs, MAGNET_R, 0.0, TAU, 64, Color(1.0, 0.85, 0.1, 0.12), 1.0)
	draw_circle(hs, HERO_RADIUS, Color(0.2, 0.9, 0.4))
	if _joy_active and _joy_dir.length() > 0.05:
		draw_line(hs, hs + _joy_dir * (HERO_RADIUS + 18.0), Color(1.0, 1.0, 1.0, 0.75), 2.5)


func _draw_joystick() -> void:
	draw_circle(JOY_ANCHOR, JOY_RADIUS, Color(1.0, 1.0, 1.0, 0.06))
	draw_arc(JOY_ANCHOR, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.22), 2.0)
	if _joy_active:
		draw_circle(JOY_ANCHOR + _joy_dir * JOY_RADIUS, 22.0, Color(1.0, 1.0, 1.0, 0.38))


func _draw_hud() -> void:
	# Gold
	draw_circle(Vector2(28.0, 28.0), 8.0, Color(1.0, 0.85, 0.1))
	_txt(Vector2(44.0, 28.0), "%d g" % _gold, Color(1.0, 0.95, 0.7), 18, false)

	# Castle HP mini-bar (top-right)
	var ratio := float(_castle_hp) / float(CASTLE_MAX_HP)
	var bar_col := Color(0.9, 0.2, 0.2) if ratio < 0.35 else Color(0.3, 0.85, 0.3)
	draw_rect(Rect2(Vector2(VIEWPORT.x - 124.0, 20.0), Vector2(104.0, 10.0)), Color(0.15, 0.08, 0.08))
	draw_rect(Rect2(Vector2(VIEWPORT.x - 124.0, 20.0), Vector2(104.0 * ratio, 10.0)), bar_col)
	_txt(Vector2(VIEWPORT.x - 72.0, 14.0), "Chateau", Color(0.65, 0.65, 0.65), 12, true)


# ---------------------------------------------------------------------------
# Off-screen directional arrow
# ---------------------------------------------------------------------------
func _draw_offscreen_arrow(screen_pos: Vector2, col: Color, label: String = "") -> void:
	var center := VIEWPORT / 2.0
	var dir    := center.direction_to(screen_pos)
	# Find intersection with viewport border (with margin)
	var margin := 48.0
	var tip    := _edge_clamp(center, dir, margin)
	var perp   := Vector2(-dir.y, dir.x) * 10.0
	draw_colored_polygon(
		PackedVector2Array([tip, tip - dir * 20.0 + perp, tip - dir * 20.0 - perp]),
		col
	)
	if label != "":
		_txt(tip - dir * 36.0, label, col, 13, true)


func _edge_clamp(origin: Vector2, dir: Vector2, margin: float) -> Vector2:
	var bounds := Rect2(Vector2(margin, margin), VIEWPORT - Vector2(margin * 2.0, margin * 2.0))
	# Ray-AABB intersection to find the point on the edge
	var t_max := INF
	if abs(dir.x) > 0.001:
		var tx := (bounds.position.x + bounds.size.x if dir.x > 0 else bounds.position.x) - origin.x
		t_max = minf(t_max, tx / dir.x)
	if abs(dir.y) > 0.001:
		var ty := (bounds.position.y + bounds.size.y if dir.y > 0 else bounds.position.y) - origin.y
		t_max = minf(t_max, ty / dir.y)
	return origin + dir * t_max


# ---------------------------------------------------------------------------
# Text helper using fallback font
# ---------------------------------------------------------------------------
func _txt(pos: Vector2, text: String, col: Color, size: int, centered: bool) -> void:
	if _font == null:
		return
	var draw_pos := pos
	if centered:
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_pos.x -= w / 2.0
	draw_pos.y += size / 2.0
	draw_string(_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
