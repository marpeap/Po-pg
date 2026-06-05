## Castle — HP tracking + Area2D contact zone
## ADR-002: Area2D overlap only (no physics bodies)
## ADR-005: GameStateMachine integration
## GDD Req: TR-castle-001
##
## The castle takes damage when enemies enter its Area2D.
## At 0 HP, emits castle_fell and triggers GAME_OVER state.
extends Node2D

const CASTLE_MAX_HP := 200
## World-space position of the castle — left-center in landscape world 1920×1080
const CASTLE_POS := Vector2(200.0, 540.0)
## Damage dealt per enemy contact
const CASTLE_DMG := 8
## HP regenerated per second — 1.5% of max HP
const REGEN_RATE := 0.015

## Emitted on every take_damage() call with the new HP value.
signal hp_changed(new_hp: int)
## Emitted when the maximum HP ceiling changes (Forge HP upgrade or Stone resource bonus).
signal max_hp_changed(new_max: int)
## Emitted exactly once when HP reaches 0.
signal castle_fell
## Emitted whenever take_damage() deals actual damage (not regen). Used for screen shake.
signal castle_hit

## Current castle HP. Read by HUD; written only via take_damage().
var castle_hp: int = CASTLE_MAX_HP
## Runtime max HP — starts at CASTLE_MAX_HP, raised by Forge HP upgrades. Session-scoped.
var _max_hp: int = CASTLE_MAX_HP
## Regen multiplier — set to 3.0 by Healing Ward crafted item, else 1.0. Reset on session_reset.
var _regen_bonus_mult: float = 1.0
## Permanent regen multiplier from quest/NPC rewards. NOT reset on session_reset.
var _quest_regen_mult: float = 1.0
## Flat damage reduction per hit — set to 2 by Iron Gate crafted item, else 0.
var _damage_reduction: int = 0
## DEFENSIVE_MOAT: slow enemies within MOAT_RADIUS by 30%. Applied on return from exploration.
var _has_defensive_moat: bool = false
const MOAT_RADIUS := 180.0
var _sprite: Sprite2D

func _ready() -> void:
	position = CASTLE_POS
	## Join "castle" group so WorldBoss (Ignifex eruption ability) and other systems
	## can deal damage via call_group("castle", "take_damage", amount).
	add_to_group("castle")
	GameStateMachine.session_reset.connect(_on_session_reset)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/garrison/castle.png")
	_sprite.scale = Vector2(0.85, 0.85)
	add_child(_sprite)

## Regenerate 1.5% of max HP per second whenever below full HP.
func _process(delta: float) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return

	## DEFENSIVE_MOAT: continuously slow enemies within MOAT_RADIUS by 30%.
	if _has_defensive_moat:
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if enemy.has_method("apply_slow") and enemy.position.distance_to(position) <= MOAT_RADIUS:
				enemy.apply_slow(0.70, 0.6)  ## 30% slow, refreshed every frame

	if castle_hp >= _max_hp:
		return
	var regen: int = floori(float(_max_hp) * REGEN_RATE * _regen_bonus_mult * _quest_regen_mult * delta)
	if regen <= 0:
		return
	castle_hp = mini(castle_hp + regen, _max_hp)
	hp_changed.emit(castle_hp)
	_update_sprite_color()

## Called by enemy's area_entered signal (via EnemyWave/Main wiring).
## Ignored if the game is not in PLAYING state (prevents double-kills).
func take_damage(amount: int) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	castle_hp = max(castle_hp - maxi(amount - _damage_reduction, 1), 0)
	hp_changed.emit(castle_hp)
	castle_hit.emit()
	_update_sprite_color()
	if castle_hp <= 0:
		castle_fell.emit()
		GameStateMachine.request_game_over()

## Called by Main when Forge HP zone purchase fires — increases max (and current) HP.
## GDD forge.md F4: each purchase adds FORGE_HP_DELTA (30) HP to the ceiling.
func increase_max_hp(amount: int) -> void:
	_max_hp += amount
	castle_hp = mini(castle_hp + amount, _max_hp)
	max_hp_changed.emit(_max_hp)
	hp_changed.emit(castle_hp)
	_update_sprite_color()

func _on_session_reset() -> void:
	_max_hp = CASTLE_MAX_HP
	castle_hp = CASTLE_MAX_HP
	_regen_bonus_mult = 1.0
	_damage_reduction = 0
	_has_defensive_moat = false
	max_hp_changed.emit(_max_hp)
	hp_changed.emit(castle_hp)
	_update_sprite_color()

## Tint the castle sprite based on HP ratio: white → amber → red
func _update_sprite_color() -> void:
	if _sprite == null:
		return
	var ratio: float = float(castle_hp) / float(_max_hp)
	if ratio >= 0.6:
		_sprite.modulate = Color.WHITE
	elif ratio >= 0.3:
		_sprite.modulate = Color("#FFC107")
	else:
		_sprite.modulate = Color("#F44336")

## Update castle sprite to wave-tier-appropriate texture.
## Tier 0 = castle.png baseline; T1–T3 = castle_t1/t2/t3.png.
## Called by Main._on_wave_visual_tier_update when wave crosses threshold.
func set_visual_tier(tier: int) -> void:
	if _sprite == null:
		return
	var tex: Texture2D = null
	if tier > 0:
		tex = load("res://assets/sprites/garrison/castle_t%d.png" % clampi(tier, 1, 3))
	if tex == null:
		tex = load("res://assets/sprites/garrison/castle.png")
	_sprite.texture = tex
