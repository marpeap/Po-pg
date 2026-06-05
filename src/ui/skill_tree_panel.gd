## SkillTreePanel — Interface tactile de l'arbre de compétences.
## Affiché sur demande depuis le HUD RPG (bouton dédié ou NPC Sage).
## 3 colonnes (Guerrier / Explorateur / Erudit), 5 rangées de compétences.
## Les passives secrètes (rangée 6) s'affichent quand débloquées.
##
## Inspiré du skill tree de Path of Exile (nœuds connectés visuellement)
## et Diablo 3 (boutons tactiles larges adaptés mobile).
extends CanvasLayer

const W := 960.0
const H := 540.0
const PANEL_W := 760.0
const PANEL_H := 460.0
const PANEL_X := (W - PANEL_W) * 0.5
const PANEL_Y := (H - PANEL_H) * 0.5

const COL_W := PANEL_W / 3.0

## Branch colors
const BRANCH_COLORS: Array[Color] = [
	Color(0.90, 0.30, 0.25),  ## Guerrier — rouge
	Color(0.30, 0.75, 0.35),  ## Explorateur — vert
	Color(0.35, 0.55, 1.00),  ## Erudit — bleu
]

const BRANCH_NAMES: Array[String] = ["GUERRIER", "EXPLORATEUR", "ERUDIT"]

## ── Nodes ─────────────────────────────────────────────────────────────────

var _bg: ColorRect = null
var _close_btn: Button = null
var _prestige_btn: Button = null
var _skill_buttons: Array[Control] = []
var _points_label: Label = null
var _skill_tree: Node = null  ## SkillTree autoload ref

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 20
	visible = false
	_skill_tree = get_node_or_null("/root/SkillTree")
	_build_ui()
	if _skill_tree != null:
		_skill_tree.skill_unlocked.connect(_on_skill_state_changed)
		_skill_tree.passive_unlocked.connect(_on_skill_state_changed)
		_skill_tree.skill_points_changed.connect(_on_skill_points_changed)

func _build_ui() -> void:
	## Dimmed full-screen overlay
	var dim := ColorRect.new()
	dim.size = Vector2(W, H)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	## Panel background
	_bg = ColorRect.new()
	_bg.size     = Vector2(PANEL_W, PANEL_H)
	_bg.position = Vector2(PANEL_X, PANEL_Y)
	_bg.color    = Color(0.10, 0.09, 0.07, 0.96)
	add_child(_bg)

	## Border
	for edge: Dictionary in [
		{r=Rect2(PANEL_X, PANEL_Y, PANEL_W, 2.0)},
		{r=Rect2(PANEL_X, PANEL_Y + PANEL_H - 2.0, PANEL_W, 2.0)},
		{r=Rect2(PANEL_X, PANEL_Y, 2.0, PANEL_H)},
		{r=Rect2(PANEL_X + PANEL_W - 2.0, PANEL_Y, 2.0, PANEL_H)},
	]:
		var b := ColorRect.new()
		b.position = edge.r.position
		b.size     = edge.r.size
		b.color    = Color(0.65, 0.58, 0.40)
		add_child(b)

	## Title
	var title_lbl := Label.new()
	title_lbl.text = "ARBRE DE COMPETENCES"
	title_lbl.position = Vector2(PANEL_X, PANEL_Y + 8.0)
	title_lbl.size     = Vector2(PANEL_W, 24.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
	add_child(title_lbl)

	## Points disponibles
	_points_label = Label.new()
	_points_label.position = Vector2(PANEL_X, PANEL_Y + 32.0)
	_points_label.size     = Vector2(PANEL_W, 18.0)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_size_override("font_size", 12)
	_points_label.add_theme_color_override("font_color", Color(0.85, 0.90, 0.50))
	add_child(_points_label)
	_refresh_points_label()

	## Branch headers
	for b: int in range(3):
		var header := ColorRect.new()
		header.position = Vector2(PANEL_X + b * COL_W, PANEL_Y + 52.0)
		header.size     = Vector2(COL_W, 22.0)
		header.color    = BRANCH_COLORS[b]
		header.color.a  = 0.30
		add_child(header)
		var hlbl := Label.new()
		hlbl.text = BRANCH_NAMES[b]
		hlbl.position = Vector2(PANEL_X + b * COL_W, PANEL_Y + 53.0)
		hlbl.size     = Vector2(COL_W, 20.0)
		hlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hlbl.add_theme_font_size_override("font_size", 11)
		hlbl.add_theme_color_override("font_color", BRANCH_COLORS[b])
		add_child(hlbl)

	## Skill buttons — 5 tiers × 3 branches
	const BTN_W  := 120.0
	const BTN_H  := 52.0
	const BTN_Y0 := 80.0
	const BTN_GAP := 56.0

	for branch: int in range(3):
		for tier: int in range(5):
			var skill_id: int = branch * 5 + tier
			var bx: float = PANEL_X + branch * COL_W + (COL_W - BTN_W) * 0.5
			var by: float = PANEL_Y + BTN_Y0 + tier * BTN_GAP

			## Connector line upward (to show chain)
			if tier > 0:
				var line := ColorRect.new()
				line.position = Vector2(bx + BTN_W * 0.5 - 1.0, by - BTN_GAP + BTN_H)
				line.size     = Vector2(2.0, BTN_GAP - BTN_H)
				line.color    = Color(0.55, 0.50, 0.38, 0.50)
				add_child(line)

			var btn := _make_skill_button(skill_id, bx, by, BTN_W, BTN_H, branch)
			_skill_buttons.append(btn)
			add_child(btn)

	## Passive secrets row (collapsed until unlocked)
	const PASS_Y0 := 380.0
	const PASS_BTN_W := 110.0
	var pass_positions: Array[float] = [
		PANEL_X + 60.0,
		PANEL_X + 200.0,
		PANEL_X + 340.0,
		PANEL_X + 480.0,
		PANEL_X + 610.0,
		PANEL_X + 730.0,
	]
	for pi: int in range(6):
		var sid: int = 15 + pi
		var pbtn := _make_skill_button(sid, pass_positions[pi], PANEL_Y + PASS_Y0, PASS_BTN_W, 46.0, -1)
		pbtn.modulate.a = 0.35  ## Dim until unlocked
		_skill_buttons.append(pbtn)
		add_child(pbtn)

	## "Passives Secrètes" section label
	var plbl := Label.new()
	plbl.text = "— Passives Secrètes —"
	plbl.position = Vector2(PANEL_X, PANEL_Y + 374.0)
	plbl.size     = Vector2(PANEL_W, 16.0)
	plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plbl.add_theme_font_size_override("font_size", 10)
	plbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.50, 0.70))
	add_child(plbl)

	## PRESTIGE button — visible only when PrestigeSystem.can_prestige() is true.
	_prestige_btn = Button.new()
	_prestige_btn.text = "PRESTIGE ★"
	_prestige_btn.position = Vector2(PANEL_X + 8.0, PANEL_Y + PANEL_H - 30.0)
	_prestige_btn.size     = Vector2(130.0, 26.0)
	_prestige_btn.add_theme_font_size_override("font_size", 12)
	var prestige_style := StyleBoxFlat.new()
	prestige_style.bg_color = Color(0.75, 0.55, 0.05)
	prestige_style.corner_radius_top_left    = 4
	prestige_style.corner_radius_top_right   = 4
	prestige_style.corner_radius_bottom_left = 4
	prestige_style.corner_radius_bottom_right = 4
	_prestige_btn.add_theme_stylebox_override("normal", prestige_style)
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	_prestige_btn.visible = false
	add_child(_prestige_btn)

	## Close button
	_close_btn = Button.new()
	_close_btn.text = "Fermer"
	_close_btn.position = Vector2(PANEL_X + PANEL_W - 80.0, PANEL_Y + PANEL_H - 30.0)
	_close_btn.size     = Vector2(76.0, 26.0)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(hide_panel)
	add_child(_close_btn)

func _make_skill_button(skill_id: int, bx: float, by: float, bw: float, bh: float, branch: int) -> Control:
	var c := Control.new()
	c.position = Vector2(bx, by)
	c.size     = Vector2(bw, bh)

	## Background
	var bg := ColorRect.new()
	bg.size  = Vector2(bw, bh)
	bg.color = Color(0.18, 0.16, 0.12)
	bg.name  = "Bg"
	c.add_child(bg)

	## Branch color border
	var border_color: Color = BRANCH_COLORS[branch] if branch >= 0 else Color(0.65, 0.60, 0.80)
	var border := ColorRect.new()
	border.size     = Vector2(bw, 2.0)
	border.position = Vector2(0.0, 0.0)
	border.color    = border_color
	border.name     = "Border"
	c.add_child(border)

	## Skill name label
	var name_lbl := Label.new()
	name_lbl.text = SkillTree.NAMES[skill_id] if skill_id < SkillTree.NAMES.size() else "?"
	name_lbl.size = Vector2(bw - 4.0, 20.0)
	name_lbl.position = Vector2(2.0, 2.0)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78))
	name_lbl.name = "NameLbl"
	c.add_child(name_lbl)

	## Description label
	var desc_lbl := Label.new()
	desc_lbl.text = SkillTree.DESCRIPTIONS[skill_id] if skill_id < SkillTree.DESCRIPTIONS.size() else ""
	desc_lbl.size = Vector2(bw - 4.0, 24.0)
	desc_lbl.position = Vector2(2.0, 18.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 8)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60))
	desc_lbl.name = "DescLbl"
	c.add_child(desc_lbl)

	## Cost label (bottom right)
	var cost: int = SkillTree.SKILL_COSTS[skill_id] if skill_id < SkillTree.SKILL_COSTS.size() else 0
	if cost > 0:
		var cost_lbl := Label.new()
		cost_lbl.text = "%d pt" % cost
		cost_lbl.size = Vector2(28.0, 14.0)
		cost_lbl.position = Vector2(bw - 30.0, bh - 16.0)
		cost_lbl.add_theme_font_size_override("font_size", 8)
		cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.45))
		cost_lbl.name = "CostLbl"
		c.add_child(cost_lbl)

	## Touch area
	var area := Area2D.new()
	area.position = Vector2.ZERO
	area.input_pickable = true
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bw - 2.0, bh - 2.0)
	col.position = Vector2(bw * 0.5 - 1.0, bh * 0.5 - 1.0)
	col.shape = shape
	area.add_child(col)
	c.add_child(area)
	area.input_event.connect(
		func(_vp: Viewport, event: InputEvent, _si: int) -> void:
			if event is InputEventScreenTouch and event.pressed:
				_on_skill_button_pressed(skill_id))

	## Store skill_id for refresh
	c.set_meta("skill_id", skill_id)
	_refresh_button_state(c)
	return c

## ── Button state refresh ─────────────────────────────────────────────────

func _refresh_all_buttons() -> void:
	for btn: Control in _skill_buttons:
		_refresh_button_state(btn)
	_refresh_points_label()
	_refresh_prestige_btn()

func _refresh_prestige_btn() -> void:
	if _prestige_btn == null:
		return
	var prestige: Node = get_node_or_null("/root/PrestigeSystem")
	_prestige_btn.visible = prestige != null and prestige.can_prestige()

func _refresh_button_state(btn: Control) -> void:
	if _skill_tree == null:
		return
	var sid: int = btn.get_meta("skill_id", -1)
	if sid < 0:
		return
	var unlocked: bool = _skill_tree.is_unlocked(sid)
	var can_unlock: bool = _skill_tree.can_unlock(sid) if sid < 15 else false

	var bg: ColorRect = btn.get_node_or_null("Bg")
	if bg == null:
		return
	if unlocked:
		bg.color = Color(0.12, 0.22, 0.12) if sid < 15 else Color(0.18, 0.14, 0.28)
		btn.modulate.a = 1.0
	elif can_unlock:
		bg.color = Color(0.20, 0.18, 0.12)
		btn.modulate.a = 1.0
	else:
		bg.color = Color(0.12, 0.12, 0.12)
		btn.modulate.a = 1.0 if (sid >= 15 and unlocked) else 0.55

	## Passive: dim until unlocked
	if sid >= 15:
		btn.modulate.a = 1.0 if unlocked else 0.35

	## Name color: gold if unlocked, white if available, gray if locked
	var name_lbl: Label = btn.get_node_or_null("NameLbl")
	if name_lbl != null:
		if unlocked:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		elif can_unlock:
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.48))

func _refresh_points_label() -> void:
	if _points_label == null or _skill_tree == null:
		return
	var pts: int = _skill_tree.skill_points
	_points_label.text = "Points disponibles : %d" % pts
	_points_label.add_theme_color_override("font_color",
		Color(0.85, 0.90, 0.50) if pts > 0 else Color(0.55, 0.55, 0.50))

## ── Interaction ──────────────────────────────────────────────────────────

func _on_skill_button_pressed(skill_id: int) -> void:
	if _skill_tree == null:
		return
	if _skill_tree.is_unlocked(skill_id):
		## Already unlocked — show info toast
		var rpg_hud: Node = get_tree().get_first_node_in_group("rpg_hud")
		if rpg_hud != null and rpg_hud.has_method("show_toast"):
			rpg_hud.show_toast(SkillTree.NAMES[skill_id], SkillTree.DESCRIPTIONS[skill_id], 0)
		return
	var success: bool = _skill_tree.unlock_skill(skill_id)
	if not success:
		## Show feedback: why it failed
		var rpg_hud: Node = get_tree().get_first_node_in_group("rpg_hud")
		if rpg_hud != null and rpg_hud.has_method("show_toast"):
			if _skill_tree.skill_points < SkillTree.SKILL_COSTS[skill_id]:
				rpg_hud.show_toast("Points insuffisants", "Montez de niveau pour en gagner", 0)
			else:
				rpg_hud.show_toast("Prerequis manquant", "Debloquez la competence precedente", 0)

func _on_skill_state_changed(_skill_id: int) -> void:
	_refresh_all_buttons()

func _on_skill_points_changed(_new_pts: int) -> void:
	_refresh_all_buttons()

func _on_prestige_pressed() -> void:
	var prestige: Node = get_node_or_null("/root/PrestigeSystem")
	if prestige == null or not prestige.can_prestige():
		return
	## Confirmation guard — double-tap required to avoid accidental prestige.
	if not _prestige_btn.has_meta("confirm_pending"):
		_prestige_btn.set_meta("confirm_pending", true)
		_prestige_btn.text = "Confirmer ?"
		## Auto-reset after 3 seconds if not confirmed.
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if _prestige_btn != null and _prestige_btn.has_meta("confirm_pending"):
				_prestige_btn.remove_meta("confirm_pending")
				_prestige_btn.text = "PRESTIGE ★")
	else:
		_prestige_btn.remove_meta("confirm_pending")
		prestige.do_prestige()
		_refresh_all_buttons()

## ── Show / Hide ──────────────────────────────────────────────────────────

func show_panel() -> void:
	visible = true
	_refresh_all_buttons()

func hide_panel() -> void:
	visible = false
