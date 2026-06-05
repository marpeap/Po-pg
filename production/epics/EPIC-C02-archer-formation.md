# EPIC-C02: Archer Formation System

> **Layer**: Core (L3)
> **Status**: Not Started
> **Priority**: HIGH — primary power expression; Pillar 3 "L'armée se voit grandir"
> **GDD Source**: `design/gdd/archer-formation.md`
> **Governing ADRs**: ADR-002 (Area2D), ADR-003 (arrow pool), ADR-004 (lerp formula), ADR-005 (GSM), ADR-008 (AudioManager)
> **Engine Risk**: LOW–MEDIUM (ADR-004 lerp — verify at 30fps)

---

## Summary

Implement the archer formation: 8 formation slots in a V behind the hero, archers that
lerp to their slots using ADR-004 formula, auto-fire volleys toward the nearest enemy,
and arrow projectiles (pooled). This epic delivers the "army grows around you" visual
and the primary DPS output.

---

## Scope

### In Scope

- `src/gameplay/archer_formation.gd` — slot calculation, archer follow, volley management
- `src/gameplay/archer.gd` — individual archer node, position lerp, visual
- `src/gameplay/arrow.gd` — pooled projectile Area2D, movement, hit detection
- V-formation: 8 slots, positions relative to hero at `facing_angle + PI/2`
- Formation slot offsets (V shape, 8 positions — hardcoded array):
  - Slot 1 (center rear): offset `(0, 40)`
  - Slots 2–3 (second rank): offsets `(-30, 70)`, `(30, 70)`
  - Slots 4–5 (third rank): offsets `(-60, 100)`, `(60, 100)`
  - Slots 6–7 (fourth rank): offsets `(-90, 130)`, `(90, 130)`
  - Slot 8 (rear center): offset `(0, 160)` (only with full formation)
  - (offsets in facing-angle rotated space — rotate by `facing_angle + PI/2`)
- Archer lerp: `weight = 1.0 - pow(1.0 - 0.12, delta * 60.0)` (ARCHER_LERP_F = 0.12)
- Starting archers: 2 (`STARTING_ARCHERS = 2`)
- Auto-fire: all active archers fire simultaneously at nearest enemy, every `SHOOT_IVTL = 1.2s`
- Arrow pool: 24 pre-allocated arrow Area2D nodes (ADR-003)
- Arrow speed: `PROJ_SPEED = 400.0 px/s`
- Arrow damage: `PROJ_DAMAGE = 8` (matches enemy HP per GDD)
- Arrow max range: `SHOOT_RANGE = 300.0 px` — arrow disappears if it travels beyond range
- `current_archer_count: int` read-only property
- `formation_full` signal when archer_count reaches 8
- `recruit_purchased` listener: adds archer to next available slot
- On session reset: reset to 2 archers, return all arrows to pool, reset volley timer
- Audio: `AudioManager.play_volley(current_archer_count)` on each volley
- Archer placeholder: small circle `#C8962A` per archer
- Arrow placeholder: line or small circle `#F5C518`

### Out of Scope

- Archer Tower detachment (EPIC-FT01)
- Forge damage/speed upgrades (Alpha)
- Archer death/removal from formation

---

## Dependencies

- EPIC-F01 (GSM — session_reset)
- EPIC-F02 (Hero — hero.position, hero.facing_angle)
- EPIC-F05 (Enemy Wave — enemies to target)
- EPIC-C01 (Economy — recruit_purchased signal)

---

## Unblocks

- EPIC-FT01 (Archer Tower — archers can be transferred)
- EPIC-P01 (HUD — needs current_archer_count, formation_full signal)

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `STARTING_ARCHERS` | 2 | archer-formation.md |
| `MAX_FORMATION_SLOTS` | 8 | archer-formation.md |
| `ARCHER_LERP_F` | 0.12 | archer-formation.md |
| `SHOOT_IVTL` | 1.2 | archer-formation.md |
| `SHOOT_RANGE` | 300.0 | archer-formation.md |
| `PROJ_SPEED` | 400.0 | archer-formation.md |
| `PROJ_DAMAGE` | 8 | archer-formation.md |
| Arrow pool size | 24 | ADR-003 |

---

## Key Acceptance Criteria

- [ ] Session starts with 2 archers following the hero in V-formation
- [ ] Archers lerp to their formation slots each frame using ADR-004 formula (feel identical at 30fps and 60fps)
- [ ] Formation rotates as the hero's facing angle changes
- [ ] All active archers fire simultaneously every 1.2s at the nearest enemy within range
- [ ] Arrows are drawn from the archer pool, not instantiated — pool never starves under normal play
- [ ] Arrow disappears when it hits an enemy (returns to pool) or exceeds SHOOT_RANGE
- [ ] Enemy loses 8 HP on arrow hit; emits `enemy_died` signal when HP reaches 0
- [ ] `recruit_purchased` adds an archer to the next available slot
- [ ] `formation_full` fires when archer count reaches 8
- [ ] `current_archer_count` is readable and accurate at all times
- [ ] Session reset: 2 archers, no arrows in flight, volley timer reset

---

## Control Manifest Notes

- ADR-004 lerp formula is MANDATORY — no raw lerp without delta
- Arrow pool: pre-allocate 24 in `_ready()`; disable CollisionShape2D on return
- Audio via AudioManager.play_volley(n) — no AudioStreamPlayer in this script
