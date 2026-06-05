## SpellUpgradeTree — arbre d'ameliorations pour les 3 sorts du heros.
## Chaque sort a 3 chemins d'upgrade (Puissance / Zone / Efficacite).
## Chaque chemin a 3 niveaux. Le joueur ne peut choisir qu'un chemin par sort.
## Couts: ressources depuis ResourceInventory (get_count / spend API).
## Persistance: session uniquement.
extends Node

## Upgrade paths per spell.
## path 0 = Puissance (dommages), path 1 = Zone (rayon), path 2 = Efficacite (CD reduit)
## spell_upgrades[spell_idx][path_idx] = current_level (0-3)
var spell_upgrades: Array = [
	[0, 0, 0],  ## Embrasement
	[0, 0, 0],  ## Foudre
	[0, 0, 0],  ## Glace
]
## Which path is chosen per spell (-1 = none yet)
var chosen_path: Array[int] = [-1, -1, -1]

signal upgrade_applied(spell_idx: int, path_idx: int, level: int)

func _ready() -> void:
	GameStateMachine.session_reset.connect(reset)

## Couts en ressources pour chaque niveau d'upgrade.
## Format: [[type_int, qty], ...]
## type 7 = Cristal, type 42 = Lichen Arg., type 12 = Ombre
const UPGRADE_COSTS: Array = [
	## Level 1
	[[7, 2]],
	## Level 2
	[[7, 4], [42, 1]],
	## Level 3
	[[7, 6], [12, 1]],
]

## Multiplicateurs appliques par path et niveau.
## path 0 (Puissance): [damage_mult, radius_mult, cd_mult]
## path 1 (Zone): [damage_mult, radius_mult, cd_mult]
## path 2 (Efficacite): [damage_mult, radius_mult, cd_mult]
const PATH_MULTS: Array = [
	## path 0 — Puissance: +40% dmg par niveau
	[[1.40, 1.0, 1.0], [1.80, 1.0, 1.0], [2.20, 1.0, 1.0]],
	## path 1 — Zone: +30% rayon par niveau
	[[1.0, 1.30, 1.0], [1.0, 1.60, 1.0], [1.0, 1.90, 1.0]],
	## path 2 — Efficacite: -20% CD par niveau (mult 0.80, 0.65, 0.50)
	[[1.0, 1.0, 0.80], [1.0, 1.0, 0.65], [1.0, 1.0, 0.50]],
]

const PATH_NAMES: Array[String] = ["Puissance", "Zone", "Efficacite"]
const SPELL_NAMES: Array[String] = ["Embrasement", "Foudre", "Glace"]

## Try to apply an upgrade. Returns true if successful.
func try_upgrade(spell_idx: int, path_idx: int) -> bool:
	if spell_idx < 0 or spell_idx > 2:
		return false
	if path_idx < 0 or path_idx > 2:
		return false
	## If a different path is already chosen for this spell, refuse
	var current_path: int = chosen_path[spell_idx]
	if current_path != -1 and current_path != path_idx:
		return false
	var current_level: int = spell_upgrades[spell_idx][path_idx]
	if current_level >= 3:
		return false
	## Check cost
	var cost: Array = UPGRADE_COSTS[current_level]
	for entry: Array in cost:
		var res_type: int = entry[0]
		var qty: int = entry[1]
		if ResourceInventory.get_count(res_type) < qty:
			return false
	## Deduct cost
	for entry: Array in cost:
		ResourceInventory.spend(entry[0], entry[1])
	## Apply
	spell_upgrades[spell_idx][path_idx] += 1
	chosen_path[spell_idx] = path_idx
	upgrade_applied.emit(spell_idx, path_idx, spell_upgrades[spell_idx][path_idx])
	return true

## Get the current multipliers for a spell (aggregated from chosen upgrade path).
func get_spell_mults(spell_idx: int) -> Dictionary:
	var result: Dictionary = {"damage_mult": 1.0, "radius_mult": 1.0, "cd_mult": 1.0}
	var path: int = chosen_path[spell_idx]
	if path == -1:
		return result
	var level: int = spell_upgrades[spell_idx][path]
	if level <= 0:
		return result
	var mults: Array = PATH_MULTS[path][level - 1]
	result["damage_mult"] = mults[0]
	result["radius_mult"] = mults[1]
	result["cd_mult"] = mults[2]
	return result

## Can the player afford this upgrade?
func can_afford(spell_idx: int, path_idx: int) -> bool:
	var level: int = spell_upgrades[spell_idx][path_idx]
	if level >= 3:
		return false
	var cost: Array = UPGRADE_COSTS[level]
	for entry: Array in cost:
		if ResourceInventory.get_count(entry[0]) < entry[1]:
			return false
	return true

## Returns a display string for the cost of the next level of a path.
func get_upgrade_cost_text(spell_idx: int, path_idx: int) -> String:
	var level: int = spell_upgrades[spell_idx][path_idx]
	if level >= 3:
		return "MAX"
	var cost: Array = UPGRADE_COSTS[level]
	var parts: Array[String] = []
	for entry: Array in cost:
		parts.append("%dx[%d]" % [entry[1], entry[0]])
	return ", ".join(parts)

## Reset all upgrades on session restart.
func reset() -> void:
	spell_upgrades = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
	chosen_path = [-1, -1, -1]
