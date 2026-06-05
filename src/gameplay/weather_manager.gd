## WeatherManager — Système météo dynamique avec 6 états.
## Inspiré de BOTW (météo affectant gameplay) et Zelda TOTK (gameplay weather reactions).
##
## 6 états : CLEAR / CLOUDY / RAIN / STORM / FOG / SNOW
## Transitions aléatoires pondérées toutes les WEATHER_INTERVAL secondes.
## Overlay CanvasLayer via ColorRect + label VFX.
## Audio ambiant déclenché via AudioManager.
##
## Effets gameplay :
##   RAIN  : coins +10%, hero_speed −5%
##   STORM : enemy_speed −10%, archer_range −15%, VFX éclairs
##   FOG   : visibility −20% (overlay opacité +0.12)
##   SNOW  : enemy_speed −15%, resource herb_mult ×0.7 (winter chill)
extends Node

enum WeatherState {
	CLEAR  = 0,
	CLOUDY = 1,
	RAIN   = 2,
	STORM  = 3,
	FOG    = 4,
	SNOW   = 5,
}

## Durée min/max de chaque état météo (secondes)
const WEATHER_MIN_DURATION := 120.0
const WEATHER_MAX_DURATION := 480.0

## Probabilité de transition vers chaque état (somme = 1.0 pour chaque ligne)
## Lignes = état source, colonnes = état cible [CLEAR, CLOUDY, RAIN, STORM, FOG, SNOW]
const TRANSITION_WEIGHTS: Array[Array] = [
	[0.30, 0.35, 0.18, 0.05, 0.07, 0.05],  ## CLEAR   →
	[0.25, 0.20, 0.28, 0.12, 0.10, 0.05],  ## CLOUDY  →
	[0.15, 0.25, 0.20, 0.25, 0.08, 0.07],  ## RAIN    →
	[0.10, 0.20, 0.35, 0.10, 0.10, 0.15],  ## STORM   →
	[0.20, 0.30, 0.15, 0.05, 0.20, 0.10],  ## FOG     →
	[0.15, 0.25, 0.10, 0.15, 0.10, 0.25],  ## SNOW    →
]

## Teinte overlay par état
const WEATHER_TINTS: Array[Color] = [
	Color(0.0, 0.0, 0.0, 0.00),   ## CLEAR  : aucun
	Color(0.1, 0.1, 0.2, 0.08),   ## CLOUDY : léger gris
	Color(0.1, 0.1, 0.3, 0.14),   ## RAIN   : bleu-gris
	Color(0.05,0.05,0.2, 0.22),   ## STORM  : sombre
	Color(0.8, 0.8, 0.7, 0.16),   ## FOG    : blanc jaunâtre
	Color(0.7, 0.8, 1.0, 0.18),   ## SNOW   : blanc bleuté
]

const WEATHER_NAMES: Array[String] = [
	"Ensoleille", "Nuageux", "Pluie", "Orage", "Brouillard", "Neige"
]

## ── Runtime ─────────────────────────────────────────────────────────────────

var _state: int = WeatherState.CLEAR
var _timer: float = 0.0
var _duration: float = WEATHER_MAX_DURATION

var _overlay: ColorRect = null
var _tw: Tween = null

signal weather_changed(new_state: WeatherState)

## ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_schedule_next()

## ── Process ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _duration:
		_timer = 0.0
		_transition()

## ── Transitions ──────────────────────────────────────────────────────────────

func _schedule_next() -> void:
	_duration = randf_range(WEATHER_MIN_DURATION, WEATHER_MAX_DURATION)

func _transition() -> void:
	var weights: Array = TRANSITION_WEIGHTS[_state]
	var roll: float = randf()
	var cumulative: float = 0.0
	var new_state: int = _state
	for i: int in range(weights.size()):
		cumulative += float(weights[i])
		if roll <= cumulative:
			new_state = i
			break
	if new_state != _state:
		_state = new_state
		_apply_overlay()
		weather_changed.emit(_state as WeatherState)
		## Notifier AudioManager si disponible
		if AudioManager != null and AudioManager.has_method("play_weather"):
			AudioManager.play_weather(_state)
	_schedule_next()

func _apply_overlay() -> void:
	if _overlay == null:
		return
	var target: Color = WEATHER_TINTS[_state]
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_overlay, "color", target, 3.0)

## ── Overlay ─────────────────────────────────────────────────────────────────

func set_weather_overlay(rect: ColorRect) -> void:
	_overlay = rect
	if rect != null:
		rect.color = WEATHER_TINTS[_state]

## ── Queries ─────────────────────────────────────────────────────────────────

func get_weather() -> WeatherState:
	return _state as WeatherState

func get_weather_name() -> String:
	return WEATHER_NAMES[_state]

func is_stormy() -> bool:
	return _state == WeatherState.STORM

func get_coin_mult() -> float:
	return 1.10 if _state == WeatherState.RAIN else 1.00

func get_enemy_speed_mult() -> float:
	match _state:
		WeatherState.STORM: return 0.90
		WeatherState.SNOW:  return 0.85
		_:                  return 1.00

func get_archer_range_mult() -> float:
	return 0.85 if _state == WeatherState.STORM else 1.00

func get_fog_opacity() -> float:
	return 0.12 if _state == WeatherState.FOG else 0.00

func get_herb_mult() -> float:
	return 0.70 if _state == WeatherState.SNOW else 1.00

## Force weather for testing/events
func force_weather(state: WeatherState) -> void:
	_state = int(state)
	_timer = 0.0
	_apply_overlay()
	weather_changed.emit(_state as WeatherState)
