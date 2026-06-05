## HeroSpells — 3 active spell slots usable in Tower Defense and RPG modes.
## Spells are centered on the hero's current world position.
## ADR-002: enemy lookup uses get_nodes_in_group("enemies") — no physics queries.
## ADR-005: resets on session_reset signal.
##
## Spell index:
##   0 — Embrasement  : AoE fire damage,  radius 150px, 80 dmg,       cooldown 8s
##   1 — Foudre       : AoE stun,         radius 120px, 30 dmg + stop, cooldown 12s
##   2 — Vague de givre: AoE slow + dmg, radius 180px, 40 dmg + 70% slow, cooldown 10s
extends Node

## Spell definitions — index matches HUD button order (0=Embrasement, 1=Foudre, 2=Glace).
## slow_factor < 1.0 triggers apply_slow(); factor ≈ 0 acts as a stun.
const SPELLS := [
	{
		"name":          "Embrasement",
		"radius":        150.0,
		"damage":        80,
		"slow_factor":   1.0,    ## No slow — pure damage
		"slow_duration": 0.0,
		"cooldown":      8.0,
	},
	{
		"name":          "Foudre",
		"radius":        120.0,
		"damage":        30,
		"slow_factor":   0.001,  ## Effectively a stun — speed reduced to 0.1% of base
		"slow_duration": 2.5,    ## Stun duration in seconds
		"cooldown":      12.0,
	},
	{
		"name":          "Glace",
		"radius":        180.0,
		"damage":        40,
		"slow_factor":   0.30,   ## 70% speed reduction
		"slow_duration": 4.0,
		"cooldown":      10.0,
	},
]

## Emitted immediately after a spell fires — HUD uses this to trigger cooldown display.
signal spell_cast(spell_index: int)
## Emitted with world-space center so Main can spawn a VFX ring at the impact point.
signal spell_impact(spell_index: int, center: Vector2)

## Per-spell remaining cooldown in seconds. 0.0 = ready.
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]

## Optional SpellUpgradeTree reference — injected by Main after creation.
var _upgrade_tree: Node = null

## Inject the SpellUpgradeTree node so cast() can apply upgrade multipliers.
func set_upgrade_tree(tree: Node) -> void:
	_upgrade_tree = tree

func _ready() -> void:
	GameStateMachine.session_reset.connect(_on_session_reset)

## Returns true if the spell can be cast (cooldown has expired).
func is_ready(idx: int) -> bool:
	return _cooldowns[idx] <= 0.0

## Returns remaining cooldown seconds. Never negative.
func get_cooldown_remaining(idx: int) -> float:
	return maxf(_cooldowns[idx], 0.0)

## Cast the spell at hero_pos (world space).
## No-op when on cooldown or node is not in the scene tree (test guard).
func cast(idx: int, hero_pos: Vector2) -> void:
	if not is_ready(idx):
		return
	if not is_inside_tree():
		return
	var spell: Dictionary = SPELLS[idx]
	## Apply cooldown reduction from upgrade tree (Efficacite path)
	var cd_mult: float = 1.0
	if _upgrade_tree != null:
		var mults: Dictionary = _upgrade_tree.get_spell_mults(idx)
		cd_mult = float(mults.get("cd_mult", 1.0))
	_cooldowns[idx] = spell.cooldown * cd_mult
	_apply_spell(spell, hero_pos, idx)
	spell_cast.emit(idx)
	spell_impact.emit(idx, hero_pos)

## Apply spell effects to all active enemies within range.
## Uses the "enemies" group — works in TD mode and (Phase 3) RPG mode alike.
## idx is passed through to enable status effect overlay on each hit enemy.
func _apply_spell(spell: Dictionary, center: Vector2, idx: int) -> void:
	var radius: float  = spell.radius
	var dmg: int       = spell.damage
	## CRYSTAL_STAFF: look up the caster's _spell_dmg_mult via the "players" group
	var dmg_mult: float = 1.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		if player.get("_spell_dmg_mult") != null:
			dmg_mult = float(player.get("_spell_dmg_mult"))
			break
	dmg = roundi(float(dmg) * dmg_mult)
	## SpellUpgradeTree: apply damage and radius multipliers
	if _upgrade_tree != null:
		var mults: Dictionary = _upgrade_tree.get_spell_mults(idx)
		dmg = roundi(float(dmg) * float(mults.get("damage_mult", 1.0)))
		radius = radius * float(mults.get("radius_mult", 1.0))
	var slow_f: float  = spell.slow_factor
	var slow_d: float  = spell.slow_duration
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		## Skip inactive pooled nodes (deactivated but still in tree)
		if not enemy.get("_alive"):
			continue
		if enemy.position.distance_to(center) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
		## Apply slow/stun when spell has a duration (Foudre stun + Glace slow)
		if slow_d > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_f, slow_d)
		## Spell hit impact VFX sprite (fire/lightning/ice burst)
		if enemy.has_method("show_spell_hit_effect"):
			enemy.show_spell_hit_effect(idx)
		## Status effect visual overlay on hit enemy
		if enemy.has_method("show_status_effect"):
			var effect_dur: float = slow_d if slow_d > 0.0 else 2.0
			enemy.show_status_effect(idx, effect_dur)

func _process(delta: float) -> void:
	if GameStateMachine.current_state == GameStateMachine.State.GAME_OVER:
		return
	for i: int in range(_cooldowns.size()):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)

## Reset all cooldowns on session restart.
func _on_session_reset() -> void:
	for i: int in range(_cooldowns.size()):
		_cooldowns[i] = 0.0
