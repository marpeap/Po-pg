# Test Infrastructure — Garrison

**Engine**: Godot 4.6
**Test Framework**: GUT (Godot Unit Testing) 9.6.0
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-19

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

### In-editor (GUT panel)
Open the GUT panel in the Godot editor and click Run All.

### Headless (CI / command line)
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Flags:
- `-gdir=res://tests` — scan this directory recursively for test files
- `-gexit` — exit after tests complete (required for CI — without it Godot hangs)
- `-gprefix=test_` — only run files starting with `test_` (default)
- `-glog=1` — normal verbosity (0=minimal, 2=verbose)

### Installing GUT 9.6.0
1. Godot Editor → AssetLib → search "GUT" → Download & Install
2. Project → Project Settings → Plugins → GUT → Enable
3. Verify: `res://addons/gut/` exists
4. Restart editor

> **Note**: The GUT readthedocs CLI page returns 404 as of 2026-05-19.
> Use the GUT GitHub README or in-editor panel for full documentation.
> See also: `docs/engine-reference/godot/modules/gut-runner.md`

## Test Naming Conventions

- **Files**: `test_[system]_[feature].gd` (e.g., `test_economy_gold.gd`)
- **Functions**: `test_[scenario]_[expected_result]()` (e.g., `test_recruit_cost_deducted()`)
- **Class**: `extends GutTest`
- **Directory**: `tests/unit/[system]/test_[feature].gd`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, state) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| **UI** | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| **Config/Data** | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## What to Test (Garrison-specific)

**Automate:**
- Economy formulas (gold gain, recruit costs, reset to 60g)
- Wave scaling formulas (enemies_per_wave, enemy_hp progression)
- Castle HP calculations (damage per contact, GAME_OVER threshold)
- Archer formation slot assignments (fill order, cap at 8, slot release on tower purchase)
- Zone dwell timer logic (0.8s trigger, reset on exit)

**Do NOT automate:**
- Visual fidelity (V-formation readability, zone arc appearance)
- Touch input feel (joystick responsiveness, input lag)
- Frame-rate consistency on physical Android hardware

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.
See `.github/workflows/tests.yml`.
