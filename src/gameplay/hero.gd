## Hero — player-controlled character
## ADR-002: Area2D physics (no CharacterBody2D)
## ADR-001: Viewport 960×540 (landscape), world 1920×1080
## GDD Req: TR-hero-001
##
## Moves via virtual fixed-anchor joystick in the bottom-left quadrant of the screen.
## Exposes facing_angle for ArcherFormation slot rotation.
extends Node2D

const HERO_SPEED    := 200.0
const JOY_ANCHOR    := Vector2(110.0, 430.0)  ## Fixed viewport-space position — bottom-left
const JOY_RADIUS    := 80.0
const HERO_START_POS := Vector2(500.0, 540.0)  ## Center of landscape world, near castle

## Hero HP — only relevant in EXPLORING state (hero is immortal in TD mode).
const HERO_MAX_HP := 50

## World bounds — hero cannot leave this rectangle.
## TD mode: 1920×1080. Exploration mode: 3840×1080 (double-wide map).
const WORLD_MIN := Vector2(0.0, 0.0)
const WORLD_MAX_TD   := Vector2(1920.0, 1080.0)
const WORLD_MAX_EXPL := Vector2(9600.0, 3240.0)

## Joystick activation: circular zone around the anchor (viewport coords).
## Radius of 200 px keeps the joystick strictly left of the Interact button
## (nearest edge of Interact at x=330, y=453 is ~221 px from the anchor).
const JOY_ACTIVATION_RADIUS := 200.0

var _joy_active: bool = false
var _joy_touch_id: int = -1
## Normalized direction from joystick input — zero when released
var _joy_direction: Vector2 = Vector2.ZERO
## Current facing angle in radians. Updated every frame while moving.
## Holds last value when stationary. Resets to PI/2 (facing down) on session reset.
var facing_angle: float = PI / 2.0
var _anim: AnimatedSprite2D
var _visual_tier: int = -1  ## Cached tier — avoids redundant frame reloads

## HP — tracked only while EXPLORING. Hero is immortal in TD mode.
var hp: int = HERO_MAX_HP
## Guards against stacking die-triggers while the return fade is in progress.
var _dying: bool = false
## CHAMPION skill: absorbs a lethal hit once per session, leaving the hero at 1 HP.
var _champion_absorbed: bool = false

## --- Auto-attack (EXPLORING mode only) ---
const ATK_RANGE    := 130.0  ## px — aggro range at which hero auto-attacks
const ATK_DAMAGE   := 10     ## damage per hit
const ATK_COOLDOWN := 1.5    ## seconds between swings
var _atk_timer: float = 0.0

## Equipment stat bonuses — modified by crafted items via ItemInventory.item_crafted.
## Reset on session_reset alongside HP.
var _atk_damage_bonus: int   = 0   ## Added to ATK_DAMAGE per swing
var _atk_range_bonus:  float = 0.0 ## Added to ATK_RANGE
var _hp_max_bonus:     int   = 0   ## Added to HERO_MAX_HP
var _dmg_reduction:    float = 0.0 ## 0.0–1.0 fraction of incoming damage absorbed
var _regen_timer:      float = 0.0 ## HP regen countdown (Crystal Amulet)
var _regen_rate:       float = 0.0 ## HP per tick (set when amulet is crafted)
var _speed_mult:       float = 1.0 ## Speed multiplier (Speed Elixir / buffs)
var _speed_elixir_timer: float = 0.0
var _slow_timer:       float = 0.0 ## Remaining slow duration (boss root_nova, water arrows)
var _poison_immune:    bool  = false  ## Shadow Mail: not used yet, future
var _stealth:          float = 0.0   ## Silk Cloak: aggro radius multiplier for enemies
var _spell_dmg_mult:   float = 1.0   ## Crystal Staff: multiplies all spell damage by 1.30

## XP system — 3 tiers: Novice (0), Guerrier (1), Champion (2).
const XP_THRESHOLDS: Array[int] = [0, 30, 80]
const LEVEL_NAMES: Array[String] = ["Novice", "Guerrier", "Champion"]
var _xp: int = 0
var _xp_level: int = 0  ## 0=Novice, 1=Guerrier, 2=Champion

## Emitted when HP drops to 0 while exploring. Main listens to trigger _do_return().
signal hp_changed(new_hp: int)
signal died_in_exploration
signal xp_changed(new_xp: int, new_level: int)

## Returns effective max HP combining base, equipment bonus, and SkillTree ENDURANCE bonus.
func _get_max_hp() -> int:
	var skill_bonus: int = SkillTree.get_hp_bonus() if SkillTree != null else 0
	return HERO_MAX_HP + _hp_max_bonus + skill_bonus

func _ready() -> void:
	position = HERO_START_POS
	add_to_group("players")
	GameStateMachine.session_reset.connect(_on_session_reset)

	# Drop shadow — rendered before sprite (child order = draw order)
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/garrison/shadow.png")
	shadow.position = Vector2(0.0, 22.0)  ## Grounded under the sprite center (hero pivot at feet-level)
	shadow.scale = Vector2(1.5, 1.5)
	add_child(shadow)

	# Animated walk cycle — 4 frames at 8 fps
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in range(4):
		var tex: Texture2D = load("res://assets/sprites/garrison/hero_%d.png" % i)
		frames.add_frame("walk", tex)
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = frames
	_anim.scale = Vector2(0.68, 0.68)
	_anim.play("walk")
	add_child(_anim)
	_visual_tier = 0

## Update hero walk animation to tier-appropriate sprites.
## T0 Medieval, T1 Paladin Solaire, T2 Chevalier-Automate, T3 Commandant Néo-Synthétique.
## Called by Main when wave tier threshold is crossed.
func set_visual_tier(tier: int) -> void:
	if tier == _visual_tier:
		return
	_visual_tier = tier
	var prefix: String = "hero" if tier == 0 else ("hero_t%d" % clampi(tier, 1, 3))
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in range(4):
		var path: String = "res://assets/sprites/garrison/%s_%d.png" % [prefix, i]
		var tex: Texture2D = load(path)
		if tex == null:
			tex = load("res://assets/sprites/garrison/hero_%d.png" % i)
		frames.add_frame("walk", tex)
	if _anim != null:
		_anim.sprite_frames = frames
		_anim.play("walk")

func _input(event: InputEvent) -> void:
	var s := GameStateMachine.current_state
	if s != GameStateMachine.State.PLAYING and s != GameStateMachine.State.EXPLORING:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _process(delta: float) -> void:
	var s := GameStateMachine.current_state
	if s != GameStateMachine.State.PLAYING and s != GameStateMachine.State.EXPLORING:
		return
	if _joy_active and _joy_direction.length() > 0.1:
		var skill_spd: float = SkillTree.get_speed_mult() if SkillTree != null else 1.0
		position += _joy_direction * HERO_SPEED * _speed_mult * skill_spd * delta
		facing_angle = _joy_direction.angle()
		var world_max: Vector2 = WORLD_MAX_EXPL if s == GameStateMachine.State.EXPLORING else WORLD_MAX_TD
		position = position.clamp(WORLD_MIN, world_max)
	## Knight is a side-view sprite facing RIGHT by default.
	## Flip horizontally to face left; no vertical rotation to avoid upside-down display.
	if _anim != null:
		_anim.rotation = 0.0
		if _joy_direction.x < -0.05:
			_anim.flip_h = true   ## face left (flip from right-default)
		elif _joy_direction.x > 0.05:
			_anim.flip_h = false  ## face right (knight default)

	## Auto-attack: find and strike nearest enemy every ATK_COOLDOWN seconds.
	if s == GameStateMachine.State.EXPLORING:
		_atk_timer -= delta
		if _atk_timer <= 0.0:
			_try_auto_attack()
		## HP regen (Crystal Amulet)
		if _regen_rate > 0.0:
			_regen_timer -= delta
			if _regen_timer <= 0.0:
				_regen_timer = 4.0
				heal(int(_regen_rate))
		## Speed Elixir countdown
		if _speed_elixir_timer > 0.0:
			_speed_elixir_timer -= delta
			if _speed_elixir_timer <= 0.0:
				_speed_mult = 1.0
		## Slow timer (Sylvalis root_nova, enemy water arrows)
		if _slow_timer > 0.0:
			_slow_timer -= delta
			if _slow_timer <= 0.0:
				_slow_timer = 0.0
				_speed_mult = maxf(_speed_mult, 1.0)  ## Restore full speed (don't cancel elixir)

## Apply a movement slow to the hero for [param duration] seconds.
## [param factor] 0.0-1.0 — remaining speed fraction (0.40 = 60% slower).
func apply_slow(factor: float, duration: float) -> void:
	_speed_mult = minf(_speed_mult, factor)
	_slow_timer = maxf(_slow_timer, duration)

## Handle touch begin and end
func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Joystick activates within a circular zone around its anchor (viewport coords).
		if _joy_touch_id == -1 and event.position.distance_to(JOY_ANCHOR) < JOY_ACTIVATION_RADIUS:
			_joy_touch_id = event.index
			_joy_active = true
			_update_joy_direction(event.position)
	else:
		if event.index == _joy_touch_id:
			_joy_touch_id = -1
			_joy_active = false
			_joy_direction = Vector2.ZERO

## Handle touch move
func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joy_touch_id:
		_update_joy_direction(event.position)

## Compute normalized joystick direction from viewport-space touch position.
## Clamps knob offset to JOY_RADIUS before normalizing.
func _update_joy_direction(touch_pos: Vector2) -> void:
	var raw_offset: Vector2 = touch_pos - JOY_ANCHOR
	var clamped_offset: Vector2 = raw_offset.limit_length(JOY_RADIUS)
	_joy_direction = clamped_offset.normalized() if clamped_offset.length() > 0.1 else Vector2.ZERO

## Find the nearest enemy in the "enemies" group within ATK_RANGE and strike it.
## Emits a brief white slash visual in the attack direction.
func _try_auto_attack() -> void:
	var nearest: Node = null
	var nearest_dist: float = ATK_RANGE + _atk_range_bonus
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("take_damage"):
			continue
		## RPGEnemy uses _alive, TD enemies use active — only hit living ones
		if e.get("_alive") == false:
			continue
		var d: float = position.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest == null:
		return
	_atk_timer = ATK_COOLDOWN
	var skill_dmg_mult: float = SkillTree.get_melee_damage_mult() if SkillTree != null else 1.0
	var base_dmg: int = roundi(float(ATK_DAMAGE + _atk_damage_bonus) * skill_dmg_mult)
	nearest.take_damage(base_dmg)
	## VENOM_BLADE: main target gets poisoned (3 DPS, 4s)
	if ItemInventory.has_item(ItemInventory.Item.VENOM_BLADE) and nearest.has_method("apply_poison"):
		nearest.apply_poison(3.0, 4.0)
	## IRON_SWORD: 60° AoE cone swing — hits up to 2 additional enemies at 40% damage
	if ItemInventory.has_item(ItemInventory.Item.IRON_SWORD):
		var dir: Vector2 = position.direction_to(nearest.position)
		var aoe_range: float = ATK_RANGE + _atk_range_bonus
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if e == nearest:
				continue
			if e.get("_alive") == false:
				continue
			var d: float = position.distance_to(e.position)
			if d > aoe_range:
				continue
			var e_dir: Vector2 = position.direction_to(e.position)
			## 60° cone = dot product > cos(30°) ≈ 0.866
			if dir.dot(e_dir) > 0.866 and e.has_method("take_damage"):
				e.take_damage(int(base_dmg * 0.4))
	add_xp(2)  ## +2 XP per kill (killing the nearest target)
	AudioManager.play(AudioManager.SFX_VOLLEY)
	## Slash visual: thin white line pointing toward target, fades in 0.15s
	var dir: Vector2 = position.direction_to(nearest.position)
	var slash := ColorRect.new()
	slash.size = Vector2(ATK_RANGE * 0.55, 4.0)
	slash.color = Color(1.0, 1.0, 0.85, 0.90)
	slash.rotation = dir.angle()
	slash.position = dir * 12.0 - Vector2(0.0, 2.0).rotated(dir.angle())
	add_child(slash)
	var tw := create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.15)
	tw.tween_callback(slash.queue_free)

## Reduce hero HP by [param amount]. Triggers forced return if HP reaches 0.
## Only active while EXPLORING; no-op in TD mode.
func take_damage(amount: int) -> void:
	if _dying or GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return
	var final_amount: int = maxi(1, roundi(float(amount) * (1.0 - _dmg_reduction)))
	hp = maxi(hp - final_amount, 0)
	## CHAMPION skill: absorb one lethal blow per session, survive at 1 HP.
	if hp <= 0 and not _champion_absorbed and SkillTree != null and SkillTree.has_fatal_absorption():
		hp = 1
		_champion_absorbed = true
	hp_changed.emit(hp)
	if hp <= 0:
		_dying = true
		died_in_exploration.emit()

## Restore HP by [param amount], capped at effective max HP.
func heal(amount: int) -> void:
	hp = mini(hp + amount, _get_max_hp())
	hp_changed.emit(hp)

## Add XP and level up when a threshold is crossed.
func add_xp(amount: int) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return
	_xp += amount
	var new_level: int = _xp_level
	for i: int in range(XP_THRESHOLDS.size() - 1, -1, -1):
		if _xp >= XP_THRESHOLDS[i]:
			new_level = i
			break
	if new_level != _xp_level:
		_xp_level = new_level
	xp_changed.emit(_xp, _xp_level)

func _on_session_reset() -> void:
	position = HERO_START_POS
	facing_angle = PI / 2.0
	_joy_active = false
	_joy_touch_id = -1
	_joy_direction = Vector2.ZERO
	_dying = false
	_atk_timer = 0.0
	## Reset equipment bonuses (skills persist — _get_max_hp() includes ENDURANCE bonus)
	_atk_damage_bonus    = 0
	_atk_range_bonus     = 0.0
	_hp_max_bonus        = 0
	_dmg_reduction       = 0.0
	_regen_rate          = 0.0
	_regen_timer         = 0.0
	_speed_mult          = 1.0
	_speed_elixir_timer  = 0.0
	_slow_timer          = 0.0
	_stealth             = 0.0
	_spell_dmg_mult      = 1.0
	_xp                  = 0
	_xp_level            = 0
	_champion_absorbed   = false
	## HP reset at max including skill bonuses (equipment already zeroed above)
	hp = _get_max_hp()
	hp_changed.emit(hp)
	xp_changed.emit(_xp, _xp_level)
