## ResourceNode — instant-collect resource node in the exploration map.
## Handles all 35 common resource types (ResourceInventory indices: 0-4, 13-41).
## Tap or proximity-interact to collect — node disappears after one use (session-scoped).
## For timed-mining nodes (IRON_ORE, COAL, CRYSTAL, GEMSTONE, HARDWOOD) use ResourceNodeTimed.
## ADR-002: Area2D for input_pickable touch detection (no PhysicsBody2D).
extends Area2D

## Per-type visual and gameplay config — keyed by ResourceInventory.Type int value.
## path: Sprite2D texture path; sx/sy: scale; r/g/b: modulate tint; hw/hh: CollisionShape half-size; y: yield amount.
const TYPE_CFG: Dictionary = {
	## ─── ORIGINAL COMMONS (0-4) ─────────────────────────────────────────────
	0:  {path="res://assets/sprites/garrison/tree_sm.png",           sx=0.55, sy=0.55, r=1.00, g=1.00, b=1.00, hw=19, hh=22, y=3}, ## WOOD
	1:  {path="res://assets/sprites/garrison/rock.png",              sx=0.50, sy=0.50, r=1.00, g=1.00, b=1.00, hw=21, hh=15, y=2}, ## STONE
	2:  {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.95, sy=0.95, r=0.50, g=1.00, b=0.38, hw=12, hh=12, y=4}, ## HERB
	3:  {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_14.png", sx=1.10, sy=1.10, r=0.78, g=0.28, b=0.95, hw=12, hh=12, y=2}, ## MUSHROOM
	4:  {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=1.20, sy=1.20, r=0.96, g=0.96, b=0.88, hw=14, hh=10, y=2}, ## SILK
	## ─── ZONE A — Forêt de l'Éveil (13-19) ─────────────────────────────────
	13: {path="res://assets/sprites/garrison/tree_sm.png",           sx=0.50, sy=0.50, r=0.95, g=0.95, b=0.85, hw=18, hh=20, y=3}, ## BIRCH_BARK — white birch tint
	14: {path="res://assets/sprites/garrison/res_wild_honey.png",     sx=1.00, sy=1.00, r=1.00, g=0.82, b=0.10, hw=11, hh=11, y=2}, ## WILD_HONEY — custom amber sprite
	15: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.70, sy=0.70, r=0.55, g=0.38, b=0.12, hw=10, hh=10, y=4}, ## ACORN — brown tint
	16: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.65, sy=0.65, r=0.18, g=0.55, b=0.22, hw=10, hh=10, y=5}, ## MOSS — deep green
	17: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.85, sy=0.85, r=0.85, g=0.18, b=0.18, hw=12, hh=10, y=3}, ## WILD_BERRY — red
	18: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.70, sy=0.70, r=0.72, g=0.85, b=0.98, hw=10, hh=8,  y=2}, ## FEATHER — light blue
	19: {path="res://assets/sprites/garrison/tree_sm.png",           sx=0.45, sy=0.45, r=0.88, g=0.55, b=0.12, hw=16, hh=18, y=2}, ## RESIN — amber orange
	## ─── ZONE B — Clairière Dorée (20-24) ───────────────────────────────────
	20: {path="res://assets/sprites/garrison/rock.png",              sx=0.55, sy=0.55, r=0.82, g=0.58, b=0.30, hw=18, hh=12, y=3}, ## CLAY — orange-tan
	21: {path="res://assets/sprites/garrison/rock.png",              sx=0.45, sy=0.45, r=0.45, g=0.45, b=0.50, hw=15, hh=10, y=2}, ## FLINT — dark gray
	22: {path="res://assets/sprites/garrison/rock.png",              sx=0.55, sy=0.55, r=0.90, g=0.90, b=0.88, hw=18, hh=12, y=2}, ## LIMESTONE — very pale
	23: {path="res://assets/sprites/garrison/rock.png",              sx=0.50, sy=0.50, r=0.78, g=0.52, b=0.22, hw=16, hh=11, y=2}, ## BRONZE_SCRAP — bronze copper
	24: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.80, sy=0.80, r=0.88, g=0.78, b=0.55, hw=12, hh=9,  y=3}, ## ROPE_FIBER — tan beige
	## ─── ZONE C — Ruines Ancestrales (25) ───────────────────────────────────
	25: {path="res://assets/sprites/garrison/rock.png",              sx=0.48, sy=0.48, r=0.22, g=0.22, b=0.22, hw=15, hh=10, y=3}, ## CHARCOAL — near black
	## ─── ZONE D — Catacombes Oubliées (26-28) ───────────────────────────────
	26: {path="res://assets/sprites/garrison/rock.png",              sx=0.48, sy=0.48, r=0.92, g=0.88, b=0.12, hw=15, hh=10, y=2}, ## SULFUR — sulfur yellow
	27: {path="res://assets/sprites/garrison/res_quartz_crystal.png", sx=1.00, sy=1.00, r=0.92, g=0.88, b=1.00, hw=16, hh=11, y=2}, ## QUARTZ — custom crystal sprite
	28: {path="res://assets/sprites/garrison/rock.png",              sx=0.50, sy=0.50, r=0.98, g=0.98, b=0.98, hw=16, hh=11, y=2}, ## ROCK_SALT — white crystal
	## ─── ZONE E — Marécage Murmurant (29-33) ────────────────────────────────
	29: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.90, sy=1.20, r=0.28, g=0.60, b=0.30, hw=10, hh=14, y=4}, ## REED — tall dark green
	30: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.70, sy=0.70, r=0.35, g=0.72, b=0.35, hw=10, hh=8,  y=1}, ## FROG_SKIN — green flat
	31: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.75, sy=0.75, r=0.20, g=0.52, b=0.28, hw=10, hh=10, y=4}, ## ALGAE — slimy green
	32: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=0.80, sy=0.80, r=0.35, g=0.58, b=0.30, hw=11, hh=11, y=3}, ## SWAMP_HERB — murky green
	33: {path="res://assets/sprites/garrison/rock.png",              sx=0.52, sy=0.52, r=0.45, g=0.32, b=0.18, hw=16, hh=11, y=3}, ## MUD_CLAY — muddy brown
	## ─── ZONE F — Forêt de Cristal (34-36) ──────────────────────────────────
	34: {path="res://assets/sprites/garrison/res_glowing_mushroom.png", sx=1.00, sy=1.00, r=0.18, g=0.95, b=0.88, hw=12, hh=12, y=2}, ## GLOWING_MUSHROOM — custom cyan glow sprite
	35: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.90, sy=0.90, r=0.48, g=0.30, b=0.18, hw=13, hh=10, y=3}, ## GNARLED_ROOT — brown root
	36: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_13.png", sx=1.00, sy=0.80, r=0.30, g=0.85, b=0.30, hw=12, hh=10, y=3}, ## CLIMBING_VINE — bright green
	## ─── ZONES G-I — Cendres / Feu / Glace (37-39) ─────────────────────────
	37: {path="res://assets/sprites/garrison/rock.png",              sx=0.48, sy=0.48, r=0.78, g=0.78, b=0.80, hw=15, hh=10, y=4}, ## ASH — pale gray
	38: {path="res://assets/sprites/garrison/rock.png",              sx=0.50, sy=0.50, r=0.20, g=0.16, b=0.12, hw=16, hh=11, y=3}, ## BLACK_SOIL — near black brown
	39: {path="res://assets/sprites/garrison/tree_sm.png",           sx=0.50, sy=0.50, r=0.52, g=0.48, b=0.42, hw=18, hh=20, y=3}, ## DEAD_WOOD — desaturated gray
	## ─── ZONES J-K — Désert / Temple (40-41) ────────────────────────────────
	40: {path="res://assets/sprites/kenney_downloads/medieval-rts/PNG/Default size/Environment/medievalEnvironment_05.png", sx=0.75, sy=0.75, r=0.55, g=0.38, b=0.18, hw=11, hh=9,  y=3}, ## PINE_CONE — dark brown
	41: {path="res://assets/sprites/garrison/rock.png",              sx=0.55, sy=0.55, r=0.52, g=0.18, b=0.08, hw=18, hh=12, y=2}, ## VOLCANIC_STONE — dark red-orange
}

## Rarity-based glow tint applied additively when rarity > 0.
## Common = no glow. Uncommon = subtle green. Rare = blue. Epic = purple.
const RARITY_GLOW: Array[Color] = [
	Color(1.0, 1.0, 1.0),       ## COMMON — no glow
	Color(0.6, 1.0, 0.6),       ## RARE — green shimmer (unused for commons but kept for shared API)
	Color(0.5, 0.7, 1.0),       ## LEGENDARY — blue shimmer
	Color(0.9, 0.4, 1.0),       ## EPIC — purple shimmer
]

## Resource types that get a CPUParticles2D sparkle aura → sparkle color.
## These are visually/lore "special" resources within their zone.
const SPARKLE_TYPES: Dictionary = {
	14: Color(1.00, 0.82, 0.10),  ## WILD_HONEY    — amber sparkle
	17: Color(1.00, 0.20, 0.28),  ## WILD_BERRY    — ruby sparkle
	19: Color(0.90, 0.60, 0.12),  ## RESIN         — amber-orange sparkle
	26: Color(0.96, 0.90, 0.12),  ## SULFUR        — sulfur yellow sparkle
	27: Color(0.75, 0.55, 1.00),  ## QUARTZ        — lavender sparkle
	28: Color(0.82, 0.92, 1.00),  ## ROCK_SALT     — ice-blue sparkle
	30: Color(0.28, 0.95, 0.42),  ## FROG_SKIN     — vivid green sparkle
	34: Color(0.10, 0.96, 0.88),  ## GLOWING_MUSHROOM — cyan glow sparkle
}

## Time in seconds before a collected node respawns — 15 minutes.
const RESPAWN_TIME := 900.0

var _type: int = 0
var _active: bool = true
var _visual: CanvasItem = null
var _pulse_time: float = 0.0
var _base_tint: Color = Color.WHITE

func setup(node_type: int) -> void:
	_type = node_type
	input_pickable = true

	if not TYPE_CFG.has(_type):
		## Unsupported type — create invisible placeholder (should not occur in practice).
		return

	var cfg: Dictionary = TYPE_CFG[_type]
	var sp := Sprite2D.new()
	var tex: Texture2D = load(cfg.path)
	if tex != null:
		sp.texture = tex
	sp.scale    = Vector2(cfg.sx, cfg.sy)
	_base_tint  = Color(cfg.r, cfg.g, cfg.b)
	sp.modulate = _base_tint
	_visual     = sp
	add_child(sp)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cfg.hw * 2.0, cfg.hh * 2.0)
	col.shape  = shape
	add_child(col)

	## Rare-type sparkle — ambient CPUParticles2D to signal "worth collecting".
	if SPARKLE_TYPES.has(_type):
		_add_sparkle(SPARKLE_TYPES[_type])

	input_event.connect(_on_input_event)

## Gentle idle alpha pulse to draw the player's eye.
func _process(delta: float) -> void:
	if not _active or _visual == null:
		return
	_pulse_time += delta * 1.8
	var alpha: float = 0.78 + sin(_pulse_time) * 0.22
	_visual.modulate = Color(_base_tint.r, _base_tint.g, _base_tint.b, alpha)

## Returns the action label for the proximity interact button.
func get_interact_label() -> String:
	return "Recolter"

## Returns true when this node can be collected.
func is_interactable() -> bool:
	return _active

## Collect this node — called by proximity button or tap.
func interact() -> void:
	_collect()

## Fires when the player taps this Area2D.
func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and event.pressed:
		_collect()

## Called directly in unit tests to trigger collection without real input.
func _collect() -> void:
	if not _active:
		return
	if not TYPE_CFG.has(_type):
		return
	_active = false
	visible = false
	var base_amount: int = TYPE_CFG[_type].y
	## PrestigeSystem bonus yield: rare_resource_mult applied to all node types.
	var prestige_mult: float = PrestigeSystem.get_rare_resource_mult() if PrestigeSystem != null else 1.0
	## ALCHIMIE_BASIQUE skill: doubles herb/plant yield (all ResourceNode types are plant-based).
	var herb_mult: float = SkillTree.get_herb_yield_mult() if SkillTree != null else 1.0
	## HeroProgression rare chance bonus: adds a probabilistic extra item for rarer nodes.
	var extra: int = 0
	if HeroProgression != null:
		var rare_roll: float = randf()
		if rare_roll < HeroProgression.get_rare_chance_bonus():
			extra = 1
	var amount: int = roundi(float(base_amount) * prestige_mult * herb_mult) + extra
	ResourceInventory.add(_type, amount)
	## Schedule respawn after RESPAWN_TIME seconds (15 minutes).
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)

## Adds ambient sparkle particles around a rare resource node.
func _add_sparkle(sparkle_color: Color) -> void:
	var p := CPUParticles2D.new()
	p.emitting        = true
	p.amount          = 6
	p.lifetime        = 1.4
	p.explosiveness   = 0.0
	p.emission_shape  = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.color           = sparkle_color
	p.direction       = Vector2.UP
	p.spread          = 180.0
	p.gravity         = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	add_child(p)

## Restore the node after the respawn delay has elapsed.
func _respawn() -> void:
	_active = true
	_pulse_time = 0.0
	visible = true
