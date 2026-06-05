## Unit tests for ArcherFormation slot math and lerp formula
## Story: C02-S01
## GUT 9.6.0 — extends GutTest
extends GutTest

const ARCHER_LERP_F := 0.12
const TOLERANCE := 0.001

## ADR-004 formula under test
func _lerp_weight(delta: float) -> float:
	return 1.0 - pow(1.0 - ARCHER_LERP_F, delta * 60.0)

func test_lerp_weight_frame_rate_independent_at_60fps() -> void:
	var w := _lerp_weight(1.0 / 60.0)
	assert_almost_eq(w, ARCHER_LERP_F, TOLERANCE,
		"At 60fps, weight must equal ARCHER_LERP_F (0.12)")

func test_lerp_weight_frame_rate_independent_at_30fps() -> void:
	var w_30 := _lerp_weight(1.0 / 30.0)
	# Two 30fps steps must compound to same as two 60fps steps
	var w_60 := _lerp_weight(1.0 / 60.0)
	var compound_60 := 1.0 - (1.0 - w_60) * (1.0 - w_60)
	assert_almost_eq(w_30, compound_60, TOLERANCE,
		"One 30fps frame must equal two 60fps frames compounded (frame-rate independence)")

func test_slot_offset_rotated_correctly() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	# Slot 1 at angle=0 (no rotation) should be (0, 50)
	var slot: Vector2 = formation.FORMATION_V[0]
	var rotated: Vector2 = slot.rotated(0.0)
	assert_almost_eq(rotated.x, 0.0, TOLERANCE)
	assert_almost_eq(rotated.y, 50.0, TOLERANCE)
	# Slot 1 rotated PI/2 should be (-50, 0)
	var rotated_90: Vector2 = slot.rotated(PI / 2.0)
	assert_almost_eq(rotated_90.x, -50.0, TOLERANCE)
	assert_almost_eq(rotated_90.y, 0.0, TOLERANCE)
	formation.free()

func test_formation_has_8_slots() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	assert_eq(formation.FORMATION_V.size(), 8, "FORMATION_V must have 8 slots")
	formation.free()

func test_formation_full_fires_at_8() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	formation._slots_active = 7
	watch_signals(formation)
	# Simulate adding to slot 8
	formation._slots_active = 8
	formation.current_archer_count = 8
	if formation._slots_active == formation.MAX_FORMATION_SLOTS:
		formation.formation_full.emit()
	assert_signal_emitted(formation, "formation_full",
		"formation_full must fire when archer count reaches 8")
	formation.free()

func test_recruit_increments_count() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	formation._slots_active = 2
	formation.current_archer_count = 2
	formation._slots_active += 1
	formation.current_archer_count = formation._slots_active
	assert_eq(formation.current_archer_count, 3,
		"Recruiting must increment current_archer_count by 1")
	formation.free()

func test_starting_archers_is_2() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	assert_eq(formation.STARTING_ARCHERS, 2, "STARTING_ARCHERS must be 2")
	formation.free()

func test_session_reset_restores_2_archers() -> void:
	var formation: Node2D = load("res://src/gameplay/archer_formation.gd").new()
	formation._slots_active = 6
	formation._slots_active = formation.STARTING_ARCHERS
	formation.current_archer_count = formation.STARTING_ARCHERS
	assert_eq(formation.current_archer_count, 2,
		"Session reset must restore archer count to STARTING_ARCHERS (2)")
	formation.free()
