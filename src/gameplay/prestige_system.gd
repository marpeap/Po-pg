## PrestigeSystem — Remise à zéro volontaire avec bonus multiplicatifs permanents.
## Inspiré de Path of Exile (Leagues), Diablo 3 (Saisons), et Cookie Clicker (ascension).
##
## Condition : avoir atteint le niveau 50.
## Récompense : titre unique + multiplicateur permanent sur XP et ressources rares.
## Chaque prestige incrémente les bonus — encourages la rejouabilité long-terme.
##
## Les joueurs gardent : titres, achievements, zone_mastery bonus (×0.5).
## Les joueurs perdent : niveau, xp, skill_points, ressources de session.
##
## Persisté dans user://prestige.cfg.
extends Node

## ── Titres de prestige ───────────────────────────────────────────────────

const TITLES: Array[String] = [
	"",               ## 0 — aucun prestige (pas de titre)
	"Vétéran",        ## 1
	"Éclaireur Aguerri", ## 2
	"Maître des Terres", ## 3
	"Défenseur de la Cime", ## 4
	"Gardien Éternel", ## 5
	"Légende Vivante", ## 6
	"Titan de Garrison", ## 7
	"Déité des Âges",  ## 8
	"Transcendant",    ## 9
	"L'Immortel",      ## 10  (prestige maximum)
]

const MAX_PRESTIGE := 10

## Couleurs de titre (affichage HUD)
const TITLE_COLORS: Array[Color] = [
	Color.WHITE,
	Color(0.80, 0.52, 0.25),  ## Bronze
	Color(0.75, 0.75, 0.80),  ## Argent
	Color(1.00, 0.85, 0.20),  ## Or
	Color(0.40, 0.80, 1.00),  ## Saphir
	Color(0.60, 0.35, 1.00),  ## Améthyste
	Color(0.90, 0.30, 0.90),  ## Rubis
	Color(1.00, 0.50, 0.15),  ## Topaze
	Color(0.35, 1.00, 0.60),  ## Émeraude
	Color(1.00, 0.30, 0.30),  ## Crimson
	Color(1.10, 1.00, 0.50),  ## Légendaire (glow)
]

## ── Bonus par niveau de prestige ─────────────────────────────────────────

## Multiplicateur XP additionnel par prestige (cumulatif) : +10% / prestige
func get_xp_mult() -> float:
	return 1.0 + 0.10 * float(prestige_level)

## Multiplicateur ressources rares : +5% / prestige
func get_rare_resource_mult() -> float:
	return 1.0 + 0.05 * float(prestige_level)

## Multiplicateur or des coffres : +8% / prestige
func get_chest_gold_mult() -> float:
	return 1.0 + 0.08 * float(prestige_level)

## Bonus vitesse héros : +3% / prestige
func get_hero_speed_bonus() -> float:
	return 0.03 * float(prestige_level)

## Skill points bonus au démarrage après prestige : +2 / prestige
func get_starting_skill_points() -> int:
	return 2 * prestige_level

## ── Runtime state ─────────────────────────────────────────────────────────

var prestige_level: int = 0
var total_prestiges: int = 0  ## Lifetime count (should equal prestige_level but tracked separately)
var prestige_date: Array[String] = []  ## Date of each prestige

signal prestige_gained(new_level: int, title: String)

## ── Lifecycle ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()

## ── Prestige logic ────────────────────────────────────────────────────────

## Returns true if the player can currently prestige.
func can_prestige() -> bool:
	if HeroProgression == null:
		return false
	if prestige_level >= MAX_PRESTIGE:
		return false
	return HeroProgression.hero_level >= HeroProgression.MAX_LEVEL

## Perform prestige — resets hero but preserves prestige bonuses.
func do_prestige() -> void:
	if not can_prestige():
		return

	prestige_level += 1
	total_prestiges += 1

	var dt := Time.get_datetime_dict_from_system()
	var date_str: String = "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	prestige_date.append(date_str)

	## Preserve zone mastery at 50% (knowledge of the land remains)
	if HeroProgression != null:
		for i: int in range(15):
			HeroProgression.zone_clears[i] = HeroProgression.zone_clears[i] / 2
		## Reset level/xp but keep zone_clears (already halved)
		HeroProgression.hero_level = 1
		HeroProgression.hero_xp = 0
		HeroProgression._save()

	## Grant starting skill points bonus
	var skill_tree: Node = get_node_or_null("/root/SkillTree")
	if skill_tree != null:
		skill_tree.reset_all()
		skill_tree.add_skill_points(get_starting_skill_points())

	_save()
	prestige_gained.emit(prestige_level, get_title())

## Returns the current prestige title string.
func get_title() -> String:
	if prestige_level <= 0 or prestige_level >= TITLES.size():
		return ""
	return TITLES[prestige_level]

## Returns the title color for HUD display.
func get_title_color() -> Color:
	var idx: int = clampi(prestige_level, 0, TITLE_COLORS.size() - 1)
	return TITLE_COLORS[idx]

## Display string for HUD: "Vétéran [P1]" or "" if no prestige.
func get_display_string() -> String:
	if prestige_level <= 0:
		return ""
	return "%s [P%d]" % [get_title(), prestige_level]

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("prestige", "level",  prestige_level)
	cfg.set_value("prestige", "total",  total_prestiges)
	cfg.set_value("prestige", "dates",  prestige_date)
	cfg.save("user://prestige.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://prestige.cfg") != OK:
		return
	prestige_level  = cfg.get_value("prestige", "level",  0)
	total_prestiges = cfg.get_value("prestige", "total",  0)
	prestige_date   = cfg.get_value("prestige", "dates",  [])

func reset_all() -> void:
	## Only called on absolute full reset (debug/dev mode)
	prestige_level  = 0
	total_prestiges = 0
	prestige_date.clear()
	_save()
