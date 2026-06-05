## WorldStateManager — Progression de l'état des zones basée sur les camps vaincus.
## Inspiré de BOTW (monde qui réagit aux actions), FFXIV (quêtes qui transforment les zones).
##
## 4 états de zone : WILD → CONTESTED → PACIFIED → FLOURISHING
## Progression déclenchée par les signaux camp_cleared de ExplorationMap.
##
## Effets visuels et gameplay de chaque état :
##   WILD        : normal, ennemis présents
##   CONTESTED   : 50% camps vaincus — vignette rouge réduite, +5% ressources
##   PACIFIED    : 100% camps vaincus — +30% ressources, settlers NPCs, brightness +10%
##   FLOURISHING : après 3 visites pacifiées — +50% ressources, node de récolte quotidien
##
## Persisté dans user://world_state.cfg.
extends Node

enum ZoneState { WILD = 0, CONTESTED = 1, PACIFIED = 2, FLOURISHING = 3 }

const ZONE_COUNT := 15

## Camps totaux par zone (cache de ExplorationMap.ZONE_CAMP_COUNT)
const ZONE_TOTAL_CAMPS: Array[int] = [1,1,2,1,2,1,2,2,1,1,2,2,1,2,1]

## ── Runtime state ─────────────────────────────────────────────────────────

var zone_states: Array[int]         = []  ## ZoneState per zone
var zone_camps_cleared: Array[int]  = []  ## Cleared camps per zone
var zone_pacified_visits: Array[int] = [] ## Visits while PACIFIED

signal zone_state_changed(zone_idx: int, new_state: ZoneState)
signal zone_flourishing(zone_idx: int)

## ── Lifecycle ────────────────────────────────────────────────────────────

func _ready() -> void:
	zone_states.resize(ZONE_COUNT)
	zone_states.fill(ZoneState.WILD)
	zone_camps_cleared.resize(ZONE_COUNT)
	zone_camps_cleared.fill(0)
	zone_pacified_visits.resize(ZONE_COUNT)
	zone_pacified_visits.fill(0)
	_load()

## ── Camp cleared event ────────────────────────────────────────────────────

func on_camp_cleared(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= ZONE_COUNT:
		return
	zone_camps_cleared[zone_idx] += 1
	_update_zone_state(zone_idx)
	_save()

func _update_zone_state(zone_idx: int) -> void:
	var total: int = ZONE_TOTAL_CAMPS[zone_idx]
	var cleared: int = zone_camps_cleared[zone_idx]
	var old_state: int = zone_states[zone_idx]
	var new_state: int = old_state

	if cleared >= total and old_state < ZoneState.PACIFIED:
		new_state = ZoneState.PACIFIED
	elif cleared >= total / 2 and old_state < ZoneState.CONTESTED:
		new_state = ZoneState.CONTESTED

	if new_state != old_state:
		zone_states[zone_idx] = new_state
		zone_state_changed.emit(zone_idx, new_state as ZoneState)

## ── Zone visit tracking ──────────────────────────────────────────────────

func on_zone_visited(zone_idx: int) -> void:
	if zone_idx < 0 or zone_idx >= ZONE_COUNT:
		return
	if zone_states[zone_idx] == ZoneState.PACIFIED:
		zone_pacified_visits[zone_idx] += 1
		if zone_pacified_visits[zone_idx] >= 3:
			zone_states[zone_idx] = ZoneState.FLOURISHING
			zone_state_changed.emit(zone_idx, ZoneState.FLOURISHING)
			zone_flourishing.emit(zone_idx)
	_save()

## ── Resource multiplier query ─────────────────────────────────────────────

func get_resource_mult(zone_idx: int) -> float:
	if zone_idx < 0 or zone_idx >= ZONE_COUNT:
		return 1.0
	match zone_states[zone_idx]:
		ZoneState.WILD:        return 1.00
		ZoneState.CONTESTED:   return 1.05
		ZoneState.PACIFIED:    return 1.30
		ZoneState.FLOURISHING: return 1.50
		_:                     return 1.00

func get_state(zone_idx: int) -> ZoneState:
	if zone_idx < 0 or zone_idx >= ZONE_COUNT:
		return ZoneState.WILD
	return zone_states[zone_idx] as ZoneState

func get_state_name(zone_idx: int) -> String:
	match get_state(zone_idx):
		ZoneState.WILD:        return "Sauvage"
		ZoneState.CONTESTED:   return "Disputee"
		ZoneState.PACIFIED:    return "Pacifiee"
		ZoneState.FLOURISHING: return "Florissante"
		_:                     return "?"

## ── Persistence ──────────────────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	for i: int in range(ZONE_COUNT):
		cfg.set_value("zones", "state_%d" % i,    zone_states[i])
		cfg.set_value("zones", "cleared_%d" % i,  zone_camps_cleared[i])
		cfg.set_value("zones", "visits_%d" % i,   zone_pacified_visits[i])
	cfg.save("user://world_state.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://world_state.cfg") != OK:
		return
	for i: int in range(ZONE_COUNT):
		zone_states[i]          = cfg.get_value("zones", "state_%d" % i,   0)
		zone_camps_cleared[i]   = cfg.get_value("zones", "cleared_%d" % i, 0)
		zone_pacified_visits[i] = cfg.get_value("zones", "visits_%d" % i,  0)

func reset_all() -> void:
	zone_states.fill(ZoneState.WILD)
	zone_camps_cleared.fill(0)
	zone_pacified_visits.fill(0)
	_save()
