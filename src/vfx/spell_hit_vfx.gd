## SpellHitVfx — expanding splash ring for hero spell impacts.
## Pure _draw() implementation — no textures, no CPUParticles2D required.
## Compatible with Android Compatibility renderer (ADR-002 / ADR-007).
##
## Spawned by Main._spawn_spell_vfx() at world position; auto-queues free when done.
## spell_index: 0=Feu (orange), 1=Foudre (yellow), 2=Glace (blue)
extends Node2D

const DURATION := 0.50   ## Total animation length in seconds

## Spell ring colors — match hero_spells.gd spell palette
const SPELL_COLORS: Array[Color] = [
	Color("#FF6B35"),   ## 0 — Feu     : orange fire
	Color("#FFEB3B"),   ## 1 — Foudre  : yellow lightning
	Color("#81D4FA"),   ## 2 — Glace   : light blue ice
]

var _elapsed: float = 0.0
var _color: Color = Color.WHITE
var _spell_radius: float = 80.0

## Initialize and start the animation.
## spell_index: 0/1/2    spell_radius: from SPELLS[].radius in hero_spells.gd
func play(spell_index: int, spell_radius: float) -> void:
	_spell_radius = spell_radius
	_color = SPELL_COLORS[clampi(spell_index, 0, 2)]
	_spawn_particles(spell_index)

## Spawn procedural particle ColorRects as siblings (children of parent node).
## All via Tween — no GPUParticles2D, compatible with Android Compatibility renderer.
func _spawn_particles(spell_idx: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	## Particle configs per spell type
	## [count, width, height, color, move_vec_func, alpha_dur, move_dur]
	match spell_idx:
		0:  ## Embrasement — orange/red embers rising upward
			for i: int in range(8):
				var angle: float = randf() * TAU
				var dist: float = randf_range(8.0, 40.0)
				var p := ColorRect.new()
				p.size = Vector2(4.0, 4.0)
				p.color = Color(1.0, randf_range(0.3, 0.6), 0.05, 0.9)
				p.position = position + Vector2(cos(angle) * dist, sin(angle) * dist) - Vector2(2.0, 2.0)
				parent.add_child(p)
				var tw: Tween = p.create_tween()
				var target_pos: Vector2 = p.position + Vector2(randf_range(-12.0, 12.0), -randf_range(20.0, 40.0))
				tw.tween_property(p, "position", target_pos, 0.8)
				tw.parallel().tween_property(p, "modulate:a", 0.0, 0.8)
				tw.tween_callback(p.queue_free)
		1:  ## Foudre — yellow sparks jetting outward in a star burst
			for i: int in range(7):
				var angle: float = float(i) / 7.0 * TAU + randf() * 0.3
				var p := ColorRect.new()
				p.size = Vector2(3.0, 8.0)
				p.color = Color(1.0, 0.95, 0.2, 0.9)
				p.position = position - Vector2(1.5, 4.0)
				parent.add_child(p)
				var tw: Tween = p.create_tween()
				var target_pos: Vector2 = position + Vector2(cos(angle), sin(angle)) * randf_range(35.0, 60.0) - Vector2(1.5, 4.0)
				tw.tween_property(p, "position", target_pos, 0.4)
				tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
				tw.tween_callback(p.queue_free)
		2:  ## Glace — blue-white snowflakes drifting down slowly
			for i: int in range(6):
				var angle: float = randf() * TAU
				var dist: float = randf_range(5.0, 35.0)
				var p := ColorRect.new()
				p.size = Vector2(5.0, 5.0)
				p.color = Color(0.75, 0.93, 1.0, 0.85)
				p.position = position + Vector2(cos(angle) * dist, sin(angle) * dist) - Vector2(2.5, 2.5)
				parent.add_child(p)
				var tw: Tween = p.create_tween()
				var target_pos: Vector2 = p.position + Vector2(randf_range(-8.0, 8.0), randf_range(10.0, 25.0))
				tw.tween_property(p, "position", target_pos, 1.2)
				tw.parallel().tween_property(p, "modulate:a", 0.0, 1.2)
				tw.tween_callback(p.queue_free)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = minf(_elapsed / DURATION, 1.0)
	var alpha: float = 0.85 * (1.0 - t)
	var radius: float = _spell_radius * t

	if radius < 2.0:
		return

	## Filled circle at low opacity — shows the AoE area
	draw_circle(Vector2.ZERO, radius,
			Color(_color.r, _color.g, _color.b, alpha * 0.22))

	## Bright ring outline that expands with the circle
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36,
			Color(_color.r, _color.g, _color.b, alpha), 3.0, false)

	## Second smaller inner ring — adds depth (fades out faster)
	var inner_r: float = radius * maxf(0.6 - t, 0.0) / 0.6
	if inner_r > 3.0:
		draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, 24,
				Color(_color.r, _color.g, _color.b, alpha * 0.55), 2.0, false)
