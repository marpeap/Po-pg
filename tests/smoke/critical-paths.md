# Smoke Test: Critical Paths — Garrison

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Engine**: Godot 4.6
**Update**: Add new entries when new core systems are implemented.

---

## Core Stability (always run)

1. Project opens in Godot 4.6 without import errors
2. Main scene (`res://src/main/main.tscn`) loads without crash
3. GUT tests pass: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

## Core Mechanic

4. Hero moves with virtual joystick (bottom-left, fixed anchor)
5. Camera follows hero — does NOT show black edges at world boundaries
6. Enemies spawn and march toward castle position
7. Formation arrows spawn, travel, and hit enemies (enemy HP decreases)
8. Gold coins spawn on enemy death and are attracted by hero magnet
9. Zone dwell (0.8s in RECRUIT_ZONE) triggers archer recruitment
10. Session resets correctly after GAME_OVER (gold=60, archers=2, castle HP=60)

## Economy

11. Archer slot count increases from 2 → 3 after first RECRUIT_ZONE dwell
12. Gold display decreases by 30 after T1 recruit
13. TOWER_ZONE purchase deducts 100g and releases 2 formation slots

## HUD

14. Gold counter updates visibly when gold changes
15. Castle HP bar decreases visibly on enemy contact
16. HUD stays fixed to screen while hero moves (not in world space)

## Performance (on target Android device or profiler)

17. 20 enemies + 8 archers + active volleys: no visible frame drop below 60fps
18. No memory growth after 3 full session restarts

---

*Last updated: 2026-05-19 (test framework scaffolded)*
*Next update: when core systems are implemented*
