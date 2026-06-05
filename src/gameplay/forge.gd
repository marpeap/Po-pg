## Forge — session-scoped stat upgrade system (4 spatial zones, Alpha tier)
## GDD Req: forge.md — Formulas F1–F4
## ADR-005: session_reset integration
## Sprint 6: All k_* counters reset on GAME_OVER / session_reset.
## Consumers query effective_*() methods each fire/tick — no caching needed.
extends Node

## Emitted when any forge stat changes (purchase or session reset).
signal forge_stat_changed

## --- Base constants (authoritative values shared with archer_formation, economy, castle) ---

const PROJ_DAMAGE_BASE := 8
const SHOOT_IVTL_BASE := 1.2
const SHOOT_IVTL_FLOOR := 0.40     ## Minimum fire interval — floor per GDD forge.md
const MAGNET_BASE := 170.0
const MAGNET_CEILING := 450.0      ## Maximum magnet radius — ceiling per GDD forge.md
const CASTLE_HP_BASE := 200

## --- Per-purchase deltas (GDD forge.md tuning knobs) ---

const FORGE_PROJ_DAMAGE_DELTA := 2      ## +2 damage per DMG purchase
const FORGE_IVTL_DELTA := 0.10          ## -0.10s per SPD purchase
const FORGE_MAGNET_DELTA := 40.0        ## +40px per MAG purchase
const FORGE_HP_DELTA := 30              ## +30 HP per HP purchase

## --- Purchase counters — session-scoped (reset on session_reset) ---

var k_dmg: int = 0
var k_ivtl: int = 0
var k_magnet: int = 0
var k_hp: int = 0

func _ready() -> void:
	GameStateMachine.session_reset.connect(_on_session_reset)

## --- Formula accessors ---

## Formula F1: effective archer projectile damage (GDD forge.md F1).
## result = PROJ_DAMAGE_BASE + k_dmg × FORGE_PROJ_DAMAGE_DELTA
func effective_proj_damage() -> int:
	return PROJ_DAMAGE_BASE + k_dmg * FORGE_PROJ_DAMAGE_DELTA

## Formula F2: effective fire interval in seconds (GDD forge.md F2).
## result = max(SHOOT_IVTL_FLOOR, SHOOT_IVTL_BASE − k_ivtl × FORGE_IVTL_DELTA)
func effective_shoot_ivtl() -> float:
	return maxf(SHOOT_IVTL_FLOOR, SHOOT_IVTL_BASE - k_ivtl * FORGE_IVTL_DELTA)

## Formula F3: effective coin magnet radius in px (GDD forge.md F3).
## result = min(MAGNET_CEILING, MAGNET_BASE + k_magnet × FORGE_MAGNET_DELTA)
func effective_magnet_r() -> float:
	return minf(MAGNET_CEILING, MAGNET_BASE + k_magnet * FORGE_MAGNET_DELTA)

## Formula F4: effective castle max HP (GDD forge.md F4).
## result = CASTLE_HP_BASE + k_hp × FORGE_HP_DELTA
func effective_castle_max_hp() -> int:
	return CASTLE_HP_BASE + k_hp * FORGE_HP_DELTA

## --- Purchase handlers (called by Main when Economy forge signals fire) ---

## Called when the hero dwells in the FORGE_DMG zone and 200g is spent.
func on_dmg_purchased() -> void:
	k_dmg += 1
	forge_stat_changed.emit()

## Called when the hero dwells in the FORGE_SPD zone and 200g is spent.
func on_spd_purchased() -> void:
	k_ivtl += 1
	forge_stat_changed.emit()

## Called when the hero dwells in the FORGE_MAG zone and 200g is spent.
func on_mag_purchased() -> void:
	k_magnet += 1
	forge_stat_changed.emit()

## Called when the hero dwells in the FORGE_HP zone and 200g is spent.
func on_hp_purchased() -> void:
	k_hp += 1
	forge_stat_changed.emit()

func _on_session_reset() -> void:
	k_dmg = 0
	k_ivtl = 0
	k_magnet = 0
	k_hp = 0
	forge_stat_changed.emit()
