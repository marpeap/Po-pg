## QuestManager — Gestionnaire de quêtes principal du mode RPG.
## Inspiré de BOTW (Stone Echoes = mémoires environnementales),
## FFXIV (chaînes de quêtes NPC longues), et Stardew Valley (pas de pression temporelle).
##
## Contient :
##   - Quête principale : 15 chapitres (Forge-Heart)
##   - Chaînes NPC : 5 NPCs × 5 étapes
##   - Système de Codex de zones : 5 objectifs par zone
##   - Mystères du monde : 10 anomalies
##
## ADR-009 : session-only (pas de FileAccess en session)
## ConfigFile pour persistance entre sessions.
extends Node

## ── Quête Principale — Forge-Heart ───────────────────────────────────────

enum MainQuestState {
	NOT_STARTED  = 0,
	IN_PROGRESS  = 1,
	COMPLETED    = 2,
}

## 15 chapitres — chaque chapitre débloqué par le précédent + condition de zone.
const MAIN_QUEST_CHAPTERS: Array[Dictionary] = [
	{id=0,  title="L'Appel des Ruines",        zone=0,  wave=1,  desc="Explorez la Forêt de l'Éveil. Le Forgeron parle d'un artefact brisé.",              xp=100},
	{id=1,  title="Premier Éclat",              zone=1,  wave=1,  desc="Trouvez le premier Éclat du Forge-Cœur dans la Clairière Dorée.",                  xp=120},
	{id=2,  title="Les Ruines Parlent",         zone=2,  wave=2,  desc="Les ruines ancestrales cachent le deuxième éclat. Méfiez-vous des gardiens.",       xp=150},
	{id=3,  title="Le Chant des Catacombes",    zone=3,  wave=3,  desc="Descendez dans les catacombes. L'éclat y brille d'une lueur froide.",               xp=180},
	{id=4,  title="Le Secret du Marécage",      zone=4,  wave=4,  desc="Le Sage connaît l'emplacement de l'éclat des marais. Interrogez-le.",               xp=200},
	{id=5,  title="Cristaux et Mensonges",      zone=5,  wave=5,  desc="La Forêt de Cristal cache l'éclat derrière une illusion. Persévérez.",              xp=220},
	{id=6,  title="Cendres du Passé",           zone=6,  wave=6,  desc="Les terres dévastées gardent un éclat noir. Attention aux ambuscades.",             xp=250},
	{id=7,  title="Au Cœur du Volcan",          zone=7,  wave=8,  desc="L'éclat de lave ne peut être pris qu'en survie. Préparez vos défenses.",            xp=280},
	{id=8,  title="La Glaciation Oubliée",      zone=8,  wave=9,  desc="La toundra gelée protège l'éclat de glace. Surmontez le blizzard.",                 xp=300},
	{id=9,  title="Sables et Ossements",        zone=9,  wave=10, desc="Le désert cache l'éclat sous des décombres anciens.",                               xp=320},
	{id=10, title="Le Temple Révèle",           zone=10, wave=11, desc="Le temple sacré s'ouvre seulement au Maître Érudit. Retournez si vous êtes prêt.",   xp=350},
	{id=11, title="Profondeurs Indicibles",     zone=11, wave=12, desc="Les grottes les plus profondes abritent l'éclat des ombres.",                       xp=380},
	{id=12, title="Convergence Éthérée",        zone=12, wave=14, desc="Les pics éthérés. L'éclat flotte entre deux réalités.",                             xp=400},
	{id=13, title="La Nécropole Parle",         zone=13, wave=16, desc="Les morts gardent le dernier éclat. Accomplissez le rite du souvenir.",              xp=450},
	{id=14, title="Le Forge-Cœur Renaît",       zone=14, wave=20, desc="Tous les éclats réunis. Forgez le Forge-Cœur à la Cime Sacrée.",                    xp=1000},
]

## Récompenses de Tour à chaque chapitre (buff TD permanent)
const CHAPTER_TD_REWARDS: Array[String] = [
	"",                ## Ch. 0 — introductif
	"archer_range_+10",
	"arrow_speed_+15pct",
	"tower_hp_+25",
	"castle_regen_x2",
	"coin_magnet_+30px",
	"archer_dmg_+10pct",
	"fire_tower_perm",
	"ice_slow_enhanced",
	"lightning_chain",
	"formation_unlock",
	"tower_count_+1",
	"hero_spell_+1",
	"wave_preview",
	"forge_heart_final",
]

## ── Chaînes NPC ──────────────────────────────────────────────────────────

## 5 NPCs × 5 étapes de quête
const NPC_CHAINS: Array[Dictionary] = [
	## Marchand Darro
	{
		npc_id=0, name="Marchand Darro",
		steps=[
			{wave=1,  zone=0, req_type="talk",      req_val=0, desc="Parlez à Darro dans la Forêt de l'Éveil.",                                         xp=50,  reward="shop_discount_10pct"},
			{wave=4,  zone=3, req_type="collect",   req_val=5, res=1,    desc="Darro cherche 5 pierres pour sa boutique nomade.",                         xp=75,  reward="shop_discount_20pct"},
			{wave=8,  zone=6, req_type="camp",      req_val=1,            desc="Des bandits pillent les marchandises. Libérez un camp.",                   xp=100, reward="gold_bonus_10pct"},
			{wave=14, zone=10, req_type="collect",  req_val=2, res=44,   desc="Darro a besoin de Sève Dorée pour son élixir de longévité.",               xp=150, reward="trade_post_access"},
			{wave=20, zone=14, req_type="talk",     req_val=0,            desc="Darro révèle la vérité sur le Forge-Cœur.",                               xp=300, reward="merchant_bonded"},
		]
	},
	## Éclaireuse Lira
	{
		npc_id=1, name="Eclaireuse Lira",
		steps=[
			{wave=1,  zone=1, req_type="talk",      req_val=0,            desc="Lira vous enseigne les bases de l'exploration.",                           xp=50,  reward="cave_radius_+20px"},
			{wave=4,  zone=4, req_type="cave",      req_val=1,            desc="Lira vous demande de cartographier une caverne.",                          xp=75,  reward="scout_mark_ability"},
			{wave=8,  zone=7, req_type="zone",      req_val=7,            desc="Lira teste votre endurance : atteignez la Vallée de Feu.",                 xp=100, reward="stamina_+20pct"},
			{wave=14, zone=11, req_type="collect",  req_val=3, res=42,   desc="Lira cherche du Lichen Argenté pour soigner une blessure.",                xp=150, reward="scout_reveal_all_caves"},
			{wave=20, zone=14, req_type="talk",     req_val=0,            desc="Lira révèle son passé de gardienne du Forge-Cœur.",                       xp=300, reward="scout_bonded"},
		]
	},
	## Sage Orrin
	{
		npc_id=2, name="Sage Orrin",
		steps=[
			{wave=2,  zone=2, req_type="lore",      req_val=3,            desc="Lisez 3 tablettes de lore pour mériter l'attention d'Orrin.",              xp=50,  reward="lore_xp_+25pct"},
			{wave=5,  zone=5, req_type="collect",   req_val=1, res=7,    desc="Orrin a besoin d'un Cristal pour ses recherches.",                          xp=75,  reward="spell_dmg_+15pct"},
			{wave=9,  zone=9, req_type="talk",      req_val=0,            desc="Orrin avoue avoir détruit le manuel du Forge-Cœur.",                       xp=100, reward="sage_tome_unlock"},
			{wave=15, zone=12, req_type="mystery",  req_val=3,            desc="Élucidez 3 mystères du monde pour prouver votre sagesse.",                 xp=150, reward="ancient_knowledge_passive"},
			{wave=20, zone=14, req_type="talk",     req_val=0,            desc="Orrin se sacrifie pour réactiver le Forge-Cœur.",                         xp=300, reward="sage_bonded"},
		]
	},
	## Barde Caelo
	{
		npc_id=3, name="Barde Caelo",
		steps=[
			{wave=1,  zone=0, req_type="talk",      req_val=0,            desc="Écoutez la chanson de Caelo — elle raconte la légende de Garrison.",       xp=50,  reward="speed_buff_30s"},
			{wave=4,  zone=3, req_type="camp",      req_val=2,            desc="Caelo veut composer sur la victoire. Défaites 2 camps.",                   xp=75,  reward="momentum_boost"},
			{wave=8,  zone=8, req_type="zone",      req_val=8,            desc="Caelo compose sa symphonie des glaces. Atteignez la Toundra.",              xp=100, reward="xp_song_+20pct"},
			{wave=14, zone=12, req_type="collect",  req_val=1, res=48,   desc="Caelo cherche de la Poussière d'Étoile pour son final.",                    xp=150, reward="bard_concert_unlock"},
			{wave=20, zone=14, req_type="talk",     req_val=0,            desc="Caelo chante la victoire finale. Garrison entre dans la légende.",         xp=300, reward="bard_bonded"},
		]
	},
	## Guérisseuse Senna
	{
		npc_id=4, name="Guerisseuse Senna",
		steps=[
			{wave=1,  zone=0, req_type="collect",   req_val=3, res=2,    desc="Senna a besoin d'herbes pour soigner des blessés.",                         xp=50,  reward="heal_shrine_cd_-30s"},
			{wave=4,  zone=4, req_type="collect",   req_val=2, res=32,   desc="La Herbe des Marais est rare — trouvez-en 2 pour Senna.",                   xp=75,  reward="castle_regen_+25pct"},
			{wave=9,  zone=9, req_type="talk",      req_val=0,            desc="Senna révèle que sa grand-mère a traité le créateur du Forge-Cœur.",        xp=100, reward="aura_heal_unlock"},
			{wave=15, zone=13, req_type="collect",  req_val=1, res=55,   desc="Senna a besoin d'Essence Éternelle pour son antidote final.",               xp=150, reward="mass_heal_ability"},
			{wave=20, zone=14, req_type="talk",     req_val=0,            desc="Senna guérit les blessures laissées par le conflit. Le cycle s'achève.",    xp=300, reward="healer_bonded"},
		]
	},
]

## ── Codex de Zones (5 objectifs par zone) ────────────────────────────────

## Types d'objectifs
enum ZoneObjType {
	ENTRY      = 0,  ## Visiter la zone
	GATHER     = 1,  ## Collecter N ressources de la zone
	COMBAT     = 2,  ## Vaincre N camps de la zone
	SECRET     = 3,  ## Trouver la caverne / coffre secret
	STORY      = 4,  ## Lire la tablette de lore de la zone
}

## ── Mystères du Monde (10 anomalies) ─────────────────────────────────────

enum MysteryState { HIDDEN = 0, OBSERVED = 1, CLUE_FOUND = 2, CROSS_REFERENCED = 3, UNDERSTOOD = 4 }

const MYSTERIES: Array[Dictionary] = [
	{id=0, zone=1,  name="L'Arbre qui Saigne Or",         desc="Un arbre ancien pleure de la sève dorée. Pourquoi maintenant ?"},
	{id=1, zone=2,  name="Le Cercle de Pierre Brisé",     desc="Les ruines forment un cercle parfait... sauf un segment manquant."},
	{id=2, zone=3,  name="La Voix des Catacombes",        desc="Des chuchotements montent des profondeurs. Aucun vivant ne devrait y être."},
	{id=3, zone=4,  name="Les Flambeaux Éternels",        desc="Des torches brûlent dans le marécage sans jamais s'éteindre ni se consumer."},
	{id=4, zone=5,  name="Le Cristal qui Chante",         desc="Un cristal émet une mélodie constante. Elle correspond à une chanson ancienne."},
	{id=5, zone=7,  name="Le Pont de Lave Stable",        desc="Un pont de pierre traverse la lave sans fondations. Qui l'a construit ?"},
	{id=6, zone=9,  name="Les Empreintes dans le Sable",  desc="Des empreintes de géant qui n'ont pas de début ni de fin."},
	{id=7, zone=10, name="L'Autel Actif",                 desc="L'autel du temple génère encore de l'énergie. Le culte n'est pas mort."},
	{id=8, zone=12, name="L'Étoile Qui Ne Bouge Pas",     desc="Une étoile reste fixe pendant que les autres tournent. Elle pointe vers le sol."},
	{id=9, zone=13, name="Le Dernier Soldat",             desc="Une silhouette en armure observe la nécropole. Elle ne bouge jamais."},
]

## Le mystère 9 n'a pas de résolution — c'est intentionnel (pic émotionnel).
const MYSTERY_REWARDS: Array[int] = [51, 52, 53, 54, 55, 56, 57, 58, 59, 63]  ## ResourceInventory.Type

## ── Runtime state ─────────────────────────────────────────────────────────

var main_quest_chapter: int = 0
var main_quest_states: Array[int] = []  ## MainQuestState per chapter

## NPC chain progress: [npc_id][step_id] = completed bool
var npc_chain_progress: Array[Array] = []

## Zone codex: [zone_id][obj_type] = completed bool
var zone_codex: Array[Array] = []

## Mystery states: [mystery_id] = MysteryState int
var mystery_states: Array[int] = []

## Zones visited this session
var zones_visited: Array[bool] = []

## Active chapter ID being tracked
var active_tracked_quest: int = -1

## NPC chain reward — Sage Orrin "lore_xp_+25pct": bonus fraction applied in on_lore_read().
## Barde Caelo "xp_song_+20pct": additive fraction applied to all XP grants.
var _lore_xp_bonus_pct: float = 0.0
var _all_xp_bonus_pct:  float = 0.0

signal quest_chapter_completed(chapter_id: int)
signal npc_step_completed(npc_id: int, step_id: int, reward: String)
signal zone_codex_completed(zone_id: int)
signal mystery_advanced(mystery_id: int, new_state: MysteryState)
signal quest_notification(title: String, description: String)

## ── Lifecycle ─────────────────────────────────────────────────────────────

func _ready() -> void:
	main_quest_states.resize(15)
	main_quest_states.fill(MainQuestState.NOT_STARTED)
	main_quest_states[0] = MainQuestState.IN_PROGRESS

	npc_chain_progress.resize(5)
	for i: int in range(5):
		npc_chain_progress[i] = []
		npc_chain_progress[i].resize(5)
		npc_chain_progress[i].fill(false)

	zone_codex.resize(15)
	for i: int in range(15):
		zone_codex[i] = []
		zone_codex[i].resize(5)
		zone_codex[i].fill(false)

	mystery_states.resize(10)
	mystery_states.fill(MysteryState.HIDDEN)

	zones_visited.resize(15)
	zones_visited.fill(false)

	_load()

## ── Zone entry tracking ────────────────────────────────────────────────────

## Called from ExplorationMap._process() when zone changes
func on_zone_entered(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= 15:
		return
	var just_visited: bool = not zones_visited[zone_idx]
	zones_visited[zone_idx] = true

	## Zone codex: ENTRY objective
	_complete_codex_obj(zone_idx, ZoneObjType.ENTRY)

	## Reveal mysteries in this zone that are HIDDEN
	for m: Dictionary in MYSTERIES:
		if m.zone == zone_idx and mystery_states[m.id] == MysteryState.HIDDEN:
			mystery_states[m.id] = MysteryState.OBSERVED
			mystery_advanced.emit(m.id, MysteryState.OBSERVED)

	## Check main quest chapter condition
	_check_main_quest_zone(zone_idx)

	## Notify DailyChallenge
	if DailyChallenge != null:
		DailyChallenge.on_zone_reached(zone_idx)

	## Check if all 15 zones now visited
	if zones_visited.all(func(v: bool) -> bool: return v):
		if AchievementSystem != null:
			AchievementSystem.on_all_zones_visited()

	if just_visited:
		_save()

## ── Resource collection forwarding ───────────────────────────────────────

func on_resource_collected(res_type: int, amount: int) -> void:
	var zone_idx: int = _hero_current_zone()
	if zone_idx >= 0:
		_complete_codex_obj(zone_idx, ZoneObjType.GATHER)

	## Forward to DailyChallenge
	if DailyChallenge != null:
		DailyChallenge.on_resource_collected(res_type, amount)

	## Check NPC chain resource requirements
	_check_npc_resource_requirements(res_type, amount)

## ── Camp cleared forwarding ───────────────────────────────────────────────

func on_camp_cleared(zone_idx: int, tier: int) -> void:
	_complete_codex_obj(zone_idx, ZoneObjType.COMBAT)
	if DailyChallenge != null:
		DailyChallenge.on_camp_cleared()
	if AchievementSystem != null:
		AchievementSystem.on_camp_cleared(tier)

## ── Cave discovered ───────────────────────────────────────────────────────

func on_cave_discovered(zone_idx: int) -> void:
	_complete_codex_obj(zone_idx, ZoneObjType.SECRET)
	if DailyChallenge != null:
		DailyChallenge.on_cave_discovered()
	if AchievementSystem != null:
		AchievementSystem.on_cave_discovered()
	## Advance mystery cross-reference
	var zone_mystery_id: int = _mystery_in_zone(zone_idx)
	if zone_mystery_id >= 0 and mystery_states[zone_mystery_id] == MysteryState.OBSERVED:
		mystery_states[zone_mystery_id] = MysteryState.CLUE_FOUND
		mystery_advanced.emit(zone_mystery_id, MysteryState.CLUE_FOUND)

## ── Lore read ─────────────────────────────────────────────────────────────

func on_lore_read(zone_idx: int) -> void:
	_complete_codex_obj(zone_idx, ZoneObjType.STORY)
	if DailyChallenge != null:
		DailyChallenge.on_resource_collected(0, 0)  ## placeholder
	if AchievementSystem != null:
		AchievementSystem.on_lore_read()
	## XP from lore (base + SkillTree bonus + NPC Orrin lore bonus + Caelo song bonus)
	var bonus_xp: int = 10
	if SkillTree != null:
		bonus_xp += SkillTree.get_lore_xp_bonus()
	var xp_mult: float = 1.0 + _lore_xp_bonus_pct + _all_xp_bonus_pct
	bonus_xp = maxi(1, int(float(bonus_xp) * xp_mult))
	if HeroProgression != null:
		HeroProgression.add_xp(bonus_xp)

## ── NPC interaction ───────────────────────────────────────────────────────

## Called from npc_wanderer.gd when player interacts
func on_npc_interaction(npc_id: int) -> void:
	var chain: Dictionary = NPC_CHAINS[npc_id]
	for step_idx: int in range(chain.steps.size()):
		if npc_chain_progress[npc_id][step_idx]:
			continue
		var step: Dictionary = chain.steps[step_idx]
		if step.req_type == "talk":
			_complete_npc_step(npc_id, step_idx)
			break
		## Other types need external triggers — break on first incomplete
		break

## ── NPC step completion ───────────────────────────────────────────────────

func _complete_npc_step(npc_id: int, step_idx: int) -> void:
	if npc_chain_progress[npc_id][step_idx]:
		return
	npc_chain_progress[npc_id][step_idx] = true
	var step: Dictionary = NPC_CHAINS[npc_id].steps[step_idx]
	npc_step_completed.emit(npc_id, step_idx, step.reward)
	if HeroProgression != null:
		var step_xp: int = maxi(1, int(float(step.xp) * (1.0 + _all_xp_bonus_pct)))
		HeroProgression.add_xp(step_xp)
	quest_notification.emit(NPC_CHAINS[npc_id].name, step.desc)
	if DailyChallenge != null:
		DailyChallenge.on_contract_completed()
	_save()

func _check_npc_resource_requirements(res_type: int, _amount: int) -> void:
	for npc_id: int in range(5):
		for step_idx: int in range(5):
			if npc_chain_progress[npc_id][step_idx]:
				continue
			var step: Dictionary = NPC_CHAINS[npc_id].steps[step_idx]
			if step.req_type == "collect" and step.get("res", -1) == res_type:
				if ResourceInventory.has_enough(res_type, step.req_val):
					_complete_npc_step(npc_id, step_idx)
			break  ## Only check first incomplete step per chain

## ── Zone codex ────────────────────────────────────────────────────────────

func _complete_codex_obj(zone_idx: int, obj_type: ZoneObjType) -> void:
	if zone_idx < 0 or zone_idx >= 15:
		return
	if zone_codex[zone_idx][obj_type]:
		return
	zone_codex[zone_idx][obj_type] = true
	## Check if all 5 objectives done
	var all_done: bool = zone_codex[zone_idx].all(func(b: bool) -> bool: return b)
	if all_done:
		zone_codex_completed.emit(zone_idx)
		if HeroProgression != null:
			HeroProgression.add_xp(50)
		if HeroProgression != null:
			HeroProgression.register_zone_clear(zone_idx)
	_save()

## ── Main quest ────────────────────────────────────────────────────────────

func _check_main_quest_zone(zone_idx: int) -> void:
	if main_quest_chapter >= 15:
		return
	var chapter: Dictionary = MAIN_QUEST_CHAPTERS[main_quest_chapter]
	if zone_idx >= chapter.zone and main_quest_states[main_quest_chapter] == MainQuestState.IN_PROGRESS:
		_advance_main_quest()

func _advance_main_quest() -> void:
	var chapter_id: int = main_quest_chapter
	main_quest_states[chapter_id] = MainQuestState.COMPLETED
	if HeroProgression != null:
		HeroProgression.add_xp(MAIN_QUEST_CHAPTERS[chapter_id].xp)
	quest_chapter_completed.emit(chapter_id)
	quest_notification.emit(
		"Chapitre %d terminé" % (chapter_id + 1),
		MAIN_QUEST_CHAPTERS[chapter_id].title)

	## Advance to next chapter
	if chapter_id + 1 < 15:
		main_quest_chapter = chapter_id + 1
		main_quest_states[main_quest_chapter] = MainQuestState.IN_PROGRESS
	_save()

## ── Mystery ───────────────────────────────────────────────────────────────

func advance_mystery(mystery_id: int) -> void:
	if mystery_id < 0 or mystery_id >= 10:
		return
	var current: int = mystery_states[mystery_id]
	if current >= MysteryState.UNDERSTOOD:
		return
	## Mystery 9 (The Last Soldier) never reaches UNDERSTOOD
	if mystery_id == 9 and current >= MysteryState.CROSS_REFERENCED:
		return
	mystery_states[mystery_id] = current + 1
	mystery_advanced.emit(mystery_id, mystery_states[mystery_id] as MysteryState)
	if mystery_states[mystery_id] == MysteryState.UNDERSTOOD:
		var reward_res: int = MYSTERY_REWARDS[mystery_id]
		ResourceInventory.add(reward_res, 1)
		if HeroProgression != null:
			HeroProgression.register_discovery()
	_save()

func get_understood_mysteries() -> int:
	var count: int = 0
	for s: int in mystery_states:
		if s >= MysteryState.UNDERSTOOD:
			count += 1
	return count

## ── Utility ───────────────────────────────────────────────────────────────

func _hero_current_zone() -> int:
	var hero_nodes: Array = get_tree().get_nodes_in_group("hero")
	if hero_nodes.is_empty():
		return -1
	var hero: Node2D = hero_nodes[0] as Node2D
	var x: float = hero.global_position.x
	return clampi(int(x / 3200.0), 0, 14)

func _mystery_in_zone(zone_idx: int) -> int:
	for m: Dictionary in MYSTERIES:
		if m.zone == zone_idx:
			return m.id
	return -1

## Returns how many NPC chain steps have been completed for a given NPC.
func get_npc_progress(npc_id: int) -> int:
	if npc_id < 0 or npc_id >= npc_chain_progress.size():
		return 0
	var count: int = 0
	for done: bool in npc_chain_progress[npc_id]:
		if done:
			count += 1
	return count

func get_codex_completion_pct(zone_idx: int) -> float:
	if zone_idx < 0 or zone_idx >= 15:
		return 0.0
	var done: int = 0
	for b: bool in zone_codex[zone_idx]:
		if b:
			done += 1
	return float(done) / 5.0

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("main", "chapter", main_quest_chapter)
	for i: int in range(15):
		cfg.set_value("main", "state_%d" % i, main_quest_states[i])
		cfg.set_value("codex_%d" % i, "obj", zone_codex[i])
		cfg.set_value("zones", "visited_%d" % i, zones_visited[i])
	for npc: int in range(5):
		cfg.set_value("npc_%d" % npc, "steps", npc_chain_progress[npc])
	for m: int in range(10):
		cfg.set_value("mysteries", "m%d" % m, mystery_states[m])
	cfg.save("user://quest_data.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://quest_data.cfg") != OK:
		return
	main_quest_chapter = cfg.get_value("main", "chapter", 0)
	for i: int in range(15):
		main_quest_states[i] = cfg.get_value("main", "state_%d" % i, 0)
		var obj: Array = cfg.get_value("codex_%d" % i, "obj", [false,false,false,false,false])
		for j: int in range(5):
			zone_codex[i][j] = obj[j] if j < obj.size() else false
		zones_visited[i] = cfg.get_value("zones", "visited_%d" % i, false)
	for npc: int in range(5):
		var steps: Array = cfg.get_value("npc_%d" % npc, "steps", [false,false,false,false,false])
		for s: int in range(5):
			npc_chain_progress[npc][s] = steps[s] if s < steps.size() else false
	for m: int in range(10):
		mystery_states[m] = cfg.get_value("mysteries", "m%d" % m, 0)

## Re-emit all completed rewards so Main.gd can re-apply permanent bonuses
## after connecting signals. Called by Main._wire_signals() after all connections.
func replay_completed_rewards() -> void:
	## Re-apply quest chapter TD rewards
	for i: int in range(main_quest_states.size()):
		if main_quest_states[i] == MainQuestState.COMPLETED:
			quest_chapter_completed.emit(i)
	## Re-apply NPC step rewards
	for npc_id: int in range(5):
		for step_id: int in range(5):
			if npc_chain_progress[npc_id][step_id]:
				var step: Dictionary = NPC_CHAINS[npc_id].steps[step_id]
				npc_step_completed.emit(npc_id, step_id, step.reward)

func reset_all() -> void:
	main_quest_chapter = 0
	main_quest_states.fill(MainQuestState.NOT_STARTED)
	main_quest_states[0] = MainQuestState.IN_PROGRESS
	for i: int in range(15):
		zone_codex[i].fill(false)
	for i: int in range(5):
		npc_chain_progress[i].fill(false)
	mystery_states.fill(MysteryState.HIDDEN)
	zones_visited.fill(false)
	_save()
