# EPIC-F05: Enemy Wave System

> **Layer**: Foundation (L2)
> **Status**: Not Started
> **Priority**: HIGH — no gold income, no pressure without enemies
> **GDD Source**: `design/gdd/enemy-wave.md`
> **Governing ADRs**: ADR-002 (Area2D), ADR-003 (enemy pool), ADR-005 (GSM), ADR-006 (direction_to)
> **Engine Risk**: LOW — direction_to, Area2D, manual position update are stable

---

## Summary

Implement the wave spawner and enemy entity: parameterized 5-wave sequence, direction_to
steering toward castle, HP tracking, death signal (gold drop trigger), and pre-allocated
enemy pool. This epic delivers the "pressure" half of the core loop.

---

## Scope

### In Scope

- `src/gameplay/enemy_wave.gd` — wave sequencer, spawn timer, pool management
- `src/gameplay/enemy.gd` — Area2D, position update via direction_to, HP, death signal
- Enemy pool: 30 pre-allocated nodes (ADR-006)
- Wave parameters: 5-wave hardcoded table (count, HP, speed, gold_drop)
- Movement: `position += (CASTLE_POS - position).normalized() * speed * delta`
- Castle contact damage via Area2D overlap with castle Area2D
- `enemy_died(pos: Vector2)` signal on HP = 0 (for Economy gold drop)
- `wave_started(wave_number: int)` signal on wave begin
- `wave_cleared` signal when all enemies in wave are dead
- Inter-wave pause: `INTER_WAVE_PAUSE = 10.0s`
- Enemy HP bar drawn above sprite (placeholder `_draw()`)
- Single frame white flash on hit
- Session reset: drain all active enemies, reset wave_number to 0, reset timers

### Wave Parameters Table

| Wave | Count | Base HP | Speed (px/s) | Gold/kill |
|------|-------|---------|--------------|----------|
| 1 | 5 | 30 | 70 | 15 |
| 2 | 8 | 40 | 75 | 15 |
| 3 | 12 | 50 | 80 | 18 |
| 4 | 16 | 60 | 85 | 18 |
| 5 | 20 | 80 | 90 | 20 |

(Wave 5 = final wave in MVP. After wave 5 clears: GAME_OVER with victory context)

### Out of Scope

- Enemy elite/variant sprites (Alpha)
- NavigationAgent2D / NavMesh (post-MVP)
- Collision avoidance between enemies
- Boss waves (Alpha+)

---

## Dependencies

- EPIC-F01 (GSM — session_reset, current_state check)
- EPIC-F03 (Castle — CASTLE_POS constant, castle Area2D for contact detection)

---

## Unblocks

- EPIC-C01 (Economy — needs `enemy_died(pos)` signal for gold drop)
- EPIC-C02 (Archer Formation — needs enemies to shoot at)
- EPIC-P01 (HUD — needs `wave_started`, `wave_cleared` signals)

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `INTER_WAVE_PAUSE` | 10.0 | enemy-wave.md |
| `CASTLE_POS` (ref) | `Vector2(270, 62)` | castle.md |
| Enemy pool size | 30 | ADR-006 |

---

## Key Acceptance Criteria

- [ ] Wave 1 spawns 5 enemies after session start; each subsequent wave spawns per the table above
- [ ] All enemies move toward `CASTLE_POS` at correct wave speed each frame
- [ ] Enemy emits `enemy_died(pos)` when HP reaches 0 — before being returned to pool
- [ ] `wave_cleared` fires when the last enemy in the current wave dies
- [ ] `wave_started(n)` fires at the start of each new wave
- [ ] Inter-wave pause of 10.0s separates each wave (HUD countdown mirrors this)
- [ ] After wave 5 clears: a final wave_cleared fires; no wave 6 spawns (game ends)
- [ ] Enemy pool never instantiates during gameplay — only pre-allocated nodes used
- [ ] Session reset: all active enemies removed from scene, pool drained, wave counter reset

---

## Control Manifest Notes

- direction_to only — no NavigationAgent2D
- Area2D for enemies (not CharacterBody2D)
- CollisionShape2D disabled on pool return
- Enemy pool pre-allocated in `_ready()`
