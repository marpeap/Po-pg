## AchievementSystem — 30 succès persistants sur 6 catégories.
## Inspiré de Monster Hunter (collection de trophées), Steam achievements,
## et Pokémon GO (médailles avec bonification progressive).
##
## Chaque succès débloqué → toast visuel + XP + parfois récompense unique.
## Persisté dans user://achievements.cfg.
extends Node

## ── Définition des succès ────────────────────────────────────────────────

enum AchievementId {
	## ── EXPLORATION (0-4) ────────────────────────────────────────────────
	FIRST_STEPS        = 0,  ## Première expédition complétée
	ZONE_EXPLORER      = 1,  ## Visiter toutes les 15 zones
	CAVE_HUNTER        = 2,  ## Trouver 5 cavernes cachées
	LORE_SEEKER        = 3,  ## Lire 10 tablettes de lore
	CARTOGRAPHER       = 4,  ## Compléter 3 expéditions complètes

	## ── COLLECTE (5-9) ───────────────────────────────────────────────────
	HOARDER            = 5,  ## Collecter 500 ressources totales
	RARE_FINDER        = 6,  ## Collecter 50 ressources rares
	LEGENDARY_TOUCH    = 7,  ## Obtenir une ressource légendaire
	EPIC_COLLECTOR     = 8,  ## Obtenir une ressource épique
	COMPLETIONIST      = 9,  ## Collecter chaque type de ressource au moins 1 fois

	## ── COMBAT (10-14) ───────────────────────────────────────────────────
	FIRST_BLOOD        = 10, ## Défaite premier camp ennemi
	CAMP_RAIDER        = 11, ## Défaite 10 camps ennemis
	ELITE_SLAYER       = 12, ## Défaite 3 camps de tier 2
	WAR_HERO           = 13, ## Défaite 25 camps au total
	UNSTOPPABLE        = 14, ## Défaite 5 camps en une seule expédition

	## ── PROGRESSION (15-19) ──────────────────────────────────────────────
	LEVEL_5            = 15, ## Atteindre niveau 5
	LEVEL_20           = 16, ## Atteindre niveau 20
	LEVEL_50           = 17, ## Atteindre le niveau maximum 50
	SKILL_MASTER       = 18, ## Débloquer 10 compétences dans l'arbre
	CONTRACT_PRO       = 19, ## Compléter 20 contrats

	## ── ARTISANAT (20-24) ────────────────────────────────────────────────
	APPRENTICE_SMITH   = 20, ## Forger votre premier objet
	MASTER_CRAFTSMAN   = 21, ## Forger 10 objets différents
	LEGENDARY_FORGE    = 22, ## Forger un objet légendaire
	ALCHEMIST          = 23, ## Créer 5 potions différentes
	SIEGE_ENGINEER     = 24, ## Toutes les améliorations de tour actives

	## ── ACCOMPLISSEMENTS (25-29) ─────────────────────────────────────────
	GOLD_HOARDER       = 25, ## Accumuler 1000 or en une session
	SURVIVOR           = 26, ## Survivre à 10 vagues sans perdre de château HP
	DAILY_WARRIOR      = 27, ## Compléter 7 défis quotidiens consécutifs
	ZONE_MASTER        = 28, ## Atteindre la maîtrise max (×5) sur une zone
	LEGENDARY_GARRISON = 29, ## Atteindre défense maximale avec 8 archers + 5 tours
}

const ACHIEVEMENT_COUNT := 30

## Noms français affichés en UI
const NAMES: Array[String] = [
	"Premiers Pas", "Grand Explorateur", "Chasseur de Cavernes", "Chercheur de Lore", "Cartographe",
	"Accumulateur", "Chercheur de Rares", "Contact Légendaire", "Collecteur Épique", "Complétionniste",
	"Premier Sang", "Pilleur de Camps", "Tueur d'Élites", "Héros de Guerre", "Inarrêtable",
	"Niveau 5", "Niveau 20", "Niveau Maximum", "Maître des Compétences", "Professionnel des Contrats",
	"Apprenti Forgeron", "Maître Artisan", "Forge Légendaire", "Alchimiste", "Ingénieur de Siège",
	"Thésauriseur d'Or", "Survivant", "Guerrier Quotidien", "Maître de Zone", "Garnison Légendaire",
]

## Descriptions courtes (pour toast et liste)
const DESCRIPTIONS: Array[String] = [
	"Première expédition terminée",
	"Toutes les 15 zones visitées",
	"5 cavernes secrètes découvertes",
	"10 tablettes de lore lues",
	"3 expéditions complètes",
	"500 ressources collectées",
	"50 ressources rares obtenues",
	"1 ressource légendaire obtenue",
	"1 ressource épique obtenue",
	"Chaque type de ressource collecté",
	"Premier camp ennemi vaincu",
	"10 camps ennemis vaincus",
	"3 camps d'élite vaincus",
	"25 camps vaincus au total",
	"5 camps en une expédition",
	"Héros niveau 5 atteint",
	"Héros niveau 20 atteint",
	"Héros niveau 50 atteint",
	"10 compétences débloquées",
	"20 contrats complétés",
	"Premier objet forgé",
	"10 objets différents forgés",
	"Objet légendaire forgé",
	"5 potions créées",
	"Toutes tours améliorées",
	"1000 or en une session",
	"10 vagues sans perte",
	"7 défis quotidiens consécutifs",
	"Zone maîtrisée ×5",
	"Défense maximale déployée",
]

## XP rewards per achievement (scaled by difficulty)
const XP_REWARDS: Array[int] = [
	## Exploration
	50, 200, 150, 100, 300,
	## Collecte
	100, 200, 500, 1000, 750,
	## Combat
	50, 200, 300, 500, 400,
	## Progression
	25, 100, 500, 300, 200,
	## Artisanat
	50, 200, 400, 150, 350,
	## Accomplissements
	100, 200, 500, 300, 600,
]

## Rareté visuelle (couleur du toast): 0=bronze 1=argent 2=or 3=diamant
const RARITY: Array[int] = [
	0, 1, 0, 0, 1,
	0, 1, 2, 3, 2,
	0, 1, 2, 2, 2,
	0, 1, 3, 2, 1,
	0, 1, 2, 1, 2,
	1, 1, 2, 2, 3,
]

const RARITY_COLORS: Array[Color] = [
	Color(0.80, 0.52, 0.25),  ## Bronze
	Color(0.75, 0.75, 0.80),  ## Argent
	Color(1.00, 0.85, 0.20),  ## Or
	Color(0.55, 0.88, 1.00),  ## Diamant
]

## ── Runtime state ────────────────────────────────────────────────────────

var _unlocked: Array[bool] = []

## Progress counters (for cumulative achievements)
var total_resources_collected: int = 0
var total_rare_resources: int = 0
var total_legendary_resources: int = 0
var total_epic_resources: int = 0
var total_camps_cleared: int = 0
var total_expeditions: int = 0
var total_contracts: int = 0
var total_items_crafted: int = 0
var total_caves_found: int = 0
var total_lore_read: int = 0
var session_camps: int = 0
var types_collected: Dictionary = {}  ## type_int -> true

signal achievement_unlocked(achievement_id: int)

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	_unlocked.resize(ACHIEVEMENT_COUNT)
	_unlocked.fill(false)
	_load()
	## Connect to game systems
	if ResourceInventory != null:
		ResourceInventory.resource_changed.connect(_on_resource_changed)
	if HeroProgression != null:
		HeroProgression.level_up.connect(_on_level_up)
	if ItemInventory != null:
		ItemInventory.item_crafted.connect(_on_item_crafted)

## ── Public event hooks ────────────────────────────────────────────────────

func on_expedition_completed() -> void:
	total_expeditions += 1
	session_camps = 0
	_check(AchievementId.FIRST_STEPS, total_expeditions >= 1)
	_check(AchievementId.CARTOGRAPHER, total_expeditions >= 3)

func on_camp_cleared(tier: int) -> void:
	total_camps_cleared += 1
	session_camps += 1
	_check(AchievementId.FIRST_BLOOD, total_camps_cleared >= 1)
	_check(AchievementId.CAMP_RAIDER, total_camps_cleared >= 10)
	_check(AchievementId.WAR_HERO,    total_camps_cleared >= 25)
	_check(AchievementId.UNSTOPPABLE, session_camps >= 5)
	if tier >= 2:
		var elite_count: int = _get_counter("elite_camps") + 1
		_set_counter("elite_camps", elite_count)
		_check(AchievementId.ELITE_SLAYER, elite_count >= 3)

func on_cave_discovered() -> void:
	total_caves_found += 1
	_check(AchievementId.CAVE_HUNTER, total_caves_found >= 5)

func on_lore_read() -> void:
	total_lore_read += 1
	_check(AchievementId.LORE_SEEKER, total_lore_read >= 10)

func on_contract_completed() -> void:
	total_contracts += 1
	_check(AchievementId.CONTRACT_PRO, total_contracts >= 20)

func on_all_zones_visited() -> void:
	_check(AchievementId.ZONE_EXPLORER, true)

func on_skill_unlocked(count: int) -> void:
	_check(AchievementId.SKILL_MASTER, count >= 10)

func on_gold_earned_session(total: int) -> void:
	_check(AchievementId.GOLD_HOARDER, total >= 1000)

func on_zone_mastery_reached(level: int) -> void:
	_check(AchievementId.ZONE_MASTER, level >= 5)

func on_max_garrison_deployed(archer_count: int, tower_count: int) -> void:
	_check(AchievementId.LEGENDARY_GARRISON, archer_count >= 8 and tower_count >= 5)

func on_waves_survived_clean(count: int) -> void:
	_check(AchievementId.SURVIVOR, count >= 10)

func on_daily_streak(streak: int) -> void:
	_check(AchievementId.DAILY_WARRIOR, streak >= 7)

func on_potion_count(count: int) -> void:
	_check(AchievementId.ALCHEMIST, count >= 5)

func on_all_towers_upgraded() -> void:
	_check(AchievementId.SIEGE_ENGINEER, true)

## ── Internal event handlers ──────────────────────────────────────────────

func _on_resource_changed(type: int, new_count: int) -> void:
	if new_count <= 0:
		return
	if not types_collected.has(type):
		types_collected[type] = true
		total_resources_collected += 1
	var rarity: int = ResourceInventory.get_rarity(type)
	if rarity >= ResourceInventory.Rarity.RARE:
		total_rare_resources += 1
		_check(AchievementId.RARE_FINDER, total_rare_resources >= 50)
	if rarity >= ResourceInventory.Rarity.LEGENDARY:
		total_legendary_resources += 1
		_check(AchievementId.LEGENDARY_TOUCH, true)
	if rarity >= ResourceInventory.Rarity.EPIC:
		total_epic_resources += 1
		_check(AchievementId.EPIC_COLLECTOR, true)
	_check(AchievementId.HOARDER,        total_resources_collected >= 500)
	_check(AchievementId.COMPLETIONIST,  types_collected.size() >= ResourceInventory.TYPE_COUNT)

func _on_level_up(new_level: int) -> void:
	_check(AchievementId.LEVEL_5,  new_level >= 5)
	_check(AchievementId.LEVEL_20, new_level >= 20)
	_check(AchievementId.LEVEL_50, new_level >= 50)

func _on_item_crafted(item_id: int) -> void:
	var crafted_set: Dictionary = _get_dict("crafted_items")
	crafted_set[item_id] = true
	_set_dict("crafted_items", crafted_set)
	total_items_crafted += 1
	_check(AchievementId.APPRENTICE_SMITH, total_items_crafted >= 1)
	_check(AchievementId.MASTER_CRAFTSMAN, crafted_set.size() >= 10)
	## Legendary forge: SHADOW_MAIL, CRYSTAL_STAFF, VENOM_BLADE are "legendary" items
	const LEGENDARY_ITEMS: Array[int] = [1, 3, 7]
	for lid: int in LEGENDARY_ITEMS:
		if crafted_set.has(lid):
			_check(AchievementId.LEGENDARY_FORGE, true)
			break

## ── Unlock logic ─────────────────────────────────────────────────────────

func _check(achievement_id: int, condition: bool) -> void:
	if not condition:
		return
	if _unlocked[achievement_id]:
		return
	_unlocked[achievement_id] = true
	achievement_unlocked.emit(achievement_id)
	## Grant XP reward
	var xp: int = XP_REWARDS[achievement_id]
	if HeroProgression != null:
		HeroProgression.add_xp(xp)
	_save()

func is_unlocked(achievement_id: int) -> bool:
	if achievement_id < 0 or achievement_id >= ACHIEVEMENT_COUNT:
		return false
	return _unlocked[achievement_id]

func get_unlock_count() -> int:
	var count: int = 0
	for u: bool in _unlocked:
		if u:
			count += 1
	return count

## ── Counter helpers (stored in cfg) ─────────────────────────────────────

var _counters: Dictionary = {}
var _dicts: Dictionary = {}

func _get_counter(key: String) -> int:
	return _counters.get(key, 0)

func _set_counter(key: String, value: int) -> void:
	_counters[key] = value

func _get_dict(key: String) -> Dictionary:
	return _dicts.get(key, {})

func _set_dict(key: String, value: Dictionary) -> void:
	_dicts[key] = value

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	for i: int in range(ACHIEVEMENT_COUNT):
		cfg.set_value("unlocked", "a%d" % i, _unlocked[i])
	cfg.set_value("counters", "resources",   total_resources_collected)
	cfg.set_value("counters", "rares",       total_rare_resources)
	cfg.set_value("counters", "legendary",   total_legendary_resources)
	cfg.set_value("counters", "epic",        total_epic_resources)
	cfg.set_value("counters", "camps",       total_camps_cleared)
	cfg.set_value("counters", "expeditions", total_expeditions)
	cfg.set_value("counters", "contracts",   total_contracts)
	cfg.set_value("counters", "items",       total_items_crafted)
	cfg.set_value("counters", "caves",       total_caves_found)
	cfg.set_value("counters", "lore",        total_lore_read)
	cfg.set_value("counters", "elite_camps", _get_counter("elite_camps"))
	## Save types collected list
	var tc_arr: Array = types_collected.keys()
	cfg.set_value("sets", "types_collected", tc_arr)
	cfg.set_value("sets", "crafted_items", _get_dict("crafted_items").keys())
	cfg.save("user://achievements.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://achievements.cfg") != OK:
		return
	for i: int in range(ACHIEVEMENT_COUNT):
		_unlocked[i] = cfg.get_value("unlocked", "a%d" % i, false)
	total_resources_collected = cfg.get_value("counters", "resources",   0)
	total_rare_resources      = cfg.get_value("counters", "rares",       0)
	total_legendary_resources = cfg.get_value("counters", "legendary",   0)
	total_epic_resources      = cfg.get_value("counters", "epic",        0)
	total_camps_cleared       = cfg.get_value("counters", "camps",       0)
	total_expeditions         = cfg.get_value("counters", "expeditions", 0)
	total_contracts           = cfg.get_value("counters", "contracts",   0)
	total_items_crafted       = cfg.get_value("counters", "items",       0)
	total_caves_found         = cfg.get_value("counters", "caves",       0)
	total_lore_read           = cfg.get_value("counters", "lore",        0)
	_set_counter("elite_camps", cfg.get_value("counters", "elite_camps", 0))
	var tc_arr: Array = cfg.get_value("sets", "types_collected", [])
	for t: int in tc_arr:
		types_collected[t] = true
	var ci_arr: Array = cfg.get_value("sets", "crafted_items", [])
	var ci_dict: Dictionary = {}
	for ci: int in ci_arr:
		ci_dict[ci] = true
	_set_dict("crafted_items", ci_dict)

func reset_all() -> void:
	_unlocked.fill(false)
	total_resources_collected = 0
	total_rare_resources = 0
	total_legendary_resources = 0
	total_epic_resources = 0
	total_camps_cleared = 0
	total_expeditions = 0
	total_contracts = 0
	total_items_crafted = 0
	total_caves_found = 0
	total_lore_read = 0
	session_camps = 0
	types_collected.clear()
	_counters.clear()
	_dicts.clear()
	_save()
