# EPIC-P01: HUD System

> **Layer**: Presentation (L5)
> **Status**: Not Started
> **Priority**: HIGH — economy decisions are invisible without HUD
> **GDD Source**: `design/gdd/hud.md`
> **UX Source**: `design/ux/hud.md`
> **Governing ADRs**: ADR-007 (CanvasLayer, Tween), ADR-005 (GSM)
> **Engine Risk**: LOW–MEDIUM (CanvasLayer safe area; Tween API is stable)

---

## Summary

Implement the 4-element HUD: gold counter, castle HP bar (with numeric), wave indicator,
and archer badge. All signal-driven — no per-frame reads except the wave countdown.
The HUD is the player's decision dashboard and must be legible in a single glance.

---

## Scope

### In Scope

- `src/ui/hud.gd` — CanvasLayer child, signal subscriptions, 4 elements
- Gold counter: Label node, top-left. Updates on `gold_changed`. Amber when can-afford.
- Castle HP bar: ProgressBar + Label (numeric HP). Top-center. Updates on `hp_changed`. 3 color bands.
- Wave indicator: Label. Top-right. "Wave N" / "Next: Xs". Countdown in `_process` during inter-wave.
- Archer badge: Label. Below wave label. "N/8". Updates on `recruit_purchased`. Gold when full.
- HUD strip: semi-transparent dark panel `Color(0,0,0,0.55)` spanning full width, 48px tall
- Safe area offset: read `DisplayServer.get_display_safe_area()` at `_ready()`, offset all elements
- Session initialization: read all upstream values at `game_state_changed → PLAYING`
- Visibility: visible only in PLAYING (hidden in GAME_OVER, RESETTING)

### Castle HP Bar Spec

- Width: ~280px, Height: 16px
- Fill color bands: `hp_ratio >= 0.6` → `#4CAF50`, `0.3–0.6` → `#FFC107`, `< 0.3` → `#F44336`
- Numeric label: integer HP value always visible (accessibility requirement)

### Affordability Highlight Spec

```gdscript
var cost: int = ARCHER_COST_T1 if current_archer_count < 4 else ARCHER_COST_T2
var highlight: bool = current_gold >= cost and current_archer_count < 8
gold_label.modulate = Color("#F5C518") if highlight else Color.WHITE
```

### Out of Scope

- GAME_OVER overlay (EPIC-P02)
- HUD animations (Tween fade — can add in Polish sprint)
- Forge zone indicators (Alpha)

---

## Dependencies

- EPIC-F01 (GSM — game_state_changed signal; CanvasLayer scene structure)
- EPIC-F03 (Castle — hp_changed, castle_hp, CASTLE_MAX_HP)
- EPIC-F05 (Enemy Wave — wave_started, wave_cleared, INTER_WAVE_PAUSE)
- EPIC-C01 (Economy — gold_changed, recruit_purchased, current_gold)
- EPIC-C02 (Archer Formation — formation_full, current_archer_count)

---

## Unblocks

- EPIC-P02 (Game Over — uses same CanvasLayer)

---

## Key Constants (from upstream)

| Constant | Value | Source |
|----------|-------|--------|
| `INTER_WAVE_PAUSE` | 10.0 | enemy-wave.md |
| `CASTLE_MAX_HP` | 200 | castle.md |
| `ARCHER_COST_T1` | 30 | economy.md |
| `ARCHER_COST_T2` | 60 | economy.md |
| `MAX_FORMATION_SLOTS` | 8 | archer-formation.md |

---

## Key Acceptance Criteria

- [ ] Gold counter displays integer gold, updates within one frame of `gold_changed` signal
- [ ] Gold counter turns amber when `gold >= ARCHER_COST AND archer_count < 8`
- [ ] Castle HP bar fill reflects `castle_hp / 200` ratio — correct color band at all HP levels
- [ ] Castle HP numeric value is always visible alongside the bar
- [ ] Wave label shows "Wave N" during active wave; "Next: Xs" counting down during inter-wave
- [ ] Archer badge shows "N/8" and turns gold when `formation_full` fires
- [ ] HUD is hidden in GAME_OVER and RESETTING states
- [ ] All 4 elements are correctly re-initialized on session start (gold=60, castle=200, wave=1, archers=2/8)
- [ ] HUD elements are inside the Android safe area on a device with a camera notch
- [ ] All text is ≥16px minimum rendered size

---

## Control Manifest Notes

- AnimationPlayer FORBIDDEN on HUD nodes — Tween only for any animations
- No direct reads in `_process` except countdown timer (wave indicator only)
- Safe area: `DisplayServer.get_display_safe_area()` at startup
