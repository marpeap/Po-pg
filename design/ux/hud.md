# HUD Design — Garrison

> **Status**: Complete
> **Author**: ux-designer
> **Last Updated**: 2026-05-19
> **Template**: HUD Design
> **Input Methods**: Touch only (Android). No keyboard, no gamepad, no hover.
> **GDD Source**: `design/gdd/hud.md`

---

## HUD Philosophy

Garrison's HUD is a **minimal information strip** — a single semi-transparent
dark band at the top of the screen that holds exactly four persistent displays.
The philosophy is *"dashboard, not panel"*: the player absorbs all four values
in a single downward glance without breaking joystick focus. Every element
communicates one decision-relevant fact. Nothing else lives on the HUD.

**Design constraint**: The HUD must remain legible while the thumb is actively
on the joystick. The player's eyes are in the bottom 40% of the screen. The top
strip is the only place safe from occlusion by the hand.

**Category: Information-dense (top strip only)** — all decision data always
visible during PLAYING, nothing visible during GAME_OVER.

---

## Information Architecture

### Full Information Inventory

Sourced from GDD UI Requirements (`design/gdd/hud.md`):

| # | Information | Source System | GDD Rule |
|---|-------------|--------------|----------|
| 1 | Current gold (integer) | Economy | Rule 5, D.7 |
| 2 | Affordability signal (can recruit?) | Economy | Rule 7, D.6 |
| 3 | Castle current HP (integer) | Castle | Rule 8 |
| 4 | Castle HP ratio (visual bar) | Castle | Rule 8, D.1 |
| 5 | Castle HP threat level (color) | Castle | Rule 10, D.2 |
| 6 | Current wave number | Enemy Wave | Rule 11 |
| 7 | Inter-wave countdown (seconds) | Enemy Wave | Rules 12–15, D.3 |
| 8 | Archer formation count (N/8) | Archer Formation | Rule 16, D.5 |
| 9 | Formation full state | Archer Formation | Rule 19 |

### Categorization

| Category | Items |
|----------|-------|
| **Must Show** | #1 (gold), #3 (castle HP numeric), #4 (castle bar), #6 (wave), #7 (countdown), #8 (archer badge) |
| **Contextual** | #2 (affordability color shift — visible only when recruit is possible), #5 (color band on bar — always showing, changes meaning), #9 (badge fill state — only when formation full) |
| **Hidden** | None — all HUD info is on-screen text/visual |

---

## Layout Zones

### Zone Arrangement

Single horizontal strip at the very top of the 540×960 viewport, inside safe-area insets.

```
┌────────────────────────────────────────────────────────────┐
│  (safe area margin — no content above this line)           │
├──────────────────────────────────────────────────────────────
│ [GOLD]      [CASTLE HP BAR ▓▓▓▓▓▓▓▓░░] 142  [WAVE] [ARCHERS]
├──────────────────────────────────────────────────────────────
│  (game world below)                                         │
```

**Strip height**: 48px logical (safe-area-relative y = 0 to 48).
**Background**: semi-transparent dark overlay (`Color(0,0,0,0.55)`) spanning
full 540px width, 48px height. Provides contrast for all text and bar.

### Element Zones

| Zone | Element | Anchor | Alignment | Size |
|------|---------|--------|-----------|------|
| LEFT | Gold counter | Top-left + 12px inset | Left-align | ~80px wide |
| CENTER-LEFT | Castle HP bar | Centered, margin from gold + wave zones | Center | ~280px wide |
| CENTER-RIGHT | Castle HP numeric | Right of bar fill | Center-right | ~40px |
| RIGHT-TOP | Wave indicator | Top-right + 12px inset | Right-align | ~80px wide |
| RIGHT-BOTTOM | Archer badge | Below wave indicator | Right-align | ~50px wide |

---

## HUD Elements

### Element 1 — Gold Counter

**Zone**: Left
**Category**: Must Show
**Content**: `⬡ [N]` — coin icon + integer gold value
**Visual form**: Icon + numeric label
**Update behavior**: Signal-driven. Updates on `gold_changed(new_gold)` signal. No per-frame reads.
**Contextual behavior**: When `current_gold >= ARCHER_COST AND current_archer_count < 8`:
label shifts to **amber** (`#F5C518` — Royal Gold from art bible). Returns to white when below threshold.
This communicates "recruit is available" without a separate affordability UI element.
**Font size**: 18px minimum (rendered at 540px logical width)
**Color default**: White `#FFFFFF` on dark strip background
**Color highlight**: `#F5C518` (amber gold — aligns with art bible Royal Gold)
**Accessibility**: Numeric value always visible. Color shift is secondary to the number. Passes color-independence requirement.

---

### Element 2 — Castle HP Bar

**Zone**: Center
**Category**: Must Show
**Content**: Filled progress bar + numeric HP label
**Visual form**: Horizontal progress bar with fill + integer overlay
**Update behavior**: Signal-driven. Updates on `hp_changed(new_hp)` signal. Bar snaps to correct fill (no tween — legibility under pressure takes priority over smoothness, per GDD Rule 9).
**Bar dimensions**: 280px wide × 16px tall
**Fill color bands** (from GDD D.2):
- `hp_ratio >= 0.6`: GREEN `#4CAF50` — safe state
- `0.3 <= hp_ratio < 0.6`: AMBER `#FFC107` — damaged state
- `hp_ratio < 0.3`: RED `#F44336` — critical state
**Numeric label**: `[N]` integer HP value, right-aligned inside bar or to the right of bar fill. 14px minimum. White with shadow for legibility over color bands.
**Accessibility**: Numeric HP value displayed alongside bar — color is NOT the sole signal of castle health. Resolves gap flagged in `design/accessibility-requirements.md` Section 2.2.
**Background track**: Dark `#333333` showing as remaining bar fill.
**Border**: 1px `#555555` rounded rect.

---

### Element 3 — Wave Indicator

**Zone**: Right-top
**Category**: Must Show
**Content**: "Wave N" (during wave) OR "Next: Xs" (inter-wave countdown)
**Visual form**: Text label, right-aligned
**Update behavior**:
- Switches to WAVE_ACTIVE on `wave_started(n)` signal → static text
- Switches to INTER_WAVE on `wave_cleared` signal → per-frame countdown via `_process(delta)`
- Countdown: `countdown_display = floor(countdown_remaining)` (GDD D.3)
- Freezes at "Next: 0s" until next `wave_started` — Enemy Wave owns the authoritative timer
**Font size**: 16px
**Color**: White during WAVE_ACTIVE. Amber `#F5C518` during INTER_WAVE countdown (signals "spending window open")
**Accessibility**: Pure text — no color-only information. "Wave 3" vs "Next: 7s" are semantically distinct.

---

### Element 4 — Archer Count Badge

**Zone**: Right-bottom (below wave indicator)
**Category**: Must Show
**Content**: `[archer icon] N/8`
**Visual form**: Small icon + fractional counter
**Update behavior**: Signal-driven. Updates on `recruit_purchased` signal (read deferred — Formation increments before HUD reads, per GDD Rule 18). Initializes from `Formation.current_archer_count` at session start (= 2).
**Filled state**: When `formation_full` signal received, badge text shifts to gold `#F5C518` and optionally displays a small ★ or ⬡ fill indicator. Returns to white on next session reset.
**Font size**: 14px
**Color default**: White
**Color full**: Gold `#F5C518`
**Accessibility**: Numeric "N/8" always present. Color shift is supplementary.

---

## Dynamic Behaviors

### HUD Visibility States

| State | HUD Visibility | Trigger |
|-------|----------------|---------|
| `PLAYING` (wave active) | Visible | `game_state_changed → PLAYING` |
| `PLAYING` (inter-wave) | Visible | `wave_cleared` |
| `GAME_OVER` | Hidden | `game_state_changed → GAME_OVER` |
| `RESETTING` | Hidden | `game_state_changed → RESETTING` |

### Session Initialization Sequence (on `PLAYING` transition)

All four elements read initial state before becoming visible:
1. Gold label: reads `Economy.current_gold` (= 60g)
2. Castle bar: reads `Castle.castle_hp` / `CASTLE_MAX_HP` (= 200/200 = full, green)
3. Castle HP label: reads `Castle.castle_hp` (= 200)
4. Wave label: "Wave 1" (awaits first `wave_started` signal; blank until then is acceptable)
5. Archer badge: reads `Formation.current_archer_count` (= 2), displays "2/8"
6. All color states reset to default (white text, green bar)

### Countdown (_process — inter-wave only)

The wave countdown is the only HUD element requiring per-frame updates. Active only when `wave_active == false`. Check `is_visible()` before processing to prevent orphaned ticks.

### Affordability Highlight

Re-evaluated on every `gold_changed` and `recruit_purchased` signal. Gold label color:
- `#F5C518` when `gold >= ARCHER_COST AND archer_count < 8`
- `#FFFFFF` otherwise

`ARCHER_COST = 30g if archer_count < 4, else 60g` (GDD D.6)

---

## Platform Variants

**Mobile Android (only target)**: All values given in logical pixels at 540×960.
Safe-area insets applied at startup via `DisplayServer.get_display_safe_area()`.
The strip top edge is offset to the bottom of the safe-area top inset (accounts for notch, camera cutout, status bar).

No desktop, no tablet, no landscape variant in MVP.

---

## Accessibility

Committed tier: **BASIC-MOBILE** (`design/accessibility-requirements.md`)

| Check | Status | Implementation |
|-------|--------|----------------|
| Text contrast ≥ 4.5:1 | PASS | White text on `Color(0,0,0,0.55)` dark strip exceeds 7:1 |
| Color independence | PASS | Castle HP shows numeric value alongside bar; affordability is color + numeric threshold; badge is numeric |
| Min text size (16px HUD, 14px badge) | PASS | Element font sizes specified above |
| Touch targets | N/A — HUD is read-only in MVP; no interactive elements |
| Safe area insets | REQUIRED | `DisplayServer.get_display_safe_area()` at startup |
| No 3–50 Hz flashing | PASS | No HUD elements flash; castle bar snaps (no pulse) |

**Resolved gap**: Castle HP numeric value displayed alongside color bar — resolves
the HIGH priority gap flagged in `accessibility-requirements.md` Section 2.2.

---

## Open Questions

- **Castle HP display format**: `"142"` vs `"142/200"` vs `"71%"` — integer absolute HP is the specified format (GDD D.7 pattern applied to HP display). Use `"%d" % castle_hp`.
- **Wave indicator color during countdown**: Amber `#F5C518` for spending-window signal is a design choice not in GDD. If playtest shows it distracts, revert to white.
- **Archer icon asset**: Placeholder circle until Art Bible Section 5 (Characters) specifies the asset. Badge displays text "N/8" without icon until asset is ready.

---

## Acceptance Criteria

- [ ] HUD strip renders as a semi-transparent dark band at the top of the screen, entirely within the Android safe area on a device with a camera notch
- [ ] Gold counter displays integer gold value and updates within one frame of `gold_changed` signal (no delay, no interpolation)
- [ ] Gold counter shifts to amber when `gold >= ARCHER_COST AND archer_count < 8`; returns to white when below threshold
- [ ] Castle HP bar fill reflects `castle_hp / 200` ratio; snaps immediately on `hp_changed` signal
- [ ] Castle HP bar color is GREEN at ≥60%, AMBER at 30–59%, RED at <30%
- [ ] Castle HP numeric value is always visible alongside the bar (not hidden at any HP level)
- [ ] Wave label shows "Wave N" during active wave and "Next: Xs" countdown during inter-wave, with X counting down each second
- [ ] Archer badge shows "N/8" and updates after each recruitment; shifts to gold color when formation is full
- [ ] HUD is completely hidden on GAME_OVER and RESETTING states
- [ ] All four elements are re-initialized correctly when a new session starts (gold=60, castle=200/200, wave=1, archers=2/8)
- [ ] All HUD text renders legibly at ≥16px on a 540px logical width screen
