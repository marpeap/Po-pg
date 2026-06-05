# Interaction Pattern Library — Garrison

> **Status**: In Design — Initial Catalog
> **Author**: ux-designer
> **Last Updated**: 2026-05-19
> **Template**: Interaction Pattern Library
> **Input Methods**: Touch only (Android). No keyboard, no gamepad, no hover.

---

## Overview

Garrison is a single-input mobile game. Every interaction must be expressible with
one thumb touching one point on the screen. This constraint is Pillar 1
("Un seul doigt, zéro friction") and it governs all patterns in this library.

The patterns below define how the game communicates with the player and how the
player acts on the game world. All patterns:
- Require at most one simultaneous touch
- Never require a button tap for core gameplay actions
- Provide feedback through world-space visuals rather than modal UI
- Are joystick-driven by default; spatial world presence replaces menu selection

**Pattern count**: 7 patterns catalogued.

---

## Pattern Catalog

| # | Pattern Name | Category | Used In |
|---|---|---|---|
| 1 | Fixed-Anchor Virtual Joystick | Input | Hero Movement, all zone navigation |
| 2 | Zone Dwell Trigger | Input / Feedback | Economy (RECRUIT_ZONE, TOWER_ZONE), Forge (FORGE_ZONEs) |
| 3 | Spatial Zone Selection | Input | Forge upgrade selection (Alpha) |
| 4 | Gold Magnet Auto-Collect | Feedback / Data Display | Economy collectibles |
| 5 | Volley Auto-Fire | Feedback | Archer Formation, Archer Tower |
| 6 | Signal-Driven HUD Display | Data Display | HUD |
| 7 | In-Place Session Reset | Navigation | Game State Machine → all systems |

---

## Patterns

---

### Pattern 1: Fixed-Anchor Virtual Joystick

**Category**: Input
**Used In**: Hero Movement (all gameplay movement)

**Description**: A virtual joystick with a fixed anchor position in viewport space
(bottom-left). The player holds anywhere in the bottom half of the screen and drags;
the knob follows the touch within a clamped radius. Releasing the touch stops the
hero immediately. No other input method drives movement.

**Specification**:
- Anchor: `(135, 800)` in viewport space (540×960). Fixed — does not reposition on touch.
- Activation: any `ScreenTouch` where `touch.position.y > VIEWPORT.y × 0.5` (bottom half only).
- Single-touch: first qualifying touch claims the joystick; additional touches ignored.
- Knob clamp radius: 80px. Knob position: `anchor + clamp(touch − anchor, 80px)`.
- Joystick direction: `normalize(touch − anchor)`. Applied to hero velocity = `joystick_dir × HERO_SPEED`.
- Dead zone: if `|touch − anchor| < 5px`, direction = zero, hero does not move.
- Release: joystick direction → zero, hero velocity → zero instantly. No deceleration.
- Top-half touches ignored by joystick; they do not interfere with any other system.

**When to Use**: Any continuous movement input on a touchscreen where the player
must be able to move in 360 degrees. Appropriate when the control point should be
predictable and not drift with multi-session play.

**When NOT to Use**: Do not use a floating joystick (repositions on touch down) —
Garrison uses a fixed anchor intentionally to give players muscle memory. Do not
use for discrete actions (use Zone Dwell Trigger for those).

**Accessibility**:
- Touch target is the entire bottom half of the screen (~540×480px) — far exceeds
  minimum 44×44pt requirement.
- Dead zone (5px) prevents unintentional micro-movement on touch down.
- No color dependency: joystick position is spatial, not color-coded.

**Reference**: `design/gdd/hero-movement.md` R6, R10–R15

---

### Pattern 2: Zone Dwell Trigger

**Category**: Input / Feedback
**Used In**: Economy (RECRUIT_ZONE, TOWER_ZONE in MVP; FORGE_ZONE deferred to Alpha)

**Description**: The player triggers a purchase or action by moving the hero into
a defined world-space zone and remaining there for a fixed hold duration (0.8s)
without leaving. No tap, no button. The commitment is spatial and temporal: the
player must physically be present and remain present. Abandoning the zone mid-dwell
cancels with no cost. The HUD shows the dwell fill ratio as a progress indicator.

**Specification**:
- Zone radius: `ZONE_RADIUS = 90px` in world space.
- Detection: each frame, Economy checks `distance(hero_pos, zone.center) ≤ ZONE_RADIUS`.
- Timer: while inside, `dwell_timer += delta` per frame.
- Threshold: when `dwell_timer ≥ DWELL_TIME (0.8s)`, a purchase attempt fires.
- Interruption: exit zone before threshold → `dwell_timer = 0`. Re-entry starts from zero.
  No partial-fill carry between visits.
- Purchase attempt: Economy checks `gold ≥ zone.cost`. If true: purchase succeeds,
  gold decremented, purchase signal emitted, `dwell_timer = 0`. If false: fails silently.
  No "not enough gold" feedback in MVP.
- After purchase: zone immediately re-available. No cooldown.
- Dwell states:
  - `IDLE` — hero outside all zones; `dwell_timer` holds at 0
  - `DWELLING` — hero inside zone, `dwell_timer < DWELL_TIME`; HUD progress bar fills
  - `TRIGGERED` — `dwell_timer ≥ DWELL_TIME`; purchase fires; timer resets
- HUD data: Economy exposes `dwell_fill_ratio = clamp(dwell_timer / DWELL_TIME, 0.0, 1.0)`
  read by HUD each frame for the progress bar.
- Active zones in MVP: `RECRUIT_ZONE` (archers), `TOWER_ZONE` (archer tower).

**When to Use**: Any action that requires sustained commitment and spatial presence.
Appropriate when the anti-pillar "no buttons/taps mid-combat" must be respected.
Use this instead of a tap button whenever the action is a meaningful resource spend.

**When NOT to Use**: Do not use for passive collection (use Gold Magnet Auto-Collect).
Do not use for actions that should fire instantly on touch (there are none in MVP).

**Accessibility**:
- Zone radius (90px in world space, ~45px in viewport at 540×1080 mapping) is
  generous relative to a 540px-wide screen.
- Dwell bar provides visual progress feedback without requiring precise timing judgement.
- No audio cue defined in MVP — mark as gap: a completion sound would help low-vision players.

**Reference**: `design/gdd/economy.md` R5–R10, `design/gdd/forge.md` R2

---

### Pattern 3: Spatial Zone Selection

**Category**: Input
**Used In**: Forge upgrade selection (Alpha milestone — inactive in MVP)

**Description**: Rather than presenting a menu of options and requiring the player
to tap a card, discrete choices are represented as distinct named world-space zones.
The player selects an option by walking to the corresponding zone and triggering a
Zone Dwell there. The joystick-only control contract is fully preserved: the act
of walking to a zone IS the selection. No modal menu, no confirmation tap.

**Specification**:
- Each option has a dedicated, permanently placed zone in the world.
- Zone placement ensures options are separated enough to prevent accidental
  selection of the wrong zone (at least 200px world-space separation recommended).
- Zone labels must be visible at the zone position in world space (not a menu overlay).
- The player communicates their choice by direction of movement toward a zone.
- Dwell at the chosen zone → Zone Dwell Trigger fires → action applied immediately.
- No "are you sure?" confirmation step. Walking away mid-dwell is the cancel action.
- In Garrison: four FORGE_ZONE variants (DMG / SPD / MAG / HP) placed as permanent
  world fixtures. Active from Alpha milestone onward.

**When to Use**: Any discrete selection from a small set of options (2–6 items)
that must respect the "no modal menu, no tap" constraint. Ideal for upgrades,
unlocks, or branching paths in joystick-only games.

**When NOT to Use**: Do not use for more than 6 options (world space becomes
cluttered and spatial clarity breaks down). Do not use when selection order matters
and must be enforced — spatial selection assumes the player can freely visit zones
in any order.

**Accessibility**:
- Zone labels must be readable at 540×960 minimum (14px rendered text or larger).
- Color MUST NOT be the sole differentiator between zone types — each zone must
  have a distinct icon or label in addition to color.
- Zones must be spaced enough to be selectable with normal joystick movement,
  not requiring sub-pixel precision.

**Reference**: `design/gdd/forge.md` R5, Design rationale note (D-02)

---

### Pattern 4: Gold Magnet Auto-Collect

**Category**: Feedback / Data Display
**Used In**: Economy collectibles (gold coins)

**Description**: Collectibles (gold coins) spawned in the world at enemy death
positions are automatically collected when the hero moves within a proximity
radius. No tap required. The player's movement through the battlefield inherently
collects gold. The magnet radius is a tunable design lever that controls how
much route optimization is required to collect efficiently.

**Specification**:
- Each frame, Economy checks `distance(hero_pos, coin.pos) ≤ GOLD_MAGNET_RADIUS`.
- If within radius: coin transitions to attracted state, moves toward hero,
  and is collected on overlap. Gold counter increments.
- Coins persist until collected or `session_reset`. They do not despawn on wave start.
- On `session_reset`: all active coins cleared without granting gold.
- Base radius: `GOLD_MAGNET_RADIUS = 170px`.
- Forge upgrade (Alpha): radius upgradeable via `FORGE_ZONE_MAG` dwell;
  ceiling `GOLD_MAGNET_CEILING = 450px`.
- No player action required beyond movement proximity.

**When to Use**: Consumable pickups that reward area traversal without requiring
stop-and-tap behavior. Appropriate for any resource collection where the
tactical interest lies in *where* the player moves, not *when* they tap.

**When NOT to Use**: Do not use for resources that require conscious choice to
collect (those should use Zone Dwell Trigger). Do not auto-collect anything with
downside risk (traps, penalties) — auto-collect implies always-safe.

**Accessibility**:
- Collection is passive and does not require timing or tap accuracy.
- Gold counter on HUD provides confirmation of collection event.
- Coin visual must be distinct from enemies and environmental elements at 540×960.

**Reference**: `design/gdd/economy.md` R3–R4, Formula D-1, D-2

---

### Pattern 5: Volley Auto-Fire

**Category**: Feedback
**Used In**: Archer Formation, Archer Tower

**Description**: All offensive actions in Garrison fire automatically on a fixed
interval (`SHOOT_IVTL`). The player never taps to shoot. The archers in the
formation fire as a coordinated group toward the nearest enemy, and the archer
tower fires independently. The player's only influence on firing is positioning —
moving the hero to face enemies determines the formation's attack direction.

**Specification**:
- Formation fires every `SHOOT_IVTL = 1.2s` regardless of joystick state.
- Auto-fire continues during all movement states including hero stationary.
- Hero facing angle (last non-zero joystick direction) determines formation rotation.
- Volley fires `n` projectiles simultaneously where `n = current_archer_count`.
- Projectiles sourced from ObjectPoolManager (pool of 24 arrows).
- Archer Tower fires independently on its own timer (same SHOOT_IVTL parameter).
- No player action triggers a volley; no player action cancels a volley.
- Volume scaling: `lerp(-6.0, 0.0, (n−2)/6.0)` dB — quieter with fewer archers,
  louder as formation grows.

**When to Use**: Any offensive or passive ability that should fire based on state/position
rather than player input. Appropriate for games where cognitive load must be minimized
by removing "press to attack" decisions.

**When NOT to Use**: Do not use for abilities that require conscious targeting by
the player (none in Garrison MVP). Do not use if the player is expected to control
firing timing as a core skill.

**Accessibility**:
- Auto-fire removes any motor requirement for offensive actions.
- Audio feedback (volley sound) provides non-visual confirmation of firing.
- Volume scales with archer count — gives audio feedback on formation size.

**Reference**: `design/gdd/archer-formation.md`, `design/gdd/archer-tower.md`,
`design/gdd/hero-movement.md` R7

---

### Pattern 6: Signal-Driven HUD Display

**Category**: Data Display
**Used In**: HUD (all four HUD elements)

**Description**: The HUD reads game state exclusively through signals emitted by
upstream systems. It owns no authoritative game state and never writes back to
any game system. On session start, HUD reads current values directly from upstream
systems before signals fire. All subsequent updates come from signals. This ensures
the HUD is a pure display layer with zero logic dependency.

**Specification**:
- HUD is a CanvasLayer with `layer = 1`. All container nodes have
  `mouse_filter = MOUSE_FILTER_IGNORE` — the HUD never intercepts touch events.
- Signal contracts:
  - `Economy.gold_changed(new_amount: int)` → gold counter display
  - `Economy.dwell_fill_ratio: float` → dwell progress bar (polled each frame)
  - `Castle.hp_changed(new_hp: int)` → castle HP bar
  - `WaveManager.wave_changed(wave_num: int)` → wave label
  - `Formation.archer_count_changed(count: int)` → archer badge
- On `_ready`: HUD reads current values directly before any signal fires.
- On `game_state_changed → GAME_OVER`: HUD `visible = false` in the same frame.
- On `game_state_changed → PLAYING`: HUD `visible = true` in the same frame.
- No modal overlays, tooltips, or notification banners spawn from the HUD in MVP.
- Animations: Tween only. AnimationPlayer is forbidden on CanvasLayer nodes
  (ADR-007, StringName risk in Godot 4.5–4.6).

**When to Use**: Any display element that reads upstream game state. Appropriate
for all HUD meters, counters, and progress bars. Enforces one-way data flow.

**When NOT to Use**: Do not use if the display must also modify game state — that
indicates an architectural violation. Display and logic must be separated.

**Accessibility**:
- All four HUD elements must have numeric or text fallbacks — no information
  conveyed by bar fill alone (bar + number pairing required).
- HUD text minimum rendered size: 14px at 540×960 viewport.
- HUD must remain visible at all Android safe area insets (notch, nav bar).
  All elements must be inside the OS-reported safe rect.
- High-contrast required: HUD elements placed on a semi-transparent background
  strip to ensure legibility over any world color.

**Reference**: `design/gdd/hud.md` UI Requirements, `docs/architecture/ADR-007-scene-architecture.md`

---

### Pattern 7: In-Place Session Reset

**Category**: Navigation
**Used In**: Game State Machine → all systems on GAME_OVER → RESETTING → PLAYING

**Description**: When the game ends and a new session begins, the game world resets
in place — no scene reload, no loading screen. The GameStateMachine emits
`session_reset`, and every system independently resets its own state in response.
From the player's perspective: GAME_OVER screen appears, then the world snaps back
to start state. The flow is: `PLAYING → GAME_OVER → RESETTING (one frame) → PLAYING`.

**Specification**:
- `SceneTree.reload_current_scene()` is FORBIDDEN (ADR-007).
- GSM emits `session_reset` signal from the RESETTING state.
- Each system resets its own authoritative state on `session_reset`:
  - Economy: `gold = STARTING_GOLD (60g)`, `dwell_timer = 0`, all coins cleared
  - Castle: `castle_hp = CASTLE_MAX_HP (60)`
  - Formation: `current_archer_count = STARTING_ARCHERS (2)`, archers repositioned
  - WaveManager: `current_wave = 0`, wave cleared, timer reset
  - HUD: re-reads all values on transition to PLAYING
  - ObjectPools: all active nodes returned to pool
- HUD remains hidden during RESETTING and becomes visible when PLAYING fires.
- The reset completes within one frame (single-frame RESETTING state).
- Player sees: GAME_OVER screen → brief reset frame (HUD hidden) → gameplay resumes.

**When to Use**: Any "restart" or "new game" flow in a game with a single persistent
scene. Appropriate when load times must be zero (no scene change = no import delay).

**When NOT to Use**: Do not use if individual systems cannot be cleanly reset to
initial state via signal. If any system has complex teardown requiring multiple
frames, the single-frame RESETTING assumption breaks.

**Accessibility**:
- Instant reset prevents disorientation from long loading screens.
- GAME_OVER state must persist long enough for the player to read the result
  (minimum 1.5s or until player input acknowledges) — do not flash immediately.
- Reduced-motion: the reset itself is instantaneous, which is lower motion than
  a scene transition animation. No additional reduced-motion handling needed.

**Reference**: `docs/architecture/ADR-005-game-state-machine.md`,
`docs/architecture/ADR-007-scene-architecture.md`

---

## Gaps & Patterns Needed

The following interaction needs have been identified but are not yet fully specified.
These should be addressed when the relevant screens are designed in Pre-Production.

| Gap | Needed For | Priority | Resolution Path |
|-----|-----------|----------|-----------------|
| GAME_OVER screen presentation | Session end / score display | High | `/ux-design game-over` |
| Dwell bar visual design | Economy zone feedback | High | `/ux-design hud` |
| Zone label / icon language | Forge zone identification (Alpha) | Medium | `/ux-design forge-zones` |
| "Not enough gold" silent failure | Economy UX | Medium | `/quick-design` or HUD spec |
| Coin visual identity | Economy collectibles | Medium | Art bible Section 5+ |
| Joystick visual affordance | First-time player discoverability | Low | `/ux-design hud` |

---

## Open Questions

1. **Dwell bar position**: The HUD GDD specifies a dwell bar exists but does not
   define its pixel position or whether it follows the zone or sits in the HUD strip.
   Resolve in `/ux-design hud`.

2. **Silent failure on unaffordable purchase**: When the player dwells a zone but
   cannot afford it, there is no MVP feedback. This may cause confusion ("did it
   work?"). Consider a subtle visual pulse on the gold counter. Deferred to HUD spec.

3. **Touch-screen GAME_OVER interaction**: How does the player dismiss GAME_OVER
   and trigger the restart? Zone dwell on a "PLAY AGAIN" zone? Tap anywhere? Timer
   auto-restart? Not defined in any GDD — resolve in `/ux-design game-over`.

4. **Reduced-motion preference**: Android does not expose a system-level reduced-motion
   flag accessible to Godot 4.6 GDScript in the same way as iOS. Verify via
   `DisplayServer.get_screen_size()` approach or use a manual in-game toggle.
   Flag for technical investigation before Pre-Production.

---

*Pattern library initialized: 2026-05-19*
*Next update: when first UX screen spec is authored (HUD or game-over)*
