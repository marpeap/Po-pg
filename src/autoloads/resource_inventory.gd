## ResourceInventory — Autoload singleton
## 65 ressources : 35 Communes + 15 Rares + 10 Légendaires + 5 Épiques.
## Les indices 0-12 sont rétro-compatibles avec crafting_system.gd.
## Les nouvelles ressources sont ajoutées à partir de l'indice 13.
## Resets on session_reset. XP bridge → HeroProgression.add_xp().
extends Node

enum Rarity { COMMON = 0, RARE = 1, LEGENDARY = 2, EPIC = 3 }

enum Type {
	## ─── EXISTANTS (0-12) — rétro-compatibles ─────────────────────────────
	## Communes collecte-instant
	WOOD             = 0,   ## Bois — forêts
	STONE            = 1,   ## Pierre — ruines/mines
	HERB             = 2,   ## Herbe — tous biomes
	MUSHROOM         = 3,   ## Champignon — marécage/hantés
	SILK             = 4,   ## Soie — toiles
	## Rares minage temporisé
	IRON_ORE         = 5,   ## Minerai de Fer — armes
	COAL             = 6,   ## Charbon — combustible forge
	CRYSTAL          = 7,   ## Cristal — magie
	GEMSTONE         = 8,   ## Gemme — légendaire
	HARDWOOD         = 9,   ## Bois Dur — arbres anciens
	## Drops ennemis
	BONE             = 10,  ## Os — infanterie/cavalier
	HIDE             = 11,  ## Cuir — cavalier/élite (rare)
	SHADOW_ESSENCE   = 12,  ## Essence d'Ombre — boss seulement (légendaire)

	## ─── COMMUNES NOUVELLES (13-41) ───────────────────────────────────────
	## Zone A — Forêt de l'Éveil
	BIRCH_BARK       = 13,  ## Écorce de Bouleau
	WILD_HONEY       = 14,  ## Miel Sauvage
	ACORN            = 15,  ## Gland
	MOSS             = 16,  ## Mousse
	WILD_BERRY       = 17,  ## Baie Sauvage
	FEATHER          = 18,  ## Plume (drop oiseaux)
	RESIN            = 19,  ## Résine d'arbre
	## Zone B — Clairière Dorée
	CLAY             = 20,  ## Argile
	FLINT            = 21,  ## Silex
	LIMESTONE        = 22,  ## Calcaire
	BRONZE_SCRAP     = 23,  ## Éclat de Bronze
	ROPE_FIBER       = 24,  ## Fibre de Corde
	## Zone C — Ruines Ancestrales
	CHARCOAL         = 25,  ## Charbon de Bois (différent du COAL miné)
	## Zone D — Catacombes Oubliées
	SULFUR           = 26,  ## Soufre
	QUARTZ           = 27,  ## Quartz
	ROCK_SALT        = 28,  ## Sel Gemme
	## Zone E — Marécage Murmurant
	REED             = 29,  ## Roseau
	FROG_SKIN        = 30,  ## Peau de Grenouille (drop)
	ALGAE            = 31,  ## Algues
	SWAMP_HERB       = 32,  ## Herbe des Marais
	MUD_CLAY         = 33,  ## Argile Boueuse
	## Zone F — Forêt de Cristal
	GLOWING_MUSHROOM = 34,  ## Champignon Lumineux
	GNARLED_ROOT     = 35,  ## Racine Noueuse
	CLIMBING_VINE    = 36,  ## Liane Grimpante
	## Zones G-I — Cendres / Feu / Glace
	ASH              = 37,  ## Cendre
	BLACK_SOIL       = 38,  ## Terre Noire
	DEAD_WOOD        = 39,  ## Bois Mort
	## Zones J-K — Désert / Temple
	PINE_CONE        = 40,  ## Pomme de Pin
	VOLCANIC_STONE   = 41,  ## Pierre Volcanique

	## ─── RARES NOUVELLES (42-50) ──────────────────────────────────────────
	SILVER_LICHEN    = 42,  ## Lichen Argenté — grottes secrètes
	GHOST_MUSHROOM   = 43,  ## Champignon Fantôme — zone hantée
	GOLDEN_SAP       = 44,  ## Sève Dorée — arbres anciens rares
	SNAKE_SCALE      = 45,  ## Écaille de Serpent — drop serpent géant
	ICE_CRYSTAL      = 46,  ## Cristal de Glace — toundra
	LAVA_FLOWER      = 47,  ## Fleur de Lave — gouffre volcanique
	STAR_DUST        = 48,  ## Poussière d'Étoile — pics éthérés / nuit
	GOLEM_EYE        = 49,  ## Oeil de Golem — drop golem
	WIND_ESSENCE     = 50,  ## Essence des Vents — pics éthérés

	## ─── LÉGENDAIRES (51-59) ──────────────────────────────────────────────
	ADAMANTITE       = 51,  ## Adamantite — forge légendaire
	MYTHRIL          = 52,  ## Mythril — cime sacrée seulement
	MOONSTONE        = 53,  ## Pierre de Lune — grottes nocturnes
	DRAGON_HEART     = 54,  ## Coeur de Dragon — drop boss dragon
	ETERNAL_ESSENCE  = 55,  ## Essence Éternelle — zone temple
	TIME_FRAGMENT    = 56,  ## Fragment du Temps — événement rare
	GODS_TEAR        = 57,  ## Larme des Dieux — sanctuaire sacré
	PRIMAL_FLAME     = 58,  ## Flamme Primordiale — gouffre de feu
	CRYSTALLIZED_SHADOW = 59, ## Ombre Cristallisée — nécropole

	## ─── ÉPIQUES (60-64) ──────────────────────────────────────────────────
	WORLD_CORE       = 60,  ## Noyau du Monde — boss zone 15
	VOID_BREATH      = 61,  ## Souffle du Néant — boss néant
	TITAN_BLOOD      = 62,  ## Sang des Titans — boss titan
	ANCIENT_RUNE     = 63,  ## Rune Ancienne — coffre légendaire caché
	CHAOS_ESSENCE    = 64,  ## Essence du Chaos — événement chaos
}

const TYPE_COUNT := 65

## Rarity tier par index (0=COMMON 1=RARE 2=LEGENDARY 3=EPIC)
## Indices 0-64 dans le même ordre que l'enum.
const RARITIES: Array[int] = [
	## 0-4   WOOD STONE HERB MUSHROOM SILK
	0, 0, 0, 0, 0,
	## 5-9   IRON_ORE COAL CRYSTAL GEMSTONE HARDWOOD
	1, 1, 1, 1, 1,
	## 10-12 BONE HIDE SHADOW_ESSENCE
	0, 1, 2,
	## 13-41 nouvelles communes (29 entrées)
	0, 0, 0, 0, 0, 0, 0,  ## 13-19 BIRCH_BARK..RESIN
	0, 0, 0, 0, 0,         ## 20-24 CLAY..ROPE_FIBER
	0,                     ## 25    CHARCOAL
	0, 0, 0,               ## 26-28 SULFUR QUARTZ ROCK_SALT
	0, 0, 0, 0, 0,         ## 29-33 REED..MUD_CLAY
	0, 0, 0,               ## 34-36 GLOWING_MUSHROOM GNARLED_ROOT CLIMBING_VINE
	0, 0, 0,               ## 37-39 ASH BLACK_SOIL DEAD_WOOD
	0, 0,                  ## 40-41 PINE_CONE VOLCANIC_STONE
	## 42-50 rares nouvelles (9 entrées)
	1, 1, 1, 1, 1, 1, 1, 1, 1,
	## 51-59 légendaires (9 entrées)
	2, 2, 2, 2, 2, 2, 2, 2, 2,
	## 60-64 épiques (5 entrées)
	3, 3, 3, 3, 3,
]

## Noms courts français pour HUD (≤12 chars)
const SHORT_NAMES: Array[String] = [
	## 0-4
	"Bois", "Pierre", "Herbe", "Champ.", "Soie",
	## 5-9
	"Fer", "Charbon", "Cristal", "Gemme", "Bois Dur",
	## 10-12
	"Os", "Cuir", "Ombre",
	## 13-19
	"Écorce", "Miel", "Gland", "Mousse", "Baie",
	"Plume", "Résine",
	## 20-24
	"Argile", "Silex", "Calcaire", "Bronze", "Fibre",
	## 25
	"Ch.Bois",
	## 26-28
	"Soufre", "Quartz", "Sel",
	## 29-33
	"Roseau", "Grenouil.", "Algues", "H.Marais", "Arg.Boue",
	## 34-36
	"C.Lumin.", "Rac.Noue", "Liane",
	## 37-39
	"Cendre", "Terre N.", "B.Mort",
	## 40-41
	"Pomme Pin", "P.Volcan.",
	## 42-50
	"Lichen Arg.", "C.Fantôme", "Sève Or", "Écaille",
	"Crist.Glace", "Fl.Lave", "Étoiles", "Oeil Gol.", "Ess.Vents",
	## 51-59
	"Adamantite", "Mythril", "P.Lune", "C.Dragon",
	"Ess.Étern.", "Frag.Temps", "Larme D.", "Fl.Primo.", "Ombre Crist.",
	## 60-64
	"Noyau M.", "Souf.Néant", "Sang Titan", "Rune Anc.", "Ess.Chaos",
]

## Couleur HUD par rareté
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  ## COMMON — gris
	Color(0.20, 0.90, 0.30),  ## RARE — vert
	Color(0.40, 0.55, 1.00),  ## LEGENDARY — bleu
	Color(0.90, 0.35, 1.00),  ## EPIC — violet
]

## XP gagné par collecte selon la rareté
const RARITY_XP: Array[int] = [2, 5, 15, 40]

## Emitted whenever any resource count changes.
signal resource_changed(type: int, new_count: int)

var _counts: Array[int] = []

func _ready() -> void:
	_counts.resize(TYPE_COUNT)
	_counts.fill(0)
	GameStateMachine.session_reset.connect(_on_session_reset)

## Ajoute [amount] du type [type]. Déclenche XP héros selon rareté.
func add(type: int, amount: int) -> void:
	if type < 0 or type >= TYPE_COUNT:
		return
	_counts[type] += amount
	resource_changed.emit(type, _counts[type])
	## XP héros proportionnel à la rareté
	if HeroProgression != null:
		var xp: int = RARITY_XP[RARITIES[type]] * amount
		HeroProgression.add_xp(xp)

## Dépense [amount] du type [type]. Retourne false si insuffisant.
func spend(type: int, amount: int) -> bool:
	if type < 0 or type >= TYPE_COUNT:
		return false
	if _counts[type] < amount:
		return false
	_counts[type] -= amount
	resource_changed.emit(type, _counts[type])
	return true

## Retourne le stock actuel du type.
func get_count(type: int) -> int:
	if type < 0 or type >= TYPE_COUNT:
		return 0
	return _counts[type]

## Retourne true si au moins [amount] du type est disponible.
func has_enough(type: int, amount: int) -> bool:
	if type < 0 or type >= TYPE_COUNT:
		return false
	return _counts[type] >= amount

## Retourne [[type, count]] pour les types non vides (pour affichage HUD).
func get_nonempty() -> Array:
	var result: Array = []
	for i: int in range(TYPE_COUNT):
		if _counts[i] > 0:
			result.append([i, _counts[i]])
	return result

## Retourne la rareté du type (0=COMMON 1=RARE 2=LEGENDARY 3=EPIC).
func get_rarity(type: int) -> int:
	if type < 0 or type >= TYPE_COUNT:
		return 0
	return RARITIES[type]

func _on_session_reset() -> void:
	for i: int in range(TYPE_COUNT):
		_counts[i] = 0
		resource_changed.emit(i, 0)
