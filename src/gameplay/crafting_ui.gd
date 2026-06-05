## CraftingUI — modal crafting panel displayed over the exploration world.
## Opened by CraftingAnvil when the player taps a forge.
## Built on a CanvasLayer so it renders above all world geometry.
## Layout: dark backdrop → title → category tabs → scrollable recipe list.
## ADR-007: Tween-only animations, no AnimationPlayer.
extends CanvasLayer

const PANEL_W := 700.0
const PANEL_H := 420.0
const PANEL_X := 130.0   ## Left edge of panel in viewport space
const PANEL_Y :=  60.0   ## Top edge

## Emitted when the player closes the panel.
signal closed

var _crafting_system: Node = null   ## CraftingSystem instance
var _panel:           ColorRect = null
var _title_lbl:       Label = null
var _category_btns:   Array[Button] = []
var _scroll:          ScrollContainer = null
var _recipe_list:     VBoxContainer = null
var _active_category: int = 0
var _close_btn:       Button = null

## Initialise with a CraftingSystem instance (injected by CraftingAnvil).
func init(crafting_system: Node) -> void:
	_crafting_system = crafting_system
	layer = 5   ## Above HUD (layer 1) and spell VFX
	_build_ui()
	_refresh_list()
	## Slide in from right
	_panel.position.x = 960.0
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", PANEL_X, 0.20)

## --- Build ---

func _build_ui() -> void:
	## Dark backdrop (full screen, dims the world)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(960.0, 540.0)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.gui_input.connect(func(_e: InputEvent) -> void: pass)  ## absorb clicks

	## Main panel
	_panel = ColorRect.new()
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_panel.color = Color(0.12, 0.10, 0.08)
	add_child(_panel)

	## Panel border
	var border := ColorRect.new()
	border.size = Vector2(PANEL_W, PANEL_H)
	border.position = Vector2(-2.0, -2.0)
	border.color = Color(0.55, 0.42, 0.18)
	border.z_index = -1
	_panel.add_child(border)

	## Title
	_title_lbl = Label.new()
	_title_lbl.text = "FORGE — Atelier de crafting"
	_title_lbl.position = Vector2(12.0, 10.0)
	_title_lbl.size = Vector2(600.0, 28.0)
	_title_lbl.add_theme_font_size_override("font_size", 16)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	_panel.add_child(_title_lbl)

	## Close button
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.position = Vector2(PANEL_W - 38.0, 8.0)
	_close_btn.size = Vector2(30.0, 26.0)
	_close_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_panel.add_child(_close_btn)
	_close_btn.pressed.connect(_on_close)

	## Resource strip (shows current inventory)
	var res_strip := Label.new()
	res_strip.name = "ResourceStrip"
	res_strip.position = Vector2(12.0, 38.0)
	res_strip.size = Vector2(PANEL_W - 24.0, 18.0)
	res_strip.add_theme_font_size_override("font_size", 10)
	res_strip.add_theme_color_override("font_color", Color(0.75, 0.90, 0.65))
	_panel.add_child(res_strip)
	_refresh_resource_strip()
	## Live updates when resources change
	ResourceInventory.resource_changed.connect(func(_t: int, _c: int) -> void: _refresh_resource_strip())

	## Category tabs
	const CAT_NAMES := ["Armes", "Armure", "Archers", "Tours", "Château", "Consom."]
	const CAT_W := 95.0
	for i: int in range(6):
		var btn := Button.new()
		btn.text = CAT_NAMES[i]
		btn.position = Vector2(12.0 + i * (CAT_W + 4.0), 60.0)
		btn.size = Vector2(CAT_W, 26.0)
		btn.add_theme_font_size_override("font_size", 11)
		var cat_idx := i
		btn.pressed.connect(func() -> void: _select_category(cat_idx))
		_panel.add_child(btn)
		_category_btns.append(btn)

	## Scroll container for recipe list
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(10.0, 92.0)
	_scroll.size = Vector2(PANEL_W - 20.0, PANEL_H - 102.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_recipe_list)

	_update_tab_colors()

## --- Logic ---

func _select_category(cat: int) -> void:
	_active_category = cat
	_update_tab_colors()
	_refresh_list()

func _update_tab_colors() -> void:
	for i: int in range(_category_btns.size()):
		var btn: Button = _category_btns[i]
		if i == _active_category:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
		else:
			btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

func _refresh_list() -> void:
	## Clear existing rows
	for child in _recipe_list.get_children():
		child.queue_free()
	## Rebuild for active category
	var indices: Array[int] = _crafting_system.get_by_category(_active_category)
	if indices.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucune recette disponible."
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_recipe_list.add_child(empty_lbl)
		return
	for idx: int in indices:
		_recipe_list.add_child(_make_recipe_row(idx))

## Build one recipe row: name + ingredient list + Craft button.
func _make_recipe_row(recipe_idx: int) -> Control:
	var recipe: Dictionary = _crafting_system.RECIPES[recipe_idx]
	var craftable: bool = _crafting_system.can_craft(recipe_idx)

	var row := ColorRect.new()
	row.custom_minimum_size = Vector2(PANEL_W - 24.0, 54.0)
	row.color = Color(0.18, 0.15, 0.12) if craftable else Color(0.10, 0.10, 0.10)

	## Separator line on top
	var sep := ColorRect.new()
	sep.size = Vector2(PANEL_W - 24.0, 1.0)
	sep.color = Color(0.30, 0.25, 0.15)
	row.add_child(sep)

	## Recipe name
	var name_lbl := Label.new()
	name_lbl.text = recipe["name"]
	name_lbl.position = Vector2(8.0, 4.0)
	name_lbl.size = Vector2(320.0, 18.0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.95, 0.60) if craftable else Color(0.50, 0.50, 0.50))
	row.add_child(name_lbl)

	## Description
	var desc_lbl := Label.new()
	desc_lbl.text = recipe["description"]
	desc_lbl.position = Vector2(8.0, 22.0)
	desc_lbl.size = Vector2(400.0, 14.0)
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	row.add_child(desc_lbl)

	## Ingredient list
	var ing_parts: Array[String] = []
	for ing: Array in recipe["ingredients"]:
		var res_type: int = ing[0]
		var need: int     = ing[1]
		var have: int     = ResourceInventory.get_count(res_type)
		var short: String = ResourceInventory.SHORT_NAMES[res_type]
		ing_parts.append("%s %d/%d" % [short, have, need])
	var ing_lbl := Label.new()
	ing_lbl.text = "  ".join(ing_parts)
	ing_lbl.position = Vector2(8.0, 36.0)
	ing_lbl.size = Vector2(440.0, 14.0)
	ing_lbl.add_theme_font_size_override("font_size", 10)
	ing_lbl.add_theme_color_override("font_color",
		Color(0.60, 0.88, 0.55) if craftable else Color(0.55, 0.35, 0.35))
	row.add_child(ing_lbl)

	## Craft button
	var craft_btn := Button.new()
	craft_btn.text = "Forger" if craftable else "Manque"
	craft_btn.disabled = not craftable
	craft_btn.position = Vector2(PANEL_W - 105.0, 10.0)
	craft_btn.size = Vector2(88.0, 34.0)
	craft_btn.add_theme_font_size_override("font_size", 12)
	if craftable:
		craft_btn.add_theme_color_override("font_color", Color(0.20, 0.85, 0.40))
		var ridx := recipe_idx
		craft_btn.pressed.connect(func() -> void: _on_craft(ridx))
	row.add_child(craft_btn)

	return row

func _on_craft(recipe_idx: int) -> void:
	if not _crafting_system.craft(recipe_idx):
		return
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	## Refresh the list so ingredient counts and button states update
	_refresh_list()
	_refresh_resource_strip()

func _refresh_resource_strip() -> void:
	var strip: Label = _panel.get_node_or_null("ResourceStrip")
	if strip == null:
		return
	var parts: Array[String] = []
	for pair: Array in ResourceInventory.get_nonempty():
		var t: int = pair[0]
		var c: int = pair[1]
		parts.append("%s:%d" % [ResourceInventory.SHORT_NAMES[t], c])
	strip.text = "  ".join(parts) if not parts.is_empty() else "Inventaire vide"

func _on_close() -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", 960.0, 0.15)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free()
	)
