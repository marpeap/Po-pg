## Unit tests for HeroSpells — 3 AoE spell slots (Embrasement, Foudre, Glace)
## Story: Sprint 7 — Phase 1 spells
## GUT 9.6.0 — extends GutTest
extends GutTest

## Helper — creates a bare HeroSpells node outside the scene tree.
## is_inside_tree() returns false, so cast() no-ops safely in tests.
func _make_spells() -> Node:
	return load("res://src/gameplay/hero_spells.gd").new()

# ---------------------------------------------------------------------------
# SPELLS array constants
# ---------------------------------------------------------------------------

func test_spell_count_is_3() -> void:
	var hs: Node = _make_spells()
	assert_eq(hs.SPELLS.size(), 3, "Must have exactly 3 spells")
	hs.free()

func test_embrasement_stats() -> void:
	var hs: Node = _make_spells()
	var s: Dictionary = hs.SPELLS[0]
	assert_eq(s["name"],          "Embrasement", "Spell 0 name")
	assert_eq(s["damage"],        80,            "Embrasement damage")
	assert_almost_eq(s["radius"], 150.0, 0.001,  "Embrasement radius")
	assert_almost_eq(s["slow_factor"], 1.0, 0.001, "Embrasement has no slow")
	assert_almost_eq(s["cooldown"],    8.0, 0.001, "Embrasement cooldown")
	hs.free()

func test_foudre_stats() -> void:
	var hs: Node = _make_spells()
	var s: Dictionary = hs.SPELLS[1]
	assert_eq(s["name"],    "Foudre", "Spell 1 name")
	assert_eq(s["damage"],  30,       "Foudre damage")
	assert_almost_eq(s["radius"],       120.0,  0.001, "Foudre radius")
	assert_almost_eq(s["slow_factor"],  0.001,  0.0001, "Foudre stun factor")
	assert_almost_eq(s["slow_duration"], 2.5,   0.001, "Foudre stun duration")
	assert_almost_eq(s["cooldown"],     12.0,   0.001, "Foudre cooldown")
	hs.free()

func test_glace_stats() -> void:
	var hs: Node = _make_spells()
	var s: Dictionary = hs.SPELLS[2]
	assert_eq(s["name"],    "Glace", "Spell 2 name")
	assert_eq(s["damage"],  40,      "Glace damage")
	assert_almost_eq(s["radius"],       180.0, 0.001, "Glace radius")
	assert_almost_eq(s["slow_factor"],  0.30,  0.001, "Glace 70% slow")
	assert_almost_eq(s["slow_duration"], 4.0,  0.001, "Glace slow duration")
	assert_almost_eq(s["cooldown"],     10.0,  0.001, "Glace cooldown")
	hs.free()

# ---------------------------------------------------------------------------
# Cooldown state
# ---------------------------------------------------------------------------

func test_all_spells_ready_at_start() -> void:
	var hs: Node = _make_spells()
	assert_true(hs.is_ready(0), "Embrasement must be ready at start")
	assert_true(hs.is_ready(1), "Foudre must be ready at start")
	assert_true(hs.is_ready(2), "Glace must be ready at start")
	hs.free()

func test_cooldown_remaining_zero_at_start() -> void:
	var hs: Node = _make_spells()
	assert_almost_eq(hs.get_cooldown_remaining(0), 0.0, 0.001, "No cooldown at start")
	assert_almost_eq(hs.get_cooldown_remaining(1), 0.0, 0.001, "No cooldown at start")
	assert_almost_eq(hs.get_cooldown_remaining(2), 0.0, 0.001, "No cooldown at start")
	hs.free()

func test_cooldown_remaining_never_negative() -> void:
	var hs: Node = _make_spells()
	## Manually force a negative cooldown — get_cooldown_remaining must clamp to 0
	hs._cooldowns[0] = -5.0
	assert_almost_eq(hs.get_cooldown_remaining(0), 0.0, 0.001,
		"get_cooldown_remaining must never return negative")
	hs.free()

# ---------------------------------------------------------------------------
# cast() — safety guard (not in scene tree)
# ---------------------------------------------------------------------------

func test_cast_no_ops_when_not_in_tree() -> void:
	## Node is NOT added to the scene — is_inside_tree() returns false.
	## cast() must return without crashing and without emitting the signal.
	var hs: Node = _make_spells()
	var emitted: bool = false
	hs.spell_cast.connect(func(_idx: int) -> void: emitted = true)
	hs.cast(0, Vector2.ZERO)
	assert_false(emitted, "spell_cast must NOT emit when not in the scene tree")
	## Cooldown must also not be set (no-op)
	assert_true(hs.is_ready(0), "Spell must still be ready after tree-guard no-op")
	hs.free()

func test_cast_no_ops_when_on_cooldown() -> void:
	var hs: Node = _make_spells()
	## Manually set cooldown so is_ready returns false
	hs._cooldowns[2] = 5.0
	var emitted: bool = false
	hs.spell_cast.connect(func(_idx: int) -> void: emitted = true)
	## cast() must bail early — cooldown guard fires before is_inside_tree guard
	hs.cast(2, Vector2.ZERO)
	assert_false(emitted, "spell_cast must NOT emit when spell is on cooldown")
	hs.free()

# ---------------------------------------------------------------------------
# Session reset
# ---------------------------------------------------------------------------

func test_session_reset_clears_all_cooldowns() -> void:
	var hs: Node = _make_spells()
	hs._cooldowns[0] = 8.0
	hs._cooldowns[1] = 12.0
	hs._cooldowns[2] = 10.0
	hs._on_session_reset()
	assert_almost_eq(hs._cooldowns[0], 0.0, 0.001, "Embrasement cooldown cleared on reset")
	assert_almost_eq(hs._cooldowns[1], 0.0, 0.001, "Foudre cooldown cleared on reset")
	assert_almost_eq(hs._cooldowns[2], 0.0, 0.001, "Glace cooldown cleared on reset")
	hs.free()

func test_is_ready_after_session_reset() -> void:
	var hs: Node = _make_spells()
	hs._cooldowns[0] = 5.0
	hs._on_session_reset()
	assert_true(hs.is_ready(0), "All spells must be ready after session reset")
	hs.free()
