# EPIC-F04: Camera System

> **Layer**: Foundation (L1)
> **Status**: Not Started
> **Priority**: MEDIUM — world is 2× viewport; camera is MVP-mandatory
> **GDD Source**: `design/gdd/camera.md`
> **Governing ADRs**: ADR-001 (viewport 540×960), ADR-004 (frame-rate-independent lerp)
> **Engine Risk**: MEDIUM — Camera2D limits and smoothing behavior; verify on target device

---

## Summary

Implement Camera2D that follows the hero with frame-rate-independent lerp,
clamped to the world bounds (1080×1920). The camera converts the 2× world into
a playable scrolling view. Without it, the game world is clipped to the viewport top-left.

---

## Scope

### In Scope

- Camera2D node attached to Main scene (NOT as child of hero node)
- Hero position read each frame: `camera.position = lerp(camera.position, hero.position, weight)`
- Lerp formula: `weight = 1.0 - pow(1.0 - 0.10, delta * 60.0)` (CAMERA_LERP_F = 0.10)
- Camera limits: left=0, right=1080, top=0, bottom=1920 (world bounds)
- `position_smoothing_enabled = false` on the Camera2D node
- Camera halts updates when `GameStateMachine.current_state != PLAYING`

### Out of Scope

- Camera shake (post-MVP VFX)
- Zoom (fixed zoom throughout MVP)
- Multiple camera targets (single hero follow only)

---

## Dependencies

- EPIC-F01 (GSM — to halt camera during GAME_OVER)
- EPIC-F02 (Hero — needs hero.position reference)

---

## Unblocks

- All gameplay epics that depend on the world being navigable

---

## Key Constants

| Constant | Value | GDD / ADR |
|----------|-------|-----------|
| `CAMERA_LERP_F` | 0.10 | camera.md (validated in prototype) |
| World width | 1080 | ADR-001 |
| World height | 1920 | ADR-001 |

---

## Key Acceptance Criteria

- [ ] Camera follows hero position with smooth lerp at both 30fps and 60fps (feel must be equivalent)
- [ ] Camera never shows content outside the 1080×1920 world bounds
- [ ] Camera does not update during GAME_OVER or RESETTING states
- [ ] `Camera2D.position_smoothing_enabled` is `false`
- [ ] Camera position resets to hero start position on session reset

---

## Control Manifest Notes

- Mandatory ADR-004 lerp formula — no raw `lerp(pos, target, 0.10)` without delta
- `position_smoothing_enabled = false` is non-negotiable (forbidden pattern)
