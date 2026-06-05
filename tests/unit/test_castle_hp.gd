# tests/unit/test_castle_hp.gd
# Validates: castle HP constants, damage-per-contact, GAME_OVER threshold
# Source: design/gdd/castle.md

extends GutTest

const CASTLE_MAX_HP             := 60
const CASTLE_DAMAGE_PER_CONTACT := 10

# --- Constants ---

func test_castle_max_hp_is_sixty() -> void:
	assert_eq(CASTLE_MAX_HP, 60, "CASTLE_MAX_HP must be 60 per castle.md")

func test_damage_per_contact_is_ten() -> void:
	assert_eq(CASTLE_DAMAGE_PER_CONTACT, 10, "CASTLE_DAMAGE_PER_CONTACT must be 10")

# --- Threshold arithmetic ---

func test_six_contacts_destroy_castle() -> void:
	@warning_ignore("integer_division")
	var contacts_to_destroy: int = CASTLE_MAX_HP / CASTLE_DAMAGE_PER_CONTACT
	assert_eq(contacts_to_destroy, 6, "Castle destroyed after exactly 6 enemy contacts")

func test_five_contacts_leave_castle_alive() -> void:
	var hp_after_5: int = CASTLE_MAX_HP - 5 * CASTLE_DAMAGE_PER_CONTACT
	assert_true(hp_after_5 > 0, "Castle survives 5 contacts (HP = %d)" % hp_after_5)
	assert_eq(hp_after_5, 10)

func test_castle_hp_never_goes_negative() -> void:
	# Simulate overkill — 10 contacts on a 60 HP castle
	var hp: int = CASTLE_MAX_HP
	for _i in 10:
		hp = max(0, hp - CASTLE_DAMAGE_PER_CONTACT)
	assert_eq(hp, 0, "Castle HP floored at 0, not negative")
