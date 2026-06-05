## JournalPanel — Journal de découverte tactile (4 onglets RPG).
## Inspiré de FFXIV (journal de quêtes clair), BOTW (compendium de découvertes).
##
## 4 onglets :
##   QUESTS   — Quête principale + chaînes NPC
##   CODEX    — Objectifs de zones (5 par zone)
##   MYSTERIES— 10 mystères du monde (états progressifs)
##   DAILY    — Challenges quotidiens + streak
##
## CanvasLayer layer=15, visible uniquement sur demande.
extends CanvasLayer

const W := 960.0
const H := 540.0
const PANEL_W := 820.0
const PANEL_H := 480.0
const PANEL_X := (W - PANEL_W) * 0.5
const PANEL_Y := (H - PANEL_H) * 0.5

const TAB_COUNT := 4
const TAB_NAMES: Array[String] = ["QUETES", "CODEX", "MYSTERES", "QUOTIDIEN"]
const TAB_COLORS: Array[Color] = [
	Color(0.85, 0.70, 0.25),  ## QUESTS  — or
	Color(0.30, 0.75, 0.50),  ## CODEX   — vert
	Color(0.55, 0.35, 0.90),  ## MYSTERY — violet
	Color(0.30, 0.65, 1.00),  ## DAILY   — bleu
]

## ── Nodes ────────────────────────────────────────────────────────────────────

var _bg: ColorRect = null
var _close_btn: Button = null
var _tab_btns: Array[Button] = []
var _content_root: Control = null
var _current_tab: int = 0

## Refs aux autoloads
var _quest: Node = null
var _daily: Node = null
var _prestige: Node = null

## ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 15
	visible = false
	_quest = get_node_or_null("/root/QuestManager")
	_daily = get_node_or_null("/root/DailyChallenge")
	_prestige = get_node_or_null("/root/PrestigeSystem")
	_build_ui()

## ── Build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	## Dim overlay
	var dim := ColorRect.new()
	dim.size = Vector2(W, H)
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	## Panel background
	_bg = ColorRect.new()
	_bg.size = Vector2(PANEL_W, PANEL_H)
	_bg.position = Vector2(PANEL_X, PANEL_Y)
	_bg.color = Color(0.08, 0.07, 0.06, 0.97)
	add_child(_bg)

	## Bordure
	for edge: Dictionary in [
		{r=Rect2(PANEL_X, PANEL_Y, PANEL_W, 2.0)},
		{r=Rect2(PANEL_X, PANEL_Y + PANEL_H - 2.0, PANEL_W, 2.0)},
		{r=Rect2(PANEL_X, PANEL_Y, 2.0, PANEL_H)},
		{r=Rect2(PANEL_X + PANEL_W - 2.0, PANEL_Y, 2.0, PANEL_H)},
	]:
		var b := ColorRect.new()
		b.position = edge.r.position
		b.size = edge.r.size
		b.color = Color(0.60, 0.55, 0.35)
		add_child(b)

	## Titre
	var title_lbl := Label.new()
	title_lbl.text = "JOURNAL DE L'AVENTURIER"
	title_lbl.position = Vector2(PANEL_X, PANEL_Y + 6.0)
	title_lbl.size = Vector2(PANEL_W - 80.0, 22.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
	add_child(title_lbl)

	## Onglets
	const TAB_W := 180.0
	const TAB_H := 30.0
	const TAB_Y := PANEL_Y + 30.0
	for i: int in range(TAB_COUNT):
		var tbtn := Button.new()
		tbtn.text = TAB_NAMES[i]
		tbtn.position = Vector2(PANEL_X + i * TAB_W + 4.0, TAB_Y)
		tbtn.size = Vector2(TAB_W - 4.0, TAB_H)
		tbtn.add_theme_font_size_override("font_size", 11)
		var captured_i := i
		tbtn.pressed.connect(func() -> void: _switch_tab(captured_i))
		add_child(tbtn)
		_tab_btns.append(tbtn)

	## Zone de contenu scrollable (simple Control pour ce prototype)
	_content_root = Control.new()
	_content_root.position = Vector2(PANEL_X + 4.0, PANEL_Y + 64.0)
	_content_root.size = Vector2(PANEL_W - 8.0, PANEL_H - 100.0)
	add_child(_content_root)

	## Fermer
	_close_btn = Button.new()
	_close_btn.text = "Fermer"
	_close_btn.position = Vector2(PANEL_X + PANEL_W - 82.0, PANEL_Y + PANEL_H - 30.0)
	_close_btn.size = Vector2(78.0, 26.0)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(hide_panel)
	add_child(_close_btn)

## ── Tab Switching ─────────────────────────────────────────────────────────────

func _switch_tab(idx: int) -> void:
	_current_tab = idx
	## Highlight onglet actif
	for i: int in range(_tab_btns.size()):
		var col: Color = TAB_COLORS[i] if i == idx else Color(0.4, 0.38, 0.30)
		_tab_btns[i].add_theme_color_override("font_color", col)
	_rebuild_content()

## ── Content Builders ──────────────────────────────────────────────────────────

func _rebuild_content() -> void:
	## Vider contenu
	for child: Node in _content_root.get_children():
		child.queue_free()

	match _current_tab:
		0: _build_quests_tab()
		1: _build_codex_tab()
		2: _build_mysteries_tab()
		3: _build_daily_tab()

func _build_quests_tab() -> void:
	if _quest == null:
		_add_label("QuestManager non disponible.", 4.0, 4.0, Color(0.6, 0.6, 0.6), 11)
		return
	var y: float = 4.0
	## Quête principale
	_add_label("Quete Principale — Forge-Coeur", 4.0, y, Color(1.0, 0.88, 0.30), 13)
	y += 22.0
	var states: Array = _quest.main_quest_states
	for i: int in range(states.size()):
		var ch: Dictionary = _quest.MAIN_QUEST_CHAPTERS[i]
		var state: int = states[i] if i < states.size() else 0
		var icon: String = "[ ]" if state == 0 else ("[>]" if state == 1 else "[x]")
		var col: Color = Color(0.5, 0.5, 0.5) if state == 0 else (Color(0.9, 0.9, 0.4) if state == 1 else Color(0.4, 0.9, 0.4))
		_add_label("%s Ch.%d %s" % [icon, i, ch.title], 12.0, y, col, 10)
		y += 16.0
		if y > 360.0:
			break
	## Chaînes NPC
	y += 10.0
	_add_label("Chaines NPC", 4.0, y, Color(0.70, 0.80, 1.00), 12)
	y += 20.0
	if _quest.has_method("get_npc_progress"):
		for npc_id: int in range(5):
			var chain: Dictionary = _quest.NPC_CHAINS[npc_id]
			var progress: int = _quest.get_npc_progress(npc_id)
			_add_label("%s : %d/5" % [chain.name, progress], 12.0, y, Color(0.80, 0.80, 0.70), 10)
			y += 14.0

func _build_codex_tab() -> void:
	if _quest == null:
		_add_label("QuestManager non disponible.", 4.0, 4.0, Color(0.6, 0.6, 0.6), 11)
		return
	var codex: Array = _quest.zone_codex
	const OBJ_NAMES: Array[String] = ["Entree", "Recolte", "Combat", "Secret", "Histoire"]
	var y: float = 4.0
	_add_label("Codex des Zones", 4.0, y, Color(0.30, 0.90, 0.60), 13)
	y += 22.0
	for zone_idx: int in range(codex.size()):
		var zone_objs: Array = codex[zone_idx]
		var done: int = 0
		for obj: bool in zone_objs:
			if obj:
				done += 1
		var pct: float = float(done) / float(zone_objs.size())
		var col: Color = Color(0.3, 0.9, 0.4) if pct >= 1.0 else (Color(0.9, 0.9, 0.3) if pct > 0.0 else Color(0.5, 0.5, 0.5))
		_add_label("Zone %d : %d/%d" % [zone_idx, done, zone_objs.size()], 8.0, y, col, 10)
		y += 14.0
		if y > 420.0:
			break

func _build_mysteries_tab() -> void:
	if _quest == null:
		_add_label("QuestManager non disponible.", 4.0, 4.0, Color(0.6, 0.6, 0.6), 11)
		return
	const STATE_NAMES: Array[String] = [
		"[Inconnu]", "[Observe]", "[Indice]", "[Relie]", "[Compris]"
	]
	const STATE_COLORS: Array[Color] = [
		Color(0.35, 0.35, 0.35),
		Color(0.60, 0.55, 0.85),
		Color(0.85, 0.80, 0.35),
		Color(0.35, 0.75, 0.85),
		Color(0.35, 0.90, 0.50),
	]
	var y: float = 4.0
	_add_label("Mysteres du Monde", 4.0, y, Color(0.70, 0.50, 1.00), 13)
	y += 22.0
	var mysteries: Array = _quest.MYSTERIES
	var mstates: Array = _quest.mystery_states
	for i: int in range(mysteries.size()):
		var myst: Dictionary = mysteries[i]
		var mstate: int = mstates[i] if i < mstates.size() else 0
		var sname: String = STATE_NAMES[mini(mstate, STATE_NAMES.size() - 1)]
		var col: Color = STATE_COLORS[mini(mstate, STATE_COLORS.size() - 1)]
		_add_label("%s — %s" % [myst.title, sname], 8.0, y, col, 10)
		y += 18.0

func _build_daily_tab() -> void:
	var y: float = 4.0

	## ── Prestige section ────────────────────────────────────────────────────
	if _prestige != null:
		var plevel: int = _prestige.prestige_level
		var ptitle: String = _prestige.get_display_string()
		var ptitle_col: Color = _prestige.get_title_color()
		_add_label("Prestige : %s" % (ptitle if plevel > 0 else "Aucun"), 4.0, y, ptitle_col, 12)
		y += 18.0
		var xp_mult: float = _prestige.get_xp_mult()
		var gold_mult: float = _prestige.get_chest_gold_mult()
		_add_label("XP x%.1f | Or coffre x%.1f" % [xp_mult, gold_mult],
				8.0, y, Color(0.75, 0.72, 0.55), 10)
		y += 16.0
		## Prestige button — only shown when level 50 is reached
		var can_p: bool = _prestige.can_prestige() if _prestige.has_method("can_prestige") else false
		var prestige_btn := Button.new()
		if can_p:
			prestige_btn.text = "PRESTIGE — Renaître [P%d → P%d]" % [plevel, plevel + 1]
			prestige_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		else:
			prestige_btn.text = "Prestige (requiert Niv.50)"
			prestige_btn.disabled = true
			prestige_btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		prestige_btn.position = Vector2(4.0, y)
		prestige_btn.size = Vector2(340.0, 26.0)
		prestige_btn.add_theme_font_size_override("font_size", 11)
		prestige_btn.pressed.connect(func() -> void:
			if _prestige != null and _prestige.can_prestige():
				_prestige.do_prestige()
				_rebuild_content())  ## Refresh tab after prestige
		_content_root.add_child(prestige_btn)
		y += 34.0
		## Divider
		var div := ColorRect.new()
		div.position = Vector2(0.0, y)
		div.size = Vector2(_content_root.size.x, 1.0)
		div.color = Color(0.35, 0.30, 0.20)
		_content_root.add_child(div)
		y += 8.0

	if _daily == null:
		_add_label("DailyChallenge non disponible.", 4.0, y, Color(0.6, 0.6, 0.6), 11)
		return
	## Streak
	var streak: int = _daily.get_streak()
	_add_label("Streak quotidien : %d jours" % streak, 4.0, y, Color(1.0, 0.75, 0.20), 13)
	y += 20.0
	var bonus_pct: int = _daily.get_streak_bonus_pct()
	_add_label("Bonus XP : +%d%%" % bonus_pct, 8.0, y, Color(0.90, 0.85, 0.40), 11)
	y += 22.0
	## Challenges
	_add_label("Challenges du jour :", 4.0, y, Color(0.60, 0.90, 1.00), 12)
	y += 20.0
	var challenges: Array[Dictionary] = _daily.get_challenges()
	for i: int in range(challenges.size()):
		var ch: Dictionary = challenges[i]
		var done: bool = ch.get("completed", false)
		var progress: int = ch.get("progress", 0)
		var target: int = ch.get("target_value", 0)
		var icon: String = "[x]" if done else "[ ]"
		var col: Color = Color(0.4, 0.9, 0.4) if done else Color(0.85, 0.85, 0.75)
		var name_str: String = ch.get("name", "Challenge %d" % i)
		_add_label("%s %s (%d/%d)" % [icon, name_str, progress, target], 8.0, y, col, 10)
		y += 18.0
		_add_label("   XP : %d | Or : %d" % [ch.get("xp_reward", 0), ch.get("gold_reward", 0)],
				12.0, y, Color(0.6, 0.6, 0.6), 9)
		y += 14.0

## ── Helpers ─────────────────────────────────────────────────────────────────

func _add_label(text: String, x: float, y: float, col: Color, size: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(_content_root.size.x - x - 4.0, float(size) + 4.0)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	_content_root.add_child(lbl)

## ── Show / Hide ──────────────────────────────────────────────────────────────

func show_panel(tab: int = 0) -> void:
	visible = true
	_switch_tab(tab)

func hide_panel() -> void:
	visible = false
