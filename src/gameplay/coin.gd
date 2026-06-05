## Coin — pooled collectible dropped on enemy death
## ADR-003: Object pool — no instantiate() during gameplay
## ADR-002: Area2D overlap only
## GDD Req: TR-economy-001
##
## Coin sits at the drop position until Economy's magnet logic moves it.
## Economy calls return_node() after collection.
extends Area2D

## Gold value this coin awards on collection. Set by activate().
var gold_value: int = 15

var _active: bool = false
var _visual_tier: int = -1   ## Cached tier — avoids reloading texture when tier unchanged
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/coin.png")
	_sprite.scale = Vector2(0.52, 0.52)
	add_child(_sprite)
	deactivate()

## Pool API — place and show coin at drop_pos with given value.
## visual_tier: 0=Gold 1=Crystal Rune 2=Circuit Token 3=Plasma Orb.
func activate(drop_pos: Vector2, value: int, visual_tier: int = 0) -> void:
	position = drop_pos
	gold_value = value
	if visual_tier != _visual_tier:
		_visual_tier = visual_tier
		if visual_tier > 0 and _sprite != null:
			var tier_path: String = "res://assets/sprites/garrison/coin_t%d.png" % clampi(visual_tier, 1, 3)
			var tex: Texture2D = load(tier_path)
			if tex != null:
				_sprite.texture = tex
	_active = true
	$CollisionShape2D.set_deferred("disabled", false)
	show()

## Pool API — hide and disable. Called by Economy after collection or on session reset.
func deactivate() -> void:
	_active = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	hide()

func is_active() -> bool:
	return _active

