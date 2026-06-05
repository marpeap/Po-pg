## DailyChallenge — 3 défis quotidiens renouvelés toutes les 24h.
## Inspiré de Genshin Impact (commissions quotidiennes), Warframe (sorties quotidiennes),
## et FFXIV (tâches journalières avec prime de fidélité).
##
## Mécanique clé : Streak (séquence de jours consécutifs) → bonus multiplicatifs.
## Streak 7 jours = +100% XP sur toutes les récompenses.
## Streak brisé → retour à 1.
##
## Défis générés via seed horodatée (même défis pour tous joueurs → community feel).
extends Node

## ── Types de défis ───────────────────────────────────────────────────────

enum ChallengeType {
	COLLECT_RESOURCE    = 0,  ## Collecter N d'une ressource spécifique
	CLEAR_CAMPS         = 1,  ## Vaincre N camps
	REACH_ZONE          = 2,  ## Atteindre la zone N dans une expédition
	DISCOVER_CAVE       = 3,  ## Trouver une caverne secrète
	FULFILL_CONTRACT    = 4,  ## Compléter N contrats
	CRAFT_ITEM          = 5,  ## Forger un objet
	COLLECT_RARE        = 6,  ## Obtenir N ressources rares
	SURVIVE_WAVES       = 7,  ## Survivre à N vagues sans perdre de vie château
	SPEND_GOLD          = 8,  ## Dépenser N or dans des améliorations
	COLLECT_XP          = 9,  ## Gagner N XP en une session
}

## ── Pool de ressources cibles par difficulté ─────────────────────────────

const EASY_RESOURCES: Array[int]   = [0, 1, 2, 3, 4, 13, 14, 17]   ## communes simples
const MEDIUM_RESOURCES: Array[int] = [5, 6, 7, 9, 22, 25, 34, 41]  ## rares
const HARD_RESOURCES: Array[int]   = [42, 43, 44, 46, 47, 48]       ## rares/légendaires

## ── Structure d'un défi ──────────────────────────────────────────────────

## Chaque défi: {type, target_value, resource_type (si applicable), name, description, gold_reward, xp_reward, progress, completed}

## Quantités par difficulté (0=easy, 1=medium, 2=hard)
const COLLECT_AMOUNTS: Array[int]  = [8, 4, 2]
const CAMP_AMOUNTS: Array[int]     = [1, 2, 3]
const ZONE_TARGETS: Array[int]     = [3, 6, 10]
const CONTRACT_AMOUNTS: Array[int] = [1, 2, 3]
const RARE_AMOUNTS: Array[int]     = [3, 6, 10]
const WAVE_AMOUNTS: Array[int]     = [3, 5, 8]
const GOLD_AMOUNTS: Array[int]     = [50, 120, 250]
const XP_AMOUNTS: Array[int]       = [100, 300, 600]

## Récompenses par difficulté
const GOLD_REWARDS: Array[int] = [20, 50, 100]
const XP_REWARDS:  Array[int]  = [75, 150, 300]

## ── Runtime ──────────────────────────────────────────────────────────────

var _challenges: Array[Dictionary] = []
var _day_seed: int = 0
var _last_date_str: String = ""

## Streak
var streak: int = 0
var streak_last_completed_date: String = ""
var _all_completed_today: bool = false

signal challenge_progress(challenge_idx: int, progress: int, target: int)
signal challenge_completed(challenge_idx: int)
signal all_challenges_completed(bonus_xp: int)
signal streak_updated(new_streak: int)

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	_refresh_if_new_day()

## ── Day refresh ──────────────────────────────────────────────────────────

func _get_today_str() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]

func _refresh_if_new_day() -> void:
	var today: String = _get_today_str()
	if today == _last_date_str:
		return  ## Same day, challenges still valid

	## New day — check streak continuity
	if _last_date_str != "":
		var yesterday: bool = _is_yesterday(_last_date_str, today)
		if _all_completed_today and yesterday:
			streak += 1
		elif not yesterday:
			streak = 0  ## Missed a day
		## If yesterday but not completed, streak stays (not broken, not incremented)
	_last_date_str = today
	_all_completed_today = false

	## Generate today's challenges deterministically by date seed
	var date_parts := today.split("-")
	_day_seed = (int(date_parts[0]) * 365 + int(date_parts[1]) * 31 + int(date_parts[2]))
	_generate_challenges()
	streak_updated.emit(streak)
	_save()

func _is_yesterday(prev_str: String, today_str: String) -> bool:
	## Simple check: parse dates and subtract 1 day
	var p := prev_str.split("-")
	var t := today_str.split("-")
	var prev_days: int = int(p[0]) * 365 + int(p[1]) * 31 + int(p[2])
	var today_days: int = int(t[0]) * 365 + int(t[1]) * 31 + int(t[2])
	return (today_days - prev_days) == 1

## ── Challenge generation ─────────────────────────────────────────────────

func _generate_challenges() -> void:
	_challenges.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _day_seed

	## 3 challenges: one easy, one medium, one hard
	for difficulty: int in range(3):
		var c: Dictionary = _generate_one(rng, difficulty)
		_challenges.append(c)

func _generate_one(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var type: int = rng.randi_range(0, ChallengeType.size() - 1)
	var resource_type: int = -1
	var target: int = 1
	var name_str: String = ""
	var desc: String = ""

	match type:
		ChallengeType.COLLECT_RESOURCE:
			var pool: Array
			match difficulty:
				0: pool = EASY_RESOURCES
				1: pool = MEDIUM_RESOURCES
				_: pool = HARD_RESOURCES
			resource_type = pool[rng.randi_range(0, pool.size() - 1)]
			target = COLLECT_AMOUNTS[difficulty]
			var res_name: String = ResourceInventory.SHORT_NAMES[resource_type]
			name_str = "Récolte : %s" % res_name
			desc = "Collecter %d %s" % [target, res_name]
		ChallengeType.CLEAR_CAMPS:
			target = CAMP_AMOUNTS[difficulty]
			name_str = "Combattant"
			desc = "Vaincre %d camp(s) ennemi(s)" % target
		ChallengeType.REACH_ZONE:
			target = ZONE_TARGETS[difficulty]
			name_str = "Explorateur"
			desc = "Atteindre la zone %d" % target
		ChallengeType.DISCOVER_CAVE:
			target = 1
			name_str = "Spéléologue"
			desc = "Découvrir une caverne secrète"
		ChallengeType.FULFILL_CONTRACT:
			target = CONTRACT_AMOUNTS[difficulty]
			name_str = "Marchand de Guerre"
			desc = "Compléter %d contrat(s)" % target
		ChallengeType.CRAFT_ITEM:
			target = 1
			name_str = "Forgeron du Jour"
			desc = "Forger n'importe quel objet"
		ChallengeType.COLLECT_RARE:
			target = RARE_AMOUNTS[difficulty]
			name_str = "Fortune Rare"
			desc = "Obtenir %d ressource(s) rares" % target
		ChallengeType.SURVIVE_WAVES:
			target = WAVE_AMOUNTS[difficulty]
			name_str = "Défenseur"
			desc = "Survivre à %d vagues" % target
		ChallengeType.SPEND_GOLD:
			target = GOLD_AMOUNTS[difficulty]
			name_str = "Investisseur"
			desc = "Dépenser %d or en améliorations" % target
		ChallengeType.COLLECT_XP:
			target = XP_AMOUNTS[difficulty]
			name_str = "Apprenti Sage"
			desc = "Gagner %d XP en une session" % target

	return {
		"type": type,
		"difficulty": difficulty,
		"target": target,
		"resource_type": resource_type,
		"name": name_str,
		"description": desc,
		"gold_reward": GOLD_REWARDS[difficulty],
		"xp_reward": XP_REWARDS[difficulty],
		"progress": 0,
		"completed": false,
	}

## ── Progress tracking ─────────────────────────────────────────────────────

## Called from exploration_map / main when relevant events happen.

func on_resource_collected(res_type: int, amount: int) -> void:
	for i: int in range(_challenges.size()):
		var c: Dictionary = _challenges[i]
		if c.completed:
			continue
		if c.type == ChallengeType.COLLECT_RESOURCE and c.resource_type == res_type:
			_add_progress(i, amount)
		elif c.type == ChallengeType.COLLECT_RARE:
			if ResourceInventory.get_rarity(res_type) >= ResourceInventory.Rarity.RARE:
				_add_progress(i, amount)
		elif c.type == ChallengeType.COLLECT_XP:
			var xp: int = ResourceInventory.RARITY_XP[ResourceInventory.get_rarity(res_type)] * amount
			_add_progress(i, xp)

func on_camp_cleared() -> void:
	_progress_type(ChallengeType.CLEAR_CAMPS, 1)

func on_zone_reached(zone_idx: int) -> void:
	for i: int in range(_challenges.size()):
		var c: Dictionary = _challenges[i]
		if c.completed or c.type != ChallengeType.REACH_ZONE:
			continue
		if zone_idx + 1 >= c.target and c.progress < c.target:
			_challenges[i].progress = c.target
			_complete(i)

func on_cave_discovered() -> void:
	_progress_type(ChallengeType.DISCOVER_CAVE, 1)

func on_contract_completed() -> void:
	_progress_type(ChallengeType.FULFILL_CONTRACT, 1)

func on_item_crafted() -> void:
	_progress_type(ChallengeType.CRAFT_ITEM, 1)

func on_wave_survived() -> void:
	_progress_type(ChallengeType.SURVIVE_WAVES, 1)

func on_gold_spent(amount: int) -> void:
	_progress_type(ChallengeType.SPEND_GOLD, amount)

func on_xp_gained(amount: int) -> void:
	_progress_type(ChallengeType.COLLECT_XP, amount)

func _progress_type(type: int, amount: int) -> void:
	for i: int in range(_challenges.size()):
		if not _challenges[i].completed and _challenges[i].type == type:
			_add_progress(i, amount)

func _add_progress(idx: int, amount: int) -> void:
	var c: Dictionary = _challenges[idx]
	var new_progress: int = mini(c.progress + amount, c.target)
	_challenges[idx].progress = new_progress
	challenge_progress.emit(idx, new_progress, c.target)
	if new_progress >= c.target:
		_complete(idx)

func _complete(idx: int) -> void:
	_challenges[idx].completed = true
	challenge_completed.emit(idx)

	## Apply streak multiplier to rewards
	var streak_mult: float = _get_streak_mult()
	var gold: int = int(float(_challenges[idx].gold_reward) * streak_mult)
	var xp: int   = int(float(_challenges[idx].xp_reward)  * streak_mult)

	## Emit gold to economy group
	get_tree().call_group("economy", "add_gold", gold)
	if HeroProgression != null:
		HeroProgression.add_xp(xp)

	## Check if all three done
	if _challenges.all(func(c: Dictionary) -> bool: return c.completed):
		_all_completed_today = true
		var bonus: int = int(200.0 * streak_mult)
		if HeroProgression != null:
			HeroProgression.add_xp(bonus)
		all_challenges_completed.emit(bonus)
		streak_updated.emit(streak)
	_save()

func _get_streak_mult() -> float:
	## +10% per streak day, capped at ×2.5 (streak 15)
	return minf(1.0 + 0.10 * float(streak), 2.5)

## ── Accessors ─────────────────────────────────────────────────────────────

func get_challenges() -> Array[Dictionary]:
	return _challenges

func get_streak() -> int:
	return streak

func get_streak_bonus_pct() -> int:
	return int((_get_streak_mult() - 1.0) * 100.0)

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "last_date", _last_date_str)
	cfg.set_value("meta", "streak", streak)
	cfg.set_value("meta", "all_completed", _all_completed_today)
	cfg.set_value("meta", "streak_date", streak_last_completed_date)
	for i: int in range(_challenges.size()):
		var c: Dictionary = _challenges[i]
		cfg.set_value("c%d" % i, "type",          c.type)
		cfg.set_value("c%d" % i, "difficulty",    c.difficulty)
		cfg.set_value("c%d" % i, "target",        c.target)
		cfg.set_value("c%d" % i, "resource_type", c.resource_type)
		cfg.set_value("c%d" % i, "name",          c.name)
		cfg.set_value("c%d" % i, "description",   c.description)
		cfg.set_value("c%d" % i, "gold_reward",   c.gold_reward)
		cfg.set_value("c%d" % i, "xp_reward",     c.xp_reward)
		cfg.set_value("c%d" % i, "progress",      c.progress)
		cfg.set_value("c%d" % i, "completed",     c.completed)
	cfg.save("user://daily_challenges.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://daily_challenges.cfg") != OK:
		return
	_last_date_str = cfg.get_value("meta", "last_date", "")
	streak = cfg.get_value("meta", "streak", 0)
	_all_completed_today = cfg.get_value("meta", "all_completed", false)
	streak_last_completed_date = cfg.get_value("meta", "streak_date", "")
	_challenges.clear()
	for i: int in range(3):
		if not cfg.has_section("c%d" % i):
			continue
		_challenges.append({
			"type":          cfg.get_value("c%d" % i, "type",          0),
			"difficulty":    cfg.get_value("c%d" % i, "difficulty",    i),
			"target":        cfg.get_value("c%d" % i, "target",        1),
			"resource_type": cfg.get_value("c%d" % i, "resource_type", -1),
			"name":          cfg.get_value("c%d" % i, "name",          "Défi"),
			"description":   cfg.get_value("c%d" % i, "description",  ""),
			"gold_reward":   cfg.get_value("c%d" % i, "gold_reward",   20),
			"xp_reward":     cfg.get_value("c%d" % i, "xp_reward",     75),
			"progress":      cfg.get_value("c%d" % i, "progress",      0),
			"completed":     cfg.get_value("c%d" % i, "completed",     false),
		})

func reset_all() -> void:
	_challenges.clear()
	streak = 0
	_all_completed_today = false
	_last_date_str = ""
	_day_seed = 0
	_save()
