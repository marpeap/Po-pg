## CraftingSystem — pure data + logic, no visual dependencies.
## Holds all 27 recipe definitions and exposes can_craft() / craft() methods.
## Instantiated once per exploration session by CraftingAnvil.
## Emits no signals — delegates to ItemInventory.receive_item() on success.
extends Node

## Recipe structure: { id, name, category, ingredients: [[type, amount]...], description }
## category: 0=weapon, 1=armor, 2=archers, 3=towers, 4=castle, 5=consumable

const RECIPES: Array = [
	## ── Hero Weapons ──────────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.IRON_SWORD,
		"name": "Épée de fer",
		"category": 0,
		"description": "ATK héros +5. Frappe en arc 60° (3 ennemis simultanés).",
		"ingredients": [
			[ResourceInventory.Type.IRON_ORE, 3],
			[ResourceInventory.Type.COAL,     1],
		],
	},
	{
		"id": ItemInventory.Item.CRYSTAL_STAFF,
		"name": "Bâton de cristal",
		"category": 0,
		"description": "Sorts +30% DMG. Recharges sorts -20%.",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL, 2],
			[ResourceInventory.Type.GEMSTONE, 1],
		],
	},
	{
		"id": ItemInventory.Item.BONE_BOW,
		"name": "Arc en os",
		"category": 0,
		"description": "Portée auto-attaque 130→200px.",
		"ingredients": [
			[ResourceInventory.Type.WOOD, 2],
			[ResourceInventory.Type.BONE, 2],
		],
	},
	{
		"id": ItemInventory.Item.VENOM_BLADE,
		"name": "Lame de venin",
		"category": 0,
		"description": "Attaques empoisonnent (3/s pendant 4s).",
		"ingredients": [
			[ResourceInventory.Type.IRON_ORE, 1],
			[ResourceInventory.Type.MUSHROOM, 2],
		],
	},
	## ── Hero Armor ────────────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.HIDE_JERKIN,
		"name": "Veste de cuir",
		"category": 1,
		"description": "HP max héros +20.",
		"ingredients": [
			[ResourceInventory.Type.HIDE, 3],
		],
	},
	{
		"id": ItemInventory.Item.SILK_CLOAK,
		"name": "Cape de soie",
		"category": 1,
		"description": "Rayon d'aggro ennemis -35% (discrétion).",
		"ingredients": [
			[ResourceInventory.Type.SILK, 2],
			[ResourceInventory.Type.HERB, 1],
		],
	},
	{
		"id": ItemInventory.Item.CRYSTAL_AMULET,
		"name": "Amulette de cristal",
		"category": 1,
		"description": "Régénération HP héros : 1 HP toutes les 4s en exploration.",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL, 1],
			[ResourceInventory.Type.HERB,    1],
		],
	},
	{
		"id": ItemInventory.Item.SHADOW_MAIL,
		"name": "Armure d'ombre",
		"category": 1,
		"description": "Dégâts reçus par le héros -40%.",
		"ingredients": [
			[ResourceInventory.Type.SHADOW_ESSENCE, 2],
			[ResourceInventory.Type.HIDE,           2],
		],
	},
	## ── Archer Equipment ──────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.IRON_ARROWHEADS,
		"name": "Pointes de fer",
		"category": 2,
		"description": "DMG flèche archer +8.",
		"ingredients": [
			[ResourceInventory.Type.IRON_ORE, 2],
			[ResourceInventory.Type.COAL,     1],
		],
	},
	{
		"id": ItemInventory.Item.SILK_QUIVER,
		"name": "Carquois de soie",
		"category": 2,
		"description": "Vitesse flèche +30%. Portée archer +20px.",
		"ingredients": [
			[ResourceInventory.Type.SILK, 2],
		],
	},
	{
		"id": ItemInventory.Item.POISON_QUIVER,
		"name": "Carquois empoisonné",
		"category": 2,
		"description": "25% des flèches empoisonnent (2/s, 3s).",
		"ingredients": [
			[ResourceInventory.Type.MUSHROOM, 2],
			[ResourceInventory.Type.HERB,     1],
		],
	},
	{
		"id": ItemInventory.Item.FIRE_QUIVER,
		"name": "Carquois de feu",
		"category": 2,
		"description": "Flèches enflamment (3/s, 3s de brûlure).",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL, 2],
			[ResourceInventory.Type.COAL,    1],
		],
	},
	{
		"id": ItemInventory.Item.HEAVY_BROADHEAD,
		"name": "Pointe lourde",
		"category": 2,
		"description": "DMG flèche +15. Cadence de tir -10%.",
		"ingredients": [
			[ResourceInventory.Type.IRON_ORE, 3],
			[ResourceInventory.Type.BONE,     1],
		],
	},
	{
		"id": ItemInventory.Item.FORMATION_BANNER,
		"name": "Bannière de formation",
		"category": 2,
		"description": "Stabilité formation +20%. Repositionnement +30% plus rapide.",
		"ingredients": [
			[ResourceInventory.Type.SILK,     2],
			[ResourceInventory.Type.HARDWOOD, 1],
		],
	},
	## ── Tower Upgrades ────────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.BALLISTA_KIT,
		"name": "Kit baliste",
		"category": 3,
		"description": "Portée toutes tours +200px.",
		"ingredients": [
			[ResourceInventory.Type.HARDWOOD, 2],
			[ResourceInventory.Type.IRON_ORE, 2],
		],
	},
	{
		"id": ItemInventory.Item.EXPLOSIVE_TIPS,
		"name": "Pointes explosives",
		"category": 3,
		"description": "Flèches tours : explosion 30px au contact.",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL,  2],
			[ResourceInventory.Type.IRON_ORE, 1],
		],
	},
	{
		"id": ItemInventory.Item.TARGETING_RUNE,
		"name": "Rune de ciblage",
		"category": 3,
		"description": "Tours ciblent l'ennemi au plus haut HP en priorité.",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL, 1],
			[ResourceInventory.Type.GEMSTONE, 1],
		],
	},
	{
		"id": ItemInventory.Item.POWER_CORE,
		"name": "Noyau de pouvoir",
		"category": 3,
		"description": "Pouvoirs élémentaires tours gratuits (plus 150g).",
		"ingredients": [
			[ResourceInventory.Type.CRYSTAL,        2],
			[ResourceInventory.Type.SHADOW_ESSENCE, 1],
		],
	},
	{
		"id": ItemInventory.Item.REINFORCED_PLATFORM,
		"name": "Plateforme renforcée",
		"category": 3,
		"description": "Tours : +100 HP effectif (résistance aux dégâts).",
		"ingredients": [
			[ResourceInventory.Type.STONE, 3],
			[ResourceInventory.Type.WOOD,  2],
		],
	},
	## ── Castle Defenses ───────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.STONE_WALL,
		"name": "Mur de pierre",
		"category": 4,
		"description": "HP max château +60 (appliqué au retour).",
		"ingredients": [
			[ResourceInventory.Type.STONE,    6],
			[ResourceInventory.Type.IRON_ORE, 2],
		],
	},
	{
		"id": ItemInventory.Item.HEALING_WARD,
		"name": "Chambre de guérison",
		"category": 4,
		"description": "Régénération château ×3 (appliqué au retour).",
		"ingredients": [
			[ResourceInventory.Type.HERB,    3],
			[ResourceInventory.Type.CRYSTAL, 2],
		],
	},
	{
		"id": ItemInventory.Item.IRON_GATE,
		"name": "Grille de fer",
		"category": 4,
		"description": "Château absorbe 2 dégâts par coup (appliqué au retour).",
		"ingredients": [
			[ResourceInventory.Type.IRON_ORE, 3],
			[ResourceInventory.Type.COAL,     2],
		],
	},
	{
		"id": ItemInventory.Item.DEFENSIVE_MOAT,
		"name": "Fossé défensif",
		"category": 4,
		"description": "Ennemis proches du château ralentis -30% (appliqué au retour).",
		"ingredients": [
			[ResourceInventory.Type.STONE, 4],
			[ResourceInventory.Type.WOOD,  2],
		],
	},
	## ── Consumables ───────────────────────────────────────────────────────
	{
		"id": ItemInventory.Item.HEALTH_POTION,
		"name": "Potion de soin",
		"category": 5,
		"description": "Héros +30 HP instantané.",
		"ingredients": [
			[ResourceInventory.Type.HERB,     2],
			[ResourceInventory.Type.MUSHROOM, 1],
		],
	},
	{
		"id": ItemInventory.Item.MEGA_POTION,
		"name": "Méga-potion",
		"category": 5,
		"description": "Héros restauré au maximum de HP.",
		"ingredients": [
			[ResourceInventory.Type.HERB,    4],
			[ResourceInventory.Type.CRYSTAL, 2],
		],
	},
	{
		"id": ItemInventory.Item.SPEED_ELIXIR,
		"name": "Élixir de vitesse",
		"category": 5,
		"description": "Vitesse héros ×1.5 pendant 20s.",
		"ingredients": [
			[ResourceInventory.Type.SILK,     2],
			[ResourceInventory.Type.MUSHROOM, 1],
		],
	},
	{
		"id": ItemInventory.Item.SMOKE_BOMB,
		"name": "Fumigène",
		"category": 5,
		"description": "Annule l'aggro de tous les ennemis dans 250px pendant 5s.",
		"ingredients": [
			[ResourceInventory.Type.SILK, 2],
			[ResourceInventory.Type.COAL, 1],
		],
	},
]

## Category display names (French)
const CATEGORY_NAMES: Array[String] = [
	"Armes héros", "Armure héros", "Archers", "Tours", "Château", "Consommables"
]

## Returns true if the player has all ingredients for the recipe at [param recipe_idx].
func can_craft(recipe_idx: int) -> bool:
	if recipe_idx < 0 or recipe_idx >= RECIPES.size():
		return false
	var recipe: Dictionary = RECIPES[recipe_idx]
	for ing: Array in recipe["ingredients"]:
		if not ResourceInventory.has_enough(ing[0], ing[1]):
			return false
	return true

## Spend ingredients and deliver the item to ItemInventory.
## Returns false if ingredients are missing.
func craft(recipe_idx: int) -> bool:
	if not can_craft(recipe_idx):
		return false
	var recipe: Dictionary = RECIPES[recipe_idx]
	for ing: Array in recipe["ingredients"]:
		ResourceInventory.spend(ing[0], ing[1])
	ItemInventory.receive_item(recipe["id"])
	return true

## Returns a list of recipe indices belonging to [param category] (0-5).
func get_by_category(category: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(RECIPES.size()):
		if RECIPES[i]["category"] == category:
			result.append(i)
	return result
