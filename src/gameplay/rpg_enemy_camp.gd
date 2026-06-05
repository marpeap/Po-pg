## RpgEnemyCamp — manages a cluster of RPGEnemy nodes in the exploration map.
## Supports three difficulty tiers that scale enemy count, HP, speed and reward.
## When all enemies die, emits reward_earned and spawns a TreasureChest.
extends Node

## Difficulty tiers — passed as integer 0/1/2 to setup().
const TIER_ENEMY_COUNT: Array[int]  = [3,    4,    5   ]
const TIER_GOLD_REWARD: Array[int]  = [25,   40,   60  ]
const TIER_HP_MULT:     Array[float] = [1.0,  1.4,  2.0 ]
const TIER_SPEED_MULT:  Array[float] = [1.0,  1.15, 1.35]
## Visual accent colors per tier (used to tint the camp marker)
const TIER_COLORS: Array[Color] = [
	Color(0.60, 0.12, 0.12, 0.70),  ## Tier 0 — red
	Color(0.70, 0.35, 0.05, 0.75),  ## Tier 1 — orange
	Color(0.50, 0.05, 0.50, 0.80),  ## Tier 2 — purple (elite)
]

## Emitted once when the last camp enemy dies.
signal reward_earned(gold: int)
## Emitted with position so exploration_map can spawn a chest there.
signal cleared(camp_pos: Vector2, gold: int)

var _alive_count: int = 0
var _rewarded: bool = false
var _camp_pos: Vector2 = Vector2.ZERO
var _tier: int = 0

## Loot tables per tier — each entry [ResourceInventory.Type, amount, probability].
## Tier 0 (easy): common drops (Bone, occasionally Hide)
## Tier 1 (medium): common + Hide, small Crystal chance
## Tier 2 (hard/elite): Hide, Crystal, Shadow Essence guaranteed
const TIER_LOOT: Array = [
	[  ## Tier 0
		[ResourceInventory.Type.BONE, 1, 0.70],
		[ResourceInventory.Type.HIDE, 1, 0.30],
	],
	[  ## Tier 1
		[ResourceInventory.Type.BONE,    1, 0.80],
		[ResourceInventory.Type.HIDE,    1, 0.55],
		[ResourceInventory.Type.CRYSTAL, 1, 0.25],
	],
	[  ## Tier 2
		[ResourceInventory.Type.BONE,           1, 0.90],
		[ResourceInventory.Type.HIDE,           1, 0.80],
		[ResourceInventory.Type.CRYSTAL,        1, 0.60],
		[ResourceInventory.Type.SHADOW_ESSENCE, 1, 1.00],
	],
]

## [param tier] 0 = easy, 1 = medium, 2 = hard/elite.
func setup(camp_pos: Vector2, hero: Node2D, parent: Node, tier: int = 0) -> void:
	_camp_pos = camp_pos
	_tier = clampi(tier, 0, 2)
	var count: int = TIER_ENEMY_COUNT[_tier]
	## Tier-2 camps include 1 healer — add it to the alive count
	var has_healer: bool = (_tier == 2)
	_alive_count = count + (1 if has_healer else 0)
	var enemy_script: GDScript = load("res://src/gameplay/rpg_enemy.gd")
	var loot: Array = TIER_LOOT[_tier]
	for i: int in range(count):
		var enemy: Area2D = Area2D.new()
		enemy.set_script(enemy_script)
		parent.add_child(enemy)
		enemy._visual_type = _tier  ## 0=Infantry, 1=Archer, 2=Elite sprite
		enemy.setup(camp_pos, hero)
		## Apply tier scaling after setup() to override base stats
		enemy.hp        = roundi(float(enemy.hp)    * TIER_HP_MULT[_tier])
		enemy._max_hp   = enemy.hp
		enemy._speed_mult = TIER_SPEED_MULT[_tier]
		enemy._loot_table = loot
		enemy.died.connect(_on_enemy_died)
	## Tier-2 camps: spawn 1 healer that sustains the group
	if has_healer:
		var healer: Area2D = Area2D.new()
		healer.set_script(load("res://src/gameplay/rpg_healer.gd"))
		parent.add_child(healer)
		healer._loot_table = [
			[ResourceInventory.Type.HERB,    1, 0.90],
			[ResourceInventory.Type.CRYSTAL, 1, 0.40],
		]
		healer.setup(camp_pos, hero)
		healer.died.connect(_on_enemy_died)

func _on_enemy_died(_pos: Vector2) -> void:
	_alive_count -= 1
	if _alive_count <= 0 and not _rewarded:
		_rewarded = true
		var gold: int = TIER_GOLD_REWARD[_tier]
		reward_earned.emit(gold)
		cleared.emit(_camp_pos, gold)
