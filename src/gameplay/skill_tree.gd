## SkillTree — Arbre de compétences persistant du héros.
## Inspiré de Path of Exile (passive nodes), Diablo 3 (spécialisations), FFXIV (classes).
## 3 Branches × 5 Niveaux = 15 compétences majeures + 6 passives secrètes.
##
## Branch GUERRIER  : combat, dommages, survie
## Branch EXPLORATEUR : vitesse, collecte, découvertes
## Branch ERUDIT   : magie, ressources rares, forge
##
## Utilise les SkillPoints gagnés au level-up (1 point / niveau).
## Persisté dans HeroProgression via ConfigFile.
extends Node

## ── Définition des branches ─────────────────────────────────────────────

enum Branch { GUERRIER = 0, EXPLORATEUR = 1, ERUDIT = 2 }

## Identifiants uniques de toutes les compétences (0-20).
## Actives 0-14, Passives secrètes 15-20.
enum Skill {
	## ── GUERRIER (0-4) ──────────────────────────────────────────────────
	## Tier 1 — Coups Durs : +15% dégâts mêlée héros
	COUPS_DURS        = 0,
	## Tier 2 — Endurance : +25 HP max
	ENDURANCE         = 1,
	## Tier 3 — Riposte : 20% chance de renvoyer 10 dégâts
	RIPOSTE           = 2,
	## Tier 4 — Fureur : les kills consécutifs donnent +5% dégâts (max ×3)
	FUREUR            = 3,
	## Tier 5 — Incarnation : survivre avec <10 HP pendant 5s → invincible 2s
	INCARNATION       = 4,

	## ── EXPLORATEUR (5-9) ───────────────────────────────────────────────
	## Tier 1 — Foulée Légère : +20% vitesse de déplacement
	FOULEE_LEGERE     = 5,
	## Tier 2 — Mains Habiles : collecte en 0.6s au lieu de 1s
	MAINS_HABILES     = 6,
	## Tier 3 — Sixième Sens : révèle les cavernes dans 250px (au lieu de 180)
	SIXIEME_SENS      = 7,
	## Tier 4 — Fortune Cachée : +35% or dans les coffres
	FORTUNE_CACHEE    = 8,
	## Tier 5 — Carte du Monde : toutes les zones actives visibles sur mini-carte
	CARTE_DU_MONDE    = 9,

	## ── ERUDIT (10-14) ──────────────────────────────────────────────────
	## Tier 1 — Œil du Sage : +15% chance de ressource rare
	OEIL_DU_SAGE      = 10,
	## Tier 2 — Alchimie Basique : les herbes donnent ×2
	ALCHIMIE_BASIQUE  = 11,
	## Tier 3 — Catalyseur : forge réduite de 1 ressource de chaque type
	CATALYSEUR        = 12,
	## Tier 4 — Connaissances Anciennes : les tablettes de lore donnent 50 XP
	CONNAISSANCES     = 13,
	## Tier 5 — Maître Érudit : double la rareté de chaque ressource collectée
	MAITRE_ERUDIT     = 14,

	## ── PASSIVES SECRÈTES (15-20) — débloquées par combinaisons ────────
	## Actives si 3+ skills GUERRIER ET 3+ skills EXPLORATEUR
	LAME_RAPIDE       = 15,  ## +10% vitesse ET +10% dégâts
	## Actives si 3+ skills GUERRIER ET 3+ skills ERUDIT
	GUERRIER_SAGE     = 16,  ## les sorts du héros coûtent -1 mana
	## Actives si 3+ skills EXPLORATEUR ET 3+ skills ERUDIT
	NATURALISTE       = 17,  ## +25% XP de collecte de ressources communes
	## Actives si 5 skills GUERRIER
	CHAMPION          = 18,  ## le héros peut absorber 1 coup fatal / expédition
	## Actives si 5 skills EXPLORATEUR
	RANDONNEUR        = 19,  ## aucune fatigue dans les zones de danger
	## Actives si 5 skills ERUDIT
	ARCHIVISTE        = 20,  ## les contrats rapportent 50% XP bonus
}

const SKILL_COUNT := 21

## Noms français
const NAMES: Array[String] = [
	"Coups Durs", "Endurance", "Riposte", "Fureur", "Incarnation",
	"Foulée Légère", "Mains Habiles", "Sixième Sens", "Fortune Cachée", "Carte du Monde",
	"Oeil du Sage", "Alchimie Basique", "Catalyseur", "Connaissances Anciennes", "Maître Érudit",
	"Lame Rapide", "Guerrier Sage", "Naturaliste", "Champion", "Randonneur", "Archiviste",
]

## Descriptions courtes
const DESCRIPTIONS: Array[String] = [
	"+15% dégâts mêlée",
	"+25 HP max",
	"20% riposte 10 dmg",
	"Kills consécutifs +5% dmg",
	"Invincible 2s < 10HP",
	"+20% vitesse",
	"Collecte 40% plus rapide",
	"Détecte cavernes à 250px",
	"+35% or coffres",
	"Révèle toutes les zones",
	"+15% chance rare",
	"Herbes ×2",
	"Forge -1 ingrédient",
	"Lore +50 XP",
	"Ressources doublées rareté",
	"+10% vitesse & dégâts",
	"Sorts -1 mana",
	"+25% XP collecte",
	"Absorbe 1 coup fatal",
	"Pas de vignette danger",
	"Contrats +50% XP",
]

## XP cost of each skill tier (tiers 1-5 for branches, fixed for passives)
const SKILL_COSTS: Array[int] = [
	1, 2, 3, 4, 5,   ## Guerrier
	1, 2, 3, 4, 5,   ## Explorateur
	1, 2, 3, 4, 5,   ## Erudit
	0, 0, 0, 0, 0, 0 ## Passives secrètes (auto-unlock, no cost)
]

## Prerequisite: skill ID qui doit être débloqué avant
const PREREQUISITES: Array[int] = [
	-1, 0, 1, 2, 3,   ## Guerrier chain
	-1, 5, 6, 7, 8,   ## Explorateur chain
	-1, 10, 11, 12, 13, ## Erudit chain
	-1, -1, -1, -1, -1, -1  ## Passives no prereq
]

## ── Runtime state ────────────────────────────────────────────────────────

var _unlocked: Array[bool] = []
var skill_points: int = 0

signal skill_unlocked(skill_id: int)
signal skill_points_changed(new_total: int)
signal passive_unlocked(skill_id: int)

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	_unlocked.resize(SKILL_COUNT)
	_unlocked.fill(false)
	_load()
	## Connect to HeroProgression level-up for skill point grants.
	if HeroProgression != null:
		HeroProgression.level_up.connect(_on_level_up)

## ── Skill point management ──────────────────────────────────────────────

func _on_level_up(new_level: int) -> void:
	## Grant 1 skill point per level. At prestige levels (every 10), grant 2.
	var bonus: int = 2 if (new_level % 10 == 0) else 1
	add_skill_points(bonus)

func add_skill_points(amount: int) -> void:
	skill_points += amount
	skill_points_changed.emit(skill_points)
	_save()

## ── Unlock logic ─────────────────────────────────────────────────────────

## Returns true if the skill can be unlocked (prereq met, points available, not already owned).
func can_unlock(skill_id: int) -> bool:
	if skill_id < 0 or skill_id >= SKILL_COUNT:
		return false
	if _unlocked[skill_id]:
		return false
	## Passives auto-unlock — not player-triggered
	if skill_id >= 15:
		return false
	var cost: int = SKILL_COSTS[skill_id]
	if skill_points < cost:
		return false
	var prereq: int = PREREQUISITES[skill_id]
	if prereq >= 0 and not _unlocked[prereq]:
		return false
	return true

## Attempt to unlock a skill. Returns true on success.
func unlock_skill(skill_id: int) -> bool:
	if not can_unlock(skill_id):
		return false
	_unlocked[skill_id] = true
	skill_points -= SKILL_COSTS[skill_id]
	skill_points_changed.emit(skill_points)
	skill_unlocked.emit(skill_id)
	_check_passive_unlocks()
	_save()
	return true

func _check_passive_unlocks() -> void:
	var g := _branch_count(Branch.GUERRIER)
	var e := _branch_count(Branch.EXPLORATEUR)
	var r := _branch_count(Branch.ERUDIT)

	_try_unlock_passive(Skill.LAME_RAPIDE,    g >= 3 and e >= 3)
	_try_unlock_passive(Skill.GUERRIER_SAGE,  g >= 3 and r >= 3)
	_try_unlock_passive(Skill.NATURALISTE,    e >= 3 and r >= 3)
	_try_unlock_passive(Skill.CHAMPION,       g >= 5)
	_try_unlock_passive(Skill.RANDONNEUR,     e >= 5)
	_try_unlock_passive(Skill.ARCHIVISTE,     r >= 5)

func _try_unlock_passive(skill_id: int, condition: bool) -> void:
	if condition and not _unlocked[skill_id]:
		_unlocked[skill_id] = true
		passive_unlocked.emit(skill_id)
		_save()

func _branch_count(branch: Branch) -> int:
	var base: int = branch * 5
	var count: int = 0
	for i: int in range(5):
		if _unlocked[base + i]:
			count += 1
	return count

## ── Query helpers ─────────────────────────────────────────────────────────

func is_unlocked(skill_id: int) -> bool:
	if skill_id < 0 or skill_id >= SKILL_COUNT:
		return false
	return _unlocked[skill_id]

func get_unlocked_in_branch(branch: Branch) -> int:
	return _branch_count(branch)

## Effective bonuses based on unlocked skills.

func get_melee_damage_mult() -> float:
	var m := 1.0
	if _unlocked[Skill.COUPS_DURS]:     m += 0.15
	if _unlocked[Skill.LAME_RAPIDE]:    m += 0.10
	return m

func get_hp_bonus() -> int:
	return 25 if _unlocked[Skill.ENDURANCE] else 0

func get_riposte_chance() -> float:
	return 0.20 if _unlocked[Skill.RIPOSTE] else 0.0

func get_speed_mult() -> float:
	var m := 1.0
	if _unlocked[Skill.FOULEE_LEGERE]: m += 0.20
	if _unlocked[Skill.LAME_RAPIDE]:   m += 0.10
	return m

func get_collect_speed_mult() -> float:
	return 0.60 if _unlocked[Skill.MAINS_HABILES] else 1.0

func get_cave_reveal_radius() -> float:
	return 250.0 if _unlocked[Skill.SIXIEME_SENS] else 180.0

func get_chest_gold_mult() -> float:
	return 1.35 if _unlocked[Skill.FORTUNE_CACHEE] else 1.0

func get_rare_chance_bonus() -> float:
	var bonus := 0.0
	if _unlocked[Skill.OEIL_DU_SAGE]: bonus += 0.15
	return bonus

func get_herb_yield_mult() -> float:
	return 2.0 if _unlocked[Skill.ALCHIMIE_BASIQUE] else 1.0

func get_resource_xp_mult() -> float:
	var m := 1.0
	if _unlocked[Skill.NATURALISTE]: m += 0.25
	return m

func get_contract_xp_mult() -> float:
	return 1.50 if _unlocked[Skill.ARCHIVISTE] else 1.0

func get_lore_xp_bonus() -> int:
	return 50 if _unlocked[Skill.CONNAISSANCES] else 0

func has_fatal_absorption() -> bool:
	return _unlocked[Skill.CHAMPION]

func has_danger_immunity() -> bool:
	return _unlocked[Skill.RANDONNEUR]

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("skills", "points", skill_points)
	for i: int in range(SKILL_COUNT):
		cfg.set_value("skills", "s%d" % i, _unlocked[i])
	cfg.save("user://skill_tree.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://skill_tree.cfg") != OK:
		return
	skill_points = cfg.get_value("skills", "points", 0)
	for i: int in range(SKILL_COUNT):
		_unlocked[i] = cfg.get_value("skills", "s%d" % i, false)

## Full reset (new game).
func reset_all() -> void:
	_unlocked.fill(false)
	skill_points = 0
	_save()
