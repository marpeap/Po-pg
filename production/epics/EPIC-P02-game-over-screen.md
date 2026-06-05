# EPIC-P02: Game Over Screen + Session Reset UX

> **Layer**: Presentation (L5)
> **Status**: Not Started
> **Priority**: HIGH — without it, the game has no end state UX
> **GDD Source**: `design/gdd/game-state.md`
> **UX Source**: `design/ux/game-over.md`
> **Governing ADRs**: ADR-005 (GSM), ADR-007 (CanvasLayer, Tween, no scene reload), ADR-009 (no persistence)
> **Engine Risk**: LOW

---

## Summary

Implement the GAME_OVER overlay and session reset UX: a dark overlay with centered panel
showing wave reached + enemies defeated, a tap-anywhere restart interaction, and instant
in-place session reset. This completes the game loop — without it, the game cannot be
restarted after castle falls.

---

## Scope

### In Scope

- `src/ui/game_over_overlay.gd` — CanvasLayer child (same CanvasLayer as HUD), visibility driven by GSM
- Dark overlay: `Color(0.05, 0.05, 0.08, 0.70)`, full screen
- Panel: `Color(0.1, 0.08, 0.12, 0.92)`, centered ~340×280px, 12px radius corners
- Panel content:
  - "CASTLE FELL" headline — 24px, white, bold
  - "Wave reached: N" — 16px, white (reads from EnemyWave.current_wave at GAME_OVER transition)
  - "Enemies defeated: N" — 16px, white (reads from EnemyWave.total_kills)
  - "TAP ANYWHERE TO RESTART" — 14px, white, slow opacity pulse 1.0→0.6→1.0 at ~1Hz via Tween
- Panel entrance: scale 0.8→1.0 over 0.15s ease-out via Tween
- Tap-anywhere restart: any `InputEventScreenTouch` while in GAME_OVER → trigger `GameStateMachine.request_restart()`
- Session reset completeness: all systems reset via `session_reset` signal (no scene reload)
- `EnemyWave.total_kills: int` — running kill counter (requires addition to EPIC-F05 if not already there)

### Out of Scope

- High score / persistent records (ADR-009 — no persistence)
- Share/leaderboard buttons
- Settings menu
- Return to main menu (no main menu in MVP)

---

## Dependencies

- EPIC-F01 (GSM — game_state_changed → GAME_OVER, session_reset signal)
- EPIC-F05 (Enemy Wave — current_wave, total_kills)
- EPIC-P01 (HUD — same CanvasLayer parent; HUD must hide when this shows)

---

## Unblocks

Nothing — terminal epic. Completes the full game loop.

---

## Key Acceptance Criteria

- [ ] Overlay appears within the same frame as `game_state_changed → GAME_OVER`
- [ ] Dark overlay covers full 540×960 screen; frozen game world visible underneath
- [ ] Panel shows correct wave number and kill count at time of castle fall
- [ ] "TAP ANYWHERE TO RESTART" text pulses slowly (≈1Hz — under 3Hz flicker threshold)
- [ ] Tapping anywhere on screen during GAME_OVER triggers full session reset → PLAYING within one frame
- [ ] Tapping during RESETTING does not trigger a second reset
- [ ] Overlay is completely invisible during PLAYING and RESETTING states
- [ ] All text is ≥14px minimum; contrast ≥4.5:1 against panel background
- [ ] Panel entrance animation completes in ≤0.2 seconds

---

## Control Manifest Notes

- Tween ONLY for all animations (pulse, scale) — no AnimationPlayer
- No SceneTree.reload_current_scene() — in-place reset via session_reset signal
- No FileAccess — score is transient
- Pulse animation: `Tween.tween_property(label, "modulate:a", 0.6, 1.0).set_ease(Tween.EASE_IN_OUT).set_loops()`
