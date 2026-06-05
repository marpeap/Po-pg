# GUT Test Runner — Quick Reference (Garrison)

Last verified: 2026-05-19 | GUT: 9.6.0 | Engine: Godot 4.6

GUT (Godot Unit Testing) 9.6.0 is the test framework for Garrison.
Released 2026-02-24. Confirmed compatible with Godot 4.6.

---

## Installation

Install as a Godot addon from the Asset Library or by placing the addon folder at:
```
addons/gut/
```

Enable in Project Settings → Plugins → GUT → Enable.

---

## Test File Structure

```gdscript
# tests/unit/economy/test_gold_economy.gd
extends GutTest

func test_recruit_cost_deducted() -> void:
    # Arrange
    var economy := preload("res://src/systems/economy/economy.gd").new()
    economy.gold = 60

    # Act
    economy.spend(30)  # ARCHER_COST

    # Assert
    assert_eq(economy.gold, 30, "Gold should be 30 after spending 30")

func test_cannot_spend_below_zero() -> void:
    var economy := preload("res://src/systems/economy/economy.gd").new()
    economy.gold = 10
    economy.spend(30)  # Attempt to overspend
    assert_eq(economy.gold, 10, "Gold should be unchanged when insufficient")
```

---

## Core Assertions

| Assertion | Usage |
|-----------|-------|
| `assert_eq(got, expected, msg)` | Exact equality |
| `assert_ne(got, not_expected, msg)` | Not equal |
| `assert_true(value, msg)` | Is truthy |
| `assert_false(value, msg)` | Is falsy |
| `assert_almost_eq(got, expected, tolerance, msg)` | Float comparison |
| `assert_gt(got, threshold, msg)` | Greater than |
| `assert_lt(got, threshold, msg)` | Less than |
| `assert_null(value, msg)` | Is null |
| `assert_not_null(value, msg)` | Is not null |
| `assert_has(collection, item, msg)` | Collection contains item |
| `assert_does_not_have(collection, item, msg)` | Collection lacks item |

---

## Lifecycle Hooks

```gdscript
extends GutTest

var _subject  # System under test

func before_all() -> void:
    # Runs once before all tests in this file
    pass

func before_each() -> void:
    # Runs before each test — set up fresh state here
    _subject = MySystem.new()

func after_each() -> void:
    # Runs after each test — clean up
    _subject.free()

func after_all() -> void:
    # Runs once after all tests
    pass
```

---

## Headless CI Runner

Run all tests headlessly (for CI/CD):

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Flags:
- `-gdir=res://tests` — scan this directory for test files
- `-gexit` — exit Godot after tests complete (required for CI)
- `-gprefix=test_` — only run files starting with `test_` (default)
- `-glog=1` — verbose output (0=minimal, 1=normal, 2=verbose)

**Note:** The GUT readthedocs CLI page returns 404 as of 2026-05-19. Use the GUT
GitHub README or in-editor GUT panel for full flag documentation.

---

## Directory Structure (Garrison)

```
tests/
├── unit/
│   ├── economy/
│   │   └── test_gold_economy.gd
│   ├── archer_formation/
│   │   └── test_archer_formation.gd
│   ├── enemy_wave/
│   │   └── test_wave_scaling.gd
│   └── castle/
│       └── test_castle_hp.gd
└── integration/
    └── core_loop/
        └── test_recruit_dwell_trigger.gd
```

---

## What to Test vs. Not Test

**Test (automated unit tests):**
- Economy formulas (gold gain, cost checks, gold reset)
- Wave scaling formulas (ENEMY_HP_SCALING progression)
- Castle HP calculations (damage per contact, GAME_OVER trigger)
- Archer formation slot assignments
- Zone dwell timer logic (0.8s trigger)

**Do NOT automate:**
- Visual fidelity (V-formation readability, zone fill-arc appearance)
- Touch input feel (joystick responsiveness, input lag)
- Frame-rate consistency on physical Android hardware

---

## Common Mistakes

- Forgetting `-gexit` in CI — Godot hangs waiting for input after tests complete
- Not inheriting `GutTest` — file is ignored by the runner
- Testing singletons without resetting them between tests — use `before_each()` to reinstantiate
- Naming test functions without `test_` prefix — GUT skips them silently
