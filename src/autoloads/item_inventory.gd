## ItemInventory — Autoload singleton
## Tracks all crafted items and their active effects for the current session.
## Items are divided into four categories:
##   - Equipment (hero weapon / hero armor): one slot each, latest craft replaces previous
##   - Persistent buffs (archers, towers, castle): stack additively per craft
##   - Consumables: quantity-tracked, used on demand during exploration
##
## Emits item_crafted(item_id) so Main.gd can route effects to the right nodes.
## Resets on session_reset.
extends Node

## Item IDs — match indices in CraftingSystem.RECIPES.
## Grouped by category for readability.
enum Item {
	## Hero weapons (slot: hero_weapon)
	IRON_SWORD        = 0,
	CRYSTAL_STAFF     = 1,
	BONE_BOW          = 2,
	VENOM_BLADE       = 3,
	## Hero armor (slot: hero_armor)
	HIDE_JERKIN       = 4,
	SILK_CLOAK        = 5,
	CRYSTAL_AMULET    = 6,
	SHADOW_MAIL       = 7,
	## Archer equipment (global persistent buff)
	IRON_ARROWHEADS   = 8,
	SILK_QUIVER       = 9,
	POISON_QUIVER     = 10,
	FIRE_QUIVER       = 11,
	HEAVY_BROADHEAD   = 12,
	FORMATION_BANNER  = 13,
	## Tower upgrades (global persistent buff)
	BALLISTA_KIT      = 14,
	EXPLOSIVE_TIPS    = 15,
	TARGETING_RUNE    = 16,
	POWER_CORE        = 17,
	REINFORCED_PLATFORM = 18,
	## Castle defenses (applied on return)
	STONE_WALL        = 19,
	HEALING_WARD      = 20,
	IRON_GATE         = 21,
	DEFENSIVE_MOAT    = 22,
	## Consumables
	HEALTH_POTION     = 23,
	MEGA_POTION       = 24,
	SPEED_ELIXIR      = 25,
	SMOKE_BOMB        = 26,
	## Mount
	MOUNT_SCROLL      = 28,
}

const ITEM_COUNT := 29

## Human-readable names (French)
## Indices 0-26: items existants. Index 27: réservé (gap). Index 28: MOUNT_SCROLL.
const NAMES: Array[String] = [
	"Épée de fer", "Bâton de cristal", "Arc en os", "Lame de venin",
	"Veste de cuir", "Cape de soie", "Amulette de cristal", "Armure d'ombre",
	"Pointes de fer", "Carquois de soie", "Carquois empoisonné", "Carquois de feu",
	"Pointe lourde", "Bannière de formation",
	"Kit baliste", "Pointes explosives", "Rune de ciblage", "Noyau de pouvoir",
	"Plateforme renforcée",
	"Mur de pierre", "Chambre de guérison", "Grille de fer", "Fossé défensif",
	"Potion de soin", "Méga-potion", "Élixir de vitesse", "Fumigène",
	"(réservé)",
	"Parchemin de Monture",
]

## Highest consumable item ID (IDs 23-26 are consumables; 27-28 are NOT consumables).
const _CONSUMABLE_MAX := 26

## Emitted when any item is crafted. Main.gd routes to the correct gameplay node.
signal item_crafted(item_id: int)
## Emitted when a consumable is used (for UI update).
signal consumable_used(item_id: int, remaining: int)

## Equipped slots (hero) — -1 means nothing equipped.
var hero_weapon: int = -1
var hero_armor:  int = -1

## Persistent buff flags — true once the item has been crafted this session.
## Multiple crafts of the same buff item do NOT stack (one-shot upgrades).
var _crafted: Array[bool] = []

## Consumable quantities (only meaningful for item IDs 23-26).
var _consumables: Array[int] = [0, 0, 0, 0]  ## indexed [potion, mega, elixir, smoke]
const _CONSUMABLE_BASE := 23  ## first consumable item ID
## _CONSUMABLE_MAX defined above alongside NAMES.

func _ready() -> void:
	_crafted.resize(ITEM_COUNT)
	_crafted.fill(false)
	GameStateMachine.session_reset.connect(_on_session_reset)

## Mark an item as crafted and emit the signal for effect application.
## For consumables (IDs 23-26), increments quantity.
## For equipment/buffs/mount (IDs 0-22 + 27-28), records ownership in _crafted.
func receive_item(item_id: int) -> void:
	if item_id < 0 or item_id >= ITEM_COUNT:
		return
	if item_id >= _CONSUMABLE_BASE and item_id <= _CONSUMABLE_MAX:
		## Consumable item — increment quantity.
		var idx: int = item_id - _CONSUMABLE_BASE
		_consumables[idx] += 1
	else:
		## Persistent buff, equipment, or mount — record in _crafted.
		_crafted[item_id] = true
		## Equip weapons/armor automatically (replace previous).
		if item_id <= Item.VENOM_BLADE:
			hero_weapon = item_id
		elif item_id <= Item.SHADOW_MAIL:
			hero_armor = item_id
	item_crafted.emit(item_id)

## Returns true if the given persistent item has been crafted this session.
func has_item(item_id: int) -> bool:
	if item_id < 0 or item_id >= ITEM_COUNT:
		return false
	if item_id >= _CONSUMABLE_BASE and item_id <= _CONSUMABLE_MAX:
		return _consumables[item_id - _CONSUMABLE_BASE] > 0
	return _crafted[item_id]

## Returns quantity for a consumable item (IDs 23-26). Returns 0 otherwise.
func consumable_count(item_id: int) -> int:
	if item_id < _CONSUMABLE_BASE or item_id > _CONSUMABLE_MAX:
		return 0
	return _consumables[item_id - _CONSUMABLE_BASE]

## Use one consumable. Returns false if none available.
func use_consumable(item_id: int) -> bool:
	if item_id < _CONSUMABLE_BASE or item_id > _CONSUMABLE_MAX:
		return false
	var idx: int = item_id - _CONSUMABLE_BASE
	if _consumables[idx] <= 0:
		return false
	_consumables[idx] -= 1
	consumable_used.emit(item_id, _consumables[idx])
	return true

func _on_session_reset() -> void:
	hero_weapon = -1
	hero_armor  = -1
	_crafted.fill(false)
	_consumables.fill(0)
