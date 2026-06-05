# GAME_OVER Overlay Manual Walkthrough Evidence
## Story: P02-S01
## Date: TBD (complete during Sprint 4 playtest)
## Status: PENDING — walkthrough required before story-done

## Checklist

- [ ] 1. Moment of castle fall — GAME_OVER overlay appears on same frame as game_state_changed(GAME_OVER)
- [ ] Overlay covers full screen; game world visible underneath (semi-transparent dark layer)
- [ ] Panel shows correct "Wave reached: N" from enemy_wave.current_wave
- [ ] Panel shows correct "Enemies defeated: N" from enemy_wave.total_kills
- [ ] "TAP ANYWHERE TO RESTART" label visible and pulses at ~1Hz via Tween
- [ ] Panel entrance scale animation plays (0.8 → 1.0 in ≤0.2s)
- [ ] No AnimationPlayer used — inspector confirms Tween only

- [ ] 2. Post-tap — game restarted, overlay gone
- [ ] Tap anywhere during GAME_OVER triggers GameStateMachine.request_restart()
- [ ] Overlay becomes invisible immediately on RESETTING transition
- [ ] Tap during RESETTING does NOT trigger another restart

- [ ] 3. Session reset verified
- [ ] After restart: HUD visible, gold = 60, wave label = "Wave 1"
- [ ] Overlay hidden during PLAYING state

## Screenshots

- `production/qa/evidence/game-over-screenshots/overlay-appears.png` — TBD
- `production/qa/evidence/game-over-screenshots/stats-visible.png` — TBD
- `production/qa/evidence/game-over-screenshots/post-restart.png` — TBD

## Sign-Off

Lead sign-off: ___________________ Date: ___________
