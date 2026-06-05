## HUD — landscape in-game overlay (viewport 960×540)
## ADR-007: CanvasLayer, Tween only, no AnimationPlayer
## GDD Req: TR-hud-001
## Landscape refactor: top bar + bottom-right action buttons (Sprint 7)
##
## Layout:
##   TOP BAR  (960×60): [❤ HP_bar HP_val]  [Vague N]  [Archers 2/8]  [123g]
##   BOTTOM-RIGHT: 5 action buttons — ARCHER / TOUR / CIBLE / FORM / FORGE
##   FORGE sub-panel: DMG / VIT / MAG / PV (shown when FORGE toggled)
extends Node2D

## Button press signals — Main wires these to Economy / ArcherFormation
signal recruit_pressed
signal tower_pressed
signal target_pressed
signal formation_pressed
signal forge_dmg_pressed
signal forge_spd_pressed
signal forge_mag_pressed
signal forge_hp_pressed
## Tower power selection signals — Main wires to tower.set_power() after spending gold
signal power_fire_pressed(tower: Node)
signal power_lightning_pressed(tower: Node)
signal power_water_pressed(tower: Node)
signal power_panel_cancelled
## Tower tier upgrade — Main deducts gold and calls tower.upgrade_to_tier(new_tier)
signal tier_upgrade_pressed(tower: Node, new_tier: int)
## Spell buttons — emitted with the spell index (0=Embrasement, 1=Foudre, 2=Glace)
signal spell_pressed(spell_index: int)
## Emitted when the player taps the Start Wave button between waves
signal start_wave_pressed
## Emitted when the context-sensitive interact button is tapped (proximity action)
signal interact_pressed
## Emitted when the MONTER/DESCENDRE button is tapped in EXPLORING mode
signal mount_pressed
## Emitted when the player taps the spell upgrade button (EXPLORING mode only)
signal spell_upgrades_requested

const CASTLE_MAX_HP    := 200
const ARCHER_COST      := 30
const MAX_FORMATION    := 8
const TOWER_COST       := 100
const FORGE_COST       := 200

## Top-bar node references — set by Main via setup()
var gold_label: Label
var castle_bar: ProgressBar
var castle_hp_label: Label
var wave_label: Label
var archer_badge: Label
var hud_strip: ColorRect

## Action button references — for state refresh
var _btn_recruit: Button
var _btn_tower: Button
var _btn_target: Button
var _btn_form: Button
var _btn_forge: Button
var _forge_panel: Control
var _btn_forge_dmg: Button
var _btn_forge_spd: Button
var _btn_forge_mag: Button
var _btn_forge_hp: Button

var _current_gold: int = 0
var _archer_count: int = 2
var _wave_active: bool = false
var _countdown: float = 0.0
var _forge_open: bool = false
var _power_panel: Control = null
var _power_target_tower: Node = null
var _tier_upgrade_btn: Button = null
## Spell button references and their cooldown overlay labels
var _btn_spells: Array[Button] = []
var _spell_cd_labels: Array[Label] = []
## Set by Main after hero_spells is created — used to poll cooldown state
var _hero_spells: Node = null
## Start Wave button — shown between waves, hidden while a wave is running
var _btn_start_wave: Button = null
var _start_wave_tween: Tween = null
## Preview label — shows next wave composition under the Start Wave button
var _wave_preview_lbl: Label = null

## --- P1: Pause / Speed ---
var _btn_pause: Button = null
var _btn_speed: Button = null
var _paused: bool = false
var _speed_2x: bool = false
var _pause_overlay: ColorRect = null

## --- P1: Mode labels ---
var _mode_label: Label = null   ## Shows "NEAREST | V-Form."

## --- P2: Streak / enemy count ---
var _streak_label: Label = null
var _enemy_count_label: Label = null
var _wave_total_count: int = 0

## --- P2: Announce overlay (boss/elite/rush) ---
var _announce_label: Label = null
var _announce_tween: Tween = null

## --- P2: Forge levels ---
var _forge_levels: Array[int] = [0, 0, 0, 0]  ## [dmg, spd, mag, hp]

## Forge node reference — injected by Main so forge buttons can display effective stats.
var _forge_ref: Node = null

## --- Castle max HP (for bar scaling) ---
var _castle_max_hp: int = 200

## --- P1: Mode tracking (for mode label refresh) ---
var _current_target_mode: int = 0
var _current_formation_mode: int = 0

## TD-mode exclusive nodes — hidden while EXPLORING, restored on PLAYING
var _td_elements: Array[Node] = []

## RPG proximity interact button — bottom-center, shown when hero is near an interactable
var _btn_interact: Button = null
## RPG mount button — bottom-left, shown only while EXPLORING (if Mount system active)
var _btn_mount: Button = null
## Spell upgrade button — shown only while EXPLORING, opens the upgrade tree panel
var _btn_spell_upgrades: Button = null

## RPG mode strip and inventory elements — visible only while EXPLORING
var _rpg_strip: ColorRect = null
var _rpg_hp_bar: ProgressBar = null
var _rpg_hp_lbl: Label = null
var _rpg_level_lbl: Label = null
var _rpg_camps_lbl: Label = null
var _btn_inventory: Button = null
var _inventory_panel: Control = null
var _inv_content_node: Control = null
var _inventory_visible: bool = false

## Mini-map — visible only while EXPLORING, shows hero position in world space.
## World space: 9600×3240 (5 zone cols × 3 zone rows); minimap display: 145×54 px.
var _minimap_bg: ColorRect = null
var _minimap_hero_dot: ColorRect = null
const MINIMAP_X := 812.0
const MINIMAP_Y := 6.0
const MINIMAP_W := 145.0
const MINIMAP_H := 54.0
const MINIMAP_WORLD_W := 9600.0
const MINIMAP_WORLD_H := 3240.0
const MINIMAP_ZONE_COLS := 5
const MINIMAP_ZONE_ROWS := 3
const MM_TILE_W := 26.0
const MM_TILE_H := 15.0
const MM_TILE_PAD := 1.0

## Zone background colors — mirrors exploration_map.gd ZONE_DEFS col values for minimap display.
const MINIMAP_ZONE_COLORS: Array[Color] = [
	Color(0.12, 0.34, 0.12),  ## 0  Foret Eveil
	Color(0.38, 0.34, 0.20),  ## 1  Clairiere
	Color(0.30, 0.26, 0.18),  ## 2  Ruines
	Color(0.18, 0.15, 0.22),  ## 3  Catacombes
	Color(0.14, 0.22, 0.12),  ## 4  Marecage
	Color(0.10, 0.20, 0.28),  ## 5  Foret Cristal
	Color(0.20, 0.18, 0.16),  ## 6  Cendres
	Color(0.30, 0.12, 0.05),  ## 7  Vallee Feu
	Color(0.72, 0.82, 0.88),  ## 8  Toundra
	Color(0.48, 0.42, 0.28),  ## 9  Desert
	Color(0.30, 0.26, 0.38),  ## 10 Temple
	Color(0.14, 0.12, 0.18),  ## 11 Grottes
	Color(0.55, 0.60, 0.75),  ## 12 Pics Etheres
	Color(0.12, 0.10, 0.16),  ## 13 Necropole
	Color(0.62, 0.65, 0.80),  ## 14 Cime Sacree
]

## NPC popup panel (lazy-built on first call).
var _npc_panel: Control = null
var _npc_title_lbl: Label = null
var _npc_desc_lbl: Label = null
var _npc_current: Node = null

## Contracts panel (lazy-built on first call).
var _contracts_panel: Control = null
var _contracts_content: Control = null

## Called by Main to wire top-bar node references after scene tree is ready.
func setup(
		p_gold_label: Label,
		p_castle_bar: ProgressBar,
		p_castle_hp_label: Label,
		p_wave_label: Label,
		p_archer_badge: Label,
		p_hud_strip: ColorRect) -> void:
	## Register in "hud" group so ExplorationMap can reach us via call_group().
	add_to_group("hud")
	gold_label = p_gold_label
	castle_bar = p_castle_bar
	castle_hp_label = p_castle_hp_label
	wave_label = p_wave_label
	archer_badge = p_archer_badge
	hud_strip = p_hud_strip

	castle_bar.min_value = 0
	castle_bar.max_value = CASTLE_MAX_HP
	_castle_max_hp = CASTLE_MAX_HP

	# Safe area inset for Android notch (ADR-007)
	var safe_rect := DisplayServer.get_display_safe_area()
	if hud_strip != null:
		hud_strip.position.y = safe_rect.position.y

	GameStateMachine.game_state_changed.connect(_on_game_state_changed)

## Called by Economy when gold changes — updates gold label and all button states.
func _on_gold_changed(new_gold: int) -> void:
	_current_gold = new_gold
	gold_label.text = str(new_gold) + "g"
	_refresh_button_states()

## Called by Castle when HP changes.
func _on_hp_changed(new_hp: int) -> void:
	castle_bar.value = new_hp
	castle_hp_label.text = str(new_hp)
	var ratio: float = float(new_hp) / float(max(_castle_max_hp, 1))
	if ratio >= 0.6:
		castle_bar.modulate = Color("#4CAF50")
	elif ratio >= 0.3:
		castle_bar.modulate = Color("#FFC107")
	else:
		castle_bar.modulate = Color("#F44336")

## Called by Castle when max HP increases (Forge HP upgrade or Stone resource bonus).
func _on_castle_max_hp_changed(new_max: int) -> void:
	_castle_max_hp = new_max
	castle_bar.max_value = new_max

## Called by EnemyWave when a new wave starts.
func _on_wave_started(wave_number: int) -> void:
	_wave_active = true
	_countdown = 0.0
	wave_label.text = "Vague %d" % wave_number
	wave_label.modulate = Color.WHITE
	# Boss/Elite/Rush wave announcement
	if wave_number % 5 == 0:
		_show_wave_announce("BOSS WAVE !", Color("#E74C3C"))
	elif wave_number % 3 == 0:
		_show_wave_announce("VAGUE ELITE", Color("#F39C12"))

## Called by EnemyWave.wave_enemy_count signal — stores total for count display.
func _on_wave_enemy_count(count: int) -> void:
	_wave_total_count = count
	if _enemy_count_label != null:
		_enemy_count_label.text = "%d restants" % count

## Called by EnemyWave.enemies_remaining signal — updates count label each kill.
func _on_enemies_remaining(count: int) -> void:
	if _enemy_count_label == null:
		return
	if count <= 0:
		_enemy_count_label.text = ""
	else:
		_enemy_count_label.text = "%d restants" % count

## Called by EnemyWave when all enemies in a wave die.
func _on_wave_cleared() -> void:
	_wave_active = false
	_countdown = 0.0
	wave_label.text = "Vague terminée"
	wave_label.modulate = Color("#F5C518")

## Called when a recruit purchase succeeds.
func _on_recruit_purchased() -> void:
	_archer_count += 1
	archer_badge.text = "%d/8" % _archer_count
	_refresh_button_states()

## Called when ArcherFormation formation_full fires.
func _on_formation_full() -> void:
	archer_badge.modulate = Color("#F5C518")

func _process(_delta: float) -> void:
	if _hero_spells != null and _btn_spells.size() == 3:
		_refresh_spell_cooldowns()
	## Update mini-map hero dot position each frame while exploring.
	if _minimap_hero_dot != null and _minimap_hero_dot.visible:
		var players: Array = get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			var hero_pos: Vector2 = (players[0] as Node2D).global_position
			var tile_total_w: float = (MM_TILE_W + MM_TILE_PAD) * float(MINIMAP_ZONE_COLS)
			var tile_total_h: float = (MM_TILE_H + MM_TILE_PAD) * float(MINIMAP_ZONE_ROWS)
			var mx: float = MINIMAP_X + clampf(hero_pos.x / MINIMAP_WORLD_W, 0.0, 1.0) * tile_total_w - 2.0
			var my: float = MINIMAP_Y + clampf(hero_pos.y / MINIMAP_WORLD_H, 0.0, 1.0) * tile_total_h - 2.0
			_minimap_hero_dot.position = Vector2(mx, my)

## Multi-touch spell activation — lets the right thumb cast while the left holds the joystick.
##
## Problem: Godot's Button.pressed fires only on the PRIMARY touch (converted to mouse events
## via emulation). A second finger generates raw InputEventScreenTouch but no mouse event,
## so Button.pressed is never called.
##
## Fix: intercept every InputEventScreenTouch.pressed here. If it lands on a spell button rect
## (viewport-space), emit spell_pressed directly. hero_spells.cast() has an is_ready() guard
## so even if Button.pressed also fires on a primary touch, the spell only casts once.
func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed:
		return
	var s := GameStateMachine.current_state
	if s != GameStateMachine.State.PLAYING and s != GameStateMachine.State.EXPLORING:
		return
	for i: int in range(_btn_spells.size()):
		var btn: Button = _btn_spells[i]
		if not is_instance_valid(btn) or not btn.visible or btn.disabled:
			continue
		## get_global_rect() on a CanvasLayer Control returns viewport-space coordinates,
		## matching the viewport-space position in InputEventScreenTouch.position.
		if btn.get_global_rect().has_point(event.position):
			spell_pressed.emit(i)
			return

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameStateMachine.State.PLAYING:
		visible = true
		_set_exploring_mode(false)  ## restore all TD elements; RPG strip hidden
		wave_label.text = "Vague 1"
		wave_label.modulate = Color.WHITE
		_wave_active = false
		_countdown = 0.0
		archer_badge.modulate = Color.WHITE
		_archer_count = 2
		archer_badge.text = "2/8"
		_forge_open = false
		if _forge_panel != null:
			_forge_panel.visible = false  ## override: forge panel stays closed
		if _btn_forge != null:
			_btn_forge.text = "Forge\n[+]"
		# Re-enable all spell buttons on reset (cooldowns cleared by hero_spells)
		for btn: Button in _btn_spells:
			btn.disabled = false
		for lbl: Label in _spell_cd_labels:
			lbl.text = ""
		# Hide the start wave button if it was shown from the previous session
		hide_start_wave_btn()  ## override: start wave hidden until wave_start_ready fires
		# Reset pause
		if _paused:
			_paused = false
			get_tree().paused = false
		if _btn_pause != null:
			_btn_pause.text = "||"
		# Reset speed
		if _speed_2x:
			_speed_2x = false
			Engine.time_scale = 1.0
		if _btn_speed != null:
			_btn_speed.text = "1x"
		# Reset mode label
		_current_target_mode = 0
		_current_formation_mode = 0
		_refresh_mode_label()
		# Reset streak and enemy count labels
		if _streak_label != null:
			_streak_label.text = ""
		if _enemy_count_label != null:
			_enemy_count_label.text = ""
		# Reset forge level counters and refresh labels with base stats
		_forge_levels = [0, 0, 0, 0]
		_refresh_forge_labels()   ## shows "→8 dmg", "→1.20s", etc. at base values
		_refresh_button_states()
	elif new_state == GameStateMachine.State.EXPLORING:
		visible = false  ## hide TD top bar (castle HP, wave, archers, gold)
		hide_power_panel()
		_set_exploring_mode(true)  ## show RPG strip, hide TD buttons
		if _rpg_camps_lbl != null:
			_rpg_camps_lbl.text = "Camps: 0/3"
			_rpg_camps_lbl.modulate = Color.WHITE
	else:
		visible = false
		_set_exploring_mode(false)

## Refresh enabled/disabled state and labels of all action buttons.
func _refresh_button_states() -> void:
	if _btn_recruit == null:
		return
	var can_recruit := _archer_count < MAX_FORMATION and _current_gold >= ARCHER_COST
	_btn_recruit.text = "Archer\n%dg" % ARCHER_COST
	_btn_recruit.disabled = not can_recruit

	var can_tower := _current_gold >= TOWER_COST
	_btn_tower.disabled = not can_tower

	var can_forge := _current_gold >= FORGE_COST
	if _btn_forge_dmg != null:
		_btn_forge_dmg.disabled = not can_forge
		_btn_forge_spd.disabled = not can_forge
		_btn_forge_mag.disabled = not can_forge
		_btn_forge_hp.disabled = not can_forge

## Toggle visibility of all TD-mode vs RPG-mode HUD elements.
## exploring=true → hide TD, show RPG strip; exploring=false → vice versa.
func _set_exploring_mode(exploring: bool) -> void:
	for el: Node in _td_elements:
		if is_instance_valid(el):
			el.visible = not exploring
	if _rpg_strip != null:
		_rpg_strip.visible = exploring
	if _rpg_hp_bar != null:
		_rpg_hp_bar.visible = exploring
	if _rpg_hp_lbl != null:
		_rpg_hp_lbl.visible = exploring
	if _rpg_level_lbl != null:
		_rpg_level_lbl.visible = exploring
	if _rpg_camps_lbl != null:
		_rpg_camps_lbl.visible = exploring
	if _btn_inventory != null:
		_btn_inventory.visible = exploring
	## Always close inventory panel when switching modes
	if _inventory_panel != null:
		_inventory_panel.visible = false
	_inventory_visible = false
	## Hide interact button when leaving EXPLORING (never show in TD mode)
	if not exploring and _btn_interact != null:
		_btn_interact.visible = false
	## Hide mount button when leaving EXPLORING
	if not exploring and _btn_mount != null:
		_btn_mount.visible = false
	## Spell upgrade button — visible only while EXPLORING
	if _btn_spell_upgrades != null:
		_btn_spell_upgrades.visible = exploring
	## Mini-map — show only while EXPLORING
	_set_minimap_visible(exploring)

## Show or hide all minimap nodes.
func _set_minimap_visible(v: bool) -> void:
	if _minimap_bg != null:
		_minimap_bg.visible = v
		for z: int in range(15):
			var key: String = "zone_tile_%d" % z
			if _minimap_bg.has_meta(key):
				(_minimap_bg.get_meta(key) as ColorRect).visible = v
	if _minimap_hero_dot != null:
		_minimap_hero_dot.visible = v

## Build the RPG top bar and inventory system shown while EXPLORING.
## Called by Main._setup_ui() on the HUDLayer CanvasLayer after build_meta_buttons().
func build_rpg_elements(parent: Node) -> void:
	## Dark green top bar — same 960×60 area as TD bar, shown only in EXPLORING
	_rpg_strip = ColorRect.new()
	_rpg_strip.size = Vector2(960.0, 60.0)
	_rpg_strip.color = Color(0.04, 0.11, 0.07, 0.85)
	_rpg_strip.visible = false
	parent.add_child(_rpg_strip)

	## Hero HP bar — left section (8-188, y 8-26)
	_rpg_hp_bar = ProgressBar.new()
	_rpg_hp_bar.position = Vector2(8.0, 8.0)
	_rpg_hp_bar.size = Vector2(180.0, 18.0)
	_rpg_hp_bar.min_value = 0
	_rpg_hp_bar.max_value = 50
	_rpg_hp_bar.value = 50
	_rpg_hp_bar.show_percentage = false
	_rpg_hp_bar.modulate = Color("#EF5350")
	_rpg_hp_bar.visible = false
	parent.add_child(_rpg_hp_bar)

	_rpg_hp_lbl = Label.new()
	_rpg_hp_lbl.position = Vector2(8.0, 30.0)
	_rpg_hp_lbl.size = Vector2(180.0, 22.0)
	_rpg_hp_lbl.text = "Hero: 50/50 HP"
	_rpg_hp_lbl.add_theme_font_size_override("font_size", 11)
	_rpg_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rpg_hp_lbl.add_theme_color_override("font_color", Color("#EF9A9A"))
	_rpg_hp_lbl.visible = false
	parent.add_child(_rpg_hp_lbl)

	## Level / XP — center section (200-549)
	_rpg_level_lbl = Label.new()
	_rpg_level_lbl.position = Vector2(200.0, 8.0)
	_rpg_level_lbl.size = Vector2(350.0, 44.0)
	_rpg_level_lbl.text = "Novice  |  0 / 30 XP"
	_rpg_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rpg_level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rpg_level_lbl.add_theme_font_size_override("font_size", 16)
	_rpg_level_lbl.add_theme_color_override("font_color", Color("#7BC8F6"))
	_rpg_level_lbl.visible = false
	parent.add_child(_rpg_level_lbl)

	## Camps counter — right section (560-699)
	_rpg_camps_lbl = Label.new()
	_rpg_camps_lbl.position = Vector2(562.0, 8.0)
	_rpg_camps_lbl.size = Vector2(138.0, 44.0)
	_rpg_camps_lbl.text = "Camps: 0/3"
	_rpg_camps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rpg_camps_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rpg_camps_lbl.add_theme_font_size_override("font_size", 14)
	_rpg_camps_lbl.add_theme_color_override("font_color", Color("#FFC107"))
	_rpg_camps_lbl.visible = false
	parent.add_child(_rpg_camps_lbl)

	## Inventory button — far right of strip (712-807, y 8-51)
	_btn_inventory = _make_btn("INVENT.", Color("#795548"), 712, 8, 96, 44)
	_btn_inventory.add_theme_font_size_override("font_size", 12)
	var _inv_tex := load("res://assets/sprites/garrison/btn_inventory.png") as Texture2D
	if _inv_tex != null:
		_btn_inventory.icon = _inv_tex
		_btn_inventory.add_theme_constant_override("icon_max_width", 26)
		_btn_inventory.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_inventory.visible = false
	_btn_inventory.pressed.connect(_on_inventory_toggle)
	parent.add_child(_btn_inventory)

	## Build inventory overlay panel (hidden by default)
	_build_inventory_panel(parent)

	## Minimap — far-right section of RPG strip, 5×3 zone tile grid.
	## Background panel (slightly larger than the tile area to give a border effect).
	_minimap_bg = ColorRect.new()
	_minimap_bg.position = Vector2(MINIMAP_X - 3.0, MINIMAP_Y - 3.0)
	_minimap_bg.size = Vector2(MINIMAP_W + 6.0, MINIMAP_H + 6.0)
	_minimap_bg.color = Color(0.04, 0.04, 0.04, 0.90)
	_minimap_bg.visible = false
	parent.add_child(_minimap_bg)

	## Build 5×3 zone tiles
	for z: int in range(15):
		var col: int = z % MINIMAP_ZONE_COLS
		var row: int = z / MINIMAP_ZONE_COLS
		var tile := ColorRect.new()
		tile.position = Vector2(
			MINIMAP_X + float(col) * (MM_TILE_W + MM_TILE_PAD),
			MINIMAP_Y + float(row) * (MM_TILE_H + MM_TILE_PAD))
		tile.size = Vector2(MM_TILE_W, MM_TILE_H)
		var zc: Color = MINIMAP_ZONE_COLORS[z]
		tile.color = Color(zc.r * 0.7, zc.g * 0.7, zc.b * 0.7, 0.90)
		tile.visible = false
		parent.add_child(tile)
		_minimap_bg.set_meta("zone_tile_%d" % z, tile)

	## Hero dot
	_minimap_hero_dot = ColorRect.new()
	_minimap_hero_dot.size = Vector2(4.0, 4.0)
	_minimap_hero_dot.color = Color(1.0, 1.0, 1.0, 1.0)
	_minimap_hero_dot.z_index = 2
	_minimap_hero_dot.visible = false
	parent.add_child(_minimap_hero_dot)

	## Context-sensitive interact button — center-bottom, appears on proximity
	## Positioned at y=453 (same row as TD action buttons, which are hidden in EXPLORING)
	_btn_interact = _make_btn("Récolter", Color("#00897B"), 330, 453, 200, 72)
	_btn_interact.add_theme_font_size_override("font_size", 17)
	_btn_interact.visible = false
	_btn_interact.pressed.connect(func() -> void: interact_pressed.emit())
	parent.add_child(_btn_interact)

	## Mount button — bottom-left, visible only while EXPLORING when Mount system is active
	## x=20, y=460 (below spell upgrade button at y=420-452, above screen bottom at 540)
	_btn_mount = _make_btn("MONTER", Color("#8B4513"), 20, 460, 100, 36)
	_btn_mount.add_theme_font_size_override("font_size", 13)
	_btn_mount.visible = false
	_btn_mount.pressed.connect(func() -> void: mount_pressed.emit())
	parent.add_child(_btn_mount)

	## Spell upgrade button — visible only while EXPLORING, opens upgrade tree panel
	## Positioned at x=20, y=65 (just below the RPG top bar, far from the joystick)
	_btn_spell_upgrades = _make_btn("SORTS +", Color("#6C3483"), 20, 65, 90, 28)
	_btn_spell_upgrades.add_theme_font_size_override("font_size", 11)
	_btn_spell_upgrades.visible = false
	_btn_spell_upgrades.pressed.connect(func() -> void: spell_upgrades_requested.emit())
	parent.add_child(_btn_spell_upgrades)

## Show the context interact button with the given action label.
## Called by Main when hero enters proximity of an interactable.
func show_interact_btn(label: String) -> void:
	if _btn_interact == null:
		return
	_btn_interact.text = label
	_btn_interact.visible = true

## Hide the context interact button.
## Called by Main when hero leaves proximity of all interactables.
func hide_interact_btn() -> void:
	if _btn_interact != null:
		_btn_interact.visible = false

## Update RPG HP bar and label — called by Main when hero.hp_changed fires.
func update_rpg_hp(hp: int, max_hp: int) -> void:
	if _rpg_hp_bar != null:
		_rpg_hp_bar.max_value = max(max_hp, 1)
		_rpg_hp_bar.value = hp
		var ratio: float = float(hp) / float(max(max_hp, 1))
		if ratio >= 0.6:
			_rpg_hp_bar.modulate = Color("#4CAF50")
		elif ratio >= 0.3:
			_rpg_hp_bar.modulate = Color("#FFC107")
		else:
			_rpg_hp_bar.modulate = Color("#EF5350")
	if _rpg_hp_lbl != null:
		_rpg_hp_lbl.text = "Hero: %d/%d HP" % [hp, max_hp]

## Update RPG level / XP label — called by Main when hero.xp_changed fires.
func update_rpg_xp(xp: int, level: int) -> void:
	if _rpg_level_lbl == null:
		return
	const LEVEL_NAMES: Array[String] = ["Novice", "Guerrier", "Champion"]
	const XP_NEXT: Array[int] = [30, 80, 80]  ## XP needed for next level (max at idx 2)
	var lname: String = LEVEL_NAMES[clampi(level, 0, 2)]
	if level >= 2:
		_rpg_level_lbl.text = "%s  |  MAX" % lname
	else:
		_rpg_level_lbl.text = "%s  |  %d / %d XP" % [lname, xp, XP_NEXT[level]]

## Update RPG camps counter — called by Main when a camp is cleared.
func update_rpg_camps(cleared: int) -> void:
	if _rpg_camps_lbl == null:
		return
	_rpg_camps_lbl.text = "Camps: %d/3" % cleared
	var tw := create_tween()
	tw.tween_property(_rpg_camps_lbl, "modulate", Color(1.0, 1.0, 0.4), 0.12)
	tw.tween_property(_rpg_camps_lbl, "modulate", Color(1.0, 1.0, 1.0), 0.30)

## Toggle the inventory overlay open/closed.
func _on_inventory_toggle() -> void:
	_inventory_visible = not _inventory_visible
	if _inventory_panel == null:
		return
	_inventory_panel.visible = _inventory_visible
	if _inventory_visible:
		_refresh_inventory_panel()

## Rebuild the inventory panel content from current ResourceInventory and ItemInventory state.
func _refresh_inventory_panel() -> void:
	if _inv_content_node == null:
		return
	## Use free() (immediate) so new labels added below don't coexist with old ones
	for child: Node in _inv_content_node.get_children():
		child.free()
	var y := 0.0

	## --- Resources ---
	_add_inv_header("RESSOURCES", y)
	y += 24.0
	var resources: Array = ResourceInventory.get_nonempty()
	if resources.is_empty():
		_add_inv_row("(aucune ressource collectée)", Color(0.55, 0.55, 0.55), y)
		y += 20.0
	else:
		for pair: Array in resources:
			var t: int = pair[0]
			var c: int = pair[1]
			_add_inv_row("%s: %d" % [ResourceInventory.SHORT_NAMES[t], c], Color.WHITE, y)
			y += 20.0

	y += 10.0
	## --- Equipment ---
	_add_inv_header("ÉQUIPEMENT", y)
	y += 24.0
	var has_equip := false
	if ItemInventory.hero_weapon >= 0:
		_add_inv_row("Arme: %s" % ItemInventory.NAMES[ItemInventory.hero_weapon], Color("#81C784"), y)
		y += 20.0
		has_equip = true
	if ItemInventory.hero_armor >= 0:
		_add_inv_row("Armure: %s" % ItemInventory.NAMES[ItemInventory.hero_armor], Color("#64B5F6"), y)
		y += 20.0
		has_equip = true
	if not has_equip:
		_add_inv_row("(aucun équipement)", Color(0.55, 0.55, 0.55), y)
		y += 20.0

	## Persistent buffs (item IDs 8–22)
	var buffs: Array[String] = []
	for id: int in range(8, 23):
		if ItemInventory.has_item(id):
			buffs.append(ItemInventory.NAMES[id])
	if not buffs.is_empty():
		y += 6.0
		_add_inv_header("AMÉLIORATIONS", y)
		y += 24.0
		for b: String in buffs:
			_add_inv_row(b, Color("#FFA726"), y)
			y += 20.0

	y += 10.0
	## --- Consumables ---
	_add_inv_header("CONSOMMABLES", y)
	y += 24.0
	var any_cons := false
	for cid: int in [23, 24, 25, 26]:
		var cnt: int = ItemInventory.consumable_count(cid)
		if cnt > 0:
			_add_inv_row("%s  ×%d" % [ItemInventory.NAMES[cid], cnt], Color("#CE93D8"), y)
			y += 20.0
			any_cons = true
	if not any_cons:
		_add_inv_row("(aucun consommable)", Color(0.55, 0.55, 0.55), y)

func _add_inv_header(text: String, y: float) -> void:
	if _inv_content_node == null:
		return
	var lbl := Label.new()
	lbl.text = "— %s —" % text
	lbl.position = Vector2(0.0, y)
	lbl.size = Vector2(730.0, 20.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#BDBDBD"))
	_inv_content_node.add_child(lbl)

func _add_inv_row(text: String, color: Color, y: float) -> void:
	if _inv_content_node == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(16.0, y)
	lbl.size = Vector2(714.0, 18.0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	_inv_content_node.add_child(lbl)

## Build the inventory overlay panel (once, shown/hidden on demand).
func _build_inventory_panel(parent: Node) -> void:
	const PW := 820.0
	const PH := 420.0
	const PX := 70.0
	const PY := 62.0

	_inventory_panel = Control.new()
	_inventory_panel.position = Vector2.ZERO
	_inventory_panel.size = Vector2(960.0, 540.0)
	_inventory_panel.visible = false
	parent.add_child(_inventory_panel)

	## Dark backdrop — tap outside panel body to close
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(960.0, 540.0)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_inventory_visible = false
			_inventory_panel.visible = false)
	_inventory_panel.add_child(backdrop)

	## Panel body — stops backdrop tap-through
	var panel_bg := ColorRect.new()
	panel_bg.position = Vector2(PX, PY)
	panel_bg.size = Vector2(PW, PH)
	panel_bg.color = Color(0.09, 0.07, 0.05, 0.97)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_panel.add_child(panel_bg)

	## Title
	var title := Label.new()
	title.text = "INVENTAIRE"
	title.position = Vector2(PX, PY + 6.0)
	title.size = Vector2(PW - 50.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#FFC107"))
	_inventory_panel.add_child(title)

	## Close button — top-right corner of panel
	var btn_close := _make_btn("X", Color("#C0392B"), int(PX + PW - 38.0), int(PY + 8.0), 32, 26)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(func() -> void:
		_inventory_visible = false
		_inventory_panel.visible = false)
	_inventory_panel.add_child(btn_close)

	## Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(PX + 8.0, PY + 46.0)
	scroll.size = Vector2(PW - 16.0, PH - 52.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_panel.add_child(scroll)

	_inv_content_node = Control.new()
	_inv_content_node.custom_minimum_size = Vector2(PW - 16.0, 600.0)
	scroll.add_child(_inv_content_node)

## Build and attach the bottom-right action button panel.
## Called by Main._setup_ui() — parent is the HUDLayer CanvasLayer.
func build_action_buttons(parent: Node) -> void:
	const BTN_W := 95
	const BTN_H := 82
	const GAP   := 6
	const Y_ROW := 453  ## top of main button row (viewport y in 960×540)
	const X0    := 460  ## left edge of first button

	# Semi-transparent background behind the 5 buttons
	var panel_bg := ColorRect.new()
	panel_bg.size = Vector2(5 * BTN_W + 4 * GAP + 8, BTN_H + 8)
	panel_bg.position = Vector2(X0 - 4, Y_ROW - 4)
	panel_bg.color = Color(0.0, 0.0, 0.0, 0.50)
	parent.add_child(panel_bg)
	_td_elements.append(panel_bg)

	# --- Main row ---
	_btn_recruit = _make_btn("Archer\n30g",  Color("#27AE60"), X0,                        Y_ROW, BTN_W, BTN_H)
	_set_btn_icon(_btn_recruit, "res://assets/sprites/garrison/btn_archer.png")
	_btn_recruit.pressed.connect(func() -> void: recruit_pressed.emit())
	parent.add_child(_btn_recruit)
	_td_elements.append(_btn_recruit)

	_btn_tower = _make_btn("Tour\n100g", Color("#2980B9"), X0 + (BTN_W + GAP),       Y_ROW, BTN_W, BTN_H)
	_set_btn_icon(_btn_tower, "res://assets/sprites/garrison/btn_tower.png")
	_btn_tower.pressed.connect(func() -> void: tower_pressed.emit())
	parent.add_child(_btn_tower)
	_td_elements.append(_btn_tower)

	_btn_target = _make_btn("Cible\nMode", Color("#8E44AD"), X0 + 2 * (BTN_W + GAP), Y_ROW, BTN_W, BTN_H)
	_set_btn_icon(_btn_target, "res://assets/sprites/garrison/btn_target.png")
	_btn_target.pressed.connect(func() -> void: target_pressed.emit())
	parent.add_child(_btn_target)
	_td_elements.append(_btn_target)

	_btn_form = _make_btn("Form.\nMode",  Color("#D35400"), X0 + 3 * (BTN_W + GAP), Y_ROW, BTN_W, BTN_H)
	_set_btn_icon(_btn_form, "res://assets/sprites/garrison/btn_formation.png")
	_btn_form.pressed.connect(func() -> void: formation_pressed.emit())
	parent.add_child(_btn_form)
	_td_elements.append(_btn_form)

	_btn_forge = _make_btn("Forge\n[+]",  Color("#C0392B"), X0 + 4 * (BTN_W + GAP), Y_ROW, BTN_W, BTN_H)
	_set_btn_icon(_btn_forge, "res://assets/sprites/garrison/btn_forge.png")
	_btn_forge.pressed.connect(_on_forge_toggle)
	parent.add_child(_btn_forge)
	_td_elements.append(_btn_forge)

	# --- Forge sub-panel (4 upgrade buttons, hidden by default) ---
	_forge_panel = Control.new()
	_forge_panel.position = Vector2(X0 - 4, Y_ROW - BTN_H - GAP - 4)
	_forge_panel.size = Vector2(4 * BTN_W + 3 * GAP + 8, BTN_H + 8)
	_forge_panel.visible = false
	parent.add_child(_forge_panel)
	_td_elements.append(_forge_panel)

	var fpbg := ColorRect.new()
	fpbg.size = _forge_panel.size
	fpbg.color = Color(0.0, 0.0, 0.0, 0.50)
	_forge_panel.add_child(fpbg)

	_btn_forge_dmg = _make_btn("DMG\n200g", Color("#E74C3C"), 4, 4, BTN_W, BTN_H)
	_set_btn_icon(_btn_forge_dmg, "res://assets/sprites/garrison/btn_forge_dmg.png")
	_btn_forge_dmg.pressed.connect(func() -> void: forge_dmg_pressed.emit())
	_forge_panel.add_child(_btn_forge_dmg)

	_btn_forge_spd = _make_btn("VIT\n200g",  Color("#F39C12"), 4 + (BTN_W + GAP),       4, BTN_W, BTN_H)
	_set_btn_icon(_btn_forge_spd, "res://assets/sprites/garrison/btn_forge_spd.png")
	_btn_forge_spd.pressed.connect(func() -> void: forge_spd_pressed.emit())
	_forge_panel.add_child(_btn_forge_spd)

	_btn_forge_mag = _make_btn("MAG\n200g",  Color("#3498DB"), 4 + 2 * (BTN_W + GAP),  4, BTN_W, BTN_H)
	_set_btn_icon(_btn_forge_mag, "res://assets/sprites/garrison/btn_forge_mag.png")
	_btn_forge_mag.pressed.connect(func() -> void: forge_mag_pressed.emit())
	_forge_panel.add_child(_btn_forge_mag)

	_btn_forge_hp = _make_btn("PV\n200g",   Color("#2ECC71"), 4 + 3 * (BTN_W + GAP),  4, BTN_W, BTN_H)
	_set_btn_icon(_btn_forge_hp, "res://assets/sprites/garrison/btn_forge_hp.png")
	_btn_forge_hp.pressed.connect(func() -> void: forge_hp_pressed.emit())
	_forge_panel.add_child(_btn_forge_hp)

	_refresh_button_states()

## Toggle the forge sub-panel open/closed.
func _on_forge_toggle() -> void:
	_forge_open = not _forge_open
	_forge_panel.visible = _forge_open
	_btn_forge.text = "Forge\n[-]" if _forge_open else "Forge\n[+]"

## Show the tower power selection panel for the given tower node.
## Called by Main when a tower emits power_requested.
func show_power_panel(tower: Node) -> void:
	_power_target_tower = tower
	if _power_panel == null:
		_build_power_panel(get_parent())  ## parent is HUDLayer
	## Update tier upgrade button text/visibility for the target tower
	if _tier_upgrade_btn != null:
		var cost: int = tower.get_next_tier_cost() if tower.has_method("get_next_tier_cost") else 0
		var name_: String = tower.get_next_tier_name() if tower.has_method("get_next_tier_name") else ""
		if cost > 0 and name_ != "":
			var free_str: String = "(gratuit)" if (tower.has_method("is_power_free") and tower.is_power_free()) else ("%dg" % cost)
			_tier_upgrade_btn.text = "AMELIORER → %s  %s" % [name_, free_str]
			_tier_upgrade_btn.disabled = false
			_tier_upgrade_btn.visible = true
		else:
			_tier_upgrade_btn.text = "Forteresse (max)"
			_tier_upgrade_btn.disabled = true
			_tier_upgrade_btn.visible = true
	_power_panel.visible = true

## Hide the power selection panel.
func hide_power_panel() -> void:
	if _power_panel != null:
		_power_panel.visible = false
	_power_target_tower = null

## Build the tower power panel (once; shown/hidden on demand).
func _build_power_panel(parent: Node) -> void:
	const PPW := 500
	const PPH := 160
	const BTNW := 140
	const BTNH := 75
	const GAPP := 8
	const UPGRADE_H := 42
	_power_panel = Control.new()
	_power_panel.size = Vector2(PPW, PPH)
	_power_panel.position = Vector2((960 - PPW) / 2, 165.0)
	_power_panel.visible = false
	parent.add_child(_power_panel)

	var bg := ColorRect.new()
	bg.size = _power_panel.size
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	_power_panel.add_child(bg)

	var lbl := Label.new()
	lbl.text = "Choisir un pouvoir (150g):"
	lbl.position = Vector2(8.0, 4.0)
	_power_panel.add_child(lbl)

	var x0 := 8
	var y0 := 24

	var btn_f := _make_btn("FEU\n+80% Dmg\n150g", Color("#E74C3C"), x0,                  y0, BTNW, BTNH)
	btn_f.pressed.connect(func() -> void:
		power_fire_pressed.emit(_power_target_tower)
		hide_power_panel())
	_power_panel.add_child(btn_f)

	var btn_l := _make_btn("ECLAIR\n+80% Vit.\n150g", Color("#F1C40F"), x0 + BTNW + GAPP, y0, BTNW, BTNH)
	btn_l.pressed.connect(func() -> void:
		power_lightning_pressed.emit(_power_target_tower)
		hide_power_panel())
	_power_panel.add_child(btn_l)

	var btn_w := _make_btn("EAU\n-80% Vitesse\nennemis  150g", Color("#3498DB"), x0 + 2 * (BTNW + GAPP), y0, BTNW, BTNH)
	btn_w.pressed.connect(func() -> void:
		power_water_pressed.emit(_power_target_tower)
		hide_power_panel())
	_power_panel.add_child(btn_w)

	var btn_c := _make_btn("Annuler", Color("#7F8C8D"), x0 + 3 * (BTNW + GAPP), y0, BTNW, BTNH)
	btn_c.pressed.connect(func() -> void:
		power_panel_cancelled.emit()
		hide_power_panel())
	_power_panel.add_child(btn_c)

	## Tier upgrade button — full-width row below the power buttons
	var y_upgrade := y0 + BTNH + GAPP
	_tier_upgrade_btn = _make_btn("AMELIORER", Color("#8D6E63"), x0, y_upgrade, PPW - 2 * x0, UPGRADE_H)
	_tier_upgrade_btn.add_theme_font_size_override("font_size", 14)
	_tier_upgrade_btn.pressed.connect(func() -> void:
		if _power_target_tower != null and _power_target_tower.has_method("get_next_tier_cost"):
			var next_tier: int = int(_power_target_tower.get("_tier")) + 1
			tier_upgrade_pressed.emit(_power_target_tower, next_tier)
		hide_power_panel())
	_power_panel.add_child(_tier_upgrade_btn)

## Register the HeroSpells node so the HUD can display cooldowns each frame.
func set_hero_spells(hero_spells: Node) -> void:
	_hero_spells = hero_spells

## Build the 3 spell buttons in a MOBA-style vertical column on the right side.
## Called by Main._setup_ui() on the HUDLayer CanvasLayer.
## Column sits at x≈876 (8px from right edge), above the action button row (y<453).
## Order: Feu at bottom (thumb-reachable), Glace at top.
## Buttons display the generated spell PNG icon (80x80) above a small name label.
func build_spell_buttons(parent: Node) -> void:
	const SPELL_NAMES := ["Feu", "Foudre", "Glace"]
	const SPELL_COLORS := [Color("#E74C3C"), Color("#F1C40F"), Color("#3498DB")]
	const SPELL_ICONS := [
		"res://assets/sprites/garrison/spell_fire.png",
		"res://assets/sprites/garrison/spell_lightning.png",
		"res://assets/sprites/garrison/spell_ice.png",
	]
	const BTN_W := 80
	const BTN_H := 80
	## Right-side vertical column — 8px gap between buttons, 4px from right edge
	const POSITIONS: Array[Vector2] = [
		Vector2(876.0, 365.0),   ## 0 — Feu     : bottom (closest to thumb)
		Vector2(876.0, 277.0),   ## 1 — Foudre  : middle
		Vector2(876.0, 189.0),   ## 2 — Glace   : top
	]

	for i: int in range(3):
		var pos: Vector2 = POSITIONS[i]
		var btn: Button = _make_btn("", SPELL_COLORS[i],
				int(pos.x), int(pos.y), BTN_W, BTN_H)
		## Icon fills the button — spell identity communicated by image, not text
		var icon_tex: Texture2D = load(SPELL_ICONS[i])
		if icon_tex != null:
			btn.icon = icon_tex
			btn.expand_icon = true
		var idx := i  ## Capture loop variable for lambda
		btn.pressed.connect(func() -> void: spell_pressed.emit(idx))
		parent.add_child(btn)
		_btn_spells.append(btn)
		## Spell buttons intentionally NOT in _td_elements — remain visible in RPG/EXPLORING mode

		## Small spell name label below the button
		var name_lbl := Label.new()
		name_lbl.text = SPELL_NAMES[i]
		name_lbl.position = Vector2(pos.x, pos.y + float(BTN_H) + 2.0)
		name_lbl.size = Vector2(float(BTN_W), 16.0)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", SPELL_COLORS[i])
		parent.add_child(name_lbl)

		## Cooldown overlay label — centered on each button
		var cd_lbl := Label.new()
		cd_lbl.position = Vector2(pos.x + 4.0, pos.y + float(BTN_H) / 2.0 - 10.0)
		cd_lbl.size = Vector2(BTN_W - 8, 20)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 18)
		cd_lbl.add_theme_color_override("font_color", Color.WHITE)
		cd_lbl.text = ""
		parent.add_child(cd_lbl)
		_spell_cd_labels.append(cd_lbl)
		## Cooldown labels also remain visible in RPG mode (companion to spell buttons)

## Build the Start Wave button — top-right row, left of the EXPLORER button.
## Called by Main._setup_ui() on the HUDLayer CanvasLayer.
func build_start_wave_button(parent: Node) -> void:
	const BTN_W := 170
	const BTN_H := 40
	const BTN_X := 642   ## Left of EXPLORER (818 - 170 - 6px gap)
	const BTN_Y := 68    ## Same row as EXPLORER/RETOUR
	_btn_start_wave = _make_btn("LANCER LA VAGUE", Color("#27AE60"), BTN_X, BTN_Y, BTN_W, BTN_H)
	_btn_start_wave.add_theme_font_size_override("font_size", 16)
	_btn_start_wave.visible = false
	_btn_start_wave.pressed.connect(func() -> void:
		hide_start_wave_btn()
		start_wave_pressed.emit())
	parent.add_child(_btn_start_wave)
	_td_elements.append(_btn_start_wave)
	## Wave preview label — appears just below the button
	_wave_preview_lbl = Label.new()
	_wave_preview_lbl.position = Vector2(BTN_X, BTN_Y + BTN_H + 2)
	_wave_preview_lbl.size = Vector2(BTN_W, 20)
	_wave_preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_preview_lbl.add_theme_font_size_override("font_size", 11)
	_wave_preview_lbl.add_theme_color_override("font_color", Color("#FFCC80"))
	_wave_preview_lbl.visible = false
	parent.add_child(_wave_preview_lbl)
	_td_elements.append(_wave_preview_lbl)

## Show the Start Wave button with a gentle pulse animation (called by wave_start_ready).
## preview — dict from EnemyWave.get_next_wave_preview() with wave/tag/composition keys.
func show_start_wave_btn(preview: Dictionary = {}) -> void:
	if _btn_start_wave == null:
		return
	_btn_start_wave.visible = true
	## Update preview label
	if _wave_preview_lbl != null:
		if not preview.is_empty():
			var tag_str: String = ""
			match preview.get("tag", ""):
				"BOSS":         tag_str = " ⚠BOSS"
				"ELITE":        tag_str = " ÉLITE"
				"RUSH":         tag_str = " RUSH"
				"HEALER_SURGE": tag_str = " SOINS+"
			_wave_preview_lbl.text = "Vague %d%s — %s" % [
				preview.get("wave", "?"), tag_str,
				preview.get("composition", "")
			]
			_wave_preview_lbl.visible = true
		else:
			_wave_preview_lbl.visible = false
	if _start_wave_tween != null:
		_start_wave_tween.kill()
	_start_wave_tween = create_tween()
	_start_wave_tween.set_loops()
	_start_wave_tween.tween_property(_btn_start_wave, "modulate",
			Color(1.0, 1.0, 1.0, 1.0), 0.55)
	_start_wave_tween.tween_property(_btn_start_wave, "modulate",
			Color(1.0, 1.0, 1.0, 0.55), 0.55)

## Hide the Start Wave button and stop the pulse (called when wave begins or game resets).
func hide_start_wave_btn() -> void:
	if _start_wave_tween != null:
		_start_wave_tween.kill()
		_start_wave_tween = null
	if _btn_start_wave != null:
		_btn_start_wave.modulate = Color.WHITE
		_btn_start_wave.visible = false
	if _wave_preview_lbl != null:
		_wave_preview_lbl.visible = false

## Update spell button enabled/disabled state and cooldown countdown labels.
## Called every frame from _process when _hero_spells is set.
func _refresh_spell_cooldowns() -> void:
	for i: int in range(3):
		var remaining: float = _hero_spells.get_cooldown_remaining(i)
		var ready: bool = _hero_spells.is_ready(i)
		_btn_spells[i].disabled = not ready
		_spell_cd_labels[i].text = "%ds" % int(ceil(remaining)) if not ready else ""

## Build pause and speed buttons in the top-right HUD strip, plus info labels.
## Called by Main._setup_ui() on the HUDLayer CanvasLayer.
func build_meta_buttons(parent: Node) -> void:
	## Pause button — "||" at top-right of HUD strip
	_btn_pause = _make_btn("||", Color("#7F8C8D"), 870, 6, 38, 24)
	_btn_pause.add_theme_font_size_override("font_size", 12)
	_btn_pause.pressed.connect(_on_pause_toggled)
	parent.add_child(_btn_pause)
	_td_elements.append(_btn_pause)

	## Speed button — "1x" / "2x" next to pause
	_btn_speed = _make_btn("1x", Color("#7F8C8D"), 912, 6, 40, 24)
	_btn_speed.add_theme_font_size_override("font_size", 12)
	_btn_speed.pressed.connect(_on_speed_toggled)
	parent.add_child(_btn_speed)
	_td_elements.append(_btn_speed)

	## Mode label — shows current targeting and formation mode above action buttons
	_mode_label = Label.new()
	_mode_label.position = Vector2(460.0, 438.0)
	_mode_label.size = Vector2(300.0, 16.0)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mode_label.add_theme_font_size_override("font_size", 11)
	_mode_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.85))
	_mode_label.text = "NEAREST | V-Form."
	parent.add_child(_mode_label)
	_td_elements.append(_mode_label)

	## Enemy count label — right of wave label in top bar
	_enemy_count_label = Label.new()
	_enemy_count_label.position = Vector2(500.0, 14.0)
	_enemy_count_label.size = Vector2(160.0, 20.0)
	_enemy_count_label.add_theme_font_size_override("font_size", 13)
	_enemy_count_label.add_theme_color_override("font_color", Color("#FFA726"))
	_enemy_count_label.text = ""
	parent.add_child(_enemy_count_label)
	_td_elements.append(_enemy_count_label)

	## Streak label — small label at left side above joystick area
	_streak_label = Label.new()
	_streak_label.position = Vector2(10.0, 370.0)
	_streak_label.size = Vector2(200.0, 22.0)
	_streak_label.add_theme_font_size_override("font_size", 14)
	_streak_label.add_theme_color_override("font_color", Color("#F5C518"))
	_streak_label.text = ""
	parent.add_child(_streak_label)
	_td_elements.append(_streak_label)

	## Announce label — centered overlay for boss/elite wave announcement
	_announce_label = Label.new()
	_announce_label.position = Vector2(180.0, 190.0)
	_announce_label.size = Vector2(600.0, 70.0)
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce_label.add_theme_font_size_override("font_size", 34)
	_announce_label.add_theme_color_override("font_color", Color.WHITE)
	_announce_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	parent.add_child(_announce_label)
	_td_elements.append(_announce_label)

	## Pause overlay — semi-transparent black rect shown while paused.
	## z_index = -1 keeps it behind all other HUD controls while above the game world.
	_pause_overlay = ColorRect.new()
	_pause_overlay.size = Vector2(960.0, 540.0)
	_pause_overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.z_index = -1
	parent.add_child(_pause_overlay)
	_td_elements.append(_pause_overlay)

## Toggle game pause — freezes world, shows overlay, updates button label.
func _on_pause_toggled() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_btn_pause.text = ">" if _paused else "||"
	if _pause_overlay != null:
		_pause_overlay.visible = _paused

## Toggle game speed between 1× and 2×.
func _on_speed_toggled() -> void:
	_speed_2x = not _speed_2x
	Engine.time_scale = 2.0 if _speed_2x else 1.0
	_btn_speed.text = "2x" if _speed_2x else "1x"

## Show a boss/elite wave announcement banner with a fade-in/out Tween.
func _show_wave_announce(text: String, color: Color) -> void:
	if _announce_label == null:
		return
	if _announce_tween != null:
		_announce_tween.kill()
	_announce_label.text = text
	_announce_label.add_theme_color_override("font_color", color)
	_announce_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce_label, "modulate:a", 1.0, 0.3)
	_announce_tween.tween_interval(1.5)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.5)

## Update mode label text from stored mode indices.
func _refresh_mode_label() -> void:
	if _mode_label == null:
		return
	const TARGET_NAMES := ["NEAREST", "FIRST", "STRONG", "WEAK"]
	const FORM_NAMES := ["V-Form.", "LINE", "ARC"]
	var t: String = TARGET_NAMES[clampi(_current_target_mode, 0, 3)]
	var f: String = FORM_NAMES[clampi(_current_formation_mode, 0, 2)]
	_mode_label.text = "%s | %s" % [t, f]

## Called when ArcherFormation.targeting_mode_changed fires.
func _on_targeting_mode_changed(mode: int) -> void:
	_current_target_mode = mode
	_refresh_mode_label()

## Called when ArcherFormation.formation_mode_changed fires.
func _on_formation_mode_changed(mode: int) -> void:
	_current_formation_mode = mode
	_refresh_mode_label()

## Called when ArcherFormation.streak_tier_changed fires.
func _on_streak_tier_changed(tier: int) -> void:
	if _streak_label == null:
		return
	const TIER_LABELS := ["", "×1.15 STREAK", "×1.30 STREAK!", "×1.50 STREAK!!"]
	_streak_label.text = TIER_LABELS[clampi(tier, 0, 3)]

## Show a temporary floating "-Xg entretien" popup near the gold label.
func show_upkeep_popup(amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%dg entretien" % amount
	lbl.position = Vector2(820.0, 40.0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#EF5350"))
	var target: Node = get_parent() if get_parent() != null else self
	target.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", 20.0, 0.9)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	tween.tween_callback(lbl.queue_free)

## Called when Economy.forge_dmg_purchased fires — increment counter and update label.
func _on_forge_dmg_purchased() -> void:
	_forge_levels[0] += 1
	_refresh_forge_labels()

## Called when Economy.forge_spd_purchased fires.
func _on_forge_spd_purchased() -> void:
	_forge_levels[1] += 1
	_refresh_forge_labels()

## Called when Economy.forge_mag_purchased fires.
func _on_forge_mag_purchased() -> void:
	_forge_levels[2] += 1
	_refresh_forge_labels()

## Called when Economy.forge_hp_purchased fires.
func _on_forge_hp_purchased() -> void:
	_forge_levels[3] += 1
	_refresh_forge_labels()

## Called when forge_stat_changed fires or any purchase occurs.
## Updates forge button labels with effective stat values from the Forge node.
func _refresh_forge_labels() -> void:
	if _forge_ref == null:
		return
	if _btn_forge_dmg != null:
		var lv: int   = _forge_ref.k_dmg
		var val: int  = _forge_ref.effective_proj_damage()
		_btn_forge_dmg.text = "DMG %s\n→%d dmg" % [("Lv.%d" % lv if lv > 0 else ""), val]
	if _btn_forge_spd != null:
		var lv: int     = _forge_ref.k_ivtl
		var val: float  = _forge_ref.effective_shoot_ivtl()
		_btn_forge_spd.text = "VIT %s\n→%.2fs" % [("Lv.%d" % lv if lv > 0 else ""), val]
	if _btn_forge_mag != null:
		var lv: int   = _forge_ref.k_magnet
		var val: int  = int(_forge_ref.effective_magnet_r())
		_btn_forge_mag.text = "MAG %s\n→%dpx" % [("Lv.%d" % lv if lv > 0 else ""), val]
	if _btn_forge_hp != null:
		var lv: int   = _forge_ref.k_hp
		var val: int  = _forge_ref.effective_castle_max_hp()
		_btn_forge_hp.text = "PV %s\n→%dHP" % [("Lv.%d" % lv if lv > 0 else ""), val]

## ── NPC Popup ─────────────────────────────────────────────────────────────
## Called via call_group("hud", "show_npc_popup", ...) from ExplorationMap.
## npc_type: 0=MERCHANT 1=SCOUT 2=SAGE 3=BARD 4=HEALER.
func show_npc_popup(npc: Node, npc_type: int, title: String) -> void:
	_npc_current = npc
	if _npc_panel == null:
		_build_npc_panel(get_parent())
	## Prefer rich personality dialogue from the NPC itself; fall back to generic desc.
	const NPC_DESCS: Array[String] = [
		"Ce marchant vend des ressources rares contre de l'or.\nTaper Interagir pour acheter.",
		"Cet eclaireur peut reveler les caves cachees proches.",
		"Le sage vous transmet son savoir. +80 XP immediat.",
		"Le barde chante pour vous. Vitesse hero +20 % pendant 30 s.",
		"Le guerisseur partage son experience. +30 XP.",
	]
	var desc: String = NPC_DESCS[clampi(npc_type, 0, 4)]
	## If the NPC supports rich dialogue, use it instead.
	if npc != null and npc.has_method("get_dialogue_text"):
		var rich: String = npc.get_dialogue_text()
		if rich.length() > 0:
			desc = rich
	if _npc_title_lbl != null:
		_npc_title_lbl.text = title
	if _npc_desc_lbl != null:
		_npc_desc_lbl.text = desc
	if _npc_panel != null:
		_npc_panel.visible = true

func _build_npc_panel(parent: Node) -> void:
	const PW := 560.0
	const PH := 200.0
	const PX := (960.0 - PW) * 0.5
	const PY := (540.0 - PH) * 0.5

	_npc_panel = Control.new()
	_npc_panel.size = Vector2(960.0, 540.0)
	_npc_panel.visible = false
	parent.add_child(_npc_panel)

	## Backdrop — tap to dismiss
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(960.0, 540.0)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.60)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_npc_panel.visible = false
			_npc_current = null)
	_npc_panel.add_child(backdrop)

	## Panel body
	var bg := ColorRect.new()
	bg.position = Vector2(PX, PY)
	bg.size = Vector2(PW, PH)
	bg.color = Color(0.08, 0.06, 0.10, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_npc_panel.add_child(bg)

	## Gold border top
	var border_top := ColorRect.new()
	border_top.position = Vector2(PX, PY)
	border_top.size = Vector2(PW, 2.0)
	border_top.color = Color(0.90, 0.75, 0.30)
	_npc_panel.add_child(border_top)

	## Title label
	_npc_title_lbl = Label.new()
	_npc_title_lbl.position = Vector2(PX + 8.0, PY + 8.0)
	_npc_title_lbl.size = Vector2(PW - 16.0, 28.0)
	_npc_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_title_lbl.add_theme_font_size_override("font_size", 18)
	_npc_title_lbl.add_theme_color_override("font_color", Color("#FFC107"))
	_npc_panel.add_child(_npc_title_lbl)

	## Description label
	_npc_desc_lbl = Label.new()
	_npc_desc_lbl.position = Vector2(PX + 12.0, PY + 42.0)
	_npc_desc_lbl.size = Vector2(PW - 24.0, 90.0)
	_npc_desc_lbl.add_theme_font_size_override("font_size", 13)
	_npc_desc_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
	_npc_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_panel.add_child(_npc_desc_lbl)

	## Interact button
	var btn_ok := _make_btn("Interagir", Color("#27AE60"),
			int(PX + 12.0), int(PY + PH - 54.0), 200, 44)
	btn_ok.add_theme_font_size_override("font_size", 15)
	btn_ok.pressed.connect(func() -> void:
		if _npc_current != null and _npc_current.has_method("resolve_interaction"):
			_npc_current.resolve_interaction(0)
		_npc_panel.visible = false
		_npc_current = null)
	_npc_panel.add_child(btn_ok)

	## Close button
	var btn_close := _make_btn("Partir", Color("#7F8C8D"),
			int(PX + PW - 212.0), int(PY + PH - 54.0), 200, 44)
	btn_close.add_theme_font_size_override("font_size", 15)
	btn_close.pressed.connect(func() -> void:
		_npc_panel.visible = false
		_npc_current = null)
	_npc_panel.add_child(btn_close)

## ── Contracts Panel ───────────────────────────────────────────────────────
## Called via call_group("hud", "show_contracts_panel") from ExplorationMap.
func show_contracts_panel() -> void:
	## Fetch the first contract board from the group.
	var boards: Array = get_tree().get_nodes_in_group("contract_board")
	if boards.is_empty():
		return
	var board: Node = boards[0]
	if not board.has_method("check_fulfillment"):
		return
	board.check_fulfillment()
	if _contracts_panel == null:
		_build_contracts_panel(get_parent())
	_refresh_contracts_content(board)
	if _contracts_panel != null:
		_contracts_panel.visible = true

func _build_contracts_panel(parent: Node) -> void:
	## Panneau parcheminé — fond bois 760×460, 3 cartes verticales 220×370.
	const PW := 760.0
	const PH := 460.0
	const PX := (960.0 - PW) * 0.5
	const PY := (540.0 - PH) * 0.5

	_contracts_panel = Control.new()
	_contracts_panel.size = Vector2(960.0, 540.0)
	_contracts_panel.visible = false
	parent.add_child(_contracts_panel)

	## Backdrop semi-transparent.
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(960.0, 540.0)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_contracts_panel.visible = false)
	_contracts_panel.add_child(backdrop)

	## Fond bois extérieur.
	var bg_wood := ColorRect.new()
	bg_wood.position = Vector2(PX, PY)
	bg_wood.size = Vector2(PW, PH)
	bg_wood.color = Color(0.35, 0.22, 0.10)
	bg_wood.mouse_filter = Control.MOUSE_FILTER_STOP
	_contracts_panel.add_child(bg_wood)

	## Bordure intérieure bois foncé.
	var bg_inner := ColorRect.new()
	bg_inner.position = Vector2(PX + 4.0, PY + 4.0)
	bg_inner.size = Vector2(PW - 8.0, PH - 8.0)
	bg_inner.color = Color(0.28, 0.18, 0.08)
	bg_inner.mouse_filter = Control.MOUSE_FILTER_PASS
	_contracts_panel.add_child(bg_inner)

	## Banderole titre centree.
	var banner := ColorRect.new()
	banner.position = Vector2(PX + (PW - 500.0) * 0.5, PY + 12.0)
	banner.size = Vector2(500.0, 36.0)
	banner.color = Color(0.55, 0.35, 0.12)
	_contracts_panel.add_child(banner)

	var title := Label.new()
	title.text = "TABLEAU DES CONTRATS"
	title.position = Vector2(PX + (PW - 500.0) * 0.5, PY + 14.0)
	title.size = Vector2(500.0, 32.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_contracts_panel.add_child(title)

	## Contenu des cartes — sera remplacé à chaque show_contracts_panel().
	_contracts_content = Control.new()
	_contracts_content.position = Vector2(PX + 16.0, PY + 60.0)
	_contracts_content.size = Vector2(PW - 32.0, PH - 110.0)
	_contracts_panel.add_child(_contracts_content)

	## Bouton FERMER — bas-droite du panneau.
	var btn_close := _make_btn("FERMER", Color(0.55, 0.35, 0.12),
			int(PX + PW - 136.0), int(PY + PH - 46.0), 120, 34)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(func() -> void: _contracts_panel.visible = false)
	_contracts_panel.add_child(btn_close)

func _refresh_contracts_content(board: Node) -> void:
	if _contracts_content == null:
		return
	for child: Node in _contracts_content.get_children():
		child.free()

	var contracts: Array = board.contracts
	const TIER_NAMES: Array[String]  = ["Facile", "Moyen", "Difficile"]
	const TIER_COLORS: Array[Color]  = [Color("#81C784"), Color("#FFD54F"), Color("#EF9A9A")]
	## Card dimensions.
	const CARD_W   := 220.0
	const CARD_H   := 370.0
	const CARD_PAD := 16.0

	for i: int in range(contracts.size()):
		var c: Dictionary   = contracts[i]
		var fulfilled: bool = c.get("fulfilled", false)
		var tier_idx: int   = clampi(c.get("tier", 0), 0, 2)
		var tier_col: Color = TIER_COLORS[tier_idx]
		var res_type: int   = c.get("type", 0)
		var res_name: String = ResourceInventory.SHORT_NAMES[clampi(res_type, 0,
				ResourceInventory.SHORT_NAMES.size() - 1)]
		var qty_req: int = c.get("qty_required", 1)
		var qty_cur: int = c.get("qty_current", 0)
		var gold: int    = c.get("gold", 0)
		var xp: int      = c.get("xp", 0)

		var card_x: float = float(i) * (CARD_W + CARD_PAD)
		var card_y: float = 0.0

		## Carte parcheminée.
		var card := ColorRect.new()
		card.position = Vector2(card_x, card_y)
		card.size     = Vector2(CARD_W, CARD_H)
		card.color    = Color(0.92, 0.86, 0.72)
		_contracts_content.add_child(card)

		## Icone difficulte (12×12, couleur tier).
		var diff_dot := ColorRect.new()
		diff_dot.position = Vector2(card_x + 8.0, card_y + 8.0)
		diff_dot.size     = Vector2(12.0, 12.0)
		diff_dot.color    = tier_col
		_contracts_content.add_child(diff_dot)

		## Label difficulte.
		var tier_lbl := Label.new()
		tier_lbl.text     = TIER_NAMES[tier_idx]
		tier_lbl.position = Vector2(card_x + 24.0, card_y + 4.0)
		tier_lbl.size     = Vector2(CARD_W - 28.0, 20.0)
		tier_lbl.add_theme_font_size_override("font_size", 12)
		tier_lbl.add_theme_color_override("font_color", Color(0.35, 0.22, 0.10))
		_contracts_content.add_child(tier_lbl)

		## Titre du contrat (ressource).
		var title_lbl := Label.new()
		title_lbl.text                = "Collecte de %s" % res_name
		title_lbl.position            = Vector2(card_x + 6.0, card_y + 28.0)
		title_lbl.size                = Vector2(CARD_W - 12.0, 40.0)
		title_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		_contracts_content.add_child(title_lbl)

		## Separateur.
		var sep := ColorRect.new()
		sep.position = Vector2(card_x + 6.0, card_y + 74.0)
		sep.size     = Vector2(CARD_W - 12.0, 2.0)
		sep.color    = Color(0.65, 0.50, 0.32)
		_contracts_content.add_child(sep)

		## Barre de progression — fond.
		var prog_bg := ColorRect.new()
		prog_bg.position = Vector2(card_x + 10.0, card_y + 86.0)
		prog_bg.size     = Vector2(CARD_W - 20.0, 12.0)
		prog_bg.color    = Color(0.60, 0.48, 0.32)
		_contracts_content.add_child(prog_bg)

		## Barre de progression — remplie.
		var prog_ratio: float = clampf(float(qty_cur) / float(qty_req), 0.0, 1.0)
		var prog_fill := ColorRect.new()
		prog_fill.position = Vector2(card_x + 10.0, card_y + 86.0)
		prog_fill.size     = Vector2((CARD_W - 20.0) * prog_ratio, 12.0)
		prog_fill.color    = Color("#4CAF50") if fulfilled else tier_col
		_contracts_content.add_child(prog_fill)

		## Texte progression "x/y".
		var prog_lbl := Label.new()
		prog_lbl.text     = "%d/%d" % [qty_cur, qty_req]
		prog_lbl.position = Vector2(card_x + 10.0, card_y + 100.0)
		prog_lbl.size     = Vector2(CARD_W - 20.0, 18.0)
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog_lbl.add_theme_font_size_override("font_size", 12)
		prog_lbl.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		_contracts_content.add_child(prog_lbl)

		## Recompense or.
		var reward_lbl := Label.new()
		reward_lbl.text     = "+%dg  +%dXP" % [gold, xp]
		reward_lbl.position = Vector2(card_x + 6.0, card_y + 126.0)
		reward_lbl.size     = Vector2(CARD_W - 12.0, 22.0)
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", Color(0.7, 0.55, 0.0))
		_contracts_content.add_child(reward_lbl)

		## Bouton LIVRER / En cours... — bas de carte.
		var deliver_btn := Button.new()
		deliver_btn.text     = "LIVRER" if fulfilled else "En cours..."
		deliver_btn.position = Vector2(card_x + 10.0, card_y + CARD_H - 46.0)
		deliver_btn.size     = Vector2(CARD_W - 20.0, 34.0)
		deliver_btn.disabled = not fulfilled
		var dbtn_style := StyleBoxFlat.new()
		dbtn_style.bg_color = Color(0.35, 0.60, 0.30) if fulfilled else Color(0.50, 0.44, 0.34)
		dbtn_style.set_corner_radius_all(6)
		deliver_btn.add_theme_stylebox_override("normal", dbtn_style)
		deliver_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		deliver_btn.add_theme_font_size_override("font_size", 13)
		_contracts_content.add_child(deliver_btn)

## Show or update the mount button — called by Main when mount system is active in EXPLORING.
## is_mounted=true → label becomes "DESCENDRE"; false → "MONTER".
func update_mount_btn(is_mounted: bool) -> void:
	if _btn_mount == null:
		return
	_btn_mount.text = "DESCENDRE" if is_mounted else "MONTER"
	## Show the button (it may have been hidden if the Mount system wasn't set up yet)
	if GameStateMachine.current_state == GameStateMachine.State.EXPLORING:
		_btn_mount.visible = true

## Show the mount button (called by Main when entering EXPLORING with an active mount system).
func show_mount_btn() -> void:
	if _btn_mount != null:
		_btn_mount.visible = true

## Helper — build a styled Button at position (x, y) with the given accent color.
func _make_btn(label: String, accent: Color, x: int, y: int, w: int, h: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 14)

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 0.90)
	sn.border_color = accent
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("normal", sn)

	var sp := StyleBoxFlat.new()
	sp.bg_color = accent
	sp.border_color = Color.WHITE
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("pressed", sp)

	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.95)
	sh.border_color = Color.WHITE
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("hover", sh)

	var sd := StyleBoxFlat.new()
	sd.bg_color = Color(0.12, 0.12, 0.12, 0.70)
	sd.border_color = Color(0.28, 0.28, 0.28, 0.5)
	sd.set_border_width_all(1)
	sd.set_corner_radius_all(7)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_disabled_color", Color(0.38, 0.38, 0.38, 0.65))

	return btn

## Set an icon on a 95×82 action button — icon centred at top, text shrinks to 11pt.
func _set_btn_icon(btn: Button, res_path: String) -> void:
	var tex := load(res_path) as Texture2D
	if tex == null:
		return
	btn.icon = tex
	btn.add_theme_constant_override("icon_max_width", 44)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_font_size_override("font_size", 11)
