## Enemy — pooled Area2D unit
## ADR-002: Area2D overlap only (no RigidBody2D)
## ADR-006: direction_to steering — no NavigationAgent2D
## GDD Req: TR-enemy-001
##
## Steers toward the castle each frame using (CASTLE_POS - position).normalized().
## Returned to pool by EnemyWave via deactivate() after enemy_died fires.
extends Area2D

## Emitted when HP reaches 0. EnemyWave listens to handle coin spawn + kill count.
signal enemy_died(death_position: Vector2)

## Enemy types — each has distinct stats, visual tint, and behaviour.
enum EnemyType {
	INFANTRY,   ## Standard footsoldier — balanced stats
	ARCHER,     ## Fast, low HP, ranged feel — weaker castle hit
	CAVALIER,   ## Heavy cavalry — high HP and speed, high damage
	HEALER,     ## Support unit — heals nearby allies periodically
	SHIELDER,   ## Armored shielder — 40% damage while shield active (breaks at 50% HP)
}

## Per-type base stats: hp, speed, gold, castle_dmg, tint color
const TYPE_STATS := {
	EnemyType.INFANTRY: { "hp": 40, "speed": 65.0,  "gold": 12, "castle_dmg": 10, "tint": Color(1.0,  1.0,  1.0)  },
	EnemyType.ARCHER:   { "hp": 22, "speed": 88.0,  "gold": 18, "castle_dmg": 6,  "tint": Color(0.55, 0.80, 1.0)  },
	EnemyType.CAVALIER: { "hp": 70, "speed": 108.0, "gold": 25, "castle_dmg": 18, "tint": Color(0.85, 0.65, 0.40) },
	EnemyType.HEALER:   { "hp": 28, "speed": 55.0,  "gold": 22, "castle_dmg": 4,  "tint": Color(0.50, 0.90, 0.50) },
	EnemyType.SHIELDER: { "hp": 90, "speed": 40.0,  "gold": 20, "castle_dmg": 15, "tint": Color(0.70, 0.82, 1.0)  },
}

## Castle world-space position — left-center in landscape world 1920×1080
const CASTLE_POS := Vector2(200.0, 540.0)
## Radius within which contact is triggered (matches castle draw radius)
const CASTLE_CONTACT_R := 34.0
## Healer heal interval and amount
const HEAL_INTERVAL := 3.0
const HEAL_AMOUNT := 8
const HEAL_RADIUS := 150.0

## Current HP and stats
var hp: int = 40
var speed: float = 65.0
var gold_value: int = 12
var enemy_type: EnemyType = EnemyType.INFANTRY

var _alive: bool = false
var _max_hp: int = 40
var _castle_dmg: int = 10  ## Per-type castle damage, set by activate()
var _base_speed: float = 65.0  ## Stored for slow recovery
var _slow_timer: float = 0.0   ## Remaining slow duration (0 = not slowed)
var _heal_timer: float = HEAL_INTERVAL  ## Healer: time until next heal pulse
## Poison / burn DoT state
var _poison_timer: float = 0.0
var _poison_dps:   float = 0.0
var _poison_tick:  float = 0.0
## Status effect overlay sprite — replaced each time a new effect is applied.
var _status_sprite: Sprite2D = null

## SHIELDER shield state — active until HP drops to ≤50% of max
var _shield_active: bool = false
## Base modulate tint for this enemy type (set by activate, restored after flash/slow)
var _base_modulate: Color = Color.WHITE

## Injected by EnemyWave — used to call take_damage on castle contact
var _castle: Node = null
var _sprite: AnimatedSprite2D
var _visual_tier: int = -1  ## Cached visual tier to avoid redundant frame reloads

## Type-to-sprite-prefix mapping for type-distinct visuals.
const TYPE_SPRITE_PREFIX := {
	EnemyType.INFANTRY: "enemy_infantry",
	EnemyType.ARCHER:   "enemy_archer",
	EnemyType.CAVALIER: "enemy_cavalier",
	EnemyType.HEALER:   "enemy_healer",
	EnemyType.SHIELDER: "enemy_shielder",
}

func _ready() -> void:
	add_to_group("enemies")

	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/garrison/shadow.png")
	shadow.position = Vector2(0.0, 30.0)
	shadow.scale = Vector2(1.4, 1.4)
	add_child(shadow)

	_sprite = AnimatedSprite2D.new()
	_sprite.scale = Vector2(0.58, 0.58)
	add_child(_sprite)
	_reload_frames(EnemyType.INFANTRY)
	deactivate()

## Rebuild walk animation frames for the given enemy type and visual tier.
## Called on first setup and whenever activate() changes type or tier.
## visual_tier: 0=Medieval, 1=Elven/Rune, 2=Steampunk, 3=Mecha-Cosmic.
func _reload_frames(etype: EnemyType, vtier: int = 0) -> void:
	var base: String = TYPE_SPRITE_PREFIX.get(etype, "enemy_infantry")
	var prefix: String = base if vtier == 0 else ("%s_t%d" % [base, clampi(vtier, 1, 3)])
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in range(4):
		var tex: Texture2D = null
		## Primary path (with tier suffix for T1-T3)
		var path: String = "res://assets/sprites/garrison/%s_%d.png" % [prefix, i]
		if ResourceLoader.exists(path):
			tex = load(path)
		## T0 base fallback (same type, no tier suffix)
		if tex == null and prefix != base:
			var base_path: String = "res://assets/sprites/garrison/%s_%d.png" % [base, i]
			if ResourceLoader.exists(base_path):
				tex = load(base_path)
		## Ultimate fallback: infantry T0 (always imported)
		if tex == null:
			var inf_path: String = "res://assets/sprites/garrison/enemy_infantry_%d.png" % i
			if ResourceLoader.exists(inf_path):
				tex = load(inf_path)
		if tex != null:
			frames.add_frame("walk", tex)
	_sprite.sprite_frames = frames
	_sprite.play("walk")

func _process(delta: float) -> void:
	if not _alive:
		return
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return

	# Slow timer — recover to full speed when expired
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			speed = _base_speed
			_slow_timer = 0.0
			if _sprite != null:
				_sprite.modulate = _base_modulate

	# Poison / burn DoT tick
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_tick  += delta
		if _poison_tick >= 1.0:
			_poison_tick -= 1.0
			take_damage(int(_poison_dps))
		if _poison_timer <= 0.0:
			_poison_timer = 0.0
			_poison_dps   = 0.0

	# Healer — pulse heal to nearby allies
	if enemy_type == EnemyType.HEALER:
		_heal_timer -= delta
		if _heal_timer <= 0.0:
			_heal_timer = HEAL_INTERVAL
			_pulse_heal()

	var dir: Vector2 = (CASTLE_POS - position).normalized()
	var weather_spd_mult: float = WeatherManager.get_enemy_speed_mult() if WeatherManager != null else 1.0
	position += dir * speed * weather_spd_mult * delta
	# Rotate sprite to face movement direction
	if _sprite != null:
		_sprite.rotation = dir.angle() + PI / 2.0
	# Castle contact — deal damage and remove enemy from play
	if position.distance_to(CASTLE_POS) < CASTLE_CONTACT_R:
		if _castle != null:
			_castle.take_damage(_castle_dmg)
		_alive = false
		enemy_died.emit(position)

func _draw() -> void:
	if not _alive:
		return
	# HP bar — 40×6 px at y=-52, clearly above the sprite head
	var bar_w := 40.0
	var ratio := float(hp) / float(max(_max_hp, 1))
	draw_rect(Rect2(-20.0, -52.0, bar_w, 6.0), Color(0.1, 0.1, 0.1, 0.9))
	draw_rect(Rect2(-20.0, -52.0, bar_w * ratio, 6.0), Color("#E53935"))
	## SHIELDER: blue shield ring while shield is active
	if _shield_active:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.50, 0.72, 1.0, 0.72), 2.5)

## Reduce HP. If HP drops to 0, emit enemy_died and mark inactive.
## EnemyWave calls deactivate() after receiving enemy_died.
## SHIELDER: takes 40% damage while shield is active (shield breaks at 50% HP).
func take_damage(amount: int) -> void:
	if not _alive:
		return
	## SHIELDER shield absorbs 60% of incoming damage
	if _shield_active:
		amount = maxi(1, roundi(float(amount) * 0.40))
	hp -= amount
	## Shield breaks once HP falls to or below 50% of max
	if _shield_active and hp <= _max_hp / 2:
		_shield_active = false
	queue_redraw()
	## Brief bright flash — preserves current tint so slow/stun tint is restored correctly
	if _sprite != null:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.06)
		tw.tween_property(_sprite, "modulate",
				Color(0.50, 0.70, 1.0) if _slow_timer > 0.0 else _base_modulate, 0.12)
	if hp <= 0:
		_alive = false
		_spawn_death_particles(position, _visual_tier)
		enemy_died.emit(position)

## Pool API — called by EnemyWave to spawn this enemy from the pool.
## etype selects stats from TYPE_STATS; pass EnemyType.INFANTRY for default.
## visual_tier: 0=Medieval 1=Rune 2=Steampunk 3=Cosmic — drives sprite selection.
func activate(start_pos: Vector2, etype: EnemyType = EnemyType.INFANTRY, visual_tier: int = 0) -> void:
	## Reload sprite frames when type or visual tier changes.
	if etype != enemy_type or visual_tier != _visual_tier:
		_reload_frames(etype, visual_tier)
		_visual_tier = visual_tier
	enemy_type = etype
	var stats: Dictionary = TYPE_STATS[etype]
	position = start_pos
	hp = stats.hp
	_max_hp = stats.hp
	speed = stats.speed
	_base_speed = stats.speed
	gold_value = stats.gold
	_castle_dmg = stats.castle_dmg
	_slow_timer   = 0.0
	_heal_timer   = HEAL_INTERVAL
	_poison_timer = 0.0
	_poison_dps   = 0.0
	_poison_tick  = 0.0
	## SHIELDER: start with shield active; all others: no shield
	_shield_active = (etype == EnemyType.SHIELDER)
	_alive = true
	## Apply type-specific modulate tint
	var tint: Color = stats.get("tint", Color.WHITE) as Color
	_base_modulate = tint
	if _sprite != null:
		_sprite.modulate = tint
	$CollisionShape2D.set_deferred("disabled", false)
	show()
	queue_redraw()

## Apply a poison/burn DoT: dps damage per second for duration seconds.
## Stacks duration and takes the max dps if called again while active.
func apply_poison(dps: float, duration: float) -> void:
	if not _alive:
		return
	_poison_dps   = maxf(_poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)
	_poison_tick  = 0.0
	## Green tint while poisoned (orange/fire tint handled by show_status_effect)
	if _sprite != null and _slow_timer <= 0.0:
		_sprite.modulate = Color(0.55, 1.0, 0.45)

## Apply a speed slow debuff: factor = fraction of normal speed (0.20 = 80% slow).
func apply_slow(factor: float, duration: float) -> void:
	if not _alive:
		return
	speed = _base_speed * factor
	_slow_timer = duration
	# Blue tint while slowed
	if _sprite != null:
		_sprite.modulate = Color(0.50, 0.70, 1.0)

## Show a colored status overlay sprite above the enemy for [duration] seconds.
## effect_type: 0=burning (Embrasement), 1=stunned (Foudre), 2=frozen (Glace).
## Replaces any existing status overlay.
func show_status_effect(effect_type: int, duration: float) -> void:
	if not _alive:
		return
	## Remove previous status sprite if present
	if _status_sprite != null and is_instance_valid(_status_sprite):
		_status_sprite.queue_free()
		_status_sprite = null
	const STATUS_TEXTURES: Array[String] = [
		"res://assets/sprites/garrison/status_burning.png",
		"res://assets/sprites/garrison/status_stunned.png",
		"res://assets/sprites/garrison/status_frozen.png",
	]
	var tex_path: String = STATUS_TEXTURES[clampi(effect_type, 0, 2)]
	var tex: Texture2D = load(tex_path)
	if tex == null:
		## Fallback: colored square when texture not yet imported
		const FALLBACK_COLORS: Array[Color] = [
			Color(1.0, 0.45, 0.1, 0.85),   ## burning — orange
			Color(1.0, 0.92, 0.23, 0.85),  ## stunned  — yellow
			Color(0.50, 0.83, 0.98, 0.85), ## frozen   — light blue
		]
		var fallback_rect: ColorRect = ColorRect.new()
		fallback_rect.color = FALLBACK_COLORS[clampi(effect_type, 0, 2)]
		fallback_rect.size = Vector2(10.0, 10.0)
		fallback_rect.position = Vector2(-5.0, -28.0)
		add_child(fallback_rect)
		## Auto-remove after duration
		get_tree().create_timer(duration).timeout.connect(
			func() -> void:
				if is_instance_valid(fallback_rect):
					fallback_rect.queue_free())
		return
	_status_sprite = Sprite2D.new()
	_status_sprite.texture = tex
	_status_sprite.scale = Vector2(0.6, 0.6)
	_status_sprite.position = Vector2(0.0, -20.0)
	_status_sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
	add_child(_status_sprite)
	## Pulse animation: alpha 0.85 -> 0.4 -> 0.85, loop
	var pulse_tween: Tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(_status_sprite, "modulate:a", 0.4, 0.35)
	pulse_tween.tween_property(_status_sprite, "modulate:a", 0.85, 0.35)
	## Auto-remove after duration
	var sprite_ref: Sprite2D = _status_sprite
	get_tree().create_timer(duration).timeout.connect(
		func() -> void:
			pulse_tween.kill()
			if is_instance_valid(sprite_ref):
				sprite_ref.queue_free()
			if _status_sprite == sprite_ref:
				_status_sprite = null)

## Briefly show the spell-type hit VFX sprite over this enemy.
## spell_idx: 0=fire, 1=lightning, 2=ice — matches hero_spells SPELLS array order.
## Spawns a Sprite2D child, scales it in then fades it out in ~0.4s.
func show_spell_hit_effect(spell_idx: int) -> void:
	if not _alive:
		return
	const HIT_TEXTURES: Array[String] = [
		"res://assets/sprites/garrison/spell_hit_fire.png",
		"res://assets/sprites/garrison/spell_hit_lightning.png",
		"res://assets/sprites/garrison/spell_hit_ice.png",
	]
	var tex: Texture2D = load(HIT_TEXTURES[clampi(spell_idx, 0, 2)])
	if tex == null:
		return
	var hit_spr := Sprite2D.new()
	hit_spr.texture = tex
	hit_spr.scale = Vector2(0.4, 0.4)
	hit_spr.position = Vector2(0.0, -12.0)
	hit_spr.modulate = Color(1.0, 1.0, 1.0, 0.9)
	add_child(hit_spr)
	## Pop in: 0.4→1.1 then settle to 1.0, fade out
	var tw := create_tween()
	tw.tween_property(hit_spr, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_property(hit_spr, "scale", Vector2(0.85, 0.85), 0.05)
	tw.tween_property(hit_spr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(hit_spr.queue_free)

## Healer pulse — restore HP to nearby allies within HEAL_RADIUS.
func _pulse_heal() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var enemy := e as Area2D
		if enemy == null or not enemy.has_method("take_damage"):
			continue
		if not enemy._alive:
			continue
		if position.distance_to(enemy.position) <= HEAL_RADIUS:
			enemy.hp = mini(enemy.hp + HEAL_AMOUNT, enemy._max_hp)
			enemy.queue_redraw()

## Called by EnemyWave after activate() when this enemy is the wave boss.
## Adds a red CPUParticles2D aura child to make the boss visually distinct.
## Pass is_boss=false to remove the aura when the enemy is returned to the pool.
func set_boss_visual(is_boss: bool) -> void:
	var existing: Node = get_node_or_null("BossAura")
	if existing != null:
		existing.queue_free()
	if not is_boss:
		return
	var aura := CPUParticles2D.new()
	aura.name = "BossAura"
	aura.emitting = true
	aura.amount = 22
	aura.lifetime = 0.9
	aura.color = Color(1.0, 0.20, 0.05, 0.75)
	aura.emission_sphere_radius = 26.0
	aura.explosiveness = 0.0
	aura.direction = Vector2.UP
	aura.spread = 180.0
	aura.gravity = Vector2.ZERO
	aura.initial_velocity_min = 18.0
	aura.initial_velocity_max = 32.0
	aura.scale_amount_min = 2.0
	aura.scale_amount_max = 4.0
	add_child(aura)

## Spawn a one-shot CPUParticles2D burst at the death position.
## T0: small yellow flash ring. T1: golden magic. T2: orange debris. T3: cyan plasma.
## Particles are added to the scene root so they outlive the pooled enemy node's hide().
func _spawn_death_particles(death_pos: Vector2, vtier: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	if vtier <= 0:
		## T0: simple expanding yellow ring flash — cheap, no CPUParticles2D
		var flash := Node2D.new()
		flash.global_position = death_pos
		scene_root.add_child(flash)
		var ring := ColorRect.new()
		ring.size = Vector2(22.0, 22.0)
		ring.position = Vector2(-11.0, -11.0)
		ring.color = Color(1.0, 0.88, 0.30, 0.90)
		flash.add_child(ring)
		var tw := flash.create_tween()
		tw.tween_property(flash, "scale", Vector2(2.4, 2.4), 0.20)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.20)
		tw.tween_callback(flash.queue_free)
		return
	var p := CPUParticles2D.new()
	p.global_position = death_pos
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.9
	p.amount = 12
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2(0.0, 280.0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 4.5
	match vtier:
		1:  ## T1 Runique — golden/violet sparkles
			p.color = Color(1.0, 0.85, 0.20, 0.95)
		2:  ## T2 Steampunk — orange debris
			p.color = Color(1.0, 0.45, 0.10, 0.90)
		3:  ## T3 Cosmique — cyan plasma disintegration
			p.color = Color(0.10, 0.95, 1.0, 0.90)
	scene_root.add_child(p)
	## Auto-remove once particles finish (lifetime + buffer)
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.queue_free())

## Pool API — hide and disable this enemy. Called after enemy_died or on session reset.
func deactivate() -> void:
	_alive = false
	_shield_active = false
	## Remove boss aura if present (enemy returns to pool as a regular unit)
	var boss_aura: Node = get_node_or_null("BossAura")
	if boss_aura != null:
		boss_aura.queue_free()
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	hide()
