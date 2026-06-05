# Requirements Traceability Index — Garrison

> **Version**: 1.1
> **Last Updated**: 2026-05-19 (ADR-005–009 gap resolution)
> **Source Architecture**: `docs/architecture/architecture.md` v1.0
> **ADRs Covered**: ADR-001 through ADR-009 (all Accepted)
> **Status**: Complete — 26/26 requirements traced, 0 Foundation gaps

---

## Coverage Summary

| Layer | Requirements | Traced | Gaps |
|-------|-------------|--------|------|
| Foundation | 3 (GSM FSM, GSM signals, Session reset) | 3 | **0** |
| Core | 15 | 15 | 0 |
| Feature | 4 | 4 | 0 |
| Presentation | 4 | 4 | 0 |
| **Total** | **26** | **26** | **0** |

---

## Foundation Layer Requirements

| Req ID | GDD Source | Requirement | ADR Coverage | Status |
|--------|-----------|-------------|-------------|--------|
| TR-gsm-001 | `game-state.md` | Game State Machine: 5-state FSM (LOADING, SESSION_RESET, PLAYING, WAVE_CLEAR, GAME_OVER) — global singleton | ADR-005: Game State Machine / Autoload | ✅ |
| TR-gsm-002 | `game-state.md` | GSM emits signals: `game_state_changed(new_state)`, session reset signal | ADR-005 + Architecture Data Flow §3 | ✅ |
| TR-persist-001 | `game-state.md` | No file persistence in MVP — session-only state | ADR-009: Session Persistence (No Save) | ✅ |

---

## Core Layer Requirements

| Req ID | GDD Source | Requirement | ADR Coverage | Status |
|--------|-----------|-------------|-------------|--------|
| TR-hero-001 | `hero-movement.md` | Fixed-anchor virtual joystick at (135, 800) in 540×960 viewport space | ADR-005, Architecture Module Ownership (HeroMovement) | ✅ |
| TR-hero-002 | `hero-movement.md` | `hero_pos: Vector2` and `facing_angle: float` readable per-frame by Economy, ArcherFormation | Architecture API Boundaries (HeroMovement) | ✅ |
| TR-hero-003 | `hero-movement.md` | SHOOT_IVTL shared timer tick — fire interval owned by ArcherFormation | Architecture API Boundaries | ✅ |
| TR-cam-001 | `camera.md` | Camera2D follows hero with frame-rate-independent lerp factor 0.10 | ADR-004: Frame-Rate-Independent Lerp | ✅ |
| TR-cam-002 | `camera.md` | Camera constrained to world 1080×1920; viewport 540×960 | ADR-001: Viewport Resolution | ✅ |
| TR-castle-001 | `castle.md` | Enemies damage castle on Area2D overlap; 10 HP per contact | ADR-002: Physics Policy (Area2D only) | ✅ |
| TR-castle-002 | `castle.md` | `castle_destroyed` signal emitted when `castle_hp ≤ 0` | Architecture API Boundaries | ✅ |
| TR-wave-001 | `enemy-wave.md` | 13-wave parameterized spawn: HP = 30 + (wave−1)×3; count = 5 + floor(wave×1.15) | Architecture Module Ownership (EnemyWave) | ✅ |
| TR-wave-002 | `enemy-wave.md` | Enemy steering: `direction_to(castle_pos) × ENEMY_SPEED`; no NavigationAgent2D in MVP | ADR-006: Enemy Pathfinding (direction_to) | ✅ |
| TR-wave-003 | `enemy-wave.md` | `enemy_died(position: Vector2)` signal emitted on enemy death | Architecture API Boundaries | ✅ |
| TR-eco-001 | `economy.md` | Zone dwell trigger: Area2D proximity (r=90px) + 0.8s hold timer | ADR-002: Physics Policy (Area2D) | ✅ |
| TR-eco-002 | `economy.md` | Gold magnet: Area2D proximity (r=170px) auto-collects coins | ADR-002: Physics Policy (Area2D) | ✅ |
| TR-eco-003 | `economy.md` | Deterministic costs: ARCHER_COST_T1=30g, ARCHER_COST_T2=60g, TOWER_COST=100g | Architecture Module Ownership (Economy) | ✅ |
| TR-eco-004 | `economy.md` | session_reset resets `gold = STARTING_GOLD (60g)`, clears all coins | ADR-005 + Architecture Data Flow §3 | ✅ |

---

## Feature Layer Requirements

| Req ID | GDD Source | Requirement | ADR Coverage | Status |
|--------|-----------|-------------|-------------|--------|
| TR-form-001 | `archer-formation.md` | 8-slot V-formation computed per-frame around hero | Architecture Module Ownership (ArcherFormation) | ✅ |
| TR-form-002 | `archer-formation.md` | Object pool: 24 arrows + 8 impact effects + 16 coins + 30 enemies | ADR-003: Object Pool Pattern + ADR-006 | ✅ |
| TR-form-003 | `archer-formation.md` | `tower_purchased` signal releases 2 archer slots back to formation | Architecture Data Flow §2 + API Boundaries | ✅ |
| TR-form-004 | `archer-formation.md` | Archer follow position lerp factor 0.12 (frame-rate independent) | ADR-004: Frame-Rate-Independent Lerp | ✅ |
| TR-tower-001 | `archer-tower.md` | Tower placement deducts 100g and releases 2 archer formation slots (R3 contract) | Architecture API Boundaries (ArcherTower) | ✅ |
| TR-tower-002 | `archer-tower.md` | Tower fires independently on its own SHOOT_IVTL timer (not synced to formation) | Architecture Module Ownership (ArcherTower) | ✅ |
| TR-forge-001 | `forge.md` | 4 dedicated FORGE_ZONEs (DMG / SPD / MAG / HP) placed in world space — Alpha milestone | Architecture Module Ownership (Forge) | ✅ |
| TR-forge-002 | `forge.md` | Forge emits PROJ_DAMAGE_UP and SHOOT_IVTL_DOWN signals on dwell purchase | Architecture Module Ownership (Forge) | ✅ |

---

## Presentation Layer Requirements

| Req ID | GDD Source | Requirement | ADR Coverage | Status |
|--------|-----------|-------------|-------------|--------|
| TR-hud-001 | `hud.md` | HUD is a CanvasLayer with `layer = 1`; all containers have `MOUSE_FILTER_IGNORE` | ADR-007: Scene Architecture / HUD Layout | ✅ |
| TR-hud-002 | `hud.md` | HUD visible only in PLAYING / WAVE_CLEAR states; hidden in GAME_OVER and SESSION_RESET | ADR-005 + Architecture Data Flow §2 | ✅ |
| TR-audio-001 | `archer-formation.md` | Volley fire audio: non-positional, scales `lerp(-6dB, 0dB, (n-2)/6)` with archer count | ADR-008: Audio Architecture | ✅ |
| TR-audio-002 | (implied all GDDs) | All audio non-positional in MVP; AudioManager autoload; no AudioStreamPlayer2D | ADR-008: Audio Architecture | ✅ |

---

## ADR Cross-Reference

| ADR | Title | Status | Requirements Covered |
|-----|-------|--------|----------------------|
| ADR-001 | Viewport Resolution | Accepted | TR-cam-002 |
| ADR-002 | Physics Policy | Accepted | TR-castle-001, TR-eco-001, TR-eco-002 |
| ADR-003 | Object Pool Pattern | Accepted | TR-form-002 (partial — ADR-006 covers enemy pool) |
| ADR-004 | Frame-Rate-Independent Lerp | Accepted | TR-cam-001, TR-form-004 |
| ADR-005 | Game State Machine / Autoload | Accepted | TR-gsm-001, TR-gsm-002, TR-hero-001, TR-eco-004, TR-hud-002 |
| ADR-006 | Enemy Pathfinding (direction_to) | Accepted | TR-wave-002, TR-form-002 (enemy pool) |
| ADR-007 | Scene Architecture / HUD Layout | Accepted | TR-hud-001 |
| ADR-008 | Audio Architecture | Accepted | TR-audio-001, TR-audio-002 |
| ADR-009 | Session Persistence (No Save) | Accepted | TR-persist-001 |

---

## Foundation Layer Gap Verification

**Gate requirement**: Architecture traceability matrix must have zero Foundation layer gaps
before advancing to Pre-Production.

| Foundation Requirement | Gap at architecture.md v1.0 | Resolution |
|------------------------|----------------------------|------------|
| TR-gsm-001 (Game State Machine FSM) | ❌ GAP — ADR-005 required | ✅ ADR-005 Accepted 2026-05-19 |
| TR-gsm-002 (GSM signals) | ✅ at v1.0 | ✅ |
| TR-persist-001 (No save in MVP) | ❌ GAP — ADR-009 required | ✅ ADR-009 Accepted 2026-05-19 |

**Foundation layer gaps at current state: 0**

---

## Deferred Requirements (Post-MVP)

These requirements were identified in GDDs but are deliberately deferred to post-MVP
milestones. They do not count as traceability gaps:

| Req | GDD | Deferral Reason |
|-----|-----|-----------------|
| NavigationAgent2D pathfinding | `enemy-wave.md` | Direction_to sufficient for MVP; NavMesh deferred to Alpha/Beta |
| Forge zone state machine | `forge.md` | Forge inactive in MVP and Vertical Slice; activates at Alpha |
| Tower arrow pool extension | `archer-tower.md` | Tower pool sizing requires tower implementation data; update ADR-003 at implementation |
| FileAccess save system | Multiple | No save in MVP per ADR-009; implement post-MVP |
| High-score persistence | `game-state.md` | Session-only display in MVP; persist post-MVP |

---

*Traceability index last updated: 2026-05-19*
*Next update: when `/architecture-review` is re-run or new ADRs are written*
