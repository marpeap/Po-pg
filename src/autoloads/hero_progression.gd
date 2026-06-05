## HeroProgression — Autoload singleton
## Persistent hero XP, levels 1-50, zone mastery, discoveries.
## Saved via ConfigFile to user://hero_progress.cfg.
## ADR-009 post-MVP exception: ConfigFile allowed for hero persistence.
extends Node

signal level_up(new_level: int)
signal xp_gained(amount: int, total: int)
signal discovery_registered(total: int)
signal zone_cleared(zone_idx: int, clear_count: int)

const SAVE_PATH := "user://hero_progress.cfg"
const MAX_LEVEL := 50

## XP required to reach each level (index = level, value = cumulative XP needed).
## Level 1 = 0 XP. Level 50 = ~500k XP.
const XP_TABLE: Array[int] = [
	0,       ## Level 1
	100,     ## Level 2
	250,     ## Level 3
	450,     ## Level 4
	700,     ## Level 5
	1000,    ## Level 6
	1350,    ## Level 7
	1750,    ## Level 8
	2200,    ## Level 9
	2700,    ## Level 10
	3300,    ## Level 11
	4000,    ## Level 12
	4800,    ## Level 13
	5700,    ## Level 14
	6700,    ## Level 15
	7900,    ## Level 16
	9200,    ## Level 17
	10700,   ## Level 18
	12400,   ## Level 19
	14300,   ## Level 20
	16500,   ## Level 21
	19000,   ## Level 22
	21800,   ## Level 23
	24900,   ## Level 24
	28300,   ## Level 25
	32100,   ## Level 26
	36300,   ## Level 27
	41000,   ## Level 28
	46200,   ## Level 29
	52000,   ## Level 30
	58500,   ## Level 31
	65700,   ## Level 32
	73700,   ## Level 33
	82600,   ## Level 34
	92500,   ## Level 35
	103500,  ## Level 36
	115700,  ## Level 37
	129200,  ## Level 38
	144100,  ## Level 39
	160500,  ## Level 40
	178500,  ## Level 41
	198200,  ## Level 42
	219700,  ## Level 43
	243100,  ## Level 44
	268500,  ## Level 45
	296000,  ## Level 46
	325700,  ## Level 47
	357700,  ## Level 48
	392100,  ## Level 49
	429000,  ## Level 50 (cap)
]

## Zone mastery: clear count per zone (15 zones).
var zone_clears: Array[int] = []
## Total unique discoveries (caves, hidden items, secret areas).
var discoveries_found: int = 0
## Current hero level (1-50).
var hero_level: int = 1
## Current total accumulated XP.
var hero_xp: int = 0

func _ready() -> void:
	zone_clears.resize(15)
	zone_clears.fill(0)
	_load()

## Add XP and check for level-up. Called from ResourceInventory and gameplay events.
func add_xp(amount: int) -> void:
	if hero_level >= MAX_LEVEL:
		return
	var season_mult: float = SeasonManager.get_xp_multiplier() if SeasonManager != null else 1.0
	var prestige_mult: float = PrestigeSystem.get_xp_mult() if PrestigeSystem != null else 1.0
	var effective: int = roundi(float(amount) * season_mult * prestige_mult)
	hero_xp += effective
	xp_gained.emit(effective, hero_xp)
	## Check for level-up(s) — multiple levels possible in one call.
	while hero_level < MAX_LEVEL and hero_xp >= XP_TABLE[hero_level]:
		hero_level += 1
		level_up.emit(hero_level)
	_save()

## Register a discovery (cave, shrine, hidden chest, secret area).
func register_discovery() -> void:
	discoveries_found += 1
	discovery_registered.emit(discoveries_found)
	add_xp(25)
	_save()

## Register clearing a zone (completing all content in a zone pass).
func register_zone_clear(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= 15:
		return
	zone_clears[zone_idx] += 1
	zone_cleared.emit(zone_idx, zone_clears[zone_idx])
	add_xp(50 + zone_idx * 10)
	_save()

## Returns XP needed to advance from current level to next (0 if at cap).
func xp_to_next_level() -> int:
	if hero_level >= MAX_LEVEL:
		return 0
	return XP_TABLE[hero_level] - hero_xp

## Returns progress [0.0-1.0] toward next level.
func level_progress() -> float:
	if hero_level >= MAX_LEVEL:
		return 1.0
	var prev: int = XP_TABLE[hero_level - 1]
	var next: int = XP_TABLE[hero_level]
	return float(hero_xp - prev) / float(next - prev)

## Movement speed bonus: +2% per level, up to +98% at level 50.
func get_speed_bonus() -> float:
	return 0.02 * float(hero_level - 1)

## Collect radius bonus: +3px per level, up to +147px at level 50.
func get_collect_radius_bonus() -> float:
	return 3.0 * float(hero_level - 1)

## Rare resource spawn chance bonus: +0.5% per level, up to +24.5% at level 50.
func get_rare_chance_bonus() -> float:
	return 0.005 * float(hero_level - 1)

## Zone mastery level for a given zone (0=virgin, 1-5=master tiers).
func get_zone_mastery(zone_idx: int) -> int:
	if zone_idx < 0 or zone_idx >= 15:
		return 0
	return mini(zone_clears[zone_idx], 5)

## Full reset — used for "new game" from main menu.
func reset_all() -> void:
	hero_level = 1
	hero_xp = 0
	zone_clears.fill(0)
	discoveries_found = 0
	_save()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("hero", "level", hero_level)
	cfg.set_value("hero", "xp", hero_xp)
	cfg.set_value("hero", "discoveries", discoveries_found)
	for i: int in range(15):
		cfg.set_value("zones", "zone_%d" % i, zone_clears[i])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	hero_level = cfg.get_value("hero", "level", 1)
	hero_xp = cfg.get_value("hero", "xp", 0)
	discoveries_found = cfg.get_value("hero", "discoveries", 0)
	for i: int in range(15):
		zone_clears[i] = cfg.get_value("zones", "zone_%d" % i, 0)
