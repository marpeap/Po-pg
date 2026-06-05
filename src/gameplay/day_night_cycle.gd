## DayNightCycle — Cycle jour/nuit dynamique 8 minutes / cycle complet.
## Inspiré de Zelda BOTW (météo + heure qui changent le gameplay),
## Stardew Valley (rythme quotidien apaisant), et Minecraft (difficulté nocturne).
##
## Effets du cycle :
##   Aube (0-15%)  : +20% XP collecte, spawn ressources bonus
##   Matin (15-40%): normal
##   Midi (40-60%) : -10% vitesse (chaleur), +15% or des coffres
##   Soir (60-80%) : +25% ressources rares, lumière dorée
##   Nuit (80-100%): STAR_DUST spawn, ennemis +20% HP, MOONSTONE bonus
##
## Piliers : ambiance apaisante (transitions douces), profondeur stratégique (timing).
extends Node

## ── Paramètres du cycle ──────────────────────────────────────────────────

## Durée totale d'un cycle complet en secondes (8 minutes).
const CYCLE_DURATION := 480.0

## Phases et leurs plages [0.0 - 1.0]
enum Phase { DAWN = 0, MORNING = 1, NOON = 2, EVENING = 3, NIGHT = 4 }

const PHASE_RANGES: Array[Vector2] = [
	Vector2(0.00, 0.15),  ## Aube
	Vector2(0.15, 0.40),  ## Matin
	Vector2(0.40, 0.60),  ## Midi
	Vector2(0.60, 0.80),  ## Soir
	Vector2(0.80, 1.00),  ## Nuit
]

const PHASE_NAMES: Array[String] = ["Aube", "Matin", "Midi", "Soir", "Nuit"]

## Couleurs ambiantes par phase (appliquées en overlay CanvasLayer avec modulate)
const PHASE_COLORS: Array[Color] = [
	Color(1.00, 0.92, 0.78, 0.05),  ## Aube — chaud doux
	Color(1.00, 1.00, 1.00, 0.00),  ## Matin — neutre (aucun overlay)
	Color(1.00, 0.98, 0.88, 0.08),  ## Midi — léger jaune
	Color(0.95, 0.80, 0.55, 0.15),  ## Soir — orange doré
	Color(0.15, 0.12, 0.30, 0.30),  ## Nuit — bleu nuit
]

## Modificateurs de gameplay par phase.
## [xp_mult, rare_chance_bonus, gold_mult, enemy_hp_mult, speed_mult]
const PHASE_MODIFIERS: Array[Array] = [
	[1.20, 0.00,  1.00, 1.00, 1.00],  ## Aube
	[1.00, 0.00,  1.00, 1.00, 1.00],  ## Matin
	[1.00, 0.00,  1.15, 1.00, 0.90],  ## Midi
	[1.00, 0.25,  1.00, 1.00, 1.00],  ## Soir
	[1.00, 0.10,  1.00, 1.20, 1.00],  ## Nuit
]

## ── Runtime state ─────────────────────────────────────────────────────────

var _time: float = 0.0           ## Current cycle time [0, CYCLE_DURATION)
var _phase: Phase = Phase.MORNING
var _paused: bool = false
var _overlay: ColorRect = null   ## Canvas overlay for ambient tint
var _canvas_layer: CanvasLayer = null

signal phase_changed(new_phase: Phase, name_str: String)
signal night_started()
signal dawn_started()
signal star_dust_spawn_requested(zone_idx: int)

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	## Start at morning (25% into cycle) — peaceful opening feel
	_time = CYCLE_DURATION * 0.25
	_build_overlay()

func _build_overlay() -> void:
	## Create a full-screen color overlay on CanvasLayer 1 (above world, below HUD)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1
	add_child(_canvas_layer)
	_overlay = ColorRect.new()
	_overlay.size = Vector2(960.0, 540.0)
	_overlay.position = Vector2.ZERO
	_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_overlay)

## ── Process ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _paused:
		return
	_time += delta
	if _time >= CYCLE_DURATION:
		_time = fmod(_time, CYCLE_DURATION)

	var progress: float = _time / CYCLE_DURATION
	var new_phase: Phase = _get_phase(progress)

	if new_phase != _phase:
		var old_phase: Phase = _phase
		_phase = new_phase
		phase_changed.emit(new_phase, PHASE_NAMES[new_phase])
		if new_phase == Phase.NIGHT:
			night_started.emit()
		elif new_phase == Phase.DAWN:
			dawn_started.emit()
			## Spawn STAR_DUST in a random zone at dawn (they remain from the night)
		## Spawn STAR_DUST at start of night in a random zone
		if new_phase == Phase.NIGHT:
			var zone_idx: int = int(randf() * 15.0)
			star_dust_spawn_requested.emit(zone_idx)

	## Smooth overlay tint transition
	if _overlay != null:
		var target_color: Color = _compute_ambient_color(progress)
		_overlay.color = _overlay.color.lerp(target_color, delta * 0.8)

func _get_phase(progress: float) -> Phase:
	for i: int in range(PHASE_RANGES.size()):
		var r: Vector2 = PHASE_RANGES[i]
		if progress >= r.x and progress < r.y:
			return i as Phase
	return Phase.NIGHT

func _compute_ambient_color(progress: float) -> Color:
	## Interpolate between adjacent phase colors for smooth transition
	var phase: Phase = _get_phase(progress)
	var r: Vector2 = PHASE_RANGES[phase]
	var t: float = (progress - r.x) / (r.y - r.x)
	var next_phase: int = (phase + 1) % 5
	var c1: Color = PHASE_COLORS[phase]
	var c2: Color = PHASE_COLORS[next_phase]
	## Smooth step for natural feel
	t = t * t * (3.0 - 2.0 * t)
	return c1.lerp(c2, t)

## ── Pause control ────────────────────────────────────────────────────────

func pause_cycle() -> void:
	_paused = true

func resume_cycle() -> void:
	_paused = false

## ── Gameplay modifier queries ─────────────────────────────────────────────

func get_xp_multiplier() -> float:
	return PHASE_MODIFIERS[_phase][0]

func get_rare_chance_bonus() -> float:
	return PHASE_MODIFIERS[_phase][1]

func get_gold_multiplier() -> float:
	return PHASE_MODIFIERS[_phase][2]

func get_enemy_hp_multiplier() -> float:
	return PHASE_MODIFIERS[_phase][3]

func get_speed_multiplier() -> float:
	return PHASE_MODIFIERS[_phase][4]

func get_current_phase() -> Phase:
	return _phase

func get_phase_name() -> String:
	return PHASE_NAMES[_phase]

## Progress [0.0, 1.0] within current phase
func get_phase_progress() -> float:
	var progress: float = _time / CYCLE_DURATION
	var r: Vector2 = PHASE_RANGES[_phase]
	if r.y <= r.x:
		return 0.0
	return (progress - r.x) / (r.y - r.x)

## Total cycle progress [0.0, 1.0] — useful for clock display
func get_cycle_progress() -> float:
	return _time / CYCLE_DURATION

## Is it currently night?
func is_night() -> bool:
	return _phase == Phase.NIGHT

## Is it currently dawn? (rare spawn window)
func is_dawn() -> bool:
	return _phase == Phase.DAWN

## Is MOONSTONE bonus active? (night and evening)
func moonstone_bonus_active() -> bool:
	return _phase == Phase.NIGHT or _phase == Phase.EVENING

## STAR_DUST bonus: higher during night
func star_dust_yield_mult() -> float:
	match _phase:
		Phase.NIGHT:    return 3.0
		Phase.DAWN:     return 1.5
		Phase.EVENING:  return 1.2
		_:              return 1.0
