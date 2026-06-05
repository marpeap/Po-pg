## Arrow — pooled projectile (Area2D)
## ADR-002: Area2D overlap only
## ADR-003: Pool API — activate()/deactivate(), no instantiate()/queue_free()
## GDD Req: TR-archer-002
##
## Checked out of the arrow pool by ArcherFormation and ArcherTower.
## Deactivates and returns itself to pool after hitting an enemy or exceeding range.
extends Area2D

const PROJ_SPEED := 400.0
const PROJ_DAMAGE := 8   ## Base damage — used as default when no override is passed
const SHOOT_RANGE := 300.0

var _direction: Vector2 = Vector2.ZERO
var _start_pos: Vector2 = Vector2.ZERO
var _active: bool = false
var _pool: ObjectPool  ## Injected by activate() — needed for self-return
var _damage: int = PROJ_DAMAGE  ## Effective damage — overridden by ArcherFormation for Momentum
var _speed: float = PROJ_SPEED   ## Effective speed — overridden by crafted Silk Quiver bonus
var _slow_factor: float = 1.0    ## 1.0 = no slow; Water tower passes 0.20 (80% slow)
var _slow_duration: float = 0.0  ## Seconds slow effect lasts on hit enemy
var _poison_on_hit: bool = false  ## POISON_QUIVER: apply 3 DPS poison for 3s on hit
var _fire_on_hit:   bool = false  ## FIRE_QUIVER:   apply 4 DPS burn  for 3s on hit
var _sprite: Sprite2D
var _visual_tier: int = -1       ## Cached tier to avoid redundant texture reloads

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/arrow.png")
	_sprite.scale = Vector2(0.55, 0.55)
	add_child(_sprite)
	deactivate()
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if not _active:
		return
	position += _direction * _speed * delta
	if _sprite != null:
		_sprite.rotation = _direction.angle()
	if position.distance_to(_start_pos) > SHOOT_RANGE:
		_return_to_pool()

func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area.is_in_group("enemies"):
		area.take_damage(_damage)
		if _slow_factor < 1.0 and area.has_method("apply_slow"):
			area.apply_slow(_slow_factor, _slow_duration)
		if _poison_on_hit and area.has_method("apply_poison"):
			area.apply_poison(3.0, 3.0)
		if _fire_on_hit and area.has_method("apply_poison"):
			area.apply_poison(4.0, 3.0)  ## Fire burn: higher DPS, same duration
		_return_to_pool()

## Pool API — called by ArcherFormation / ArcherTower to fire this arrow.
## damage defaults to PROJ_DAMAGE; ArcherFormation passes effective_damage for Momentum scaling.
## speed defaults to PROJ_SPEED; ArcherFormation passes PROJ_SPEED * _crafted_speed_bonus (Silk Quiver).
## slow_factor < 1.0 activates a speed debuff on hit (Water tower power).
## poison_on_hit / fire_on_hit: set by ArcherFormation when quiver items are equipped.
## visual_tier: 0=Medieval 1=Elven 2=Tracer 3=Laser — drives arrow sprite selection.
func activate(start: Vector2, dir: Vector2, pool: ObjectPool, damage: int = PROJ_DAMAGE, slow_factor: float = 1.0, slow_duration: float = 0.0, speed: float = PROJ_SPEED, poison_on_hit: bool = false, fire_on_hit: bool = false, visual_tier: int = 0) -> void:
	position = start
	_start_pos = start
	_direction = dir.normalized()
	_pool = pool
	_damage = damage
	_speed = speed
	_slow_factor = slow_factor
	_slow_duration = slow_duration
	_poison_on_hit = poison_on_hit
	_fire_on_hit   = fire_on_hit
	## Update arrow sprite when tier changes — avoid reloading same texture every fire.
	if visual_tier != _visual_tier:
		_visual_tier = visual_tier
		var tier_path: String = "res://assets/sprites/garrison/arrow_t%d.png" % clampi(visual_tier, 0, 3)
		var tex: Texture2D = load(tier_path)
		if tex != null and _sprite != null:
			_sprite.texture = tex
	_active = true
	$CollisionShape2D.set_deferred("disabled", false)
	show()

## Hide and disable without queue_free. Pool retains the node.
func deactivate() -> void:
	_active = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	hide()

func _return_to_pool() -> void:
	deactivate()
	if _pool != null:
		_pool.return_node(self)
