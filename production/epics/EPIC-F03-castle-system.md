# EPIC-F03: Castle System

> **Layer**: Foundation (L1)
> **Status**: Not Started
> **Priority**: HIGH — Castle HP is the core tension signal; Enemy Wave depends on CASTLE_POS
> **GDD Source**: `design/gdd/castle.md`
> **Governing ADRs**: ADR-002 (Area2D), ADR-005 (GSM castle_fell signal)
> **Engine Risk**: LOW

---

## Summary

Implement the castle entity: a static target with HP, damage reception on enemy contact,
and the `castle_fell` signal that triggers GAME_OVER. The castle owns `CASTLE_MAX_HP`
and emits `hp_changed` for the HUD. It is a simple passive entity — it does not move
or act, it only receives damage.

---

## Scope

### In Scope

- `src/gameplay/castle.gd` — Node2D + Area2D, HP tracking, damage receipt, signal emission
- `CASTLE_MAX_HP = 200`, `CASTLE_POS = Vector2(270, 62)` as exported constants
- `castle_hp: int` property (read-only from outside)
- `hp_changed(new_hp: int)` signal — emitted on every damage event
- `castle_fell` signal — emitted once when `castle_hp <= 0`
- Enemy contact damage: 8 HP per contact (`CASTLE_DMG = 8`)
- Session reset: restore `castle_hp = CASTLE_MAX_HP`
- Castle visual placeholder: circle `#9B9B9B` in `_draw()` with HP color modulate

### Out of Scope

- Castle sprite art
- Castle damage visual states (crack sprite — Alpha milestone)
- Castle max HP upgrades (Forge — Alpha)

---

## Dependencies

- EPIC-F01 (GameStateMachine for session_reset signal)

---

## Unblocks

- EPIC-F05 (Enemy Wave — needs `CASTLE_POS` constant)
- EPIC-P01 (HUD — needs `hp_changed` signal and `CASTLE_MAX_HP`)

---

## Key Constants

| Constant | Value | GDD |
|----------|-------|-----|
| `CASTLE_MAX_HP` | 200 | castle.md |
| `CASTLE_POS` | `Vector2(270, 62)` | castle.md |
| `CASTLE_DMG` | 8 | castle.md |

---

## Key Acceptance Criteria

- [ ] Castle HP starts at 200 on session start
- [ ] Castle emits `hp_changed(new_hp)` within the same frame as each damage event
- [ ] Castle emits `castle_fell` exactly once when HP first reaches or drops below 0
- [ ] If two enemies contact the castle in the same frame: HP decrements by 8 per contact, clamped to 0; exactly one `castle_fell` signal fires
- [ ] `castle_fell` does not fire again if already in GAME_OVER state
- [ ] Castle HP resets to 200 on `session_reset` signal
- [ ] Castle is drawn at `CASTLE_POS` in world space with correct scale

---

## Control Manifest Notes

- Castle damage detection uses Area2D overlap (enemy enters castle contact zone)
- Castle does not use CharacterBody2D
- `castle_fell` triggers GSM transition — castle does not call GSM directly; GSM listens for the signal
