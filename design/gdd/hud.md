# HUD

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-18
> **Implements Pillar**: Pillar 3 (L'armée se voit grandir) + Pillar 4 (Tension sans panique)

## Overview

The HUD is Garrison's sole read-only information layer: a lightweight CanvasLayer overlaid on the game world that translates live data from four upstream systems — Economy, Castle, Enemy Wave, and Archer Formation — into four persistent displays the player uses to make decisions. The HUD owns no game state; it reads, formats, and renders only. Its four elements are: a **gold counter** (current spendable gold), a **castle HP bar** (the threat metric), a **wave indicator** (current wave number + inter-wave countdown), and an **archer count badge** (occupied formation slots of 8). Together these four elements give the player the spatial and economic awareness demanded by the Visual Identity Anchor *"Lisible avant tout"* — hero position, archer count, castle status, and wave threat must be readable at a single glance on a 1080×1920 mobile screen. The HUD is MVP-mandatory: without it, the economic decisions that define Garrison's spatial tension mechanic are invisible to the player.

## Player Fantasy

The HUD is the player's dashboard of tension and ambition. In a single downward glance — without lifting the thumb from the joystick — the player absorbs four critical facts: *How close is the castle to falling? How much gold do I have? How large is my army? When does the next wave hit?* Each piece of information drives an immediate feeling:

- The **castle HP bar** is pure urgency. Watching it shrink from full to half creates escalating dread; seeing it dip into the final quarter triggers the kind of focused panic that makes players move faster, think sharper, and feel genuinely relieved when the wave clears. This is Pillar 4 (*Tension sans panique*) made visible — not an abstract "lives remaining" but a real-time picture of the castle under siege.

- The **gold counter** creates economic anticipation. The moment a player earns 30 gold, they see they can recruit. The moment they see 60, they know they're two archers away from the mid-formation. The counter turns every enemy kill into a tiny progress moment.

- The **archer count badge** is the pride display. Watching it tick from 2/8 → 4/8 → 6/8 → 8/8 over the course of a run is Pillar 3 (*L'armée se voit grandir*) in numbers. A full badge means the player feels powerful, capable, in command.

- The **wave indicator** provides structure: the inter-wave countdown is the planning window. When it appears, the player knows exactly how many seconds they have to spend gold before the next assault.

The player never feels informed *by* the HUD — they feel informed *for* the fight. The HUD disappears into fluency.

## Detailed Design

### Core Rules

**General**

1. The HUD is implemented as a `CanvasLayer` (layer 1) permanently attached to the main game scene. It renders above the game world and is unaffected by the game camera's position or zoom.

2. The HUD has two visibility states: **VISIBLE** (when the Game State Machine is in the `PLAYING` state) and **HIDDEN** (during `GAME_OVER` and `RESETTING`). Transitions are driven by the GSM's `game_state_changed` signal. The Game State Machine has exactly 3 states: `PLAYING`, `GAME_OVER`, `RESETTING` — no LOADING, WIN, or MAIN_MENU states exist in MVP.

3. On transition to PLAYING, the HUD **initializes** all four elements from the current upstream state before making itself visible (one-time read at session start; signals handle all subsequent updates).

4. The HUD owns no game state. It reads from upstream systems via signals and exposed properties only. It never modifies any upstream value.

---

**Element 1 — Gold Counter (top-left, inside safe-area)**

5. Displays `Economy.current_gold` as an integer. Format: `[coin icon] [N]g` (e.g. "⬡ 60g").

6. Subscribes to Economy's `gold_changed(new_gold: int)` signal. Updates `GoldLabel.text` immediately on receipt — no frame lag, no interpolation.

7. **Affordability highlight**: when `current_gold ≥ ARCHER_COST_TIER_1` (30g) AND `current_archer_count < 8`, the gold counter shifts to an amber highlight color, signaling the recruit zone is actionable. Color resets to neutral when gold drops below threshold or the formation is full.

---

**Element 2 — Castle HP Bar (top-center, spanning most of screen width)**

8. Displays `hp_ratio = castle_hp / CASTLE_MAX_HP` as a filled progress bar. Range: 0.0–1.0. `bar.max_value` is set to `CASTLE_MAX_HP` (200) at session start and does not change mid-session.

9. Subscribes to Castle's `hp_changed(new_hp: int)` signal. Updates `bar.value = new_hp` immediately — the bar snaps to the correct fill with no smoothing tween (MVP: snap is more readable under pressure than animation lag).

10. **Color bands** (instantaneous, no animation):
    - 1.0–0.6: green (safe)
    - 0.6–0.3: amber/orange (damaged)
    - < 0.3: red (critical)

---

**Element 3 — Wave Indicator (top-right, inside safe-area)**

11. During **WAVE_ACTIVE**: displays `"Wave N"` where N = `wave_number` from Enemy Wave. Static text — signal-only update, no per-frame read.

12. During **INTER_WAVE**: replaces the wave label with a countdown display. Format: `"Next: Xs"` (rounded to nearest integer second). The countdown starts at `INTER_WAVE_PAUSE` (10.0s) and decrements using `_process(delta)` — this is the only HUD element requiring per-frame updates.

13. Subscribes to Enemy Wave's `wave_started(wave_number: int)` signal → switches to WAVE_ACTIVE display and stops the countdown timer.

14. Subscribes to Enemy Wave's `wave_cleared` signal → switches to INTER_WAVE display and starts the countdown from 10.0s. The HUD mirrors the inter-wave pause; it does not control it.

15. When the countdown reaches 0.0, the HUD freezes the display at "Next: 0s" until the next `wave_started` signal arrives (Enemy Wave owns the timer; the HUD does not fire any action on timer expiry).

---

**Element 4 — Archer Count Badge (top-right, below wave indicator)**

16. Displays `"N/8"` where N = `Formation.current_archer_count`. Maximum is always 8 (`MAX_FORMATION_SLOTS`).

17. At session start: reads `Formation.current_archer_count` directly (equals `STARTING_ARCHERS` = 2). Displays `"2/8"`.

18. Subscribes to Economy's `recruit_purchased` signal. On receipt: reads `Formation.current_archer_count` and updates the badge text. This read is safe — `recruit_purchased` is deferred by one frame in Godot's signal queue, so the Formation has already incremented its slot count before HUD reads it.

19. Subscribes to Archer Formation's `formation_full` signal. On receipt: the badge shifts to a **filled visual state** (text color: gold/highlight). Returns to neutral color on `game_state_changed → PLAYING` (session reset).

---

### States and Transitions

| HUD State | Trigger | Behavior |
|-----------|---------|----------|
| `HUD_HIDDEN` | `game_state_changed` ≠ PLAYING | `CanvasLayer.visible = false`. No signal processing. |
| `HUD_ACTIVE_WAVE` | `game_state_changed` → PLAYING then `wave_started(n)` | All four elements visible. Wave label shows "Wave N". Countdown timer stopped. |
| `HUD_INTER_WAVE` | `wave_cleared` | All four elements visible. Wave label replaced by countdown. `_process(delta)` active for countdown. |

On `game_state_changed` → PLAYING (new or restarted session):
- Gold label: reads `Economy.current_gold` (= 60g)
- Castle bar: reads `Castle.castle_hp` / `CASTLE_MAX_HP` (= 200/200 = full)
- Wave label: "Wave 1" (or blank until first `wave_started`)
- Archer badge: reads `Formation.current_archer_count` (= 2), displays "2/8"
- All color states reset to default neutral

---

### Interactions with Other Systems

| Direction | System | Data / Signal | HUD Action |
|-----------|--------|---------------|------------|
| ← receives | Economy | `gold_changed(new_gold: int)` | Update `GoldLabel.text`; re-evaluate affordability color |
| ← receives | Economy | `recruit_purchased` | Read `Formation.current_archer_count`; update archer badge |
| ← reads | Economy | `current_gold` (session init) | Initialize gold label |
| ← receives | Castle | `hp_changed(new_hp: int)` | Update `CastleBar.value`; re-evaluate color band |
| ← reads | Castle | `castle_hp`, `CASTLE_MAX_HP` (session init) | Initialize castle bar |
| ← receives | Enemy Wave | `wave_started(n: int)` | Switch to WAVE_ACTIVE; update wave label |
| ← receives | Enemy Wave | `wave_cleared` | Switch to INTER_WAVE; start countdown |
| ← reads | Enemy Wave | `INTER_WAVE_PAUSE` constant | Initialize countdown duration |
| ← receives | Archer Formation | `formation_full` | Set archer badge to filled visual state |
| ← reads | Archer Formation | `current_archer_count` (session init + after recruit) | Initialize / update archer badge |
| ← receives | Game State Machine | `game_state_changed(new_state)` | Show/hide HUD; trigger session init on PLAYING |
| → exposes | — | Nothing | HUD is a terminal leaf node — no outbound signals or mutable state |

## Formulas

### D.1 Castle HP Ratio

`hp_ratio = castle_hp / CASTLE_MAX_HP`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current castle HP | `castle_hp` | int | 0–200 | Live value from Castle node |
| Max castle HP | `CASTLE_MAX_HP` | int | 200 | Locked constant |

**Output Range:** 0.0–1.0. Clamped before assignment to `ProgressBar.value` — overkill damage overshooting 0 must not produce a negative ratio.
**Example:** Castle took 70 damage → `castle_hp = 130` → `hp_ratio = 130/200 = 0.65` → bar at 65%.

---

### D.2 Castle HP Bar Color Band

```
bar_color =
  GREEN   if hp_ratio >= 0.6
  AMBER   if 0.3 <= hp_ratio < 0.6
  RED     if hp_ratio < 0.3
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `THRESH_GREEN` | float | 0.6 | Lower bound of safe band (inclusive) |
| `THRESH_AMBER` | float | 0.3 | Lower bound of warning band (inclusive); below → danger |

| State | Hex | Godot Color |
|-------|-----|-------------|
| GREEN | `#4CAF50` | `Color(0.298, 0.686, 0.314)` |
| AMBER | `#FFC107` | `Color(1.0, 0.757, 0.027)` |
| RED | `#F44336` | `Color(0.957, 0.263, 0.212)` |

**Output Range:** Exactly one of three discrete Color values. Applied to `ProgressBar` fill modulate; updated on each `hp_changed` signal (signal-driven, not per-frame).
**Boundary:** `hp_ratio = 0.6` → GREEN; `hp_ratio = 0.3` → AMBER (not RED).
**Example:** `castle_hp = 50` → `hp_ratio = 0.25` < 0.3 → RED.

---

### D.3 Wave Countdown Display Value

`countdown_display = floor(countdown_remaining)`
`countdown_remaining = max(countdown_remaining - delta, 0.0)` *(applied each frame in _process during INTER_WAVE state)*

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Remaining inter-wave time | `countdown_remaining` | float | 0.0–10.0 | Init to `INTER_WAVE_PAUSE = 10.0` on `wave_cleared` signal |
| Frame time | `delta` | float | ~0.016–0.05 | Engine-provided; not stored |
| Display integer | `countdown_display` | int | 0–10 | Value shown in label |

**Output Range:** 10 down to 0. The `max()` guard prevents overshoot below 0.0.
**Example:** `countdown_remaining = 7.83` → display = 7 → "Next: 7s". Drops to 6 when `countdown_remaining` first crosses below 7.0.

---

### D.4 Wave Label Text Selection

```
wave_label_text =
  "Wave %d" % current_wave         if wave_active == true
  "Next: %ds" % countdown_display  if wave_active == false
```

| Variable | Type | Description |
|----------|------|-------------|
| `wave_active` | bool | `true` on `wave_started` signal; `false` on `wave_cleared` signal |
| `current_wave` | int | 1-indexed wave number from Enemy Wave |
| `countdown_display` | int | From D.3; only consumed when `wave_active == false` |

**Output Range:** Two mutually exclusive string formats. The `wave_started` signal (not HUD countdown expiry) triggers the switch back to WAVE_ACTIVE display — Enemy Wave owns the authoritative timer.

---

### D.5 Archer Badge Display Value

`badge_text = "%d/8" % current_archer_count`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `current_archer_count` | int | 2–8 | Read from Formation on recruit_purchased signal; init = STARTING_ARCHERS = 2 |
| `MAX_FORMATION_SLOTS` | int | 8 | Denominator; constant literal |

**Output Range:** "2/8" at session start → "8/8" at full formation. Never "0/8" or "1/8" under normal play (STARTING_ARCHERS = 2).

---

### D.6 Affordability Highlight Condition

```
ARCHER_COST =
  ARCHER_COST_TIER_1 (30g)  if current_archer_count < 4
  ARCHER_COST_TIER_2 (60g)  if current_archer_count >= 4

highlight_active = (current_gold >= ARCHER_COST) AND (current_archer_count < MAX_FORMATION_SLOTS)
```

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `current_gold` | int | 0–unbounded | From Economy.current_gold |
| `ARCHER_COST_TIER_1` | int | 30g | Locked |
| `ARCHER_COST_TIER_2` | int | 60g | Locked |
| `current_archer_count` | int | 2–8 | Determines both cost tier and slot availability |
| `MAX_FORMATION_SLOTS` | int | 8 | Suppress highlight when full |

**Output Range:** Boolean. `false` unconditionally when `current_archer_count == 8`.
**Example 1:** gold=45, count=3 → cost=30; `45≥30 AND 3<8` → `true` (highlight on).
**Example 2:** gold=45, count=4 → cost=60; `45≥60` is false → `false`.
**Example 3:** gold=999, count=8 → `8<8` is false → `false`.
**Example 4 (boundary):** gold=60, count=4 → cost=60; `60≥60 AND 4<8` → `true`.

---

### D.7 Gold Counter Display Value

`gold_display_text = "%d" % current_gold`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `current_gold` | int | 0–unbounded | From Economy.current_gold on gold_changed signal |

**Output Range:** "0" minimum, no locked maximum. No thousands separator, no decimal, no currency symbol in string (coin icon is a separate sprite node).
**Example:** `current_gold = 130` → label reads "130".

---

### D.8 Formula Summary

| ID | Formula | Updates on | Output type |
|----|---------|------------|-------------|
| D.1 | `hp_ratio = castle_hp / 200` | `hp_changed` signal | float 0.0–1.0 |
| D.2 | Color band lookup on `hp_ratio` | `hp_changed` signal | Color (3 values) |
| D.3 | `countdown_display = floor(countdown_remaining)` | `_process` (inter-wave only) | int 0–10 |
| D.4 | Wave label string selection | `wave_started` / `wave_cleared` signals | String |
| D.5 | `badge_text = "%d/8" % count` | `recruit_purchased` signal | String |
| D.6 | `highlight_active = gold ≥ cost AND count < 8` | `gold_changed` / `recruit_purchased` signals | bool |
| D.7 | `gold_display_text = "%d" % current_gold` | `gold_changed` signal | String |

## Edge Cases

- **If `castle_hp` reaches 0 before the `hp_changed` signal fires** (multi-hit in one frame): the bar snaps to 0.0 on the next signal received. Color band evaluates to RED. The `castle_fell` signal from Castle drives game-over flow — the HUD does not handle it directly beyond reading whatever `hp_changed` value arrives.

- **If `castle_hp` overshoots below 0** (overkill damage): `hp_ratio = max(castle_hp, 0) / CASTLE_MAX_HP` clamps to 0.0. The bar does not display a negative fill or crash.

- **If `gold_changed` fires with `new_gold < 0`** (should not happen under normal play — Economy enforces non-negative gold): display clamped to "0". The affordability highlight evaluates as `false`.

- **If `recruit_purchased` fires but Formation has not yet incremented `current_archer_count`** (same-frame signal): read is deferred — HUD subscribes with `call_deferred` or reads in `_deferred` to ensure Formation's counter reflects the new archer. Per the Archer Formation GDD, the signal fires after the slot is filled.

- **If the HUD receives `wave_started` while already in WAVE_ACTIVE state** (duplicate signal): overwrite the wave label with the new wave number. The countdown timer is stopped regardless (it should already be stopped — idempotent).

- **If the HUD receives `wave_cleared` while already in INTER_WAVE state** (duplicate signal): reset `countdown_remaining` to `INTER_WAVE_PAUSE = 10.0` and restart the countdown. No crash.

- **If `wave_started` fires before the countdown reaches 0** (Enemy Wave advances the wave early — possible in future fast-mode tuning): the countdown stops immediately and the label switches to "Wave N". HUD does not block the wave transition.

- **If `formation_full` fires but `current_archer_count` reads 7** (signal/read race): trust the signal — display badge in filled visual state regardless of the read value. The signal is authoritative for the filled state.

- **If `game_state_changed` → GAME_OVER fires during INTER_WAVE countdown**: HUD hides immediately (`CanvasLayer.visible = false`). The countdown `_process` handler checks HUD visibility before updating — no residual countdown tick after hide.

- **If `game_state_changed` → PLAYING fires with `Formation.current_archer_count` not yet initialized** (scene load order issue): HUD reads 0 and displays "0/8". Mitigation: HUD's `_ready()` connects signals before reading initial state; if Formation is not ready, HUD waits for the first `recruit_purchased` signal to correct the display. Flag for architecture review (scene-order dependency).

- **If `CASTLE_MAX_HP` is 0** (misconfiguration): `hp_ratio = castle_hp / 0` → division by zero. Guard: `if CASTLE_MAX_HP == 0: push_error("CASTLE_MAX_HP must be > 0"); hp_ratio = 0.0`. Programmer error, not a gameplay case.

- **If the screen has a notch or navigation bar** (Android safe area): all four HUD elements are anchored inside the safe-area rect retrieved from `DisplayServer.get_display_safe_area()` at startup. Elements must not be clipped by hardware UI chrome on any Android device.

## Dependencies

### Upstream (Hard — HUD cannot function without these)

| System | Dependency type | Data / Signals consumed |
|--------|----------------|------------------------|
| **Economy** | Hard | `gold_changed(new_gold: int)` signal; `recruit_purchased` signal; `current_gold` property (session init); `ARCHER_COST_TIER_1` (30g), `ARCHER_COST_TIER_2` (60g) constants for affordability calculation |
| **Castle** | Hard | `hp_changed(new_hp: int)` signal; `castle_hp` property (session init); `CASTLE_MAX_HP` constant (200) for hp_ratio denominator |
| **Enemy Wave** | Hard | `wave_started(wave_number: int)` signal; `wave_cleared` signal; `INTER_WAVE_PAUSE` constant (10.0s) for countdown initialization |
| **Archer Formation** | Hard | `formation_full` signal; `current_archer_count` property (session init + post-recruit read) |
| **Game State Machine** | Hard | `game_state_changed(new_state)` signal — controls HUD visibility and triggers session initialization |

### Downstream (None)

The HUD is a terminal leaf node in the dependency graph. No system depends on the HUD. It exposes no signals and no mutable state.

### Bidirectional Consistency Notes

The following upstream GDDs should list HUD as a downstream dependent:
- **Castle** — `castle.md` lists HUD as downstream (confirmed)
- **Enemy Wave** — `enemy-wave.md` exposes `wave_number`, `inter_wave_countdown`, `active_enemy_count` for HUD (confirmed)
- **Economy** — `entities.yaml` lists `INTER_WAVE_PAUSE` as `referenced_by: [hud, economy]` (confirmed)
- **Archer Formation** — `archer-formation.md` Interactions table includes "→ Expose HUD (current_archer_count)" (confirmed)
- **Game State Machine** — `game-state.md` should list HUD as a downstream dependent. Flag for cross-reference verification in `/design-review`.

## Tuning Knobs

| Knob | Current value | Safe range | What changes | Notes |
|------|-------------|-----------|--------------|-------|
| `THRESH_GREEN` | 0.6 | 0.5–0.75 | Lower bound of safe (green) HP band. | Too high → bar goes amber too early (excessive tension). Too low → players ignore warning until it's too late. |
| `THRESH_AMBER` | 0.3 | 0.15–0.4 | Lower bound of warning (amber) band; below this → red. | Must always be < `THRESH_GREEN`. Too high → red zone barely exists. Too low → red feels sudden. |
| HP bar color: safe | `#4CAF50` | Any green | Fill color in safe band. | Pair with THRESH_GREEN — if threshold changes, verify the color still reads correctly at that fill level. |
| HP bar color: warning | `#FFC107` | Any amber | Fill color in warning band. | Must contrast with both the safe and danger colors on a dark game world background. |
| HP bar color: danger | `#F44336` | Any red | Fill color in danger band. | Test on low-brightness mobile screens — dark reds can become unreadable. |
| `INTER_WAVE_PAUSE` | 10.0s | (owned by Enemy Wave) | Countdown init value. | **Do not change here.** Change in Enemy Wave GDD. HUD reads this constant at session start — it will auto-adjust. |
| Gold highlight color | amber (to be locked in art pass) | Any warm color | Color of GoldLabel when `highlight_active = true`. | Must clearly distinguish from neutral white/cream without blending into the background. |
| HUD safe area margin | Derived from `DisplayServer.get_display_safe_area()` | N/A | Minimum inset from screen edges. | Not a design knob — driven by Android device specs. Do not hardcode a pixel margin. |

**Knobs that do NOT exist on the HUD (owned by upstream systems):**

- Gold values, archer costs, starting gold → Economy GDD
- Castle max HP, damage per contact → Castle GDD
- Wave count, enemy count → Enemy Wave GDD
- Archer count, formation slots → Archer Formation GDD

## Visual/Audio Requirements

### 1. Overall Visual Style

The HUD occupies a top strip (approximately 1080 × 160 px) at the absolute top of the 1080 × 1920 canvas. It reads as a single coherent band floating above the battlefield without competing with gameplay action below.

**Background treatment.** A semi-transparent dark panel spans the full top strip: solid fill `#0D0D0D` at 80% opacity. No blur. No gradient. A 2 px bottom-edge line in `#2A2A2A` (pure geometry, no shader) separates HUD from world. Part of the same NinePatchRect or flat ColorRect that backs the strip — zero extra draw calls.

**Color language on the strip.** The world below is dark and desaturated. The HUD warm palette (`#FFC107` amber, `#C8A96E` warm stone, `#4CAF50` green) reads as "player-owned." Cold colors (`#F44336` red, `#FF6B35` orange) are reserved exclusively for threat signals — HP bar danger bands. Do not use red or orange anywhere in the HUD for non-threat purposes.

**Depth and separation.** No drop shadows (shader cost). All HUD text and icons use a 1 px hard black outline baked into the font or achieved via Godot's `Label` outline settings (outline size: 2 px, color `#000000`). Sufficient at 1080 px width to pop elements off any world frame.

**Scale and arm's-length readability.** All primary numerals must be no smaller than 48 px rendered; secondary labels no smaller than 36 px. HUD elements are display-only (no touch targets).

---

### 2. Typography

**Font family.** One bitmap font, one weight. Pre-rendered condensed bold sans-serif style (mechanically similar to Barlow Condensed Bold or Rajdhani Bold), delivered as a bitmap `.fnt` (AngelCode format) for Godot's BitmapFont resource. Single atlas sheet (512 × 256 recommended) covering digits 0–9, letters A–Z, colon, slash, space. One atlas = one texture = one draw call contribution, shared across all Label nodes.

**Do not use a dynamic font (TTF/OTF) in production.** Dynamic fonts require per-frame rasterization on Compatibility renderer and produce inconsistent sub-pixel rendering across Android GPU vendors. Export as bitmap at 64 px cap-height and scale Label nodes downward.

**Size assignments (rendered px at 1080 wide):**

| Element | Primary numeral | Secondary label |
|---|---|---|
| Gold counter | 52 px | 36 px (coin icon replaces label) |
| Castle HP bar | — | 28 px (bar fill communicates state) |
| Wave indicator — "Wave N" | 48 px (N) | 32 px ("Wave" prefix) |
| Wave indicator — "Next: Xs" | 48 px (X) | 32 px ("Next:" prefix) |
| Archer count badge | 44 px (N) | 30 px ("/8" suffix) |

**Outline.** 2 px black outline on all Label nodes. No secondary shadow. **Letter-spacing.** Tight (0 px extra). Condensed glyphs allow "999" to fit its column without wrapping.

---

### 3. Gold Counter

**Position.** Top-left. Icon at left edge with 12 px margin; numeral immediately right; right edge at approximately x = 240 px.

**Icon style.** Pixel-art coin: circular silhouette, `#FFC107` fill, `#B8860B` 1 px inner ring, `#000000` 1 px outer edge. Size: 40 × 40 px. Static Sprite2D or TextureRect pointing to the shared HUD atlas. Does not animate in idle state.

**Numeral style.** `#FFC107` (amber). Outline black 2 px. Right-aligned within its column so "0", "99", "999" share the same right edge — no layout shift as the number grows.

**Affordability highlight — what changes (no tween, no shader, no pulse):**
1. Numeral color: `#FFC107` → `#FFFFFF` (white = "this number is actionable")
2. Coin icon: swaps to alternate atlas frame (same shape, `#FFFFFF` ring instead of `#B8860B` ring)
3. A 1 px solid border appears around the gold counter region in `#FFC107` — implemented as a pre-sized NinePatchRect child toggled `visible = true`/`false`

No glow. No additive blending. No pulsing scale. The contrast between default amber and affordable white is sufficient at arm's length.

---

### 4. Castle HP Bar

**Position.** Top-center, spanning x = 260 px to x = 820 px (560 px wide), vertically centered in the top strip.

**Bar shape.** Flat wide rectangle. Height: 28 px. Corner radius: 4 px (NinePatchRect frame — no shader). No capsule ends.

**Frame.** NinePatchRect border in `#C8A96E` (warm stone — castle's color vocabulary), 2 px thickness. Separate node layered above fill.

**Fill style.** Flat color ColorRect, sized proportionally to current HP percentage, clipped by frame's inner rect. No gradient. No texture.

**Color band transitions — instantaneous snap:**
- `HP > 60%`: fill `#4CAF50` (green)
- `30% < HP ≤ 60%`: fill `#FFC107` (amber)
- `HP ≤ 30%`: fill `#F44336` (red)

No tween on color. The sudden threshold snap is more legible and more alarming than a gradient.

**Damage flash — MVP.** On any `hp_changed` event: fill ColorRect modulates to `#FFFFFF` for exactly 3 frames (50 ms at 60 fps), then returns to current band color. `modulate` set in `_process` via frame counter — no Tween, no shader.

**Bar shake on RED entry.** One-time per wave, when HP crosses from AMBER into RED: HUD bar parent executes a positional shake — 4 alternating x-offsets (+4, -4, +4, -4 px) over 8 frames — via Tween on `position.x`. This is the **only Tween** used in the MVP HUD.

---

### 5. Wave Indicator

**Position.** Top-right cluster, upper slot.

**"Wave N" state.** "Wave" prefix: 32 px, `#A0A0A0` (cool mid-gray). Wave number N: 48 px, `#FFFFFF` (white). Right-aligned. No animation on wave number update — signal updates the text only.

**"Next: Xs" countdown state.** "Next:" prefix: 32 px, `#A0A0A0`. Count X: 48 px, color progression:
- X > 5: `#4CAF50` (green — calm, time remains)
- X ≤ 5: `#FFC107` (amber — soon)
- X ≤ 2: `#F44336` (red — imminent)

No shaking, no flashing during countdown. Color shift alone is sufficient — over-signaling during a prepared inter-wave pause violates Pillar 4.

---

### 6. Archer Count Badge

**Position.** Top-right, directly below wave indicator, 8 px vertical gap.

**Format.** Text-only ("N/8"). No individual pip dots in MVP — a numeric format costs one Label node; pip dots would require 8 sprite nodes or custom draw calls per frame.

**Typography.** Current count (left of slash): 44 px, `#FFC107` (amber — archer/player vocabulary). Slash and max ("/8"): 30 px, `#606060` (dark gray — structural, secondary). Right-aligned to match wave indicator column.

**Partial states (2–7).** Standard amber numeral. No special treatment.

**Full state — "8/8".** Three simultaneous changes (no animation):
1. Current count color: `#FFC107` → `#FFFFFF` (white — same as gold affordability)
2. A 1 px border appears around the badge region in `#FFC107` (same pre-sized NinePatchRect pattern as gold counter)
3. "/8" suffix color: `#606060` → `#FFC107` — entire badge unifies to warm amber

No bow/archer icon in MVP — deferred to production pass (atlas management overhead; readability concerns at 30–36 px on mid-range Android).

---

### 7. Audio Cues

**Architectural principle.** The HUD does not own audio playback. Audio is triggered by upstream systems (Castle, WaveManager, FormationManager) via signals. The HUD subscribes to the same signals for visual updates only — it never calls AudioStreamPlayer. This prevents duplicate playback if both the HUD and another system respond to the same event.

| Event | Signal | Audio owner | Sound character |
|-------|--------|-------------|-----------------|
| Castle HP enters AMBER (≤ 60%) | `hp_changed` crossing 60% threshold | CastleSystem | Low stone rumble, 0.5–0.8 s, non-looping. Early warning, not alarm. |
| Castle HP enters RED (≤ 30%) | `hp_changed` crossing 30% threshold | CastleSystem | Sharp dry impact crack + 1 s ambient low drone (fade out). Synchronized with HUD bar shake. |
| Castle HP damage flash | `hp_changed` (any hit) | CastleSystem | Short stone-chip tick, < 0.2 s. Quieter than enemy attack SFX. Synchronized with white flash. |
| Wave start | `wave_started(n)` | WaveManager | Single low drum hit or horn stab, 0.4–0.6 s. Non-repeating. |
| Inter-wave countdown begins | `wave_cleared` | WaveManager | Short ascending two-note chime (positive, not tense). |
| Countdown at 2 seconds | `countdown_critical` | WaveManager | Single percussive tick/click, < 0.15 s. Punctuates red color change. |
| Countdown at 5 seconds | (color change only) | — | No dedicated audio. Color change is the signal — avoid over-signaling. |
| Formation full | `formation_full` | FormationSystem | Short ascending 3-note arpeggio, warm tones, 0.5–0.7 s. Restrained satisfaction, not a fanfare. |
| Gold affordability threshold | (color change only) | — | No dedicated audio. Would fire repeatedly near threshold during normal play. |

---

### 8. Accessibility

**Contrast ratios** (effective background `#1A1A1A` = `#0D0D0D` at 80% over dark world):

| Element | Foreground | Ratio | Status |
|---------|-----------|-------|--------|
| Gold numeral (default) | `#FFC107` | ~9.2:1 | Passes |
| Gold numeral (affordable) | `#FFFFFF` | ~16.7:1 | Passes |
| Wave number | `#FFFFFF` | ~16.7:1 | Passes |
| Wave prefix | `#A0A0A0` | ~5.1:1 | Passes |
| Archer count (current) | `#FFC107` | ~9.2:1 | Passes |
| Archer count (suffix) | `#606060` | ~2.5:1 | Borderline — raise to `#808080` (~4.1:1) if accessibility is a hard requirement |

**Color-independent HP bar readability:**
1. **Bar width** is the primary signal — a bar at 20% communicates threat regardless of color
2. **Bar shake on RED entry** (Section 4) is a motion cue, not a color cue — perceived independently of color channels
3. **Production pass**: skull icon overlay inside RED-band fill (shape-based signal, no color perception required)
4. **Deferred for production**: `ColorBlind` accessibility setting — replaces three-color sequence with warm white fill + numeric percentage label inside bar (`[CASTLE 45%]`, readable in monochrome)

**Text size floor.** No HUD text may be rendered below 28 px at 1080 wide.

---

### 9. Performance Checklist

**Draw call budget: target ≤ 8, ceiling 10.**

| Node | Draw calls | Notes |
|------|-----------|-------|
| Top strip background (ColorRect) | 1 | Full-width dark panel |
| Gold icon + borders (TextureRect/NinePatchRect, atlas) | 1 | Single shared HUD atlas |
| Gold numeral (Label, BitmapFont) | 1 | BitmapFont atlas; batches with other Labels if same font resource |
| Castle HP bar frame (NinePatchRect, atlas) | 0 (batched) | Same atlas |
| Castle HP bar fill (ColorRect) | 1 | Separate ColorRect; breaks batch — unavoidable |
| Wave indicator (Label, BitmapFont) | 0 (batched) | Same BitmapFont atlas |
| Archer badge + border (Label + NinePatchRect, atlas) | 0 (batched) | Same atlas + same font |

**Estimated: 4 draw calls** under ideal batching. Worst case (atlas/font fragmentation): 8. Well within ≤150 mobile budget.

**Atlas requirements.** Single 512 × 256 atlas: coin icon (normal + affordable frames), NinePatchRect border template (one slice, reused for all bordered elements). Export PNG, import as `compress/mode = Lossless` — do not use Basis Universal; color fidelity on `#FFC107` degrades under lossy compression.

**Font requirements.** One BitmapFont resource, one atlas sheet (512 × 256 px), shared across all Label nodes via identical `theme` resource. Do not create per-node font overrides — they break batching.

**Prohibited in this HUD.** CanvasItem shaders, additive blend modes, particle nodes, AnimationPlayer driving color changes (use `modulate` in `_process` instead), multiple font resources, Viewport-based sub-rendering.

**Validation step.** After implementation, enable `Project Settings > Debug > Draw Calls` overlay. Capture a mid-wave frame with all active states simultaneously (damage flash + affordable state + formation full). Confirm HUD strip contributes ≤ 10 draw calls.

## UI Requirements

The HUD is itself the UI system for in-game play — it has no separate screen. Its UI requirements are:

- **Signal contracts**: all four upstream systems must emit signals whose names and signatures exactly match those listed in Section C and the Dependencies section. Any rename requires updating this GDD and all signal connection code simultaneously.
- **No interactive elements in MVP**: the HUD strip contains zero touch targets. The top strip must not intercept touch events — `CanvasLayer` must have `mouse_filter = MOUSE_FILTER_IGNORE` on all container nodes. Touch pass-through to the game world is required.
- **UX spec required before production**: run `/ux-design hud` in Pre-Production to specify pixel positions, font sizes, margins, and element spacing as a standalone UX document. This GDD defines *what* to display and the design rules; the UX spec defines *exactly where and how large* in pixel coordinates.
- **No pop-up elements**: the HUD does not spawn any modal overlays, tooltips, or notification banners in MVP. Such elements belong to a future notification system GDD.

## Acceptance Criteria

### AC-C1: HUD Architecture (CanvasLayer, Layer 1)

**AC-C1.1 — Layer assignment**
**GIVEN** the game scene is loaded, **WHEN** the HUD node tree is inspected at runtime, **THEN** the HUD root node is a `CanvasLayer` with `layer` property equal to `1`.

**AC-C1.2 — Signal-driven updates only**
**GIVEN** the HUD is visible, **WHEN** `Economy.current_gold` is mutated directly (bypassing the `gold_changed` signal), **THEN** the gold counter display does not update; the displayed value retains its last signal-driven value.

**AC-C1.3 — No upstream mutation**
**GIVEN** the HUD is fully initialised, **WHEN** any HUD script function is executed (signal handlers, `_process`, `_ready`), **THEN** no write operation is performed on `Economy`, `Formation`, `Castle`, or `WaveManager` — verified by confirming none of those nodes' setters are called from HUD code.

---

### AC-C2: Visibility Tied to PLAYING State

**AC-C2.1 — Hidden on GAME_OVER**
**GIVEN** `GameStateManager` emits `game_state_changed` with value `GAME_OVER`, **WHEN** the signal is received, **THEN** the HUD `CanvasLayer.visible` property is `false` within the same frame.

**AC-C2.2 — Visible on transition to PLAYING**
**GIVEN** the HUD is hidden (any non-PLAYING state), **WHEN** `GSM` emits `game_state_changed` with value `PLAYING`, **THEN** `HUD.visible` becomes `true` within the same frame.

**AC-C2.3 — Hidden on RESETTING**
**GIVEN** the HUD is hidden after GAME_OVER, **WHEN** `GSM` emits `game_state_changed` with value `RESETTING`, **THEN** `HUD.visible` remains `false` (HUD stays hidden during the one-frame reset; it becomes visible again when PLAYING fires).

> **Note**: The MVP Game State Machine has exactly 3 states: PLAYING, GAME_OVER, RESETTING. MAIN_MENU, LOADING, WIN, and PAUSED do not exist in MVP — acceptance criteria referencing those states have been removed.

---

### AC-C3: Session Initialisation

**AC-C3.1 — Gold read before first signal**
**GIVEN** `Economy.current_gold` is `150` at the moment `game_state_changed → PLAYING` fires, **WHEN** the HUD becomes visible, **THEN** the gold counter displays `"150"` before any `gold_changed` signal is emitted.

**AC-C3.2 — Castle bar read before first signal**
**GIVEN** `Castle.castle_hp` is `180` and `CASTLE_MAX_HP` is `200` at session start, **WHEN** the HUD initialises, **THEN** the castle bar `value` is `0.9` (= 180/200) before any `hp_changed` signal fires.

**AC-C3.3 — Wave label read before first signal**
**GIVEN** `WaveManager.wave_active` is `false` and `WaveManager.current_wave` is `0` at session start, **WHEN** the HUD initialises, **THEN** the wave label displays the inter-wave format (not "Wave 0") or the correct wave number if `wave_active` is `true`.

**AC-C3.4 — Archer badge read before first signal**
**GIVEN** `Formation.current_archer_count` is `2` (STARTING_ARCHERS) at session start, **WHEN** the HUD initialises, **THEN** the archer badge displays `"2/8"` before any `recruit_purchased` signal fires.

---

### AC-C4: HUD Owns No Game State

**AC-C4.1 — No authoritative state stored in HUD**
**GIVEN** the HUD has received ten `gold_changed` signals, **WHEN** the HUD node is freed and re-instanced without restarting the game, **THEN** the HUD re-reads values from upstream systems on `_ready` and displays correct current values; no cached HUD-local variable is treated as the source of truth.

---

### AC-C5: Gold Counter

**AC-C5.1 — Display updates on signal**
**GIVEN** the gold counter shows `"50"`, **WHEN** `Economy` emits `gold_changed` with value `75`, **THEN** the gold counter label text becomes `"75"` on the same frame the signal is processed.

**AC-C5.2 — Coin icon present**
**GIVEN** the HUD is visible, **WHEN** the gold counter is inspected, **THEN** a coin icon node (Texture or Sprite child of the gold counter container) is visible alongside the numeric label at all gold values including `0`.

**AC-C5.3 — Affordability highlight activates (Tier 1)**
**GIVEN** `current_archer_count` is `2` (< 4) and `ARCHER_COST_TIER_1` = `30`, **WHEN** `gold_changed` fires with value `30`, **THEN** the affordability highlight visual state is active.

**AC-C5.4 — Affordability highlight deactivates below threshold (Tier 1)**
**GIVEN** `current_archer_count` is `2` and highlight is currently active, **WHEN** `gold_changed` fires with value `29`, **THEN** the affordability highlight visual state is inactive.

**AC-C5.5 — Affordability highlight activates (Tier 2)**
**GIVEN** `current_archer_count` is `5` (>= 4) and `ARCHER_COST_TIER_2` = `60`, **WHEN** `gold_changed` fires with value `60`, **THEN** the affordability highlight visual state is active.

**AC-C5.6 — Affordability highlight deactivates at max formation**
**GIVEN** `current_archer_count` is `8` (== MAX_FORMATION_SLOTS) and `current_gold` is `200`, **WHEN** `gold_changed` fires with value `200`, **THEN** the affordability highlight visual state is inactive regardless of gold amount.

**AC-C5.7 — Affordability highlight deactivates one gold below Tier 2**
**GIVEN** `current_archer_count` is `4` and highlight is active, **WHEN** `gold_changed` fires with value `59`, **THEN** the affordability highlight visual state is inactive.

---

### AC-C6: Castle HP Bar

**AC-C6.1 — Bar value updates on signal**
**GIVEN** `CASTLE_MAX_HP` = `200` and the bar currently shows `hp_ratio` = `1.0`, **WHEN** `hp_changed` fires with value `100`, **THEN** the bar `value` is exactly `0.5` with no animation or tween — the change is instantaneous.

**AC-C6.2 — No tween on update**
**GIVEN** the bar is at `hp_ratio` = `1.0`, **WHEN** `hp_changed` fires with value `0`, **THEN** no `Tween` node is created and the bar `value` reaches `0.0` within one frame.

**AC-C6.3 — GREEN color band**
**GIVEN** `CASTLE_MAX_HP` = `200`, **WHEN** `hp_changed` fires with value `120` (ratio = `0.6`), **THEN** the bar fill color matches the GREEN band constant exactly.

**AC-C6.4 — AMBER color band lower boundary**
**GIVEN** `CASTLE_MAX_HP` = `200`, **WHEN** `hp_changed` fires with value `119` (ratio ≈ `0.595`), **THEN** the bar fill color matches the AMBER band constant exactly.

**AC-C6.5 — AMBER color band upper boundary**
**GIVEN** `CASTLE_MAX_HP` = `200`, **WHEN** `hp_changed` fires with value `60` (ratio = `0.3`), **THEN** the bar fill color matches the AMBER band constant exactly.

**AC-C6.6 — RED color band**
**GIVEN** `CASTLE_MAX_HP` = `200`, **WHEN** `hp_changed` fires with value `59` (ratio ≈ `0.295`), **THEN** the bar fill color matches the RED band constant exactly.

---

### AC-C7: Wave Indicator

**AC-C7.1 — Active wave label**
**GIVEN** the HUD is visible, **WHEN** `WaveManager` emits `wave_started` with `wave_number = 3`, **THEN** the wave label text is exactly `"Wave 3"`.

**AC-C7.2 — Inter-wave countdown label on clear**
**GIVEN** wave 2 is active and the label shows `"Wave 2"`, **WHEN** `WaveManager` emits `wave_cleared`, **THEN** the wave label text becomes `"Next: 10s"` within the same frame.

**AC-C7.3 — Countdown decrements via _process**
**GIVEN** `wave_cleared` was emitted and `countdown_remaining` = `10.0`, **WHEN** `3.0` seconds of real engine delta accumulate, **THEN** the wave label displays `"Next: 7s"` (floor(10.0 - 3.0) = 7).

**AC-C7.4 — Countdown floor truncation**
**GIVEN** `countdown_remaining` = `4.9` seconds, **WHEN** the next `_process` frame fires, **THEN** the wave label displays `"Next: 4s"` (floor(4.9) = 4, not 5).

**AC-C7.5 — Countdown clamps at zero**
**GIVEN** `countdown_remaining` = `0.3` and delta = `0.5`, **WHEN** `_process` fires, **THEN** `countdown_remaining` is clamped to `0.0` and the label displays `"Next: 0s"`.

**AC-C7.6 — wave_started mid-countdown interrupts immediately**
**GIVEN** the countdown is at `"Next: 5s"`, **WHEN** `WaveManager` emits `wave_started` with `wave_number = 4`, **THEN** the wave label becomes `"Wave 4"` on the same frame and the countdown stops decrementing.

---

### AC-C8: Archer Count Badge

**AC-C8.1 — Badge text updates on recruit**
**GIVEN** the badge shows `"2/8"`, **WHEN** `Economy` emits `recruit_purchased` and `Formation.current_archer_count` is `3`, **THEN** the badge text becomes `"3/8"`.

**AC-C8.2 — Formation full visual state activates**
**GIVEN** `current_archer_count` is `7`, **WHEN** `recruit_purchased` is followed by `formation_full`, **THEN** the badge text is `"8/8"` and the filled visual state is active.

**AC-C8.3 — formation_full signal takes precedence over count read**
**GIVEN** `recruit_purchased` and `formation_full` are emitted in rapid succession within the same frame, **WHEN** both are processed, **THEN** the badge reflects the `formation_full` visual state; no intermediate non-full state persists.

**AC-C8.4 — Badge initialized at STARTING_ARCHERS**
**GIVEN** a new session starts with `STARTING_ARCHERS` = `2`, **WHEN** the HUD initialises before any `recruit_purchased` signal, **THEN** the badge text is `"2/8"` and the filled visual state is inactive.

---

### AC-C9: Session Reset

**AC-C9.1 — Gold counter resets to upstream value**
**GIVEN** the previous session ended with gold counter showing `"340"` and `Economy.current_gold` is reset to `0`, **WHEN** a new session begins, **THEN** the gold counter displays `"0"`.

**AC-C9.2 — Castle bar resets to full**
**GIVEN** the previous session ended with the bar at RED, **WHEN** a new session starts with `castle_hp = 200`, **THEN** bar `value` is `1.0` and fill color matches GREEN.

**AC-C9.3 — Wave label resets correctly**
**GIVEN** the previous session ended showing `"Next: 3s"`, **WHEN** a new session starts with `wave_active = false`, **THEN** the wave label does not show the stale countdown value; it reflects the new session's wave state.

**AC-C9.4 — Archer badge resets to STARTING_ARCHERS**
**GIVEN** the previous session had full formation (`"8/8"`) with filled visual state active, **WHEN** a new session starts with `Formation.current_archer_count = 2`, **THEN** the badge text is `"2/8"` and the filled visual state is inactive.

---

### AC-D1: HP Ratio Formula

**AC-D1.1 — Nominal ratio** — `castle_hp = 150`, `CASTLE_MAX_HP = 200` → `hp_ratio = 0.75`.
**AC-D1.2 — Ratio clamp at maximum** — `castle_hp = 200` → `hp_ratio = 1.0` (not greater).
**AC-D1.3 — Ratio clamp at minimum (overkill)** — `castle_hp = -40` → `hp_ratio = 0.0`, bar `value = 0.0`, fill color RED.

---

### AC-D2: Color Band Lookup

**AC-D2.1 — Boundary 0.6 is GREEN** — `hp_ratio = 0.6` exactly → GREEN (not AMBER).
**AC-D2.2 — Boundary 0.3 is AMBER** — `hp_ratio = 0.3` exactly → AMBER (not RED).
**AC-D2.3 — Below 0.3 is RED** — `hp_ratio = 0.299` → RED.
**AC-D2.4 — Below 0.6 is AMBER** — `hp_ratio = 0.599` → AMBER.

---

### AC-D3: Countdown Decrement Formula

**AC-D3.1 — Decrement precision** — `countdown_remaining = 10.0`, delta = `0.016` → result = `9.984`.
**AC-D3.2 — Floor display does not go negative** — `countdown_remaining = 0.01`, delta = `0.02` → clamped to `0.0`, label `"Next: 0s"`.
**AC-D3.3 — Countdown stops at zero** — Once `countdown_remaining = 0.0`, two additional frames with delta=`0.016` each → remains `0.0`.

---

### AC-D4: Wave Label Format

**AC-D4.1** — `wave_active = true`, `wave_number = 1` → `"Wave 1"` (exact, no leading zeros).
**AC-D4.2** — `wave_active = false`, `countdown_remaining = 7.9` → `"Next: 7s"`.
**AC-D4.3** — `wave_active = false`, `countdown_remaining = 0.0` → `"Next: 0s"`.
**AC-D4.4** — `wave_active = true`, `wave_number = 10` → `"Wave 10"`.

---

### AC-D5: Badge Text Format

**AC-D5.1** — `current_archer_count = 4` → `"4/8"`.
**AC-D5.2** — `current_archer_count = 2` → `"2/8"`.
**AC-D5.3** — `current_archer_count = 8` → `"8/8"`.
**AC-D5.4** — Denominator is always `"/8"` for any valid count value.

---

### AC-D6: Affordability Highlight Formula

**AC-D6.1** — count=0, gold=30 → Tier 1 cost=30; `30 >= 30` → `true`.
**AC-D6.2** — count=0, gold=29 → `29 >= 30` is false → `false`.
**AC-D6.3** — count=3, gold=30 → Tier 1 applies (count < 4); `30 >= 30` → `true`.
**AC-D6.4** — count=4, gold=30 → Tier 2 applies (count >= 4); `30 >= 60` is false → `false`.
**AC-D6.5** — count=4, gold=60 → Tier 2; `60 >= 60` AND `4 < 8` → `true`.
**AC-D6.6** — count=8, gold=9999 → `8 < 8` is false → `false` unconditionally.

---

### AC-D7: Gold Display Text Format

**AC-D7.1** — `current_gold = 75` → `"75"` (no decimal, no symbol in string).
**AC-D7.2** — `current_gold = 0` → `"0"`.
**AC-D7.3** — `current_gold = 1000` → `"1000"` (no thousands separator).

---

### AC-E: Edge Cases

**AC-E1 — Overkill clamp** — `hp_changed` fires with value `-40` → bar value = `0.0`, fill = RED, no negative-width artifact.
**AC-E2 — Duplicate wave_started** — Label already shows `"Wave 2"`, `wave_started` fires again with wave_number=2 → label stays `"Wave 2"`, no state corruption.
**AC-E3 — Duplicate wave_cleared** — `countdown_remaining` at `"Next: 7s"`, `wave_cleared` fires again → countdown continues from current value, not reset to 10.0.
**AC-E4 — GAME_OVER stops countdown** — Countdown at `"Next: 5s"`, `GAME_OVER` fires → HUD hidden, `countdown_remaining` stops decrementing (value identical two frames later).
**AC-E5 — Scene load race recovery** — Formation not ready → badge shows `"0/8"`; on first `recruit_purchased` with `current_archer_count = 3` → badge corrects to `"3/8"`.
**AC-E6 — CASTLE_MAX_HP = 0 guard** — Misconfiguration causes `CASTLE_MAX_HP = 0` → `push_error` emitted, no crash, bar retains last valid value.
**AC-E7 — Android safe area** — On device with notch/status bar, all four HUD elements are fully within `DisplayServer.get_display_safe_area()` rect — no element clipped.
**AC-E8 — wave_started mid-countdown** — Countdown at `"Next: 3s"`, `wave_started` with wave_number=3 → label switches to `"Wave 3"`, `_process` no longer decrements.
**AC-E9 — Highlight tier change on recruit** — gold=45, count=3 (Tier 1, highlight active) → recruit fires, count=4 (Tier 2, cost=60) → highlight deactivates because `45 < 60`.
**AC-E10 — Zero-gold session start** — New session, `Economy.current_gold = 0` → gold counter shows `"0"`, affordability highlight inactive.

## Open Questions

1. **Signal name alignment**: this GDD uses `hp_changed`, `gold_changed`, `wave_started`, `wave_cleared`, `recruit_purchased`, `formation_full`, `game_state_changed` as signal names. These must be confirmed against the actual signal declarations in each upstream GDD before implementation — no upstream GDD locks exact signal names as entity registry entries. → Resolve in `/consistency-check` and `/design-review`.

2. **`countdown_critical` signal exists?**: Section 7 (Audio) references a `countdown_critical` signal emitted by WaveManager at 2 seconds remaining. The Enemy Wave GDD does not currently define this signal. Either add it to the Enemy Wave GDD, or WaveManager checks the countdown internally and emits it. → Flag for Enemy Wave GDD revision.

3. **Scene load order race**: Edge Case 5 (AC-E5) identifies a race condition where HUD reads `Formation.current_archer_count = 0` if the Formation scene hasn't initialized when HUD `_ready()` runs. The provisional resolution (deferred read on first `recruit_purchased`) needs confirmation. → Resolve in the Architecture Decision Record for scene initialization order.

4. **`DisplayServer.get_display_safe_area()` stability on Godot 4.6 Android**: the engine reference notes this API was experimental in 4.3 (MEDIUM risk in 4.6). Verify the API is stable and returns correct values on Android devices with notches before implementing safe-area anchoring. → Validate in a spike test before HUD implementation story.

5. **BitmapFont asset does not yet exist**: Visual/Audio specifies a custom bitmap font (condensed bold, 512×256 atlas). This asset must be created or licensed before HUD implementation begins. → Dependency on `/art-bible` output (not yet authored).
