## SeasonManager — Saisons basées sur le temps réel (7 jours = 1 saison).
## Inspiré de Genshin Impact (Windblume, Lantern Rite) et FFXIV (événements hebdomadaires).
##
## 4 saisons cycliques :
##   SPRING : bonus ressources végétales, fleurs cosmétiques
##   SUMMER : bonus gold, ennemis légèrement plus rapides
##   AUTUMN : bonus XP +15%, feuillage doré
##   WINTER : chance rare doublée, blizzard visuel la nuit
##
## Persistance : user://season.cfg
extends Node

enum Season { SPRING = 0, SUMMER = 1, AUTUMN = 2, WINTER = 3 }

## 7 jours réels = 1 saison (604800 secondes)
const SEASON_DURATION_SECONDS := 604800

## Bonus par saison : [xp_mult, gold_mult, rare_bonus, herb_mult]
const SEASON_MODIFIERS: Array[Array] = [
	[1.00, 1.00, 0.00, 1.40],  ## SPRING  : herbes +40%
	[1.00, 1.20, 0.00, 1.00],  ## SUMMER  : gold +20%
	[1.15, 1.00, 0.00, 1.00],  ## AUTUMN  : XP +15%
	[1.00, 1.00, 0.08, 1.00],  ## WINTER  : rareté +8%
]

const SEASON_NAMES: Array[String] = ["Printemps", "Ete", "Automne", "Hiver"]

## Palette de teinte de saison : modulate sur l'overlay CanvasLayer
const SEASON_TINTS: Array[Color] = [
	Color(0.85, 0.95, 0.80, 0.04),  ## SPRING  : légèrement vert-rosé
	Color(1.00, 0.92, 0.70, 0.05),  ## SUMMER  : chaud doré
	Color(0.95, 0.80, 0.55, 0.06),  ## AUTUMN  : doré ambré
	Color(0.70, 0.80, 1.00, 0.05),  ## WINTER  : bleuté froid
]

## ── Runtime ─────────────────────────────────────────────────────────────────

var _current_season: int = Season.SPRING
var _season_start_unix: int = 0

## Overlay ColorRect (référence externe, optionnel — si fourni sera teinté)
var _season_overlay: ColorRect = null

signal season_changed(new_season: Season)

## ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load()
	_refresh_season()

## ── Tick ────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_refresh_season()

func _refresh_season() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - _season_start_unix
	if elapsed >= SEASON_DURATION_SECONDS:
		## Avancer d'autant de saisons que nécessaire (gère les longues absences)
		var skipped: int = elapsed / SEASON_DURATION_SECONDS
		_season_start_unix += skipped * SEASON_DURATION_SECONDS
		var old: int = _current_season
		_current_season = (_current_season + skipped) % 4
		if _current_season != old:
			season_changed.emit(_current_season as Season)
		_save()
	## Teinte overlay si connecté
	if _season_overlay != null:
		_season_overlay.color = SEASON_TINTS[_current_season]

## ── Queries ─────────────────────────────────────────────────────────────────

func get_season() -> Season:
	return _current_season as Season

func get_season_name() -> String:
	return SEASON_NAMES[_current_season]

func get_xp_multiplier() -> float:
	return SEASON_MODIFIERS[_current_season][0]

func get_gold_multiplier() -> float:
	return SEASON_MODIFIERS[_current_season][1]

func get_rare_bonus() -> float:
	return SEASON_MODIFIERS[_current_season][2]

func get_herb_multiplier() -> float:
	return SEASON_MODIFIERS[_current_season][3]

## Jours restants dans la saison courante (arrondi supérieur)
func days_remaining() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - _season_start_unix
	var remaining: int = SEASON_DURATION_SECONDS - (elapsed % SEASON_DURATION_SECONDS)
	return ceili(float(remaining) / 86400.0)

## ── Season Overlay ──────────────────────────────────────────────────────────

## Brancher un ColorRect existant pour le filtre de teinte saisonnière.
func set_season_overlay(rect: ColorRect) -> void:
	_season_overlay = rect
	if rect != null:
		rect.color = SEASON_TINTS[_current_season]

## ── Persistence ──────────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("season", "current", _current_season)
	cfg.set_value("season", "start_unix", _season_start_unix)
	cfg.save("user://season.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://season.cfg") != OK:
		## Première ouverture : démarrer la saison au timestamp courant
		_season_start_unix = int(Time.get_unix_time_from_system())
		_current_season = Season.SPRING
		_save()
		return
	_current_season = cfg.get_value("season", "current", Season.SPRING)
	_season_start_unix = cfg.get_value("season", "start_unix",
			int(Time.get_unix_time_from_system()))
