# UX Spec: GAME_OVER Screen

> **Status**: Complete
> **Author**: ux-designer
> **Last Updated**: 2026-05-19
> **Journey Phase(s)**: Session resolution — every run ends here
> **Template**: UX Spec
> **Input Methods**: Touch only (Android)
> **GDD Sources**: `design/gdd/game-state.md`, `design/gdd/hud.md`

---

## Purpose & Player Need

The GAME_OVER screen resolves the tension accumulated during the run. Its purpose is
to let the run end with clarity and immediately invite the player back. It answers
two player needs:

1. **Clarity of defeat**: "The castle fell. This run is over." — no ambiguity.
2. **Zero-friction restart**: "Tap anywhere to try again." — one action, immediate return.

This screen must be felt as **earned defeat + immediate invitation**, not punishment.

---

## Player Context on Arrival

The player arrives at this screen:
- Involuntarily — the castle HP reached 0, the world froze
- Under stress — they were actively fighting a wave
- With full emotional context — they watched the HP bar drain; the moment is clear
- Ready to immediately restart — mobile players in this genre expect near-zero friction on retry

**Emotional state on arrival**: Tense → sudden stillness → anticipation to retry.

The design must honor the dramatic beat (castle fell — real moment) while making the retry path so fast and clear that the player's impulse to "try again" is satisfied instantly.

---

## Navigation Position

`[PLAYING state] → [GAME_OVER] → [RESETTING] → [PLAYING state]`

This is a circular loop — no branching. GAME_OVER is not a menu. It is a momentary
overlay between runs. There is no exit, no settings, no leaderboard in MVP.

---

## Entry & Exit Points

### Entry

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Castle HP reaches 0 | `castle_fell` signal → `GAME_OVER` state | Final wave number, final gold, formation state visible under overlay |

### Exit

| Exit Destination | Trigger | Notes |
|---|---|---|
| RESETTING → PLAYING | Any touch anywhere on screen | Instantaneous — no confirmation dialog, no animation delay. One-way: player cannot "cancel" a restart. |

---

## Layout Specification

### Information Hierarchy

Priority order (what the player must see first → last):

1. **Defeat confirmation** — clear, immediate: "The castle has fallen."
2. **Wave reached** — the one metric that communicates run length and progress
3. **Restart affordance** — "Tap to restart" — one visible call-to-action
4. *(Secondary)* Enemies defeated — honorable mention of performance
5. *(Background)* Frozen game world — visible under overlay, providing context

### Layout Zones

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   (frozen game world — dark overlay at ~65% opacity)       │
│                                                             │
│                                                             │
│           ╔═════════════════════════════╗                  │
│           ║                             ║                  │
│           ║    CASTLE FELL              ║  ← Headline      │
│           ║                             ║                  │
│           ║    Wave reached: [N]        ║  ← Primary stat  │
│           ║    Enemies defeated: [N]    ║  ← Secondary     │
│           ║                             ║                  │
│           ║    ┌─────────────────────┐  ║                  │
│           ║    │   TAP TO RESTART    │  ║  ← CTA           │
│           ║    └─────────────────────┘  ║                  │
│           ║                             ║                  │
│           ╚═════════════════════════════╝                  │
│                                                             │
│   (joystick zone — below, not interactive)                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Overlay**: Dark `Color(0.05, 0.05, 0.08, 0.70)` — deep dark blue-tint at 70% opacity.
Game world is still visible underneath (frozen). The world context makes the defeat feel real.

**Panel**: Centered card, ~340px wide × 280px tall. Background `Color(0.1, 0.08, 0.12, 0.92)` — near-opaque dark violet, consistent with art bible color system (Dark Violet `#5E2E6B`). Rounded corners 12px. No border (panel reads from contrast against overlay).

### Component Inventory

| Zone | Component | Type | Content | Interactive |
|------|-----------|------|---------|-------------|
| Full screen | Dark overlay | Panel | `Color(0.05,0.05,0.08,0.70)` | No |
| Panel — top | Headline label | Text | "CASTLE FELL" | No |
| Panel — mid | Wave stat label | Text | `"Wave reached: %d" % wave_number` | No |
| Panel — mid-low | Kill stat label | Text | `"Enemies defeated: %d" % total_kills` | No |
| Panel — bottom | Restart affordance | Text label (pulsing) | "TAP ANYWHERE TO RESTART" | The whole screen is the tap target |
| Full screen | Tap-to-restart zone | Touch area | entire screen | YES — triggers restart |

**New pattern introduced**: None. Uses existing patterns:
- Signal-Driven HUD Display (Pattern 6) for stat values
- In-Place Session Reset (Pattern 7) for restart

---

## States & Variants

| State / Variant | Trigger | What Changes |
|-----------------|---------|--------------|
| Default (GAME_OVER) | `castle_fell` signal | Overlay appears, panel visible, stats populated |
| First run (wave 1 fall) | Game starts, castle falls on wave 1 | Same layout; low wave number is contextually clear |
| Late run (wave 8+) | Castle falls after extended run | Same layout; high wave number signals achievement |

No loading state. No error state. No empty state. This screen is always fully populated
(castle fell is deterministic — all values are available at the moment of trigger).

**Platform variant**: None. 540×960 portrait only.

---

## Interaction Map

| Player Action | Input | Immediate Feedback | Outcome |
|---|---|---|---|
| Tap anywhere on screen | ScreenTouch any position | Overlay vanishes | GSM transitions to `RESETTING` → `PLAYING` |

**Single interaction** — the entire screen is the tap target. No buttons, no menu items, no directional navigation required. Consistent with Pillar 1 ("Un seul doigt, zéro friction").

**Input mapping for Touch**: Any `_input(event: InputEvent)` with `event is InputEventScreenTouch AND event.pressed AND _state == GAME_OVER`.

**Coverage**: Touch only (no keyboard, no gamepad — game is Android mobile).

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Tap on GAME_OVER screen | `game_state_changed(RESETTING)` (via GSM) | New state enum value |
| (immediately after) | `session_reset` signal (via GSM) | None |

No analytics events defined in MVP. Add when analytics layer is scoped.

**State modification**: Tapping triggers the GSM state transition. All session state
(castle HP, gold, archers, enemies, projectiles) is reset via `session_reset` signal.
This modifies persistent session state — owned by the GSM. HUD and all systems subscribe.

---

## Transitions & Animations

### Screen Enter (GAME_OVER appears)

- **Dark overlay**: instant cut (no fade). The world freezes in one frame — the
  abruptness is intentional. The castle falling is a discrete event, not a gradual fade.
- **Panel**: fast scale-up from 0.8→1.0 over 0.15s with ease-out. Signals "this matters,
  pay attention" without being jarring. Implemented via `Tween` (per ADR-007).
- **Headline text**: no additional animation — panel scale carries the entrance.

**Why instant overlay + panel pop?** The player was in active gameplay. A slow fade
would interrupt the emotional beat of the castle falling. An instant dark overlay
freezes the world cleanly; the panel pop announces "this is the end screen."

### Screen Exit (restart tap)

- **Instant cut**: overlay and panel disappear on the same frame as the state transition.
  No exit animation. The goal is zero perceived delay between tap and new run start.

### Idle state

- **Restart affordance text**: slow opacity pulse 1.0→0.6→1.0, period ~2.0s (1Hz).
  Below 3Hz threshold — no seizure risk (accessibility requirement met).
  Communicates "this is interactive" without demanding attention.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|------|--------------|--------------|-------|
| Wave number reached | Enemy Wave | Read | `EnemyWave.current_wave` — available at moment of `castle_fell` |
| Enemies defeated (total) | Enemy Wave | Read | `EnemyWave.total_kills` — running counter maintained in Enemy Wave system |
| GAME_OVER state | Game State Machine | Read | `GSM.current_state == GAME_OVER` — screen shows when this is true |

**Implementation note**: Stats should be captured at the moment `castle_fell` fires
(same frame as GAME_OVER transition) and stored in the overlay node. They do not need
to remain live-updated — the run is over.

**Enemy Wave total_kills**: Requires a `total_kills` counter in the Enemy Wave system.
This is an addition not currently in the Enemy Wave GDD — flag for ADR/GDD addition.

---

## Accessibility

Committed tier: **BASIC-MOBILE**

| Check | Status | Implementation |
|-------|--------|----------------|
| Contrast ≥ 4.5:1 | PASS | White text on `Color(0.1,0.08,0.12,0.92)` exceeds 10:1 |
| Color independence | PASS | No information conveyed by color alone; all info is text |
| Touch target ≥ 44×44px | PASS | Entire screen is the tap target (540×960) |
| No 3–50Hz flashing | PASS | Pulse animation at ~1Hz |
| Single-touch operation | PASS | One tap anywhere triggers restart |
| No time-limited prompt | PASS | GAME_OVER overlay persists until player taps — no auto-dismiss |

**Resolves gap** from `accessibility-requirements.md` Section 7:
"GAME_OVER dismiss mechanism not defined" — resolved: one tap anywhere on screen.

---

## Localization Considerations

| Element | Max visible characters | Notes |
|---------|----------------------|-------|
| "CASTLE FELL" | 12 chars | Short — low localization risk |
| "Wave reached: 8" | ~20 chars | Number-terminated — low risk |
| "Enemies defeated: 42" | ~25 chars | Number-terminated — low risk |
| "TAP ANYWHERE TO RESTART" | 24 chars | Risk: French "APPUYEZ N'IMPORTE OÙ POUR RECOMMENCER" = 40 chars — panel width must accommodate or text wraps to 2 lines |

**HIGH PRIORITY for localization**: "TAP ANYWHERE TO RESTART" is the most layout-critical element. Allow text wrap to 2 lines in panel layout. Min font size 14px even when wrapped.

---

## Acceptance Criteria

- [ ] When `castle_fell` signal fires, the game freezes within the same frame (no enemy movement, no projectiles, no gold collection after the castle falls) and the GAME_OVER overlay appears
- [ ] The overlay covers the full 540×960 screen at 70% opacity; the frozen game world is visible underneath
- [ ] The panel displays the correct wave number (e.g., "Wave reached: 4" if the castle fell during wave 4)
- [ ] The restart affordance ("TAP ANYWHERE TO RESTART") pulses slowly and remains visible at all times while in GAME_OVER state
- [ ] Tapping anywhere on the screen during GAME_OVER triggers a full session reset and returns to PLAYING state within one frame — no loading screen, no confirmation dialog, no animation delay
- [ ] The GAME_OVER overlay is not visible at any point during PLAYING or RESETTING states
- [ ] All text on the GAME_OVER panel renders at ≥14px minimum and at ≥4.5:1 contrast against the panel background
- [ ] The panel entrance animation (scale 0.8→1.0) completes in ≤0.2 seconds
- [ ] If the player taps during RESETTING (immediately after first tap), no second reset is triggered

---

## Open Questions

- **"Enemies defeated" counter**: Requires `total_kills` int in Enemy Wave system — not currently in Enemy Wave GDD. Add as a GDD amendment before sprint implementation.
- **Score / high score**: Out of scope MVP (ADR-009 — no persistence). Display wave reached as the only session performance metric.
- **Future: wave record display**: "Your best: Wave N" post-MVP — needs score persistence (ADR-009 extension). Flag for Alpha scope.
