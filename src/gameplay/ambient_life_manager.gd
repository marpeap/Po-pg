## AmbientLifeManager — Pool de 64 créatures ambiantes dans le monde RPG.
## Inspiré de BOTW (vie sauvage réactive) et Stardew Valley (animaux saisonniers).
##
## Les créatures errent dans la zone courante, s'enfuient au contact du héros,
## réapparaissent hors caméra. Elles ne bloquent pas le gameplay (pas de collision).
##
## Pool de 64 nœuds réutilisés (pas d'instanciation par-frame).
## Visible uniquement en mode EXPLORING.
extends Node2D

## Garrison chibi ambient creature sprites (28–36px, side-view).
const GARRISON := "res://assets/sprites/garrison/"

## Types de créatures avec leurs attributs
## [sprite_path, scale, tint, speed, flee_radius]
const CREATURE_TYPES: Array[Array] = [
	["ambient_bunny.png",    1.0, Color(1.0,  1.0,  1.0),  40.0,  90.0],  ## Lapin blanc
	["ambient_squirrel.png", 1.0, Color(1.0,  1.0,  1.0),  35.0,  80.0],  ## Écureuil orange
	["ambient_bird.png",     1.0, Color(1.0,  1.0,  1.0),  50.0, 100.0],  ## Oiseau bleu
	["ambient_deer.png",     1.0, Color(1.0,  1.0,  1.0),  30.0,  70.0],  ## Cerf doré
	["ambient_crow.png",     1.0, Color(1.0,  1.0,  1.0),  60.0, 120.0],  ## Corbeau noir
]

## Nombre max de créatures actives
const POOL_SIZE := 64
## Créatures actives simultanément dans une zone
const ACTIVE_PER_ZONE := 12
## Zone d'apparition autour du héros (évite spawn visible)
const SPAWN_MARGIN := 300.0
const ROAM_RADIUS := 200.0

## ── Runtime ─────────────────────────────────────────────────────────────────

class AmbientCreature:
	var node: Node2D
	var sprite: Sprite2D
	var type_idx: int
	var active: bool
	var home: Vector2
	var target: Vector2
	var fleeing: bool
	var speed: float
	var flee_radius: float

var _pool: Array[AmbientCreature] = []
var _hero: Node2D = null
var _active_count: int = 0
var _zone_bounds: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _visible_in_rpg: bool = false

## ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_pool()
	## Se cache en mode TD
	if GameStateMachine != null:
		GameStateMachine.game_state_changed.connect(_on_state_changed)
	visible = false

func _build_pool() -> void:
	for i: int in range(POOL_SIZE):
		var creature := AmbientCreature.new()
		var n := Node2D.new()
		var sp := Sprite2D.new()
		n.add_child(sp)
		add_child(n)
		n.visible = false
		creature.node = n
		creature.sprite = sp
		creature.active = false
		creature.type_idx = 0
		creature.fleeing = false
		creature.speed = 40.0
		creature.flee_radius = 90.0
		_pool.append(creature)

## ── State ────────────────────────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	## GameStateMachine.State: 0=PLAYING 1=GAME_OVER 2=RESETTING 3=EXPLORING
	var exploring: bool = (new_state == 3)
	_visible_in_rpg = exploring
	visible = exploring
	if not exploring:
		_deactivate_all()

func setup(hero: Node2D, zone_rect: Rect2) -> void:
	_hero = hero
	_zone_bounds = zone_rect
	_deactivate_all()
	_spawn_initial()

## ── Process ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _visible_in_rpg or _hero == null:
		return
	var hero_pos: Vector2 = _hero.global_position
	for c: AmbientCreature in _pool:
		if not c.active:
			continue
		_update_creature(c, delta, hero_pos)
	## Respan si trop peu actives
	if _active_count < ACTIVE_PER_ZONE:
		_try_spawn_one(hero_pos)

func _update_creature(c: AmbientCreature, delta: float, hero_pos: Vector2) -> void:
	var dist: float = c.node.global_position.distance_to(hero_pos)
	## Fuite si héros trop proche
	if dist < c.flee_radius:
		c.fleeing = true
		c.target = c.node.global_position + (c.node.global_position - hero_pos).normalized() * 300.0
		c.target = c.target.clamp(_zone_bounds.position, _zone_bounds.position + _zone_bounds.size)
	elif c.fleeing and dist > c.flee_radius * 2.0:
		c.fleeing = false
		c.target = c.home + Vector2(randf_range(-ROAM_RADIUS, ROAM_RADIUS),
				randf_range(-ROAM_RADIUS, ROAM_RADIUS))
		c.target = c.target.clamp(_zone_bounds.position, _zone_bounds.position + _zone_bounds.size)

	## Mouvement vers cible
	var to_target: Vector2 = c.target - c.node.global_position
	if to_target.length() > 4.0:
		var speed: float = c.speed * (1.5 if c.fleeing else 1.0)
		c.node.global_position += to_target.normalized() * speed * delta
		## Flip sprite selon direction
		c.sprite.flip_h = to_target.x < 0.0
	else:
		## Cible atteinte — choisir nouvelle errance
		if not c.fleeing:
			c.target = c.home + Vector2(randf_range(-ROAM_RADIUS, ROAM_RADIUS),
					randf_range(-ROAM_RADIUS, ROAM_RADIUS))
			c.target = c.target.clamp(_zone_bounds.position, _zone_bounds.position + _zone_bounds.size)

	## Désactiver si hors zone
	if not _zone_bounds.grow(200.0).has_point(c.node.global_position):
		_deactivate(c)

## ── Spawn / Deactivate ────────────────────────────────────────────────────────

func _spawn_initial() -> void:
	for _i: int in range(ACTIVE_PER_ZONE):
		_try_spawn_one(_hero.global_position if _hero != null else Vector2(960, 540))

func _try_spawn_one(hero_pos: Vector2) -> void:
	## Cherche une créature inactive dans le pool
	for c: AmbientCreature in _pool:
		if c.active:
			continue
		## Position de spawn hors rayon héros
		var pos: Vector2 = Vector2(
				randf_range(_zone_bounds.position.x, _zone_bounds.end.x),
				randf_range(_zone_bounds.position.y, _zone_bounds.end.y))
		if pos.distance_to(hero_pos) < SPAWN_MARGIN:
			return
		_activate(c, pos)
		return

func _activate(c: AmbientCreature, pos: Vector2) -> void:
	c.type_idx = randi() % CREATURE_TYPES.size()
	var t: Array = CREATURE_TYPES[c.type_idx]
	## Charger texture
	var tex: Texture2D = load(GARRISON + str(t[0]))
	if tex != null:
		c.sprite.texture = tex
	c.sprite.scale = Vector2(float(t[1]), float(t[1]))
	c.sprite.modulate = t[2] as Color
	c.node.global_position = pos
	c.home = pos
	c.target = pos
	c.speed = float(t[3])
	c.flee_radius = float(t[4])
	c.fleeing = false
	c.active = true
	c.node.visible = true
	_active_count += 1

func _deactivate(c: AmbientCreature) -> void:
	c.active = false
	c.node.visible = false
	_active_count -= 1

func _deactivate_all() -> void:
	for c: AmbientCreature in _pool:
		if c.active:
			_deactivate(c)
