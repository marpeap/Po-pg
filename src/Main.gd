## Main — root scene controller and system wiring
## ADR-007: Scene Architecture
## ADR-001: Viewport 960×540 (landscape), world 1920×1080
## GDD Req: TR-scene-001
##
## Thin orchestrator. Instantiates all gameplay systems, wires signals,
## passes node references. All gameplay lives under GameWorld.
## HUD and GAME_OVER overlay live on HUDLayer (CanvasLayer, layer=1).
## Landscape refactor (Sprint 7): world 1920×1080, castle left-center,
## enemies from right, joystick bottom-left, action buttons bottom-right.
extends Node2D

const ARROW_POOL_SIZE := 24
const MAX_TOWERS := 5  ## Hard cap (TOWER_POSITIONS array size)
## Effective tower slot limit — starts at 5, incremented by "tower_count_+1" quest rewards (max 8).
var _tower_slot_limit: int = 5
## World-space positions for up to 5 towers — flanking the castle on both sides
const TOWER_POSITIONS: Array[Vector2] = [
	Vector2(400.0, 200.0),   ## Tower 1 — upper flank, near castle
	Vector2(400.0, 880.0),   ## Tower 2 — lower flank, near castle
	Vector2(650.0, 350.0),   ## Tower 3 — mid upper
	Vector2(650.0, 730.0),   ## Tower 4 — mid lower
	Vector2(900.0, 540.0),   ## Tower 5 — center forward
]

## Gameplay nodes (added as children of GameWorld or root)
var _hero: Node2D
var _castle: Node2D
var _enemy_wave: Node
var _economy: Node
var _archer_formation: Node2D
var _camera_follow: Node
var _forge: Node  ## Forge stat upgrade system (Sprint 6 — Alpha tier)
var _hero_spells: Node  ## 3 AoE spell slots usable in TD and RPG modes (Sprint 7)

## Arrow pool shared between ArcherFormation and all ArcherTowers
var _arrow_pool: ObjectPool

## Tower tracking
var _towers: Array[Node2D] = []

## UI nodes
var _hud: Node
var _game_over_overlay: Node

## Joystick visual — rendered on HUDLayer in viewport space
var _joy_base: Sprite2D
var _joy_knob: Sprite2D

## Main menu — shown once on game launch.
var _main_menu: Node = null

## RPG overlay systems (layer nodes, persistent across TD and EXPLORING)
var _rpg_hud_overlay: CanvasLayer = null   ## XP bar, phase, challenges, prestige
var _skill_tree_panel: CanvasLayer = null  ## layer=20 skill tree touchable panel
var _journal_panel: CanvasLayer = null     ## layer=15 quest/codex/mystery journal
var _day_night_cycle: Node = null          ## 8-min cycle, overlay + phase modifiers
var _ambient_life: Node2D = null           ## 64-creature ambient pool (exploration only)

## Phase 2-4 — exploration mode
## _expl_root is null when in TD mode; created on explore entry, freed on return.
var _expl_root: Node2D = null
var _dungeon_node: Node = null         ## Active DungeonFloor overlay (null when not in dungeon)
var _mount_system: Node = null         ## Mount system node (persistent across explorations)
var _spell_upgrade_tree: Node = null   ## SpellUpgradeTree node (persistent)
var _hero_td_pos: Vector2 = Vector2.ZERO  ## Hero's TD position saved when entering exploration
var _explore_btn: Button = null           ## Visible between waves with ≥1 tower
var _return_btn: Button = null            ## Visible only while EXPLORING
var _fade_rect: ColorRect = null          ## Full-screen black overlay for transition fades

var _expl_resource_lbl: Label = null      ## Unused (resources shown in inventory panel)
var _expl_camps_cleared: int = 0          ## Running count reset on each exploration entry
## Consumable quick-use buttons — 4 buttons (Potion/Méga/Élixir/Fumigène), right side of screen.
var _expl_consumable_btns: Array[Button] = []

## Proximity interact system — detect nearest interactable within INTERACT_RADIUS
const INTERACT_RADIUS := 90.0
var _expl_interactables: Array[Node2D] = []
var _expl_nearest: Node2D = null          ## Interactable currently shown in interact button

func _ready() -> void:
	## Force GL clear color in code immediately — guarantees no white flash even if
	## project.godot is not yet reloaded by the editor. Must run before any draw.
	RenderingServer.set_default_clear_color(Color(0.18, 0.40, 0.10))  ## Dark grass green
	_setup_gameplay_nodes()  ## background added first — arrows must come after
	_setup_arrow_pool()      ## arrows added after background to render on top
	_setup_ui()
	_wire_signals()
	_show_main_menu()

## Show the main menu CanvasLayer. Hides the HUD until player starts.
func _show_main_menu() -> void:
	if _hud != null:
		_hud.visible = false
	var menu_script: GDScript = load("res://src/ui/main_menu.gd")
	_main_menu = CanvasLayer.new()
	_main_menu.set_script(menu_script)
	add_child(_main_menu)
	_main_menu.play_pressed.connect(_on_menu_play)
	_main_menu.continue_pressed.connect(_on_menu_continue)

## New game: full reset then start.
func _on_menu_play() -> void:
	_main_menu = null
	ResourceInventory._on_session_reset()
	if _hud != null:
		_hud.visible = true
	## Apply hero speed bonus from progression.
	_apply_hero_progression_bonuses()

## Continue: restore from HeroProgression save (already loaded in _ready()).
func _on_menu_continue() -> void:
	_main_menu = null
	if _hud != null:
		_hud.visible = true
	_apply_hero_progression_bonuses()

## Apply persistent hero progression bonuses to gameplay nodes.
func _apply_hero_progression_bonuses() -> void:
	if HeroProgression == null or _hero == null:
		return
	## Speed bonus — level progression + prestige bonus (stacks additively).
	var speed_bonus: float = HeroProgression.get_speed_bonus()
	if PrestigeSystem != null:
		speed_bonus += PrestigeSystem.get_hero_speed_bonus()
	if _hero.get("_speed_bonus") != null:
		_hero.set("_speed_bonus", speed_bonus)
	## Collect radius bonus applied when exploration map is built.

## --- Setup ---

func _setup_arrow_pool() -> void:
	_arrow_pool = ObjectPool.new()
	var arrow_script := load("res://src/gameplay/arrow.gd")
	for i in range(ARROW_POOL_SIZE):
		var a: Area2D = Area2D.new()
		a.set_script(arrow_script)
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		a.add_child(col)
		$GameWorld.add_child(a)
		_arrow_pool._available.append(a)

func _setup_gameplay_nodes() -> void:
	var game_world: Node2D = $GameWorld
	game_world.y_sort_enabled = true

	## Background: handled by project.godot default_clear_color = Color(0.18, 0.40, 0.10).
	## CanvasLayer layer=-1 does NOT render in Godot 4 (bug #67633) — removed.
	## Polygon2D also broken with gl_compatibility (bug #69109) — not used.

	# Decorative trees and rocks — scattered along top/bottom edges of 1920×1080 world
	_add_decor(game_world, Vector2(120.0, 180.0),  "tree_lg.png", 0.80)
	_add_decor(game_world, Vector2(120.0, 900.0),  "tree_sm.png", 0.70)
	_add_decor(game_world, Vector2(420.0, 100.0),  "tree_sm.png", 0.70)
	_add_decor(game_world, Vector2(420.0, 980.0),  "rock.png",    0.90)
	_add_decor(game_world, Vector2(900.0, 130.0),  "tree_lg.png", 0.75)
	_add_decor(game_world, Vector2(900.0, 950.0),  "tree_sm.png", 0.65)
	_add_decor(game_world, Vector2(1600.0, 200.0), "rock.png",    0.80)
	_add_decor(game_world, Vector2(1600.0, 870.0), "tree_sm.png", 0.70)

	# Barracks — decorative, near castle left-center of world
	var barracks_node := Node2D.new()
	barracks_node.position = Vector2(200.0, 340.0)
	game_world.add_child(barracks_node)
	var barracks_shadow := Sprite2D.new()
	barracks_shadow.texture = load("res://assets/sprites/garrison/shadow.png")
	barracks_shadow.position = Vector2(0.0, 42.0)
	barracks_shadow.scale = Vector2(2.5, 2.5)
	barracks_node.add_child(barracks_shadow)
	var barracks_spr := Sprite2D.new()
	barracks_spr.texture = load("res://assets/sprites/garrison/barracks.png")
	barracks_spr.scale = Vector2(0.90, 0.90)
	barracks_node.add_child(barracks_spr)

	# Hero
	_hero = Node2D.new()
	_hero.set_script(load("res://src/gameplay/hero.gd"))
	game_world.add_child(_hero)

	# Castle
	_castle = Node2D.new()
	_castle.set_script(load("res://src/gameplay/castle.gd"))
	game_world.add_child(_castle)

	# Enemy Wave
	_enemy_wave = Node.new()
	_enemy_wave.set_script(load("res://src/gameplay/enemy_wave.gd"))
	game_world.add_child(_enemy_wave)

	# Economy
	_economy = Node.new()
	_economy.set_script(load("res://src/gameplay/economy.gd"))
	_economy._hero = _hero
	game_world.add_child(_economy)
	_enemy_wave._economy = _economy
	_enemy_wave._castle = _castle

	# Archer Formation
	_archer_formation = Node2D.new()
	_archer_formation.set_script(load("res://src/gameplay/archer_formation.gd"))
	game_world.add_child(_archer_formation)

	# Forge — session-scoped stat upgrade system (Sprint 6, Alpha tier)
	_forge = Node.new()
	_forge.set_script(load("res://src/gameplay/forge.gd"))
	game_world.add_child(_forge)

	# Inject Forge reference into Economy (ArcherFormation gets it via setup() in _wire_signals)
	_economy._forge = _forge

	# Hero Spells — standalone Node, uses group "enemies" so it works in TD and RPG modes
	_hero_spells = Node.new()
	_hero_spells.set_script(load("res://src/gameplay/hero_spells.gd"))
	game_world.add_child(_hero_spells)

	# Spell Upgrade Tree — persiste entre les explorations, injectable dans HeroSpells
	_spell_upgrade_tree = Node.new()
	_spell_upgrade_tree.set_script(load("res://src/gameplay/spell_upgrade_tree.gd"))
	game_world.add_child(_spell_upgrade_tree)
	_hero_spells.set_upgrade_tree(_spell_upgrade_tree)

	# Mount System — persiste, gère la vitesse et le sprite du héros en exploration
	_mount_system = Node.new()
	_mount_system.set_script(load("res://src/gameplay/mount.gd"))
	game_world.add_child(_mount_system)

	# Camera follow
	_camera_follow = Node.new()
	_camera_follow.set_script(load("res://src/gameplay/camera_follow.gd"))
	add_child(_camera_follow)

## Add a decorative static sprite at world pos. Silently skipped if texture not yet imported.
func _add_decor(parent: Node2D, pos: Vector2, spr_name: String, spr_scale: float) -> void:
	var tex: Texture2D = load("res://assets/sprites/garrison/" + spr_name)
	if tex == null:
		return
	var d := Sprite2D.new()
	d.texture = tex
	d.position = pos
	d.scale = Vector2(spr_scale, spr_scale)
	parent.add_child(d)

func _setup_ui() -> void:
	## HUD — landscape top bar (960×60): [HP bar | HP val] [Wave] [Archers N/8] [Gold]
	_hud = $HUDLayer/HUD
	_hud.set_script(load("res://src/ui/hud.gd"))

	var hud_strip := ColorRect.new()
	hud_strip.size = Vector2(960.0, 60.0)
	hud_strip.color = Color(0.0, 0.0, 0.0, 0.7)
	_hud.add_child(hud_strip)

	var castle_bar := ProgressBar.new()
	castle_bar.position = Vector2(12.0, 18.0)
	castle_bar.size = Vector2(200.0, 24.0)
	castle_bar.show_percentage = false
	_hud.add_child(castle_bar)

	var castle_hp_label := Label.new()
	castle_hp_label.position = Vector2(218.0, 14.0)
	castle_hp_label.text = "200"
	_hud.add_child(castle_hp_label)

	var wave_label := Label.new()
	wave_label.position = Vector2(390.0, 14.0)
	wave_label.text = "Vague 1"
	_hud.add_child(wave_label)

	var archer_badge := Label.new()
	archer_badge.position = Vector2(680.0, 14.0)
	archer_badge.text = "2/8"
	_hud.add_child(archer_badge)

	var gold_label := Label.new()
	gold_label.position = Vector2(820.0, 14.0)
	gold_label.text = "60g"
	_hud.add_child(gold_label)

	_hud.setup(gold_label, castle_bar, castle_hp_label, wave_label, archer_badge, hud_strip)
	## Action buttons — built programmatically onto HUDLayer (landscape bottom-right)
	_hud.build_action_buttons($HUDLayer)
	## Spell buttons — MOBA diagonal arc, bottom-center zone
	_hud.build_spell_buttons($HUDLayer)
	## Start Wave button — shown between waves, hidden while wave is active
	_hud.build_start_wave_button($HUDLayer)
	## Meta buttons — pause, speed, mode label, streak/enemy count labels, announce overlay
	_hud.build_meta_buttons($HUDLayer)
	## RPG mode HUD — top bar shown while EXPLORING, hidden in TD mode
	_hud.build_rpg_elements($HUDLayer)
	## Wire proximity interact button — calls _on_interact_pressed when tapped
	_hud.interact_pressed.connect(_on_interact_pressed)
	## HUDLayer always processes so pause button remains clickable while game is paused
	$HUDLayer.process_mode = Node.PROCESS_MODE_ALWAYS

	## GameOverOverlay — dark panel with stats + tap-to-restart (landscape 960×540)
	_game_over_overlay = $HUDLayer/GameOverOverlay
	_game_over_overlay.set_script(load("res://src/ui/game_over_overlay.gd"))

	var dark_bg := ColorRect.new()
	dark_bg.size = Vector2(960.0, 540.0)
	dark_bg.color = Color(0.0, 0.0, 0.0, 0.65)
	_game_over_overlay.add_child(dark_bg)

	var panel := Control.new()
	panel.position = Vector2(220.0, 130.0)
	panel.size = Vector2(520.0, 260.0)
	_game_over_overlay.add_child(panel)

	var go_wave_label := Label.new()
	go_wave_label.position = Vector2(20.0, 30.0)
	go_wave_label.text = "Wave reached: —"
	panel.add_child(go_wave_label)

	var kills_label := Label.new()
	kills_label.position = Vector2(20.0, 80.0)
	kills_label.text = "Enemies defeated: —"
	panel.add_child(kills_label)

	var restart_label := Label.new()
	restart_label.position = Vector2(20.0, 170.0)
	restart_label.text = "TAP ANYWHERE TO RESTART"
	panel.add_child(restart_label)

	_game_over_overlay.setup(panel, go_wave_label, kills_label, restart_label, _enemy_wave)

	## Joystick visual — bottom-left viewport area (landscape: x<480, y>270)
	_joy_base = Sprite2D.new()
	_joy_base.texture = load("res://assets/sprites/garrison/joystick_base.png")
	_joy_base.position = Vector2(110.0, 430.0)
	$HUDLayer.add_child(_joy_base)

	_joy_knob = Sprite2D.new()
	_joy_knob.texture = load("res://assets/sprites/garrison/joystick_knob.png")
	_joy_knob.position = Vector2(110.0, 430.0)
	$HUDLayer.add_child(_joy_knob)

	## Phase 2 — explore button: bottom-left corner, near where the castle appears visually.
	## Only visible between waves once the player has at least 1 tower.
	## Explore / Return — top-right corner, below the HUD bar (y=68), away from joystick.
	## EXPLORER visible between waves (TD mode); RETOUR visible while EXPLORING.
	## Both occupy the same slot — only one is shown at a time.
	_explore_btn = Button.new()
	_explore_btn.text = "EXPLORER"
	_explore_btn.position = Vector2(818.0, 68.0)
	_explore_btn.size = Vector2(134.0, 40.0)
	_explore_btn.visible = false
	$HUDLayer.add_child(_explore_btn)

	_return_btn = Button.new()
	_return_btn.text = " RETOUR"
	_return_btn.position = Vector2(810.0, 65.0)
	_return_btn.size = Vector2(142.0, 46.0)
	_return_btn.visible = false
	## Style castle-themed — fond brun, coins arrondis.
	var return_style: StyleBoxFlat = StyleBoxFlat.new()
	return_style.bg_color = Color("#5D4037")
	return_style.corner_radius_top_left = 6
	return_style.corner_radius_top_right = 6
	return_style.corner_radius_bottom_left = 6
	return_style.corner_radius_bottom_right = 6
	_return_btn.add_theme_stylebox_override("normal", return_style)
	var return_hover: StyleBoxFlat = StyleBoxFlat.new()
	return_hover.bg_color = Color("#795548")
	return_hover.corner_radius_top_left = 6
	return_hover.corner_radius_top_right = 6
	return_hover.corner_radius_bottom_left = 6
	return_hover.corner_radius_bottom_right = 6
	_return_btn.add_theme_stylebox_override("hover", return_hover)
	_return_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_return_btn.add_theme_font_size_override("font_size", 15)
	## Icone chateau a gauche du texte.
	var castle_tex: Texture2D = load("res://assets/sprites/garrison/castle_icon.png")
	if castle_tex != null:
		_return_btn.icon = castle_tex
		_return_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUDLayer.add_child(_return_btn)

	## Weather overlay — full viewport, mouse-transparent, beneath HUD (z_index=-2)
	var weather_overlay := ColorRect.new()
	weather_overlay.size = Vector2(960.0, 540.0)
	weather_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	weather_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_overlay.z_index = -2
	$HUDLayer.add_child(weather_overlay)
	if WeatherManager != null and WeatherManager.has_method("set_weather_overlay"):
		WeatherManager.set_weather_overlay(weather_overlay)

	## Season overlay — full viewport, mouse-transparent, beneath HUD (z_index=-3)
	var season_overlay := ColorRect.new()
	season_overlay.size = Vector2(960.0, 540.0)
	season_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	season_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	season_overlay.z_index = -3
	$HUDLayer.add_child(season_overlay)
	if SeasonManager != null and SeasonManager.has_method("set_season_overlay"):
		SeasonManager.set_season_overlay(season_overlay)

	## Fade rect — full viewport, always on top, starts transparent
	_fade_rect = ColorRect.new()
	_fade_rect.size = Vector2(960.0, 540.0)
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.z_index = 10
	$HUDLayer.add_child(_fade_rect)

	## Phase 4 — Consumable quick-use buttons (4 items, right side, only while EXPLORING).
	## Resources, hero HP, XP, and camp progress are shown in the RPG HUD bar (build_rpg_elements).
	## IDs 23-26: Health Potion, Méga-potion, Speed Elixir, Smoke Bomb.
	const CONSUMABLE_IDS: Array[int] = [
		ItemInventory.Item.HEALTH_POTION,
		ItemInventory.Item.MEGA_POTION,
		ItemInventory.Item.SPEED_ELIXIR,
		ItemInventory.Item.SMOKE_BOMB,
	]
	const CONSUMABLE_SHORT: Array[String] = ["Pot.", "Méga", "Élix.", "Fum."]
	for ci: int in range(CONSUMABLE_IDS.size()):
		var cbtn := Button.new()
		cbtn.text = CONSUMABLE_SHORT[ci] + " ×0"
		## Small icon row just below the RPG top bar (y=62), 4 buttons × 50px, gap 4px
		cbtn.position = Vector2(352.0 + float(ci) * 54.0, 62.0)
		cbtn.size = Vector2(50.0, 28.0)
		cbtn.add_theme_font_size_override("font_size", 10)
		cbtn.visible = false
		cbtn.disabled = true
		## Store item_id in metadata for the signal handler
		cbtn.set_meta("consumable_id", CONSUMABLE_IDS[ci])
		var _ci_cap := ci
		cbtn.pressed.connect(func() -> void: _on_use_consumable(CONSUMABLE_IDS[_ci_cap]))
		$HUDLayer.add_child(cbtn)
		_expl_consumable_btns.append(cbtn)

	## RPG HUD Overlay — XP bar, phase label, challenge dots, prestige title
	_rpg_hud_overlay = CanvasLayer.new()
	_rpg_hud_overlay.set_script(load("res://src/ui/rpg_hud_overlay.gd"))
	add_child(_rpg_hud_overlay)

	## Skill Tree Panel — layer=20, touch-based skill purchase
	_skill_tree_panel = CanvasLayer.new()
	_skill_tree_panel.set_script(load("res://src/ui/skill_tree_panel.gd"))
	add_child(_skill_tree_panel)

	## Journal Panel — layer=15, 4-tab quest/codex/mystery/daily journal
	_journal_panel = CanvasLayer.new()
	_journal_panel.set_script(load("res://src/ui/journal_panel.gd"))
	add_child(_journal_panel)

	## Day/Night Cycle — 8-minute real-time cycle, overlay tint on CanvasLayer
	_day_night_cycle = Node.new()
	_day_night_cycle.set_script(load("res://src/gameplay/day_night_cycle.gd"))
	add_child(_day_night_cycle)

	## Journal open button — shown in RPG bar at top-right while EXPLORING
	var journal_btn := Button.new()
	journal_btn.text = "Journal"
	journal_btn.position = Vector2(4.0, 68.0)
	journal_btn.size = Vector2(90.0, 36.0)
	journal_btn.visible = false
	journal_btn.add_theme_font_size_override("font_size", 11)
	journal_btn.set_meta("journal_btn", true)
	journal_btn.pressed.connect(func() -> void:
		if _journal_panel != null:
			_journal_panel.show_panel(0))
	$HUDLayer.add_child(journal_btn)

	## Skill Tree open button — shown in RPG bar while EXPLORING
	var skills_btn := Button.new()
	skills_btn.text = "Talents"
	skills_btn.position = Vector2(100.0, 68.0)
	skills_btn.size = Vector2(90.0, 36.0)
	skills_btn.visible = false
	skills_btn.add_theme_font_size_override("font_size", 11)
	skills_btn.set_meta("skills_btn", true)
	skills_btn.pressed.connect(func() -> void:
		if _skill_tree_panel != null:
			_skill_tree_panel.show_panel())
	$HUDLayer.add_child(skills_btn)

func _wire_signals() -> void:
	# Castle signals → GSM and HUD
	_castle.castle_fell.connect(GameStateMachine.request_game_over)
	## Screen shake on castle hit (not regen) — intensity 7px, 0.3s
	_castle.castle_hit.connect(func() -> void:
		if _camera_follow != null and _camera_follow.has_method("shake"):
			_camera_follow.shake(7.0, 0.30))

	# Economy → ArcherFormation sync
	_economy.recruit_purchased.connect(_on_recruit_purchased)
	_economy.tower_purchased.connect(_on_tower_purchased)

	# Camera follow setup (after hero is added)
	_camera_follow.setup($Camera2D, _hero)

	# ArcherFormation setup (Forge ref already injected in _setup_gameplay_nodes)
	_archer_formation.setup(_hero, _enemy_wave, _arrow_pool, _forge)

	# HUD signal connections
	_castle.hp_changed.connect(_hud._on_hp_changed)
	_economy.gold_changed.connect(_hud._on_gold_changed)
	_enemy_wave.wave_started.connect(_hud._on_wave_started)
	_enemy_wave.wave_cleared.connect(_hud._on_wave_cleared)
	## Visual tier upgrade — update hero and castle sprites when wave thresholds are crossed.
	_enemy_wave.wave_started.connect(_on_wave_visual_tier_update)
	_economy.recruit_purchased.connect(_hud._on_recruit_purchased)
	_archer_formation.formation_full.connect(_hud._on_formation_full)

	# Castle max HP → HUD bar scaling
	_castle.max_hp_changed.connect(_hud._on_castle_max_hp_changed)

	# Enemy wave count and remaining counters → HUD labels
	_enemy_wave.wave_enemy_count.connect(_hud._on_wave_enemy_count)
	_enemy_wave.enemies_remaining.connect(_hud._on_enemies_remaining)

	# Targeting and formation mode changes → HUD mode label
	_archer_formation.targeting_mode_changed.connect(_hud._on_targeting_mode_changed)
	_archer_formation.formation_mode_changed.connect(_hud._on_formation_mode_changed)

	# Momentum streak tier → HUD streak label
	_archer_formation.streak_tier_changed.connect(_hud._on_streak_tier_changed)

	# Wave upkeep deduction → HUD popup
	_economy.upkeep_deducted.connect(_hud.show_upkeep_popup)

	# Forge purchases → HUD level counters
	_economy.forge_dmg_purchased.connect(_hud._on_forge_dmg_purchased)
	_economy.forge_spd_purchased.connect(_hud._on_forge_spd_purchased)
	_economy.forge_mag_purchased.connect(_hud._on_forge_mag_purchased)
	_economy.forge_hp_purchased.connect(_hud._on_forge_hp_purchased)

	# Sprint 5 — Momentum: per-kill tracking and streak gold bonus
	_enemy_wave.enemy_killed.connect(_archer_formation.on_enemy_killed)
	_archer_formation.streak_gold_bonus.connect(_economy.add_gold)
	## P3 — Enemy death VFX: burst particle at kill position
	_enemy_wave.enemy_killed.connect(_spawn_death_vfx)

	# Sprint 5 — Wave upkeep deducted at wave end
	_enemy_wave.wave_cleared.connect(_economy._on_wave_cleared)
	_enemy_wave.wave_cleared.connect(_archer_formation._on_wave_cleared)

	# Landscape Sprint 7 — HUD action buttons → Economy and ArcherFormation
	_hud.recruit_pressed.connect(func() -> void: _economy.try_recruit())
	_hud.tower_pressed.connect(func() -> void: _economy.try_purchase_tower())
	_hud.target_pressed.connect(_archer_formation.cycle_targeting_mode)
	_hud.formation_pressed.connect(_archer_formation.cycle_formation_mode)
	_hud.forge_dmg_pressed.connect(func() -> void: _economy.try_forge_dmg())
	_hud.forge_spd_pressed.connect(func() -> void: _economy.try_forge_spd())
	_hud.forge_mag_pressed.connect(func() -> void: _economy.try_forge_mag())
	_hud.forge_hp_pressed.connect(func() -> void: _economy.try_forge_hp())

	# Tower power selection — HUD signals to _apply_tower_power (pays 150g unless POWER_CORE)
	_hud.power_fire_pressed.connect(func(t: Node) -> void: _apply_tower_power(t, 1))
	_hud.power_lightning_pressed.connect(func(t: Node) -> void: _apply_tower_power(t, 2))
	_hud.power_water_pressed.connect(func(t: Node) -> void: _apply_tower_power(t, 3))
	# Tower tier upgrade — HUD tier_upgrade_pressed → _apply_tower_tier_upgrade
	_hud.tier_upgrade_pressed.connect(_apply_tower_tier_upgrade)

	# Sprint 6 — Forge zone purchases → Forge stat increments
	_economy.forge_dmg_purchased.connect(_forge.on_dmg_purchased)
	_economy.forge_spd_purchased.connect(_forge.on_spd_purchased)
	_economy.forge_mag_purchased.connect(_forge.on_mag_purchased)
	_economy.forge_hp_purchased.connect(_forge.on_hp_purchased)
	# HP purchase also increases castle max HP directly (GDD forge.md F4)
	_economy.forge_hp_purchased.connect(_on_forge_hp_purchased)
	# Inject Forge reference into HUD so labels can display effective stat values
	_hud._forge_ref = _forge
	_forge.forge_stat_changed.connect(_hud._refresh_forge_labels)
	# Populate initial labels (base values shown before any purchase)
	_hud._refresh_forge_labels()

	# Sprint 7 — Spell system: HUD shows cooldowns, routes press to hero_spells.cast()
	_hud.set_hero_spells(_hero_spells)
	_hud.spell_pressed.connect(func(idx: int) -> void: _hero_spells.cast(idx, _hero.global_position))
	# Spell VFX — spawn expanding ring at impact position
	_hero_spells.spell_impact.connect(_spawn_spell_vfx)
	# Spell upgrade tree — HUD button opens the upgrade panel (EXPLORING mode only)
	_hud.spell_upgrades_requested.connect(_show_spell_upgrade_panel)

	# Wave start button — shown after wave_cleared, hidden when wave_started fires.
	# Guard: do not show during EXPLORING — the assault wave clears silently.
	_enemy_wave.wave_start_ready.connect(func() -> void:
		if GameStateMachine.current_state == GameStateMachine.State.PLAYING:
			var preview: Dictionary = _enemy_wave.get_next_wave_preview()
			_hud.show_start_wave_btn(preview))
	_hud.start_wave_pressed.connect(_enemy_wave.start_next_wave)
	_enemy_wave.wave_started.connect(func(_n: int) -> void: _hud.hide_start_wave_btn())

	# Phase 2 — Exploration portal / return buttons
	_explore_btn.pressed.connect(_do_explore)
	_return_btn.pressed.connect(_do_return)

	# Phase 3 — Hero HP label updates
	_hero.hp_changed.connect(_on_hero_hp_changed)
	_hero.died_in_exploration.connect(_do_return)
	_hero.xp_changed.connect(_on_hero_xp_changed)

	# Phase 3 — Resource label updates
	ResourceInventory.resource_changed.connect(func(_t: int, _c: int) -> void: _refresh_resource_lbl())
	# Notify QuestManager of resource collection for codex / NPC chain tracking
	ResourceInventory.resource_changed.connect(func(res_type: int, count: int) -> void:
		if QuestManager != null and count > 0:
			QuestManager.on_resource_collected(res_type, count))

	# Phase 4 — Consumable count updates and equipment effect application
	ItemInventory.consumable_used.connect(func(_id: int, _rem: int) -> void: _refresh_consumable_btns())
	## item_crafted: refresh buttons AND apply immediate hero/equipment effects
	ItemInventory.item_crafted.connect(_on_item_crafted)

	# RPG overlay — pass system references (overlay self-connects in _connect_systems)
	if _rpg_hud_overlay != null:
		if _rpg_hud_overlay.has_method("set_day_night_system"):
			_rpg_hud_overlay.set_day_night_system(_day_night_cycle)

	# QuestManager notification → RPG overlay toast
	if QuestManager != null and _rpg_hud_overlay != null:
		QuestManager.quest_notification.connect(
			func(title: String, desc: String) -> void:
				_rpg_hud_overlay.queue_toast({
					"text": title, "subtitle": desc, "color": Color(0.9, 0.8, 0.4), "rarity": 0
				}))
	# QuestManager chapter completed → apply permanent TD reward
	if QuestManager != null:
		QuestManager.quest_chapter_completed.connect(_on_quest_chapter_completed)
	# QuestManager NPC step completed → apply NPC chain reward
	if QuestManager != null:
		QuestManager.npc_step_completed.connect(_on_npc_step_reward)

	# DailyChallenge — progress wiring (all event sources → DailyChallenge singleton).
	## Resources collected (any type, any amount).
	ResourceInventory.resource_changed.connect(func(res_type: int, count: int) -> void:
		if count > 0 and DailyChallenge != null:
			DailyChallenge.on_resource_collected(res_type, count))
	## Gold spent on upgrades/purchases.
	_economy.gold_spent.connect(func(amount: int) -> void:
		if DailyChallenge != null:
			DailyChallenge.on_gold_spent(amount))
	## XP gained by hero (fires on every add_xp call — amount is the effective value).
	if HeroProgression != null:
		HeroProgression.xp_gained.connect(func(amount: int, _total: int) -> void:
			if DailyChallenge != null:
				DailyChallenge.on_xp_gained(amount))
		## Cave / shrine discovery → DailyChallenge DISCOVER_CAVE progress.
		HeroProgression.discovery_registered.connect(func(_total: int) -> void:
			if DailyChallenge != null:
				DailyChallenge.on_cave_discovered())
	## Wave survived (fires each time a wave is fully cleared).
	_enemy_wave.wave_cleared.connect(func() -> void:
		if DailyChallenge != null:
			DailyChallenge.on_wave_survived()
		## XP reward to hero for surviving a wave — scales gently with wave number.
		if HeroProgression != null:
			var xp_gain: int = 10 + _enemy_wave.current_wave * 2
			HeroProgression.add_xp(xp_gain))
	## Contract fulfilled — wired lazily in _do_explore() once the board node exists.
	## DailyChallenge UI — show toast on completion events.
	if DailyChallenge != null:
		DailyChallenge.challenge_completed.connect(func(idx: int) -> void:
			var chal: Dictionary = DailyChallenge.get_challenges()[idx]
			if _rpg_hud_overlay != null and _rpg_hud_overlay.has_method("queue_toast"):
				_rpg_hud_overlay.queue_toast({
					"text": "Défi accompli !", "subtitle": chal.get("name", ""),
					"color": Color(0.95, 0.80, 0.20), "rarity": 1
				}))
		DailyChallenge.all_challenges_completed.connect(func(bonus_xp: int) -> void:
			if _rpg_hud_overlay != null and _rpg_hud_overlay.has_method("queue_toast"):
				_rpg_hud_overlay.queue_toast({
					"text": "Tous les défis du jour !", "subtitle": "+%d XP bonus (série +%d%%)" % [bonus_xp, DailyChallenge.get_streak_bonus_pct()],
					"color": Color(0.40, 1.00, 0.55), "rarity": 2
				}))
		DailyChallenge.streak_updated.connect(func(new_streak: int) -> void:
			if new_streak > 1 and _rpg_hud_overlay != null and _rpg_hud_overlay.has_method("queue_toast"):
				_rpg_hud_overlay.queue_toast({
					"text": "Série quotidienne ×%d" % new_streak,
					"subtitle": "+%d%% bonus XP actif" % DailyChallenge.get_streak_bonus_pct(),
					"color": Color(1.00, 0.55, 0.20), "rarity": 1
				}))

	# PrestigeSystem — re-apply hero speed bonus immediately after prestige resets the level.
	if PrestigeSystem != null:
		PrestigeSystem.prestige_gained.connect(func(_new_level: int, _title: String) -> void:
			_apply_hero_progression_bonuses())

	## Prestige available notification — show toast when hero reaches level 50.
	HeroProgression.level_up.connect(func(new_level: int) -> void:
		if new_level >= HeroProgression.MAX_LEVEL and PrestigeSystem != null and PrestigeSystem.can_prestige():
			if _rpg_hud_overlay != null and _rpg_hud_overlay.has_method("queue_toast"):
				_rpg_hud_overlay.queue_toast({
					"text": "Niveau maximum !",
					"subtitle": "Prestige disponible dans l'Arbre de Compétences",
					"color": Color(1.0, 0.75, 0.05),
					"rarity": 2,
				}))

	# Day/Night cycle — star_dust_spawn_requested → ExplorationMap (wired in _do_explore)
	## Weather changes → AudioManager (WeatherManager.weather_changed handled internally)

	# Toggle Journal and Talent buttons with EXPLORING state
	GameStateMachine.game_state_changed.connect(_on_rpg_btn_state_changed)

	# Mount system — wire HUD button to mount handler and sync mount button label
	_hud.mount_pressed.connect(_on_mount_pressed)
	if _mount_system != null:
		_mount_system.mounted_changed.connect(func(v: bool) -> void: _hud.update_mount_btn(v))
		GameStateMachine.session_reset.connect(func() -> void: _mount_system.reset())

	# Re-apply all earned quest/NPC rewards from previous sessions.
	# Must run AFTER all signal connections above are established.
	if QuestManager != null:
		QuestManager.replay_completed_rewards()

	# Push initial values to HUD
	_hud._on_gold_changed(_economy.current_gold)
	_hud._on_hp_changed(_castle.castle_hp)

## Called on wave_started — updates hero visual tier when wave crosses a threshold.
## wave_num is 1-indexed from EnemyWave.wave_started signal.
func _on_wave_visual_tier_update(wave_num: int) -> void:
	var vtier: int = 0
	if wave_num >= 50: vtier = 3
	elif wave_num >= 25: vtier = 2
	elif wave_num >= 10: vtier = 1
	if _hero != null and _hero.has_method("set_visual_tier"):
		_hero.set_visual_tier(vtier)
	if _castle != null and _castle.has_method("set_visual_tier"):
		_castle.set_visual_tier(vtier)

func _on_recruit_purchased() -> void:
	_archer_formation.on_recruit_purchased()
	_economy.set_archer_count(_archer_formation.current_archer_count)
	## Achievement: check max garrison
	AchievementSystem.on_max_garrison_deployed(
		_archer_formation.current_archer_count, _towers.size())

func _on_tower_purchased() -> void:
	if _towers.size() >= _tower_slot_limit:
		return
	var tower: Node2D = Node2D.new()
	tower.set_script(load("res://src/gameplay/archer_tower.gd"))
	tower.position = TOWER_POSITIONS[_towers.size()]
	tower.setup(_arrow_pool, _enemy_wave, _forge)
	## Wire power / tier-upgrade request — shows the combined options panel
	tower.power_requested.connect(_on_tower_power_requested.bind(tower))
	$GameWorld.add_child(tower)
	_towers.append(tower)
	## Tower delivers its own archers — formation is NOT depleted
	## Achievement: check max garrison after adding tower
	AchievementSystem.on_max_garrison_deployed(
		_archer_formation.current_archer_count, _towers.size())

## Called when a tower is tapped — open the combined options panel (power + tier upgrade).
func _on_tower_power_requested(tower: Node2D) -> void:
	_hud.show_power_panel(tower)

## Apply a Fire/Lightning/Water power to a tower if the player can afford it.
## POWER_CORE item makes powers free.
func _apply_tower_power(tower: Node, power_type: int) -> void:
	var cost: int = 0 if tower.has_method("is_power_free") and tower.is_power_free() else 150
	if cost == 0 or _economy.spend_gold(cost):
		tower.set_power(power_type)

## Apply a tier upgrade to a tower after spending the required gold.
func _apply_tower_tier_upgrade(tower: Node, new_tier: int) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var cost: int = tower.get_next_tier_cost()
	if cost > 0 and _economy.spend_gold(cost):
		tower.upgrade_to_tier(new_tier)

## Apply item effects to all existing towers (called from _apply_crafted_item_effects).
func _apply_tower_item_effects() -> void:
	for tower: Node2D in _towers:
		if not tower.has_method("apply_item"):
			continue
		for item_id: int in [14, 15, 16, 17, 18]:  ## BALLISTA_KIT … REINFORCED_PLATFORM
			if ItemInventory.has_item(item_id):
				tower.apply_item(item_id)

## Called whenever an item is crafted. Applies immediate effects during EXPLORING.
## TD-side effects (archers, castle, towers) are applied on _do_return() instead.
func _on_item_crafted(item_id: int) -> void:
	_refresh_consumable_btns()
	if GameStateMachine.current_state == GameStateMachine.State.EXPLORING:
		match item_id:
			ItemInventory.Item.BONE_BOW:
				_hero.set("_atk_range_bonus", 70.0)
			ItemInventory.Item.CRYSTAL_STAFF:
				_hero.set("_spell_dmg_mult", 1.30)
			ItemInventory.Item.HIDE_JERKIN:
				_hero.heal(20)
			ItemInventory.Item.CRYSTAL_AMULET:
				_hero.set("_regen_rate", 1.0)
			ItemInventory.Item.SHADOW_MAIL:
				_hero.set("_dmg_reduction", 0.40)
			ItemInventory.Item.SILK_CLOAK:
				_hero.set("_stealth", 0.65)
	## Refresh equipment display in RPG overlay
	if _rpg_hud_overlay != null and _rpg_hud_overlay.has_method("refresh_equipment"):
		_rpg_hud_overlay.refresh_equipment()
	## DailyChallenge — craft item progress
	if DailyChallenge != null:
		DailyChallenge.on_item_crafted()

## Called when forge_hp_purchased fires — increases castle max HP per GDD forge.md F4.
func _on_forge_hp_purchased() -> void:
	_castle.increase_max_hp(30)

## Update joystick knob and exploration button visibility each frame.
func _process(_delta: float) -> void:
	## Joystick knob tracking
	if _joy_knob != null and _hero != null:
		var joy_anchor := Vector2(110.0, 430.0)
		var joy_radius := 80.0
		if _hero._joy_active and _hero._joy_direction.length() > 0.01:
			_joy_knob.position = joy_anchor + _hero._joy_direction * joy_radius
		else:
			_joy_knob.position = joy_anchor

	## Portal button — shown only between waves AND when ≥1 tower exists
	if _explore_btn != null:
		_explore_btn.visible = (
			GameStateMachine.current_state == GameStateMachine.State.PLAYING and
			_enemy_wave._waiting_for_next_wave and
			_towers.size() >= 1
		)

	## Return button — shown only while EXPLORING
	var is_exploring: bool = (GameStateMachine.current_state == GameStateMachine.State.EXPLORING)
	if _return_btn != null:
		_return_btn.visible = is_exploring

	## Consumable quick-use buttons — only visible while EXPLORING
	for cbtn: Button in _expl_consumable_btns:
		cbtn.visible = is_exploring

	## Proximity interact button — scan nearest interactable each frame while EXPLORING
	if is_exploring and _hero != null and not _expl_interactables.is_empty():
		_update_interact_proximity()
	elif not is_exploring and _expl_nearest != null:
		_expl_nearest = null
		_hud.hide_interact_btn()

## Fade to black → enter EXPLORING → reparent hero into exploration world → fade in.
func _do_explore() -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return   ## Guard against double-tap
	_hero_td_pos = _hero.position
	_refresh_resource_lbl()
	_on_hero_hp_changed(_hero.hp)
	_on_hero_xp_changed(_hero._xp, _hero._xp_level)
	_refresh_consumable_btns()
	_expl_camps_cleared = 0
	_hud.update_rpg_camps(0)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		## Always restore hero HP on exploration entry (hero rested at the castle).
		## Prevents 0-HP instant-death bug if the hero died in the previous expedition.
		_hero.hp = _hero.HERO_MAX_HP
		_hero._dying = false
		_hero.hp_changed.emit(_hero.hp)
		GameStateMachine.request_explore()
		$GameWorld.visible = false
		## Build exploration world and reparent hero into it
		_expl_root = Node2D.new()
		_expl_root.set_script(load("res://src/scenes/exploration_map.gd"))
		add_child(_expl_root)
		_expl_root.init(_hero)
		_expl_root.build_map()
		## Populate interactable list for proximity detection
		_expl_interactables = _expl_root.get_interactables()
		## Wire camp gold rewards to Economy
		_expl_root.gold_earned.connect(func(g: int) -> void: _economy.add_gold(g))
		## Wire camp cleared → progress counter
		_expl_root.camp_cleared.connect(_on_camp_cleared)
		## Wire contract_board contract_fulfilled → DailyChallenge (board is fresh each exploration trip).
		if DailyChallenge != null:
			var board_node: Node = get_tree().get_first_node_in_group("contract_board")
			if board_node != null:
				board_node.contract_fulfilled.connect(func(_idx: int, _gold: int, _xp: int) -> void:
					DailyChallenge.on_contract_completed())
		## Wire zone blessings → floating notification label
		_expl_root.blessing_granted.connect(_on_blessing_granted)
		## Wire dynamic event banners → HUD
		_expl_root.event_banner_requested.connect(_on_event_banner_requested)
		## Wire dungeon entries → open DungeonFloor overlay
		_expl_root.dungeon_entered.connect(_on_dungeon_entered)
		## Wire world boss phase 2 → EnemyWave assault on the castle.
		## The castle takes real damage during exploration — multi-front battle.
		_expl_root.boss_phase2_triggered.connect(_on_boss_phase2)
		## Notify WorldStateManager of zone visit for FLOURISHING progression
		if WorldStateManager != null:
			var zone_idx: int = _expl_root.current_zone_idx if _expl_root != null else 0
			WorldStateManager.on_zone_visited(zone_idx)
		## Notify QuestManager of zone entry
		if QuestManager != null and QuestManager.has_method("on_zone_entered"):
			var zone_idx2: int = _expl_root.current_zone_idx if _expl_root != null else 0
			QuestManager.on_zone_entered(zone_idx2)
		## DailyChallenge — zone reached tracking
		if DailyChallenge != null:
			var zone_idx3: int = _expl_root.current_zone_idx if _expl_root != null else 0
			DailyChallenge.on_zone_reached(zone_idx3)
		## Setup AmbientLifeManager — pool creatures in exploration zone
		if _ambient_life == null:
			_ambient_life = Node2D.new()
			_ambient_life.set_script(load("res://src/gameplay/ambient_life_manager.gd"))
		_expl_root.add_child(_ambient_life)
		var zone_rect := Rect2(0.0, 0.0, 3200.0, 1080.0)
		_ambient_life.setup(_hero, zone_rect)
		## Wire night star_dust spawn request from DayNightCycle
		if _day_night_cycle != null and _day_night_cycle.has_signal("star_dust_spawn_requested"):
			if not _day_night_cycle.star_dust_spawn_requested.is_connected(_on_star_dust_spawn):
				_day_night_cycle.star_dust_spawn_requested.connect(_on_star_dust_spawn)
		## Show mount button if hero has acquired the MOUNT_SCROLL item
		if ItemInventory.has_item(ItemInventory.Item.MOUNT_SCROLL) and _hud != null:
			_hud.show_mount_btn()
		## reparent keeps global transform — hero appears at same world position then teleports
		_hero.reparent(_expl_root, true)
		_hero.position = Vector2(320.0, 540.0)  ## Exploration entry — zone 0 center-left
	)
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.35)

## Fade to black → auto-apply resources → return to TD → reparent hero → fade in.
## Also triggered by hero.died_in_exploration (forced return on 0 HP).
func _do_return() -> void:
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return   ## Guard against double-trigger (e.g. die + tap return simultaneously)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		GameStateMachine.request_return_to_td()
		_hero.reparent($GameWorld, true)
		_hero.position = _hero_td_pos
		_hero._dying = false

		## Dismount hero if mounted (mount is EXPLORING-only)
		if _mount_system != null and _mount_system.is_mounted:
			_mount_system.dismount(_hero)

		## Phase 4 — auto-apply collected resources as TD bonuses
		_apply_exploration_resources()

		## Notify exploration map before freeing (refreshes contracts, stops events).
		if _expl_root.has_method("on_hero_returned"):
			_expl_root.on_hero_returned()

		## Register zone clear with HeroProgression.
		var zone_idx: int = int(_hero.position.x / 3200.0)
		HeroProgression.register_zone_clear(clampi(zone_idx, 0, 14))
		## Achievement: expedition completed
		AchievementSystem.on_expedition_completed()

		## Detach AmbientLifeManager from expl_root before freeing (keep pool)
		if _ambient_life != null and _ambient_life.get_parent() == _expl_root:
			_expl_root.remove_child(_ambient_life)
			add_child(_ambient_life)
		_expl_root.queue_free()
		_expl_root = null
		_expl_interactables.clear()
		_expl_nearest = null
		$GameWorld.visible = true
		## Restore start wave button if the wave system is still waiting between waves.
		## _on_game_state_changed(PLAYING) hides it unconditionally; re-show here
		## since wave_start_ready won't fire again for an already-waiting wave.
		if _enemy_wave != null and _enemy_wave._waiting_for_next_wave:
			var _ret_preview: Dictionary = _enemy_wave.get_next_wave_preview()
			_hud.show_start_wave_btn(_ret_preview)
	)
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.35)

## World boss phase 2 — unleash an assault wave on the castle from inside the boss fight.
## The wave spawns in GameWorld (hidden) and attacks the castle in real time.
## When the player returns from exploration they'll find the castle damaged.
func _on_boss_phase2(wave_tier: int) -> void:
	if _enemy_wave != null and _enemy_wave.has_method("force_boss_wave"):
		_enemy_wave.force_boss_wave(wave_tier)

## Apply a permanent TD gameplay buff when a main quest chapter is completed.
## Rewards defined in QuestManager.CHAPTER_TD_REWARDS.
func _on_quest_chapter_completed(chapter_id: int) -> void:
	if QuestManager == null:
		return
	var reward: String = QuestManager.CHAPTER_TD_REWARDS[clampi(chapter_id, 0, QuestManager.CHAPTER_TD_REWARDS.size() - 1)]
	if reward.is_empty():
		return
	match reward:
		"archer_range_+10":
			if _archer_formation != null:
				_archer_formation.set("_range_bonus", (_archer_formation.get("_range_bonus") as float) + 10.0)
		"arrow_speed_+15pct":
			if _archer_formation != null:
				_archer_formation.set("_arrow_speed_mult",
					(_archer_formation.get("_arrow_speed_mult") as float) * 1.15)
		"tower_hp_+25":
			for t: Node2D in _towers:
				if t.has_method("increase_max_hp"):
					t.increase_max_hp(25)
		"castle_regen_x2":
			if _castle != null:
				_castle.set("_quest_regen_mult", 2.0)
		"coin_magnet_+30px":
			if _economy != null:
				var cur: float = _economy.get("_magnet_r_bonus") if _economy.get("_magnet_r_bonus") != null else 0.0
				_economy.set("_magnet_r_bonus", cur + 30.0)
		"archer_dmg_+10pct":
			if _archer_formation != null:
				var cur_mult: float = _archer_formation.get("_damage_bonus_mult") if _archer_formation.get("_damage_bonus_mult") != null else 1.0
				_archer_formation.set("_damage_bonus_mult", cur_mult * 1.10)
		"tower_count_+1":
			## Increase the effective tower slot limit by 1 (capped at MAX_TOWERS for TOWER_POSITIONS array)
			_tower_slot_limit = mini(_tower_slot_limit + 1, MAX_TOWERS)
		"hero_spell_+1":
			if _hero_spells != null and _hero_spells.has_method("unlock_extra_spell"):
				_hero_spells.unlock_extra_spell()
		_:
			pass  ## forge_heart_final, fire_tower_perm, etc. handled by narrative or future systems

## Apply a permanent gameplay bonus from an NPC chain step reward.
## Called by QuestManager.npc_step_completed signal.
func _on_npc_step_reward(_npc_id: int, _step_id: int, reward: String) -> void:
	match reward:
		## ── Marchand Darro ───────────────────────────────────────────────────
		"gold_bonus_10pct":
			if _economy != null:
				_economy.set("_npc_gold_bonus_mult",
					(_economy.get("_npc_gold_bonus_mult") as float) * 1.10)
		"gold_bonus_20pct":
			if _economy != null:
				_economy.set("_npc_gold_bonus_mult",
					(_economy.get("_npc_gold_bonus_mult") as float) * 1.20)

		## ── Éclaireuse Lira ──────────────────────────────────────────────────
		"cave_radius_+20px":
			HiddenCave.radius_bonus += 20.0
		"stamina_+20pct":
			if _hero != null:
				var cur: float = _hero.get("_speed_mult") if _hero.get("_speed_mult") != null else 1.0
				_hero.set("_speed_mult", cur * 1.20)

		## ── Sage Orrin ───────────────────────────────────────────────────────
		"lore_xp_+25pct":
			if QuestManager != null:
				QuestManager.set("_lore_xp_bonus_pct",
					(QuestManager.get("_lore_xp_bonus_pct") as float) + 0.25)
		"spell_dmg_+15pct":
			if _hero != null:
				var cur: float = _hero.get("_spell_dmg_mult") if _hero.get("_spell_dmg_mult") != null else 1.0
				_hero.set("_spell_dmg_mult", cur * 1.15)

		## ── Barde Caelo ──────────────────────────────────────────────────────
		"speed_buff_30s":
			## "Speed buff" from bard becomes a modest permanent speed bonus.
			if _hero != null:
				var cur: float = _hero.get("_speed_mult") if _hero.get("_speed_mult") != null else 1.0
				_hero.set("_speed_mult", cur * 1.10)
		"momentum_boost":
			if _archer_formation != null:
				_archer_formation.set("_momentum_gold_mult",
					(_archer_formation.get("_momentum_gold_mult") as float) * 1.50)
		"xp_song_+20pct":
			if QuestManager != null:
				QuestManager.set("_all_xp_bonus_pct",
					(QuestManager.get("_all_xp_bonus_pct") as float) + 0.20)

		## ── Guérisseuse Senna ────────────────────────────────────────────────
		"heal_shrine_cd_-30s":
			HealingShrine.cd_reduction += 30.0
		"castle_regen_+25pct":
			if _castle != null:
				var cur: float = _castle.get("_quest_regen_mult") if _castle.get("_quest_regen_mult") != null else 1.0
				_castle.set("_quest_regen_mult", cur * 1.25)

		## ── Future / narrative rewards (no runtime effect yet) ────────────────
		"shop_discount_10pct", "shop_discount_20pct", "trade_post_access", "merchant_bonded",\
		"scout_mark_ability", "scout_reveal_all_caves", "scout_bonded",\
		"sage_tome_unlock", "ancient_knowledge_passive", "sage_bonded",\
		"bard_concert_unlock", "bard_bonded",\
		"aura_heal_unlock", "mass_heal_ability", "healer_bonded":
			pass  ## Handled by future systems (shop, exploration perks, narrative)
		_:
			pass

## Display an event banner via HUD when a dynamic world event fires.
func _on_event_banner_requested(title: String, description: String, _duration: float) -> void:
	if _hud != null and _hud.has_method("show_boss_announce"):
		_hud.show_boss_announce(title + "\n" + description)

## Phase 4 — apply all pending effects on return to TD mode.
## 1. Apply crafted item effects to TD nodes (archers, towers, castle).
## 2. Convert unconsumed raw resources into TD bonuses.
func _apply_exploration_resources() -> void:
	_apply_crafted_item_effects()
	_apply_raw_resource_bonuses()

## Apply permanent effects from crafted items to all TD gameplay nodes.
## Called once on _do_return(). Effects that were already applied to the hero
## during exploration (weapon, armor) persist via hero's stat fields.
func _apply_crafted_item_effects() -> void:
	## ── Archer equipment ──────────────────────────────────────────────────
	if ItemInventory.has_item(ItemInventory.Item.IRON_ARROWHEADS):
		_archer_formation.set("_crafted_arrow_dmg_bonus",
			(_archer_formation.get("_crafted_arrow_dmg_bonus") as int) + 8)
	if ItemInventory.has_item(ItemInventory.Item.SILK_QUIVER):
		_archer_formation.set("_crafted_speed_bonus", 1.30)
	if ItemInventory.has_item(ItemInventory.Item.HEAVY_BROADHEAD):
		_archer_formation.set("_crafted_arrow_dmg_bonus",
			(_archer_formation.get("_crafted_arrow_dmg_bonus") as int) + 15)
	if ItemInventory.has_item(ItemInventory.Item.POISON_QUIVER):
		_archer_formation.set("_has_poison_quiver", true)
	if ItemInventory.has_item(ItemInventory.Item.FIRE_QUIVER):
		_archer_formation.set("_has_fire_quiver", true)
	if ItemInventory.has_item(ItemInventory.Item.FORMATION_BANNER):
		_archer_formation.set("_has_formation_banner", true)

	## ── Castle defenses ───────────────────────────────────────────────────
	if ItemInventory.has_item(ItemInventory.Item.STONE_WALL):
		_castle.increase_max_hp(60)
	if ItemInventory.has_item(ItemInventory.Item.HEALING_WARD):
		## Triple the castle REGEN_RATE by reducing its effective interval
		_castle.set("_regen_bonus_mult", 3.0)
	if ItemInventory.has_item(ItemInventory.Item.IRON_GATE):
		_castle.set("_damage_reduction", 2)
	if ItemInventory.has_item(ItemInventory.Item.DEFENSIVE_MOAT):
		_castle.set("_has_defensive_moat", true)

	## ── Hero weapon/armor effects (applied here in case crafted before return) ──
	if ItemInventory.has_item(ItemInventory.Item.BONE_BOW):
		_hero.set("_atk_range_bonus", 70.0)
	if ItemInventory.has_item(ItemInventory.Item.CRYSTAL_STAFF):
		_hero.set("_spell_dmg_mult", 1.30)
	if ItemInventory.has_item(ItemInventory.Item.CRYSTAL_AMULET):
		_hero.set("_regen_rate", 1.0)   ## 1 HP every 4s
	if ItemInventory.has_item(ItemInventory.Item.SHADOW_MAIL):
		_hero.set("_dmg_reduction", 0.40)
	if ItemInventory.has_item(ItemInventory.Item.SILK_CLOAK):
		_hero.set("_stealth", 0.65)     ## enemies aggro at 65% of normal radius

	## ── Tower item upgrades ────────────────────────────────────────────────
	_apply_tower_item_effects()

## Convert leftover raw resources (not consumed by crafting) into TD bonuses.
## Only base resources (WOOD, STONE, HERB) convert — crafting ingredients are spent.
func _apply_raw_resource_bonuses() -> void:
	var wood_sets: int = ResourceInventory.get_count(ResourceInventory.Type.WOOD) / 5
	if wood_sets > 0:
		ResourceInventory.spend(ResourceInventory.Type.WOOD, wood_sets * 5)
		_economy.add_gold(wood_sets * 50)

	var stone_sets: int = ResourceInventory.get_count(ResourceInventory.Type.STONE) / 3
	if stone_sets > 0:
		ResourceInventory.spend(ResourceInventory.Type.STONE, stone_sets * 3)
		_castle.increase_max_hp(stone_sets * 20)

	var herb_sets: int = ResourceInventory.get_count(ResourceInventory.Type.HERB) / 2
	if herb_sets > 0:
		ResourceInventory.spend(ResourceInventory.Type.HERB, herb_sets * 2)
		_hero.heal(herb_sets * 20)

## Update the exploration resource counter label — shows only non-zero resources.
func _refresh_resource_lbl() -> void:
	if _expl_resource_lbl == null:
		return
	var pairs: Array = ResourceInventory.get_nonempty()
	if pairs.is_empty():
		_expl_resource_lbl.text = "Inventaire vide"
		return
	var parts: Array[String] = []
	for pair: Array in pairs:
		var t: int = pair[0]
		var c: int = pair[1]
		parts.append("%s:%d" % [ResourceInventory.SHORT_NAMES[t], c])
	_expl_resource_lbl.text = "  ".join(parts)

## Update the RPG HUD hero HP bar during exploration.
func _on_hero_hp_changed(new_hp: int) -> void:
	_hud.update_rpg_hp(new_hp, _hero.HERO_MAX_HP)

## Update the RPG HUD level/XP display when hero gains experience.
func _on_hero_xp_changed(new_xp: int, new_level: int) -> void:
	_hud.update_rpg_xp(new_xp, new_level)

## Toggle Journal and Talent buttons with exploration state.
func _on_rpg_btn_state_changed(new_state: int) -> void:
	var exploring: bool = (new_state == GameStateMachine.State.EXPLORING)
	for child: Node in $HUDLayer.get_children():
		if child.has_meta("journal_btn") or child.has_meta("skills_btn"):
			(child as Button).visible = exploring

## Called when any RPG camp in the exploration map is cleared.
## Updates the "Camps: X/3" counter in the RPG HUD bar.
func _on_camp_cleared(index: int) -> void:
	_expl_camps_cleared = mini(_expl_camps_cleared + 1, 3)
	_hud.update_rpg_camps(_expl_camps_cleared)
	## Notify WorldStateManager and QuestManager of camp clear
	var zone_idx: int = _expl_root.current_zone_idx if _expl_root != null else 0
	if WorldStateManager != null:
		WorldStateManager.on_camp_cleared(zone_idx)
	## Achievement tracking
	var camp_tier: int = _expl_root.get_camp_tier(index) if _expl_root != null and _expl_root.has_method("get_camp_tier") else 0
	if QuestManager != null and QuestManager.has_method("on_camp_cleared"):
		QuestManager.on_camp_cleared(zone_idx, camp_tier)
	AchievementSystem.on_camp_cleared(camp_tier)
	if DailyChallenge != null:
		DailyChallenge.on_camp_cleared()

## Show a transient notification label when a zone blessing is earned.
func _on_blessing_granted(label: String) -> void:
	var lbl := Label.new()
	lbl.text = label
	lbl.position = Vector2(480.0 - 150.0, 200.0)  ## Centered, lower third of screen
	lbl.size = Vector2(300.0, 30.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.35))
	$HUDLayer.add_child(lbl)
	AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", 160.0, 1.0)
	tw.parallel().tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.60)
	tw.tween_callback(lbl.queue_free)

## ── Dungeon system ─────────────────────────────────────────────────────────

## Open a DungeonFloor overlay when a hidden cave is entered.
func _on_dungeon_entered(zone_idx: int, seed_val: int) -> void:
	if _dungeon_node != null:
		return
	var script: GDScript = load("res://src/gameplay/dungeon_floor.gd")
	if script == null:
		return
	_dungeon_node = CanvasLayer.new()
	_dungeon_node.set_script(script)
	add_child(_dungeon_node)
	_dungeon_node.dungeon_completed.connect(_on_dungeon_completed)
	_dungeon_node.dungeon_fled.connect(func() -> void: _dungeon_node = null)
	_dungeon_node.hero_damaged.connect(func(amt: int) -> void:
		if _hero != null and _hero.has_method("take_damage"):
			_hero.take_damage(amt))
	_dungeon_node.setup(zone_idx, seed_val, _hero)

func _on_dungeon_completed(gold: int, resources: Dictionary) -> void:
	_dungeon_node = null
	if gold > 0:
		_economy.add_gold(gold)
	for res_type: int in resources.keys():
		var qty: int = resources[res_type] as int
		if qty > 0:
			ResourceInventory.add(res_type, qty)
	if _hud != null and _hud.has_method("show_boss_announce"):
		_hud.show_boss_announce("Donjon termine ! +%dg" % gold)

## ── Mount system ───────────────────────────────────────────────────────────

func _on_mount_pressed() -> void:
	if _mount_system == null or _hero == null:
		return
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return
	_mount_system.try_mount(_hero)

## ── Spell upgrade panel ────────────────────────────────────────────────────

var _spell_upgrade_panel: Node = null

func _show_spell_upgrade_panel() -> void:
	if _spell_upgrade_panel != null:
		_spell_upgrade_panel.queue_free()
		_spell_upgrade_panel = null
		return
	if _spell_upgrade_tree == null:
		return
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 12
	add_child(cl)
	_spell_upgrade_panel = cl

	var bg: ColorRect = ColorRect.new()
	bg.size     = Vector2(640.0, 400.0)
	bg.position = Vector2(160.0, 70.0)
	bg.color    = Color(0.10, 0.06, 0.18, 0.96)
	cl.add_child(bg)

	var title: Label = Label.new()
	title.text     = "AMELIORATIONS DE SORTS"
	title.position = Vector2(0.0, 14.0)
	title.size     = Vector2(640.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	bg.add_child(title)

	var path_names: Array[String] = ["Puissance", "Zone", "Efficacite"]
	var spell_cols: Array[Color] = [Color("#E74C3C"), Color("#F1C40F"), Color("#3498DB")]

	for si: int in range(3):
		var col_x: float = 20.0 + float(si) * 205.0
		var spell_lbl: Label = Label.new()
		spell_lbl.text     = (_spell_upgrade_tree.SPELL_NAMES as Array[String])[si]
		spell_lbl.position = Vector2(col_x, 50.0)
		spell_lbl.size     = Vector2(190.0, 22.0)
		spell_lbl.add_theme_font_size_override("font_size", 13)
		spell_lbl.add_theme_color_override("font_color", spell_cols[si])
		bg.add_child(spell_lbl)
		for pi: int in range(3):
			var btn_y: float = 80.0 + float(pi) * 90.0
			var level: int = (_spell_upgrade_tree.spell_upgrades as Array)[si][pi]
			var can_aff: bool = _spell_upgrade_tree.can_afford(si, pi)
			var cost_txt: String = _spell_upgrade_tree.get_upgrade_cost_text(si, pi)
			var path_chosen: int = (_spell_upgrade_tree.chosen_path as Array[int])[si]
			var allowed: bool = can_aff and (path_chosen == -1 or path_chosen == pi)
			var btn_lbl: String = "%s Lv.%d\n%s" % [path_names[pi], level, cost_txt]
			var btn: Button = Button.new()
			btn.text     = btn_lbl
			btn.position = Vector2(col_x, btn_y)
			btn.size     = Vector2(190.0, 80.0)
			btn.disabled = not allowed
			btn.add_theme_font_size_override("font_size", 11)
			var s: StyleBoxFlat = StyleBoxFlat.new()
			s.bg_color = Color(0.22, 0.14, 0.38) if allowed else Color(0.15, 0.12, 0.20)
			s.corner_radius_top_left     = 5
			s.corner_radius_top_right    = 5
			s.corner_radius_bottom_left  = 5
			s.corner_radius_bottom_right = 5
			btn.add_theme_stylebox_override("normal", s)
			var _si: int = si
			var _pi: int = pi
			btn.pressed.connect(func() -> void:
				_spell_upgrade_tree.try_upgrade(_si, _pi)
				## Rebuild panel to reflect updated state
				if _spell_upgrade_panel != null:
					_spell_upgrade_panel.queue_free()
					_spell_upgrade_panel = null
				_show_spell_upgrade_panel())
			bg.add_child(btn)

	var close_btn: Button = Button.new()
	close_btn.text     = "FERMER"
	close_btn.position = Vector2(260.0, 358.0)
	close_btn.size     = Vector2(120.0, 34.0)
	close_btn.pressed.connect(func() -> void:
		if _spell_upgrade_panel != null:
			_spell_upgrade_panel.queue_free()
			_spell_upgrade_panel = null)
	bg.add_child(close_btn)

## Refresh all consumable button labels and disabled state to reflect current quantities.
func _refresh_consumable_btns() -> void:
	const CONSUMABLE_IDS: Array[int] = [
		ItemInventory.Item.HEALTH_POTION,
		ItemInventory.Item.MEGA_POTION,
		ItemInventory.Item.SPEED_ELIXIR,
		ItemInventory.Item.SMOKE_BOMB,
	]
	const CONSUMABLE_SHORT: Array[String] = ["Pot.", "Méga", "Élix.", "Fum."]
	for i: int in range(_expl_consumable_btns.size()):
		var cbtn: Button = _expl_consumable_btns[i]
		var count: int = ItemInventory.consumable_count(CONSUMABLE_IDS[i])
		cbtn.text = CONSUMABLE_SHORT[i] + " ×%d" % count
		cbtn.disabled = (count <= 0)

## Apply the effect of a consumed item immediately to the hero.
## Called when a consumable button is pressed during exploration.
func _on_use_consumable(item_id: int) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.EXPLORING:
		return
	if not ItemInventory.use_consumable(item_id):
		return
	match item_id:
		ItemInventory.Item.HEALTH_POTION:
			if _hero != null:
				_hero.heal(25)
			AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
		ItemInventory.Item.MEGA_POTION:
			if _hero != null:
				_hero.heal(50)
			AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
		ItemInventory.Item.SPEED_ELIXIR:
			if _hero != null:
				_hero.set("_speed_mult", 1.5)
				_hero.set("_speed_elixir_timer", 20.0)
			AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
		ItemInventory.Item.SMOKE_BOMB:
			## Smoke Bomb: briefly suppresses enemy aggro — set stealth to 1.0 for 8s
			## RPGEnemy._effective_aggro_radius() reads _hero._stealth directly.
			if _hero != null:
				_hero.set("_stealth", 1.0)
				## Restore stealth to Silk Cloak value (or 0) after 8 seconds.
				var restore_stealth: float = 0.65 if ItemInventory.has_item(ItemInventory.Item.SILK_CLOAK) else 0.0
				get_tree().create_timer(5.0).timeout.connect(func() -> void:
					if _hero != null:
						_hero.set("_stealth", restore_stealth))
			AudioManager.play(AudioManager.SFX_DWELL_COMPLETE)
	_refresh_consumable_btns()

## Scan all interactables, find the nearest within INTERACT_RADIUS.
## Show/hide the HUD interact button accordingly.
func _update_interact_proximity() -> void:
	var hero_pos: Vector2 = _hero.global_position
	var best_dist: float = INTERACT_RADIUS + 1.0
	var best_node: Node2D = null

	for node: Node2D in _expl_interactables:
		if not is_instance_valid(node) or not node.visible:
			continue
		## Only show button for interactable nodes that are currently usable
		if not node.has_method("is_interactable") or not node.is_interactable():
			continue
		var dist: float = hero_pos.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_node = node

	if best_node == _expl_nearest:
		return  ## no change

	_expl_nearest = best_node
	if _expl_nearest != null:
		var label: String = _expl_nearest.get_interact_label() if _expl_nearest.has_method("get_interact_label") else "Utiliser"
		_hud.show_interact_btn(label)
	else:
		_hud.hide_interact_btn()

## Called when the HUD proximity interact button is tapped.
func _on_interact_pressed() -> void:
	if _expl_nearest == null or not is_instance_valid(_expl_nearest):
		return
	if _expl_nearest.has_method("is_interactable") and not _expl_nearest.is_interactable():
		return
	if _expl_nearest.has_method("interact"):
		_expl_nearest.interact()
	## Re-check nearest immediately so button updates (e.g., resource disappears)
	_expl_nearest = null
	_hud.hide_interact_btn()

## Called by DayNightCycle.star_dust_spawn_requested during NIGHT phase.
## Spawns a star_dust resource node in the active exploration map.
func _on_star_dust_spawn(zone_idx: int) -> void:
	if _expl_root == null or not is_instance_valid(_expl_root):
		return
	if _expl_root.has_method("spawn_star_dust"):
		_expl_root.spawn_star_dust(zone_idx)

## Spawn an expanding ring VFX at the spell impact center (world space).
## Connected to hero_spells.spell_impact signal.
## P3 — burst VFX on enemy death: expanding orange ring that fades out in 0.35s.
## Spawned in GameWorld (TD mode only — called from enemy_killed signal).
func _spawn_death_vfx(pos: Vector2) -> void:
	if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
		return
	var ring := ColorRect.new()
	ring.size = Vector2(18.0, 18.0)
	ring.color = Color(1.0, 0.55, 0.1, 0.85)
	ring.position = pos - Vector2(9.0, 9.0)
	$GameWorld.add_child(ring)
	var tw := ring.create_tween()
	tw.parallel().tween_property(ring, "scale", Vector2(3.5, 3.5), 0.35)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.tween_callback(ring.queue_free)

func _spawn_spell_vfx(spell_index: int, center: Vector2) -> void:
	var vfx: Node2D = Node2D.new()
	vfx.set_script(load("res://src/vfx/spell_hit_vfx.gd"))
	vfx.position = center
	## Add to the active world — GameWorld in TD mode, _expl_root in exploration
	var world: Node2D = _expl_root if _expl_root != null else $GameWorld
	world.add_child(vfx)
	## play() reads SPELLS[].radius from hero_spells for the correct ring size
	var radius: float = _hero_spells.SPELLS[spell_index].radius
	vfx.play(spell_index, radius)
