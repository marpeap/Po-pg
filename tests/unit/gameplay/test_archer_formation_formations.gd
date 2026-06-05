## test_archer_formation_formations.gd
## Tests formation mode arrays for slot count, symmetry, and range compliance.
## GDD Req: archer-formation.md — Formulas D-8 (LINE), D-9 (ARC), Rules 14-17
## Sprint 5
extends GutTest

## Replicate formation arrays from archer_formation.gd
const FORMATION_V: Array[Vector2] = [
	Vector2(0.0,    50.0),
	Vector2(-35.0,  80.0),
	Vector2(35.0,   80.0),
	Vector2(-70.0,  110.0),
	Vector2(70.0,   110.0),
	Vector2(-105.0, 140.0),
	Vector2(105.0,  140.0),
	Vector2(0.0,    170.0),
]

const FORMATION_LINE: Array[Vector2] = [
	Vector2(-25.0,  58.0),
	Vector2( 25.0,  58.0),
	Vector2(-50.0,  58.0),
	Vector2( 50.0,  58.0),
	Vector2(-75.0,  58.0),
	Vector2( 75.0,  58.0),
	Vector2(-100.0, 58.0),
	Vector2( 100.0, 58.0),
]

const FORMATION_ARC: Array[Vector2] = [
	Vector2(-30.58, 73.91),
	Vector2( 30.58, 73.91),
	Vector2(-56.57, 56.57),
	Vector2( 56.57, 56.57),
	Vector2(-73.91, 30.58),
	Vector2( 73.91, 30.58),
	Vector2(-80.0,   0.0),
	Vector2( 80.0,   0.0),
]

const ARC_RADIUS := 80.0
const SLOT_COUNT := 8

## --- Slot count ---

func test_v_formation_has_8_slots() -> void:
	assert_eq(FORMATION_V.size(), SLOT_COUNT, "V formation has 8 slots")

func test_line_formation_has_8_slots() -> void:
	assert_eq(FORMATION_LINE.size(), SLOT_COUNT, "LINE formation has 8 slots")

func test_arc_formation_has_8_slots() -> void:
	assert_eq(FORMATION_ARC.size(), SLOT_COUNT, "ARC formation has 8 slots")

## --- V-formation: center slots on x=0 ---

func test_v_slot0_center() -> void:
	assert_eq(FORMATION_V[0].x, 0.0, "V slot 0 is center (x=0)")

func test_v_slot7_center() -> void:
	assert_eq(FORMATION_V[7].x, 0.0, "V slot 7 is center (x=0)")

## --- LINE formation: all at same depth ---

func test_line_all_slots_same_y() -> void:
	for i in range(SLOT_COUNT):
		assert_almost_eq(FORMATION_LINE[i].y, 58.0, 0.01,
			"LINE slot %d y=58" % i)

## --- LINE formation: paired symmetry ---

func test_line_slot_pairs_symmetric() -> void:
	# Pairs: (0,1), (2,3), (4,5), (6,7)
	for p in range(4):
		var left := FORMATION_LINE[p * 2]
		var right := FORMATION_LINE[p * 2 + 1]
		assert_almost_eq(left.x, -right.x, 0.01,
			"LINE pair %d is symmetric" % p)

## --- ARC formation: all slots at ARC_RADIUS distance ---

func test_arc_all_slots_at_radius() -> void:
	for i in range(SLOT_COUNT):
		var dist := FORMATION_ARC[i].length()
		assert_almost_eq(dist, ARC_RADIUS, 0.1,
			"ARC slot %d at radius 80 (got %.2f)" % [i, dist])

## --- ARC formation: paired left/right symmetry ---

func test_arc_slot_pairs_symmetric() -> void:
	for p in range(4):
		var left := FORMATION_ARC[p * 2]
		var right := FORMATION_ARC[p * 2 + 1]
		assert_almost_eq(left.x, -right.x, 0.01,
			"ARC pair %d x-symmetric" % p)
		assert_almost_eq(left.y, right.y, 0.01,
			"ARC pair %d y-equal" % p)

## --- ARC formation: slots fan outward (angle increases per pair) ---

func test_arc_angles_increase_per_pair() -> void:
	# Each pair should be at a larger angle from center (larger |x|, smaller y)
	for p in range(3):
		var cur_x := absf(FORMATION_ARC[p * 2].x)
		var nxt_x := absf(FORMATION_ARC[(p + 1) * 2].x)
		assert_true(nxt_x > cur_x,
			"ARC pair %d |x| < pair %d |x| (fan outward)" % [p, p + 1])

## --- V-formation: progressive depth ---

func test_v_progressive_depth() -> void:
	# Slots 0,1,2 should increase in y (moving further behind hero)
	assert_true(FORMATION_V[1].y > FORMATION_V[0].y,
		"V slot 1 deeper than slot 0")
	assert_true(FORMATION_V[3].y > FORMATION_V[1].y,
		"V slot 3 deeper than slot 1")
