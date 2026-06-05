## RPGHudOverlay — Overlay HUD RPG sur CanvasLayer (layer = 5).
## Affiche en mode EXPLORING :
##   - Barre XP héros (niveau + progression)
##   - Phase jour/nuit (icône + nom)
##   - Streak des défis quotidiens
##   - Notifications de succès (toast animé)
##   - Notifications de level-up
##   - Prestige title
##   - Mini-carte de progression (zones complétées)
##
## S'auto-masque en mode PLAYING (tour de défense).
## Inspiré du HUD de Genshin Impact (minimal, informatif, non-intrusif).
extends CanvasLayer

## ── Constants ────────────────────────────────────────────────────────────

const W := 960.0
const H := 540.0
const XP_BAR_W := 260.0
const XP_BAR_H := 8.0
const XP_BAR_X := (W - XP_BAR_W) * 0.5
const XP_BAR_Y := H - 22.0

## Toast queue — multiple toasts show in sequence
const TOAST_DURATION   := 3.0
const TOAST_ANIM_SEC   := 0.40

## Phase icons (unicode) — fallback since no sprite
const PHASE_ICONS: Array[String] = ["☀", "☀", "☽", "🌅", "★"]

## Rarity toast colors (matches AchievementSystem.RARITY_COLORS)
const TOAST_COLORS: Array[Color] = [
	Color(0.80, 0.52, 0.25),  ## Bronze
	Color(0.75, 0.75, 0.80),  ## Argent
	Color(1.00, 0.85, 0.20),  ## Or
	Color(0.55, 0.88, 1.00),  ## Diamant
]

## ── Nodes ────────────────────────────────────────────────────────────────

var _xp_bar_bg: ColorRect       = null
var _xp_bar_fill: ColorRect     = null
var _xp_level_lbl: Label        = null
var _xp_pct_lbl: Label          = null
var _phase_lbl: Label           = null
var _streak_lbl: Label          = null
var _title_lbl: Label           = null
var _toast_panel: ColorRect     = null
var _toast_label: Label         = null
var _zone_bar: ColorRect        = null

## Daily challenge dots
var _challenge_dots: Array[ColorRect] = []

## Zone mastery dots
var _zone_dots: Array[ColorRect] = []

## Equipment display (weapon + armor, top-left below challenge dots)
var _equip_weapon_lbl: Label = null
var _equip_armor_lbl: Label  = null

## ── State ────────────────────────────────────────────────────────────────

var _toast_queue: Array[Dictionary] = []  ## {text, color, subtitle}
var _toast_showing: bool = false
var _toast_timer: float = 0.0
var _built: bool = false

var _day_night: Node = null
var _achievement: Node = null
var _daily: Node = null
var _prestige: Node = null

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 5
	visible = false  ## Hidden by default; shown only in EXPLORING state
	_build_ui()
	_connect_systems()
	GameStateMachine.game_state_changed.connect(_on_state_changed)

func _build_ui() -> void:
	if _built:
		return
	_built = true

	## ── XP Bar (bottom center) ──────────────────────────────────────────
	_xp_bar_bg = ColorRect.new()
	_xp_bar_bg.position = Vector2(XP_BAR_X - 1.0, XP_BAR_Y - 1.0)
	_xp_bar_bg.size     = Vector2(XP_BAR_W + 2.0, XP_BAR_H + 2.0)
	_xp_bar_bg.color    = Color(0.0, 0.0, 0.0, 0.60)
	add_child(_xp_bar_bg)

	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.position = Vector2(XP_BAR_X, XP_BAR_Y)
	_xp_bar_fill.size     = Vector2(0.0, XP_BAR_H)
	_xp_bar_fill.color    = Color(0.25, 0.75, 1.00)
	add_child(_xp_bar_fill)

	_xp_level_lbl = Label.new()
	_xp_level_lbl.position = Vector2(XP_BAR_X - 38.0, XP_BAR_Y - 6.0)
	_xp_level_lbl.size     = Vector2(36.0, 20.0)
	_xp_level_lbl.add_theme_font_size_override("font_size", 11)
	_xp_level_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	_xp_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_xp_level_lbl)

	_xp_pct_lbl = Label.new()
	_xp_pct_lbl.position = Vector2(XP_BAR_X + XP_BAR_W + 4.0, XP_BAR_Y - 6.0)
	_xp_pct_lbl.size     = Vector2(50.0, 20.0)
	_xp_pct_lbl.add_theme_font_size_override("font_size", 10)
	_xp_pct_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.85))
	add_child(_xp_pct_lbl)

	## ── Phase jour/nuit (top left, small) ──────────────────────────────
	_phase_lbl = Label.new()
	_phase_lbl.position = Vector2(6.0, 4.0)
	_phase_lbl.size     = Vector2(80.0, 18.0)
	_phase_lbl.add_theme_font_size_override("font_size", 11)
	_phase_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	add_child(_phase_lbl)

	## ── Streak (top left sous phase) ────────────────────────────────────
	_streak_lbl = Label.new()
	_streak_lbl.position = Vector2(6.0, 20.0)
	_streak_lbl.size     = Vector2(100.0, 16.0)
	_streak_lbl.add_theme_font_size_override("font_size", 10)
	_streak_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	add_child(_streak_lbl)

	## ── Daily challenge dots (3 small dots near streak) ─────────────────
	for i: int in range(3):
		var dot := ColorRect.new()
		dot.size     = Vector2(8.0, 8.0)
		dot.position = Vector2(6.0 + i * 11.0, 38.0)
		dot.color    = Color(0.35, 0.35, 0.35)
		add_child(dot)
		_challenge_dots.append(dot)

	## ── Prestige title (top center) ─────────────────────────────────────
	_title_lbl = Label.new()
	_title_lbl.position = Vector2(W * 0.5 - 100.0, 2.0)
	_title_lbl.size     = Vector2(200.0, 18.0)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	add_child(_title_lbl)

	## ── Zone progression bar (top right — 15 dots) ──────────────────────
	for i: int in range(15):
		var dot := ColorRect.new()
		dot.size     = Vector2(6.0, 6.0)
		dot.position = Vector2(W - 15 * 8.0 + i * 8.0, 6.0)
		dot.color    = Color(0.30, 0.30, 0.30, 0.70)
		add_child(dot)
		_zone_dots.append(dot)

	## ── Equipment labels (top-left, below challenge dots) ──────────────
	_equip_weapon_lbl = Label.new()
	_equip_weapon_lbl.position = Vector2(6.0, 50.0)
	_equip_weapon_lbl.size     = Vector2(160.0, 14.0)
	_equip_weapon_lbl.add_theme_font_size_override("font_size", 10)
	_equip_weapon_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 0.70))
	add_child(_equip_weapon_lbl)

	_equip_armor_lbl = Label.new()
	_equip_armor_lbl.position = Vector2(6.0, 64.0)
	_equip_armor_lbl.size     = Vector2(160.0, 14.0)
	_equip_armor_lbl.add_theme_font_size_override("font_size", 10)
	_equip_armor_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
	add_child(_equip_armor_lbl)

	refresh_equipment()

	## ── Toast panel (center screen, hidden) ─────────────────────────────
	_toast_panel = ColorRect.new()
	_toast_panel.size     = Vector2(340.0, 54.0)
	_toast_panel.position = Vector2((W - 340.0) * 0.5, 80.0)
	_toast_panel.color    = Color(0.12, 0.10, 0.08, 0.92)
	_toast_panel.modulate.a = 0.0
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.size     = Vector2(330.0, 50.0)
	_toast_label.position = Vector2(5.0, 2.0)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_toast_panel.add_child(_toast_label)

	_refresh_xp_bar()

## ── Connect external systems ─────────────────────────────────────────────

func _connect_systems() -> void:
	if HeroProgression != null:
		HeroProgression.xp_gained.connect(_on_xp_gained)
		HeroProgression.level_up.connect(_on_level_up)

	## Lazy-find optional systems (autoloads may not all be registered)
	_day_night   = get_node_or_null("/root/DayNightCycle")
	_achievement  = get_node_or_null("/root/AchievementSystem")
	_daily        = get_node_or_null("/root/DailyChallenge")
	_prestige     = get_node_or_null("/root/PrestigeSystem")

	if _achievement != null:
		_achievement.achievement_unlocked.connect(_on_achievement_unlocked)

	if _daily != null:
		_daily.challenge_completed.connect(_on_challenge_completed)
		_daily.all_challenges_completed.connect(_on_all_challenges_completed)
		_daily.streak_updated.connect(_on_streak_updated)
		_refresh_streak()
		_refresh_challenge_dots()

	if _prestige != null:
		_prestige.prestige_gained.connect(_on_prestige_gained)
		_refresh_title()

## ── Process ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	## Update phase display
	if _day_night != null and _phase_lbl != null:
		var pname: String = _day_night.get_phase_name()
		_phase_lbl.text = pname

	## Update zone dots from HeroProgression
	_refresh_zone_dots()

	## Toast queue processing
	if _toast_showing:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_hide_toast()
	elif not _toast_queue.is_empty():
		_show_next_toast()

## ── XP Bar refresh ───────────────────────────────────────────────────────

func _refresh_xp_bar() -> void:
	if HeroProgression == null or _xp_bar_fill == null:
		return
	var progress: float = HeroProgression.level_progress()
	_xp_bar_fill.size.x = XP_BAR_W * progress
	_xp_level_lbl.text = "Niv.%d" % HeroProgression.hero_level
	var pct: int = int(progress * 100.0)
	_xp_pct_lbl.text = "%d%%" % pct

	## Color shifts as level increases (blue → purple → gold)
	var lv: int = HeroProgression.hero_level
	if lv < 20:
		_xp_bar_fill.color = Color(0.25, 0.75, 1.00)
	elif lv < 40:
		_xp_bar_fill.color = Color(0.65, 0.35, 1.00)
	else:
		_xp_bar_fill.color = Color(1.00, 0.80, 0.20)

func _on_xp_gained(_amount: int, _total: int) -> void:
	_refresh_xp_bar()

func _on_level_up(new_level: int) -> void:
	_refresh_xp_bar()
	queue_toast({
		"text": "NIVEAU %d !" % new_level,
		"subtitle": "+1 point de competence",
		"color": Color(0.25, 0.85, 1.00),
		"rarity": 2,
	})

## ── Zone dots ─────────────────────────────────────────────────────────────

func _refresh_zone_dots() -> void:
	if HeroProgression == null:
		return
	for i: int in range(mini(15, _zone_dots.size())):
		var mastery: int = HeroProgression.get_zone_mastery(i)
		match mastery:
			0: _zone_dots[i].color = Color(0.28, 0.28, 0.28, 0.70)
			1: _zone_dots[i].color = Color(0.80, 0.52, 0.25, 0.85)
			2: _zone_dots[i].color = Color(0.75, 0.75, 0.80, 0.85)
			3: _zone_dots[i].color = Color(1.00, 0.85, 0.20, 0.90)
			4: _zone_dots[i].color = Color(0.40, 0.80, 1.00, 0.95)
			_: _zone_dots[i].color = Color(0.90, 0.35, 1.00, 1.00)

## ── Streak & Challenges ──────────────────────────────────────────────────

func _refresh_streak() -> void:
	if _daily == null or _streak_lbl == null:
		return
	var s: int = _daily.get_streak()
	if s > 0:
		var bonus: int = _daily.get_streak_bonus_pct()
		_streak_lbl.text = "Série : %d jour(s) (+%d%% XP)" % [s, bonus]
	else:
		_streak_lbl.text = "Défis du jour"

func _refresh_challenge_dots() -> void:
	if _daily == null:
		return
	var challenges: Array[Dictionary] = _daily.get_challenges()
	for i: int in range(mini(3, challenges.size())):
		var c: Dictionary = challenges[i]
		if c.completed:
			_challenge_dots[i].color = Color(0.25, 0.90, 0.30)  ## Vert = fait
		elif c.progress > 0:
			_challenge_dots[i].color = Color(1.00, 0.80, 0.10)  ## Jaune = en cours
		else:
			_challenge_dots[i].color = Color(0.40, 0.40, 0.40)  ## Gris = non commencé

func _on_challenge_completed(idx: int) -> void:
	_refresh_challenge_dots()
	var challenges: Array[Dictionary] = _daily.get_challenges() if _daily != null else []
	if idx < challenges.size():
		var c: Dictionary = challenges[idx]
		queue_toast({
			"text": "Defi : " + c.name,
			"subtitle": "+%d or, +%d XP" % [c.gold_reward, c.xp_reward],
			"color": Color(1.00, 0.85, 0.20),
			"rarity": 1,
		})

func _on_all_challenges_completed(bonus_xp: int) -> void:
	_refresh_streak()
	queue_toast({
		"text": "TOUS LES DEFIS COMPLETES !",
		"subtitle": "Bonus : +%d XP" % bonus_xp,
		"color": Color(1.00, 0.65, 0.10),
		"rarity": 3,
	})

func _on_streak_updated(new_streak: int) -> void:
	_refresh_streak()

## ── Prestige title ────────────────────────────────────────────────────────

func _refresh_title() -> void:
	if _prestige == null or _title_lbl == null:
		return
	var title: String = _prestige.get_display_string()
	_title_lbl.text = title
	if title != "":
		_title_lbl.add_theme_color_override("font_color", _prestige.get_title_color())

func _on_prestige_gained(new_level: int, title_str: String) -> void:
	_refresh_title()
	queue_toast({
		"text": "PRESTIGE %d — %s" % [new_level, title_str],
		"subtitle": "Bonification permanente debloquee !",
		"color": Color(1.00, 0.75, 0.15),
		"rarity": 3,
	})

## ── Achievement toast ─────────────────────────────────────────────────────

func _on_achievement_unlocked(ach_id: int) -> void:
	var name_str: String = AchievementSystem.NAMES[ach_id] if ach_id < AchievementSystem.NAMES.size() else "Succes"
	var rarity: int = AchievementSystem.RARITY[ach_id] if ach_id < AchievementSystem.RARITY.size() else 0
	var xp: int     = AchievementSystem.XP_REWARDS[ach_id] if ach_id < AchievementSystem.XP_REWARDS.size() else 0
	queue_toast({
		"text": "SUCCES : " + name_str,
		"subtitle": "+%d XP" % xp,
		"color": AchievementSystem.RARITY_COLORS[rarity],
		"rarity": rarity,
	})

## ── Toast system ──────────────────────────────────────────────────────────

func queue_toast(data: Dictionary) -> void:
	_toast_queue.append(data)

func _show_next_toast() -> void:
	if _toast_queue.is_empty() or _toast_panel == null:
		return
	var data: Dictionary = _toast_queue.pop_front()
	_toast_showing = true
	_toast_timer = TOAST_DURATION

	var rarity_idx: int = data.get("rarity", 0)
	var bg_color: Color = data.get("color", Color.WHITE)
	bg_color.a = 0.18
	_toast_panel.color = Color(0.10, 0.08, 0.06, 0.92)

	## Left accent bar
	var accent_color: Color = data.get("color", Color.WHITE)
	var accent := _toast_panel.get_node_or_null("Accent")
	if accent == null:
		accent = ColorRect.new()
		accent.name = "Accent"
		accent.size = Vector2(4.0, 54.0)
		accent.position = Vector2(0.0, 0.0)
		_toast_panel.add_child(accent)
	accent.color = accent_color

	var main_text: String = data.get("text", "")
	var sub_text:  String = data.get("subtitle", "")
	_toast_label.text = main_text if sub_text.is_empty() else "%s\n%s" % [main_text, sub_text]
	_toast_label.position.x = 8.0

	## Animate in
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(_toast_panel, "modulate:a", 1.0, TOAST_ANIM_SEC)

func _hide_toast() -> void:
	_toast_showing = false
	if _toast_panel == null:
		return
	var tw := create_tween()
	tw.tween_property(_toast_panel, "modulate:a", 0.0, TOAST_ANIM_SEC * 0.5)

## ── State visibility ─────────────────────────────────────────────────────

func _on_state_changed(new_state: int) -> void:
	## 0=PLAYING 1=GAME_OVER 2=RESETTING 3=EXPLORING
	visible = (new_state == 3)

## ── Public API ───────────────────────────────────────────────────────────

## Called from HeroProgression after zone clear to refresh dots.
func refresh_zone_mastery() -> void:
	_refresh_zone_dots()

## Called from Main when day_night system is assigned.
func set_day_night_system(dn_node: Node) -> void:
	_day_night = dn_node

## Called from Main to forward achievement system reference.
func set_achievement_system(ach_node: Node) -> void:
	_achievement = ach_node
	if _achievement != null and not _achievement.achievement_unlocked.is_connected(_on_achievement_unlocked):
		_achievement.achievement_unlocked.connect(_on_achievement_unlocked)

## Refresh the weapon/armor display from ItemInventory.
## Called by Main._on_item_crafted() when hero equips a new item.
func refresh_equipment() -> void:
	if _equip_weapon_lbl == null or _equip_armor_lbl == null:
		return
	var w_id: int = ItemInventory.hero_weapon
	var a_id: int = ItemInventory.hero_armor
	_equip_weapon_lbl.text = "Arme: %s" % (ItemInventory.NAMES[w_id] if w_id >= 0 else "Aucune")
	_equip_armor_lbl.text  = "Armure: %s" % (ItemInventory.NAMES[a_id] if a_id >= 0 else "Aucune")

## Shortcut: show a custom toast from any system.
func show_toast(text: String, subtitle: String = "", rarity: int = 0) -> void:
	queue_toast({
		"text": text,
		"subtitle": subtitle,
		"color": TOAST_COLORS[clampi(rarity, 0, 3)] if rarity < TOAST_COLORS.size() else Color.WHITE,
		"rarity": rarity,
	})
