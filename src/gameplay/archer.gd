## Archer — formation unit visual
## GDD Req: TR-archer-001
##
## Minimal visual node placed by ArcherFormation at slot positions.
## No logic — movement and firing are orchestrated by ArcherFormation.
## Tier sprite prefixes: T0="archer", T1="archer_t1", T2="archer_t2", T3="archer_t3".
extends Node2D

var _anim: AnimatedSprite2D
var _visual_tier: int = -1  ## Cached tier to avoid redundant reloads

func _ready() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/garrison/shadow.png")
	shadow.position = Vector2(0.0, 28.0)
	shadow.scale = Vector2(1.3, 1.3)
	add_child(shadow)

	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2(0.52, 0.52)
	add_child(_anim)
	_load_frames(0)

## Reload walk animation frames for the given visual tier.
## Called by ArcherFormation when wave crosses a tier threshold.
func set_visual_tier(tier: int) -> void:
	if tier == _visual_tier:
		return
	_load_frames(tier)

func _load_frames(tier: int) -> void:
	_visual_tier = tier
	var prefix: String = "archer" if tier == 0 else ("archer_t%d" % clampi(tier, 1, 3))
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in range(4):
		var path: String = "res://assets/sprites/garrison/%s_%d.png" % [prefix, i]
		var tex: Texture2D = load(path)
		if tex == null:
			tex = load("res://assets/sprites/garrison/archer_%d.png" % i)
		frames.add_frame("walk", tex)
	if _anim != null:
		_anim.sprite_frames = frames
		_anim.play("walk")
